# Changelog

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Le numéro de version est celui de `$script:Version` dans `src/GreaseweazleGUI.ps1` ; chaque release GitHub porte le tag `vX.Y` correspondant.

## [11.7] - 2026-10-07

- Sortie de gw : les dernières lignes avant la fin du processus n'étaient pas toujours lues, ce qui masquait notamment « Command Failed: WriteProtected » sur une disquette protégée en écriture, gw se terminant alors avec le code 0. L'application attend désormais la fin des deux flux avant de conclure, affiche la durée et le nombre de lignes reçues, colore « Command Failed » en erreur, et signale une opération incomplète quand gw rend le code 0 après moins de la moitié des pistes annoncées, sans lancer le contrôle post-écriture.

## [11.6] - 2026-10-07

- Calibration precomp : barre de progression globale sur l'ensemble des passes, avec passe en cours, phase, pourcentage et temps restant estimé d'après les durées mesurées des passes précédentes.
- Build-Exe.ps1 : signature systématique de l'exe, y compris sur un poste joint à un domaine ; `-Sign:$false` reste le seul moyen de compiler sans signer. Règle du projet : tout exe livré est signé.
- Workflow : l'exe de release est signé en CI si le certificat est fourni en secrets (`CODESIGN_PFX_BASE64`, `CODESIGN_PFX_PASSWORD`), avec horodatage ; sans secrets, il reste non signé et le journal le dit.
- Exe lancé depuis un partage réseau (chemin UNC) : gw.exe était signalé présent mais son lancement échouait, le répertoire de l'application étant pris sur le répertoire courant sous sa forme qualifiée par le fournisseur PowerShell. Le répertoire est désormais celui de l'exécutable, quel que soit le répertoire courant.

## [11.5] - 2026-10-07

- Interface bilingue français / anglais : choix automatique d'après la langue d'affichage de Windows (anglais pour toute langue autre que le français), paramètre `-Language fr|en` pour forcer. Les textes français restent la référence dans le code, la table anglaise est embarquée dans le script.
- Libellés tronqués corrigés (« Images seulement », « Masquer journal », « Réindexer ») : la largeur des boutons et des cases à cocher s'ajuste au texte et à la police au démarrage.
- Coloration du journal reconnue dans les deux langues.
- Écriture : calibration automatique de la précompensation. Écrit les cylindres de test de l'image avec une même valeur de precomp par passe sur une disquette vierge, les relit en flux, note chaque cylindre d'après le jitter et l'asymétrie des intervalles, affine autour des meilleures valeurs, lisse la courbe en croissante et enregistre le profil pour la famille de l'image (standard ou long track), appliqué ensuite par le mode Auto. Test standard, un cylindre sur dix, ou test fin, tous les cylindres ; nombre de cylindres lu dans l'image.

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
