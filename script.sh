#!/bin/bash

# Actualizare și instalare pachete necesare
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y nginx openssl

# Pornire și activare Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Generare certificat SSL auto-semnat
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/nginx_selfsigned.key \
  -out /etc/ssl/certs/nginx_selfsigned.crt \
  -subj "/C=RO/ST=Bucuresti/L=Bucuresti/O=CompaniaMea/CN=$(hostname -I | awk '{print $1}')"

# Generare parametru Diffie-Hellman pentru securitate suplimentară
sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

# Configurare fișier SSL Nginx
sudo bash -c 'cat > /etc/nginx/snippets/self-signed.conf <<EOF
ssl_certificate /etc/ssl/certs/nginx_selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx_selfsigned.key;
EOF'

# Configurare parametri SSL
sudo bash -c 'cat > /etc/nginx/snippets/ssl-params.conf <<EOF
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/ssl/certs/dhparam.pem;
ssl_ciphers HIGH:!aNULL:!MD5;
ssl_ecdh_curve secp384r1;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
EOF'

# Configurare Nginx pentru redirecționare automată a HTTP la HTTPS
sudo bash -c 'cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 443 ssl;
    listen [::]:443 ssl;

    include snippets/self-signed.conf;
    include snippets/ssl-params.conf;

    server_name 89.33.44.227;

    # Proxy pentru cererile de HTTPS către aplicație
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    # Redirecționează cererile HTTP la HTTPS pentru resursele statice
    location /ui-static/ {
        proxy_pass https://localhost:8080/ui-static/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

server {
    listen 80;
    listen [::]:80;
    server_name 89.33.44.227;

    return 301 https://\$host\$request_uri;  # Redirecționează HTTP la HTTPS pentru toate cererile
}
EOF'

# Verificare configurație și repornire Nginx
sudo nginx -t
sudo systemctl restart nginx

echo "Nginx a fost instalat și configurat cu succes cu SSL auto-semnat pe portul 443!"
