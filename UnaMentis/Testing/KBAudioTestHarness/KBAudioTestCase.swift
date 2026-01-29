//
//  KBAudioTestCase.swift
//  UnaMentis
//
//  Test case definition for KB audio Q&A pipeline testing
//

import Foundation

// MARK: - Audio Test Case

/// A single KB audio Q&A test case
///
/// Defines a question, expected answer, audio source, and validation configuration
/// for testing the full audio pipeline: TTS -> STT -> Validation
struct KBAudioTestCase: Codable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let question: KBQuestion
    let expectedAnswer: String
    let answerType: KBAnswerType
    let audioSource: AudioSource
    let validationConfig: ValidationConfig

    init(
        id: UUID = UUID(),
        name: String? = nil,
        question: KBQuestion,
        expectedAnswer: String? = nil,
        answerType: KBAnswerType? = nil,
        audioSource: AudioSource = .generateTTS(provider: .kyutaiPocket),
        validationConfig: ValidationConfig = .standard
    ) {
        self.id = id
        self.name = name ?? "Q: \(question.text.prefix(40))..."
        self.question = question
        self.expectedAnswer = expectedAnswer ?? question.answer.primary
        self.answerType = answerType ?? question.answer.answerType
        self.audioSource = audioSource
        self.validationConfig = validationConfig
    }
}

// MARK: - Audio Source

extension KBAudioTestCase {
    /// Source of audio for the test case
    enum AudioSource: Codable, Sendable {
        /// Generate audio using TTS from the expected answer
        case generateTTS(provider: TTSProvider)

        /// Load pre-recorded audio from a file path
        case prerecordedFile(path: String)

        /// Load pre-recorded audio from the app bundle
        case prerecordedBundle(name: String, extension: String)

        /// Use raw audio data directly
        case rawAudioData(Data, format: AudioFormat)

        struct AudioFormat: Codable, Sendable {
            let sampleRate: Double
            let channels: UInt32
            let isFloat: Bool

            static let stt16kHz = AudioFormat(sampleRate: 16000, channels: 1, isFloat: true)
            static let tts24kHz = AudioFormat(sampleRate: 24000, channels: 1, isFloat: true)
        }
    }
}

// MARK: - Validation Configuration

extension KBAudioTestCase {
    /// Configuration for answer validation
    struct ValidationConfig: Codable, Sendable {
        /// Minimum confidence threshold for a match (0.0-1.0)
        let minimumConfidence: Float

        /// Whether to use fuzzy matching (Levenshtein, phonetic, etc.)
        let useFuzzyMatching: Bool

        /// Whether to use embeddings-based semantic matching
        let useEmbeddings: Bool

        /// Whether to use LLM-based validation
        let useLLMValidation: Bool

        /// Maximum acceptable total pipeline latency (ms)
        let maxPipelineLatencyMs: Double?

        /// Timeout for the entire test (seconds)
        let timeoutSeconds: TimeInterval

        init(
            minimumConfidence: Float = 0.6,
            useFuzzyMatching: Bool = true,
            useEmbeddings: Bool = false,
            useLLMValidation: Bool = false,
            maxPipelineLatencyMs: Double? = nil,
            timeoutSeconds: TimeInterval = 30
        ) {
            self.minimumConfidence = minimumConfidence
            self.useFuzzyMatching = useFuzzyMatching
            self.useEmbeddings = useEmbeddings
            self.useLLMValidation = useLLMValidation
            self.maxPipelineLatencyMs = maxPipelineLatencyMs
            self.timeoutSeconds = timeoutSeconds
        }

        /// Standard configuration: fuzzy matching only
        static let standard = ValidationConfig()

        /// Strict configuration: exact and acceptable matches only
        static let strict = ValidationConfig(
            minimumConfidence: 0.95,
            useFuzzyMatching: false,
            useEmbeddings: false,
            useLLMValidation: false
        )

        /// Lenient configuration: all matching tiers enabled
        static let lenient = ValidationConfig(
            minimumConfidence: 0.5,
            useFuzzyMatching: true,
            useEmbeddings: true,
            useLLMValidation: true
        )
    }
}

// MARK: - Test Case Factory

