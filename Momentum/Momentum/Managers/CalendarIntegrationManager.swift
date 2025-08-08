//
//  CalendarIntegrationManager.swift
//  Momentum
//
//  Manages calendar integrations including iCloud, Google Calendar, and other calendar services
//

import Foundation
import EventKit
import EventKitUI
import SwiftUI
import Combine
import CoreData

// MARK: - Calendar Types
enum CalendarType: String, CaseIterable {
    case iCloud = "iCloud"
    case google = "Google Calendar"
    case outlook = "Outlook"
    case exchange = "Exchange"
    case local = "Local"
    
    var icon: String {
        switch self {
        case .iCloud: return "icloud"
        case .google: return "g.circle.fill"
        case .outlook: return "envelope.fill"
        case .exchange: return "arrow.triangle.2.circlepath"
        case .local: return "calendar"
        }
    }
    
    var color: Color {
        switch self {
        case .iCloud: return .blue
        case .google: return .red
        case .outlook: return .blue
        case .exchange: return .orange
        case .local: return .gray
        }
    }
}

// MARK: - Integrated Calendar Model
struct IntegratedCalendar: Identifiable {
    let id = UUID()
    let calendarIdentifier: String
    let title: String
    let type: CalendarType
    let color: Color
    let isEnabled: Bool
    let sourceIdentifier: String?
    
    // For EventKit calendars
    let ekCalendar: EKCalendar?
    
    init(ekCalendar: EKCalendar) {
        self.ekCalendar = ekCalendar
        self.calendarIdentifier = ekCalendar.calendarIdentifier
        self.title = ekCalendar.title
        self.color = Color(ekCalendar.cgColor ?? UIColor.systemBlue.cgColor)
        self.isEnabled = !ekCalendar.isImmutable
        self.sourceIdentifier = ekCalendar.source.sourceIdentifier
        
        // Determine type based on source
        switch ekCalendar.source.sourceType {
        case .local:
            self.type = .local
        case .exchange:
            self.type = .exchange
        case .calDAV:
            if ekCalendar.source.title.lowercased().contains("google") {
                self.type = .google
            } else if ekCalendar.source.title.lowercased().contains("icloud") {
                self.type = .iCloud
            } else {
                self.type = .local
            }
        default:
            self.type = .local
        }
    }
}

// MARK: - Calendar Event Model
struct CalendarEvent: Identifiable {
    let id = UUID()
    let eventIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let calendarIdentifier: String
    let color: Color
    
    init(ekEvent: EKEvent) {
        self.eventIdentifier = ekEvent.eventIdentifier
        self.title = ekEvent.title ?? "Untitled Event"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.location = ekEvent.location
        self.notes = ekEvent.notes
        self.calendarIdentifier = ekEvent.calendar.calendarIdentifier
        self.color = Color(ekEvent.calendar.cgColor ?? UIColor.systemBlue.cgColor)
    }
}

// MARK: - Calendar Integration Manager
@MainActor
class CalendarIntegrationManager: NSObject, ObservableObject {
    static let shared = CalendarIntegrationManager()
    
    @Published var integratedCalendars: [IntegratedCalendar] = []
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCalendarIds: Set<String> = []
    @Published var syncedEvents: [CalendarEvent] = []
    
    private let eventStore = EKEventStore()
    private var cancellables = Set<AnyCancellable>()
    
    // User defaults keys
    private let selectedCalendarsKey = "selectedCalendarIdentifiers"
    private let lastSyncDateKey = "lastCalendarSyncDate"
    
