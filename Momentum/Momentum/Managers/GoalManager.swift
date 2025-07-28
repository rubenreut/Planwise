//
//  GoalManager.swift
//  Momentum
//
//  Manages goals, milestones, and progress tracking
//

import Foundation
import CoreData
import Combine

enum GoalType: String, CaseIterable {
    case milestone = "milestone"
    case numeric = "numeric"
    case habit = "habit"
    case project = "project"
    
    var displayName: String {
        switch self {
        case .milestone: return "Milestone Goal"
        case .numeric: return "Numeric Goal"
        case .habit: return "Habit-Based Goal"
        case .project: return "Project Goal"
        }
    }
    
    var icon: String {
        switch self {
        case .milestone: return "flag.checkered"
        case .numeric: return "chart.line.uptrend.xyaxis"
        case .habit: return "repeat.circle"
        case .project: return "folder.badge.checkmark"
        }
    }
}

enum GoalPriority: Int16, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"  
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#8E8E93"
        case .medium: return "#007AFF"
        case .high: return "#FF9500"
        case .critical: return "#FF3B30"
        }
    }
}

enum GoalUpdateType: String {
    case progress = "progress"
    case milestone = "milestone"
    case note = "note"
    case pause = "pause"
    case resume = "resume"
}

@MainActor
class GoalManager: ObservableObject {
    static let shared = GoalManager()
    
