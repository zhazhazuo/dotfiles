/**
 * Prints the `/peer` completion list, ordered by the same weights the command uses.
 *
 * This is the repeatable check for the deterministic session list. It reads the
 * live intercom roster and this session's transcript, then ranks the peers:
 * talked first, then the same directory, then a real session name.
 *
 * Usage: bun ~/dotfiles/pi/scripts/peer-completions-probe.ts [--talked <name>] [prefix ...]
 * `--talked <name>` marks that peer as talked, so the weight can be checked
 * without sending it a message.
 */

import { execFile } from "node:child_process";
import {
	describePeerRelation,
	formatPeerCompletionItem,
	readLivePeerSessions,
	readPeerConversationTimes,
	rankPeerSessions,
	resolveIntercomCliPath,
	type PeerCommandRunner,
} from "../extensions/peer.ts";

const run: PeerCommandRunner = (command, params) =>
	new Promise((resolve) => {
		execFile(command, params, { timeout: 8_000 }, (error, stdout, stderr) => {
			resolve({ code: error ? 1 : 0, stdout: String(stdout), stderr: String(stderr) });
		});
	});

const argv = process.argv.slice(2);
const talkedIndex = argv.indexOf("--talked");
const talkedName = talkedIndex >= 0 ? argv[talkedIndex + 1] : undefined;
const prefixes = argv.filter((_, index) => index !== talkedIndex && index !== talkedIndex + 1);
if (prefixes.length === 0) {
	prefixes.push("");
}

for (const prefix of prefixes) {
	const conversationTimes = new Map(readPeerConversationTimes(process.env.PI_SESSION_FILE ?? ""));
	if (talkedName) {
		conversationTimes.set(talkedName.toLowerCase(), Date.now());
	}

	const sessions = rankPeerSessions(
		await readLivePeerSessions(run),
		process.cwd(),
		conversationTimes,
	);
	const matches = sessions.filter((session) =>
		prefix ? session.name.toLowerCase().startsWith(prefix.toLowerCase()) : true,
	);

	console.log(`cli: ${resolveIntercomCliPath() ?? "not found"}`);
	console.log(
		`transcript: ${process.env.PI_SESSION_FILE ?? "unset"} · ${conversationTimes.size} peer(s) talked`,
	);
	console.log(`prefix ${JSON.stringify(prefix)} -> ${matches.length} item(s)`);
	for (const session of matches) {
		const item = formatPeerCompletionItem(
			session,
			describePeerRelation(session, process.cwd(), conversationTimes),
		);
		console.log(`  ${String(item.label).padEnd(34)} ${item.description ?? ""}`);
	}
}
