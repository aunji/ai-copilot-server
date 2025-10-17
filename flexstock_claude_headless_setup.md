# FlexStock — Claude Code Headless Setup (Ubuntu + Tailscale)  
**Goal:** ใช้ Claude Code ผ่าน CLI แบบ *ไม่ต้องยืนยัน*, ให้มันสร้าง/อัปเดตโค้ด, สรุปรายงาน, และ `git commit → push → PR` อัตโนมัติ โดยสั่งผ่านสคริปต์ `.sh`

> วิธีใช้ไฟล์นี้: ให้คุณก็อปปี้ **หัวข้อ “CLAUDE HEADLESS TASK PROMPT”** ไปสั่ง Claude Code (`claude -p '...'`) เพื่อให้ Claude สร้างสคริปต์ `.sh` ทั้งหมดให้บนเครื่อง Ubuntu ของคุณแบบอัตโนมัติ

---

## 0) Prereqs (หนึ่งครั้งบนเครื่อง Ubuntu)
- มีสิทธิ์ `sudo`
- มี `git`, `jq`, `curl`
- มี **GitHub Token** (export เป็น env ชื่อ `GH_TOKEN`) ที่สิทธิ์ `repo` สำหรับ push/PR แบบ non‑interactive
- (แนะนำ) ตั้งค่าชื่อ/อีเมล Git ล่วงหน้า:
  ```bash
  git config --global user.name  "Your Name"
  git config --global user.email "you@example.com"
  export GH_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # ต้องตั้งจริง
  ```

> หากใช้ผ่าน **Tailscale** ให้ SSH เข้าเครื่อง Ubuntu ตามปกติ แล้วทำขั้นตอนนี้บนเครื่องนั้น

---

## 1) โครงใช้งาน (ที่ Claude จะสร้างให้)
```
~/claude-headless/
 ├─ scripts/
 │   ├─ setup_claude_env.sh      # ติดตั้ง Node, Claude CLI, gh, jq (ถ้าขาด)
 │   ├─ run-claude-task.sh       # รันงานแบบไม่ถาม, บันทึกผล JSON, commit&PR
 │   ├─ make-report.sh           # แปลงผล JSON → Markdown report
 │   └─ enable_hooks.sh          # เปิด hook log คำสั่ง bash ที่ Claude รัน (ออปชัน)
 └─ README.md
```

---

## 2) **CLAUDE HEADLESS TASK PROMPT** (คัดลอกทั้งบล็อกนี้ไปรันกับ `claude -p` ได้เลย)

> คำสั่งตัวอย่าง:  
> ```bash
> claude -p "$(cat << 'PROMPT'
> (เนื้อหาพรอมป์ข้างล่างนี้ทั้งก้อน)
> PROMPT
> )" --dangerously-skip-permissions --output-format json --max-turns 16 --model sonnet
> ```

```
You are a senior DevOps/Platform engineer working on my Ubuntu box over CLI with Claude Code.
Your job: create a fully headless, non-interactive workflow to run coding tasks, auto-commit, push, and open PRs with a final Markdown report. Do NOT ask me to confirm anything. Just do it.

## RULES
- Never prompt for confirmation. Assume consent for file edits and command execs.
- Use safe paths under "$HOME/claude-headless".
- All scripts must be POSIX bash, with `set -euo pipefail`.
- Scripts must be executable (`chmod +x`). 
- Prefer idempotent installs (check before install).
- GitHub auth must be non-interactive via $GH_TOKEN env; if missing, print a clear error and exit 1.
- Use a dedicated branch `feature/claude-YYYYmmdd-HHMM` by default.
- Save raw JSON run output into `.reports/`, and make a Markdown report via `make-report.sh`.
- Create a minimal README.md with usage examples.
- Do not leak secrets in logs.

## VARIABLES (allow overrides via env)
- REPO_DIR: default "$HOME/projects/flexstock"
- MODEL: default "sonnet"
- MAX_TURNS: default 12
- PROJECT_HOST: optional (like pos.zentrydev.com) – not used by scripts, kept for future.

## CREATE FILES
1) Create directory tree:
   - $HOME/claude-headless
   - $HOME/claude-headless/scripts
   - $HOME/projects (if missing)

2) Create file: $HOME/claude-headless/scripts/setup_claude_env.sh
   Content:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   if ! command -v git >/dev/null 2>&1; then
     sudo apt-get update -y && sudo apt-get install -y git
   fi
   if ! command -v jq >/dev/null 2>&1; then
     sudo apt-get update -y && sudo apt-get install -y jq
   fi
   if ! command -v node >/dev/null 2>&1; then
     curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
     sudo apt-get install -y nodejs
   fi
   if ! command -v gh >/dev/null 2>&1; then
     type -p curl >/dev/null || (sudo apt-get update -y && sudo apt-get install -y curl)
     curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
     sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
     echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
     sudo apt-get update -y && sudo apt-get install -y gh
   fi
   if ! command -v claude >/dev/null 2>&1; then
     sudo npm i -g @anthropic-ai/claude-code
   fi

   mkdir -p "$HOME/projects" "$HOME/claude-headless/.reports"
   echo "OK: Environment ready."
   ```

