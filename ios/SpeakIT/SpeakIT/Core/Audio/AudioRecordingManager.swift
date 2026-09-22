//
//  AudioRecordingManager.swift
//  SpeakIT
//
//  AVAudioRecorder wrapper configured for 16kHz mono AAC with real-time amplitude metering.
//

import Foundation
import AVFoundation

@Observable
final class AudioRecordingManager: NSObject, AVAudioRecorderDelegate {
    static let shared = AudioRecordingManager()
    
    var isRecording: Bool = false
    var elapsedTime: TimeInterval = 0.0
    var amplitudes: [CGFloat] = Array(repeating: 0.15, count: 18)
    var recordedFileURL: URL? = nil
    var hasPermission: Bool = false
    
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private let maxDuration: TimeInterval = 300.0 // 5-minute guardrail
    
    override private init() {
        super.init()
    }
    
    // MARK: - Permission
    func checkPermission() async -> Bool {
        let status = AVAudioApplication.shared.recordPermission
        switch status {
        case .granted:
            hasPermission = true
            return true
        case .denied:
            hasPermission = false
            return false
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            hasPermission = granted
            return granted
        @unknown default:
            return false
        }
    }
    
    // MARK: - Recording
    func startRecording() async -> Bool {
        let permitted = await checkPermission()
        guard permitted else { return false }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("live_recording_\(Date().timeIntervalSince1970).m4a")
            self.recordedFileURL = fileURL
            
            // 16kHz mono AAC settings (optimized for Groq Whisper)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 32000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true
            recorder?.record()
            
            isRecording = true
            elapsedTime = 0.0
            
            startMetering()
            return true
        } catch {
            print("Failed to start recording: \(error)")
            return false
        }
    }
    
    func stopRecording() -> URL? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        
        // Reset amplitudes to base height
        amplitudes = Array(repeating: 0.15, count: 18)
        
        // Deactivate recording audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        return recordedFileURL
    }
    
    private func startMetering() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.recorder, recorder.isRecording else { return }
            
            recorder.updateMeters()
            self.elapsedTime = recorder.currentTime
            
            // 5-minute guardrail
            if self.elapsedTime >= self.maxDuration {
                _ = self.stopRecording()
                return
            }
            
            // Normalized amplitude calculation (-60 dB to 0 dB)
            let power = recorder.averagePower(forChannel: 0)
            let minDb: Float = -60.0
            let normalized = max(0.05, min(1.0, (power - minDb) / (0.0 - minDb)))
            
            // Shift amplitudes array with smooth varied heights
            var newAmps = self.amplitudes
            newAmps.removeFirst()
            
            // Add varied jitter around normalized power
            let jitter = Float.random(in: -0.15...0.15)
            let finalAmp = CGFloat(max(0.1, min(1.0, normalized + jitter)))
            newAmps.append(finalAmp)
            
            self.amplitudes = newAmps
        }
    }
    
    // MARK: - Delegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            isRecording = false
        }
    }
}
