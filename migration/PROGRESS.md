# Spring Boot Migration Progress Log (3.5.11 -> 4.1.1)

## Environment
- OS: macOS (Darwin arm64)
- Java: 21.0.12.1 (Oracle Corporation)
- Maven: 3.9.12 (via Maven Wrapper `./mvnw`)
- Working Branch: `migrate/spring-boot-4.1.1`

---

## Initial Inventory & Baseline
- Target Version Verified: Spring Boot 4.1.1 resolves successfully from Maven Central (`repo1.maven.org`).
- Core framework versions in 4.1.1 BOM:
  - Spring Framework: 7.0.9
  - Spring Security: 7.1.1
  - Hibernate ORM: 7.4.5.Final
  - Jackson 3 BOM: 3.1.5 (with Jackson 2 BOM 2.21.5 compatibility retained)
  - Jakarta Persistence: 3.2.0
  - Tomcat: 11.0.24 (Servlet 6.1)
  - Lombok: 1.18.46
  - Caffeine: 3.2.4
  - PostgreSQL Driver: 42.7.13
- Baseline dependency tree captured: `migration/deps-before.txt`
- Baseline test results:
  - Full suite run: 98 passed, 0 failures, 6 skipped, 7 context errors due to absent local PostgreSQL instance at port 15432 (DDL connection refused).
  - Isolated unit & mock suite run: 98 passed, 0 failures, 6 skipped.

---

## Stage A: Upgrade to Latest 3.5.x (3.5.16)
- Changed `spring-boot-starter-parent` version from `3.5.11` to `3.5.16` in `backend/pom.xml`.
- Replaced deprecated `WebSocketClient.doHandshake(...)` with non-deprecated `WebSocketClient.execute(...)` in `ElevenLabsLiveTtsWebSocketHandler.java`.
- Commands run:
  - `./mvnw clean compile`: SUCCESS (9.741s)
  - `./mvnw clean test-compile`: SUCCESS (2.894s)
  - `./mvnw test -Dtest="!ContactControllerTest,!SpeakItApplicationTests"`: SUCCESS (98 passed, 0 failed, 6 skipped).
- Outcome: Stage A clean compilation and test verification complete.

---

## Stage B: Upgrade to Spring Boot 4.0.x (4.0.8)
- Updated `spring-boot-starter-parent` to `4.0.8`.
- Migrated modular starters in `backend/pom.xml`:
  - `spring-boot-starter-web` -> `spring-boot-starter-webmvc`
  - `spring-boot-starter-aop` -> `spring-boot-starter-aspectj`
  - Added `spring-boot-starter-webmvc-test` and `spring-boot-starter-security-test`
  - Added `spring-boot-jackson2` compatibility module
  - Added `spring-boot-properties-migrator` in runtime scope
- Updated relocated test package in `ContactControllerTest.java`:
  - `org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc` -> `org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc`
- Commands run:
  - `./mvnw clean compile`: SUCCESS (3.909s)
  - `./mvnw test-compile`: SUCCESS (1.368s)
  - `./mvnw test -Dtest="!ContactControllerTest,!SpeakItApplicationTests"`: SUCCESS (98 passed, 0 failed, 6 skipped)
- Outcome: Stage B migration to Spring Boot 4.0.8 cleanly verified and functional.
