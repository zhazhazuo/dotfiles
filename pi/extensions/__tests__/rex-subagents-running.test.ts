/**
 * rex-subagents-running — title contract, publish, refresh, and clear
 *
 * The adapter's side of this contract is in agent-monitor/adapters/rex.sh: a parked
 * block becomes `SubagentsRunning` when its title matches
 * `([0-9]+)[[:space:]]+[Ss]ubagents?`. The first test pins that shape, so a change to
 * either side fails here rather than on a SketchyBar chip.
 */

import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import rexSubagentsRunning, {
  MAX_TITLE_NAMES,
  buildSubagentTitle,
  createRexSubagentsRunningExtension,
  fallbackTitle,
} from "../rex-subagents-running.ts";

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

// ── fixtures ───────────────────────────────────────────────────────────────

/** The same regex agent-monitor/adapters/rex.sh applies to a title. */
const ADAPTER_TITLE_PATTERN = /([0-9]+)\s+[Ss]ubagents?/;

/** A version 1 registry snapshot holding the given threads. */
function registryEntry(threads: Array<{ path: string; state: string }>, rootSessionId = "session:1") {
  return {
    customType: "pi-subagent:registry:v1",
    data: {
      version: 1,
      rootSessionId,
      threads: threads.map((thread) => ({ view: { path: thread.path, state: thread.state } })),
    },
  };
}

type Handler = (event: unknown, ctx: unknown) => Promise<void>;

/** A pi stand-in that records handlers so a test can fire events at them. */
function fakePi() {
  const handlers = new Map<string, Handler[]>();
  const pi = {
    on(name: string, handler: Handler) {
      const list = handlers.get(name) ?? [];
      list.push(handler);
      handlers.set(name, list);
    },
  };
  async function fire(name: string, event: unknown, ctx: unknown): Promise<void> {
    for (const handler of handlers.get(name) ?? []) await handler(event, ctx);
    // `publish` is not awaited by the handlers; let its promise settle.
    await Bun.sleep(0);
    await Bun.sleep(0);
  }
  return { pi, fire };
}

