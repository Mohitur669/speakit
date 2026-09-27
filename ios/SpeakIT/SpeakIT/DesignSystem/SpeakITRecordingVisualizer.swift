//
//  SpeakITRecordingVisualizer.swift
//  SpeakIT
//
//  Real-time iOS Voice Memos / Siri-inspired waveform visualizer.
//  Features dynamic capsule bars, natural frequency curves, center-mirrored expansion,
//  and smooth ambient breathing when idle.
//

import SwiftUI

struct SpeakITRecordingVisualizer: View {
    let amplitudes: [CGFloat]
    var isRecording: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Ambient breathing phase when idle
    @State private var ambientPhase: Double = 0.0
    
    // Waveform bar configuration
    private let barCount: Int = 22
    private let barWidth: CGFloat = 3.5
    private let barSpacing: CGFloat = 4.5
    private let minBarHeight: CGFloat = 6.0
    private let maxBarHeight: CGFloat = 48.0
    
    var body: some View {
        ZStack {
            // Ambient glow behind waveform while recording
            if isRecording && !reduceMotion {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.speakitDestructive.opacity(0.18),
                                Color.speakitPrimary.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 70
                        )
                    )
                    .frame(width: 160, height: 50)
                    .blur(radius: 12)
            }
            
            // Centered audio wave capsules
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    barView(at: index)
                }
            }
            .frame(height: maxBarHeight, alignment: .center)
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    ambientPhase = .pi * 2
                }
            }
        }
    }
    
    @ViewBuilder
    private func barView(at index: Int) -> some View {
        let height = computedBarHeight(for: index)
        
        Capsule(style: .continuous)
            .fill(barGradient(for: index))
            .frame(width: barWidth, height: height)
            .animation(reduceMotion ? nil : .spring(response: 0.12, dampingFraction: 0.62), value: height)
    }
    
    private func computedBarHeight(for index: Int) -> CGFloat {
        if reduceMotion {
            return isRecording ? 24.0 : minBarHeight
        }
        
        if !isRecording {
            // Gentle ambient sinusoidal wave when idle
            let normalizedIndex = Double(index) / Double(barCount)
            let sineVal = sin(ambientPhase + normalizedIndex * .pi * 2)
            let waveHeight = minBarHeight + CGFloat((sineVal + 1.0) * 0.5) * 4.0
            return max(minBarHeight, waveHeight)
        }
        
        // When recording: map incoming amplitudes with acoustic bell-curve envelope
        let ampIndex = index % max(1, amplitudes.count)
        let rawAmp = (ampIndex < amplitudes.count) ? amplitudes[ampIndex] : 0.2
        
        // Bell-curve weighting: center bars respond with higher dynamic range
        let center = Double(barCount - 1) / 2.0
        let distanceFromCenter = abs(Double(index) - center) / center
        let envelope = 1.0 - (distanceFromCenter * 0.35)
        
        let scaledAmp = rawAmp * CGFloat(envelope)
        let targetHeight = minBarHeight + (scaledAmp * (maxBarHeight - minBarHeight))
        return max(minBarHeight, min(maxBarHeight, targetHeight))
    }
    
    private func barGradient(for index: Int) -> LinearGradient {
        if isRecording {
            return LinearGradient(
                colors: [
                    Color(hex: "FF3B30"),
                    Color(hex: "FF6961")
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.speakitTextTertiary.opacity(0.35),
                    Color.speakitTextTertiary.opacity(0.2)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
    }
}
