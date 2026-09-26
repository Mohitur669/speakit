//
//  Typography.swift
//  SpeakIT
//
//  Design System Typography scale supporting Dynamic Type.
//

import SwiftUI

extension Font {
    // Large Title (~34pt)
    static var speakitTitleLarge: Font {
        .system(size: 30, weight: .bold, design: .default)
    }

    // Section Title (~22pt)
    static var speakitTitleSection: Font {
        .system(size: 22, weight: .bold, design: .default)
    }

    // Headline (~17pt semibold)
    static var speakitHeadline: Font {
        .system(size: 17, weight: .semibold, design: .default)
    }

    // Body (~17pt regular)
    static var speakitBody: Font {
        .system(size: 16, weight: .regular, design: .default)
    }

    // Secondary / Subheadline (~15pt)
    static var speakitSecondary: Font {
        .system(size: 14, weight: .regular, design: .default)
    }

    // Caption (~12pt)
    static var speakitCaption: Font {
        .system(size: 12, weight: .medium, design: .default)
    }

    // Small Caption (~11pt)
    static var speakitCaptionSmall: Font {
        .system(size: 11, weight: .regular, design: .default)
    }

    // Monospaced badge / timer (~13pt)
    static var speakitMonoBadge: Font {
        .system(size: 13, weight: .semibold, design: .rounded).monospacedDigit()
    }

    // Prominent timer (~32pt)
    static var speakitTimer: Font {
        .system(size: 32, weight: .bold, design: .rounded).monospacedDigit()
    }
}
