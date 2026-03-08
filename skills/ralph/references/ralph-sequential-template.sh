#!/bin/bash
# Ralph Sequential — iterates in a worktree, auto-PR on COMPLETE or ABORT
# Uses native git worktrees via `claude -p --worktree`
# Exit codes: 0=COMPLETE, 1=ABORT, 2=exhausted

set -e

# Force OAuth — remove this line if using API key authentication
unset ANTHROPIC_API_KEY

BATCH_SIZE="${1:-10}"
MODEL="${2:-sonnet}"
BASE_BRANCH=$(git branch --show-current)
WORKTREE_NAME="ralph-seq-$(date +%s)"
LOG_DIR="plans/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${WORKTREE_NAME}.log"

stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'
final_result='select(.type == "result").result // empty'

# Build MCP flags if config exists
MCP_FLAGS=""
if [ -f ".mcp.json" ]; then
  MCP_FLAGS="--mcp-config .mcp.json"
fi

echo "Ralph sequential — worktree: ${WORKTREE_NAME}, batch size: ${BATCH_SIZE}, model: ${MODEL}"
echo "Base branch: ${BASE_BRANCH}"
echo "Log: $LOG_FILE"

# Push worktree branch and create a PR. Called on COMPLETE, ABORT, or exhaustion.
# Args: $1=reason ("COMPLETE"|"ABORT"|"exhausted"), $2=batch, $3=iteration
push_and_pr() {
  local reason="$1" batch="$2" iteration="$3"
  local worktree_dir=".claude/worktrees/${WORKTREE_NAME}"

  if [ ! -d "$worktree_dir" ]; then
    echo "No worktree directory found — skipping PR." | tee -a "$LOG_FILE"
    return
  fi

  # Only PR if there are commits beyond base
  local branch_name
  branch_name=$(cd "$worktree_dir" && git rev-parse --abbrev-ref HEAD)
  local commit_count
  commit_count=$(cd "$worktree_dir" && git rev-list --count "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "0")

  if [ "$commit_count" -eq 0 ]; then
    echo "No new commits on $branch_name — skipping PR." | tee -a "$LOG_FILE"
    return
  fi

  echo "Pushing $branch_name ($commit_count commits)..." | tee -a "$LOG_FILE"
  git push origin "$branch_name" 2>>"$LOG_FILE"

  local pr_body="Automated sequential Ralph run.\n\n"
  pr_body+="**Status:** ${reason} after ${batch} batch(es), ${iteration} iteration(s).\n"
  pr_body+="**Commits:** ${commit_count}\n"
  pr_body+="**Log:** \`${LOG_FILE}\`"

  local pr_url
  pr_url=$(gh pr create \
    --base "$BASE_BRANCH" \
    --head "$branch_name" \
    --title "RALPH: Sequential run — ${WORKTREE_NAME}" \
    --body "$(echo -e "$pr_body")" \
    2>>"$LOG_FILE") || true

  if [ -n "$pr_url" ]; then
    gh pr comment "$pr_url" --body "@claude please review this PR" 2>>"$LOG_FILE" || true
    echo "PR created: $pr_url" | tee -a "$LOG_FILE"
  fi
}

BATCH=1
while true; do
  echo "======= BATCH $BATCH (${BATCH_SIZE} iterations) =======" | tee -a "$LOG_FILE"

  for ((i=1; i<=$BATCH_SIZE; i++)); do
    tmpfile=$(mktemp)
    trap "rm -f $tmpfile" EXIT
    echo "------- ITERATION $i --------" | tee -a "$LOG_FILE"

    ralph_commits=$(git log --grep="RALPH" -n 10 \
      --format="%H%n%ad%n%B---" --date=short 2>/dev/null \
      || echo "No RALPH commits found")

    cat <<PROMPT | claude -p \
      --model "$MODEL" \
      --worktree "$WORKTREE_NAME" \
      --output-format stream-json --verbose \
      --allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch" \
      $MCP_FLAGS \
    | grep --line-buffered '^{' \
    | tee "$tmpfile" \
    | jq --unbuffered -rj "$stream_text" \
    | tee -a "$LOG_FILE"
$(cat plans/prompt.md)

Previous RALPH commits:
$ralph_commits
PROMPT

    result=$(jq -r "$final_result" "$tmpfile")

    if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
      echo "Ralph COMPLETE after batch $BATCH, iteration $i." | tee -a "$LOG_FILE"
      push_and_pr "COMPLETE" "$BATCH" "$i"
      exit 0
    fi

    if [[ "$result" == *"<promise>ABORT</promise>"* ]]; then
      echo "Ralph ABORT at batch $BATCH, iteration $i." | tee -a "$LOG_FILE"
      push_and_pr "ABORT" "$BATCH" "$i"
      exit 1
    fi
  done

  BATCH=$((BATCH + 1))
  echo "Iterations exhausted. Starting batch $BATCH in 5s..." | tee -a "$LOG_FILE"
  sleep 5
done
