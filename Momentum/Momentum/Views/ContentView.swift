import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        UnifiedNavigationView()
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