// Cache for the invoice list. Decisions are in docs/decisions/caching.md and are not ratified.
import { readSession } from "./session.ts";

type Entry<T> = { value: T; at: number };

const store = new Map<string, Entry<unknown>>();
const TTL_MS = 60_000;

export function cacheKey(tenantId: string, page: number): string {
  return `tenant:${tenantId}:invoices:${page}`;
}

export function read<T>(key: string, now = Date.now()): T | null {
  const found = store.get(key);
  if (!found) return null;
  if (now - found.at > TTL_MS) {
    store.delete(key);
    return null;
  }
  return found.value as T;
}

export function write<T>(key: string, value: T, now = Date.now()): void {
  store.set(key, { value, at: now });
}

export function invalidateTenant(tenantId: string): number {
  let removed = 0;
  for (const key of [...store.keys()]) {
    if (key.startsWith(`tenant:${tenantId}:invoices:`)) {
      store.delete(key);
      removed += 1;
    }
  }
  return removed;
}

export function scopeFor(headers: Record<string, string>): string | null {
  return readSession(headers["authorization"]?.slice(7) ?? "") ? "tenant" : null;
}
