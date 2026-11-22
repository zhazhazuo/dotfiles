#!/usr/bin/env bash
# One iteration loop for one navigator skill. The measurement is frozen before round one.
#
#   loop.sh --skill dev-nav --label r01                 # run the iterate split, 3 repeats
#   loop.sh --skill dev-nav --label r01 --split holdout  # the stopping signal
#   loop.sh --skill dev-nav --reuse r01                 # re-score saved transcripts, no model calls
#   loop.sh --skill dev-nav --freeze                    # record the frozen hashes
#   loop.sh --skill dev-nav --verify                    # exit 3 when a frozen input changed
#   loop.sh --skill dev-nav --decide --baseline r00 --candidate r01
#   loop.sh --skill dev-nav --stop                      # which stop rule fires now
#   loop.sh --self-test
#
# The loop changes no deck. A tester agent runs this script. An editor agent changes one thing
# in SKILL.md. This script measures and decides; it never chooses the edit.
set -uo pipefail

HARNESS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="${HARNESS}/lib"
SKILLS_ROOT="$(cd "${HARNESS}/.." && pwd)"
SKILL=""
LABEL=""
SPLIT="iterate"
REPEATS=""
JOBS=""
MODE=""
MODEL=""
DECK=""
DECK_BASELINE=""
OUT="${HOME}/.agents/eval-runs"
FIXTURE=""
RULES=""
REUSE=""
DO_FREEZE=""
DO_REFREEZE=""
DO_VERIFY=""
DO_DECIDE=""
DO_STOP=""
DO_CHECK=""
BASELINE=""
CANDIDATE=""
HYPOTHESIS=""
SECTION=""
QUOTE=""
CHANGE=""
SELF_TEST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --skill) SKILL="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    --split) SPLIT="$2"; shift 2 ;;
    --repeats) REPEATS="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --deck) DECK="$2"; shift 2 ;;
    --deck-baseline) DECK_BASELINE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --fixture) FIXTURE="$2"; shift 2 ;;
    --rules) RULES="$2"; shift 2 ;;
    --reuse) REUSE="$2"; shift 2 ;;
    --freeze) DO_FREEZE=1; shift ;;
    --refreeze) DO_REFREEZE=1; shift ;;
    --verify) DO_VERIFY=1; shift ;;
    --decide) DO_DECIDE=1; shift ;;
    --stop) DO_STOP=1; shift ;;
    --check) DO_CHECK=1; shift ;;
    --baseline) BASELINE="$2"; shift 2 ;;
    --candidate) CANDIDATE="$2"; shift 2 ;;
    --hypothesis) HYPOTHESIS="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    --quote) QUOTE="$2"; shift 2 ;;
    --change) CHANGE="$2"; shift 2 ;;
    --self-test) SELF_TEST=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ------------------------------------------------------------------ helpers

say() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit "${2:-2}"; }

sha_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

sha_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    sha256sum | awk '{print $1}'
  fi
}

hash_tree() {  # $1 = dir, $2 = find expression for files to skip
  local dir="$1" skip="${2:-}"
  ( cd "$dir" || return 1
    find . -type f ! -path './.git/*' ${skip:+! -path "$skip"} | LC_ALL=C sort |
    while IFS= read -r f; do printf '%s ' "$f"; sha_file "$f"; done ) | sha_stdin
}

require_skill() {
  [ -n "$SKILL" ] || die "--skill is required"
  SKILL_DIR="${SKILLS_ROOT}/${SKILL}"
  EVALS="${SKILL_DIR}/evals"
  [ -f "${SKILL_DIR}/SKILL.md" ] || die "no SKILL.md under ${SKILL_DIR}"
  [ -d "$EVALS" ] || die "no evals dir at ${EVALS}"
  FIXTURE="${FIXTURE:-${EVALS}/routing-moments.tsv}"
  RULES="${RULES:-${EVALS}/rules-routing.json}"
  [ -f "$FIXTURE" ] || die "no fixture at ${FIXTURE}"
  [ -f "$RULES" ] || die "no rules at ${RULES}"
}

