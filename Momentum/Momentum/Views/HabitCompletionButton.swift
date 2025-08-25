import SwiftUI

struct HabitCompletionButton: View {
    let habit: Habit
    let date: Date
    @EnvironmentObject private var habitManager: HabitManager
    
    @State private var isCompleted: Bool = false
    @State private var showAnimation: Bool = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var ringProgress: Double = 0.0
    @State private var showStreak: Bool = false
    @State private var currentValue: Double = 0.0
    @State private var showingValueInput: Bool = false
    
    var body: some View {
        Button {
            handleTap()
        } label: {
            ZStack {
                // Background circle
                Circle()
                    .fill(isCompleted ? Color(hex: habit.colorHex ?? "#007AFF").opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                // Background ring (shows the unfilled portion)
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 56, height: 56)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        isCompleted ? Color(hex: habit.colorHex ?? "#007AFF") : 
                            Color(hex: habit.colorHex ?? "#007AFF").opacity(0.7),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: ringProgress)
                
                // Show value or icon based on habit type and progress
                if hasTarget && !isCompleted {
                    // Show current value for habits with targets
                    VStack(spacing: 2) {
                        Text(formatProgressValue())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                        
                        Text(formatTargetLabel())
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                } else {
                    // Icon for completed or simple habits
                    Image(systemName: habit.iconName ?? "star.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isCompleted ? Color(hex: habit.colorHex ?? "#007AFF") : .gray)
                        .scaleEffect(buttonScale)
                }
                
                // Checkmark overlay when completed
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(Color.green)
                                .frame(width: 24, height: 24)
                        )
                        .offset(x: 20, y: -20)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(buttonScale)
        .contextMenu {
            if hasTarget {
                Button {
                    showingValueInput = true
                } label: {
                    Label("Set Custom Value", systemImage: "pencil")
                }
                
                Button {
                    // Quick complete to target
                    currentValue = habit.goalTarget
                    ringProgress = 1.0
                    isCompleted = true
                    saveProgress()
                } label: {
                    Label("Mark as Complete", systemImage: "checkmark.circle")
                }
                
                if currentValue > 0 {
                    Button(role: .destructive) {
                        resetProgress()
                    } label: {
                        Label("Reset Progress", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
        .overlay(
            // Streak celebration
            Group {
                if showStreak {
                    StreakBadge(count: Int(habit.currentStreak))
                        .transition(.scale.combined(with: .opacity))
                        .offset(y: -80)
                }
            }
        )
        .onAppear {
            checkCompletionStatus()
        }
        .taskCompletionAnimation(isCompleted: $showAnimation) {
            // Animation completed
        }
    }
    
    private var hasTarget: Bool {
        // Check if habit has a target value (duration, quantity, etc.)
        let trackingType = HabitTrackingType(rawValue: habit.trackingType ?? "") ?? .binary
        return (trackingType == .duration || trackingType == .quantity) && habit.goalTarget > 0
    }
    
    private func formatProgressValue() -> String {
        let trackingType = HabitTrackingType(rawValue: habit.trackingType ?? "") ?? .binary
        
        switch trackingType {
        case .duration:
            // Format as minutes
            let minutes = Int(currentValue)
            if minutes >= 60 {
                return "\(minutes / 60)h"
            }
            return "\(minutes)"
        case .quantity:
            // Format as count
            return "\(Int(currentValue))"
        default:
            return ""
        }
    }
    
    private func formatTargetLabel() -> String {
        let trackingType = HabitTrackingType(rawValue: habit.trackingType ?? "") ?? .binary
        let target = Int(habit.goalTarget)
        
        switch trackingType {
        case .duration:
            if target >= 60 {
                return "of \(target / 60)h"
            }
            return "of \(target)m"
        case .quantity:
            return "of \(target)"
        default:
            return ""
        }
    }
    
    private func checkCompletionStatus() {
        let calendar = Calendar.current
        if let entry = habit.entries?.allObjects.first(where: { entry in
            guard let entry = entry as? HabitEntry else { return false }
            return calendar.isDate(entry.date ?? Date(), inSameDayAs: date)
        }) as? HabitEntry {
            isCompleted = !entry.skipped
            currentValue = entry.value
            
            // Calculate ring progress based on target
            if hasTarget && habit.goalTarget > 0 {
                ringProgress = min(currentValue / habit.goalTarget, 1.0)
                // Mark as completed if target reached
                if ringProgress >= 1.0 {
                    isCompleted = true
                }
            } else {
                ringProgress = isCompleted ? 1.0 : 0.0
            }
        } else {
            // No entry for today
            isCompleted = false
            currentValue = 0
            ringProgress = 0.0
        }
    }
    
    private func handleTap() {
        // For habits with targets, increment progress; for simple habits, toggle
        if hasTarget && !isCompleted {
            incrementProgress()
        } else {
            toggleCompletion()
        }
    }
    
    private func incrementProgress() {
        let trackingType = HabitTrackingType(rawValue: habit.trackingType ?? "") ?? .binary
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Determine increment amount
        var increment: Double = 0
        switch trackingType {
        case .duration:
            // Increment by 5 minutes for duration habits
            increment = 5
        case .quantity:
            // Increment by 1 for quantity habits
            increment = 1
        default:
            return
        }
        
        // Update current value
        currentValue += increment
        
        // Check if target reached
        if currentValue >= habit.goalTarget {
            currentValue = habit.goalTarget
            isCompleted = true
            showAnimation = true
            
            // Stronger haptic for completion
            let completionFeedback = UIImpactFeedbackGenerator(style: .medium)
            completionFeedback.impactOccurred()
        }
        
        // Update ring progress
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            ringProgress = min(currentValue / habit.goalTarget, 1.0)
        }
        
        // Save the progress
        _ = habitManager.logHabit(
            habit,
            value: currentValue,
            date: date,
            notes: nil,
            mood: nil,
            duration: trackingType == .duration ? Int32(currentValue * 60) : nil,
            quality: nil
        )
        
        // Check for streak milestone if completed
        if isCompleted && Int(habit.currentStreak) % 7 == 0 && habit.currentStreak > 0 {
            showStreakCelebration()
        }
    }
    
    private func toggleCompletion() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Button press animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            buttonScale = 0.85
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                buttonScale = 1.0
            }
        }
        
        if isCompleted {
            // Unlog habit
            withAnimation(.easeOut(duration: 0.3)) {
                isCompleted = false
                ringProgress = 0.0
            }
            
            // Remove entry logic here
            if let entry = getEntryForDate() {
                _ = habitManager.deleteEntry(entry)
            }
        } else {
            // Log habit with animation
            isCompleted = true
            showAnimation = true
            
            // Animate ring progress
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                ringProgress = 1.0
            }
            
            // Log the habit
            let result = habitManager.logHabit(
                habit,
                value: habit.goalTarget,
                date: date,
                notes: nil,
                mood: nil,
                duration: nil,
                quality: nil
            )
            
            if case .success = result {
                // Check for streak milestone
                if Int(habit.currentStreak) % 7 == 0 && habit.currentStreak > 0 {
                    showStreakCelebration()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showAnimation = false
            }
        }
    }
    
    private func getEntryForDate() -> HabitEntry? {
        let calendar = Calendar.current
        return habit.entries?.allObjects.first(where: { entry in
            guard let entry = entry as? HabitEntry else { return false }
            return calendar.isDate(entry.date ?? Date(), inSameDayAs: date)
        }) as? HabitEntry
    }
    
    private func saveProgress() {
        _ = habitManager.logHabit(
            habit,
            value: currentValue,
            date: date,
            notes: nil,
            mood: nil,
            duration: habit.trackingType == HabitTrackingType.duration.rawValue ? Int32(currentValue * 60) : nil,
            quality: nil
        )
        
        // Haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    private func resetProgress() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            currentValue = 0
            ringProgress = 0
            isCompleted = false
        }
        
        // Remove entry if exists
        if let entry = getEntryForDate() {
            _ = habitManager.deleteEntry(entry)
        }
    }
    
    private func showStreakCelebration() {
        withAnimation(.spring()) {
            showStreak = true
        }
        
        // Extra haptic for milestone
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut) {
                showStreak = false
            }
        }
    }
}

struct StreakBadge: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
            
            Image(systemName: "flame.fill")
                .font(.title3)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        )
    }
}

// MARK: - Preview

struct HabitCompletionButton_Previews: PreviewProvider {
    static var previews: some View {
        HabitCompletionButton(
            habit: createSampleHabit(),
            date: Date()
        )
        .environmentObject(HabitManager.shared)
        .previewLayout(.sizeThatFits)
        .padding()
    }
    
    static func createSampleHabit() -> Habit {
        let context = PersistenceController.preview.container.viewContext
        let habit = Habit(context: context)
        habit.name = "Meditation"
        habit.iconName = "brain.head.profile"
        habit.colorHex = "#A29BFE"
        habit.currentStreak = 6
        habit.goalTarget = 1
        return habit
    }
}