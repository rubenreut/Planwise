//
//  GoalsWidget.swift
//  MomentumWidget
//
//  Interactive goals widget with progress tracking
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Entry
struct GoalsEntry: TimelineEntry {
    let date: Date
    let goals: [GoalItem]
    let accentColor: String
    let configuration: ConfigurationAppIntent
}

struct GoalItem: Identifiable {
    let id: String
    let title: String
    let type: String
    let progress: Double
    let targetDate: Date?
    let priority: String
    let colorHex: String
    let milestoneCount: Int
    let completedMilestones: Int
}

// MARK: - Goals Widget
struct GoalsWidget: Widget {
    let kind: String = "GoalsWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: GoalsProvider()) { entry in
            GoalsWidgetView(entry: entry)
                .containerBackground(Color(UIColor.systemBackground), for: .widget)
        }
        .configurationDisplayName("Goals")
        .description("Track your goals and milestones")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Timeline Provider
struct GoalsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> GoalsEntry {
        GoalsEntry(
            date: Date(),
            goals: sampleGoals,
            accentColor: UserDefaults(suiteName: "group.com.rubenreut.momentum")?.string(forKey: "accentColor") ?? "blue",
            configuration: ConfigurationAppIntent()
        )
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> GoalsEntry {
        let goals = await fetchGoals(limit: context.family.goalLimit)
        let accentColor = UserDefaults(suiteName: "group.com.rubenreut.momentum")?.string(forKey: "accentColor") ?? "blue"
        return GoalsEntry(date: Date(), goals: goals, accentColor: accentColor, configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<GoalsEntry> {
        let goals = await fetchGoals(limit: context.family.goalLimit)
        let accentColor = UserDefaults(suiteName: "group.com.rubenreut.momentum")?.string(forKey: "accentColor") ?? "blue"
        let entry = GoalsEntry(date: Date(), goals: goals, accentColor: accentColor, configuration: configuration)
        
        // Update every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func fetchGoals(limit: Int) async -> [GoalItem] {
        // Fetch from Core Data
        let context = WidgetPersistenceController.shared.container.viewContext
        let request = Goal.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Goal.priority, ascending: false),
            NSSortDescriptor(keyPath: \Goal.createdAt, ascending: false)
        ]
        request.fetchLimit = limit
        
        do {
            let goals = try context.fetch(request)
            return goals.map { goal in
                let milestones = goal.milestones?.allObjects as? [GoalMilestone] ?? []
                let completedMilestones = milestones.filter { $0.isCompleted }.count
                
                return GoalItem(
                    id: goal.objectID.uriRepresentation().absoluteString,
                    title: goal.title ?? "Untitled Goal",
                    type: goal.typeString ?? "milestone",
                    progress: goal.progressPercentage,
                    targetDate: goal.targetDate,
                    priority: goal.priorityString ?? "medium",
                    colorHex: goal.category?.colorHex ?? "#007AFF",
                    milestoneCount: milestones.count,
                    completedMilestones: completedMilestones
                )
            }
        } catch {
            return []
        }
    }
    
    private var sampleGoals: [GoalItem] {
        [
            GoalItem(id: "1", title: "Complete Marathon Training", type: "milestone", progress: 0.65, targetDate: Date().addingTimeInterval(60*24*3600), priority: "high", colorHex: "#FF3B30", milestoneCount: 5, completedMilestones: 3),
            GoalItem(id: "2", title: "Read 20 Books", type: "numeric", progress: 0.45, targetDate: nil, priority: "medium", colorHex: "#34C759", milestoneCount: 0, completedMilestones: 0),
            GoalItem(id: "3", title: "Learn Spanish", type: "habit", progress: 0.30, targetDate: Date().addingTimeInterval(180*24*3600), priority: "medium", colorHex: "#AF52DE", milestoneCount: 0, completedMilestones: 0)
        ]
    }
}

// MARK: - Widget Views
struct GoalsWidgetView: View {
    let entry: GoalsEntry
    @Environment(\.widgetFamily) var family
    
    var accentColor: Color {
        Color.fromAccentString(entry.accentColor)
    }
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallGoalsView(goals: entry.goals, accentColor: accentColor)
        case .systemMedium:
            MediumGoalsView(goals: entry.goals, accentColor: accentColor)
        case .systemLarge:
            LargeGoalsView(goals: entry.goals, accentColor: accentColor)
        case .systemExtraLarge:
            ExtraLargeGoalsView(goals: entry.goals, accentColor: accentColor)
        case .accessoryCircular:
            CircularGoalsView(goals: entry.goals)
        case .accessoryRectangular:
            RectangularGoalsView(goals: entry.goals)
        case .accessoryInline:
            InlineGoalsView(goals: entry.goals)
        default:
            EmptyView()
        }
    }
}

// MARK: - Small Widget
struct SmallGoalsView: View {
    let goals: [GoalItem]
    let accentColor: Color
    
