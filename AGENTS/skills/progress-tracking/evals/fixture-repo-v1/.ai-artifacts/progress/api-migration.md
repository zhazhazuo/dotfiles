# api-migration

## Status
active

## Objective
Move clients to v2 without breaking v1 consumers.

## State
- The v2 client covers four endpoints.

## Decisions
- Keep compatibility during migration.

## Constraints
- v1 consumers remain in production.

## Assumptions
- The contract suite covers the supported consumers.

## Open Questions
- None.

## Next
- Run the contract suite after the final endpoint lands.

## Context
The first plan removed v1 before parity. That plan was rejected.
