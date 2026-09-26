# Workspace Rules

- **Git Commits & Pushes:** Do not automatically perform `git commit` or `git push` commands. Always ask the user for explicit permission before staging (`git add`), committing (`git commit`), or pushing (`git push`) any code changes.
- **Keychain & GitHub CLI (`gh`):** The AI agent must NEVER read, query, extract, or interact with macOS Keychain or iCloud Keychain (e.g. `security`, `git credential-osxkeychain`, or any credential helper). For any GitHub operations (pull requests, issues, releases), the agent must ONLY use the official GitHub CLI (`gh`). If `gh` is not installed or authenticated, prompt the user or provide the manual web link instead.
- **Dependabot Pipeline:** IMPORTANT - The AI agent must completely ignore `scripts/dependency-vapt-pipeline/fix-alerts.py`. Do not run, modify, or interact with this script during the fix process.
- **Legal & Company Content Synchronization (Frontend & iOS):** Whenever any legal, policy, or company content is created, modified, or updated in the frontend (`frontend/src/app/features/marketing/legal/terms`, `privacy`, `about`, `contact`, or `blog`), the corresponding native in-app sheets in the iOS app (`TermsOfServiceSheet.swift`, `PrivacyPolicySheet.swift`, `AboutSpeakITSheet.swift`, `ContactSupportSheet.swift`, and `BlogUpdatesSheet.swift`) must always be synchronized to maintain exact content parity. Never redirect iOS users to external web links for legal or company information; always present native in-app views.

---

> For the comprehensive architectural blueprint, backend standards, frontend signals guidelines, database rules, and API design, see the root [AGENTS.md](../AGENTS.md).
