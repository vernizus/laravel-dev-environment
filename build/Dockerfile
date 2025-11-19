# ----------------------------------------------
# STAGE 1: Get the Composer binary
# ----------------------------------------------
FROM composer:2.7 as composer_installer

# ----------------------------------------------
# STAGE 2: Final Image (PHP-CLI Base with apt-get)
# ----------------------------------------------
FROM php:8.3-cli

COPY --from=composer_installer /usr/bin/composer /usr/local/bin/composer

# 1. Install necessary system dependencies

RUN apt-get update && apt-get install -y \
    git \
    libzip-dev \
    libonig-dev \
    unzip \
    --no-install-recommends && rm -rf /var/lib/apt/lists/*

# 2. Install PHP extensions (only the necessary ones)
RUN docker-php-ext-install pdo_mysql mbstring zip

# 3. Working directory: CHANGED TO /var/www/html!
WORKDIR /var/www/html

# 4. Copy and prepare the startup script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 5. Define the Entry Point and Command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# The CMD starts the Laravel development server
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