/** Run fn with the given environment and restore it afterwards. */
function withEnv<T>(env: Record<string, string | undefined>, fn: () => T): T {
  const saved = new Map<string, string | undefined>();
  for (const key of Object.keys(env)) {
    saved.set(key, process.env[key]);
    const value = env[key];
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  try {
    return fn();
  } finally {
    for (const [key, value] of saved) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

const cwd = mkdtempSync(join(tmpdir(), "rex-subagents-"));

/** A context whose UI records the titles written to the terminal. */
function fakeCtx(entries: unknown[], titles: string[], options: { mode?: string } = {}) {
  return {
    mode: options.mode ?? "tui",
    ui: { setTitle: (title: string) => titles.push(title) },
    sessionManager: {
      getSessionId: () => "session:1",
      getBranch: () => entries,
    },
  };
}

// ── T1: the title carries a count the adapter can read ─────────────────────

{
  const title = buildSubagentTitle({ count: 2, names: ["alpha", "beta"] }, 65);
  check("T1 title matches the adapter pattern", ADAPTER_TITLE_PATTERN.test(title), title);
  check("T1 title states the count", ADAPTER_TITLE_PATTERN.exec(title)?.[1] === "2", title);
  check("T1 title shows the clock", title.includes("1:05"), title);

  const one = buildSubagentTitle({ count: 1, names: ["solo"] }, 5);
  check("T1 singular reads subagent", /1 subagent\b/.test(one), one);

  const many = buildSubagentTitle(
    { count: MAX_TITLE_NAMES + 2, names: ["a", "b", "c", "d", "e"] },
    10,
  );
  check("T1 extra names collapse", many.includes("+2"), many);
  check("T1 still matches the adapter pattern", ADAPTER_TITLE_PATTERN.exec(many)?.[1] === "5", many);
}

// ── T2: inert outside a Rex block, and for a subagent child ────────────────

{
  const { pi } = fakePi();
  const titles: string[] = [];
  const created = withEnv({ REX_BLOCK: undefined }, () =>
    createRexSubagentsRunningExtension(pi, { setTitle: (title) => titles.push(title) }),
  );
  check("T2 inert without REX_BLOCK", created === false);

  const child = withEnv({ REX_BLOCK: "block:x", PI_SUBAGENT_CHILD: "1" }, () =>
    createRexSubagentsRunningExtension(pi, { setTitle: () => {} }),
  );
  check("T2 inert for a subagent child", child === false);
}

// ── T3: a parked session with running threads publishes the title ──────────

{
  const { pi, fire } = fakePi();
  const titles: string[] = [];
  const entries = [registryEntry([{ path: "/root/alpha", state: "running" }, { path: "/root/beta", state: "running" }])];
  withEnv({ REX_BLOCK: "block:x", REX_SESSION: "session:1" }, () =>
    createRexSubagentsRunningExtension(pi, {
      setTitle: (title) => titles.push(title),
      readTitle: async () => "π - Downloads",
      now: () => 0,
    }),
  );

  await fire("session_start", { reason: "start" }, fakeCtx(entries, titles));
  const first = titles.at(-1) ?? "";
  check("T3 publishes the subagent title", /⏳ 2 subagents \(alpha, beta\)/.test(first), first);
  check("T3 published title matches the adapter", ADAPTER_TITLE_PATTERN.exec(first)?.[1] === "2", first);
}

// ── T4: the title is written once per change, not per event ────────────────

{
  const { pi, fire } = fakePi();
  const titles: string[] = [];
  const entries = [registryEntry([{ path: "/root/alpha", state: "running" }])];
  let reads = 0;
  withEnv({ REX_BLOCK: "block:x" }, () =>
    createRexSubagentsRunningExtension(pi, {
      setTitle: (title) => titles.push(title),
      readTitle: async () => {
        reads++;
        return "π - Downloads";
      },
      now: () => 0,
    }),
  );

  const ctx = fakeCtx(entries, titles);
  await fire("session_start", { reason: "start" }, ctx);
  await fire("agent_settled", {}, ctx);
  check("T4 one write for an unchanged title", titles.length === 1, JSON.stringify(titles));
  check("T4 pi's title is read once", reads === 1, String(reads));
}

// ── T5: the clock makes a refresh a real change ────────────────────────────

{
  const { pi, fire } = fakePi();
  const titles: string[] = [];
  const entries = [registryEntry([{ path: "/root/alpha", state: "running" }])];
  let clock = 0;
  withEnv({ REX_BLOCK: "block:x" }, () =>
    createRexSubagentsRunningExtension(pi, {
      setTitle: (title) => titles.push(title),
      readTitle: async () => "π - Downloads",
      refreshIntervalMs: 10,
      now: () => clock,
    }),
  );

  await fire("session_start", { reason: "start" }, fakeCtx(entries, titles));
  const first = titles.at(-1) ?? "";
  clock = 45_000;
  await waitFor(() => titles.length > 1, 1500);
  const second = titles.at(-1) ?? "";
  check("T5 refresh rewrites the title", second !== first, `${first} / ${second}`);
  check("T5 refresh advances the clock", second.includes("0:45"), second);
}

// ── T6: the clear restores pi's own title ─────────────────────────────────

{
  const { pi, fire } = fakePi();
  const titles: string[] = [];
  let entries = [registryEntry([{ path: "/root/alpha", state: "running" }])];
  withEnv({ REX_BLOCK: "block:x" }, () =>
    createRexSubagentsRunningExtension(pi, {
      setTitle: (title) => titles.push(title),
      readTitle: async () => "π - Downloads",
      now: () => 0,
    }),
  );

  const ctx = fakeCtx(entries, titles);
  await fire("session_start", { reason: "start" }, ctx);
  check("T6 subagent title in place", /subagent/.test(titles.at(-1) ?? ""), titles.at(-1));

  entries = [registryEntry([{ path: "/root/alpha", state: "done" }])];
  await fire("agent_settled", {}, fakeCtx(entries, titles));
  check("T6 clear restores pi's title", titles.at(-1) === "π - Downloads", titles.at(-1));
}

// ── T7: shutdown restores the title too ───────────────────────────────────

{
  const { pi, fire } = fakePi();
  const titles: string[] = [];
  const entries = [registryEntry([{ path: "/root/alpha", state: "running" }])];
  withEnv({ REX_BLOCK: "block:x" }, () =>
    createRexSubagentsRunningExtension(pi, {
      setTitle: (title) => titles.push(title),
      readTitle: async () => "π - Downloads",
      now: () => 0,
    }),
  );

  await fire("session_start", { reason: "start" }, fakeCtx(entries, titles));
  await fire("session_shutdown", {}, fakeCtx(entries, titles));
  check("T7 shutdown restores pi's title", titles.at(-1) === "π - Downloads", titles.at(-1));
}

// ── T8: the fallback title names the working directory ────────────────────

{
  globalThis.process.chdir(cwd);
  check(
    "T8 fallback title is pi's shape",
    fallbackTitle(cwd) === `π - ${cwd.split("/").pop()}`,
    fallbackTitle(cwd),
  );
}

check("default export is a function", typeof rexSubagentsRunning === "function");

console.log(`\n${passed} passed, ${failures.length} failed`);
for (const failure of failures) console.log(`  FAIL  ${failure}`);
process.exit(failures.length === 0 ? 0 : 1);