extension KBAudioTestCase {
    /// Create test cases from a list of questions
    static func fromQuestions(
        _ questions: [KBQuestion],
        audioSource: AudioSource = .generateTTS(provider: .kyutaiPocket),
        validationConfig: ValidationConfig = .standard
    ) -> [KBAudioTestCase] {
        questions.map { question in
            KBAudioTestCase(
                question: question,
                audioSource: audioSource,
                validationConfig: validationConfig
            )
        }
    }

    /// Create a simple test case for quick testing
    static func simple(
        questionText: String,
        expectedAnswer: String,
        answerType: KBAnswerType = .text,
        domain: KBDomain = .science
    ) -> KBAudioTestCase {
        let question = KBQuestion(
            text: questionText,
            answer: KBAnswer(primary: expectedAnswer, answerType: answerType),
            domain: domain
        )
        return KBAudioTestCase(question: question)
    }

    /// Create a complex test case with guidance for sentence-length answers
    ///
    /// Complex answers require evaluation guidance that tells the LLM validator
    /// what criteria to use when judging if the spoken answer is acceptable.
    ///
    /// - Parameters:
    ///   - questionText: The question to ask
    ///   - expectedAnswer: The canonical correct answer (1-2 sentences)
    ///   - guidance: Evaluation criteria for the LLM validator
    ///   - acceptable: Alternative acceptable phrasings
    ///   - answerType: Type of answer for specialized matching
    ///   - domain: Knowledge domain
    /// - Returns: A test case configured for complex answer validation
    static func complex(
        questionText: String,
        expectedAnswer: String,
        guidance: String,
        acceptable: [String]? = nil,
        answerType: KBAnswerType = .text,
        domain: KBDomain = .science
    ) -> KBAudioTestCase {
        let question = KBQuestion(
            text: questionText,
            answer: KBAnswer(
                primary: expectedAnswer,
                acceptable: acceptable,
                answerType: answerType,
                guidance: guidance
            ),
            domain: domain
        )
        return KBAudioTestCase(
            question: question,
            validationConfig: .lenient  // Use lenient config to enable LLM validation
        )
    }
}

// MARK: - Test Suite

/// A collection of test cases to run together
struct KBAudioTestSuite: Codable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let testCases: [KBAudioTestCase]
    let repetitions: Int

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        testCases: [KBAudioTestCase],
        repetitions: Int = 1
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.testCases = testCases
        self.repetitions = repetitions
    }

    /// Total number of test executions (testCases.count * repetitions)
    var totalExecutions: Int {
        testCases.count * repetitions
    }
}

// MARK: - Sample Test Cases

#if DEBUG
extension KBAudioTestCase {
    /// Simple test cases with short answers (1-2 words)
    static let simpleSamples: [KBAudioTestCase] = [
        .simple(
            questionText: "What is the capital of France?",
            expectedAnswer: "Paris",
            answerType: .place
        ),
        .simple(
            questionText: "Who wrote Romeo and Juliet?",
            expectedAnswer: "William Shakespeare",
            answerType: .person
        ),
        .simple(
            questionText: "What is the chemical symbol for water?",
            expectedAnswer: "H2O",
            answerType: .scientific
        ),
        .simple(
            questionText: "In what year did World War II end?",
            expectedAnswer: "1945",
            answerType: .numeric
        ),
        .simple(
            questionText: "What is the largest planet in our solar system?",
            expectedAnswer: "Jupiter",
            answerType: .text
        )
    ]