load_config() {
  local cli_repeats="$REPEATS" cli_jobs="$JOBS" cli_mode="$MODE"
  if [ -f "${EVALS}/loop-config.json" ]; then
    eval "$(python3 - "$EVALS/loop-config.json" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        cfg = json.load(fh)
except Exception:
    cfg = {}
for key in ("repeats", "jobs", "mode", "ceiling_usd", "ceiling_tokens", "cap_rounds", "holdout_patience"):
    if key in cfg:
        print(f"{key.upper()}={cfg[key]}")
PY
)"
  fi
  REPEATS="${cli_repeats:-${REPEATS:-3}}"
  JOBS="${cli_jobs:-${JOBS:-4}}"
  MODE="${cli_mode:-${MODE:-natural}}"
  CAP_ROUNDS="${CAP_ROUNDS:-6}"
  HOLDOUT_PATIENCE="${HOLDOUT_PATIENCE:-2}"
  CEILING_USD="${CEILING_USD:-0}"
  CEILING_TOKENS="${CEILING_TOKENS:-0}"
}

deck_hash() {
  if [ "$MODE" = "route" ] && [ -n "$DECK" ]; then
    sha_file "$DECK"
  else
    hash_tree "$SKILL_DIR" './evals/*'
  fi
}

freeze_path() { printf '%s' "${EVALS}/freeze.json"; }

write_freeze() {
  local path; path="$(freeze_path)"
  if [ -f "$path" ] && [ -z "$DO_REFREEZE" ]; then
    say "freeze exists: ${path}. A frozen measurement does not move during a loop."
    say "Use --refreeze only before round one, and name the reason in RESULTS.md."
    return 0
  fi
  python3 - "$path" "$SKILL" "$FIXTURE" "$RULES" "$SKILL_DIR" "$HARNESS" <<'PY'
import hashlib, json, os, sys, datetime

path, skill, fixture, rules, skill_dir, harness = sys.argv[1:7]

def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(65536), b""):
            h.update(block)
    return h.hexdigest()

def tree(root, skip):
    rows = []
    for base, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d != ".git")
        for name in sorted(files):
            full = os.path.join(base, name)
            rel = os.path.relpath(full, root)
            if any(rel == s or rel.startswith(s.rstrip("*")) for s in skip):
                continue
            rows.append(rel + " " + sha(full))
    return hashlib.sha256("\n".join(rows).encode()).hexdigest()

instrument = {}
for name in ("score_routing.py", "score_artifact.py", "decide.py"):
    instrument[name] = sha(os.path.join(harness, "lib", name))
instrument["skill-loop.sh"] = sha(os.path.join(harness, "bin", "skill-loop.sh"))
instrument["PROCEDURE.md"] = sha(os.path.join(harness, "PROCEDURE.md"))

record = {
    "created": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "skill": skill,
    "fixture": sha(fixture),
    "rules": sha(rules),
    "fixture_tree": tree(os.path.join(skill_dir, "evals", "fixture-repo"), []),
    "deck_at_freeze": tree(skill_dir, ["evals/*"]),
    "instrument": instrument,
}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(record, fh, indent=2, sort_keys=True)
    fh.write("\n")
print("froze " + path)
PY
}

verify_freeze() {
  local path; path="$(freeze_path)"
  [ -f "$path" ] || die "no freeze at ${path}; run --freeze before round one" 3
  python3 - "$path" "$FIXTURE" "$RULES" "$SKILL_DIR" "$HARNESS" <<'PY'
import hashlib, json, os, sys

path, fixture, rules, skill_dir, harness = sys.argv[1:6]
with open(path, encoding="utf-8") as fh:
    frozen = json.load(fh)

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for block in iter(lambda: fh.read(65536), b""):
            h.update(block)
    return h.hexdigest()

def tree(root, skip):
    rows = []
    for base, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d != ".git")
        for name in sorted(files):
            full = os.path.join(base, name)
            rel = os.path.relpath(full, root)
            if any(rel == s or rel.startswith(s.rstrip("*")) for s in skip):
                continue
            rows.append(rel + " " + sha(full))
    return hashlib.sha256("\n".join(rows).encode()).hexdigest()

