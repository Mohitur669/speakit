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
| `localhost:8080` | **`http://localhost:8080` (Simulator) vs. LAN IP (Physical)** | **Crucial Difference:**<br>• On **iOS Simulator**, `http://localhost:8080` works directly because it shares your Mac's network.<br>• On **Physical iPhone**, `localhost` refers to the phone itself — you must use your Mac's LAN IP (`http://192.168.x.x:8080`) or deployed URL. |
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

## 5. Mastering the iOS Simulator (Fast Development Loop)

For everyday UI building, SwiftUI rapid prototyping, and API testing, the **iOS Simulator** is significantly faster than constantly tethering a physical iPhone. It boots in seconds, runs natively on your Mac's Apple Silicon/Intel hardware, and requires zero provisioning profiles or Apple ID team logins.

### 5.1 Simulator vs. Physical iPhone Comparison Matrix

| Feature / Capability | iOS Simulator | Physical iPhone | Recommendation for SpeakIT |
|---|---|---|---|
| **Development Setup** | Zero setup. Instantly boots on Mac. | Requires USB cable, Developer Mode, Apple ID Personal Team, and trust certificates. | Use Simulator for 85% of feature development; use device for milestone hardware verification. |
| **Backend API URL** | **`http://localhost:8080`** works directly! (Shares Mac network stack). | **Cannot use `localhost`** (Points to iPhone). Must use Mac's LAN IP or deployed URL. | Simulator eliminates LAN IP reconfiguration during local backend debugging. |
| **Microphone / Audio Input (STT)** | Routes your Mac's physical microphone or external USB mic. | Uses built-in iPhone microphones with hardware beamforming. | Simulator is great for basic STT; use device for real-world acoustic testing. |
| **Audio Playback (TTS)** | Outputs to Mac speakers or connected headphones. | Native iPhone stereo speakers, Bluetooth AirPods, EarPods. | Simulator works well; use device to verify audio route changes (e.g. plugging in headphones). |
| **Lock Screen Audio Controls** | Supported via `Cmd + L` (Simulated lock screen). | Full hardware lock screen and Dynamic Island integration (`MPNowPlayingInfoCenter`). | Use device for fine-tuning lock-screen scrubber responsiveness. |
| **In-App Purchases (StoreKit 2)** | Fully testable **offline and free** via local Xcode `.storekit` configuration files. | Requires Apple Developer Program sandbox tester account and App Store Connect configuration. | Test subscription purchasing logic on Simulator first with `.storekit` files. |
| **Screen Sizes & Appearance** | Switch between iPhone SE (3rd gen), iPhone 16, and iPhone 16 Pro Max in 1 click. Instant Dark/Light mode (`Cmd + Shift + A`). | Fixed to your single physical device's screen dimension. | Simulator is superior for responsive layout testing across various notch/Dynamic Island styles. |

---

### 5.2 Managing Simulator Runtimes

#### Installing iOS Runtimes via Xcode
If Xcode did not install the iOS 17 or iOS 18 runtime by default:
1. Open **Xcode → Settings...** (`Cmd + ,`).
2. Click the **Platforms** tab at the top.
3. If iOS is missing or marked "Not Installed", click the **Get** button next to **iOS 17.x** or **iOS 18.x**.
4. Once downloaded, Xcode creates default simulators for the latest iPhone models automatically.

#### Command-Line Management (`xcrun simctl`)
You can control simulators directly from your Mac terminal without even launching Xcode:
```bash
# List all available simulators and their current state (Booted vs Shutdown)
xcrun simctl list devices

# Open the Simulator application standalone
open -a Simulator

# Boot a specific device by name
xcrun simctl boot "iPhone 16 Pro"

# Shut down all active simulators to free Mac memory
xcrun simctl shutdown all

# Factory reset / clear all app caches and Keychain data from all simulators
xcrun simctl erase all
```

---

### 5.3 Essential Simulator Keyboard Shortcuts

When the Simulator window is focused, use these standard macOS shortcuts:

| Shortcut | Simulator Action | Why it's useful for SpeakIT |
|---|---|---|
| `Cmd + Shift + H` | **Home Button** | Minimizes app to Home Screen. Double-tap opens App Switcher. |
| `Cmd + L` | **Lock / Unlock Screen** | **Critical for TTS:** Verifies audio playback continues when device is locked (`UIBackgroundModes: audio`). |
| `Cmd + Shift + A` | **Toggle Dark / Light Appearance** | Instantly verifies SpeakIT's dark-mode and light-mode SwiftUI styles. |
| `Cmd + K` | **Toggle Software Keyboard** | Shows/hides the on-screen keyboard when typing in text fields. |
| `Cmd + S` | **Save Screenshot** | Saves a pixel-perfect screenshot directly to your Mac Desktop. |
| `Cmd + Left` / `Cmd + Right` | **Rotate Device** | Tests landscape and portrait SwiftUI layout adaptations. |
| `Ctrl + Cmd + Z` | **Shake Device** | Triggers undo prompts or feedback gestures. |

