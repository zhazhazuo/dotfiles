/**
 * ask-user-attention — report "blocked on human" to Herdr while Pi waits for a
 * reply to `ask_user_question` (or any blocking extension UI prompt).
 *
 * Why this exists:
 *   Pi's Herdr agent-state integration (`herdr-agent-state.ts`, managed by
 *   `herdr integration install pi`) only leaves `working` when something emits
 *   `herdr:blocked`. `@juicesharp/rpiv-ask-user-question` emits
 *   `rpiv:ask-user:blocked` while its questionnaire waits, but nothing bridges
 *   it, so the Herdr pane — and therefore agent-monitor's herdr source — stayed
 *   green through the whole wait. This extension is that bridge.
 *
 *   Herdr path:
 *     rpiv:ask-user:blocked → herdr:blocked
 *       → herdr-agent-state `pane.report_agent state=blocked`
 *       → agent-monitor `adapters/herdr.sh` maps blocked → PermissionRequest
 *       → state `needs-help` (red) + macOS notification.
 *
 * Signals (both feed one reason set, so the counted Herdr contract observes
 * exactly one active/inactive pair per blocked span):
 *   1. `rpiv:ask-user:blocked` — primary; the question text from
 *      `rpiv:ask-user:prompt` becomes the label.
 *   2. `ui_prompt_start` / `ui_prompt_end` — core backstop for any blocking
 *      extension UI prompt (select/confirm/input/editor/custom).
 *
 * Scope: Herdr-only and TUI-only, mirroring herdr-agent-state's own gating, so
 * a plain tmux / headless / subagent-child session never emits.
 *
 * The rpiv channel names are part of that package's immutable event contract
 * (`events.ts`), so they are declared here rather than imported.
 *
 * Tests: bun pi/extensions/__tests__/ask-user-attention.test.ts
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export const HERDR_BLOCKED_EVENT = "herdr:blocked";
export const ASK_USER_BLOCKED_EVENT = "rpiv:ask-user:blocked";
export const ASK_USER_PROMPT_EVENT = "rpiv:ask-user:prompt";
export const DEFAULT_BLOCKED_LABEL = "waiting for user input";
export const MAX_LABEL_CHARS = 80;

export type BlockedPayload = { active: boolean; label?: string };

/** Collapse whitespace, drop control characters, clip at a word boundary. */
export function clipLabel(raw: unknown): string | undefined {
  if (typeof raw !== "string") return undefined;
  const flat = Array.from(raw)
    .filter((ch) => ch.charCodeAt(0) >= 0x20)
    .join("")
    .replace(/\s+/g, " ")
    .trim();
  if (!flat) return undefined;
  if (flat.length <= MAX_LABEL_CHARS) return flat;
  const cut = flat.slice(0, MAX_LABEL_CHARS);
  const boundary = cut.lastIndexOf(" ");
  return (boundary > MAX_LABEL_CHARS * 0.6 ? cut.slice(0, boundary) : cut).trim();
}

/** First question text from a `rpiv:ask-user:prompt` payload. */
export function questionLabelFrom(data: unknown): string | undefined {
  const questions = (data as { questions?: unknown } | undefined)?.questions;
  if (!Array.isArray(questions)) return undefined;
  for (const entry of questions) {
    const text = (entry as { question?: unknown } | undefined)?.question;
    if (typeof text === "string" && text.trim()) return text;
  }
  return undefined;
}

export type BlockedTracker = {
  /** Mark one reason active/inactive; the last active label is reported. */
  setReason(reason: string, active: boolean, label?: string): void;
  isBlocked(): boolean;
  /** Clear all reasons, unwinding an active block with one inactive report. */
  reset(): void;
};

/**
 * Collapse any number of overlapping blocked reasons into one Herdr
 * active/inactive pair. Herdr counts `herdr:blocked`, so two signals covering
 * the same wait must not each raise a count.
 */
export function createBlockedTracker(emit: (payload: BlockedPayload) => void): BlockedTracker {
  const reasons = new Map<string, string | undefined>();
  let blocked = false;

  function publish(): void {
    const next = reasons.size > 0;
    if (next === blocked) return;
    blocked = next;
    if (!next) {
      emit({ active: false });
      return;
    }
    let label: string | undefined;
    for (const value of reasons.values()) label = value;
    emit(label ? { active: true, label } : { active: true });
  }

  return {
    setReason(reason, active, label) {
      if (active) reasons.set(reason, label);
      else reasons.delete(reason);
      publish();
    },
    isBlocked: () => blocked,
    reset() {
      const wasBlocked = blocked;
      reasons.clear();
      blocked = false;
      if (wasBlocked) emit({ active: false });
    },
  };
}

export type AttentionEnv = Record<string, string | undefined>;

function isSubagentContext(env: AttentionEnv): boolean {
  return (
    Boolean(env.PI_SUBAGENT_PARENT_SESSION) ||
    Boolean(env.PI_SUBAGENT_CHILD)
  );
}

export type AskUserAttentionOptions = {
  env?: AttentionEnv;
};

/**
 * Wire the bridge to a live pi session. Returns false when this process is not
 * a Herdr-owned session (plain terminal, headless, or subagent child), so
 * callers can tell "inert" from "active".
 */
export function createAskUserAttentionExtension(
  pi: ExtensionAPI,
  options: AskUserAttentionOptions = {},
): boolean {
  const env = options.env ?? process.env;
  if (env.HERDR_ENV !== "1") return false;
  if (!env.HERDR_PANE_ID) return false;
  if (isSubagentContext(env)) return false;

  let rootSession = false;
  let questionLabel: string | undefined;

  const tracker = createBlockedTracker((payload) => {
    pi.events.emit(HERDR_BLOCKED_EVENT, payload);
  });

  // Primary signal: the questionnaire extension's paired blocked event.
  pi.events.on(ASK_USER_PROMPT_EVENT, (data: unknown) => {
    questionLabel = clipLabel(questionLabelFrom(data));
  });

  pi.events.on(ASK_USER_BLOCKED_EVENT, (data: unknown) => {
    if (!rootSession) return;
    const active = (data as { active?: unknown } | undefined)?.active === true;
    tracker.setReason("rpiv", active, active ? (questionLabel ?? DEFAULT_BLOCKED_LABEL) : undefined);
  });

  // Backstop: any blocking extension UI prompt Pi waits on.
  pi.on("ui_prompt_start", (event: { title?: unknown } | undefined) => {
    if (!rootSession) return;
    const title = clipLabel(event?.title);
    tracker.setReason("ui_prompt", true, title ?? questionLabel ?? DEFAULT_BLOCKED_LABEL);
  });

  pi.on("ui_prompt_end", () => {
    if (!rootSession) return;
    tracker.setReason("ui_prompt", false);
  });

  pi.on("session_start", (_event: unknown, ctx?: { mode?: string }) => {
    // TUI only: RPC/JSON/print modes are headless. herdr-agent-state gates the
    // same way, and a non-root session must not spend the pane's blocked count.
    if (ctx?.mode !== "tui") return;
    tracker.reset();
    questionLabel = undefined;
    rootSession = true;
  });

  pi.on("session_shutdown", () => {
    tracker.reset();
  });

  return true;
}

export default function (pi: ExtensionAPI): void {
  createAskUserAttentionExtension(pi);
}
