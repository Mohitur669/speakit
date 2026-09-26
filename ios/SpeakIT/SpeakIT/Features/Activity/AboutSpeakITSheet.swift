//
//  AboutSpeakITSheet.swift
//  SpeakIT
//
//  Native in-app About view matching frontend about.component.ts.
//

import SwiftUI

struct AboutSpeakITSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Section
                    VStack(spacing: 10) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color.speakitPrimary)
                            .padding(.top, 8)
                        
                        Text("SpeakIT")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Text("Giving voice to the internet")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.speakitPrimary)
                        
                        Text("We build the infrastructure for the next generation of auditory and voice synthesis experiences.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.speakitTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    
                    // Mission Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("OUR MISSION")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.speakitPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.speakitBadgeBackground)
                                .clipShape(Capsule())
                        }
                        
                        Text("Democratizing studio-quality speech")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Text("Historically, high-quality voiceovers required expensive studio rentals, professional voice actors, and hours of post-production. SpeakIT transforms text into natural, emotional, and highly expressive speech in milliseconds using state-of-the-art neural networks.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.speakitTextSecondary)
                            .lineSpacing(4)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.speakitBackground)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
                    )
                    
                    // Core Values
                    VStack(alignment: .leading, spacing: 14) {
                        Text("CORE VALUES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.speakitTextTertiary)
                        
                        valueRow(
                            icon: "bolt.fill",
                            title: "Speed Matters",
                            description: "Sub-second synthesis delivery with optimized audio pipelines and caching."
                        )
                        
                        Divider()
                        
                        valueRow(
                            icon: "lock.shield.fill",
                            title: "Privacy First",
                            description: "Your intellectual property is strictly protected and never used to train global AI models."
                        )
                        
                        Divider()
                        
                        valueRow(
                            icon: "globe",
                            title: "Multilingual Inclusivity",
                            description: "World-class Indian language neural voices (Sarvam) alongside international accents (ElevenLabs & AWS Polly)."
                        )
                    }
                    .padding(18)
                    .background(Color.speakitBackground)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
                    )
                    
                    // App Version Footer
                    VStack(spacing: 4) {
                        Text("SpeakIT iOS • Version 1.0.0 (Build 27)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.speakitTextTertiary)
                        Text("Engineered by Mohd Mohitur Rahaman")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color.speakitTextTertiary)
                    }
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.bottom, 24)
            }
            .background(Color(hex: "F8F9FB").ignoresSafeArea())
            .navigationTitle("About SpeakIT")
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
    
    private func valueRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.speakitBadgeBackground)
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.speakitPrimary)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                
                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.speakitTextSecondary)
                    .lineSpacing(2)
            }
        }
    }
}

#Preview {
    AboutSpeakITSheet()
}
