import SwiftUI
import UserNotifications

struct OnboardingViewPremium: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var scheduleManager: ScheduleManager
    @State private var userName = ""
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            // Content
            TabView(selection: $currentPage) {
                WelcomePage(userName: $userName) {
                    withAnimation {
                        currentPage = 1
                    }
                }
                .tag(0)
                
                ValuePropositionPage()
                    .tag(1)
                
                AIShowcasePage()
                    .tag(2)
                
                PaywallPageEmbedded()
                    .tag(3)
                
                NotificationsPermissionPage(currentPage: $currentPage)
                    .tag(4)
                
                ReadyToGoPage(
                    userName: userName,
                    showOnboarding: $showOnboarding,
                    hasCompletedOnboarding: $hasCompletedOnboarding
                )
                .tag(5)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Custom page indicator and navigation
            VStack {
                Spacer()
                
                VStack(spacing: 15) {
                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<6) { index in
                            Capsule()
                                .fill(currentPage == index ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: currentPage == index ? 28 : 8, height: 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPage)
                        }
                    }
                    
                    // Navigation buttons
                    HStack {
                        if currentPage > 0 {
                            Button(action: {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.blue)
                                    .frame(width: 50, height: 50)
                                    .background(Circle().fill(Color.blue.opacity(0.1)))
                            }
                        } else {
                            Color.clear.frame(width: 50, height: 50)
                        }
                        
                        Spacer()
                        
                        if currentPage < 5 {
                            Button(action: {
                                withAnimation {
                                    currentPage += 1
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Text(currentPage == 0 && userName.isEmpty ? "Skip" : "Continue")
                                        .font(.system(size: 18, weight: .semibold))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.vertical, 15)
                .padding(.bottom, 15)
                .background(
                    Color(UIColor.systemBackground)
                        .opacity(0.85)
                        .ignoresSafeArea()
                )
            }
        }
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {
    @Binding var userName: String
    @State private var animateWelcome = false
    var onNameSubmit: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated logo
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateWelcome ? 1.0 : 0.8)
                    .opacity(animateWelcome ? 1.0 : 0.0)
                
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.blue)
                    .scaleEffect(animateWelcome ? 1.0 : 0.5)
                    .opacity(animateWelcome ? 1.0 : 0.0)
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                    animateWelcome = true
                }
            }
            
            VStack(spacing: 16) {
                Text("Welcome to")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Planwise")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            // Personal touch
            VStack(spacing: 16) {
                Text("Let's personalize your experience")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                
                TextField("Your name", text: $userName)
                    .font(.system(size: 18))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )
                    .padding(.horizontal, 40)
                    .submitLabel(.done)
                    .onSubmit {
                        // Dismiss keyboard and advance to next page
                        onNameSubmit()
                    }
            }
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Value Proposition Page

struct ValuePropositionPage: View {
    @State private var animateFeatures = false
    
    let features = [
        ("clock.arrow.circlepath", "Save 10+ hours weekly", "AI scheduling that learns your preferences"),
        ("brain", "Natural language input", "Just say what you need to do"),
        ("chart.line.uptrend.xyaxis", "Track everything", "Tasks, habits, goals in one place")
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Your productivity")
                    .font(.system(size: 32, weight: .bold))
                Text("supercharged")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 24) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(spacing: 20) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: feature.0)
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                        }
                        .scaleEffect(animateFeatures ? 1.0 : 0.0)
                        .opacity(animateFeatures ? 1.0 : 0.0)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7)
                            .delay(Double(index) * 0.2),
                            value: animateFeatures
                        )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(feature.1)
                                .font(.system(size: 18, weight: .semibold))
                            Text(feature.2)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                }
            }
            .onAppear {
                animateFeatures = true
            }
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - AI Showcase Page

struct AIShowcasePage: View {
    @State private var messages: [(String, Bool)] = []
    @State private var currentMessageIndex = 0
    
    let demoMessages = [
        ("Schedule a team meeting tomorrow at 2pm", false),
        ("I'll schedule your team meeting for tomorrow at 2:00 PM. Would you like to add any details?", true),
        ("Add lunch with Sarah on Friday", false),
        ("Perfect! I've added lunch with Sarah for Friday at 12:00 PM.", true)
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "message.badge.filled.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("AI that understands you")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
            }
            
