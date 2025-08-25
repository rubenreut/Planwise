//
//  EnhancedChatComponents.swift
//  Momentum
//
//  Enhanced chat UI components with CRUD preview cards
//

import SwiftUI

// MARK: - CRUD Preview Card Protocol
protocol CRUDPreviewCard: View {
    var itemType: String { get }
    var itemTitle: String { get }
    var timestamp: Date { get }
}

// MARK: - Created Item Preview Card
struct CreatedItemCard: View {
    let itemType: String
    let itemTitle: String
    let itemDescription: String?
    let timestamp: Date
    let categoryColor: Color?
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    @State private var isExpanded = false
    @State private var showSuccess = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with animation
            HStack {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(Color.fromAccentString(selectedAccentColor).opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: iconForType)
                        .scaledFont(size: 18, weight: .semibold)
                        .foregroundColor(Color.fromAccentString(selectedAccentColor))
                        .rotationEffect(.degrees(showSuccess ? 360 : 0))
                        .scaleEffect(showSuccess ? 1.2 : 1.0)
                }
                .animation(.spring(response: 0.4), value: showSuccess)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Created \(itemType)")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundColor(.secondary)
                    
                    Text(itemTitle)
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 1)
                }
                
                Spacer()
                
                // Success checkmark
                if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .scaledFont(size: 24)
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Description if available
            if let description = itemDescription, !description.isEmpty {
                Text(description)
                    .scaledFont(size: 14)
                    .foregroundColor(.secondary)
                    .lineLimit(isExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Category indicator
            if let color = categoryColor {
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text("Categorized")
                        .scaledFont(size: 12)
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: { 
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }) {
                    Label(isExpanded ? "Show Less" : "Show More", 
                          systemImage: isExpanded ? "chevron.up" : "chevron.down")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundColor(Color.fromAccentString(selectedAccentColor))
                }
                
                Spacer()
                
                // Time indicator
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .scaledFont(size: 11)
                    Text(timestamp, style: .relative)
                        .scaledFont(size: 11)
                }
                .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.fromAccentString(selectedAccentColor).opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            withAnimation(.spring().delay(0.3)) {
                showSuccess = true
            }
        }
    }
    
    private var iconForType: String {
        switch itemType.lowercased() {
        case "task": return "checkmark.circle.fill"
        case "event": return "calendar.badge.plus"
        case "habit": return "repeat.circle.fill"
        case "goal": return "target"
        default: return "plus.circle.fill"
        }
    }
}

// MARK: - Updated Item Preview Card
struct UpdatedItemCard: View {
    let itemType: String
    let itemTitle: String
    let changes: [String: (old: String, new: String)]
    let timestamp: Date
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    @State private var showChanges = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "pencil.circle.fill")
                        .scaledFont(size: 18, weight: .semibold)
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Updated \(itemType)")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundColor(.secondary)
                    
                    Text(itemTitle)
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Change count badge
                Text("\(changes.count)")
                    .scaledFont(size: 12, weight: .bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange)
                    )
            }
            
            // Changes preview
            if showChanges {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(changes.keys), id: \.self) { key in
                        if let change = changes[key] {
                            ChangeRowView(
                                field: key,
                                oldValue: change.old,
                                newValue: change.new
                            )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Toggle button
            Button(action: {
                withAnimation(.spring()) {
                    showChanges.toggle()
                }
            }) {
                HStack {
                    Text(showChanges ? "Hide Changes" : "View Changes")
                        .scaledFont(size: 13, weight: .medium)
                    Image(systemName: showChanges ? "chevron.up" : "chevron.down")
                        .scaledFont(size: 12)
                }
                .foregroundColor(Color.fromAccentString(selectedAccentColor))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Change Row View
struct ChangeRowView: View {
    let field: String
    let oldValue: String
    let newValue: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field.capitalized)
                .scaledFont(size: 12, weight: .semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                // Old value
                HStack(spacing: 4) {
                    Image(systemName: "minus.circle.fill")
                        .scaledFont(size: 12)
                        .foregroundColor(.red)
                    Text(oldValue)
                        .scaledFont(size: 13)
                        .strikethrough()
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "arrow.right")
                    .scaledFont(size: 10)
                    .foregroundColor(.secondary.opacity(0.5))
                
                // New value
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .scaledFont(size: 12)
                        .foregroundColor(.green)
                    Text(newValue)
                        .scaledFont(size: 13)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

// MARK: - Deleted Item Preview Card
struct DeletedItemCard: View {
    let itemType: String
    let itemTitle: String
    let reason: String?
    let timestamp: Date
    @State private var showUndo = true
    @State private var isDeleted = false
    var onUndo: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "trash.circle.fill")
                        .scaledFont(size: 18, weight: .semibold)
                        .foregroundColor(.red)
                        .rotationEffect(.degrees(isDeleted ? -10 : 0))
                }
                .animation(.spring(), value: isDeleted)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Deleted \(itemType)")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundColor(.secondary)
                    
                    Text(itemTitle)
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.primary)
                        .strikethrough(isDeleted)
                }
                
                Spacer()
                
                if showUndo {
                    Button(action: {
                        onUndo?()
                        withAnimation {
                            showUndo = false
                        }
                    }) {
                        Text("Undo")
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                            )
                    }
                }
            }
            
            if let reason = reason {
                Text(reason)
                    .scaledFont(size: 13)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .opacity(isDeleted ? 0.6 : 1.0)
        .onAppear {
            withAnimation(.spring().delay(0.5)) {
                isDeleted = true
            }
            
            // Auto-hide undo after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    showUndo = false
                }
            }
        }
    }
}

