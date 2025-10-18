# audit_cms_zentrydev_security_links.md

> **ROLE**
> Act as a **world-class Senior Laravel Security Engineer** and **DevSecOps lead**.

> **MODE**
> Non-interactive, autonomous execution. Do not ask questions. If a recoverable step fails, fix and retry. If unrecoverable, print the exact failing command and error.

> **OBJECTIVE**
> Perform a **security audit** and a **link integrity audit** for the Laravel project **cms_zentrydev** and deliver a concise **Markdown report** suitable for sending to another LLM for next-step planning.

---

## 0) Scope & Paths

- Monorepo: `aunji/internal_ai_lab`
- Project path: `/home/aunji/internal_ai_lab/cms_zentrydev`
- Output files:
  - Full report: `/home/aunji/internal_ai_lab/cms_zentrydev/AUDIT_REPORT.md`
  - Console summary: **print last** a compact summary with TOP risks & dead links
- Do not change app behavior (read-only), except to install dev-only tools if needed.

---

## 1) Preflight

```bash
set -euo pipefail
cd /home/aunji/internal_ai_lab/cms_zentrydev
php -v
composer --version
```

If `vendor/` is missing, run `composer install --no-interaction --prefer-dist`.

---

## 2) Dependency Vulnerabilities

1) **Composer** known vulns
```bash
composer audit --no-interaction || true
```

2) **Node** (if package.json exists)
```bash
if [ -f package.json ]; then
  npm --version || true
  npm audit --omit=dev || true
fi
```

Capture stdout/stderr and include findings in the report.

---

## 3) Laravel App Security Checks (Static)

Run the following checks and collect results:

### 3.1 Configuration
- `.env` or config values:
  - `APP_ENV`, `APP_DEBUG`, `APP_URL`, `SESSION_DRIVER`, `SESSION_SECURE_COOKIE`, `SESSION_SAME_SITE`
  - `LOG_LEVEL`, `MAIL_*` (no secrets hard-coded in config files), `FILESYSTEM_DISK`
- Ensure **debug is OFF in production**.
- Check `config/filament.php` auth guard and path protection.

Commands:
```bash
grep -nE "APP_DEBUG|APP_ENV|APP_URL|SESSION_|LOG_LEVEL|FILESYSTEM_" .env* || true
[ -f config/filament.php ] && sed -n '1,200p' config/filament.php || true
```

### 3.2 CSRF & CORS
- List `VerifyCsrfToken` exclusions.
- Presence of `\Fruitcake\Cors\HandleCors` or custom CORS config.
```bash
sed -n '1,200p' app/Http/Middleware/VerifyCsrfToken.php || true
[ -f config/cors.php ] && sed -n '1,200p' config/cors.php || true
```

### 3.3 Authentication & Authorization
- Enumerate routes missing auth on admin-like paths.
- Check Filament routes protected by its auth.
```bash
php artisan route:list --columns=Method,URI,Name,Action,Middleware > storage/route_list.txt
grep -E "admin|filament" storage/route_list.txt || true
grep -E "admin|filament" -n routes/*.php app/Http/Controllers -R || true
```

### 3.4 Mass Assignment & Validation
- Flag models without `$fillable`/`$guarded`.
- Flag controllers storing/updating without `->validate()` or FormRequest.
```bash
grep -R "class .* extends Model" app/Models | cut -d: -f1 | sort -u | while read f; do
  echo "## $f"; grep -nE '\$fillable|\$guarded' "$f" || echo "NO_FILLABLE_OR_GUARDED";
done

grep -R "public function (store|update)\(" -n app/Http/Controllers | cut -d: -f1 | sort -u | while read c; do
  echo "## $c"; grep -nE "->validate\(|FormRequest" "$c" || echo "NO_VALIDATION_FOUND";
done
```

### 3.5 Output Escaping
- Find unescaped Blade echoes `{!! ... !!}`.
```bash
grep -R --line-number "{!!" resources/views || true
```

### 3.6 File Upload & Media
- Search for `store`, `addMedia` uses and ensure validation.
```bash
grep -R --line-number "addMedia\(|storeAs\(|store\(" app -n || true
```

### 3.7 Headers & CSP
- Check for Security headers (CSP, X-Frame-Options, HSTS, X-Content-Type-Options).
```bash
grep -R --line-number "Content-Security-Policy\|X-Frame-Options\|Strict-Transport-Security\|X-Content-Type-Options" app routes -n || true
[ -f app/Http/Middleware/SecurityHeaders.php ] && sed -n '1,200p' app/Http/Middleware/SecurityHeaders.php || true
```

