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
    echo "   ./scripts/dependabot-vapt/generate-vapt-reports.sh"
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
echo ""
echo "Select Python environment type:"
echo "  1) Virtualenv (.venv)"
echo "  2) Conda (Miniconda/Anaconda)"
read -rp "Enter choice [1-2] (default: 1): " ENV_CHOICE
ENV_CHOICE=${ENV_CHOICE:-1}

if [[ "$ENV_CHOICE" == "2" ]]; then
    if ! command -v conda &> /dev/null; then
        # Check standard installation locations if conda is not in PATH
        if [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
            source "$HOME/miniconda3/etc/profile.d/conda.sh"
        elif [[ -f "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh" ]]; then
            source "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh"
        elif [[ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]]; then
            source "$HOME/anaconda3/etc/profile.d/conda.sh"
        elif [[ -f "/opt/homebrew/anaconda3/etc/profile.d/conda.sh" ]]; then
            source "/opt/homebrew/anaconda3/etc/profile.d/conda.sh"
        fi
    fi

    if ! command -v conda &> /dev/null; then
        echo "[ERROR] Conda is not installed or not in PATH."
        exit 1
    fi

    # Initialize conda shell support for scripting
    CONDA_BASE=$(conda info --base 2>/dev/null)
    if [[ -f "$CONDA_BASE/etc/profile.d/conda.sh" ]]; then
        source "$CONDA_BASE/etc/profile.d/conda.sh"
    fi

    echo ""
    echo "Conda options:"
    echo "  1) Select an existing environment"
    echo "  2) Create a new environment"
    read -rp "Enter choice [1-2] (default: 1): " CONDA_ACTION
    CONDA_ACTION=${CONDA_ACTION:-1}

    if [[ "$CONDA_ACTION" == "2" ]]; then
        while true; do
            read -rp "Enter new Conda environment name: " NEW_ENV_NAME
            NEW_ENV_NAME=$(echo "$NEW_ENV_NAME" | xargs)
            if [[ -z "$NEW_ENV_NAME" ]]; then
                echo "[WARNING] Environment name cannot be empty."
            else
                break
            fi
        done

        read -rp "Enter Python version for $NEW_ENV_NAME (default: 3.11): " CONDA_PY_VER
        CONDA_PY_VER=${CONDA_PY_VER:-3.11}

        echo "Creating Conda environment '$NEW_ENV_NAME' with Python $CONDA_PY_VER..."
        conda create -y -n "$NEW_ENV_NAME" python="$CONDA_PY_VER"
        TARGET_ENV="$NEW_ENV_NAME"
    else
        # Collect existing conda environments (macOS Bash 3.2 compatible without mapfile)
        CONDA_ENVS=()
        while IFS= read -r env_name; do
            [[ -n "$env_name" ]] && CONDA_ENVS+=("$env_name")
        done < <(conda env list | awk '{print $1}' | grep -v '^#' | grep -v '^$')
        if [[ ${#CONDA_ENVS[@]} -eq 0 ]]; then
            echo "[WARNING] No existing Conda environments found. Creating 'localpython'..."
            conda create -y -n "localpython" python=3.11
            TARGET_ENV="localpython"
        else
            echo ""
            echo "Available Conda environments:"
            for i in "${!CONDA_ENVS[@]}"; do
                printf "  %2d) %s\n" "$((i+1))" "${CONDA_ENVS[$i]}"
            done

            while true; do
                read -rp "Select an environment [1-${#CONDA_ENVS[@]}] (default: 1): " ENV_IDX
                ENV_IDX=${ENV_IDX:-1}
                if [[ "$ENV_IDX" =~ ^[0-9]+$ ]] && [[ "$ENV_IDX" -ge 1 ]] && [[ "$ENV_IDX" -le "${#CONDA_ENVS[@]}" ]]; then
                    TARGET_ENV="${CONDA_ENVS[$((ENV_IDX-1))]}"
                    break
                else
                    echo "[WARNING] Invalid selection. Please enter a number between 1 and ${#CONDA_ENVS[@]}."
                fi
            done
        fi
    fi

    echo "Activating Conda environment '$TARGET_ENV'..."
    conda activate "$TARGET_ENV"
    echo "[OK] Active Python: $(which python3)"
else
    echo "Setting up Python virtual environment (.venv)..."
    if [[ ! -d ".venv" ]]; then
        python3 -m venv .venv
    fi
    source .venv/bin/activate
    echo "[OK] Active Python: $(which python3)"
fi

echo "Installing required Python dependencies..."
pip install --only-binary :all: -r .github/scripts/requirements.txt --quiet || pip install -r .github/scripts/requirements.txt --quiet
echo "[OK] Python dependencies installed."

# 5. Generate Reports
GITHUB_TOKEN="$(gh auth token)"
export GITHUB_TOKEN

echo "Generating Dependabot VAPT reports..."
python .github/scripts/dependabot_report.py --repo "$REPO" --out "reports/dependabot-vapt"
echo "[OK] Reports successfully generated in reports/dependabot-vapt/"

# 6. Auto-Fix NPM Packages
if [[ "$SKIP_AUTOFIX" == "true" ]]; then
    echo "Skipping automated NPM fast-track fixes (--reports-only specified)."
else
    echo "Starting automated NPM fast-track fixes..."
    ./scripts/dependabot-vapt/auto-fix-npm.py
fi

echo ""
echo "[DONE] Setup, Report Generation, and NPM Fast-Tracking Complete!"
echo "Consolidated AI Remediation Plan generated:"
echo "  - Dependabot:    reports/dependabot-vapt/fix-vapt-alerts.md"
echo ""
echo "Feed 'reports/dependabot-vapt/fix-vapt-alerts.md' to the AI agent to begin processing the remaining vulnerabilities."
