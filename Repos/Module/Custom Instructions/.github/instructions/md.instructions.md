---
files:
  - '**/*.md'
  - '**/*.markdown'
---

# Markdown Instructions

These are centrally managed instructions for working with Markdown files in PSModule repositories.

## Guidelines

### Structure and Formatting
- Use proper heading hierarchy (start with h1, don't skip levels)
- Add blank lines before and after headings
- Use fenced code blocks with language identifiers
- Keep line length reasonable (aim for 120 characters or less for readability)

### Code Blocks
- Always specify language for syntax highlighting
- Use ```powershell for PowerShell code
- Use ```yaml for YAML files
- Use ```bash for shell commands

### Links and References
- Use descriptive link text (avoid "click here")
- Prefer relative links for internal documentation
- Verify links are working before committing

### Lists
- Use `-` for unordered lists consistently
- Use `1.` for ordered lists (Markdown will auto-number)
- Indent nested lists with 2 or 4 spaces consistently

### Documentation Standards
- Include a clear title and description at the top
- Add a table of contents for long documents
- Document all parameters, examples, and return values
- Keep examples up to date with code changes

### Linting
- Follow markdown-lint rules defined in the Linter Settings
- Fix all linting errors before committing
- Use consistent formatting throughout the document
