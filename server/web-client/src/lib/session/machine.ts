/**
 * Session State Machine
 *
 * XState v5 state machine for managing voice learning sessions.
 * Mirrors the iOS client session states for consistency.
 */

import { setup, assign } from 'xstate';
import type { SessionContext, SessionMetrics } from '@/types/session';

// ===== Types =====

export interface SessionMachineContext extends SessionContext {
  // Additional machine-specific context
  retryCount: number;
  maxRetries: number;
}

export type SessionMachineEvent =
  | { type: 'START_SESSION'; topicId?: string }
  | { type: 'STOP_SESSION' }
  | { type: 'STT_INTERIM'; text: string }
  | { type: 'STT_FINAL'; text: string }
  | { type: 'LLM_FIRST_TOKEN' }
  | { type: 'LLM_TOKEN'; content: string }
  | { type: 'LLM_COMPLETE' }
  | { type: 'TTS_COMPLETE' }
  | { type: 'USER_SPEECH_DETECTED' }
  | { type: 'USER_SPEECH_CONFIRMED' }
  | { type: 'PAUSE' }
  | { type: 'RESUME' }
  | { type: 'ERROR'; error: Error }
  | { type: 'RETRY' }
  | { type: 'DISMISS' };

// ===== Initial Context =====

function createInitialMetrics(): SessionMetrics {
  return {
    sessionId: '',
    startTime: new Date(),
    duration: 0,
    sttLatencies: [],
    llmTTFTs: [],
    ttsTTFBs: [],
    e2eLatencies: [],
    sttCost: 0,
    llmInputTokens: 0,
    llmOutputTokens: 0,
    llmCost: 0,
    ttsCost: 0,
    totalCost: 0,
    turnCount: 0,
    userSpeechDuration: 0,
    aiSpeechDuration: 0,
    interruptionCount: 0,
    errorCount: 0,
  };
}

function createInitialContext(): SessionMachineContext {
  return {
    state: 'idle',
    sessionId: null,
    conversationHistory: [],
    currentUtterance: '',
    aiResponse: '',
    currentTopic: null,
    visualAssets: [],
    currentVisualIndex: 0,
    metrics: createInitialMetrics(),
    error: null,
    retryCount: 0,
    maxRetries: 3,
  };
}

// ===== State Machine =====

