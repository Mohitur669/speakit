//
//  SpeakITSubscriptionCard.swift
//  SpeakIT
//
//  Subscription plan card matching 08_Subscription_Paywall.svg.
//

import SwiftUI

struct SpeakITSubscriptionCard: View {
    let tierName: String
    let price: String
    let features: [String]
    let isSelected: Bool
    var isPopular: Bool = false
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            UISelectionFeedbackGenerator().selectionChanged()
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tierName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.speakitPrimary)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.speakitPrimary)
                    }
                }
                
                Text(price)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                
                ForEach(features, id: \.self) { feature in
                    Text(feature)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.speakitTextSecondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.speakitBadgeBackground : Color.speakitBackground)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Color.speakitPrimary : Color(hex: "D9D9E0"), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
