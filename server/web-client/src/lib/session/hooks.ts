/**
 * Session Hooks
 *
 * React hooks for interacting with the session state machine.
 * Provides a clean API for components to manage voice sessions.
 */

'use client';

import * as React from 'react';
import { useMachine } from '@xstate/react';
import { sessionMachine, type SessionMachineContext } from './machine';
import { getProviderManager, type ProviderConfig, type STTResult } from '@/lib/providers';
import { getAudioContextManager, createAudioRecorder, createVAD, type VADEvent } from '@/lib/audio';
import type { SessionState, SessionMetrics } from '@/types/session';

// ===== Types =====

export interface UseSessionOptions {
  /** Provider configuration */
  providers: ProviderConfig;
  /** Auto-start session when hook mounts */
  autoStart?: boolean;
  /** Topic ID to start with */
  topicId?: string;
  /** System instructions for the AI */
  instructions?: string;
  /** Callback when transcript is received */
  onTranscript?: (text: string, isFinal: boolean) => void;
  /** Callback when AI response is received */
  onAIResponse?: (text: string) => void;
  /** Callback when session state changes */
  onStateChange?: (state: SessionState) => void;
  /** Callback when error occurs */
  onError?: (error: Error) => void;
}

export interface UseSessionReturn {
  /** Current session state */
  state: SessionState;
  /** Whether currently listening to user */
  isListening: boolean;
  /** Whether AI is speaking */
  isAISpeaking: boolean;
  /** Whether session is paused */
  isPaused: boolean;
  /** Whether there's an error */
  hasError: boolean;
  /** Current error if any */
  error: Error | null;
  /** Current user utterance (interim + final) */
  transcript: string;
  /** Current AI response */
  aiResponse: string;
  /** Conversation history */
  history: Array<{ role: 'user' | 'assistant'; content: string }>;
  /** Session metrics */
  metrics: SessionMetrics;
  /** Start the session */
  start: (topicId?: string) => Promise<void>;
  /** Stop the session */
  stop: () => void;
  /** Pause the session */
  pause: () => void;
  /** Resume the session */
  resume: () => void;
  /** Mute/unmute microphone */
  setMuted: (muted: boolean) => void;
  /** Check if muted */
  isMuted: boolean;
  /** Retry after error */
  retry: () => void;
  /** Dismiss error */
  dismissError: () => void;
}

// ===== Hook Implementation =====

