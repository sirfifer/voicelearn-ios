# Knowledge Bowl Localization Issues

**Status**: Documented for follow-up PR
**Priority**: Medium
**Created**: 2026-01-18
**Related PR**: #53

## Overview

The Knowledge Bowl feature has multiple user-facing strings that are currently hardcoded and not localized. Per iOS coding guidelines, all user-facing text must use LocalizedStringKey for proper internationalization support.

## Files Affected

### UnaMentis/UI/KnowledgeBowl/KBOralSessionView.swift

**Hardcoded Strings** (lines identified):
- Line 68: `"Question \(viewModel.currentQuestionIndex + 1) of \(viewModel.questions.count)"` - String interpolation blocks localization
- Line 74: `"\(viewModel.session.correctCount) correct"` - String interpolation blocks localization
- Line 111: `"Oral Round Practice"` - Static title
- Line 116: `"Questions will be read aloud. You'll have time to confer, then speak your answer."` - Static subtitle
- Line 141: `"Microphone and speech recognition permissions required"` - Permission message
- Line 149: `"Start Practice"` - Button label
- Line 190: `"Reading Question..."` - Status message
- Line 234-238: Conference timer display with hardcoded "seconds" text
- Line 244: `"Conference Time"` - Label
- Line 266: `"Ready to Answer"` - Status message
- Line 349: `"Submit"` - Button label
- Line 384: `"Correct answer:"` - Label
- Line 401: `"Your answer:"` - Label
- Line 445: `"Session Complete!"` - Completion message
- Line 471: `"Done"` - Button label
- Line 497: `"Accuracy"` - Label

**Error Messages** (KBOralSessionViewModel):
- Line 847: `"Speech recognition unavailable. Please try on a physical device."` - STT error message

## Missing Accessibility Support

Per PR #53 feedback:

### 1. Accessibility Metadata (around lines 139-151)
**Issue**: "Start Practice" button lacks accessibility metadata

**Fix Needed**:
```swift
Button(action: { ... }) {
    Text("Start Practice")
        ...
}
.accessibilityLabel("Start Practice")
.accessibilityHint("Begin oral Knowledge Bowl practice session")
.disabled(!viewModel.hasPermissions)
.accessibilityValue(viewModel.hasPermissions ? "" : "disabled")
```

### 2. Dynamic Type Support
**Issue**: Hardcoded font sizes bypass Dynamic Type

**Fix Needed**:
- Add `@ScaledMetric` properties for responsive sizing
- Example: `@ScaledMetric private var timerFontSize: CGFloat = 64`
- Apply to timer displays and other large text

### 3. Reduce Motion Support (around lines 94-95)
**Issue**: Pulse animations don't respect accessibility reduce motion setting

**Fix Needed**:
```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// In PulseModifier or animation code:
.animation(reduceMotion ? nil : .easeInOut, value: isPulsing)
```

### 4. Accessibility Labels for Interactive Elements
**Issue**: Multiple buttons and controls lack proper accessibility labels, hints, and state

**Affected Elements**:
- Quick start buttons (around lines 159-190)
- Submit answer button
- Done button
- Conference timer controls

## Recommended Approach

### Phase 1: Create Localization Keys
1. Create `KnowledgeBowl.strings` file with all text keys
2. Define keys like:
   ```
   "kb.oral.title" = "Oral Round Practice";
   "kb.oral.subtitle" = "Questions will be read aloud. You'll have time to confer, then speak your answer.";
   "kb.button.start" = "Start Practice";
   "kb.button.submit" = "Submit";
   "kb.button.done" = "Done";
   "kb.status.reading" = "Reading Question...";
   "kb.status.ready" = "Ready to Answer";
   "kb.label.correct_answer" = "Correct answer:";
   "kb.label.your_answer" = "Your answer:";
   "kb.error.stt_unavailable" = "Speech recognition unavailable. Please try on a physical device.";
   ```

### Phase 2: Update Views to Use LocalizedStringKey
Replace all `Text("string")` with `Text("kb.key.name")` using the defined keys.

For string interpolation, use:
```swift
Text("kb.question_count", arguments: [currentIndex + 1, totalCount])
```

With corresponding strings file:
```
"kb.question_count" = "Question %d of %d";
```

### Phase 3: Add Accessibility Metadata
1. Add accessibility labels, hints, and values to all interactive elements
2. Add `@Environment(\.accessibilityReduceMotion)` and respect it
3. Add `@ScaledMetric` for Dynamic Type support
4. Test with VoiceOver enabled

### Phase 4: Testing
1. Test with VoiceOver
2. Test with Dynamic Type at various sizes
3. Test with Reduce Motion enabled
4. Test with RTL languages (if Arabic/Hebrew support is planned)

## Effort Estimate

- Phase 1: 1-2 hours (create comprehensive strings file)
- Phase 2: 2-3 hours (update all views)
- Phase 3: 2-3 hours (add accessibility metadata)
- Phase 4: 1-2 hours (testing)

**Total**: 6-10 hours

## Dependencies

None - can be completed independently

## Related Issues

- PR #53: Original feedback identifying these issues
- iOS Style Guide: Requirement for all user-facing text to be localized

## Testing Checklist

- [ ] All user-facing text uses LocalizedStringKey
- [ ] String interpolation properly formatted for localization
- [ ] VoiceOver reads all elements correctly
- [ ] Dynamic Type scales text appropriately
- [ ] Reduce Motion disables animations
- [ ] All interactive elements have accessibility labels
- [ ] Error messages are localized
- [ ] Status messages are localized
- [ ] Build succeeds with no warnings

## Notes

- Consider using SwiftGen or similar tool for type-safe localization keys
- May want to add support for additional languages beyond English
- Consider using accessibility audit tools in Xcode
