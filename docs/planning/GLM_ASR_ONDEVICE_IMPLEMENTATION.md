# GLM-ASR On-Device Implementation - Work in Progress

**Last Updated:** December 16, 2025
**Status:** Swift Integration Complete - Awaiting Xcode C++ Interop Configuration

---

## Overview

This document tracks the implementation of GLM-ASR-Nano-2512 as an **on-device** speech recognition solution for UnaMentis iOS. The primary target is iPhone 17 Pro Max (12GB RAM) with server fallback for older devices.

---

## Current State Summary (December 16)

### Completed

| Task | Status | Output |
|------|--------|--------|
| Python environment setup | ✅ | `.venv/` with torch, transformers, coremltools |
| Model download | ✅ | 4.21 GB `model.safetensors` |
| Model loads in PyTorch | ✅ | 2.26B params on MPS (Apple Silicon) |
| Patched for transformers 4.57 | ✅ | Changed `WhisperFlashAttention2` → `WhisperAttention` |
| Whisper Encoder → CoreML | ✅ | `GLMASRWhisperEncoder.mlpackage` (1.2 GB, 635M params) |
| Audio Adapter → CoreML | ✅ | `GLMASRAudioAdapter.mlpackage` (56 MB, 29.4M params) |
| Embed+Head → CoreML | ✅ | `GLMASREmbedHead.mlpackage` (232 MB) |
| LLM Decoder → GGUF | ✅ | `glm-asr-nano-f16.gguf` (3.0 GB) |
| Quantized GGUF (Q4_K_M) | ✅ | `glm-asr-nano-q4km.gguf` (935 MB) |
| llama.cpp built | ✅ | With Metal support for Apple Silicon |
| GLMASROnDeviceSTTService.swift | ✅ | Service created with CoreML + llama.cpp pipeline |
| STTProviderRouter updated | ✅ | On-device priority over server |
| STTProvider enum updated | ✅ | Added `glmASROnDevice` case |

### Awaiting Configuration

| Task | Status | Blocker |
|------|--------|---------|
| llama.cpp Swift integration | ⏸️ | Requires Xcode C++ interop (SWIFT_OBJC_INTEROP_MODE = objcxx) |

### Remaining

| Task | Priority | Notes |
|------|----------|-------|
| Configure Xcode C++ interop | High | Enable LLAMA_AVAILABLE flag in build settings |
| Test end-to-end inference | High | Validate transcription quality |
| Add `.ultra` device tier | Medium | iPhone 17 Pro/Max detection |
| Implement mel spectrogram with vDSP | Medium | Current implementation is simplified |

---

## Models Created

```
models/glm-asr-nano/
├── model.safetensors              (4.21 GB) - Original PyTorch weights
├── GLMASRWhisperEncoder.mlpackage (1.2 GB)  - Audio → embeddings (CoreML)
├── GLMASRAudioAdapter.mlpackage   (56 MB)   - Dimension adaptation (CoreML)
├── GLMASREmbedHead.mlpackage      (232 MB)  - Token embed + output head (CoreML)
├── GLMASRConvEncoder.mlpackage    (10 MB)   - Conv layers only (test)
├── glm-asr-nano-f16.gguf          (3.0 GB)  - LLM decoder (F16 GGUF)
├── glm-asr-nano-q4km.gguf         (935 MB)  - LLM decoder (Q4_K_M quantized)
└── modeling_audio.py              (patched) - WhisperAttention fix
```

### Pipeline Architecture

```
Audio (16kHz)
    ↓
[Mel Spectrogram] (128 x 3000)
    ↓
┌─────────────────────────────────────┐
│ GLMASRWhisperEncoder.mlpackage      │  ← CoreML ✅
│ (635M params, 1.2 GB)               │
└─────────────────────────────────────┘
    ↓ (1 x 1500 x 1280)
┌─────────────────────────────────────┐
│ GLMASRAudioAdapter.mlpackage        │  ← CoreML ✅
│ (29M params, 56 MB)                 │
└─────────────────────────────────────┘
    ↓ (1 x 375 x 2048) + BOA/EOA tokens
┌─────────────────────────────────────┐
│ LLM Decoder (28 layers)             │  ← GGUF ✅ (llama.cpp)
│ (1.47B params, 935 MB Q4_K_M)       │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ GLMASREmbedHead.mlpackage           │  ← CoreML ✅
│ (232 MB)                            │
└─────────────────────────────────────┘
    ↓
Text tokens → Transcript
```

---

## LLM Decoder Conversion Options

