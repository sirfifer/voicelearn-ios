# Knowledge Bowl Answer Validation API

**Version:** 1.0
**Last Updated:** 2026-01-19

## Overview

The Knowledge Bowl answer validation system provides a three-tiered approach to fuzzy answer matching, achieving up to 98% accuracy while respecting regional strictness requirements and device capabilities.

### Accuracy Targets by Tier

- **Tier 1 (All devices):** 85-90% accuracy (enhanced algorithms, 0 bytes)
- **Tier 2 (iPhone XS+/Android 8.0+):** 92-95% accuracy (sentence embeddings, 80MB optional)
- **Tier 3 (iPhone 12+/Android 10+):** 95-98% accuracy (open-source LLM, 1.5GB, server admin controlled)

### Regional Strictness

The system respects regional competition rules via `KBValidationStrictness`:

- `.strict` (Colorado): Exact + Levenshtein fuzzy only
- `.standard` (Minnesota, Washington): + phonetic + n-gram + token + linguistic
- `.lenient` (Practice mode): + semantic (embeddings, LLM)

---

## Tier 1: Enhanced Rule-Based Algorithms

### 1. Phonetic Matching (Double Metaphone)

**Purpose:** Catch pronunciation-based STT errors

**Algorithm:** Double Metaphone with primary and secondary codes

**Examples:**
- "Stephen" ↔ "Steven" ✓
- "Catherine" ↔ "Kathryn" ✓
- "Philadelphia" ↔ "Filadelfia" ✓

**API:**

```swift
actor KBPhoneticMatcher {
    /// Generate Double Metaphone codes
    nonisolated func metaphone(_ text: String) -> (primary: String, secondary: String?)

    /// Check if two strings match phonetically
    nonisolated func arePhoneticMatch(_ str1: String, _ str2: String) -> Bool
}
```

**Performance:** <2ms per call
**Threshold:** Phonetic match = correct

---

### 2. N-Gram Similarity

**Purpose:** Handle transpositions, missing characters, spelling variations

**Algorithm:** Jaccard similarity of character bigrams (40%), trigrams (40%), word bigrams (20%)

**Examples:**
- "Mississippi" ↔ "Missisipi" (score: 0.85) ✓
- "Connecticut" ↔ "Conneticut" (score: 0.82) ✓
- "Photosynthesis" ↔ "Fotosynthesis" (score: 0.88) ✓

**API:**

```swift
actor KBNGramMatcher {
    /// Character n-gram similarity
    nonisolated func characterNGramSimilarity(_ str1: String, _ str2: String, n: Int) -> Float

    /// Word n-gram similarity
    nonisolated func wordNGramSimilarity(_ str1: String, _ str2: String, n: Int) -> Float

    /// Combined weighted score
    nonisolated func nGramScore(_ str1: String, _ str2: String) -> Float
}
```

**Performance:** <3ms per call
**Threshold:** ≥0.80 similarity = correct

---

### 3. Token-Based Similarity

**Purpose:** Handle word order variations, extra/missing words

**Algorithm:** Average of Jaccard and Dice coefficients on tokenized words (stopwords removed)

**Examples:**
- "United States of America" ↔ "United States" (score: 0.67) ✓
- "States United" ↔ "United States" (score: 1.0) ✓
- "The Great Gatsby" ↔ "Great Gatsby" (score: 1.0) ✓

**Stopwords Removed:** the, a, an, of, in, at, on, to, for, with, by, from

**API:**

```swift
actor KBTokenMatcher {
    /// Jaccard similarity (intersection / union)
    nonisolated func jaccardSimilarity(_ str1: String, _ str2: String) -> Float

    /// Dice coefficient (2 * intersection / sum)
    nonisolated func diceSimilarity(_ str1: String, _ str2: String) -> Float

    /// Combined score (average of Jaccard + Dice)
    nonisolated func tokenScore(_ str1: String, _ str2: String) -> Float
}
```

**Performance:** <2ms per call
**Threshold:** ≥0.80 similarity = correct

---

### 4. Domain-Specific Synonyms

**Purpose:** Handle common abbreviations and alternative names