    override init() {
        super.init()
        loadSelectedCalendars()
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func requestCalendarAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    self.authorizationStatus = granted ? .fullAccess : .denied
                }
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                await MainActor.run {
                    self.authorizationStatus = granted ? .authorized : .denied
                }
                return granted
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to request calendar access: \(error.localizedDescription)"
                self.authorizationStatus = .denied
            }
            return false
        }
    }
    
    // MARK: - Calendar Management
    
    func loadCalendars() async {
        // Check authorization status
        let isAuthorized: Bool
        if #available(iOS 17.0, *) {
            isAuthorized = authorizationStatus == .fullAccess
        } else {
            isAuthorized = authorizationStatus == .authorized
        }
        
        if !isAuthorized {
            let granted = await requestCalendarAccess()
            if !granted { return }
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Load calendars
        let calendars = eventStore.calendars(for: .event)
        let integrated = calendars.map { IntegratedCalendar(ekCalendar: $0) }
        
        await MainActor.run {
            self.integratedCalendars = integrated
            self.isLoading = false
        }
    }
    
    func toggleCalendarSelection(_ calendar: IntegratedCalendar) {
        if selectedCalendarIds.contains(calendar.calendarIdentifier) {
            selectedCalendarIds.remove(calendar.calendarIdentifier)
        } else {
            selectedCalendarIds.insert(calendar.calendarIdentifier)
        }
        saveSelectedCalendars()
    }
    
    private func loadSelectedCalendars() {
        if let saved = UserDefaults.standard.array(forKey: selectedCalendarsKey) as? [String] {
            selectedCalendarIds = Set(saved)
        }
    }
    
    private func saveSelectedCalendars() {
        UserDefaults.standard.set(Array(selectedCalendarIds), forKey: selectedCalendarsKey)
    }
    
    // MARK: - Event Syncing
    
    func syncEvents(from startDate: Date, to endDate: Date) async {
        // Check authorization
        let isAuthorized: Bool
        if #available(iOS 17.0, *) {
            isAuthorized = authorizationStatus == .fullAccess
        } else {
            isAuthorized = authorizationStatus == .authorized
        }
        
        guard isAuthorized else { return }
        guard !selectedCalendarIds.isEmpty else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Get selected calendars
        let selectedCalendars = eventStore.calendars(for: .event).filter { calendar in
            selectedCalendarIds.contains(calendar.calendarIdentifier)
        }
        
        // Create predicate for events
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: selectedCalendars
        )
        
        // Fetch events
        let events = eventStore.events(matching: predicate)
        let calendarEvents = events.map { CalendarEvent(ekEvent: $0) }
        
        await MainActor.run {
            self.syncedEvents = calendarEvents
            self.isLoading = false
            UserDefaults.standard.set(Date(), forKey: lastSyncDateKey)
        }
        
        // Import events to Momentum
        await importEventsToMomentum(calendarEvents)
    }
    
    private func importEventsToMomentum(_ events: [CalendarEvent]) async {
        let scheduleManager = ScheduleManager.shared
        let viewContext = PersistenceController.shared.container.viewContext
        
        for calendarEvent in events {
            // Check if event already exists
            let fetchRequest = NSFetchRequest<Event>(entityName: "Event")
            fetchRequest.predicate = NSPredicate(
                format: "externalEventID == %@", 
                calendarEvent.eventIdentifier
            )
            
            do {
                let existingEvents = try viewContext.fetch(fetchRequest)
                
                if existingEvents.isEmpty {
                    // Create new event
                    let _ = scheduleManager.createEvent(
                        title: calendarEvent.title,
                        startTime: calendarEvent.startDate,
                        endTime: calendarEvent.endDate,
                        category: nil,
                        notes: calendarEvent.notes,
                        location: calendarEvent.location,
                        isAllDay: calendarEvent.isAllDay
                    )
                    
                    // Update with external ID
                    let eventsForDate = scheduleManager.events(for: calendarEvent.startDate)
                    if let newEvent = eventsForDate.first(where: { $0.title == calendarEvent.title && $0.externalEventID == nil }) {
                        newEvent.externalEventID = calendarEvent.eventIdentifier
                        try? viewContext.save()
                    }
                } else if let existingEvent = existingEvents.first {
                    // Update existing event
                    existingEvent.title = calendarEvent.title
                    existingEvent.startTime = calendarEvent.startDate
                    existingEvent.endTime = calendarEvent.endDate
                    existingEvent.location = calendarEvent.location
                    existingEvent.notes = calendarEvent.notes
                }
            } catch {
                print("Error syncing event \(calendarEvent.title): \(error)")
            }
        }
        
        // Save changes
        do {
            try viewContext.save()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save synced events: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Google Calendar Integration
    
    func setupGoogleCalendar() {
        // This would require OAuth setup with Google Calendar API
        // For now, we'll use CalDAV if the user has already added their Google account to iOS
        errorMessage = "Google Calendar can be accessed if you've added your Google account in Settings > Calendar > Accounts"
    }
    
    // MARK: - Export Events
    
    func exportEventToCalendar(_ event: Event, to calendar: IntegratedCalendar) async -> Bool {
        guard let ekCalendar = calendar.ekCalendar else { return false }
        
        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = event.title
        ekEvent.startDate = event.startTime
        ekEvent.endDate = event.endTime
        ekEvent.calendar = ekCalendar
        ekEvent.location = event.location
        ekEvent.notes = event.notes
        
        do {
            try eventStore.save(ekEvent, span: .thisEvent)
            
            // Save external identifier
            event.externalEventID = ekEvent.eventIdentifier
            try event.managedObjectContext?.save()
            
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to export event: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Auto Sync
    
    func setupAutoSync() {
        // Sync every hour
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                _Concurrency.Task {
                    let startDate = Date()
                    let endDate = Calendar.current.date(byAdding: .month, value: 3, to: startDate) ?? startDate
                    await self.syncEvents(from: startDate, to: endDate)
                }
            }
            .store(in: &cancellables)
    }
    
    var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date
    }
}

