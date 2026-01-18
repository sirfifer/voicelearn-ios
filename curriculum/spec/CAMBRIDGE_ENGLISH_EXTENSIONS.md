# Cambridge English UMCF Extensions

This document specifies the UMCF schema extensions required to support Cambridge English exam preparation content (B2 First, C1 Advanced, C2 Proficiency). These extensions build upon the base UMCF v1.1.0 specification.

## Overview

Cambridge English Qualifications are internationally recognized English language certifications developed by Cambridge University Press & Assessment. They are:
- **Valid for life** (unlike IELTS which expires after 2 years)
- **Accepted by 6,000+ institutions** worldwide
- **Aligned to CEFR** (Common European Framework of Reference)

### Qualifications Covered
| Exam | CEFR | Pass Score | High Pass |
|------|------|------------|-----------|
| **B2 First (FCE)** | B2 | 160+ | 180+ (C1 certificate) |
| **C1 Advanced (CAE)** | C1 | 180+ | 200+ (C2 certificate) |
| **C2 Proficiency (CPE)** | C2 | 200+ | 220+ |

## Extension Namespace

All Cambridge English extensions use the `cambridgeEnglish` namespace within UMCF content nodes.

```json
{
  "extensions": {
    "cambridgeEnglish": {
      // Cambridge English specific fields
    }
  }
}
```

## Schema Extensions

### 1. Content Node Extensions

#### cambridgeEnglish Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `exam` | enum | Yes | Exam type (b2_first, c1_advanced, c2_proficiency) |
| `paper` | enum | Yes | Paper/section being tested |
| `part` | number | No | Part number within paper |
| `taskType` | string | No | Specific task type |
| `duration` | number | No | Time allocation in minutes |
| `questionCount` | number | No | Number of questions |
| `voiceFriendly` | boolean | No | Optimized for voice learning |
| `topic` | string | No | Thematic topic category |
| `grammarFocus` | array | No | Grammar points covered |
| `vocabularyLevel` | string | No | Vocabulary difficulty |

#### exam Enum

```json
{
  "enum": ["b2_first", "c1_advanced", "c2_proficiency"]
}
```

#### paper Enum

```json
{
  "enum": ["reading_use_of_english", "writing", "listening", "speaking"]
}
```

| Paper | Weight | Duration (C1) | Voice-Friendly |
|-------|--------|---------------|----------------|
| `reading_use_of_english` | 40% | 90 min | ★★★★☆ |
| `writing` | 20% | 90 min | ★★☆☆☆ |
| `listening` | 20% | 40 min | ★★★★★ |
| `speaking` | 20% | 15 min | ★★★★★ |

### 2. Exam Structure

#### C1 Advanced Structure

```json
{
  "examStructure": {
    "exam": "c1_advanced",
    "totalDuration": 235,
    "papers": {
      "reading_use_of_english": {
        "duration": 90,
        "parts": 8,
        "questions": 56,
        "weight": 40,
        "taskTypes": [
          "multiple_choice_cloze",
          "open_cloze",
          "word_formation",
          "key_word_transformation",
          "multiple_choice_reading",
          "cross_text_multiple_matching",
          "gapped_text",
          "multiple_matching"
        ]
      },
      "writing": {
        "duration": 90,
        "parts": 2,
        "wordCount": 250,
        "weight": 20,
        "taskTypes": [
          "compulsory_essay",
          "choice_task"
        ]
      },
      "listening": {
        "duration": 40,
        "parts": 4,
        "questions": 30,
        "weight": 20,
        "taskTypes": [
          "multiple_choice",
          "sentence_completion",
          "multiple_matching",
          "multiple_choice_extended"
        ]
      },
      "speaking": {
        "duration": 15,
        "parts": 4,
        "weight": 20,
        "taskTypes": [
          "interview",
          "long_turn",
          "collaborative_task",
          "discussion"
        ]
      }
    }
  }
}
```

### 3. Use of English Task Types

