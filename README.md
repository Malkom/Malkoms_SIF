# Malkoms Set Icon Filter (MSIF)

Ajoute une **liste déroulante de classe** à côté du filtre existant (« All Icons / Items / Spells »)
sur la fenêtre de **création/édition d'un set d'équipement**. Choisir une classe restreint la grille
d'icônes aux **icônes des sorts et talents de cette classe**.

## Fonctionnement

- Le filtre par classe se règle sur la fenêtre du sélecteur d'icône de set (fiche de perso →
  Gestionnaire d'équipement → créer/éditer un set → choisir une icône).
- Sélectionner une classe affiche uniquement ses icônes ; « Toutes les classes » revient à la liste
  Blizzard normale. Le filtre se réinitialise à chaque ouverture de la fenêtre.
- Les icônes proviennent d'une liste de sorts iconiques par classe, dont l'icône est résolue en jeu
  via `C_Spell.GetSpellTexture` (les identifiants invalides sont simplement ignorés).

## Installation

Copier le dossier `Malkoms_SIF` dans `World of Warcraft\_retail_\Interface\AddOns\`, puis `/reload`.

## Notes techniques

- Se greffe sur `GearManagerPopupFrame` (Blizzard) : surcharge de `GetNumIcons` / `GetIconByIndex` /
  `GetIndexOfIcon` sur l'instance et rebinding de la grille via `IconSelector:UpdateSelections()`.
- Aucune dépendance. Interface ciblée : 12.01 (120100).
- Auteur : **Malkom**.

## Limites connues

- La liste de sorts par classe est embarquée (pas exhaustive) ; on peut l'étoffer facilement.
- Récupérer dynamiquement les talents des **autres** classes n'est pas possible en jeu (nécessite un
  configID propre au joueur), d'où l'approche par liste de sorts + résolution d'icône à l'exécution.
