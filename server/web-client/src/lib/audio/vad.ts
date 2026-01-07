/**
 * Voice Activity Detection (VAD)
 *
 * Detects speech in audio streams using energy-based analysis.
 * Supports both real-time processing and batch analysis.
 */

// ===== Types =====

export interface VADConfig {
  /** Sample rate of audio data */
  sampleRate?: number;
  /** Frame size in samples */
  frameSize?: number;
  /** Energy threshold for speech detection (0-1) */
  energyThreshold?: number;
  /** Minimum speech duration in ms */
  minSpeechDuration?: number;
  /** Maximum silence duration before end of speech (ms) */
  maxSilenceDuration?: number;
  /** Number of frames to use for smoothing */
  smoothingFrames?: number;
}

export interface VADState {
  isSpeaking: boolean;
  speechStartTime: number | null;
  silenceStartTime: number | null;
  currentEnergy: number;
  averageEnergy: number;
}

export interface VADEvent {
  type: 'speech_start' | 'speech_end' | 'speech_continued' | 'silence';
  timestamp: number;
  duration?: number;
  energy: number;
}

export type VADCallback = (event: VADEvent) => void;

// ===== VAD Processor =====

export class VADProcessor {
  private config: Required<VADConfig>;
  private state: VADState;
  private energyHistory: number[] = [];
  private callback: VADCallback | null = null;
  private startTime: number = 0;

  constructor(config: VADConfig = {}) {
    this.config = {
      sampleRate: config.sampleRate ?? 16000,
      frameSize: config.frameSize ?? 512,
      energyThreshold: config.energyThreshold ?? 0.01,
      minSpeechDuration: config.minSpeechDuration ?? 100,
      maxSilenceDuration: config.maxSilenceDuration ?? 500,
      smoothingFrames: config.smoothingFrames ?? 5,
    };

    this.state = {
      isSpeaking: false,
      speechStartTime: null,
      silenceStartTime: null,
      currentEnergy: 0,
      averageEnergy: 0,
    };

    this.startTime = Date.now();
  }

  /**
   * Start VAD processing with a callback for events.
   */
  start(callback: VADCallback): void {
    this.callback = callback;
    this.startTime = Date.now();
    this.reset();
  }

  /**
   * Stop VAD processing.
   */
  stop(): void {
    if (this.state.isSpeaking) {
      this.emitEvent('speech_end');
    }
    this.callback = null;
  }

  /**
   * Process an audio frame.
   * @param samples - Float32Array of audio samples
   */
  process(samples: Float32Array): VADEvent | null {
    const energy = this.calculateEnergy(samples);
    this.updateEnergyHistory(energy);

    const smoothedEnergy = this.getSmoothedEnergy();
    this.state.currentEnergy = smoothedEnergy;

    const isSpeech = smoothedEnergy > this.config.energyThreshold;
    const now = Date.now();

    let event: VADEvent | null = null;

    if (isSpeech) {
      if (!this.state.isSpeaking) {
        // Start of speech
        this.state.speechStartTime = now;
        this.state.silenceStartTime = null;
        this.state.isSpeaking = true;
        event = this.emitEvent('speech_start');
      } else {
        // Continued speech - reset silence timer
        this.state.silenceStartTime = null;
        event = this.emitEvent('speech_continued');
      }
    } else {
      if (this.state.isSpeaking) {
        if (!this.state.silenceStartTime) {
          // Start of silence during speech
          this.state.silenceStartTime = now;
        } else if (now - this.state.silenceStartTime > this.config.maxSilenceDuration) {
          // End of speech (silence exceeded threshold)
          const duration = now - (this.state.speechStartTime ?? now);
          if (duration >= this.config.minSpeechDuration) {
            event = this.emitEvent('speech_end', duration);
          }
          this.state.isSpeaking = false;
          this.state.speechStartTime = null;
          this.state.silenceStartTime = null;
        }
      } else {
        event = this.emitEvent('silence');
      }
    }

    return event;
  }

