//
//  ElevenLabsLiveStreamTTSService.swift
//  SpeakIT
//
//  Phase 4: Live Voice Bridge — ElevenLabs Streaming TTS WebSocket client.
//  Connects to the backend /ws/live-tts proxy, sends text chunks,
//  receives binary MP3 audio, and plays it via AVAudioEngine for low-latency output.
//
//  Protocol:
//    iOS → Backend → ElevenLabs: {"text":"sentence","try_trigger_generation":true}
//    iOS → Backend → ElevenLabs: {"text":""} to flush/end
//    ElevenLabs → Backend → iOS: binary MP3 audio chunks (streamed, play as received)
//
//  Target latency: < 800ms end-to-end (Sarvam STT ~100-200ms + ElevenLabs TTS ~75ms + network)
//

import AVFoundation
import Foundation
import os.log

private let logger = Logger(subsystem: "com.speakit", category: "ElevenLabsLiveStreamTTS")

@Observable
final class ElevenLabsLiveStreamTTSService: NSObject {

    // MARK: - Observable State

    /// Whether the TTS streaming session is active.
    var isConnected: Bool = false

    /// Whether audio is currently playing.
    var isPlaying: Bool = false

    /// Audio output level (0.0 – 1.0) for waveform visualizer.
    var audioLevel: Float = 0.0

    /// Last error message for display in UI.
    var lastError: String? = nil

    /// Total audio bytes received in current session (for analytics).
    var bytesReceived: Int = 0

    // MARK: - Private Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession = URLSession(configuration: .default)

    // AVAudioEngine for low-latency PCM playback
    private let audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    // MP3 chunks are decoded via AVAudioFile-in-memory approach
    private var audioQueue: [Data] = []
    private var isEngineSetup = false

    // MARK: - Connection Lifecycle

    /// Opens a WebSocket connection to the backend /ws/live-tts proxy.
    /// - Parameters:
    ///   - voiceId: ElevenLabs voice ID to use for synthesis.
    ///   - token: JWT auth token.
    func connect(voiceId: String, token: String) {
        disconnect()
        lastError = nil
        bytesReceived = 0

        // Build WebSocket URL using same pattern as SarvamLiveSTTService
        let wsBase = APIEndpoint.baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        let urlString = "\(wsBase)/ws/live-tts?token=\(token)&voiceId=\(voiceId)"
        guard let url = URL(string: urlString) else {
            lastError = "Invalid server URL"
            return
        }

        logger.info("ElevenLabsLiveTTS: Connecting to \(urlString)")
        let request = URLRequest(url: url)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        isConnected = true
        setupAudioEngine()
        receiveMessages()
    }

    /// Sends a text chunk to the backend for TTS synthesis.
    /// - Parameter text: The sentence or partial text to synthesize.
    func sendText(_ text: String) {
        guard isConnected, let task = webSocketTask else {
            logger.warning("ElevenLabsLiveTTS: sendText called but not connected")
            return
        }

        let payload: [String: Any] = [
            "text": text,
            "try_trigger_generation": true
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        logger.debug("ElevenLabsLiveTTS: Sending text chunk (\(text.count) chars)")
        task.send(.string(jsonString)) { [weak self] error in
            if let error = error {
                logger.error("ElevenLabsLiveTTS: Failed to send text chunk: \(error.localizedDescription)")
                self?.lastError = "Send failed: \(error.localizedDescription)"
            }
        }
    }

    /// Sends an EOS flush signal to trigger final audio generation, then disconnects.
    func flush() {
        guard isConnected, let task = webSocketTask else { return }
        let flushPayload = "{\"text\":\"\"}"
        logger.info("ElevenLabsLiveTTS: Sending EOS flush signal")
        task.send(.string(flushPayload)) { _ in }
    }

    /// Disconnects from the backend WebSocket and stops audio playback.
    func disconnect() {
        flush()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        stopAudio()
        isConnected = false
        isPlaying = false
        audioLevel = 0.0
        logger.info("ElevenLabsLiveTTS: Disconnected")
    }

    // MARK: - Message Receiving

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .data(let audioData):
                    // Binary MP3 audio chunk from ElevenLabs — play immediately
                    self.handleAudioChunk(audioData)
                case .string(let text):
                    // Metadata/control message (e.g. {"type":"audio_end"})
                    logger.debug("ElevenLabsLiveTTS: Received text frame: \(text)")
                    if text.contains("audio_end") {
                        // EOS signal from backend — stream complete
                        logger.info("ElevenLabsLiveTTS: Received audio_end signal")
                        DispatchQueue.main.async { self.isPlaying = false }
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self.receiveMessages()

            case .failure(let error):
                let nsErr = error as NSError
                // Code 57 = socket not connected (normal on close)
                if nsErr.code != 57 && nsErr.code != 54 {
                    logger.error("ElevenLabsLiveTTS: WebSocket receive error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.lastError = "Connection error: \(error.localizedDescription)"
                        self.isConnected = false
                        self.isPlaying = false
                    }
                }
            }
        }
    }

    // MARK: - Audio Playback

    private func setupAudioEngine() {
        guard !isEngineSetup else { return }

        Task.detached(priority: .userInitiated) {
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setCategory(.playback, mode: .default)
            try? audioSession.setActive(true)
        }

        do {
            audioEngine.attach(playerNode)
            // Use 44100 Hz stereo to match ElevenLabs mp3_44100_128 output
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
            try audioEngine.start()
            playerNode.play()
            isEngineSetup = true
            logger.info("ElevenLabsLiveTTS: AVAudioEngine started (44100Hz stereo)")
        } catch {
            logger.error("ElevenLabsLiveTTS: AVAudioEngine setup failed: \(error.localizedDescription)")
            lastError = "Audio engine setup failed"
        }
    }

    /// Decodes an MP3 Data chunk and schedules it for immediate playback.
    private func handleAudioChunk(_ data: Data) {
        bytesReceived += data.count
        DispatchQueue.main.async { self.isPlaying = true }

        // Write chunk to a temp file for AVAudioFile decoding
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("el_chunk_\(UUID().uuidString).mp3")
        do {
            try data.write(to: tempURL)
            let audioFile = try AVAudioFile(forReading: tempURL)
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                                frameCapacity: frameCount) else { return }
            try audioFile.read(into: buffer)

            // Schedule for immediate playback
            playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                DispatchQueue.main.async {
                    // Animate audio level for waveform
                    self?.audioLevel = 0.0
                }
            }

            // Simulate audio level for waveform (based on data size as proxy)
            let level = min(1.0, Float(data.count) / 4096.0)
            DispatchQueue.main.async { self.audioLevel = level }

            // Cleanup temp file
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            logger.error("ElevenLabsLiveTTS: Failed to decode MP3 chunk (\(data.count) bytes): \(error.localizedDescription)")
        }
    }

    private func stopAudio() {
        if audioEngine.isRunning {
            playerNode.stop()
            audioEngine.stop()
            isEngineSetup = false
        }
        Task.detached(priority: .utility) {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
