/**
 * UMCF Curriculum Types
 * Based on UMCF_SPECIFICATION.md
 */

// ===== Identifiers =====

export interface CatalogId {
  catalog: string;
  value: string;
}

// ===== Version =====

export interface Version {
  number: string;
  date: string;
  changelog?: string;
}

// ===== Lifecycle =====

export interface Contributor {
  name: string;
  role: string;
  email?: string;
  organization?: string;
}

export interface Lifecycle {
  status: 'draft' | 'review' | 'published' | 'archived';
  contributors?: Contributor[];
  dates?: {
    created?: string;
    modified?: string;
    published?: string;
  };
}

// ===== Metadata =====

export interface Metadata {
  language: string;
  keywords?: string[];
  subject?: string;
  gradeLevel?: string;
}

// ===== Educational =====

export interface EducationalAlignment {
  alignmentType: 'teaches' | 'assesses' | 'requires';
  educationalFramework: string;
  targetName: string;
  targetDescription?: string;
  targetUrl?: string;
}

export interface Educational {
  audience?: {
    minimumAge?: number;
    maximumAge?: number;
    educationLevel?: string;
  };
  alignment?: EducationalAlignment[];
  difficulty?: 'beginner' | 'intermediate' | 'advanced';
}

// ===== Rights =====

export interface Rights {
  license: string;
  attribution?: string;
  copyrightHolder?: string;
  copyrightYear?: number;
}

// ===== Learning Objectives =====

export type BloomsLevel =
  | 'remember'
  | 'understand'
  | 'apply'
  | 'analyze'
  | 'evaluate'
  | 'create';

export interface LearningObjective {
  id: CatalogId;
  statement: string;
  abbreviatedStatement?: string;
  bloomsLevel: BloomsLevel;
  educationalAlignment?: EducationalAlignment[];
  verificationCriteria?: string;
  assessmentIds?: string[];
}

// ===== Transcript =====

export type SegmentType =
  | 'introduction'
  | 'lecture'
  | 'explanation'
  | 'example'
  | 'checkpoint'
  | 'transition'
  | 'summary'
  | 'conclusion';

export interface SpeakingNotes {
  pace?: 'very slow' | 'slow' | 'normal' | 'fast';
  emphasis?: string[];
  pauseAfter?: boolean;
  pauseDuration?: number;
  emotionalTone?: 'neutral' | 'encouraging' | 'serious' | 'curious' | 'excited';
}

export type CheckpointType =
  | 'simple_confirmation'
  | 'comprehension_check'
  | 'knowledge_check'
  | 'application_check'
  | 'teachback';

export interface Checkpoint {
  type: CheckpointType;
  prompt: string;
  expectedResponses?: string[];
  fallbackResponse?: string;
}

export interface StoppingPoint {
  reason: string;
  resumePrompt?: string;
}

export interface AlternativeExplanation {
  id: string;
  approach: string;
  content: string;
  forDifficulty?: string;
}

export interface TranscriptSegment {
  id: string;
  type: SegmentType;
  content: string;
  speakingNotes?: SpeakingNotes;
  checkpoint?: Checkpoint;
  stoppingPoint?: StoppingPoint;
  glossaryRefs?: string[];
  alternativeExplanations?: AlternativeExplanation[];
  estimatedDuration?: string; // ISO 8601 duration
}

export interface PronunciationEntry {
  ipa: string;
  respelling: string;
  language?: string;
}

export interface VoiceProfile {
  tone?: 'conversational' | 'formal' | 'casual';
  pace?: 'slow' | 'moderate' | 'fast';
  accent?: string;
}

export interface Transcript {
  segments: TranscriptSegment[];
  totalDuration?: string; // ISO 8601 duration
  pronunciationGuide?: Record<string, PronunciationEntry>;
  voiceProfile?: VoiceProfile;
}

// ===== Media Assets =====

export type MediaType =
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

export type DisplayMode = 'persistent' | 'highlight' | 'popup' | 'inline';

