# Tasks: Pelican Panel sur Synology

**Input**: Design documents from `/specs/001-pelican-synology/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Installation manuelle sur DSM 7.2+ ou VM

**Organization**: Tasks groupées par phase pour permettre une implémentation incrémentale.

## Format: `[ID] [P?] Description`

- **[P]**: Peut être exécuté en parallèle (fichiers différents, pas de dépendances)
- Chemins de fichiers exacts inclus dans les descriptions

---

## Phase 1: Structure SPK de base

**Purpose**: Créer la structure de fichiers du paquet SPK

- [x] T001 [P] Créer `spk/pelican/Makefile` avec configuration SPK (nom, version, dépendances)
- [x] T002 [P] Créer `spk/pelican/src/conf/privilege` pour les permissions (run-as: package, groupname: docker)
- [x] T003 [P] Créer `spk/pelican/src/conf/resource` pour la configuration des ports

**Checkpoint**: Structure SPK de base créée ✅

---

## Phase 2: Scripts Lifecycle

**Purpose**: Scripts de gestion du cycle de vie du paquet

- [x] T004 Créer `spk/pelican/src/service-setup.sh` avec hooks preinst/postinst/preupgrade/postupgrade/preuninst/postuninst
- [x] T005 Créer `spk/pelican/src/dsm-control.sh` avec commandes start/stop/status
- [x] T006 [P] Créer `spk/pelican/src/loading-server.sh` pour la page d'attente
- [x] T007 [P] Créer `spk/pelican/src/loading.html` avec animation Pelican (bleu au lieu de rouge)

**Checkpoint**: Scripts lifecycle fonctionnels ✅

---

## Phase 3: Configuration Docker

**Purpose**: Configuration du container Pelican Panel

- [x] T008 Créer `spk/pelican/src/docker/compose.yaml` basé sur contracts/compose.yaml
- [x] T009 Créer `spk/pelican/src/panel.env.example` basé sur contracts/panel.env.example
- [x] T010 Créer `spk/pelican/src/wings.config.example.yml` basé sur contracts/wings.config.example.yml

**Checkpoint**: Configuration Docker prête ✅

---

## Phase 4: Interface DSM

**Purpose**: Wizards d'installation et interface utilisateur DSM

- [x] T011 Créer `spk/pelican/src/wizard/install_uifile` avec wizard 3 étapes (host, admin, info)
- [x] T012 Créer `spk/pelican/src/wizard/uninstall_uifile` avec option suppression données
- [x] T013 Créer `spk/pelican/src/app/config` pour le menu DSM (liens Panel + Wings Config)
- [x] T014 Créer `spk/pelican/src/app/pelican_panel.sc` pour les ports firewall (8080, 8443, 2022)
- [x] T015 Créer `spk/pelican/src/ui/wings-config.cgi` pour la configuration Wings depuis DSM

**Checkpoint**: Interface DSM fonctionnelle ✅

---

## Phase 5: Assets et Build

**Purpose**: Icônes et fichiers de build

- [x] T016 Créer `spk/pelican/src/app/images/` (icônes 16/24/32/48/64/72/256 px)
- [x] T017 Créer `spk/pelican/src/PACKAGE_ICON.PNG` et `PACKAGE_ICON_256.PNG`
- [x] T018 Créer `Makefile` racine pour le build du paquet

**Checkpoint**: Projet prêt pour build ✅

---

## Phase 6: Documentation et Validation

**Purpose**: Vérification finale et documentation

- [x] T019 Valider la cohérence entre contracts/ et fichiers SPK créés
- [x] T020 Mettre à jour specs/001-pelican-synology/quickstart.md si nécessaire
- [x] T021 Marquer la checklist requirements.md comme complète

**Checkpoint**: Projet validé et documenté ✅

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1**: Aucune dépendance - peut commencer immédiatement
- **Phase 2**: Dépend de Phase 1 (Makefile doit exister)
- **Phase 3**: Peut commencer en parallèle avec Phase 2
- **Phase 4**: Peut commencer en parallèle avec Phase 2-3
- **Phase 5**: Dépend de Phases 2-4 (structure complète)
- **Phase 6**: Dépend de toutes les phases précédentes

### Parallel Opportunities

```bash
# Phase 1: Toutes les tâches peuvent être parallélisées
Task: "T001 Makefile SPK"
Task: "T002 conf/privilege"
Task: "T003 conf/resource"