now = {
    "fixture": sha(fixture),
    "rules": sha(rules),
    "fixture_tree": tree(os.path.join(skill_dir, "evals", "fixture-repo"), []),
}
for name in ("score_routing.py", "score_artifact.py", "decide.py"):
    now[f"instrument.{name}"] = sha(os.path.join(harness, "lib", name))
now["instrument.skill-loop.sh"] = sha(os.path.join(harness, "bin", "skill-loop.sh"))
now["instrument.PROCEDURE.md"] = sha(os.path.join(harness, "PROCEDURE.md"))

changed = []
for key, value in now.items():
    if key.startswith("instrument."):
        name = key.split(".", 1)[1]
        if frozen["instrument"].get(name) != value:
            changed.append("lib/" + name)
    elif frozen.get(key) != value:
        changed.append(key)
if changed:
    print("FREEZE VIOLATION: " + ", ".join(changed))
    sys.exit(3)
print("freeze OK")
PY
}



field() {  # $1 = row, $2 = column number (1-based)
  printf '%s' "$1" | awk -F'\t' -v n="$2" '{ print $n }'
}

# ------------------------------------------------------------------ the run

scratch_tree() {  # prints a neutral working tree, never named after the skill or the repeat
  local root
  root="$(mktemp -d "${TMPDIR:-/tmp}/looprun.XXXXXXXX")" || return 1
  printf '%s/workspace\n' "$root"
}

instrument_stamp() {  # keys the run cache, so a repaired runner never reuses old transcripts
  { sha_file "${BASH_SOURCE[0]}"
    sha_file "${LIB}/score_routing.py"
    sha_file "${LIB}/score_artifact.py"
    sha_file "${LIB}/decide.py"
  } | sha_stdin
}

