#!/bin/bash

# =====================================================================
#  NODE.JS + VITE DOCKER MODULE
#  Part of: laravel-dev-environment[]
#  https://github.com/vernizus/laravel-dev-environment
#
#  Author       : Alejandro Fernandes aka Vernizus Luna
#  GitHub       : https://github.com/vernizus
#  LinkedIn     : https://linkedin.com/in/gabriel-fernandes-998b64320
#  Created      : 2025 – "I'm not a teapot" – but I do run on coffee
# =====================================================================

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =====================================================================
# MAIN FUNCTIONS
# =====================================================================

ensure_vite_config() {
    load_config
    log "Fixing vite.config.js inside container (bulletproof method)..."

    if docker compose -f "$COMPOSE_FILE" exec node test -f /app/vite.config.js 2>/dev/null; then
        docker compose -f "$COMPOSE_FILE" exec node sh -c "
            if ! grep -q 'hmr.*host.*localhost' /app/vite.config.js 2>/dev/null; then
                echo 'Patching vite.config.js with Docker fixes...'
                cp /app/vite.config.js /app/vite.config.js.bak
                cat > /app/vite.config.js << 'VITE'
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
        tailwindcss(),
    ],
    server: {
        host: '0.0.0.0',
        port: 5173,
        strictPort: true,
        hmr: { host: 'localhost' },
        watch: { usePolling: false },
    },
});
VITE
                echo 'vite.config.js fixed!'
            else
                echo 'vite.config.js already perfect'
            fi
        "
    else
        docker compose -f "$COMPOSE_FILE" exec node sh -c "
            echo 'Creating perfect vite.config.js...'
            cat > /app/vite.config.js << 'VITE'
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
        tailwindcss(),
    ],
    server: {
        host: '0.0.0.0',
        port: 5173,
        strictPort: true,
        hmr: { host: 'localhost' },
        watch: { usePolling: false },
    },
});
VITE
            echo 'vite.config.js created!'
        "
    fi

    log "vite.config.js is now 100% perfect inside container"
}

# Function: Load configuration
load_config() {
    if [ -f "$ENV_FILE" ]; then
        # Safe method compatible with Bash 3.1+
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            case "$line" in
                \#* | "" ) continue ;;
            esac

            # Only process lines with KEY=value format
            if printf '%s\n' "$line" | grep -E '^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]' >/dev/null 2>&1; then
                # Extract KEY and VALUE safely
                key=$(printf '%s\n' "$line" | cut -d= -f1)
                value=$(printf '%s\n' "$line" | sed 's/^[^=]*=//')
                export "$key=$value"
            fi
        done < "$ENV_FILE"

        # Default values + force _node suffix
        PROJECT_NAME="${PROJECT_NAME:-default}"
        CONTAINER_NAME="${CONTAINER_NAME:-default_app}"
        CONTAINER_NAME="${CONTAINER_NAME%_node}_node"
    else
        PROJECT_NAME="default"
        CONTAINER_NAME="default_app_node"
        warn "No .env file found, using defaults"
    fi
}

# Function: Check if container is running
is_running() {
    local port="${VITE_PORT:-5173}"

    # Prioridad: lsof → ss → netstat → docker
    lsof -i :$port -sTCP:LISTEN -t >/dev/null 2>&1 && return 0
    ss -ltn 2>/dev/null | grep -q ":$port " && return 0
    netstat -an 2>/dev/null | grep -q "\.$port .*LISTEN" && return 0

    # Fallback final por si acaso
    docker ps --filter "expose=$port" --format "{{.Names}}" | grep -q "_node"
}

# Function: Get container status
container_status() {
    if is_running; then
        echo -e "${GREEN}RUNNING${NC}"
    else
        echo -e "${RED}STOPPED${NC}"
    fi
}

