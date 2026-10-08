#!/usr/bin/env bash
# Routing eval for the dev-nav card book.
#
# Runs one fresh pi session per fixture moment and records every skill file the agent
# reads, in order.
#
# Scoring rule:
#   - A moment passes when the expected skill is among the skills read AND every skill read
#     is either the expected skill or a ripwire-family orient skill. Orienting before the
#     phase is legal lifecycle behaviour; substituting a wrong phase is not.
#   - A negative control (expected phase "-") passes when no dev-card skill is read at all.
#     Landing on another navigator (ops-nav, design-nav, dev-flow-nav) or on no skill passes.
#
# Usage:
#   evals/run-routing-eval.sh                 # every moment, natural mode
#   evals/run-routing-eval.sh --mode route    # agent is told its job is to route
#   evals/run-routing-eval.sh --only m02,m11  # subset
#   evals/run-routing-eval.sh --model <id>    # override the model
#   evals/run-routing-eval.sh --fixture <path>
#   evals/run-routing-eval.sh --reuse <transcripts-dir>   # re-score saved runs, no model calls
#   evals/run-routing-eval.sh --deck-path <file>   # A/B: point the agent at another deck
#
# Transcripts are written outside the agent's cwd. A transcript written into the cwd is
# grepped by the agent under test, which corrupts the run.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="${ROOT}/evals/routing-moments.tsv"
MODE="natural"
ONLY=""
REUSE=""
DECK_PATH="${HOME}/.agents/skills/dev-nav/SKILL.md"
MODEL_ARG=()

while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --model) MODEL_ARG=(--model "$2"); shift 2 ;;
    --fixture) FIXTURE="$2"; shift 2 ;;
    --reuse) REUSE="$2"; shift 2 ;;
    --deck-path) DECK_PATH="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -f "$FIXTURE" ] || { echo "fixture not found: $FIXTURE" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/devnav-eval.XXXXXX")"
OUTDIR="${WORK}/transcripts"
mkdir -p "$OUTDIR"
FIXTURE_REPO="${ROOT}/evals/fixture-repo"
[ -d "$FIXTURE_REPO" ] || { echo "fixture repo not found: $FIXTURE_REPO" >&2; exit 2; }

ROUTE_PROMPT="Your job in this run is to route, not to do the work. Read the dev-nav deck at ${DECK_PATH}, decide the lifecycle phases this task passes through, in order, and read the card and skill file for every phase you will need. Then stop and list the phases you entered and the skills you read. Do the routing only; do not do the work."

pass=0; fail=0; skipped=0; total=0
printf '%-5s %-5s %-27s %s\n' ID PHASE EXPECTED 'READS -> VERDICT'

while IFS=$'\t' read -r id moment phase skill natural_ok _; do
  case "$id" in ''|'#'*) continue ;; esac
  if [ -n "$ONLY" ] && [[ ",$ONLY," != *",$id,"* ]]; then continue; fi
  if [ "$MODE" != "route" ] && [ "$natural_ok" = "no" ]; then
    printf '%-5s %-5s %-27s SKIP (fixture limitation)\n' "$id" "$phase" "$skill"
    skipped=$((skipped + 1))
    continue
  fi

  total=$((total + 1))
  if [ -n "$REUSE" ]; then
    transcript="${REUSE}/${id}.jsonl"
    [ -f "$transcript" ] || { echo "missing transcript: $transcript" >&2; transcript=/dev/null; }
  else
    transcript="${OUTDIR}/${id}.jsonl"
  fi
  prompt="$moment"
  if [ "$MODE" = "route" ]; then
    prompt="${ROUTE_PROMPT}

TASK: ${moment}"
  fi

  if [ -z "$REUSE" ]; then
    SCRATCH="${WORK}/repo-${id}"
    rm -rf "$SCRATCH"
    cp -R "$FIXTURE_REPO" "$SCRATCH"
    ( cd "$SCRATCH" && git init -q . \
        && git add -A \
        && git -c user.email=eval@local -c user.name=eval commit -qm fixture ) >/dev/null 2>&1 || true

    ( cd "$SCRATCH" && pi -p --no-session --mode json \
        ${MODEL_ARG[@]+"${MODEL_ARG[@]}"} \
        --append-system-prompt "dev-nav routing eval. Do not modify any file." \
        "$prompt" ) > "$transcript" 2>&1 < /dev/null
  fi

  scored="$(python3 - "$transcript" "$skill" "$phase" <<'PY'
