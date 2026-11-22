# parser-recovery

## Status
active

## Objective
Recover from malformed input without dropping valid records.

## State
- Recovery skips one malformed record.

## Open Questions
- None.

## Next
- Count skipped records.

## Decisions
- Recover at record boundaries.

## Constraints
- Preserve valid records.

## Assumptions
- Each malformed record has a detectable boundary.

## Context
No further history.
