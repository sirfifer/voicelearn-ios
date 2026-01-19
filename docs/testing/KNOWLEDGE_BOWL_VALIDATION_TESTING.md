# Knowledge Bowl Answer Validation Testing

**Comprehensive Testing Strategy and Documentation**

## Overview

The Knowledge Bowl answer validation system uses a multi-layered testing approach to ensure 95%+ code coverage and cross-platform parity between iOS and Android implementations.

## Test Coverage Requirements

**Minimum Coverage:** 95% on all validation-related files

**Coverage by Component:**
- Algorithm implementations: 100%
- Service implementations: 95%
- UI components: 90%
- Integration tests: 100% of critical paths

---

## Unit Tests (280+ Test Cases)

### 1. KBPhoneticMatcherTests (50+ tests)

**Location:** `UnaMentisTests/Unit/KnowledgeBowl/Validation/KBPhoneticMatcherTests.swift`

**Coverage:**
- Person name variations (Stephen/Steven, Catherine/Kathryn, etc.)
- Place names (Philadelphia/Filadelfia, Cincinnati/Cincinatti)
- Scientific terms (Photosynthesis/Fotosynthesis, Chemistry/Kemistry)
- Metaphone code generation
- Edge cases (empty strings, single characters)
- Non-matches (completely different words)
- Case insensitivity
- Performance benchmarks

**Run:**
```bash
xcodebuild test -scheme UnaMentis -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnaMentisTests/KBPhoneticMatcherTests
```

**Expected Results:**
- All 50+ tests pass
- Total execution time <500ms
- 100% code coverage on KBPhoneticMatcher.swift

---

### 2. KBNGramMatcherTests (50+ tests)

**Location:** `UnaMentisTests/Unit/KnowledgeBowl/Validation/KBNGramMatcherTests.swift`

**Coverage:**
- Character bigrams and trigrams
- Word bigrams
- Combined n-gram scoring
- Real-world examples (Mississippi, Philadelphia, etc.)
- Multi-word phrases
- Threshold testing (≥0.80)
- Edge cases
- Performance benchmarks

**Run:**
```bash
xcodebuild test -scheme UnaMentis -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnaMentisTests/KBNGramMatcherTests
```

**Expected Results:**
- All 50+ tests pass
- Total execution time <1s
- 100% code coverage on KBNGramMatcher.swift

---

### 3. KBTokenMatcherTests (50+ tests)

**Location:** `UnaMentisTests/Unit/KnowledgeBowl/Validation/KBTokenMatcherTests.swift`

**Coverage:**
- Jaccard similarity
- Dice coefficient
- Combined token scoring
- Word order variations
- Extra/missing words
- Stopword removal
- Tokenization edge cases
- Real-world examples (place names, person names)
- Threshold testing (≥0.80)
- Performance benchmarks

**Run:**
```bash
xcodebuild test -scheme UnaMentis -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnaMentisTests/KBTokenMatcherTests
```

**Expected Results:**
- All 50+ tests pass
- Total execution time <1s
- 100% code coverage on KBTokenMatcher.swift

---

### 4. KBSynonymDictionariesTests (100+ tests)

**Location:** `UnaMentisTests/Unit/KnowledgeBowl/Validation/KBSynonymDictionariesTests.swift`

**Coverage:**
- Place synonyms (30+ tests): USA/United States, UK/Great Britain, NYC/New York City
- Scientific synonyms (40+ tests): H2O/Water, CO2/Carbon Dioxide, DNA/Deoxyribonucleic Acid
- Historical synonyms (20+ tests): WWI/World War I, FDR/Franklin Roosevelt, NATO/North Atlantic Treaty Organization
- Mathematics synonyms (10+ tests): π/Pi, e/Euler's Number, √/Square Root
- Cross-domain non-matches
- Case insensitivity

**Run:**
```bash
xcodebuild test -scheme UnaMentis -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnaMentisTests/KBSynonymDictionariesTests
```

**Expected Results:**
- All 100+ tests pass
- Total execution time <2s
- 100% code coverage on KBSynonymDictionaries.swift

---

### 5. KBLinguisticMatcherTests (30+ tests)

**Location:** `UnaMentisTests/Unit/KnowledgeBowl/Validation/KBLinguisticMatcherTests.swift`

