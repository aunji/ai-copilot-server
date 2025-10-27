# saas-chatbot-omni-commerce.md

> **สำคัญมาก – คำสั่งถึง Claude Code**  
> - ทำตัวเป็น **Senior Staff/Principal Engineer** ระดับโลก  
> - พัฒนา **Production-grade** จริงตั้งแต่ต้น: โค้ดพร้อมรัน, มี test, CI/CD, security hardening, observability, docs  
> - **ห้ามถามย้อน/ขออนุญาต** ให้ลงมือทำตามสเปคนี้ทันที ถ้าติดประเด็นให้เลือกทางที่ปลอดภัย-เป็นมาตรฐานอุตสาหกรรม  
> - หลีกเลี่ยง mock / stub ที่ไม่จำเป็น ใช้ fake only ที่ขอบเขต test  
> - แยก commit ตาม feature, ผ่านทดสอบทั้งหมดก่อน push

---

## 0) Product Scope (TH)

SaaS แชทบอทสำหรับ **LINE OA** และ **Facebook Messenger**:
- แดชบอร์ดให้ลูกค้า (tenant) ใส่ข้อมูลร้าน, สินค้า, ราคา, โปรโมชัน  
- AI ตอบอัตโนมัติ พร้อม RAG จาก FAQs/ไฟล์/URL/Sheets + คลังสินค้า  
- ตะกร้า/เช็คเอาต์ (Omise/Stripe/PromptPay) ส่งลิงก์จ่ายในแชท  
- Inbox มนุษย์รับไม้, RBAC, Audit log, Usage billing, Observability

**เป้าหมาย**: MVP แข็งแรง, deploy ได้จริง, รองรับ multi-tenant พร้อมสเกล

---

## 1) Tech & Architecture

- **Backend:** Laravel 11 (PHP 8.3), MySQL 8 (หรือ PostgreSQL 15), Redis 7, Horizon  
- **AI Layer:** OpenAI/Anthropic provider abstraction + Embeddings, **pgvector/Qdrant** (เลือกอย่างใดอย่างหนึ่ง)  
- **Frontend:** React 18 + Vite + TypeScript + Tailwind + TanStack Query  
- **Infra:** Docker Compose (dev, staging), K8s manifests (prod-ready), Caddy/Traefik, S3-compatible object storage, Cloudflare CDN/WAF  
- **Observability:** OpenTelemetry traces, Prometheus metrics, JSON logs, Sentry  
- **CI/CD:** GitHub Actions (build, test, security scan, container push, deploy)  
- **Security:** Secrets via env, HSTS, CSRF, CORS strict, webhook signature verify, idempotency keys, RBAC, audit  
- **Region:** ap-southeast-1 defaults

---

## 2) Monorepo Layout

```
/saas-chatbot
  /backend        # Laravel 11 app
  /frontend       # React + Vite dashboard
  /deploy
    /docker       # docker-compose.*.yml, Dockerfiles
    /k8s          # prod manifests (namespace, secrets, deploy, svc, ingress, hpa)
    /caddy        # Caddyfile for local/staging
  /.github/workflows
  /docs           # runbooks, API docs, ADRs
  /scripts        # make, seed, ops scripts
```

---

## 3) Core Domains & Tables (ERD ย่อ)

- tenants(id, name, plan, status, …)  
- users(id, tenant_id, email, password_hash, 2fa_secret, …) + roles/permissions  
- channels(id, tenant_id, type[line|messenger], display_name, secrets(enc), status)  
- end_users(id, tenant_id, platform, platform_user_id, profile_json, tags, last_seen_at)  
- conversations(id, tenant_id, channel_id, end_user_id, status, assignee_id, last_msg_at)  
- messages(id, conversation_id, role[user|assistant|agent|system], content, payload_json, platform_msg_id, delivery_status, error)  
- catalog_products(id, tenant_id, sku, name, description, price, compare_at, images[], attributes_json, stock)  
- carts(id, tenant_id, end_user_id, channel_id, currency, totals_json, status)  
- cart_items(id, cart_id, product_id, qty, unit_price, options_json)  
- orders(id, tenant_id, end_user_id, totals_json, payment_status, delivery_status, external_ref)  
- promotions(id, tenant_id, rule_json, start_at, end_at, is_active)  
- knowledge_sources(id, tenant_id, type[faq|file|url|sheet], meta_json, status)  
- kb_chunks(id, source_id, content, embedding_vector)  
- intents(id, tenant_id, name, patterns[], priority, tool_config_json)  
- webhooks_out(id, tenant_id, url, secret, event_types[])  
- audit_logs(id, tenant_id, actor_id, action, target_type, target_id, diff_json, ip)  
- usage_meters(id, tenant_id, metric, qty, window_start, window_end)  
- invoices(id, tenant_id, amount, items_json, status)

