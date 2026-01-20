# TTS Lab Guide

## Overview

The TTS Lab is an experimentation interface for server administrators to test different TTS models and configurations before batch converting thousands of questions into audio files. This allows you to compare quality, performance, and characteristics across models to find the optimal settings for your use case.

## Purpose

Before batch-generating audio for:
- Knowledge Bowl questions (thousands of Q&A pairs)
- Quiz Ball questions
- Curriculum content delivery
- Pre-cached FOV context

You need to:
1. Select the right TTS model (Kyutai TTS 1.6B, Pocket TTS, Fish Speech)
2. Choose a voice that fits your audience
3. Tune configuration parameters for quality vs speed
4. Generate test samples to validate settings
5. Save the optimal configuration for batch processing

## Accessing TTS Lab

**Web UI:** http://localhost:3000/management/tts-lab

**API Endpoints:**
- `GET /api/tts-lab/models` - List all supported models
- `POST /api/tts-lab/generate` - Generate test audio
- `POST /api/tts-lab/config` - Save configuration
- `GET /api/tts-lab/configs` - List saved configurations
- `GET /api/tts-lab/config/{id}` - Get specific configuration
- `DELETE /api/tts-lab/config/{id}` - Delete configuration
- `POST /api/tts-lab/validate` - Validate configuration

## Supported Models

### Kyutai TTS 1.6B (Recommended for Batch)
**Release:** July 2025
**Parameters:** 1.6 billion
**License:** CC-BY 4.0

**Capabilities:**
- 40+ voices (including emotional variations)
- Delayed streams framework (low latency)
- Voice cloning from reference audio
- Optimized for batch processing

