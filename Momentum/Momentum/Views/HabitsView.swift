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
                            if let headerData = SettingsView.loadHeaderImage() {
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
                                .opacity(1) // Always visible
                                
                                // White content container with rounded corners
                                ZStack {
                                    // Gradient background that extends beyond safe area
                                    if let colors = extractedColors {
                                        ExtendedGradientBackground(
                                            colors: [
                                                colors.primary.opacity(0.8),
                                                colors.primary.opacity(0.6),
                                                colors.secondary.opacity(0.4),
                                                colors.primary.opacity(0.2),
                                                colors.secondary.opacity(0.1),
                                                Color.white.opacity(0.02),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom,
                                            extendFactor: 3.0
                                        )
                                        .blur(radius: 2)
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
                                .background(Color(UIColor.systemBackground))
                                .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: -2)
                                .ignoresSafeArea(edges: .bottom)
                                .zIndex(1)
                            }
                        }
                    }
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingActionButton(icon: "plus", accessibilityLabel: "Add new habit") {
                            showingAddHabit = true
                        }
                        .accessibilityHint("Opens habit creation view")
                        .padding(.trailing, 24)
                        .padding(.bottom, 82)
                    }
                }
            }
            .navigationBarHidden(true)
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
                // Load extracted colors from header image
                self.extractedColors = UserDefaults.standard.getExtractedColors()
                
                // If no colors saved but we have an image, extract them
                if extractedColors == nil, let headerData = SettingsView.loadHeaderImage() {
                    let colors = ColorExtractor.extractColors(from: headerData.image)
                    UserDefaults.standard.setExtractedColors(colors)
                    self.extractedColors = (colors.primary, colors.secondary)
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
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    private var habitList: some View {
        VStack(spacing: 12) {
            if habitManager.habitsForDate(selectedDate).isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No habits for today")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Tap + to create your first habit")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
                .padding(.vertical, 40)
            } else {
                ForEach(habitManager.habitsForDate(selectedDate)) { habit in
                    CleanHabitRow(habit: habit, date: selectedDate, onTap: {
                        selectedHabit = habit
                    })
                    .contextMenu {
                        Button {
                            selectedHabit = habit
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            habitToDelete = habit
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
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
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Main content
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Completion button - matching task style
                    Button {
                        HapticFeedback.success.trigger()
                        toggleCompletion()
                    } label: {
                        ZStack {
                            // Simple circle border
                            Circle()
                                .stroke(isCompleted ? accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            
                            // Fill when completed
                            if isCompleted {
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .animation(.none, value: isCompleted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                
                // Habit content
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // Title row
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        Text(habit.name ?? "Untitled Habit")
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.regular)
                            .strikethrough(isCompleted)
                            .foregroundColor(isCompleted ? .secondary : .primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 0)
                    }
                    
                    // Metadata row - fixed height and no wrapping
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        // Streak badge - compact version
                        if habit.currentStreak > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 11))
                                Text("\(habit.currentStreak)")
                                    .font(DesignSystem.Typography.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color(UIColor.systemGray6))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(UIColor.systemGray5), lineWidth: 0.5)
                                    )
                            )
                            .fixedSize() // Prevent expansion
                        }
                        
                        // Category if exists - compact version
                        if let category = habit.category, let categoryName = category.name {
                            HStack(spacing: 2) {
                                Image(systemName: category.iconName ?? "folder.fill")
                                    .font(.system(size: 11))
                                Text(categoryName)
                                    .font(DesignSystem.Typography.caption2)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: 60) // Limit width
                            }
                            .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color(UIColor.systemGray6))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(UIColor.systemGray5), lineWidth: 0.5)
                                    )
                            )
                            .fixedSize() // Prevent expansion
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .frame(height: 20) // Fixed height for metadata row
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiary)
            }
            .padding(DesignSystem.Spacing.md)
        }
        }
        .buttonStyle(.plain)
        .background(
            // Same style as task cards - frosted glass blur effect
            ZStack {
                // Base blur layer
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(.thinMaterial)
                
                // Additional tint for better opacity
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(Color(UIColor.systemBackground).opacity(0.3))
            }
        )
        .overlay(
            // Subtle border for definition - same as task cards
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
        )
        .overlay(
            // Top edge highlight for depth
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
            .padding(1),
            alignment: .top
        )
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
        .onAppear {
            isCompleted = entry != nil && (habit.trackingTypeEnum == .binary || entry?.value ?? 0 >= habit.goalTarget)
        }
        .onChange(of: entry?.value ?? 0) { _, newValue in
            isCompleted = habit.trackingTypeEnum == .binary ? (entry != nil) : (newValue >= habit.goalTarget)
        }
    }
    
    private func toggleCompletion() {
        if habit.trackingTypeEnum == .binary {
            if isCompleted {
                if let entry = entry {
                    _ = habitManager.deleteEntry(entry)
                }
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
            }
            isCompleted.toggle()
        } else {
            // For count/time habits, toggle between 0 and goal
            if isCompleted {
                if let entry = entry {
                    _ = habitManager.deleteEntry(entry)
                }
                isCompleted = false
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
                    .frame(width: geometry.size.width * progress)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
            }
        }
    }
}