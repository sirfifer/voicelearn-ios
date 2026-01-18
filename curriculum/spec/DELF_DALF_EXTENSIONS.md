# DELF/DALF French UMCF Extensions

This document specifies the UMCF schema extensions required to support DELF (Diplôme d'Études en Langue Française) and DALF (Diplôme Approfondi de Langue Française) exam preparation content. These extensions build upon the base UMCF v1.1.0 specification.

## Overview

DELF and DALF are official French language proficiency diplomas issued by the French Ministry of Education. They are:
- **Valid for life** (unlike IELTS/TOEFL which expire)
- **Recognized worldwide** by 1,200+ exam centers
- **Aligned to CEFR** (Common European Framework of Reference)

### Levels
| Diploma | Levels | CEFR | Description |
|---------|--------|------|-------------|
| **DELF** | A1, A2 | Basic | Beginner to Elementary |
| **DELF** | B1, B2 | Independent | Intermediate to Upper-Intermediate |
| **DALF** | C1, C2 | Proficient | Advanced to Mastery |

### Practical Value
- **DELF B1**: Required for French nationality
- **DELF B2**: University admission in France/EU
- **DALF C1**: Increasingly required by top universities

## Extension Namespace

All DELF/DALF extensions use the `delfDalf` namespace within UMCF content nodes.

```json
{
  "extensions": {
    "delfDalf": {
      // DELF/DALF specific fields
    }
  }
}
```

## Schema Extensions

### 1. Content Node Extensions

#### delfDalf Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `level` | enum | Yes | CEFR level (A1, A2, B1, B2, C1, C2) |
| `diploma` | enum | Yes | delf or dalf |
| `skill` | enum | Yes | Skill being tested |
| `version` | string | No | Exam version (tout_public, junior, prim, pro) |
| `part` | number | No | Part number within skill section |
| `duration` | number | No | Time allocation in minutes |
| `maxPoints` | number | No | Maximum points for this content |
| `voiceFriendly` | boolean | No | Optimized for voice learning |
| `topic` | string | No | Thematic topic category |
| `grammarFocus` | array | No | Grammar points covered |
| `vocabularyTheme` | string | No | Vocabulary theme |

#### level Enum

```json
{
  "enum": ["A1", "A2", "B1", "B2", "C1", "C2"]
}
```

#### skill Enum

```json
{
  "enum": ["comprehension_orale", "comprehension_ecrite", "production_ecrite", "production_orale"]
}
```

| Skill | French Name | English | Points | Voice-Friendly |
|-------|-------------|---------|--------|----------------|
| `comprehension_orale` | Compréhension orale | Listening | 25 | ★★★★★ |
| `comprehension_ecrite` | Compréhension écrite | Reading | 25 | ★★★★☆ |
| `production_ecrite` | Production écrite | Writing | 25 | ★★★☆☆ |
| `production_orale` | Production orale | Speaking | 25 | ★★★★★ |

### 2. Exam Structure by Level

#### DELF A1 (1h20 total)

```json
{
  "examStructure": {
    "level": "A1",
    "totalDuration": 80,
    "passingScore": 50,
    "minimumPerSkill": 5,
    "sections": {
      "comprehension_orale": {
        "duration": 20,
        "parts": 4,
        "recordings": "3 minutes max",
        "playCount": 2
      },
      "comprehension_ecrite": {
        "duration": 30,
        "parts": 4
      },
      "production_ecrite": {
        "duration": 30,
        "parts": 2,
        "wordCount": "40-50 words"
      },
      "production_orale": {
        "duration": 10,
        "prepTime": 10,
        "parts": 3
      }
    }
  }
}
```

#### DELF B2 (2h30 total + speaking)

```json
{
  "examStructure": {
    "level": "B2",
    "totalDuration": 150,
    "passingScore": 50,
    "minimumPerSkill": 5,
    "sections": {
      "comprehension_orale": {
        "duration": 30,
        "parts": 2,
        "recordings": "8 minutes max",
        "playCount": "varies"
      },
      "comprehension_ecrite": {
        "duration": 60,
        "parts": 2,
        "textLength": "long texts"
      },
      "production_ecrite": {
        "duration": 60,
        "parts": 1,
        "wordCount": "250+ words",
        "taskType": "argumentative essay"
      },
      "production_orale": {
        "duration": 20,
        "prepTime": 30,
        "parts": 2,
        "taskType": "debate/argumentation"
      }
    }
  }
}
```

### 3. Content Classification

#### Topic Taxonomy by Level

```json
{
  "topics": {
    "A1_A2": [
      "personal_identity",
      "family_friends",
      "daily_routine",
      "housing",
      "food_drink",
      "shopping",
      "travel_transport",
      "leisure_hobbies",
      "weather",
      "directions"
    ],
    "B1_B2": [
      "education",
      "work_career",
      "health_wellbeing",
      "environment",
      "media_communication",
      "culture_society",
      "science_technology",
      "current_events",
      "travel_tourism",
      "personal_opinions"
    ],
    "C1_C2": [
      "politics",
      "economics",
      "philosophy",
      "arts_literature",
      "ethics",
      "globalization",
      "scientific_research",
      "social_issues",
      "historical_analysis",
      "abstract_concepts"
    ]
  }
}
```

#### Grammar Focus by Level

```json
{
  "grammarProgression": {
    "A1": [
      "present_tense",
      "articles",
      "basic_adjectives",
      "negation",
      "basic_questions",
      "prepositions_place"
    ],
    "A2": [
      "passe_compose",
      "imparfait",
      "futur_proche",
      "pronouns_direct_indirect",
      "comparatives",
      "relative_pronouns_qui_que"
    ],
    "B1": [
      "subjonctif_present",
      "conditionnel_present",
      "plus_que_parfait",
      "passive_voice",
      "reported_speech",
      "complex_relatives"
    ],
    "B2": [
      "subjonctif_past",
      "conditionnel_passe",
      "literary_tenses",
      "nuanced_connectors",
      "nominalization",
      "complex_hypotheticals"
    ],
    "C1_C2": [
      "all_subjunctive_forms",
      "literary_style",
      "advanced_concession",
      "sophisticated_argumentation",
      "register_variation",
      "stylistic_nuance"
    ]
  }
}
```

### 4. Assessment Extensions

#### Listening Comprehension (Compréhension Orale)

Perfect for voice-based learning:

```json
{
  "type": "listening",
  "delfDalf": {
    "level": "B1",
    "skill": "comprehension_orale",
    "part": 1,
    "voiceFriendly": true,
    "audioType": "dialogue",
    "duration": 90,
    "playCount": 2,
    "topic": "daily_routine",
    "questions": [
      {
        "type": "multiple_choice",
        "prompt": "Où se passe cette conversation?",
        "spokenPrompt": "Où se passe cette conversation?",
        "options": ["À la gare", "À l'aéroport", "Au bureau", "À la maison"],
        "correct": "À la gare",
        "points": 1
      }
    ]
  }
}
```

#### Speaking Practice (Production Orale)

Voice-native content:

```json
{
  "type": "speaking",
  "delfDalf": {
    "level": "B2",
    "skill": "production_orale",
    "part": 2,
    "voiceFriendly": true,
    "taskType": "argumentation",
    "prepTime": 30,
    "speakingTime": 10,
    "topic": "environment",
    "prompt": "Doit-on interdire les voitures dans les centres-villes?",
    "spokenPrompt": "Doit-on interdire les voitures dans les centres-villes? Présentez votre opinion et défendez votre point de vue.",
    "evaluationCriteria": [
      "argumentation_structure",
      "vocabulary_precision",
      "grammatical_accuracy",
      "fluency",
      "pronunciation"
    ],
    "sampleArguments": {
      "pour": ["réduction pollution", "qualité de vie", "santé publique"],
      "contre": ["accessibilité commerces", "liberté individuelle", "économie locale"]
    }
  }
}
```

#### Reading Comprehension (Compréhension Écrite)

Adapted for voice (text read aloud):

```json
{
  "type": "reading",
  "delfDalf": {
    "level": "B1",
    "skill": "comprehension_ecrite",
    "voiceFriendly": true,
    "textType": "article",
    "topic": "travel_tourism",
    "text": "Les Français voyagent de plus en plus...",
    "spokenText": "Les Français voyagent de plus en plus...",
    "wordCount": 350,
    "questions": [
      {
        "type": "true_false_justify",
        "statement": "Les Français préfèrent les voyages organisés.",
        "correct": false,
        "justification": "Selon le texte, ils préfèrent organiser eux-mêmes leurs voyages.",
        "points": 2
      }
    ]
  }
}
```

#### Dictée (Dictation Practice)

Classic French learning exercise, perfect for voice:

```json
{
  "type": "dictation",
  "delfDalf": {
    "level": "B1",
    "voiceFriendly": true,
    "text": "La France est un pays riche en histoire et en culture.",
    "speed": "normal",
    "repetitions": 3,
    "grammarFocus": ["accents", "agreement", "silent_letters"],
    "hints": [
      "Attention aux accords",
      "Les lettres muettes en fin de mot"
    ]
  }
}
```

### 5. Voice-Learning Optimizations

#### Skill-Specific Voice Adaptations

```json
{
  "voiceOptimizations": {
    "comprehension_orale": {
      "nativeVoiceFit": true,
      "adaptations": [
        "Direct audio playback",
        "Speed adjustment available",
        "Pause/replay functionality"
      ]
    },
    "production_orale": {
      "nativeVoiceFit": true,
      "adaptations": [
        "Speaking prompts read aloud",
        "Timer announcements",
        "Model responses available",
        "Pronunciation feedback"
      ]
    },
    "comprehension_ecrite": {
      "nativeVoiceFit": "adapted",
      "adaptations": [
        "Text read aloud by TTS",
        "Questions read aloud",
        "Verbal answer options"
      ]
    },
    "production_ecrite": {
      "nativeVoiceFit": "limited",
      "adaptations": [
        "Grammar rule explanations",
        "Vocabulary drilling",
        "Sentence structure practice",
        "Dictation as writing proxy"
      ]
    }
  }
}
```

### 6. Performance Tracking

#### Skill-Level Tracking

```json
{
  "performanceTracking": {
    "level": "B1",
    "skillBreakdown": {
      "comprehension_orale": {
        "score": 18,
        "maxScore": 25,
        "percentage": 72,
        "strengths": ["dialogue_comprehension", "numbers"],
        "weaknesses": ["fast_speech", "regional_accents"]
      },
      "production_orale": {
        "score": 20,
        "maxScore": 25,
        "percentage": 80,
        "strengths": ["fluency", "vocabulary"],
        "weaknesses": ["subjunctive_usage", "liaisons"]
      }
    },
    "overallScore": 68,
    "passingStatus": "pass",
    "recommendations": [
      "Focus on listening to varied French accents",
      "Practice subjunctive triggers"
    ]
  }
}
```

### 7. Study Session Configuration

#### Session Templates

```json
{
  "sessionTemplates": {
    "diagnostic": {
      "type": "diagnostic",
      "duration": 3600,
      "allSkills": true,
      "levelAssessment": true,
      "voicePrimary": true
    },
    "listening_intensive": {
      "type": "skill_focus",
      "skill": "comprehension_orale",
      "duration": 1800,
      "variety": ["dialogues", "monologues", "announcements", "interviews"],
      "speedProgression": true
    },
    "speaking_practice": {
      "type": "skill_focus",
      "skill": "production_orale",
      "duration": 1200,
      "components": ["guided_conversation", "monologue", "debate"],
      "recordingEnabled": true
    },
    "exam_simulation": {
      "type": "simulation",
      "level": "B2",
      "fullExam": true,
      "timed": true,
      "feedbackImmediate": false
    },
    "grammar_through_listening": {
      "type": "integrated",
      "duration": 1200,
      "focus": "grammar",
      "method": "listening_examples",
      "targetStructures": ["configurable"]
    },
    "vocabulary_builder": {
      "type": "vocabulary",
      "duration": 900,
      "theme": "configurable",
      "method": "contextual_audio",
      "spaceRepetition": true
    }
  }
}
```

## JSON Schema Fragment

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "definitions": {
    "delfDalfExtension": {
      "type": "object",
      "properties": {
        "level": {
          "type": "string",
          "enum": ["A1", "A2", "B1", "B2", "C1", "C2"],
          "description": "CEFR level"
        },
        "diploma": {
          "type": "string",
          "enum": ["delf", "dalf"],
          "description": "Diploma type"
        },
        "skill": {
          "type": "string",
          "enum": ["comprehension_orale", "comprehension_ecrite", "production_ecrite", "production_orale"],
          "description": "Skill being assessed"
        },
        "version": {
          "type": "string",
          "enum": ["tout_public", "junior", "prim", "pro"],
          "description": "Exam version"
        },
        "part": {
          "type": "integer",
          "minimum": 1,
          "description": "Part number within section"
        },
        "duration": {
          "type": "integer",
          "description": "Time in minutes"
        },
        "maxPoints": {
          "type": "integer",
          "default": 25,
          "description": "Maximum points"
        },
        "voiceFriendly": {
          "type": "boolean",
          "default": true,
          "description": "Optimized for voice learning"
        },
        "topic": {
          "type": "string",
          "description": "Thematic topic"
        },
        "grammarFocus": {
          "type": "array",
          "items": {"type": "string"},
          "description": "Grammar points covered"
        },
        "vocabularyTheme": {
          "type": "string",
          "description": "Vocabulary theme"
        }
      },
      "required": ["level", "diploma", "skill"]
    }
  }
}
```

## Validation Rules

### Required Fields

1. All DELF/DALF content MUST include `level` and `diploma`
2. All assessment content MUST include `skill`
3. Listening content MUST specify `playCount` and `duration`
4. Speaking content MUST specify `prepTime` and `speakingTime`

### Scoring Rules

1. Each skill section is worth 25 points (100 total)
2. Pass mark: 50/100 overall AND minimum 5/25 per skill
3. Failing any single skill = exam failure regardless of overall score

### Voice-Friendly Guidelines

1. All prompts MUST include `spokenPrompt` variant optimized for TTS
2. Listening content should specify French TTS language code (`fr`)
3. Production orale content is native voice content
4. Production écrite should include alternative voice-based practice

## Content Language

**IMPORTANT**: Content for DELF/DALF is in French. The UMCF file should specify:

```json
{
  "metadata": {
    "language": "fr",
    "ttsLanguage": "fr"
  }
}
```

## Versioning

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | January 2026 | Initial DELF/DALF extensions |

---

*This specification extends UMCF v1.1.0 and should be read in conjunction with the base UMCF Specification.*

## Sources

- [DELF tout public](https://www.france-education-international.fr/en/diplome/delf-tout-public)
- [DELF & DALF Exam Guide](https://lingorelic.com/delf-dalf-exam-guide-2025-levels-format-fees-registration-preparation/)
- [DELF Scoring System](https://global-exam.com/blog/en/how-does-the-delf-scoring-system-work/)
