import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), events: Event.placeholderEvents())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), events: Event.widgetTodayEvents())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of entries every 15 minutes
        let currentDate = Date()
        let events = Event.widgetTodayEvents()
        
        // Create entries for the next 2 hours, every 15 minutes
        for minuteOffset in stride(from: 0, to: 120, by: 15) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, events: events)
            entries.append(entry)
        }

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct SimpleEntry: TimelineEntry {
    let date: Date
    let events: [Event]
}

// MARK: - Widget Views

struct MomentumWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        case .accessoryInline:
            InlineWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: Provider.Entry
    
    var currentEvent: Event? {
        let now = entry.date
        return entry.events.first { event in
            guard let start = event.startTime, let end = event.endTime else { return false }
            return start <= now && end > now
        }
    }
    
    var nextEvent: Event? {
        let now = entry.date
        return entry.events.first { event in
            guard let start = event.startTime else { return false }
            return start > now
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Compact header
            HStack {
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
                Text(entry.date, format: .dateTime.weekday(.abbreviated).day())
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            
            // Current event
            if let current = currentEvent {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.categoryColor(for: current.category?.colorHex))
                        .frame(width: 4)
                        .cornerRadius(2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.categoryColor(for: current.category?.colorHex))
                        
                        Text(current.title ?? "Event")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if let end = current.endTime {
                            let remaining = end.timeIntervalSince(entry.date)
                            let minutes = Int(remaining / 60)
                            Text("\(minutes)m")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 10)
                    
                    Spacer(minLength: 2)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            
            // Next event - ultra compact
            if let next = nextEvent {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NEXT")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        if let start = next.startTime {
                            Text(start, style: .time)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Text(next.title ?? "Event")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 12)
            } else if currentEvent == nil {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.green)
                    Text("No events")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            
            Spacer()
        }
    }
}




// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: Provider.Entry
    
    var currentEvent: Event? {
        entry.events.first { event in
            guard let start = event.startTime, let end = event.endTime else { return false }
            return start <= entry.date && end > entry.date
        }
    }
    
    var upcomingEvents: [Event] {
        let calendar = Calendar.current
        return entry.events.filter { event in
            guard let startTime = event.startTime else { return false }
            return calendar.isDate(startTime, inSameDayAs: entry.date) && startTime > entry.date
        }.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }.prefix(3).map { $0 }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Time and current event
            VStack(alignment: .leading, spacing: 0) {
                // Time
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(entry.date, format: .dateTime.weekday(.wide))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 16)
                
                // Current event
                if let current = currentEvent {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.categoryColor(for: current.category?.colorHex))
                            .frame(width: 3)
                            .cornerRadius(1.5)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NOW")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.categoryColor(for: current.category?.colorHex))
                            Text(current.title ?? "Event")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.leading, 8)
                    }
                } else {
                    Text("No current event")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .frame(minWidth: 120, maxWidth: 140)
            
            // Right: Upcoming events
            if upcomingEvents.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.green.opacity(0.8))
                    Text("All done for today")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(upcomingEvents, id: \.id) { event in
                        HStack(alignment: .top, spacing: 10) {
                            // Time
                            if let start = event.startTime {
                                Text(start, style: .time)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .frame(width: 40)
                            }
                            
                            // Divider with color
                            Rectangle()
                                .fill(Color.categoryColor(for: event.category?.colorHex))
                                .frame(width: 2)
                                .frame(minHeight: 20)
                            
                            // Title
                            Text(event.title ?? "Event")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                            
                            Spacer()
                        }
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
    }
}


struct EventBlockWidget: View {
    let event: Event
    let geometry: GeometryProxy
    let timeRange: (start: Int, end: Int)
    let hourHeight: CGFloat
    let currentTime: Date
    
    var position: (y: CGFloat, height: CGFloat) {
        guard let start = event.startTime, let end = event.endTime else {
            return (0, hourHeight)
        }
        
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: start)
        let startMinute = calendar.component(.minute, from: start)
        let endHour = calendar.component(.hour, from: end)
        let endMinute = calendar.component(.minute, from: end)
        
