# 002 - Add GUI desktop + noVNC to Codespace

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
- Prefer an separate GUI configuration (separate decomk config) so the
  default Codespace stays fast and small for CLI-only work.
  - XXX see ~/lab/decomk
- First try an existing Dev Container Feature that bundles a
  lightweight desktop + noVNC (commonly called `desktop-lite`) before
  hand-rolling X/VNC/noVNC setup.

Design choices to decide up front:
- Desktop: `xfce4` vs `lxqt` vs `openbox`/`fluxbox` (lighter is better).
- VNC server: TigerVNC (`Xtigervnc`) vs `x11vnc` (TigerVNC is common for full sessions).
- noVNC: install from distro packages vs vendored release + `websockify`.
- Startup: `devcontainer.json` `postStartCommand` vs a user-level background script.

Implementation plan:
- [ ] 002.1 Confirm base OS + package manager in the devcontainer
  image (`/etc/os-release`, `apt-get --version`) and whether `sudo`
  works.
- [ ] 002.2 Decide whether this should be default-on or opt-in; if
  opt-in, add a separate decomk config so users can select it when
  creating a Codespace.
  - XXX can gh codespace start or web UI accept flags?  or is this a
    feature thing?
- [ ] 002.3 Prototype with an existing Dev Container Feature (if
  available) that provides a lightweight desktop + noVNC; record what
  port it uses and how to start it.
- [ ] 002.4 If the feature approach isn't viable, pick a minimal
  desktop stack (start with a window manager + terminal, then add a
  fuller DE only if needed).
- [ ] 002.5 Add install steps to `.devcontainer/postCreateCommand.sh`
  (or a separate GUI-specific install script) that:
  - XXX use decomk
  - installs X components, the chosen DE/WM, fonts, `dbus-x11`, VNC
    server, and noVNC.
  - uses `--no-install-recommends` where possible.
  - cleans up (`apt-get clean`, remove `/var/lib/apt/lists/*`) to save
    space.
- [ ] 002.6 Add a start script (e.g. `.devcontainer/start-desktop.sh`)
  that:
  - XXX use decomk
  - creates `~/.vnc/`
  - sets a VNC password (prompt or env var; never log it)
  - starts the VNC session on a fixed display (e.g. `:1` => `5901`)
  - starts noVNC (e.g. `6080`) pointing at `localhost:5901`
- [ ] 002.7 Add a stop script (e.g. `.devcontainer/stop-desktop.sh`)
  to kill VNC/noVNC cleanly and avoid orphan processes across
  restarts.
  - XXX what?  restarting a container restarts all processes, right?
- [ ] 002.8 Update `.devcontainer/devcontainer.json` (or the GUI
  devcontainer config):
  - `forwardPorts`: at least `6080` (optionally `5901` for native VNC
    clients)
  - `portsAttributes` to label the port (e.g. "Desktop (noVNC)") and
    set visibility defaults (keep private).
- [ ] 002.9 Document usage in `README.md`:
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
  - open the noVNC URL and verify the desktop appears
  - verify clipboard + keyboard mappings are usable
  - run a trivial GUI app (terminal, file manager) to confirm
    stability
