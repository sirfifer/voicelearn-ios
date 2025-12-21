# UnaMentis Device Capability Tiers

**Purpose:** Define device tiers for optimal on-device AI experience with graceful fallback.

---

## Design Principles

1. **Best possible experience** for each device - don't artificially limit capable hardware
2. **Two main tiers** with smooth fallback between them
3. **Fallback should be subtle** - significant load reduction, minimal quality loss
4. **Dynamic adaptation** - respond to runtime conditions (thermal, memory pressure)
5. **Clear cutoff** - don't try to support everything

---

## Device Tier Definitions

### Tier 1: Pro Max (Flagship)
*Target: iPhone 15 Pro Max, 16 Pro Max, 17 Pro Max*

```
┌─────────────────────────────────────────────────────────────┐
│  TIER 1: PRO MAX                                            │
├─────────────────────────────────────────────────────────────┤
│  Hardware Requirements:                                     │
│  • A17 Pro or newer                                         │
│  • 8GB+ RAM                                                 │
│  • Neural Engine 16-core+                                   │
│                                                             │
│  On-Device Capabilities Enabled:                            │
│  ✅ Silero VAD (always)                                     │
│  ✅ Intent classifier (DistilBERT ~50MB)                    │
│  ✅ On-device embeddings (MiniLM ~100MB)                    │
│  ✅ Small LLM for simple responses (Llama 3.2 3B ~4GB)      │
│  ✅ Concurrent model loading                                │
│  ✅ Higher quality audio (48kHz)                            │
│  ✅ Aggressive prefetching/caching                          │
│                                                             │
│  Expected Performance:                                      │
│  • VAD: <25ms                                               │
│  • Intent: <60ms                                            │
│  • Small LLM: ~15-20 tokens/sec                             │
│  • Can sustain 30-45 min before thermal throttle            │
└─────────────────────────────────────────────────────────────┘
```

### Tier 2: Pro Standard (Capable)
*Target: iPhone 14 Pro/Max, 15 Pro, 16 Pro, older Pro Max models*

```
┌─────────────────────────────────────────────────────────────┐
│  TIER 2: PRO STANDARD                                       │
├─────────────────────────────────────────────────────────────┤
│  Hardware Requirements:                                     │
│  • A16 Bionic or newer                                      │
│  • 6GB+ RAM                                                 │
│  • Neural Engine 16-core                                    │
│                                                             │
│  On-Device Capabilities Enabled:                            │
│  ✅ Silero VAD (always)                                     │
│  ✅ Intent classifier (DistilBERT ~50MB)                    │
│  ✅ On-device embeddings (MiniLM ~100MB)                    │
│  ⚠️ Smaller LLM only (Llama 3.2 1B ~1.5GB)                  │
│  ❌ No concurrent heavy model loading                       │
│  ⚠️ Standard audio (24kHz)                                  │
│  ⚠️ Conservative prefetching                                │
│                                                             │
│  Expected Performance:                                      │
│  • VAD: <30ms                                               │
│  • Intent: <80ms                                            │
│  • Small LLM: ~25-30 tokens/sec (1B is faster)              │
│  • Can sustain 20-30 min before thermal throttle            │
└─────────────────────────────────────────────────────────────┘
```

### Minimum Supported (Cutoff)
*Below this = not officially supported*

```
┌─────────────────────────────────────────────────────────────┐
│  MINIMUM REQUIREMENTS                                       │
├─────────────────────────────────────────────────────────────┤
│  • A15 Bionic (iPhone 13 Pro/14)                            │
│  • 6GB RAM                                                  │
│  • iOS 17+                                                  │
│                                                             │
│  Devices BELOW cutoff (not supported):                      │
│  ❌ iPhone 13 (non-Pro) - only 4GB RAM                      │
│  ❌ iPhone 12 and older - A14 or older                      │
│  ❌ Any non-Pro with less than 6GB RAM                      │
│                                                             │
│  Rationale: Below this, on-device LLM is not viable,       │
│  and even embeddings become memory-constrained.             │
│  Users would have poor experience.                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Dynamic Fallback System

The key insight: **Tier is not static**. A Tier 1 device can temporarily operate at Tier 2 levels due to:
- Thermal throttling
- Memory pressure (other apps)
- Low battery mode
- Background activity

### Fallback Triggers

```swift
struct RuntimeConditions {
    // Thermal (from ProcessInfo.thermalState)
    var thermalState: ProcessInfo.ThermalState  // .nominal, .fair, .serious, .critical

    // Memory (from os_proc_available_memory)
    var availableMemoryMB: Int
    var memoryPressure: MemoryPressure  // .normal, .warning, .critical

    // Battery
    var batteryLevel: Float  // 0.0 - 1.0
    var isLowPowerMode: Bool