### 3.8 Secrets in Repo
```bash
git ls-files | xargs grep -nE "(api[_-]?key|secret|password|token)\s*=\s*|sk_[A-Za-z0-9]{20,}" --color=never || true
```

---

## 4) Link Integrity Audit

### 4.1 Route existence vs. Blade usage
- Extract all `route('name')` from Blade & Controllers and verify against `route:list`.
```bash
php artisan route:list --json > storage/routes.json
jq -r '.[].name' storage/routes.json | sort -u > storage/route_names.txt || true

grep -Rho "route\(['\"][^)]+['\"]\)" resources app | sed -E "s/.*route\(['\"]([^'\"]+)['\"].*/\1/" | sort -u > storage/used_route_names.txt || true

comm -23 storage/used_route_names.txt storage/route_names.txt > storage/missing_routes_by_name.txt || true
```

### 4.2 Plain hrefs & anchors
- Find `<a>` with `href="#"` or missing/empty href.
```bash
grep -R --line-number "<a[^>]*href=[\"']#?[\"']" resources/views || true
```

### 4.3 Static URLs and Dead Paths (best-effort)
- Collect unique `href="/..."` and test with a lightweight curl to local dev (if `php artisan serve` not running, **skip**).
```bash
grep -Rho "href=[\"']/[^\"']+[\"']" resources/views | sed -E "s/.*href=[\"']([^\"']+)[\"'].*/\1/" | sort -u > storage/href_paths.txt || true
```

> **Do not** start any servers. Only static analysis; list paths for manual verification.

### 4.4 Assets
- Find missing assets references (images/css/js) under `public/`.
```bash
grep -Rho "src=[\"']/[^\"']+[\"']" resources/views | sed -E "s/.*src=[\"']([^\"']+)[\"'].*/\1/" | sort -u > storage/src_paths.txt || true
```

---

## 5) Optional: Static Analysis (Larastan)

If `nunomaduro/larastan` is not installed, install as dev and run level 5.

```bash
if ! grep -q "nunomaduro/larastan" composer.json; then
  composer require --dev nunomaduro/larastan:^2.9 --no-interaction || true
fi
vendor/bin/phpstan analyse --memory-limit=1G --level=5 app || true
```

Include summary of errors/warnings in the report.

---

## 6) Generate Markdown Report

Create `/home/aunji/internal_ai_lab/cms_zentrydev/AUDIT_REPORT.md` with the following sections and include real findings:

- **Project**: cms_zentrydev
- **Date/Time (server)**: `date -Is`
- **Executive Summary**: Top 5 risks and suggested next actions
- **Security Findings**
  - Config & Secrets
  - CSRF/CORS
  - Authz/Authn & Admin routes
  - Mass Assignment & Validation
  - Output Escaping & Templating
  - Uploads/Media
  - Headers & CSP
  - Dependencies (composer/npm)
- **Link Integrity Findings**
  - Missing route names (file:line → route name)
  - `<a>` without proper href
  - Potentially dead href/src paths for manual verify
- **Static Analysis (Larastan) Summary**
- **Appendix**
  - `php artisan route:list` excerpt
  - Tool outputs (composer audit summary, npm audit summary)

Script the report assembly using bash `cat <<'MD' > AUDIT_REPORT.md` and append command outputs between fenced code blocks.

---

## 7) Print Console Summary

At the end, print:
- TOP 5 risks (one-liners)
- Count of missing route names
- Count of anchors with `href="#"` or empty href
- Path to the full report

---

## 8) Commit & Push (optional)

If any dev-only files were added (e.g., `storage/*.txt`, `AUDIT_REPORT.md`), commit under a `chore(security-audit): ...` message **only if** gh auth is ready.

```bash
cd /home/aunji/internal_ai_lab
git add cms_zentrydev/AUDIT_REPORT.md cms_zentrydev/storage/*.txt 2>/dev/null || true
git commit -m "chore(cms_zentrydev): add security & link audit report" || true
git pull --rebase --autostash || true
git push -u origin main || true
```

---

## 9) Final Output (must print)

- ✅ **Audit complete** with counts & important highlights
- 📄 Report path: `/home/aunji/internal_ai_lab/cms_zentrydev/AUDIT_REPORT.md`
- 📌 Next-step suggestions (3–5 bullets)

> End of prompt.
