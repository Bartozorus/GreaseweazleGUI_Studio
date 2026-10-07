# Changelog

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Le numéro de version est celui de `$script:Version` dans `src/GreaseweazleGUI.ps1` ; chaque release GitHub porte le tag `vX.Y` correspondant.

## [11.4] - 2026-10-07

Aucun changement fonctionnel dans l'application. Version de maintenance de la chaîne de build.

- `Build-Exe.ps1` : lancé depuis PowerShell 7, se relance seul sous Windows PowerShell 5.1 avec `-ExecutionPolicy Bypass` (PS2EXE l'exige et sa propre relance échouait en policy Restricted).
- `Build-Exe.ps1` : supprime l'exe précédent avant compilation et échoue si PS2EXE ne produit rien, au lieu de signaler un faux succès.
- `Build-Exe.ps1` : sur un poste joint à un domaine ou à Entra ID, la signature auto-signée est ignorée sauf `-Sign` explicite.

## [11.3] - 2026-10-07

Première publication sur GitHub.

- Couverture des 13 actions de `gw` : info, read, write, convert, erase, clean, seek, delays, update, pin, reset, bandwidth, rpm.
- Onglets Bibliothèque, Écriture, Lecture, Conversion, Comparaison, Qualité & Alignement, Outils, Délais, Commande libre.
- Bibliothèque : index persistant construit dans un thread .NET, recherche instantanée en mémoire, archives ZIP parsées, ouverture des documents associés.
- Profils de précompensation (standard 2 µs / long track 1,89 µs) détectés d'après l'image (IPF, SCP, HFE).
- Textes de l'interface : accents et apostrophes rétablis dans les libellés, infobulles, journal et messages.
- Compilation en exécutable avec PS2EXE (`Build-Exe.ps1`), signature auto-signée par défaut, désactivable avec `-Sign:$false`.
- Dépôt : sources dans `src/`, sortie de build dans `dist/`, workflow GitHub Actions de release.

## Versions antérieures

Historique reconstitué depuis l'en-tête du script ; les versions 10 à 11.2 ne sont pas documentées.

- **v9** : profils de précompensation choisis automatiquement d'après l'image.
- **v8** : onglet Alignement, mesure de qualité de lecture (jitter, asymétrie, dropouts) en continu pendant le réglage du stepper.
- **v7** : onglet Comparaison, convert (référence) + read (disquette) + diff secteur.
- **v6** : fenêtre entièrement redimensionnable, recherche de la bibliothèque en arrière-plan.
