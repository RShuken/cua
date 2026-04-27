---
name: cua-local
description: Use the locally installed Cua CLI for direct macOS host automation when the user wants computer control, browser or app driving, clicking, typing, screenshots, hotkeys, or rough UI automation on this machine without relying on Cua cloud auth or MCP. Trigger for requests to use Cua locally, brute-force UI actions, drive Chrome or macOS apps, open URLs, step through forms, or wrap working `cua do ...` host commands.
---

# cua-local

Use the local Cua CLI as a direct host-control layer on this Mac when cloud auth or the Cua MCP server is unavailable.

## Current known-good scope on 4C

The following have been directly validated in this workspace:
- `cua do-host-consent`
- `cua do switch host`
- `cua do status`
- `cua do screenshot`
- `cua do move`
- `cua do click`
- `cua do key`
- `cua do hotkey`
- `cua do type`

The cloud auth / MCP path is currently not reliable because `cua.ai` DNS/auth may be unavailable. Prefer local CLI control first.

## Binary and wrapper

- Cua binary: `~/.local/bin/cua`
- Wrapper script: `scripts/cua-local.sh`

Always use the wrapper script unless there is a specific reason to call `~/.local/bin/cua` directly.

## Command tiers

### Primitive
```bash
scripts/cua-local.sh move 500 400
scripts/cua-local.sh click 500 400
scripts/cua-local.sh right-click 500 400
scripts/cua-local.sh double-click 500 400
scripts/cua-local.sh drag 500 400 700 500
scripts/cua-local.sh scroll down 3
scripts/cua-local.sh type "hello world"
scripts/cua-local.sh paste "longer clipboard text"
scripts/cua-local.sh key enter
scripts/cua-local.sh hotkey cmd+r
scripts/cua-local.sh press tab tab enter
```

### Verification and state
```bash
scripts/cua-local.sh status
scripts/cua-local.sh screenshot
scripts/cua-local.sh screenshot-path
scripts/cua-local.sh last-screenshot
scripts/cua-local.sh browser-title
scripts/cua-local.sh frontmost-app
scripts/cua-local.sh ensure-frontmost "Google Chrome"
scripts/cua-local.sh wait-for-window "Google Chrome"
scripts/cua-local.sh safe-step 1 navigate "https://example.com"
```

### Convenience and workflow
```bash
scripts/cua-local.sh wait 1
scripts/cua-local.sh pause-ms 250
scripts/cua-local.sh retry 3 browser-title
scripts/cua-local.sh open-app "Google Chrome"
scripts/cua-local.sh activate-app "Google Chrome"
scripts/cua-local.sh open-url "https://example.com"
scripts/cua-local.sh browser-open "https://example.com"
scripts/cua-local.sh navigate "https://example.com"
scripts/cua-local.sh goto-url "https://example.com"
scripts/cua-local.sh address-bar
scripts/cua-local.sh new-tab
scripts/cua-local.sh close-tab
scripts/cua-local.sh back
scripts/cua-local.sh forward
scripts/cua-local.sh tab 3
scripts/cua-local.sh fill-form 2 "Ryan" 1 "ryan@example.com"
scripts/cua-local.sh raw window ls
```

## Recommended workflows

### Browser navigation
1. `scripts/cua-local.sh browser-open "https://target"`
2. `scripts/cua-local.sh wait-for-window "Google Chrome"`
3. `scripts/cua-local.sh screenshot-path`
4. Use `navigate`, `address-bar`, `hotkey`, `key`, `type`, and `click`
5. Verify with `browser-title`, `last-screenshot`, another screenshot, or Peekaboo observation

### Safe verified step
Use `safe-step` when a flow is brittle and you want automatic before/after artifacts.

```bash
scripts/cua-local.sh safe-step 1 browser-goto "https://example.com"
```

This emits:
- `before=<path>`
- `after=<path>`

### Keyboard-first form fill
1. Ensure the target app is frontmost
2. Use `tab` or `press`
3. Use `fill-form` for predictable tab-order forms
4. Use `submit` to finish
5. Verify

### Rough brute-force UI stepping
1. Screenshot before action
2. Apply one small action
3. Wait briefly
4. Screenshot again
5. Repeat

## Behavior rules

1. Ensure host mode is selected before interaction-heavy flows.
2. Prefer keyboard-first automation for brittle browser/app flows.
3. Use `ensure-frontmost` and `wait-for-window` before sending keyboard sequences to an app that matters.
4. Use `tab`, `press`, and `fill-form` when the UI has a stable keyboard order. Avoid coordinate clicks when keyboarding is viable.
5. Prefer `screenshot-path`, `browser-title`, `last-screenshot`, and `safe-step` over manual artifact tracking.
6. Treat "command succeeded" as "input sent", not necessarily "outcome verified".
7. If Cua reports success but UI state is unclear, verify with `peekaboo see`, `peekaboo list windows`, `browser-title`, or another screenshot.
8. Do not claim a UI action worked without verification when the task matters.
9. Use `raw` only as an escape hatch when the wrapper does not expose the needed Cua primitive cleanly.
10. If cloud auth is required, report the exact blocker rather than pretending the local wrapper solves it.

## Troubleshooting

- If commands fail because host consent is missing, run:
  `~/.local/bin/cua do-host-consent`
- If commands target the wrong platform, run:
  `~/.local/bin/cua do switch host`
- If auth-related commands fail, this is expected when `cua.ai` is unavailable. Fall back to local `do` commands.
- Hotkeys use `cmd+r` style syntax, not `cmd,r`.
- `double-click` is implemented via Cua double-click behavior when available, otherwise equivalent timing still matters at the UI layer.
- `fill-form` is best for simple tab-order forms, not arbitrary rich web apps.
- `navigate` and `goto-url` are preferred names; `browser-goto`, `launch-app`, `focus-app`, `tab-n`, `press-seq`, `form-fill`, and `shell` remain compatibility aliases.
- `raw` is preferred over `shell` for Cua passthrough because it matches what the wrapper is actually doing.
- Set `CUA_LOCAL_QUIET=1` when you need less verbose output from looped macros.
- Set `CUA_LOCAL_DELAY=0.25` or similar if a target UI needs slower pacing.
- Run `scripts/smoke-test.sh` after substantial wrapper changes so SKILL examples stay honest.
- Use `scripts/sync-to-fork.sh` to copy the current workspace skill into the fork clone, commit only if changed, and push to `origin/main`.
