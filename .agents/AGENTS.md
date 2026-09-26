# Workspace Rules

- **Git Commits & Pushes:** Do not automatically perform `git commit` or `git push` commands. Always ask the user for explicit permission before staging (`git add`), committing (`git commit`), or pushing (`git push`) any code changes.
- **Keychain & GitHub CLI (`gh`):** The AI agent must NEVER read, query, extract, or interact with macOS Keychain or iCloud Keychain (e.g. `security`, `git credential-osxkeychain`, or any credential helper). For any GitHub operations (pull requests, issues, releases), the agent must ONLY use the official GitHub CLI (`gh`). If `gh` is not installed or authenticated, prompt the user or provide the manual web link instead.
- **Dependabot Pipeline:** IMPORTANT - The AI agent must completely ignore `scripts/dependency-vapt-pipeline/fix-alerts.py`. Do not run, modify, or interact with this script during the fix process.

---

> For the comprehensive architectural blueprint, backend standards, frontend signals guidelines, database rules, and API design, see the root [AGENTS.md](../AGENTS.md).
