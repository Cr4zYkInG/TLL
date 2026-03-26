import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
#endif

extension Color {
    init(hex: String) {
        #if canImport(UIKit)
        self.init(uiColor: PlatformColor(hex: hex) ?? .clear)
        #elseif canImport(AppKit)
        self.init(nsColor: PlatformColor(hex: hex) ?? .clear)
        #endif
    }
}

extension PlatformColor {
    #if canImport(UIKit)
    static var windowBackgroundColor: UIColor {
        return .systemBackground
    }
    #endif
    
    #if canImport(AppKit) && !canImport(UIKit)
    convenience init?(hex: String) {
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
            return nil
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
    #else
    convenience init?(hex: String) {
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
            return nil
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
    #endif
}

struct Theme {
    struct Colors {
        #if canImport(UIKit)
        static let bg = Color(UIColor { appearance in
            return appearance.userInterfaceStyle == .dark ? #colorLiteral(red: 0.05, green: 0.05, blue: 0.05, alpha: 1) : #colorLiteral(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
        })
        static let bgLight = Color(UIColor { appearance in
            return appearance.userInterfaceStyle == .dark ? #colorLiteral(red: 0.08, green: 0.08, blue: 0.08, alpha: 1) : #colorLiteral(red: 0.96, green: 0.96, blue: 0.96, alpha: 1)
        })
        static let surface = Color(UIColor { appearance in
            return appearance.userInterfaceStyle == .dark ? #colorLiteral(red: 0.12, green: 0.12, blue: 0.12, alpha: 1) : #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        })
        static let textPrimary = Color(UIColor { appearance in
            return appearance.userInterfaceStyle == .dark ? #colorLiteral(red: 0.95, green: 0.95, blue: 0.95, alpha: 1) : #colorLiteral(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        })
        static let textSecondary = Color.secondary
        static let textSecondaryLight = Color.secondary.opacity(0.7)
        static let onAccent = Color(UIColor { appearance in
            return appearance.userInterfaceStyle == .dark ? .black : .white
        })
        #else
        static let bg = Color(NSColor(name: nil, dynamicProvider: { appearance in
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? #colorLiteral(red: 0.05, green: 0.05, blue: 0.05, alpha: 1) : #colorLiteral(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
        }))
        static let bgLight = Color(NSColor(name: nil, dynamicProvider: { appearance in
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? #colorLiteral(red: 0.08, green: 0.08, blue: 0.08, alpha: 1) : #colorLiteral(red: 0.96, green: 0.96, blue: 0.96, alpha: 1)
        }))
        static let surface = Color(NSColor(name: nil, dynamicProvider: { appearance in
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? #colorLiteral(red: 0.12, green: 0.12, blue: 0.12, alpha: 1) : #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        }))
        static let textPrimary = Color(NSColor(name: nil, dynamicProvider: { appearance in
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? #colorLiteral(red: 0.95, green: 0.95, blue: 0.95, alpha: 1) : #colorLiteral(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        }))
        static let textSecondary = Color.secondary
        static let textSecondaryLight = Color.secondary.opacity(0.7)
        static let onAccent = Color(NSColor(name: nil, dynamicProvider: { appearance in
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .black : .white
        }))
        #endif
        
        #if canImport(UIKit)
        static var accent: Color {
            if let hex = UserDefaults.standard.string(forKey: "chambers_accent_hex") {
                return Color(hex: hex)
            }
            return Color(UIColor { appearance in
                return appearance.userInterfaceStyle == .dark ? .white : .black
            })
        }
        static var accentSecondary: Color {
            if let _ = UserDefaults.standard.string(forKey: "chambers_accent_hex") {
                return accent.opacity(0.8)
            }
            return Color(UIColor { appearance in
                return appearance.userInterfaceStyle == .dark ? #colorLiteral(red: 0.8, green: 0.8, blue: 0.8, alpha: 1) : #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
            })
        }
        #else
        static var accent: Color {
            if let hex = UserDefaults.standard.string(forKey: "chambers_accent_hex") {
                return Color(hex: hex)
            }
            return Color(NSColor(name: nil, dynamicProvider: { appearance in
                return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .black
            }))
        }
        static var accentSecondary: Color {
            if let _ = UserDefaults.standard.string(forKey: "chambers_accent_hex") {
                return accent.opacity(0.8)
            }
            return Color(NSColor(name: nil, dynamicProvider: { appearance in
                return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? #colorLiteral(red: 0.8, green: 0.8, blue: 0.8, alpha: 1) : #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
            }))
        }
        #endif
        
        static let glassBorder = Color.white.opacity(0.1)
        
        static let shadow = Color.black.opacity(0.1)
        
        static let windowBackgroundColor = PlatformColor.windowBackgroundColor
    }
    
    struct Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)
        static let slowSpring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0)
        static let bouncy = SwiftUI.Animation.interactiveSpring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)
    }
    
    struct Shadows {
        static let soft = Color.black.opacity(0.05)
        static let medium = Color.black.opacity(0.1)
        static let glass = Color.black.opacity(0.15)
    }
    
    struct Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let huge: CGFloat = 32
    }
    
    struct Fonts {
        static func outfit(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return .system(size: size, weight: weight, design: .default)
        }
        
        static func playfair(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return .system(size: size, weight: weight, design: .serif)
        }
        
        static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return .system(size: size, weight: weight, design: .default)
        }
    }
    
    // --- Device Detection ---
    static var isPhone: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }
    
    static var isPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    struct HapticFeedback {
        static func light() {
            #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
        }
        
        static func medium() {
            #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            #endif
        }
        
        static func heavy() {
            #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            #endif
        }
        
        static func success() {
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
        }
    }
}

// MARK: - View Modifiers

#if canImport(UIKit)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
#else
// Fallback for macOS compatibility
extension View {
    func cornerRadius(_ radius: CGFloat, corners: Any) -> some View {
        self.cornerRadius(radius)
    }
}
#endif

enum HapticFeedbackStyle {
    case light, medium, heavy, success, warning, error
}

extension View {
    func hapticFeedback(_ style: HapticFeedbackStyle) -> some View {
        self.simultaneousGesture(TapGesture().onEnded {
            #if os(iOS)
            switch style {
            case .light: Theme.HapticFeedback.light()
            case .medium: Theme.HapticFeedback.medium()
            case .heavy: Theme.HapticFeedback.heavy()
            case .success: Theme.HapticFeedback.success()
            default: break
            }
            #endif
        })
    }
}

