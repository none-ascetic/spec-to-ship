#!/bin/bash
# Ralph Parallel — one worktree agent per issue, auto-PR on completion
# Uses native git worktrees via `claude -p --worktree`
# Usage: bash plans/ralph-parallel.sh 26 27 28

set -e

# Force OAuth — remove this line if using API key authentication
unset ANTHROPIC_API_KEY

if [ $# -eq 0 ]; then
  echo "Usage: $0 <issue_numbers...>"
  echo "Example: $0 26 27 28"
  exit 1
fi

BASE_BRANCH=$(git branch --show-current)
LOG_DIR="plans/logs"
mkdir -p "$LOG_DIR"

MAX_CONCURRENT=3

# Build MCP flags if config exists
MCP_FLAGS=""
if [ -f ".mcp.json" ]; then
  MCP_FLAGS="--mcp-config .mcp.json"
fi

# Pre-flight: check for file overlap across issues
echo "Pre-flight: checking for file overlap across issues..."
declare -A file_to_issues
overlap_found=false

for issue_num in "$@"; do
  files=$(gh issue view "$issue_num" --json body --jq '.body' 2>/dev/null \
    | grep -oE '`[^`]+\.[a-zA-Z]+`' \
    | tr -d '`' \
    | sort -u)
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [ -n "${file_to_issues[$f]}" ]; then
      file_to_issues[$f]="${file_to_issues[$f]}, #$issue_num"
      overlap_found=true
    else
      file_to_issues[$f]="#$issue_num"
    fi
  done <<< "$files"
done

if [ "$overlap_found" = true ]; then
  echo ""
  echo "WARNING: File overlap detected across issues!"
  echo "Overlapping files:"
  for f in "${!file_to_issues[@]}"; do
    if [[ "${file_to_issues[$f]}" == *","* ]]; then
      echo "  $f → ${file_to_issues[$f]}"
    fi
  done
  echo ""
  echo "Parallel agents modifying the same files will create merge conflicts."
  echo "Consider using: bash plans/ralph-sequential.sh <batch_size>"
  echo ""
  read -r -p "Continue anyway? [y/N] " response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Aborted. Use ralph-sequential.sh for overlapping issues."
    exit 0
  fi
fi

pids=()
issues=()

for issue_num in "$@"; do
  # Throttle: wait for a slot if at max concurrency
  while [ ${#pids[@]} -ge $MAX_CONCURRENT ]; do
    new_pids=()
    for pid in "${pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        new_pids+=("$pid")
      fi
    done
    pids=("${new_pids[@]}")
    if [ ${#pids[@]} -ge $MAX_CONCURRENT ]; then
      sleep 2
    fi
  done

  log_file="$LOG_DIR/ralph-issue-${issue_num}.log"
  echo "Starting agent for issue #${issue_num} → $log_file"

  (
    issue_title=$(gh issue view "$issue_num" --json title --jq '.title' 2>/dev/null || echo "Issue #${issue_num}")

    ralph_commits=$(git log --grep="RALPH" -n 10 \
      --format="%H%n%ad%n%B---" --date=short 2>/dev/null \
      || echo "No RALPH commits found")

    cat <<PROMPT | claude -p \
      --worktree "issue-${issue_num}" \
      --output-format stream-json --verbose \
      --allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch" \
      $MCP_FLAGS \
      >> "$log_file" 2>&1
$(cat plans/prompt.md)

Target: Fix issue #${issue_num} only. Do not work on any other issue.

Previous RALPH commits:
$ralph_commits
PROMPT

    # Push branch and create PR
    worktree_dir=".claude/worktrees/issue-${issue_num}"
    if [ -d "$worktree_dir" ]; then
      branch_name=$(cd "$worktree_dir" && git rev-parse --abbrev-ref HEAD)
      git push origin "$branch_name" 2>>"$log_file"

      pr_url=$(gh pr create \
        --base "$BASE_BRANCH" \
        --head "$branch_name" \
        --title "RALPH: Fix #${issue_num} — ${issue_title}" \
        --body "Automated fix for #${issue_num} via Ralph parallel agent." \
        2>>"$log_file") || true

      if [ -n "$pr_url" ]; then
        gh pr comment "$pr_url" --body "@claude please review this PR" 2>>"$log_file" || true
        echo "PR created: $pr_url" >> "$log_file"
      fi
    else
      echo "Warning: worktree dir $worktree_dir not found" >> "$log_file"
    fi
  ) &

  pids+=($!)
  issues+=("$issue_num")
done

echo "Waiting for ${#pids[@]} agents to finish..."
failures=0
for i in "${!pids[@]}"; do
  if ! wait "${pids[$i]}"; then
    echo "Agent for issue #${issues[$i]} failed. Check $LOG_DIR/ralph-issue-${issues[$i]}.log"
    failures=$((failures + 1))
  else
    echo "Agent for issue #${issues[$i]} completed."
  fi
done

echo "All agents done. $failures failure(s). Logs in $LOG_DIR/"
echo ""
echo "Tip: Clean up worktrees with: git worktree list | grep issue- | awk '{print \$1}' | xargs -I{} git worktree remove {}"
exit $failures