**ข้อบังคับ:** ทุกตารางที่เป็นข้อมูลธุรกิจต้องมี `tenant_id` และ enforce row-level scoping

---

## 4) Feature Checklist (ต้องส่งมอบ)

### 4.1 Channel Gateway
- LINE & Messenger webhook endpoints
- Signature verification (LINE `X-Line-Signature`, FB appsecret_proof)
- Normalize event → unified schema; enqueue jobs (Redis queues)
- Idempotency ด้วย platform message id; retry with exponential backoff
- Rate-limit per tenant & per end_user

### 4.2 AI Orchestrator
- Intent classifier (rule+lightweight ML) + Router
- RAG: hybrid search (lexical + vector) จาก kb_chunks + product index
- Tool-calls (strict): product search/detail, cart ops, checkout link, order lookup, store info, human handover
- Thai/EN auto-detect + brand voice; guardrails ห้ามเดาราคา/สต็อก (ต้องผ่าน tool)
- Short-TTL cache for popular queries

### 4.3 Commerce
- Catalog CRUD, import CSV/Google Sheets
- Cart/Quote, Promotions (basic rules), Currency rounding
- Checkout link (Omise/Stripe/PromptPay QR), order hold TTL
- Send receipt in chat + email

### 4.4 Inbox & Ops
- Omni-channel inbox, assignment, tags, internal notes, SLA timers
- Human handover (Messenger Handover Protocol; LINE internal state)
- Canned responses, transcript export (CSV/JSON)

### 4.5 Knowledge Base
- Sources: FAQ form, file upload (PDF/Doc), URL, Google Sheet
- Chunking, embedding async workers, versioning & re-embed button

### 4.6 Admin Dashboard
- Home KPIs, Catalog, Knowledge, Automation (intents/rules, menus), Payments, Channels connect, Analytics, Settings (RBAC, API keys, webhooks, audit), Billing

### 4.7 Security & Compliance
- RBAC (Owner/Admin/Agent/Analyst), 2FA optional
- PDPA-like tools: data export/delete for end_user; retention policy
- Audit log for critical actions
- WAF-ready headers, strict CORS, HSTS, secure cookies

### 4.8 Observability
- /healthz, /readyz
- Metrics: queue lag, tool latency, fallback rate, conversions
- Tracing spans: webhook→router→RAG→tool→reply
- Error tracking (Sentry)

---

## 5) API Contracts (หลัก)

**Auth:**  
- `POST /api/v1/auth/login`  
- `POST /api/v1/auth/refresh`  
- `POST /api/v1/auth/logout`

**Catalog:**  
- `GET /api/v1/catalog/products?query=&category=&page=`  
- `POST /api/v1/catalog/products` (bulk upsert allowed)  
- `PUT /api/v1/catalog/products/{id}`  
- `DELETE /api/v1/catalog/products/{id}`

**Knowledge:**  
- `POST /api/v1/kb/sources` (faq/file/url/sheet)  
- `POST /api/v1/kb/reindex`  
- `GET /api/v1/kb/sources/:id/chunks`

**Conversations/Inbox:**  
- `GET /api/v1/conversations?status=&assignee=`  
- `GET /api/v1/conversations/{id}`  
- `POST /api/v1/conversations/{id}/reply` (agent)  
- `POST /api/v1/conversations/{id}/assign`  
- `POST /api/v1/conversations/{id}/tags`

