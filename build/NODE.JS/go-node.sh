#!/bin/bash

# =============================================================================
# NODE.JS DEVELOPMENT SCRIPT
# Gestión de containers Node.js para desarrollo Laravel
# =============================================================================

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# FUNCIONES PRINCIPALES
# =============================================================================

# Función: Cargar configuración
load_config() {
    if [ -f "$ENV_FILE" ]; then
        export $(grep -v '^#' "$ENV_FILE" | xargs)
        PROJECT_NAME="${PROJECT_NAME:-vernizus}"
        CONTAINER_NAME="${CONTAINER_NAME:-default_app}"
        
        # Asegurar que CONTAINER_NAME siempre tenga _node al final
        CONTAINER_NAME="${CONTAINER_NAME%_node}_node"
    else
        PROJECT_NAME="vernizus"
        CONTAINER_NAME="default_app_node"
        warn "No .env file found, using defaults"
    fi
}

# Función: Configuración interactiva
node_config() {
    echo ""
    echo -e "${CYAN}🔧 NODE.JS CONTAINER CONFIGURATION${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    
    # Verificar si el archivo existe
    if [ ! -f "$ENV_FILE" ]; then
        error "File $ENV_FILE not found"
        echo "Please create the .env file first with PROJECT_NAME and CONTAINER_NAME"
        return 1
    fi

    # Valores actuales
    local current_project=$(grep '^PROJECT_NAME=' "$ENV_FILE" | cut -d'=' -f2)
    local current_container=$(grep '^CONTAINER_NAME=' "$ENV_FILE" | cut -d'=' -f2)
    
    current_project=${current_project:-"vernizus"}
    current_container=${current_container:-"default_app"}
    
    # Remover _node si ya existe para mostrar limpio
    current_container=${current_container%_node}

    # 1. Pedir nombre del proyecto
    echo -e "${YELLOW}Project name:${NC}"
    read -p "  [current: $current_project] (Enter = keep): " new_project
    new_project=${new_project:-$current_project}

    # 2. Pedir nombre del container (BASE, sin _node)
    echo -e "\n${YELLOW}Container base name:${NC}"
    echo -e "  '_node' will be automatically added"
    read -p "  [current: $current_container] (Enter = keep): " new_container_base
    new_container_base=${new_container_base:-$current_container}
    
    # Limpiar _node si lo tiene
    new_container_base=${new_container_base%_node}

    # 3. Actualizar con sed
    sed -i \
        -e "s|^PROJECT_NAME=.*|PROJECT_NAME=$new_project|" \
        -e "s|^CONTAINER_NAME=.*|CONTAINER_NAME=$new_container_base|" \
        "$ENV_FILE"

    # 4. Mostrar resumen
    echo -e "\n${GREEN}✅ CONFIGURATION UPDATED${NC}"
    echo -e "┌──────────────────────┬────────────────────────────┐"
    echo -e "│ ${YELLOW}Project Name${NC}        │ $new_project │"
    echo -e "│ ${YELLOW}Container Base${NC}      │ $new_container_base │"
    echo -e "│ ${YELLOW}Container Full${NC}      │ ${new_container_base}_node │"
    echo -e "└──────────────────────┴────────────────────────────┘"
}

# Función: Verificar si el container está corriendo
is_running() {
    docker ps --format 'table {{.Names}}' | grep -q "${CONTAINER_NAME}"
}

# Función: Ver estado del container
container_status() {
    if is_running; then
        echo -e "${GREEN}RUNNING${NC}"
    else
        echo -e "${RED}STOPPED${NC}"
    fi
}

# =============================================================================
# FUNCIONES DE GESTIÓN
# =============================================================================

# Función: Iniciar container
node_start() {
    log "Starting Node.js container..."
    if docker compose -f "$COMPOSE_FILE" up -d > /dev/null 2>&1; then
        log "Node.js container started successfully"
        node_status
    else
        error "Failed to start Node.js container"
        return 1
    fi
}

# Función: Parar container
node_stop() {
    log "Stopping Node.js container..."
    if docker compose -f "$COMPOSE_FILE" down > /dev/null 2>&1; then
        log "Node.js container stopped"
    else
        error "Failed to stop Node.js container"
        return 1
    fi
}

# Función: Reiniciar container
node_restart() {
    log "Restarting Node.js container..."
    node_stop
    sleep 2
    node_start
}

# Función: Ver estado
node_status() {
    load_config
    local container_base="${CONTAINER_NAME%_node}"
    
    echo -e "\n${CYAN}📊 NODE.JS CONTAINER STATUS${NC}"
    echo -e "┌──────────────────────┬────────────────────────────┐"
    echo -e "│ ${YELLOW}Container${NC}           │ $(container_status) │"
    echo -e "│ ${YELLOW}Project${NC}             │ $PROJECT_NAME │"
    echo -e "│ ${YELLOW}Container Base${NC}      │ $container_base │"
    echo -e "│ ${YELLOW}Container Full${NC}      │ $CONTAINER_NAME │"
    echo -e "│ ${YELLOW}Vite Dev Server${NC}     │ http://localhost:5173 │"
    echo -e "└──────────────────────┴────────────────────────────┘"

    if is_running; then
        echo -e "\n${GREEN}✅ Ready for development!${NC}"
    else
        echo -e "\n${YELLOW}⚠️  Container is stopped - use 'go --node start'${NC}"
    fi
}

