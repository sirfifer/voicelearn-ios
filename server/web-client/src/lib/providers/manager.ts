/**
 * Provider Manager
 *
 * Manages the lifecycle and switching of STT, LLM, and TTS providers.
 * Provides a unified interface for voice pipeline operations.
 */

import type {
  ProviderConfig,
  ProviderManagerState,
  STTProviderName,
  LLMProviderName,
  TTSProviderName,
  STTProviderConfig,
  LLMProviderConfig,
  TTSProviderConfig,
  STTResult,
  AudioChunk,
} from './types';

import { OpenAIRealtimeProvider, getOpenAIRealtimeProvider } from './openai-realtime';
import { DeepgramSTTProvider, getDeepgramSTTProvider } from './deepgram-stt';
import { ElevenLabsTTSProvider, getElevenLabsTTSProvider } from './elevenlabs-tts';

// ===== Types =====

export interface ProviderManagerEvents {
  onSTTConnected?: () => void;
  onSTTDisconnected?: () => void;
  onSTTResult?: (result: STTResult) => void;
  onTTSStart?: () => void;
  onTTSChunk?: (chunk: AudioChunk) => void;
  onTTSComplete?: () => void;
  onError?: (error: Error, source: 'stt' | 'llm' | 'tts') => void;
  onStateChange?: (state: ProviderManagerState) => void;
}

// ===== Provider Manager =====

export class ProviderManager {
  private state: ProviderManagerState = {
    stt: {
      provider: 'deepgram',
      isConnected: false,
      isStreaming: false,
    },
    llm: {
      provider: 'openai',
      isGenerating: false,
    },
    tts: {
      provider: 'elevenlabs',
      isPlaying: false,
      queue: 0,
    },
  };

  private config: ProviderConfig | null = null;
  private events: ProviderManagerEvents = {};

  // Provider instances
  private realtimeProvider: OpenAIRealtimeProvider | null = null;
  private sttProvider: DeepgramSTTProvider | null = null;
  private ttsProvider: ElevenLabsTTSProvider | null = null;

  // Stream iterators
  private sttIterator: AsyncIterator<STTResult> | null = null;
  private ttsIterator: AsyncIterator<AudioChunk> | null = null;

  /**
   * Configure providers and event handlers.
   */
  async configure(config: ProviderConfig, events: ProviderManagerEvents = {}): Promise<void> {
    this.config = config;
    this.events = events;

    // Update state with configured providers
    this.updateState({
      stt: { ...this.state.stt, provider: config.stt.provider },
      llm: { ...this.state.llm, provider: config.llm.provider },
      tts: { ...this.state.tts, provider: config.tts.provider },
    });
  }

  /**
   * Get the current provider state.
   */
  getState(): ProviderManagerState {
    return { ...this.state };
  }

  /**
   * Connect STT provider.
   */
  async connectSTT(): Promise<void> {
    if (!this.config) {
      throw new Error('Provider manager not configured');
    }

    try {
      const sttConfig = this.config.stt;

      if (sttConfig.provider === 'openai-realtime') {
        // Use OpenAI Realtime (combined STT+LLM+TTS)
        this.realtimeProvider = getOpenAIRealtimeProvider();
        await this.realtimeProvider.connect(
          {
            model: sttConfig.model,
          },
          {
            onSessionCreated: () => {
              this.updateState({
                stt: { ...this.state.stt, isConnected: true },
              });
              this.events.onSTTConnected?.();
            },
            onTranscript: (result) => {
              this.events.onSTTResult?.(result);
            },
            onError: (error) => {
              this.events.onError?.(error, 'stt');
            },
            onDisconnect: () => {
              this.updateState({
                stt: { ...this.state.stt, isConnected: false, isStreaming: false },
              });
              this.events.onSTTDisconnected?.();
            },
          }
        );
      } else if (sttConfig.provider === 'deepgram') {
        // Use Deepgram STT
        this.sttProvider = getDeepgramSTTProvider();
        await this.sttProvider.connect({
          sampleRate: 16000,
          channels: 1,
          model: sttConfig.model,
          language: sttConfig.language,
          interimResults: sttConfig.interimResults,
        });

        this.updateState({
          stt: { ...this.state.stt, isConnected: true },
        });
        this.events.onSTTConnected?.();
      }
    } catch (error) {
      this.events.onError?.(error instanceof Error ? error : new Error(String(error)), 'stt');
      throw error;
    }
  }

  /**
   * Start STT streaming.
   */
  async startSTTStreaming(): Promise<void> {
    if (this.state.stt.provider === 'openai-realtime') {
      // OpenAI Realtime handles streaming automatically
      this.updateState({
        stt: { ...this.state.stt, isStreaming: true },
      });
      return;
    }

    if (!this.sttProvider) {
      throw new Error('STT provider not connected');
    }

    this.updateState({
      stt: { ...this.state.stt, isStreaming: true },
    });

    // Start consuming the async iterator
    this.sttIterator = this.sttProvider.startStreaming()[Symbol.asyncIterator]();

    // Process results in background
    this.processSTTResults();
  }

  /**
   * Send audio to STT provider.
   */
  sendAudio(buffer: ArrayBuffer): void {
    if (this.state.stt.provider === 'openai-realtime') {
      // OpenAI Realtime receives audio via WebRTC track
      return;
    }

    this.sttProvider?.sendAudio(buffer);
  }

