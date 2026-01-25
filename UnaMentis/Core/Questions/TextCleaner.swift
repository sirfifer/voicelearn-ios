//
//  TextCleaner.swift
//  UnaMentis
//
//  Utilities for cleaning competition-specific markers from question text.
//  Enables questions to be transformed cleanly between Quiz Bowl, Knowledge Bowl,
//  and Science Bowl formats.
//

import Foundation

// MARK: - Text Cleaner

/// Utilities for cleaning competition-specific markers from question text.
///
/// Quiz Bowl questions contain markers like "For 10 points" that are inappropriate
/// for Knowledge Bowl. Science Bowl answers contain letter prefixes (W, X, Y, Z)
/// that need to be stripped for clean answer matching.
public struct TextCleaner {

    // MARK: - Quiz Bowl Markers

    /// Regex patterns for Quiz Bowl point markers
    private static let qbPointPatterns: [NSRegularExpression] = {
        let patterns = [
            // "For 10 points," "For ten points," "For 10 points, name"
            #"[Ff]or\s+(?:10|ten|15|fifteen|20|twenty|5|five)\s+points?,?\s*"#,
            // "FTP," "FTP name"
            #"FTP,?\s*"#,
            // Standalone point references at end of sentences
            #",?\s*for\s+(?:10|ten|15|fifteen|20|twenty|5|five)\s+points?\.?\s*$"#,
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    /// The power marker used in Quiz Bowl pyramidal questions
    private static let powerMarker = "(*)"

    /// Additional QB-specific phrases to clean
    private static let qbPhrases = [
        "Name this",
        "Identify this",
        "Give this",
        "What is this",
    ]

    // MARK: - Science Bowl Patterns

    /// Regex for Science Bowl answer letter prefixes: W), X), Y), Z)
    private static let sbAnswerPrefixPattern: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"^[WXYZ]\)\s*"#, options: [])
    }()

    /// Regex for inline Science Bowl options in question text
    private static let sbInlineOptionsPattern: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"\s*[WXYZ]\)\s*[^WXYZ]+(?=\s*[WXYZ]\)|$)"#, options: [])
    }()

    // MARK: - Public API

    /// Clean Quiz Bowl markers from question text.
    ///
    /// Removes:
    /// - "For 10 points," and variations
    /// - "FTP," abbreviation
    /// - (*) power markers
    /// - Trailing point references
    ///
    /// - Parameter text: Raw question text potentially containing QB markers
    /// - Returns: Cleaned text suitable for Knowledge Bowl or general use
    public static func cleanQuizBowlText(_ text: String) -> String {
        var result = text

        // Remove power marker
        result = result.replacingOccurrences(of: powerMarker, with: "")

        // Remove point patterns using regex
        for pattern in qbPointPatterns {
            let range = NSRange(result.startIndex..., in: result)
            result = pattern.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: ""
            )
        }

        // Clean up whitespace
        result = cleanWhitespace(result)

        // Ensure proper sentence ending
        result = ensureSentenceEnding(result)