# Function: Interactive configuration
node_config() {
    echo ""
    echo -e "${CYAN}🔧 NODE.JS CONTAINER CONFIGURATION${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"

    # Check if file exists
    if [ ! -f "$ENV_FILE" ]; then
        error "File $ENV_FILE not found"
        echo "Please create the .env file first with PROJECT_NAME and CONTAINER_NAME"
        return 1
    fi

    # Current values
    local current_project=$(grep '^PROJECT_NAME=' "$ENV_FILE" | cut -d'=' -f2)
    local current_container=$(grep '^CONTAINER_NAME=' "$ENV_FILE" | cut -d'=' -f2)

    current_project=${current_project:-"default"}
    current_container=${current_container:-"default_app_node"}

    # Remove _node if exists for clean display
    local current_container_base=${current_container%_node}

    # 1. Ask for project name
    echo -e "${YELLOW}Project name:${NC}"
    read -p "  [current: $current_project] (Enter = keep): " new_project
    new_project=${new_project:-$current_project}

    # 2. Ask for container base name (without _node)
    echo -e "\n${YELLOW}Container base name:${NC}"
    echo -e "  '_node' will be automatically added"
    read -p "  [current: $current_container_base] (Enter = keep): " new_container_base
    new_container_base=${new_container_base:-$current_container_base}

    # 3. CONTAINER_NAME in .env MUST include _node
    local new_container_full="${new_container_base}_node"

    # 4. Update .env file - WITH _node INCLUDED
    echo -e "\n${YELLOW}Updating $ENV_FILE...${NC}"

    temp_file=$(mktemp)

    while IFS= read -r line; do
        if [[ "$line" =~ ^PROJECT_NAME= ]]; then
            echo "PROJECT_NAME=$new_project"
        elif [[ "$line" =~ ^CONTAINER_NAME= ]]; then
            echo "CONTAINER_NAME=$new_container_full"  # WITH _node!
        else
            echo "$line"
        fi
    done < "$ENV_FILE" > "$temp_file"

    mv "$temp_file" "$ENV_FILE"

    # 5. Show summary
    echo -e "\n${GREEN}✅ CONFIGURATION UPDATED${NC}"
    echo -e "┌──────────────────────┬────────────────────────────┐"
    echo -e "│ ${YELLOW}Project Name${NC}         │ $new_project │"
    echo -e "│ ${YELLOW}Container Name${NC}       │ $new_container_full │"
    echo -e "└──────────────────────┴────────────────────────────┘"

    # 6. Verification
    echo -e "\n${CYAN}📋 VERIFICATION:${NC}"
    echo -e "Current values in $ENV_FILE:"
    grep -E "^(PROJECT_NAME|CONTAINER_NAME)=" "$ENV_FILE"
}

# ===================================================================
# MANAGEMENT FUNCTIONS
# ===================================================================

# Function: Start container
node_start() {
    load_config || return 1
    log "Starting Node.js development server..."

    if docker compose -f "$COMPOSE_FILE" up -d; then
	sleep 2
	ensure_vite_config

        echo -e "\n${GREEN}🎨 VITE DEVELOPMENT SERVER STARTED${NC}"
        echo -e "┌──────────────────────┬────────────────────────────┐"
        echo -e "│ ${YELLOW}Project${NC}              │ $PROJECT_NAME "
        echo -e "│ ${YELLOW}Container${NC}            │ $CONTAINER_NAME "
        echo -e "│ ${YELLOW}Dev Server${NC}           │ ${GREEN}http://localhost:5173${NC} "
        echo -e "│ ${YELLOW}Hot Reload${NC}           │ ${GREEN}Enabled${NC} "
        echo -e "└──────────────────────┴────────────────────────────┘"
        echo -e "\n${CYAN}📝 Changes in resources/ will trigger automatic rebuild${NC}"

        # Show logs automatically
        echo -e "\n${YELLOW}Tip: press Ctrl+C to stop watching logs${NC}"
        docker compose -f "$COMPOSE_FILE" logs -f node
    else
        error "Failed to start Node.js container"
        return 1
    fi
}

# Function: Stop container
node_stop() {
    log "Stopping Node.js container..."
    if docker compose -f "$COMPOSE_FILE" down > /dev/null 2>&1; then
        log "Node.js container stopped"
    else
        error "Failed to stop Node.js container"
        return 1
    fi
}

# Function: Restart container
node_restart() {
    load_config
    log "Restarting Node.js container ($CONTAINER_NAME)..."
    if docker compose -f "$COMPOSE_FILE" restart node > /dev/null 2>&1; then
        log "Node.js container restarted successfully"
        echo -e "${GREEN}Vite dev server available at http://localhost:5173${NC}"
    else
        error "Failed to restart Node.js container"
        return 1
    fi
}

# Function: Check status
node_status() {
    load_config
    local container_base="${CONTAINER_NAME%_node}"

    echo -e "\n${CYAN}📊 NODE.JS CONTAINER STATUS${NC}"
    echo -e "┌──────────────────────┬────────────────────────────┐"
    echo -e "│ ${YELLOW}Container${NC}            │ $(container_status)"
    echo -e "│ ${YELLOW}Project${NC}              │ $PROJECT_NAME              │"
    echo -e "│ ${YELLOW}Container Base${NC}       │ $container_base      "
    echo -e "│ ${YELLOW}Container Full${NC}       │ $CONTAINER_NAME      "
    echo -e "│ ${YELLOW}Vite Dev Server${NC}      │ http://localhost:5173"
    echo -e "└──────────────────────┴────────────────────────────┘"

    if is_running; then
        echo -e "\n${GREEN}✅ Ready for development!${NC}"
    else
        echo -e "\n${YELLOW}⚠️  Container is stopped - use 'go --node start'${NC}"
    fi
}

