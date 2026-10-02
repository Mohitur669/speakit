# SpeakIT — ElevenLabs & Sarvam AI API Capabilities & Live Feature Blueprint

**Document Version:** 1.1.0  
**File Location:** `docs/ios-migration/ai-provider-capabilities-and-live-feature.md`  
**Status:** Research & Feature Planning — Active Engineering Reference  
**Last Updated:** October 2026 — v1.1: Added Section 10 — Combined Maximum Power (complete API catalogue + all integration opportunities)  

---

## Table of Contents

1. [Overview & Document Purpose](#1-overview--document-purpose)
2. [ElevenLabs API — Full Capabilities Breakdown](#2-elevenlabs-api--full-capabilities-breakdown)
   - [Text-to-Speech: Models & Modes](#21-text-to-speech-models--modes)
   - [WebSocket Streaming TTS](#22-websocket-streaming-tts)
   - [Conversational AI (ElevenAgents)](#23-conversational-ai-elevenagents)
   - [Voice Cloning (IVC & PVC)](#24-voice-cloning-ivc--pvc)
   - [Cross-Language Voice Consistency](#25-cross-language-voice-consistency)
   - [iOS Swift Integration Path](#26-ios-swift-integration-path)
   - [Security: API Key Protection](#27-security-api-key-protection)
3. [Sarvam AI API — Full Capabilities Breakdown](#3-sarvam-ai-api--full-capabilities-breakdown)
   - [Saaras STT — Models & Versions](#31-saaras-stt--models--versions)
   - [Live WebSocket Streaming STT](#32-live-websocket-streaming-stt)
   - [Output Modes: Transcribe / Translate / Codemix / Translit](#33-output-modes-transcribe--translate--codemix--translit)
   - [Bulbul TTS — Indic Voice Synthesis](#34-bulbul-tts--indic-voice-synthesis)
   - [Translation API (Sarvam-Translate)](#35-translation-api-sarvam-translate)
   - [Speaker Diarization](#36-speaker-diarization)
   - [iOS Swift Integration Path](#37-ios-swift-integration-path)
4. [Feature Catalogue — What Can Be Built](#4-feature-catalogue--what-can-be-built)
   - [Feature Matrix: Provider × Capability](#41-feature-matrix-provider--capability)
   - [Tier 1: Immediate / Low Effort](#42-tier-1-immediate--low-effort)
   - [Tier 2: Medium Effort — High Value](#43-tier-2-medium-effort--high-value)
   - [Tier 3: Advanced / Flagship Features](#44-tier-3-advanced--flagship-features)
5. [Live Voice Feature — Architecture Blueprint](#5-live-voice-feature--architecture-blueprint)
   - [What "Live" Means in SpeakIT Context](#51-what-live-means-in-speakit-context)
   - [Live Mode A: Real-Time Transcription (STT → Text Display)](#52-live-mode-a-real-time-transcription-stt--text-display)
   - [Live Mode B: Live Transcription + Translation (STT → Translate → Display)](#53-live-mode-b-live-transcription--translation-stt--translate--display)
   - [Live Mode C: Full Live Voice Bridge (STT → Translate → TTS — Different Voice)](#54-live-mode-c-full-live-voice-bridge-stt--translate--tts--different-voice)
   - [Data Flow Diagram](#55-data-flow-diagram)
   - [iOS Audio Stack](#56-ios-audio-stack)
   - [Spring Boot Backend Role in Live Mode](#57-spring-boot-backend-role-in-live-mode)
   - [Latency Budget Analysis](#58-latency-budget-analysis)
6. [Plan Gating — Which Live Features Per Tier](#6-plan-gating--which-live-features-per-tier)
7. [Implementation Roadmap](#7-implementation-roadmap)
8. [Cost Implications of Live Features](#8-cost-implications-of-live-features)
9. [Risks & Mitigations](#9-risks--mitigations)
10. [**Combined Maximum Power — Full API Catalogue & Opportunity Map**](#10-combined-maximum-power--full-api-catalogue--opportunity-map)
    - [Complete ElevenLabs API Surface](#101-complete-elevenlabs-api-surface)
    - [Complete Sarvam AI API Surface](#102-complete-sarvam-ai-api-surface)
    - [The Combined Opportunity Matrix (25 Features)](#103-the-combined-opportunity-matrix)
    - [Flagship Combined Experiences (7 Product Experiences)](#104-flagship-combined-experiences)
    - [SpeakIT Product Roadmap: 6-Phase Build Plan](#105-speakit-product-roadmap-what-to-build--when)

---

## 1. Overview & Document Purpose

This document is the **authoritative engineering reference** for understanding the full scope of AI capabilities available from **ElevenLabs** and **Sarvam AI** — and how they can be applied to build powerful new features in SpeakIT, with a primary focus on the **Live Voice Feature**: a continuous, real-time pipeline that listens to a user's voice, transcribes it, optionally translates it, and re-synthesises it in a chosen target voice (from ElevenLabs or Sarvam).

This is not a tutorial — it is a **decision-making document** for feature prioritisation, plan gating, and engineering sprint planning.

---

## 2. ElevenLabs API — Full Capabilities Breakdown

### 2.1 Text-to-Speech: Models & Modes

ElevenLabs operates on a character-credit billing model. The current flagship models as of 2026:

| Model | ID | Cost/1k chars | Latency | Best For |
|---|---|---|---|---|
| **Eleven Flash v2.5** | `eleven_flash_v2_5` | $0.05 | ~75ms | Live TTS, conversational, streaming |
| **Eleven Turbo v2.5** | `eleven_turbo_v2_5` | $0.05 | ~150ms | Default studio synthesis |
| **Eleven v4 Turbo** | `eleven_v4_turbo` | $0.05–$0.08 | ~100ms | Voice agents, emotional range |
| **Eleven Multilingual v2** | `eleven_multilingual_v2` | $0.15–$0.30 | ~350ms | 90+ language, studio quality |

> [!IMPORTANT]
> **Default to `eleven_flash_v2_5` for all streaming/live use cases.** It delivers ~75ms first-byte latency at the same price as Turbo — this is critical for live voice bridge experiences to feel natural.

**Available Output Formats:**
- `mp3_44100_128` — standard playback
- `pcm_16000` / `pcm_22050` / `pcm_44100` — raw PCM for real-time playback via `AVAudioEngine`
- `ulaw_8000` — telephony (for call center use cases)

**Voice Library:**
- 3,000+ pre-built voices (English, Spanish, French, German, Hindi, etc.)
- Voices are indexed by gender, age, accent, and use case
- Sharable community voice library (Voice Design)

---

### 2.2 WebSocket Streaming TTS

ElevenLabs supports a persistent **WebSocket connection** for streaming TTS — critical for the live voice bridge feature.

**Endpoint:**
```
wss://api.elevenlabs.io/v1/text-to-speech/{voice_id}/stream-input?model_id=eleven_flash_v2_5&output_format=pcm_16000
```

**Protocol flow:**
```
iOS Client                          ElevenLabs WebSocket
    |                                       |
    |--- CONNECT (with xi-api-key header) ->|
    |                                       |
    |--- TEXT CHUNK (JSON):                 |
    |    { "text": "Hello world",           |
    |      "try_trigger_generation": true } |
    |                                       |
    |<-- BINARY AUDIO (PCM/MP3 chunk) ------|
    |<-- BINARY AUDIO (PCM/MP3 chunk) ------|
    |                                       |
    |--- TEXT CHUNK (JSON):                 |
    |    { "text": " and welcome..." }      |
    |                                       |
    |<-- BINARY AUDIO (PCM/MP3 chunk) ------|
    |--- FLUSH: { "text": "" }              |
    |<-- [end of stream] -------------------|
```

**Key parameters:**
- `xi-api-key`: Authentication header
- `model_id`: Model to use (default `eleven_flash_v2_5`)
- `output_format`: Audio format (`pcm_16000` is best for AVAudioEngine)
- `optimize_streaming_latency`: 0–4 (higher = faster first chunk, slightly lower quality)

**iOS Implementation using `URLSessionWebSocketTask`:**
```swift
// Establish connection
let url = URL(string: "wss://api.elevenlabs.io/v1/text-to-speech/\(voiceId)/stream-input?model_id=eleven_flash_v2_5&output_format=pcm_16000")!
var request = URLRequest(url: url)
request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
let wsTask = URLSession.shared.webSocketTask(with: request)
wsTask.resume()

// Send text chunk
let payload = ["text": "Hello, how are you?", "try_trigger_generation": true] as [String: Any]
let data = try JSONSerialization.data(withJSONObject: payload)
wsTask.send(.string(String(data: data, encoding: .utf8)!)) { error in ... }

// Receive PCM chunks → AVAudioEngine buffer
wsTask.receive { result in
    if case .data(let audioData) = try? result.get() {
        // pipe audioData into AVAudioPlayerNode
    }
}
```

---

### 2.3 Conversational AI (ElevenAgents)

ElevenLabs provides a higher-level **ElevenAgents SDK** for building interactive voice agents. This is built on LiveKit WebRTC (not raw WebSockets) and provides:

- **Native Swift SDK:** `https://github.com/elevenlabs/elevenlabs-swift-sdk`
- Bidirectional voice (mic input → STT → LLM → TTS output) in a single session
- Built-in VAD (Voice Activity Detection), echo cancellation, background noise removal
- Interruption handling (user can speak over the agent mid-sentence)
- Support for GPT-4, Claude, Gemini as the underlying LLM
- Knowledge base grounding (attach custom documents)
- Guardrails / content moderation

> [!NOTE]
> ElevenAgents is a **full conversational AI stack** — it includes STT, LLM, and TTS together. For SpeakIT's Live Voice Bridge (STT → Translate → TTS), you would use ElevenLabs **only for the TTS output side** (streaming the synthesised voice back to the user), while Sarvam handles the STT + translation input side.

**Quick Start (if building a full ElevenLabs agent):**
```swift
import ElevenLabs

let conversation = try await ElevenLabs.startConversation(agentId: "your-agent-id")
```

---

### 2.4 Voice Cloning (IVC & PVC)

| Type | Description | Audio Required | Use Case |
|---|---|---|---|
| **Instant Voice Cloning (IVC)** | Clone from 1–60 second sample. Fast, good quality. | ~5 seconds minimum | User profile voice, personalisation |
| **Professional Voice Cloning (PVC)** | Fine-tuned dedicated model from 30+ minutes of clean audio. Near-indistinguishable. | 30+ minutes | Enterprise brand voice, narrator IP |

**API endpoint (IVC):**
```
POST https://api.elevenlabs.io/v1/voices/add
Content-Type: multipart/form-data

files: [audio sample .mp3/.wav]
name: "My Cloned Voice"
```

**Key detail:** IVC clones are stored in your ElevenLabs account and can be used as a `voice_id` in any TTS call. Cross-language consistency is preserved — the clone speaks other languages without carrying the original accent.

**Plan gating suggestion for SpeakIT:** Voice Cloning → **Pro Plus** or **Enterprise** only.

---

### 2.5 Cross-Language Voice Consistency

Using Eleven v4 / Multilingual v2 models, a voice clone (or a library voice) can speak:
- 90+ languages without accent bleed from the training language
- Real-time automatic language detection (no manual language parameter needed)
- Emotional range preserved across languages (excitement, sadness, calm)

This is the key enabler for the **Live Voice Bridge**: a user speaks Hindi, Sarvam transcribes and translates it to English, and ElevenLabs speaks the English back in any chosen voice — with natural prosody.

---

### 2.6 iOS Swift Integration Path

**Recommended stack for ElevenLabs in SpeakIT iOS:**

| Use Case | Approach |
|---|---|
| Standard TTS (current) | REST `POST /v1/text-to-speech/{voice_id}` → MP3 download |
| Live TTS streaming | WebSocket `wss://...stream-input` → PCM → `AVAudioEngine` |
| Voice cloning (future) | REST `POST /v1/voices/add` (multipart) |
| Full conversational agent | ElevenLabs Swift SDK (LiveKit/WebRTC) |

**Required iOS permissions (`Info.plist`):**
```xml
<key>NSMicrophoneUsageDescription</key>
<string>SpeakIT uses your microphone for live voice transcription and translation.</string>
```

**Required Swift packages:**
- No package required for REST/WebSocket TTS
- `https://github.com/elevenlabs/elevenlabs-swift-sdk` for conversational agents

---

### 2.7 Security: API Key Protection

> [!CAUTION]
> **Never embed your ElevenLabs API key in the iOS app binary.** It will be extracted from the IPA.

**Production-safe pattern (already used in SpeakIT):**
1. iOS app calls SpeakIT backend (`/api/tts/synthesize`) with JWT auth
2. Spring Boot backend calls ElevenLabs with the server-side API key
3. Audio is streamed back to iOS via the backend

**For live WebSocket streaming:** Backend acts as a WebSocket proxy — iOS connects to SpeakIT backend WebSocket, backend relays to ElevenLabs WebSocket. The API key never leaves the server.

---

## 3. Sarvam AI API — Full Capabilities Breakdown

### 3.1 Saaras STT — Models & Versions

> [!IMPORTANT]
> **Saarika v2.5 is deprecated.** The current flagship model family is **Saaras v4**. Update any existing references in backend code.

| Model | Use Case | Notes |
|---|---|---|
| `saaras:v4` | Batch file transcription, highest accuracy | Not real-time |
| `saaras:v3-realtime` | Live WebSocket streaming STT | Recommended for Live feature |
| `saaras:v3` | Batch + moderate latency | Good for Pro file uploads |

**Supported Languages (22+ Indian + English):**
`hi-IN` (Hindi), `ta-IN` (Tamil), `te-IN` (Telugu), `bn-IN` (Bengali), `mr-IN` (Marathi), `gu-IN` (Gujarati), `kn-IN` (Kannada), `ml-IN` (Malayalam), `pa-IN` (Punjabi), `or-IN` (Odia), `as-IN` (Assamese), `ur-IN` (Urdu), `en-IN` (Indian English), + more.

Use `language_code: "auto"` for automatic language detection during live sessions.

---

### 3.2 Live WebSocket Streaming STT

**Endpoint:**
```
wss://api.sarvam.ai/speech-to-text-realtime/ws
```

**Authentication header:**
```
Api-Subscription-Key: <your-sarvam-api-key>
```

**Connection payload (JSON, sent first):**
```json
{
  "model": "saaras:v3-realtime",
  "language_code": "auto",
  "mode": "translate",
  "vad": {
    "threshold": 0.5,
    "silence_duration_ms": 400,
    "min_speech_duration_ms": 100
  }
}
```

**Audio stream format:**
- Sample rate: `16000 Hz`
- Channels: Mono (1)
- Encoding: PCM 16-bit little-endian
- Chunk size: 50–256ms recommended (800–4096 bytes)

**Response events:**
```json
{ "type": "transcript.partial", "text": "Hello" }
{ "type": "transcript.partial", "text": "Hello world" }
{ "type": "transcript.final",   "text": "Hello world, how are you." }
```

**VAD (Voice Activity Detection) built-in:**
- `threshold`: Sensitivity (0.0–1.0). Use `0.5` as default.
- `silence_duration_ms`: How long silence before turn ends (300–600ms recommended).
- `min_speech_duration_ms`: Minimum speech to trigger transcription.

> [!TIP]
> Use `transcript.partial` events to update the live caption display in real-time (streamed text), and `transcript.final` for committing the translated/synthesised output.

---

### 3.3 Output Modes: Transcribe / Translate / Codemix / Translit

| Mode | Description | Output | Use Case in SpeakIT |
|---|---|---|---|
| `transcribe` | Native script output | "नमस्ते दुनिया" | Live captions in original language |
| `translate` | Direct speech → English | "Hello world" | Live English translation of Indian speech |
| `codemix` | Handles Hinglish / code-mixed naturally | Mixed | Most natural for urban Indian speakers |
| `translit` | Romanized script (Devanagari → Latin) | "Namaste Duniya" | Display Indian text on non-Indic keyboards |
| `verbatim` | Exact words including fillers ("um", "uh") | Verbatim | Transcription accuracy use cases |

**For the Live Voice Bridge:** Use `translate` mode → output is clean English → feed directly to ElevenLabs TTS in the target voice.

---

### 3.4 Bulbul TTS — Indic Voice Synthesis

**Endpoint:**
```
POST https://api.sarvam.ai/text-to-speech
```

**Request:**
```json
{
  "inputs": ["नमस्ते, मेरा नाम सीता है"],
  "target_language_code": "hi-IN",
  "speaker": "ritu",
  "pitch": 0,
  "pace": 1.0,
  "loudness": 1.0,
  "speech_sample_rate": 22050,
  "enable_preprocessing": true,
  "model": "bulbul:v3"
}
```

**Available voices (37 official bulbul:v3 speakers):**
- Female: `ritu`, `priya`, `neha`, `pooja`, `simran`, `kavya`, `ishita`, `shreya`, `roopa`, `tanya`, `shruti`, `suhani`, `kavitha`, `rupali`
- Male: `aditya`, `ashutosh`, `rahul`, `rohan`, `amit`, `dev`, `ratan`, `varun`, `manan`, `sumit`, `kabir`, `aayan`, `shubh`, `advait`, `anand`, `tarun`, `sunny`, `mani`, `gokul`, `vijay`, `mohit`, `rehan`, `soham`
- Languages: `hi-IN`, `ta-IN`, `te-IN`, `bn-IN`, `mr-IN`, `gu-IN`, `kn-IN`, `ml-IN`, `pa-IN`, `od-IN`, `en-IN`

**Voice Cloning (Bulbul):**
- Clone a voice from audio sample at same API cost (₹30/10k chars)
- Ideal for regional language brand voices

**Output:** Base64-encoded WAV audio in response body.

---

### 3.5 Translation API (Sarvam-Translate)

For **text-to-text translation** (not STT-based), Sarvam provides a dedicated translation endpoint:

**Endpoint:**
```
POST https://api.sarvam.ai/translate
```

**Request:**
```json
{
  "input": "कल मौसम बहुत अच्छा था",
  "source_language_code": "hi-IN",
  "target_language_code": "en-IN",
  "speaker_gender": "Female",
  "mode": "formal",
  "enable_preprocessing": true,
  "numerals_format": "international"
}
```

**Modes:** `formal`, `colloquial`, `code-mixed`

**Use case in SpeakIT:** After user finishes speaking (final transcript received), translate the full paragraph via REST before synthesising in ElevenLabs — gives better quality than streaming translation for non-live use cases.

---

### 3.6 Speaker Diarization

**Available in batch STT (not real-time):**
```json
{
  "model": "saaras:v4",
  "with_diarization": true,
  "num_speakers": 2
}
```

**Output includes:**
- `speaker_id` per utterance
- Word-level timestamps
- Confidence scores

**Use case:** Meeting transcription feature (Pro Plus / Enterprise) — "Who said what" in a recorded conversation.

---

### 3.7 iOS Swift Integration Path

**Recommended stack for Sarvam in SpeakIT iOS:**

| Use Case | Approach |
|---|---|
| Batch file STT (current) | REST `POST` multipart audio → transcript JSON |
| Live STT streaming | WebSocket `wss://api.sarvam.ai/speech-to-text-realtime/ws` |
| Indic TTS | REST `POST /text-to-speech` → base64 WAV decode → `AVAudioPlayer` |
| Text translation | REST `POST /translate` |

**iOS audio capture for Sarvam live:**
```swift
// AVAudioEngine tap at 16kHz mono PCM
let inputNode = audioEngine.inputNode
let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!

inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, time in
    guard let channelData = buffer.int16ChannelData else { return }
    let data = Data(bytes: channelData[0], count: Int(buffer.frameLength) * 2)
    // Send `data` as binary WebSocket message to Sarvam
    wsTask.send(.data(data)) { _ in }
}
audioEngine.prepare()
try audioEngine.start()
```

---

## 4. Feature Catalogue — What Can Be Built

### 4.1 Feature Matrix: Provider × Capability

| Feature | ElevenLabs | Sarvam AI | AWS Polly | Notes |
|---|---|---|---|---|
| Standard TTS | ✅ Flash/Turbo | ✅ Bulbul v3 | ✅ Neural/Standard | All implemented |
| Streaming TTS (WebSocket) | ✅ ~75ms | ❌ (batch only) | ❌ | ElevenLabs only |
| Live STT (WebSocket) | ❌ | ✅ Saaras v3-realtime | ❌ | Sarvam only |
| Batch File STT | ❌ | ✅ Saaras v4 | ❌ | Implemented |
| Live Transcription Display | ❌ | ✅ partial events | ❌ | New feature |
| Live Translation (Speech → English) | ❌ | ✅ `translate` mode | ❌ | New feature |
| Live Codemix (Hinglish) | ❌ | ✅ `codemix` mode | ❌ | New feature |
| Live Voice Bridge (STT → TTS) | ✅ (TTS side) | ✅ (STT side) | ❌ | Flagship feature |
| Voice Cloning | ✅ IVC/PVC | ✅ Bulbul clone | ❌ | Future |
| Speaker Diarization | ❌ | ✅ Saaras v4 | ❌ | Future (Pro Plus) |
| Transliteration | ❌ | ✅ `translit` mode | ❌ | New feature |
| 90+ Language TTS | ✅ Multilingual v2 | ❌ (Indic only) | ✅ (limited) | Different targets |
| Text Translation | ❌ | ✅ Sarvam-Translate | ❌ | New feature |
| Conversational AI Agent | ✅ ElevenAgents | ❌ | ❌ | Future / Enterprise |
| Emotional Voice Control | ✅ v4 model | ❌ | ❌ | Future |

---

### 4.2 Tier 1: Immediate / Low Effort

These features can be implemented without any new infrastructure — just new API calls to existing providers:

1. **Transliteration Display** — Show romanized text alongside Indic output (Sarvam `translit` mode)  
   *Effort: 1 day. Add `mode: "translit"` to STT response and display alongside transcript.*

2. **Codemix STT Mode** — Better accuracy for Hinglish speakers (most urban Indian users)  
   *Effort: 0.5 day. Add `mode` selector to STT settings screen.*

3. **Text-to-Text Translation** — Type in Hindi, see the English translation before synthesising  
   *Effort: 2 days. New `POST /translate` call on the TTS input screen before synthesis.*

4. **Speaker Gender Selection for Sarvam** — Let user choose `ritu`, `priya`, `aditya`, `rahul`, etc.  
   *Effort: 1 day. Add voice picker for Sarvam voices in the iOS voice selector.*

5. **Upgrade to Saaras v4 for File STT** — Better accuracy for batch uploads  
   *Effort: 0.5 day. Change model ID in backend STT service.*

---

### 4.3 Tier 2: Medium Effort — High Value

6. **Live Transcription Mode** — User speaks, text appears live on screen (Sarvam WebSocket STT)  
   *Effort: 1 week. New LiveTranscriptionService (iOS) + WebSocket proxy endpoint (backend).*

7. **Live Translation Mode** — User speaks in Hindi/Tamil/etc., English text appears live  
   *Effort: 1 week (builds on #6). Pass `mode: "translate"` to Sarvam WebSocket.*

8. **Live Caption Export** — Save the final transcript from a live session as a text file  
   *Effort: 0.5 day (builds on #6). Add export button to Live Transcription view.*

9. **Multi-Language TTS via ElevenLabs Multilingual v2** — Single voice speaks 90+ languages  
   *Effort: 3 days. Model ID parameter + language auto-detection UI.*

10. **Voice Cloning (Instant)** — User records 30 seconds, gets a personalised voice  
    *Effort: 1 week. Audio recording UI + `POST /v1/voices/add` backend call.*

---

### 4.4 Tier 3: Advanced / Flagship Features

11. **Live Voice Bridge** — Full pipeline: Speak Hindi → translate → hear it in any ElevenLabs voice  
    *Effort: 3–4 weeks. See Section 5 for full architecture.*

12. **Multi-Speaker Meeting Transcription** — Diarisation + speaker identification + export  
    *Effort: 2 weeks. Saaras v4 diarization + iOS meeting recording UI.*

13. **Conversational AI Voice Assistant** — Full ElevenAgents integration, SpeakIT as the brand wrapper  
    *Effort: 4–6 weeks. ElevenLabs Swift SDK + knowledge base setup.*

14. **Real-Time Dubbing** — Pre-recorded video → detect speech → replace audio track in different voice  
    *Effort: 6–8 weeks. Complex media pipeline (AVAsset + frame-level sync).*

15. **Professional Voice Cloning (PVC)** — Enterprise-grade brand voice training  
    *Effort: 4 weeks. Guided recording flow + PVC submission + async polling.*

---

## 5. Live Voice Feature — Architecture Blueprint

### 5.1 What "Live" Means in SpeakIT Context

The **Live Voice Bridge** is SpeakIT's flagship differentiator — a feature that:

1. Listens to the user's microphone continuously
2. Transcribes and translates speech in real-time (via Sarvam WebSocket)
3. Synthesises the translated text in a **chosen target voice** (via ElevenLabs WebSocket)
4. Plays the synthesised audio back through the device speaker

The user selects:
- **Source language** (or `auto`): Hindi, Tamil, Telugu, etc.
- **Target voice**: Any ElevenLabs or Sarvam Bulbul voice
- **Output language**: English (or another Indian language for inter-Indic translation)

**Example:** A Tamil speaker selects "Translate & Speak as Aria (ElevenLabs, English Female)". They speak in Tamil — and the app speaks the English translation back to them in Aria's voice, live.

---

### 5.2 Live Mode A: Real-Time Transcription (STT → Text Display)

The simplest live mode. No TTS involved.

```
User speaks → AVAudioEngine (16kHz PCM) → Sarvam WebSocket STT
                                                    ↓
                                        transcript.partial events
                                                    ↓
                                        Live caption UI updates in real-time
                                                    ↓
                                        transcript.final → commit to session log
```

**Plan gate:** Pro (file STT already included; live STT is an upgrade)  
**Quota unit:** Per minute of live audio consumed  
**Backend role:** WebSocket proxy (iOS → Backend → Sarvam) to protect Sarvam API key

---

### 5.3 Live Mode B: Live Transcription + Translation (STT → Translate → Display)

```
User speaks in Hindi/Tamil/etc.
        ↓
AVAudioEngine (16kHz PCM)
        ↓
Sarvam WebSocket (mode: "translate")
        ↓
transcript.partial → "Hello, my name..." (English)
        ↓
Live English text display (updates as user speaks)
        ↓
transcript.final → commit full translated sentence
```

No TTS synthesis in this mode — just text output. This is the **Live Translator** feature (like Google Translate live, but with 22 Indian languages and higher accuracy).

**Plan gate:** Pro Plus  
**Quota unit:** Per minute of live audio

---

### 5.4 Live Mode C: Full Live Voice Bridge (STT → Translate → TTS — Different Voice)

This is the **flagship feature**. The complete pipeline:

```
Phase 1: Capture & Transcribe
    User speaks → AVAudioEngine → Sarvam WebSocket (mode: "translate")
    
Phase 2: Buffer translated text
    transcript.partial → accumulate in sentence buffer
    transcript.final   → trigger synthesis of complete sentence
    
Phase 3: Synthesise in target voice
    Complete sentence → ElevenLabs WebSocket TTS (voice_id = user-selected)
    Audio chunks stream back → AVAudioEngine playback buffer
    
Phase 4: Playback
    AVAudioPlayerNode plays PCM chunks as they arrive
    Next sentence queued as current sentence plays
```

**Key UX detail:** There is an inherent latency between when the user stops speaking a sentence and when the synthesised voice begins playing. The target is **< 800ms end-to-end** (see Section 5.8).

---

### 5.5 Data Flow Diagram

```
iOS App                    SpeakIT Backend              Third-Party APIs
─────────────────────────────────────────────────────────────────────────────
┌─────────────────┐        ┌──────────────────┐         ┌─────────────────┐
│ AVAudioEngine   │──PCM──>│  /ws/live-stt    │──PCM──> │  Sarvam         │
│ (Mic capture)   │        │  (WebSocket      │         │  WebSocket STT  │
│                 │        │   proxy)         │<───────── saaras:v3-rt    │
│  Live caption   │<─text──│                  │ transcript events          │
│  UI updates     │        │                  │                            │
└─────────────────┘        │                  │         └─────────────────┘
                           │  On final event: │
┌─────────────────┐        │  POST translated │         ┌─────────────────┐
│ AVAudioPlayerNode│<─PCM─-│  text to         │──text──>│  ElevenLabs     │
│ (Speaker output)│        │  /ws/live-tts    │         │  WebSocket TTS  │
│                 │        │  (WebSocket      │<─PCM────│  eleven_flash   │
└─────────────────┘        │   proxy)         │  chunks │  _v2_5          │
                           └──────────────────┘         └─────────────────┘
```

**Why proxy through backend?**
- API keys (Sarvam + ElevenLabs) never exposed in iOS binary
- Backend can enforce per-user rate limits and quota deduction
- Backend can log session duration for billing accuracy
- Backend can inject context (user's voice preference, target language)

---

### 5.6 iOS Audio Stack

**Capture (input):**
```
Physical mic
    → AVAudioSession (.playAndRecord, .defaultToSpeaker)
    → AVAudioEngine.inputNode
    → installTap(bufferSize: 1024, format: 16kHz mono PCM Int16)
    → Data chunks → WebSocket.send(.data)
```

**Playback (output):**
```
ElevenLabs PCM chunks received via WebSocket
    → Convert Data → AVAudioPCMBuffer (Float32 from Int16)
    → AVAudioPlayerNode.scheduleBuffer()
    → AVAudioEngine.outputNode
    → Device speaker
```

**Important iOS session setup:**
```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playAndRecord, 
                         mode: .default, 
                         options: [.defaultToSpeaker, .allowBluetooth])
try session.setActive(true)
```

**Bluetooth headset support:** `.allowBluetooth` enables AirPods / BT headsets for both capture and playback simultaneously.

---

### 5.7 Spring Boot Backend Role in Live Mode

The backend acts as an **authenticated WebSocket proxy** with quota enforcement:

```java
@Controller
public class LiveVoiceProxyController {

    // Client (iOS) connects here:
    // wss://api.speakit.com/ws/live-stt?token=JWT
    
    @MessageMapping("/live-stt")
    public void handleSttFrame(BinaryMessage audioFrame, Principal principal) {
        // 1. Validate JWT + deduct from user's live-minute quota
        // 2. Forward PCM bytes to Sarvam WebSocket
        // 3. Forward Sarvam transcript events back to iOS client
    }

    @MessageMapping("/live-tts")  
    public void handleTtsText(TextMessage translatedText, Principal principal) {
        // 1. Validate JWT + deduct character quota
        // 2. Forward text to ElevenLabs WebSocket with user's voice_id preference
        // 3. Stream PCM chunks back to iOS client
    }
}
```

**Technology options for WebSocket proxy in Spring Boot:**
- **Spring WebSocket + STOMP** — native, no extra deps
- **Spring WebFlux** — reactive, better for high-concurrency streaming
- **Virtual Threads (Loom)** — already in place, ideal for I/O proxy work

---

### 5.8 Latency Budget Analysis

Target: **< 800ms** from user stopping speaking to hearing synthesised output.

| Stage | Estimated Latency | Notes |
|---|---|---|
| Audio buffer flush to WebSocket | ~50ms | 50ms chunks |
| Sarvam STT processing (`transcript.final`) | ~100–200ms | After silence detected |
| Network: iOS → Backend → Sarvam | ~30ms | Same region deployment |
| Backend: translate text (if batch REST) | ~150ms | Sarvam REST translate |
| Network: Backend → ElevenLabs WebSocket | ~50ms | |
| ElevenLabs Flash first audio chunk | ~75ms | `eleven_flash_v2_5` |
| Network: ElevenLabs → Backend → iOS | ~30ms | |
| AVAudioEngine buffer playback start | ~20ms | Buffer scheduling overhead |
| **Total (optimistic)** | **~505ms** | ✅ Under 800ms target |
| **Total (pessimistic)** | **~800ms** | ⚠️ At budget limit |

**Optimisations to stay under budget:**
1. Use `transcript.partial` to start TTS synthesis before the sentence is complete (speculative synthesis)
2. Deploy backend in the same AWS region as ElevenLabs (us-east-1)
3. Use `optimize_streaming_latency: 4` on ElevenLabs WebSocket
4. Keep `silence_duration_ms: 300` (shorter turn-end detection)

---

## 6. Plan Gating — Which Live Features Per Tier

| Feature | Free | Pro | Pro Plus | Enterprise |
|---|---|---|---|---|
| Standard TTS (Polly) | ✅ 3k chars/mo | ✅ | ✅ | ✅ |
| Neural TTS (Polly) | ❌ | ✅ 5k chars/mo | ✅ | ✅ |
| Sarvam Indic TTS (Bulbul) | ❌ | ✅ | ✅ | ✅ |
| ElevenLabs TTS | ❌ | ❌ | ✅ 10k chars/mo | ✅ |
| Batch File STT | ❌ | ✅ 15 mins/mo | ✅ 30 mins/mo | ✅ 120 mins/mo |
| **Live Transcription (Mode A)** | ❌ | ✅ 10 mins/mo | ✅ 30 mins/mo | ✅ Unlimited |
| **Live Translation Display (Mode B)** | ❌ | ❌ | ✅ 30 mins/mo | ✅ Unlimited |
| **Live Voice Bridge (Mode C)** | ❌ | ❌ | ✅ 15 mins/mo | ✅ Unlimited |
| Codemix STT | ❌ | ✅ | ✅ | ✅ |
| Transliteration | ❌ | ✅ | ✅ | ✅ |
| Text Translation | ❌ | ✅ | ✅ | ✅ |
| Voice Cloning (IVC) | ❌ | ❌ | ✅ (1 clone) | ✅ (unlimited) |
| Speaker Diarization | ❌ | ❌ | ❌ | ✅ |
| Conversational AI Agent | ❌ | ❌ | ❌ | ✅ |

---

## 7. Implementation Roadmap

```
Sprint 1 (Week 1–2): Foundation
────────────────────────────────
□ Upgrade Saarika → Saaras v4 in backend STT service
□ Add codemix + translit mode selector to iOS STT settings
□ Add Sarvam text translation endpoint to backend
□ Add translation preview on iOS TTS input screen

Sprint 2 (Week 3–4): Live Transcription
────────────────────────────────────────
□ Build SarvamLiveSTTService.swift (WebSocket + AVAudioEngine)
□ Build LiveTranscriptionView.swift (SwiftUI view with real-time text)
□ Build /ws/live-stt WebSocket proxy in Spring Boot
□ Wire quota deduction (per minute) to live STT sessions
□ Add Live Transcription to Pro tier

Sprint 3 (Week 5–6): Live Translation
────────────────────────────────────────
□ Add translate mode to SarvamLiveSTTService
□ Add language selector to LiveTranscriptionView
□ Add session transcript export (text file)
□ Gate behind Pro Plus

Sprint 4 (Week 7–10): Live Voice Bridge
────────────────────────────────────────
□ Build ElevenLabsLiveStreamTTSService.swift (WebSocket TTS + PCM playback)
□ Build /ws/live-tts WebSocket proxy in Spring Boot
□ Wire Sarvam final transcript → ElevenLabs TTS pipeline
□ Build LiveVoiceBridgeView.swift (voice selector + waveform display)
□ Latency tuning (speculative synthesis, buffer management)
□ Gate behind Pro Plus (15 mins/mo)

Sprint 5 (Week 11–12): Voice Cloning
────────────────────────────────────────
□ Build voice recording UI (30-second capture + upload)
□ Backend: POST /api/voice-clone → ElevenLabs /v1/voices/add
□ Store clone voice_id in user profile
□ Gate behind Pro Plus
```

---

## 8. Cost Implications of Live Features

### Live STT Cost (per user, per month — at plan quota)

| Plan | Live Mins Included | Sarvam Cost (₹30/hr) | Cost per User |
|---|---|---|---|
| Pro | 10 mins | 10/60 × ₹30 = ₹5.00 | **₹5.00/user/mo** |
| Pro Plus | 30 mins | 30/60 × ₹30 = ₹15.00 | **₹15.00/user/mo** |
| Enterprise | 120 mins | 120/60 × ₹30 = ₹60.00 | **₹60.00/user/mo** |

### Live Voice Bridge Additional TTS Cost (ElevenLabs)

Assumption: average spoken pace = 130 words/minute = ~780 characters/minute.

| Plan | Live Bridge Mins | ElevenLabs chars | Cost ($0.05/1k) |
|---|---|---|---|
| Pro Plus | 15 mins | 15 × 780 = 11,700 chars | **$0.585/user/mo** |
| Enterprise | Unlimited (cap 120 min) | 93,600 chars | **$4.68/user/mo** |

> [!NOTE]
> These costs are well within margin. Pro Plus at ₹999 ($11.76) — total live feature COGS is **₹15 STT + $0.585 TTS ≈ ₹64.50 (~$0.76)**. Gross margin remains **>93%** even with live features active.

---

## 9. Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| API key exposure in iOS binary | 🔴 Critical | Always proxy through backend — never embed keys in app |
| Sarvam connection billing per session | 🟡 Medium | Backend manages connection lifecycle; close on user pause > 5s |
| ElevenLabs WebSocket disconnects mid-sentence | 🟡 Medium | Implement reconnect with exponential backoff; buffer unsent text |
| AVAudioEngine mic + speaker echo loop | 🟡 Medium | Use `.defaultToSpeaker` + `AVAudioSession.setMode(.videoChat)` for echo suppression |
| Quota abuse (users leaving session open) | 🟡 Medium | Backend enforces hard per-session minute caps; auto-close after plan quota |
| Saarika deprecation breaking existing STT | 🟡 Medium | Migrate to `saaras:v3` (batch) and `saaras:v3-realtime` (live) immediately |
| Latency > 800ms on slow networks | 🟢 Low | Add visual "translating..." indicator; pre-buffer first 500ms of synthesis |
| ElevenLabs Flash not supporting all languages | 🟢 Low | Auto-fall-back to Turbo v2.5 for unsupported language inputs |
| User recording in noisy environments | 🟢 Low | Surface VAD threshold setting in Pro Plus settings |

---

*Document authored by SpeakIT Engineering. Update this file as new API capabilities are released by ElevenLabs or Sarvam AI.*

---

## 10. Combined Maximum Power — Full API Catalogue & Opportunity Map

This section documents **every API capability** available from ElevenLabs and Sarvam AI as of October 2026, and maps them into a full opportunity catalogue of what SpeakIT can build by combining both providers. This is the most complete view of what is technically achievable.

---

### 10.1 Complete ElevenLabs API Surface

#### 🗣️ Text-to-Speech (TTS)
| Capability | API | Notes |
|---|---|---|
| Standard TTS (REST) | `POST /v1/text-to-speech/{voice_id}` | Returns MP3/PCM audio |
| Streaming TTS (SSE) | `POST /v1/text-to-speech/{voice_id}/stream` | Server-Sent Events, progressive playback |
| WebSocket Streaming TTS | `WSS /v1/text-to-speech/{voice_id}/stream-input` | Bidirectional, ultra-low latency |
| Natural language voice direction | Embed in text: `"<excited>Hello!</excited>"` | v4 models only; controls emotion inline |
| SSML-style prosody control | `stability`, `similarity_boost`, `style`, `speed` | Per-request voice tuning |

#### 🎤 Speech-to-Text / Transcription (Scribe)
| Capability | API | Notes |
|---|---|---|
| Transcription (Scribe v2) | `POST /v1/speech-to-text` | 90+ languages, word timestamps |
| Speaker diarization | `diarize: true` | Up to 32 speakers identified |
| Entity detection | `tag_audio_events: true` | 65 entity types (names, orgs, locations) |
| Keyterm prompting | `additional_formats` / `keyterm_prompting` | Improve domain-specific accuracy |
| Medical transcription | `model: scribe_v2_medical` | Clinical HIPAA-grade transcription |
| Word-level timestamps | Default in Scribe v2 output | Precise word-level time alignment |

#### 🔄 Speech-to-Speech (STS) / Voice Changer
| Capability | API | Notes |
|---|---|---|
| Voice transformation (batch) | `POST /v1/speech-to-speech/{voice_id}` | Upload audio → get back in target voice |
| Real-time voice changer (stream) | `POST /v1/speech-to-speech/{voice_id}/stream` | Streaming version |
| Preserve emotion & intonation | Automatic | Original speaker's cadence is preserved in the new voice |
| Use any library or cloned voice | Any `voice_id` | Works with 3,000+ voices or your own clones |

#### 🎭 Voice Cloning
| Capability | API | Notes |
|---|---|---|
| Instant Voice Cloning (IVC) | `POST /v1/voices/add` (multipart audio) | ~5 seconds of audio minimum; usable immediately |
| Professional Voice Cloning (PVC) | Via ElevenLabs Studio UI + API | 30+ min of clean audio; near-indistinguishable |
| Cross-language clone | Any model | Clone speaks 90+ languages without original accent |
| Voice library management | `GET /v1/voices`, `DELETE /v1/voices/{id}` | List, update, delete clones |
| Shared voices (community) | `GET /v1/voices?show_legacy=false` | Access 3,000+ community-shared voices |

#### 🎵 Sound Effects Generation
| Capability | API | Notes |
|---|---|---|
| Text-to-Sound-Effects | `POST /v1/sound-generation` | Natural language → cinematic SFX |
| Duration control | `duration_seconds: 0.5–22` | Precise length control |
| Looping audio | `prompt_influence` tuning | Background loops, ambient textures |
| Types: cinematic, UI, ambient | Free-form prompt | Footsteps, explosions, notifications, nature |

#### 🎬 AI Dubbing & Translation
| Capability | API | Notes |
|---|---|---|
| Full audio/video dubbing | `POST /v1/dubbing` | Translate + re-voice in 90+ languages |
| Voice preservation across languages | Automatic (Dubbing v2) | Same voice identity, different language |
| Lip-sync timing optimization | Automatic | Matches dubbing to original speech rhythm |
| Dubbing status polling | `GET /v1/dubbing/{dubbing_id}` | Async job tracking |
| Get dubbed audio | `GET /v1/dubbing/{dubbing_id}/audio/{language_code}` | Download dubbed track |

#### 🔇 Audio Isolation (Voice Isolator)
| Capability | API | Notes |
|---|---|---|
| Background noise removal | `POST /v1/audio-isolation` | Deep-learning-based, studio quality |
| Input: any audio file | MP3, WAV, FLAC, M4A | Handles field recordings, phone calls |
| Output: clean speech only | Streaming or download | Removes music, wind, traffic, echo |

#### 🎼 Music Generation
| Capability | API | Notes |
|---|---|---|
| Text-to-music | ElevenLabs Creative / API | Full compositions from natural language |
| Instrumental tracks | `instrumental: true` | Background music without vocals |
| Composition plans | Structured JSON prompt | Fine-grained genre/mood/tempo control |

#### 👤 Voice Library & Management
| Capability | API | Notes |
|---|---|---|
| List available voices | `GET /v1/voices` | Filter by gender, age, accent, use case |
| Voice settings | `GET /v1/voices/{id}/settings` | Retrieve default settings |
| Voice design (text prompt) | `POST /v1/voice-generation/generate-voice` | Create new voice from description |
| Projects (long-form) | `POST /v1/projects` | Chapter management for audiobooks |

#### 🏢 Enterprise & Platform
| Capability | Notes |
|---|---|
| SOC 2 / HIPAA / GDPR compliant | Available on enterprise tiers |
| EU Data Residency | Data never leaves EU |
| Zero Retention Mode | No audio stored post-processing |
| Workspace / team management | Shared voices, billing, permissions |
| Multiple revocable API keys | Granular permission scoping |
| Usage analytics | Per-key character consumption tracking |

---

### 10.2 Complete Sarvam AI API Surface

#### 🎤 Speech-to-Text (Saaras)
| Capability | API / Parameter | Notes |
|---|---|---|
| Batch file transcription | `POST /speech-to-text` | Upload audio file, get full transcript |
| Real-time WebSocket STT | `WSS /speech-to-text-realtime/ws` | Live streaming, partial + final events |
| Auto language detection | `language_code: "auto"` | Detects from 22 Indian languages + English |
| Transcription mode | `mode: "transcribe"` | Native script output (Devanagari, Tamil, etc.) |
| Translation mode | `mode: "translate"` | Speech → English text directly |
| Codemix mode | `mode: "codemix"` | Handles Hinglish/code-mixed naturally |
| Transliteration mode | `mode: "translit"` | Indic → Romanized Latin output |
| Verbatim mode | `mode: "verbatim"` | Includes fillers ("um", "uh") |
| Speaker diarization | `with_diarization: true` | Who said what; batch only |
| Word-level timestamps | Default in output | Precise alignment per word |
| VAD (Voice Activity Detection) | `threshold`, `silence_duration_ms` | Real-time session only |
| Built-in noise robustness | Automatic | Handles phone-quality, accent, noise |
| 22+ language support | `hi-IN`, `ta-IN`, `te-IN`, `bn-IN`, etc. | Full Indian language coverage |
| Confidence scores | In output JSON | Per-word accuracy confidence |
| Entity preservation | Automatic | Proper nouns, numbers preserved accurately |

#### 🔊 Text-to-Speech (Bulbul)
| Capability | API / Parameter | Notes |
|---|---|---|
| Indic TTS | `POST /text-to-speech` | 11+ Indian languages, 30+ voices |
| Streaming TTS | Supported | Real-time audio generation |
| Voice selection | `speaker: "ritu"` / `"aditya"` / etc. | 37 male & female voices |
| Pitch control | `pitch: -10 to +10` | Fine-tune voice tone |
| Pace control | `pace: 0.5–2.0` | Speed of speech |
| Loudness control | `loudness: 0.5–2.0` | Volume normalization |
| Preprocessing | `enable_preprocessing: true` | Handles abbreviations, numbers, dates |
| Sample rate | `speech_sample_rate: 8000/16000/22050` | Match target device/telephony |
| Voice cloning | Supported at same price | Clone from audio sample |
| Output format | Base64 WAV in JSON | Decode and play directly |

#### 🌐 Translation (Sarvam-Translate / Mayura)
| Capability | API | Notes |
|---|---|---|
| Text-to-text translation | `POST /translate` | 22 Indian languages ↔ English |
| Inter-Indic translation | Hindi ↔ Tamil, Bengali ↔ Telugu, etc. | No English intermediary |
| Colloquial mode | `mode: "colloquial"` | Natural, informal translation |
| Formal mode | `mode: "formal"` | Professional/official translation |
| Codemix mode | `mode: "code-mixed"` | Handles Hinglish input |
| Gender-aware translation | `speaker_gender: "Male"/"Female"` | Grammatically correct gendered output |
| Number format | `numerals_format: "international"/"native"` | 1,000 vs १,०००  |
| Preprocessing | `enable_preprocessing: true` | Handles domain entities correctly |

#### 📝 Transliteration
| Capability | API | Notes |
|---|---|---|
| Script conversion | `POST /transliterate` | Roman ↔ Devanagari ↔ Tamil script, etc. |
| Bulk transliteration | Batch mode | Multiple strings in one call |
| Numerals | Included | Numbers transliterated in target script |

#### 🤖 LLM (Sarvam-105B / Chat Completion)
| Capability | API | Notes |
|---|---|---|
| Chat completion | `POST /chat/completions` | OpenAI-compatible API format |
| Sarvam-105B (flagship) | MoE, 105B params | Complex reasoning, 128k context |
| Indian language comprehension | Native | No translation intermediary for Indian inputs |
| Agentic reasoning | Function calling supported | Tool use, multi-step reasoning |
| Long-form document analysis | 128k context window | Full document ingestion |

#### 👁️ Document AI (Sarvam Vision)
| Capability | API | Notes |
|---|---|---|
| Document digitization / OCR | `POST /parse` | Handwritten + printed, Indian scripts |
| Table extraction | Structured JSON output | Forms, invoices, bank statements |
| Visual reasoning | Multimodal VLM | Describe/answer questions about images |
| Indian language OCR | Native | No transliteration loss |

#### 🎙️ Voice Agents & Telephony
| Capability | Notes |
|---|---|
| Full voice agent platform | STT + LLM + TTS orchestrated in one system |
| Inbound/Outbound telephony | SIP integration, Airtel/Jio/Exotel compatible |
| WhatsApp deployment | Voice agents on WhatsApp Business |
| Web widget deployment | Embeddable voice widget |
| Call analytics | Duration, intent, sentiment per call |
| Campaign scheduling | Outbound call batch scheduling |
| Regional accent robustness | Handles rural Indian accents reliably |
| Mid-call language switching | Detects and handles in real-time |
| Interruption handling | Natural conversation flow |

---

### 10.3 The Combined Opportunity Matrix

This is the **master map of what becomes possible** when ElevenLabs and Sarvam are used together. Every row is a real product feature SpeakIT can build.

| # | Feature Name | ElevenLabs Role | Sarvam Role | Complexity | Plan Gate |
|---|---|---|---|---|---|
| 1 | **Live Transcription** | — | Saaras v3-realtime (STT) | Medium | Pro |
| 2 | **Live Translation Display** | — | Saaras `translate` mode | Medium | Pro Plus |
| 3 | **Live Voice Bridge** | Flash TTS (output) | Saaras STT + translate | High | Pro Plus |
| 4 | **Indic → Indic Live Bridge** | — | Saaras STT + Bulbul TTS | High | Pro Plus |
| 5 | **Voice Changer Studio** | STS: swap voice post-record | Saaras: clean transcript first | Medium | Pro Plus |
| 6 | **AI Dubbing** | Dubbing v2 (video/audio) | Saaras: source transcript | High | Enterprise |
| 7 | **Podcast/Video Noise Cleaner** | Audio Isolation | — | Low | Pro |
| 8 | **Meeting Transcription** | Scribe v2 (if English meeting) | Saaras + Diarization (Indian) | Medium | Enterprise |
| 9 | **Smart Subtitles / Captions** | Scribe v2 word timestamps | Saaras word timestamps | Medium | Pro Plus |
| 10 | **Voice Clone Creator** | IVC: record & clone | — | Medium | Pro Plus |
| 11 | **Indic Voice Clone** | — | Bulbul clone | Medium | Pro Plus |
| 12 | **Bilingual Voice Clone** | IVC clone speaks EN | Bulbul clone speaks Indian | High | Enterprise |
| 13 | **AI Audiobook Generator** | Projects API long-form | Saaras: input transcript | High | Enterprise |
| 14 | **SFX Layer on Speech** | Sound Effects generation | — | Low | Pro Plus |
| 15 | **Interview Transcription** | Scribe v2 + diarization | Saaras + diarization | Medium | Pro |
| 16 | **Codemix Smart Keyboard** | — | Saaras codemix mode | Low | Pro |
| 17 | **Inter-Indic Text Translator** | — | Sarvam-Translate (22 langs) | Low | Pro |
| 18 | **Document → Speech (OCR + TTS)** | TTS narration | Sarvam Vision OCR + Saaras | High | Enterprise |
| 19 | **Real-Time Medical Transcription** | Scribe v2 Medical | — | High | Enterprise |
| 20 | **Conversational AI Voice Assistant** | ElevenAgents (LLM + TTS) | Saaras (Indian STT input) | Very High | Enterprise |
| 21 | **Hindi → English Audiobook** | Flash TTS in EN voice | Saaras: source Hindi audio | High | Enterprise |
| 22 | **Emotion-Directed TTS** | v4 `<excited>` / `<sad>` tags | — | Low | Pro Plus |
| 23 | **Transliteration Display** | — | `/transliterate` endpoint | Low | Pro |
| 24 | **Background Music + Voice** | Music generation | Bulbul TTS | Medium | Pro Plus |
| 25 | **Field Recording Cleaner** | Audio Isolation | — | Low | Pro |

---

### 10.4 Flagship Combined Experiences

Below are the **highest-impact product features** possible only because of ElevenLabs + Sarvam together. None of SpeakIT's competitors can build these without both APIs.

---

#### 🌉 Feature A: The Bilingual Voice Bridge (Live)
> *"Speak in Hindi. Hear it back in any voice, in English, instantly."*

**What it does:** User speaks in any of 22 Indian languages → Sarvam transcribes + translates to English in real-time → ElevenLabs speaks the translated text back in whatever voice the user selected (e.g., a British male, a calm American female, or their own voice clone).

**Why it's unique:** No other consumer app in India offers this. Requires both Sarvam's unmatched Indian STT accuracy AND ElevenLabs' premium voice quality. Neither provider alone can build this.

**Use cases:** Language learning, content creation, accessibility for non-English speakers, live interpretation.

```
Sarvam Saaras v3-realtime (mode: translate)  →  ElevenLabs Flash v2.5 WebSocket TTS
              ↑                                              ↓
         User's mic (16kHz PCM)                    Speaker output (PCM → AVAudioEngine)
```

---

#### 🎬 Feature B: AI Dubbing for Indian Content
> *"Upload a Hindi video. Get it dubbed in English in the same voice."*

**What it does:** User uploads a Hindi/Tamil/Telugu video or audio file → Sarvam Saaras transcribes it (with timestamps) → ElevenLabs Dubbing v2 re-voices it in 90+ languages, preserving the original speaker's voice characteristics.

**Why it's unique:** ElevenLabs dubbing works best with clean source transcripts. Sarvam provides the most accurate Indian language source transcript. Together: perfect dubbing of Indian regional content into English (or vice versa).

**Use cases:** YouTube content localisation, Bollywood to global markets, corporate multilingual training videos.

---

#### 🎙️ Feature C: Bilingual Voice Cloning
> *"Clone your voice. Speak in Hindi AND English."*

**What it does:** User records 30 seconds of their voice → ElevenLabs IVC creates an English clone → Sarvam Bulbul creates an Indic clone from the same recording → SpeakIT stores both `voice_id`s → User's voice now speaks in both languages.

**Why it's unique:** ElevenLabs handles English; Sarvam handles Indic. One recording → two clones → one unified experience.

**Use cases:** Creators who produce content in both Hindi and English (most Indian YouTubers). Brand voice that sounds the same in both languages.

---

#### 📰 Feature D: Document → Bilingual Audio (OCR → TTS)
> *"Photograph a Hindi newspaper article. Hear it read aloud in English by your preferred voice."*

**What it does:** User takes a photo of any Indian document (Hindi newspaper, Tamil form, Gujarati letter) → Sarvam Vision OCR extracts the text → Sarvam Translate converts to English → ElevenLabs TTS narrates in the user's preferred voice.

**Why it's unique:** Combines Sarvam's Indian-language OCR (no Western model can read Devanagari/Tamil reliably) with ElevenLabs' premium narration.

**Use cases:** Accessibility for non-English readers, business document translation, studying regional language materials.

---

#### 🎵 Feature E: Voice + Music Composer
> *"Type your script. Get a narrated audio piece with background music."*

**What it does:** User types or speaks a script → SpeakIT generates narration (ElevenLabs TTS) + background music (ElevenLabs Music API) simultaneously → Mixes audio tracks → Delivers a complete podcast intro, ad spot, or audio story.

**Why it's unique:** ElevenLabs is the only API offering both TTS and Music generation in one platform. Sarvam provides the Indian-language narration layer.

**Use cases:** Podcast production, audio advertisements, meditation/relaxation audio, storytelling for children.

---

#### 🗣️ Feature F: Noise-Cleaned Meeting Transcription with Diarization
> *"Record your team call. Get a clean transcript with 'Speaker 1 said... Speaker 2 said...'"*

**What it does:** User uploads a meeting recording (phone call quality, noisy) → ElevenLabs Audio Isolation removes background noise → Sarvam Saaras v4 transcribes with speaker diarization → Output is a structured, speaker-labelled transcript in the spoken Indian language(s) + English translation.

**Why it's unique:** Audio Isolation (ElevenLabs) → Indian language diarization (Sarvam) is the first clean pipeline for Indian business meetings.

**Use cases:** Legal depositions, business meetings, HR interviews, journalistic field recordings.

---

#### 🤖 Feature G: Indic Conversational AI Assistant
> *"Talk to SpeakIT in Hindi. It understands, thinks, and responds — in any voice you choose."*

**What it does:** User speaks in Hindi/Tamil → Sarvam Saaras STT converts to text → Sarvam LLM (Sarvam-105B) processes the query in native Indian language → ElevenLabs TTS speaks the response in the user's preferred voice.

**Why it's unique:** An LLM that natively understands Indian languages (not translated through English) + premium voice output. Sarvam-105B is India's most capable sovereign LLM; ElevenLabs provides the voice.

**Use cases:** AI tutor in regional languages, customer support for Indian vernacular users, accessibility assistant.

---

### 10.5 SpeakIT Product Roadmap: What to Build & When

```
PHASE 1 — FOUNDATION (Weeks 1–4)  [Sarvam-only]
──────────────────────────────────────────────────
✅ Already done:  Standard Sarvam Bulbul TTS (Indic voices)
✅ Already done:  Sarvam Saaras batch file STT
□ Migrate:        Saarika → Saaras v4 for batch STT
□ New:            Codemix mode toggle in STT settings
□ New:            Transliteration display alongside transcript
□ New:            Inter-Indic text translation (Sarvam-Translate)
□ New:            Sarvam voice picker (all 30+ Bulbul voices)

PHASE 2 — LIVE TRANSCRIPTION (Weeks 5–8)  [Sarvam Live]
─────────────────────────────────────────────────────────
□ Build:  SarvamLiveSTTService.swift (WebSocket, VAD, partial events)
□ Build:  LiveTranscriptionView.swift (real-time caption display)
□ Build:  Backend /ws/live-stt WebSocket proxy (Spring WebFlux)
□ Build:  Live Translation mode (mode: "translate")
□ Build:  Session transcript export (.txt / .pdf)
□ Gate:   Live Transcription → Pro (10 min/mo)
□ Gate:   Live Translation → Pro Plus (30 min/mo)

PHASE 3 — ELEVENLABS ADVANCED (Weeks 9–12)  [ElevenLabs Power]
────────────────────────────────────────────────────────────────
□ Build:  Audio Isolation endpoint (noise cleaner feature)
□ Build:  Voice Changer (STS: record in your voice → hear in another)
□ Build:  Sound Effects generator (text → SFX for content creators)
□ Build:  Emotion-directed TTS (v4 voice direction tags)
□ Gate:   Voice Changer → Pro Plus
□ Gate:   Audio Isolation → Pro (field recording cleaner)
□ Gate:   Sound Effects → Pro Plus

PHASE 4 — LIVE VOICE BRIDGE (Weeks 13–16)  [Combined: Flagship]
──────────────────────────────────────────────────────────────────
□ Build:  ElevenLabsLiveStreamTTSService.swift (WebSocket TTS + PCM)
□ Build:  Backend /ws/live-tts WebSocket proxy
□ Build:  LiveVoiceBridgeView.swift (voice picker + waveform)
□ Wire:   Sarvam final transcript → ElevenLabs TTS pipeline
□ Build:  Indic → Indic mode (Saaras STT → Bulbul TTS in diff language)
□ Gate:   Live Voice Bridge → Pro Plus (15 min/mo)
□ Tune:   Latency < 800ms end-to-end

PHASE 5 — VOICE CLONING & CONTENT STUDIO (Weeks 17–24)  [Enterprise]
────────────────────────────────────────────────────────────────────────
□ Build:  Voice Clone Creator (record 30s → IVC via ElevenLabs)
□ Build:  Indic Voice Clone (Bulbul clone alongside ElevenLabs clone)
□ Build:  Bilingual Voice Clone (same recording → EN + Indic twin)
□ Build:  AI Dubbing (upload video → choose output language)
□ Build:  Document → Audio (photo → OCR → translate → narrate)
□ Gate:   All above → Enterprise

PHASE 6 — CONVERSATIONAL AI & LLM (Weeks 25–36)  [Future / Enterprise]
──────────────────────────────────────────────────────────────────────────
□ Research: Sarvam-105B API integration (chat completions endpoint)
□ Build:    Indic AI Assistant (Saaras STT → Sarvam-105B → ElevenLabs TTS)
□ Build:    Meeting Transcription with Diarization (noise clean → diarize → export)
□ Build:    AI Audiobook from Document (long-form ElevenLabs Projects API)
□ Build:    Voice + Music Composer (ElevenLabs TTS + Music API)
□ Gate:     All above → Enterprise + API Access tier
```

---

### Summary: The Maximum Combined Output

| Category | ElevenLabs Max | Sarvam Max | Combined Max |
|---|---|---|---|
| **Languages (TTS)** | 90+ | 11 Indian | 90+ global + 11 Indic native |
| **Languages (STT)** | 90+ (Scribe) | 22 Indian (Saaras) | 90+ global + 22 Indic with codemix |
| **Voice Count** | 3,000+ library | 30+ Bulbul voices | 3,030+ total across both |
| **Cloning** | IVC + PVC | Bulbul clone | Bilingual clone (EN + Indic from 1 recording) |
| **Live Latency** | ~75ms TTS | ~100-200ms STT | ~500–800ms total bridge latency |
| **Audio Production** | TTS + STS + SFX + Music + Isolation + Dubbing | TTS + STT + Translation | Full studio: clean → transcribe → translate → synthesise → add music → export |
| **LLM** | External (GPT/Claude via ElevenAgents) | Sarvam-105B (native Indian) | Indian-first AI assistant with global voice output |
| **Document Understanding** | — | OCR + Vision (Indian scripts) | Photograph Indian doc → narrate in any language/voice |
| **Enterprise Compliance** | SOC 2, HIPAA, GDPR, EU Residency | DPDPA compliant, India-hosted | Fully sovereign for Indian enterprise + globally compliant |

> [!IMPORTANT]
> **The single most powerful combination SpeakIT can offer is the Live Voice Bridge + Bilingual Voice Cloning.** No competitor — Indian or global — has both Sarvam's Indian language accuracy and ElevenLabs' voice quality in a single consumer product. This is SpeakIT's defensible moat for the next 2–3 years.

*End of Section 10. See Sections 5–7 for implementation details of the Live Voice Bridge.*
