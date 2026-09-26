//
//  Colors.swift
//  SpeakIT
//
//  Design System color tokens aligned with design_tokens.json and Apple HIG.
//

import SwiftUI

extension Color {
    // MARK: - Initializer for Hex Colors
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
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // MARK: - Semantic Design Tokens
    static let speakitPrimary = Color(hex: "6366F1")
    static let speakitSecondary = Color(hex: "0EA5E9")
    static let speakitGradientEnd = Color(hex: "8B5CF6")
    
    // Backgrounds & Surfaces
    static let speakitBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor.black : UIColor.white
    })
    
    static let speakitCard = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0) // #F2F2F7
    })
    
    static let speakitCardElevated = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0) : UIColor.white
    })

    static let speakitBadgeBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.20, green: 0.20, blue: 0.40, alpha: 1.0) : UIColor(red: 0.93, green: 0.94, blue: 1.0, alpha: 1.0) // #EEF0FF
    })

    // Typography & Text
    static let speakitTextPrimary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
    })
    
    static let speakitTextSecondary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor(white: 0.8, alpha: 1.0) : UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1.0) // #3C3C43
    })
    
    static let speakitTextTertiary = Color(hex: "8E8E93")
    
    // Status
    static let speakitSuccess = Color(hex: "34C759")
    static let speakitWarning = Color(hex: "FF9500")
    static let speakitDestructive = Color(hex: "FF3B30")
    static let speakitDestructiveLight = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.35, green: 0.12, blue: 0.12, alpha: 1.0) : UIColor(red: 1.0, green: 0.95, blue: 0.94, alpha: 1.0) // #FFF1F0
    })

    // Borders & Dividers
    static let speakitBorder = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor(white: 0.25, alpha: 1.0) : UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1.0) // #D1D1D6
    })

    static let speakitWaveformBar = Color(hex: "A5B4FC")

    // MARK: - Gradients
    static var speakitPrimaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color.speakitPrimary, Color.speakitGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
