//
//  HabitsWidget.swift
//  MomentumWidget
//
//  Interactive habits tracking widget
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Entry
struct HabitsEntry: TimelineEntry {
    let date: Date
    let habits: [HabitItem]
    let progress: HabitProgress
    let configuration: ConfigurationAppIntent
}

struct HabitItem: Identifiable {
    let id: String
    let name: String
    let iconName: String
    let colorHex: String
    let isCompletedToday: Bool
    let currentStreak: Int
    let goalTarget: Double
    let goalUnit: String?
    let trackingType: String
}

struct HabitProgress {
    let completed: Int
    let total: Int
    var percentage: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }
}

// MARK: - Habits Widget
struct HabitsWidget: Widget {
    let kind: String = "HabitsWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: HabitsProvider()) { entry in
            HabitsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Habits")
        .description("Track your daily habits")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Timeline Provider
struct HabitsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HabitsEntry {
        HabitsEntry(
            date: Date(),
            habits: sampleHabits,
            progress: HabitProgress(completed: 2, total: 5),
            configuration: ConfigurationAppIntent()
        )
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> HabitsEntry {
        let (habits, progress) = await fetchHabits()
        return HabitsEntry(date: Date(), habits: habits, progress: progress, configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<HabitsEntry> {
        let (habits, progress) = await fetchHabits()
        let entry = HabitsEntry(date: Date(), habits: habits, progress: progress, configuration: configuration)
        
        // Update every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func fetchHabits() async -> ([HabitItem], HabitProgress) {
        let context = WidgetPersistenceController.shared.container.viewContext
        let request = Habit.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Habit.sortOrder, ascending: true)]
        
        do {
            let habits = try context.fetch(request)
            let today = Calendar.current.startOfDay(for: Date())
            
            var completedCount = 0
            let habitItems = habits.map { habit in
                let isCompleted = habit.entries?.contains { entry in
                    guard let entry = entry as? HabitEntry,
                          let date = entry.date else { return false }
                    return Calendar.current.isDate(date, inSameDayAs: today) && !entry.skipped
                } ?? false
                
                if isCompleted { completedCount += 1 }
                
                return HabitItem(
                    id: habit.objectID.uriRepresentation().absoluteString,
                    name: habit.name ?? "Unnamed",
                    iconName: habit.iconName ?? "star.fill",
                    colorHex: habit.colorHex ?? "#007AFF",
                    isCompletedToday: isCompleted,
                    currentStreak: Int(habit.currentStreak),
                    goalTarget: habit.goalTarget,
                    goalUnit: habit.goalUnit,
                    trackingType: habit.trackingType ?? "binary"
                )
            }
            
            let progress = HabitProgress(completed: completedCount, total: habits.count)
            return (habitItems, progress)
        } catch {
            return ([], HabitProgress(completed: 0, total: 0))
        }
    }
    
    private var sampleHabits: [HabitItem] {
        [
            HabitItem(id: "1", name: "Morning Meditation", iconName: "brain.head.profile", colorHex: "#9B59B6", isCompletedToday: true, currentStreak: 7, goalTarget: 10, goalUnit: "min", trackingType: "duration"),
            HabitItem(id: "2", name: "Drink Water", iconName: "drop.fill", colorHex: "#3498DB", isCompletedToday: true, currentStreak: 14, goalTarget: 8, goalUnit: "glasses", trackingType: "quantity"),
            HabitItem(id: "3", name: "Exercise", iconName: "figure.run", colorHex: "#E74C3C", isCompletedToday: false, currentStreak: 3, goalTarget: 30, goalUnit: "min", trackingType: "duration"),
            HabitItem(id: "4", name: "Read", iconName: "book.fill", colorHex: "#F39C12", isCompletedToday: false, currentStreak: 5, goalTarget: 20, goalUnit: "pages", trackingType: "quantity"),
            HabitItem(id: "5", name: "Journal", iconName: "pencil", colorHex: "#1ABC9C", isCompletedToday: false, currentStreak: 2, goalTarget: 1, goalUnit: nil, trackingType: "binary")
        ]
    }
}

// MARK: - Widget Views
struct HabitsWidgetView: View {
    let entry: HabitsEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallHabitsView(habits: entry.habits, progress: entry.progress)
        case .systemMedium:
            MediumHabitsView(habits: entry.habits, progress: entry.progress)
        case .systemLarge:
            LargeHabitsView(habits: entry.habits, progress: entry.progress)
        case .accessoryCircular:
            CircularHabitsView(progress: entry.progress)
        case .accessoryRectangular:
            RectangularHabitsView(habits: entry.habits, progress: entry.progress)
        default:
            EmptyView()
        }
    }
}

