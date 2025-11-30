SPK_NAME = pelican_panel
SPK_VERS = 1.0.0
SPK_REV = 70
SPK_ICON = src/pelican.png
DSM_UI_DIR = app

MAINTAINER = Pelican Synology Builders
MAINTAINER_URL = https://github.com/gilles/ProjetSPK
DESCRIPTION = Pelican Panel pour Synology - Interface de gestion de serveurs de jeux avec support i18n. Hébergez vos serveurs Minecraft, Terraria et plus sur votre NAS.
CHANGELOG = "Version initiale - Pelican Panel v1.0.0-beta28 avec interface française par défaut."
DISPLAY_NAME = Pelican Panel
HOMEPAGE = https://pelican.dev/
LICENSE = MIT

# Bouton "Ouvrir" dans le Centre de paquets
ADMIN_URL = /
ADMIN_PORT = 8080
ADMIN_PROTOCOL = http

STARTABLE = yes
SERVICE_USER = auto
SERVICE_SETUP = src/service-setup.sh
SSS_SCRIPT = src/dsm-control.sh
FWPORTS = src/app/pelican_panel.sc

WIZARDS_DIR = src/wizard
CONF_DIR = src/conf

# Container Manager (Docker) est la seule dépendance
INSTALL_DEP_PACKAGES = ContainerManager

POST_STRIP_TARGET = pelican_extra_install

include ../../mk/spksrc.common.mk
include ../../mk/spksrc.spk.mk

.PHONY: pelican_extra_install
pelican_extra_install:
	# Runtime assets - Docker compose
	install -d -m 0755 $(STAGING_DIR)/share/docker
	install -m 0644 src/docker/compose.yaml $(STAGING_DIR)/share/docker/compose.yaml
	# Configuration templates
	install -m 0644 src/panel.env.example $(STAGING_DIR)/share/panel.env.example
	install -m 0644 src/wings.config.example.yml $(STAGING_DIR)/share/wings.config.example.yml
	# DSM UI config and images
	install -d -m 0755 $(STAGING_DIR)/app/images
	install -m 0644 src/app/config $(STAGING_DIR)/app/config
	install -m 0644 src/app/images/*.png $(STAGING_DIR)/app/images/ 2>/dev/null || true
	# Wings configuration CGI (DSM popup interface)
	install -m 0755 src/ui/wings-config.cgi $(STAGING_DIR)/app/wings-config.cgi
	# Loading page
	install -d -m 0755 $(STAGING_DIR)/bin
	install -m 0644 src/loading.html $(STAGING_DIR)/share/loading.html
	install -m 0755 src/loading-server.sh $(STAGING_DIR)/bin/loading-server.sh
