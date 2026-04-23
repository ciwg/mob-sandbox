# 004 - Decomk parity (CLI): make default Codespace match legacy `postCreateCommand.sh`

Goal: the default (non-GUI) Codespace created from `ciwg/mob-sandbox` should have
the same baseline tools as before, but provisioned via **decomk** (using
`ciwg/decomk-conf-cswg`) instead of `.devcontainer/postCreateCommand.sh`.

This TODO is written for the *next* Codex session that will run in
`~/lab/decomk-conf-cswg` and won’t have access to this chat history.

## What “equivalent” means (legacy behavior)

Legacy CLI provisioning lived in:
- `.devcontainer/postCreateCommand.sh` (runs after container create)
- `.devcontainer/devcontainer.json` (old: `universal:2` image + PATH + secrets)

Baseline tools that were installed (CLI mode):
- OS packages (apt): `neovim`, `openssh-server`, `ripgrep`, `iproute2`, `golang-go`,
  `nodejs`, `npm`
- User-home tools:
  - `mob-consensus` via `go install ...` into `~/.local/bin`
  - OpenAI Codex CLI via `npm install -g @openai/codex` into `~/.local/bin`
  - Neovim Copilot plugin via `git clone` into `~/.config/nvim/pack/github/start/copilot.vim`
- Devcontainer wiring:
  - `~/.local/bin` is on PATH (`remoteEnv.PATH`)
  - `OPENAI_API_KEY` secret is declared in devcontainer config (`secrets`)

Important policy for the decomk refactor:
- All OS package installs should happen in the **`updateContent`** phase (so Codespaces
  prebuilds can cache them).
- `postCreate` should avoid OS installs and stick to per-user setup/evidence.

GUI-only extras (browser, noVNC reminder, etc.) are tracked separately in TODO 005.

## Current state (after `decomk init` in mob-sandbox)

In `mob-sandbox`:
- `.devcontainer/devcontainer.json` now runs decomk stage-0 for `updateContent` and
  `postCreate`, and sets:
  - `DECOMK_HOME=/var/decomk`
  - `DECOMK_LOG_DIR=/var/log/decomk`
- That new `devcontainer.json` is missing several things the old one had:
  - no `image` or `build` stanza (may not be a valid devcontainer)
  - no `remoteEnv.PATH` for `~/.local/bin`
  - no `secrets.OPENAI_API_KEY`
  - `DECOMK_CONF_URI` is currently an SSH URL (`git@github.com:...`) which may fail
    in Codespaces if SSH keys aren’t available

In `decomk-conf-cswg`:
- `decomk.conf` currently maps `mob-sandbox` to `GUI_DESKTOP` (GUI forced even for
  CLI); this needs a CLI default context.
- `Makefile` `Block10` installs many basics but does **not** include:
  - `openssh-server` (only `openssh-client`)
  - `ripgrep`
  - `iproute2` (for `ss`)
  - `nodejs` / `npm`

Key bootstrap hazard:
- `mob-sandbox` stage-0 runs `mkdir -p /var/decomk /var/log/decomk` **without sudo**.
  If those aren’t writable by the stage-0 user, decomk won’t run (and you’ll only
  see failure markers/logs).

## Plan

- [ ] 004.1 Decide how stage-0 can write `/var/decomk` and `/var/log/decomk`.
  - Preferred: publish a base image (owned by `decomk-conf-cswg`) that pre-creates
    and `chown`s these dirs to the non-root dev user.
  - Alternative: call stage-0 via `sudo -n bash ...` from the non-root dev user so
    stage-0 runs as root (then Makefile must drop back to the dev user for user-home
    installs).
  - Avoid unless necessary: `remoteUser: root` (makes “per-user” installs tricky).
  - Acceptance: after a successful run, `/var/log/decomk/stage0-updateContent.log`
    exists and includes `decomk run updateContent` completing successfully.

- [ ] 004.2 Fix `decomk-conf-cswg/decomk.conf` so CLI is the default for `mob-sandbox`.
  - Add a non-GUI context (example: `MOB_SANDBOX_CLI`) with `DEVCONTAINER_GUI=0`.
  - Point `mob-sandbox:` at the CLI context by default (GUI should be opt-in).
  - Ensure the `postCreate` action tuple does not re-run apt installs.

- [ ] 004.3 Add pinned apt targets in `decomk-conf-cswg/Makefile` for missing CLI packages.
  - Required parity packages: `openssh-server`, `ripgrep`, `iproute2`, `nodejs`, `npm`.
  - Follow the repo’s append-only rule: add new versioned targets and wire them in;
    do not edit old versioned targets.

- [ ] 004.4 Add user-home tool targets in `decomk-conf-cswg/Makefile`.
  - Install `mob-consensus` into the dev user’s `~/.local/bin`.
  - Install `@openai/codex` into the dev user’s `~/.local/bin`.
  - Install `copilot.vim` into the dev user’s `~/.config/nvim/...`.
  - Notes:
    - Make may run as root; explicitly run these commands as the non-root dev user.
    - Acceptance: files are owned by the dev user, not root.

- [ ] 004.5 Restore the “devcontainer wiring” that was lost during `decomk init` (in `mob-sandbox`).
  - Add an `image` or `build` stanza to `.devcontainer/devcontainer.json` so it’s a
    valid devcontainer.
  - Re-add `remoteEnv.PATH` so `~/.local/bin` is on PATH.
  - Re-add the `secrets.OPENAI_API_KEY` entry.
  - Consider switching `DECOMK_CONF_URI` to HTTPS (and ideally pin a ref) so it
    works without SSH keys.

- [ ] 004.6 Validate in a fresh CLI Codespace.
  - `nvim`, `rg`, `ss`, `sshd`, `node`, `npm` all exist.
  - `mob-consensus` and `codex` exist on PATH for the dev user.
  - `~/.config/nvim/pack/github/start/copilot.vim` exists for the dev user.
  - Decomk state + logs live under `/var/decomk` and `/var/log/decomk`.

