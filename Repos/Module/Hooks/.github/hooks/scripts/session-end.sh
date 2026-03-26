#!/bin/bash
# Session end hook for GitHub Copilot
# Receives JSON input via stdin with session completion information

# Read JSON input
INPUT=$(cat)

# Parse session info
TIMESTAMP=$(echo "$INPUT" | grep -o '"timestamp":[0-9]*' | cut -d':' -f2)
REASON=$(echo "$INPUT" | grep -o '"reason":"[^"]*"' | cut -d'"' -f4)

# Log session end
echo "[$(date)] Copilot session ended (reason: $REASON)" >&2

# Cleanup or finalize session resources here
# Example: Close log files, send metrics, cleanup temporary files, etc.
