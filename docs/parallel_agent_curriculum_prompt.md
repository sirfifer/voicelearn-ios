# Parallel Agent Prompt: Curriculum Management System

## Context

You are working on the UnaMentis iOS project - a real-time bidirectional voice AI platform for educational conversations. Another agent is working on the core audio/voice pipeline (AudioEngine, VAD, STT, TTS, LLM). Your task is to implement the **Curriculum Management System** which is independent of the audio pipeline.

## Your Objective

Implement the Curriculum Management System as specified in the TDD (Technical Design Document). This includes Core Data models, the CurriculumEngine actor, and document processing logic.

## Reference Documents

Read these files before starting:

1. **Primary Reference:** `/Users/ramerman/dev/voicelearn-ios/docs/UnaMentis_TDD.md`
   - Section 4: Curriculum Management System (lines ~1200-1600)
   - Section 4.2: Data Models (Curriculum, Topic, Document, TopicProgress entities)
   - Section 4.3: CurriculumEngine implementation
   - Section 4.4: Document Processing

2. **Project Structure:** `/Users/ramerman/dev/voicelearn-ios/README.md`

3. **Testing Guidelines:** `/Users/ramerman/dev/voicelearn-ios/docs/TESTING.md`
   - Follow TDD approach: write tests first, then implement

## Files to Create

### Core Data Model
- `/Users/ramerman/dev/voicelearn-ios/UnaMentis/UnaMentis.xcdatamodeld/` - Core Data model with entities

### Curriculum Components
Create these files:
1. `/Users/ramerman/dev/voicelearn-ios/UnaMentis/Core/Curriculum/CurriculumEngine.swift`
   - Actor that manages curriculum state and LLM context generation
   
2. `/Users/ramerman/dev/voicelearn-ios/UnaMentis/Core/Curriculum/CurriculumModels.swift`
   - Swift structs/classes matching Core Data entities for in-memory use

3. `/Users/ramerman/dev/voicelearn-ios/UnaMentis/Core/Curriculum/DocumentProcessor.swift`
   - Handles text extraction from PDF/markdown, summarization, embedding generation

4. `/Users/ramerman/dev/voicelearn-ios/UnaMentis/Core/Curriculum/ProgressTracker.swift`
   - Tracks mastery levels, time spent, quiz performance per topic

### Unit Tests (Write FIRST per TDD)
1. `/Users/ramerman/dev/voicelearn-ios/UnaMentisTests/Unit/CurriculumEngineTests.swift`
2. `/Users/ramerman/dev/voicelearn-ios/UnaMentisTests/Unit/DocumentProcessorTests.swift`
3. `/Users/ramerman/dev/voicelearn-ios/UnaMentisTests/Unit/ProgressTrackerTests.swift`

## Key Requirements from TDD

### Core Data Entities (Section 4.2)
```
Curriculum
├── id: UUID
├── name: String
├── topics: [Topic] (ordered relationship)
└── createdAt/updatedAt: Date

Topic
├── id: UUID
├── title: String
├── orderIndex: Int
├── mastery: Float (0.0-1.0)
├── documents: [Document]
└── progress: TopicProgress

Document
├── id: UUID
├── type: enum (pdf, text, markdown, transcript)
├── content: String (extracted text)
├── summary: String (LLM-generated)
├── embedding: Data (vector for semantic search)
└── sourceURL: URL?

TopicProgress
├── timeSpent: TimeInterval
├── quizScores: [Float]
└── lastAccessed: Date
```

### CurriculumEngine API (Section 4.3)
- `loadCurriculum(_ id: UUID)` - Load from Core Data
- `generateLLMContext(for topic: Topic)` - Create context string with outline, objectives, key points
- `updateProgress(for topic: Topic, mastery: Float, timeSpent: TimeInterval)`
- `semanticSearch(query: String)` - Find relevant documents using embeddings

### Pre-Generated Content Format
Use structured JSON format with:
- Sections with scripts, key points, duration
- Depth levels (basic → intermediate → advanced)
- Tangent hooks for topic jumping
- Socratic questions for engagement

## Existing Dependencies

The project already has:
- Xcode project at `/Users/ramerman/dev/voicelearn-ios/UnaMentis.xcodeproj`
- SPM dependencies configured (LiveKit, Swift Log, Swift Collections)
- Provider protocols in `/Users/ramerman/dev/voicelearn-ios/UnaMentis/Services/Protocols/`
- Test structure in `/Users/ramerman/dev/voicelearn-ios/UnaMentisTests/`

## DO NOT MODIFY

These files are being worked on by the other agent:
- `UnaMentis/Core/Audio/*`
- `UnaMentis/Core/Telemetry/*`
- `UnaMentis/Services/Protocols/VADService.swift`
- `UnaMentis/Services/Protocols/STTService.swift`
- `UnaMentis/Services/Protocols/TTSService.swift`
- `UnaMentis/Services/Protocols/LLMService.swift`

## Deliverables

1. Core Data model file (`.xcdatamodeld`)
2. CurriculumEngine actor with context generation
3. DocumentProcessor for text extraction
4. ProgressTracker for mastery tracking
5. Unit tests for all components (written first)
6. All code compiles with `xcodebuild -project UnaMentis.xcodeproj -scheme UnaMentis build`

## Success Criteria

- [ ] Core Data entities match TDD specification
- [ ] CurriculumEngine can generate LLM context from topic materials
- [ ] Progress tracking updates mastery levels correctly
- [ ] All unit tests pass
- [ ] Code follows Swift 6.0 strict concurrency (actors, Sendable)
