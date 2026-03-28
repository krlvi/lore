#!/usr/bin/env bash
# Ralph Loop for Lore — robust autonomous build loop using Claude Code
# Designed to run unattended for hours.
set -uo pipefail

# ──────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MAX_ITERATIONS="${MAX_ITERATIONS:-100}"
ITER_TIMEOUT="${ITER_TIMEOUT:-900}"        # 15 min max per iteration
MAX_TURNS="${MAX_TURNS:-30}"               # Claude Code tool-use turns per iteration
CONSECUTIVE_FAIL_LIMIT=3                   # Stop after N consecutive failures
COOLDOWN_SECS=5                            # Pause between iterations

LOG_DIR="${REPO_DIR}/.ralph"
STOP_FILE="${LOG_DIR}/STOP"
STATUS_FILE="${LOG_DIR}/STATUS"
SUMMARY_FILE="${LOG_DIR}/SUMMARY.log"
PROMPT_FILE="${LOG_DIR}/_current_prompt.md"

mkdir -p "$LOG_DIR"

# ──────────────────────────────────────────────
# Environment — ensure rbenv Ruby is active
# ──────────────────────────────────────────────
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$HOME/.rbenv/shims:$HOME/.rbenv/bin:/opt/homebrew/bin:$PATH"
eval "$(rbenv init - bash 2>/dev/null || true)"

# Verify Ruby
RUBY_VER=$(ruby --version 2>/dev/null || echo "MISSING")
if [[ "$RUBY_VER" == *"2.6"* ]] || [[ "$RUBY_VER" == "MISSING" ]]; then
  echo "❌ Wrong Ruby: $RUBY_VER — need 3.3+"
  exit 1
fi

# Unset ANTHROPIC_API_KEY so Claude Code uses its own OAuth
unset ANTHROPIC_API_KEY 2>/dev/null || true

# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────
timestamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$SUMMARY_FILE"; }

write_status() {
  cat > "$STATUS_FILE" <<EOF
{
  "iteration": $1,
  "max_iterations": $MAX_ITERATIONS,
  "status": "$2",
  "timestamp": "$(timestamp)",
  "consecutive_failures": $consecutive_failures,
  "total_commits": $(git -C "$REPO_DIR" rev-list --count HEAD 2>/dev/null || echo 0),
  "message": "$3"
}
EOF
}

# Clean up dirty git state between iterations
git_cleanup() {
  cd "$REPO_DIR"
  # Stash any uncommitted changes so next iteration starts clean
  if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet HEAD 2>/dev/null; then
    log "⚠️  Uncommitted changes detected — stashing"
    git stash push -m "ralph-loop-cleanup-iter-$1" 2>/dev/null || true
  fi
  # Clean untracked files EXCEPT .ralph/ and ralph_loop.sh and .gitignore
  git clean -fd --exclude=.ralph --exclude=ralph_loop.sh --exclude=ralph_monitor.sh --exclude=.gitignore 2>/dev/null || true
}

# Count commits made during this loop run
commits_before_loop=$(git -C "$REPO_DIR" rev-list --count HEAD 2>/dev/null || echo 0)

