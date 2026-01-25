# TTS Model Audio Samples

This directory contains pre-generated audio samples for TTS model comparison in the Voice Lab.

## Reference Text

All samples should be generated using this standard evaluation text:

> "The quick mathematician, Dr. Sarah Chen, carefully examined the peculiar equation. 'Could this really be correct?' she wondered aloud, her eyes widening with excitement. After seventeen years of research, breakthrough discoveries still thrilled her. Numbers, equations, and the elegant beauty of mathematics had always been her true passion."

This text tests:

- Proper noun pronunciation (Dr. Sarah Chen)
- Question intonation
- Emotional expression (excitement, wonder)
- Natural phrasing and rhythm
- Comma pauses and sentence flow
- Numbers and technical terms

## Required Files

Generate these files using each model's optimal default settings:

### Server TTS Models

- `fish-speech-v1.5.mp3` - Fish Speech V1.5
- `kyutai-tts-1.6b.mp3` - Kyutai TTS 1.6B
- `index-tts-2.mp3` - IndexTTS-2
- `vibevoice-1.5b.mp3` - VibeVoice-1.5B

### On-Device TTS Models

- `kyutai-pocket-tts.mp3` - Kyutai Pocket TTS (100M)
- `neutts-air.mp3` - NeuTTS Air
- `kokoro-82m.mp3` - Kokoro-82M

Note: Apple Neural TTS is not included as it's a proprietary system voice.

## Generation Guidelines

1. Use each model's recommended/default voice
2. Use the model's optimal default parameters
3. Export as MP3 at 128kbps or higher
4. Keep file size reasonable (under 500KB each)
5. Normalize audio levels for consistent playback

## Regeneration

Samples can be regenerated with different settings using the TTS Lab's batch processing feature.
Update this README when samples are regenerated with new settings.

## Last Updated

Samples pending initial generation - January 2026
