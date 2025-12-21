# UnaMentis AI Task Analysis & Model Routing Strategy

**Purpose:** Break down every AI/LLM task to understand capability requirements and optimal deployment strategies.

---

## Executive Summary

This document analyzes every AI-dependent task in UnaMentis to determine:
1. Whether AI is actually needed (vs simple deterministic code)
2. If AI is needed, what capability level is required
3. Optimal deployment: On-Device | Self-Hosted Server | Cloud API
4. Multi-model routing strategy with fallbacks

---

## 1. Complete AI Task Inventory

### 1.1 Currently Implemented Tasks

| # | Task | Current Implementation | AI Required? |
|---|------|----------------------|--------------|
| 1 | Voice Activity Detection (VAD) | Silero CoreML on Neural Engine | ✅ Yes - On-device ML |
| 2 | Speech-to-Text (STT) | AssemblyAI / Deepgram WebSocket | ✅ Yes - Complex ASR |
| 3 | Text-to-Speech (TTS) | ElevenLabs / Deepgram | ✅ Yes - Natural voice synthesis |
| 4 | Conversational AI Response | OpenAI GPT-4o / Claude 3.5 | ✅ Yes - Core tutoring |
| 5 | Semantic Document Search | OpenAI Embeddings | ✅ Yes - Vector similarity |
| 6 | Context Generation for LLM | CurriculumEngine string building | ❌ No - Deterministic |
| 7 | Progress Tracking | Core Data writes | ❌ No - Deterministic |
| 8 | Cost Calculation | Simple math | ❌ No - Deterministic |
| 9 | Latency Tracking | Timestamp diffs | ❌ No - Deterministic |
| 10 | Audio Level Monitoring | RMS calculation | ❌ No - Deterministic |

### 1.2 Implicit/Future AI Tasks (Not Yet Implemented)

| # | Task | Description | AI Required? |
|---|------|-------------|--------------|
| 11 | Understanding Assessment | Determine if student grasped concept | ✅ Yes - Needs reasoning |
| 12 | Question Generation | Generate Socratic questions | ✅ Yes - Needs creativity |
| 13 | Concept Extraction | Extract concepts from student response | ✅ Probably - NLU |
| 14 | Topic Recommendation | Suggest next topic based on performance | ⚠️ Maybe - Could be rules |
| 15 | Document Summarization | Summarize curriculum documents | ✅ Yes - Needs comprehension |
| 16 | Transcript Summarization | Summarize session transcripts | ✅ Yes - Needs comprehension |
| 17 | Learning Objective Matching | Match responses to objectives | ⚠️ Maybe - Could use embeddings only |
| 18 | Difficulty Adaptation | Adjust explanation complexity | ✅ Yes - Needs meta-cognition |
| 19 | Error Detection | Detect misconceptions in student answers | ✅ Yes - Domain knowledge |
| 20 | Explanation Generation | Generate analogies/examples | ✅ Yes - Needs creativity |
| 21 | Conversation Routing | Decide when to move topics | ⚠️ Maybe - Rules + simple classifier |
| 22 | Intent Classification | Classify user intent (question/statement/etc) | ⚠️ Maybe - Small model sufficient |
| 23 | Keyword Extraction | Extract key terms from speech | ⚠️ Maybe - Can be regex/NLP |
| 24 | Sentiment Analysis | Detect confusion/frustration | ⚠️ Maybe - Small model sufficient |

---

## 2. Task Capability Analysis

### Tier 1: No AI Needed (Deterministic Logic)
These can be done with simple code:

```
┌─────────────────────────────────────────────────────────────┐
│  DETERMINISTIC TASKS - No AI Required                       │
├─────────────────────────────────────────────────────────────┤
│  • Context string assembly (generateContext)                │
│  • Progress tracking (Core Data CRUD)                       │
│  • Cost/latency calculations (arithmetic)                   │
│  • Audio level monitoring (RMS calculation)                 │
│  • Conversation history management (array operations)       │
│  • Topic ordering/navigation (sorted arrays)                │
│  • Timer/duration tracking                                  │
│  • Configuration management                                 │
│  • File I/O for documents                                   │
│  • Token counting (rough estimation: len/4)                 │
└─────────────────────────────────────────────────────────────┘
```

