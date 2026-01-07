/**
 * Audio Worklets
 *
 * AudioWorklet processors for real-time audio processing.
 * Handles PCM conversion, resampling, and buffering.
 */

import { getAudioContextManager, float32ToInt16 } from './context';

// ===== Types =====

export interface AudioWorkletConfig {
  inputSampleRate?: number;
  outputSampleRate?: number;
  bufferSize?: number;
}

export type AudioChunkCallback = (chunk: ArrayBuffer) => void;

// ===== Worklet Processor Code =====

// This code runs in the AudioWorklet thread
const workletProcessorCode = `
class PCMProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.buffer = [];
    this.bufferSize = 4096; // Default buffer size

    this.port.onmessage = (event) => {
      if (event.data.type === 'config') {
        this.bufferSize = event.data.bufferSize || 4096;
      }
    };
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0];
    if (!input || !input[0]) return true;

    const channelData = input[0];

    // Accumulate samples
    for (let i = 0; i < channelData.length; i++) {
      this.buffer.push(channelData[i]);
    }

    // Send when buffer is full
    while (this.buffer.length >= this.bufferSize) {
      const chunk = new Float32Array(this.buffer.splice(0, this.bufferSize));
      this.port.postMessage({ type: 'audio', data: chunk });
    }

    return true;
  }
}

registerProcessor('pcm-processor', PCMProcessor);
`;

// ===== Audio Recorder =====

export class AudioRecorder {
  private stream: MediaStream | null = null;
  private workletNode: AudioWorkletNode | null = null;
  private sourceNode: MediaStreamAudioSourceNode | null = null;
  private isRecording = false;
  private config: AudioWorkletConfig = {};
  private onChunk: AudioChunkCallback | null = null;

  /**
   * Start recording audio from the microphone.
   */
  async start(config: AudioWorkletConfig = {}, onChunk: AudioChunkCallback): Promise<void> {
    if (this.isRecording) {
      throw new Error('Already recording');
    }

    this.config = config;
    this.onChunk = onChunk;

    try {
      // Get microphone access
      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          sampleRate: config.inputSampleRate || 48000,
          channelCount: 1,
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        },
      });

      // Get audio context
      const contextManager = getAudioContextManager();
      const context = await contextManager.getContext();

      // Load worklet if not already loaded
      await this.loadWorklet(context);

      // Create source from stream
      this.sourceNode = context.createMediaStreamSource(this.stream);

      // Create worklet node
      this.workletNode = new AudioWorkletNode(context, 'pcm-processor');

      // Configure worklet
      this.workletNode.port.postMessage({
        type: 'config',
        bufferSize: config.bufferSize || 4096,
      });

      // Handle audio chunks from worklet
      this.workletNode.port.onmessage = (event) => {
        if (event.data.type === 'audio') {
          const float32Data = event.data.data as Float32Array;

          // Convert to Int16 PCM
          const int16Data = float32ToInt16(float32Data);

          // Callback with the audio chunk (cast to ArrayBuffer for type safety)
          this.onChunk?.(int16Data.buffer as ArrayBuffer);
        }
      };

      // Connect nodes
      this.sourceNode.connect(this.workletNode);
      // Don't connect to destination - we just want to capture

      this.isRecording = true;
      console.debug('[Audio] Recording started');
    } catch (error) {
      this.cleanup();
      throw error;
    }
  }

  /**
   * Stop recording.
   */
  stop(): void {
    this.cleanup();
    this.isRecording = false;
    console.debug('[Audio] Recording stopped');
  }

  /**
   * Check if currently recording.
   */
  get recording(): boolean {
    return this.isRecording;
  }

  /**
   * Mute/unmute the microphone.
   */
  setMuted(muted: boolean): void {
    if (this.stream) {
      this.stream.getAudioTracks().forEach((track) => {
        track.enabled = !muted;
      });
    }
  }

  /**
   * Get whether the microphone is muted.
   */
  get isMuted(): boolean {
    if (!this.stream) return true;
    const track = this.stream.getAudioTracks()[0];
    return !track?.enabled;
  }

  // ===== Private Methods =====

  private async loadWorklet(context: AudioContext): Promise<void> {
    try {
      // Check if worklet is already registered by trying to create a node
      // This will fail silently if not registered
      const testNode = new AudioWorkletNode(context, 'pcm-processor');
      testNode.disconnect();
    } catch {
      // Worklet not registered, load it
      const blob = new Blob([workletProcessorCode], { type: 'application/javascript' });
      const url = URL.createObjectURL(blob);
      await context.audioWorklet.addModule(url);
      URL.revokeObjectURL(url);
    }
  }

  private cleanup(): void {
    if (this.sourceNode) {
      this.sourceNode.disconnect();
      this.sourceNode = null;
    }

    if (this.workletNode) {
      this.workletNode.disconnect();
      this.workletNode = null;
    }

    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }

    this.onChunk = null;
  }
}

