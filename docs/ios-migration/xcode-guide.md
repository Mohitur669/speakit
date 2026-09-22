# SpeakIT — Xcode Master Guide for Web Developers

> **Document Status:** Living Master Guide  
> **Location:** `docs/ios-migration/xcode-guide.md`  
> **Audience:** Developers transitioning from Web/Angular/Java to native iOS (SwiftUI)  
> **Prerequisites:** macOS, Xcode installed, physical iPhone, USB cable

---

## 1. Introduction & Xcode Mental Model

If you are coming from full-stack web development (Java Spring Boot, Angular, TypeScript, VS Code), Xcode will initially feel different. This section maps web concepts to their exact native Xcode equivalents.

### 1.1 Web vs. Xcode Concept Mapping

| Web / Angular Concept | Xcode / iOS Equivalent | Purpose / Notes |
|---|---|---|
| `package.json` / `pom.xml` | **Swift Package Manager (SPM)** or `project.pbxproj` | Manages external libraries (e.g., Keychain, Sentry). |
| `environment.ts` / `.env` | **Configuration Settings (`.xcconfig`)** / Swift `Environment` structs | Manages API URLs (`http://localhost:8080`, production URLs). |
| `npm start` / `ng serve` | **Product → Run (`Cmd + R`)** | Builds the code, installs it onto the simulator or physical iPhone, and attaches the debugger. |
| Browser DevTools Console | **Debug Area / Console (`Cmd + Shift + Y`)** | Shows application logs (`print()`), network errors, and runtime crashes. |
| `localhost:8080` | **Local Mac IP (`http://192.168.x.x:8080`) or Staging URL** | **Crucial:** Physical iPhones cannot reach `localhost` — they must use your Mac's LAN IP or a deployed backend URL. |
| LocalStorage / Cookies | **Apple Keychain (`KeychainAccess`)** | Secure hardware-encrypted storage for JWT tokens and sensitive session data. |
| HTML + Tailwind CSS | **SwiftUI Views & Modifiers** | Declarative UI markup (`VStack`, `HStack`, `.padding()`, `.background()`). |
| Angular Signals / RxJS | **`@Observable` / `@State` / Swift Concurrency (`async/await`)** | Reactive state management native to modern iOS 17+. |

---

### 1.2 The Anatomy of the Xcode Window

When you open Xcode, the workspace is divided into 5 primary zones:

```text
+-----------------------------------------------------------------------------------+
|  [>] Run  [■] Stop  |  SpeakIT > [Your iPhone]  |  Status: Build Succeeded        |  <- TOP TOOLBAR
+--------------------+------------------------------------------+-------------------+
|                    |                                          |                   |
|  PROJECT           |  CODE EDITOR / SWIFTUI CANVAS PREVIEW    |  INSPECTORS       |
|  NAVIGATOR         |                                          |                   |
|  (File Tree)       |  struct ContentView: View {              |  Attributes,      |
|                    |      var body: some View { ... }         |  File settings,   |
|  Cmd + 1           |  }                                       |  Modifiers        |
|                    |                                          |  Cmd + Option + 0 |
|                    |                                          |                   |
+--------------------+------------------------------------------+-------------------+
|                    DEBUG AREA: Variables & Console Logs (Cmd + Shift + Y)         |
+-----------------------------------------------------------------------------------+
```

1. **Toolbar (Top):**
   * **Play button (`Cmd + R`):** Builds and runs the app.
   * **Stop button (`Cmd + .`):** Halts execution.
   * **Scheme / Destination Selector:** Choose whether you are running on a **Simulator** (e.g. iPhone 16 Pro) or your **Physical iPhone**.
2. **Navigator Pane (Left, `Cmd + 1`):** Shows your project files, assets, tests, and build logs.
3. **Editor Area (Center):** Where you write Swift code. In SwiftUI, pressing `Cmd + Option + Enter` opens the **Canvas** (live interactive preview of your UI without running the whole app).
4. **Inspectors Pane (Right, `Cmd + Option + 0`):** File inspectors, font size, colors, padding controls.
5. **Debug Area (Bottom, `Cmd + Shift + Y`):** Left side shows variables in memory; right side shows stdout/stderr console output.

---

## 2. Essential Xcode Keyboard Shortcuts

Commit these to memory — they save hours of time:

| Shortcut | Action | Description |
|---|---|---|
| `Cmd + R` | **Run** | Compiles and installs the app onto your phone or simulator. |
| `Cmd + B` | **Build** | Verifies compilation errors without launching the app. |
| `Cmd + .` | **Stop** | Stops running the app in the debugger. |
| `Cmd + Shift + K` | **Clean Build Folder** | Clears build cache (use this when something seems stuck or strange). |
| `Cmd + Shift + O` | **Quick Open** | Search and jump directly to any file, function, or struct name. |
| `Cmd + Shift + Y` | **Toggle Debug Area** | Show or hide the bottom console output. |
| `Cmd + Option + Enter` | **Toggle Canvas** | Open/close the SwiftUI live preview canvas. |
| `Cmd + /` | **Comment Line** | Toggles `//` comments. |
| `Cmd + Option + [` / `]` | **Move Line Up/Down** | Move selected line up or down. |
| `Ctrl + I` | **Re-indent Code** | Auto-formats indentation of selected code. |

