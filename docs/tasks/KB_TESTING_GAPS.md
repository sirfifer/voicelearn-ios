# Knowledge Bowl Testing Gaps and Preventive Tests

**Status**: Documented for implementation
**Priority**: High
**Created**: 2026-01-18
**Related PR**: #53

## Overview

During the PR #53 review and actor conversion refactoring, several critical bugs were discovered that should have been caught by tests. This document identifies testing gaps and proposes preventive tests to catch similar issues in the future.

## Critical Bugs Found

### 1. KBOnDeviceTTS Continuation Leak (CRITICAL)
**Issue**: The `speechDidCancel` delegate callback set `completionHandler = nil` without calling `continuation.resume()`, causing the async `speak()` method to hang forever.

**Location**: KBOnDeviceTTS.swift, lines 211-222 (original code)

**Impact**:
- Memory leak (continuation never released)
- Deadlock (caller waiting forever for speak() to complete)
- Resource exhaustion if multiple TTS operations attempted

**Root Cause**: Missing continuation.resume() call in error/cancellation path

**Why Not Caught**:
- No tests for TTS cancellation behavior
- No tests for async/await completion guarantees
- No resource leak detection in test suite

### 2. Actor Isolation Violations (HIGH)
**Issue**: Services in Services/ directory were not actors, violating coding guidelines and Swift 6 concurrency safety.

**Affected Files**:
- KBAnswerValidator.swift - was `class`, should be `actor`
- KBOnDeviceSTT.swift - was `@MainActor class`, should be `actor` conforming to `STTService`
- KBOnDeviceTTS.swift - was `@MainActor class`, should be `actor`
- KBQuestionEngine.swift - still `@MainActor class` (deferred)

**Why Not Caught**:
- No static analysis enforcement of actor requirements
- No compilation warnings for non-actor services
- No architecture tests validating service structure

### 3. Data Race Risks (MEDIUM)
**Issue**: Non-Sendable types (AVSpeechUtterance, AVSpeechSynthesizer) being passed across actor boundaries

**Why Not Caught**:
- Swift 6 strict concurrency checking not enforced in CI
- No runtime concurrency sanitizer in tests

## Proposed Preventive Tests

### Test Suite 1: TTS Service Tests
**File**: `Tests/Services/KnowledgeBowl/KBOnDeviceTTSTests.swift`

```swift
import XCTest
@testable import UnaMentis

final class KBOnDeviceTTSTests: XCTestCase {
    var tts: KBOnDeviceTTS!

    override func setUp() async throws {
        tts = KBOnDeviceTTS()
    }

    // CRITICAL: Test continuation completion in all paths
    func testSpeakCompletesWithinTimeout() async throws {
        let expectation = expectation(description: "speak completes")

        Task {
            await tts.speak("Test")
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)
    }

    // CRITICAL: Test cancellation doesn't leak
    func testCancelDoesNotLeak() async throws {
        let expectation = expectation(description: "speak cancelled without hanging")

        Task {
            async let _ = tts.speak("Long text...")
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            await tts.stop() // Should resume continuation
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // CRITICAL: Test multiple rapid calls don't deadlock
    func testRapidCallsDoNotDeadlock() async throws {
        for i in 0..<10 {
            await tts.speak("Test \(i)")
        }
        // If we get here without timeout, test passes
    }

    // Test state consistency
    func testStateConsistentAfterSpeech() async throws {
        await tts.speak("Test")
        let isSpeaking = await tts.isSpeaking
        XCTAssertFalse(isSpeaking, "Should not be speaking after completion")
    }

    // Test state consistent after cancellation
    func testStateConsistentAfterCancellation() async throws {
        Task {
            async let _ = tts.speak("Test")
            try? await Task.sleep(nanoseconds: 100_000_000)
            await tts.stop()
        }

        try? await Task.sleep(nanoseconds: 200_000_000)
        let isSpeaking = await tts.isSpeaking
        let progress = await tts.progress

        XCTAssertFalse(isSpeaking)
        XCTAssertEqual(progress, 0)
    }
}
```

### Test Suite 2: STT Service Tests
**File**: `Tests/Services/KnowledgeBowl/KBOnDeviceSTTTests.swift`

