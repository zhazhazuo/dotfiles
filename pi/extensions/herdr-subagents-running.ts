/**
 * herdr-subagents-running — report "subagents running" to Herdr while this root
 * Pi session is parked on background subagent threads.
 *
 * Why this exists:
 *   agent-monitor shows an orange `subagents-running` item when a main agent is
 *   parked (turn ended) but the subagents it spawned are still running, so the
 *   item is not read as the blue "finished, review me" state. Its herdr source
 *   learned that from Herdr pane state labels whose text contained
 *   "N subagent(s)", which the old `pi-subagents` package published because each
 *   child was a full Pi process that owned pane metadata.
 *
 *   The successor, `pi-subagent-manager`, runs its subagent threads in-process
 *   and publishes nothing to Herdr, so the labels stopped arriving and every
 *   parked agent read as `needs-attention`. This extension is that bridge: it
 *   derives the count from the manager's own session entry and republishes the
 *   labels, so `adapters/herdr.sh` keeps working unchanged.
 *
 * Herdr path:
 *   pi-subagent:registry:v1 journal (base + deltas, replayed)
 *     → pane.report_metadata state_labels "⏳ N subagent(s) (names) · m:ss"
 *     → Herdr pane.agent_status_changed (presentation change)
 *     → agent-monitor adapters/herdr.sh maps a parked pane to `subagents-running`
 *     → SketchyBar / tmux item turns orange.
 *
 * Refresh:
 *   Herdr re-emits pane.agent_status_changed only when the pane presentation
 *   actually differs (`emit_pane_state_update` in src/app/api.rs), and it expires
 *   metadata on its own TTL without an event. The elapsed clock in the label
 *   therefore guarantees each refresh is a real presentation change, which both
 *   keeps the item orange and refreshes agent-monitor's `subagents_checked_at`
 *   heartbeat so `prune` does not demote a long run as abandoned.
 *
 * Clear:
 *   The same event lags its own snapshot: Herdr announces the label change before
 *   `herdr api snapshot` stops listing the labels, and the adapter reads the
 *   snapshot. A clear landing in that window is recomputed as still-orange, and a
 *   clear is the last report of a run, so nothing re-fires. The bridge repeats the
 *   clear once after `CLEAR_RETRY_MS`.
 *
 * Scope: Herdr-only and TUI-only, mirroring `herdr-agent-state.ts`. A legacy
 * `pi-subagents` child process shares this pane but does not own its labels, so
 * it is excluded too; the in-process manager needs no such exclusion because it
 * never emits root-session events.
 *
 * Tests: bun pi/extensions/__tests__/herdr-subagents-running.test.ts
 */

import net from "node:net";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	RUNNING_THREAD_STATES,
	SUBAGENT_REGISTRY_ENTRY,
	type RegistryThread,
	type RunningSubagents,
	formatElapsedClock,
	replayRegistryThreads,
	runningSubagentsFromEntries,
} from "../lib/subagent-registry.ts";

// The registry reader moved to lib/subagent-registry.ts so the Rex bridge can
// share it. Re-exported here because this module's tests import these names.
export {
	RUNNING_THREAD_STATES,
	SUBAGENT_REGISTRY_ENTRY,
	formatElapsedClock,
	replayRegistryThreads,
	runningSubagentsFromEntries,
};
export type { RegistryThread, RunningSubagents };

/** Herdr metadata source; distinct from `herdr:pi` so agent authority is untouched. */
export const HERDR_SOURCE = "user:pi-subagents-running";
/** Herdr only re-emits its event on a presentation change, so refresh with a new clock. */
export const REFRESH_INTERVAL_MS = 45_000;
/** Herdr expires metadata at this age without emitting; kept above the refresh. */
export const METADATA_TTL_MS = 120_000;
/**
 * Herdr announces a label change before `herdr api snapshot` reflects it. The
 * adapter reads the snapshot, so a clear that lands in that window is recomputed
 * as still-orange and nothing re-fires. One delayed repeat close the gap.
 */
export const CLEAR_RETRY_MS = 2_500;
/** Names shown in the label; the rest collapse into a `+N`. */
export const MAX_LABEL_NAMES = 4;

export type SubagentsRunningOptions = {
  refreshIntervalMs?: number;
  clearRetryMs?: number;
  now?: () => number;
};

