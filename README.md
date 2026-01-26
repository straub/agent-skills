# Agent Skills

Personal agent skills repository for hosting custom skills developed for use with AI agents like Claude, GitHub Copilot, and other AI assistants that support the Agent Skills specification.

## About

This repository follows the [Agent Skills specification](https://agentskills.io/specification) - an open, portable standard for creating skills that add new capabilities to AI agents across platforms.

## What are Agent Skills?

Skills are folders of instructions, scripts, and resources that AI agents load dynamically to improve performance on specialized tasks. Each skill teaches an agent how to complete specific tasks in a repeatable way.

## Repository Structure

```
agent-skills/
├── skills/          # Individual skill folders
│   └── [skill-name]/
│       └── SKILL.md # Required: skill definition with YAML frontmatter
├── template/        # Template for creating new skills
│   └── SKILL.md     # Skill template
└── README.md        # This file
```

## Creating a Skill

Skills are simple to create - just a folder with a `SKILL.md` file containing YAML frontmatter and instructions. You can use the **template** in this repository as a starting point.

### Basic Structure

```markdown
---
name: my-skill-name
description: A clear description of what this skill does and when to use it
---

# My Skill Name

[Add your instructions here that the agent will follow when this skill is active]

## Examples
- Example usage 1
- Example usage 2

## Guidelines
- Guideline 1
- Guideline 2
```

### Required Frontmatter Fields

- `name` - A unique identifier for your skill (lowercase, hyphens for spaces, max 64 characters)
- `description` - A complete description of what the skill does and when to use it (max 1024 characters)

### Optional Frontmatter Fields

- `license` - License information for the skill
- `compatibility` - Compatibility information
- `metadata` - Additional metadata
- `allowed-tools` - Tools the agent is allowed to use with this skill

### Skill Content

The markdown content below the frontmatter contains the instructions, examples, and guidelines that the agent will follow. While there are no strict format rules, consider including:

- Step-by-step instructions
- Examples of inputs and outputs
- Common edge cases
- Best practices

### Optional Components

You can enhance your skills with additional resources:

- `scripts/` - Executable scripts (Bash, Python, etc.)
- `references/` - Supporting documentation
- `assets/` - Images or other assets

## Using Skills

Skills in this repository can be used with various AI platforms that support the Agent Skills specification:

- **Claude Code** - Register as a plugin marketplace
- **Claude.ai** - Upload custom skills via the web interface
- **Claude API** - Use the Skills API
- **Other compatible agents** - Follow platform-specific instructions

## Resources

- [Agent Skills Specification](https://agentskills.io/specification)
- [Anthropic Skills Repository](https://github.com/anthropics/skills)
- [What are skills?](https://support.claude.com/en/articles/12512176-what-are-skills)
- [Creating custom skills](https://support.claude.com/en/articles/12512198-creating-custom-skills)

## License

This repository is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
