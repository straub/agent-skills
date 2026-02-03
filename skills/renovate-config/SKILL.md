---
name: renovate-config
description: "Comprehensive guide for Renovate configuration, preset creation, and dependency update automation. Use when working with Renovate to: (1) Create or modify renovate.json configurations, (2) Design and implement custom presets, (3) Optimize dependency update strategies, (4) Set up automerge rules and scheduling, (5) Configure manager-specific settings, (6) Implement custom rules and grouping strategies, or (7) Troubleshoot Renovate behavior and configuration issues."
license: Complete terms in LICENSE.txt
---

# Renovate Configuration Skill

Renovate is a powerful bot for automating dependency updates. This skill provides practical workflows for designing effective configurations, avoiding common pitfalls, and implementing best practices.

## Quick Start: Configuration Structure

Renovate configurations consist of:
1. **Base config** (renovate.json) - Root configuration file
2. **Presets** - Reusable configuration templates
3. **Rules** - Condition-based config overrides (matcher + settings)
4. **Managers** - Package manager-specific settings (npm, docker, maven, etc.)

Basic structure:
```json
{
  "extends": ["config:base"],
  "schedule": ["before 3am on Monday"],
  "automerge": true,
  "automergeType": "pr",
  "grouping": {
    "minor": {},
    "major": {}
  }
}
```

## Core Workflows

### 1. Design Automerge Strategy (Pyramid Approach)

Renovate's most powerful feature is automerge. Structure it as a pyramid of confidence levels:

**Level 1 - Always merge** (highest confidence):
- Lock files (package-lock.json, yarn.lock, etc.)
- Internal packages from your organization
- Patch updates to core dependencies

**Level 2 - Merge with constraints**:
- Dependencies with passing CI + test coverage
- Developmental dependencies (devDeps)
- Minor updates to stable packages

**Level 3 - Create PR, no merge**:
- Major version updates
- Breaking changes
- Unproven packages

Implementation:
```json
{
  "automerge": true,
  "automergeType": "pr",
  "rules": [
    {
      "description": "Lock files - always merge",
      "matchUpdateTypes": ["lockfileUpdate"],
      "automerge": true,
      "automergeType": "squash"
    },
    {
      "description": "Internal packages - always merge",
      "matchPackagePatterns": ["^@myorg/"],
      "automerge": true
    },
    {
      "description": "Major updates - create PR only",
      "matchUpdateTypes": ["major"],
      "automerge": false
    }
  ]
}
```

### 2. Implement Version Matching Rules

**Critical**: Avoid overlapping matchers or contradictory rules.

**Best practice: Use `matchNewValue` to target upgrade destinations**:
```json
{
  "description": "Allow specific major versions",
  "matchPackageNames": ["postgres"],
  "matchNewValue": "^(13|14|15)",
  "automerge": true
}
```

**Avoid this pattern** (conflicting matchers):
```json
{
  "matchCurrentVersion": "^13",
  "allowedVersions": "^14",
  "automerge": true
}
```

### 3. Configure Scheduling

Scheduling prevents noise and coordinator overload:

```json
{
  "schedule": [
    "before 3am on Monday",
    "before 3am on Wednesday",
    "before 3am on Friday"
  ],
  "timezone": "UTC"
}
```

Key patterns:
- Small projects: Once per week
- Active projects: 2-3x per week
- Enterprise: Daily but staggered times
- Use cron for precise timing: `"0 3 * * 1"` (3am Mondays)

### 4. Handle Docker Image Updates

Docker naming conventions conflict with Renovate defaults. Avoid generic names (`node`, `postgres`) unless you want Renovate's built-in behavior.

**Recommendation: Always specify image source explicitly**:
```json
{
  "description": "Custom Docker registries",
  "matchDatasources": ["docker"],
  "matchImages": ["ghcr.io/myorg/.*"],
  "automerge": true,
  "schedule": ["before 3am"]
}
```

### 5. Manage Breaking Changes

When a dependency has breaking changes across major versions, maintain separate presets:

```json
{
  "description": "TypeScript 4.x settings",
  "matchPackageNames": ["typescript"],
  "matchCurrentVersion": "^3",
  "config": {
    "allowedVersions": "^4",
    "postUpgradeTasks": {
      "commands": ["npm run migrate:ts4"]
    }
  }
}
```

