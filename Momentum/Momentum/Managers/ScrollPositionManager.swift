import Foundation
import SwiftUI

@MainActor
final class ScrollPositionManager: ObservableObject, ScrollPositionProviding {
    static let shared = ScrollPositionManager()
    
    /// Per-day vertical offset (points). Key is the `dayOffset` used in DayView.
    @Published private(set) var offsets: [Int: CGFloat] = [:]
    
    private init() { }
    
    func offset(for dayOffset: Int, default y: CGFloat = 612) -> CGFloat {
        // 612 pt = 9 AM in your 68 pt-per-hour grid.
        offsets[dayOffset, default: y]
    }
    
    func update(dayOffset: Int, to newValue: CGFloat) {
        offsets[dayOffset] = max(newValue, 0)
    }
}