# Phases 2-4: Groupes indépendants
Task Group A: "T004 service-setup.sh" → "T005 dsm-control.sh"
Task Group B: "T006 loading-server.sh" | "T007 loading.html"
Task Group C: "T008 compose.yaml" | "T009 panel.env" | "T010 wings.config"
Task Group D: "T011 install_uifile" | "T012 uninstall_uifile" | "T013-T015 app/*"
```

---

## Implementation Notes

### Différences Pterodactyl → Pelican

| Aspect | Pterodactyl | Pelican |
|--------|-------------|---------|
| Package name | pterodactyl_panel | pelican_panel |
| Port HTTP | 38080 (fixe) | 8080 (configurable via wizard) |
| Database | MariaDB container | SQLite intégré |
| Redis | Container séparé | Non requis (file cache) |
| Image Docker | ccarney/pterodactyl-panel | ghcr.io/pelican-dev/panel:latest |
| Couleur thème | Rouge | Bleu (#4fc3f7) |
| i18n | Non | Oui (APP_LOCALE=fr) |

### Simplifications par rapport à Pterodactyl

1. **Pas de MariaDB** → Pas de wizard_db_password
2. **Pas de Redis** → Pas de container redis
3. **Port configurable** → wizard_port au lieu de port fixe 38080
4. **Langue configurable** → wizard_locale (Français/English)

### Fichiers à adapter

- `service-setup.sh`: Supprimer références MariaDB/Redis, ajouter SQLite
- `dsm-control.sh`: Port dynamique au lieu de fixe
- `install_uifile`: Supprimer étape DB, ajouter langue
- `loading.html`: Couleur bleue Pelican
- `compose.yaml`: Un seul service (panel)

---

## Bugfixes et Améliorations

### 2024-11-30: Validation mot de passe wizard

**Problème**: La confirmation du mot de passe dans le wizard d'installation ne bloquait pas l'installation si les mots de passe étaient différents.

**Solution implémentée**:
1. **Validation côté wizard** (`spk/pelican/src/wizard/install_uifile`):
   - Ajout de `invalid_next_disabled: true` sur l'étape "Compte Administrateur"
   - Ajout d'une fonction de validation `fn` pour comparer les deux champs password

2. **Validation côté script** (`spk/pelican/src/service-setup.sh`):
   - Ajout d'une vérification dans `service_preinst()` qui compare `wizard_admin_password` et `wizard_admin_password_confirm`
   - L'installation échoue avec message d'erreur si les mots de passe ne correspondent pas

**Fichiers modifiés**:
- `spk/pelican/src/wizard/install_uifile`
- `spk/pelican/src/service-setup.sh`

### 2025-11-30: Wings en conteneur Docker + Interface de configuration

**Problème**: Wings était configuré comme binaire natif mais le binaire n'existait pas. Le bouton "Enregistrer & Redémarrer" restait bloqué sur "Enregistrement...".

**Solutions implémentées**:

1. **Wings en conteneur Docker** (`spk/pelican/src/docker/compose.yaml`):
   - Ajout du service Wings avec image `ghcr.io/pelican-dev/wings:latest`
   - Port 8445 pour l'API Wings (évite conflit avec Panel HTTPS 8443)
   - Port 2022 pour SFTP
   - Volumes pour config, serveurs, backups et logs

2. **Interface de configuration Wings** (`spk/pelican/src/app/wings-config.html`):
   - Appels API directs vers le loading-proxy (port 8080) au lieu du CGI DSM
   - Résout le problème de blocage du bouton de sauvegarde

3. **Configuration réseau Docker** (`spk/pelican/src/wings.config.example.yml`):
   - Ajout de la configuration réseau avec subnet `172.20.0.0/16`
   - Évite les conflits d'IP pool avec les réseaux Docker existants

4. **Création des répertoires** (`scripts/package/build-spk.sh`):
   - Ajout des répertoires `servers`, `backups`, `wings-logs` dans `create_data_dirs()`
   - Nécessaire pour le démarrage du conteneur Wings

**Fichiers modifiés**:
- `spk/pelican/src/docker/compose.yaml`
- `spk/pelican/src/app/wings-config.html`
- `spk/pelican/src/wings.config.example.yml`
- `scripts/package/build-spk.sh`

---

## Notes

- Cette feature crée le paquet SPK complet pour Pelican Panel
- Container Manager (Docker) est la seule dépendance système
- SQLite simplifie considérablement l'installation par rapport à Pterodactyl
- Le wizard demande: host, port, email admin, langue
- Wings est déployé en conteneur Docker et configuré via l'interface DSM
- Version actuelle: 1.0.0-70
