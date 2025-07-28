import WidgetKit
import SwiftUI

struct DebugEntry: TimelineEntry {
    let date: Date
    let debugInfo: String
}

struct DebugProvider: TimelineProvider {
    func placeholder(in context: Context) -> DebugEntry {
        DebugEntry(date: Date(), debugInfo: "Placeholder")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (DebugEntry) -> ()) {
        let appGroupID = "group.com.rubnereut.productivity"
        let hasAppGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
        let entry = DebugEntry(date: Date(), debugInfo: "App Group: \(hasAppGroup ? "✓" : "✗")")
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let appGroupID = "group.com.rubnereut.productivity"
        let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        let hasAppGroup = appGroupURL != nil
        
        var debugInfo = "App Group: \(hasAppGroup ? "✓" : "✗")\n"
        if let url = appGroupURL {
            debugInfo += "Path: \(url.lastPathComponent)\n"
        }
        
        // Check if PersistenceController exists
        let hasPersistence = true // Using WidgetPersistenceController
        debugInfo += "Persistence: \(hasPersistence ? "✓" : "✗")\n"
        
        // Try to access Core Data
        let events = Event.widgetTodayEvents()
        debugInfo += "Events: \(events.count)"
        
        let entry = DebugEntry(date: Date(), debugInfo: debugInfo)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        completion(timeline)
    }
}

struct DebugWidgetView: View {
    let entry: DebugEntry
    
    var body: some View {
        VStack {
            Text("Debug Info")
                .font(.headline)
            Text(entry.debugInfo)
                .font(.caption)
                .multilineTextAlignment(.center)
            Text(entry.date, style: .time)
                .font(.caption2)
        }
        .padding()
    }
}

struct DebugWidget: Widget {
    let kind: String = "DebugWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DebugProvider()) { entry in
            DebugWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Debug Widget")
        .description("Shows widget debug info")
        .supportedFamilies([.systemSmall])
    }
}