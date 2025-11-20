# ----------------------------------------------
# STAGE 1: Get the Composer binary
# ----------------------------------------------
FROM composer:2.7 AS composer_installer

# ----------------------------------------------
# STAGE 2: Final Image
# ----------------------------------------------
FROM php:8.3-cli

LABEL maintainer="Alejandro Fernandes (Vernizus Luna)"
LABEL email="alejandro.fernandes@vernizusluna.com"
LABEL github="https://github.com/vernizus"
LABEL linkedin="https://www.linkedin.com/in/gabriel-fernandes-998b64320"
LABEL description="Laravel development environment with Composer and PHP 8.3 CLI"

COPY --from=composer_installer /usr/bin/composer /usr/local/bin/composer

# 1. Install necessary system dependencies

RUN apt-get update && apt-get install -y \
    git \
    libzip-dev \
    libonig-dev \
    unzip \
    --no-install-recommends && rm -rf /var/lib/apt/lists/*

# 2. Install PHP extensions
RUN docker-php-ext-install pdo_mysql mbstring zip

# 3. Working directory
WORKDIR /var/www/html

# 4. Copy and prepare the startup script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 5. Define the Entry Point and Command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# The CMD starts the Laravel development server
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