These are highly voice-friendly for drilling:

#### Multiple Choice Cloze (Part 1)

```json
{
  "type": "multiple_choice_cloze",
  "cambridgeEnglish": {
    "exam": "c1_advanced",
    "paper": "reading_use_of_english",
    "part": 1,
    "voiceFriendly": true,
    "text": "The restaurant was so popular that we had to book a table well in ___(1)___.",
    "spokenText": "The restaurant was so popular that we had to book a table well in blank one.",
    "gaps": [
      {
        "number": 1,
        "options": ["advance", "ahead", "front", "forward"],
        "correct": "advance",
        "explanation": "'In advance' is a fixed expression meaning 'beforehand'"
      }
    ]
  }
}
```

#### Open Cloze (Part 2)

```json
{
  "type": "open_cloze",
  "cambridgeEnglish": {
    "exam": "c1_advanced",
    "paper": "reading_use_of_english",
    "part": 2,
    "voiceFriendly": true,
    "text": "She managed to finish the project ___(1)___ time.",
    "spokenText": "She managed to finish the project blank one time.",
    "gaps": [
      {
        "number": 1,
        "correct": "on",
        "alternates": [],
        "grammarPoint": "preposition_collocation",
        "explanation": "'On time' means at the scheduled time"
      }
    ]
  }
}
```

#### Word Formation (Part 3)

Excellent for vocabulary building via voice:

```json
{
  "type": "word_formation",
  "cambridgeEnglish": {
    "exam": "c1_advanced",
    "paper": "reading_use_of_english",
    "part": 3,
    "voiceFriendly": true,
    "text": "The ___(1)___ of the new policy has been very successful.",
    "spokenText": "The blank one of the new policy has been very successful. The base word is IMPLEMENT.",
    "gaps": [
      {
        "number": 1,
        "baseWord": "IMPLEMENT",
        "correct": "implementation",
        "wordFamily": ["implement", "implementation", "implementable"],
        "affixes": ["prefix: none", "suffix: -ation (noun)"]
      }
    ]
  }
}
```

#### Key Word Transformation (Part 4)

Perfect for grammar drilling:

```json
{
  "type": "key_word_transformation",
  "cambridgeEnglish": {
    "exam": "c1_advanced",
    "paper": "reading_use_of_english",
    "part": 4,
    "voiceFriendly": true,
    "original": "I regret not studying harder for the exam.",
    "spokenOriginal": "The original sentence is: I regret not studying harder for the exam.",
    "keyWord": "WISH",
    "target": "I ___ harder for the exam.",
    "spokenTarget": "Using the word WISH, complete the sentence: I blank harder for the exam.",
    "correct": "wish I had studied",
    "grammarPoint": "wish_past_perfect",
    "explanation": "'Wish + past perfect' expresses regret about the past"
  }
}
```

### 4. Listening Tasks

Native voice content:

#### Multiple Choice (Part 1)

```json
{
  "type": "listening_multiple_choice",
  "cambridgeEnglish": {
    "exam": "c1_advanced",
    "paper": "listening",
    "part": 1,
    "voiceFriendly": true,
    "audioType": "short_extracts",
    "extractCount": 6,
    "questionsPerExtract": 2,
    "playCount": 2,
    "extract": {
      "number": 1,
      "context": "You hear two friends discussing a film.",
      "spokenContext": "You will hear two friends discussing a film.",
      "duration": 30,
      "questions": [
        {
          "prompt": "What did the woman think of the film?",
          "options": [
            "It was too long.",
            "The acting was disappointing.",
            "The plot was confusing."
          ],
          "correct": "The plot was confusing."
        }
      ]
    }
  }
}
```

#### Sentence Completion (Part 2)

