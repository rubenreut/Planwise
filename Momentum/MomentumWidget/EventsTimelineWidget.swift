//
//  EventsTimelineWidget.swift
//  MomentumWidget
//
//  Timeline view of upcoming events
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Entry
struct EventsTimelineEntry: TimelineEntry {
    let date: Date
    let events: [EventItem]
    let currentEvent: EventItem?
    let nextEvent: EventItem?
    let configuration: ConfigurationAppIntent
}

struct EventItem: Identifiable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let categoryName: String?
    let categoryColor: String
    let location: String?
    let isAllDay: Bool
    let isNow: Bool
}

// MARK: - Events Timeline Widget
struct EventsTimelineWidget: Widget {
    let kind: String = "EventsTimelineWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: EventsTimelineProvider()) { entry in
            EventsTimelineWidgetView(entry: entry)
                .containerBackground(Color(UIColor.systemBackground), for: .widget)
        }
        .configurationDisplayName("Events Timeline")
        .description("View your schedule at a glance")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Timeline Provider
struct EventsTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> EventsTimelineEntry {
        EventsTimelineEntry(
            date: Date(),
            events: sampleEvents,
            currentEvent: nil,
            nextEvent: sampleEvents.first,
            configuration: ConfigurationAppIntent()
        )
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> EventsTimelineEntry {
        let events = await fetchEvents()
        let (current, next) = findCurrentAndNextEvents(from: events)
        return EventsTimelineEntry(
            date: Date(),
            events: events,
            currentEvent: current,
            nextEvent: next,
            configuration: configuration
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<EventsTimelineEntry> {
        let events = await fetchEvents()
        var entries: [EventsTimelineEntry] = []
        let now = Date()
        
        // Create entries for the next 4 hours, updating every 15 minutes
        for minuteOffset in stride(from: 0, to: 240, by: 15) {
            guard let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now) else { continue }
            let (current, next) = findCurrentAndNextEvents(from: events, at: entryDate)
            
            entries.append(EventsTimelineEntry(
                date: entryDate,
                events: events,
                currentEvent: current,
                nextEvent: next,
                configuration: configuration
            ))
        }
        
        return Timeline(entries: entries, policy: .atEnd)
    }
    
    private func fetchEvents() async -> [EventItem] {
        let context = WidgetPersistenceController.shared.container.viewContext
        let request = Event.fetchRequest()
        
        let calendar = Calendar.current
        let now = Date()
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
        
        request.predicate = NSPredicate(format: "(startTime >= %@ AND startTime <= %@) OR (endTime >= %@ AND endTime <= %@)",
                                       now as NSDate, endOfDay as NSDate, now as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Event.startTime, ascending: true)]
        
        do {
            let events = try context.fetch(request)
            return events.map { event in
                let isAllDay = event.notes?.contains("[ALL_DAY]") ?? false
                let isNow = !isAllDay && (event.startTime ?? Date()) <= now && (event.endTime ?? Date()) > now
                
                return EventItem(
                    id: event.objectID.uriRepresentation().absoluteString,
                    title: event.title ?? "Untitled",
                    startTime: event.startTime ?? Date(),
                    endTime: event.endTime ?? Date(),
                    categoryName: event.category?.name,
                    categoryColor: event.category?.colorHex ?? "#007AFF",
                    location: event.location,
                    isAllDay: isAllDay,
                    isNow: isNow
                )
            }
        } catch {
            return []
        }
    }
    
    private func findCurrentAndNextEvents(from events: [EventItem], at date: Date = Date()) -> (current: EventItem?, next: EventItem?) {
        let sortedEvents = events.filter { !$0.isAllDay }.sorted { $0.startTime < $1.startTime }
        
        let current = sortedEvents.first { event in
            event.startTime <= date && event.endTime > date
        }
        
        let next = sortedEvents.first { event in
            event.startTime > date
        }
        
        return (current, next)
    }
    
    private var sampleEvents: [EventItem] {
        let now = Date()
        return [
            EventItem(
                id: "1",
                title: "Team Standup",
                startTime: Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now,
                endTime: Calendar.current.date(byAdding: .minute, value: 90, to: now) ?? now,
                categoryName: "Work",
                categoryColor: "#007AFF",
                location: "Zoom",
                isAllDay: false,
                isNow: false
            ),
            EventItem(
                id: "2",
                title: "Lunch with Sarah",
                startTime: Calendar.current.date(byAdding: .hour, value: 3, to: now) ?? now,
                endTime: Calendar.current.date(byAdding: .hour, value: 4, to: now) ?? now,
                categoryName: "Personal",
                categoryColor: "#FF9500",
                location: "Cafe Blue",
                isAllDay: false,
                isNow: false
            )
        ]
    }
}

