// Span helper. Timings are exported as counters; nothing here talks to a network.
type Span = { name: string; startedAt: number; endedAt?: number };

const spans: Span[] = [];

export function start(name: string, now = Date.now()): Span {
  const span = { name, startedAt: now };
  spans.push(span);
  return span;
}

export function end(span: Span, now = Date.now()): number {
  span.endedAt = now;
  return now - span.startedAt;
}

export function counters(): Record<string, number> {
  const out: Record<string, number> = {};
  for (const span of spans) {
    if (span.endedAt === undefined) continue;
    out[span.name] = (out[span.name] ?? 0) + (span.endedAt - span.startedAt);
  }
  return out;
}
