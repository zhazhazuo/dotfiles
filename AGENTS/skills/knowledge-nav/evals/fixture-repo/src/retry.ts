export type Attempt = { ok: boolean; at: number };
const MAX_ATTEMPTS = 3;
export function shouldRetry(attempts: Attempt[]): boolean {
  return attempts.length < MAX_ATTEMPTS && !attempts.at(-1)?.ok;
}
export function backoffMs(attempts: Attempt[]): number {
  return 100 * 2 ** attempts.length;
}
