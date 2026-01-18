# Goethe-Zertifikat / TestDaF German UMCF Extensions

This document specifies the UMCF schema extensions required to support Goethe-Zertifikat and TestDaF German language exam preparation content. These extensions build upon the base UMCF v1.1.0 specification.

## Overview

### Goethe-Zertifikat
Official German language certifications from the Goethe-Institut:
- **Valid for life**
- **Modular** (can take sections separately)
- **Covers A1-C2** levels
- **Accepted by 150+ countries**

### TestDaF
Standardized test for university admission in Germany:
- **Valid for life**
- **B2-C1 level** only
- **Required for German university admission**
- **500+ test centers in 100 countries**

### Qualifications Covered
| Exam | Levels | Purpose |
|------|--------|---------|
| **Goethe-Zertifikat** | A1-C2 | General proficiency |
| **TestDaF** | B2-C1 | Academic/university admission |

## Extension Namespace

All Goethe/TestDaF extensions use the `goetheTestDaF` namespace within UMCF content nodes.

```json
{
  "extensions": {
    "goetheTestDaF": {
      // Goethe/TestDaF specific fields
    }
  }
}
```

## Schema Extensions

### 1. Content Node Extensions

#### goetheTestDaF Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `examType` | enum | Yes | goethe or testdaf |
| `level` | enum | Yes | CEFR level |
| `modul` | enum | Yes | Skill module being tested |
| `teil` | number | No | Part number (Teil) within module |
| `aufgabe` | number | No | Task number (Aufgabe) |
| `duration` | number | No | Time allocation in minutes |
| `maxPoints` | number | No | Maximum points |
| `voiceFriendly` | boolean | No | Optimized for voice learning |
| `thema` | string | No | Thematic topic |
| `grammatikFokus` | array | No | Grammar points covered |
| `wortschatzThema` | string | No | Vocabulary theme |

#### examType Enum

```json
{
  "enum": ["goethe", "testdaf"]
}
```

#### level Enum

```json
{
  "enum": ["A1", "A2", "B1", "B2", "C1", "C2", "TDN3", "TDN4", "TDN5"]
}
```

Note: TDN levels are TestDaF-specific (TDN 3 ≈ B2.1, TDN 4 ≈ B2.2/C1.1, TDN 5 ≈ C1)

#### modul Enum

```json
{
  "enum": ["lesen", "hoeren", "schreiben", "sprechen"]
}
```

| Modul | German | English | Points | Voice-Friendly |
|-------|--------|---------|--------|----------------|
| `lesen` | Lesen | Reading | 100 (Goethe) | ★★★★☆ |
| `hoeren` | Hören | Listening | 100 (Goethe) | ★★★★★ |
| `schreiben` | Schreiben | Writing | 100 (Goethe) | ★★★☆☆ |
| `sprechen` | Sprechen | Speaking | 100 (Goethe) | ★★★★★ |

### 2. Exam Structure

#### Goethe-Zertifikat B2 Structure

```json
{
  "examStructure": {
    "examType": "goethe",
    "level": "B2",
    "totalDuration": 190,
    "passingScore": 60,
    "modular": true,
    "module": {
      "lesen": {
        "duration": 65,
        "teile": 4,
        "maxPoints": 100,
        "aufgaben": 30
      },
      "hoeren": {
        "duration": 40,
        "teile": 4,
        "maxPoints": 100,
        "aufgaben": 30
      },
      "schreiben": {
        "duration": 75,
        "teile": 2,
        "maxPoints": 100
      },
      "sprechen": {
        "duration": 15,
        "teile": 2,
        "maxPoints": 100,
        "paarprüfung": true
      }
    }
  }
}
```

#### TestDaF Structure

```json
{
  "examStructure": {
    "examType": "testdaf",
    "totalDuration": 210,
    "levels": ["TDN3", "TDN4", "TDN5"],
    "academicFocus": true,
    "module": {
      "lesen": {
        "duration": 60,
        "teile": 3,
        "aufgaben": 30
      },
      "hoeren": {
        "duration": 40,
        "teile": 3,
        "aufgaben": 25
      },
      "schreiben": {
        "duration": 60,
        "teile": 1,
        "taskType": "academic_essay"
      },
      "sprechen": {
        "duration": 30,
        "teile": 7,
        "format": "computer_based"
      }
    },
    "universityRequirement": "TDN 4 in all modules"
  }
}
```

### 3. Content Classification

#### Topic Taxonomy

