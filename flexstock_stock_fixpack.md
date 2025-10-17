# FlexStock — **Stock System Fix Pack (Laravel 11)**
> **Role for Claude:** *Full‑stack senior developer at a world‑class IT company*  
> **Goal:** Diagnose & **make the stock system fully working in production terms**: correct inventory math, atomic updates, proper ledger, tenant isolation, validations, and end‑to‑end API flows (adjust → order → confirm → ledger → reports). Include tests and seed data.  
> **Project root:** `/home/aunji/ai-copilot-server/flexstock`

---

## How to use this file
Copy the **PROMPT FOR CLAUDE** block and run it with **Claude Code CLI**. Claude will create/fix files, run migrations, add tests, and commit in a new branch.

**Headless example (no confirmations):**
```bash
cd /home/aunji/ai-copilot-server/flexstock
claude -p "$(awk '/^BEGIN PROMPT FOR CLAUDE$/{flag=1;next}/^END PROMPT FOR CLAUDE$/{flag=0}flag' ../flexstock_stock_fixpack.md)" \
  --dangerously-skip-permissions --output-format json --model sonnet --max-turns 22
```

---

## BEGIN PROMPT FOR CLAUDE

You are a **full‑stack senior developer at a world‑class IT company**. Work non‑interactively, on my Ubuntu server, inside:

- **Repo:** `/home/aunji/ai-copilot-server/flexstock`
- **Stack:** Laravel 11 (PHP 8.3), MySQL 8, Redis, Sanctum, Docker
- **Tenancy:** URL slug `{company}` + global tenant scope
- **Current Issue:** The **stock system "does not work"** end‑to‑end. We need a **reliable production‑grade stock module**.

### Rules
- No confirmations. Use POSIX bash and idempotent steps.
- Create branch: `fix/stock-system-hardening`
- Make **clean, logical commits** (db, domain, api, tests, docs).
- Run `php artisan test` locally and ensure it passes before committing.
- If `gh` + `GH_TOKEN` exist, push and open PR to `main` with clear description.

---

## 1) Diagnose & Stabilize
1. Run quick health:
   ```bash
   php artisan --version || true
   php -v || true
   php artisan migrate --status || true
   ```
2. Audit existing **Models/Controllers/Services** for: `Product`, `StockMovement`, `SaleOrder`, `SaleOrderItem`.
3. Verify `attributes JSON` exists on entities and tenant scoping is consistent (company_id everywhere).
4. Add/adjust DB indexes for performance (company_id, product_id, created_at).

---

## 2) Database Constraints & Indexes
- Ensure **foreign keys** exist and **indexes** for:
  - `products(company_id, sku) UNIQUE`
  - `products(company_id, created_at)` INDEX
  - `stock_movements(company_id, product_id, created_at)` INDEX
  - `sale_orders(company_id, tx_id)` UNIQUE + INDEX on `(company_id, created_at)`
- If missing, create a migration `*_stock_fix_indexes.php` and add them safely (`IF NOT EXISTS` checks where applicable).

---

## 3) Inventory Service (Authoritative Logic)
Create/replace **`app/Services/InventoryService.php`** with atomic, lock‑based operations:

```php
<?php

namespace App\Services;

use App\Models\Product;
use App\Models\StockMovement;
use Illuminate\Support\Facades\DB;

class InventoryService
{
    /**
     * Adjust stock for a product (positive for incoming, negative for outgoing).
     * Atomic, tenant-safe, prevents negative balance.
     */
    public function adjust(string $companyId, int $productId, float $deltaQty, string $refType, ?string $refId = null, ?string $notes = null): array
    {
        return DB::transaction(function () use ($companyId, $productId, $deltaQty, $refType, $refId, $notes) {
            $product = Product::where('company_id', $companyId)
                ->where('id', $productId)
                ->lockForUpdate()
                ->firstOrFail();

            $newQty = (float)$product->stock_qty + (float)$deltaQty;
            if ($newQty < 0) {
                throw new \RuntimeException("Insufficient stock for product_id={$productId}");
            }

            $in = $deltaQty >= 0 ? $deltaQty : 0;
            $out = $deltaQty < 0 ? abs($deltaQty) : 0;

            $product->update(['stock_qty' => $newQty]);

            $movement = StockMovement::create([
                'company_id'    => $companyId,
                'product_id'    => $productId,
                'ref_type'      => $refType,     // SALE, PURCHASE, ADJUSTMENT, OPENING, RETURN
                'ref_id'        => $refId,
                'qty_in'        => $in,
                'qty_out'       => $out,
                'balance_after' => $newQty,
                'notes'         => $notes,
            ]);

            return [$movement, $product->fresh()];
        }, 3);
    }
}
```

> **Contract:** `adjust()` is the **single source of truth** for stock changes. **Do not** change `stock_qty` anywhere else.

---

## 4) Stock Controller & Routes
**File:** `app/Http/Controllers/StockController.php`  
Create (or fix) endpoints with validation and tenant scoping.

```php
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\InventoryService;
use App\Models\StockMovement;

class StockController extends Controller
{
    public function adjust(Request $req, string $company)
    {
        $data = $req->validate([
            'product_id' => 'required|integer|exists:products,id',
            'qty_delta'  => 'required|numeric|not_in:0',
            'ref_type'   => 'required|in:OPENING,PURCHASE,SALE,RETURN,ADJUSTMENT',
            'ref_id'     => 'nullable|string|max:191',
            'notes'      => 'nullable|string|max:1000',
        ]);

        $cid = app('currentCompany')->id;
        [$movement, $product] = app(InventoryService::class)->adjust(
            companyId: $cid,
            productId: (int)$data['product_id'],
            deltaQty: (float)$data['qty_delta'],
            refType: $data['ref_type'],
            refId: $data['ref_id'] ?? null,
            notes: $data['notes'] ?? null,
        );

        return response()->json([
            'movement' => $movement,
            'product'  => $product,
        ], 201);
    }

    public function movements(Request $req, string $company)
    {
        $cid = app('currentCompany')->id;
        $pid = (int)$req->query('product_id');

        $items = StockMovement::where('company_id', $cid)
            ->when($pid, fn($q) => $q->where('product_id', $pid))
            ->orderByDesc('created_at')
            ->paginate(25);

        return response()->json($items);
    }
}
```

**Routes:** add to `routes/api.php` inside tenant group
```php
Route::post('{company}/stock/adjust', [\App\Http\Controllers\StockController::class, 'adjust'])
    ->middleware(['tenant','auth:sanctum']);
Route::get('{company}/stock/movements', [\App\Http\Controllers\StockController::class, 'movements'])
    ->middleware(['tenant','auth:sanctum']);
```

---

## 5) Sale Order Flow (Deduct on Confirm)
Harden `SaleOrderService` to **deduct stock only when confirming** a Draft order, using `InventoryService::adjust()` in a DB transaction with row locks.

**File:** `app/Services/SaleOrderService.php` (patch the `confirm()` method)

```php
public function confirm(string $companyId, string $txId): \App\Models\SaleOrder
{
    return DB::transaction(function () use ($companyId, $txId) {
        $so = SaleOrder::where('company_id', $companyId)
            ->where('tx_id', $txId)
            ->lockForUpdate()
            ->with('items')
            ->firstOrFail();

        if ($so->status !== 'Draft') {
            throw new \RuntimeException('Only Draft can be confirmed.');
        }

        foreach ($so->items as $it) {
            app(\App\Services\InventoryService::class)->adjust(
                companyId: $companyId,
                productId: $it->product_id,
                deltaQty: -1 * (float)$it->qty,
                refType: 'SALE',
                refId: $so->tx_id,
                notes: 'SO Confirm'
            );
        }

        $so->update(['status' => 'Confirmed']);
        return $so->fresh(['items']);
    }, 3);
}
```

