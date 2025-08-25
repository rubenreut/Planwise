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
                    HStack(spacing: 6) {
                        Image(systemName: context.attributes.habitIcon)
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: context.attributes.habitColor))
                        
                        // Show full habit name without truncation
                        Text(context.attributes.habitName)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(2) // Allow 2 lines if needed
                            .minimumScaleFactor(0.5) // Allow more shrinking
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.leading, 12)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatTime(context.state.elapsedTime))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: context.attributes.habitColor))
                        
                        if let target = context.state.targetDuration {
                            Text("\(Int((context.state.elapsedTime / target) * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.trailing, 12)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        // Progress bar if target duration is set
                        if let target = context.state.targetDuration {
                            ProgressView(value: min(context.state.elapsedTime / target, 1.0))
                                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: context.attributes.habitColor)))
                                .frame(height: 3)
                                .padding(.horizontal, 16)
                        }
                        
                        // Control buttons
                        HStack(spacing: 16) {
                            // Pause/Resume button
                            Link(destination: URL(string: "momentum://timer/pause")!) {
                                HStack(spacing: 3) {
                                    Image(systemName: context.state.isRunning ? "pause.fill" : "play.fill")
                                        .font(.system(size: 11))
                                    Text(context.state.isRunning ? "Pause" : "Resume")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: context.attributes.habitColor))
                                )
                            }
                            
                            // Stop button
                            Link(destination: URL(string: "momentum://timer/stop")!) {
                                HStack(spacing: 3) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 11))
                                    Text("Stop")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.8))
                                )
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
                
            } compactLeading: {
                // Compact leading - show habit name and icon on one line
                HStack(spacing: 3) {
                    Image(systemName: context.attributes.habitIcon)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: context.attributes.habitColor))
                    
                    // Show habit name with adaptive sizing
                    Text(context.attributes.habitName)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6) // Allow more shrinking if needed
                        .frame(maxWidth: 100) // Give more width for habit name
                }
                .padding(.leading, 2)
                
            } compactTrailing: {
                // Compact trailing - timer display
                Text(formatCompactTime(context.state.elapsedTime))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(context.state.isRunning ? 
                        Color(hex: context.attributes.habitColor) : 
                        Color.orange)
                    .padding(.trailing, 2)
                
            } minimal: {
                // Minimal view - icon with running indicator
                ZStack {
                    Image(systemName: context.attributes.habitIcon)
                        .font(.caption)
                        .foregroundColor(Color(hex: context.attributes.habitColor))
                    
                    if !context.state.isRunning {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .offset(x: 6, y: -6)
                    }
                }
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