**Examples:**
- "USA" ↔ "United States" ✓
- "CO2" ↔ "Carbon Dioxide" ✓
- "WWI" ↔ "World War I" ✓
- "π" ↔ "Pi" ✓

**Domains:**
- **Places:** ~200 entries (USA, UK, NYC, SF, etc.)
- **Scientific:** ~200 entries (H2O, CO2, DNA, elements, etc.)
- **Historical:** ~150 entries (WWI, FDR, JFK, etc.)
- **Mathematics:** ~100 entries (pi, e, phi, trig functions)

**API:**

```swift
actor KBSynonymMatcher {
    /// Find all synonyms for text in domain
    nonisolated func findSynonyms(_ text: String, for type: KBAnswerType) -> Set<String>

    /// Check if two strings are synonyms
    nonisolated func areSynonyms(_ str1: String, _ str2: String, for type: KBAnswerType) -> Bool
}
```

**Performance:** <1ms per lookup
**Storage:** ~15KB total

---

### 5. Linguistic Matching (iOS Only)

**Purpose:** Lemmatization and POS tagging using Apple Natural Language framework

**Examples:**
- "running" ↔ "run" ✓
- "cats" ↔ "cat" ✓
- "better" ↔ "good" ✓

**API:**

```swift
actor KBLinguisticMatcher {
    /// Lemmatize text (reduce to base forms)
    nonisolated func lemmatize(_ text: String) -> String

    /// Extract key nouns and verbs
    nonisolated func extractKeyTerms(_ text: String) -> [String]

    /// Check if lemmatized forms match
    nonisolated func areLemmasEquivalent(_ str1: String, _ str2: String) -> Bool
}
```

**Performance:** <5ms per call
**Android Alternative:** Porter Stemmer (simpler algorithm)

---

## Tier 2: Semantic Embeddings

### Model Specifications

- **Model:** all-MiniLM-L6-v2 sentence transformer
- **Size:** 80MB (FP16 quantized)
- **Output:** 384-dimensional embeddings
- **Similarity:** Cosine similarity, threshold: 0.85

### Device Requirements

- **iOS:** iPhone XS+ (A12+) with 3GB+ RAM
- **Android:** 8.0+ with 3GB+ RAM

### API

```swift
actor KBEmbeddingsService {
    enum ModelState: Sendable {
        case notDownloaded, downloading(Float), available, loaded, error(String)
    }

    /// Download the embeddings model
    func downloadModel(progressHandler: @escaping (Float) -> Void) async throws

    /// Load model into memory
    func loadModel() async throws

    /// Unload model from memory
    func unloadModel()

    /// Generate 384-dim embedding for text
    func embed(_ text: String) async throws -> [Float]

    /// Compute cosine similarity between two texts
    func similarity(_ text1: String, _ text2: String) async throws -> Float
}
```

### Performance

- **Inference:** 10-30ms per embedding
- **Memory:** ~200MB with model loaded
- **Threshold:** ≥0.85 similarity = correct

### Model Packaging

**iOS:** CoreML (.mlpackage)
```
UnaMentis/Assets/ML/sentence_embeddings_v1.mlpackage/
```

**Android:** TensorFlow Lite (.tflite)
```
app/src/main/assets/ml/sentence_embeddings_v1.tflite
```

---

## Tier 3: LLM Validation

### Model Specifications

- **Model:** Llama 3.2 1B (4-bit quantized)
- **Size:** ~1.5GB
- **Backend:** llama.cpp
- **Temperature:** 0.1 (deterministic validation)

### Device Requirements

- **iOS:** iPhone 12+ (A14+) with 4GB+ RAM
- **Android:** 10+ with 4GB+ RAM
- **Availability:** Controlled by server administrator via feature flags

### Validation Prompt

```
You are an expert Knowledge Bowl judge. Determine if the student's answer
is semantically equivalent to the correct answer.

Question: {question_text}
Correct Answer: {correct_answer}
Student Answer: {student_answer}
Answer Type: {answer_type}

Rules:
1. Accept answers that convey the same meaning
2. Accept common abbreviations and alternative names
3. Reject close but factually incorrect answers
4. Consider the answer type for domain-specific rules

Respond with exactly one word: "CORRECT" or "INCORRECT"

Your judgment:
```

### API

