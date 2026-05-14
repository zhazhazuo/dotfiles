# Execution Plan

## Roles

- **Subagent**: reads source code, returns structured findings — keeps raw code out of main context
- **Main agent**: receives subagent output, writes all KB files to `./docs/`

---

## Step 1+2 — Subagent: Stack & Structure Scanner

Dispatch ONE subagent with this prompt:

```
You are a code structure scanner. Do the following in order:

1. Traverse the project directory.
   Ignore: node_modules, .git, dist, build, coverage, .next, __pycache__, vendor
   Identify: entry files, major folders, config files
   (package.json, go.mod, requirements.txt, pom.xml, Dockerfile, Cargo.toml,
   Gemfile, composer.json, mix.exs, *.csproj)

2. Load knowledge-base-writer/heuristics.md and apply it to detect the tech stack.

3. Return ONLY the block below. No prose. No explanations.

TECH_STACK:
  runtime: <value>
  frontend: <value or "none">
  backend: <value>
  storage: <value or "none">
  infra: <value or "none">

SYSTEM_LAYERS: <layer> → <layer> → <layer>

FEATURE_CLUSTERS:
  - <cluster name>

MODULE_BOUNDARIES:
  <folder/> → <module name>
```

Wait for the subagent to return before continuing.
Use its output to complete Steps 3 and 4.

---

## Step 3 — Write Overview (main agent)

From Step 1+2 subagent output, write:

- `00_overview/big_picture.md` — what the system does, core flow, constraints
- `00_overview/tech_stack.md` — TECH_STACK values formatted as `name → version/role`

Follow `knowledge-base-writer/file-generation-rules.md` → 00_overview/ section.

---

## Step 4 — Write Maps (main agent)

From Step 1+2 subagent output, write:

- `01_maps/system_map.md` — SYSTEM_LAYERS as a Mermaid diagram
- `01_maps/feature_map.md` — FEATURE_CLUSTERS as `feature → module link`
- `01_maps/module_map.md` — MODULE_BOUNDARIES as `module → entry file`

Follow `knowledge-base-writer/file-generation-rules.md` → 01_maps/ section.
Add Mermaid per `knowledge-base-writer/mermaid-rules.md`.

---

## Step 5 — Subagent: File Indexer

Dispatch ONE subagent with this prompt:

```
You are a file indexer. Do the following:

1. List every file in the project.
   Ignore: node_modules, .git, dist, build, coverage, .next, __pycache__, vendor

2. For each file, write one line that says what it does.

3. If a backend framework was detected, also list API endpoints.

Return ONLY the block below. No prose.

FILE_INDEX:
<top-level-folder>/
  <path> → <one-line meaning>

API_INDEX (omit section entirely if no backend):
<METHOD> /<path> → <purpose>
```

Wait for the subagent to return. Write `03_index/file_index.md` and (if present) `03_index/api_index.md` from its output.

Follow `knowledge-base-writer/file-generation-rules.md` → 03_index/ section.

---

## Step 6 — Parallel Subagents: Module Extractors

From the MODULE_BOUNDARIES list returned in Step 1+2, dispatch ONE subagent per module IN PARALLEL.

Each subagent receives this prompt (substitute `<module_folder>` and `<module_name>`):

```
You are a module extractor. Your task: read the files in <module_folder> only.
Do NOT read files outside this folder.

Return ONLY the block below. No prose.

MODULE: <module_name>
RESPONSIBILITY: <one line — what this module owns>
ENTRY_POINTS:
  <path> → <role>
KEY_FILES:
  <path> → <role>
CONSTRAINTS:
  - <rule or invariant to preserve>
SCOPE_TABLE:
  Implementation:
    <path> → <what it implements>
  Consumer:
    <path> → <how/why it uses this module>
```

Wait for ALL module subagents to return.
For each module, write `04_modules/<name>.md` from its subagent output.

Follow `knowledge-base-writer/file-generation-rules.md` → 04_modules/ section.

---

## Step 7 — Subagent: Guide Extractor

Dispatch ONE subagent with this prompt:

```
You are a command extractor. Read these files (whichever exist):
package.json, Makefile, Dockerfile, docker-compose.yml,
pyproject.toml, go.mod, Cargo.toml, Gemfile, mix.exs

Return ONLY the block below. No prose. Omit any section where no data is found.

DEV:
  install: <command>
  server: <command>
  test: <command>
  env_vars: <names of required env variables>

DEPLOY:
  build: <command>
  start: <command>
  docker: <command>
  pipeline: <CI/CD steps>

DEBUG:
  logs: <log file location or command>
  issues:
    - <symptom> → <resolution>
```

Wait for the subagent to return. Write `02_guides/dev.md`, `02_guides/deploy.md`, `02_guides/debug.md` from its output.

Follow `knowledge-base-writer/file-generation-rules.md` → 02_guides/ section.

---

## Step 8 — Write RUNBOOK (main agent)

Use `knowledge-base-writer/RUNBOOK-template.md` as the template.

- Link every file generated in Steps 3–7
- Organize by intent (NOT topic)

---

## Step 9 — Write META (main agent)

Use `knowledge-base-writer/meta-template.md` as the template.

Run:
```
git rev-parse --short HEAD   → last_commit
git rev-parse HEAD:docs      → docs_tree_hash
```

- Set `generated` and `last_synced` to today's ISO date
- Set `schema_version` to `1`
- Use `"init"` for both hash fields if no commits exist yet
- Use `"untracked"` for `docs_tree_hash` if `./docs/` is not yet committed
- Write to `./docs/META.md`
