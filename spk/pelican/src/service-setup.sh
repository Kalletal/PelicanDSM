# Pelican Panel - Service Setup Script
# Lifecycle hooks for SPK installation/upgrade/uninstall

ENV_EXAMPLE="${SYNOPKG_PKGDEST}/share/panel.env.example"
WINGS_CONFIG_EXAMPLE="${SYNOPKG_PKGDEST}/share/wings.config.example.yml"
VAR_DIR="${SYNOPKG_PKGVAR}"
DATA_DIR="${VAR_DIR}/data"
LOG_DIR="${VAR_DIR}/logs"
ENV_FILE="${VAR_DIR}/panel.env"
WINGS_CONFIG="${DATA_DIR}/wings/config.yml"

# Cleanup function - called on uninstall or failed install
cleanup_package()
{
    # Stop and remove Docker containers
    docker rm -f pelican_panel-panel-1 2>/dev/null || true
    docker rm -f pelican_panel-wings-1 2>/dev/null || true
    docker rm -f pelican_panel-panel 2>/dev/null || true

    # Remove Docker network
    docker network rm pelican_network 2>/dev/null || true

    # Remove user from docker group
    if getent group docker >/dev/null 2>&1 && [ -n "${EFF_USER}" ]; then
        delgroup "${EFF_USER}" docker 2>/dev/null || true
    fi
}

service_preinst()
{
    # Validate password confirmation
    if [ -n "${wizard_admin_password}" ] && [ -n "${wizard_admin_password_confirm}" ]; then
        if [ "${wizard_admin_password}" != "${wizard_admin_password_confirm}" ]; then
            echo "Les mots de passe ne correspondent pas." >&2
            exit 1
        fi
    fi
    return 0
}

create_data_dirs()
{
    install -d -m 0750 "${VAR_DIR}"
    # Pelican data directory (SQLite DB, uploads, cache)
    mkdir -p "${DATA_DIR}/pelican-data" 2>/dev/null || true
    # Application logs
    mkdir -p "${DATA_DIR}/pelican-logs" 2>/dev/null || true
    # Wings directories
    mkdir -p "${DATA_DIR}/wings" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/servers" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/backups" 2>/dev/null || true
    mkdir -p "${DATA_DIR}/wings-logs" 2>/dev/null || true
    # Package logs
    install -d -m 0750 "${LOG_DIR}" 2>/dev/null || mkdir -p "${LOG_DIR}"
}

generate_app_key()
{
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 32 | tr -d '\n'
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import secrets,base64;print(base64.b64encode(secrets.token_bytes(32)).decode())"
    else
        tr -dc 'A-Za-z0-9' </dev/urandom | head -c 43
    fi
}

