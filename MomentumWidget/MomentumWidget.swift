import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), events: Event.placeholderEvents())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), events: Event.todayEvents())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of entries every 15 minutes
        let currentDate = Date()
        let events = Event.todayEvents()
        
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
        case .systemLarge:
            LargeWidgetView(entry: entry)
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
    
    var currentAndNextEvents: (current: Event?, next: Event?) {
        let now = entry.date
        let current = entry.events.first { event in
            guard let start = event.startTime, let end = event.endTime else { return false }
            return start <= now && end > now
        }
        let next = entry.events.first { event in
            guard let start = event.startTime else { return false }
            return start > now
        }
        return (current, next)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with current time
                HStack {
                    Text(entry.date, format: .dateTime.hour().minute())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Spacer()
                    Text(entry.date, format: .dateTime.weekday(.abbreviated))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Time blocks visualization
                VStack(spacing: 6) {
                    if let current = currentAndNextEvents.current {
                        CurrentEventBlock(event: current, now: entry.date)
                    }
                    
                    if let next = currentAndNextEvents.next {
                        NextEventBlock(event: next)
                    } else if currentAndNextEvents.current == nil {
                        NoEventsView()
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
            }
        }
        .containerBackground(Color(UIColor.systemBackground), for: .widget)
    }
}

struct CurrentEventBlock: View {
    let event: Event
    let now: Date
    
    var progress: Double {
        guard let start = event.startTime, let end = event.endTime else { return 0 }
        let total = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        return min(max(elapsed / total, 0), 1)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NOW")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            
            Text(event.title ?? "Untitled")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.2))
                        .frame(height: 3)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.8))
                        .frame(width: geometry.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)
            
            if let end = event.endTime {
                Text("Until \(end, style: .time)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: event.category?.colorHex ?? "#007AFF"))
        )
    }
}

struct NextEventBlock: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let start = event.startTime {
                Text(start, style: .time)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(event.title ?? "Untitled")
                .font(.system(size: 14, weight: .medium))
                .lineLimit(2)
            
            if let duration = event.duration {
                Text("\(Int(duration / 60)) min")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: event.category?.colorHex ?? "#007AFF"), lineWidth: 1.5)
        )
    }
}

struct NoEventsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundColor(.green)
            Text("All clear")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: Provider.Entry
    
    var todayEvents: [Event] {
        let calendar = Calendar.current
        return entry.events.filter { event in
            guard let startTime = event.startTime else { return false }
            return calendar.isDate(startTime, inSameDayAs: entry.date)
        }.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
    }
    
    var currentEvent: Event? {
        entry.events.first { event in
            guard let start = event.startTime, let end = event.endTime else { return false }
            return start <= entry.date && end > entry.date
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left side - Current time and status
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.date, format: .dateTime.hour().minute())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text(entry.date, format: .dateTime.weekday(.wide))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let current = currentEvent {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOW")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: current.category?.colorHex ?? "#007AFF"))
                            
                            Text(current.title ?? "Untitled")
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(2)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: current.category?.colorHex ?? "#007AFF").opacity(0.1))
                        )
                    }
                }
                .frame(width: geometry.size.width * 0.35)
                .padding()
                
                Divider()
                    .padding(.vertical, 8)
                
                // Right side - Timeline
                TimelineWidgetView(events: todayEvents, currentTime: entry.date)
                    .padding(.vertical, 12)
                    .padding(.trailing, 12)
            }
        }
        .containerBackground(Color(UIColor.systemBackground), for: .widget)
    }
}

struct TimelineWidgetView: View {
    let events: [Event]
    let currentTime: Date
    let hourHeight: CGFloat = 20
    
    var timeRange: (start: Int, end: Int) {
        let calendar = Calendar.current
        var startHour = 8
        var endHour = 20
        
        for event in events {
            if let eventStart = event.startTime {
                let hour = calendar.component(.hour, from: eventStart)
                startHour = min(startHour, hour)
            }
            if let eventEnd = event.endTime {
                let hour = calendar.component(.hour, from: eventEnd)
                endHour = max(endHour, hour + 1)
            }
        }
        
        // Add current hour to range
        let currentHour = calendar.component(.hour, from: currentTime)
        startHour = min(startHour, currentHour)
        endHour = max(endHour, currentHour + 1)
        
        return (max(6, startHour), min(23, endHour))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Time labels and grid
                ForEach(timeRange.start...timeRange.end, id: \.self) { hour in
                    HStack(spacing: 4) {
                        Text("\(hour)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .trailing)
                        
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 0.5)
                    }
                    .offset(y: CGFloat(hour - timeRange.start) * hourHeight)
                }
                
                // Events
                ForEach(events, id: \.id) { event in
                    if let start = event.startTime, let end = event.endTime {
                        EventBlockWidget(
                            event: event,
                            geometry: geometry,
                            timeRange: timeRange,
                            hourHeight: hourHeight,
                            currentTime: currentTime
                        )
                    }
                }
                
                // Current time indicator
                CurrentTimeLineWidget(
                    currentTime: currentTime,
                    timeRange: timeRange,
                    hourHeight: hourHeight,
                    width: geometry.size.width - 24
                )
            }
            .frame(height: CGFloat(timeRange.end - timeRange.start + 1) * hourHeight)
        }
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
                .fill(Color(hex: event.category?.colorHex ?? "#007AFF"))
                .frame(width: 3)
            
            Text(event.title ?? "")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isActive ? .white : .primary)
                .lineLimit(1)
                .padding(.horizontal, 4)
            
            Spacer()
        }
        .frame(height: max(position.height - 2, 14))
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? 
                    Color(hex: event.category?.colorHex ?? "#007AFF") :
                    Color(hex: event.category?.colorHex ?? "#007AFF").opacity(0.1)
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

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: Provider.Entry
    
    var todayEvents: [Event] {
        let calendar = Calendar.current
        return entry.events.filter { event in
            guard let startTime = event.startTime else { return false }
            return calendar.isDate(startTime, inSameDayAs: entry.date)
        }.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Planwise")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(entry.date, format: .dateTime.weekday(.wide).day().month())
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                Spacer()
                Image(systemName: "calendar")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            
            Divider()
            
            if todayEvents.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("No Events Today")
                        .font(.headline)
                    Text("Enjoy your free day!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(todayEvents, id: \.id) { event in
                            HStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: event.category?.colorHex ?? "#007AFF"))
                                    .frame(width: 4)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title ?? "Untitled")
                                        .font(.headline)
                                        .lineLimit(1)
                                    
                                    HStack {
                                        if let startTime = event.startTime,
                                           let endTime = event.endTime {
                                            Text("\(startTime, style: .time) - \(endTime, style: .time)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if let location = event.location {
                                            Text("• \(location)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                if event.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding()
        .containerBackground(Color(UIColor.systemBackground), for: .widget)
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
        }
        .configurationDisplayName("Planwise")
        .description("Keep track of your upcoming events.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Widget Bundle

struct MomentumWidgetBundle: WidgetBundle {
    var body: some Widget {
        MomentumWidget()
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

#Preview(as: .systemLarge) {
    MomentumWidget()
} timeline: {
    SimpleEntry(date: .now, events: Event.placeholderEvents())
}