# Build the prompt for each iteration
build_prompt() {
  local iter="$1"
  local prev_result="$2"

  cat <<PROMPT
You are running iteration ${iter} of an autonomous Ralph Loop build.

## Previous iteration result
${prev_result}

## Your contract (READ THIS CAREFULLY)

1. Read AGENT.md first — it is your build contract.
2. Read fix_plan.md — your prioritized task list.
3. Consult spec.md for implementation details ONLY when needed (it's 37KB — read targeted sections).
4. Pick exactly ONE unchecked item — the highest-priority one that is not marked as blocked.
5. Implement that one item completely. Do not half-finish.
6. Validate your work:
   - If Rails app exists: \`bundle exec rails test\` or \`bundle exec rspec\` (whichever is configured)
   - If setting up for the first time: ensure \`bundle install\` and \`bin/rails server\` start without errors
   - For API work: use curl to verify endpoints
   - For git transport: test clone/push operations
7. Update fix_plan.md: mark completed items with [x], add notes.
8. Stage and commit ALL your changes: \`git add -A && git commit -m "descriptive message"\`
9. Do NOT commit broken code. If validation fails, fix it before committing.

## Environment

- macOS arm64, Ruby 3.3.7 via rbenv (already on PATH)
- Rails and bundler are installed as gems
- SQLite3 is available
- OPENAI_API_KEY is set (for embeddings)
- Git is configured, you can commit freely
- Working directory: ${REPO_DIR}

## Rails setup (if this is early iteration and no Rails app exists yet)

\`\`\`bash
rails new . --database=sqlite3 --skip-docker --skip-action-mailer --skip-action-mailbox --skip-action-text --skip-active-storage --skip-action-cable --skip-hotwire --skip-jbuilder --skip-test --skip-system-test --skip-thruster --force
# Then add needed gems to Gemfile and bundle install
\`\`\`

## Output format (IMPORTANT — last line of your output must be one of these)

- If you completed the task and committed: \`COMPLETED: <one-line summary of what you did>\`
- If you're blocked and cannot proceed: \`BLOCKED: <specific reason>\`
- If all tasks in fix_plan.md are done: \`ALL_DONE\`

The last line of your output MUST be one of these three. This is how the loop knows what happened.
PROMPT
}

# ──────────────────────────────────────────────
# Main loop
# ──────────────────────────────────────────────
consecutive_failures=0
prev_result="First iteration — no previous context."

log "🔄 Ralph Loop starting"
log "   Repo: $REPO_DIR"
log "   Ruby: $RUBY_VER"
log "   Max iterations: $MAX_ITERATIONS"
log "   Timeout per iteration: ${ITER_TIMEOUT}s"
log "   Stop file: $STOP_FILE"
log ""

for i in $(seq 1 "$MAX_ITERATIONS"); do
  # ── Pre-flight checks ──
  if [[ -f "$STOP_FILE" ]]; then
    log "⛔ Stop file detected. Halting loop."
    write_status "$i" "stopped" "Stop file detected"
    break
  fi

  if [[ $consecutive_failures -ge $CONSECUTIVE_FAIL_LIMIT ]]; then
    log "🚫 $CONSECUTIVE_FAIL_LIMIT consecutive failures. Halting to avoid waste."
    write_status "$i" "failed" "Too many consecutive failures"
    break
  fi

  # ── Clean git state ──
  git_cleanup "$i"

  # ── Build prompt ──
  PROMPT=$(build_prompt "$i" "$prev_result")
  echo "$PROMPT" > "$PROMPT_FILE"

  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "📍 Iteration $i / $MAX_ITERATIONS"
  write_status "$i" "running" "Starting iteration"

  ITER_LOG="${LOG_DIR}/iteration_${i}.log"
  COMMITS_BEFORE=$(git -C "$REPO_DIR" rev-list --count HEAD 2>/dev/null || echo 0)

  # ── Run Claude Code with timeout ──
  timeout "$ITER_TIMEOUT" claude --print \
    --permission-mode bypassPermissions \
    --max-turns "$MAX_TURNS" \
    -p "$PROMPT" \
    2>&1 | tee "$ITER_LOG"

  EXIT_CODE=${PIPESTATUS[0]}
  COMMITS_AFTER=$(git -C "$REPO_DIR" rev-list --count HEAD 2>/dev/null || echo 0)
  NEW_COMMITS=$((COMMITS_AFTER - COMMITS_BEFORE))

  # ── Parse result ──
  LAST_LINES=$(tail -30 "$ITER_LOG" 2>/dev/null || echo "")

  if echo "$LAST_LINES" | grep -q "ALL_DONE"; then
    log "✅ ALL DONE at iteration $i"
    write_status "$i" "complete" "All tasks finished"
    prev_result="Previous iteration completed all remaining tasks."
    break
  elif echo "$LAST_LINES" | grep -q "BLOCKED:"; then
    BLOCK_MSG=$(echo "$LAST_LINES" | grep "BLOCKED:" | tail -1)
    log "🚫 $BLOCK_MSG"
    consecutive_failures=$((consecutive_failures + 1))
    write_status "$i" "blocked" "$BLOCK_MSG"
    prev_result="Previous iteration was BLOCKED: $BLOCK_MSG"
  elif echo "$LAST_LINES" | grep -q "COMPLETED:"; then
    DONE_MSG=$(echo "$LAST_LINES" | grep "COMPLETED:" | tail -1)
    log "✅ $DONE_MSG (${NEW_COMMITS} new commits)"
    consecutive_failures=0
    write_status "$i" "success" "$DONE_MSG"
    prev_result="$DONE_MSG"
  elif [[ $EXIT_CODE -eq 124 ]]; then
    log "⏰ Iteration $i timed out after ${ITER_TIMEOUT}s"
    consecutive_failures=$((consecutive_failures + 1))
    write_status "$i" "timeout" "Iteration timed out"
    prev_result="Previous iteration TIMED OUT. The task may have been too large. Pick a smaller increment."
  elif [[ $NEW_COMMITS -gt 0 ]]; then
    # Agent committed but didn't output the expected format — still counts as progress
    LAST_COMMIT=$(git -C "$REPO_DIR" log --oneline -1)
    log "✅ Iteration $i: $NEW_COMMITS commit(s) — $LAST_COMMIT (no COMPLETED tag)"
    consecutive_failures=0
    write_status "$i" "success" "Committed: $LAST_COMMIT"
    prev_result="Previous iteration committed: $LAST_COMMIT"
  else
    log "⚠️  Iteration $i: no commits, no clear result (exit code: $EXIT_CODE)"
    consecutive_failures=$((consecutive_failures + 1))
    write_status "$i" "failed" "No commits, exit code $EXIT_CODE"
    prev_result="Previous iteration produced no commits and no clear result. Something may be wrong."
  fi

  # ── Progress summary ──
  TOTAL_NEW=$(($(git -C "$REPO_DIR" rev-list --count HEAD 2>/dev/null || echo 0) - commits_before_loop))
  log "   📊 Total new commits this run: $TOTAL_NEW | Consecutive failures: $consecutive_failures"
  log ""

  sleep "$COOLDOWN_SECS"
done

# ── Final summary ──
TOTAL_NEW=$(($(git -C "$REPO_DIR" rev-list --count HEAD 2>/dev/null || echo 0) - commits_before_loop))
log ""
log "🏁 Ralph Loop finished"
log "   Iterations run: $((i > MAX_ITERATIONS ? MAX_ITERATIONS : i))"
log "   New commits: $TOTAL_NEW"
log "   Logs: $LOG_DIR"

if [[ $TOTAL_NEW -gt 0 ]]; then
  log ""
  log "📋 Commits made during this run:"
  git -C "$REPO_DIR" log --oneline "-${TOTAL_NEW}"
fi
