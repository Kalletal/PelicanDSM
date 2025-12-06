# Implementation Plan: Pelican Panel sur Synology

**Branch**: `001-pelican-synology` | **Date**: 2025-11-29 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-pelican-synology/spec.md`

## Summary

Porter Pelican Panel (fork de Pterodactyl avec support i18n) sur NAS Synology DS920+ sous forme de paquet SPK installable via Package Center. Le paquet permet aux utilisateurs francophones d'héberger des serveurs de jeux (Minecraft, Counter-Strike, etc.) directement sur leur NAS avec une interface traduite en français.

**Approche technique** : Réutiliser l'architecture validée du projet Pterodactyl en l'adaptant pour Pelican Panel. Utiliser Container Manager Direct (pas de Docker Worker) pour maximiser la flexibilité et la maintenabilité.

## Technical Context

**Language/Version**: Shell scripts (Bash 4+), Python 3.x (loading server)
**Primary Dependencies**: spksrc (Synology Package SDK), Docker/Container Manager
**Storage**: SQLite intégré à Pelican (pas de container MariaDB requis)
**Testing**: Installation manuelle sur DSM 7.2+, VM DSM pour CI
**Target Platform**: Synology DSM 7.2+ (architecture geminilake x86_64)
**Project Type**: SPK Package (Synology Package)
**Performance Goals**: Installation < 5 min, démarrage Panel < 2 min, RAM < 2 GB
**Constraints**: Container Manager ≥1432, ports 8080/8443/2022 disponibles
**Scale/Scope**: Usage domestique, 1-10 serveurs de jeux simultanés

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pilier 1: Intégrité Build Synology ✅

| Exigence | Status | Notes |
|----------|--------|-------|
| `make package` réussit en CI | ✅ Planifié | Réutiliser scripts Pterodactyl |
| spksrc bootstrap + overlays | ✅ Planifié | cross/, native/, spk/ |
| Artefacts .spk + .sha256 | ✅ Planifié | dist/ directory |
| Versions épinglées avec digests | ✅ Planifié | Pelican v1.0.0-beta28 |

### Pilier 2: Fidélité Pelican ✅

| Exigence | Status | Notes |
|----------|--------|-------|
| Suivre releases upstream | ✅ | ghcr.io/pelican-dev/panel:latest |
| Patches Synology documentés | ✅ Planifié | synology/patches/ si nécessaire |
| Configs reflètent upstream | ✅ | compose.yaml conforme |
| Documentation réutilisable | ✅ | quickstart.md créé |

### Pilier 3: Sécurité & Isolation ✅

| Exigence | Status | Notes |
|----------|--------|-------|
| Compte service sc-pelican | ✅ Planifié | SERVICE_USER=auto |
| panel.env chmod 600 | ✅ Planifié | service-setup.sh |
| Logs sans credentials | ✅ Planifié | dsm-control.sh |
| Firewall .sc files | ✅ Planifié | pelican_panel.sc |

### Pilier 4: Discipline Ressources ✅

| Exigence | Status | Notes |
|----------|--------|-------|
| RAM < 2 GB | ✅ | SQLite + pas de Redis = économie |
| Chemins logs documentés | ✅ | /var/packages/pelican_panel/var/ |
| Instructions backup | ✅ | quickstart.md section dépannage |

### Pilier 5: Support & Mise à Jour ✅

| Exigence | Status | Notes |
|----------|--------|-------|
| Compatibilité DSM déclarée | ✅ | DSM 7.2+, geminilake |
| Hooks upgrade préservent données | ✅ Planifié | preupgrade/postupgrade |
| Tests DS920+ avant release | ✅ Planifié | Matrice QA |

**Résultat**: Tous les piliers validés. Aucune exception requise.

## Project Structure

### Documentation (this feature)

```text
specs/001-pelican-synology/
├── plan.md              # Ce fichier
├── spec.md              # Spécification fonctionnelle
├── research.md          # Recherches et décisions techniques
├── data-model.md        # Entités et flux de données
├── quickstart.md        # Guide démarrage rapide
├── contracts/           # Configurations et templates
│   ├── wizard-install.json
│   ├── compose.yaml
│   ├── panel.env.example
│   └── wings.config.example.yml
├── checklists/
│   └── requirements.md  # Checklist validation spec
└── tasks.md             # Tâches d'implémentation (via /speckit.tasks)
```

### Source Code (repository root)

```text
# Structure SPK Synology
scripts/
├── package/
│   ├── common.sh            # Utilitaires partagés
│   ├── bootstrap.sh         # Initialisation spksrc
│   ├── build-spk.sh         # Build principal
│   └── build-wings.sh       # Compilation Wings

