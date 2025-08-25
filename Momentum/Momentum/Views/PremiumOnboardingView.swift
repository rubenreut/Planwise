//
//  PremiumOnboardingView.swift
//  Planwise
//
//  Premium onboarding experience with smooth animations
//

import SwiftUI
import CoreData

@available(iOS 15.0, *)
struct PremiumOnboardingView: View {
    @State private var currentStep = 0
    @State private var userName = ""
    @State private var wakeTime = Date()
    @State private var selectedCategories: Set<String> = []
    @State private var firstGoal = ""
    @State private var selectedSetupMode = "guided"
    @State private var isAnimating = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var slideOffset: CGFloat = 50
    
    @Environment(\.dismiss) var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userWakeTimeInterval") private var userWakeTimeInterval: Double = Date().timeIntervalSince1970
    @AppStorage("userDisplayName") private var userDisplayName = ""
    
    private var userWakeTime: Date {
        get { Date(timeIntervalSince1970: userWakeTimeInterval) }
        set { userWakeTimeInterval = newValue.timeIntervalSince1970 }
    }
    @EnvironmentObject var scheduleManager: ScheduleManager
    
    let categories = [
        ("briefcase.fill", "Work & Projects", "work"),
        ("heart.fill", "Health & Fitness", "health"),
        ("book.fill", "Learning & Growth", "learning"),
        ("person.2.fill", "Family & Friends", "family"),
        ("star.fill", "Personal Time", "personal")
    ]
    
