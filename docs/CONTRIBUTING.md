# Contributing to UnaMentis

## Development Workflow

### Branch Strategy

```
main
  ↓
develop
  ↓
feature/your-feature
```

**Branches:**
- `main` - Production-ready code
- `develop` - Integration branch
- `feature/*` - New features
- `fix/*` - Bug fixes
- `refactor/*` - Code refactoring

### Workflow Steps

1. **Create Feature Branch**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/your-feature
   ```

2. **Develop with TDD**
   ```bash
   # Write test first
   # Run: ./scripts/test-quick.sh
   # Implement feature
   # Test passes!
   ```

3. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat: add your feature"
   ```

4. **Push and Create PR**
   ```bash
   git push origin feature/your-feature
   # Create PR on GitHub
   ```

5. **Code Review**
   - Address feedback
   - Update PR
   - Get approval

6. **Merge**
   ```bash
   # Squash and merge to develop
   # Delete feature branch
   ```

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <description>

[optional body]
[optional footer]
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `test:` Tests
- `refactor:` Code refactoring
- `perf:` Performance improvement
- `ci:` CI/CD changes
- `chore:` Maintenance

**Examples:**
```bash
feat: add AssemblyAI STT integration
fix: resolve memory leak in AudioEngine
docs: update API documentation
test: add SessionManager integration tests
refactor: simplify CurriculumEngine context generation
```

## Code Style

### Swift Style

Follow `.swiftlint.yml` and `.swiftformat` rules.

**Auto-format before commit:**
```bash
./scripts/format.sh
./scripts/lint.sh
```

**Key rules:**
- 4-space indentation
- 120 character line length
- Sorted imports
- No force unwrapping (!)
- Prefer `let` over `var`
- Document public APIs

### Documentation

```swift
/// Manages voice conversation sessions with AI
///
/// SessionManager orchestrates the complete conversation flow including
/// turn-taking, interruption handling, and state management.
///
/// - Important: Always call `startSession()` before processing audio
/// - Note: Sessions automatically save every 5 minutes
actor SessionManager {
    // ...
}
```

## Testing Requirements

### Before Committing

```bash
# Run health check
./scripts/health-check.sh
```

This runs:
1. SwiftLint
2. Quick tests

### Before PR

```bash
# Run full test suite
./scripts/test-all.sh
```

### TDD Workflow

1. **Write test first** - Red
2. **Implement feature** - Green
3. **Refactor** - Refactor
4. **Repeat**

### Test Coverage

- **New features**: Add tests
- **Bug fixes**: Add regression test
- **Refactoring**: Maintain existing tests

## Pull Request Process

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation

## Testing
- [ ] Added new tests
- [ ] All tests passing
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guide
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No new warnings
```

### Review Criteria

**Code Quality:**
- Follows Swift style guide
- Well-documented
- No code smells

**Testing:**
- Tests included
- All tests passing
- Adequate coverage

**Architecture:**
- Follows TDD principles
- Proper separation of concerns
- No tight coupling

**Performance:**
- No performance regressions
- Memory leaks checked
- Latency targets met

## Development Environment

### Required Tools

- Xcode 15.2+
- SwiftLint
- SwiftFormat
- xcbeautify

### VS Code

**Recommended extensions:**
- Swift Language
- GitLens
- Better Comments

### Xcode

**Useful shortcuts:**
- `⌘ + B` - Build
- `⌘ + U` - Run tests
- `⌘ + K` - Clean
- `⌘ + Shift + K` - Clean build folder

## Issue Reporting

### Bug Reports

```markdown
**Description**
Clear description of the bug

**Steps to Reproduce**
1. Step 1
2. Step 2
3. See error

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**
- iOS version:
- Device:
- UnaMentis version:

**Screenshots**
If applicable
```

### Feature Requests

```markdown
**Problem**
What problem does this solve?

**Proposed Solution**
Your suggested approach

**Alternatives**
Other approaches considered

**Additional Context**
Any other relevant info
```

## Code of Conduct

- Be respectful
- Be collaborative
- Be constructive
- Be inclusive

## Questions?

- Open a Discussion on GitHub
- Check existing Issues
- Review Documentation

## Getting Started

1. Fork the repository
2. Clone your fork
3. Set up development environment
4. Create feature branch
5. Make changes
6. Submit PR

---

Thank you for contributing to UnaMentis! 🎉
