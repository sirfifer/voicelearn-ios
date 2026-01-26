//
//  KBPack.swift
//  UnaMentis
//
//  Knowledge Bowl question pack model.
//  Supports both server-side packs (fetched from management API) and local packs (created on-device).
//

import Foundation

/// A collection of Knowledge Bowl questions grouped for practice or competition.
struct KBPack: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let name: String
    let description: String?
    let questionCount: Int
    let domainDistribution: [String: Int]
    let difficultyDistribution: [Int: Int]
    let packType: PackType
    let isLocal: Bool
    let questionIds: [String]?  // For local packs, stores the question UUIDs
    let createdAt: Date?
    let updatedAt: Date?

    /// Type of question pack
    enum PackType: String, Codable, Sendable {
        case system    // Pre-made packs from the server
        case custom    // User-created packs (local or synced)
        case bundle    // Combined packs
    }

    /// Initialize a local pack
    init(
        id: String,
        name: String,
        description: String?,
        questionCount: Int,
        domainDistribution: [String: Int],
        difficultyDistribution: [Int: Int],
        packType: PackType = .custom,
        isLocal: Bool = true,
        questionIds: [String]? = nil,
        createdAt: Date? = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.questionCount = questionCount
        self.domainDistribution = domainDistribution
        self.difficultyDistribution = difficultyDistribution
        self.packType = packType
        self.isLocal = isLocal
        self.questionIds = questionIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Top domains in this pack (up to 4)
    var topDomains: [KBDomain] {
        domainDistribution
            .sorted { $0.value > $1.value }
            .prefix(4)
            .compactMap { KBDomain(rawValue: $0.key) }
    }

    /// Display string for question count
    var questionCountDisplay: String {
        "\(questionCount) question\(questionCount == 1 ? "" : "s")"
    }
}

// MARK: - Server Response Models

/// Response from GET /api/kb/packs
struct KBPacksResponse: Codable {
    let packs: [KBPackDTO]
    let total: Int?
}

/// Data transfer object for pack from server
struct KBPackDTO: Codable {
    let id: String
    let name: String
    let description: String?
    let packType: String?
    let questionIds: [String]?
    let stats: KBPackStats?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case packType = "pack_type"
        case questionIds = "question_ids"
        case stats
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Convert to domain model
    func toPack() -> KBPack {
        KBPack(
            id: id,
            name: name,
            description: description,
            questionCount: stats?.questionCount ?? questionIds?.count ?? 0,
            domainDistribution: stats?.domainDistribution ?? [:],
            difficultyDistribution: stats?.difficultyDistribution ?? [:],
            packType: KBPack.PackType(rawValue: packType ?? "system") ?? .system,
            isLocal: false,
            questionIds: questionIds,
            createdAt: createdAt.flatMap { ISO8601DateFormatter().date(from: $0) },
            updatedAt: updatedAt.flatMap { ISO8601DateFormatter().date(from: $0) }
        )
    }
}

/// Pack statistics from server
struct KBPackStats: Codable {
    let questionCount: Int
    let domainCount: Int?
    let domainDistribution: [String: Int]
    let difficultyDistribution: [Int: Int]
    let audioCoveragePercent: Double?
    let missingAudioCount: Int?

    enum CodingKeys: String, CodingKey {
        case questionCount = "question_count"
        case domainCount = "domain_count"
        case domainDistribution = "domain_distribution"
        case difficultyDistribution = "difficulty_distribution"
        case audioCoveragePercent = "audio_coverage_percent"
        case missingAudioCount = "missing_audio_count"
    }
}

// MARK: - Preview Support

#if DEBUG
extension KBPack {
    static let preview = KBPack(
        id: "preview-pack-1",
        name: "Colorado Regional 2024",
        description: "Official questions from the 2024 Colorado Regional competition",
        questionCount: 150,
        domainDistribution: [
            "science": 30,
            "mathematics": 25,
            "literature": 20,
            "history": 20,
            "socialStudies": 15,
            "arts": 10,
            "currentEvents": 10,
            "technology": 10,
            "language": 5,
            "popCulture": 3,
            "religionPhilosophy": 2
        ],
        difficultyDistribution: [1: 20, 2: 40, 3: 50, 4: 30, 5: 10],
        packType: .system,
        isLocal: false
    )

    static let localPreview = KBPack(
        id: "local-abc123",
        name: "Science Focus",
        description: "Custom pack focusing on science questions",
        questionCount: 30,
        domainDistribution: ["science": 25, "technology": 5],
        difficultyDistribution: [2: 15, 3: 10, 4: 5],
        packType: .custom,
        isLocal: true,
        questionIds: ["q1", "q2", "q3"]
    )
}
#endif
