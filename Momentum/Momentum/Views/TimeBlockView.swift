import SwiftUI
import UIKit
import CoreHaptics

struct TimeBlockView: View {
    let event: Event
    let hourHeight: CGFloat = 68 // φ³ - Golden ratio cubed
    let onTap: () -> Void
    @Binding var isDraggingAnyBlock: Bool
    
    @EnvironmentObject var scheduleManager: ScheduleManager
    
    @State private var isPressed = false
    @State private var isHovered = false
    @State private var showTimePills = false
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    @State private var lastHapticOffset: Int = 0
    @State private var lastDragOffset: CGFloat = 0
    @State private var selectionFeedback = UISelectionFeedbackGenerator()
    @State private var impactFeedback = UIImpactFeedbackGenerator(style: .light)
    @State private var mediumImpactFeedback = UIImpactFeedbackGenerator(style: .medium)
    @State private var hapticEngine: CHHapticEngine?
    @State private var continuousPlayer: CHHapticPatternPlayer?
    @State private var initialDragLocation: CGPoint = .zero
    @State private var previousStartTime: String = ""
    @State private var previousEndTime: String = ""
    @State private var resetTimer: Timer?
    @Environment(\.colorScheme) var colorScheme
    
    // Mathematical constants
    private let φ: CGFloat = 1.618033988749895 // Golden ratio
    private let baseUnit: CGFloat = 8 // Base spatial unit
    private let timeGridUnit: CGFloat = 4 // Temporal alignment grid
    private let timeColumnWidth: CGFloat = 58 // Timeline column width
    
    // Priority levels with sophisticated logic
    private var priority: Priority {
        guard let categoryName = event.category?.name?.lowercased() else { return .standard }
        
        switch categoryName {
        case "critical", "urgent", "deadline":
            return .critical
        case "important", "work", "meeting":
            return .elevated
        case "focus", "deep work":
            return .focus
        default:
            return .standard
        }
    }
    
    // Get the category color directly from Core Data
    private var categoryColor: Color {
        if let colorHex = event.category?.colorHex {
            return Color(hex: colorHex)
        }
        return priority.accentColor
    }
    
    enum Priority {
        case critical, elevated, focus, standard
        
        func backgroundColor(for colorScheme: ColorScheme) -> Color {
            // Use tinted backgrounds based on accent color with proper light/dark adaptation
            switch self {
            case .critical:
                return colorScheme == .dark
                    ? Color(red: 0.3, green: 0.15, blue: 0.15) // Dark red tint
                    : Color(red: 1.0, green: 0.95, blue: 0.95) // Light red tint
            case .elevated:
                return colorScheme == .dark
                    ? Color(red: 0.25, green: 0.2, blue: 0.1) // Dark orange tint
                    : Color(red: 1.0, green: 0.97, blue: 0.94) // Light orange tint
            case .focus:
                return colorScheme == .dark
                    ? Color(red: 0.2, green: 0.15, blue: 0.25) // Dark purple tint
                    : Color(red: 0.98, green: 0.96, blue: 1.0) // Light purple tint
            case .standard:
                return colorScheme == .dark
                    ? Color(red: 0.11, green: 0.11, blue: 0.118) // #1C1C1E
                    : Color(red: 0.949, green: 0.949, blue: 0.969) // #F2F2F7
            }
        }
        
        
        func textColor(for colorScheme: ColorScheme) -> Color {
            // Always use high contrast text for readability
            switch self {
            case .critical, .elevated, .focus:
                return colorScheme == .dark
                    ? Color(red: 0.95, green: 0.95, blue: 0.97) // Very light
                    : Color(red: 0.1, green: 0.1, blue: 0.1) // Very dark
            case .standard:
                return colorScheme == .dark
                    ? Color(red: 0.949, green: 0.949, blue: 0.969) // #F2F2F7
                    : Color(red: 0.067, green: 0.067, blue: 0.067) // #111111
            }
        }
        
        func secondaryTextColor(for colorScheme: ColorScheme) -> Color {
            // WCAG AA compliant (4.5:1) using φ ratio for opacity
            let φ = 1.618033988749895
            switch self {
            case .critical, .elevated, .focus:
                return textColor(for: colorScheme).opacity(1/φ) // 0.618
            case .standard:
                return colorScheme == .dark
                    ? Color(red: 0.706, green: 0.706, blue: 0.714) // #B4B4B6
                    : Color(red: 0.353, green: 0.353, blue: 0.361) // #5A5A5C
            }
        }
        