run_cells() {
  local label="$1" split="$2"
  local run="${OUT}/${label}"
  local trans="${run}/transcripts"
  mkdir -p "$trans"
  local deck="$DECK"
  local deck_file="${SKILL_DIR}/SKILL.md"
  [ "$MODE" = "route" ] && deck_file="${deck:-${SKILL_DIR}/SKILL.md}"
  [ -f "$deck_file" ] || die "no deck at ${deck_file}"

  local sig
  sig="$(printf '%s %s %s %s %s %s' "$(deck_hash)" "$(sha_file "$FIXTURE")" "$(sha_file "$RULES")" "$MODE" "${MODEL:-default}" "$(instrument_stamp)" | sha_stdin)"
  local cache="${OUT}/cache/${sig}"
  mkdir -p "$cache"
  printf '%s\n' "$sig" > "${run}/cache-sig.txt"
  deck_hash > "${run}/deck-hash.txt"

  local sys_prompt="Work inside this repository and do not write outside it."
  local route_prompt="Your job in this run is to route, not to do the work. Read the deck at ${deck_file}, decide the lifecycle phases this task passes through, in order, and read the card and skill file for every phase you will need. Then stop and list the phases you entered and the skills you read. Do the routing only; do not do the work."

  local n=0
  local total=0
  while IFS= read -r row; do
    [ -z "$row" ] && continue
    case "$row" in \#*) continue ;; esac
    local id natural split_row moment
    id="$(field "$row" 1)"
    moment="$(field "$row" 2)"
    natural="$(field "$row" 5)"
    split_row="$(field "$row" 7)"
    [ -z "$split_row" ] && split_row="iterate"
    [ "$split" = "all" ] || [ "$split_row" = "$split" ] || continue
    if [ "$MODE" = "natural" ] && [ "$natural" = "no" ]; then
      say "skip ${id}: natural_ok=no, marked in the fixture"
      continue
    fi
    local repeat=1
    while [ "$repeat" -le "$REPEATS" ]; do
      total=$((total + 1))
      local out="${trans}/${id}-r${repeat}.jsonl"
      local hit="${cache}/${id}-r${repeat}.jsonl"
      (
        if [ -s "$hit" ]; then
          cp "$hit" "$out"
        else
          local prompt="$moment"
          [ "$MODE" = "route" ] && prompt="${route_prompt}

TASK: ${moment}"
          # The tree sits outside the run directory, at a name that states neither the skill nor
          # the repeat. A session that reads its own path must not learn what is being measured.
          local scratch
          scratch="$(scratch_tree)" || exit 1
          cp -R "${EVALS}/fixture-repo" "$scratch" || exit 1
          ( cd "$scratch" && git init -q . && git add -A &&
            git -c user.email=eval@local -c user.name=eval commit -qm fixture ) >/dev/null 2>&1 || true
          (
            cd "$scratch" && pi -p --no-session --mode json \
              ${MODEL:+--model "$MODEL"} \
              --append-system-prompt "$sys_prompt" \
              "$prompt"
          ) > "$out" 2>"${trans}/${id}-r${repeat}.err" < /dev/null
          [ -s "$out" ] && cp "$out" "$hit"
          rm -rf "$(dirname "$scratch")"
        fi
      ) &
      n=$((n + 1))
      if [ $((n % JOBS)) -eq 0 ]; then wait; fi
      repeat=$((repeat + 1))
    done
  done < "$FIXTURE"
  wait
  say "ran ${total} cells into ${trans}"
}

