/**
 * Voice Providers Module
 *
 * This module provides the voice pipeline infrastructure for the UnaMentis web client.
 * It includes STT (Speech-to-Text), TTS (Text-to-Speech), and combined providers.
 *
 * @module lib/providers
 *
 * @example
 * ```tsx
 * import { getProviderManager, type ProviderConfig } from '@/lib/providers';
 *
 * const manager = getProviderManager();
 *
 * await manager.configure({
 *   stt: { provider: 'deepgram', model: 'nova-2' },
 *   llm: { provider: 'openai', model: 'gpt-4o' },
 *   tts: { provider: 'elevenlabs', voice: 'EXAVITQu4vr4xnSDxMaL' },
 * }, {
 *   onSTTResult: (result) => console.log('Transcript:', result.text),
 *   onTTSChunk: (chunk) => playAudio(chunk),
 * });
 *
 * await manager.connectSTT();
 * await manager.startSTTStreaming();
 * ```
 */

// ===== Type Exports =====

export type {
  // Provider info
  ProviderType,
  ProviderInfo,

  // STT types
  WordTiming,
  STTResult,
  STTEndpointing,
  STTConfig,
  STTProvider,
  STTProviderName,
  STTProviderConfig,

  // LLM types
  ToolCall,
  ToolDefinition,
  FinishReason,
  LLMToken,
  MessageRole,
  Message,
  LLMConfig,
  LLMProvider,
  LLMProviderName,
  LLMProviderConfig,

  // TTS types
  AudioFormat,
  AudioChunk,
  TTSConfig,
  TTSProvider,
  TTSProviderName,
  TTSProviderConfig,

  // Provider registry
  ProviderConfig,

  // Audio configuration
  AudioConfig,

  // Manager types
  ProviderManagerState,
  ProviderManagerActions,
} from './types';

export {
  defaultSTTConfigs,
  defaultLLMConfigs,
  defaultTTSConfigs,
  providerAudioRequirements,
} from './types';

// ===== Provider Exports =====

// OpenAI Realtime (WebRTC - STT+LLM+TTS combined)
export {
  OpenAIRealtimeProvider,
  getOpenAIRealtimeProvider,
  type RealtimeConfig,
  type RealtimeEventHandlers,
} from './openai-realtime';

// Deepgram STT (WebSocket)
export {
  DeepgramSTTProvider,
  getDeepgramSTTProvider,
} from './deepgram-stt';

// ElevenLabs TTS (WebSocket streaming)
export {
  ElevenLabsTTSProvider,
  getElevenLabsTTSProvider,
} from './elevenlabs-tts';

// ===== Manager Export =====

export {
  ProviderManager,
  getProviderManager,
  type ProviderManagerEvents,
} from './manager';