    var body: some View {
        ZStack {
            // Gradient background matching app theme
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.15, blue: 0.35),
                    Color(red: 0.12, green: 0.25, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                if currentStep > 0 && currentStep < 5 {
                    OnboardingProgressBar(progress: Double(currentStep) / 5.0)
                        .frame(height: 3)
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Content
                Group {
                    switch currentStep {
                    case 0:
                        WelcomeScreen(
                            logoScale: $logoScale,
                            logoOpacity: $logoOpacity,
                            contentOpacity: $contentOpacity,
                            onContinue: nextStep
                        )
                    case 1:
                        PersonalizationScreen(
                            userName: $userName,
                            contentOpacity: $contentOpacity
                        )
                    case 2:
                        HowItWorksScreen(
                            contentOpacity: $contentOpacity
                        )
                    case 3:
                        SetupModeScreen(
                            selectedMode: $selectedSetupMode,
                            contentOpacity: $contentOpacity
                        )
                    case 4:
                        NotificationScreen(
                            contentOpacity: $contentOpacity
                        )
                    case 5:
                        CompletionScreen(
                            userName: userName,
                            isAnimating: $isAnimating
                        )
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Navigation buttons
                if currentStep > 0 && currentStep < 5 {
                    HStack(spacing: 20) {
                        // Skip button for non-essential screens
                        if currentStep == 2 || currentStep == 3 || currentStep == 4 {
                            Button(action: { nextStep() }) {
                                Text("Skip")
                                    .scaledFont(size: 16, weight: .medium)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.leading, 30)
                        }
                        
                        Spacer()
                        
                        // Continue button
                        Button(action: nextStep) {
                            HStack {
                                Text(buttonText)
                                    .scaledFont(size: 18, weight: .semibold)
                                if currentStep < 4 {
                                    Image(systemName: "arrow.right")
                                        .scaledFont(size: 18, weight: .semibold)
                                }
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, currentStep == 4 ? 50 : 40)
                            .padding(.vertical, 18)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                            )
                        }
                        .disabled(!canProceed)
                        .opacity(canProceed ? 1 : 0.5)
                        .scaleEffect(canProceed ? 1 : 0.95)
                        .animation(.spring(response: 0.3), value: canProceed)
                        .padding(.trailing, 30)
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            if currentStep == 0 {
                startWelcomeAnimation()
            }
        }
    }
    
    var canProceed: Bool {
        switch currentStep {
        case 1:
            return !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }
    
    var buttonText: String {
        switch currentStep {
        case 1: return "Continue"
        case 2: return "Got it"
        case 3: return "Continue"
        case 4: return "Start Using Planwise"
        default: return "Continue"
        }
    }
    
    func startWelcomeAnimation() {
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.6)) {
                contentOpacity = 1.0
            }
        }
    }
    
    func nextStep() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            if currentStep == 4 {
                // Save everything and finish
                userDisplayName = userName
                if selectedSetupMode == "sample" {
                    createSampleSchedule()
                } else {
                    createBasicSetup()
                }
                
                // Show completion
                currentStep = 5
                
                // Trigger completion animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isAnimating = true
                }
                
                // Dismiss after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    hasCompletedOnboarding = true
                    dismiss()
                }
            } else {
                currentStep += 1
                contentOpacity = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        contentOpacity = 1
                    }
                }
            }
        }
    }
    
    func previousStep() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep -= 1
            contentOpacity = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.5)) {
                    contentOpacity = 1
                }
            }
        }
    }
    
    func saveSelectedCategories() {
        // Actually create the selected categories in the app
        let context = PersistenceController.shared.container.viewContext
        
        // Category configurations with proper colors and icons
        let categoryConfigs: [String: (color: String, icon: String, name: String)] = [
            "work": ("#007AFF", "briefcase.fill", "Work & Projects"),
            "health": ("#34C759", "heart.fill", "Health & Fitness"),
            "learning": ("#AF52DE", "book.fill", "Learning & Growth"),
            "family": ("#FF9500", "person.2.fill", "Family & Friends"),
            "personal": ("#FF2D55", "star.fill", "Personal Time")
        ]
        
        for categoryId in selectedCategories {
            if let config = categoryConfigs[categoryId] {
                // Check if category already exists
                let fetchRequest = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", config.name)
                
                if let existing = try? context.fetch(fetchRequest).first {
                    // Category exists, just make sure it's active
                    existing.isActive = true
                } else {
                    // Create new category
                    let category = Category(context: context)
                    category.id = UUID()
                    category.name = config.name
                    category.colorHex = config.color
                    category.iconName = config.icon
                    category.isActive = true
                    category.createdAt = Date()
                }
            }
        }
        
        try? context.save()
    }
    
    func saveFirstGoal() {
        // Actually create the first task in the system
        if !firstGoal.isEmpty {
            let context = PersistenceController.shared.container.viewContext
            
            // Create as a task (more immediate than a goal)
            let task = Task(context: context)
            task.id = UUID()
            task.title = firstGoal
            task.createdAt = Date()
            task.priority = 2 // Medium priority
            task.isCompleted = false
            
            // Set due date to end of this week
            let calendar = Calendar.current
            if let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.end {
                task.dueDate = calendar.date(byAdding: .day, value: -1, to: endOfWeek)
            }
            
            // Assign to first selected category if any
            if let firstCategory = selectedCategories.first,
               let categoryName = getCategoryName(for: firstCategory) {
                let fetchRequest = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", categoryName)
                task.category = try? context.fetch(fetchRequest).first
            }
            
            // Also create a morning planning block for today
            let event = Event(context: context)
            event.id = UUID()
            event.title = "Morning Planning"
            event.notes = "Review your day and plan your priorities"
            event.startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
            event.endTime = calendar.date(bySettingHour: 9, minute: 15, second: 0, of: Date())
            event.isCompleted = false
            event.createdAt = Date()
            
            try? context.save()
            
            // Save to UserDefaults for reference
            UserDefaults.standard.set(firstGoal, forKey: "firstGoal")
        }
    }
    
    private func getCategoryName(for id: String) -> String? {
        let configs: [String: String] = [
            "work": "Work & Projects",
            "health": "Health & Fitness",
            "learning": "Learning & Growth",
            "family": "Family & Friends",
            "personal": "Personal Time"
        ]
        return configs[id]
    }
    
    func createSampleSchedule() {
        let context = PersistenceController.shared.container.viewContext
        let calendar = Calendar.current
        let today = Date()
        
        // Create categories first
        createBasicSetup()
        
        // Create a realistic sample day
        let sampleEvents = [
            (9, 0, 9, 30, "Morning Planning", "Review priorities for the day"),
            (9, 30, 11, 30, "Deep Work", "Focus on most important project"),
            (11, 30, 12, 0, "Email & Messages", "Catch up on communications"),
            (12, 0, 13, 0, "Lunch Break", ""),
            (13, 0, 15, 0, "Team Meeting", "Weekly sync"),
            (15, 0, 16, 30, "Project Work", "Continue morning tasks"),
            (16, 30, 17, 0, "Daily Review", "Plan for tomorrow"),
            (18, 0, 19, 0, "Gym", "Workout session"),
            (20, 0, 21, 0, "Personal Time", "Relax and unwind")
        ]
        
        for (startHour, startMin, endHour, endMin, title, notes) in sampleEvents {
            let event = Event(context: context)
            event.id = UUID()
            event.title = title
            event.notes = notes.isEmpty ? nil : notes
            event.startTime = calendar.date(bySettingHour: startHour, minute: startMin, second: 0, of: today)
            event.endTime = calendar.date(bySettingHour: endHour, minute: endMin, second: 0, of: today)
            event.isCompleted = false
            event.createdAt = Date()
            
            // Assign categories
            if title.contains("Work") || title.contains("Meeting") || title.contains("Project") {
                let fetchRequest = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", "Work")
                event.category = try? context.fetch(fetchRequest).first
            } else if title.contains("Gym") || title.contains("Personal") {
                let fetchRequest = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", "Personal")
                event.category = try? context.fetch(fetchRequest).first
            }
        }
        
        // Add a few sample tasks
        let sampleTasks = [
            ("Finish presentation slides", 3),
            ("Review contract proposal", 2),
            ("Call dentist for appointment", 1),
            ("Buy groceries", 1)
        ]
        
        for (title, priority) in sampleTasks {
            let task = Task(context: context)
            task.id = UUID()
            task.title = title
            task.createdAt = Date()
            task.priority = Int16(priority)
            task.isCompleted = false
            
            if priority == 3 {
                task.dueDate = today
            }
        }
        
        try? context.save()
    }
    
    func createBasicSetup() {
        let context = PersistenceController.shared.container.viewContext
        
        // Create just the essential categories
        let essentialCategories = [
            ("Work", "#007AFF", "briefcase.fill"),
            ("Personal", "#34C759", "person.fill"),
            ("Other", "#8E8E93", "folder.fill")
        ]
        
        for (name, color, icon) in essentialCategories {
            let category = Category(context: context)
            category.id = UUID()
            category.name = name
            category.colorHex = color
            category.iconName = icon
            category.isActive = true
            category.createdAt = Date()
        }
        
        // Create ONE sample task to get them started
        let task = Task(context: context)
        task.id = UUID()
        task.title = "Tap + to add your first task"
        task.createdAt = Date()
        task.priority = 2
        task.isCompleted = false
        
        try? context.save()
    }
    
    func createDefaultSchedule() {
        let context = PersistenceController.shared.container.viewContext
        let calendar = Calendar.current
        let today = Date()
        
        // Get wake hour and minute
        let wakeHour = calendar.component(.hour, from: wakeTime)
        let wakeMinute = calendar.component(.minute, from: wakeTime)
        
        // Create a FULL DAY schedule based on their wake time
        var currentTime = calendar.date(bySettingHour: wakeHour, 
                                       minute: wakeMinute, 
                                       second: 0, 
                                       of: today) ?? Date()
        
        // 1. Morning Routine (30 min)
        let morningRoutine = Event(context: context)
        morningRoutine.id = UUID()
        morningRoutine.title = "☀️ Morning Routine"
        morningRoutine.notes = "Hydrate, stretch, review your day"
        morningRoutine.startTime = currentTime
        morningRoutine.endTime = calendar.date(byAdding: .minute, value: 30, to: currentTime)
        morningRoutine.isCompleted = false
        morningRoutine.createdAt = Date()
        
        currentTime = calendar.date(byAdding: .minute, value: 30, to: currentTime) ?? currentTime
        
        // 2. Planning Session (15 min)
        let planning = Event(context: context)
        planning.id = UUID()
        planning.title = "📝 Daily Planning"
        planning.notes = "Review priorities and schedule"
        planning.startTime = currentTime
        planning.endTime = calendar.date(byAdding: .minute, value: 15, to: currentTime)
        planning.isCompleted = false
        planning.createdAt = Date()
        
        currentTime = calendar.date(byAdding: .minute, value: 15, to: currentTime) ?? currentTime
        
        // Add work blocks if work was selected
        if selectedCategories.contains("work") {
            // Deep work session
            let workTime = calendar.date(byAdding: .minute, value: 30, to: currentTime) ?? currentTime
            let deepWork = Event(context: context)
            deepWork.id = UUID()
            deepWork.title = "Deep Work Session"
            deepWork.notes = "Focus on your most important task"
            deepWork.startTime = workTime
            deepWork.endTime = calendar.date(byAdding: .hour, value: 2, to: workTime)
            deepWork.isCompleted = false
            deepWork.createdAt = Date()
            
            // Assign work category
            let fetchRequest = Category.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", "Work & Projects")
            deepWork.category = try? context.fetch(fetchRequest).first
        }
        
        // Add fitness block if health was selected
        if selectedCategories.contains("health") {
            let exerciseTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: today) ?? Date()
            let exercise = Event(context: context)
            exercise.id = UUID()
            exercise.title = "Workout"
            exercise.notes = "Stay active and healthy"
            exercise.startTime = exerciseTime
            exercise.endTime = calendar.date(byAdding: .hour, value: 1, to: exerciseTime)
            exercise.isCompleted = false
            exercise.createdAt = Date()
            
            // Assign health category
            let fetchRequest = Category.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", "Health & Fitness")
            exercise.category = try? context.fetch(fetchRequest).first
        }
        
        // Evening wind-down
        let windDownTime = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: today) ?? Date()
        let windDown = Event(context: context)
        windDown.id = UUID()
        windDown.title = "Evening Wind-down"
        windDown.notes = "Relax and prepare for tomorrow"
        windDown.startTime = windDownTime
        windDown.endTime = calendar.date(byAdding: .minute, value: 30, to: windDownTime)
        windDown.isCompleted = false
        windDown.createdAt = Date()
        
        try? context.save()
    }
}

