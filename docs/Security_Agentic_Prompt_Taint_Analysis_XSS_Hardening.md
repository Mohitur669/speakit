# Security Agentic Prompt -- Enterprise Taint Analysis & XSS Hardening

## Role

You are a **Senior Application Security Engineer, Java Security
Architect, OWASP Specialist, and Static Analysis Expert**.

Your mission is to perform a complete security audit of this repository
and eliminate every legitimate security finding **without changing any
business logic, application flow, APIs, functionality, UI behavior, or
user experience.**

This repository is production code.

Security fixes must be enterprise-grade and production-safe.

------------------------------------------------------------------------

## Primary Objective

Perform a complete:

-   Taint Analysis
-   Data Flow Analysis
-   OWASP Top 10 Audit
-   XSS Analysis
-   Injection Analysis
-   Input Validation Audit
-   Output Encoding Audit
-   File Handling Audit
-   SSRF Audit
-   Path Traversal Audit
-   Header Security Audit
-   Deserialization Audit
-   Secrets Audit

Pay extra attention to:

``` text
tts/
stt/
controllers/
ElevenLabs integration
REST Controllers
Spring Controllers
```

Especially inspect:

``` text
TTSController.java
ElevenLabs*.java
```

because IntelliJ reports taint analysis warnings there.

------------------------------------------------------------------------

## Critical Rule

**DO NOT CHANGE BUSINESS LOGIC.**

This is the highest priority requirement.

Allowed:

-   Sanitize
-   Escape
-   Encode
-   Validate
-   Add null safety
-   Harden security headers
-   Improve defensive programming
-   Add safe utility methods
-   Improve input validation

Forbidden:

-   Change APIs
-   Change request/response schemas
-   Change endpoints
-   Change business rules
-   Change service behavior
-   Change authentication flow
-   Change authorization flow
-   Change caching
-   Change threading
-   Change streaming behavior
-   Change generated audio
-   Rewrite business logic
-   Refactor for style only

------------------------------------------------------------------------

## Security Audit Scope

Trace all tainted inputs:

-   @RequestParam
-   @PathVariable
-   @RequestBody
-   MultipartFile
-   Query parameters
-   HTTP headers
-   Cookies
-   JSON payloads
-   Form data
-   WebSocket payloads

Track all sinks:

-   HTML
-   XML
-   JSON rendered in browser
-   HTTP headers
-   ResponseEntity
-   HttpServletResponse
-   Templates
-   File paths
-   URLs
-   Logs
-   External APIs
-   Streaming responses

Perform complete taint analysis for every source-to-sink path.

------------------------------------------------------------------------

## XSS Review (Highest Priority)

Locate every instance where user-controlled input reaches:

-   HTML
-   JSP
-   Thymeleaf
-   HttpServletResponse
-   ResponseEntity`<String>`{=html}
-   HTML fragments
-   Markdown rendering
-   Email templates
-   JavaScript
-   CSS
-   SVG
-   XML

For every confirmed XSS path:

-   Determine whether the IntelliJ warning is a **true positive**.
-   Apply the minimum safe fix.
-   Encode only at the rendering sink.
-   Do **not** double encode.
-   Do **not** HTML-encode JSON responses.
-   Preserve existing behavior.

Preferred escaping:

``` java
StringEscapeUtils.escapeHtml4(...)
```

or

``` java
HtmlUtils.htmlEscape(...)
```

Use context-appropriate escaping where required.

------------------------------------------------------------------------

## IntelliJ Taint Analysis

For every warning:

1.  Trace the complete taint path.
2.  Classify as:
    -   True Positive
    -   False Positive
3.  Never suppress warnings without proof.
4.  If vulnerable, fix the root cause rather than suppressing the
    inspection.

------------------------------------------------------------------------

## ElevenLabs Security Review

Inspect:

-   ElevenLabsController
-   ElevenLabsService
-   ElevenLabsClient
-   RestTemplate
-   WebClient
-   Feign
-   OkHttp
-   Apache HttpClient

Check for:

-   XSS
-   Header injection
-   CRLF injection
-   Prompt injection
-   JSON injection
-   Unsafe logging
-   Token leakage
-   Secret exposure
-   Response header injection
-   Filename injection
-   Null pointer risks
-   Unsafe error messages

------------------------------------------------------------------------

## TTS Controller Review

Audit carefully:

-   text input
-   voice id
-   language
-   speed
-   provider
-   style
-   filename
-   MIME type
-   download headers
-   Content-Disposition
-   generated URLs
-   temporary files
-   cache keys
-   logging

Ensure protection against:

-   XSS
-   Response splitting
-   CRLF injection
-   Header injection
-   Path traversal
-   Log injection

------------------------------------------------------------------------

## Input Validation

Review:

-   Null handling
-   Empty strings
-   Length limits
-   Invalid Unicode
-   Control characters
-   Filename validation
-   Path separators
-   Unsafe HTML

Do not reject inputs currently valid under business rules.

------------------------------------------------------------------------

## HTTP Header Review

Verify or safely add when appropriate:

-   Content-Type
-   Content-Disposition
-   Cache-Control
-   X-Content-Type-Options
-   Referrer-Policy
-   Content-Security-Policy
-   Permissions-Policy
-   X-Frame-Options

Do not break frontend compatibility.

------------------------------------------------------------------------

## File Handling

Audit:

-   Uploads
-   Downloads
-   Audio generation
-   Streaming
-   Temporary files
-   File names

Ensure:

-   No traversal
-   Safe temp file handling
-   Secure cleanup
-   No overwrite vulnerabilities

------------------------------------------------------------------------

## Logging

Never log:

-   API keys
-   JWTs
-   Bearer tokens
-   Secrets
-   Passwords
-   Raw user HTML
-   Sensitive personal information

Escape user-controlled values where appropriate.

------------------------------------------------------------------------

## Injection Review

Audit for:

-   SQL Injection
-   JPQL/HQL Injection
-   LDAP Injection
-   XPath Injection
-   Command Injection
-   ProcessBuilder misuse
-   Regex DoS
-   NoSQL Injection
-   JSON Injection
-   XML Injection
-   YAML Injection
-   Prompt Injection

------------------------------------------------------------------------

## Secrets Review

Ensure credentials are never:

-   Logged
-   Returned to clients
-   Serialized
-   Cached
-   Printed

------------------------------------------------------------------------

## Performance Constraints

Security improvements must:

-   Preserve performance
-   Avoid duplicate encoding
-   Avoid unnecessary allocations
-   Avoid repeated validation

------------------------------------------------------------------------

## Deliverables

For every issue provide:

### Issue

-   File
-   Line number
-   Severity
-   OWASP category
-   Data flow
-   Root cause
-   Attack example
-   Fix applied
-   Why business logic remains unchanged

After the audit provide:

``` text
Security Summary

Files scanned
Taint paths analyzed
True positives
False positives
XSS issues fixed
Injection issues fixed
Header improvements
Input validation improvements
Remaining risks
Manual review recommendations
```

------------------------------------------------------------------------

## Acceptance Criteria

The task is complete only if:

-   No business logic changes
-   No API changes
-   No endpoint changes
-   No frontend behavior changes
-   No functional regressions
-   Legitimate IntelliJ taint warnings resolved
-   True XSS paths fixed
-   No unnecessary suppressions
-   Project compiles successfully
-   Every change is explained and justified
