# remediate_cms_zentrydev_all_in_one.md

> **ROLE**: World-class Senior Laravel Security Engineer (DevSecOps).  
> **MODE**: Non-interactive & autonomous. Do not ask for confirmation. Fix & retry on recoverable errors; if unrecoverable, print the failing command and error, then stop.

> **OBJECTIVE**: Apply security hardening and link-related fixes to **cms_zentrydev** in one run:
> - Tighten CORS
> - Add Security Headers middleware (incl. CSP baseline)
> - Disable debug in `.env`
> - Session cookie hardening
> - Sanitize risky Blade `{!! !!}` output
> - Update vulnerable dependencies (browsershot ≥ 5.0.5) + install purifier
> - Optimize, test, commit & push

---

## 0) Paths & Preconditions
- Monorepo: `aunji/internal_ai_lab`
- App path: `/home/aunji/internal_ai_lab/cms_zentrydev`
- Use existing `gh` auth or `$GITHUB_TOKEN`. Do **not** start servers.

```bash
set -euo pipefail
APP="/home/aunji/internal_ai_lab/cms_zentrydev"
MONO="/home/aunji/internal_ai_lab"
cd "$APP"
php -v
composer --version
```

If `vendor` missing: `composer install --no-interaction --prefer-dist`

---

## 1) Disable Debug & Harden Session via .env (idempotent)

```bash
set -euo pipefail
cd "$APP"
cp .env .env.bak.$(date +%s) || true

# APP_DEBUG=false
if grep -q '^APP_DEBUG=' .env; then
  sed -i 's/^APP_DEBUG=.*/APP_DEBUG=false/' .env
else
  echo 'APP_DEBUG=false' >> .env
fi

# APP_ENV=production (optional; keep current if already set)
if ! grep -q '^APP_ENV=' .env; then echo 'APP_ENV=production' >> .env; fi

# Session hardening
if grep -q '^SESSION_SECURE_COOKIE=' .env; then
  sed -i 's/^SESSION_SECURE_COOKIE=.*/SESSION_SECURE_COOKIE=true/' .env
else
  echo 'SESSION_SECURE_COOKIE=true' >> .env
fi

if grep -q '^SESSION_SAME_SITE=' .env; then
  sed -i 's/^SESSION_SAME_SITE=.*/SESSION_SAME_SITE=lax/' .env
else
  echo 'SESSION_SAME_SITE=lax' >> .env
fi
```

---

## 2) Tighten CORS (config/cors.php + .env)

```bash
set -euo pipefail
cd "$APP"

applypatch <<'PATCH'
*** Begin Patch
*** Update File: config/cors.php
@@
-return [
-    'paths' => ['api/*', 'sanctum/csrf-cookie'],
-    'allowed_methods' => ['*'],
-    'allowed_origins' => ['*'],
-    'allowed_origins_patterns' => [],
-    'allowed_headers' => ['*'],
-    'exposed_headers' => [],
-    'max_age' => 0,
-    'supports_credentials' => false,
-];
+return [
+    'paths' => ['api/*', 'sanctum/csrf-cookie'],
+    'allowed_methods' => ['GET','POST','PUT','PATCH','DELETE','OPTIONS'],
+    'allowed_origins' => explode(',', env('CORS_ALLOWED_ORIGINS', 'https://yourdomain.com')),
+    'allowed_origins_patterns' => [],
+    'allowed_headers' => ['Content-Type','X-Requested-With','Authorization'],
+    'exposed_headers' => [],
+    'max_age' => 3600,
+    'supports_credentials' => false,
+];
*** End Patch
PATCH

# Ensure env var exists (example domain; adjust later as needed)
if ! grep -q '^CORS_ALLOWED_ORIGINS=' .env; then
  echo 'CORS_ALLOWED_ORIGINS=https://yourdomain.com' >> .env
fi
```

---

## 3) Add Security Headers Middleware (CSP baseline) & Register

