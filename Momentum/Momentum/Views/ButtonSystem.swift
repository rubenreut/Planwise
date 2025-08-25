//
//  ButtonSystem.swift
//  Momentum
//
//  Comprehensive button style system with various styles, sizes, and states
//

import SwiftUI

// MARK: - Button Size
enum ButtonSize {
    case small
    case medium
    case large
    
    var height: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 44
        case .large: return 56
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        }
    }
    
    var font: Font {
        switch self {
        case .small: return .system(size: 14, weight: .semibold, design: .default)
        case .medium: return .system(size: 17, weight: .semibold, design: .default)
        case .large: return .system(size: 20, weight: .semibold, design: .default)
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 20
        case .large: return 24
        }
    }
}

// MARK: - Button Style
enum MomentumButtonStyle {
    case primary
    case secondary
    case tertiary
    case destructive
    case ghost
}

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    let size: ButtonSize
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    init(size: ButtonSize = .medium) {
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundColor(.white)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .stroke(Color.white.opacity(isHovered ? 0.2 : 0), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return DesignSystem.Colors.gray3
        } else if isPressed {
            return DesignSystem.Colors.accent.opacity(0.8)
        } else {
            return DesignSystem.Colors.accent
        }
    }
}

// MARK: - Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    let size: ButtonSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    
    init(size: ButtonSize = .medium) {
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
            .contentShape(Rectangle())
    }
    
    private var foregroundColor: Color {
        if !isEnabled {
            return DesignSystem.Colors.tertiary
        } else {
            return DesignSystem.Colors.accent
        }
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return DesignSystem.Colors.quaternaryFill
        } else if isPressed {
            return DesignSystem.Colors.accent.opacity(0.15)
        } else if isHovered {
            return DesignSystem.Colors.accent.opacity(0.08)
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if !isEnabled {
            return DesignSystem.Colors.separator
        } else {
            return DesignSystem.Colors.accent.opacity(colorScheme == .dark ? 0.5 : 0.3)
        }
    }
}

// MARK: - Tertiary Button Style
struct TertiaryButtonStyle: ButtonStyle {
    let size: ButtonSize
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    init(size: ButtonSize = .medium) {
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
            .contentShape(Rectangle())
    }
    
    private var foregroundColor: Color {
        if !isEnabled {
            return DesignSystem.Colors.tertiary
        } else {
            return DesignSystem.Colors.accent
        }
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return DesignSystem.Colors.accent.opacity(0.15)
        } else if isHovered {
            return DesignSystem.Colors.accent.opacity(0.08)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Destructive Button Style
struct DestructiveButtonStyle: ButtonStyle {
    let size: ButtonSize
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    init(size: ButtonSize = .medium) {
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundColor(.white)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .stroke(Color.white.opacity(isHovered ? 0.2 : 0), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return DesignSystem.Colors.gray3
        } else if isPressed {
            return DesignSystem.Colors.error.opacity(0.8)
        } else {
            return DesignSystem.Colors.error
        }
    }
}

// MARK: - Ghost Button Style
struct GhostButtonStyle: ButtonStyle {
    let size: ButtonSize
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    init(size: ButtonSize = .medium) {
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
            .contentShape(Rectangle())
    }
    
    private var foregroundColor: Color {
        if !isEnabled {
            return DesignSystem.Colors.tertiary
        } else {
            return DesignSystem.Colors.primary
        }
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return DesignSystem.Colors.quaternaryFill
        } else if isHovered {
            return DesignSystem.Colors.tertiaryFill
        } else {
            return Color.clear
        }
    }
}

// MARK: - Icon Button Style
struct IconButtonStyle: ButtonStyle {
    let size: ButtonSize
    let style: MomentumButtonStyle
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    init(size: ButtonSize = .medium, style: MomentumButtonStyle = .secondary) {
        self.size = size
        self.style = style
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.iconSize))
            .foregroundColor(foregroundColor)
            .frame(width: size.height, height: size.height)
            .background(
                Circle()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: style == .secondary ? 1 : 0)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
            .contentShape(Circle())
    }
    
    private var foregroundColor: Color {
        if !isEnabled {
            return DesignSystem.Colors.tertiary
        }
        
        switch style {
        case .primary:
            return .white
        case .destructive:
            return .white
        case .secondary, .tertiary, .ghost:
            return DesignSystem.Colors.accent
        }
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return DesignSystem.Colors.quaternaryFill
        }
        
        switch style {
        case .primary:
            return isPressed ? DesignSystem.Colors.accent.opacity(0.8) : DesignSystem.Colors.accent
        case .secondary:
            if isPressed {
                return DesignSystem.Colors.accent.opacity(0.15)
            } else if isHovered {
                return DesignSystem.Colors.accent.opacity(0.08)
            } else {
                return Color.clear
            }
        case .tertiary, .ghost:
            if isPressed {
                return DesignSystem.Colors.quaternaryFill
            } else if isHovered {
                return DesignSystem.Colors.tertiaryFill
            } else {
                return Color.clear
            }
        case .destructive:
            return isPressed ? DesignSystem.Colors.error.opacity(0.8) : DesignSystem.Colors.error
        }
    }
    
    private var borderColor: Color {
        if !isEnabled {
            return DesignSystem.Colors.separator
        } else if style == .secondary {
            return DesignSystem.Colors.accent.opacity(0.3)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Floating Action Button Style
struct FloatingActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(size: 24, weight: .semibold)
            .scaledIcon()
            .foregroundColor(.white)
            .frame(width: 56, height: 56)
            .background(
                Circle()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .shadow(
                        color: DesignSystem.Elevation.high.color,
                        radius: DesignSystem.Elevation.high.radius,
                        x: DesignSystem.Elevation.high.x,
                        y: DesignSystem.Elevation.high.y
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(isHovered ? 0.2 : 0), lineWidth: 1)
            )
            .contentShape(Circle())
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return DesignSystem.Colors.gray3
        } else if isPressed {
            return DesignSystem.Colors.accent.opacity(0.8)
        } else {
            return DesignSystem.Colors.accent
        }
    }
}

