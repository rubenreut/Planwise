//
//  EventPreviewView.swift
//  Momentum
//
//  Rich event preview component for chat messages
//

import SwiftUI

struct EventPreviewView: View {
    let event: EventPreview
    let onAction: (EventAction) -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    @State private var showingActions = true
    
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
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPressed = true
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    onAction(action)
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isPressed = false
                                    }
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    
                                    Image(systemName: action.icon)
                                        .font(.system(size: 14, weight: .medium))
                                    
                                    Text(action.label)
                                        .font(.system(size: 14, weight: .semibold))
                                    
                                    Spacer()
                                }
                                .foregroundColor(action.isDestructive ? .red : .accentColor)
                                .padding(.vertical, 14)
                                .background(
                                    Rectangle()
                                        .fill(Color.primary.opacity(isPressed ? 0.05 : 0))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundGradient)
                .shadow(
                    color: shadowColor,
                    radius: 12,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3),
                            Color.white.opacity(0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
    
    private var categoryGradient: LinearGradient {
        LinearGradient(
            colors: getCategoryColors(event.category ?? ""),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var backgroundGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(white: 0.15),
                    Color(white: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white,
                    Color(white: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.1)
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
        case .complete: return "Complete"
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
    let onAction: (BulkActionPreview.BulkAction) -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    @State private var showingConfirmation = false
    
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
                            
                            // Affected count badge
                            HStack(spacing: 4) {
                                Image(systemName: "number.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("\(preview.affectedCount)")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(warningGradient)
                            )
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
            
            // Action buttons
            HStack(spacing: 12) {
                ForEach(preview.actions, id: \.self) { action in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                            handleAction(action)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: iconForAction(action))
                                .font(.system(size: 14, weight: .semibold))
                            
                            Text(labelForAction(action))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(colorForAction(action))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(backgroundForAction(action))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(borderForAction(action), lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.95), value: isPressed)
        .confirmationDialog(
            "Are you sure?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Confirm", role: .destructive) {
                onAction(.confirm)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will \(preview.action) \(preview.affectedCount) events. This action cannot be undone.")
        }
    }
    
    private func handleAction(_ action: BulkActionPreview.BulkAction) {
        if action == .confirm && preview.warningLevel == .critical {
            showingConfirmation = true
        } else {
            onAction(action)
        }
    }
    
    private func iconForAction(_ action: BulkActionPreview.BulkAction) -> String {
        switch action {
        case .confirm:
            return preview.warningLevel == .critical ? "trash.fill" : "checkmark.circle.fill"
        case .cancel:
            return "xmark.circle.fill"
        case .undo:
            return "arrow.uturn.backward.circle.fill"
        }
    }
    
    private func labelForAction(_ action: BulkActionPreview.BulkAction) -> String {
        switch action {
        case .confirm:
            return preview.warningLevel == .critical ? "Delete" : "Confirm"
        case .cancel:
            return "Cancel"
        case .undo:
            return "Undo"
        }
    }
    
    private func colorForAction(_ action: BulkActionPreview.BulkAction) -> Color {
        switch action {
        case .confirm:
            return preview.warningLevel == .critical ? .white : .white
        case .cancel:
            return .primary
        case .undo:
            return .orange
        }
    }
    
    private func backgroundForAction(_ action: BulkActionPreview.BulkAction) -> Color {
        switch action {
        case .confirm:
            return preview.warningLevel == .critical ? .red : .accentColor
        case .cancel:
            return .clear
        case .undo:
            return .orange.opacity(0.15)
        }
    }
    
    private func borderForAction(_ action: BulkActionPreview.BulkAction) -> Color {
        switch action {
        case .confirm:
            return .clear
        case .cancel:
            return Color(.separator)
        case .undo:
            return .orange.opacity(0.3)
        }
    }
}

// MARK: - Multiple Events Preview

struct MultipleEventsPreviewView: View {
    let events: [EventListItem]
    let onAction: (MultiEventAction) -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var animatedEvents: Set<String> = []
    
    private let φ: Double = 1.618033988749895
    
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
                
                // Progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: completionProgress)
                        .stroke(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: completionProgress)
                    
                    Text("\(completedCount)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .padding(16)
            
            Divider()
            
            // Events list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        HStack(spacing: 12) {
                            // Checkbox with animation
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    animatedEvents.insert(event.id)
                                }
                                onAction(.toggleComplete(event.id))
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    animatedEvents.remove(event.id)
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(event.isCompleted ? Color.green : Color.secondary.opacity(0.3), lineWidth: 2)
                                        .frame(width: 22, height: 22)
                                    
                                    if event.isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.green)
                                            .scaleEffect(animatedEvents.contains(event.id) ? 1.2 : 1.0)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Time badge
                            Text(event.time)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: getTimeColors(for: index),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            
                            // Event title
                            Text(event.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(event.isCompleted ? .secondary : .primary)
                                .strikethrough(event.isCompleted, color: .secondary)
                                .lineLimit(2)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            event.isCompleted ? Color.green.opacity(0.05) : Color.clear
                        )
                        
                        if index < events.count - 1 {
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            
            // Action buttons
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 0) {
                    Button(action: { onAction(.markAllComplete) }) {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text("Mark All Complete")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(.green)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .frame(height: 20)
                    
                    Button(action: { onAction(.editTimes) }) {
                        HStack {
                            Spacer()
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 14, weight: .medium))
                            Text("Edit Times")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundGradient)
                .shadow(
                    color: shadowColor,
                    radius: 12,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3),
                            Color.white.opacity(0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private var completedCount: Int {
        events.filter { $0.isCompleted }.count
    }
    
    private var completionProgress: Double {
        guard !events.isEmpty else { return 0 }
        return Double(completedCount) / Double(events.count)
    }
    
    private var backgroundGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(white: 0.15),
                    Color(white: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white,
                    Color(white: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.1)
    }
    
    private func getTimeColors(for index: Int) -> [Color] {
        let colors = [
            [Color(hex: "667eea"), Color(hex: "764ba2")],
            [Color(hex: "f093fb"), Color(hex: "f5576c")],
            [Color(hex: "4facfe"), Color(hex: "00f2fe")],
            [Color(hex: "43e97b"), Color(hex: "38f9d7")],
            [Color(hex: "fa709a"), Color(hex: "fee140")],
        ]
        return colors[index % colors.count]
    }
}

struct EventListItem: Identifiable, Equatable {
    let id: String
    let time: String
    let title: String
    let isCompleted: Bool
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
                onAction: { _ in }
            )
            
            // Multiple events preview
            MultipleEventsPreviewView(
                events: [
                    EventListItem(id: "1", time: "6:00 AM", title: "Wake up & Hydrate", isCompleted: false),
                    EventListItem(id: "2", time: "6:15 AM", title: "Morning Exercise", isCompleted: false),
                    EventListItem(id: "3", time: "6:45 AM", title: "Shower", isCompleted: false),
                    EventListItem(id: "4", time: "7:15 AM", title: "Breakfast", isCompleted: false),
                ],
                onAction: { _ in }
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}