# Tasks: Français comme langue par défaut

**Input**: Design documents from `/specs/002-french-default/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/
**Parent Feature**: `001-pelican-synology`

**Tests**: Non requis (modification de configuration)

**Organization**: Tasks groupées par user story pour permettre une implémentation et validation indépendantes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Peut être exécuté en parallèle (fichiers différents, pas de dépendances)
- **[Story]**: User story concernée (US1, US2, US3)
- Chemins de fichiers exacts inclus dans les descriptions

## Path Conventions

Cette feature modifie des fichiers existants dans la feature parent `001-pelican-synology` :
- `specs/001-pelican-synology/contracts/wizard-install.json` - Configuration wizard
- `specs/001-pelican-synology/quickstart.md` - Documentation
- `spk/pelican/src/wizard/install_uifile` - Wizard DSM natif (à créer ultérieurement)

---

## Phase 1: Setup (Vérification Prérequis)

**Purpose**: Vérifier que les fichiers à modifier existent et sont conformes

- [x] T001 Vérifier l'existence de specs/001-pelican-synology/contracts/wizard-install.json
- [x] T002 Vérifier que le champ wizard_locale existe avec default="fr" dans wizard-install.json
- [x] T003 Lister les options actuelles du champ wizard_locale pour confirmation

**Checkpoint**: Fichiers sources identifiés et état actuel documenté

---

## Phase 2: User Story 1 - Installation avec français par défaut (Priority: P1) 🎯 MVP

**Goal**: Français présélectionné comme langue par défaut lors de l'installation

**Independent Test**: Installer le paquet SPK et vérifier que "Français" est présélectionné dans l'assistant.

### Implementation for User Story 1

- [x] T004 [US1] Confirmer que "default": "fr" est déjà présent dans specs/001-pelican-synology/contracts/wizard-install.json
- [x] T005 [US1] Documenter la configuration actuelle dans specs/002-french-default/research.md si non fait

**Checkpoint**: US1 est satisfaite par la configuration existante (default="fr")

---

## Phase 3: User Story 2 - Choix entre Français et Anglais (Priority: P1)

**Goal**: Réduire les options de langue à Français et Anglais uniquement

**Independent Test**: Lors de l'installation, vérifier que seules 2 options sont disponibles : Français et English

### Implementation for User Story 2

- [x] T006 [US2] Modifier le champ wizard_locale dans specs/001-pelican-synology/contracts/wizard-install.json pour réduire options à 2 langues :
  ```json
  "options": [
    {"value": "fr", "label": "Français"},
    {"value": "en", "label": "English"}
  ]
  ```
- [x] T007 [US2] Vérifier que la structure JSON reste valide après modification
- [x] T008 [US2] Mettre à jour le contrat local specs/002-french-default/contracts/wizard-locale-field.json pour refléter le changement

**Checkpoint**: US2 complète - seulement 2 langues disponibles dans le wizard

---

## Phase 4: User Story 3 - Interface Pelican en français (Priority: P2)

**Goal**: S'assurer que l'interface Pelican affiche le contenu en français

**Independent Test**: Naviguer dans le Panel et vérifier que les menus, boutons et messages sont en français.

### Implementation for User Story 3

- [x] T009 [US3] Vérifier que APP_LOCALE=fr est correctement mappé dans specs/001-pelican-synology/contracts/panel.env.example
- [x] T010 [US3] Vérifier que le mapping APP_LOCALE=${wizard_locale} existe dans environment_mapping de wizard-install.json
- [x] T011 [US3] Documenter le comportement i18n de Pelican dans specs/002-french-default/quickstart.md (chaînes non traduites affichées en anglais)

**Checkpoint**: US3 validée - la configuration garantit l'interface en français

---

## Phase 5: Polish & Documentation

**Purpose**: Mise à jour de la documentation et validation finale

- [x] T012 [P] Mettre à jour specs/001-pelican-synology/quickstart.md section installation :
  - Changer "Langue : Français (ou autre)" en "Langue : Français (par défaut) ou English"
- [x] T013 [P] Ajouter une note dans specs/002-french-default/quickstart.md expliquant comment changer de langue après installation
- [x] T014 Valider la cohérence entre wizard-install.json et contracts/wizard-locale-field.json
- [x] T015 Marquer la checklist specs/002-french-default/checklists/requirements.md comme complète

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Aucune dépendance - peut commencer immédiatement
- **US1 (Phase 2)**: Dépend de Setup - vérifie l'état existant
- **US2 (Phase 3)**: Dépend de US1 - modifie le même fichier
- **US3 (Phase 4)**: Peut commencer après US2 - vérifie le pipeline complet
- **Polish (Phase 5)**: Dépend de toutes les US

### User Story Dependencies

| User Story | Dépendance | Notes |
|------------|------------|-------|
| US1 | Setup | Vérifie que default="fr" existe |
| US2 | US1 | Modifie le même fichier (options) |
| US3 | US2 | Valide le pipeline complet locale→APP_LOCALE |

### Parallel Opportunities

```bash
# Phase 1: Toutes les tâches T001-T003 peuvent être parallélisées
Task: "T001 Vérifier l'existence de wizard-install.json"
Task: "T002 Vérifier le champ wizard_locale"
Task: "T003 Lister les options actuelles"

# Phase 5: Documentation peut être parallélisée
Task: "T012 Mettre à jour quickstart.md parent"
Task: "T013 Mettre à jour quickstart.md local"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2)

1. ✅ Phase 1: Vérifier fichiers existants
2. ✅ Phase 2: Confirmer US1 (default="fr" existe déjà)
3. 🔄 Phase 3: Implémenter US2 (réduire options à 2)
4. **STOP et VALIDER**: Tester le wizard avec 2 options
5. Continuer vers US3 et Polish

### Changement Principal

La tâche critique est **T006** : modifier le fichier `wizard-install.json` pour réduire les options de 10 à 2 langues.

```json
// AVANT (10 langues)
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

// APRÈS (2 langues)
"options": [
  {"value": "fr", "label": "Français"},
  {"value": "en", "label": "English"}
]
```

---

## Notes

- Cette feature est une **modification de configuration**, pas de nouveau code
- Le fichier principal à modifier est dans la **feature parente** `001-pelican-synology`
- La propriété `"default": "fr"` existe déjà - pas besoin de l'ajouter
- Tester sur DSM 7.2+ réel ou VM pour validation finale
- Commit après chaque tâche ou groupe logique
