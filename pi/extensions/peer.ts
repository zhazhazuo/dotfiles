/**
 * `/peer <session> <task>` sends a task to another local pi session.
 *
 * The argument completion reads the live pi-intercom roster from the broker, so
 * the session list is real data and no agent turn is spent on it. Selecting a
 * session and adding a task puts an instruction into the current session: the
 * agent then messages that peer with the intercom tool, following the house
 * protocol in ~/.agents/skills/intercom-coordination/SKILL.md.
 *
 * Source of truth for the roster: `pi-intercom list --json`, run against the
 * installed package. Each call registers a short-lived `pi-intercom-cli` peer,
 * which is filtered out here, and the result is cached for 10 s.
 *
 * Ranking, highest weight first: a peer this session has exchanged messages
 * with, a peer in the current working directory, a peer that carries a real
 * session name. The exchange history is read from this session's transcript.
 */

import {
	closeSync,
	existsSync,
	openSync,
	readSync,
	readdirSync,
	realpathSync,
	statSync,
} from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import type { AutocompleteItem } from "@earendil-works/pi-tui";

/** Name the pi-intercom CLI registers under while it lists the roster. */
const INTERCOM_CLI_SESSION_NAME = "pi-intercom-cli";

/** How long a roster read stays valid, in milliseconds. */
const PEER_ROSTER_CACHE_MS = 10_000;

/** Ceiling on roster reads, in milliseconds. */
const PEER_ROSTER_TIMEOUT_MS = 8_000;

/** Ceiling on completed session names offered for one keystroke. */
const PEER_COMPLETION_LIMIT = 20;

/** Path of the house protocol the dispatched instruction tells the agent to read. */
const PEER_PROTOCOL_SKILL_PATH = "~/.agents/skills/intercom-coordination/SKILL.md";

/** Name shape pi-intercom assigns to a session that has no name of its own. */
const RUNTIME_FALLBACK_NAME_PATTERN = /^subagent-chat-[0-9a-f]{8}-[0-9a-f]{4}/;

/** Weight of a peer this session has exchanged messages with. */
const TALKED_WEIGHT = 4;

/** Weight of a peer that works in the current directory. */
const SAME_DIRECTORY_WEIGHT = 2;

/** Weight of a peer that carries a real session name. */
const NAMED_SESSION_WEIGHT = 1;

/** How much of the session transcript tail is scanned for past peer exchanges. */
const PEER_TRANSCRIPT_TAIL_BYTES = 4 * 1024 * 1024;

/** How long a transcript scan stays valid, in milliseconds. */
const PEER_TRANSCRIPT_CACHE_MS = 10_000;

/** One intercom-connected session, as the CLI reports it. */
export type PeerSessionRecord = {
	name: string;
	id: string;
	cwd: string;
	status: string;
};

/** Runs a command and returns its exit code and output. */
export type PeerCommandRunner = (
	command: string,
	params: string[],
) => Promise<{ code: number; stdout: string; stderr: string }>;

let cachedPeerRoster: { sessions: PeerSessionRecord[]; readAt: number } | undefined;
let peerRosterInFlight: Promise<PeerSessionRecord[]> | undefined;

/** Returns the pi agent directory that holds installed packages. */
function resolvePiAgentDirectory(): string {
	const configured = process.env.PI_CODING_AGENT_DIR?.trim();
	if (configured) {
		return configured;
	}
	return join(homedir(), ".pi", "agent");
}

/** Returns the path of the pi-intercom CLI entry point, or undefined when absent. */
export function resolveIntercomCliPath(): string | undefined {
	const agentDirectory = resolvePiAgentDirectory();
	const npmCliPath = join(agentDirectory, "npm", "node_modules", "pi-intercom", "cli.mjs");
	if (existsSync(npmCliPath)) {
		return npmCliPath;
	}

	const gitRoot = join(agentDirectory, "git");
	if (!existsSync(gitRoot)) {
		return undefined;
	}
	for (const entry of readdirSync(gitRoot)) {
		const candidates = [
			join(gitRoot, entry, "pi-intercom", "cli.mjs"),
			join(gitRoot, entry, "node_modules", "pi-intercom", "cli.mjs"),
		];
		for (const candidate of candidates) {
			if (existsSync(candidate)) {
				return candidate;
			}
		}
	}
	return undefined;
}

