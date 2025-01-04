FROM alpine:3.21
LABEL Maintainer="Mathieu LESNIAK <mathieu@lesniak.fr>"\
    Description="Lightweight container with Nginx 1.26.2 & PHP-FPM 8.4 based on Alpine Linux. Full locales enabled"

ENV MUSL_LOCPATH="/usr/share/i18n/locales/musl"

RUN apk update && \
    apk add bash less geoip nginx nginx-mod-http-headers-more nginx-mod-http-geoip nginx-mod-stream nginx-mod-stream-geoip ca-certificates git tzdata zip \
    zlib-dev gmp-dev freetype-dev libjpeg-turbo-dev libpng-dev curl icu-data-full \
    php84-common php84-fpm php84-json php84-zlib php84-xml php84-xmlwriter php84-pdo php84-phar php84-openssl php84-fileinfo php84-pecl-imagick \
    php84-pdo_mysql php84-mysqli php84-sqlite3 php84-pdo_sqlite php84-session \
    php84-gd php84-iconv php84-gmp php84-zip \
    php84-curl php84-opcache php84-ctype php84-pecl-apcu php84-pecl-memcached php84-pecl-redis php84-pecl-yaml php84-exif \
    php84-intl php84-bcmath php84-dom php84-mbstring php84-simplexml php84-soap php84-tokenizer php84-xmlreader php84-xmlwriter php84-posix php84-pcntl php84-ftp php84-imap && \
    apk add -u musl && \
    apk add msmtp && \
    apk add musl-locales musl-locales-lang && cd "$MUSL_LOCPATH" \
    && for i in *.UTF-8; do cp -a "$i" "${i%%.UTF-8}"; done && \
    mkdir /etc/nginx/server-override && \
    rm -rf /var/cache/apk/*

RUN { \
    echo '[mail function]'; \
    echo 'sendmail_path = "/usr/bin/msmtp -t"'; \
    } > /etc/php84/conf.d/msmtp.ini

# opcode recommended settings
RUN { \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=64'; \
    echo 'opcache.max_accelerated_files=25000'; \
    echo 'opcache.revalidate_path=0'; \
    echo 'opcache.enable_file_override=1'; \
    echo 'opcache.max_file_size=0'; \
    echo 'opcache.max_wasted_percentage=5;' \
    echo 'opcache.revalidate_freq=120'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=0'; \ 
    echo 'opcache.jit_buffer_size=64M'; \
    echo 'opcache.jit=tracing';\ 
    } > /etc/php84/conf.d/opcache-recommended.ini

# limits settings
RUN { \
    echo 'memory_limit=256M'; \
    echo 'upload_max_filesize=128M'; \
    echo 'max_input_vars=5000'; \
    echo "date.timezone='Europe/Paris'"; \
    } > /etc/php84/conf.d/limits.ini

RUN sed -i "s/nginx:x:100:101:nginx:\/var\/lib\/nginx:\/sbin\/nologin/nginx:x:100:101:nginx:\/usr:\/bin\/bash/g" /etc/passwd && \
    sed -i "s/nginx:x:100:101:nginx:\/var\/lib\/nginx:\/sbin\/nologin/nginx:x:100:101:nginx:\/usr:\/bin\/bash/g" /etc/passwd- && \
    ln -s /sbin/php-fpm84 /sbin/php-fpm && \
    ln -s /usr/bin/php84 /usr/bin/php

# Composer
RUN cd /tmp/ && \
    curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    composer self-update

ADD php-fpm.conf /etc/php84/
ADD nginx-site.conf /etc/nginx/nginx.conf

ADD entrypoint.sh /etc/entrypoint.sh
ADD ownership.sh /
RUN mkdir -p /var/www/public
COPY --chown=nobody src/ /var/www/public/


WORKDIR /var/www/
EXPOSE 80

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=3s CMD curl --silent --fail http://127.0.0.1:80/fpm-ping

ENTRYPOINT ["sh", "/etc/entrypoint.sh"]

