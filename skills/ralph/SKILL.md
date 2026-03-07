---
name: ralph
description: Set up and run Ralph loops — autonomous AI coding agent iterations driven by GitHub issues. Use when user says "ralph", "set up ralph", "ralph loop", "autonomous loop", "AFK build", "implement this PRD", "build from spec", "loop through tasks", "run it unattended", or wants Claude Code to autonomously implement a spec one task at a time.
argument-hint: "[setup|once|afk <iterations>|team-research|team-review]"
---

# Ralph Loop

Autonomous iteration loop that implements GitHub issues one sub-task at a time, committing after each. Each iteration gets a fresh context window so errors don't compound — git history is the only memory between runs.

**Why this works:** A fresh context per iteration prevents hallucination buildup and keeps each task focused. One sub-task per iteration means easy rollback (just `git revert`) and avoids context window exhaustion on large projects. Git commit messages as memory means the history is auditable, diff-able, and survives context resets.

**Workflow chain:** `/write-a-prd` → `/prd-to-plan` → `/plan-to-issues` → **`/ralph`** (you are here) → `/review-to-issues` → `/ralph` (cycle)

**Optional team modes:** `/ralph team-research` (before implementation) | `/ralph team-review` (instead of @claude review)

GitHub issues are the single source of truth for what to build. Ralph reads them, not the PRD directly.

## Authentication

All Ralph scripts run `unset ANTHROPIC_API_KEY` at the top to force Claude Code OAuth authentication. This prevents accidental API billing when your shell profile sets an API key.

If you are using an API key instead of OAuth, remove the `unset ANTHROPIC_API_KEY` lines from the generated scripts.

## Instructions

### If `$ARGUMENTS` is "setup" or empty

Scaffold Ralph infrastructure in the current project:

1. **Check prerequisites**
   - Verify git is initialized (`git rev-parse --git-dir`). If not, ask the user before running `git init`
   - Check if `plans/` already exists — if so, ask whether to reuse or overwrite existing files
   - Check for GitHub issues: `gh issue list --state open`. If none exist, suggest running `/plan-to-issues` first
2. **Get the plan**
   - Check if `plans/plan.md` already exists (architectural decisions reference)
   - If not, check if `plans/prd.md` exists and suggest running `/prd-to-plan` then `/plan-to-issues`
   - If no PRD either, invoke `/write-a-prd` to start the chain
3. **Create `plans/prompt.md`** from [references/prompt-template.md](references/prompt-template.md)
   - Replace `{{FEEDBACK_COMMANDS}}` with the project's actual feedback commands
   - **Detect the tech stack** and pick appropriate commands (list is non-exhaustive — check for whatever the project uses):
     - Bun/TS: `bun test`, `tsc --noEmit`, `bunx biome check src/`
     - Go: `go test ./...`, `go vet ./...`
     - Node/TS: `npm run test`, `npm run typecheck`, `npm run lint`
     - Python: `pytest`, `mypy .`, `ruff check .`
     - Ruby: `bundle exec rspec`, `bundle exec rubocop`
     - Rust: `cargo test`, `cargo clippy`
     - Generic: check for pre-commit hooks, Makefile targets, or CI config
   - If unsure, ask the user what commands validate their code
4. **Create `plans/once-claude.sh`** from [references/once-claude-template.sh](references/once-claude-template.sh)
5. **Create `plans/afk-claude.sh`** from [references/afk-claude-template.sh](references/afk-claude-template.sh)
6. **Set up pre-commit hooks** if not already configured (husky, pre-commit, or similar)
7. `chmod +x plans/*.sh`
8. **Worktree setup** (for AFK isolation):
   - Create `plans/ralph-sequential.sh` from [references/ralph-sequential-template.sh](references/ralph-sequential-template.sh)
   - Create `plans/ralph-parallel.sh` from [references/ralph-parallel-template.sh](references/ralph-parallel-template.sh)
   - Explain `claude -p --worktree <name>` for file isolation without containers
   - Ensure `.claude/worktrees/` is in `.gitignore`
   - **Platform note:** Git worktrees and bash scripts require Unix/macOS. Windows users should use WSL or adapt scripts for PowerShell.
