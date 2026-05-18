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
gui_health_ready_timeout_seconds=${GUI_HEALTH_READY_TIMEOUT_SECONDS:-180}
gui_health_stable_seconds=${GUI_HEALTH_STABLE_SECONDS:-15}
name=""

validate_seconds() {
    local value_name=$1
    local value=$2

    case "$value" in
        ''|*[!0-9]*)
            printf '%s must be a non-negative integer, got %q\n' "$value_name" "$value" >&2
            return 1
            ;;
    esac
}

validate_seconds CODESPACE_START_TIMEOUT_SECONDS "$start_timeout_seconds"
validate_seconds CODESPACE_POLL_SECONDS "$poll_seconds"
validate_seconds CODESPACE_LOOKUP_TIMEOUT_SECONDS "$lookup_timeout_seconds"
validate_seconds GUI_HEALTH_READY_TIMEOUT_SECONDS "$gui_health_ready_timeout_seconds"
validate_seconds GUI_HEALTH_STABLE_SECONDS "$gui_health_stable_seconds"

: > "$log_file"

# Intent: Keep the pull-test log as a complete artifact that includes both
# Codespaces build logs and GUI health output. Source: DI-002-20260518-050312
append_log_line() {
    printf '%s\n' "$*" | tee -a "$log_file" >&2
}

append_log_section() {
    printf '\n===== %s %s =====\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$log_file" >&2
}

fetch_codespace_logs() {
    if [[ -z "$name" ]]; then
        return 0
    fi

    append_log_section "gh codespace logs for $name"
    if gh codespace logs -c "$name" 2>&1 | tee -a "$log_file"; then
        append_log_line "wrote codespace logs to $log_file"
    else
        local rc=$?
        append_log_line "WARN: failed to write codespace logs to $log_file (rc=$rc)"
    fi
}

finish() {
    local rc=$?
    set +e
    fetch_codespace_logs
    exit "$rc"
}
trap finish EXIT

# Find the newest matching codespace because display names can be reused.
find_codespace_name() {
    gh codespace list \
        --json name,displayName,repository,createdAt \
        --jq 'map(select(.repository == "'"$repo"'" and .displayName == "'"$display_name"'")) | sort_by(.createdAt) | reverse | .[0].name // ""'
}

# Wait until GitHub's list endpoint shows the newly-created codespace.
wait_for_codespace_name() {
    local deadline=$((SECONDS + lookup_timeout_seconds))
    local found_name=""

    while ((SECONDS < deadline)); do
        found_name=$(find_codespace_name)
        if [[ -n "$found_name" ]]; then
            printf '%s\n' "$found_name"
            return 0
        fi
        sleep "$poll_seconds"
    done

    printf 'timed out waiting for codespace %s to appear after %s seconds\n' "$display_name" "$lookup_timeout_seconds" >&2
    return 1
}

# Poll the Codespaces state ourselves instead of relying on gh create --status.
wait_for_codespace_start() {
    local codespace_name=$1
    local deadline=$((SECONDS + start_timeout_seconds))
    local state=""

    while ((SECONDS < deadline)); do
        if state=$(gh codespace view -c "$codespace_name" --json state --jq .state 2>&1); then
            case "$state" in
                Available|Running)
                    printf 'codespace %s reached state %s\n' "$codespace_name" "$state" >&2
                    return 0
                    ;;
            esac
        fi

        printf 'waiting for %s: %s\n' "$codespace_name" "$state" >&2
        sleep "$poll_seconds"
    done

    printf 'timed out waiting for %s after %s seconds\n' "$codespace_name" "$start_timeout_seconds" >&2
    return 1
}

# Intent: Treat GUI health as part of the pull-test contract, not just a
# successful Codespaces build log. Source: DI-002-20260517-210209
run_gui_health_check() {
    local codespace_name=$1

    gh codespace ssh -c "$codespace_name" -- "GUI_HEALTH_READY_TIMEOUT_SECONDS=$gui_health_ready_timeout_seconds GUI_HEALTH_STABLE_SECONDS=$gui_health_stable_seconds bash -s" <<'REMOTE_GUI_HEALTH'
set -euo pipefail

fail() {
    printf 'GUI health check failed: %s\n' "$*" >&2
    exit 1
}

require_command() {
    local command_name=$1
    if ! command -v "$command_name" >/dev/null 2>&1; then
        fail "required command is missing: $command_name"
    fi
}

service_status_is_healthy() {
    local service=$1
    local status=""

    if ! status=$(sudo sv status "/etc/service/$service" 2>&1); then
        printf 'service %s status command failed: %s\n' "$service" "$status" >&2
        return 1
    fi

    printf 'service %s status: %s\n' "$service" "$status"
    case "$status" in
        run:*)
            ;;
        *)
            printf 'service %s is not running\n' "$service" >&2
            return 1
            ;;
    esac

    if [[ "$status" == *'down:'* ]]; then
        printf 'service %s reports a down component\n' "$service" >&2
        return 1
    fi
}

process_list_has() {
    local process_list=$1
    local description=$2
    local pattern=$3

    case "$process_list" in
        *"$pattern"*)
            printf 'found %s with pattern %q\n' "$description" "$pattern"
            ;;
        *)
            printf 'missing %s with pattern %q\n' "$description" "$pattern" >&2
            return 1
            ;;
    esac
}

