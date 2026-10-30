# Workspace Rules

- **Git Commits & Pushes:** Do not automatically perform `git commit` or `git push` commands. Always ask the user for explicit permission before staging (`git add`), committing (`git commit`), or pushing (`git push`) any code changes.
- **Git Branch Creation:** Never create new branches out of the blue or without explicit user permission. Always work on the user's active/designated branch unless explicitly instructed to create a new branch.
- **Keychain & GitHub CLI (`gh`):** The AI agent must NEVER read, query, extract, or interact with macOS Keychain or iCloud Keychain (e.g. `security`, `git credential-osxkeychain`, or any credential helper). For any GitHub operations (pull requests, issues, releases), the agent must ONLY use the official GitHub CLI (`gh`). If `gh` is not installed or authenticated, prompt the user or provide the manual web link instead.
- **Dependabot Pipeline:** IMPORTANT - The AI agent must completely ignore `scripts/dependency-vapt-pipeline/fix-alerts.py`. Do not run, modify, or interact with this script during the fix process.
- **Legal & Company Content Synchronization (Frontend & iOS):** Whenever any legal, policy, or company content is created, modified, or updated in the frontend (`frontend/src/app/features/marketing/legal/terms`, `privacy`, `about`, `contact`, or `blog`), the corresponding native in-app sheets in the iOS app (`TermsOfServiceSheet.swift`, `PrivacyPolicySheet.swift`, `AboutSpeakITSheet.swift`, `ContactSupportSheet.swift`, and `BlogUpdatesSheet.swift`) must always be synchronized to maintain exact content parity. Never redirect iOS users to external web links for legal or company information; always present native in-app views.
- **Python Environment (Miniconda):** Whenever Python is needed or executed, always use Miniconda and activate the environment with `conda activate localpython`.
- **Server Access, Remote DB & Background Execution Restrictions:** NEVER EVER login or connect directly to Oracle DB / remote databases, NEVER open ports / establish SSH tunnels / port forwarding, and NEVER run `spring-boot:run` in the background (e.g. background tasks / daemons). The AI agent must NEVER attempt to SSH into any server. In all these cases, ALWAYS ask the user first or provide manual command instructions for the user to execute themselves.

---

> For the comprehensive architectural blueprint, backend standards, frontend signals guidelines, database rules, and API design, see the root [AGENTS.md](../AGENTS.md).
