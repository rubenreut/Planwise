# Momentum Button System Documentation

## Overview
A comprehensive, professional button system has been implemented to replace the basic ScaleButtonStyle. The new system provides consistent, accessible, and visually polished buttons throughout the app.

## Button Styles

### 1. Primary Button Style
- **Use**: Main actions, CTAs
- **Appearance**: Filled with accent color, white text
- **States**: Normal, pressed, disabled, hover (iPad/Mac)
- **Example**: "Create Task", "Save", "Continue"

### 2. Secondary Button Style
- **Use**: Secondary actions, alternatives
- **Appearance**: Outlined with accent color border
- **States**: Normal, pressed, disabled, hover
- **Example**: "Cancel", "Browse", "View All"

### 3. Tertiary Button Style
- **Use**: Low-emphasis actions
- **Appearance**: No border, subtle background on interaction
- **States**: Normal, pressed, disabled, hover
- **Example**: "Skip", "Learn More"

### 4. Destructive Button Style
- **Use**: Dangerous/irreversible actions
- **Appearance**: Red background, white text
- **States**: Normal, pressed, disabled, hover
- **Example**: "Delete", "Remove All"

### 5. Ghost Button Style
- **Use**: Minimal emphasis, inline actions
- **Appearance**: Transparent, subtle interaction
- **States**: Normal, pressed, disabled, hover
- **Example**: Inline toggles, expandable sections

## Button Sizes

- **Small**: 32pt height, 14pt font
- **Medium**: 44pt height, 17pt font (default, meets minimum touch target)
- **Large**: 56pt height, 20pt font

## Specialized Components

### IconButton
- Circular icon-only buttons
- Available in all styles
- Proper touch targets (44pt minimum)
- Built-in accessibility labels

### FloatingActionButton
- 56pt circular button
- Elevated with shadow
- Primary actions like "Add"
- Includes haptic feedback

### LoadingButton
- Shows progress indicator while loading
- Maintains button size during loading
- Automatically disables during loading
- Available for all button styles

## Usage Examples

```swift
// Primary button
MomentumButton("Save Changes", icon: "checkmark", style: .primary) {
    saveChanges()
}

// Secondary button with size
MomentumButton("Cancel", style: .secondary, size: .small) {
    dismiss()
}

// Loading button
LoadingButton(action: submit, isLoading: isSubmitting) {
    Text("Submit")
}

// Icon button
IconButton(
    icon: "gear",
    style: .secondary,
    accessibilityLabel: "Settings"
) {
    showSettings()
}

// Floating action button
FloatingActionButton(
    icon: "plus",
    accessibilityLabel: "Create new"
) {
    createNew()
}
```

## Features

### Accessibility
- All buttons meet WCAG touch target guidelines (44pt minimum)
- Proper accessibility labels and traits
- VoiceOver support
- High contrast mode support

### Visual Feedback
- Scale animation on press (0.96 scale)
- Opacity changes for states
- Smooth spring animations
- Hover effects for iPad/Mac

### Haptic Feedback
- Built-in haptic feedback support
- Light impact for most buttons
- Medium impact for primary actions
- Success/error feedback for results

### Platform Adaptations
- Hover states for iPad/Mac
- Proper touch targets for all devices
- Responsive sizing
- Platform-specific optimizations

## Migration Guide

### Old ScaleButtonStyle
```swift
// Before
Button("Save") { save() }
    .buttonStyle(ScaleButtonStyle())

// After
MomentumButton("Save", style: .primary) { save() }
```

### Custom Buttons
```swift
// Before
Button { action() } label: {
    HStack {
        Image(systemName: "plus")
        Text("Add")
    }
    .padding()
    .background(Color.blue)
    .cornerRadius(8)
}

// After
MomentumButton("Add", icon: "plus", style: .primary) { action() }
```

## Best Practices

1. **Use appropriate styles**: Primary for main actions, secondary for alternatives
2. **Include icons**: When space allows, icons improve recognition
3. **Provide feedback**: Use loading states and haptic feedback
4. **Ensure accessibility**: Always include proper labels
5. **Test touch targets**: Verify 44pt minimum on all devices

## Technical Details

- Located in: `/Views/ButtonSystem.swift`
- Integrates with: `DesignSystem.swift`
- Deprecated: `ScaleButtonStyle` in `CommonButtonStyles.swift`
- Dependencies: SwiftUI, UIKit (for haptics)