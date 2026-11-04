/**
 * Test harness for herdr-subagents-running. Run with:
 *   bun pi/extensions/__tests__/herdr-subagents-running.test.ts
 *
 * QA scenarios, each traceable to the two contracts this bridge joins:
 *   agent-monitor's `subagents-running` state (see
 *   dotfiles/agent-monitor/adapters/herdr.sh, README "Subagent state") and
 *   pi-subagent-manager's `pi-subagent:registry:v1` session entry
 *   (src/index.ts persist() / orch/manager.ts saved()).
 *
 *   S1  running threads    -> "⏳ N subagents (…)" state labels -> the adapter
 *                             stores `subagents-running` with subagents_count = N
 *   S2  nothing running    -> clear_state_labels            -> the adapter stores
 *                             `needs-attention` (the deferred "your turn" ping)
 *   S3  the registry journal replays: v1 snapshot, v2 base, v2 deltas; `starting`
 *       counts as running; paused/completed/failed/stopped do not; a delta is not
 *       a thread list, so the newest entry alone says nothing
 *   S4  inert outside herdr, outside TUI mode, and in a legacy pi-subagents child
 *   S5  while threads run, the bridge republishes with a *changed* value, because
 *       herdr only re-emits pane.agent_status_changed when the presentation
 *       differs (src/app/api.rs emit_pane_state_update) — that re-emission is
 *       what keeps agent-monitor's subagents_checked_at heartbeat fresh
 *   S6  session_shutdown clears the labels
 */
import net from "node:net";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import herdrSubagentsRunning, {
  SUBAGENT_REGISTRY_ENTRY,
  buildSubagentMetadataReport,
  buildSubagentStateLabels,
  createSubagentsRunningExtension,
  runningSubagentsFromEntries,
} from "../herdr-subagents-running.ts";

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

type ThreadFixture = { path: string; state: string; type?: string };

const savedThread = (thread: ThreadFixture) => ({
  view: {
    path: thread.path,
    parent: "/root",
    owner: "/root",
    type: thread.type ?? "coder",
    state: thread.state,
    task: "do the thing",
    status: "Working",
    createdAt: 0,
    sessionFile: `/tmp/${thread.path.split("/").pop()}.jsonl`,
  },
  definition: { name: thread.type ?? "coder" },
});

/** A version 1 entry: the whole thread list on every change (legacy sessions). */
function snapshotEntry(threads: ThreadFixture[], rootSessionId = "root-1"): unknown {
  return {
    type: "custom",
    customType: SUBAGENT_REGISTRY_ENTRY,
    data: { version: 1, rootSessionId, threads: threads.map(savedThread) },
  };
}

/** A version 2 base: the whole thread list, written once per session. */
function registryEntry(threads: ThreadFixture[], rootSessionId = "root-1"): unknown {
  return {
    type: "custom",
    customType: SUBAGENT_REGISTRY_ENTRY,
    data: { version: 2, rootSessionId, kind: "base", threads: threads.map(savedThread) },
  };
}

/**
 * A version 2 delta: only the threads that changed. `viewOnly` mirrors the
 * producer's case where the definition is already on the branch.
 */
function deltaEntry(
  upserts: (ThreadFixture | { viewOf: ThreadFixture })[] = [],
  removals: string[] = [],
  rootSessionId = "root-1",
): unknown {
  return {
    type: "custom",
    customType: SUBAGENT_REGISTRY_ENTRY,
    data: {
      version: 2,
      rootSessionId,
      kind: "delta",
      upserts: upserts.map((item) =>
        "viewOf" in item ? { view: savedThread(item.viewOf).view } : savedThread(item),
      ),
      removals,
    },
  };
}

// ── S3: which threads count, and from which entry ──────────────────────────

{
  const running = runningSubagentsFromEntries([
    registryEntry([
      { path: "/root/alpha", state: "running" },
      { path: "/root/beta", state: "running" },
      { path: "/root/gamma", state: "starting" },
    ]),
  ]);
  check("S3 running + starting count", running.count === 3, String(running.count));
  check("S3 names are the thread basenames", running.names.join(",") === "alpha,beta,gamma", running.names.join(","));

  const settled = runningSubagentsFromEntries([
    registryEntry([
      { path: "/root/alpha", state: "completed" },
      { path: "/root/beta", state: "failed" },
      { path: "/root/gamma", state: "stopped" },
      { path: "/root/delta", state: "paused" },
    ]),
  ]);
  check("S3 settled states do not count", settled.count === 0, String(settled.count));

  // Any later base replaces the snapshot; it is not merged with an earlier one.
  const newestBaseWins = runningSubagentsFromEntries([
    registryEntry([{ path: "/root/old", state: "running" }]),
    registryEntry([{ path: "/root/old", state: "completed" }]),
  ]);
  check("S3 a later base replaces the snapshot", newestBaseWins.count === 0, String(newestBaseWins.count));

  check("S3 no registry entry is zero", runningSubagentsFromEntries([]).count === 0);
  check(
    "S3 ignores other custom entries",
    runningSubagentsFromEntries([{ customType: "pi-subagent:cost:v1", data: { threads: [{ view: { state: "running" } }] } }]).count === 0,
  );
  check(
    "S3 tolerates malformed entries",
    runningSubagentsFromEntries([
      registryEntry([{ path: "", state: "running" }]),
      { customType: SUBAGENT_REGISTRY_ENTRY, data: { threads: "nope" } },
      { customType: SUBAGENT_REGISTRY_ENTRY },
    ]).count === 0,
  );
}

