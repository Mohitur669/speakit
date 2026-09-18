# Dependabot → GitHub Actions → AI agent pipeline

Destination: `docs/dependabot-pipeline.md` (GitHub renders these blocks natively).

Legend: solid arrows = control flow, dotted arrows = a file written or read.

## 1. End-to-end flow, with the artifact each step produces

```mermaid
flowchart TD
    subgraph TRIG["Triggers"]
        T1["schedule — Mon 07:00 IST"]
        T2["workflow_dispatch — state, min_severity"]
        T3["repository_dispatch — dependabot-alert webhook bridge"]
    end

    T1 --> JOB
    T2 --> JOB
    T3 --> JOB

    subgraph JOB[".github/workflows/dependabot-report.yml"]
        direction TB
        J1["checkout + setup-python 3.12"]
        J2["apt: pango, cairo, harfbuzz for WeasyPrint"]
        J3["pip install -r .github/scripts/requirements.txt"]
        J4["run dependabot_report.py"]
        J5["summary.md appended to GITHUB_STEP_SUMMARY"]
        J6["upload-artifact — retention 90 days"]
        J1 --> J2 --> J3 --> J4 --> J5 --> J6
    end

    J4 --> SCRIPT

    subgraph SCRIPT[".github/scripts/dependabot_report.py"]
        direction TB
        S1["fetch_alerts — paginated GET /repos/OWNER/REPO/dependabot/alerts"]
        S2["normalise — flatten advisory, vulnerability, dependency"]
        S3["group_upgrades — key on package plus manifest, take highest patched version"]
        S4["inline_images — embed advisory screenshots as data URIs"]
        S5["build_markdown and build_html"]
        S6["write_pdf — WeasyPrint"]
        S7["agent_brief — one fix task per alert"]
        S1 --> S2 --> S3 --> S4 --> S5 --> S6
        S3 --> S7
    end

    GH[("GitHub Security API")] --> S1

    subgraph OUT["reports/dependabot/"]
        direction TB
        O1["alerts.json — raw API payload"]
        O2["agent-queue.json — severity-ordered queue"]
        O3["agent/alert-N-pkg.md — fix briefs"]
        O4["report.md"]
        O5["report.html"]
        O6["report.pdf"]
        O7["summary.md"]
    end

    S1 -.-> O1
    S3 -.-> O2
    S7 -.-> O3
    S5 -.-> O4
    S5 -.-> O5
    S6 -.-> O6
    S3 -.-> O7
    O7 -.-> J5
    OUT -.-> J6

    J6 --> ART["CI artifact: dependabot-report-RUNNUMBER"]
    ART --> DL["gh run download -D reports/dependabot"]
    DL --> LOCAL

    subgraph LOCAL["scripts/dependency-vapt-pipeline/fix-alerts.sh — local machine"]
        direction TB
        L1["read agent-queue.json"]
        L2["branch fix/dependabot-N-pkg"]
        L3["pipe brief into AGENT_CMD, default agy"]
        L4["run VERIFY_CMD — install, build, test"]
        L5["show diff, wait for approval"]
        L6["commit, return to base branch"]
        L1 --> L2 --> L3 --> L4 --> L5 --> L6
        L6 --> L1
    end

    L3 -.-> AGENT[["Local agent with whole-codebase context"]]
    L6 -.-> LOG["reports/dependabot/fix-log.md"]

    classDef committed fill:#ddf4ff,stroke:#0969da,color:#0a3069
    classDef generated fill:#fff8c5,stroke:#9a6700,color:#4d2d00
    class JOB,SCRIPT,LOCAL committed
    class O1,O2,O3,O4,O5,O6,O7,LOG,ART generated
```

## 2. Files and folders — committed vs generated

```mermaid
flowchart LR
    ROOT["repo root"] --> DGH[".github/"]
    ROOT --> DSC["scripts/dependency-vapt-pipeline/"]
    ROOT --> DRP["reports/"]
    ROOT --> DDOC["docs/"]

    DGH --> DWF["workflows/"]
    DGH --> DSS["scripts/"]
    DWF --> F1["dependabot-report.yml"]
    DSS --> F2["dependabot_report.py"]
    DSS --> F3["requirements.txt"]
    DSC --> F4A["generate-vapt-reports.sh"]
    DSC --> F4B["auto-fix-npm.py"]
    DSC --> F4C["fix-alerts.sh"]
    DDOC --> F5["dependabot-pipeline.md"]

    DRP --> DDB["dependabot/"]
    DDB --> G1["alerts.json"]
    DDB --> G2["agent-queue.json"]
    DDB --> G3["report.md"]
    DDB --> G4["report.html"]
    DDB --> G5["report.pdf"]
    DDB --> G6["summary.md"]
    DDB --> G7["fix-log.md"]
    DDB --> DAG["agent/"]
    DAG --> G8["alert-24-vite.md"]
    DAG --> G9["alert-N-package.md"]

    classDef committed fill:#ddf4ff,stroke:#0969da,color:#0a3069
    classDef generated fill:#fff8c5,stroke:#9a6700,color:#4d2d00
    class F1,F2,F3,F4A,F4B,F4C,F5 committed
    class G1,G2,G3,G4,G5,G6,G7,G8,G9 generated
```

Add `reports/` to `.gitignore` — every file under it is regenerated on each run.

## 3. The local fix workflow

```mermaid
sequenceDiagram
    autonumber
    participant Dev as You
    participant Gen as generate-vapt-reports.sh
    participant Npm as auto-fix-npm.py
    participant Sh as fix-alerts.sh
    participant Repo as Working tree

    Dev->>Gen: ./scripts/dependency-vapt-pipeline/generate-vapt-reports.sh
    Gen->>Repo: Checks CLI auth, dependencies, generates queue
    Gen->>Npm: (Auto-triggers) fast-track NPM fixes
    Npm->>Repo: Loops through npm alerts, runs tests, commits automatically
    Npm-->>Gen: Returns
    Gen-->>Dev: Ready for AI handoff
    
    Dev->>Sh: ./scripts/dependency-vapt-pipeline/fix-alerts.sh (or AI handoff)
    Sh->>Repo: Skips already fixed npm packages
    loop for remaining complex alerts
        Sh->>Dev: ask run / skip / quit
        Dev-->>Sh: y
        Sh->>Repo: Delegate to AI agent or manual fix, test, and commit
    end
```

## 4. Where the data comes from inside one alert

```mermaid
flowchart LR
    API["Dependabot alert JSON"] --> A["security_advisory"]
    API --> V["security_vulnerability"]
    API --> D["dependency"]
    API --> M["alert metadata"]

    A --> A1["summary, description body"]
    A --> A2["ghsa_id, cve_id, identifiers"]
    A --> A3["cvss v3 and v4, epss, cwes"]
    A --> A4["references, published_at"]
    V --> V1["severity"]
    V --> V2["vulnerable_version_range"]
    V --> V3["first_patched_version"]
    D --> D1["manifest_path"]
    D --> D2["scope, relationship"]
    M --> M1["number, state, html_url, timeline"]

    A1 --> REP["report.pdf section"]
    A2 --> REP
    A3 --> REP
    A4 --> REP
    V1 --> REP
    V2 --> REP
    V3 --> GRP["group_upgrades — target version"]
    D1 --> GRP
    D2 --> HINT["ecosystem upgrade hint"]
    M1 --> REP
    GRP --> BRIEF["agent/alert-N-pkg.md"]
    HINT --> BRIEF
    A1 --> BRIEF
```
