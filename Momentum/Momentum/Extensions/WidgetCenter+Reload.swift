import WidgetKit
import Foundation

extension ScheduleManager {
    /// Reload all widgets when events change
    func reloadWidgets() {
        #if !targetEnvironment(simulator)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}