# =============================================================================
# FUNCIONES DE DESARROLLO
# =============================================================================

# Función: Instalar dependencias
node_install() {
    log "Installing Node.js dependencies..."
    load_config

    if docker compose -f "$COMPOSE_FILE" run --rm node sh -c "cd $PROJECT_NAME && npm install"; then
        log "Dependencies installed successfully"
    else
        error "Failed to install dependencies"
        return 1
    fi
}

# Función: Modo desarrollo
node_dev() {
    log "Starting development mode..."
    load_config

    if node_start; then
        echo -e "\n${GREEN}🎨 VITE DEVELOPMENT SERVER STARTED${NC}"
        echo -e "┌──────────────────────┬────────────────────────────┐"
        echo -e "│ ${YELLOW}Project${NC}             │ $PROJECT_NAME │"
        echo -e "│ ${YELLOW}Container${NC}           │ $CONTAINER_NAME │"
        echo -e "│ ${YELLOW}Dev Server${NC}          │ ${GREEN}http://localhost:5173${NC} │"
        echo -e "│ ${YELLOW}Hot Reload${NC}          │ ${GREEN}Enabled${NC} │"
        echo -e "└──────────────────────┴────────────────────────────┘"
        echo -e "\n${CYAN}📝 Changes in resources/ will trigger automatic rebuild${NC}"
    else
        error "Failed to start development mode"
        return 1
    fi
}

# Función: Build para producción
node_build() {
    log "Building production assets..."
    load_config

    if docker compose -f "$COMPOSE_FILE" run --rm node sh -c "cd $PROJECT_NAME && npm run build"; then
        log "Production build completed successfully"
        echo -e "\n${GREEN}✅ Assets ready in: public/build/${NC}"
    else
        error "Build failed"
        return 1
    fi
}

# =============================================================================
# FUNCIONES DE DEBUG
# =============================================================================

# Función: Ver logs
node_logs() {
    if is_running; then
        log "Showing logs (Ctrl+C to exit)..."
        docker compose -f "$COMPOSE_FILE" logs -f node
    else
        error "Node.js container is not running"
        return 1
    fi
}

# Función: Shell interactivo
node_shell() {
    if is_running; then
        log "Entering container shell..."
        docker compose -f "$COMPOSE_FILE" exec node sh
    else
        error "Node.js container is not running"
        return 1
    fi
}

# Función: Ejecutar comando npm
node_npm() {
    if is_running; then
        load_config
        local npm_command="$*"
        if [ -z "$npm_command" ]; then
            error "No npm command provided"
            return 1
        fi

        log "Executing: npm $npm_command"
        docker compose -f "$COMPOSE_FILE" exec node sh -c "cd $PROJECT_NAME && npm $npm_command"
    else
        error "Node.js container is not running"
        return 1
    fi
}

# =============================================================================
# FUNCIONES DE UTILIDAD
# =============================================================================

# Función: Limpiar todo
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

# Función: Setup inicial
node_setup() {
    log "Running initial setup..."
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
# MENU PRINCIPAL
# =============================================================================

main() {
    load_config

    case "$1" in
        # Gestión de containers
        start|up)          node_start ;;
        stop|down)         node_stop ;;
        restart)           node_restart ;;
        status)            node_status ;;

        # Desarrollo
        install)           node_install ;;
        dev)               node_dev ;;
        build)             node_build ;;

        # Configuración
        config)            node_config ;;

        # Debug
        logs)              node_logs ;;
        shell)             node_shell ;;
        npm)               shift; node_npm "$@" ;;

        # Utilidades
        clean)             node_clean ;;
        setup)             node_setup ;;

        # Ayuda
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
    echo "  start, up     Start Node.js container"
    echo "  stop, down    Stop Node.js container"
    echo "  restart       Restart Node.js container"
    echo "  status        Show container status"
    echo
    echo -e "${GREEN}DEVELOPMENT:${NC}"
    echo "  install       Install npm dependencies"
    echo "  dev           Start Vite development server"
    echo "  build         Build for production"
    echo "  npm <cmd>     Run any npm command"
    echo
    echo -e "${GREEN}CONFIGURATION:${NC}"
    echo "  config        Interactive configuration"
    echo
    echo -e "${GREEN}DEBUGGING:${NC}"
    echo "  logs          Show container logs"
    echo "  shell         Enter container shell"
    echo
    echo -e "${GREEN}UTILITIES:${NC}"
    echo "  clean         Stop and remove containers/volumes"
    echo "  setup         Initial setup (install + start)"
    echo "  help          Show this help"
    echo
    echo -e "${YELLOW}EXAMPLES:${NC}"
    echo "  go --node config      # Configure container"
    echo "  go --node setup       # First-time setup"
    echo "  go --node dev         # Start development"
    echo "  go --node npm test    # Run tests"
}

# =============================================================================
# EJECUCIÓN
# =============================================================================

# Cargar configuración al inicio
load_config

# Ejecutar comando
if [ $# -eq 0 ]; then
    show_help
else
    main "$@"
fi
