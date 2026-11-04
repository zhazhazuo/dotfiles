/**
 * subagent-registry — read which background subagent threads are still running
 *
 * The pi-subagent-manager keeps every thread of a root session in one session
 * entry, `pi-subagent:registry:v1`. Version 1 writes a full snapshot per change;
 * version 2 writes one base snapshot and then only the threads that changed, so
 * the newest entry alone is not the current list and the journal must be replayed
 * in append order.
 *
 * Two bridges read this registry and publish the count to the terminal that owns
 * the block: herdr-subagents-running for Herdr pane metadata, and
 * rex-subagents-running for the Rex terminal title. Both need the same replay, so
 * it lives here.
 */

/** pi-subagent-manager's session entry holding every thread of this root. */
export const SUBAGENT_REGISTRY_ENTRY = "pi-subagent:registry:v1";
/** Thread states that still count as running. */
export const RUNNING_THREAD_STATES = new Set(["starting", "running"]);

export type RunningSubagents = {
  count: number;
  names: string[];
};

/** A saved thread as far as a bridge needs it: its path and its state. */
export type RegistryThread = { path: string; state: string };

/** Last path segment of a thread, e.g. `/root/ai-report-e2e` -> `ai-report-e2e`. */
export function threadNameFromPath(path: unknown): string | undefined {
  if (typeof path !== "string") return undefined;
  const trimmed = path.trim();
  if (!trimmed) return undefined;
  const parts = trimmed.split(/[\\/]/);
  return parts[parts.length - 1] || undefined;
}

/**
 * Apply one thread update from a registry entry.
 *
 * A delta upsert carries either the whole `SavedThread` or only `{ view }` when
 * the definition is already on the branch. Both state the view, so both land here.
 */
function applyThreadView(threads: Map<string, string>, update: unknown): void {
  const view = (update as { view?: { path?: unknown; state?: unknown } } | undefined)?.view;
  if (!view || typeof view.path !== "string" || !view.path) return;
  if (typeof view.state !== "string") return;
  threads.set(view.path, view.state);
}

/**
 * Rebuild the thread list by replaying the registry journal in append order.
 *
 * An entry written by another root session resets the replay: a forked session
 * owns a new registry and must not adopt its parent's threads.
 */
export function replayRegistryThreads(entries: unknown[], rootSessionId?: string): RegistryThread[] {
  let threads = new Map<string, string>();

  for (const entry of entries ?? []) {
    const record = entry as { customType?: unknown; data?: unknown } | undefined;
    if (record?.customType !== SUBAGENT_REGISTRY_ENTRY) continue;

    const data = record.data as
      | {
          version?: unknown;
          rootSessionId?: unknown;
          kind?: unknown;
          threads?: unknown;
          upserts?: unknown;
          removals?: unknown;
        }
      | undefined;
    if (!data || typeof data !== "object") continue;

    if (typeof data.rootSessionId === "string" && rootSessionId && data.rootSessionId !== rootSessionId) {
      threads = new Map();
      continue;
    }

    if (data.version === 1 || (data.version === 2 && data.kind === "base")) {
      threads = new Map();
      if (Array.isArray(data.threads)) for (const thread of data.threads) applyThreadView(threads, thread);
      continue;
    }

    if (data.version !== 2 || data.kind !== "delta") continue;

    if (Array.isArray(data.upserts)) for (const update of data.upserts) applyThreadView(threads, update);
    if (Array.isArray(data.removals))
      for (const path of data.removals) if (typeof path === "string") threads.delete(path);
  }

  return [...threads].map(([path, state]) => ({ path, state }));
}

/**
 * Count subagent threads still running, by replaying the registry journal.
 *
 * Pass the session id so entries written by another session (a fork) are excluded.
 */
export function runningSubagentsFromEntries(entries: unknown[], rootSessionId?: string): RunningSubagents {
  const names: string[] = [];
  for (const thread of replayRegistryThreads(entries, rootSessionId)) {
    if (!RUNNING_THREAD_STATES.has(thread.state)) continue;
    const name = threadNameFromPath(thread.path);
    if (name) names.push(name);
  }
  return { count: names.length, names };
}

/** Compact `m:ss` / `h:mm:ss` clock; changes every second so a refresh always differs. */
export function formatElapsedClock(elapsedSeconds: number): string {
  const total = Math.max(0, Math.floor(elapsedSeconds));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = total % 60;
  const pad = (value: number) => String(value).padStart(2, "0");
  return hours > 0 ? `${hours}:${pad(minutes)}:${pad(seconds)}` : `${minutes}:${pad(seconds)}`;
}