export function useSession(options: UseSessionOptions): UseSessionReturn {
  const {
    providers,
    autoStart = false,
    topicId,
    instructions: _instructions,
    onTranscript,
    onAIResponse: _onAIResponse,
    onStateChange,
    onError,
  } = options;

  // State machine
  const [machineState, send] = useMachine(sessionMachine);
  const context = machineState.context as SessionMachineContext;

  // Refs for cleanup
  const providerManagerRef = React.useRef(getProviderManager());
  const audioRecorderRef = React.useRef(createAudioRecorder());
  const vadRef = React.useRef(createVAD());
  const isMutedRef = React.useRef(false);

  // Derived state
  const state = machineState.value as SessionState;
  const isListening = state === 'userSpeaking';
  const isAISpeaking = state === 'aiSpeaking';
  const isPaused = state === 'paused';
  const hasError = state === 'error';

  // Initialize providers
  React.useEffect(() => {
    const manager = providerManagerRef.current;

    manager.configure(providers, {
      onSTTResult: (result: STTResult) => {
        if (result.isFinal) {
          send({ type: 'STT_FINAL', text: result.text });
          onTranscript?.(result.text, true);
        } else {
          send({ type: 'STT_INTERIM', text: result.text });
          onTranscript?.(result.text, false);
        }
      },
      onTTSComplete: () => {
        send({ type: 'TTS_COMPLETE' });
      },
      onError: (error) => {
        send({ type: 'ERROR', error });
        onError?.(error);
      },
    });

    return () => {
      manager.dispose();
    };
  }, [providers, send, onTranscript, onError]);

  // Initialize audio context on mount
  React.useEffect(() => {
    const initAudio = async () => {
      try {
        await getAudioContextManager().initialize();
      } catch (error) {
        console.warn('[Session] Audio context init failed:', error);
      }
    };
    initAudio();
  }, []);

  // Auto-start
  React.useEffect(() => {
    if (autoStart && state === 'idle') {
      start(topicId);
    }
  }, [autoStart, state, topicId]);

  // Notify on state change
  React.useEffect(() => {
    onStateChange?.(state);
  }, [state, onStateChange]);

  // Handle VAD events
  const handleVADEvent = React.useCallback((event: VADEvent) => {
    if (event.type === 'speech_start' && state === 'aiSpeaking') {
      send({ type: 'USER_SPEECH_DETECTED' });
    } else if (event.type === 'speech_end' && state === 'interrupted') {
      send({ type: 'USER_SPEECH_CONFIRMED' });
    }
  }, [state, send]);

  // Start session
  const start = React.useCallback(async (startTopicId?: string) => {
    try {
      // Initialize audio context (requires user gesture)
      await getAudioContextManager().initialize();

      // Connect providers
      await providerManagerRef.current.connectSTT();
      await providerManagerRef.current.startSTTStreaming();

      // Start VAD
      vadRef.current.start(handleVADEvent);

      // Start recording
      await audioRecorderRef.current.start({}, (chunk) => {
        // Send audio to provider
        providerManagerRef.current.sendAudio(chunk);

        // Process with VAD
        const samples = new Float32Array(chunk);
        vadRef.current.process(samples);
      });

      // Start the state machine
      send({ type: 'START_SESSION', topicId: startTopicId || topicId });
    } catch (error) {
      send({ type: 'ERROR', error: error instanceof Error ? error : new Error(String(error)) });
      onError?.(error instanceof Error ? error : new Error(String(error)));
    }
  }, [topicId, send, handleVADEvent, onError]);

  // Stop session
  const stop = React.useCallback(() => {
    // Stop recording
    audioRecorderRef.current.stop();

    // Stop VAD
    vadRef.current.stop();

    // Disconnect providers
    providerManagerRef.current.disconnectSTT();

    // Stop the state machine
    send({ type: 'STOP_SESSION' });
  }, [send]);

  // Pause session
  const pause = React.useCallback(() => {
    audioRecorderRef.current.stop();
    send({ type: 'PAUSE' });
  }, [send]);

  // Resume session
  const resume = React.useCallback(async () => {
    await audioRecorderRef.current.start({}, (chunk) => {
      providerManagerRef.current.sendAudio(chunk);
      const samples = new Float32Array(chunk);
      vadRef.current.process(samples);
    });
    send({ type: 'RESUME' });
  }, [send]);

  // Mute control
  const setMuted = React.useCallback((muted: boolean) => {
    isMutedRef.current = muted;
    audioRecorderRef.current.setMuted(muted);
  }, []);

  // Retry after error
  const retry = React.useCallback(() => {
    send({ type: 'RETRY' });
  }, [send]);

  // Dismiss error
  const dismissError = React.useCallback(() => {
    send({ type: 'DISMISS' });
  }, [send]);

  return {
    state,
    isListening,
    isAISpeaking,
    isPaused,
    hasError,
    error: context.error,
    transcript: context.currentUtterance,
    aiResponse: context.aiResponse,
    history: context.conversationHistory.filter(
      (msg): msg is { role: 'user' | 'assistant'; content: string } =>
        msg.role === 'user' || msg.role === 'assistant'
    ),
    metrics: context.metrics,
    start,
    stop,
    pause,
    resume,
    setMuted,
    isMuted: isMutedRef.current,
    retry,
    dismissError,
  };
}

// ===== Simple Hook for Read-Only Session State =====

export interface UseSessionStateReturn {
  state: SessionState;
  isActive: boolean;
  isListening: boolean;
  isAISpeaking: boolean;
  isPaused: boolean;
  hasError: boolean;
}

/**
 * Lightweight hook for components that only need to read session state.
 */
export function useSessionState(): UseSessionStateReturn {
  const [state, _setState] = React.useState<SessionState>('idle');

  // This would typically subscribe to a global session store
  // For now, return defaults
  return {
    state,
    isActive: state !== 'idle',
    isListening: state === 'userSpeaking',
    isAISpeaking: state === 'aiSpeaking',
    isPaused: state === 'paused',
    hasError: state === 'error',
  };
}
