# SpeakIt

> Transform any text into natural, human-quality speech — instantly.

SpeakIt is a full-stack Text-to-Speech web application powered by **AWS Polly**. It provides a clean, responsive interface where users can paste or type any text, select from a rich catalog of voices and languages, and receive high-quality synthesized audio — playable in-browser or downloadable as an MP3. The project is deployed across a modern cloud stack: an Angular SPA on Vercel, a Spring Boot REST API on Render, with path-based routing managed through a Cloudflare Worker.

**Live Demo:** [mohitur-speakit.vercel.app](https://mohitur-speakit.vercel.app)

---

## Table of Contents

- [Key Features](#key-features)
- [Tech Stack](#tech-stack)
- [Project Architecture](#project-architecture)
- [Installation & Setup](#installation--setup)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Getting Help](#getting-help)
- [Contributing](#contributing)
- [License](#license)

---

## Key Features

- **AWS Polly-Powered Synthesis** — Leverages Amazon Polly's neural and standard TTS engines to produce natural, high-fidelity audio from any input text.
- **Multi-Voice & Multi-Language Support** — Users can choose from a wide range of Polly voices across multiple languages and accents via a dynamic dropdown.
- **In-Browser Audio Playback** — Synthesized audio streams directly into the browser's native audio player, with no file downloads required for instant listening.
- **MP3 Download** — Users can download the generated audio as an MP3 file for offline use.
- **Rate Limiting** — Built-in server-side rate limiting protects the API against abuse and controls AWS Polly invocation costs.
- **Input Character Limit** — Enforces a 1,000-character cap on synthesis requests, keeping responses fast and costs predictable.
- **Responsive Design** — The Angular frontend adapts gracefully across desktop and mobile screen sizes.
- **Runtime Environment Configuration** — Frontend reads the API base URL from `runtime-env.js` injected at startup, enabling zero-rebuild environment switching between local development and production.
- **Automated Dev/Build Hooks** — `prestart` and `prebuild` npm scripts auto-generate the correct environment file, ensuring a frictionless local development experience.
- **Cross-Origin REST API** — Spring Boot backend exposes a CORS-configured REST endpoint (`/api/synthesize`) that accepts text and voice parameters and returns audio data.
- **Containerized Backend** — The Spring Boot service is fully Dockerized using `eclipse-temurin:21`, deployable on any container-compatible host including Render.
- **Cloudflare Worker Routing** — A lightweight edge Worker handles path-based routing under the `mohitur.com` domain, dispatching requests to the correct application without infrastructure overhead.
- **Cost-Control Kill Switch** — AWS Budgets + SNS + Lambda IAM deny policy architecture ensures AWS Polly costs are hard-capped, preventing runaway charges.

---

## Tech Stack

### Frontend

| Technology           | Purpose                                  |
| -------------------- | ---------------------------------------- |
| Angular (TypeScript) | SPA framework and component architecture |
| SCSS                 | Component-scoped styling                 |
| Angular HttpClient   | REST API communication with the backend  |
| Vercel               | Frontend hosting and CI/CD               |

### Backend

| Technology                    | Purpose                                      |
| ----------------------------- | -------------------------------------------- |
| Java 21                       | Runtime language                             |
| Spring Boot                   | REST API framework                           |
| Spring Web (MVC)              | HTTP endpoint routing and CORS configuration |
| Maven                         | Dependency management and build              |
| AWS SDK for Java (Polly)      | Text-to-Speech synthesis                     |
| Docker (`eclipse-temurin:21`) | Containerization                             |
| Render                        | Backend hosting via Procfile / Docker        |

### Cloud & Infrastructure

| Technology                 | Purpose                                              |
| -------------------------- | ---------------------------------------------------- |
| AWS Polly                  | Neural/Standard TTS engine                           |
| AWS IAM                    | Credential management and cost-control deny policies |
| AWS Budgets + SNS + Lambda | Automated billing kill switch                        |
| Cloudflare Workers         | Edge-layer path-based domain routing                 |

---

## Project Architecture

```
User Browser
     |
     | HTTPS
     v
Vercel (Angular SPA)
     |
     | HTTP REST  POST /api/synthesize
     v
Render (Spring Boot API)
     |
     | AWS SDK for Java
     v
AWS Polly (TTS Engine)
     |
     | audio/mpeg stream
     v
Spring Boot  -->  Angular  -->  User (playback / download)
```

**Request Flow:**

1. The user enters text (up to 1,000 characters) and selects a voice on the Angular frontend.
2. The Angular service reads the backend API URL from `window.__env.API_URL` (injected by `public/runtime-env.js`) and sends a `POST /api/synthesize` request to the Spring Boot backend.
3. The backend applies rate limiting, validates the request, then invokes the **AWS Polly SDK** with the user's chosen voice ID and engine type.
4. The synthesized audio bytes are returned as an HTTP response with `Content-Type: audio/mpeg`.
5. The Angular component creates a blob URL, binds it to an `<audio>` element for instant in-browser playback, and optionally triggers an MP3 download.

**Environment Strategy:**

The Angular app does not bake the API URL into the compiled bundle. Instead, `src/public/runtime-env.js` (generated at startup by `prestart`/`prebuild` npm hooks) sets `window.__env.API_URL` at runtime, allowing the same build artifact to target different backends without a rebuild.

---

## Installation & Setup

### Prerequisites
- **Node.js** v18+ and **npm** v9+
- **Angular CLI** v17+: `npm install -g @angular/cli`
- **Java 21** (JDK): [eclipse-temurin:21](https://adoptium.net/) recommended
- **Maven** 3.9+
- **Docker** (optional, for containerized setup)
- **AWS Account** with an IAM user/role that has `polly:SynthesizeSpeech` permissions
- AWS credentials configured locally (`~/.aws/credentials` or environment variables)

---

### 1. Clone the Repository
```bash
git clone https://github.com/Mohitur669/speakit.git
cd speakit
```

---

### 2. Backend Setup (Spring Boot)
```bash
cd backend
```

#### Configure Environment Variables
Copy the provided example file and fill in your credentials:
```bash
cp example.env .env
```

Edit `.env` with your values:
```bash
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
AWS_REGION=us-east-1
CORS_ALLOWED_ORIGIN=http://localhost:4200
```

> **Note:** For production, set `CORS_ALLOWED_ORIGIN` to your deployed frontend URL (e.g. `https://mohitur-speakit.vercel.app`).

Alternatively, configure AWS credentials via the CLI:
```bash
aws configure
```

#### Run Locally with Maven
```bash
./mvnw spring-boot:run
```
The backend starts on `http://localhost:8080` by default.

#### Build and Run with Docker (Backend only)
```bash
cd backend
docker build -t mohitur/speakit:backend .
docker run -p 8080:8080 \
  -e AWS_ACCESS_KEY_ID=your-access-key-id \
  -e AWS_SECRET_ACCESS_KEY=your-secret-access-key \
  -e AWS_REGION=us-east-1 \
  -e CORS_ALLOWED_ORIGIN=http://localhost:4200 \
  mohitur/speakit:backend
```

---

### 3. Frontend Setup (Angular)
```bash
cd ../frontend
npm install
```

#### Configure the Runtime Environment
Create `public/runtime-env.js` for local development:
```javascript
// public/runtime-env.js  (local dev — do not commit)
window.__env = {
  API_URL: "http://localhost:8080",
};
```

For production (Vercel), this file is generated automatically by the `prebuild` npm hook pointing to your Render deployment URL.

> **Note:** The `prestart` script auto-generates this file before `ng serve`. Manual creation is only needed if you want to override the target backend or if the hooks are not yet configured.

#### Start the Development Server
```bash
npm start
```
The frontend is served at `http://localhost:4200`.

#### Build and Run with Docker (Frontend only)
```bash
cd frontend
docker build -t mohitur/speakit:frontend .
docker run -p 4200:80 \
  mohitur/speakit:frontend
```
The frontend is served at `http://localhost:4200`.

---

### 4. Run Everything with Docker Compose (Recommended)

This is the easiest way to run both frontend and backend together with a single command.

#### Prerequisites
- Docker installed and running
- A `.env` file in the repo root

#### Create `.env` in the repo root
```bash
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
AWS_REGION=your-region
CORS_ALLOWED_ORIGIN=http://localhost
```

#### Option A — Build from source
```bash
docker compose build
docker compose up -d
```

#### Option B — Pull from Docker Hub (no build needed)
```bash
docker pull mohitur/speakit:backend
docker pull mohitur/speakit:frontend
docker compose up -d
```

#### Access the app
| Service  | URL                      |
|----------|--------------------------|
| Frontend | http://localhost:4200    |
| Backend  | http://localhost:8080    |

#### Stop the app
```bash
docker compose down
```

---


### 4. Environment Variable Reference

| Variable                | Location                  | Description                              |
| ----------------------- | ------------------------- | ---------------------------------------- |
| `AWS_ACCESS_KEY_ID`     | Backend `.env`            | AWS IAM access key                       |
| `AWS_SECRET_ACCESS_KEY` | Backend `.env`            | AWS IAM secret key                       |
| `AWS_REGION`            | Backend `.env`            | AWS region for Polly (e.g. `us-east-1`)  |
| `CORS_ALLOWED_ORIGIN`   | Backend `.env`            | Allowed frontend origin for CORS headers |
| `window.__env.API_URL`  | Frontend `runtime-env.js` | Base URL of the Spring Boot API          |

---

## Usage

### Running the Full Stack Locally

```bash
# Terminal 1 — Backend
cd backend
./mvnw spring-boot:run

# Terminal 2 — Frontend
cd frontend
npm start
```

Open your browser at `http://localhost:4200`.

### Application Walkthrough

1. Open the application in your browser.
2. Enter text in the input field (up to **1,000 characters**).
3. Select a voice from the dropdown — voices are grouped by language and accent.
4. Click **Convert to Speech**.
5. Play the generated audio directly in the browser, or click **Download** to save the MP3 file.

### API — Get Available Voices

```
GET /api/tts/voices
```

Returns a list of all available AWS Polly voices with their ID, name, and gender.

**Response:** `application/json`

```json
[
  {
    "id": "Joanna",
    "name": "Joanna",
    "gender": "Female"
  },
  {
    "id": "Matthew",
    "name": "Matthew",
    "gender": "Male"
  }
]
```

Example with `curl`:

```bash
curl http://localhost:8080/api/tts/voices
```

> **Note:** This endpoint is rate limited. Excessive requests within a short window will be rejected.

### API — Synthesize Speech

```
POST /api/synthesize
Content-Type: application/json

{
  "text": "Hello, world! This is SpeakIt.",
  "voiceId": "Joanna",
  "engine": "neural"
}
```

**Response:** `audio/mpeg` binary stream (MP3 audio).

Example with `curl`:

```bash
curl -X POST http://localhost:8080/api/synthesize \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello from SpeakIt","voiceId":"Joanna","engine":"neural"}' \
  --output output.mp3
```

---

## Getting Help

- **Bug Reports & Feature Requests:** Open an issue on the [GitHub Issues](https://github.com/Mohitur669/speakit/issues) page with a clear description and steps to reproduce.
- **Questions & Discussions:** Join the conversation on [GitHub Discussions](https://github.com/Mohitur669/speakit/discussions).
- **API Reference:** Inline documentation is available in the backend source code comments.

---

## License

This project is currently unlicensed. All rights reserved by the author.

To use, modify, or distribute this code, please contact the repository owner at [github.com/Mohitur669](https://github.com/Mohitur669), or add a `LICENSE` file to the repository to clarify terms for contributors.

---

_Built and maintained by [Mohd Mohitur Rahaman](https://github.com/Mohitur669) — powered by Spring Boot, Angular, and AWS Polly._
