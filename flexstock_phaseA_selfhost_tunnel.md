# FlexStock — Phase A Internal Demo (Self-Hosted + Cloudflare Tunnel)
> Role for Claude: **Full-stack senior dev & infra engineer at a world-class IT company**
>
> Goal: Bring FlexStock online for demo TODAY using your home Ubuntu box (the machine that already runs Docker, MySQL, Laravel, Filament admin).  
> Expose `/admin` securely to business owners via a public HTTPS URL using Cloudflare Tunnel.  
> No VPS, no Render, no money.

This playbook MUST run non-interactively.
You are to generate/setup everything automatically.

We are in this repo:
`/home/aunji/flexstock`

We assume:
- Laravel backend running in Docker (php-fpm + web server in container or via Caddy/Nginx in docker-compose)
- MySQL in Docker
- Admin panel (Filament) available at `/admin`
- Sanctum already installed
- Multi-tenant is {company}-scoped in API, and Admin Panel requires company context in session.

We will produce:
1. A bash script `scripts/flexstock_selfhost_tunnel_setup.sh`
2. `.env.demo` suggestion for demo mode
3. Docs for "what URL do I give to the SME right now?"

You will create the script, update docs, and ensure the codebase is ready.

Do NOT ask for confirmation.  
Do NOT pause for manual edits.  
Just generate.

---

## 1. Directory & Script Layout

Create (or update) the following files:

### `scripts/flexstock_selfhost_tunnel_setup.sh`
Bash script that will:
1. Check docker, docker-compose
2. Bring up the stack (`docker-compose up -d`)
3. Ensure we have a `.env.demo` and explain how to apply it to `.env`
4. Install cloudflared if not present
5. Start a Cloudflare tunnel to expose the Laravel HTTP port publicly
6. Echo the final public URL + `/admin`

Script requirements:
- Script must be idempotent (safe to rerun)
- Must not prompt the user for interactive input except where Cloudflare token is absolutely required
- Must clearly echo "✅ FLEXSTOCK PUBLIC URL:" at the end

Assumptions:
- App inside docker is served on `http://localhost:8000`
- We will tunnel <public_url> → localhost:8000

Content to generate in this script:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo ">>> [Step 0] Checking requirements..."
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker not found. Please install Docker first."
  exit 1
fi
if ! command -v docker-compose >/dev/null 2>&1; then
  echo "❌ docker-compose not found. Please install docker-compose first."
  exit 1
fi

echo ">>> [Step 1] Starting FlexStock stack via docker-compose..."
cd /home/aunji/flexstock
docker-compose up -d

echo ">>> [Step 2] Running migrations and storage:link inside container..."
# We assume service is called 'app' in docker-compose (php-fpm container)
docker-compose exec app php artisan migrate --force || true
docker-compose exec app php artisan storage:link || true
docker-compose exec app php artisan optimize || true

echo ">>> [Step 3] Ensuring demo admin user exists..."
cat << 'PHP_CMDS' | docker-compose exec -T app php artisan tinker
use App\Models\User;
use App\Models\Company;

$user = User::firstOrCreate(
  ['email' => 'owner@demo.local'],
  ['name' => 'Demo Owner', 'password' => bcrypt('password')]
);

$company = Company::first(); // first tenant acts as demo
if ($company) {
    $user->companies()->syncWithoutDetaching([
        $company->id => ['role' => 'admin']
    ]);
    echo "Attached user to company as admin\n";
} else {
    echo "WARNING: No company found. Seed demo data first.\n";
}
PHP_CMDS

echo ">>> [Step 4] Generating .env.demo suggestion for external access..."
cat > /home/aunji/flexstock/.env.demo << 'EOF'
APP_NAME=FlexStock
APP_ENV=demo
APP_DEBUG=false
APP_URL=https://REPLACE_ME_PUBLIC_URL

# Sanctum / session cookie domains (IMPORTANT for login from external browser)
SESSION_DRIVER=cookie
SESSION_DOMAIN=.REPLACE_ME_PUBLIC_DOMAIN
SANCTUM_STATEFUL_DOMAINS=REPLACE_ME_PUBLIC_DOMAIN,localhost,127.0.0.1

