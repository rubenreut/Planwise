//
//  WeekView.swift
//  Momentum
//
//  Week view for iPhone - redirects to UnifiedWeekView
//

import SwiftUI

struct WeekView: View {
    var body: some View {
        UnifiedWeekView()
    }
}

// MARK: - Preview
struct WeekView_Previews: PreviewProvider {
    static var previews: some View {
        WeekView()
            .environmentObject(ScheduleManager.shared)
    }
}