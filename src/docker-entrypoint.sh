#!/bin/sh
set -e

CONFIG=/var/www/msmtp/msmtprc

if [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASSWORD" ]; then
    umask 077
    cat > "$CONFIG" <<EOF
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile -

account gmail
host smtp.gmail.com
port 587
from ${SMTP_FROM:-$SMTP_USER}
user $SMTP_USER
password $SMTP_PASSWORD

account default : gmail
EOF
else
    echo "docker-entrypoint: SMTP_USER/SMTP_PASSWORD not set — mail() will fail silently, as before." >&2
fi

exec "$@"