# ===================================================================
# DEVELOPMENT FUNCTIONS
# ===================================================================

# Function: Install dependencies
node_install() {
    load_config
    log "Installing/updating Node.js dependencies..."

    docker compose -f "$COMPOSE_FILE" up -d --no-deps node > /dev/null 2>&1

    if docker compose -f "$COMPOSE_FILE" exec node test -d /app/node_modules 2>/dev/null && \
       docker compose -f "$COMPOSE_FILE" exec node npm install --quiet; then
        log "Dependencies updated successfully (exec)"

    elif docker compose -f "$COMPOSE_FILE" run --rm node npm install --quiet; then
        log "Dependencies installed successfully (run)"

    else
        error "Failed to install Node.js dependencies"
        error "Check logs: go --node logs"
        return 1
    fi

    ensure_vite_config

    log "Node.js environment ready"
}

# Function: Production build
node_build() {
    log "Building production assets..."
    load_config

    if docker compose -f "$COMPOSE_FILE" run --rm node sh -c "npm run build"; then
        log "Production build completed successfully"
        echo -e "\n${GREEN}✅ Assets ready in: public/build/${NC}"
    else
        error "Build failed"
        return 1
    fi
}

# =====================================================================
# DEBUG FUNCTIONS
# =====================================================================

# Function: View logs
node_logs() {
    if is_running; then
        log "Showing logs (Ctrl+C to exit)..."
        docker compose -f "$COMPOSE_FILE" logs -f node
    else
        error "Node.js container is not running"
        return 1
    fi
}

# Function: Interactive shell
node_shell() {
    if is_running; then
        log "Entering container shell..."
        docker compose -f "$COMPOSE_FILE" exec node sh
    else
        error "Node.js container is not running"
        return 1
    fi
}

# Function: Execute npm command
node_npm() {
    # If container is not running → clear error
    if ! is_running; then
        error "Node.js container is not running → use: go --node dev"
        return 1
    fi

    # If no command provided → quick help
    if [ $# -eq 0 ]; then
        error "No npm command provided"
        echo "   Examples:"
        echo "     go --node npm run dev"
        echo "     go --node npm install"
        echo "     go --node npm run lint"
        return 1
    fi

    load_config

    log "npm $*"
    docker compose -f "$COMPOSE_FILE" exec node npm "$@"
}

# =====================================================================
# UTILITY FUNCTIONS
# =====================================================================

# Function: Clean everything
node_clean() {
    warn "This will stop and remove the Node.js container and volumes"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Cleaning Node.js environment..."
        docker compose -f "$COMPOSE_FILE" down -v > /dev/null 2>&1
        log "Clean completed"
    else
        log "Clean cancelled"
    fi
}

###################################################################

# Function: Install Breeze for existing projects 
install_existing_breeze() {
    log "Installing Breeze for existing project..."
    local MAIN_COMPOSE="$SCRIPT_DIR/../docker-compose.yml"

    echo -e "${GREEN}🛡️  COMPLETE PEACE OF MIND - YOUR ROUTES ARE PROTECTED 🛡️${NC}"
    echo -e "${YELLOW}Your current routes/web.php file will be 100% preserved.${NC}"
    echo -e "${YELLOW}Breeze routes will be added at the end without modifying your existing code.${NC}"
    echo ""
    
    # Ask for Breeze configuration BEFORE docker command
    echo -e "${YELLOW}Which Breeze stack do you prefer?${NC}"
    echo " 1) Blade with Alpine (recommended)"
    echo " 2) React"
    echo " 3) Vue"
    read -p " Option [1]: " stack_choice
    case $stack_choice in
        2) stack="react" ;;
        3) stack="vue" ;;
        *) stack="blade" ;;
    esac
    
    echo -e "${YELLOW}Do you want dark mode support?${NC}"
    read -p " (y/N): " dark_mode
    if [[ $dark_mode =~ ^[Yy]$ ]]; then
        dark_flag="--dark"
    else
        dark_flag=""
    fi

    # 1. Install Breeze in Laravel container
    log "Installing Breeze in Laravel container..."
    if ! docker compose -f "$MAIN_COMPOSE" exec laravel bash -c "
        cd /var/www/html/$PROJECT_NAME
        
        # 1. Backup your original routes
        cp routes/web.php routes/web.php.MY_CUSTOM
        
        # 2. Install Breeze
        composer require laravel/breeze --dev
        php artisan breeze:install $stack $dark_flag --pest --no-interaction
        
        # 3. Save what Breeze generated
        cp routes/web.php routes/web.php.BREEZE_GENERATED
        
        # 4. Rebuild the perfect file
        {
            # PHP opening
            echo '<?php'
            echo ''
            echo '// ****** YOUR CUSTOM ROUTES ****** //'

            # Your original routes (without <?php if it had it)
            if head -n 1 routes/web.php.MY_CUSTOM | grep -q '^<?php'; then
                tail -n +2 routes/web.php.MY_CUSTOM
            else
                cat routes/web.php.MY_CUSTOM
            fi
    
            echo ''
            echo '// ****** ROUTES ADDED BY BREEZE ****** // '
            echo ''
    
            awk '/use App\\\\Http\\\\Controllers\\\\ProfileController;/,0' routes/web.php.BREEZE_GENERATED | \
            grep -v 'use Illuminate\\\\Support\\\\Facades\\\\Route;' | \
            grep -v 'Route::get.*welcome'
    
        } > routes/web.php.new && mv routes/web.php.new routes/web.php
        
        # Cleanup
        rm -f routes/web.php.MY_CUSTOM routes/web.php.BREEZE_GENERATED routes/web.php.new 2>/dev/null || true
        chown 1000:1000 routes/web.php

    "; then
        error "Failed to install Breeze in Laravel container"
        return 1
    fi

    # 2. Install and run in Node container
    log "Installing and running Node dependencies..."
    docker compose -f "$COMPOSE_FILE" exec node sh -c "
        npm install && npm run build && npm run dev
    "
    
    log "Breeze installed successfully"
}