// ── S3b: the version 2 journal (base + deltas) ─────────────────────────────

{
  // The regression: from version 2 the newest entry is a delta that names only the
  // changed thread, so a reader of the newest entry alone reports every running
  // thread as gone and the item never turns orange.
  const runningUnderDelta = runningSubagentsFromEntries([
    registryEntry([{ path: "/root/alpha", state: "running" }]),
    deltaEntry([{ path: "/root/alpha", state: "running" }]),
  ]);
  check("S3b a running base survives its own delta", runningUnderDelta.count === 1, String(runningUnderDelta.count));
  check("S3b the name survives the replay", runningUnderDelta.names.join(",") === "alpha", runningUnderDelta.names.join(","));

  // The producer restates a changed thread only; every other thread keeps its state.
  const partialDelta = runningSubagentsFromEntries([
    registryEntry([
      { path: "/root/alpha", state: "running" },
      { path: "/root/beta", state: "running" },
    ]),
    deltaEntry([{ path: "/root/beta", state: "completed" }]),
  ]);
  check("S3b a delta keeps the threads it does not restate", partialDelta.names.join(",") === "alpha", partialDelta.names.join(","));

  // A view-only upsert carries no definition; its state still applies.
  const viewOnly = runningSubagentsFromEntries([
    registryEntry([{ path: "/root/alpha", state: "starting" }]),
    deltaEntry([{ viewOf: { path: "/root/alpha", state: "running" } }]),
  ]);
  check("S3b a view-only upsert applies", viewOnly.count === 1, String(viewOnly.count));

  // A removal drops the thread, so a settled thread leaves the label.
  const removed = runningSubagentsFromEntries([
    registryEntry([
      { path: "/root/alpha", state: "running" },
      { path: "/root/beta", state: "running" },
    ]),
    deltaEntry([], ["/root/beta"]),
  ]);
  check("S3b a removal drops the thread", removed.names.join(",") === "alpha", removed.names.join(","));

  // Version 1 sessions must keep reporting until they are resumed.
  const legacy = runningSubagentsFromEntries([snapshotEntry([{ path: "/root/alpha", state: "running" }])]);
  check("S3b a version 1 snapshot still counts", legacy.count === 1, String(legacy.count));

  // A forked session owns a new registry; the parent's threads must not leak in.
  const forked = runningSubagentsFromEntries(
    [
      registryEntry([{ path: "/root/parent-thread", state: "running" }], "root-1"),
      deltaEntry([{ path: "/root/child-thread", state: "running" }], [], "root-2"),
    ],
    "root-2",
  );
  check("S3b a fork drops the parent's threads", forked.names.join(",") === "child-thread", forked.names.join(","));

  // Malformed deltas must not throw or invent threads.
  check(
    "S3b tolerates malformed deltas",
    runningSubagentsFromEntries([
      registryEntry([{ path: "/root/alpha", state: "running" }]),
      { customType: SUBAGENT_REGISTRY_ENTRY, data: { version: 2, kind: "delta", upserts: "nope", removals: "nope" } },
      { customType: SUBAGENT_REGISTRY_ENTRY, data: { version: 2, kind: "delta", upserts: [{ view: {} }] } },
      { customType: SUBAGENT_REGISTRY_ENTRY, data: { version: 9, threads: [] } },
    ]).count === 1,
  );
}

// ── S1/S2/S5: the label contract the adapter parses ────────────────────────

