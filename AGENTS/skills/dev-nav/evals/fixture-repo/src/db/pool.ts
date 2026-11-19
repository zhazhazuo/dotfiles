// Connection pool. One pool per process, created on first use.
import { parseValue, toMillis } from "../parser.ts";

export type Connection = { id: number; open: boolean };

const pool: Connection[] = [];
let limit = 10;

export function configure(maxConnections: string): void {
  limit = Math.max(1, Math.floor(parseValue(maxConnections).value));
}

export function idleTimeout(): number {
  return toMillis(parseValue("30s"));
}

export function acquire(): Connection {
  const free = pool.find((connection) => !connection.open);
  if (free) {
    free.open = true;
    return free;
  }
  if (pool.length >= limit) throw new Error("pool exhausted");
  const created = { id: pool.length + 1, open: true };
  pool.push(created);
  return created;
}

export function release(connection: Connection): void {
  connection.open = false;
}
