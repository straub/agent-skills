# Quick Start: Running Evals with GitHub Models

This guide shows how to run evaluations using GitHub Models, which provides unified access to OpenAI, Claude, and other AI providers.

## Setup for GitHub Models

### 1. GitHub Token (Automatic in CI)

GitHub Actions automatically provides `GITHUB_TOKEN`, so **no setup is needed for CI**.

### 2. Local Development Setup

For local evaluation, use a GitHub personal access token:

1. Go to [GitHub Settings → Personal Access Tokens](https://github.com/settings/tokens)
2. Create a token (classic or fine-grained)
3. Copy the token

**Option A: Environment Variable**
```bash
export GITHUB_TOKEN=your_github_token_here
```

**Option B: .env File**
```bash
# Create .env file from template
cp .env.example .env

# Edit .env and add your token
echo "GITHUB_TOKEN=your_github_token_here" >> .env
```

### 3. Run Evaluations

```bash
# Run with OpenAI via GitHub Models (default)
npm run eval

# Run with specific OpenAI model
npm run eval:openai
```

### 4. View Results

```bash
npm run eval:view
```

## Available Models via GitHub Models

GitHub Models provides access to multiple AI providers:

### OpenAI Models
- `github:openai/gpt-4o-mini` - **Default**, balanced performance and cost
- `github:openai/gpt-4o` - Most capable OpenAI model

### Other Providers
As other providers become available through GitHub Models, they can be configured in the same way.

### Custom Model Selection

```bash
# Use specific model
npx promptfoo eval -p github:openai/gpt-4o

# Single model
npx promptfoo eval -p github:openai/gpt-4o-mini
```

## CI Integration

Evaluations run automatically in GitHub Actions with no configuration needed:

1. GitHub Actions provides `GITHUB_TOKEN` automatically
2. Workflow runs on skill changes, PRs, and pushes to main
3. Results are uploaded as artifacts (30-day retention)

No API key secrets needed - GitHub Models access is included with GitHub Actions.

## Understanding Results

After running evaluations, you'll see:

- ✅ **Pass**: All assertions passed for this test case
- ❌ **Fail**: One or more assertions failed  
- 📊 **Pass Rate**: Percentage of tests that passed

View detailed results:

```bash
npm run eval:view
```

## Cost Estimates

GitHub Models pricing (approximate):

| Provider | Model | Cost per eval run* |
|----------|-------|-------------------|
| OpenAI | gpt-4o-mini | ~$0.01 |
| OpenAI | gpt-4o | ~$0.05 |
| Claude | claude-4-sonnet | ~$0.03 |
| Claude | claude-4-opus | ~$0.10 |

*Estimates based on typical response lengths. Multi-provider runs cost proportionally more.

## Troubleshooting

### "No GITHUB_TOKEN found"
- **In CI**: Token is automatic, check workflow permissions
- **Locally**: Set `export GITHUB_TOKEN=your_token_here`

### "Rate limit exceeded"
```bash
# Reduce concurrency
npx promptfoo eval --max-concurrency 1

# Add delay between requests
npx promptfoo eval --delay 1000
```

### "Model not found"
- Verify model name matches GitHub Models format: `github:provider/model-name`
- Check [GitHub Models marketplace](https://github.com/marketplace/models) for available models

## More Information

- [Full Evaluation Documentation](EVAL_README.md)
- [Promptfoo Documentation](https://www.promptfoo.dev/docs/intro/)
- [GitHub Models Documentation](https://docs.github.com/en/github-models)
- [Promptfoo GitHub Provider](https://www.promptfoo.dev/docs/providers/github/)
