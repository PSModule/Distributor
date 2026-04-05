#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Syncs managed files from this repository to subscribing repositories in the organization.

.DESCRIPTION
    This script:
    1. Creates Installation Access Token contexts for repo-level operations
    2. Discovers available file sets from the Repos/ directory structure
    3. Queries all organization repositories with their Type and SubscribeTo custom properties
    4. For each subscribing repository:
       - Clones the repository
       - Copies managed files from the appropriate file sets
       - Detects changes using git
       - Creates or updates a pull request if changes are detected
    5. Outputs a summary of actions taken

.NOTES
    Requires the GitHub PowerShell module and GitHub App authentication via GitHub-Script action.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Track summary information
$script:Summary = @{
    TotalReposProcessed      = 0
    PRsCreated               = 0
    PRsUpdated               = 0
    ReposAlreadyInSync       = 0
    ReposSkipped             = 0
    Errors                   = @()
}

#region Helper Functions

function Write-SyncLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $prefix = switch ($Level) {
        'Info' { '💡' }
        'Warning' { '⚠️ ' }
        'Error' { '❌' }
        'Success' { '✅' }
    }

    $fullMessage = "[$timestamp] $prefix $Message"

    switch ($Level) {
        'Error' { Write-Error $fullMessage -ErrorAction Continue }
        'Warning' { Write-Warning $fullMessage }
        default { Write-Information $fullMessage }
    }
}

function Get-FileSets {
    <#
    .SYNOPSIS
        Discovers available file sets from the Repos/ directory structure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ReposPath
    )

    $fileSets = @{}

    if (-not (Test-Path $ReposPath)) {
        Write-SyncLog "Repos directory not found at: $ReposPath" -Level Error
        return $fileSets
    }

    # Get all type directories (first level)
    $typeDirs = Get-ChildItem -Path $ReposPath -Directory

    foreach ($typeDir in $typeDirs) {
        $typeName = $typeDir.Name
        $fileSets[$typeName] = @{}

        # Get all selection directories (second level)
        $selectionDirs = Get-ChildItem -Path $typeDir.FullName -Directory

        foreach ($selectionDir in $selectionDirs) {
            $selectionName = $selectionDir.Name

            # Get all files in this selection directory recursively
            $files = Get-ChildItem -Path $selectionDir.FullName -File -Recurse

            $fileList = @()
            foreach ($file in $files) {
                # Compute relative path from selection directory root
                $relativePath = $file.FullName.Substring($selectionDir.FullName.Length + 1)
                $fileList += @{
                    SourcePath   = $file.FullName
                    RelativePath = $relativePath
                }
            }

            $fileSets[$typeName][$selectionName] = $fileList
            Write-SyncLog "Discovered file set: $typeName/$selectionName ($($fileList.Count) files)" -Level Info
        }
    }

    return $fileSets
}

function Get-SubscribingRepositories {
    <#
    .SYNOPSIS
        Queries all organization repositories with their Type and SubscribeTo custom properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Owner,

        [Parameter(Mandatory)]
        [object]$Context
    )

    Write-SyncLog "Querying repositories in organization: $Owner" -Level Info

    try {
        $repos = Get-GitHubRepository -Owner $Owner -Context $Context
        Write-SyncLog "Found $($repos.Count) repositories in organization" -Level Info

        $subscribingRepos = @()

        foreach ($repo in $repos) {
            $customProps = $repo.CustomProperties

            if (-not $customProps) {
                continue
            }

            $type = ($customProps | Where-Object Name -EQ 'Type').Value
            $subscribeTo = ($customProps | Where-Object Name -EQ 'SubscribeTo').Value

            # Both Type and SubscribeTo must be set
            if ([string]::IsNullOrWhiteSpace($type) -or -not $subscribeTo) {
                continue
            }

            # SubscribeTo might be a single value or array
            if ($subscribeTo -is [string]) {
                $subscribeTo = @($subscribeTo)
            }

            if ($subscribeTo.Count -eq 0) {
                continue
            }

            $subscribingRepos += @{
                Name         = $repo.Name
                Owner        = $repo.Owner.Login
                FullName     = $repo.FullName
                Type         = $type
                SubscribeTo  = $subscribeTo
                DefaultBranch = $repo.DefaultBranch
            }

            Write-SyncLog "Repository '$($repo.FullName)' subscribes to: Type=$type, SubscribeTo=$($subscribeTo -join ', ')" -Level Info
        }

        Write-SyncLog "Found $($subscribingRepos.Count) repositories with subscriptions" -Level Success

        return $subscribingRepos
    } catch {
        Write-SyncLog "Failed to query repositories: $_" -Level Error
        throw
    }
}

