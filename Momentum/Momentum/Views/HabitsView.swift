//
//  HabitsView.swift
//  Momentum
//
//  Clean, professional habit tracking UI
//

import SwiftUI
import Charts

struct HabitsView: View {
    @EnvironmentObject private var habitManager: HabitManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var selectedHabit: Habit?
    @State private var showingAddHabit = false
    @State private var selectedDate = Date()
    @State private var showingStats = false
    @State private var refreshID = UUID()
    @State private var habitToDelete: Habit?
    @State private var showingDeleteAlert = false
    @Environment(\.colorScheme) var colorScheme
    @State private var headerImageOffset: CGFloat = 0
    @State private var extractedColors: (primary: Color, secondary: Color)? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Super light gray background - EXACTLY like DayView
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                    .transition(.identity)

                VStack(spacing: 0) {
                    GeometryReader { geometry in
                        ZStack(alignment: .top) {
                            // Background - either custom image or gradient
                            Group {
                                if let headerData = AppearanceSettingsViewModel.loadHeaderImage() {
                                    ZStack {
                                        // Simple image display
                                        GeometryReader { imageGeo in
                                            Image(uiImage: headerData.image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: imageGeo.size.width)
                                                .offset(y: CGFloat(UserDefaults.standard.double(forKey: "headerImageVerticalOffset")))
                                        }
                                        .frame(height: 280) // Increased to cover rounded corners
                                        .clipped()
                                        
                                        // Dark overlay
                                        Color.black.opacity(0.3)
                                            .allowsHitTesting(false)
                                            .frame(height: 280)
                                    }
                                    .frame(height: 280) // Match the increased height
                                    .ignoresSafeArea()
                                } else {
                                    // Default blue gradient background - extended beyond visible area
                                    ExtendedGradientBackground(
                                        colors: [
                                            Color(red: 0.08, green: 0.15, blue: 0.35),
                                            Color(red: 0.12, green: 0.25, blue: 0.55)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                        extendFactor: 3.0
                                    )
                                }
                            }
                            
                            VStack(spacing: 0) {
                                // Header container - always same expanded size
                                PremiumHeaderView(
                                    dateTitle: formatDate(selectedDate),
                                    selectedDate: selectedDate,
                                    onPreviousDay: {
                                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                                    },
                                    onNextDay: {
                                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                                    },
                                    onToday: {
                                        selectedDate = Date()
                                    },
                                    onSettings: {
                                        // Settings handled elsewhere
                                    },
                                    onAddEvent: {
                                        showingAddHabit = true
                                    },
                                    onDateSelected: { date in
                                        selectedDate = date
                                    }
                                )
                                .zIndex(2) // Ensure header is on top for gestures
                                
                                // White content container with rounded corners
                                ZStack {
                                    // Gradient background that extends beyond safe area
                                    Group {
                                        if let colors = extractedColors {
                                            let darkModeColors: [Color] = [
                                                colors.primary.opacity(0.15),
                                                colors.primary.opacity(0.1),
                                                colors.secondary.opacity(0.08),
                                                colors.primary.opacity(0.05),
                                                colors.secondary.opacity(0.03),
                                                Color.white.opacity(0.01),
                                                Color.clear
                                            ]
                                            
                                            let lightModeColors: [Color] = [
                                                colors.primary.opacity(0.8),
                                                colors.primary.opacity(0.6),
                                                colors.secondary.opacity(0.4),
                                                colors.primary.opacity(0.2),
                                                colors.secondary.opacity(0.1),
                                                Color.white.opacity(0.02),
                                                Color.clear
                                            ]
                                            
                                            ExtendedGradientBackground(
                                                colors: colorScheme == .dark ? darkModeColors : lightModeColors,
                                                startPoint: .top,
                                                endPoint: .bottom,
                                                extendFactor: 3.0
                                            )
                                            .blur(radius: colorScheme == .dark ? 8 : 2)
                                            .blendMode(colorScheme == .dark ? .plusLighter : .normal)
                                        }
                                    }
                                    
                                    ScrollView {
                                        VStack(spacing: 0) {
                                            // Progress summary at top
                                            
                                            // Habit list
                                            habitList
                                                .padding(.horizontal, 20)
                                                .padding(.top, 20)
                                            
                                            Spacer(minLength: 100)
                                        }
                                    }
                                }
                                .frame(maxHeight: .infinity)
                                .background(Color(UIColor.systemGroupedBackground))
                                .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: -2)
                                .ignoresSafeArea(edges: .bottom)
                                .zIndex(1)
                            }
                        }
                    }
                }
                
