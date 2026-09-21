/**
 * Test harness for ask-user-attention. Run with:
 *   bun pi/extensions/__tests__/ask-user-attention.test.ts
 *
 * Covers label helpers, the single-pair blocked tracker, and the live event
 * wiring (rpiv primary signal + core ui_prompt backstop) against a fake Pi.
 */

import askUserAttention, {
  ASK_USER_BLOCKED_EVENT,
  ASK_USER_PROMPT_EVENT,
  HERDR_BLOCKED_EVENT,
  createAskUserAttentionExtension,
  createBlockedTracker,
  clipLabel,
  questionLabelFrom,
  type BlockedPayload,
} from "../ask-user-attention.ts";

let passed = 0;
const failures: string[] = [];

function check(name: string, condition: boolean, detail?: string): void {
  if (condition) {
    passed++;
  } else {
    failures.push(detail ? `${name} (${detail})` : name);
  }
}

// ── fake pi ────────────────────────────────────────────────────────────────

type Handler = (event: any, ctx?: any) => unknown;

function fakePi() {
  const handlers = new Map<string, Handler[]>();
  const bus = new Map<string, ((data: unknown) => void)[]>();
  const emitted: { event: string; data: any }[] = [];

  const pi: any = {
    on: (name: string, handler: Handler) => {
      const list = handlers.get(name) ?? [];
      list.push(handler);
      handlers.set(name, list);
    },
    events: {
      on: (name: string, handler: (data: unknown) => void) => {
        const list = bus.get(name) ?? [];
        list.push(handler);
        bus.set(name, list);
        return () => undefined;
      },
      emit: (name: string, data: unknown) => {
        emitted.push({ event: name, data });
      },
    },
  };

  return {
    pi,
    handlers,
    emitted,
    fire: async (name: string, event?: any, ctx?: any) => {
      for (const handler of handlers.get(name) ?? []) await handler(event, ctx);
    },
    publish: (name: string, data?: unknown) => {
      for (const handler of bus.get(name) ?? []) handler(data);
    },
    blocked: () => emitted.filter((entry) => entry.event === HERDR_BLOCKED_EVENT).map((entry) => entry.data as BlockedPayload),
  };
}

const ROOT_ENV = { HERDR_ENV: "1", HERDR_PANE_ID: "w9:p2" };
const TUI_CTX = { mode: "tui" };

// ── clipLabel ──────────────────────────────────────────────────────────────

check("clip collapses whitespace", clipLabel("  waiting\n\t for   input ") === "waiting for input");
check(
  "clip drops control characters",
  clipLabel("ask\u0007me\u001b[31m") === "askme[31m",
  clipLabel("ask\u0007me\u001b[31m"),
);
check("clip rejects blank", clipLabel("   ") === undefined);
check("clip rejects non-string", clipLabel(42) === undefined && clipLabel(undefined) === undefined);

const long = "Should the migration rewrite the ledger rows in place or append a compatibility shim first";
const clipped = clipLabel(long);
check("clip bounds length", (clipped?.length ?? 0) <= 80, String(clipped?.length));
check("clip ends on a word", clipped !== undefined && !clipped.endsWith(" "));
check("clip keeps unicode", clipLabel("confirm — π ✓") === "confirm — π ✓");

// ── questionLabelFrom ──────────────────────────────────────────────────────

check(
  "questionLabelFrom takes the first question",
  questionLabelFrom({ questions: [{ question: "Which scope?" }, { question: "Second?" }] }) === "Which scope?",
);
check(
  "questionLabelFrom skips blank leading entries",
  questionLabelFrom({ questions: [{ question: "   " }, { question: "Real one" }] }) === "Real one",
);
check("questionLabelFrom tolerates bad shapes", questionLabelFrom(undefined) === undefined);
check("questionLabelFrom rejects empty list", questionLabelFrom({ questions: [] }) === undefined);

// ── createBlockedTracker ───────────────────────────────────────────────────

{
  const out: BlockedPayload[] = [];
  const tracker = createBlockedTracker((payload) => out.push(payload));
  tracker.setReason("rpiv", true, "Which scope?");
  tracker.setReason("rpiv", true, "Which scope?"); // duplicate active: no second raise
  tracker.setReason("rpiv", false);
  check(
    "tracker raises and lowers exactly one pair",
    out.length === 2 && out[0].active === true && out[0].label === "Which scope?" && out[1].active === false,
    JSON.stringify(out),
  );
}

{
  const out: BlockedPayload[] = [];
  const tracker = createBlockedTracker((payload) => out.push(payload));
  tracker.setReason("rpiv", true, "Which scope?");
  tracker.setReason("ui_prompt", true, "Which scope?");
  tracker.setReason("rpiv", false);
  const midBlocked = out.filter((p) => p.active).length === 1 && out.filter((p) => !p.active).length === 0;
  check("tracker stays blocked while any reason is active", midBlocked, JSON.stringify(out));
  tracker.setReason("ui_prompt", false);
  check(
    "tracker lowers on the last clear",
    out.filter((p) => p.active).length === 1 && out.filter((p) => !p.active).length === 1,
    JSON.stringify(out),
  );
}

{
  const out: BlockedPayload[] = [];
  const tracker = createBlockedTracker((payload) => out.push(payload));
  tracker.setReason("rpiv", true, "x");
  tracker.reset();
  check(
    "tracker reset unwinds an active block",
    out.length === 2 && out[1].active === false,
    JSON.stringify(out),
  );
  check("tracker reset clears state", tracker.isBlocked() === false);
}

// ── extension gating ───────────────────────────────────────────────────────

