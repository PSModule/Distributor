---
files:
  - '**/*.yml'
  - '**/*.yaml'
  - 'action.yml'
  - 'action.yaml'
---

# GitHub Actions Instructions

These are centrally managed instructions for developing GitHub Actions in PSModule repositories.

## Guidelines

### Action Structure
- Use semantic versioning for releases (v1.0.0, v1.1.0, etc.)
- Provide clear action.yml metadata with description and inputs
- Include comprehensive README with usage examples
- Add branding icon and color for Marketplace visibility

### Code Quality
- Follow GitHub Actions best practices
- Use TypeScript for JavaScript actions or containers for complex logic
- Include comprehensive testing (unit tests and integration tests)
- Validate all inputs and provide clear error messages

### Documentation
- Document all inputs, outputs, and usage examples
- Include a "Getting Started" section in README
- Add workflow examples showing common use cases
- Keep CHANGELOG updated with each release

### Security
- Pin action dependencies to specific SHAs
- Scan for vulnerabilities regularly
- Follow principle of least privilege for permissions
- Never log sensitive information

### Maintenance
- Keep dependencies up to date
- Respond to issues and PRs in a timely manner
- Mark breaking changes clearly in releases
- Maintain backward compatibility when possible