---

### 5.4 SpeakIT-Specific Testing on the Simulator

#### A. Microphone Access & STT Audio Input
By default, the iOS Simulator routes your Mac's default microphone into the simulated app:
1. Launch your app in the Simulator.
2. When SpeakIT requests microphone permission for Speech-to-Text (`POST /api/stt/transcribe-live`), tap **OK** on the simulated prompt.
3. macOS will then display a system prompt asking: *"Simulator would like to access the microphone"*. Click **Allow**.
4. To choose which physical microphone the Simulator uses (e.g. Mac Built-in Mic vs. USB Studio Mic), go to the Mac top menu bar:
   **I/O → Audio Input → [Select Microphone]**.

#### B. Testing Background Audio Playback & Lock-Screen Transport Controls
One of SpeakIT's primary requirements is uninterrupted voice synthesis playback when the phone locks:
1. Start playing a synthesized audio track in SpeakIT.
2. Press **`Cmd + L`** to lock the simulated iPhone.
3. The audio must continue playing smoothly through your Mac speakers.
4. Press the simulated lock-screen Power button to view the lock screen — verify the lock-screen player widget displays the active voice name and playback progress.

#### C. Simulating Incoming Audio Interruptions
SpeakIT's `AudioPlayerService` must gracefully pause when an interruption occurs (e.g., an incoming phone call) and resume or stay paused cleanly:
1. While audio is playing, in the Simulator menu bar click **Features → In-Call Status Bar** (or trigger a simulated call via `xcrun simctl openurl booted tel://1234567890`).
2. Verify audio pauses cleanly and does not crash the `AVAudioSession`.

#### D. Testing StoreKit 2 Subscriptions Locally (Free & Offline)
Apple allows you to test in-app subscriptions (`PRO`, `PRO_PLUS`) completely inside Xcode without connecting to App Store servers:
1. In Xcode, select **File → New → File...** (`Cmd + N`).
2. Search for and select **StoreKit Configuration File**. Click **Next**.
3. Name it `SpeakITSubscriptions.storekit` and ensure *"Sync this file with an App Store Connect app"* is **unchecked**.
4. Add Auto-Renewable Subscriptions matching SpeakIT's product IDs:
   * `com.speakit.subscription.pro.monthly`
   * `com.speakit.subscription.proplus.monthly`
   * `com.speakit.subscription.enterprise.monthly`
5. In Xcode's top toolbar, click **Product → Scheme → Edit Scheme...** (`Cmd + <`).
6. Select **Run** in the left sidebar, click the **Options** tab, and set **StoreKit Configuration** to `SpeakITSubscriptions.storekit`.
7. When you run the app on the Simulator, subscription purchase buttons will pop up local Apple test sheets and issue valid mock signed JWS transaction tokens for your testing!

---

## 6. Step-by-Step: Creating the SpeakIT iOS Project

When creating the native iOS application within this repository:

### Step 6.1: Create Project Scaffolding
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

## 7. Target Project Folder Structure

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

## 8. Adding Required Swift Packages (SPM)

Instead of `npm install`, Xcode uses Swift Package Manager:

### 8.1 How to Add a Swift Package
1. In Xcode, click **File → Add Package Dependencies...**.
2. In the search box in the upper right corner, paste the GitHub URL of the library:
   * **KeychainAccess:** `https://github.com/kishikawakatsumi/KeychainAccess.git` (Dependency Rule: Up to Next Major Version).
   * **Sentry-Cocoa:** `https://github.com/getsentry/sentry-cocoa.git` (Dependency Rule: Up to Next Major Version).
3. Click **Add Package**.
4. In the confirmation dialog, ensure the package is added to the `SpeakIT` target, then click **Finish**.

---

## 9. Hardware Capabilities & Permissions Setup

Because SpeakIT records audio (for STT) and plays audio (for TTS) in the background:

### 9.1 Enable Background Audio Playback
1. Click the top-level **SpeakIT** blue project icon in the Project Navigator (`Cmd + 1`).
2. In the center pane, select the **SpeakIT** target under **TARGETS**.
3. Click the **Signing & Capabilities** tab at the top.
4. Click the **+ Capability** button (top left of the tab).
5. Search for and double-click **Background Modes**.
6. In the Background Modes checklist, check:
   * ✅ **Audio, AirPlay, and Picture in Picture**  
   *(This allows synthesized voice playback to continue when the iPhone screen is locked).*

