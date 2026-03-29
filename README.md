# SpeakIt - Text-to-Speech Application

A modern web application that converts text into natural-sounding speech using AWS Polly, featuring a responsive Angular frontend and a robust Spring Boot backend.

## What the Project Does

SpeakIt provides a simple yet powerful text-to-speech service through a web interface. Users can input text, select from various voices, and generate high-quality audio files in MP3 format. The application leverages Amazon Polly's advanced neural text-to-speech technology to deliver lifelike speech synthesis.

## Why the Project is Useful

- **High-Quality Speech Synthesis**: Uses AWS Polly's neural voices for natural, human-like speech
- **Multiple Voice Options**: Access to a wide range of voices in different languages and accents
- **Rate Limiting**: Built-in protection against abuse with configurable rate limits
- **Responsive Design**: Modern web interface that works on desktop and mobile devices
- **Easy Deployment**: Ready-to-deploy configurations for popular hosting platforms

## How Users Can Get Started

### Prerequisites

- Java 21 or higher
- Node.js 18+ and npm
- AWS account with Polly access
- Git

### Backend Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/Mohitur669/speakit.git
   cd speakit/backend
   ```

2. Configure AWS credentials:
   - Copy `example.env` to `.env`
   - Fill in your AWS credentials:
     ```
     AWS_ACCESS_KEY_ID=your-access-key
     AWS_SECRET_ACCESS_KEY=your-secret-key
     AWS_REGION=us-east-1
     CORS_ALLOWED_ORIGIN=your-allowed-origin
     ```

3. Build and run the backend:

   ```bash
   ./mvnw spring-boot:run
   ```

   The backend will start on `http://localhost:8080`

### Frontend Setup

1. Navigate to the frontend directory:

   ```bash
   cd ../text-to-speech-frontend
   ```

2. Install dependencies:

   ```bash
   npm install
   ```

3. Configure the API URL:
   - For development, the default `http://localhost:8080` is used
   - For production, set the `API_URL` environment variable

4. Start the development server:

   ```bash
   npm start
   ```

   Open `http://localhost:4200` in your browser

### Usage Example

1. Open the application in your browser
2. Enter text in the input field (up to 1000 characters)
3. Select a voice from the dropdown
4. Click "Convert to Speech"
5. Play the generated audio or download the MP3 file

## Where Users Can Get Help

- **Issues**: Report bugs and request features on the [GitHub Issues](https://github.com/Mohitur669/speakit/issues) page
- **Discussions**: Join community discussions on [GitHub Discussions](https://github.com/Mohitur669/speakit/discussions)
- **Documentation**: API documentation is available in the backend code comments

## Who Maintains and Contributes

This project is maintained by the SpeakIt development team. We welcome contributions from the community!

For contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md) (if available).

To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

_Built with Spring Boot, Angular, and AWS Polly_</content>
<parameter name="filePath">/home/cyberbully/Documents/Desktop/git-projects/speakit/README.md
