# Geography Bee EU UMCF Extensions

This document specifies the UMCF schema extensions required to support International Geography Bee (European Division) preparation content. These extensions build upon the base UMCF v1.1.0 specification and share structural similarities with the History Bee EU and Knowledge Bowl extensions.

## Overview

The International Geography Bee (run by International Academic Competitions) European Division runs academic geography competitions for students across Europe. The format mirrors the History Bee structure:
- **Geography Bee**: Individual buzzer competition
- **Geography Bowl**: Team competition

Questions use a **pyramidal structure** and cover physical, human, political, and economic geography.

## Extension Namespace

All Geography Bee EU extensions use the `geographyBeeEU` namespace within UMCF content nodes.

```json
{
  "extensions": {
    "geographyBeeEU": {
      // Geography Bee EU specific fields
    }
  }
}
```

## Schema Extensions

### 1. Content Node Extensions

#### geographyBeeEU Object

Added to any content node (topic, segment, assessment):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `competitionYear` | string | Yes | Academic year (e.g., "2025-2026") |
| `organization` | enum | Yes | Competition organization |
| `competitionType` | enum | No | bee (individual) or bowl (team) |
| `difficultyTier` | enum | No | Age/competition level |
| `domain` | string | Yes | Geographic domain |
| `subDomain` | string | No | Specific topic within domain |
| `region` | string | No | Geographic focus region |
| `questionWeight` | number | No | Relative importance (0.0-1.0) |
| `speedTarget` | number | No | Target response time in seconds |
| `buzzPoints` | array | No | Phrases indicating buzz opportunity |
| `pyramidClues` | array | No | Progressive clue structure |
| `voiceFriendly` | boolean | No | Question works well in voice-only format |
| `requiresVisual` | boolean | No | Question requires map/image (filtered for voice) |

#### difficultyTier Enum

```json
{
  "enum": ["elementary", "middle_school", "jv", "varsity", "championship", "international"]
}
```

| Tier | Description | Birth Date Cutoff (2025-26) |
|------|-------------|----------------------------|
| `elementary` | Younger students | Born Sept 2013 or later |
| `middle_school` | Middle school level | Born Sept 2011 or later |
| `jv` | Junior Varsity | Born Sept 2009 - Aug 2011 |
| `varsity` | Standard varsity competition | Born before Sept 2009 |
| `championship` | International Championships level | Top qualifiers |
| `international` | International Geography Championships | Elite level |

### 2. Domain Classification

#### Geographic Domain Taxonomy

```json
{
  "domains": {
    "physical_geography": {
      "subDomains": [
        "landforms",
        "climate",
        "hydrology",
        "biogeography",
        "geology",
        "natural_disasters",
        "oceanography"
      ]
    },
    "human_geography": {
      "subDomains": [
        "population",
        "urbanization",
        "migration",
        "cultural_regions",
        "languages",
        "religions",
        "ethnic_groups"
      ]
    },
    "political_geography": {
      "subDomains": [
        "countries",
        "capitals",
        "borders",
        "territories",
        "international_organizations",
        "geopolitics",
        "historical_boundaries"
      ]
    },
    "economic_geography": {
      "subDomains": [
        "resources",
        "trade",
        "industry",
        "agriculture",
        "transportation",
        "development",
        "tourism"
      ]
    },
    "european_geography": {
      "subDomains": [
        "eu_member_states",
        "european_rivers",
        "mountain_ranges",
        "european_cities",
        "regional_divisions",
        "eu_institutions"
      ]
    },
    "world_regions": {
      "subDomains": [
        "africa",
        "asia",
        "americas",
        "oceania",
        "middle_east",
        "polar_regions"
      ]
    },
    "cartography": {
      "subDomains": [
        "map_reading",
        "coordinates",
        "projections",
        "scale",
        "geographic_tools"
      ],
      "voiceFriendly": false
    },
    "current_geographic_events": {
      "subDomains": [
        "environmental_changes",
        "political_changes",
        "natural_events",
        "demographic_shifts"
      ],
      "yearlyUpdate": true
    }
  }
}
```

