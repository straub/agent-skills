# Common Mistakes & How to Avoid Them

## Table of Contents
1. [Version Matching Contradictions](#version-matching-contradictions)
2. [Grouping Conflicts](#grouping-conflicts)
3. [Docker Naming Issues](#docker-naming-issues)
4. [Post-Upgrade Task Failures](#post-upgrade-task-failures)
5. [Rule Ordering Problems](#rule-ordering-problems)
6. [Configuration Validation](#configuration-validation)

## Version Matching Contradictions

### Mistake: Overlapping `matchCurrentVersion` and `allowedVersions`

**Problem Code:**
```json
{
  "matchPackageNames": ["postgres"],
  "matchCurrentVersion": "^13",
  "allowedVersions": "^14",
  "automerge": true
}
```

**Why it fails**: These matchers contradict each other:
- `matchCurrentVersion` says "only match if current is 13.x"
- `allowedVersions` says "only allow upgrades to 14.x"
- Result: This rule never matches because you can't currently be on ^13 AND upgrade to ^14 in the same rule

**Why it's confusing**: You think you're handling the "upgrade from 13 to 14" case, but Renovate doesn't work that way.

**Fix:**
```json
{
  "description": "PostgreSQL 13→14 migration",
  "matchPackageNames": ["postgres"],
  "matchCurrentVersion": "^13",
  "allowedVersions": "^13",
  "groupName": "PostgreSQL 13.x patches"
}
// Separate rule for 14.x
{
  "description": "PostgreSQL 14.x updates",
  "matchPackageNames": ["postgres"],
  "matchCurrentVersion": "^14",
  "allowedVersions": "^14",
  "groupName": "PostgreSQL 14.x patches",
  "automerge": true
}
```

### Mistake: Using `matchCurrentVersion` When You Mean `matchNewValue`

**Problem Code:**
```json
{
  "matchPackageNames": ["node"],
  "matchCurrentVersion": "^16",
  "automerge": true
}
```

**Why it's wrong**: This rule only applies when the project is currently on Node 16. If you upgrade to 18, new PRs stop matching.

**Intended meaning**: "Allow upgrading TO version 16, auto-merge those PRs."

**Fix:**
```json
{
  "matchPackageNames": ["node"],
  "matchNewValue": "^16",
  "automerge": true
}
```

### Mistake: Null vs 0 for `minimumReleaseAge`

**Problem Code:**
```json
{
  "minimumReleaseAge": null
}
```

**Why it's wrong**: `null` is unpredictable. Different systems interpret it differently.

**Fix:**
```json
{
  "minimumReleaseAge": 0
}
```

For stability days, use a number:
```json
{
  "minimumReleaseAge": "7 days"
}
```

## Grouping Conflicts

### Mistake: Over-Grouping Hides Failures

**Problem Code:**
```json
{
  "groupName": "All dependencies",
  "grouping": "all",
  "automerge": true
}
```

**Why it fails**:
- Groups 50+ unrelated updates into one PR
- If one fails, entire group fails
- Automerge waits for all to pass
- Silent failures: Which package broke CI?
- Difficult to debug which update caused issues

**Real consequence**: From production analysis, over-grouped configurations caused hours of debugging because it wasn't clear which of 20 dependencies broke the build.

**Fix:**
```json
{
  "rules": [
    {
      "description": "Lock files - always together",
      "matchUpdateTypes": ["lockfileUpdate"],
      "groupName": "Lock files",
      "grouping": "all",
      "automerge": true
    },
    {
      "description": "Patches together",
      "matchUpdateTypes": ["patch"],
      "groupName": "Patch updates",
      "grouping": "all",
      "automerge": true
    },
    {
      "description": "Minor updates separate",
      "matchUpdateTypes": ["minor"],
      "automerge": false
    }
  ]
}
```

### Mistake: Group Conflicts with Rate Limiting

**Problem Code:**
```json
{
  "groupName": "All updates",
  "grouping": "all",
  "prConcurrentLimit": 1
}
```

**Why it's confusing**: These settings work against each other:
- Grouping says "put everything in one PR"
- Concurrent limit prevents multiple PRs
- Configuration is contradictory

**Fix**: Either group OR use concurrent limits, not both:
```json
{
  "groupName": "All non-breaking updates",
  "matchUpdateTypes": ["patch", "minor"],
  "grouping": "all"
  // No concurrent limit needed - only one PR
}
```

## Docker Naming Issues

### Mistake: Generic Docker Image Names

**Problem Code:**
```json
{
  "extends": ["config:base"]
}
// Then uses: FROM node:14
```

**Why it's wrong**: Renovate has built-in behavior for official Docker images. `node` is managed by Docker Hub's official library with automatic Renovate support. Your custom config may be ignored.

**Fix: Be Explicit**
```json
{
  "rules": [
    {
      "description": "Custom Node images from our registry",
      "matchDatasources": ["docker"],
      "matchImages": ["ghcr.io/myorg/node"],
      "automerge": true,
      "schedule": ["before 3am"]
    },
    {
      "description": "Official Docker images (allow built-in defaults)",
      "matchDatasources": ["docker"],
      "matchImages": ["node", "postgres"],
      "automerge": false,
      "schedule": ["weekly"]
    }
  ]
}
```

### Mistake: Registry Assumptions

**Problem Code:**
```json
{
  "matchImages": ["myimage:latest"],
  "automerge": true
}
```

**Why it fails**: Renovate assumes Docker Hub. If your image is in a private registry, this fails silently.

**Fix:**
```json
{
  "matchImages": ["ghcr.io/myorg/myimage"],
  "registryAliases": {
    "gcr.io": "ghcr.io"
  },
  "automerge": true
}
```

## Post-Upgrade Task Failures

### Mistake: Assuming Post-Upgrade Tasks Run

**Problem Code:**
```json
{
  "postUpgradeTasks": {
    "commands": ["npm run migrate"],
    "filePattern": "src/migrations/*.js"
  }
}
```

**Why it might fail**:
- Task fails silently if script doesn't exist
- No error logs visible in PR
- Migration might have already run
- Script might have permission issues

**Fix: Add Error Handling**
```json
{
  "postUpgradeTasks": {
    "commands": ["npm run migrate || true"],
    "filePattern": "src/migrations/*.js"
  },
  "postUpdateOptions": ["npmDedupe"]
}
```

### Mistake: Complex Migrations Without Testing

**Problem Code:**
```json
{
  "postUpgradeTasks": {
    "commands": [
      "sed -i 's/oldAPI/newAPI/g' src/**/*.js",
      "npm run lint",
      "npm test"
    ]
  }
}
```

**Why it's risky**:
- Sed replacement might match unintended code
- No rollback if script fails
- Testing happens in PR, not locally first

**Fix: Test Locally First**
```bash
# Test locally with new version
npm install newpackage@2.0.0
npm run migrate  # Test your post-upgrade script
git diff  # Verify changes
```

Then add to config with monitoring:
```json
{
  "postUpgradeTasks": {
    "commands": [
      "npm run migrate:newpackage"
    ]
  },
  "labels": ["requires-review"],
  "assignees": ["@oncall"]
}
```

## Rule Ordering Problems

### Mistake: Rules Processed Bottom-Up (Actually Oldest First)

**Problem Code:**
```json
{
  "rules": [
    {
      "description": "Rule 2",
      "matchUpdateTypes": ["major"],
      "automerge": false
    },
    {
      "description": "Rule 1",
      "matchUpdateTypes": ["major"],
      "automerge": true
    }
  ]
}
```

**Why it's confusing**: Rules are applied in order, but Renovate uses a config merge strategy, not first-match. So rule ordering can be non-obvious.

**Why it fails**: You expect Rule 1 to override Rule 2, but depending on specificity, Rule 2 might take precedence.

**Fix: Be Explicit with Specificity**
```json
{
  "rules": [
    {
      "description": "Very specific: postgres major updates never automerge",
      "matchPackageNames": ["postgres"],
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "priority": 10
    },
    {
      "description": "Specific: internal packages always automerge",
      "matchPackagePatterns": ["^@myorg/"],
      "matchUpdateTypes": ["major"],
      "automerge": true,
      "priority": 5
    },
    {
      "description": "Default: major updates no automerge",
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "priority": 0
    }
  ]
}
```

## Configuration Validation

### Mistake: Not Running Validator in CI

**Problem**: Configuration errors surface hours later when Renovate runs, not when you commit.

**Fix: Add to CI Pipeline**
```yaml
# .github/workflows/validate.yml
name: Validate Renovate Config
on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate Renovate configuration
        run: npx renovate-config-validator
```

This catches:
- Typos in field names
- Invalid preset references
- Syntax errors
- Contradictory rules

### Mistake: Using Presets Without Verifying They Exist

**Problem Code:**
```json
{
  "extends": [
    "config:base",
    "config:nonexistent-preset"
  ]
}
```

**Why it fails**: Nonexistent presets are silently ignored. Your config doesn't apply as intended.

**Fix: Verify in CI**
```bash
renovate-config-validator
# Will report: "Preset 'config:nonexistent-preset' not found"
```

### Common Configuration Typos

**Typo Examples**:
- `automergeType` vs `automergeType` (correct)
- `groupName` vs `groupname` (wrong)
- `matchPackageNames` vs `matchPackageName` (wrong)
- `postUpgradeTasks` vs `postUpdateTasks` (wrong in old versions)

**Fix**: Always validate:
```bash
renovate-config-validator renovate.json
```

## Summary: Red Flags in Your Config

Before committing, check for these red flags:

```json
{
  // ❌ Red flag: matchCurrentVersion AND allowedVersions together
  "matchCurrentVersion": "^13",
  "allowedVersions": "^14",

  // ❌ Red flag: grouping: all with 50+ dependencies
  "grouping": "all",

  // ❌ Red flag: matchCurrentVersion without specific version
  "matchCurrentVersion": "*",

  // ❌ Red flag: null values (use 0 or explicit string)
  "minimumReleaseAge": null,

  // ❌ Red flag: postUpgradeTasks without local testing
  "postUpgradeTasks": { "commands": [...] },

  // ❌ Red flag: generic Docker image names without explicit registry
  "matchImages": ["node"],

  // ✅ Good: Specific matchers with clear intent
  "matchPackageNames": ["postgres"],
  "matchNewValue": "^14",
  "automerge": true
}
```
