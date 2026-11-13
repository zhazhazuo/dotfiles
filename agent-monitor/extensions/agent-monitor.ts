/**
 * agent-monitor — Emit Pi lifecycle events into the shared agent monitor.
 *
 * Architecture:
 *   Pi event → adapters/pi.sh → agent-monitor reconcile
 *     → state.json → sinks/sketchybar.sh → SketchyBar items
 *
 * The adapter handles event mapping (Pi names → generic names) and
 * subagent filtering. The core handles state transitions and sink refresh.
 *
 * Subagent detection: pi-subagents spawns each child as a full Pi process
 * and marks it with PI_SUBAGENT_PARENT_SESSION / PI_SUBAGENT_CHILD env vars
 * (see pi-subagents pi-args.ts). We gate on those in emit() — the canonical
 * signal. The session-file path regex is kept only as a secondary backstop.
 *
 * States:
 *   session_start  → SessionStart → idle
 *   agent_start    → RunStart     → running
 *   agent_settled  → TurnComplete → needs-attention
 *
 * We use agent_settled (NOT agent_end) because agent_end fires for every
 * agent loop including subagent turns. agent_settled fires only when the
 * entire run is truly complete.
 *
 * Cleanup is handled by tmux pane-exited / after-kill-pane hooks
 * calling agent-monitor prune.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import * as path from "node:path";

const ADAPTER_SCRIPT = path.resolve(
  process.env.HOME ?? "~",
  "dotfiles/agent-monitor/adapters/pi.sh",
);

/**
 * Detect a pi-subagents child process via the environment.
 *
 * pi-subagents sets PI_SUBAGENT_PARENT_SESSION (and PI_SUBAGENT_CHILD) on
 * every child Pi process it spawns. This is the canonical, reliable signal.
 * Child sessions use arbitrary .jsonl locations (--session / --session-dir /
 * .pi-subagents/artifacts), so path guessing cannot identify them.
 */
function isSubagentContext(): boolean {
  return (
    Boolean(process.env.PI_SUBAGENT_PARENT_SESSION) ||
    Boolean(process.env.PI_SUBAGENT_CHILD)
  );
}

/**
 * Backstop: detect a subagent from the session file path alone.
 *
 * Matches pi's legacy internal run-log layout:
 *   Subagent:  .../<uuid>/<runId>/run-<index>/session.jsonl
 *
 * Not sufficient on its own (pi-subagents children don't use this layout),
 * hence kept only as defense-in-depth behind isSubagentContext().
 */
function isSubagentSession(sessionFile: string | undefined): boolean {
  if (!sessionFile) return false;
  return /\/run-\d+\/session\.jsonl$/.test(sessionFile);
}

/**
 * Fire-and-forget: call the Pi adapter with the raw event name.
 * The adapter handles event mapping and agent naming.
 * Must never throw or block Pi's event loop.
 */
function emit(piEvent: string, payload: string): void {
  // Never emit from a pi-subagents child process — canonical guard.
  if (isSubagentContext()) return;

  // Only emit inside tmux — TMUX_PANE is the identity anchor.
  if (!process.env.TMUX) return;

  const child = spawn(ADAPTER_SCRIPT, [piEvent], {
    stdio: ["pipe", "ignore", "ignore"],
    env: { ...process.env },
  });

  child.on("error", () => {
    // Silently ignore — monitor is best-effort.
  });

  child.stdin.write(payload);
  child.stdin.end();
}

/**
 * Build the JSON payload the monitor expects on stdin.
 */
function buildPayload(ctx: { cwd: string }, extra?: Record<string, unknown>): string {
  return JSON.stringify({
    cwd: ctx.cwd,
    session_id: extra?.session_id ?? undefined,
    ...extra,
  });
}

export default function (pi: ExtensionAPI) {
  // ── session_start → idle ────────────────────────────────────────────
  pi.on("session_start", async (_event, ctx) => {
    const sessionFile = ctx.sessionManager.getSessionFile();
    if (isSubagentSession(sessionFile)) return;
    emit("session_start", buildPayload(ctx, {
      session_id: sessionFile ?? undefined,
    }));
  });

  // ── agent_start → running ───────────────────────────────────────────
  pi.on("agent_start", async (_event, ctx) => {
    const sessionFile = ctx.sessionManager.getSessionFile();
    if (isSubagentSession(sessionFile)) return;
    emit("agent_start", buildPayload(ctx, {
      session_id: sessionFile ?? undefined,
    }));
  });

  // ── agent_settled → needs-attention ──────────────────────────────────
  pi.on("agent_settled", async (_event, ctx) => {
    const sessionFile = ctx.sessionManager.getSessionFile();
    if (isSubagentSession(sessionFile)) return;
    emit("agent_settled", buildPayload(ctx, {
      session_id: sessionFile ?? undefined,
    }));
  });

  // ── session_shutdown → remove agent from monitor ─────────────────────
  pi.on("session_shutdown", async (_event, ctx) => {
    const sessionFile = ctx.sessionManager.getSessionFile();
    if (isSubagentSession(sessionFile)) return;
    emit("session_shutdown", buildPayload(ctx, {
      session_id: sessionFile ?? undefined,
    }));
  });
}
