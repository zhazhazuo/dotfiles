/**
 * Read one Pi session file and print what the `subagents-running` bridge would
 * report for it. Run with:
 *
 *   bun pi/extensions/__tests__/inspect-session-subagents.ts <session.jsonl> [...]
 *
 * Why this exists: the bridge reads a session entry whose shape belongs to
 * pi-subagent-manager, not to this repository. When the producer changes that
 * shape, the symptom is only "the item is not orange", and the session file is
 * the evidence. This script replays the journal with the bridge's own replay and
 * prints the thread states it derives, so a producer change shows up as data.
 *
 * `count 0` on a session that visibly has running subagents is the failure this
 * script exists to expose.
 */
import { readFileSync } from "node:fs";

import {
  SUBAGENT_REGISTRY_ENTRY,
  buildSubagentStateLabels,
  replayRegistryThreads,
  runningSubagentsFromEntries,
} from "../herdr-subagents-running.ts";

/** Every registry entry of one session file, in append order, plus its root session id. */
function loadRegistry(file: string): { entries: unknown[]; rootSessionId?: string } {
  const entries: unknown[] = [];
  let rootSessionId: string | undefined;
  for (const line of readFileSync(file, "utf8").split("\n")) {
    if (!line.trim()) continue;
    let record: { customType?: unknown; data?: { rootSessionId?: unknown } };
    try {
      record = JSON.parse(line);
    } catch {
      continue;
    }
    if (record?.customType !== SUBAGENT_REGISTRY_ENTRY) continue;
    entries.push(record);
    if (typeof record.data?.rootSessionId === "string") rootSessionId = record.data.rootSessionId;
  }
  return { entries, rootSessionId };
}

const files = process.argv.slice(2);
if (!files.length) {
  console.error("usage: bun pi/extensions/__tests__/inspect-session-subagents.ts <session.jsonl> [...]");
  process.exit(2);
}

let failures = 0;
for (const file of files) {
  const { entries, rootSessionId } = loadRegistry(file);
  const threads = replayRegistryThreads(entries, rootSessionId);
  const running = runningSubagentsFromEntries(entries, rootSessionId);
  const labels = buildSubagentStateLabels(running, 0);

  const counts = threads.reduce<Record<string, number>>((totals, thread) => {
    totals[thread.state] = (totals[thread.state] ?? 0) + 1;
    return totals;
  }, {});

  const newest = (entries[entries.length - 1] as { data?: { kind?: unknown } } | undefined)?.data;
  const newestThreads = (newest as { threads?: unknown } | undefined)?.threads;

  console.log(`\n${file}`);
  console.log(`  registry entries: ${entries.length}  root session: ${rootSessionId ?? "-"}`);
  console.log(`  newest entry kind: ${String(newest?.kind ?? "v1 snapshot")}`);
  console.log(
    `  journal states: ${
      Object.entries(counts)
        .map(([state, count]) => `${state}=${count}`)
        .join(" ") || "none"
    }`,
  );
  for (const thread of threads)
    console.log(`    ${thread.state.padEnd(9)} ${thread.path}`);
  console.log(`  bridge: count=${running.count} names=[${running.names.join(", ")}]`);
  console.log(`  label: ${running.count ? labels.idle : "(cleared)"}`);

  // A journal whose newest entry is a delta can hide running threads from a
  // reader of the newest entry alone. That difference is the regression this
  // script reports; it does not fail, because a delta journal is the normal state.
  if (!Array.isArray(newestThreads) && running.count > 0)
    console.log("  note: newest entry is a delta — a newest-entry-only reader reports 0");

  // No registry entry at all means the producer renamed the entry or this is the
  // wrong file; both make the bridge silent, which is worth a non-zero exit.
  if (!entries.length) {
    console.log("  FAIL: no pi-subagent:registry:v1 entry in this session");
    failures++;
  }
}

process.exit(failures === 0 ? 0 : 1);