# Function: Initial setup
node_setup() {
    log "Running initial setup..."
    node_config

    # Ask if existing project with Breeze
    echo -e "\n${CYAN}🔍 EXISTING PROJECT DETECTION${NC}"
    echo -e "${YELLOW}Is this an existing Laravel project that already had Breeze?${NC}"
    read -p "  (y/N): " has_breeze
    
    if [[ $has_breeze =~ ^[Yy]$ ]]; then
        log "Existing project detected - installing Breeze automatically..."
	node_install
        node_start
        install_existing_breeze
    else
        log "New project - standard installation..."
        node_install
        node_start
    fi

    node_status
}

# =====================================================================
# HELPERS
# =====================================================================

log() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${BLUE}ℹ${NC} $1"; }

# =====================================================================
# MAIN MENU
# =====================================================================

main() {
    load_config

    case "$1" in
        # Container management
        start|dev)         node_start ;;
        stop|down)         node_stop ;;
        restart)           node_restart ;;
        status)            node_status ;;

        # Development
        build)             node_build ;;
		install)           node_install ;;
        # Configuration
        config)            node_config ;;

        # Debug
        logs)              node_logs ;;
        sh)                node_shell ;;
        npm)               shift; node_npm "$@" ;;

        # Utilities
        clean)             node_clean ;;
        setup)             node_setup ;;

        # Help
        help|--help|-h|*)  show_help ;;
    esac
}

show_help() {
    echo -e "${CYAN}🚀 NODE.JS DEVELOPMENT SCRIPT${NC}"
    echo
    echo -e "${YELLOW}USAGE:${NC}"
    echo "  go --node [COMMAND]"
    echo
    echo -e "${GREEN}CONTAINER MANAGEMENT:${NC}"
    echo "  start, dev     Start Node.js container"
    echo "  stop, down     Stop Node.js container"
    echo "  restart        Restart Node.js container"
    echo "  status         Show container status"
    echo
    echo -e "${GREEN}DEVELOPMENT:${NC}"
    echo "  build          Build for production"
    echo "  npm <cmd>      Run any npm command"
    echo "  install        Installing/updating Node.js depend  "
	echo
    echo -e "${GREEN}CONFIGURATION:${NC}"
    echo "  config         Interactive configuration"
    echo
    echo -e "${GREEN}DEBUGGING:${NC}"
    echo "  logs           Show container logs"
    echo "  shell          Enter container shell"
    echo
    echo -e "${GREEN}UTILITIES:${NC}"
    echo "  clean          Stop and remove containers/volumes"
    echo "  setup          Initial setup (install + start)"
    echo "  help           Show this help"
    echo
    echo -e "${YELLOW}EXAMPLES:${NC}"
    echo "  go --node config      # Configure container"
    echo "  go --node setup       # First-time setup"
    echo "  go --node dev         # Start development"
    echo "  go --node npm test    # Run tests"
}

# =============================================================================
# EXECUTION
# =============================================================================

# Load configuration at startup
load_config

# Execute command
if [ $# -eq 0 ]; then
    show_help
else
    main "$@"
fi
