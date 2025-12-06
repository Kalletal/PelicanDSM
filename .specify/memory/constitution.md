# Pelican Panel Synology SPK Constitution

## Mission
Offrir une expérience Pelican Panel + Wings de qualité professionnelle aux propriétaires de NAS Synology DS920+ en
livrant des paquets `.spk` reproductibles, sécurisés pour DSM 7.2+, et entièrement utilisables via les artefacts,
scripts et documentation de ce dépôt.

**Pourquoi Pelican plutôt que Pterodactyl** : Pelican Panel est un fork actif de Pterodactyl qui implémente
le support d'internationalisation (i18n) via Crowdin, permettant une interface en français. Le projet Pterodactyl
original n'a pas de système i18n dans son frontend React (texte codé en dur en anglais).

## Piliers Directeurs

### 1. Intégrité Build Synology
- `make package` DOIT réussir localement et en CI (GitHub Actions utilisant `synologytoolkit/dsm7.2:7.2-64570`)
  via les scripts `scripts/package/*` et `Makefile`, ciblant `ARCH=geminilake` / `TCVERSION=7.2`.
- Les scripts de build DOIVENT cloner/synchroniser **spksrc** upstream et superposer nos définitions `cross/`,
  `native/`, et `spk/`; toute déviation nécessite une justification documentée.
- Chaque build DOIT produire `.spk`, `.sha256`, et logs sous `dist/`; les releases doivent attacher ces
  artefacts verbatim pour vérification de provenance.
- Les définitions `cross/pelican-panel` et `cross/wings` DOIVENT épingler les versions upstream avec `digests`
  correspondants, `spk/pelican/Makefile` étant l'unique source de vérité pour les métadonnées INFO,
  dépendances, ports firewall et staging `POST_STRIP_TARGET`.

### 2. Fidélité Pelican
- Panel et Wings DOIVENT suivre les releases taggées Pelican upstream; tout patch Synology vit sous
  `synology/patches/**` avec justification liée dans CHANGELOG et issues upstream.
- Les fichiers `panel.env.example`, `wings.config.example.yml`, et `compose.yaml` DOIVENT refléter les
  défauts upstream sauf où les chemins/ports DSM exigent des surcharges, documentées dans wizard et docs.
- Les packages `cross/` DOIVENT rester agnostiques à l'architecture sauf si une fonctionnalité ne peut
  tourner sur DS920+; dans ce cas, la spec doit enregistrer la limitation.
- Les opérateurs DOIVENT pouvoir réutiliser la documentation upstream Pelican : les clés env renommées,
  changements API, ou modifications Wings requièrent snippets de migration dans `docs/`.

### 3. Sécurité & Isolation
- Le compte service `sc-pelican` est le seul utilisateur autorisé à posséder `/var/packages/pelican/*`;
  `service-setup.sh` DOIT imposer ownership et `chmod 600` pour `panel.env`, tokens Wings, et fichiers secrets.
- Les scripts start/stop (`dsm-control.sh`) DOIVENT refuser de s'exécuter si Container Manager est indisponible,
  logger toutes transitions de cycle de vie vers `/var/packages/pelican/var/pelican.log`, et ne jamais
  exposer credentials via stdout.
- Les fichiers firewall `.sc` et bindings certificats DSM DOIVENT être mis à jour dès que ports ou flux TLS changent.
- La gestion des secrets et attentes TLS DOIVENT apparaître dans wizard + docs opérateur.

### 4. Discipline Ressources & Observabilité
- Le runtime baseline (Panel + MariaDB + Redis) DOIT rester sous 2 GB RAM et 70% CPU agrégé sur DS920+ stock;
  les specs modifiant docker-compose doivent inclure nouvelles mesures ou plan de mitigation.
- Les chemins de logs (`/var/packages/pelican/var/pelican.log`, logs containers, intégration DSM Log Center)
  DOIVENT rester découvrables et documentés.
- Les instructions backup & restore DOIVENT couvrir snapshots DB panel, volumes docker sous
  `/var/packages/pelican/var/data/**`, `.env`, et configs Wings.
- Les hooks monitoring (endpoints santé, heartbeat Wings, métriques docker) DOIVENT rester scriptables.

### 5. Chemin de Support & Mise à Jour
- Chaque changement DOIT déclarer compatibilité build DSM, prérequis ContainerManager, et si une mise à jour
  package, restart, ou action opérateur est nécessaire.
- Les hooks upgrade (`service_preupgrade`, `service_postupgrade`) DOIVENT garder les données utilisateur intactes;
  seuls les fichiers de configuration sont sauvegardés (pas les données Docker volumineuses).
- Les tests sur DS920+ physique (ou équivalent VM DSM documenté) DOIVENT précéder les releases stables.
- SemVer s'applique au SPK et à cette constitution : changement breaking = bump MAJOR, contraintes additives = MINOR.

## Directives d'Implémentation

### Architecture Container Manager (Approche Recommandée)

Suite aux recherches du projet Pterodactyl, l'approche **Container Manager Direct** est privilégiée :

| Approche | Complexité SPK | UX Utilisateur | Maintenabilité |
|----------|----------------|----------------|----------------|
| Docker Worker (JSON) | Élevée | One-click | Difficile |
| Docker Project Worker | Moyenne | One-click | Moyenne |
| **Container Manager Direct** | Faible | 2 étapes | **Facile** |

**Justification** : Container Manager Direct offre le meilleur compromis. Les Workers Synology ajoutent
une couche d'abstraction problématique lors des mises à jour DSM/ContainerManager.

