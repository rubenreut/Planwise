import Foundation
import CoreData
import SwiftUI

@MainActor
class JournalManager: ObservableObject {
    static let shared = JournalManager()
    
    @Published private(set) var journalEntries: [JournalEntry] = []
    
    private let persistence: any PersistenceProviding
    
    private init() {
        self.persistence = PersistenceController.shared
        fetchAllEntries()
    }
    
    init(persistence: any PersistenceProviding) {
        self.persistence = persistence
        fetchAllEntries()
    }
    
    // MARK: - Fetch Methods
    
    private func fetchAllEntries() {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \JournalEntry.entryDate, ascending: false),
            NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)
        ]
        
        do {
            journalEntries = try persistence.container.viewContext.fetch(request)
        } catch {
            print("Error fetching journal entries: \(error)")
        }
    }
    
    func entriesFor(habit: Habit) -> [JournalEntry] {
        journalEntries.filter { $0.habit == habit }
            .sorted { $0.entryDate! > $1.entryDate! }
    }
    
    func entriesFor(goal: Goal) -> [JournalEntry] {
        journalEntries.filter { $0.goal == goal }
            .sorted { $0.entryDate! > $1.entryDate! }
    }
    
    func entriesFor(task: Task) -> [JournalEntry] {
        journalEntries.filter { $0.task == task }
            .sorted { $0.entryDate! > $1.entryDate! }
    }
    
    func entriesFor(event: Event) -> [JournalEntry] {
        journalEntries.filter { $0.event == event }
            .sorted { $0.entryDate! > $1.entryDate! }
    }
    
    func todayEntry(for habit: Habit) -> JournalEntry? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return journalEntries.first { entry in
            guard entry.habit == habit,
                  let entryDate = entry.entryDate else { return false }
            return calendar.isDate(entryDate, inSameDayAs: today)
        }
    }
    
    func todayEntry(for goal: Goal) -> JournalEntry? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return journalEntries.first { entry in
            guard entry.goal == goal,
                  let entryDate = entry.entryDate else { return false }
            return calendar.isDate(entryDate, inSameDayAs: today)
        }
    }
    
    func todayEntry(for task: Task) -> JournalEntry? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return journalEntries.first { entry in
            guard entry.task == task,
                  let entryDate = entry.entryDate else { return false }
            return calendar.isDate(entryDate, inSameDayAs: today)
        }
    }
    
    func todayEntry(for event: Event) -> JournalEntry? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return journalEntries.first { entry in
            guard entry.event == event,
                  let entryDate = entry.entryDate else { return false }
            return calendar.isDate(entryDate, inSameDayAs: today)
        }
    }
    
    // MARK: - Create/Update Methods
    
    func createOrUpdateEntry(
        for habit: Habit,
        content: String,
        date: Date = Date(),
        mood: Int16? = nil,
        tags: [String]? = nil
    ) {
        let context = persistence.container.viewContext
        
        // Check if entry exists for today
        if let existingEntry = todayEntry(for: habit) {
            // Update existing entry
            existingEntry.content = content
            existingEntry.modifiedAt = Date()
            if let mood = mood {
                existingEntry.mood = mood
            }
            if let tags = tags {
                existingEntry.tags = tags.joined(separator: ",")
            }
        } else {
            // Create new entry
            let entry = JournalEntry(context: context)
            entry.id = UUID()
            entry.content = content
            entry.createdAt = Date()
            entry.modifiedAt = Date()
            entry.entryDate = Calendar.current.startOfDay(for: date)
            entry.entityType = "habit"
            entry.entityID = habit.id
            entry.habit = habit
            if let mood = mood {
                entry.mood = mood
            }
            if let tags = tags {
                entry.tags = tags.joined(separator: ",")
            }
        }
        
        do {
            try context.save()
            fetchAllEntries()
        } catch {
            print("Error saving journal entry: \(error)")
        }
    }
    
    func createOrUpdateEntry(
        for goal: Goal,
        content: String,
        date: Date = Date(),
        mood: Int16? = nil,
        tags: [String]? = nil
    ) {
        let context = persistence.container.viewContext
        
        // Check if entry exists for today
        if let existingEntry = todayEntry(for: goal) {
            // Update existing entry
            existingEntry.content = content
            existingEntry.modifiedAt = Date()
            if let mood = mood {
                existingEntry.mood = mood
            }
            if let tags = tags {
                existingEntry.tags = tags.joined(separator: ",")
            }
        } else {
            // Create new entry
            let entry = JournalEntry(context: context)
            entry.id = UUID()
            entry.content = content
            entry.createdAt = Date()
            entry.modifiedAt = Date()
            entry.entryDate = Calendar.current.startOfDay(for: date)
            entry.entityType = "goal"
            entry.entityID = goal.id
            entry.goal = goal
            if let mood = mood {
                entry.mood = mood
            }
            if let tags = tags {
                entry.tags = tags.joined(separator: ",")
            }
        }
        
        do {
            try context.save()
            fetchAllEntries()
        } catch {
            print("Error saving journal entry: \(error)")
        }
    }
    
    func createOrUpdateEntry(
        for task: Task,
        content: String,
        date: Date = Date(),
        mood: Int16? = nil,
        tags: [String]? = nil
    ) {
        let context = persistence.container.viewContext
        
        // Check if entry exists for today
        if let existingEntry = todayEntry(for: task) {
            // Update existing entry
            existingEntry.content = content
            existingEntry.modifiedAt = Date()
            if let mood = mood {
                existingEntry.mood = mood
            }
            if let tags = tags {
                existingEntry.tags = tags.joined(separator: ",")
            }
        } else {
            // Create new entry
            let entry = JournalEntry(context: context)
            entry.id = UUID()
            entry.content = content
            entry.createdAt = Date()
            entry.modifiedAt = Date()
            entry.entryDate = Calendar.current.startOfDay(for: date)
            entry.entityType = "task"
            entry.entityID = task.id
            entry.task = task
            if let mood = mood {
                entry.mood = mood
            }
            if let tags = tags {
                entry.tags = tags.joined(separator: ",")
            }
        }
        
        do {
            try context.save()
            fetchAllEntries()
        } catch {
            print("Error saving journal entry: \(error)")
        }
    }
    
    func createOrUpdateEntry(
        for event: Event,
        content: String,
        date: Date = Date(),
        mood: Int16? = nil,
        tags: [String]? = nil
    ) {
        let context = persistence.container.viewContext
        
        // Check if entry exists for today
        if let existingEntry = todayEntry(for: event) {
            // Update existing entry
            existingEntry.content = content
            existingEntry.modifiedAt = Date()
            if let mood = mood {
                existingEntry.mood = mood
            }
            if let tags = tags {
                existingEntry.tags = tags.joined(separator: ",")
            }
        } else {
            // Create new entry
            let entry = JournalEntry(context: context)
            entry.id = UUID()
            entry.content = content
            entry.createdAt = Date()
            entry.modifiedAt = Date()
            entry.entryDate = Calendar.current.startOfDay(for: date)
            entry.entityType = "event"
            entry.entityID = event.id
            entry.event = event
            if let mood = mood {
                entry.mood = mood
            }
            if let tags = tags {
                entry.tags = tags.joined(separator: ",")
            }
        }
        
        do {
            try context.save()
            fetchAllEntries()
        } catch {
            print("Error saving journal entry: \(error)")
        }
    }
    
    func deleteEntry(_ entry: JournalEntry) {
        let context = persistence.container.viewContext
        context.delete(entry)
        
        do {
            try context.save()
            fetchAllEntries()
        } catch {
            print("Error deleting journal entry: \(error)")
        }
    }
}