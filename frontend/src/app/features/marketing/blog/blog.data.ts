export interface BlogPost {
  slug: string;
  title: string;
  date: string;
  author: string;
  authorRole: string;
  category: string;
  categoryColor: string;
  readTime: string;
  excerpt: string;
  content: string;
  tags: string[];
}

export const BLOG_POSTS: BlogPost[] = [
  {
    slug: 'spring-boot-docker-multi-stage-builds',
    title: 'Why my Spring Boot Docker image kept failing — and how multi-stage builds fixed it',
    date: 'May 31, 2026',
    author: 'Mohd Mohitur Rahaman',
    authorRole: 'Senior Software Engineer',
    category: 'Engineering',
    categoryColor: 'accent-500',
    readTime: '6 min read',
    excerpt: 'A deep dive into why standard Spring Boot Dockerfiles fail in CI/CD pipelines, and how moving to a multi-stage Eclipse Temurin build solved my JDK mismatches and missing target/ directory errors.',
    tags: ['Docker', 'Spring Boot', 'CI/CD', 'Java 21'],
    content: `
      <p class="lead text-xl text-primary-700 dark:text-primary-200 font-medium">
        We’ve all been there. You’ve just finished a marathon coding session, your Spring Boot backend is humming along perfectly on localhost:8080, and you’ve even managed to get your AWS Polly integration producing crystal-clear audio. It’s time to ship. You write a "simple" Dockerfile, push to GitHub, and wait for the deployment to go green. Except it doesn't.
      </p>

      <h2>The Context</h2>
      <p>SpeakIT isn't just a "Hello World" app. It’s a production-grade backend that handles real-time synthesis, manages user history in PostgreSQL, and enforces rate limits via Bucket4j. Because I’m deploying to Render, which supports Docker, I wanted to ensure my deployment environment was identical to my development environment.</p>
      <p>The stack was modern: <strong>Spring Boot 3.3.0</strong> and <strong>Java 21</strong>. Naturally, I started with what I thought was the "standard" way to containerize a Java app.</p>

      <h2>The Problem: "It Works on My Machine"</h2>
      <p>My first attempt at a Dockerfile looked something like this:</p>
      <pre><code class="language-dockerfile"># [Broken Version - DO NOT USE]
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]</code></pre>
      <p>I ran <code>mvn clean package</code> on my laptop, then ran <code>docker build</code>. It worked! Then, I pushed it to the cloud. The moment my build hit a remote environment, it exploded with this error:</p>
      <pre><code>Step 3/4 : COPY target/*.jar app.jar
COPY failed: no source files were specified</code></pre>

      <h3>Root Cause</h3>
      <p>I had fallen into the classic <strong>"target/ directory is gitignored"</strong> trap. The compiled <code>.jar</code> file never makes it to the remote repository. My Dockerfile was expecting me to have built the app <em>before</em> running Docker, which completely defeats the purpose of an automated pipeline.</p>

      <h2>What I Tried: Version Drift and Mismatched JDKs</h2>
      <p>I tried to change the base image to something with Maven and run the build there. But I hit a second problem: <strong>The JDK version mismatch.</strong> SpeakIT uses Java 21, but my initial base image was Java 17. I got the dreaded:</p>
      <pre><code>java.lang.UnsupportedClassVersionError: com/tts/TextToSpeechApplication has been compiled by a more recent version of the Java Runtime...</code></pre>

      <h2>The Fix: Multi-Stage Builds</h2>
      <p>The solution was to stop treating the Dockerfile as a "runner" and start treating it as a <strong>complete build factory.</strong> I moved to a Multi-Stage Build using Eclipse Temurin.</p>
      <pre><code class="language-dockerfile"># Stage 1: Build stage
FROM maven:3.9.6-eclipse-temurin-21-alpine AS build
WORKDIR /app

# Copy only the pom.xml first to leverage Docker layer caching
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source and build
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Run stage
FROM eclipse-temurin:21-jdk-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar

RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]</code></pre>

      <h2>Key Takeaways</h2>
      <ul>
        <li><strong>Multi-stage is mandatory:</strong> Use one stage for building (with Maven/JDK) and another for running (with just JRE/Alpine) to keep images small and portable.</li>
        <li><strong>Sync your versions:</strong> Ensure the Java version in pom.xml matches the version in your FROM lines.</li>
        <li><strong>Layer your cache:</strong> Copy pom.xml and download dependencies before copying your src directory to speed up build times.</li>
        <li><strong>Ignore the target:</strong> Never rely on local target/ builds for your Docker images; let Docker handle the compilation.</li>
      </ul>
    `
  },
  {
    slug: 'angular-runtime-env-injection',
    title: 'Angular environment.ts is not enough — runtime config injection for Docker + Vercel',
    date: 'May 30, 2026',
    author: 'Mohd Mohitur Rahaman',
    authorRole: 'Senior Software Engineer',
    category: 'Architecture',
    categoryColor: 'purple-500',
    readTime: '7 min read',
    excerpt: 'Why hardcoding API URLs into environment.prod.ts breaks containerized deployments, and how to build a "write once, run anywhere" Angular app using the window.__env pattern.',
    tags: ['Angular', 'Docker', 'Vercel', 'DevOps'],
    content: `
      <p class="lead text-xl text-primary-700 dark:text-primary-200 font-medium">
        If you've built an Angular app, you've probably used the <code>src/environments/environment.ts</code> pattern. But when I started deploying SpeakIT to Vercel and wrapping it in Docker for local testing, I hit a massive wall: Angular environments are baked in at compile-time.
      </p>

      <h2>The Problem: The "Immutable Image" Paradox</h2>
      <p>Once you run <code>ng build --configuration production</code>, your API URL is hardcoded into the Javascript main bundle.</p>
      <pre><code class="language-typescript">// [Original Broken Approach]
export const environment = {
  production: true,
  apiUrl: 'https://text-to-speech-java-backend.onrender.com'
};</code></pre>
      <p>If I wanted to spin up a "Staging" environment, I had to edit the file, commit, and wait for a full rebuild. This defeats the purpose of Docker, which configures environments via variables at startup.</p>

      <h2>The Fix: The "Window Env" Pattern</h2>
      <p>The solution was to stop using Angular for configuration and start using the Browser Window.</p>

      <h3>Step 1: Create a Runtime Script</h3>
      <p>I created a script in <code>frontend/scripts/generate-runtime-env.js</code> that reads environment variables and writes them to a plain Javascript file.</p>
      <pre><code class="language-javascript">const fs = require('fs');
const envConfig = { API_URL: process.env.API_URL || 'http://localhost:8080' };
fs.writeFileSync('public/runtime-env.js', \`window.__env = \${JSON.stringify(envConfig)};\`);</code></pre>

      <h3>Step 2: Hook into the Build Lifecycle</h3>
      <p>In <code>package.json</code>, I added a <code>prebuild</code> hook.</p>
      <pre><code class="language-json">"scripts": {
  "prebuild": "node scripts/generate-runtime-env.js",
  "build": "ng build"
}</code></pre>

      <h3>Step 3 & 4: Load and Map</h3>
      <p>I added a script tag to <code>index.html</code> and updated <code>environment.ts</code> to look at this global window object instead of hardcoded strings.</p>
      <pre><code class="language-typescript">const env = (window as any).__env || {};
export const environment = {
  production: false,
  apiUrl: env.API_URL || ''
};</code></pre>

      <h2>Key Takeaways</h2>
      <ul>
        <li><strong>Stop baking URLs:</strong> Use environment.ts as a bridge to a window object, not as a storage for strings.</li>
        <li><strong>Leverage npm hooks:</strong> Use prebuild and prestart to generate your config scripts automatically.</li>
        <li><strong>Build Once:</strong> Your production Docker image should be able to run in Staging just by changing an ENV var.</li>
      </ul>
    `
  },
  {
    slug: 'spring-boot-cors-render-fix',
    title: 'Spring Boot CORS: why it worked locally but broke on Render',
    date: 'May 28, 2026',
    author: 'Mohd Mohitur Rahaman',
    authorRole: 'Senior Software Engineer',
    category: 'Engineering',
    categoryColor: 'accent-500',
    readTime: '5 min read',
    excerpt: 'How Spring Security filters block OPTIONS preflight requests before @CrossOrigin can handle them, and the correct way to configure global CORS in Spring Boot 3.',
    tags: ['Spring Boot', 'CORS', 'Security', 'Render'],
    content: `
      <p class="lead text-xl text-primary-700 dark:text-primary-200 font-medium">
        "It works on my machine." The four most dangerous words in software engineering. I had SpeakIT running perfectly locally. Then I deployed the backend to Render, the frontend to Vercel, and... <strong>CORS Error.</strong>
      </p>

      <h2>The Problem: The Preflight Failure</h2>
      <p>I started with the simplest approach: adding <code>@CrossOrigin(origins = "http://localhost:4200")</code> to my controller. Locally, it worked. On Render, it exploded:</p>
      <pre><code>Access to XMLHttpRequest at 'https://api.com' has been blocked by CORS policy: Response to preflight request doesn't pass access control check.</code></pre>
      
      <h3>Root Cause</h3>
      <p>In SpeakIT, I use <code>JwtAuthenticationFilter</code>. The Security Filter Chain hits <em>before</em> the Controller. It sees an unauthenticated <code>OPTIONS</code> request and rejects it with a <code>403 Forbidden</code> before it reaches the <code>@CrossOrigin</code> annotation.</p>

      <h2>The Fix: Global Security Configuration</h2>
      <p>I moved all CORS logic into my <code>SecurityConfig.java</code> and externalized the allowed origins in <code>application.properties</code>:</p>
      <pre><code class="language-properties">cors.allowed-origins=\${CORS_ALLOWED_ORIGINS:http://localhost:4200}</code></pre>
      
      <pre><code class="language-java">@Bean
public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    http.cors(cors -> cors.configurationSource(corsConfigurationSource()))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
            .anyRequest().authenticated()
        );
    return http.build();
}

@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration configuration = new CorsConfiguration();
    configuration.setAllowedOrigins(Arrays.asList(allowedOrigins.split(",")));
    configuration.setAllowedMethods(Arrays.asList("GET", "POST", "OPTIONS"));
    // ... setup source
    return source;
}</code></pre>

      <h2>Key Takeaways</h2>
      <ul>
        <li><strong>Global > Local:</strong> Prefer CorsConfigurationSource over @CrossOrigin annotations.</li>
        <li><strong>Permit OPTIONS:</strong> Always ensure your security chain allows unauthenticated OPTIONS requests.</li>
        <li><strong>Use Placeholders:</strong> Use env vars in application.properties to keep your CORS policy flexible across environments.</li>
      </ul>
    `
  },
  {
    slug: 'bucket4j-rate-limiting-spring-boot-3',
    title: 'Bucket4j rate limiting in Spring Boot 3 — migrating away from the deprecated API',
    date: 'May 25, 2026',
    author: 'Mohd Mohitur Rahaman',
    authorRole: 'Senior Software Engineer',
    category: 'Engineering',
    categoryColor: 'accent-500',
    readTime: '6 min read',
    excerpt: 'Navigating the Bucket4j builder pattern migration in Spring Boot 3, and how to effectively limit API usage per-IP to protect expensive backend services.',
    tags: ['Spring Boot', 'Bucket4j', 'Rate Limiting', 'Java'],
    content: `
      <p class="lead text-xl text-primary-700 dark:text-primary-200 font-medium">
        When building an app that calls expensive APIs like AWS Polly, rate limiting isn't just a "nice to have"—it's a financial necessity. I chose Bucket4j, but during the migration to Spring Boot 3, I found that the classic Bandwidth.simple() API was gone.
      </p>

      <h2>The Problem: The Deprecation Wall</h2>
      <p>My original implementation used the old simple API which wouldn't even compile anymore:</p>
      <pre><code class="language-java">// [Deprecated]
Bandwidth limit = Bandwidth.simple(5, Duration.ofMinutes(1));
Refill refill = Refill.greedy(5, Duration.ofMinutes(1));</code></pre>

      <h2>The Fix: The Builder Pattern</h2>
      <p>I had to refactor my <code>RateLimitConfig.java</code> to use the new <code>Bandwidth.builder()</code> syntax:</p>
      <pre><code class="language-java">public Bucket createAuthBucket() {
    return Bucket.builder()
            .addLimit(Bandwidth.builder()
                    .capacity(3)
                    .refillIntervally(1, Duration.ofMinutes(1))
                    .build())
            .build();
}</code></pre>

      <h2>Implementation: Keying by Real IP</h2>
      <p>A rate limiter is only as good as the ID it uses. In my <code>RateLimitAspect.java</code>, I extracted the real IP address, accounting for Cloudflare:</p>
      <pre><code class="language-java">private String extractRealIp(HttpServletRequest request) {
    String cfIp = request.getHeader("CF-Connecting-IP");
    if (cfIp != null) return cfIp;
    return request.getRemoteAddr();
}</code></pre>

      <h2>Key Takeaways</h2>
      <ul>
        <li><strong>Build the Bandwidth:</strong> Use Bandwidth.builder() for all new Bucket4j implementations.</li>
        <li><strong>Trust No IP:</strong> Always parse proxy headers to avoid rate-limiting your own load balancer.</li>
        <li><strong>Aspects over Filters:</strong> Use AOP for rate limiting if you need granular control for different methods.</li>
      </ul>
    `
  },
  {
    slug: 'aws-polly-spend-kill-switch',
    title: 'Building an AWS spend kill switch: how I made sure a free TTS app can never rack up a surprise bill',
    date: 'May 20, 2026',
    author: 'Mohd Mohitur Rahaman',
    authorRole: 'Senior Software Engineer',
    category: 'Architecture',
    categoryColor: 'purple-500',
    readTime: '8 min read',
    excerpt: 'How to combine AWS Budgets, SNS, Lambda, and IAM Deny policies to build an automated, proactive financial kill switch for pay-as-you-go APIs.',
    tags: ['AWS', 'Serverless', 'FinOps', 'Security'],
    content: `
      <p class="lead text-xl text-primary-700 dark:text-primary-200 font-medium">
        AWS Polly charges per character. For a personal project like SpeakIT, a single bug in a loop could easily generate a $200 bill while I'm asleep. I needed a Zero-Cost Overrun policy.
      </p>

      <h2>The Problem: Reactive vs. Proactive</h2>
      <p>AWS Budgets send you an email when you hit your limit. If a scraper hits your API at 2 AM, an email won't stop the bill from piling up until you wake up. I needed a bot that would instantly "pull the plug".</p>

      <h2>The Fix: AWS Budgets + Lambda + IAM</h2>
      <p>The architecture is: <code>AWS Budgets → SNS Topic → Lambda → IAM Policy</code></p>

      <h3>1. The Emergency Policy</h3>
      <p>I created a policy called <code>PollyEmergencyDeny</code>. In AWS, an explicit Deny always wins over an Allow.</p>
      <pre><code class="language-json">{
    "Version": "2012-10-17",
    "Statement": [{ "Effect": "Deny", "Action": "polly:*", "Resource": "*" }]
}</code></pre>

      <h3>2. The Lambda (PollyBudgetKillSwitch)</h3>
      <p>This function attaches the Deny policy to my backend user when the budget triggers an SNS event.</p>
      <pre><code class="language-javascript">const AWS = require('aws-sdk');
const iam = new AWS.IAM();

exports.handler = async (event) => {
    const params = {
        PolicyArn: 'arn:aws:iam::[MY_ACCOUNT_ID]:policy/PollyEmergencyDeny',
        UserName: 'speakit-backend-user'
    };
    await iam.attachUserPolicy(params).promise();
    console.log("Emergency Deny policy attached.");
};</code></pre>

      <h2>Key Takeaways</h2>
      <ul>
        <li><strong>Emails are not enough:</strong> Automation must follow notification.</li>
        <li><strong>Explicit Deny:</strong> Use it as a global "Off" switch in AWS.</li>
        <li><strong>Peace of Mind:</strong> Building this switch took 2 hours, but saved me countless nights of worrying about a surprise bill.</li>
      </ul>
    `
  },
  {
    slug: 'cloudflare-worker-vercel-render-routing',
    title: 'One domain, two clouds: using a Cloudflare Worker to route between Vercel and Render',
    date: 'May 15, 2026',
    author: 'Mohd Mohitur Rahaman',
    authorRole: 'Senior Software Engineer',
    category: 'Architecture',
    categoryColor: 'purple-500',
    readTime: '5 min read',
    excerpt: 'Solving CORS and branding issues by deploying a Cloudflare Worker to act as a reverse proxy, routing /api to Render and everything else to Vercel.',
    tags: ['Cloudflare', 'Vercel', 'Render', 'Networking'],
    content: `
      <p class="lead text-xl text-primary-700 dark:text-primary-200 font-medium">
        When building a full-stack SaaS prototype on a budget, you quickly learn to love free tiers. I chose Vercel for the Angular frontend and Render for the Spring Boot backend. But tying them both to a single custom domain was a challenge.
      </p>

      <h2>The Problem: CORS and Branding</h2>
      <p>With the frontend on <code>vercel.app</code> and backend on <code>onrender.com</code>, I hit massive CORS headaches and branding issues. I needed a way to route <code>mohitur.com/api/*</code> to Render and everything else to Vercel.</p>

      <h2>The Fix: Cloudflare Workers</h2>
      <p>Since my domain's DNS was managed by Cloudflare, a Worker was the perfect, free Edge routing solution.</p>

      <pre><code class="language-javascript">export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/api')) {
      url.hostname = 'text-to-speech-java-backend.onrender.com';
      // Forward request avoiding aggressive GET cache
      const newRequest = new Request(url, request);
      return fetch(newRequest);
    }
    // Let Cloudflare handle the Vercel DNS CNAME naturally
    return fetch(request);
  }
}</code></pre>

      <h2>Key Takeaways</h2>
      <ul>
        <li><strong>Edge routing is cheap:</strong> A Cloudflare Worker is vastly superior to paying for an AWS ALB just to route paths.</li>
        <li><strong>One domain solves CORS:</strong> By routing everything through a single domain, CORS issues completely disappear.</li>
        <li><strong>Watch out for caching:</strong> Edge functions are eager to cache. Bypass caching for stateful API GET requests.</li>
      </ul>
    `
  }
];
