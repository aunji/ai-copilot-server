
# FlexStock — **Phase 2 Full System Implementation (Laravel Multi‑Tenant)**
> **Role for Claude:** *Full‑stack senior developer at a world‑class IT company*  
> **Repo Root:** `/home/aunji/flexstock` (adjust if different)  
> **Stack:** Laravel 10 (PHP 8.1), MySQL 8, Redis, Sanctum, Docker/Caddy  
> **Baseline:** Phase 1 completed (InventoryService atomic, Stock API, Document Numbering, DB hardening, PaymentSlip infra).  
> **Goal (Phase 2):** Complete the **production‑ready** system: **Custom Field dynamic validation**, **Payment Slip approval**, **Reports consistency**, **Security (RBAC + throttle + CORS)**, **Seeder update**, **Feature tests**, **CI/CD**, and **Docs**.

---

## How to use
1) Copy the **PROMPT FOR CLAUDE** block below.  
2) Run with **Claude Code CLI** in headless mode (no confirmations):  
```bash
cd /home/aunji/flexstock
claude -p "$(awk '/^BEGIN PROMPT FOR CLAUDE$/{flag=1;next}/^END PROMPT FOR CLAUDE$/{flag=0}flag' ../flexstock_phase2_fullsystem.md)" \
  --dangerously-skip-permissions --output-format json --model sonnet --max-turns 28
```
3) Claude will create a branch, implement tasks, run tests, and (optionally) open a PR.

---

## BEGIN PROMPT FOR CLAUDE

You are a **full‑stack senior developer at a world‑class IT company**. Work **non‑interactively** in this repo:

- **Repo:** `/home/aunji/flexstock`
- **Stack:** Laravel 10 (PHP 8.1), MySQL 8, Redis, Sanctum, Docker/Caddy
- **Tenancy:** `/api/{company}/...` + tenant global scope
- **Phase 1 is done:** InventoryService (atomic adjust), StockController, DocumentNumbering, DB hardening, PaymentSlip infra, SaleOrderService integrated with InventoryService.

### Rules
- Do **not** ask for confirmations. Use POSIX bash; make idempotent changes.
- Create a new branch: `feature/phase2-fullsystem`
- Make clean commits in this order: **db → domain → api → security → tests → ci → docs**.
- Run `php artisan test` and ensure it passes before committing.
- If `gh` + `GH_TOKEN` exist, push and open PR to `main` with a clear title & body.

---

## 1) CustomFieldRegistry — Dynamic Validation + Admin CRUD
**Context:** Table `custom_field_defs` already exists. Entities `Product`, `Customer`, `SaleOrder`, `SaleOrderItem` have `attributes` (JSON).

### Tasks
1. Add **service** `app/Services/CustomFieldRegistry.php` that converts definitions → Laravel Validator rules. Types: `text, number, boolean, date, select, multiselect`. Respect `required`, `options`, `validation_regex`.
2. **Form Requests:** Merge dynamic rules:
   - `ProductRequest` → entity `PRODUCT`
   - `CustomerRequest` → entity `CUSTOMER`
   - `SaleOrderRequest` → entity `SALE_ORDER`
   - `SaleOrderItemRequest` → entity `SALE_ORDER_ITEM`
3. **Admin API CRUD** for custom fields (tenant‑scoped):
   - `GET /api/{company}/admin/custom-fields`
   - `POST /api/{company}/admin/custom-fields`
   - `PATCH /api/{company}/admin/custom-fields/{id}`
   - `DELETE /api/{company}/admin/custom-fields/{id}`
4. **Optional performance:** Artisan command `php artisan flex:cf-index {entity} {key}` creates a MySQL **JSON expression index** on `attributes->{key}` for the target table.

**Commits**
- `feat(custom-fields): registry + dynamic validation`
- `feat(admin): custom fields CRUD endpoints`
- `feat(cli): cf-index command for JSON index`

---

## 2) Payment Slip Approval — Transfer vs Cash
**Context:** There is `payment_slips` table and `PaymentSlip` model (from Phase 1).

### Tasks
1. Extend `sale_orders` if needed: columns `payment_state` (`PendingReceipt`/`Received`), `payment_method` (`cash`/`transfer`), `payment_notes`, `approved_by` (FK users), `approved_at` (datetime), `slip_path` (nullable string). Safe migration only if not present.
2. Endpoints (tenant‑scoped, auth required):
   - `POST /api/{company}/sale-orders/{tx}/pay`  
     Body: `{ "payment_method": "cash" | "transfer", "payment_notes": "...", "slip": <file?> }`  
     - If `"cash"` → set `payment_state=Received` immediately, capture `received_at`.
     - If `"transfer"` → create `PaymentSlip` and set `payment_state=PendingReceipt` with `slip_path`, awaiting approval.
   - `POST /api/{company}/sale-orders/{tx}/approve-payment` (admin only)  
     - Set `payment_state=Received`, persist `approved_by`, `approved_at`.
3. Store files at `storage/app/public/slips/{company}/{tx}/...` and ensure `php artisan storage:link` is valid.
4. Update `ReportService` to count only **Confirmed + Received** orders.

**Commits**
- `feat(payment): pay & approve endpoints with slip upload`
- `fix(reports): count Confirmed+Received only`

---

## 3) Reports Consistency + Analytics
### Tasks
1. Verify endpoints:
   - `/reports/sales-daily` (date filter; only Confirmed+Received)
   - `/reports/top-products`
   - `/reports/low-stock` (`threshold` param default 5)
   - `/reports/payment-mix`
