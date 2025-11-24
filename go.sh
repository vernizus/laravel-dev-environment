#!/bin/bash

# Auto-load variables from build/.env on every execution
if [[ -f "build/.env" ]]; then
    source "build/.env"
fi

BASE_DIR="/var/www/html"
PROJECT_NAME="${PROJECT_NAME:-default}"
CONTAINER_NAME="${CONTAINER_NAME:-default_app}"
PROJECT_PATH="$BASE_DIR/$PROJECT_NAME"
SERVER_PORT="${SERVER_PORT:-8000}"
MYSQL_CONTAINER="${MYSQL_CONTAINER:-mariadb_dev}"

# Docker Compose shortcut
dc() {
    docker compose -f build/docker-compose.yml "$@"
}

export PROJECT_NAME CONTAINER_NAME PROJECT_PATH BASE_DIR


# --- Helper Functions ---

# --------------------------------------------------
# Function: Update or add PROJECT_NAME and CONTAINER_NAME in build/.env
# --------------------------------------------------
update_env_project_names() {
    local ENV_FILE="build/.env"

    # If the file doesn't exist → clear error
    if [[ ! -f "$ENV_FILE" ]]; then
        echo "Error: File $ENV_FILE not found"
        exit 1
    fi

    # 1. Ask for project name
    echo ""
    echo "Project name configuration"
    echo "-----------------------------------------------"
    read -p "Project name [current: $(grep '^PROJECT_NAME=' "$ENV_FILE" | cut -d'=' -f2 || echo 'default') ] (Enter = keep): " NEW_PROJECT
    NEW_PROJECT=${NEW_PROJECT:-$(grep '^PROJECT_NAME=' "$ENV_FILE" | cut -d'=' -f2 || echo "default")}

    # 2. Ask for container name
    read -p "Container name [current: $(grep '^CONTAINER_NAME=' "$ENV_FILE" | cut -d'=' -f2 || echo 'default') ] (Enter = keep): " NEW_CONTAINER
    NEW_CONTAINER=${NEW_CONTAINER:-$(grep '^CONTAINER_NAME=' "$ENV_FILE" | cut -d'=' -f2 || echo "default")}

    # 3. Update or add lines with sed
    sed -i \
        -e "s|^PROJECT_NAME=.*|PROJECT_NAME=$NEW_PROJECT|" \
        -e "s|^CONTAINER_NAME=.*|CONTAINER_NAME=$NEW_CONTAINER|" \
        "$ENV_FILE"

    # If for some reason they didn't exist → add them at the end
    grep -q "^PROJECT_NAME=" "$ENV_FILE" || echo "PROJECT_NAME=$NEW_PROJECT" >> "$ENV_FILE"
    grep -q "^CONTAINER_NAME=" "$ENV_FILE" || echo "CONTAINER_NAME=$NEW_CONTAINER" >> "$ENV_FILE"

    echo ""
    echo "File build/.env updated:"
    echo "   PROJECT_NAME=$NEW_PROJECT"
    echo "   CONTAINER_NAME=$NEW_CONTAINER"
    echo ""
}

# --------------------------------------------------
# Wait for Laravel to be fully ready
# --------------------------------------------------
wait_for_laravel_ready() {
    local container_name="${1:-$CONTAINER_NAME}"
    local port="${2:-$SERVER_PORT}"

    echo "Waiting for Laravel to be fully ready (artisan serve on port $port)..."
    until docker exec "$CONTAINER_NAME" ss -nlt | grep -q ":$port"; do
        printf "."
        sleep 1
    done
    echo ""
    echo "Laravel is up and running on http://localhost:$port"
}

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

wait_for_mysql() {
    echo "⏳ Waiting for MariaDB to be ready..."
    until docker exec $MYSQL_CONTAINER ss -nlt | grep -q ':3306'; do
        printf "."
        sleep 1
    done
    echo ""
    echo "✅ MariaDB is ready!"
}

# --- NEW: GIT CLONE & SYNC FUNCTION ---
########################################

