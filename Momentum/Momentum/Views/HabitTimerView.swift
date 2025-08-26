//
//  HabitTimerView.swift
//  Momentum
//
//  Timer popup for duration-based habits
//

import SwiftUI
import Combine
import ActivityKit

struct HabitTimerView: View {
    let habit: Habit
    let date: Date
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var habitManager: HabitManager
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    @StateObject private var liveActivityManager = LiveActivityManager.shared
    
    @State private var timeElapsed: TimeInterval = 0
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var startTime: Date?
    @State private var backgroundTime: Date?
    
    // Event tracking
    @State private var sessionStartTime: Date?
    @State private var lastPauseTime: Date?
    @State private var totalPauseTime: TimeInterval = 0
    @State private var currentEvent: Event?
    
    private var targetTime: TimeInterval {
        TimeInterval(habit.goalTarget * 60) // Convert minutes to seconds
    }
    
    private var progress: Double {
        min(timeElapsed / targetTime, 1.0)
    }
    
    private var formattedTime: String {
        let minutes = Int(timeElapsed) / 60
        let seconds = Int(timeElapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var formattedMilliseconds: String {
        let milliseconds = Int((timeElapsed.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d", milliseconds)
    }
    
    private var formattedTarget: String {
        let minutes = Int(targetTime) / 60
        let seconds = Int(targetTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        ZStack {
            // Background matching DayView header
            ZStack {
                // Check for custom header image using the same method as DayView
                if let headerData = AppearanceSettingsViewModel.loadHeaderImage() {
                    // Use the custom header image with slight blur
                    Image(uiImage: headerData.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .blur(radius: 2) // Slight blur
                        .ignoresSafeArea()
                        .overlay(
                            // Gradient overlay for better contrast
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.3),
                                    Color.black.opacity(0.5),
                                    Color.black.opacity(0.7)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea()
                        )
                } else {
                    // Fallback to gradient if no custom image
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.15, blue: 0.35),
                            Color(red: 0.12, green: 0.25, blue: 0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0),
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
                }
            }
            
            VStack(spacing: 20) {
                // Close button at top
                HStack {
                    Button {
                        if timer != nil {
                            timer?.invalidate()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .scaledFont(size: 18, weight: .semibold)
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                    }
                    
                    Spacer()
                    
                    // Save button
                    if timeElapsed > 0 {
                        Button {
                            saveProgress()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .scaledFont(size: 14, weight: .bold)
                                Text("Save")
                                    .scaledFont(size: 16, weight: .semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.fromAccentString(selectedAccentColor))
                                    .shadow(color: Color.fromAccentString(selectedAccentColor).opacity(0.4), radius: 8, y: 4)
                            )
                        }
                        .scaleEffect(progress >= 1.0 ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: progress >= 1.0)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                
                // Header - simplified without icon
                VStack(spacing: 8) {
                    Text(habit.name ?? "Timer")
                        .scaledFont(size: 28, weight: .bold)
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .scaledFont(size: 14)
                        Text("\(Int(habit.goalTarget)) min")
                            .scaledFont(size: 15, weight: .medium)
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .padding(.top, 10)
                
                // Timer Circle with modern design - moved higher
                ZStack {
                    // Outer decorative ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 320, height: 320)
                    
                    // Background track
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 20
                        )
                        .frame(width: 280, height: 280)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    // Progress ring with gradient
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.fromAccentString(selectedAccentColor),
                                    Color.fromAccentString(selectedAccentColor).opacity(0.8),
                                    Color.fromAccentString(selectedAccentColor)
                                ],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 280, height: 280)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Color.fromAccentString(selectedAccentColor).opacity(0.6), radius: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                    
                    // Progress percentage dots
                    ForEach(0..<12) { index in
                        Circle()
                            .fill(index < Int(progress * 12) ? Color.white : Color.white.opacity(0.2))
                            .frame(width: 4, height: 4)
                            .offset(y: -150)
                            .rotationEffect(.degrees(Double(index) * 30))
                            .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.02), value: progress)
                    }
                    
                    // Animated pulse when running
                    if isRunning {
                        Circle()
                            .stroke(
                                Color.fromAccentString(selectedAccentColor).opacity(0.3),
                                lineWidth: 2
                            )
                            .frame(width: 260, height: 260)
                            .scaleEffect(isRunning ? 1.05 : 1.0)
                            .opacity(isRunning ? 0.5 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                                value: isRunning
                            )
                    }
                    
                    // Center content
                    VStack(spacing: 4) {
                        // Time with milliseconds
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text(formattedTime)
                                .scaledFont(size: 52, weight: .bold, design: .rounded)
                                .foregroundColor(.white)
                                .monospacedDigit()
                            
                            if isRunning {
                                Text(".\(formattedMilliseconds)")
                                    .scaledFont(size: 24, weight: .medium, design: .rounded)
                                    .foregroundColor(.white.opacity(0.6))
                                    .monospacedDigit()
                            }
                        }
                        
                        // Progress bar
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 120, height: 4)
                            
                            Capsule()
                                .fill(Color.fromAccentString(selectedAccentColor))
                                .frame(width: 120 * progress, height: 4)
                        }
                        .padding(.vertical, 8)
                        
                        // Target time
                        Text("Target: \(formattedTarget)")
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundColor(.white.opacity(0.7))
                        
                        // Completion badge
                        if progress >= 1.0 {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .scaledFont(size: 16)
                                Text("Complete!")
                                    .scaledFont(size: 16, weight: .bold)
                            }
                            .foregroundColor(Color.yellow)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.yellow.opacity(0.2))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                                    )
                            )
                            .padding(.top, 8)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                
                Spacer(minLength: 20)
                
                // Controls with modern glass morphism
                VStack(spacing: 16) {
                    // Main control button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if isRunning {
                                pauseTimer()
                            } else {
                                startTimer()
                            }
                        }
                    } label: {
                        ZStack {
                            // Background with gradient
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: isRunning ? 
                                            [Color.orange, Color.red.opacity(0.8)] :
                                            [Color.white, Color.white.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: isRunning ? Color.orange.opacity(0.4) : Color.black.opacity(0.15), 
                                       radius: 12, y: 6)
                            
                            HStack(spacing: 10) {
                                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                    .scaledFont(size: 20, weight: .bold)
                                    .symbolEffect(.bounce, value: isRunning)
                                
                                Text(isRunning ? "Pause" : (timeElapsed > 0 ? "Resume" : "Start"))
                                    .scaledFont(size: 18, weight: .bold)
                            }
                            .foregroundColor(isRunning ? .white : .black)
                        }
                        .frame(width: 200, height: 56)
                    }
                    .scaleEffect(isRunning ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isRunning)
                    
                    // Secondary controls
                    HStack(spacing: 12) {
                        // Quick complete
                        Button {
                            quickComplete()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .scaledFont(size: 18)
                                Text("Quick")
                                    .scaledFont(size: 12, weight: .medium)
                            }
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.3),
                                                        Color.white.opacity(0.1)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                        
                        // Reset button
                        if timeElapsed > 0 && !isRunning {
                            Button {
                                withAnimation(.spring()) {
                                    resetTimer()
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .scaledFont(size: 18)
                                        .rotationEffect(.degrees(timeElapsed > 0 ? 0 : -180))
                                    Text("Reset")
                                        .scaledFont(size: 12, weight: .medium)
                                }
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 70, height: 70)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Add time shortcuts
                        if !isRunning && timeElapsed < targetTime {
                            Menu {
                                Button("+1 min") { 
                                    withAnimation {
                                        timeElapsed = min(timeElapsed + 60, targetTime)
                                    }
                                }
                                Button("+5 min") { 
                                    withAnimation {
                                        timeElapsed = min(timeElapsed + 300, targetTime)
                                    }
                                }
                                Button("Half way") { 
                                    withAnimation {
                                        timeElapsed = targetTime / 2
                                    }
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .scaledFont(size: 18)
                                    Text("Add")
                                        .scaledFont(size: 12, weight: .medium)
                                }
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 70, height: 70)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.fromAccentString(selectedAccentColor).opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.fromAccentString(selectedAccentColor).opacity(0.5), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .interactiveDismissDisabled(isRunning)
        .onAppear {
            loadExistingEntry()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            if isRunning {
                backgroundTime = Date()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if let backgroundTime = backgroundTime, isRunning {
                let elapsed = Date().timeIntervalSince(backgroundTime)
                timeElapsed += elapsed
                self.backgroundTime = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pauseTimer)) { _ in
            // Handle pause from Dynamic Island
            if isRunning {
                pauseTimer()
            } else {
                startTimer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopTimer)) { _ in
            // Handle stop from Dynamic Island
            saveProgress()
        }
    }
    
    private func loadExistingEntry() {
        // Check if there's already an entry for today
        if let entry = habit.entries?.first(where: { entry in
            guard let entry = entry as? HabitEntry,
                  let entryDate = entry.date else { return false }
            return Calendar.current.isDate(entryDate, inSameDayAs: date)
        }) as? HabitEntry {
            timeElapsed = entry.value * 60 // Convert minutes to seconds
        }
    }
    
    private func startTimer() {
        isRunning = true
        let now = Date()
        startTime = now.addingTimeInterval(-timeElapsed) // Account for existing elapsed time
        
        // Track session start for event creation
        if sessionStartTime == nil {
            sessionStartTime = now
        }
        
        // If resuming from a pause
        if let pauseTime = lastPauseTime {
            let pauseDuration = now.timeIntervalSince(pauseTime)
            
            // If pause was more than 10 minutes, create a new event for the previous session
            if pauseDuration > 600 { // 600 seconds = 10 minutes
                createHabitEvent(endTime: pauseTime)
                // Start a new session
                sessionStartTime = now
                totalPauseTime = 0
            } else {
                // Short pause, just track the pause time
                totalPauseTime += pauseDuration
            }
        }
        
        lastPauseTime = nil
        
        // Start Live Activity for Dynamic Island with current elapsed time
        AsyncTask {
            await liveActivityManager.startTimerActivity(for: habit, initialElapsedTime: timeElapsed)
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = startTime {
                // Calculate total elapsed time from start
                timeElapsed = Date().timeIntervalSince(startTime)
                
                // Auto-stop at target
                if timeElapsed >= targetTime && progress >= 1.0 {
                    pauseTimer()
                    HapticFeedback.success.trigger()
                }
            }
        }
    }
    
    private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        // Don't reset startTime - we need it to resume correctly
        
        // Track pause time
        lastPauseTime = Date()
        
        // Pause Live Activity
        AsyncTask {
            await liveActivityManager.pauseTimerActivity()
        }
    }
    
    private func resetTimer() {
        pauseTimer()
        
        // Don't create event for very short sessions (< 2 minutes)
        if let sessionStart = sessionStartTime {
            let sessionDuration = Date().timeIntervalSince(sessionStart) - totalPauseTime
            if sessionDuration >= 120 { // 2 minutes minimum
                createHabitEvent(endTime: Date())
            }
        }
        
        timeElapsed = 0
        startTime = nil
        sessionStartTime = nil
        lastPauseTime = nil
        totalPauseTime = 0
        
        // End Live Activity
        AsyncTask {
            await liveActivityManager.endCurrentActivity()
        }
    }
    
    private func quickComplete() {
        timeElapsed = targetTime
        sessionStartTime = sessionStartTime ?? Date()
        saveProgress()
    }
    
    private func saveProgress() {
        let minutes = timeElapsed / 60.0
        
        // Create event for the completed session (if duration >= 2 minutes)
        if timeElapsed >= 120 { // 2 minutes minimum
            createHabitEvent(endTime: Date())
        }
        
        _ = habitManager.logHabit(
            habit,
            value: minutes,
            date: date,
            notes: nil,
            mood: nil,
            duration: Int32(timeElapsed),
            quality: nil
        )
        
        HapticFeedback.success.trigger()
        
        // End Live Activity
        AsyncTask {
            await liveActivityManager.endCurrentActivity()
        }
        
        dismiss()
    }
    
    private func createHabitEvent(endTime: Date) {
        guard let sessionStart = sessionStartTime else { return }
        
        // Calculate actual duration (excluding pauses)
        let actualDuration = endTime.timeIntervalSince(sessionStart) - totalPauseTime
        
        // Only create event if duration is at least 2 minutes
        guard actualDuration >= 120 else { return }
        
        // Create the event
        let scheduleManager = ScheduleManager.shared
        let eventTitle = habit.name ?? "Habit Session"
        let eventNotes = "⏱️ Timer session for \(eventTitle)\nActual time: \(Int(actualDuration / 60)) minutes"
        
        _ = scheduleManager.createEvent(
            title: eventTitle,
            startTime: sessionStart,
            endTime: endTime,
            category: habit.category,
            notes: eventNotes,
            location: nil,
            isAllDay: false
        )
    }
}

