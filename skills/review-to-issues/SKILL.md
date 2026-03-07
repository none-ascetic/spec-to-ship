---
name: review-to-issues
description: Parse a Claude PR review into GitHub issues for the next Ralph cycle. Use when user says "review to issues", "harvest review", "create issues from review", "parse review", "process review", or after Claude reviews a Ralph PR.
argument-hint: "[PR number]"
---

# Review to Issues

**Workflow chain:** `/write-a-prd` → `/prd-to-plan` → `/plan-to-issues` → `/ralph` → [PR + Claude review] → **`/review-to-issues`** (you are here) → `/ralph` (cycle)

Parse a Claude PR review into GitHub issues for the next Ralph cycle. Automates the handoff between "Claude reviews a PR" and "Ralph fixes the findings."

## Process

### 1. Detect the PR

Three paths in priority order:

1. If `$ARGUMENTS` contains a number, use it as the PR number
2. Otherwise detect from current branch: `git branch --show-current` → `gh pr list --head <branch> --state all --json number,title --jq '.[0]'`
3. If nothing found, ask the user for the PR number

### 2. Fetch PR comments

```bash
gh pr view <number> --json comments --jq '.comments[].body'
```

Also check formal reviews:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews --jq '.[].body'
```

### 3. Identify Claude's review

Heuristic — in priority order:

1. **Longest comment** containing severity markers: `### Critical`, `### 🔴 Critical`, `### Medium`, `### 🟡 Medium`, `### Low`, `### 🟢 Low`, `### Nits`
2. **Secondary:** starts with `**Claude finished` or contains `PR Review:`
3. **Fallback:** show all comments to the user and ask which is the review

### 4. Parse structured findings

Split on `### ` severity headers (Critical, Medium, Low, Nits), then split on `**N.` numbered titles within each section. Extract per finding:

- **Title** — from the bold numbered heading
- **Severity** — from the parent section header
- **Description** — everything between this title and the next
- **Affected files** — from code block references like `file.ts:line`
- **Recommendation** — the suggested fix text

If the format is unrecognised (no severity headers), fall back to asking the user to paste/identify the findings manually.

### 5. Present findings for approval

Show a numbered list with title, severity, affected files, and a one-line summary per finding. Then ask:

- Which findings should become issues? (default: all Critical + Medium)
- Merge or split any?
- Re-prioritise any?
- Additional context to add?

Iterate until the user approves.

### 6. Create labels if needed

Check existing labels with `gh label list`. Create any that are missing:

- `review-fix` (color `D93F0B`)
- `critical` (color `B60205`)
- `bug` (if not already present)

### 7. Create issues

Create in severity order (Critical first → lowest issue numbers → Ralph picks them first).

Use this issue body template:

<issue-template>
## Source

PR #<pr-number> review — <severity>

## Problem

<parsed description including code blocks>

## Affected Files

- `<file:line>` — <context>

## Acceptance Criteria

- [ ] <derived from recommendation>
- [ ] Existing tests still pass
- [ ] No regressions

## Recommendation

<recommendation from review>

## Blocked by

None - can start immediately
</issue-template>

Labels: `bug` + severity label (`critical` / `medium` / `low`). Add `review-fix` to all.

### 8. Show next steps

After creating all issues, show a summary table (issue number, title, severity, labels) and suggest Ralph commands.

**Analyse file overlap first** — for each issue, collect the files from its "Affected Files" section. Compare across all issues. If any two issues share a file, flag the overlap.

Then suggest Ralph commands based on overlap analysis:

- **If all issues touch independent files** → recommend parallel:
  `bash plans/ralph-parallel.sh <numbers>` (recommended — no file overlap detected)
- **If any files overlap** → recommend sequential:
  `bash plans/ralph-sequential.sh 10` (recommended — issues share files: `<list overlapping files>`)
  Explain: "Parallel agents modifying the same files will create merge conflicts. Sequential mode avoids this."

Always show both options, but mark the recommended one. Also show:
- **Interactive**: `/ralph once`

**Multi-lens review option:** For deeper review of the next PR, consider using
`/ralph team-review` instead of a single `@claude review`. This spawns 3
specialised reviewers (correctness, security, architecture) that examine the
PR simultaneously. The consolidated output feeds directly into `/review-to-issues`.

Remind the user: "After Ralph completes and Claude reviews the next PR, run `/review-to-issues` again to continue the cycle."
