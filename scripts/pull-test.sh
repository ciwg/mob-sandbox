#!/bin/bash

set -euo pipefail
set -x

repo=${REPO:-ciwg/mob-sandbox}
branch=${BRANCH:-main}
display_name=${DISPLAY_NAME:-pull-test-mob-sandbox-$(date -u +%Y%m%d-%H%M%S)}
machine=${MACHINE:-basicLinux32gb}
devcontainer_path=${DEVCONTAINER_PATH:-.devcontainer/devcontainer.json}
log_file=${LOG_FILE:-/tmp/cs-pull-test-mob-sandbox.log}
start_timeout_seconds=${CODESPACE_START_TIMEOUT_SECONDS:-3600}
poll_seconds=${CODESPACE_POLL_SECONDS:-15}
lookup_timeout_seconds=${CODESPACE_LOOKUP_TIMEOUT_SECONDS:-120}

# Find the newest matching codespace because display names can be reused.
find_codespace_name() {
    gh codespace list \
        --json name,displayName,repository,createdAt \
        --jq 'map(select(.repository == "'"$repo"'" and .displayName == "'"$display_name"'")) | sort_by(.createdAt) | reverse | .[0].name // ""'
}

# Wait until GitHub's list endpoint shows the newly-created codespace.
wait_for_codespace_name() {
    local deadline=$((SECONDS + lookup_timeout_seconds))
    local name=""

    while ((SECONDS < deadline)); do
        name=$(find_codespace_name)
        if [[ -n "$name" ]]; then
            printf '%s\n' "$name"
            return 0
        fi
        sleep "$poll_seconds"
    done

    return 1
}

# Poll the Codespaces state ourselves instead of relying on gh create --status.
wait_for_codespace_start() {
    local name=$1
    local deadline=$((SECONDS + start_timeout_seconds))
    local state=""

    while ((SECONDS < deadline)); do
        if state=$(gh codespace view -c "$name" --json state --jq .state 2>&1); then
            case "$state" in
                Available|Running)
                    printf 'codespace %s reached state %s\n' "$name" "$state" >&2
                    return 0
                    ;;
            esac
        fi

        printf 'waiting for %s: %s\n' "$name" "$state" >&2
        sleep "$poll_seconds"
    done

    printf 'timed out waiting for %s after %s seconds\n' "$name" "$start_timeout_seconds" >&2
    return 1
}

gh codespace create \
    --repo "$repo" \
    --branch "$branch" \
    --display-name "$display_name" \
    --default-permissions \
    --machine "$machine" \
    --devcontainer-path "$devcontainer_path"

name=$(wait_for_codespace_name)
wait_for_codespace_start "$name"

gh codespace logs -c "$name" > "$log_file"
echo "$log_file"
