import SwiftUI

// MARK: - Kunlun Design System
// Ultra-minimalist design system with three colors and 8pt grid spacing

// MARK: - Color System
extension Color {
    // Semantic colors that automatically adapt to light/dark mode
    // Maintains ultra-minimalist aesthetic while respecting user preferences
    
    // Background colors - adapt to light/dark mode
    static let kunlunBackground = Color(.systemBackground)           // Primary background (white in light, black in dark)
    static let kunlunSecondaryBackground = Color(.secondarySystemBackground) // Secondary background (light gray in light, dark gray in dark)
    
    // Text colors - adapt to light/dark mode  
    static let kunlunPrimaryText = Color(.label)                    // Primary text (black in light, white in dark)
    static let kunlunSecondaryText = Color(.secondaryLabel)         // Secondary text (dark gray in light, light gray in dark)
    static let kunlunTertiaryText = Color(.tertiaryLabel)           // Tertiary text (light gray in light, dark gray in dark)
    
    // Accent color - remains consistent across modes
    static let kunlunJade = Color(hex: "#00A693")                   // Links, active states, accents (unchanged)
    
    // Legacy color aliases for backward compatibility
    // These now use semantic colors instead of hardcoded values
    static let kunlunWhite = Color(.systemBackground)               // Now adapts to light/dark mode
    static let kunlunBlack = Color(.label)                         // Now adapts to light/dark mode
}

// MARK: - Typography System
extension Font {
    // SF Pro Text (iOS system font) - no custom fonts
    static let kunlunLargeTitle = Font.largeTitle     // 34pt - App title, major headings
    static let kunlunTitle = Font.title               // 28pt - Screen titles
    static let kunlunTitle2 = Font.title2             // 22pt - Section headers
    static let kunlunTitle3 = Font.title3             // 20pt - Note titles
    static let kunlunHeadline = Font.headline         // 17pt - Important text
    static let kunlunBody = Font.body                 // 17pt - Primary reading text
    static let kunlunCallout = Font.callout           // 16pt - Secondary text
    static let kunlunSubheadline = Font.subheadline   // 15pt - Metadata
    static let kunlunFootnote = Font.footnote         // 13pt - Captions
    static let kunlunCaption = Font.caption           // 12pt - Fine print
}

// MARK: - Spacing Scale - 8pt Grid System
extension CGFloat {
    // Based on 8pt grid for mathematical harmony
    static let kunlunMicro: CGFloat = 2      // Micro spacing
    static let kunlunTiny: CGFloat = 4       // Minimal spacing  
    static let kunlunSmall: CGFloat = 8      // Small elements
    static let kunlunMedium: CGFloat = 16    // Standard spacing
    static let kunlunLarge: CGFloat = 24     // Section spacing
    static let kunlunXLarge: CGFloat = 32    // Major spacing
    static let kunlunXXLarge: CGFloat = 48   // Screen margins
    static let kunlunMassive: CGFloat = 64   // Hero spacing
}

// MARK: - Animation Standards
extension Animation {
    // All animations must maintain 60fps
    static let kunlunFast = Animation.easeInOut(duration: 0.1)    // <100ms
    static let kunlunMedium = Animation.easeInOut(duration: 0.2)  // <200ms
    static let kunlunSlow = Animation.easeInOut(duration: 0.3)    // <300ms
}

// MARK: - Design Tokens Structure
struct KunlunDesignTokens {
    static let colors = KunlunColors()
    static let typography = KunlunTypography()
    static let spacing = KunlunSpacing()
    static let animation = KunlunAnimation()
}

struct KunlunColors {
    // Semantic colors for light/dark mode adaptation
    let background = Color.kunlunBackground
    let secondaryBackground = Color.kunlunSecondaryBackground
    let primaryText = Color.kunlunPrimaryText
    let secondaryText = Color.kunlunSecondaryText
    let tertiaryText = Color.kunlunTertiaryText
    let jade = Color.kunlunJade
    
    // Legacy color aliases (now semantic)
    let white = Color.kunlunWhite
    let black = Color.kunlunBlack
}

struct KunlunTypography {
    let largeTitle = Font.kunlunLargeTitle
    let title = Font.kunlunTitle
    let title2 = Font.kunlunTitle2
    let title3 = Font.kunlunTitle3
    let headline = Font.kunlunHeadline
    let body = Font.kunlunBody
    let callout = Font.kunlunCallout
    let subheadline = Font.kunlunSubheadline
    let footnote = Font.kunlunFootnote
    let caption = Font.kunlunCaption
}

struct KunlunSpacing {
    let micro: CGFloat = .kunlunMicro
    let tiny: CGFloat = .kunlunTiny
    let small: CGFloat = .kunlunSmall
    let medium: CGFloat = .kunlunMedium
    let large: CGFloat = .kunlunLarge
    let xlarge: CGFloat = .kunlunXLarge
    let xxlarge: CGFloat = .kunlunXXLarge
    let massive: CGFloat = .kunlunMassive
}

struct KunlunAnimation {
    let fast = Animation.kunlunFast
    let medium = Animation.kunlunMedium
    let slow = Animation.kunlunSlow
}

// MARK: - Reusable Component Extensions

// MARK: - KunlunCard Component
struct KunlunCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: .kunlunSmall) {
            content
        }
        .padding(.kunlunMedium)
        .background(Color.kunlunWhite)
        // Completely flat design - no shadows, borders, or decorative elements
    }
}

// MARK: - KunlunButton Component
struct KunlunButton: View {
    let title: String
    let action: () -> Void
    let style: KunlunButtonStyle
    
    init(_ title: String, style: KunlunButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.kunlunBody)
                .fontWeight(.medium)
                .foregroundColor(style.textColor)
                .padding(.horizontal, .kunlunMedium)
                .padding(.vertical, .kunlunSmall)
                .background(style.backgroundColor)
                // Flat design - no corner radius
        }
    }
}

enum KunlunButtonStyle {
    case primary
    case secondary
    
    var backgroundColor: Color {
        switch self {
        case .primary:
            return .kunlunJade
        case .secondary:
            return .kunlunWhite
        }
    }
    
    var textColor: Color {
        switch self {
        case .primary:
            return .kunlunWhite
        case .secondary:
            return .kunlunBlack
        }
    }
}

// MARK: - KunlunTextField Component
struct KunlunTextField: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.kunlunBody)
            .foregroundColor(.kunlunBlack)
            .padding(.kunlunMedium)
            .background(Color.kunlunWhite)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.kunlunBlack.opacity(0.2))
            )
    }
}

// MARK: - View Modifiers for 8pt Grid System
extension View {
    func kunlunPadding(_ edges: Edge.Set = .all, _ spacing: CGFloat) -> some View {
        self.padding(edges, spacing)
    }
}

// MARK: - Color Helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
