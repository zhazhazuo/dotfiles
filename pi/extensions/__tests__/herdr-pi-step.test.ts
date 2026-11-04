/**
 * Test harness for herdr-pi-step. Run with: bun pi/extensions/__tests__/herdr-pi-step.test.ts
 *
 * Covers the pure step derivation, the throttled reporter, and the live event
 * flow against a real unix socket that stands in for Herdr's API socket.
 */
import net from "node:net";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import herdrPiStep, {
  buildReport,
  clipStep,
  createStepExtension,
  createStepReporter,
  inProgressStep,
  pickStep,
  replayTodos,
  tasksFromDetails,
  toolPhrase,
} from "../herdr-pi-step.ts";

let passed = 0;
const failures: string[] = [];

function check(name: string, condition: boolean, detail?: string): void {
  if (condition) {
    passed++;
  } else {
    failures.push(detail ? `${name} (${detail})` : name);
  }
}

async function waitFor(predicate: () => boolean, ms = 2000): Promise<boolean> {
  const start = Date.now();
  while (Date.now() - start < ms) {
    if (predicate()) return true;
    await Bun.sleep(10);
  }
  return predicate();
}

// ── pure helpers ───────────────────────────────────────────────────────────

check("clip collapses whitespace", clipStep("  running\n\t cargo   test  ") === "running cargo test");
check(
  "clip keeps control characters out",
  clipStep("step\u0007 label\u001b[31m") === "step label[31m",
  clipStep("step\u0007 label\u001b[31m"),
);
check("clip rejects blank", clipStep("   ") === undefined && clipStep(undefined) === undefined);
check("clip keeps unicode", clipStep("writing tests — π ✓") === "writing tests — π ✓");

const long = "analyzing the herdr tab bar status segment wiring across the pi extension and configuration";
const clipped = clipStep(long);
check("clip bounds length", (clipped?.length ?? 0) <= 72, String(clipped?.length));
check("clip ends on a word", clipped?.endsWith(" ") === false && !clipped?.endsWith("acros"));

check(
  "todo step prefers activeForm",
  inProgressStep([
    { id: 1, subject: "Verify end to end", status: "pending" },
    { id: 2, subject: "Write the status script", activeForm: "writing the status script", status: "in_progress" },
  ]) === "writing the status script",
);
check(
  "todo step falls back to subject",
  inProgressStep([{ id: 3, subject: "Write the status script", status: "in_progress" }]) ===
    "Write the status script",
);
check("todo step ignores finished work", inProgressStep([{ id: 1, status: "completed" }]) === undefined);
check("todo step tolerates junk", inProgressStep(undefined) === undefined && inProgressStep([]) === undefined);

check(
  "pickStep priority: todo over tool over name",
  pickStep({ todoStep: "writing tests", toolStep: "running `bun test`", sessionName: "herdr work" }) ===
    "writing tests",
);
check(
  "pickStep falls through blanks",
  pickStep({ todoStep: "  ", toolStep: "editing config.toml", sessionName: "herdr work" }) ===
    "editing config.toml",
);
check("pickStep can resolve to nothing", pickStep({ todoStep: "", toolStep: "", sessionName: "" }) === undefined);

check("toolPhrase: tests", toolPhrase("bash", { command: "cd /tmp && bun test src" }) === "running tests");
check("toolPhrase: build", toolPhrase("bash", { command: "cargo build --release" }) === "building");
check(
  "toolPhrase: generic command",
  toolPhrase("bash", { command: "grep -rn tab_bar_right src/" }) === "running `grep -rn tab_bar_right src/`",
);
check("toolPhrase: edit", toolPhrase("edit", { path: "/Users/walkerw/.config/herdr/config.toml" }) === "editing config.toml");
check("toolPhrase: write", toolPhrase("write", { path: "status-pi-step.sh" }) === "writing status-pi-step.sh");
check("toolPhrase: read", toolPhrase("read", { path: "src/ui/panes.rs" }) === "reading panes.rs");
check("toolPhrase: grep keeps pattern", toolPhrase("grep", { pattern: "tab_bar_right" }) === "searching for tab_bar_right");
check("toolPhrase: unknown tool falls back", toolPhrase("confluence_search", {}) === "running confluence_search");
check("toolPhrase: todo is not a phrase", toolPhrase("todo", { action: "list" }) === undefined);
check("toolPhrase: missing name is silent", toolPhrase(undefined, {}) === undefined);