    // Performance
    var recentInferenceLatencyMs: Double
    var inferenceFailureCount: Int
}
```

### Fallback Decision Matrix

```
┌──────────────────────────────────────────────────────────────────┐
│  DYNAMIC TIER ADJUSTMENT                                         │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Base Tier: Determined at app launch by device model             │
│                                                                   │
│  Runtime Downgrades (Tier 1 → Tier 2 behavior):                  │
│  ───────────────────────────────────────────────────────────────│
│  Condition                      │ Action                         │
│  ───────────────────────────────┼───────────────────────────────│
│  thermalState >= .serious       │ Unload 3B LLM, use 1B only    │
│  availableMemory < 2GB          │ Unload 3B LLM, use 1B only    │
│  thermalState == .critical      │ Disable on-device LLM entirely│
│  memoryPressure == .critical    │ Unload all optional models    │
│  isLowPowerMode == true         │ Disable on-device LLM         │
│  batteryLevel < 0.15            │ Disable on-device LLM         │
│  inferenceLatency > 2x expected │ Fall back to cloud            │
│  inferenceFailures > 3          │ Fall back to cloud            │
│                                                                   │
│  Recovery (Tier 2 → Tier 1 behavior):                            │
│  ───────────────────────────────────────────────────────────────│
│  Condition                      │ Action                         │
│  ───────────────────────────────┼───────────────────────────────│
│  thermalState == .nominal       │ Can reload larger models      │
│  availableMemory > 4GB          │ Can reload larger models      │
│  After 5 min at .fair thermal   │ Attempt to reload 3B          │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## What Changes Between Tiers

### The Subtle Differences (User Barely Notices)

| Aspect | Tier 1 (Pro Max) | Tier 2 (Pro Standard) | Impact |
|--------|------------------|----------------------|--------|
| Simple acknowledgments | On-device 3B | On-device 1B | Slightly less natural |
| Audio sample rate | 48kHz | 24kHz | Imperceptible |
| Embedding batch size | 10 chunks | 5 chunks | Slightly slower RAG |
| Model preloading | Aggressive | Lazy | First response slower |
| Concurrent operations | Yes | Sequential | ~100ms extra latency |

### What Stays The Same (Quality Protected)

| Aspect | Both Tiers |
|--------|------------|
| VAD accuracy | Same (Silero) |
| Intent classification | Same model |
| STT quality | Same (cloud primary) |
| TTS quality | Same (cloud primary) |
| Complex tutoring | Same (routed to cloud/server) |
| Conversation quality | Same (main LLM unchanged) |

**The key insight:** On-device LLM is only for simple stuff. The heavy lifting (actual tutoring) goes to cloud/server regardless of tier. So tier differences affect latency and device resource usage, not tutoring quality.

---

## Implementation

### Device Detection

```swift
enum DeviceCapabilityTier: String, Codable {
    case proMax      // Tier 1: Full on-device capabilities
    case proStandard // Tier 2: Reduced on-device capabilities
    case unsupported // Below minimum requirements

    static func detect() -> DeviceCapabilityTier {
        let device = Device.current  // Using DeviceKit or similar
        let ram = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)

        // Tier 1: Pro Max models with 8GB+
        let tier1Devices: Set<String> = [
            "iPhone15,3",  // iPhone 14 Pro Max
            "iPhone16,2",  // iPhone 15 Pro Max
            "iPhone17,2",  // iPhone 16 Pro Max
            // Add iPhone 17 Pro Max when available
        ]

        if tier1Devices.contains(device.identifier) && ram >= 8 {
            return .proMax
        }

        // Tier 2: Pro models with 6GB+
        let tier2Devices: Set<String> = [
            "iPhone14,2",  // iPhone 13 Pro
            "iPhone14,3",  // iPhone 13 Pro Max
            "iPhone15,2",  // iPhone 14 Pro
            "iPhone15,3",  // iPhone 14 Pro Max (also Tier 1 eligible)
            "iPhone16,1",  // iPhone 15 Pro
            "iPhone16,2",  // iPhone 15 Pro Max (also Tier 1 eligible)
            "iPhone17,1",  // iPhone 16 Pro
            "iPhone17,2",  // iPhone 16 Pro Max (also Tier 1 eligible)
        ]

        if tier2Devices.contains(device.identifier) && ram >= 6 {
            return .proStandard
        }

        return .unsupported
    }
}
```

### Runtime Capability Manager