export interface SegmentTiming {
  startSegment: string;
  endSegment?: string;
  displayMode: DisplayMode;
}

export interface Dimensions {
  width: number;
  height: number;
}

export interface SemanticVariable {
  symbol: string;
  meaning: string;
  unit?: string | null;
}

export interface SemanticMeaning {
  category?: string;
  commonName?: string;
  purpose?: string;
  variables?: SemanticVariable[];
  spokenForm?: string;
}

export interface GeoPoint {
  latitude: number;
  longitude: number;
}

export interface MapMarker {
  id?: string;
  latitude: number;
  longitude: number;
  label: string;
  description?: string;
  markerType?: string;
  color?: string;
}

export interface MapRoute {
  id?: string;
  label?: string;
  points: GeoPoint[];
  color?: string;
  style?: 'solid' | 'dashed' | 'dotted';
  width?: number;
}

export interface MapRegion {
  id?: string;
  label?: string;
  points?: GeoPoint[];
  geoJsonUrl?: string;
  fillColor?: string;
  opacity?: number;
}

export interface DiagramSourceCode {
  format: 'mermaid' | 'graphviz' | 'plantuml' | 'd2';
  code: string;
  version?: string;
}

export interface ChartDataset {
  label: string;
  data: number[];
  backgroundColor?: string | string[];
  borderColor?: string;
}

export interface ChartData {
  labels: string[];
  datasets: ChartDataset[];
}

// Base media asset
export interface BaseMediaAsset {
  id: string;
  type: MediaType;
  url?: string;
  localPath?: string;
  title?: string;
  alt: string;
  caption?: string;
  mimeType?: string;
  dimensions?: Dimensions;
  segmentTiming?: SegmentTiming;
}

// Type-specific media assets
export interface ImageAsset extends BaseMediaAsset {
  type: 'image';
}

export interface DiagramAsset extends BaseMediaAsset {
  type: 'diagram';
  diagramSubtype?: string;
  sourceCode?: DiagramSourceCode;
  generationSource?: string;
}

export interface FormulaAsset extends BaseMediaAsset {
  type: 'formula' | 'equation';
  latex: string;
  displayMode?: 'block' | 'inline';
  semanticMeaning?: SemanticMeaning;
  fallbackImageUrl?: string;
}

export interface ChartAsset extends BaseMediaAsset {
  type: 'chart';
  chartType: 'bar' | 'line' | 'pie' | 'scatter' | 'radar';
  chartData: ChartData;
}

export interface MapAsset extends BaseMediaAsset {
  type: 'map';
  geography: {
    center: GeoPoint;
    zoom: number;
  };
  mapStyle?: 'standard' | 'historical' | 'physical' | 'satellite' | 'minimal' | 'educational';
  timePeriod?: {
    year: number;
    era: 'BCE' | 'CE';
    displayLabel?: string;
  };
  markers?: MapMarker[];
  routes?: MapRoute[];
  regions?: MapRegion[];
  interactive?: boolean;
  fallbackImageUrl?: string;
}

export interface VideoAsset extends BaseMediaAsset {
  type: 'video' | 'videoLecture';
  duration?: number;
  source?: string;
}

export type MediaAsset =
  | ImageAsset
  | DiagramAsset
  | FormulaAsset
  | ChartAsset
  | MapAsset
  | VideoAsset;

// Visual asset (alias for components)
export type VisualAsset = MediaAsset;

export interface MediaCollection {
  embedded?: MediaAsset[];
  reference?: Array<{
    id: string;
    type: 'link' | 'document';
    url: string;
    title: string;
    description?: string;
  }>;
}

// ===== Assessments =====

export type AssessmentType = 'choice' | 'multiple_choice' | 'text_entry' | 'true_false';

export interface AssessmentChoice {
  id: string;
  text: string;
  spokenText?: string;
  correct: boolean;
  feedback?: string;
}

export interface AssessmentFeedback {
  text: string;
  spokenText?: string;
  hint?: string;
}

