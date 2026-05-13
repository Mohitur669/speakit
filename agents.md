# AGENTS.md

## Project Overview

This repository is optimized for AI-assisted development using tools like Claude, Gemini, ChatGPT, and local coding agents.

Tech Stack:

- Backend: Java + Spring Boot
- Frontend: Angular
- Build Tool: Maven
- Database: PostgreSQL
- Deployment: Docker / Render / AWS

---

# Development Rules

## General Guidelines

- Always understand the existing code before modifying anything.
- Prefer minimal and clean changes.
- Avoid unnecessary refactoring unless requested.
- Keep naming consistent with the current project style.
- Do not create duplicate utility/helper classes.
- Reuse existing services, DTOs, and repositories whenever possible.
- Preserve backward compatibility.

---

# Code Style

## Java / Spring Boot

- Use constructor injection only.
- Use Lombok where already used.
- Follow layered architecture:
  - Controller
  - Service
  - Repository
  - DTO
  - Entity

- Keep controllers thin.
- Business logic must stay inside services.
- Validate inputs properly.
- Handle exceptions using global exception handlers.
- Use meaningful method names.
- Prefer Streams only when readability improves.

## Angular Frontend Standards

- Use standalone components when appropriate.
- Keep business logic inside services.
- Reuse shared components.
- Use environment files properly.
- Avoid hardcoded API URLs.
- Use interceptors for auth tokens and error handling.
- Keep components focused and small.
- Prefer reactive forms for complex forms.
- Use lazy loading for large modules.
- Follow consistent folder structure.

Example structure:

```text
src/app/
 ├── core/
 ├── shared/
 ├── features/
 ├── services/
 ├── interceptors/
 └── models/
```

---

## API Standards

- Use REST conventions.
- Return proper HTTP status codes.
- Use consistent JSON response structure.
- Never expose internal exceptions directly.
- Add pagination for large datasets.

Example Response:

```json
{
  "success": true,
  "message": "Data fetched successfully",
  "data": {}
}
```

---

# Database Rules

- Never drop tables without explicit instruction.
- Prefer migration scripts.
- Avoid breaking schema changes.
- Add indexes for frequently queried fields.
- Use snake_case for DB columns.

---

# Security Rules

- Never hardcode secrets.
- Use environment variables.
- Do not log sensitive data.
- Validate all external inputs.
- Sanitize file uploads.
- Use Spring Security best practices.

---

# Environment Configuration

- Backend uses environment variables through `.env` or deployment environment configs.
- Environment values must be referenced inside `application.properties` or `application.yml`.
- Never hardcode secrets or credentials.
- Keep configuration externalized.

Example:

```properties
spring.datasource.url=${DB_URL}
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}
```

---

# Testing Instructions

Before completing tasks:

- Run all existing tests.
- Ensure project builds successfully.
- Verify no compilation issues.
- Check formatting.
- Validate API endpoints.

Maven commands:

```bash
./mvnw clean test
./mvnw spring-boot:run
```

---

# Git Rules

- Do not commit directly to main.
- Use feature branches.
- Keep commits small and meaningful.

Commit format:

```text
feat: add user profile API
fix: resolve JWT expiration issue
refactor: simplify payment service
```

---

# AI Agent Instructions

## When Modifying Code

1. Read related files first.
2. Search for existing implementations before creating new ones.
3. Preserve current architecture.
4. Explain major changes.
5. Avoid generating placeholder code unless requested.
6. Do not invent APIs or database columns.
7. If unsure, ask for clarification instead of guessing.

---

# Performance Guidelines

- Avoid N+1 queries.
- Prefer pagination.
- Use caching when appropriate.
- Avoid loading unnecessary data.
- Optimize SQL queries.

---

# Logging

- Use structured logging.
- Log errors with context.
- Avoid excessive debug logs in production.
- Never log passwords or tokens.

---

# Docker Rules

- Keep images lightweight.
- Use multi-stage builds when possible.
- Externalize configs.
- Avoid hardcoded ports.

---

# Documentation

- Update README when adding major features.
- Add comments only where logic is complex.
- Keep API docs updated.

---

# Preferred Development Flow

1. Understand requirement
2. Inspect related modules
3. Plan minimal changes
4. Implement
5. Test locally
6. Verify edge cases
7. Document important updates

---

# Local Development Commands

## Run Backend

```bash
./mvnw spring-boot:run
```

## Build Project

```bash
./mvnw clean package
```

## Run Docker

```bash
docker compose up --build
```

---

# Important Constraints

- Do not change environment configs unnecessarily.
- Do not rename public APIs without instruction.
- Do not introduce heavy dependencies casually.
- Keep memory and CPU usage reasonable.

---

# Preferred AI Output Style

When responding:

- Be concise.
- Show exact file changes.
- Explain why changes are needed.
- Provide commands when useful.
- Mention potential risks.
- Prefer production-ready code.

---

# Repository Structure Example

```text
src/
 ├── controller/
 ├── service/
 ├── repository/
 ├── dto/
 ├── entity/
 ├── config/
 ├── security/
 └── exception/
```

---

# Final Checklist For AI Agents

Before finishing:

- [ ] Project builds successfully
- [ ] No syntax errors
- [ ] No unused imports
- [ ] No hardcoded secrets
- [ ] API responses validated
- [ ] Edge cases considered
- [ ] Logs are clean
- [ ] Documentation updated if needed
