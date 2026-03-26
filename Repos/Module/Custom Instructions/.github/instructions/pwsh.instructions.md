---
files:
  - '**/*.ps1'
  - '**/*.psm1'
  - '**/*.psd1'
---

# PowerShell Instructions

These are centrally managed instructions for working with PowerShell files in PSModule repositories.

## Guidelines

### Naming Conventions
- Use approved PowerShell verbs (Get, Set, New, Remove, etc.)
- Use PascalCase for function names (e.g., Get-UserData)
- Use PascalCase for parameter names
- Use descriptive, clear names that indicate purpose

### Function Structure
- Include comment-based help with .SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE
- Use [CmdletBinding()] for advanced functions
- Define parameters with proper types and validation
- Use ValueFromPipeline where appropriate

### Code Quality
- Follow PSScriptAnalyzer rules defined in the Linter Settings
- Use proper error handling (try/catch/finally)
- Avoid using aliases in scripts (use full cmdlet names)
- Avoid Write-Host; prefer Write-Output, Write-Verbose, Write-Warning
- Use strict mode: Set-StrictMode -Version Latest

### Parameter Validation
- Use parameter validation attributes ([ValidateNotNullOrEmpty()], [ValidateRange()], etc.)
- Provide parameter sets when needed
- Set default values appropriately
- Mark mandatory parameters with [Parameter(Mandatory)]

### Documentation
- Include comprehensive comment-based help
- Add inline comments for complex logic
- Provide at least one example in help
- Document any prerequisites or dependencies

### Testing
- Write Pester tests for all functions
- Test both success and failure paths
- Use descriptive test names
- Aim for high code coverage

### Best Practices
- Use splatting for cmdlets with many parameters
- Prefer pipeline operations over loops when possible
- Return objects, not formatted text
- Use proper output streams (Output, Error, Warning, Verbose, Debug)
- Follow the DRY principle (Don't Repeat Yourself)
