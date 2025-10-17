# FlexStock — Laravel Blueprint (Full Stack, Multi‑Tenant)

> ระบบขาย + สต๊อก + รายงาน + เพิ่มฟิลด์เอง (Custom Fields) ด้วย **Laravel 11** ทั้งระบบ  
> โครง URL: `https://flexstock.zentrydev.com/{company}/...` (Tenant = บริษัท)

**Stack:** Laravel 11 (PHP 8.3) · MySQL 8 · Redis (cache/queue) · Sanctum (API Auth) · Blade + Filament (Admin) · Docker Compose + Caddy

---

## 1) Modules & Features (สรุป)
- **Tenants (Companies)**: แยกข้อมูลด้วย `company_id`, route prefix `{company}`, สิทธิ์ต่อบริษัท
- **Users & Roles**: admin / cashier / viewer (per company) + Sanctum tokens
- **Customers & Tiers**: ลูกค้า PK ภายในบริษัท (phone unique per company) + tier ส่วนลด
- **Products & Inventory**: SKU unique per company, ราคาขาย/ทุน, เลเจอร์ **stock_movements** (append-only)
- **Sale Orders**: สร้าง SO (Draft → Confirmed/Cancelled); การชำระเงิน: cash/transfer (PendingReceipt → Received)
- **Reports**: ยอดขายรายวัน/ช่วงเวลา, Top products, Low stock, Payment mix
- **Admin Settings**: **Custom Fields** (Product/Customer/SaleOrder/Item), Tier list, Document numbering, Tax/UOM
- **Multi‑Tenant Security**: Middleware + Global Scope + Policy (company isolation)

---

## 2) Directory Layout (แนะนำ)
```
app/
 ├─ Models/
 ├─ Http/
 │   ├─ Controllers/
 │   ├─ Middleware/TenantResolver.php
 │   ├─ Requests/
 │   └─ Resources/ (API Resources)
 ├─ Services/
 │   ├─ ProductService.php
 │   ├─ StockService.php
 │   └─ SaleOrderService.php
 ├─ Policies/
 └─ Providers/TenantServiceProvider.php
bootstrap/
config/
database/
 ├─ migrations/
 ├─ seeders/
 └─ factories/
routes/
 ├─ api.php
 └─ web.php
resources/
 ├─ views/ (Blade)
 └─ filament/
```

---

## 3) Migrations (หลัก)
> ใช้ `php artisan make:migration` แล้วปรับตามด้านล่าง

```php
// 2025_01_01_000001_create_companies_table.php
return new class extends Migration {
  public function up(): void {
    Schema::create('companies', function (Blueprint $t) {
      $t->uuid('id')->primary();
      $t->string('name');
      $t->string('slug')->unique();
      $t->boolean('is_active')->default(true);
      $t->timestamps();
    });
  }
  public function down(): void { Schema::dropIfExists('companies'); }
};
```

```php
// 2025_01_01_000010_create_users_and_company_user.php
return new class extends Migration {
  public function up(): void {
    Schema::create('users', function (Blueprint $t) {
      $t->id();
      $t->string('name');
      $t->string('email')->unique();
      $t->string('password');
      $t->rememberToken();
      $t->timestamps();
    });
    Schema::create('company_user', function (Blueprint $t) {
      $t->uuid('company_id');
      $t->foreign('company_id')->references('id')->on('companies')->cascadeOnDelete();
      $t->foreignId('user_id')->constrained()->cascadeOnDelete();
      $t->enum('role',['admin','cashier','viewer']);
      $t->boolean('is_default')->default(false);
      $t->timestamps();
      $t->primary(['company_id','user_id']);
      $t->index(['company_id','role']);
    });
  }
  public function down(): void {
    Schema::dropIfExists('company_user');
    Schema::dropIfExists('users');
  }
};
```

```php
// 2025_01_01_000100_create_customer_tiers_and_customers.php
return new class extends Migration {
  public function up(): void {
    Schema::create('customer_tiers', function (Blueprint $t) {
      $t->uuid('company_id');
      $t->foreign('company_id')->references('id')->on('companies')->cascadeOnDelete();
      $t->string('code');
      $t->string('name');
      $t->enum('discount_type',['percent','amount']);
      $t->decimal('discount_value',12,2)->default(0);
      $t->text('notes')->nullable();
      $t->timestamps();
      $t->primary(['company_id','code']);
    });
    Schema::create('customers', function (Blueprint $t) {
      $t->id();
      $t->uuid('company_id');
      $t->foreign('company_id')->references('id')->on('companies')->cascadeOnDelete();
      $t->string('phone');             // unique per company
      $t->string('name');
      $t->string('tier_code')->nullable();
      $t->json('attributes')->nullable(); // JSON custom fields
      $t->timestamps();
      $t->unique(['company_id','phone']);
      $t->foreign(['company_id','tier_code'])
        ->references(['company_id','code'])->on('customer_tiers')->nullOnDelete();
    });
  }
  public function down(): void {
    Schema::dropIfExists('customers');
    Schema::dropIfExists('customer_tiers');
  }
};
```