  /**
   * Process a buffer of audio data.
   * Splits into frames and processes each.
   */
  processBuffer(buffer: Float32Array): VADEvent[] {
    const events: VADEvent[] = [];
    const frameSize = this.config.frameSize;

    for (let i = 0; i < buffer.length; i += frameSize) {
      const frame = buffer.slice(i, i + frameSize);
      const event = this.process(frame);
      if (event) {
        events.push(event);
      }
    }

    return events;
  }

  /**
   * Get current VAD state.
   */
  getState(): VADState {
    return { ...this.state };
  }

  /**
   * Reset VAD state.
   */
  reset(): void {
    this.state = {
      isSpeaking: false,
      speechStartTime: null,
      silenceStartTime: null,
      currentEnergy: 0,
      averageEnergy: 0,
    };
    this.energyHistory = [];
    this.startTime = Date.now();
  }

  /**
   * Update configuration.
   */
  configure(config: Partial<VADConfig>): void {
    Object.assign(this.config, config);
  }

  // ===== Private Methods =====

  private calculateEnergy(samples: Float32Array): number {
    let sum = 0;
    for (let i = 0; i < samples.length; i++) {
      sum += samples[i] * samples[i];
    }
    return Math.sqrt(sum / samples.length);
  }

  private updateEnergyHistory(energy: number): void {
    this.energyHistory.push(energy);
    if (this.energyHistory.length > this.config.smoothingFrames) {
      this.energyHistory.shift();
    }

    // Update average energy (for adaptive threshold)
    this.state.averageEnergy =
      this.energyHistory.reduce((a, b) => a + b, 0) / this.energyHistory.length;
  }

  private getSmoothedEnergy(): number {
    if (this.energyHistory.length === 0) return 0;
    return this.energyHistory.reduce((a, b) => a + b, 0) / this.energyHistory.length;
  }

  private emitEvent(type: VADEvent['type'], duration?: number): VADEvent {
    const event: VADEvent = {
      type,
      timestamp: Date.now() - this.startTime,
      energy: this.state.currentEnergy,
      duration,
    };

    this.callback?.(event);
    return event;
  }
}

// ===== Adaptive VAD =====

/**
 * Adaptive VAD that adjusts threshold based on ambient noise.
 */
export class AdaptiveVAD extends VADProcessor {
  private noiseFloor: number = 0;
  private noiseFrames: number[] = [];
  private readonly NOISE_FRAME_COUNT = 50;
  private isCalibrated = false;

  /**
   * Calibrate the noise floor from current audio.
   * Call this during a period of silence.
   */
  calibrate(samples: Float32Array): void {
    const energy = this['calculateEnergy'](samples);
    this.noiseFrames.push(energy);

    if (this.noiseFrames.length > this.NOISE_FRAME_COUNT) {
      this.noiseFrames.shift();
    }

    if (this.noiseFrames.length >= this.NOISE_FRAME_COUNT) {
      // Calculate noise floor as 90th percentile
      const sorted = [...this.noiseFrames].sort((a, b) => a - b);
      this.noiseFloor = sorted[Math.floor(sorted.length * 0.9)];

      // Set threshold to 2x noise floor
      this.configure({
        energyThreshold: Math.max(0.01, this.noiseFloor * 2),
      });

      this.isCalibrated = true;
    }
  }

  /**
   * Get calibration status.
   */
  get calibrated(): boolean {
    return this.isCalibrated;
  }

  /**
   * Get current noise floor.
   */
  getNoiseFloor(): number {
    return this.noiseFloor;
  }
}

// ===== Factory Functions =====

export function createVAD(config?: VADConfig): VADProcessor {
  return new VADProcessor(config);
}

export function createAdaptiveVAD(config?: VADConfig): AdaptiveVAD {
  return new AdaptiveVAD(config);
}
