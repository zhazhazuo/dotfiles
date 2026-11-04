/**
 * rex-subagents-running — report "subagents running" in the Rex block title while
 * this root Pi session is parked on background subagent threads.
 *
 * Why this exists:
 *   agent-monitor shows an orange `subagents-running` item when a main agent is
 *   parked (turn ended) but the subagents it spawned are still running, so the
 *   item is not read as the blue "finished, review me" state. For Rex, that signal
 *   has to come from data Rex exposes, and the program status pi publishes carries
 *   only the session name. Rex has no pane metadata channel, so the terminal title
 *   is the channel: a program sets it with OSC 2, the server stores it per block,
 *   `com.superlogical.terminal.title` reads it back, and `title_changed` announces
 *   the change.
 *
 * Path:
 *   pi-subagent:registry:v1 journal (base + deltas, replayed)
 *     → ctx.ui.setTitle("⏳ N subagent(s) (names) · m:ss")
 *     → Rex title_changed
 *     → agent-monitor adapters/rex.sh reads a parked block's title
 *     → SubagentsRunning → SketchyBar item turns orange.
 *
 * Refresh:
 *   Rex announces `title_changed` only when the title really differs, so the label
 *   carries an elapsed clock: every tick is a fresh change, which also refreshes
 *   agent-monitor's `subagents_checked_at` heartbeat so `prune` does not demote a
 *   long run as abandoned.
 *
 * Clear:
 *   The extension API has no title getter, so pi's own title is read once per run
 *   from the server and written back when the last thread finishes.
 *
 * Scope: Rex-only and TUI-only. A subagent child process is excluded: it shares
 * the block but does not own its title.
 */

import { execFile } from "node:child_process";
import * as path from "node:path";
import { promisify } from "node:util";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { formatElapsedClock, runningSubagentsFromEntries } from "../lib/subagent-registry.ts";
import type { RunningSubagents } from "../lib/subagent-registry.ts";

/** Rex re-emits title_changed only on a real change, so refresh with a new clock. */
export const REFRESH_INTERVAL_MS = 45_000;
/** Names shown in the title; the rest collapse into a `+N`. */
export const MAX_TITLE_NAMES = 3;

const execFileAsync = promisify(execFile);

/** The title a parked root session publishes while its threads still run. */
export function buildSubagentTitle(running: RunningSubagents, elapsedSeconds: number): string {
  const noun = running.count === 1 ? "subagent" : "subagents";
  const shown = running.names.slice(0, MAX_TITLE_NAMES).join(", ");
  const hidden = running.names.length - MAX_TITLE_NAMES;
  const names = shown ? ` (${shown}${hidden > 0 ? `, +${hidden}` : ""})` : "";
  return `⏳ ${running.count} ${noun}${names} · ${formatElapsedClock(elapsedSeconds)}`;
}

/** Read the block's title from the Rex server, or undefined when it cannot be read. */
export async function readBlockTitle(blockId: string, sessionId?: string): Promise<string | undefined> {
  const args = ["api", "call"];
  if (sessionId) args.push("-s", sessionId);
  args.push("com.superlogical.terminal.title", JSON.stringify({ block_id: blockId }));
  try {
    const { stdout } = await execFileAsync("rex", args, { timeout: 4_000 });
    const parsed = JSON.parse(stdout) as { title?: unknown };
    return typeof parsed.title === "string" ? parsed.title : undefined;
  } catch {
    // The monitor degrades to pi's own title; nothing to report here.
    return undefined;
  }
}

/** What pi sets at startup: `<app> - <session> - <cwd>`, or without a session name. */
export function fallbackTitle(cwd: string, appTitle = "π"): string {
  return `${appTitle} - ${path.basename(cwd) || cwd}`;
}

export type SubagentsRunningOptions = {
  refreshIntervalMs?: number;
  now?: () => number;
  /** Test seam: the writer for the terminal title, normally ctx.ui.setTitle. */
  setTitle?: (title: string) => void;
  /** Test seam: pi's own title, normally read from the Rex server. */
  readTitle?: () => Promise<string | undefined>;
};

type SubagentsContext = {
  mode?: string;
  ui?: { setTitle?: (title: string) => void };
  sessionManager?: {
    getSessionId?: () => string;
    getBranch?: () => unknown[];
    getEntries?: () => unknown[];
  };
};

/**
 * Wire the bridge to a live pi session. Returns false when this process is not a
 * Rex-owned root session (plain terminal, another multiplexer, headless, or a
 * subagent child), so callers can tell "inert" from "active".
 */
