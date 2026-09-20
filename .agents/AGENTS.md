# Workspace Rules

- **Git Commits & Pushes:** Do not automatically perform `git commit` or `git push` commands. Always ask the user for explicit permission before staging (`git add`), committing (`git commit`), or pushing (`git push`) any code changes.
- **Dependabot Pipeline:** IMPORTANT - The AI agent must completely ignore `scripts/dependency-vapt-pipeline/fix-alerts.py`. Do not run, modify, or interact with this script during the fix process.

---

> For the comprehensive architectural blueprint, backend standards, frontend signals guidelines, database rules, and API design, see the root [AGENTS.md](../AGENTS.md).
