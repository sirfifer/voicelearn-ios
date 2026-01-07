/**
 * ElevenLabs TTS Provider
 *
 * Streaming text-to-speech provider using ElevenLabs API.
 * Supports WebSocket streaming for low-latency audio.
 */

import type { AudioChunk, TTSConfig, TTSProvider } from './types';

// ===== Types =====

interface ElevenLabsConfig extends TTSConfig {
  voiceId?: string;
  modelId?: string;
  stability?: number;
  similarityBoost?: number;
  style?: number;
  useSpeakerBoost?: boolean;
}

interface ElevenLabsMessage {
  audio?: string; // Base64 encoded audio
  isFinal?: boolean;
  normalizedAlignment?: {
    char_start_times_ms: number[];
    chars_durations_ms: number[];
    chars: string[];
  };
  alignment?: {
    char_start_times_ms: number[];
    chars_durations_ms: number[];
    chars: string[];
  };
}

// ===== ElevenLabs TTS Provider =====

export class ElevenLabsTTSProvider implements TTSProvider {
  readonly name = 'elevenlabs';
  readonly costPerCharacter = 0.00003; // Approximate

  private socket: WebSocket | null = null;
  private config: ElevenLabsConfig | null = null;
  private audioContext: AudioContext | null = null;
  private audioQueue: AudioBuffer[] = [];
  private isPlaying = false;
  private isCancelled = false;

  /**
   * Configure the provider.
   */
  configure(config: ElevenLabsConfig): void {
    this.config = config;
  }

  /**
   * Synthesize text to speech.
   * Returns an async iterator of audio chunks.
   */
  async *synthesize(text: string): AsyncIterable<AudioChunk> {
    this.isCancelled = false;

    // Get API key from server
    const keyResponse = await fetch('/api/providers/elevenlabs/key', {
      method: 'POST',
    });

    if (!keyResponse.ok) {
      throw new Error('Failed to get ElevenLabs API key');
    }

    const { key } = await keyResponse.json();

    const voiceId = this.config?.voiceId || 'EXAVITQu4vr4xnSDxMaL'; // Default: Bella
    const modelId = this.config?.modelId || 'eleven_turbo_v2_5';

    // Use WebSocket for streaming
    const wsUrl = `wss://api.elevenlabs.io/v1/text-to-speech/${voiceId}/stream-input?model_id=${modelId}&output_format=mp3_44100_128`;

    this.socket = new WebSocket(wsUrl);

    const chunks: AudioChunk[] = [];
    let resolveNext: ((value: AudioChunk | null) => void) | null = null;

    this.socket.onopen = () => {
      // Send initial configuration
      this.socket!.send(
        JSON.stringify({
          text: ' ', // Initial space to start stream
          voice_settings: {
            stability: this.config?.stability ?? 0.5,
            similarity_boost: this.config?.similarityBoost ?? 0.75,
            style: this.config?.style ?? 0,
            use_speaker_boost: this.config?.useSpeakerBoost ?? true,
          },
          xi_api_key: key,
        })
      );

      // Send the actual text
      this.socket!.send(
        JSON.stringify({
          text: text,
          try_trigger_generation: true,
        })
      );

      // Send end of stream marker
      this.socket!.send(JSON.stringify({ text: '' }));
    };

    this.socket.onmessage = (event) => {
      try {
        const message = JSON.parse(event.data) as ElevenLabsMessage;

        if (message.audio) {
          // Decode base64 audio
          const binaryString = atob(message.audio);
          const bytes = new Uint8Array(binaryString.length);
          for (let i = 0; i < binaryString.length; i++) {
            bytes[i] = binaryString.charCodeAt(i);
          }

          const chunk: AudioChunk = {
            audio: bytes.buffer,
            format: 'mp3',
            sampleRate: 44100,
            isFinal: message.isFinal ?? false,
          };

          if (resolveNext) {
            resolveNext(chunk);
            resolveNext = null;
          } else {
            chunks.push(chunk);
          }
        }

        if (message.isFinal) {
          if (resolveNext) {
            resolveNext(null);
            resolveNext = null;
          }
        }
      } catch (error) {
        console.error('[ElevenLabs] Failed to parse message:', error);
      }
    };

    this.socket.onerror = (error) => {
      console.error('[ElevenLabs] WebSocket error:', error);
      if (resolveNext) {
        resolveNext(null);
        resolveNext = null;
      }
    };

    this.socket.onclose = () => {
      if (resolveNext) {
        resolveNext(null);
        resolveNext = null;
      }
    };

    // Yield chunks as they arrive
    while (!this.isCancelled) {
      if (chunks.length > 0) {
        const chunk = chunks.shift()!;
        yield chunk;
        if (chunk.isFinal) break;
      } else {
        const chunk = await new Promise<AudioChunk | null>((resolve) => {
          resolveNext = resolve;
          // Timeout after 30 seconds
          setTimeout(() => resolve(null), 30000);
        });

        if (chunk === null) break;
        yield chunk;
        if (chunk.isFinal) break;
      }
    }

    this.socket?.close();
    this.socket = null;
  }

  /**
   * Flush any buffered audio.
   */
  async flush(): Promise<void> {
    // ElevenLabs handles flushing internally via WebSocket
    // This is a no-op but required by the interface
  }

  /**
   * Cancel ongoing synthesis.
   */
  cancel(): void {
    this.isCancelled = true;
    if (this.socket) {
      this.socket.close();
      this.socket = null;
    }
  }

  /**
   * Play audio chunk directly (helper method).
   */
  async playChunk(chunk: AudioChunk): Promise<void> {
    if (!this.audioContext) {
      this.audioContext = new AudioContext({ sampleRate: chunk.sampleRate });
    }

    try {
      const audioBuffer = await this.audioContext.decodeAudioData(
        chunk.audio.slice(0) // Clone to avoid detached buffer issues
      );

      const source = this.audioContext.createBufferSource();
      source.buffer = audioBuffer;
      source.connect(this.audioContext.destination);
      source.start();

      // Wait for playback to finish
      return new Promise((resolve) => {
        source.onended = () => resolve();
      });
    } catch (error) {
      console.error('[ElevenLabs] Failed to play audio:', error);
    }
  }

  /**
   * Get available voices.
   */
  static async getVoices(): Promise<Array<{ id: string; name: string }>> {
    const response = await fetch('/api/providers/elevenlabs/voices');

    if (!response.ok) {
      throw new Error('Failed to get voices');
    }

    const { voices } = await response.json();
    return voices;
  }
}

// ===== Singleton Instance =====

let instance: ElevenLabsTTSProvider | null = null;

export function getElevenLabsTTSProvider(): ElevenLabsTTSProvider {
  if (!instance) {
    instance = new ElevenLabsTTSProvider();
  }
  return instance;
}
