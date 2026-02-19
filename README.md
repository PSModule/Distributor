# Distributor

A central repository for distributing and syncing shared files across multiple repositories in the PSModule organization.

## Overview

The Distributor service maintains a centralized collection of files that are automatically synced to subscribing repositories in the PSModule organization. This ensures consistency across repositories for configuration files, linter settings, documentation templates, GitHub Actions workflows, and other shared resources.

## How It Works

### Convention-Based Structure

Files are organized in a **two-level folder hierarchy** under the `Repos/` directory:

```
Repos/{Type}/{Selection}/
```

- **Type** (first level): Groups repositories by their kind (Module, Action, Template, Workflow, etc.)
- **Selection** (second level): Individual file sets that repositories can subscribe to
- Each selection folder mimics the root of a target repository

### Subscription Model

Repositories subscribe to file sets using **two custom properties** defined at the organization level:

| Property | Type | Description |
|----------|------|-------------|
| `Type` | Single-select | Determines which type folder to use (Module, Action, Template, Workflow, Docs, Other) |
| `SubscribeTo` | Multi-select | Determines which file sets to receive (Custom Instructions, Linter Settings, License, etc.) |

Repositories self-manage their subscriptions by setting these custom property values.

### Sync Process

A scheduled GitHub Actions workflow runs daily and:

1. Discovers available file sets from the `Repos/` directory structure
2. Queries all organization repositories for their subscription preferences
3. For each subscribing repository:
   - Clones the repository
   - Copies files from the subscribed file sets
   - Detects changes using git
   - Creates or updates a pull request if changes are detected
4. Outputs a summary of actions taken

### Pull Request Lifecycle

When changes are detected, the workflow creates a pull request with:

- **Title**: `⚙️ [Maintenance]: Sync managed files`
- **Label**: `NoRelease`
- **Branch**: `managed-files/update`
- **Description**: Explains that files are centrally managed

If a PR already exists from a previous sync, the workflow updates it by force-pushing to the existing branch.

## Repository Structure

```
Distributor/
├── Repos/                          # File sets organized by type and selection
│   ├── Module/                     # Files for PowerShell modules
│   │   ├── Custom Instructions/    # Copilot instructions
│   │   ├── Linter Settings/        # Linter configurations
│   │   ├── PSModule Settings/      # PSModule-specific configs
│   │   ├── .gitattributes/         # Git attributes
│   │   ├── .gitignore/             # Git ignore patterns
│   │   └── License/                # License file
│   ├── Action/                     # Files for GitHub Actions
│   │   ├── Custom Instructions/
│   │   ├── .gitattributes/
│   │   ├── .gitignore/
│   │   └── License/
│   ├── Template/                   # Files for repository templates
│   └── Workflow/                   # Files for reusable workflows
├── scripts/
│   └── Sync-Files.ps1             # Main sync script
└── .github/
    └── workflows/
        └── sync-files.yml         # Scheduled workflow
```

## Adding New File Sets

To add a new file set:

1. **Add the selection value** to the `SubscribeTo` custom property definition in the organization settings
2. **Create a new folder** under the appropriate type: `Repos/{Type}/{SelectionName}/`
3. **Add files** to the folder, organizing them as they should appear in target repositories
4. Commit and push the changes
5. The next scheduled sync will distribute these files to subscribing repositories

### Example: Adding a new "CODEOWNERS" file set

```bash
# 1. Add "CODEOWNERS" to the SubscribeTo custom property in GitHub organization settings

# 2. Create the folder structure
mkdir -p "Repos/Module/CODEOWNERS/.github"

# 3. Add the CODEOWNERS file
cat > "Repos/Module/CODEOWNERS/.github/CODEOWNERS" << 'EOF'
# Default owners for everything
* @PSModule/maintainers

# Specific paths
/.github/ @PSModule/infrastructure
EOF

# 4. Commit and push
git add Repos/Module/CODEOWNERS/
git commit -m "Add CODEOWNERS file set for modules"
git push
```

## Subscribing Repositories

Repository owners can subscribe to file sets by setting their repository's custom properties:

1. Go to the repository settings
2. Navigate to the **Custom properties** section
3. Set the **Type** property (e.g., "Module")
4. Select one or more **SubscribeTo** values (e.g., "Linter Settings", "License")
5. Save the changes

On the next scheduled sync (or manual trigger), the repository will receive a pull request with the selected files.

## Important Behaviors

### File Creation and Updates

- The sync process **creates new files** and **overwrites existing files**
- Files are forcefully synchronized to match the source
- Local changes to managed files will be overwritten

### File Deletion

- Files are **never deleted** from target repositories
- If a file is removed from a file set, the previously synced copy remains in target repos but is no longer managed
- Manual cleanup is required if you want to remove files from target repositories

### Change Detection

- The workflow only creates PRs when git detects actual changes
- Repositories already in sync are skipped (no empty PRs)
- Only changed files are included in commits

### Existing PRs

- If a `managed-files/update` branch already exists, the workflow force-pushes to update it
- This updates the existing PR rather than creating duplicates
- Review and merge the PR to complete the sync

## Workflow Triggers

The sync workflow runs:

- **Daily** at 06:00 UTC (scheduled via cron)
- **Manually** via workflow_dispatch in the GitHub Actions UI

## GitHub App Requirements

The workflow uses the **PSModule's Custo** GitHub App with the following permissions:

| Permission | Access | Purpose |
|------------|--------|---------|
| `contents` | Write | Clone repos, push branches |
| `pull_requests` | Write | Create PRs, apply labels |
| `repository_custom_properties` | Read | Read subscription preferences |
| `metadata` | Read | Repository information |

### Required Secrets

The following secrets must be configured in this repository:

- `CUSTO_BOT_CLIENT_ID`: The GitHub App's client ID
- `CUSTO_BOT_PRIVATE_KEY`: The GitHub App's private key (PEM format)

## Troubleshooting

### Repository not receiving files

1. Verify the repository has both `Type` and `SubscribeTo` custom properties set
2. Check that the `Type` value matches a folder under `Repos/`
3. Check that each `SubscribeTo` value has a corresponding folder under `Repos/{Type}/`
4. Review the workflow logs for warnings or errors

### Files not updating

1. Check if the repository already has an open PR from the `managed-files/update` branch
2. Verify that the source files in `Repos/` have actually changed
3. Check the workflow logs for the repository in question

### Workflow failures

1. Review the workflow run logs in the Actions tab
2. Check that the GitHub App credentials are valid
3. Verify that the GitHub App has the required permissions
4. Ensure the GitHub App is installed on the target repositories

## Development and Testing

To test changes locally:

```bash
# Install the GitHub PowerShell module
Install-Module -Name GitHub -Force

# Authenticate (using a PAT for local testing)
$env:GITHUB_TOKEN = 'your-pat-here'
Connect-GitHub

# Run the sync script
./scripts/Sync-Files.ps1
```

## License

MIT License - See LICENSE file for details
