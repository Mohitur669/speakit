# Running the Dependabot → Actions → AI agent pipeline

Destination: `docs/dependabot-pipeline-setup.md`

Setup is steps 1–4 and takes about ten minutes. Steps 5–7 are the loop you run from then on.

---

## Step 1 — Prerequisites

| Need | Check | If missing |
| --- | --- | --- |
| Dependabot alerts enabled | repo → Settings → Advanced Security → Dependabot alerts | turn it on, wait for the first scan |
| Python 3.10+ | `python3 --version` | install 3.12 |
| `jq` | `jq --version` | `sudo apt install jq` / `brew install jq` |
| GitHub CLI, authenticated | `gh auth status` | `gh auth login` |
| Your agent CLI | `agy --version` | any CLI that reads a prompt on stdin works |

For local PDF rendering, WeasyPrint needs system libraries:

```bash
sudo apt-get install -y libpango-1.0-0 libpangoft2-1.0-0 libharfbuzz0b libffi-dev libjpeg-turbo8
# macOS: brew install pango libffi
```

Skip this if you only ever build PDFs in CI — pass `--no-pdf` locally.

---

## Step 2 — Place the files

```
.github/scripts/dependabot_report.py
.github/scripts/requirements.txt
.github/workflows/dependabot-report.yml
scripts/dependency-vapt-pipeline/fix-alerts.sh
scripts/dependency-vapt-pipeline/generate-vapt-reports.sh
scripts/dependency-vapt-pipeline/auto-fix-npm.py
docs/dependabot-pipeline.md          # the diagrams
docs/dependabot-pipeline-setup.md    # this file
```

```bash
chmod +x scripts/dependency-vapt-pipeline/*.sh
chmod +x scripts/dependency-vapt-pipeline/*.py
echo "reports/" >> .gitignore
```

Everything under `reports/` is regenerated on every run — never commit it.

---

## Step 3 — Confirm your token can read alerts

The Dependabot alerts API is stricter than the rest of the REST API. Test before you
wire anything up:

```bash
gh api /repos/Mohitur669/speakit/dependabot/alerts --jq 'length'
```

- **A number** → your `gh` token works locally, and `GITHUB_TOKEN` will very likely work in CI via the `vulnerability-alerts: read` permission already declared in the workflow.
- **403** → create a PAT and add it as a repo secret:
  1. GitHub → Settings → Developer settings → Personal access tokens → Fine-grained.
  2. Repository access: `speakit`. Permission: **Dependabot alerts → Read-only**. (Classic token equivalent: the `security_events` scope.)
  3. Repo → Settings → Secrets and variables → Actions → New secret, named `DEPENDABOT_TOKEN`.

The workflow already falls back to that secret: `${{ secrets.DEPENDABOT_TOKEN || github.token }}`.

---

## Step 4 — First run, locally

Faster feedback than pushing and waiting on CI. Use the all-in-one setup script which automatically creates a virtual environment, installs dependencies, verifies GitHub authentication, and runs the report generator:

```bash
./scripts/dependency-vapt-pipeline/generate-vapt-reports.sh
```

Expected console output:

```
5 alert(s) written to reports/dependabot/
  HIGH     vite -> 7.3.5 (5 alerts)
```

Check what landed:

```bash
ls reports/dependabot reports/dependabot/agent
xdg-open reports/dependabot/report.pdf     # macOS: open
cat reports/dependabot/agent-queue.json | jq '.[0]'
```

Useful flags while you tune it:

| Flag | Effect |
| --- | --- |
| `--state all` | include fixed and dismissed alerts, not just open ones |
| `--min-severity high` | drop the noise, keep high and critical |
| `--no-pdf` | skip WeasyPrint entirely |
| `--no-images` | skip screenshot fetching (much faster) |
| `--out /tmp/dbrep` | write somewhere other than `reports/dependabot` |
| `--fail-on critical` | exit 1 when a critical alert is open |

---

## Step 5 — First run in CI

```bash
git add .github scripts docs .gitignore
git commit -m "ci: add Dependabot report pipeline"
git push
```

Trigger it by hand rather than waiting for Monday:

```bash
gh workflow run dependabot-report.yml -f state=open -f min_severity=low
gh run watch
```

Then open the run — the job summary page shows the alert table, and the
`dependabot-report-<number>` artifact holds the full bundle including the PDF.

---

## Step 6 — Pull the bundle down

```bash
gh run download -n dependabot-report-42 -D reports/dependabot
```

Or skip CI entirely and regenerate in place using the setup script:

```bash
./scripts/dependency-vapt-pipeline/generate-vapt-reports.sh
```

---

## Step 7 — Fast-track NPM Fixes

For frontend repositories, NPM vulnerabilities often come in large batches that are tedious to process one-by-one. After generating the queue, run the automated bulk script to instantly handle all `npm` vulnerabilities:

```bash
./scripts/dependency-vapt-pipeline/auto-fix-npm.py
```

This loops through the `npm` alerts in `agent-queue.json`, updates `package.json`, tests the build, and creates commits on `vapt-fix` automatically.

---

## Step 8 — Work the remaining queue

Always dry-run first, so you can see the branch names and commands before anything moves:

```bash
./scripts/dependency-vapt-pipeline/fix-alerts.sh --dry-run
```

Then for real:

```bash
./scripts/dependency-vapt-pipeline/fix-alerts.sh
```

Per alert it will: cut `fix/dependabot-<n>-<pkg>` off your current branch, pipe the fix
brief into `agy`, run the verify command, print the diff, and wait for your yes before
committing. `s` skips, `q` stops.

| Situation | Command |
| --- | --- |
| One specific alert | `./scripts/dependency-vapt-pipeline/fix-alerts.sh --only 24` |
| Resume after quitting at 3 of 7 | `./scripts/dependency-vapt-pipeline/fix-alerts.sh --from 3` |
| Unattended, no prompts | `./scripts/dependency-vapt-pipeline/fix-alerts.sh --auto` |
| Different agent | `AGENT_CMD="claude -p" ./scripts/dependency-vapt-pipeline/fix-alerts.sh` |
| Override verification | `VERIFY_CMD="npm --prefix frontend ci && npm --prefix frontend run build" ./scripts/dependency-vapt-pipeline/fix-alerts.sh` |

The auto-detected verify command for this repo is the frontend install + build + test,
since `frontend/package.json` exists. If an alert lands on the Spring Boot side, set
`VERIFY_CMD="./mvnw -B verify"` for that run.

Afterwards, push and open PRs:

```bash
git branch --list 'fix/dependabot-*'
git push -u origin fix/dependabot-24-vite
gh pr create --fill
```

Read `reports/dependabot/fix-log.md` for the verdict on each attempt.

---

## Optional — Fire the report the moment an alert opens

GitHub has no `dependabot_alert` workflow trigger, so bridge the webhook to
`repository_dispatch`. A Cloudflare Worker is enough:

1. Repo → Settings → Webhooks → Add webhook, events: **Dependabot alerts** only, pointing at the worker.
2. Worker:

```js
export default {
  async fetch(req, env) {
    if (req.method !== "POST") return new Response("no", { status: 405 });
    const body = await req.json();
    if (body.action !== "created") return new Response("ignored");
    await fetch("https://api.github.com/repos/Mohitur669/speakit/dispatches", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.DISPATCH_TOKEN}`,   // PAT with contents: write
        Accept: "application/vnd.github+json",
        "User-Agent": "dependabot-bridge",
      },
      body: JSON.stringify({ event_type: "dependabot-alert" }),
    });
    return new Response("dispatched");
  },
};
```

Verify the webhook's HMAC signature before trusting the payload if the worker is public.

---

## Optional — Block merges on critical alerts

Add `--fail-on critical` to the generator step in the workflow, then make
`Dependabot Report` a required status check on `main`. The report still uploads;
the job just goes red.

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `403 from the Dependabot alerts API` | token lacks the alerts permission | Step 3 — add `DEPENDABOT_TOKEN` |
| `404 for <repo>` | wrong repo path, or alerts disabled | check Settings → Advanced Security |
| `PDF rendering skipped: cannot load library 'gobject-2.0'` | missing Pango/Cairo | install the system libs in Step 1, or use `--no-pdf` |
| Screenshots show as "image not embedded" | GitHub's signed image URLs expire in minutes | expected; the alert link is kept alongside. Run the report sooner after the alert opens if you need them inline |
| `target_version: null` in the queue | no patched release exists yet | the brief says so — mitigate or dismiss with a rationale, don't invent a version |
| Agent keeps touching unrelated files | brief not being read | check `AGENT_CMD` actually consumes stdin; test with `agy < reports/dependabot/agent/alert-24-vite.md` |
| Verification fails on every alert | wrong auto-detected command | set `VERIFY_CMD` explicitly |
| Same alert reappears after the fix | lockfile not committed, or a transitive pin missing | ensure the `overrides`/`resolutions` entry and the lockfile are both in the commit |

---

## Day-to-day cheat sheet

```bash
# 1. generate the queue
./scripts/dependency-vapt-pipeline/generate-vapt-reports.sh

# 2. fast-track the simple npm fixes automatically
./scripts/dependency-vapt-pipeline/auto-fix-npm.py

# 3. fix complex alerts with the AI loop (skips already fixed npm ones)
./scripts/dependency-vapt-pipeline/fix-alerts.sh

# CI on demand
gh workflow run dependabot-report.yml && gh run watch
```
