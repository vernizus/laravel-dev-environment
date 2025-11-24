#!/bin/bash

# =============================================================================
# NODE.JS DEVELOPMENT SCRIPT
# Node.js container management for Laravel development
# =============================================================================

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

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

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
        PROJECT_NAME="${PROJECT_NAME:-vernizus}"
        CONTAINER_NAME="${CONTAINER_NAME:-default_app}"
        CONTAINER_NAME="${CONTAINER_NAME%_node}_node"
    else
        PROJECT_NAME="vernizus"
        CONTAINER_NAME="default_app_node"
        warn "No .env file found, using defaults"
    fi
}

# Function: Check if container is running
is_running() {
    docker ps --format 'table {{.Names}}' | grep -q "${CONTAINER_NAME}"
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
    echo -e "│ ${YELLOW}Project Name${NC}        │ $new_project │"
    echo -e "│ ${YELLOW}Container Name${NC}      │ $new_container_full │"
    echo -e "└──────────────────────┴────────────────────────────┘"

    # 6. Verification
    echo -e "\n${CYAN}📋 VERIFICATION:${NC}"
    echo -e "Current values in $ENV_FILE:"
    grep -E "^(PROJECT_NAME|CONTAINER_NAME)=" "$ENV_FILE"
}

# =============================================================================
# MANAGEMENT FUNCTIONS
# =============================================================================

# Function: Start container
node_start() {
    load_config || return 1
    log "Starting Node.js development server..."

    if docker compose -f "$COMPOSE_FILE" up -d; then
        echo -e "\n${GREEN}🎨 VITE DEVELOPMENT SERVER STARTED${NC}"
        echo -e "┌──────────────────────┬────────────────────────────┐"
        echo -e "│ ${YELLOW}Project${NC}             │ $PROJECT_NAME │"
        echo -e "│ ${YELLOW}Container${NC}           │ $CONTAINER_NAME │"
        echo -e "│ ${YELLOW}Dev Server${NC}          │ ${GREEN}http://localhost:5173${NC} │"
        echo -e "│ ${YELLOW}Hot Reload${NC}          │ ${GREEN}Enabled${NC} │"
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
    echo -e "│ ${YELLOW}Container${NC}            │ $(container_status) │"
    echo -e "│ ${YELLOW}Project${NC}              │ $PROJECT_NAME │"
    echo -e "│ ${YELLOW}Container Base${NC}       │ $container_base │"
    echo -e "│ ${YELLOW}Container Full${NC}       │ $CONTAINER_NAME │"
    echo -e "│ ${YELLOW}Vite Dev Server${NC}      │ http://localhost:5173 │"
    echo -e "└──────────────────────┴────────────────────────────┘"

    if is_running; then
        echo -e "\n${GREEN}✅ Ready for development!${NC}"
    else
        echo -e "\n${YELLOW}⚠️  Container is stopped - use 'go --node start'${NC}"
    fi
}

# =============================================================================
# DEVELOPMENT FUNCTIONS
# =============================================================================

# Function: Install dependencies
node_install() {
    log "Installing Node.js dependencies..."
    load_config

    if docker compose -f "$COMPOSE_FILE" run --rm node sh -c "npm install"; then
        log "Dependencies installed successfully"
    else
        error "Failed to install dependencies"
        return 1
    fi
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

# =============================================================================
# DEBUG FUNCTIONS
# =============================================================================

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
    # No forced cd! We trust docker-compose.yml working_dir
    docker compose -f "$COMPOSE_FILE" exec node npm "$@"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

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

# Function: Initial setup
node_setup() {
    log "Running initial setup..."
    node_config
    node_install
    node_start
    node_status
}

# =============================================================================
# HELPERS
# =============================================================================

log() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${BLUE}ℹ${NC} $1"; }

# =============================================================================
# MAIN MENU
# =============================================================================

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