```json
{
  "themen": {
    "alltag": {
      "de": "Alltag",
      "en": "Daily Life",
      "subtopics": ["einkaufen", "wohnen", "essen_trinken", "freizeit", "verkehr"]
    },
    "beruf": {
      "de": "Beruf und Arbeit",
      "en": "Work and Career",
      "subtopics": ["bewerbung", "arbeitsplatz", "kollegen", "meetings", "karriere"]
    },
    "bildung": {
      "de": "Bildung und Studium",
      "en": "Education",
      "subtopics": ["schule", "universitaet", "kurse", "pruefungen", "forschung"]
    },
    "gesellschaft": {
      "de": "Gesellschaft",
      "en": "Society",
      "subtopics": ["politik", "umwelt", "medien", "kultur", "soziales"]
    },
    "wissenschaft": {
      "de": "Wissenschaft und Technik",
      "en": "Science and Technology",
      "subtopics": ["forschung", "technologie", "medizin", "innovation"]
    },
    "reisen": {
      "de": "Reisen und Tourismus",
      "en": "Travel and Tourism",
      "subtopics": ["urlaub", "hotel", "transport", "sehenswuerdigkeiten"]
    }
  }
}
```

#### Grammar Focus by Level

```json
{
  "grammatikProgression": {
    "A1": [
      "praesens",
      "artikel",
      "personalpronomen",
      "negation_nicht_kein",
      "wortstellung",
      "ja_nein_fragen"
    ],
    "A2": [
      "perfekt",
      "praeteritum_modal",
      "dativ",
      "praepositionen_wechsel",
      "nebensaetze_weil_dass",
      "komparativ_superlativ"
    ],
    "B1": [
      "praeteritum",
      "passiv_praesens",
      "konjunktiv_II",
      "relativsaetze",
      "indirekte_rede",
      "konnektoren"
    ],
    "B2": [
      "passiv_alle_zeiten",
      "partizipien_als_adjektive",
      "nominalisierung",
      "konjunktiv_I",
      "komplexe_satzstrukturen",
      "modalpartikeln"
    ],
    "C1_C2": [
      "erweiterte_partizipien",
      "nomen_verb_verbindungen",
      "gehobener_stil",
      "wissenschaftssprache",
      "umgangssprache_register"
    ]
  }
}
```

### 4. Assessment Extensions

#### Listening (Hören)

Voice-native content:

```json
{
  "type": "hoeren",
  "goetheTestDaF": {
    "examType": "goethe",
    "level": "B2",
    "modul": "hoeren",
    "teil": 1,
    "voiceFriendly": true,
    "audioType": "kurze_texte",
    "playCount": 2,
    "thema": "alltag",
    "aufgaben": [
      {
        "nummer": 1,
        "kontext": "Sie hören fünf kurze Texte. Zu jedem Text gibt es eine Aufgabe.",
        "spokenKontext": "Sie hören fünf kurze Texte. Zu jedem Text gibt es eine Aufgabe.",
        "text": "Guten Tag, hier ist die Praxis Dr. Müller...",
        "frage": "Was soll die Person tun?",
        "antworten": [
          "Später anrufen",
          "Eine Nachricht hinterlassen",
          "Zur Praxis kommen"
        ],
        "richtig": "Später anrufen",
        "punkte": 1
      }
    ]
  }
}
```

#### TestDaF Academic Listening

```json
{
  "type": "hoeren_testdaf",
  "goetheTestDaF": {
    "examType": "testdaf",
    "modul": "hoeren",
    "teil": 2,
    "voiceFriendly": true,
    "audioType": "interview_wissenschaft",
    "duration": 300,
    "playCount": 2,
    "thema": "wissenschaft",
    "akademischKontext": "Universitätsvorlesung",
    "aufgaben": [
      {
        "typ": "richtig_falsch",
        "aussage": "Der Forscher hat die Studie alleine durchgeführt.",
        "richtig": false,
        "begruendung": "Er erwähnt, dass er mit einem Team gearbeitet hat."
      }
    ]
  }
}
```

#### Speaking (Sprechen)

Voice-native content:

