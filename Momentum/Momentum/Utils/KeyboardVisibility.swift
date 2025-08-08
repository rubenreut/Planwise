//
//  KeyboardVisibility.swift
//  Momentum
//
//  Environment key for keyboard visibility state
//

import SwiftUI

// MARK: - Keyboard Visibility State
class KeyboardVisibilityState: ObservableObject {
    @Published var isVisible = false
}

// MARK: - Environment Key
struct KeyboardVisibilityKey: EnvironmentKey {
    static let defaultValue = KeyboardVisibilityState()
}

extension EnvironmentValues {
    var keyboardVisibility: KeyboardVisibilityState {
        get { self[KeyboardVisibilityKey.self] }
        set { self[KeyboardVisibilityKey.self] = newValue }
    }
}