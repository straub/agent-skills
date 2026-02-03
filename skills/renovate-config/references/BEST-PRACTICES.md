# Best Practices & Patterns

## Table of Contents
1. [Automerge Strategies](#automerge-strategies)
2. [Configuration Organization](#configuration-organization)
3. [Preset Design Patterns](#preset-design-patterns)
4. [Monorepo Configurations](#monorepo-configurations)
5. [Noise Reduction Techniques](#noise-reduction-techniques)
6. [Performance Optimization](#performance-optimization)
7. [Production Lessons](#production-lessons)

## Automerge Strategies

### The Automerge Pyramid

The most effective automerge strategy uses tiered confidence levels:

```
                    ▲
                   /|\
                  / | \
                 /  |  \  Major updates (create PR, no merge)
                /   |   \
               /----|----\
              /     |     \  Tested dependencies & minors
             /      |      \
            /-------|-------\
           /        |        \ Internal packages & patches
          /         |         \
         /__________|__________\
        Lock files (always merge)
```

**Tier 1 - Lock Files (Always Merge)**
- Dependency: lock files (package-lock.json, yarn.lock, Podfile.lock)
- Action: Auto-squash merge immediately
- Rationale: Lock file updates are low-risk, high-frequency

```json
{
  "description": "Lock file updates",
  "matchUpdateTypes": ["lockfileUpdate"],
  "automerge": true,
  "automergeType": "squash",
  "schedule": ["at any time"]
}
```

**Tier 2 - Internal & Patch Updates**
- Dependencies: Your organization's internal packages, patches to core deps
- Action: Auto-merge if CI passes
- Rationale: Your control + tested releases

```json
{
  "description": "Internal packages",
  "matchPackagePatterns": ["^@myorg/"],
  "automerge": true,
  "automergeType": "squash",
  "require": ["status-success"]
}
```

**Tier 3 - Devops & Testing Tools**
- Dependencies: devDeps, testing frameworks, build tools
- Action: Auto-merge if tests pass
- Rationale: Breaking changes unlikely to affect production

```json
{
  "description": "Development dependencies",
  "matchDepTypes": ["devDependencies"],
  "matchUpdateTypes": ["minor", "patch"],
  "automerge": true,
  "require": ["status-success"]
}
```

**Tier 4 - Production Dependencies**
- Dependencies: Major versions, untested packages
- Action: Create PR only, review manually
- Rationale: Higher risk of breaking changes

```json
{
  "description": "Production major updates",
  "matchUpdateTypes": ["major"],
  "automerge": false,
  "schedule": ["weekly"]
}
```

### Multi-Rule Coordination

When using multiple rules, maintain clear priority/hierarchy:

```json
{
  "rules": [
    {
      "description": "Highest priority: security patches",
      "groupName": "Security patches",
      "schedule": ["at any time"],
      "labels": ["security"],
      "automerge": true
    },
    {
      "description": "Second priority: internal packages",
      "matchPackagePatterns": ["^@myorg/"],
      "automerge": true,
      "automergeType": "squash"
    },
    {
      "description": "Default: create PR for review",
      "automerge": false
    }
  ]
}
```

## Configuration Organization

### Small Project (Single File)
For projects with <5 active dependencies, single renovate.json is fine:

```json
{
  "extends": ["config:base"],
  "schedule": ["before 3am on Monday"],
  "automerge": true,
  "automergeType": "pr",
  "rules": [
    {
      "description": "No automerge for major updates",
      "matchUpdateTypes": ["major"],
      "automerge": false
    }
  ]
}
```

### Medium Project (Organized Structure)
For active projects with multiple managers or complex rules:

```
renovate.json (main config - extends presets)
renovate/
  ├── automerge.json (automerge rules)
  ├── scheduling.json (scheduling by frequency)
  ├── docker.json (docker-specific rules)
  └── npm.json (npm-specific rules)
```

Main config:
```json
{
  "extends": [
    "config:base",
    "local>renovate/automerge",
    "local>renovate/docker",
    "local>renovate/npm"
  ]
}
```

### Large Project (Multi-Domain Organization)
For monorepos or complex architectures:

```
renovate/
  ├── base.json (shared extends)
  ├── infrastructure/
  │   ├── automerge.json
  │   ├── docker.json
  │   └── terraform.json
  ├── services/
  │   ├── automerge.json
  │   ├── npm.json
  │   └── python.json
  └── libraries/
      ├── automerge.json
      ├── npm.json
      ├── python.json
      └── go.json
```

## Preset Design Patterns

### Pattern 1: Semantic Versioning Tiers
Separate presets for different semver levels:

```json
// renovate/semver-patch.json
{
  "description": "Patch updates only",
  "rules": [{
    "matchUpdateTypes": ["patch"],
    "automerge": true,
    "automergeType": "squash"
  }]
}

// renovate/semver-minor.json
{
  "description": "Minor updates with review",
  "rules": [{
    "matchUpdateTypes": ["minor"],
    "automerge": false,
    "assignees": ["@oncall"]
  }]
}

// renovate/semver-major.json
{
  "description": "Major updates - manual review",
  "rules": [{
    "matchUpdateTypes": ["major"],
    "automerge": false,
    "labels": ["breaking-change"],
    "schedule": ["weekly"]
  }]
}
```

### Pattern 2: Manager-Specific Presets
Separate handling for different package managers:

```json
// renovate/docker-strict.json
{
  "description": "Conservative Docker updates",
  "rules": [{
    "matchDatasources": ["docker"],
    "automerge": false,
    "schedule": ["monthly"],
    "groupName": "Docker images"
  }]
}

// renovate/npm-aggressive.json
{
  "description": "Aggressive npm updates",
  "rules": [{
    "matchDatasources": ["npm"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true,
    "schedule": ["weekly"]
  }]
}
```

### Pattern 3: Business Logic Presets
Group by business concern, not technical detail:

```json
// renovate/security.json
{
  "description": "Security patches",
  "rules": [{
    "matchDatasources": ["npm", "docker", "pip"],
    "labels": ["security"],
    "schedule": ["at any time"],
    "automerge": true
  }]
}

// renovate/compliance.json
{
  "description": "Regulatory/compliance updates",
  "rules": [{
    "labels": ["compliance"],
    "schedule": ["before 1st day of month"],
    "automerge": false
  }]
}
```

## Monorepo Configurations

### Monorepo Challenge
Monorepos can have thousands of dependencies with different update strategies per package. Renovate can create hundreds of PRs.

### Solution: Path-Based Rules

```json
{
  "rules": [
    {
      "description": "Core libraries - strict testing",
      "matchPaths": ["packages/core/**"],
      "automerge": false,
      "require": ["status-success"],
      "schedule": ["weekly"]
    },
    {
      "description": "Services - aggressive updates",
      "matchPaths": ["services/**"],
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true,
      "schedule": ["twice weekly"]
    },
    {
      "description": "Examples - always merge non-breaking",
      "matchPaths": ["examples/**"],
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true
    }
  ]
}
```

### Monorepo PRs with Grouping

Group updates by path to reduce PR noise:

```json
{
  "grouping": [
    {
      "description": "Group by path",
      "matchPaths": ["packages/*"],
      "groupName": "Updates for {{{baseBranch}}} in {{{dir}}}"
    }
  ]
}
```

## Noise Reduction Techniques

### 1. Smart Grouping
Group related updates into single PRs:

```json
{
  "rules": [
    {
      "groupName": "All non-breaking changes",
      "matchUpdateTypes": ["patch", "minor"],
      "grouping": "all"
    },
    {
      "groupName": "Major versions",
      "matchUpdateTypes": ["major"],
      "grouping": "all"
    }
  ]
}
```

### 2. Scheduled Bursts
Control when updates are created (not when they merge):

```json
{
  "rules": [
    {
      "description": "Check daily, create PR weekly",
      "schedule": ["before 3am on Monday"],
      "extends": ["schedule:monthly"]
    }
  ]
}
```

### 3. Dependency Dashboard
Enable dashboard for overview without polluting branches:

```json
{
  "dependencyDashboard": true,
  "dependencyDashboardTitle": "🤖 Dependency Dashboard",
  "postUpdateOptions": ["gomodTidy"]
}
```

### 4. Update Limits
Limit concurrent updates to prevent CI overload:

```json
{
  "prConcurrentLimit": 5,
  "prCreationLimit": 10,
  "schedule": ["before 3am"],
  "minimumReleaseAge": "3 days"
}
```

## Performance Optimization

### 1. Manager Optimization
Disable unused managers to speed up job:

```json
{
  "enabledManagers": ["npm", "docker"],
  "ignoreDeps": ["some-rarely-updated-dep"]
}
```

### 2. Datasource Optimization
Skip unnecessary datasources:

```json
{
  "rules": [{
    "matchDatasources": ["npm"],
    "ignoreTests": true,
    "schedule": ["weekly"]
  }]
}
```

### 3. Cache Optimization
Let Renovate cache between runs:

```json
{
  "cacheTtlDays": 14,
  "persistRepoData": true
}
```

### 4. Constraint Filtering
Use specific version constraints to reduce search space:

```json
{
  "rules": [{
    "matchPackageNames": ["node"],
    "allowedVersions": "^18",
    "schedule": ["weekly"]
  }]
}
```

## Production Lessons

### From Mature Configuration Analysis

**Finding 1: Preset Modularity Scales**
- Production configs using 31 separate preset files
- Each preset handles 4-5 concerns
- Configuration remains maintainable as it grows
- Lesson: Break monolithic configs into modules early

**Finding 2: Maintenance is 50% of Activity**
- Lock file updates, chores, maintenance represent majority of commits
- Automerge for these reduces overhead
- Lesson: Prioritize automerge for low-risk, high-frequency items

**Finding 3: Post-Upgrade Tasks Enable Transformation**
- Sed replacements for code migrations
- Script execution after updates
- Automated code fixes for API changes
- Lesson: Use postUpgradeTasks for breaking changes that can be automated

**Finding 4: Match by Source for Internal Packages**
- More reliable than pattern matching on names
- Handles organization-wide packages
- Prevents false matches
- Lesson: Use `matchSourceUrl` for internal registries

**Finding 5: Docker Naming Matters**
- Generic names (node, postgres) trigger Renovate defaults
- Custom registries need explicit configuration
- Lesson: Be explicit about Docker image sources

### From Renovate Documentation

**Best Practice 1: Automerge Pyramid**
- Official recommendation: tier confidence levels
- Lock files → internal packages → tested deps → majors
- Prevents silent failures and debugging chaos

**Best Practice 2: minimumReleaseAge**
- Add "stability days" before upgrading
- Catches early bugs in new releases
- Recommended: 3-7 days for production

**Best Practice 3: Branch Protection Integration**
- Renovate respects branch protection rules
- Must have permissions to merge
- Use separate Renovate bot account with limited permissions

**Best Practice 4: Dependency Dashboard**
- Enable for visibility without PR pollution
- Shows status of all dependencies at a glance
- Better for teams than 20 individual PRs

**Best Practice 5: CI Integration is Essential**
- Automerge only works if CI is reliable
- Failing CI blocks automerge
- Must configure `require` checks for safety
