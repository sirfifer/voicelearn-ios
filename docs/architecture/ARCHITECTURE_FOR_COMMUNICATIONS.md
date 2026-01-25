# UnaMentis Architecture for Communications

*A visual and narrative guide to the voice AI tutoring platform*

---

## 1. The One-Sentence Story

**UnaMentis is a voice AI tutoring platform that enables 60-90+ minute personalized learning conversations with sub-500ms response times, working across iOS, Android, and web platforms, powered by AI that guides rather than replaces genuine understanding.**

---

## 2. The Problem We Solve

### The AI Paradox

We live in an age where AI can write essays, solve problems, and answer any question instantly. This power is extraordinary, but it creates a paradox: tools that do thinking for you prevent you from developing thinking skills. A calculator is useless to someone who doesn't understand what multiplication means. AI writing is hollow to someone who has never formed their own thoughts.

### The 90-Minute Gap

Existing voice AI assistants (Siri, Alexa, ChatGPT Voice Mode) are optimized for quick interactions: "What's the weather?" "Set a timer." "Who won the game?" They cannot sustain the kind of extended engagement that real learning requires. Try having a 90-minute calculus tutoring session with any voice assistant. It breaks down: context is lost, responses become generic, the conversation loops back on itself.

### The Curriculum Gap

Even if a voice AI could maintain a long conversation, where would the educational content come from? Traditional curriculum formats (SCORM, IMSCC) were designed for clicking through slides on a screen, not for voice-based tutoring. There's no standard way to represent "speak this content, then pause and check understanding, then offer a simpler explanation if confused."

### The Latency Wall

Voice interactions feel unnatural when response times exceed 500 milliseconds. Your brain expects conversation to flow. Delays that would be imperceptible in text become jarring in speech. Most AI systems cannot reliably hit sub-500ms latency while also providing thoughtful, contextual responses.

**UnaMentis solves all four problems.**

---

## 3. User Journeys

### Journey 1: The Student

```
Morning Study Session

"Hey Siri, start my calculus lesson"
                │
                ▼
┌────────────────────────────────────────┐
│  UnaMentis opens to last topic         │
│  "Let's continue with limits..."       │
└────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│  AI speaks curriculum content          │
│  Visual: Limit notation appears        │
│  "The formal definition states..."     │
└────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│  Student interrupts:                   │
│  "Wait, I'm confused about epsilon"    │
│  (Barge-in detected in <300ms)         │
└────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│  AI stops, pivots to simpler           │
│  explanation with analogy:             │
│  "Think of epsilon as a tolerance..."  │
└────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│  Teachback checkpoint:                 │
│  "Can you explain epsilon back to me   │
│   in your own words?"                  │
└────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│  Session continues for 75 minutes      │
│  Progress tracked, mastery measured    │
│  Resume tomorrow on any device         │
└────────────────────────────────────────┘
```

**Key insight:** The student interrupts, the AI adapts instantly. The session lasts over an hour. The student is asked to demonstrate understanding, not just listen passively.

### Journey 2: The Content Creator

```
Curriculum Import Flow

MIT OpenCourseWare Physics Course
                │
                ▼
┌────────────────────────────────────────┐
│  Operations Console: Select course     │
│  Click "Import to UnaMentis"           │
└────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│  7-Stage AI Enrichment Pipeline        │
│                                        │
│  1. Content Analysis                   │
│  2. Structure Inference                │
│  3. Content Segmentation               │
│  4. Learning Objective Extraction      │
│  5. Assessment Generation              │
│  6. Tutoring Enhancement               │
│  7. Knowledge Graph Construction       │
│                                        │
│  [████████████████░░░░] 80% complete   │
└────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│  Curriculum Studio: Review & Edit      │
│  AI-generated content has confidence   │
│  scores; human approves enrichments    │
└────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│  Publish: Available to all students    │
│  Syncs to iOS, Web, Android clients    │
│  Voice-optimized, ready for tutoring   │
└────────────────────────────────────────┘
```

**Key insight:** Sparse textbook content becomes rich tutoring material through AI enrichment, with human oversight ensuring quality.

---

## 4. The Voice Pipeline

