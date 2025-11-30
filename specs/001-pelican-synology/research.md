# Research Log – Pelican Panel SPK pour Synology
**Date**: 2025-11-29
**Owner**: speckit research phase
**Spec**: `specs/001-pelican-synology/spec.md`

## Goals
- Valider les prérequis upstream Pelican Panel (PHP, MariaDB, Redis)
- Confirmer la stratégie de build Synology en réutilisant l'architecture Pterodactyl
- Identifier les différences clés entre Pelican et Pterodactyl
- Documenter l'approche d'intégration Docker sur DSM 7.2+

## Recherches Héritées du Projet Pterodactyl

Le projet Pterodactyl (`/home/gilles/ProjetSPK/Pterodactyl/`) a produit une base solide réutilisable pour Pelican.

### Architecture SPK Validée

| Composant | Status | Réutilisable |
|-----------|--------|--------------|
| Build tooling (spksrc) | ✅ Validé | Oui, adapter Makefile |
| Scripts package (common.sh, bootstrap.sh) | ✅ Validé | Oui, copier et adapter |
| Service setup (service-setup.sh) | ✅ Validé | Oui, renommer variables |
| DSM control (dsm-control.sh) | ✅ Validé | Oui, adapter noms conteneurs |
| Wizard installation | ✅ Validé | Oui, adapter textes |
| Page de chargement | ✅ Validé | Oui, changer branding |
| UI Wings config | ✅ Validé | Oui, adapter chemins |

### Problèmes Résolus (Pterodactyl) à Appliquer

| Problème | Solution | Application Pelican |
|----------|----------|---------------------|
| CSRF token mismatch | `SESSION_SECURE_COOKIE=false` en HTTP | Identique |
| Fichiers DB non supprimables | `docker run busybox rm -rf` pour uid 999 | Identique |
| Page de chargement chaque démarrage | Lancer à chaque `start` | Identique |
| Performance installation | Sauvegarder configs seules | Identique |
| Docker Worker non fonctionnel | Container Manager Direct | Identique |

### Décision Architecture: Container Manager Direct

**Choix validé** : Container Manager Direct (Option C dans recherches Pterodactyl)

| Approche | Complexité | UX | Maintenabilité |
|----------|------------|-----|----------------|
| Docker Worker (JSON) | Élevée | One-click | Difficile |
| Docker Project Worker | Moyenne | One-click | Moyenne |
| **Container Manager Direct** | **Faible** | 2 étapes | **Facile** |

**Justification** : Les Workers Synology ajoutent une couche d'abstraction problématique lors des mises à jour de DSM ou Container Manager. Container Manager Direct offre flexibilité utilisateur et maintenabilité.

---

## Pelican Panel - Différences avec Pterodactyl

### Informations Projet

| Attribut | Pterodactyl | Pelican |
|----------|-------------|---------|
| Statut | Maintenance sécurité | Développement actif |
| Version actuelle | 1.11.6 | v1.0.0-beta28 |
| i18n Frontend | ❌ Non (React hardcodé) | ✅ Oui (Crowdin) |
| Image Docker | `ghcr.io/pterodactyl/panel` | `ghcr.io/pelican-dev/panel` |
| Wings | `ghcr.io/pterodactyl/wings` | `ghcr.io/pelican-dev/wings` |
| PHP requis | 8.1-8.3 | 8.2-8.4 (8.4 recommandé) |
| DB requise | MySQL 5.7+ / MariaDB 10.2+ | MySQL 8+ / MariaDB 10.6+ |

### Images Docker Officielles

**Panel:**
- `ghcr.io/pelican-dev/panel:latest` - Release stable actuelle
- `ghcr.io/pelican-dev/panel:main` - Branche de développement

**Wings:**
- `ghcr.io/pelican-dev/wings:latest` - v1.0.0-beta19
- Binaires: `wings_linux_amd64`, `wings_linux_arm64`

### Architecture Pelican vs Pterodactyl

| Composant | Pterodactyl | Pelican |
|-----------|-------------|---------|
| Webserver intégré | Nginx | Caddy |
| Base de données par défaut | MySQL/MariaDB externe | SQLite ou externe |
| Cache par défaut | Redis obligatoire | SQLite possible, Redis recommandé |
| Ports par défaut | 80, 443 | 80, 443 |
| PHP-FPM | Oui | Oui (port 9000 optionnel) |

