# Knowledge Bowl Module Specification

## Executive Summary

The Knowledge Bowl Module is a specialized learning system designed to prepare students for academic quiz bowl competitions. Unlike traditional reinforcement-based tutoring, this module provides directed, adaptive studying across the full spectrum of Knowledge Bowl subjects with real-time content updates to reflect yearly competition changes.

**Key Differentiators:**
- Multi-subject mastery tracking across 12+ academic domains
- Speed-based recall training with sub-3-second response targets
- Dynamic content pipeline that incorporates yearly topic updates
- Competition simulation with realistic buzzer mechanics
- Weakness identification with targeted remediation paths
- Team coordination training for collaborative answering

### Voice-First Requirement

**CRITICAL**: As part of UnaMentis, this module MUST be voice-first while maintaining full multimodal support. This means:

1. **Automatic Voice Output**: All questions are automatically read aloud via TTS when presented, mimicking a real competition moderator
2. **Always-Listening Input**: Voice recognition is always active during practice sessions; users can answer verbally without any special interaction
3. **Verbal Feedback**: Correct/incorrect feedback and explanations are spoken aloud
4. **Simultaneous Multimodality**: Visual UI and voice work in parallel; users see AND hear questions, can type OR speak answers
5. **No Toggle Required**: Voice is the default, not an opt-in feature

**Competition Authenticity (Future Enhancement):**
- Adjust TTS cadence and pacing to match real KB moderator delivery
- Add appropriate dramatic pauses before revealing answers
- Consider different vocal energy levels for different question difficulties
- Potential for multiple "moderator voices" to match regional competition styles

## Table of Contents

