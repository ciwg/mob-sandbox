# 002 - Add GUI desktop + noVNC to Codespace

## Decision Intent Log

ID: DI-002-20260518-052215
Date: 2026-05-18 05:22:15 UTC
Status: active
Decision: Treat `gh codespace create` API lookup timeouts as non-fatal and continue with the script-owned `gh codespace list` discovery/poll path.
Intent: GitHub CLI can create the Codespace and then fail while fetching it by generated name; the pull test should not exit before checking whether the Codespace appeared and can be polled normally.
Constraints: Keep real creation failures visible in `/tmp/cs-pull-test-mob-sandbox.log`; preserve the existing display-name lookup timeout as the final authority; do not hide later build or GUI-health failures.
Affects: `scripts/pull-test.sh`, `TODO/002-gui-desktop-novnc.md`

ID: DI-002-20260518-050312
Date: 2026-05-18 05:03:12 UTC
Status: active
Decision: Append both `gh codespace logs` output and GUI health-check output to the pull-test log file.
Intent: Make `/tmp/cs-pull-test-mob-sandbox.log` a complete handoff artifact that includes devcontainer build logs and the post-build GUI service/noVNC assertions that explain pass or fail.
Constraints: Preserve the existing log path default; keep terminal output visible while teeing to the log; avoid hiding the original health-check exit code.
Affects: `scripts/pull-test.sh`, `TODO/002-gui-desktop-novnc.md`

ID: DI-002-20260517-210209
Date: 2026-05-17 21:02:09 UTC
Status: active
Decision: Extend `scripts/pull-test.sh` so a successful pull test requires the GUI daemons to remain supervised and the noVNC desktop path to be reachable inside the Codespace.
Intent: Prevent green Codespaces build logs from hiding GUI services that briefly start, immediately exit, or leave noVNC unable to connect to the VNC desktop.
Constraints: Keep the test in the existing pull-test script; use `gh codespace ssh` for in-container assertions; fail loudly instead of silently accepting transient runit status; keep logs written to `/tmp/cs-pull-test-mob-sandbox.log`.
Affects: `scripts/pull-test.sh`, `TODO/002-gui-desktop-novnc.md`


Goal: run a lightweight Linux desktop environment inside the Codespace and access it
from a browser via noVNC (VNC over WebSockets), primarily for GUI-only tools.

Constraints/assumptions to verify:
- This repo's Codespace uses a devcontainer image; we likely don't have `systemd`.
- Services should start as the `codespace` user (or via `postStartCommand`), not as a
  long-running root daemon.
- Package installs can be large; prefer minimal packages and clean up apt caches to
  reduce "No space left on device" risk.
- Port forwarding in Codespaces provides an authenticated proxy; still treat a shared
  Codespace as a shared trust boundary.

Recommended approach:
- Prefer a separate **opt-in** GUI configuration (separate devcontainer config)
  so the default Codespace stays fast and small for CLI-only work.
- First try an existing Dev Container Feature that bundles a lightweight desktop
  + noVNC (`desktop-lite`) before hand-rolling X/VNC/noVNC setup.

Design choices to decide up front:
- Desktop: `xfce4` vs `lxqt` vs `openbox`/`fluxbox` (lighter is better).
- VNC server: TigerVNC (`Xtigervnc`) vs `x11vnc` (TigerVNC is common for full sessions).
- noVNC: install from distro packages vs vendored release + `websockify`.
- Startup: `devcontainer.json` `postStartCommand` vs a user-level background script.

Implementation plan:
- [ ] 002.1 Confirm base OS + package manager in the devcontainer
  image (`/etc/os-release`, `apt-get --version`) and whether `sudo`
  works.
- [x] 002.2 Decide whether this should be default-on or opt-in.
  - Decision: opt-in via a separate `.devcontainer/gui/devcontainer.json`.
  - Selection UX:
    - GitHub UI: choose the devcontainer configuration when creating/rebuilding.
    - `gh`: `gh codespace create --devcontainer-path .devcontainer/gui/devcontainer.json ...`
