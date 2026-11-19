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
SCORER="${ROOT}/../_harness/lib/score_routing.py"
RULES="${ROOT}/evals/rules-routing.json"
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

  scored="$(python3 "${SCORER}" --rules "${RULES}" --transcript "$transcript" \
    --expected-skill "$skill" --phase "$phase")"

  route="${scored%%$'\t'*}"
  verdict="${scored##*$'\t'}"
  if [ "$verdict" = "PASS" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
  printf '%-5s %-5s %-27s %s -> %s\n' "$id" "$phase" "$skill" "$route" "$verdict"
done < "$FIXTURE"

echo
echo "mode=${MODE}  pass=${pass}  fail=${fail}  skipped=${skipped}  scored=${total}"
echo "transcripts: ${OUTDIR}"
[ "$fail" -eq 0 ]
