/**
 * Deepgram STT Provider
 *
 * WebSocket-based provider for Deepgram's speech-to-text API.
 * Supports real-time transcription with interim results.
 */

import type { STTResult, STTConfig, STTProvider } from './types';

// ===== Types =====

interface DeepgramResponse {
  type: 'Results' | 'Metadata' | 'Error';
  channel?: {
    alternatives: Array<{
      transcript: string;
      confidence: number;
      words?: Array<{
        word: string;
        start: number;
        end: number;
        confidence: number;
      }>;
    }>;
  };
  is_final?: boolean;
  speech_final?: boolean;
  error?: string;
}

interface DeepgramConfig extends STTConfig {
  model?: string;
  punctuate?: boolean;
  smartFormat?: boolean;
  diarize?: boolean;
  utteranceEndMs?: number;
}

// ===== Deepgram STT Provider =====

export class DeepgramSTTProvider implements STTProvider {
  readonly name = 'deepgram';
  readonly costPerHour = 0.0043; // $0.0043/min Nova-2
  readonly isStreaming = true;

  private socket: WebSocket | null = null;
  private config: DeepgramConfig | null = null;
  private isConnected = false;
  private resultQueue: STTResult[] = [];
  private resolvers: Array<(value: STTResult | null) => void> = [];

  /**
   * Connect to Deepgram's WebSocket API.
   */
  async connect(config: DeepgramConfig): Promise<void> {
    this.config = config;

    // Get API key from server (never expose to client directly)
    const keyResponse = await fetch('/api/providers/deepgram/key', {
      method: 'POST',
    });

    if (!keyResponse.ok) {
      throw new Error('Failed to get Deepgram API key');
    }

    const { key } = await keyResponse.json();

    // Build WebSocket URL with parameters
    const params = new URLSearchParams({
      model: config.model || 'nova-2',
      language: config.language || 'en-US',
      sample_rate: String(config.sampleRate || 16000),
      channels: String(config.channels || 1),
      encoding: 'linear16',
      punctuate: String(config.punctuate !== false),
      smart_format: String(config.smartFormat !== false),
      interim_results: String(config.interimResults !== false),
      utterance_end_ms: String(config.utteranceEndMs || 1000),
      vad_events: 'true',
    });

    const url = `wss://api.deepgram.com/v1/listen?${params}`;

    return new Promise((resolve, reject) => {
      this.socket = new WebSocket(url, ['token', key]);

      this.socket.onopen = () => {
        this.isConnected = true;
        console.debug('[Deepgram] Connected');
        resolve();
      };

      this.socket.onclose = (event) => {
        this.isConnected = false;
        console.debug('[Deepgram] Disconnected:', event.code, event.reason);
        // Resolve any pending iterators
        this.resolvers.forEach((resolve) => resolve(null));
        this.resolvers = [];
      };

      this.socket.onerror = (error) => {
        console.error('[Deepgram] WebSocket error:', error);
        reject(new Error('WebSocket connection failed'));
      };

      this.socket.onmessage = (event) => {
        this.handleMessage(event.data);
      };
    });
  }

  /**
   * Start streaming transcription.
   * Returns an async iterator that yields STT results.
   */
  async *startStreaming(): AsyncIterable<STTResult> {
    while (this.isConnected) {
      const result = await this.waitForResult();
      if (result === null) break;
      yield result;
    }
  }

  /**
   * Send audio data to Deepgram.
   * Audio should be PCM16 at the configured sample rate.
   */
  sendAudio(buffer: ArrayBuffer): void {
    if (this.socket?.readyState === WebSocket.OPEN) {
      this.socket.send(buffer);
    }
  }

  /**
   * Stop streaming and get the final result.
   */
  async stopStreaming(): Promise<STTResult | null> {
    if (this.socket?.readyState === WebSocket.OPEN) {
      // Send close message to finalize transcription
      this.socket.send(JSON.stringify({ type: 'CloseStream' }));

      // Wait for final result
      return new Promise((resolve) => {
        const timeout = setTimeout(() => resolve(null), 2000);

        const checkFinal = () => {
          const finalResult = this.resultQueue.find((r) => r.isFinal);
          if (finalResult) {
            clearTimeout(timeout);
            resolve(finalResult);
          } else {
            setTimeout(checkFinal, 100);
          }
        };

        checkFinal();
      });
    }
    return null;
  }

  /**
   * Disconnect from Deepgram.
   */
  disconnect(): void {
    if (this.socket) {
      this.socket.close();
      this.socket = null;
    }
    this.isConnected = false;
    this.resultQueue = [];
    this.resolvers = [];
  }

  // ===== Private Methods =====

  private handleMessage(data: string): void {
    try {
      const response = JSON.parse(data) as DeepgramResponse;

      if (response.type === 'Error') {
        console.error('[Deepgram] Error:', response.error);
        return;
      }

      if (response.type === 'Results' && response.channel) {
        const alternative = response.channel.alternatives[0];
        if (!alternative) return;

        const result: STTResult = {
          text: alternative.transcript,
          isFinal: response.is_final || response.speech_final || false,
          confidence: alternative.confidence,
          words: alternative.words?.map((w) => ({
            word: w.word,
            start: w.start,
            end: w.end,
            confidence: w.confidence,
          })),
          language: this.config?.language,
        };

        // Add to queue and resolve any waiting iterators
        this.resultQueue.push(result);

        if (this.resolvers.length > 0) {
          const resolver = this.resolvers.shift();
          resolver?.(this.resultQueue.shift() || null);
        }
      }
    } catch (error) {
      console.error('[Deepgram] Failed to parse message:', error);
    }
  }

  private waitForResult(): Promise<STTResult | null> {
    // If there are queued results, return immediately
    if (this.resultQueue.length > 0) {
      return Promise.resolve(this.resultQueue.shift() || null);
    }

    // Wait for next result
    return new Promise((resolve) => {
      this.resolvers.push(resolve);
    });
  }
}

// ===== Singleton Instance =====

let instance: DeepgramSTTProvider | null = null;

export function getDeepgramSTTProvider(): DeepgramSTTProvider {
  if (!instance) {
    instance = new DeepgramSTTProvider();
  }
  return instance;
}
