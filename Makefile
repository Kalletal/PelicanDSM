# Pelican Panel SPK - Root Makefile
# Build system for Synology SPK packages
# Auto-increment version, no checksums, clean previous builds

.PHONY: all clean package spk help version validate bump-patch bump-minor bump-major

# Scripts
BUILD_SCRIPT = scripts/package/build-spk.sh
VERSION_SCRIPT = scripts/package/version.sh

# Default target
all: package

# Build the SPK package (auto-increments revision, cleans previous)
package: spk

spk:
	@chmod +x $(BUILD_SCRIPT) $(VERSION_SCRIPT)
	@$(BUILD_SCRIPT) build

# Clean all build artifacts
clean:
	@chmod +x $(BUILD_SCRIPT) 2>/dev/null || true
	@$(BUILD_SCRIPT) clean 2>/dev/null || true
	@rm -rf dist/ .build/

# Version management
version:
	@chmod +x $(VERSION_SCRIPT)
	@$(VERSION_SCRIPT) info

# Bump patch version (x.y.Z) - for bug fixes
bump-patch:
	@chmod +x $(VERSION_SCRIPT)
	@$(VERSION_SCRIPT) bump-patch

# Bump minor version (x.Y.0) - for new features
bump-minor:
	@chmod +x $(VERSION_SCRIPT)
	@$(VERSION_SCRIPT) bump-minor

# Bump major version (X.0.0) - for breaking changes
bump-major:
	@chmod +x $(VERSION_SCRIPT)
	@$(VERSION_SCRIPT) bump-major

# Set specific version
set-version:
	@if [ -z "$(VER)" ]; then \
		echo "Usage: make set-version VER=x.y.z"; \
		exit 1; \
	fi
	@chmod +x $(VERSION_SCRIPT)
	@$(VERSION_SCRIPT) set $(VER)

# Validate project structure
validate:
	@echo "Validating project structure..."
	@test -f spk/pelican/src/service-setup.sh || (echo "ERROR: service-setup.sh not found" && exit 1)
	@test -f spk/pelican/src/dsm-control.sh || (echo "ERROR: dsm-control.sh not found" && exit 1)
	@test -f spk/pelican/src/wizard/install_uifile || (echo "ERROR: install_uifile not found" && exit 1)
	@test -f spk/pelican/src/docker/compose.yaml || (echo "ERROR: compose.yaml not found" && exit 1)
	@test -f spk/pelican/src/panel.env.example || (echo "ERROR: panel.env.example not found" && exit 1)
	@test -f $(BUILD_SCRIPT) || (echo "ERROR: build-spk.sh not found" && exit 1)
	@test -f $(VERSION_SCRIPT) || (echo "ERROR: version.sh not found" && exit 1)
	@echo "Structure validated successfully!"

# Show help
help:
	@echo "Pelican Panel SPK Build System"
	@echo ""
	@echo "Build Commands:"
	@echo "  make              - Build SPK (auto-increments revision)"
	@echo "  make package      - Same as above"
	@echo "  make clean        - Remove all build artifacts"
	@echo "  make validate     - Check project structure"
	@echo ""
	@echo "Version Commands:"
	@echo "  make version      - Show current version"
	@echo "  make bump-patch   - Increment patch (x.y.Z) for bug fixes"
	@echo "  make bump-minor   - Increment minor (x.Y.0) for features"
	@echo "  make bump-major   - Increment major (X.0.0) for breaking changes"
	@echo "  make set-version VER=1.2.3 - Set specific version"
	@echo ""
	@echo "Notes:"
	@echo "  - Each build auto-increments the revision number"
	@echo "  - Previous SPK files are automatically deleted"
	@echo "  - No checksum files are generated"
	@echo ""
	@echo "Output: dist/pelican_panel-<version>-<rev>-geminilake.spk"