detect_nas_ip()
{
    # Try to get the primary IP address of the NAS
    # Method 1: Get IP from default route interface
    local default_iface=$(ip route | grep default | head -1 | awk '{print $5}')
    if [ -n "$default_iface" ]; then
        local ip=$(ip -4 addr show "$default_iface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        if [ -n "$ip" ]; then
            echo "$ip"
            return
        fi
    fi
    # Method 2: Get first non-localhost IPv4
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1
}

hydrate_env_file()
{
    if [ ! -f "${ENV_FILE}" ] && [ -f "${ENV_EXAMPLE}" ]; then
        install -m 0600 "${ENV_EXAMPLE}" "${ENV_FILE}"

        # Generate APP_KEY
        APP_KEY=$(generate_app_key)
        sed -i "s#APP_KEY=.*#APP_KEY=base64:${APP_KEY}#" "${ENV_FILE}"

        # Apply wizard values - auto-detect IP if not provided or localhost
        local app_host="${wizard_host}"
        if [ -z "$app_host" ] || [ "$app_host" = "localhost" ]; then
            app_host=$(detect_nas_ip)
            # Fallback to localhost if detection fails
            app_host="${app_host:-localhost}"
        fi
        local app_port="${wizard_port:-8080}"
        local app_url="http://${app_host}:${app_port}"
        local admin_email="${wizard_admin_email:-admin@example.com}"
        local app_locale="${wizard_locale:-fr}"

        sed -i "s#APP_URL=.*#APP_URL=${app_url}#" "${ENV_FILE}"
        sed -i "s#PANEL_PORT=.*#PANEL_PORT=${app_port}#" "${ENV_FILE}"
        sed -i "s#ADMIN_EMAIL=.*#ADMIN_EMAIL=${admin_email}#" "${ENV_FILE}"
        sed -i "s#APP_LOCALE=.*#APP_LOCALE=${app_locale}#" "${ENV_FILE}"

        # Admin account configuration
        local admin_username="${wizard_admin_username:-admin}"
        local admin_password="${wizard_admin_password:-ChangeMe123!}"

        sed -i "s#ADMIN_USERNAME=.*#ADMIN_USERNAME=${admin_username}#" "${ENV_FILE}"
        sed -i "s#ADMIN_PASSWORD=.*#ADMIN_PASSWORD=${admin_password}#" "${ENV_FILE}"

        # Update Wings Panel URL
        sed -i "s#WINGS_PANEL_URL=.*#WINGS_PANEL_URL=${app_url}#" "${ENV_FILE}"
    fi
}

hydrate_wings_config()
{
    if [ ! -f "${WINGS_CONFIG}" ] && [ -f "${WINGS_CONFIG_EXAMPLE}" ]; then
        install -d -m 0770 "${DATA_DIR}/wings"
        install -m 0640 "${WINGS_CONFIG_EXAMPLE}" "${WINGS_CONFIG}"
    fi
}


service_postinst()
{
    create_data_dirs
    hydrate_env_file
    hydrate_wings_config
    install -d -m 0750 "${VAR_DIR}/runtime"
    touch "${VAR_DIR}/pelican.log"
    chmod 0640 "${VAR_DIR}/pelican.log"

    # Only chown specific files, not recursively (Docker manages its own data permissions)
    if [ -n "${EFF_USER}" ]; then
        chown "${EFF_USER}:${EFF_USER}" "${VAR_DIR}" "${LOG_DIR}" "${VAR_DIR}/runtime" 2>/dev/null || true
        chown "${EFF_USER}:${EFF_USER}" "${ENV_FILE}" "${VAR_DIR}/pelican.log" 2>/dev/null || true
        chown "${EFF_USER}:${EFF_USER}" "${WINGS_CONFIG}" 2>/dev/null || true
    fi

    if getent group docker >/dev/null 2>&1 && [ -n "${EFF_USER}" ]; then
        addgroup "${EFF_USER}" docker 2>/dev/null || true
    fi
}

service_preupgrade()
{
    # Only backup config files - Docker data is persistent and doesn't need copying
    if [ -d "${SYNOPKG_TEMP_UPGRADE_FOLDER}" ]; then
        cp -a "${ENV_FILE}" "${SYNOPKG_TEMP_UPGRADE_FOLDER}/panel.env" 2>/dev/null || true
        cp -a "${WINGS_CONFIG}" "${SYNOPKG_TEMP_UPGRADE_FOLDER}/wings.config.yml" 2>/dev/null || true
    fi
}

service_postupgrade()
{
    # Create any missing directories (for upgrades from older versions)
    create_data_dirs

    # Restore config files only - Docker data stays in place
    if [ -f "${SYNOPKG_TEMP_UPGRADE_FOLDER}/panel.env" ]; then
        install -m 0600 "${SYNOPKG_TEMP_UPGRADE_FOLDER}/panel.env" "${ENV_FILE}"
    fi
    if [ -f "${SYNOPKG_TEMP_UPGRADE_FOLDER}/wings.config.yml" ]; then
        install -m 0640 "${SYNOPKG_TEMP_UPGRADE_FOLDER}/wings.config.yml" "${WINGS_CONFIG}"
    fi
    # Only chown config files, not the entire data directory
    if [ -n "${EFF_USER}" ]; then
        chown "${EFF_USER}:${EFF_USER}" "${ENV_FILE}" 2>/dev/null || true
        chown "${EFF_USER}:${EFF_USER}" "${WINGS_CONFIG}" 2>/dev/null || true
        chown -R "${EFF_USER}:docker" "${DATA_DIR}" 2>/dev/null || true
    fi
}

service_preuninst()
{
    # Stop containers quickly (1 second timeout instead of default 10)
    docker stop -t 1 pelican_panel-panel-1 2>/dev/null || true
    docker stop -t 1 pelican_panel-wings-1 2>/dev/null || true
    docker stop -t 1 pelican_panel-panel 2>/dev/null || true
}

service_postuninst()
{
    # Always cleanup containers and system files
    cleanup_package

    # Delete data if user chose to
    if [ "${wizard_delete_data}" = "true" ]; then
        rm -rf "/var/packages/pelican_panel/var" 2>/dev/null || true
        rm -rf "/volume1/@appdata/pelican_panel" 2>/dev/null || true
    fi
}
