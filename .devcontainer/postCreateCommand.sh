#!/usr/bin/env bash
set -euo pipefail

# Keep setup minimal and fast.
#
# This hook runs after the Codespace/devcontainer is created. Add lightweight,
# deterministic setup here (e.g. language dependency downloads) so everyone
# starts from the same baseline environment.

echo "[postCreate] Repo: $(basename "$(pwd)")"

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

# If this sandbox ever grows a Go module, prefetch deps to speed up first builds.
if [[ -f go.mod ]] && command -v go >/dev/null 2>&1; then
  echo "[postCreate] go.mod detected; downloading modules..."
  go mod download
fi
