# Guide de Démarrage Rapide – Pelican Panel sur Synology

## Prérequis

Avant d'installer le paquet Pelican Panel, assurez-vous que votre NAS Synology répond aux exigences suivantes :

| Prérequis | Minimum | Recommandé |
|-----------|---------|------------|
| **Modèle** | DS920+ ou compatible | DS920+, DS1520+, DS1821+ |
| **DSM** | 7.2+ | 7.2.1+ |
| **RAM** | 4 GB | 8 GB+ |
| **Stockage** | 5 GB libre | 20 GB+ |
| **Container Manager** | Installé et démarré | Version 20.10.23+ |

## Installation

### Étape 1 : Télécharger le paquet SPK

Téléchargez le fichier `pelican_panel-x.x.x-geminilake.spk` depuis :
- [Releases GitHub](https://github.com/votre-repo/releases)
- Ou le lien fourni par le mainteneur

### Étape 2 : Installation via Package Center

1. Ouvrez **Package Center** sur votre NAS
2. Cliquez sur **Installation manuelle**
3. Sélectionnez le fichier `.spk` téléchargé
4. Suivez l'assistant d'installation :
   - **Adresse du NAS** : IP ou nom de domaine de votre NAS
   - **Port** : 8080 (par défaut, modifiable)
   - **Email admin** : Votre adresse email
   - **Langue** : Français (par défaut) ou English
5. Cliquez **Suivant** puis **Appliquer**

### Étape 3 : Attendre l'initialisation

Une page de chargement s'affiche pendant que :
- Les images Docker sont téléchargées (~500 MB)
- La base de données est initialisée
- Le Panel démarre

**Durée** : 2-5 minutes selon votre connexion internet.

## Configuration Initiale

### Étape 4 : Accéder au Panel

Ouvrez votre navigateur et accédez à :
```
http://IP_DU_NAS:8080
```

Vous serez redirigé vers l'assistant de configuration Pelican.

### Étape 5 : Compléter l'assistant web

1. **Database** : SQLite (pré-configuré, cliquez Suivant)
2. **Redis** : File (cache local, cliquez Suivant)
3. **Admin Account** :
   - Email : (pré-rempli depuis le wizard)
   - Username : Choisissez un nom d'utilisateur
   - Password : Créez un mot de passe fort
4. **Mail** : Configurez ou ignorez (configurable plus tard)
5. Cliquez **Finish**

### Étape 6 : Connexion

Connectez-vous avec le compte admin que vous venez de créer.

🎉 **Félicitations !** Votre Panel Pelican est prêt.

## Configuration de Wings

Pour héberger des serveurs de jeux, vous devez configurer Wings (le daemon de gestion).

### Étape 7 : Créer un Node dans le Panel

1. Connectez-vous au Panel en tant qu'admin
2. Allez dans **Admin** → **Nodes** → **Create New**
3. Remplissez les informations :
   - **Name** : Mon NAS (ou autre nom)
   - **FQDN** : IP ou hostname du NAS
   - **Total Memory** : RAM à allouer (ex: 4096 MB)
   - **Total Disk** : Espace disque à allouer (ex: 50000 MB)
4. Cliquez **Create Node**

### Étape 8 : Récupérer la configuration Wings

1. Cliquez sur le Node créé
2. Allez dans l'onglet **Configuration**
3. Cliquez **Generate Token** pour créer un token d'authentification
4. Copiez le contenu de la section **Configuration File**

### Étape 9 : Appliquer la configuration Wings

1. Dans DSM, ouvrez **Package Center**
2. Trouvez **Pelican Panel** dans la liste
3. Cliquez sur **Configurer Wings** (ou ouvrez le menu déroulant)
4. Collez la configuration copiée
5. Cliquez **Sauvegarder et Redémarrer**

### Étape 10 : Vérifier la connexion

1. Retournez dans le Panel → **Admin** → **Nodes**
2. Votre Node devrait afficher **Connected** (vert)

Si le statut reste "Disconnected", vérifiez :
- Les ports 8443 et 2022 sont ouverts dans le pare-feu DSM
- L'URL du Panel est accessible depuis le NAS

## Créer votre premier serveur de jeu

### Étape 11 : Ajouter un Egg (template de jeu)

1. **Admin** → **Nests** → Import Eggs
2. Importez depuis le repository officiel :
   - Minecraft, Terraria, Valheim, etc.
3. Ou créez un Nest personnalisé

### Étape 12 : Créer un serveur

1. **Admin** → **Servers** → **Create New**
2. Configurez :
   - **Name** : Mon Serveur Minecraft
   - **Owner** : Sélectionnez l'utilisateur
   - **Node** : Votre Node configuré
   - **Nest/Egg** : Sélectionnez le jeu
3. Définissez les ressources :
   - Memory, Disk, CPU
4. Cliquez **Create Server**

### Étape 13 : Démarrer le serveur

1. Allez sur la page du serveur créé
2. Cliquez **Start**
3. Suivez les logs de démarrage
4. Une fois prêt, connectez-vous au jeu avec `IP_NAS:PORT`

## Ports et Pare-feu

### Ports utilisés par défaut

| Service | Port | Protocole | Description |
|---------|------|-----------|-------------|
| Panel HTTP | 8080 | TCP | Interface web |
| Panel HTTPS | 8443 | TCP | Interface web sécurisée |
| Wings API | 8443 | TCP | Communication Panel-Wings |
| Wings SFTP | 2022 | TCP | Accès fichiers serveurs |
| Game Servers | 25565+ | TCP/UDP | Ports des jeux (variable) |

### Configuration pare-feu DSM

1. **Panneau de configuration** → **Sécurité** → **Pare-feu**
2. Créez des règles pour autoriser les ports ci-dessus
3. Pour les serveurs de jeux, créez une plage (ex: 25565-25600)

## Reverse Proxy (HTTPS)

Pour accéder au Panel en HTTPS via le reverse proxy DSM :

1. **Panneau de configuration** → **Portail de connexion** → **Avancé**
2. **Proxy inverse** → **Créer**
3. Configurez :
   - Source : `pelican.votredomaine.com` (HTTPS, 443)
   - Destination : `localhost:8080` (HTTP)
4. Modifiez `panel.env` :
   ```
   APP_URL=https://pelican.votredomaine.com
   SESSION_SECURE_COOKIE=true
   ```
5. Redémarrez le paquet

## Dépannage

### Le Panel ne démarre pas

```bash
# Via SSH sur le NAS
docker logs pelican_panel-panel-1
```

### Wings ne se connecte pas

1. Vérifiez la configuration dans `/var/packages/pelican_panel/var/data/wings/config.yml`
2. Vérifiez que l'URL du Panel est accessible :
   ```bash
   curl -I http://IP_NAS:8080
   ```
3. Consultez les logs Wings :
   ```bash
   cat /var/packages/pelican_panel/var/data/wings/wings.log
   ```

### Erreur CSRF Token

Si vous obtenez "CSRF token mismatch" :
1. Vérifiez que `SESSION_SECURE_COOKIE=false` si vous accédez en HTTP
2. Ou configurez HTTPS via reverse proxy

### Réinitialisation complète

Pour recommencer à zéro :
1. Désinstallez le paquet avec "Supprimer les données" coché
2. Réinstallez le paquet
3. Suivez à nouveau l'assistant

## Support

- **Documentation Pelican** : https://pelican.dev/docs
- **Discord Pelican** : https://discord.gg/pelican-panel
- **GitHub Issues** : Lien vers votre repository

---

*Guide créé le 2025-11-29 pour Pelican Panel v1.0.0-beta28*
