# GitHub Copilot Hooks

This directory contains GitHub Copilot agent hooks that are triggered at various lifecycle events during a Copilot session.

## What Are Copilot Hooks?

Copilot hooks are event-driven automation scripts that run at specific points in a GitHub Copilot agent or CLI session. They enable you to:
- Audit and log Copilot usage for compliance
- Initialize or cleanup session resources
- Enforce organizational policies
- Integrate with external systems
- Track usage analytics

## Configuration

Hooks are configured in the `hooks.json` file, which defines which scripts to execute for each event type.

### Available Events

- **sessionStart**: Triggered when a Copilot agent session begins
- **sessionEnd**: Triggered when a Copilot agent session ends
- **userPromptSubmitted**: Triggered each time a user submits a prompt

## Hook Scripts

This file set includes example scripts for all three events:

### Session Start
- `scripts/session-start.sh` (Bash)
- `scripts/session-start.ps1` (PowerShell)

Receives JSON input with `timestamp`, `source` (new/resume), and optional `initialPrompt`.

### Session End
- `scripts/session-end.sh` (Bash)
- `scripts/session-end.ps1` (PowerShell)

Receives JSON input with `timestamp` and `reason` (complete/error/abort/timeout/user_exit).

### User Prompt Submitted
- `scripts/log-prompt.sh` (Bash)
- `scripts/log-prompt.ps1` (PowerShell)

Receives JSON input with `timestamp` and `prompt` (the user's submitted text).

## Customization

These are example scripts that demonstrate the basic structure. Customize them for your needs:

1. **Auditing**: Log prompts and session data to files or external systems
2. **Policy enforcement**: Validate prompts against organizational policies
3. **Analytics**: Track usage patterns and metrics
4. **Integration**: Connect to logging services, databases, or monitoring tools

## Learn More

- [GitHub Copilot Hooks Documentation](https://docs.github.com/en/copilot/reference/hooks-configuration)
- [Using hooks with GitHub Copilot agents](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/use-hooks)
