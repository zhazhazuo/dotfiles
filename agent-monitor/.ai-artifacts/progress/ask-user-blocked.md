# ask-user-blocked

## Status
active

## Current State
- New herdr-only bridge `pi/extensions/ask-user-attention.ts`, symlinked into
  `~/.pi/agent/extensions/`.
- Maps `rpiv:ask-user:blocked` (primary) plus core `ui_prompt_start/end`
  (backstop) to `herdr:blocked`, so a Pi session blocked on `ask_user_question`
  reaches herdr as `blocked` -> `adapters/herdr.sh` -> `PermissionRequest` ->
  `needs-help` (red) + notification.
- Overlapping signals collapse into one `herdr:blocked` active/inactive pair
  (herdr counts the event).
- Tests: 30 pass in `pi/extensions/__tests__/ask-user-attention.test.ts`.
  `herdr-pi-step` (47) and agent-monitor `reconcile` suites still pass.
- README documents the bridge under "Blocked on human input (`ask_user_question`)".

## Key Decisions
- Scope herdr-only: herdr is the source of truth for this environment; the tmux
  `adapters/pi.sh` path is untouched.
- Signal: rpiv primary + core `ui_prompt` backstop (user choice).
- State: `needs-help` (red) — "blocked, needs input".
- Location: `dotfiles/pi/extensions/` + symlink, matching `herdr-pi-step.ts` and
  `skill-guard.ts`.
- No herdr pi integration upgrade: v9 extracted from the herdr 0.9.1 binary is
  functionally identical for this path (only an absolute-session-path check).

## Open Questions
- None.

## Next
- Restart/reload Pi to load the new extension — it is not active in the
  authoring session.
- Live verification: in a fresh Pi session inside herdr, run `ask_user_question`
  and confirm the pane / agent-monitor item goes red, then returns to running
  after the answer.
