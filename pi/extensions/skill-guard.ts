/**
 * skill-guard — silence third-party package skills, except the ones you allow.
 *
 * Why this exists
 * ---------------
 * pi has no "disable this skill" setting. The settings package filter
 * (`packages[].skills`) *unloads* a skill: it disappears from the system
 * prompt AND loses its `/skill:name` command. The only mechanism that hides a
 * skill from the model while keeping it registered is the frontmatter field
 * `disable-model-invocation: true`.
 *
 * For third-party packages that patch lives in files we do not own, so a
 * package update wipes it (npm packages are re-extracted, git packages are
 * reset to the upstream tree). This extension re-asserts the flag at session
 * start. pi emits `session_start` -> `resources_discover` -> then scans skill
 * locations for the system prompt, so a repair made here lands in the session
 * that is starting, not the next one.
 *
 * Policy: silent by default, allow by exception
 * ---------------------------------------------
 * Every skill a configured package provides is silenced, except the ones you
 * name in `skillGuard.keepVisible` in global settings.json:
 *
 *   "skillGuard": {
 *     "keepVisible": [
 *       "npm:pi-subagents",                  // a whole package stays visible
 *       "npm:pi-lens",
 *       "~/Research/pi-thing/skills/one"     // or a single skill / directory
 *     ]
 *   }
 *
 * Entries are package sources (the same strings `packages[]` uses) or paths;
 * both resolve to an absolute root, and any skill under that root is allowed.
 * An entry naming a user-owned skill (anything outside the packages pi
 * installs) is a valid declaration of intent but has no effect here: this
 * extension only ever touches skills that a package update can overwrite.
 *
 * The scan universe is every package listed in `packages[]`: the skill roots
 * its manifest declares (`pi.skills`) plus its conventional `skills/`
 * directory. The settings `skills` filter is deliberately ignored — pi-lens
 * injects its skills through `resources_discover` and so bypasses the filter,
 * which means the filter is not a reliable indicator of what pi loads.
 * Packages installed but not configured are not touched, because pi does not
 * load them.
 *
 * A whitelisted skill that still carries the flag is reported as a conflict
 * rather than rewritten: the flag may be the package author's own intent, and
 * overriding upstream is not this extension's call.
 *
 * Behaviour: repair, then notify. Fail-open — any error leaves files
 * untouched rather than half-written. Run `/skill-guard` to re-check without
 * restarting pi.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync, readFileSync, readdirSync, renameSync, statSync, unlinkSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

const FLAG = "disable-model-invocation";
const MAX_DEPTH = 6;
const SKIP_DIRS = new Set(["node_modules", ".git"]);

// ─── paths ──────────────────────────────────────────────────────────────────

/** pi's config directory: $PI_CODING_AGENT_DIR, else ~/.pi/agent. */
function getAgentDir(): string {
  const fromEnv = process.env.PI_CODING_AGENT_DIR?.trim();
  if (fromEnv) return expandTilde(fromEnv);
  return join(homedir(), ".pi", "agent");
}

function expandTilde(input: string): string {
  if (input === "~") return homedir();
  if (input.startsWith("~/")) return join(homedir(), input.slice(2));
  return input;
}

type ParsedSource =
  | { type: "npm"; name: string }
  | { type: "git"; host: string; path: string }
  | { type: "local"; path: string };

/**
 * Mirror of pi's `isLocalPath`: anything without a known scheme is a path.
 * Exported with the rest of the pure helpers so the repair logic can be
 * exercised without a live pi session: see __tests__/skill-guard.test.ts.
 */
export function parseSource(source: string): ParsedSource {
  const trimmed = source.trim();
  if (trimmed.startsWith("npm:")) return { type: "npm", name: parseNpmName(trimmed.slice(4)) };
  if (!/^(npm:|git:|github:|https?:|ssh:)/.test(trimmed)) return { type: "local", path: trimmed };
  const git = parseGitSource(trimmed);
  return git ?? { type: "local", path: trimmed };
}

/** `@scope/pkg@1.2.3` -> `@scope/pkg`, `pkg@1.2.3` -> `pkg`. */
function parseNpmName(spec: string): string {
  const trimmed = spec.trim();
  if (trimmed.startsWith("@")) {
    const at = trimmed.indexOf("@", 1);
    return at === -1 ? trimmed : trimmed.slice(0, at);
  }
  const at = trimmed.indexOf("@");
  return at === -1 ? trimmed : trimmed.slice(0, at);
}