probe_gui_daemons() {
    local remote_user=${DECOMK_REMOTE_USER:-vscode}
    local pid1=""
    local process_list=""
    local service=""

    pid1=$(ps -p 1 -o comm= | tr -d '[:space:]')
    if [[ "$pid1" != "runsvdir" ]]; then
        printf 'PID 1 is %q, expected runsvdir\n' "$pid1" >&2
        return 1
    fi

    for service in xvfb openbox x11vnc novnc; do
        service_status_is_healthy "$service"
    done

    if ! process_list=$(ps -u "$remote_user" -o args= 2>&1); then
        printf 'could not list processes for %s: %s\n' "$remote_user" "$process_list" >&2
        return 1
    fi

    process_list_has "$process_list" Xvfb 'Xvfb :0'
    process_list_has "$process_list" Openbox 'openbox'
    process_list_has "$process_list" x11vnc 'x11vnc -display :0'
    process_list_has "$process_list" websockify 'websockify'
    process_list_has "$process_list" websockify-port '6080 127.0.0.1:5900'
}

wait_for_gui_daemons() {
    local deadline=$((SECONDS + GUI_HEALTH_READY_TIMEOUT_SECONDS))
    local output=""
    local rc=0

    while ((SECONDS < deadline)); do
        set +e
        output=$(probe_gui_daemons 2>&1)
        rc=$?
        set -e
        if ((rc == 0)); then
            printf '%s\n' "$output"
            return 0
        fi
        printf 'waiting for GUI daemons: %s\n' "$output" >&2
        sleep 2
    done

    printf '%s\n' "$output" >&2
    fail "GUI daemons did not become healthy within ${GUI_HEALTH_READY_TIMEOUT_SECONDS}s"
}

require_novnc_web_page() {
    local html=""

    if ! html=$(curl -fsS --max-time 10 http://127.0.0.1:6080/ 2>&1); then
        fail "noVNC web page is not reachable: $html"
    fi

    case "$html" in
        *noVNC*|*vnc.html*)
            printf 'noVNC web page is reachable on port 6080\n'
            ;;
        *)
            fail 'port 6080 responded, but it did not look like the noVNC page'
            ;;
    esac
}

require_novnc_websocket_to_vnc() {
    python3 - <<'REMOTE_WS_PY'
import base64
import os
import socket
import struct
import sys


def recv_exact(sock, size):
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise RuntimeError("connection closed before receiving enough data")
        data += chunk
    return data


def read_ws_payload(sock):
    header = recv_exact(sock, 2)
    length = header[1] & 0x7F
    if length == 126:
        length = struct.unpack("!H", recv_exact(sock, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", recv_exact(sock, 8))[0]

    mask = b""
    if header[1] & 0x80:
        mask = recv_exact(sock, 4)

    payload = recv_exact(sock, length)
    if mask:
        payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    return payload


def try_path(path):
    key = base64.b64encode(os.urandom(16)).decode("ascii")
    request = (
        f"GET {path} HTTP/1.1\r\n"
        "Host: 127.0.0.1:6080\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        "\r\n"
    )

    with socket.create_connection(("127.0.0.1", 6080), timeout=10) as sock:
        sock.settimeout(10)
        sock.sendall(request.encode("ascii"))
        response = sock.recv(4096)
        status_line = response.split(b"\r\n", 1)[0]
        if b" 101 " not in status_line:
            raise RuntimeError(f"{path} did not upgrade to websocket: {status_line!r}")
        payload = read_ws_payload(sock)
        if not payload.startswith(b"RFB "):
            raise RuntimeError(f"{path} upgraded, but first payload was not VNC RFB: {payload[:32]!r}")


errors = []
for path in ("/websockify", "/"):
    try:
        try_path(path)
    except Exception as exc:
        errors.append(f"{path}: {exc}")
    else:
        print(f"noVNC websocket reaches VNC desktop through {path}")
        sys.exit(0)

for error in errors:
    print(error, file=sys.stderr)
sys.exit(1)
REMOTE_WS_PY
}

require_command curl
require_command python3
require_command ps
require_command sudo
require_command sv

wait_for_gui_daemons
sleep "$GUI_HEALTH_STABLE_SECONDS"
probe_gui_daemons
require_novnc_web_page
require_novnc_websocket_to_vnc
REMOTE_GUI_HEALTH
}

run_and_log_gui_health_check() {
    # Intent: Preserve GUI health diagnostics in the same log file even when the
    # health check fails and the shell exits early. Source: DI-002-20260518-050312
    local codespace_name=$1
    local rc=0

    append_log_section "GUI health check for $codespace_name"
    if run_gui_health_check "$codespace_name" 2>&1 | tee -a "$log_file"; then
        append_log_line "GUI health check succeeded for $codespace_name"
        return 0
    fi

    rc=$?
    append_log_line "GUI health check failed for $codespace_name (rc=$rc)"
    return "$rc"
}

create_codespace() {
    local rc=0

    append_log_section "gh codespace create for $display_name"
    set +e
    gh codespace create \
        --repo "$repo" \
        --branch "$branch" \
        --display-name "$display_name" \
        --default-permissions \
        --machine "$machine" \
        --devcontainer-path "$devcontainer_path" 2>&1 | tee -a "$log_file"
    rc=${PIPESTATUS[0]}
    set -e

    if ((rc == 0)); then
        return 0
    fi

    # Intent: `gh codespace create` can create the Codespace and then fail while
    # fetching it by generated name; keep going so our display-name lookup can
    # determine whether creation really happened. Source: DI-002-20260518-052215
    append_log_line "WARN: gh codespace create exited with rc=$rc; continuing with list/poll discovery"
    return 0
}

create_codespace
name=$(wait_for_codespace_name)
wait_for_codespace_start "$name"
fetch_codespace_logs
run_and_log_gui_health_check "$name"
fetch_codespace_logs
echo "$log_file"