#### Regional Focus Categories (European Emphasis)

```json
{
  "europeanRegions": {
    "western_europe": {
      "countries": ["France", "Germany", "Netherlands", "Belgium", "Luxembourg", "Austria", "Switzerland"],
      "majorCities": ["Paris", "Berlin", "Amsterdam", "Brussels", "Vienna", "Zurich"],
      "features": ["Rhine River", "Alps", "Danube River"]
    },
    "southern_europe": {
      "countries": ["Italy", "Spain", "Portugal", "Greece", "Malta", "Cyprus"],
      "majorCities": ["Rome", "Madrid", "Lisbon", "Athens", "Barcelona"],
      "features": ["Mediterranean Sea", "Pyrenees", "Apennines"]
    },
    "northern_europe": {
      "countries": ["Sweden", "Norway", "Finland", "Denmark", "Iceland"],
      "majorCities": ["Stockholm", "Oslo", "Helsinki", "Copenhagen", "Reykjavik"],
      "features": ["Scandinavian Mountains", "Baltic Sea", "Norwegian Fjords"]
    },
    "eastern_europe": {
      "countries": ["Poland", "Czech Republic", "Slovakia", "Hungary", "Romania", "Bulgaria"],
      "majorCities": ["Warsaw", "Prague", "Budapest", "Bucharest", "Sofia"],
      "features": ["Carpathian Mountains", "Vistula River", "Black Sea"]
    },
    "british_isles": {
      "countries": ["United Kingdom", "Ireland"],
      "majorCities": ["London", "Dublin", "Edinburgh", "Belfast", "Cardiff"],
      "features": ["River Thames", "Scottish Highlands", "English Channel"]
    },
    "balkans": {
      "countries": ["Slovenia", "Croatia", "Serbia", "Bosnia and Herzegovina", "Montenegro", "North Macedonia", "Albania", "Kosovo"],
      "majorCities": ["Ljubljana", "Zagreb", "Belgrade", "Sarajevo"],
      "features": ["Dinaric Alps", "Adriatic Sea", "Lake Ohrid"]
    },
    "baltic_states": {
      "countries": ["Estonia", "Latvia", "Lithuania"],
      "majorCities": ["Tallinn", "Riga", "Vilnius"],
      "features": ["Baltic Sea", "Gulf of Finland"]
    }
  }
}
```

### 3. Assessment Extensions

#### Question Type Extensions

##### Pyramid Toss-Up (Primary Format)

```json
{
  "type": "pyramid",
  "questionType": "toss_up",
  "geographyBeeEU": {
    "organization": "iac_europe",
    "competitionType": "bee",
    "voiceFriendly": true,
    "clues": [
      {
        "text": "This river's delta forms the border between Romania and Ukraine.",
        "difficulty": "expert",
        "buzzWindow": "early"
      },
      {
        "text": "It flows through four European capitals: Vienna, Bratislava, Budapest, and Belgrade.",
        "difficulty": "hard",
        "buzzWindow": "optimal"
      },
      {
        "text": "Rising in Germany's Black Forest, it is Europe's second-longest river.",
        "difficulty": "medium",
        "buzzWindow": "late"
      },
      {
        "text": "Name this river that gives its name to a famous waltz by Johann Strauss II.",
        "difficulty": "giveaway",
        "buzzWindow": "final"
      }
    ],
    "answer": "Danube River",
    "alternateAnswers": ["Danube", "Donau", "Dunaj", "Duna", "Dunărea", "Dunav"],
    "pronounce": "DAN-yoob",
    "timeLimit": 10,
    "interruptible": true
  }
}
```

##### Voice-Friendly Identification Question

Questions designed specifically for voice-based learning:

```json
{
  "type": "identification",
  "geographyBeeEU": {
    "voiceFriendly": true,
    "requiresVisual": false,
    "prompt": "This landlocked European country shares borders with Germany, Poland, Slovakia, and Austria. Its capital sits on the Vltava River and is known for its astronomical clock. Name this country whose largest city is Prague.",
    "answer": "Czech Republic",
    "alternateAnswers": ["Czechia"],
    "domain": "political_geography",
    "subDomain": "countries",
    "region": "eastern_europe"
  }
}
```

