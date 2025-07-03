import SwiftUI

struct DayTimelineView: View {
    let selectedDate: Date
    var showCurrentTime: Bool = true
    
    // Mathematical constants
    private let φ: CGFloat = 1.618033988749895 // Golden ratio
    private let hourHeight: CGFloat = 68 // φ³ - Golden ratio cubed
    private let timeColumnWidth: CGFloat = 58 // φ² + base unit for perfect proportion
    private let baseUnit: CGFloat = 8
    private let timeGridUnit: CGFloat = 4
    
    @Environment(\.colorScheme) var colorScheme
    @State private var currentTime = Date()
    
    // Ensure we're using the device's current calendar and timezone
    private var deviceCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }
    @State private var timelineOpacity: Double = 1
    @State private var gridOpacity: Double = 1
    
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }
    
    // Generate hours from 12am to 11pm (0-23)
    private var hours: [Int] {
        Array(0...23)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Layer 1: Sophisticated background
            backgroundLayer
            
            // Layer 2: Mathematical grid
            gridLayer
                .opacity(gridOpacity)
            
            // Layer 3: Time labels
            timeLabelsLayer
                .opacity(timelineOpacity)
            
            // Layer 4: Current time indicator
            // Only show if we're viewing today's actual date and showCurrentTime is true
            if showCurrentTime && deviceCalendar.isDateInToday(selectedDate) {
                currentTimeIndicator
            }
            
        }
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(hours.count) * hourHeight)
        .onAppear {
            // Removed fade-in animation
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    // MARK: - Background Layer
    private var backgroundLayer: some View {
        Rectangle()
            .fill(colorScheme == .dark ? Color.black : Color.white)
    }
    
    // MARK: - Grid Layer
    private var gridLayer: some View {
        Canvas { context, size in
            // Vertical separator line
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: timeColumnWidth, y: 0))
                    path.addLine(to: CGPoint(x: timeColumnWidth, y: size.height))
                },
                with: .color(hourLineColor),
                lineWidth: 0.5
            )
            
            // Hour lines only - clean and minimal
            for (index, _) in hours.enumerated() {
                let y = CGFloat(index) * hourHeight
                
                // Main hour line
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: timeColumnWidth, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(hourLineColor),
                    lineWidth: 0.5
                )
                
                
            }
        }
    }
    
    // MARK: - Time Labels Layer
    private var timeLabelsLayer: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(hours.enumerated()), id: \.offset) { index, hour in
                HStack(spacing: 0) {
                    timeLabel(for: hour, index: index)
                        .frame(width: timeColumnWidth)
                    
                    Spacer()
                }
                .offset(y: CGFloat(index) * hourHeight - 6) // Center on grid line (half font height)
                .id("hour_\(hour)")
            }
        }
    }
    
    // MARK: - Time Label
    private func timeLabel(for hour: Int, index: Int) -> some View {
        // Create time string directly from hour value
        let isPM = hour >= 12
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let timeString = "\(displayHour) \(isPM ? "PM" : "AM")"
        
        return Text(timeString)
            .font(.system(size: 12, weight: .regular, design: .default))
            .foregroundColor(colorScheme == .dark ? Color(white: 0.6) : Color(white: 0.5))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, baseUnit)
    }
    
    // MARK: - Current Time Indicator
    private var currentTimeIndicator: some View {
        let position = calculateTimePosition(for: currentTime)
        
        return VStack(spacing: 0) {
            // Spacer to push indicator to correct position
            Color.clear
                .frame(height: position)
            
            // Indicator at exact position
            ZStack(alignment: .top) {
                // Glow effect
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: timeColumnWidth)
                    
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0),
                            Color.red.opacity(0.3),
                            Color.red.opacity(0.3),
                            Color.red.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: baseUnit * 2)
                    .blur(radius: baseUnit)
                }
                .offset(y: -baseUnit)
                
                // Main indicator line
                HStack(spacing: 0) {
                    // Time badge
                    ZStack {
                        RoundedRectangle(cornerRadius: baseUnit / 2, style: .continuous)
                            .fill(Color.red)
                            .frame(width: timeColumnWidth - baseUnit, height: baseUnit * 3)
                        
                        Text(formatCurrentTime())
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, baseUnit / 2)
                    
                    // Animated line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.red,
                                    Color.red.opacity(0.8),
                                    Color.red.opacity(0.6)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                        .overlay(
                            GeometryReader { geometry in
                                // Pulse effect
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: baseUnit * 4, height: 2)
                                    .opacity(0.8)
                                    .offset(x: geometry.size.width * pulseOffset)
                                    .animation(
                                        .linear(duration: 3)
                                        .repeatForever(autoreverses: false),
                                        value: pulseOffset
                                    )
                                    .onAppear {
                                        pulseOffset = 1.2
                                    }
                            }
                        )
                        .mask(
                            LinearGradient(
                                colors: [
                                    Color.black,
                                    Color.black.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .offset(y: -1)
            }
            .frame(height: baseUnit * 3)
            
            Spacer(minLength: 0)
        }
    }
    
    
    // MARK: - Helper Functions
    
    private func calculateTimePosition(for date: Date) -> CGFloat {
        // Use deviceCalendar to ensure consistency
        let components = deviceCalendar.dateComponents([.hour, .minute], from: date)
        let hour = CGFloat(components.hour ?? 0)
        let minute = CGFloat(components.minute ?? 0)
        
        // Debug one more time
        if deviceCalendar.isDateInToday(date) {
            print("🔴 Final debug - Hour: \(Int(hour)), Position: \((hour * hourHeight) + (minute * (hourHeight / 60)))")
            
            // Check if this matches what we see visually
            // 9 AM should be at position 612 (9 * 68)
            // 9 PM should be at position 1428 (21 * 68)
            if Int(hour) == 9 {
                print("   This should appear at the 9 AM position (around pixel 612)")
                print("   If it appears at 9 PM position (around pixel 1428), something is adding 816 pixels")
            }
        }
        
        return (hour * hourHeight) + (minute * (hourHeight / 60))
    }
    
    
    private func formatCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
    
    
    // MARK: - Colors
    
    private var hourLineColor: Color {
        colorScheme == .dark
            ? Color(white: 0.2)
            : Color(white: 0.9)
    }
    
    @State private var pulseOffset: CGFloat = -0.2
}

// MARK: - Preview
#Preview {
    DayTimelineView(selectedDate: Date())
        .preferredColorScheme(.dark)
}