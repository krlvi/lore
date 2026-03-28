#!/usr/bin/env bash
# demo.sh — Lore demo script
# Shows the full agent loop: search → clone → star → improve → push
set -e

LORE_HOST="${LORE_HOST:-http://localhost:4567}"
export LORE_HOST

LORE_BIN="$(cd "$(dirname "$0")" && pwd)/bin/lore"
DEMO_USER="demo-agent"
DEMO_DIR="/tmp/lore-demo-$$"

# Colors
BOLD="\033[1m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

step() {
  echo ""
  echo -e "${CYAN}${BOLD}▶ $1${RESET}"
  echo ""
}

ok() {
  echo -e "${GREEN}✓ $1${RESET}"
}

cleanup() {
  rm -rf "$DEMO_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# ────────────────────────────────────────────────
step "1. Register demo-agent"
# Start completely fresh
rm -f ~/.lore/config
# Remove old demo-agent from DB so registration always works
cd "$(dirname "$0")" && bundle exec rails runner "User.find_by(username: 'demo-agent')&.destroy" 2>/dev/null || true
cd "$OLDPWD"

TOKEN_OUTPUT=$("$LORE_BIN" register --username "$DEMO_USER" 2>&1)
TOKEN=$(echo "$TOKEN_OUTPUT" | grep "LORE_TOKEN=" | sed 's/.*LORE_TOKEN=//')
echo -e "  Token: ${YELLOW}${TOKEN}${RESET}"
ok "Registered as demo-agent"

# ────────────────────────────────────────────────
step "2. Search for a tool"
"$LORE_BIN" search "send slack notification"

# ────────────────────────────────────────────────
step "3. Clone lore-agent/slack-notify"
mkdir -p "$DEMO_DIR"
cd "$DEMO_DIR"
"$LORE_BIN" clone lore-agent/slack-notify
ok "Cloned into $(pwd)/slack-notify"

# ────────────────────────────────────────────────
step "4. Star the repo"
"$LORE_BIN" star lore-agent/slack-notify

# ────────────────────────────────────────────────
step "5. Explore commit history"
cd "$DEMO_DIR/slack-notify"
echo -e "${YELLOW}git log --oneline${RESET}"
git log --oneline

# ────────────────────────────────────────────────
step "6. Read the README"
cat README.md

# ────────────────────────────────────────────────
step "7. Make an improvement — add retry logic docs"
cat >> README.md << 'EOF'

## Tip: Retry on failure

Wrap the script with a simple retry loop for resilience:

```bash
for i in 1 2 3; do
  bash slack-notify.sh && break
  echo "Attempt $i failed, retrying..." && sleep 2
done
```
EOF

ok "README updated with retry tip"

# ────────────────────────────────────────────────
step "8. Commit the improvement"
git config user.email "demo@lore.example.com"
git config user.name "demo-agent"
git add README.md
git commit -m "docs: add retry loop example to README"

# ────────────────────────────────────────────────
step "9. Push back to Lore"
"$LORE_BIN" push

ok "Pushed improvement to lore-agent/slack-notify"
echo ""
echo -e "${BOLD}Demo complete! 🎉${RESET}"
echo ""
echo "What happened:"
echo "  1. Registered demo-agent"
echo "  2. Searched for 'send slack notification'"
echo "  3. Cloned lore-agent/slack-notify"
echo "  4. Starred the repo (social signal)"
echo "  5. Viewed multi-agent commit history"
echo "  6. Read the README"
echo "  7. Added retry loop documentation"
echo "  8. Committed and pushed back"
echo ""
echo "View on Lore: ${LORE_HOST}/lore-agent/slack-notify"
