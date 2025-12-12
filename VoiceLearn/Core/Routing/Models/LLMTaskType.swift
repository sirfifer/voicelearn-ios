// VoiceLearn - LLM Task Type
// Defines all types of LLM tasks and their capability requirements
//
// Part of Core/Routing (Patch Panel Architecture)
//
// Every LLM call in the application has a task type that describes:
// - What the task is trying to accomplish
// - What minimum capability level is required
// - Whether it can be answered from pre-generated content (transcript)

import Foundation

// MARK: - LLM Task Type

/// Types of tasks that can be routed to LLM endpoints
///
/// Each task type represents a distinct use case for LLM inference.
/// The Patch Panel uses task types to make routing decisions based on
/// the minimum capability required for each task.
///
/// ## Task Categories
/// - **Tutoring Core**: Main educational dialogue tasks
/// - **Content Generation**: Creating explanations, examples, analogies
/// - **Navigation**: Session flow and topic transitions
/// - **Processing**: Document and transcript processing
/// - **Classification**: Intent, sentiment, topic classification
/// - **Simple Responses**: Acknowledgments and fillers
/// - **System**: Health checks and embeddings
public enum LLMTaskType: String, Codable, Sendable, CaseIterable {

    // MARK: - Tutoring Core Tasks

    /// Main tutoring dialogue response
    /// Requires frontier capability for nuanced pedagogy
    case tutoringResponse

    /// Check if student understood a concept
    /// Requires frontier capability for accurate assessment
    case understandingCheck

    /// Generate Socratic probing questions
    /// Requires frontier capability for pedagogical reasoning
    case socraticQuestion

    /// Correct a misconception in student's understanding
    /// Requires frontier capability for precise correction
    case misconceptionCorrection

    // MARK: - Content Generation Tasks

    /// Generate an explanation for a concept
    /// Medium capability sufficient for most explanations
    case explanationGeneration

    /// Generate an example to illustrate a concept
    /// Medium capability, can often use transcript examples
    case exampleGeneration

    /// Generate an analogy to explain a concept
    /// Medium capability with creativity
    case analogyGeneration

    /// Rephrase an explanation differently
    /// Medium capability, can often use transcript alternatives
    case rephrasing

    /// Simplify an explanation to lower level
    /// Medium capability, can often use transcript simpler versions
    case simplification

    // MARK: - Navigation Tasks

    /// Explore a tangent topic raised by user
    /// Requires frontier capability for relevance judgment
    case tangentExploration

    /// Transition between topics smoothly
    /// Small capability sufficient for transitions
    case topicTransition

    /// Summarize what was covered in session
    /// Medium capability for extractive summary
    case sessionSummary

    // MARK: - Processing Tasks

    /// Summarize a curriculum document
    /// Medium capability for document understanding
    case documentSummarization

    /// Generate a lesson transcript
    /// Medium capability for structured content
    case transcriptGeneration

    /// Extract glossary terms from content
    /// Small capability for term extraction
    case glossaryExtraction

    // MARK: - Classification Tasks

    /// Classify user's intent (question, acknowledgment, etc.)
    /// Small capability, can run on-device
    case intentClassification

    /// Analyze user's sentiment (confused, engaged, etc.)
    /// Small capability, can run on-device
    case sentimentAnalysis

    /// Classify what topic user is asking about
    /// Small capability, can run on-device
    case topicClassification

    // MARK: - Simple Response Tasks

    /// Simple acknowledgment response ("Okay, continuing...")
    /// Tiny capability, should run on-device
    case acknowledgment

    /// Filler response ("I see, tell me more...")
    /// Tiny capability, should run on-device
    case fillerResponse

    /// Navigation confirmation ("Going back to...")
    /// Tiny capability, should run on-device
    case navigationConfirmation

    // MARK: - System Tasks

    /// Health check ping to test endpoint
    /// Any capability level
    case healthCheck

    /// Generate embeddings for semantic search
    /// Specialized embedding model
    case embeddingGeneration
}

// MARK: - Capability Requirements

extension LLMTaskType {

