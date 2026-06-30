#!/bin/bash
set -e # Interrompe l'esecuzione in caso di errore

CONFIG_PATH="/opt/iartnet_edge/proxy/conf.d/default.conf"
BACKUP_PATH="/opt/iartnet_edge/proxy/conf.d/default.conf.bak-$(date +%s)"

echo "Creazione backup in $BACKUP_PATH..."
cp "$CONFIG_PATH" "$BACKUP_PATH"

echo "Scrittura nuova configurazione Nginx..."
cat << 'EOF' > "$CONFIG_PATH"
# ==========================================
# HTTP CATCH-ALL & ACME CHALLENGE (Porta 80)
# ==========================================
server {
    listen 80;
    server_name iartnet.gpams.it iiif.gpams.it ingestion.gpams.it cms.gpams.it;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
        try_files $uri =404;
    }

    location / {
        proxy_buffer_size          128k;
        proxy_buffers              4 256k;
        proxy_busy_buffers_size    256k;
        return 301 https://$host$request_uri;
    }
}

# ==========================================
# FRONTEND NUXT (iartnet.gpams.it)
# ==========================================
server {
    listen 443 ssl;
    server_name iartnet.gpams.it;

    ssl_certificate /etc/letsencrypt/live/iartnet.gpams.it/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/iartnet.gpams.it/privkey.pem;

    location / {
        resolver 127.0.0.11 valid=10s;
        set $frontend_upstream http://iartnet_frontend:3000;
        
        proxy_buffer_size          128k;
        proxy_buffers              4 256k;
        proxy_busy_buffers_size    256k;
        proxy_pass $frontend_upstream;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# ==========================================
# API LARAVEL (ingestion.gpams.it)
# ==========================================
server {
    listen 443 ssl;
    server_name ingestion.gpams.it;

    ssl_certificate /etc/letsencrypt/live/iartnet.gpams.it/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/iartnet.gpams.it/privkey.pem;

    # Bypass Laravel Welcome Page -> Redirect a Filament Admin
    location = / {
        return 301 https://$host/admin;
    }

    location / {
        resolver 127.0.0.11 valid=10s;
        set $api_upstream http://iartnet_api_nginx:80;
        
        proxy_buffer_size          128k;
        proxy_buffers              4 256k;
        proxy_busy_buffers_size    256k;
        proxy_pass $api_upstream;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# ==========================================
# CMS FILAMENT (cms.gpams.it)
# ==========================================
server {
    listen 443 ssl;
    server_name cms.gpams.it;

    ssl_certificate /etc/letsencrypt/live/iartnet.gpams.it/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/iartnet.gpams.it/privkey.pem;

    location ^~ /storage/ {
        if ($request_method = OPTIONS) {
            add_header 'Access-Control-Allow-Origin' 'https://iartnet.gpams.it' always;
            add_header 'Access-Control-Allow-Methods' 'GET, HEAD, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
            add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range,Accept-Ranges' always;
            add_header 'Access-Control-Max-Age' 1728000 always;
            add_header 'Content-Type' 'text/plain; charset=utf-8' always;
            add_header 'Content-Length' 0 always;
            return 204;
        }
    
        add_header 'Access-Control-Allow-Origin' 'https://iartnet.gpams.it' always;
        add_header 'Access-Control-Allow-Methods' 'GET, HEAD, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
        add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range,Accept-Ranges' always;
        add_header 'Vary' 'Origin' always;
    
        proxy_pass http://iartnetcms_nginx:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }



    location / {
        resolver 127.0.0.11 valid=10s;
        set $cms_upstream http://iartnetcms_nginx:80;
        
        proxy_buffer_size          128k;
        proxy_buffers              4 256k;
        proxy_busy_buffers_size    256k;
        proxy_pass $cms_upstream;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# ==========================================
# SERVER IIIF (iiif.gpams.it)
# ==========================================
server {
    listen 443 ssl;
    server_name iiif.gpams.it;

    ssl_certificate /etc/letsencrypt/live/iartnet.gpams.it/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/iartnet.gpams.it/privkey.pem;

    location / {
        resolver 127.0.0.11 valid=10s;
        set $iiif_upstream http://iartnet_iiif:8182;
        
        proxy_buffer_size          128k;
        proxy_buffers              4 256k;
        proxy_busy_buffers_size    256k;
        
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
        add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;

        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }

        proxy_pass $iiif_upstream;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

echo "Avvio cicli di validazione Nginx..."

# Ciclo 1: Validazione strutturale
docker exec iartnet_reverse_proxy nginx -t
if [ $? -ne 0 ]; then
    echo "ERRORE FATALE: Sintassi non valida. Ripristino backup..."
    cp "$BACKUP_PATH" "$CONFIG_PATH"
    exit 1
fi
echo "[OK] Sintassi Nginx valida."

# Ciclo 2: Reload a caldo
docker exec iartnet_reverse_proxy nginx -s reload
sleep 2
echo "[OK] Reload eseguito."

# Ciclo 3: Test del redirect su Ingestion
HTTP_CODE=$(docker exec iartnet_reverse_proxy curl -k -s -o /dev/null -w "%{http_code}" -H "Host: ingestion.gpams.it" https://127.0.0.1/)
if [ "$HTTP_CODE" -eq "301" ]; then
    echo "VALIDAZIONE SUPERATA: Redirect 301 attivo su ingestion.gpams.it"
else
    echo "ANOMALIA: Ingestion ha restituito $HTTP_CODE"
fi
