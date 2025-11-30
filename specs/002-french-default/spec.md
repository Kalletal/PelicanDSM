# Feature Specification: Français comme langue par défaut

**Feature Branch**: `002-french-default`
**Created**: 2025-11-29
**Status**: Draft
**Input**: User description: "Ajouter le support du français comme langue par défaut avec choix Français/Anglais"
**Parent Feature**: `001-pelican-synology`

## Vue d'ensemble

Configurer le paquet Pelican Panel SPK pour que le français soit la langue par défaut de l'interface, avec un choix simplifié Français/Anglais lors de l'installation. Cette fonctionnalité améliore l'expérience utilisateur pour le public francophone ciblé tout en gardant l'option anglais pour les utilisateurs qui le préfèrent.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Installation avec français par défaut (Priority: P1)

En tant qu'utilisateur francophone installant Pelican Panel, je veux que le français soit présélectionné comme langue par défaut pour éviter de devoir chercher dans une liste de langues.

**Why this priority**: C'est le comportement par défaut qui impacte 100% des nouvelles installations. Le public cible est francophone.

**Independent Test**: Installer le paquet SPK et vérifier que "Français" est présélectionné dans l'assistant.

**Acceptance Scenarios**:

1. **Given** un utilisateur installant le paquet SPK, **When** l'assistant d'installation affiche l'étape de configuration, **Then** "Français" est présélectionné dans le menu déroulant de langue
2. **Given** l'assistant affichant le choix de langue, **When** l'utilisateur ne modifie pas la sélection et continue, **Then** le Panel s'installe avec `APP_LOCALE=fr`

---

### User Story 2 - Choix entre Français et Anglais (Priority: P1)

En tant qu'utilisateur, je veux pouvoir choisir entre Français et Anglais lors de l'installation pour adapter l'interface à ma préférence linguistique.

**Why this priority**: Certains utilisateurs préfèrent l'anglais même dans un environnement francophone (documentation, cohérence avec tutoriels, etc.).

**Independent Test**: Lors de l'installation, sélectionner Anglais et vérifier que l'interface est en anglais après démarrage.

**Acceptance Scenarios**:

1. **Given** l'assistant d'installation, **When** l'utilisateur voit le champ de sélection de langue, **Then** exactement deux options sont disponibles : "Français" et "English"
2. **Given** l'utilisateur sélectionnant "English", **When** l'installation se termine et le Panel démarre, **Then** l'interface est affichée en anglais
3. **Given** l'utilisateur sélectionnant "Français", **When** l'installation se termine et le Panel démarre, **Then** l'interface est affichée en français

---

### User Story 3 - Interface Pelican en français (Priority: P2)

En tant qu'utilisateur francophone, je veux naviguer dans l'interface Pelican Panel entièrement en français pour comprendre facilement toutes les fonctionnalités.

**Why this priority**: Dépend de l'installation correcte avec `APP_LOCALE=fr`. C'est le bénéfice final de la fonctionnalité.

**Independent Test**: Naviguer dans le Panel et vérifier que les menus, boutons et messages sont en français.

**Acceptance Scenarios**:

1. **Given** un Panel installé avec langue française, **When** l'utilisateur accède au dashboard, **Then** les éléments de navigation (menus, boutons) sont affichés en français
2. **Given** un Panel en français, **When** l'utilisateur crée un serveur de jeu, **Then** les étapes et messages du wizard de création sont en français
3. **Given** un Panel en français, **When** une erreur se produit, **Then** le message d'erreur est affiché en français

---

### Edge Cases

- Que se passe-t-il si la traduction française est incomplète dans Pelican ? → Les chaînes non traduites s'affichent en anglais (comportement standard i18n)
- Que faire si l'utilisateur veut une autre langue après installation ? → La langue peut être changée dans les paramètres du Panel (Administration → Settings)
- Comment gérer les emails système ? → Les emails suivent la langue configurée dans APP_LOCALE

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: L'assistant d'installation DOIT présenter "Français" comme langue présélectionnée par défaut
- **FR-002**: L'assistant d'installation DOIT offrir exactement deux choix de langue : "Français" et "English"
- **FR-003**: Le système DOIT configurer `APP_LOCALE=fr` lorsque l'utilisateur choisit Français
- **FR-004**: Le système DOIT configurer `APP_LOCALE=en` lorsque l'utilisateur choisit Anglais
- **FR-005**: L'interface Pelican Panel DOIT s'afficher dans la langue sélectionnée après le premier démarrage
- **FR-006**: Les labels de l'assistant d'installation (wizard DSM) DOIVENT être affichés en français

### Key Entities

- **Configuration Langue** (wizard_locale): Paramètre collecté lors de l'installation, valeurs possibles : `fr` (défaut), `en`
- **Variable APP_LOCALE**: Variable d'environnement dans panel.env qui détermine la langue de l'interface Pelican

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% des nouvelles installations présentent "Français" comme langue présélectionnée
- **SC-002**: L'interface Pelican affiche au moins 95% de son contenu en français lorsque `APP_LOCALE=fr`
- **SC-003**: Le changement de langue est effectif dès le premier accès au Panel après installation (pas de redémarrage supplémentaire requis)
- **SC-004**: Les utilisateurs francophones peuvent compléter l'installation sans avoir à chercher "Français" dans une longue liste

## Assumptions

- Pelican Panel dispose d'un système i18n fonctionnel via Crowdin
- La traduction française de Pelican est suffisamment complète pour une utilisation quotidienne
- La variable `APP_LOCALE` de Pelican supporte les valeurs `fr` et `en`
- L'utilisateur type de ce package SPK est francophone

## Out of Scope

- Ajout d'autres langues que Français et Anglais
- Traduction du wizard DSM dans d'autres langues (uniquement Français)
- Contribution aux traductions Pelican sur Crowdin
- Détection automatique de la langue du navigateur
- Support de langues régionales (fr-CA, fr-BE, etc.)

## Dependencies

- Feature `001-pelican-synology` : Cette fonctionnalité modifie le wizard d'installation défini dans la spec parent
