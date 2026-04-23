# 005 - Decomk parity (GUI): make GUI Codespace match legacy GUI provisioning

Goal: the GUI Codespace (created using `.devcontainer/gui/devcontainer.json`) should
keep working (noVNC desktop on port 6080) and should match the legacy GUI extras,
but provision them via **decomk** instead of `.devcontainer/postCreateCommand.sh`.

This TODO is written for the *next* Codex session that will run in
`~/lab/decomk-conf-cswg` and won’t have access to this chat history.

## What “equivalent” means (legacy GUI behavior)

Legacy GUI config:
- `.devcontainer/gui/devcontainer.json`:
  - base image: `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`
  - Dev Container Features:
    - `ghcr.io/devcontainers/features/sshd:1` (so `gh codespace ssh` works)
    - `ghcr.io/devcontainers/features/desktop-lite:1` (desktop + noVNC)
  - forwards port `6080`
  - sets `WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1` so Epiphany/WebKit can run
    in Codespaces (user namespaces are often disabled)
  - declares the `OPENAI_API_KEY` secret
- `.devcontainer/postCreateCommand.sh` with `MOB_SANDBOX_GUI=1`:
  - apt installs GUI-only packages:
    - `libnotify-bin` (for `notify-send`)
    - `x11-utils` (for `xmessage` fallback)
    - `epiphany-browser` (GNOME Web; avoids snap-heavy Firefox/Chromium)
  - installs a noVNC clipboard reminder:
    - script in `~/.local/bin/mob-novnc-clipboard-reminder`
    - autostart entry in `~/.config/autostart/*.desktop`

## Current state

- `mob-sandbox` GUI devcontainer still runs `.devcontainer/postCreateCommand.sh`.
- `decomk-conf-cswg` has:
  - a `GUI_DESKTOP` context and a `GUIDesktop` target,
  - but `GUIDesktop` is currently a placeholder (no installs).

## Plan

- [ ] 005.1 Decide where GUI-specific logic lives in `decomk-conf-cswg`.
  - Option A: implement GUI apt installs in the shared `GUIDesktop` target.
  - Option B: create a `MobSandboxGUI_*` target and keep `GUIDesktop` generic.
  - Either way: keep GUI installs additive on top of the CLI baseline (TODO 004).

- [ ] 005.2 Add pinned apt targets for GUI-only packages in `decomk-conf-cswg/Makefile`.
  - `libnotify-bin`
  - `x11-utils`
  - `epiphany-browser`
  - Follow the append-only rule: add new versioned targets, don’t edit old ones.

- [ ] 005.3 Add a per-user target to install the noVNC clipboard reminder.
  - Install the reminder script into the dev user’s `~/.local/bin/`.
  - Install the `.desktop` autostart file into the dev user’s `~/.config/autostart/`.
  - Ensure it’s safe/idempotent to run multiple times.

- [ ] 005.4 Switch `mob-sandbox/.devcontainer/gui/devcontainer.json` to decomk stage-0.
  - Replace `postCreateCommand: MOB_SANDBOX_GUI=1 .devcontainer/postCreateCommand.sh`
    with decomk `updateContentCommand` + `postCreateCommand`.
  - Keep the `sshd` and `desktop-lite` Features and the `6080` port forwarding.
  - Keep `WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1`.
  - Keep `remoteEnv.PATH` and `secrets.OPENAI_API_KEY`.

- [ ] 005.5 Validate in a fresh GUI Codespace.
  - Port `6080` opens and shows the desktop.
  - `epiphany` launches and can load a web page.
  - Clipboard reminder appears inside the desktop session.
  - `gh codespace ssh` works (sshd is running).