```json
{
  "type": "listening_sentence_completion",
  "cambridgeEnglish": {
    "exam": "c1_advanced",
    "paper": "listening",
    "part": 2,
    "voiceFriendly": true,
    "audioType": "monologue",
    "duration": 180,
    "playCount": 2,
    "topic": "science_and_nature",
    "gappedSentences": [
      {
        "number": 1,
        "sentence": "The researcher found that the birds could remember up to ___ different locations.",
        "spokenSentence": "The researcher found that the birds could remember up to blank one different locations.",
        "answer": "200",
        "acceptableVariants": ["two hundred"]
      }
    ]
  }
}
```

### 5. Speaking Tasks

Voice-native content:

#### Long Turn (Part 2)

```json
{
  "type": "speaking_long_turn",
  "cambridgeEnglish": {
    "exam": "c1_advanced",
    "paper": "speaking",
    "part": 2,
    "voiceFriendly": true,
    "duration": 60,
    "instructions": "Here are your pictures. They show people in different working environments. I'd like you to compare two of the pictures and say why the people might have chosen these working environments and how they might be feeling about their work.",
    "spokenInstructions": "Look at these pictures showing people in different working environments. Compare two of them. Why might the people have chosen these environments? How might they be feeling about their work? You have one minute.",
    "followUpQuestion": "Which working environment would you prefer?",
    "evaluationCriteria": [
      "discourse_management",
      "grammar_vocabulary",
      "pronunciation",
      "interactive_communication"
    ],
    "modelResponse": {
      "structure": ["comparison", "speculation", "personal opinion"],
      "usefulPhrases": [
        "Both pictures show...",
        "In contrast to...",
        "I imagine they might be feeling...",
        "One possible reason could be..."
      ]
    }
  }
}
```

#### Collaborative Task (Part 3)

```json
{
  "type": "speaking_collaborative",
  "cambridgeEnglish": {
    "exam": "c1_advanced",
    "paper": "speaking",
    "part": 3,
    "voiceFriendly": true,
    "discussionTime": 120,
    "decisionTime": 60,
    "topic": "Factors that contribute to job satisfaction",
    "promptQuestion": "Why might these factors be important for job satisfaction?",
    "spokenPrompt": "Here are some factors that might contribute to job satisfaction: salary, flexible hours, interesting work, friendly colleagues, and opportunities for promotion. First, talk together about why these factors might be important for job satisfaction. You have two minutes.",
    "factors": [
      "salary",
      "flexible_hours",
      "interesting_work",
      "friendly_colleagues",
      "promotion_opportunities"
    ],
    "decisionQuestion": "Which factor is most important for people starting their careers?",
    "interactionStrategies": [
      "turn_taking",
      "building_on_ideas",
      "polite_disagreement",
      "reaching_consensus"
    ]
  }
}
```

### 6. Voice-Learning Optimizations

#### Paper-Specific Adaptations

```json
{
  "voiceOptimizations": {
    "reading_use_of_english": {
      "voiceFit": "high",
      "adaptations": [
        "Gap-fill exercises read aloud with 'blank' markers",
        "Word formation drills with base word spoken",
        "Key word transformations as verbal exercises",
        "Collocations and phrasal verbs as audio flashcards"
      ]
    },
    "listening": {
      "voiceFit": "native",
      "adaptations": [
        "Direct audio playback",
        "Variable speed practice",
        "Transcript reveal for study mode"
      ]
    },
    "speaking": {
      "voiceFit": "native",
      "adaptations": [
        "Timed speaking practice",
        "Model answer playback",
        "Useful phrase drilling",
        "AI conversation partner simulation"
      ]
    },
    "writing": {
      "voiceFit": "limited",
      "adaptations": [
        "Essay structure explanation",
        "Linking phrase drilling",
        "Vocabulary for writing spoken practice",
        "Oral essay planning exercises"
      ]
    }
  }
}
```

### 7. Performance Tracking

#### Score Tracking

