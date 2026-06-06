# Attack Surface Categories & Deep Analysis Guide

## Categories

| ID         | Name                     | What to look for                                                                 |
|------------|--------------------------|---------------------------------------------------------------------------------|
| `secrets`  | Secrets & credentials    | Hardcoded API keys, JWT secrets, DB passwords, tokens in source or config       |
| `injection`| Injection flaws          | SQL injection, command injection, SSTI, LDAP injection, path traversal, XSS     |
| `auth`     | Auth & access control    | Broken JWT validation, missing authz checks, IDOR, privilege escalation, CSRF   |
| `deps`     | Dependency risks         | CVEs in pom.xml / package.json / requirements.txt, unpinned or abandoned libs   |
| `config`   | Misconfigurations        | CORS wildcards, missing security headers, debug endpoints, insecure defaults     |
| `exposure` | Sensitive data exposure  | PII/secrets in logs, verbose stack traces in responses, debug flags in prod      |
| `docker`   | Container security       | Privileged containers, root user in image, exposed secrets in ENV, no healthcheck|
| `cicd`     | CI/CD & supply chain     | Unpinned Actions, workflow injection via `${{ github.event.* }}`, OIDC misuse   |

## Deep Analysis Per Category

### `secrets`
- Search for patterns: `(?i)(password|passwd|pwd|secret|api[_-]?key|token|auth[_-]?key|private[_-]?key)\s*[=:]\s*['"]?[A-Za-z0-9+/]{8,}`
- Check `.env.example` for real values (not placeholders)
- Check git history for accidental commits later "fixed" — the secret is still in history
- Check CI/CD env vars hardcoded in workflow YAML (not via secrets context)
- Severity: CRITICAL if real credential; HIGH if placeholder pattern that gets used

### `injection`
- Java/Spring: Look for string-concatenated JPQL/HQL/SQL, `Runtime.exec()`, `ProcessBuilder`, SpEL injection in ` @Value`, Thymeleaf SSTI
- Node.js: `eval()`, `new Function()`, `child_process.exec`, template literal SQL, `__proto__` merges
- Python: `os.system()`, `subprocess.call(shell=True)`, f-string SQL, `pickle.loads()`
- Any: Path traversal via unsanitised `../` in file download endpoints
- Severity: CRITICAL for SQL/command injection with user input; HIGH for path traversal

### `auth`
- JWT: Check algorithm (`alg: none` acceptance, symmetric vs asymmetric mismatch, no expiry check)
- Spring Security: `permitAll()` on sensitive paths, missing ` @PreAuthorize`, CSRF disabled
- Check if user-supplied IDs are validated against the authenticated principal (IDOR)
- OAuth2: Check redirect_uri validation, state parameter presence, token storage in localStorage
- Severity: CRITICAL for auth bypass; HIGH for IDOR/privilege escalation

### `deps`
- Cross-reference key dependencies and their declared versions against known CVEs:
  - Spring Boot < 2.7.x: multiple CVEs
  - Log4j 1.x or 2.0–2.14.1: Log4Shell (CVE-2021-44228)
  - Jackson-databind < 2.13.x: deserialization CVEs
  - lodash < 4.17.21: prototype pollution
  - axios < 0.21.1: SSRF
  - Spring Security < 5.7.x: various auth bypass CVEs
- Flag unpinned versions (`latest`, `*`, ranges without upper bound)
- Severity: CRITICAL for actively exploited CVEs; HIGH for known CVEs with available PoCs

### `config`
- CORS: `allowedOrigins("*")` with `allowCredentials(true)` — critical combination
- Missing headers: `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`, `Content-Security-Policy`
- Spring Actuator endpoints exposed without auth (`/actuator/env`, `/actuator/heapdump`)
- `management.endpoints.web.exposure.include=*` in properties
- Severity: HIGH for CORS misconfig; MEDIUM for missing headers

### `exposure`
- Logging: `log.info("password: " + password)`, logging full request bodies with auth headers
- Error handling: returning raw stack traces in API responses (`e.printStackTrace()` to response)
- Debug flags: `spring.jpa.show-sql=true`, `DEBUG=*` in production config
- Severity: HIGH for credential logging; MEDIUM for stack trace exposure

### `docker`
- `USER root` or no USER directive (runs as root)
- Secrets passed via `--build-arg` or `ENV` (visible in image layers)
- `--privileged` flag in docker-compose
- Base images: `latest` tag, known vulnerable base (e.g., `node:14`, `python:3.8`)
- Multi-stage build missing (secrets in build stage persist)
- Severity: HIGH for root user; CRITICAL for secrets in image layers

### `cicd`
- Workflow injection: `run: echo ${{ github.event.issue.title }}` — unsanitised user input into shell
- Unpinned actions: `uses: actions/checkout @main` instead of a commit SHA
- `pull_request_target` with checkout of untrusted code + secrets access
- GITHUB_TOKEN with excessive permissions (`permissions: write-all`)
- Secrets printed in run steps (`echo $SECRET`)
- Severity: CRITICAL for workflow injection; HIGH for unpinned actions with secrets access