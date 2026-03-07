# INPUTS

Pull @plans/plan.md into your context for architectural decisions.

You've been passed a file containing the last 10 RALPH commits (SHA, date, full message). Review these to understand what work has been done.

# TASK SELECTION

Fetch open GitHub issues:

```
gh issue list --state open --json number,title,body,labels
```

Pick the lowest-numbered issue that is not blocked (check its "Blocked by" section — all referenced issues must be closed).

Read the issue's acceptance criteria carefully. Break that issue into the smallest possible sub-tasks. Pick ONE sub-task to implement.

A sub-task is a single coherent change — NOT an entire issue. Even if the project is empty, break it down. Examples of good sub-task granularity:
- Config files only (tsconfig, package.json, vite.config)
- Backend server skeleton (entry point, one route)
- Frontend shell (index.html, App component, mount)
- Wire frontend to backend (proxy config, first fetch)

If an acceptance criterion is already met (check the code), skip it.

If all issues are closed, output <promise>COMPLETE</promise>.

# EXPLORATION

Explore the repo and fill your context window with relevant information for the selected sub-task.

# EXECUTION

Complete the sub-task.

If anything blocks your completion, output <promise>ABORT</promise>.

# FEEDBACK LOOPS

Before committing, run the feedback loops:

- {{FEEDBACK_COMMANDS}}

# COMMIT

Make a git commit. The commit message must:

1. Start with `RALPH:` prefix
2. Reference the GitHub issue number (`#N`)
3. Sub-task completed
4. Key decisions made
5. Files changed
6. Remaining sub-tasks for this issue (or "Issue complete" if all acceptance criteria met)

Keep it concise.

# ISSUE CLOSURE

If ALL acceptance criteria for the current issue are now met, close it:

```
gh issue close <number> --comment "All acceptance criteria met. See commits: [list SHAs]"
```

# FINAL RULES

ONLY WORK ON A SINGLE SUB-TASK. This is non-negotiable.

Do NOT implement an entire issue in one iteration, even if the project is empty or the issue seems small. Each iteration should produce a focused, reviewable commit — not a full feature. If you find yourself creating more than 5 files, you are doing too much. Stop, commit what you have, and leave the rest for the next iteration.
