# Multilingual Voice Learning Exploration

## Executive Summary

This document explores the comprehensive requirements for supporting multilingual voice-based learning in UnaMentis. The challenge is multi-dimensional: LLMs must understand and reason in multiple languages, translate curriculum accurately in educational contexts, and TTS must produce native-quality pronunciation with proper prosody. This exploration covers the current state of our infrastructure, the capabilities of modern models, critical gaps, and a recommended implementation path.

**Key Finding**: UnaMentis is already positioned better than expected. Qwen 2.5 7B (our primary self-hosted model) has strong multilingual support for 27+ languages. Whisper (our STT) supports 100 languages. ElevenLabs (our TTS) supports 32 languages with the Turbo model. The infrastructure is there—but the implementation is English-only.

---

## Table of Contents

1. [Current Infrastructure State](#1-current-infrastructure-state)
2. [LLM Multilingual Capabilities](#2-llm-multilingual-capabilities)
3. [Text-to-Speech Multilingual Analysis](#3-text-to-speech-multilingual-analysis)
4. [Speech-to-Text Multilingual Analysis](#4-speech-to-text-multilingual-analysis)
5. [Curriculum Translation Challenges](#5-curriculum-translation-challenges)
6. [Language Support Matrix](#6-language-support-matrix)
7. [Critical Implementation Gaps](#7-critical-implementation-gaps)
8. [Recommended Implementation Path](#8-recommended-implementation-path)
9. [Research Sources](#9-research-sources)

---

## 1. Current Infrastructure State

### What's Already Prepared (Good News)

UnaMentis has **solid foundational infrastructure** for internationalization:

| Component | Status | Details |
|-----------|--------|---------|
| **UMCF Curriculum Format** | ✅ Ready | BCP 47 language codes in metadata (`metadata.language`) |
| **Pronunciation Data** | ✅ Ready | IPA support, `xml:lang` attributes, language-tagged terms |
| **iOS Localization Framework** | ✅ Ready | `en.lproj/Localizable.strings` with 114 strings |
| **Database Schema** | ✅ Ready | `language VARCHAR(10)` column, indexed |
| **Service Abstractions** | ✅ Ready | Language parameters exist in most STT/TTS services |
| **Style Guide** | ✅ Ready | Mandates `LocalizedStringKey`, RTL support, text expansion |

### What's NOT Implemented (The Gap)

Despite infrastructure readiness, the app operates **English-only**:

| Component | Issue |
|-----------|-------|
| **Apple STT** | Hardcoded to `en-US` (`SFSpeechRecognizer(locale: Locale(identifier: "en-US"))`) |
| **Apple TTS** | Voice selection defaults to English only |
| **Self-Hosted STT** | Default language: `"en"` |
| **User Preferences** | No UI to select learning language |
| **Language Validation** | No check that curriculum matches session language |
| **Voice Matching** | TTS voice not matched to curriculum language |
| **Web UI** | No i18n package (English-only Next.js) |

---

## 2. LLM Multilingual Capabilities

### Current Model: Qwen 2.5 7B

The codebase shows examples using `qwen2.5:7b` via SelfHostedLLMService. This is excellent news for multilingual:

**Qwen 2.5 7B Multilingual Strengths:**
- **27+ languages** natively supported
- **Strong Asian language performance**: Japanese, Korean, Vietnamese, Thai, Indonesian
- **European languages**: English, Spanish, French, German, Italian
- **Technical translation**: Cross-lingual document analysis with context preservation
- **Training data**: 18 trillion tokens from multilingual datasets
- **Context**: 128,000 token context length

> *"Qwen 2.5 offers advanced capabilities for cross-lingual document analysis, translation with context preservation, and multilingual content generation that maintains semantic accuracy across language boundaries."*
> — [Qwen 2.5 Technical Report](https://arxiv.org/pdf/2412.15115)

### Comparison: Mistral 7B Limitations

If switching to Mistral 7B was considered, note its **significant limitations**:

> *"Mistral 7B is not a multilingual model. It's only pretrained on the English language."*
> — [Gathnex Analysis](https://gathnex.medium.com/mistral-7b-is-not-a-multilingual-model-5df3a38b3cc3)

Later versions (v0.2) add limited support for Hinglish, Spanish, Ukrainian, Vietnamese—but nothing compared to Qwen's comprehensive multilingual training.

### Model Recommendations by Use Case

| Priority | Model | Best For | Parameters |
|----------|-------|----------|------------|
| **Recommended** | Qwen 2.5 7B | All-around multilingual, Asian languages | 7.6B |
| **European Focus** | Mistral Large 2 | FR/DE/ES, enterprise EU | 123B |
| **Latest Option** | Qwen 3 | 119 languages, hybrid reasoning | Various |
| **Alternative** | Llama 3.1 8B | General multilingual, safety-focused | 8B |

### Curriculum Translation Capability

Qwen 2.5 can handle:
- ✅ Translating English curriculum to target language during tutoring
- ✅ Understanding student responses in non-English
- ✅ Maintaining semantic accuracy in technical/scientific content
- ⚠️ Philosophical/abstract content requires careful prompting
- ⚠️ Cultural idioms may need explicit context in system prompts

---

## 3. Text-to-Speech Multilingual Analysis

### Current Integration: ElevenLabs

The codebase uses `eleven_turbo_v2_5` via WebSocket streaming. This model **already supports 32 languages**.

**ElevenLabs Model Options:**

| Model | Languages | Latency | Best For |
|-------|-----------|---------|----------|
| **Turbo v2.5** (current) | 32 | 75ms | Real-time conversation |
| **Multilingual v2** | 29 | Higher | Non-English audiobooks, narration |
| **Eleven v3** (preview) | 70+ | Highest | Long-form, expressive dialogue |

**Turbo v2.5 Supported Languages:**
English, Spanish, French, German, Italian, Portuguese, Russian, Japanese, Korean, Chinese (Mandarin), Arabic, Hindi, Dutch, Polish, Czech, Slovak, Ukrainian, Croatian, Romanian, Bulgarian, Greek, Finnish, Danish, Swedish, Norwegian, Hungarian, Turkish, Hebrew, Malay, Tamil, Vietnamese

**Key Implementation Note:**
> *"If your content will be in another language or potentially multilingual, you must use one of the multilingual models."*
> — [ElevenLabs Documentation](https://elevenlabs.io/docs/creative-platform/playground/text-to-speech)

**Pronunciation Quality Best Practices:**
1. Write out numbers as words (not "7" but "seven")—symbols are language-ambiguous
2. Use ISO 639-1 codes to enforce specific pronunciation when auto-detection fails
3. ElevenLabs maintains speaker voice characteristics across languages (accent preservation)

### Open-Source TTS Alternatives

For self-hosted deployments or cost reduction:

| Model | Languages | WER | Notable Features |
|-------|-----------|-----|------------------|
| **Fish Speech V1.5** | Many | 3.5% EN | 300k+ hours training, ELO 1339 |
| **CosyVoice 2** | CN/EN/JP/KR | - | 30-50% pronunciation error reduction, 150ms streaming |
| **MeloTTS** | Multiple + accents | - | CPU-optimized, real-time inference |
| **XTTS-v2** | 17 | - | 6-second voice cloning, cross-lingual |
| **Chatterbox** | Multiple | - | MIT licensed, accent control |

**Recommendation**: Stick with ElevenLabs for quality, but evaluate **Fish Speech V1.5** or **CosyVoice 2** for self-hosted multilingual.

---

## 4. Speech-to-Text Multilingual Analysis

### Current Integration: Whisper (via Groq, Self-Hosted)

The codebase integrates Whisper through multiple services:
- `GroqSTTService` - Whisper via Groq API
- `SelfHostedSTTService` - Self-hosted Whisper server

**Whisper Large V3 Capabilities:**

| Metric | Value |
|--------|-------|
| **Languages** | 100 (including Cantonese) |
| **Parameters** | 1.55B |
| **WER (clean)** | 2.7% |
| **WER (mixed real-world)** | 7.88% |
| **Training Data** | 5M hours (1M labeled + 4M pseudo-labeled) |

**Language Performance Tiers:**

| Tier | Languages | Notes |
|------|-----------|-------|
| **Excellent** | English, Spanish, French, German | 67% training data is English |
| **Good** | Italian, Portuguese, Dutch, Polish, Russian | High-resource languages |
| **Moderate** | Japanese, Korean, Chinese, Arabic | Tonal/script complexity |
| **Variable** | Low-resource languages | Less training data |

**Known Limitations:**
- Hallucination issues (can generate text even without audio)
- Inconsistent formatting
- Low-resource languages have higher error rates

**Whisper Turbo Option:**
- 6x faster inference (809M params vs 1.55B)
- 1-2% accuracy reduction—acceptable for conversational use

### Apple On-Device STT

Currently hardcoded to `en-US`, but Apple's Speech framework supports:
- 60+ locales
- On-device processing (privacy, offline)
- Real-time transcription

**Implementation Change Required:**
```swift
// Current (hardcoded)
SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

// Needed (dynamic)
SFSpeechRecognizer(locale: Locale(identifier: userSelectedLanguage))
```

---

## 5. Curriculum Translation Challenges

### Educational Content Translation: Critical Considerations

Learning content demands **the highest semantic accuracy**. LLM translation has specific challenges in educational contexts:

#### Challenge 1: Abstract & Philosophical Content

> *"All models translate structured, fact-based content well but struggle with abstract and philosophical content. Sentences discussing deep concepts, such as the imperishability of the soul, show lower similarity scores."*
> — [arXiv Sentiment Analysis Study](https://arxiv.org/html/2503.21393v1)

**Mitigation**: Pre-validate critical philosophical/abstract sections with human review. Use explicit context in LLM prompts.

#### Challenge 2: Domain-Specific Terminology

Technical terms (physics, mathematics, medicine) require:
- Consistent terminology across the curriculum
- Terminology glossaries per language
- UMCF already supports this via `pronunciation_guide`

**Mitigation**: Extend UMCF to include a `terminology` section with official translations per language.

#### Challenge 3: Cultural Adaptation

> *"LLMs may accurately translate the words of an idiomatic expression but miss the cultural context, leading to misunderstandings."*
> — [Pairaphrase Analysis](https://www.pairaphrase.com/blog/llm-translation-advantages-disadvantages)

**Mitigation**: Include cultural notes in curriculum metadata. Use localized examples (not just translated).

#### Challenge 4: Semantic Consistency Across Sessions

Long learning sessions (60-90 minutes) must maintain:
- Consistent terminology usage
- Context from earlier explanations
- Building on previously established concepts

**Mitigation**: Include a "session terminology log" in the learning context.

### Translation Architecture Options

| Approach | Pros | Cons |
|----------|------|------|
| **Pre-translated Curriculum** | Perfect quality control, human-reviewed | High cost, slow updates |
| **Real-time LLM Translation** | Dynamic, cost-effective, instant | Quality variation, no human QA |
| **Hybrid** | Core curriculum pre-translated, discussion real-time | Best balance |

**Recommendation**: **Hybrid approach**
- Core lesson content: Pre-translated or LLM-translated + human review
- Interactive discussion: Real-time LLM translation
- Critical terminology: Defined in UMCF per language

---

## 6. Language Support Matrix

### Priority Languages for UnaMentis

Based on global education markets and model capabilities:

| Tier | Languages | LLM | TTS | STT | Notes |
|------|-----------|-----|-----|-----|-------|
| **T1** | English | ✅ Excellent | ✅ Excellent | ✅ Excellent | Primary, current |
| **T1** | Spanish | ✅ Excellent | ✅ Excellent | ✅ Excellent | 2nd most spoken |
| **T1** | Mandarin | ✅ Excellent | ✅ Excellent | ✅ Good | Qwen excels |
| **T2** | French | ✅ Good | ✅ Excellent | ✅ Good | EU market |
| **T2** | German | ✅ Good | ✅ Excellent | ✅ Good | EU market |
| **T2** | Portuguese | ✅ Good | ✅ Good | ✅ Good | Brazil market |
| **T2** | Japanese | ✅ Excellent | ✅ Good | ✅ Moderate | Qwen strength |
| **T2** | Korean | ✅ Excellent | ✅ Good | ✅ Moderate | Qwen strength |
| **T3** | Arabic | ✅ Good | ✅ Good | ✅ Moderate | RTL support needed |
| **T3** | Hindi | ✅ Good | ✅ Good | ✅ Moderate | Large market |

### Feature Support Requirements by Language

| Feature | Requirement |
|---------|-------------|
| **LLM Comprehension** | Understand student queries in target language |
| **LLM Translation** | Translate curriculum concepts accurately |
| **LLM Reasoning** | Perform tutoring logic in target language |
| **TTS Pronunciation** | Native-quality word pronunciation |
| **TTS Prosody** | Natural sentence rhythm and intonation |
| **TTS Emotion** | Convey encouragement, emphasis appropriately |
| **STT Accuracy** | Transcribe student speech with <10% WER |
| **STT Vocabulary** | Handle educational/technical terms |

---

## 7. Critical Implementation Gaps

### Priority 1: Core Session Flow

| Gap | Impact | Effort |
|-----|--------|--------|
| **Language selection UI** | Users can't choose language | Low |
| **Service initialization** | STT/TTS hardcoded to English | Medium |
| **Curriculum-session matching** | Language mismatch undetected | Low |

### Priority 2: Voice Pipeline

| Gap | Impact | Effort |
|-----|--------|--------|
| **TTS model selection** | Non-English needs `eleven_multilingual_v2` | Low |
| **Voice matching** | No voice selection per language | Medium |
| **Pronunciation override** | Can't force language on ambiguous text | Low |

### Priority 3: Curriculum System

| Gap | Impact | Effort |
|-----|--------|--------|
| **Multi-language curriculum storage** | Each curriculum only one language | High |
| **Terminology glossary** | No official term translations | Medium |
| **Real-time translation API** | No endpoint for curriculum translation | Medium |

### Priority 4: UI/UX

| Gap | Impact | Effort |
|-----|--------|--------|
| **iOS localization files** | Only `en.lproj` exists | Medium |
| **RTL layout testing** | Arabic/Hebrew support unverified | Medium |
| **Web UI i18n** | No Next.js i18n integration | Medium |

---

## 8. Recommended Implementation Path

### Phase 1: Foundation (Enable Multilingual Sessions)

**Goal**: Allow users to learn in a non-English language using English curriculum

1. **Add Language Preference to iOS Settings**
   - New setting: "Learning Language" (dropdown)
   - Store in UserDefaults
   - Surface to session initialization

2. **Initialize Services with Selected Language**
   ```swift
   // STT
   let recognizer = SFSpeechRecognizer(locale: Locale(identifier: learningLanguage))

   // TTS - switch model for non-English
   let modelId = learningLanguage == "en" ? "eleven_turbo_v2_5" : "eleven_multilingual_v2"
   ```

3. **Add System Prompt for Translation**
   ```
   You are tutoring in {language}. The curriculum is in English.
   Translate all content naturally as you teach. Maintain the
   student's terminology preferences established in this session.
   ```

4. **Validate Curriculum Language Match**
   - Warn if curriculum language differs from session language
   - Offer to proceed with translation

**Deliverable**: Users can select Spanish, and the tutor speaks in Spanish, translating the English curriculum in real-time.

### Phase 2: Voice Quality Enhancement

**Goal**: Native-quality pronunciation and voice matching

1. **Per-Language Voice Selection**
   - Map ElevenLabs voices to languages
   - Auto-select voice based on curriculum/session language
   - Allow user voice preference per language

2. **Pronunciation Guide Integration**
   - Extend UMCF to support per-language pronunciation
   - Use SSML `<lang>` tags for foreign terms

3. **Open-Source TTS Evaluation**
   - Test Fish Speech V1.5 for self-hosted multilingual
   - Evaluate CosyVoice 2 for Asian languages

### Phase 3: Curriculum Translation

**Goal**: High-quality translated curriculum content

1. **UMCF Multi-Language Support**
   ```json
   {
     "content": {
       "en": "Newton's first law states...",
       "es": "La primera ley de Newton establece...",
       "zh": "牛顿第一定律指出..."
     }
   }
   ```

2. **Terminology Glossary Schema**
   ```json
   {
     "terminology": {
       "inertia": {
         "en": "inertia",
         "es": "inercia",
         "zh": "惯性",
         "pronunciation": { "es": "ee-NER-see-ah" }
       }
     }
   }
   ```

3. **Curriculum Translation Pipeline**
   - Batch LLM translation of curriculum
   - Human review for T1 languages
   - Store translations in UMCF

### Phase 4: Full Localization

**Goal**: Complete app experience in multiple languages

1. **iOS UI Localization**
   - Add `es.lproj`, `zh-Hans.lproj`, etc.
   - Translate all 114 strings per language
   - RTL testing for Arabic

2. **Web UI i18n**
   - Integrate next-i18next
   - Translate web interface

3. **Server Language Negotiation**
   - Accept-Language header parsing
   - Language-filtered curriculum queries

---

## 9. Research Sources

### LLM Multilingual Capabilities
- [Qwen 2.5 Technical Report](https://arxiv.org/pdf/2412.15115) - Official Alibaba research paper
- [Qwen 2.5 7B Hugging Face](https://huggingface.co/Qwen/Qwen2.5-7B-Instruct) - Model card with multilingual benchmarks
- [Mistral 7B Is Not Multilingual](https://gathnex.medium.com/mistral-7b-is-not-a-multilingual-model-5df3a38b3cc3) - Analysis of Mistral limitations
- [Top Open-Source LLMs 2025](https://huggingface.co/blog/daya-shankar/open-source-llms) - Comparative analysis

### Text-to-Speech
- [ElevenLabs Language Support](https://help.elevenlabs.io/hc/en-us/articles/13313366263441-What-languages-do-you-support) - Official language list
- [ElevenLabs Multilingual v2](https://elevenlabs.io/blog/multilingualv2) - Model capabilities
- [Best Open-Source TTS 2025](https://www.resemble.ai/best-open-source-text-to-speech-models/) - Comprehensive comparison
- [Fish Speech V1.5](https://www.siliconflow.com/articles/en/best-open-source-text-to-speech-models) - Open-source evaluation

### Speech-to-Text
- [Whisper Large V3 Model Card](https://huggingface.co/openai/whisper-large-v3) - Official specifications
- [OpenAI Whisper GitHub](https://github.com/openai/whisper) - Technical details
- [Best STT Models 2025](https://northflank.com/blog/best-open-source-speech-to-text-stt-model-in-2025-benchmarks) - Benchmarks

### Translation Challenges
- [LLM Translation Advantages & Disadvantages](https://www.pairaphrase.com/blog/llm-translation-advantages-disadvantages) - Practical analysis
- [Science Across Languages](https://arxiv.org/html/2502.17882v1) - Scientific translation challenges
- [LLMs as Tutors in Foreign Language Education](https://arxiv.org/html/2502.05467v1) - Educational context

---

## Appendix A: Quick Reference

### Model Configuration for Multilingual

```swift
// SelfHostedLLMService - already supports Qwen 2.5
let llm = SelfHostedLLMService(baseURL: serverURL, modelName: "qwen2.5:7b")

// ElevenLabsTTSService - switch model for non-English
let modelId = language == "en" ? "eleven_turbo_v2_5" : "eleven_multilingual_v2"

// GroqSTTService - pass language code
let stt = GroqSTTService(apiKey: key, language: "es") // Spanish
```

### BCP 47 Language Codes

| Language | Code | UMCF Example |
|----------|------|--------------|
| English (US) | en-US | `"language": "en-US"` |
| Spanish (Spain) | es-ES | `"language": "es-ES"` |
| Spanish (Mexico) | es-MX | `"language": "es-MX"` |
| Chinese (Simplified) | zh-Hans | `"language": "zh-Hans"` |
| Japanese | ja | `"language": "ja"` |
| French | fr-FR | `"language": "fr-FR"` |
| German | de-DE | `"language": "de-DE"` |
| Arabic | ar | `"language": "ar"` |

---

*Document generated: 2026-01-02*
*UnaMentis Multilingual Voice Learning Exploration*
