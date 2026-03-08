---
name: plan-to-issues
description: Break an implementation plan into independently-grabbable GitHub issues using vertical slices (tracer bullets). Use when user wants to convert a plan to issues, create a backlog from phases, or mentions "tracer bullets". Comes after /prd-to-plan in the workflow chain.
---

# Plan to Issues

**Workflow chain:** `/write-a-prd` → `/prd-to-plan` → **`/plan-to-issues`** (you are here) → `/ralph` → `/review-to-issues` → `/ralph` (cycle)

Break an implementation plan into independently-grabbable GitHub issues using vertical slices (tracer bullets). Reads from the plan file created by `/prd-to-plan`.

## Process

### 1. Locate the plan

Ask the user for the plan file path (usually in `./plans/`). If the plan is not already in your context window, read it.

Also locate the parent PRD (GitHub issue) so issues can reference it.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code.

### 3. Draft vertical slices

Convert each plan phase into one or more GitHub issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Slices may be 'HITL' or 'AFK'. HITL slices require human interaction, such as an architectural decision or a design review. AFK slices can be implemented and merged without human interaction. Prefer AFK over HITL where possible.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
- Respect the dependency order from the plan
</vertical-slice-rules>

### 4. Size check — validate slice granularity

After drafting slices, check each against the sizing heuristic:

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

If red flags trigger:
- Pre-split oversized slices into smaller ones
- Mark with `[SPLIT]` and note the original slice

### 5. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Type**: HITL / AFK
- **Plan phase**: which phase from the plan this implements
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories from the PRD this addresses

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?
- Any auto-split slices that should be re-merged? (splits marked with [SPLIT])
- Are the correct slices marked as HITL and AFK?

Iterate until the user approves the breakdown.

### 6. Check and create labels

Before creating issues, check which labels already exist:

```bash
gh label list --limit 100
```

For each label you plan to use (e.g., `AFK`, `HITL`, `vertical-slice`, `PRD`, or any domain-specific labels), only create it if it doesn't already exist:

```bash
# Only create if missing
gh label create "AFK" --color "0E8A16" --description "Can be implemented without human interaction" 2>/dev/null || true
gh label create "HITL" --color "D93F0B" --description "Requires human-in-the-loop interaction" 2>/dev/null || true
gh label create "vertical-slice" --color "1D76DB" --description "Thin end-to-end tracer bullet" 2>/dev/null || true
```

Apply appropriate labels to each issue when creating it (see step 7).

### 7. Create the GitHub issues and link as sub-issues

For each approved slice, create a GitHub issue using `gh issue create`. Use the issue body template below.

Create issues in dependency order (blockers first) so you can reference real issue numbers in the "Blocked by" field.

**After creating each issue, link it as a sub-issue of the PRD** using the GraphQL API:

```bash
# Get the parent PRD's node ID (do this once)
PARENT_ID=$(gh issue view <prd-issue-number> --json id --jq '.id')

# After each `gh issue create` returns an issue number:
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

<issue-template>
## Parent PRD

#<prd-issue-number>

## Plan Phase

Phase <N>: <phase title>

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation. Reference specific sections of the parent PRD rather than duplicating content.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by

- Blocked by #<issue-number> (if any)

Or "None - can start immediately" if no blockers.

## User stories addressed

Reference by number from the parent PRD:

- User story 3
- User story 7

</issue-template>

Labels: Apply `vertical-slice` to all issues. Add `AFK` or `HITL` based on slice type. Add any domain-specific labels relevant to the slice.

Do NOT close or modify the parent PRD issue.

After creating all issues, suggest the next step with a model recommendation:

**Choose the model** based on issue complexity:

| Model | When to use | Examples |
|-------|-------------|---------|
| `haiku` | Trivial changes — comments, renames, single-line fixes | Adding a comment, renaming a variable |
| `sonnet` (default) | Standard implementation — most issues | Typical vertical slices, schema changes, API endpoints |
| `opus` | Complex architecture — multi-file design decisions, tricky logic | New subsystems, issues touching 5+ files with interdependencies |

Suggest: `bash plans/ralph-sequential.sh <iterations> <model>` (e.g., `bash plans/ralph-sequential.sh 20 sonnet`).

> **Tip:** The PRD issue now shows sub-issue progress — as Ralph closes each slice, the parent PRD tracks completion automatically in the GitHub UI.