```swift
final class KBOnDeviceSTTTests: XCTestCase {
    var stt: KBOnDeviceSTT!

    override func setUp() async throws {
        stt = KBOnDeviceSTT()
    }

    // Test stream cleanup
    func testStreamingStopsCleanly() async throws {
        // Mock audio format
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        let stream = try await stt.startStreaming(audioFormat: format)
        try? await Task.sleep(nanoseconds: 100_000_000)
        try await stt.stopStreaming()

        let isStreaming = await stt.isStreaming
        XCTAssertFalse(isStreaming)
    }

    // Test cancellation
    func testCancellationCleanup() async throws {
        let format = AVAudioFormat(...)!
        let stream = try await stt.startStreaming(audioFormat: format)

        await stt.cancelStreaming()

        let isStreaming = await stt.isStreaming
        XCTAssertFalse(isStreaming)
    }

    // Test multiple start/stop cycles
    func testMultipleStartStopCycles() async throws {
        let format = AVAudioFormat(...)!

        for _ in 0..<5 {
            _ = try await stt.startStreaming(audioFormat: format)
            try? await Task.sleep(nanoseconds: 100_000_000)
            try await stt.stopStreaming()
        }

        // Should not crash or leak
    }
}
```

### Test Suite 3: Answer Validator Tests
**File**: `Tests/Services/KnowledgeBowl/KBAnswerValidatorTests.swift`

```swift
final class KBAnswerValidatorTests: XCTestCase {
    var validator: KBAnswerValidator!

    override func setUp() {
        validator = KBAnswerValidator()
    }

    // Test exact match
    func testExactMatch() {
        let question = KBQuestion(
            text: "What is 2+2?",
            answer: KBAnswer(primary: "4", answerType: .number),
            domain: .mathematics
        )

        let result = validator.validate(userAnswer: "4", question: question)
        XCTAssertTrue(result.isCorrect)
        XCTAssertEqual(result.matchType, .exact)
    }

    // Test fuzzy match
    func testFuzzyMatch() {
        let question = KBQuestion(
            text: "Who wrote Hamlet?",
            answer: KBAnswer(primary: "William Shakespeare", answerType: .person),
            domain: .literature
        )

        let result = validator.validate(userAnswer: "Shakespear", question: question)
        XCTAssertTrue(result.isCorrect)
        XCTAssertEqual(result.matchType, .fuzzy)
    }

    // Test normalization
    func testNormalization() {
        let question = KBQuestion(
            text: "Capital of USA?",
            answer: KBAnswer(primary: "Washington DC", answerType: .place),
            domain: .socialStudies
        )

        let result1 = validator.validate(userAnswer: "washington dc", question: question)
        let result2 = validator.validate(userAnswer: "Washington, DC", question: question)
        let result3 = validator.validate(userAnswer: "Washington D.C.", question: question)

        XCTAssertTrue(result1.isCorrect)
        XCTAssertTrue(result2.isCorrect)
        XCTAssertTrue(result3.isCorrect)
    }

    // Test thread safety (validator is actor)
    func testConcurrentValidation() async {
        let question = KBQuestion(...)

        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let result = await self.validator.validate(
                        userAnswer: "test \(i)",
                        question: question
                    )
                    return result.isCorrect
                }
            }
        }

        // Should not crash
    }
}
```

### Test Suite 4: Architecture Tests
**File**: `Tests/Architecture/ServiceActorTests.swift`

```swift
import XCTest
@testable import UnaMentis

/// Tests that enforce architectural requirements for services
final class ServiceActorTests: XCTestCase {

    // CRITICAL: All services in Services/ must be actors
    func testAllServicesAreActors() throws {
        // This test uses reflection to verify all types in Services/ directory
        // are actors or have @MainActor annotation with documented reason

        let bundle = Bundle(for: type(of: self))
        // Use Mirror and Swift metadata to check type conformance

        // Example assertions:
        // XCTAssertTrue(KBAnswerValidator.self is Actor.Type)
        // XCTAssertTrue(KBOnDeviceSTT.self is Actor.Type)
        // XCTAssertTrue(KBOnDeviceTTS.self is Actor.Type)

        // For @MainActor exceptions, verify they have documentation explaining why
    }

    // Test STTService protocol conformance
    func testSTTServicesConformToProtocol() {
        XCTAssertTrue(KBOnDeviceSTT.self is STTService.Type)
    }

    // Test actor isolation
    func testServicesAreIsolated() {
        // Verify services don't have non-Sendable mutable state exposed
    }
}
```

### Test Suite 5: Concurrency Safety Tests
**File**: `Tests/Concurrency/DataRaceTests.swift`

