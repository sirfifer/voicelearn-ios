# UMCF (Una Mentis Curriculum Format) Specification

**Version**: 1.1.0
**MIME Type**: `application/vnd.unamentis.curriculum+json`
**File Extension**: `.umcf`

---

## Overview

UMCF is a JSON-based specification for educational curriculum optimized for conversational AI tutoring. It's voice-native, standards-grounded, and designed for unlimited hierarchical depth.

---

## Document Structure

```json
{
  "formatIdentifier": "umcf",
  "schemaVersion": "1.1.0",
  "id": {
    "catalog": "unamentis",
    "value": "curriculum-uuid"
  },
  "title": "Introduction to Biology",
  "description": "A comprehensive introduction to biological sciences",
  "version": {
    "number": "1.0.0",
    "date": "2024-01-15",
    "changelog": "Initial release"
  },
  "lifecycle": {
    "status": "published",
    "contributors": [...],
    "dates": {...}
  },
  "metadata": {
    "language": "en",
    "keywords": ["biology", "science"]
  },
  "educational": {
    "audience": {...},
    "alignment": [...],
    "difficulty": "intermediate"
  },
  "rights": {
    "license": "CC-BY-4.0",
    "attribution": "..."
  },
  "content": [...],
  "glossary": {...},
  "extensions": {}
}
```

---

## Content Hierarchy

### Node Types

Content nodes can be nested to unlimited depth:

| Type | Purpose | Typical Contains |
|------|---------|------------------|
| `curriculum` | Root container | units |
| `unit` | Major section (semester) | modules |
| `module` | Thematic grouping | topics |
| `topic` | Main subject | subtopics, lessons |
| `subtopic` | Subdivision | lessons, sections |
| `lesson` | Single session | sections, segments |
| `section` | Part of lesson | segments |
| `segment` | Smallest unit | content only |

### ContentNode Schema

```json
{
  "id": {
    "catalog": "string",
    "value": "string"
  },
  "title": "Node Title",
  "type": "topic",
  "orderIndex": 0,
  "description": "Description text",
  "learningObjectives": [...],
  "prerequisites": [...],
  "timeEstimates": {...},
  "transcript": {...},
  "examples": [...],
  "assessments": [...],
  "glossaryTerms": [...],
  "misconceptions": [...],
  "resources": [...],
  "media": {...},
  "children": [...],
  "tutoringConfig": {...},
  "extensions": {}
}
```

---

## Transcript

The transcript contains the speakable content for AI tutoring.

### Structure

```json
{
  "transcript": {
    "segments": [
      {
        "id": "seg-1",
        "type": "introduction",
        "content": "Welcome to today's lesson on cell structure...",
        "speakingNotes": {
          "pace": "normal",
          "emphasis": ["cell", "structure"],
          "pauseAfter": true,
          "pauseDuration": 2,
          "emotionalTone": "encouraging"
        },
        "checkpoint": {...},
        "stoppingPoint": {...},
        "glossaryRefs": ["mitochondria", "nucleus"],
        "alternativeExplanations": [...],
        "estimatedDuration": "PT2M30S"
      }
    ],
    "totalDuration": "PT45M",
    "pronunciationGuide": {
      "mitochondria": {
        "ipa": "/maɪtəˈkɑːndriə/",
        "respelling": "my-tuh-KON-dree-uh",
        "language": "en"
      }
    },
    "voiceProfile": {
      "tone": "conversational",
      "pace": "moderate",
      "accent": "neutral"
    }
  }
}
```

### Segment Types

| Type | Purpose |
|------|---------|
| `introduction` | Opening segment |
| `lecture` | Main content delivery |
| `explanation` | Detailed explanation |
| `example` | Example walkthrough |
| `checkpoint` | Comprehension check |
| `transition` | Between topics |
| `summary` | Recap content |
| `conclusion` | Closing segment |

### Speaking Notes

```json
{
  "speakingNotes": {
    "pace": "slow",           // very slow, slow, normal, fast
    "emphasis": ["key", "words"],
    "pauseAfter": true,
    "pauseDuration": 2,       // seconds
    "emotionalTone": "serious" // neutral, encouraging, serious, curious, excited
  }
}
```

### Checkpoints

```json
{
  "checkpoint": {
    "type": "comprehension_check",
    "prompt": "Does that make sense so far?",
    "expectedResponses": ["yes", "i think so"],
    "fallbackResponse": "Let me explain that differently..."
  }
}
```