##### Team Bowl Bonus

```json
{
  "type": "bonus",
  "geographyBeeEU": {
    "competitionType": "bowl",
    "voiceFriendly": true,
    "leadIn": "Answer these questions about European rivers.",
    "parts": [
      {
        "prompt": "What river flows through London?",
        "answer": "Thames",
        "alternateAnswers": ["River Thames"],
        "points": 10
      },
      {
        "prompt": "What river flows through Paris?",
        "answer": "Seine",
        "alternateAnswers": ["River Seine"],
        "points": 10
      },
      {
        "prompt": "What river flows through Rome?",
        "answer": "Tiber",
        "alternateAnswers": ["River Tiber", "Tevere"],
        "points": 10
      }
    ],
    "totalPoints": 30,
    "conferenceTime": 5
  }
}
```

##### Lightning Round (European Capitals)

```json
{
  "type": "lightning",
  "geographyBeeEU": {
    "category": "European Union Capital Cities",
    "voiceFriendly": true,
    "timeLimit": 60,
    "questions": [
      {
        "prompt": "What is the capital of Belgium?",
        "answer": "Brussels"
      },
      {
        "prompt": "What is the capital of Slovenia?",
        "answer": "Ljubljana"
      },
      {
        "prompt": "What is the capital of Estonia?",
        "answer": "Tallinn"
      },
      {
        "prompt": "What is the capital of Cyprus?",
        "answer": "Nicosia"
      },
      {
        "prompt": "What is the capital of Malta?",
        "answer": "Valletta"
      }
    ],
    "pointsPerCorrect": 10,
    "negativePoints": false
  }
}
```

### 4. Voice-Friendly Content Guidelines

Since this is for voice-based learning, content should be categorized by voice compatibility:

#### Voice Compatibility Categories

```json
{
  "voiceCompatibility": {
    "excellent": {
      "questionTypes": [
        "capital_identification",
        "country_identification",
        "river_identification",
        "landmark_identification",
        "border_questions",
        "population_facts",
        "historical_geography"
      ],
      "note": "Pure verbal questions with no visual component needed"
    },
    "good": {
      "questionTypes": [
        "relative_location",
        "geographic_features",
        "climate_descriptions",
        "regional_characteristics"
      ],
      "note": "Descriptive questions that paint a verbal picture"
    },
    "limited": {
      "questionTypes": [
        "coordinate_questions",
        "map_interpretation",
        "visual_identification",
        "direction_questions"
      ],
      "note": "Can be adapted but may lose some precision"
    },
    "not_recommended": {
      "questionTypes": [
        "map_reading",
        "flag_identification",
        "visual_comparison",
        "route_tracing"
      ],
      "note": "Requires visual component, filter for voice sessions"
    }
  }
}
```

### 5. Competition Configuration

#### IAC Europe Geography Rules

```json
{
  "competitionConfig": {
    "organization": "iac_europe",
    "format": "geography_bee",
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
      "online_fall_bee": {
        "date": "December 12, 2025"
      },
      "online_winter_bee": {
        "date": "March 6, 2026"
      },
      "international_championships": {
        "location": "Thailand",
        "date": "July 5-12, 2026"
      }
    }
  }
}
```

### 6. Performance Tracking Extensions

#### Domain Performance

```json
{
  "domainPerformance": {
    "physical_geography": { "accuracy": 0.82, "avgBuzzPoint": 0.68 },
    "human_geography": { "accuracy": 0.78, "avgBuzzPoint": 0.72 },
    "political_geography": { "accuracy": 0.90, "avgBuzzPoint": 0.55 },
    "economic_geography": { "accuracy": 0.75, "avgBuzzPoint": 0.75 },
    "european_geography": { "accuracy": 0.88, "avgBuzzPoint": 0.60 }
  }
}
```

#### Regional Knowledge Analysis

