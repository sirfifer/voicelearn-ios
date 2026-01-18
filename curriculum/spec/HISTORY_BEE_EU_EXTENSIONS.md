# History Bee EU UMCF Extensions

This document specifies the UMCF schema extensions required to support International History Bee and Bowl (European Division) preparation content. These extensions build upon the base UMCF v1.1.0 specification and share structural similarities with the Knowledge Bowl extensions.

## Overview

The International History Bee and Bowl (IHBB) European Division runs academic competitions for students across Europe. The format includes:
- **History Bee**: Individual buzzer competition
- **History Bowl**: Team competition (all members from same school)

Questions use a **pyramidal structure**, starting with harder clues and progressively revealing easier information.

## Extension Namespace

All History Bee EU extensions use the `historyBeeEU` namespace within UMCF content nodes.

```json
{
  "extensions": {
    "historyBeeEU": {
      // History Bee EU specific fields
    }
  }
}
```

## Schema Extensions

### 1. Content Node Extensions

#### historyBeeEU Object

Added to any content node (topic, segment, assessment):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `competitionYear` | string | Yes | Academic year (e.g., "2025-2026") |
| `organization` | enum | Yes | Competition organization (ihbb_europe, ihbb_international) |
| `competitionType` | enum | No | bee (individual) or bowl (team) |
| `difficultyTier` | enum | No | Age/competition level |
| `domain` | string | Yes | Historical domain |
| `period` | string | No | Historical period |
| `region` | string | No | Geographic focus |
| `questionWeight` | number | No | Relative importance (0.0-1.0) |
| `speedTarget` | number | No | Target response time in seconds |
| `buzzPoints` | array | No | Phrases indicating buzz opportunity |
| `pyramidClues` | array | No | Progressive clue structure |
| `yearlyUpdate` | boolean | No | Content requires annual refresh |
| `europeanFocus` | boolean | No | Indicates European-centric content |

#### difficultyTier Enum

```json
{
  "enum": ["elementary", "middle_school", "jv", "varsity", "championship", "invitational"]
}
```

| Tier | Description | Birth Date Cutoff (2025-26) |
|------|-------------|----------------------------|
| `elementary` | Younger students | Born Sept 2013 or later |
| `middle_school` | Middle school level | Born Sept 2011 or later |
| `jv` | Junior Varsity | Born Sept 2009 - Aug 2011 |
| `varsity` | Standard varsity competition | Born before Sept 2009 |
| `championship` | European Championships level | Top qualifiers |
| `invitational` | International History Olympiad prep | Advanced |

### 2. Domain Classification

#### Historical Domain Taxonomy

History Bee EU content is organized by historical domain, period, and region:

```json
{
  "domains": {
    "european_history": {
      "periods": ["ancient", "medieval", "early_modern", "modern", "contemporary"],
      "regions": ["western_europe", "eastern_europe", "southern_europe", "northern_europe", "central_europe"]
    },
    "world_history": {
      "periods": ["ancient", "classical", "medieval", "early_modern", "modern", "contemporary"],
      "regions": ["asia", "africa", "americas", "oceania", "middle_east"]
    },
    "ancient_civilizations": {
      "categories": ["greece", "rome", "egypt", "mesopotamia", "persia", "china", "india"]
    },
    "medieval_history": {
      "categories": ["byzantine", "islamic_golden_age", "feudal_europe", "crusades", "mongols", "renaissance"]
    },
    "modern_european": {
      "categories": ["reformation", "enlightenment", "french_revolution", "industrial_revolution", "nationalism", "imperialism"]
    },
    "twentieth_century": {
      "categories": ["world_war_i", "interwar", "world_war_ii", "cold_war", "european_integration", "post_cold_war"]
    },
    "european_union": {
      "categories": ["founding", "expansion", "institutions", "policies", "member_states"]
    },
    "historical_figures": {
      "categories": ["rulers", "military_leaders", "philosophers", "scientists", "artists", "reformers"]
    },
    "cultural_history": {
      "categories": ["art_movements", "literature", "philosophy", "religion", "science", "technology"]
    },
    "political_history": {
      "categories": ["governments", "revolutions", "treaties", "diplomacy", "wars", "movements"]
    },
    "economic_history": {
      "categories": ["trade", "industry", "finance", "agriculture", "labor", "globalization"]
    },
    "social_history": {
      "categories": ["demographics", "class", "gender", "migration", "urbanization", "daily_life"]
    }
  }
}
```