**Checkpoint Types:**
- `simple_confirmation` - Quick acknowledgment
- `comprehension_check` - Verify understanding
- `knowledge_check` - Test recall
- `application_check` - Apply knowledge
- `teachback` - Explain in own words

---

## Media Assets

### Media Collection

```json
{
  "media": {
    "embedded": [
      {
        "id": "img-cell",
        "type": "image",
        "url": "https://...",
        "localPath": "media/cell-diagram.png",
        "title": "Cell Diagram",
        "alt": "Diagram showing the parts of an animal cell",
        "caption": "A typical animal cell",
        "mimeType": "image/png",
        "dimensions": { "width": 1200, "height": 800 },
        "segmentTiming": {
          "startSegment": "seg-3",
          "endSegment": "seg-5",
          "displayMode": "persistent"
        }
      }
    ],
    "reference": [
      {
        "id": "ref-textbook",
        "type": "link",
        "url": "https://...",
        "title": "Textbook Chapter 3",
        "description": "Further reading"
      }
    ]
  }
}
```

### Media Types

| Type | Purpose | Properties |
|------|---------|------------|
| `image` | Static images | url, dimensions |
| `diagram` | Flow/architecture diagrams | sourceCode, format |
| `equation` | Simple LaTeX | latex |
| `formula` | Enhanced formulas | latex, semanticMeaning |
| `chart` | Data visualizations | chartData, chartType |
| `map` | Geographic maps | geography, markers, routes |
| `slideImage` | Single slide | url |
| `slideDeck` | Full presentation | url |
| `video` | Video content | url, duration |
| `videoLecture` | External lecture | url, source |

### Formula Format

```json
{
  "id": "eq-quadratic",
  "type": "formula",
  "latex": "x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}",
  "alt": "x equals negative b plus or minus the square root of b squared minus 4ac, all divided by 2a",
  "displayMode": "block",
  "semanticMeaning": {
    "category": "algebraic",
    "commonName": "Quadratic Formula",
    "purpose": "Finds the roots of a quadratic equation",
    "variables": [
      { "symbol": "x", "meaning": "solution values", "unit": null },
      { "symbol": "a", "meaning": "coefficient of x²", "unit": null },
      { "symbol": "b", "meaning": "coefficient of x", "unit": null },
      { "symbol": "c", "meaning": "constant term", "unit": null }
    ],
    "spokenForm": "x equals the quantity negative b, plus or minus the square root of b squared minus 4 a c, all divided by 2 a"
  },
  "fallbackImageUrl": "media/formulas/quadratic.png"
}
```

### Map Format

```json
{
  "id": "map-renaissance",
  "type": "map",
  "title": "Italian City-States in 1494",
  "alt": "Map of Italy showing major city-states",
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
      "latitude": 43.77,
      "longitude": 11.26,
      "label": "Florence",
      "description": "Center of the Renaissance",
      "markerType": "city",
      "color": "#E74C3C"
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
      "color": "#3498DB",
      "style": "dashed"
    }
  ],
  "regions": [
    {
      "id": "region-florence",
      "label": "Republic of Florence",
      "geoJsonUrl": "regions/florence.geojson",
      "fillColor": "#27AE60",
      "opacity": 0.3
    }
  ],
  "interactive": true,
  "fallbackImageUrl": "media/maps/italy-1494.png"
}
```

### Diagram Format

```json
{
  "id": "diag-neural",
  "type": "diagram",
  "title": "Neural Network Architecture",
  "alt": "Diagram of a multilayer perceptron",
  "diagramSubtype": "architecture",
  "sourceCode": {
    "format": "mermaid",
    "code": "graph LR\n  A[Input] --> B[Hidden]\n  B --> C[Output]",
    "version": "10.6.0"
  },
  "url": "media/diagrams/neural-network.svg",
  "generationSource": "author_provided"
}
```

### Segment Timing

Controls when visuals appear during playback:

```json
{
  "segmentTiming": {
    "startSegment": "seg-3",
    "endSegment": "seg-5",
    "displayMode": "persistent"
  }
}
```

**Display Modes:**
- `persistent` - Stays visible for segment range
- `highlight` - Appears prominently, fades to thumbnail
- `popup` - Dismissible overlay
- `inline` - Embedded in transcript flow

---

## Learning Objectives

