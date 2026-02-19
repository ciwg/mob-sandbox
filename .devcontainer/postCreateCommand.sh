#!/usr/bin/env bash
set -euo pipefail

# Keep setup minimal and fast.
#
# This hook runs after the Codespace/devcontainer is created. Add lightweight,
# deterministic setup here (e.g. language dependency downloads) so everyone
# starts from the same baseline environment.

echo "[postCreate] Repo: $(basename "$(pwd)")"

# Install OS packages that are useful in this sandbox.
#
# Prefer installing OS packages here (instead of in the base image) while we're
# experimenting. If this grows, consider moving OS package installs into a
# `.devcontainer/Dockerfile` so Codespaces prebuilds can cache them.
install_os_packages() {
  if command -v nvim >/dev/null 2>&1; then
    echo "[postCreate] neovim already installed."
    return 0
  fi


  if ! command -v apt-get >/dev/null 2>&1; then
    echo "[postCreate] apt-get not found; skipping OS package installs."
    return 0
  fi

  # Some base images ship extra apt sources without their GPG keys. If `apt-get
  # update` fails, disable a small set of known-problem sources and retry.
  disable_apt_sources_containing() {
    local needle="$1"
    local sources_dir="/etc/apt/sources.list.d"

    if [[ ! -d "${sources_dir}" ]]; then
      return 0
    fi
    if ! command -v grep >/dev/null 2>&1; then
      return 0
    fi

    local matches
    matches="$(sudo grep -RIl -- "${needle}" "${sources_dir}" 2>/dev/null || true)"
    if [[ -z "${matches}" ]]; then
      return 0
    fi

    echo "[postCreate] Disabling apt sources containing '${needle}'..."
    while IFS= read -r match; do
      [[ -z "${match}" ]] && continue
      [[ "${match}" == *.disabled ]] && continue
      sudo mv "${match}" "${match}.disabled"
    done <<<"${matches}"
  }

  echo "[postCreate] Installing neovim via apt-get..."
  set +e
  sudo DEBIAN_FRONTEND=noninteractive apt-get update
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    # Workaround for a common failure mode in the universal devcontainer image:
    # a Yarn apt source is present but its signing key isn't.
    disable_apt_sources_containing "dl.yarnpkg.com/debian"
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    rc=$?
  fi
  if [[ $rc -eq 0 ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends neovim
    rc=$?
  fi
  set -e

  if [[ $rc -ne 0 ]]; then
    echo "[postCreate] neovim install failed (rc=${rc}); continuing."
    return 0
  fi

  echo "[postCreate] neovim installed."
}

install_os_packages

# Install common CLI tools used in mob programming exercises.
#
# Notes:
# - Keep installs best-effort; a failure here should not break container creation.
# - Prefer installing into ~/.local/bin (usually already on PATH in Codespaces).
install_mob_tools() {
  local local_bin="${HOME}/.local/bin"

  mkdir -p "${local_bin}"
  export PATH="${local_bin}:${PATH}"

  if command -v mob-consensus >/dev/null 2>&1; then
    echo "[postCreate] mob-consensus already installed."
    return 0
  fi

  if ! command -v go >/dev/null 2>&1; then
    echo "[postCreate] go not found; skipping mob-consensus install."
    return 0
  fi

  # Try a couple common Go install paths. We keep this tolerant because the
  # repo layout may change and because private repo auth can fail on first run.
  echo "[postCreate] Installing mob-consensus..."
  set +e
  GOBIN="${local_bin}" go install github.com/stevegt/mob-consensus@latest
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    GOBIN="${local_bin}" go install github.com/stevegt/mob-consensus/cmd/mob-consensus@latest
    rc=$?
  fi
  set -e

  if [[ $rc -ne 0 ]]; then
    echo "[postCreate] mob-consensus install failed (rc=${rc}); continuing."
    return 0
  fi

  echo "[postCreate] mob-consensus installed to ${local_bin}."
}

install_mob_tools

# Install the OpenAI Codex CLI.
#
# We install this in the user's home directory so it works without sudo and so
# each Codespace user can manage/upgrade it independently.
install_codex_cli() {
  local local_bin="${HOME}/.local/bin"

  mkdir -p "${local_bin}"
  export PATH="${local_bin}:${PATH}"

  if command -v codex >/dev/null 2>&1; then
    echo "[postCreate] codex already installed."
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    echo "[postCreate] npm not found; skipping Codex CLI install."
    return 0
  fi

  echo "[postCreate] Installing Codex CLI (@openai/codex)..."
  set +e
  npm_config_prefix="${HOME}/.local" npm install -g @openai/codex
  local rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    echo "[postCreate] Codex CLI install failed (rc=${rc}); continuing."
    return 0
  fi

  echo "[postCreate] Codex CLI installed to ${local_bin}."
}

install_codex_cli

# Install the GitHub Copilot plugin for Neovim using Neovim's built-in package
# manager layout.
#
# The plugin still needs a one-time interactive setup inside Neovim
# (`:Copilot setup`) per user.
install_neovim_copilot_plugin() {
  local plugin_dir="${HOME}/.config/nvim/pack/github/start/copilot.vim"
  local plugin_repo="https://github.com/github/copilot.vim"

  # If the plugin directory exists and is usable, leave it alone.
  if [[ -e "${plugin_dir}" ]]; then
    if command -v git >/dev/null 2>&1 && git -C "${plugin_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "[postCreate] copilot.vim already installed."
      return 0
    fi

    # If it looks like a broken git clone, back it up and reinstall. We avoid
    # deleting non-git directories because users may manage plugins via dotfiles.
    if [[ -d "${plugin_dir}/.git" ]]; then
      local backup_dir="${plugin_dir}.bak.$(date +%Y%m%d%H%M%S)"
      echo "[postCreate] copilot.vim install looks broken; moving to ${backup_dir}..."
      mv "${plugin_dir}" "${backup_dir}"
    else
      echo "[postCreate] ${plugin_dir} exists but is not a git repo; skipping copilot.vim install."
      return 0
    fi
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "[postCreate] git not found; skipping copilot.vim install."
    return 0
  fi

  echo "[postCreate] Installing copilot.vim..."
  mkdir -p "$(dirname "${plugin_dir}")"

  # Prefer a shallow git clone so updates are easy, but fall back to downloading
  # an archive if `git clone` fails for any reason.
  set +e
  git clone --depth 1 "${plugin_repo}" "${plugin_dir}"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    rm -rf "${plugin_dir}"
    if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
      local tmp_dir
      tmp_dir="$(mktemp -d)"
      curl -fsSL "${plugin_repo}/archive/HEAD.tar.gz" | tar -xz -C "${tmp_dir}"
      rc=$?
      if [[ $rc -eq 0 ]]; then
        local extracted_dir=""
        local candidate
        for candidate in "${tmp_dir}"/copilot.vim-*; do
          if [[ -d "${candidate}" ]]; then
            extracted_dir="${candidate}"
            break
          fi
        done
        if [[ -n "${extracted_dir}" ]]; then
          mv "${extracted_dir}" "${plugin_dir}"
          rc=$?
        else
          rc=1
        fi
      fi
      rm -rf "${tmp_dir}"
    fi
  fi
  set -e

  if [[ $rc -ne 0 ]]; then
    echo "[postCreate] copilot.vim install failed (rc=${rc}); continuing."
    return 0
  fi

  echo "[postCreate] copilot.vim installed to ${plugin_dir}."
}

install_neovim_copilot_plugin

# If this sandbox ever grows a Go module, prefetch deps to speed up first builds.
if [[ -f go.mod ]] && command -v go >/dev/null 2>&1; then
  echo "[postCreate] go.mod detected; downloading modules..."
  go mod download
fi
