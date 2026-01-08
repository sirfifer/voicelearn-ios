# CodeRabbit

CodeRabbit is an AI-powered code review tool that automatically reviews pull requests and provides context-aware feedback. This document covers installation, configuration, usage, and best practices for the UnaMentis project.

## Table of Contents

- [Overview](#overview)
- [What CodeRabbit Does](#what-coderabbit-does)
- [Installation](#installation)
- [Configuration](#configuration)
- [Commands Reference](#commands-reference)
- [Interacting with CodeRabbit](#interacting-with-coderabbit)
- [Integrated Tools](#integrated-tools)
- [Strengths and Limitations](#strengths-and-limitations)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Resources](#resources)

## Overview

CodeRabbit is a hosted AI code review service that connects to your GitHub repository and automatically reviews pull requests. It uses large language models combined with static analysis tools to provide comprehensive feedback on code changes.

**Key Value Proposition**: While AI coding tools let you write code faster, code reviews still happen manually. CodeRabbit automates this by delivering reviews that understand your codebase, not just the code you changed, but how it connects to your architecture, follows your patterns, and affects downstream dependencies.

**Pricing**: Free Pro features for public/open-source repositories. Private repositories have tiered plans.

## What CodeRabbit Does

### Core Capabilities

1. **Automated PR Reviews**: Analyzes every pull request and provides detailed feedback
2. **Context-Aware Analysis**: Understands how changes affect the broader codebase
3. **AI-Generated Summaries**: Creates high-level summaries explaining what changed and why it matters
4. **Visual Diagrams**: Generates sequence diagrams for complex changes
5. **File Walkthroughs**: Provides file-by-file analysis of changes
6. **Interactive Chat**: Answers questions about code changes in PR comments
7. **Issue Creation**: Can create issues in GitHub, GitLab, Jira, or Linear
8. **Committable Suggestions**: Provides one-click code fix suggestions
9. **Learning System**: Adapts to team preferences based on feedback

### Analysis Types

- **Security Analysis**: Detects vulnerabilities, secrets, and security issues
- **Code Quality**: Identifies bugs, code smells, and maintainability issues
- **Performance**: Flags potential performance problems
- **Style Compliance**: Checks adherence to coding standards
- **Concurrency Safety**: Validates async/await patterns and thread safety
- **Type Safety**: Verifies type correctness and null safety

## Installation

CodeRabbit is already installed for the UnaMentis repository. For reference, here's the installation process:

### GitHub Installation

1. Visit [app.coderabbit.ai](https://app.coderabbit.ai/)
2. Click "Sign up with GitHub"
3. Authorize CodeRabbit to access your repositories
4. Select the repositories to enable
5. CodeRabbit will automatically start reviewing PRs

### Configuration File

Create a `.coderabbit.yaml` file in your repository root. See [Configuration](#configuration) below.

### Verification

To verify installation is working:
1. Create a test PR
2. CodeRabbit should comment within minutes
3. Use `@coderabbitai configuration` to see current settings

## Configuration

CodeRabbit is configured via the `.coderabbit.yaml` file in the repository root.

### Our Configuration

```yaml
# CodeRabbit Configuration
# https://docs.coderabbit.ai/guides/configure-coderabbit

language: en-US

reviews:
  # Automatic reviews on all PRs
  auto_review:
    enabled: true
    drafts: true  # Review drafts early
    base_branches:
      - main
      - rea/main-dev

  # Review intensity (chill or assertive)
  profile: assertive

  # Request changes on high-severity issues
  request_changes_workflow: true

  # Generate sequence diagrams
  sequence_diagrams: true

  # Collapse walkthrough for large PRs
  collapse_walkthrough: true

  # High-level summary
  high_level_summary: true

  # Fun poem (disabled for us)
  poem: false

  # Path-specific instructions
  path_instructions:
    - path: "**/*.swift"
      instructions: |
        Review for Swift 6.0 concurrency safety...

chat:
  auto_reply: true

knowledge_base:
  learnings:
    scope: auto

early_access: true
```

### Key Configuration Options

| Option | Description | Values |
|--------|-------------|--------|
| `language` | Response language | `en-US`, `es`, `fr`, etc. |
| `reviews.profile` | Review intensity | `chill` (lenient), `assertive` (comprehensive) |
| `reviews.auto_review.enabled` | Auto-review PRs | `true`/`false` |
| `reviews.auto_review.drafts` | Review draft PRs | `true`/`false` |
| `reviews.sequence_diagrams` | Generate diagrams | `true`/`false` |
| `reviews.high_level_summary` | Include summary | `true`/`false` |
| `reviews.poem` | Include fun poem | `true`/`false` |
| `reviews.request_changes_workflow` | Request changes on issues | `true`/`false` |
| `chat.auto_reply` | Auto-reply to mentions | `true`/`false` |
| `early_access` | Enable beta features | `true`/`false` |

### Path Instructions

You can provide custom review instructions for specific file patterns:

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

## Commands Reference

Interact with CodeRabbit by mentioning `@coderabbitai` in PR comments.

### Review Control Commands

| Command | Description |
|---------|-------------|
| `@coderabbitai review` | Request an incremental review (only new changes) |
| `@coderabbitai full review` | Request a complete review (ignores previous comments) |
| `@coderabbitai pause` | Pause automatic reviews on this PR |
| `@coderabbitai resume` | Resume automatic reviews on this PR |
| `@coderabbitai ignore` | Disable reviews entirely (put in PR description) |

### Information Commands

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

You can ask CodeRabbit questions about the code in PR comments:

```
@coderabbitai Why was this change made?
@coderabbitai What's the impact of this on performance?
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

### Responding to Review Comments

When CodeRabbit comments on specific lines:

1. **To acknowledge**: Reply with your fix or explanation
2. **To dismiss**: Reply explaining why it's not applicable
3. **To resolve all**: Use `@coderabbitai resolve`

## Integrated Tools

CodeRabbit runs 40+ analysis tools in a secure sandbox:

### Language-Specific Linters

| Tool | Language/Framework |
|------|-------------------|
| Ruff | Python |
| ESLint | JavaScript/TypeScript |
| Flake8 | Python |
| golangci-lint | Go |
| RuboCop | Ruby |
| PHPStan | PHP |
| Clippy | Rust |
| ShellCheck | Shell scripts |
| SQLFluff | SQL |
| Hadolint | Dockerfile |

### Security Analyzers

| Tool | Purpose |
|------|---------|
| Semgrep | Multi-language static analysis |
| Gitleaks | Secret detection |
| Checkov | Infrastructure as Code security |

### Customization

Tools can be enabled/disabled in `.coderabbit.yaml`:

```yaml
tools:
  ruff:
    enabled: true
  eslint:
    enabled: true
  gitleaks:
    enabled: true
```

## Strengths and Limitations

### Strengths

1. **Context Awareness**: Understands codebase architecture, not just individual files
2. **Fast Reviews**: Provides feedback within minutes of PR creation
3. **Consistent Quality**: Never gets tired, never misses obvious issues
4. **Learning Capability**: Adapts to team preferences over time
5. **Multi-Language Support**: Works across Swift, Python, TypeScript, and more
6. **Interactive**: Can answer questions and generate code/tests
7. **Integrated Tooling**: Runs 40+ linters and security analyzers
8. **Low Friction**: No code changes required, works via GitHub integration
9. **Free for Open Source**: Full Pro features for public repositories

### Limitations

1. **Not a Replacement**: Should complement, not replace, human review
2. **Context Gaps**: May miss business logic or domain-specific issues
3. **False Positives**: Occasionally flags non-issues, especially in unusual patterns
4. **No Runtime Analysis**: Cannot catch issues that only manifest at runtime
5. **Learning Curve**: Team needs time to learn effective interaction patterns
6. **Dependency on Config**: Effectiveness depends on good configuration
7. **Large PR Handling**: Very large PRs may get truncated summaries
8. **Rate Limits**: Heavy usage may hit API limits on free tier

### When to Trust CodeRabbit

**High confidence**:
- Syntax errors and typos
- Security vulnerabilities (secrets, injection)
- Common code smells
- Style violations
- Missing null checks
- Obvious performance issues

**Verify with human review**:
- Architecture decisions
- Business logic correctness
- Complex concurrency issues
- Trade-off decisions
- Edge case handling

## Best Practices

### For PR Authors

1. **Read the Summary**: Start with CodeRabbit's high-level summary
2. **Address High-Severity Issues**: Fix security and critical issues immediately
3. **Respond to Comments**: Acknowledge or explain decisions
4. **Use Interactive Features**: Ask questions if suggestions are unclear
5. **Provide Context**: Add PR description to help CodeRabbit understand intent

### For Reviewers

1. **Don't Skip Human Review**: Use CodeRabbit as a first pass, not the final word
2. **Check False Positives**: Help CodeRabbit learn by providing feedback
3. **Leverage Summaries**: Use AI summaries to quickly understand changes
4. **Focus on Logic**: Let CodeRabbit handle style, focus on business logic

### For the Team

1. **Maintain Configuration**: Keep `.coderabbit.yaml` updated with team standards
2. **Add Path Instructions**: Provide domain-specific guidance for different areas
3. **Review Learnings**: Periodically check what CodeRabbit has learned
4. **Set Expectations**: Clarify when human review is still required

## Troubleshooting

### CodeRabbit Not Reviewing

1. Check if auto_review is enabled in configuration
2. Verify the branch is in `base_branches`
3. Check if `@coderabbitai ignore` is in PR description
4. Verify GitHub app permissions

### Too Many False Positives

1. Adjust `profile` from `assertive` to `chill`
2. Add specific `path_instructions` to clarify intent
3. Provide feedback on incorrect suggestions

### Missing Language-Specific Issues

1. Verify the relevant tool is enabled
2. Add custom `path_instructions` for the file type
3. Check if the language is supported

### Slow Reviews

1. Large PRs take longer to analyze
2. Check CodeRabbit status at [status.coderabbit.ai](https://status.coderabbit.ai/)
3. Use `@coderabbitai review` to manually trigger

## Resources

### Official Documentation

- [CodeRabbit Documentation](https://docs.coderabbit.ai/)
- [Configuration Reference](https://docs.coderabbit.ai/reference/configuration)
- [Commands Guide](https://docs.coderabbit.ai/guides/commands)
- [CLI Documentation](https://www.coderabbit.ai/cli)

### Project Resources

- [Our Configuration](.coderabbit.yaml) (repository root)
- [iOS Style Guide](../ios/IOS_STYLE_GUIDE.md) (referenced in path instructions)

### Support

- [CodeRabbit Status](https://status.coderabbit.ai/)
- [CodeRabbit GitHub](https://github.com/coderabbitai)
- [Community Discussions](https://github.com/coderabbitai/coderabbit-docs/discussions)

---

*Last updated: January 2025*