```json
{
  "performanceTracking": {
    "exam": "c1_advanced",
    "cambridgeScale": {
      "overall": 185,
      "grade": "B",
      "cefrLevel": "C1"
    },
    "paperScores": {
      "reading_use_of_english": 188,
      "writing": 180,
      "listening": 190,
      "speaking": 182
    },
    "partAnalysis": {
      "use_of_english": {
        "part1_cloze": 0.75,
        "part2_open_cloze": 0.65,
        "part3_word_formation": 0.80,
        "part4_transformation": 0.60
      }
    },
    "recommendations": [
      "Focus on key word transformations (Part 4)",
      "Practice open cloze grammatical words"
    ]
  }
}
```

### 8. Study Session Configuration

#### Session Templates

```json
{
  "sessionTemplates": {
    "diagnostic": {
      "type": "diagnostic",
      "duration": 3600,
      "allPapers": true,
      "levelAssessment": true
    },
    "use_of_english_blitz": {
      "type": "skill_focus",
      "paper": "reading_use_of_english",
      "parts": [1, 2, 3, 4],
      "duration": 1800,
      "voicePrimary": true,
      "instantFeedback": true
    },
    "listening_intensive": {
      "type": "skill_focus",
      "paper": "listening",
      "duration": 1200,
      "variety": ["monologues", "dialogues", "interviews"],
      "accentVariety": true
    },
    "speaking_practice": {
      "type": "skill_focus",
      "paper": "speaking",
      "duration": 1200,
      "allParts": true,
      "timedPractice": true,
      "modelResponses": true
    },
    "word_formation_drill": {
      "type": "vocabulary",
      "focus": "word_families",
      "duration": 900,
      "affixDrilling": true,
      "spacedRepetition": true
    },
    "exam_simulation": {
      "type": "simulation",
      "exam": "c1_advanced",
      "timed": true,
      "voiceAdapted": true
    }
  }
}
```

## JSON Schema Fragment

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "definitions": {
    "cambridgeEnglishExtension": {
      "type": "object",
      "properties": {
        "exam": {
          "type": "string",
          "enum": ["b2_first", "c1_advanced", "c2_proficiency"],
          "description": "Cambridge exam type"
        },
        "paper": {
          "type": "string",
          "enum": ["reading_use_of_english", "writing", "listening", "speaking"],
          "description": "Exam paper"
        },
        "part": {
          "type": "integer",
          "minimum": 1,
          "maximum": 8,
          "description": "Part number within paper"
        },
        "taskType": {
          "type": "string",
          "description": "Specific task type"
        },
        "duration": {
          "type": "integer",
          "description": "Time in minutes"
        },
        "questionCount": {
          "type": "integer",
          "description": "Number of questions"
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
          "description": "Grammar points"
        }
      },
      "required": ["exam", "paper"]
    }
  }
}
```

## Validation Rules

### Required Fields

1. All Cambridge content MUST include `exam` and `paper`
2. Use of English tasks MUST include `part` and `taskType`
3. Listening content MUST specify `playCount` and audio type
4. Speaking content MUST specify timing and evaluation criteria

### Scoring Rules

1. Cambridge Scale: 80-230
2. B2 First pass: 160+, C1 Advanced pass: 180+, C2 Proficiency pass: 200+
3. Reading & Use of English = 40%, other papers = 20% each

### Voice-Friendly Guidelines

1. Gap-fill exercises MUST include spoken versions with "blank" markers
2. Word formation MUST include base word pronunciation
3. Speaking tasks are native voice content
4. Writing tasks should include oral planning alternatives

## Versioning

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | January 2026 | Initial Cambridge English extensions |

---

*This specification extends UMCF v1.1.0 and should be read in conjunction with the base UMCF Specification.*

## Sources

- [C1 Advanced exam format](https://www.cambridgeenglish.org/exams-and-tests/qualifications/advanced/format/)
- [Cambridge B2 First Exam Guide](https://www.lingolugo.com/html/B2Overview.html)
- [Cambridge C1 Advanced Exam Guide](https://www.lingolugo.com/html/C1Overview.html)
