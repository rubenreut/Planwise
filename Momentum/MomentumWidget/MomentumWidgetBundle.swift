//
//  MomentumWidgetBundle.swift
//  MomentumWidget
//
//  Created by Ruben Reut on 03/07/2025.
//

import WidgetKit
import SwiftUI

@main
struct MomentumWidgetBundle: WidgetBundle {
    var body: some Widget {
        MomentumWidget()           // Today Overview (events & schedule)
        TasksWidget()              // Tasks management
        HabitsWidget()             // Habits tracking
        GoalsWidget()              // Goals & milestones
        QuickActionsWidget()       // Quick add actions
        // EventsTimelineWidget()  // Removed - duplicate of MomentumWidget
        MomentumWidgetControl()
        #if !targetEnvironment(macCatalyst)
        MomentumWidgetLiveActivity()
        TimerLiveActivity()        // Habit timer Dynamic Island
        #endif
    }
}
