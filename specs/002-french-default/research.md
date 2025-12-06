# Research Log – Français comme langue par défaut
**Date**: 2025-11-29
**Owner**: speckit research phase
**Spec**: `specs/002-french-default/spec.md`
**Parent**: `001-pelican-synology`

## Goals
- Confirmer que Pelican supporte les locales `fr` et `en`
- Valider le format de configuration du wizard DSM
- Documenter le changement de configuration requis

## Recherche: Support i18n Pelican

### Question
Pelican Panel supporte-t-il les locales `fr` (Français) et `en` (English) via la variable `APP_LOCALE` ?

### Résultat

| Locale | Support | Source | Notes |
|--------|---------|--------|-------|
| `en` | ✅ Oui | Langue par défaut | 100% des chaînes |
| `fr` | ✅ Oui | Crowdin active | Traduction en cours, >80% estimé |

**Sources**:
- https://crowdin.com/project/pelican-dev
- https://pelican.dev/blog/translations-begin/
- Constitution projet: `.specify/memory/constitution.md` section "Support Internationalisation"

### Décision
**Choix**: Limiter le wizard à `fr` et `en` uniquement.

**Rationale**:
1. Public cible francophone → français par défaut
2. Anglais comme fallback universel (documentation, tutoriels)
3. Simplification UX : pas de recherche dans une longue liste

**Alternatives rejetées**:
- Garder 10 langues : Complexité inutile pour le public cible
- Français uniquement : Certains utilisateurs préfèrent l'anglais
- Ajouter allemand/espagnol : Hors scope, peut être ajouté plus tard

---

## Recherche: Format Wizard DSM

### Question
Comment définir une valeur par défaut présélectionnée dans le wizard d'installation DSM ?

### Résultat

Le fichier `install_uifile` (JSON) utilise la structure suivante pour les champs de type `combobox`/`select` :

```json
{
  "type": "combobox",
  "subitems": [
    {
      "key": "wizard_locale",
      "desc": "Langue de l'interface",
      "defaultValue": "fr",
      "editable": false,
      "items": [
        { "value": "fr", "displayValue": "Français" },
        { "value": "en", "displayValue": "English" }
      ]
    }
  ]
}
```

**Propriété clé**: `"defaultValue": "fr"` → Français présélectionné.

**Source**:
- Documentation Synology Developer Guide
- Analyse du projet Pterodactyl: `/home/gilles/ProjetSPK/Pterodactyl/spk/pterodactyl/src/wizard/install_uifile`

### Décision
**Choix**: Utiliser `"defaultValue": "fr"` dans le wizard.

**Rationale**: Format standard DSM, déjà utilisé dans le wizard actuel de `001-pelican-synology`.

---

## Recherche: État actuel du wizard

### Question
Quel est l'état actuel de la configuration de langue dans `001-pelican-synology` ?

### Résultat

Le fichier `specs/001-pelican-synology/contracts/wizard-install.json` contient :

```json
{
  "id": "wizard_locale",
  "type": "select",
  "label": "Langue de l'interface",
  "description": "Langue par défaut du Panel (modifiable ensuite)",
  "default": "fr",  // ← Déjà présent !
  "options": [
    {"value": "fr", "label": "Français"},
    {"value": "en", "label": "English"},
    // ... 8 autres langues
  ]
}
```

**Observation**: Le français est déjà la valeur par défaut (`"default": "fr"`).

**Modification requise**: Réduire `options` de 10 langues à 2 (fr, en).

---

## Décisions Finales

| Aspect | Décision | Implémentation |
|--------|----------|----------------|
| Langue par défaut | Français (`fr`) | `"default": "fr"` (déjà en place) |
| Langues disponibles | Français et Anglais | Réduire `options` à 2 entrées |
| Labels wizard | En français | `"Langue de l'interface"` |
| Variable env | `APP_LOCALE` | Mapping existant conservé |

## Fichiers à Modifier

1. **`specs/001-pelican-synology/contracts/wizard-install.json`**
   - Réduire options de 10 à 2 langues

2. **`spk/pelican/src/wizard/install_uifile`** (quand créé)
   - Transposer le JSON vers le format DSM natif

3. **`specs/001-pelican-synology/quickstart.md`**
   - Mettre à jour la documentation

## Sources

- [Pelican Crowdin](https://crowdin.com/project/pelican-dev)
- [Pelican Blog - Translations](https://pelican.dev/blog/translations-begin/)
- [Synology Developer Guide](https://help.synology.com/developer-guide/)
- Projet Pterodactyl: `/home/gilles/ProjetSPK/Pterodactyl/`
