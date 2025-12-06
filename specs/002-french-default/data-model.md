# Data Model – Français comme langue par défaut

**Feature**: `002-french-default`
**Created**: 2025-11-29
**Parent**: `001-pelican-synology`

## Overview

Cette feature modifie une entité existante (`wizard_locale`) définie dans la feature parente. Aucune nouvelle entité n'est créée.

---

## Entité Modifiée: Configuration Langue

### Définition

| Attribut | Type | Description |
|----------|------|-------------|
| `wizard_locale` | enum | Langue sélectionnée lors de l'installation |

### Valeurs (AVANT modification)

```
wizard_locale ∈ { fr, en, de, es, it, pt, ru, zh, ja, ko }
default = "fr"
```

### Valeurs (APRÈS modification)

```
wizard_locale ∈ { fr, en }
default = "fr"
```

### Mapping vers Pelican

| wizard_locale | APP_LOCALE | Résultat |
|---------------|------------|----------|
| `fr` | `fr` | Interface en français |
| `en` | `en` | Interface en anglais |

---

## Flux de Données

### Installation

```
┌─────────────────────────────────────────────────────────┐
│                  Wizard Installation                     │
│                                                          │
│  Étape 2: Compte Administrateur                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Langue de l'interface:                          │   │
│  │  ┌─────────────────────────────────────────┐    │   │
│  │  │  ○ Français  ← (présélectionné)         │    │   │
│  │  │  ○ English                               │    │   │
│  │  └─────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│                      ↓ Sélection                         │
│                                                          │
│  wizard_locale = "fr" ou "en"                           │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│               service-setup.sh                           │
│                                                          │
│  hydrate_env_file():                                    │
│    APP_LOCALE=${wizard_locale}                          │
│                                                          │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    panel.env                             │
│                                                          │
│  APP_LOCALE=fr   # ou "en" si sélectionné               │
│                                                          │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│              Pelican Panel Container                     │
│                                                          │
│  L'application lit APP_LOCALE et charge                 │
│  les traductions correspondantes via son                │
│  système i18n React.                                    │
│                                                          │
│  Interface affichée en: Français ou English             │
└─────────────────────────────────────────────────────────┘
```

---

## Validation Rules

| Règle | Implémentation |
|-------|----------------|
| `wizard_locale` doit être `fr` ou `en` | Enforced par le select du wizard |
| Valeur par défaut = `fr` | `"default": "fr"` dans config |
| Champ obligatoire | `"required": true` |

---

## State Transitions

Aucune transition d'état complexe. La langue est configurée une fois à l'installation et persiste.

### Changement post-installation

Si l'utilisateur souhaite changer de langue après installation :

```
Panel Dashboard
     ↓
Administration → Settings
     ↓
Language: [Dropdown]
     ↓
Sauvegarder
     ↓
APP_LOCALE modifié dans base de données Pelican
(panel.env non modifié)
```

Note: Le changement via l'interface Panel ne modifie pas `panel.env`, mais la configuration interne de Pelican.