// MARK: - Welcome Screen
@available(iOS 15.0, *)
struct WelcomeScreen: View {
    @Binding var logoScale: CGFloat
    @Binding var logoOpacity: Double
    @Binding var contentOpacity: Double
    let onContinue: () -> Void
    @State private var floating = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated logo
            Image(systemName: "calendar.badge.clock")
                .scaledFont(size: 80, weight: .thin)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .offset(y: floating ? -10 : 10)
                .animation(
                    Animation.easeInOut(duration: 3)
                        .repeatForever(autoreverses: true),
                    value: floating
                )
                .onAppear { floating = true }
            
            VStack(spacing: 20) {
                Text("Planwise")
                    .scaledFont(size: 48, weight: .bold)
                    .foregroundColor(.white)
                
                Text("Plan your perfect day")
                    .scaledFont(size: 20, weight: .medium)
                    .foregroundColor(.white.opacity(0.8))
            }
            .opacity(contentOpacity)
            
            Spacer()
            
            Button(action: onContinue) {
                HStack {
                    Text("Let's get started")
                        .scaledFont(size: 18, weight: .semibold)
                    Image(systemName: "arrow.right")
                        .scaledFont(size: 18, weight: .semibold)
                }
                .foregroundColor(.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                )
            }
            .opacity(contentOpacity)
            .padding(.bottom, 60)
        }
    }
}