// MARK: - Loading Button View
struct LoadingButton<Label: View>: View {
    let action: () -> Void
    let isLoading: Bool
    let style: MomentumButtonStyle
    let size: ButtonSize
    @ViewBuilder let label: () -> Label
    
    init(
        action: @escaping () -> Void,
        isLoading: Bool = false,
        style: MomentumButtonStyle = .primary,
        size: ButtonSize = .medium,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.isLoading = isLoading
        self.style = style
        self.size = size
        self.label = label
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                label()
                    .opacity(isLoading ? 0 : 1)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: progressTint))
                        .scaleEffect(progressScale)
                }
            }
        }
        .disabled(isLoading)
        .modifier(ButtonStyleModifier(style: style, size: size))
    }
    
    private var progressTint: Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary, .tertiary, .ghost:
            return DesignSystem.Colors.accent
        }
    }
    
    private var progressScale: CGFloat {
        switch size {
        case .small: return 0.7
        case .medium: return 0.8
        case .large: return 1.0
        }
    }
    
}

// MARK: - Button Style Modifier
struct ButtonStyleModifier: ViewModifier {
    let style: MomentumButtonStyle
    let size: ButtonSize
    
    func body(content: Content) -> some View {
        switch style {
        case .primary:
            content.buttonStyle(PrimaryButtonStyle(size: size))
        case .secondary:
            content.buttonStyle(SecondaryButtonStyle(size: size))
        case .tertiary:
            content.buttonStyle(TertiaryButtonStyle(size: size))
        case .destructive:
            content.buttonStyle(DestructiveButtonStyle(size: size))
        case .ghost:
            content.buttonStyle(GhostButtonStyle(size: size))
        }
    }
}

// MARK: - Button Modifiers
extension View {
    /// Apply haptic feedback to button tap
    func buttonHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
        }
    }
    
    /// Apply standard button accessibility
    func buttonAccessibility(_ label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Convenience Button Views
struct MomentumButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let style: MomentumButtonStyle
    let size: ButtonSize
    let isLoading: Bool
    
    init(
        _ title: String,
        icon: String? = nil,
        style: MomentumButtonStyle = .primary,
        size: ButtonSize = .medium,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        LoadingButton(action: action, isLoading: isLoading, style: style, size: size) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize))
                }
                Text(title)
            }
        }
        .buttonHaptic(.light)
    }
}

struct IconButton: View {
    let icon: String
    let action: () -> Void
    let style: MomentumButtonStyle
    let size: ButtonSize
    let accessibilityLabel: String
    