#### Regional Focus Categories

```json
{
  "regions": {
    "western_europe": {
      "countries": ["france", "germany", "netherlands", "belgium", "luxembourg", "austria", "switzerland"]
    },
    "southern_europe": {
      "countries": ["italy", "spain", "portugal", "greece", "malta", "cyprus"]
    },
    "northern_europe": {
      "countries": ["united_kingdom", "ireland", "denmark", "sweden", "norway", "finland", "iceland"]
    },
    "eastern_europe": {
      "countries": ["poland", "czech_republic", "slovakia", "hungary", "romania", "bulgaria"]
    },
    "baltic_states": {
      "countries": ["estonia", "latvia", "lithuania"]
    },
    "balkans": {
      "countries": ["slovenia", "croatia", "serbia", "bosnia", "montenegro", "north_macedonia", "albania", "kosovo"]
    }
  }
}
```

### 3. Assessment Extensions

#### Question Type Extensions

##### Pyramid Toss-Up (Primary Format)

The standard History Bee format with progressive clues:

```json
{
  "type": "pyramid",
  "questionType": "toss_up",
  "historyBeeEU": {
    "organization": "ihbb_europe",
    "competitionType": "bee",
    "clues": [
      {
        "text": "This ruler's forces defeated the Umayyad Caliphate at the Battle of Tours in 732.",
        "difficulty": "expert",
        "buzzWindow": "early"
      },
      {
        "text": "He united the Frankish kingdoms and established the Carolingian dynasty.",
        "difficulty": "hard",
        "buzzWindow": "optimal"
      },
      {
        "text": "His grandson would be crowned as the first Holy Roman Emperor.",
        "difficulty": "medium",
        "buzzWindow": "late"
      },
      {
        "text": "Name this Frankish leader known as 'The Hammer' who was the father of Pepin the Short.",
        "difficulty": "giveaway",
        "buzzWindow": "final"
      }
    ],
    "answer": "Charles Martel",
    "alternateAnswers": ["Karl Martell", "Charles the Hammer"],
    "pronounce": "SHARL mar-TEL",
    "timeLimit": 10,
    "interruptible": true
  }
}
```

##### Team Bowl Bonus

Multi-part bonus for team competition:

```json
{
  "type": "bonus",
  "historyBeeEU": {
    "competitionType": "bowl",
    "leadIn": "Answer these questions about the Congress of Vienna.",
    "parts": [
      {
        "prompt": "Name the Austrian foreign minister who hosted the Congress.",
        "answer": "Klemens von Metternich",
        "alternateAnswers": ["Metternich", "Prince Metternich"],
        "points": 10
      },
      {
        "prompt": "What principle guided the restoration of pre-Napoleonic monarchies?",
        "answer": "Legitimacy",
        "alternateAnswers": ["Principle of Legitimacy"],
        "points": 10
      },
      {
        "prompt": "Name the British foreign secretary who represented the United Kingdom.",
        "answer": "Viscount Castlereagh",
        "alternateAnswers": ["Castlereagh", "Robert Stewart"],
        "points": 10
      }
    ],
    "totalPoints": 30,
    "conferenceTime": 5
  }
}
```

##### Lightning Round (European Capitals/Leaders)

Rapid-fire questions on a specific theme:

```json
{
  "type": "lightning",
  "historyBeeEU": {
    "category": "European Capital Cities Through History",
    "timeLimit": 60,
    "questions": [
      {
        "prompt": "What city was the capital of the Byzantine Empire?",
        "answer": "Constantinople"
      },
      {
        "prompt": "What city served as capital of the Holy Roman Empire under Charlemagne?",
        "answer": "Aachen"
      },
      {
        "prompt": "What city became the capital of unified Italy in 1871?",
        "answer": "Rome"
      }
    ],
    "pointsPerCorrect": 10,
    "negativePoints": false
  }
}
```

