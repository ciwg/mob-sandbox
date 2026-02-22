#!/usr/bin/env bash
set -uo pipefail

# Keep setup minimal and fast.
#
# This hook runs after the Codespace/devcontainer is created. Add lightweight,
# deterministic setup here (e.g. language dependency downloads) so everyone
# starts from the same baseline environment.
#
# This script is intentionally best-effort: failures should not break Codespace
# creation. Always return success at the end.

log() {
  echo "[postCreate] $*"
}

on_exit() {
  # The devcontainer CLI treats postCreateCommand as blocking; a non-zero exit
  # breaks Codespace creation. Force success, but emit a hint when we exit early.
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    log "postCreateCommand exited early (rc=${rc}); continuing."
  fi
  exit 0
}

trap on_exit EXIT

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_dir() {
  local dir="$1"
  local why="${2:-}"

  if [[ -d "${dir}" ]]; then
    return 0
  fi

  mkdir -p "${dir}"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    log "mkdir -p ${dir} failed${why:+ (${why})} (rc=${rc}); skipping."
    return 1
  fi

  return 0
}

log "Repo: $(basename "$(pwd)")"

if [[ -z "${HOME:-}" ]]; then
  log "HOME is unset; skipping user-level installs."
  exit 0
fi

# Install OS packages that are useful in this sandbox.
#
# Prefer installing OS packages here (instead of in the base image) while we're
# experimenting. If this grows, consider moving OS package installs into a
# `.devcontainer/Dockerfile` so Codespaces prebuilds can cache them.
install_os_packages() {
  if have_cmd nvim; then
    log "neovim already installed."
    return 0
  fi

  if ! have_cmd sudo; then
    log "sudo not found; skipping OS package installs."
    return 0
  fi

  if ! have_cmd apt-get; then
    log "apt-get not found; skipping OS package installs."
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
    if ! have_cmd grep; then
      return 0
    fi

    local matches
    matches="$(sudo grep -RIl -- "${needle}" "${sources_dir}" 2>/dev/null || true)"
    if [[ -z "${matches}" ]]; then
      return 0
    fi

    log "Disabling apt sources containing '${needle}'..."
    while IFS= read -r match; do
      [[ -z "${match}" ]] && continue
      [[ "${match}" == *.disabled ]] && continue
      sudo mv "${match}" "${match}.disabled" || true
    done <<<"${matches}"
  }

  log "Installing neovim via apt-get..."
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

  if [[ $rc -ne 0 ]]; then
    log "neovim install failed (rc=${rc}); continuing."
    return 0
  fi

  log "neovim installed."
}

install_os_packages

# Install common CLI tools used in mob programming exercises.
#
# Notes:
# - Keep installs best-effort; a failure here should not break container creation.
# - Prefer installing into ~/.local/bin (usually already on PATH in Codespaces).
install_mob_tools() {
  local local_bin="${HOME}/.local/bin"

  if ! ensure_dir "${local_bin}" "for Go-installed tools"; then
    return 0
  fi
  export PATH="${local_bin}:${PATH}"

  if command -v mob-consensus >/dev/null 2>&1; then
    log "mob-consensus already installed."
    return 0
  fi

  if ! have_cmd go; then
    log "go not found; skipping mob-consensus install."
    return 0
  fi

  # Try a couple common Go install paths. We keep this tolerant because the
  # repo layout may change and because private repo auth can fail on first run.
  log "Installing mob-consensus..."
  GOBIN="${local_bin}" go install github.com/stevegt/mob-consensus@latest
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    GOBIN="${local_bin}" go install github.com/stevegt/mob-consensus/cmd/mob-consensus@latest
    rc=$?
  fi

  if [[ $rc -ne 0 ]]; then
    log "mob-consensus install failed (rc=${rc}); continuing."
    return 0
  fi

  log "mob-consensus installed to ${local_bin}."
}

install_mob_tools

# Install the OpenAI Codex CLI.
#
# We install this in the user's home directory so it works without sudo and so
# each Codespace user can manage/upgrade it independently.
install_codex_cli() {
  local local_bin="${HOME}/.local/bin"
  local npm_cache="${HOME}/.cache/npm"
  local npm_work="${HOME}/.npm"

  if ! ensure_dir "${local_bin}" "for npm-installed tools"; then
    return 0
  fi
  export PATH="${local_bin}:${PATH}"

  if command -v codex >/dev/null 2>&1; then
    log "codex already installed."
    return 0
  fi

  if ! have_cmd npm; then
    log "npm not found; skipping Codex CLI install."
    return 0
  fi

  if ! ensure_dir "${npm_cache}" "for npm cache"; then
    return 0
  fi
  if ! ensure_dir "${npm_work}" "for npm work dir"; then
    return 0
  fi

  log "Installing Codex CLI (@openai/codex)..."
  npm_config_prefix="${HOME}/.local" \
    npm_config_cache="${npm_cache}" \
    npm install -g @openai/codex --no-fund --no-audit
  local rc=$?

  if [[ $rc -ne 0 ]]; then
    log "Codex CLI install failed (rc=${rc}); continuing."
    return 0
  fi

  log "Codex CLI installed to ${local_bin}."
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
      log "copilot.vim install looks broken; moving to ${backup_dir}..."
      mv "${plugin_dir}" "${backup_dir}" || return 0
    else
      log "${plugin_dir} exists but is not a git repo; skipping copilot.vim install."
      return 0
    fi
  fi

  if ! have_cmd git; then
    log "git not found; skipping copilot.vim install."
    return 0
  fi

  log "Installing copilot.vim..."
  if ! ensure_dir "$(dirname "${plugin_dir}")" "for Neovim config"; then
    return 0
  fi

  # Prefer a shallow git clone so updates are easy, but fall back to downloading
  # an archive if `git clone` fails for any reason.
  git clone --depth 1 "${plugin_repo}" "${plugin_dir}"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    rm -rf "${plugin_dir}" || true
    if have_cmd curl && have_cmd tar && have_cmd mktemp; then
      local tmp_dir=""
      tmp_dir="$(mktemp -d 2>/dev/null)"
      rc=$?
      if [[ $rc -ne 0 || -z "${tmp_dir}" ]]; then
        rc=1
        tmp_dir=""
      fi
      if [[ -z "${tmp_dir}" ]]; then
        rc=1
      else
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
      rm -rf "${tmp_dir}" || true
      fi
    fi
  fi

  if [[ $rc -ne 0 ]]; then
    log "copilot.vim install failed (rc=${rc}); continuing."
    return 0
  fi

  log "copilot.vim installed to ${plugin_dir}."
}

install_neovim_copilot_plugin

# If this sandbox ever grows a Go module, prefetch deps to speed up first builds.
if [[ -f go.mod ]] && command -v go >/dev/null 2>&1; then
  log "go.mod detected; downloading modules..."
  go mod download || true
fi

# scratchpad for POC testing if decomk concepts
mkdir /var/decomk
touch /var/decomk/hello.txt

log "Done."
exit 0