The voice pipeline is the technical heart of UnaMentis. It turns a student's spoken words into AI responses in under 500 milliseconds.

### The Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           THE VOICE PIPELINE                                 │
│                        (Sub-500ms Round Trip)                                │
└─────────────────────────────────────────────────────────────────────────────┘

   Student         Device           Processing         Device          Student
   Speaks          Listens          Thinks             Speaks          Hears
      │               │                 │                 │               │
      ▼               ▼                 ▼                 ▼               ▼

   ┌─────┐       ┌─────────┐       ┌─────────┐       ┌─────────┐     ┌─────┐
   │  🎤 │ ────► │   VAD   │ ────► │   LLM   │ ────► │   TTS   │────►│  🔊 │
   │     │       │ Silero  │       │ Claude/ │       │ Kyutai  │     │     │
   │     │       │         │       │ GPT-4o  │       │ Pocket  │     │     │
   └─────┘       └────┬────┘       └────┬────┘       └─────────┘     └─────┘
                      │                 │
                      ▼                 ▼
                 ┌─────────┐       ┌─────────┐
                 │   STT   │ ────► │   FOV   │
                 │ Apple/  │       │ Context │
                 │ Deepgram│       │ Manager │
                 └─────────┘       └─────────┘

   ◄─────────────────────── <500ms total ───────────────────────►
```

### The Latency Budget

We budget latency like you budget money. Every millisecond has a purpose, and we never overspend.

| Stage | Budget | What Happens |
|-------|--------|--------------|
| **VAD** | 50ms | Voice Activity Detection determines when the student stops speaking |
| **STT** | 200ms | Speech-to-Text converts voice to words |
| **Context** | 50ms | FOV Context Manager builds optimal prompt from curriculum |
| **LLM TTFT** | 100ms | Large Language Model generates first response token |
| **TTS TTFB** | 100ms | Text-to-Speech streams first audio byte |
| **Total** | **<500ms** | Student hears AI response begin |

### The "Always Works" Philosophy

UnaMentis always works. No API key? Use Apple Speech. Server down? Fall back to cloud. Network gone? Run entirely on-device with Kyutai Pocket TTS and Ministral-3B LLM.

```
Primary Provider (Deepgram)
        │ fails
        ▼
Secondary Provider (Groq)
        │ fails
        ▼
On-Device Fallback (Apple Speech)
        │ always available
        ▼
Student Never Waits
```

---

## 5. The Intelligence Layer

UnaMentis doesn't depend on any single AI provider. It supports multiple options across three deployment models.

### The Provider Matrix

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        AI CAPABILITY MATRIX                               │
└──────────────────────────────────────────────────────────────────────────┘

                      On-Device           Self-Hosted          Cloud
                    (Zero Cost)          (Your Server)      (Pay-per-use)
              ┌───────────────────┬───────────────────┬───────────────────┐
  Speech-to-  │   Apple Speech    │    Whisper.cpp    │     Deepgram      │
  Text (STT)  │   GLM-ASR Nano    │   faster-whisper  │    AssemblyAI     │
              │                   │                   │       Groq        │
              ├───────────────────┼───────────────────┼───────────────────┤
  Text-to-    │  Kyutai Pocket    │    Chatterbox     │    ElevenLabs     │
  Speech      │    (100M)         │    VibeVoice      │     Deepgram      │
  (TTS)       │   Apple TTS       │    Piper TTS      │                   │
              ├───────────────────┼───────────────────┼───────────────────┤
  Language    │   Ministral-3B    │      Ollama       │  Claude 3.5       │
  Model       │  TinyLlama-1.1B   │       vLLM        │     GPT-4o        │
  (LLM)       │                   │                   │                   │
              └───────────────────┴───────────────────┴───────────────────┘

                         ◄───── Privacy Increases ─────►
                         ◄───── Latency Decreases ────►
```

### Spotlight: Kyutai Pocket TTS

Released January 2026, Kyutai Pocket represents a paradigm shift in on-device TTS. Previously, on-device meant choosing between robotic system voices or multi-gigabyte neural models requiring specialized hardware. Kyutai Pocket breaks this tradeoff:

