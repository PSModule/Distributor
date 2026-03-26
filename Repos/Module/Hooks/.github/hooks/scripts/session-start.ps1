#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Session start hook for GitHub Copilot.

.DESCRIPTION
    This script is triggered when a GitHub Copilot agent session starts.
    Receives JSON input via stdin with session information.
#>

# Read JSON input from stdin
$input = [Console]::In.ReadToEnd() | ConvertFrom-Json

# Log session start
$timestamp = $input.timestamp
$source = $input.source
Write-Host "[$(Get-Date)] Copilot session started (source: $source)" -ForegroundColor Green

# Initialize any session-specific resources here
# Example: Set up logging, validate environment, load custom configuration, etc.
