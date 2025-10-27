# omni-commerce-phase2.md

> **Execution Mode for Claude Code**
> - Act as **Senior Staff/Principal Engineer**.
> - Implement **production-grade** code. No mockups. No permission prompts.
> - Prefer boring, industry-standard solutions. Ship incrementally with passing tests.
> - Default stack = Laravel 10 (PHP 8.1), PostgreSQL 15 + pgvector, Redis 7, Qdrant, Nginx.
> - Follow the order below (P0 → P2). Each task must include tests, docs, and observability.

---

## Phase 2 — Scope
This phase delivers end-to-end chat flow LINE/Messenger → Webhook → AI Orchestrator (RAG + Tool Calls) → Reply, plus Commerce core and Admin API for the upcoming React dashboard.

**Outcomes**
- Inbound webhooks (LINE & Messenger) with signature verify + idempotency.
- AI Orchestrator with intent router, tool registry, RAG retrieval (Qdrant/pgvector).
- Commerce services (Catalog, Cart, Order, Payment link stub).
- Secure Admin APIs (JWT/Sanctum + RBAC) to back the dashboard.
- Observability (metrics/traces/logs) + CI updates.
- Acceptance tests pass (see bottom).

---

## P0. Foundations & Guardrails

### P0.1 Project Hardening
- Enforce PHP 8.1 settings; opcache config in Docker.
- Enable **strict types** in new PHP files.
- Add **http signature middleware** skeleton, `IdempotencyMiddleware` for webhook routes.
- Add **Request/Response logging** (masked PII) with channel `webhook` to JSON logs.
- Add **OpenTelemetry** auto-instrumentation (HTTP server/client, Redis, DB).

### P0.2 Tenant Resolution
- Implement `TenantResolver` (stancl/tenancy) supporting:
  - Header `X-Tenant` (admin/internal).
  - Channel mapping by `channel_id` for webhooks (central DB lookup → tenant context).
- Add tests: central → tenant context switching, race-safe.

---

## P1. Channel Webhooks (LINE/Messenger)

### P1.1 Routes
```
POST /webhooks/line/{channel_uuid}
POST /webhooks/facebook/{page_uuid}
```
- Bind `channel_uuid`/`page_uuid` → central `channel_connections` → tenant.
- Apply middlewares: `verify.signature:*`, `idempotent:webhook`, `tenant.context`.

### P1.2 Signature Verification
- **LINE**: header `X-Line-Signature` HMAC-SHA256 with Channel Secret.
- **Facebook**: `appsecret_proof = HMAC_SHA256(app_secret, access_token)` check + verify request signature if present.
- Reject if timestamp drift > 5m.

### P1.3 Normalization
Create `InboundMessage` DTO:
```php
class InboundMessage {
  public string $tenantId;
  public string $channelId;
  public string $platform; // line|facebook
  public string $eventType; // message|postback|follow|unfollow|delivery...
  public ?string $userId;
  public ?string $text;
  public array $attachments; // images, files, location
  public array $raw;
  public string $platformMessageId;
}
```
- Store raw payload in `webhook_logs` (central), create/attach `end_users`, `conversations`, `messages` (tenant DB).
- Dispatch `MessageReceived` job to queue.

### P1.4 Idempotency
- Key = `{platform}:{platformMessageId}`.
- Use Redis `SETNX` with TTL (24h), or insert unique key in `webhook_logs`.
- Tests: duplicated POST processed exactly once, with delivery-safe retry.

### P1.5 Reply Adapters
- **LINE**: Reply/Push API, Flex message builder service.
- **Facebook**: Send API; support text, quick reply, generic template.
- Respect rate limits; exponential backoff. Trace external calls.

---

## P2. AI Orchestrator & RAG

### P2.1 Intent Router
- `IntentRouter` combines:
  - **Rules**: postback payload, keywords (store_hours, shipping, price, order_status).
  - **Classifier**: small model (fast LLM with system prompt) or heuristic. Cache top-N for 60s.
- Intents baseline: `greeting`, `product_search`, `product_detail`, `price_check`, `stock_check`, `promo`, `store_hours`, `order_status`, `smalltalk`, `handover`, `fallback`.

