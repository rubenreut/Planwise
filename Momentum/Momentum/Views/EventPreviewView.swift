//
//  EventPreviewView.swift
//  Momentum
//
//  Rich event preview component for chat messages
//

import SwiftUI

struct EventPreviewView: View {
    let event: EventPreview
    let isAccepted: Bool
    let isDeleted: Bool
    let onAction: (EventAction) -> Void
    var inMessageBubble: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var pressedAction: EventAction? = nil
    @State private var showingActions = true
    @State private var buttonScale: [EventAction: CGFloat] = [:]
    
    private let φ: Double = 1.618033988749895
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            VStack(alignment: .leading, spacing: 12 / φ) {
                // Header with category color bar
                HStack(spacing: 12) {
                    // Category color indicator
                    RoundedRectangle(cornerRadius: 4)
                        .fill(categoryGradient)
                        .frame(width: 4, height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.icon)
                                .font(.system(size: 24))
                            
                            Text(event.title)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            if event.isMultiDay {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("\(event.dayCount) days")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(categoryGradient)
                                )
                            }
                        }
                        
                        // Time and Location with better icons
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(categoryGradient)
                                
                                Text(event.timeDescription)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary.opacity(0.8))
                            }
                            
                            if let location = event.location {
                                HStack(spacing: 6) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(categoryGradient)
                                    
                                    Text(location)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary.opacity(0.8))
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Multi-day breakdown with better styling
                if event.isMultiDay, let breakdown = event.dayBreakdown {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(breakdown.prefix(3), id: \.day) { item in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(categoryGradient)
                                        .frame(width: 8, height: 8)
                                    
                                    Text("Day \(item.day)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .frame(width: 50, alignment: .leading)
                                    
                                    Text(item.description)
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                }
                            }
                            
                            if breakdown.count > 3 {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                    
                                    Text("+ \(breakdown.count - 3) more days")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            
            // Action buttons with animation
            if showingActions {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.top, 12)
                    
                    HStack(spacing: 0) {
                        ForEach(event.actions, id: \.self) { action in
                            Button(action: {
                                // Disable if already accepted/deleted
                                if action == .complete && isAccepted { return }
                                if action == .delete && isDeleted { return }
                                
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                
                                // Animate button press
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    pressedAction = action
                                    buttonScale[action] = 0.92
                                }
                                
                                // Reset after a short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        buttonScale[action] = 1.0
                                    }
                                }
                                
                                // Perform action after animation starts
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    // Add haptic feedback based on action type
                                    switch action {
                                    case .complete:
                                        HapticFeedback.success.trigger()
                                    case .delete:
                                        HapticFeedback.warning.trigger()
                                    default:
                                        HapticFeedback.light.trigger()
                                    }
                                    
                                    onAction(action)
                                    
                                    // Keep pressed state a bit longer for visual feedback
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            pressedAction = nil
                                        }
                                    }
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    
                                    Image(systemName: 
                                        action == .complete && isAccepted ? "checkmark.circle.fill" :
                                        action == .delete && isDeleted ? "trash.circle.fill" :
                                        action.icon
                                    )
                                    .font(.system(size: 14, weight: .medium))
                                    
                                    Text(
                                        action == .complete && isAccepted ? "Accepted" :
                                        action == .delete && isDeleted ? "Deleted" :
                                        action.label
                                    )
                                    .font(.system(size: 14, weight: .semibold))
                                    
                                    Spacer()
                                }
                                .foregroundColor(
                                    action == .complete && isAccepted ? .green :
                                    action == .delete && isDeleted ? .red.opacity(0.6) :
                                    action.isDestructive ? .red : .accentColor
                                )
                                .padding(.vertical, 14)
                                .background(
                                    Rectangle()
                                        .fill(
                                            action == .complete && isAccepted ? Color.green.opacity(0.1) :
                                            action == .delete && isDeleted ? Color.red.opacity(0.1) :
                                            pressedAction == action ? Color.accentColor.opacity(0.15) : Color.clear
                                        )
                                )
                                .scaleEffect(buttonScale[action] ?? 1.0)
                                .opacity((action == .complete && isAccepted) || (action == .delete && isDeleted) ? 0.7 : 1.0)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled((action == .complete && isAccepted) || (action == .delete && isDeleted))
                            
                            if action != event.actions.last {
                                Divider()
                                    .frame(height: 20)
                            }
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
        .if(!inMessageBubble) { view in
            view
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.adaptiveBorder.opacity(0.5), lineWidth: 1)
                )
                .shadow(
                    color: shadowColor,
                    radius: 8,
                    x: 0,
                    y: 4
                )
        }
        .if(inMessageBubble) { view in
            view
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.tertiarySystemBackground))
                )
        }
        .scaleEffect(pressedAction != nil ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressedAction)
        .onAppear {
            // Initialize button scales
            for action in event.actions {
                buttonScale[action] = 1.0
            }
        }
    }
    
    private var categoryGradient: LinearGradient {
        LinearGradient(
            colors: getCategoryColors(event.category ?? ""),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var categoryColor: Color {
        getCategoryColors(event.category ?? "").first ?? Color.accentColor
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient.adaptiveGradient(
            from: Color.adaptiveCardBackground,
            to: Color.adaptiveSecondaryBackground,
            darkFrom: Color(white: 0.15),
            darkTo: Color(white: 0.12)
        )
    }
    
    private var shadowColor: Color {
        Color.adaptiveShadow
    }
    
    private func getCategoryColors(_ category: String) -> [Color] {
        switch category.lowercased() {
        case "work":
            return [Color(hex: "5856D6"), Color(hex: "7C7AEA")]
        case "personal":
            return [Color(hex: "FF6B6B"), Color(hex: "FF8787")]
        case "health":
            return [Color(hex: "4ECDC4"), Color(hex: "6EE7DF")]
        case "learning":
            return [Color(hex: "FFD93D"), Color(hex: "FFE066")]
        default:
            return [Color.accentColor, Color.accentColor.opacity(0.8)]
        }
    }
}

// MARK: - Supporting Types

struct EventPreview: Equatable {
    let id: String
    let icon: String
    let title: String
    let timeDescription: String
    let location: String?
    let category: String?
    let isMultiDay: Bool
    let dayCount: Int
    let dayBreakdown: [DayBreakdown]?
    let actions: [EventAction]
    
    struct DayBreakdown: Equatable {
        let day: Int
        let description: String
    }
}

enum EventAction: Hashable {
    case edit
    case delete
    case complete
    case markAllComplete
    case viewFull
    case share
    
    var label: String {
        switch self {
        case .edit: return "Edit"
        case .delete: return "Delete"
        case .complete: return "Accept"
        case .markAllComplete: return "Mark All Complete"
        case .viewFull: return "View Full"
        case .share: return "Share"
        }
    }
    
    var icon: String {
        switch self {
        case .edit: return "pencil"
        case .delete: return "trash"
        case .complete: return "checkmark.circle"
        case .markAllComplete: return "checkmark.circle.fill"
        case .viewFull: return "arrow.up.forward.square"
        case .share: return "square.and.arrow.up"
        }
    }
    
    var isDestructive: Bool {
        self == .delete
    }
}

// MARK: - Bulk Action Preview

struct BulkActionPreview: Equatable {
    let id: String
    let action: String // "delete", "update", "complete"
    let icon: String
    let title: String
    let description: String
    let affectedCount: Int
    let dateRange: String?
    let warningLevel: WarningLevel
    let actions: [BulkAction]
    
    enum WarningLevel {
        case normal
        case caution
        case critical
    }
    
    enum BulkAction: String {
        case confirm = "confirm"
        case cancel = "cancel"
        case undo = "undo"
    }
}

struct BulkActionPreviewView: View {
    let preview: BulkActionPreview
    let isCompleted: Bool
    let onAction: (BulkActionPreview.BulkAction) -> Void
    var inMessageBubble: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var pressedAction: BulkActionPreview.BulkAction? = nil
    
    private let φ: Double = 1.618033988749895
    
    private var warningGradient: LinearGradient {
        switch preview.warningLevel {
        case .normal:
            return LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .caution:
            return LinearGradient(
                colors: [Color.orange, Color.orange.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .critical:
            return LinearGradient(
                colors: [Color.red, Color.red.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var categoryColor: Color {
        switch preview.warningLevel {
        case .normal:
            return Color.blue
        case .caution:
            return Color.orange
        case .critical:
            return Color.red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            VStack(alignment: .leading, spacing: 12 / φ) {
                // Header with warning indicator
                HStack(spacing: 12) {
                    // Warning level indicator
                    RoundedRectangle(cornerRadius: 4)
                        .fill(warningGradient)
                        .frame(width: 4, height: 50)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(preview.icon)
                                .font(.system(size: 28))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preview.title)
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text(preview.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            // Affected count text
                            Text("\(preview.affectedCount) events")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Date range if provided
                        if let dateRange = preview.dateRange {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(warningGradient)
                                
                                Text(dateRange)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary.opacity(0.8))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Warning message for critical actions
                if preview.warningLevel == .critical {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                        
                        Text("This action cannot be undone")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            
            // Action button
            VStack(spacing: 0) {
                Divider()
                
                Button(action: {
                    if !isCompleted {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            pressedAction = .confirm
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onAction(.confirm)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                pressedAction = nil
                            }
                        }
                    }
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 14, weight: .medium))
                        Text(isCompleted ? "Done" : "Confirm")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(isCompleted ? .green : .red)
                    .padding(.vertical, 14)
                    .background(
                        Rectangle()
                            .fill(
                                isCompleted ? Color.green.opacity(0.1) :
                                pressedAction == .confirm ? Color.primary.opacity(0.05) : Color.clear
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isCompleted)
            }
        }
        .if(!inMessageBubble) { view in
            view
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.adaptiveBorder.opacity(0.5), lineWidth: 1)
                )
                .shadow(
                    color: shadowColor,
                    radius: 8,
                    x: 0,
                    y: 4
                )
        }
        .if(inMessageBubble) { view in
            view
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.tertiarySystemBackground))
                )
        }
        .scaleEffect(pressedAction != nil ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressedAction)
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient.adaptiveGradient(
            from: Color.adaptiveCardBackground,
            to: Color.adaptiveSecondaryBackground,
            darkFrom: Color(white: 0.15),
            darkTo: Color(white: 0.12)
        )
    }
    
    private var shadowColor: Color {
        Color.adaptiveShadow
    }
    
}

// MARK: - Multiple Events Preview

struct MultipleEventsPreviewView: View {
    let events: [EventListItem]
    let isAccepted: Bool
    let onAction: (MultiEventAction) -> Void
    var inMessageBubble: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var animatedEvents: Set<String> = []
    
    private let φ: Double = 1.618033988749895
    
    // Group events by date
    private var groupedEvents: [(date: Date, events: [EventListItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event -> Date in
            if let date = event.date {
                return calendar.startOfDay(for: date)
            }
            return calendar.startOfDay(for: Date())
        }
        
        return grouped
            .sorted { $0.key < $1.key }
            .map { (date: $0.key, events: $0.value.sorted { ($0.time < $1.time) }) }
    }
    
    private var categoryColor: Color {
        // For multiple events, use accent color as default
        Color.accentColor
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            // Check if it's within this week
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()),
               date >= weekInterval.start && date < weekInterval.end {
                formatter.dateFormat = "EEEE" // Day name
            } else {
                formatter.dateFormat = "EEEE, MMM d" // Full format
            }
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Created \(events.count) events")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(16)
            
            Divider()
            
            // Events list grouped by date
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(groupedEvents.enumerated()), id: \.offset) { groupIndex, group in
                        // Date header
                        HStack {
                            Text(formatDate(group.date))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(group.events.count) events")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.08))
                        
                        // Events for this date
                        ForEach(Array(group.events.enumerated()), id: \.element.id) { index, event in
                            HStack(spacing: 12) {
                                // Time text
                                Text(event.time)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 65, alignment: .leading)
                                
                                // Event title
                                Text(event.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                event.isCompleted ? Color.green.opacity(0.05) : Color.clear
                            )
                            
                            if index < group.events.count - 1 {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                        
                        // Add spacing between date groups
                        if groupIndex < groupedEvents.count - 1 {
                            Divider()
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            
            // Action buttons
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 0) {
                    Button(action: { 
                        if !isAccepted {
                            onAction(.markAllComplete)
                        }
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: isAccepted ? "checkmark.circle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text(isAccepted ? "Accepted" : "Accept All")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(isAccepted ? .green : .accentColor)
                        .padding(.vertical, 14)
                        .background(
                            Rectangle()
                                .fill(isAccepted ? Color.green.opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isAccepted)
                    
                }
            }
        }
        .if(!inMessageBubble) { view in
            view
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.adaptiveBorder.opacity(0.5), lineWidth: 1)
                )
                .shadow(
                    color: shadowColor,
                    radius: 8,
                    x: 0,
                    y: 4
                )
        }
        .if(inMessageBubble) { view in
            view
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.tertiarySystemBackground))
                )
        }
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient.adaptiveGradient(
            from: Color.adaptiveCardBackground,
            to: Color.adaptiveSecondaryBackground,
            darkFrom: Color(white: 0.15),
            darkTo: Color(white: 0.12)
        )
    }
    
    private var shadowColor: Color {
        Color.adaptiveShadow
    }
    
}

struct EventListItem: Identifiable, Equatable {
    let id: String
    let time: String
    let title: String
    let isCompleted: Bool
    let date: Date? // Added to support grouping by date
}

enum MultiEventAction {
    case toggleComplete(String)
    case markAllComplete
    case editTimes
}

// MARK: - Preview Provider

struct EventPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Single event preview
            EventPreviewView(
                event: EventPreview(
                    id: "1",
                    icon: "💼",
                    title: "Team Standup",
                    timeDescription: "Today at 3:00 PM - 3:30 PM",
                    location: "Conference Room B",
                    category: "work",
                    isMultiDay: false,
                    dayCount: 1,
                    dayBreakdown: nil,
                    actions: [.edit, .delete, .complete]
                ),
                isAccepted: false,
                isDeleted: false,
                onAction: { _ in }
            )
            
            // Multi-day event preview
            EventPreviewView(
                event: EventPreview(
                    id: "2",
                    icon: "✈️",
                    title: "Vacation in Bali",
                    timeDescription: "Dec 20 - Dec 27",
                    location: "Bali, Indonesia",
                    category: "personal",
                    isMultiDay: true,
                    dayCount: 8,
                    dayBreakdown: [
                        .init(day: 1, description: "Flight + Check-in"),
                        .init(day: 2, description: "Beach & Activities"),
                        .init(day: 3, description: "Temple Tour"),
                        .init(day: 4, description: "Snorkeling"),
                    ],
                    actions: [.viewFull, .edit, .delete]
                ),
                isAccepted: true,
                isDeleted: false,
                onAction: { _ in }
            )
            
            // Multiple events preview
            MultipleEventsPreviewView(
                events: [
                    EventListItem(id: "1", time: "6:00 AM", title: "Wake up & Hydrate", isCompleted: false, date: Date()),
                    EventListItem(id: "2", time: "6:15 AM", title: "Morning Exercise", isCompleted: false, date: Date()),
                    EventListItem(id: "3", time: "6:45 AM", title: "Shower", isCompleted: false, date: Date()),
                    EventListItem(id: "4", time: "7:15 AM", title: "Breakfast", isCompleted: false, date: Date().addingTimeInterval(86400)),
                ],
                isAccepted: false,
                onAction: { _ in }
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

// Conditional modifier extension is defined in ViewExtensions.swift