score_cells() {
  local label="$1" split="$2"
  local run="${OUT}/${label}"
  local trans="${run}/transcripts"
  local reps
  reps="$(ls "${trans}"/*-r*.jsonl 2>/dev/null | sed -E 's/.*-r([0-9]+)\.jsonl$/\1/' | sort -n | tail -1)"
  [ -n "$reps" ] || reps="$REPEATS"
  python3 "${LIB}/score_routing.py" --rules "$RULES" --fixture "$FIXTURE" \
    --transcripts "$trans" --repeats "$reps" --split "$split" --json \
    > "${run}/cells.json" || die "routing scorer failed"

  local dhash
  dhash="$(cat "${run}/deck-hash.txt" 2>/dev/null || deck_hash)"
  python3 - "$run" "$SKILL" "$LABEL" "$MODE" "${MODEL:-default}" "$reps" \
    "$EVALS" "$dhash" "$LIB" <<'PY'
import json, os, subprocess, sys

run, skill, label, mode, model, repeats, evals, deck, lib = sys.argv[1:10]
repeats = int(repeats)

with open(os.path.join(run, "cells.json"), encoding="utf-8") as fh:
    cells = json.load(fh)

artifact_of = {}
with open(os.path.join(evals, "routing-moments.tsv"), encoding="utf-8") as fh:
    for line in fh:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        cols = line.rstrip("\n").split("\t")
        while len(cols) < 9:
            cols.append("")
        artifact_of[cols[0].strip()] = cols[7].strip() or "-"

for cell in cells:
    artifact = artifact_of.get(cell["id"], "-")
    transcript = os.path.join(run, "transcripts", f"{cell['id']}-r{cell['repeat']}.jsonl")
    cell["artifact_wanted"] = artifact
    if artifact == "-" or not os.path.exists(transcript):
        cell["artifact"] = "na" if artifact == "-" else "fail"
    else:
        proc = subprocess.run(
            [sys.executable, os.path.join(lib, "score_artifact.py"),
             "--transcript", transcript, "--artifact", artifact, "--json"],
            capture_output=True, text=True)
        try:
            cell["artifact"] = json.loads(proc.stdout)["verdict"]
        except Exception:
            cell["artifact"] = "fail"

moments = {}
for cell in cells:
    entry = moments.setdefault(cell["id"], {"split": cell["split"], "passes": 0,
                                             "repeats": 0, "artifact_passes": 0,
                                             "action_passes": 0, "routing_passes": 0})
    entry["repeats"] += 1
    entry["passes"] += 1 if cell["verdict"] == "PASS" else 0
    entry["artifact_passes"] += 1 if cell.get("artifact") == "pass" else 0
    entry["action_passes"] += 1 if cell.get("action") == "pass" else 0
    entry["routing_passes"] += 1 if cell.get("routing_verdict") == "PASS" else 0

splits = {}
for cell in cells:
    splits.setdefault(cell["split"], set()).add(cell["repeat"])
agg = {}
for split in splits:
    agg[split] = []
    for repeat in sorted(splits[split]):
        agg[split].append(sum(1 for c in cells
                              if c["split"] == split and c["repeat"] == repeat
                              and c["verdict"] == "PASS"))

scored = [c for c in cells if c["verdict"] != "MISSING"]
summary = {
    "skill": skill, "label": label, "mode": mode, "model": model, "repeats": repeats,
    "deck_hash": deck,
    "skill_files_mean": round(sum(c["skill_files_read"] for c in scored) / len(scored), 2) if scored else 0,
    "wall_mean_s": round(sum(c["wall_seconds"] for c in scored) / len(scored), 1) if scored else 0,
    "cost_usd": round(sum(c["cost_usd"] for c in cells), 6),
    "tokens": sum(c["tokens_billable"] for c in cells),
    "tokens_reported": sum(c["tokens_total"] for c in cells),
    "cells": cells, "moments": moments, "repeat_totals": agg,
}
with open(os.path.join(run, "score.json"), "w", encoding="utf-8") as fh:
    json.dump(summary, fh, indent=2, sort_keys=True)
    fh.write("\n")

with open(os.path.join(run, "report.tsv"), "w", encoding="utf-8") as fh:
    fh.write("id\tsplit\tphase\texpected\tverdicts\tartifact\taction\trouting\treads\treads_per_repeat\twall_s\ttokens\n")
    for moment_id in sorted(moments):
        group = [c for c in cells if c["id"] == moment_id]
        verdicts = ",".join(c["verdict"][0] for c in group)
        artifacts = ",".join({"pass": "P", "fail": "F", "na": "-"}.get(c.get("artifact"), "?") for c in group)
        actions = ",".join({"pass": "P", "fail": "F", "na": "-"}.get(c.get("action"), "?") for c in group)
        routing = ",".join(c.get("routing_verdict", c["verdict"])[0] for c in group)
        reads = ",".join(group[0]["reads"]) or "NONE"
        per = ";".join(",".join(c["reads"]) or "NONE" for c in group)
        wall = sum(c["wall_seconds"] for c in group) / len(group)
        tokens = sum(c["tokens_total"] for c in group)
        fh.write(f"{moment_id}\t{group[0]['split']}\t{group[0]['phase']}\t{group[0]['expected']}\t"
                 f"{verdicts}\t{artifacts}\t{actions}\t{routing}\t{reads}\t{per}\t{wall:.1f}\t{tokens}\n")

print(f"skill={skill} label={label} mode={mode} model={model}")
print(f"repeats per cell: {repeats}  split totals: {json.dumps(agg, sort_keys=True)}")
print(f"skill files read per moment (mean): {summary['skill_files_mean']}")
print(f"wall seconds per session (mean):    {summary['wall_mean_s']}")
print(f"usage.cost.total (sum):             {summary['cost_usd']}")
print(f"tokens in+out+cacheWrite (sum):     {summary['tokens']}")
print(f"tokens reported by the provider:    {summary['tokens_reported']}")
print(f"wrote {os.path.join(run, 'report.tsv')}")
PY
}

