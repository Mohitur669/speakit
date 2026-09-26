//
//  BlogUpdatesSheet.swift
//  SpeakIT
//
//  Native in-app Blog & Engineering Updates matching frontend blog.data.ts with full parity.
//

import SwiftUI

struct BlogArticleSection: Identifiable {
    let id = UUID()
    var heading: String? = nil
    var body: String? = nil
    var code: String? = nil
    var codeLanguage: String? = nil
    var bulletPoints: [String]? = nil
}

struct BlogArticle: Identifiable {
    let id: String
    let title: String
    let date: String
    let author: String
    let authorRole: String
    let category: String
    let readTime: String
    let excerpt: String
    let tags: [String]
    let sections: [BlogArticleSection]
}

enum BlogData {
    static let articles: [BlogArticle] = [
        BlogArticle(
            id: "spring-boot-docker-multi-stage-builds",
            title: "Why my Spring Boot Docker image kept failing — and how multi-stage builds fixed it",
            date: "May 31, 2026",
            author: "Mohd Mohitur Rahaman",
            authorRole: "Senior Software Engineer",
            category: "Engineering",
            readTime: "6 min read",
            excerpt: "A deep dive into why standard Spring Boot Dockerfiles fail in CI/CD pipelines, and how moving to a multi-stage Eclipse Temurin build solved my JDK mismatches and missing target/ directory errors.",
            tags: ["Docker", "Spring Boot", "CI/CD", "Java 21"],
            sections: [
                BlogArticleSection(
                    body: "We’ve all been there. You’ve just finished a marathon coding session, your Spring Boot backend is humming along perfectly on localhost:8080, and you’ve even managed to get your AWS Polly integration producing crystal-clear audio. It’s time to ship. You write a \"simple\" Dockerfile, push to GitHub, and wait for the deployment to go green. Except it doesn't."
                ),
                BlogArticleSection(
                    heading: "The Context",
                    body: "SpeakIT isn't just a \"Hello World\" app. It’s a production-grade backend that handles real-time synthesis, manages user history in PostgreSQL, and enforces rate limits via Bucket4j. Because I’m deploying to Render, which supports Docker, I wanted to ensure my deployment environment was identical to my development environment.\n\nThe stack was modern: Spring Boot 3.3.0 and Java 21. Naturally, I started with what I thought was the \"standard\" way to containerize a Java app."
                ),
                BlogArticleSection(
                    heading: "The Problem: \"It Works on My Machine\"",
                    body: "My first attempt at a Dockerfile looked something like this:",
                    code: """
# [Broken Version - DO NOT USE]
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
""",
                    codeLanguage: "dockerfile"
                ),
                BlogArticleSection(
                    heading: "Root Cause",
                    body: "I ran mvn clean package on my laptop, then ran docker build. It worked! Then, I pushed it to the cloud. The moment my build hit a remote environment, it exploded with:\n\nStep 3/4 : COPY target/*.jar app.jar\nCOPY failed: no source files were specified\n\nI had fallen into the classic \"target/ directory is gitignored\" trap. The compiled .jar file never makes it to the remote repository. My Dockerfile was expecting me to have built the app before running Docker, which completely defeats the purpose of an automated pipeline."
                ),
                BlogArticleSection(
                    heading: "What I Tried: Version Drift and Mismatched JDKs",
                    body: "I tried to change the base image to something with Maven and run the build there. But I hit a second problem: The JDK version mismatch. SpeakIT uses Java 21, but my initial base image was Java 17. I got the dreaded java.lang.UnsupportedClassVersionError: com/tts/SpeakItApplication has been compiled by a more recent version of the Java Runtime."
                ),
                BlogArticleSection(
                    heading: "The Fix: Multi-Stage Builds",
                    body: "The solution was to stop treating the Dockerfile as a \"runner\" and start treating it as a complete build factory. I moved to a Multi-Stage Build using Eclipse Temurin:",
                    code: """
# Stage 1: Build stage
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
ENTRYPOINT ["java", "-jar", "app.jar"]
""",
                    codeLanguage: "dockerfile"
                ),
                BlogArticleSection(
                    heading: "Key Takeaways",
                    bulletPoints: [
                        "Multi-stage is mandatory: Use one stage for building (with Maven/JDK) and another for running (with just JRE/Alpine) to keep images small and portable.",
                        "Sync your versions: Ensure the Java version in pom.xml matches the version in your FROM lines.",
                        "Layer your cache: Copy pom.xml and download dependencies before copying your src directory to speed up build times.",
                        "Ignore the target: Never rely on local target/ builds for your Docker images; let Docker handle the compilation."
                    ]
                )
            ]
        ),
        BlogArticle(
            id: "angular-runtime-env-injection",
            title: "Angular environment.ts is not enough — runtime config injection for Docker + Vercel",
            date: "May 30, 2026",
            author: "Mohd Mohitur Rahaman",
            authorRole: "Senior Software Engineer",
            category: "Architecture",
            readTime: "7 min read",
            excerpt: "Why hardcoding API URLs into environment.prod.ts breaks containerized deployments, and how to build a \"write once, run anywhere\" Angular app using the window.__env pattern.",
            tags: ["Angular", "Docker", "Vercel", "DevOps"],
            sections: [
                BlogArticleSection(
                    body: "If you've built an Angular app, you've probably used the src/environments/environment.ts pattern. But when I started deploying SpeakIT to Vercel and wrapping it in Docker for local testing, I hit a massive wall: Angular environments are baked in at compile-time."
                ),
                BlogArticleSection(
                    heading: "The Problem: The \"Immutable Image\" Paradox",
                    body: "Once you run ng build --configuration production, your API URL is hardcoded into the Javascript main bundle:",
                    code: """
// [Original Broken Approach]
export const environment = {
  production: true,
  apiUrl: 'https://text-to-speech-java-backend.onrender.com'
};
""",
                    codeLanguage: "typescript"
                ),
                BlogArticleSection(
                    body: "If I wanted to spin up a \"Staging\" environment, I had to edit the file, commit, and wait for a full rebuild. This defeats the purpose of Docker, which configures environments via variables at startup."
                ),
                BlogArticleSection(
                    heading: "The Fix: The \"Window Env\" Pattern",
                    body: "The solution was to stop using Angular for configuration and start using the Browser Window.\n\nStep 1: Create a Runtime Script in frontend/scripts/generate-runtime-env.js that reads environment variables and writes them to a plain Javascript file:",
                    code: """
const fs = require('fs');
const envConfig = { API_URL: process.env.API_URL || 'http://localhost:8080' };
fs.writeFileSync('public/runtime-env.js', `window.__env = ${JSON.stringify(envConfig)};`);
""",
                    codeLanguage: "javascript"
                ),
                BlogArticleSection(
                    heading: "Step 2: Hook into the Build Lifecycle",
                    body: "In package.json, add a prebuild hook:",
                    code: """
"scripts": {
  "prebuild": "node scripts/generate-runtime-env.js",
  "build": "ng build"
}
""",
                    codeLanguage: "json"
                ),
                BlogArticleSection(
                    heading: "Step 3 & 4: Load and Map",
                    body: "Add a script tag to index.html and update environment.ts to look at this global window object instead of hardcoded strings:",
                    code: """
const env = (window as any).__env || {};
export const environment = {
  production: false,
  apiUrl: env.API_URL || ''
};
""",
                    codeLanguage: "typescript"
                ),
                BlogArticleSection(
                    heading: "Key Takeaways",
                    bulletPoints: [
                        "Stop baking URLs: Use environment.ts as a bridge to a window object, not as a storage for strings.",
                        "Leverage npm hooks: Use prebuild and prestart to generate your config scripts automatically.",
                        "Build Once: Your production Docker image should be able to run in Staging just by changing an ENV var."
                    ]
                )
            ]
        ),
        BlogArticle(
            id: "spring-boot-cors-render-fix",
            title: "Spring Boot CORS: why it worked locally but broke on Render",
            date: "May 28, 2026",
            author: "Mohd Mohitur Rahaman",
            authorRole: "Senior Software Engineer",
            category: "Engineering",
            readTime: "5 min read",
            excerpt: "How Spring Security filters block OPTIONS preflight requests before @CrossOrigin can handle them, and the correct way to configure global CORS in Spring Boot 3.",
            tags: ["Spring Boot", "CORS", "Security", "Render"],
            sections: [
                BlogArticleSection(
                    body: "\"It works on my machine.\" The four most dangerous words in software engineering. I had SpeakIT running perfectly locally. Then I deployed the backend to Render, the frontend to Vercel, and... CORS Error."
                ),
                BlogArticleSection(
                    heading: "The Problem: The Preflight Failure",
                    body: "I started with the simplest approach: adding @CrossOrigin(origins = \"http://localhost:4200\") to my controller. Locally, it worked. On Render, it exploded with: Access to XMLHttpRequest at 'https://api.com' has been blocked by CORS policy: Response to preflight request doesn't pass access control check."
                ),
                BlogArticleSection(
                    heading: "Root Cause",
                    body: "In SpeakIT, I use JwtAuthenticationFilter. The Security Filter Chain hits before the Controller. It sees an unauthenticated OPTIONS request and rejects it with a 403 Forbidden before it reaches the @CrossOrigin annotation."
                ),
                BlogArticleSection(
                    heading: "The Fix: Global Security Configuration",
                    body: "I moved all CORS logic into my SecurityConfig.java and externalized the allowed origins in application.properties:\n\ncors.allowed-origins=${CORS_ALLOWED_ORIGINS:http://localhost:4200}"
                ),
                BlogArticleSection(
                    heading: "Security Filter Chain Configuration",
                    body: "Configuring the filter chain and configuration source:",
                    code: """
@Bean
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
    return source;
}
""",
                    codeLanguage: "java"
                ),
                BlogArticleSection(
                    heading: "Key Takeaways",
                    bulletPoints: [
                        "Global > Local: Prefer CorsConfigurationSource over @CrossOrigin annotations.",
                        "Permit OPTIONS: Always ensure your security chain allows unauthenticated OPTIONS requests.",
                        "Use Placeholders: Use env vars in application.properties to keep your CORS policy flexible across environments."
                    ]
                )
            ]
        ),
        BlogArticle(
            id: "bucket4j-rate-limiting-spring-boot-3",
            title: "Bucket4j rate limiting in Spring Boot 3 — migrating away from the deprecated API",
            date: "May 25, 2026",
            author: "Mohd Mohitur Rahaman",
            authorRole: "Senior Software Engineer",
            category: "Engineering",
            readTime: "6 min read",
            excerpt: "Navigating the Bucket4j builder pattern migration in Spring Boot 3, and how to effectively limit API usage per-IP to protect expensive backend services.",
            tags: ["Spring Boot", "Bucket4j", "Rate Limiting", "Java"],
            sections: [
                BlogArticleSection(
                    body: "When building an app that calls expensive APIs like AWS Polly, rate limiting isn't just a \"nice to have\"—it's a financial necessity. I chose Bucket4j, but during the migration to Spring Boot 3, I found that the classic Bandwidth.simple() API was gone."
                ),
                BlogArticleSection(
                    heading: "The Problem: The Deprecation Wall",
                    body: "My original implementation used the old simple API which wouldn't even compile anymore:",
                    code: """
// [Deprecated]
Bandwidth limit = Bandwidth.simple(5, Duration.ofMinutes(1));
Refill refill = Refill.greedy(5, Duration.ofMinutes(1));
""",
                    codeLanguage: "java"
                ),
                BlogArticleSection(
                    heading: "The Fix: The Builder Pattern",
                    body: "I had to refactor RateLimitConfig.java to use the new Bandwidth.builder() syntax:",
                    code: """
public Bucket createAuthBucket() {
    return Bucket.builder()
            .addLimit(Bandwidth.builder()
                    .capacity(3)
                    .refillIntervally(1, Duration.ofMinutes(1))
                    .build())
            .build();
}
""",
                    codeLanguage: "java"
                ),
                BlogArticleSection(
                    heading: "Implementation: Keying by Real IP",
                    body: "A rate limiter is only as good as the ID it uses. In RateLimitAspect.java, I extracted the real IP address, accounting for Cloudflare:",
                    code: """
private String extractRealIp(HttpServletRequest request) {
    String cfIp = request.getHeader("CF-Connecting-IP");
    if (cfIp != null) return cfIp;
    return request.getRemoteAddr();
}
""",
                    codeLanguage: "java"
                ),
                BlogArticleSection(
                    heading: "Key Takeaways",
                    bulletPoints: [
                        "Build the Bandwidth: Use Bandwidth.builder() for all new Bucket4j implementations.",
                        "Trust No IP: Always parse proxy headers to avoid rate-limiting your own load balancer.",
                        "Aspects over Filters: Use AOP for rate limiting if you need granular control for different methods."
                    ]
                )
            ]
        ),
        BlogArticle(
            id: "aws-polly-spend-kill-switch",
            title: "Building an AWS spend kill switch: how I made sure a free TTS app can never rack up a surprise bill",
            date: "May 20, 2026",
            author: "Mohd Mohitur Rahaman",
            authorRole: "Senior Software Engineer",
            category: "Architecture",
            readTime: "8 min read",
            excerpt: "How to combine AWS Budgets, SNS, Lambda, and IAM Deny policies to build an automated, proactive financial kill switch for pay-as-you-go APIs.",
            tags: ["AWS", "Serverless", "FinOps", "Security"],
            sections: [
                BlogArticleSection(
                    body: "AWS Polly charges per character. For a personal project like SpeakIT, a single bug in a loop could easily generate a $200 bill while I'm asleep. I needed a Zero-Cost Overrun policy."
                ),
                BlogArticleSection(
                    heading: "The Problem: Reactive vs. Proactive",
                    body: "AWS Budgets send you an email when you hit your limit. If a scraper hits your API at 2 AM, an email won't stop the bill from piling up until you wake up. I needed a bot that would instantly \"pull the plug\"."
                ),
                BlogArticleSection(
                    heading: "The Fix: AWS Budgets + Lambda + IAM",
                    body: "The architecture is: AWS Budgets → SNS Topic → Lambda → IAM Policy.\n\n1. The Emergency Policy:\nI created a policy called PollyEmergencyDeny. In AWS, an explicit Deny always wins over an Allow:",
                    code: """
{
    "Version": "2012-10-17",
    "Statement": [{ "Effect": "Deny", "Action": "polly:*", "Resource": "*" }]
}
""",
                    codeLanguage: "json"
                ),
                BlogArticleSection(
                    heading: "2. The Lambda (PollyBudgetKillSwitch)",
                    body: "This function attaches the Deny policy to my backend user when the budget triggers an SNS event:",
                    code: """
const AWS = require('aws-sdk');
const iam = new AWS.IAM();

exports.handler = async (event) => {
    const params = {
        PolicyArn: 'arn:aws:iam::[MY_ACCOUNT_ID]:policy/PollyEmergencyDeny',
        UserName: 'speakit-backend-user'
    };
    await iam.attachUserPolicy(params).promise();
    console.log("Emergency Deny policy attached.");
};
""",
                    codeLanguage: "javascript"
                ),
                BlogArticleSection(
                    heading: "Key Takeaways",
                    bulletPoints: [
                        "Emails are not enough: Automation must follow notification.",
                        "Explicit Deny: Use it as a global \"Off\" switch in AWS.",
                        "Peace of Mind: Building this switch took 2 hours, but saved me countless nights of worrying about a surprise bill."
                    ]
                )
            ]
        ),
        BlogArticle(
            id: "cloudflare-worker-vercel-render-routing",
            title: "One domain, two clouds: using a Cloudflare Worker to route between Vercel and Render",
            date: "May 15, 2026",
            author: "Mohd Mohitur Rahaman",
            authorRole: "Senior Software Engineer",
            category: "Architecture",
            readTime: "5 min read",
            excerpt: "Solving CORS and branding issues by deploying a Cloudflare Worker to act as a reverse proxy, routing /api to Render and everything else to Vercel.",
            tags: ["Cloudflare", "Vercel", "Render", "Networking"],
            sections: [
                BlogArticleSection(
                    body: "When building a full-stack SaaS prototype on a budget, you quickly learn to love free tiers. I chose Vercel for the Angular frontend and Render for the Spring Boot backend. But tying them both to a single custom domain was a challenge."
                ),
                BlogArticleSection(
                    heading: "The Problem: CORS and Branding",
                    body: "With the frontend on vercel.app and backend on onrender.com, I hit massive CORS headaches and branding issues. I needed a way to route mohitur.com/api/* to Render and everything else to Vercel."
                ),
                BlogArticleSection(
                    heading: "The Fix: Cloudflare Workers",
                    body: "Since my domain's DNS was managed by Cloudflare, a Worker was the perfect, free Edge routing solution:",
                    code: """
export default {
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
}
""",
                    codeLanguage: "javascript"
                ),
                BlogArticleSection(
                    heading: "Key Takeaways",
                    bulletPoints: [
                        "Edge routing is cheap: A Cloudflare Worker is vastly superior to paying for an AWS ALB just to route paths.",
                        "One domain solves CORS: By routing everything through a single domain, CORS issues completely disappear.",
                        "Watch out for caching: Edge functions are eager to cache. Bypass caching for stateful API GET requests."
                    ]
                )
            ]
        )
    ]
}

