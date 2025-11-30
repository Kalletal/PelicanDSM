# Implementation Plan: Français comme langue par défaut

**Branch**: `002-french-default` | **Date**: 2025-11-29 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-french-default/spec.md`
**Parent Feature**: `001-pelican-synology`

## Summary

Modifier le wizard d'installation du paquet SPK Pelican Panel pour :
1. Présenter le français comme langue présélectionnée par défaut
2. Limiter le choix à deux langues : Français et Anglais

Cette feature est une **modification de configuration** de la feature parente `001-pelican-synology`, affectant uniquement le fichier `wizard-install.json` (et sa transposition en `install_uifile` pour DSM).

## Technical Context

**Language/Version**: JSON (wizard configuration), Shell scripts (Bash 4+)
**Primary Dependencies**: Feature `001-pelican-synology` (wizard d'installation)
**Storage**: N/A (configuration uniquement)
**Testing**: Test manuel sur DSM 7.2+
**Target Platform**: Synology DSM 7.2+ (architecture geminilake x86_64)
**Project Type**: Configuration SPK
**Performance Goals**: N/A (pas d'impact performance)
**Constraints**: Compatibilité format wizard DSM
**Scale/Scope**: Modification de 1 fichier de configuration

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pilier 1: Intégrité Build Synology ✅

| Exigence | Status | Notes |
|----------|--------|-------|
| Modification de config seulement | ✅ | Pas de changement de build |
| Format wizard valide | ✅ | JSON standard DSM |

### Pilier 2: Fidélité Pelican ✅

| Exigence | Status | Notes |
|----------|--------|-------|
| APP_LOCALE supporté | ✅ | `fr` et `en` sont des locales Pelican valides |
| Pas de patch upstream | ✅ | Utilise l'i18n natif Pelican |

### Pilier 3: Sécurité & Isolation ✅

| Exigence | Status | Notes |
|----------|--------|-------|
| Pas d'impact sécurité | ✅ | Changement cosmétique |

### Pilier 4: Discipline Ressources ✅

| Exigence | Status | Notes |
|----------|--------|-------|
| Pas d'impact performance | ✅ | Configuration seulement |

### Pilier 5: Support & Mise à Jour ✅

| Exigence | Status | Notes |
|----------|--------|-------|
| Documentation à jour | ✅ Planifié | Modifier quickstart.md parent |
| Rétrocompatibilité | ✅ | Installations existantes non affectées |

**Résultat**: Tous les piliers validés. Changement mineur de configuration.

## Project Structure

### Documentation (this feature)

```text
specs/002-french-default/
├── plan.md              # Ce fichier
├── spec.md              # Spécification fonctionnelle
├── research.md          # Recherche (minimal pour cette feature)
├── data-model.md        # Modèle de données (entité locale)
├── contracts/           # Configuration wizard modifiée
│   └── wizard-install.json
├── checklists/
│   └── requirements.md  # Checklist validation spec
└── tasks.md             # Tâches d'implémentation (via /speckit.tasks)
```

### Fichiers Modifiés (dans feature parent)

```text
# Fichiers de 001-pelican-synology à modifier :
specs/001-pelican-synology/contracts/wizard-install.json  # Réduire options langue
spk/pelican/src/wizard/install_uifile                     # Équivalent DSM natif
specs/001-pelican-synology/quickstart.md                  # Mettre à jour doc
```

**Structure Decision**: Cette feature ne crée pas de nouveau code source, elle modifie la configuration du wizard définie dans `001-pelican-synology`.

## Complexity Tracking

> Aucune violation de constitution. Changement de configuration simple.

## Phase 0 Output: Research

### Recherche: Support i18n Pelican

**Question**: Pelican supporte-t-il les locales `fr` et `en` ?

**Résultat**: Oui, confirmé.

| Locale | Support | Source |
|--------|---------|--------|
| `fr` | ✅ Oui | Crowdin, traductions actives |
| `en` | ✅ Oui | Langue par défaut upstream |

**Décision**: Limiter à `fr` et `en` est sûr.
**Rationale**: Ce sont les deux langues les plus pertinentes pour le public cible francophone.
**Alternatives rejetées**: Garder toutes les langues (complexité inutile), ajouter d'autres langues européennes (hors scope).

### Recherche: Format Wizard DSM

**Question**: Comment définir une valeur par défaut dans le wizard DSM ?

**Résultat**: Le format JSON utilise la propriété `"default"` dans les champs de type `select`.

```json
{
  "id": "wizard_locale",
  "type": "select",
  "default": "fr",  // ← Valeur présélectionnée
  "options": [...]
}
```

**Décision**: Utiliser `"default": "fr"` (déjà en place dans le wizard actuel).

## Phase 1 Output: Design & Contracts

### data-model.md

**Entité unique**: Configuration Langue

| Champ | Type | Valeurs | Défaut |
|-------|------|---------|--------|
| `wizard_locale` | enum | `fr`, `en` | `fr` |

**Mapping vers Pelican**:
- `wizard_locale=fr` → `APP_LOCALE=fr`
- `wizard_locale=en` → `APP_LOCALE=en`

### contracts/wizard-install.json (modifié)

Modification du champ `wizard_locale` dans le wizard :

**Avant** (10 langues):
```json
"options": [
  {"value": "fr", "label": "Français"},
  {"value": "en", "label": "English"},
  {"value": "de", "label": "Deutsch"},
  {"value": "es", "label": "Español"},
  {"value": "it", "label": "Italiano"},
  {"value": "pt", "label": "Português"},
  {"value": "ru", "label": "Русский"},
  {"value": "zh", "label": "中文"},
  {"value": "ja", "label": "日本語"},
  {"value": "ko", "label": "한국어"}
]
```

**Après** (2 langues):
```json
"options": [
  {"value": "fr", "label": "Français"},
  {"value": "en", "label": "English"}
]
```

La propriété `"default": "fr"` est déjà en place.

### quickstart.md (mise à jour)

Modifier la section installation pour refléter le choix simplifié :

**Avant**: "Langue : Français (ou autre)"
**Après**: "Langue : Français (par défaut) ou English"

## Next Steps

1. **Exécuter `/speckit.tasks`** pour générer les tâches
2. Modifier `specs/001-pelican-synology/contracts/wizard-install.json`
3. Mettre à jour `specs/001-pelican-synology/quickstart.md`
4. Tester l'installation sur DSM

## Impact Analysis

| Élément | Impact | Action |
|---------|--------|--------|
| Nouvelles installations | ✅ Français par défaut, 2 choix | Automatique |
| Installations existantes | ⚠️ Aucun | Langue déjà configurée |
| Mise à jour SPK | ⚠️ Aucun | Config préservée |
| Documentation | 🔄 Mineure | Mettre à jour quickstart |

## References

- Feature parent: [001-pelican-synology](../001-pelican-synology/)
- Crowdin Pelican: https://crowdin.com/project/pelican-dev
- Synology Wizard Format: https://help.synology.com/developer-guide/
