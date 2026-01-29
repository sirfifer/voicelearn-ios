# KB Audio Test Harness

Component documentation for Claude Code.

## Overview

The KB Audio Test Harness enables iterative testing of the Knowledge Bowl audio Q&A pipeline in the iOS Simulator. It allows you to:

1. Generate TTS audio from expected answers
2. Inject audio directly into STT (bypassing microphone)
3. Get transcript from STT
4. Validate transcript against expected answer semantically
5. Report detailed results with per-phase latencies

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    KBAudioTestHarness (coordinator)                  │
└─────────────────────────────────────────────────────────────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        ▼                          ▼                          ▼
┌───────────────┐        ┌─────────────────┐        ┌─────────────────┐
│ KBAudioGenerator│       │ KBAudioInjector │        │KBTranscriptValidator│
│ (TTS → Buffer) │        │ (Buffer → STT)  │        │ (Answer Matching)│
└───────────────┘        └─────────────────┘        └─────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `KBAudioTestHarness.swift` | Main coordinator actor |
| `KBAudioTestCase.swift` | Test case definition and configuration |
| `KBAudioTestResult.swift` | Result model with detailed metrics |
| `KBAudioGenerator.swift` | TTS audio generation and file loading |
| `KBAudioInjector.swift` | Audio buffer injection into STT |
| `KBTranscriptValidator.swift` | Semantic validation of transcripts |

## Quick Start

```swift
// Create test harness
let harness = KBAudioTestHarness()

// Simple test
let result = try await harness.quickTest(
    question: "What is the capital of France?",
    answer: "Paris"
)

print("Success: \(result.isSuccess)")
print("Transcribed: \(result.transcribedText)")
print("Confidence: \(result.validationResult.confidence)")
```

## Test Case Creation

### Simple Test Case

```swift
let testCase = KBAudioTestCase.simple(
    questionText: "What is the capital of France?",
    expectedAnswer: "Paris",
    answerType: .place
)
```

### From KBQuestion

```swift
let testCase = KBAudioTestCase(
    question: myKBQuestion,
    audioSource: .generateTTS(provider: .appleTTS),
    validationConfig: .standard
)
```

### From Question Set

```swift
let testCases = KBAudioTestCase.fromQuestions(
    myQuestions,
    audioSource: .generateTTS(provider: .appleTTS)
)
```

## Audio Sources

| Source | Description |
|--------|-------------|
| `.generateTTS(provider:)` | Generate audio via TTS |
| `.prerecordedFile(path:)` | Load from file path |
| `.prerecordedBundle(name:extension:)` | Load from app bundle |
| `.rawAudioData(data:format:)` | Use raw PCM data |

### Supported TTS Providers

For testing, on-device providers are preferred:
- `.appleTTS` - Apple TTS (always available)
- `.kyutaiPocket` - Kyutai Pocket neural TTS

## Validation Configuration

```swift
// Strict: exact/acceptable matches only
let strict = ValidationConfig.strict

// Standard: includes fuzzy matching (default)
let standard = ValidationConfig.standard

// Lenient: includes embeddings and LLM
let lenient = ValidationConfig.lenient

// Custom
let custom = ValidationConfig(
    minimumConfidence: 0.7,
    useFuzzyMatching: true,
    useEmbeddings: true,
    useLLMValidation: false,
    maxPipelineLatencyMs: 5000,
    timeoutSeconds: 30
)
```

## Running Tests

### Single Test

```swift
let result = try await harness.runTest(testCase)
```

### Test Suite

```swift
let suite = KBAudioTestSuite(
    name: "Geography Questions",
    testCases: geographyTestCases,
    repetitions: 3
)

let suiteResult = try await harness.runSuite(suite)
print(suiteResult.summary)
```

### Sample Tests (Debug)

```swift
#if DEBUG
let result = try await harness.runSampleTests()
#endif
```

## Result Analysis

### Single Result

```swift
let result = try await harness.runTest(testCase)

// Success check
if result.isSuccess {
    print("Passed!")
} else {
    print("Failed: \(result.errors)")
}

// Metrics
print("TTS latency: \(result.audioGenerationLatencyMs ?? 0)ms")
print("STT latency: \(result.sttLatencyMs)ms")
print("Validation: \(result.validationLatencyMs)ms")
print("Total: \(result.totalPipelineMs)ms")

// Validation details
print("Match type: \(result.validationResult.matchType)")
print("Confidence: \(result.validationResult.confidence)")
```

### Suite Result

```swift
let suiteResult = try await harness.runSuite(suite)

print("Pass rate: \(suiteResult.passRate * 100)%")
print("Avg pipeline: \(suiteResult.averagePipelineMs)ms")
print("Avg STT latency: \(suiteResult.averageSTTLatencyMs)ms")
print("Avg confidence: \(suiteResult.averageSTTConfidence)")
```

## Custom STT Service

By default, the harness uses on-device Apple Speech. To use a different STT:

```swift
let harness = KBAudioTestHarness(sttService: mySTTService)
// or
await harness.setSTTService(mySTTService)
```

## How It Works

### Audio Generation

1. For TTS sources: Uses `TTSService.synthesize()` to generate audio
2. Collects `TTSAudioChunk` stream into buffer
3. Converts to STT format (16kHz mono float32)

### Audio Injection

1. Chunks buffer into 100ms segments (1600 frames at 16kHz)
2. Starts STT streaming session
3. Sends chunks via `STTService.sendAudio()`
4. Stops streaming and collects final transcript

### Validation

Uses `KBAnswerValidator` with 3-tier validation:
- **Tier 1**: Rule-based (exact, acceptable, fuzzy, phonetic, n-gram)
- **Tier 2**: Embeddings similarity (optional)
- **Tier 3**: LLM judgment (optional)

## Simulator Testing

The harness is designed for Simulator testing:
- Bypasses microphone requirement
- Works without hardware audio
- Enables automated CI testing

## Performance Targets

- TTS generation: <500ms
- STT processing: <2000ms
- Validation: <100ms
- Total pipeline: <3000ms

## Troubleshooting

### No transcript returned

- Check STT service is available
- Verify audio format is correct (16kHz mono float32)
- Try with Apple TTS (most compatible)

### Low confidence scores

- Speech might be unclear (try Apple TTS)
- Expected answer might need alternatives
- Consider using `.lenient` validation

### Test timeouts

- Increase `timeoutSeconds` in ValidationConfig
- Check thermal state (throttling)
- Try simpler test cases first

## Related Files

- `UnaMentis/Services/KnowledgeBowl/KBAnswerValidator.swift` - Validation logic
- `UnaMentis/Testing/LatencyHarness/LatencyTestCoordinator.swift` - Reference pattern
- `UnaMentis/Services/Protocols/STTService.swift` - STT protocol
- `UnaMentis/Services/Protocols/TTSService.swift` - TTS protocol