    @Published var goals: [Goal] = []
    @Published var activeGoals: [Goal] = []
    @Published var completedGoals: [Goal] = []
    
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadGoals()
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Listen for Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: persistenceController.container.viewContext)
            .sink { [weak self] _ in
                self?.loadGoals()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - CRUD Operations
    
    func createGoal(
        title: String,
        description: String? = nil,
        type: GoalType,
        targetValue: Double? = nil,
        targetDate: Date? = nil,
        unit: String? = nil,
        priority: GoalPriority = .medium,
        colorHex: String = "#007AFF",
        iconName: String = "target",
        category: Category? = nil,
        linkedHabits: [Habit] = []
    ) -> Result<Goal, Error> {
        // Check subscription limits
        if !SubscriptionManager.shared.canCreateGoal(currentCount: goals.count) {
            return .failure(ScheduleError.subscriptionLimitReached)
        }
        
        let context = persistenceController.container.viewContext
        
        let goal = Goal(context: context)
        goal.id = UUID()
        goal.title = title
        goal.desc = description
        goal.type = type.rawValue
        goal.targetValue = targetValue ?? 0
        goal.currentValue = 0
        goal.targetDate = targetDate
        goal.startDate = Date()
        goal.unit = unit
        goal.priority = priority.rawValue
        goal.colorHex = colorHex
        goal.iconName = iconName
        goal.isActive = true
        goal.isCompleted = false
        goal.createdAt = Date()
        goal.modifiedAt = Date()
        goal.category = category
        
        // Link habits if any
        for habit in linkedHabits {
            goal.addToLinkedHabits(habit)
        }
        
        do {
            try context.save()
            loadGoals()
            return .success(goal)
        } catch {
            return .failure(error)
        }
    }
    
    func updateGoal(_ goal: Goal) -> Result<Void, Error> {
        goal.modifiedAt = Date()
        
        do {
            try persistenceController.container.viewContext.save()
            loadGoals()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    func updateGoal(
        _ goal: Goal,
        title: String? = nil,
        description: String? = nil,
        targetValue: Double? = nil,
        targetDate: Date? = nil,
        unit: String? = nil,
        priority: GoalPriority? = nil,
        category: Category? = nil
    ) -> Result<Void, Error> {
        if let title = title {
            goal.title = title
        }
        if let description = description {
            goal.desc = description
        }
        if let targetValue = targetValue {
            goal.targetValue = targetValue
        }
        if let targetDate = targetDate {
            goal.targetDate = targetDate
        }
        if let unit = unit {
            goal.unit = unit
        }
        if let priority = priority {
            goal.priority = priority.rawValue
        }
        if let category = category {
            goal.category = category
        }
        
        return updateGoal(goal)
    }
    
    func deleteGoal(_ goal: Goal) -> Result<Void, Error> {
        let context = persistenceController.container.viewContext
        context.delete(goal)
        
        do {
            try context.save()
            loadGoals()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Progress Tracking
    
    func updateProgress(
        for goal: Goal,
        value: Double,
        notes: String? = nil
    ) -> Result<GoalUpdate, Error> {
        let context = persistenceController.container.viewContext
        
        let update = GoalUpdate(context: context)
        update.id = UUID()
        update.date = Date()
        update.value = value
        update.notes = notes
        update.type = GoalUpdateType.progress.rawValue
        update.goal = goal
        
        // Update current value
        goal.currentValue = value
        goal.modifiedAt = Date()
        
        // Check if goal is completed based on type
        switch goal.typeEnum {
        case .numeric, .habit:
            if goal.targetValue > 0 && value >= goal.targetValue {
                goal.isCompleted = true
                goal.completedDate = Date()
            }
        case .milestone, .project:
            // For milestone/project goals, check if all milestones are completed
            let milestones = goal.milestones?.allObjects as? [GoalMilestone] ?? []
            if !milestones.isEmpty {
                let allCompleted = milestones.allSatisfy { $0.isCompleted }
                if allCompleted {
                    goal.isCompleted = true
                    goal.completedDate = Date()
                }
            }
        }
        
        do {
            try context.save()
            loadGoals()
            return .success(update)
        } catch {
            return .failure(error)
        }
    }
    
    func addMilestone(
        to goal: Goal,
        title: String,
        targetValue: Double
    ) -> Result<GoalMilestone, Error> {
        let context = persistenceController.container.viewContext
        
        let milestone = GoalMilestone(context: context)
        milestone.id = UUID()
        milestone.title = title
        milestone.targetValue = targetValue
        milestone.isCompleted = false
        milestone.sortOrder = Int32((goal.milestones?.count ?? 0))
        milestone.goal = goal
        
        do {
            try context.save()
            loadGoals()
            return .success(milestone)
        } catch {
            return .failure(error)
        }
    }
    
    func completeMilestone(_ milestone: GoalMilestone) -> Result<Void, Error> {
        milestone.isCompleted = true
        milestone.completedDate = Date()
        
        // Create update record and check if goal is completed
        if let goal = milestone.goal {
            let context = persistenceController.container.viewContext
            let update = GoalUpdate(context: context)
            update.id = UUID()
            update.date = Date()
            update.value = milestone.targetValue
            update.type = GoalUpdateType.milestone.rawValue
            update.notes = "Completed milestone: \(milestone.title ?? "")"
            update.goal = goal
            
            // Update goal's modified date
            goal.modifiedAt = Date()
            
            // Check if all milestones are completed
            let milestones = goal.milestones?.allObjects as? [GoalMilestone] ?? []
            if !milestones.isEmpty {
                let allCompleted = milestones.allSatisfy { $0.isCompleted || $0 == milestone }
                if allCompleted {
                    goal.isCompleted = true
                    goal.completedDate = Date()
                }
            }
        }
        
        do {
            try persistenceController.container.viewContext.save()
            loadGoals()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    func deleteMilestone(_ milestone: GoalMilestone, from goal: Goal) -> Result<Void, Error> {
        let context = persistenceController.container.viewContext
        
        goal.removeFromMilestones(milestone)
        context.delete(milestone)
        
        do {
            try context.save()
            loadGoals()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    func saveContext() throws {
        if persistenceController.container.viewContext.hasChanges {
            try persistenceController.container.viewContext.save()
            loadGoals()
        }
    }
    
    // MARK: - Queries
    
    func loadGoals() {
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Goal.priority, ascending: false),
            NSSortDescriptor(keyPath: \Goal.createdAt, ascending: false)
        ]
        
        do {
            goals = try persistenceController.container.viewContext.fetch(request)
            activeGoals = goals.filter { $0.isActive && !$0.isCompleted }
            completedGoals = goals.filter { $0.isCompleted }
        } catch {
        }
    }
    
    func goals(for category: Category) -> [Goal] {
        return goals.filter { $0.category == category }
    }
    
    func upcomingDeadlines(days: Int = 7) -> [Goal] {
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        
        return activeGoals.filter { goal in
            guard let targetDate = goal.targetDate else { return false }
            return targetDate <= futureDate && targetDate >= Date()
        }.sorted { ($0.targetDate ?? Date()) < ($1.targetDate ?? Date()) }
    }
    
    // MARK: - Goal Completion
    
    func completeGoal(_ goal: Goal, notes: String? = nil) -> Result<Void, Error> {
        goal.isCompleted = true
        goal.completedDate = Date()
        goal.modifiedAt = Date()
        
        if let notes = notes {
            let context = persistenceController.container.viewContext
            let update = GoalUpdate(context: context)
            update.id = UUID()
            update.date = Date()
            update.value = goal.targetValue
            update.notes = notes
            update.type = GoalUpdateType.note.rawValue
            update.goal = goal
        }
        
        do {
            try persistenceController.container.viewContext.save()
            loadGoals()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Progress and Milestones
    
    func getProgress(for goal: Goal) -> (currentValue: Double, targetValue: Double, percentage: Double)? {
        let percentage = goal.progress
        return (currentValue: goal.currentValue, targetValue: goal.targetValue, percentage: percentage)
    }
    
    func addMilestone(to goal: Goal, title: String, targetValue: Double? = nil, targetDate: Date? = nil) -> Result<Void, Error> {
        let context = persistenceController.container.viewContext
        
        let milestone = GoalMilestone(context: context)
        milestone.id = UUID()
        milestone.title = title
        milestone.targetValue = targetValue ?? 0
        milestone.isCompleted = false
        milestone.sortOrder = Int32((goal.milestones?.count ?? 0))
        milestone.goal = goal
        
        do {
            try context.save()
            loadGoals()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Linking
    
    func linkHabit(_ habit: Habit, to goal: Goal) -> Result<Void, Error> {
        goal.addToLinkedHabits(habit)
        goal.modifiedAt = Date()
        
        do {
            try persistenceController.container.viewContext.save()
            loadGoals()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    func linkTask(_ task: Task, to goal: Goal) -> Result<Void, Error> {
        // Note: Goals don't have a direct relationship to Tasks in the Core Data model
        // This would need to be implemented differently if task linking is required
        return .failure(NSError(domain: "GoalManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Task linking not implemented in Core Data model"]))
    }
    
    // MARK: - Statistics
    
    func completionRate() -> Double {
        let total = goals.count
        guard total > 0 else { return 0 }
        
        let completed = completedGoals.count
        return Double(completed) / Double(total)
    }
    
    func averageCompletionTime() -> TimeInterval? {
        let completedWithDates = completedGoals.compactMap { goal -> TimeInterval? in
            guard let completedDate = goal.completedDate else { return nil }
            return completedDate.timeIntervalSince(goal.startDate ?? Date())
        }
        
        guard !completedWithDates.isEmpty else { return nil }
        
        let total = completedWithDates.reduce(0, +)
        return total / Double(completedWithDates.count)
    }
    
    func progressForGoal(_ goal: Goal) -> Double {
        guard goal.targetValue > 0 else { return 0 }
        return min(goal.currentValue / goal.targetValue, 1.0)
    }
    
    // MARK: - Habit Integration
    
    func syncWithHabits() {
        for goal in activeGoals {
            guard goal.type == GoalType.habit.rawValue else { continue }
            
            // Calculate progress based on linked habits
            let linkedHabits = goal.linkedHabits?.allObjects as? [Habit] ?? []
            var totalProgress: Double = 0
            
            for habit in linkedHabits {
                // Calculate habit completion rate
                let completions = habit.entries?.count ?? 0
                let daysSinceStart = Calendar.current.dateComponents([.day], from: goal.startDate ?? Date(), to: Date()).day ?? 1
                let expectedCompletions = Double(daysSinceStart) // Assuming daily habit
                
                let habitProgress = Double(completions) / max(expectedCompletions, 1)
                totalProgress += habitProgress
            }
            
            if !linkedHabits.isEmpty {
                let averageProgress = totalProgress / Double(linkedHabits.count)
                _ = updateProgress(for: goal, value: averageProgress * (goal.targetValue), notes: "Auto-synced from habits")
            }
        }
    }
}

// MARK: - Core Data Extensions

extension Goal {
    var typeEnum: GoalType {
        GoalType(rawValue: type ?? "") ?? .milestone
    }
    
    var priorityEnum: GoalPriority {
        GoalPriority(rawValue: priority) ?? .medium
    }
    
    var progress: Double {
        // If completed, always return 100%
        if isCompleted {
            return 1.0
        }
        
        switch typeEnum {
        case .numeric:
            // For numeric goals, use current/target value
            guard targetValue > 0 else { return 0 }
            return min(currentValue / targetValue, 1.0)
            
        case .milestone, .project:
            // For milestone/project goals, calculate based on completed milestones
            let milestones = self.milestones?.allObjects as? [GoalMilestone] ?? []
            guard !milestones.isEmpty else { return 0 }
            
            let completedCount = milestones.filter { $0.isCompleted }.count
            return Double(completedCount) / Double(milestones.count)
            
        case .habit:
            // For habit goals, use the current value which should be synced from habits
            guard targetValue > 0 else { return 0 }
            return min(currentValue / targetValue, 1.0)
        }
    }
    
    var daysRemaining: Int? {
        guard let targetDate = targetDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
        return max(days, 0)
    }
    
    var isOverdue: Bool {
        guard let targetDate = targetDate else { return false }
        return targetDate < Date() && !isCompleted
    }
    
    var sortedMilestones: [GoalMilestone] {
        let milestones = self.milestones?.allObjects as? [GoalMilestone] ?? []
        return milestones.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    var recentUpdates: [GoalUpdate] {
        let updates = self.updates?.allObjects as? [GoalUpdate] ?? []
        return updates.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }.prefix(10).map { $0 }
    }
}

extension GoalMilestone {
    var progress: Double {
        guard let goal = goal, goal.targetValue > 0 else { return 0 }
        return min(goal.currentValue / targetValue, 1.0)
    }
}