/** Understands `git:host/owner/repo`, `https://host/owner/repo`, `git@host:owner/repo`. */
function parseGitSource(source: string): { type: "git"; host: string; path: string } | null {
  let rest = source.startsWith("git:") ? source.slice(4) : source;
  rest = rest.replace(/@[^/@]+$/, ""); // drop a trailing @ref, if any

  let host: string;
  let path: string;

  // Scheme URLs first: `ssh://git@host:2222/group/repo` must not be read as
  // an scp-style `host:path` pair (the port would land in the path).
  const urlLike = rest.match(/^(?:https?|ssh|git):\/\/(?:[^@/]+@)?([^/:]+)(?::\d+)?\/(.+)$/);
  const scpLike = rest.match(/^(?:git@|ssh:\/\/git@)([^/:]+)[/:](.+)$/);
  if (urlLike) {
    host = urlLike[1];
    path = urlLike[2];
  } else if (scpLike) {
    host = scpLike[1];
    path = scpLike[2];
  } else {
    const shorthand = rest.match(/^([^/]+)\/(.+)$/);
    if (!shorthand) return null;
    host = shorthand[1];
    path = shorthand[2];
  }

  path = path.replace(/\.git$/, "").replace(/\/+$/, "");
  if (!host || !path) return null;
  return { type: "git", host, path };
}

/**
 * Resolve a package source to its installed directory, using pi's layout.
 * Returns undefined when nothing is installed for that source.
 */
export function resolvePackageDir(source: string, agentDir: string): string | undefined {
  const parsed = parseSource(source);
  if (parsed.type === "local") {
    const candidate = resolve(agentDir, expandTilde(parsed.path));
    return existsSync(candidate) ? candidate : undefined;
  }
  if (parsed.type === "git") {
    const candidate = join(agentDir, "git", parsed.host, parsed.path);
    return existsSync(candidate) ? candidate : undefined;
  }
  // npm: pi-managed install first, then the legacy global install pi falls back to.
  const managed = join(agentDir, "npm", "node_modules", parsed.name);
  if (existsSync(managed)) return managed;
  const legacyBun = join(homedir(), ".bun", "install", "global", "node_modules", parsed.name);
  if (existsSync(legacyBun)) return legacyBun;
  return undefined;
}

/**
 * Skill roots a package contributes: its declared `pi.skills` entries, plus a
 * conventional `skills/` directory when present. Declared entries win; the
 * fallback is what catches skills an extension injects at runtime, which the
 * package manifest may not list.
 */
export function packageSkillRoots(pkgDir: string): string[] {
  const roots: string[] = [];
  try {
    const manifest = JSON.parse(readFileSync(join(pkgDir, "package.json"), "utf-8")) as {
      pi?: { skills?: unknown };
    };
    const declared = manifest.pi?.skills;
    if (Array.isArray(declared)) {
      for (const entry of declared) {
        if (typeof entry === "string" && entry.trim() !== "") roots.push(resolve(pkgDir, entry));
      }
    }
  } catch {
    // No or unreadable manifest — fall through to the conventional directory.
  }
  const conventional = join(pkgDir, "skills");
  if (existsSync(conventional) && !roots.includes(conventional)) roots.push(conventional);
  return roots;
}

/** Collect SKILL.md files under a skill root (a directory) or the file itself. */
function collectSkillFiles(target: string, out: string[], problems: string[], depth = 0): void {
  let stats;
  try {
    stats = statSync(target);
  } catch {
    // A manifest may declare a root that does not exist; that is the package's
    // problem, not a configuration problem worth reporting every session.
    return;
  }
  if (stats.isFile()) {
    if (target.endsWith(".md")) out.push(target);
    return;
  }
  if (!stats.isDirectory() || depth > MAX_DEPTH) return;

  const marker = join(target, "SKILL.md");
  if (existsSync(marker)) out.push(marker);

  let entries;
  try {
    entries = readdirSync(target, { withFileTypes: true });
  } catch {
    return;
  }
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    if (SKIP_DIRS.has(entry.name) || entry.name.startsWith(".")) continue;
    collectSkillFiles(join(target, entry.name), out, problems, depth + 1);
  }
}

// ─── frontmatter ────────────────────────────────────────────────────────────

/**
 * Return `content` with `disable-model-invocation: true` in its frontmatter,
 * changing nothing else: BOM, line endings, key order and trailing bytes are
 * preserved. Files without frontmatter are returned untouched.
 *
 * The flag is inserted after `name:` when present (matching the historical
 * manual patch), otherwise directly before the closing fence.
 */