**Coverage:**
- Lemmatization (plurals, verbs, adjectives)
- Lemma equivalence
- Key term extraction
- Shared key terms
- Real-world examples (scientific, geographic, historical)
- Edge cases
- Performance benchmarks

**Run:**
```bash
xcodebuild test -scheme UnaMentis -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnaMentisTests/KBLinguisticMatcherTests
```

**Expected Results:**
- All 30+ tests pass
- Total execution time <1s
- 100% code coverage on KBLinguisticMatcher.swift

---

## Integration Tests

### Test Data

**Location:** `docs/knowledgebowl/validation_test_vectors.json`

**Format:**
```json
{
  "version": "1.0",
  "test_cases": [
    {
      "id": "phonetic_001",
      "category": "phonetic",
      "user_answer": "Stephen",
      "correct_answer": "Steven",
      "answer_type": "person",
      "expected_match": true,
      "expected_tier": 1,
      "expected_algorithm": "phonetic"
    },
    {
      "id": "synonym_001",
      "category": "synonym",
      "user_answer": "USA",
      "correct_answer": "United States",
      "answer_type": "place",
      "expected_match": true,
      "expected_tier": 1,
      "expected_algorithm": "synonym"
    }
    // ... 1000+ test cases
  ]
}
```

### Test Case Categories

1. **Phonetic** (200 cases): Pronunciation-based matches
2. **N-gram** (200 cases): Spelling variations and transpositions
3. **Token** (200 cases): Word order and extra/missing words
4. **Synonym** (200 cases): Domain-specific synonyms
5. **Embeddings** (100 cases): Semantic meaning matches (Tier 2)
6. **LLM** (100 cases): Complex semantic matches (Tier 3)

### Running Integration Tests

**iOS:**
```bash
./scripts/test-integration.sh
```

**Android:**
```bash
cd /Users/ramerman/dev/unamentis-android
./gradlew connectedAndroidTest
```

**Expected Results:**
- Tier 1: 85-90% accuracy on test set
- Tier 2: 92-95% accuracy on test set
- Tier 3: 95-98% accuracy on test set

---

## Performance Tests

### Benchmarking Suite

**Location:** `UnaMentisTests/Performance/KBAnswerValidationPerformanceTests.swift`

**Benchmarks:**

```swift
// Individual algorithms
func testPerformance_PhoneticMatching() {
    measure {
        _ = phoneticMatcher.arePhoneticMatch("Christopher", "Kristopher")
    }
    // Expected: <2ms
}

func testPerformance_NGramMatching() {
    measure {
        _ = ngramMatcher.nGramScore("Mississippi", "Missisipi")
    }
    // Expected: <3ms
}

func testPerformance_TokenMatching() {
    measure {
        _ = tokenMatcher.tokenScore("United States", "States United")
    }
    // Expected: <2ms
}

// Full validation chain
func testPerformance_FullValidation_Tier1() {
    measure {
        _ = validator.validate(userAnswer: "Missisipi", question: question)
    }
    // Expected: <50ms
}

func testPerformance_FullValidation_Tier2() {
    measure {
        _ = validator.validate(userAnswer: "water", question: question)
    }
    // Expected: <80ms
}

func testPerformance_FullValidation_Tier3() {
    measure {
        _ = validator.validate(userAnswer: "powerhouse of the cell", question: question)
    }
    // Expected: <250ms
}

// Stress tests
func testPerformance_1000Validations() {
    measure {
        for testCase in testCases {
            _ = validator.validate(userAnswer: testCase.user, question: testCase.question)
        }
    }
    // Expected: <50s for 1000 validations (50ms avg)
}
```

### Performance Targets

| Component | Target Latency |
|-----------|----------------|
| Phonetic matching | <2ms |
| N-gram matching | <3ms |
| Token matching | <2ms |
| Synonym lookup | <1ms |
| Linguistic matching | <5ms |
| **Tier 1 total** | **<50ms** |
| Embeddings inference | 10-30ms |
| **Tier 2 total** | **<80ms** |
| LLM inference | 50-200ms |
| **Tier 3 total** | **<250ms** |

### Memory Benchmarks

```swift
func testMemory_Tier1() {
    // Expected: <10MB additional memory
}

func testMemory_Tier2_ModelLoaded() {
    // Expected: ~200MB with model loaded
}

func testMemory_Tier3_ModelLoaded() {
    // Expected: ~2GB with model loaded
}

func testMemory_ModelUnload() {
    // Verify memory released after unload
}
```

