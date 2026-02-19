#!/usr/bin/env bash
set -euo pipefail

# Keep setup minimal and fast.
#
# This hook runs after the Codespace/devcontainer is created. Add lightweight,
# deterministic setup here (e.g. language dependency downloads) so everyone
# starts from the same baseline environment.

echo "[postCreate] Repo: $(basename "$(pwd)")"

# If this sandbox ever grows a Go module, prefetch deps to speed up first builds.
if [[ -f go.mod ]] && command -v go >/dev/null 2>&1; then
  echo "[postCreate] go.mod detected; downloading modules..."
  go mod download
fi