```json
{
  "learningObjectives": [
    {
      "id": { "catalog": "local", "value": "obj-1" },
      "statement": "Students will be able to identify the major organelles of a cell",
      "abbreviatedStatement": "Identify cell organelles",
      "bloomsLevel": "understand",
      "educationalAlignment": [
        {
          "alignmentType": "teaches",
          "educationalFramework": "NGSS",
          "targetName": "LS1.A",
          "targetDescription": "Structure and Function"
        }
      ],
      "verificationCriteria": "Can correctly label 80% of organelles",
      "assessmentIds": ["q-1", "q-2"]
    }
  ]
}
```

**Bloom's Levels:**
- `remember`
- `understand`
- `apply`
- `analyze`
- `evaluate`
- `create`

---

## Assessments

```json
{
  "assessments": [
    {
      "id": { "catalog": "local", "value": "q-1" },
      "type": "choice",
      "title": "Cell Organelles",
      "prompt": "Which organelle is called the powerhouse of the cell?",
      "spokenPrompt": "Which organelle is known as the powerhouse of the cell?",
      "choices": [
        {
          "id": "a",
          "text": "Nucleus",
          "spokenText": "The nucleus",
          "correct": false,
          "feedback": "The nucleus contains DNA but doesn't produce energy."
        },
        {
          "id": "b",
          "text": "Mitochondria",
          "spokenText": "The mitochondria",
          "correct": true,
          "feedback": "Correct! Mitochondria produce ATP, the cell's energy currency."
        }
      ],
      "correctResponse": ["b"],
      "scoring": {
        "maxScore": 1,
        "passingScore": 1,
        "partialCredit": false
      },
      "feedback": {
        "correct": {
          "text": "Excellent!",
          "spokenText": "Excellent! That's right."
        },
        "incorrect": {
          "text": "Not quite.",
          "spokenText": "Not quite. Let me explain.",
          "hint": "Think about where energy is produced."
        }
      },
      "hints": [
        { "text": "It's an organelle that produces ATP." }
      ],
      "difficulty": 0.3,
      "objectivesAssessed": ["obj-1"]
    }
  ]
}
```

**Assessment Types:**
- `choice` - Single choice
- `multiple_choice` - Multiple choices
- `text_entry` - Free text
- `true_false` - Binary choice

---

## Glossary

```json
{
  "glossary": {
    "terms": [
      {
        "id": "term-mitochondria",
        "term": "Mitochondria",
        "pronunciation": "/maɪtəˈkɑːndriə/",
        "definition": "Membrane-bound organelles found in the cytoplasm of eukaryotic cells that generate most of the cell's supply of ATP.",
        "spokenDefinition": "Mitochondria are small structures inside cells that produce energy. They're often called the powerhouse of the cell.",
        "simpleDefinition": "The part of a cell that makes energy.",
        "synonyms": ["powerhouse of the cell"],
        "relatedTerms": ["ATP", "cellular respiration"],
        "etymology": "From Greek mitos (thread) + chondrion (granule)"
      }
    ]
  }
}
```

---

## Misconceptions

```json
{
  "misconceptions": [
    {
      "id": "misc-1",
      "misconception": "All cells have a nucleus",
      "triggerPhrases": [
        "all cells have nucleus",
        "every cell has a nucleus"
      ],
      "correction": "Not all cells have a nucleus. Prokaryotic cells, like bacteria, lack a membrane-bound nucleus.",
      "spokenCorrection": "Actually, that's a common misconception. Not all cells have a nucleus. Bacteria and other prokaryotes don't have a membrane-bound nucleus.",
      "explanation": "Students often generalize from animal and plant cells they learn about first.",
      "remediationPath": {
        "reviewTopics": ["cell-types"],
        "additionalExamples": ["ex-bacteria"],
        "suggestedTranscriptSegments": ["seg-prokaryotes"]
      },
      "severity": "moderate"
    }
  ]
}
```

---

## Time Estimates

All durations use ISO 8601 format:

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

---

## Tutoring Configuration

```json
{
  "tutoringConfig": {
    "contentDepth": "intermediate",
    "adaptiveDepth": true,
    "systemPromptOverride": "Focus on visual explanations for this topic.",
    "interactionMode": "socratic",
    "allowTangents": false,
    "checkpointFrequency": "medium",
    "escalationThreshold": 0.7
  }
}
```

**Interaction Modes:**
- `lecture` - Teacher-led explanation
- `socratic` - Question-based discovery
- `practice` - Problem-solving focus
- `assessment` - Testing mode
- `freeform` - Open conversation

