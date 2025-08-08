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
    @State private var selectedFilter: GoalFilter = .active
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
    
    enum GoalFilter: String, CaseIterable {
        case active = "Active"
        case completed = "Completed" 
        case all = "All"
        
        var icon: String {
            switch self {
            case .active: return "target"
            case .completed: return "checkmark.circle.fill"
            case .all: return "list.bullet"
            }
        }
    }
    
    var filteredGoals: [Goal] {
        switch selectedFilter {
        case .active:
            return goalManager.activeGoals
        case .completed:
            return goalManager.completedGoals
        case .all:
            return goalManager.goals
        }
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
                        .background(Color(UIColor.systemBackground))
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
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    FloatingActionButton(
                        icon: "plus",
                        accessibilityLabel: "Add new goal"
                    ) {
                        showingAddGoal = true
                    }
                    .accessibilityHint("Opens goal creation view")
                    .padding(.trailing, DesignSystem.Spacing.lg)
                    .padding(.bottom, 82)
                }
            }
        }
        .navigationBarHidden(DeviceType.isIPad ? false : true) // Show nav bar on iPad for sidebar toggle
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
            
            // Load extracted colors from header image
            self.extractedColors = UserDefaults.standard.getExtractedColors()
            
            // If no colors saved but we have an image, extract them
            if extractedColors == nil, let headerData = SettingsView.loadHeaderImage() {
                let colors = ColorExtractor.extractColors(from: headerData.image)
                UserDefaults.standard.setExtractedColors(colors)
                self.extractedColors = (colors.primary, colors.secondary)
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
                                .font(.title3)
                                .fontWeight(.semibold)
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
                    // Filter Picker inside the gradient area
                    filterSection
                    
                    // Upcoming Deadlines
                    if selectedFilter == .active {
                        upcomingDeadlinesSection
                    }
                    
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
            // Use VStack with List for non-grouped view (for swipe actions)
            VStack(spacing: 0) {
                // Filter section at top
                filterSection
                    .padding(.bottom, 16)
                
                // Upcoming Deadlines
                if selectedFilter == .active {
                    upcomingDeadlinesSection
                        .padding(.bottom, 16)
                }
                
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
    
    @ViewBuilder
    var upcomingDeadlinesSection: some View {
        let upcoming = goalManager.upcomingDeadlines()
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Upcoming Deadlines")
                    .sectionHeader()
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
    
    var filterSection: some View {
        VStack(spacing: 16) {
            // Filter Picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(GoalFilter.allCases, id: \.self) { filter in
                    Label(filter.rawValue, systemImage: filter.icon)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Group by Area Toggle
            HStack {
                Label("Group by Area", systemImage: "folder")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("", isOn: $groupByArea)
                    .labelsHidden()
            }
            .padding(.horizontal, 40)
        }
    }
    
    var emptyStateView: some View {
        Group {
            switch selectedFilter {
            case .all:
                EmptyStateView(config: .noGoals {
                    showingAddGoal = true
                })
            case .active:
                EmptyStateView(config: .noActiveGoals(
                    action: { showingAddGoal = true },
                    viewCompleted: { selectedFilter = .completed }
                ))
            case .completed:
                EmptyStateView(config: EmptyStateConfig(
                    illustration: AnyView(CelebrationIllustration()),
                    title: "No Completed Goals Yet",
                    subtitle: "Your journey to achievement starts with setting meaningful goals. Each completed goal is a victory worth celebrating.",
                    tip: "Set SMART goals: Specific, Measurable, Achievable, Relevant, Time-bound",
                    accentColor: .adaptiveGreen,
                    actions: [
                        EmptyStateAction(
                            title: "Set Your First Goal",
                            icon: "flag.fill",
                            handler: { showingAddGoal = true }
                        ),
                        EmptyStateAction(
                            title: "View Active Goals",
                            icon: "target",
                            isPrimary: false,
                            handler: { selectedFilter = .active }
                        )
                    ]
                ))
            }
        }
    }
    
    func showQuickUpdate(for goal: Goal) {
        // TODO: Implement quick update sheet
    }
    
    func deleteGoal(_ goal: Goal) {
        _ = goalManager.deleteGoal(goal)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
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
        Color(hex: goal.colorHex ?? "#007AFF")
    }
    
    var body: some View {
        // Use same styling as EnhancedTaskCard
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon with colored background
                ZStack {
                    ColoredIconBackground(color: goalColor, size: DesignSystem.IconSize.xxl + 6)
                    Image(systemName: goal.iconName ?? "target")
                        .font(.system(size: DesignSystem.IconSize.lg))
                        .foregroundColor(goalColor)
                }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text(goal.title ?? "")
                            .cardTitle()
                        
                        if let desc = goal.desc {
                            Text(desc)
                                .caption()
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
                                .titleLarge()
                                .fontWeight(.bold)
                            if goal.typeEnum == .milestone || goal.typeEnum == .project {
                                let milestones = goal.sortedMilestones
                                let completedCount = milestones.filter { $0.isCompleted }.count
                                Text("\(completedCount)/\(milestones.count) milestones")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Progress")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if let targetDate = goal.targetDate {
                            HStack(spacing: DesignSystem.Spacing.xxs) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                Text(targetDate, style: .date)
                                    .font(.caption)
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
                                .frame(width: geometry.size.width * goal.progress, height: DesignSystem.Spacing.sm)
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
                                    .fontWeight(.semibold)
                                Text("/")
                                    .foregroundColor(.secondary)
                                Text("\(Int(goal.targetValue))")
                                if let unit = goal.unit {
                                    Text(unit)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.callout)
                            Text("Current")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let daysRemaining = goal.daysRemaining, !goal.isCompleted {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs / 2) {
                            Text("\(daysRemaining)")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(daysRemaining <= 7 ? .orange : .primary)
                            Text("Days left")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if goal.isCompleted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Completed")
                                .fontWeight(.medium)
                        }
                        .font(.caption)
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
        Color(hex: goal.colorHex ?? "#007AFF")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ZStack {
                ColoredIconBackground(color: goalColor, size: DesignSystem.Spacing.xl + DesignSystem.Spacing.xs, iconOpacity: DesignSystem.Opacity.light + 0.05)
                Image(systemName: goal.iconName ?? "target")
                    .font(.system(size: DesignSystem.IconSize.md))
                    .foregroundColor(goalColor)
            }
            
            Text(goal.title ?? "")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            if let days = goal.daysRemaining {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text("\(days) days")
                        .fontWeight(.bold)
                }
                .font(.caption)
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
        Text(priority.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(hex: priority.color))
            )
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
                .font(.system(size: DesignSystem.IconSize.lg))
                .foregroundColor(color)
            
            VStack(spacing: DesignSystem.Spacing.xxs) {
                Text(value)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(label)
                    .font(.caption)
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
                        .font(.system(size: DesignSystem.IconSize.lg))
                        .foregroundColor(categoryColor)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(categoryName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(goalCount) goal\(goalCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
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
                                        .font(.system(size: DesignSystem.IconSize.xl))
                                        .foregroundColor(categoryColor)
                                }
                                
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text(categoryName)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("\(goals.count) goal\(goals.count == 1 ? "" : "s")")
                                        .font(.subheadline)
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
                                .font(.caption)
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
                    .fontWeight(.semibold)
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
