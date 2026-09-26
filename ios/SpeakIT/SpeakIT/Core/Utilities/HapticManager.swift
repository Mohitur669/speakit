//
//  HapticManager.swift
//  SpeakIT
//
//  Centralized haptic feedback controller respecting user preferences.
//

import UIKit
import SwiftUI

@MainActor
final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    /// Checks whether haptics are enabled globally by user preference (default: true).
    var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }
    
    /// Trigger an impact feedback (light, medium, heavy, soft, rigid)
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Trigger light impact feedback (e.g. subtle button taps, slider ticks)
    func light() {
        impact(.light)
    }
    
    /// Trigger medium impact feedback (e.g. primary actions, conversions)
    func medium() {
        impact(.medium)
    }
    
    /// Trigger heavy impact feedback (e.g. start/stop recording, deletion)
    func heavy() {
        impact(.heavy)
    }
    
    /// Trigger selection changed feedback (e.g. tab switch, dropdown/picker change, checkbox toggle)
    func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    /// Trigger notification feedback (success, error, warning)
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    /// Trigger success haptic (e.g. speech generation complete, profile saved)
    func success() {
        notification(.success)
    }
    
    /// Trigger error haptic (e.g. network failure, invalid input)
    func error() {
        notification(.error)
    }
    
    /// Trigger warning haptic (e.g. quota limit reached, paywall prompt)
    func warning() {
        notification(.warning)
    }
}