2. Add appropriate indexes on `sale_orders(status,payment_state,created_at)` as needed.

**Commit**
- `fix(reports): consistency & indexes for analytics`

---

## 4) Security Layer — RBAC, Throttling, CORS
### Tasks
1. **Policies/Abilities**: Ensure write actions require role `admin` or `cashier` for the current company; certain admin endpoints (e.g., approve payment, custom fields) require `admin`.
2. **Rate Limit:** Apply throttle middleware to login and write endpoints (e.g., stock adjust, SO confirm, payment endpoints).
3. **CORS:** Tighten allowed origins from `.env` (e.g., `CORS_ALLOWED_ORIGINS`). Ensure local dev + prod domain supported.

**Commit**
- `feat(security): policies + throttle + cors hardening`

---

## 5) Seeder Update — Use InventoryService
### Tasks
1. In `DemoSeeder`, create initial stock using `InventoryService::adjust(..., 'OPENING')` (not direct column edit).
2. Optionally seed one confirmed order (with Received payment) to validate reports.

**Commit**
- `chore(seed): demo via InventoryService + sample confirmed order`

---

## 6) Feature Tests (must pass)
Create `tests/Feature/Phase2SystemTest.php` with these tests:
1. **test_custom_fields_dynamic_validation**  
   - Define `PRODUCT.brand` (required, select `[A,B]`)  
   - Create product **fails** without `attributes.brand` (422)  
   - Create product **passes** with valid brand
2. **test_payment_transfer_and_admin_approve**  
   - Create SO (transfer) → `pay` (upload slip) → `approve-payment` → state becomes `Received`
3. **test_reports_include_only_confirmed_and_received**  
   - Create multiple orders with different states; verify daily sales reflects only Confirmed+Received
4. **test_rbac_enforced_for_admin_endpoints**  
   - Cashier cannot approve payment or manage custom fields; admin can
5. **test_tenant_isolation**  
   - User from company A cannot access/modify company B resources
6. **test_opening_stock_via_service**  
   - Seeder or service can set opening stock and produce ledger entries

Mock filesystem for slip uploads. Use factories; wrap DB in transactions where appropriate.

**Commit**
- `test: phase 2 feature tests`

---

## 7) CI/CD — GitHub Actions
Create/update `.github/workflows/ci.yml`:
- Setup PHP 8.1
- `composer install --no-interaction --prefer-dist`
- `php artisan key:generate`
- Use SQLite memory or tmp sqlite for `php artisan test`
- (optional) `phpcs` step if available
- Cache composer deps

**Commit**
- `ci: add github actions for phpunit`

---

## 8) Docs — README & QUICKSTART
Update both to include:
- Custom Fields (admin CRUD + validation + optional `flex:cf-index`)
- Payment Slip workflow (pay/approve endpoints, file upload)
- Reports filters and samples
- Security notes (roles, throttle, CORS)
- Seeder behavior (opening stock)
- cURL samples and troubleshooting

**Commit**
- `docs: update readme & quickstart for phase 2`

---

## 9) Open PR
If available:
```bash
git push -u origin feature/phase2-fullsystem
gh pr create --fill --title "feat: Phase 2 — custom fields, payment approval, reports consistency, security, tests & CI" \
  --body "Completes production features: dynamic custom fields, payment slip approval, report consistency, RBAC/throttle/CORS, seeder via InventoryService, feature tests, CI, and docs."
```

---

## Smoke Tests (cURL)
Assume `$TOKEN` and tenant `demo-sme`.

```bash
# Custom Field (Product.brand required)
curl -s -X POST http://localhost:8000/api/demo-sme/admin/custom-fields \
 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
 -d '{"entity":"PRODUCT","key":"brand","label":"Brand","data_type":"select","options":["A","B"],"required":true}' | jq '.'

# Create product without brand → 422
curl -s -X POST http://localhost:8000/api/demo-sme/products \
 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
 -d '{"sku":"USB-C-2M","name":"USB-C 2m","price":150,"attributes":{}}' | jq '.'

# Create product with brand → 201
curl -s -X POST http://localhost:8000/api/demo-sme/products \
 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
 -d '{"sku":"USB-C-2M","name":"USB-C 2m","price":150,"attributes":{"brand":"A"}}' | jq '.'

# Pay by transfer (upload slip)
curl -s -X POST http://localhost:8000/api/demo-sme/sale-orders/SO-202510-0001/pay \
 -H "Authorization: Bearer $TOKEN" \
 -F "payment_method=transfer" \
 -F "payment_notes=Kasikorn transfer" \
 -F "slip=@/path/to/slip.png" | jq '.'

# Approve payment (admin only)
curl -s -X POST http://localhost:8000/api/demo-sme/sale-orders/SO-202510-0001/approve-payment \
 -H "Authorization: Bearer $TOKEN" | jq '.'

# Reports daily
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/demo-sme/reports/sales-daily | jq '.'

# Optional: create JSON index for attributes.brand
docker compose exec app php artisan flex:cf-index PRODUCT brand
```

## Acceptance Criteria
- Dynamic custom fields validate on create/update for all entities.  
- Payment slip flow works (`transfer` → upload → approve → `Received`; `cash` → immediate `Received`).  
- Reports include only Confirmed + Received orders.  
- RBAC enforced; admin/cashier separation; tenant isolation guaranteed.  
- Seeders use InventoryService for opening stock.  
- Feature tests pass locally and in CI; PR opened with clean commit history.

## END PROMPT FOR CLAUDE