// MARK: - How It Works Screen
@available(iOS 15.0, *)
struct HowItWorksScreen: View {
    @Binding var contentOpacity: Double
    @State private var animatedItems = Set<Int>()
    
    let features = [
        ("Drag to schedule", "clock.arrow.2.circlepath", "Drag any task into your timeline"),
        ("AI Assistant", "sparkles", "Just tell the AI what you need"),
        ("Smart reminders", "bell.badge", "Never miss what matters")
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 20) {
                Text("How Planwise Works")
                    .scaledFont(size: 28, weight: .semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 80)
            .opacity(contentOpacity)
            
            VStack(spacing: 24) {
                ForEach(features.indices, id: \.self) { index in
                    HStack(spacing: 20) {
                        Image(systemName: features[index].1)
                            .scaledFont(size: 28)
                            .foregroundColor(.white)
                            .frame(width: 50)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(features[index].0)
                                .scaledFont(size: 18, weight: .semibold)
                                .foregroundColor(.white)
                            
                            Text(features[index].2)
                                .scaledFont(size: 14)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                    .opacity(contentOpacity)
                    .scaleEffect(animatedItems.contains(index) ? 1 : 0.8)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                            withAnimation(.spring(response: 0.5)) {
                                _ = animatedItems.insert(index)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Setup Mode Screen
@available(iOS 15.0, *)
struct SetupModeScreen: View {
    @Binding var selectedMode: String
    @Binding var contentOpacity: Double
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 20) {
                Text("Choose Your Start")
                    .scaledFont(size: 28, weight: .semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("You can always change this later")
                    .scaledFont(size: 16)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 80)
            .opacity(contentOpacity)
            
            VStack(spacing: 16) {
                SetupModeCard(
                    title: "Start Fresh",
                    subtitle: "Begin with a clean slate",
                    icon: "sparkles",
                    isSelected: selectedMode == "fresh",
                    action: { selectedMode = "fresh" }
                )
                
                SetupModeCard(
                    title: "Sample Schedule",
                    subtitle: "See an example day to get inspired",
                    icon: "calendar.badge.plus",
                    isSelected: selectedMode == "sample",
                    action: { selectedMode = "sample" }
                )
            }
            .padding(.horizontal, 30)
            .opacity(contentOpacity)
            
            Spacer()
        }
    }
}

// MARK: - Notification Screen
@available(iOS 15.0, *)
struct NotificationScreen: View {
    @Binding var contentOpacity: Double
    @State private var notificationsEnabled = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "bell.badge")
                    .scaledFont(size: 60)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text("Stay on Track")
                    .scaledFont(size: 28, weight: .semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Get gentle reminders for your\nscheduled events and tasks")
                    .scaledFont(size: 16)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .opacity(contentOpacity)
            
            Button(action: {
                // Request notification permission
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    notificationsEnabled = granted
                }
            }) {
                Text("Enable Notifications")
                    .scaledFont(size: 18, weight: .medium)
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.white)
                    )
            }
            .opacity(contentOpacity)
            
            Spacer()
        }
    }
}