```swift
actor KBLLMValidator {
    enum ModelState: Sendable {
        case notDownloaded, downloading(Float), available, loaded, error(String)
    }

    /// Download the LLM model
    func downloadModel(progressHandler: @escaping (Float) -> Void) async throws

    /// Load model into memory
    func loadModel() async throws

    /// Unload model from memory
    func unloadModel()

    /// Validate answer using LLM
    func validate(
        userAnswer: String,
        correctAnswer: String,
        question: String,
        answerType: KBAnswerType
    ) async throws -> Bool
}
```

### Performance

- **Inference:** 50-200ms per validation
- **Memory:** ~2GB with model loaded
- **Accuracy:** 95-98%

### Feature Flag Control

Features are controlled by server administrators via the `KBFeatureFlags` actor. This allows server admins to enable/disable features based on their server's capabilities and policies.

```swift
actor KBFeatureFlags {
    enum Feature: String, Sendable, CaseIterable {
        case llmValidation = "kb_llm_validation"
        case customDictionaries = "kb_custom_dictionaries"
        case advancedAnalytics = "kb_advanced_analytics"
        case offlineMode = "kb_offline_mode"
    }

    /// Initialize from server configuration
    init(fromServerConfig config: [String: Bool])

    /// Check if server admin has enabled a feature
    nonisolated func isFeatureEnabled(_ feature: Feature) async -> Bool

    /// Check device capability for feature
    nonisolated func isDeviceCapable(for feature: Feature) -> Bool

    /// Get feature availability with reason
    nonisolated func featureAvailability(for feature: Feature) async -> (available: Bool, reason: String?)

    /// Preset configurations for server admins
    static func defaultConfiguration() -> KBFeatureFlags // All features enabled
    static func standardConfiguration() -> KBFeatureFlags // Tier 1 + 2
    static func minimalConfiguration() -> KBFeatureFlags // Tier 1 only
}
```

---

## Validation Fallback Chain

The `KBAnswerValidator` implements a complete fallback chain:

```
1. Exact primary match → confidence: 1.0, type: .exact
2. Acceptable alternatives → confidence: 1.0, type: .acceptable
3. Levenshtein fuzzy → confidence: 0.6-1.0, type: .fuzzy

[If strictness >= .standard:]
4. Synonym check → confidence: 0.95, type: .fuzzy
5. Phonetic check → confidence: 0.90, type: .fuzzy
6. N-gram check → confidence: 0.80-1.0, type: .fuzzy
7. Token similarity → confidence: 0.80-1.0, type: .fuzzy
8. Linguistic matching → confidence: 0.85, type: .fuzzy

[If strictness >= .lenient:]
9. Embeddings → confidence: 0.85-1.0, type: .ai
10. LLM → confidence: 0.98, type: .ai

11. No match → confidence: 0.0, type: .none
```

### API

```swift
actor KBAnswerValidator {
    struct Config: Sendable {
        var fuzzyThresholdPercent: Double = 0.20
        var minimumConfidence: Float = 0.6
        var strictMode: Bool = false
    }

    init(
        config: Config = .standard,
        strictness: KBValidationStrictness = .standard,
        phoneticMatcher: KBPhoneticMatcher? = KBPhoneticMatcher(),
        ngramMatcher: KBNGramMatcher? = KBNGramMatcher(),
        tokenMatcher: KBTokenMatcher? = KBTokenMatcher(),
        synonymMatcher: KBSynonymMatcher? = KBSynonymMatcher(),
        linguisticMatcher: KBLinguisticMatcher? = KBLinguisticMatcher(),
        embeddingsService: KBEmbeddingsService? = nil,
        llmValidator: KBLLMValidator? = nil,
        featureFlags: KBFeatureFlags? = nil
    )

    /// Validate user answer against question
    nonisolated func validate(userAnswer: String, question: KBQuestion) -> KBValidationResult

    /// Validate MCQ selection
    nonisolated func validateMCQ(selectedIndex: Int, question: KBQuestion) -> KBValidationResult
}
```

### Validation Result

```swift
struct KBValidationResult: Sendable {
    let isCorrect: Bool
    let confidence: Float        // 0.0-1.0
    let matchType: KBMatchType   // .exact, .acceptable, .fuzzy, .ai, .none
    let matchedAnswer: String?   // The answer that matched

    var pointsEarned: Int {
        isCorrect ? 1 : 0
    }
}
```

