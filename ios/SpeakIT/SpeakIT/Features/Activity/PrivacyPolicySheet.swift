//
//  PrivacyPolicySheet.swift
//  SpeakIT
//
//  Native in-app Privacy Policy matching frontend privacy.component.ts.
//

import SwiftUI

struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Privacy Policy")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Text("Last updated: May 31, 2026")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    .padding(.top, 8)
                    
                    // Introductory Note
                    Text("SpeakIT values your trust. This Privacy Policy explains how we collect, store, and process your personal data in accordance with the Digital Personal Data Protection Act, 2023 (DPDP Act) and the Information Technology Rules, 2011.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color.speakitTextSecondary)
                        .padding(14)
                        .background(Color.speakitBadgeBackground)
                        .cornerRadius(12)
                    
                    // Section 1
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1. Consent and Data Collection")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Text("By creating an account or using our service, you provide free, specific, informed, and unambiguous consent under Section 6 of the DPDP Act. We collect:")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.speakitTextSecondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            bulletItem(title: "Account Information", detail: "Full name, username, email address, and encrypted credentials stored securely in PostgreSQL.")
                            bulletItem(title: "Input Content", detail: "Text submitted for Text-to-Speech synthesis and audio uploaded for Speech-to-Text transcription.")
                            bulletItem(title: "Usage & Security Logs", detail: "Session tokens, IP rate-limiting telemetry (Bucket4j), and operational diagnostics.")
                        }
                    }
                    .padding(16)
                    .background(Color.speakitBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
                    )
                    
                    // Section 2
                    sectionCard(
                        title: "2. Purpose of Processing",
                        bodyText: "In line with statutory Purpose Limitation requirements, your data is used strictly for authenticating your session, generating speech audio via AWS Polly and neural engines, enforcing tier quotas, and safeguarding cybersecurity as mandated by Section 43A of the IT Act, 2000."
                    )
                    
                    // Section 3
                    sectionCard(
                        title: "3. Data Sovereignty & Cloud Infrastructure",
                        bodyText: "All speech synthesis operations and database records are hosted on Amazon Web Services (AWS) in the ap-south-1 (Mumbai, India) region to ensure strict data residency and sovereignty compliance. Your scripts and synthesized audio are never used to train public third-party AI models without explicit consent."
                    )
                    
                    // Section 4
                    sectionCard(
                        title: "4. Data Security and Retention",
                        bodyText: "We implement industry-standard reasonable security practices, including cryptographic password hashing, stateless JWT session versioning, and SSL/TLS in transit. You retain the right to delete your account and synthesis logs at any time from Account Settings."
                    )
                    
                    // Section 5 - Grievance Officer
                    VStack(alignment: .leading, spacing: 10) {
                        Text("5. Grievance Redressal Officer")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Text("As mandated by Rule 3(11) of the IT Rules, 2021, any privacy inquiries or grievances may be directed to:")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.speakitTextSecondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name: Mohd Mohitur Rahaman")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.speakitTextPrimary)
                            Text("Email: grievance@mohitur.com")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.speakitPrimary)
                            Text("Jurisdiction: West Bengal, India")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color.speakitTextSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "F2F2F7"))
                        .cornerRadius(10)
                    }
                    .padding(16)
                    .background(Color.speakitBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
                    )
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.bottom, 36)
            }
            .background(Color(hex: "F8F9FB").ignoresSafeArea())
            .navigationTitle("Privacy Policy")
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
    
    private func bulletItem(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.speakitPrimary)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.speakitTextPrimary)
                Text(detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.speakitTextSecondary)
            }
        }
    }
}

#Preview {
    PrivacyPolicySheet()
}