    init(
        icon: String,
        style: MomentumButtonStyle = .secondary,
        size: ButtonSize = .medium,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.size = size
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .buttonStyle(IconButtonStyle(size: size, style: style))
        .buttonHaptic(.light)
        .buttonAccessibility(accessibilityLabel)
    }
}

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    let accessibilityLabel: String
    @State private var isTabBarCollapsed = false
    
    init(
        icon: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                Button(action: action) {
                    Image(systemName: icon)
                }
                .buttonStyle(FloatingActionButtonStyle())
                .buttonHaptic(.medium)
                .buttonAccessibility(accessibilityLabel)
            }
            .padding(.trailing, 16)
            .padding(.bottom, isTabBarCollapsed ? -65 : 8) // Move down more when collapsed to match smaller navbar
        }
        .frame(maxHeight: isTabBarCollapsed ? 50 : .infinity) // Shrink container when collapsed
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTabBarCollapsed)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TabBarCollapseChanged"))) { notification in
            if let userInfo = notification.userInfo,
               let collapsed = userInfo["isCollapsed"] as? Bool {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isTabBarCollapsed = collapsed
                }
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ButtonSystemPreview: View {
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Primary Buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Primary Buttons")
                        .scaledFont(size: 17, weight: .semibold)
                    
                    MomentumButton("Get Started", style: .primary, size: .large) {
                        print("Primary large tapped")
                    }
                    
                    MomentumButton("Continue", icon: "arrow.right", style: .primary, size: .medium) {
                        print("Primary medium tapped")
                    }
                    
                    MomentumButton("Save", style: .primary, size: .small) {
                        print("Primary small tapped")
                    }
                    
                    MomentumButton("Loading...", style: .primary, isLoading: true) {
                        print("Loading tapped")
                    }
                    
                    MomentumButton("Disabled", style: .primary) {
                        print("Disabled tapped")
                    }
                    .disabled(true)
                }
                
                Divider()
                
                // Secondary Buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Secondary Buttons")
                        .scaledFont(size: 17, weight: .semibold)
                    
                    MomentumButton("Learn More", style: .secondary, size: .large) {
                        print("Secondary large tapped")
                    }
                    
                    MomentumButton("Browse", icon: "folder", style: .secondary, size: .medium) {
                        print("Secondary medium tapped")
                    }
                    
                    MomentumButton("View", style: .secondary, size: .small) {
                        print("Secondary small tapped")
                    }
                }
                
                Divider()
                
                // Tertiary Buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tertiary Buttons")
                        .scaledFont(size: 17, weight: .semibold)
                    
                    MomentumButton("Skip", style: .tertiary) {
                        print("Tertiary tapped")
                    }
                    
                    MomentumButton("Learn More", icon: "info.circle", style: .tertiary) {
                        print("Tertiary with icon tapped")
                    }
                }
                
                Divider()
                
                // Destructive Buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Destructive Buttons")
                        .scaledFont(size: 17, weight: .semibold)
                    
                    MomentumButton("Delete", icon: "trash", style: .destructive) {
                        print("Delete tapped")
                    }
                    
                    MomentumButton("Remove All", style: .destructive, size: .small) {
                        print("Remove all tapped")
                    }
                }
                
                Divider()
                
                // Icon Buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Icon Buttons")
                        .scaledFont(size: 17, weight: .semibold)
                    
                    HStack(spacing: 16) {
                        IconButton(icon: "plus", style: .primary, accessibilityLabel: "Add") {
                            print("Add tapped")
                        }
                        
                        IconButton(icon: "square.and.pencil", style: .secondary, accessibilityLabel: "Edit") {
                            print("Edit tapped")
                        }
                        
                        IconButton(icon: "trash", style: .destructive, accessibilityLabel: "Delete") {
                            print("Delete tapped")
                        }
                        
                        IconButton(icon: "ellipsis", style: .ghost, accessibilityLabel: "More options") {
                            print("More tapped")
                        }
                    }
                    
                    HStack(spacing: 16) {
                        IconButton(icon: "heart", size: .small, accessibilityLabel: "Like") {
                            print("Like tapped")
                        }
                        
                        IconButton(icon: "heart.fill", size: .medium, accessibilityLabel: "Unlike") {
                            print("Unlike tapped")
                        }
                        
                        IconButton(icon: "star", size: .large, accessibilityLabel: "Favorite") {
                            print("Favorite tapped")
                        }
                    }
                }
                
                Divider()
                
                // Floating Action Button
                VStack(alignment: .leading, spacing: 12) {
                    Text("Floating Action Button")
                        .scaledFont(size: 17, weight: .semibold)
                    
                    HStack {
                        Spacer()
                        FloatingActionButton(icon: "plus", accessibilityLabel: "Create new") {
                            print("FAB tapped")
                        }
                    }
                }
                
                Divider()
                
                // Loading Button Demo
                VStack(alignment: .leading, spacing: 12) {
                    Text("Loading State Demo")
                        .scaledFont(size: 17, weight: .semibold)
                    
                    LoadingButton(action: {
                        isLoading = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isLoading = false
                        }
                    }, isLoading: isLoading) {
                        Text("Submit")
                    }
                }
            }
            .padding()
        }
    }
}

struct ButtonSystemPreview_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ButtonSystemPreview()
                .preferredColorScheme(.light)
            
            ButtonSystemPreview()
                .preferredColorScheme(.dark)
        }
    }
}
#endif