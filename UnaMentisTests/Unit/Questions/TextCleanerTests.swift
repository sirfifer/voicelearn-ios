//
//  TextCleanerTests.swift
//  UnaMentisTests
//
//  Tests for TextCleaner utilities that handle Quiz Bowl and Science Bowl
//  marker cleaning for cross-format question compatibility.
//

import XCTest
@testable import UnaMentis

final class TextCleanerTests: XCTestCase {

    // MARK: - Quiz Bowl Text Cleaning

    func testCleansForTenPointsComma() {
        let input = "This author wrote many famous works. For 10 points, name this author."
        let cleaned = TextCleaner.cleanQuizBowlText(input)

        XCTAssertFalse(cleaned.contains("For 10 points"))
        XCTAssertTrue(cleaned.contains("This author wrote"))
        XCTAssertTrue(cleaned.contains("name this author"))
    }

    func testCleansForTenPointsWrittenOut() {
        let input = "For ten points, identify this element."
        let cleaned = TextCleaner.cleanQuizBowlText(input)

        XCTAssertFalse(cleaned.lowercased().contains("for ten points"))
        XCTAssertTrue(cleaned.contains("identify this element"))
    }

    func testCleansFTP() {
        let input = "This novel was published in 1925. FTP, name its author."
        let cleaned = TextCleaner.cleanQuizBowlText(input)

        XCTAssertFalse(cleaned.contains("FTP"))
        XCTAssertTrue(cleaned.contains("This novel was published"))
    }

    func testCleansPowerMarker() {
        let input = "This scientist (*) developed the theory of relativity."
        let cleaned = TextCleaner.cleanQuizBowlText(input)

        XCTAssertFalse(cleaned.contains("(*)"))
        XCTAssertTrue(cleaned.contains("This scientist"))
        XCTAssertTrue(cleaned.contains("developed the theory"))
    }

    func testCleansFor15Points() {
        let input = "For 15 points, name this capital city."
        let cleaned = TextCleaner.cleanQuizBowlText(input)

        XCTAssertFalse(cleaned.contains("For 15 points"))
    }

    func testCleansFor20Points() {
        let input = "For 20 points, identify this composer."
        let cleaned = TextCleaner.cleanQuizBowlText(input)

        XCTAssertFalse(cleaned.contains("For 20 points"))
    }

    func testCleansTrailingPointReference() {
        let input = "This battle occurred in 1066, for 10 points."
        let cleaned = TextCleaner.cleanQuizBowlText(input)

        XCTAssertFalse(cleaned.contains("for 10 points"))
        XCTAssertTrue(cleaned.contains("This battle occurred in 1066"))
    }

    func testPreservesRegularText() {
        let input = "What is the capital of France?"
        let cleaned = TextCleaner.cleanQuizBowlText(input)

        XCTAssertEqual(cleaned, "What is the capital of France?")
    }

    func testCleansMultipleSpaces() {
        let input = "For 10 points,   name    this city."
        let cleaned = TextCleaner.cleanQuizBowlText(input)

        XCTAssertFalse(cleaned.contains("  "), "Should not contain double spaces")
    }

    func testEnsuresSentenceEnding() {
        let input = "For 10 points, name this element"
        let cleaned = TextCleaner.cleanQuizBowlText(input)

        XCTAssertTrue(cleaned.hasSuffix("."), "Should end with period")
    }

    func testPreservesExistingPunctuation() {
        let input = "For 10 points, what is this element?"
        let cleaned = TextCleaner.cleanQuizBowlText(input)

        XCTAssertTrue(cleaned.hasSuffix("?"), "Should preserve question mark")
    }

    // MARK: - Science Bowl Answer Cleaning

    func testCleansWPrefix() {
        let answer = "W) BASIC"
        let cleaned = TextCleaner.cleanScienceBowlAnswer(answer)

        XCTAssertEqual(cleaned, "BASIC")
    }

    func testCleansXPrefix() {
        let answer = "X) ACIDIC"
        let cleaned = TextCleaner.cleanScienceBowlAnswer(answer)

        XCTAssertEqual(cleaned, "ACIDIC")
    }

    func testCleansYPrefix() {
        let answer = "Y) NEUTRAL"
        let cleaned = TextCleaner.cleanScienceBowlAnswer(answer)

        XCTAssertEqual(cleaned, "NEUTRAL")
    }

    func testCleansZPrefix() {
        let answer = "Z) EQUILIBRIUM"
        let cleaned = TextCleaner.cleanScienceBowlAnswer(answer)

        XCTAssertEqual(cleaned, "EQUILIBRIUM")
    }

    func testCleansPrefixWithExtraSpaces() {
        let answer = "W)   BENZENE"
        let cleaned = TextCleaner.cleanScienceBowlAnswer(answer)

        XCTAssertEqual(cleaned, "BENZENE")
    }

    func testPreservesAnswerWithoutPrefix() {
        let answer = "Carbon Dioxide"
        let cleaned = TextCleaner.cleanScienceBowlAnswer(answer)

        XCTAssertEqual(cleaned, "Carbon Dioxide")
    }

