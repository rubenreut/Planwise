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
    
    var body: some View {
        Button {
            toggleCompletion()
        } label: {
            ZStack {
                // Background circle
                Circle()
                    .fill(isCompleted ? Color(hex: habit.colorHex ?? "#007AFF").opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        Color(hex: habit.colorHex ?? "#007AFF"),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: ringProgress)
                
                // Icon
                Image(systemName: habit.iconName ?? "star.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isCompleted ? Color(hex: habit.colorHex ?? "#007AFF") : .gray)
                    .scaleEffect(buttonScale)
                
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
    
    private func checkCompletionStatus() {
        let calendar = Calendar.current
        if let entry = habit.entries?.allObjects.first(where: { entry in
            guard let entry = entry as? HabitEntry else { return false }
            return calendar.isDate(entry.date ?? Date(), inSameDayAs: date)
        }) as? HabitEntry {
            isCompleted = !entry.skipped
            ringProgress = isCompleted ? 1.0 : 0.0
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
                habitManager.deleteEntry(entry)
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
                value: habit.goalTarget ?? 1.0,
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