        let startOffset = CGFloat(startHour - timeRange.start) * hourHeight + (CGFloat(startMinute) / 60.0) * hourHeight
        let endOffset = CGFloat(endHour - timeRange.start) * hourHeight + (CGFloat(endMinute) / 60.0) * hourHeight
        
        return (startOffset, endOffset - startOffset)
    }
    
    var isActive: Bool {
        guard let start = event.startTime, let end = event.endTime else { return false }
        return start <= currentTime && end > currentTime
    }
    
    var body: some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.fromHex( event.category?.colorHex ?? "#007AFF"))
                .frame(width: 3)
            
            Text(event.title ?? "")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isActive ? .white : .label)
                .lineLimit(1)
                .padding(.horizontal, 4)
            
            Spacer()
        }
        .frame(height: max(position.height - 2, 14))
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? 
                    Color.categoryColor(for: event.category?.colorHex) :
                    Color.categoryColor(for: event.category?.colorHex).opacity(0.1)
                )
        )
        .offset(x: 24, y: position.y + 1)
        .frame(width: geometry.size.width - 24)
    }
}

struct CurrentTimeLineWidget: View {
    let currentTime: Date
    let timeRange: (start: Int, end: Int)
    let hourHeight: CGFloat
    let width: CGFloat
    
    var offset: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        
        let hourOffset = CGFloat(hour - timeRange.start) * hourHeight
        let minuteOffset = (CGFloat(minute) / 60.0) * hourHeight
        
        return hourOffset + minuteOffset
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
            
            Rectangle()
                .fill(Color.red)
                .frame(height: 1)
        }
        .offset(x: 21, y: offset)
        .frame(width: width)
    }
}

// MARK: - Lock Screen Widgets

struct CircularWidgetView: View {
    let entry: Provider.Entry
    
    var eventsCount: Int {
        let calendar = Calendar.current
        return entry.events.filter { event in
            guard let startTime = event.startTime else { return false }
            return calendar.isDate(startTime, inSameDayAs: entry.date) && startTime > entry.date
        }.count
    }
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack {
                Image(systemName: "calendar")
                    .font(.title2)
                Text("\(eventsCount)")
                    .font(.headline)
            }
        }
    }
}

struct RectangularWidgetView: View {
    let entry: Provider.Entry
    
    var nextEvent: Event? {
        entry.events.first { event in
            guard let startTime = event.startTime else { return false }
            return startTime > entry.date
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "calendar")
                Text("Next Event")
                    .font(.headline)
            }
            
            if let event = nextEvent {
                Text(event.title ?? "Untitled")
                    .font(.caption)
                    .lineLimit(1)
                if let startTime = event.startTime {
                    Text(startTime, style: .time)
                        .font(.caption2)
                }
            } else {
                Text("No upcoming events")
                    .font(.caption)
            }
        }
    }
}

struct InlineWidgetView: View {
    let entry: Provider.Entry
    
    var nextEvent: Event? {
        entry.events.first { event in
            guard let startTime = event.startTime else { return false }
            return startTime > entry.date
        }
    }
    
    var body: some View {
        if let event = nextEvent, let startTime = event.startTime {
            Text("\(event.title ?? "Event") at \(startTime, style: .time)")
        } else {
            Text("No upcoming events")
        }
    }
}

// MARK: - Widget Configuration

struct MomentumWidget: Widget {
    let kind: String = "MomentumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MomentumWidgetEntryView(entry: entry)
                .containerBackground(Color(UIColor.systemBackground), for: .widget)
        }
        .configurationDisplayName("Today Overview")
        .description("See your day at a glance with events and tasks.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    MomentumWidget()
} timeline: {
    SimpleEntry(date: .now, events: Event.placeholderEvents())
}

#Preview(as: .systemMedium) {
    MomentumWidget()
} timeline: {
    SimpleEntry(date: .now, events: Event.placeholderEvents())
}

// MARK: - Helper Views