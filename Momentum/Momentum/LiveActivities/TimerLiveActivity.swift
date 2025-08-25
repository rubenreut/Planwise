//
//  TimerLiveActivity.swift
//  Momentum
//
//  Dynamic Island and Lock Screen UI for habit timers
//

import ActivityKit
import SwiftUI
import WidgetKit

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // Lock Screen/Banner UI - appears on lock screen and as notification banner
            LockScreenTimerView(context: context)
                .activityBackgroundTint(Color(hex: context.attributes.habitColor))
                .activitySystemActionForegroundColor(Color.white)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI - when Dynamic Island is pressed and expands
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.attributes.habitIcon)
                            .font(.title2)
                            .foregroundColor(Color(hex: context.attributes.habitColor))
                        VStack(alignment: .leading) {
                            Text(context.attributes.habitName)
                                .font(.headline)
                                .lineLimit(1)
                            Text("Timer Active")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.elapsedTime))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: context.attributes.habitColor))
                        .padding(.trailing)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        // Progress bar if target duration is set
                        if let target = context.state.targetDuration {
                            ProgressView(value: min(context.state.elapsedTime / target, 1.0))
                                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: context.attributes.habitColor)))
                                .frame(height: 4)
                                .padding(.horizontal)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    // Empty center to balance layout
                }
                
            } compactLeading: {
                // Compact leading - small icon when minimized
                Image(systemName: context.attributes.habitIcon)
                    .font(.caption)
                    .foregroundColor(Color(hex: context.attributes.habitColor))
                    .padding(.leading, 4)
                
            } compactTrailing: {
                // Compact trailing - timer when minimized
                Text(formatCompactTime(context.state.elapsedTime))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: context.attributes.habitColor))
                    .padding(.trailing, 4)
                
            } minimal: {
                // Minimal view - just icon for smallest state
                Image(systemName: context.attributes.habitIcon)
                    .font(.caption)
                    .foregroundColor(Color(hex: context.attributes.habitColor))
            }
            .widgetURL(URL(string: "momentum://timer/\(context.attributes.habitName)"))
            .keylineTint(Color(hex: context.attributes.habitColor))
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func formatCompactTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Lock Screen View
struct LockScreenTimerView: View {
    let context: ActivityViewContext<TimerActivityAttributes>
    
    var body: some View {
        HStack {
            // Icon and name
            HStack(spacing: 12) {
                Image(systemName: context.attributes.habitIcon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.habitName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Timer Active")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Timer display
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTime(context.state.elapsedTime))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                if let target = context.state.targetDuration {
                    Text("\(Int((context.state.elapsedTime / target) * 100))% complete")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding()
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}