# CORS allow panel access
CORS_ALLOWED_ORIGINS=https://REPLACE_ME_PUBLIC_URL,http://localhost:8000,http://127.0.0.1:8000

# Database (use your existing docker mysql service)
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=flexstock
DB_USERNAME=flexstock
DB_PASSWORD=flexstock

# File storage
FILESYSTEM_DISK=public
EOF

echo ">>> NOTE:"
echo ">>>   - .env.demo created."
echo ">>>   - Update your real .env with these values (APP_URL, SESSION_DOMAIN, SANCTUM_STATEFUL_DOMAINS, etc.)"
echo ">>>   - SESSION_DOMAIN MUST be just the domain (no protocol), e.g. mytunnel.trycloudflare.com"

echo ">>> [Step 5] Installing cloudflared if missing..."
if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared not found. Installing..."
  # Ubuntu/Debian quick install
  # (If distro differs, user may need to adjust.)
  sudo apt-get update -y && sudo apt-get install -y wget
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -O /tmp/cloudflared.deb
  sudo dpkg -i /tmp/cloudflared.deb || true
fi

echo ">>> [Step 6] Starting Cloudflare Tunnel (quick tunnel)..."

# We'll run a quick tunnel (cloudflared tunnel --url http://localhost:8000)
# This will output a https://xxxx.trycloudflare.com URL.
# We'll try to capture it.
TUNNEL_OUTPUT=$(cloudflared tunnel --url http://localhost:8000 --no-autoupdate 2>&1 | tee /tmp/cloudflared_url.log || true)

PUBLIC_URL=$(echo "$TUNNEL_OUTPUT" | grep -Eo "https://[a-zA-Z0-9.-]+trycloudflare.com" | head -n1 || true)

if [ -z "$PUBLIC_URL" ]; then
  echo "⚠ Could not automatically detect public URL from tunnel output."
  echo "   Please check /tmp/cloudflared_url.log manually."
  echo "   Once you have PUBLIC_URL, set:"
  echo "     APP_URL=<PUBLIC_URL>"
  echo "     SESSION_DOMAIN=<PUBLIC_URL domain only>"
  echo "   and access <PUBLIC_URL>/admin"
else
  echo ">>> Cloudflare tunnel public URL detected: $PUBLIC_URL"
  echo ">>> You can now access FlexStock Admin Panel here:"
  echo "✅ FLEXSTOCK PUBLIC URL: $PUBLIC_URL/admin"
  echo
  echo "IMPORTANT NEXT STEPS:"
  echo "1) Put that PUBLIC_URL into .env (APP_URL, etc.)"
  echo "2) php artisan optimize"
  echo "3) Login with:"
  echo "   email: owner@demo.local"
  echo "   pass : password"
fi

echo ">>> DONE."
Permissions:

Add scripts/ to repo if not exists.

After creation, we will chmod +x scripts/flexstock_selfhost_tunnel_setup.sh.

Commit:
chore(demo): add flexstock_selfhost_tunnel_setup.sh for internal tunnel demo

2. Update docs: DEMO_README.md
Create a new file at project root: /home/aunji/flexstock/DEMO_README.md

Content to generate:

markdown
Copy code
# FlexStock Demo Mode (Phase A: Selfhost + Cloudflare Tunnel)

This mode is for letting an SME owner try the system TODAY with zero hosting cost.

## What this gives you
- Public HTTPS URL (via Cloudflare tunnel)
- Filament Admin Panel at /admin
- Multi-tenant isolation intact
- Stock workflow, Sale Order workflow, Payment Slip upload all usable
- Role-based access still enforced

## How to run (on your Ubuntu box)
```bash
cd /home/aunji/flexstock
bash scripts/flexstock_selfhost_tunnel_setup.sh
When the script finishes it will print:
✅ FLEXSTOCK PUBLIC URL: https://SOMETHING.trycloudflare.com/admin

Send that URL + credentials to the SME.

Login credentials (demo)
text
Copy code
Email:    owner@demo.local
Password: password
Role:     admin (for the first company)
VERY IMPORTANT
The tunnel URL changes each time you rerun the script unless you set up a named Cloudflare tunnel with auth.

SESSION_DOMAIN and SANCTUM_STATEFUL_DOMAINS in .env must match that public domain (no protocol).

This is not production:

If your PC sleeps, SME can't access.

Data is in your MySQL.

SSL is managed by Cloudflare free tunnel.

When they like it ➜ move to paid / always-on hosting.

yaml
Copy code

**Commit:**  
`docs(demo): add DEMO_README.md for SME trial instructions`

---

## 3. Codebase assumptions check
Claude MUST:
- Confirm docker-compose service name for app container (if different from `app`, adjust script).
- Confirm app listens on port 8000 inside your network (Caddy / PHP / Nginx). If different, also update tunnel URL in the script.
- If Filament requires login guard changes (e.g. Filament uses a different guard than Sanctum), ensure:
  - Filament is using the same `users` table
  - Filament login works with the user created in tinker
- Make sure `/admin` actually loads under that public URL (CORS / SESSION_DOMAIN / SANCTUM_STATEFUL_DOMAINS fix)

If needed, Claude MUST patch:
- `config/sanctum.php`
- `config/cors.php`
- `.env.example` or `.env.demo` fields
to make it work from an external domain.

**Commit:**  
`fix(demo): align Sanctum/CORS/session config for external tunnel access`

---

## 4. After all commits
Claude MUST:
1. Add `scripts/` dir if doesn't exist, add executable bit to the script:
```bash
git add scripts/flexstock_selfhost_tunnel_setup.sh DEMO_README.md
git update-index --chmod=+x scripts/flexstock_selfhost_tunnel_setup.sh
Commit in logical order:

chore(demo): add flexstock_selfhost_tunnel_setup.sh for internal tunnel demo

docs(demo): add DEMO_README.md for SME trial instructions

fix(demo): align Sanctum/CORS/session config for external tunnel access (if needed)

Push a branch feature/demo-cloudflare-tunnel

If gh and GH_TOKEN exist:

bash
Copy code
git push -u origin feature/demo-cloudflare-tunnel
gh pr create --fill --title "chore: Phase A internal demo tunnel setup" \
  --body "Adds selfhost+tunnel script, DEMO_README.md, and external-access config so SME owners can try FlexStock over HTTPS without paid hosting."
5. Acceptance
After Claude finishes, you (human) should be able to:

bash
Copy code
cd /home/aunji/flexstock
bash scripts/flexstock_selfhost_tunnel_setup.sh
And get output like:

text
Copy code
✅ FLEXSTOCK PUBLIC URL: https://abcxyz123.trycloudflare.com/admin

IMPORTANT NEXT STEPS:
1) Put that PUBLIC_URL into .env (APP_URL, SESSION_DOMAIN...)
2) php artisan optimize
3) Login:
   email: owner@demo.local
   pass : password
If you can open that URL on your phone (4G) and login to /admin, Phase A = SUCCESS.

END PROMPT FOR CLAUDE
bash
Copy code

ขั้นตอนใช้งาน:
1. สร้างไฟล์ใหม่ในเครื่องคุณ:  
   `/home/aunji/flexstock_phaseA_selfhost_tunnel.md`
2. วางเนื้อหาทั้งหมดด้านบนลงไป
3. รัน Claude Code CLI ประมาณนี้ (ปรับ path ให้ตรงจริงของคุณ):

```bash
cd /home/aunji/flexstock
claude -p "$(awk '/^BEGIN PROMPT FOR CLAUDE$/{flag=1;next}/^END PROMPT FOR CLAUDE$/{flag=0}flag' ../flexstock_phaseA_selfhost_tunnel.md)" \
  --dangerously-skip-permissions --output-format json --model sonnet --max-turns 36
เสร็จแล้วคุณก็รันสคริปต์ที่มันสร้าง:

bash
Copy code
bash scripts/flexstock_selfhost_tunnel_setup.sh
