#!/bin/bash

# GLOBAL VARIABLES
PROJECT_NAME="default" 
CONTAINER_NAME="default_app"
BASE_DIR="/var/www/html"
# Default Laravel port (8000). Overridden by explicit flags.
SERVER_PORT="8000" 
PROJECT_PATH="$BASE_DIR/$PROJECT_NAME"

# --- Helper Functions ---

# Function to update global context variables
update_project_context() {
    local NEW_NAME=$1
    PROJECT_NAME="$NEW_NAME"
    PROJECT_PATH="$BASE_DIR/$PROJECT_NAME"
    echo "🎯 Context switched to project: $PROJECT_NAME"
}

# Function to execute artisan commands inside the container
execute_artisan() {
    docker exec -w $PROJECT_PATH $CONTAINER_NAME php artisan "$@"
}

# Function to execute composer
execute_composer() {
    docker exec -w $PROJECT_PATH $CONTAINER_NAME composer "$@"
}


# --- NEW: GIT CLONE & SYNC FUNCTION ---
########################################

git_clone_setup() {
    local USER_REPO=$1 # e.g., 'vernizus/vernizus_app'
    local REPO_URL="git@github.com:${USER_REPO}.git"
    
    # CRITICAL: Get absolute HOST path (e.g., /home/user/...)
    local HOST_PROJECT_DIR="$PWD" 
    
    if [ -z "$USER_REPO" ]; then
        echo "❌ Error: You must specify the user/repository to clone."
        echo "Example: $0 --clone user/repository"
        exit 1
    fi

    echo "---------------------------------------------------------"
    echo "🌐 Starting Git clone and synchronization process"
    echo "---------------------------------------------------------"
    
    # 1. Run 'git init' if the repo is not initialized yet
    if [ ! -d ".git" ]; then
        echo "📦 Initializing local Git repository..."
        git init
    fi
    
    # 2. Configure remote origin
    if ! git remote show origin 2>/dev/null | grep -q 'Fetch URL:'; then
        echo "🔗 Adding remote 'origin': $REPO_URL"
        git remote add origin "$REPO_URL"
    else
        echo "🔗 Remote 'origin' already exists. Updating URL..."
        git remote set-url origin "$REPO_URL"
    fi

    # 3. Fix 'dubious ownership' errors
    echo "🛡️ Setting directory as a safe Git directory: $HOST_PROJECT_DIR"
    git config --global --add safe.directory "$HOST_PROJECT_DIR"

    # 4. Fix permission issues caused by Docker volumes
    echo "🔑 Resetting ownership of all files to $USER..."
    sudo chown -R $USER:$USER .

    # 5. Clean untracked files (remove boilerplate from default Laravel)
    echo "🧹 Cleaning untracked files and directories (git clean -fd)..."
    git clean -fd
    
    # 6. Pull from main or master
    echo "📥 Executing git pull origin main..."
    git pull origin main || git pull origin master

    if [ $? -eq 0 ]; then
        echo "---------------------------------------------------------"
        echo "✅ Synchronization completed. Code is up to date."
        echo "---------------------------------------------------------"
        
        # 7. Run composer install inside the container
        echo "📦 Running composer install inside the container..."
        execute_composer install
        
    else
        echo "❌ Error: 'git pull' could not be completed. Check SSH keys or branch name."
    fi
}

########################################
# --- END GIT CLONE & SYNC FUNCTION ---

