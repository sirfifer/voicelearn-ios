# Una Mentis Curriculum Format (UMCF) Specification

**Version:** 1.1.0
**Status:** Draft
**Date:** 2026-01-03
**MIME Type:** `application/vnd.unamentis.curriculum+json`
**File Extension:** `.umcf`

---

## Table of Contents

1. [Introduction](#introduction)
2. [Design Philosophy](#design-philosophy)
3. [Quick Start](#quick-start)
4. [Document Structure](#document-structure)
5. [Content Hierarchy](#content-hierarchy)
6. [Tutoring Elements](#tutoring-elements)
7. [Assessments](#assessments)
8. [Compliance Features](#compliance-features)
9. [Extensions](#extensions)
10. [Validation](#validation)
11. [Future Considerations](#future-considerations)

---

## Introduction

The Una Mentis Curriculum Format (UMCF) is a JSON-based specification for educational curriculum designed specifically for conversational AI tutoring. Unlike traditional LMS-oriented formats (SCORM, IMS Common Cartridge), UMCF is optimized for:

- **Voice-first learning experiences** - Every text field can have a `spokenText` variant
- **Conversational AI tutoring** - Native support for transcripts, checkpoints, and branching
- **Unlimited hierarchical depth** - Topics can nest infinitely
- **Standards traceability** - Every field traces to established educational standards

### Use Cases

- Elementary education (3rd-4th grade and up)
- K-12 curricula with state standards alignment
- Higher education courses
- Corporate training and compliance
- Professional certification programs

### Goals

1. Serve as the **canonical internal format** for Una Mentis
2. Enable **import from** IMSCC, QTI, SCORM, and other standards
3. Enable **export to** established interchange formats
4. Maximize **reusability** of curriculum content

---

## Design Philosophy

### Hub-and-Spoke Model

UMCF is designed as the "hub" format:

```
                    ┌─────────────┐
                    │   IMSCC     │
                    └──────┬──────┘
                           │ import
┌─────────────┐     ┌──────▼──────┐     ┌─────────────┐
│     QTI     │────►│    UMCF      │────►│   Export    │
└─────────────┘     │   (hub)     │     │  (IMSCC)    │
                    └──────▲──────┘     └─────────────┘
                           │ import
                    ┌──────┴──────┐
                    │    H5P      │
                    └─────────────┘
```

- **Your format is the hub** - Optimized for your tutoring runtime
- **Standards are ports** - Import and export adapters connect to the ecosystem

### Tutoring-First Design

Unlike LMS formats that focus on packaging and launching content, UMCF focuses on:

- **Dialogue flow** - How the AI tutor converses with learners
- **Comprehension verification** - Checkpoints and assessments
- **Misconception handling** - Detection and remediation paths
- **Adaptive depth** - Adjusting complexity based on learner needs

### Standards Traceability

Every UMCF field traces to one or more established standards:

| Standard | What We Borrow |
|----------|----------------|
| **LOM** (IEEE 1484.12.1) | Metadata, lifecycle, educational context |
| **LRMI** (Schema.org) | Educational alignment, audience, resource types |
| **SCORM** | Hierarchical organization, sequencing |
| **xAPI** | Event verbs, extensions pattern |
| **CASE** (1EdTech) | Competency frameworks, learning objectives |
| **QTI 3.0** | Assessment items, response declarations |
| **Open Badges 3.0** | Certification, criteria, validity |
| **Dublin Core** | Core metadata (title, creator, rights) |
| **Creative Commons** | Licensing vocabulary |

---

## Quick Start

### Minimal Valid Curriculum

```json
{
  "umcf": "1.0.0",
  "id": { "catalog": "UUID", "value": "550e8400-e29b-41d4-a716-446655440000" },
  "title": "Introduction to Python",
  "version": { "number": "1.0.0" },
  "content": [
    {
      "id": { "value": "topic-1" },
      "title": "Hello World",
      "type": "topic"
    }
  ]
}
```

### With Transcript and Assessment

```json
{
  "umcf": "1.0.0",
  "id": { "catalog": "UUID", "value": "550e8400-e29b-41d4-a716-446655440000" },
  "title": "Introduction to Python",
  "version": { "number": "1.0.0" },
  "content": [
    {
      "id": { "value": "topic-1" },
      "title": "Hello World",
      "type": "topic",
      "transcript": {
        "segments": [
          {
            "id": "seg-1",
            "type": "introduction",
            "content": "Welcome! Today we're going to write your very first Python program."
          },
          {
            "id": "seg-2",
            "type": "explanation",
            "content": "In Python, we use the print function to display text on the screen."
          }
        ]
      },
      "assessments": [
        {
          "id": { "value": "q-1" },
          "type": "choice",
          "prompt": "What function displays text in Python?",
          "choices": [
            { "id": "a", "text": "print()", "correct": true },
            { "id": "b", "text": "display()", "correct": false },
            { "id": "c", "text": "show()", "correct": false }
          ]
        }
      ]
    }
  ]
}
```

---

## Document Structure

### Top-Level Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `umcf` | Yes | string | Schema version (always "1.0.0") |
| `id` | Yes | Identifier | Unique curriculum identifier |
| `title` | Yes | string | Human-readable title |
| `description` | No | string | Detailed description |
| `version` | Yes | VersionInfo | Curriculum version |
| `lifecycle` | No | Lifecycle | Status, contributors, dates |
| `metadata` | No | Metadata | Language, keywords, structure |
| `educational` | No | Educational | Audience, alignment, difficulty |
| `rights` | No | Rights | Licensing information |
| `compliance` | No | Compliance | Certification, audit requirements |
| `content` | Yes | ContentNode[] | Hierarchical content (min 1 item) |
| `glossary` | No | Glossary | Curriculum-wide terms |
| `extensions` | No | Extensions | Custom namespaced data |

### Identifier

Used throughout UMCF for stable references:

```json
{
  "catalog": "UUID",
  "value": "550e8400-e29b-41d4-a716-446655440000"
}
```

Common catalogs: `UUID`, `URI`, `ISBN`, `DOI`, `internal`

### Version Info

```json
{
  "number": "1.0.0",
  "date": "2025-12-17T00:00:00Z",
  "changelog": "Initial release"
}
```

---

## Content Hierarchy

### Content Node

The `contentNode` is the core building block. It's **recursive** - nodes can contain `children` that are also content nodes, enabling unlimited nesting depth.

```
curriculum/
├── unit/
│   ├── module/
│   │   ├── topic/
│   │   │   ├── subtopic/
│   │   │   │   └── segment/
│   │   │   └── subtopic/
│   │   └── topic/
│   └── module/
└── unit/
```

### Node Types

| Type | Description | Typical Depth |
|------|-------------|---------------|
| `curriculum` | Top-level container | 0 |
| `unit` | Major division (semester, quarter) | 1 |
| `module` | Thematic grouping | 2 |
| `topic` | Main subject area | 3 |
| `subtopic` | Subdivision of topic | 4+ |
| `lesson` | Single learning session | Any |
| `section` | Part of a lesson | Any |
| `segment` | Smallest unit (single concept) | Leaf |

### Content Node Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | Identifier | Required. Unique node ID |
| `title` | string | Required. Display title |
| `type` | string | Required. Node type (see above) |
| `orderIndex` | integer | Sequence within parent |
| `description` | string | Node description |
| `learningObjectives` | LearningObjective[] | What learner will achieve |
| `prerequisites` | Prerequisite[] | Required prior knowledge |
| `timeEstimates` | TimeEstimates | Duration by depth level |
| `transcript` | Transcript | Tutoring dialogue |
| `examples` | Example[] | Instructional examples |
| `assessments` | Assessment[] | Questions/quizzes |
| `glossaryTerms` | GlossaryTerm[] | Node-specific terms |
| `misconceptions` | Misconception[] | Common errors |
| `resources` | Resource[] | External references |
| `media` | MediaCollection | Visual assets (images, diagrams, equations) |
| `children` | ContentNode[] | Nested child nodes |
| `tutoringConfig` | TutoringConfig | AI behavior settings |
| `compliance` | NodeCompliance | Pass/fail requirements |
| `extensions` | Extensions | Custom data |

---

## Media and Visual Assets

UMCF supports rich media content that can be displayed alongside or synchronized with audio content.

### Media Collection

Each content node can include a `media` object with two categories:

```json
{
  "media": {
    "embedded": [
      {
        "id": "img-1",
        "type": "diagram",
        "url": "https://cdn.example.com/images/architecture.png",
        "localPath": "media/architecture.png",
        "title": "System Architecture",
        "alt": "Diagram showing the three-tier architecture with client, server, and database layers",
        "caption": "Figure 1: High-level system architecture",
        "mimeType": "image/png",
        "dimensions": { "width": 1200, "height": 800 },
        "segmentTiming": {
          "startSegment": 2,
          "endSegment": 5,
          "displayMode": "persistent"
        }
      }
    ],
    "reference": [
      {
        "id": "ref-1",
        "type": "slideDeck",
        "url": "https://cdn.example.com/slides/overview.pdf",
        "title": "Complete Overview Slides",
        "description": "30-slide presentation with detailed diagrams",
        "keywords": ["architecture", "deployment", "scaling"]
      }
    ]
  }
}
```

### Media Types

| Type | Description | Use Case |
|------|-------------|----------|
| `image` | Static images (PNG, JPEG, WebP) | Photos, screenshots, illustrations |
| `diagram` | Architectural/flow diagrams | System design, process flows |
| `equation` | Mathematical formulas (LaTeX) | Simple formulas, derivations |
| `formula` | Enhanced mathematical formulas | Complex formulas with semantics |
| `chart` | Data visualizations | Graphs, statistics |
| `map` | Geographic maps | History, geography, spatial content |
| `slideImage` | Single slide from a deck | Key presentation slides |
| `slideDeck` | Full presentation reference | Complete slide sets |
| `video` | Video content (MP4, WebM) | Demonstrations, animations |
| `videoLecture` | Full lecture video (streaming) | Original source lecture recordings |

### Embedded Media Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `id` | Yes | string | Unique identifier within the curriculum |
| `type` | Yes | string | Media type (see table above) |
| `url` | Yes | string | Remote URL for the asset |
| `localPath` | No | string | Relative path for bundled assets |
| `title` | No | string | Display title |
| `alt` | Yes | string | Accessibility description |
| `caption` | No | string | Caption text to display |
| `mimeType` | No | string | MIME type (e.g., "image/png") |
| `dimensions` | No | object | Width and height in pixels |
| `segmentTiming` | No | object | When to display during playback |
| `audioDescription` | No | string | Detailed verbal description for accessibility |

### Segment Timing

Controls when visuals appear during transcript playback:

```json
{
  "segmentTiming": {
    "startSegment": 2,
    "endSegment": 5,
    "displayMode": "persistent"
  }
}
```

**Display Modes:**
- `persistent` - Visual remains on screen for the entire segment range
- `highlight` - Visual appears prominently, then fades to thumbnail
- `popup` - Visual appears as dismissible overlay
- `inline` - Visual embedded directly in transcript text flow

### Reference Media Fields

Reference media are optional supplementary materials users can request:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `id` | Yes | string | Unique identifier |
| `type` | Yes | string | Media type |
| `url` | Yes | string | Remote URL |
| `title` | Yes | string | Display title |
| `description` | No | string | Description of content |
| `keywords` | No | string[] | Search keywords for matching user requests |

### Equation Format

For mathematical content, use LaTeX notation:

```json
{
  "id": "eq-1",
  "type": "equation",
  "latex": "\\sigma(x) = \\frac{1}{1 + e^{-x}}",
  "alt": "Sigmoid function: sigma of x equals one over one plus e to the negative x",
  "title": "Sigmoid Activation Function",
  "segmentTiming": {
    "startSegment": 3,
    "endSegment": 3,
    "displayMode": "highlight"
  }
}
```

### Video Lecture Format

For lecture videos from external sources (MIT OCW, Stanford, etc.):

```json
{
  "id": "vid-lecture-1",
  "type": "videoLecture",
  "url": "https://ocw.mit.edu/courses/6-001-structure-and-interpretation-of-computer-programs-spring-2005/video-lectures/lecture-1/",
  "title": "Lecture 1: Introduction to SICP",
  "description": "Professor Abelson introduces the course and discusses the nature of computer science.",
  "duration": "PT1H15M",
  "source": {
    "name": "MIT OpenCourseWare",
    "courseId": "6-001-spring-2005",
    "attribution": "Content from MIT OpenCourseWare (ocw.mit.edu), licensed under CC-BY-NC-SA 4.0."
  },
  "hasTranscript": true,
  "transcriptUrl": "https://ocw.mit.edu/courses/6-001/.../transcript.pdf"
}
```

**Video Lecture Fields:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `id` | Yes | string | Unique identifier |
| `type` | Yes | string | Must be "videoLecture" |
| `url` | Yes | string | URL to video page or stream |
| `title` | Yes | string | Lecture title |
| `description` | No | string | Lecture description |
| `duration` | No | string | ISO 8601 duration |
| `source` | No | object | Attribution and source info |
| `hasTranscript` | No | boolean | Whether transcript is available |
| `transcriptUrl` | No | string | URL to transcript if available |

Video lectures are intended for in-app playback (windowed or fullscreen) and link back to the original source for proper attribution.

### Map Format (v1.1.0)

Maps are first-class media types for geographic and historical content:

```json
{
  "id": "map-italian-city-states",
  "type": "map",
  "title": "Italian City-States in 1494",
  "alt": "Map showing major Renaissance city-states including Florence, Venice, and Milan",
  "geography": {
    "center": { "latitude": 42.5, "longitude": 12.5 },
    "zoom": 6
  },
  "mapStyle": "historical",
  "timePeriod": {
    "year": 1494,
    "era": "CE",
    "displayLabel": "Renaissance Italy, 1494"
  },
  "markers": [
    {
      "id": "marker-florence",
      "latitude": 43.7696,
      "longitude": 11.2558,
      "label": "Florence",
      "description": "Center of the Renaissance, ruled by the Medici family",
      "markerType": "city",
      "color": "#D4AF37"
    }
  ],
  "routes": [
    {
      "id": "route-trade",
      "label": "Trade Route",
      "points": [
        { "latitude": 45.44, "longitude": 12.31 },
        { "latitude": 43.77, "longitude": 11.26 }
      ],
      "color": "#8B4513",
      "style": "dashed"
    }
  ],
  "regions": [
    {
      "id": "region-florence",
      "label": "Republic of Florence",
      "fillColor": "#FFD700",
      "opacity": 0.3
    }
  ],
  "interactive": true,
  "fallbackImageUrl": "media/maps/italian-city-states.png",
  "segmentTiming": {
    "startSegment": "seg-city-states",
    "displayMode": "persistent"
  }
}
```

**Map-Specific Fields:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `geography` | Yes | object | Center coordinates and zoom level |
| `mapStyle` | No | string | Visual style: political, historical, satellite, terrain |
| `timePeriod` | No | object | Historical period for the map |
| `markers` | No | array | Points of interest with labels |
| `routes` | No | array | Paths/routes to display |
| `regions` | No | array | Highlighted geographic areas |
| `interactive` | No | boolean | Enable pan/zoom interaction (default: false) |
| `fallbackImageUrl` | No | string | Static image for non-interactive display |

### Diagram with Source Code (v1.1.0)

Diagrams can include source code for server-side generation:

```json
{
  "id": "diag-neural-network",
  "type": "diagram",
  "title": "Multi-Layer Perceptron Architecture",
  "alt": "Diagram showing input, hidden, and output layers",
  "diagramSubtype": "architecture",
  "sourceCode": {
    "format": "mermaid",
    "code": "graph LR\n  I1((x₁)) --> H1((h₁))\n  I1 --> H2((h₂))\n  H1 --> O1((y))\n  H2 --> O1",
    "version": "10.6.0"
  },
  "url": "media/diagrams/mlp-architecture.svg",
  "mimeType": "image/svg+xml",
  "generationSource": "ai_generated",
  "generationMetadata": {
    "model": "claude-opus-4-5",
    "humanReviewed": true
  }
}
```

**Diagram Source Code Fields:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `diagramSubtype` | No | string | Type: flowchart, sequence, class, architecture, mindmap |
| `sourceCode.format` | Yes | string | Diagram language: mermaid, graphviz, plantuml |
| `sourceCode.code` | Yes | string | The diagram source code |
| `generationSource` | No | string | How created: ai_generated, author_provided |
| `generationMetadata` | No | object | AI generation details |

**Supported Diagram Formats:**
- `mermaid` - Flowcharts, sequence diagrams, class diagrams, state diagrams
- `graphviz` - DOT language for graphs and trees
- `plantuml` - UML diagrams
- `d2` - Modern declarative diagramming

### Enhanced Formula Format (v1.1.0)

The `formula` type extends `equation` with semantic meaning and accessibility:

```json
{
  "id": "eq-quadratic",
  "type": "formula",
  "latex": "x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}",
  "alt": "x equals negative b plus or minus the square root of b squared minus 4ac, all over 2a",
  "displayMode": "block",
  "semanticMeaning": {
    "category": "algebraic",
    "commonName": "Quadratic Formula",
    "purpose": "Finds the roots of a quadratic equation ax² + bx + c = 0",
    "variables": [
      { "symbol": "x", "meaning": "solutions (roots) of the equation" },
      { "symbol": "a", "meaning": "coefficient of x²" },
      { "symbol": "b", "meaning": "coefficient of x" },
      { "symbol": "c", "meaning": "constant term" }
    ],
    "spokenForm": "x equals negative b, plus or minus the square root of b squared minus four a c, all divided by two a"
  },
  "fallbackImageUrl": "media/formulas/quadratic.png"
}
```

**Formula-Specific Fields:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `displayMode` | No | string | inline, block, or display |
| `semanticMeaning` | No | object | Semantic interpretation |
| `semanticMeaning.category` | No | string | Math category: algebraic, calculus, etc. |
| `semanticMeaning.commonName` | No | string | Well-known name for the formula |
| `semanticMeaning.variables` | No | array | Variable descriptions |
| `semanticMeaning.spokenForm` | No | string | TTS-optimized verbal form |
| `fallbackImageUrl` | No | string | Pre-rendered image for fallback |

### Accessibility Requirements

All visual content MUST include:
1. `alt` text describing the visual for screen readers
2. Consider providing `audioDescription` for complex diagrams
3. Equations should have verbal descriptions in `alt`

---

## Tutoring Elements

These elements are unique to UMCF, designed for conversational AI tutoring.

### Transcript

A structured dialogue for the AI tutor:

```json
{
  "transcript": {
    "segments": [
      {
        "id": "seg-1",
        "type": "introduction",
        "content": "Let's explore how neural networks learn...",
        "speakingNotes": {
          "pace": "slow",
          "emotionalTone": "encouraging"
        },
        "checkpoint": {
          "type": "simple_confirmation",
          "prompt": "Does that make sense so far?",
          "fallbackBehavior": "simplify"
        }
      }
    ],
    "voiceProfile": {
      "tone": "conversational",
      "pace": "moderate"
    }
  }
}
```

### Segment Types

| Type | Purpose |
|------|---------|
| `introduction` | Opening/context setting |
| `lecture` | Main content delivery |
| `explanation` | Concept clarification |
| `example` | Illustrative example |
| `checkpoint` | Verification point |
| `transition` | Moving between topics |
| `summary` | Recap of key points |
| `conclusion` | Closing/next steps |

### Speaking Notes

TTS delivery instructions:

```json
{
  "speakingNotes": {
    "pace": "slow",
    "emphasis": ["neural networks", "backpropagation"],
    "pauseAfter": true,
    "pauseDuration": 2,
    "emotionalTone": "curious"
  }
}
```

### Checkpoints

Interactive verification:

```json
{
  "checkpoint": {
    "type": "comprehension_check",
    "prompt": "Can you explain what a gradient is in your own words?",
    "expectedResponsePatterns": ["slope", "direction", "rate of change"],
    "fallbackBehavior": "simplify",
    "transitions": {
      "understood": {
        "nextSegment": "seg-advanced",
        "feedbackText": "Excellent! Let's dive deeper."
      },
      "confused": {
        "nextSegment": "seg-review",
        "feedbackText": "No problem, let me explain it differently."
      }
    }
  }
}
```

### Alternative Explanations

For rephrasing the same concept:

```json
{
  "alternativeExplanations": [
    {
      "style": "simpler",
      "content": "Think of it like a recipe - each step depends on the one before."
    },
    {
      "style": "analogy",
      "content": "It's like teaching a child to ride a bike - you adjust based on their wobbles."
    }
  ]
}
```

### Misconceptions

Detect and correct common errors:

```json
{
  "misconceptions": [
    {
      "id": "misc-1",
      "misconception": "Neural networks work exactly like human brains",
      "triggerPhrases": ["just like a brain", "same as neurons"],
      "correction": "While inspired by biology, artificial neural networks are mathematical models that work quite differently.",
      "severity": "moderate",
      "remediationPath": {
        "reviewTopics": ["topic-biology-vs-ai"],
        "additionalExamples": ["ex-comparison"]
      }
    }
  ]
}
```

### Time Estimates

Duration by content depth:

```json
{
  "timeEstimates": {
    "overview": "PT5M",
    "introductory": "PT15M",
    "intermediate": "PT30M",
    "advanced": "PT45M",
    "graduate": "PT1H30M",
    "research": "PT2H"
  }
}
```

### Tutoring Configuration

AI behavior settings:

```json
{
  "tutoringConfig": {
    "contentDepth": "intermediate",
    "adaptiveDepth": true,
    "interactionMode": "socratic",
    "allowTangents": false,
    "checkpointFrequency": "medium",
    "escalationThreshold": 0.7
  }
}
```

---

## Assessments

UMCF v1.0 supports basic assessment types:

### Assessment Types

| Type | Description |
|------|-------------|
| `choice` | Single correct answer |
| `multiple_choice` | Multiple correct answers |
| `text_entry` | Short text response |
| `true_false` | Boolean response |

### Assessment Structure

```json
{
  "id": { "value": "assess-1" },
  "type": "choice",
  "title": "Understanding Variables",
  "prompt": "What is the correct way to assign a value to a variable in Python?",
  "spokenPrompt": "What's the correct way to assign a value to a variable in Python?",
  "choices": [
    { "id": "a", "text": "x = 5", "correct": true, "feedback": "Correct! The equals sign assigns values." },
    { "id": "b", "text": "x == 5", "correct": false, "feedback": "That's a comparison, not an assignment." },
    { "id": "c", "text": "x := 5", "correct": false, "feedback": "Python doesn't use := for assignment." }
  ],
  "scoring": {
    "maxScore": 1,
    "passingScore": 1
  },
  "feedback": {
    "correct": {
      "text": "Great job!",
      "spokenText": "That's right! Great job understanding variable assignment."
    },
    "incorrect": {
      "text": "Not quite. Let's review.",
      "hint": "Remember, we use a single equals sign for assignment."
    }
  },
  "difficulty": 0.3,
  "attempts": 2
}
```

---

## Compliance Features

For corporate training and certification:

### Certification

```json
{
  "compliance": {
    "certification": {
      "id": { "value": "cert-security-101" },
      "name": "Security Awareness Certificate",
      "description": "Demonstrates completion of security awareness training",
      "criteria": {
        "narrative": "Complete all modules and pass final assessment with 80%+",
        "passingScore": 80,
        "requiredAssessments": ["final-exam"],
        "minimumTimeSpent": "PT2H"
      },
      "validityPeriod": "P1Y",
      "issuer": {
        "name": "ACME Corp Training",
        "url": "https://training.acme.com"
      }
    }
  }
}
```

### Regulatory Frameworks

```json
{
  "regulatoryFrameworks": [
    {
      "name": "SOC2",
      "version": "2017",
      "url": "https://www.aicpa.org/soc2"
    },
    {
      "name": "HIPAA",
      "url": "https://www.hhs.gov/hipaa"
    }
  ]
}
```

### Audit Requirements

```json
{
  "auditRequirements": {
    "enabled": true,
    "retentionPeriod": "P7Y",
    "requiredEvents": ["started", "completed", "passed", "failed", "answered"],
    "dataFields": ["timestamp", "user_id", "session_id", "duration", "score"],
    "signatureRequired": true,
    "supervisorApproval": false
  }
}
```

### Renewal Policy

```json
{
  "renewalPolicy": {
    "required": true,
    "renewalPeriod": "P1Y",
    "renewalOptions": [
      {
        "type": "abbreviated",
        "description": "1-hour refresher course",
        "requirements": "Complete refresher and pass assessment"
      },
      {
        "type": "assessment_only",
        "description": "Assessment-only renewal",
        "requirements": "Pass comprehensive assessment with 90%+"
      }
    ],
    "gracePeriod": "P30D",
    "notificationSchedule": ["P30D", "P7D", "P1D"]
  }
}
```

### Node-Level Compliance

```json
{
  "compliance": {
    "mandatory": true,
    "passingCriteria": {
      "minimumScore": 80,
      "minimumTime": "PT30M",
      "allObjectivesRequired": true
    },
    "trackingLevel": "detailed"
  }
}
```

---

## Extensions

UMCF uses namespaced extensions (inspired by xAPI) for custom data:

```json
{
  "extensions": {
    "https://unamentis.com/extensions/analytics": {
      "trackingId": "UA-123456",
      "experimentGroup": "A"
    },
    "https://mycompany.com/extensions/hr": {
      "departmentCode": "ENG-001",
      "requiredByDate": "2025-03-01"
    }
  }
}
```

### Extension Guidelines

1. Use URI-based namespaces
2. Document your extension schema
3. Extensions should not duplicate core fields
4. Extensions are optional - core functionality shouldn't depend on them

---

## Validation

### JSON Schema

UMCF uses JSON Schema Draft 2020-12 for validation. The schema is available at:

```
https://unamentis.com/schemas/umcf/v1.0.0/curriculum.json
```

### Validating a File

```bash
# Using ajv-cli
ajv validate -s umcf-schema.json -d my-curriculum.umcf

# Using Python jsonschema
python -c "
import json
from jsonschema import validate
schema = json.load(open('umcf-schema.json'))
data = json.load(open('my-curriculum.umcf'))
validate(data, schema)
print('Valid!')
"
```

### Common Validation Errors

1. **Missing required fields**: `umcf`, `id`, `title`, `version`, `content`
2. **Invalid duration format**: Must be ISO 8601 (e.g., `PT30M`, not `30 minutes`)
3. **Invalid node type**: Must be one of the defined types
4. **Empty content array**: At least one content node required

---

## Future Considerations

These features are designed into the schema but not fully implemented in v1.0:

### Multi-Language Support (i18n)

The schema is designed to support locale-keyed text fields in future versions:

```json
{
  "title": {
    "en": "Introduction to Python",
    "es": "Introducción a Python",
    "zh-Hans": "Python入门"
  }
}
```

### Advanced Assessment Types

Future versions may support:
- Matching
- Ordering/sequencing
- Fill-in-blank
- Graphical/hotspot
- Drag-and-drop

### Enhanced Media Features

Future versions may support:
- Base64 embedded assets for fully offline content
- Video clips and animated diagrams
- Interactive 3D models
- Collaborative annotations on visuals

### Import/Export Adapters

Planned adapters:
- IMS Common Cartridge (IMSCC)
- QTI 3.0
- H5P
- Open edX OLX
- SCORM 2004

---

## References

- [IEEE LOM 1484.12.1-2020](https://standards.ieee.org/standard/1484_12_1-2020.html)
- [LRMI (Dublin Core)](https://www.dublincore.org/specifications/lrmi/)
- [SCORM 2004](https://scorm.com/scorm-explained/)
- [xAPI (Experience API)](https://xapi.com/overview/)
- [CASE 1.0 (1EdTech)](https://www.imsglobal.org/spec/case/v1p0)
- [QTI 3.0](https://www.imsglobal.org/spec/qti/v3p0)
- [Open Badges 3.0](https://www.imsglobal.org/spec/ob/v3p0)
- [Dublin Core Metadata Terms](https://www.dublincore.org/specifications/dublin-core/dcmi-terms/)
- [JSON Schema](https://json-schema.org/)

---

## License

This specification is released under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