/** Replaces the home directory prefix with a tilde. */
function shortenHomePath(path: string): string {
	const home = homedir();
	return path.startsWith(home) ? `~${path.slice(home.length)}` : path;
}

/** Returns the ids of this process's own session, which must not appear as a peer. */
export function readOwnSessionIds(): Set<string> {
	const ids = [process.env.PI_SESSION_ID, process.env.PI_INTERCOM_SESSION_ID];
	return new Set(ids.filter((id): id is string => typeof id === "string" && id.length > 0));
}

/**
 * Turns the CLI JSON listing into session records.
 * Drops the CLI's own transient entry and any id named in `excludedSessionIds`.
 */
export function parsePeerRosterJson(
	stdout: string,
	excludedSessionIds: ReadonlySet<string> = new Set(),
): PeerSessionRecord[] {
	let parsed: unknown;
	try {
		parsed = JSON.parse(stdout);
	} catch {
		return [];
	}

	const sessions = (parsed as { sessions?: unknown } | null)?.sessions;
	if (!Array.isArray(sessions)) {
		return [];
	}

	const records: PeerSessionRecord[] = [];
	for (const raw of sessions) {
		if (typeof raw !== "object" || raw === null) {
			continue;
		}
		const entry = raw as Record<string, unknown>;
		const name = typeof entry.name === "string" ? entry.name : "";
		const id = typeof entry.id === "string" ? entry.id : "";
		if (!name || name === INTERCOM_CLI_SESSION_NAME || excludedSessionIds.has(id)) {
			continue;
		}
		records.push({
			name,
			id,
			cwd: typeof entry.cwd === "string" ? entry.cwd : "",
			status: typeof entry.status === "string" ? entry.status : "",
		});
	}
	return records;
}

/** Reads the roster from the broker, reusing a read younger than the cache window. */
export async function readLivePeerSessions(run: PeerCommandRunner): Promise<PeerSessionRecord[]> {
	if (cachedPeerRoster && Date.now() - cachedPeerRoster.readAt < PEER_ROSTER_CACHE_MS) {
		return cachedPeerRoster.sessions;
	}
	if (peerRosterInFlight) {
		return peerRosterInFlight;
	}

	peerRosterInFlight = fetchPeerRoster(run).finally(() => {
		peerRosterInFlight = undefined;
	});
	return peerRosterInFlight;
}

async function fetchPeerRoster(run: PeerCommandRunner): Promise<PeerSessionRecord[]> {
	const cliPath = resolveIntercomCliPath();
	if (!cliPath) {
		return [];
	}
	const result = await run(process.execPath, [cliPath, "list", "--json"]);
	if (result.code !== 0) {
		return [];
	}
	const sessions = parsePeerRosterJson(result.stdout, readOwnSessionIds());
	cachedPeerRoster = { sessions, readAt: Date.now() };
	return sessions;
}

/** Reports whether a session name or id starts with the typed text. */
function matchesPeerPrefix(session: PeerSessionRecord, prefix: string): boolean {
	if (!prefix) {
		return true;
	}
	const needle = prefix.toLowerCase();
	return session.name.toLowerCase().startsWith(needle) || session.id.toLowerCase().startsWith(needle);
}

/** Reads the last `maxBytes` of a file as text, dropping a partial first line. */
function readTailText(path: string, maxBytes: number): string {
	let fileSize: number;
	try {
		fileSize = statSync(path).size;
	} catch {
		return "";
	}

	const start = Math.max(0, fileSize - maxBytes);
	const length = fileSize - start;
	if (length <= 0) {
		return "";
	}

	const buffer = Buffer.alloc(length);
	let descriptor: number | undefined;
	try {
		descriptor = openSync(path, "r");
		readSync(descriptor, buffer, 0, length, start);
	} catch {
		return "";
	} finally {
		if (descriptor !== undefined) {
			closeSync(descriptor);
		}
	}

	const text = buffer.toString("utf8");
	if (start === 0) {
		return text;
	}
	const firstLineBreak = text.indexOf("\n");
	return firstLineBreak >= 0 ? text.slice(firstLineBreak + 1) : "";
}

let cachedPeerConversations:
	| { transcriptPath: string; readAt: number; times: Map<string, number> }
	| undefined;

/** Records the later of two exchange times for one peer key. */
function recordPeerExchange(times: Map<string, number>, key: unknown, at: number): void {
	if (typeof key !== "string" || key.length === 0 || !Number.isFinite(at)) {
		return;
	}
	const peerKey = key.toLowerCase();
	if (at > (times.get(peerKey) ?? 0)) {
		times.set(peerKey, at);
	}
}

