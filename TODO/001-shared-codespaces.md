# 001 - Trial shared Codespaces access

Goal: determine whether (and how well) multiple people with different GitHub IDs can
collaborate inside the same GitHub Codespace (including SSH access), and document
the security/UX tradeoffs.

Working assumptions (verify during the trial):
- A Codespace is effectively a single dev VM/container; if multiple people can connect,
  they share the same filesystem and process namespace (not an isolation boundary).
- Access is mediated by GitHub's Codespaces "sharing" feature/policy (often configured
  at the org/enterprise level). The `gh` CLI may or may not expose sharing commands.
- Secrets are decrypted by GitHub services and injected into the runtime environment.
  Anyone with shell access to the same environment may be able to read injected values
  (treat this as "yes" unless testing proves otherwise).

Questions to answer:
- How do we share a Codespace (UI, API, `gh`)?
- Can multiple people be connected concurrently (VS Code + SSH + web)?
- What does "multi-user" mean inside the container (same Linux user? sudo?)?
- What secrets are available to shared collaborators (repo/org/user secrets)? Are any
  secrets suppressed when a Codespace is shared?
- What logging/audit trail exists (who connected, when, from where)?

Trial plan:
- [ ] 001.1 Confirm whether Codespaces sharing is enabled (org/enterprise policy) and
  note any constraints (internal-only, specific org members, etc.).
- [ ] 001.2 Create a fresh Codespace from this repo and record baseline info:
  `uname -a`, `whoami`, `id`, `df -h`, `env | rg -i 'CODESPACE|GITHUB'`.
- [ ] 001.3 Find the share mechanism in GitHub UI (and/or `gh`) and document the exact
  steps to grant access to a second GitHub account.
- [ ] 001.4 As the second GitHub account, connect via SSH (`gh codespace ssh -c ...`)
  and via VS Code, and confirm both work.
- [ ] 001.5 Verify whether shared access is "same Linux user" by checking `whoami`,
  `id`, home directory, and ability to read/write all repo files.
- [ ] 001.6 Verify concurrency: two users editing the same file, running `tmux`, and
  running dev tools simultaneously; note any surprising contention.
- [ ] 001.7 Set `OPENAI_API_KEY` as a **per-user** Codespaces secret for the owner and
  check whether the shared collaborator can read `printenv OPENAI_API_KEY`.
- [ ] 001.8 If repo/org secrets are used, repeat the test and document differences.
- [ ] 001.9 Check what a shared collaborator can do with ports: view forwarded ports,
  create new forwards, and access private services bound to `localhost`.
- [ ] 001.10 Identify and document logs/audit in GitHub UI (recent connections, sharing
  events, and any audit log entries).
- [ ] 001.11 Identify anything visible inside the container (if applicable): e.g. any
  `journalctl` output, `/var/log/*`, or Codespaces-specific logs.
- [ ] 001.12 Decide a recommended workflow for mobbing:
  shared Codespace vs VS Code Live Share vs separate Codespaces, with a clear warning
  about secrets and trust boundaries.
- [ ] 001.13 Confirm how dotfiles/editor config behave for shared collaborators, and
  document a safe per-user customization approach.
- [ ] 001.14 Update `README.md` with the findings and the recommended default.