git_clone_setup() {
    local USER_REPO=$1   # Example: 'user/namerepo'

    echo "⚠️ You are about to clone/sync a Laravel project."
    read -p "Are you sure you are inside the target project directory? (y/N): " CONFIRM
    case "$CONFIRM" in
        [yY][eE][sS]|[yY])
            echo "✅ Proceeding..."
            ;;
        *)
            echo "❌ Aborted. Please navigate to the correct project folder."
            return 1
            ;;
    esac
    
    local REPO_URL="git@github.com:${USER_REPO}.git"

    # Host absolute path where the script is being executed
    local HOST_PROJECT_DIR="$PWD"

    if [ -z "$USER_REPO" ]; then
        echo "❌ Error: You must specify user/repository for cloning."
        echo "Example: $0 --clone user/repo"
        exit 1
    fi

    echo "---------------------------------------------------------"
    echo "🌐 Starting Git clone and synchronization process"
    echo "---------------------------------------------------------"

    # 1. Fix permissions BEFORE touching .git
    echo "🔑 Fixing file ownership for the current directory..."
    sudo chown -R $USER:$USER "$HOST_PROJECT_DIR"

    # 2. Ensure .git does not exist in a broken state
    if [ -d ".git" ]; then
        echo "⚠️ Existing .git folder found. Checking integrity..."
        if ! git status &>/dev/null; then
            echo "🧨 The .git directory is corrupted. Removing it..."
            rm -rf .git
        fi
    fi

    # 3. Initialize Git repository if needed
    if [ ! -d ".git" ]; then
        echo "📦 Initializing local Git repository..."
        git init
    fi

    # 4. Configure or update remote 'origin'
    if git remote | grep -q "^origin$"; then
        echo "🔗 Remote 'origin' already exists. Updating URL..."
        git remote set-url origin "$REPO_URL"
    else
        echo "🔗 Adding remote 'origin': $REPO_URL"
        git remote add origin "$REPO_URL"
    fi

    # 5. Fix “dubious ownership”
    echo "🛡️ Marking directory as safe for Git: $HOST_PROJECT_DIR"
    git config --global --add safe.directory "$HOST_PROJECT_DIR"

    echo "📥 Fetching remote branch information..."
    git fetch origin main || git fetch origin master || {
        echo "❌ Error: Could not fetch remote repository branches."
        echo "Verify SSH keys or repository name."
        exit 1
    }

    # Determine branch
    LOCAL_BRANCH="main"
    git fetch origin main &>/dev/null || LOCAL_BRANCH="master"

    echo "🔄 Resetting local files to match origin/${LOCAL_BRANCH}..."
    git reset --hard "origin/${LOCAL_BRANCH}"

    echo "---------------------------------------------------------"
    echo "✅ Git repository synchronized successfully!"
    echo "---------------------------------------------------------"

    echo "📦 Running 'composer install' inside the container..."
    execute_composer install

    echo "🎉 Clone and setup completed!"
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

	# Check if it exists as a file and delete it
    if docker exec $CONTAINER_NAME [ -f "$NEW_PROJECT_PATH" ]; then
        echo "⚠️  Found conflicting file at $NEW_PROJECT_PATH. Removing it..."
        docker exec $CONTAINER_NAME rm -f "$NEW_PROJECT_PATH"
    fi

	# Check if the directory already exists
    if docker exec $CONTAINER_NAME [ -d "$NEW_PROJECT_PATH" ]; then
        echo "✅ Project directory '$NEW_PROJECT_NAME' already exists."
        echo "Skipping project creation."
        return 0
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
        echo "Use: go -p $PROJECT_NAME --port$SERVER_PORT -k to stop it."
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

# Function validate existing project
validate_project() {
    # Verify that the container is running
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        echo "❌ Error: Container '$CONTAINER_NAME' is not running"
        echo "💡 Start it with: go --init"
        return 1
    fi

    # Verify that the project exists
    if ! docker exec $CONTAINER_NAME [ -d "$PROJECT_PATH" ] 2>/dev/null; then
        echo "❌ Error: Project '$PROJECT_NAME' doesn't exist at $PROJECT_PATH"
        echo ""
        echo "📁 Available projects in $BASE_DIR:"
        docker exec $CONTAINER_NAME ls -la "$BASE_DIR" 2>/dev/null | grep '^d' | awk '{print "   📂 " $9}' || echo "   (cannot list directory)"
        echo ""
        echo "💡 Solutions:"
        echo "   - Create project: go --new $PROJECT_NAME"
        echo "   - Switch project: go -p existing_project_name"
        echo "   - Clone from Git: go --clone user/repo"
        return 1
    fi

    # Verify that it has the basic Laravel structure
    if ! docker exec $CONTAINER_NAME [ -f "$PROJECT_PATH/artisan" ] 2>/dev/null; then
        echo "⚠️  Warning: Project '$PROJECT_NAME' exists but doesn't look like a Laravel project (artisan not found)"
        echo "   The directory exists but may not be a valid Laravel application"
        # No return 1 here, just warning
    fi

    return 0
}

