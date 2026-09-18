#!/usr/bin/env bash
# Destination: scripts/dependency-vapt-pipeline/fix-alerts.sh   (chmod +x)
#
# Walks the Dependabot queue produced by .github/scripts/dependabot_report.py and
# hands each alert, one at a time, to a local agent that has the whole codebase in
# context. One branch per fix, verification after each, human approval before commit.
#
#   ./scripts/dependency-vapt-pipeline/fix-alerts.sh                       # interactive, full queue
#   ./scripts/dependency-vapt-pipeline/fix-alerts.sh --dry-run             # print what would run
#   ./scripts/dependency-vapt-pipeline/fix-alerts.sh --only 24             # a single alert number
#   ./scripts/dependency-vapt-pipeline/fix-alerts.sh --from 3 --auto       # resume at #3, no prompts
#   ./scripts/dependency-vapt-pipeline/fix-alerts.sh --refresh             # regenerate the report first
#
# Environment:
#   AGENT_CMD   agent invocation, prompt arrives on stdin   (default: agy)
#   VERIFY_CMD  build/test command                          (default: auto-detected)
#   REPORT_DIR  where the report lives                      (default: reports/dependabot)
#   GITHUB_TOKEN  needed only with --refresh

set -euo pipefail

AGENT_CMD=${AGENT_CMD:-agy}
REPORT_DIR=${REPORT_DIR:-reports/dependabot}
QUEUE="$REPORT_DIR/agent-queue.json"
LOG="$REPORT_DIR/fix-log.md"
DRY_RUN=0
AUTO=0
FROM=1
ONLY=""
REFRESH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --auto) AUTO=1 ;;
    --from) FROM="$2"; shift ;;
    --only) ONLY="$2"; shift ;;
    --refresh) REFRESH=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

command -v jq >/dev/null || { echo "jq is required"; exit 1; }

if [[ $REFRESH -eq 1 ]]; then
  python .github/scripts/dependabot_report.py --out "$REPORT_DIR"
fi

if [[ ! -f "$QUEUE" ]]; then
  echo "No queue at $QUEUE."
  echo "Run with --refresh, or pull the latest CI bundle:"
  echo "  gh run download -n dependabot-report-<run> -D $REPORT_DIR"
  exit 1
fi

# Auto-detect a verification command if none was supplied.
if [[ -z "${VERIFY_CMD:-}" ]]; then
  if [[ -f frontend/package.json ]]; then
    VERIFY_CMD="npm --prefix frontend ci && npm --prefix frontend run build && npm --prefix frontend test -- --watch=false"
  elif [[ -f package.json ]]; then
    VERIFY_CMD="npm ci && npm run build --if-present && npm test --if-present"
  elif [[ -f pom.xml ]]; then
    VERIFY_CMD="./mvnw -B verify"
  elif [[ -f build.gradle || -f build.gradle.kts ]]; then
    VERIFY_CMD="./gradlew build"
  else
    VERIFY_CMD="true"
  fi
fi

BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
mkdir -p "$(dirname "$LOG")"
{ echo; echo "## Run $(date -u '+%Y-%m-%d %H:%M UTC') (base: $BASE_BRANCH)"; echo; } >> "$LOG"

TOTAL=$(jq 'length' "$QUEUE")
echo "Queue: $TOTAL alert(s) · agent: $AGENT_CMD · verify: $VERIFY_CMD"
echo

for idx in $(seq 0 $((TOTAL - 1))); do
  ORDER=$(jq -r ".[$idx].order" "$QUEUE")
  NUM=$(jq -r ".[$idx].alert_number" "$QUEUE")
  SEV=$(jq -r ".[$idx].severity" "$QUEUE")
  PKG=$(jq -r ".[$idx].package" "$QUEUE")
  TARGET=$(jq -r ".[$idx].target_version" "$QUEUE")
  CLOSES=$(jq -r ".[$idx].closes_alerts | join(\", #\")" "$QUEUE")
  BRIEF="$REPORT_DIR/$(jq -r ".[$idx].brief" "$QUEUE")"

  [[ $ORDER -lt $FROM ]] && continue
  [[ -n "$ONLY" && "$NUM" != "$ONLY" ]] && continue

  echo "────────────────────────────────────────────────────────"
  echo "[$ORDER/$TOTAL] #$NUM  $(echo "$SEV" | tr '[:lower:]' '[:upper:]')  $PKG -> $TARGET  (closes #$CLOSES)"
  echo "brief: $BRIEF"

  SLUG=$(echo "$PKG" | tr -c 'A-Za-z0-9._-' '-')
  BRANCH="fix/dependabot-$NUM-$SLUG"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  would: git switch -c $BRANCH && $AGENT_CMD < $BRIEF && $VERIFY_CMD"
    continue
  fi

  if [[ $AUTO -eq 0 ]]; then
    read -r -p "  run this fix? [y]es / [s]kip / [q]uit: " answer
    case "$answer" in
      s|S) echo "- skipped #$NUM ($PKG)" >> "$LOG"; continue ;;
      q|Q) echo "stopping."; exit 0 ;;
    esac
  fi

  git switch -c "$BRANCH" "$BASE_BRANCH" 2>/dev/null || git switch "$BRANCH"

  if ! "$AGENT_CMD" < "$BRIEF"; then
    echo "  agent exited non-zero on #$NUM" | tee -a "$LOG"
    git switch "$BASE_BRANCH"
    continue
  fi

  echo "  verifying..."
  if bash -c "$VERIFY_CMD"; then
    VERDICT="verified"
  else
    VERDICT="VERIFICATION FAILED"
    echo "  $VERDICT — branch $BRANCH left in place for manual review."
  fi

  git --no-pager diff --stat
  echo "- #$NUM $PKG -> $TARGET on \`$BRANCH\` — $VERDICT" >> "$LOG"

  if [[ "$VERDICT" == "verified" ]]; then
    if [[ $AUTO -eq 1 ]]; then
      COMMIT=y
    else
      read -r -p "  commit? [y/N]: " COMMIT
    fi
    if [[ "$COMMIT" =~ ^[yY]$ ]]; then
      git add -A
      git commit -m "fix(deps): bump $PKG to $TARGET

Closes Dependabot alert(s) #$CLOSES."
    fi
  fi

  git switch "$BASE_BRANCH"
done

echo
echo "Done. Log: $LOG"
