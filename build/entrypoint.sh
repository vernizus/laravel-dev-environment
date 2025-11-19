#!/bin/bash

# This script runs as the ENTRYPOINT of the Laravel container.
# It is responsible for:
# 1. Creating the project in a subfolder if it doesn't exist.
# 2. Installing dependencies if the 'vendor' folder is missing.
# 3. Ensuring the application key and clearing the cache.

# Set the default name proyect
PROJECT_NAME="default"
# The final path of the project inside the container will be /var/www/html/default
PROJECT_PATH="/var/www/html/$PROJECT_NAME"

# Base directory of the volume
BASE_DIR="/var/www/html"

# Enter the base directory where the project will be created
cd $BASE_DIR

# --- 1. Project Verification and Creation (First Boot) ---

if [ ! -f "$PROJECT_PATH/artisan" ]; then
    echo "🏗️  Project '$PROJECT_NAME' not found. Creating Laravel application..."
    
    # Create the project in the subfolder
    composer create-project --prefer-dist laravel/laravel $PROJECT_NAME
    
    # Enter the project for initial setup
    cd $PROJECT_NAME
    
    # Generate the application key
    php artisan key:generate
    
    echo "✅ Project '$PROJECT_NAME' created and configured."
    
else
    echo "➡️ Project '$PROJECT_NAME' already exists. Checking dependencies."
    # Enter the project
    cd $PROJECT_NAME
    
    # --- 2. Vendor Verification and Installation (Subsequent Boots) ---
    if [ ! -d "vendor" ]; then
        echo "⚠️ 'vendor' folder missing. Running optimized composer install..."
        # Use optimization flags for containers
        composer install --no-dev --optimize-autoloader
    fi

fi

# --- 3. Final Configuration Tasks (Always necessary) ---

echo "⚙️ Configuring permissions and clearing cache..."

# Set CRITICAL permissions for storage and cache
# Note: The path is relative to the current folder (which is $PROJECT_PATH)
chmod -R 775 storage bootstrap/cache

# CRITICAL cleanup on startup to avoid using old cached configuration
php artisan config:clear

# --- 4. Start the Server ---
# The main command (CMD) runs now, e.g., 'php artisan serve...'
exec "$@"