struct SmallHabitsView: View {
    let habits: [HabitItem]
    let progress: HabitProgress
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: progress.percentage)
                    .stroke(
                        progress.percentage == 1 ? Color.green : Color.blue,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(progress.completed)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("of \(progress.total)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)
            
            Text("Habits")
                .font(.headline)
            
            Link(destination: .habits) {
                Text("View All")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
    }
}

struct MediumHabitsView: View {
    let habits: [HabitItem]
    let progress: HabitProgress
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - Progress
            VStack(alignment: .leading, spacing: 12) {
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(progress.completed)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("/ \(progress.total)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progress.percentage == 1 ? Color.green : Color.blue)
                            .frame(width: geometry.size.width * progress.percentage, height: 8)
                    }
                }
                .frame(height: 8)
                
                Text("\(Int(progress.percentage * 100))% complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Right side - Habit grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(habits.prefix(4)) { habit in
                    HabitIconButton(habit: habit)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

struct LargeHabitsView: View {
    let habits: [HabitItem]
    let progress: HabitProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Habits")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(progress.completed) of \(progress.total) completed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    
                    Circle()
                        .trim(from: 0, to: progress.percentage)
                        .stroke(
                            progress.percentage == 1 ? Color.green : Color.blue,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(progress.percentage * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .frame(width: 50, height: 50)
            }
            
            // Habit list
            VStack(spacing: 10) {
                ForEach(habits.prefix(6)) { habit in
                    HabitRowWidget(habit: habit)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct CircularHabitsView: View {
    let progress: HabitProgress
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 2) {
                Text("\(progress.completed)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("habits")
                    .font(.caption2)
            }
        }
    }
}

struct RectangularHabitsView: View {
    let habits: [HabitItem]
    let progress: HabitProgress
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Habits")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("\(progress.completed)/\(progress.total)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Mini habit icons
            HStack(spacing: 4) {
                ForEach(habits.prefix(3)) { habit in
                    Image(systemName: habit.iconName)
                        .font(.caption)
                        .foregroundColor(habit.isCompletedToday ? .green : .gray)
                }
            }
        }
    }
}

// MARK: - Habit Components
struct HabitIconButton: View {
    let habit: HabitItem
    
    var body: some View {
        Button(intent: ToggleHabitIntent(habitId: habit.id)) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(habit.isCompletedToday ? Color.fromHex( habit.colorHex) : Color.gray.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: habit.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(habit.isCompletedToday ? .white : .gray)
                }
                
                Text(habit.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct HabitRowWidget: View {
    let habit: HabitItem
    
    var body: some View {
        Button(intent: ToggleHabitIntent(habitId: habit.id)) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(habit.isCompletedToday ? Color.fromHex( habit.colorHex) : Color.gray.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: habit.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(habit.isCompletedToday ? .white : .gray)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.subheadline)
                        .lineLimit(1)
                        .strikethrough(habit.isCompletedToday)
                    
                    if habit.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("\(habit.currentStreak) days")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Completion indicator
                Image(systemName: habit.isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(habit.isCompletedToday ? .green : .gray.opacity(0.3))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Intents
struct ToggleHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Habit"
    
    @Parameter(title: "Habit ID")
    var habitId: String
    
    init() {}
    
    init(habitId: String) {
        self.habitId = habitId
    }
    
    func perform() async throws -> some IntentResult {
        let context = WidgetPersistenceController.shared.container.viewContext
        
        guard let url = URL(string: habitId),
              let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url),
              let habit = try? context.existingObject(with: objectID) as? Habit else {
            return .result()
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let existingEntry = habit.entries?.first { entry in
            guard let entry = entry as? HabitEntry,
                  let date = entry.date else { return false }
            return Calendar.current.isDate(date, inSameDayAs: today)
        } as? HabitEntry
        
        if let entry = existingEntry {
            // Remove entry
            context.delete(entry)
        } else {
            // Create entry with default value
            let entry = HabitEntry(context: context)
            entry.date = Date()
            entry.habit = habit
            
            switch habit.trackingType {
            case "binary":
                entry.value = 1.0
            case "quantity", "duration":
                entry.value = habit.goalTarget
            case "quality":
                entry.value = 5.0
            default:
                entry.value = 1.0
            }
        }
        
        try? context.save()
        
        return .result()
    }
}

// Color extension is provided by the main app target