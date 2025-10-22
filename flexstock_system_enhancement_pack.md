
# FlexStock — **System Enhancement Pack (Laravel Multi‑Tenant)**
> **Role for Claude:** *Full‑stack senior developer at a world‑class IT company*  
> **Repo Root:** `/home/aunji/flexstock/` (adjust if different)  
> **Goal:** Fix & harden **stock** end‑to‑end, add **Custom Fields (admin‑driven)**, implement **Payment slip approval**, **Document numbering (per‑tenant)**, strengthen **reports/security/tests/CI**, and make the system **production‑ready**.

---

## How to use
1) Copy the **PROMPT FOR CLAUDE** block below.  
2) Run with **Claude Code CLI** in headless mode (no confirmations):  
```bash
cd /home/aunji/flexstock
claude -p "$(awk '/^BEGIN PROMPT FOR CLAUDE$/{flag=1;next}/^END PROMPT FOR CLAUDE$/{flag=0}flag' ../flexstock_system_enhancement_pack.md)" \
  --dangerously-skip-permissions --output-format json --model sonnet --max-turns 28
```
3) Claude will create a branch, modify files, run tests, and (optionally) open a PR.

---

## BEGIN PROMPT FOR CLAUDE
You are a **full‑stack senior developer at a world‑class IT company**.  
Work non‑interactively on my Ubuntu server inside this repo:

- **Repo:** `/home/aunji/flexstock`  
- **Stack:** Laravel 10 (PHP 8.1), MySQL 8, Redis, Sanctum, Docker/Caddy  
- **Tenancy:** route `/api/{company}/...` + tenant global scope  
- **Baseline:** Multi‑tenant app with products, customers, stock_movements ledger, sale_orders, reports, custom_field_defs.  
- **Problem:** Stock flow needs to **work reliably in production**, plus we need **custom fields full module**, **payment slip approval**, and **document numbering**. Add **tests/CI** to ensure quality.

### Rules
- Do **not** ask for confirmations. Use idempotent changes.  
- Create a branch: `feature/system-fix-enhancement`  
- Make clean commits: db → domain → api → tests → docs → ci.  
- Run `php artisan test` locally and ensure it passes before committing.  
- If `gh` + `GH_TOKEN` exist, push and open PR to `main` with a clear title & body.

---

## 1) Database Hardening (Indexes + FKs)
Create migration `database/migrations/*_system_fix_indexes.php` that **adds (if missing)**:
```php
// products
$table->unique(['company_id','sku']); 
$table->index(['company_id','created_at']);
// stock_movements
$table->index(['company_id','product_id','created_at']);
// sale_orders
$table->unique(['company_id','tx_id']);
$table->index(['company_id','created_at']);
// customers (phone unique per company)
$table->unique(['company_id','phone']);
```
Add/ensure FKs: stock_movements.product_id → products.id; sale_order_items.sale_order_id → sale_orders.id; sale_order_items.product_id → products.id; etc.

**Commit:** `feat(db): add/ensure core indexes & foreign keys`

---

## 2) Inventory Service — Single Source of Truth
Create/replace `app/Services/InventoryService.php` with **atomic adjust** (row‑lock, never let negative) and append‑only ledger write:
```php
<?php
namespace App\Services;

use App\Models\Product;
use App\Models\StockMovement;
use Illuminate\Support\Facades\DB;

class InventoryService {
  public function adjust(string $companyId, int $productId, float $deltaQty, string $refType, ?string $refId=null, ?string $notes=null): array {
    return DB::transaction(function() use($companyId,$productId,$deltaQty,$refType,$refId,$notes){
      $p = Product::where('company_id',$companyId)->where('id',$productId)->lockForUpdate()->firstOrFail();
      $new = (float)$p->stock_qty + (float)$deltaQty;
      if ($new < 0) throw new \RuntimeException('Insufficient stock');
      $in  = $deltaQty >= 0 ? $deltaQty : 0;
      $out = $deltaQty < 0  ? -$deltaQty : 0;
      $p->update(['stock_qty'=>$new]);
      $m = StockMovement::create([
        'company_id'=>$companyId,'product_id'=>$productId,
        'ref_type'=>$refType,'ref_id'=>$refId,
        'qty_in'=>$in,'qty_out'=>$out,'balance_after'=>$new,'notes'=>$notes,
      ]);
      return [$m,$p->fresh()];
    }, 3);
  }
}
```
**Contract:** All stock changes go **only** through `InventoryService::adjust()`.