/** The `idle`/`done`/`working` labels the herdr adapter reads to detect subagents. */
export function buildSubagentStateLabels(
  running: RunningSubagents,
  elapsedSeconds: number,
): Record<string, string> {
  const noun = running.count === 1 ? "subagent" : "subagents";
  const shown = running.names.slice(0, MAX_LABEL_NAMES).join(", ");
  const hidden = running.names.length - MAX_LABEL_NAMES;
  const names = shown ? ` (${shown}${hidden > 0 ? `, +${hidden}` : ""})` : "";
  const label = `⏳ ${running.count} ${noun}${names} · ${formatElapsedClock(elapsedSeconds)}`;
  return { idle: label, done: label, working: label };
}

/** A `pane.report_metadata` request; pass no labels to clear them. */
export function buildSubagentMetadataReport(
  paneId: string,
  stateLabels: Record<string, string> | undefined,
  seq: number,
): Record<string, unknown> {
  return {
    id: `${HERDR_SOURCE}:${Date.now()}:${Math.random().toString(36).slice(2)}`,
    method: "pane.report_metadata",
    params: {
      pane_id: paneId,
      source: HERDR_SOURCE,
      agent: "pi",
      seq,
      ttl_ms: METADATA_TTL_MS,
      ...(stateLabels ? { state_labels: stateLabels } : { clear_state_labels: true }),
    },
  };
}

function sendRequestAttempt(endpoint: string, request: unknown, timeoutMs: number): Promise<boolean> {
  return new Promise((resolve) => {
    let done = false;
    let timeout: ReturnType<typeof setTimeout> | undefined;
    const finish = (delivered: boolean) => {
      if (done) return;
      done = true;
      if (timeout) clearTimeout(timeout);
      socket.destroy();
      resolve(delivered);
    };

    const socket = net.createConnection(endpoint);
    socket.on("error", () => finish(false));
    socket.on("connect", () => socket.write(`${JSON.stringify(request)}\n`));
    socket.on("data", () => finish(true));
    socket.on("end", () => finish(false));
    timeout = setTimeout(() => finish(false), timeoutMs);
    timeout.unref?.();
  });
}

async function sendRequest(endpoint: string, request: unknown): Promise<void> {
  if (await sendRequestAttempt(endpoint, request, 500)) return;
  await sendRequestAttempt(endpoint, request, 1500);
}

/** A session context as far as this bridge needs it; all fields are optional. */
type SubagentsContext = {
  mode?: string;
  sessionManager?: {
    getSessionId?: () => string;
    getBranch?: () => unknown[];
    getEntries?: () => unknown[];
  };
};

/**
 * Wire the bridge to a live pi session. Returns false when this process is not
 * a Herdr-owned root session (plain terminal, headless, or legacy subagent
 * child), so callers can tell "inert" from "active".
 */
