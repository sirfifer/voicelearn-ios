# Testing Guide

Testing philosophy and practices for UnaMentis.

## Philosophy: Real Over Mock

UnaMentis follows a "Real Over Mock" testing philosophy:

> Only mock paid external APIs. Use real implementations for everything else.

### What to Mock

- LLM APIs (OpenAI, Anthropic)
- STT APIs (Deepgram, AssemblyAI)
- TTS APIs (ElevenLabs)
- Embedding APIs

### What NOT to Mock

- Internal services
- Database operations
- File system operations
- Local computations
- Audio processing (use test files)

## Test Commands

### Quick Tests (Daily Development)

```bash
./scripts/test-quick.sh
```

Runs unit tests only. Fast feedback loop.

### Full Test Suite

```bash
./scripts/test-all.sh
```

Runs all tests with 80% coverage enforcement.

### Integration Tests

```bash
./scripts/test-integration.sh
```

Tests component interactions.

### Health Check

```bash
./scripts/health-check.sh
```

Runs lint + quick tests. Use before committing.

### Validation (Definition of Done)

```bash
/validate           # Lint + quick tests
/validate --full    # Lint + full tests + coverage
```

**No implementation is complete until `/validate` passes.**

## iOS Tests

### Running from Xcode

1. Open `UnaMentis.xcodeproj`
2. Press `Cmd+U` to run all tests
3. Or right-click a test file and select "Run Tests"

### Running from Command Line

```bash
# All tests
xcodebuild test -project UnaMentis.xcodeproj \
  -scheme UnaMentis \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Specific test class
xcodebuild test -project UnaMentis.xcodeproj \
  -scheme UnaMentis \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnaMentisTests/SessionManagerTests
```

### Test Structure

```
UnaMentisTests/
├── Core/
│   ├── SessionManagerTests.swift
│   ├── AudioEngineTests.swift
│   └── CurriculumEngineTests.swift
├── Services/
│   ├── STTServiceTests.swift
│   ├── TTSServiceTests.swift
│   └── LLMServiceTests.swift
├── Integration/
│   └── VoicePipelineIntegrationTests.swift
└── Mocks/
    └── MockProviders.swift
```

### Writing Tests

```swift
final class SessionManagerTests: XCTestCase {

    var sut: SessionManager!  // System Under Test

    override func setUp() async throws {
        sut = SessionManager(
            audio: MockAudioEngine(),
            stt: MockSTTService(),
            llm: MockLLMService(),
            tts: MockTTSService()
        )
    }

    override func tearDown() async throws {
        sut = nil
    }

    func testStartSession_setsStateToUserSpeaking() async throws {
        // Given
        XCTAssertEqual(await sut.state, .idle)

        // When
        await sut.startSession()

        // Then
        XCTAssertEqual(await sut.state, .userSpeaking)
    }
}
```

## Python Tests

### Running Tests

```bash
cd server/management

# All tests
python -m pytest tests/ -v

# Specific file
python -m pytest tests/test_tts_cache.py -v

# With coverage
python -m pytest tests/ --cov=. --cov-report=html
```

### Test Structure

```
server/management/tests/
├── test_server.py
├── test_tts_cache.py
├── test_session_integration.py
└── conftest.py  # Shared fixtures
```

### Writing Tests

```python
import pytest
from tts_cache import TTSCache

@pytest.fixture
async def cache():
    cache = TTSCache(cache_dir="/tmp/test_cache")
    yield cache
    await cache.clear()

@pytest.mark.asyncio
async def test_cache_stores_and_retrieves(cache):
    # Given
    key = "test_key"
    data = b"test audio data"

    # When
    await cache.store(key, data)
    result = await cache.get(key)

    # Then
    assert result == data
```

## Web Tests

### Operations Console

```bash
cd server/web
npm test
npm run test:coverage
```

### Web Client

```bash
cd server/web-client
pnpm test
pnpm test:coverage
pnpm test:e2e  # Playwright E2E tests
```

## Latency Testing

### CLI Commands

```bash
# List suites
python -m latency_harness.cli --list-suites

# Quick validation (mock)
python -m latency_harness.cli --suite quick_validation --mock

# Real providers
python -m latency_harness.cli --suite quick_validation --no-mock
```

### Performance Targets

| Metric | Target (Median) | Target (P99) |
|--------|-----------------|--------------|
| E2E Latency | <500ms | <1000ms |
| STT | <300ms | <1000ms |
| LLM TTFT | <200ms | <500ms |
| TTS TTFB | <200ms | <400ms |

## Coverage Requirements

| Component | Minimum Coverage |
|-----------|-----------------|
| iOS App | 80% |
| Management API | 80% |
| Operations Console | 70% |
| Web Client | 70% |

## CI/CD Integration

Tests run automatically on:
- Every push to main/develop
- Every pull request
- Nightly (full E2E suite)

See [[GitHub-Actions]] for workflow details.

## Mutation Testing

Weekly mutation testing validates test quality:

- **Python**: mutmut
- **Web**: Stryker
- **iOS**: Muter (manual)

## Chaos Engineering

Voice pipeline resilience testing:

- Network degradation
- API failures
- Resource pressure

See `docs/testing/CHAOS_ENGINEERING_RUNBOOK.md`.

## Related Pages

- [[Development]] - Development workflows
- [[iOS-Development]] - iOS testing details
- [[Server-Development]] - Server testing
- [[GitHub-Actions]] - CI/CD workflows

---

Back to [[Home]]