### Tier 2: Tiny Models (On-Device Feasible - ~100M-500M params)
Low capability but fast, can run on Neural Engine:

```
┌─────────────────────────────────────────────────────────────┐
│  TINY MODEL TASKS - On-Device CoreML                        │
├─────────────────────────────────────────────────────────────┤
│  Task                    │ Model Size │ Latency │ Accuracy  │
│  ────────────────────────┼────────────┼─────────┼────────── │
│  Voice Activity Detection│ ~5MB       │ ~20ms   │ 95%+      │
│  Intent Classification   │ ~50-100MB  │ ~50ms   │ 85-90%    │
│  Sentiment Analysis      │ ~50-100MB  │ ~50ms   │ 80-85%    │
│  Keyword Extraction      │ ~50-100MB  │ ~50ms   │ 85%+      │
│  Embedding Generation    │ ~100-200MB │ ~100ms  │ Varies    │
│                                                              │
│  Candidates: DistilBERT, MiniLM, TinyBERT, all-MiniLM-L6    │
│  CoreML conversion available for most                        │
└─────────────────────────────────────────────────────────────┘
```

### Tier 3: Small LLMs (On-Device Possible - 1B-3B params)
Can run on iPhone 15/16 Pro with Neural Engine + memory constraints:

```
┌─────────────────────────────────────────────────────────────┐
│  SMALL LLM TASKS - On-Device MLX/CoreML                     │
├─────────────────────────────────────────────────────────────┤
│  Task                      │ Min Params │ Notes             │
│  ──────────────────────────┼────────────┼────────────────── │
│  Simple Q&A generation     │ 1-3B       │ Llama 3.2 1B/3B   │
│  Text reformulation        │ 1-3B       │ Mistral 7B Q4     │
│  Basic summarization       │ 1-3B       │ May lack quality  │
│  Concept extraction        │ 1-3B       │ Structured output │
│  Topic classification      │ 1-3B       │ Good accuracy     │
│                                                              │
│  Performance on iPhone 16 Pro Max:                          │
│  - Llama 3.2 1B: ~30 tokens/sec                             │
│  - Llama 3.2 3B: ~15 tokens/sec                             │
│  - Mistral 7B Q4: ~8 tokens/sec (marginal)                  │
│                                                              │
│  Thermal: Can run ~5-10 min before throttling               │
└─────────────────────────────────────────────────────────────┘
```

### Tier 4: Medium LLMs (Self-Hosted Server - 7B-70B params)
Your Mac Studio M4 Max 128GB can run these:

```
┌─────────────────────────────────────────────────────────────┐
│  MEDIUM LLM TASKS - Self-Hosted Server                      │
├─────────────────────────────────────────────────────────────┤
│  Task                      │ Min Params │ Quality           │
│  ──────────────────────────┼────────────┼────────────────── │
│  Tutoring responses        │ 7-13B      │ Good for basics   │
│  Document summarization    │ 7-13B      │ Good quality      │
│  Explanation generation    │ 7-13B      │ Acceptable        │
│  Understanding assessment  │ 13-30B     │ Good reliability  │
│  Complex Q&A               │ 30-70B     │ High quality      │
│                                                              │
│  Mac Studio M4 Max 128GB Performance:                       │
│  - Llama 3.1 8B: ~100 tokens/sec                            │
│  - Llama 3.1 70B Q4: ~20 tokens/sec                         │
│  - Mixtral 8x7B: ~40 tokens/sec                             │
│  - Qwen 2.5 72B: ~15 tokens/sec                             │
│                                                              │
│  Cost: $0 per token (electricity only)                      │
│  Latency: Depends on home network + model                   │
└─────────────────────────────────────────────────────────────┘
```

### Tier 5: Frontier LLMs (Cloud API - GPT-4o, Claude 3.5+)
Maximum capability, highest cost:

