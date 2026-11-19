type Entry<T> = { value: T; at: number };
const store = new Map<string, Entry<unknown>>();
const TTL_MS = 60_000;
export function cacheKey(tenantId: string, page: number): string {
  return `tenant:${tenantId}:invoices:${page}`;
}
export function read<T>(key: string, now = Date.now()): T | null {
  const found = store.get(key);
  if (!found || now - found.at > TTL_MS) return null;
  return found.value as T;
}
export function write<T>(key: string, value: T, now = Date.now()): void {
  store.set(key, { value, at: now });
}