**Commerce:**  
- `POST /api/v1/carts/{end_user_id}/items`  
- `GET /api/v1/carts/{end_user_id}`  
- `POST /api/v1/checkout/create` → `{ payment_url }`  
- `POST /api/v1/orders/webhooks/payment` (verify signature)

**Automation / Intents:**  
- `GET /api/v1/intents`  
- `POST /api/v1/intents` (patterns, tool_config)  
- `PUT /api/v1/intents/{id}`  
- `DELETE /api/v1/intents/{id}`

**Channels (Inbound Webhooks):**  
- `POST /webhooks/line/{channel_id}`  
- `POST /webhooks/fb/{channel_id}`

**Webhooks Out:**  
- `POST /api/v1/webhooks` (register outbound)  
- Events: `order.created`, `message.fallback`, `cart.abandoned`, `customer.created`

---

## 6) AI Tool-Call Schemas (JSON)

```json
{
  "name": "searchProducts",
  "parameters": {
    "type": "object",
    "properties": {
      "query": { "type": "string" },
      "filters": { "type": "object" },
      "limit": { "type": "integer", "default": 10 }
    },
    "required": ["query"]
  }
}
```

```json
{
  "name": "addToCart",
  "parameters": {
    "type": "object",
    "properties": {
      "end_user_id": { "type": "string" },
      "sku": { "type": "string" },
      "qty": { "type": "integer", "minimum": 1 }
    },
    "required": ["end_user_id", "sku", "qty"]
  }
}
```

```json
{
  "name": "createCheckoutLink",
  "parameters": {
    "type": "object",
    "properties": {
      "cart_id": { "type": "string" },
      "gateway": { "type": "string", "enum": ["omise", "stripe", "promptpay"] }
    },
    "required": ["cart_id", "gateway"]
  }
}
```

> เพิ่ม: `getProduct`, `lookupOrder`, `getStoreInfo`, `handoverToAgent` ตามแบบเดียวกัน

---

## 7) Security Requirements

- Verify HMAC signatures (LINE, FB). Reject if timestamp window > 5m  
- Idempotency key = platform message id (store digest)  
- Secrets at rest: encrypt (Laravel encrypter) + KMS-ready  
- Strict validation (Laravel FormRequest) ทุก endpoint  
- Rate-limit: per tenant & per end_user (token bucket)  
- CSRF on dashboard, SameSite=Lax, Secure cookies, HSTS on TLS  
- Input sanitation; output escaping; disable guess mime  
- File scanning for uploads (ClamAV container)  
- Logging PII: mask phone/email except last 2 chars

---

## 8) Testing Strategy

- **Unit:** tool contracts, promo rules, pricing, webhook verifiers  
- **Feature/HTTP:** API endpoints (auth, catalog, kb, carts, checkout)  
- **Contract Tests:** fixtures สำหรับ LINE/Messenger events (snapshot tests)  
- **E2E (backend):** webhook → AI (LLM mocked) → tool-calls → reply  
- **E2E (frontend):** Cypress: login, catalog CRUD, connect channel, simulate chat preview  
- **Load:** k6 script for webhook ingress (5k rps burst), queue lag guard  
- **Security:** larastan/phpstan, php-cs-fixer, composer audit, Trivy image scan

---

## 9) CI/CD (GitHub Actions)

- **backend.yml**: install deps, phpstan, phpunit, mutation tests (optional), build Docker image, Trivy scan, push registry  
- **frontend.yml**: pnpm i, typecheck, vitest, build, Dockerize  
- **deploy.yml**: on tag `v*`, render manifests (kustomize), `kubectl apply`, run migrations, Horizon rolling  
- Artifacts: SBOM (syft), coverage reports, OpenAPI JSON (from routes)

---

## 10) Docker & Runtime

**Backend Dockerfile (prod) – requirements:**  
- php:8.3-fpm-alpine, opcache, intl, pdo_mysql/pgsql, redis, gd, bcmath  
- Non-root user, read-only FS except storage/cache/logs  
- `php.ini` tuned (opcache JIT off, memory_limit sane), `fpm` pool tuned  
- Healthcheck script: DB/Redis ping, queue up

