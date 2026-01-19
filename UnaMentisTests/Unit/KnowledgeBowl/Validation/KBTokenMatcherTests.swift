//
//  KBTokenMatcherTests.swift
//  UnaMentisTests
//
//  Comprehensive unit tests for token-based similarity (Jaccard & Dice)
//  Target: 50+ test cases covering word order, extra/missing words
//

import XCTest
@testable import UnaMentis

@available(iOS 18.0, *)
final class KBTokenMatcherTests: XCTestCase {
    var matcher: KBTokenMatcher!

    override func setUp() async throws {
        try await super.setUp()
        matcher = KBTokenMatcher()
    }

    override func tearDown() async throws {
        matcher = nil
        try await super.tearDown()
    }

    // MARK: - Jaccard Similarity

    func testJaccard_ExactMatch() {
        let score = matcher.jaccardSimilarity("united states", "united states")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testJaccard_WordOrder() {
        // Order doesn't matter for Jaccard
        let score = matcher.jaccardSimilarity("united states america", "america united states")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testJaccard_ExtraWord() {
        let score = matcher.jaccardSimilarity("united states of america", "united states america")
        XCTAssertGreaterThan(score, 0.75)
    }

    func testJaccard_MissingWord() {
        let score = matcher.jaccardSimilarity("united states", "united states of america")
        XCTAssertGreaterThan(score, 0.50)
    }

    func testJaccard_StopWordsRemoved() {
        // "the" should be removed
        let score = matcher.jaccardSimilarity("the united states", "united states")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    // MARK: - Dice Coefficient

    func testDice_ExactMatch() {
        let score = matcher.diceSimilarity("united states", "united states")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testDice_WordOrder() {
        let score = matcher.diceSimilarity("united states america", "america united states")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testDice_ExtraWord() {
        let score = matcher.diceSimilarity("united states of america", "united states america")
        XCTAssertGreaterThan(score, 0.80)
    }

    func testDice_MissingWord() {
        let score = matcher.diceSimilarity("united states", "united states of america")
        XCTAssertGreaterThan(score, 0.60)
    }

    // MARK: - Combined Token Score

    func testTokenScore_ExactMatch() {
        let score = matcher.tokenScore("united states", "united states")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testTokenScore_WordOrderDifferent() {
        let score = matcher.tokenScore("states united", "united states")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testTokenScore_WithArticle() {
        let score = matcher.tokenScore("the united states", "united states")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testTokenScore_WithPreposition() {
        let score = matcher.tokenScore("united states of america", "united states america")
        XCTAssertGreaterThan(score, 0.80)
    }

    // MARK: - Real-World Place Names

    func testPlaceName_USA() {
        let score = matcher.tokenScore("united states of america", "united states")
        XCTAssertGreaterThan(score, 0.60)
    }

    func testPlaceName_UK() {
        let score = matcher.tokenScore("united kingdom", "kingdom united")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testPlaceName_SanFrancisco() {
        let score = matcher.tokenScore("san francisco", "francisco san")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testPlaceName_NewYorkCity() {
        let score = matcher.tokenScore("new york city", "city new york")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testPlaceName_LosAngeles() {
        let score = matcher.tokenScore("los angeles", "angeles los")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    // MARK: - Person Names

    func testPersonName_FirstLast() {
        let score = matcher.tokenScore("george washington", "washington george")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testPersonName_MiddleInitial() {
        let score = matcher.tokenScore("john f kennedy", "kennedy john f")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testPersonName_Title() {
        let score = matcher.tokenScore("president lincoln", "lincoln")
        XCTAssertGreaterThan(score, 0.40)
    }

    func testPersonName_DrTitle() {
        let score = matcher.tokenScore("dr martin luther king", "martin luther king")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)  // "dr" might be removed as stopword
    }

    // MARK: - Scientific Terms

    func testScientific_DNAFull() {
        let score = matcher.tokenScore("deoxyribonucleic acid", "acid deoxyribonucleic")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testScientific_H2OFull() {
        let score = matcher.tokenScore("dihydrogen monoxide", "monoxide dihydrogen")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    // MARK: - Titles

    func testTitle_BookWithThe() {
        let score = matcher.tokenScore("the great gatsby", "great gatsby")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testTitle_BookWithA() {
        let score = matcher.tokenScore("a tale of two cities", "tale two cities")
        XCTAssertGreaterThan(score, 0.85)
    }

    func testTitle_MovieWithThe() {
        let score = matcher.tokenScore("the lord of the rings", "lord rings")
        XCTAssertGreaterThan(score, 0.50)
    }

    // MARK: - Extra Words

    func testExtraWords_ManyArticles() {
        let score = matcher.tokenScore("the a an united states", "united states")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testExtraWords_Prepositions() {
        let score = matcher.tokenScore("united states of in at on america", "united states america")
        XCTAssertGreaterThan(score, 0.80)
    }

    // MARK: - Missing Words

    func testMissingWords_OneWord() {
        let score = matcher.tokenScore("united", "united states")
        XCTAssertGreaterThan(score, 0.40)
    }

    func testMissingWords_TwoWords() {
        let score = matcher.tokenScore("united states", "united states of america")
        XCTAssertGreaterThan(score, 0.60)
    }

    // MARK: - Tokenization

    func testTokenization_Punctuation() {
        let score = matcher.tokenScore("hello, world!", "hello world")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testTokenization_MultipleSpaces() {
        let score = matcher.tokenScore("hello    world", "hello world")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testTokenization_MixedPunctuation() {
        let score = matcher.tokenScore("hello-world", "hello world")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    // MARK: - Threshold Testing

    func testThreshold_Above80() {
        let score = matcher.tokenScore("united states of america", "united states america")
        XCTAssertGreaterThan(score, 0.80)
    }

    func testThreshold_Below80() {
        let score = matcher.tokenScore("apple", "zebra")
        XCTAssertLessThan(score, 0.80)
    }

    // MARK: - Edge Cases

    func testEdgeCase_EmptyStrings() {
        let score = matcher.tokenScore("", "")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testEdgeCase_OneEmpty() {
        let score = matcher.tokenScore("hello", "")
        XCTAssertEqual(score, 0.0, accuracy: 0.01)
    }

    func testEdgeCase_SingleWord() {
        let score = matcher.tokenScore("hello", "hello")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testEdgeCase_OnlyStopWords() {
        let score = matcher.tokenScore("the a an of in at on to for with by from", "")
        // All stopwords should be removed, leaving empty
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    // MARK: - Case Sensitivity

    func testCaseInsensitive_Uppercase() {
        let score = matcher.tokenScore("UNITED STATES", "united states")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testCaseInsensitive_MixedCase() {
        let score = matcher.tokenScore("UnItEd StAtEs", "united states")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    // MARK: - Performance Tests

    func testPerformance_ShortPhrase() {
        measure {
            _ = matcher.tokenScore("united states", "states united")
        }
    }

    func testPerformance_MediumPhrase() {
        measure {
            _ = matcher.tokenScore("united states of america", "america states united")
        }
    }

    func testPerformance_LongPhrase() {
        let long1 = "the quick brown fox jumps over the lazy dog in the park"
        let long2 = "lazy dog in park jumps over quick brown fox"
        measure {
            _ = matcher.tokenScore(long1, long2)
        }
    }
}