```
┌─────────────────────────────────────────────────────────────┐
│  FRONTIER LLM TASKS - Cloud APIs                            │
├─────────────────────────────────────────────────────────────┤
│  Task                         │ Best Model │ Why Frontier?  │
│  ─────────────────────────────┼────────────┼─────────────── │
│  Complex tutoring dialogues   │ GPT-4o     │ Nuanced pedagogy│
│  Advanced understanding check │ Claude 3.5 │ Reasoning depth │
│  Domain expert explanations   │ GPT-4o     │ Knowledge breadth
│  Multi-step problem solving   │ Claude 3.5 │ Chain of thought│
│  Detecting subtle errors      │ GPT-4o     │ Precision needed│
│  Generating novel analogies   │ Claude 3.5 │ Creativity      │
│                                                              │
│  Cost (per 90-min session, ~50 turns):                      │
│  - GPT-4o: ~$0.50-1.50                                      │
│  - GPT-4o-mini: ~$0.05-0.15                                 │
│  - Claude 3.5 Sonnet: ~$0.75-2.00                           │
│  - Claude 3.5 Haiku: ~$0.10-0.30                            │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Detailed Task-by-Task Analysis

### 3.1 Voice Activity Detection (VAD)

**Current:** Silero VAD on CoreML (Neural Engine)

| Aspect | Analysis |
|--------|----------|
| **AI Needed?** | Yes - distinguishing speech from noise requires pattern recognition |
| **Capability Required** | Low - binary classification, 512-sample windows |
| **Latency Requirement** | <30ms (real-time) |
| **Best Deployment** | ✅ **ON-DEVICE** - Silero is perfect |
| **Alternatives** | WebRTC VAD (simpler, less accurate), Apple's built-in |

**Recommendation:** Keep Silero on-device. No changes needed.

---

### 3.2 Speech-to-Text (STT)

**Current:** AssemblyAI Universal-Streaming / Deepgram Nova-3

| Aspect | Analysis |
|--------|----------|
| **AI Needed?** | Yes - ASR is complex neural network task |
| **Capability Required** | High - needs large acoustic + language models |
| **Latency Requirement** | <300ms for real-time streaming |
| **On-Device Options** | Apple Speech (SFSpeechRecognizer) - free, private, ~200ms |
| **Best Deployment** | Cloud API for quality, Apple Speech as fallback |

**Multi-Model Strategy:**
```
Primary:    Deepgram Nova-3    ($0.26/hr, ~150ms latency, high quality)
Secondary:  AssemblyAI         ($0.65/hr, ~200ms latency, backup)
Fallback:   Apple Speech       (FREE, ~200ms, on-device, privacy mode)
Offline:    Apple Speech       (Must use when no network)
```

**Recommendation:** Implement Apple Speech as on-device fallback. Use for:
- Offline mode
- Privacy-first mode
- Cost-reduction mode
- Network failure fallback

---

### 3.3 Text-to-Speech (TTS)

**Current:** ElevenLabs Turbo v2.5 / Deepgram Aura-2

| Aspect | Analysis |
|--------|----------|
| **AI Needed?** | Yes - natural voice synthesis requires neural vocoder |
| **Capability Required** | Medium-High for natural sounding voice |
| **Latency Requirement** | <200ms TTFB for streaming |
| **On-Device Options** | Apple AVSpeechSynthesizer - free, robotic but usable |
| **Best Deployment** | Cloud API for quality, Apple TTS as fallback |

**Multi-Model Strategy:**
```
Primary:    Deepgram Aura-2     ($0.015/1K chars, ~80ms TTFB, good quality)
Secondary:  ElevenLabs Turbo    ($0.018/char, ~250ms TTFB, best quality)
Fallback:   Apple TTS           (FREE, ~50ms, on-device, robotic)
Offline:    Apple TTS           (Must use when no network)
```

**Recommendation:** Implement Apple TTS as on-device fallback. Quality is acceptable for:
- Offline mode
- Privacy-first mode
- Reading back text (non-conversational)
- Network failure scenarios

---

### 3.4 Conversational AI Response (Core Tutoring)

**Current:** OpenAI GPT-4o / Anthropic Claude 3.5 Sonnet

| Aspect | Analysis |
|--------|----------|
| **AI Needed?** | Yes - this is the core AI tutoring capability |
| **Capability Required** | **HIGH** - needs reasoning, knowledge, pedagogy |
| **Latency Requirement** | <500ms TTFT acceptable |
| **Tasks Within This** | See breakdown below |

**Sub-Task Breakdown:**

| Sub-Task | Capability Needed | Smallest Viable Model |
|----------|------------------|----------------------|
| Acknowledge user input | Very Low | Llama 3.2 1B |
| Simple factual Q&A | Low | Llama 3.2 3B |
| Explain a concept | Medium | Llama 3.1 8B |
| Generate practice questions | Medium | Llama 3.1 8B |
| Socratic questioning | Medium-High | Llama 3.1 70B or GPT-4o-mini |
| Check understanding deeply | High | GPT-4o / Claude 3.5 |
| Detect subtle misconceptions | Very High | GPT-4o / Claude 3.5 |
| Generate novel analogies | High | GPT-4o / Claude 3.5 |
| Complex multi-step reasoning | Very High | GPT-4o / Claude 3.5 |

**Multi-Model Strategy:**
```
┌────────────────────────────────────────────────────────────────┐
│  INTELLIGENT MODEL ROUTING FOR TUTORING                        │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  User Says Something                                            │
│         │                                                       │
│         ▼                                                       │
│  ┌──────────────────┐                                          │
│  │ Intent Classifier │  (On-Device, Tiny Model)                │
│  │   ~50ms latency   │                                          │
│  └────────┬─────────┘                                          │
│           │                                                     │
│     ┌─────┴─────┬──────────┬──────────┬──────────┐            │
│     ▼           ▼          ▼          ▼          ▼            │
│  Simple     Factual    Explain    Check      Complex          │
│  Ack/Filler  Question   Request   Understand  Reasoning       │
│     │           │          │          │          │            │
│     ▼           ▼          ▼          ▼          ▼            │
│  On-Device   Self-Host  Self-Host  Cloud API  Cloud API       │
│  Llama 1B   Llama 8B   Llama 70B  GPT-4o-mini GPT-4o         │
│  ~30ms      ~200ms     ~500ms     ~200ms      ~300ms          │
│  $0         $0         $0         ~$0.001     ~$0.01          │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

