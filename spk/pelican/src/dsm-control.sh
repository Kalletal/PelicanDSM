#!/bin/sh

# Pelican Panel - DSM Start/Stop/Status Script

PACKAGE="pelican_panel"
DNAME="Pelican Panel"
INSTALL_DIR="/var/packages/${PACKAGE}/target"
VAR_DIR="/var/packages/${PACKAGE}/var"
LOG_FILE="${VAR_DIR}/${PACKAGE}.log"

# Docker compose paths
COMPOSE_FILE="${INSTALL_DIR}/share/docker/compose.yaml"
ENV_FILE="${VAR_DIR}/panel.env"

# Wings config path (container managed via Docker Compose)
WINGS_CONFIG="${VAR_DIR}/data/wings/config.yml"

# Loading proxy
LOADING_PROXY="${INSTALL_DIR}/bin/loading-proxy.py"
LOADING_HTML="${INSTALL_DIR}/share/loading.html"
PROXY_PID_FILE="${VAR_DIR}/loading-proxy.pid"

# Ports
PANEL_PORT="8080"           # Public port (served by proxy)
PANEL_INTERNAL_PORT="8090"  # Internal Docker port

# Get port from env file if available
get_panel_port() {
    if [ -f "${ENV_FILE}" ]; then
        PORT=$(grep -E "^PANEL_PORT=" "${ENV_FILE}" | cut -d'=' -f2 | tr -d '"')
        [ -n "$PORT" ] && PANEL_PORT="$PORT"
    fi
}

get_panel_port

PATH="${INSTALL_DIR}/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Detect docker compose command
if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" >> "${LOG_FILE}" 2>/dev/null
}

# Start the loading proxy on the public port
start_loading_proxy()
{
    if [ ! -f "${LOADING_PROXY}" ]; then
        log "Loading proxy not found at ${LOADING_PROXY}"
        return 1
    fi

    # Stop any existing proxy
    stop_loading_proxy

    log "Starting loading proxy on port ${PANEL_PORT} (forwarding to ${PANEL_INTERNAL_PORT})..."

    # Start proxy in background
    python3 "${LOADING_PROXY}" "${PANEL_PORT}" "${PANEL_INTERNAL_PORT}" "${LOADING_HTML}" >> "${LOG_FILE}" 2>&1 &
    PROXY_PID=$!
    echo "${PROXY_PID}" > "${PROXY_PID_FILE}"

    sleep 1
    if kill -0 "${PROXY_PID}" 2>/dev/null; then
        log "Loading proxy started (PID: ${PROXY_PID})"
        return 0
    else
        log "Failed to start loading proxy"
        return 1
    fi
}

# Stop the loading proxy
stop_loading_proxy()
{
    if [ -f "${PROXY_PID_FILE}" ]; then
        PID=$(cat "${PROXY_PID_FILE}" 2>/dev/null)
        if [ -n "${PID}" ] && kill -0 "${PID}" 2>/dev/null; then
            log "Stopping loading proxy (PID: ${PID})"
            kill "${PID}" 2>/dev/null
            sleep 1
            kill -9 "${PID}" 2>/dev/null
        fi
        rm -f "${PROXY_PID_FILE}"
    fi

    # Kill any remaining python proxy processes
    pkill -f "loading-proxy.py.*${PANEL_PORT}" 2>/dev/null || true
}

# Check if proxy is running
proxy_running()
{
    [ -f "${PROXY_PID_FILE}" ] && kill -0 "$(cat "${PROXY_PID_FILE}" 2>/dev/null)" 2>/dev/null
}

ensure_port_free()
{
    local port="$1"
    log "Ensuring port ${port} is free..."

    if command -v fuser >/dev/null 2>&1; then
        fuser -k ${port}/tcp 2>/dev/null
        sleep 1
    fi

    PID_ON_PORT=$(lsof -t -i:${port} 2>/dev/null)
    if [ -n "${PID_ON_PORT}" ]; then
        log "Killing process ${PID_ON_PORT} on port ${port}"
        kill -9 ${PID_ON_PORT} 2>/dev/null
        sleep 1
    fi

    if netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
        log "WARNING: Port ${port} still in use"
        return 1
    fi

    log "Port ${port} is free"
    return 0
}

