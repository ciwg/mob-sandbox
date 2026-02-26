#!/usr/bin/env bash
#
# Collect baseline diagnostics for a Codespace / devcontainer session.
#
# This is intended to be run by both the Codespace owner and any shared
# collaborator so we can compare:
# - identity (Linux user, uid/gid, groups)
# - environment (without leaking secrets)
# - filesystem/quota signals
# - versions of key tools (gh, git)
#
# Usage:
#   scripts/codespace-baseline.sh            # human-readable
#   scripts/codespace-baseline.sh --json     # machine-readable (best-effort)
#
# Safety:
# - This script NEVER prints OPENAI_API_KEY (or other secrets) values.
# - It only reports whether certain variables are set.
set -euo pipefail

format="text"
if [[ "${1:-}" == "--json" ]]; then
  format="json"
fi

now_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"
host="$(hostname 2>/dev/null || true)"
user="$(whoami 2>/dev/null || true)"

print_kv() {
  local k="$1"
  local v="${2:-}"
  printf '%s=%s\n' "$k" "$v"
}

is_set() {
  local name="$1"
  [[ -n "${!name:-}" ]]
}

safe_env_report() {
  # Print only non-sensitive env vars useful for Codespaces diagnostics.
  # Keep this conservative: add allowlisted keys as needed.
  env | awk -F= '
    /^[A-Za-z_][A-Za-z0-9_]*=/ {
      key=$1
      if (key ~ /^(CODESPACE|CODESPACES|GITHUB|GH_|REMOTE_CONTAINERS|TERM|SHELL|USER|HOME|PATH|LANG|LC_|SSH_|VSCODE)/) {
        print $0
      }
    }'
}

if [[ "$format" == "json" ]]; then
  # Best-effort JSON without jq. Values are lightly escaped.
  esc() { awk 'BEGIN{ORS="";} {gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); print;}'; }

  printf '{'
  printf '"timestampUtc":"%s",' "$(printf '%s' "$now_utc" | esc)"
  printf '"hostname":"%s",' "$(printf '%s' "$host" | esc)"
  printf '"whoami":"%s",' "$(printf '%s' "$user" | esc)"
  printf '"uidGid":"%s",' "$(id 2>/dev/null | esc)"

  printf '"openaiApiKeySet":%s,' "$(is_set OPENAI_API_KEY && echo "true" || echo "false")"
  printf '"decomkHomeSet":%s,' "$(is_set DECOMK_HOME && echo "true" || echo "false")"
  printf '"decomkConfRepoSet":%s,' "$(is_set DECOMK_CONF_REPO && echo "true" || echo "false")"

  printf '"osRelease":'
  if [[ -r /etc/os-release ]]; then
    printf '"%s",' "$(tr '\n' ' ' </etc/os-release 2>/dev/null | esc)"
  else
    printf 'null,'
  fi

  printf '"dfHuman":"%s",' "$(df -h 2>/dev/null | tr '\n' ' ' | esc)"
  printf '"dfInodes":"%s",' "$(df -ih 2>/dev/null | tr '\n' ' ' | esc)"

  printf '"ghVersion":'
  if command -v gh >/dev/null 2>&1; then
    printf '"%s",' "$(gh --version 2>/dev/null | tr '\n' ' ' | esc)"
  else
    printf 'null,'
  fi

  printf '"gitVersion":'
  if command -v git >/dev/null 2>&1; then
    printf '"%s",' "$(git --version 2>/dev/null | esc)"
  else
    printf 'null,'
  fi

  printf '"safeEnv":"%s"' "$(safe_env_report 2>/dev/null | tr '\n' ' ' | esc)"
  printf '}\n'
  exit 0
fi

echo "# codespace-baseline"
print_kv "timestampUtc" "$now_utc"
print_kv "hostname" "$host"
print_kv "whoami" "$user"
echo

echo "## Identity"
id 2>/dev/null || true
echo

echo "## OS"
uname -a 2>/dev/null || true
if [[ -r /etc/os-release ]]; then
  echo
  cat /etc/os-release
fi
echo

echo "## Disk"
df -h 2>/dev/null || true
echo
df -ih 2>/dev/null || true
echo

echo "## Key vars (presence only)"
print_kv "OPENAI_API_KEY_set" "$(is_set OPENAI_API_KEY && echo yes || echo no)"
print_kv "DECOMK_HOME_set" "$(is_set DECOMK_HOME && echo yes || echo no)"
print_kv "DECOMK_CONF_REPO_set" "$(is_set DECOMK_CONF_REPO && echo yes || echo no)"
echo

echo "## Tool versions"
command -v gh >/dev/null 2>&1 && gh --version || echo "gh: not found"
command -v git >/dev/null 2>&1 && git --version || echo "git: not found"
echo

echo "## Env (allowlist)"
safe_env_report 2>/dev/null || true

