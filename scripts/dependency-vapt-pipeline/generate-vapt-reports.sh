#!/usr/bin/env bash
set -e

echo "=== Dependabot & Code Scanning VAPT Pipeline Setup & Report Generation ==="

SKIP_AUTOFIX=false
for arg in "$@"; do
    case "$arg" in
        --reports-only|--no-autofix|--skip-autofix)
            SKIP_AUTOFIX=true
            ;;
    esac
done

# 1. Check directories (ensure we are in the repo root)
if [[ ! -f ".github/scripts/dependabot_report.py" || ! -f ".github/scripts/code_scanning_report.py" ]]; then
    echo "[ERROR] Error: Script must be run from the repository root."
    echo "   Please 'cd' to the root of the project and run:"
    echo "   ./scripts/dependency-vapt-pipeline/generate-vapt-reports.sh"
    exit 1
fi
echo "[OK] Directory check passed."

# 2. Check required system commands (gh, python3, jq)
echo "Checking required system packages..."
for cmd in gh python3 jq; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "[ERROR] Error: Required tool '$cmd' is not installed."
        echo "   Please install '$cmd' and try again."
        exit 1
    fi
done
echo "[OK] System tools verified."

# 3. Check GitHub Auth and Permissions
echo "Checking GitHub CLI authentication..."
if ! gh auth status &> /dev/null; then
    echo "[ERROR] GitHub CLI is not authenticated."
    echo ""
    echo "To configure GitHub CLI, please run:"
    echo "  gh auth login"
    echo ""
    echo "Make sure to grant access to the repository."
    exit 1
fi

REPO="Mohitur669/speakit"
echo "Verifying Dependabot API access for $REPO..."
# We test hitting the API directly. If it fails, the token lacks the correct scope.
if ! gh api "/repos/$REPO/dependabot/alerts" --silent 2>/dev/null; then
    echo "[ERROR] Permission Denied: Your GitHub token cannot read Dependabot alerts."
    echo ""
    echo "How to fix this:"
    echo "1. Go to GitHub -> Settings -> Developer Settings -> Fine-grained PATs"
    echo "2. Create a token with 'Dependabot alerts: Read-only' for this repository."
    echo "3. Export it to your environment: export GITHUB_TOKEN=github_pat_..."
    echo "   OR authenticate the gh CLI with the new token: gh auth login --with-token"
    exit 1
fi
echo "[OK] Dependabot API access verified."

echo "Verifying Code Scanning API access for $REPO..."
if ! gh api "/repos/$REPO/code-scanning/alerts" --silent 2>/dev/null; then
    echo "[WARNING] Your GitHub token cannot read Code Scanning alerts."
    echo "          Ensure the token has 'security_events: read' or fine-grained 'Code scanning alerts: Read-only'."
else
    echo "[OK] Code Scanning API access verified."
fi
echo "[OK] GitHub authentication and permissions verified."

# 4. Setup Python environment and install packages
echo "Setting up Python virtual environment..."
if [[ ! -d ".venv" ]]; then
    python3 -m venv .venv
fi
source .venv/bin/activate

echo "Installing required Python dependencies..."
pip install -r .github/scripts/requirements.txt --quiet
echo "[OK] Python dependencies installed."

# 5. Generate Reports
export GITHUB_TOKEN=$(gh auth token)

echo "Generating Dependabot VAPT reports..."
python .github/scripts/dependabot_report.py --repo "$REPO"
echo "[OK] Reports successfully generated in reports/dependabot/"

echo "Generating Code Scanning (CodeQL) VAPT reports..."
if gh api "/repos/$REPO/code-scanning/alerts" --silent 2>/dev/null; then
    python .github/scripts/code_scanning_report.py --repo "$REPO"
    echo "[OK] Reports successfully generated in reports/code-scanning/"
else
    echo "[SKIP] Skipping Code Scanning reports due to API access limitations."
fi

# 6. Auto-Fix NPM Packages
if [[ "$SKIP_AUTOFIX" == "true" ]]; then
    echo "Skipping automated NPM fast-track fixes (--reports-only specified)."
else
    echo "Starting automated NPM fast-track fixes..."
    ./scripts/dependency-vapt-pipeline/auto-fix-npm.py
fi

echo ""
echo "[DONE] Setup, Report Generation, and NPM Fast-Tracking Complete!"
echo "Reports available in:"
echo "  - Dependabot:    reports/dependabot/ (and reports/alerts/dependabot-alerts-report.csv)"
echo "  - Code Scanning: reports/code-scanning/ (and reports/alerts/code-scanning-alerts.csv)"
echo "You can now manually submit 'fix-vapt-alerts.md' to the AI agent to begin processing the remaining complex vulnerabilities."