- **100M parameters** (~100MB total): Small enough to download once
- **CPU-only execution**: Runs on any iPhone, no Neural Engine required
- **~200ms time-to-first-byte**: Comparable to cloud services
- **8 built-in voices**: Named after Les Misérables characters
- **5-second voice cloning**: Create custom voices from brief audio samples

### Provider Counts

| Capability | On-Device | Self-Hosted | Cloud | **Total** |
|------------|-----------|-------------|-------|-----------|
| STT | 2 | 2 | 5 | **9** |
| TTS | 2 | 4 | 2 | **8** |
| LLM | 2 | 2+ | 3 | **5+** |
| VAD | 2 | - | - | **2** |

---

## 6. The Curriculum System

Educational content flows from external sources through a standardized format to all client platforms.

### The Hub-and-Spoke Model

```
┌──────────────────────────────────────────────────────────────────────────┐
│                       CONTENT FLOW ARCHITECTURE                           │
└──────────────────────────────────────────────────────────────────────────┘

      SOURCES                        HUB                          CLIENTS
   ┌───────────┐                                               ┌───────────┐
   │ MIT OCW   │ ──┐                                       ┌──►│    iOS    │
   └───────────┘   │          ┌─────────────────┐          │   └───────────┘
   ┌───────────┐   │          │                 │          │   ┌───────────┐
   │   CK-12   │ ──┼─────────►│      UMCF       │──────────┼──►│    Web    │
   └───────────┘   │          │  (152 fields)   │          │   └───────────┘
   ┌───────────┐   │          │                 │          │   ┌───────────┐
   │ Fast.ai   │ ──┤          └─────────────────┘          └──►│  Android  │
   └───────────┘   │                 │                         └───────────┘
   ┌───────────┐   │                 │
   │ EngageNY  │ ──┘                 ▼
   └───────────┘              ┌─────────────────┐
   ┌───────────┐              │ AI Enrichment   │
   │ Stanford  │ ─────────────┤   Pipeline      │
   └───────────┘              │  (7 stages)     │
                              └─────────────────┘
```

### UMCF: Voice-Native Curriculum

The Una Mentis Curriculum Format (UMCF) is a JSON specification with 152 fields, designed from the ground up for conversational tutoring.

**What makes UMCF different from SCORM/IMSCC:**

| Feature | Traditional LMS | UMCF |
|---------|----------------|------|
| Primary use | Click-through slides | Voice tutoring |
| Content depth | 3-4 levels max | Unlimited nesting |
| Voice support | None | Native (`spokenText` variants) |
| Stopping points | None | Rich metadata |
| Misconception handling | None | Trigger phrases + remediation |
| Alternative explanations | None | Simpler, technical, analogy variants |

**Novel UMCF elements:**

```json
{
  "segments": [{
    "text": "The mitochondria produces ATP.",
    "spokenText": "The mitochondria produces A T P.",
    "stoppingPoint": {
      "type": "check_understanding",
      "prompt": "Can you explain what mitochondria do?"
    }
  }],
  "misconceptions": [{
    "triggerPhrases": ["only animals have"],
    "remediation": "Actually, both plant and animal cells have mitochondria..."
  }],
  "alternatives": {
    "simpler": "Mitochondria are like tiny batteries inside cells.",
    "technical": "Mitochondria generate ATP via oxidative phosphorylation."
  }
}
```

### Import Sources

| Source | Content Type | Status |
|--------|--------------|--------|
| MIT OpenCourseWare | Collegiate | 247 courses loaded |
| CK-12 FlexBooks | K-12 | Complete |
| EngageNY | K-12 (NY State) | Complete |
| MERLOT | Higher Ed | Complete |
| Fast.ai | AI/ML | Spec complete |
| Stanford SEE | Engineering | Spec complete |

---

## 7. The Platform Story

One curriculum, three platforms. Learn on your phone during commute, continue on web at your desk, review on tablet before bed. Your progress follows you.

### Platform Capabilities

