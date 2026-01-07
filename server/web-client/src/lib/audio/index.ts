/**
 * Audio Module
 *
 * This module provides audio processing utilities for the UnaMentis web client.
 * Includes AudioContext management, worklets for recording/playback, and VAD.
 *
 * @module lib/audio
 *
 * @example
 * ```tsx
 * import { getAudioContextManager, createAudioRecorder, createVAD } from '@/lib/audio';
 *
 * // Initialize audio context (must be in response to user gesture)
 * const contextManager = getAudioContextManager();
 * await contextManager.initialize();
 *
 * // Create recorder and VAD
 * const recorder = createAudioRecorder();
 * const vad = createVAD({ energyThreshold: 0.02 });
 *
 * // Start recording with VAD
 * await recorder.start({}, (chunk) => {
 *   const samples = new Float32Array(chunk);
 *   const event = vad.process(samples);
 *   if (event?.type === 'speech_start') {
 *     console.log('User started speaking');
 *   }
 * });
 * ```
 */

// ===== Audio Context =====

export {
  getAudioContextManager,
  int16ToFloat32,
  float32ToInt16,
  resample,
  type AudioContextConfig,
  type AudioContextState,
} from './context';

// ===== Audio Worklets =====

export {
  AudioRecorder,
  AudioPlayer,
  createAudioRecorder,
  createAudioPlayer,
  type AudioWorkletConfig,
  type AudioChunkCallback,
} from './worklets';

// ===== Voice Activity Detection =====

export {
  VADProcessor,
  AdaptiveVAD,
  createVAD,
  createAdaptiveVAD,
  type VADConfig,
  type VADState,
  type VADEvent,
  type VADCallback,
} from './vad';