check("inert outside herdr", createAskUserAttentionExtension(fakePi().pi, { env: {} }) === false);
check(
  "inert without a pane id",
  createAskUserAttentionExtension(fakePi().pi, { env: { HERDR_ENV: "1" } }) === false,
);
check(
  "inert in a subagent child",
  createAskUserAttentionExtension(fakePi().pi, {
    env: { ...ROOT_ENV, PI_SUBAGENT_PARENT_SESSION: "01a0b27c" },
  }) === false,
);
check("active in a herdr root session", createAskUserAttentionExtension(fakePi().pi, { env: ROOT_ENV }) === true);

// ── extension wiring ───────────────────────────────────────────────────────

// No root session yet: blocked signals are ignored.
{
  const { pi, publish } = fakePi();
  const active = createAskUserAttentionExtension(pi, { env: ROOT_ENV });
  publish(ASK_USER_BLOCKED_EVENT, { active: true });
  check("active in herdr", active === true);
}

// Headless session must never emit.
{
  const { pi, fire, publish, blocked } = fakePi();
  createAskUserAttentionExtension(pi, { env: ROOT_ENV });
  await fire("session_start", { reason: "start" }, { mode: "print" });
  publish(ASK_USER_PROMPT_EVENT, { questions: [{ question: "Which scope?" }] });
  publish(ASK_USER_BLOCKED_EVENT, { active: true });
  check("headless session never emits", blocked().length === 0, JSON.stringify(blocked()));
}

// TUI root session: rpiv primary signal, question text as label.
{
  const { pi, fire, publish, blocked } = fakePi();
  createAskUserAttentionExtension(pi, { env: ROOT_ENV });
  await fire("session_start", { reason: "start" }, TUI_CTX);
  publish(ASK_USER_PROMPT_EVENT, { questions: [{ question: "Which scope should I take?" }] });
  publish(ASK_USER_BLOCKED_EVENT, { active: true });
  check(
    "rpiv blocked raises with the question as label",
    blocked().length === 1 && blocked()[0].active === true && blocked()[0].label === "Which scope should I take?",
    JSON.stringify(blocked()),
  );
  publish(ASK_USER_BLOCKED_EVENT, { active: false });
  check(
    "rpiv clear lowers the block",
    blocked().length === 2 && blocked()[1].active === false,
    JSON.stringify(blocked()),
  );
}

// TUI root session: core ui_prompt backstop.
{
  const { pi, fire, blocked } = fakePi();
  createAskUserAttentionExtension(pi, { env: ROOT_ENV });
  await fire("session_start", { reason: "start" }, TUI_CTX);
  await fire("ui_prompt_start", { type: "ui_prompt_start", reason: "ui_prompt", kind: "confirm", title: "Ship it?" });
  check(
    "ui_prompt backstop raises with its title",
    blocked().length === 1 && blocked()[0].active === true && blocked()[0].label === "Ship it?",
    JSON.stringify(blocked()),
  );
  await fire("ui_prompt_end", { type: "ui_prompt_end", reason: "ui_prompt", kind: "confirm" });
  check(
    "ui_prompt backstop lowers on end",
    blocked().length === 2 && blocked()[1].active === false,
    JSON.stringify(blocked()),
  );
}

// Overlap: rpiv and the core backstop cover the same wait → exactly one pair.
{
  const { pi, fire, publish, blocked } = fakePi();
  createAskUserAttentionExtension(pi, { env: ROOT_ENV });
  await fire("session_start", { reason: "start" }, TUI_CTX);
  publish(ASK_USER_PROMPT_EVENT, { questions: [{ question: "Which scope?" }] });
  publish(ASK_USER_BLOCKED_EVENT, { active: true });
  await fire("ui_prompt_start", { type: "ui_prompt_start", reason: "ui_prompt", kind: "custom" });
  publish(ASK_USER_BLOCKED_EVENT, { active: false });
  await fire("ui_prompt_end", { type: "ui_prompt_end", reason: "ui_prompt", kind: "custom" });
  const raises = blocked().filter((p) => p.active).length;
  const lowers = blocked().filter((p) => !p.active).length;
  check(
    "overlapping signals produce one active/inactive pair",
    raises === 1 && lowers === 1,
    JSON.stringify(blocked()),
  );
}

// Default label when no question text is available.
{
  const { pi, fire, publish, blocked } = fakePi();
  createAskUserAttentionExtension(pi, { env: ROOT_ENV });
  await fire("session_start", { reason: "start" }, TUI_CTX);
  publish(ASK_USER_BLOCKED_EVENT, { active: true });
  check(
    "missing question falls back to the default label",
    blocked().length === 1 && blocked()[0].label === "waiting for user input",
    JSON.stringify(blocked()),
  );
}

// ui_prompt backstop reuses the question label when the core event has no title.
{
  const { pi, fire, publish, blocked } = fakePi();
  createAskUserAttentionExtension(pi, { env: ROOT_ENV });
  await fire("session_start", { reason: "start" }, TUI_CTX);
  publish(ASK_USER_PROMPT_EVENT, { questions: [{ question: "Pick a target" }] });
  await fire("ui_prompt_start", { type: "ui_prompt_start", reason: "ui_prompt", kind: "custom" });
  check(
    "backstop reuses the pending question label",
    blocked().length === 1 && blocked()[0].label === "Pick a target",
    JSON.stringify(blocked()),
  );
}

check("default export is a function", typeof askUserAttention === "function");

console.log(`\n${passed} passed, ${failures.length} failed`);
for (const failure of failures) console.log(`  FAIL  ${failure}`);
process.exit(failures.length === 0 ? 0 : 1);