**Voices:**
- Neutral: sarah, john, emma, alex
- Emotional: sarah-happy, sarah-sad, john-excited, emma-calm
- (Plus 30+ additional voices from hf-snapshot://kyutai/tts-voices/)

**Configuration Parameters:**
- `cfg_coef` (1.0-5.0, default: 2.0) - Voice adherence
  - Higher = more faithful to target voice
  - Lower = more creative/varied
  - Recommended: 2.0 for consistency

- `n_q` (8-32, default: 24) - Quantization levels
  - Higher = better quality, slower
  - Lower = faster, lower quality
  - 24 = full quality for archival
  - 16 = good quality, 1.5x faster
  - 8 = lower quality, 3x faster

- `padding_between` (0-5, default: 1) - Word spacing
  - 0 = continuous speech
  - 1 = natural articulation (recommended)
  - 3+ = deliberate, teaching-style pacing

- `padding_bonus` (-3 to 3, default: 0) - Speech speed
  - Negative = faster speech
  - 0 = neutral speed
  - Positive = slower, more deliberate

- `temperature` (0.1-2.0, default: 1.0) - Variation
  - Lower = more consistent
  - Higher = more varied prosody
  - Recommended: 0.8-1.0 for educational content

- `top_p` (0.1-1.0, default: 0.95) - Nucleus sampling
  - Controls diversity of speech patterns

- `batch_size` (1-32, default: 8) - Parallel generations
  - Adjust based on GPU memory
  - 8 = ~64 streams at 3x real-time on L40S

### Kyutai Pocket TTS (On-Device/CPU)
**Release:** January 13, 2026
**Parameters:** 100 million
**License:** MIT

**Capabilities:**
- 8 built-in voices
- Voice cloning from 5 seconds of audio
- CPU-only (no GPU required)
- 6x real-time speed on MacBook Air M4
- Sub-50ms latency
- Best WER (1.84%)

**Voices:**
- voice1 through voice8 (default set)
- Custom voices via cloning

**Configuration Parameters:**
- `cfg_coef` (1.0-5.0, default: 2.0)
- `n_q` (8-24, default: 24)
- `temperature` (0.1-2.0, default: 1.0)

**Use Cases:**
- Lightweight batch processing on CPU-only servers
- On-device generation for mobile apps
- Low-latency interactive TTS

### Fish Speech V1.5
**Release:** Late 2025
**Parameters:** ~2 billion
**License:** Apache 2.0

**Capabilities:**
- Zero-shot voice cloning
- Multilingual (30+ languages)
- Cross-lingual synthesis
- Batch processing support

**Voices:**
- Uses voice cloning (no preset voices)
- Provide reference audio sample

**Configuration Parameters:**
- `temperature` (0.1-2.0, default: 1.0)
- `top_p` (0.1-1.0, default: 0.95)

**Use Cases:**
- Multilingual content
- Custom voice requirements
- Zero-shot voice adaptation

## Workflow

### 1. Configure Tab

**Select Model:**
- Choose from Kyutai TTS 1.6B, Pocket TTS, or Fish Speech
- Review model capabilities and voice options

**Select Voice:**
- Kyutai TTS 1.6B: 40+ voices (neutral and emotional)
- Pocket TTS: 8 built-in voices
- Fish Speech: Provide reference audio

**Adjust Parameters:**
- Use sliders to configure each parameter
- Real-time descriptions show effect of each setting
- Start with defaults, then tune based on results

**Enter Test Text:**
- Use representative content (e.g., actual KB question)
- 50-200 characters recommended for quick tests
- Estimated duration shown based on text length

**Generate:**
- Click "Generate Audio" to create test sample
- Processing takes 0.5-2 seconds depending on config
- Audio appears in Compare tab automatically

### 2. Compare Tab

**Review Samples:**
- All generated samples shown in chronological order
- Each card displays:
  - Model and voice used
  - Duration and generation timestamp
  - Full text that was synthesized
  - Audio player for playback
  - Configuration parameters used

**Listen and Compare:**
- Play samples side-by-side
- Compare different voices
- Compare different cfg_coef settings
- Compare quality levels (n_q)
- Compare speech speeds (padding_bonus)

**Actions:**
- Copy configuration to reuse settings
- Download audio file for offline review
- Clear all samples to start fresh

### 3. Batch Settings Tab

**Configure Batch Processing:**
- Set batch size (parallel generations)
  - Higher = faster throughput
  - Adjust based on available GPU memory
  - Default: 8 for balanced performance

**Review Configuration:**
- Summary of selected model and all parameters
- Estimated throughput (e.g., "24x real-time")
- Quality vs speed tradeoffs highlighted

**Save Configuration:**
- Provide name: "KB Questions - Sarah Voice"
- Add description: "Standard config for Knowledge Bowl"
- Save for use in batch pipeline

**Reset to Defaults:**
- Quickly return to recommended settings
- Useful after experimentation

## Configuration Validation

The system automatically validates configurations:

**Errors (will prevent generation):**
- Unsupported model
- Invalid voice for model
- Parameters outside valid ranges
- Missing required fields

**Warnings (generation allowed, quality may vary):**
- `cfg_coef > 3.0`: May reduce naturalness
- `n_q < 16`: May reduce quality
- `temperature > 1.5`: May reduce consistency
- Non-default values flagged for review

## Batch Processing Pipeline

After saving a configuration, use it for batch conversion:

```python
# Load saved configuration
config_id = "config-uuid-from-tts-lab"
config = load_tts_lab_config(config_id)

# Batch process questions
questions = load_kb_questions()  # Thousands of questions

for batch in chunks(questions, config.batch_size):
    audio_files = generate_tts_batch(
        texts=[q.text for q in batch],
        model=config.model,
        voice=config.voice,
        cfg_coef=config.cfg_coef,
        n_q=config.n_q,
        padding_between=config.padding_between,
        padding_bonus=config.padding_bonus,
        temperature=config.temperature,
        top_p=config.top_p,
    )

    # Encode with Mimi codec
    encoded = [mimi_encode(audio) for audio in audio_files]

    # Upload to CDN
    upload_to_cdn(encoded)
```

## Use Case: Knowledge Bowl Questions

**Goal:** Pre-generate audio for 5,000 KB questions

**Recommended Configuration:**
```json
{
  "model": "kyutai-tts-1.6b",
  "voice": "sarah",
  "cfg_coef": 2.0,
  "n_q": 24,
  "padding_between": 1,
  "padding_bonus": 0,
  "temperature": 0.8,
  "top_p": 0.95,
  "batch_size": 8
}
```

**Rationale:**
- **Sarah voice:** Neutral, professional tone suitable for educational content
- **cfg_coef=2.0:** Default adherence, consistent voice across questions
- **n_q=24:** Full quality for archival, questions will be reused many times
- **padding_between=1:** Natural word spacing, clear articulation
- **padding_bonus=0:** Neutral speed, not too fast or slow
- **temperature=0.8:** Slightly lower for consistency across similar questions
- **batch_size=8:** 64 streams at 3x real-time = ~150 questions/minute

**Estimated Time:** 5,000 questions ÷ 150/min ≈ 33 minutes

## Voice Selection Guidelines

**For Educational Content:**
- Use neutral voices (sarah, john, emma, alex)
- Avoid emotional variations for factual questions
- Consider multiple voices for variety (rotate every 50 questions)

**For Interactive Learning:**
- Emotional voices can increase engagement
- Use happy/excited for encouragement
- Use calm for complex explanations

**For Accessibility:**
- Clear articulation is critical
- Use `padding_between=2` for extra clarity
- Consider slower speed (`padding_bonus=1`)

## A/B Testing Strategy

Generate samples with multiple configurations to compare:

**Test 1: Voice Comparison**
- Sarah (neutral)
- Emma (warm)
- John (neutral)
- Same settings, different voices

**Test 2: Speed Comparison**
- `padding_bonus=-1` (faster)
- `padding_bonus=0` (neutral)
- `padding_bonus=1` (slower)
- Same voice, different speeds

**Test 3: Quality Comparison**
- `n_q=16` (good quality, faster)
- `n_q=24` (full quality)
- `n_q=32` (maximum quality)
- Same voice, different quality levels

Evaluate with focus groups or user testing before committing to batch processing.

## Performance Optimization

**For Maximum Throughput:**
- Use `n_q=16` instead of 24 (1.5x faster)
- Increase `batch_size` to max GPU memory allows
- Use Kyutai TTS 1.6B with Rust backend (not Python)

**For Maximum Quality:**
- Use `n_q=24` or higher
- Use `cfg_coef=2.0` for voice consistency
- Use `temperature=0.8` for natural variation
- Lower batch size if GPU memory is constrained

**For CPU-Only Servers:**
- Use Kyutai Pocket TTS (100M)
- 6x real-time on modern CPUs
- Good quality with 1.84% WER
- Lower resource requirements

## Integration with Delayed Streams

For production batch processing, use Kyutai's Delayed Streams framework:

**Rust Backend (Recommended):**
```bash
cd delayed-streams/rust
cargo build --release

./target/release/tts-server \
  --model kyutai-tts-1.6b \
  --voice sarah \
  --cfg-coef 2.0 \
  --n-q 24 \
  --batch-size 8
```

**Configuration File:**
```toml
# config-tts.toml
[model]
path = "hf-snapshot://kyutai/tts-1.6b"
voice = "sarah"

[generation]
cfg_coef = 2.0
n_q = 24
padding_between = 1
padding_bonus = 0
temperature = 0.8
top_p = 0.95

[batch]
size = 8
max_concurrent = 64
```

**Performance:** 400+ concurrent streams on H100 GPU

## Troubleshooting

**Audio sounds robotic:**
- Increase `temperature` to 1.0-1.2
- Check `cfg_coef` isn't too high (>3.0)
- Verify voice embedding loaded correctly

**Audio cuts off or has artifacts:**
- Decrease `n_q` (may be out of memory)
- Reduce `batch_size`
- Check GPU memory usage

**Generation is too slow:**
- Reduce `n_q` from 24 to 16
- Use Pocket TTS for CPU-only
- Increase `batch_size` for better GPU utilization
- Use Rust backend instead of Python

**Voice doesn't match selection:**
- Verify voice embedding file exists
- Check voice ID matches available voices
- Clear cache and regenerate

## API Examples

### Generate Test Audio

```bash
curl -X POST http://localhost:8766/api/tts-lab/generate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "The French Revolution began in 1789 when the Estates-General convened at Versailles.",
    "config": {
      "model": "kyutai-tts-1.6b",
      "voice": "sarah",
      "cfg_coef": 2.0,
      "n_q": 24,
      "padding_between": 1,
      "padding_bonus": 0,
      "temperature": 0.8,
      "top_p": 0.95
    }
  }'
```

### Save Configuration

```bash
curl -X POST http://localhost:8766/api/tts-lab/config \
  -H "Content-Type: application/json" \
  -d '{
    "name": "KB Questions - Sarah Voice",
    "description": "Standard configuration for Knowledge Bowl questions",
    "config": {
      "model": "kyutai-tts-1.6b",
      "voice": "sarah",
      "cfg_coef": 2.0,
      "n_q": 24,
      "padding_between": 1,
      "padding_bonus": 0,
      "temperature": 0.8,
      "top_p": 0.95,
      "batch_size": 8
    }
  }'
```

### List Saved Configurations

```bash
curl http://localhost:8766/api/tts-lab/configs
```

### Validate Configuration

```bash
curl -X POST http://localhost:8766/api/tts-lab/validate \
  -H "Content-Type: application/json" \
  -d '{
    "config": {
      "model": "kyutai-tts-1.6b",
      "voice": "sarah",
      "cfg_coef": 2.0,
      "n_q": 24
    }
  }'
```

## Next Steps

After finding optimal settings in TTS Lab:

1. **Save configuration** with descriptive name
2. **Integrate with batch pipeline** (see tts_pregen_api.py)
3. **Create batch job** for thousands of questions
4. **Monitor progress** via batch API endpoints
5. **Validate output** with spot checks
6. **Deploy to CDN** for low-latency delivery

For batch processing documentation, see:
- `docs/server/TTS_PREGEN_GUIDE.md` - Batch generation system
- `server/management/tts_pregen_api.py` - Batch API implementation
- `docs/AI_MODEL_SELECTION_2026.md` - Model selection guide