**Structure d'installation** :
1. Le SPK installe Wings + helpers + templates (`compose.yaml.example`, `.env.example`)
2. L'utilisateur copie les templates vers `/volume1/docker/pelican/`
3. L'utilisateur crée un Project dans Container Manager
4. Wings est configuré via le Panel

### Build & Packaging Flow
- `scripts/package/common.sh` gouverne détection toolchain, builds dockerisés, overlays rsync, et collection artefacts.
- Les scripts de build DOIVENT rester idempotents, logger clairement les versions, et échouer bruyamment
  quand les prérequis hôte sont manquants.
- Tous nouveaux binaires/configs doivent être stagés via `POST_STRIP_TARGET` dans le Makefile.
- Les digests (`cross/*/digests`) DOIVENT être régénérés dès changement des tarballs upstream.

### Gestion Configuration & Données
- L'état mutable vit sous `/var/packages/pelican/var`: `var/data/**` pour volumes docker,
  `var/panel.env`, `var/data/wings/config.yml`, `var/pelican.log`.
- `compose.yaml` est la topologie runtime autoritaire. Changer services, ports, ou volumes requiert
  mise à jour wizard, templates env, et documentation reverse proxies/TLS.
- Volumes Docker : Toujours utiliser chemins absolus `/volumeX/docker/pelican/` pour bind mounts.
- Suppression données : Utiliser `busybox` via Docker pour supprimer fichiers appartenant aux containers
  (ex: uid 999 pour mysql).

### Leçons Apprises du Projet Pterodactyl

| Problème Identifié | Solution Appliquée |
|--------------------|--------------------|
| CSRF token mismatch | `SESSION_SECURE_COOKIE=false` si accès HTTP |
| Fichiers DB non supprimables | `docker run busybox rm -rf` pour uid 999 |
| Page de chargement | Afficher à chaque démarrage, pas seulement première install |
| Performance installation | Sauvegarder uniquement configs, pas données Docker |
| Serveur HTTP Python 404 | Handler custom redirigeant tout vers index.html |
| Docker Worker non fonctionnel | `conf/resource` doit inclure config `docker-project` |

### Testing & Validation
- Suite regression minimum par PR: `make package`, `verify-perms.sh` contre staging tree,
  et smoke test docker-compose (panel accessible, wings s'enregistre).
- Les logs CI DOIVENT être attachés aux PRs. Échecs non acceptables sans issue documentant cause racine.
- Matrice QA manuelle pour releases: install VM DSM → configurer DB/Redis → créer serveur jeu →
  heartbeat wings → backup/restore → désinstall.

### Documentation & Workflow Release
- Chaque changement comportemental requiert mise à jour docs (README/guide opérateur, CHANGELOG, release notes).
- Les PRs release DOIVENT inclure matrice dépendances (DSM, ContainerManager), étapes upgrade, plan rollback,
  et liens vers artefacts build.

### Support Internationalisation (i18n)

L'avantage principal de Pelican sur Pterodactyl :
- **Pelican** : Frontend React avec système i18n intégré, traductions via Crowdin
- **Pterodactyl** : Texte hardcodé en anglais dans React, pas de i18n

Fichiers de traduction Pelican :
- Interface utilisateur : Gérée par le système i18n React de Pelican
- Messages backend Laravel : Fichiers `/resources/lang/` standard
- Variable `APP_LOCALE=fr` : Effective pour backend ET frontend sur Pelican

## Prérequis Techniques

### Synology DS920+
- DSM 7.2+ avec ContainerManager ≥1432
- Architecture: x86_64 geminilake (Intel Celeron J4125)
- RAM recommandée: 8GB minimum, 20GB maximum supporté
- Docker Engine: 20.10.23+ ou 24.0.2+

### Dépendances Container
- Pelican Panel: Image officielle `ghcr.io/pelican/panel` (Nginx + PHP-FPM)
- MariaDB: 10.5+ (`mariadb:10.5`)
- Redis: 7.2+ (`redis:7.2-alpine`)
- Wings: Binary Go natif ou container

### Configuration Réseau
- Mode réseau recommandé: **bridge** (pas host, pas macvlan)
- Ports par défaut: Panel 8080, Wings 8081
- Reverse proxy DSM pour HTTPS recommandé

## Gouvernance & Conformité
- Cette constitution gouverne tout travail dans ce dépôt. Amendements requièrent consensus maintainer via PR
  citant le déclencheur (update DSM, changement upstream, incident sécurité), mise à jour templates impactés,
  et bump version selon SemVer.
- La conformité est vérifiée pendant review plan/spec, review PR, et avant signature SPK.
- Le texte ratifié vit dans `.specify/memory/constitution.md`; templates sous `.specify/templates/**`
  doivent rester synchronisés avec les principes actuels.

## Références

### Documentation Synology
- [Docker Project Worker](https://help.synology.com/developer-guide/resource_acquisition/docker-project.html)
- [Docker Worker](https://help.synology.com/developer-guide/resource_acquisition/docker.html)
- [Container Manager Package](https://www.synology.com/en-us/dsm/packages/ContainerManager)

### Documentation Pelican
- [Pelican.dev](https://pelican.dev/) - Site officiel
- [Pelican GitHub](https://github.com/pelican-dev/panel) - Code source
- [Crowdin Pelican](https://crowdin.com/project/pelican) - Traductions

### Projet Pterodactyl (Référence)
- Recherches et solutions : `/home/gilles/ProjetSPK/Pterodactyl/specs/pterodactyl-installable/research.md`
- Constitution v1.3.0 : `/home/gilles/ProjetSPK/Pterodactyl/.specify/memory/constitution.md`

**Version**: 1.0.0 | **Ratified**: 2025-11-29 | **Last Amended**: 2025-11-29