### P2.2 Tool Registry (Function Calls)
Define interfaces:
```php
interface Tool {
  public function name(): string;
  public function schema(): array; // JSON schema
  public function execute(array $args, OrchestratorContext $ctx): array;
}
```
Built-in tools (implement + register):
- `searchProducts(query, filters, limit)`
- `getProduct(sku)`
- `addToCart(end_user_id, sku, qty)`
- `createCheckoutLink(cart_id, gateway)`
- `lookupOrder(order_ref)`
- `getStoreInfo(topic)`
- `handoverToAgent(conversation_id)`

### P2.3 RAG Retrieval
- `KnowledgeSearch` service with strategy: hybrid lexical (pg fulltext) + vector (Qdrant).
- Pipeline:
  1) Query build: user text + language + shop context.
  2) Vector search top-k (k=8), min-score threshold.
  3) Merge lexical hits; rerank (BM25 + vector score).
  4) Return snippets with source refs.
- Background workers:
  - Chunker (PDF/Doc/URL/Sheet → markdown → chunks 512-1024 tokens).
  - Embedding job → store in Qdrant (or pgvector).
- Tests: retrieval returns expected chunks; Thai/EN cases.

### P2.4 Composer (LLM)
- Provider abstraction: OpenAI/Anthropic with retry/jitter + timeout.
- **Guardrails**: สำหรับราคา/สต็อก ต้องเรียก tool เท่านั้น (reject direct answer).
- Output adapters: text + carousel payload, plus Quick Replies (CTA).
- Add **safety filter** (profanity, PII redaction) pre/post.
- Observability: record token usage per-tenant → `usage_meters`.

---

## P3. Commerce Core

### P3.1 Catalog Service
- Eloquent Models: `Category`, `Product` (sku unique per tenant), soft delete.
- Services: `CatalogReader`, `CatalogImporter` (CSV/Google Sheets adapter stub).
- Endpoints:
  - `GET /api/v1/catalog/products`
  - `POST /api/v1/catalog/products` (bulk upsert)
  - `PUT /api/v1/catalog/products/{id}`
  - `DELETE /api/v1/catalog/products/{id}`
- Validation via FormRequest; indexing jobs for RAG on change.

### P3.2 Cart Service
- `CartService`: create/get by end_user & channel, add/remove/update items, compute totals (price, discount, tax placeholder).
- Endpoint:
  - `POST /api/v1/carts/{end_user_id}/items`
  - `GET /api/v1/carts/{end_user_id}`
- Store cart linkable token for deep link in chat.

### P3.3 Order & Checkout Link
- `OrderService`: create from cart, hold with TTL=15m, status `pending`.
- `PaymentService`: stub `createCheckoutLink(cart_id, gateway)` (Stripe/Omise/PromptPay).
- `POST /api/v1/checkout/create` → `{payment_url, order_id}`
- Webhook receivers (Stripe/Omise): verify signature → set `payment_status=paid` atomically.
- Send receipt message via platform adapter.

---

## P4. Admin APIs (Dashboard-ready)

- Auth: Sanctum or JWT (choose one and implement).
- RBAC: spatie/permission roles: `owner`, `admin`, `agent`, `analyst`.
- Endpoints:
  - **Conversations**: list/filter, get detail, reply (agent), assign, tag.
  - **Knowledge**: add source (faq/file/url/sheet), reindex, list chunks.
  - **Automation**: CRUD intents/rules; menu builders save persistent configs.
  - **Channels**: connect LINE/Messenger credentials; return webhook URLs.
  - **Analytics**: top intents, fallback %, conversion, first-response-time.
  - **Billing**: usage meters view (read-only in phase 2).

Security:
- Tenant scoping middleware; rate-limit; audit log (`activitylog`) for all write ops.

---

## P5. Observability & CI

### P5.1 Metrics
- Counters: `webhook_received_total{platform}`, `message_sent_total{platform}`, `tool_call_total{name}`, `ai_tokens_total{tenant}`.
- Gauges: `queue_lag_seconds`, `vector_latency_ms` p95.
- Histograms: `orchestrator_latency_seconds`.

### P5.2 Tracing
- Root span at webhook; child spans for normalize, route, rag, tools, provider, reply.
- Inject `tenant_id`, `channel_id`, `conversation_id` as baggage.

### P5.3 CI updates
- Add PHPUnit Feature suites for: webhooks, orchestrator, cart/checkout.
- Add Trivy image scan, `composer audit`, phpstan level max.
- Cache composer/vendor & phpunit coverage artifact.

---

## Code Sketches (Implement verbatim, adapt names)

