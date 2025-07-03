# Timeline Design Context

## Overview
Complete mathematical design system for Momentum's daily timeline view with pixel-perfect precision using golden ratio (φ = 1.618033988749895).

## Core Design Principles
- **Mathematical Foundation**: Every measurement based on φ (golden ratio)
- **Base Unit**: 8px spatial grid, 4px temporal sub-grid
- **Hour Height**: 68px (φ³) instead of standard 60px
- **Surgical Precision**: Every pixel justified mathematically
- **Premium Aesthetic**: Apple-level design with notion-like refinement

## Timeline Components

### 1. DayTimelineView
- **Background**: Pure white (light) / pure black (dark) - no gradients
- **Grid**: Only hour lines, no 15-minute markers (clean minimal look)
- **Hour Labels**: All hours shown (6am-1am) in format "10 am", "7 pm"
- **Line Style**: 0.5px thickness, subtle gray (#E5E5E5 light / #333333 dark)
- **Current Time Indicator**: Red line with time badge, pulse animation
- **Removed**: Temporal accents, background patterns, noise textures

### 2. TimeBlockView (Event Blocks)
- **Priority System**:
  - Critical (red): #FF3B30, semibold text, chromatic aberration
  - Elevated (orange): #FF9500, medium weight, work/meetings
  - Focus (purple): #AF52DE, medium weight, deep work
  - Standard (green): #34C759, regular weight, default
  
- **Visual Features**:
  - 3px colored accent bar on left edge
  - Tinted backgrounds (not inverted colors)
  - Multi-layer shadows based on priority
  - Corner radius varies by priority (8-13px)
  - Duration display: "8:00-10:00 • 2h"
  
- **Spacing**: 
  - Horizontal padding: 16px (baseUnit × 2)
  - Vertical padding: 13px (baseUnit × φ)
  - Time spacing: 8px bullet 4px duration

### 3. Time Pills (Long Press Feature)
- **Trigger**: 0.5 second long press with haptic feedback
- **Position**: 
  - Top left: Start time at (x: -29px, y: 8px)
  - Bottom left: End time at (x: -29px, y: blockHeight)
  - Aligned with timeline hour labels
- **Style**:
  - 10pt semibold monospaced font
  - 8px horizontal padding, 4px vertical
  - Subtle shadow: 10% opacity, 2px radius
  - Matches event priority color
  - Gradient border for directionality

## Layout System

### Event Positioning
```swift
position = (hour - 6) * 68 + (minute * 68 / 60)
height = duration_minutes * (68 / 60)
```

### Overlapping Events
- Column-based layout algorithm
- 4px gap between columns
- Events share available width equally

### ScrollView Structure
- Single ScrollView contains both timeline and events
- Events positioned as overlay on timeline
- Automatic scroll to current time on load

## Color System

### Lab Color Space
- Perceptually uniform color calculations
- WCAG AAA compliance (7:1 contrast minimum)
- Tinted backgrounds instead of pure grays

### Dark Mode
- Tinted dark backgrounds (not inverted)
- Adjusted shadow intensities (2× light mode)
- Maintained brand color consistency

## Interaction Design

### Animations
- Spring: response 0.3, damping 0.86
- Scale on press: 0.969 (1 - 1/φ/20)
- Scale on hover: 1.015 (1 + 1/φ/40)
- Time pill transition: scale(0.8) + opacity

### Gestures
- Tap: Open event details
- Long press: Show time pills
- Drag: Visual feedback only
- Timeline tap: Create event at time

## Implementation Details

### File Structure
```
/Views/
  DayView.swift - Main container
  DayTimelineView.swift - Timeline grid
  TimeBlockView.swift - Event blocks
  EventDetailView.swift - Event details
  AddEventView.swift - Event creation

/Extensions/
  Color+MathematicalDesign.swift - Color system

/Documentation/
  DESIGN_SYSTEM.md - Mathematical framework
  VISUAL_SPECIFICATIONS.md - Precise specs
```

### Key Measurements
- Time column width: 58px
- Minimum event height: 44px
- Base shadow radius: 4px
- Animation duration: 200ms
- Long press delay: 500ms

## Design Evolution
1. Started with complex gradients/textures
2. Simplified to pure white/black background
3. Removed 15-minute marks for cleaner look
4. Changed from top pills to left-aligned pills
5. Refined shadows from 25% to 10% opacity
6. Aligned pills with timeline hour markers

## Critical Rules
- Never use arbitrary values - everything derives from φ or base units
- Maintain visual hierarchy through mathematical relationships
- Test with 0 events, 1000+ events, overlapping events
- Ensure 60fps animations on all devices
- Follow Apple HIG while adding mathematical precision

This design system represents "€1,000,000 button" level attention to detail - every decision backed by mathematical reasoning and perceptual science.