    /// Complex test cases with sentence-length answers requiring evaluation guidance
    static let complexSamples: [KBAudioTestCase] = [
        .complex(
            questionText: "Explain why the sky appears blue during the day.",
            expectedAnswer: "The sky appears blue because of Rayleigh scattering, where shorter blue wavelengths of sunlight are scattered more than other colors by molecules in the atmosphere.",
            guidance: """
            Accept answers that mention:
            1. Scattering of light (Rayleigh scattering preferred but not required)
            2. Blue light being scattered more than other colors
            3. Reference to atmosphere or air molecules
            Reject answers that only say 'because of the sun' without explaining the mechanism.
            Accept simplified explanations like 'blue light bounces around more in the air'.
            """,
            acceptable: [
                "Rayleigh scattering causes blue light to scatter more in the atmosphere",
                "Blue light scatters more than other colors when sunlight hits the atmosphere"
            ],
            domain: .science
        ),
        .complex(
            questionText: "What was the primary cause of World War I?",
            expectedAnswer: "The assassination of Archduke Franz Ferdinand of Austria-Hungary triggered World War I, though underlying causes included nationalism, militarism, imperial rivalries, and alliance systems.",
            guidance: """
            Accept answers that mention:
            1. The assassination of Franz Ferdinand (primary trigger)
            OR
            2. A combination of underlying causes (nationalism, militarism, alliances, imperialism)
            Full credit for mentioning both the trigger and underlying causes.
            Accept 'the assassination of the Austrian archduke' without the full name.
            Reject answers that only mention a single underlying cause without the assassination.
            """,
            acceptable: [
                "The assassination of Archduke Franz Ferdinand",
                "A combination of nationalism, militarism, and alliance systems"
            ],
            domain: .history
        ),
        .complex(
            questionText: "Describe the process of photosynthesis in one or two sentences.",
            expectedAnswer: "Photosynthesis is the process by which plants convert sunlight, carbon dioxide, and water into glucose and oxygen using chlorophyll.",
            guidance: """
            Accept answers that include:
            1. Plants (or organisms with chlorophyll) as the subject
            2. At least two inputs: sunlight/light AND (carbon dioxide OR water)
            3. At least one output: glucose/sugar OR oxygen
            Mentioning chlorophyll is a bonus but not required.
            Accept simplified versions like 'plants use sunlight and water to make food'.
            Reject answers that only mention 'plants need sunlight' without describing the conversion.
            """,
            acceptable: [
                "Plants use sunlight, water, and carbon dioxide to make glucose and release oxygen",
                "Plants convert light energy into chemical energy stored in glucose"
            ],
            domain: .science
        ),
        .complex(
            questionText: "What is the significance of the Pythagorean theorem?",
            expectedAnswer: "The Pythagorean theorem states that in a right triangle, the square of the hypotenuse equals the sum of the squares of the other two sides, and it's fundamental to geometry and many practical applications.",
            guidance: """
            Accept answers that:
            1. State the theorem: a² + b² = c² or equivalent verbal description
            OR
            2. Explain its significance in geometry, construction, or navigation
            Full credit for both statement and significance.
            Accept 'the sides of a right triangle have a special relationship' if they explain it.
            Reject answers that confuse it with other theorems or give incorrect formulas.
            """,
            acceptable: [
                "a squared plus b squared equals c squared",
                "It relates the sides of a right triangle"
            ],
            answerType: .scientific,
            domain: .mathematics
        ),
        .complex(
            questionText: "Why do we have seasons on Earth?",
            expectedAnswer: "Earth has seasons because its axis is tilted at about 23.5 degrees, causing different parts of the Earth to receive varying amounts of direct sunlight throughout the year as it orbits the Sun.",
            guidance: """
            Accept answers that mention:
            1. Earth's tilted axis (exact angle not required)
            2. Variation in sunlight or solar energy received
            Reject the common misconception that seasons are caused by Earth's distance from the Sun.
            Accept simplified explanations like 'the Earth is tilted so different parts get more sun at different times'.
            """,
            acceptable: [
                "Earth's tilted axis causes different amounts of sunlight to reach different areas",
                "The tilt of Earth on its axis"
            ],
            domain: .science
        )
    ]

    /// All sample test cases (simple + complex)
    static let samples: [KBAudioTestCase] = simpleSamples + complexSamples

    /// Sample test suite with only simple tests (fast)
    static let sampleSuite = KBAudioTestSuite(
        name: "Sample KB Audio Tests",
        description: "Basic test suite for verifying audio Q&A pipeline",
        testCases: simpleSamples,
        repetitions: 1
    )

    /// Complex test suite requiring LLM validation
    static let complexSuite = KBAudioTestSuite(
        name: "Complex KB Audio Tests",
        description: "Test suite with sentence-length answers requiring semantic evaluation",
        testCases: complexSamples,
        repetitions: 1
    )

    /// Full test suite (simple + complex)
    static let fullSuite = KBAudioTestSuite(
        name: "Full KB Audio Tests",
        description: "Complete test suite with both simple and complex answer validation",
        testCases: samples,
        repetitions: 1
    )
}
#endif