        return result
    }

    /// Clean Science Bowl letter prefix from answer.
    ///
    /// Removes prefixes like "W) ", "X) ", "Y) ", "Z) " from answers.
    ///
    /// - Parameter answer: Raw answer potentially containing SB prefix
    /// - Returns: Clean answer text
    public static func cleanScienceBowlAnswer(_ answer: String) -> String {
        guard let pattern = sbAnswerPrefixPattern else { return answer }

        let range = NSRange(answer.startIndex..., in: answer)
        let result = pattern.stringByReplacingMatches(
            in: answer,
            options: [],
            range: range,
            withTemplate: ""
        )

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Extract the letter from a Science Bowl answer prefix.
    ///
    /// - Parameter answer: Answer like "W) BASIC"
    /// - Returns: The letter (e.g., "W") or nil if no prefix
    public static func extractScienceBowlLetter(_ answer: String) -> String? {
        guard let pattern = sbAnswerPrefixPattern else { return nil }

        let range = NSRange(answer.startIndex..., in: answer)
        guard let match = pattern.firstMatch(in: answer, options: [], range: range) else {
            return nil
        }

        let matchRange = Range(match.range, in: answer)!
        let prefix = String(answer[matchRange])

        // Extract just the letter
        return prefix.first.map { String($0) }
    }

    /// Extract the last meaningful sentence from pyramidal text.
    ///
    /// Quiz Bowl pyramidal questions build up with clues, ending with the actual question.
    /// This extracts that final question portion for use in non-pyramidal formats.
    ///
    /// - Parameter pyramidal: Full pyramidal question text
    /// - Returns: The final question sentence, cleaned of QB markers
    public static func extractShortForm(_ pyramidal: String) -> String {
        // Clean QB markers first
        let cleaned = cleanQuizBowlText(pyramidal)

        // Split into sentences
        let sentences = splitIntoSentences(cleaned)

        // Return the last sentence, or the whole thing if can't split
        guard let lastSentence = sentences.last, !lastSentence.isEmpty else {
            return cleaned
        }

        return lastSentence
    }

    /// Extract a medium-length form from pyramidal text.
    ///
    /// Takes the last 2-3 sentences to provide more context than shortForm
    /// while still being concise enough for Knowledge Bowl.
    ///
    /// - Parameter pyramidal: Full pyramidal question text
    /// - Returns: The last 2-3 sentences, cleaned of QB markers
    public static func extractMediumForm(_ pyramidal: String) -> String {
        // Clean QB markers first
        let cleaned = cleanQuizBowlText(pyramidal)

        // Split into sentences
        let sentences = splitIntoSentences(cleaned)

        // Take last 2-3 sentences depending on total length
        let takeCount = sentences.count >= 4 ? 3 : min(2, sentences.count)
        let lastSentences = sentences.suffix(takeCount)

        return lastSentences.joined(separator: " ")
    }

    /// Check if text contains Quiz Bowl markers.
    ///
    /// Useful for validation and quality checks.
    ///
    /// - Parameter text: Text to check
    /// - Returns: True if QB markers are detected
    public static func containsQuizBowlMarkers(_ text: String) -> Bool {
        // Check for power marker
        if text.contains(powerMarker) {
            return true
        }

        // Check for point patterns
        for pattern in qbPointPatterns {
            let range = NSRange(text.startIndex..., in: text)
            if pattern.firstMatch(in: text, options: [], range: range) != nil {
                return true
            }
        }

        return false
    }

    /// Check if answer contains Science Bowl prefix.
    ///
    /// - Parameter answer: Answer to check
    /// - Returns: True if SB prefix is detected
    public static func containsScienceBowlPrefix(_ answer: String) -> Bool {
        guard let pattern = sbAnswerPrefixPattern else { return false }
        let range = NSRange(answer.startIndex..., in: answer)
        return pattern.firstMatch(in: answer, options: [], range: range) != nil
    }

    // MARK: - Private Helpers

    private static func cleanWhitespace(_ text: String) -> String {
        // Replace multiple spaces with single space
        let components = text.components(separatedBy: .whitespaces)
        let filtered = components.filter { !$0.isEmpty }
        return filtered.joined(separator: " ")
    }

    private static func ensureSentenceEnding(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // If already ends with punctuation, return as-is
        if let last = trimmed.last, ".?!".contains(last) {
            return trimmed
        }

        // Add period if needed
        return trimmed + "."
    }

    private static func splitIntoSentences(_ text: String) -> [String] {
        // Use linguistic tagger for better sentence detection
        var sentences: [String] = []

        text.enumerateSubstrings(
            in: text.startIndex...,
            options: [.bySentences, .localized]
        ) { substring, _, _, _ in
            if let sentence = substring?.trimmingCharacters(in: .whitespaces), !sentence.isEmpty {
                sentences.append(sentence)
            }
        }

        // Fallback to simple splitting if linguistic tagger fails
        if sentences.isEmpty {
            sentences = text.components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        return sentences
    }
}

// MARK: - String Extension

extension String {
    /// Clean this string of Quiz Bowl markers.
    var cleanedOfQuizBowlMarkers: String {
        TextCleaner.cleanQuizBowlText(self)
    }

    /// Clean this string of Science Bowl answer prefix.
    var cleanedOfScienceBowlPrefix: String {
        TextCleaner.cleanScienceBowlAnswer(self)
    }
}
