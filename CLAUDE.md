# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

UnaMentis is an iOS voice AI tutoring app built with Swift 6.0/SwiftUI. It enables 60-90+ minute voice-based learning sessions with sub-500ms latency. The project is developed with 100% AI assistance.

## Monorepo Structure

This repository contains multiple components, each with its own CLAUDE.md:

| Component | Location | Purpose |
|-----------|----------|---------|
| iOS App | `UnaMentis/` | Swift/SwiftUI voice tutoring client |
| Server | `server/` | Backend infrastructure |
| Management API | `server/management/` | Python/aiohttp backend API (port 8766) |
| UnaMentis Server | `server/web/` | Next.js/React web interface (port 3000) |
| Importers | `server/importers/` | Curriculum import framework |
| Curriculum | `curriculum/` | UMCF format specification |

See the CLAUDE.md in each directory for component-specific instructions.

## Quick Commands

```bash
# iOS build
xcodebuild -project UnaMentis.xcodeproj -scheme UnaMentis \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run all tests
xcodebuild test -project UnaMentis.xcodeproj -scheme UnaMentis \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Quick tests
./scripts/test-quick.sh

# All tests
./scripts/test-all.sh

# Lint and format
./scripts/lint.sh
./scripts/format.sh

# Health check (lint + quick tests)
./scripts/health-check.sh
```

## MANDATORY: Definition of Done

**NO IMPLEMENTATION IS COMPLETE UNTIL TESTS PASS.** This is the single most important rule.

### The Golden Rule
You MUST run `./scripts/test-quick.sh` (or `./scripts/test-all.sh` for significant changes) and verify ALL tests pass BEFORE:
- Telling the user the work is "done" or "complete"
- Summarizing what you accomplished
- Moving on to the next task
- Committing any changes

### What "Complete" Means
1. Code is written and compiles
2. `./scripts/lint.sh` passes with no violations
3. `./scripts/test-quick.sh` passes with ALL tests green
4. You have ACTUALLY RUN these commands and seen the results yourself

### Failure Mode to Avoid
**WRONG:** Write code, see it compiles, tell user "implementation is complete"
**RIGHT:** Write code, run tests, verify all pass, THEN tell user "implementation is complete"

If you tell the user "tests are passing" or "implementation is complete" when tests are actually failing, you have failed at your job. Always verify by running tests locally.

### Pre-Commit Checklist
```bash
./scripts/lint.sh && ./scripts/test-quick.sh
```

If either command fails, fix the issues before proceeding.

## Key Technical Requirements

**Testing Philosophy (Real Over Mock):**
- Only mock paid external APIs (LLM, STT, TTS, Embeddings)
- Use real implementations for all internal services
- See `AGENTS.md` for detailed testing philosophy

**Performance Targets:**
- E2E turn latency: <500ms (median), <1000ms (P99)
- Memory growth: <50MB over 90 minutes
- Session stability: 90+ minutes without crashes

## Multi-Agent Coordination

Check `docs/TASK_STATUS.md` before starting work. Claim tasks before working to prevent conflicts with other AI agents.

## Commit Convention

Follow Conventional Commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `perf:`, `ci:`, `chore:`

**BEFORE EVERY COMMIT:**
```bash
./scripts/lint.sh && ./scripts/test-quick.sh
```

Do NOT commit if either command fails. Fix the issues first.

## Key Documentation

- `docs/IOS_STYLE_GUIDE.md` - Mandatory iOS coding standards
- `docs/UnaMentis_TDD.md` - Technical design document
- `docs/TASK_STATUS.md` - Current task status
- `AGENTS.md` - AI development guidelines and testing philosophy
- `curriculum/README.md` - UMCF curriculum format
