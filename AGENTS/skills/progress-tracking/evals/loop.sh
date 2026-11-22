#!/usr/bin/env bash
# Progress-tracking iteration loop. The shared engine owns measurement and decisions.
# See ~/.agents/skills/_harness/PROCEDURE.md.
exec "${HOME}/.agents/skills/_harness/bin/skill-loop.sh" --skill progress-tracking "$@"
