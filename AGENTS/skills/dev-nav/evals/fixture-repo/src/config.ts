// Runtime configuration, read from the environment once.
import { parseValue, toMillis } from "./parser.ts";

export type Config = {
  port: number;
  cacheTtlMs: number;
  poolSize: number;
  logLevel: string;
};

export function load(env: Record<string, string | undefined> = {}): Config {
  return {
    port: Number(env.PORT ?? 8080),
    cacheTtlMs: toMillis(parseValue(env.CACHE_TTL ?? "60s")),
    poolSize: Math.floor(parseValue(env.POOL_SIZE ?? "10").value),
    logLevel: env.LOG_LEVEL ?? "info",
  };
}
