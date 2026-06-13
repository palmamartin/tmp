---
name: dev-server
description: "Starts or reuses the repository's local development server and exposes preview URLs. Use when asked to run, restart, inspect, or share the dev server, or when a task needs a live app for verification, browser testing, screenshots, or checking UI output."
---

# Dev Server

Use this skill when the user asks to run the app locally, start the dev server, restart it, check whether it is running, or provide a preview URL.

Also use this skill whenever an implementation, review, or QA task needs a live running app to verify behavior, inspect rendered output, run browser automation, capture screenshots, or confirm that UI changes work as expected.

## Workflow

1. Prefer the bundled helper. Run it from the app directory that contains `package.json` (this may be a subfolder of the repository).

   If you are the Amp coding agent, run the helper with `--amp` so it publishes preview metadata:

   ```sh
   "$(git rev-parse --show-toplevel)/.agents/skills/dev-server/scripts/ensure-dev-server.sh" --amp
   ```

   For manual local-only use, omit `--amp`.

   The helper is intended to:
   - detect the current app's package manager from `package.json` or lockfiles in the app directory or workspace root,
   - install dependencies if needed,
   - start the dev server in the background,
   - wait until it responds locally,
   - write logs and PID files under the app directory's `.amp/`, and
   - when run with `--amp`, write preview metadata to the repo root `.amp/preview.json` when Tailscale preview support is available.

2. If the helper fails, read the error before retrying. Common checks:
   - Inspect the project package scripts, for example `cat package.json` or the relevant app's `package.json`.
   - Confirm the package manager from lockfiles before installing or running commands.
   - Confirm the expected port from the framework output or existing config.
   - Check `.amp/dev-server.log` for the actual failure.

3. Do not start duplicate servers blindly. If `.amp/dev-server.pid` exists, verify it with `kill -0 $(cat .amp/dev-server.pid)` before starting another process.

4. Report the useful URL(s) to the user:
   - local URL, usually `http://localhost:$HTTP_PROXY_PORT/` or the framework-reported localhost URL,
   - preview URL from `.amp/preview.json` if present.

## Environment

- `HTTP_PROXY_PORT` may be set to choose the localhost port. If unset, use the helper default.
- `--amp` enables Amp-specific preview publishing. Omit it for manual local-only use.
- Keep generated runtime files in `.amp/`; do not commit logs, PID files, or other transient output.

## Troubleshooting

- If dependencies are missing, install with the package manager indicated by the repo's lockfile.
- If the chosen port is occupied, either reuse the existing compatible server or set `HTTP_PROXY_PORT` to a free port and run the helper again.
- If Tailscale is unavailable, the local dev server can still be valid; explain that only the external preview URL could not be created.
- If readiness checks fail, include the last relevant lines of `.amp/dev-server.log` in the user-facing blocker summary.