  /**
   * Stop STT streaming.
   */
  async stopSTTStreaming(): Promise<STTResult | null> {
    this.updateState({
      stt: { ...this.state.stt, isStreaming: false },
    });

    if (this.state.stt.provider === 'openai-realtime') {
      return null;
    }

    return this.sttProvider?.stopStreaming() ?? null;
  }

  /**
   * Disconnect STT provider.
   */
  disconnectSTT(): void {
    if (this.realtimeProvider) {
      this.realtimeProvider.disconnect();
      this.realtimeProvider = null;
    }

    if (this.sttProvider) {
      this.sttProvider.disconnect();
      this.sttProvider = null;
    }

    this.sttIterator = null;

    this.updateState({
      stt: { ...this.state.stt, isConnected: false, isStreaming: false },
    });
    this.events.onSTTDisconnected?.();
  }

  /**
   * Synthesize text to speech.
   */
  async synthesize(text: string): Promise<void> {
    if (!this.config) {
      throw new Error('Provider manager not configured');
    }

    try {
      if (this.state.tts.provider === 'openai-realtime') {
        // OpenAI Realtime handles TTS via the same connection
        this.realtimeProvider?.sendText(text);
        return;
      }

      // Use ElevenLabs TTS
      this.ttsProvider = getElevenLabsTTSProvider();
      this.ttsProvider.configure({
        voice: this.config.tts.voice,
        voiceId: this.config.tts.voice,
        stability: this.config.tts.stability,
        similarityBoost: this.config.tts.similarityBoost,
      });

      this.updateState({
        tts: { ...this.state.tts, isPlaying: true, queue: this.state.tts.queue + 1 },
      });
      this.events.onTTSStart?.();

      // Stream audio chunks
      for await (const chunk of this.ttsProvider.synthesize(text)) {
        this.events.onTTSChunk?.(chunk);
      }

      this.updateState({
        tts: { ...this.state.tts, queue: Math.max(0, this.state.tts.queue - 1) },
      });

      if (this.state.tts.queue === 0) {
        this.updateState({
          tts: { ...this.state.tts, isPlaying: false },
        });
        this.events.onTTSComplete?.();
      }
    } catch (error) {
      this.events.onError?.(error instanceof Error ? error : new Error(String(error)), 'tts');
      throw error;
    }
  }

  /**
   * Cancel TTS playback.
   */
  cancelTTS(): void {
    if (this.state.tts.provider === 'openai-realtime') {
      this.realtimeProvider?.cancelResponse();
    } else {
      this.ttsProvider?.cancel();
    }

    this.updateState({
      tts: { ...this.state.tts, isPlaying: false, queue: 0 },
    });
  }

  /**
   * Switch STT provider.
   */
  async switchSTT(provider: STTProviderName, config?: Partial<STTProviderConfig>): Promise<void> {
    // Disconnect current provider
    this.disconnectSTT();

    // Update config
    if (this.config) {
      this.config.stt = { ...this.config.stt, provider, ...config };
    }

    this.updateState({
      stt: { ...this.state.stt, provider },
    });

    // Connect new provider
    await this.connectSTT();
  }

  /**
   * Switch LLM provider.
   */
  async switchLLM(provider: LLMProviderName, config?: Partial<LLMProviderConfig>): Promise<void> {
    if (this.config) {
      this.config.llm = { ...this.config.llm, provider, ...config };
    }

    this.updateState({
      llm: { ...this.state.llm, provider },
    });
  }

  /**
   * Switch TTS provider.
   */
  async switchTTS(provider: TTSProviderName, config?: Partial<TTSProviderConfig>): Promise<void> {
    // Cancel any ongoing TTS
    this.cancelTTS();

    if (this.config) {
      this.config.tts = { ...this.config.tts, provider, ...config };
    }

    this.updateState({
      tts: { ...this.state.tts, provider },
    });
  }

  /**
   * Get provider costs.
   */
  getProviderCosts(): {
    stt: { costPerHour: number };
    llm: { costPerInputToken: number; costPerOutputToken: number };
    tts: { costPerCharacter: number };
  } {
    return {
      stt: {
        costPerHour:
          this.state.stt.provider === 'openai-realtime' ? 0.06 : 0.0043 * 60,
      },
      llm: {
        costPerInputToken: 0.0000025, // GPT-4o approximate
        costPerOutputToken: 0.00001,
      },
      tts: {
        costPerCharacter: 0.00003, // ElevenLabs approximate
      },
    };
  }

  /**
   * Disconnect all providers and clean up.
   */
  dispose(): void {
    this.disconnectSTT();
    this.cancelTTS();
    this.config = null;
    this.events = {};
  }

  // ===== Private Methods =====

  private updateState(partial: Partial<ProviderManagerState>): void {
    this.state = { ...this.state, ...partial };
    this.events.onStateChange?.(this.state);
  }

  private async processSTTResults(): Promise<void> {
    if (!this.sttIterator) return;

    try {
      while (this.state.stt.isStreaming) {
        const { value, done } = await this.sttIterator.next();
        if (done) break;
        if (value) {
          this.events.onSTTResult?.(value);
        }
      }
    } catch (error) {
      this.events.onError?.(error instanceof Error ? error : new Error(String(error)), 'stt');
    }
  }
}

// ===== Singleton Instance =====

let instance: ProviderManager | null = null;

export function getProviderManager(): ProviderManager {
  if (!instance) {
    instance = new ProviderManager();
  }
  return instance;
}