## Configuration Validation

**CRITICAL**: Always validate configurations in CI before merging.

```bash
renovate-config-validator
```

This catches:
- Syntax errors
- Invalid field names
- Conflicting rules
- Preset reference errors

## Common Mistakes to Avoid

See [MISTAKES.md](references/MISTAKES.md) for detailed analysis of:
- Version matching contradictions
- Over-grouping and grouping conflicts
- Docker naming issues
- Post-upgrade task failures
- Rule ordering problems

## Best Practices & Patterns

See [BEST-PRACTICES.md](references/BEST-PRACTICES.md) for:
- Automerge strategies (pyramid approach)
- Configuration organization for complex repositories
- Preset design patterns
- Monorepo specific configurations
- Noise reduction techniques
- Performance optimization

## Advanced Configuration Reference

See [ADVANCED.md](references/ADVANCED.md) for comprehensive coverage of:
- All configuration options by category
- Manager-specific configurations (npm, docker, go, python, maven, etc.)
- Conditional logic and custom rules
- Post-upgrade tasks and automation
- Custom datasources and integrations
- Dependency dashboard configuration

## Decision Tree: When to Use Features

**Question: Do you want automatic merging?**
- Yes → Configure automerge pyramid (see Core Workflows #1)
- No → Set `"automerge": false`, create PRs only

**Question: Are you managing breaking changes?**
- Yes → Use separate rule blocks per major version (see Core Workflows #5)
- No → Use simple matchUpdateTypes rules

**Question: Is configuration getting complex?**
- Yes → Break into presets and organize by domain
- No → Keep single renovate.json

**Question: Multiple languages/managers?**
- Yes → Use manager-specific rules in rules array
- No → Use extends for base configuration

## Workflow: Creating a New Configuration

1. Start with `"extends": ["config:base"]` - builds on official defaults
2. Add scheduling to reduce noise
3. Define automerge rules (pyramid approach)
4. Test with dry-run: `renovate --dry-run`
5. Validate: `renovate-config-validator`
6. Deploy and monitor first PRs
7. Adjust based on CI results and team feedback

## Workflow: Troubleshooting Configuration Issues

1. Check validation: `renovate-config-validator`
2. Review rule matching: Add `"debugMode": true` to see matching details
3. Check rule ordering: Rules are applied top-to-bottom, first match wins
4. Verify presets are available: Confirm preset paths/references
5. Test individual rules with dry-run
6. Compare with reference implementations (see assets/)

## Real-World Configuration Templates

See `assets/` for tested configuration templates:
- Minimal configuration for small projects
- Enterprise configuration with complex rules
- Monorepo configuration
- Docker-heavy application configuration
- Post-upgrade automation examples

## Reference Implementation Analysis

Production Renovate configurations from mature projects show:

Key lessons from production:
- Modular preset organization scales better than monolithic configs
- Post-upgrade tasks enable powerful automation (code migrations, sed replacements)
- Match by source URL for internal packages (more reliable than name patterns)
- Maintenance and lock file updates represent ~50% of activity
- Configuration validation is essential to prevent silent failures

## Integration with CI/CD

Renovate works alongside your CI/CD:
- Renovate creates PRs with dependency changes
- Your CI runs tests on those PRs
- Automerge happens only if CI passes (when enabled)
- Branch protection rules must allow Renovate to merge
- Use `"ignoreTests": true` to override CI results (use sparingly)

## Configuration Inheritance & Extends

Renovate's `extends` field allows building on presets:

```json
{
  "extends": [
    "config:base",
    "schedule:weekly",
    "docker:enableMajor"
  ]
}
```

Official presets are in `config:`, `schedule:`, and manager-specific namespaces. Custom org presets follow `local>` prefix for file-based or hosted on GitHub.

---

For detailed reference material, see the `references/` directory:
- **BEST-PRACTICES.md** - Patterns, strategies, and production lessons
- **MISTAKES.md** - Common pitfalls and how to avoid them
- **ADVANCED.md** - Comprehensive configuration reference