export const sessionMachine = setup({
  types: {
    context: {} as SessionMachineContext,
    events: {} as SessionMachineEvent,
  },
  guards: {
    canRetry: ({ context }) => context.retryCount < context.maxRetries,
    hasUtterance: ({ context }) => context.currentUtterance.trim().length > 0,
  },
  actions: {
    initializeSession: assign({
      sessionId: () => `session-${Date.now()}-${Math.random().toString(36).slice(2)}`,
      metrics: ({ context }) => ({
        ...context.metrics,
        sessionId: context.sessionId || '',
        startTime: new Date(),
      }),
      error: () => null,
      retryCount: () => 0,
    }),
    setTopic: assign({
      currentTopic: ({ context, event }) => {
        if (event.type === 'START_SESSION' && event.topicId) {
          // Topic would be loaded from API based on topicId
          return null; // Placeholder
        }
        return context.currentTopic;
      },
    }),
    updateInterimTranscript: assign({
      currentUtterance: ({ event }) => {
        if (event.type === 'STT_INTERIM') {
          return event.text;
        }
        return '';
      },
    }),
    setFinalTranscript: assign({
      currentUtterance: ({ event }) => {
        if (event.type === 'STT_FINAL') {
          return event.text;
        }
        return '';
      },
    }),
    addUserMessage: assign({
      conversationHistory: ({ context }) => {
        if (!context.currentUtterance.trim()) return context.conversationHistory;
        return [
          ...context.conversationHistory,
          { role: 'user' as const, content: context.currentUtterance },
        ];
      },
      metrics: ({ context }) => ({
        ...context.metrics,
        turnCount: context.metrics.turnCount + 1,
      }),
    }),
    appendAIResponse: assign({
      aiResponse: ({ context, event }) => {
        if (event.type === 'LLM_TOKEN') {
          return context.aiResponse + event.content;
        }
        return context.aiResponse;
      },
    }),
    finalizeAIResponse: assign({
      conversationHistory: ({ context }) => {
        if (!context.aiResponse.trim()) return context.conversationHistory;
        return [
          ...context.conversationHistory,
          { role: 'assistant' as const, content: context.aiResponse },
        ];
      },
      aiResponse: () => '',
    }),
    truncateAIResponse: assign({
      aiResponse: () => '',
      metrics: ({ context }) => ({
        ...context.metrics,
        interruptionCount: context.metrics.interruptionCount + 1,
      }),
    }),
    setError: assign({
      error: ({ event }) => {
        if (event.type === 'ERROR') {
          return event.error;
        }
        return null;
      },
      metrics: ({ context }) => ({
        ...context.metrics,
        errorCount: context.metrics.errorCount + 1,
      }),
    }),
    clearError: assign({
      error: () => null,
      retryCount: () => 0,
    }),
    incrementRetry: assign({
      retryCount: ({ context }) => context.retryCount + 1,
    }),
    resetSession: assign(() => createInitialContext()),
  },
}).createMachine({
  id: 'session',
  initial: 'idle',
  context: createInitialContext(),
  states: {
    idle: {
      on: {
        START_SESSION: {
          target: 'userSpeaking',
          actions: ['initializeSession', 'setTopic'],
        },
      },
    },

    userSpeaking: {
      on: {
        STT_INTERIM: {
          actions: ['updateInterimTranscript'],
        },
        STT_FINAL: {
          target: 'processingUserUtterance',
          actions: ['setFinalTranscript'],
        },
        PAUSE: {
          target: 'paused',
        },
        STOP_SESSION: {
          target: 'idle',
          actions: ['resetSession'],
        },
        ERROR: {
          target: 'error',
          actions: ['setError'],
        },
      },
    },

    processingUserUtterance: {
      entry: ['addUserMessage'],
      always: [
        {
          target: 'aiThinking',
          guard: 'hasUtterance',
        },
        {
          target: 'userSpeaking',
        },
      ],
    },

    aiThinking: {
      on: {
        LLM_FIRST_TOKEN: {
          target: 'aiSpeaking',
        },
        LLM_TOKEN: {
          actions: ['appendAIResponse'],
        },
        USER_SPEECH_DETECTED: {
          target: 'interrupted',
        },
        PAUSE: {
          target: 'paused',
        },
        STOP_SESSION: {
          target: 'idle',
          actions: ['resetSession'],
        },
        ERROR: {
          target: 'error',
          actions: ['setError'],
        },
      },
    },

    aiSpeaking: {
      on: {
        LLM_TOKEN: {
          actions: ['appendAIResponse'],
        },
        LLM_COMPLETE: {
          actions: ['finalizeAIResponse'],
        },
        TTS_COMPLETE: {
          target: 'userSpeaking',
        },
        USER_SPEECH_DETECTED: {
          target: 'interrupted',
        },
        PAUSE: {
          target: 'paused',
        },
        STOP_SESSION: {
          target: 'idle',
          actions: ['resetSession'],
        },
        ERROR: {
          target: 'error',
          actions: ['setError'],
        },
      },
    },

    interrupted: {
      entry: ['truncateAIResponse'],
      on: {
        USER_SPEECH_CONFIRMED: {
          target: 'userSpeaking',
        },
        TTS_COMPLETE: {
          // User stopped speaking, AI can continue
          target: 'userSpeaking',
        },
        PAUSE: {
          target: 'paused',
        },
        STOP_SESSION: {
          target: 'idle',
          actions: ['resetSession'],
        },
        ERROR: {
          target: 'error',
          actions: ['setError'],
        },
      },
    },

    paused: {
      on: {
        RESUME: {
          target: 'userSpeaking',
        },
        STOP_SESSION: {
          target: 'idle',
          actions: ['resetSession'],
        },
      },
    },

    error: {
      on: {
        RETRY: [
          {
            target: 'userSpeaking',
            guard: 'canRetry',
            actions: ['clearError', 'incrementRetry'],
          },
          {
            target: 'idle',
            actions: ['resetSession'],
          },
        ],
        DISMISS: {
          target: 'userSpeaking',
          actions: ['clearError'],
        },
        STOP_SESSION: {
          target: 'idle',
          actions: ['resetSession'],
        },
      },
    },
  },
});

// ===== Type Exports =====

export type SessionMachine = typeof sessionMachine;
