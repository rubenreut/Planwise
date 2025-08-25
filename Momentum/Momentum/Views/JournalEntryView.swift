import SwiftUI
import CoreData

struct JournalEntryView: View {
    let entity: Any // Can be Habit, Goal, Task, or Event
    @State private var journalText: String = ""
    @State private var selectedMood: Int = 3
    @State private var showingAllEntries = false
    @EnvironmentObject private var journalManager: JournalManager
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    private var entityName: String {
        switch entity {
        case let habit as Habit:
            return habit.name ?? "Habit"
        case let goal as Goal:
            return goal.title ?? "Goal"
        case let task as Task:
            return task.title ?? "Task"
        case let event as Event:
            return event.title ?? "Event"
        default:
            return "Entry"
        }
    }
    
    private var entityColor: Color {
        switch entity {
        case let habit as Habit:
            return Color(hex: habit.colorHex ?? "#007AFF")
        case let goal as Goal:
            return Color(hex: goal.colorHex ?? "#007AFF")
        case let event as Event:
            return Color(hex: event.colorHex ?? "#007AFF")
        case let task as Task:
            return task.category?.colorHex != nil ? Color(hex: task.category!.colorHex!) : .accentColor
        default:
            return .accentColor
        }
    }
    
    private var entityIcon: String {
        switch entity {
        case let habit as Habit:
            return habit.iconName ?? "star.fill"
        case let goal as Goal:
            return goal.iconName ?? "target"
        case let event as Event:
            return event.iconName ?? "calendar"
        case is Task:
            return "checkmark.circle"
        default:
            return "book.fill"
        }
    }
    
    private var existingEntry: JournalEntry? {
        switch entity {
        case let habit as Habit:
            return journalManager.todayEntry(for: habit)
        case let goal as Goal:
            return journalManager.todayEntry(for: goal)
        case let task as Task:
            return journalManager.todayEntry(for: task)
        case let event as Event:
            return journalManager.todayEntry(for: event)
        default:
            return nil
        }
    }
    
    private var allEntries: [JournalEntry] {
        switch entity {
        case let habit as Habit:
            return journalManager.entriesFor(habit: habit)
        case let goal as Goal:
            return journalManager.entriesFor(goal: goal)
        case let task as Task:
            return journalManager.entriesFor(task: task)
        case let event as Event:
            return journalManager.entriesFor(event: event)
        default:
            return []
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(entityColor.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: entityIcon)
                                    .scaledFont(size: 32)
                                    .foregroundColor(entityColor)
                            }
                            
                            Text(entityName)
                                .scaledFont(size: 24, weight: .bold)
                            
                            Text("Today's Journal Entry")
                                .scaledFont(size: 14, weight: .medium)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        
                        // Mood selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How are you feeling?")
                                .scaledFont(size: 14, weight: .semibold)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(1...5, id: \.self) { mood in
                                    Button {
                                        selectedMood = mood
                                        HapticFeedback.light.trigger()
                                    } label: {
                                        Text(moodEmoji(for: mood))
                                            .scaledFont(size: 28)
                                            .scaleEffect(selectedMood == mood ? 1.2 : 1.0)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedMood)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                            )
                        }
                        .padding(.horizontal)
                        
                        // Journal text entry
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Journal Entry")
                                .scaledFont(size: 14, weight: .semibold)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $journalText)
                                .focused($isTextFieldFocused)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                                )
                                .frame(minHeight: 150)
                        }
                        .padding(.horizontal)
                        
                        // Previous entries button
                        if !allEntries.isEmpty {
                            Button {
                                showingAllEntries = true
                            } label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .scaledFont(size: 16)
                                    Text("View All Entries (\(allEntries.count))")
                                        .scaledFont(size: 16, weight: .medium)
                                }
                                .foregroundColor(entityColor)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(entityColor.opacity(0.1))
                                )
                            }
                        }
                        
                        Spacer(minLength: 80)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .disabled(journalText.isEmpty)
                }
            }
            .sheet(isPresented: $showingAllEntries) {
                AllJournalEntriesView(entity: entity, entries: allEntries)
            }
        }
        .onAppear {
            loadExistingEntry()
            isTextFieldFocused = true
        }
    }
    
    private func loadExistingEntry() {
        if let entry = existingEntry {
            journalText = entry.content ?? ""
            selectedMood = Int(entry.mood)
        }
    }
    
    private func saveEntry() {
        switch entity {
        case let habit as Habit:
            journalManager.createOrUpdateEntry(
                for: habit,
                content: journalText,
                mood: Int16(selectedMood)
            )
        case let goal as Goal:
            journalManager.createOrUpdateEntry(
                for: goal,
                content: journalText,
                mood: Int16(selectedMood)
            )
        case let task as Task:
            journalManager.createOrUpdateEntry(
                for: task,
                content: journalText,
                mood: Int16(selectedMood)
            )
        case let event as Event:
            journalManager.createOrUpdateEntry(
                for: event,
                content: journalText,
                mood: Int16(selectedMood)
            )
        default:
            break
        }
        
        HapticFeedback.success.trigger()
        dismiss()
    }
    
    private func moodEmoji(for mood: Int) -> String {
        switch mood {
        case 1: return "😔"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😄"
        default: return "😐"
        }
    }
}

// MARK: - All Entries View
struct AllJournalEntriesView: View {
    let entity: Any
    let entries: [JournalEntry]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(formatDate(entry.entryDate ?? Date()))
                                .scaledFont(size: 14, weight: .semibold)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if entry.mood > 0 {
                                Text(moodEmoji(for: Int(entry.mood)))
                                    .scaledFont(size: 18)
                            }
                        }
                        
                        Text(entry.content ?? "")
                            .scaledFont(size: 15)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("All Journal Entries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func moodEmoji(for mood: Int) -> String {
        switch mood {
        case 1: return "😔"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😄"
        default: return "😐"
        }
    }
}