// MARK: - Bulk Action Preview Card
struct BulkActionCard: View {
    let action: String
    let itemCount: Int
    let itemType: String
    let details: [String]
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    @State private var showDetails = false
    @State private var completedCount = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.fromAccentString(selectedAccentColor).opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "square.stack.3d.up.fill")
                        .scaledFont(size: 18, weight: .semibold)
                        .foregroundColor(Color.fromAccentString(selectedAccentColor))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bulk \(action)")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundColor(.secondary)
                    
                    Text("\(itemCount) \(itemType)\(itemCount > 1 ? "s" : "")")
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Progress indicator
                CircularProgress(
                    progress: Double(completedCount) / Double(itemCount),
                    lineWidth: 3,
                    size: 30,
                    color: Color.fromAccentString(selectedAccentColor)
                )
                .overlay(
                    Text("\(completedCount)/\(itemCount)")
                        .scaledFont(size: 10, weight: .bold)
                )
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.fromAccentString(selectedAccentColor))
                        .frame(
                            width: geometry.size.width * (Double(completedCount) / Double(itemCount)),
                            height: 8
                        )
                        .animation(.spring(), value: completedCount)
                }
            }
            .frame(height: 8)
            
            // Details preview
            if showDetails {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(details.prefix(5), id: \.self) { detail in
                            Text(detail)
                                .scaledFont(size: 12)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.gray.opacity(0.1))
                                )
                        }
                        
                        if details.count > 5 {
                            Text("+\(details.count - 5) more")
                                .scaledFont(size: 12)
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Button(action: {
                withAnimation(.spring()) {
                    showDetails.toggle()
                }
            }) {
                HStack {
                    Text(showDetails ? "Hide Details" : "Show Details")
                        .scaledFont(size: 13, weight: .medium)
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .scaledFont(size: 12)
                }
                .foregroundColor(Color.fromAccentString(selectedAccentColor))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.fromAccentString(selectedAccentColor).opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            // Animate progress
            withAnimation(.easeInOut(duration: 1.5)) {
                completedCount = itemCount
            }
        }
    }
}

// MARK: - Circular Progress View
struct CircularProgress: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.spring(), value: progress)
        }
    }
}

// MARK: - Animated Typing Indicator
struct AnimatedTypingIndicator: View {
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    @State private var animatingDots = [false, false, false]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.fromAccentString(selectedAccentColor))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDots[index] ? 1.2 : 0.8)
                    .opacity(animatingDots[index] ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animatingDots[index]
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    Capsule()
                        .stroke(Color.fromAccentString(selectedAccentColor).opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            for index in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                    animatingDots[index] = true
                }
            }
        }
    }
}

// MARK: - Quick Action Buttons
struct QuickActionButtons: View {
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    let suggestions: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: { onSelect(suggestion) }) {
                        Text(suggestion)
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundColor(Color.fromAccentString(selectedAccentColor))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.fromAccentString(selectedAccentColor).opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.fromAccentString(selectedAccentColor).opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(SpringButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Spring Button Style
struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Empty State View
struct ChatEmptyStateView: View {
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    let prompts = [
        "📅 Schedule my day",
        "✅ Create a new task",
        "🎯 Set a goal",
        "📊 Show my progress",
        "💡 Give me suggestions"
    ]
    let onPromptSelect: (String) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.fromAccentString(selectedAccentColor).opacity(0.2),
                                Color.fromAccentString(selectedAccentColor).opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Image(systemName: "brain")
                    .scaledFont(size: 48, weight: .medium)
                    .foregroundColor(Color.fromAccentString(selectedAccentColor))
                    .symbolEffect(.pulse)
            }
            
            VStack(spacing: 8) {
                Text("Hi! I'm your AI Assistant")
                    .scaledFont(size: 24, weight: .bold)
                    .foregroundColor(.primary)
                
                Text("How can I help you today?")
                    .scaledFont(size: 16)
                    .foregroundColor(.secondary)
            }
            
            // Prompt suggestions
            VStack(spacing: 12) {
                Text("Try asking:")
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundColor(.secondary.opacity(0.7))
                
                ForEach(prompts, id: \.self) { prompt in
                    Button(action: { onPromptSelect(prompt) }) {
                        HStack {
                            Text(prompt)
                                .scaledFont(size: 15, weight: .medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right.circle.fill")
                                .scaledFont(size: 20)
                                .foregroundColor(Color.fromAccentString(selectedAccentColor))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(SpringButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Message Status Indicator
struct MessageStatusIndicator: View {
    enum Status {
        case sending, sent, delivered, read, error
    }
    
    let status: Status
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    var body: some View {
        HStack(spacing: 2) {
            switch status {
            case .sending:
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                
            case .sent:
                Image(systemName: "checkmark")
                    .scaledFont(size: 10, weight: .medium)
                    .foregroundColor(.secondary)
                
            case .delivered:
                HStack(spacing: -4) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .scaledFont(size: 10, weight: .medium)
                .foregroundColor(.secondary)
                
            case .read:
                HStack(spacing: -4) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .scaledFont(size: 10, weight: .medium)
                .foregroundColor(Color.fromAccentString(selectedAccentColor))
                
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .scaledFont(size: 12)
                    .foregroundColor(.red)
            }
        }
    }
}