```swift
/// Tests to catch data races and concurrency issues
final class DataRaceTests: XCTestCase {

    // Test concurrent access to actor state
    func testConcurrentActorAccess() async {
        let tts = KBOnDeviceTTS()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    await tts.speak("Test \(i)")
                }

                group.addTask {
                    let _ = await tts.isSpeaking
                    let _ = await tts.progress
                }
            }
        }

        // Should not crash with Thread Sanitizer
    }

    // Test MainActor property access
    func testMainActorPropertyAccess() async {
        let tts = KBOnDeviceTTS()

        // All MainActor access should be through MainActor.run or marked await
        await MainActor.run {
            // Access @MainActor properties
        }
    }
}
```

## Test Infrastructure Improvements

### 1. Enable Strict Concurrency Checking in CI
**File**: `.github/workflows/test.yml`

Add Swift compiler flags:
```yaml
- name: Run Tests
  run: |
    swift test -Xswiftc -strict-concurrency=complete
```

### 2. Enable Thread Sanitizer
**File**: `scripts/test-all.sh`

```bash
xcodebuild test \
  -enableThreadSanitizer YES \
  ...
```

### 3. Add Memory Leak Detection
Use Instruments or XCTest memory leak detection:

```swift
// In test tearDown
override func tearDown() async throws {
    // Force cleanup
    tts = nil

    // Verify no leaks
    XCTAssertNoLeak()
}
```

### 4. Add Performance Tests
```swift
func testSpeakPerformance() async throws {
    measure {
        await tts.speak("Performance test")
    }
}
```

## CI/CD Integration

### Required CI Checks
1. ✅ All unit tests pass
2. ✅ Strict concurrency checking enabled
3. ✅ Thread Sanitizer passes
4. ✅ Architecture tests pass
5. ✅ No memory leaks detected
6. ✅ Performance regression tests pass

### Pre-commit Hooks
Add to `.git/hooks/pre-commit`:
```bash
#!/bin/bash
# Run quick tests before allowing commit
./scripts/test-quick.sh
if [ $? -ne 0 ]; then
    echo "Tests failed. Commit aborted."
    exit 1
fi
```

## Static Analysis

### SwiftLint Rules
Add to `.swiftlint.yml`:
```yaml
custom_rules:
  actor_services:
    name: "Services must be actors"
    regex: '^(class|struct)\s+\w+(Service|Validator|Engine)\s*:'
    match_kinds:
      - keyword
    message: "Services should be actors for thread safety"
    severity: error
```

### CodeQL Queries
Create custom query to detect continuation leaks:
```ql
// Detect CheckedContinuation that might not be resumed
import swift

from CheckedContinuation c
where not exists(CallExpr call | call.getTarget().getName() = "resume")
select c, "Continuation might not be resumed in all paths"
```

## Testing Best Practices

### For Actors
1. Always test all state transitions
2. Test concurrent access patterns
3. Test cleanup and resource release
4. Verify state consistency after errors
5. Test with Task cancellation

### For Continuations
1. Always test completion within timeout
2. Test cancellation path
3. Test error path
4. Verify continuation resumed exactly once
5. Test resource cleanup on completion/cancellation

### For UI Integration
1. Test actor -> UI state updates
2. Test polling patterns
3. Test AsyncStream consumption
4. Test UI responsiveness during actor operations

## Implementation Priority

1. **HIGH**: TTS/STT service tests (catch continuation leaks)
2. **HIGH**: Architecture tests (enforce actor requirements)
3. **MEDIUM**: Answer validator tests (correctness)
4. **MEDIUM**: Concurrency safety tests (Thread Sanitizer)
5. **LOW**: Performance tests

## Success Metrics

- [ ] 80%+ test coverage on all Knowledge Bowl services
- [ ] Zero continuation leak bugs
- [ ] Zero data races detected by Thread Sanitizer
- [ ] All architecture requirements enforced by tests
- [ ] CI catches concurrency issues before merge

## Timeline

- Week 1: Implement TTS/STT service tests
- Week 2: Implement architecture tests
- Week 3: Implement concurrency safety tests
- Week 4: CI/CD integration and documentation

## Notes

- Consider using Swift Testing framework (new in Swift 5.9) for better async test support
- May want to create test utilities for common actor testing patterns
- Consider property-based testing for validator normalization logic
- Monitor for Swift Evolution proposals around actor testing improvements