9. **Show summary** of what was created and how to run each mode

### If `$ARGUMENTS` is "once"

Run a single HITL (Human In The Loop) iteration inside this interactive session:

1. **Verify** `plans/prompt.md` exists. If not, suggest running `/ralph setup` first
2. **Read** `plans/plan.md` for architectural decisions
3. **Read git history** — gather last 10 RALPH commits: `git log --grep="RALPH" -n 10 --format="%H%n%ad%n%B---" --date=short`
4. **Fetch open issues** — `gh issue list --state open --json number,title,body,labels`
5. **Issue selection** — Pick the lowest-numbered issue that is not blocked (check its "Blocked by" section — all referenced issues must be closed). If all issues are closed, tell the user and stop
6. **Sub-task breakdown** — Read the selected issue's acceptance criteria. Break it into the smallest possible sub-tasks. Pick one sub-task
7. **Exploration** — Read relevant files in the repo to fill context for the selected sub-task
8. **Execution** — Implement the sub-task
9. **Feedback loops** — Run the commands specified in `plans/prompt.md` (tests, typecheck, lint). Fix any failures before proceeding
10. **Commit** — `git commit` with a structured message:
    - `RALPH:` prefix
    - GitHub issue reference (`#N`)
    - Sub-task completed
    - Key decisions made
    - Files changed
    - Remaining sub-tasks for this issue (or "Issue complete")
11. **Issue closure** — If ALL acceptance criteria for the issue are met, close it: `gh issue close <number> --comment "All acceptance criteria met."`

### If `$ARGUMENTS` starts with "afk"

AFK mode runs autonomously outside Claude Code via a bash script. Show the user the command:

```bash
bash plans/ralph-sequential.sh <batch_size>       # sequential worktree loop
bash plans/ralph-parallel.sh <issue_numbers>      # parallel (one worktree per issue)
bash plans/afk-claude.sh <iterations>             # bare-metal (no worktree)
```

**Choosing parallel vs sequential:** Check whether issues touch overlapping
files. If they do, use sequential. Parallel is only safe when issues modify
completely independent file sets. When in doubt, use sequential — the time
saved by parallelism is lost to conflict resolution if files overlap.

Check that the scripts exist first. If not, suggest `/ralph setup`.

Explain: each iteration gets a fresh context, reads the plan + last 10 RALPH commits, fetches open issues, picks the next unblocked one, implements one sub-task, runs feedback loops, commits, and closes the issue if complete. The loop stops on `<promise>COMPLETE</promise>` (all issues closed) or `<promise>ABORT</promise>` (blocked).

After Ralph completes and Claude reviews the PR, run `/review-to-issues` to cycle.

### If `$ARGUMENTS` is "team-research"

In-session Agent Teams mode for pre-implementation research. Do not launch from a bash script.

1. **Verify** `plans/prompt.md` exists. If not, suggest `/ralph setup`
2. **Fetch open issues:** `gh issue list --state open --json number,title,body,labels`
3. **Present issues** to the user — ask which to research (default: all unblocked). User confirms
4. **Create team** via TeamCreate: name `ralph-research-{timestamp}`
5. **Create tasks:** one per selected issue — "Research issue #N: {title}" with full issue body as task description
6. **Spawn 2-3 `issue-researcher` teammates.** Max 3 for rate limits
7. Teammates self-claim tasks, investigate, and send findings via SendMessage
8. **Lead collects findings** and synthesises into `plans/research/pre-implementation-{date}.md`:
   - Per-issue findings
   - Cross-issue file overlap analysis
   - Recommended execution order
   - Parallel vs sequential recommendation
9. **Shutdown teammates**
10. Suggest: "Research complete. Review the brief, then run `/ralph once` or `/ralph afk`."

### If `$ARGUMENTS` is "team-review"

In-session Agent Teams mode for multi-lens PR review. Do not launch from a bash script.

