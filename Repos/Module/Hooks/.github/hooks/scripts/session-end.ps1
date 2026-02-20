#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Session end hook for GitHub Copilot.

.DESCRIPTION
    This script is triggered when a GitHub Copilot agent session ends.
    Receives JSON input via stdin with session completion information.
#>

# Read JSON input from stdin
$input = [Console]::In.ReadToEnd() | ConvertFrom-Json

# Log session end
$timestamp = $input.timestamp
$reason = $input.reason
Write-Host "[$(Get-Date)] Copilot session ended (reason: $reason)" -ForegroundColor Yellow

# Cleanup or finalize session resources here
# Example: Close log files, send metrics, cleanup temporary files, etc.
