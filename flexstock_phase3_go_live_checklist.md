
# FlexStock — Phase 3 Admin Panel **Go‑Live & QA Checklist**

**Scope:** Filament v3 Admin at `/admin` for multi‑tenant FlexStock.  
**Target envs:** `local` → `staging` → `production`.

---

## 0) Pre‑flight
- [ ] `.env` has correct **APP_URL**, **SESSION_DOMAIN**, **SANCTUM_STATEFUL_DOMAINS**.
- [ ] CORS allowed origins (frontend hosts) set in `.env` (e.g. `CORS_ALLOWED_ORIGINS=https://*.zentrydev.com,http://localhost:5173`).
- [ ] Storage symlink: `php artisan storage:link`.
- [ ] Queue driver chosen (sync/redis) depending on slip upload/notifications usage.
- [ ] Mail driver configured if using notifications.

---

## 1) Database & Migrations
```bash
php artisan migrate --force
php artisan optimize:clear && php artisan optimize
```
- [ ] Verify new tables/columns for payments/slips exist.
- [ ] Check indexes on `sale_orders(company_id,status,payment_state,created_at)`.

---

## 2) Admin User & Company Access
```bash
php artisan tinker
>>> $u = \App\Models\User::firstOrCreate(['email'=>'admin@test.com'], ['name'=>'Admin','password'=>bcrypt('password')]);
>>> $c = \App\Models\Company::first();
>>> $u->companies()->syncWithoutDetaching([$c->id => ['role'=>'admin']]);
```
- [ ] Login `/admin` with this user.
- [ ] Confirm **company switcher** shows the expected companies.
- [ ] Confirm **role matrix** (viewer/cashier/admin) applies in UI (menus/actions hidden/disabled accordingly).

---

## 3) Tenant Scoping Smoke Tests (UI)
- [ ] **Products**: Create product in Company A, ensure not visible in Company B.
- [ ] **Customers**: Create customer in A, switch to B → not visible.
- [ ] **Stock Movements**: Movements appear only for matching tenant.

---

## 4) Sale Order Workflow (UI)
1. Create **Draft** with items.
2. **Confirm** order → stock deducts (check Product stock & Stock Movements).
3. **Cash** payment path → mark as Received immediately.
4. **Transfer** path → upload slip → status Pending → **Admin Approve** → Received.
5. **Cancel** order: (if implemented) should **restore** stock—verify movement is correct.
- [ ] Reports dashboard reflects only **Confirmed + Received**.

---

## 5) Custom Fields (Dynamic)
- [ ] Add Product `brand` (select: A,B), `required=true` in **CustomFieldDef**.
- [ ] Create product **without** brand → should **fail** validation.
- [ ] Create product **with** brand → **pass**, field appears in form & table.
- [ ] (Optional) Run JSON index: `php artisan flex:cf-index PRODUCT brand`.

---

## 6) Files & Slips
- [ ] Upload sample slip (PNG/JPG/PDF ≤ configured size).  
- [ ] Confirm file stored at `storage/app/public/slips/{company}/{tx}/...` and preview works in UI.
- [ ] `php artisan storage:link` resolved public visibility.

---

## 7) Dashboard Widgets
- [ ] SalesToday: totals reflect today’s Confirmed+Received.
- [ ] TopProducts: contains correct top items (past 7/30 days).
- [ ] LowStock: shows items ≤ threshold; tune threshold in config or env.
- [ ] PaymentMix: percentages add up to 100% (cash vs transfer).

---

## 8) Security
- [ ] **Viewer** cannot create/modify/delete anywhere.
- [ ] **Cashier** can create SO, confirm, pay; **cannot approve** payments or edit custom fields.
- [ ] **Admin** full access incl. CustomFieldDef & approve payments.
- [ ] Rate limits applied to sensitive routes (login, write ops).

---

## 9) Performance & Ops
- [ ] Configure OPcache in PHP‑FPM (prod).
- [ ] Cache config/routes: `php artisan config:cache && php artisan route:cache`.
- [ ] Horizon/Queue (if using redis): supervisor service configured.
- [ ] DB backups: setup `spatie/laravel-backup` or cron `mysqldump` per tenant database or with company_id scoping.

---

## 10) Staging → Production Rollout
1. Tag release: `git tag vX.Y.Z && git push --tags`.
2. Deploy build: composer install (no‑dev), migrate `--force`.
3. Warm caches (config/route/view).
4. Verify `/admin` smoke tests end‑to‑end.
5. Enable monitoring (Sentry/Bugsnag), access logs for `/admin`.

---

## 11) Quick cURL API Sanity (Optional)
```bash
# Confirm reports use Confirmed+Received
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/demo-sme/reports/sales-daily | jq '.'

# Custom field creation
curl -s -X POST http://localhost:8000/api/demo-sme/admin/custom-fields \
 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
 -d '{"entity":"PRODUCT","key":"brand","label":"Brand","data_type":"select","options":["A","B"],"required":true}' | jq '.'
```

---

## 12) Acceptance Criteria (Go‑Live)
- [ ] Tenant isolation proven via panel.
- [ ] SO lifecycle works (deduct / slips / approval / reports).
- [ ] Custom fields enforce UI+API validation.
- [ ] RBAC matches role matrix; actions hidden appropriately.
- [ ] Files stored and readable via symlink.
- [ ] Dashboards accurate for a small dataset.
- [ ] Backups configured; error monitoring enabled.

---

### Notes
- If using **Caddy**: ensure `/admin` is routed to Laravel `public/index.php`, and `/storage` serves `public/storage`.
- For **DirectAdmin**: place built frontend (if any) at `public_html`, keep Laravel under e.g. `/api` or subdomain; Filament remains under backend host.
