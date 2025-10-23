
# FlexStock — **Phase 2 ALL‑IN‑ONE (Full System + Optional Enhancements)**
> **Role for Claude:** *Full‑stack senior developer at a world‑class IT company*  
> **Repo Root:** `/home/aunji/flexstock` (adjust if different)  
> **Stack:** Laravel 10 (PHP 8.1), MySQL 8, Redis, Sanctum, Docker/Caddy  
> **Baseline:** Phase 1 completed (InventoryService atomic, Stock API, Document Numbering, DB hardening, PaymentSlip infra).  
> **Goal (Phase 2 All‑in‑One):** Finish a **production‑ready** system with: **Custom Fields dynamic validation + Admin CRUD**, **Payment Slip approval flow**, **Reports consistency**, **Security (RBAC + throttle + CORS)**, **Seeder update**, **Feature tests**, **CI/CD**, **Docs**, **AND** optional enhancements (Policies wiring, Rate limiting profiles, Reports filtering & indexes).

---

## How to run (headless)
```bash
cd /home/aunji/flexstock
claude -p "$(awk '/^BEGIN PROMPT FOR CLAUDE$/{flag=1;next}/^END PROMPT FOR CLAUDE$/{flag=0}flag' ../flexstock_phase2_all_in_one.md)" \
  --dangerously-skip-permissions --output-format json --model sonnet --max-turns 36
```

---

## BEGIN PROMPT FOR CLAUDE

You are a **full‑stack senior developer at a world‑class IT company**. Work **non‑interactively** in:

- **Repo:** `/home/aunji/flexstock`
- **Stack:** Laravel 10 (PHP 8.1), MySQL 8, Redis, Sanctum, Docker/Caddy
- **Tenancy:** `/api/{company}/...` + tenant global scope
- **Phase 1 done:** InventoryService (atomic adjust), StockController, DocumentNumbering, DB hardening, PaymentSlip infra, SaleOrderService integrated.

### Rules
- No confirmations. POSIX bash; idempotent changes.
- Branch: `feature/phase2-all-in-one`
- Commit order: **db → domain → api → security → tests → ci → docs** (logical, small commits).
- Run `php artisan test` before committing each major step.
- If `gh` + `GH_TOKEN` exist, push & open a PR to `main` with a clear body.

---

## A) Custom Fields — Dynamic Validation + Admin CRUD
**Context:** `custom_field_defs` exists; entities have `attributes` (JSON).

**Tasks**
1) Service `app/Services/CustomFieldRegistry.php`: map defs → Laravel rules (types: `text, number, boolean, date, select, multiselect`; support `required`, `options`, `validation_regex`).  
2) Form Requests merge dynamic rules:
   - `ProductRequest` → `PRODUCT`
   - `CustomerRequest` → `CUSTOMER`
   - `SaleOrderRequest` → `SALE_ORDER`
   - `SaleOrderItemRequest` → `SALE_ORDER_ITEM`
3) Admin CRUD (tenant‑scoped):
   - `GET /api/{company}/admin/custom-fields`
   - `POST /api/{company}/admin/custom-fields`
   - `PATCH /api/{company}/admin/custom-fields/{id}`
   - `DELETE /api/{company}/admin/custom-fields/{id}`
4) **Optional perf**: Artisan `php artisan flex:cf-index {entity} {key}` → MySQL JSON expression index `attributes->{key}`.

**Commits**
- `feat(custom-fields): registry + dynamic validation`
- `feat(admin): custom fields CRUD endpoints`
- `feat(cli): cf-index command for JSON index`

---

## B) Payments — Slip Upload & Approval
**Tasks**
1) Safe migration (if missing) on `sale_orders`:
   - `payment_state` (`PendingReceipt`/`Received`), `payment_method` (`cash`/`transfer`), `payment_notes`, `approved_by` FK users, `approved_at` datetime, `slip_path` string nullable
2) Endpoints (tenant, auth):
   - `POST /api/{company}/sale-orders/{tx}/pay`  
     If `cash` → set `payment_state=Received` immediately; if `transfer` → create PaymentSlip + `PendingReceipt` with `slip_path`
   - `POST /api/{company}/sale-orders/{tx}/approve-payment` (admin only) → set `Received`, `approved_by/approved_at`
3) Store slips to `storage/app/public/slips/{company}/{tx}/...` (ensure `php artisan storage:link`)

**Commit**
- `feat(payment): pay & approve endpoints + storage`

---

## C) Reports — Consistency & Analytics
**Tasks**
- Count **only** `status='Confirmed' AND payment_state='Received'` for sales KPIs.  
- Update endpoints: `/reports/sales-daily`, `/reports/top-products`, `/reports/low-stock?threshold=5`, `/reports/payment-mix`.  
- Add index if missing: `sale_orders(company_id, status, payment_state, created_at)`.

**Commit**
- `fix(reports): ensure Confirmed+Received; add helpful indexes`

---