3) Create file: $HOME/claude-headless/scripts/run-claude-task.sh
   Content:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   : "${REPO_DIR:=$HOME/projects/flexstock}"
   : "${MODEL:=sonnet}"
   : "${MAX_TURNS:=12}"

   if [ ! -d "$REPO_DIR/.git" ]; then
     echo "ERROR: REPO_DIR '$REPO_DIR' is not a git repository. Please clone first." >&2
     exit 1
   fi
   if ! command -v gh >/dev/null 2>&1; then
     echo "ERROR: gh CLI not found." >&2
     exit 1
   fi
   if [ -z "${GH_TOKEN:-}" ]; then
     echo "ERROR: GH_TOKEN not set. Export a repo-scoped token first." >&2
     exit 1
   fi
   gh auth status >/dev/null 2>&1 || gh auth login --with-token <<< "$GH_TOKEN"

   TASK_PROMPT="${1:-Implement inventory API from spec and add tests}"
   BRANCH="${2:-feature/claude-$(date +%Y%m%d-%H%M)}"
   REPORT_DIR="$REPO_DIR/.reports"
   mkdir -p "$REPORT_DIR"

   pushd "$REPO_DIR" >/dev/null

   git fetch origin || true
   CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
   if [ "$CURRENT_BRANCH" != "main" ] && git rev-parse --verify main >/dev/null 2>&1; then
     git checkout main
     git pull --ff-only || true
   fi
   git checkout -b "$BRANCH"

   RUN_TS="$(date -Is)"
   RAW_JSON="$REPORT_DIR/claude_run_${RUN_TS}.json"

   claude -p "$TASK_PROMPT" \
     --output-format json \
     --model "$MODEL" \
     --max-turns "$MAX_TURNS" \
     --dangerously-skip-permissions \
     --allowedTools "Read,Edit,Write,MultiEdit,Grep,Glob,Bash(git *),Bash(npm *),Bash(go *),Bash(curl *),Bash(jq *),Bash(make *),Bash(sqlc *),Bash(docker *),Bash(gh *),Bash(pgrep *),Bash(systemctl *)" \
     --append-system-prompt "You are a senior engineer. Follow repository conventions, run tests, and create logical commits." \
     > "$RAW_JSON"

   # derive commit message from result
   COMMIT_MSG="$(jq -r '.result' "$RAW_JSON" | sed -n '1,20p' | tr -d '\r' || true)"
   [ -z "$COMMIT_MSG" ] && COMMIT_MSG="chore: automated update by Claude Code"

   git add -A
   if ! git diff --cached --quiet; then
     git commit -m "$COMMIT_MSG" || true
     git push -u origin "$BRANCH"
     PR_URL="$(gh pr create --fill --head "$BRANCH" --base main --title "$COMMIT_MSG" --body "Automated by Claude Code")"
     echo "{\"pr_url\":\"$PR_URL\"}" | jq '.' > "$REPORT_DIR/pr_${RUN_TS}.json"
   else
     echo "No changes to commit."
   fi

   # make md summary
   "$HOME/claude-headless/scripts/make-report.sh" "$RAW_JSON" "$REPORT_DIR/claude_run_${RUN_TS}.md" || true

   echo "=== SUMMARY ==="
   echo "Branch   : $BRANCH"
   [ -f "$REPORT_DIR/pr_${RUN_TS}.json" ] && echo "PR       : $(jq -r .pr_url "$REPORT_DIR/pr_${RUN_TS}.json")"
   echo "Run JSON : $RAW_JSON"

   popd >/dev/null
   ```

4) Create file: $HOME/claude-headless/scripts/make-report.sh
   Content:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   JSON_FILE="${1:?usage: make-report.sh <run.json> [out.md]}"
   OUT="${2:-${JSON_FILE%.json}.md}"

   ts="$(jq -r '.timestamp // now' "$JSON_FILE" 2>/dev/null || date -Is)"
   duration="$(jq -r '.duration_ms // .duration // "n/a"' "$JSON_FILE" 2>/dev/null || echo n/a)"
   turns="$(jq -r '.num_turns // "n/a"' "$JSON_FILE" 2>/dev/null || echo n/a)"
   cost="$(jq -r '.total_cost_usd // "n/a"' "$JSON_FILE" 2>/dev/null || echo n/a)"
   result="$(jq -r '.result // ""' "$JSON_FILE" 2>/dev/null || echo)"

   cat > "$OUT" <<EOF
   # Claude Code Run Report
   - **When**: $ts
   - **Duration**: $duration ms
   - **Turns**: $turns
   - **Cost**: $cost

   ## Result (summary)
   \`\`\`
   $result
   \`\`\`
   EOF

   echo "Report -> $OUT"
   ```