materialize_baseline() {
  local ref="$1" dest="$2"
  mkdir -p "${dest}/${SKILL}"
  git -C "$SKILL_DIR" show "${ref}:AGENTS/skills/${SKILL}/SKILL.md" > "${dest}/${SKILL}/SKILL.md" \
    || die "cannot read ${ref}:AGENTS/skills/${SKILL}/SKILL.md"
  say "baseline deck from ${ref} at ${dest}/${SKILL}/SKILL.md"
}

# ------------------------------------------------------------------ self test

self_test() {
  python3 "${LIB}/score_routing.py" --self-test || return 1
  python3 "${LIB}/score_artifact.py" --self-test || return 1
  python3 "${LIB}/decide.py" --self-test || return 1
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/loopselftest.XXXXXX")"
  mkdir -p "${tmp}/skill/evals/fixture-repo"
  printf 'name: x\n' > "${tmp}/skill/SKILL.md"
  printf 'id\tmoment\tphase\tskill\tnatural_ok\tnote\tsplit\tartifact\nm01\tdo it\t4\twrite-discoverable-code\tyes\t-\titerate\t-\n' \
    > "${tmp}/skill/evals/routing-moments.tsv"
  printf '{"skill":"x","own_skills":["write-discoverable-code"],"phases":{"4":["write-discoverable-code"]}}\n' \
    > "${tmp}/skill/evals/rules-routing.json"
  printf 'hello\n' > "${tmp}/skill/evals/fixture-repo/README.md"
  (
    EVALS="${tmp}/skill/evals"
    SKILL_DIR="${tmp}/skill"
    FIXTURE="${EVALS}/routing-moments.tsv"
    RULES="${EVALS}/rules-routing.json"
    write_freeze >/dev/null || exit 1
    cp "$FIXTURE" "${tmp}/original.tsv"
    printf 'm02\tedited\t4\twrite-discoverable-code\tyes\t-\titerate\t-\n' >> "$FIXTURE"
    if verify_freeze >/dev/null 2>&1; then
      say "self-test: freeze did not catch a fixture edit"
      exit 1
    fi
    cp "${tmp}/original.tsv" "$FIXTURE"
    verify_freeze >/dev/null || exit 1
    printf 'changed\n' > "${tmp}/skill/evals/fixture-repo/README.md"
    if verify_freeze >/dev/null 2>&1; then
      say "self-test: freeze did not catch a fixture-repo edit"
      exit 1
    fi
  ) || { rm -rf "$tmp"; return 1; }
  local neutral
  neutral="$(scratch_tree)" || { rm -rf "$tmp"; return 1; }
  case "$neutral" in
    *dev-nav*|*intercom-coordination*|*-r3*)
      say "self-test: the scratch path names the skill or the repeat: $neutral"
      rm -rf "$(dirname "$neutral")" "$tmp"
      return 1 ;;
  esac
  [ -d "$(dirname "$neutral")" ] || { say "self-test: scratch_tree made no directory"; rm -rf "$tmp"; return 1; }
  rm -rf "$(dirname "$neutral")" "$tmp"
  say "skill-loop self-test OK: three scorers, freeze catches a fixture edit and a tree edit, the
scratch path is neutral"
}

# ------------------------------------------------------------------ dispatch

if [ -n "$SELF_TEST" ]; then self_test; exit $?; fi
require_skill
load_config
OUT="${OUT}/${SKILL}"
mkdir -p "$OUT"

if [ -n "$DO_FREEZE" ] || [ -n "$DO_REFREEZE" ]; then write_freeze; exit 0; fi
if [ -n "$DO_VERIFY" ]; then verify_freeze; exit $?; fi

