# SpeakIT — Xcode & Simulator CLI Command Reference

> **Document Status:** Living Command Cheatsheet  
> **Location:** `docs/ios-migration/xcode-commands.md`  
> **Target Project:** `ios/SpeakIT/SpeakIT.xcodeproj`  
> **Target Simulator:** iPhone 17 (`3CCD6150-1C4F-465F-AE14-E231925779E7`)

---

## 1. Quick Device Context

| Parameter | Value |
|---|---|
| **Device Model** | iPhone 17 |
| **Simulator UDID** | `3CCD6150-1C4F-465F-AE14-E231925779E7` |
| **App Bundle ID** | `com.speakit.SpeakIT` |
| **Workspace Path** | `/Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT` |
| **Xcode Project** | `SpeakIT.xcodeproj` |
| **Scheme** | `SpeakIT` |

---

## 2. Monorepo Setup: Remove Nested `.git`

Xcode initializes a local Git repository by default when creating a new project. In a monorepo, this causes Git to treat `ios/SpeakIT` as an untracked submodule.

Run this command once from the repository root:
```bash
rm -rf /Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT/.git
```

Verify Git now tracks the iOS project files cleanly:
```bash
git status
```

---

## 3. Simulator Lifecycle Commands

### Boot the iPhone 17 Simulator
```bash
xcrun simctl boot 3CCD6150-1C4F-465F-AE14-E231925779E7
```

### Open the Simulator GUI Window on Mac
```bash
open -a Simulator
```

### Shut Down the Simulator
```bash
# Shut down the iPhone 17 simulator
xcrun simctl shutdown 3CCD6150-1C4F-465F-AE14-E231925779E7

# Or shut down all running simulators to free Mac RAM
xcrun simctl shutdown all
```

### Factory Reset / Clear Simulator Data
Flushes all Keychain tokens, cached JWT sessions, and local app storage:
```bash
xcrun simctl erase 3CCD6150-1C4F-465F-AE14-E231925779E7
```

---

## 4. Build, Install & Launch via Terminal

Navigate to the iOS project directory:
```bash
cd /Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT
```

### Step 1: Compile the Project
```bash
xcodebuild -project SpeakIT.xcodeproj \
  -scheme SpeakIT \
  -destination 'id=3CCD6150-1C4F-465F-AE14-E231925779E7' \
  -derivedDataPath build \
  build
```

### Step 2: Install the App onto the Simulator
```bash
xcrun simctl install 3CCD6150-1C4F-465F-AE14-E231925779E7 build/Build/Products/Debug-iphonesimulator/SpeakIT.app
```

### Step 3: Launch SpeakIT
```bash
xcrun simctl launch 3CCD6150-1C4F-465F-AE14-E231925779E7 com.speakit.SpeakIT
```

### Step 4: Terminate the App
```bash
xcrun simctl terminate 3CCD6150-1C4F-465F-AE14-E231925779E7 com.speakit.SpeakIT
```

---

## 5. One-Liner Fast Rebuild & Run

For daily coding, combine build, install, and launch into a single command:

```bash
cd /Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT && \
xcodebuild -project SpeakIT.xcodeproj -scheme SpeakIT -destination 'id=3CCD6150-1C4F-465F-AE14-E231925779E7' -derivedDataPath build build && \
xcrun simctl install 3CCD6150-1C4F-465F-AE14-E231925779E7 build/Build/Products/Debug-iphonesimulator/SpeakIT.app && \
xcrun simctl launch --terminate-running-process 3CCD6150-1C4F-465F-AE14-E231925779E7 com.speakit.SpeakIT
```

---

## 6. Live Logging & Debugging

### Stream Live SpeakIT Logs in Terminal
Filters macOS system logs to only show messages from the SpeakIT process:
```bash
xcrun simctl spawn 3CCD6150-1C4F-465F-AE14-E231925779E7 log stream --predicate 'process == "SpeakIT"'
```

### Filter for Specific Subsystems (Network / Audio)
```bash
xcrun simctl spawn 3CCD6150-1C4F-465F-AE14-E231925779E7 log stream --predicate 'process == "SpeakIT" and eventMessage contains "TTS"'
```

---

## 7. Media & Hardware Simulation

### Take a Screenshot
Saves a screenshot directly to your Desktop:
```bash
xcrun simctl io 3CCD6150-1C4F-465F-AE14-E231925779E7 screenshot ~/Desktop/speakit-screenshot.png
```

### Record Simulator Screen (Video)
```bash
# Start recording (Press Ctrl + C in terminal to stop)
xcrun simctl io 3CCD6150-1C4F-465F-AE14-E231925779E7 recordVideo ~/Desktop/speakit-demo.mp4
```

### Toggle Dark / Light Appearance
```bash
# Dark mode
xcrun simctl ui 3CCD6150-1C4F-465F-AE14-E231925779E7 appearance dark

# Light mode
xcrun simctl ui 3CCD6150-1C4F-465F-AE14-E231925779E7 appearance light
```

### Simulate Audio Interruption (Phone Call)
Tests SpeakIT's `AudioPlayerService` pause/resume handling:
```bash
xcrun simctl openurl 3CCD6150-1C4F-465F-AE14-E231925779E7 tel://1234567890
```

---

## 8. Physical iPhone Commands

When connecting your physical iPhone 17 over USB:

### Find Your Physical Device ID
```bash
xcrun devicectl list devices
```

### Build for Physical Device
```bash
cd /Users/mohitur/Desktop/git-projects/speakit/ios/SpeakIT

xcodebuild -project SpeakIT.xcodeproj \
  -scheme SpeakIT \
  -destination 'generic/platform=iOS' \
  build
```
*(Note: Code signing with your personal Apple ID team profile is handled automatically when building in Xcode GUI via `Cmd + R`)*
