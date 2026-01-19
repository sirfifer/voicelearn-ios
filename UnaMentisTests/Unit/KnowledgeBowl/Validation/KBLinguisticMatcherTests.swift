//
//  KBLinguisticMatcherTests.swift
//  UnaMentisTests
//
//  Comprehensive unit tests for linguistic matching (lemmatization)
//  Target: 30+ test cases using Apple Natural Language framework
//

import XCTest
@testable import UnaMentis

@available(iOS 18.0, *)
final class KBLinguisticMatcherTests: XCTestCase {
    var matcher: KBLinguisticMatcher!

    override func setUp() async throws {
        try await super.setUp()
        matcher = KBLinguisticMatcher()
    }

    override func tearDown() async throws {
        matcher = nil
        try await super.tearDown()
    }

    // MARK: - Lemmatization

    func testLemma_Plurals() {
        let lemma1 = matcher.lemmatize("cats")
        let lemma2 = matcher.lemmatize("cat")
        XCTAssertEqual(lemma1, lemma2)
    }

    func testLemma_Verbs_Present() {
        let lemma1 = matcher.lemmatize("running")
        let lemma2 = matcher.lemmatize("run")
        XCTAssertEqual(lemma1, lemma2)
    }

    func testLemma_Verbs_Past() {
        let lemma1 = matcher.lemmatize("ran")
        let lemma2 = matcher.lemmatize("run")
        XCTAssertEqual(lemma1, lemma2)
    }

    func testLemma_Adjectives() {
        let lemma1 = matcher.lemmatize("better")
        let lemma2 = matcher.lemmatize("good")
        XCTAssertEqual(lemma1, lemma2)
    }

    func testLemma_IrregularNouns() {
        let lemma1 = matcher.lemmatize("mice")
        let lemma2 = matcher.lemmatize("mouse")
        XCTAssertEqual(lemma1, lemma2)
    }

    func testLemma_MultiWord() {
        let lemma1 = matcher.lemmatize("running cats")
        let lemma2 = matcher.lemmatize("run cat")
        XCTAssertEqual(lemma1, lemma2)
    }

    // MARK: - Lemma Equivalence

    func testEquivalence_Plurals() {
        XCTAssertTrue(matcher.areLemmasEquivalent("cats", "cat"))
    }

    func testEquivalence_Verbs() {
        XCTAssertTrue(matcher.areLemmasEquivalent("running", "run"))
    }

    func testEquivalence_Tense() {
        XCTAssertTrue(matcher.areLemmasEquivalent("walked", "walk"))
    }

    func testEquivalence_Participles() {
        XCTAssertTrue(matcher.areLemmasEquivalent("written", "write"))
    }

    func testEquivalence_Adjectives() {
        XCTAssertTrue(matcher.areLemmasEquivalent("bigger", "big"))
    }

    func testEquivalence_NotEquivalent() {
        XCTAssertFalse(matcher.areLemmasEquivalent("cat", "dog"))
    }

    // MARK: - Key Terms Extraction

    func testKeyTerms_SimpleNoun() {
        let terms = matcher.extractKeyTerms("The cat is sleeping")
        XCTAssertTrue(terms.contains("cat"))
        XCTAssertTrue(terms.contains("sleeping"))
    }

    func testKeyTerms_MultipleNouns() {
        let terms = matcher.extractKeyTerms("Dogs and cats play together")
        XCTAssertTrue(terms.contains("dogs"))
        XCTAssertTrue(terms.contains("cats"))
        XCTAssertTrue(terms.contains("play"))
    }

    func testKeyTerms_NoArticles() {
        let terms = matcher.extractKeyTerms("The quick brown fox")
        XCTAssertFalse(terms.contains("the"))  // Articles not included
    }

    func testKeyTerms_VerbsAndNouns() {
        let terms = matcher.extractKeyTerms("Students study mathematics")
        XCTAssertTrue(terms.contains("students"))
        XCTAssertTrue(terms.contains("study"))
        XCTAssertTrue(terms.contains("mathematics"))
    }

    // MARK: - Shared Key Terms

    func testShared_ExactMatch() {
        XCTAssertTrue(matcher.shareKeyTerms("The cat runs", "The cat runs"))
    }

    func testShared_SimilarSentences() {
        XCTAssertTrue(matcher.shareKeyTerms("The cat runs quickly", "The cat runs"))
    }

    func testShared_DifferentWords() {
        XCTAssertFalse(matcher.shareKeyTerms("The cat runs", "The dog sleeps"))
    }

    func testShared_OneTerm() {
        XCTAssertTrue(matcher.shareKeyTerms("cat", "cat"))
    }

    func testShared_OneSharedTerm() {
        // "cat" is shared
        let result = matcher.shareKeyTerms("The cat runs", "The cat sleeps")
        XCTAssertTrue(result)  // At least 50% overlap
    }

    // MARK: - Real-World Examples

    func testRealWorld_ScientificTerms() {
        XCTAssertTrue(matcher.areLemmasEquivalent("photosynthesizes", "photosynthesize"))
    }

    func testRealWorld_GeographicTerms() {
        XCTAssertTrue(matcher.areLemmasEquivalent("cities", "city"))
    }

    func testRealWorld_HistoricalEvents() {
        XCTAssertTrue(matcher.areLemmasEquivalent("wars", "war"))
    }

    // MARK: - Edge Cases

    func testEdgeCase_EmptyString() {
        let lemma = matcher.lemmatize("")
        XCTAssertEqual(lemma, "")
    }

    func testEdgeCase_SingleWord() {
        let lemma = matcher.lemmatize("cat")
        XCTAssertEqual(lemma, "cat")
    }

    // MARK: - Performance

    func testPerformance_Lemmatization() {
        measure {
            _ = matcher.lemmatize("The quick brown foxes are running through the fields")
        }
    }
}