```
┌──────────────────────────────────────────────────────────────────────────┐
│                       PLATFORM CAPABILITIES                               │
└──────────────────────────────────────────────────────────────────────────┘

                        iOS              Web              Android
                     (Primary)       (Complete)      (In Development)
              ┌───────────────────┬───────────────────┬───────────────────┐
  On-Device   │        ✓         │        —          │        ✓          │
  AI          │  Kyutai Pocket   │                   │    (planned)      │
              │   Ministral-3B   │                   │                   │
              ├───────────────────┼───────────────────┼───────────────────┤
  Voice       │   Full Pipeline  │   WebRTC via      │   Full Pipeline   │
  Pipeline    │   (9 STT, 8 TTS) │  OpenAI Realtime  │    (planned)      │
              ├───────────────────┼───────────────────┼───────────────────┤
  Offline     │        ✓         │        —          │        ✓          │
  Mode        │  Full sessions   │                   │    (planned)      │
              ├───────────────────┼───────────────────┼───────────────────┤
  Siri/       │        ✓         │        —          │        —          │
  Assistant   │ "Start lesson"   │                   │                   │
              └───────────────────┴───────────────────┴───────────────────┘
```

### Technology Stack

| Platform | Language | UI Framework | Audio |
|----------|----------|--------------|-------|
| **iOS** | Swift 6.0 | SwiftUI | AVAudioEngine |
| **Web** | TypeScript | Next.js 15 / React 19 | WebRTC |
| **Android** | Kotlin 2.0+ | Jetpack Compose | Oboe |

---

## 8. The Server Architecture

The backend consists of five interconnected components that together enable curriculum management, service orchestration, and client support.

### Server Component Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                       SERVER ARCHITECTURE                                 │
└──────────────────────────────────────────────────────────────────────────┘

       ┌─────────────────────────────────────────────────────────────┐
       │                    USM Core (Port 8787)                      │
       │                    Rust Service Manager                      │
       │  ┌───────────────────────────────────────────────────────┐  │
       │  │ Service Registry │ Process Monitor │ Event System     │  │
       │  │ HTTP/WebSocket   │ Real-time Metrics │ <50ms updates  │  │
       │  └───────────────────────────────────────────────────────┘  │
       └─────────────────────────────────────────────────────────────┘
                              │ manages
         ┌────────────────────┼────────────────────┐
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Management API  │  │ Ops Console     │  │ Web Client      │
│ Port 8766       │  │ Port 3000       │  │ Port 3001       │
│ Python/aiohttp  │  │ Next.js/React   │  │ Next.js/React   │
├─────────────────┤  ├─────────────────┤  ├─────────────────┤
│ • Curriculum    │  │ • Dashboards    │  │ • Voice Tutor   │
│ • FOV Context   │  │ • Curriculum    │  │ • Curriculum    │
│ • TTS Caching   │  │   Studio        │  │   Browser       │
│ • Sessions      │  │ • Voice Lab     │  │ • Visual Assets │
│ • Auth          │  │ • Plugin Mgr    │  │ • Analytics     │
│ • Latency Tests │  │ • Analytics     │  │                 │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Curriculum Importers                      │
│  Plugin-based: MIT OCW │ CK-12 │ EngageNY │ MERLOT │ Fast.ai │
│              → 7-Stage AI Enrichment → UMCF Output           │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Port | Purpose |
|-----------|------|---------|
| **USM Core** | 8787 | Cross-platform service orchestration, real-time monitoring |
| **Management API** | 8766 | Curriculum CRUD, TTS caching, FOV context, sessions, auth |
| **Operations Console** | 3000 | Admin UI for system monitoring and content management |
| **Web Client** | 3001 | Browser-based voice tutoring (feature parity with iOS) |
| **Importers** | N/A | Plugin-based curriculum ingestion from external sources |

---

## 9. The Operations View

For organizations deploying UnaMentis, the Operations Console provides comprehensive system management.

