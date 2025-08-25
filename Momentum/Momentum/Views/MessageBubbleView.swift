import SwiftUI

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChatMessage
    let acceptedEventIds: Set<String>
    let deletedEventIds: Set<String>
    let acceptedMultiEventMessageIds: Set<UUID>
    let completedBulkActionIds: Set<String>
    var onRetry: (() -> Void)? = nil
    var onEventAction: ((String, EventAction) -> Void)? = nil
    var onMultiEventAction: ((MultiEventAction, UUID) -> Void)? = nil
    var onBulkAction: ((UUID, BulkActionPreview.BulkAction) -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    @State private var isPressed = false
    @State private var showActions = false
    @State private var messageStatus: MessageStatusIndicator.Status = .sent
    @State private var showReactions = false
    @State private var selectedReaction: String? = nil
    @State private var showCopySuccess = false
    
    // MARK: - Mathematical Constants
    
    private let φ: Double = 1.618033988749895
    private let baseUnit: Double = 8.0
    
    // MARK: - Computed Properties
    
    private var bubbleColor: Color {
        if message.sender.isUser {
            // User messages use accent color
            return Color.fromAccentString(selectedAccentColor)
        } else {
            // AI messages use adaptive background
            return Color(UIColor.secondarySystemBackground)
        }
    }
    
    private var textColor: Color {
        if message.sender.isUser {
            return .white
        } else {
            return Color.aiBubbleText
        }
    }
    
    private var horizontalPadding: Double {
        baseUnit * 2 // 16px
    }
    
    private var verticalPadding: Double {
        baseUnit * φ // 13px
    }
    
    private var maxWidth: Double {
        return max(100, UIScreen.main.bounds.width - (baseUnit * 4)) // Full width minus padding for both
    }
    
    private func documentIcon(for extension: String) -> String {
        switch `extension`.lowercased() {
        case "pdf":
            return "doc.fill"
        case "doc", "docx":
            return "doc.richtext.fill"
        case "txt":
            return "doc.text.fill"
        default:
            return "doc.fill"
        }
    }
    
    private func documentColor(for extension: String) -> Color {
        switch `extension`.lowercased() {
        case "pdf":
            return .red
        case "doc", "docx":
            return .blue
        case "txt":
            return .gray
        default:
            return .orange
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: baseUnit) {
            // Remove spacer to make both user and AI messages full width
            
            VStack(alignment: message.sender.isUser ? .trailing : .leading, spacing: baseUnit / 2) {
                // Show name only for user messages
                if case .user(let name) = message.sender {
                    Text(name)
                        .scaledFont(size: 11, weight: .medium, design: .default)
                        .foregroundColor(.secondary)
                        .tracking(-0.2)
                }
                
                // Check for CRUD operations first
                if let crudOperation = detectCRUDOperation(), !message.sender.isUser {
                    renderCRUDCard(for: crudOperation)
                        .frame(maxWidth: maxWidth, alignment: .leading)
                }
                // Check if this is a function call card message
                else if message.eventPreview != nil || message.multipleEventsPreview != nil || message.bulkActionPreview != nil {
                    // Render event previews without bubble background
                    Group {
                        // Rich event preview
                        if let eventPreview = message.eventPreview {
                            EventPreviewView(
                                event: eventPreview,
                                isAccepted: acceptedEventIds.contains(eventPreview.id),
                                isDeleted: deletedEventIds.contains(eventPreview.id),
                                onAction: { action in
                                    onEventAction?(eventPreview.id, action)
                                },
                                inMessageBubble: false
                            )
                        }
                        
                        // Multiple events preview
                        if let multipleEvents = message.multipleEventsPreview {
                            MultipleEventsPreviewView(
                                events: multipleEvents,
                                isAccepted: acceptedMultiEventMessageIds.contains(message.id),
                                onAction: { action in
                                    onMultiEventAction?(action, message.id)
                                },
                                inMessageBubble: false
                            )
                        }
                        
                        // Bulk action preview
                        if let bulkActionPreview = message.bulkActionPreview {
                            BulkActionPreviewView(
                                preview: bulkActionPreview,
                                isCompleted: completedBulkActionIds.contains(bulkActionPreview.id),
                                onAction: { action in
                                    onBulkAction?(message.id, action)
                                },
                                inMessageBubble: false
                            )
                        }
                    }
                    .frame(maxWidth: maxWidth, alignment: message.sender.isUser ? .trailing : .leading)
                } else {
                    // Regular message bubble
                    VStack(alignment: .leading, spacing: baseUnit) {
                    
                    // Attached file/image preview
                    if let image = message.attachedImage {
                        VStack(alignment: .leading, spacing: baseUnit / 2) {
                            // Show file name for PDFs and other documents
                            if let fileName = message.attachedFileName {
                                HStack(spacing: baseUnit / 2) {
                                    Image(systemName: documentIcon(for: message.attachedFileExtension ?? ""))
                                        .scaledFont(size: 14)
                                        .foregroundColor(documentColor(for: message.attachedFileExtension ?? ""))
                                    
                                    Text(fileName)
                                        .scaledFont(size: 13, weight: .medium)
                                        .foregroundColor(textColor.opacity(0.9))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .textSelection(.enabled)
                                }
                            }
                            
                            // Image preview
                            HStack {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.adaptiveBorder.opacity(0.5), lineWidth: 1)
                                    )
                                Spacer()
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, verticalPadding)
                        .padding(.bottom, message.content.isEmpty ? verticalPadding : baseUnit / 2)
                    } else if let fileName = message.attachedFileName,
                              let fileExtension = message.attachedFileExtension {
                        // Non-image file attachment
                        HStack(spacing: baseUnit) {
                            // Document icon
                            VStack {
                                Image(systemName: documentIcon(for: fileExtension))
                                    .scaledFont(size: 28)
                                    .foregroundColor(documentColor(for: fileExtension))
                                Text(fileExtension.uppercased())
                                    .scaledFont(size: 10, weight: .medium)
                                    .foregroundColor(textColor.opacity(0.6))
                            }
                            .frame(width: 60, height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(documentColor(for: fileExtension).opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(documentColor(for: fileExtension).opacity(0.3), lineWidth: 1)
                                    )
                            )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fileName)
                                    .scaledFont(size: 14, weight: .medium)
                                    .foregroundColor(textColor)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                Text("Document")
                                    .scaledFont(size: 12)
                                    .foregroundColor(textColor.opacity(0.6))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, verticalPadding)
                        .padding(.bottom, message.content.isEmpty ? verticalPadding : baseUnit / 2)
                    }
                    
                    // Main message content
                    if !message.content.isEmpty {
                        MarkdownText(text: message.content, textColor: textColor)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, verticalPadding)
                            .padding(.top, message.attachedImage != nil ? 0 : verticalPadding)
                    }
                    
                    // Error state
                    if let error = message.error {
                        HStack(spacing: baseUnit / 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .scaledFont(size: 14)
                                .foregroundColor(.orange)
                            
                            Text(error)
                                .scaledFont(size: 13)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                            
                            if let onRetry = onRetry {
                                Spacer()
                                
                                Button(action: onRetry) {
                                    HStack(spacing: baseUnit / 4) {
                                        Image(systemName: "arrow.clockwise")
                                            .scaledFont(size: 12)
                                        Text("Retry")
                                            .scaledFont(size: 12, weight: .medium)
                                    }
                                    .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, baseUnit)
                    }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: baseUnit * 2.5)
                            .fill(bubbleColor)
                            .shadow(
                                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                    )
                    .frame(maxWidth: maxWidth, alignment: message.sender.isUser ? .trailing : .leading)
                }
                
                // Streaming indicator
                if message.isStreaming {
                    StreamingIndicator()
                        .padding(.horizontal, baseUnit)
                }
                
                // Message actions row (reactions, copy, share)
                if !message.sender.isUser && !message.isStreaming && !message.content.isEmpty {
                    HStack(spacing: baseUnit) {
                        // Reaction button
                        Button(action: {
                            withAnimation(.spring()) {
                                showReactions.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                if let reaction = selectedReaction {
                                    Text(reaction)
                                        .scaledFont(size: 16)
                                } else {
                                    Image(systemName: "face.smiling")
                                        .scaledFont(size: 14)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                        
                        // Copy button
                        Button(action: {
                            copyToClipboard()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showCopySuccess ? "checkmark" : "doc.on.doc")
                                    .scaledFont(size: 14)
                                    .foregroundColor(showCopySuccess ? .green : .secondary)
                                    .symbolEffect(.bounce, value: showCopySuccess)
                                if showCopySuccess {
                                    Text("Copied")
                                        .scaledFont(size: 12)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                        
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .scale))
                }
                
                // Reaction picker
                if showReactions {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["👍", "❤️", "🎉", "💡", "🔥", "👏", "😊", "🚀"], id: \.self) { emoji in
                                Button(action: {
                                    withAnimation(.spring()) {
                                        selectedReaction = emoji
                                        showReactions = false
                                        HapticFeedback.light.trigger()
                                    }
                                }) {
                                    Text(emoji)
                                        .scaledFont(size: 24)
                                        .scaleEffect(selectedReaction == emoji ? 1.2 : 1.0)
                                }
                            }
                        }
                        .padding(.horizontal, baseUnit)
                    }
                    .frame(height: 40)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            
            // Remove spacer for AI messages to make them full width
        }
        .padding(.horizontal, baseUnit * 2) // 16px
        .padding(.vertical, baseUnit / 2) // 4px
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(message.error != nil && onRetry != nil ? "Double tap to retry" : "")
    }
    
    private var accessibilityLabel: String {
        var components: [String] = []
        
        // Sender
        switch message.sender {
        case .user(let name):
            components.append("Message from \(name)")
        case .assistant:
            components.append("Response from Planwise Assistant")
        }
        
        // Function call
        if let functionCall = message.functionCall {
            components.append("Function call: \(functionCall.displayName)")
        }
        
        // Content
        if !message.content.isEmpty {
            let cleanContent = message.content
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "`", with: "")
                .replacingOccurrences(of: "#", with: "")
            components.append(cleanContent)
        }
        
        // Error
        if let error = message.error {
            components.append("Error: \(error)")
        }
        
        // Event preview
        if let event = message.eventPreview {
            components.append("Event preview: \(event.title)")
        }
        
        // Multiple events
        if let events = message.multipleEventsPreview {
            components.append("Preview of \(events.count) events")
        }
        
        return components.joined(separator: ". ")
    }
    
    // MARK: - Helper Functions
    
    private func copyToClipboard() {
        UIPasteboard.general.string = message.content
        withAnimation(.spring()) {
            showCopySuccess = true
        }
        HapticFeedback.success.trigger()
        
        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopySuccess = false
            }
        }
    }
}