const branch = [
  { type: "message", message: { role: "user", content: "hi" } },
  {
    type: "message",
    message: {
      role: "toolResult",
      toolName: "todo",
      details: { tasks: [{ id: 1, subject: "first", status: "pending" }] },
    },
  },
  { type: "message", message: { role: "toolResult", toolName: "read", details: { tasks: "nope" } } },
  {
    type: "message",
    message: {
      role: "toolResult",
      toolName: "todo",
      details: { tasks: [{ id: 1, subject: "second", status: "in_progress", activeForm: "writing tests" }] },
    },
  },
];
const replayed = replayTodos(branch);
check("replay takes the latest snapshot", replayed.length === 1 && replayed[0].subject === "second");
check("replay ignores other tools", replayTodos([{ type: "message", message: { role: "toolResult", toolName: "bash" } }]).length === 0);
check("details guard rejects junk", tasksFromDetails({ tasks: "nope" }) === undefined);
check("details guard accepts lists", tasksFromDetails({ tasks: [{ id: 1 }] })?.length === 1);

const cleared = buildReport("w1:p2", undefined, 7) as any;
check("report targets the pane token", cleared.params.pane_id === "w1:p2" && cleared.params.tokens.pi_step === null);
check("report carries ttl and seq", cleared.params.ttl_ms === 86_400_000 && cleared.params.seq === 7);
check("report uses the socket method", cleared.method === "pane.report_metadata" && cleared.params.source === "user:pi-step");
const set = buildReport("w1:p2", "writing tests", 8) as any;
check("report sets text", set.params.tokens.pi_step === "writing tests");

// ── reporter ───────────────────────────────────────────────────────────────

{
  const seen: (string | undefined)[] = [];
  const reporter = createStepReporter(async (request: any) => {
    seen.push(request.text);
  }, { buildRequest: (text) => ({ text }) as any, minIntervalMs: 5 });

  reporter.set("first");
  reporter.set("second");
  reporter.set("third");
  check("reporter sends the first step immediately", seen.join(",") === "first", seen.join(","));
  await reporter.settle();
  check("reporter coalesces intermediates to the latest", seen.join(",") === "first,third", seen.join(","));

  reporter.set("third");
  await reporter.settle();
  check("reporter skips duplicate text", seen.join(",") === "first,third", seen.join(","));

  reporter.set(undefined);
  await reporter.settle();
  check("reporter clears with undefined", seen[seen.length - 1] === undefined, String(seen[seen.length - 1]));
  reporter.dispose();
}

// ── live flow over a real socket ────────────────────────────────────────────

const socketDir = mkdtempSync(join(tmpdir(), "herdr-pi-step-"));
const socketPath = join(socketDir, "herdr.sock");
const requests: any[] = [];
const server = net.createServer((socket) => {
  socket.on("data", (buffer) => {
    for (const line of buffer.toString().split("\n")) {
      if (!line.trim()) continue;
      try {
        requests.push(JSON.parse(line));
      } catch {
        requests.push({ malformed: line });
      }
    }
    socket.write('{"id":"ok","result":{"type":"ok"}}\n');
  });
});
await new Promise<void>((resolve) => server.listen(socketPath, () => resolve()));

function fakePi() {
  const handlers = new Map<string, ((event: any, ctx?: any) => unknown)[]>();
  const pi: any = {
    on: (name: string, handler: (event: any, ctx?: any) => unknown) => {
      const list = handlers.get(name) ?? [];
      list.push(handler);
      handlers.set(name, list);
    },
    events: { on: () => undefined },
  };
  const fire = async (name: string, event?: any, ctx?: any) => {
    for (const handler of handlers.get(name) ?? []) await handler(event, ctx);
  };
  return { pi, fire, handlers };
}