{
  const labels = buildSubagentStateLabels({ count: 3, names: ["alpha", "beta", "gamma"] }, 42);
  check(
    "S1 label parses as the adapter's count",
    /([0-9]+)\s+[Ss]ubagents?/.exec(labels.idle)?.[1] === "3",
    labels.idle,
  );
  check("S1 every status carries the label", labels.working === labels.idle && labels.done === labels.idle);
  check("S1 label names the workers", labels.idle.includes("alpha") && labels.idle.includes("gamma"), labels.idle);
  check("S1 label carries the elapsed clock", /42|0:42/.test(labels.idle), labels.idle);

  const single = buildSubagentStateLabels({ count: 1, names: ["alpha"] }, 5);
  check("S1 singular noun", /1\s+[Ss]ubagent[^s]/.test(single.idle), single.idle);

  const first = buildSubagentStateLabels({ count: 2, names: ["alpha", "beta"] }, 0);
  const later = buildSubagentStateLabels({ count: 2, names: ["alpha", "beta"] }, 45);
  check("S5 refresh changes the value", first.idle !== later.idle, `${first.idle} vs ${later.idle}`);
}

{
  const report = buildSubagentMetadataReport("w9:p1", { idle: "⏳ 1 subagent (a) 0:00" }, 7) as any;
  check("S1 report uses the herdr metadata method", report.method === "pane.report_metadata");
  check("S1 report targets the pane with agent pi", report.params.pane_id === "w9:p1" && report.params.agent === "pi");
  check("S1 report sets state labels", report.params.state_labels?.idle === "⏳ 1 subagent (a) 0:00");
  check("S1 report carries ttl and seq", report.params.ttl_ms > 0 && report.params.seq === 7);
  check("S1 report never claims agent authority", report.params.applies_to_source === undefined);

  const cleared = buildSubagentMetadataReport("w9:p1", undefined, 8) as any;
  check("S2 clear uses clear_state_labels", cleared.params.clear_state_labels === true);
  check("S2 clear does not also set labels", cleared.params.state_labels === undefined);
}

// ── live flow over a real socket ───────────────────────────────────────────

const socketDir = mkdtempSync(join(tmpdir(), "herdr-subagents-running-"));
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
  const keys = [
    "HERDR_ENV",
    "HERDR_SOCKET_PATH",
    "HERDR_PANE_ID",
    "PI_SUBAGENT_PARENT_SESSION",
    "PI_SUBAGENT_CHILD",
  ];
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

const tuiCtx = (entries: unknown[]) => ({
  mode: "tui",
  isIdle: () => true,
  sessionManager: { getEntries: () => entries, getBranch: () => entries },
});

// S4: inert outside herdr.
check("S4 inert outside herdr", withEnv({}, () => createSubagentsRunningExtension(fakePi().pi)) === false);

// S4: inert in a legacy pi-subagents child process.
check(
  "S4 inert in a legacy subagent child",
  withEnv(
    { HERDR_ENV: "1", HERDR_SOCKET_PATH: socketPath, HERDR_PANE_ID: "w9:p9", PI_SUBAGENT_CHILD: "1" },
    () => createSubagentsRunningExtension(fakePi().pi),
  ) === false,
);