## D) Security — Policies (RBAC), Throttle, CORS
**Tasks**
1) Policies / Gates per company (role in pivot company_user):
   - `company.view`: admin/cashier/viewer
   - `company.write`: admin/cashier
   - `company.admin`: admin
   Apply in controllers:
   - **Admin only**: custom fields, approve-payment, destructive ops
   - **Write**: stock adjust, confirm order, pay
2) Throttle profiles in `RouteServiceProvider`:
   - `auth` → 10/min by IP
   - `api-write` → 60/min by user.id or IP
3) Apply middleware to routes: `throttle:auth` on /auth/login; `throttle:api-write` on write routes.  
4) CORS via `.env` (`CORS_ALLOWED_ORIGINS`), include local and prod domains.

**Commit**
- `feat(security): RBAC policies + throttling + CORS hardening`

---

## E) Seeders — via InventoryService
**Tasks**
- `DemoSeeder`: opening stock using `InventoryService::adjust(..., 'OPENING')` (no direct column write).  
- Optionally seed 1 confirmed + received order to validate reports.

**Commit**
- `chore(seed): demo via InventoryService + sample confirmed order`

---

## F) Feature Tests — Must Pass
Create `tests/Feature/Phase2AllInOneTest.php`:
1. **custom_fields_dynamic_validation**: define PRODUCT.brand (required, select [A,B]) → product without brand 422, with brand 201.  
2. **payment_transfer_then_admin_approve**: SO transfer → pay (upload slip) → approve → `Received`.  
3. **reports_confirmed_received_only**: Only confirmed+received included.  
4. **rbac_enforcement**: cashier forbidden for custom fields/approve; admin allowed.  
5. **tenant_isolation**: cannot access cross‑company resources.  
6. **opening_stock_via_service**: seeder/service writes ledger on OPENING.

Mock filesystem for slip uploads; use factories; wrap in DB transactions.

**Commit**
- `test: phase 2 all‑in‑one feature tests`

---

## G) CI/CD — GitHub Actions
**Tasks**
- `.github/workflows/ci.yml`: PHP 8.1, composer install, `php artisan key:generate`, sqlite memory for `php artisan test`.  
- (optional) `phpcs` if available; cache composer.

**Commit**
- `ci: add github actions for phpunit`

---

## H) Docs — README & QUICKSTART
**Tasks**
- Document: Custom fields admin endpoints; dynamic validation; `flex:cf-index` usage.  
- Payment flow (pay/approve), slip upload examples.  
- Reports behaviour; Security notes (RBAC/throttle/CORS).  
- Seeder behaviour; Troubleshooting (CORS/401/storage link).  
- cURL samples.

**Commit**
- `docs: update readme & quickstart (phase 2 all‑in‑one)`

---

## Open PR
```bash
git push -u origin feature/phase2-all-in-one
gh pr create --fill --title "feat: Phase 2 ALL‑IN‑ONE — custom fields, payments, reports, security, tests & CI" \
  --body "Completes production features: dynamic custom fields, payment slip approval, Confirmed+Received reports, RBAC/throttle/CORS, seeder via InventoryService, feature tests, CI, and docs."
```

---

## Smoke Tests (cURL)
Assume `$TOKEN` & tenant `demo-sme`.

```bash
# Custom Fields
curl -s -X POST http://localhost:8000/api/demo-sme/admin/custom-fields \
 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
 -d '{"entity":"PRODUCT","key":"brand","label":"Brand","data_type":"select","options":["A","B"],"required":true}' | jq '.'

# Product without brand → 422
curl -s -X POST http://localhost:8000/api/demo-sme/products \
 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
 -d '{"sku":"USB-C-2M","name":"USB-C 2m","price":150,"attributes":{}}' | jq '.'

# Product with brand → 201
curl -s -X POST http://localhost:8000/api/demo-sme/products \
 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
 -d '{"sku":"USB-C-2M","name":"USB-C 2m","price":150,"attributes":{"brand":"A"}}' | jq '.'

# Payment (transfer)
curl -s -X POST http://localhost:8000/api/demo-sme/sale-orders/SO-202510-0001/pay \
 -H "Authorization: Bearer $TOKEN" \
 -F "payment_method=transfer" \
 -F "payment_notes=Kasikorn transfer" \
 -F "slip=@/path/to/slip.png" | jq '.'

# Approve payment (admin)
curl -s -X POST http://localhost:8000/api/demo-sme/sale-orders/SO-202510-0001/approve-payment \
 -H "Authorization: Bearer $TOKEN" | jq '.'

# Reports
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/demo-sme/reports/sales-daily | jq '.'

# Optional: JSON index for attributes.brand
docker compose exec app php artisan flex:cf-index PRODUCT brand
```

## Acceptance Criteria
- Dynamic custom fields validate on create/update for all entities.  
- Payment slip flow solid (transfer upload→approve→Received; cash→immediate Received).  
- Reports include only Confirmed + Received.  
- RBAC enforced; tenant isolation guaranteed; throttle active.  
- Seeders via InventoryService; tests pass; CI green; PR ready.

## END PROMPT FOR CLAUDE
