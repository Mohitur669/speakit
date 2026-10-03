# SpeakIT iOS Activity, Live Chat & Design System Specification

## Document Overview
This document defines the UI/UX architecture, color token governance, timestamp formatting rules, and Live Chat session lifecycle for the native SpeakIT iOS application. It addresses design alignment with SpeakIT's existing design system tokens, direct AM/PM timestamping, 4-way Activity segmentation, and the Face-to-Face Session Setup Launcher.

---

## 1. Design System & Semantic Color Tokens

SpeakIT adheres strictly to Apple's Human Interface Guidelines (HIG) and the design tokens established in `design_tokens.json` and `Colors.swift`. Arbitrary colors (such as unbranded dark teals or neon gradients) are forbidden.

### Semantic Color Token Matrix

| Semantic Token | Hex / Light Mode | Dark Mode | Usage |
|---|---|---|---|
| `Color.speakitPrimary` | `#6366F1` (Indigo) | `#818CF8` | Primary CTA buttons, active segmented control tabs, Speaker 1 accents, quota progress bars. |
| `Color.speakitSecondary` | `#0EA5E9` (Sky Blue) | `#38BDF8` | Speaker 2 accents, secondary indicators, transcription format tags. |
| `Color.speakitGradientEnd` | `#8B5CF6` (Purple) | `#A78BFA` | Subtle brand gradients. |
| `Color.speakitScreenBackground` | `#F8F9FB` | `#000000` | Main scroll view background. |
| `Color.speakitCardSurface` | `#FFFFFF` | `#1C1C1E` | Card containers, list rows, top navigation bars, modal sheets. |
| `Color.speakitCard` | `#F2F2F7` | `#1C1C1E` | Input field backgrounds, segmented control troughs, secondary bubble surfaces. |
| `Color.speakitBadgeBackground` | `#EEF0FF` | `#2D2B52` | Icon circles, turn badges, Speaker 1 bubble surfaces. |
| `Color.speakitBorder` | `#E6E6EB` | `rgba(255,255,255,0.08)` | Hairline dividers and card borders (1pt stroke). |
| `Color.speakitTextPrimary` | `#000000` | `#FFFFFF` | Headings, transcription text, card titles. |
| `Color.speakitTextSecondary` | `#3C3C43` | `#EBEBF5` | Subtitles, secondary metadata, turn counts. |
| `Color.speakitTextTertiary` | `#8E8E93` | `#8E8E93` | Form field labels, subtle timestamps, placeholders. |
| `Color.speakitSuccess` | `#34C759` | `#30D158` | Live connection status dot, successful generation badges. |
| `Color.speakitDestructive` | `#FF3B30` | `#FF453A` | Recording indicator, delete actions. |

---

## 2. Direct AM/PM Timestamp Formatting

### 2.1 Problem & Resolution
Previously, history rows and detail sheets displayed raw SQL strings directly (e.g., `2026-10-03 20:24:33.212 +0530`), or continuous relative counters that did not cleanly convey when a generation occurred.

The platform now standardizes on **direct Date and AM/PM time stamping**:
- Dates are formatted cleanly using standard date conventions (`MMM d, yyyy` -> `Oct 3, 2026`).
- Times are formatted in 12-hour AM/PM format (`h:mm a` -> `8:24 PM`).
- Combined representation: `Oct 3, 2026, 8:24 PM`.

### 2.2 Date Parsing Engine (`HistoryItem.swift`)
To guarantee compatibility with all backend formats (Postgres timestamps with timezone offsets, ISO 8601 strings, and plain datetimes), `HistoryItem.swift` evaluates candidates sequentially:

```swift
private static let candidateDateFormats = [
    "yyyy-MM-dd HH:mm:ss.SSSSSS Z",
    "yyyy-MM-dd HH:mm:ss.SSS Z",
    "yyyy-MM-dd HH:mm:ss.SSSZ",
    "yyyy-MM-dd HH:mm:ss.SSSSSS",
    "yyyy-MM-dd HH:mm:ss.SSS",
    "yyyy-MM-dd HH:mm:ss Z",
    "yyyy-MM-dd HH:mm:ss",
    "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
    "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
    "yyyy-MM-dd'T'HH:mm:ss.SSS",
    "yyyy-MM-dd'T'HH:mm:ssZ",
    "yyyy-MM-dd'T'HH:mm:ss",
    "yyyy-MM-dd"
]
```

### 2.3 Row Presentation
In `SpeakITHistoryRow.swift` and `liveChatHistoryCard`, the timestamp is stacked on the trailing edge of the card:
- Top Line: `Oct 3, 2026` (`font: 11pt, weight: .semibold, color: Color.speakitTextSecondary`)
- Bottom Line: `8:24 PM` (`font: 10pt, weight: .regular, color: Color.speakitTextTertiary`)

