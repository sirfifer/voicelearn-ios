//
//  KBTokenMatcher.swift
//  UnaMentis
//
//  Token-based similarity matching for Knowledge Bowl answer validation
//  Handles word order variations, extra words, and missing words
//

import Foundation
import OSLog

// MARK: - Token Matcher

/// Token-based similarity using Jaccard and Dice coefficients
actor KBTokenMatcher {
    private let logger = Logger(subsystem: "com.unamentis", category: "KBTokenMatcher")

    // MARK: - Public API

    /// Compute Jaccard similarity (intersection / union of tokens)
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    /// - Returns: Jaccard similarity (0.0-1.0)
    nonisolated func jaccardSimilarity(_ str1: String, _ str2: String) -> Float {
        let tokens1 = tokenize(str1)
        let tokens2 = tokenize(str2)

        // If both are empty (all stopwords removed), consider them equal
        if tokens1.isEmpty && tokens2.isEmpty {
            return 1.0
        }

        guard !tokens1.isEmpty && !tokens2.isEmpty else {
            return 0.0
        }

        let intersection = tokens1.intersection(tokens2).count
        let union = tokens1.union(tokens2).count

        guard union > 0 else { return 0.0 }

        return Float(intersection) / Float(union)
    }

    /// Compute Dice coefficient (2 * intersection / sum of sizes)
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    /// - Returns: Dice similarity (0.0-1.0)
    nonisolated func diceSimilarity(_ str1: String, _ str2: String) -> Float {
        let tokens1 = tokenize(str1)
        let tokens2 = tokenize(str2)

        // If both are empty (all stopwords removed), consider them equal
        if tokens1.isEmpty && tokens2.isEmpty {
            return 1.0
        }

        guard !tokens1.isEmpty && !tokens2.isEmpty else {
            return 0.0
        }

        let intersection = tokens1.intersection(tokens2).count
        let sumOfSizes = tokens1.count + tokens2.count

        guard sumOfSizes > 0 else { return 0.0 }

        return Float(2 * intersection) / Float(sumOfSizes)
    }

    /// Combined token score (average of Jaccard + Dice)
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    /// - Returns: Combined similarity score (0.0-1.0)
    nonisolated func tokenScore(_ str1: String, _ str2: String) -> Float {
        let jaccard = jaccardSimilarity(str1, str2)
        let dice = diceSimilarity(str1, str2)

        return (jaccard + dice) / 2.0
    }

    // MARK: - Private Helpers

    /// Tokenize string into normalized words
    /// - Parameter text: Input text
    /// - Returns: Set of normalized tokens
    private nonisolated func tokenize(_ text: String) -> Set<String> {
        let normalized = text.lowercased()

        // Split on whitespace and punctuation
        let tokens = normalized.components(separatedBy: .whitespacesAndNewlines)
            .flatMap { word in
                word.components(separatedBy: .punctuationCharacters)
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Remove common articles, prepositions, and titles
        let stopWords = Set([
            "the", "a", "an", "of", "in", "at", "on", "to", "for", "with", "by", "from",
            "dr", "mr", "mrs", "ms", "jr", "sr"  // Common titles
        ])

        let filtered = tokens.filter { !stopWords.contains($0) }

        return Set(filtered)
    }
}

// MARK: - Preview Support

#if DEBUG
extension KBTokenMatcher {
    static func preview() -> KBTokenMatcher {
        KBTokenMatcher()
    }
}
#endif