    var topGoal: GoalItem? {
        goals.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "target")
                    .font(.headline)
                    .foregroundColor(accentColor)
                Text("Goals")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if let goal = topGoal {
                // Main goal display
                VStack(alignment: .leading, spacing: 8) {
                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        
                        Circle()
                            .trim(from: 0, to: goal.progress)
                            .stroke(
                                Color.fromHex(goal.colorHex),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text("\(Int(goal.progress * 100))%")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if goal.type == "milestone" && goal.milestoneCount > 0 {
                                Text("\(goal.completedMilestones)/\(goal.milestoneCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(width: 80, height: 80)
                    
                    // Target date
                    if let targetDate = goal.targetDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(targetDateText(targetDate))
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No active goals")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding()
    }
    
    private func targetDateText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Tomorrow"
        } else if days > 0 {
            return "\(days) days"
        } else {
            return "Overdue"
        }
    }
}

// MARK: - Medium Widget
struct MediumGoalsView: View {
    let goals: [GoalItem]
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - Featured goal
            if let goal = goals.first {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "target")
                            .font(.title2)
                            .foregroundColor(accentColor)
                        Text("Goals")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    // Circular progress
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                            
                            Circle()
                                .trim(from: 0, to: goal.progress)
                                .stroke(
                                    Color.fromHex(goal.colorHex),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(Int(goal.progress * 100))%")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .frame(width: 50, height: 50)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if goal.type == "milestone" {
                                Text("\(goal.completedMilestones) of \(goal.milestoneCount)")
                                    .font(.caption)
                                Text("milestones")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Progress")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
            
            // Right side - Goal list
            VStack(alignment: .leading, spacing: 10) {
                ForEach(goals.prefix(3)) { goal in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.fromHex(goal.colorHex))
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.title)
                                .font(.caption)
                                .lineLimit(1)
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 3)
                                    
                                    Rectangle()
                                        .fill(Color.fromHex(goal.colorHex))
                                        .frame(width: geometry.size.width * goal.progress, height: 3)
                                }
                            }
                            .frame(height: 3)
                        }
                        
                        Text("\(Int(goal.progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

// MARK: - Large Widget
struct LargeGoalsView: View {
    let goals: [GoalItem]
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "target")
                    .font(.title2)
                    .foregroundColor(accentColor)
                Text("Goals")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Link(destination: URL(string: "momentum://goals/add")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(accentColor)
                }
            }
            
            // Goals grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(goals.prefix(6)) { goal in
                    GoalCard(goal: goal)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Extra Large Widget
struct ExtraLargeGoalsView: View {
    let goals: [GoalItem]
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "target")
                    .font(.largeTitle)
                    .foregroundColor(accentColor)
                Text("Goals & Progress")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Link(destination: URL(string: "momentum://goals/add")!) {
                    Label("Add Goal", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(accentColor)
                }
            }
            
            // Goals grid - 3 columns
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(goals.prefix(12)) { goal in
                    GoalCard(goal: goal)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Accessory Widgets
struct CircularGoalsView: View {
    let goals: [GoalItem]
    
    var topGoal: GoalItem? {
        goals.first
    }
    
    var body: some View {
        if let goal = topGoal {
            ZStack {
                AccessoryWidgetBackground()
                
                VStack(spacing: 2) {
                    Text("\(Int(goal.progress * 100))%")
                        .font(.headline)
                    Image(systemName: "target")
                        .font(.caption)
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "target")
            }
        }
    }
}

struct RectangularGoalsView: View {
    let goals: [GoalItem]
    
    var body: some View {
        if let goal = goals.first {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption)
                    Text(goal.title)
                        .font(.caption)
                        .lineLimit(1)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geometry.size.width * goal.progress, height: 4)
                    }
                    .cornerRadius(2)
                }
                .frame(height: 4)
                
                Text("\(Int(goal.progress * 100))% complete")
                    .font(.caption2)
            }
        } else {
            HStack {
                Image(systemName: "target")
                Text("No active goals")
                    .font(.caption)
            }
        }
    }
}

struct InlineGoalsView: View {
    let goals: [GoalItem]
    
    var body: some View {
        if let goal = goals.first {
            Label {
                Text("\(goal.title): \(Int(goal.progress * 100))%")
            } icon: {
                Image(systemName: "target")
            }
        } else {
            Label("No active goals", systemImage: "target")
        }
    }
}

// MARK: - Supporting Views
struct GoalCard: View {
    let goal: GoalItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.fromHex(goal.colorHex))
                    .frame(width: 10, height: 10)
                
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Progress visualization
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                
                VStack(spacing: 8) {
                    // Circular progress
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        
                        Circle()
                            .trim(from: 0, to: goal.progress)
                            .stroke(
                                Color.fromHex(goal.colorHex),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 0) {
                            Text("\(Int(goal.progress * 100))")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 60, height: 60)
                    
                    // Type badge
                    Text(goal.type.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.fromHex(goal.colorHex).opacity(0.2))
                        .cornerRadius(4)
                    
                    // Milestone or date info
                    if goal.type == "milestone" && goal.milestoneCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flag.checkered")
                                .font(.caption2)
                            Text("\(goal.completedMilestones)/\(goal.milestoneCount)")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    } else if let targetDate = goal.targetDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(shortDateText(targetDate))
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 12)
            }
            .frame(height: 120)
        }
    }
    
    private func shortDateText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days == 0 {
            return "Today"
        } else if days > 0 && days <= 30 {
            return "\(days)d"
        } else if days > 30 {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        } else {
            return "Past"
        }
    }
}

// MARK: - Widget Family Extensions
extension WidgetFamily {
    var goalLimit: Int {
        switch self {
        case .systemSmall: return 1
        case .systemMedium: return 4
        case .systemLarge: return 6
        case .systemExtraLarge: return 12
        case .accessoryCircular: return 1
        case .accessoryRectangular: return 1
        case .accessoryInline: return 1
        default: return 1
        }
    }
}

// MARK: - Color Extension for Accent
extension Color {
    static func fromAccentString(_ accent: String) -> Color {
        switch accent.lowercased() {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "indigo": return .indigo
        case "brown": return .brown
        default: return .blue
        }
    }
}