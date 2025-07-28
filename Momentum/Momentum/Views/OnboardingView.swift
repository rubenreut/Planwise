import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var scheduleManager: ScheduleManager
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                // Welcome Page
                OnboardingPage(
                    image: "calendar.badge.clock",
                    title: "Welcome to\nPlanwise",
                    description: "Your intelligent calendar assistant that transforms how you manage time.",
                    showButton: false
                )
                .tag(0)
                
                // AI Assistant Page
                OnboardingPage(
                    image: "brain",
                    title: "AI-Powered Scheduling",
                    description: "Simply tell the AI what you need to schedule. It understands natural language like 'Schedule a meeting tomorrow at 2pm'.",
                    showButton: false
                )
                .tag(1)
                
                // Smart Features Page
                OnboardingPage(
                    image: "sparkles",
                    title: "Smart Features",
                    description: "Natural language • Smart suggestions\nCategories • iCloud sync • And more",
                    showButton: false
                )
                .tag(2)
                
                // Sample Events Page
                SampleEventsPage(scheduleManager: scheduleManager)
                    .tag(3)
                
                // Premium Features Page
                PremiumFeaturesPage()
                    .tag(4)
                
                // Permissions Page
                PermissionsPage()
                    .tag(5)
                
                // Get Started Page
                GetStartedPage(showOnboarding: $showOnboarding, hasCompletedOnboarding: $hasCompletedOnboarding)
                    .tag(6)
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            
            // Skip/Next buttons
            HStack {
                if currentPage < 6 {
                    Button(action: {
                        currentPage = 6
                    }) {
                        Text("Skip")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentPage += 1
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text("Next")
                                .font(.system(size: 18, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
}

struct OnboardingPage: View {
    let image: String
    let title: String
    let description: String
    let showButton: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: image)
                    .font(.system(size: 70, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .symbolEffect(.bounce, value: UUID())
            }
            .padding(.bottom, 50)
            
            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 30)
            
            Spacer()
            Spacer()
        }
    }
}

struct SampleEventsPage: View {
    let scheduleManager: ScheduleManager
    @State private var isCreatingSamples = false
    @State private var samplesCreated = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.1), Color.green.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: "calendar.day.timeline.left")
                    .font(.system(size: 70, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color.mint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding(.bottom, 50)
            
            VStack(spacing: 20) {
                Text("Try Sample\nEvents")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("Add sample events to explore all the amazing features.")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
            }
            .padding(.horizontal, 30)
            
            VStack(spacing: 12) {
                if samplesCreated {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.green, Color.mint],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text("Sample events created!")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 20)
                } else {
                    Button(action: createSampleEvents) {
                        HStack(spacing: 10) {
                            if isCreatingSamples {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                            }
                            Text("Add Sample Events")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green, Color.mint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .disabled(isCreatingSamples)
                    
                    Text("You can delete these anytime")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            Spacer()
        }
    }
    
    private func createSampleEvents() {
        isCreatingSamples = true
        
        AsyncTask {
            let calendar = Calendar.current
            let today = Date()
            
            // Sample events
            let sampleEvents = [
                (title: "Morning Workout 🏃‍♂️", hour: 7, duration: 1, category: "Health"),
                (title: "Team Standup", hour: 9, duration: 0.5, category: "Work"),
                (title: "Deep Work Session", hour: 10, duration: 2, category: "Work"),
                (title: "Lunch Break 🍽️", hour: 12, duration: 1, category: "Personal"),
                (title: "Client Meeting", hour: 14, duration: 1.5, category: "Work"),
                (title: "Coffee with Sarah ☕", hour: 16, duration: 1, category: "Personal"),
                (title: "Evening Yoga 🧘‍♀️", hour: 18, duration: 1, category: "Health")
            ]
            
            for eventData in sampleEvents {
                if let startTime = calendar.date(bySettingHour: eventData.hour, minute: 0, second: 0, of: today),
                   let endTime = calendar.date(byAdding: .minute, value: Int(eventData.duration * 60), to: startTime) {
                    
                    // Find or create category
                    var category = scheduleManager.categories.first { $0.name == eventData.category }
                    if category == nil {
                        let categoryColor = eventData.category == "Work" ? "#007AFF" : 
                                          eventData.category == "Health" ? "#34C759" : "#FF9500"
                        let result = scheduleManager.createCategory(
                            name: eventData.category,
                            icon: "folder.fill",
                            colorHex: categoryColor
                        )
                        if case .success(let newCategory) = result {
                            category = newCategory
                        }
                    }
                    
                    let _ = scheduleManager.createEvent(
                        title: eventData.title,
                        startTime: startTime,
                        endTime: endTime,
                        category: category,
                        notes: "This is a sample event to help you explore Planwise",
                        location: nil,
                        isAllDay: false
                    )
                }
                
                // Small delay between events
                try? await _Concurrency.Task.sleep(nanoseconds: 100_000_000)
            }
            
            await MainActor.run {
                isCreatingSamples = false
                samplesCreated = true
            }
        }
    }
}

struct PremiumFeaturesPage: View {
    @State private var showingPaywall = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.1), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 70, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding(.bottom, 50)
            
            VStack(spacing: 20) {
                Text("Go Premium")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("Unlock unlimited AI messages, voice input, and image analysis.")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
            }
            .padding(.horizontal, 30)
            
            VStack(spacing: 16) {
                // Premium benefits
                VStack(alignment: .leading, spacing: 12) {
                    OnboardingFeatureRow(icon: "message.badge.filled.fill", text: "500 daily AI messages")
                    OnboardingFeatureRow(icon: "photo.on.rectangle.angled", text: "20 daily image/PDF uploads")
                    OnboardingFeatureRow(icon: "mic.fill", text: "Voice input")
                    OnboardingFeatureRow(icon: "bolt.fill", text: "Priority support")
                }
                .padding(.vertical, 20)
                
                Button(action: {
                    showingPaywall = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 20))
                        Text("View Plans")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                
                Text("Start with 10 free messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            Spacer()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
}

struct OnboardingFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.pink],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 30)
            
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct PermissionsPage: View {
    @State private var notificationStatus = "Not Requested"
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.1), Color.orange.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: "bell.badge")
                    .font(.system(size: 70, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding(.bottom, 50)
            
            VStack(spacing: 20) {
                Text("Stay On\nSchedule")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("Get timely reminders so you never miss important events.")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
            }
            .padding(.horizontal, 30)
            
            VStack(spacing: 16) {
                Button(action: requestNotificationPermission) {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 20))
                        Text("Enable Notifications")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                
                Text(notificationStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            Spacer()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                notificationStatus = granted ? "Notifications Enabled ✓" : "Notifications Denied"
            }
        }
    }
}

struct GetStartedPage: View {
    @Binding var showOnboarding: Bool
    @Binding var hasCompletedOnboarding: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.1), Color.green.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color.mint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .symbolEffect(.bounce, value: UUID())
            }
            .padding(.bottom, 50)
            
            VStack(spacing: 20) {
                Text("You're\nAll Set!")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("Let's create your perfect schedule together.")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
            }
            .padding(.horizontal, 30)
            
            Button(action: {
                hasCompletedOnboarding = true
                showOnboarding = false
            }) {
                HStack(spacing: 10) {
                    Text("Get Started")
                        .font(.system(size: 20, weight: .bold))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 22))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 50)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.blue.opacity(0.3), radius: 20, x: 0, y: 10)
                )
            }
            .padding(.top, 30)
            
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
        .environmentObject(ScheduleManager.shared)
}