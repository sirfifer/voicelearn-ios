/**
 * Audio Context Manager
 *
 * Manages the AudioContext lifecycle for the web client.
 * Handles browser autoplay policies and context state management.
 */

// ===== Types =====

export interface AudioContextConfig {
  sampleRate?: number;
  latencyHint?: 'interactive' | 'balanced' | 'playback';
}

export interface AudioContextState {
  isInitialized: boolean;
  isRunning: boolean;
  sampleRate: number;
  baseLatency: number;
  outputLatency: number;
}

// ===== Audio Context Manager =====

class AudioContextManager {
  private context: AudioContext | null = null;
  private config: AudioContextConfig = {};

  /**
   * Initialize the audio context.
   * Should be called in response to a user gesture (click, tap).
   */
  async initialize(config: AudioContextConfig = {}): Promise<AudioContext> {
    this.config = config;

    // If context exists and is running, return it
    if (this.context?.state === 'running') {
      return this.context;
    }

    // If context exists but suspended, resume it
    if (this.context?.state === 'suspended') {
      await this.resume();
      return this.context;
    }

    // Create new context
    this.context = new AudioContext({
      sampleRate: config.sampleRate || 48000,
      latencyHint: config.latencyHint || 'interactive',
    });

    // Resume if suspended (Safari requires this after user gesture)
    if (this.context.state === 'suspended') {
      await this.context.resume();
    }

    console.debug('[Audio] Context initialized:', {
      sampleRate: this.context.sampleRate,
      state: this.context.state,
      baseLatency: this.context.baseLatency,
      outputLatency: this.context.outputLatency,
    });

    return this.context;
  }

  /**
   * Get the current audio context.
   * Creates one if it doesn't exist.
   */
  async getContext(): Promise<AudioContext> {
    if (!this.context) {
      return this.initialize(this.config);
    }
    return this.context;
  }

  /**
   * Resume the audio context.
   * Useful after browser suspends due to inactivity.
   */
  async resume(): Promise<void> {
    if (!this.context) {
      throw new Error('Audio context not initialized');
    }

    if (this.context.state === 'suspended') {
      await this.context.resume();
      console.debug('[Audio] Context resumed');
    }
  }

  /**
   * Suspend the audio context.
   * Useful to save power when not actively using audio.
   */
  async suspend(): Promise<void> {
    if (!this.context) return;

    if (this.context.state === 'running') {
      await this.context.suspend();
      console.debug('[Audio] Context suspended');
    }
  }

  /**
   * Close the audio context and release resources.
   */
  async close(): Promise<void> {
    if (!this.context) return;

    await this.context.close();
    this.context = null;
    console.debug('[Audio] Context closed');
  }

  /**
   * Get the current state of the audio context.
   */
  getState(): AudioContextState {
    if (!this.context) {
      return {
        isInitialized: false,
        isRunning: false,
        sampleRate: 0,
        baseLatency: 0,
        outputLatency: 0,
      };
    }

    return {
      isInitialized: true,
      isRunning: this.context.state === 'running',
      sampleRate: this.context.sampleRate,
      baseLatency: this.context.baseLatency,
      outputLatency: this.context.outputLatency,
    };
  }

  /**
   * Create an audio buffer from raw PCM data.
   */
  createBuffer(
    data: Float32Array | ArrayBuffer,
    sampleRate: number,
    channels: number = 1
  ): AudioBuffer {
    if (!this.context) {
      throw new Error('Audio context not initialized');
    }

    const floatData =
      data instanceof Float32Array
        ? data
        : new Float32Array(data);

    const buffer = this.context.createBuffer(
      channels,
      floatData.length / channels,
      sampleRate
    );

    // Copy data to each channel
    for (let channel = 0; channel < channels; channel++) {
      const channelData = buffer.getChannelData(channel);
      for (let i = 0; i < channelData.length; i++) {
        channelData[i] = floatData[i * channels + channel];
      }
    }

    return buffer;
  }

  /**
   * Play an audio buffer.
   */
  async playBuffer(buffer: AudioBuffer, volume: number = 1): Promise<void> {
    if (!this.context) {
      throw new Error('Audio context not initialized');
    }

    await this.resume();

    const source = this.context.createBufferSource();
    source.buffer = buffer;

    // Add gain node for volume control
    const gainNode = this.context.createGain();
    gainNode.gain.value = volume;

    source.connect(gainNode);
    gainNode.connect(this.context.destination);

    source.start();

    return new Promise((resolve) => {
      source.onended = () => resolve();
    });
  }

  /**
   * Decode audio data (MP3, WAV, etc.) to AudioBuffer.
   */
  async decodeAudioData(data: ArrayBuffer): Promise<AudioBuffer> {
    if (!this.context) {
      throw new Error('Audio context not initialized');
    }

    return this.context.decodeAudioData(data);
  }

  /**
   * Get the current time of the audio context.
   */
  getCurrentTime(): number {
    return this.context?.currentTime ?? 0;
  }
}

// ===== Singleton Instance =====

let instance: AudioContextManager | null = null;

export function getAudioContextManager(): AudioContextManager {
  if (!instance) {
    instance = new AudioContextManager();
  }
  return instance;
}

// ===== Helper Functions =====

/**
 * Convert Int16 PCM to Float32.
 */
export function int16ToFloat32(int16Array: Int16Array): Float32Array {
  const float32Array = new Float32Array(int16Array.length);
  for (let i = 0; i < int16Array.length; i++) {
    float32Array[i] = int16Array[i] / 32768;
  }
  return float32Array;
}

/**
 * Convert Float32 to Int16 PCM.
 */
export function float32ToInt16(float32Array: Float32Array): Int16Array {
  const int16Array = new Int16Array(float32Array.length);
  for (let i = 0; i < float32Array.length; i++) {
    const sample = Math.max(-1, Math.min(1, float32Array[i]));
    int16Array[i] = sample < 0 ? sample * 32768 : sample * 32767;
  }
  return int16Array;
}

/**
 * Resample audio data to a different sample rate.
 * Uses linear interpolation for simplicity.
 */
export function resample(
  data: Float32Array,
  fromRate: number,
  toRate: number
): Float32Array {
  if (fromRate === toRate) {
    return data;
  }

  const ratio = fromRate / toRate;
  const newLength = Math.ceil(data.length / ratio);
  const result = new Float32Array(newLength);

  for (let i = 0; i < newLength; i++) {
    const srcIndex = i * ratio;
    const index = Math.floor(srcIndex);
    const frac = srcIndex - index;

    if (index + 1 < data.length) {
      result[i] = data[index] * (1 - frac) + data[index + 1] * frac;
    } else {
      result[i] = data[index] ?? 0;
    }
  }

  return result;
}
