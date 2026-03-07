# spec-to-ship

Spec to ship in one workflow. PRD → Plan → Issues → Ralph → Review → Cycle.

A Claude Code plugin that packages the complete spec-to-ship development workflow — from writing a PRD through autonomous implementation (Ralph loops) to review cycling. Based on [Matt Pocock's Ralph methodology](https://www.aihero.dev/getting-started-with-ralph).

## Workflow

```
/write-a-prd ──→ /prd-to-plan ──→ /plan-to-issues ──→ /ralph ──→ /review-to-issues ──→ /ralph
                  │                                      │                                 │
                  │         shortcut: /prd-to-issues ────→│                                 │
                  │                                      │                                 │
                  └──── /grill-me (stress-test plan) ────┘                                 │
                                                                                           │
                                                                            (cycle continues)
```

**Optional branches:**
- `/grill-me` — stress-test any plan or design before committing
- `/design-an-interface` — explore multiple API/interface designs
- `/tdd` — red-green-refactor loop during implementation
- `/request-refactor-plan` — plan a refactor as a GitHub issue

## Quick Start

```bash
# Install from GitHub
claude plugin install spec-to-ship --marketplace https://github.com/none-ascetic/spec-to-ship

# Or use locally
claude --plugin-dir /path/to/spec-to-ship
```

Then in any project:

```
/write-a-prd          # Start with a PRD
/ralph setup          # Scaffold the autonomous loop
/ralph afk 20         # Run 20 iterations unattended
```

## Skills Reference

| Skill | Description | When to Use |
|-------|-------------|-------------|
| `/write-a-prd` | Deep interview → PRD as GitHub issue | Starting a new feature |
| `/prd-to-plan` | PRD → phased plan file (tracer bullets) | Large features needing phases |
| `/prd-to-issues` | PRD → GitHub issues directly | Small features (skip plan step) |
| `/plan-to-issues` | Plan phases → GitHub issues | After `/prd-to-plan` |
| `/ralph` | Autonomous coding loop | Implementation phase |
| `/review-to-issues` | PR review → GitHub issues | After Claude reviews a PR |
| `/grill-me` | Stress-test a plan or design | Before committing to a design |
| `/design-an-interface` | Generate multiple interface designs | API/module design phase |
| `/tdd` | Red-green-refactor TDD loop | Test-first development |
| `/request-refactor-plan` | Plan a refactor with tiny commits | Refactoring existing code |

## The Ralph Loop

Ralph is a bash loop that runs Claude Code repeatedly against GitHub issues until all tasks are complete. Each iteration gets a **fresh context window**, picks the next unblocked issue, implements one sub-task, runs feedback loops (tests/typecheck/lint), commits, and exits.

**Execution modes:**

- `bash plans/once-claude.sh` — HITL (interactive, you watch)
- `bash plans/afk-claude.sh 20` — AFK (20 autonomous iterations)
- `bash plans/ralph-sequential.sh 10` — Worktree-isolated sequential loop
- `bash plans/ralph-parallel.sh 26 27 28` — Parallel agents (one per issue)

Run `/ralph setup` to scaffold these scripts in your project.

See [skills/ralph/references/ralph-loop-guide.md](skills/ralph/references/ralph-loop-guide.md) for the full methodology guide.

## Agent Teams (Optional)

For projects using Claude Code Agent Teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`):

- `/ralph team-research` — Spawn parallel read-only researchers to investigate issues before implementation
- `/ralph team-review` — Spawn 3 specialised reviewers (correctness, security, architecture) for multi-lens PR review

These use the bundled `issue-researcher` and `pr-reviewer` agent definitions.

## Workflow Examples

### Greenfield Feature

```
/write-a-prd              # Interview → PRD issue
/grill-me                 # Stress-test the PRD
/prd-to-plan              # Break into phases
/plan-to-issues           # Create GitHub issues
/ralph setup              # Scaffold scripts
# In a separate terminal:
bash plans/ralph-sequential.sh 10
# After PR review:
/review-to-issues         # Review findings → new issues
# Repeat
```

### Bug Fix Cycle

```
/review-to-issues 42      # Parse review from PR #42
# In a separate terminal:
bash plans/ralph-parallel.sh 50 51 52
```

### Refactor

```
/request-refactor-plan    # Plan with tiny commits → GitHub issue
/ralph setup              # Scaffold (if first time)
/ralph once               # Interactive first iteration
# Then AFK:
bash plans/afk-claude.sh 15
```

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 1.0.33+
- [GitHub CLI](https://cli.github.com/) (`gh`) — for issue/PR management
- Git
- `jq` — for AFK script output parsing
- Unix/macOS (or WSL on Windows) — bash scripts required

## Credits

- **Ralph methodology:** [Matt Pocock / AI Hero](https://www.aihero.dev)
- **"Design It Twice":** John Ousterhout, *A Philosophy of Software Design*
- **Plugin:** [none-ascetic](https://github.com/none-ascetic)

## License

MIT
