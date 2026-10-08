// Retry helper, eval fixture only. The retry storm bug lives here.
export type Attempt = { ok: boolean; at: number };

export function shouldRetry(attempts: Attempt[], maxAttempts: number): boolean {
  if (attempts.length >= maxAttempts) return false;
  const last = attempts.at(-1);
  if (!last) return true;
  return !last.ok;
}

export function backoffMs(attempts: Attempt[]): number {
  return 100 * attempts.length;
}
