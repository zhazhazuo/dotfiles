export type ParsedValue = { value: number; unit: string };
const UNITS = ["ms", "s", "m", "h"];
export function parseValue(raw: string): ParsedValue {
  const match = /^(-?\d+(?:\.\d+)?)\s*([a-z]*)$/.exec(raw.trim());
  if (!match) throw new Error(`cannot parse value: ${raw}`);
  const unit = match[2] || "";
  if (unit && !UNITS.includes(unit)) throw new Error(`unknown unit: ${unit}`);
  return { value: Number(match[1]), unit };
}