### Support Internationalisation (i18n)

**Avantage majeur de Pelican** : Support natif des traductions via Crowdin.

- Projet Crowdin: https://crowdin.com/project/pelican-dev
- Annonce officielle: https://pelican.dev/blog/translations-begin/ (Mai 2024)
- Variable d'environnement: `APP_LOCALE=fr` effective pour frontend ET backend

**Langues en cours de traduction** (Mai 2024+):
- Français, Allemand, Espagnol, Italien
- Chinois, Japonais, Coréen
- Portugais, Russe, et autres

---

## Configuration Docker Pelican

### compose.yml Officiel (simplifié pour Synology)

```yaml
services:
  panel:
    image: ghcr.io/pelican-dev/panel:latest
    restart: always
    ports:
      - "${PANEL_PORT:-8080}:80"
      - "${PANEL_HTTPS_PORT:-8443}:443"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ${DATA_ROOT}/pelican-data:/pelican-data
      - ${DATA_ROOT}/pelican-logs:/var/www/html/storage/logs
    environment:
      XDG_DATA_HOME: /pelican-data
      APP_URL: "${APP_URL}"
      APP_LOCALE: "${APP_LOCALE:-en}"
      APP_ENV: production
      APP_DEBUG: "false"
      ADMIN_EMAIL: "${ADMIN_EMAIL}"
      TRUSTED_PROXIES: "*"

networks:
  default:
    name: pelican_network
    driver: bridge
```

### Différences de Configuration vs Pterodactyl

| Variable | Pterodactyl | Pelican |
|----------|-------------|---------|
| Data path | `/app/var`, `/app/storage` | `/pelican-data` |
| Config home | - | `XDG_DATA_HOME=/pelican-data` |
| Admin email | Wizard | `ADMIN_EMAIL` env var |
| QUEUE_DRIVER | `redis` | `sync` ou `database` par défaut |
| DB par défaut | MariaDB container | SQLite intégré |

### Base de Données: SQLite vs MariaDB

**Pelican supporte SQLite** comme option par défaut (simplification):

| Option | Avantages | Inconvénients |
|--------|-----------|---------------|
| SQLite (défaut) | Pas de container DB, simple | Performances moindres à grande échelle |
| MariaDB | Meilleures performances | Container supplémentaire |

**Recommandation pour Synology**:
- SQLite pour démarrage simple
- Option MariaDB documentée pour utilisateurs avancés

### Redis: Optionnel dans Pelican

Pelican peut fonctionner **sans Redis** (utilise file/database pour cache/sessions).

**Recommandation**: Pas de container Redis par défaut, documenter ajout optionnel.

---

## Prérequis Techniques Validés

### Synology DS920+

| Prérequis | Status | Notes |
|-----------|--------|-------|
| DSM 7.2+ | ✅ Requis | Container Manager intégré |
| Container Manager ≥1432 | ✅ Requis | Docker 20.10.23+ ou 24.0.2+ |
| Architecture geminilake | ✅ Supporté | Intel Celeron J4125 |
| RAM 4GB+ | ⚠️ Recommandé | 8GB optimal |

### Images Docker

| Image | Tag | Taille | Notes |
|-------|-----|--------|-------|
| `ghcr.io/pelican-dev/panel` | `latest` | ~500MB | Caddy + PHP-FPM intégré |
| `ghcr.io/pelican-dev/wings` | `latest` | ~50MB | Daemon Go |
| `busybox` | `latest` | ~1.5MB | Pour nettoyage uid 999 |

### Ports par Défaut

| Service | Port | Modifiable | Firewall |
|---------|------|------------|----------|
| Panel HTTP | 8080 | Wizard | Oui |
| Panel HTTPS | 8443 | Wizard | Oui |
| Wings API | 8443 | Config | Oui |
| Wings SFTP | 2022 | Config | Oui |

---

## Structure SPK Proposée

### Arborescence Package

