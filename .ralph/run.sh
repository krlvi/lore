#!/usr/bin/env bash
set -uo pipefail
unset ANTHROPIC_API_KEY
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
eval "$(rbenv init -)"
cd ~/src/lore

mkdir -p .ralph
ITER=0
FAIL=0
LOG=".ralph/build.log"

log() { echo "[$(date -u +%H:%M:%S)] $*" | tee -a "$LOG"; }
notify() { openclaw system event --text "$1" --mode now 2>/dev/null || true; }

notify "🚀 Lore build loop started (Claude Code authorized)"
log "Loop started"

while true; do
  ITER=$((ITER+1))
  echo "$ITER" > .ralph/iteration
  [ -f .ralph/STOP ] && { notify "🛑 Stopped after $ITER iterations"; exit 0; }
  ! grep -q '^\- \[ \]' fix_plan.md 2>/dev/null && { notify "✅ All Lore tasks complete after $ITER iterations!"; exit 0; }

  DONE=$(grep -c '^\- \[x\]' fix_plan.md 2>/dev/null || echo 0)
  TOTAL=$(grep -c '^\- \[' fix_plan.md 2>/dev/null || echo 0)
  log "=== Iter $ITER ($DONE/$TOTAL tasks done) ==="
  git pull --rebase origin main 2>/dev/null || true

  OUTPUT=$(timeout 900 claude --permission-mode bypassPermissions --print --max-turns 40 \
"$(cat AGENT.md)

Read fix_plan.md. Pick the NEXT unchecked task (- [ ]). Implement it fully.
Run tests: bundle exec rails test
Fix any failures before proceeding.
Commit with a clear message and push to origin main: git push origin main
Mark the task done in fix_plan.md (- [ ] to - [x]), commit and push.
Output LORE_COMPLETE only when ALL tasks in fix_plan.md are checked off and tests pass." 2>&1 | tee -a "$LOG")
  EXIT=${PIPESTATUS[0]}

  if [ $EXIT -eq 0 ]; then
    FAIL=0
    git push origin main 2>/dev/null || true
    DONE=$(grep -c '^\- \[x\]' fix_plan.md 2>/dev/null || echo 0)
    notify "✓ Lore iter $ITER done — $DONE/$TOTAL tasks complete"
    echo "$OUTPUT" | grep -q "LORE_COMPLETE" && { notify "✅ LORE_COMPLETE after $ITER iterations!"; exit 0; }
  else
    FAIL=$((FAIL+1))
    log "Iter $ITER failed (exit $EXIT, consec: $FAIL)"
    notify "⚠️ Lore iter $ITER failed — retrying ($FAIL consecutive)"
    [ $FAIL -ge 5 ] && { notify "🆘 5 consecutive failures on Lore — needs attention"; FAIL=0; }
  fi
  sleep 5
done