**Commit:** `feat(domain): InventoryService atomic adjust with ledger`

---

## 3) Stock API — Adjust & Movements
Create/fix `app/Http/Controllers/StockController.php`:
```php
public function adjust(Request $r, string $company) {
  $v = $r->validate([
    'product_id'=>'required|integer|exists:products,id',
    'qty_delta'=>'required|numeric|not_in:0',
    'ref_type'=>'required|in:OPENING,PURCHASE,SALE,RETURN,ADJUSTMENT',
    'ref_id'=>'nullable|string|max:191','notes'=>'nullable|string|max:1000',
  ]);
  $cid = app('currentCompany')->id;
  [$mov,$prod] = app(\App\Services\InventoryService::class)->adjust($cid,(int)$v['product_id'],(float)$v['qty_delta'],$v['ref_type'],$v['ref_id']??null,$v['notes']??null);
  return response()->json(['movement'=>$mov,'product'=>$prod],201);
}
public function movements(Request $r, string $company) {
  $cid = app('currentCompany')->id; $pid = (int)$r->query('product_id');
  $q = \App\Models\StockMovement::where('company_id',$cid);
  if ($pid) $q->where('product_id',$pid);
  return $q->orderByDesc('created_at')->paginate(25);
}
```
Add routes in `routes/api.php` inside the tenant group:
```php
Route::post('{company}/stock/adjust', [StockController::class,'adjust'])->middleware(['tenant','auth:sanctum']);
Route::get('{company}/stock/movements', [StockController::class,'movements'])->middleware(['tenant','auth:sanctum']);
```
**Commit:** `feat(api): stock adjust & movements endpoints`

---

## 4) Sale Orders — Deduct On Confirm
Patch `app/Services/SaleOrderService.php` confirm flow to **deduct stock** via InventoryService:
```php
public function confirm(string $companyId, string $txId): SaleOrder {
  return DB::transaction(function() use($companyId,$txId){
    $so = SaleOrder::where('company_id',$companyId)->where('tx_id',$txId)->lockForUpdate()->with('items')->firstOrFail();
    if ($so->status!=='Draft') throw new \RuntimeException('Only Draft can be confirmed');
    foreach($so->items as $it){
      app(\App\Services\InventoryService::class)->adjust($companyId,$it->product_id,-1*(float)$it->qty,'SALE',$so->tx_id,'SO Confirm');
    }
    $so->update(['status'=>'Confirmed']);
    return $so->fresh(['items']);
  },3);
}
```
**Commit:** `feat(so): confirm flow deducts stock via InventoryService`

---

## 5) Custom Fields — Full Admin Module
We already have `custom_field_defs`. Implement:
- `app/Http/Controllers/Admin/CustomFieldController.php`: index/store/update/destroy (tenant‑scoped)
- `app/Services/CustomFieldRegistry.php`: build dynamic Laravel rules from definitions
- Merge rules into **Form Requests** (Product/Customer/SaleOrder/SaleOrderItem) by calling `CustomFieldRegistry->rules($companyId, ENTITY)`
- **Optional**: Artisan command `php artisan flex:cf-index {entity} {key}` creates JSON expression index for `attributes->{key}`.

**Commit:** `feat(custom-fields): admin CRUD + dynamic validation (+ optional index cmd)`

---

## 6) Payment Slip Approval
- Extend `sale_orders` with columns if missing: `payment_state` (`PendingReceipt`/`Received`), `payment_method` (`cash`/`transfer`), `slip_path` nullable, `approved_by` nullable FK users, `approved_at` datetime.
- Controller endpoints:
  - `POST /{company}/sale-orders/{tx}/pay` (accepts `payment_method`, optional `slip` upload) → set `PendingReceipt` for transfer or `Received` for cash.
  - `POST /{company}/sale-orders/{tx}/approve-payment` (admin only) → sets `Received`, stores `approved_by/approved_at`.
- Store files in `storage/app/public/slips/{company}/{tx}/`. Ensure `php artisan storage:link` exists.

**Commit:** `feat(payment): transfer slip upload + approve flow`

---

## 7) Document Numbering (Per Tenant)
Create table `document_counters`:
```php
company_id (uuid), doc_type (string), period (string, e.g. YYYYMM), next_seq (int)
PRIMARY KEY (company_id, doc_type, period)
```
Service `app/Services/DocumentNumberService.php`:
```php
public function next(string $companyId, string $docType, ?Carbon $at=null): string {
  // inside transaction + lock row
  // format: SO-YYYYMM-#### (zero-padded)
}
```
Use in `SaleOrderService::createDraft()` to generate `tx_id` like `SO-202510-0001` per company per month.