export function ensureSilent(content: string): { content: string; changed: boolean } {
  const fence = content.match(/^(?:\uFEFF)?---[ \t]*(\r?\n)/);
  if (!fence) return { content, changed: false };

  const eol = fence[1];
  const bodyStart = fence[0].length;

  type Line = { start: number; end: number; text: string; eol: string };
  const lines: Line[] = [];
  let closeStart = -1;

  for (const match of content.slice(bodyStart).matchAll(/[^\n]*\n?/g)) {
    const raw = match[0];
    if (raw === "") break;
    const start = bodyStart + (match.index ?? 0);
    const text = raw.replace(/\r?\n$/, "");
    if (/^---[ \t]*$/.test(text)) {
      closeStart = start;
      break;
    }
    lines.push({ start, end: start + raw.length, text, eol: raw.slice(text.length) });
  }

  if (closeStart === -1) return { content, changed: false };

  const flagLine = lines.find((line) => new RegExp(`^${FLAG}\\s*:`).test(line.text));
  if (flagLine) {
    const value = flagLine.text.slice(flagLine.text.indexOf(":") + 1).trim();
    if (value === "true") return { content, changed: false };
    return {
      content: content.slice(0, flagLine.start) + `${FLAG}: true` + flagLine.eol + content.slice(flagLine.end),
      changed: true,
    };
  }

  const nameLine = lines.find((line) => /^name\s*:/.test(line.text));
  const insertAt = nameLine ? nameLine.end : closeStart;
  return {
    content: content.slice(0, insertAt) + `${FLAG}: true${eol}` + content.slice(insertAt),
    changed: true,
  };
}

/** Whether the frontmatter already declares the silent flag. */
export function isSilenced(content: string): boolean {
  const fence = content.match(/^(?:\uFEFF)?---[ \t]*(\r?\n)/);
  if (!fence) return false;
  const body = content.slice(fence[0].length);
  const end = body.search(/^---[ \t]*$/m);
  const frontmatter = end === -1 ? body : body.slice(0, end);
  return new RegExp(`^${FLAG}\\s*:\\s*true\\s*$`, "m").test(frontmatter);
}

/** Replace a file atomically, preserving its permission bits. */
function writeAtomic(file: string, content: string): void {
  const stats = statSync(file);
  const tmp = `${file}.skill-guard.${process.pid}.tmp`;
  try {
    writeFileSync(tmp, content, { mode: stats.mode });
    renameSync(tmp, file);
  } catch (error) {
    try {
      unlinkSync(tmp);
    } catch {
      // Nothing to clean up.
    }
    throw error;
  }
}

// ─── policy and enforcement ─────────────────────────────────────────────────

type Settings = { keepVisible: string[]; packages: string[] };
export type Report = {
  scanned: number;
  silenced: string[];
  conflicts: string[];
  problems: string[];
};

function readSettings(agentDir: string): Settings {
  const settingsPath = join(agentDir, "settings.json");
  const empty: Settings = { keepVisible: [], packages: [] };

  let raw: string;
  try {
    raw = readFileSync(settingsPath, "utf-8");
  } catch (error) {
    // No settings file yet (fresh install) is a legitimate empty policy; any
    // other read failure is worth reporting.
    if ((error as NodeJS.ErrnoException)?.code === "ENOENT") return empty;
    throw error;
  }

  let parsed: { skillGuard?: { keepVisible?: unknown }; packages?: unknown };
  try {
    parsed = JSON.parse(raw) as typeof parsed;
  } catch (error) {
    throw new Error(`invalid JSON: ${message(error)}`);
  }

  const strings = (value: unknown): string[] =>
    Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === "string" && entry.trim() !== "") : [];

  const packages: string[] = [];
  if (Array.isArray(parsed.packages)) {
    for (const entry of parsed.packages) {
      if (typeof entry === "string") packages.push(entry);
      else if (entry && typeof entry === "object" && typeof (entry as { source?: unknown }).source === "string") {
        packages.push((entry as { source: string }).source);
      }
    }
  }

  return { keepVisible: strings(parsed.skillGuard?.keepVisible), packages };
}

/** Display path for messages: agent-dir-relative where possible. */
function displayPath(file: string, agentDir: string): string {
  return file.startsWith(`${agentDir}/`) ? `~/.pi/agent/${file.slice(agentDir.length + 1)}` : file;
}

/**
 * Silence every skill a configured package provides unless the whitelist
 * allows it. Never throws: failures are collected in `problems`.
 */
