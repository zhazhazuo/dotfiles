#!/usr/bin/env bash
# Entry point for the agent-nav iteration loop. The engine is shared; see
# ~/.agents/skills/_harness/PROCEDURE.md.
#
#   ./evals/loop.sh --self-test
#   ./evals/loop.sh --check
#   ./evals/loop.sh --label cal --split iterate
#   ./evals/loop.sh --decide --baseline cal --candidate r01 --hypothesis "..." --change "..."
#   ./evals/loop.sh --stop
exec "${HOME}/.agents/skills/_harness/bin/skill-loop.sh" --skill agent-nav "$@"
