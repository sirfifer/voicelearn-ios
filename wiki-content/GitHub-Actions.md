# GitHub Actions

CI/CD workflows for UnaMentis.

## Overview

UnaMentis uses GitHub Actions for automated testing, building, and deployment.

## Workflows

### iOS CI

**Trigger:** Push/PR to main, develop

**File:** `.github/workflows/ios.yml`

**Steps:**
1. Checkout code
2. Setup Xcode
3. Run SwiftLint
4. Build for simulator
5. Run unit tests
6. Run integration tests
7. Check code coverage (80% minimum)
8. Upload coverage to Codecov

```yaml
jobs:
  build-and-test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: xcodebuild build -scheme UnaMentis ...
      - name: Test
        run: xcodebuild test -scheme UnaMentis ...
```

### Server CI

**Trigger:** Push/PR to main

**File:** `.github/workflows/server.yml`

**Steps:**
1. Lint Python (Ruff)
2. Type check (mypy)
3. Run pytest
4. Check coverage

### Web CI

**Trigger:** Push/PR to main

**File:** `.github/workflows/web.yml`

**Steps:**
1. Lint (ESLint)
2. Type check (TypeScript)
3. Build
4. Run tests
5. Check coverage

### Security

**Trigger:** Push/PR, weekly

**File:** `.github/workflows/security.yml`

**Checks:**
- Gitleaks (secrets detection)
- CodeQL (vulnerability scanning)
- pip-audit (Python dependencies)
- npm audit (Node dependencies)

### Performance

**Trigger:** Push/PR, nightly

**File:** `.github/workflows/performance.yml`

**Steps:**
1. Run latency test suite
2. Compare against baseline
3. Report regressions

### Nightly E2E

**Trigger:** Daily 2am UTC

**File:** `.github/workflows/nightly.yml`

**Steps:**
1. Full E2E test suite
2. Latency regression tests
3. Long-running stability tests

### Mutation Testing

**Trigger:** Weekly (Sunday 4am UTC)

**File:** `.github/workflows/mutation.yml`

**Tools:**
- mutmut (Python)
- Stryker (Web)
- Muter (iOS, manual)

### Quality Metrics

**Trigger:** Daily

**File:** `.github/workflows/quality.yml`

**Metrics:**
- CI success rate
- PR merge time
- Bug count
- Coverage trends

### Feature Flags

**Trigger:** Weekly

**File:** `.github/workflows/feature-flags.yml`

**Checks:**
- Stale flag detection
- Flag usage audit
- Cleanup recommendations

## Quality Gates

| Gate | Threshold | Enforcement |
|------|-----------|-------------|
| Code Coverage | 80% | CI fails |
| Latency P50 | 500ms | CI warns at +10%, fails at +20% |
| SwiftLint | 0 violations | CI fails |
| Ruff (Python) | 0 violations | CI fails |
| ESLint | 0 violations | CI fails |
| Secrets | 0 findings | CI fails |
| Security Vulns | 0 critical/high | CI fails |

## Branch Protection

**main branch:**
- Required status checks must pass
- At least 1 approving review
- No force pushes
- No deletions

**Required Checks:**
- iOS CI (build, test)
- Server CI (lint, test)
- Web CI (lint, build)
- Security scan

## Secrets Management

Secrets are stored in GitHub Settings > Secrets:

| Secret | Purpose |
|--------|---------|
| `CODECOV_TOKEN` | Coverage upload |
| `OPENAI_API_KEY` | LLM testing |
| `ANTHROPIC_API_KEY` | LLM testing |
| `DEEPGRAM_API_KEY` | STT testing |
| `ELEVENLABS_API_KEY` | TTS testing |

## Local Simulation

Run workflow checks locally:

```bash
# iOS checks
./scripts/lint.sh
./scripts/test-all.sh

# Python checks
cd server/management
ruff check .
pytest tests/

# Web checks
cd server/web
npm run lint
npm test
```

## Debugging Failed Workflows

1. **Check logs**: Click on failed job in GitHub Actions
2. **Re-run**: Use "Re-run failed jobs" button
3. **Local debug**: Run same commands locally

### Common Failures

**"SwiftLint violations"**
```bash
./scripts/lint.sh
# Fix issues, then commit
```

**"Coverage below threshold"**
```bash
./scripts/test-all.sh
# Add tests to increase coverage
```

**"Secrets detected"**
```bash
# Check for accidental commits
gitleaks detect --source .
```

## Adding New Workflows

1. Create `.github/workflows/new-workflow.yml`
2. Define triggers and jobs
3. Test with `act` locally (optional)
4. Push and verify

Example minimal workflow:
```yaml
name: New Workflow
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run command
        run: echo "Hello"
```

## Related Pages

- [[Testing]] - Testing guide
- [[Development]] - Development workflow
- [[Contributing]] - PR process
- [[CodeRabbit]] - AI code review

---

Back to [[Tools]] | [[Home]]