**docker-compose.dev.yml:**  
- backend, frontend, mysql/pgsql, redis, vector db (pgvector/qdrant), caddy, minio (S3)  
- volumes + hot reload dev

---

## 11) Frontend Dashboard (Pages)

- **/login** (2FA optional)  
- **/home** KPIs  
- **/inbox** threads, filters, assignment, reply, notes, canned  
- **/catalog** list/create/edit, CSV import, images upload (S3)  
- **/knowledge** sources list, add, index status, re-embed  
- **/automation** intents/rules, menu builders (store persistent menu config for channels)  
- **/payments** gateways config, test payment  
- **/channels** connect LINE OA (channel id/secret/webhook url), FB Page/App tokens  
- **/analytics** intents, fallback %, conversions, first-response time  
- **/settings** members & roles, webhooks, audit, API keys, billing

> UX: Loading/skeleton, optimistic updates where safe, error boundaries, i18n th/en

---

## 12) Payment Flow (สูงสุด)

- Create checkout link: hold order with TTL (e.g., 15m)  
- Omise/Stripe webhooks: verify signature, update order status atomically  
- PromptPay: generate QR, poll/confirm (adapter interface; pluggable provider)  
- Send receipt in chat (text + rich template)

---

## 13) Billing & Plans

- Plans: Starter/Growth/Scale (+addons: OCR slip, advanced analytics)  
- Usage meters: ai_tokens, messages, MAU, channels, storage  
- Invoicing via Stripe/Omise; overage alerts email + in-app  
- Hard/soft limit behaviors (429 + dashboard notice)

---

## 14) Observability & SLO

- p95 webhook→reply < 1s (LLM tool path < 700ms)  
- Message send success > 99.9% rolling 7d  
- Alerts: DLQ growth, fallback spike, payment failure rate, queue lag  
- Traces with baggage: tenant_id, channel_id, conversation_id

---

## 15) Definition of Done (ทุก Feature)

- Code + tests ผ่าน 100% ของกรณี critical  
- API docs (OpenAPI excerpt) อัปเดต  
- Observability hooks (metrics/traces/logs) ครบ  
- Security review checklist ผ่าน  
- Runbook/README section เพิ่ม  
- Demo script (scripted curl / Postman collection) ใช้งานได้จริง

---

## 16) Runbooks (ย่อ)

- **Local dev:** `make dev-up`, `make dev-seed`, open http://localhost:5173  
- **Migrate:** `php artisan migrate --force`  
- **Reindex KB:** `php artisan kb:reindex --tenant={id}`  
- **Rotate secrets:** `php artisan secrets:rotate`  
- **Scale workers:** Horizon tags per-queue; K8s HPA target CPU 65%

---

## 17) Tasks for Claude Code (ทำตามลำดับ ไม่ต้องถาม)

### T1 – Bootstrap Repos & Tooling
- สร้าง monorepo โครงสร้างตามข้อ 2  
- ตั้งค่า EditorConfig, git hooks (pre-commit lint/tests), LICENSE (MIT), CONTRIBUTING.md  
- เพิ่ม Makefile สคริปต์สั้น ๆ (dev-up, dev-down, test, lint, build, seed)

### T2 – Backend Foundation
- Laravel 11 skeleton + multi-tenant middleware (scoping by `tenant_id`)  
- DB migrations + seeders (tenant demo, sample catalog, FAQs)  
- Auth (Sanctum/JWT), RBAC (spatie/permission), 2FA (time-based)  
- Horizon + queue config; S3 storage; Sentry + OTEL SDK

### T3 – Channel Gateway
- Implement `/webhooks/line/{channel_id}` & `/webhooks/fb/{channel_id}`  
- Signature verify, idempotency, normalize events, enqueue jobs  
- Basic reply adapters (LINE reply/push; FB Send API)

### T4 – AI Orchestrator & RAG
- Intent router, tool registry (function-call schemas)  
- Vector DB integration (pgvector/qdrant), embedding jobs  
- Guardrails (price/stock via tool-only), Thai/EN detection, response formatter

### T5 – Commerce
- Catalog CRUD + CSV import + images to S3  
- Cart/Quote + Promotions rules  
- Checkout link (Omise/Stripe/PromptPay), payment webhooks verify, order finalize

