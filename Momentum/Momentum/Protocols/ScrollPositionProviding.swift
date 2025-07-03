import Foundation
import SwiftUI

/// Protocol defining the interface for scroll position management
@MainActor
protocol ScrollPositionProviding: AnyObject {
    var offsets: [Int: CGFloat] { get }
    
    func offset(for dayOffset: Int, default y: CGFloat) -> CGFloat
    func update(dayOffset: Int, to newValue: CGFloat)
}