- [ ] 002.3 Prototype with the existing `desktop-lite` Dev Container Feature.
  - [x] 002.3.1 Add a separate devcontainer config at `.devcontainer/gui/devcontainer.json`
    that enables `ghcr.io/devcontainers/features/desktop-lite:1`.
  - [x] 002.3.2 Create a Codespace using that GUI config and confirm it works:
    open forwarded port `6080` and verify the desktop appears in the browser.
  - [ ] 002.3.3 If container creation falls back to an Alpine recovery container,
    pull Codespace logs and check for “no space left on device”. If present:
    - retry with a larger machine size and/or a smaller base image
    - run `gh codespace rebuild --full`
  - [x] 002.3.4 Install a GUI browser (so the desktop can browse the web).
  - [x] 002.3.5 Ensure the browser can run in Codespaces (work around WebKit sandbox constraints).
  - [x] 002.3.6 Add an in-desktop reminder to use the noVNC clipboard for copy/paste.
- [ ] 002.4 If the feature approach isn't viable, pick a minimal
  desktop stack (start with a window manager + terminal, then add a
  fuller DE only if needed).
- [ ] 002.5 Add install steps to `.devcontainer/postCreateCommand.sh`
  (or a separate GUI-specific install script) that:
  - installs X components, the chosen DE/WM, fonts, `dbus-x11`, VNC
    server, and noVNC.
  - uses `--no-install-recommends` where possible.
  - cleans up (`apt-get clean`, remove `/var/lib/apt/lists/*`) to save
    space.
- [ ] 002.6 Add a start script (e.g. `.devcontainer/start-desktop.sh`)
  that:
  - creates `~/.vnc/`
  - sets a VNC password (prompt or env var; never log it)
  - starts the VNC session on a fixed display (e.g. `:1` => `5901`)
  - starts noVNC (e.g. `6080`) pointing at `localhost:5901`
- [ ] 002.7 Add a stop script (e.g. `.devcontainer/stop-desktop.sh`)
  to kill VNC/noVNC cleanly and avoid orphan processes across
  restarts.
  - XXX what?  restarting a container restarts all processes, right?
- [x] 002.8 Update `.devcontainer/devcontainer.json` (or the GUI
  devcontainer config):
  - `forwardPorts`: at least `6080` (optionally `5901` for native VNC
    clients)
  - `portsAttributes` to label the port (e.g. "Desktop (noVNC)") and
    set visibility defaults (keep private).
- [x] 002.9 Document usage in `README.md`:
  - how to start/stop the desktop
  - how to open the forwarded port
  - how to set the VNC password securely
- [ ] 002.10 Security checks:
  - confirm ports are not set to public by default
  - confirm what happens when a Codespace is shared (do collaborators
    get the desktop?)
  - confirm secrets/passwords are not written to repo files or shell
    history
- [ ] 002.11 Basic validation:
  - [ ] 002.11.1 Open the noVNC URL and verify the desktop appears.
  - [ ] 002.11.2 Confirm the noVNC clipboard reminder appears in the desktop.
  - [ ] 002.11.3 Launch a browser inside the desktop and load a page.
  - [ ] 002.11.4 Verify clipboard + keyboard mappings are usable.
  - [ ] 002.11.5 Run a trivial GUI app (terminal, file manager) to confirm stability.
  - [x] 002.11.6 Automate pull-test validation that runit keeps `xvfb`, `openbox`, `x11vnc`, and `novnc` running and that noVNC reaches the VNC desktop.
  - [x] 002.11.7 Include GUI health-check pass/fail output in `/tmp/cs-pull-test-mob-sandbox.log`.
  - [x] 002.11.8 Continue after `gh codespace create` post-create lookup timeouts and rely on script-owned list/poll discovery.