export function run(agentDir: string): Report {
  let settings: Settings;
  try {
    settings = readSettings(agentDir);
  } catch (error) {
    return {
      scanned: 0,
      silenced: [],
      conflicts: [],
      problems: [`cannot read ${displayPath(join(agentDir, "settings.json"), agentDir)}: ${message(error)}`],
    };
  }

  const problems: string[] = [];

  // Whitelist entries resolve to absolute roots; any skill beneath one is allowed.
  const allowedRoots: string[] = [];
  for (const entry of settings.keepVisible) {
    const asPackage = resolvePackageDir(entry, agentDir);
    const asPath = asPackage ?? resolve(agentDir, expandTilde(entry));
    if (asPackage ?? existsSync(asPath)) allowedRoots.push(asPath);
    else problems.push(`whitelist entry not found: ${entry}`);
  }
  const isAllowed = (file: string): boolean =>
    allowedRoots.some((root) => file === root || file.startsWith(`${root}/`));

  const targets: string[] = [];
  for (const source of new Set(settings.packages)) {
    const pkgDir = resolvePackageDir(source, agentDir);
    // A configured package that is not installed contributes nothing; pi
    // installs those itself, so this is not a configuration error.
    if (!pkgDir) continue;
    for (const root of packageSkillRoots(pkgDir)) collectSkillFiles(root, targets, problems);
  }

  const silenced: string[] = [];
  const conflicts: string[] = [];
  const files = [...new Set(targets)];

  for (const file of files) {
    try {
      const original = readFileSync(file, "utf-8");

      if (isAllowed(file)) {
        // Whitelisted: never added to, and never stripped of, the flag. An
        // existing flag may be the author's intent, so report instead of
        // overriding upstream.
        if (isSilenced(original)) conflicts.push(displayPath(file, agentDir));
        continue;
      }

      const { content, changed } = ensureSilent(original);
      if (!changed) continue;
      writeAtomic(file, content);
      silenced.push(displayPath(file, agentDir));
    } catch (error) {
      problems.push(`cannot patch ${displayPath(file, agentDir)}: ${message(error)}`);
    }
  }

  return { scanned: files.length, silenced, conflicts, problems };
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/**
 * Subagent children run their own session_start. They still enforce (the write
 * is idempotent and atomic) but stay quiet — their parent owns the UI.
 */
function inSubagent(): boolean {
  return Boolean(process.env.PI_SUBAGENT_CHILD) || Boolean(process.env.PI_SUBAGENT_PARENT_SESSION);
}

function names(files: string[], limit: number): string {
  const short = files.map((file) => dirname(file).split("/").pop() ?? file);
  const shown = short.slice(0, limit).join(", ");
  return short.length > limit ? `${shown} (+${short.length - limit})` : shown;
}

export function summarise(report: Report): { text: string; type: "info" | "warning" } | undefined {
  const { silenced, conflicts, problems } = report;
  const footnote = silenced.length > 0 ? ` Silenced ${silenced.length}: ${names(silenced, 3)}.` : "";

  if (problems.length > 0) {
    const detail = problems.slice(0, 3).join("; ");
    const more = problems.length > 3 ? ` (+${problems.length - 3} more)` : "";
    const alsoConflicts = conflicts.length > 0 ? ` ${conflicts.length} whitelisted skill(s) still silenced.` : "";
    return {
      text: `skill-guard: ${problems.length} configuration problem(s) — ${detail}${more}.${alsoConflicts}${footnote}`,
      type: "warning",
    };
  }

  if (conflicts.length > 0) {
    return {
      text: `skill-guard: whitelisted but still silenced — ${names(conflicts, 4)}. Remove the flag or drop the entry from keepVisible.${footnote}`,
      type: "warning",
    };
  }

  if (silenced.length > 0) {
    return {
      text: `skill-guard: silenced ${silenced.length} package skill(s) not on the whitelist — ${names(silenced, 4)}`,
      type: "info",
    };
  }

  return undefined;
}

// ─── extension ──────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    try {
      const report = run(getAgentDir());
      if (inSubagent() || !ctx.hasUI) return;
      const summary = summarise(report);
      if (summary) ctx.ui.notify(summary.text, summary.type);
    } catch (error) {
      // Fail-open: a guard must never block or break session startup.
      console.error("[skill-guard] unexpected error; leaving skills untouched", error);
    }
  });

  pi.registerCommand("skill-guard", {
    description: "Silence package skills that are not on the keepVisible whitelist, and report drift",
    handler: async (_args, ctx) => {
      const report = run(getAgentDir());
      const summary = summarise(report);
      ctx.ui.notify(
        summary?.text ??
          `skill-guard: ${report.scanned} package skill(s) checked, all silent but for the whitelist`,
        summary?.type ?? "info",
      );
    },
  });
}
