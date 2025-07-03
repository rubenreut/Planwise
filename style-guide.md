# Momentum Style Guide

## 🎨 Design Philosophy
- **Clean & Sophisticated**: Apple meets Notion
- **Minimal by Default**: Power features hidden until needed
- **Delightful Details**: Smooth animations, haptic feedback
- **Information Density**: Show a lot without clutter

## 🎨 Visual Design

### Color Palette
```swift
// Brand Colors
primary: #007AFF (Apple Blue)
secondary: #5856D6 (Purple)
accent: #FF9500 (Orange)

// Semantic Colors
success: #34C759
warning: #FF9500
error: #FF3B30
info: #5856D6

// Category Colors (High Contrast)
work: #007AFF (Blue)
personal: #34C759 (Green)  
health: #FF3B30 (Red)
social: #FF9500 (Orange)
tasks: #5856D6 (Purple)

// Backgrounds
background: systemBackground
secondaryBackground: secondarySystemBackground
tertiaryBackground: tertiarySystemBackground

// Text
primaryText: label
secondaryText: secondaryLabel
tertiaryText: tertiaryLabel
```

### Typography
```swift
// Fonts - SF Pro throughout
.largeTitle: 34pt, weight: .bold
.title: 28pt, weight: .bold
.title2: 22pt, weight: .bold
.title3: 20pt, weight: .semibold
.headline: 17pt, weight: .semibold
.body: 17pt, weight: .regular
.callout: 16pt, weight: .regular
.subheadline: 15pt, weight: .regular
.footnote: 13pt, weight: .regular
.caption: 12pt, weight: .regular
.caption2: 11pt, weight: .regular

// Usage
Event titles: .headline
Time labels: .subheadline
Category labels: .caption
Notes: .body
```

### Spacing System
```swift
// Consistent spacing scale
spacing.micro: 4
spacing.small: 8
spacing.medium: 16
spacing.large: 24
spacing.xlarge: 32

// Usage
Padding within cards: .medium
Spacing between cards: .small
Section spacing: .large
```

### Corner Radius
```swift
// Consistent curves
radius.small: 8 (buttons, small elements)
radius.medium: 12 (cards, inputs)
radius.large: 16 (modals, sheets)
radius.xlarge: 20 (special elements)

// Time blocks: radius.medium
```

## 📱 Component Design

### Time Blocks
```swift
TimeBlockView:
- Height: Dynamic based on duration
- Min height: 44pt (tappable)
- Background: Category color at 15% opacity
- Border: Category color at 100%
- Border width: 2pt
- Corner radius: 12
- Left accent bar: 4pt wide, full height
- Padding: 12pt all sides
- Shadow: None (too busy with many blocks)
```

### Buttons
```swift
PrimaryButton:
- Height: 50pt
- Background: primary color
- Text: white, .headline
- Corner radius: 12
- Pressed: 90% opacity

SecondaryButton:
- Height: 44pt
- Background: clear
- Border: 1pt, tertiaryLabel color
- Text: primary color
- Corner radius: 10
```

### Input Fields
```swift
TextField:
- Height: 44pt
- Background: tertiarySystemBackground
- Corner radius: 10
- Padding: horizontal 16pt
- Font: .body
- Clear button: when editing
```

## 🎬 Animations

### Timing
```swift
// Animation durations
micro: 0.1s (haptic feedback sync)
fast: 0.2s (button presses)
normal: 0.3s (most transitions)
slow: 0.5s (page transitions)

// Spring animations preferred
.spring(response: 0.3, dampingFraction: 0.8)
```

### Standard Animations
```swift
// Adding time block
- Scale from 0.8 → 1.0
- Opacity 0 → 1
- Slight bounce at end

// Completing task
- Check mark scales 0 → 1.2 → 1.0
- Block background flashes
- Haptic: .success

// Deleting
- Scale to 0.8
- Fade out
- Remaining blocks slide up
```

## 🎯 Interaction Design