```json
{
  "regionalAnalysis": {
    "strengths": ["western_europe", "british_isles", "northern_europe"],
    "weaknesses": ["balkans", "baltic_states"],
    "recommendations": [
      "Study Balkan country capitals and borders",
      "Review Baltic state geography and features",
      "Practice lesser-known EU member state facts"
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
      "domainCoverage": "all",
      "voiceFriendlyOnly": true,
      "difficultyMix": {
        "easy": 0.3,
        "medium": 0.5,
        "hard": 0.2
      }
    },
    "european_focus": {
      "type": "focused",
      "duration": 1800,
      "targetDomain": "european_geography",
      "includeAllSubRegions": true,
      "capitalDrill": true
    },
    "buzz_practice": {
      "type": "speed",
      "duration": 1200,
      "pyramidOnly": true,
      "buzzFeedback": true,
      "voiceFriendlyOnly": true
    },
    "tournament_simulation": {
      "type": "simulation",
      "format": "iac_europe",
      "rounds": 8,
      "questionsPerRound": 10,
      "aiOpponent": true
    },
    "capital_cities_drill": {
      "type": "lightning",
      "duration": 600,
      "category": "capitals",
      "regions": ["eu_member_states", "european_non_eu", "world"],
      "progressiveDifficulty": true
    },
    "rivers_and_mountains": {
      "type": "focused",
      "duration": 1200,
      "subDomains": ["hydrology", "landforms"],
      "europeanEmphasis": true
    }
  }
}
```

## JSON Schema Fragment

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "definitions": {
    "geographyBeeEUExtension": {
      "type": "object",
      "properties": {
        "competitionYear": {
          "type": "string",
          "pattern": "^\\d{4}-\\d{4}$",
          "description": "Academic competition year"
        },
        "organization": {
          "type": "string",
          "enum": ["iac_europe", "iac_international", "national_affiliate"],
          "description": "Competition organization"
        },
        "competitionType": {
          "type": "string",
          "enum": ["bee", "bowl"],
          "description": "Individual (bee) or team (bowl) format"
        },
        "difficultyTier": {
          "type": "string",
          "enum": ["elementary", "middle_school", "jv", "varsity", "championship", "international"],
          "description": "Competition difficulty level"
        },
        "domain": {
          "type": "string",
          "enum": ["physical_geography", "human_geography", "political_geography", "economic_geography", "european_geography", "world_regions", "cartography", "current_geographic_events"],
          "description": "Geographic domain"
        },
        "subDomain": {
          "type": "string",
          "description": "Specific topic within domain"
        },
        "region": {
          "type": "string",
          "description": "Geographic focus region"
        },
        "voiceFriendly": {
          "type": "boolean",
          "default": true,
          "description": "Question works well in voice-only format"
        },
        "requiresVisual": {
          "type": "boolean",
          "default": false,
          "description": "Question requires map or image"
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
            "$ref": "#/definitions/geographyPyramidClue"
          }
        }
      },
      "required": ["competitionYear", "organization", "domain"]
    },
    "geographyPyramidClue": {
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

1. All Geography Bee EU content nodes MUST include `competitionYear`
2. All content nodes MUST include `organization` (default: iac_europe)
3. All content nodes MUST include `domain`
4. Pyramid questions MUST include at least 3 clues with decreasing difficulty
5. Bowl bonus questions MUST include exactly 3 parts

### Voice-Friendly Guidelines

1. Questions marked `voiceFriendly: true` MUST NOT require visual interpretation
2. Questions requiring maps MUST be marked `requiresVisual: true`
3. Voice-only study sessions SHOULD filter out `requiresVisual: true` questions
4. Alternate answers SHOULD include common pronunciations and spellings

### Content Guidelines

1. European Championships content SHOULD have 50%+ European geography focus
2. Pyramid clues MUST progress from hardest to easiest
3. Answers for non-English place names MUST include pronunciation guides
4. Alternate answers MUST include local language variants

## Versioning

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | January 2026 | Initial Geography Bee EU extensions |

---

*This specification extends UMCF v1.1.0 and should be read in conjunction with the base UMCF Specification, Knowledge Bowl Extensions, and History Bee EU Extensions.*
