import SwiftUI

struct DayView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @StateObject private var viewModel = DayViewModel()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.managedObjectContext) var managedObjectContext
    
    // Drag/swipe state
    @State private var isDraggingTimeBlock = false
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimatingSwipe = false
    @State private var isEditingHeaderImage = false
    @State private var headerImageOffset: CGFloat = 0
    @State private var headerImageScale: CGFloat = 1.0
    @State private var lastHeaderImageOffset: CGFloat = 0
    
    // Date selection
    @State private var showingSettings = false
    @State private var dayOffset: Int = 0
    @State private var viewDates: [Date] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return [
            calendar.date(byAdding: .day, value: -1, to: today) ?? today,
            today,
            calendar.date(byAdding: .day, value: 1, to: today) ?? today
        ]
    }()
    
    // Extracted colors from header image
    @State private var extractedColors: (primary: Color, secondary: Color)? = nil
    
    // Layout constants
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    private let baseHourHeight: CGFloat = DeviceType.isIPad ? 80 : 136  // Base height, will be scaled
    private var hourHeight: CGFloat {
        baseHourHeight * zoomScale
    }
    private let timeColumnWidth: CGFloat = DeviceType.isIPad ? 70 : 58
    private let headerHeight: CGFloat = 0
    private let rightPadding: CGFloat = 16
    private let minDragDistance: CGFloat = 8
    private let velocityThreshold: CGFloat = 150
    private let swipeAnimationDuration: Double = 0.3
    private let gapBetweenColumns: CGFloat = 4
    private let minZoomScale: CGFloat = 0.5  // Can zoom out to see twice as much
    private let maxZoomScale: CGFloat = 3.0  // Can zoom in 3x for detail
    
    private var todayDate: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    var body: some View {
        ZStack {
            // Super light gray background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
                .transition(.identity)
            
            VStack(spacing: 0) {
                // Stack with blue header extending behind content
                ZStack(alignment: .top) {
                    // Background - either custom image or gradient
                    if let headerData = SettingsView.loadHeaderImage() {
                        // Image with gesture
                        GeometryReader { imageGeo in
                            Image(uiImage: headerData.image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: imageGeo.size.width)
                                .offset(y: headerImageOffset)
                                .overlay(
                                    // Dark overlay
                                    Color.black.opacity(isEditingHeaderImage ? 0.1 : 0.3)
                                )
                                .gesture(
                                    isEditingHeaderImage ?
                                    DragGesture()
                                        .onChanged { value in
                                            print("🎯 Dragging: \(value.translation.height)")
                                            headerImageOffset = lastHeaderImageOffset + value.translation.height
                                        }
                                        .onEnded { _ in
                                            print("🎯 Drag ended, saving offset: \(headerImageOffset)")
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
                                print("🎯 Manual trigger: Starting header edit mode")
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
                        .ignoresSafeArea()
                    }
                    
                    VStack(spacing: 0) {
                        if DeviceType.isIPhone {
                            GeometryReader { geo in
                                HStack(spacing: 0) {
                                    ForEach(0..<3, id: \.self) { index in
                                        dayContentView(for: viewDates[index])
                                            .frame(width: geo.size.width)
                                    }
                                }
                                .offset(x: -geo.size.width + (isDraggingTimeBlock ? 0 : dragOffset))
                                .gesture(
                                    DragGesture(minimumDistance: minDragDistance)
                                        .onChanged { value in
                                            guard !isAnimatingSwipe, !isDraggingTimeBlock else { return }
                                            let horizontal = abs(value.translation.width)
                                            let vertical = abs(value.translation.height)
                                            if horizontal > vertical * 1.5, horizontal > minDragDistance {
                                                dragOffset = value.translation.width
                                            }
                                        }
                                        .onEnded { value in
                                            guard !isAnimatingSwipe, !isDraggingTimeBlock else { return }
                                            let screenWidth = UIScreen.main.bounds.width
                                            let predictedVelocity = value.predictedEndLocation.x - value.location.x
                                            let horizontal = abs(value.translation.width)
                                            let vertical = abs(value.translation.height)
                                            
                                            guard horizontal > vertical * 1.5 else {
                                                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.9)) {
                                                    dragOffset = 0
                                                }
                                                return
                                            }
                                            
                                            if abs(predictedVelocity) > velocityThreshold {
                                                if predictedVelocity > 0 {
                                                    swipeToPreviousDay(screenWidth: screenWidth)
                                                } else {
                                                    swipeToNextDay(screenWidth: screenWidth)
                                                }
                                            } else if abs(dragOffset) > screenWidth * 0.3 {
                                                if dragOffset > 0 {
                                                    swipeToPreviousDay(screenWidth: screenWidth)
                                                } else {
                                                    swipeToNextDay(screenWidth: screenWidth)
                                                }
                                            } else {
                                                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.9)) {
                                                    dragOffset = 0
                                                }
                                            }
                                        }
                                )
                            }
                        } else {
                            dayContentView(for: viewDates[1])
                        }
                    }
                }
            }
            
        }
        .navigationBarHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowAddEvent"))) { _ in
            viewModel.showingAddEvent = true
        }
        .onAppear {
            setupInitialDates()
            viewModel.selectedDate = Calendar.current.date(
                byAdding: .day, value: dayOffset, to: todayDate
            ) ?? todayDate
            preloadSurroundingDays()
            // Load saved header image position
            headerImageOffset = CGFloat(UserDefaults.standard.double(forKey: "headerImageVerticalOffset"))
            lastHeaderImageOffset = headerImageOffset
            
            // Load saved zoom scale
            let savedZoom = CGFloat(UserDefaults.standard.double(forKey: "timelineZoomScale"))
            if savedZoom > 0 {
                zoomScale = savedZoom
                lastZoomScale = savedZoom
            }
            
            // Load gradient colors based on settings
            let useAutoGradient = UserDefaults.standard.bool(forKey: "useAutoGradient")
            
            if useAutoGradient {
                // Load extracted colors from header image
                self.extractedColors = UserDefaults.standard.getExtractedColors()
                print("🎨 Loaded extracted colors: \(extractedColors != nil ? "Found" : "None")")
                
                // If no colors saved but we have an image, extract them
                if extractedColors == nil, let headerData = SettingsView.loadHeaderImage() {
                    print("🎨 No saved colors, extracting from image...")
                    let colors = ColorExtractor.extractColors(from: headerData.image)
                    UserDefaults.standard.setExtractedColors(colors)
                    self.extractedColors = (colors.primary, colors.secondary)
                    print("🎨 Extracted colors - Primary: \(colors.primary), Secondary: \(colors.secondary)")
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
                print("🎯 Should start header edit mode")
                UserDefaults.standard.set(false, forKey: "shouldStartHeaderEdit")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🎯 Starting header edit mode")
                    withAnimation {
                        isEditingHeaderImage = true
                    }
                }
            }
        }
        .onChange(of: dayOffset) { _, _ in
            viewModel.selectedDate = Calendar.current.date(
                byAdding: .day, value: dayOffset, to: todayDate
            ) ?? todayDate
        }
        .onChange(of: isDraggingTimeBlock) { _, dragging in
            if dragging { dragOffset = 0 }
        }
        .optimizedSheet(isPresented: $viewModel.showingAddEvent) {
            LazyView(AddEventView())
        }
        .optimizedSheet(item: $viewModel.selectedEvent) { event in
            LazyView(EventDetailView(event: event))
        }
        .optimizedSheet(isPresented: $showingSettings) {
            LazyView(NavigationView { SettingsView() })
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
    
    // MARK: - Date Navigation & Preloading
    
    private func setupInitialDates() {
        let calendar = Calendar.current
        viewDates = [
            calendar.date(byAdding: .day, value: dayOffset - 1, to: todayDate) ?? todayDate,
            calendar.date(byAdding: .day, value: dayOffset,     to: todayDate) ?? todayDate,
            calendar.date(byAdding: .day, value: dayOffset + 1, to: todayDate) ?? todayDate
        ]
    }
    
    private func swipeToNextDay(screenWidth: CGFloat) {
        isAnimatingSwipe = true
        withAnimation(.easeInOut(duration: swipeAnimationDuration)) {
            dragOffset = -screenWidth
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + swipeAnimationDuration) {
            dayOffset += 1
            setupInitialDates()
            preloadSurroundingDays()
            dragOffset = 0
            isAnimatingSwipe = false
        }
    }
    
    private func swipeToPreviousDay(screenWidth: CGFloat) {
        isAnimatingSwipe = true
        withAnimation(.easeInOut(duration: swipeAnimationDuration)) {
            dragOffset = screenWidth
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + swipeAnimationDuration) {
            dayOffset -= 1
            setupInitialDates()
            preloadSurroundingDays()
            dragOffset = 0
            isAnimatingSwipe = false
        }
    }
    
    private func preloadSurroundingDays() {
        let calendar = Calendar.current
        let dates = (-1...1).compactMap {
            calendar.date(byAdding: .day, value: dayOffset + $0, to: todayDate)
        }
        dependencyContainer.scheduleManager.preloadEvents(for: dates)
    }
    
    // MARK: - Day View
    
    @ViewBuilder
    private func dayContentView(for date: Date) -> some View {
        VStack(spacing: 0) {
            // Header container - always same expanded size
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
                onSettings: {
                    showingSettings = true
                },
                onAddEvent: {
                    viewModel.showingAddEvent = true
                },
                onDateSelected: navigateToDate,
                showViewToggle: true // Enable view toggle for iPad
            )
            .opacity(isEditingHeaderImage ? 0 : 1) // Hide content but maintain size
            
            // Timeline extends all the way up - no gap
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
                    .allowsHitTesting(false)
                }
                
                VStack(spacing: 0) {
                    let isCurrentDay = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
                    let scrollBinding = Binding<CGFloat>(
                        get: { 
                            // Adjust default scroll position based on zoom level
                            // Default to 7am position, scaled by zoom
                            let baseOffset: CGFloat = DeviceType.isIPad ? 560 : 952  // 7 hours * base hour height
                            let scaledOffset = baseOffset * zoomScale
                            return dependencyContainer.scrollPositionManager.offset(for: 0, default: scaledOffset) 
                        },
                        set: { newValue in
                            if isCurrentDay {
                                dependencyContainer.scrollPositionManager.update(dayOffset: 0, to: newValue)
                            }
                        }
                    )
                    
                    PersistentScrollView(offset: scrollBinding, isScrollEnabled: !isDraggingTimeBlock) {
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { _ in
                            Color.clear.frame(height: hourHeight)
                        }
                        // Scale padding based on 59% zoom being perfect with 70px
                        Color.clear.frame(height: 70 * (zoomScale / 0.59))
                    }
                    .overlay(alignment: .bottomTrailing) {
                        // Zoom indicator
                        if zoomScale != 1.0 {
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    zoomScale = 1.0
                                    lastZoomScale = 1.0
                                    UserDefaults.standard.set(1.0, forKey: "timelineZoomScale")
                                }
                                HapticFeedback.light.trigger()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 11, weight: .medium))
                                    Text("\(Int(zoomScale * 100))%")
                                        .scaledFont(size: 11, weight: .semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.5))
                                        .background(
                                            Capsule()
                                                .fill(.ultraThinMaterial)
                                        )
                                )
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .background(
                        DayTimelineView(
                            selectedDate: date, 
                            showCurrentTime: false, 
                            extractedColors: extractedColors, 
                            hourHeight: hourHeight,
                            bottomPadding: 70 * (zoomScale / 0.59)
                        )
                            .overlay(alignment: .topLeading) {
                                GeometryReader { geo in
                                    let events = dependencyContainer.scheduleManager.events(for: date)
                                    let isToday = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
                                    let layouts = viewModel.calculateEventLayout(for: events, hourHeight: hourHeight)
                                    let availableWidth = geo.size.width - timeColumnWidth - rightPadding
                                    
                                    ForEach(layouts, id: \.event.id) { layout in
                                        TimeBlockView(
                                            event: layout.event,
                                            hourHeight: hourHeight,
                                            onTap: {
                                                if isToday { viewModel.handleEventTap(layout.event) }
                                            },
                                            isDraggingAnyBlock: $isDraggingTimeBlock
                                        )
                                        .frame(
                                            width: max(10, (availableWidth - CGFloat(max(1, layout.totalColumns - 1)) * gapBetweenColumns)
                                                / CGFloat(max(1, layout.totalColumns))),
                                            height: layout.height  // Use exact height, no minimum
                                        )
                                        .offset(
                                            x: timeColumnWidth +
                                                CGFloat(layout.column) *
                                                ((availableWidth - CGFloat(layout.totalColumns - 1) * gapBetweenColumns)
                                                 / CGFloat(layout.totalColumns) + gapBetweenColumns),
                                            y: layout.yPosition
                                        )
                                        .allowsHitTesting(isToday)
                                        .id(layout.event.id)
                                    }
                                }
                            }
                            .overlay(alignment: .topLeading) {
                                if Calendar.current.isDateInToday(date) {
                                    CurrentTimeIndicator(hourHeight: hourHeight)
                                }
                            }
                            .frame(maxWidth: .infinity)
                    )
                    }
                }
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        // Store the current scroll position before scaling
                        let currentOffset = dependencyContainer.scrollPositionManager.offset(for: 0, default: 0)
                        let oldScale = zoomScale
                        
                        // Update the scale
                        let newScale = lastZoomScale * value
                        zoomScale = min(max(newScale, minZoomScale), maxZoomScale)
                        
                        // Adjust scroll position to keep the same content in view
                        if oldScale != zoomScale {
                            let scaleFactor = zoomScale / oldScale
                            let newOffset = currentOffset * scaleFactor
                            dependencyContainer.scrollPositionManager.update(dayOffset: 0, to: newOffset)
                        }
                    }
                    .onEnded { value in
                        lastZoomScale = zoomScale
                        // Save zoom preference
                        UserDefaults.standard.set(zoomScale, forKey: "timelineZoomScale")
                        HapticFeedback.light.trigger()
                    }
            )
            .frame(maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground))
            .clipShape(
                .rect(
                    topLeadingRadius: 40,
                    topTrailingRadius: 40
                )
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        return Date.formatDateWithGreeting(date)
    }
    
    private func navigateToDate(_ target: Date) {
        let calendar = Calendar.current
        let startTarget = calendar.startOfDay(for: target)
        let startToday = calendar.startOfDay(for: todayDate)
        guard let diff = calendar.dateComponents([.day], from: startToday, to: startTarget).day else {
            return
        }
        dayOffset = diff
        setupInitialDates()
        viewModel.selectedDate = startTarget
        viewModel.refreshEvents()
        preloadSurroundingDays()
    }
}