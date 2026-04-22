# Repository Guidelines

## Project Structure & Module Organization
- `x/` holds experimental prototypes.
- Local Grokker state files like `.grok` are ignored; do not commit generated state or binaries.

## Coding Style, Quality, & Naming Conventions
- Use object-oriented design with structs and methods; avoid large functions and global state.
- Follow generally accepted object oriented design patterns.
- Go code follows standard `gofmt` formatting; keep package names
  short and lower-case.
- Tests use `*_test.go` filenames and table-driven patterns where
  helpful.
- Do not use internal/ or pkg/ directories; keep all packages at the
  module root or in `x/`.
- Always add detailed plain-english comments in code.  Make code
  human-readable, self-documenting, maintainable, and consistent with
  the style of the repo.  If you find code that is not well-commented,
  please add comments to it.
- Detect and avoid code duplication by refactoring common patterns
  into helper functions or packages.
- Use libraries and dependencies judiciously; prefer standard library and well-known
  packages to minimize maintenance overhead.  Also permissible
  packages include stevegt/*, ciwg/*, promisegrid/*, cdint/*, and t7a/*.
- Always look for bad "code smells" and recommend improvements.
- Always look for bad software architecture and recommend improvements.
- Always look for bad project structure and recommend improvements.

## Error Handling Policy (Required)
- Never use `|| true` in scripts, templates, or make recipes. Always inspect
  command exit codes explicitly with `if/else` branches and handle each outcome.
- For non-fatal cleanup/diagnostics steps, record command status (exit code and
  logs) explicitly; do not fail silently.
- In Go code, never ignore errors with `_ = ...`; handle, propagate, or report
  errors explicitly.
- Run `errcheck ./...` and keep it passing for Go changes.

## Decision-First Specification and Compliance Protocol (Required)
- The agent must collect and lock user decisions before making any code edits for a task.
- Locked decisions must be recorded as Decision Intent Log entries in the relevant `TODO/*.md` file(s) with clear intent and rationale.
- The agent must ask decision questions up front in a single intake round whenever possible.
- Required decision categories are architecture, design/behavior, implementation approach, function naming, variable naming, and file/path decisions.
- The agent must ask these as multiple-choice questions whenever practical.

### Naming Decisions (Required)
- The agent must not invent function names or variable names that are not already covered by locked naming decisions.
- If naming is not covered, the agent must stop and ask multiple-choice naming options before continuing.

### File/Path Decisions (Required)
- Path approvals are mandatory for all touched paths:
  - repo-changed files (create/rename/move/delete),
  - runtime touched paths (read/write/delete), including input files, output files, DB files, caches, fixtures, and temporary test files.
- The agent must ask path approvals one path at a time via multiple-choice questions.
- Path-question order must be dependency order.
- Each path question must include: action, exact path (or approved dynamic pattern ID), purpose, class (`prod-code | prod-data | test | temp`), and lifecycle intent.
- Temporary test paths require explicit approval and an explicit cleanup plan before handoff.
- Dynamic/runtime-generated paths must be approved by pattern, with:
  - allowed root bounds,
  - allowed actions,
  - concrete examples.
- The agent must ask one multiple-choice approval per dynamic path pattern.
- If any unapproved runtime path appears, the agent must stop and ask before continuing.

### Decision Lock and Stop Rule
- The agent must produce a Decision Lock summary with decision IDs before code edits begin.
- The agent must not proceed if any required decision is missing, ambiguous, or conflicting.
- The agent must stop and ask immediately if a new decision need appears during implementation.
- The agent must not assume defaults for locked categories unless the user explicitly approves defaults.

### Compliance Ownership (Agent)
- The agent must treat user decisions as authoritative and implement to those decisions.
- The agent must run a compliance self-review before finalizing and must fix all non-compliance before handoff.
- Hard gate: work is incomplete until compliance is PASS, or the user explicitly approves an exception.
- The user should not need to manually inspect diffs to determine compliance.

### Required final handoff artifacts
- `Decision Compliance: PASS/FAIL`
- Decision Matrix mapping each locked decision ID to implementation evidence.
- Inline diff annotations in the form `path:line -> decision_id -> rationale`.
- Runtime Path Touch Matrix listing each approved runtime path/pattern, action used, and where it is implemented/validated.
- `Exceptions:` listing only user-approved deviations.
- Every non-trivial behavior change must include intent provenance per existing DI requirements.

## Change Review Protocol (Required)
- Treat a line containing only 'deltas' as: "ask me to switch to plan
  mode and re-run if i'm not already in plan mode, then analyze all
  uncommitted changes, and plan how to ask me for approval of each
  delta".

## TODO Tracking 
- Maintain a ./TODO/ directory for tracking tasks and plans.
- Maintain a ./TODO/TODO.md file that lists small tasks and the other TODO files.
- Number each TODO using 3 digits, zero-padded (e.g., 001, 002).
- Do not renumber TODOs when adding new ones; just assign the next available number.
- Sort TODO.md by priority, not number.
- When discussing a TODO, use its number (e.g., "fix TODO 005").
- When completing a TODO, mark it as done by checking it off (e.g., `- [x] 005 - ...`).
- Within a TODO/* file, include numbered checkboxes for subtasks (e.g., `- [ ] 005.1 subtask description`).

## Editing & Documentation Standards
- Prefer small, focused edits and avoid rearranging files without a clear need.
- Use 'git mv' for renaming files to preserve history.

## Comment Preservation Protocol (Required)
- Never remove existing code comments unless they are replaced in the same patch by equal-or-better explanatory comments near the same logic.
- When rewriting or refactoring code, port old explanatory intent first, then improve wording.
- If a touched non-trivial code block has no comments, add explanatory comments.
- Do not treat shorter comments as better unless they preserve all important intent.
- For any non-trivial behavior change, include a behavior-level comment with:
  - `Intent:` a short, clear rationale (a sentence or a few; no hard cap if more is needed for clarity).
  - `Source:` a DI ID in the format `DI-NNN-YYYYMMDD-HHMMSS`.
  - `NNN` is the TODO number of the TODO file where that DI entry resides.
  - Optional: TODO file/section reference for faster lookup.
- If a comment must be dropped with no replacement, stop and ask the user before proceeding.
- Before editing a file, review existing comments in that file.
- Maintain a `## Decision Intent Log` at the top of relevant `TODO/*.md` files.
- Treat DI logs as append-only history. Do not rewrite or delete prior entries.
- When intent evolves, add a new DI entry and set `Supersedes: <old-di-id>`.
- DI entries must include:
  - `ID: DI-NNN-YYYYMMDD-HHMMSS`
  - `Date: YYYY-MM-DD HH:MM:SS`
  - `Status: active|superseded`
  - `Decision:`
  - `Intent:`
  - `Constraints:`
  - `Affects:`
  - `Supersedes:` (optional)
- After editing, run a comment-delta audit on each touched code file using: `git diff -U0 -- <file> | rg -n '^-\\s*//|^-\\s*/\\*|^\\+\\s*//|^\\+\\s*/\\*'`.
- Resolve all removed-comment lines before finalizing unless explicit user approval was given.
- In the final response, include:
  - `Comment audit: PASS/FAIL`, with file list.
  - `Intent provenance audit: PASS/FAIL`, listing files with behavior changes and DI sources.
