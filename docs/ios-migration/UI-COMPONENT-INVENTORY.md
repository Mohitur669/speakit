# SpeakIT iOS UI Component Inventory

This document details all reusable native SwiftUI components implemented for the SpeakIT iOS application, their location, variants, states, accessibility semantics, and usage across the product.

---

## 1. Design System Tokens & Foundations

| File | Purpose | Location |
|---|---|---|
| `Colors.swift` | Semantic color tokens (`speakitPrimary`, `speakitSecondary`, `speakitBackground`, `speakitCard`, `speakitBadgeBackground`, `speakitPrimaryGradient`, etc.) with automatic Light/Dark mode adaptation. | [`Core/Theme/Colors.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/Core/Theme/Colors.swift) |
| `Typography.swift` | Dynamic Type typographic scale (`speakitTitleLarge`, `speakitTitleSection`, `speakitHeadline`, `speakitBody`, `speakitCaption`, `speakitMonoBadge`, `speakitTimer`). | [`Core/Theme/Typography.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/Core/Theme/Typography.swift) |
| `Spacing.swift` | 4pt base unit spacing scale (`micro`, `related`, `compact`, `card`, `screenMargin`, `section`, `hero`) and control corner radii. | [`Core/Theme/Spacing.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/Core/Theme/Spacing.swift) |

---

## 2. Reusable UI Components

### 2.1 `SpeakITButton`
* **File:** [`DesignSystem/SpeakITButton.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/DesignSystem/SpeakITButton.swift)
* **Visual Reference:** Matches 52pt primary buttons across all 8 SVG screens.
* **Variants:**
  * `.primary`: Linear gradient (`#6366F1` to `#8B5CF6`) with white bold text.
  * `.secondary`: `#EEF0FF` background with `#6366F1` text.
  * `.outline`: White/card surface with `#D1D1D6` 1pt stroke.
  * `.destructive`: `#FFF1F0` background with `#FF3B30` text.
* **States:** Normal, Pressed (haptic tick), Loading (inline `ProgressView`), Disabled (50% opacity).
* **Touch Target:** Minimum 52pt height × full width (meets 44×44pt requirement).
* **Where Used:** `LoginView`, `SignUpView`, `TTSStudioView`, `VoiceCatalogSheet`, `STTStudioView`, `ProfileSettingsView`, `SubscriptionPaywallView`.

### 2.2 `SpeakITTextField`
* **File:** [`DesignSystem/SpeakITTextField.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/DesignSystem/SpeakITTextField.swift)
* **Visual Reference:** 50pt rounded input fields from `01_Login.svg`.
* **Features:**
  * 14pt corner radius with `#D1D1D6` border.
  * Leading SF Symbol icon support.
  * Secure password mode with toggleable eye action button (44×44pt hit target).
  * Auto-capitalization and keyboard type configuration.
* **States:** Empty, Filled, Active Focus, Password Obscured / Revealed.
* **Where Used:** `LoginView`, `SignUpView`.

### 2.3 `SpeakITQuotaBadge`
* **File:** [`DesignSystem/SpeakITQuotaBadge.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/DesignSystem/SpeakITQuotaBadge.swift)
* **Visual Reference:** Quota pill capsules from `02_TTS_Studio.svg` ("1,450 left") and `06_Activity.svg` ("PRO").
* **Variants:** Customizable foreground and background colors (defaults to `#EEF0FF` background with `#6366F1` text).
* **Where Used:** `TTSStudioView`, `ActivityView`, `TranscriptionResultSheet`.

### 2.4 `SpeakITAudioPlayer`
* **File:** [`DesignSystem/SpeakITAudioPlayer.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/DesignSystem/SpeakITAudioPlayer.swift)
* **Visual Reference:** Docked player card from `02_TTS_Studio.svg`.
* **Features:**
  * 44pt circular play/pause button with haptic feedback.
  * Interactive audio scrubber slider.
  * Real-time elapsed time (`0:00`) and total duration (`0:12`) labels.
  * Native iOS Share Sheet (`UIActivityViewController`) export button.
* **States:** Idle, Playing, Paused, Scrubbing.
* **Where Used:** `TTSStudioView`, `TranscriptionResultSheet`.

### 2.5 `SpeakITRecordingVisualizer`
* **File:** [`DesignSystem/SpeakITRecordingVisualizer.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/DesignSystem/SpeakITRecordingVisualizer.swift)
* **Visual Reference:** 18-bar amplitude waveform from `04_STT_Record.svg`.
* **Features:**
  * 18 rounded vertical bars (7pt width, 4pt radius) in `#A5B4FC`.
  * Dynamic height driven directly by live microphone `AVAudioRecorder.averagePower`.
  * Fully respects `UIAccessibility.isReduceMotionEnabled` (degrades to static gentle state).
* **Where Used:** `STTStudioView`.

### 2.6 `SpeakITVoiceRow`
* **File:** [`DesignSystem/SpeakITVoiceRow.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/DesignSystem/SpeakITVoiceRow.swift)
* **Visual Reference:** Voice card rows from `03_Voice_Catalog.svg`.
* **Features:**
  * 60pt height, 14pt radius, `#E1E1E6` border.
  * 32pt circular audition play button.
  * Voice name, language/accent, and engine provider badge.
  * Favorite toggle action and lock icon for gated voices.
* **States:** Normal, Selected (highlighted with `#6366F1` border), Locked.
* **Where Used:** `VoiceCatalogSheet`.

### 2.7 `SpeakITHistoryRow`
* **File:** [`DesignSystem/SpeakITHistoryRow.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/DesignSystem/SpeakITHistoryRow.swift)
* **Visual Reference:** Generation log items from `06_Activity.svg`.
* **Features:**
  * 70pt height, 14pt radius, `#E3E3E8` border.
  * 36pt circular play button for audio playback.
  * 1-line truncated text snippet with `.lineLimit(1)`.
  * Voice name / engine tag and relative timestamp ("2h ago", "Yesterday").
* **Where Used:** `ActivityView`.

### 2.8 `SpeakITSubscriptionCard`
* **File:** [`DesignSystem/SpeakITSubscriptionCard.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/DesignSystem/SpeakITSubscriptionCard.swift)
* **Visual Reference:** PRO and PRO PLUS plan cards from `08_Subscription_Paywall.svg`.
* **Features:**
  * Plan tier badge, monthly price, and bulleted features list.
  * Selection state with checkmark indicator and violet border.
* **Where Used:** `SubscriptionPaywallView`.

### 2.9 `SpeakITEmptyState`
* **File:** [`DesignSystem/SpeakITEmptyState.swift`](file:///Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/SpeakIT/DesignSystem/SpeakITEmptyState.swift)
* **Features:**
  * 64pt circular badge icon.
  * Title, descriptive message, and action capsule button.
* **Where Used:** `ActivityView`, `VoiceCatalogSheet`.
