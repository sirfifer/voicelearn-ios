# CodeRabbit

CodeRabbit is an AI-powered code review tool that automatically reviews pull requests and provides context-aware feedback.

## Overview

CodeRabbit is a hosted AI code review service that connects to GitHub and automatically reviews pull requests. It uses large language models combined with static analysis tools to provide comprehensive feedback.

**Key Value**: While AI coding tools let you write code faster, code reviews still happen manually. CodeRabbit automates this by delivering reviews that understand your codebase, not just the code you changed, but how it connects to your architecture, follows your patterns, and affects downstream dependencies.

**Pricing**: Free Pro features for public/open-source repositories.

## What CodeRabbit Does

### Core Capabilities

1. **Automated PR Reviews** - Analyzes every pull request
2. **Context-Aware Analysis** - Understands how changes affect the broader codebase
3. **AI-Generated Summaries** - Creates high-level summaries
4. **Visual Diagrams** - Generates sequence diagrams for complex changes
5. **Interactive Chat** - Answers questions about code changes
6. **Issue Creation** - Can create issues in GitHub, Jira, or Linear
7. **Committable Suggestions** - Provides one-click code fix suggestions
8. **Learning System** - Adapts to team preferences

### Analysis Types

- Security vulnerabilities and secrets
- Code quality and bugs
- Performance issues
- Style compliance
- Concurrency safety
- Type safety

## Commands Reference

Interact with CodeRabbit by mentioning `@coderabbitai` in PR comments.

### Review Control

| Command | Description |
|---------|-------------|
| `@coderabbitai review` | Request incremental review (new changes only) |
| `@coderabbitai full review` | Request complete review (ignores previous comments) |
| `@coderabbitai pause` | Pause automatic reviews on this PR |
| `@coderabbitai resume` | Resume automatic reviews |
| `@coderabbitai ignore` | Disable reviews entirely (put in PR description) |

### Information

| Command | Description |
|---------|-------------|
| `@coderabbitai help` | Show quick reference guide |
| `@coderabbitai configuration` | Show current configuration |
| `@coderabbitai summary` | Regenerate the PR summary |
| `@coderabbitai generate sequence diagram` | Create a sequence diagram |

### Comment Management

| Command | Description |
|---------|-------------|
| `@coderabbitai resolve` | Mark all CodeRabbit comments as resolved |

### Agentic Commands

| Command | Description |
|---------|-------------|
| `@coderabbitai generate unit tests` | Generate unit tests for the changes |
| `@coderabbitai create issue` | Create an issue from the discussion |
| `@coderabbitai create Jira ticket` | Create a Jira ticket (requires integration) |
| `@coderabbitai create Linear issue` | Create a Linear issue (requires integration) |

## Interacting with CodeRabbit

### Asking Questions

```
@coderabbitai Why was this change made?
@coderabbitai What's the impact on performance?
@coderabbitai Can you explain this function?
@coderabbitai Is this thread-safe?
```

### Providing Feedback

When CodeRabbit makes a suggestion you disagree with:

```
@coderabbitai I disagree because [reason].
Please remember this for future reviews.
```

CodeRabbit learns from feedback and adjusts future reviews.

### Requesting Actions

```
@coderabbitai Generate unit tests for the UserService class
@coderabbitai Create a GitHub issue to track this technical debt
@coderabbitai Summarize what this PR does in one sentence
```

## Configuration

CodeRabbit is configured via `.coderabbit.yaml` in the repository root.

### Key Settings

| Option | Description |
|--------|-------------|
| `reviews.profile` | `chill` (lenient) or `assertive` (comprehensive) |
| `reviews.auto_review.enabled` | Enable automatic reviews |
| `reviews.auto_review.drafts` | Review draft PRs |
| `reviews.sequence_diagrams` | Generate diagrams |
| `reviews.high_level_summary` | Include summary |
| `chat.auto_reply` | Auto-reply to mentions |

### Path Instructions

Custom review instructions for specific file patterns:

```yaml
reviews:
  path_instructions:
    - path: "**/*.swift"
      instructions: |
        Check for Swift 6.0 concurrency issues

    - path: "server/**/*.py"
      instructions: |
        Verify async/await patterns
```

## Integrated Tools

CodeRabbit runs 40+ analysis tools:

| Tool | Language |
|------|----------|
| Ruff, Flake8 | Python |
| ESLint | JavaScript/TypeScript |
| golangci-lint | Go |
| RuboCop | Ruby |
| Clippy | Rust |
| ShellCheck | Shell |
| Semgrep | Multi-language security |
| Gitleaks | Secret detection |

## Strengths

1. **Context Awareness** - Understands codebase architecture
2. **Fast Reviews** - Feedback within minutes
3. **Consistent Quality** - Never misses obvious issues
4. **Learning Capability** - Adapts to team preferences
5. **Multi-Language** - Works across Swift, Python, TypeScript
6. **Interactive** - Can answer questions and generate code
7. **Free for Open Source** - Full Pro features for public repos

## Limitations

1. **Not a Replacement** - Should complement human review
2. **Context Gaps** - May miss business logic issues
3. **False Positives** - Occasionally flags non-issues
4. **No Runtime Analysis** - Cannot catch runtime-only issues
5. **Large PR Handling** - Very large PRs may be truncated

## Resources

- [Official Documentation](https://docs.coderabbit.ai/)
- [Configuration Reference](https://docs.coderabbit.ai/reference/configuration)
- [Commands Guide](https://docs.coderabbit.ai/guides/commands)
- [CLI Documentation](https://www.coderabbit.ai/cli)
- [CodeRabbit GitHub](https://github.com/coderabbitai)

---

Back to [[Tools]] | [[Home]]
