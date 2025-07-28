//
//  WeekViewIPad.swift
//  Momentum
//
//  Week view for iPad - redirects to UnifiedWeekView
//

import SwiftUI

struct WeekViewIPad: View {
    var body: some View {
        UnifiedWeekView()
    }
}

// MARK: - Preview
#Preview {
    WeekViewIPad()
        .environmentObject(ScheduleManager.shared)
        .environment(\.dependencyContainer, DependencyContainer(
            persistenceProvider: PersistenceController.shared,
            scheduleManager: ScheduleManager.shared,
            scrollPositionManager: ScrollPositionManager.shared
        ))
}