```json
{
  "type": "sprechen",
  "goetheTestDaF": {
    "examType": "goethe",
    "level": "B2",
    "modul": "sprechen",
    "teil": 1,
    "voiceFriendly": true,
    "aufgabeTyp": "praesentation",
    "vorbereitungszeit": 60,
    "sprechzeit": 90,
    "thema": "gesellschaft",
    "aufgabe": {
      "titel": "Sollte man Plastiktüten verbieten?",
      "spokenAufgabe": "Halten Sie einen kurzen Vortrag zum Thema: Sollte man Plastiktüten verbieten? Nennen Sie Vor- und Nachteile und sagen Sie Ihre Meinung.",
      "stichpunkte": [
        "Umweltschutz",
        "Alternativen",
        "Wirtschaftliche Auswirkungen",
        "Persönliche Meinung"
      ],
      "nuetzlichePhrasen": [
        "Ich möchte heute über... sprechen.",
        "Einerseits... andererseits...",
        "Meiner Meinung nach...",
        "Zusammenfassend lässt sich sagen..."
      ]
    },
    "bewertungskriterien": [
      "aufgabenerfuellung",
      "kohaerenz",
      "wortschatz",
      "grammatik",
      "aussprache"
    ]
  }
}
```

#### TestDaF Speaking (Computer-Based)

```json
{
  "type": "sprechen_testdaf",
  "goetheTestDaF": {
    "examType": "testdaf",
    "modul": "sprechen",
    "teil": 3,
    "voiceFriendly": true,
    "format": "computer_based",
    "vorbereitungszeit": 60,
    "sprechzeit": 120,
    "akademischKontext": true,
    "aufgabe": {
      "situation": "Sie nehmen an einem Seminar teil. Diskutieren Sie die Grafik.",
      "grafikBeschreibung": "Die Grafik zeigt die Entwicklung der Studierendenzahlen von 2010 bis 2020.",
      "spokenAufgabe": "Beschreiben Sie die Grafik und interpretieren Sie die Entwicklung. Sie haben zwei Minuten.",
      "strukturHilfe": [
        "Einleitung: Was zeigt die Grafik?",
        "Hauptteil: Beschreibung der Entwicklung",
        "Interpretation: Mögliche Gründe",
        "Schluss: Ausblick"
      ]
    }
  }
}
```

#### Diktat (Dictation Practice)

Classic German learning exercise:

```json
{
  "type": "diktat",
  "goetheTestDaF": {
    "level": "B1",
    "voiceFriendly": true,
    "text": "Die deutsche Sprache hat viele interessante Wörter.",
    "geschwindigkeit": "normal",
    "wiederholungen": 3,
    "grammatikFokus": ["umlaute", "eszett", "zusammengesetzte_woerter"],
    "hinweise": [
      "Achten Sie auf die Umlaute: ä, ö, ü",
      "Das ß wird nach langen Vokalen verwendet"
    ]
  }
}
```

### 5. Voice-Learning Optimizations

#### Module-Specific Adaptations

```json
{
  "voiceOptimizations": {
    "hoeren": {
      "voiceFit": "native",
      "adaptations": [
        "Direct German audio playback",
        "Variable speed practice",
        "Regional accent exposure",
        "Transcript study mode"
      ]
    },
    "sprechen": {
      "voiceFit": "native",
      "adaptations": [
        "Timed speaking practice",
        "Pronunciation feedback",
        "Useful phrase drilling",
        "AI conversation partner"
      ]
    },
    "lesen": {
      "voiceFit": "adapted",
      "adaptations": [
        "Text read aloud by German TTS",
        "Questions in German audio",
        "Vocabulary in context"
      ]
    },
    "schreiben": {
      "voiceFit": "limited",
      "adaptations": [
        "Essay structure explanation",
        "Useful phrase drilling",
        "Diktat practice",
        "Grammar rule explanations"
      ]
    }
  }
}
```

### 6. Performance Tracking

#### Goethe Scoring

```json
{
  "performanceTracking": {
    "examType": "goethe",
    "level": "B2",
    "modulScores": {
      "lesen": {
        "punkte": 75,
        "maxPunkte": 100,
        "prozent": 75,
        "bestanden": true,
        "note": "gut"
      },
      "hoeren": {
        "punkte": 82,
        "maxPunkte": 100,
        "prozent": 82,
        "bestanden": true,
        "note": "gut"
      },
      "schreiben": {
        "punkte": 68,
        "maxPunkte": 100,
        "prozent": 68,
        "bestanden": true,
        "note": "befriedigend"
      },
      "sprechen": {
        "punkte": 90,
        "maxPunkte": 100,
        "prozent": 90,
        "bestanden": true,
        "note": "sehr gut"
      }
    },
    "gesamtErgebnis": "bestanden",
    "empfehlungen": [
      "Schriftlichen Ausdruck verbessern",
      "Konnektoren üben"
    ]
  }
}
```

#### TestDaF TDN Scoring