function withEnv<T>(env: Record<string, string | undefined>, fn: () => T): T {
  const keys = ["HERDR_ENV", "HERDR_SOCKET_PATH", "HERDR_PANE_ID", "PI_SUBAGENT_PARENT_SESSION", "PI_SUBAGENT_CHILD"];
  const saved = Object.fromEntries(keys.map((key) => [key, process.env[key]]));
  for (const key of keys) {
    if (env[key] === undefined) delete process.env[key];
    else process.env[key] = env[key];
  }
  try {
    return fn();
  } finally {
    for (const key of keys) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  }
}

const inertOutsideHerdr = withEnv({}, () => createStepExtension(fakePi().pi));
check("inert outside herdr", inertOutsideHerdr === false);

const inertInSubagent = withEnv(
  {
    HERDR_ENV: "1",
    HERDR_SOCKET_PATH: socketPath,
    HERDR_PANE_ID: "w9:p1",
    PI_SUBAGENT_PARENT_SESSION: "01a0b27c",
  },
  () => createStepExtension(fakePi().pi),
);
check("inert in a subagent child", inertInSubagent === false);

{
  const { pi, fire } = fakePi();
  const active = withEnv(
    { HERDR_ENV: "1", HERDR_SOCKET_PATH: socketPath, HERDR_PANE_ID: "w9:p2" },
    () => createStepExtension(pi, { minIntervalMs: 5 }),
  );
  check("active in a herdr root session", active === true);

  const token = () => requests[requests.length - 1]?.params?.tokens?.pi_step;
  const base = 200;
  await fire("session_start", { reason: "start" }, {
    mode: "tui",
    isIdle: () => true,
    sessionManager: {
      getBranch: () => branch,
      getSessionName: () => undefined,
    },
  });
  await waitFor(() => token() === "writing tests");
  check("session_start replays the todo step", token() === "writing tests", String(token()));

  await fire("tool_result", { toolName: "todo", details: { tasks: [{ id: 1, subject: "second", status: "completed" }] } });
  await fire("tool_execution_start", { toolName: "bash", args: { command: "bun test" } });
  await waitFor(() => token() === "running tests");
  check("tool activity takes over once todos finish", token() === "running tests", String(token()));

  await fire("agent_settled", {}, { isIdle: () => true });
  await Bun.sleep(30);
  check("settling keeps the last step", token() === "running tests", String(token()));

  await fire("session_info_changed", { name: "herdr tab bar task" });
  await Bun.sleep(30);
  check("a todo step outranks the session name while working", token() === "running tests", String(token()));

  await fire("agent_start", {});
  await waitFor(() => token() === "thinking");
  check("a new turn shows thinking", token() === "thinking", String(token()));

  await fire("session_shutdown", { reason: "quit" });
  await waitFor(() => token() === null);
  check("quit clears the token", token() === null, String(token()));
}

{
  const { pi, fire } = fakePi();
  const active = withEnv(
    { HERDR_ENV: "1", HERDR_SOCKET_PATH: socketPath, HERDR_PANE_ID: "w9:p3" },
    () => createStepExtension(pi, { minIntervalMs: 5 }),
  );
  check("headless session stays inert", active === true);
  await fire("session_start", { reason: "start" }, {
    mode: "print",
    isIdle: () => true,
    sessionManager: { getBranch: () => [], getSessionName: () => undefined },
  });
  const before = requests.length;
  await fire("tool_execution_start", { toolName: "bash", args: { command: "bun test" } });
  await Bun.sleep(30);
  check("headless session never reports", requests.length === before, String(requests.length - before));
}

check("default export is a function", typeof herdrPiStep === "function");
server.close();

// ── report ─────────────────────────────────────────────────────────────────

console.log(`\n${passed} passed, ${failures.length} failed`);
for (const failure of failures) console.log(`  FAIL  ${failure}`);
process.exit(failures.length === 0 ? 0 : 1);
