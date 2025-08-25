//
//  GoalsView.swift
//  Momentum
//
//  Display and manage goals with progress tracking
//

import SwiftUI
import Charts

struct GoalsView: View {
    @EnvironmentObject private var goalManager: GoalManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var areaManager = GoalAreaManager.shared
    @State private var selectedGoal: Goal?
    @State private var showingAddGoal = false
    @State private var groupByArea = false
    @Environment(\.colorScheme) var colorScheme
    @State private var extractedColors: (primary: Color, secondary: Color)? = nil
    @State private var isEditingHeaderImage = false
    @State private var headerImageOffset: CGFloat = 0
    @State private var lastHeaderImageOffset: CGFloat = 0
    @State private var selectedCategory: Category?
    @State private var showingCategoryGoals = false
    @State private var selectedCategoryName: String = ""
    @State private var selectedCategoryGoals: [Goal] = []
    @State private var categorySheetData: CategorySheetData? = nil
    
    struct CategorySheetData: Identifiable {
        let id = UUID()
        let name: String
        let category: Category?
        let goals: [Goal]
    }
    
    
    var filteredGoals: [Goal] {
        return goalManager.goals
    }
    
    var body: some View {
        ZStack {
            // Super light gray background
            backgroundView
            
            VStack(spacing: 0) {
                // Stack with blue header extending behind content
                ZStack(alignment: .top) {
                    // Background - either custom image or gradient
                    headerBackgroundView
                    
                    VStack(spacing: 0) {
                        // Use PremiumHeaderView like Day/Habits views for consistency
                        PremiumHeaderView(
                            dateTitle: formatDate(Date()),
                            selectedDate: Date(),
                            onPreviousDay: {},
                            onNextDay: {},
                            onToday: {},
                            onSettings: {},
                            onAddEvent: { showingAddGoal = true },
                            onDateSelected: nil
                        )
                        .opacity(isEditingHeaderImage ? 0 : 1)
                        .zIndex(2) // Ensure header is on top for gestures
                        
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
                                        Color(UIColor.systemBackground).opacity(0.02),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom,
                                    extendFactor: 3.0
                                )
                                .blur(radius: 2)
                            }
                            
                            mainContentView
                        }
                        .opacity(isEditingHeaderImage ? 0 : 1)
                        .frame(maxHeight: .infinity)
                        .background(Color(UIColor.systemGroupedBackground))
                        .clipShape(
                            .rect(
                                topLeadingRadius: 40,
                                topTrailingRadius: 40
                            )
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: -2)
                        .ignoresSafeArea(edges: .bottom)
                    }
                }
            }
            
            // Floating Action Button
        }
        .navigationBarHidden(true) // Hide nav bar on all devices
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowAddGoal"))) { _ in
            showingAddGoal = true
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $selectedGoal) { goal in
            GoalDetailView(goal: goal)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $categorySheetData) { data in
            CategoryGoalsView(
                categoryName: data.name,
                category: data.category,
                goals: data.goals,
                onSelectGoal: { goal in
                    selectedGoal = goal
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .onAppear {
            // Load saved header image offset
            headerImageOffset = CGFloat(UserDefaults.standard.double(forKey: "headerImageVerticalOffset"))
            lastHeaderImageOffset = headerImageOffset
            
            // Load gradient colors based on settings
            let useAutoGradient = UserDefaults.standard.bool(forKey: "useAutoGradient")
            
            if useAutoGradient {
                // Load extracted colors from header image
                self.extractedColors = UserDefaults.standard.getExtractedColors()
                
                // If no colors saved but we have an image, extract them
                if extractedColors == nil, let headerData = SettingsView.loadHeaderImage() {
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
                
                self.extractedColors = (baseColor, baseColor.opacity(0.7))
            }
            
            // Check if we should start editing
            if UserDefaults.standard.bool(forKey: "shouldStartHeaderEdit") {
                UserDefaults.standard.set(false, forKey: "shouldStartHeaderEdit")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        isEditingHeaderImage = true
                    }
                }
            }
        }
        .overlay(
            // Edit mode overlay
            Group {
                if isEditingHeaderImage {
                    ZStack {
                        // Semi-transparent background only below header
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: 168.5) // Start grayout earlier
                            
                            // Gray overlay on main content with rounded corners
                            Color.black.opacity(0.4)
                                .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
                                .ignoresSafeArea(edges: .bottom)
                        }
                        .onTapGesture {
                            // Prevent taps from going through
                        }
                        
                        // Done button in center of screen
                        Button(action: {
                            withAnimation {
                                isEditingHeaderImage = false
                                lastHeaderImageOffset = headerImageOffset
                                UserDefaults.standard.set(headerImageOffset, forKey: "headerImageVerticalOffset")
                            }
                        }) {
                            Text("Done")
                                .scaledFont(size: 20, weight: .semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 50)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(Color.blue)
                                )
                                .shadow(radius: 10)
                        }
                    }
                }
            }
        )
    }
    
    // MARK: - View Components
    @ViewBuilder
    var backgroundView: some View {
        Color(UIColor.systemGroupedBackground)
            .ignoresSafeArea()
            .transition(.identity)
    }
    
    @ViewBuilder
    var headerBackgroundView: some View {
        if let headerData = SettingsView.loadHeaderImage() {
            // Image with gesture
            GeometryReader { imageGeo in
                Image(uiImage: headerData.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: imageGeo.size.width)
                    .offset(y: CGFloat(UserDefaults.standard.double(forKey: "headerImageVerticalOffset")))
                    .overlay(
                        // Dark overlay
                        Color.black.opacity(isEditingHeaderImage ? 0.1 : 0.3)
                    )
                    .gesture(
                        isEditingHeaderImage ?
                        DragGesture()
                            .onChanged { value in
                                headerImageOffset = lastHeaderImageOffset + value.translation.height
                            }
                            .onEnded { _ in
                                lastHeaderImageOffset = headerImageOffset
                                UserDefaults.standard.set(headerImageOffset, forKey: "headerImageVerticalOffset")
                            }
                        : nil
                    )
            }
            .frame(height: 280)
            .ignoresSafeArea()
            .onTapGesture {
                if !isEditingHeaderImage {
                    withAnimation {
                        isEditingHeaderImage = true
                    }
                }
            }
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
            .frame(height: 280)
        }
    }
    
    @ViewBuilder
    var mainContentView: some View {
        if groupByArea {
            // Use ScrollView for grouped view
            ScrollView {
                VStack(spacing: 24) {
                    // Group by Area Toggle
                    groupByAreaToggle
                    
                    // Upcoming Deadlines
                    upcomingDeadlinesSection
                    
                    // Goals List
                    if filteredGoals.isEmpty {
                        emptyStateView
                            .padding(.vertical, 60)
                            .padding(.horizontal, 20)
                    } else {
                        goalsListView
                    }
                    
                    // Bottom padding for floating button
                    Color.clear.frame(height: 100)
                }
            }
        } else {
            // Use List for non-grouped view (for swipe actions)
            if DeviceType.isIPhone {
                // On iPhone, make everything scroll together
                List {
                    // Group by Area Toggle as first item
                    groupByAreaToggle
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    
                    // Upcoming Deadlines
                    if !goalManager.upcomingDeadlines().isEmpty {
                        upcomingDeadlinesSection
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    
                    // Goals
                    ForEach(filteredGoals) { goal in
                        GoalCard(goal: goal)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedGoal = goal
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteGoal(goal)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    
                    // Add bottom padding for floating button inside the List
                    Color.clear
                        .frame(height: 100)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            } else {
                // On iPad, keep the original layout
                VStack(spacing: 0) {
                    // Group by Area Toggle at top
                    groupByAreaToggle
                        .padding(.bottom, 16)
                    
                    // Upcoming Deadlines
                    upcomingDeadlinesSection
                        .padding(.bottom, 16)
                    
                    // Goals List or empty state
                    if filteredGoals.isEmpty {
                        ScrollView {
                            emptyStateView
                                .padding(.vertical, 60)
                                .padding(.horizontal, 20)
                        }
                    } else {
                        goalsListView
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    var upcomingDeadlinesSection: some View {
        // Hide upcoming deadlines on iPad
        if !DeviceType.isIPad {
            let upcoming = goalManager.upcomingDeadlines()
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Upcoming Deadlines")
                        .scaledFont(size: 20, weight: .semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(upcoming) { goal in
                                DeadlineCard(goal: goal)
                                    .onTapGesture {
                                        selectedGoal = goal
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    var goalsListView: some View {
        if groupByArea {
            // Group by area - used in ScrollView
            VStack(spacing: 16) {
                // Uncategorized goals first
                let uncategorizedGoals = filteredGoals.filter { $0.category == nil }
                if !uncategorizedGoals.isEmpty {
                    let capturedUncategorizedGoals = Array(uncategorizedGoals) // Capture goals here
                    AreaCard(
                        categoryName: "Uncategorized",
                        iconName: "tray",
                        colorHex: "#808080",
                        goalCount: capturedUncategorizedGoals.count,
                        onTap: {
                            print("🎯 Tapped uncategorized area with \(capturedUncategorizedGoals.count) goals")
                            print("🎯 Uncategorized goal titles: \(capturedUncategorizedGoals.compactMap { $0.title })")
                            categorySheetData = CategorySheetData(
                                name: "Uncategorized",
                                category: nil,
                                goals: capturedUncategorizedGoals
                            )
                        }
                    )
                    .padding(.horizontal, 20)
                }
                
                // Goals by area
                ForEach(areaManager.categories.filter { $0.isActive }) { category in
                    let categoryGoals = filteredGoals.filter { goal in
                        goal.category == category
                    }
                    if !categoryGoals.isEmpty {
                        let capturedGoals = Array(categoryGoals) // Capture goals here
                        let capturedCategory = category // Capture category
                        AreaCard(
                            categoryName: category.name ?? "",
                            iconName: category.iconName ?? "folder.fill",
                            colorHex: category.colorHex ?? "#007AFF",
                            goalCount: capturedGoals.count,
                            onTap: {
                                let name = capturedCategory.name ?? ""
                                print("🎯 Tapped \(name) area with \(capturedGoals.count) goals")
                                print("🎯 Goal titles: \(capturedGoals.compactMap { $0.title })")
                                categorySheetData = CategorySheetData(
                                    name: name,
                                    category: capturedCategory,
                                    goals: capturedGoals
                                )
                            }
                        )
                        .padding(.horizontal, 20)
                    }
                }
            }
        } else {
            // Regular list using List for swipe actions - standalone List
            List {
                ForEach(filteredGoals) { goal in
                    GoalCard(goal: goal)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedGoal = goal
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteGoal(goal)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                
                // Add bottom padding for floating button inside the List
                Color.clear
                    .frame(height: 100)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
        }
    }
    
    var groupByAreaToggle: some View {
        HStack {
            Label("Group by Area", systemImage: "folder")
                .scaledFont(size: DeviceType.isIPhone ? 13 : 15)
                .foregroundColor(.secondary)
            Spacer()
            Toggle("", isOn: $groupByArea)
                .labelsHidden()
                .scaleEffect(DeviceType.isIPhone ? 0.85 : 1.0)
        }
        .padding(.horizontal, DeviceType.isIPhone ? 20 : 40)
        .padding(.top, DeviceType.isIPhone ? 12 : 20)
        .padding(.bottom, DeviceType.isIPhone ? 8 : 0)
    }
    
    var emptyStateView: some View {
        EmptyStateView(config: .noGoals {
            showingAddGoal = true
        })
    }
    
    func showQuickUpdate(for goal: Goal) {
        // TODO: Implement quick update sheet
    }
    
    func deleteGoal(_ goal: Goal) {
        _ = goalManager.deleteGoal(goal)
    }
    
    func formatDate(_ date: Date) -> String {
        return Date.formatDateWithGreeting(date)
    }
    
    // This function is no longer needed as we've moved the logic inline
    // Keeping for compatibility if called elsewhere
    @ViewBuilder
    func goalCardView(goal: Goal) -> some View {
        GoalCard(goal: goal)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedGoal = goal
            }
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: Goal
    @Environment(\.colorScheme) var colorScheme
    
    private var goalColor: Color {
        Color(hex: goal.category?.colorHex ?? "#007AFF")
    }
    
    var body: some View {
        // Use same styling as EnhancedTaskCard
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon with colored background
                ZStack {
                    ColoredIconBackground(color: goalColor, size: DesignSystem.IconSize.xxl + 6)
                    Image(systemName: goal.category?.iconName ?? "target")
                        .scaledFont(size: DesignSystem.IconSize.lg)
                        .scaledIcon()
                        .foregroundColor(goalColor)
                }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text(goal.title ?? "")
                            .scaledFont(size: 17, weight: .semibold)
                            .foregroundColor(.primary)
                        
                        if let desc = goal.desc {
                            Text(desc)
                                .scaledFont(size: 13)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Priority Badge
                    PriorityBadge(priority: goal.priorityEnum)
                }
                
                // Progress Section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Progress Header
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs / 2) {
                            Text("\(Int(goal.progress * 100))%")
                                .scaledFont(size: 28, weight: .bold)
                                .fontWeight(.bold)
                            if goal.typeEnum == .milestone || goal.typeEnum == .project {
                                let milestones = goal.sortedMilestones
                                let completedCount = milestones.filter { $0.isCompleted }.count
                                Text("\(completedCount)/\(milestones.count) milestones")
                                    .scaledFont(size: 12)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Progress")
                                    .scaledFont(size: 12)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if let targetDate = goal.targetDate {
                            HStack(spacing: DesignSystem.Spacing.xxs) {
                                Image(systemName: "calendar")
                                    .scaledFont(size: 12)
                                    .scaledIcon()
                                Text(targetDate, style: .date)
                                    .scaledFont(size: 12)
                            }
                            .foregroundColor(goal.isOverdue ? .red : .secondary)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs - 2)
                            .background(
                                Capsule()
                                    .fill(goal.isOverdue ? Color.red.opacity(DesignSystem.Opacity.light) : Color.gray.opacity(DesignSystem.Opacity.light))
                            )
                        }
                    }
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm - 2)
                                .fill(Color.gray.opacity(DesignSystem.Opacity.light))
                                .frame(height: DesignSystem.Spacing.sm)
                            
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm - 2)
                                .fill(
                                    LinearGradient(
                                        colors: [goalColor, goalColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, geometry.size.width * goal.progress), height: DesignSystem.Spacing.sm)
                                // Removed animation for faster response
                        }
                    }
                    .frame(height: DesignSystem.Spacing.sm)
                }
                
                // Stats Row
                HStack(spacing: DesignSystem.Spacing.md) {
                    if goal.typeEnum == .numeric {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs / 2) {
                            HStack(spacing: DesignSystem.Spacing.xxs) {
                                Text("\(Int(goal.currentValue))")
                                    .scaledFont(size: 17, weight: .semibold)
                                Text("/")
                                    .scaledFont(size: 17)
                                    .foregroundColor(.secondary)
                                Text("\(Int(goal.targetValue))")
                                    .scaledFont(size: 17)
                                if let unit = goal.unit {
                                    Text(unit)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .scaledFont(size: 16)
                            Text("Current")
                                .scaledFont(size: 11)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let daysRemaining = goal.daysRemaining, !goal.isCompleted {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs / 2) {
                            Text("\(daysRemaining)")
                                .scaledFont(size: 16, weight: .semibold)
                                .foregroundColor(daysRemaining <= 7 ? .orange : .primary)
                            Text("Days left")
                                .scaledFont(size: 11)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if goal.isCompleted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Completed")
                                .scaledFont(size: 12, weight: .medium)
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(DesignSystem.Opacity.light))
                        )
                    }
                }
            }
        .padding(DesignSystem.Spacing.lg - 4)
        .background(
            // Same style as EnhancedTaskCard - frosted glass blur effect
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
            // Top edge highlight
            VStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.6),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 1)
                .blur(radius: 0.5)
                .padding(.horizontal, DesignSystem.CornerRadius.md)
                
                Spacer()
            }
        )
        // Single shadow like task cards
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Deadline Card

struct DeadlineCard: View {
    let goal: Goal
    
    private var goalColor: Color {
        Color(hex: goal.category?.colorHex ?? "#007AFF")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ZStack {
                ColoredIconBackground(color: goalColor, size: DesignSystem.Spacing.xl + DesignSystem.Spacing.xs, iconOpacity: DesignSystem.Opacity.light + 0.05)
                Image(systemName: goal.category?.iconName ?? "target")
                    .font(.system(size: DesignSystem.IconSize.md))
                    .foregroundColor(goalColor)
            }
            
            Text(goal.title ?? "")
                .scaledFont(size: 15, weight: .medium)
                .lineLimit(2)
            
            if let days = goal.daysRemaining {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: "clock.fill")
                        .scaledFont(size: 12)
                        .scaledIcon()
                    Text("\(days) days")
                        .scaledFont(size: 12, weight: .bold)
                }
                .foregroundColor(days <= 3 ? .red : .orange)
                .padding(.horizontal, DesignSystem.Spacing.xs)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .background(
                    Capsule()
                        .fill((days <= 3 ? Color.red : Color.orange).opacity(DesignSystem.Opacity.light))
                )
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(width: DesignSystem.Spacing.xxxl + DesignSystem.Spacing.xxl + 8)
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
            // Subtle border for definition
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
        )
        .overlay(
            // Top edge highlight
            VStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.6),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 1)
                .blur(radius: 0.5)
                .padding(.horizontal, DesignSystem.CornerRadius.md)
                
                Spacer()
            }
        )
        // Single shadow like task cards
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: GoalPriority
    
    var body: some View {
        // Small colored dot like in tasks
        Circle()
            .fill(Color(hex: priority.color))
            .frame(width: 8, height: 8)
    }
}

// MARK: - Goal Stat Card

struct GoalStatCard: View {
    let value: String
    let label: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .scaledFont(size: DesignSystem.IconSize.lg)
                .scaledIcon()
                .foregroundColor(color)
            
            VStack(spacing: DesignSystem.Spacing.xxs) {
                Text(value)
                    .scaledFont(size: 22, weight: .bold, design: .rounded)
                    .foregroundColor(color)
                
                Text(label)
                    .scaledFont(size: 12)
                    .foregroundColor(color.opacity(0.8))
            }
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color.white.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Area Card

struct AreaCard: View {
    let categoryName: String
    let iconName: String
    let colorHex: String
    let goalCount: Int
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var categoryColor: Color {
        Color(hex: colorHex)
    }
    
    var body: some View {
        Button(action: {
            print("🔵 AreaCard button ACTION for \(categoryName) with \(goalCount) goals")
            HapticFeedback.light.trigger()
            onTap()
        }) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon with colored background
                ZStack {
                    ColoredIconBackground(color: categoryColor, size: DesignSystem.IconSize.xxl + 8)
                    Image(systemName: iconName)
                        .scaledFont(size: DesignSystem.IconSize.lg)
                        .scaledIcon()
                        .foregroundColor(categoryColor)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(categoryName)
                        .scaledFont(size: 17, weight: .semibold)
                        .foregroundColor(.primary)
                    Text("\(goalCount) goal\(goalCount == 1 ? "" : "s")")
                        .scaledFont(size: 12)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .scaledFont(size: 14, weight: .semibold)
                    .scaledIcon()
                    .foregroundColor(.secondary)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.95))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .contentShape(Rectangle()) // Ensure entire area is tappable
        }
        .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle for more reliable taps
    }
}



#Preview {
    GoalsView()
        .environmentObject(GoalManager.shared)
        .environmentObject(SubscriptionManager.shared)
}

// MARK: - Category Goals View

struct CategoryGoalsView: View {
    let categoryName: String
    let category: Category?
    let goals: [Goal]
    let onSelectGoal: (Goal) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var extractedColors: (primary: Color, secondary: Color)? = nil
    
    init(categoryName: String, category: Category?, goals: [Goal], onSelectGoal: @escaping (Goal) -> Void) {
        self.categoryName = categoryName
        self.category = category
        self.goals = goals
        self.onSelectGoal = onSelectGoal
        print("📦 CategoryGoalsView INIT with \(goals.count) goals for \(categoryName)")
    }
    
    var categoryColor: Color {
        if let colorHex = category?.colorHex {
            return Color(hex: colorHex)
        }
        return Color(hex: "#808080") // Gray for uncategorized
    }
    
    var categoryIcon: String {
        return category?.iconName ?? "tray"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Category header card
                        GlassCard(cornerRadius: DesignSystem.CornerRadius.lg, padding: DesignSystem.Spacing.lg) {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                ZStack {
                                    ColoredIconBackground(color: categoryColor, size: DesignSystem.IconSize.xxxl)
                                    Image(systemName: categoryIcon)
                                        .scaledFont(size: DesignSystem.IconSize.xl)
                                        .scaledIcon()
                                        .foregroundColor(categoryColor)
                                }
                                
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text(categoryName)
                                        .scaledFont(size: 22, weight: .bold)
                                    Text("\(goals.count) goal\(goals.count == 1 ? "" : "s")")
                                        .scaledFont(size: 15)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Goals list
                        VStack(spacing: 12) {
                            Text("Showing \(goals.count) goals")
                                .scaledFont(size: 12)
                                .foregroundColor(.secondary)
                            
                            if goals.isEmpty {
                                Text("No goals in this category")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(goals.indices, id: \.self) { index in
                                    let goal = goals[index]
                                    GoalCard(goal: goal)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            dismiss()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                onSelectGoal(goal)
                                            }
                                        }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .scaledFont(size: 17, weight: .semibold)
                }
            }
        }
        .onAppear {
            print("📂 CategoryGoalsView appeared with \(goals.count) goals for \(categoryName)")
            // Log each goal to verify they're being passed correctly
            for goal in goals {
                print("📂   - Goal: \(goal.title ?? "Untitled")")
            }
        }
    }
}


// MARK: - Simple Scale Button Style

struct SimpleScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