if [ -n "$DO_CHECK" ]; then
  python3 - "$FIXTURE" "$RULES" "$SKILLS_ROOT" "$SKILL" <<'PY'
import json, os, sys

fixture, rules_path, skills_root, skill = sys.argv[1:5]
with open(rules_path, encoding="utf-8") as fh:
    rules = json.load(fh)
own = set(rules.get("own_skills") or [])
phases = rules.get("phases") or {}
phase_of = {}
for key, names in phases.items():
    for name in names:
        phase_of[name] = key

errors = []
counts = {}
external = set(rules.get("external_skills") or [])
for key in ("own_skills", "orient_skills", "delivery_skills"):
    for name in rules.get(key) or []:
        if name in external:
            continue
        if not os.path.isdir(os.path.join(skills_root, name)):
            errors.append(f"{key}: {name} has no directory under {skills_root}")

rows = 0
with open(fixture, encoding="utf-8") as fh:
    for line in fh:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        cols = line.rstrip("\n").split("\t")
        while len(cols) < 9:
            cols.append("")
        moment_id, _, phase, expected, natural, _, split, artifact, action = cols[:9]
        rows += 1
        allowed = {"-", "", "send", "ask", "reply", "handover", "cancel",
                   "list", "list-cwd", "peers", "status", "pending"}
        if skill == "progress-tracking":
            allowed.add("progress")
        for want in (action or "-").split("|"):
            if want.strip() not in allowed:
                errors.append(f"{moment_id}: expected action {want!r} is not supported")
        split = split or "iterate"
        counts[split] = counts.get(split, 0) + 1
        if expected != "-" and expected not in own:
            errors.append(f"{moment_id}: expected skill {expected} is not in own_skills")
        if expected != "-" and expected not in phase_of and phases:
            errors.append(f"{moment_id}: expected skill {expected} has no phase")
        if phase != "-" and phases and phase not in phases:
            errors.append(f"{moment_id}: phase {phase} is not in phases")
        if natural not in ("yes", "no"):
            errors.append(f"{moment_id}: natural_ok is {natural!r}")
        if split not in ("iterate", "holdout", "sealed"):
            errors.append(f"{moment_id}: split {split!r} is not iterate, holdout or sealed")

if errors:
    print("CHECK FAILED")
    for error in errors:
        print("  " + error)
    sys.exit(1)
print(f"check OK: {skill}, {rows} moments, splits {json.dumps(counts, sort_keys=True)}, "
      f"{len(own)} own skills, {len(phases)} phases, {len(external)} external")
PY
  exit $?
fi

if [ -n "$DO_STOP" ]; then
  python3 - "$OUT" "$CAP_ROUNDS" "$HOLDOUT_PATIENCE" "$CEILING_USD" "$CEILING_TOKENS" <<'PY'
import json, os, sys
from glob import glob