---

## Device Capability Detection

```swift
enum DeviceCapability {
    /// Get device model identifier
    static var modelIdentifier: String

    /// Get model number (e.g., iPhone13,2 -> 13)
    static var modelNumber: Int?

    /// Get available memory in MB
    static var availableMemoryMB: Int

    /// Check if device supports Tier 2 (embeddings)
    /// Requires iPhone XS+ (A12+) with 3GB+ RAM
    static func supportsEmbeddings() -> Bool

    /// Check if device supports Tier 3 (LLM)
    /// Requires iPhone 12+ (A14+) with 4GB+ RAM
    static func supportsLLMValidation() -> Bool

    /// Get maximum supported validation tier
    static var maxSupportedTier: Int  // 1, 2, or 3

    /// Get device description for UI
    static var deviceDescription: String
}
```

---

## Example Usage

### Basic Validation (Tier 1 Only)

```swift
let validator = KBAnswerValidator(
    config: .standard,
    strictness: .standard
)

let result = validator.validate(
    userAnswer: "Missisipi",
    question: question
)

if result.isCorrect {
    print("Correct! (confidence: \(result.confidence), type: \(result.matchType))")
} else {
    print("Incorrect")
}
```

### With Embeddings (Tier 2)

```swift
let embeddingsService = KBEmbeddingsService()
try await embeddingsService.downloadModel { progress in
    print("Download progress: \(progress)")
}
try await embeddingsService.loadModel()

let validator = KBAnswerValidator(
    strictness: .lenient,
    embeddingsService: embeddingsService
)

let result = validator.validate(userAnswer: "H2O", question: question)
```

### With LLM (Tier 3)

```swift
// Load feature flags from server configuration
let featureFlags = KBFeatureFlags.defaultConfiguration() // or fetch from server

let llmValidator = KBLLMValidator()
try await llmValidator.downloadModel { progress in
    print("Download progress: \(progress)")
}
try await llmValidator.loadModel()

let validator = KBAnswerValidator(
    strictness: .lenient,
    llmValidator: llmValidator,
    featureFlags: featureFlags
)

let result = validator.validate(userAnswer: "water", question: question)
```

---

## Performance Characteristics

| Component | Latency | Memory | Storage |
|-----------|---------|--------|---------|
| Exact match | <1ms | <1MB | 0 bytes |
| Levenshtein | <2ms | <1MB | 0 bytes |
| Phonetic | <2ms | <5MB | 0 bytes |
| N-gram | <3ms | <5MB | 0 bytes |
| Token | <2ms | <5MB | 0 bytes |
| Synonym | <1ms | <10MB | 15KB |
| Linguistic | <5ms | <10MB | 0 bytes |
| **Tier 1 Total** | **<50ms** | **<10MB** | **0 bytes** |
| Embeddings | 10-30ms | ~200MB | 80MB |
| **Tier 2 Total** | **<80ms** | **~200MB** | **80MB** |
| LLM | 50-200ms | ~2GB | 1.5GB |
| **Tier 3 Total** | **<250ms** | **~2GB** | **1.5GB** |

---

## Error Handling

All services use Swift's structured concurrency and throw appropriate errors:

```swift
enum EmbeddingsError: Error {
    case invalidURL
    case downloadFailed
    case modelNotFound
    case loadFailed(Error)
    case modelNotLoaded
    case invalidInput
    case invalidOutput
    case dimensionMismatch
}

enum LLMError: Error {
    case invalidURL
    case downloadFailed
    case modelNotFound
    case loadFailed(Error)
    case modelNotLoaded
    case inferenceFailed(String)
}
```

All validator methods are `nonisolated` for synchronous access where possible.

---

## See Also

- [Knowledge Bowl Module Documentation](KNOWLEDGE_BOWL_MODULE.md)
- [Enhanced Validation User Guide](../user-guides/KNOWLEDGE_BOWL_ENHANCED_VALIDATION.md)
- [Validation Testing Documentation](../testing/KNOWLEDGE_BOWL_VALIDATION_TESTING.md)
