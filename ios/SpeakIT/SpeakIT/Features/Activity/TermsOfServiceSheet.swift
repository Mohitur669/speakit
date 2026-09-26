//
//  TermsOfServiceSheet.swift
//  SpeakIT
//
//  Native in-app Terms of Service matching frontend terms.component.ts.
//

import SwiftUI

struct TermsOfServiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Terms of Service")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Text("Last updated: May 31, 2026")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    .padding(.top, 8)
                    
                    // Introductory Legal Note
                    Text("These Terms constitute a \"Record\" under the Information Technology Act, 2000 and a legally binding contract under the Indian Contract Act, 1872.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color.speakitTextSecondary)
                        .padding(14)
                        .background(Color.speakitBadgeBackground)
                        .cornerRadius(12)
                    
                    // Section 1
                    sectionCard(
                        title: "1. User Account Responsibility",
                        bodyText: "You are responsible for maintaining the confidentiality of your password and credentials. You agree to notify us immediately of any unauthorized use of your account. We reserve the right to suspend or terminate accounts that provide false information during registration or violate service integrity."
                    )
                    
                    // Section 2
                    VStack(alignment: .leading, spacing: 10) {
                        Text("2. Prohibited Content (Rule 3(1)(b) Compliance)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Text("In accordance with Rule 3(1)(b) of the IT Rules, 2021, you shall not host, display, synthesize, or upload any text that:")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.speakitTextSecondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            prohibitedBullet("Belongs to another person without legal right.")
                            prohibitedBullet("Is defamatory, obscene, pornographic, or invasive of another's privacy.")
                            prohibitedBullet("Is harmful to minors or threatens the unity, integrity, or defense of India.")
                            prohibitedBullet("Violates any law currently in force in India or applicable jurisdictions.")
                        }
                        .padding(.top, 4)
                        
                        Text("Any violation will result in immediate termination of service and reporting to relevant authorities if required by law.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.speakitDestructive)
                            .padding(.top, 4)
                    }
                    .padding(16)
                    .background(Color.speakitBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
                    )
                    
                    // Section 3
                    sectionCard(
                        title: "3. Rate Limiting and Service Fair Use",
                        bodyText: "SpeakIT employs Bucket4j token bucket rate limiting to enforce quotas per IP and authenticated user. Attempting to bypass these limits via automated scripts, botting, or multiple accounts is a breach of these Terms. For Free Plan users, daily limits are set dynamically via our system parameters."
                    )
                    
                    // Section 4
                    sectionCard(
                        title: "4. Payments and Refunds",
                        bodyText: "Subscriptions and payments are managed through secure payment processors (Razorpay and Apple App Store in-app purchases). All transactions are billed in accordance with the selected tier. Since SpeakIT is a digital SaaS product with immediate compute and synthesis consumption, refunds are governed by the Consumer Protection (e-Commerce) Rules, 2020 once a voice synthesis operation has been completed."
                    )
                    
                    // Section 5
                    sectionCard(
                        title: "5. Governing Law & Jurisdiction",
                        bodyText: "These Terms shall be governed by and constructed in accordance with the laws of India. Any disputes arising out of or in connection with these Terms shall be subject to the exclusive jurisdiction of the competent courts in West Bengal, India."
                    )
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.bottom, 36)
            }
            .background(Color(hex: "F8F9FB").ignoresSafeArea())
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.speakitPrimary)
                }
            }
        }
    }
    
    private func sectionCard(title: String, bodyText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.speakitTextPrimary)
            
            Text(bodyText)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.speakitTextSecondary)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.speakitBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
        )
    }
    
    private func prohibitedBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(Color.speakitDestructive)
                .padding(.top, 2)
            
            Text(text)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color.speakitTextPrimary)
        }
    }
}

#Preview {
    TermsOfServiceSheet()
}