```bash
set -euo pipefail
cd "$APP"

applypatch <<'PATCH'
*** Begin Patch
*** Add File: app/Http/Middleware/SecurityHeaders.php
+<?php
+namespace App\Http\Middleware;
+use Closure;
+
+class SecurityHeaders {
+    public function handle($request, Closure $next){
+        $resp = $next($request);
+        $resp->headers->set('X-Frame-Options', 'SAMEORIGIN');
+        $resp->headers->set('X-Content-Type-Options', 'nosniff');
+        $resp->headers->set('Referrer-Policy', 'no-referrer-when-downgrade');
+        // HSTS: enable only behind HTTPS
+        if (strtolower($request->getScheme()) === 'https') {
+            $resp->headers->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
+        }
+        // Baseline CSP; adjust allowlists as needed
+        $csp = "default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline' https:; script-src 'self' https:; connect-src 'self' https:; font-src 'self' https: data:; frame-ancestors 'self';";
+        $resp->headers->set('Content-Security-Policy', $csp);
+        return $resp;
+    }
+}
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Update File: app/Http/Kernel.php
@@
     protected $middlewareGroups = [
         'web' => [
             \App\Http\Middleware\EncryptCookies::class,
             \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
             \Illuminate\Session\Middleware\StartSession::class,
+            \App\Http\Middleware\SecurityHeaders::class,
             \Illuminate\View\Middleware\ShareErrorsFromSession::class,
             \App\Http\Middleware\VerifyCsrfToken::class,
             \Illuminate\Routing\Middleware\SubstituteBindings::class,
         ],
*** End Patch
PATCH
```

---

## 4) Sanitize risky Blade `{!! !!}` with Purifier

Install package and define a global helper. Then **wrap unescaped blocks** with `clean(...)`. (We’ll attempt a conservative codemod and report any files changed.)

```bash
set -euo pipefail
cd "$APP"
composer require mews/purifier --no-interaction || true
php artisan vendor:publish --provider="Mews\Purifier\PurifierServiceProvider" --force || true

# Global helper: app/Support/helpers.php (autoloaded via composer.json)
applypatch <<'PATCH'
*** Begin Patch
*** Add File: app/Support/helpers.php
+<?php
+if (!function_exists('clean')) {
+    /**
+     * Clean HTML using Mews\Purifier with default profile.
+     */
+    function clean($html, $profile = null) {
+        try { return \Mews\Purifier\Facades\Purifier::clean($html, $profile); }
+        catch (\Throwable $e) { return e($html); }
+    }
+}
*** End Patch
PATCH

# Ensure helpers autoload
if ! grep -q "app/Support/helpers.php" composer.json; then
  jq '.autoload.files |= ( . + ["app/Support/helpers.php"] )' composer.json > composer.json.tmp && mv composer.json.tmp composer.json || true
  composer dump-autoload -o || true
fi

# Codemod: wrap simple `{!! ... !!}` to `{!! clean(...) !!}` (non-greedy; backup before)
set +e
FILES=$(grep -RIl --include=\*.blade.php "{!!" resources/views || true)
for f in $FILES; do
  cp "$f" "$f.bak" || true
  perl -0777 -pe "s/\{\!\!\s*(.*?)\s*\!\!\}/{!! clean(\$1) !!}/gs" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
set -e
```

> หมายเหตุ: โค้ดนี้ตั้งใจ **ไม่แตะ** `{{ }}` (ที่ escaped อยู่แล้ว) และอาจเว้นรูปแบบซับซ้อนบางส่วนไว้ คุณจะได้สำเนา `.bak` ให้ตรวจด้วย

---

## 5) Update vulnerable dependency (browsershot) & Optimize

```bash
set -euo pipefail
cd "$APP"
# Update Browsershot to patched range
composer require spatie/browsershot:^5.0.5 --update-with-all-dependencies --no-interaction || true

php artisan config:clear
php artisan optimize
```

---

## 6) Optional: Quick grep report (post-fix)

```bash
set -euo pipefail
cd "$APP"
echo "=== Post-fix checks ==="
echo "[Unescaped blocks remaining]"
grep -R --line-number "{!!" resources/views || true

echo "[CORS config preview]"
sed -n '1,200p' config/cors.php || true

echo "[SecurityHeaders registered?]"
grep -n "SecurityHeaders::class" app/Http/Kernel.php || true
```

---

## 7) Tests (best-effort)

```bash
set -euo pipefail
cd "$APP"
php artisan test --without-tty || true
```

---

## 8) Commit & Push

```bash
set -euo pipefail
cd "$MONO"
git add cms_zentrydev
git commit -m "sec(cms_zentrydev): tighten CORS, add security headers, disable debug, session hardening, sanitize unescaped blade, update browsershot" || true
git pull --rebase --autostash || true
git push -u origin main || true
```

---

## 9) Final Output (print)

Print a compact summary:
- Number of `.blade.php` files modified by codemod
- Any remaining `{!! !!}` occurrences
- Confirmation of CORS & SecurityHeaders changes
- Composer changes (browsershot/purifier)
- Path to this run’s backup files (`*.bak`)

> End of prompt.
