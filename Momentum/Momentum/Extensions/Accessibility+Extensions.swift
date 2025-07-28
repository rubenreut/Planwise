//
//  Accessibility+Extensions.swift
//  Momentum
//
//  Accessibility improvements for better user experience
//

import SwiftUI

// MARK: - Accessibility Extensions

extension View {
    /// Add comprehensive accessibility labels and hints
    func accessibilityElement(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }
    
    /// Mark view as decorative (not important for VoiceOver)
    func accessibilityDecorative() -> some View {
        self.accessibilityHidden(true)
    }
    
    /// Group elements for better navigation
    func accessibilityGroup(_ label: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
    }
    
    /// Add action description for interactive elements
    func accessibilityAction(_ label: String, action: @escaping () -> Void) -> some View {
        self.accessibilityAction(named: Text(label), action)
    }
    
    /// Support Dynamic Type with minimum and maximum scale
    func dynamicTypeAccessible(
        minimumScaleFactor: Double = 0.5,
        lineLimit: Int? = nil
    ) -> some View {
        self
            .minimumScaleFactor(minimumScaleFactor)
            .lineLimit(lineLimit)
    }
}

// MARK: - Semantic Colors for Better Contrast

extension Color {
    /// High contrast variants for accessibility
    static var accessiblePrimary: Color {
        Color(UIColor { traitCollection in
            traitCollection.accessibilityContrast == .high
                ? UIColor.label
                : UIColor.label.withAlphaComponent(0.9)
        })
    }
    
    static var accessibleSecondary: Color {
        Color(UIColor { traitCollection in
            traitCollection.accessibilityContrast == .high
                ? UIColor.secondaryLabel
                : UIColor.secondaryLabel.withAlphaComponent(0.8)
        })
    }
    
    static var accessibleAccent: Color {
        Color(UIColor { traitCollection in
            traitCollection.accessibilityContrast == .high
                ? UIColor.systemBlue
                : UIColor.systemBlue.withAlphaComponent(0.9)
        })
    }
}

// MARK: - Accessibility Announcements

struct AccessibilityAnnouncement {
    static func announce(_ message: String, priority: Bool = true) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(
                notification: .announcement,
                argument: NSAttributedString(
                    string: message,
                    attributes: [.accessibilitySpeechQueueAnnouncement: priority]
                )
            )
        }
    }
    
    static func announceScreenChange(_ message: String) {
        UIAccessibility.post(notification: .screenChanged, argument: message)
    }
    
    static func announceLayoutChange(_ message: String) {
        UIAccessibility.post(notification: .layoutChanged, argument: message)
    }
}

// MARK: - Accessible Custom Controls

struct AccessibleButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var role: ButtonRole? = nil
    
    @Environment(\.accessibilityShowButtonShapes) private var showButtonShapes
    
    var body: some View {
        Button(action: {
            HapticFeedback.light.trigger()
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .accessibilityHidden(true)
                }
                Text(title)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(role == .destructive ? Color.red.opacity(0.1) : Color.accentColor.opacity(0.1))
                    .overlay(
                        showButtonShapes ?
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(role == .destructive ? Color.red : Color.accentColor, lineWidth: 1)
                        : nil
                    )
            )
            .foregroundColor(role == .destructive ? .red : .accentColor)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(
            label: title,
            traits: role == .destructive ? [.isButton, .startsMediaSession] : .isButton
        )
    }
}

// MARK: - Focus Management

struct AccessibilityFocus: ViewModifier {
    @AccessibilityFocusState var isFocused: Bool
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .accessibilityFocused($isFocused)
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    isFocused = true
                }
            }
    }
}

extension View {
    func accessibilityFocus(when trigger: Bool) -> some View {
        modifier(AccessibilityFocus(trigger: trigger))
    }
}

// MARK: - Readable Content Guide

struct ReadableContentModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .regular ? 700 : .infinity)
            .padding(.horizontal, horizontalSizeClass == .regular ? 20 : 16)
    }
}

extension View {
    func readableContentWidth() -> some View {
        modifier(ReadableContentModifier())
    }
}

// MARK: - Voice Control Support

extension View {
    /// Add voice control commands
    func voiceControlCommand(_ command: String, action: @escaping () -> Void) -> some View {
        self.onTapGesture {
            action()
        }
        .accessibilityInputLabels([command])
    }
}

// MARK: - Reduce Motion Support

struct ReducedMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let reducedAnimation: Animation
    
    func body(content: Content) -> some View {
        content.animation(
            reduceMotion ? reducedAnimation : animation,
            value: UUID()
        )
    }
}

extension View {
    func adaptiveAnimation(
        _ animation: Animation = .spring(),
        reduced: Animation = .easeInOut(duration: 0.2)
    ) -> some View {
        modifier(ReducedMotionModifier(
            animation: animation,
            reducedAnimation: reduced
        ))
    }
}

// MARK: - Large Content Viewer Support

extension View {
    func largeContentViewer(title: String, image: String? = nil) -> some View {
        self
            .accessibilityShowsLargeContentViewer {
                VStack {
                    if let image = image {
                        Image(systemName: image)
                            .font(.largeTitle)
                    }
                    Text(title)
                        .font(.title)
                }
            }
    }
}