            // Chat demo
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                    ChatBubble(text: message.0, isAI: message.1)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding(.horizontal, 30)
            .frame(maxHeight: 300)
            .onAppear {
                animateMessages()
            }
            
            Spacer()
            Spacer()
        }
    }
    
    private func animateMessages() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if currentMessageIndex < demoMessages.count {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    messages.append(demoMessages[currentMessageIndex])
                }
                currentMessageIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

struct ChatBubble: View {
    let text: String
    let isAI: Bool
    
    var body: some View {
        HStack {
            if !isAI { Spacer() }
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(isAI ? .primary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isAI ? Color.gray.opacity(0.1) : Color.blue)
                )
            
            if isAI { Spacer() }
        }
    }
}

// MARK: - Paywall Page Embedded

struct PaywallPageEmbedded: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPlan: PaywallViewPremium.PricingPlan = .annual
    @State private var showingError = false
    @State private var errorMessage = ""
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Text("Unlock Premium")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("Choose the perfect plan for you")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Pricing cards
                VStack(spacing: 16) {
                    ForEach(PaywallViewPremium.PricingPlan.allCases, id: \.self) { plan in
                        PricingCard(
                            plan: plan,
                            isSelected: selectedPlan == plan,
                            action: { selectedPlan = plan },
                            subscriptionManager: subscriptionManager
                        )
                    }
                }
                .padding(.horizontal)
                
                // Features comparison
                FeaturesComparisonView()
                    .padding(.horizontal)
                
                // Purchase button
                Button(action: purchase) {
                    HStack {
                        if subscriptionManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Continue with \(selectedPlan.displayName)")
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(subscriptionManager.isLoading)
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Restore purchases button
                Button(action: restore) {
                    Text("Restore Purchases")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .disabled(subscriptionManager.isLoading)
                
                // Trust badges
                HStack(spacing: 32) {
                    TrustBadge(icon: "lock.fill", text: "Secure\nPayment")
                    TrustBadge(icon: "arrow.triangle.2.circlepath", text: "Cancel\nAnytime")
                }
                .padding(.vertical, 20)
                
                // Skip for now button
                Button(action: {
                    // Just continue without purchasing
                }) {
                    Text("Maybe later")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Terms and Privacy
                VStack(spacing: 8) {
                    HStack(spacing: 20) {
                        Link("Terms", destination: URL(string: "https://rubenreut.github.io/Planwise-legal/terms-of-service.html")!)
                        Link("Privacy", destination: URL(string: "https://rubenreut.github.io/Planwise-legal/privacy-policy.html")!)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    
                    Text("Cancel anytime • Renews automatically")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.top, 10)
                .padding(.bottom, 120) // Add extra padding to avoid overlap with navigation
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func purchase() {
        let productId = selectedPlan == .monthly ? "com.rubenreut.planwise.pro.monthly" : "com.rubenreut.planwise.pro.annual"
        guard let product = subscriptionManager.products.first(where: { $0.id == productId }) else {
            errorMessage = "Product not found"
            showingError = true
            return
        }
        
        _Concurrency.Task {
            do {
                try await subscriptionManager.purchase(product)
                await MainActor.run {
                    if subscriptionManager.isPremium {
                        // Purchase successful, continue onboarding
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func restore() {
        _Concurrency.Task {
            do {
                try await subscriptionManager.restorePurchases()
                await MainActor.run {
                    if subscriptionManager.isPremium {
                        // Restore successful, continue onboarding
                    } else {
                        errorMessage = "No purchases found to restore"
                        showingError = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Notifications Permission Page

struct NotificationsPermissionPage: View {
    @State private var animateIcon = false
    @Binding var currentPage: Int
    
    init(currentPage: Binding<Int> = .constant(4)) {
        self._currentPage = currentPage
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated bell icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateIcon ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                        value: animateIcon
                    )
                
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(animateIcon ? -10 : 10))
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true),
                        value: animateIcon
                    )
            }
            .onAppear {
                animateIcon = true
            }
            
            VStack(spacing: 16) {
                Text("Stay on Track")
                    .font(.system(size: 32, weight: .bold))
                
                Text("Get gentle reminders for your tasks, habits, and events")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Benefits list
            VStack(alignment: .leading, spacing: 20) {
                NotificationBenefit(
                    icon: "clock.arrow.circlepath",
                    title: "Never miss important tasks",
                    subtitle: "Timely reminders keep you productive"
                )
                
                NotificationBenefit(
                    icon: "checkmark.circle.fill",
                    title: "Build better habits",
                    subtitle: "Daily nudges help form lasting routines"
                )
                
                NotificationBenefit(
                    icon: "bell.slash",
                    title: "Full control",
                    subtitle: "Customize or disable anytime in settings"
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Enable button
            Button(action: requestNotificationPermission) {
                HStack {
                    Image(systemName: "bell.fill")
                    Text("Enable Notifications")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.blue)
                .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            
            // Skip button
            Button(action: {
                // Just continue without enabling
                withAnimation {
                    currentPage = 5
                }
            }) {
                Text("Not now")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 120)
        }
    }
    
    private func requestNotificationPermission() {
        #if DEBUG
        print("🔔 DEBUG: requestNotificationPermission called")
        #endif
        
        // First check current status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            #if DEBUG
            print("🔔 DEBUG: Current auth status: \(settings.authorizationStatus.rawValue)")
            print("🔔 DEBUG: Status - 0=notDetermined, 1=denied, 2=authorized, 3=provisional, 4=ephemeral")
            #endif
            
            DispatchQueue.main.async {
                // Only request if not determined
                if settings.authorizationStatus == .notDetermined {
                    #if DEBUG
                    print("🔔 DEBUG: Requesting authorization...")
                    #endif
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        #if DEBUG
                        print("🔔 DEBUG: Authorization result - granted: \(granted), error: \(String(describing: error))")
                        #endif
                        DispatchQueue.main.async {
                            // Move to next page regardless of permission result
                            withAnimation {
                                currentPage = 5
                            }
                        }
                    }
                } else {
                    #if DEBUG
                    print("🔔 DEBUG: Permission already determined, skipping request")
                    #endif
                    // Move to next page if already determined
                    withAnimation {
                        currentPage = 5
                    }
                }
            }
        }
    }
}

struct NotificationBenefit: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Ready to Go Page

struct ReadyToGoPage: View {
    let userName: String
    @Binding var showOnboarding: Bool
    @Binding var hasCompletedOnboarding: Bool
    @State private var animateConfetti = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Success animation
            ZStack {
                // Confetti effect
                ForEach(0..<20) { index in
                    OnboardingConfettiPiece()
                        .opacity(animateConfetti ? 0 : 1)
                        .scaleEffect(animateConfetti ? 1.5 : 0.1)
                        .offset(
                            x: animateConfetti ? CGFloat.random(in: -150...150) : 0,
                            y: animateConfetti ? CGFloat.random(in: -200...50) : 0
                        )
                        .animation(
                            .easeOut(duration: 1.5)
                            .delay(Double(index) * 0.05),
                            value: animateConfetti
                        )
                }
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.green)
                    .scaleEffect(animateConfetti ? 1.0 : 0.0)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.6)
                        .delay(0.3),
                        value: animateConfetti
                    )
            }
            .onAppear {
                animateConfetti = true
            }
            
            VStack(spacing: 16) {
                Text(userName.isEmpty ? "You're all set!" : "Welcome, \(userName)!")
                    .font(.system(size: 36, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("Let's build momentum together")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                hasCompletedOnboarding = true
                showOnboarding = false
            }) {
                HStack(spacing: 12) {
                    Text("Start Using Planwise")
                        .font(.system(size: 20, weight: .semibold))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(Color.blue)
                        .shadow(
                            color: Color.blue.opacity(0.3),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                )
            }
            
            Spacer()
            Spacer()
        }
    }
}

struct OnboardingConfettiPiece: View {
    let colors: [Color] = [.blue, .green, .orange, .red, .yellow]
    let size: CGFloat
    let rotation: Double
    let color: Color
    
    init() {
        self.size = CGFloat.random(in: 8...16)
        self.rotation = Double.random(in: 0...360)
        self.color = [Color.blue, .green, .orange, .red, .yellow].randomElement()!
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: size, height: size * 0.6)
            .rotationEffect(.degrees(rotation))
    }
}

#Preview {
    OnboardingViewPremium(showOnboarding: .constant(true))
        .environmentObject(ScheduleManager.shared)
}