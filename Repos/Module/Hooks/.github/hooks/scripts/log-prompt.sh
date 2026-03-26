#!/bin/bash
# User prompt submitted hook for GitHub Copilot
# Receives JSON input via stdin with the user's prompt

# Read JSON input
INPUT=$(cat)

# Parse prompt
PROMPT=$(echo "$INPUT" | grep -o '"prompt":"[^"]*"' | cut -d'"' -f4)
TIMESTAMP=$(echo "$INPUT" | grep -o '"timestamp":[0-9]*' | cut -d':' -f2)

# Log the prompt (example: for auditing or analytics)
echo "[$(date)] User prompt: $PROMPT" >&2

# You can implement additional logic here:
# - Audit logging for compliance
# - Usage analytics
# - Custom validation or pre-processing
