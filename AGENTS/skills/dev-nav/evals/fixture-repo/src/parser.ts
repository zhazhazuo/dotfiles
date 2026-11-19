// Config value parser. It has no test, and it is the only parser in the tree.
export type ParsedValue = { value: number; unit: string };

const UNITS = ["ms", "s", "m", "h"];

export function parseValue(raw: string): ParsedValue {
  const text = raw.trim();
  const match = /^(-?\d+(?:\.\d+)?)\s*([a-z]*)$/.exec(text);
  if (!match) {
    throw new Error(`cannot parse value: ${text}`);
  }
  const value = Number(match[1]);
  const unit = match[2] || "";
  if (unit && !UNITS.includes(unit)) {
    throw new Error(`unknown unit: ${unit}`);
  }
  return { value, unit };
}

export function toMillis(parsed: ParsedValue): number {
  switch (parsed.unit) {
    case "ms":
      return parsed.value;
    case "s":
      return parsed.value * 1000;
    case "m":
      return parsed.value * 60_000;
    case "h":
      return parsed.value * 3_600_000;
    default:
      return parsed.value;
  }
}
