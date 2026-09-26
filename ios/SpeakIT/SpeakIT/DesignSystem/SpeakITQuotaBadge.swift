//
//  SpeakITQuotaBadge.swift
//  SpeakIT
//
//  Pill badge for quota, tier, and metadata counters.
//

import SwiftUI

struct SpeakITQuotaBadge: View {
    let text: String
    var foregroundColor: Color = Color.speakitPrimary
    var backgroundColor: Color = Color.speakitBadgeBackground
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .clipShape(Capsule())
    }
}
