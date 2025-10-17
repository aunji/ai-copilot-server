# FlexStock Deployment Notes (DirectAdmin & Caddy)

## A) DirectAdmin (Frontend)
1. Build frontend:
   ```bash
   cd /home/aunji/ai-copilot-server/flexstock-frontend
   VITE_API_URL=https://yourdomain.com/api npm run build
   ```
2. Upload `dist/` into `public_html/`
3. Create `.htaccess` in `public_html/`
   ```
   <IfModule mod_rewrite.c>
     RewriteEngine On
     RewriteBase /
     RewriteRule ^index\.html$ - [L]
     RewriteCond %{REQUEST_FILENAME} !-f
     RewriteCond %{REQUEST_FILENAME} !-d
     RewriteRule . /index.html [L]
   </IfModule>
   ```

## B) Backend (Laravel) behind Caddy
`/etc/caddy/Caddyfile`:
```
flexstock.zentrydev.com {
  encode zstd gzip
  tls you@domain.com
  @api path /api/*

  handle @api {
    reverse_proxy 127.0.0.1:8080
  }
  handle {
    root * /var/www/flexstock-frontend/dist
    try_files {path} /index.html
    file_server
  }
}
```

Reload:
```bash
sudo systemctl reload caddy
```

## C) Environment
- Frontend: set `VITE_API_URL` to `https://flexstock.zentrydev.com/api`
- Backend: set `APP_URL` accordingly, update CORS allowed origins
