//
//  CommonButtonStyles.swift
//  Momentum
//
//  Shared button styles used across the app
//

import SwiftUI

// MARK: - Scale Button Style (Deprecated - Use ButtonSystem.swift)

@available(*, deprecated, message: "Use the new button styles from ButtonSystem.swift")
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Convenience Type Aliases

typealias PrimaryButton = MomentumButton
typealias SecondaryButton = MomentumButton

// MARK: - Button Style Extensions

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(size: ButtonSize) -> PrimaryButtonStyle { PrimaryButtonStyle(size: size) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static func secondary(size: ButtonSize) -> SecondaryButtonStyle { SecondaryButtonStyle(size: size) }
}

extension ButtonStyle where Self == TertiaryButtonStyle {
    static var tertiary: TertiaryButtonStyle { TertiaryButtonStyle() }
    static func tertiary(size: ButtonSize) -> TertiaryButtonStyle { TertiaryButtonStyle(size: size) }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    static var destructive: DestructiveButtonStyle { DestructiveButtonStyle() }
    static func destructive(size: ButtonSize) -> DestructiveButtonStyle { DestructiveButtonStyle(size: size) }
}

extension ButtonStyle where Self == GhostButtonStyle {
    static var ghost: GhostButtonStyle { GhostButtonStyle() }
    static func ghost(size: ButtonSize) -> GhostButtonStyle { GhostButtonStyle(size: size) }
}