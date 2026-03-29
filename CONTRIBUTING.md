# Contributing to SpeakIt

Thank you for your interest in contributing to SpeakIt! We welcome bug reports, feature requests, documentation improvements, and code contributions.

All changes must go through a feature branch — direct commits to `main` are not accepted.

---

## Workflow

1. **Fork** the repository.

2. **Create a feature branch** from `main`:

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes** with clear, focused commits using [Conventional Commits](https://www.conventionalcommits.org/) format:

   ```bash
   git commit -m "feat: add SSML markup support to synthesis request"
   git commit -m "fix: correct audio blob MIME type handling in Safari"
   git commit -m "docs: update environment variable reference table"
   ```

4. **Test locally** against both the Angular frontend and the Spring Boot backend before pushing.

5. **Push your branch** and open a Pull Request against `main`:
   ```bash
   git push origin feature/your-feature-name
   ```
   Include a clear description of what was changed and why.

> Branches not following the `feature/*` naming convention will be asked to rename before merging.

---

## Code Style

- **Frontend:** Follow the [Angular Style Guide](https://angular.dev/style-guide). Run `ng lint` before committing.
- **Backend:** Follow standard Java/Spring Boot conventions. Ensure the project builds cleanly with `./mvnw verify`.
- **Commits:** Use [Conventional Commits](https://www.conventionalcommits.org/) — prefixes: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`.

---

## Submitting Changes

1. Push your branch to your fork
2. Open a pull request against `main`
3. Describe the problem, solution, and test coverage
4. Link related issues if present

---

## Branching and Reviews

- Use descriptive commit messages
- Follow conventional commit style if possible
- Address review feedback promptly

---

## Code of Conduct

This project follows a code of conduct. Please be respectful and inclusive: see `CODE_OF_CONDUCT.md`.