### Gestures
```swift
// Tap
- Create event: Tap empty space
- Edit event: Tap block
- Quick complete: Tap checkbox

// Long Press
- Show context menu
- Haptic: .medium

// Drag
- Resize blocks: Drag edges
- Move blocks: Drag center (v2)
- Visual feedback: 10% scale up

// Swipe
- Navigate days: Horizontal swipe
- Delete block: Swipe left (maybe)
```

### Haptic Feedback
```swift
// Impact
.light: Tab switches, toggles
.medium: Block selection
.heavy: Delete actions

// Notification
.success: Task completed
.warning: Conflict detected
.error: Action failed

// Selection
Used for time picker scrolling
```

## 📐 Layout Principles

### Grid System
```swift
// Day view
- 24 rows (hours)
- Each hour = 60pt height
- 15-min increments = 15pt
- Left time labels: 50pt wide
- Right padding: 16pt

// Week view  
- 7 columns
- Equal width
- Header height: 44pt
- Compressed blocks
```

### Responsive Design
```swift
// iPhone SE → Pro Max
if screenWidth < 375 {
    // Reduce padding
    // Smaller fonts
    // Hide non-essential
}

// iPad
if horizontalSizeClass == .regular {
    // Side-by-side views
    // Floating panels
    // Multi-column
}
```

## 🎨 Theme System

### Light Mode (Default)
- Clean white backgrounds
- High contrast
- Subtle shadows
- Bright category colors

### Dark Mode
- Pure black option
- Reduced white point
- Softer colors
- No harsh contrasts

### Custom Themes (Premium)
```swift
struct Theme {
    let name: String
    let background: Color
    let surface: Color
    let primary: Color
    let categoryColors: [Color]
    let style: ThemeStyle // .minimal, .playful, .professional
}
```

## 🚫 Don'ts

### Visual Don'ts
- ❌ Gradients (except subtle overlays)
- ❌ Drop shadows on time blocks
- ❌ Neon/harsh colors
- ❌ Custom fonts
- ❌ Overuse of borders
- ❌ Cluttered interfaces

### Animation Don'ts
- ❌ Bouncy/playful animations (keep professional)
- ❌ Long durations (>0.5s)
- ❌ Animation on scroll
- ❌ Parallax effects
- ❌ Auto-playing animations

### Interaction Don'ts
- ❌ Custom gestures
- ❌ Hidden functionality
- ❌ Confirmation for everything
- ❌ Tiny tap targets (<44pt)
- ❌ Unexpected behaviors

## ✅ Do's

### Visual Do's
- ✅ High contrast for accessibility
- ✅ Consistent spacing
- ✅ Clear hierarchy
- ✅ SF Symbols for icons
- ✅ Native components when possible
- ✅ Breathing room

### Animation Do's
- ✅ Enhance understanding
- ✅ Provide feedback
- ✅ Guide attention
- ✅ Respect reduce motion
- ✅ Feel native to iOS

### Interaction Do's
- ✅ Predictable behaviors
- ✅ Immediate feedback
- ✅ Forgiving actions (undo)
- ✅ Clear affordances
- ✅ Respect platform conventions

## 📝 Code Style

### SwiftUI Best Practices
```swift
// View composition over massive views
struct EventRow: View {
    let event: Event
    
    var body: some View {
        HStack {
            CategoryIndicator(event.category)
            EventDetails(event)
            CompletionToggle(event)
        }
    }
}

// ViewModifiers for reusable styling
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.secondaryBackground)
            .cornerRadius(12)
            .shadow(radius: 2)
    }
}

// Computed properties for complex logic
var timeString: String {
    event.startTime.formatted(date: .omitted, time: .shortened)
}
```

### Naming Conventions
```swift
// Views: Descriptive noun
EventDetailView, ScheduleGridView

// View Models: ViewNameViewModel
ScheduleViewModel, AIAssistantViewModel

// Managers: Single responsibility
ScheduleManager, ThemeManager

// Models: Simple nouns
Event, Category, Theme

// Functions: Verb phrases
func createEvent(_ event: Event)
func rescheduleAllEvents(after date: Date)
```

Remember: When in doubt, follow Apple's Human Interface Guidelines!