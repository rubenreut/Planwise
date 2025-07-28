# Color System Migration Guide

## Overview
The color system has been simplified to use iOS system colors for automatic dark mode support, removing unnecessary mathematical calculations and Lab color space conversions.

## What Changed

### Removed
- `Color+MathematicalDesign.swift` - Completely removed
- Lab color space calculations
- Complex contrast ratio calculations
- Golden ratio gradient calculations
- Mathematical color creation methods

### Simplified
- All colors now use iOS system colors for automatic dark mode
- Backward compatibility maintained with deprecation warnings
- Cleaner, more semantic color names

## Migration Steps

### 1. Update Import Statements
No changes needed - the new system maintains backward compatibility.

### 2. Color Name Mappings

#### Background Colors
```swift
// Old → New
Color.adaptiveBackground → Color.background
Color.adaptiveSecondaryBackground → Color.secondaryBackground
Color.adaptiveTertiaryBackground → Color.tertiaryBackground
Color.adaptiveCardBackground → Color.cardBackground
```

#### Text Colors
```swift
// Old → New
Color.adaptivePrimaryText → Color.label
Color.adaptiveSecondaryText → Color.secondaryLabel
Color.adaptiveTertiaryText → Color.tertiaryLabel
```

#### System Colors
```swift
// Old → New
Color.adaptiveBlue → Color.systemBlue
Color.adaptiveGreen → Color.systemGreen
Color.adaptiveOrange → Color.systemOrange
Color.adaptiveRed → Color.systemRed
Color.adaptivePurple → Color.systemPurple
```

#### UI Elements
```swift
// Old → New
Color.adaptiveSeparator → Color.separator
Color.adaptiveBorder → Color.separator.opacity(0.5)
Color.adaptiveShadow → Color.shadow
```

#### Chat Colors
```swift
// Old → New
Color.userBubbleBackground → Color.userBubble
Color.aiBubbleBackground → Color.aiBubble
Color.aiBubbleText → Color.label
```

### 3. View Modifiers

```swift
// Old
.adaptiveBackground() → .background(Color.background)
.adaptiveCard() → .cardStyle()
.adaptiveForeground(.primary) → .foregroundColor(.label)
```

### 4. Gradients

```swift
// Old
LinearGradient.golden(from: color1, to: color2)
// New
LinearGradient.simple(color1, color2)

// Old
LinearGradient.adaptiveGradient(from: color1, to: color2)
// New
LinearGradient.simple(color1, color2)
```

### 5. Color Utilities

```swift
// Old
color.toHex() → color.hexString
color.mix(with: other, by: 0.5) → color.mixed(with: other, amount: 0.5)
```

## New Features

### Brand Colors
```swift
Color.Brand.primary   // App primary brand color
Color.Brand.secondary // App secondary brand color
Color.Brand.accent    // App accent color
```

### Status Colors
```swift
Color.success  // Green for success states
Color.warning  // Orange for warnings
Color.error    // Red for errors
Color.info     // Blue for information
```

### New View Modifiers
```swift
// Standard card with shadow
.cardStyle(padding: 16, cornerRadius: 12)

// Elevated card with more prominent shadow
.elevatedCardStyle(padding: 16, cornerRadius: 12)

// Subtle background
.subtleBackground()
```

### Simplified Gradients
```swift
// Brand gradient
LinearGradient.brand

// Simple gradient with angle
LinearGradient.simple(.systemBlue, .systemPurple, angle: 45)

// Subtle background gradient
LinearGradient.subtleBackground(in: colorScheme)
```

## Best Practices

1. **Always use system colors** - They automatically adapt to dark mode
2. **Use semantic names** - `Color.label` instead of hardcoded colors
3. **Avoid custom dark mode logic** - The system colors handle it
4. **Use the status colors** - For consistent success/error/warning states
5. **Leverage view modifiers** - Use `.cardStyle()` for consistent card appearance

## Testing Dark Mode

To test your views in both light and dark mode:

```swift
#Preview("Light Mode") {
    YourView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    YourView()
        .preferredColorScheme(.dark)
}
```

## Example Migration

### Before
```swift
struct MyView: View {
    var body: some View {
        VStack {
            Text("Hello")
                .foregroundColor(.adaptivePrimaryText)
        }
        .adaptiveCard()
        .background(Color.adaptiveBackground)
    }
}
```

### After
```swift
struct MyView: View {
    var body: some View {
        VStack {
            Text("Hello")
                .foregroundColor(.label)
        }
        .cardStyle()
        .background(Color.background)
    }
}
```

## Notes

- The old color names still work but show deprecation warnings
- All mathematical color calculations have been removed
- Dark mode now works automatically with iOS system colors
- No need for manual color scheme detection