    func testPreservesLowercasePrefixLettersInAnswer() {
        // Should not clean "w)" if it's part of the actual answer
        let answer = "www.example.com"
        let cleaned = TextCleaner.cleanScienceBowlAnswer(answer)

        XCTAssertEqual(cleaned, "www.example.com")
    }

    // MARK: - Extract Science Bowl Letter

    func testExtractsWLetter() {
        let answer = "W) BASIC"
        let letter = TextCleaner.extractScienceBowlLetter(answer)

        XCTAssertEqual(letter, "W")
    }

    func testExtractsXLetter() {
        let answer = "X) ANSWER"
        let letter = TextCleaner.extractScienceBowlLetter(answer)

        XCTAssertEqual(letter, "X")
    }

    func testReturnsNilForNoPrefix() {
        let answer = "No prefix here"
        let letter = TextCleaner.extractScienceBowlLetter(answer)

        XCTAssertNil(letter)
    }

    // MARK: - Detection Functions

    func testDetectsQuizBowlMarkers() {
        XCTAssertTrue(TextCleaner.containsQuizBowlMarkers("For 10 points, name this."))
        XCTAssertTrue(TextCleaner.containsQuizBowlMarkers("This is (*) a power marker."))
        XCTAssertTrue(TextCleaner.containsQuizBowlMarkers("FTP, identify this."))
        XCTAssertFalse(TextCleaner.containsQuizBowlMarkers("What is the capital?"))
    }

    func testDetectsScienceBowlPrefix() {
        XCTAssertTrue(TextCleaner.containsScienceBowlPrefix("W) BASIC"))
        XCTAssertTrue(TextCleaner.containsScienceBowlPrefix("X) ANSWER"))
        XCTAssertFalse(TextCleaner.containsScienceBowlPrefix("No prefix"))
        XCTAssertFalse(TextCleaner.containsScienceBowlPrefix("A) This is not SB format"))
    }

    // MARK: - Text Form Extraction

    func testExtractShortForm() {
        let pyramidal = """
            This author wrote The Great Gatsby. He was part of the Lost Generation. \
            For 10 points, name this American author.
            """
        let shortForm = TextCleaner.extractShortForm(pyramidal)

        // Should be the last sentence, cleaned
        XCTAssertFalse(shortForm.contains("For 10 points"))
        XCTAssertTrue(shortForm.contains("name this American author"))
    }

    func testExtractMediumForm() {
        let pyramidal = """
            First clue about obscure fact. Second clue with more detail. \
            Third clue getting easier. For 10 points, name this thing.
            """
        let mediumForm = TextCleaner.extractMediumForm(pyramidal)

        // Should be last 2-3 sentences, cleaned
        XCTAssertFalse(mediumForm.contains("For 10 points"))
        XCTAssertTrue(mediumForm.contains("name this thing"))
    }

    func testExtractMediumFormFromShortText() {
        let shortText = "What is the capital of France?"
        let mediumForm = TextCleaner.extractMediumForm(shortText)

        // Should return the whole thing for short text
        XCTAssertEqual(mediumForm, "What is the capital of France?")
    }

    // MARK: - String Extension

    func testStringExtensionForQB() {
        let input = "For 10 points, name this."
        let cleaned = input.cleanedOfQuizBowlMarkers

        XCTAssertFalse(cleaned.contains("For 10 points"))
    }

    func testStringExtensionForSB() {
        let input = "W) BASIC"
        let cleaned = input.cleanedOfScienceBowlPrefix

        XCTAssertEqual(cleaned, "BASIC")
    }

    // MARK: - Edge Cases

    func testEmptyString() {
        XCTAssertEqual(TextCleaner.cleanQuizBowlText(""), ".")
        XCTAssertEqual(TextCleaner.cleanScienceBowlAnswer(""), "")
    }

    func testCaseInsensitiveQBCleaning() {
        let input1 = "FOR 10 POINTS, name this."
        let input2 = "for 10 points, name this."
        let input3 = "For 10 Points, name this."

        let cleaned1 = TextCleaner.cleanQuizBowlText(input1)
        let cleaned2 = TextCleaner.cleanQuizBowlText(input2)
        let cleaned3 = TextCleaner.cleanQuizBowlText(input3)

        XCTAssertFalse(cleaned1.lowercased().contains("for 10 points"))
        XCTAssertFalse(cleaned2.lowercased().contains("for 10 points"))
        XCTAssertFalse(cleaned3.lowercased().contains("for 10 points"))
    }

    func testComplexPyramidalQuestion() {
        // Real-world example structure
        let pyramidal = """
            In an essay on this activity, a man sits next to a tall blonde woman at \
            a boxing match. One essay about this activity observes that it creates \
            a bond between participants. (*) Joyce Carol Oates wrote that this \
            activity requires courage. For 10 points, Marianne Moore co-wrote a poem \
            about what sport?
            """

        let cleaned = TextCleaner.cleanQuizBowlText(pyramidal)

        XCTAssertFalse(cleaned.contains("(*)"))
        XCTAssertFalse(cleaned.contains("For 10 points"))
        XCTAssertTrue(cleaned.contains("what sport"))
    }
}