### 4. Competition Configuration

#### IHBB Europe Rules

```json
{
  "competitionConfig": {
    "organization": "ihbb_europe",
    "format": "european_championship",
    "year": "2025-2026",
    "rules": {
      "tossupFormat": "pyramid",
      "interruptible": true,
      "negativePoints": true,
      "negativeValue": -5,
      "correctValue": 10,
      "powerEnabled": true,
      "powerValue": 15,
      "powerWindow": 0.5,
      "bonusFormat": "three_part",
      "bonusPartValue": 10
    },
    "events": {
      "european_championships": {
        "location": "Berlin",
        "date": "May 29-31, 2026",
        "qualification": "Through national/regional tournaments"
      },
      "online_tournaments": {
        "fall_bee": "December 2025",
        "winter_bee": "March 2026"
      }
    }
  }
}
```

### 5. Performance Tracking Extensions

#### Speed Metrics

```json
{
  "speedMetrics": {
    "targetBuzzPoint": 0.6,
    "averageBuzzPoint": 0.72,
    "earlyBuzzRate": 0.15,
    "optimalBuzzRate": 0.60,
    "lateBuzzRate": 0.25,
    "conversionRate": 0.85
  }
}
```

#### Historical Period Performance

```json
{
  "periodPerformance": {
    "ancient": { "accuracy": 0.78, "avgBuzzPoint": 0.68 },
    "medieval": { "accuracy": 0.82, "avgBuzzPoint": 0.65 },
    "early_modern": { "accuracy": 0.75, "avgBuzzPoint": 0.72 },
    "modern": { "accuracy": 0.88, "avgBuzzPoint": 0.58 },
    "contemporary": { "accuracy": 0.90, "avgBuzzPoint": 0.55 }
  }
}
```

#### Regional Knowledge Gaps

```json
{
  "regionAnalysis": {
    "strengths": ["western_europe", "ancient_civilizations"],
    "weaknesses": ["eastern_europe", "balkans"],
    "recommendations": [
      "Focus on post-WWII Eastern European history",
      "Study Yugoslav Wars and Balkan independence movements"
    ]
  }
}
```

### 6. Study Session Configuration

#### Session Templates

```json
{
  "sessionTemplates": {
    "diagnostic": {
      "type": "diagnostic",
      "duration": 3600,
      "periodCoverage": "all",
      "regionBalance": true,
      "difficultyMix": {
        "easy": 0.3,
        "medium": 0.5,
        "hard": 0.2
      }
    },
    "period_deep_dive": {
      "type": "focused",
      "duration": 1800,
      "targetPeriod": "configurable",
      "includeContext": true,
      "connectionQuestions": true
    },
    "buzz_practice": {
      "type": "speed",
      "duration": 1200,
      "pyramidOnly": true,
      "buzzFeedback": true,
      "optimalWindowTraining": true
    },
    "tournament_simulation": {
      "type": "simulation",
      "format": "ihbb_europe",
      "rounds": 8,
      "questionsPerRound": 10,
      "aiOpponent": true,
      "opponentDifficulty": "varsity"
    },
    "european_championships_prep": {
      "type": "intensive",
      "duration": 7200,
      "focusAreas": ["european_history", "european_union"],
      "difficultyTier": "championship",
      "includeWrittenComponent": true
    }
  }
}
```

### 7. Content Categorization by Competition Event

#### European Championships Content

```json
{
  "eventContent": {
    "european_championships": {
      "distribution": {
        "european_history": 0.50,
        "world_history": 0.30,
        "ancient_civilizations": 0.10,
        "cultural_history": 0.10
      },
      "europeanEmphasis": true,
      "periodWeights": {
        "modern": 0.35,
        "contemporary": 0.25,
        "medieval": 0.20,
        "ancient": 0.10,
        "early_modern": 0.10
      }
    },
    "international_history_olympiad": {
      "distribution": {
        "world_history": 0.45,
        "european_history": 0.35,
        "ancient_civilizations": 0.10,
        "cultural_history": 0.10
      }
    }
  }
}
```

