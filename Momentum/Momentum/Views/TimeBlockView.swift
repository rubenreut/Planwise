import SwiftUI
import UIKit

struct TimeBlockView: View {
    let event: Event
    let hourHeight: CGFloat = DeviceType.isIPad ? 80 : 68 // Use same as DayView
    let onTap: () -> Void
    @Binding var isDraggingAnyBlock: Bool
    
    @EnvironmentObject var scheduleManager: ScheduleManager
    
    // Combined state for better performance
    @State private var dragState = DragState()
    @State private var previousTimes = PreviousTimes()
    
    // Feedback generators (not @State)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    struct DragState {
        var isPressed = false
        var isDragging = false
        var showTimePills = false
        var dragOffset: CGFloat = 0
        var lastHapticOffset: Int = 0
        var resetTimer: Timer?
    }
    
    struct PreviousTimes {
        var startTime: String = ""
        var endTime: String = ""
    }
    @Environment(\.colorScheme) var colorScheme
    
    // Design system constants
    private let φ: CGFloat = 1.618033988749895 // Golden ratio
    private let baseUnit: CGFloat = DesignSystem.Spacing.xs // Base spatial unit
    private let timeGridUnit: CGFloat = DesignSystem.Spacing.xxs // Temporal alignment grid
    private let timeColumnWidth: CGFloat = DeviceType.isIPad ? 70 : 58 // Timeline column width
    
    
    // Get the category color directly from Core Data
    private var categoryColor: Color {
        if let colorHex = event.category?.colorHex {
            return Color(hex: colorHex)
        }
        return .accentColor // Use system accent color as fallback
    }
    
    
    private var duration: TimeInterval {
        guard let start = event.startTime,
              let end = event.endTime else { return 0 }
        return end.timeIntervalSince(start)
    }
    
    private var blockHeight: CGFloat {
        let minutes = duration / 60
        let pixelsPerMinute = hourHeight / 60
        let exactHeight = CGFloat(minutes) * pixelsPerMinute
        
        // Return exact height - no minimum for accurate representation
        // This ensures 30min = exactly half hour block, 15min = exactly quarter, etc.
        return exactHeight
    }
    
    var body: some View {
        ZStack {
            // Time pills overlay - positioned OUTSIDE the draggable block
            if dragState.showTimePills {
                timePillsOverlay
                    .offset(y: dragState.dragOffset) // Move with the block
            }
            
            // Main block
            TimelineGeometryReader { geometry in
                HStack(spacing: 0) {
                    // Accent bar with optical correction
                    accentBar
                    
                    // Main content with mathematical spacing
                    VStack(alignment: .leading, spacing: 0) {
                        // Title section with precise spacing
                        titleSection
                            .padding(.bottom, shouldShowTimeInfo ? timeGridUnit : 0) // Spacing only if time shown
                        
                        // Time section with precise spacing
                        if shouldShowTimeInfo {
                            timeSection
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, DesignSystem.Spacing.md)
                    .padding(.trailing, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: blockHeight)
                .background(backgroundLayer)
                .overlay(overlayEffects)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .scaleEffect(scaleFactor)
                .opacity(opacityValue)
                .animation(.spring(response: 0.3, dampingFraction: 0.86, blendDuration: 0), value: dragState.isPressed)
            }
            .offset(y: dragState.dragOffset)
        }
        .onTapGesture {
            // Handle tap
            impactFeedback.impactOccurred()
            onTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view details")
        .accessibilityAddTraits(.isButton)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    // Long press detected
                    impactFeedback.impactOccurred()
                    // No animation - instant appearance
                    dragState.showTimePills = true
                    dragState.isPressed = true
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: dragState.showTimePills ? 5 : 30)
                .onChanged { value in
                    // Only handle drag if time pills are showing
                    if dragState.showTimePills {
                        if !dragState.isDragging {
                            dragState.isDragging = true
                            isDraggingAnyBlock = true
                            selectionFeedback.prepare()
                        }
                        
                        // Calculate drag offset with snapping
                        let pixelsPerMinute = hourHeight / 60.0
                        let pixelsPer5Minutes = pixelsPerMinute * 5.0
                        let rawOffset = value.translation.height
                        let intervals = rawOffset / pixelsPer5Minutes
                        let snappedIntervals = round(intervals)
                        let snappedOffset = snappedIntervals * pixelsPer5Minutes
                        
                        dragState.dragOffset = snappedOffset
                        
                        // Haptic feedback for intervals
                        let currentSnapInterval = Int(snappedIntervals)
                        if currentSnapInterval != dragState.lastHapticOffset {
                            selectionFeedback.selectionChanged()
                            dragState.lastHapticOffset = currentSnapInterval
                        }
                    }
                }
                .onEnded { _ in
                    if dragState.isDragging {
                        applyTimeChange()
                    }
                    
                    // Reset states individually to avoid animation conflicts
                    isDraggingAnyBlock = false
                    
                    // No animation for pill hiding
                    dragState.dragOffset = 0
                    dragState.showTimePills = false
                    dragState.isPressed = false
                    dragState.isDragging = false
                    dragState.lastHapticOffset = 0
                }
        )
        .onAppear {
            // Prepare haptic engines
            selectionFeedback.prepare()
            impactFeedback.prepare()
            // Removed haptic setup for performance
        }
        .onDisappear {
            dragState.resetTimer?.invalidate()
            dragState.resetTimer = nil
        }
    }
    
    // MARK: - Subviews
    
    private var timePillsOverlay: some View {
        GeometryReader { geometry in
            Group {
                // Top left pill - start time (aligned with hour line)
                if let startTime = event.startTime {
                timePill(time: startTime, isStart: true)
                    .position(
                        x: -timeColumnWidth / 2, // Center of time column (58/2 = 29px)
                        y: 0 // Top of block
                    )
            }
            
                // Bottom left pill - end time (aligned with hour line)
                if let endTime = event.endTime {
                    timePill(time: endTime, isStart: false)
                        .position(
                            x: -timeColumnWidth / 2, // Center of time column (58/2 = 29px)
                            y: geometry.size.height // Bottom of block
                        )
                }
            }
        }
        .frame(height: blockHeight) // Match the block height
        .allowsHitTesting(false) // Don't interfere with gestures
    }
    
    @ViewBuilder
    private func timePill(time: Date?, isStart: Bool) -> some View {
        if let time = time {
            let adjustedTime = dragState.isDragging ? adjustTimeForDrag(time) : time
            let timeString = formatTime(adjustedTime)
            let previousString = isStart ? previousTimes.startTime : previousTimes.endTime
            
            HStack(spacing: 0) {
                // Each character gets its own view for individual animation
                ForEach(Array(timeString.enumerated()), id: \.offset) { index, char in
                    if char == ":" {
                        Text(":")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    } else {
                        // Simple digit without animation
                        Text(String(char))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .padding(.vertical, DesignSystem.Spacing.xxs + 2)
            .background(
                Capsule()
                    .fill(categoryColor)
            )
            .overlay(
                // Subtle directional indicator
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(DesignSystem.Opacity.strong),
                                .white.opacity(DesignSystem.Opacity.light)
                            ],
                            startPoint: isStart ? .top : .bottom,
                            endPoint: isStart ? .bottom : .top
                        ),
                        lineWidth: 1
                    )
            )
            .onChange(of: timeString) { oldValue, newValue in
                if isStart {
                    previousTimes.startTime = newValue
                } else {
                    previousTimes.endTime = newValue
                }
            }
            .onAppear {
                if isStart {
                    previousTimes.startTime = timeString
                } else {
                    previousTimes.endTime = timeString
                }
            }
        }
    }
    
    private var accentBar: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        categoryColor,
                        categoryColor.opacity(1 - DesignSystem.Opacity.light)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: DesignSystem.Spacing.xxs - 1) // 3pt for visual weight at any scale
            .opacity(dragState.isPressed ? 1 - DesignSystem.Opacity.medium : 1.0)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs / 2) {
            Text(event.title ?? "Untitled")
                .font(.system(size: 15, weight: titleWeight, design: .default))
                .foregroundColor(Color.adaptivePrimaryText)
                .tracking(-0.4)
        }
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            if let startTime = event.startTime,
               let endTime = event.endTime {
                // Time with monospace precision and duration
                HStack(spacing: DesignSystem.Spacing.xs) {
                    // Time range text with exact-width gray bar
                    Text(formatTimeRange(
                        start: dragState.isDragging ? adjustTimeForDrag(startTime) : startTime,
                        end: dragState.isDragging ? adjustTimeForDrag(endTime) : endTime
                    ))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.adaptiveSecondaryText)
                        .tracking(0.2)
                        .opacity(dragState.showTimePills ? 0 : 1) // Hide only time range when showing pills
                        .background(
                            // Gray bar overlay when dragging - matches text width exactly
                            dragState.showTimePills ?
                            Capsule()
                                .fill(colorScheme == .dark ? Color(white: DesignSystem.Opacity.medium) : Color(white: 1 - DesignSystem.Opacity.strong))
                                .frame(height: 14) // Thinner bar
                                // No transition - instant appearance
                            : nil
                        )
                    
                    // Duration with bullet separator - always visible
                    HStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("•")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(Color.adaptiveSecondaryText.opacity(DesignSystem.Opacity.disabled))
                        
                        Text(formatDuration(
                            start: dragState.isDragging ? adjustTimeForDrag(startTime) : startTime,
                            end: dragState.isDragging ? adjustTimeForDrag(endTime) : endTime
                        ))
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(Color.adaptiveSecondaryText.opacity(1 - DesignSystem.Opacity.strong))
                            .tracking(0.1)
                    }
                }
                
                // Location with SF Symbols
                if shouldShowLocation,
                   let location = event.location, !location.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.xxs) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color.adaptiveSecondaryText.opacity(1 - DesignSystem.Opacity.strong))
                        
                        Text(location)
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(Color.adaptiveSecondaryText)
                            .tracking(-0.2)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
    
    // MARK: - Visual Effects
    
    private var backgroundLayer: some View {
        // Simple solid background
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(categoryColor.opacity(colorScheme == .dark ? 0.15 : 0.1))
    }
    
    private var overlayEffects: some View {
        // Simple border and shadow
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(categoryColor.opacity(0.2), lineWidth: 1)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                radius: dragState.isPressed ? 6 : 3,
                x: 0,
                y: dragState.isPressed ? 3 : 1
            )
    }
    
    
    
    // MARK: - Computed Properties
    
    private var accessibilityLabel: String {
        var components: [String] = []
        
        // Event title
        components.append(event.title ?? "Untitled event")
        
        // Time information
        if let startTime = event.startTime, let endTime = event.endTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let start = formatter.string(from: startTime)
            let end = formatter.string(from: endTime)
            components.append("from \(start) to \(end)")
            
            // Duration
            let duration = formatDuration(start: startTime, end: endTime)
            components.append("duration \(duration)")
        }
        
        // Category
        if let categoryName = event.category?.name {
            components.append("category \(categoryName)")
        }
        
        // Location
        if let location = event.location, !location.isEmpty {
            components.append("at \(location)")
        }
        
        // Completion status
        if event.isCompleted {
            components.append("completed")
        }
        
        return components.joined(separator: ", ")
    }
    
    private var cornerRadius: CGFloat {
        DesignSystem.CornerRadius.sm + 5 // 13pt corner radius
    }
    
    private var titleWeight: Font.Weight {
        .medium // Consistent weight for all events
    }
    
    private var shouldShowTimeInfo: Bool {
        // Show time if height >= φ² × baseUnit × 2 = 41.89 ≈ 44pt
        blockHeight >= 44
    }
    
    private var shouldShowLocation: Bool {
        // Show location if height >= φ³ × baseUnit = 68pt
        blockHeight >= hourHeight
    }
    
    
    private var scaleFactor: CGFloat {
        // Responsive scale based on interaction state
        if dragState.isDragging {
            return 1.05
        } else if dragState.isPressed {
            return 1.02
        } else {
            return 1.0
        }
    }
    
    private var opacityValue: Double {
        dragState.isPressed ? 0.95 : 1.0
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        // Use en dash for mathematical correctness
        return "\(formatter.string(from: start))–\(formatter.string(from: end))"
    }
    
    private func formatDuration(start: Date, end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        // Format with consistent spacing
        if hours > 0 && minutes > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if hours > 0 {
            return String(format: "%dh", hours)
        } else {
            return String(format: "%dm", minutes)
        }
    }
    
    // MARK: - Drag Time Adjustment
    
    private func adjustTimeForDrag(_ time: Date) -> Date {
        // Calculate offset in 5-minute intervals
        let pixelsPerMinute = hourHeight / 60.0
        let pixelsPer5Minutes = pixelsPerMinute * 5.0
        let intervals = dragState.dragOffset / pixelsPer5Minutes
        let snappedIntervals = round(intervals)
        let offsetMinutes = Int(snappedIntervals * 5)
        
        return Calendar.current.date(byAdding: .minute, value: offsetMinutes, to: time) ?? time
    }
    
    private func applyTimeChange() {
        guard let startTime = event.startTime,
              let endTime = event.endTime else { return }
        
        // Calculate offset in 5-minute intervals
        let pixelsPerMinute = hourHeight / 60.0
        let pixelsPer5Minutes = pixelsPerMinute * 5.0
        let intervals = dragState.dragOffset / pixelsPer5Minutes
        let snappedIntervals = round(intervals)
        let offsetMinutes = Int(snappedIntervals * 5)
        
        guard let newStartTime = Calendar.current.date(byAdding: .minute, value: offsetMinutes, to: startTime),
              let newEndTime = Calendar.current.date(byAdding: .minute, value: offsetMinutes, to: endTime) else { return }
        
        // Prevent dragging across day boundaries
        let calendar = Calendar.current
        let originalDay = calendar.startOfDay(for: startTime)
        let newDay = calendar.startOfDay(for: newStartTime)
        
        if originalDay != newDay {
            impactFeedback.impactOccurred()
            return
        }
        
        // Update the event using ScheduleManager
        let result = scheduleManager.updateEvent(
            event,
            title: nil,
            startTime: newStartTime,
            endTime: newEndTime,
            category: nil,
            notes: nil,
            location: nil,
            isCompleted: nil,
            colorHex: nil,
            iconName: nil,
            priority: nil,
            tags: nil,
            url: nil,
            energyLevel: nil,
            weatherRequired: nil,
            bufferTimeBefore: nil,
            bufferTimeAfter: nil,
            recurrenceRule: nil,
            recurrenceEndDate: nil,
            linkedTasks: nil
        )
        
        // Haptic feedback on success
        if case .success = result {
            impactFeedback.impactOccurred()
            // No need for forceRefresh - updateEvent already triggers updates
        }
    }
    
    // Removed complex haptic implementation for performance
}

