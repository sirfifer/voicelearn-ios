# Patch Panel Implementation Plan

## Overview

This document outlines the step-by-step implementation of the LLM Patch Panel routing system, following TDD principles.

## Directory Structure

```
VoiceLearn/
├── Core/
│   └── Routing/
│       ├── Models/
│       │   ├── LLMEndpoint.swift          # Endpoint definition & registry
│       │   ├── LLMTaskType.swift          # Task type enumeration
│       │   ├── RoutingCondition.swift     # Condition types for auto-routing
│       │   └── RoutingTable.swift         # Routing configuration
│       ├── PatchPanelService.swift        # Main routing actor
│       └── DeviceCapabilityManager.swift  # Device tier detection (future)
│
VoiceLearnTests/
├── Unit/
│   └── Routing/
│       ├── LLMEndpointTests.swift
│       ├── LLMTaskTypeTests.swift
│       ├── RoutingConditionTests.swift
│       ├── RoutingTableTests.swift
│       └── PatchPanelServiceTests.swift
```

## Implementation Order (TDD)

### Phase 1: Core Models

#### 1.1 LLMEndpoint
- **Test first**: Endpoint creation, validation, status management
- **Then implement**: Struct with all properties, default registry

#### 1.2 LLMTaskType
- **Test first**: All task types exist, capability tier mapping
- **Then implement**: Enum with capability requirements

#### 1.3 RoutingCondition
- **Test first**: Condition evaluation logic
- **Then implement**: Condition types and evaluation

#### 1.4 RoutingTable
- **Test first**: Default routes, manual overrides, auto-rules
- **Then implement**: Routing configuration struct

### Phase 2: Core Service

#### 2.1 PatchPanelService
- **Test first**: Routing resolution, fallback handling, history tracking
- **Then implement**: Main actor with routing logic

### Phase 3: Integration

#### 3.1 AppState Integration
- Wire PatchPanelService into AppState
- Update existing LLM calls to route through patch panel

## File Dependencies

```
LLMEndpoint.swift          ← No dependencies
LLMTaskType.swift          ← No dependencies
RoutingCondition.swift     ← LLMTaskType
RoutingTable.swift         ← LLMEndpoint, LLMTaskType, RoutingCondition
PatchPanelService.swift    ← All above + TelemetryEngine
```

## Testing Strategy

1. **Unit tests for models** - Test all data structures in isolation
2. **Unit tests for routing logic** - Test routing decisions with various conditions
3. **Integration tests** - Test end-to-end routing with mock endpoints

## Compatibility Notes

- Uses `actor` for thread safety (matches existing SessionManager pattern)
- Uses `@Observable` for SwiftUI integration (iOS 17+)
- Uses `Codable` for persistence (matches existing config patterns)
- Integrates with existing `TelemetryEngine` for metrics
- Compatible with existing `LLMService` protocol
