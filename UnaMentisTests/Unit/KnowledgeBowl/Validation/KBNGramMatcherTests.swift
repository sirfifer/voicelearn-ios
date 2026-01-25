//
//  KBNGramMatcherTests.swift
//  UnaMentisTests
//
//  Comprehensive unit tests for n-gram similarity matching
//  Target: 50+ test cases covering transpositions, spelling errors, variations
//

import XCTest
@testable import UnaMentis

@available(iOS 18.0, *)
final class KBNGramMatcherTests: XCTestCase {
    var matcher: KBNGramMatcher!

    override func setUp() async throws {
        try await super.setUp()
        matcher = KBNGramMatcher()
    }

    override func tearDown() async throws {
        matcher = nil
        try await super.tearDown()
    }

    // MARK: - Character Bigrams

    func testCharBigram_ExactMatch() {
        let score = matcher.characterNGramSimilarity("hello", "hello", n: 2)
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testCharBigram_OneCharDifference() {
        let score = matcher.characterNGramSimilarity("hello", "hallo", n: 2)
        XCTAssertGreaterThan(score, 0.6)
    }

    func testCharBigram_Transposition() {
        // "helol" vs "hello" - one transposition
        let score = matcher.characterNGramSimilarity("helol", "hello", n: 2)
        XCTAssertGreaterThan(score, 0.5)
    }

    func testCharBigram_MissingChar() {
        let score = matcher.characterNGramSimilarity("helo", "hello", n: 2)
        XCTAssertGreaterThan(score, 0.6)
    }

    func testCharBigram_ExtraChar() {
        let score = matcher.characterNGramSimilarity("helllo", "hello", n: 2)
        XCTAssertGreaterThan(score, 0.7)
    }

    // MARK: - Character Trigrams

    func testCharTrigram_ExactMatch() {
        let score = matcher.characterNGramSimilarity("mississippi", "mississippi", n: 3)
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testCharTrigram_OneMissingS() {
        let score = matcher.characterNGramSimilarity("mississippi", "missisippi", n: 3)
        XCTAssertGreaterThan(score, 0.8)
    }

    func testCharTrigram_TwoMissingS() {
        let score = matcher.characterNGramSimilarity("mississippi", "missisipi", n: 3)
        XCTAssertGreaterThan(score, 0.7)
    }

    func testCharTrigram_Connecticut() {
        let score = matcher.characterNGramSimilarity("Connecticut", "Conneticut", n: 3)
        XCTAssertGreaterThanOrEqual(score, 0.8)
    }

    func testCharTrigram_Massachusetts() {
        let score = matcher.characterNGramSimilarity("Massachusetts", "Massachusets", n: 3)
        XCTAssertGreaterThan(score, 0.8)
    }

    // MARK: - Word Bigrams

    func testWordBigram_ExactPhrase() {
        let score = matcher.wordNGramSimilarity("united states of america", "united states of america", n: 2)
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testWordBigram_ReorderedWords() {
        let score = matcher.wordNGramSimilarity("united states of america", "america of united states", n: 2)
        XCTAssertLessThan(score, 0.8)  // Word order matters for bigrams
    }

    func testWordBigram_MissingWord() {
        let score = matcher.wordNGramSimilarity("united states america", "united states of america", n: 2)
        XCTAssertGreaterThan(score, 0.3)  // Word bigrams differ significantly when words are missing
    }

    func testWordBigram_ExtraWord() {
        let score = matcher.wordNGramSimilarity("the united states of america", "united states of america", n: 2)
        XCTAssertGreaterThan(score, 0.7)
    }

    func testWordBigram_SimilarPhrase() {
        let score = matcher.wordNGramSimilarity("new york city", "new york town", n: 2)
        XCTAssertGreaterThanOrEqual(score, 0.5)  // One shared bigram out of two pairs
    }

    // MARK: - Combined N-Gram Score

    func testNGramScore_ExactMatch() {
        let score = matcher.nGramScore("hello world", "hello world")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testNGramScore_OneCharDifference() {
        let score = matcher.nGramScore("hello world", "hallo world")
        XCTAssertGreaterThan(score, 0.8)
    }

    func testNGramScore_Transposition() {
        let score = matcher.nGramScore("hello world", "helol world")
        XCTAssertGreaterThan(score, 0.8)
    }

    func testNGramScore_MissingChars() {
        let score = matcher.nGramScore("hello world", "helo worl")
        XCTAssertGreaterThan(score, 0.7)
    }

    func testNGramScore_ExtraChars() {
        let score = matcher.nGramScore("hello world", "helllo worrld")
        XCTAssertGreaterThan(score, 0.7)
    }

    // MARK: - Real-World Examples

    func testRealWorld_Mississippi() {
        let score = matcher.nGramScore("Mississippi", "Missisipi")
        XCTAssertGreaterThan(score, 0.80)  // Should pass threshold
    }

    func testRealWorld_Philadelphia() {
        let score = matcher.nGramScore("Philadelphia", "Philadelfia")
        XCTAssertGreaterThan(score, 0.80)
    }

    func testRealWorld_Cincinnati() {
        let score = matcher.nGramScore("Cincinnati", "Cincinatti")
        XCTAssertGreaterThan(score, 0.80)
    }

    func testRealWorld_Albuquerque() {
        let score = matcher.nGramScore("Albuquerque", "Alberquerque")
        XCTAssertGreaterThan(score, 0.80)
    }

    func testRealWorld_Massachusetts() {
        let score = matcher.nGramScore("Massachusetts", "Massachusets")
        XCTAssertGreaterThan(score, 0.80)
    }

    func testRealWorld_Connecticut() {
        let score = matcher.nGramScore("Connecticut", "Conneticut")
        XCTAssertGreaterThan(score, 0.80)
    }

    func testRealWorld_Photosynthesis() {
        let score = matcher.nGramScore("Photosynthesis", "Fotosynthesis")
        XCTAssertGreaterThan(score, 0.80)
    }

    func testRealWorld_Chromosome() {
        let score = matcher.nGramScore("Chromosome", "Cromosome")
        XCTAssertGreaterThan(score, 0.80)
    }

    func testRealWorld_Christopher() {
        let score = matcher.nGramScore("Christopher", "Cristopher")
        XCTAssertGreaterThan(score, 0.80)
    }

    func testRealWorld_Deoxyribonucleic() {
        let score = matcher.nGramScore("Deoxyribonucleic acid", "Deoxyribonucliec acid")
        XCTAssertGreaterThan(score, 0.80)
    }

    // MARK: - Multi-Word Phrases

    func testMultiWord_UnitedStates() {
        let score = matcher.nGramScore("United States", "United States")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testMultiWord_NewYork() {
        let score = matcher.nGramScore("New York City", "New York City")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testMultiWord_SanFrancisco() {
        let score = matcher.nGramScore("San Francisco", "San Fransisco")
        XCTAssertGreaterThan(score, 0.85)
    }

    func testMultiWord_LosAngeles() {
        let score = matcher.nGramScore("Los Angeles", "Los Angelos")
        XCTAssertGreaterThan(score, 0.80)  // Single character difference in multi-word phrase
    }

    func testMultiWord_NewHampshire() {
        let score = matcher.nGramScore("New Hampshire", "New Hampsire")
        XCTAssertGreaterThan(score, 0.80)
    }

    // MARK: - Edge Cases

    func testEdgeCase_EmptyStrings() {
        let score = matcher.nGramScore("", "")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)  // Both empty = exact match
    }

    func testEdgeCase_OneEmpty() {
        let score = matcher.nGramScore("hello", "")
        XCTAssertEqual(score, 0.0, accuracy: 0.01)
    }

    func testEdgeCase_SingleChar() {
        let score = matcher.nGramScore("a", "a")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testEdgeCase_TwoChars() {
        let score = matcher.nGramScore("ab", "ab")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testEdgeCase_ThreeChars() {
        let score = matcher.nGramScore("abc", "abc")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    // MARK: - Threshold Testing

    func testThreshold_Above80() {
        // Should pass 0.80 threshold
        let score = matcher.nGramScore("mississippi", "missisipi")
        XCTAssertGreaterThan(score, 0.80)
    }

    func testThreshold_Below80() {
        // Should fail 0.80 threshold (very different words)
        let score = matcher.nGramScore("apple", "zebra")
        XCTAssertLessThan(score, 0.80)
    }

    // MARK: - Case Sensitivity

    func testCaseInsensitive_Uppercase() {
        let score1 = matcher.nGramScore("HELLO", "HELLO")
        let score2 = matcher.nGramScore("hello", "hello")
        XCTAssertEqual(score1, score2, accuracy: 0.01)
    }

    func testCaseInsensitive_MixedCase() {
        let score1 = matcher.nGramScore("HeLLo WoRLd", "hello world")
        let score2 = matcher.nGramScore("hello world", "hello world")
        XCTAssertEqual(score1, score2, accuracy: 0.01)
    }

    // MARK: - Performance Tests

    func testPerformance_ShortString() {
        measure {
            _ = matcher.nGramScore("hello", "hallo")
        }
    }

    func testPerformance_MediumString() {
        measure {
            _ = matcher.nGramScore("mississippi river", "missisipi river")
        }
    }

    func testPerformance_LongString() {
        let long1 = "The quick brown fox jumps over the lazy dog"
        let long2 = "The quik brown fox jumps over the lasy dog"
        measure {
            _ = matcher.nGramScore(long1, long2)
        }
    }
}
