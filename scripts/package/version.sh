#!/bin/bash
# Version management script for Pelican Panel SPK
# Handles automatic version incrementing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VERSION_FILE="${ROOT_DIR}/VERSION"
SPK_MAKEFILE="${ROOT_DIR}/spk/pelican/Makefile"

# Default version if VERSION file doesn't exist
DEFAULT_VERSION="1.0.0"
DEFAULT_REVISION=1

# Get current version
get_version() {
    if [ -f "${VERSION_FILE}" ]; then
        cat "${VERSION_FILE}"
    else
        echo "${DEFAULT_VERSION}"
    fi
}

# Get current revision
get_revision() {
    if [ -f "${VERSION_FILE}.rev" ]; then
        cat "${VERSION_FILE}.rev"
    else
        echo "${DEFAULT_REVISION}"
    fi
}

# Set version
set_version() {
    local version="$1"
    echo "${version}" > "${VERSION_FILE}"
    echo "Version set to: ${version}"
}

# Set revision
set_revision() {
    local rev="$1"
    echo "${rev}" > "${VERSION_FILE}.rev"
}

# Increment revision (for each build)
increment_revision() {
    local current_rev=$(get_revision)
    local new_rev=$((current_rev + 1))
    set_revision "${new_rev}"
    echo "${new_rev}"
}

# Increment patch version (x.y.Z)
increment_patch() {
    local version=$(get_version)
    local major=$(echo "${version}" | cut -d. -f1)
    local minor=$(echo "${version}" | cut -d. -f2)
    local patch=$(echo "${version}" | cut -d. -f3)
    local new_patch=$((patch + 1))
    local new_version="${major}.${minor}.${new_patch}"
    set_version "${new_version}"
    set_revision 1
    echo "${new_version}"
}

# Increment minor version (x.Y.0)
increment_minor() {
    local version=$(get_version)
    local major=$(echo "${version}" | cut -d. -f1)
    local minor=$(echo "${version}" | cut -d. -f2)
    local new_minor=$((minor + 1))
    local new_version="${major}.${new_minor}.0"
    set_version "${new_version}"
    set_revision 1
    echo "${new_version}"
}

# Increment major version (X.0.0)
increment_major() {
    local version=$(get_version)
    local major=$(echo "${version}" | cut -d. -f1)
    local new_major=$((major + 1))
    local new_version="${new_major}.0.0"
    set_version "${new_version}"
    set_revision 1
    echo "${new_version}"
}

# Update SPK Makefile with current version
update_makefile() {
    local version=$(get_version)
    local revision=$(get_revision)

    if [ -f "${SPK_MAKEFILE}" ]; then
        sed -i "s/^SPK_VERS = .*/SPK_VERS = ${version}/" "${SPK_MAKEFILE}"
        sed -i "s/^SPK_REV = .*/SPK_REV = ${revision}/" "${SPK_MAKEFILE}"
        echo "Updated Makefile: version=${version}, revision=${revision}"
    else
        echo "Warning: SPK Makefile not found at ${SPK_MAKEFILE}"
    fi
}

# Get full version string for package naming
get_full_version() {
    local version=$(get_version)
    local revision=$(get_revision)
    echo "${version}-${revision}"
}

# Initialize version files if they don't exist
init() {
    if [ ! -f "${VERSION_FILE}" ]; then
        set_version "${DEFAULT_VERSION}"
    fi
    if [ ! -f "${VERSION_FILE}.rev" ]; then
        set_revision "${DEFAULT_REVISION}"
    fi
    update_makefile
    echo "Initialized: $(get_version) rev$(get_revision)"
}

# Display current version info
info() {
    echo "Version: $(get_version)"
    echo "Revision: $(get_revision)"
    echo "Full: $(get_full_version)"
}

# Main command handler
case "${1:-info}" in
    get)
        get_version
        ;;
    get-rev)
        get_revision
        ;;
    get-full)
        get_full_version
        ;;
    set)
        if [ -z "$2" ]; then
            echo "Usage: $0 set <version>"
            exit 1
        fi
        set_version "$2"
        set_revision 1
        update_makefile
        ;;
    bump|bump-rev|rev)
        increment_revision
        update_makefile
        ;;
    bump-patch|patch)
        increment_patch
        update_makefile
        ;;
    bump-minor|minor)
        increment_minor
        update_makefile
        ;;
    bump-major|major)
        increment_major
        update_makefile
        ;;
    update-makefile)
        update_makefile
        ;;
    init)
        init
        ;;
    info|*)
        info
        ;;
esac
