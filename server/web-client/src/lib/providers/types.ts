/**
 * Provider Types
 *
 * Re-export all provider types from the centralized types module.
 * This allows components to import provider types from @/lib/providers.
 */

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
} from '@/types/providers';

export {
  // Default configurations
  defaultSTTConfigs,
  defaultLLMConfigs,
  defaultTTSConfigs,
  providerAudioRequirements,
} from '@/types/providers';
