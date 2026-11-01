# Build stage: compile the Astro site to static HTML, then render the CV
# page to a PDF with Chromium (installed here only, not shipped in the final
# image).
FROM node:24-alpine AS build

# Pinned Alpine package versions leave the current apk index on the next
# base image update and break the build; apk add --no-cache already pulls
# whatever is current and current gets rebuilt on every push anyway.
# hadolint ignore=DL3018
RUN apk add --no-cache chromium
ENV CHROMIUM_PATH=/usr/bin/chromium-browser

WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci

COPY astro.config.mjs tsconfig.json ./
COPY public ./public
COPY src ./src
COPY scripts ./scripts

RUN npm run build && npm run pdf

# Serve stage: nginx serves the static Astro output; php-fpm handles just
# /contact.php (mail() -> msmtp -> Gmail SMTP, same relay the original PHP
# site used, same app password).
FROM php:8.5-fpm-alpine AS serve

# hadolint ignore=DL3018
RUN apk upgrade --no-cache && apk add --no-cache nginx msmtp

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && echo 'sendmail_path = "/usr/bin/msmtp -C /var/www/msmtp/msmtprc -t"' \
       > /usr/local/etc/php/conf.d/msmtp.ini \
    && mkdir -p /var/www/msmtp /var/www/ratelimit \
    && chown www-data:www-data /var/www/msmtp /var/www/ratelimit

# nginx's main config is replaced (see docker/nginx.main.conf) so everything
# can run as www-data. Alpine includes http.d/*.conf inside the http{} block,
# which is where our server block goes.
COPY docker/nginx.main.conf /etc/nginx/nginx.conf
COPY docker/php-fpm-listen.conf /usr/local/etc/php-fpm.d/zzz-listen.conf
COPY nginx.conf /etc/nginx/http.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
COPY php/contact.php /usr/share/nginx/html/contact.php
COPY php/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# 82 = www-data in the php alpine image (hadolint wants a numeric uid).
USER 82
EXPOSE 8080

# The php base image sets STOPSIGNAL SIGQUIT; the entrypoint supervises both
# daemons and traps TERM, so `docker stop` must send that instead.
STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/"]

ENTRYPOINT ["docker-entrypoint.sh"]
