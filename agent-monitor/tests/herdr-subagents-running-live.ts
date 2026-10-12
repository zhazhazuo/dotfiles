/**
 * Live check: herdr pore -> plugin -> adapter -> monitor store, for the
 * `subagents-running` bridge labels.
 *
 * The hermetic suites pin each half of the chain separately
 * (`pi/extensions/__tests__/herdr-subagents-running.test.ts` for the producer,
 * `tests/herdr-adapter.test.sh` for the consumer). This script proves the halves
 * are actually joined by Herdr: it reports the producer's real label on a *live*
 * parked Herdr pane and waits for the monitor store to flip, then clears the
 * label and waits for it to flip back.
 *
 * It is NOT part of the hermetic suite — it needs a running Herdr and a parked
 * (done/idle) pane, and it briefly changes that pane's monitor item. Run:
 *
 *   bun tests/herdr-subagents-running-live.ts <pane-id>
 *
 * The pane must be `done` or `idle` in `herdr api snapshot`; the receiver maps
 * `working`/`blocked` to their own states and would ignore the labels.
 */
import net from "node:net";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

import {
  HERDR_SOURCE,
  buildSubagentMetadataReport,
  buildSubagentStateLabels,
} from "../../pi/extensions/herdr-subagents-running.ts";

const PANE_ID = process.argv[2];
const PROBE_THREADS = ["alpha", "beta", "gamma"];
const PROBE_ELAPSED_SECONDS = 45;

if (!PANE_ID) {
  console.error("usage: bun tests/herdr-subagents-running-live.ts <pane-id>");
  process.exit(2);
}

const socketPath = process.env.HERDR_SOCKET_PATH;
if (process.env.HERDR_ENV !== "1" || !socketPath) {
  console.error("not inside Herdr (HERDR_ENV / HERDR_SOCKET_PATH unset)");
  process.exit(2);
}

const stateFile =
  process.env.AGENT_MONITOR_STATE_FILE ??
  join(process.env.XDG_CACHE_HOME ?? join(homedir(), ".cache"), "agent-monitor", "state.json");

const failures: string[] = [];
function check(name: string, ok: boolean, detail?: string): void {
  console.log(`${ok ? "ok  " : "FAIL"} ${name}${ok || !detail ? "" : ` — ${detail}`}`);
  if (!ok) failures.push(name);
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/** Herdr answers one request per connection, so every report gets a fresh socket. */
function report(request: unknown): Promise<boolean> {
  return new Promise((resolve) => {
    let done = false;
    let timeout: ReturnType<typeof setTimeout> | undefined;
    const finish = (ok: boolean) => {
      if (done) return;
      done = true;
      if (timeout) clearTimeout(timeout);
      socket.destroy();
      resolve(ok);
    };
    const socket = net.createConnection(socketPath!);
    socket.on("error", () => finish(false));
    socket.on("connect", () => socket.write(`${JSON.stringify(request)}\n`));
    socket.on("data", () => finish(true));
    socket.on("end", () => finish(false));
    timeout = setTimeout(() => finish(false), 2000);
    timeout.unref?.();
  });
}

function paneSnapshot(): { agent_status?: string } | undefined {
  const output = Bun.spawnSync(["herdr", "api", "snapshot"]).stdout.toString();
  const parsed = JSON.parse(output) as {
    result?: { snapshot?: { agents?: { pane_id?: string; agent_status?: string }[] } };
  };
  return parsed.result?.snapshot?.agents?.find((agent) => agent.pane_id === PANE_ID);
}

function monitorEntry(): { state?: string; subagents_count?: number } | undefined {
  try {
    const state = JSON.parse(readFileSync(stateFile, "utf8")) as {
      agents?: Record<string, { name?: string; state?: string; subagents_count?: number }>;
    };
    const key = PANE_ID.replace(/[^a-zA-Z0-9_]/g, "_");
    return state.agents?.[key];
  } catch {
    return undefined;
  }
}

async function waitForMonitor(
  predicate: (entry: { state?: string; subagents_count?: number }) => boolean,
  ms = 6000,
): Promise<{ state?: string; subagents_count?: number } | undefined> {
  const start = Date.now();
  while (Date.now() - start < ms) {
    const entry = monitorEntry();
    if (entry && predicate(entry)) return entry;
    await sleep(100);
  }
  return monitorEntry();
}

const paneStatus = paneSnapshot()?.agent_status;
if (paneStatus !== "done" && paneStatus !== "idle") {
  console.error(
    paneStatus
      ? `pane ${PANE_ID} is '${paneStatus}'; pick a parked pane (done/idle) — working/blocked win over the labels`
      : `pane ${PANE_ID} has no agent in the Herdr snapshot`,
  );
  process.exit(2);
}
console.log(`pane ${PANE_ID} is '${paneStatus}' — reporting bridge labels from ${HERDR_SOURCE}\n`);

// What the adapter maps this pane to once the labels are gone. `idle` panes go
// back to grey `idle` rather than blue `needs-attention`, so that is the state
// to expect back, not a fixed one.
const parkedState = paneStatus === "done" ? "needs-attention" : "idle";

const labels = buildSubagentStateLabels(
  { count: PROBE_THREADS.length, names: PROBE_THREADS },
  PROBE_ELAPSED_SECONDS,
);
check(
  "producer label parses as the adapter's count",
  /([0-9]+)\s+[Ss]ubagents?/.exec(labels.idle)?.[1] === String(PROBE_THREADS.length),
  labels.idle,
);

try {
  check("herdr accepts the metadata report", await report(buildSubagentMetadataReport(PANE_ID, labels, Date.now())));

  // The adapter writes the state, then the count, as two separate store writes;
  // require both so this does not read between them.
  const parked = await waitForMonitor(
    (entry) => entry.state === "subagents-running" && entry.subagents_count === PROBE_THREADS.length,
  );
  check("monitor flips to subagents-running", parked?.state === "subagents-running", JSON.stringify(parked));
  check("monitor stores the subagent count", parked?.subagents_count === PROBE_THREADS.length, JSON.stringify(parked));

  check("herdr accepts the clear report", await report(buildSubagentMetadataReport(PANE_ID, undefined, Date.now())));

  // Same two-write ordering as above: the state lands before the count clears.
  const cleared = await waitForMonitor(
    (entry) => entry.state === parkedState && entry.subagents_count === 0,
  );
  check(`monitor returns to ${parkedState}`, cleared?.state === parkedState, JSON.stringify(cleared));
  check("monitor resets the subagent count", cleared?.subagents_count === 0, JSON.stringify(cleared));
} finally {
  // Never leave a probe label behind, whatever happened above.
  await report(buildSubagentMetadataReport(PANE_ID, undefined, Date.now()));
}

console.log(`\n${failures.length === 0 ? "PASS" : "FAIL"} — ${failures.length} failed`);
process.exit(failures.length === 0 ? 0 : 1);