```swift
@Observable
@MainActor
final class DeviceCapabilityManager {
    // Static tier (based on device model)
    let baseTier: DeviceCapabilityTier

    // Dynamic tier (adjusted for runtime conditions)
    private(set) var effectiveTier: DeviceCapabilityTier

    // Runtime monitoring
    private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    private(set) var availableMemoryMB: Int = 0
    private(set) var isLowPowerMode: Bool = false

    // What's currently possible
    var canUseOnDeviceLLM: Bool {
        effectiveTier != .unsupported &&
        thermalState < .critical &&
        availableMemoryMB > 1500 &&
        !isLowPowerMode
    }

    var recommendedOnDeviceLLMSize: OnDeviceLLMSize {
        guard canUseOnDeviceLLM else { return .none }

        switch effectiveTier {
        case .proMax:
            return thermalState == .nominal ? .threeB : .oneB
        case .proStandard:
            return .oneB
        case .unsupported:
            return .none
        }
    }

    enum OnDeviceLLMSize {
        case none     // Don't use on-device LLM
        case oneB     // Llama 3.2 1B
        case threeB   // Llama 3.2 3B
    }

    // Start monitoring
    func startMonitoring() {
        // Thermal state
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateThermalState()
        }

        // Memory pressure
        startMemoryMonitoring()

        // Low power mode
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updatePowerState()
        }
    }

    private func updateEffectiveTier() {
        // Start with base tier
        var newTier = baseTier

        // Downgrade conditions
        if thermalState >= .serious || availableMemoryMB < 2000 {
            if baseTier == .proMax {
                newTier = .proStandard
            }
        }

        if thermalState == .critical || availableMemoryMB < 1000 || isLowPowerMode {
            // Even Tier 2 can't do on-device LLM safely
            // (but we keep the tier, just disable LLM via canUseOnDeviceLLM)
        }

        if effectiveTier != newTier {
            effectiveTier = newTier
            NotificationCenter.default.post(name: .deviceTierDidChange, object: newTier)
        }
    }
}
```

### Configuration Presets Per Tier

```swift
extension SessionConfig {
    static func forTier(_ tier: DeviceCapabilityTier) -> SessionConfig {
        switch tier {
        case .proMax:
            return SessionConfig(
                audio: .init(
                    sampleRate: 48000,
                    enableVoiceProcessing: true,
                    vadProvider: .silero,
                    enableAdaptiveQuality: true
                ),
                onDeviceLLM: .init(
                    enabled: true,
                    modelSize: .threeB,
                    maxConcurrentModels: 3,  // VAD + Intent + LLM
                    preloadModels: true
                ),
                intentClassifier: .init(
                    enabled: true,
                    model: .distilBERT
                ),
                embeddings: .init(
                    useOnDevice: true,
                    batchSize: 10
                )
            )

        case .proStandard:
            return SessionConfig(
                audio: .init(
                    sampleRate: 24000,
                    enableVoiceProcessing: true,
                    vadProvider: .silero,
                    enableAdaptiveQuality: true
                ),
                onDeviceLLM: .init(
                    enabled: true,
                    modelSize: .oneB,
                    maxConcurrentModels: 2,  // VAD + Intent OR LLM
                    preloadModels: false     // Lazy load to save memory
                ),
                intentClassifier: .init(
                    enabled: true,
                    model: .distilBERT
                ),
                embeddings: .init(
                    useOnDevice: true,
                    batchSize: 5
                )
            )

        case .unsupported:
            // Minimal config - everything goes to cloud
            return SessionConfig(
                audio: .init(
                    sampleRate: 16000,
                    enableVoiceProcessing: true,
                    vadProvider: .silero,  // VAD still works
                    enableAdaptiveQuality: false
                ),
                onDeviceLLM: .init(enabled: false),
                intentClassifier: .init(enabled: false),
                embeddings: .init(useOnDevice: false)
            )
        }
    }
}
```

---

## User Communication

### What Users See

**Tier 1 users:** No indication needed - everything just works optimally.

**Tier 2 users:** No indication needed - experience is nearly identical. Maybe slightly longer initial load.

**During fallback (Tier 1 → Tier 2 behavior):**
```
[Optional subtle indicator in UI - not alarming]
"Optimizing for device temperature..."
or
"Adjusted for available memory..."

[No interruption to session - seamless transition]
```

**Unsupported devices (at app launch):**
```
"UnaMentis requires iPhone 13 Pro or newer for the best experience.
Your device may experience reduced functionality."

[Allow them to continue but set expectations]
```

---

## Summary

```
┌──────────────────────────────────────────────────────────────────┐
│  TIER SYSTEM SUMMARY                                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Tier 1 (Pro Max):                                               │
│  • Full on-device: VAD + Intent + Embeddings + 3B LLM            │
│  • Best latency for simple operations                            │
│  • Falls back to Tier 2 behavior if device stressed              │
│                                                                   │
│  Tier 2 (Pro Standard):                                          │
│  • Reduced on-device: VAD + Intent + Embeddings + 1B LLM         │
│  • Nearly identical user experience                              │
│  • Falls back to cloud-only if device critically stressed        │
│                                                                   │
│  Both Tiers:                                                     │
│  • Same tutoring quality (complex stuff goes to cloud/server)   │
│  • Same STT/TTS quality (cloud services)                        │
│  • Same VAD accuracy                                             │
│                                                                   │
│  The difference is WHERE simple tasks run, not HOW WELL          │
│  the tutoring works.                                             │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## Next Steps

1. **Add DeviceKit dependency** for reliable device detection
2. **Implement DeviceCapabilityManager** actor
3. **Add thermal/memory monitoring** hooks
4. **Create tier-specific SessionConfig presets**
5. **Add subtle UI indicators** for fallback states
6. **Test on actual devices** across tier boundaries

---

*Document created: December 2024*