struct BlogUpdatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedArticle: BlogArticle? = nil
    @State private var selectedCategory: String = "All"
    
    private let categories = ["All", "Engineering", "Architecture"]
    
    private var articles: [BlogArticle] {
        BlogData.articles
    }
    
    private var filteredArticles: [BlogArticle] {
        if selectedCategory == "All" {
            return articles
        }
        return articles.filter { $0.category.lowercased() == selectedCategory.lowercased() }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Blog & Updates")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Text("Honest technical breakdowns, architectural decisions, and the lessons learned while building SpeakIT.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    .padding(.top, 8)
                    
                    // Category Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { category in
                                categoryPill(category)
                            }
                        }
                    }
                    
                    // Articles List
                    VStack(spacing: 16) {
                        ForEach(filteredArticles) { article in
                            articleCard(article)
                        }
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.bottom, 36)
            }
            .background(Color(hex: "F8F9FB").ignoresSafeArea())
            .navigationTitle("Blog & Updates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.speakitPrimary)
                }
            }
            .sheet(item: $selectedArticle) { article in
                articleDetailSheet(article)
            }
        }
    }
    
    @ViewBuilder
    private func categoryPill(_ category: String) -> some View {
        let isSelected = selectedCategory == category
        let fontWeight: Font.Weight = isSelected ? .semibold : .medium
        let textColor: Color = isSelected ? .white : Color.speakitTextPrimary
        let bgColor: Color = isSelected ? Color.speakitPrimary : Color.speakitCard
        
        Button(action: {
            selectedCategory = category
        }) {
            Text(category)
                .font(.system(size: 13, weight: fontWeight))
                .foregroundColor(textColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(bgColor)
                .clipShape(Capsule())
        }
    }
    
    @ViewBuilder
    private func articleCard(_ article: BlogArticle) -> some View {
        let isEngineering = article.category == "Engineering"
        let categoryColor: Color = isEngineering ? Color.speakitPrimary : Color(hex: "8B5CF6")
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(article.category.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(categoryColor.opacity(0.12))
                    .clipShape(Capsule())
                
                Spacer()
                
                Text(article.readTime)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.speakitTextTertiary)
            }
            
            Text(article.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.speakitTextPrimary)
                .lineLimit(2)
            
            Text(article.excerpt)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color.speakitTextSecondary)
                .lineLimit(3)
                .lineSpacing(3)
            
            // Tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(article.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.speakitTextSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "EFEFF4"))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 2)
            
            HStack {
                Text("By \(article.author) • \(article.date)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.speakitTextTertiary)
                
                Spacer()
                
                Button(action: {
                    selectedArticle = article
                }) {
                    HStack(spacing: 4) {
                        Text("Read Article")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Color.speakitPrimary)
                }
            }
        }
        .padding(16)
        .background(Color.speakitBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func articleDetailSheet(_ article: BlogArticle) -> some View {
        let isEngineering = article.category == "Engineering"
        let categoryColor: Color = isEngineering ? Color.speakitPrimary : Color(hex: "8B5CF6")
        
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header badges
                    HStack {
                        Text(article.category.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(categoryColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(categoryColor.opacity(0.12))
                            .clipShape(Capsule())
                        
                        Text("•")
                            .foregroundColor(Color.speakitTextTertiary)
                        
                        Text(article.readTime)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.speakitTextTertiary)
                        
                        Spacer()
                    }
                    
                    Text(article.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                        .lineSpacing(4)
                    
                    // Author card
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: "E2E8F0"))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(Color(hex: "94A3B8"))
                                    .font(.system(size: 18))
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(article.author)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.speakitTextPrimary)
                            Text("\(article.authorRole) • \(article.date)")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color.speakitTextSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    // Sections
                    ForEach(article.sections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            if let heading = section.heading {
                                Text(heading)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(Color.speakitTextPrimary)
                                    .padding(.top, 6)
                            }
                            
                            if let body = section.body {
                                Text(body)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(Color.speakitTextSecondary)
                                    .lineSpacing(5)
                            }
                            
                            if let code = section.code {
                                ScrollView(.horizontal, showsIndicators: true) {
                                    Text(code)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(Color(hex: "F8FAFC"))
                                        .padding(14)
                                }
                                .background(Color(hex: "1E293B"))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: "334155"), lineWidth: 1)
                                )
                            }
                            
                            if let bulletPoints = section.bulletPoints {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(bulletPoints, id: \.self) { point in
                                        HStack(alignment: .top, spacing: 8) {
                                            Circle()
                                                .fill(Color.speakitPrimary)
                                                .frame(width: 6, height: 6)
                                                .padding(.top, 6)
                                            Text(point)
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundColor(Color.speakitTextSecondary)
                                                .lineSpacing(4)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.top, 10)
                    
                    // Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        HStack(spacing: 8) {
                            ForEach(article.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.speakitPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.speakitBadgeBackground)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .navigationTitle("Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        selectedArticle = nil
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.speakitPrimary)
                }
            }
        }
    }
}

#Preview {
    BlogUpdatesSheet()
}
