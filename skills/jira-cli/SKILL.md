---
name: jira-cli
description: Interact with Jira using the jira-cli command-line tool to manage issues, sprints, epics, and boards. Use when working with Jira tickets, sprint planning, issue tracking, or when the user mentions Jira, tickets, sprints, epics, or issue management.
compatibility: Requires jira-cli installed and configured (jira init)
---

# Jira CLI

Use [jira-cli](https://github.com/ankitpokhrel/jira-cli) to interact with Jira from the command line.

## Prerequisites

- Jira CLI installed and configured with `jira init`
- Default config: `~/.config/.jira/.config.yml`
- Override with `JIRA_CONFIG_FILE` environment variable

## Critical Usage Patterns

### Always Use Plain Mode

**IMPORTANT**: Always use `--plain` flag to avoid interactive UI:

```bash
jira issue list --plain              # ✓ Good - parseable output
jira issue list                      # ✗ Bad - opens interactive mode
```

### Use JSON for Structured Data

```bash
jira issue view MPD-1234 --raw
```

### Specify Project

```bash
jira issue list -p MPD --plain
```

## Issue Operations

### View Issue

```bash
jira issue view MPD-1234 --plain
jira issue view MPD-1234 --raw              # JSON output
jira issue view MPD-1234 --comments 10      # Show 10 comments
```

### List Issues

```bash
# Basic listing
jira issue list --plain

# Filter by status
jira issue list -s"In Progress" -s"To Do" --plain

# Filter by assignee
jira issue list -a"user@example.com" --plain
jira issue list -ax --plain                 # Unassigned

# Filter by priority, type, reporter
jira issue list -yHigh --plain
jira issue list -tBug --plain
jira issue list -r"user@example.com" --plain

# Filter by labels, component, parent
jira issue list -lbackend -lurgent --plain
jira issue list -C"API" --plain
jira issue list -P"MPD-1234" --plain

# Date filters
jira issue list --created today --plain
jira issue list --created week --plain
jira issue list --created "-10d" --plain
jira issue list --updated "-1w" --plain
jira issue list --created-after 2026-01-01 --created-before 2026-01-31 --plain

# Special filters
jira issue list --history --plain           # Recently accessed
jira issue list --watching --plain          # Issues you watch

# Combined filters
jira issue list -yHigh -s"In Progress" --created month -lbackend --plain

# Text search
jira issue list "Feature Request" --plain

# JQL query
jira issue list -q"project = MPD AND status = 'In Progress'" --plain

# Ordering and pagination
jira issue list --order-by created --plain
jira issue list --reverse --plain
jira issue list --paginate 20 --plain       # First 20
jira issue list --paginate 10:50 --plain    # Items 10-60

# Custom output
jira issue list --plain --columns key,summary,status,assignee
jira issue list --plain --no-headers
jira issue list --plain --delimiter "|"
jira issue list --csv
```

### Create Issues

```bash
# Interactive
jira issue create

# With details
jira issue create -tBug -s"Button not working" -yHigh \
  -b"Description text" -a"user@example.com" -lbug -lurgent

# In specific project
jira issue create -pMPD -tTask -s"New task"

# With custom fields
jira issue create -tStory -s"Title" --custom story-points=5

# From template or stdin
jira issue create --template /path/to/template.md
echo "Description" | jira issue create -s"Summary" -tTask

# Options
jira issue create --web                     # Open in browser
jira issue create --no-input                # No prompts
jira issue create --raw                     # JSON output

# With versions
jira issue create -tBug --fix-version "v1.2.0"
jira issue create -tBug --affects-version "v1.1.0"

# Subtask (parent required)
jira issue create -t"Sub-task" -P"MPD-1234" -s"Subtask title"
```

### Update Issues

```bash
jira issue edit MPD-1234 -s"New summary"
jira issue edit MPD-1234 --priority Critical
jira issue edit MPD-1234 --assignee "user@example.com"
jira issue edit MPD-1234 --label newlabel
jira issue edit MPD-1234 --custom story-points=8
```

### Assign Issues

```bash
jira issue assign MPD-1234 "user@example.com"
jira issue assign MPD-1234 -d              # Default assignee
jira issue assign MPD-1234 -x              # Unassign
```

### Transition Issues

```bash
jira issue move MPD-1234 "In Progress"
jira issue move MPD-1234 "Done"
```

### Comment on Issues

```bash
jira issue comment add MPD-1234 -m"Comment text"
echo "Comment" | jira issue comment add MPD-1234
jira issue comment list MPD-1234
```

### Other Issue Operations

```bash
jira issue link MPD-1234 MPD-5678 "relates to"
jira issue clone MPD-1234
jira issue delete MPD-1234
```

## Sprint Operations

```bash
# List sprints
jira sprint list --table --plain
jira sprint list --state active --plain
jira sprint list --state "active,closed" --plain
jira sprint list --table --plain --columns id,name,start,end,state

# Sprint issues
jira sprint list 123 --plain               # Specific sprint
jira sprint list --current --plain         # Current sprint
jira sprint list --prev --plain            # Previous sprint
jira sprint list --next --plain            # Next sprint

# Filter sprint issues
jira sprint list 123 --show-all-issues --plain
jira sprint list 123 -s"In Progress" --plain
jira sprint list 123 -a"user@example.com" --plain
jira sprint list 123 --plain --columns type,key,summary,status
```

## Epic Operations

```bash
# List epics
jira epic list --table --plain
jira epic list -s"In Progress" --plain
jira epic list -a"user@example.com" --plain
jira epic list --history --plain

# Epic issues
jira epic list EPIC-123 --plain
jira epic list EPIC-123 -s"To Do" --plain

# Manage epics
jira epic create -s"Epic title" -b"Description"
jira epic add EPIC-123 MPD-1234            # Add issue to epic
jira epic remove EPIC-123 MPD-1234         # Remove from epic
```

## Other Operations

```bash
# Boards
jira board list --plain
jira board list --type scrum --plain

# Projects
jira project list --plain

# Releases
jira release list --plain
jira release list -p MPD --plain

# Utilities
jira open MPD-1234                         # Open in browser
jira me                                    # Current user
jira serverinfo                            # Server info
jira version                               # CLI version
```

## JQL Patterns

```jql
# Current user's issues
assignee = currentUser()

# Unassigned
assignee is EMPTY

# Status filtering
status != "Done"
status not in ("Done", "Closed")

# Recent updates
updated >= -7d

# Combined conditions
project = MPD AND status = "In Progress" AND priority in (High, Highest)

# Text search
text ~ "login bug"

# Labels
labels is EMPTY
labels = urgent

# Parent-child
parent = MPD-1234
issueFunction in subtasksOf("MPD-1234")

# Ordering
ORDER BY created DESC
ORDER BY priority DESC, updated DESC
```

## Available Columns

**Issues**: TYPE, KEY, SUMMARY, STATUS, ASSIGNEE, REPORTER, PRIORITY, RESOLUTION, CREATED, UPDATED, LABELS

**Sprints**: ID, NAME, START, END, COMPLETE, STATE

## Common Tasks

### My Open Issues

```bash
jira issue list -a"$(jira me --plain)" -s"To Do" -s"In Progress" --plain
```

### Today's Changes

```bash
jira issue list --updated today --plain --columns key,summary,updated
```

### Current Sprint Report

```bash
SPRINT_ID=$(jira sprint list --state active --plain --no-headers | head -1 | cut -f1)
jira sprint list "$SPRINT_ID" --plain --columns key,summary,status,assignee
```

### Check Issue Status

```bash
STATUS=$(jira issue view MPD-1234 --raw | jq -r '.fields.status.name')
```

### Bulk Label Update

```bash
for key in MPD-1234 MPD-1235; do
  jira issue edit "$key" --label "hotfix"
done
```

## Environment

```bash
# Config location
~/.config/.jira/.config.yml

# Override config
export JIRA_CONFIG_FILE=/path/to/config.yml

# Debug mode
jira --debug issue list
```

## Important Notes

1. **Always use `--plain` or `--raw`** - Interactive mode won't work in automation
2. **Pagination** - Default limit is 100, use `--paginate` for more
3. **Rate limits** - Implement backoff for bulk operations
4. **Permissions** - Can only access issues you have permission for
5. **Custom fields** - Require knowing the field ID

## Quick Reference

| Task | Command |
|------|---------|
| View issue | `jira issue view KEY --plain` |
| List issues | `jira issue list --plain` |
| Create issue | `jira issue create -tTYPE -s"SUMMARY"` |
| Assign | `jira issue assign KEY USER` |
| Transition | `jira issue move KEY STATUS` |
| Comment | `jira issue comment add KEY -m"TEXT"` |
| Sprint issues | `jira sprint list ID --plain` |
| Open browser | `jira open KEY` |
