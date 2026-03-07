#!/bin/bash
# Ralph Sequential — iterates in a worktree, auto-PR on COMPLETE
# Uses native git worktrees via `claude -p --worktree`
# Exit codes: 0=COMPLETE, 1=ABORT, 2=exhausted

set -e

# Force OAuth — remove this line if using API key authentication
unset ANTHROPIC_API_KEY

BATCH_SIZE="${1:-10}"
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

echo "Ralph sequential — worktree: ${WORKTREE_NAME}, batch size: ${BATCH_SIZE}"
echo "Base branch: ${BASE_BRANCH}"
echo "Log: $LOG_FILE"

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
      echo ""
      echo "Tip: Clean up worktrees with: git worktree list | grep ralph-seq- | awk '{print \$1}' | xargs -I{} git worktree remove {}"

      # Push branch and create PR
      worktree_dir=".claude/worktrees/${WORKTREE_NAME}"
      if [ -d "$worktree_dir" ]; then
        branch_name=$(cd "$worktree_dir" && git rev-parse --abbrev-ref HEAD)
        git push origin "$branch_name" 2>>"$LOG_FILE"

        pr_url=$(gh pr create \
          --base "$BASE_BRANCH" \
          --head "$branch_name" \
          --title "RALPH: Sequential run — ${WORKTREE_NAME}" \
          --body "Automated sequential Ralph run. Completed after $BATCH batch(es), $i iteration(s)." \
          2>>"$LOG_FILE") || true

        if [ -n "$pr_url" ]; then
          gh pr comment "$pr_url" --body "@claude please review this PR" 2>>"$LOG_FILE" || true
          echo "PR created: $pr_url" | tee -a "$LOG_FILE"
        fi
      fi
      exit 0
    fi

    if [[ "$result" == *"<promise>ABORT</promise>"* ]]; then
      echo "Ralph ABORT at batch $BATCH, iteration $i." | tee -a "$LOG_FILE"
      exit 1
    fi
  done

  BATCH=$((BATCH + 1))
  echo "Iterations exhausted. Starting batch $BATCH in 5s..." | tee -a "$LOG_FILE"
  sleep 5
done
