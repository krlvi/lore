#!/usr/bin/env bash
# Self-healing Lore build orchestrator
# Spawns Claude Code, monitors it, restarts on failure, reports to OpenClaw

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$REPO_DIR/.ralph/orchestrator.log"
STATUS="$REPO_DIR/.ralph/STATUS"
ITER_FILE="$REPO_DIR/.ralph/iteration"
MAX_ITER=50
COOLDOWN=10

mkdir -p "$REPO_DIR/.ralph"
echo "0" > "$ITER_FILE"

log() { echo "[$(date -u +%H:%M:%S)] $*" | tee -a "$LOG"; }

notify() {
  openclaw system event --text "$1" --mode now 2>/dev/null || true
}

run_claude() {
  local iter=$1
  log "=== Iteration $iter ==="
  echo "running:$iter" > "$STATUS"

  timeout 900 claude \
    --permission-mode bypassPermissions \
    --print \
    --max-turns 40 \
    "$(cat "$REPO_DIR/AGENT.md")

Read fix_plan.md and pick the next unchecked task. Implement it fully.
Run bin/rails test after changes. Fix failures before moving on.
Commit with a clear message. Push to origin main.
Update fix_plan.md to check off completed items.
Output LORE_COMPLETE only when ALL tasks in fix_plan.md are checked off and bin/rails test passes." \
    2>&1 | tee -a "$LOG"
  
  return ${PIPESTATUS[0]}
}

notify "🚀 Lore build loop started — watching https://github.com/krlvi/lore"

iter=0
consec_fail=0

while [ $iter -lt $MAX_ITER ]; do
  iter=$((iter + 1))
  echo "$iter" > "$ITER_FILE"

  # Check for STOP file
  if [ -f "$REPO_DIR/.ralph/STOP" ]; then
    log "STOP file found, halting."
    notify "🛑 Lore loop stopped by STOP file after $iter iterations"
    exit 0
  fi

  # Pull latest before each iteration
  cd "$REPO_DIR"
  git pull --rebase origin main 2>/dev/null || true

  # Check if already complete
  if ! grep -q '^\- \[ \]' fix_plan.md 2>/dev/null; then
    log "All tasks complete!"
    notify "✅ Lore build complete after $iter iterations — all fix_plan.md tasks done"
    exit 0
  fi

  # Run claude
  if run_claude $iter; then
    consec_fail=0
    # Check output for completion signal
    if tail -5 "$LOG" | grep -q "LORE_COMPLETE"; then
      notify "✅ Lore build complete! LORE_COMPLETE signal received after $iter iterations"
      exit 0
    fi
    notify "✓ Iter $iter done — $(grep '^\- \[x\]' "$REPO_DIR/fix_plan.md" 2>/dev/null | wc -l) tasks complete"
  else
    consec_fail=$((consec_fail + 1))
    log "Iteration $iter failed (consec: $consec_fail)"
    notify "⚠️ Iter $iter failed ($consec_fail consecutive) — auto-retrying"
    
    if [ $consec_fail -ge 3 ]; then
      notify "🆘 3 consecutive failures on Lore build — needs attention"
      consec_fail=0  # Reset and keep trying
    fi
  fi

  sleep $COOLDOWN
done

notify "⏰ Lore loop hit max iterations ($MAX_ITER) — check status"
