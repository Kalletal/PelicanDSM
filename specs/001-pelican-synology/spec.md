# Feature Specification: Pelican Panel sur Synology

**Feature Branch**: `001-pelican-synology`
**Created**: 2025-11-29
**Status**: Draft
**Input**: User description: "Faire le portage de l'application Pelican panel sur Synology pour pouvoir héberger ses meilleurs serveurs de jeu directement chez soi. En toute simplicité."

## Vue d'ensemble

Porter Pelican Panel (fork de Pterodactyl avec support i18n) sur NAS Synology DS920+ sous forme de paquet SPK installable via le Package Center. L'objectif est de permettre aux utilisateurs francophones d'héberger leurs serveurs de jeux (Minecraft, Counter-Strike, etc.) directement sur leur NAS domestique, avec une interface en français et une installation simplifiée.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Installation du paquet SPK (Priority: P1)

En tant que propriétaire de NAS Synology DS920+, je veux installer Pelican Panel via le Package Center DSM pour disposer d'une plateforme de gestion de serveurs de jeux sans configuration complexe.

**Why this priority**: L'installation est le point d'entrée obligatoire. Sans installation fonctionnelle, aucune autre fonctionnalité n'est accessible. C'est le MVP minimal.

**Independent Test**: Peut être testé en téléchargeant le fichier SPK, l'installant via Package Center, et vérifiant que l'interface web est accessible.

**Acceptance Scenarios**:

1. **Given** un NAS DS920+ avec DSM 7.2+ et Container Manager installé, **When** l'utilisateur installe le paquet SPK via "Installation manuelle", **Then** le paquet s'installe en moins de 5 minutes et affiche "Installation terminée"
2. **Given** un paquet SPK installé, **When** l'utilisateur clique sur "Ouvrir" dans Package Center, **Then** l'interface web Pelican Panel s'ouvre dans un nouvel onglet
3. **Given** Container Manager non installé sur le NAS, **When** l'utilisateur tente d'installer le SPK, **Then** un message d'erreur clair indique la dépendance manquante

---

### User Story 2 - Configuration initiale du Panel (Priority: P2)

En tant qu'utilisateur ayant installé le paquet, je veux configurer le Panel (compte admin, base de données) via un assistant guidé pour pouvoir commencer à utiliser la plateforme.

**Why this priority**: Sans configuration initiale, le Panel n'est pas utilisable. C'est la suite logique de l'installation.

**Independent Test**: Après installation, suivre l'assistant de configuration et vérifier que le compte admin fonctionne.

**Acceptance Scenarios**:

1. **Given** le Panel fraîchement installé, **When** l'utilisateur accède à l'interface pour la première fois, **Then** un assistant de configuration s'affiche pour créer le compte administrateur
2. **Given** l'assistant de configuration affiché, **When** l'utilisateur remplit les champs (email, mot de passe), **Then** le compte admin est créé et l'utilisateur est connecté automatiquement
3. **Given** l'utilisateur connecté en tant qu'admin, **When** il accède aux paramètres, **Then** l'interface est affichée en français (basé sur APP_LOCALE=fr)

---

### User Story 3 - Configuration de Wings (Node) (Priority: P2)

En tant qu'administrateur, je veux configurer Wings (le daemon de gestion des conteneurs) sur mon NAS pour pouvoir exécuter des serveurs de jeux.

**Why this priority**: Wings est indispensable pour exécuter les serveurs de jeux. Priorité égale à la configuration initiale.

**Independent Test**: Configurer Wings via l'interface et vérifier que le Node apparaît comme "connecté" dans le Panel.

**Acceptance Scenarios**:

1. **Given** le Panel configuré, **When** l'admin accède à la section "Nodes" et clique sur "Créer un Node", **Then** un formulaire s'affiche avec les informations pré-remplies pour le NAS local
2. **Given** un Node créé dans le Panel, **When** l'admin copie la configuration et l'applique à Wings, **Then** Wings se connecte au Panel et le statut du Node passe à "Connecté"
3. **Given** Wings connecté, **When** l'admin vérifie les ressources disponibles, **Then** la RAM et le CPU du NAS sont correctement détectés

