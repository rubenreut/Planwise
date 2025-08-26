//
//  UnifiedWeekView.swift
//  Momentum
//
//  A unified, improved week view that works on both iPhone and iPad
//  with smart event layout, readable text, and optimized space usage
//

import SwiftUI
import Combine

// MARK: - Main Unified Week View

struct UnifiedWeekView: View {
    @StateObject private var viewModel = UnifiedWeekViewModel()
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedEvent: Event?
    @State private var showingAddEvent = false
    @State private var selectedTimeSlot: (date: Date, hour: Int)?
    @State private var showingMiniCalendar = false
    @State private var draggedEvent: Event?
    @State private var extractedColors: (primary: Color, secondary: Color)? = nil
    @State private var isEditingHeaderImage = false
    @State private var headerImageOffset: CGFloat = 0
    @State private var lastHeaderImageOffset: CGFloat = 0
    
    // Adaptive layout constants
    private var hourHeight: CGFloat {
        horizontalSizeClass == .regular ? 70 : 60
    }
    
    private var timeColumnWidth: CGFloat {
        horizontalSizeClass == .regular ? 55 : 45
    }
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
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
                        // Premium header like Day view
                        PremiumHeaderView(
                            dateTitle: viewModel.weekTitle,
                            selectedDate: viewModel.currentWeekStart,
                            onPreviousDay: viewModel.previousWeek,
                            onNextDay: viewModel.nextWeek,
                            onToday: viewModel.goToToday,
                            onSettings: {},
                            onAddEvent: { showingAddEvent = true },
                            onDateSelected: nil,
                            showViewToggle: true, // Enable view toggle for iPad
                            isWeekView: true // Show week icon
                        )
                        .opacity(isEditingHeaderImage ? 0 : 1)
                        .zIndex(2)
                        
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
        }
        .navigationBarHidden(true)
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
                
                self.extractedColors = (baseColor, baseColor.opacity(0.7))
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
        .sheet(isPresented: $showingAddEvent) {
            if let slot = selectedTimeSlot {
                AddEventView(preselectedDate: slot.date, preselectedHour: slot.hour)
            } else {
                AddEventView()
            }
        }
        .sheet(isPresented: $showingMiniCalendar) {
            MiniCalendarView(selectedWeek: $viewModel.currentWeekStart)
                .presentationDetents([.height(400)])
        }
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
        if let headerData = AppearanceSettingsViewModel.loadHeaderImage() {
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
            }
            .frame(height: 280)
            .ignoresSafeArea()
        } else {
            // Default blue gradient background
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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Days header (no weekSummaryBar needed since we have PremiumHeaderView)
                daysHeader(width: geometry.size.width)
                    .padding(.top, 20)
                    .background(Color.clear)
                    .zIndex(2)
                
                // Main content
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            // Time grid background
                            timeGridBackground(width: geometry.size.width)
                            
                            // Events layer with smart layout
                            eventsLayer(width: geometry.size.width)
                            
                            // Current time indicator
                            if viewModel.isCurrentWeek {
                                currentTimeIndicator(width: geometry.size.width)
                            }
                        }
                        .frame(height: CGFloat(24) * hourHeight)
                    }
                    .onAppear {
                        scrollToCurrentTime(proxy: scrollProxy)
                    }
                }
            }
        }
    }
    
    // MARK: - Week Summary Bar (Removed - using PremiumHeaderView instead)
    // The weekSummaryBar is no longer needed since we're using PremiumHeaderView
    // which already provides navigation controls
    
    // MARK: - Days Header
    
    private func daysHeader(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Empty space for time column
            Color.clear
                .frame(width: timeColumnWidth)
            
            // Day headers
            HStack(spacing: 1) {
                ForEach(viewModel.weekDates, id: \.self) { date in
                    dayHeaderView(for: date)
                }
            }
        }
        .frame(height: 60)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    private func dayHeaderView(for date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let events = viewModel.events(for: date)
        
        return VStack(spacing: 2) {
            Text(dayName(for: date))
                .scaledFont(size: 11, weight: .medium)
                .foregroundColor(isToday ? .blue : .secondary)
            
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 30, height: 30)
                }
                
                Text("\(Calendar.current.component(.day, from: date))")
                    .scaledFont(size: 16, weight: isToday ? .bold : .medium)
                    .foregroundColor(isToday ? .white : .primary)
            }
            
            // Event indicator dots
            if !events.isEmpty {
                HStack(spacing: 2) {
                    ForEach(0..<min(events.count, 3), id: \.self) { _ in
                        Circle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTimeSlot = (date: date, hour: 9)
            showingAddEvent = true
        }
    }
    
    // MARK: - Time Grid Background
    
    private func timeGridBackground(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Time labels
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(formatHour(hour))
                        .scaledFont(size: 10, weight: .medium)
                        .foregroundColor(.secondary)
                        .frame(width: timeColumnWidth, height: hourHeight, alignment: .topTrailing)
                        .padding(.top, -6)
                        .padding(.trailing, 4)
                        .id("hour-\(hour)")
                }
            }
            
            // Grid lines
            ZStack(alignment: .topLeading) {
                // Vertical day separators
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 0.5),
                                alignment: .trailing
                            )
                    }
                }
                
                // Horizontal hour lines
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: hourHeight)
                            .overlay(
                                Rectangle()
                                    .fill(Color.gray.opacity(hour % 2 == 0 ? 0.15 : 0.08))
                                    .frame(height: 0.5),
                                alignment: .top
                            )
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleGridTap(location: location, width: width)
            }
        }
    }
    
    // MARK: - Events Layer
    
    private func eventsLayer(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Empty space for time column
            Color.clear
                .frame(width: timeColumnWidth)
            
            // Day columns with events
            HStack(spacing: 1) {
                ForEach(viewModel.weekDates, id: \.self) { date in
                    dayEventsColumn(for: date, width: width)
                }
            }
        }
    }
    
    private func dayEventsColumn(for date: Date, width: CGFloat) -> some View {
        let columnWidth = (width - timeColumnWidth) / 7.0 - 1.0
        let events = viewModel.eventsWithLayout(for: date)
        
        return ZStack(alignment: .topLeading) {
            Color.clear
            
            ForEach(events) { eventLayout in
                UnifiedEventBlock(
                    event: eventLayout.event,
                    layout: eventLayout,
                    hourHeight: hourHeight,
                    columnWidth: columnWidth,
                    onTap: { selectedEvent = eventLayout.event },
                    onDrag: isIPad ? { draggedEvent = eventLayout.event } : nil
                )
                .offset(y: eventLayout.topOffset(hourHeight: hourHeight))
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Current Time Indicator
    
    private func currentTimeIndicator(width: CGFloat) -> some View {
        CurrentTimeLineView(
            weekDates: viewModel.weekDates,
            hourHeight: hourHeight,
            timeColumnWidth: timeColumnWidth,
            totalWidth: width
        )
    }
    
    // MARK: - Helper Methods
    
    private func handleGridTap(location: CGPoint, width: CGFloat) {
        let dayWidth = (width - timeColumnWidth) / 7.0
        let adjustedX = location.x - timeColumnWidth
        let dayIndex = min(6, max(0, Int(adjustedX / dayWidth)))
        let date = viewModel.weekDates[dayIndex]
        let hour = min(23, max(0, Int(location.y / hourHeight)))
        
        selectedTimeSlot = (date: date, hour: hour)
        showingAddEvent = true
    }
    
    private func scrollToCurrentTime(proxy: ScrollViewProxy) {
        if viewModel.isCurrentWeek {
            let currentHour = Calendar.current.component(.hour, from: Date())
            let targetHour = max(0, currentHour - 2)
            withAnimation {
                proxy.scrollTo("hour-\(targetHour)", anchor: .top)
            }
        }
    }
    
    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }
}

// MARK: - Event Block Component

struct UnifiedEventBlock: View {
    let event: Event
    let layout: EventLayoutInfo
    let hourHeight: CGFloat
    let columnWidth: CGFloat
    let onTap: () -> Void
    let onDrag: (() -> Void)?
    
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    private var eventColor: Color {
        if let colorHex = event.category?.colorHex {
            return Color(hex: colorHex) ?? .blue
        }
        return .blue
    }
    
    private var effectiveWidth: CGFloat {
        (columnWidth - 8) * layout.widthMultiplier - CGFloat(layout.column * 2)
    }
    
    private var horizontalOffset: CGFloat {
        4 + CGFloat(layout.column) * (columnWidth - 8) * layout.widthMultiplier
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Accent bar
            Rectangle()
                .fill(eventColor)
                .frame(width: 2)
            
            // Content
            VStack(alignment: .leading, spacing: 1) {
                // Title with dynamic font size
                HStack(spacing: 3) {
                    if let iconName = event.category?.iconName {
                        Image(systemName: iconName)
                            .font(.system(size: fontSize - 2, weight: .medium))
                            .foregroundColor(eventColor)
                    }
                    
                    Text(event.title ?? "Untitled")
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(layout.height(hourHeight: hourHeight) > 30 ? 2 : 1)
                }
                
                // Time for taller events
                if layout.height(hourHeight: hourHeight) > 35 {
                    Text(formatTimeRange())
                        .font(.system(size: fontSize - 3, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Location for even taller events
                if layout.height(hourHeight: hourHeight) > 50, let location = event.location, !location.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "location.fill")
                            .font(.system(size: fontSize - 4))
                        Text(location)
                            .font(.system(size: fontSize - 3))
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            
            Spacer(minLength: 0)
        }
        .frame(width: effectiveWidth, height: layout.height(hourHeight: hourHeight))
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(eventColor.opacity(colorScheme == .dark ? 0.3 : 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(eventColor.opacity(0.3), lineWidth: 0.5)
        )
        .offset(x: horizontalOffset)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .onTapGesture {
            isPressed = true
            onTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
        .onLongPressGesture {
            onDrag?()
        }
    }
    
    private var fontSize: CGFloat {
        let height = layout.height(hourHeight: hourHeight)
        if height < 25 {
            return 9
        } else if height < 40 {
            return 10
        } else if height < 60 {
            return 11
        } else {
            return 12
        }
    }
    
    private func formatTimeRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        guard let start = event.startTime,
              let end = event.endTime else { return "" }
        
        let startStr = formatter.string(from: start)
        
        // If same day, show range, otherwise just start time
        if Calendar.current.isDate(start, inSameDayAs: end) {
            formatter.dateFormat = "h:mm a"
            return "\(startStr) - \(formatter.string(from: end))"
        } else {
            return startStr
        }
    }
}

// MARK: - Current Time Line

struct CurrentTimeLineView: View {
    let weekDates: [Date]
    let hourHeight: CGFloat
    let timeColumnWidth: CGFloat
    let totalWidth: CGFloat
    
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        let calendar = Calendar.current
        let todayIndex = weekDates.firstIndex { calendar.isDateInToday($0) } ?? -1
        
        if todayIndex >= 0 {
            let currentHour = calendar.component(.hour, from: currentTime)
            let currentMinute = calendar.component(.minute, from: currentTime)
            let yOffset = CGFloat(currentHour) * hourHeight + (CGFloat(currentMinute) / 60.0 * hourHeight)
            let columnWidth = (totalWidth - timeColumnWidth) / 7.0
            
            HStack(spacing: 0) {
                // Time badge
                Text(formatTime(currentTime))
                    .scaledFont(size: 10, weight: .semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
                    .frame(width: timeColumnWidth, alignment: .trailing)
                    .padding(.trailing, 4)
                
                // Line
                Rectangle()
                    .fill(Color.red)
                    .frame(width: columnWidth - 8, height: 1.5)
                    .offset(x: CGFloat(todayIndex) * columnWidth + 4)
                
                Spacer()
            }
            .offset(y: yOffset)
            .onReceive(timer) { _ in
                currentTime = Date()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Mini Calendar View

struct MiniCalendarView: View {
    @Binding var selectedWeek: Date
    @Environment(\.dismiss) var dismiss
    
    @State private var displayedMonth = Date()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month navigation
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                    }
                    
                    Spacer()
                    
                    Text(monthYearString)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                    }
                }
                .padding()
                
                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    // Day headers
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    
                    // Days
                    ForEach(calendarDays, id: \.self) { date in
                        if let date = date {
                            dayView(for: date)
                        } else {
                            Color.clear
                                .frame(height: 36)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Select Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Today") {
                        selectWeek(containing: Date())
                    }
                }
            }
        }
    }
    
    private func dayView(for date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let isInSelectedWeek = isInWeek(date, weekStart: selectedWeek)
        let isCurrentMonth = Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        
        return Text("\(Calendar.current.component(.day, from: date))")
            .scaledFont(size: 14, weight: isToday ? .bold : .regular)
            .foregroundColor(isCurrentMonth ? .primary : .secondary)
            .frame(width: 36, height: 36)
            .background(
                ZStack {
                    if isToday {
                        Circle().fill(Color.blue)
                    } else if isInSelectedWeek {
                        RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.2))
                    }
                }
            )
            .foregroundColor(isToday ? .white : nil)
            .onTapGesture {
                selectWeek(containing: date)
            }
    }
    
    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: displayedMonth)!.start
        let startWeekday = calendar.component(.weekday, from: startOfMonth)
        
        var days: [Date?] = Array(repeating: nil, count: startWeekday - 1)
        
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }
    
    private func isInWeek(_ date: Date, weekStart: Date) -> Bool {
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart)!
        return weekInterval.contains(date)
    }
    
    private func selectWeek(containing date: Date) {
        let calendar = Calendar.current
        if let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start {
            selectedWeek = weekStart
            dismiss()
        }
    }
    
    private func previousMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
    
    private func nextMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