**Concrete Examples:**

| User Says | Routed To | Why |
|-----------|-----------|-----|
| "Okay" | On-device 1B | Simple acknowledgment response |
| "What year was WWII?" | Self-hosted 8B | Simple factual lookup |
| "Explain quantum entanglement" | Self-hosted 70B | Needs good explanation |
| "I think I get it but..." | Cloud GPT-4o-mini | Understanding check |
| "Why can't FTL travel work?" | Cloud GPT-4o | Complex physics reasoning |
| "Wait, isn't that like..." | Cloud Claude 3.5 | Novel analogy evaluation |

---

### 3.5 Semantic Document Search (Embeddings)

**Current:** OpenAI text-embedding-3-small (API)

| Aspect | Analysis |
|--------|----------|
| **AI Needed?** | Yes - semantic similarity requires embeddings |
| **Capability Required** | Medium - 1536-dim embeddings sufficient |
| **Latency Requirement** | Not real-time, can be async/batch |
| **On-Device Options** | all-MiniLM-L6-v2 (22M params, 384-dim) |

**Multi-Model Strategy:**
```
Document Ingestion (Async, One-time):
  - Use OpenAI text-embedding-3-small for quality
  - Pre-compute and store embeddings in Core Data
  - Cost: ~$0.02 per 1M tokens (negligible)

Runtime Query Embedding:
  Primary:   On-Device MiniLM   (FREE, ~100ms, good quality)
  Fallback:  OpenAI API         ($0.02/1M tokens, ~200ms)
```

**Recommendation:**
- Keep OpenAI for document ingestion (quality matters, done once)
- Add on-device MiniLM for runtime query embedding (free, fast)
- Embeddings are compatible if you use the same model for docs and queries

---

### 3.6 Intent Classification (NEW - Recommended)

**Current:** Not implemented

| Aspect | Analysis |
|--------|----------|
| **AI Needed?** | Maybe - could be rules, but ML is more robust |
| **Capability Required** | Low - simple multi-class classification |
| **Latency Requirement** | <50ms (must be before LLM routing) |
| **Best Deployment** | ✅ **ON-DEVICE** - tiny classifier |

**Intent Categories:**
```swift
enum UserIntent: String, CaseIterable {
    case acknowledgment    // "okay", "I see", "right"
    case factualQuestion   // "what is X?", "when did Y?"
    case explanationRequest // "explain X", "how does Y work?"
    case clarification     // "what do you mean?", "can you repeat?"
    case understandingClaim // "I think I understand", "so basically..."
    case disagreement      // "I don't think that's right", "but..."
    case tangent           // "by the way", "unrelated but..."
    case completion        // "I'm done", "let's move on"
    case confusion         // "I'm lost", "this is confusing"
    case other
}
```

