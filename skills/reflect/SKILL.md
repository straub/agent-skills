---
name: reflect
description: Audit a project's agent-instruction and config files (AGENTS.md/CLAUDE.md, Claude Code Skills/commands/settings/MCP, Copilot CLI instructions/agents/skills/MCP) plus Claude Code's Auto Memory files for staleness, gaps, or drift from what actually happened in the session, then propose and — once approved — apply fixes. Use when the user says "reflect", asks for a retro on the session, wants to audit or clean up project instructions/config, or wants to consolidate/tidy memory files.
---

# Reflect

Audit the project's agent-instruction and config surface — and, where
present, Claude Code's Auto Memory files — against what actually happened in
this session, then propose concrete fixes. Implement only what's approved.

This is deliberately **not** a general "remember things across sessions"
tool. Claude Code already does that continuously and automatically via Auto
Memory (`~/.claude/projects/<path-slug>/memory/`, where `<path-slug>` is the
project's absolute path with `/` replaced by `-`, e.g. `/home/me/docker` →
`-home-me-docker`) — writing structured notes every time you correct or
confirm something, with no invocation needed. This skill covers the two
things nothing else automates:

1. **Instruction/config hygiene** — do the project's instruction and config
   files reflect what this session actually needed? Missing permissions,
   undocumented conventions, workflows that should be a Skill instead of a
   one-off.
2. **Memory consolidation** — Auto Memory accumulates by design; nothing
   periodically dedupes it, checks it against current repo state, or merges
   related notes into a synthesized principle. This skill does that pass.

## When to Use This Skill

✅ Use if:
- The user asks to "reflect" on the session, or for a retro / post-mortem
- The user wants to audit, clean up, or modernize project instructions
  (`AGENTS.md`, Skills, commands, settings, MCP config) for either
  Claude Code or GitHub Copilot CLI
- The user wants Auto Memory tidied up (duplicates merged, stale entries
  removed, related notes consolidated into a principle)
- You (the agent) notice recurring friction this session — a permission
  approved ad hoc and re-prompted repeatedly, a mistake a hook could have
  caught, a workflow that got reinvented — and want to surface it

❌ Don't use if:
- The user just wants something remembered for next time — Auto Memory
  already does that on its own; no skill invocation needed
- The ask is a one-off code change with no instruction/config angle

## Analysis Phase

Check whichever of these exist in the project. Not every project will have
all of them — Claude Code and Copilot CLI paths are independent; use what's
present.

**Shared across tools:**
- `AGENTS.md` (repo root and nested) — read natively by both Claude Code
  and GitHub Copilot CLI (and other AGENTS.md-aware tools), so getting this
  one file right has the highest leverage. A `CLAUDE.md` symlink to it is a
  common pattern for backward compatibility.

**Claude Code:**
- `.claude/skills/*/SKILL.md` — the current preferred mechanism, using the
  same `SKILL.md` format shared by Claude.ai, the API, and other Agent
  Skills-compatible tools.
- `.claude/commands/*.md` — legacy custom commands. Still functional, but a
  workflow that's grown non-trivial usually belongs in `.claude/skills/`
  instead — flag candidates for migration rather than just patching them
  in place.
- `.claude/settings.json`, `.claude/settings.local.json`, and their
  user-scoped counterparts `~/.claude/settings.json`, `~/.claude/skills/`,
  `~/.claude/commands/` — permissions, hooks, env vars. Look for
  permissions the user approved repeatedly during the session that were
  never persisted, and repeated mistakes a `PreToolUse`/`PostToolUse` hook
  could catch. Persist a finding at the scope it's actually true for (this
  one repo vs. this user everywhere).
- `.mcp.json` (project-scoped) and `mcpServers` in `~/.claude.json`
  (user-scoped). Prefer user-scoped when a server's URL carries a
  bearer-equivalent secret in the path — project-scoped config gets
  committed.
- `.claude-plugin` marketplace/plugin config, if the project uses one —
  plugins bundle skills, agents, hooks, and MCP servers as one versioned
  unit; a repeated ad hoc setup step across sessions may belong there.
- Auto Memory: `~/.claude/projects/<path-slug>/memory/*.md` and its
  `MEMORY.md` index. Entries are typed (`user`, `feedback`, `project`,
  `reference`). Check for:
  - Stale claims — a memory naming a file, function, or flag that no
    longer exists (grep/read to confirm before trusting it)
  - Duplicate or near-duplicate entries, especially within the same type
  - Related entries that should be merged into one synthesized principle
  - Entries that belong in `AGENTS.md` instead (a fact true for anyone
    working in the repo, not just this user's personal preference)

**GitHub Copilot CLI:**
- `.github/copilot-instructions.md` and
  `.github/instructions/**.instructions.md` — Copilot's own instruction
  files, alongside its native `AGENTS.md` support.
- Custom agents: `.github/agents/*.agent.md` (repo-scoped) or
  `~/.copilot/agents` (user-scoped) — Markdown + YAML frontmatter profiles.
- Copilot CLI Skills (same `SKILL.md` format as above) — Copilot's skills
  support is newer than its instructions support, so confirm what the
  install actually loads rather than assuming a directory is in use.
- `~/.copilot/mcp-config.json` — Copilot CLI's MCP server config.

**Session friction (not file-specific):**
- Scan the conversation for misunderstood requests, corrections the user
  had to repeat, or manual steps that recurred — these are candidates for
  a config/doc fix even if no file above is obviously stale.

## Interaction Phase

Present all findings together in one turn, not dragged out across multiple
round trips. For each finding, give:

1. The issue you found
2. A specific, concrete proposed change
3. What it fixes

Then ask, in that same turn, which findings to implement — approve all,
approve a subset, or reject/defer any. Only move to the Implementation
Phase once the user has responded with their picks. Don't apply anything
before that response comes back.

## Implementation Phase

For each approved change:
- State which file you're editing and why
- Make the edit
- If the change is a workflow that's proven itself reusable, prefer adding
  it as a new Skill (`.claude/skills/<name>/SKILL.md`, or the equivalent
  path for whichever tool the project uses) over a legacy command or an
  ever-growing `AGENTS.md` bullet list

## Examples

- User: "reflect on this session" — read chat history, check `AGENTS.md`
  and `.claude/settings.local.json` for permissions approved ad hoc but not
  persisted, propose adding them, wait for approval, apply.
- User: "clean up memory, it's gotten cluttered" — read all files under
  `~/.claude/projects/<path-slug>/memory/`, identify duplicates and stale
  claims (verify against current repo state), propose a consolidated set,
  apply once approved, update `MEMORY.md`'s index accordingly.
- User: "we keep re-explaining our deploy process, can we fix that" — note
  in the session that this came up more than once, check whether it's
  already in `AGENTS.md` or a Skill, propose adding it as a Skill if it's
  a repeatable multi-step workflow rather than a one-line fact.

## Guidelines

- Verify before asserting: don't claim a memory entry or instruction is
  stale without actually checking current file/function existence.
- Keep `AGENTS.md` thin — point to detail (a Skill, a `references/` file)
  rather than pasting it inline; the file loads on every session.
- Auto Memory and `AGENTS.md` serve different audiences: memory is this
  user's personal, evolving observations; `AGENTS.md` is durable, shared
  ground truth for anyone (or any agent) working in the repo. A finding
  that belongs in one shouldn't just accumulate in the other by default.