5) (Optional) Create file: $HOME/claude-headless/scripts/enable_hooks.sh
   Content:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   mkdir -p "$HOME/.claude"
   LOG="$HOME/.claude/bash-command-log.txt"
   touch "$LOG"
   echo "Hook enabled. Commands will be appended to: $LOG"
   echo "Note: Configure hooks in Claude Code settings to call:"
   echo "jq -r '\"\\(.tool_input.command) - \\(.tool_input.description // \\\"No description\\\")\"' >> $LOG"
   ```

6) Create $HOME/claude-headless/README.md (quick usage):
   ```md
   # Claude Headless
   ## Setup
   bash ./scripts/setup_claude_env.sh

   ## Run
   export GH_TOKEN=ghp_xxx
   REPO_DIR=$HOME/projects/flexstock \
   MODEL=sonnet \
   MAX_TURNS=12 \
   bash ./scripts/run-claude-task.sh "Implement inventory API from spec and add tests"

   ## Reports
   ls -l $REPO_DIR/.reports/
   ```

7) `chmod +x` all scripts in `scripts/`, then print next steps.
8) Validate syntax (`bash -n`) for each script, print the tree structure.
```

---

## 3) วิธีรันจริง (หลัง Claude สร้างสคริปต์ให้แล้ว)
```bash
# 1) เตรียมสภาพแวดล้อม
bash ~/claude-headless/scripts/setup_claude_env.sh

# 2) โคลน repo (ครั้งแรก)
mkdir -p ~/projects
cd ~/projects
git clone git@github.com:<org>/<repo>.git flexstock

# 3) รันงานให้ Claude ทำ (ไม่ถามยืนยัน)
export GH_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
REPO_DIR=$HOME/projects/flexstock \
MODEL=sonnet \
MAX_TURNS=12 \
bash ~/claude-headless/scripts/run-claude-task.sh \
"Implement inventory API from spec and add tests"

# 4) ดูรายงาน
ls -l ~/projects/flexstock/.reports/
```

---

## 4) Notes
- ปรับ `--allowedTools` ในสคริปต์ให้จำกัดเครื่องมือได้ตามความเสี่ยง
- ถ้าไม่อยากใช้ gh login โต้ตอบ ให้ตั้ง `$GH_TOKEN` เสมอ
- ถ้า repo ใช้ default branch คนละชื่อ (เช่น `main`/`master`) ปรับในสคริปต์ได้