**Implementation:**
- Fine-tune DistilBERT or use zero-shot classifier
- Convert to CoreML, run on Neural Engine
- ~50MB model, ~50ms inference

---

### 3.7 Understanding Assessment (NEW - Enhanced)

**Current:** Implicit in LLM prompting

**Recommendation:** Make this explicit with tiered approach:

```
┌───────────────────────────────────────────────────────────────┐
│  UNDERSTANDING ASSESSMENT PIPELINE                            │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  Student Response                                              │
│         │                                                      │
│         ▼                                                      │
│  ┌──────────────────────┐                                     │
│  │ Quick Heuristics     │  (No AI - deterministic)            │
│  │ - Response length    │                                     │
│  │ - Key term presence  │                                     │
│  │ - Confidence phrases │                                     │
│  └──────────┬───────────┘                                     │
│             │                                                  │
│     Score < threshold?                                         │
│        │         │                                             │
│       Yes        No ────► Assume understanding, continue      │
│        │                                                       │
│        ▼                                                       │
│  ┌──────────────────────┐                                     │
│  │ Embedding Similarity │  (On-Device MiniLM)                 │
│  │ Compare to expected  │                                     │
│  │ concept embeddings   │                                     │
│  └──────────┬───────────┘                                     │
│             │                                                  │
│     Score < threshold?                                         │
│        │         │                                             │
│       Yes        No ────► Likely understands, maybe verify    │
│        │                                                       │
│        ▼                                                       │
│  ┌──────────────────────┐                                     │
│  │ LLM Deep Assessment  │  (Cloud API)                        │
│  │ Detailed analysis    │                                     │
│  │ of misconceptions    │                                     │
│  └──────────────────────┘                                     │
│                                                                │
└───────────────────────────────────────────────────────────────┘
```

---

## 4. Proposed Multi-Model Architecture

### 4.1 Model Registry

```swift
enum AIModel: String, CaseIterable {
    // On-Device (Neural Engine / MLX)
    case sileroVAD          // VAD only
    case miniLMEmbedding    // Embeddings
    case distilBERTIntent   // Intent classification
    case llama1B            // Simple responses
    case llama3B            // Basic tutoring

    // Self-Hosted Server (Your Mac)
    case llama8B            // Good explanations
    case llama70B           // Complex tutoring
    case mixtral8x7B        // Balanced quality

    // Cloud APIs
    case gpt4oMini          // Cost-effective cloud
    case gpt4o              // Best OpenAI
    case claude35Haiku      // Fast Claude
    case claude35Sonnet     // Best Claude

    // STT
    case appleSpeech        // On-device STT
    case deepgramNova3      // Cloud STT
    case assemblyAI         // Cloud STT backup

    // TTS
    case appleTTS           // On-device TTS
    case deepgramAura2      // Cloud TTS
    case elevenLabsTurbo    // Premium TTS
}
```

### 4.2 Model Router Service

```swift
actor ModelRouter {
    struct RoutingDecision {
        let primaryModel: AIModel
        let fallbackModels: [AIModel]
        let estimatedLatencyMs: Int
        let estimatedCostUSD: Decimal
    }

    func routeRequest(
        task: AITask,
        userIntent: UserIntent?,
        networkStatus: NetworkStatus,
        thermalState: ThermalState,
        costBudget: CostBudget
    ) -> RoutingDecision
}
```

### 4.3 Fallback Chain Configuration

```swift
struct FallbackChain {
    // For main tutoring responses
    static let tutoring: [AIModel] = [
        .gpt4o,           // Best quality
        .gpt4oMini,       // If cost limited
        .llama70B,        // If network slow
        .llama8B,         // If server busy
        .llama3B          // Emergency on-device
    ]

    // For STT
    static let stt: [AIModel] = [
        .deepgramNova3,   // Primary
        .assemblyAI,      // Backup cloud
        .appleSpeech      // Offline fallback
    ]

    // For TTS
    static let tts: [AIModel] = [
        .deepgramAura2,   // Primary (fast)
        .elevenLabsTurbo, // If quality needed
        .appleTTS         // Offline fallback
    ]
}
```

