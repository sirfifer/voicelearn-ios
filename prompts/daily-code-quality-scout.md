# Daily Code Quality Scout Prompt for UnaMentis

**Purpose:** Discover new tools, patterns, and AI capabilities to improve UnaMentis code quality infrastructure.

**Usage:** Run this prompt daily/weekly with an AI assistant (Claude, Perplexity) that has web search capabilities. Review output and create GitHub issues for items worth investigating.

**Scope:** Developer tooling and code quality practices. For AI model scouting (STT, TTS, LLM), see `daily-tech-scout.md`.

---

## The Prompt

```
You are a code quality scout for UnaMentis, a cross-platform voice AI tutoring system. Your job is to find NEW developments (within the last 7 days) that could improve our code quality infrastructure.

## Project Context

UnaMentis is a voice AI tutoring platform with iOS, Android, and server components. The project is 100% AI-developed and has a comprehensive code quality initiative.

### Current Technology Stack

**iOS (Swift 6.0 / SwiftUI):**
- Linting: SwiftLint (strict mode, zero violations enforced)
- Formatting: SwiftFormat
- Coverage: xccov (80% minimum enforced)
- Mutation Testing: Muter (manual only, not in CI)
- Testing: XCTest with unit/integration/E2E separation

**Android (Kotlin / Jetpack Compose):**
- Linting: ktlint
- Formatting: ktfmt
- Coverage: JaCoCo
- Testing: JUnit, Espresso, Compose testing

**Python (Server - aiohttp, FastAPI):**
- Linting: Ruff (E, F, I, N, W, UP rules)
- Formatting: Black via Ruff
- Coverage: pytest-cov (70% minimum)
- Mutation Testing: mutmut (weekly, >70% score target)
- Testing: pytest with pytest-asyncio

**Web (Next.js / React / TypeScript):**
- Linting: ESLint with TypeScript strict
- Formatting: Prettier with Tailwind plugin
- Coverage: Vitest (70% minimum)
- Mutation Testing: Stryker (weekly)
- Testing: Vitest, React Testing Library

**Cross-Platform:**
- AI Code Review: CodeRabbit (assertive profile, all PRs)
- Secrets Detection: Gitleaks (pre-commit + CI)
- DORA Metrics: Apache DevLake
- Feature Flags: Unleash (90-day max age)

### Quality Gates (Current)

| Gate | Threshold |
|------|-----------|
| iOS Coverage | 80% minimum |
| Python Coverage | 70% minimum |
| Web Coverage | 70% minimum |
| SwiftLint | Zero violations (strict) |
| Ruff | Zero violations |
| ESLint | Zero violations |
| Mutation Score | >70% (Python, Web) |
| Secrets | Zero findings |
| Feature Flag Age | 90 days max |

### CI/CD Infrastructure

- 11 GitHub Actions workflows
- Pre-commit hooks: lint, format, secrets detection
- Pre-push hooks: quick unit tests
- Hook bypass logging and audit
- Nightly E2E tests with real API providers
- Daily quality metrics collection
- Automatic issue creation on failures

### Testing Philosophy

"Real Over Mock" - Only mock paid third-party APIs (LLM, STT, TTS). Use real implementations for:
- Internal services
- File systems (temp directories)
- Core Data (in-memory stores)
- Free external APIs
- Local computations

### Current Pain Points

1. iOS mutation testing only runs manually (Muter complex in CI)
2. No automated test generation
3. No architectural drift detection
4. No property-based testing
5. Flaky test detection is manual
6. No visual regression testing for web UI
7. Technical debt not systematically tracked

## Search Categories

For each category, find NEW items from the past 7 days:

### 1. Static Analysis & Linting

Search for:
- New SwiftLint rules or plugins
- Ruff updates and new rules
- ESLint plugins for TypeScript/React
- ktlint and detekt updates for Android
- Cross-language linting tools
- Custom rule creation frameworks
- Architecture-aware linting (layer violations)

### 2. Testing Frameworks & Patterns

Search for:
- XCTest improvements and alternatives
- pytest plugins and patterns
- Vitest/Jest updates
- Property-based testing tools (SwiftCheck, Hypothesis, fast-check)
- Snapshot testing improvements
- Contract testing (Pact, OpenAPI validation)
- Behavior-driven testing frameworks
- Flaky test detection and quarantine tools

### 3. Coverage & Mutation Testing

Search for:
- Mutation testing tools for Swift/iOS (Muter alternatives)
- mutmut and Stryker updates
- Coverage visualization tools
- Differential coverage (only changed code)
- Test impact analysis tools
- Uncovered code detection improvements

### 4. Security Scanning

Search for:
- SAST tools (Semgrep, CodeQL updates)
- Dependency vulnerability scanners (Snyk, Dependabot, pip-audit)
- Secret detection improvements (beyond Gitleaks)
- iOS/Android specific security scanners
- Supply chain security tools
- SBOM generation and analysis

### 5. CI/CD Optimization

Search for:
- Faster build caching strategies
- Test parallelization tools
- Build time analysis and optimization
- Incremental testing (only run affected tests)
- GitHub Actions performance improvements
- Self-hosted runner optimizations
- Build artifact management

### 6. AI Code Review

Search for:
- CodeRabbit alternatives and competitors
- Specialized AI reviewers (security, performance, accessibility)
- GitHub Copilot code review features
- Custom AI review rule creation
- PR size and complexity analysis
- Review automation improvements

### 7. AI Test Generation

Search for:
- AI-powered unit test generators (Diffblue, CodiumAI)
- Property-based test synthesis
- Test case generation from specifications
- Fuzz testing with AI guidance
- Edge case discovery tools
- Test quality scoring

### 8. AI Refactoring & Tech Debt

Search for:
- AI-powered refactoring suggestions
- Technical debt detection and tracking
- Code smell detection tools
- Architectural drift detection
- Dependency analysis and cleanup
- Dead code detection improvements
- Complexity reduction suggestions

### 9. AI Documentation

Search for:
- Automatic API documentation generation
- Code comment generation
- README and changelog automation
- Architecture diagram generation
- Docstring quality tools
- Documentation coverage tracking

### 10. AI Debugging & Observability

Search for:
- AI-powered log analysis
- Root cause analysis tools
- Error clustering and deduplication
- Performance regression detection
- Memory leak detection improvements
- Crash analysis automation

## Output Format

For each finding, provide:

```markdown
### [Category] Finding Title