# New function to create a new Laravel project 
create_new_project() {
    local NEW_PROJECT_NAME=$1
    local NEW_PROJECT_PATH="$BASE_DIR/$NEW_PROJECT_NAME"

    if [ -z "$NEW_PROJECT_NAME" ]; then
        echo "❌ Error: You must specify the name of the new project."
        echo "Example: $0 --new my_new_app"
        exit 1
    fi

    echo "🏗️  Creating new Laravel project: '$NEW_PROJECT_NAME'..."

    docker exec -w $BASE_DIR $CONTAINER_NAME composer create-project --prefer-dist laravel/laravel "$NEW_PROJECT_NAME"

    if [ $? -eq 0 ]; then
        echo "✅ Project created at: ./$NEW_PROJECT_NAME (on your host)"
        echo "🔑 Generating application key..."
        docker exec -w "$NEW_PROJECT_PATH" $CONTAINER_NAME php artisan key:generate
        echo "⚙️  Configuring permissions..."
        docker exec -w "$NEW_PROJECT_PATH" $CONTAINER_NAME chown -R www-data:www-data storage bootstrap/cache
        docker exec -w "$NEW_PROJECT_PATH" $CONTAINER_NAME chmod -R 775 storage bootstrap/cache
        echo "🎉 The project '$NEW_PROJECT_NAME' is ready!"
    else
        echo "❌ Error creating the project."
    fi
}

# Function to start the development server in the background
run_dev_server() {
    echo "🌐 Starting the development server for '$PROJECT_NAME' on port $SERVER_PORT (background)..."
    
    docker exec -w $PROJECT_PATH $CONTAINER_NAME sh -c "php artisan serve --host=0.0.0.0 --port=$SERVER_PORT > /dev/null 2>&1 &"

    if [ $? -eq 0 ]; then
        echo "✅ Development server started in the background for '$PROJECT_NAME'."
        echo "URL: http://localhost:$SERVER_PORT"
        echo "Use: ./go.sh -p $PROJECT_NAME --port$SERVER_PORT -k to stop it."
    else
        echo "❌ Error starting the development server."
    fi
}

# Function to kill the development server
kill_dev_server() {
    echo "🛑 Stopping the Laravel development server for '$PROJECT_NAME' on port $SERVER_PORT..."
    # Find and kill the specific 'php artisan serve' process by port
    docker exec -w $PROJECT_PATH $CONTAINER_NAME sh -c "pkill -f \"php artisan serve --host=0.0.0.0 --port=$SERVER_PORT\""

    if [ $? -eq 0 ]; then
        echo "✅ Server stopped successfully."
    else
        echo "⚠️ No 'php artisan serve' process was found running on port $SERVER_PORT for this project."
    fi
}

# Display help message
display_help() {
    echo "-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-"
    echo "-.- Usage: $0 [option]"
    echo "-.-"
    echo "-.- Context and Development Options:"
    echo "-.-     -p, --project <name>  Sets the target project."
    echo "-.-                           (Default: default)"
    echo "-.-"
    echo "-.-     --port8080            Sets the port to 8080 for the -r/-k command."
    echo "-.-     --port8008            Sets the port to 8008 for the -r/-k command."
    echo "-.-     --port8000            Sets the port to 8000 for the -r/-k command."
    echo "-.-     -r, --run             Starts the Laravel development web server."
    echo "-.-     -k, --kill            Stops the development web server."
    echo "-.-"
    echo "-.- Initialization/Setup Options:"
    echo "-.-     --new <name>          Creates a new Laravel project in a subdirectory."
    echo "-.-      --clone <user/repo>  Initializes Git, sets origin, fixes permissions,"
    echo "-.-                           cleans local files, and runs 'git pull'."
    echo "-.-     -i, --init            Initial setup: migrate:fresh and seed."
    echo "-.-     -m, --migrate         Runs migrations and seeders."
    echo "-.-"
    echo "-.- Maintenance Options:"
    echo "-.-     -c, --clear           Clears all Laravel cache."
    echo "-.-     --composer            Runs 'composer install' for PHP dependencies."
    echo "-.-     -s, --shell           Enters the bash shell of the application container."
    echo "-.-     -M, --make-MMC        Creates one or more new Laravel Models + Migrations + Controller."
    echo "-.-"
    echo "-.- Help:"
    echo "-.-     -h, --help            Displays this help message."
    echo "-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-"
}


