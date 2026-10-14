# Changelog

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Le numéro de version est celui de `$script:Version` dans `src/GreaseweazleGUI.ps1` ; chaque release GitHub porte le tag `vX.Y` correspondant.

## [Non publié]

- Releases v11.3 à v11.7 : exécutable remplacé le 14/10/2026 par une version recompilée depuis le tag et signée avec le certificat du projet. La CI, sans secrets de signature, y avait publié un exécutable non signé.
- README : signature auto-signée décrite sans surestimer sa portée, accès aux secrets de signature du dépôt précisé, commande d'export du PFX indépendante du répertoire courant, étape de remplacement de l'exécutable signé dans la procédure de publication, durée du test fin, garde-fou du contrôle à partir de 20 pistes, option TG43, conséquences de l'échec de compilation des helpers C#, contenu du fichier de configuration et des fichiers temporaires, mention du moteur PS2EXE (Microsoft Limited Public License 1.1) embarqué dans l'exécutable.

## [11.8] - 2026-10-14

- Écriture lente : case de l'onglet Écriture qui écrit toutes les pistes de la tête 0 puis toutes celles de la tête 1, en deux commandes `gw write`, chacune avec sa précompensation (champ « Précomp. tête 1 »). Champ Pistes respecté, `hswap` compris ; sans `h=`, faces lues dans l'image (IPF, HFE, ADF), refus pour les autres images si « Effacer les pistes vides » est coché, pour ne pas effacer la tête 1 d'un format simple face ; contrôle après écriture et réécritures des pistes faibles tête par tête ; tête 1 non lancée si la tête 0 échoue. Calibration par tête quand la case est cochée : mesures analysées face par face, une courbe et une vérification par tête, courbes enregistrées par famille et appliquées par le profil Auto en écriture lente tant qu'aucune calibration commune plus récente ne les remplace, fenêtre « Courbe » à deux courbes. Une face non écrite par gw est rejetée au lieu de produire une courbe sans signification. Onglet Écriture défilant quand la fenêtre est trop basse pour l'afficher en entier, ouvert en haut sur l'image.
- Calibration precomp : courbe par cylindre. Les estimations des cylindres testés, avec leur incertitude, sont ajustées par une courbe croissante, linéaire, en 1/rayon ou en 1/rayon², ou par interpolation monotone si aucune ne convient, puis évaluées pour chaque cylindre : une valeur entière par cylindre au lieu de paliers arrondis à 5 ns. Fenêtre « Courbe » avec mesures, courbe, profil et tableau des valeurs, courbe enregistrée dans la configuration. La vérification corrige la courbe localement aux cylindres hors tolérance. Un seul cylindre mesurable donne une valeur constante.
- Écriture : contrôle de toutes les pistes après écriture, en remplacement de la relecture des cylindres 0, 40 et 79. Les pistes faibles, À SURVEILLER, CRITIQUE ou illisibles, sont réécrites seules avec pré-effacement puis seules remesurées, au plus N passes, 3 par défaut, réglables de 0 à 10. Garde-fou si plus de la moitié des pistes sont faibles. État final de chaque piste et nombre de réécritures dans l'onglet Qualité & alignement.
- Onglet Qualité & alignement : métriques par piste et rendu du tableau factorisés, partagés avec le contrôle après écriture ; colonne État élargie.
- Contrôle après écriture : périmètre limité aux pistes réellement écrites par gw, relectures avec le lecteur et les options de lecteur de l'écriture, garde-fou à partir de 20 pistes, désactivation automatique pour le haute densité, le GCR, les secteurs durs et le 8 pouces, verdict exploitant les remesures déjà faites si gw échoue en cours de passe.
- Échec du lancement de gw : la séquence en cours, écriture contrôlée, calibration ou comparaison, est abandonnée. Auparavant, la commande gw suivante, même sans rapport, reprenait ses étapes, écritures comprises.
- Opération incomplète : pour une écriture, détectée par l'absence de la ligne de bilan que gw imprime toujours en fin d'écriture. Plus de fausse alerte pour une image de moins de 82 pistes.
- Libellés de piste remappés par gw, `T1.0 -> Drive 2.0`, reconnus par la progression, les retries et le contrôle.
- Images HFE : débit lu à l'offset 12 de l'en-tête au lieu de 24. Toute image HFE était jusqu'ici prise pour une image à cellule courte, ce qui faussait le profil de précompensation Auto.
- Journal : lignes de synthèse du contrôle en couleur neutre. Arrêter agit aussi entre deux commandes gw. La mesure continue ne démarre plus de cycle pendant une séquence.
- Calibration precomp : nouvelle méthode de mesure. L'analyse de flux mesure directement le décalage de pic résiduel, signé, par moyennes conditionnelles au contexte (2T entre deux longs contre 2T entre deux courts, 3T entre deux courts contre 3T entre deux longs), au lieu d'un score de jitter. Trois passes de mesure à 0, 100 et 200 ns, droite par cylindre, valeur qui annule le décalage, puis passe de vérification sur le profil obtenu avec correction des cylindres hors tolérance. Quatre à cinq passes au lieu de quatorze, profil arrondi à 5 ns, résidus affichés dans le journal.

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