fix_permissions()
{
    log "Fixing permissions for container volumes..."
    DATA_DIR="${VAR_DIR}/data"

    mkdir -p "${DATA_DIR}/pelican-data"
    mkdir -p "${DATA_DIR}/pelican-logs"
    mkdir -p "${DATA_DIR}/pelican-logs/supervisord"

    chmod -R 777 "${DATA_DIR}/pelican-data" 2>/dev/null || true
    chmod -R 777 "${DATA_DIR}/pelican-logs" 2>/dev/null || true

    log "Permissions fixed"
}

# Check if container is healthy
check_container_health()
{
    CONTAINER_NAME="${PACKAGE}-panel-1"

    if ! docker ps --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' 2>/dev/null | grep -q "${CONTAINER_NAME}"; then
        return 1
    fi

    docker exec "${CONTAINER_NAME}" curl -sf http://localhost:8080/api/health >/dev/null 2>&1
    return $?
}

containers_running()
{
    docker ps --filter "name=${PACKAGE}" --format '{{.Names}}' 2>/dev/null | grep -q "${PACKAGE}"
}

wait_for_migrations()
{
    CONTAINER_NAME="${PACKAGE}-panel-1"
    log "Waiting for migrations to complete..."

    # Wait for migrations by checking if database has users table
    for i in $(seq 1 60); do
        # Check if migrations are done by looking for a key table
        TABLES=$(docker exec "${CONTAINER_NAME}" php artisan tinker --execute="echo Schema::hasTable('users') ? 'ready' : 'waiting';" 2>/dev/null | tr -d '\n' | grep -o 'ready\|waiting')
        if [ "${TABLES}" = "ready" ]; then
            log "Database migrations completed"
            return 0
        fi
        sleep 5
    done
    log "Timeout waiting for migrations"
    return 1
}

create_admin_user()
{
    if [ -f "${ENV_FILE}" ]; then
        ADMIN_CREATED=$(grep -E "^ADMIN_CREATED=" "${ENV_FILE}" | cut -d'=' -f2 | tr -d '"' || echo "false")
        if [ "${ADMIN_CREATED}" = "true" ]; then
            log "Admin user already created, skipping"
            return 0
        fi
    fi

    ADMIN_EMAIL=$(grep -E "^ADMIN_EMAIL=" "${ENV_FILE}" | cut -d'=' -f2 | tr -d '"' || echo "admin@example.com")
    ADMIN_USERNAME=$(grep -E "^ADMIN_USERNAME=" "${ENV_FILE}" | cut -d'=' -f2 | tr -d '"' || echo "admin")
    ADMIN_PASSWORD=$(grep -E "^ADMIN_PASSWORD=" "${ENV_FILE}" | cut -d'=' -f2 | tr -d '"' || echo "")

    if [ -z "${ADMIN_PASSWORD}" ]; then
        log "No admin password configured, skipping admin creation"
        return 1
    fi

    log "Creating admin user: ${ADMIN_USERNAME} (${ADMIN_EMAIL})..."
    log "Password length: ${#ADMIN_PASSWORD} characters"

    CONTAINER_NAME="${PACKAGE}-panel-1"

    if ! docker ps --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' | grep -q "${CONTAINER_NAME}"; then
        log "Panel container not found, cannot create admin"
        return 1
    fi

    # Wait longer for migrations to fully complete
    sleep 10

    # Try to create user with retries
    for attempt in 1 2 3; do
        log "Admin creation attempt ${attempt}/3..."

        RESULT=$(docker exec "${CONTAINER_NAME}" php artisan p:user:make \
            --email="${ADMIN_EMAIL}" \
            --username="${ADMIN_USERNAME}" \
            --password="${ADMIN_PASSWORD}" \
            --admin=1 \
            --no-interaction 2>&1)

        log "Artisan output: ${RESULT}"

        # Check for success - artisan outputs a table with UUID when successful
        if echo "${RESULT}" | grep -qiE "(created|success|already exists|user.* created|UUID)"; then
            log "Admin user created successfully"
            sed -i "s#ADMIN_CREATED=.*#ADMIN_CREATED=true#" "${ENV_FILE}"
            return 0
        fi

        if echo "${RESULT}" | grep -qiE "(already|duplicate|exists|unique constraint)"; then
            log "Admin user already exists"
            sed -i "s#ADMIN_CREATED=.*#ADMIN_CREATED=true#" "${ENV_FILE}"
            return 0
        fi

        # Wait before retry
        sleep 10
    done

    log "Failed to create admin after 3 attempts. Last result: ${RESULT}"
    return 1
}

