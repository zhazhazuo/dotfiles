# Plan: session tokens for the dashboard

## Change

1. On login, the API returns a JWT in the response body.
2. The dashboard stores the token in localStorage.
3. Every fetch sends the token in an Authorization header.
4. The token lasts 30 days and there is no refresh path.
5. The migration adds a `last_login` column in `002_login.sql`.

## Rollout

Deploy on Thursday. If it fails, roll back by dropping the column.
