#!/bin/sh
set -e

CONFIG=/var/www/msmtp/msmtprc

if [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASSWORD" ]; then
    # Subshell so the restrictive umask doesn't leak into nginx/php-fpm.
    (umask 077; cat > "$CONFIG") <<EOT
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
EOT
else
    echo "docker-entrypoint: SMTP_USER/SMTP_PASSWORD not set - mail() will fail silently." >&2
fi
unset SMTP_PASSWORD

# Run both daemons in the foreground and supervise them: if either one dies
# the container exits (so the orchestrator restarts it) instead of nginx
# carrying on with a dead php-fpm behind it. TERM/INT are forwarded so
# `docker stop` shuts both down cleanly.
php-fpm -F &
FPM=$!
nginx -g 'daemon off;' &
NGINX=$!

trap 'kill -TERM "$FPM" "$NGINX" 2>/dev/null; wait; exit 0' TERM INT

while kill -0 "$FPM" 2>/dev/null && kill -0 "$NGINX" 2>/dev/null; do
    sleep 2 &
    wait $!
done

echo "docker-entrypoint: php-fpm or nginx exited - shutting down." >&2
kill -TERM "$FPM" "$NGINX" 2>/dev/null || true
wait
exit 1