/**
 * Reads when this session last exchanged a message with each peer.
 * Keys are lowercased session names and ids. An outbound send is the
 * `intercom_sent` entry. An inbound message is the `intercom_message` entry,
 * because a peer that wrote to this session is one this session talked with.
 */
export function readPeerConversationTimes(transcriptPath: string): Map<string, number> {
	if (
		cachedPeerConversations &&
		cachedPeerConversations.transcriptPath === transcriptPath &&
		Date.now() - cachedPeerConversations.readAt < PEER_TRANSCRIPT_CACHE_MS
	) {
		return cachedPeerConversations.times;
	}

	const times = new Map<string, number>();
	const transcript = readTailText(transcriptPath, PEER_TRANSCRIPT_TAIL_BYTES);
	for (const line of transcript.split("\n")) {
		if (!line.includes("intercom_")) {
			continue;
		}

		let entry: Record<string, unknown>;
		try {
			entry = JSON.parse(line) as Record<string, unknown>;
		} catch {
			continue;
		}

		if (entry.type === "custom" && entry.customType === "intercom_sent") {
			const data = entry.data as { to?: unknown; timestamp?: unknown } | undefined;
			const sentAt = Number(data?.timestamp) || Date.parse(String(entry.timestamp ?? ""));
			recordPeerExchange(times, data?.to, sentAt);
			continue;
		}

		if (entry.type === "custom_message") {
			const sender = (entry.details as { from?: { name?: unknown; id?: unknown } } | undefined)?.from;
			const receivedAt = Date.parse(String(entry.timestamp ?? ""));
			recordPeerExchange(times, sender?.name, receivedAt);
			recordPeerExchange(times, sender?.id, receivedAt);
		}
	}

	cachedPeerConversations = { transcriptPath, readAt: Date.now(), times };
	return times;
}

/** Resolves a directory through symlinks, so /tmp and /private/tmp compare equal. */
function normalizeDirectoryPath(path: string): string {
	if (!path) {
		return "";
	}
	try {
		return realpathSync(path);
	} catch {
		return path;
	}
}

/** Reports whether a session carries a name that a human or an agent chose. */
export function hasExplicitSessionName(name: string): boolean {
	return !RUNTIME_FALLBACK_NAME_PATTERN.test(name);
}

/** Returns when this session last exchanged a message with the peer, or 0. */
export function readPeerLastExchangeAt(
	session: PeerSessionRecord,
	conversationTimes: ReadonlyMap<string, number>,
): number {
	return (
		conversationTimes.get(session.id.toLowerCase()) ??
		conversationTimes.get(session.name.toLowerCase()) ??
		0
	);
}

/**
 * Orders peers by the weight of the relationship: talked first, then the same
 * directory, then a real session name. Ties keep the most recent exchange
 * first, then the name order.
 */
export function rankPeerSessions(
	sessions: PeerSessionRecord[],
	currentDirectory: string,
	conversationTimes: ReadonlyMap<string, number>,
): PeerSessionRecord[] {
	const normalizedCurrent = normalizeDirectoryPath(currentDirectory);

	const weighted = sessions.map((session) => {
		const lastExchangeAt = readPeerLastExchangeAt(session, conversationTimes);
		const weight =
			(lastExchangeAt > 0 ? TALKED_WEIGHT : 0) +
			(normalizeDirectoryPath(session.cwd) === normalizedCurrent ? SAME_DIRECTORY_WEIGHT : 0) +
			(hasExplicitSessionName(session.name) ? NAMED_SESSION_WEIGHT : 0);
		return { session, lastExchangeAt, weight };
	});

	weighted.sort(
		(left, right) =>
			right.weight - left.weight ||
			right.lastExchangeAt - left.lastExchangeAt ||
			left.session.name.localeCompare(right.session.name),
	);
	return weighted.map((entry) => entry.session);
}

/** Names the reasons a peer ranks where it does, for the completion row. */
export function describePeerRelation(
	session: PeerSessionRecord,
	currentDirectory: string,
	conversationTimes: ReadonlyMap<string, number>,
): string[] {
	const relation: string[] = [];
	if (readPeerLastExchangeAt(session, conversationTimes) > 0) {
		relation.push("talked");
	}
	if (normalizeDirectoryPath(session.cwd) === normalizeDirectoryPath(currentDirectory)) {
		relation.push("same dir");
	}
	return relation;
}