        var accentColor: Color {
            // Colors chosen for 40+ ΔE separation in Lab space
            switch self {
            case .critical:
                // L*53 C*70 in both modes for consistency
                return Color(red: 1, green: 0.231, blue: 0.188) // #FF3B30
            case .elevated:
                // L*68 C*85 - φ ratio lighter than critical
                return Color(red: 1, green: 0.584, blue: 0) // #FF9500
            case .focus:
                // L*55 C*60 - Triadic harmony (280° hue)
                return Color(red: 0.686, green: 0.322, blue: 0.871) // #AF52DE
            case .standard:
                // L*60 C*55 - Complementary split (140° hue)
                return Color(red: 0.204, green: 0.78, blue: 0.349) // #34C759
            }
        }
        
        func shadowIntensity(for colorScheme: ColorScheme) -> Double {
            // Shadow opacity based on φ ratios and color scheme
            let base = colorScheme == .dark ? 0.4 : 0.2
            let φ = 1.618033988749895
            
            switch self {
            case .critical: return base
            case .elevated: return base / φ // 0.247 dark, 0.124 light
            case .focus: return base / (φ * φ) // 0.153 dark, 0.076 light
            case .standard: return base / (φ * φ * φ) // 0.094 dark, 0.047 light
            }
        }
    }
    
    private var duration: TimeInterval {
        guard let start = event.startTime,
              let end = event.endTime else { return 0 }
        return end.timeIntervalSince(start)
    }
    
    private var blockHeight: CGFloat {
        let minutes = duration / 60
        let pixelsPerMinute = hourHeight / 60 // 1.133...
        let rawHeight = CGFloat(minutes) * pixelsPerMinute
        
        // Snap to temporal grid (4pt) for precise alignment
        let snappedHeight = round(rawHeight / timeGridUnit) * timeGridUnit
        
        // Minimum height: φ³ × base unit = 42.94 ≈ 44pt
        let minHeight = round(φ * φ * φ * baseUnit / timeGridUnit) * timeGridUnit
        return max(snappedHeight, minHeight)
    }
    
