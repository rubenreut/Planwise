//
//  FontScaling.swift
//  Momentum
//
//  Font and icon scaling based on user preference
//

import SwiftUI

// MARK: - Font Scaling Modifier
struct ScaledFont: ViewModifier {
    @AppStorage("appFontSize") private var appFontSizeRaw = "regular"
    let baseSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    
    private var scale: CGFloat {
        AppFontSize(rawValue: appFontSizeRaw)?.scale ?? 1.0
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: baseSize * scale, weight: weight, design: design))
    }
}

// MARK: - Icon Scaling Modifier
struct ScaledIcon: ViewModifier {
    @AppStorage("appFontSize") private var appFontSizeRaw = "regular"
    
    private var scale: CGFloat {
        AppFontSize(rawValue: appFontSizeRaw)?.iconScale ?? 1.0
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
    }
}

// MARK: - Container Scaling Modifier
struct ScaledContainer: ViewModifier {
    @AppStorage("appFontSize") private var appFontSizeRaw = "regular"
    let baseHeight: CGFloat
    let basePadding: CGFloat
    
    private var scale: CGFloat {
        AppFontSize(rawValue: appFontSizeRaw)?.scale ?? 1.0
    }
    
    func body(content: Content) -> some View {
        content
            .frame(height: baseHeight * scale)
            .padding(.all, basePadding * scale)
    }
}

// MARK: - Dynamic Type Scaling
struct DynamicTypeScaling: ViewModifier {
    @AppStorage("appFontSize") private var appFontSizeRaw = "regular"
    
    private var scale: CGFloat {
        AppFontSize(rawValue: appFontSizeRaw)?.scale ?? 1.0
    }
    
    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(dynamicRange)
    }
    
    private var dynamicRange: ClosedRange<DynamicTypeSize> {
        switch AppFontSize(rawValue: appFontSizeRaw) {
        case .verySmall:
            return .xSmall...DynamicTypeSize.medium
        case .small:
            return .small...DynamicTypeSize.large
        case .regular:
            return .medium...DynamicTypeSize.xLarge
        case .large:
            return .large...DynamicTypeSize.xxxLarge
        case .none:
            return .medium...DynamicTypeSize.xLarge
        }
    }
}

// MARK: - Convenience Extensions
extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        self.modifier(ScaledFont(baseSize: size, weight: weight, design: design))
    }
    
    func scaledIcon() -> some View {
        self.modifier(ScaledIcon())
    }
    
    func dynamicTypeScaling() -> some View {
        self.modifier(DynamicTypeScaling())
    }
    
    func scaledContainer(height: CGFloat, padding: CGFloat = 0) -> some View {
        self.modifier(ScaledContainer(baseHeight: height, basePadding: padding))
    }
    
    func scaledPadding(_ edges: Edge.Set = .all, _ length: CGFloat) -> some View {
        self.modifier(ScaledPadding(edges: edges, baseLength: length))
    }
    
    func scaledFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        self.modifier(ScaledFrame(baseWidth: width, baseHeight: height))
    }
}

// MARK: - Scaled Padding Modifier
struct ScaledPadding: ViewModifier {
    @AppStorage("appFontSize") private var appFontSizeRaw = "regular"
    let edges: Edge.Set
    let baseLength: CGFloat
    
    private var scale: CGFloat {
        AppFontSize(rawValue: appFontSizeRaw)?.scale ?? 1.0
    }
    
    func body(content: Content) -> some View {
        content
            .padding(edges, baseLength * scale)
    }
}

// MARK: - Scaled Frame Modifier
struct ScaledFrame: ViewModifier {
    @AppStorage("appFontSize") private var appFontSizeRaw = "regular"
    let baseWidth: CGFloat?
    let baseHeight: CGFloat?
    
    private var scale: CGFloat {
        AppFontSize(rawValue: appFontSizeRaw)?.scale ?? 1.0
    }
    
    func body(content: Content) -> some View {
        content
            .frame(
                width: baseWidth.map { $0 * scale },
                height: baseHeight.map { $0 * scale }
            )
    }
}

// MARK: - Scaled System Fonts
extension Font {
    @AppStorage("appFontSize") private static var appFontSizeRaw = "regular"
    
    private static var scale: CGFloat {
        AppFontSize(rawValue: appFontSizeRaw)?.scale ?? 1.0
    }
    
    static var scaledLargeTitle: Font {
        .system(size: 34 * scale, weight: .bold, design: .default)
    }
    
    static var scaledTitle: Font {
        .system(size: 28 * scale, weight: .bold, design: .default)
    }
    
    static var scaledTitle2: Font {
        .system(size: 22 * scale, weight: .bold, design: .default)
    }
    
    static var scaledTitle3: Font {
        .system(size: 20 * scale, weight: .semibold, design: .default)
    }
    
    static var scaledHeadline: Font {
        .system(size: 17 * scale, weight: .semibold, design: .default)
    }
    
    static var scaledBody: Font {
        .system(size: 17 * scale, weight: .regular, design: .default)
    }
    
    static var scaledCallout: Font {
        .system(size: 16 * scale, weight: .regular, design: .default)
    }
    
    static var scaledSubheadline: Font {
        .system(size: 15 * scale, weight: .regular, design: .default)
    }
    
    static var scaledFootnote: Font {
        .system(size: 13 * scale, weight: .regular, design: .default)
    }
    
    static var scaledCaption: Font {
        .system(size: 12 * scale, weight: .regular, design: .default)
    }
    
    static var scaledCaption2: Font {
        .system(size: 11 * scale, weight: .regular, design: .default)
    }
}

// MARK: - Environment Key for Font Scale
struct FontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var fontScale: CGFloat {
        get { self[FontScaleKey.self] }
        set { self[FontScaleKey.self] = newValue }
    }
}

// MARK: - Root View Modifier
struct FontScalingEnvironment: ViewModifier {
    @AppStorage("appFontSize") private var appFontSizeRaw = "regular"
    
    private var scale: CGFloat {
        AppFontSize(rawValue: appFontSizeRaw)?.scale ?? 1.0
    }
    
    func body(content: Content) -> some View {
        content
            .environment(\.fontScale, scale)
    }
}