// MARK: - Digit Direction

enum DigitDirection {
    case up, down
}

// MARK: - Custom Geometry Reader for Timeline
struct TimelineGeometryReader<Content: View>: View {
    @ViewBuilder let content: (GeometryProxy) -> Content
    
    var body: some View {
        GeometryReader { geometry in
            content(geometry)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}


// MARK: - Preview

struct TimeBlockPreview: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Critical
            createPreviewEvent(title: "Board Meeting", category: "critical", duration: 90)
            
            // Elevated
            createPreviewEvent(title: "Design Review", category: "important", duration: 60)
            
            // Focus
            createPreviewEvent(title: "Deep Work Session", category: "focus", duration: 120)
            
            // Standard
            createPreviewEvent(title: "Lunch Break", category: "personal", duration: 45)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    @ViewBuilder
    private func createPreviewEvent(title: String, category: String, duration: TimeInterval) -> some View {
        let context = PersistenceController.preview.container.viewContext
        let event = Event(context: context)
        event.title = title
        event.startTime = Date()
        event.endTime = Date().addingTimeInterval(duration * 60)
        event.location = "Conference Room A"
        
        let cat = Category(context: context)
        cat.name = category
        event.category = cat
        
        return TimeBlockView(
            event: event,
            onTap: { },
            isDraggingAnyBlock: .constant(false)
        )
        .frame(width: 300)
        .environmentObject(ScheduleManager.shared)
    }
}

#Preview("TimeBlock Variations") {
    TimeBlockPreview()
}