    var body: some View {
        ZStack {
            // Main block
            TimelineGeometryReader { geometry in
                HStack(spacing: 0) {
                    // Accent bar with optical correction
                    accentBar
                    
                    // Main content with mathematical spacing
                    VStack(alignment: .leading, spacing: 0) {
                        // Title section with precise spacing
                        titleSection
                            .padding(.bottom, shouldShowTimeInfo ? timeGridUnit : 0) // 4pt only if time shown
                        
                        // Time section with precise spacing
                        if shouldShowTimeInfo {
                            timeSection
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, baseUnit * 2) // 16pt
                    .padding(.trailing, baseUnit * 2) // 16pt - symmetric for balance
                    .padding(.vertical, baseUnit * φ) // 13pt - golden ratio
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: blockHeight)
                .background(backgroundLayer)
                .overlay(overlayEffects)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
                .scaleEffect(scaleFactor)
                .opacity(opacityValue)
                .animation(.spring(response: 0.3, dampingFraction: 0.86, blendDuration: 0), value: isPressed)
                .animation(.easeOut(duration: 0.2), value: isHovered)
                .animation(showTimePills ? .spring(response: 0.5, dampingFraction: 0.85) : nil, value: showTimePills)
            }
            
            // Time pills overlay - positioned with mathematical precision
            if showTimePills {
                timePillsOverlay
                    // No transition - appear/disappear instantly
            }
        }
        .offset(y: dragOffset)
        .animation(isDragging ? nil : .interactiveSpring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
        .onTapGesture {
            // Handle tap
            impactFeedback.impactOccurred()
            onTap()
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onChanged { _ in
                    // Press started - show visual feedback immediately
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    // Long press detected
                    impactFeedback.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showTimePills = true
                    }
                    
                    // Start a timer to reset if no drag happens
                    resetTimer?.invalidate()
                    resetTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                        if !isDragging {
                            showTimePills = false
                            isPressed = false
                        }
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    if showTimePills && !isDragging {
                        // Start dragging after pills are shown
                        isDragging = true
                        isDraggingAnyBlock = true
                        selectionFeedback.prepare()
                        print("🎯 DEBUG: Starting drag")
                        // Start continuous haptic feedback
                        startContinuousHaptic()
                        
                        // Cancel the reset timer since we're now dragging
                        resetTimer?.invalidate()
                        resetTimer = nil
                    }
                    
                    if isDragging {
                        // Calculate 5-minute intervals more precisely
                        let pixelsPerMinute = hourHeight / 60.0 // 68/60 = 1.1333...
                        let pixelsPer5Minutes = pixelsPerMinute * 5.0 // 5.6666...
                        
                        // Snap to 5-minute intervals
                        let rawOffset = value.translation.height
                        let intervals = rawOffset / pixelsPer5Minutes
                        let snappedIntervals = round(intervals)
                        let snappedOffset = snappedIntervals * pixelsPer5Minutes
                        
                        dragOffset = snappedOffset
                        
                        // Update continuous haptic intensity based on drag speed
                        let dragSpeed = rawOffset - lastDragOffset
                        updateHapticIntensity(for: dragSpeed)
                        lastDragOffset = rawOffset
                        
                        // Custom haptic feedback for 5-minute intervals
                        let currentSnapInterval = Int(snappedIntervals)
                        if currentSnapInterval != lastHapticOffset {
                            print("📳 DEBUG: 5-minute snap haptic - interval changed from \(lastHapticOffset) to \(currentSnapInterval)")
                            
                            // Gentle haptic feedback for 5-minute marks
                            selectionFeedback.selectionChanged()
                            
                            lastHapticOffset = currentSnapInterval
                        }
                    }
                }
                .onEnded { value in
                    if isDragging {
                        // Stop continuous haptic
                        stopContinuousHaptic()
                        
                        // Apply the time change
                        applyTimeChange()
                        isDragging = false
                        isDraggingAnyBlock = false
                        dragOffset = 0
                        lastHapticOffset = 0
                        lastDragOffset = 0
                    }
                    
                    // Reset everything - no animation for pills
                    showTimePills = false
                    isPressed = false
                }
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            // Prepare haptic engines
            selectionFeedback.prepare()
            impactFeedback.prepare()
            mediumImpactFeedback.prepare()
            setupHaptics()
        }
        .onDisappear {
            stopHaptics()
            resetTimer?.invalidate()
            resetTimer = nil
        }
    }
    
    // MARK: - Digit Animation View
    
    struct DigitView: View {
        let currentDigit: String
        let previousDigit: String
        let isChanging: Bool
        let direction: Direction
        
        enum Direction {
            case up, down
            
            var offset: CGFloat {
                switch self {
                case .up: return -15
                case .down: return 15
                }
            }
            
            var incomingOffset: CGFloat {
                switch self {
                case .up: return 15
                case .down: return -15
                }
            }
        }
        
        var body: some View {
            ZStack {
                // Previous digit fading out
                if isChanging {
                    // Just a few ghost copies
                    ForEach(0..<3) { i in
                        Text(previousDigit)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .opacity(0.6 - Double(i) * 0.2) // Quick fade
                            .scaleEffect(y: 1.0 + Double(i) * 0.05) // Very subtle stretch
                            .offset(y: direction.offset * 0.5 + (CGFloat(i) * 1.5)) // Minimal spacing
                    }
                }
                
                // Current digit - stable
                Text(currentDigit)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .opacity(isChanging ? 0.95 : 1.0) // Almost no fade
                    .offset(y: isChanging ? direction.incomingOffset * 0.1 : 0) // Tiny offset
                
                // Numbers scrolling in - minimal movement
                if isChanging {
                    let numbers = direction == .up ? 
                        ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] :
                        ["9", "8", "7", "6", "5", "4", "3", "2", "1", "0"]
                    
                    ForEach(0..<4) { i in
                        Text(numbers[i % numbers.count])
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .opacity(0.5 - Double(i) * 0.12) // Quick fade out
                            .scaleEffect(y: 1.0 + Double(i) * 0.06) // Minimal stretch
                            .offset(y: direction.incomingOffset * 0.5 + (CGFloat(i) * 2)) // Small offset
                    }
                }
            }
            .animation(.easeOut(duration: 0.15), value: currentDigit) // Quick animation
        }
    }
    
