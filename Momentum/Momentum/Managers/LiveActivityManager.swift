//
//  LiveActivityManager.swift
//  Momentum
//
//  Manages Live Activities for habit timers
//

import ActivityKit
import Foundation
import SwiftUI

@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()
    
    @Published private var currentActivity: Activity<TimerActivityAttributes>?
    private var updateTimer: Timer?
    private var pausedElapsedTime: TimeInterval = 0
    private var isPaused: Bool = false
    
    private init() {}
    
    // MARK: - Start Timer Activity
    func startTimerActivity(for habit: Habit, initialElapsedTime: TimeInterval = 0) async {
        // Check if Live Activities are enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("❌ Live Activities are not enabled")
            return
        }
        
        // End any existing activity
        await endCurrentActivity()
        
        // Store initial elapsed time for resuming
        pausedElapsedTime = initialElapsedTime
        isPaused = false
        
        // Create attributes
        let attributes = TimerActivityAttributes(
            habitName: habit.name ?? "Habit",
            habitIcon: habit.iconName ?? "clock",
            habitColor: habit.colorHex ?? "#007AFF",
            startTime: Date().addingTimeInterval(-initialElapsedTime) // Adjust start time
        )
        
        // Initial state - use goalTarget for duration-based habits
        let targetMinutes = habit.goalTarget > 0 ? habit.goalTarget : 0
        let initialState = TimerActivityAttributes.ContentState(
            elapsedTime: initialElapsedTime,
            isRunning: true,
            targetDuration: targetMinutes > 0 ? TimeInterval(targetMinutes * 60) : nil
        )
        
        // Create activity content
        let content = ActivityContent(
            state: initialState,
            staleDate: nil // Timer should never be stale
        )
        
        do {
            // Request the activity
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil // No push updates needed
            )
            
            print("✅ Started Live Activity for \(habit.name ?? "habit")")
            currentActivity = activity
            
            // Start update timer from the adjusted start time
            let adjustedStartTime = Date().addingTimeInterval(-initialElapsedTime)
            startUpdateTimer(from: adjustedStartTime)
            
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }
    
    // MARK: - Update Timer
    private func startUpdateTimer(from startTime: Date? = nil) {
        updateTimer?.invalidate()
        
        let timerStartTime = startTime ?? Date()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            AsyncTask { @MainActor in
                await self.updateTimerActivity(startTime: timerStartTime)
            }
        }
    }
    
    private func updateTimerActivity(startTime: Date) async {
        guard let activity = currentActivity else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        let updatedState = TimerActivityAttributes.ContentState(
            elapsedTime: elapsed,
            isRunning: true,
            targetDuration: activity.content.state.targetDuration
        )
        
        let content = ActivityContent(
            state: updatedState,
            staleDate: nil
        )
        
        await activity.update(content)
    }
    
    // MARK: - Pause Timer
    func pauseTimerActivity() async {
        guard let activity = currentActivity else { return }
        
        updateTimer?.invalidate()
        updateTimer = nil
        
        // Store the elapsed time when pausing
        pausedElapsedTime = activity.content.state.elapsedTime
        isPaused = true
        
        // Update to paused state
        let finalState = TimerActivityAttributes.ContentState(
            elapsedTime: activity.content.state.elapsedTime,
            isRunning: false,
            targetDuration: activity.content.state.targetDuration
        )
        
        let content = ActivityContent(
            state: finalState,
            staleDate: Date().addingTimeInterval(60) // Mark as stale after 1 minute
        )
        
        await activity.update(content)
        print("⏸️ Paused Live Activity at \(pausedElapsedTime)s")
    }
    
    // MARK: - Resume Timer
    func resumeTimerActivity() async {
        guard let activity = currentActivity, isPaused else { return }
        
        isPaused = false
        
        // Resume with the stored elapsed time
        let resumeState = TimerActivityAttributes.ContentState(
            elapsedTime: pausedElapsedTime,
            isRunning: true,
            targetDuration: activity.content.state.targetDuration
        )
        
        let content = ActivityContent(
            state: resumeState,
            staleDate: nil
        )
        
        await activity.update(content)
        
        // Restart the update timer from where we left off
        let startTime = Date().addingTimeInterval(-pausedElapsedTime)
        startUpdateTimer(from: startTime)
        
        print("▶️ Resumed Live Activity from \(pausedElapsedTime)s")
    }
    
    // MARK: - Toggle Pause/Resume
    func togglePauseResume() async {
        if isPaused {
            await resumeTimerActivity()
        } else {
            await pauseTimerActivity()
        }
    }
    
    // MARK: - End Activity
    func endCurrentActivity() async {
        updateTimer?.invalidate()
        updateTimer = nil
        
        guard let activity = currentActivity else { return }
        
        // Reset pause state
        isPaused = false
        pausedElapsedTime = 0
        
        // Final update with completion state
        let finalState = TimerActivityAttributes.ContentState(
            elapsedTime: activity.content.state.elapsedTime,
            isRunning: false,
            targetDuration: activity.content.state.targetDuration
        )
        
        let content = ActivityContent(
            state: finalState,
            staleDate: Date() // Mark as stale immediately
        )
        
        await activity.end(content, dismissalPolicy: .default)
        currentActivity = nil
        print("🏁 Ended Live Activity")
    }
    
    // MARK: - Check for existing activities
    func checkForExistingActivities() {
        AsyncTask { @MainActor in
            for activity in Activity<TimerActivityAttributes>.activities {
                // End any orphaned activities
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}