1. [Understanding Knowledge Bowl](#understanding-knowledge-bowl)
2. [Module Architecture](#module-architecture)
3. [Subject Domain Coverage](#subject-domain-coverage)
4. [Directed Study System](#directed-study-system)
5. [Dynamic Content Pipeline](#dynamic-content-pipeline)
6. [Assessment and Reinforcement](#assessment-and-reinforcement)
7. [Competition Simulation](#competition-simulation)
8. [Progress Analytics](#progress-analytics)
9. [UMCF Integration](#umcf-integration)
10. [Implementation Roadmap](#implementation-roadmap)

---

## Understanding Knowledge Bowl

### What is Knowledge Bowl?

Knowledge Bowl is an academic competition where teams of students answer questions across a broad range of subjects. Unlike single-subject competitions, Knowledge Bowl requires:

- **Breadth over Depth**: Coverage of 12+ subject areas
- **Speed**: Quick recall with buzzer-based answering
- **Team Coordination**: Strategic collaboration on answers
- **Current Awareness**: Topics include current events and recent developments
- **Format Familiarity**: Understanding of question types and scoring rules

### Competition Format

| Element | Description |
|---------|-------------|
| Team Size | 3-5 students |
| Question Types | Toss-up (individual), Bonus (team) |
| Subjects | Science, Math, Literature, History, Arts, Current Events, etc. |
| Timing | 10-15 second response window |
| Scoring | Points vary by difficulty (10/20/30) |
| Rounds | Written round + oral rounds |

### Why Traditional Tutoring Falls Short

Standard tutoring approaches fail Knowledge Bowl preparation because they:

1. Focus on deep understanding of single subjects rather than broad recall
2. Lack speed pressure that mirrors competition conditions
3. Cannot adapt to yearly topic changes and current events
4. Do not simulate team dynamics and strategic answering
5. Provide generic reinforcement rather than targeted weakness remediation

---

## Module Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────────┐
│                    Knowledge Bowl Module                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   Content    │  │   Study      │  │    Competition       │  │
│  │   Engine     │  │   Director   │  │    Simulator         │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
│         │                 │                      │              │
│         ▼                 ▼                      ▼              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Adaptive Learning Core                       │  │
│  │  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐  │  │
│  │  │ Mastery │  │ Spaced   │  │ Weakness │  │ Speed     │  │  │
│  │  │ Tracker │  │ Retrieval│  │ Analyzer │  │ Trainer   │  │  │
│  │  └─────────┘  └──────────┘  └──────────┘  └───────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              UMCF Curriculum Layer                        │  │
│  │  12+ Subject Domains × 6 Depth Levels × Dynamic Updates  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Core Components

#### 1. Content Engine
Manages the multi-subject question bank and content organization:
- Subject taxonomy with hierarchical topics
- Question difficulty classification
- Source attribution and verification
- Annual update integration

#### 2. Study Director
Orchestrates personalized study sessions:
- Analyzes performance across all subjects
- Prioritizes weak areas with smart scheduling
- Balances breadth maintenance with depth improvement
- Adapts to time constraints and competition dates

#### 3. Competition Simulator
Provides realistic practice environments:
- Timed question delivery with buzzer mechanics
- Team mode with role assignments
- Score tracking with statistical analysis
- Post-round review and analysis

#### 4. Adaptive Learning Core
Powers the intelligent tutoring capabilities:
- **Mastery Tracker**: Per-subject and per-topic proficiency
- **Spaced Retrieval**: Optimized review scheduling
- **Weakness Analyzer**: Pattern detection in errors
- **Speed Trainer**: Progressive response time reduction

---

## Subject Domain Coverage

### Primary Domains (12 Categories)

| Domain | Subcategories | Question Weight |
|--------|---------------|-----------------|
| **Science** | Biology, Chemistry, Physics, Earth Science, Astronomy | 20% |
| **Mathematics** | Arithmetic, Algebra, Geometry, Calculus, Statistics | 15% |
| **Literature** | American, British, World, Poetry, Drama | 12% |
| **History** | US, World, Ancient, Modern, Military | 12% |
| **Social Studies** | Geography, Government, Economics, Sociology | 10% |
| **Arts** | Visual Arts, Music, Theater, Architecture | 8% |
| **Current Events** | Politics, Science, Culture, Sports, Technology | 8% |
| **Language** | Grammar, Vocabulary, Etymology, Foreign Languages | 5% |
| **Technology** | Computer Science, Engineering, Inventions | 4% |
| **Pop Culture** | Entertainment, Media, Sports, Games | 3% |
| **Religion & Philosophy** | World Religions, Ethics, Philosophy | 2% |
| **Miscellaneous** | Trivia, Cross-domain, Puzzles | 1% |

### Depth Levels per Domain

Each domain supports UMCF's six content depth levels:

| Level | Duration | Knowledge Bowl Application |
|-------|----------|---------------------------|
| Overview | 2-5 min | Quick fact recognition |
| Introductory | 5-15 min | Basic concept understanding |
| Intermediate | 15-30 min | Standard competition level |
| Advanced | 30-60 min | Championship-level depth |
| Graduate | 60-120 min | Expert mastery topics |
| Research | 90-180 min | Obscure/specialist knowledge |

### Topic Granularity Example

```
Science (Domain)
├── Biology (Category)
│   ├── Cell Biology (Topic)
│   │   ├── Cell Structure (Subtopic)
│   │   │   ├── Organelles (Segment)
│   │   │   ├── Cell Membrane (Segment)
│   │   │   └── Cytoplasm (Segment)
│   │   ├── Cell Division (Subtopic)
│   │   │   ├── Mitosis (Segment)
│   │   │   └── Meiosis (Segment)
│   │   └── Cell Metabolism (Subtopic)
│   ├── Genetics (Topic)
│   ├── Evolution (Topic)
│   ├── Ecology (Topic)
│   └── Human Biology (Topic)
├── Chemistry (Category)
├── Physics (Category)
├── Earth Science (Category)
└── Astronomy (Category)
```

---

## Directed Study System

### Philosophy: Directed vs. Random

Traditional quiz apps use random question selection. The Knowledge Bowl Module uses **directed study**, which means:

| Random Approach | Directed Approach |
|-----------------|-------------------|
| Equal time on all topics | Weighted time based on weakness |
| No awareness of competition date | Prioritizes topics by competition timeline |
| Generic difficulty progression | Adaptive difficulty per subject |
| Isolated topic coverage | Strategic breadth maintenance |

### Study Session Types

#### 1. Diagnostic Session
**Purpose**: Establish baseline proficiency across all domains
**Duration**: 45-60 minutes
**Structure**:
- 5 questions per domain (60 total)
- Mixed difficulty distribution
- No time pressure initially
- Generates initial weakness map

#### 2. Targeted Remediation
**Purpose**: Intensive work on identified weak areas
**Duration**: 20-30 minutes
**Structure**:
- Focuses on 2-3 weakest subtopics
- Scaffolded difficulty progression
- Includes concept explanations
- Uses teachback verification

#### 3. Breadth Maintenance
**Purpose**: Prevent skill decay in strong areas
**Duration**: 15-20 minutes
**Structure**:
- Quick recall across all domains
- Emphasizes speed over depth
- Uses spaced retrieval scheduling
- Maintains competition readiness

#### 4. Speed Drill
**Purpose**: Develop rapid recall under pressure
**Duration**: 10-15 minutes
**Structure**:
- Timed responses (countdown visible)
- Progressive time reduction
- Focus on strong topics first
- Builds confidence and automaticity

#### 5. Competition Simulation
**Purpose**: Full practice under realistic conditions
**Duration**: 30-45 minutes
**Structure**:
- Mimics actual competition format
- Includes written and oral rounds
- Team mode available
- Post-session analytics

### Study Director Algorithm

The Study Director uses a multi-factor optimization to select study content:

```
Priority Score =
    (Weakness Factor × 0.35) +
    (Recency Factor × 0.25) +
    (Question Weight × 0.20) +
    (Competition Timeline × 0.15) +
    (Speed Gap × 0.05)

Where:
- Weakness Factor: 1.0 - mastery_level
- Recency Factor: days_since_review / 30 (capped at 1.0)
- Question Weight: domain weight from competition statistics
- Competition Timeline: urgency based on days to competition
- Speed Gap: (target_time - current_time) / target_time
```

### Adaptive Difficulty

Each topic tracks difficulty separately with three tiers:

| Tier | Description | Progression Criteria |
|------|-------------|---------------------|
| Recognition | Identify correct answer from options | 80% accuracy, <8s response |
| Recall | Generate answer without prompts | 70% accuracy, <5s response |
| Application | Apply knowledge to novel questions | 60% accuracy, <10s response |

---

## Dynamic Content Pipeline

### The Freshness Problem

Knowledge Bowl includes current events and recent developments. Content must stay fresh:

| Content Type | Update Frequency | Source Examples |
|--------------|------------------|-----------------|
| Current Events | Weekly | News APIs, RSS feeds |
| Scientific Discoveries | Monthly | arXiv, journal summaries |
| Political Changes | As-needed | Government sources |
| Cultural Events | Quarterly | Awards, releases |
| Competition Rules | Annually | Official KB organizations |
| Historical Facts | Stable | Academic sources |

### Content Update Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                 Dynamic Content Pipeline                      │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   Source    │    │   Content   │    │   Quality   │      │
│  │   Monitors  │───▶│   Enricher  │───▶│   Verifier  │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│         │                  │                  │              │
│         ▼                  ▼                  ▼              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Content Integration Layer               │    │
│  │  - Question Generation from New Content              │    │
│  │  - Difficulty Classification                         │    │
│  │  - Domain Tagging                                    │    │
│  │  - UMCF Formatting                                   │    │
│  └─────────────────────────────────────────────────────┘    │
│                            │                                 │
│                            ▼                                 │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Curriculum Distribution                 │    │
│  │  - Client Sync                                       │    │
│  │  - Version Management                                │    │
│  │  - Rollback Capability                               │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### Annual Update Cycle

Knowledge Bowl competitions have annual cycles. The module supports:

#### Pre-Season (Summer)
- Competition rule updates imported
- Subject weight adjustments
- Historical question analysis
- Coach/advisor topic suggestions

#### Competition Season (Fall-Spring)
- Weekly current events integration
- Performance analytics from practice
- Peer comparison benchmarks
- Competition result tracking

#### Post-Season (Spring)
- Season performance review
- Curriculum gap analysis
- Content retirement decisions
- Next-year planning

### Content Sources

| Source Type | Examples | Integration Method |
|-------------|----------|-------------------|
| Official KB Materials | NAQT, NSB question sets | Licensed import |
| Educational Databases | Khan Academy, Wikipedia | API integration |
| News Sources | AP, Reuters, NPR | RSS/API feeds |
| Academic Publishers | Textbook summaries | Partnership/license |
| Community Contributions | Coach-submitted questions | Review pipeline |

---

## Assessment and Reinforcement

### Question Types

The module supports UMCF assessment types optimized for Knowledge Bowl:

#### 1. Toss-Up (Single Answer)
```json
{
  "type": "choice",
  "questionType": "toss_up",
  "stem": "This physicist developed the theory of general relativity.",
  "options": [
    { "id": "a", "text": "Isaac Newton" },
    { "id": "b", "text": "Albert Einstein", "correct": true },
    { "id": "c", "text": "Niels Bohr" },
    { "id": "d", "text": "Max Planck" }
  ],
  "timeLimit": 10,
  "points": 10
}
```

#### 2. Bonus (Multi-Part)
```json
{
  "type": "bonus",
  "stem": "Answer these questions about the American Revolution.",
  "parts": [
    {
      "prompt": "Name the general who led the Continental Army.",
      "answer": "George Washington",
      "points": 10
    },
    {
      "prompt": "In what year was the Declaration of Independence signed?",
      "answer": "1776",
      "points": 10
    },
    {
      "prompt": "Name the French general who assisted the American forces.",
      "answer": "Marquis de Lafayette",
      "points": 10
    }
  ]
}
```

#### 3. Pyramid (Progressive Clues)
```json
{
  "type": "pyramid",
  "stem": "Identify this scientist.",
  "clues": [
    { "text": "This scientist was born in Poland in 1867.", "revealPoints": 30 },
    { "text": "They moved to France to study at the Sorbonne.", "revealPoints": 20 },
    { "text": "They discovered radium and polonium.", "revealPoints": 10 },
    { "text": "They won Nobel Prizes in both Physics and Chemistry.", "revealPoints": 5 }
  ],
  "answer": "Marie Curie"
}
```

#### 4. Lightning Round (Rapid Fire)
```json
{
  "type": "lightning",
  "category": "US State Capitals",
  "timeLimit": 60,
  "questions": [
    { "prompt": "California", "answer": "Sacramento" },
    { "prompt": "Texas", "answer": "Austin" },
    { "prompt": "New York", "answer": "Albany" }
  ]
}
```

### Reinforcement Strategy

#### Spaced Retrieval Configuration

The module uses adaptive spaced retrieval based on performance:

| Performance | Initial Interval | Multiplier | Max Interval |
|-------------|------------------|------------|--------------|
| Correct + Fast | 3 days | 2.5x | 30 days |
| Correct + Slow | 2 days | 2.0x | 21 days |
| Incorrect | 1 day | 1.5x | 14 days |
| Repeated Incorrect | Same day | 1.0x | 7 days |

#### Misconception Handling

Common Knowledge Bowl misconceptions are tracked and corrected:

```json
{
  "misconceptions": [
    {
      "description": "Confusing mitosis with meiosis",
      "triggerPhrases": ["both divide", "same thing"],
      "correction": "Mitosis produces 2 identical cells, meiosis produces 4 different gametes.",
      "remediationPath": {
        "reviewTopics": ["cell-division", "genetics-basics"]
      }
    }
  ]
}
```

#### Teachback Verification

For concepts requiring deeper understanding:

```json
{
  "checkpoint": {
    "type": "teachback",
    "prompt": "Explain photosynthesis as if teaching a younger student.",
    "evaluationCriteria": {
      "requiredConcepts": ["light", "chlorophyll", "glucose", "oxygen"],
      "bonusConcepts": ["chloroplast", "carbon dioxide fixation"]
    }
  }
}
```

---

## Competition Simulation

### Simulation Modes

#### Solo Practice
- Individual timed questions
- Immediate feedback
- No opponent pressure
- Focus on accuracy and speed

#### vs. AI Opponent
- Simulated competitor with configurable difficulty
- Realistic buzzer competition
- Strategic interruption decisions
- Performance comparison

#### Team Practice
- Multi-device synchronized sessions
- Role assignment (captain, specialist, backup)
- Team communication protocols
- Collaborative bonus answering

#### Mock Competition
- Full competition format
- Multiple rounds (written + oral)
- Score tracking
- Tournament progression

### Buzzer Mechanics

The simulator includes realistic buzzer behavior:

```
Question Display Timeline:
0ms     ─────────────────────────────────────────────▶ 15000ms
   ┌─────────────┬─────────────┬─────────────┬────────┐
   │  Reading    │   Buzzable  │   Danger    │ Lockout│
   │   Period    │    Zone     │    Zone     │        │
   │  (0-3s)     │  (3-12s)    │  (12-14s)   │ (14s+) │
   └─────────────┴─────────────┴─────────────┴────────┘
                       ▲
                       │
              Optimal buzz window
              (after key info, before opponent)
```

### Performance Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| Accuracy Rate | Correct answers / total attempts | >80% |
| Response Time | Time from question end to answer | <3 seconds |
| Buzz Timing | Optimal buzz point identification | >70% |
| Category Spread | Coverage across all domains | >90% touched |
| Neg Rate | Incorrect buzzes (negative points) | <10% |

---

## Progress Analytics

### Dashboard Components

#### 1. Subject Mastery Radar
Visual representation of proficiency across all 12 domains:
- Color-coded by mastery level
- Historical trend overlay
- Comparison to competition averages

#### 2. Speed Progress Chart
Response time tracking over time:
- Per-subject breakdown
- Target line visualization
- Improvement trajectory

#### 3. Weakness Heat Map
Granular view of problem areas:
- Topic-level detail
- Error pattern analysis
- Recommended focus areas

#### 4. Competition Readiness Score
Overall preparedness metric (0-100):
- Weighted by question distribution
- Accounts for recency
- Predicts expected score

### Analytics API

```json
{
  "studentId": "student_123",
  "assessmentPeriod": "2024-2025",
  "overallReadiness": 78.5,
  "domainScores": {
    "science": { "mastery": 0.82, "speed": 2.8, "trend": "improving" },
    "literature": { "mastery": 0.65, "speed": 4.1, "trend": "stable" },
    "history": { "mastery": 0.71, "speed": 3.5, "trend": "declining" }
  },
  "recommendedFocus": [
    { "domain": "literature", "topic": "british-poetry", "reason": "low_mastery" },
    { "domain": "history", "topic": "world-war-2", "reason": "recent_errors" }
  ],
  "practiceHistory": {
    "totalSessions": 45,
    "totalQuestions": 2340,
    "averageAccuracy": 0.76,
    "averageSpeed": 3.2
  }
}
```

---

## UMCF Integration

### Knowledge Bowl UMCF Extensions

The module extends UMCF with Knowledge Bowl-specific fields:

```json
{
  "$schema": "umcf-schema.json",
  "version": "1.1.0",
  "extensions": {
    "knowledgeBowl": {
      "competitionYear": "2024-2025",
      "questionSource": "naqt",
      "difficultyTier": "varsity",
      "categoryWeights": {
        "science": 0.20,
        "literature": 0.12
      },
      "speedTarget": 3.0,
      "buzzable": true,
      "pyramidClues": []
    }
  }
}
```

### Curriculum Structure

```
knowledge-bowl-curriculum/
├── curriculum.json                 # Root curriculum manifest
├── domains/
│   ├── science/
│   │   ├── domain.json            # Domain metadata
│   │   ├── biology/
│   │   │   ├── topic.json
│   │   │   ├── cell-biology.json
│   │   │   └── genetics.json
│   │   ├── chemistry/
│   │   ├── physics/
│   │   └── earth-science/
│   ├── literature/
│   ├── history/
│   └── [other domains]/
├── assessments/
│   ├── diagnostic/
│   │   └── full-diagnostic.json
│   ├── practice/
│   │   └── daily-drills/
│   └── simulations/
│       └── mock-competitions/
├── current-events/
│   └── 2024/
│       ├── week-01.json
│       ├── week-02.json
│       └── [weekly updates]/
└── competition-rules/
    ├── naqt-2024.json
    └── nsb-2024.json
```

### Sample UMCF Content Node

```json
{
  "id": "kb-science-physics-mechanics-001",
  "nodeType": "segment",
  "title": "Newton's Laws of Motion",
  "description": "Fundamental principles of classical mechanics",
  "spokenText": "Newton's three laws describe how objects move and respond to forces.",
  "domain": "science",
  "category": "physics",
  "topic": "mechanics",
  "knowledgeBowl": {
    "competitionYear": "2024-2025",
    "questionWeight": 0.03,
    "typicalDifficulty": "intermediate",
    "buzzPoints": [
      "When you hear 'inertia', buzz for Newton's First Law",
      "F=ma uniquely identifies Newton's Second Law"
    ]
  },
  "learningObjectives": [
    {
      "statement": "State Newton's three laws of motion",
      "bloomLevel": "remember",
      "assessmentType": "recall"
    },
    {
      "statement": "Apply Newton's second law to calculate force",
      "bloomLevel": "apply",
      "assessmentType": "calculation"
    }
  ],
  "assessments": [
    {
      "id": "newton-tossup-001",
      "type": "choice",
      "questionType": "toss_up",
      "stem": "This law states that an object at rest stays at rest unless acted upon by an external force.",
      "options": [
        { "id": "a", "text": "Newton's First Law", "correct": true },
        { "id": "b", "text": "Newton's Second Law" },
        { "id": "c", "text": "Newton's Third Law" },
        { "id": "d", "text": "Law of Conservation of Energy" }
      ],
      "feedback": {
        "correct": "Correct! Newton's First Law is also called the Law of Inertia.",
        "incorrect": "The Law of Inertia is Newton's First Law, describing objects' tendency to maintain their state of motion."
      },
      "knowledgeBowl": {
        "timeLimit": 10,
        "points": 10,
        "pyramidPosition": null,
        "buzzTrigger": "object at rest stays at rest"
      }
    }
  ],
  "retrievalConfig": {
    "keyConceptForRetrieval": true,
    "difficulty": "medium",
    "retrievalPrompts": [
      "What are Newton's three laws of motion?",
      "Which law relates force, mass, and acceleration?",
      "What is the law of inertia?"
    ],
    "spacingAlgorithm": "sm2",
    "initialInterval": "P1D",
    "maxInterval": "P21D"
  }
}
```

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)

**Deliverables:**
- [ ] Knowledge Bowl UMCF schema extensions
- [ ] Base curriculum structure for 12 domains
- [ ] Core question database (1000+ questions)
- [ ] Basic study session flow

**Technical Tasks:**
- Extend `UMCFParser` for KB extensions
- Create `KnowledgeBowlEngine` actor
- Implement domain mastery tracking
- Build initial question bank

### Phase 2: Directed Study (Weeks 5-8)

**Deliverables:**
- [ ] Study Director algorithm
- [ ] Diagnostic session flow
- [ ] Targeted remediation sessions
- [ ] Breadth maintenance scheduling

**Technical Tasks:**
- Implement priority scoring algorithm
- Build session type templates
- Create weakness analyzer
- Integrate spaced retrieval

### Phase 3: Speed Training (Weeks 9-12)

**Deliverables:**
- [ ] Timed response mechanics
- [ ] Speed drill sessions
- [ ] Response time tracking
- [ ] Progressive difficulty adjustment

**Technical Tasks:**
- Implement countdown timer UI
- Build speed metrics tracking
- Create adaptive time targets
- Add speed-based scoring

### Phase 4: Competition Simulation (Weeks 13-16)

**Deliverables:**
- [ ] Full competition simulator
- [ ] Buzzer mechanics
- [ ] Team mode support
- [ ] Mock competition flow

**Technical Tasks:**
- Build buzzer interaction model
- Implement multi-device sync
- Create competition scoring
- Add post-round analytics

### Phase 5: Dynamic Content (Weeks 17-20)

**Deliverables:**
- [ ] Current events pipeline
- [ ] Weekly content updates
- [ ] Source integration APIs
- [ ] Content verification system

**Technical Tasks:**
- Build content ingestion pipeline
- Implement question generation
- Create quality verification
- Add distribution system

### Phase 6: Analytics & Polish (Weeks 21-24)

**Deliverables:**
- [ ] Progress dashboard
- [ ] Competition readiness scoring
- [ ] Peer benchmarking
- [ ] Coach/parent reports

**Technical Tasks:**
- Build analytics aggregation
- Create visualization components
- Implement export capabilities
- Add notification system

---

## Audio and Storage Management

### Audio Format Specification

**Standard Format: Opus 32 kbps**

All pre-generated question audio uses Opus codec at 32 kbps. This provides:
- Excellent speech quality (equivalent to AAC 64 kbps or MP3 128 kbps)
- Minimal storage footprint (~4 KB/second)
- Native support on iOS (11+) and Android
- Royalty-free licensing

| Content Type | Avg Duration | Size per Item | 1,000 Items |
|--------------|--------------|---------------|-------------|
| Question audio | ~15 sec | ~60 KB | ~60 MB |
| Answer audio | ~3 sec | ~12 KB | ~12 MB |
| Feedback audio | ~8 sec | ~32 KB | ~32 MB |
| **Total per question set** | | | **~104 MB** |

### Storage Budget

| Component | Size | Notes |
|-----------|------|-------|
| JSON question data | ~1 MB | 1,000 questions with metadata |
| Question audio (Opus 32k) | ~60 MB | Pre-generated TTS |
| Answer/feedback audio | ~44 MB | Optional, can stream |
| **Recommended bundle** | **~105 MB** | Full offline capability |

### Smart Content Unloading

Users can manage storage through intelligent content lifecycle:

#### Mastery-Based Unloading

Questions with high mastery scores can be unloaded to free storage:

```
Mastery Level    Unload Eligible    Reload Priority
─────────────────────────────────────────────────────
< 70%            Never              N/A
70-85%           After 30 days      High
85-95%           After 14 days      Medium
> 95%            After 7 days       Low (spaced review)
```

#### Unloading Strategy

1. **Granular unloading**: Individual questions, not entire domains
2. **Audio-first**: Remove audio files first, keep JSON (can re-stream)
3. **Preserve metadata**: Mastery data and history always retained
4. **Lazy reload**: Audio fetched on-demand when question resurfaces
5. **Background sync**: Reload during WiFi/charging when approaching review date

#### User Controls

| Setting | Options | Default |
|---------|---------|---------|
| Max offline storage | 100MB / 250MB / 500MB / Unlimited | 250 MB |
| Auto-unload mastered | On / Off | On |
| Mastery threshold | 85% / 90% / 95% | 90% |
| Keep recent days | 7 / 14 / 30 | 14 |

#### Storage Reclamation Algorithm

```
Priority Score for Unloading =
    (Mastery Level × 0.4) +
    (Days Since Review × 0.3) +
    (Days Until Next Review × 0.2) +
    (File Size Factor × 0.1)

Unload when:
- Storage > user threshold AND
- Priority Score > 0.7 AND
- Content is audio (not JSON metadata)
```

### Offline Capability

The module is designed for full offline operation:

| Feature | Offline Support | Notes |
|---------|-----------------|-------|
| Practice sessions | ✅ Full | All downloaded content |
| Progress tracking | ✅ Full | Local storage, syncs later |
| New content | ❌ Requires sync | Background download |
| Current events | ⚠️ Cached | Weekly refresh recommended |
| Leaderboards | ❌ Online only | Requires server |

### Audio Generation Pipeline

Pre-generated audio is created server-side and bundled with question packs:

```
Question JSON → TTS Engine → Opus Encoder → CDN Distribution
                    ↓
            [Configurable voice]
            [Moderator cadence]
            [Regional variants]
```

See [TTS Configuration](#tts-configuration) for voice selection and settings.

### TTS Configuration

#### Recommended Voice Settings for Question Audio

**Primary Recommendation: Chatterbox (Self-Hosted)**

Chatterbox is an open-source TTS model from Resemble AI, ideal for bulk question generation:

| Setting | Value | Rationale |
|---------|-------|-----------|
| Provider | `chatterbox` | Open source, high quality, tunable |
| Voice ID | `default` or custom clone | Consistent moderator voice |
| Speed | `0.95` | Slightly slower for academic content comprehension |
| Exaggeration | `0.35` | Clear enunciation without being dramatic |
| CFG Weight | `0.6` | Good consistency across questions |
| Language | `en` | English (supports 23 languages) |

**Profile Configuration:**
```json
{
  "name": "KB Question Reader",
  "provider": "chatterbox",
  "voice_id": "default",
  "use_case": "questions",
  "settings": {
    "speed": 0.95,
    "exaggeration": 0.35,
    "cfg_weight": 0.6,
    "language": "en"
  }
}
```

#### Alternative Providers

| Provider | Quality | Cost | Best For |
|----------|---------|------|----------|
| **Chatterbox** | Excellent | Free (self-hosted) | Bulk generation, offline |
| **VibeVoice** | Very Good | Free (self-hosted) | Fast generation |
| **Piper** | Good | Free (self-hosted) | Low-resource environments |
| **ElevenLabs** | Premium | $0.30/1K chars | Voice cloning, premium feel |
| **Deepgram** | Very Good | $0.015/1K chars | Cloud-based, reliable |

#### Voice Selection Criteria

For Knowledge Bowl question audio, prioritize:

1. **Clarity**: Academic terms, proper nouns, scientific names must be clearly pronounced
2. **Authority**: Moderator-like delivery, confident but not overbearing
3. **Consistency**: Same voice across all questions for immersion
4. **Neutrality**: No emotional bias that could hint at answers
5. **Pacing**: Allow time for comprehension, especially for complex questions

#### Domain-Specific Pronunciation

Some domains require special attention:

| Domain | Pronunciation Challenges | Solution |
|--------|-------------------------|----------|
| Science | Latin species names, chemical formulas | Pronunciation lexicon |
| Literature | Author names, foreign titles | Per-question overrides |
| History | Historical figure names, place names | Pronunciation processor |
| Math | Equations read as words | LaTeX-to-speech preprocessing |

#### Generating Audio

Use the management API to generate audio for a question set:

```bash
# Start generation job
curl -X POST http://localhost:8766/api/kb/audio/generate \
  -H "Content-Type: application/json" \
  -d '{
    "module_id": "knowledge-bowl",
    "voice_id": "default",
    "provider": "chatterbox",
    "speed": 0.95
  }'

# Check progress
curl http://localhost:8766/api/kb/audio/jobs/{job_id}

# Get coverage status
curl http://localhost:8766/api/kb/audio/coverage/knowledge-bowl
```

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Domain Coverage | 12 domains, 100+ topics each | Content audit |
| Question Bank Size | 10,000+ questions | Database count |
| Update Freshness | Weekly current events | Pipeline monitoring |
| User Engagement | 5+ sessions/week | Usage analytics |
| Competition Improvement | 20%+ score increase | Pre/post assessment |
| Speed Improvement | 30%+ faster responses | Response time tracking |
| Retention Rate | 80%+ monthly active | User analytics |

---

## Appendices

### A. Competition Organizations

| Organization | Abbreviation | Level | Website |
|--------------|--------------|-------|---------|
| National Academic Quiz Tournaments | NAQT | High School/College | naqt.com |
| National Science Bowl | NSB | High School/Middle | science.energy.gov |
| Quiz Bowl | Various | All levels | quizbowlpackets.com |
| Knowledge Master | KM | Elementary-High | greatauk.com |

### B. Subject Weight Sources

Competition statistics from:
- NAQT Question Distribution Guide
- Historical competition analysis
- Coach survey results

### C. Related Documentation

- [UMCF Specification](/curriculum/spec/UMCF_SPECIFICATION.md)
- [AI Enrichment Pipeline](/curriculum/importers/AI_ENRICHMENT_PIPELINE.md)
- [Progress Tracker](/UnaMentis/Core/Curriculum/ProgressTracker.swift)
- [iOS Style Guide](/docs/ios/IOS_STYLE_GUIDE.md)

---

*Document Version: 1.0.0*
*Last Updated: January 2025*
*Author: UnaMentis Development Team*

---

## Answer Validation Architecture

### Overview

The Knowledge Bowl module implements a three-tiered answer validation system that achieves up to 98% accuracy while respecting regional strictness requirements and device capabilities.

### Three-Tier System

**Tier 1: Enhanced Rule-Based Algorithms (All Devices)**
- **Accuracy:** 85-90% (up from ~75% baseline)
- **Storage:** 0 bytes (pure algorithms)
- **Latency:** <50ms total
- **Availability:** All devices, all regions (respecting regional strictness)

Algorithms:
1. Levenshtein fuzzy matching (baseline)
2. Double Metaphone phonetic matching
3. N-gram similarity (character + word bigrams/trigrams)
4. Token-based matching (Jaccard + Dice coefficients)
5. Domain-specific synonym dictionaries (~650 entries)
6. Linguistic matching (lemmatization via Apple NL framework)

**Tier 2: Semantic Embeddings (Optional, 80MB)**
- **Accuracy:** 92-95%
- **Model:** all-MiniLM-L6-v2 sentence transformer (384-dim)
- **Storage:** 80MB (FP16 quantized CoreML/TFLite)
- **Latency:** 10-30ms inference
- **Requirements:** iPhone XS+ (A12+) / Android 8.0+ with 3GB+ RAM

**Tier 3: LLM Validation (Open Source, 1.5GB)**
- **Accuracy:** 95-98%
- **Model:** Llama 3.2 1B (4-bit quantized, open source)
- **Storage:** 1.5GB (GGUF format via llama.cpp)
- **Latency:** 50-200ms inference
- **Requirements:** iPhone 12+ (A14+) / Android 10+ with 4GB+ RAM
- **Availability:** Controlled by server administrator via feature flags

### Regional Strictness Compliance

The system respects regional competition rules via `KBValidationStrictness`:

```swift
enum KBValidationStrictness: Comparable {
    case strict      // Colorado: Exact + Levenshtein only
    case standard    // Minnesota/Washington: + phonetic + n-gram + token
    case lenient     // Practice mode: + semantic (embeddings, LLM)
}
```

Regional configurations automatically set the appropriate strictness level:
- Colorado regions → `.strict` (highest standards)
- Minnesota/Washington regions → `.standard` (enhanced algorithms allowed)
- Practice mode → `.lenient` (all tiers available)

### Validation Fallback Chain

The validator implements a complete fallback chain:

```
1. Exact primary match → (1.0, .exact)
2. Acceptable alternatives → (1.0, .acceptable)
3. Levenshtein fuzzy → (0.6-1.0, .fuzzy)

[If strictness >= .standard:]
4. Synonym check → (0.95, .fuzzy)
5. Phonetic check → (0.90, .fuzzy)
6. N-gram check → (0.80-1.0, .fuzzy)
7. Token similarity → (0.80-1.0, .fuzzy)
8. Linguistic matching → (0.85, .fuzzy)

[If strictness >= .lenient:]
9. Embeddings → (0.85-1.0, .ai)
10. LLM → (0.98, .ai)

11. No match → (0.0, .none)
```

Each step returns early if a match is found, ensuring optimal performance.

### Device Capability Detection

The system automatically detects device capabilities and enables appropriate tiers:

```swift
enum DeviceCapability {
    static func supportsEmbeddings() -> Bool {
        // iPhone XS+ (model 11+) with 3GB+ RAM
    }

    static func supportsLLMValidation() -> Bool {
        // iPhone 12+ (model 13+) with 4GB+ RAM
    }

    static var maxSupportedTier: Int {
        // Returns 1, 2, or 3 based on device
    }
}
```

### Performance Characteristics

| Tier | Accuracy | Latency | Memory | Storage |
|------|----------|---------|--------|---------|
| Tier 1 | 85-90% | <50ms | <10MB | 0 bytes |
| Tier 2 | 92-95% | <80ms | ~200MB | 80MB |
| Tier 3 | 95-98% | <250ms | ~2GB | 1.5GB |

### Integration with Knowledge Bowl Workflow

Answer validation integrates seamlessly into the Knowledge Bowl study and competition flows:

1. **During Practice:** All tiers available (strictness = .lenient)
2. **During Competition Simulation:** Regional strictness applied automatically
3. **Feedback:** Match type and confidence included in response
4. **Analytics:** Validation confidence tracked for performance insights

### Example Validations

**Tier 1 (Phonetic):**
- User: "Missisipi" → Correct: "Mississippi" ✓
- User: "Filadelfia" → Correct: "Philadelphia" ✓
- User: "Kristopher" → Correct: "Christopher" ✓

**Tier 1 (Synonym):**
- User: "USA" → Correct: "United States" ✓
- User: "CO2" → Correct: "Carbon Dioxide" ✓
- User: "WWI" → Correct: "World War I" ✓

**Tier 2 (Embeddings):**
- User: "water" → Correct: "H2O" ✓
- User: "table salt" → Correct: "NaCl" ✓
- User: "genetic material" → Correct: "DNA" ✓

**Tier 3 (LLM):**
- User: "the powerhouse of the cell" → Correct: "mitochondria" ✓
- User: "the author of Romeo and Juliet" → Correct: "William Shakespeare" ✓
- User: "the largest planet" → Correct: "Jupiter" ✓

### Cross-Platform Parity

The validation system maintains consistent behavior across iOS and Android:

- **Test Vectors:** Shared JSON file with 1000+ Q&A pairs
- **Parity Testing:** Automated CI checks ensure <2% accuracy difference
- **Model Formats:** CoreML (iOS) and TensorFlow Lite (Android) for embeddings
- **LLM Backend:** llama.cpp on both platforms

### See Also

- [Answer Validation API Documentation](KNOWLEDGE_BOWL_ANSWER_VALIDATION.md)
- [Enhanced Validation User Guide](../user-guides/KNOWLEDGE_BOWL_ENHANCED_VALIDATION.md)
- [Validation Testing Documentation](../testing/KNOWLEDGE_BOWL_VALIDATION_TESTING.md)

