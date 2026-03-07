#!/bin/bash
# TaskCompleted hook — validate task output has required sections
# Exit 2 = reject completion, Exit 0 = allow

transcript=$(cat)

# Only gate ralph team tasks (check for research/review markers in task context)
if ! echo "$transcript" | grep -qi "research issue\|review.*pr\|correctness\|security\|architecture"; then
  exit 0
fi

# Check for any structured output
if echo "$transcript" | grep -qE "Files affected|Estimated complexity|### Critical|### Medium|### Low"; then
  exit 0
fi

echo "Task output is missing structured findings. Please produce your analysis with the required format before marking complete."
exit 2