// MARK: - Millisecond Ring Indicator
struct MillisecondRingIndicator: View {
    let timeElapsed: TimeInterval
    let accentColor: String
    
    var progress: Double {
        timeElapsed.truncatingRemainder(dividingBy: 1)
    }
    
    var body: some View {
        ZStack {
            // Subtle second tick marks
            ForEach(0..<60) { second in
                Rectangle()
                    .fill(Color.white.opacity(second % 5 == 0 ? 0.3 : 0.1))
                    .frame(width: second % 5 == 0 ? 2 : 1, height: second % 5 == 0 ? 8 : 4)
                    .offset(y: -165)
                    .rotationEffect(.degrees(Double(second) * 6))
            }
            
            // Smooth rotating indicator
            Circle()
                .fill(Color.fromAccentString(accentColor))
                .frame(width: 6, height: 6)
                .offset(y: -165)
                .rotationEffect(.degrees(progress * 360 - 90))
                .shadow(color: Color.fromAccentString(accentColor), radius: 4)
                .animation(.linear(duration: 0.1), value: progress)
        }
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
        }
    }
}

#Preview {
    let habit = Habit(context: PersistenceController.preview.container.viewContext)
    habit.name = "Meditation"
    habit.iconName = "brain"
    habit.colorHex = "#AF52DE"
    habit.trackingType = HabitTrackingType.duration.rawValue
    habit.goalTarget = 10 // 10 minutes
    
    return HabitTimerView(habit: habit, date: Date())
        .environmentObject(HabitManager.shared)
}