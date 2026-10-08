// Session store wiring for the auth middleware, eval fixture only.
import { processOrder, type Order } from "./orders.ts";

const sessions = new Map<string, { userId: string; expiresAt: number }>();

export function createSession(userId: string, ttlMs: number): string {
  const id = `sess_${sessions.size + 1}`;
  sessions.set(id, { userId, expiresAt: Date.now() + ttlMs });
  return id;
}

export function readSession(id: string): { userId: string } | null {
  const found = sessions.get(id);
  if (!found) return null;
  if (found.expiresAt < Date.now()) {
    sessions.delete(id);
    return null;
  }
  return { userId: found.userId };
}

export function middleware(headers: Record<string, string>): { userId: string } | null {
  const raw = headers["authorization"] ?? "";
  const id = raw.startsWith("Bearer ") ? raw.slice(7) : "";
  return id ? readSession(id) : null;
}

export function paidOrders(orders: Order[]): Order[] {
  return orders.map(processOrder);
}
