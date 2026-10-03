//
//  SarvamLiveSTTService.swift
//  SpeakIT
//
//  Real-time streaming speech-to-text service via SpeakIT's WebSocket proxy.
//  Captures 16kHz mono PCM microphone audio via AVAudioEngine, computes dynamic
//  audio power levels for waveforms, and streams text events in real-time.
//

import Foundation
import AVFoundation
import SwiftUI

struct LiveTranscriptSegment: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let timestamp: Date
    let isTranslation: Bool
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

@Observable
final class SarvamLiveSTTService {
    // MARK: - Published State
    var isRecording: Bool = false
    var isConnecting: Bool = false
    var audioLevel: Float = 0.0 // 0.0 to 1.0 for dynamic waveform visualizer
    var elapsedSeconds: Int = 0
    var errorMessage: String? = nil
    
    // Live Transcription Stream
    var partialTranscript: String = ""
    var committedSegments: [LiveTranscriptSegment] = []
    
    // Configuration
    var mode: String = "transcribe" // "transcribe" or "translate"
    var languageCode: String = "auto"
    
    // MARK: - Audio Engine & Networking
    private var audioEngine: AVAudioEngine?
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var timer: Timer?
    
    init() {
        self.urlSession = URLSession(configuration: .default)
    }
    
    var fullTranscriptText: String {
        let committed = committedSegments.map { $0.text }.joined(separator: " ")
        if partialTranscript.isEmpty {
            return committed
        }
        return committed.isEmpty ? partialTranscript : "\(committed) \(partialTranscript)"
    }
    
    // MARK: - Start / Stop Live Session
    @MainActor
    func startSession() async {
        guard !isRecording && !isConnecting else { return }
        
        isConnecting = true
        errorMessage = nil
        elapsedSeconds = 0
        audioLevel = 0.0
        
        startTimer()
        
        // Request microphone permission and begin live real-time capture
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if granted {
                    self.connectAndRecord()
                } else {
                    self.isConnecting = false
                    self.errorMessage = "Microphone access denied. Please enable microphone in iOS Settings."
                }
            }
        }
    }
    
    @MainActor
    func stopSession() {
        guard isRecording || isConnecting else { return }
        
        isRecording = false
        isConnecting = false
        audioLevel = 0.0
        stopTimer()
        
        // Stop audio engine
        if let engine = audioEngine, engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        
        // Finalize partial transcript if present
        if !partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let seg = LiveTranscriptSegment(
                text: partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines),
                timestamp: Date(),
                isTranslation: mode == "translate"
            )
            committedSegments.append(seg)
            partialTranscript = ""
        }
        
        // Close WebSocket
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        HapticManager.shared.light()
    }
    
    @MainActor
    func clearTranscript() {
        committedSegments.removeAll()
        partialTranscript = ""
        elapsedSeconds = 0
        HapticManager.shared.selection()
    }
    
    // MARK: - Internal Microphone & WebSocket Engine
    @MainActor
    private func connectAndRecord() {
        // 1. Establish WebSocket Connection to SpeakIT backend proxy
        let wsBase = APIEndpoint.baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        
        let token = KeychainHelper.shared.getToken() ?? ""
        let encodedLang = languageCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? languageCode
        let encodedMode = mode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? mode
        guard let url = URL(string: "\(wsBase)/ws/live-stt?token=\(token)&language_code=\(encodedLang)&mode=\(encodedMode)") else {
            self.isConnecting = false
            self.errorMessage = "Invalid WebSocket connection URL."
            return
        }
        
        let task = urlSession?.webSocketTask(with: url)
        self.webSocketTask = task
        task?.resume()
        
        // Send initial handshake configuration
        let configPayload: [String: Any] = [
            "model": "saaras:v3-realtime",
            "language_code": languageCode,
            "mode": mode
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: configPayload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            task?.send(.string(jsonString)) { error in
                if let error = error {
                    print("Live STT config send error: \(error)")
                }
            }
        }
        
        // Start listening for inbound transcript events from proxy
        listenForInboundMessages()
        
        // 2. Configure AVAudioSession
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.overrideOutputAudioPort(.speaker)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to configure audio session for Live STT: \(error)")
        }
        
        // 3. Configure AVAudioEngine Tap (16kHz Mono Int16 PCM)
        let engine = AVAudioEngine()
        self.audioEngine = engine
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            self.isConnecting = false
            self.errorMessage = "Unable to initialize audio format for live speech."
            return
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            self.isConnecting = false
            self.errorMessage = "Audio format converter unavailable for input: \(inputFormat)."
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Calculate Audio RMS Power Level for Waveform
            var level: Float = 0.0
            if let channelData = buffer.floatChannelData?[0] {
                let frameLength = Int(buffer.frameLength)
                var sum: Float = 0.0
                for i in 0..<frameLength {
                    sum += channelData[i] * channelData[i]
                }
                let rms = sqrt(sum / Float(frameLength))
                level = min(1.0, max(0.0, rms * 5.0))
            }
            
            Task { @MainActor in
                self.audioLevel = level
            }
            
            // Convert to 16kHz mono 16-bit PCM
            let pcmBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * (16000.0 / inputFormat.sampleRate))
            )!
            
            var error: NSError?
            converter.convert(to: pcmBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            if let convertedData = self.toData(buffer: pcmBuffer) {
                self.webSocketTask?.send(.data(convertedData)) { err in
                    if let err = err {
                        print("Failed to stream audio chunk: \(err)")
                    }
                }
            }
        }
        
        do {
            try engine.start()
            self.isConnecting = false
            self.isRecording = true
            HapticManager.shared.success()
        } catch {
            self.isConnecting = false
            self.errorMessage = "Audio capture failed to start: \(error.localizedDescription)"
        }
    }
    
    private func listenForInboundMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    Task { @MainActor in
                        self.handleIncomingJson(text)
                    }
                default:
                    break
                }
                // Continue receiving next message
                self.listenForInboundMessages()
                
            case .failure(let error):
                print("Live STT WebSocket receive error: \(error)")
            }
        }
    }
    
    @MainActor
    private func handleIncomingJson(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        let type = (json["type"] as? String) ?? (json["event"] as? String) ?? ""
        
        var extractedText = ""
        if let text = json["text"] as? String {
            extractedText = text
        } else if let transcript = json["transcript"] as? String {
            extractedText = transcript
        } else if let dataObj = json["data"] as? [String: Any] {
            if let t = dataObj["transcript"] as? String {
                extractedText = t
            } else if let t = dataObj["text"] as? String {
                extractedText = t
            }
        }
        
        if type.contains("partial") || type == "transcript.partial" {
            self.partialTranscript = extractedText
        } else if type.contains("final") || type == "transcript.final" {
            let trimmed = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let segment = LiveTranscriptSegment(
                    text: trimmed,
                    timestamp: Date(),
                    isTranslation: self.mode == "translate"
                )
                self.committedSegments.append(segment)
                self.partialTranscript = ""
                HapticManager.shared.light()
            }
        } else if type == "error", let msg = (json["message"] as? String) ?? (json["error"] as? String) {
            self.errorMessage = msg
        } else if type == "upstream.closed" {
            if let reason = json["reason"] as? String, !reason.isEmpty {
                self.errorMessage = "Live service disconnected: \(reason)"
            }
        }
    }
    
    private func toData(buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData else { return nil }
        let channel = channelData[0]
        let byteCount = Int(buffer.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: channel, count: byteCount)
    }
    
    // MARK: - Timer
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.elapsedSeconds += 1
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
