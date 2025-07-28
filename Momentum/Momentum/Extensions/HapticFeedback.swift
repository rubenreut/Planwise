//
//  HapticFeedback.swift
//  Momentum
//
//  Haptic feedback utilities for better user experience
//

import SwiftUI
import UIKit

enum HapticFeedback {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
    
    func trigger() {
        #if !targetEnvironment(macCatalyst) && !os(macOS)
        switch self {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
        #endif
    }
}

extension View {
    func hapticFeedback(_ type: HapticFeedback = .light) -> some View {
        self.onTapGesture {
            type.trigger()
        }
    }
    
    func hapticFeedbackOnChange<V: Equatable>(of value: V, type: HapticFeedback = .selection) -> some View {
        self.onChange(of: value) { _, _ in
            type.trigger()
        }
    }
}