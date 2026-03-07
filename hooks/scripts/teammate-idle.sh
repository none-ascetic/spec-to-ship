#!/bin/bash
# TeammateIdle hook — validate teammate produced structured output
# Exit 2 = reject (send feedback), Exit 0 = allow idle

transcript=$(cat)

# Check for issue-researcher output markers
if echo "$transcript" | grep -q "Files affected" && \
   echo "$transcript" | grep -q "Estimated complexity"; then
  exit 0
fi

# Check for pr-reviewer output markers
if echo "$transcript" | grep -qE "### Critical|### Medium|### Low"; then
  exit 0
fi

# If this isn't a ralph team agent, allow idle
if ! echo "$transcript" | grep -qi "issue-researcher\|pr-reviewer\|team-research\|team-review"; then
  exit 0
fi

# Ralph team agent without structured output — reject
echo "Your findings are incomplete. Please include all required sections (Files affected, Estimated complexity, Suggested implementation approach for research; or severity-rated findings with Critical/Medium/Low headers for review) before finishing."
exit 2