---

## 3. Initial Setup: Xcode & Developer Account

### Step 3.1: Verify Command Line Tools
Open Terminal on your Mac and verify the tools are active:
```bash
xcode-select -p
```
If it prints `/Applications/Xcode.app/Contents/Developer`, you are set. If not, run:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### Step 3.2: Link Your Apple ID to Xcode
1. Open **Xcode**.
2. In the top Mac menu bar, click **Xcode → Settings...** (or press `Cmd + ,`).
3. Click the **Accounts** tab at the top.
4. Click the **+** (plus button) in the lower left corner → select **Apple ID** → click **Continue**.
5. Sign in with your standard Apple ID (the same one on your iPhone).
6. Once signed in, you will see your name listed under teams as:  
   `Your Name (Personal Team)` — **Role: User (Free)**.
   > **Note:** A Personal Team allows you to install apps directly onto your physical iPhone for testing completely free of charge. The $99/year Apple Developer Program is only needed later when testing In-App Purchases (StoreKit), TestFlight, or submitting to the App Store.

---

## 4. Connecting & Configuring Your Physical iPhone

Apple requires explicit authorization before an iPhone allows sideloading apps from Xcode.

### Step 4.1: Connect iPhone via USB Cable
1. Connect your iPhone to your Mac using a Lightning or USB-C cable.
2. Unlock your iPhone screen.
3. If a pop-up appears on your iPhone asking *"Trust This Computer?"*, tap **Trust** and enter your iPhone passcode.

### Step 4.2: Enable Developer Mode on iOS (iOS 16, 17, 18)
On modern iOS, Developer Mode is disabled by default for security:
1. On your iPhone, open **Settings**.
2. Scroll down and tap **Privacy & Security**.
3. Scroll all the way to the bottom and tap **Developer Mode**.
4. Toggle the switch to **ON**.
5. A confirmation dialog appears — tap **Restart**.
6. After your iPhone restarts, unlock it. An alert titled *"Turn On Developer Mode?"* will appear.
7. Tap **Turn On**, then enter your iPhone passcode.

### Step 4.3: Verify iPhone in Xcode
1. In Xcode, click **Window → Devices and Simulators** (or press `Cmd + Shift + 2`).
2. Under **Connected**, select your iPhone.
3. You will see a green dot next to your iPhone name with the message *"Connected"*.
4. (Optional) Check **Connect via network** to allow running apps over your home Wi-Fi without needing the cable plugged in.

---

## 5. Step-by-Step: Creating the SpeakIT iOS Project

When creating the native iOS application within this repository:

### Step 5.1: Create Project Scaffolding
1. In Xcode, select **File → New → Project...** (or press `Cmd + Shift + N`).
2. In the template chooser:
   * Select the **iOS** tab at the top.
   * Under Application, select **App**.
   * Click **Next**.
3. Fill in the Project Options dialog:
   * **Product Name:** `SpeakIT`
   * **Team:** Select your `Your Name (Personal Team)`.
   * **Organization Identifier:** `com.speakit` (or your chosen identifier).
   * **Bundle Identifier:** Will auto-compute to `com.speakit.SpeakIT`.
   * **Interface:** `SwiftUI` *(Do NOT select Storyboard)*.
   * **Language:** `Swift`.
   * **Storage:** `None` *(We use Swift Concurrency and Keychain; no Core Data/SwiftData needed for MVP)*.
   * **Include Tests:** Checked.
   * Click **Next**.
4. Choose the save location:
   * Navigate to your cloned SpeakIT repository folder.
   * Create a new folder named `ios` at the repository root: `speakit/ios/`.
   * Uncheck *"Create Git repository on my Mac"* (since this git repository is already managed at the root).
   * Click **Create**.

---

## 6. Target Project Folder Structure

Inside `ios/SpeakIT/`, organize the code following clean MVVM architecture:

```text
ios/SpeakIT/
├── SpeakIT.xcodeproj                <- Xcode Project Bundle
└── SpeakIT/
    ├── App/
    │   ├── SpeakITApp.swift          <- Entry point (@main)
    │   └── AppEnvironment.swift      <- API Base URLs & configuration
    ├── Core/
    │   ├── Network/
    │   │   ├── NetworkClient.swift   <- Native URLSession wrapper
    │   │   ├── APIEndpoint.swift     <- Base URL + paths (/api/tts, /api/stt)
    │   │   └── AuthInterceptor.swift <- Injects Bearer token
    │   ├── Storage/
    │   │   └── KeychainService.swift <- Secure token storage in iOS Keychain
    │   ├── Audio/
    │   │   ├── AudioPlayerService.swift   <- Playback & lock-screen controls
    │   │   └── AudioRecorderService.swift <- Microphone capture (.m4a / audio/mp4)
    │   └── WebSocket/
    │       └── SessionWebSocketService.swift <- Multi-login revocation (/ws/logout)
    ├── Features/
    │   ├── Auth/
    │   │   ├── Views/ (LoginView, SignupView)
    │   │   └── ViewModels/ (AuthViewModel)
    │   ├── TTS/
    │   │   ├── Views/ (TtsSynthesisView, VoicePickerView)
    │   │   └── ViewModels/ (TtsViewModel)
    │   ├── STT/
    │   │   ├── Views/ (SttRecordingView, TranscriptCardView)
    │   │   └── ViewModels/ (SttViewModel)
    │   └── Profile/
    │       └── Views/ (ProfileSettingsView)
    └── Resources/
        ├── Assets.xcassets           <- App icons, colors, brand logos
        └── Info.plist                <- Hardware permissions (Microphone, Audio)
```