/** Reads the roster, then orders it by the weight of the relationship. */
async function readRankedPeerSessions(run: PeerCommandRunner): Promise<PeerSessionRecord[]> {
	const sessions = await readLivePeerSessions(run);
	const conversationTimes = readPeerConversationTimes(process.env.PI_SESSION_FILE ?? "");
	return rankPeerSessions(sessions, process.cwd(), conversationTimes);
}

/** Builds one completion row for a session. */
export function formatPeerCompletionItem(
	session: PeerSessionRecord,
	relation: string[] = [],
): AutocompleteItem {
	const location = shortenHomePath(session.cwd) || "unknown directory";
	return {
		value: session.name,
		label: session.name,
		description: [location, session.status || "unknown state", ...relation].join(" · "),
	};
}

/**
 * Returns session-name completions for the text typed after `/peer`.
 * Returns null once the text leaves the first word, because the task follows it.
 */
export async function loadPeerSessionCompletions(
	prefix: string,
	run: PeerCommandRunner,
): Promise<AutocompleteItem[] | null> {
	const afterLeadingSpace = prefix.replace(/^\s+/, "");
	if (/\s/.test(afterLeadingSpace)) {
		return null;
	}

	const sessions = await readRankedPeerSessions(run);
	const matches = sessions.filter((session) => matchesPeerPrefix(session, afterLeadingSpace));
	if (matches.length === 0) {
		return null;
	}

	const conversationTimes = readPeerConversationTimes(process.env.PI_SESSION_FILE ?? "");
	return matches
		.slice(0, PEER_COMPLETION_LIMIT)
		.map((session) =>
			formatPeerCompletionItem(session, describePeerRelation(session, process.cwd(), conversationTimes)),
		);
}

/** Builds the instruction the agent receives after `/peer` names a session and a task. */
export function buildPeerDispatchPrompt(target: PeerSessionRecord, task: string): string {
	return [
		`Use the intercom tool to message the peer pi session "${target.name}".`,
		`Read ${PEER_PROTOCOL_SKILL_PATH} first and follow it. The default action is send.`,
		"",
		`Task for ${target.name}:`,
		task,
	].join("\n");
}

/** Asks the user to choose one session from the live roster. */
async function choosePeerSession(
	ctx: ExtensionCommandContext,
	sessions: PeerSessionRecord[],
	prefix: string,
): Promise<PeerSessionRecord | undefined> {
	const candidates = sessions.filter((session) => matchesPeerPrefix(session, prefix));
	if (candidates.length === 1) {
		return candidates[0];
	}

	const labels = candidates.map(
		(session) =>
			`${session.name} — ${shortenHomePath(session.cwd) || "unknown directory"} (${session.status || "unknown state"})`,
	);
	const picked = await ctx.ui.select("Message which session?", labels);
	if (!picked) {
		return undefined;
	}
	const pickedIndex = labels.indexOf(picked);
	return pickedIndex >= 0 ? candidates[pickedIndex] : undefined;
}

export default function peerCommandExtension(pi: ExtensionAPI) {
	const run: PeerCommandRunner = (command, params) =>
		pi.exec(command, params, { timeout: PEER_ROSTER_TIMEOUT_MS });

	pi.registerCommand("peer", {
		description: "Send a task to another local pi session (usage: /peer <session> <task>)",
		getArgumentCompletions: (prefix) => loadPeerSessionCompletions(prefix, run),
		handler: async (args, ctx) => {
			const sessions = await readRankedPeerSessions(run);
			if (sessions.length === 0) {
				ctx.ui.notify("No live pi session is connected to intercom.", "warning");
				return;
			}

			const typed = args.trim();
			const firstWord = typed.split(/\s+/)[0] ?? "";
			const target = await choosePeerSession(ctx, sessions, firstWord);
			if (!target) {
				return;
			}

			let task = typed.slice(firstWord.length).trim();
			if (!task) {
				const edited = await ctx.ui.editor(`Task for ${target.name}`, "");
				if (!edited?.trim()) {
					return;
				}
				task = edited.trim();
			}

			pi.sendUserMessage(buildPeerDispatchPrompt(target, task));
			ctx.ui.notify(`Dispatched to the agent: message ${target.name}.`, "info");
		},
	});
}
