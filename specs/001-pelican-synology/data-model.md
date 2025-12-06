# Data Model – Pelican Panel SPK

**Feature**: `001-pelican-synology`
**Created**: 2025-11-29

## Overview

Ce document décrit les entités de données, leurs relations, et les flux de données pour le paquet SPK Pelican Panel sur Synology.

---

## Entités Principales

### 1. SPK Package

Archive installable distribuée aux utilisateurs.

| Attribut | Type | Description |
|----------|------|-------------|
| `name` | string | `pelican_panel` |
| `version` | semver | `1.0.0-beta28` (suit Pelican upstream) |
| `revision` | integer | Numéro de build SPK (incrémental) |
| `architecture` | string | `geminilake` (x86_64) |
| `maintainer` | string | Contact mainteneur |
| `dependencies` | list | `ContainerManager` |

**États**: Non installé → Installation → Installé → Mise à jour → Désinstallation

### 2. Panel Service

Interface web de gestion des serveurs de jeux.

| Attribut | Type | Description |
|----------|------|-------------|
| `container_name` | string | `pelican_panel-panel-1` |
| `image` | string | `ghcr.io/pelican-dev/panel:latest` |
| `port_http` | integer | Port HTTP (défaut: 8080) |
| `port_https` | integer | Port HTTPS (défaut: 8443) |
| `app_url` | url | URL d'accès publique |
| `app_locale` | string | Langue interface (défaut: `fr`) |
| `admin_email` | email | Email administrateur |
| `data_path` | path | `/pelican-data` dans container |

**États**: Arrêté → Démarrage → En cours d'exécution → Arrêt

### 3. Wings Daemon

Daemon de gestion des conteneurs de serveurs de jeux.

| Attribut | Type | Description |
|----------|------|-------------|
| `binary_path` | path | `/var/packages/pelican_panel/target/bin/wings` |
| `config_path` | path | `/var/packages/pelican_panel/var/data/wings/config.yml` |
| `pid_file` | path | `/var/packages/pelican_panel/var/runtime/wings.pid` |
| `api_port` | integer | Port API HTTPS (défaut: 8443) |
| `sftp_port` | integer | Port SFTP (défaut: 2022) |
| `panel_url` | url | URL du Panel pour connexion |
| `token` | string | Token d'authentification généré par Panel |

**États**: Non configuré → Configuré → Démarré → Connecté au Panel → Arrêté

### 4. Configuration Panel (panel.env)

Fichier de variables d'environnement pour le Panel.

| Variable | Type | Description | Requis |
|----------|------|-------------|--------|
| `APP_URL` | url | URL publique | Oui |
| `APP_LOCALE` | string | Langue (`fr`, `en`, etc.) | Non |
| `APP_ENV` | enum | `production` | Oui |
| `APP_DEBUG` | boolean | `false` en prod | Oui |
| `ADMIN_EMAIL` | email | Contact admin | Oui |
| `PANEL_PORT` | integer | Port HTTP | Oui |
| `XDG_DATA_HOME` | path | `/pelican-data` | Oui |
| `TRUSTED_PROXIES` | string | `*` pour reverse proxy | Non |

### 5. Configuration Wings (wings.config.yml)

Configuration YAML du daemon Wings.

```yaml
system:
  data: /var/packages/pelican_panel/var/data/wings
  username: sc-pelican_panel
  timezone: Europe/Paris

api:
  host: 0.0.0.0
  port: 8443
  ssl:
    enabled: false  # TLS via reverse proxy DSM

panel:
  url: https://nas.local:8080
  token_id: PELICAN-TOKEN-ID
  token: PELICAN-SECRET-TOKEN

docker:
  socket: /var/run/docker.sock
  network:
    name: pelican_wings
```

### 6. Wizard Configuration

Données collectées lors de l'installation.

| Champ | Type | Validation | Étape |
|-------|------|------------|-------|
| `wizard_host` | string | IP ou hostname | 1 |
| `wizard_port` | integer | 1-65535 | 1 |
| `wizard_admin_email` | email | Format email valide | 2 |
| `wizard_locale` | enum | `fr`, `en`, etc. | 2 |
| `wizard_delete_data` | boolean | - | Désinstallation |

---

## Relations

```
┌─────────────────────────────────────────────────────────┐
│                    SPK Package                          │
│  ┌─────────────┐     ┌─────────────┐                   │
│  │ Panel       │────▶│ Wings       │                   │
│  │ (Container) │     │ (Binary)    │                   │
│  └──────┬──────┘     └──────┬──────┘                   │
│         │                   │                           │
│         ▼                   ▼                           │
│  ┌─────────────┐     ┌─────────────┐                   │
│  │ panel.env   │     │ config.yml  │                   │
│  │ (Secrets)   │     │ (YAML)      │                   │
│  └─────────────┘     └─────────────┘                   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Data Volumes                        │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐        │   │
│  │  │ pelican- │ │ pelican- │ │  wings   │        │   │
│  │  │   data   │ │   logs   │ │  data    │        │   │
│  │  └──────────┘ └──────────┘ └──────────┘        │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## Flux de Données

### Installation

```
1. Utilisateur télécharge SPK
   │
