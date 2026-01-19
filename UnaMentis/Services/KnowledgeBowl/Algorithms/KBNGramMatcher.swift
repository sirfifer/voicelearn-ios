//
//  KBNGramMatcher.swift
//  UnaMentis
//
//  N-gram similarity matching for Knowledge Bowl answer validation
//  Handles transpositions, missing characters, and spelling variations
//

import Foundation
import OSLog

// MARK: - N-Gram Matcher

/// N-gram similarity matching using character and word n-grams
actor KBNGramMatcher {
    private let logger = Logger(subsystem: "com.unamentis", category: "KBNGramMatcher")

    // MARK: - Public API

    /// Compute character n-gram similarity between two strings
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    ///   - n: N-gram size (2 for bigrams, 3 for trigrams)
    /// - Returns: Similarity score (0.0-1.0)
    nonisolated func characterNGramSimilarity(_ str1: String, _ str2: String, n: Int) -> Float {
        let ngrams1 = Set(characterNGrams(str1, n: n))
        let ngrams2 = Set(characterNGrams(str2, n: n))

        guard !ngrams1.isEmpty && !ngrams2.isEmpty else {
            return str1 == str2 ? 1.0 : 0.0
        }

        return jaccardSimilarity(ngrams1, ngrams2)
    }

    /// Compute word n-gram similarity for multi-word answers
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    ///   - n: N-gram size (typically 2 for word bigrams)
    /// - Returns: Similarity score (0.0-1.0)
    nonisolated func wordNGramSimilarity(_ str1: String, _ str2: String, n: Int) -> Float {
        let ngrams1 = Set(wordNGrams(str1, n: n))
        let ngrams2 = Set(wordNGrams(str2, n: n))

        guard !ngrams1.isEmpty && !ngrams2.isEmpty else {
            return str1 == str2 ? 1.0 : 0.0
        }

        return jaccardSimilarity(ngrams1, ngrams2)
    }

    /// Combined n-gram score (weighted average of char bigrams, trigrams, word bigrams)
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    /// - Returns: Weighted similarity score (0.0-1.0)
    nonisolated func nGramScore(_ str1: String, _ str2: String) -> Float {
        // Normalize inputs
        let normalized1 = str1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized2 = str2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Character bigrams (40% weight)
        let charBigramScore = characterNGramSimilarity(normalized1, normalized2, n: 2)

        // Character trigrams (40% weight)
        let charTrigramScore = characterNGramSimilarity(normalized1, normalized2, n: 3)

        // Word bigrams (20% weight) - only if multi-word
        let wordBigramScore: Float
        if normalized1.contains(" ") || normalized2.contains(" ") {
            wordBigramScore = wordNGramSimilarity(normalized1, normalized2, n: 2)
        } else {
            // Single word, use character-based only
            wordBigramScore = (charBigramScore + charTrigramScore) / 2
        }

        // Weighted combination
        let score = (charBigramScore * 0.4) + (charTrigramScore * 0.4) + (wordBigramScore * 0.2)

        return score
    }

    // MARK: - Private Helpers

    /// Generate character n-grams from a string
    private nonisolated func characterNGrams(_ text: String, n: Int) -> [String] {
        guard text.count >= n else { return [text] }

        var ngrams: [String] = []
        let chars = Array(text)

        for i in 0...(chars.count - n) {
            let ngram = String(chars[i..<(i + n)])
            ngrams.append(ngram)
        }

        return ngrams
    }

    /// Generate word n-grams from a string
    private nonisolated func wordNGrams(_ text: String, n: Int) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        guard words.count >= n else { return [text] }

        var ngrams: [String] = []

        for i in 0...(words.count - n) {
            let ngram = words[i..<(i + n)].joined(separator: " ")
            ngrams.append(ngram)
        }

        return ngrams
    }

    /// Compute Jaccard similarity between two sets
    private nonisolated func jaccardSimilarity<T: Hashable>(_ set1: Set<T>, _ set2: Set<T>) -> Float {
        let intersection = set1.intersection(set2).count
        let union = set1.union(set2).count

        guard union > 0 else { return 0.0 }

        return Float(intersection) / Float(union)
    }
}

// MARK: - Preview Support

#if DEBUG
extension KBNGramMatcher {
    static func preview() -> KBNGramMatcher {
        KBNGramMatcher()
    }
}
#endif