---

### User Story 4 - Création d'un serveur de jeu (Priority: P3)

En tant qu'administrateur du Panel, je veux créer un serveur de jeu (ex: Minecraft) pour héberger une partie avec mes amis.

**Why this priority**: C'est l'objectif final de la plateforme mais nécessite les étapes précédentes.

**Independent Test**: Créer un serveur Minecraft via l'interface et vérifier qu'il démarre correctement.

**Acceptance Scenarios**:

1. **Given** un Panel configuré avec au moins un "Node" (Wings), **When** l'admin crée un nouveau serveur avec le template Minecraft, **Then** le serveur apparaît dans la liste avec statut "Arrêté"
2. **Given** un serveur de jeu créé, **When** l'admin clique sur "Démarrer", **Then** le serveur démarre et le statut passe à "En cours d'exécution" dans les 60 secondes
3. **Given** un serveur Minecraft en cours d'exécution, **When** un joueur se connecte avec l'IP du NAS et le port configuré, **Then** le joueur peut rejoindre la partie

---

### User Story 5 - Mise à jour du paquet (Priority: P4)

En tant qu'utilisateur, je veux pouvoir mettre à jour le paquet SPK vers une nouvelle version sans perdre mes données (serveurs, configurations).

**Why this priority**: Important pour la maintenabilité long terme mais pas bloquant pour l'utilisation initiale.

**Independent Test**: Installer une version, créer des données, mettre à jour vers nouvelle version, vérifier intégrité des données.

**Acceptance Scenarios**:

1. **Given** un paquet version N installé avec des serveurs configurés, **When** l'utilisateur installe la version N+1, **Then** tous les serveurs et configurations sont préservés
2. **Given** une mise à jour en cours, **When** le processus se termine, **Then** les conteneurs Docker redémarrent automatiquement avec la nouvelle configuration

---

### User Story 6 - Désinstallation propre (Priority: P5)

En tant qu'utilisateur, je veux pouvoir désinstaller complètement le paquet et optionnellement supprimer toutes les données associées.

**Why this priority**: Fonctionnalité de maintenance, priorité basse.

**Independent Test**: Désinstaller le paquet et vérifier qu'aucun résidu ne reste sur le système.

**Acceptance Scenarios**:

1. **Given** le paquet installé, **When** l'utilisateur désinstalle via Package Center avec option "Supprimer les données", **Then** tous les fichiers, conteneurs et volumes Docker sont supprimés
2. **Given** le paquet installé, **When** l'utilisateur désinstalle SANS cocher "Supprimer les données", **Then** les données utilisateur sont préservées pour réinstallation future

---

### Edge Cases

- Que se passe-t-il si le NAS n'a pas assez de RAM disponible (< 2 GB libre) ? → Message d'avertissement à l'installation
- Comment le système gère-t-il une coupure de courant pendant l'installation ? → Le paquet reste dans un état partiellement installé, l'utilisateur peut le désinstaller et réessayer
- Que se passe-t-il si les ports par défaut (8080, 8081) sont déjà utilisés ? → L'assistant de configuration propose des ports alternatifs
- Comment gérer un disque plein pendant le téléchargement des images Docker ? → Message d'erreur explicite avec espace requis estimé
- Que faire si Container Manager est mis à jour pendant l'utilisation ? → Le paquet reste fonctionnel, redémarrage des conteneurs peut être nécessaire

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT être distribuable sous forme de paquet SPK installable via Package Center DSM 7.2+
- **FR-002**: Le système DOIT vérifier la présence de Container Manager avant l'installation et afficher un message d'erreur explicite si absent
- **FR-003**: Le système DOIT fournir des templates de configuration (compose.yaml, panel.env) pour déployer les conteneurs via Container Manager
- **FR-004**: Le système DOIT permettre l'accès à l'interface web du Panel via un port configurable (défaut: 8080)
- **FR-005**: Le système DOIT supporter l'internationalisation avec français comme langue disponible (APP_LOCALE=fr)
- **FR-006**: Le système DOIT inclure Wings (daemon de gestion des serveurs de jeux) configurable sur le même NAS
- **FR-007**: Le système DOIT persister toutes les données utilisateur dans /volume1/docker/pelican/ pour faciliter les sauvegardes
- **FR-008**: Le système DOIT supporter la mise à jour du paquet sans perte de données (uniquement sauvegarde des fichiers de configuration)
- **FR-009**: Le système DOIT permettre la suppression complète des données lors de la désinstallation (optionnel via checkbox)
- **FR-010**: Le système DOIT afficher une page de chargement pendant l'initialisation des conteneurs au premier démarrage
- **FR-011**: Le système DOIT fonctionner sur architecture x86_64 geminilake (Intel Celeron J4125 du DS920+)
- **FR-012**: Le système DOIT gérer les permissions des fichiers de base de données (uid 999 pour MariaDB) lors de la désinstallation

