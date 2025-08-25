//
//  HabitManager.swift
//  Momentum
//
//  Created by Claude on [Date]
//  Epic habit tracking system - best in class
//

import Foundation
import CoreData
import SwiftUI
import CoreLocation

// MARK: - Enums

enum HabitFrequency: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"  
        case .custom: return "Custom"
        }
    }
}

enum HabitTrackingType: String, CaseIterable {
    case binary = "binary"          // Yes/No
    case quantity = "quantity"      // Number (glasses of water, pages read)
    case duration = "duration"      // Minutes/hours
    case quality = "quality"        // 1-5 scale
    
    var displayName: String {
        switch self {
        case .binary: return "Yes/No"
        case .quantity: return "Amount"
        case .duration: return "Time"
        case .quality: return "Quality"
        }
    }
    
    var defaultUnit: String? {
        switch self {
        case .binary, .quality: return nil
        case .quantity: return "times"
        case .duration: return "minutes"
        }
    }
}

// MARK: - Protocol

protocol HabitManaging: AnyObject {
    var habits: [Habit] { get }
    
    // CRUD Operations
    func createHabit(
        name: String,
        icon: String,
        color: String,
        frequency: HabitFrequency,
        trackingType: HabitTrackingType,
        goalTarget: Double?,
        goalUnit: String?,
        category: Category?,
        notes: String?
    ) -> Result<Habit, ScheduleError>
    
    func createMultipleHabits(_ habitDataArray: [(
        name: String,
        icon: String,
        color: String,
        frequency: HabitFrequency,
        trackingType: HabitTrackingType,
        goalTarget: Double?,
        goalUnit: String?,
        category: Category?,
        notes: String?
    )]) -> Result<[Habit], ScheduleError>
    
    func updateHabit(_ habit: Habit) -> Result<Void, ScheduleError>
    func deleteHabit(_ habit: Habit) -> Result<Void, ScheduleError>
    
    // Entry Management
    func logHabit(
        _ habit: Habit,
        value: Double,
        date: Date,
        notes: String?,
        mood: Int16?,
        duration: Int32?,
        quality: Int16?
    ) -> Result<HabitEntry, ScheduleError>
    
    func deleteEntry(_ entry: HabitEntry) -> Result<Void, ScheduleError>
    
    // Query Methods
    func habitsForToday() -> [Habit]
    func habitsForDate(_ date: Date) -> [Habit]
    func entriesForHabit(_ habit: Habit, in range: ClosedRange<Date>) -> [HabitEntry]
    func todayProgress() -> (completed: Int, total: Int, percentage: Double)
    
    // Streak Management
    func updateStreaks()
    func getStreakInfo(for habit: Habit) -> (current: Int32, best: Int32, safetyNetActive: Bool)
    
    // Analytics & Insights
    func calculateCorrelations(for habit: Habit)
    func getInsights(for habit: Habit) -> [String]
    func getMoodCorrelation(for habit: Habit) -> Double?
}

// MARK: - HabitManager

@MainActor
class HabitManager: NSObject, ObservableObject, @preconcurrency HabitManaging {
    
    // MARK: - Singleton
    
    static let shared = HabitManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var habits: [Habit] = []
    @Published private(set) var todayEntries: [HabitEntry] = []
    @Published private(set) var insights: [UUID: [String]] = [:]
    
    // MARK: - Private Properties
    
    private let persistence: PersistenceProviding
    private var fetchedResultsController: NSFetchedResultsController<Habit>?
    private let locationManager = CLLocationManager()
    
    // Cache for performance
    private var entryCache: [UUID: [HabitEntry]] = [:]
    private let cacheLock = NSLock()
    
    // MARK: - Initialization
    
    private init(persistence: PersistenceProviding? = nil) {
        self.persistence = persistence ?? PersistenceController.shared
        super.init()
        setupFetchedResultsController()
        loadHabits()
        updateStreaks()
    }
    
    // MARK: - Setup
    