# Check if arguments were provided
if [ $# -eq 0 ]; then
    echo "No arguments provided."
    display_help
    exit 1
fi

# Process arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        # 1. SET PROJECT CONTEXT
        -p|--project)
            if [ -n "$2" ] && [[ "$2" != -* ]]; then
                update_project_context "$2"
                shift 2
            else
                echo "❌ Error: Missing project name after -p/--project."
                display_help; exit 1
            fi
            ;;
        
        # 2. SET SERVER PORT
        --port8080)
            SERVER_PORT="8080"
            echo "Server port set to: 8080"
            shift
            ;;
        --port8008)
            SERVER_PORT="8008"
            echo "Server port set to: 8008"
            shift
            ;;
        --port8000)
            SERVER_PORT="8000"
            echo "Server port set to: 8000"
            shift
            ;;


        # 3. RUN/KILL SERVER COMMANDS
        -r|--run)
            run_dev_server
            shift
            ;;
        -k|--kill)
            kill_dev_server
            shift
            ;;

        # 4. NEW PROJECT COMMAND
        --new)
            if [ -n "$2" ] && [[ "$2" != -* ]]; then
                create_new_project "$2"
                shift 2
            else
                echo "❌ Error: Missing project name after --new."
                display_help; exit 1
            fi
            ;;
        
        # 5. CLONE YOU GITHUB PROYECT
        --clone)
            if [ -n "$2" ] && [[ "$2" != -* ]]; then
                git_clone_setup "$2"
                shift 2
            else
                echo "❌ Error: Missing repository name (e.g., user/repo) after --clone."
                display_help; exit 1
            fi
            ;;
        # 6. INITIALIZATION COMMANDS
        -i|--init)
           
            # ----------------------------------------------------
            # >>> ADD TO PATH <<<
            if [[ -n "$BASH_SOURCE" ]]; then
                REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            else
                REPO_ROOT="$(dirname "$(readlink -f "$0")")" 
            fi

            # Add to PATH if it doesn't already exist
            if [[ ":$PATH:" != *":$REPO_ROOT:"* ]]; then
                export PATH="$REPO_ROOT:$PATH"
                echo "✅ 'go.sh' directory ($REPO_ROOT) added to \$PATH for this session."
                # Add the 'go' alias
                alias go='go.sh'
                echo "✨ 'go' alias created."
            fi
            # ----------------------------------------------------
            echo "🔥 Executing initial setup for '$PROJECT_NAME': Migrate:Fresh and Seed."
            docker exec -w $BASE_DIR $CONTAINER_NAME cp .env $PROJECT_PATH
            execute_artisan migrate:fresh --seed
            shift
            ;;
        -m|--migrate)
            echo "🔄 Executing migrations and seeders for '$PROJECT_NAME' (artisan migrate --seed)."
            execute_artisan migrate --seed
            shift
            ;;
        
        # 7. MAINTENANCE COMMANDS (Clearing cache, composer install, shell access)
        -c|--clear)
            echo "🧹 Clearing all Laravel cache in '$PROJECT_NAME'..."
            execute_artisan cache:clear
            execute_artisan config:clear
            execute_artisan view:clear
            execute_artisan route:clear
            shift
            ;;

            -M|--make-MMC)
            shift
            for model_name in "$@"; do
                if [[ -n "$model_name" ]]; then
                    echo "🏭 Executing artisan: make:model $model_name -mcr"
                    execute_artisan make:model "$model_name" -mcr 
                fi
            done
            ;;
        --composer)
            echo "📦 Executing composer install in '$PROJECT_NAME'..."
            execute_composer install
            shift
            ;;
        -s|--shell)
            echo "🖥️  Entering the container shell at path '$PROJECT_PATH'..."
            docker exec -w $PROJECT_PATH -it $CONTAINER_NAME bash
            shift
            ;;

        # 8. HELP AND INVALID
        -h|--help)
            display_help
            exit 0
            ;;
        
        *)
            echo "Invalid option: $1"
            display_help; exit 1
            ;;
    esac
done