### 9.2 Microphone Permission in `Info.plist`
Apple requires a descriptive explanation why the app accesses the microphone:
1. Select the **Info** tab in target settings (or open `Info.plist`).
2. Hover over any row and click the **+** button.
3. Select or enter:  
   `Privacy - Microphone Usage Description` (`NSMicrophoneUsageDescription`).
4. Set its Value to:  
   `"SpeakIT requires microphone access to record audio for speech-to-text transcription."`

---

## 10. Running Your App: Simulator vs. Physical iPhone

### 10.1 Running on the iOS Simulator (Fast Development Loop)
1. In the Xcode top toolbar destination selector (next to the Play button), click the current device and choose any Simulator (e.g. **iPhone 16 Pro** under the iOS Simulators section).
2. Press **`Cmd + R`** (or click the **Play** button).
3. Xcode builds the app, launches the Simulator window automatically, and attaches the debugger.
4. The app can connect directly to your local Spring Boot backend at `http://localhost:8080`.

### 10.2 Running Directly on Your Physical iPhone (Hardware Validation)
1. Connect your physical iPhone to your Mac via USB cable (ensure Developer Mode is enabled per Section 4).
2. In the top toolbar scheme selector, click next to **SpeakIT >** and select your **Physical iPhone** under the iOS Devices section.
3. Press **`Cmd + R`**.
4. Xcode compiles the Swift code, signs the binary with your free personal certificate, and transfers the app to your iPhone.
5. **First-Time Security Alert on your iPhone:**  
   If an alert appears stating *"Untrusted Developer"* or *"Developer App Not Trusted"*:
   * On your iPhone, open **Settings → General → VPN & Device Management**.
   * Under Developer App, tap your Apple ID email.
   * Tap **Trust "[Your Name/Email]"** → tap **Trust** again.
6. Tap the SpeakIT icon on your iPhone home screen — the app launches!

---

## 11. Troubleshooting Common Xcode & Simulator Pitfalls

### 1. "Failed to register bundle identifier / No profiles for 'com.speakit.SpeakIT' were found"
* **Cause:** Bundle Identifiers must be globally unique across all Apple developers. `com.speakit.SpeakIT` might already be reserved by another developer.
* **Fix:** Change the Bundle Identifier in Target Settings → General → Identity to something unique (e.g., `com.mohitur.speakit`).

### 2. "Could not connect to the server (Network error)"
* **On Physical iPhone:**
  * **Cause:** Your iPhone app is trying to connect to `http://localhost:8080`. On a physical iPhone, `localhost` points to the phone itself, not your Mac!
  * **Fix:** In `AppEnvironment.swift`, use your Mac's local network IP (e.g. `http://192.168.1.15:8080`) or your deployed backend URL. Find your Mac's IP with:
    ```bash
    ipconfig getifaddr en0
    ```
* **On Simulator:**
  * **Cause:** Your Spring Boot backend is not running on port 8080 or is bound strictly to `127.0.0.1` instead of `0.0.0.0`.
  * **Fix:** Ensure `./mvnw spring-boot:run` is active and reachable via `curl http://localhost:8080/api/auth/ping`.

### 3. "Microphone Access Denied on Simulator"
* **Cause:** macOS blocked the Simulator app from accessing the Mac's physical microphone.
* **Fix:** On your Mac, open **System Settings → Privacy & Security → Microphone**, and ensure the toggle next to **Simulator** is switched to **ON**.

### 4. "Simulator Glitch / Stuck Cache / Phantom Keychain Data"
* **Cause:** Simulators retain Keychain tokens and app data between builds, which can lead to stale JWT sessions.
* **Fix:** In the Simulator top menu bar, click **Device → Erase All Content and Settings...**, or run from your Mac terminal:
  ```bash
  xcrun simctl erase all
  ```

### 5. "Clean Build Folder" Remedy
* Whenever Xcode acts erratically, shows phantom errors that won't go away after fixing the code, or fails a build mysteriously:
  * Press **`Cmd + Shift + K`** (Clean Build Folder).
  * Then press **`Cmd + B`** (Rebuild).

---

## 12. Maintenance Rule & Living Document Status

Whenever any new capability, certificate, scheme, build configuration, or native dependency is added during the `ios-migration` track:
1. Update this document immediately under the corresponding section.
2. Keep step-by-step instructions granular so any team member can configure a fresh Mac from scratch.