**Source:** [URL]
**Date:** [Publication date]
**Relevance:** [High/Medium/Low]
**Platforms:** [iOS/Android/Python/Web/All]

**Summary:** 2-3 sentences describing what it is

**Why It Matters for UnaMentis:**
- Specific benefit 1
- Specific benefit 2

**Comparison to Current Tools:**
- How it compares to what we already use

**Action Items:**
- [ ] Concrete next step to evaluate/integrate

**Effort Estimate:** [Low/Medium/High integration effort]

**Risk/Considerations:**
- Any downsides or concerns
```

## Priority Signals

Flag as HIGH priority if:
- Works with our stack (Swift, Kotlin, Python, TypeScript)
- Improves test quality or coverage without manual effort
- Reduces CI build/test time significantly
- Catches bugs we currently miss (mutation survivors, security issues)
- Has GitHub Actions / CLI integration
- Open source or has free tier for open source projects
- Addresses one of our listed pain points

Flag as MEDIUM priority if:
- Interesting approach we could adapt
- Requires moderate integration effort
- Academic paper with practical implementation
- New tool from established vendor
- Would improve developer experience

Flag as LOW priority if:
- Only supports languages we don't use
- Requires major architecture changes
- Early stage without production usage
- Duplicates existing tooling without clear advantage
- Enterprise-only pricing

## Additional Context

The project emphasizes:
- Real implementations over mocks in testing
- Modular, protocol-based architecture
- Comprehensive observability and telemetry
- Cost transparency and optimization
- "Definition of Done" requires /validate to pass

Key metrics we track:
- CI success rate (target: >90%)
- Code coverage (iOS 80%, Python/Web 70%)
- Mutation score (target: >70%)
- Mean time to recovery
- Deployment frequency

Now search the web for developments in each category from the past 7 days and report your findings.
```

