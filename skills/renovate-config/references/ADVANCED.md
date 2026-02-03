# Advanced Configuration Reference

## Table of Contents
1. [Configuration Options by Category](#configuration-options-by-category)
2. [Manager-Specific Configurations](#manager-specific-configurations)
3. [Custom Rules & Conditional Logic](#custom-rules--conditional-logic)
4. [Post-Upgrade Tasks & Automation](#post-upgrade-tasks--automation)
5. [Custom Datasources & Integrations](#custom-datasources--integrations)
6. [Dependency Dashboard Configuration](#dependency-dashboard-configuration)

## Configuration Options by Category

### Scheduling Options

Control when Renovate checks and creates PRs:

```json
{
  "schedule": [
    "before 3am on Monday",
    "before 3am on Wednesday",
    "before 3am on Friday"
  ],
  "timezone": "UTC",
  "extends": ["schedule:monthly"]
}
```

**Common patterns**:
- `"before 3am on Monday"` - weekly check
- `"0 3 * * 1,3,5"` - cron format (3am Mon/Wed/Fri)
- `"0 0 1 * *"` - monthly (1st of month)
- `"at any time"` - no schedule limit (for security patches)

**Official presets**:
- `schedule:weekly` - 3am Mondays
- `schedule:monthly` - 1st of month
- `schedule:quarterly` - 1st of Jan/Apr/Jul/Oct
- `schedule:daily` - 3am every day

### Automerge Options

Control automatic merging behavior:

```json
{
  "automerge": true,
  "automergeType": "pr",
  "automergeStrategy": "squash",
  "autoApprove": false,
  "ignoreTests": false
}
```

**automergeType options**:
- `"pr"` - Wait for status checks to pass (default, safest)
- `"squash"` - Squash and merge after checks pass
- `"rebase"` - Rebase and merge
- `"fast-forward"` - Fast-forward merge only

**Requirements for automerge**:
```json
{
  "automerge": true,
  "require": [
    "status-success",
    "branch-protection"
  ]
}
```

### Dependency Pinning & Versioning

```json
{
  "rangeStrategy": "auto",
  "semanticCommits": "enabled",
  "semanticCommitType": "chore",
  "semanticCommitScope": "deps",
  "lockFileMaintenance": {
    "enabled": true,
    "schedule": ["before 3am on Monday"]
  }
}
```

**rangeStrategy options**:
- `"auto"` - Infer from current usage (recommended)
- `"pin"` - Remove ranges, use exact versions
- `"bump"` - Update to highest compatible
- `"replace"` - Replace range with new version
- `"widen"` - Widen range if new version outside it
- `"update-lockfile"` - Update lock file only

### PR Management

```json
{
  "prConcurrentLimit": 5,
  "prCreationLimit": 10,
  "prBodyColumns": ["Package", "Type", "Update", "Change"],
  "prTitle": "chore(deps): update {{depName}} to {{newVersion}}",
  "prBodyTemplate": "## Updates\\n\\n{{{table}}}",
  "commitMessagePrefix": "[automated]"
}
```

**Useful PR options**:
- `prConcurrentLimit` - Max open PRs at once
- `prCreationLimit` - Max PRs created per Renovate run
- `semanticCommits` - Use conventional commits
- `prBodyColumns` - Customize PR table columns

### Version Constraints

```json
{
  "minimumReleaseAge": "3 days",
  "rollbackPrs": true,
  "rollback": {
    "enabled": true
  }
}
```

**minimumReleaseAge**: Wait N days after release before updating (prevents early-stage bugs)

- `"0 days"` - Update immediately
- `"3 days"` - Wait 3 days (good default for stability)
- `"7 days"` - Wait a week (conservative)

### Extension & Inheritance

```json
{
  "extends": [
    "config:base",
    "config:npm-strict",
    "schedule:weekly",
    "docker:enableMajor",
    "local>renovate/custom"
  ]
}
```

**Official namespaces**:
- `config:` - Configuration presets
- `schedule:` - Scheduling presets
- `docker:` - Docker-specific presets
- `npm:` - NPM-specific presets
- `local>` - Local file-based presets

## Manager-Specific Configurations

### NPM Configuration

```json
{
  "npm": {
    "enabled": true,
    "rangeStrategy": "auto",
    "lockFileMaintenance": {
      "enabled": true,
      "schedule": ["before 3am on Monday"]
    }
  },
  "rules": [
    {
      "matchDatasources": ["npm"],
      "matchDepTypes": ["dependencies"],
      "groupName": "Production dependencies",
      "automerge": false
    },
    {
      "matchDatasources": ["npm"],
      "matchDepTypes": ["devDependencies"],
      "groupName": "Dev dependencies",
      "automerge": true,
      "schedule": ["weekly"]
    }
  ]
}
```

### Docker Configuration

```json
{
  "docker": {
    "enabled": true,
    "automerge": true,
    "automergeType": "squash",
    "schedule": ["before 3am on Monday"]
  },
  "rules": [
    {
      "matchDatasources": ["docker"],
      "matchImages": ["ghcr.io/myorg/.*"],
      "automerge": true
    },
    {
      "matchDatasources": ["docker"],
      "matchImages": ["postgres", "redis"],
      "minimumReleaseAge": "7 days",
      "automerge": false
    }
  ]
}
```

### Python Configuration

```json
{
  "python": {
    "enabled": true,
    "rangeStrategy": "auto"
  },
  "rules": [
    {
      "matchDatasources": ["pypi"],
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "schedule": ["weekly"]
    },
    {
      "matchDatasources": ["pypi"],
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true
    }
  ]
}
```

### Go Configuration

```json
{
  "go": {
    "enabled": true,
    "rangeStrategy": "auto"
  },
  "rules": [
    {
      "matchDatasources": ["go"],
      "groupName": "Go dependencies",
      "automerge": true,
      "schedule": ["weekly"]
    }
  ]
}
```

### Maven Configuration

```json
{
  "maven": {
    "enabled": true
  },
  "rules": [
    {
      "matchDatasources": ["maven"],
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "labels": ["breaking-change"]
    }
  ]
}
```

## Custom Rules & Conditional Logic

### Pattern Matching Rules

```json
{
  "rules": [
    {
      "description": "Scoped packages from org",
      "matchPackagePatterns": ["^@myorg/.*"],
      "automerge": true
    },
    {
      "description": "Avoid specific packages",
      "excludePackagePatterns": ["@deprecated/.*"],
      "automerge": false
    },
    {
      "description": "Match by source URL",
      "matchSourceUrl": "github.com/myorg/.*",
      "automerge": true
    }
  ]
}
```

### Dependency Type Matching

```json
{
  "rules": [
    {
      "description": "Production dependencies",
      "matchDepTypes": ["dependencies"],
      "automerge": false
    },
    {
      "description": "Dev dependencies",
      "matchDepTypes": ["devDependencies", "devDeps"],
      "automerge": true
    },
    {
      "description": "Peer dependencies",
      "matchDepTypes": ["peerDependencies"],
      "automerge": false
    },
    {
      "description": "Optional dependencies",
      "matchDepTypes": ["optionalDependencies"],
      "automerge": true
    }
  ]
}
```

### Update Type Matching

```json
{
  "rules": [
    {
      "description": "Patch updates",
      "matchUpdateTypes": ["patch"],
      "automerge": true
    },
    {
      "description": "Minor updates",
      "matchUpdateTypes": ["minor"],
      "automerge": true
    },
    {
      "description": "Major updates",
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "labels": ["breaking-change"]
    },
    {
      "description": "Digest updates",
      "matchUpdateTypes": ["digest"],
      "groupName": "Digest updates",
      "automerge": true
    }
  ]
}
```

### Datasource Matching

```json
{
  "rules": [
    {
      "matchDatasources": ["npm"],
      "automerge": true
    },
    {
      "matchDatasources": ["docker"],
      "automerge": false,
      "schedule": ["weekly"]
    },
    {
      "matchDatasources": ["pypi"],
      "automerge": true
    },
    {
      "matchDatasources": ["golang"],
      "automerge": true
    }
  ]
}
```

### Path-Based Rules (Monorepo)

```json
{
  "rules": [
    {
      "matchPaths": ["packages/core/**"],
      "automerge": false,
      "require": ["status-success"]
    },
    {
      "matchPaths": ["packages/ui/**"],
      "automerge": true,
      "schedule": ["weekly"]
    },
    {
      "matchPaths": ["examples/**"],
      "automerge": true
    }
  ]
}
```

## Post-Upgrade Tasks & Automation

### Running Commands After Update

```json
{
  "postUpgradeTasks": {
    "commands": [
      "npm run lint --fix",
      "npm run test"
    ],
    "filePattern": "src/**/*.js"
  }
}
```

### Post-Update Options

```json
{
  "postUpdateOptions": [
    "gomodTidy",
    "yarnDedupeHighest",
    "npmDedupe",
    "pnpmDedupe",
    "branchProtectionAutomerge"
  ]
}
```

### Common Post-Upgrade Tasks

**Code migrations**:
```json
{
  "postUpgradeTasks": {
    "commands": [
      "npm run migrate:api-v2"
    ]
  }
}
```

**Dependency deduplication**:
```json
{
  "postUpdateOptions": ["npmDedupe", "yarnDedupeHighest"]
}
```

**Code formatting**:
```json
{
  "postUpgradeTasks": {
    "commands": [
      "npm run lint --fix",
      "npm run format"
    ]
  }
}
```

**Lock file updates**:
```json
{
  "postUpdateOptions": ["gomodTidy"],
  "lockFileMaintenance": {
    "enabled": true,
    "schedule": ["before 3am on Monday"]
  }
}
```

## Custom Datasources & Integrations

### Custom Datasource Configuration

```json
{
  "customDatasources": {
    "myCompanyPackages": {
      "defaultRegistryUrlTemplate": "https://registry.mycompany.com/v1/packages/{{{package}}}",
      "format": "json",
      "homepage": "https://registry.mycompany.com"
    }
  },
  "rules": [
    {
      "matchDatasources": ["custom.myCompanyPackages"],
      "automerge": true,
      "schedule": ["daily"]
    }
  ]
}
```

### HTTP Registry Configuration

```json
{
  "npmrc": "registry=https://private-registry.mycompany.com/",
  "rules": [
    {
      "matchDatasources": ["npm"],
      "matchSourceUrl": "https://private-registry.mycompany.com",
      "automerge": true
    }
  ]
}
```

## Dependency Dashboard Configuration

### Enable Dashboard

```json
{
  "dependencyDashboard": true,
  "dependencyDashboardTitle": "🤖 Dependency Dashboard",
  "dependencyDashboardAutoclose": false,
  "dependencyDashboardProtection": {
    "approvalRequired": true
  }
}
```

### Dashboard Content

The dashboard shows:
- All pending updates
- Status of each update (automerge candidate, blocked, etc.)
- Links to individual PRs
- Overall dependency health

### Using Dashboard for Noise Reduction

Instead of creating 50 individual PRs:
1. Create initial PR with updates grouped
2. Enable dependency dashboard
3. Team reviews dashboard for overview
4. Individual PRs created on schedule
5. Team clicks checkbox to enable/disable specific updates

```json
{
  "dependencyDashboard": true,
  "schedule": ["before 3am on Monday"],
  "grouping": "none"
}
```

## Advanced Grouping Strategies

### Group by Dependency Type

```json
{
  "grouping": [
    {
      "description": "Group testing dependencies",
      "matchDepTypes": ["devDependencies"],
      "groupName": "Dev dependency updates"
    },
    {
      "description": "Group internal packages",
      "matchPackagePatterns": ["^@myorg/"],
      "groupName": "Internal packages"
    }
  ]
}
```

### Group by Semver

```json
{
  "grouping": [
    {
      "description": "Group patches",
      "matchUpdateTypes": ["patch"],
      "groupName": "Patch updates"
    },
    {
      "description": "Group minors",
      "matchUpdateTypes": ["minor"],
      "groupName": "Minor updates"
    }
  ]
}
```

### Group by Business Concern

```json
{
  "grouping": [
    {
      "description": "Security-critical packages",
      "matchLabels": ["security"],
      "groupName": "Security updates",
      "schedule": ["at any time"],
      "automerge": true
    },
    {
      "description": "Compliance-related",
      "matchLabels": ["compliance"],
      "groupName": "Compliance updates",
      "schedule": ["monthly"],
      "automerge": false
    }
  ]
}
```

## Debugging & Advanced Monitoring

### Enable Debug Mode

```json
{
  "debugMode": true,
  "debugLog": true,
  "logLevel": "debug"
}
```

Output shows:
- Matching rules for each dependency
- Why updates were/weren't created
- Configuration resolution
- Datasource queries

### Repository Data Caching

```json
{
  "persistRepoData": true,
  "cacheTtlDays": 30
}
```

Performance optimization: Renovate caches repository structure and dependency data between runs.

### Conflict Resolution

```json
{
  "conflictResolution": "base",
  "resolveLockFiles": true,
  "lockFileMaintenance": {
    "enabled": true
  }
}
```

When dependencies conflict, Renovate can:
- Keep base version (conservative)
- Use new version (aggressive)
- Regenerate lock file

---

For more details, refer to official docs:
- Configuration options: https://docs.renovatebot.com/configuration-options/
- Presets: https://docs.renovatebot.com/config-presets/