// MARK: - Supporting Views for New Screens
@available(iOS 15.0, *)
struct SetupModeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .scaledFont(size: 24)
                    .foregroundColor(isSelected ? .black : .white)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .scaledFont(size: 18, weight: .semibold)
                        .foregroundColor(isSelected ? .black : .white)
                    
                    Text(subtitle)
                        .scaledFont(size: 14)
                        .foregroundColor(isSelected ? .black.opacity(0.7) : .white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .scaledFont(size: 24)
                    .foregroundColor(isSelected ? .green : .white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(isSelected ? 0 : 0.2), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Daily Rhythm Screen
@available(iOS 15.0, *)
struct DailyRhythmScreen: View {
    @Binding var wakeTime: Date
    @Binding var slideOffset: CGFloat
    @Binding var contentOpacity: Double
    @State private var isPickerPresented = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "sunrise.fill")
                    .scaledFont(size: 60)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(x: slideOffset)
                
                Text("When do you start your day?")
                    .scaledFont(size: 28, weight: .semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("This helps us organize your schedule")
                    .scaledFont(size: 16)
                    .foregroundColor(.white.opacity(0.7))
            }
            .opacity(contentOpacity)
            
            // Time display
            Button(action: { isPickerPresented = true }) {
                VStack(spacing: 8) {
                    Text(wakeTime, style: .time)
                        .scaledFont(size: 48, weight: .medium, design: .rounded)
                        .foregroundColor(.white)
                    
                    Text("Tap to change")
                        .scaledFont(size: 14)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .opacity(contentOpacity)
            
            Spacer()
        }
        .sheet(isPresented: $isPickerPresented) {
            TimePickerSheet(selectedTime: $wakeTime)
        }
    }
}

// MARK: - Focus Areas Screen
@available(iOS 15.0, *)
struct FocusAreasScreen: View {
    @Binding var selectedCategories: Set<String>
    let categories: [(String, String, String)]
    @Binding var contentOpacity: Double
    @State private var animatedCategories: Set<String> = []
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 20) {
                Text("What's important to you?")
                    .scaledFont(size: 28, weight: .semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Select the areas you want to focus on")
                    .scaledFont(size: 16)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 60)
            .opacity(contentOpacity)
            
            VStack(spacing: 16) {
                ForEach(categories, id: \.2) { icon, title, id in
                    CategoryCard(
                        icon: icon,
                        title: title,
                        isSelected: selectedCategories.contains(id),
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedCategories.contains(id) {
                                    selectedCategories.remove(id)
                                } else {
                                    selectedCategories.insert(id)
                                }
                            }
                        }
                    )
                    .opacity(contentOpacity)
                    .scaleEffect(animatedCategories.contains(id) ? 1.05 : 1.0)
                }
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
    }
}