### Middleware: VerifySignature
```php
final class VerifySignature
{
    public function handle($request, \Closure $next, string $platform)
    {
        $raw = $request->getContent();
        if ($platform === 'line') {
            $sig = base64_encode(hash_hmac('sha256', $raw, config('channels.line.secret'), true));
            abort_unless(hash_equals($sig, $request->header('X-Line-Signature')), 401, 'Invalid signature');
        } elseif ($platform === 'facebook') {
            // compute and validate appsecret_proof or X-Hub-Signature if configured
        }
        return $next($request);
    }
}
```

### Service: Orchestrator
```php
final class Orchestrator
{
    public function __construct(
        private IntentRouter $router,
        private ToolRegistry $tools,
        private KnowledgeSearch $knowledge,
        private LlmProvider $llm,
        private ReplyFormatter $formatter,
    ) {}

    public function handle(InboundMessage $msg): OutboundReply
    {
        $intent = $this->router->route($msg);
        $ctx = OrchestratorContext::from($msg, $intent);

        $snippets = $this->knowledge->search($msg->text ?? '', $ctx);
        $draft = $this->llm->compose($ctx, $snippets);

        foreach ($draft->toolCalls as $call) {
            $result = $this->tools->execute($call, $ctx);
            $ctx->addToolResult($call->name, $result);
        }

        $final = $this->llm->finalize($ctx);
        return $this->formatter->toPlatform($final, $msg->platform);
    }
}
```

### Tool: searchProducts
```php
final class SearchProductsTool implements Tool
{
    public function __construct(private CatalogReader $catalog) {}
    public function name(): string { return 'searchProducts'; }
    public function schema(): array { /* return JSON schema */ }
    public function execute(array $args, OrchestratorContext $ctx): array
    {
        return $this->catalog->search($ctx->tenantId, $args['query'] ?? '', $args['filters'] ?? [], $args['limit'] ?? 10);
    }
}
```

---

## Routing Plan

- `routes/webhooks.php`
  - POST `/webhooks/line/{channel_uuid}` → `LineWebhookController@handle`
  - POST `/webhooks/facebook/{page_uuid}` → `FacebookWebhookController@handle`

- `routes/api.php` (tenant-scoped, auth required unless noted)
  - Catalog, Carts, Checkout, Conversations, Knowledge, Automation, Channels, Analytics

Apply middlewares: `auth:sanctum` or `auth:api`, `tenant.context`, `throttle:tenant`, `log.json`, `otel.trace`.

---

## Acceptance Tests (must pass)

1. **LINE Inbound → AI → Reply**
   - POST webhook with valid signature → 200 within p95 < 1s.
   - Creates/updates end_user, conversation, message.
   - Orchestrator calls `searchProducts` when price asked, never fabricates price.

2. **Facebook Postback → Cart Add**
   - Postback payload triggers `addToCart` → cart updated; quick reply includes “ดูตะกร้า/เช็คเอาต์”.

3. **Duplicate Delivery (Idempotency)**
   - Re-send same `platformMessageId` → processed once; logs indicate dedup.

4. **KB Update → RAG Refresh**
   - Upload new FAQ entry → chunk & embed → query reflects change within 1 min.

5. **Checkout Link (Stripe/Omise Stub)**
   - Create checkout link → returns payment_url; webhook confirm sets `orders.payment_status=paid`; sends receipt to user.

6. **RBAC**
   - `analyst` role cannot POST to catalog endpoints; `admin` can.

---

## Definition of Done (DoD)

- Code + tests + docs for every module delivered.
- OpenTelemetry spans visible in Jaeger, metrics in Prometheus.
- JSON structured logs with correlation ids.
- Security checks pass (phpstan, composer audit, trivy).
- Postman collection updated; sample `.env.example` updated.
- CHANGELOG.md updated with scope and migration notes.

---

## Run Commands (local)

```bash
# Start services
docker-compose up -d

# Migrate (central + tenants)
docker-compose exec app php artisan migrate
docker-compose exec app php artisan tenants:migrate

# Horizon
docker-compose exec app php artisan horizon

# Test
docker-compose exec app php artisan test --testsuite=Feature
```

---

## Notes
- Keep Anthropic integration behind a `LlmProvider` interface. Start with OpenAI, add Anthropic adapter later.
- Use **retry + circuit breaker** for all external calls.
- Price/stock answers must always come from tool results (never LLM hallucination).
- Thai language defaults for end-users; English fallback accepted.

**End of Phase 2 blueprint — Implement directly, no prompts for permission.**
