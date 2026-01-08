# Contributing

Thank you for your interest in contributing to UnaMentis!

## Code of Conduct

Be respectful and constructive. We're building something great together.

## How to Contribute

### Reporting Issues

1. Search existing [issues](https://github.com/UnaMentis/unamentis/issues)
2. If new, create an issue with:
   - Clear title
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details

### Pull Requests

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `./scripts/test-quick.sh`
5. Run linting: `./scripts/lint.sh`
6. Open a pull request
7. [[CodeRabbit]] will review automatically

### Commit Messages

Follow Conventional Commits:

```
feat: Add new voice processing feature
fix: Resolve memory leak in session handler
docs: Update API documentation
test: Add unit tests for STT service
refactor: Simplify audio pipeline
perf: Optimize latency in voice loop
```

## Development Setup

See [[Getting-Started]] for environment setup.

## Code Standards

### Swift (iOS)

- Follow [IOS_STYLE_GUIDE.md](https://github.com/UnaMentis/unamentis/blob/main/docs/ios/IOS_STYLE_GUIDE.md)
- Swift 6.0 concurrency patterns
- SwiftUI for all views
- Actor isolation for thread safety

### Python (Server)

- Type hints required
- Async/await for I/O
- pytest for tests
- Ruff for linting

### TypeScript (Web)

- Strict TypeScript mode
- React hooks best practices
- ESLint + Prettier

## Testing Requirements

- All changes must pass existing tests
- New features should include tests
- Run `./scripts/health-check.sh` before PRs

## Review Process

1. [[CodeRabbit]] provides initial AI review
2. Human maintainer reviews
3. Address all feedback
4. Approval and merge

## Getting Help

- [Discussions](https://github.com/UnaMentis/unamentis/discussions)
- [[Development]] guide
- [[Tools]] documentation

---

Back to [[Home]]
