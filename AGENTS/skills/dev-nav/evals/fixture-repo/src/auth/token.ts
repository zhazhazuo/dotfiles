// Token minting for the auth middleware. Bearer tokens are opaque here.
const issued = new Map<string, string>();

export function mint(userId: string): string {
  const token = `tok_${Buffer.from(userId).toString("base64url")}_${issued.size + 1}`;
  issued.set(token, userId);
  return token;
}

export function verify(token: string): string | null {
  return issued.get(token) ?? null;
}

export function revoke(token: string): void {
  issued.delete(token);
}