```
spk/pelican/
├── Makefile                           # SPK_NAME=pelican_panel
├── PACKAGE_ICON.PNG                   # Icônes 16-256px
└── src/
    ├── app/
    │   ├── config                     # Menu DSM (Panel + Wings Config)
    │   ├── images/                    # Icônes Pelican
    │   └── pelican_panel.sc           # Ports firewall
    ├── conf/
    │   ├── privilege                  # docker group
    │   └── resource                   # port-config
    ├── wizard/
    │   ├── install_uifile             # Assistant 3 étapes
    │   └── uninstall_uifile           # Option suppression données
    ├── ui/
    │   └── wings-config.cgi           # Config Wings DSM popup
    ├── docker/
    │   └── compose.yaml               # Stack Pelican
    ├── service-setup.sh               # Hooks lifecycle
    ├── dsm-control.sh                 # start/stop/status
    ├── loading-server.sh              # Page attente
    ├── loading.html                   # UI K2000 avec branding Pelican
    ├── panel.env.example              # Template variables
    └── wings.config.example.yml       # Template Wings
```

### Chemins Données

| Chemin | Contenu | Permissions |
|--------|---------|-------------|
| `/var/packages/pelican_panel/var/data/pelican-data` | Données Panel (SQLite, uploads) | 770 |
| `/var/packages/pelican_panel/var/data/pelican-logs` | Logs application | 750 |
| `/var/packages/pelican_panel/var/data/wings` | Config et données Wings | 770 |
| `/var/packages/pelican_panel/var/panel.env` | Variables environnement | 600 |

---

## Risques & Mitigations

| Risque | Impact | Mitigation |
|--------|--------|------------|
| Version beta (beta28) | Bugs potentiels | Tester release avant packaging |
| SQLite limitations | Performance | Documenter option MariaDB |
| Caddy vs Nginx | Config différente | Utiliser config par défaut |
| Traductions incomplètes | UX partielle | Documenter statut Crowdin |
| Mise à jour DB breaking | Migrations | Tester upgrades avant release |

## Décisions Prises

### 1. Image Docker
**Décision**: Utiliser `ghcr.io/pelican-dev/panel:latest`
**Rationale**: Image officielle avec Caddy intégré, pas besoin de container Nginx séparé
**Alternatives rejetées**: Build custom (complexité), Pterodactyl (pas de i18n)

### 2. Base de Données
**Décision**: SQLite par défaut (intégré à Pelican)
**Rationale**: Simplicité maximale, pas de container supplémentaire
**Alternatives rejetées**: MariaDB container (complexité, RAM)

### 3. Redis
**Décision**: Pas de Redis par défaut
**Rationale**: Pelican supporte cache file/database, suffisant pour usage domestique
**Alternatives rejetées**: Redis container (RAM supplémentaire)

### 4. Wings
**Décision**: Binary natif + container Docker (comme Pterodactyl)
**Rationale**: Wings doit accéder à Docker pour gérer les serveurs de jeux
**Alternatives rejetées**: Wings en container (accès Docker complexe)

### 5. Ports
**Décision**: 8080 (HTTP), 8443 (HTTPS/Wings), 2022 (SFTP)
**Rationale**: Éviter conflits avec DSM (5000/5001) et services courants
**Alternatives rejetées**: 80/443 (conflits DSM reverse proxy)

---

## Prochaines Étapes

1. ✅ Recherche complète (ce document)
2. → Créer data-model.md avec entités et flux
3. → Créer contracts/ avec configuration wizard
4. → Créer quickstart.md guide démarrage rapide
5. → Mettre à jour plan.md avec contexte technique

---

## Recherches DSM - Bouton "Ouvrir" et Configuration UI (2025-11-30)

### Problème Initial
Le bouton "Ouvrir" n'apparaissait pas dans le Centre de paquets DSM après installation du SPK Pelican.

### Solution Trouvée

La configuration du bouton "Ouvrir" dans DSM 7 nécessite plusieurs éléments :

#### 1. Fichier INFO - Champs Admin
```
adminport="8080"
adminurl="/"
adminprotocol="http"
dsmuidir="app"
dsmappname="com.synocommunity.packages.pelican_panel"
```

#### 2. Fichier app/config - Format Complet
Le fichier `app/config` doit inclure les champs **obligatoires** suivants pour que le raccourci fonctionne :

```json
{
  ".url": {
    "com.synocommunity.packages.pelican_panel": {
      "title": "Pelican Panel",
      "desc": "Description",
      "icon": "images/pelican_panel-{0}.png",
      "type": "url",
      "protocol": "http",
      "port": "8080",
      "url": "/",
      "allUsers": true,
      "grantPrivilege": "all",
      "advanceGrantPrivilege": true
    }
  }
}
```

