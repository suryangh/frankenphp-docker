FROM dunglas/frankenphp:1-php8.4-alpine

LABEL org.opencontainers.image.authors="suryangh"
LABEL org.opencontainers.image.url="https://github.com/suryangh/frankenphp-docker"
LABEL org.opencontainers.image.description="FrankenPHP Alpine base image with PHP 8.4 and worker mode support"

# Install system dependencies and PHP extensions commonly needed
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
    mysql-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        pdo_pgsql \
        mysqli \
        zip \
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

# Create Caddyfile for FrankenPHP with worker mode
RUN echo ':80 {\n\
    root * /app/public\n\
    \n\
    # Enable FrankenPHP worker mode\n\
    php_server {\n\
        workers 4\n\
    }\n\
    \n\
    # Handle PHP files\n\
    php_fastcgi\n\
    \n\
    # Handle static files\n\
    file_server\n\
    \n\
    # Optional: Enable compression\n\
    encode gzip\n\
    \n\
    # Security headers\n\
    header {\n\
        X-Content-Type-Options nosniff\n\
        X-Frame-Options DENY\n\
        X-XSS-Protection "1; mode=block"\n\
    }\n\
}' > /etc/caddy/Caddyfile

# Set working directory
WORKDIR /app

# Create user and set permissions (you can modify this at runtime)
RUN addgroup -g 1000 appuser \
    && adduser -D -s /bin/sh -u 1000 -G appuser appuser \
    && chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 80 443

# Set environment variables for FrankenPHP worker mode
ENV FRANKENPHP_CONFIG="worker ./public/index.php"
ENV SERVER_NAME=":80"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Start FrankenPHP
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]