                // Floating Action Button
            }
            .navigationBarHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowAddHabit"))) { _ in
                showingAddHabit = true
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .sheet(item: $selectedHabit) { habit in
                HabitDetailView(habit: habit)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showingStats) {
                HabitStatsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .alert("Delete Habit", isPresented: $showingDeleteAlert, presenting: habitToDelete) { habit in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteHabit(habit)
                }
            } message: { habit in
                Text("Are you sure you want to delete '\(habit.name ?? "")'? This will also delete all associated entries and cannot be undone.")
            }
            .onAppear {
                let useAutoGradient = UserDefaults.standard.bool(forKey: "useAutoGradient")
                
                if useAutoGradient {
                    // Load extracted colors from header image
                    self.extractedColors = UserDefaults.standard.getExtractedColors()
                    
                    // If no colors saved but we have an image, extract them
                    if extractedColors == nil, let headerData = AppearanceSettingsViewModel.loadHeaderImage() {
                        let colors = ColorExtractor.extractColors(from: headerData.image)
                        UserDefaults.standard.setExtractedColors(colors)
                        self.extractedColors = (colors.primary, colors.secondary)
                    }
                } else {
                    // Use manual gradient color
                    let customHex = UserDefaults.standard.string(forKey: "customGradientColorHex") ?? ""
                    var baseColor: Color
                    if !customHex.isEmpty {
                        baseColor = Color(hex: customHex)
                    } else {
                        let manualColor = UserDefaults.standard.string(forKey: "manualGradientColor") ?? "blue"
                        baseColor = Color.fromAccentString(manualColor)
                    }
                    
                    // In dark mode, brighten the colors for better visibility
                    if colorScheme == .dark {
                        // Mix with white to brighten the color
                        let brightened = UIColor(baseColor).brightened(by: 0.3) ?? UIColor(baseColor)
                        baseColor = Color(brightened)
                    }
                    
                    self.extractedColors = (baseColor, baseColor.opacity(0.7))
                }
            }
        }
        .id(refreshID)
    }
    
    // MARK: - Computed Properties
    
    private var todayProgress: (completed: Int, total: Int, percentage: Double) {
        habitManager.todayProgress()
    }
    
    private func formatDate(_ date: Date) -> String {
        return Date.formatDateWithGreeting(date)
    }
    
    private var habitList: some View {
        VStack(spacing: 12) {
            if habitManager.habitsForDate(selectedDate).isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .scaledFont(size: 60)
                        .scaledIcon()
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No habits for today")
                        .scaledFont(size: 17, weight: .semibold)
                        .foregroundColor(.secondary)
                    Text("Tap + to create your first habit")
                        .scaledFont(size: 15)
                        .foregroundColor(.secondary)
                }
                .scaledFrame(height: 300)
                .frame(maxWidth: .infinity)
                .scaledPadding(.vertical, 40)
            } else {
                ForEach(habitManager.habitsForDate(selectedDate)) { habit in
                    CleanHabitRow(habit: habit, date: selectedDate, onTap: {
                        selectedHabit = habit
                    })
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            habitToDelete = habit
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            selectedHabit = habit
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
    }
    
    @MainActor
    private func refresh() async {
        habitManager.updateStreaks()
        refreshID = UUID()
    }
    
    private func deleteHabit(_ habit: Habit) {
        let result = habitManager.deleteHabit(habit)
        
        if case .success = result {
            // Generate haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
            // Refresh the view
            refreshID = UUID()
        }
    }
}


// MARK: - Clean Habit Row

struct CleanHabitRow: View {
    let habit: Habit
    let date: Date
    let onTap: () -> Void
    @EnvironmentObject private var habitManager: HabitManager
    @State private var isCompleted = false
    @State private var showCompletionAnimation = false
    @State private var hasInitialized = false
    @State private var showingTimer = false
    @State private var showingCounter = false
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    private var entry: HabitEntry? {
        habit.entries?.first { entry in
            guard let entry = entry as? HabitEntry,
                  let entryDate = entry.date else { return false }
            return Calendar.current.isDate(entryDate, inSameDayAs: date)
        } as? HabitEntry
    }
    
    private var accentColor: Color {
        Color.fromAccentString(selectedAccentColor)
    }
    
    private var progressValue: Double {
        // Calculate progress for habits with targets
        guard (habit.trackingTypeEnum == .duration || habit.trackingTypeEnum == .quantity),
              habit.goalTarget > 0 else {
            return 0
        }
        
        // Get current value from today's entry
        let currentValue = entry?.value ?? 0
        return min(currentValue / habit.goalTarget, 1.0)
    }
    
    var body: some View {
        habitRowContent
            .onTapGesture { onTap() }
    }
    
