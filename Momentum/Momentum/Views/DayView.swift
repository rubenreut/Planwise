import SwiftUI

struct DayView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @StateObject private var viewModel = DayViewModel()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.managedObjectContext) var managedObjectContext
    @State private var isDraggingTimeBlock = false
    @State private var showingSettings = false
    @State private var dayOffset: Int = 0
    
    // Swipe gesture states
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimatingSwipe = false
    @State private var viewDates: [Date] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return [
            calendar.date(byAdding: .day, value: -1, to: today) ?? today,
            today,
            calendar.date(byAdding: .day, value: 1, to: today) ?? today
        ]
    }()
    
    // Cache events for all three visible days
    @State private var eventsCache: [Date: [Event]] = [:]
    
    // Mathematical constants
    private var hourHeight: CGFloat {
        DeviceType.isIPad ? 80 : 68
    }
    private var timeColumnWidth: CGFloat {
        DeviceType.isIPad ? 70 : 58
    }
    private let rightPadding: CGFloat = DesignSystem.Spacing.md
    private let animationDuration: Double = 0.2
    private let minDragDistance: CGFloat = DesignSystem.Spacing.xs
    private let velocityThreshold: CGFloat = 150
    
    private var todayDate: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.adaptiveBackground)
                .ignoresSafeArea()
            
            // Three-view sliding system (disabled for iPad/Mac)
            Group {
                if DeviceType.isIPhone {
                    GeometryReader { geometry in
                        if viewDates.count >= 3 {
                            HStack(spacing: 0) {
                                ForEach(0..<3, id: \.self) { index in
                                    dayView(for: viewDates[index])
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                }
                            }
                            .offset(x: -geometry.size.width + (isDraggingTimeBlock ? 0 : dragOffset))
                        }
                    }
                } else {
                    // iPad/Mac: Single day view with navigation
                    dayView(for: viewDates[1])
                }
            }
            .gesture(
                DragGesture(minimumDistance: minDragDistance)
                    .onChanged { value in
                        guard !isAnimatingSwipe && !isDraggingTimeBlock else { return }
                        
                        // Horizontal drag ratio check
                        let horizontalAmount = abs(value.translation.width)
                        let verticalAmount = abs(value.translation.height)
                        
                        // Only capture gesture if it's primarily horizontal
                        if horizontalAmount > verticalAmount * 1.5 && horizontalAmount > minDragDistance {
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        guard !isAnimatingSwipe && !isDraggingTimeBlock else { return }
                        
                        let screenWidth = UIScreen.main.bounds.width
                        let velocity = value.predictedEndLocation.x - value.location.x
                        
                        // Horizontal drag check
                        let horizontalAmount = abs(value.translation.width)
                        let verticalAmount = abs(value.translation.height)
                        
                        guard horizontalAmount > verticalAmount * 1.5 else {
                            // Removed animation for faster navigation
                            dragOffset = 0
                            return
                        }
                        
                        if abs(velocity) > velocityThreshold {
                            // Velocity-based swipe
                            if velocity > 0 {
                                swipeToPreviousDay(screenWidth: screenWidth)
                            } else {
                                swipeToNextDay(screenWidth: screenWidth)
                            }
                        } else if abs(dragOffset) > screenWidth * 0.3 {
                            // Distance-based swipe
                            if dragOffset > 0 {
                                swipeToPreviousDay(screenWidth: screenWidth)
                            } else {
                                swipeToNextDay(screenWidth: screenWidth)
                            }
                        } else {
                            // Snap back smoothly
                            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.9)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            
            
            // Floating Action Button with Voice Recording
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        viewModel.showingAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .buttonStyle(FloatingActionButtonStyle())
                    .accessibilityLabel("Add new event")
                    .accessibilityHint("Opens event creation view")
                    .padding(.trailing, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                }
            }
        }
        .onAppear {
            setupInitialDates()
            viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: todayDate) ?? todayDate
            preloadSurroundingDays()
        }
        .onChange(of: dayOffset) { _, _ in
            viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: todayDate) ?? todayDate
            // Don't refresh events, they're already loaded
        }
        .onChange(of: isDraggingTimeBlock) { _, isDragging in
            if isDragging {
                // Reset any partial drag when starting to drag a time block
                dragOffset = 0
            }
        }
        .optimizedSheet(isPresented: $viewModel.showingAddEvent) {
            LazyView(AddEventView())
        }
        .optimizedSheet(item: $viewModel.selectedEvent) { event in
            LazyView(EventDetailView(event: event))
        }
        .optimizedSheet(isPresented: $showingSettings) {
            LazyView(NavigationView {
                SettingsView()
            })
        }
    }
    
    private func setupInitialDates() {
        let calendar = Calendar.current
        viewDates = [
            calendar.date(byAdding: .day, value: dayOffset - 1, to: todayDate) ?? todayDate,
            calendar.date(byAdding: .day, value: dayOffset, to: todayDate) ?? todayDate,
            calendar.date(byAdding: .day, value: dayOffset + 1, to: todayDate) ?? todayDate
        ]
    }
    
    private func swipeToNextDay(screenWidth: CGFloat) {
        isAnimatingSwipe = true
        
        withAnimation(.easeInOut(duration: 0.3)) {
            dragOffset = -screenWidth
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.dayOffset += 1
            self.updateViewDates()
            self.preloadSurroundingDays()
            // Reset without animation - the view already moved
            self.dragOffset = 0
            self.isAnimatingSwipe = false
        }
    }
    
    private func swipeToPreviousDay(screenWidth: CGFloat) {
        isAnimatingSwipe = true
        
        withAnimation(.easeInOut(duration: 0.3)) {
            dragOffset = screenWidth
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.dayOffset -= 1
            self.updateViewDates()
            self.preloadSurroundingDays()
            // Reset without animation - the view already moved
            self.dragOffset = 0
            self.isAnimatingSwipe = false
        }
    }
    
    private func updateViewDates() {
        let calendar = Calendar.current
        viewDates = [
            calendar.date(byAdding: .day, value: dayOffset - 1, to: todayDate) ?? todayDate,
            calendar.date(byAdding: .day, value: dayOffset, to: todayDate) ?? todayDate,
            calendar.date(byAdding: .day, value: dayOffset + 1, to: todayDate) ?? todayDate
        ]
    }
    
    private func preloadSurroundingDays() {
        // Only preload immediate surrounding days for performance
        var datesToPreload: [Date] = []
        for offset in -1...1 {
            if let date = Calendar.current.date(byAdding: .day, value: dayOffset + offset, to: todayDate) {
                datesToPreload.append(date)
            }
        }
        dependencyContainer.scheduleManager.preloadEvents(for: datesToPreload)
    }
    
    @ViewBuilder
    private func dayView(for date: Date) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header - sticky at the top
                PremiumHeaderView(
                    dateTitle: formatDate(date),
                    selectedDate: date,
                    onPreviousDay: { 
                        if !isAnimatingSwipe {
                            swipeToPreviousDay(screenWidth: UIScreen.main.bounds.width)
                        }
                    },
                    onNextDay: { 
                        if !isAnimatingSwipe {
                            swipeToNextDay(screenWidth: UIScreen.main.bounds.width)
                        }
                    },
                    onToday: { 
                        dayOffset = 0
                        setupInitialDates()
                    },
                    onSettings: { showingSettings = true },
                    onAddEvent: { viewModel.showingAddEvent = true },
                    onDateSelected: { selectedDate in
                        navigateToDate(selectedDate)
                    }
                )
                .background(Color(UIColor.systemBackground))
                .zIndex(1) // Keep header on top
                
                // Timeline
                let isCurrentDay = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
                let scrollBinding = Binding<CGFloat>(
                    get: { dependencyContainer.scrollPositionManager.offset(for: 0, default: 612) },
                    set: { newValue in
                        if isCurrentDay {
                            dependencyContainer.scrollPositionManager.update(dayOffset: 0, to: newValue)
                        }
                    }
                )
                
                PersistentScrollView(
                    offset: scrollBinding,
                    isScrollEnabled: !isDraggingTimeBlock
                ) {
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            Color.clear
                                .frame(height: hourHeight)
                        }
                    }
                    .background(
                        DayTimelineView(selectedDate: date, showCurrentTime: false)
                            .overlay(alignment: .topLeading) {
                                // Always show events layer
                                eventsLayerForDate(date)
                            }
                            .overlay(alignment: .topLeading) {
                                if Calendar.current.isDateInToday(date) {
                                    CurrentTimeIndicator()
                                }
                            }
                            .frame(maxWidth: .infinity)
                    )
                }
            }
        }
    }
    
    private func eventsLayerForDate(_ date: Date) -> some View {
        GeometryReader { geometry in
            let events = dependencyContainer.scheduleManager.events(for: date)
            let isToday = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
            let layouts = viewModel.calculateEventLayout(for: events)
            let availableWidth = geometry.size.width - timeColumnWidth - rightPadding
            
            ForEach(layouts, id: \.event.id) { layout in
                TimeBlockView(
                    event: layout.event,
                    onTap: { 
                        if isToday {
                            viewModel.handleEventTap(layout.event)
                        }
                    },
                    isDraggingAnyBlock: $isDraggingTimeBlock
                )
                .frame(
                    width: calculateEventWidth(layout: layout, totalWidth: availableWidth),
                    height: layout.height
                )
                .offset(
                    x: timeColumnWidth + calculateEventXOffset(layout: layout, availableWidth: availableWidth),
                    y: layout.yPosition
                )
                .allowsHitTesting(isToday)
                .id(layout.event.id) // Ensure proper view recycling
            }
        }
    }
    
    private func calculateEventWidth(layout: EventLayout, totalWidth: CGFloat) -> CGFloat {
        let gapBetweenColumns: CGFloat = DesignSystem.Spacing.xxs
        let columnWidth = (totalWidth - (CGFloat(layout.totalColumns - 1) * gapBetweenColumns)) / CGFloat(layout.totalColumns)
        return columnWidth
    }
    
    private func calculateEventXOffset(layout: EventLayout, availableWidth: CGFloat) -> CGFloat {
        let gapBetweenColumns: CGFloat = DesignSystem.Spacing.xxs
        let columnWidth = (availableWidth - (CGFloat(layout.totalColumns - 1) * gapBetweenColumns)) / CGFloat(layout.totalColumns)
        return CGFloat(layout.column) * (columnWidth + gapBetweenColumns)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func navigateToDate(_ targetDate: Date) {
        let calendar = Calendar.current
        let targetStartOfDay = calendar.startOfDay(for: targetDate)
        let currentStartOfDay = calendar.startOfDay(for: todayDate)
        
        guard let daysDifference = calendar.dateComponents([.day], from: currentStartOfDay, to: targetStartOfDay).day else {
            return
        }
        
        // Update the dayOffset to jump to the selected date
        dayOffset = daysDifference
        setupInitialDates()
        
        // Update the view model's selected date
        viewModel.selectedDate = targetStartOfDay
        viewModel.refreshEvents()
        preloadSurroundingDays()
    }
}