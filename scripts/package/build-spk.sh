#!/bin/bash
# Build script for Pelican Panel SPK package
# Creates a proper Synology SPK package following spksrc conventions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPK_SRC="${ROOT_DIR}/spk/pelican/src"
DIST_DIR="${ROOT_DIR}/dist"
WORK_DIR="${ROOT_DIR}/.build"
VERSION_SCRIPT="${SCRIPT_DIR}/version.sh"

# Package info
PKG_NAME="pelican_panel"
ARCH="geminilake"  # DS920+, DS720+, DS420+, DS220+ (Intel Celeron J4125)
DSM_MIN_VER="7.2-72806"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Clean previous builds
clean_previous() {
    log_info "Cleaning previous builds..."
    rm -rf "${DIST_DIR}"/*.spk 2>/dev/null || true
    rm -rf "${WORK_DIR}" 2>/dev/null || true
    log_success "Previous builds cleaned"
}

# Increment version for this build
increment_version() {
    log_info "Incrementing build revision..."
    chmod +x "${VERSION_SCRIPT}"
    "${VERSION_SCRIPT}" init >/dev/null 2>&1
    "${VERSION_SCRIPT}" bump-rev
    "${VERSION_SCRIPT}" update-makefile
}

# Get current version
get_version() {
    chmod +x "${VERSION_SCRIPT}"
    "${VERSION_SCRIPT}" get-full
}

# Create the package.tgz content (what goes in /var/packages/PKG/target/)
create_package_content() {
    log_info "Creating package content..."

    local PKG_DIR="${WORK_DIR}/package"
    mkdir -p "${PKG_DIR}"

    # Create target directory structure
    mkdir -p "${PKG_DIR}/share/docker"
    mkdir -p "${PKG_DIR}/app/images"
    mkdir -p "${PKG_DIR}/bin"

    # Docker compose
    cp "${SPK_SRC}/docker/compose.yaml" "${PKG_DIR}/share/docker/"

    # Configuration templates
    cp "${SPK_SRC}/panel.env.example" "${PKG_DIR}/share/"
    cp "${SPK_SRC}/wings.config.example.yml" "${PKG_DIR}/share/"

    # Loading page and proxy
    cp "${SPK_SRC}/loading.html" "${PKG_DIR}/share/"

    # Instructions page (shown after loading, before Pelican installer)
    mkdir -p "${PKG_DIR}/share/app"
    cp "${SPK_SRC}/app/instructions.html" "${PKG_DIR}/share/app/"
    chmod 644 "${PKG_DIR}/share/app/instructions.html"
    cp "${SPK_SRC}/loading-server.sh" "${PKG_DIR}/bin/"
    cp "${SPK_SRC}/loading-proxy.py" "${PKG_DIR}/bin/"
    chmod +x "${PKG_DIR}/bin/loading-server.sh"
    chmod +x "${PKG_DIR}/bin/loading-proxy.py"

    # DSM UI config - must be readable by DSM (644 permissions)
    cp "${SPK_SRC}/app/config" "${PKG_DIR}/app/"
    chmod 644 "${PKG_DIR}/app/config"

    # Wings configuration embedded application for DSM 7.2+
    cp "${SPK_SRC}/app/PelicanWings.js" "${PKG_DIR}/app/"
    chmod 644 "${PKG_DIR}/app/PelicanWings.js"

    # Wings configuration HTML page (loaded in iframe)
    cp "${SPK_SRC}/app/wings-config.html" "${PKG_DIR}/app/"
    chmod 644 "${PKG_DIR}/app/wings-config.html"

    # Wings API CGI proxy (for same-origin API calls)
    cp "${SPK_SRC}/app/api.cgi" "${PKG_DIR}/app/"
    chmod 755 "${PKG_DIR}/app/api.cgi"

    # Firewall port configuration (must be in package.tgz/app/ for resource to find it)
    cp "${SPK_SRC}/app/pelican_panel.sc" "${PKG_DIR}/app/"
    chmod 644 "${PKG_DIR}/app/pelican_panel.sc"

    # Copy icons if they exist - must be readable (644 permissions)
    if ls "${SPK_SRC}/app/images/"*.png >/dev/null 2>&1; then
        cp "${SPK_SRC}/app/images/"*.png "${PKG_DIR}/app/images/"
        chmod 644 "${PKG_DIR}/app/images/"*.png
    fi

    log_success "Package content created"
}

# Create package.tgz
create_package_tgz() {
    log_info "Creating package.tgz..."
    cd "${WORK_DIR}/package"
    tar czf "${WORK_DIR}/package.tgz" .
    log_success "package.tgz created"
}

# Create INFO file (following spksrc format exactly)
create_info_file() {
    local version=$("${VERSION_SCRIPT}" get)
    local revision=$("${VERSION_SCRIPT}" get-rev)

    log_info "Creating INFO file (version: ${version}-${revision})..."

    cat > "${WORK_DIR}/INFO" << EOF
package="${PKG_NAME}"
version="${version}-${revision}"
description="Pelican Panel - Gérez vos serveurs de jeux (Minecraft, Terraria, etc.) sur votre NAS Synology. Configuration de Wings: 1) Connectez-vous au Panel 2) Admin > Nodes > Create New 3) Configurez avec IP/FQDN du NAS 4) Configuration > Generate Token 5) Menu DSM > Configurer Wings 6) Collez le YAML et enregistrez."

arch="${ARCH}"
maintainer="Pelican Synology Builders"
maintainer_url="https://github.com/pelican-dev/panel"
distributor=""
distributor_url=""
os_min_ver="${DSM_MIN_VER}"
helpurl="https://pelican.dev/docs"
displayname="Pelican Panel"
dsmuidir="app"
dsmappname="com.synocommunity.packages.${PKG_NAME}"
changelog="Initial release with French language support."
support_conf_folder="yes"
EOF

    log_success "INFO file created"
}

# Create the scripts directory with proper spksrc-compatible scripts
create_scripts() {
    log_info "Creating package scripts..."

    mkdir -p "${WORK_DIR}/scripts"

    # Create the installer script (main entry point - from spksrc framework)
    cat > "${WORK_DIR}/scripts/installer" << 'INSTALLER'
#!/bin/sh

# DSM 5 -> 7 upgrade path:
# - Not supported
# DSM 6 -> 7 upgrade path:
# - files are migrated from ${SYNOPKG_PKGDEST}/var to ${SYNOPKG_PKGVAR}

# installer log is not writable, use for reference only.
INST_LOG="/var/log/packages/${SYNOPKG_PKGNAME}.log"

# Optional FWPORTS file
FWPORTS_FILE="/var/packages/${SYNOPKG_PKGNAME}/conf/${SYNOPKG_PKGNAME}.sc"

# Temporary directory when the package is upgrading
TMP_DIR="${SYNOPKG_TEMP_UPGRADE_FOLDER}"

install_log ()
{
    local _msg_="$@"
    if [ -z "${_msg_}" ]; then
        # read multiline from stdin
        while IFS=$'\n' read -r line; do
            install_log "${line}"
        done
    else
        # stderr goes to /var/log/packages/{package}.log
        # stdout goes to dialog in package manager ui.
        echo -e "$(date +'%Y/%m/%d %H:%M:%S')\t${_msg_}" 1>&2
    fi
}

# Invoke shell function if available
call_func ()
{
    FUNC=$1
    if type "${FUNC}" 2>/dev/null | grep -q 'function' 2>/dev/null; then
        install_log "Begin ${FUNC}"
        LOG=$2
        ARG=$3
        if [ -z "${LOG}" ]; then
            if [ -z "${ARG}" ]; then
                eval ${FUNC}
            else
                eval ${FUNC} ${ARG}
            fi
        else
            if [ -z "${ARG}" ]; then
                eval ${FUNC} 2>&1 | ${LOG}
            else
                eval ${FUNC} ${ARG} 2>&1 | ${LOG}
            fi
        fi
        install_log "End ${FUNC}"
    fi
}

# Source installer variables and functions
INST_FUNCTIONS=$(dirname $0)"/functions"
if [ -r "${INST_FUNCTIONS}" ]; then
    . "${INST_FUNCTIONS}"
fi


# Source package specific variables and functions
SVC_SETUP=$(dirname $0)"/service-setup"
if [ -r "${SVC_SETUP}" ]; then
    . "${SVC_SETUP}"
fi


# Load (wizard) variables stored by postinst
load_variables_from_file ${INST_VARIABLES}

# init variables either from ${INST_VARIABLES}, from package or from wizard
call_func "initialize_variables"


### Functions library

#
# syncronize all files from var folder in spk (extracted to target/var)
# (@appdata) /var/packages/<package>/target/var -> /var/packages/<package>/var
#
syno_sync_var_folder () {
    # take all files that do not alredy exist and rename the other files to *.new to avoid overwriting
    # existing configuration files.
    # finally remove the target/var folder that is not used under DSM 7.
    if [ -d ${SYNOPKG_PKGDEST}/var -a "$(ls -A ${SYNOPKG_PKGDEST}/var 2>/dev/null)" ]; then

        echo "Install files from var folder"

        # Move all files except existing
        echo "$RSYNC --ignore-existing --remove-source-files ${SYNOPKG_PKGDEST}/var/ ${SYNOPKG_PKGVAR}"
        $RSYNC --ignore-existing --remove-source-files ${SYNOPKG_PKGDEST}/var/ ${SYNOPKG_PKGVAR}

        # Rename any remaining (thus pre-existing) files with .new suffix
        find ${SYNOPKG_PKGDEST}/var -type f -exec sh -c 'x="{}"; mv "$x" "${x}.new"' \;

        # Move .new files (overwrite existing)
        echo "$RSYNC --remove-source-files ${SYNOPKG_PKGDEST}/var/ ${SYNOPKG_PKGVAR}"
        $RSYNC --remove-source-files ${SYNOPKG_PKGDEST}/var/ ${SYNOPKG_PKGVAR}

        # Remove var folder extraced from spk
        $RM ${SYNOPKG_PKGDEST}/var
    fi
}

set_unix_permissions ()
{
    echo "Notice: set_unix_permissions() is no longer required on DSM7."
}

syno_remove_user ()
{
    echo "${SYNOPKG_PKGNAME} has not been updated to DSM7 yet. syno_remove_user() is no longer supported."
}

syno_group_create ()
{
    echo "${SYNOPKG_PKGNAME} has not been updated to DSM7 yet. syno_group_create() is no longer supported."
}

syno_group_remove ()
{
    echo "${SYNOPKG_PKGNAME} has not been updated to DSM7 yet. syno_group_remove() is no longer supported."
}

syno_user_add_to_group ()
{
    echo "${SYNOPKG_PKGNAME} has not been updated to DSM7 yet. syno_user_add_to_group() is no longer supported."
}

set_syno_permissions ()
{
    echo "${SYNOPKG_PKGNAME} has not been updated to DSM7 yet. set_syno_permissions() is no longer supported."
}

syno_user_add_to_legacy_group () {
    echo "${SYNOPKG_PKGNAME} has not been updated to DSM7 yet. syno_user_add_to_legacy_group() is no longer supported."
}


### Generic package behaviors

preinst ()
{
    log_step "preinst"
    call_func "validate_preinst"
    call_func "service_preinst" install_log

    exit 0
}

postinst ()
{
    log_step "postinst"
    call_func "save_wizard_variables" install_log

    # copy target/var data to permanent storage
    # and don't override old configurations
    call_func "syno_sync_var_folder" install_log

    call_func "service_postinst" install_log

    if [ -n "${LOG_FILE}" ]; then
        echo "Installation log: ${INST_LOG}" >> ${LOG_FILE}
    fi

    exit 0
}

preuninst ()
{
    log_step "preuninst"
    call_func "validate_preuninst"
    call_func "service_preuninst" install_log

    exit 0
}

postuninst ()
{
    log_step "postuninst"
    call_func "service_postuninst" install_log

    if [ "$wizard_delete_data" = "true" ]; then
        echo "Removing files..." | install_log
        if [ "$(ls -A ${SYNOPKG_PKGHOME})" != "" ]; then
            find ${SYNOPKG_PKGHOME} -mindepth 1 -delete | install_log
        fi

        if [ "$(ls -A ${SYNOPKG_PKGVAR})" != "" ]; then
            find ${SYNOPKG_PKGVAR} -mindepth 1 -delete | install_log
        fi

        _etc_path=$(realpath /var/packages/${SYNOPKG_PKGNAME}/etc)
        if [ "$(ls -A ${_etc_path})" != "" ]; then
            find ${_etc_path} -mindepth 1 -delete | install_log
        fi
    fi

    exit 0
}

preupgrade ()
{
    log_step "preupgrade"
    call_func "validate_preupgrade"

    # dsm6 -> dsm7
    if [ -d ${SYNOPKG_PKGDEST}/var ]; then
        if [ ! -d ${SYNOPKG_PKGVAR} -o $(realpath ${SYNOPKG_PKGVAR}) = $(realpath ${SYNOPKG_PKGDEST}/var) ]; then
            # Copy to temporary directory if upgrading from DSM6 -> DSM7
            # Then restore once to permanent storage at postupgrade
            if [ -d ${SYNOPKG_PKGDEST}/var -a "$(ls -A ${SYNOPKG_PKGDEST}/var 2>/dev/null)" ]; then
                echo "Backup target/var folder used under DSM6" | install_log
                echo "$RSYNC ${SYNOPKG_PKGDEST}/var/ ${TMP_DIR}" | install_log
                $RSYNC ${SYNOPKG_PKGDEST}/var/ ${TMP_DIR} 2>&1 | install_log
                # remove DSM6 target/var folder
                rm -rf ${SYNOPKG_PKGDEST}/var 2>&1 | install_log
            fi
        fi
    fi

    call_func "service_preupgrade" install_log
    call_func "service_save" install_log

    exit 0
}

postupgrade ()
{
    log_step "postupgrade"

    call_func "service_restore" install_log

    # dsm6 -> dsm7
    if [ -d ${TMP_DIR} -a "$(ls -A ${TMP_DIR} 2>/dev/null)" ]; then
        # Restore once to permanent storage at postupgrade
        echo "Resore var folder from DSM6" | install_log
        echo "$RSYNC ${TMP_DIR}/ ${SYNOPKG_PKGVAR}" | install_log
        $RSYNC ${TMP_DIR}/ ${SYNOPKG_PKGVAR} 2>&1 | install_log
    fi

    # dsm7: Now sync in any new files to permanent storage
    call_func "syno_sync_var_folder" install_log
    call_func "service_postupgrade" install_log

    exit 0
}
INSTALLER
    chmod 755 "${WORK_DIR}/scripts/installer"

    # Create the functions script (common spksrc functions)
    cat > "${WORK_DIR}/scripts/functions" << 'FUNCTIONS'
### common installer functions and variables for synocommunity generic service installer
#
# functions are common for all DSM versions
#
# The script must be sh/ash compatible and not use bash syntax.
# SRM and DSM < 6.0 have only the busybox built-in shell an not bash
#

# Tools shortcuts
MV="/bin/mv -f"
RM="/bin/rm -rf"
CP="/bin/cp -rfp"
MKDIR="/bin/mkdir -p"
LN="/bin/ln -nsf"
TEE="/usr/bin/tee -a"
RSYNC="/bin/rsync -avh"
TAR="/bin/tar"

INST_ETC="/var/packages/${SYNOPKG_PKGNAME}/etc"
INST_VARIABLES="${INST_ETC}/installer-variables"
# DSM7 only
INST_SHARES="/var/packages/${SYNOPKG_PKGNAME}/shares"

if [ -z "${SYNOPKG_PKGVAR}" ]; then
    # define SYNOPKG_PKGVAR for compatibility with DSM7 (replaces former INST_VAR)
    SYNOPKG_PKGVAR="${SYNOPKG_PKGDEST}/var"
fi


### Functions library

log_step ()
{
    install_log "===> Step $1. STATUS=${SYNOPKG_PKG_STATUS} USER=$USER GROUP=$GROUP SHARE_PATH=${SHARE_PATH}"
}


initialize_variables ()
{
    # Expect user to be set from package specific variables
    if [ -n "${USER}" -a -z "${USER_DESC}" ]; then
        USER_DESC="User running $SYNOPKG_PKGNAME"
    fi

    # Default description if group name provided by UI
    if [ -n "${GROUP}" -a -z "${GROUP_DESC}" ]; then
        GROUP_DESC="SynoCommunity Package Group"
    fi

    # Extract share volume and share name from share path when provided, and not already defined
    if [ -n "${SHARE_PATH}" ]; then
        # migrate SHARE_PATH that holds the share name only to full share path
        # this is required for installers without resource worker for file share (SRM 1, DSM 5, DSM 6 old packages)
        if [ "$(echo ${SHARE_PATH} | grep ^/)" != "${SHARE_PATH}" ]; then
            SHARE_NAME=${SHARE_PATH}
            if [ ${SYNOPKG_DSM_VERSION_MAJOR} -lt 7 ]; then
                if synoshare --get "${SHARE_NAME}" &> /dev/null; then
                    SHARE_PATH=$(synoshare --get "${SHARE_NAME}" | awk 'NR==4' | cut -d] -f1 | cut -d[ -f2)
                    install_log "Path of existing share [${SHARE_NAME}] is [${SHARE_PATH}]"
                fi
            else
                # synoshare fails on DSM 7 (at least on 7.2.1) with "Permission denied"
                # but DSM 7 links package specific shares to the package installation folder
                if [ -d ${INST_SHARES}/${SHARE_NAME} ]; then
                    SHARE_PATH=$(realpath ${INST_SHARES}/${SHARE_NAME})
                    install_log "Path of existing share [${SHARE_NAME}] is [${SHARE_PATH}]"
                fi
            fi
            if [ ! -d "${SHARE_PATH}" ]; then
                install_log "SHARE_NAME is not an existing share [${SHARE_PATH}]."
            fi
        fi
        if [ -z "${SHARE_NAME}" ]; then
            SHARE_NAME=$(basename ${SHARE_PATH})
        fi
        install_log "Shared folder configured with SHARE_NAME [${SHARE_NAME}] and SHARE_PATH [${SHARE_PATH}]"
    fi
}


# function to read and export variables from a text file
# empty lines and lines starting with # are ignored
# we cannot 'source' the file to load the variables, when values have special characters like <, >, ...
# already defined variables are not taken from the file (e.g. variables from wizard)
load_variables_from_file ()
{
   if [ -n "$1" -a -r "$1" ]; then
      while read -r _line; do
        if [ "$(echo ${_line} | grep -v ^[/s]*#)" != "" ]; then
           _key=${_line%%=*}
           _value=${_line#*=}
           _existing_value=$(eval echo "\$${_key}")
           if [ -z "${_existing_value}" ]; then
              export "${_key}=${_value}"
           fi
        fi
      done < "$1"
   fi
}


save_wizard_variables ()
{
    if [ -e "${INST_VARIABLES}" -a -n "${GROUP}${SHARE_PATH}${SHARE_NAME}" ]; then
        $RM "${INST_VARIABLES}"
    fi
    if [ -n "${GROUP}" ]; then
        echo "GROUP=${GROUP}" >> ${INST_VARIABLES}
    fi
    if [ -n "${SHARE_PATH}" ]; then
        echo "SHARE_PATH=${SHARE_PATH}" >> ${INST_VARIABLES}
    fi
    if [ -n "${SHARE_NAME}" ]; then
        echo "SHARE_NAME=${SHARE_NAME}" >> ${INST_VARIABLES}
    fi
}
FUNCTIONS
    chmod 755 "${WORK_DIR}/scripts/functions"

    # Create the service-setup script (package specific)
    cat > "${WORK_DIR}/scripts/service-setup" << 'SERVICESETUP'
### Generic variables and functions
### -------------------------------

if [ -z "${SYNOPKG_PKGNAME}" ] || [ -z "${SYNOPKG_DSM_VERSION_MAJOR}" ]; then
  echo "Error: Environment variables are not set." 1>&2;
  echo "Please run me using synopkg instead. Example: \"synopkg start [packagename]\"" 1>&2;
  exit 1
fi

USER="pelican_panel"
EFF_USER="sc-pelican_panel"


# start-stop-status script redirect stdout/stderr to LOG_FILE
LOG_FILE="${SYNOPKG_PKGVAR}/${SYNOPKG_PKGNAME}.log"

# Service command has to deliver its pid into PID_FILE
PID_FILE="${SYNOPKG_PKGVAR}/${SYNOPKG_PKGNAME}.pid"


### Package specific variables and functions
### ----------------------------------------

PANEL_SHARE="${SYNOPKG_PKGDEST}/share/panel"
WINGS_CONFIG_EXAMPLE="${SYNOPKG_PKGDEST}/share/wings.config.example.yml"
ENV_EXAMPLE="${SYNOPKG_PKGDEST}/share/panel.env.example"
VAR_DIR="${SYNOPKG_PKGVAR}"
DATA_DIR="${VAR_DIR}/data"
LOG_DIR="${VAR_DIR}/logs"
ENV_FILE="${VAR_DIR}/panel.env"
WINGS_CONFIG="${DATA_DIR}/wings/config.yml"

# Cleanup function - called on uninstall or failed install
cleanup_package()
{
    # Stop and remove Docker containers (try both naming conventions)
    docker rm -f pelican_panel-panel-1 2>/dev/null || true
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
    return 0
}

create_data_dirs()
{
    install -d -m 0750 "${VAR_DIR}"
    # Pelican data directory (SQLite DB, uploads, cache)
    install -d -m 0770 "${DATA_DIR}/pelican-data" 2>/dev/null || mkdir -p "${DATA_DIR}/pelican-data"
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
    local default_iface=$(ip route 2>/dev/null | grep default | head -1 | awk '{print $5}')
    if [ -n "$default_iface" ]; then
        local ip=$(ip -4 addr show "$default_iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        if [ -n "$ip" ]; then
            echo "$ip"
            return
        fi
    fi
    # Fallback: get first non-localhost IPv4
    ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1
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

        # Admin account configuration from wizard
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

    if [ -n "${EFF_USER}" ]; then
        chown -R "${EFF_USER}:${EFF_USER}" "${VAR_DIR}" 2>/dev/null || true
    fi

    if getent group docker >/dev/null 2>&1 && [ -n "${EFF_USER}" ]; then
        addgroup "${EFF_USER}" docker 2>/dev/null || true
    fi
}

service_preupgrade()
{
    if [ -d "${SYNOPKG_TEMP_UPGRADE_FOLDER}" ]; then
        cp -a "${ENV_FILE}" "${SYNOPKG_TEMP_UPGRADE_FOLDER}/panel.env" 2>/dev/null || true
        cp -a "${WINGS_CONFIG}" "${SYNOPKG_TEMP_UPGRADE_FOLDER}/wings.config.yml" 2>/dev/null || true
        if [ -d "${DATA_DIR}" ]; then
            rsync -a "${DATA_DIR}/" "${SYNOPKG_TEMP_UPGRADE_FOLDER}/data/" 2>/dev/null || true
        fi
    fi
}

service_postupgrade()
{
    if [ -f "${SYNOPKG_TEMP_UPGRADE_FOLDER}/panel.env" ]; then
        install -m 0600 "${SYNOPKG_TEMP_UPGRADE_FOLDER}/panel.env" "${ENV_FILE}"
    fi
    if [ -f "${SYNOPKG_TEMP_UPGRADE_FOLDER}/wings.config.yml" ]; then
        install -m 0640 "${SYNOPKG_TEMP_UPGRADE_FOLDER}/wings.config.yml" "${WINGS_CONFIG}"
    fi
    if [ -d "${SYNOPKG_TEMP_UPGRADE_FOLDER}/data" ]; then
        rsync -a "${SYNOPKG_TEMP_UPGRADE_FOLDER}/data/" "${DATA_DIR}/" 2>/dev/null || true
    fi
    if [ -n "${EFF_USER}" ]; then
        chown -R "${EFF_USER}:${EFF_USER}" "${VAR_DIR}" 2>/dev/null || true
    fi
}

service_preuninst()
{
    # Stop containers before uninstall (try both naming conventions)
    docker stop pelican_panel-panel-1 2>/dev/null || true
    docker stop pelican_panel-panel 2>/dev/null || true
}

service_postuninst()
{
    # Always cleanup containers and system files
    cleanup_package

    # Delete data if user chose to
    if [ "${wizard_delete_data}" = "true" ]; then
        # Use Docker to remove files owned by container users (uid 999, etc.)
        # This handles files owned by Docker that can't be deleted normally
        docker run --rm -v "/var/packages/pelican_panel/var/data:/data" alpine sh -c "rm -rf /data/*" 2>/dev/null || true
        docker run --rm -v "/var/packages/pelican_panel/var:/data" alpine sh -c "rm -rf /data/*" 2>/dev/null || true
        rm -rf "/var/packages/pelican_panel/var" 2>/dev/null || true
        rm -rf "/volume1/@appdata/pelican_panel" 2>/dev/null || true
    fi
}
SERVICESETUP
    chmod 755 "${WORK_DIR}/scripts/service-setup"

    # Create start-stop-status script
    cp "${SPK_SRC}/dsm-control.sh" "${WORK_DIR}/scripts/start-stop-status"
    chmod 755 "${WORK_DIR}/scripts/start-stop-status"

    # Create all hook scripts using the spksrc pattern
    for script in preinst postinst preuninst postuninst preupgrade postupgrade; do
        cat > "${WORK_DIR}/scripts/${script}" << 'EOF'
#!/bin/sh
. $(dirname $0)/installer
$(basename $0) > $SYNOPKG_TEMP_LOGFILE
EOF
        chmod 755 "${WORK_DIR}/scripts/${script}"
    done

    log_success "Package scripts created"
}

# Create conf directory (only privilege and resource - .sc file goes in package.tgz)
create_conf() {
    log_info "Creating conf directory..."
    mkdir -p "${WORK_DIR}/conf"
    cp "${SPK_SRC}/conf/privilege" "${WORK_DIR}/conf/"
    cp "${SPK_SRC}/conf/resource" "${WORK_DIR}/conf/"
    # Must be readable by DSM (644 permissions)
    chmod 644 "${WORK_DIR}/conf/privilege"
    chmod 644 "${WORK_DIR}/conf/resource"
    log_success "Conf directory created"
}

# Create wizard files
create_wizard() {
    log_info "Creating wizard directory..."
    mkdir -p "${WORK_DIR}/WIZARD_UIFILES"

    # Prefer .sh script if it exists (dynamic wizard generation)
    if [ -f "${SPK_SRC}/wizard/install_uifile.sh" ]; then
        cp "${SPK_SRC}/wizard/install_uifile.sh" "${WORK_DIR}/WIZARD_UIFILES/"
        chmod 755 "${WORK_DIR}/WIZARD_UIFILES/install_uifile.sh"
    elif [ -f "${SPK_SRC}/wizard/install_uifile" ]; then
        cp "${SPK_SRC}/wizard/install_uifile" "${WORK_DIR}/WIZARD_UIFILES/"
        chmod 644 "${WORK_DIR}/WIZARD_UIFILES/install_uifile"
    fi

    if [ -f "${SPK_SRC}/wizard/uninstall_uifile.sh" ]; then
        cp "${SPK_SRC}/wizard/uninstall_uifile.sh" "${WORK_DIR}/WIZARD_UIFILES/"
        chmod 755 "${WORK_DIR}/WIZARD_UIFILES/uninstall_uifile.sh"
    elif [ -f "${SPK_SRC}/wizard/uninstall_uifile" ]; then
        cp "${SPK_SRC}/wizard/uninstall_uifile" "${WORK_DIR}/WIZARD_UIFILES/"
        chmod 644 "${WORK_DIR}/WIZARD_UIFILES/uninstall_uifile"
    fi

    log_success "Wizard directory created"
}

# Create placeholder icons (required for SPK)
create_icons() {
    log_info "Creating package icons..."

    # Create minimal 1x1 transparent PNG if icons don't exist
    if [ ! -f "${SPK_SRC}/PACKAGE_ICON.PNG" ]; then
        # Base64 encoded 1x1 transparent PNG
        echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" | base64 -d > "${WORK_DIR}/PACKAGE_ICON.PNG"
    else
        cp "${SPK_SRC}/PACKAGE_ICON.PNG" "${WORK_DIR}/"
    fi

    if [ ! -f "${SPK_SRC}/PACKAGE_ICON_256.PNG" ]; then
        echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" | base64 -d > "${WORK_DIR}/PACKAGE_ICON_256.PNG"
    else
        cp "${SPK_SRC}/PACKAGE_ICON_256.PNG" "${WORK_DIR}/"
    fi

    log_success "Package icons created"
}

# Create SPK archive
create_spk() {
    local full_version=$(get_version)
    local spk_filename="${PKG_NAME}-${full_version}-${ARCH}.spk"

    log_info "Creating SPK: ${spk_filename}..."

    mkdir -p "${DIST_DIR}"
    cd "${WORK_DIR}"

    # Create SPK (tar archive with specific structure)
    tar cf "${DIST_DIR}/${spk_filename}" \
        INFO \
        package.tgz \
        scripts \
        conf \
        WIZARD_UIFILES \
        PACKAGE_ICON.PNG \
        PACKAGE_ICON_256.PNG

    log_success "SPK created: ${DIST_DIR}/${spk_filename}"

    echo ""
    echo "========================================="
    echo -e "${GREEN}Build successful!${NC}"
    echo "========================================="
    echo "Package: ${spk_filename}"
    echo "Size: $(du -h "${DIST_DIR}/${spk_filename}" | cut -f1)"
    echo "Location: ${DIST_DIR}/"
    echo "========================================="
}

# Cleanup
cleanup() {
    log_info "Cleaning up work directory..."
    rm -rf "${WORK_DIR}"
    log_success "Cleanup complete"
}

# Main build process
main() {
    echo ""
    echo "========================================="
    echo "  Pelican Panel SPK Builder"
    echo "  Architecture: ${ARCH}"
    echo "========================================="
    echo ""

    if [ ! -d "${SPK_SRC}" ]; then
        log_error "Source directory not found: ${SPK_SRC}"
        exit 1
    fi

    clean_previous
    increment_version

    mkdir -p "${WORK_DIR}"

    create_package_content
    create_package_tgz
    create_info_file
    create_scripts
    create_conf
    create_wizard
    create_icons
    create_spk
    cleanup

    echo ""
}

# Command handler
case "${1:-build}" in
    build)
        main
        ;;
    clean)
        clean_previous
        rm -rf "${WORK_DIR}" 2>/dev/null || true
        log_success "All build artifacts cleaned"
        ;;
    version)
        shift
        "${VERSION_SCRIPT}" "$@"
        ;;
    *)
        echo "Usage: $0 {build|clean|version [command]}"
        exit 1
        ;;
esac
