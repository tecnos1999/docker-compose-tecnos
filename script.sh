#!/bin/bash

apt update -y
apt upgrade -y

apt install -y nginx openssl

systemctl start nginx
systemctl enable nginx

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/nginx_selfsigned.key \
  -out /etc/ssl/certs/nginx_selfsigned.crt \
  -subj "/C=RO/ST=Bucuresti/L=Bucuresti/O=CompaniaMea/CN=$(hostname -I | awk '{print $1}')"

openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

cat > /etc/nginx/snippets/self-signed.conf <<EOF
ssl_certificate /etc/ssl/certs/nginx_selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx_selfsigned.key;
EOF

cat > /etc/nginx/snippets/ssl-params.conf <<EOF
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/ssl/certs/dhparam.pem;
ssl_ciphers HIGH:!aNULL:!MD5;
ssl_ecdh_curve secp384r1;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
EOF

cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 443 ssl;
    listen [::]:443 ssl;

    include snippets/self-signed.conf;
    include snippets/ssl-params.conf;

    server_name 84.46.241.251;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    listen [::]:80;
    server_name 84.46.241.251;

    return 301 https://\$host\$request_uri;
}
EOF

nginx -t
systemctl restart nginx

echo "Nginx a fost instalat și configurat cu succes cu SSL auto-semnat!"