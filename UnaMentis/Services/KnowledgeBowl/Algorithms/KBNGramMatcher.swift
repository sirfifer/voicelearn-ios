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

    /// Compute character n-gram similarity between two strings using Dice coefficient with padding
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    ///   - n: N-gram size (2 for bigrams, 3 for trigrams)
    /// - Returns: Similarity score (0.0-1.0)
    nonisolated func characterNGramSimilarity(_ str1: String, _ str2: String, n: Int) -> Float {
        // Pad strings with boundary markers for better n-gram matching
        let padded1 = String(repeating: "#", count: n - 1) + str1.lowercased() + String(repeating: "#", count: n - 1)
        let padded2 = String(repeating: "#", count: n - 1) + str2.lowercased() + String(repeating: "#", count: n - 1)

        let ngrams1 = characterNGrams(padded1, n: n)
        let ngrams2 = characterNGrams(padded2, n: n)

        guard !ngrams1.isEmpty && !ngrams2.isEmpty else {
            return str1 == str2 ? 1.0 : 0.0
        }

        // Use Dice coefficient with multiset (counting duplicates)
        return diceMultisetSimilarity(ngrams1, ngrams2)
    }

    /// Compute word n-gram similarity for multi-word answers using Dice coefficient
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    ///   - n: N-gram size (typically 2 for word bigrams)
    /// - Returns: Similarity score (0.0-1.0)
    nonisolated func wordNGramSimilarity(_ str1: String, _ str2: String, n: Int) -> Float {
        let normalized1 = str1.lowercased()
        let normalized2 = str2.lowercased()

        let ngrams1 = wordNGrams(normalized1, n: n)
        let ngrams2 = wordNGrams(normalized2, n: n)

        guard !ngrams1.isEmpty && !ngrams2.isEmpty else {
            return str1 == str2 ? 1.0 : 0.0
        }

        return diceMultisetSimilarity(ngrams1, ngrams2)
    }

    /// Combined n-gram score using multiple similarity measures
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    /// - Returns: Weighted similarity score (0.0-1.0)
    nonisolated func nGramScore(_ str1: String, _ str2: String) -> Float {
        // Normalize inputs
        let normalized1 = str1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized2 = str2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact match check
        guard normalized1 != normalized2 else { return 1.0 }

        // Character unigrams (shared character ratio) - very forgiving
        let unigramScore = characterUnigramSimilarity(normalized1, normalized2)

        // Character bigrams with Dice coefficient
        let bigramScore = characterNGramSimilarity(normalized1, normalized2, n: 2)

        // Character trigrams with Dice coefficient
        let trigramScore = characterNGramSimilarity(normalized1, normalized2, n: 3)

        // For multi-word strings, check word-level similarity
        let isMultiWord = normalized1.contains(" ") || normalized2.contains(" ")

        if isMultiWord {
            // For multi-word answers, compute per-word average similarity
            let wordScore = wordBySimilarity(normalized1, normalized2)
            // Weighted: unigrams give base similarity, word-level for structure
            return (unigramScore * 0.2) + (bigramScore * 0.25) + (trigramScore * 0.25) + (wordScore * 0.3)
        } else {
            // Single word: weighted combination favoring character-level
            // Higher unigram weight helps with single character differences
            return (unigramScore * 0.3) + (bigramScore * 0.35) + (trigramScore * 0.35)
        }
    }

    /// Compute character unigram (single character) similarity
    private nonisolated func characterUnigramSimilarity(_ str1: String, _ str2: String) -> Float {
        let chars1 = Array(str1.filter { !$0.isWhitespace })
        let chars2 = Array(str2.filter { !$0.isWhitespace })

        guard !chars1.isEmpty && !chars2.isEmpty else {
            return chars1.isEmpty && chars2.isEmpty ? 1.0 : 0.0
        }

        // Count character frequencies
        var freq1: [Character: Int] = [:]
        var freq2: [Character: Int] = [:]

        for ch in chars1 { freq1[ch, default: 0] += 1 }
        for ch in chars2 { freq2[ch, default: 0] += 1 }

        // Intersection count (min of frequencies)
        var intersection = 0
        for (ch, count1) in freq1 {
            if let count2 = freq2[ch] {
                intersection += min(count1, count2)
            }
        }

        // Dice coefficient for character multisets
        return Float(2 * intersection) / Float(chars1.count + chars2.count)
    }

    /// Compute word-by-word similarity for multi-word strings
    private nonisolated func wordBySimilarity(_ str1: String, _ str2: String) -> Float {
        let words1 = str1.split(separator: " ").map(String.init)
        let words2 = str2.split(separator: " ").map(String.init)

        guard !words1.isEmpty && !words2.isEmpty else { return 0.0 }

        // Find best match for each word in str1 against words in str2
        var totalScore: Float = 0.0

        for word1 in words1 {
            var bestMatch: Float = 0.0
            for word2 in words2 {
                let sim = characterNGramSimilarity(word1, word2, n: 2)
                bestMatch = max(bestMatch, sim)
            }
            totalScore += bestMatch
        }

        return totalScore / Float(words1.count)
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

    /// Compute Dice coefficient similarity for multisets (arrays with duplicates)
    private nonisolated func diceMultisetSimilarity(_ arr1: [String], _ arr2: [String]) -> Float {
        guard !arr1.isEmpty || !arr2.isEmpty else { return 1.0 }
        guard !arr1.isEmpty && !arr2.isEmpty else { return 0.0 }

        // Count occurrences in each array
        var counts1: [String: Int] = [:]
        var counts2: [String: Int] = [:]

        for item in arr1 {
            counts1[item, default: 0] += 1
        }
        for item in arr2 {
            counts2[item, default: 0] += 1
        }

        // Calculate intersection (minimum of counts)
        var intersectionCount = 0
        for (key, count1) in counts1 {
            if let count2 = counts2[key] {
                intersectionCount += min(count1, count2)
            }
        }

        // Dice coefficient: 2 * |intersection| / (|A| + |B|)
        let totalCount = arr1.count + arr2.count
        return Float(2 * intersectionCount) / Float(totalCount)
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