# Display help message
display_help() {
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│                    🚀 LARAVEL DEV TOOL                       │"
    echo "├──────────────────────────────────────────────────────────────┤"
    echo "│ Usage: go [OPTION] [ARGUMENTS]                               │"
    echo "│       . go.sh [OPTION] [ARGUMENTS]                           │"
    echo "│                                                              │"
    echo "│ Quick Start:                                                 │"
    echo "│   . go -i                      First-time project setup      │"
    echo "│   go -p myapp -r               Run dev server (use -p for    │"
    echo "│                                non-default projects)         │"
    echo "│                                                              │"
    echo "└──────────────────────────────────────────────────────────────┤"
    echo "│ PROJECT & CONTEXT MANAGEMENT                                 │"
    echo "│  -p, --project <name>    Switch to project context           │"
    echo "│                          (Default: $PROJECT_NAME)            │"
    echo "│                                                              │"
    echo "│ DEVELOPMENT SERVER                                           │"
    echo "│  -r, --run              Start Laravel development server     │"
    echo "│  -k, --kill             Stop development server              │"
    echo "│  --port8000             Use port 8000 (default)              │"
    echo "│  --port8080             Use port 8080                        │"
    echo "│  --port8008             Use port 8008                        │"
    echo "│                                                              │"
    echo "│ PROJECT INITIALIZATION                                       │"
    echo "│  --new <name>           Create new Laravel project           │"
    echo "│  --clone <user/repo>    Clone & setup from GitHub            │"
    echo "│  -i, --init             Full setup: env, db, migrations      │"
    echo "│  -m, --migrate          Run migrations + seeders             │"
    echo "│                                                              │"
    echo "│ CODE GENERATION & MAINTENANCE                                │"
    echo "│  -M, --make-MMC <models> Create Model+Migration+Controller   │"
    echo "│                         (Multiple models supported)          │"
    echo "│  -c, --clear            Clear all cache (cache, route, etc.) │"
    echo "│  --composer             Run composer install                 │"
    echo "│  -s, --shell            Enter container shell                │"
    echo "│                                                              │"
    echo "│ EXAMPLES                                                     │"
    echo "│   go --init                    Initial project setup         │"
    echo "│   go -p blog --new blog        Create & switch to 'blog'     │"
    echo "│   go -p api -r                 Run server on 'api' project   │"
    echo "│   go --port8080 -r             Run on port 8080              │"
    echo "│   go -M User Post Category     Generate multiple models      │"
    echo "│   go --clone owner/myapp       Clone from GitHub             │"
    echo "│                                                              │"
    echo "│ TIPS                                                         │"
    echo "│ • Use 'go -p <name>' to switch between projects              │"
    echo "│ • Project files are in ./volumes/laravel/                    │"
    echo "│ • Database data in ./volumes/database/                       │"
    echo "└──────────────────────────────────────────────────────────────┘"
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
	    if validate_project; then
	        run_dev_server
	    else
	        echo "💡 Tip: Use 'go --new $PROJECT_NAME' to create the project first"
	        exit 1
	    fi
            shift
            ;;
        -k|--kill)
	    if validate_project; then
	        kill_dev_server
	    else
	        exit 1
	    fi
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
	    update_env_project_names

            source build/.env 2>/dev/null || true
            PROJECT_NAME="${PROJECT_NAME:-default}"
            CONTAINER_NAME="${CONTAINER_NAME:-default_app}"
            BASE_DIR="/var/www/html"
            PROJECT_PATH="$BASE_DIR/$PROJECT_NAME"

	    dc up -d --build --quiet-pull

	    wait_for_laravel_ready "$CONTAINER_NAME" "$SERVER_PORT"

            echo "🔥 Executing initial setup for '$PROJECT_NAME': Migrate:Fresh and Seed."
            docker exec -w $BASE_DIR $CONTAINER_NAME cp .env $PROJECT_PATH

            wait_for_mysql

            execute_artisan migrate:fresh --seed

            echo -e "\nALL DONE! Project '$PROJECT_NAME' is ready"
            echo "   → http://localhost:$SERVER_PORT"
            echo "   → Container: $CONTAINER_NAME"
            shift
            ;;

        -m|--migrate)
	    if validate_project; then
	        echo "🔄 Executing migrations and seeders for '$PROJECT_NAME' (artisan migrate --seed)."
	        execute_artisan migrate --seed
	    else
	        exit 1
	    fi
            shift
            ;;
        
        # 7. MAINTENANCE COMMANDS (Clearing cache, composer install, shell access)
        -c|--clear)
	    if validate_project; then
	        echo "🧹 Clearing all Laravel cache in '$PROJECT_NAME'..."
	        execute_artisan cache:clear
	        execute_artisan config:clear
	        execute_artisan view:clear
	        execute_artisan route:clear
	    else
	        exit 1
	    fi
            shift
            ;;

        -M|--make-MMC)
            if ! validate_project; then
                exit 1
            fi

            if [[ $# -eq 1 ]]; then
                echo "Error: No model names provided."
                echo "Usage: go -M User Post Category"
                exit 1
            fi

            shift
            local models=()
            while [[ $# -gt 0 ]] && [[ "$1" != -* ]]; do
                models+=("$1")
                shift
            done

            if [[ ${#models[@]} -eq 0 ]]; then
                echo "Error: At least one model name is required."
                echo "Example: go -M Product User Order"
                exit 1
            fi

            for model in "${models[@]}"; do
                echo "Creating model: $model (with migration, controller, resource)"
                execute_artisan make:model "$model" -mcr
            done
            ;;

        --composer)
	    if validate_project; then
	        echo "📦 Executing composer install in '$PROJECT_NAME'..."
	        execute_composer install
	    else
	        exit 1
	    fi
            shift
            ;;


        -s|--shell)
	    if validate_project; then
	        echo "🖥️  Entering the container shell at path '$PROJECT_PATH'..."
	        docker exec -w $PROJECT_PATH -it $CONTAINER_NAME bash
	    else
	        exit 1
	    fi
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
