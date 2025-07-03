import SwiftUI

struct ContentView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Day View with Timeline
            DayView()
                .tabItem {
                    Label("Day", systemImage: "calendar.day.timeline.left")
                }
                .tag(0)
            
            // AI Assistant
            AIChatView()
                .tabItem {
                    Label("Assistant", systemImage: "message.fill")
                }
                .tag(1)
            
            // Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .onChange(of: selectedTab) { _, newTab in
            let tabName: String
            switch newTab {
            case 0:
                tabName = "DayView"
            case 1:
                tabName = "AIChatView"
            case 2:
                tabName = "SettingsView"
            default:
                tabName = "Unknown"
            }
            CrashReporter.shared.logNavigation(to: tabName)
            CrashReporter.shared.addBreadcrumb(
                message: "Tab changed to \(tabName)",
                category: "navigation",
                level: .info,
                data: ["tab_index": newTab]
            )
        }
        .trackViewAppearance("ContentView", additionalData: ["initial_tab": selectedTab])
    }
}

#Preview {
    let container = DependencyContainer.shared
    return ContentView()
        .environment(\.managedObjectContext, container.persistenceProvider.container.viewContext)
        .environmentObject(container.scheduleManager as! ScheduleManager)
        .environmentObject(container.scrollPositionManager as! ScrollPositionManager)
        .injectDependencies(container)
}