> Ensure `SaleOrder` has relation `items` and each item has `product_id`, `qty`, `unit_price`, `line_total` computed.

---

## 6) Validation Requests
Create/verify **Form Requests**:
- `ProductRequest` (sku, name, price, cost, attributes)
- `SaleOrderRequest` (customer_id, items array, payment_method)
- `StockAdjustRequest` (or inline rules as in controller)

Each should merge **CustomFieldRegistry** rules for `attributes.*` if module is present.

---

## 7) Feature Tests (must pass)
Create tests to guarantee correctness and prevent regressions.

**File:** `tests/Feature/StockFlowTest.php`
- **adjust_increase_creates_ledger_and_updates_balance**
- **prevent_negative_balance**
- **confirm_order_deducts_stock_and_writes_movements**
- **tenant_isolation_enforced** (cannot adjust product of another company)
- **concurrent_confirms_prevent_oversell** (simulate by parallel transactions if feasible; otherwise use lock expectations)

**File:** `tests/Feature/ApiContractTest.php`
- Smoke tests: login → list products → adjust → create SO → confirm → reports

Run tests:
```bash
php artisan test --without-tty
```

---

## 8) Seeders & Demo
- Ensure `DemoDataSeeder` creates 1 company (`demo-store` slug), 2 users (admin/cashier), 3 customers, 4 products with **non‑zero** stock via an OPENING adjustment through `InventoryService` (not direct `stock_qty` edit).
- Add artisan command `flex:demo-reset` to wipe and re‑seed quickly (optional).

---

## 9) Reports Consistency
- Reports must only count **Confirmed + Received** orders for sales KPIs.
- Add test to verify sales‑daily numbers match order confirmations created during tests.

---

## 10) Frontend touch‑ups (minimal)
- Ensure the **Products List** reads `stock_qty` and displays **Low stock** badge when `stock_qty <= 5` (configurable).
- Add error display for 422 from stock adjust or product create.
- Confirm **CORS** allows `http://localhost:5173` (backend `.env`).

---

## 11) Git Hygiene & PR
Commit plan:
1) `feat(db): add/ensure indexes & constraints for stock tables`
2) `feat(domain): InventoryService with atomic adjust()`
3) `feat(api): stock endpoints + validation`
4) `feat(so): confirm() deducts stock through InventoryService`
5) `test: add stock flow feature tests`
6) `chore(seed): demo data via service`
7) `docs: update README (stock flows & curl samples)`

If available:
```bash
git push -u origin fix/stock-system-hardening
gh pr create --fill --title "fix(stock): harden stock system (atomic adjust, ledger, confirm flow)" \
  --body "Stabilizes inventory math, adds tests, and ensures tenant isolation."
```

---

## 12) Smoke Test (cURL)
Assume token in `$TOKEN`, company `demo-store`.
```bash
# Products
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/demo-store/products | jq '.|length'

# Adjust +10 to product 1
curl -s -X POST http://localhost:8080/api/demo-store/stock/adjust \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"product_id":1,"qty_delta":10,"ref_type":"OPENING","notes":"init"}' | jq '.'

# Create SO (1 item of product 1, qty 2)
curl -s -X POST http://localhost:8080/api/demo-store/sale-orders \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"customer_id":1,"payment_method":"transfer","items":[{"product_id":1,"qty":2,"unit_price":120}]}' | jq '.'

# Confirm SO (deduct stock)
TX="SO-xxxx..." # set from response
curl -s -X POST http://localhost:8080/api/demo-store/sale-orders/$TX/confirm \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# Movements for product 1
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:8080/api/demo-store/stock/movements?product_id=1" | jq '.'
```

**Acceptance:** All tests pass, curl flow works, stock ledger shows correct balances.

## END PROMPT FOR CLAUDE