    // MARK: - Subviews
    
    private var timePillsOverlay: some View {
        GeometryReader { geometry in
            // Top left pill - start time (aligned with hour line)
            if let startTime = event.startTime {
                timePill(time: startTime, isStart: true)
                    .position(
                        x: -timeColumnWidth / 2, // Center of time column (58/2 = 29px)
                        y: 0 // Moved slightly higher
                    )
            }
            
            // Bottom left pill - end time (aligned with hour line)
            if let endTime = event.endTime {
                timePill(time: endTime, isStart: false)
                    .position(
                        x: -timeColumnWidth / 2, // Center of time column (58/2 = 29px)
                        y: geometry.size.height // Exactly at bottom to align with next hour
                    )
            }
        }
        .frame(height: blockHeight) // Match the block height
        .allowsHitTesting(false) // Don't interfere with gestures
    }
    
    @ViewBuilder
    private func timePill(time: Date?, isStart: Bool) -> some View {
        if let time = time {
            let adjustedTime = isDragging ? adjustTimeForDrag(time) : time
            let timeString = formatTime(adjustedTime)
            let previousString = isStart ? previousStartTime : previousEndTime
            
            HStack(spacing: 0) {
                // Each character gets its own view for individual animation
                ForEach(Array(timeString.enumerated()), id: \.offset) { index, char in
                    if char == ":" {
                        Text(":")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    } else {
                        // Get previous character at this position
                        let prevChar: Character? = previousString.count > index ? 
                            Array(previousString)[index] : nil
                        let isChanging = prevChar != nil && prevChar != char && isDragging
                        
                        DigitView(
                            currentDigit: String(char),
                            previousDigit: prevChar != nil ? String(prevChar!) : String(char),
                            isChanging: isChanging,
                            direction: dragOffset > 0 ? .down : .up
                        )
                    }
                }
            }
            .padding(.horizontal, baseUnit) // 8pt - smaller padding
            .padding(.vertical, baseUnit * 0.75) // 6pt - smaller vertical padding
            .background(
                Capsule()
                    .fill(categoryColor)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: -1, y: isStart ? -0.5 : 0.5)
            )
            .overlay(
                // Subtle directional indicator
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.3),
                                .white.opacity(0.1)
                            ],
                            startPoint: isStart ? .top : .bottom,
                            endPoint: isStart ? .bottom : .top
                        ),
                        lineWidth: 1
                    )
            )
            .onChange(of: timeString) { oldValue, newValue in
                if isStart {
                    previousStartTime = newValue
                } else {
                    previousEndTime = newValue
                }
            }
            .onAppear {
                if isStart {
                    previousStartTime = timeString
                } else {
                    previousEndTime = timeString
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
                        categoryColor.opacity(0.9)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 3) // 3pt for visual weight at any scale
            .opacity(isPressed ? 0.8 : 1.0)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            if priority == .critical {
                // Chromatic aberration for critical
                ZStack {
                    Text(event.title ?? "Untitled")
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundColor(Color(red: 1, green: 0, blue: 0))
                        .opacity(0.8)
                        .offset(x: 0.5)
                    
                    Text(event.title ?? "Untitled")
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundColor(Color(red: 0, green: 1, blue: 1))
                        .opacity(0.8)
                        .offset(x: -0.5)
                    
                    Text(event.title ?? "Untitled")
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundColor(priority.textColor(for: colorScheme))
                }
                .tracking(-0.4) // SF Pro optimal tracking
            } else {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 15, weight: titleWeight, design: .default))
                    .foregroundColor(priority.textColor(for: colorScheme))
                    .tracking(-0.4)
            }
            
        }
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: baseUnit * 0.5) { // 4pt
            if let startTime = event.startTime,
               let endTime = event.endTime {
                // Time with monospace precision and duration
                HStack(spacing: baseUnit) { // 8pt spacing for breathing room
                    // Time range text with exact-width gray bar
                    Text(formatTimeRange(start: startTime, end: endTime))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(priority.secondaryTextColor(for: colorScheme))
                        .tracking(0.2)
                        .opacity(showTimePills ? 0 : 1) // Hide only time range when showing pills
                        .background(
                            // Gray bar overlay when dragging - matches text width exactly
                            showTimePills ?
                            Capsule()
                                .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.7))
                                .frame(height: 14) // Thinner bar
                                .transition(.scale.combined(with: .opacity))
                            : nil
                        )
                    
                    // Duration with bullet separator - always visible
                    HStack(spacing: timeGridUnit) { // 4pt
                        Text("•")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(priority.secondaryTextColor(for: colorScheme).opacity(0.5))
                        
                        Text(formatDuration(start: startTime, end: endTime))
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(priority.secondaryTextColor(for: colorScheme).opacity(0.7))
                            .tracking(0.1)
                    }
                }
                
                // Location with SF Symbols
                if shouldShowLocation,
                   let location = event.location, !location.isEmpty {
                    HStack(spacing: baseUnit * 0.5) { // 4pt
                        Image(systemName: "location.fill")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(priority.secondaryTextColor(for: colorScheme).opacity(0.7))
                        
                        Text(location)
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(priority.secondaryTextColor(for: colorScheme))
                            .tracking(-0.2)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
    
    // MARK: - Visual Effects
    
    private var backgroundLayer: some View {
        ZStack {
            // Base color - use lighter version of category color
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    colorScheme == .dark 
                        ? categoryColor.mix(with: .black, by: 0.85) // 85% black mixed in for dark mode
                        : categoryColor.mix(with: .white, by: 0.9)  // 90% white mixed in for light mode
                )
            
            
            // Noise texture
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    noisePattern
                        .opacity(colorScheme == .dark ? 0.03 : 0.015) // Adaptive noise
                )
        }
    }
    
    private var overlayEffects: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2),
                        Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }
    
    // Simulated noise texture using gradients
    private var noisePattern: some ShapeStyle {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.1), location: 0),
                .init(color: .clear, location: 0.3),
                .init(color: .black.opacity(0.05), location: 0.5),
                .init(color: .clear, location: 0.7),
                .init(color: .black.opacity(0.1), location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Computed Properties
    
    private var cornerRadius: CGFloat {
        // Radius based on φ ratios
        let baseRadius: CGFloat = 13 // iOS standard
        switch priority {
        case .critical: return round(baseRadius / φ) // 8pt
        case .elevated: return round(baseRadius / φ + 1) // 9pt
        case .focus: return round(baseRadius / φ + 2) // 10pt
        case .standard: return baseRadius // 13pt - softest
        }
    }
    
    private var titleWeight: Font.Weight {
        switch priority {
        case .critical: return .semibold
        case .elevated: return .medium
        case .focus: return .medium
        case .standard: return .regular
        }
    }
    
    private var shouldShowTimeInfo: Bool {
        // Show time if height >= φ² × baseUnit × 2 = 41.89 ≈ 44pt
        blockHeight >= 44
    }
    
    private var shouldShowLocation: Bool {
        // Show location if height >= φ³ × baseUnit = 68pt
        blockHeight >= hourHeight
    }
    
    private var shadowColor: Color {
        Color.black.opacity(priority.shadowIntensity(for: colorScheme))
    }
    
    private var shadowRadius: CGFloat {
        isPressed ? 2 : (isHovered ? 8 : 4)
    }
    
    private var shadowY: CGFloat {
        isPressed ? 1 : (isHovered ? 3 : 2)
    }
    
    private var scaleFactor: CGFloat {
        // Scale factors based on φ ratios
        if isPressed {
            return 1 + (1/φ)/30 // 1.021 - subtle expansion
        } else if isHovered {
            return 1 + (1/φ)/40 // 1.015 - gentle lift
        }
        return 1.0
    }
    
    private var opacityValue: Double {
        isPressed ? 0.95 : 1.0
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
        let intervals = dragOffset / pixelsPer5Minutes
        let snappedIntervals = round(intervals)
        let offsetMinutes = Int(snappedIntervals * 5)
        
        let newTime = Calendar.current.date(byAdding: .minute, value: offsetMinutes, to: time) ?? time
        
        // Debug output
        if abs(dragOffset) > 0 {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            print("🌟 DEBUG: Drag time adjustment")
            print("   Original: \(formatter.string(from: time))")
            print("   Offset minutes: \(offsetMinutes)")
            print("   New time: \(formatter.string(from: newTime))")
        }
        
        return newTime
    }
    
    private func applyTimeChange() {
        guard let startTime = event.startTime,
              let endTime = event.endTime else { return }
        
        // Calculate offset in 5-minute intervals
        let pixelsPerMinute = hourHeight / 60.0
        let pixelsPer5Minutes = pixelsPerMinute * 5.0
        let intervals = dragOffset / pixelsPer5Minutes
        let snappedIntervals = round(intervals)
        let offsetMinutes = Int(snappedIntervals * 5)
        
        guard let newStartTime = Calendar.current.date(byAdding: .minute, value: offsetMinutes, to: startTime),
              let newEndTime = Calendar.current.date(byAdding: .minute, value: offsetMinutes, to: endTime) else { return }
        
        // Prevent dragging across day boundaries
        let calendar = Calendar.current
        let originalDay = calendar.startOfDay(for: startTime)
        let newDay = calendar.startOfDay(for: newStartTime)
        
        if originalDay != newDay {
            print("⚠️ Preventing drag across day boundary")
            // Haptic feedback for boundary hit
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
            return
        }
        
        // Debug: Log the time change details
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        print("🔄 DEBUG: Applying time change")
        print("   Event: \(event.title ?? "Untitled")")
        print("   Drag offset: \(dragOffset) pixels")
        print("   Offset minutes: \(offsetMinutes)")
        print("   Old time: \(formatter.string(from: startTime)) - \(formatter.string(from: endTime))")
        print("   New time: \(formatter.string(from: newStartTime)) - \(formatter.string(from: newEndTime))")
        
        // Check if we're crossing day boundaries
        if !calendar.isDate(startTime, inSameDayAs: newStartTime) {
            print("   ⚠️ WARNING: Event is moving to a different day!")
            print("   From day: \(calendar.startOfDay(for: startTime))")
            print("   To day: \(calendar.startOfDay(for: newStartTime))")
        }
        
        // Update the event using ScheduleManager
        let result = scheduleManager.updateEvent(
            event,
            startTime: newStartTime,
            endTime: newEndTime
        )
        
        // Success haptic
        if case .success = result {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
            print("✅ Event update successful, forcing refresh...")
            
            // Force multiple refreshes to ensure UI updates
            scheduleManager.objectWillChange.send()
            scheduleManager.forceRefresh()
            
            // Try again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scheduleManager.forceRefresh()
            }
            
            // And once more to be sure
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                scheduleManager.forceRefresh()
            }
        } else {
            print("❌ Event update failed!")
        }
    }
    
    // MARK: - Core Haptics
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            createContinuousHapticPattern()
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    private func createContinuousHapticPattern() {
        // Create a subtle continuous haptic pattern
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
        
        let continuous = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensity, sharpness],
            relativeTime: 0,
            duration: 100 // Long duration, we'll stop it manually
        )
        
        do {
            let pattern = try CHHapticPattern(events: [continuous], parameters: [])
            continuousPlayer = try hapticEngine?.makePlayer(with: pattern)
        } catch {
            print("Failed to create haptic pattern: \(error)")
        }
    }
    
    private func startContinuousHaptic() {
        do {
            try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to start continuous haptic: \(error)")
        }
    }
    
    private func updateHapticIntensity(for dragSpeed: CGFloat) {
        // Vary intensity based on drag speed (0.2 to 0.3)
        let normalizedSpeed = min(abs(dragSpeed) / 100, 1.0) // Normalize to 0-1
        let intensity = 0.2 + (normalizedSpeed * 0.1) // 0.2 to 0.3 range
        
        let intensityParam = CHHapticDynamicParameter(
            parameterID: .hapticIntensityControl,
            value: Float(intensity),
            relativeTime: 0
        )
        
        do {
            try continuousPlayer?.sendParameters([intensityParam], atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to update haptic intensity: \(error)")
        }
    }
    
    private func stopContinuousHaptic() {
        do {
            try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to stop continuous haptic: \(error)")
        }
    }
    
    private func stopHaptics() {
        hapticEngine?.stop(completionHandler: { _ in })
    }
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
#Preview("TimeBlock Variations") {
    VStack(spacing: 16) {
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

@MainActor
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
    
    @State var isDragging = false
    
    return TimeBlockView(
        event: event,
        onTap: { print("Tapped: \(title)") },
        isDraggingAnyBlock: .constant(false)
    )
    .frame(width: 300)
    .environmentObject(ScheduleManager.shared)
}