    private func setupFetchedResultsController() {
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Habit.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Habit.name, ascending: true)
        ]
        request.predicate = NSPredicate(format: "isActive == YES")
        // Prefetch relationships to avoid faulting
        request.relationshipKeyPathsForPrefetching = ["category", "entries"]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: persistence.container.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        fetchedResultsController?.delegate = self
    }
    
    private func loadHabits() {
        do {
            try fetchedResultsController?.performFetch()
            habits = fetchedResultsController?.fetchedObjects ?? []
            objectWillChange.send()
        } catch {
        }
    }
    
    // MARK: - CRUD Operations
    
    func createHabit(
        name: String,
        icon: String = "star.fill",
        color: String = "#FF6B6B",
        frequency: HabitFrequency = .daily,
        trackingType: HabitTrackingType = .binary,
        goalTarget: Double? = nil,
        goalUnit: String? = nil,
        category: Category? = nil,
        notes: String? = nil
    ) -> Result<Habit, ScheduleError> {
        // Check subscription limits
        if !SubscriptionManager.shared.canCreateHabit(currentCount: habits.count) {
            return .failure(.subscriptionLimitReached)
        }
        
        let context = persistence.container.viewContext
        
        let habit = Habit(context: context)
        habit.id = UUID()
        habit.name = name
        habit.iconName = icon
        habit.colorHex = color
        habit.frequency = frequency.rawValue
        habit.trackingType = trackingType.rawValue
        habit.goalTarget = goalTarget ?? 1.0
        habit.goalUnit = goalUnit ?? trackingType.defaultUnit
        habit.category = category
        habit.notes = notes
        habit.createdAt = Date()
        habit.modifiedAt = Date()
        habit.isActive = true
        habit.currentStreak = 0
        habit.bestStreak = 0
        habit.totalCompletions = 0
        habit.sortOrder = Int32(habits.count)
        
        do {
            try persistence.save()
            clearCache()
            return .success(habit)
        } catch {
            return .failure(.saveFailed)
        }
    }
    
    func createMultipleHabits(_ habitDataArray: [(
        name: String,
        icon: String,
        color: String,
        frequency: HabitFrequency,
        trackingType: HabitTrackingType,
        goalTarget: Double?,
        goalUnit: String?,
        category: Category?,
        notes: String?
    )]) -> Result<[Habit], ScheduleError> {
        let context = persistence.container.viewContext
        var createdHabits: [Habit] = []
        let startingSortOrder = Int32(habits.count)
        
        for (index, habitData) in habitDataArray.enumerated() {
            let habit = Habit(context: context)
            habit.id = UUID()
            habit.name = habitData.name
            habit.iconName = habitData.icon
            habit.colorHex = habitData.color
            habit.frequency = habitData.frequency.rawValue
            habit.trackingType = habitData.trackingType.rawValue
            habit.goalTarget = habitData.goalTarget ?? 1.0
            habit.goalUnit = habitData.goalUnit ?? habitData.trackingType.defaultUnit
            habit.category = habitData.category
            habit.notes = habitData.notes
            habit.createdAt = Date()
            habit.modifiedAt = Date()
            habit.isActive = true
            habit.currentStreak = 0
            habit.bestStreak = 0
            habit.totalCompletions = 0
            habit.sortOrder = startingSortOrder + Int32(index)
            
            createdHabits.append(habit)
        }
        
        do {
            try persistence.save()
            clearCache()
            return .success(createdHabits)
        } catch {
            // Roll back all habits if save fails
            for habit in createdHabits {
                context.delete(habit)
            }
            return .failure(.saveFailed)
        }
    }
    
    func updateHabit(_ habit: Habit) -> Result<Void, ScheduleError> {
        habit.modifiedAt = Date()
        
        do {
            try persistence.save()
            clearCache()
            updateStreaks()
            return .success(())
        } catch {
            return .failure(.saveFailed)
        }
    }
    
    func deleteHabit(_ habit: Habit) -> Result<Void, ScheduleError> {
        let context = persistence.container.viewContext
        context.delete(habit)
        
        do {
            try persistence.save()
            clearCache()
            return .success(())
        } catch {
            return .failure(.deleteFailed)
        }
    }
    
    // MARK: - Entry Management
    
    func logHabit(
        _ habit: Habit,
        value: Double = 1.0,
        date: Date = Date(),
        notes: String? = nil,
        mood: Int16? = nil,
        duration: Int32? = nil,
        quality: Int16? = nil
    ) -> Result<HabitEntry, ScheduleError> {
        let context = persistence.container.viewContext
        
        // Check if entry already exists for this date
        let calendar = Calendar.current
        let _ = calendar.startOfDay(for: date)
        
        let existingEntry = habit.entries?.first { entry in
            guard let entry = entry as? HabitEntry,
                  let entryDate = entry.date else { return false }
            return calendar.isDate(entryDate, inSameDayAs: date)
        } as? HabitEntry
        
        let entry: HabitEntry
        if let existing = existingEntry {
            entry = existing
            entry.value = value
            entry.completedAt = Date()
        } else {
            entry = HabitEntry(context: context)
            entry.id = UUID()
            entry.habit = habit
            entry.date = date
            entry.completedAt = Date()
            entry.value = value
        }
        
        // Set optional values
        entry.notes = notes
        if let mood = mood { entry.mood = mood }
        if let duration = duration { entry.duration = duration }
        if let quality = quality { entry.quality = quality }
        
        // Get current location if available
        if CLLocationManager.locationServicesEnabled() &&
           locationManager.authorizationStatus == .authorizedWhenInUse {
            if let location = locationManager.location {
                entry.location = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
            }
        }
        
        // Update habit stats
        if existingEntry == nil {
            habit.totalCompletions += 1
            habit.lastCompletedDate = date
        }
        
        do {
            try persistence.save()
            clearCache()
            updateStreaks()
            
            // Calculate correlations in background
            _Concurrency.Task {
                calculateCorrelations(for: habit)
            }
            
            // Update linked goals progress
            updateLinkedGoalsProgress(for: habit)
            
            return .success(entry)
        } catch {
            return .failure(.saveFailed)
        }
    }
    
    func deleteEntry(_ entry: HabitEntry) -> Result<Void, ScheduleError> {
        if let habit = entry.habit {
            habit.totalCompletions = max(0, habit.totalCompletions - 1)
        }
        
        persistence.container.viewContext.delete(entry)
        
        do {
            try persistence.save()
            clearCache()
            updateStreaks()
            return .success(())
        } catch {
            return .failure(.deleteFailed)
        }
    }
    
    // MARK: - Query Methods
    
    func habitsForToday() -> [Habit] {
        habitsForDate(Date())
    }
    
    func habitsForDate(_ date: Date) -> [Habit] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        return habits.filter { habit in
            // Check if habit is paused
            if habit.isPaused {
                if let pausedUntil = habit.pausedUntil, pausedUntil > date {
                    return false
                } else {
                    // Unpause if pause period has ended
                    habit.isPaused = false
                    habit.pausedUntil = nil
                }
            }
            
            switch HabitFrequency(rawValue: habit.frequency ?? "daily") {
            case .daily:
                return true
            case .weekly:
                let targetDays = habit.weeklyTarget
                let completedThisWeek = getWeeklyCompletionCount(for: habit, date: date)
                return Int16(completedThisWeek) < targetDays
            case .custom:
                // Parse custom frequency days (e.g., "1,3,5" for Mon, Wed, Fri)
                guard let frequencyDays = habit.frequencyDays else { return true }
                let days = frequencyDays.split(separator: ",").compactMap { Int($0) }
                return days.contains(weekday)
            case .none:
                return true
            }
        }
    }
    
    func entriesForHabit(_ habit: Habit, in range: ClosedRange<Date>) -> [HabitEntry] {
        // Check cache first
        cacheLock.lock()
        if let cached = entryCache[habit.id ?? UUID()] {
            cacheLock.unlock()
            return cached.filter { entry in
                guard let date = entry.date else { return false }
                return range.contains(date)
            }
        }
        cacheLock.unlock()
        
        // Fetch from Core Data
        let request: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date <= %@",
            habit, range.lowerBound as NSDate, range.upperBound as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \HabitEntry.date, ascending: false)]
        
        do {
            let entries = try persistence.container.viewContext.fetch(request)
            
            // Update cache
            cacheLock.lock()
            entryCache[habit.id ?? UUID()] = entries
            cacheLock.unlock()
            
            return entries
        } catch {
            return []
        }
    }
    
    func todayProgress() -> (completed: Int, total: Int, percentage: Double) {
        let todayHabits = habitsForToday()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let completed = todayHabits.filter { habit in
            habit.entries?.contains { entry in
                guard let entry = entry as? HabitEntry,
                      let date = entry.date else { return false }
                return calendar.isDate(date, inSameDayAs: today) && !entry.skipped
            } ?? false
        }.count
        
        let total = todayHabits.count
        let percentage = total > 0 ? Double(completed) / Double(total) : 0
        
        return (completed, total, percentage)
    }
    
    // MARK: - Streak Management
    
    func updateStreaks() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for habit in habits {
            var currentStreak: Int32 = 0
            var checkDate = today
            var missedDays = 0
            let maxMissedDays = habit.streakSafetyNet ? 1 : 0
            
            // Work backwards from today
            while true {
                let hasEntry = habit.entries?.contains { entry in
                    guard let entry = entry as? HabitEntry,
                          let date = entry.date else { return false }
                    return calendar.isDate(date, inSameDayAs: checkDate) && !entry.skipped
                } ?? false
                
                if hasEntry {
                    currentStreak += 1
                    missedDays = 0
                } else {
                    // Check if this date should have had an entry
                    if shouldHaveEntry(for: habit, on: checkDate) {
                        missedDays += 1
                        if missedDays > maxMissedDays {
                            break
                        }
                    }
                }
                
                // Move to previous day
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDay
                
                // Don't count before habit was created
                if checkDate < (habit.createdAt ?? Date()) {
                    break
                }
            }
            
            habit.currentStreak = currentStreak
            if currentStreak > habit.bestStreak {
                habit.bestStreak = currentStreak
            }
        }
        
        // Save changes
        do {
            try persistence.save()
        } catch {
        }
    }
    
    func getStreakInfo(for habit: Habit) -> (current: Int32, best: Int32, safetyNetActive: Bool) {
        (habit.currentStreak, habit.bestStreak, habit.streakSafetyNet)
    }
    
    // MARK: - Analytics & Insights
    
    func calculateCorrelations(for habit: Habit) {
        // This would run complex correlation analysis
        // For now, we'll implement basic mood correlation
        
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let entries = entriesForHabit(habit, in: thirtyDaysAgo...Date())
        
        guard entries.count >= 7 else { return } // Need minimum data
        
        // Calculate average mood on days with/without habit
        let daysWithHabit = entries.filter { !$0.skipped }
        let avgMoodWithHabit = daysWithHabit.compactMap { $0.mood }.map(Double.init).reduce(0, +) / Double(daysWithHabit.count)
        
        // Store correlation
        let context = persistence.container.viewContext
        let correlation = HabitCorrelation(context: context)
        correlation.id = UUID()
        correlation.sourceHabit = habit
        correlation.targetMetric = "mood"
        correlation.correlationScore = avgMoodWithHabit / 5.0 // Normalize to 0-1
        correlation.confidence = min(Double(entries.count) / 30.0, 1.0)
        correlation.sampleSize = Int32(entries.count)
        correlation.calculatedAt = Date()
        
        if avgMoodWithHabit > 3.5 {
            correlation.insight = "You tend to feel better on days you complete this habit! 🎉"
        } else if avgMoodWithHabit < 2.5 {
            correlation.insight = "This habit might need adjustment - your mood is lower on these days."
        }
        
        do {
            try persistence.save()
        } catch {
        }
    }
    
    func getInsights(for habit: Habit) -> [String] {
        var insights: [String] = []
        
        // Streak insights
        if habit.currentStreak >= 7 {
            insights.append("🔥 You're on fire! \(habit.currentStreak) day streak!")
        }
        
        if habit.currentStreak == habit.bestStreak && habit.bestStreak > 0 {
            insights.append("🏆 This is your best streak ever!")
        }
        
        // Completion insights
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekEntries = entriesForHabit(habit, in: lastWeek...Date())
        let completionRate = Double(weekEntries.count) / 7.0
        
        if completionRate >= 0.9 {
            insights.append("💪 Nearly perfect week! \(Int(completionRate * 100))% completion rate")
        } else if completionRate < 0.5 {
            insights.append("📈 Room for improvement - only \(Int(completionRate * 100))% this week")
        }
        
        // Time-based insights
        if let _ = habit.lastCompletedDate {
            let hourFormatter = DateFormatter()
            hourFormatter.dateFormat = "ha"
            
            let completionHours = weekEntries.compactMap { $0.completedAt }
                .map { Calendar.current.component(.hour, from: $0) }
            
            if let mostCommonHour = mostFrequent(in: completionHours) {
                insights.append("⏰ You usually complete this around \(mostCommonHour):00")
            }
        }
        
        // Correlation insights
        if let correlations = habit.correlations?.allObjects as? [HabitCorrelation] {
            for correlation in correlations where correlation.confidence > 0.7 {
                if let insight = correlation.insight {
                    insights.append(insight)
                }
            }
        }
        
        return insights
    }
    
    func getMoodCorrelation(for habit: Habit) -> Double? {
        guard let correlations = habit.correlations?.allObjects as? [HabitCorrelation] else { return nil }
        
        let moodCorrelation = correlations.first { $0.targetMetric == "mood" }
        return moodCorrelation?.correlationScore
    }
    
    // MARK: - Helper Methods
    
    private func clearCache() {
        cacheLock.lock()
        entryCache.removeAll()
        cacheLock.unlock()
    }
    
    private func updateLinkedGoalsProgress(for habit: Habit) {
        // Get all goals linked to this habit
        guard let linkedGoals = habit.linkedGoals?.allObjects as? [Goal] else { return }
        
        for goal in linkedGoals where goal.typeEnum == .habit && !goal.isCompleted {
            // Calculate habit progress
            let calendar = Calendar.current
            let daysSinceStart = calendar.dateComponents([.day], from: goal.startDate ?? Date(), to: Date()).day ?? 1
            let completionCount = habit.entries?.count ?? 0
            
            // Calculate completion rate (0-1)
            let completionRate = Double(completionCount) / max(Double(daysSinceStart), 1.0)
            
            // Update goal progress based on habit completion rate
            let progressValue = min(completionRate * (goal.targetValue), goal.targetValue)
            
            // Update the goal's current value
            goal.currentValue = progressValue
            goal.modifiedAt = Date()
            
            // Check if goal is completed
            if progressValue >= goal.targetValue {
                goal.isCompleted = true
                goal.completedDate = Date()
            }
            
            // Save changes
            do {
                try persistence.save()
                
                // Post notification for UI updates
                NotificationCenter.default.post(
                    name: Notification.Name("GoalProgressUpdated"),
                    object: nil,
                    userInfo: ["goalId": goal.id ?? UUID()]
                )
            } catch {
                print("Failed to update linked goal progress: \(error)")
            }
        }
    }
    
    private func shouldHaveEntry(for habit: Habit, on date: Date) -> Bool {
        // Check if habit should have been completed on this date
        let habitsForDate = self.habitsForDate(date)
        return habitsForDate.contains(habit)
    }
    
    private func getWeeklyCompletionCount(for habit: Habit, date: Date) -> Int {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return 0 }
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? date
        
        let entries = entriesForHabit(habit, in: weekStart...weekEnd)
        return entries.filter { !$0.skipped }.count
    }
    
    private func mostFrequent<T: Hashable>(in array: [T]) -> T? {
        let counts = array.reduce(into: [:]) { counts, element in
            counts[element, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension HabitManager: NSFetchedResultsControllerDelegate {
    nonisolated func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        _Concurrency.Task { 
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.habits = self.fetchedResultsController?.fetchedObjects ?? []
                self.objectWillChange.send()
            }
        }
    }
}

// MARK: - Extensions

extension Habit {
    var frequencyEnum: HabitFrequency {
        HabitFrequency(rawValue: frequency ?? "daily") ?? .daily
    }
    
    var trackingTypeEnum: HabitTrackingType {
        HabitTrackingType(rawValue: trackingType ?? "binary") ?? .binary
    }
    
    var isCompletedToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return entries?.contains { entry in
            guard let entry = entry as? HabitEntry,
                  let date = entry.date else { return false }
            return calendar.isDate(date, inSameDayAs: today) && !entry.skipped
        } ?? false
    }
    
    var todayEntry: HabitEntry? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return entries?.first { entry in
            guard let entry = entry as? HabitEntry,
                  let date = entry.date else { return false }
            return calendar.isDate(date, inSameDayAs: today)
        } as? HabitEntry
    }
    
    var progressToday: Double {
        guard let entry = todayEntry else { return 0 }
        
        switch trackingTypeEnum {
        case .binary:
            return entry.skipped ? 0 : 1
        case .quantity, .duration:
            return min(entry.value / goalTarget, 1.0)
        case .quality:
            return entry.value / 5.0
        }
    }
}