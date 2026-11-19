#!/usr/bin/env bash
# Entry point for the dev-nav iteration loop. The engine is shared; see
# ~/.agents/skills/_harness/PROCEDURE.md.
#
#   ./evals/loop.sh --self-test
#   ./evals/loop.sh --label r01 --split iterate
#   ./evals/loop.sh --label r01 --split holdout
#   ./evals/loop.sh --reuse r01
#   ./evals/loop.sh --decide --baseline r00 --candidate r01 --hypothesis "..." --change "..."
#   ./evals/loop.sh --stop
exec "${HOME}/.agents/skills/_harness/bin/skill-loop.sh" --skill dev-nav "$@"
