# The Ralph Loop — User Guide & Instruction Manual

Based on Matt Pocock's workshop repos, blog posts, and the official Anthropic plugin. This guide covers Pocock's **bash loop approach** (which he prefers over the plugin).

## Table of Contents

- [What is Ralph?](#what-is-ralph)
- [Core Principle](#core-principle)
- [Two Execution Modes](#two-execution-modes)
- [Setup](#setup)
- [How It Works (Mental Model)](#how-it-works-mental-model)
- [Pocock's Three-Layer PRD Structure](#pococks-three-layer-prd-structure)
- [When to Use Ralph vs Normal Claude Code](#when-to-use-ralph-vs-normal-claude-code)
- [Tips & Gotchas](#tips--gotchas)
- [Sources](#sources)

---

## What is Ralph?

Ralph is a bash loop that runs Claude Code repeatedly against a PRD until all tasks are complete. Each iteration gets a **fresh context window**, picks the next task, implements it, runs feedback loops (tests/typecheck/lint), commits, and exits. The next iteration reads git history to understand what was done.

**Named after Ralph Wiggum** from The Simpsons — the philosophy is persistent iteration despite setbacks.

## Core Principle

> "Run a coding agent with a clean slate, again and again."

Each iteration:
1. Reads the PRD (the spec — doesn't change)
2. Reads the last 10 RALPH commits (the memory — grows each iteration)
3. Breaks the PRD into the smallest possible tasks
4. Picks ONE task
5. Explores the repo for context
6. Implements the task
7. Runs feedback loops (test, typecheck, lint)
8. Commits with a structured `RALPH:` message
9. Exits — next iteration begins fresh

## Two Execution Modes

### HITL (Human In The Loop)

Interactive mode. You run once, watch Claude work, review the result, then run again. Good for:
- Architecture and design decisions
- First iteration of a new PRD (watching it bootstrap)
- Debugging when Ralph gets stuck

### AFK (Away From Keyboard)

Autonomous loop. Runs N iterations unattended with worktree isolation. Good for:
- Bug fixes and refactors
- Straightforward feature implementation
- Overnight runs against a clear PRD

**Both modes use identical prompt and PRD.** The only difference is the shell script.

---

## Setup

### Files you need

```
your-project/
  plans/
    prd.md                    # The spec — what to build
    prompt.md                 # The instructions — how to work
    once-claude.sh            # HITL script (run once, interactive)
    afk-claude.sh             # AFK script (loop N times, autonomous)
    ralph-sequential.sh       # Sequential worktree loop, auto-PR on COMPLETE
    ralph-parallel.sh         # Parallel worktrees (one agent per issue)
  .husky/
    pre-commit                # Quality gates (lint, typecheck, test)
```

### 1. Write the PRD (`plans/prd.md`)

The PRD is the **steering wheel** — every decision flows from it. Pocock's PRDs are extremely detailed:

**Required sections:**
- **Problem Statement** — what are we solving and why
- **Solution** — what we're building (high level)
- **Tech Stack** — specific frameworks, libraries, versions
- **Database Schema** — actual SQL or schema definitions
- **API Endpoints** — full request/response contracts with examples
- **User Stories** — numbered list, comprehensive, cover all behaviour
- **Implementation Decisions** — architecture, patterns, key choices
- **Validation Rules** — input constraints, error formats
- **Testing Decisions** — what to test, philosophy, prior art
- **Out of Scope** — explicit exclusions
- **Environment Variables** — all config needed

**PRD quality rules:**
- No excessive abstraction — be concrete
- No missing validation criteria — every feature has success criteria
- No unexplained jargon — spell out internal terms
- No hidden dependencies — order tasks can be discovered by reading the PRD
- Use strikethrough (`~~`) for deferred user stories so Ralph skips them

**Tip:** Use `/write-a-prd` to interview yourself into a thorough PRD, then use `/grill-me` to stress-test it.

### 2. Write the prompt (`plans/prompt.md`)

The prompt template is at [prompt-template.md](prompt-template.md). Customise the `{{FEEDBACK_COMMANDS}}` placeholder for your project's tech stack.

### 3. HITL script (`plans/once-claude.sh`)

The HITL script template is at [once-claude-template.sh](once-claude-template.sh). Run with: `bash plans/once-claude.sh`

You stay in the session. Watch Claude work. Approve tool calls. Review the commit.

### 4. AFK script (`plans/afk-claude.sh`)

The AFK script template is at [afk-claude-template.sh](afk-claude-template.sh). Run with: `bash plans/afk-claude.sh 20`

**Worktree variant** (recommended for AFK):
Use `claude -p --worktree <name>` for file isolation without container overhead. See `ralph-sequential-template.sh` and `ralph-parallel-template.sh`.

### 5. Pre-commit hooks (`.husky/pre-commit`)

Quality gates that run before every commit:

```bash
npx lint-staged
npm run typecheck
npm run test
```

These catch bad code **before** it gets committed. If tests fail, the commit is rejected and Ralph will see the failure in the next iteration.

---

## How It Works (Mental Model)

```
Iteration 1:  PRD + 0 commits  ->  Bootstraps project, first feature  ->  RALPH: commit
Iteration 2:  PRD + 1 commit   ->  Reads history, picks next task     ->  RALPH: commit
Iteration 3:  PRD + 2 commits  ->  Reads history, picks next task     ->  RALPH: commit
...
Iteration N:  PRD + N-1 commits ->  All tasks done                    ->  <promise>COMPLETE</promise>
```

**Memory = git history.** No progress.txt file needed. The structured RALPH: commit messages tell each fresh iteration exactly what was done, what decisions were made, and what blockers exist.

**PRD = constant.** It never changes during a run. The PRD is the source of truth.

**Context = fresh each time.** Each iteration starts with a clean context window, loads the PRD, reads commit history, and picks up where the last one left off.

---

## Pocock's Three-Layer PRD Structure

From his workshop:

1. **Context layer** — System understanding (tech stack, schema, architecture, conventions)
2. **Task layer** — Atomic steps (user stories, API contracts, validation rules)
3. **Validation layer** — Success criteria (what tests to run, what "done" looks like)

All three layers go in a single `prd.md` file. The prompt template doesn't need to change between projects — only the PRD does.

---

## When to Use Ralph vs Normal Claude Code

| Scenario | Use Ralph | Use normal Claude Code |
|----------|-----------|----------------------|
| Greenfield feature with clear spec | Yes (AFK) | No |
| Refactoring with test coverage | Yes (AFK) | No |
| Bug fix with clear repro | Yes (HITL) | Also fine |
| Exploratory design / architecture | No | Yes |
| Unclear requirements | No | Yes (interview first) |
| One-shot task | No | Yes |
| Production debugging | No | Yes |

**Rule of thumb:** If you can write a detailed PRD with clear user stories and success criteria, Ralph will work. If you need human judgment or design decisions, use HITL mode or normal Claude Code.

---

## Tips & Gotchas

### From Pocock

- **"Don't outrun your headlights"** — one tiny task per iteration, not big features
- **Bash loop > plugin** — gives you more control and better results
- **Pre-commit hooks are essential** — they're the feedback loop that catches bad code
- **User stories with strikethrough** (`~~`) are skipped by Ralph
- **Worktrees for AFK** — file isolation without container overhead

### Common Failures

| Problem | Fix |
|---------|-----|
| Ralph implements multiple tasks per iteration | Add "ONLY WORK ON A SINGLE TASK" to prompt (Pocock does this) |
| Ralph skips tests | Add explicit feedback loop section with exact commands |
| Ralph loses context on large projects | PRD is too vague — add more concrete details (schema, API contracts) |
| Ralph commits broken code | Pre-commit hooks not configured — add lint/typecheck/test |
| Ralph loops forever | Use `--max-iterations` or `<promise>ABORT</promise>` escape hatch |
| Ralph re-implements completed work | Commit messages too vague — require structured RALPH: format |

### Completion Signals

- `<promise>COMPLETE</promise>` — All tasks done, stop looping
- `<promise>NO MORE TASKS</promise>` — Variant used in some Pocock repos
- `<promise>ABORT</promise>` — Blocked, cannot continue, stop looping

---

## Parallel Execution

Use `ralph-parallel.sh` when issues are independent (touch different files). Each issue gets its own worktree and agent running concurrently.

```bash
bash plans/ralph-parallel.sh 26 27 28    # one agent per issue, max 3 concurrent
```

**When to use parallel vs sequential:**

| Scenario | Mode |
|----------|------|
| Issues touch different files | Parallel |
| Issues might conflict (same files) | Sequential |
| Many small fixes from a review | Parallel |
| Feature with ordered dependencies | Sequential |
| Rate-limited plan | Sequential (or max 2-3 parallel) |

**Parallel gotchas:**
- Max 2-3 concurrent agents before hitting rate limits
- Merge conflicts if agents modify the same files — use sequential for overlapping work
- Each agent creates its own PR — review and merge individually

---

## Hybrid Approach: Agent Teams + Ralph Loop

### The Insight

Parallel *implementation* causes merge conflicts because multiple agents write to the same files. But parallel *research* and *review* are safe — they're read-only operations where different agents examine the codebase from different angles without conflicting.

The hybrid approach uses Agent Teams (in-session) for the read-only phases and the Ralph loop (bash scripts) for implementation.

### Workflow

```
/ralph team-research     <-- Agent Teams (parallel, read-only, in-session)
    |
/ralph once or afk       <-- Ralph loop (sequential, writes code, bash script)
    |
/ralph team-review       <-- Agent Teams (parallel, read-only, in-session)
    |
/review-to-issues        <-- Creates next cycle's issues
    |
(cycle)
```

### When to Use Each Mode

| Mode | When | Token Cost | Time |
|------|------|-----------|------|
| `team-research` | Before implementation — multiple issues to investigate | ~3x single session | Faster than serial research |
| `once` | Interactive implementation with human oversight | 1x | Varies |
| `afk` | Autonomous implementation of clear specs | 1x per iteration | Unattended |
| `team-review` | After PR — want multi-lens review (correctness, security, architecture) | ~3x single session | Faster than 3 serial reviews |

**Both team modes are optional.** Skip for simple fixes, single-issue cycles, or tight token budgets. They add the most value when:
- There are 3+ issues to research before a Ralph run
- The PR touches security-sensitive or architecturally complex code

### Quality Gates

`TeammateIdle` and `TaskCompleted` hooks validate that teammates produce structured output before going idle or marking tasks complete. If a teammate's output is missing required sections (e.g. "Files affected", "Estimated complexity" for research, or severity headers for review), the hook rejects the completion and sends feedback.

### Constraints

- **Experimental** — Agent Teams is behind the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` flag
- **Max 2-3 teammates** — more will hit rate limits
- **No session resumption** — if the lead crashes, teammate work is lost
- **In-session only** — cannot be launched from bash scripts or `claude -p`

---

## Sources

- [Matt Pocock's X thread on Ralph](https://x.com/mattpocockuk/status/2007924876548637089)
- [Workshop repo 001](https://github.com/mattpocock/ralph-workshop-repo-001) (backend: Hono + SQLite)
- [Workshop repo 002](https://github.com/mattpocock/ralph-workshop-repo-002) (fullstack: Next.js + Playwright)
- [Official Ralph Wiggum plugin](https://github.com/anthropics/claude-code/blob/main/plugins/ralph-wiggum/README.md)
- [AI Hero — Getting Started with Ralph](https://www.aihero.dev/getting-started-with-ralph)
- [AI Hero — Workshop: Turn AI Agents into Autonomous Software Engineers](https://www.aihero.dev/events/turn-ai-agents-into-autonomous-software-engineers-with-ralph)
- [Awesome Ralph](https://github.com/snwfdhmp/awesome-ralph)
