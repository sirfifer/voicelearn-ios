# GLM-ASR On-Device Implementation - Work in Progress

**Last Updated:** December 13, 2025
**Status:** In Progress - Paused at Model Download

---

## Overview

This document tracks the implementation of GLM-ASR-Nano-2512 as an **on-device** speech recognition solution for VoiceLearn iOS. The primary target is iPhone 17 Pro Max (12GB RAM) with server fallback for older devices.

---

## Current State Summary

### What's Been Completed

| Task | Status | Notes |
|------|--------|-------|
| Python environment setup | ✅ Complete | Python 3.11 venv with torch, transformers, coremltools, huggingface_hub |
| Model download started | 🔄 Partial | ~4.5GB downloaded, download stalled/interrupted |
| Model architecture analysis | ✅ Complete | Understood hybrid Whisper encoder + LLaMA decoder architecture |
| Build errors fixed | ✅ Complete | STTProviderRouter.swift and PatchPanelService.swift compile cleanly |

### What's In Progress

| Task | Status | Blocker |
|------|--------|---------|
| Download GLM-ASR-Nano model | 🔄 ~95% | Download stalled at 4.52GB, needs resume |

### What's Remaining

| Task | Priority | Complexity |
|------|----------|------------|
| Complete model download | High | Low |
| Convert model to CoreML format | High | High |
| Create GLMASROnDeviceSTTService.swift | High | Medium |
| Add `.ultra` device tier for iPhone 17 | Medium | Low |
| Update STTProviderRouter to prefer on-device | Medium | Low |
| Integrate CoreML model into Xcode project | Medium | Medium |
| Test on MacBook M4 Max | Medium | Low |
| Test on iPhone 17 Pro Max | High | Low |

---

## Technical Details

### Model Architecture (GLM-ASR-Nano-2512)

```
Audio Input (16kHz) → Whisper Encoder (32 layers) → MLP Adapter → LLaMA Decoder (28 layers) → Text
```

**Key specifications:**
- Parameters: 1.5B
- Model size: ~4.5GB (FP16), target ~750MB (INT4)
- Input: 128 mel bins, 16kHz audio
- Architecture: `GlmasrModel` (custom, extends LlamaForCausalLM)
- License: MIT (full commercial use)

**Files in model directory:**
- `config.json` - Model configuration
- `modeling_glmasr.py` - Main model class
- `modeling_audio.py` - Whisper encoder with RoPE
- `configuration_glmasr.py` - Config class
- `inference.py` - Inference helper
- `tokenizer.json` - Tokenizer (6.5MB)
- `model.safetensors` - Weights (~4.5GB) - INCOMPLETE

### CoreML Conversion Strategy

1. **Export to ONNX first** (intermediate format)
   - Trace the model with sample audio input
   - Handle dynamic shapes for streaming

2. **Convert ONNX to CoreML**
   - Use `coremltools.convert()`
   - Apply INT4 quantization for size reduction

3. **Considerations:**
   - Model uses Flash Attention 2 - may need standard attention for CoreML
   - RoPE (Rotary Position Embeddings) - verify CoreML support
   - Streaming requires chunked processing

### Files Modified During This Session

1. **`VoiceLearn/Services/STT/STTProviderRouter.swift`**
   - Added `@preconcurrency import AVFoundation` for Sendable compliance
   - Added cached protocol properties (`_metrics`, `_costPerHour`, `_isStreaming`)
   - Removed test-only MockHealthMonitor code
   - Fixed actor isolation issues in async property access

2. **`VoiceLearn/Core/Routing/PatchPanelService.swift`**
   - Fixed actor isolation in logger autoclosure (line 79-80)

---

## Environment Setup (Already Done)

### Python Virtual Environment

Location: `/Users/ramerman/dev/voicelearn-ios/.venv`

```bash
# Activate environment
cd /Users/ramerman/dev/voicelearn-ios
source .venv/bin/activate

# Installed packages
pip list | grep -E "torch|transformers|coremltools|huggingface"
```

### Model Download Location

```
/Users/ramerman/dev/voicelearn-ios/models/glm-asr-nano/
├── config.json              (3.0 KB)
├── configuration_glmasr.py  (1.3 KB)
├── inference.py             (5.7 KB)
├── modeling_audio.py        (18 KB)
├── modeling_glmasr.py       (5.6 KB)
├── tokenizer.json           (6.5 MB)
├── tokenizer_config.json    (3.7 KB)
├── README.md                (2.0 KB)
├── chat_template.jinja      (334 B)
└── .cache/huggingface/download/
    └── *.incomplete         (4.52 GB - STALLED)
```

---

## Next Steps (Resume Tomorrow)

### Step 1: Complete Model Download

```bash
cd /Users/ramerman/dev/voicelearn-ios
source .venv/bin/activate

python3 -c "
from huggingface_hub import hf_hub_download
model_file = hf_hub_download(
    repo_id='zai-org/GLM-ASR-Nano-2512',
    filename='model.safetensors',
    local_dir='./models/glm-asr-nano',
    local_dir_use_symlinks=False,
    resume_download=True
)
print(f'Downloaded: {model_file}')
"
```

### Step 2: Verify Model Loads

```python
from transformers import AutoModelForCausalLM, AutoTokenizer

model = AutoModelForCausalLM.from_pretrained(
    './models/glm-asr-nano',
    trust_remote_code=True,
    torch_dtype='float16'
)
print(f"Model loaded: {sum(p.numel() for p in model.parameters())/1e9:.2f}B params")
```

### Step 3: CoreML Conversion

This is the complex part - will need to:
1. Create a traced export wrapper
2. Handle the audio input preprocessing
3. Export encoder and decoder separately (recommended for streaming)
4. Apply INT4 quantization

### Step 4: Create Swift Service

Create `VoiceLearn/Services/STT/GLMASROnDeviceSTTService.swift`:
- Implement `STTService` protocol
- Load CoreML model
- Handle audio buffering and chunked inference
- Return `AsyncStream<STTResult>`

### Step 5: Update Routing

Modify `STTProviderRouter.swift` to:
- Check device tier
- Prefer on-device for `.ultra` tier (iPhone 17 Pro/Max)
- Fall back to server/Deepgram otherwise

---

## Related Documentation

- [GLM_ASR_NANO_2512.md](../GLM_ASR_NANO_2512.md) - Model overview and specs
- [GLM_ASR_SERVER_TRD.md](../GLM_ASR_SERVER_TRD.md) - Server implementation (fallback)
- [GLM_ASR_IMPLEMENTATION_PROGRESS.md](../GLM_ASR_IMPLEMENTATION_PROGRESS.md) - Previous progress tracking

---

## Questions/Decisions Pending

1. **Streaming approach**: Should we use sliding window or full-utterance processing?
2. **Quantization level**: INT4 (~750MB) vs INT8 (~1.5GB) - tradeoff accuracy vs size
3. **Model bundling**: Include in app bundle or download on first launch?
4. **Thermal management**: How aggressive should fallback to server be?

---

## Session Notes

**December 13, 2025:**
- Started fresh implementation of on-device GLM-ASR
- Discovered existing implementation was server-first (backwards from intent)
- Set up Python environment successfully
- Model download started but stalled at ~95%
- Analyzed model architecture - hybrid Whisper+LLaMA design
- Fixed Swift 6 concurrency build errors
- Paused for the night - will resume tomorrow

---

*This document will be updated as implementation progresses.*