export function createSubagentsRunningExtension(
  pi: ExtensionAPI,
  options: SubagentsRunningOptions = {},
): boolean {
  const socketPath = process.env.HERDR_SOCKET_PATH;
  const paneId = process.env.HERDR_PANE_ID;
  if (process.env.HERDR_ENV !== "1" || !socketPath || !paneId) return false;
  if (process.env.PI_SUBAGENT_PARENT_SESSION || process.env.PI_SUBAGENT_CHILD) return false;

  const endpoint =
    process.platform === "win32" && socketPath ? `\\\\.\\pipe\\${socketPath}` : socketPath;
  const refreshIntervalMs = options.refreshIntervalMs ?? REFRESH_INTERVAL_MS;
  const clearRetryMs = options.clearRetryMs ?? CLEAR_RETRY_MS;
  const now = options.now ?? (() => Date.now());

  let seq = Date.now() * 1000;
  const nextSeq = () => ++seq;

  let rootSession = false;
  let rootSessionId: string | undefined;
  let readEntries: () => unknown[] = () => [];
  let publishedText: string | undefined;
  let publishing = false;
  let startedAt: number | undefined;
  let refreshTimer: ReturnType<typeof setTimeout> | undefined;
  let clearRetryTimer: ReturnType<typeof setTimeout> | undefined;

  function stopRefresh(): void {
    if (refreshTimer) {
      clearTimeout(refreshTimer);
      refreshTimer = undefined;
    }
  }

  function stopClearRetry(): void {
    if (clearRetryTimer) {
      clearTimeout(clearRetryTimer);
      clearRetryTimer = undefined;
    }
  }

  /**
   * Repeat a clear once, after the window in which Herdr's snapshot still shows
   * the old labels. Skips the repeat when threads started again meanwhile.
   */
  function scheduleClearRetry(): void {
    stopClearRetry();
    clearRetryTimer = setTimeout(() => {
      clearRetryTimer = undefined;
      if (!rootSession) return;
      if (runningSubagentsFromEntries(readEntries(), rootSessionId).count > 0) return;
      void sendRequest(endpoint, buildSubagentMetadataReport(paneId, undefined, nextSeq()));
    }, clearRetryMs);
    clearRetryTimer.unref?.();
  }

  /** Arm the next refresh tick. Re-arming is `publish`'s job, so the loop stops as soon as nothing runs. */
  function scheduleRefresh(): void {
    if (refreshTimer || !rootSession) return;
    refreshTimer = setTimeout(() => {
      refreshTimer = undefined;
      void publish();
    }, refreshIntervalMs);
    refreshTimer.unref?.();
  }

  /**
   * Derive, publish, and (while threads run) arm the refresh. Sends only when
   * the label differs from the last published one: Herdr ignores an unchanged
   * presentation, so an identical report would be dead traffic.
   */
  async function publish(): Promise<void> {
    if (!rootSession) return;
    if (publishing) {
      // A send is still in flight; retry next tick rather than dropping the loop.
      scheduleRefresh();
      return;
    }
    publishing = true;
    try {
      const running = runningSubagentsFromEntries(readEntries(), rootSessionId);
      let labels: Record<string, string> | undefined;
      let text: string | undefined;

      if (running.count > 0) {
        startedAt ??= now();
        labels = buildSubagentStateLabels(running, (now() - startedAt) / 1000);
        text = labels.idle;
        stopClearRetry();
        scheduleRefresh();
      } else {
        startedAt = undefined;
        stopRefresh();
      }

      if (text === publishedText) return;
      publishedText = text;
      await sendRequest(endpoint, buildSubagentMetadataReport(paneId, labels, nextSeq()));
      if (labels === undefined) scheduleClearRetry();
    } finally {
      publishing = false;
    }
  }

  function handle(ctx: SubagentsContext | undefined): void {
    if (!rootSession) return;
    const sessionManager = ctx?.sessionManager;
    // `getBranch` is the current path to the leaf, which is what the producer replays;
    // `getEntries` would also return entries of a branch this session left behind.
    if (typeof sessionManager?.getBranch === "function") {
      readEntries = () => sessionManager.getBranch?.() ?? [];
    } else if (typeof sessionManager?.getEntries === "function") {
      readEntries = () => sessionManager.getEntries?.() ?? [];
    }
    if (typeof sessionManager?.getSessionId === "function") {
      rootSessionId = sessionManager.getSessionId();
    }
    void publish();
  }

  pi.on("session_start", async (event, ctx) => {
    // TUI only: RPC/JSON/print modes are headless (no pane Herdr can label).
    if ((ctx as SubagentsContext | undefined)?.mode !== "tui") return;
    rootSession = true;
    handle(ctx as SubagentsContext);
  });

  pi.on("agent_start", async (_event, ctx) => handle(ctx as SubagentsContext));
  pi.on("agent_settled", async (_event, ctx) => handle(ctx as SubagentsContext));

  // A spawn returns mid-turn; publishing now means the labels are already in
  // place when the turn ends, so the park itself carries them.
  pi.on("tool_result", async (event, ctx) => {
    const toolName = (event as { toolName?: unknown } | undefined)?.toolName;
    if (typeof toolName !== "string" || !toolName.startsWith("agent_")) return;
    handle(ctx as SubagentsContext);
  });

  pi.on("session_shutdown", async () => {
    if (!rootSession) return;
    rootSession = false;
    stopRefresh();
    stopClearRetry();
    if (publishedText === undefined) return;
    publishedText = undefined;
    try {
      await sendRequest(endpoint, buildSubagentMetadataReport(paneId, undefined, nextSeq()));
    } catch {
      /* Best-effort: the pane TTL clears a missed report. */
    }
  });

  return true;
}

export default function (pi: ExtensionAPI): void {
  createSubagentsRunningExtension(pi);
}
