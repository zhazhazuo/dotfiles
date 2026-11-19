// Auth middleware. The session store is wired here, through session.ts.
import { readSession } from "../session.ts";
import { verify } from "./token.ts";

export type Request = { headers: Record<string, string> };

export type Identity = { userId: string; via: "session" | "token" };

function bearer(headers: Record<string, string>): string {
  const raw = headers["authorization"] ?? "";
  return raw.startsWith("Bearer ") ? raw.slice(7) : "";
}

export function identify(request: Request): Identity | null {
  const value = bearer(request.headers);
  if (!value) return null;
  const userId = verify(value);
  if (userId) return { userId, via: "token" };
  const session = readSession(value);
  return session ? { userId: session.userId, via: "session" } : null;
}

export function requireIdentity(request: Request): Identity {
  const identity = identify(request);
  if (!identity) throw new Error("unauthenticated");
  return identity;
}