out, cap, patience, ceiling_usd, ceiling_tokens = sys.argv[1:6]
rounds = []
spent_usd = 0.0
tokens = 0
labels = sorted(glob(os.path.join(out, "*", "score.json")))
rounds_seen = len([p for p in labels if __import__("re").fullmatch(r"r\d+", p.rsplit("/", 2)[-2])])
seen_sigs = {}
for path in labels:
    with open(path, encoding="utf-8") as fh:
        score = json.load(fh)
    sig_path = os.path.join(os.path.dirname(path), "cache-sig.txt")
    sig = None
    if os.path.exists(sig_path):
        with open(sig_path, encoding="utf-8") as fh:
            sig = fh.read().strip()
    if sig and sig in seen_sigs:
        pass
    else:
        if sig:
            seen_sigs[sig] = score.get("tokens", 0)
        spent_usd += score.get("cost_usd", 0.0)
        tokens += score.get("tokens", 0)
    holdout = score.get("repeat_totals", {}).get("holdout")
    rounds.append({"round": len(rounds) + 1, "label": score.get("label"),
                   "holdout": holdout,
                   "holdout_median": sorted(holdout)[len(holdout) // 2] if holdout else None})

flat = 0
best = None
for item in rounds:
    if item["holdout_median"] is not None:
        if best is None or item["holdout_median"] > best:
            best = item["holdout_median"]
            flat = 0
        else:
            flat += 1
state = {"round": rounds_seen, "labels": len(rounds), "cap_rounds": int(cap), "holdout_patience": int(patience),
         "holdout_flat_rounds": flat, "cost_usd": round(spent_usd, 6),
         "tokens": tokens, "ceiling_usd": float(ceiling_usd), "ceiling_tokens": int(ceiling_tokens)}
decision_path = os.path.join(out, "decision.json")
if os.path.exists(decision_path):
    with open(decision_path, encoding="utf-8") as fh:
        decision = json.load(fh)
    state["delta"] = decision.get("delta")
    state["spread"] = decision.get("spread")
    state["accepted"] = decision.get("accepted")
    state["reason"] = decision.get("reason")
    state["delta_inside_spread"] = abs(decision.get("delta") or 0) <= (decision.get("spread") or 0)
print(json.dumps(state, indent=2))
PY
  exit 0
fi

if [ -n "$DO_DECIDE" ]; then
  [ -n "$BASELINE" ] && [ -n "$CANDIDATE" ] || die "--decide needs --baseline and --candidate labels"
  verify_freeze >/dev/null || { say "FREEZE VIOLATION"; exit 3; }
  python3 "${LIB}/decide.py" --baseline "${OUT}/${BASELINE}/score.json" \
    --candidate "${OUT}/${CANDIDATE}/score.json" --split "$SPLIT" --json > "${OUT}/decision.json"
  python3 "${LIB}/decide.py" --baseline "${OUT}/${BASELINE}/score.json" \
    --candidate "${OUT}/${CANDIDATE}/score.json" --split "$SPLIT"
  python3 - "${OUT}/decision.json" "$SKILL" "$SKILL_DIR" "$BASELINE" "$CANDIDATE" <<'PY'
import json, sys
path, skill, skill_dir, baseline, candidate = sys.argv[1:6]
with open(path, encoding="utf-8") as fh:
    decision = json.load(fh)
decision.update({
    "skill": skill,
    "skill_path": skill_dir + "/SKILL.md",
    "baseline": baseline,
    "candidate": candidate,
    "measurement": (f"iterate repeats baseline {decision['baseline_repeats']} "
                    f"candidate {decision['candidate_repeats']} spread {decision['spread']} "
                    f"delta {decision['delta']} reason {decision['reason']}"),
})
with open(path, "w", encoding="utf-8") as fh:
    json.dump(decision, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY
  if [ -n "$HYPOTHESIS" ]; then
    python3 "${LIB}/decide.py" --ledger --decision "${OUT}/decision.json" \
      --hypothesis "$HYPOTHESIS" --section "$SECTION" --quote "$QUOTE" \
      --change "$CHANGE" --ts "$(date -u +%Y%m%dT%H%M%SZ)"
  fi
  exit 0
fi

if [ -n "$REUSE" ]; then
  LABEL="$REUSE"
  [ -d "${OUT}/${LABEL}/transcripts" ] || die "no transcripts at ${OUT}/${LABEL}/transcripts"
  score_cells "$LABEL" "$SPLIT"
  exit $?
fi

[ -n "$LABEL" ] || die "--label is required for a measured run"

if [ -n "$DECK_BASELINE" ]; then
  materialize_baseline "$DECK_BASELINE" "${OUT}/decks/${LABEL}"
  DECK="${OUT}/decks/${LABEL}/${SKILL}/SKILL.md"
  MODE="route"
fi

verify_freeze >/dev/null || { say "FREEZE VIOLATION"; exit 3; }
run_cells "$LABEL" "$SPLIT"
score_cells "$LABEL" "$SPLIT"