1. **Detect PR** (same 3-path logic as `/review-to-issues`):
   - If `$ARGUMENTS` contains a number after "team-review", use it as PR number
   - Otherwise detect from current branch: `git branch --show-current` then `gh pr list --head <branch>`
   - If nothing found, ask the user for the PR number
2. **Fetch PR info:** `gh pr diff <number>` and `gh pr view <number> --json title,body`
3. **Show PR summary** to user. Confirm proceeding
4. **Create team** via TeamCreate: name `ralph-review-{pr-number}`
5. **Create 3 review tasks:** correctness, security, architecture. Each includes PR number + lens instructions
6. **Spawn 3 `pr-reviewer` teammates** named `correctness-reviewer`, `security-reviewer`, `architecture-reviewer`
7. Reviewers investigate and send structured findings via SendMessage
8. **Lead consolidates:** merge, deduplicate, assign final severity. Format with severity headers matching `/review-to-issues` format:
   ```
   ### Critical
   ### Medium
   ### Low / Nits
   ```
9. **Present consolidated review** to user
10. **Shutdown teammates**
11. Suggest: "Run `/review-to-issues` to convert these findings into GitHub issues."

## Known Gotchas

These were discovered through real debugging. The templates already incorporate these fixes, but know them for troubleshooting:

1. **`--allowedTools` is variadic** — it consumes ALL subsequent positional args, including the prompt. Never pass prompt as a positional arg when using `--allowedTools`. Fix: pipe prompt via heredoc to stdin.
2. **`--output-format stream-json` requires `--verbose`** when used with `-p` (print mode).
3. **`unset ANTHROPIC_API_KEY`** is essential — many users source `~/.secrets` or similar in their shell profile, which sets an API key. Without unsetting, Claude Code uses the API key instead of OAuth and bills separately.
4. **Max plan rate limits** — 2-3 concurrent agents max. More will hit rate limits and fail.
5. **Worktree branch naming** — `claude -p --worktree <name>` creates branches named `worktree-<name>`. Choose descriptive names.
6. **`.claude/worktrees/` must be gitignored** — worktrees are ephemeral local state, not repo content.
7. **Never launch Ralph from inside Claude Code** — `claude -p` cannot run nested
   inside another Claude Code session (the `CLAUDECODE` env var blocks it). Always
   tell the user to run the script from a separate terminal. Do not use Bash tool
   or `run_in_background` to launch Ralph scripts.
8. **Parallel merge conflicts** — only parallelise issues that touch independent
   files. Run `gh issue view <N> --json body` for each issue and check the
   "Affected Files" sections for overlap. If ANY two issues share a file, use
   sequential mode. Small codebases with few core files are especially hostile
   to parallelism.
9. **Agent Teams require session restart after adding agents** — definitions in
   `.claude/agents/` are cached at session start. Restart after creating new files.
10. **Agent Teams are token-expensive** — each teammate is a full Claude session.
    A 3-teammate run costs ~3x a single session. Use judiciously.
11. **No session resumption for teammates** — if the lead crashes, teammates are
    lost. Findings sent before the crash are gone.
12. **TeammateIdle/TaskCompleted hooks enforce structure** — hooks validate that
    teammates produce structured output before going idle or marking tasks
    complete. If a teammate gets stuck in a feedback loop, check the hook
    scripts bundled with this plugin in `hooks/scripts/`.

## Completion Signals

- `<promise>COMPLETE</promise>` — All GitHub issues closed
- `<promise>ABORT</promise>` — Blocked, cannot continue

## Additional Resources

- Full methodology guide: [references/ralph-loop-guide.md](references/ralph-loop-guide.md)
- Prompt template: [references/prompt-template.md](references/prompt-template.md)
- AFK script template: [references/afk-claude-template.sh](references/afk-claude-template.sh)
- HITL script template: [references/once-claude-template.sh](references/once-claude-template.sh)
- Sequential worktree template: [references/ralph-sequential-template.sh](references/ralph-sequential-template.sh)
- Parallel worktree template: [references/ralph-parallel-template.sh](references/ralph-parallel-template.sh)