// MARK: - First Goal Screen
@available(iOS 15.0, *)
struct FirstGoalScreen: View {
    @Binding var firstGoal: String
    @Binding var contentOpacity: Double
    @FocusState private var isFocused: Bool
    
    let examples = [
        "Finish project proposal",
        "Go to gym 3 times",
        "Read 50 pages",
        "Organize workspace"
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "flag.fill")
                    .scaledFont(size: 60)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text("What would you like to\naccomplish this week?")
                    .scaledFont(size: 28, weight: .semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .opacity(contentOpacity)
            
            VStack(spacing: 20) {
                TextField("Enter your goal", text: $firstGoal)
                    .scaledFont(size: 18)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .focused($isFocused)
                
                // Examples
                VStack(alignment: .leading, spacing: 12) {
                    Text("Examples:")
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundColor(.white.opacity(0.5))
                    
                    ForEach(examples, id: \.self) { example in
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .scaledFont(size: 12)
                                .foregroundColor(.white.opacity(0.3))
                            Text(example)
                                .scaledFont(size: 14)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 30)
            .opacity(contentOpacity)
            
            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isFocused = true
            }
        }
    }
}

// MARK: - Personalization Screen
@available(iOS 15.0, *)
struct PersonalizationScreen: View {
    @Binding var userName: String
    @Binding var contentOpacity: Double
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.fill")
                    .scaledFont(size: 80)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text("What should we call you?")
                    .scaledFont(size: 28, weight: .semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Just your first name is perfect")
                    .scaledFont(size: 16)
                    .foregroundColor(.white.opacity(0.7))
            }
            .opacity(contentOpacity)
            
            TextField("Your name", text: $userName)
                .scaledFont(size: 24, weight: .medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 60)
                .focused($isFocused)
                .opacity(contentOpacity)
            
            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isFocused = true
            }
        }
    }
}

// MARK: - Completion Screen
@available(iOS 15.0, *)
struct CompletionScreen: View {
    let userName: String
    @Binding var isAnimating: Bool
    @State private var checkmarkScale: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var particlesVisible = false
    
    var body: some View {
        ZStack {
            // Particle effect
            if particlesVisible {
                ForEach(0..<20, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.3...0.7)))
                        .frame(width: CGFloat.random(in: 4...8))
                        .offset(
                            x: particlesVisible ? CGFloat.random(in: -200...200) : 0,
                            y: particlesVisible ? CGFloat.random(in: -300...300) : 0
                        )
                        .scaleEffect(particlesVisible ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.5)
                            .delay(Double(index) * 0.05),
                            value: particlesVisible
                        )
                }
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Checkmark animation
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(checkmarkScale)
                    
                    Image(systemName: "checkmark")
                        .scaledFont(size: 60, weight: .bold)
                        .foregroundColor(.green)
                        .scaleEffect(checkmarkScale)
                }
                
                VStack(spacing: 20) {
                    Text("Welcome, \(userName)!")
                        .scaledFont(size: 32, weight: .bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Let's plan your day")
                        .scaledFont(size: 18)
                        .foregroundColor(.white.opacity(0.8))
                }
                .opacity(textOpacity)
                
                Spacer()
            }
        }
        .onAppear {
            if isAnimating {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    checkmarkScale = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        textOpacity = 1.0
                    }
                    particlesVisible = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

@available(iOS 15.0, *)
struct OnboardingProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                
                Rectangle()
                    .fill(Color.white)
                    .frame(width: max(0, geometry.size.width * progress))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            }
        }
    }
}

@available(iOS 15.0, *)
struct CategoryCard: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .scaledFont(size: 24)
                    .foregroundColor(isSelected ? .black : .white)
                    .frame(width: 40)
                
                Text(title)
                    .scaledFont(size: 18, weight: .medium)
                    .foregroundColor(isSelected ? .black : .white)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .scaledFont(size: 24)
                    .foregroundColor(isSelected ? .green : .white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(isSelected ? 0 : 0.2), lineWidth: 1)
                    )
            )
        }
    }
}

@available(iOS 15.0, *)
struct TimePickerSheet: View {
    @Binding var selectedTime: Date
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Wake Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .padding()
                
                Spacer()
            }
            .navigationTitle("Select Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
@available(iOS 15.0, *)
struct PremiumOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        PremiumOnboardingView()
    }
}