// ===== Audio Player =====

export class AudioPlayer {
  private queue: ArrayBuffer[] = [];
  private isPlaying = false;
  private currentSource: AudioBufferSourceNode | null = null;
  private gainNode: GainNode | null = null;
  private volume = 1;

  /**
   * Enqueue audio data for playback.
   */
  async enqueue(data: ArrayBuffer, sampleRate: number = 24000): Promise<void> {
    this.queue.push(data);

    if (!this.isPlaying) {
      this.playNext(sampleRate);
    }
  }

  /**
   * Set playback volume (0-1).
   */
  setVolume(volume: number): void {
    this.volume = Math.max(0, Math.min(1, volume));
    if (this.gainNode) {
      this.gainNode.gain.value = this.volume;
    }
  }

  /**
   * Stop playback and clear queue.
   */
  stop(): void {
    this.queue = [];
    if (this.currentSource) {
      this.currentSource.stop();
      this.currentSource = null;
    }
    this.isPlaying = false;
  }

  /**
   * Pause playback.
   */
  async pause(): Promise<void> {
    const contextManager = getAudioContextManager();
    await contextManager.suspend();
  }

  /**
   * Resume playback.
   */
  async resume(): Promise<void> {
    const contextManager = getAudioContextManager();
    await contextManager.resume();
  }

  /**
   * Get whether currently playing.
   */
  get playing(): boolean {
    return this.isPlaying;
  }

  /**
   * Get queue length.
   */
  get queueLength(): number {
    return this.queue.length;
  }

  // ===== Private Methods =====

  private async playNext(sampleRate: number): Promise<void> {
    if (this.queue.length === 0) {
      this.isPlaying = false;
      return;
    }

    this.isPlaying = true;
    const data = this.queue.shift()!;

    try {
      const contextManager = getAudioContextManager();
      const context = await contextManager.getContext();

      // Create buffer from PCM data
      const int16Data = new Int16Array(data);
      const float32Data = new Float32Array(int16Data.length);
      for (let i = 0; i < int16Data.length; i++) {
        float32Data[i] = int16Data[i] / 32768;
      }

      const buffer = context.createBuffer(1, float32Data.length, sampleRate);
      buffer.getChannelData(0).set(float32Data);

      // Create source
      this.currentSource = context.createBufferSource();
      this.currentSource.buffer = buffer;

      // Create gain node for volume
      this.gainNode = context.createGain();
      this.gainNode.gain.value = this.volume;

      // Connect
      this.currentSource.connect(this.gainNode);
      this.gainNode.connect(context.destination);

      // Play
      this.currentSource.start();

      // Queue next when done
      this.currentSource.onended = () => {
        this.currentSource = null;
        this.playNext(sampleRate);
      };
    } catch (error) {
      console.error('[Audio] Playback error:', error);
      this.playNext(sampleRate);
    }
  }
}

// ===== Factory Functions =====

export function createAudioRecorder(): AudioRecorder {
  return new AudioRecorder();
}

export function createAudioPlayer(): AudioPlayer {
  return new AudioPlayer();
}