function Sync-RepositoryFiles {
    <#
    .SYNOPSIS
        Syncs files to a single repository.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Repository,

        [Parameter(Mandatory)]
        [hashtable]$FileSets,

        [Parameter(Mandatory)]
        [string]$TempPath,

        [Parameter(Mandatory)]
        [string]$BranchName,

        [Parameter(Mandatory)]
        [string]$CommitMessage,

        [Parameter(Mandatory)]
        [string]$PRTitle,

        [Parameter(Mandatory)]
        [string]$PRBody,

        [Parameter(Mandatory)]
        [string]$PRLabel,

        [Parameter(Mandatory)]
        [object]$Context
    )

    $repoFullName = $Repository.FullName
    $owner = $Repository.Owner
    $repoName = $Repository.Name
    $type = $Repository.Type
    $subscribeTo = $Repository.SubscribeTo

    Write-SyncLog "Processing repository: $repoFullName" -Level Info

    $script:Summary.TotalReposProcessed++

    # Check if type folder exists
    if (-not $FileSets.ContainsKey($type)) {
        Write-SyncLog "Type folder '$type' not found for repository $repoFullName - skipping" -Level Warning
        $script:Summary.ReposSkipped++
        return
    }

    # Collect all files to sync
    $filesToSync = @()
    foreach ($selection in $subscribeTo) {
        if (-not $FileSets[$type].ContainsKey($selection)) {
            Write-SyncLog "Selection '$selection' not found under type '$type' for repository $repoFullName - skipping this selection" -Level Warning
            continue
        }

        $files = $FileSets[$type][$selection]
        $filesToSync += $files
        Write-SyncLog "Added $($files.Count) files from $type/$selection" -Level Info
    }

    if ($filesToSync.Count -eq 0) {
        Write-SyncLog "No files to sync for repository $repoFullName - skipping" -Level Warning
        $script:Summary.ReposSkipped++
        return
    }

    Write-SyncLog "Total files to sync: $($filesToSync.Count)" -Level Info

    # Create temporary directory for clone
    $clonePath = Join-Path $TempPath "clone-$repoName-$(Get-Random)"
    New-Item -Path $clonePath -ItemType Directory -Force | Out-Null

    try {
        # Clone repository (shallow)
        Write-SyncLog "Cloning repository: $repoFullName" -Level Info
        $cloneUrl = "https://github.com/$repoFullName.git"

        $gitCloneResult = git clone --depth 1 $cloneUrl $clonePath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Git clone failed: $gitCloneResult"
        }

        # Configure git identity and authentication
        Push-Location $clonePath
        try {
            Set-GitHubGitConfig -Context $Context
            Write-SyncLog "Git credentials configured for $repoFullName" -Level Info

            # Check if branch already exists
            $branchExists = $false
            $remoteBranches = git branch -r 2>&1
            if ($remoteBranches -match "origin/$BranchName") {
                $branchExists = $true
                Write-SyncLog "Branch '$BranchName' already exists - will update it" -Level Info
            }

            # Create or checkout branch
            if ($branchExists) {
                git fetch origin $BranchName 2>&1 | Out-Null
                git checkout $BranchName 2>&1 | Out-Null
            } else {
                git checkout -b $BranchName 2>&1 | Out-Null
            }

            # Copy files
            Write-SyncLog "Copying files to repository..." -Level Info
            foreach ($fileInfo in $filesToSync) {
                $targetPath = Join-Path $clonePath $fileInfo.RelativePath
                $targetDir = Split-Path $targetPath -Parent

                # Create directory if it doesn't exist
                if (-not (Test-Path $targetDir)) {
                    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                }

                # Copy file
                Copy-Item -Path $fileInfo.SourcePath -Destination $targetPath -Force
            }

            # Check for changes
            $status = git status --porcelain 2>&1
            if ([string]::IsNullOrWhiteSpace($status)) {
                Write-SyncLog "No changes detected for repository $repoFullName - already in sync" -Level Success
                $script:Summary.ReposAlreadyInSync++
                return
            }

            Write-SyncLog "Changes detected:" -Level Info
            $status -split "`n" | ForEach-Object {
                Write-SyncLog "  $_" -Level Info
            }

            # Stage all changes
            git add --all 2>&1 | Out-Null

            # Commit changes
            git commit -m $CommitMessage 2>&1 | Out-Null

            # Push branch (force push to handle updates)
            Write-SyncLog "Pushing branch to remote..." -Level Info
            $pushResult = git push --force --set-upstream origin $BranchName 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Git push failed: $pushResult"
            }

            Write-SyncLog "Branch pushed successfully" -Level Success

            # Create or update pull request
            try {
                # Check if PR already exists
                $existingPRs = (Invoke-GitHubAPI -Method GET -Endpoint "/repos/$owner/$repoName/pulls" -Body @{
                    head  = "${owner}:${BranchName}"
                    state = 'open'
                } -Context $Context).Response

                if ($existingPRs.Count -gt 0) {
                    $prNumber = $existingPRs[0].number
                    Write-SyncLog "Pull request #$prNumber already exists - it has been updated with the latest changes" -Level Success
                    $script:Summary.PRsUpdated++
                    $prUrl = $existingPRs[0].html_url
                } else {
                    # Create new PR
                    $prParams = @{
                        title = $PRTitle
                        head  = $BranchName
                        base  = $Repository.DefaultBranch
                        body  = $PRBody
                    }

                    $pr = (Invoke-GitHubAPI -Method POST -Endpoint "/repos/$owner/$repoName/pulls" -Body $prParams -Context $Context).Response

                    $prNumber = $pr.number
                    $prUrl = $pr.html_url

                    Write-SyncLog "Pull request #$prNumber created: $prUrl" -Level Success

                    # Add label to PR
                    try {
                        Invoke-GitHubAPI -Method POST -Endpoint "/repos/$owner/$repoName/issues/$prNumber/labels" -Body @{
                            labels = @($PRLabel)
                        } -Context $Context | Out-Null
                        Write-SyncLog "Added label '$PRLabel' to PR #$prNumber" -Level Success
                    } catch {
                        Write-SyncLog "Failed to add label to PR: $_" -Level Warning
                    }

                    $script:Summary.PRsCreated++
                }

                Write-SyncLog "Repository $repoFullName processed successfully: $prUrl" -Level Success

            } catch {
                Write-SyncLog "Failed to create/update pull request for $repoFullName : $_" -Level Error
                $script:Summary.Errors += "PR creation failed for $repoFullName : $_"
            }

        } finally {
            Pop-Location
        }

    } catch {
        Write-SyncLog "Failed to sync repository $repoFullName : $_" -Level Error
        $script:Summary.Errors += "Sync failed for $repoFullName : $_"
    } finally {
        # Cleanup
        if (Test-Path $clonePath) {
            Remove-Item -Path $clonePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

#endregion

#region Main Script

try {
    Write-SyncLog "=== Starting Managed Files Sync ===" -Level Info

    # Step 1: Create Installation Access Token contexts
    Write-SyncLog "Creating Installation Access Token contexts..." -Level Info
    $context = Connect-GitHubApp -PassThru
    Write-SyncLog "IAT contexts created successfully" -Level Success

    # Step 2: Discover file sets
    $reposPath = Join-Path $PSScriptRoot '../Repos'
    $reposPath = Resolve-Path $reposPath
    Write-SyncLog "Discovering file sets from: $reposPath" -Level Info

    $fileSets = Get-FileSets -ReposPath $reposPath

    if ($fileSets.Count -eq 0) {
        Write-SyncLog "No file sets found - exiting" -Level Warning
        exit 0
    }

    # Step 3: Get subscribing repositories
    $owner = 'PSModule'
    $subscribingRepos = Get-SubscribingRepositories -Owner $owner -Context $context

    if ($subscribingRepos.Count -eq 0) {
        Write-SyncLog "No subscribing repositories found - exiting" -Level Warning
        exit 0
    }

    # Step 4: Sync files to each repository
    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "distributor-sync-$(Get-Random)"
    New-Item -Path $tempPath -ItemType Directory -Force | Out-Null

    $branchName = 'managed-files/update'
    $commitMessage = 'chore: sync managed files'
    $prTitle = '⚙️ [Maintenance]: Sync managed files'
    $prLabel = 'NoRelease'
    $prBody = @"
This pull request was automatically created by the [Distributor](https://github.com/PSModule/Distributor) workflow that keeps shared files in sync across the organization's repositories.

The files in this PR are centrally managed. Any local changes to these files will be overwritten on the next sync. To propose changes, update the source files in the Distributor repo instead.
"@

    try {
        foreach ($repo in $subscribingRepos) {
            Sync-RepositoryFiles -Repository $repo `
                -FileSets $fileSets `
                -TempPath $tempPath `
                -BranchName $branchName `
                -CommitMessage $commitMessage `
                -PRTitle $prTitle `
                -PRBody $prBody `
                -PRLabel $prLabel `
                -Context $context
        }
    } finally {
        # Cleanup temp directory
        if (Test-Path $tempPath) {
            Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Step 5: Output summary
    Write-SyncLog "=== Sync Summary ===" -Level Info
    Write-SyncLog "Total repositories processed: $($script:Summary.TotalReposProcessed)" -Level Info
    Write-SyncLog "Pull requests created: $($script:Summary.PRsCreated)" -Level Success
    Write-SyncLog "Pull requests updated: $($script:Summary.PRsUpdated)" -Level Success
    Write-SyncLog "Repositories already in sync: $($script:Summary.ReposAlreadyInSync)" -Level Success
    Write-SyncLog "Repositories skipped: $($script:Summary.ReposSkipped)" -Level Warning

    if ($script:Summary.Errors.Count -gt 0) {
        Write-SyncLog "Errors encountered: $($script:Summary.Errors.Count)" -Level Error
        foreach ($error in $script:Summary.Errors) {
            Write-SyncLog "  - $error" -Level Error
        }
    }

    Write-SyncLog "=== Sync Complete ===" -Level Success

} catch {
    Write-SyncLog "Fatal error during sync: $_" -Level Error
    Write-SyncLog $_.ScriptStackTrace -Level Error
    exit 1
}

#endregion
