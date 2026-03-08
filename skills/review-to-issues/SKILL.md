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

### 5. Size check — detect sweep findings

For each parsed finding, check against the sizing heuristic:

<sizing-heuristic>
A well-scoped Ralph issue completes in 1-3 iterations. Each iteration = one
sub-task = one coherent change affecting 1-5 files.

RED FLAGS (issue is too big):
1. Sweep language — "all", "every", "each" + plural ("migrate all tests",
   "update every endpoint")
2. Multiple unrelated files — 4+ files for different reasons (not one
   refactor rippling through imports)
3. >3 acceptance criteria — unless they're sub-checks of one logical change
4. Repetition pattern — "rename X in Y places", "add Z to all endpoints"
5. Horizontal sweep — same operation across many locations rather than a
   vertical slice through one path

SPLIT RULE: Split by instance or location.
- "Migrate all test groups" -> one issue per test group (or per 2-3 similar)
- "Add error handling to all endpoints" -> one issue per route file
- "Fix same bug in 5 files" -> one issue per file (or group by directory)
Target: 1-3 acceptance criteria, 1-5 files per issue.
</sizing-heuristic>

If a red flag triggers:
- Identify the specific instances/locations affected
- Propose a split (one issue per instance or small group)
- Mark with `[SPLIT PROPOSED]` in the presentation list

### 6. Present findings for approval

Show a numbered list with title, severity, affected files, and a one-line summary per finding. Then ask:

- Which findings should become issues? (default: all Critical + Medium)
- Merge or split any?
- Re-prioritise any?
- Accept or reject proposed splits for oversized findings?
- Additional context to add?

Iterate until the user approves.

### 7. Detect parent PRD

Look for a parent PRD issue so review-fix issues can be linked as sub-issues:

1. Check the PR body and linked issues for a PRD reference (e.g., `#76`, or an issue labeled `PRD`)
2. If found, note the PRD issue number for sub-issue linking in step 9
3. If not found, ask the user: "Is there a parent PRD issue these fixes should be linked to? (Enter issue number or skip)"

### 8. Check and create labels

Check existing labels before creating any:

```bash
gh label list --limit 100
```

Only create labels that don't already exist:

```bash
gh label create "review-fix" --color "D93F0B" --description "Fix from PR review" 2>/dev/null || true
gh label create "critical" --color "B60205" --description "Critical severity" 2>/dev/null || true
gh label create "bug" --color "d73a4a" --description "Something isn't working" 2>/dev/null || true
```

### 9. Create issues and link as sub-issues

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

**If a parent PRD was identified in step 7**, link each created issue as a sub-issue:

```bash
PARENT_ID=$(gh issue view <prd-issue-number> --json id --jq '.id')
CHILD_ID=$(gh issue view <new-issue-number> --json id --jq '.id')
gh api graphql -f query='
  mutation($parentId: ID!, $childId: ID!) {
    addSubIssue(input: { issueId: $parentId, subIssueId: $childId }) {
      issue { number }
      subIssue { number }
    }
  }
' -f parentId="$PARENT_ID" -f childId="$CHILD_ID"
```

### 10. Check PR merge status before suggesting Ralph

Before suggesting any Ralph commands, check whether the source PR is merged:

```bash
gh pr view <number> --json state,mergedAt --jq '{state: .state, mergedAt: .mergedAt}'
```

**If the PR is NOT merged (state != "MERGED"):**

Stop. Do not suggest Ralph commands. Instead show:

> ⚠️ **PR #N is not yet merged into main.**
>
> Running Ralph now would create worktrees branching from `<current-branch>` instead of `main`. This causes:
> - Cascading conflict chains when fixes build on unmerged code
> - Harder merges later (conflicts between fix branches + original PR changes)
>
> **Do this first:**
> 1. Merge PR #N into `main` (approve + merge on GitHub, or `gh pr merge <number> --merge`)
> 2. `git checkout main && git pull`
> 3. Then run `/review-to-issues <number>` again — or just run the Ralph commands below once you're on `main`
>
> Issues have been created and are ready. Come back after merging.

**If the PR IS merged:** continue to the next step.

### 11. Show next steps

After creating all issues, show a summary table (issue number, title, severity, labels) and suggest Ralph commands.

**Analyse file overlap first** — for each issue, collect the files from its "Affected Files" section. Compare across all issues. If any two issues share a file, flag the overlap.

**Choose the model** based on issue complexity:

| Model | When to use | Examples |
|-------|-------------|---------|
| `haiku` | Trivial changes — comments, renames, single-line fixes | Adding a comment, renaming a variable, Low-severity review fixes |
| `sonnet` (default) | Standard implementation — most issues | Medium-severity fixes, typical vertical slices, schema changes |
| `opus` | Complex architecture — multi-file design decisions, tricky logic | Critical bugs, new subsystems, issues touching 5+ files with interdependencies |

Then suggest Ralph commands based on overlap analysis:

- **If all issues touch independent files** → recommend parallel:
  `bash plans/ralph-parallel.sh --model <model> <numbers>` (recommended — no file overlap detected)
- **If any files overlap** → recommend sequential:
  `bash plans/ralph-sequential.sh 10 <model>` (recommended — issues share files: `<list overlapping files>`)
  Explain: "Parallel agents modifying the same files will create merge conflicts. Sequential mode avoids this."

Always show both options, but mark the recommended one. Also show:
- **Interactive**: `/ralph once`

**Multi-lens review option:** For deeper review of the next PR, consider using
`/ralph team-review` instead of a single `@claude review`. This spawns 3
specialised reviewers (correctness, security, architecture) that examine the
PR simultaneously. The consolidated output feeds directly into `/review-to-issues`.

Remind the user: "After Ralph completes and Claude reviews the next PR, run `/review-to-issues` again to continue the cycle."

> **Rule of thumb:** Always merge the PR under review before running Ralph on its findings. Fixes should always branch from `main`, never from an open PR branch.
