# FlexStock System Status — 2025-10-17T13:01:39

## Overview
- **Backend (Laravel 11, Docker)**: http://localhost:8080/api
- **Frontend (React + Vite + TS)**: http://localhost:5173
- **phpMyAdmin**: http://localhost:8081
- **MySQL**: localhost:3306
- **Tenant (slug)**: `demo-store`

## Auth (Demo)
- `admin@demo.com` / `password`
- `cashier@demo.com` / `password`

## Running Services
```bash
docker compose ps
docker compose logs -f app
docker compose logs -f db
```
Frontend (dev):
```bash
cd /home/aunji/ai-copilot-server/flexstock-frontend
npm run dev
```

## API Endpoints (tenant-scoped)
Base: `http://localhost:8080/api/{company}` (e.g. `{company} = demo-store`)

- `POST /auth/login` (body: `{ "company":"demo-store","email":"...","password":"..." }`) → token
- `GET  /{company}/products`
- `POST /{company}/stock/adjust`
- `POST /{company}/sale-orders`
- `POST /{company}/sale-orders/{tx}/confirm`
- `POST /{company}/sale-orders/{tx}/approve-payment`
- `GET  /{company}/reports/sales-daily`
- `GET  /{company}/reports/top-products`
- `GET  /{company}/reports/low-stock`

## Quick Health Checks
```bash
curl -s http://localhost:8080/api/health || echo "health endpoint not implemented"
curl -s http://localhost:5173 | head -n 5
docker compose exec app php -v
docker compose exec app php artisan --version
```

## Common Paths
```
/home/aunji/ai-copilot-server/flexstock            # backend
/home/aunji/ai-copilot-server/flexstock-frontend  # frontend
```

## Notes
- Make sure CORS on Backend allows http://localhost:5173 in local.
- For production: set VITE_API_URL to the public API base and build the frontend.
