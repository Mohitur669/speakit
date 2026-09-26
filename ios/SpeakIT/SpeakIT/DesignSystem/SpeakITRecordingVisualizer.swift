//
//  SpeakITRecordingVisualizer.swift
//  SpeakIT
//
//  Real-time 18-bar amplitude waveform visualizer matching 04_STT_Record.svg.
//

import SwiftUI

struct SpeakITRecordingVisualizer: View {
    let amplitudes: [CGFloat]
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<amplitudes.count, id: \.self) { index in
                let height = reduceMotion ? 20.0 : max(10.0, amplitudes[index] * 36.0)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.speakitWaveformBar)
                    .frame(width: 7, height: height)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: height)
            }
        }
        .frame(height: 40)
    }
}