    /// Minimum capability tier required for this task type
    ///
    /// This guides routing decisions - a task should not be routed
    /// to an endpoint that doesn't meet its minimum capability tier.
    public var minimumCapabilityTier: CapabilityTier {
        switch self {
        // Frontier tier - needs GPT-4o / Claude 3.5 level
        case .tutoringResponse,
             .understandingCheck,
             .socraticQuestion,
             .misconceptionCorrection,
             .tangentExploration:
            return .frontier

        // Medium tier - needs 7B-70B level
        case .explanationGeneration,
             .exampleGeneration,
             .analogyGeneration,
             .rephrasing,
             .simplification,
             .documentSummarization,
             .transcriptGeneration,
             .sessionSummary:
            return .medium

        // Small tier - needs 1B-3B level
        case .intentClassification,
             .sentimentAnalysis,
             .topicClassification,
             .glossaryExtraction,
             .topicTransition:
            return .small

        // Tiny tier - can use smallest models or templates
        case .acknowledgment,
             .fillerResponse,
             .navigationConfirmation:
            return .tiny

        // Special cases
        case .healthCheck:
            return .any

        case .embeddingGeneration:
            return .embedding
        }
    }

    /// Whether this task can potentially be answered from a pre-generated transcript
    ///
    /// If true, the routing system should check transcript content before
    /// routing to an LLM. This can save cost and latency.
    public var acceptsTranscriptAnswer: Bool {
        switch self {
        case .exampleGeneration,
             .rephrasing,
             .simplification,
             .glossaryExtraction,
             .topicTransition:
            return true
        default:
            return false
        }
    }

    /// Human-readable description of this task type
    public var description: String {
        switch self {
        case .tutoringResponse: return "Tutoring Response"
        case .understandingCheck: return "Understanding Check"
        case .socraticQuestion: return "Socratic Question"
        case .misconceptionCorrection: return "Misconception Correction"
        case .explanationGeneration: return "Explanation Generation"
        case .exampleGeneration: return "Example Generation"
        case .analogyGeneration: return "Analogy Generation"
        case .rephrasing: return "Rephrasing"
        case .simplification: return "Simplification"
        case .tangentExploration: return "Tangent Exploration"
        case .topicTransition: return "Topic Transition"
        case .sessionSummary: return "Session Summary"
        case .documentSummarization: return "Document Summarization"
        case .transcriptGeneration: return "Transcript Generation"
        case .glossaryExtraction: return "Glossary Extraction"
        case .intentClassification: return "Intent Classification"
        case .sentimentAnalysis: return "Sentiment Analysis"
        case .topicClassification: return "Topic Classification"
        case .acknowledgment: return "Acknowledgment"
        case .fillerResponse: return "Filler Response"
        case .navigationConfirmation: return "Navigation Confirmation"
        case .healthCheck: return "Health Check"
        case .embeddingGeneration: return "Embedding Generation"
        }
    }
}

// MARK: - Capability Tier

/// Capability tiers for LLM models
///
/// Tiers represent rough capability levels that determine whether
/// an endpoint can handle a given task type.
public enum CapabilityTier: Int, Codable, Sendable, Comparable {
    /// Any capability level (for health checks, etc.)
    case any = 0

    /// Tiny models (~100M-500M params) - on-device classifiers
    case tiny = 1

    /// Small models (1B-3B params) - on-device LLMs
    case small = 2

    /// Medium models (7B-70B params) - self-hosted servers
    case medium = 3

    /// Frontier models (GPT-4o, Claude 3.5) - cloud APIs
    case frontier = 4

    /// Specialized embedding models
    case embedding = 5

    // MARK: - Comparable

    public static func < (lhs: CapabilityTier, rhs: CapabilityTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: - Capability Check

    /// Check if this tier meets a required tier
    /// - Parameter required: The required capability tier
    /// - Returns: True if this tier is >= required tier
    public func meets(_ required: CapabilityTier) -> Bool {
        // Special case: 'any' requirement is always met
        if required == .any {
            return true
        }

        // Special case: embedding tier only meets embedding requirement
        if required == .embedding {
            return self == .embedding
        }

        // Normal comparison: higher tier meets lower requirements
        return self >= required
    }

    /// Human-readable description of this tier
    public var description: String {
        switch self {
        case .any: return "Any"
        case .tiny: return "Tiny (On-Device Classifier)"
        case .small: return "Small (On-Device LLM)"
        case .medium: return "Medium (Self-Hosted)"
        case .frontier: return "Frontier (Cloud API)"
        case .embedding: return "Embedding"
        }
    }
}
