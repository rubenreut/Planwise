import SwiftUI

// MARK: - Font Choice
enum FontChoice: String, CaseIterable {
    case system = "System"
    case rounded = "SF Rounded"
    case serif = "New York"
    case mono = "SF Mono"
    case helvetica = "Helvetica Neue"
    case avenir = "Avenir Next"
    case georgia = "Georgia"
    
    var displayName: String { rawValue }
    
    func font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        switch self {
        case .system:
            return .system(size: size, weight: weight, design: design)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .mono:
            return .system(size: size, weight: weight, design: .monospaced)
        case .helvetica:
            return Font.custom("HelveticaNeue", size: size).weight(weight)
        case .avenir:
            return Font.custom("AvenirNext-Regular", size: size).weight(weight)
        case .georgia:
            return Font.custom("Georgia", size: size).weight(weight)
        }
    }
}

// MARK: - Typography System
// Consistent typography scales throughout the app

enum Typography {
    // Get current font choice from UserDefaults
    private static var currentFont: FontChoice {
        let fontString = UserDefaults.standard.string(forKey: "selectedFontFamily") ?? FontChoice.system.rawValue
        return FontChoice(rawValue: fontString) ?? .system
    }
    // MARK: - Display
    enum Display {
        static var large: Font { currentFont.font(size: 57, weight: .regular) }
        static var medium: Font { currentFont.font(size: 45, weight: .regular) }
        static var small: Font { currentFont.font(size: 36, weight: .regular) }
    }
    
    // MARK: - Headline
    enum Headline {
        static var large: Font { currentFont.font(size: 32, weight: .regular) }
        static var medium: Font { currentFont.font(size: 28, weight: .regular) }
        static var small: Font { currentFont.font(size: 24, weight: .regular) }
    }
    
    // MARK: - Title
    enum Title {
        static var large: Font { currentFont.font(size: 22, weight: .regular) }
        static var medium: Font { currentFont.font(size: 16, weight: .medium) }
        static var small: Font { currentFont.font(size: 14, weight: .medium) }
    }
    
    // MARK: - Body
    enum Body {
        static var large: Font { currentFont.font(size: 16, weight: .regular) }
        static var medium: Font { currentFont.font(size: 14, weight: .regular) }
        static var small: Font { currentFont.font(size: 12, weight: .regular) }
    }
    
    // MARK: - Label
    enum Label {
        static var large: Font { currentFont.font(size: 14, weight: .medium) }
        static var medium: Font { currentFont.font(size: 12, weight: .medium) }
        static var small: Font { currentFont.font(size: 11, weight: .medium) }
    }
}

// MARK: - Text Style Modifier
struct TypographyModifier: ViewModifier {
    let font: Font
    let color: Color?
    let lineSpacing: CGFloat?
    
    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color ?? .primary)
            .lineSpacing(lineSpacing ?? 0)
    }
}

// MARK: - View Extension
extension View {
    // Display styles
    func displayLarge(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Display.large, color: color, lineSpacing: 0))
    }
    
    func displayMedium(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Display.medium, color: color, lineSpacing: 0))
    }
    
    func displaySmall(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Display.small, color: color, lineSpacing: 0))
    }
    
    // Headline styles
    func headlineLarge(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Headline.large, color: color, lineSpacing: 0))
    }
    
    func headlineMedium(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Headline.medium, color: color, lineSpacing: 0))
    }
    
    func headlineSmall(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Headline.small, color: color, lineSpacing: 0))
    }
    
    // Title styles
    func titleLarge(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Title.large, color: color, lineSpacing: 2))
    }
    
    func titleMedium(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Title.medium, color: color, lineSpacing: 1))
    }
    
    func titleSmall(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Title.small, color: color, lineSpacing: 1))
    }
    
    // Body styles
    func bodyLarge(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Body.large, color: color, lineSpacing: 4))
    }
    
    func bodyMedium(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Body.medium, color: color, lineSpacing: 3))
    }
    
    func bodySmall(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Body.small, color: color, lineSpacing: 2))
    }
    
    // Label styles
    func labelLarge(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Label.large, color: color, lineSpacing: 1))
    }
    
    func labelMedium(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Label.medium, color: color, lineSpacing: 1))
    }
    
    func labelSmall(color: Color? = nil) -> some View {
        modifier(TypographyModifier(font: Typography.Label.small, color: color, lineSpacing: 0))
    }
}

// MARK: - Common Text Styles
extension Text {
    // Headers
    func pageTitle() -> some View {
        self.headlineLarge()
            .fontWeight(.bold)
    }
    
    func sectionHeader() -> some View {
        self.headlineSmall()
            .fontWeight(.semibold)
    }
    
    func cardTitle() -> some View {
        self.titleMedium()
            .fontWeight(.semibold)
    }
    
    // Content
    func primaryBody() -> some View {
        self.bodyLarge()
    }
    
    func secondaryBody() -> some View {
        self.bodyMedium(color: .secondary)
    }
    
    func caption() -> some View {
        self.bodySmall(color: .secondary)
    }
    
    // Interactive
    func buttonText() -> some View {
        self.titleMedium()
            .fontWeight(.semibold)
    }
    
    func linkText() -> some View {
        self.bodyLarge(color: .accentColor)
    }
}