    @ViewBuilder
    private var completionButton: some View {
        Button {
            if habit.trackingTypeEnum == .duration {
                showingTimer = true
                HapticFeedback.medium.trigger()
            } else if habit.trackingTypeEnum == .quantity {
                showingCounter = true
                HapticFeedback.medium.trigger()
            } else {
                toggleCompletion()
            }
        } label: {
            ZStack {
                // Use a static checkmark for display, only animate on actual completion
                if hasInitialized && showCompletionAnimation != isCompleted {
                    CompletionAnimationView(
                        isCompleted: $showCompletionAnimation,
                        style: habit.currentStreak > 7 ? .celebration : .checkmark,
                        onComplete: {
                            // Additional celebration for long streaks
                            if habit.currentStreak > 0 && habit.currentStreak % 10 == 0 {
                                HapticFeedback.success.triggerDouble()
                            }
                        }
                    )
                } else {
                    // Static display without animation
                    ZStack {
                        Circle()
                            .fill(isCompleted ? accentColor : Color.clear)
                            .frame(width: 24, height: 24)
                        
                        // Progress ring or completed outline
                        if !isCompleted && (habit.trackingTypeEnum == .duration || habit.trackingTypeEnum == .quantity) && habit.goalTarget > 0 {
                            // Background ring (unfilled)
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            
                            // Progress ring
                            Circle()
                                .trim(from: 0, to: progressValue)
                                .stroke(
                                    accentColor,
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                                )
                                .frame(width: 24, height: 24)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progressValue)
                        } else {
                            // Regular outline (for completed or non-progress habits)
                            Circle()
                                .stroke(isCompleted ? accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 24, height: 24)
                        }
                        
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .scaledFrame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var habitInfoContent: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
            // Habit name
            Text(habit.name ?? "Untitled Habit")
                .scaledFont(size: 17, weight: .regular)
                .strikethrough(isCompleted)
                .foregroundColor(isCompleted ? .secondary : .primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
            
            // Compact metadata on the right
            HStack(spacing: 8) {
                // Category if exists - smaller
                if let category = habit.category, let categoryName = category.name {
                    Text(categoryName)
                        .scaledFont(size: 10, weight: .medium)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 60)
                        .foregroundColor(.secondary)
                }
                
                // Simple streak text - minimal
                if habit.currentStreak > 0 {
                    Text("\(habit.currentStreak)🔥")
                        .scaledFont(size: 12, weight: .medium)
                        .foregroundColor(.orange.opacity(0.9))
                }
            }
        }
    }
    
    @ViewBuilder
    private var habitRowBackground: some View {
        ZStack {
            // Base blur layer
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(.thinMaterial)
            
            // Additional tint for better opacity
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(UIColor.systemBackground).opacity(0.3))
        }
    }
    
    @ViewBuilder
    private var habitRowOverlay: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
    }
    
    @ViewBuilder
    private var habitRowHighlight: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.1),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 1)
        .clipShape(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
        )
        .padding(1)
    }
    
    @ViewBuilder
    private var habitRowContent: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: DesignSystem.Spacing.md) {
                completionButton
                
                habitInfoContent
                
                // Chevron
                Image(systemName: "chevron.right")
                    .scaledFont(size: 14, weight: .medium)
                    .scaledIcon()
                    .foregroundColor(DesignSystem.Colors.tertiary)
            }
            .padding(DesignSystem.Spacing.md)
        }
        .background(habitRowBackground)
        .overlay(habitRowOverlay)
        .overlay(habitRowHighlight, alignment: .top)
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
        .onAppear {
            if !hasInitialized {
                isCompleted = entry != nil && (habit.trackingTypeEnum == .binary || entry?.value ?? 0 >= habit.goalTarget)
                // Set the animation state to match completion state without animating
                showCompletionAnimation = isCompleted
                hasInitialized = true
            }
        }
        .onChange(of: entry?.value ?? 0) { oldValue, newValue in
            // Only process changes after initialization
            if hasInitialized {
                let wasCompleted = habit.trackingTypeEnum == .binary ? (oldValue > 0) : (oldValue >= habit.goalTarget)
                let nowCompleted = habit.trackingTypeEnum == .binary ? (entry != nil) : (newValue >= habit.goalTarget)
                
                isCompleted = nowCompleted
                // Only trigger animation for actual state changes, not initial load
                if wasCompleted != nowCompleted {
                    showCompletionAnimation = nowCompleted
                }
            }
        }
        .fullScreenCover(isPresented: $showingTimer) {
            HabitTimerView(habit: habit, date: date)
        }
        .fullScreenCover(isPresented: $showingCounter) {
            HabitCounterView(habit: habit, date: date)
        }
    }
    
    private func toggleCompletion() {
        if habit.trackingTypeEnum == .binary {
            if isCompleted {
                if let entry = entry {
                    _ = habitManager.deleteEntry(entry)
                }
                HapticFeedback.light.trigger() // Uncomplete haptic
            } else {
                _ = habitManager.logHabit(
                    habit,
                    value: 1.0,
                    date: date,
                    notes: nil,
                    mood: nil,
                    duration: nil,
                    quality: nil
                )
                // Success haptic is triggered by animation
            }
            isCompleted.toggle()
            showCompletionAnimation.toggle()
        } else {
            // For count/time habits, toggle between 0 and goal
            if isCompleted {
                if let entry = entry {
                    _ = habitManager.deleteEntry(entry)
                }
                isCompleted = false
                showCompletionAnimation = false
                HapticFeedback.light.trigger()
            } else {
                _ = habitManager.logHabit(
                    habit,
                    value: habit.goalTarget,
                    date: date,
                    notes: nil,
                    mood: nil,
                    duration: nil,
                    quality: nil
                )
                isCompleted = true
                showCompletionAnimation = true
                // Success haptic is triggered by animation
            }
        }
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let value: Double
    let total: Double
    let color: Color
    
    private var progress: Double {
        min(1.0, max(0, value / total))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.2))
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(0, geometry.size.width * progress))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
            }
        }
    }
}