# VAPT Alert Remediation Agent

Destination: `scripts/dependency-vapt-pipeline/fix-vapt-alerts.md`

Invoke with something like:
`agy "read scripts/dependency-vapt-pipeline/fix-vapt-alerts.md and follow it"`

---

You are fixing dependency vulnerabilities (VAPT alerts) in this repository, one at a
time, with full context of the codebase. You have shell access. Work autonomously
through the list below; only stop early for the conditions in **Stop conditions**.

## 0. Locate your inputs

Read these, in order:

1. `reports/dependabot/agent-queue.json` — the ordered list of alerts to fix, each
   with `alert_number`, `severity`, `package`, `ecosystem`, `manifest`,
   `current_range`, `target_version`, `closes_alerts`, and a `brief` path.
2. `reports/dependabot/alerts.json` — full raw API payload, for anything the queue
   entry doesn't cover.
3. `reports/dependabot/agent/<brief>` — one file per queue entry, with the exact
   upgrade command for that ecosystem, constraints, and acceptance criteria.

If `reports/dependabot/agent-queue.json` does not exist or looks older than a day,
regenerate it before doing anything else:

```bash
python .github/scripts/dependabot_report.py --repo <owner>/<repo> --out reports/dependabot
```

If that also fails (missing token, alerts disabled), stop and report the error —
don't guess at what the alerts might be.

## 1. Check what's already done

Before starting, check whether some of the queue is already fixed:

```bash
git log --oneline --grep="dependabot alert" -i
```

Cross-reference commit messages against `closes_alerts` in the queue. Skip any
group whose alerts are already closed by an existing commit on the current branch
history. If unsure whether something is really fixed, verify it yourself (check the
manifest version) rather than trusting the commit message alone.

## 2. Work the queue, one group at a time

The queue is already ordered by severity, then by how many alerts each upgrade
closes. Multiple `alert_number`s sharing the same `package` + `manifest` are one
unit of work — fix them together with a single upgrade, not one at a time.

For each remaining group:

1. **Read the brief(s)** for every alert in the group. Note `target_version`, the
   exact upgrade mechanism given for the ecosystem, and the acceptance criteria.
2. **Branch**: `git switch -c fix/dependabot-<lowest-alert-number>-<package-slug>`
   off your current base branch.
3. **Apply the minimal fix**:
   - Direct dependency → bump it to `target_version` in the manifest.
   - Transitive dependency → use an override/resolution/dependencyManagement pin
     as the brief specifies, rather than trying to bump the parent unless the
     brief says the parent itself needs bumping.
   - Update the lockfile through the package manager (`npm install`, `mvn
     dependency:tree` verification, etc.) — never hand-edit a lockfile.
   - Touch nothing else. No refactors, no formatting sweeps, no unrelated version
     bumps, even if you notice other outdated packages along the way.
4. **Verify**:
   - Install/resolve from a clean state.
   - Build.
   - Run the test suite.
   - Confirm the installed version of the package now satisfies `target_version`
     (`npm ls <pkg>`, `mvn dependency:tree -Dincludes=<pkg>`, etc.) and that no
     new Dependabot-relevant vulnerability was introduced by the bump (check the
     lockfile diff for other packages that moved).
5. **On success**: commit.
   ```
   fix(deps): bump <package> to <target_version>

   Closes dependabot alert #<n>, #<n>, ...
   ```
   Then switch back to the base branch so the next group starts clean.
6. **On failure** (build breaks, tests fail, or the bump forces a breaking API
   change you're not confident fixing correctly):
   - Do not force it through or paper over a failing test.
   - Leave the branch as-is, uncommitted or committed-but-flagged — your choice,
     whichever leaves the clearest trail for a human to pick up.
   - Record it as blocked (see **Reporting**) with the specific error and what
     you tried.
   - Move on to the next group. One blocked alert never stops the run.
7. **No patched version available** (`target_version` is null): don't invent one.
   Record it as needing a manual mitigation or a dismissal decision — don't touch
   code for it.

## 3. Reporting

Keep a running log at `reports/dependabot/fix-log.md`, appending as you go (don't
wait until the end — a run that's interrupted should still leave a partial log):

```
## Run <date>
- #24, #25, #26 vite -> 7.3.5 — fixed, branch fix/dependabot-24-vite, verified
- #31 lodash -> 4.17.22 — blocked: test suite fails after bump, see notes
- #40 some-pkg — no patched version available, needs manual mitigation
```

When the queue is exhausted (or you hit a stop condition), give a final summary in
your response: how many groups fixed, how many blocked and why, how many with no
patch, and the branch names ready for PRs.

## Rules

- Treat `agent-queue.json` and `alerts.json` as read-only inputs — never edit them.
- One branch per group, never batch unrelated groups onto the same branch.
- Never downgrade a package to "fix" an alert — only upgrade to `target_version`
  or higher.
- Never suppress, skip, or delete a failing test to make verification pass.
- If a fix requires a genuinely breaking migration (API renamed, config format
  changed), write out the migration steps in the log instead of attempting a
  half-correct automated rewrite.
- Prefer the ecosystem's own tooling (npm/mvn/gradle/pip/cargo) for every version
  change — never hand-edit a lockfile's hashes or resolved versions.

## Stop conditions

Pause and report to the user instead of continuing when:

- Three groups in a row fail verification — likely something environmental
  (missing build tool, wrong Node/Java version) rather than a real per-package
  problem.
- A fix would require modifying CI/CD configuration, secrets, or infrastructure
  code rather than application dependencies.
- You cannot determine the correct verification command for a manifest you
  don't recognize.

Otherwise, run to completion through the whole queue.