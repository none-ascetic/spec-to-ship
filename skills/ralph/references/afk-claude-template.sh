#!/bin/bash
# Ralph AFK — bare-metal loop (no worktree isolation)
# For isolated runs, use ralph-sequential.sh or ralph-parallel.sh instead
# Exit codes: 0=COMPLETE, 1=ABORT, 2=exhausted

set -e

# Force OAuth — remove this line if using API key authentication
unset ANTHROPIC_API_KEY

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'
final_result='select(.type == "result").result // empty'

# Build MCP flags if config exists
MCP_FLAGS=""
if [ -f ".mcp.json" ]; then
  MCP_FLAGS="--mcp-config .mcp.json"
fi

for ((i=1; i<=$1; i++)); do
  tmpfile=$(mktemp)
  trap "rm -f $tmpfile" EXIT
  echo "------- ITERATION $i --------"

  ralph_commits=$(git log --grep="RALPH" -n 10 \
    --format="%H%n%ad%n%B---" --date=short 2>/dev/null \
    || echo "No RALPH commits found")

  cat <<PROMPT | claude -p \
    --output-format stream-json --verbose \
    --allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch" \
    $MCP_FLAGS \
  | grep --line-buffered '^{' \
  | tee "$tmpfile" \
  | jq --unbuffered -rj "$stream_text"
$(cat plans/prompt.md)

Previous RALPH commits:
$ralph_commits
PROMPT

  result=$(jq -r "$final_result" "$tmpfile")

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "Ralph complete after $i iterations."
    exit 0
  fi

  if [[ "$result" == *"<promise>ABORT</promise>"* ]]; then
    echo "Ralph aborted at iteration $i."
    exit 1
  fi
done

# Exhausted all iterations without COMPLETE or ABORT — more work remains
echo "Ralph used all $1 iterations. More work likely remains."
exit 2