---

## Cross-Platform Parity Testing

### Test Vector Validation

**Script:** `scripts/test-model-parity.sh`

```bash
#!/bin/bash
# Test model parity between iOS and Android

# Run iOS tests and export results
xcodebuild test -scheme UnaMentis \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:UnaMentisTests/KBAnswerValidationIntegrationTests | \
  grep "PASS\|FAIL" > ios_results.txt

# Run Android tests and export results
cd /Users/ramerman/dev/unamentis-android
./gradlew connectedAndroidTest | \
  grep "PASS\|FAIL" > android_results.txt

# Compare results
python3 scripts/compare_results.py ios_results.txt android_results.txt

# Expected: <2% accuracy difference, <5% algorithm-level difference
```

### Parity Checks

1. **Algorithm Outputs:** iOS and Android algorithms produce matching outputs (±5% tolerance)
2. **Model Accuracy:** Embeddings models achieve similar accuracy (<2% difference)
3. **Validation Results:** Same test cases produce same results (±2% tolerance)

---

## Edge Case Tests

**Location:** `UnaMentisTests/Unit/KnowledgeBowl/Validation/KBAnswerValidatorEdgeCaseTests.swift`

**Test Cases:**
- Empty user answer
- Extremely long answers (>500 chars)
- Special characters and emojis
- Non-English characters
- Numbers in scientific notation
- Dates in unusual formats
- Multiple acceptable answers with different types
- Null/undefined values
- Concurrent validation requests
- Model load failures
- Network failures during download
- Out-of-memory conditions

---

## Regression Tests

**Purpose:** Ensure existing functionality remains intact

**Coverage:**
- All existing exact matches still work
- All existing acceptable alternatives still work
- All existing Levenshtein fuzzy matches still work
- Config presets (strict/standard/lenient) still work
- MCQ validation still works
- Regional strictness enforcement still works

---

## Continuous Integration

### GitHub Actions Workflow

```yaml
name: Validation Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run unit tests
        run: ./scripts/test-all.sh

  integration-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run integration tests
        run: ./scripts/test-integration.sh

  performance-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run performance tests
        run: ./scripts/test-performance.sh

  coverage:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Check coverage
        run: ./scripts/test-coverage.sh
      - name: Verify 95% coverage
        run: |
          COVERAGE=$(cat coverage.txt | grep "Total" | awk '{print $3}')
          if (( $(echo "$COVERAGE < 95" | bc -l) )); then
            echo "Coverage $COVERAGE% is below 95%"
            exit 1
          fi
```

---

## Test Execution Guide

### Run All Tests

```bash
./scripts/test-all.sh
```

### Run Specific Test Suites

```bash
# Unit tests only
./scripts/test-quick.sh

# Integration tests
./scripts/test-integration.sh

# Performance tests
./scripts/test-performance.sh

# Coverage report
./scripts/test-coverage.sh
```

### Test on Device

```bash
# iOS
xcodebuild test -scheme UnaMentis \
  -destination 'platform=iOS,name=Your iPhone'

# Android
cd /Users/ramerman/dev/unamentis-android
./gradlew connectedAndroidTest
```

---

## Success Criteria

**Unit Tests:**
- ✅ 280+ tests pass
- ✅ 95%+ code coverage on all algorithm files
- ✅ All performance benchmarks meet targets
- ✅ Zero regressions

**Integration Tests:**
- ✅ Tier 1: 85-90% accuracy on 1000 Q&A test pairs
- ✅ Tier 2: 92-95% accuracy on 1000 Q&A test pairs
- ✅ Tier 3: 95-98% accuracy on 1000 Q&A test pairs
- ✅ <250ms total validation time

**Cross-Platform Parity:**
- ✅ iOS and Android results differ by <2% accuracy
- ✅ Algorithm outputs match within 5% tolerance
- ✅ All test vectors produce consistent results

---

## See Also

- [Answer Validation API Documentation](../modules/KNOWLEDGE_BOWL_ANSWER_VALIDATION.md)
- [Knowledge Bowl Module Documentation](../modules/KNOWLEDGE_BOWL_MODULE.md)
- [Enhanced Validation User Guide](../user-guides/KNOWLEDGE_BOWL_ENHANCED_VALIDATION.md)