---

## 7. Adding Required Swift Packages (SPM)

Instead of `npm install`, Xcode uses Swift Package Manager:

### 7.1 How to Add a Swift Package
1. In Xcode, click **File → Add Package Dependencies...**.
2. In the search box in the upper right corner, paste the GitHub URL of the library:
   * **KeychainAccess:** `https://github.com/kishikawakatsumi/KeychainAccess.git` (Dependency Rule: Up to Next Major Version).
   * **Sentry-Cocoa:** `https://github.com/getsentry/sentry-cocoa.git` (Dependency Rule: Up to Next Major Version).
3. Click **Add Package**.
4. In the confirmation dialog, ensure the package is added to the `SpeakIT` target, then click **Finish**.

---

## 8. Hardware Capabilities & Permissions Setup

Because SpeakIT records audio (for STT) and plays audio (for TTS) in the background:

### 8.1 Enable Background Audio Playback
1. Click the top-level **SpeakIT** blue project icon in the Project Navigator (`Cmd + 1`).
2. In the center pane, select the **SpeakIT** target under **TARGETS**.
3. Click the **Signing & Capabilities** tab at the top.
4. Click the **+ Capability** button (top left of the tab).
5. Search for and double-click **Background Modes**.
6. In the Background Modes checklist, check:
   * ✅ **Audio, AirPlay, and Picture in Picture**  
   *(This allows synthesized voice playback to continue when the iPhone screen is locked).*

### 8.2 Microphone Permission in `Info.plist`
Apple requires a descriptive explanation why the app accesses the microphone:
1. Select the **Info** tab in target settings (or open `Info.plist`).
2. Hover over any row and click the **+** button.
3. Select or enter:  
   `Privacy - Microphone Usage Description` (`NSMicrophoneUsageDescription`).
4. Set its Value to:  
   `"SpeakIT requires microphone access to record audio for speech-to-text transcription."`

---

## 9. First Run: Building Directly to Your iPhone

1. In the top toolbar scheme selector, click next to **SpeakIT >** and select your **Physical iPhone** under the iOS Devices section (do not select a simulator).
2. Press `Cmd + R` (or click the **Play** button).
3. Xcode will compile the Swift code, sign the binary with your free personal certificate, and transfer the app to your iPhone.
4. **First-Time Security Alert on your iPhone:**  
   If an alert appears stating *"Untrusted Developer"* or *"Developer App Not Trusted"*:
   * On your iPhone, open **Settings → General → VPN & Device Management**.
   * Under Developer App, tap your Apple ID email.
   * Tap **Trust "[Your Name/Email]"** → tap **Trust** again.
5. Tap the SpeakIT icon on your iPhone home screen — the app launches!

---

## 10. Troubleshooting Common Xcode Pitfalls

### 1. "Failed to register bundle identifier / No profiles for 'com.speakit.SpeakIT' were found"
* **Cause:** Bundle Identifiers must be globally unique across all Apple developers. `com.speakit.SpeakIT` might already be reserved by another developer.
* **Fix:** Change the Bundle Identifier in Target Settings → General → Identity to something unique (e.g., `com.mohitur.speakit`).

### 2. "Could not connect to the server (Network error)"
* **Cause:** Your iPhone app is trying to connect to `http://localhost:8080`. On a physical iPhone, `localhost` points to the phone itself, not your Mac!
* **Fix:** In `AppEnvironment.swift`, use your Mac's local network IP (e.g. `http://192.168.1.15:8080`) or your deployed backend URL (Render / Coolify). Find your Mac's IP with:
  ```bash
  ipconfig getifaddr en0
  ```

### 3. "Clean Build Folder" Remedy
* Whenever Xcode acts erratically, shows phantom errors that won't go away after fixing the code, or fails a build mysteriously:
  * Press `Cmd + Shift + K` (Clean Build Folder).
  * Then press `Cmd + B` (Rebuild).

---

## 11. Maintenance Rule & Living Document Status

Whenever any new capability, certificate, scheme, build configuration, or native dependency is added during the `ios-migration` track:
1. Update this document immediately under the corresponding section.
2. Keep step-by-step instructions granular so any team member can configure a fresh Mac from scratch.