// MARK: - Widget Views
struct EventsTimelineWidgetView: View {
    let entry: EventsTimelineEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallEventsView(currentEvent: entry.currentEvent, nextEvent: entry.nextEvent)
        case .systemMedium:
            MediumEventsView(events: entry.events)
        case .systemLarge:
            LargeEventsView(events: entry.events)
        case .accessoryRectangular:
            RectangularEventsView(currentEvent: entry.currentEvent, nextEvent: entry.nextEvent)
        case .accessoryInline:
            InlineEventsView(currentEvent: entry.currentEvent, nextEvent: entry.nextEvent)
        default:
            EmptyView()
        }
    }
}

struct SmallEventsView: View {
    let currentEvent: EventItem?
    let nextEvent: EventItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "calendar")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text("Schedule")
                    .font(.headline)
                Spacer()
            }
            
            if let current = currentEvent {
                // Current event
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOW")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    
                    Text(current.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("Until \(timeString(current.endTime))")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color.fromHex( current.categoryColor).opacity(0.15))
                .cornerRadius(8)
            } else if let next = nextEvent {
                // Next event
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text(next.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(timeString(next.startTime))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            } else {
                Spacer()
                Text("No events today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
            
            Spacer()
            
            Link(destination: .addEvent) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                    Text("Add Event")
                        .font(.caption)
                }
                .foregroundColor(.orange)
            }
        }
        .padding()
    }
}

struct MediumEventsView: View {
    let events: [EventItem]
    
    var body: some View {
        HStack(spacing: 16) {
            // Current time
            VStack(alignment: .leading, spacing: 8) {
                Text(timeString(Date(), style: .short))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(dateString(Date()))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Link(destination: .schedule) {
                    Text("View All")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Divider()
            
            // Timeline
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(events.prefix(4)) { event in
                        MiniEventRow(event: event)
                    }
                }
            }
        }
        .padding()
    }
}

struct LargeEventsView: View {
    let events: [EventItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Schedule")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(dateString(Date(), style: .full))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Link(destination: .addEvent) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }
            
            // Timeline
            if events.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No events scheduled")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(events) { event in
                            EventRowWidget(event: event)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct RectangularEventsView: View {
    let currentEvent: EventItem?
    let nextEvent: EventItem?
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundColor(.orange)
            
            if let current = currentEvent {
                Text("Now: \(current.title)")
                    .font(.caption)
                    .lineLimit(1)
            } else if let next = nextEvent {
                Text("\(timeString(next.startTime)): \(next.title)")
                    .font(.caption)
                    .lineLimit(1)
            } else {
                Text("No events today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct InlineEventsView: View {
    let currentEvent: EventItem?
    let nextEvent: EventItem?
    
    var body: some View {
        if let current = currentEvent {
            Text("📅 Now: \(current.title)")
        } else if let next = nextEvent {
            Text("📅 Next: \(next.title) at \(timeString(next.startTime))")
        } else {
            Text("📅 No events today")
        }
    }
}

// MARK: - Event Components
struct MiniEventRow: View {
    let event: EventItem
    
    var body: some View {
        HStack(spacing: 8) {
            // Time
            Text(timeString(event.startTime))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
            
            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.fromHex( event.categoryColor))
                .frame(width: 3)
            
            // Event info
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let location = event.location {
                    HStack(spacing: 2) {
                        Image(systemName: "location")
                            .font(.caption2)
                        Text(location)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

struct EventRowWidget: View {
    let event: EventItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Time column
            VStack(spacing: 2) {
                Text(timeString(event.startTime))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(durationString(from: event.startTime, to: event.endTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50, alignment: .center)
            
            // Color bar
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.fromHex( event.categoryColor))
                .frame(width: 4)
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    if let category = event.categoryName {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.fromHex( event.categoryColor))
                                .frame(width: 8, height: 8)
                            Text(category)
                                .font(.caption)
                        }
                    }
                    
                    if let location = event.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption2)
                            Text(location)
                                .font(.caption)
                        }
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if event.isNow {
                Text("NOW")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Helper Functions
private func timeString(_ date: Date, style: DateFormatter.Style = .short) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = style
    formatter.dateStyle = .none
    return formatter.string(from: date)
}

private func dateString(_ date: Date, style: DateFormatter.Style = .medium) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = style
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

private func durationString(from start: Date, to end: Date) -> String {
    let duration = end.timeIntervalSince(start)
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60
    
    if hours > 0 && minutes > 0 {
        return "\(hours)h \(minutes)m"
    } else if hours > 0 {
        return "\(hours)h"
    } else {
        return "\(minutes)m"
    }
}