```json
{
  "performanceTracking": {
    "examType": "testdaf",
    "modulErgebnisse": {
      "lesen": "TDN4",
      "hoeren": "TDN5",
      "schreiben": "TDN4",
      "sprechen": "TDN4"
    },
    "universitaetsZulassung": true,
    "empfehlung": "Alle Module TDN 4 oder höher - Zulassung möglich"
  }
}
```

### 7. Study Session Configuration

#### Session Templates

```json
{
  "sessionTemplates": {
    "einstufungstest": {
      "type": "diagnostic",
      "duration": 3600,
      "alleModule": true,
      "levelAssessment": true,
      "voicePrimary": true
    },
    "hoerverstehen_intensiv": {
      "type": "skill_focus",
      "modul": "hoeren",
      "duration": 1800,
      "variety": ["dialoge", "interviews", "vortraege"],
      "akkzentVariation": true
    },
    "sprechen_uebung": {
      "type": "skill_focus",
      "modul": "sprechen",
      "duration": 1200,
      "alleTeile": true,
      "timedPractice": true,
      "modelResponses": true
    },
    "grammatik_durch_hoeren": {
      "type": "integrated",
      "duration": 1200,
      "focus": "grammatik",
      "method": "listening_examples",
      "targetStructures": ["configurable"]
    },
    "testdaf_simulation": {
      "type": "simulation",
      "examType": "testdaf",
      "fullExam": true,
      "timed": true,
      "academicFocus": true
    },
    "wortschatz_builder": {
      "type": "vocabulary",
      "duration": 900,
      "thema": "configurable",
      "method": "contextual_audio",
      "spacedRepetition": true
    }
  }
}
```

## JSON Schema Fragment

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "definitions": {
    "goetheTestDaFExtension": {
      "type": "object",
      "properties": {
        "examType": {
          "type": "string",
          "enum": ["goethe", "testdaf"],
          "description": "Exam type"
        },
        "level": {
          "type": "string",
          "enum": ["A1", "A2", "B1", "B2", "C1", "C2", "TDN3", "TDN4", "TDN5"],
          "description": "CEFR or TDN level"
        },
        "modul": {
          "type": "string",
          "enum": ["lesen", "hoeren", "schreiben", "sprechen"],
          "description": "Skill module"
        },
        "teil": {
          "type": "integer",
          "minimum": 1,
          "description": "Part number"
        },
        "aufgabe": {
          "type": "integer",
          "description": "Task number"
        },
        "duration": {
          "type": "integer",
          "description": "Time in minutes"
        },
        "maxPoints": {
          "type": "integer",
          "default": 100,
          "description": "Maximum points"
        },
        "voiceFriendly": {
          "type": "boolean",
          "default": true,
          "description": "Optimized for voice learning"
        },
        "thema": {
          "type": "string",
          "description": "Topic theme"
        },
        "grammatikFokus": {
          "type": "array",
          "items": {"type": "string"},
          "description": "Grammar points"
        }
      },
      "required": ["examType", "level", "modul"]
    }
  }
}
```

## Validation Rules

### Required Fields

1. All content MUST include `examType`, `level`, and `modul`
2. Listening content MUST specify `playCount` and audio type
3. Speaking content MUST specify `vorbereitungszeit` and `sprechzeit`
4. TestDaF content MUST specify academic context

### Scoring Rules

**Goethe:**
- Each module is scored out of 100 points
- Pass mark: 60% per module
- Modules can be taken separately

**TestDaF:**
- Results in TDN levels (3, 4, or 5)
- TDN 4 in all modules = university admission
- Below TDN 3 = "unter TDN 3" (not passing)

### Voice-Friendly Guidelines

1. All prompts MUST include German `spoken` variants
2. Content should specify German TTS language code (`de`)
3. Include pronunciation guides for difficult words
4. Speaking tasks are native voice content

## Content Language

**IMPORTANT**: Content for Goethe/TestDaF is in German. The UMCF file should specify:

```json
{
  "metadata": {
    "language": "de",
    "ttsLanguage": "de"
  }
}
```

## Versioning

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | January 2026 | Initial Goethe/TestDaF extensions |

---

*This specification extends UMCF v1.1.0 and should be read in conjunction with the base UMCF Specification.*

## Sources

- [Goethe-Institut Exams](https://www.goethe.de/en/spr/kup/prf.html)
- [TestDaF Overview](https://en.wikipedia.org/wiki/TestDaF)
- [German Proficiency Exams Guide](https://www.olesentuition.co.uk/single-post/german-proficiency-exams-goethe-and-testdaf)