### T6 – Inbox & Automation
- Conversations + messages + human handover support  
- Automation: intents/rules CRUD, menu builders (store persistent menu config for channels)

### T7 – Knowledge Base
- Sources (faq/file/url/sheet), chunking pipelines, re-embed, version control

### T8 – Frontend Dashboard
- Auth flows, pagesทั้งหมด (ข้อ 11), RBAC-guarded routes  
- Reusable UI: DataGrid, Dialogs, Form builders, Flex/Template previews

### T9 – Observability & Security Hardening
- Metrics, traces, structured logs, alerts templates  
- Security headers, CORS strict, file scanning (clamav), audit logs UI

### T10 – CI/CD & Deploy
- GitHub Actions (build/test/scan/push/deploy)  
- Dockerfiles (prod-grade), docker-compose.dev.yml  
- K8s manifests (namespace, secrets, deploy, svc, ingress, hpa), Caddy config

### T11 – Tests & Sample Data
- PHPUnit, Pest (optional), Cypress (frontend)  
- Fixtures for LINE/Messenger events, E2E flows (webhook→reply)  
- Postman collection + environment; seed demo tenant

---

## 18) Acceptance Tests (ตัวอย่างสำคัญ)

1. **LINE text “มีไอติมรสอะไรบ้าง”**  
   - Router → RAG+product search → ตอบพร้อมรายการ + ราคา จาก DB จริง  
   - ห้ามเดาราคา/สต็อกโดยไม่เรียก tool  
2. **เพิ่มสินค้า SKU=SKU123 ลงตะกร้า** ผ่านปุ่มในแชท  
   - `addToCart` เรียกสำเร็จ, cart มี item, quick-reply “ดูตะกร้า/เช็คเอาต์”  
3. **สร้างลิงก์จ่าย Omise**  
   - รับ webhook ยืนยัน → orders.payment_status=paid, ส่งใบยืนยันในแชท  
4. **Inbox handover**  
   - agent ตอบและปิดบทสนทนาได้, transcript export ใช้ได้  
5. **KB re-embed**  
   - เพิ่มไฟล์ PDF ใหม่ → reindex → คำถามที่เกี่ยวข้องตอบถูกต้อง  
6. **Rate-limit & idempotency**  
   - ยิงซ้ำ message id เดิม → ตอบเพียงครั้งเดียว  
7. **RBAC**  
   - Analyst อ่าน analytics ได้แต่แก้ catalog ไม่ได้

---

## 19) Security Checklist (ต้องผ่าน)

- [ ] Verify signatures (LINE/FB), reject replay  
- [ ] Idempotency keys stored + TTL  
- [ ] Secrets encrypted at rest  
- [ ] File uploads scanned; mime/type double-check  
- [ ] SQL indexes on tenant_id + hot paths  
- [ ] Rate-limit per tenant/end_user  
- [ ] CSRF, CORS, HSTS, secure cookies, no-referrer  
- [ ] Access logs + audit with actor, IP, diff  
- [ ] Backups + restore test runbook

---

## 20) Deliverables

- โค้ดเต็ม **backend/frontend/deploy** + Docker/K8s + CI pipelines  
- Tests ครอบคลุม feature critical  
- Postman collection + sample env  
- Docs: README, Runbooks, API reference (OpenAPI extract), ADRs สำหรับ trade-offs หลัก  
- Demo seed tenant + script เดิน scenario Acceptance tests

---

## 21) Notes & Trade-offs

- Vector store: ถ้าใช้ PostgreSQL อยู่แล้วให้ใช้ **pgvector** ลด infra; ถ้าเน้น performance แยก **Qdrant**  
- Payments: เริ่ม Omise (TH) + Stripe (global) + PromptPay adapter สำหรับ QR  
- OCR สลิป: ทำเป็น **addon** ภายหลัง (worker + verifier)

---

### จบไฟล์ — เริ่มทำงานได้ทันทีตาม Tasks (T1–T11) และส่ง PR เป็นลำดับ feature พร้อมรายงานสถานะใน `docs/CHANGELOG.md`
