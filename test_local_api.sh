#!/usr/bin/env bash
set -euo pipefail

API_BASE="${API_BASE:-http://localhost:8080/api}"
COMPANY="${COMPANY:-demo-store}"
EMAIL="${EMAIL:-admin@demo.com}"
PASSWORD="${PASSWORD:-password}"

echo "==> Login ..."
TOKEN=$(curl -s -X POST "$API_BASE/auth/login"   -H "Content-Type: application/json"   -d "{"company":"$COMPANY","email":"$EMAIL","password":"$PASSWORD"}"   | jq -r '.token // empty')

if [ -z "$TOKEN" ]; then
  echo "Login failed"; exit 1
fi
echo "OK token acquired"

auth() { curl -s -H "Authorization: Bearer $TOKEN" "$@"; }

echo "==> Products list"
auth "$API_BASE/$COMPANY/products" | jq '.[0] // .items // .'

echo "==> Adjust stock (+5) product_id=1"
curl -s -X POST "$API_BASE/$COMPANY/stock/adjust"   -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json"   -d '{"product_id":1,"qty_delta":5,"ref_type":"ADJUSTMENT","notes":"script test"}' | jq '.'

echo "==> Create SO draft"
SO=$(curl -s -X POST "$API_BASE/$COMPANY/sale-orders"   -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json"   -d '{"customer_id":1,"payment_method":"transfer","items":[{"product_id":1,"qty":1,"unit_price":120}]}' | jq -r '.tx_id // .data.tx_id')
echo "tx_id=$SO"

echo "==> Confirm SO"
curl -s -X POST "$API_BASE/$COMPANY/sale-orders/$SO/confirm"   -H "Authorization: Bearer $TOKEN" | jq '.'

echo "==> Reports daily"
auth "$API_BASE/$COMPANY/reports/sales-daily" | jq '.'

echo "Done."
