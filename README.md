# Stacked PR Viewer

Self-hosted tool for a small team to view chains of dependent GitHub PRs (stacked PRs) as one combined diff, with per-user "what's changed since I last looked" tracking and local review comments.

## Stack

Rails 8.1, SQLite (via Solid Queue/Cache/Cable — no Redis or Postgres needed), Rails 8 built-in session auth, Octokit for the GitHub API, `@pierre/diffs` (vanilla JS API) for diff rendering.

## Setup

1. Install Ruby 3.4.x (with DevKit if on Windows) and Rails 8.1.
2. `bundle install`
3. `npm install`
4. `ruby bin/rails db:prepare`
5. `npm run build:stack-diff`
6. `ruby bin/rails db:seed` — creates a login user: `team@example.com` / `changeme123` (change this before sharing with a real team).
7. `ruby bin/rails server`
8. In a separate terminal, `ruby bin/jobs` to run the background sync worker (or rely on `SOLID_QUEUE_IN_PUMA` in production).

Sign in, then "Add a repo" using a GitHub PAT with `repo` scope to start tracking a repository. Stacks are auto-detected from open PRs' base-branch chains every 5 minutes, or trigger a sync manually:

```
ruby bin/rails runner "SyncRepoJob.perform_now(RepoConfig.first)"
```

## Running tests

```
ruby bin/rails test
ruby bin/rails test:system
```

## Notes

- On Windows, invoke `bin/rails` as `ruby bin/rails ...` — running it bare can silently swallow output.
- Comments are local-only and never synced back to GitHub.
- Out of scope for this version: GitHub OAuth login (uses a single shared PAT), writing comments back to GitHub, and Kamal deployment configuration.
