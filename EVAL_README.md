# Agent Skills Evaluations

This file documents Promptfoo evaluation configurations for testing the effectiveness of the agent skills in this repository.

## Overview

We use [Promptfoo](https://www.promptfoo.dev/) to evaluate how well our skills guide LLMs to produce correct responses. The evaluations test:

- **TDD Skill**: Verifies the skill properly guides LLMs through Test-Driven Development workflows
- **Jira CLI Skill**: Ensures the skill teaches correct Jira CLI usage patterns

## Running Evaluations Locally

### Prerequisites

1. Install dependencies:
```bash
npm install
```

2. Set up your GitHub token (for GitHub Models):

**For GitHub Models (recommended):**
GitHub Models provides access to OpenAI models through a unified interface.

```bash
export GITHUB_TOKEN=your_github_token_here
```

Get your token from: https://github.com/settings/tokens

**For direct OpenAI API (alternative):**
```bash
export OPENAI_API_KEY=your_api_key_here
```

**For GitHub Copilot:**
GitHub Copilot support requires additional configuration. See [Copilot Configuration](#using-github-copilot) below.

### Run Evaluations

**With OpenAI via GitHub Models (default):**
```bash
npm run eval
```

**With specific OpenAI model:**
```bash
npm run eval:openai
```

**With a specific model via GitHub Models:**
```bash
npx promptfoo eval -p github:openai/gpt-4o
npx promptfoo eval -p github:openai/gpt-4o-mini
```
```

### View Results

After running evaluations, view the results in an interactive UI:

```bash
npm run eval:view
```

Or open the generated JSON file:
```bash
cat promptfoo-results.json
```

## Using GitHub Models

GitHub Models provide access to multiple AI providers (including OpenAI) through a unified interface.

### Setup for GitHub Models

1. **GitHub Token:**
   - GitHub Actions automatically provides `GITHUB_TOKEN`, so no setup is needed in CI
   - For local development, you can use your GitHub personal access token

2. **Local Development:**

Create a `.env` file in the repository root:
```bash
GITHUB_TOKEN=your_github_token_here
```

3. **Run Evaluations:**

```bash
# Use default model (OpenAI GPT-4o-mini)
npm run eval

# Or specific model
npm run eval:openai
```

GitHub Models provide access to:
- OpenAI models (GPT-4o, GPT-4o-mini, etc.)
- Other providers as they become available

## Provider Options

### GitHub Models (Recommended)
All evaluations now use GitHub Models, which provides unified access:

**OpenAI via GitHub Models:**
- `github:openai/gpt-4o-mini` - **Default**, balanced performance and cost
- `github:openai/gpt-4o` - Most capable OpenAI model

**Direct OpenAI API (alternative):**
- `openai:gpt-4o-mini` - Via OpenAI API directly
- `openai:gpt-4o` - Via OpenAI API directly

### Configuration Files

- `promptfooconfig.yaml` - Main evaluation configuration
- `.env` - API keys and environment variables (git-ignored)

## Understanding Results

Promptfoo evaluates each test case and shows:
- ✅ **Pass**: All assertions passed
- ❌ **Fail**: One or more assertions failed
- 📊 **Score**: Percentage of passing assertions

### Key Metrics

1. **Pass Rate**: Percentage of test cases that passed all assertions
2. **Consistency**: How reliably the skill produces correct guidance
3. **Coverage**: Whether the skill handles all expected scenarios

### Example Output

```
┌─────────────────────────────────────────┬────────────┐
│ Test Case                               │ GPT-4o-mini│
├─────────────────────────────────────────┼────────────┤
│ TDD: Should follow Red-Green-Refactor   │ ✅ Pass    │
│ TDD: Should create test list first      │ ✅ Pass    │
│ Jira CLI: Should use --plain flag       │ ✅ Pass    │
└─────────────────────────────────────────┴────────────┘
```

## CI Integration

Evaluations run automatically in GitHub Actions using the official `promptfoo-action`:
- Pull requests that modify skills
- Pushes to the main branch
- Manual workflow dispatch

The CI workflow uses:
- **promptfoo-action** for automated evaluation
- **GitHub Models** with the automatically provided `GITHUB_TOKEN`
- **No additional API key configuration required**

Results are posted as PR comments with interactive links and uploaded as workflow artifacts (30-day retention).

## Adding New Tests

To add tests for a new skill:

1. Add the skill to the `prompts` section in `promptfooconfig.yaml`:
```yaml
prompts:
  - label: 'My New Skill'
    id: file://skills/my-new-skill/SKILL.md
```

2. Add test cases:
```yaml
tests:
  - description: 'My Skill: Should do X'
    prompt: 'My New Skill'
    vars:
      task: 'User request here'
    assert:
      - type: contains
        value: 'expected text'
```

3. Run evaluations to verify:
```bash
npm run eval
```

## Assertion Types

Common assertion types:
- `contains`: Output must contain exact string
- `icontains`: Case-insensitive contains
- `contains-any`: Output must contain at least one of the values
- `not-contains`: Output must NOT contain string
- `regex`: Output must match regex pattern
- `llm-rubric`: Use an LLM to evaluate against criteria (requires API key)

See [Promptfoo Assertions](https://www.promptfoo.dev/docs/configuration/expected-outputs/) for more options.

## Troubleshooting

**"API key not found"**
- Ensure you've exported the appropriate API key environment variable
- Check that the key is valid and has sufficient credits

**"Rate limit exceeded"**
- Reduce concurrency: `npx promptfoo eval --max-concurrency 1`
- Wait a moment and try again

**"Evaluation failed"**
- Check logs: `~/.promptfoo/logs/`
- Verify your API key is correct
- Ensure skill files exist and are valid

## Resources

- [Promptfoo Documentation](https://www.promptfoo.dev/docs/intro/)
- [Promptfoo GitHub](https://github.com/promptfoo/promptfoo)
- [Agent Skills Specification](https://agentskills.io/specification)