// S1/S2/S5/S6 live.
{
  const { pi, fire } = fakePi();
  const entries: unknown[] = [registryEntry([{ path: "/root/alpha", state: "running" }])];
  // A controllable clock: the real timer ticks every 40ms, but the elapsed
  // clock only moves when the test advances it, so S5 is deterministic.
  let clock = 1_000_000;
  // Every publish reads the entries, so counting reads observes the timer even
  // when an idle tick would send nothing.
  let entryReads = 0;
  const ctx = (contextEntries: unknown[]) => ({
    mode: "tui",
    isIdle: () => true,
    sessionManager: {
      getSessionId: () => "root-1",
      getBranch: () => {
        entryReads++;
        return contextEntries;
      },
      getEntries: () => {
        entryReads++;
        return contextEntries;
      },
    },
  });
  const active = withEnv(
    { HERDR_ENV: "1", HERDR_SOCKET_PATH: socketPath, HERDR_PANE_ID: "w9:p1" },
    () => createSubagentsRunningExtension(pi, { refreshIntervalMs: 40, clearRetryMs: 30, now: () => clock }),
  );
  check("S4 active in a herdr TUI root session", active === true);

  const lastReport = () => requests[requests.length - 1];

  await fire("session_start", { reason: "start" }, ctx(entries));
  await fire("agent_settled", {}, ctx(entries));
  // The handler publishes fire-and-forget, like herdr-pi-step: wait for the send.
  await waitFor(() => /1\s+[Ss]ubagent/.test(lastReport()?.params?.state_labels?.idle ?? ""), 1500);
  const first = lastReport();
  check("S1 park publishes subagent state labels", /1\s+[Ss]ubagent/.test(first?.params?.state_labels?.idle ?? ""), JSON.stringify(first?.params));
  check("S1 publish never claims authority", first?.params?.applies_to_source === undefined);

  // S5: the same running set must be republished with a changed value.
  const firstLabels = first?.params?.state_labels?.idle;
  const before = requests.length;
  clock += 45_000;
  const changed = await waitFor(() => {
    const current = lastReport();
    return requests.length > before && current?.params?.state_labels?.idle !== firstLabels;
  }, 1500);
  check("S5 refresh republishes a changed value", changed, JSON.stringify(lastReport()?.params));

  // S3b: the live producer writes a delta after its base. The bridge must read the
  // replay, not the newest entry, or this clear turns back into a running label.
  entries.splice(
    0,
    entries.length,
    registryEntry([{ path: "/root/alpha", state: "running" }]),
    deltaEntry([{ viewOf: { path: "/root/alpha", state: "running" } }]),
  );
  await fire("agent_settled", {}, ctx(entries));
  await waitFor(() => /1\s+[Ss]ubagent/.test(lastReport()?.params?.state_labels?.idle ?? ""), 1500);
  check(
    "S3b a published label survives a trailing delta",
    /1\s+[Ss]ubagent/.test(lastReport()?.params?.state_labels?.idle ?? ""),
    JSON.stringify(lastReport()?.params),
  );

  // S2: threads settle -> clear.
  entries.splice(0, entries.length, registryEntry([{ path: "/root/alpha", state: "completed" }]));
  await fire("agent_settled", {}, ctx(entries));
  await waitFor(() => lastReport()?.params?.clear_state_labels === true, 1500);
  check("S2 settling clears the labels", lastReport()?.params?.clear_state_labels === true, JSON.stringify(lastReport()?.params));

  // S2b: herdr announces the change before its snapshot shows it, so the adapter
  // can recompute a cleared pane as still-orange. The bridge repeats the clear.
  const clearCount = () => requests.filter((request) => request.params?.clear_state_labels === true).length;
  const clearsBeforeRetry = clearCount();
  const retried = await waitFor(() => clearCount() > clearsBeforeRetry, 1500);
  check("S2 a clear is repeated once", retried, String(clearCount() - clearsBeforeRetry));

  // S5b: the refresh loop must stop when nothing runs. Drive it the hard way —
  // re-arm by event, then let the *timer itself* discover completion, with no
  // event to clear the loop. `entryReads` only grows when a tick runs, so a
  // surviving (no-op) timer shows up here even though it would send nothing.
  entries.splice(0, entries.length, registryEntry([{ path: "/root/alpha", state: "running" }]));
  await fire("agent_settled", {}, ctx(entries));
  await waitFor(() => lastReport()?.params?.state_labels !== undefined, 1500);

  entries.splice(0, entries.length, registryEntry([{ path: "/root/alpha", state: "completed" }]));
  await waitFor(() => lastReport()?.params?.clear_state_labels === true, 1500);
  // Consume the clear retry first: it is one bounded repeat, not the refresh loop.
  const clearsBeforeStop = clearCount();
  await waitFor(() => clearCount() > clearsBeforeStop, 1500);
  const readsAfterClear = entryReads;
  clock += 45_000;
  await Bun.sleep(150);
  check("S5 refresh loop stops once nothing runs", entryReads === readsAfterClear, `+${entryReads - readsAfterClear} reads`);

  // S6: shutdown clears.
  entries.splice(0, entries.length, registryEntry([{ path: "/root/alpha", state: "running" }]));
  await fire("agent_settled", {}, ctx(entries));
  await waitFor(() => lastReport()?.params?.state_labels !== undefined, 1500);
  await fire("session_shutdown", { reason: "quit" }, ctx(entries));
  await waitFor(() => lastReport()?.params?.clear_state_labels === true, 1500);
  check("S6 quit clears the labels", lastReport()?.params?.clear_state_labels === true, JSON.stringify(lastReport()?.params));
}

// S4: a headless session never reports.
{
  const { pi, fire } = fakePi();
  const entries = [registryEntry([{ path: "/root/alpha", state: "running" }])];
  withEnv(
    { HERDR_ENV: "1", HERDR_SOCKET_PATH: socketPath, HERDR_PANE_ID: "w9:p2" },
    () => createSubagentsRunningExtension(pi, { refreshIntervalMs: 20 }),
  );
  const before = requests.length;
  await fire("session_start", { reason: "start" }, { mode: "print", isIdle: () => true, sessionManager: { getEntries: () => entries } });
  await fire("agent_settled", {}, { mode: "print", isIdle: () => true, sessionManager: { getEntries: () => entries } });
  await Bun.sleep(60);
  check("S4 headless session never reports", requests.length === before, String(requests.length - before));
}

check("default export is a function", typeof herdrSubagentsRunning === "function");
server.close();

console.log(`\n${passed} passed, ${failures.length} failed`);
for (const failure of failures) console.log(`  FAIL  ${failure}`);
process.exit(failures.length === 0 ? 0 : 1);