export interface AssessmentScoring {
  maxScore: number;
  passingScore: number;
  partialCredit?: boolean;
}

export interface Assessment {
  id: CatalogId;
  type: AssessmentType;
  title?: string;
  prompt: string;
  spokenPrompt?: string;
  choices?: AssessmentChoice[];
  correctResponse?: string[];
  scoring?: AssessmentScoring;
  feedback?: {
    correct: AssessmentFeedback;
    incorrect: AssessmentFeedback;
  };
  hints?: Array<{ text: string }>;
  difficulty?: number;
  objectivesAssessed?: string[];
}

// ===== Glossary =====

export interface GlossaryTerm {
  id: string;
  term: string;
  pronunciation?: string;
  definition: string;
  spokenDefinition?: string;
  simpleDefinition?: string;
  synonyms?: string[];
  relatedTerms?: string[];
  etymology?: string;
}

export interface Glossary {
  terms: GlossaryTerm[];
}

// ===== Misconceptions =====

export interface RemediationPath {
  reviewTopics?: string[];
  additionalExamples?: string[];
  suggestedTranscriptSegments?: string[];
}

export interface Misconception {
  id: string;
  misconception: string;
  triggerPhrases?: string[];
  correction: string;
  spokenCorrection?: string;
  explanation?: string;
  remediationPath?: RemediationPath;
  severity?: 'minor' | 'moderate' | 'critical';
}

// ===== Time Estimates =====

export interface TimeEstimates {
  overview?: string;
  introductory?: string;
  intermediate?: string;
  advanced?: string;
  graduate?: string;
  research?: string;
}

// ===== Tutoring Config =====

export interface TutoringConfig {
  contentDepth?: 'overview' | 'introductory' | 'intermediate' | 'advanced' | 'graduate' | 'research';
  adaptiveDepth?: boolean;
  systemPromptOverride?: string;
  interactionMode?: 'lecture' | 'socratic' | 'practice' | 'assessment' | 'freeform';
  allowTangents?: boolean;
  checkpointFrequency?: 'never' | 'low' | 'medium' | 'high' | 'every_segment';
  escalationThreshold?: number;
}

// ===== Content Node =====

export type NodeType =
  | 'curriculum'
  | 'unit'
  | 'module'
  | 'topic'
  | 'subtopic'
  | 'lesson'
  | 'section'
  | 'segment';

export interface ContentNode {
  id: CatalogId;
  title: string;
  type: NodeType;
  orderIndex?: number;
  description?: string;
  learningObjectives?: LearningObjective[];
  prerequisites?: CatalogId[];
  timeEstimates?: TimeEstimates;
  transcript?: Transcript;
  examples?: Array<{
    id: string;
    title: string;
    content: string;
  }>;
  assessments?: Assessment[];
  glossaryTerms?: string[];
  misconceptions?: Misconception[];
  resources?: Array<{
    id: string;
    type: string;
    url: string;
    title: string;
    description?: string;
  }>;
  media?: MediaCollection;
  children?: ContentNode[];
  tutoringConfig?: TutoringConfig;
  extensions?: Record<string, unknown>;
}

// ===== Topic (alias for UI) =====

export interface Topic extends ContentNode {
  type: 'topic';
}

// ===== UMCF Document =====

export interface UMCFDocument {
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
  extensions?: Record<string, unknown>;
}

// ===== Curriculum (API Response) =====

export interface CurriculumSummary {
  id: string;
  title: string;
  description?: string;
  author?: string;
  language: string;
  created_at: string;
  updated_at: string;
  topics_count: number;
  status: 'draft' | 'published' | 'archived';
}

export interface Curriculum extends CurriculumSummary {
  topics: Topic[];
}

export interface CurriculumWithAssets {
  curriculum: Curriculum;
  assets: Record<string, string>; // asset id -> base64 encoded data
}

// ===== Archived Curriculum =====

export interface ArchivedCurriculum {
  file_name: string;
  curriculum_id: string;
  curriculum_title: string;
  archived_at: string;
  file_size: number;
  checksum: string;
}
