# Workspace Rules

- **Git Commits:** Do not automatically perform `git commit` commands. Always ask the user for explicit permission before staging or committing any code changes.
- **Dependabot Pipeline:** IMPORTANT - The AI agent must completely ignore `scripts/dependency-vapt-pipeline/fix-alerts.py`. Do not run, modify, or interact with this script during the fix process.