cross/
├── pelican-panel/
│   ├── Makefile             # Téléchargement Panel
│   └── digests              # Checksums
└── wings/
    ├── Makefile             # Build Go Wings
    └── digests

spk/
├── pelican/
│   ├── Makefile             # Configuration SPK
│   └── src/
│       ├── app/
│       │   ├── config       # Menu DSM
│       │   ├── images/      # Icônes
│       │   └── pelican_panel.sc  # Ports firewall
│       ├── conf/
│       │   ├── privilege    # Permissions
│       │   └── resource     # Ressources DSM
│       ├── wizard/
│       │   ├── install_uifile    # Assistant install
│       │   └── uninstall_uifile  # Assistant désinstall
│       ├── ui/
│       │   └── wings-config.cgi  # Config Wings DSM
│       ├── docker/
│       │   └── compose.yaml      # Stack Docker
│       ├── service-setup.sh      # Hooks lifecycle
│       ├── dsm-control.sh        # start/stop/status
│       ├── loading-server.sh     # Page attente
│       ├── loading.html          # UI chargement
│       ├── panel.env.example     # Template env
│       └── wings.config.example.yml
└── scripts/
    └── verify-perms.sh      # Validation permissions

dist/                        # Artefacts build
├── pelican_panel-*.spk
└── pelican_panel-*.sha256
```

**Structure Decision**: Structure SPK Synology standard basée sur spksrc, adaptée du projet Pterodactyl. Le code source n'est pas compilé localement (images Docker pré-construites), seuls les scripts de packaging et configuration sont développés.

## Complexity Tracking

> Aucune violation de constitution. Pas de justification de complexité requise.

## Phase 0 Output: Research

**Fichier**: [research.md](./research.md)

### Décisions Clés

| Décision | Choix | Rationale |
|----------|-------|-----------|
| Image Docker | `ghcr.io/pelican-dev/panel:latest` | Image officielle avec Caddy intégré |
| Base de données | SQLite (intégré) | Simplicité, pas de container DB |
| Redis | Non inclus | Pelican supporte file/database cache |
| Wings | Binary natif | Doit accéder à Docker pour gérer jeux |
| Ports | 8080, 8443, 2022 | Évite conflits DSM |
| Architecture Docker | Container Manager Direct | Plus flexible que Workers |

### Leçons Pterodactyl Appliquées

- SESSION_SECURE_COOKIE=false en HTTP
- busybox pour supprimer fichiers uid 999
- Page chargement à chaque start
- Sauvegarde configs seules (pas volumes Docker)

## Phase 1 Output: Design & Contracts

### data-model.md

**Fichier**: [data-model.md](./data-model.md)

- 6 entités principales définies
- Diagrammes de relations
- Flux d'installation, configuration, mise à jour
- Règles de validation
- Transitions d'états

### contracts/

**Fichiers**:
- [wizard-install.json](./contracts/wizard-install.json) - Configuration wizard 3 étapes
- [compose.yaml](./contracts/compose.yaml) - Stack Docker Pelican
- [panel.env.example](./contracts/panel.env.example) - Variables environnement
- [wings.config.example.yml](./contracts/wings.config.example.yml) - Configuration Wings

### quickstart.md

**Fichier**: [quickstart.md](./quickstart.md)

Guide complet couvrant :
- Prérequis système
- Installation pas à pas
- Configuration initiale
- Configuration Wings
- Création premier serveur
- Dépannage courant

## Next Steps

1. **Exécuter `/speckit.tasks`** pour générer les tâches d'implémentation
2. Créer la structure de fichiers dans le repository
3. Adapter les scripts Pterodactyl pour Pelican
4. Créer les icônes et assets visuels Pelican
5. Tester sur DSM 7.2 réel

## References

### Sources Pelican
- [Pelican.dev](https://pelican.dev/)
- [GitHub pelican-dev/panel](https://github.com/pelican-dev/panel)
- [Docker Documentation](https://pelican.dev/docs/panel/advanced/docker/)
- [Crowdin Translations](https://crowdin.com/project/pelican-dev)

### Sources Synology
- [Developer Guide](https://help.synology.com/developer-guide/)
- [Container Manager](https://www.synology.com/en-us/dsm/packages/ContainerManager)

### Projet Référence
- [Pterodactyl SPK](/home/gilles/ProjetSPK/Pterodactyl/)
