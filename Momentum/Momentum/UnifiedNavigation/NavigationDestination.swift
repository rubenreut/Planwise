//
//  NavigationDestination.swift
//  Momentum
//
//  Type-safe navigation destinations for unified navigation
//

import SwiftUI

enum NavigationDestination: Int, CaseIterable, Identifiable {
    case day = 0
    case week = 1
    case tasks = 2
    case habits = 3
    case goals = 4
    case assistant = 5
    case settings = 6
    
    var id: Int { rawValue }
    
    // MARK: - Display Properties
    
    var title: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .tasks: return "Tasks"
        case .habits: return "Habits"
        case .goals: return "Goals"
        case .assistant: return "AI Assistant"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .day: return "calendar.day.timeline.left"
        case .week: return "calendar"
        case .tasks: return "checklist"
        case .habits: return "star.fill"
        case .goals: return "target"
        case .assistant: return "message.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .day: return .adaptiveBlue
        case .week: return .adaptivePurple
        case .tasks: return .adaptiveGreen
        case .habits: return .adaptiveOrange
        case .goals: return .adaptiveRed
        case .assistant: return .adaptivePurple
        case .settings: return Color(UIColor.secondaryLabel)
        }
    }
    
    var section: NavigationSection {
        switch self {
        case .day, .week:
            return .schedule
        case .tasks, .habits, .goals:
            return .productivity
        case .assistant:
            return .ai
        case .settings:
            return .system
        }
    }
    
    var analyticsName: String {
        switch self {
        case .day: return "DayView"
        case .week: return "WeekView"
        case .tasks: return "TaskListView"
        case .habits: return "HabitsView"
        case .goals: return "GoalsView"
        case .assistant: return "AIChatView"
        case .settings: return "SettingsView"
        }
    }
    
    // MARK: - Platform Specific Properties
    
    var showsInTabBar: Bool {
        switch self {
        case .day, .tasks, .habits, .goals, .assistant:
            return true
        case .week, .settings:
            return false
        }
    }
    
    var showsInSidebar: Bool {
        true // All destinations show in sidebar
    }
    
    var requiresPremium: Bool {
        switch self {
        case .assistant:
            return true
        default:
            return false
        }
    }
    
    // MARK: - View Builder
    
    @ViewBuilder
    func view() -> some View {
        switch self {
        case .day:
            DayView()
        case .week:
            WeekViewIPad()
        case .tasks:
            TaskListViewPremium()
        case .habits:
            HabitsView()
        case .goals:
            GoalsView()
        case .assistant:
            AIChatView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Navigation Section

enum NavigationSection: String, CaseIterable {
    case schedule = "Schedule"
    case productivity = "Productivity"
    case ai = "Assistant"
    case system = "System"
    
    var destinations: [NavigationDestination] {
        NavigationDestination.allCases.filter { $0.section == self }
    }
    
    var showsHeader: Bool {
        switch self {
        case .system:
            return false
        default:
            return true
        }
    }
}

// MARK: - Navigation State

@MainActor
class NavigationState: ObservableObject {
    @Published var selectedDestination: NavigationDestination = .day
    @Published var columnVisibility: NavigationSplitViewVisibility = .all
    @Published var pendingTaskCount: Int = 0
    @Published var todayHabitCount: Int = 0
    
    // Navigation history for back button support
    @Published private(set) var navigationHistory: [NavigationDestination] = []
    
    func navigate(to destination: NavigationDestination) {
        if destination != selectedDestination {
            navigationHistory.append(selectedDestination)
            selectedDestination = destination
            
            // Log navigation
            CrashReporter.shared.logNavigation(to: destination.analyticsName)
            CrashReporter.shared.addBreadcrumb(
                message: "Navigated to \(destination.analyticsName)",
                category: "navigation",
                level: .info,
                data: ["destination": destination.rawValue]
            )
        }
    }
    
    func navigateBack() {
        if let previous = navigationHistory.popLast() {
            selectedDestination = previous
        }
    }
    
    func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.25)) {
            columnVisibility = columnVisibility == .all ? .detailOnly : .all
        }
    }
}