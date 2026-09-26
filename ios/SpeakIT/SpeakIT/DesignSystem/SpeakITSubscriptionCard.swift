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
    var isCurrentPlan: Bool = false
    var isDisabled: Bool = false
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            guard !isDisabled else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(tierName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.speakitPrimary)
                    
                    if isPopular {
                        Text("POPULAR")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.speakitPrimary)
                            .cornerRadius(4)
                    }
                    
                    if isCurrentPlan {
                        Text("ACTIVE PLAN")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.speakitSuccess)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.speakitSuccessLight)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(isCurrentPlan ? Color.speakitSuccess : Color.speakitPrimary)
                    } else if isDisabled {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color.speakitTextTertiary)
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
            .background(
                isCurrentPlan && isSelected
                    ? Color.speakitSuccessLight.opacity(0.35)
                    : (isSelected ? Color.speakitBadgeBackground : Color.speakitBackground)
            )
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isCurrentPlan && isSelected
                            ? Color.speakitSuccess
                            : (isSelected ? Color.speakitPrimary : Color(hex: "D9D9E0")),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .opacity(isDisabled && !isCurrentPlan ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
