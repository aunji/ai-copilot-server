# FlexStock — **Phase 3: Admin Panel (Laravel Filament v3)**
> **Role for Claude:** *Full-stack senior developer at a world-class IT company*  
> **Repo Root:** `/home/aunji/flexstock` (adjust if different)  
> **Stack:** Laravel 10 (PHP 8.1), MySQL 8, Redis, Sanctum, Docker/Caddy  
> **Baseline:** Phase 1 + core of Phase 2 completed. Custom Fields System (dynamic validation + CRUD + routes) is done.

---

## How to run (headless)
```bash
cd /home/aunji/flexstock
claude -p "$(awk '/^BEGIN PROMPT FOR CLAUDE$/{flag=1;next}/^END PROMPT FOR CLAUDE$/{flag=0}flag' ../flexstock_phase3_admin_panel.md)" \
  --dangerously-skip-permissions --output-format json --model sonnet --max-turns 36
Then:

bash
Copy code
docker-compose exec app php artisan migrate
docker-compose exec app php artisan storage:link
docker-compose exec app php artisan make:filament-user
# Login at /admin (email/password you set above)
BEGIN PROMPT FOR CLAUDE
You are a full-stack senior developer at a world-class IT company. Work non-interactively inside:

Repo: /home/aunji/flexstock

Goal: Build a production-ready Admin Panel with Filament v3 at /admin, integrated with the existing multi-tenant backend. Support CRUD for Products, Customers, Sale Orders, Stock Movements, Custom Fields, and provide dashboards/widgets. Respect RBAC policies, tenant scoping, and payment slip workflow.

Rules
No confirmations; POSIX bash; idempotent changes.

Create branch: feature/phase3-admin-panel

Commit order: install → tenancy integration → resources → widgets → policies → uploads → tests → docs

Run php artisan test before committing when relevant.

If gh + GH_TOKEN exist, push and open PR to main with a clear title/body.

1) Install Filament v3
Require packages:

bash
Copy code
composer require filament/filament:"^3.2" filament/forms:"^3.2" filament/tables:"^3.2" filament/notifications:"^3.2" --no-interaction
Publish (if needed) config/themes:

bash
Copy code
php artisan vendor:publish --tag=filament-config
php artisan vendor:publish --tag=filament-views
Configure Filament panel in config/filament.php:

Path /admin

Use default login; guard uses users table (the same users who belong to companies).

Commit: chore(admin): install Filament v3 and base config

2) Multi-Tenant Integration (company scope)
Goal: Every panel request operates under a current company context (like API middleware).

Tasks
Create a middleware app/Http/Middleware/SetTenantForFilament.php that resolves {company} from query or user-preferred company, then sets app('currentCompany') and applies a global scope (the same you use for API).

Register this middleware for Filament only inside app/Providers/FilamentServiceProvider.php (create provider if missing) or inside panel boot via Filament config.

Add a company switcher in the Filament topbar: a simple Select that lists companies the user belongs to; persisting selection in session (e.g., session('current_company_id')).

Commit: feat(admin): tenant context middleware + topbar company switcher

3) RBAC with existing roles (admin/cashier/viewer)
Goal: Respect existing roles per company from company_user pivot.

Tasks
Reuse/extend existing CompanyResourcePolicy & Gates (company.view, company.write, company.admin).

In each Resource pages (Create/Edit/Delete/Approve), call $this->authorize(...) or Filament’s can() hooks to enforce:

viewer: read-only

cashier: write for operational items (stock adjust, SO create/confirm/pay) but not admin ops

admin: full access (approve payments, manage custom fields)

Global navigation: hide menu items the user cannot access.

Commit: feat(admin): enforce RBAC in panel

4) Resources (CRUD)
Create Filament Resources below. Each resource must be tenant-scoped (query by company_id) and map attributes JSON to dynamic form fields (see Section 5).

4.1 ProductResource
List: SKU, Name, Price, Stock, Low-stock badge (<= config threshold)

Form: SKU, Name, Price, Cost, Attributes (dynamic), Active toggle

Actions: Create, Edit, Delete, Stock Adjust (modal → calls API/service), View Movements

Search: by SKU/Name

Table bulk actions: export CSV

4.2 CustomerResource
List: Phone, Name, Tier, Total orders

Form: Phone, Name, Tier (select), Attributes (dynamic)

4.3 SaleOrderResource
List: TX_ID, Status, Payment State, Customer, Total

Form (Create Draft): Customer, Items (repeater: product, qty, unit_price), Payment method

Actions:

Confirm (calls service, deducts stock)

Pay (cash/transfer; upload slip when transfer)

Approve Payment (admin only)

Cancel (with reason)

Show page: Items table + Stock movements link

4.4 StockMovementResource (read-only)
List: datetime, product, ref_type, ref_id, qty_in, qty_out, balance_after, notes

Filters: product, date range, ref_type

4.5 CustomFieldDefResource
List: entity, key, label, data_type, required, is_indexed

Form: entity, key, label, data_type, options (array), required, is_indexed, validation_regex

Action: “Create JSON Index” (runs the artisan command or dispatches a job)

Commit: feat(admin): Product/Customer/SaleOrder/StockMovement/CustomField resources

5) Dynamic Custom Fields UI (form builder)
Goal: Render dynamic fields in Product/Customer/SO/SO Item forms based on custom_field_defs for the current company.

Tasks
Create helper app/Support/CustomFieldFormBuilder.php to convert defs → Filament form components:

text → TextInput

number → TextInput with numeric rules

boolean → Toggle

date → DatePicker

select → Select with options

multiselect → Select with multiple()

Load defs via repository/service per entity; map values to attributes.{key}.

Ensure validation mirrors backend (reuse CustomFieldRegistry for rules if feasible).

Commit: feat(admin): dynamic custom field form builder

6) Payment Slip Uploads in Panel
Goal: Manage slip upload & approval from SaleOrder pages.

Tasks
On SO view/edit page:

If payment_method = transfer and state = PendingReceipt, show Upload Slip action → store in storage/app/public/slips/{company}/{tx}/...

Show slip preview (Image column/card) if exists

Approve Payment (admin): button on Show page → sets payment_state=Received, approved_by/approved_at.

Add relevant Notifications (Filament\Notifications) on success/failure.

Commit: feat(admin): payment slip upload & approve actions

7) Dashboard & Widgets
Create a custom dashboard page with widgets (read-only queries are tenant-scoped):

SalesTodayWidget: total sales today (Confirmed+Received)

TopProductsWidget (last 7/30 days)

LowStockWidget (list products under threshold)

PaymentMixWidget (pie/percentages)

Wire as /admin home. Use Filament’s Widgets\TableWidget and Charts plugin if desired.

Commit: feat(admin): dashboard widgets (sales, top-products, low-stock, payment-mix)

8) Navigation, Theme & Branding
Set app name “FlexStock Admin” + ZentryDev logo (SVG) + primary color in Filament theme.

Group navigation: Sales, Inventory, Customers, Settings.

Add footer with version/hash (from git rev-parse --short HEAD if available).

Commit: chore(admin): theme & navigation structure

9) Tests (Panel)
Feature tests using Laravel test suite to ensure:

Tenant isolation in panel queries

RBAC (viewer read-only, cashier limited, admin full)

Custom fields form renders and validates

Payment slip upload action works and stores files

If Dusk or Pest plugin is available, add browser-level tests (optional).

Commit: test(admin): panel feature tests

10) Docs
Update README.md / create ADMIN_PANEL.md:

How to login to /admin

Role matrix for capabilities

How to switch company in topbar switcher

How to manage custom fields and create JSON index

How to upload/approve payment slips

Dashboard descriptions

Commit: docs: admin panel usage & role matrix

Open PR
bash
Copy code
git push -u origin feature/phase3-admin-panel
gh pr create --fill --title "feat: Phase 3 — Admin Panel (Filament v3)" \
  --body "Adds a production-ready Admin Panel with tenant scoping, RBAC, CRUD resources, dynamic custom fields, payment slips, and dashboard widgets."
END PROMPT FOR CLAUDE
yaml
Copy code

---

📎 ให้คุณสร้างไฟล์ชื่อ  
`flexstock_phase3_admin_panel.md`  
แล้ววางเนื้อหาทั้งหมดนี้ลงไปในเครื่อง (โฟลเดอร์เดียวกับโปรเจกต์)

จากนั้นรันคำสั่งในเทอร์มินัล:
```bash
cd /home/aunji/flexstock
claude -p "$(awk '/^BEGIN PROMPT FOR CLAUDE$/{flag=1;next}/^END PROMPT FOR CLAUDE$/{flag=0}flag' ../flexstock_phase3_admin_panel.md)" \
  --dangerously-skip-permissions --output-format json --model sonnet --max-turns 36