### Key Entities

- **Paquet SPK**: Archive installable contenant les binaires Wings, scripts de service, templates de configuration, et métadonnées DSM
- **Panel**: Interface web de gestion des serveurs de jeux, exécutée dans un conteneur Docker (Nginx + PHP)
- **Wings**: Daemon Go responsable de la création et gestion des conteneurs de serveurs de jeux
- **Node**: Représentation d'un serveur physique ou VM capable d'exécuter Wings (dans ce cas, le NAS lui-même)
- **Serveur de jeu**: Instance de jeu (Minecraft, CS:GO, etc.) gérée par Wings dans un conteneur Docker isolé
- **Configuration Panel** (panel.env): Fichier contenant les variables d'environnement du Panel (DB, Redis, secrets)
- **Configuration Wings** (config.yml): Fichier YAML définissant la connexion au Panel et les ressources allouables

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: L'installation du paquet SPK se termine en moins de 5 minutes sur une connexion internet standard (10 Mbps)
- **SC-002**: Le Panel est accessible et fonctionnel dans les 2 minutes suivant le premier démarrage du paquet
- **SC-003**: Un utilisateur sans expérience préalable de Pterodactyl/Pelican peut créer son premier serveur Minecraft en moins de 15 minutes après installation
- **SC-004**: La consommation mémoire totale (Panel + MariaDB + Redis) reste inférieure à 2 GB RAM en fonctionnement normal
- **SC-005**: La mise à jour du paquet préserve 100% des données utilisateur (serveurs, configurations, utilisateurs)
- **SC-006**: 95% des utilisateurs peuvent compléter l'installation sans avoir à consulter de documentation externe
- **SC-007**: L'interface utilisateur est disponible en français pour tous les éléments de navigation et messages principaux

## Assumptions

- L'utilisateur dispose d'un NAS Synology DS920+ ou compatible avec DSM 7.2+
- Container Manager est installé sur le NAS avant l'installation du paquet
- Le NAS dispose d'au moins 4 GB de RAM (8 GB recommandé)
- Une connexion internet est disponible pour télécharger les images Docker lors de la première installation
- L'utilisateur a des droits administrateur sur le NAS
- Les ports 8080 (Panel) et 8081 (Wings) sont disponibles ou l'utilisateur accepte de les configurer
- L'utilisateur utilise le volume1 comme volume principal de stockage

## Out of Scope

- Support d'autres architectures NAS (ARM, autres modèles Intel)
- Installation multi-NAS (cluster de Wings)
- Interface de configuration intégrée dans DSM (première version utilise l'interface web Pelican native)
- Intégration avec les certificats Let's Encrypt de DSM (l'utilisateur configure son reverse proxy manuellement)
- Support de versions DSM antérieures à 7.2
- Création automatique de règles de pare-feu DSM
- Sauvegarde automatique via HyperBackup (documenté mais non automatisé)
