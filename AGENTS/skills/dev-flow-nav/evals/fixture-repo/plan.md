# Plan: parser and cache

Three independent tasks, no shared state:
1. Add tests for `parseValue`.
2. Replace the page cache key with the tenant key.
3. Delete the mock-only suite.