---

## 3. Activity Filters & Live Chat Drill-Down

### 3.1 Four Activity Filters
In `ActivityView.swift`, the segmented control provides 4 distinct views:

```swift
enum ActivityFilter: String, CaseIterable, Identifiable {
    case all = "ALL"
    case translate = "TRANSLATE"
    case transcribe = "TRANSCRIBE"
    case liveChat = "LIVE"
}
```

1. **All (`ALL`):** Displays all historical generations chronologically.
2. **Translate (`TRANSLATE`):** Text-to-Speech synthesis records (AWS Polly, ElevenLabs, Sarvam TTS).
3. **Transcribe (`TRANSCRIBE`):** Speech-to-Text file imports and solo live dictations. Excludes two-person interactive conversations.
4. **Live Chat (`LIVE`):** Multi-turn Face-to-Face live conversation sessions.

### 3.2 Live Chat History Row (`liveChatHistoryCard`)
- **Visual Card:** 70pt height, 14pt corner radius, white/dark card surface with `#E6E6EB` border.
- **Left Badge:** Circular `#EEF0FF` badge with `bubble.left.and.bubble.right.fill` in `Color.speakitPrimary` (`#6366F1`).
- **Middle Column:** Session title (bold) with turn count pill (`X turns • Live Session`).
- **Right Column:** Stacked date & time in AM/PM + chevron.
- **Interaction:** Tapping opens `LiveChatDetailView.swift` as a native sheet.

### 3.3 Live Chat Dialogue Viewer (`LiveChatDetailView.swift`)
- **Metadata Strip:** Pill header with total turn count, character credit consumption, and direct AM/PM date/time stamp.
- **Bilingual Turn Bubbles:**
  - **Speaker 1 (Host):** Aligned leading. Background `Color.speakitBadgeBackground` with subtle `Color.speakitPrimary.opacity(0.25)` hairline border and `#6366F1` avatar circle.
  - **Speaker 2 (Guest):** Aligned trailing. Background `Color.speakitCard` with `Color.speakitBorder` hairline border and `#0EA5E9` avatar circle.
- **Turn Playback:** Tap speaker icon beside either original text or translated text to re-synthesize speech via `LocalSpeechSpeaker`.
- **Export & Sharing:** Copy complete transcript to clipboard or share via native iOS `UIActivityViewController` (`ShareLink`).

---

## 4. Face-to-Face Session Setup Launcher

### 4.1 Problem & User Journey Improvement
Previously, navigating to Face-to-Face mode immediately displayed an empty conversation list with live microphones ready, without allowing users to configure session metadata or speaker names.

### 4.2 Solution: Session Setup Launcher (`faceToFaceSessionLauncher`)
When entering Face-to-Face mode, if no active session is in progress, the user is presented with the **Session Setup Launcher**:

1. **Session Name Input:** Optional descriptive title (`e.g. Doctor Consultation or Client Meeting`). If left blank, automatically defaults to `Live Conversation (Speaker 1 & Speaker 2)`.
2. **Speaker 1 Configuration Card:** Editable name (`Speaker 1`) + language selector dropdown (accented in `#6366F1`).
3. **Center Language Swap Button:** Centered between both speaker cards with spring rotation animation (`arrow.triangle.swap`) to instantly invert language roles.
4. **Speaker 2 Configuration Card:** Editable name (`Speaker 2`) + language selector dropdown (accented in `#0EA5E9`).
5. **CTA Button:** `+ Start Live Session` button (`Color.speakitPrimary`, 50pt height, 16pt radius) that transitions into the active conversation.

### 4.3 Active Session Toolbar (`activeConversationTopBar`)
Once a session is active:
- Top bar displays a live status indicator (pulsing red dot while recording, green dot when idle), session title, and turn counter.
- **"+ New Session" Button:** Prompts an alert asking the user to confirm starting a new session; on confirmation, current turns are persisted to backend history, state resets, and launcher re-appears.
- **"End" Button:** Persists turns to `/api/stt/transcribe-live` session storage, marks conversation complete, and returns to launcher.

---

## 5. Verification Checklist

- [x] All 5 backend tests in `HistoryControllerTest` pass without regressions.
- [x] Swift parsing check (`swiftc -parse`) succeeds on all modified iOS files.
- [x] Dates and times are stamped directly with AM/PM across all rows, detail views, and cards.
- [x] Zero raw continuous timestamps (`2026-10-03 20:24:33.212 +0530`) exposed in user-facing UI.
- [x] Complete brand color token adherence: Speaker 1 in `#6366F1`, Speaker 2 in `#0EA5E9`, no unauthorized teals.
- [x] Face-to-Face Session Setup Launcher prevents accidental recording and supports custom session titles.
