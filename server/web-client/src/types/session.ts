/**
 * Session State Types
 * Based on WEB_CLIENT_TDD.md Section 6
 */

import type { Message } from './providers';
import type { VisualAsset, Topic } from './curriculum';

// ===== Session State Machine =====

export type SessionState =
  | 'idle' // Not active
  | 'userSpeaking' // Listening to user
  | 'processingUserUtterance' // STT result received
  | 'aiThinking' // LLM generating response
  | 'aiSpeaking' // TTS playback in progress
  | 'interrupted' // Tentative barge-in
  | 'paused' // Frozen state (can resume)
  | 'error'; // Error occurred

// ===== Session Context =====

export interface SessionContext {
  state: SessionState;
  sessionId: string | null;
  conversationHistory: Message[];
  currentUtterance: string;
  aiResponse: string;
  currentTopic: Topic | null;
  visualAssets: VisualAsset[];
  currentVisualIndex: number;
  metrics: SessionMetrics;
  error: Error | null;
}

// ===== Session Metrics =====

export interface SessionMetrics {
  sessionId: string;
  startTime: Date;
  duration: number; // seconds

  // Latency metrics
  sttLatencies: number[]; // ms
  llmTTFTs: number[]; // ms (time to first token)
  ttsTTFBs: number[]; // ms (time to first byte)
  e2eLatencies: number[]; // ms (full turn)

  // Cost metrics
  sttCost: number; // dollars
  llmInputTokens: number;
  llmOutputTokens: number;
  llmCost: number; // dollars
  ttsCost: number; // dollars
  totalCost: number; // dollars

  // Usage metrics
  turnCount: number;
  userSpeechDuration: number; // seconds
  aiSpeechDuration: number; // seconds
  interruptionCount: number;
  errorCount: number;
}

// ===== Session Events =====

export type SessionEvent =
  | { type: 'START_SESSION'; topicId?: string }
  | { type: 'STOP_SESSION' }
  | { type: 'PAUSE' }
  | { type: 'RESUME' }
  | { type: 'STT_INTERIM'; text: string }
  | { type: 'STT_FINAL'; text: string }
  | { type: 'LLM_FIRST_TOKEN' }
  | { type: 'LLM_TOKEN'; content: string }
  | { type: 'LLM_SENTENCE_COMPLETE'; sentence: string }
  | { type: 'LLM_COMPLETE' }
  | { type: 'TTS_PLAYBACK_START' }
  | { type: 'TTS_COMPLETE' }
  | { type: 'USER_SPEECH_DETECTED' }
  | { type: 'USER_SPEECH_CONFIRMED' }
  | { type: 'ERROR'; error: Error }
  | { type: 'RETRY' }
  | { type: 'DISMISS' };

// ===== Session Actions =====

export interface SessionActions {
  initializeSession: () => void;
  startAudioCapture: () => void;
  updateInterimTranscript: (text: string) => void;
  setFinalTranscript: (text: string) => void;
  addUserMessage: () => void;
  startLLMRequest: () => void;
  appendAIResponse: (content: string) => void;
  queueTTSSentence: (sentence: string) => void;
  finalizeLLMResponse: () => void;
  cancelTTS: () => void;
  resumeTTS: () => void;
  truncateAIResponse: () => void;
  resumeSession: () => void;
  cleanupSession: () => void;
}

// ===== Bottom Sheet State (Mobile) =====

export type BottomSheetState = 'collapsed' | 'peek' | 'expanded' | 'fullscreen';

export const bottomSheetHeights: Record<BottomSheetState, number | string> = {
  collapsed: 0,
  peek: 120,
  expanded: '50vh',
  fullscreen: 'calc(100vh - 56px)',
};

// ===== Session Configuration =====

export interface SessionConfig {
  autoStart?: boolean;
  interactionMode?: 'lecture' | 'socratic' | 'practice' | 'assessment' | 'freeform';
  checkpointFrequency?: 'never' | 'low' | 'medium' | 'high' | 'every_segment';
  adaptiveDepth?: boolean;
  allowTangents?: boolean;
}

// ===== Session History =====

export interface SessionHistoryEntry {
  id: string;
  topicId: string;
  topicTitle: string;
  curriculumId: string;
  curriculumTitle: string;
  startedAt: string;
  endedAt: string;
  duration: number; // seconds
  turnCount: number;
  completionPercentage: number;
}

// ===== Session Summary =====

export interface SessionSummary {
  sessionId: string;
  duration: number;
  turnCount: number;
  topicsCovered: string[];
  keyPoints: string[];
  areasForReview: string[];
  metrics: {
    averageE2ELatency: number;
    totalCost: number;
    interruptionRate: number;
  };
}