**Champs critiques manquants initialement :**
- `allUsers`: Permet à tous les utilisateurs DSM de voir l'icône
- `grantPrivilege`: Définit les privilèges d'accès (`"all"` pour tous)
- `advanceGrantPrivilege`: Active les privilèges avancés

#### 3. Icônes Requises
Le dossier `app/images/` doit contenir des icônes aux tailles suivantes :
- `pelican_panel-16.png`
- `pelican_panel-24.png`
- `pelican_panel-32.png`
- `pelican_panel-48.png`
- `pelican_panel-64.png`
- `pelican_panel-72.png`
- `pelican_panel-256.png`

Le placeholder `{0}` dans `"icon": "images/pelican_panel-{0}.png"` est remplacé par la taille appropriée par DSM.

### Mapping Ports Docker - Problème Caddy

**Problème** : L'image Pelican utilise Caddy qui écoute sur le port **8080** (pas 80).

**Solution** : Le mapping Docker doit être `8080:8080` et non `8080:80`

```yaml
ports:
  - "${PANEL_PORT:-8080}:8080"  # Correct
  - "${PANEL_HTTPS_PORT:-8443}:443"
```

Le health check doit aussi utiliser le port 8080 :
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/api/health"]
```

### Permissions Volumes Docker

Le conteneur Pelican exécute PHP-FPM avec l'utilisateur `www-data` (UID 82 sur Alpine).

Les volumes montés doivent avoir les permissions appropriées :
```bash
chmod -R 777 /var/packages/pelican_panel/var/data/pelican-data
chmod -R 777 /var/packages/pelican_panel/var/data/pelican-logs
mkdir -p /var/packages/pelican_panel/var/data/pelican-logs/supervisord
```

### Sources de Recherche

- [Synology Developer Guide - Optional Fields](https://help.synology.com/developer-guide/synology_package/INFO_optional_fields.html)
- [Synology Developer Guide - Application Config](https://help.synology.com/developer-guide/integrate_dsm/config.html)
- [Synology Developer Guide - Desktop Application](https://help.synology.com/developer-guide/integrate_dsm/desktopapp.html)
- [SynoCommunity spksrc - Service Support Wiki](https://github.com/SynoCommunity/spksrc/wiki/Service-Support)
- [spksrc/mk/spksrc.service.mk](https://github.com/SynoCommunity/spksrc/blob/master/mk/spksrc.service.mk) - Génération automatique app/config
- [SynoForum - How to open SPK for DSM 7.0](https://www.synoforum.com/threads/how-to-open-spk-for-dsm-7-0.5261/)
- [SynoForum - SPK for DSM 7.x Portal Service](https://www.synoforum.com/threads/spk-for-dsm-7-x-how-to-create-a-portal-service-without-an-icon.9765/)

---

## Sources

### Pelican Panel
- [Pelican.dev](https://pelican.dev/) - Site officiel
- [GitHub pelican-dev/panel](https://github.com/pelican-dev/panel) - Code source
- [Docker Documentation](https://pelican.dev/docs/panel/advanced/docker/) - Déploiement Docker
- [Crowdin Pelican](https://crowdin.com/project/pelican-dev) - Traductions
- [Panel Translations Blog](https://pelican.dev/blog/translations-begin/) - Annonce i18n

### Pelican Wings
- [GitHub pelican-dev/wings](https://github.com/pelican-dev/wings) - Code source
- [Wings Releases](https://github.com/pelican-dev/wings/releases) - Binaires

### Synology
- [Developer Guide - Docker Package](https://help.synology.com/developer-guide/examples/compile_docker_package.html)
- [Docker Project Worker](https://help.synology.com/developer-guide/resource_acquisition/docker-project.html)
- [Container Manager](https://www.synology.com/en-us/dsm/packages/ContainerManager)

### Projet Pterodactyl (Référence)
- [Research.md Pterodactyl](/home/gilles/ProjetSPK/Pterodactyl/specs/pterodactyl-installable/research.md)
- [Constitution Pterodactyl](/home/gilles/ProjetSPK/Pterodactyl/.specify/memory/constitution.md)