start_containers()
{
    if [ ! -f "${COMPOSE_FILE}" ]; then
        log "ERROR: compose.yaml not found at ${COMPOSE_FILE}"
        return 1
    fi
    if [ ! -f "${ENV_FILE}" ]; then
        log "ERROR: panel.env not found at ${ENV_FILE}"
        return 1
    fi

    fix_permissions

    # Check if already running and healthy
    if containers_running && check_container_health; then
        log "Docker containers already running and healthy"
        # Make sure proxy is running
        if ! proxy_running; then
            start_loading_proxy
        fi
        return 0
    fi

    # STEP 1: Ensure ports are free
    ensure_port_free "${PANEL_PORT}"
    ensure_port_free "${PANEL_INTERNAL_PORT}"

    # STEP 2: Start the loading proxy on public port FIRST
    # This gives immediate feedback to users
    log "Starting loading proxy..."
    start_loading_proxy

    # STEP 3: Pull Docker images
    log "Pulling Docker images..."
    ${DOCKER_COMPOSE} --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" -p "${PACKAGE}" pull >> "${LOG_FILE}" 2>&1

    # STEP 4: Start Docker containers (they use internal port 8090)
    log "Starting Docker containers..."
    ${DOCKER_COMPOSE} --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" -p "${PACKAGE}" up -d >> "${LOG_FILE}" 2>&1

    log "Docker containers started. Panel initializing..."
    log "Users can access http://<IP>:${PANEL_PORT} - loading page shown until Panel is ready"

    # STEP 5: Wait for panel and create admin in background
    (
        log "Waiting for Panel to be ready..."

        # First wait for container health check
        for i in $(seq 1 120); do
            if check_container_health; then
                log "Panel health check passed!"
                break
            fi
            sleep 5
        done

        if ! check_container_health; then
            log "Panel initialization timeout after 10 minutes"
            exit 1
        fi

        # Wait additional time for migrations to complete
        log "Waiting for migrations to finish..."
        wait_for_migrations

        # Create admin user
        log "Creating admin user..."
        create_admin_user

        log "Panel fully initialized"
    ) >> "${LOG_FILE}" 2>&1 &

    return 0
}

stop_containers()
{
    log "Stopping Docker containers..."

    if [ -f "${COMPOSE_FILE}" ] && [ -f "${ENV_FILE}" ]; then
        ${DOCKER_COMPOSE} --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" -p "${PACKAGE}" down >> "${LOG_FILE}" 2>&1
    fi

    CONTAINERS=$(docker ps -q --filter "name=${PACKAGE}" 2>/dev/null)
    if [ -n "${CONTAINERS}" ]; then
        log "Force stopping remaining containers..."
        docker stop ${CONTAINERS} >> "${LOG_FILE}" 2>&1
        docker rm -f ${CONTAINERS} >> "${LOG_FILE}" 2>&1
    fi

    if containers_running; then
        log "WARNING: Some containers may still be running"
    else
        log "Docker containers stopped"
    fi
}

start_wings()
{
    # Wings is now managed as a Docker container in compose.yaml
    # It starts automatically with docker compose up
    log "Wings container is managed via Docker Compose"
}

stop_wings()
{
    # Wings is now managed as a Docker container in compose.yaml
    # It stops automatically with docker compose down
    log "Wings container is managed via Docker Compose"
}

case "$1" in
    start)
        echo "Démarrage de ${DNAME}"
        log "Starting ${DNAME}"
        start_containers
        start_wings
        exit 0
        ;;
    stop)
        echo "Arrêt de ${DNAME}"
        log "Stopping ${DNAME}"
        stop_wings
        stop_loading_proxy
        stop_containers
        exit 0
        ;;
    status)
        if containers_running || proxy_running; then
            echo "${DNAME} est en cours d'exécution"
            exit 0
        else
            echo "${DNAME} n'est pas en cours d'exécution"
            exit 1
        fi
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    log)
        tail -n 200 -f "${LOG_FILE}"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|log}"
        exit 1
        ;;
esac