### Operations Console Capabilities

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       OPERATIONS CONSOLE                                 │
│                    (Next.js Admin Interface)                             │
└─────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
  │    Dashboard    │  │   Curriculum    │  │    Voice Lab    │
  │                 │  │     Studio      │  │                 │
  │ • System health │  │ • Browse        │  │ • AI model      │
  │ • Service       │  │   curriculum    │  │   selection     │
  │   status        │  │ • Edit UMCF     │  │ • TTS Lab       │
  │ • User sessions │  │ • Import new    │  │   experiments   │
  │ • Latency       │  │   content       │  │ • Batch audio   │
  │   metrics       │  │ • AI enrich     │  │   generation    │
  └─────────────────┘  └─────────────────┘  └─────────────────┘

  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
  │  Plugin Manager │  │    Analytics    │  │      Logs       │
  │                 │  │                 │  │                 │
  │ • Enable/       │  │ • Usage metrics │  │ • Real-time     │
  │   disable       │  │ • Performance   │  │   filtering     │
  │ • Configure     │  │   trends        │  │ • Debug tools   │
  │                 │  │ • Cost tracking │  │                 │
  └─────────────────┘  └─────────────────┘  └─────────────────┘
```

### Enterprise Use Case

A training department can:
1. Import corporate materials via the Importer plugin
2. Enrich content with AI-generated checkpoints and assessments
3. Batch-generate audio for 500 employees (TTS caching saves costs)
4. Track completion and mastery per learner
5. Monitor latency and quality metrics

All from one console.

---

## 10. The Quality Story

### Performance Targets

| Metric | Target | Status |
|--------|--------|--------|
| E2E Latency (P50) | <500ms | Achieved |
| E2E Latency (P99) | <1000ms | Achieved |
| Session Duration | 90+ min | Stable |
| Memory Growth | <50MB/hr | Validated |
| Code Coverage | 80%+ | Enforced |

### Testing Philosophy: "Real Over Mock"

We test like we're in production. The only things we mock are paid external APIs (OpenAI, ElevenLabs). Everything else uses real implementations:

- Real audio pipelines (not simulated)
- Real curriculum parsing (not stubs)
- Real session state machines (not simplified)
- Real latency measurements (not approximations)

This philosophy catches bugs that mock-heavy testing misses.

---

## 11. Specialized Modules

UnaMentis is not just a general tutor. It becomes specialized for high-stakes scenarios.

### Knowledge Bowl Module

Academic quiz bowl competition practice:

- **12+ subject domains**: Science, literature, history, math, arts, social science
- **Sub-3-second recall training**: Timed response practice
- **Competition simulation**: Buzzer mechanics, team coordination
- **3-tier answer validation**: Fuzzy matching → Embeddings → LLM verification
- **Regional compliance**: Colorado, Minnesota, Washington rule sets

### SAT Preparation Module

Digital SAT (2024+ format) preparation:

- **Adaptive practice**: Mimics Multi-Stage Testing (MST)
- **Test-taking strategy**: Time management, question triage
- **Performance psychology**: Test anxiety, focus techniques
- **Score prediction**: Targeted improvement recommendations

---

## 12. Stats for Infographics

Pull-ready numbers for design teams:

### AI Providers

| Category | Count |
|----------|-------|
| STT Providers | 9 |
| TTS Providers | 8 |
| LLM Providers | 5+ |
| VAD Options | 2 |

### Curriculum System

| Metric | Value |
|--------|-------|
| UMCF Schema Fields | 152 |
| Standards-Derived Fields | 82 (54%) |
| UMCF-Native Fields | 70 (46%) |
| Import Sources | 6+ |
| AI Enrichment Stages | 7 |

### Performance

| Metric | Value |
|--------|-------|
| Target Latency (P50) | <500ms |
| Target Latency (P99) | <1000ms |
| Session Duration | 90+ min |
| Memory Budget | <50MB/hr |
| Code Coverage | 80%+ |

### Platforms

| Category | Count |
|----------|-------|
| Client Platforms | 3 (iOS, Web, Android) |
| Server Components | 5 |
| Server Ports | 4 (8787, 8766, 3000, 3001) |

---

## 13. Visual Diagram Specifications

Specifications for design teams creating infographics:

### 1. Voice Pipeline Flow (Horizontal Swim Lane)

- **Content**: Microphone → VAD → STT → Context → LLM → TTS → Speaker
- **Annotations**: Timing for each stage (50ms, 200ms, 50ms, 100ms, 100ms)
- **Style**: Tech-forward, flowing arrows, timing callouts
- **Use**: Presentations, technical blog posts

### 2. AI Provider Matrix (Grid)

- **Rows**: STT, TTS, LLM
- **Columns**: On-Device, Self-Hosted, Cloud
- **Content**: Provider names in each cell
- **Annotations**: "Privacy increases →" and "Latency decreases →"
- **Use**: Capability comparisons, decision guides

### 3. Curriculum Flow (Hub-and-Spoke)

- **Hub**: UMCF (center)
- **Spokes (left)**: MIT OCW, CK-12, Fast.ai, EngageNY
- **Spokes (right)**: iOS, Web, Android
- **Annotations**: "7-Stage AI Enrichment" below hub
- **Use**: Content partner discussions, education stakeholders

### 4. Platform Capability Matrix (Comparison Table)

- **Rows**: On-Device AI, Voice Pipeline, Offline Mode, Assistant Integration
- **Columns**: iOS, Web, Android
- **Content**: Check marks, dashes, "(planned)" labels
- **Use**: Product sheets, website feature pages

### 5. Server Architecture (Component Diagram)

- **Components**: USM Core (top), Management API, Ops Console, Web Client (middle), Importers (bottom)
- **Annotations**: Port numbers, technology labels
- **Connections**: USM Core manages all others
- **Use**: Technical overviews, enterprise documentation

---

## 14. Narrative Templates

Ready-to-use text for different communication contexts.

### For Presentations (60 seconds)

> "UnaMentis is a voice AI tutoring platform that enables 90-minute learning conversations with sub-500ms response times. Unlike voice assistants that give quick answers, UnaMentis builds genuine understanding through curriculum-driven lessons, comprehension checks, and personalized adaptation. It works across iOS, web, and Android, with intelligent fallback that ensures it always works, even offline."

### For Technical Articles (200 words)

> "UnaMentis addresses the gap between voice AI assistants and genuine educational tutoring. The platform achieves sub-500ms end-to-end latency through a sophisticated pipeline: Silero VAD detects speech boundaries, configurable STT providers (Apple Speech, Deepgram, Groq) convert speech to text, a foveated context manager builds optimal LLM prompts from curriculum content, and neural TTS (including the 100M-parameter Kyutai Pocket running entirely on-device) streams audio back to the learner.
>
> The architecture supports graceful degradation across on-device, self-hosted, and cloud providers, ensuring the app always functions even without network connectivity. Educational content flows through UMCF, a 152-field curriculum format designed specifically for voice-native tutoring, with AI enrichment pipelines that transform sparse source content into rich, interactive lessons.
>
> The platform spans iOS (Swift 6.0/SwiftUI), web (Next.js/React), and Android (Kotlin), with specialized modules for high-stakes scenarios like SAT preparation and academic quiz bowl competitions."

### For Non-Technical Stakeholders (100 words)

> "UnaMentis is like having a personal tutor who talks with you for an hour or more, adapts to your confusion, asks you to explain things back, and remembers what you learned last week. It uses AI to deliver personalized instruction at scale, but the goal is not to give you answers, it is to build genuine understanding. The app works on iPhone, web browsers, and Android phones, with content imported from sources like MIT OpenCourseWare. It even works offline, using AI that runs entirely on your phone."

---

## Summary

UnaMentis is a multi-platform voice AI tutoring system built on these principles:

1. **AI as tutor, not substitute**: Building understanding, not providing shortcuts
2. **Voice-native design**: Every component optimized for speech interaction
3. **Provider flexibility**: 9 STT, 8 TTS, 5+ LLM options with automatic fallback
4. **Curriculum-driven**: UMCF format with 152 fields for voice tutoring
5. **Extended session stability**: 90+ minutes without degradation
6. **Sub-500ms latency**: Real conversational flow
7. **Multi-platform reach**: iOS, Web, Android with progress sync
8. **Open core**: Fundamental technology remains open source

The architecture prioritizes **learner outcomes** while maintaining **cost transparency**, **performance targets**, and **provider flexibility** across all platforms.

---

*Last updated: January 2026*
