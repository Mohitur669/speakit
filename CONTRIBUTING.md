# Contributing to SpeakIT

Thank you for your interest in contributing to SpeakIT! As a production-grade AI platform, we maintain high standards for code quality, security, and architectural consistency.

Please read our [AGENTS.md](./agents.md) for a deep dive into our engineering standards before starting.

---

## ⚖️ Legal & Licensing

SpeakIT is distributed under a **Dual-Licensing Model** (AGPLv3 + Commercial).

By contributing to this repository, you agree that:
1. Your contributions will be licensed under the **GNU AGPLv3**.
2. You grant the maintainers a non-exclusive, worldwide, royalty-free, sublicensable, and transferable license to use, copy, modify, and distribute your contributions as part of our commercial offerings.
3. You may be required to sign a **Contributor License Agreement (CLA)** before your first Pull Request is merged.

---

## 🛠 Engineering Standards

All contributions must adhere to the following core principles:

### Backend (Spring Boot)
- **Data Access:** Use JPA **Interface Projections** for read operations. Avoid fetching full entities on hot-paths.
- **Performance:** Use `userRepository.getReferenceById(id)` when linking relationships to avoid N+1 issues.
- **ID Strategy:** Use `GenerationType.SEQUENCE` for all primary keys.
- **Sanitization:** Sanitize all user-provided text using `Sanitizer.sanitize()` before validation.
- **Auditing:** All entities must extend `BaseEntity`.

### Frontend (Angular)
- **Signals:** Use Angular **Signals** for local and global state management. Avoid legacy RxJS patterns where Signals are appropriate.
- **Modularity:** Ensure all new components are **Standalone**.
- **Observability:** Use `LoggerService` for all logs. Never use `console.log` directly.
- **UI:** Maintain design consistency using Tailwind CSS utility classes.

---

## 🔄 Development Workflow

1. **Fork** the repository and create your feature branch:
   ```bash
   git checkout -b feature/amazing-feature
   ```

2. **Develop & Hardent:** Ensure your code follows the [Conventional Commits](https://www.conventionalcommits.org/) specification:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `chore:` for maintenance
   - `refactor:` for architectural improvements

3. **Verify Locally:**
   - **Backend:** `./mvnw clean compile` must succeed.
   - **Frontend:** `npm run build` must succeed with zero compiler warnings.

4. **Submit a Pull Request:**
   - Clearly describe the architectural impact of your change.
   - Attach screenshots/videos for UI changes.
   - Mention any new environment variables required.

---

## 🧪 Testing Requirements

- **Bug Fixes:** Include a regression test case or reproduction script.
- **Features:** Provide unit tests for core business logic in the service layer.
- **Verification:** Monitor Hibernate logs (`spring.jpa.show-sql=true`) to ensure no new N+1 query loops were introduced.

---

## 💬 Community & Help

- **Code of Conduct:** Please follow our [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md).
- **Issues:** Use GitHub Issues for bug reports and feature requests.
- **Discussions:** Use GitHub Discussions for architectural questions.

---

_Built with integrity for the future of AI speech._