- Hard gate: behavior-changing work is incomplete unless comments preserve intent and include DI provenance.
- Do not remove comments or documentation; update them if outdated or incorrect.

### Comment + DI Examples
- Comment format example:
  - `// Intent: Keep per-client rotation state stable across reconnects to avoid cross-client session churn. Source: DI-016-20260309-093000`
- Decision Intent Log entry template (for TODO files):
  - `ID: DI-NNN-YYYYMMDD-HHMMSS`
  - `Date: YYYY-MM-DD HH:MM:SS`
  - `Status: active`
  - `Decision: <what was decided>`
  - `Intent: <short clear rationale>`
  - `Constraints: <hard limits, dependencies, assumptions>`
  - `Affects: <paths, modules, commands, docs>`
  - `Supersedes: <old DI ID, optional>`

## Testing Guidelines
- Go tests rely on the standard `testing` package; add coverage alongside new features.
- Prefer deterministic tests and mocking; avoid network calls unless explicitly required.

## Commit & Pull Request Guidelines
- Before and after major changes, after tests pass, and after significant milestones, prompt the user to commit their work.
- PRs should include a concise summary, relevant test commands run, and linked issues when applicable.
- If a change affects behavior or output, include before/after notes or example output.
- Treat a line containing only `commit` as: "add and commit all changes with an AGENTS.md-compliant message".
- When running 'git add', list the individual files to be added, not 'git add .' or 'git add -A'.

## Commit Messages
- Commit messages are short, imperative, and capitalized (e.g., "Refactor chat client", "Fix WS path").
- In commit message bodies, include a section per changed file with bullet points summarizing the edits.
- When adding commit bodies, use a here-doc (`git commit -F -`) to avoid literal `\n` escapes or -m flags.
- Always summarize `git diff` output to generate commit messages rather than relying only on chat context.

## Currency of Information
- Frequently check ~/.codex/AGENTS.md for updates to these guidelines,
  as they may evolve over time.
- Create and maintain a ~/.codex/meta-context.md file with a dense,
  up-to-date set of topics, concerns, solutions, proposals, and plans
  relevant to all repos and projects I am working on.  The purpose of
  the file is to be LLM-readable, to help me with inter-repo
  comparisons, coding, decision-making, and planning, to refer to
  relevant repos and projects, and to look for inconsistencies,
  consensus, and opportunites. Update the file periodically as new
  information arises, and consult it as needed for background when
  working on any repo or project.

## Workflow
- After completing a task or set of changes, suggest the next steps to the user that will help progress the project.