---

## 5. Implementation Recommendations

### Phase 1: On-Device Foundations (Immediate)
1. **Implement Apple Speech STT** as offline fallback
2. **Implement Apple TTS** as offline fallback
3. **Add intent classifier** (CoreML DistilBERT)
4. **Add on-device embeddings** (MiniLM)

### Phase 2: Self-Hosted Server (Short-term)
1. **Set up Ollama or llama.cpp server** on Mac
2. **Implement LLM routing logic** based on intent
3. **Add latency monitoring** for server models
4. **Create fallback triggers** for cloud when server slow

### Phase 3: Intelligent Routing (Medium-term)
1. **Build ModelRouter service** with all logic
2. **Add cost tracking per model**
3. **Implement thermal-aware routing** (use cloud when device hot)
4. **A/B test quality** between model tiers

### Phase 4: Optimization (Long-term)
1. **Fine-tune small models** on tutoring dialogues
2. **Distill knowledge** from GPT-4o to smaller models
3. **Implement speculative generation** (draft with small, verify with large)
4. **Build quality scoring** to know when small model failed

---

## 6. Cost-Latency-Quality Tradeoffs

### Scenario Analysis for 90-minute Session (~50 turns)

| Strategy | Est. Cost | Avg Latency | Quality |
|----------|-----------|-------------|---------|
| All GPT-4o | ~$1.50 | ~300ms | ⭐⭐⭐⭐⭐ |
| All GPT-4o-mini | ~$0.15 | ~200ms | ⭐⭐⭐⭐ |
| Intelligent routing | ~$0.30 | ~250ms | ⭐⭐⭐⭐½ |
| All self-hosted 70B | ~$0 | ~600ms | ⭐⭐⭐⭐ |
| All on-device 3B | ~$0 | ~400ms | ⭐⭐½ |
| Privacy mode (all on-device) | ~$0 | ~350ms | ⭐⭐⭐ |

### Recommended Default: Intelligent Routing
- Use intent classification to route
- 70% of requests to self-hosted (simple stuff)
- 30% of requests to cloud (complex reasoning)
- Result: ~$0.30/session with near-GPT-4o quality

---

## 7. Summary: What Can Run Where

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT SUMMARY                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ON-DEVICE (iPhone Neural Engine)                                   │
│  ─────────────────────────────────                                  │
│  ✅ VAD (Silero) - Already implemented                              │
│  ✅ Intent Classification - NEW, highly recommended                 │
│  ✅ Sentiment Analysis - Optional                                   │
│  ✅ Query Embeddings - Recommended for RAG                          │
│  ⚠️ Small LLM (1-3B) - Possible but limited quality                │
│  ✅ Apple STT - Free fallback                                       │
│  ✅ Apple TTS - Free fallback                                       │
│                                                                      │
│  SELF-HOSTED SERVER (Mac M4 Max)                                    │
│  ─────────────────────────────────                                  │
│  ✅ Llama 8B - Basic tutoring, fast                                 │
│  ✅ Llama 70B Q4 - Good tutoring, slower                            │
│  ✅ Mixtral 8x7B - Balanced option                                  │
│  ✅ Document embeddings (batch)                                     │
│  ✅ Summarization (async)                                           │
│                                                                      │
│  CLOUD APIs                                                         │
│  ─────────────────────────────────                                  │
│  ✅ GPT-4o/Claude 3.5 - Complex reasoning, best quality             │
│  ✅ GPT-4o-mini/Haiku - Cost-effective good quality                 │
│  ✅ Deepgram/AssemblyAI STT - Best transcription                    │
│  ✅ ElevenLabs/Deepgram TTS - Best voices                           │
│  ✅ OpenAI Embeddings - Document ingestion                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. Next Steps

1. **Create `ModelRouter` actor** with routing logic
2. **Implement Apple STT/TTS services** as fallbacks
3. **Add intent classifier** CoreML model
4. **Set up local LLM server** (Ollama recommended)
5. **Build cost dashboard** showing per-model usage
6. **Add network/thermal monitoring** for intelligent routing
7. **Create A/B testing framework** for quality comparison

---

*Document created: December 2024*
*Last updated: December 2024*
