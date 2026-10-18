# account-action Edge Function

This function makes paper trading, daily rewards, resets, and leaderboard equity server-authoritative.

Deploy after applying `supabase/migrations/20261013_secure_account_actions.sql`.

Set one custom secret:

`MARKET_DATA_URL=https://quantquest-market-data.quantquest-finance.workers.dev`

Supabase automatically provides `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` to deployed Edge Functions.
