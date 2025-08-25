//
//  QuickActionsWidget.swift
//  MomentumWidget
//
//  Quick add actions for tasks, events, and habits
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Entry
struct QuickActionsEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

// MARK: - Quick Actions Widget
struct QuickActionsWidget: Widget {
    let kind: String = "QuickActionsWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: QuickActionsProvider()) { entry in
            QuickActionsWidgetView(entry: entry)
                .containerBackground(Color(UIColor.systemBackground), for: .widget)
        }
        .configurationDisplayName("Quick Actions")
        .description("Quickly add tasks, events, and habits")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

// MARK: - Timeline Provider
struct QuickActionsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry {
        QuickActionsEntry(date: Date(), configuration: ConfigurationAppIntent())
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> QuickActionsEntry {
        QuickActionsEntry(date: Date(), configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<QuickActionsEntry> {
        let entry = QuickActionsEntry(date: Date(), configuration: configuration)
        // Static widget, update once per day
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - Widget Views
struct QuickActionsWidgetView: View {
    let entry: QuickActionsEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallQuickActionsView()
        case .systemMedium:
            MediumQuickActionsView()
        case .accessoryCircular:
            CircularQuickActionsView()
        default:
            EmptyView()
        }
    }
}

struct SmallQuickActionsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Quick Add")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                QuickActionButton(
                    icon: "checklist",
                    label: "Task",
                    color: .blue,
                    url: "momentum://add-task"
                )
                
                QuickActionButton(
                    icon: "calendar.badge.plus",
                    label: "Event",
                    color: .orange,
                    url: "momentum://add-event"
                )
                
                QuickActionButton(
                    icon: "star.fill",
                    label: "Habit",
                    color: .purple,
                    url: "momentum://add-habit"
                )
            }
        }
        .padding()
    }
}

struct MediumQuickActionsView: View {
    var body: some View {
        HStack(spacing: 16) {
            // Quick capture
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Capture")
                    .font(.headline)
                
                Button(intent: QuickCaptureIntent()) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Voice Note")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Tap to record")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            
            Divider()
            
            // Action grid
            VStack(spacing: 8) {
                Text("Quick Add")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    QuickActionCard(
                        icon: "checklist",
                        label: "Task",
                        color: .blue,
                        url: "momentum://add-task"
                    )
                    
                    QuickActionCard(
                        icon: "calendar.badge.plus",
                        label: "Event",
                        color: .orange,
                        url: "momentum://add-event"
                    )
                }
                
                HStack(spacing: 8) {
                    QuickActionCard(
                        icon: "star.fill",
                        label: "Habit",
                        color: .purple,
                        url: "momentum://add-habit"
                    )
                    
                    QuickActionCard(
                        icon: "note.text.badge.plus",
                        label: "Note",
                        color: .green,
                        url: "momentum://add-note"
                    )
                }
            }
        }
        .padding()
    }
}

struct CircularQuickActionsView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            Link(destination: URL(string: "momentum://quick-add")!) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Components
struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(color)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let label: String
    let color: Color
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}

// MARK: - App Intents
struct QuickCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Capture"
    static var description = IntentDescription("Capture a quick voice note or text")
    
    func perform() async throws -> some IntentResult & OpensIntent {
        // This will open the app with quick capture mode
        return .result(opensIntent: OpenURLIntent(url: URL(string: "momentum://quick-capture")!))
    }
}

struct OpenURLIntent: AppIntent {
    static var title: LocalizedStringResource = "Open URL"
    static var openAppWhenRun: Bool = true
    
    var url: URL = URL(string: "momentum://")!
    
    init() {}
    
    init(url: URL) {
        self.url = url
    }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}