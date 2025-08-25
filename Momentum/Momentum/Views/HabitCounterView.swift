//
//  HabitCounterView.swift
//  Momentum
//
//  Counter view for count-based habits
//

import SwiftUI

struct HabitCounterView: View {
    let habit: Habit
    let date: Date
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var habitManager: HabitManager
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    @State private var currentCount: Double = 0
    @State private var showingSuccess = false
    @State private var pulseAnimation = false
    @State private var sessionStartTime: Date?
    @State private var initialCount: Double = 0
    
    private var accentColor: Color {
        Color.fromAccentString(selectedAccentColor)
    }
    
    private var progress: Double {
        min(1.0, currentCount / max(1, habit.goalTarget))
    }
    
    private var isComplete: Bool {
        currentCount >= habit.goalTarget
    }
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header
                VStack(spacing: 8) {
                    Text(habit.name ?? "Count")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(Date.formatDateWithGreeting(date))
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Main counter display
                VStack(spacing: 30) {
                    // Circular progress
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 20)
                            .frame(width: 250, height: 250)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .frame(width: 250, height: 250)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.4), value: currentCount)
                        
                        // Count display
                        VStack(spacing: 8) {
                            Text("\(Int(currentCount))")
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3), value: pulseAnimation)
                            
                            Text("of \(Int(habit.goalTarget))")
                                .font(.title2)
                                .foregroundColor(.gray)
                            
                            // Unit display removed as Habit doesn't have unit property
                        }
                    }
                    
                    // Increment/Decrement buttons
                    HStack(spacing: 40) {
                        // Decrease button
                        Button {
                            if currentCount > 0 {
                                HapticFeedback.light.trigger()
                                currentCount -= 1
                                // Start tracking session on first interaction
                                if sessionStartTime == nil {
                                    sessionStartTime = Date()
                                }
                                pulseAnimation = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    pulseAnimation = false
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "minus")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(currentCount <= 0)
                        .opacity(currentCount <= 0 ? 0.5 : 1)
                        
                        // Increase button
                        Button {
                            HapticFeedback.light.trigger()
                            currentCount += 1
                            // Start tracking session on first interaction
                            if sessionStartTime == nil {
                                sessionStartTime = Date()
                            }
                            pulseAnimation = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                pulseAnimation = false
                            }
                            
                            // Check if goal reached
                            if currentCount >= habit.goalTarget && !showingSuccess {
                                showingSuccess = true
                                HapticFeedback.success.trigger()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .scaleEffect(pulseAnimation ? 0.9 : 1.0)
                    }
                    
                    // Quick add buttons
                    HStack(spacing: 20) {
                        ForEach([5, 10, 25], id: \.self) { increment in
                            Button {
                                HapticFeedback.light.trigger()
                                currentCount += Double(increment)
                                // Start tracking session on first interaction
                                if sessionStartTime == nil {
                                    sessionStartTime = Date()
                                }
                                pulseAnimation = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    pulseAnimation = false
                                }
                                
                                if currentCount >= habit.goalTarget && !showingSuccess {
                                    showingSuccess = true
                                    HapticFeedback.success.trigger()
                                }
                            } label: {
                                Text("+\(increment)")
                                    .font(.headline)
                                    .foregroundColor(accentColor)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(accentColor.opacity(0.2))
                                    )
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 20) {
                    // Cancel button
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.3))
                            )
                    }
                    
                    // Save button
                    Button {
                        saveCount()
                    } label: {
                        HStack {
                            if isComplete {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(isComplete ? "Complete!" : "Save")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isComplete ? Color.green : accentColor)
                        )
                    }
                    .animation(.spring(), value: isComplete)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            
            // Success overlay
            if showingSuccess {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                            .scaleEffect(showingSuccess ? 1 : 0)
                            .animation(.spring(response: 0.4), value: showingSuccess)
                        
                        Text("Goal Reached!")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("You've completed \(Int(habit.goalTarget))!")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.9))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.green, lineWidth: 2)
                    )
                    
                    Spacer()
                }
                .background(Color.black.opacity(0.5))
                .onTapGesture {
                    showingSuccess = false
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            loadCurrentCount()
        }
    }
    
    private func loadCurrentCount() {
        // Load existing entry for this date
        if let entries = habit.entries as? Set<HabitEntry>,
           let entry = entries.first(where: { entry in
               guard let entryDate = entry.date else { return false }
               return Calendar.current.isDate(entryDate, inSameDayAs: date)
           }) {
            currentCount = entry.value
            initialCount = entry.value // Track initial count to detect changes
        }
    }
    
    private func saveCount() {
        // Create event if session was meaningful
        if let sessionStart = sessionStartTime {
            let sessionDuration = Date().timeIntervalSince(sessionStart)
            
            // Only create event if:
            // 1. Session lasted at least 2 minutes OR
            // 2. Count changed significantly (more than just 1-2 quick changes)
            let countChange = abs(currentCount - initialCount)
            
            if sessionDuration >= 120 || (countChange >= 5 && sessionDuration >= 30) {
                createCountingEvent(startTime: sessionStart, endTime: Date(), count: Int(currentCount))
            }
        }
        
        _ = habitManager.logHabit(
            habit,
            value: currentCount,
            date: date,
            notes: nil,
            mood: nil,
            duration: nil,
            quality: nil
        )
        
        HapticFeedback.success.trigger()
        dismiss()
    }
    
    private func createCountingEvent(startTime: Date, endTime: Date, count: Int) {
        let scheduleManager = ScheduleManager.shared
        let eventTitle = habit.name ?? "Counting Session"
        let duration = Int(endTime.timeIntervalSince(startTime) / 60)
        let eventNotes = "🔢 Counting session for \(eventTitle)\nCompleted: \(count) counts\nDuration: \(duration) minutes"
        
        _ = scheduleManager.createEvent(
            title: eventTitle,
            startTime: startTime,
            endTime: endTime,
            category: habit.category,
            notes: eventNotes,
            location: nil,
            isAllDay: false
        )
    }
}

#Preview {
    HabitCounterView(
        habit: {
            let habit = Habit(context: PersistenceController.preview.container.viewContext)
            habit.name = "Water Intake"
            habit.trackingType = "count" // Count type
            habit.goalTarget = 8
            return habit
        }(),
        date: Date()
    )
    .environmentObject(HabitManager.shared)
}