**Commit:** `feat(docs): per-tenant document numbering service`

---

## 8) Reports — Consistency
- Sales metrics count **only Confirmed + Received**.
- Add indexes if needed on status/payment_state.
- Verify endpoints: daily sales, top products, low stock, payment mix.

**Commit:** `fix(reports): ensure correct filters + indexes`

---

## 9) Policies, Rate Limit, CORS
- Ensure every write endpoint checks user is member of `currentCompany` and role is allowed (admin/cashier).
- Add rate limit on auth/login & stock/order writes (via throttle middleware).
- Confirm CORS allows local dev and prod domains.

**Commit:** `feat(security): policies + throttling + cors tuning`

---

## 10) Seeders
- Ensure `DemoSeeder` creates: company `demo-sme`, users (admin/cashier), 3 customers, 4 products.
- Set initial stock via `InventoryService::adjust(..., 'OPENING')` rather than direct column edit.
- (Optional) Add a sale order & confirm it to populate reports.

**Commit:** `chore(seed): demo via InventoryService OPENING`

---

## 11) Tests (must pass)
Create `tests/Feature/SystemFlowTest.php` with:
- **test_adjust_increases_stock_and_writes_ledger**  
- **test_prevent_negative_balance_on_adjust**  
- **test_confirm_order_deducts_stock_and_writes_movements**  
- **test_payment_transfer_then_admin_approve**  
- **test_reports_daily_include_confirmed_received_only**  
- **test_tenant_isolation_prevents_cross_company_access**  

Use factories/seeders and transactions. Mock storage for slip upload tests.

**Commit:** `test: system flow & isolation tests`

---

## 12) CI (GitHub Actions)
Create `.github/workflows/ci.yml`:
- PHP 8.1, composer install, run `php artisan test`
- (optional) Lint with `phpcs` if present

**Commit:** `ci: add github actions for phpunit`

---

## 13) Docs & Quickstart
Update `README.md` & `QUICKSTART.md`:
- Stock flow (adjust → order → confirm → ledger → reports)
- Custom fields usage + `flex:cf-index`
- Payment slip upload/approve API examples
- Document numbering format
- cURL samples
- Troubleshooting (CORS, 401, storage link)

**Commit:** `docs: update readme & quickstart for new flows`

---

## 14) Open PR
If `gh` is available and `GH_TOKEN` is set:
```bash
git push -u origin feature/system-fix-enhancement
gh pr create --fill --title "feat: system enhancement (stock hardening, custom fields, payments, doc numbering)" \
  --body "Hardened inventory; added admin custom fields with dynamic validation; implemented payment slip approval; per-tenant document numbering; updated reports/policies/seeders; added tests & CI."
```

---

## Smoke Tests (cURL)
Assume `$TOKEN` and tenant `demo-sme`:
```bash
# 1) Adjust opening
curl -s -X POST http://localhost:8000/api/demo-sme/stock/adjust \
 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
 -d '{"product_id":1,"qty_delta":10,"ref_type":"OPENING","notes":"init"}' | jq '.'

# 2) Create SO (qty 2)
SO=$(curl -s -X POST http://localhost:8000/api/demo-sme/sale-orders \
 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
 -d '{"customer_id":1,"payment_method":"transfer","items":[{"product_id":1,"qty":2,"unit_price":120}]}' | jq -r '.tx_id // .data.tx_id')

# 3) Confirm SO (deduct)
curl -s -X POST http://localhost:8000/api/demo-sme/sale-orders/$SO/confirm \
 -H "Authorization: Bearer $TOKEN" | jq '.'

# 4) Approve payment (transfer)
curl -s -X POST http://localhost:8000/api/demo-sme/sale-orders/$SO/approve-payment \
 -H "Authorization: BearTOKEN" | jq '.'

# 5) Check movements
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:8000/api/demo-sme/stock/movements?product_id=1" | jq '.'
```

## Acceptance Criteria
- Stock adjustments are atomic; negative balances prevented.  
- SO confirmation deducts stock via service; ledger consistent.  
- Admin custom fields usable end‑to‑end with dynamic validation.  
- Payment slip flow works (`transfer` → approve → `Received`).  
- Document numbering per tenant/month (`SO‑YYYYMM‑####`).  
- Reports reflect only Confirmed + Received.  
- Tests pass locally and in CI; clean PR created.

## END PROMPT FOR CLAUDE