## JSON Schema Fragment

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "definitions": {
    "historyBeeEUExtension": {
      "type": "object",
      "properties": {
        "competitionYear": {
          "type": "string",
          "pattern": "^\\d{4}-\\d{4}$",
          "description": "Academic competition year"
        },
        "organization": {
          "type": "string",
          "enum": ["ihbb_europe", "ihbb_international", "national_affiliate"],
          "description": "Competition organization"
        },
        "competitionType": {
          "type": "string",
          "enum": ["bee", "bowl"],
          "description": "Individual (bee) or team (bowl) format"
        },
        "difficultyTier": {
          "type": "string",
          "enum": ["elementary", "middle_school", "jv", "varsity", "championship", "invitational"],
          "description": "Competition difficulty level"
        },
        "domain": {
          "type": "string",
          "enum": ["european_history", "world_history", "ancient_civilizations", "medieval_history", "modern_european", "twentieth_century", "european_union", "historical_figures", "cultural_history", "political_history", "economic_history", "social_history"],
          "description": "Historical domain"
        },
        "period": {
          "type": "string",
          "enum": ["ancient", "classical", "medieval", "early_modern", "modern", "contemporary"],
          "description": "Historical period"
        },
        "region": {
          "type": "string",
          "description": "Geographic focus"
        },
        "questionWeight": {
          "type": "number",
          "minimum": 0,
          "maximum": 1,
          "description": "Relative importance in competition"
        },
        "speedTarget": {
          "type": "number",
          "minimum": 0,
          "description": "Target buzz time in seconds"
        },
        "buzzPoints": {
          "type": "array",
          "items": {
            "type": "string"
          },
          "description": "Key phrases for buzz opportunities"
        },
        "pyramidClues": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/historyPyramidClue"
          }
        },
        "europeanFocus": {
          "type": "boolean",
          "default": true,
          "description": "Content has European emphasis"
        },
        "yearlyUpdate": {
          "type": "boolean",
          "default": false,
          "description": "Content requires annual refresh"
        }
      },
      "required": ["competitionYear", "organization", "domain"]
    },
    "historyPyramidClue": {
      "type": "object",
      "properties": {
        "text": {
          "type": "string",
          "description": "Clue text"
        },
        "difficulty": {
          "type": "string",
          "enum": ["expert", "hard", "medium", "easy", "giveaway"]
        },
        "buzzWindow": {
          "type": "string",
          "enum": ["early", "optimal", "late", "final"],
          "description": "Recommended buzz timing"
        }
      },
      "required": ["text", "difficulty"]
    }
  }
}
```

## Validation Rules

### Required Fields

1. All History Bee EU content nodes MUST include `competitionYear`
2. All content nodes MUST include `organization` (default: ihbb_europe)
3. All content nodes MUST include `domain`
4. Pyramid questions MUST include at least 3 clues with decreasing difficulty
5. Bowl bonus questions MUST include exactly 3 parts

### Content Guidelines

1. European Championships content SHOULD have 50%+ European history focus
2. Pyramid clues MUST progress from hardest to easiest
3. Answers MUST include pronunciation guides for non-English names
4. Alternate answers MUST include common variants and translations

### Competition Accuracy Rules

1. Point values MUST match IHBB Europe rules
2. Time limits MUST reflect actual competition conditions
3. Content distribution SHOULD reflect official competition balance

## Migration from Knowledge Bowl Extensions

Existing Knowledge Bowl history content can be adapted:

```json
// Before (Knowledge Bowl)
{
  "extensions": {
    "knowledgeBowl": {
      "competitionYear": "2024-2025",
      "domain": "history",
      "category": "world_history"
    }
  }
}

// After (History Bee EU)
{
  "extensions": {
    "historyBeeEU": {
      "competitionYear": "2025-2026",
      "organization": "ihbb_europe",
      "domain": "european_history",
      "period": "modern",
      "region": "western_europe",
      "europeanFocus": true
    }
  }
}
```

## Versioning

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | January 2026 | Initial History Bee EU extensions |

---

*This specification extends UMCF v1.1.0 and should be read in conjunction with the base UMCF Specification and Knowledge Bowl Extensions.*