**Checkpoint Frequency:**
- `never`
- `low`
- `medium`
- `high`
- `every_segment`

---

## Parsing UMCF

### TypeScript Types

```typescript
interface UMCFDocument {
  formatIdentifier: 'umcf';
  schemaVersion: string;
  id: CatalogId;
  title: string;
  description?: string;
  version: Version;
  lifecycle?: Lifecycle;
  metadata?: Metadata;
  educational?: Educational;
  rights?: Rights;
  content: ContentNode[];
  glossary?: Glossary;
  extensions?: Extensions;
}

interface ContentNode {
  id: CatalogId;
  title: string;
  type: NodeType;
  orderIndex?: number;
  description?: string;
  learningObjectives?: LearningObjective[];
  transcript?: Transcript;
  media?: MediaCollection;
  children?: ContentNode[];
  // ... other properties
}

interface MediaAsset {
  id: string;
  type: MediaType;
  url?: string;
  localPath?: string;
  title?: string;
  alt: string;  // Required for accessibility
  segmentTiming?: SegmentTiming;
  // Type-specific properties
}

type MediaType =
  | 'image'
  | 'diagram'
  | 'equation'
  | 'formula'
  | 'chart'
  | 'map'
  | 'slideImage'
  | 'slideDeck'
  | 'video'
  | 'videoLecture';

type NodeType =
  | 'curriculum'
  | 'unit'
  | 'module'
  | 'topic'
  | 'subtopic'
  | 'lesson'
  | 'section'
  | 'segment';
```

### Parsing Example

```typescript
async function parseUMCF(json: string): Promise<UMCFDocument> {
  const doc = JSON.parse(json);

  // Validate required fields
  if (doc.formatIdentifier !== 'umcf') {
    throw new Error('Invalid UMCF document');
  }

  // Recursively process content nodes
  function processNode(node: ContentNode): ContentNode {
    return {
      ...node,
      children: node.children?.map(processNode),
    };
  }

  return {
    ...doc,
    content: doc.content.map(processNode),
  };
}

// Extract visual assets with segment timing
function extractVisualAssets(doc: UMCFDocument): VisualAsset[] {
  const assets: VisualAsset[] = [];

  function walkNode(node: ContentNode) {
    if (node.media?.embedded) {
      assets.push(...node.media.embedded);
    }
    node.children?.forEach(walkNode);
  }

  doc.content.forEach(walkNode);
  return assets;
}
```

---

## Rendering Visual Assets

### Formula (KaTeX)

```typescript
import katex from 'katex';

function renderFormula(asset: FormulaAsset): string {
  return katex.renderToString(asset.latex, {
    displayMode: asset.displayMode === 'block',
    throwOnError: false,
  });
}
```

### Map (Leaflet)

```typescript
import L from 'leaflet';

function renderMap(container: HTMLElement, asset: MapAsset) {
  const map = L.map(container).setView(
    [asset.geography.center.latitude, asset.geography.center.longitude],
    asset.geography.zoom
  );

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);

  asset.markers?.forEach(marker => {
    L.marker([marker.latitude, marker.longitude])
      .bindPopup(`<b>${marker.label}</b><br>${marker.description}`)
      .addTo(map);
  });

  asset.routes?.forEach(route => {
    L.polyline(
      route.points.map(p => [p.latitude, p.longitude]),
      { color: route.color }
    ).addTo(map);
  });
}
```

### Diagram (Mermaid)

```typescript
import mermaid from 'mermaid';

async function renderDiagram(container: HTMLElement, asset: DiagramAsset) {
  if (asset.sourceCode?.format === 'mermaid') {
    mermaid.initialize({ startOnLoad: false });
    const { svg } = await mermaid.render('diagram', asset.sourceCode.code);
    container.innerHTML = svg;
  } else if (asset.url) {
    container.innerHTML = `<img src="${asset.url}" alt="${asset.alt}" />`;
  }
}
```

---

## Standards Alignment

UMCF aligns with educational standards:

| Standard | What We Use |
|----------|-------------|
| IEEE LOM | Metadata structure |
| LRMI | Educational properties |
| SCORM | Sequencing concepts |
| xAPI | Event patterns |
| CASE | Competency frameworks |
| QTI 3.0 | Assessment format |
| Dublin Core | Core metadata |

---

*End of UMCF Specification*
