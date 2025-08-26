import Foundation
import SwiftUI

/// Mock scroll position manager for testing
@MainActor
class MockScrollPositionManager: ObservableObject, ScrollPositionProviding {
    @Published private(set) var offsets: [Int: CGFloat] = [:]
    
    // Test helpers
    var updateCallCount = 0
    var offsetCallCount = 0
    var lastUpdatedDayOffset: Int?
    var lastUpdatedValue: CGFloat?
    
    init() {
        // Initialize with some default offsets for testing
        offsets = [
            -1: 340.0,  // Yesterday
            0: 612.0,   // Today (9 AM)
            1: 476.0    // Tomorrow
        ]
    }
    
    func offset(for dayOffset: Int, default y: CGFloat = 612) -> CGFloat {
        offsetCallCount += 1
        return offsets[dayOffset, default: y]
    }
    
    func update(dayOffset: Int, to newValue: CGFloat) {
        updateCallCount += 1
        lastUpdatedDayOffset = dayOffset
        lastUpdatedValue = newValue
        offsets[dayOffset] = max(newValue, 0)
    }
    
    // MARK: - Test Helpers
    
    /// Reset all mock state
    func reset() {
        offsets = [
            -1: 340.0,
            0: 612.0,
            1: 476.0
        ]
        updateCallCount = 0
        offsetCallCount = 0
        lastUpdatedDayOffset = nil
        lastUpdatedValue = nil
    }
    
    /// Set a specific offset for testing
    func setOffset(_ offset: CGFloat, for dayOffset: Int) {
        offsets[dayOffset] = offset
    }
    
    /// Clear all offsets
    func clearOffsets() {
        offsets.removeAll()
    }
}