FROM php:8.2-apache

# ctype/iconv ship built into php:apache already; mbstring/xml need libonig/libxml.
# msmtp is contact-form mail()'s MTA, relaying via Gmail SMTP (see docker-entrypoint.sh).
RUN apt-get update \
    && apt-get install -y --no-install-recommends libonig-dev libxml2-dev msmtp \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install -j "$(nproc)" mbstring xml

# Run on 8080 (unprivileged) instead of the default 80, and as www-data
# instead of root, so the image doesn't need root to bind its port.
RUN sed -ri 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
    && sed -ri 's/:80>/:8080>/' /etc/apache2/sites-available/000-default.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

# mail() -> msmtp, using the per-container config docker-entrypoint.sh writes
# from SMTP_USER/SMTP_PASSWORD at startup (kept out of the image itself).
RUN echo 'sendmail_path = "/usr/bin/msmtp -C /var/www/msmtp/msmtprc -t"' \
    > /usr/local/etc/php/conf.d/msmtp.ini \
    && mkdir -p /var/www/msmtp && chown www-data:www-data /var/www/msmtp

COPY --chown=www-data:www-data . /var/www/html/
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN rm -f /var/www/html/Dockerfile /var/www/html/.dockerignore /var/www/html/docker-entrypoint.sh \
    && find /var/www/html -name '*.bak' -delete \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

USER www-data
EXPOSE 8080

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
