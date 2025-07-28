//
//  EnhancedDayComponents.swift
//  Momentum
//
//  Enhanced components for improved visual hierarchy in day/timeline views
//

import SwiftUI

// MARK: - Enhanced Time Label
struct EnhancedTimeLabel: View {
    let hour: Int
    let isCurrentHour: Bool
    let width: CGFloat
    
    private var timeString: String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = hour == 0 || hour == 12 ? "h a" : "h"
        return formatter.string(from: date).lowercased()
    }
    
    var body: some View {
        Text(timeString)
            .font(isCurrentHour ? DesignSystem.Typography.footnote : DesignSystem.Typography.caption1)
            .fontWeight(isCurrentHour ? .semibold : .regular)
            .foregroundColor(isCurrentHour ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiary)
            .frame(width: width, alignment: .trailing)
            .padding(.trailing, DesignSystem.Spacing.xs)
            .animation(.easeInOut(duration: 0.2), value: isCurrentHour)
    }
}

// MARK: - Enhanced Event Block
struct EnhancedEventBlock: View {
    let event: Event
    let geometry: GeometryProxy
    let hourHeight: CGFloat
    let timeColumnWidth: CGFloat
    let onTap: () -> Void
    let onDrag: (DragGesture.Value) -> Void
    let onDragEnd: (DragGesture.Value) -> Void
    
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var eventColor: Color {
        if let categoryHex = event.category?.colorHex {
            return Color(hex: categoryHex)
        }
        return DesignSystem.Colors.accent
    }
    
    private var textColor: Color {
        // Ensure good contrast for readability
        let brightness = eventColor.brightness
        return brightness > 0.6 ? Color.black : Color.white
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background with gradient
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(
                    LinearGradient(
                        colors: [
                            eventColor,
                            eventColor.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(eventColor.opacity(0.3), lineWidth: 1)
                )
                .shadow(
                    color: eventColor.opacity(0.3),
                    radius: isPressed ? 2 : 4,
                    x: 0,
                    y: isPressed ? 1 : 2
                )
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                // Title with proper sizing
                Text(event.title ?? "Untitled")
                    .font(eventHeight > 40 ? DesignSystem.Typography.subheadline : DesignSystem.Typography.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)
                    .lineLimit(eventHeight > 60 ? 2 : 1)
                
                // Time and location if space allows
                if eventHeight > 50 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(formatTimeRange())
                            .font(DesignSystem.Typography.caption2)
                    }
                    .foregroundColor(textColor.opacity(0.8))
                    
                    if let location = event.location, !location.isEmpty, eventHeight > 70 {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.system(size: 10))
                            Text(location)
                                .font(DesignSystem.Typography.caption2)
                                .lineLimit(1)
                        }
                        .foregroundColor(textColor.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .frame(height: max(20, eventHeight))
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture(perform: onTap)
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if !isPressed { isPressed = true }
                    onDrag(value)
                }
                .onEnded { value in
                    isPressed = false
                    onDragEnd(value)
                }
        )
    }
    
    private var eventHeight: CGFloat {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: event.startTime ?? Date())
        let startMinute = calendar.component(.minute, from: event.startTime ?? Date())
        let endHour = calendar.component(.hour, from: event.endTime ?? Date())
        let endMinute = calendar.component(.minute, from: event.endTime ?? Date())
        
        let startOffset = CGFloat(startHour) * hourHeight + (CGFloat(startMinute) / 60.0) * hourHeight
        let endOffset = CGFloat(endHour) * hourHeight + (CGFloat(endMinute) / 60.0) * hourHeight
        
        return max(20, endOffset - startOffset)
    }
    
    private func formatTimeRange() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        guard let start = event.startTime,
              let end = event.endTime else { return "" }
        
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - Enhanced Day Header
struct EnhancedDayHeader: View {
    let date: Date
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void
    let onToday: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Date navigation
            HStack(spacing: DesignSystem.Spacing.xs) {
                Button(action: onPreviousDay) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: DesignSystem.IconSize.md, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.tertiaryFill)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(spacing: 2) {
                    Text(dateFormatter.string(from: date))
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primary)
                    
                    if isToday {
                        Text("Today")
                            .font(DesignSystem.Typography.caption1)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                }
                .frame(minWidth: 200)
                
                Button(action: onNextDay) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: DesignSystem.IconSize.md, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.tertiaryFill)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            // Today button
            if !isToday {
                Button(action: onToday) {
                    Text("Today")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.accent.opacity(0.15))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            Rectangle()
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.8))
                .ignoresSafeArea(edges: .horizontal)
        )
    }
}

// MARK: - All Day Events Section
struct AllDayEventsSection: View {
    let events: [Event]
    let onEventTap: (Event) -> Void
    
    var body: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("All Day")
                    .font(DesignSystem.Typography.caption1)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(events) { event in
                            AllDayEventPill(event: event)
                                .onTapGesture {
                                    onEventTap(event)
                                }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                Rectangle()
                    .fill(DesignSystem.Colors.tertiaryBackground)
                    .ignoresSafeArea(edges: .horizontal)
            )
        }
    }
}

// MARK: - All Day Event Pill
struct AllDayEventPill: View {
    let event: Event
    
    private var eventColor: Color {
        if let categoryHex = event.category?.colorHex {
            return Color(hex: categoryHex)
        }
        return DesignSystem.Colors.accent
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(eventColor)
                .frame(width: 8, height: 8)
            
            Text(event.title ?? "Untitled")
                .font(DesignSystem.Typography.footnote)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.primary)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(eventColor.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(eventColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Hour Grid Line
struct HourGridLine: View {
    let isCurrentHour: Bool
    
    var body: some View {
        Rectangle()
            .fill(isCurrentHour ? DesignSystem.Colors.accent.opacity(0.3) : DesignSystem.Colors.separator)
            .frame(height: isCurrentHour ? 2 : 1)
            .animation(.easeInOut(duration: 0.2), value: isCurrentHour)
    }
}

// MARK: - Color Extensions
extension Color {
    var brightness: Double {
        guard let components = UIColor(self).cgColor.components else { return 0.5 }
        let red = components[0]
        let green = components.count > 1 ? components[1] : components[0]
        let blue = components.count > 2 ? components[2] : components[0]
        
        // Calculate perceived brightness using relative luminance formula
        return (0.299 * red + 0.587 * green + 0.114 * blue)
    }
}