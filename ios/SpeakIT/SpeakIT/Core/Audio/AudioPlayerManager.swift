//
//  AudioPlayerManager.swift
//  SpeakIT
//
//  AVPlayer wrapper with background playback, lock-screen controls, and AirPods route-change detection.
//

import Foundation
import AVFoundation
import MediaPlayer

@Observable
final class AudioPlayerManager: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerManager()
    
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0.0
    var duration: TimeInterval = 0.0
    var playbackRate: Float = 1.0
    var currentAudioURL: URL? = nil
    
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    
    override private init() {
        super.init()
        setupAudioSession()
        setupNotifications()
    }
    
    deinit {
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        Task.detached(priority: .userInitiated) {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.duckOthers])
                if #available(iOS 27.0, *) {
                    try await session.activate(options: [])
                } else {
                    try session.setActive(true)
                }
            } catch {
                print("Failed to set audio session category: \(error)")
            }
        }
    }
    
    // MARK: - Playback Controls
    func loadAndPlay(url: URL, title: String = "Generated Speech", subtitle: String = "SpeakIT") {
        load(url: url, title: title, subtitle: subtitle, autoPlay: true)
    }
    
    func load(url: URL, title: String = "Generated Speech", subtitle: String = "SpeakIT", autoPlay: Bool = true) {
        stop()
        currentAudioURL = url
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        setupTimeObserver()
        
        // Duration extraction
        Task {
            if let durationTime = try? await playerItem.asset.load(.duration) {
                let seconds = CMTimeGetSeconds(durationTime)
                if !seconds.isNaN && seconds > 0 {
                    await MainActor.run {
                        self.duration = seconds
                        self.updateNowPlayingInfo(title: title, subtitle: subtitle)
                    }
                }
            }
        }
        
        if autoPlay {
            play()
        } else {
            isPlaying = false
        }
        updateNowPlayingInfo(title: title, subtitle: subtitle)
    }
    
    func play() {
        guard let player = player else { return }
        player.rate = playbackRate
        isPlaying = true
        updateNowPlayingState(isPlaying: true)
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingState(isPlaying: false)
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func stop() {
        pause()
        removeTimeObserver()
        player = nil
        currentTime = 0.0
        duration = 0.0
        isPlaying = false
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }
    
    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
    }
    
    // MARK: - Time Observer
    private func setupTimeObserver() {
        removeTimeObserver()
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let seconds = CMTimeGetSeconds(time)
            if !seconds.isNaN {
                self.currentTime = seconds
                if self.duration > 0 && self.currentTime >= self.duration {
                    self.pause()
                    self.seek(to: 0)
                }
            }
        }
    }
    
    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    // MARK: - Notifications & Interruption
    private func setupNotifications() {
        // Route changes (AirPods disconnect -> pause)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        // Interruptions (Phone call / Siri)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        
        if reason == .oldDeviceUnavailable {
            // AirPods unplugged/disconnected: ALWAYS pause immediately!
            DispatchQueue.main.async {
                self.pause()
            }
        }
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        if type == .began {
            DispatchQueue.main.async {
                self.pause()
            }
        } else if type == .ended {
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                DispatchQueue.main.async {
                    self.play()
                }
            }
        }
    }
    
    // MARK: - MPNowPlayingInfoCenter
    private func updateNowPlayingInfo(title: String, subtitle: String) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = subtitle
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingState(isPlaying: Bool) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
