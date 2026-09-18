#!/usr/bin/env bash
set -e

echo "=== Dependabot VAPT Pipeline Setup & Report Generation ==="

# 1. Check directories (ensure we are in the repo root)
if [[ ! -f ".github/scripts/dependabot_report.py" ]]; then
    echo "❌ Error: Script must be run from the repository root."
    echo "   Please 'cd' to the root of the project and run:"
    echo "   ./scripts/dependency-vapt-pipeline/generate-vapt-reports.sh"
    exit 1
fi
echo "✅ Directory check passed."

# 2. Check required system commands (gh, python3, jq)
echo "Checking required system packages..."
for cmd in gh python3 jq; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Error: Required tool '$cmd' is not installed."
        echo "   Please install '$cmd' and try again."
        exit 1
    fi
done
echo "✅ System tools verified."

# 3. Check GitHub Auth and Permissions
echo "Checking GitHub CLI authentication..."
if ! gh auth status &> /dev/null; then
    echo "❌ GitHub CLI is not authenticated."
    echo ""
    echo "To configure GitHub CLI, please run:"
    echo "  gh auth login"
    echo ""
    echo "Make sure to grant access to the repository. Note: Dependabot alerts"
    echo "require specific permissions that the standard token might lack."
    exit 1
fi

REPO="Mohitur669/speakit"
echo "Verifying Dependabot API access for $REPO..."
# We test hitting the API directly. If it fails, the token lacks the correct scope.
if ! gh api "/repos/$REPO/dependabot/alerts" --silent 2>/dev/null; then
    echo "❌ Permission Denied: Your GitHub token cannot read Dependabot alerts."
    echo ""
    echo "How to fix this:"
    echo "1. Go to GitHub -> Settings -> Developer Settings -> Fine-grained PATs"
    echo "2. Create a token with 'Dependabot alerts: Read-only' for this repository."
    echo "3. Export it to your environment: export GITHUB_TOKEN=github_pat_..."
    echo "   OR authenticate the gh CLI with the new token: gh auth login --with-token"
    exit 1
fi
echo "✅ GitHub authentication and permissions verified."

# 4. Setup Python environment and install packages
echo "Setting up Python virtual environment..."
if [[ ! -d ".venv" ]]; then
    python3 -m venv .venv
fi
source .venv/bin/activate

echo "Installing required Python dependencies..."
pip install -r .github/scripts/requirements.txt --quiet
echo "✅ Python dependencies installed."

# 5. Generate Reports
echo "Generating Dependabot VAPT reports..."
# Export the token from gh cli so the python script can pick it up natively
export GITHUB_TOKEN=$(gh auth token)
python .github/scripts/dependabot_report.py --repo "$REPO"

echo ""
echo "🎉 Reports successfully generated in reports/dependabot/"
echo "You can now manually submit 'fix-vapt-alerts.md' to the AI agent to begin processing the queue!"
