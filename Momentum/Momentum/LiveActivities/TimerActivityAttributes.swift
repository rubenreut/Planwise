//
//  TimerActivityAttributes.swift
//  Momentum
//
//  Live Activity attributes for habit timers in Dynamic Island
//

import ActivityKit
import Foundation
import SwiftUI

struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic values that update during the activity
        var elapsedTime: TimeInterval
        var isRunning: Bool
        var targetDuration: TimeInterval? // Optional target duration for the habit
    }
    
    // Static values that don't change during the activity
    var habitName: String
    var habitIcon: String
    var habitColor: String
    var startTime: Date
}