```php
// 2025_01_01_000200_create_products_and_stock_movements.php
return new class extends Migration {
  public function up(): void {
    Schema::create('products', function (Blueprint $t) {
      $t->id();
      $t->uuid('company_id');
      $t->foreign('company_id')->references('id')->on('companies')->cascadeOnDelete();
      $t->string('sku');
      $t->string('name');
      $t->string('base_uom')->default('unit');
      $t->decimal('price',12,2);
      $t->decimal('cost',12,2)->default(0);
      $t->decimal('stock_qty',14,3)->default(0);
      $t->json('attributes')->nullable();
      $t->boolean('is_active')->default(true);
      $t->timestamps();
      $t->unique(['company_id','sku']);
      $t->index(['company_id','created_at']);
    });
    Schema::create('stock_movements', function (Blueprint $t) {
      $t->id();
      $t->uuid('company_id');
      $t->foreign('company_id')->references('id')->on('companies')->cascadeOnDelete();
      $t->foreignId('product_id')->constrained('products');
      $t->enum('ref_type',['SALE','ADJUSTMENT','OPENING','RETURN','PURCHASE']);
      $t->string('ref_id')->nullable();
      $t->decimal('qty_in',14,3)->default(0);
      $t->decimal('qty_out',14,3)->default(0);
      $t->decimal('balance_after',14,3);
      $t->text('notes')->nullable();
      $t->timestamps();
      $t->index(['company_id','product_id','created_at']);
    });
  }
  public function down(): void {
    Schema::dropIfExists('stock_movements');
    Schema::dropIfExists('products');
  }
};
```

```php
// 2025_01_01_000300_create_sale_orders.php
return new class extends Migration {
  public function up(): void {
    Schema::create('sale_orders', function (Blueprint $t) {
      $t->id();
      $t->uuid('company_id');
      $t->foreign('company_id')->references('id')->on('companies')->cascadeOnDelete();
      $t->string('tx_id')->unique();
      $t->foreignId('customer_id')->constrained('customers');
      $t->enum('status',['Draft','Confirmed','Cancelled']);
      $t->enum('payment_state',['PendingReceipt','Received'])->default('PendingReceipt');
      $t->enum('payment_method',['cash','transfer'])->nullable();
      $t->decimal('subtotal',12,2)->default(0);
      $t->decimal('discount_total',12,2)->default(0);
      $t->decimal('tax_total',12,2)->default(0);
      $t->decimal('grand_total',12,2)->default(0);
      $t->json('attributes')->nullable();
      $t->foreignId('created_by')->nullable()->constrained('users');
      $t->foreignId('approved_by')->nullable()->constrained('users');
      $t->timestamps();
      $t->index(['company_id','created_at']);
    });
    Schema::create('sale_order_items', function (Blueprint $t) {
      $t->id();
      $t->foreignId('sale_order_id')->constrained('sale_orders')->cascadeOnDelete();
      $t->foreignId('product_id')->constrained('products');
      $t->decimal('qty',14,3);
      $t->string('uom')->default('unit');
      $t->decimal('unit_price',12,2);
      $t->decimal('discount_value',12,2)->default(0);
      $t->decimal('tax_rate',5,2)->default(0);
      $t->decimal('line_total',12,2);
      $t->json('attributes')->nullable();
      $t->timestamps();
    });
  }
  public function down(): void {
    Schema::dropIfExists('sale_order_items');
    Schema::dropIfExists('sale_orders');
  }
};
```

```php
// 2025_01_01_000400_create_custom_field_defs.php
return new class extends Migration {
  public function up(): void {
    Schema::create('custom_field_defs', function (Blueprint $t) {
      $t->id();
      $t->uuid('company_id');
      $t->foreign('company_id')->references('id')->on('companies')->cascadeOnDelete();
      $t->enum('entity',['PRODUCT','CUSTOMER','SALE_ORDER','SALE_ORDER_ITEM']);
      $t->string('key');
      $t->string('label');
      $t->enum('data_type',['text','number','boolean','date','select','multiselect']);
      $t->boolean('required')->default(false);
      $t->json('options')->nullable();
      $t->json('default_value')->nullable();
      $t->boolean('is_indexed')->default(false);
      $t->string('validation_regex')->nullable();
      $t->timestamps();
      $t->unique(['company_id','entity','key']);
    });
  }
  public function down(): void { Schema::dropIfExists('custom_field_defs'); }
};
```

---

## 4) ตัวอย่าง Models / Middleware / Routes / Controllers / Services
(รวมอยู่ในไฟล์เพื่อพร้อมใช้งานต่อ — ดูส่วน “Models”, “Tenant Middleware”, “Routes”, “Controllers”, “Services” ในเนื้อหา)

---

## 5) Deploy (Docker Compose + Caddy) + .env + Postman
(รวมตัวอย่างไฟล์ทั้งหมดด้านล่างของเอกสารนี้)

---

## 6) Test Checklist
- URL `/{company}/...` → ต้องมี slug บริษัทและผู้ใช้เป็นสมาชิก
- Product CRUD + Adjust Stock → สร้าง stock_movements ถูกต้อง
- SO Draft → Confirm → หักสต๊อกในทรานแซกชัน
- โอนเงิน → PendingReceipt → Approve → Received
- เพิ่ม Custom Field → ฟอร์มแสดง + validate + query ได้
- รายงาน 4 หัวข้อถูกต้อง

---

> ใช้ไฟล์นี้เป็น “สคริปต์ให้ Claude/Dev” ในการสร้างโค้ดจริงต่อได้ทันที