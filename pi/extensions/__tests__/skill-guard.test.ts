/**
 * Test harness for skill-guard. Run with: bun pi/extensions/__tests__/skill-guard.test.ts
 * Exercises the pure logic without a live pi session.
 */
import { mkdtempSync, mkdirSync, symlinkSync, writeFileSync, readFileSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

import {
  ensureSilent,
  isSilenced,
  parseSource,
  resolvePackageDir,
  packageSkillRoots,
  summarise,
  run,
} from "../skill-guard.ts";
import type { Report } from "../skill-guard.ts";

let passed = 0;
const failures: string[] = [];

function check(name: string, condition: boolean, detail?: string): void {
  if (condition) {
    passed++;
  } else {
    failures.push(`${name}${detail ? ` — ${detail}` : ""}`);
  }
}

function eq(name: string, actual: unknown, expected: unknown): void {
  check(name, JSON.stringify(actual) === JSON.stringify(expected), `got ${JSON.stringify(actual)}, want ${JSON.stringify(expected)}`);
}

// ── ensureSilent: insertion ────────────────────────────────────────────────

const plain = `---\nname: brainstorming\ndescription: Use when brainstorming.\n---\n\n# Body\n`;
const inserted = ensureSilent(plain);
eq("insert after name", inserted.content.split("\n").slice(0, 5), [
  "---",
  "name: brainstorming",
  "disable-model-invocation: true",
  "description: Use when brainstorming.",
  "---",
]);
check("insert reports changed", inserted.changed);
eq("body untouched", inserted.content.split("\n").slice(6), plain.split("\n").slice(5));
eq("insert is idempotent", ensureSilent(inserted.content), { content: inserted.content, changed: false });

// already true
eq("flag true is a no-op", ensureSilent(inserted.content).changed, false);

// explicit false -> true
const falsy = `---\nname: x\ndescription: d\ndisable-model-invocation: false\n---\n`;
const flipped = ensureSilent(falsy);
check("flag false is rewritten", flipped.changed && flipped.content.includes("disable-model-invocation: true"));
check("flag false leaves no false", !flipped.content.includes("disable-model-invocation: false"));
check("flag false keeps position", flipped.content.indexOf("disable-model-invocation") > flipped.content.indexOf("description:"));

// no name field -> insert before closing fence
const noName = `---\ndescription: d\n---\nbody`;
eq("insert without name", ensureSilent(noName).content, `---\ndescription: d\ndisable-model-invocation: true\n---\nbody`);

// CRLF preserved
const crlf = `---\r\nname: y\r\ndescription: d\r\n---\r\nbody\r\n`;
const crlfOut = ensureSilent(crlf);
check("crlf preserved", crlfOut.content.includes("disable-model-invocation: true\r\n"), JSON.stringify(crlfOut.content));
check("crlf only crlf", !/[^\r]\n/.test(crlfOut.content.replace(/\r\n/g, "")));

// BOM preserved
const bom = `\uFEFF---\nname: z\ndescription: d\n---\n`;
const bomOut = ensureSilent(bom);
check("bom preserved", bomOut.content.startsWith("\uFEFF---\n"));
check("bom flag inserted", bomOut.content.includes("disable-model-invocation: true"));
check("bom idempotent", !ensureSilent(bomOut.content).changed);

// no frontmatter -> untouched
eq("no frontmatter untouched", ensureSilent("# Just a doc\n"), { content: "# Just a doc\n", changed: false });
eq("unterminated frontmatter untouched", ensureSilent("---\nname: x\n"), { content: "---\nname: x\n", changed: false });

// no trailing newline after fence
const noTrail = `---\nname: n\ndescription: d\n---`;
check("no trailing newline", ensureSilent(noTrail).content === `---\nname: n\ndisable-model-invocation: true\ndescription: d\n---`);

// ── isSilenced ─────────────────────────────────────────────────────────────

check("isSilenced on flagged file", isSilenced(inserted.content));
check("isSilenced on plain file", !isSilenced(plain));
check("isSilenced tolerates spacing", isSilenced(`---\nname: x\ndisable-model-invocation:   true  \n---\n`));
check("isSilenced rejects false", !isSilenced(`---\nname: x\ndisable-model-invocation: false\n---\n`));
check("isSilenced without frontmatter", !isSilenced("# no frontmatter\n"));
check("isSilenced ignores body mention", !isSilenced(`---\nname: x\n---\n\ndisable-model-invocation: true\n`));

// ── parseSource ────────────────────────────────────────────────────────────

eq("npm plain", parseSource("npm:pi-mcp-adapter"), { type: "npm", name: "pi-mcp-adapter" });
eq("npm scoped+version", parseSource("npm:@ff-labs/pi-fff@1.2.3"), { type: "npm", name: "@ff-labs/pi-fff" });
eq("git shorthand", parseSource("git:github.com/obra/superpowers"), { type: "git", host: "github.com", path: "obra/superpowers" });
eq("git shorthand+ref", parseSource("git:github.com/obra/superpowers@v6.3.0"), { type: "git", host: "github.com", path: "obra/superpowers" });
eq("git https", parseSource("https://github.com/ayghri/i-have-adhd"), { type: "git", host: "github.com", path: "ayghri/i-have-adhd" });
eq("git https .git", parseSource("https://github.com/owner/repo.git"), { type: "git", host: "github.com", path: "owner/repo" });
eq("git scp", parseSource("git:git@github.com:owner/repo"), { type: "git", host: "github.com", path: "owner/repo" });
eq("git ssh url", parseSource("ssh://git@gitlab.example.com:2222/group/repo"), { type: "git", host: "gitlab.example.com", path: "group/repo" });
eq("local absolute", parseSource("/Users/x/Research/pi-provider-qoder"), { type: "local", path: "/Users/x/Research/pi-provider-qoder" });
eq("local tilde", parseSource("~/Research/thing"), { type: "local", path: "~/Research/thing" });

// ── run(): default silent, whitelist by exception ──────────────────────────

/**
 * Each scenario gets its own agent dir AND its own global Agent Skills root, so
 * silencing in one scenario cannot leak into the next, and no scenario can reach
 * the real ~/.agents/skills.
 */
function freshAgent(): string {
  const dir = mkdtempSync(join(tmpdir(), "skill-guard-"));
  mkdirSync(join(dir, "agent"), { recursive: true });
  mkdirSync(join(dir, "agent-skills"), { recursive: true });
  return join(dir, "agent");
}

/** The isolated global Agent Skills root that belongs to a scenario's agent dir. */
function scenarioAgentSkillsRoot(agentDir: string): string {
  return join(dirname(agentDir), "agent-skills");
}

/** Run the guard against a scenario's isolated global Agent Skills root. */
function runIsolated(agentDir: string): Report {
  return run(agentDir, { agentSkillsRoot: scenarioAgentSkillsRoot(agentDir) });
}

/** Create a real, non-symlinked skill directory under an Agent Skills root. */
function makeAgentSkill(skillsRoot: string, name: string, silent: boolean): string {
  mkdirSync(join(skillsRoot, name), { recursive: true });
  const file = join(skillsRoot, name, "SKILL.md");
  writeFileSync(
    file,
    `---\nname: ${name}\ndescription: d${silent ? "\ndisable-model-invocation: true" : ""}\n---\n`,
  );
  return file;
}

/** Create a package with named skills; `silent` ones start already flagged. */
function makePackage(
  agentDir: string,
  kind: "npm" | "git",
  source: string,
  skills: Record<string, boolean>,
): string {
  const dir =
    kind === "npm"
      ? join(agentDir, "npm", "node_modules", source.replace(/^npm:/, ""))
      : join(agentDir, "git", "github.com", source.replace(/^git:github\.com\//, ""));
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "package.json"), JSON.stringify({ name: "pkg", pi: { skills: ["./skills"] } }));
  for (const [name, silent] of Object.entries(skills)) {
    mkdirSync(join(dir, "skills", name), { recursive: true });
    writeFileSync(
      join(dir, "skills", name, "SKILL.md"),
      `---\nname: ${name}\ndescription: d${silent ? "\ndisable-model-invocation: true" : ""}\n---\n`,
    );
  }
  return dir;
}

/** A package whose manifest declares a single skill file rather than a directory. */
function makeFilePackage(agentDir: string, name: string, skill: string): string {
  const dir = join(agentDir, "npm", "node_modules", name);
  mkdirSync(join(dir, "skills", skill), { recursive: true });
  writeFileSync(join(dir, "package.json"), JSON.stringify({ name, pi: { skills: [`skills/${skill}/SKILL.md`] } }));
  const file = join(dir, "skills", skill, "SKILL.md");
  writeFileSync(file, `---\nname: ${skill}\ndescription: d\n---\n`);
  return file;
}

function writeSettings(agentDir: string, keepVisible: unknown, packages: unknown): void {
  writeFileSync(join(agentDir, "settings.json"), JSON.stringify({ skillGuard: { keepVisible }, packages }));
}

const read = (file: string): string => readFileSync(file, "utf-8");

// ── scenario: default silent, package-level whitelist ───────────────────────
{
  const agentDir = freshAgent();
  const allowed = makePackage(agentDir, "npm", "npm:allowed-pkg", { open: false });
  const denied = makePackage(agentDir, "npm", "npm:denied-pkg", { hidden: false, already: true });
  const gitPkg = makePackage(agentDir, "git", "git:github.com/owner/repo", { deep: false });
  const oneFile = makeFilePackage(agentDir, "file-pkg", "one");
  makePackage(agentDir, "npm", "npm:not-configured", { untouched: false });

  writeSettings(
    agentDir,
    ["npm:allowed-pkg", "npm:file-pkg"],
    ["npm:allowed-pkg", "npm:denied-pkg", "git:github.com/owner/repo", "npm:file-pkg", "npm:absent-package"],
  );
  const report = runIsolated(agentDir);

  eq("scans every configured package skill", report.scanned, 5);
  eq("silences only the non-whitelisted", report.silenced.length, 2);
  eq("no conflicts or problems", [report.conflicts, report.problems], [[], []]);
  check("non-whitelisted skill silenced", isSilenced(read(join(denied, "skills", "hidden", "SKILL.md"))));
  check("non-whitelisted git skill silenced", isSilenced(read(join(gitPkg, "skills", "deep", "SKILL.md"))));
  check("whitelisted package left alone", !isSilenced(read(join(allowed, "skills", "open", "SKILL.md"))));
  check("whitelisted file-manifest package left alone", !isSilenced(read(oneFile)));
  check("already-flagged skill keeps its flag", isSilenced(read(join(denied, "skills", "already", "SKILL.md"))));
  check(
    "installed but unconfigured package untouched",
    !isSilenced(read(join(agentDir, "npm", "node_modules", "not-configured", "skills", "untouched", "SKILL.md"))),
  );

  const second = runIsolated(agentDir);
  eq("second run silences nothing new", second.silenced, []);
  eq("second run still scans", second.scanned, 5);
}

// ── scenario: whitelisting one skill by path ───────────────────────────────
{
  const agentDir = freshAgent();
  const denied = makePackage(agentDir, "npm", "npm:denied-pkg", { hidden: false, already: true });
  const configured = ["npm:denied-pkg"];
  const allowedSkill = join(denied, "skills", "already");

  // an absolute path entry allows just that skill
  writeSettings(agentDir, [allowedSkill], configured);
  const report = runIsolated(agentDir);

  eq("path entry limits the exception", report.scanned, 2);
  eq("sibling skill still silenced", report.silenced.length, 1);
  check("sibling is the non-whitelisted one", isSilenced(read(join(denied, "skills", "hidden", "SKILL.md"))));
  eq("the allowed skill is a conflict, not a rewrite", report.conflicts.length, 1);
  check("conflict names the whitelisted skill", report.conflicts[0].includes("/already/"), report.conflicts[0]);
  check("conflict leaves the file flagged", isSilenced(read(join(denied, "skills", "already", "SKILL.md"))));
}

// ── scenario: stale and malformed whitelist entries ────────────────────────
{
  const agentDir = freshAgent();
  makePackage(agentDir, "npm", "npm:denied-pkg", { hidden: false });
  const configured = ["npm:denied-pkg"];

  writeSettings(agentDir, ["npm:never-installed"], configured);
  eq("stale whitelist entry reported", runIsolated(agentDir).problems, ["whitelist entry not found: npm:never-installed"]);

  writeSettings(agentDir, [1, "", null], configured);
  eq("malformed whitelist entries ignored", runIsolated(agentDir).problems, []);

  writeSettings(agentDir, [], [...configured, "npm:absent-package"]);
  eq("absent configured package is not a problem", runIsolated(agentDir).problems, []);
}

// ── scenario: unreadable and absent settings ───────────────────────────────
{
  const agentDir = freshAgent();
  eq("missing settings is a silent no-op", runIsolated(agentDir), { scanned: 0, silenced: [], conflicts: [], problems: [] });

  writeFileSync(join(agentDir, "settings.json"), "{ not json");
  const broken = runIsolated(agentDir);
  eq("broken settings reported once", broken.problems.length, 1);
  check("broken settings names the file", broken.problems[0].includes("settings.json"), broken.problems[0]);
}


// ── scenario: global Agent Skills root (pi's ~/.agents/skills) ──────────────
{
  const agentDir = freshAgent();
  const skillsRoot = scenarioAgentSkillsRoot(agentDir);
  const allowed = makeAgentSkill(skillsRoot, "dev-nav", false);
  const denied = makeAgentSkill(skillsRoot, "grilling", false);
  const allowedFlagged = makeAgentSkill(skillsRoot, "ops-nav", true);

  writeSettings(agentDir, [join(skillsRoot, "dev-nav"), join(skillsRoot, "ops-nav")], []);
  const report = runIsolated(agentDir);

  eq("global root is scanned", report.scanned, 3);
  eq("global non-whitelisted skill is silenced", report.silenced.length, 1);
  check("global non-whitelisted skill gains the flag", isSilenced(read(denied)));
  check("global whitelisted skill is left alone", !isSilenced(read(allowed)));
  eq("global whitelisted-but-flagged is a conflict, not a rewrite", report.conflicts.length, 1);
  check("conflict names the flagged skill", report.conflicts[0].includes("/ops-nav/"), report.conflicts[0]);
  check("conflict keeps the existing flag", isSilenced(read(allowedFlagged)));
  eq("global scan reports no problems", report.problems, []);

  const second = runIsolated(agentDir);
  eq("global second run silences nothing new", second.silenced, []);
  eq("global second run still scans", second.scanned, 3);
}

// ── scenario: packages and the global root are scanned together ────────────
{
  const agentDir = freshAgent();
  const skillsRoot = scenarioAgentSkillsRoot(agentDir);
  makeAgentSkill(skillsRoot, "plannotator-tui", false);
  makePackage(agentDir, "npm", "npm:denied-pkg", { hidden: false });

  writeSettings(agentDir, [], ["npm:denied-pkg"]);
  const report = runIsolated(agentDir);

  eq("both universes contribute to the scan", report.scanned, 2);
  eq("both universes are silenced", report.silenced.length, 2);
  eq("combined scan reports no problems", report.problems, []);
}

// ── scenario: a symlinked skill is outside enforcement scope ───────────────
// A symlinked skill points at a file an installer does not own, typically a
// hand-authored skill in dotfiles. Rewriting it would edit someone else's
// repository, so the walk deliberately does not descend into symlinked dirs.
{
  const agentDir = freshAgent();
  const skillsRoot = scenarioAgentSkillsRoot(agentDir);
  const authoredDir = join(dirname(agentDir), "authored", "hand-authored");
  mkdirSync(authoredDir, { recursive: true });
  const authored = join(authoredDir, "SKILL.md");
  writeFileSync(authored, `---\nname: hand-authored\ndescription: d\n---\n`);
  symlinkSync(authoredDir, join(skillsRoot, "hand-authored"));
  const managed = makeAgentSkill(skillsRoot, "install-anti-slop", false);

  writeSettings(agentDir, [], []);
  const report = runIsolated(agentDir);

  eq("symlinked skill is not scanned", report.scanned, 1);
  check("symlinked skill file is never rewritten", !isSilenced(read(authored)));
  check("real skill beside it is still silenced", isSilenced(read(managed)));
}

// ── scenario: absent global root ───────────────────────────────────────────
{
  const agentDir = freshAgent();
  rmSync(scenarioAgentSkillsRoot(agentDir), { recursive: true, force: true });
  makePackage(agentDir, "npm", "npm:denied-pkg", { hidden: false });

  writeSettings(agentDir, [], ["npm:denied-pkg"]);
  const report = runIsolated(agentDir);

  eq("absent global root is not a problem", report.problems, []);
  eq("package skill still silenced", report.silenced.length, 1);
}

// ── summarise: the user-facing message ──────────────────────────────────────

const clean = { scanned: 31, silenced: [], conflicts: [], problems: [] };
eq("clean run stays silent", summarise(clean), undefined);

const silenced = summarise({
  scanned: 31,
  silenced: [
    "~/.pi/agent/npm/node_modules/context-mode/skills/ctx-stats/SKILL.md",
    "~/.pi/agent/npm/node_modules/context-mode/skills/ctx-search/SKILL.md",
  ],
  conflicts: [],
  problems: [],
});
check("silencing is an info notice", silenced?.type === "info");
check("silencing names the skills", silenced?.text.includes("ctx-stats") === true, silenced?.text);
check("silencing counts skills", silenced?.text.includes("2 package skill") === true, silenced?.text);

const manySilenced = summarise({
  scanned: 31,
  silenced: Array.from({ length: 6 }, (_, i) => `~/.pi/agent/x/s${i}/SKILL.md`),
  conflicts: [],
  problems: [],
});
check("long silence list is truncated", manySilenced?.text.includes("(+2)") === true, manySilenced?.text);

const conflict = summarise({ scanned: 4, silenced: [], conflicts: ["~/.pi/agent/x/one/SKILL.md"], problems: [] });
check("conflict is a warning", conflict?.type === "warning");
check("conflict is actionable", conflict?.text.includes("keepVisible") === true, conflict?.text);

const problem = summarise({ scanned: 3, silenced: [], conflicts: [], problems: ["whitelist entry not found: npm:gone"] });
check("problem is a warning", problem?.type === "warning");
check("problem names the entry", problem?.text.includes("npm:gone") === true);

const both = summarise({
  scanned: 3,
  silenced: ["~/.pi/agent/x/one/SKILL.md"],
  conflicts: ["~/.pi/agent/x/two/SKILL.md"],
  problems: ["whitelist entry not found: npm:gone"],
});
check("problem run mentions the conflict", both?.text.includes("still silenced") === true, both?.text);
check("problem run mentions the repair", both?.text.includes("Silenced 1") === true, both?.text);

const manyProblems = summarise({ scanned: 5, silenced: [], conflicts: [], problems: ["a", "b", "c", "d", "e"] });
check("many problems cluster", manyProblems?.text.includes("(+2 more)") === true, manyProblems?.text);

// ── report ─────────────────────────────────────────────────────────────────

console.log(`\n${passed} passed, ${failures.length} failed`);
for (const failure of failures) console.log(`  FAIL  ${failure}`);
process.exit(failures.length === 0 ? 0 : 1);
