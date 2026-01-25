# Kyutai Pocket TTS: Native iOS via Rust/Candle

## Overview

This document outlines the path to native iOS inference for Kyutai Pocket TTS using the Rust/Candle implementation, bypassing the CoreML conversion limitations.

## Why Not CoreML?

Kyutai Pocket TTS uses stateful streaming transformers with:
- KV cache management across inference steps
- Mimi codec state for audio decoding
- Streaming overlap-add for low-latency output

PyTorch's `torch.jit.trace()` cannot capture these stateful operations, making CoreML export impractical without major architectural changes.

## The Rust/Candle Solution

### Existing Implementation

A complete Rust/Candle port exists at [babybirdprd/pocket-tts](https://github.com/babybirdprd/pocket-tts):

| Component | Implementation |
|-----------|----------------|
| FlowLM Transformer | `models/flowlm.rs` |
| Mimi Codec | `models/mimi.rs` |
| SEANet Decoder | `models/seanet.rs` |
| Tokenizer | SentencePiece via `tokenizers` crate |
| Streaming | Full KV-cache + overlap-add |

**Performance**: 3.1x faster than optimized Python with numerical parity (<0.06 difference).

### iOS Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Swift/SwiftUI App                       │
├─────────────────────────────────────────────────────────────┤
│                   Generated Swift Bindings                   │
│                      (from UniFFI .udl)                      │
├─────────────────────────────────────────────────────────────┤
│                        XCFramework                           │
│    ┌─────────────────────┐  ┌─────────────────────┐         │
│    │ aarch64-apple-ios   │  │ aarch64-apple-ios-  │         │
│    │ (device)            │  │ sim (simulator)     │         │
│    └─────────────────────┘  └─────────────────────┘         │
├─────────────────────────────────────────────────────────────┤
│                   Rust/Candle Implementation                 │
│    ┌──────────┐  ┌──────────┐  ┌──────────┐                │
│    │ FlowLM   │  │  Mimi    │  │ SEANet   │                │
│    │Transformer│ │  Codec   │  │ Decoder  │                │
│    └──────────┘  └──────────┘  └──────────┘                │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Steps

### 1. Fork and Adapt Candle Implementation

```bash
git clone https://github.com/babybirdprd/pocket-tts pocket-tts-ios
cd pocket-tts-ios
```

### 2. Add UniFFI Interface

Create `src/ffi.udl`:

```
namespace pocket_tts {
    // Errors
    [Error]
    enum PocketTTSError {
        "ModelLoadError",
        "TokenizationError",
        "InferenceError",
        "AudioError",
    };
};

interface PocketTTSEngine {
    [Throws=PocketTTSError]
    constructor(string model_path);

    [Throws=PocketTTSError]
    bytes synthesize(string text, u32 voice_index);

    [Throws=PocketTTSError]
    void start_streaming(string text, u32 voice_index);

    [Throws=PocketTTSError]
    bytes? next_chunk();

    void stop_streaming();

    sequence<string> available_voices();
};

callback interface TTSEventHandler {
    void on_audio_chunk(bytes audio_data);
    void on_complete();
    void on_error(string message);
};
```

### 3. Build for iOS Targets

```bash
# Install targets
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim

# Build
cargo build --target aarch64-apple-ios --release
cargo build --target aarch64-apple-ios-sim --release
```

### 4. Create XCFramework

```bash
#!/bin/bash
# build-xcframework.sh

FRAMEWORK_NAME="PocketTTS"
RELEASE_DIR="target/release"

# Generate Swift bindings
cargo run --bin uniffi-bindgen generate \
    src/ffi.udl \
    --language swift \
    --out-dir bindings

# Create xcframework
xcodebuild -create-xcframework \
    -library target/aarch64-apple-ios/release/libpocket_tts.a \
    -headers bindings \
    -library target/aarch64-apple-ios-sim/release/libpocket_tts.a \
    -headers bindings \
    -output ${FRAMEWORK_NAME}.xcframework
```

### 5. Swift Integration

```swift
import PocketTTS

actor PocketTTSiOS {
    private var engine: PocketTTSEngine?

    func loadModel(path: String) async throws {
        engine = try PocketTTSEngine(modelPath: path)
    }

    func synthesize(text: String, voice: Int) async throws -> Data {
        guard let engine else { throw PocketTTSError.modelNotLoaded }
        return try engine.synthesize(text: text, voiceIndex: UInt32(voice))
    }

    func streamSynthesis(text: String, voice: Int) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try engine?.startStreaming(text: text, voiceIndex: UInt32(voice))
                    while let chunk = try engine?.nextChunk() {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
```

## Performance Considerations

### CPU-Only on iOS

Candle does not support Metal GPU on iOS. However, Pocket TTS was specifically designed for CPU execution:

| Platform | Performance |
|----------|-------------|
| MacBook Air M4 | ~6x realtime |
| iPhone 15 Pro (estimated) | ~3-4x realtime |
| iPhone 13 (estimated) | ~2x realtime |

### Quantization

For better iOS performance, consider quantization:

```rust
// Load quantized model
let model = PocketTTSModel::load_quantized(
    model_path,
    QuantizationType::Q4_K_M
)?;
```

This could improve performance by 2-3x with minimal quality loss.

### Memory Footprint

| Component | Size |
|-----------|------|
| Model weights (Q4) | ~60MB |
| Runtime memory | ~100-150MB |
| Voice embeddings | ~4MB |

## Relevant Crates

| Crate | Purpose | Notes |
|-------|---------|-------|
| `candle-core` | Tensor operations | Required |
| `candle-nn` | Neural network layers | Required |
| `uniffi` | Swift FFI generation | Required |
| `safetensors` | Model loading | Required |
| `tokenizers` | SentencePiece | Required |
| `rubato` | Audio resampling | Optional |
| `candle-coreml` | CoreML bridge | Future optimization |

## Timeline Estimate

| Phase | Effort |
|-------|--------|
| Fork and setup | 1 day |
| UniFFI interface | 2 days |
| iOS build system | 2 days |
| Swift integration | 2 days |
| Testing and optimization | 3 days |
| **Total** | **~10 days** |

## References

- [babybirdprd/pocket-tts](https://github.com/babybirdprd/pocket-tts) - Candle implementation
- [HuggingFace Candle](https://github.com/huggingface/candle) - ML framework
- [UniFFI](https://mozilla.github.io/uniffi-rs/) - FFI bindings
- [Strathweb: Phi-3 on iOS](https://www.strathweb.com/2024/05/running-microsoft-phi-3-model-in-an-ios-app-with-rust/) - Reference tutorial
- [candle-coreml](https://crates.io/crates/candle-coreml) - CoreML bridge

## Status

**Current**: Server-side inference via `/api/tts/kyutai-pocket`
**Next**: Implement Rust/Candle iOS integration for offline capability