// MARK: - Markdown Text View

struct MarkdownText: View {
    let text: String
    let textColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(text.components(separatedBy: "\n\n").indices, id: \.self) { index in
                let paragraph = text.components(separatedBy: "\n\n")[index]
                if !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Handle single line breaks within paragraphs
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(paragraph.components(separatedBy: "\n").indices, id: \.self) { lineIndex in
                            let line = paragraph.components(separatedBy: "\n")[lineIndex]
                            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                if let attributedString = try? AttributedString(markdown: line) {
                                    Text(attributedString)
                                        .scaledFont(size: 15, weight: .regular, design: .default)
                                        .foregroundColor(textColor)
                                        .tracking(-0.2)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .textSelection(.enabled)
                                } else {
                                    // Fallback for each line
                                    Text(processSimpleMarkdown(line))
                                        .scaledFont(size: 15, weight: .regular, design: .default)
                                        .foregroundColor(textColor)
                                        .tracking(-0.2)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func processSimpleMarkdown(_ text: String) -> String {
        var result = text
        
        // Remove bold markers
        result = result.replacingOccurrences(of: "**", with: "")
        
        // Remove italic markers
        result = result.replacingOccurrences(of: "*", with: "")
        
        // Remove code markers
        result = result.replacingOccurrences(of: "`", with: "")
        
        // Remove headers
        result = result.replacingOccurrences(of: "### ", with: "")
        result = result.replacingOccurrences(of: "## ", with: "")
        result = result.replacingOccurrences(of: "# ", with: "")
        
        return result
    }
}

// MARK: - Streaming Indicator

struct StreamingIndicator: View {
    @State private var isAnimating = false
    private let baseUnit: Double = 8.0
    
    var body: some View {
        HStack(spacing: baseUnit / 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Function Call Result View

struct FunctionCallResultView: View {
    let result: FunctionCallResult
    @Environment(\.colorScheme) private var colorScheme
    private let baseUnit: Double = 8.0
    
    var iconName: String {
        switch result.functionName {
        case "create_event":
            return "plus.circle.fill"
        case "update_event":
            return "pencil.circle.fill"
        case "delete_event":
            return "trash.circle.fill"
        case "list_events":
            return "list.bullet.circle.fill"
        case "suggest_schedule":
            return "lightbulb.circle.fill"
        default:
            return "gear.circle.fill"
        }
    }
    
    var iconColor: Color {
        result.success ? .green : .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: baseUnit / 2) {
            HStack(spacing: baseUnit / 2) {
                Image(systemName: iconName)
                    .scaledFont(size: 16)
                    .foregroundColor(iconColor)
                
                Text(result.displayName)
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if result.success {
                    Image(systemName: "checkmark")
                        .scaledFont(size: 12)
                        .foregroundColor(.green)
                }
            }
            
            Text(result.message)
                .scaledFont(size: 13)
                .foregroundColor(.secondary)
            
            if let details = result.details {
                ForEach(Array(details.keys.sorted()), id: \.self) { key in
                    HStack(spacing: baseUnit / 2) {
                        Text("\(key):")
                            .scaledFont(size: 12)
                            .foregroundColor(Color.secondary.opacity(0.7))
                        Text(details[key] ?? "")
                            .scaledFont(size: 12)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(baseUnit)
        .background(
            RoundedRectangle(cornerRadius: baseUnit)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        MessageBubbleView(
            message: ChatMessage(
                content: "How can I better manage my time today?",
                sender: .user(name: "Ruben"),
                timestamp: Date()
            ),
            acceptedEventIds: [],
            deletedEventIds: [],
            acceptedMultiEventMessageIds: [],
            completedBulkActionIds: []
        )
        
        MessageBubbleView(
            message: ChatMessage(
                content: "Based on your schedule, I recommend time-blocking your morning for deep work. You have a 2-hour window from 9-11 AM that would be perfect for focused tasks.",
                sender: .assistant,
                timestamp: Date()
            ),
            acceptedEventIds: [],
            deletedEventIds: [],
            acceptedMultiEventMessageIds: [],
            completedBulkActionIds: []
        )
        
        MessageBubbleView(
            message: ChatMessage(
                content: "I've created a new event for you:",
                sender: .assistant,
                timestamp: Date(),
                functionCall: FunctionCallResult(
                    functionName: "create_event",
                    success: true,
                    message: "Deep Work Session",
                    details: ["Time": "9:00 AM - 11:00 AM", "Category": "Work"]
                )
            ),
            acceptedEventIds: [],
            deletedEventIds: [],
            acceptedMultiEventMessageIds: [],
            completedBulkActionIds: []
        )
        
        MessageBubbleView(
            message: ChatMessage(
                content: "Analyzing your productivity patterns...",
                sender: .assistant,
                timestamp: Date(),
                isStreaming: true
            ),
            acceptedEventIds: [],
            deletedEventIds: [],
            acceptedMultiEventMessageIds: [],
            completedBulkActionIds: []
        )
        
        MessageBubbleView(
            message: ChatMessage(
                content: "",
                sender: .assistant,
                timestamp: Date(),
                error: "Rate limit exceeded. Please try again in 60 seconds."
            ),
            acceptedEventIds: [],
            deletedEventIds: [],
            acceptedMultiEventMessageIds: [],
            completedBulkActionIds: []
        )
        
        // Bulk action preview
        MessageBubbleView(
            message: ChatMessage(
                content: "I've completed 5 tasks for you:\n• Review project proposal\n• Send weekly report\n• Update calendar\n• Check emails\n• Prepare presentation",
                sender: .assistant,
                timestamp: Date()
            ),
            acceptedEventIds: [],
            deletedEventIds: [],
            acceptedMultiEventMessageIds: [],
            completedBulkActionIds: []
        )
        
        MessageBubbleView(
            message: ChatMessage(
                content: "I've scheduled the following events:\n1. Team meeting at 10 AM\n2. Lunch with client at 12:30 PM\n3. Project review at 3 PM",
                sender: .assistant,
                timestamp: Date()
            ),
            acceptedEventIds: [],
            deletedEventIds: [],
            acceptedMultiEventMessageIds: [],
            completedBulkActionIds: []
        )
    }
    .background(Color(.systemBackground))
}

// MARK: - CRUD Operation Detection
extension MessageBubbleView {
    
    private func detectCRUDOperation() -> CRUDOperation? {
        let content = message.content.lowercased()
        
        // Check for created operations
        if content.contains("created") || content.contains("added") || content.contains("scheduled") {
            if content.contains("task") {
                return .created(type: "Task", title: extractTitle(from: content))
            } else if content.contains("event") {
                return .created(type: "Event", title: extractTitle(from: content))
            } else if content.contains("habit") {
                return .created(type: "Habit", title: extractTitle(from: content))
            } else if content.contains("goal") {
                return .created(type: "Goal", title: extractTitle(from: content))
            }
        }
        
        // Check for updated operations
        if content.contains("updated") || content.contains("modified") || content.contains("changed") {
            if content.contains("task") {
                return .updated(type: "Task", title: extractTitle(from: content))
            } else if content.contains("event") {
                return .updated(type: "Event", title: extractTitle(from: content))
            }
        }
        
        // Check for deleted operations
        if content.contains("deleted") || content.contains("removed") || content.contains("cancelled") {
            if content.contains("task") {
                return .deleted(type: "Task", title: extractTitle(from: content))
            } else if content.contains("event") {
                return .deleted(type: "Event", title: extractTitle(from: content))
            }
        }
        
        // Check for bulk operations
        if content.contains("multiple") || content.contains("all") || content.contains("bulk") || 
           content.contains("several") || content.contains("batch") {
            let count = extractCount(from: content)
            
            // Detect action type
            if content.contains("completed") || content.contains("marked as complete") || 
               content.contains("finished") || content.contains("done") {
                let itemType = detectBulkItemType(from: content)
                return .bulk(action: "Completed", count: count, type: itemType)
            } else if content.contains("deleted") || content.contains("removed") {
                let itemType = detectBulkItemType(from: content)
                return .bulk(action: "Deleted", count: count, type: itemType)
            } else if content.contains("created") || content.contains("added") {
                let itemType = detectBulkItemType(from: content)
                return .bulk(action: "Created", count: count, type: itemType)
            } else if content.contains("updated") || content.contains("modified") {
                let itemType = detectBulkItemType(from: content)
                return .bulk(action: "Updated", count: count, type: itemType)
            } else if content.contains("scheduled") {
                return .bulk(action: "Scheduled", count: count, type: "events")
            } else if content.contains("rescheduled") {
                return .bulk(action: "Rescheduled", count: count, type: "events")
            }
        }
        
        // Check for list of items with bullet points or numbers
        let lines = content.components(separatedBy: .newlines)
        var itemCount = 0
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).starts(with: "•") ||
               line.trimmingCharacters(in: .whitespaces).starts(with: "-") ||
               line.trimmingCharacters(in: .whitespaces).starts(with: "*") ||
               line.range(of: "^\\d+\\.", options: .regularExpression) != nil {
                itemCount += 1
            }
        }
        
        if itemCount >= 3 {
            // We have a list of items
            if content.contains("created") || content.contains("added") {
                let itemType = detectBulkItemType(from: content)
                return .bulk(action: "Created", count: itemCount, type: itemType)
            } else if content.contains("scheduled") {
                return .bulk(action: "Scheduled", count: itemCount, type: "events")
            }
        }
        
        return nil
    }
    
    private func extractTitle(from text: String) -> String {
        // Try to extract text between quotes
        if let firstQuote = text.firstIndex(of: "\""),
           let lastQuote = text.lastIndex(of: "\""),
           firstQuote < lastQuote {
            let startIndex = text.index(after: firstQuote)
            let endIndex = lastQuote
            return String(text[startIndex..<endIndex])
        }
        
        // Try to extract text between single quotes
        if let firstQuote = text.firstIndex(of: "'"),
           let lastQuote = text.lastIndex(of: "'"),
           firstQuote < lastQuote {
            let startIndex = text.index(after: firstQuote)
            let endIndex = lastQuote
            return String(text[startIndex..<endIndex])
        }
        
        // Default title
        return "Untitled"
    }
    
    private func extractCount(from text: String) -> Int {
        // Look for number words first
        let numberWords = [
            "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10
        ]
        
        let lowercased = text.lowercased()
        for (word, value) in numberWords {
            if lowercased.contains(word) {
                return value
            }
        }
        
        // Then look for actual numbers
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 && $0 < 100 } // Reasonable range for bulk actions
        
        return numbers.first ?? 1
    }
    
    private func detectBulkItemType(from text: String) -> String {
        let content = text.lowercased()
        
        if content.contains("task") {
            return "tasks"
        } else if content.contains("event") {
            return "events"
        } else if content.contains("habit") {
            return "habits"
        } else if content.contains("goal") {
            return "goals"
        } else if content.contains("reminder") {
            return "reminders"
        } else if content.contains("appointment") || content.contains("meeting") {
            return "events"
        } else if content.contains("item") {
            return "items"
        }
        
        return "items" // Default
    }
    
    private enum CRUDOperation {
        case created(type: String, title: String)
        case updated(type: String, title: String)
        case deleted(type: String, title: String)
        case bulk(action: String, count: Int, type: String)
    }
    
    @ViewBuilder
    private func renderCRUDCard(for operation: CRUDOperation) -> some View {
        switch operation {
        case .created(let type, let title):
            CreatedItemCard(
                itemType: type,
                itemTitle: title,
                itemDescription: extractDescription(from: message.content),
                timestamp: message.timestamp,
                categoryColor: extractCategoryColor()
            )
            
        case .updated(let type, let title):
            UpdatedItemCard(
                itemType: type,
                itemTitle: title,
                changes: extractChanges(from: message.content),
                timestamp: message.timestamp
            )
            
        case .deleted(let type, let title):
            DeletedItemCard(
                itemType: type,
                itemTitle: title,
                reason: nil,
                timestamp: message.timestamp
            )
            
        case .bulk(let action, let count, let type):
            BulkActionCard(
                action: action,
                itemCount: count,
                itemType: type,
                details: extractBulkDetails(from: message.content)
            )
        }
    }
    
    private func extractDescription(from text: String) -> String? {
        // Extract description after colon or dash
        if let colonIndex = text.firstIndex(of: ":") {
            let afterColon = text[text.index(after: colonIndex)...]
            return String(afterColon).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func extractCategoryColor() -> Color? {
        // Check if message mentions a category
        if message.content.lowercased().contains("work") {
            return .blue
        } else if message.content.lowercased().contains("personal") {
            return .purple
        } else if message.content.lowercased().contains("health") {
            return .green
        }
        return nil
    }
    
    private func extractChanges(from text: String) -> [String: (old: String, new: String)] {
        // Simple extraction - could be enhanced
        var changes: [String: (old: String, new: String)] = [:]
        
        if text.contains("title") {
            changes["title"] = (old: "Old Title", new: extractTitle(from: text))
        }
        if text.contains("date") || text.contains("time") {
            changes["date"] = (old: "Previous Date", new: "New Date")
        }
        if text.contains("priority") {
            changes["priority"] = (old: "Medium", new: "High")
        }
        
        return changes
    }
    
    private func extractBulkDetails(from text: String) -> [String] {
        // Extract item titles or descriptions
        var details: [String] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for bullet points
            if trimmed.starts(with: "•") || trimmed.starts(with: "-") || 
               trimmed.starts(with: "*") || trimmed.starts(with: "→") {
                let cleaned = trimmed
                    .replacingOccurrences(of: "•", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "*", with: "")
                    .replacingOccurrences(of: "→", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty && cleaned.count > 2 {
                    details.append(cleaned)
                }
            }
            // Check for numbered lists
            else if let range = trimmed.range(of: "^\\d+[\\.\\)]", options: .regularExpression) {
                let cleaned = trimmed[range.upperBound...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty && cleaned.count > 2 {
                    details.append(String(cleaned))
                }
            }
            // Check for quoted items
            else if trimmed.contains("\"") {
                if let firstQuote = trimmed.firstIndex(of: "\""),
                   let lastQuote = trimmed.lastIndex(of: "\""),
                   firstQuote < lastQuote {
                    let startIndex = trimmed.index(after: firstQuote)
                    let endIndex = lastQuote
                    let extracted = String(trimmed[startIndex..<endIndex])
                    if !extracted.isEmpty && extracted.count > 2 {
                        details.append(extracted)
                    }
                }
            }
        }
        
        // If no details found but we detected bulk action, try to extract from content
        if details.isEmpty && text.lowercased().contains("follow") {
            // Look for "the following" pattern
            if let colonIndex = text.firstIndex(of: ":") {
                let afterColon = String(text[text.index(after: colonIndex)...])
                let items = afterColon.components(separatedBy: ",")
                for item in items {
                    let cleaned = item.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "and", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty && cleaned.count > 2 {
                        details.append(cleaned)
                    }
                }
            }
        }
        
        return details
    }
}