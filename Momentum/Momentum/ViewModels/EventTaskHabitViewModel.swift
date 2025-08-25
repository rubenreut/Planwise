import Foundation
import SwiftUI
import CoreData

/// Handles individual CRUD operations for events, tasks, habits, and goals
@MainActor
class EventTaskHabitViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var acceptedEventIds: Set<String> = []
    @Published var deletedEventIds: Set<String> = []
    @Published var isProcessingAction: Bool = false
    @Published var actionError: String?
    
    // MARK: - Dependencies
    
    private let scheduleManager: ScheduleManaging
    private let taskManager: TaskManaging
    private let habitManager: HabitManaging
    private let goalManager: GoalManager
    private let context: NSManagedObjectContext
    
    // MARK: - Initialization
    
    init(scheduleManager: ScheduleManaging,
         taskManager: TaskManaging,
         habitManager: HabitManaging,
         goalManager: GoalManager,
         context: NSManagedObjectContext) {
        self.scheduleManager = scheduleManager
        self.taskManager = taskManager
        self.habitManager = habitManager
        self.goalManager = goalManager
        self.context = context
    }
    
    // MARK: - Event Actions
    
    func handleEventAction(eventId: String, action: EventAction, preview: EventPreview? = nil) async {
        isProcessingAction = true
        actionError = nil
        
        switch action {
        case .complete:
            if preview != nil {
                // Create the event when completing/accepting
                acceptedEventIds.insert(eventId)
            }
        case .edit:
            // Handle edit - would typically show an edit view
            break
        case .delete:
            deleteEvent(eventId: eventId)
        case .viewFull:
            // Handle view full action
            break
        case .share:
            // Handle share action
            break
        default:
            break
        }
        
        isProcessingAction = false
    }
    
    private func acceptEvent(_ preview: EventPreview, eventId: String) async {
        acceptedEventIds.insert(eventId)
        
        // EventPreview has different properties than expected
        // Create event with available data from preview
        let calendar = Calendar.current
        let startTime = Date()
        let endTime = calendar.date(byAdding: .hour, value: 1, to: startTime) ?? startTime
        
        let _ = scheduleManager.createEvent(
            title: preview.title,
            startTime: startTime,
            endTime: endTime,
            category: nil,
            notes: nil,
            location: preview.location,
            isAllDay: false
        )
        
        // Save context
        do {
            try context.save()
        } catch {
            actionError = "Failed to save event: \(error.localizedDescription)"
        }
        
        // Navigate to the date if needed
        NotificationCenter.default.post(
            name: Notification.Name("NavigateToDate"),
            object: nil,
            userInfo: ["date": startTime, "eventId": eventId]
        )
    }
    
    private func deleteEvent(eventId: String) {
        deletedEventIds.insert(eventId)
        
        if let event = scheduleManager.events.first(where: { $0.id?.uuidString == eventId }) {
            _ = scheduleManager.deleteEvent(event)
            
            do {
                try context.save()
            } catch {
                actionError = "Failed to delete event: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Task Actions
    
    func createTask(title: String, notes: String? = nil, dueDate: Date? = nil, priority: TaskPriority = .medium, categoryId: UUID? = nil) async -> UUID? {
        isProcessingAction = true
        actionError = nil
        
        // Create task with available parameters
        let result = taskManager.createTask(
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            category: nil,
            tags: [],
            estimatedDuration: nil,
            scheduledTime: nil,
            linkedEvent: nil
        )
        
        switch result {
        case .success(let task):
            isProcessingAction = false
            return task.id
        case .failure(let error):
            actionError = "Failed to create task: \(error.localizedDescription)"
            isProcessingAction = false
            return nil
        }
    }
    
    func updateTask(taskId: UUID, title: String? = nil, notes: String? = nil, dueDate: Date? = nil, priority: TaskPriority? = nil, isCompleted: Bool? = nil) async {
        isProcessingAction = true
        actionError = nil
        
        // Find the task first
        guard let task = taskManager.tasks.first(where: { $0.id == taskId }) else {
            actionError = "Task not found"
            isProcessingAction = false
            return
        }
        
        // Update task with available parameters
        let result = taskManager.updateTask(
            task,
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: priority ?? TaskPriority(rawValue: task.priority) ?? .medium,
            category: nil,
            tags: [],
            estimatedDuration: nil,
            scheduledTime: nil,
            linkedEvent: nil,
            parentTask: nil
        )
        
        if case .failure(let error) = result {
            actionError = "Failed to update task: \(error.localizedDescription)"
        }
        
        // Handle completion status if provided
        if let isCompleted = isCompleted {
            let completionResult = isCompleted ? taskManager.completeTask(task) : taskManager.uncompleteTask(task)
            if case .failure(let error) = completionResult {
                actionError = "Failed to update completion status: \(error.localizedDescription)"
            }
        }
        
        isProcessingAction = false
    }
    
    func deleteTask(taskId: UUID) async {
        isProcessingAction = true
        actionError = nil
        
        // Find and delete task
        if let task = taskManager.tasks.first(where: { $0.id == taskId }) {
            let result = taskManager.deleteTask(task)
            if case .failure(let error) = result {
                actionError = "Failed to delete task: \(error.localizedDescription)"
            }
        } else {
            actionError = "Task not found"
        }
        
        isProcessingAction = false
    }
    
    func toggleTaskCompletion(taskId: UUID) async {
        isProcessingAction = true
        
        // Toggle task completion
        if let task = taskManager.tasks.first(where: { $0.id == taskId }) {
            let result = task.isCompleted ? taskManager.uncompleteTask(task) : taskManager.completeTask(task)
            if case .failure(let error) = result {
                actionError = "Failed to toggle task completion: \(error.localizedDescription)"
            }
        } else {
            actionError = "Task not found"
        }
        
        isProcessingAction = false
    }
    
    // MARK: - Habit Actions
    
    func createHabit(name: String, targetCount: Int? = nil, frequency: HabitFrequency = .daily, reminderTime: Date? = nil, color: String? = nil, icon: String? = nil) async -> Habit? {
        isProcessingAction = true
        actionError = nil
        
        let result = habitManager.createHabit(
            name: name,
            icon: icon ?? "star",
            color: color ?? "blue",
            frequency: frequency,
            trackingType: .binary,  // Use binary instead of checkbox
            goalTarget: targetCount != nil ? Double(targetCount!) : nil,
            goalUnit: targetCount != nil ? "times" : nil,
            category: nil,
            notes: nil
        )
        
        switch result {
        case .success(let habit):
            isProcessingAction = false
            return habit
        case .failure(let error):
            actionError = "Failed to create habit: \(error.localizedDescription)"
            isProcessingAction = false
            return nil
        }
    }
    
    func updateHabit(_ habit: Habit, name: String? = nil, targetCount: Int? = nil, frequency: HabitFrequency? = nil, reminderTime: Date? = nil) {
        isProcessingAction = true
        actionError = nil
        
        // Update habit properties if provided
        if let name = name {
            habit.name = name
        }
        if let targetCount = targetCount {
            habit.goalTarget = Double(targetCount)
        }
        if let frequency = frequency {
            habit.frequency = frequency.rawValue
        }
        if let reminderTime = reminderTime {
            habit.reminderTime = reminderTime
        }
        
        let result = habitManager.updateHabit(habit)
        
        if case .failure(let error) = result {
            actionError = "Failed to update habit: \(error.localizedDescription)"
        }
        
        isProcessingAction = false
    }
    
    func deleteHabit(_ habit: Habit) {
        isProcessingAction = true
        actionError = nil
        
        let result = habitManager.deleteHabit(habit)
        
        if case .failure(let error) = result {
            actionError = "Failed to delete habit: \(error.localizedDescription)"
        }
        
        isProcessingAction = false
    }
    
    func logHabitCompletion(_ habit: Habit, date: Date = Date()) {
        // Log completion through habit manager
        let result = habitManager.logHabit(
            habit,
            value: 1.0,  // Binary completion
            date: date,
            notes: nil,
            mood: nil,
            duration: nil,
            quality: nil
        )
        
        if case .failure(let error) = result {
            actionError = "Failed to log habit completion: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Goal Actions
    
    func createGoal(title: String, description: String? = nil, targetDate: Date? = nil, category: String? = nil, milestones: [String] = []) async -> Goal? {
        isProcessingAction = true
        actionError = nil
        
        let result = goalManager.createGoal(
            title: title,
            description: description,
            type: .hybrid,
            targetValue: nil,
            targetDate: targetDate,
            unit: nil,
            priority: .medium,
            category: nil,  // Category needs to be Category type, not String
            linkedHabits: []
        )
        
        switch result {
        case .success(let goal):
            isProcessingAction = false
            return goal
        case .failure(let error):
            actionError = "Failed to create goal: \(error.localizedDescription)"
            isProcessingAction = false
            return nil
        }
    }
    
    func updateGoal(_ goal: Goal, title: String? = nil, description: String? = nil, targetDate: Date? = nil, progress: Float? = nil) {
        isProcessingAction = true
        actionError = nil
        
        // Update using GoalManager's method
        let result = goalManager.updateGoal(
            goal,
            title: title,
            description: description,
            targetValue: progress != nil ? Double(progress!) * 100 : nil,  // Convert progress to targetValue
            targetDate: targetDate,
            unit: nil,
            priority: nil,
            category: nil,
            updateCategory: false
        )
        
        if case .failure(let error) = result {
            actionError = "Failed to update goal: \(error.localizedDescription)"
        }
        
        isProcessingAction = false
    }
    
    func deleteGoal(_ goal: Goal) async {
        isProcessingAction = true
        actionError = nil
        
        let result = goalManager.deleteGoal(goal)
        
        if case .failure(let error) = result {
            actionError = "Failed to delete goal: \(error.localizedDescription)"
        }
        
        isProcessingAction = false
    }
    
    func updateGoalProgress(_ goal: Goal, progress: Float) {
        // Update the goal's current value based on progress percentage
        goal.currentValue = Double(progress) * goal.targetValue
        goal.modifiedAt = Date()
        
        let result = goalManager.updateGoal(goal)
        
        if case .failure(let error) = result {
            actionError = "Failed to update goal progress: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Methods
    
    func isEventAccepted(_ eventId: String) -> Bool {
        acceptedEventIds.contains(eventId)
    }
    
    func isEventDeleted(_ eventId: String) -> Bool {
        deletedEventIds.contains(eventId)
    }
    
    func resetActionState() {
        isProcessingAction = false
        actionError = nil
    }
}

// MARK: - Supporting Types
// Note: EventAction, EventPreview are already defined in the main app
// Note: TaskPriority is defined in TaskManager
// Note: HabitFrequency is defined in HabitManager