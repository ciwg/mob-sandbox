# 003 - Manage mob-sandbox devcontainer provisioning via decomk-conf-cswg (updateContent-only)

Goal: refactor `ciwg/mob-sandbox` so Codespaces/devcontainers are set up by
**decomk** using the shared config repo **`ciwg/decomk-conf-cswg`**, instead of
by repo-local scripts like `.devcontainer/postCreateCommand.sh`.

This file is intentionally long and plain-English: the next Codex session will
run in `~/lab/decomk-conf-cswg` and won't have access to prior chat context or
logs, so it needs enough background to act independently.

## Background (what exists today)

`mob-sandbox` currently has two devcontainer configs:

- Non-GUI default: `.devcontainer/devcontainer.json`
  - Uses `mcr.microsoft.com/devcontainers/universal:2`
  - Runs `.devcontainer/postCreateCommand.sh`
- Optional GUI: `.devcontainer/gui/devcontainer.json`
  - Uses `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`
  - Enables Dev Container Features:
    - `ghcr.io/devcontainers/features/desktop-lite:1` (desktop + noVNC web UI)
    - `ghcr.io/devcontainers/features/sshd:1` (enables `gh codespace ssh` / logs)
  - Runs `.devcontainer/postCreateCommand.sh` with `MOB_SANDBOX_GUI=1`
  - Sets `WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1` so Epiphany runs in Codespaces

Today, `mob-sandbox/.devcontainer/postCreateCommand.sh` installs packages/tools:
- OS packages via `apt-get` (e.g. `neovim`, `ripgrep`, `iproute2`, `golang-go`, `nodejs/npm`)
- GUI-only packages (e.g. `epiphany-browser`, `libnotify-bin`, `x11-utils`)
- User-home tools:
  - `mob-consensus` via `go install`
  - `codex` via `npm install -g @openai/codex`
  - Neovim Copilot plugin (`copilot.vim`) via `git clone`
- noVNC clipboard reminder artifacts written into the user’s home directory:
  - `~/.local/bin/mob-novnc-clipboard-reminder`
  - `~/.config/autostart/mob-novnc-clipboard-reminder.desktop`

The intent of decomk is to move that provisioning logic out of consumer repos.

## Definitions (plain English)

- Devcontainer: the container environment Codespaces uses for the repo.
- decomk: a bootstrap tool that:
  1) installs decomk itself,
  2) clones/syncs a shared config repo (`decomk-conf-cswg`),
  3) runs `make` from that repo in a stamp directory so installs are idempotent.
- decomk-conf-cswg: the shared config repo holding:
  - `decomk.conf` (policy: what to run for each repo/context)
  - `Makefile` (the install steps / dependency graph)
- updateContent phase: a devcontainer lifecycle hook that runs early (before the
  interactive dev session is ready). We want installs here.
- postCreate phase: runs after container creation. We want this to do **no installs**
  (maybe validation only), so we never hide slow/flaky installs here.

## Hard constraints (must satisfy)

- `DECOMK_HOME` must be exactly `/var/decomk`.
- `DECOMK_LOG_DIR` must be exactly `/var/log/decomk`.
- All installation of packages/tools must happen in `updateContent`.
- GUI vs non-GUI must be handled by different Makefile targets in `decomk-conf-cswg`.
- All provisioning logic (Makefile, decomk.conf, image strategy) belongs in
  `~/lab/decomk-conf-cswg`, not in `mob-sandbox`.

## Key technical issue: `/var/decomk` permissions

decomk’s stage-0 script creates `$DECOMK_HOME` and `$DECOMK_LOG_DIR` with `mkdir -p`.
In most devcontainers, the remote user is non-root and cannot write under `/var`
unless the image (or an early bootstrap step) prepares those directories.

We need an explicit strategy so the dev user can write to:
- `/var/decomk`
- `/var/log/decomk`

Long-term, this should be solved by the image strategy owned by `decomk-conf-cswg`
(e.g., a base image that creates/chowns these paths). Short-term, we may need a
tiny wrapper in `mob-sandbox` that does only `sudo -n mkdir/chown` before calling
the decomk stage-0 script. That wrapper must not install packages.

Notes from decomk behavior (important):
- decomk chooses how to run `make` based on whether it is already root:
  - if `os.Geteuid() == 0`, decomk runs `make` directly as root (no `sudo` path)
  - otherwise, decomk uses passwordless `sudo -n` when configured to run make as root
- That means if stage-0 runs as root (for example by using `sudo -n bash ...` or by
  setting `"remoteUser": "root"`), decomk will also run `make` directly as root.
- Caution: if decomk runs as root *without* `sudo`, `SUDO_USER` is usually unset,
  and decomk will likely treat the “dev user” (`DECOMK_DEV_USER`) as `root`. If we
  need to write files into a non-root user’s home directory (e.g. Neovim config),
  we must either:
  - ensure decomk sees a real `SUDO_USER` (run stage-0 via `sudo` from a non-root user),
  - or explicitly drop privileges in Make recipes to a known non-root user.

## Other prerequisite: stage-0 needs bootstrap tools

