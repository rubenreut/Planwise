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
        MomentumWidget()
        TasksWidget()
        HabitsWidget()
        EventsTimelineWidget()
        QuickActionsWidget()
        MomentumWidgetControl()
        #if !targetEnvironment(macCatalyst)
        MomentumWidgetLiveActivity()
        #endif
    }
}