// MARK: - View Model

@MainActor
class UnifiedWeekViewModel: ObservableObject {
    @Published var currentWeekStart: Date
    @Published var events: [Event] = []
    @Published private var eventLayouts: [Date: [EventLayoutInfo]] = [:]
    
    private let scheduleManager = ScheduleManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    var weekDates: [Date] {
        (0..<7).compactMap { dayOffset in
            Calendar.current.date(byAdding: .day, value: dayOffset, to: currentWeekStart)
        }
    }
    
    var weekTitle: String {
        // Show greeting for current week
        if isCurrentWeek {
            return Date.formatDateWithGreeting(Date())
        }
        
        // Show date range for other weeks
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: currentWeekStart)
        
        if let endDate = Calendar.current.date(byAdding: .day, value: 6, to: currentWeekStart) {
            let end = formatter.string(from: endDate)
            let year = Calendar.current.component(.year, from: endDate)
            return "\(start) - \(end), \(year)"
        }
        return start
    }
    
    var totalEvents: Int {
        events.count
    }
    
    var totalHours: Double {
        events.reduce(0) { total, event in
            guard let start = event.startTime, let end = event.endTime else { return total }
            return total + end.timeIntervalSince(start) / 3600
        }
    }
    
    var isCurrentWeek: Bool {
        let calendar = Calendar.current
        return calendar.isDate(Date(), equalTo: currentWeekStart, toGranularity: .weekOfYear)
    }
    
    init() {
        let calendar = Calendar.current
        self.currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
        loadEvents()
        
        scheduleManager.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadEvents()
            }
            .store(in: &cancellables)
    }
    
    func loadEvents() {
        let calendar = Calendar.current
        events = scheduleManager.events.filter { event in
            guard let startTime = event.startTime else { return false }
            return weekDates.contains { calendar.isDate(startTime, inSameDayAs: $0) }
        }
        
        // Calculate layouts for each day
        for date in weekDates {
            let dayEvents = events(for: date)
            eventLayouts[date] = calculateEventLayouts(for: dayEvents)
        }
    }
    
    func events(for date: Date) -> [Event] {
        let calendar = Calendar.current
        return events.filter { event in
            guard let startTime = event.startTime else { return false }
            return calendar.isDate(startTime, inSameDayAs: date)
        }.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
    }
    
    func eventsWithLayout(for date: Date) -> [EventLayoutInfo] {
        return eventLayouts[date] ?? []
    }
    
    func previousWeek() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) ?? currentWeekStart
            loadEvents()
        }
    }
    
    func nextWeek() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? currentWeekStart
            loadEvents()
        }
    }
    
    func goToToday() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            let calendar = Calendar.current
            currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            loadEvents()
        }
    }
    
    // MARK: - Smart Event Layout Algorithm
    
    private func calculateEventLayouts(for events: [Event]) -> [EventLayoutInfo] {
        var layouts: [EventLayoutInfo] = []
        var columns: [[EventLayoutInfo]] = []
        
        for event in events {
            guard let startTime = event.startTime,
                  let endTime = event.endTime else { continue }
            
            // Find the first column where this event fits
            var placed = false
            for i in 0..<columns.count {
                let lastInColumn = columns[i].last
                if let last = lastInColumn,
                   let lastEnd = last.event.endTime,
                   startTime >= lastEnd {
                    // Event fits in this column
                    let layout = EventLayoutInfo(
                        event: event,
                        column: i,
                        columnCount: 1,
                        startTime: startTime,
                        endTime: endTime
                    )
                    columns[i].append(layout)
                    layouts.append(layout)
                    placed = true
                    break
                }
            }
            
            // If not placed, create a new column
            if !placed {
                let layout = EventLayoutInfo(
                    event: event,
                    column: columns.count,
                    columnCount: 1,
                    startTime: startTime,
                    endTime: endTime
                )
                columns.append([layout])
                layouts.append(layout)
            }
        }
        
        // Update column counts and width multipliers
        let totalColumns = columns.count
        for i in 0..<layouts.count {
            layouts[i].columnCount = totalColumns
            layouts[i].widthMultiplier = totalColumns > 0 ? 1.0 / CGFloat(totalColumns) : 1.0
        }
        
        return layouts
    }
}

// MARK: - Event Layout Info

struct EventLayoutInfo: Identifiable {
    let id = UUID()
    let event: Event
    var column: Int
    var columnCount: Int
    let startTime: Date
    let endTime: Date
    var widthMultiplier: CGFloat = 1.0
    
    func topOffset(hourHeight: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: startTime)
        let minute = calendar.component(.minute, from: startTime)
        return CGFloat(hour) * hourHeight + CGFloat(minute) * hourHeight / 60
    }
    
    func height(hourHeight: CGFloat) -> CGFloat {
        let duration = endTime.timeIntervalSince(startTime) / 3600 // in hours
        return max(20, CGFloat(duration) * hourHeight)
    }
}

// MARK: - Preview

struct UnifiedWeekView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedWeekView()
            .environmentObject(ScheduleManager.shared)
    }
}