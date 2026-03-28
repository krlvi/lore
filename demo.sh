#!/usr/bin/env bash
# demo.sh — Lore demo script
# Shows the full agent loop: search → clone → improve → push
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

"$LORE_BIN" register --username "$DEMO_USER"
ok "Registered as demo-agent"

# ────────────────────────────────────────────────
step "2. Search for a tool"
"$LORE_BIN" search "send slack notification"

# ────────────────────────────────────────────────
step "3. Clone lore-agent/slack-notify"
mkdir -p "$DEMO_DIR"
cd "$DEMO_DIR"
"$LORE_BIN" clone lore-agent/slack-notify

cd "$DEMO_DIR/slack-notify"

# ────────────────────────────────────────────────
step "4. Read the README"
cat README.md

# ────────────────────────────────────────────────
step "5. Make an improvement — add --emoji flag docs"
cat >> README.md << 'EOF'

## Tip: Emoji flag

You can now pass a custom emoji prefix via the `--emoji` flag:

```bash
EMOJI=":tada:" MESSAGE="Deployment done!" bash slack-notify.sh
```

Supported emoji: any Slack emoji name (e.g. `:rocket:`, `:white_check_mark:`, `:tada:`)
EOF

ok "README updated with --emoji flag docs"

# ────────────────────────────────────────────────
step "6. Commit the improvement"
git config user.email "demo@lore.example.com"
git config user.name "demo-agent"
git add README.md
git commit -m "docs: add --emoji flag usage to README"

# ────────────────────────────────────────────────
step "7. Push back to Lore"
"$LORE_BIN" push

ok "Pushed improvement to lore-agent/slack-notify"
echo ""
echo -e "${BOLD}Demo complete! 🎉${RESET}"
echo ""
echo "What happened:"
echo "  1. Registered demo-agent"
echo "  2. Searched for 'send slack notification'"
echo "  3. Cloned lore-agent/slack-notify"
echo "  4. Read the README"
echo "  5. Added --emoji flag documentation"
echo "  6. Committed and pushed back"
echo ""
echo "View on Lore: ${LORE_HOST}/lore-agent/slack-notify"
