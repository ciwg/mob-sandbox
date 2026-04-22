# mob-sandbox

This is a sandbox for training mob programming.  The goal is to
practice working together as a team to solve problems and learn from
each other.

## Codespaces

This repo includes a dev container config in `.devcontainer/` for GitHub
Codespaces / VS Code Dev Containers.

- Recommended secret: `OPENAI_API_KEY` (set as a per-user Codespaces secret).
- Post-create installs: `mob-consensus`, `codex`, `neovim`, `copilot.vim` (all best-effort).
- Per-user dotfiles: use GitHub Codespaces “Dotfiles” settings to bring your own `~/.config/nvim/` (or `~/.vimrc`).

### Optional GUI desktop (noVNC)

This repo also includes an **opt-in** GUI-focused devcontainer config at
`.devcontainer/gui/devcontainer.json` that enables a lightweight desktop you can
access from your browser via **noVNC**.

If Codespaces fails to build this configuration and drops you into a small Alpine
"recovery container", check the Codespace logs for “no space left on device” and
retry with a larger machine size or after a full rebuild.

How to use it:
- In GitHub’s UI when creating a new Codespace, choose the GUI devcontainer
  configuration (`.devcontainer/gui/devcontainer.json`).
- From the CLI, you can create a Codespace with:
  - `gh codespace create -R <owner/repo> --devcontainer-path .devcontainer/gui/devcontainer.json`
- For an existing Codespace, rebuild it and select the GUI configuration when
  prompted (VS Code / Codespaces command palette: “Rebuild Container”).
- Once the container is running, open forwarded port `6080` (“Desktop (noVNC)”)
  and use password `vscode`.
- Copy/paste: use the **noVNC clipboard** (sidebar clipboard icon) to move text
  between your computer and the in-container desktop. A reminder should pop up
  inside the desktop when the session starts.
- A GUI browser (`epiphany`, a.k.a. GNOME Web) is installed; launch it from the
  desktop or run `epiphany` in a terminal inside the noVNC session.
- Note: in Codespaces, Epiphany's WebKit sandbox often can't start due to
  restrictions on unprivileged user namespaces. The GUI devcontainer config sets
  `WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1` so the browser can run.

To change the desktop password, edit `.devcontainer/gui/devcontainer.json` and
rebuild the container.

Note: `gh codespace logs` and `gh codespace ssh` rely on an SSH server in the
container. The GUI devcontainer config includes the `sshd` feature to support
that workflow.

Testing footnotes [^foo] [^bar] [^1]. 

And more [^foo].

[^1]: number 1 
[^bar]: bar note
[^foo]: [foo.com](http://foo.com)
[^bar]: dup bar