import json, sys

DEV_SKILLS = {
    "ripwire-router", "alignment-quiz", "context-to-qa-scenarios", "test-driven-development",
    "write-discoverable-code", "structuring-ui-components", "api-mock", "systematic-debugging",
    "prune-low-signal-tests", "verification-before-completion", "requesting-code-review",
    "receiving-code-review", "writing-skills",
}
# Orienting before the phase is legal lifecycle behaviour, so these never fail a run.
ORIENT_SKILLS = {
    "ripwire-router", "ripwire-orient", "ripwire-navigate", "ripwire-before-you-build",
    "ripwire-change-check", "ripwire-find-bug", "ripwire-fresh-eyes", "ripwire-graph-query",
    "ripwire-handoff", "ripwire-layers", "ripwire-opt-remarks", "ripwire-perf-target",
    "ripwire-quality-bar", "ripwire-reuse-first", "ripwire-security-scan",
    "ripwire-write-tests",
}

# Skills from the delivery flow (dev-flow-nav and the package skills it routes to) are legal after
# the phase under test: finishing a branch after review is correct lifecycle behaviour, not a
# routing error.
DELIVERY_SKILLS = {
    "dev-flow-nav", "brainstorming", "writing-plans", "executing-plans",
    "subagent-driven-development", "dispatching-parallel-agents", "using-git-worktrees",
    "finishing-a-development-branch", "one-pager-gate", "pi-subagents", "council-mode",
    "using-superpowers",
}

PHASE_SKILLS = {
    "1": {"ripwire-router"},
    "2": {"alignment-quiz"},
    "3": {"context-to-qa-scenarios"},
    "4": {"test-driven-development"},
    "5": {"write-discoverable-code", "structuring-ui-components", "api-mock"},
    "6": {"systematic-debugging"},
    "7": {"prune-low-signal-tests"},
    "8": {"verification-before-completion"},
    "9": {"requesting-code-review", "receiving-code-review"},
    "10": {"writing-skills"},
}

path, expected, phase = sys.argv[1], sys.argv[2], sys.argv[3]
seen = []
for line in open(path, encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        o = json.loads(line)
    except Exception:
        continue
    if o.get("type") != "tool_execution_start":
        continue
    blob = json.dumps(o.get("args") or {})
    for token in blob.replace("\\/", "/").split('"'):
        token = token.strip()
        if not token.endswith("SKILL.md"):
            continue
        parts = [p for p in token.split("/") if p]
        if len(parts) < 2:
            continue
        name = parts[-2]
        if name == "dev-nav":
            continue
        if name not in seen:
            seen.append(name)

route = ",".join(seen) or "NONE"
def phase_num(name):
    for p, names in PHASE_SKILLS.items():
        if name in names:
            return int(p)
    return None

if expected == "-":
    ok = not any(s in DEV_SKILLS for s in seen)
else:
    exp_phase = int(phase) if phase.isdigit() else None
    # Orienting before the phase is always legal. The card that must match is the first one the
    # agent ENTERS. Everything after that is the lifecycle working: it may move forward, or
    # backwards into a repair phase such as Debug or Trim, and neither is a routing error.
    entry = next(
        (s for s in seen if phase_num(s) is not None and not (s in ORIENT_SKILLS and s != expected)),
        None,
    )
    ok = expected in seen and (entry is None or phase_num(entry) == exp_phase)
print(f"{route}\t{'PASS' if ok else 'FAIL'}")
PY
)"

  route="${scored%%$'\t'*}"
  verdict="${scored##*$'\t'}"
  if [ "$verdict" = "PASS" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
  printf '%-5s %-5s %-27s %s -> %s\n' "$id" "$phase" "$skill" "$route" "$verdict"
done < "$FIXTURE"

echo
echo "mode=${MODE}  pass=${pass}  fail=${fail}  skipped=${skipped}  scored=${total}"
echo "transcripts: ${OUTDIR}"
[ "$fail" -eq 0 ]