The 1.5B parameter LLaMA-based decoder failed direct CoreML conversion due to:
- Dynamic attention mask shapes
- `torch.jit.trace` issues with transformer attention

### Alternative Approaches

1. **MLX (Apple's ML Framework)**
   - Native Apple Silicon support
   - Good for LLMs on Mac
   - Installed: `mlx==0.30.0`, `mlx-lm==0.29.1`
   - Challenge: Custom model architecture needs manual implementation

2. **llama.cpp with GGUF**
   - Convert to GGUF format
   - Use llama.cpp for inference
   - Well-tested with LLaMA architectures
   - Challenge: Need to integrate C++ library into Swift

3. **Split Transformer Layers**
   - Convert each transformer block separately
   - Chain them in Swift
   - More complex but may work

4. **Use Server Fallback for Decoder**
   - Run encoder on-device (fast, Neural Engine)
   - Send embeddings to server for decoding
   - Hybrid approach - still reduces latency

---

## Technical Notes

### Patched File: `modeling_audio.py`

Changed line 7:
```python
# Before (incompatible with transformers 4.57):
from transformers.models.whisper.modeling_whisper import WhisperEncoder, WhisperEncoderLayer, WhisperFlashAttention2

# After:
from transformers.models.whisper.modeling_whisper import WhisperEncoder, WhisperEncoderLayer, WhisperAttention
```

And line 74:
```python
# Before:
class WhisperRoPEFlashAttn(WhisperFlashAttention2):

# After:
class WhisperRoPEFlashAttn(WhisperAttention):
```

### Model Verification

```python
# Model loads and runs on Apple Silicon MPS
model = AutoModelForCausalLM.from_pretrained(
    './models/glm-asr-nano',
    trust_remote_code=True,
    torch_dtype=torch.float16,
    device_map='mps'
)
# Output: 2.26B parameters loaded successfully
```

---

## Environment

### Python Virtual Environment

```bash
cd /Users/ramerman/dev/voicelearn-ios
source .venv/bin/activate

# Key packages:
# torch==2.9.1
# transformers==4.57.3
# coremltools==9.0
# mlx==0.30.0
# accelerate, torchaudio, safetensors
```

### Installed Tools

- PyTorch 2.9.1 with MPS support
- CoreML Tools 9.0
- MLX 0.30.0 (Apple's ML framework)
- ONNX + ONNX Runtime

---

## Next Steps

### Option A: Hybrid Approach (Recommended)
1. Use CoreML for encoder + adapter (on-device, Neural Engine)
2. Use server for decoder (existing GLMASRSTTService)
3. Create hybrid service that combines both

### Option B: Full On-Device with MLX
1. Implement GLM-ASR model in MLX
2. Load weights from safetensors
3. Run entirely on Apple Silicon GPU

### Option C: llama.cpp Integration
1. Convert decoder to GGUF format
2. Integrate llama.cpp via Swift/C++ bridge
3. Chain with CoreML encoder

---

## Session Notes

**December 13, 2025:**
- Started on-device implementation
- Set up Python environment
- Model download stalled at 95%

**December 16, 2025 (Morning):**
- Completed model download (4.21 GB)
- Patched model for transformers 4.57 compatibility
- Successfully converted Whisper encoder to CoreML (1.2 GB)
- Successfully converted audio adapter to CoreML (56 MB)
- Successfully converted embed+head to CoreML (232 MB)
- LLM decoder CoreML conversion blocked - dynamic attention issues

**December 16, 2025 (Afternoon):**
- Converted LLM decoder to GGUF format (3.0 GB F16)
- Quantized to Q4_K_M for iPhone (935 MB - 68% size reduction)
- Built llama.cpp with Metal support
- Created `GLMASROnDeviceSTTService.swift` with full pipeline
- Updated `STTProviderRouter` to prioritize on-device inference
- Added `glmASROnDevice` case to `STTProvider` enum
- Swift package builds successfully
- **Blocker**: llama.cpp Swift integration requires Xcode C++ interop configuration

**Total On-Device Model Size:** ~2.2 GB
- CoreML models: ~1.5 GB (encoder + adapter + embed/head)
- GGUF decoder: ~935 MB (Q4_K_M quantized)

---

## Next Steps to Enable llama.cpp

1. Open project in Xcode
2. Go to Build Settings
3. Set `SWIFT_OBJC_INTEROP_MODE = objcxx`
4. Add `-DLLAMA_AVAILABLE` to Swift Compiler Custom Flags
5. Uncomment llama.cpp dependency in Package.swift
6. Build and test

---

*This document will be updated as implementation progresses.*
