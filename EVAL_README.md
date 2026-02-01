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

2. Set up your LLM provider API key (choose one):

**For OpenAI (GPT-4):**
```bash
export OPENAI_API_KEY=your_api_key_here
```

**For Anthropic (Claude):**
```bash
export ANTHROPIC_API_KEY=your_api_key_here
```

**For GitHub Copilot:**
GitHub Copilot support requires additional configuration. See [Copilot Configuration](#using-github-copilot) below.

### Run Evaluations

**With both OpenAI and Claude (default):**
```bash
npm run eval
```

**With Claude only:**
```bash
npm run eval:claude
```

**With GitHub Models:**
```bash
npm run eval:github
```

**With a specific Claude model:**
```bash
npx promptfoo eval -p anthropic:claude-3-5-sonnet-20241022
```

**With multiple providers (comparison):**
```bash
npx promptfoo eval -p openai:gpt-4o-mini -p anthropic:claude-3-5-sonnet-20241022
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

## Using GitHub Copilot

GitHub Copilot can be used as a provider through the OpenAI-compatible API. 

### Setup for GitHub Copilot

1. **Get a GitHub token with Copilot access:**
   - Go to https://github.com/settings/tokens
   - Create a token with `copilot` scope
   - Save the token securely

2. **Configure the GitHub Copilot provider:**

Create a `.env` file in the repository root:
```bash
GITHUB_TOKEN=your_github_token_here
```

3. **Run with GitHub Copilot:**

Promptfoo doesn't have native GitHub Copilot support yet, but you can use it through the OpenAI-compatible endpoint:

```bash
# Use GitHub Models
export GITHUB_TOKEN=${{ secrets.GITHUB_TOKEN }}
npm run eval:github
```

GitHub Models are now supported through Promptfoo's native `github:` provider.

## Provider Options

### OpenAI Models
- `openai:gpt-4o` - Most capable, higher cost
- `openai:gpt-4o-mini` - **Default**, balanced performance and cost
- `openai:gpt-4-turbo` - Previous generation flagship
- `openai:gpt-3.5-turbo` - Fastest, lowest cost

### Anthropic (Claude) Models
- `anthropic:claude-3-5-sonnet-20241022` - **Recommended**, best balance
- `anthropic:claude-3-5-haiku-20241022` - Fastest, lowest cost
- `anthropic:claude-3-opus-20240229` - Most capable (if needed)
- `anthropic:claude-3-opus-20240229` - Most capable (if needed)

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
┌─────────────────────────────────────────┬────────────┬────────────┐
│ Test Case                               │ GPT-4o     │ Claude 3.5 │
├─────────────────────────────────────────┼────────────┼────────────┤
│ TDD: Should follow Red-Green-Refactor   │ ✅ Pass    │ ✅ Pass    │
│ TDD: Should create test list first      │ ✅ Pass    │ ✅ Pass    │
│ Jira CLI: Should use --plain flag       │ ✅ Pass    │ ⚠️  Partial│
└─────────────────────────────────────────┴────────────┴────────────┘
```

## CI Integration

Evaluations run automatically in GitHub Actions on:
- Pull requests that modify skills
- Pushes to the main branch
- Manual workflow dispatch

The CI workflow requires `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` to be set as a repository secret.

### Adding Secrets to GitHub

1. Go to repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add one of:
   - Name: `OPENAI_API_KEY`, Value: your OpenAI API key
   - Name: `ANTHROPIC_API_KEY`, Value: your Anthropic API key

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