2. Package Center → Wizard install_uifile
   │
   ▼
3. Collecte: host, port, email, locale
   │
4. service-setup.sh → service_postinst()
   │
   ├─▶ Création répertoires data
   ├─▶ Génération panel.env depuis wizard
   ├─▶ Copie wings.config.example.yml
   │
5. dsm-control.sh start
   │
   ├─▶ Lancement page de chargement (port 8081)
   ├─▶ docker compose pull
   ├─▶ docker compose up -d
   ├─▶ Attente Panel ready (health check)
   └─▶ Arrêt page de chargement
```

### Premier Démarrage Panel

```
1. Panel container démarre
   │
2. Migrations SQLite automatiques
   │
3. Utilisateur accède à APP_URL/installer
   │
4. Assistant web Pelican:
   ├─▶ Configuration DB (SQLite auto-détecté)
   ├─▶ Création compte admin
   ├─▶ Configuration mail (optionnel)
   │
5. Redirection vers dashboard
```

### Configuration Wings

```
1. Admin dans Panel → Nodes → Créer Node
   │
2. Panel génère token et config YAML
   │
3. Admin accède à DSM → Pelican → Configurer Wings
   │
4. Copie config depuis Panel vers CGI
   │
5. CGI sauvegarde vers wings.config.yml
   │
6. Redémarrage Wings daemon
   │
7. Wings → Panel: handshake avec token
   │
8. Panel: Node status = "Connecté"
```

### Création Serveur de Jeu

```
1. Admin → Panel → Servers → Create
   │
2. Sélection Node (Wings)
   │
3. Sélection Egg (template jeu)
   │
4. Configuration ressources (RAM, CPU, disk)
   │
5. Panel → Wings API: Create server request
   │
6. Wings → Docker: Pull game image
   │
7. Wings → Docker: Create container
   │
8. Serveur prêt (statut: Stopped)
```

### Mise à Jour Package

```
1. Nouvelle version SPK disponible
   │
2. Package Center → Install (réinstallation)
   │
3. service-setup.sh → service_preupgrade()
   │
   └─▶ Sauvegarde panel.env + wings.config.yml
   │
4. Désinstallation ancienne version
   │
5. Installation nouvelle version
   │
6. service_postupgrade()
   │
   └─▶ Restauration fichiers config
   │
7. dsm-control.sh start
   │
   └─▶ Containers recréés avec nouvelles images
```

### Désinstallation

```
1. Package Center → Désinstaller
   │
2. Wizard uninstall_uifile
   │
   └─▶ Option: Supprimer les données?
   │
3. service-setup.sh → service_preuninst()
   │
   ├─▶ Arrêt Wings daemon
   └─▶ docker compose down
   │
4. service_postuninst()
   │
   ├─▶ Si delete_data=true:
   │   ├─▶ docker run busybox rm (pour uid spéciaux)
   │   └─▶ rm -rf data directories
   │
   └─▶ Nettoyage réseau Docker
```

---

## Validation Rules

### Panel Configuration

| Champ | Règle | Message d'erreur |
|-------|-------|------------------|
| `APP_URL` | URL valide avec protocole | "URL invalide. Format: http://host:port" |
| `ADMIN_EMAIL` | Email valide | "Format email invalide" |
| `PANEL_PORT` | 1-65535, non utilisé | "Port déjà utilisé ou invalide" |
| `APP_LOCALE` | Code langue supporté | "Langue non supportée" |

### Wings Configuration

| Champ | Règle | Message d'erreur |
|-------|-------|------------------|
| `panel.url` | URL accessible | "Panel non accessible à cette URL" |
| `panel.token` | Non vide | "Token requis" |
| `api.port` | 1-65535 | "Port invalide" |
| `sftp.port` | 1-65535, ≠ api.port | "Port SFTP doit être différent" |

---

## State Transitions

### Package Lifecycle

```
┌──────────────┐    install    ┌───────────────┐
│ Not Installed │──────────────▶│   Installing  │
└──────────────┘               └───────┬───────┘
        ▲                              │
        │ uninstall                    │ success
        │                              ▼
┌───────┴──────┐   upgrade     ┌───────────────┐
│ Uninstalling │◀──────────────│   Installed   │
└──────────────┘               └───────────────┘
```

### Service Lifecycle

```
┌──────────┐   start   ┌──────────┐
│ Stopped  │──────────▶│ Starting │
└────▲─────┘           └────┬─────┘
     │                      │
     │ stop                 │ ready
     │                      ▼
┌────┴─────┐   error   ┌──────────┐
│ Stopping │◀──────────│ Running  │
└──────────┘           └──────────┘
```

### Wings Connection

```
┌──────────────┐  config saved  ┌────────────┐
│Not Configured│───────────────▶│ Configured │
└──────────────┘                └─────┬──────┘
                                      │
                                      │ daemon start
                                      ▼
┌──────────────┐   token valid  ┌────────────┐
│ Disconnected │◀───────────────│ Connecting │
└──────┬───────┘                └─────┬──────┘
       │                              │
       │ reconnect                    │ handshake OK
       │                              ▼
       └──────────────────────▶┌────────────┐
                               │ Connected  │
                               └────────────┘
```