export function createRexSubagentsRunningExtension(
  pi: ExtensionAPI,
  options: SubagentsRunningOptions = {},
): boolean {
  const blockId = process.env.REX_BLOCK;
  if (!blockId) return false;
  if (process.env.PI_SUBAGENT_PARENT_SESSION || process.env.PI_SUBAGENT_CHILD) return false;

  const sessionId = process.env.REX_SESSION;
  const refreshIntervalMs = options.refreshIntervalMs ?? REFRESH_INTERVAL_MS;
  const now = options.now ?? (() => Date.now());
  const writeTitle = options.setTitle;
  const readTitle = options.readTitle ?? (() => readBlockTitle(blockId, sessionId));

  let rootSession = false;
  let rootSessionId: string | undefined;
  let readEntries: () => unknown[] = () => [];
  let publishedTitle: string | undefined;
  let piTitle: string | undefined;
  let publishing = false;
  let startedAt: number | undefined;
  let refreshTimer: ReturnType<typeof setTimeout> | undefined;

  function stopRefresh(): void {
    if (refreshTimer) {
      clearTimeout(refreshTimer);
      refreshTimer = undefined;
    }
  }

  /** Arm the next tick. Re-arming is `publish`'s job, so the loop stops when nothing runs. */
  function scheduleRefresh(): void {
    if (refreshTimer || !rootSession) return;
    refreshTimer = setTimeout(() => {
      refreshTimer = undefined;
      void publish();
    }, refreshIntervalMs);
    refreshTimer.unref?.();
  }

  /** Derive, publish, and (while threads run) arm the refresh. */
  async function publish(setTitle?: (title: string) => void): Promise<void> {
    if (!rootSession) return;
    const write = setTitle ?? writeTitle;
    if (!write) return;
    if (publishing) {
      // A read is still in flight; read again on the next tick rather than race it.
      scheduleRefresh();
      return;
    }

    publishing = true;
    try {
      const running = runningSubagentsFromEntries(readEntries(), rootSessionId);

      if (running.count > 0) {
        startedAt ??= now();
        // Capture pi's own title once, before the first override, so the clear is exact.
        piTitle ??= await readTitle();
        const title = buildSubagentTitle(running, (now() - startedAt) / 1000);
        if (title !== publishedTitle) {
          publishedTitle = title;
          write(title);
        }
        scheduleRefresh();
        return;
      }

      startedAt = undefined;
      stopRefresh();
      if (publishedTitle === undefined) return;
      publishedTitle = undefined;
      write(piTitle ?? fallbackTitle(process.cwd()));
      piTitle = undefined;
    } finally {
      publishing = false;
    }
  }

  function handle(ctx: SubagentsContext | undefined): void {
    if (!rootSession) return;
    const sessionManager = ctx?.sessionManager;
    // `getBranch` is the path to the leaf, which is what the producer replays;
    // `getEntries` would also return a branch this session left behind.
    if (typeof sessionManager?.getBranch === "function") {
      readEntries = () => sessionManager.getBranch?.() ?? [];
    } else if (typeof sessionManager?.getEntries === "function") {
      readEntries = () => sessionManager.getEntries?.() ?? [];
    }
    if (typeof sessionManager?.getSessionId === "function") {
      rootSessionId = sessionManager.getSessionId();
    }
    void publish(ctx?.ui?.setTitle);
  }

  pi.on("session_start", async (_event, ctx) => {
    // TUI only: RPC/JSON/print modes are headless (no block title to own).
    if ((ctx as SubagentsContext | undefined)?.mode !== "tui") return;
    rootSession = true;
    handle(ctx as SubagentsContext);
  });

  pi.on("agent_start", async (_event, ctx) => handle(ctx as SubagentsContext));
  pi.on("agent_settled", async (_event, ctx) => handle(ctx as SubagentsContext));

  // A spawn returns mid-turn; publishing now means the title is already in place
  // when the turn ends, so the park itself carries it.
  pi.on("tool_result", async (event, ctx) => {
    const toolName = (event as { toolName?: unknown } | undefined)?.toolName;
    if (typeof toolName !== "string" || !toolName.startsWith("agent_")) return;
    handle(ctx as SubagentsContext);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    if (!rootSession) return;
    rootSession = false;
    stopRefresh();
    if (publishedTitle === undefined) return;
    publishedTitle = undefined;
    (ctx as SubagentsContext | undefined)?.ui?.setTitle?.(piTitle ?? fallbackTitle(process.cwd()));
  });

  return true;
}

export default function (pi: ExtensionAPI): void {
  createRexSubagentsRunningExtension(pi);
}
