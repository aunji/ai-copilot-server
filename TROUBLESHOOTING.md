# Troubleshooting (Local)

## Login fails
- Ensure DemoDataSeeder ran
- Check Sanctum CORS config (allow http://localhost:5173)
- Inspect `docker compose logs -f app`

## 401 after login
- Confirm Authorization header: `Bearer <token>`
- If running behind proxy, ensure `APP_URL` and `SANCTUM_STATEFUL_DOMAINS` are correct

## CORS blocked
- Set `CORS_ALLOWED_ORIGINS=http://localhost:5173`
- Verify Laravel CORS middleware is enabled

## DB migrations fail
- Check db container env matches `.env`
- `docker compose exec db mysql -u root -p` and verify database exists
