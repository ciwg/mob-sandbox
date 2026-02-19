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

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "[postCreate] apt-get not found; skipping OS package installs."
    return 0
  fi

  echo "[postCreate] Installing neovim via apt-get..."
  set +e
  sudo DEBIAN_FRONTEND=noninteractive apt-get update
  local rc=$?
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

  if [[ -d "${plugin_dir}" ]]; then
    echo "[postCreate] copilot.vim already installed."
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "[postCreate] git not found; skipping copilot.vim install."
    return 0
  fi

  echo "[postCreate] Installing copilot.vim..."
  mkdir -p "$(dirname "${plugin_dir}")"
  set +e
  git clone https://github.com/github/copilot.vim "${plugin_dir}"
  local rc=$?
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
