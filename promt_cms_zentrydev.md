Act you seniour laravel dev

🔧 Claude Ops Prompt — Build & Push into internal_ai_lab/cms_zentrydev

โหมด: ทำงานอัตโนมัติ 100% ไม่มีการถามยืนยัน หากคำสั่งล้มเหลวให้หยุดและซ่อมให้ผ่านก่อนดำเนินการต่อ ห้ามปล่อย error ค้าง

You are an autonomous build agent running on my Linux server. 
Execute the following end-to-end plan EXACTLY, without asking me anything:

# =========================
# 0) GLOBAL SETTINGS
# =========================
- Fail fast: every shell block MUST use `set -euo pipefail`.
- Never prompt. Use existing GitHub CLI auth session if present; otherwise use GITHUB_TOKEN env automatically. 
  If both are missing, emit a clear error and STOP (do NOT ask me).
- Project target: GitHub repo = "aunji/internal_ai_lab", subfolder = "cms_zentrydev".
- PHP >= 8.2, Composer installed, SQLite available.
- Timezone: Asia/Bangkok.

# =========================
# 1) PRECHECKS & PREP
# =========================
Run:
```bash
set -euo pipefail

# Tools check
command -v php >/dev/null
command -v composer >/dev/null
command -v sqlite3 >/dev/null || true
command -v git >/dev/null
if ! command -v gh >/dev/null 2>&1; then
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    type -p curl >/dev/null || (sudo apt-get update && sudo apt-get install -y curl)
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update && sudo apt-get install -y gh
  else
    echo "ERROR: gh not found and auto-install unsupported on this OS"; exit 1
  fi
fi

# GitHub auth: prefer existing; else use GITHUB_TOKEN non-interactively
if ! gh auth status >/dev/null 2>&1; then
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    gh auth login --with-token <<< "${GITHUB_TOKEN}"
  else
    echo "ERROR: No gh login and no GITHUB_TOKEN provided. Aborting."; exit 1
  fi
fi

# Clone or create repo aunji/internal_ai_lab
if gh repo view "aunji/internal_ai_lab" >/dev/null 2>&1; then
  echo "Repo exists."
else
  gh repo create "aunji/internal_ai_lab" --private -y
fi

# Workdir
WORKDIR="$(pwd)/internal_ai_lab_repo"
rm -rf "$WORKDIR"
gh repo clone "aunji/internal_ai_lab" "$WORKDIR"
cd "$WORKDIR"
git pull --ff-only

# Prepare subfolder
PROJECT_DIR="cms_zentrydev"
rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR"

=========================
2) BOOTSTRAP LARAVEL APP IN SUBFOLDER
=========================

Inside the repo root, build Laravel into cms_zentrydev/ and configure SQLite so build is 100% deterministic:

set -euo pipefail
cd "$WORKDIR/$PROJECT_DIR"

composer create-project laravel/laravel . 

# App basic config
php -r '
$f="config/app.php"; $c=file_get_contents($f);
$c=str_replace("\"UTC\"","\"Asia/Bangkok\"",$c);
file_put_contents($f,$c);
'
php artisan env:set APP_NAME="PHV CMS"
php artisan env:set APP_ENV=production
php artisan env:set APP_DEBUG=false

# SQLite for dev/test
php artisan env:set DB_CONNECTION=sqlite
php artisan env:unset DB_HOST || true
php artisan env:unset DB_PORT || true
php artisan env:unset DB_DATABASE || true
php artisan env:unset DB_USERNAME || true
php artisan env:unset DB_PASSWORD || true
mkdir -p database && touch database/database.sqlite

# Packages
composer require filament/filament spatie/laravel-permission spatie/laravel-medialibrary:^11.0 \
cviebrock/eloquent-sluggable spatie/laravel-settings spatie/laravel-sitemap spatie/laravel-backup \
spatie/laravel-activitylog

php artisan storage:link

=========================
3) ADD CONFIG, MODELS, MIGRATIONS, CONTROLLERS, VIEWS, SEEDERS, TESTS
=========================

Implement the upgraded v2 spec (full forms + Blade theme + JSON-LD + sitemap) exactly as designed.
Create files and contents IDENTICAL to the approved design.
(Use the build_cms_zentrydev_v2 spec you already have; no questions.)

Add:

config/cms.php

app/Settings/SiteSettings.php + settings migrations (php artisan vendor:publish --provider="Spatie\LaravelSettings\LaravelSettingsServiceProvider" --tag="settings-migrations")

Migrations: CMS core + Catalog + Menus (names per spec) then php artisan migrate

Models: Post, Category, Tag, Menu, MenuItem, ProductCategory, Product (with Sluggable & Medialibrary)

Routes: web.php (home/blog/page/catalog/sitemap)

Controllers: Frontend/PageController, BlogController, CatalogController, SitemapController

Views: layouts/app.blade.php (Tailwind CDN), home, blog (index/show), page/show, store (catalog/product), partials/sitemap

Seeders: PermissionSeeder, AdminSeeder, SampleContentSeeder; then run all three

Filament Resources: Post, Category, Tag, Menu, MenuItem, Product, ProductCategory

Patch PostResource & ProductResource to include the full forms/tables exactly as in the spec.

Tests: tests/Feature/RoutesSmokeTest.php (home/blog/catalog 200)

Run in order:

set -euo pipefail
# Settings migration
php artisan vendor:publish --provider="Spatie\LaravelSettings\LaravelSettingsServiceProvider" --tag="settings-migrations"
php artisan migrate

# >>> Create/overwrite all files exactly as per spec here (use your file writer). <<<

# After writing files:
php artisan migrate
php artisan db:seed --class=Database\\Seeders\\PermissionSeeder
php artisan db:seed --class=Database\\Seeders\\AdminSeeder
php artisan db:seed --class=Database\\Seeders\\SampleContentSeeder

# Make Filament user (idempotent)
php artisan make:filament-user --name=Admin --email=admin@example.com --password=Admin12345! || true

# Generate resources (idempotent) and apply patches to PostResource & ProductResource
php artisan make:filament-resource Post --generate || true
php artisan make:filament-resource Category --generate || true
php artisan make:filament-resource Tag --generate || true
php artisan make:filament-resource Menu --generate || true
php artisan make:filament-resource MenuItem --generate || true
php artisan make:filament-resource Product --generate || true
php artisan make:filament-resource ProductCategory --generate || true

# Apply resource patches exactly as designed (ensure no syntax errors).
# (Use your patch/write capability from the spec.)

# Optimize & run tests
php artisan optimize
php artisan test --without-tty

=========================
4) README & FINAL HEALTH CHECK
=========================

Create a concise README at cms_zentrydev/README.md describing dev quickstart (SQLite), admin credentials, panel path /admin, and prod DB switch. Then run:

set -euo pipefail
php artisan about
php artisan test --without-tty

=========================
5) GIT COMMIT & PUSH (MONOREPO LAYOUT)
=========================

We are inside the cloned repo internal_ai_lab.
Do NOT git init inside cms_zentrydev.
Add the new subfolder to the monorepo, commit, and push to main.

set -euo pipefail
cd "$WORKDIR"
git add "$PROJECT_DIR"
git commit -m "feat(cms_zentrydev): Laravel CMS+Catalog (Filament full forms, Tailwind theme, SEO/JSON-LD, seeders, tests) [auto-build]"
git pull --rebase --autostash
git push origin main

=========================
6) OUTPUT
=========================

Print the following, then exit 0:

Absolute path of the created project folder.

Result of gh repo view aunji/internal_ai_lab --json name,defaultBranchRef,url (single line JSON).

The admin login for Filament: admin@example.com
 / Admin12345!

A reminder that /admin is the panel path.


---

### ใช้งานยังไง (สั้น ๆ)
1) ตั้งค่าโทเค็นล่วงหน้าในเซิร์ฟเวอร์ (แนะนำ)  
```bash
export GITHUB_TOKEN=ghp_xxx   # หรือมี gh auth login อยู่แล้วก็ได้


เปิด Claude Code บนเซิร์ฟเวอร์ แล้ว วางพรอมป์ต์ด้านบน ให้รันทันที

เสร็จแล้วจะได้โค้ดอยู่ใน repo: aunji/internal_ai_lab/cms_zentrydev/ พร้อมใช้งาน (/admin เข้าด้วย admin@example.com
 / Admin12345!)