---

## Quick Daily Check

For rapid daily checks (2-3 minutes), use this condensed prompt:

```
Find NEW code quality tools or updates from the past 48 hours for:

MUST SEARCH:
1. "SwiftLint" OR "SwiftFormat" new release
2. "Ruff" OR "Black" Python linter update
3. "ESLint" OR "Prettier" TypeScript update
4. "CodeRabbit" OR "AI code review" new feature
5. "mutation testing" new tool OR update
6. "AI test generation" OR "AI unit test" new tool
7. "GitHub Actions" security OR performance update
8. "Stryker" OR "mutmut" OR "Muter" release

CONTEXT: Swift iOS + Kotlin Android + Python server + TypeScript web. Need tools with GitHub integration.

OUTPUT: Only report genuinely new and impactful findings. No findings is valid.

Format:
- **What:** One sentence
- **Platform:** iOS / Android / Python / Web / All
- **Link:** URL
- **Priority:** High/Medium/Low
- **Current Tool:** What we'd compare it to
```

---

## Sources to Monitor

### GitHub Releases (Watch these repos)

**Static Analysis:**
- `realm/SwiftLint`
- `nicklockwood/SwiftFormat`
- `astral-sh/ruff`
- `eslint/eslint`
- `pinterest/ktlint`

**Testing:**
- `stryker-mutator/stryker-js`
- `boxed/mutmut`
- `muter-mutation-testing/muter`
- `HypothesisWorks/hypothesis`
- `quick/Quick` (Swift BDD)

**Security:**
- `gitleaks/gitleaks`
- `returntocorp/semgrep`
- `github/codeql`
- `pyupio/safety`

**CI/CD:**
- `actions/runner`
- `nektos/act` (local Actions testing)

### Blogs & News

**AI Code Quality:**
- https://www.coderabbit.ai/blog
- https://www.codium.ai/blog
- https://www.diffblue.com/blog
- https://www.sonarsource.com/blog

**General Dev Tools:**
- https://github.blog/category/engineering/
- https://www.thoughtworks.com/radar
- https://martinfowler.com/

### Hacker News Searches

```
https://hn.algolia.com/?dateRange=last24h&query=code+quality
https://hn.algolia.com/?dateRange=last24h&query=mutation+testing
https://hn.algolia.com/?dateRange=last24h&query=AI+code+review
https://hn.algolia.com/?dateRange=last24h&query=static+analysis
https://hn.algolia.com/?dateRange=last24h&query=test+generation
```

---

## Maintaining This Prompt

**Update this prompt when:**

1. **New tools added** - Add to "Current Technology Stack" section
2. **Quality gates change** - Update thresholds in "Quality Gates" table
3. **Pain points resolved** - Remove from "Current Pain Points"
4. **New pain points discovered** - Add to "Current Pain Points"
5. **New platform added** - Add platform-specific section
6. **CI workflows change** - Update "CI/CD Infrastructure" section

**Last Updated:** 2026-01-13

**Current State Checksum:**
- iOS: SwiftLint, SwiftFormat, xccov (80%), Muter (manual)
- Python: Ruff, pytest-cov (70%), mutmut
- Web: ESLint, Prettier, Vitest (70%), Stryker
- Cross: CodeRabbit, Gitleaks, DevLake, Unleash

---

## Processing Results

After running the scout:

1. **Review findings** for accuracy and relevance to UnaMentis
2. **Create GitHub issues** for actionable items:
   ```bash
   gh issue create --title "Evaluate: [Tool Name]" \
     --body "Source: [URL]\n\nCategory: [Category]\n\nSummary: ...\n\nAction: ..." \
     --label "code-quality,evaluation"
   ```
3. **Update TECH_RADAR.md** if maintaining a technology radar
4. **Schedule evaluation** for high-priority findings
5. **Update this prompt** if new tools are adopted
