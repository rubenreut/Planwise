import Foundation
import SwiftUI
import Combine

@MainActor
class DayViewModel: ObservableObject {
    // MVVM: ViewModel never owns data, only references the Manager
    private let scheduleManager: any ScheduleManaging
    
    init(scheduleManager: (any ScheduleManaging)? = nil) {
        self.scheduleManager = scheduleManager ?? ScheduleManager.shared
        setupObservers()
        // Delay initial load to ensure ScheduleManager is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.loadEvents()
            // Disabled: This was causing date changes that reset scroll position
            // self?.checkForTodayEvents()
        }
    }
    
    @Published var selectedDate: Date = {
        // Start with today, but we'll check for events in init
        return Date()
    }()
    @Published var events: [Event] = []
    @Published var showingAddEvent = false
    @Published var selectedEvent: Event?
    @Published var isLoading = false
    
    // View state management
    @Published var viewState: ViewState<[Event]> = .loading
    @Published var loadError: Error?
    
    // For new event creation from timeline tap
    @Published var newEventStartTime: Date?
    
    private var cancellables = Set<AnyCancellable>()
    private let calendar = Calendar.current
    
    // Layout cache for performance
    private var layoutCache = [Date: [EventLayout]]()
    private let layoutCacheLock = NSLock()
    
    private func checkForTodayEvents() {
        // If today has no events, find the most recent date with events
        if events.isEmpty && !scheduleManager.events.isEmpty {
            
            // Sort all events by date
            let sortedEvents = scheduleManager.events
                .compactMap { $0.startTime }
                .sorted()
            
            if let mostRecentPastEvent = sortedEvents.last(where: { $0 < Date() }) {
                // Found a past event, go to that date
                selectedDate = mostRecentPastEvent
            } else if let nearestFutureEvent = sortedEvents.first(where: { $0 > Date() }) {
                // No past events, use nearest future event
                selectedDate = nearestFutureEvent
            }
        }
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe changes from ScheduleManager
        scheduleManager.eventsPublisher
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadEvents()
            }
            .store(in: &cancellables)
        
        // Reload when date changes
        $selectedDate
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.loadEvents()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    func refreshEvents() {
        // Clear layout cache when events refresh
        layoutCacheLock.lock()
        layoutCache.removeAll()
        layoutCacheLock.unlock()
        
        loadEvents()
    }
    
    private func loadEvents() {
        // Set loading state
        viewState = .loading
        loadError = nil
        
        // Simulate async loading with proper error handling
        _Concurrency.Task {
            do {
                // Add a small delay for better UX on fast operations
                try await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // ISSUE: Need to efficiently filter events for selected date
                // RESOLUTION: Use ScheduleManager's filtered method instead of filtering all events
                let allEvents = scheduleManager.events
                
                // Debug: Show what day we're looking at
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                
                let fetchedEvents = scheduleManager.events(for: selectedDate)
                    .sorted { ($0.startTime ?? Date.distantPast) < ($1.startTime ?? Date.distantPast) }
                
                for event in fetchedEvents {
                    formatter.dateFormat = "yyyy-MM-dd HH:mm"
                }
                
                // Update state
                await MainActor.run {
                    self.events = fetchedEvents
                    self.viewState = fetchedEvents.isEmpty ? .empty : .loaded(fetchedEvents)
                    self.isLoading = false
                    
                    // Force UI update
                    self.objectWillChange.send()
                }
            } catch {
                await MainActor.run {
                    self.loadError = error
                    self.viewState = .error(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Event Positioning
    func calculateEventPosition(_ event: Event) -> CGFloat {
        guard let startTime = event.startTime else { return 0 }
        
        // Use local time zone for display
        let localStartTime = startTime // Date is already in correct timezone when displayed
        let components = calendar.dateComponents([.hour, .minute], from: localStartTime)
        let hour = CGFloat(components.hour ?? 0)
        let minute = CGFloat(components.minute ?? 0)
        
        // Use the actual hour height from the view
        let hourHeight: CGFloat = DeviceType.isIPad ? 80 : 68
        let position = (hour * hourHeight) + (minute * hourHeight / 60)
        
        return position
    }
    
    func calculateEventHeight(_ event: Event) -> CGFloat {
        guard let startTime = event.startTime,
              let endTime = event.endTime else { return 0 }
        
        let duration = endTime.timeIntervalSince(startTime)
        let minutes = duration / 60
        let hourHeight: CGFloat = DeviceType.isIPad ? 80 : 68
        let height = CGFloat(minutes) * (hourHeight / 60.0)
        
        // Return exact height - no minimum
        return height
    }
    
    // MARK: - Overlapping Events
    func calculateEventLayout(for events: [Event]? = nil) -> [EventLayout] {
        let eventsToLayout = events ?? self.events
        
        // Check cache first
        if events == nil {
            layoutCacheLock.lock()
            if let cached = layoutCache[selectedDate] {
                layoutCacheLock.unlock()
                return cached
            }
            layoutCacheLock.unlock()
        }
        
        // ISSUE: Events can overlap on timeline
        // RESOLUTION: Calculate columns for overlapping events
        
        var layouts: [EventLayout] = []
        var columns: [[Event]] = []
        
        for event in eventsToLayout {
            guard let eventStart = event.startTime,
                  let eventEnd = event.endTime else { continue }
            
            // Find a column where this event fits
            var placed = false
            for (index, column) in columns.enumerated() {
                let canFit = column.allSatisfy { existingEvent in
                    guard let existingStart = existingEvent.startTime,
                          let existingEnd = existingEvent.endTime else { return true }
                    
                    // Check if events don't overlap
                    return eventEnd <= existingStart || eventStart >= existingEnd
                }
                
                if canFit {
                    columns[index].append(event)
                    layouts.append(EventLayout(
                        event: event,
                        column: index,
                        totalColumns: columns.count,
                        yPosition: calculateEventPosition(event),
                        height: calculateEventHeight(event)
                    ))
                    placed = true
                    break
                }
            }
            
            // Create new column if needed
            if !placed {
                columns.append([event])
                layouts.append(EventLayout(
                    event: event,
                    column: columns.count - 1,
                    totalColumns: columns.count,
                    yPosition: calculateEventPosition(event),
                    height: calculateEventHeight(event)
                ))
            }
        }
        
        // Update total columns for all layouts
        let totalColumns = columns.count
        let finalLayouts = layouts.map { layout in
            EventLayout(
                event: layout.event,
                column: layout.column,
                totalColumns: totalColumns,
                yPosition: layout.yPosition,
                height: layout.height
            )
        }
        
        // Cache if using default events
        if events == nil {
            layoutCacheLock.lock()
            layoutCache[selectedDate] = finalLayouts
            layoutCacheLock.unlock()
        }
        
        return finalLayouts
    }
    
    // MARK: - User Actions
    func handleTimelineTap(at hour: Int, minute: Int = 0) {
        // Create date at tapped time
        guard let tappedTime = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: selectedDate
        ) else { return }
        
        // Check if tapping on existing event
        let tappedEvents = events.filter { event in
            guard let start = event.startTime,
                  let end = event.endTime else { return false }
            return tappedTime >= start && tappedTime < end
        }
        
        if let existingEvent = tappedEvents.first {
            // Edit existing event
            selectedEvent = existingEvent
        } else {
            // Create new event at this time
            newEventStartTime = tappedTime
            showingAddEvent = true
        }
    }
    
    func handleEventTap(_ event: Event) {
        selectedEvent = event
    }
    
    // MARK: - Date Navigation
    func goToToday() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedDate = Date()
        }
    }
    
    func goToPreviousDay() {
        selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    func goToNextDay() {
        selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }
    
    // MARK: - Helpers
    var dateTitle: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }
    
    var previousDayTitle: String {
        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedDate) else { return "" }
        
        if calendar.isDateInToday(previousDay) {
            return "Today"
        } else if calendar.isDateInYesterday(previousDay) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(previousDay) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: previousDay)
        }
    }
    
    var nextDayTitle: String {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDate) else { return "" }
        
        if calendar.isDateInToday(nextDay) {
            return "Today"
        } else if calendar.isDateInYesterday(nextDay) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(nextDay) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: nextDay)
        }
    }
    
    var hasEvents: Bool {
        !events.isEmpty
    }
}

// MARK: - Event Layout Model
struct EventLayout {
    let event: Event
    let column: Int
    let totalColumns: Int
    let yPosition: CGFloat
    let height: CGFloat
    
    var widthMultiplier: CGFloat {
        1.0 / CGFloat(totalColumns)
    }
    
    var xOffset: CGFloat {
        CGFloat(column) * widthMultiplier
    }
}