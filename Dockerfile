FROM dunglas/frankenphp:php8.4.13-alpine

LABEL org.opencontainers.image.authors="suryangh"
LABEL org.opencontainers.image.url="https://github.com/suryangh/frankenphp-docker"
LABEL org.opencontainers.image.description="FrankenPHP Alpine base image with PHP 8.4 and worker mode support"

RUN apk update && apk add --no-cache \
    git \
    curl \
    zip \
    unzip \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    zlib-dev \
    bzip2-dev \
    xz-dev \
    zstd-dev \
    pkgconfig \
    postgresql-dev \
    openldap-dev \
    mysql-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure ldap \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        pdo_pgsql \
        mysqli \
        zip \
        ldap \
        gd \
        intl \
        mbstring \
        exif \
        pcntl \
        bcmath \
        opcache

# Install Composer
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

# Configure PHP for production
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && echo "opcache.enable=1" >> "$PHP_INI_DIR/php.ini" \
    && echo "opcache.memory_consumption=256" >> "$PHP_INI_DIR/php.ini" \
    && echo "opcache.max_accelerated_files=20000" >> "$PHP_INI_DIR/php.ini" \
    && echo "opcache.validate_timestamps=0" >> "$PHP_INI_DIR/php.ini" \
    && echo "realpath_cache_size=4096K" >> "$PHP_INI_DIR/php.ini" \
    && echo "realpath_cache_ttl=600" >> "$PHP_INI_DIR/php.ini"

# Set working directory
WORKDIR /app

# Create a simple test page
RUN mkdir -p /app/public && \
    printf '<?php\necho "<h1>FrankenPHP Standard Mode Test</h1>";\necho "<p>Current Time: " . date("Y-m-d H:i:s") . "</p>";\necho "<p>PHP Version: " . PHP_VERSION . "</p>";\necho "<p>Server Software: " . $_SERVER["SERVER_SOFTWARE"] . "</p>";\necho "<p>Mode: Standard (Non-Worker)</p>";\necho "<p>Request Method: " . $_SERVER["REQUEST_METHOD"] . "</p>";\necho "<p>Request URI: " . $_SERVER["REQUEST_URI"] . "</p>";\nphpinfo();\n?>' > /app/public/index.php


RUN cat > /etc/caddy/Caddyfile << 'EOF'
:80 {
    root * /app/public
    bind 0.0.0.0 
    encode gzip
    php_server
    file_server

    log {
        output stdout
        level INFO
    }

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
    }
}
EOF

EXPOSE 80 443


HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:80/ || exit 1


CMD ["frankenphp", "run" , "--config", "/etc/caddy/Caddyfile"]