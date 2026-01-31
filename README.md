# Agent Skills

Personal agent skills repository for hosting custom skills developed for use with AI agents like Claude, GitHub Copilot, and other AI assistants that support the Agent Skills specification.

## About

This repository follows the [Agent Skills specification](https://agentskills.io/specification) - an open, portable standard for creating skills that add new capabilities to AI agents across platforms.

## What are Agent Skills?

Agent Skills are folders of instructions, scripts, and resources that agents can discover and use to do things more accurately and efficiently. Skills solve the problem of agents lacking context by giving them access to procedural knowledge and domain-specific expertise they can load on demand.

### What Skills Enable

- **Domain expertise**: Package specialized knowledge into reusable instructions (legal review processes, data analysis pipelines, etc.)
- **New capabilities**: Give agents new abilities (creating presentations, building MCP servers, analyzing datasets)
- **Repeatable workflows**: Turn multi-step tasks into consistent and auditable processes
- **Interoperability**: Reuse the same skill across different skills-compatible agent products

### Progressive Disclosure

Skills are structured for efficient context usage:

1. **Metadata** (~100 tokens): The `name` and `description` fields are loaded at startup for all skills
2. **Instructions** (<5000 tokens recommended): The full `SKILL.md` body is loaded when the skill is activated
3. **Resources** (as needed): Additional files are loaded only when required

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
description: A clear description of what this skill does and when to use it. Include specific keywords that help agents identify when this skill is relevant to a task.
---

# My Skill Name

[Add step-by-step instructions here that the agent will follow when this skill is active]

## Examples
- Example usage scenario with expected input and output
- Another example showing a different use case

## Guidelines
- Best practice or important consideration
- Common edge case to handle
```

### Required Frontmatter Fields

- `name` - A unique identifier for your skill:
  - 1-64 characters
  - Lowercase letters, numbers, and hyphens only (`a-z`, `0-9`, `-`)
  - Cannot start or end with a hyphen
  - Cannot contain consecutive hyphens (`--`)
  - Must match the parent directory name
- `description` - A complete description of what the skill does and when to use it:
  - 1-1024 characters
  - Should describe both what the skill does and when to use it
  - Should include specific keywords that help agents identify relevant tasks

### Optional Frontmatter Fields

- `license` - License name or reference to a bundled license file (e.g., `Apache-2.0` or `LICENSE.txt`)
- `compatibility` - Environment requirements (max 500 characters): intended product, system packages, network access, etc.
- `metadata` - Arbitrary key-value mapping for additional metadata (e.g., author, version)
- `allowed-tools` - Space-delimited list of pre-approved tools the skill may use (experimental)

### Skill Content

The markdown content below the frontmatter contains the skill instructions. While there are no strict format rules, consider including:

- Step-by-step instructions
- Examples of inputs and outputs
- Common edge cases
- Best practices

**Keep your SKILL.md under 500 lines and 5000 tokens recommended.** Move detailed reference material to separate files for efficient context usage.

### Optional Components

You can enhance your skills with additional resources:

- `scripts/` - Executable code (Python, Bash, JavaScript, etc.). Scripts should be self-contained and handle edge cases gracefully.
- `references/` - Additional documentation loaded on demand (e.g., `REFERENCE.md`, `FORMS.md`). Keep files focused and small.
- `assets/` - Static resources (templates, diagrams, data files)

When referencing files in your skill, use relative paths from the skill root. Keep file references one level deep to avoid nested reference chains.

## Using Skills

Skills in this repository can be used with various AI platforms that support the Agent Skills specification:

- **Claude Code** - Register as a plugin marketplace
- **Claude.ai** - Upload custom skills via the web interface
- **Claude API** - Use the Skills API
- **Other compatible agents** - Follow platform-specific instructions

## Validating Skills

Use the [skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref) reference library to validate your skills:

```bash
skills-ref validate ./skills/my-skill-name
```

This checks that your `SKILL.md` frontmatter is valid and follows all naming conventions.

## Evaluating Skills

This repository includes automated evaluations using [Promptfoo](https://www.promptfoo.dev/) to test how well skills guide LLMs to produce correct responses.

### Running Evaluations Locally

1. Install dependencies:
```bash
npm install
```

2. Set up an API key for your preferred LLM provider:
```bash
# For OpenAI
export OPENAI_API_KEY=your_api_key_here

# OR for Claude (Anthropic)
export ANTHROPIC_API_KEY=your_api_key_here
```

3. Run evaluations:
```bash
# With OpenAI (default)
npm run eval

# With Claude
npx promptfoo eval -p anthropic:claude-3-5-sonnet-20241022

# Compare multiple providers
npx promptfoo eval -p openai:gpt-4o-mini -p anthropic:claude-3-5-sonnet-20241022
```

4. View results:
```bash
npm run eval:view
```

See [EVAL_README.md](EVAL_README.md) for detailed documentation on running evaluations with different providers, including GitHub Copilot.

### CI Evaluations

Evaluations run automatically in CI on skill changes. To enable:

1. Go to repository Settings → Secrets and variables → Actions
2. Add `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` as a repository secret

## Resources

- [Agent Skills Specification](https://agentskills.io/specification)
- [Agent Skills Home](https://agentskills.io)
- [Agent Skills GitHub](https://github.com/agentskills/agentskills)
- [Anthropic Skills Repository](https://github.com/anthropics/skills)
- [What are skills?](https://support.claude.com/en/articles/12512176-what-are-skills)
- [Creating custom skills](https://support.claude.com/en/articles/12512198-creating-custom-skills)

## License

This repository is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