decomk’s stage-0 script installs decomk via `go install` and syncs repos via `git`,
then runs `make`. That means the devcontainer base image must already have:
- `bash`
- `git`
- `go`
- `make`
- `sudo` (unless we always run stage-0 as root and never need sudo)

For `mob-sandbox` today:
- `universal:2` likely already includes these prerequisites.
- `base:ubuntu-24.04` may not; we previously installed some prerequisites in
  `postCreateCommand.sh`, but that approach will be removed by this TODO.

## Desired end state

In `mob-sandbox`:
- Devcontainer lifecycle runs decomk for both `updateContent` and `postCreate`.
- `postCreate` does not install packages/tools.
- `.devcontainer/postCreateCommand.sh` is removed or unused.
- GUI desktop/noVNC still comes from Features for now (defer migrating that into decomk).

In `decomk-conf-cswg`:
- `decomk.conf` has a stanza for `ciwg/mob-sandbox` (matches `GITHUB_REPOSITORY`).
- `Makefile` has append-only, versioned targets that install pinned packages/tools.
- One Make target is for non-GUI, another for GUI (adds browser + reminder deps/files).

## Work plan (checklist)

### A) decomk-conf-cswg (authoritative provisioning)

- [ ] 003.1 Fix `decomk.conf` to satisfy decomk validation (“tuple/macro-only”).
  - Background: newer decomk rejects bare RHS tokens unless they are defined keys.
  - Example: `DEFAULT: all` is invalid unless `all:` is also a key in decomk.conf.
- [ ] 003.2 Add append-only v1 Makefile targets for mob-sandbox installs (pinned versions):
  - [ ] 003.2.1 `mob-sandbox-cli-updateContent-v1` (CLI baseline)
  - [ ] 003.2.2 `mob-sandbox-gui-updateContent-v1` (GUI extras: browser + reminder deps/files)
  - [ ] 003.2.3 `mob-sandbox-postCreate-v1` (no installs; validation/logging only)
- [ ] 003.3 Add decomk.conf tuple variables that decomk can use as action args (values are target names):
  - [ ] 003.3.1 `MOB_SANDBOX_UPDATECONTENT_CLI='mob-sandbox-cli-updateContent-v1'`
  - [ ] 003.3.2 `MOB_SANDBOX_UPDATECONTENT_GUI='mob-sandbox-gui-updateContent-v1'`
  - [ ] 003.3.3 `MOB_SANDBOX_POSTCREATE='mob-sandbox-postCreate-v1'`
- [ ] 003.4 Make `/var/decomk` and `/var/log/decomk` writable by the dev user.
  - Preferred: solve via base image strategy owned by `decomk-conf-cswg`.
  - Acceptable short-term option A: consumer-side wrapper that only mkdir/chown’s these dirs.
  - Acceptable short-term option B: run stage-0 via `sudo -n` from a non-root `remoteUser`
    so `SUDO_USER` is set and decomk can still identify `DECOMK_DEV_USER` correctly.
  - Option C (use with caution): set `"remoteUser": "root"` in the consumer devcontainer.
    This makes stage-0 and decomk run as root and avoids the sudo path, but it can
    also cause `DECOMK_DEV_USER=root` unless handled explicitly.
- [ ] 003.5 Pin versions:
  - [ ] 003.5.1 Pin base image(s) (by digest).
  - [ ] 003.5.2 Pin apt package versions (exact `pkg=version`).
  - [ ] 003.5.3 Decide whether Go/NPM installs are pinned or `@latest` (prefer pinned for reproducibility).
- [ ] 003.6 Document the bump workflow: add `*-v2` targets; never edit v1 targets.

### B) mob-sandbox (stage-0 wiring only; no provisioning)

- [ ] 003.7 Replace `.devcontainer/devcontainer.json` to call decomk stage-0 for:
  - `updateContentCommand`
  - `postCreateCommand`
  - set `DECOMK_HOME=/var/decomk`, `DECOMK_LOG_DIR=/var/log/decomk`,
    `DECOMK_TOOL_URI`, and `DECOMK_CONF_URI`.
- [ ] 003.8 Replace `.devcontainer/gui/devcontainer.json` similarly, while keeping GUI Features for now.
- [ ] 003.9 Add the generated `.devcontainer/decomk-stage0.sh` (managed; do not hand-edit).
- [ ] 003.10 If needed, add a wrapper that prepares `/var/decomk` + `/var/log/decomk` then execs decomk stage-0.
- [ ] 003.11 Remove or stop referencing `.devcontainer/postCreateCommand.sh`.

### C) Validation (Codespaces)

- [ ] 003.12 Non-GUI Codespace: confirm installs happen in `updateContent` only and tools exist for the dev user.
- [ ] 003.13 GUI Codespace: confirm noVNC works (port 6080), the in-desktop browser runs, and the clipboard reminder appears.
- [ ] 003.14 Confirm decomk state/logs are written under `/var/decomk` and `/var/log/decomk`.

## Deferred follow-up (not part of this TODO)

- Move GUI stack (desktop/VNC/noVNC/sshd) from devcontainer Features into decomk-managed provisioning.
