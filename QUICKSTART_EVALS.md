# Quick Start: Running Evals with Claude and GitHub Copilot

This guide shows how to run evaluations using Claude (Anthropic) or GitHub Copilot.

## Setup for Claude (Anthropic)

### 1. Get Your API Key

1. Go to [Anthropic Console](https://console.anthropic.com/)
2. Sign in or create an account
3. Navigate to Settings → [API Keys](https://console.anthropic.com/settings/keys)
4. Click "Create Key" and copy the key (starts with `sk-ant-`)

### 2. Configure the API Key

**Option A: Environment Variable (Recommended)**
```bash
export ANTHROPIC_API_KEY=sk-ant-...
```

**Option B: .env File**
```bash
# Create .env file from template
cp .env.example .env

# Edit .env and add your key
# ANTHROPIC_API_KEY=sk-ant-...
```

### 3. Run Evaluations

```bash
# Run with Claude Sonnet (recommended)
npm run eval:claude

# Or use the CLI directly
npx promptfoo eval -p anthropic:claude-3-5-sonnet-20241022

# Other Claude models:
npx promptfoo eval -p anthropic:claude-3-5-haiku-20241022  # Faster, cheaper
npx promptfoo eval -p anthropic:claude-3-opus-20240229     # Most capable
```

### 4. View Results

```bash
npm run eval:view
```

## Setup for GitHub Copilot

### Current Status

As of January 2026, GitHub Copilot's models are primarily available through the IDE and GitHub.com interface. Direct API access for evaluations depends on:

1. **GitHub Models** (Preview): Limited access, requires waitlist approval
2. **Azure OpenAI**: If you have GitHub Copilot Business/Enterprise with Azure integration

### Option 1: GitHub Models (Preview)

If you have access to [GitHub Models](https://github.com/marketplace/models):

```bash
# Get a GitHub token with model access
# https://github.com/settings/tokens

export GITHUB_TOKEN=ghp_...

# Use with compatible endpoints (check GitHub Models docs for current API)
npx promptfoo eval -p openai:gpt-4o \
  --api-base https://models.github.com \
  --api-key $GITHUB_TOKEN
```

**Note**: API availability and endpoints may change. Check [GitHub Models documentation](https://docs.github.com/en/github-models) for current status.

### Option 2: Azure OpenAI (Enterprise)

If your organization has GitHub Copilot Enterprise with Azure OpenAI:

```bash
export AZURE_OPENAI_API_KEY=...
export AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com

npx promptfoo eval -p azureopenai:deployment-name
```

See [Promptfoo Azure OpenAI docs](https://www.promptfoo.dev/docs/providers/azure/) for details.

### Alternative: Use OpenAI or Claude

For now, we recommend using OpenAI or Claude directly for evaluations:

```bash
# OpenAI (same models that power Copilot)
export OPENAI_API_KEY=sk-...
npm run eval

# Claude (high quality alternative)
export ANTHROPIC_API_KEY=sk-ant-...
npm run eval:claude
```

## Comparing Providers

Run evaluations with multiple providers to compare results:

```bash
# Compare OpenAI vs Claude
npm run eval:compare

# Compare multiple models
npx promptfoo eval \
  -p openai:gpt-4o-mini \
  -p openai:gpt-4o \
  -p anthropic:claude-3-5-sonnet-20241022 \
  -p anthropic:claude-3-5-haiku-20241022
```

## Understanding Results

After running evaluations, you'll see:

- ✅ **Pass**: All assertions passed for this test case
- ❌ **Fail**: One or more assertions failed
- 📊 **Pass Rate**: Percentage of tests that passed

View detailed results in the interactive UI:

```bash
npm run eval:view
```

## Cost Estimates

Approximate costs per full evaluation run (9 test cases):

| Provider | Model | Cost per run* |
|----------|-------|---------------|
| OpenAI | gpt-4o-mini | ~$0.01 |
| OpenAI | gpt-4o | ~$0.05 |
| Anthropic | claude-3-5-haiku | ~$0.01 |
| Anthropic | claude-3-5-sonnet | ~$0.03 |

*Estimates based on typical response lengths. Actual costs may vary.

## Troubleshooting

### "API key not found"
- Verify you've set the correct environment variable
- Check that your key is valid (starts with expected prefix)
- Ensure you haven't accidentally added quotes or spaces

### "Rate limit exceeded"
```bash
# Reduce concurrency
npx promptfoo eval --max-concurrency 1

# Add delay between requests
npx promptfoo eval --delay 1000
```

### "Invalid model name"
- Check [Promptfoo Providers](https://www.promptfoo.dev/docs/providers/) for exact model names
- Anthropic: `anthropic:claude-3-5-sonnet-20241022`
- OpenAI: `openai:gpt-4o-mini`

## More Information

- [Full Evaluation Documentation](EVAL_README.md)
- [Promptfoo Documentation](https://www.promptfoo.dev/docs/intro/)
- [Anthropic API Reference](https://docs.anthropic.com/en/api/getting-started)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
