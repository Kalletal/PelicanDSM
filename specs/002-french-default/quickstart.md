# Guide Rapide – Configuration de la Langue

## Résumé

Cette feature configure le paquet Pelican Panel SPK pour :
- **Français présélectionné** comme langue par défaut
- **Choix simplifié** : Français ou Anglais uniquement

## Lors de l'Installation

### Étape de sélection de langue

Lors de l'installation du paquet via Package Center, l'assistant affiche :

```
┌─────────────────────────────────────────┐
│  Langue de l'interface                  │
│  ┌───────────────────────────────────┐  │
│  │  ● Français  ← présélectionné     │  │
│  │  ○ English                         │  │
│  └───────────────────────────────────┘  │
│                                          │
│  Langue par défaut du Panel              │
│  (modifiable ensuite dans les paramètres)│
└─────────────────────────────────────────┘
```

**Action par défaut** : Ne rien changer → Le Panel sera en français.

## Après l'Installation

### Vérifier la langue

1. Accédez au Panel : `http://IP_NAS:8080`
2. Connectez-vous avec votre compte admin
3. Vérifiez que l'interface est en français (menus, boutons, messages)

### Changer de langue (optionnel)

Si vous souhaitez passer en anglais après installation :

1. Connectez-vous au Panel en tant qu'admin
2. Allez dans **Administration** → **Paramètres** (ou **Settings**)
3. Trouvez l'option **Langue** / **Language**
4. Sélectionnez **English**
5. Sauvegardez

Note : Le changement est immédiat, pas besoin de redémarrer.

## Variables d'Environnement

| Variable | Valeur | Description |
|----------|--------|-------------|
| `APP_LOCALE` | `fr` | Interface en français |
| `APP_LOCALE` | `en` | Interface en anglais |

Cette variable est configurée automatiquement dans `panel.env` selon votre choix lors de l'installation.

## FAQ

### Pourquoi seulement Français et Anglais ?

Ce paquet SPK cible principalement les utilisateurs francophones. L'anglais est proposé comme alternative pour ceux qui préfèrent suivre la documentation originale.

### Puis-je ajouter d'autres langues ?

Pelican Panel supporte de nombreuses langues via son système i18n. Après installation, vous pouvez modifier `APP_LOCALE` dans le fichier `panel.env` pour utiliser d'autres codes de langue supportés par Pelican (ex: `de`, `es`, `it`).

### La traduction française est-elle complète ?

Pelican utilise Crowdin pour ses traductions. Le français est activement traduit. Les chaînes non encore traduites s'affichent en anglais (comportement standard).

Contribuez aux traductions : https://crowdin.com/project/pelican-dev
