# Pelican Panel SPK pour Synology DS920+

Paquet SPK permettant d'installer [Pelican Panel](https://pelican.dev/) sur un NAS Synology DS920+ (DSM 7.2+ et 7.3+).

## Fonctionnalités

- **Installation simplifiée** via le Centre de Paquets Synology
- **Interface française** par défaut (i18n intégré)
- **Panel + Wings** déployés en conteneurs Docker
- **Wizard d'installation** avec configuration admin
- **Interface de configuration Wings** intégrée à DSM

## Prérequis

- Synology DS920+ (ou compatible geminilake x86_64)
- DSM 7.2 ou supérieur
- Container Manager installé depuis le Centre de Paquets
- 4 GB RAM minimum (8 GB recommandé)

## Installation

1. Télécharger le fichier `.spk` depuis les [Releases](https://github.com/Kalletal/PelicanDSM/releases)
2. Ouvrir le **Centre de Paquets** sur votre NAS
3. Cliquer sur **Installation manuelle**
4. Sélectionner le fichier `pelican_panel-x.x.x-xx-geminilake.spk`
5. Suivre le wizard d'installation

## Configuration

### Wizard d'installation

Le wizard demande :
- **Hôte** : IP ou nom de domaine du NAS (auto-détecté)
- **Port** : Port HTTP du Panel (défaut: 8080)
- **Compte admin** : Email, nom d'utilisateur et mot de passe
- **Langue** : Français ou English

### Configuration Wings

Après l'installation :
1. Accéder au Panel via `http://NAS_IP:8080`
2. Aller dans **Admin** → **Nodes** → **Create New**
3. Configurer le Node avec le FQDN du NAS
4. Copier la configuration YAML générée
5. Dans DSM, ouvrir **Pelican Panel** → **Configurer Wings**
6. Coller la configuration et cliquer sur **Enregistrer & Redémarrer**

## Ports utilisés

| Service | Port | Description |
|---------|------|-------------|
| Panel HTTP | 8080 | Interface web Pelican |
| Wings API | 8445 | API de gestion des serveurs |
| Wings SFTP | 2022 | Accès SFTP aux fichiers serveurs |

## Architecture

```
/var/packages/pelican_panel/
├── var/
│   ├── data/
│   │   ├── pelican-data/     # Base SQLite, uploads, cache
│   │   ├── pelican-logs/     # Logs applicatifs
│   │   ├── wings/            # Configuration Wings
│   │   ├── servers/          # Données des serveurs de jeux
│   │   ├── backups/          # Sauvegardes
│   │   └── wings-logs/       # Logs Wings
│   ├── panel.env             # Configuration Panel
│   └── pelican.log           # Log du paquet
└── share/
    └── docker/
        └── compose.yaml      # Configuration Docker Compose
```

## Build depuis les sources

### Prérequis

- Linux (Ubuntu/Debian recommandé)
- `tar`, `gzip`
- Optionnel : `make`

### Compilation

```bash
# Cloner le dépôt
git clone https://github.com/Kalletal/PelicanDSM.git
cd PelicanDSM

# Construire le paquet
make

# Le fichier .spk est généré dans dist/
ls dist/*.spk
```

## Différences avec Pterodactyl

| Aspect | Pterodactyl | Pelican |
|--------|-------------|---------|
| Interface | Anglais uniquement | Multi-langues (i18n) |
| Base de données | MariaDB requise | SQLite intégré |
| Cache | Redis requis | File cache |
| Maintenance | Abandonné | Actif |

## Dépannage

### Le Panel ne démarre pas

Vérifier les logs :
```bash
# Via SSH sur le NAS
cat /var/packages/pelican_panel/var/pelican.log
docker logs pelican_panel-panel-1
```

### Wings reste en statut "Arrêté"

1. Vérifier que la configuration Wings a été copiée depuis le Panel
2. Vérifier les logs Wings :
```bash
docker logs pelican_panel-wings-1
```

### Erreur de réseau Docker

Si Wings ne démarre pas à cause d'un conflit IP :
1. Le subnet par défaut est `172.20.0.0/16`
2. Modifier dans la configuration Wings si conflit avec un réseau existant

## Licence

Ce projet est sous licence MIT.

## Crédits

- [Pelican Panel](https://pelican.dev/) - Fork actif de Pterodactyl avec i18n
- [Synology DSM](https://www.synology.com/) - Système d'exploitation NAS
