# Changelog

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Le numéro de version est celui de `$script:Version` dans `src/GreaseweazleGUI.ps1` ; chaque release GitHub porte le tag `vX.Y` correspondant.

Chaque version s'ouvre sur un résumé de ce qu'elle apporte, puis classe ses changements en Nouveautés, Améliorations et Corrections. La rubrique « À savoir pour la mise à jour » indique ce qu'il faut faire en installant la version, par exemple recalibrer un lecteur. « Pour les développeurs » regroupe la compilation, la publication et le format de configuration. Le fonctionnement détaillé est décrit dans le [wiki](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki).

## [12.8] - 2026-10-21

La restauration se fait avec un seul lecteur et reconnaît elle-même le format de la disquette d'origine, comme la « Comparaison » celui de son image de référence. En écriture lente, la calibration rapide adapte la courbe à une disquette d'une autre marque, au lieu d'exiger une calibration complète, et peut mémoriser cette forme par marque. L'onglet « Qualité & alignement » présente son résultat sur une carte, la « Bibliothèque » groupe ses résultats par jeu et sait identifier vos images avec une liste de référence, et les fenêtres de l'application sont harmonisées.

### Nouveautés

- **Format détecté à la restauration.** Dans l'onglet « Restauration », la liste « Format : » est réglée par défaut sur « Détection automatique (conseillée) ». L'application lit deux pistes de l'original et reconnaît une disquette Amiga double ou haute densité, PC ou Atari ST, qu'elle copie ensuite secteur par secteur. La ligne sous la liste affiche le format retenu ; le journal et le rapport donnent le détail.
- **Copie exacte du flux d'office.** En détection automatique, une disquette probablement protégée contre la copie, d'un format double densité inconnu, ou dont le secteur de démarrage annonce plus de cylindres que son format, est recopiée en copie exacte du flux. Une lecture secteur qui trouve des secteurs illisibles est relancée de la même façon, et la lecture incomplète est gardée dans le dossier de sauvegarde. L'étape « Vérifier la lecture » passe alors en « ! » et en donne la raison.
- **Comparaison automatique.** Dans l'onglet « Comparaison », le format « (détection automatique) » est choisi par défaut. Il est déduit de l'image de référence, puis vérifié sur deux pistes de la disquette avant la lecture complète. Une disquette d'un autre format donne aussitôt « formats différents », sans lecture complète.
- **Calibration rapide adaptative.** Avec « Test rapide : niveau et forme par disquette », la calibration rapide mesure le niveau de la disquette insérée, et aussi, en écriture lente, sa forme quand elle diffère de la calibration complète de référence. Une disquette d'une autre marque n'impose plus de calibration complète : une passe de mesure supplémentaire adapte la courbe, puis une vérification la contrôle, y compris sur deux cylindres vers le centre du disque. Avec vos disquettes habituelles, le déroulement ne change pas.
- **Mémoire par marque de disquette.** En écriture lente, l'avertissement de la calibration rapide propose le champ « Marque de la disquette insérée : », avec la dernière marque choisie par défaut. Après une courbe adaptée et vérifiée, la fenêtre « Courbe adaptée à cette disquette » propose « Mémoriser cette forme pour la marque : ». Cette forme sert ensuite de point de départ aux disquettes de la même marque ; la mesure reste faite sur la disquette insérée.
- **Nouvel essai des cylindres non convergés.** Quand quelques cylindres restent hors tolérance à la dernière vérification d'une calibration complète, ils sont corrigés puis relus automatiquement, une seule fois. Une calibration que ces seuls cylindres auraient laissée « NON CONVERGÉE » peut ainsi aboutir. L'avertissement de la calibration annonce la durée que ce nouvel essai peut ajouter.
- **Carte de résultat de la qualité.** L'onglet « Qualité & alignement » présente son résultat sur une carte : score, niveau et tendance à gauche, état du support à droite, avec des icônes. Elle affiche aussi « Aucune mesure », « MESURE EN COURS », « MESURE CONTINUE · PASSE n » ou « PÉRIMÉ » avec sa raison. Le tableau gagne des icônes d'état et de score.
- **Bibliothèque groupée par jeu.** Les résultats d'une recherche sont groupés par jeu, avec les colonnes Variante, Disq., Version, Langue, État, Format, Taille et Dossier, un tri par colonne et des badges. Les disquettes manquantes d'un jeu sont signalées. Les filtres « Format », « Langue », « Masquer les copies modifiées » et « Originaux seulement » réduisent la liste.
- **Panneau de détails de la Bibliothèque.** Il décrit l'image choisie : structure SPS d'un IPF, volume et type d'un ADF, entrées d'une archive ZIP, documents associés et vignette. Les boutons « Ouvrir » et « Ouvrir le dossier » ouvrent le document choisi ou son dossier.
- **Liste de référence.** Le bouton « Liste de référence… », sur la ligne « Racine : » de la Bibliothèque, charge une liste DAT au format Logiqx XML (TOSEC, No-Intro) ou clrmamepro. Chaque image, archives ZIP comprises, est alors dite officielle, modifiée ou inconnue, d'après sa taille et son empreinte.
- **Mesures par cylindre au journal.** Chaque calibration, rapide ou complète, note au journal ses mesures par cylindre et par passe. Elles y restent même quand le résultat est refusé.
- **Sauvegarde de la configuration.** Avant de remplacer une calibration complète existante, ou d'effacer les calibrations, l'application copie le fichier de configuration à côté de lui.

### Améliorations

- **Restauration avec un seul lecteur.** Le lecteur de la restauration est celui du bandeau. Le nouveau cadre « 2. Calibration du lecteur » résume les courbes double et haute densité que la restauration appliquera, avec un bouton « Courbe ».
- **Fenêtres de confirmation.** Les questions qui engagent une disquette ou la carte Greaseweazle s'ouvrent dans une même fenêtre : image protégée, mise à jour du firmware, effacement, démarrage de la restauration, « Écraser quand même », entre autres. Quand une disquette est en jeu, une case nomme le lecteur, et le bouton d'action ne s'active qu'une fois la case cochée. Chaque réponse est notée au journal.
- **Fenêtres de calibration harmonisées.** Les fenêtres de décision ont un bandeau illustré et des boutons à la largeur de leur texte. La fenêtre de décision garde une taille fixe. « Contrôle de surface » affiche l'état de chaque face, de la vitesse du lecteur et de la densité relue. « Calibrations d'un autre calcul » et la fenêtre « Courbe » ont un bouton « Fermer ». Ces fenêtres, comme celle de la carte « Calibrer le lecteur », s'ajustent aux petits écrans.
- **Préchauffage dans l'onglet « Écriture ».** La case « Préchauffer le lecteur avant la calibration complète » et le champ « Durée du préchauffage », de 0 à 30 minutes, rejoignent la case de l'écriture lente. La durée ne se règle plus seulement dans le fichier de configuration.
- **Mesure de la disquette avec le test rapide.** Avec « Test rapide : niveau et forme par disquette », le bouton « ÉCRIRE LA DISQUETTE » mesure la disquette avant l'écriture rapide comme avant l'écriture lente, comme le font déjà la Bibliothèque et la restauration. La case de la mesure est alors cochée et verrouillée.
- **Carte « Calibrer le lecteur ».** Ses tests portent les noms de la liste de l'onglet « Écriture ». « Une courbe par tête (écriture lente et restauration) » est cochée par défaut, et les choix de la fenêtre sont retenus au lancement de la calibration.
- **Couleurs du journal.** Chaque niveau a sa couleur : sain en vert, à surveiller et moyen en orange, critique et mauvais en rouge.
- **Icônes d'état.** Le verdict du contrôle après écriture dans l'onglet « Écriture », les étapes et le verdict de la restauration affichent une icône d'état. Les textes d'avertissement en orange sont plus contrastés.
- **Onglet « Outils » en français.** Ses libellés deviennent « Cylindre (seek) : », « Positionner », « Pistes (erase) : », « Passes : », « Durée par position (ms) : » et « Broche (pin) : ». Les boutons des onglets ont une hauteur commune, et la case « Face B flippy (--reverse) » porte le même nom dans « Écriture » et « Lecture / Dump ».
- **Refus plus cohérents.** Pendant un préchauffage ou une mesure continue de la qualité, ces actions sont désormais refusées : carte « Tester le Greaseweazle », réglage du jitter, « Effacer les calibrations », détection des lecteurs, carte « Calibrer le lecteur », restauration et comparaison.
- **Messages au journal.** Les messages affichés par l'application sont aussi notés au journal.
- **Écriture depuis une archive ZIP.** Une image altérée dans une archive ZIP est refusée à l'écriture, avant tout passage sur la disquette.

### Corrections

- **Journal.** « SUPPORT SAIN » et « CONTRÔLE APRÈS ÉCRITURE : n/n pistes saines » ne s'affichent plus en rouge.
- **Ancien résultat de qualité.** Pendant une nouvelle mesure, ou après un arrêt, une erreur ou une écriture, l'ancien résultat n'est plus présenté comme actuel : il est grisé et marqué « MESURE EN COURS » ou « PÉRIMÉ ».
- **Pistes illisibles.** Le score moyen ne les compte pas : la carte de résultat le signale désormais, avec leur nombre.
- **Verdict du contrôle après écriture.** Il disparaît de l'onglet « Écriture » dès qu'une disquette est écrite ou effacée sans contrôle.
- **Mesure du seul cylindre 0.** « Qualité & alignement » accepte désormais une mesure limitée au cylindre 0.
- **Comparaison.** Des secteurs illisibles des deux côtés ne donnent plus « IDENTIQUE » : le résultat devient « IDENTIQUE SUR LES SECTEURS LUS », avec le nombre de secteurs non comparés et leurs pistes.
- **Restauration avec un format choisi.** Si gw ignore des secteurs hors du format choisi, la restauration s'arrête avant toute écriture, au lieu de réussir avec une copie qui les perdrait.
- **Pause d'une mesure continue.** « Arrêter » est actif et « Réinitialiser » inactif pendant la pause entre deux passes.
- **« Réinitialiser ».** Le seuil de famille du profil de précompensation revient aussi à 1 950 ns.

### À savoir pour la mise à jour

- Les calculs de calibration ne changent pas : 12.6 en double densité, 12.7 en haute densité. Vos courbes sont reprises sans question, et aucune recalibration n'est nécessaire.
- La restauration à deux lecteurs n'existe plus. La restauration utilise le lecteur du bandeau et vous demande de changer de disquette entre la lecture et l'écriture.
- La restauration et la comparaison détectent le format par défaut ; vous pouvez toujours en choisir un dans la liste. La détection ajoute 5 à 12 secondes. Une disquette vierge ou un format haute densité inconnu arrêtent la restauration avant toute écriture.
- La détection ne reconnaît pas une protection par pistes longues dont tous les secteurs restent lisibles. Pour un tel original, choisissez vous-même « Copie exacte du flux (disquette protégée ou format inconnu) ». La détection des disquettes PC et Atari ST n'a pas encore été vérifiée sur une vraie disquette.
- Règle du « Test rapide », la même pour le bouton « ÉCRIRE LA DISQUETTE », la Bibliothèque et la restauration : la disquette est mesurée avant chaque écriture. Il n'y a pas de mesure quand l'image ne recouvrirait pas tout le motif de test, par exemple une image à une seule face ou un champ « Pistes : » limité.
- Sans calibration complète de référence pour ce lecteur, le « Test rapide » refuse l'écriture depuis le bouton « ÉCRIRE LA DISQUETTE » ou la Bibliothèque : rien n'est écrit ni calibré. Calibrez d'abord le lecteur sur une disquette sacrifiée, par la carte « Calibrer le lecteur » de l'Accueil. La restauration ne refuse pas : elle écrit avec la calibration existante, sans mesure, ou calibre le lecteur s'il n'en a aucune pour ce type de disquette.
- Après une calibration sur une disquette sacrifiée, l'écriture et la restauration attendent que vous remettiez la disquette, sans compte à rebours. L'avertissement de la calibration garde son délai de 120 secondes. Entrée ne lance plus rien dans les fenêtres de décision ni dans les confirmations.
- Quand la calibration rapide propose une calibration complète, celle-ci ne démarre jamais seule : cochez la case de la disquette sacrifiée, puis cliquez sur « Lancer la calibration complète ».
- Après une courbe adaptée par la calibration rapide, toutes les pistes sont contrôlées après l'écriture, même si « Contrôler toutes les pistes » est décochée. Le journal l'indique. Les réglages de cette adaptation sont provisoires : ils viennent de simulations établies sur les mesures d'un seul lecteur.
- Le nouvel essai des cylindres non convergés n'écrit jamais une piste plus de fois que l'avertissement ne l'annonce. Une erreur de gw pendant ce nouvel essai garde le résultat de la vérification précédente, mais l'écriture prévue est annulée : relancez-la.
- La « Comparaison » applique désormais à ses lectures les options du lecteur de l'onglet « Écriture » : « Face B flippy (--reverse) », « Densel : » et « Fake index : ». Vérifiez-les avant de comparer. Pour un ADF de 81 à 83 cylindres, les cylindres au-delà du format sont signalés en réserve, sans être comparés.
- Le nettoyage de l'onglet « Outils » fait par défaut 3 passes de 500 ms par position. Une configuration restée à l'ancien défaut, 3 × 100 ms, passe à 3 × 500 ms, avec une ligne au journal ; toute autre valeur est gardée. Dans la fenêtre « Nettoyage des têtes », le lecteur choisi devient celui du bandeau au lancement du nettoyage.
- Les sauvegardes de la configuration s'appellent `GreaseweazleGUI.json.ref-<famille>-<date>.bak` ; les 10 plus récentes sont gardées. Pour revenir aux calibrations d'une sauvegarde, fermez l'application, copiez-la sur `GreaseweazleGUI.json`, puis relancez.
- La recherche de la Bibliothèque porte sur le nom des fichiers ; cochez « Aussi dans les dossiers » pour chercher aussi dans les dossiers. La ponctuation compte : « king quest » trouve KingsQuest et King's Quest, mais « kings » ne trouve pas King's.
- Aucune liste de référence n'est fournie ni téléchargée : importez la vôtre par « Liste de référence… ». Sans liste, aucune image n'est dite officielle. La première identification d'un dossier prend du temps ; les empreintes sont ensuite reprises de leur cache.
- Le préréglage d'une écriture depuis la Bibliothèque ne vaut que pour cette écriture : l'onglet « Écriture » retrouve ensuite ses réglages, et le préréglage n'est pas enregistré.
- Pendant une mesure continue de la qualité, « Réinitialiser » est inactif. Après un changement des seuils de jitter, le résultat affiché est déclaré « PÉRIMÉ » : relancez la mesure.
- La configuration n'enregistre plus les lecteurs et le format de la restauration, ni le format de la comparaison, sous leurs anciennes clés. Une version 12.7 qui la relit repart du format `amiga.amigados` dans ces deux onglets, et du lecteur A pour la restauration. Elle ignore aussi les courbes adaptées et la mémoire par marque, qui disparaissent à son prochain enregistrement.

### Pour les développeurs

- La source est découpée en 42 modules, `src/modules/NNN-nom.ps1`. `tools/Assemble-Source.ps1` les assemble dans `src/GreaseweazleGUI.ps1`, qui ne se modifie plus à la main ; `src/GreaseweazleGUI.map.json` et `tools/Resolve-ModuleLine.ps1` relient une ligne du script à son module. `Build-Exe.ps1` assemble d'abord, et s'arrête si le fichier assemblé change. Voir `src/modules/README.md`.
- Réglages à source unique : table `$script:SettingDefs` (`040-etat-formats.ps1`), lue et écrite par `Get-Setting`, `Set-Setting`, `Import-Settings` et `Export-Settings`.
- Configuration, nouvelles clés : `write.calibWarmup`, `write.precompProfileCode`, `write.levelBrand`, `write.levelBrands`, `align.presetCode`, `ui.homeCalHeads`, `ui.homeCalCyls`, `restore.formatChoice` et `compare.formatChoice` (`auto` par défaut), `library.dat`. `write.precompProfile` et `align.preset` gardent le texte traduit, relu par la 12.7.
- Configuration, `write.levelShifts` : champs `s`, `b`, `model`, `mode`, `brand`, `ctl` et `k` ajoutés. `levelAlgo` vaut `lvl2` sur un enregistrement adapté seulement ; `write.levelAlgo` reste `lvl1`.
- Configuration, clés retirées au premier enregistrement : `restore.source`, `restore.target`, `restore.format` et `compare.format`.
- Bibliothèque : cache des empreintes `hash-<MD5 de la racine>.tsv`, à côté de l'index. CRC-32 lu dans le répertoire central d'une archive ZIP, ou calculé par `System.IO.Compression` sur une archive en mémoire : aucun calcul en PowerShell.
- Nouvelle fenêtre `frmConfirm` (`Show-AppConfirm`) ; la fenêtre Courbe s'appelle `frmCurve`. Aucun `AcceptButton`. Toutes les boîtes de message passent par `Show-AppMessage`, et le test « opération en cours » par `Get-AppBusy`.
- Aucun bloc C# modifié ; `CalibCalc` reste 12.6 et `CalibCalcHd` 12.7.

## [12.7] - 2026-10-19

Les disquettes haute densité MFM à 300 tr/min (Amiga HD, PC 1,44 Mo et une dizaine d'autres formats) se calibrent désormais. Avant chaque écriture lente, l'application mesure la disquette à écrire : son niveau de précompensation et l'état de sa surface. Une calibration complète contrôle aussi sa disquette et la vitesse du lecteur, et peut être refaite sur une autre disquette pour comparer les deux courbes.

### Nouveautés

- **Calibration haute densité.** La carte « Calibrer le lecteur » de l'Accueil et le bouton « Calibrer » de l'onglet « Écriture » calibrent maintenant les types haute densité MFM à 300 tr/min : Amiga HD, PC 1,44 Mo, formats 1,6 Mo et 1,68 Mo, entre autres. Leur courbe, « Haute densité 1 us », commune ou par tête, s'ajoute aux courbes double densité sans les modifier. En profil « Auto (selon image) », une image haute densité reçoit ensuite cette courbe.
- **Mesure de la disquette avant l'écriture lente.** Avant d'écrire l'image, l'application mesure sur la disquette insérée son niveau de précompensation propre et l'état de sa surface. Elle reprend pour cela la forme de la dernière calibration complète en test fin du lecteur, puis écrit l'image avec ce niveau. La case « Mesurer la disquette avant l'écriture lente », sous « ÉCRIRE LA DISQUETTE », est cochée par défaut ; elle vaut aussi pour la « Bibliothèque » et la restauration.
- **Disquette à écrire défectueuse.** Si la mesure trouve la disquette nettement défectueuse, la fenêtre « Disquette à écrire défectueuse » s'ouvre avant l'écriture de l'image. Elle propose « Écrire quand même » ou « Arrêter », sans compte à rebours. Un lecteur qui ne tourne pas à la vitesse du type de disquette est désigné comme tel.
- **Contrôle de surface de la disquette de calibration.** La première passe d'une calibration complète écrit déjà le motif de test, puis le relit. L'application y repère désormais les pertes de signal, les durées anormales et les lectures qui changent d'un tour à l'autre, sans écriture supplémentaire. Si la disquette paraît très défectueuse, la fenêtre « Contrôle de surface » propose « Changer de disquette », « Continuer » ou « Arrêter ». Elle n'a pas de compte à rebours. Un défaut moins marqué apparaît comme une réserve à la fin de la calibration.
- **Contrôle de la vitesse du lecteur.** Cette même passe vérifie la durée d'un tour et la densité relue. Un lecteur qui ne tourne pas à la vitesse du type choisi, par exemple un lecteur 5,25 pouces haute densité à 360 tr/min pour un format à 300 tr/min, ouvre aussi la fenêtre. Elle désigne alors le lecteur, et ne propose pas de changer de disquette.
- **Changer de disquette en cours de calibration.** Après avoir inséré une autre disquette et coché « J'ai inséré une autre disquette », la calibration reprend à la première passe avec les mêmes réglages, sans nouvel avertissement. Avant une écriture depuis la « Bibliothèque », une seconde case déclare une disquette sacrifiée : la disquette à écrire vous est alors redemandée à la fin.
- **« Refaire sur une autre disquette ».** Ce bouton apparaît dans la fenêtre de décision quand une réserve peut venir du support : calibration non convergée, plafond atteint, précompensation nulle encore excessive, vérifications contradictoires, défaut du contrôle de surface. La courbe obtenue est mise de côté et la calibration précédente rétablie. La même calibration est refaite sur une autre disquette sacrifiée, après une confirmation sans compte à rebours.
- **Comparaison des deux calibrations.** Une fenêtre superpose les courbes A et B et les compare face par face : niveau, forme, zones où elles divergent. Vous conservez la courbe A, la courbe B, ou aucune des deux ; fermer la fenêtre conserve B. Les mesures des deux disquettes ne sont jamais mélangées. Quand c'est possible, la fenêtre conseille une courbe et dit pourquoi.
- **Progression sur l'Accueil.** Pendant une calibration ou le préchauffage d'une écriture lente, une zone remplace le titre de l'Accueil : ce qui est en cours, la barre de progression et son détail. Après une calibration lancée depuis l'Accueil, elle affiche le bilan, avec « Afficher la courbe » et « Fermer ». Quand le journal est masqué, le lien « Afficher le journal » l'affiche au bilan ; pendant les écritures et relectures, le bouton « Afficher journal » de la barre reste disponible.

### Améliorations

- **Cylindre mesuré sur une seule face.** Avec une courbe commune, quand une face d'un cylindre ne peut pas être relue, la mesure de l'autre face est utilisée seule. Le journal le signale désormais sur la ligne de la passe et dans le bilan, avec le conseil de recalibrer en écriture lente ou sur une autre disquette.
- **Progression de la calibration.** Pendant la fenêtre « Contrôle de surface », la barre et la carte « Calibrer le lecteur » indiquent « Calibration en attente » au lieu d'avancer. Pendant une calibration refaite, le libellé commence par « Calibration B ».
- **Effacer les calibrations.** La confirmation rappelle qu'en haute densité l'écriture reprend le profil d'origine, sans calibration automatique.

### À savoir pour la mise à jour

- Le calcul de calibration double densité reste en version 12.6 : vos courbes sont reprises sans question. La haute densité a son propre calcul, en version 12.7 : un futur réglage de la haute densité ne touchera pas vos courbes double densité.
- La calibration haute densité est nouvelle. Ses réglages sont provisoires et seront ajustés d'après les premières mesures sur matériel réel. Il faut une disquette haute densité sacrifiée, avec son trou de densité, et un lecteur haute densité.
- L'écriture d'une image haute densité ne calibre jamais automatiquement, et la calibration rapide n'existe pas encore en haute densité. Sans courbe, l'image reçoit le profil d'origine 0=70:40=100:65=140, que recevaient déjà les ADF et IMG haute densité. Les HFE et IPF haute densité, qui recevaient le profil long track, reçoivent désormais celui-ci.
- Le contrôle de toutes les pistes après l'écriture reste impossible en haute densité.
- Restent non calibrables : la haute densité à 360 tr/min (PC 1,2 Mo, entre autres), pas encore validée sur un lecteur réel, la très haute densité (2,88 Mo), le FM, le GCR, les codages propres et la double densité à 360 tr/min. La fenêtre de la carte en donne la raison.
- Le contrôle de surface repère les pertes de signal. Une zone du support qui enregistre autrement, sans perdre de signal, ne se voit qu'en comparant deux disquettes. Ses critères sont provisoires. En test standard, seuls les cylindres de test sont contrôlés et comparés.
- « Refaire sur une autre disquette » n'est proposé ni pendant une restauration, ni après une calibration rapide. Avant une écriture depuis la « Bibliothèque », il annule l'écriture : relancez-la une fois la courbe choisie.
- Pendant la calibration refaite, c'est la calibration précédente qui est enregistrée : si vous fermez l'application avant la fin, la première courbe est perdue. La comparaison n'est conservée que dans le journal.
- Chaque écriture lente dure environ 1 minute de plus. Elle écrit d'abord le motif de test au plus 3 fois sur quelques cylindres de la disquette à écrire, que l'image recouvre ensuite. Décochez « Mesurer la disquette avant l'écriture lente » pour retrouver le comportement de la 12.6.
- La mesure n'est jamais faite quand l'image ne recouvrirait pas ces cylindres, par exemple une image à une seule face ou un champ « Pistes » limité. Elle ne l'est pas non plus en haute densité. Le journal en donne chaque fois la raison.
- Sans calibration complète en test fin du lecteur, l'écriture se fait sans mesure, avec la courbe du lecteur ou le profil d'origine. Avec « Test rapide : niveau par disquette » dans la liste « Calibration précomp », l'écriture se comporte comme en 12.6 et la case est inactive.
- La fenêtre « Disquette à écrire défectueuse » n'a pas de compte à rebours : une écriture lente lancée sans surveillance peut l'attendre.
- Une version antérieure de l'application qui relit cette configuration ignore les courbes haute densité et le réglage de la mesure, et les efface à son prochain enregistrement.

### Pour les développeurs

- Configuration, section `write` : clés `precompCurves.hd`, `precompCurves.hd_h0` et `precompCurves.hd_h1`, écrites seulement quand la courbe existe ; leur `calc` vaut `12.7`. `precompMaxNs` reste la borne double densité ; la haute densité en prend la moitié.
- Configuration, section `write` : clé `levelBeforeWrite` (booléen, `true` par défaut), case `chkWLevel` de la mesure avant l'écriture lente.
- Nouvelles fenêtres `frmCalibSurface` (contrôle de surface, et disquette à écrire défectueuse pendant la mesure) et `frmCalibRedo` (confirmation de la calibration B). Dans `frmCalibReview`, nouveaux boutons `btnRevRedo` et, en comparaison, `btnRevKeepA`. `Show-TimedConfirm` gagne `-Seconds` et `-NeedCheck`.
- Les boîtes de message du code nouveau ou modifié passent par `Show-AppMessage`, qui écrit aussi le message au journal.
- Aucun bloc C# modifié ; `CalibCalc` reste 12.6, `CalibCalcHd` vaut 12.7.

## [12.6] - 2026-10-17

L'Accueil gagne deux cartes : « Calibrer le lecteur », pour tous les types de disquette, et « Nettoyer les têtes du lecteur », avec une procédure illustrée. Le lecteur est préchauffé avant une calibration complète et avant une écriture lente. Une calibration n'est plus déclarée « NON CONVERGÉE » quand ses deux vérifications se contredisent sur une zone.

### Nouveautés

- **Carte « Calibrer le lecteur ».** Elle remplace la carte « Courbe de calibration » de l'Accueil. Sa fenêtre liste, par groupe, tous les types de disquette connus de gw 1.23, et indique pour chacun s'il est calibrable ou pourquoi il ne l'est pas. Pour le type choisi, elle affiche l'état des courbes et propose « Afficher la courbe », ainsi qu'une calibration complète (test standard ou test fin) ou rapide. La calibration rapide n'est proposée que si une calibration complète de référence convient ; sinon, la fenêtre en donne la raison. Aucune image n'est nécessaire : l'application génère un motif de test à la densité du type et l'écrit sur une disquette sacrifiée. La carte affiche ensuite la progression, puis le bilan.
- **Carte « Nettoyer les têtes du lecteur ».** Sa fenêtre présente la procédure en cinq vignettes. Elle permet de choisir le lecteur, sa course (80 ou 40 pistes), une disquette humide ou sèche et la durée. Le nettoyage ne démarre qu'une fois cochée la case « J'ai inséré une disquette de nettoyage dans le lecteur … », décochée à chaque changement de lecteur. Un bandeau rouge rappelle de ne jamais lancer le nettoyage avec une vraie disquette, qui risquerait d'être rayée et de perdre ses données. Le bouton « NETTOYER » de l'onglet « Outils » ouvre la même fenêtre.
- **Préchauffage du lecteur.** Avant une calibration complète ou une écriture lente, l'application relit la disquette insérée sans rien y écrire, pendant 5 minutes au plus. Le lecteur atteint ainsi sa température de fonctionnement, qui modifie nettement le besoin de précompensation. Le préchauffage est réduit, ou sauté, si le lecteur vient de travailler. Quand une calibration rapide précède l'écriture, il a lieu avant la mesure du niveau. Le bouton « Passer le préchauffage » de la barre le termine après la lecture en cours, et « Arrêter » l'interrompt.
- **Préchauffage désactivable.** La case « Préchauffer le lecteur avant l'écriture lente » de l'onglet « Écriture » le désactive pour l'écriture. La fenêtre de la carte « Calibrer le lecteur » a sa propre case pour la calibration. La durée se règle dans le fichier de configuration, de 0 (désactivé) à 30 minutes.

### Améliorations

- **Vérifications contradictoires.** Sur certaines zones, la première vérification peut demander moins de précompensation et la seconde, après correction, davantage. Les deux placent alors le besoin entre les deux valeurs écrites. La courbe y prend désormais la médiane des passes de mesure et des deux vérifications, sans dépasser les cylindres vérifiés voisins. Le journal et la fenêtre « Courbe » signalent ces cylindres comme « zone non reproductible », qui ne compte plus comme non convergée.
- **Fenêtre de décision sur une zone non reproductible.** Elle s'ouvre quand les deux vérifications s'écartent de plus de 12 ns, ou quand la dérive du lecteur n'a pas pu être mesurée. Les cylindres sur lesquels les deux vérifications s'accordent restent jugés normalement, et une correction sans effet, ou plus faible que prévu, reste une non-convergence.
- **Préchauffage sans disquette lisible.** Après deux lectures de suite sans aboutir (Greaseweazle, lecteur ou disquette absent), le préchauffage s'arrête et l'opération commence. Sa première écriture signale le défaut s'il persiste. Pour une écriture lente, les lectures reprennent les options d'index et de densité de l'écriture, par exemple pour une disquette à secteurs durs.
- **Durée et progression.** L'avertissement d'une calibration compte le préchauffage dans la durée estimée. Pendant une calibration ou un préchauffage, le libellé commence par le pourcentage et le temps restant, lisibles à la taille minimale de la fenêtre.
- **Formats non calibrables.** Avant une écriture, un format choisi explicitement et non calibrable (FM, GCR, secteurs durs, 360 tr/min…) n'est plus calibré automatiquement. L'écriture garde le profil courant, et le journal l'indique. Le bouton « Calibrer » refuse ces formats et en donne la raison.
- **Images IMG et ST.** La calibration prend le nombre de cylindres du format choisi, par exemple 40 pour un format 5,25 pouces 360 Ko, au lieu de 80 par défaut, et en mesure au moins 35.
- **Courbe plus courte que l'image.** Avant une écriture, une courbe calibrée sur nettement moins de cylindres que l'image est refaite sur les cylindres de l'image ; l'avertissement le signale. En « Test rapide », une telle référence mène à une calibration complète. Une restauration ne recalibre pas, mais signale la réserve à l'étape « Calibrer le lecteur si nécessaire ».
- **Contrôle après écriture.** Il n'est plus proposé pour les formats FM, ni pour ceux dont la piste 0 est en FM : ses critères MFM les jugeraient à tort.
- **Accueil sans défilement horizontal.** La fenêtre principale fait au moins 816 pixels de large. Une largeur enregistrée plus étroite est élargie au démarrage.

### À savoir pour la mise à jour

- Le calcul de calibration passe à 12.6, car les valeurs de la courbe changent sur les zones non reproductibles. Au premier démarrage, la fenêtre « Calibrations d'un autre calcul » propose vos courbes 12.4 : « Recalibrer (conseillé) » ou « Conserver ces courbes ». La recalibration commence par le préchauffage ; prévoyez une disquette sacrifiée.
- Une calibration complète et une écriture lente durent jusqu'à 5 minutes de plus, sauf si le lecteur vient de travailler. Pendant une restauration avec un seul lecteur, la lecture de l'original chauffe déjà le lecteur : le préchauffage de la destination est en général sauté.
- Une disquette protégée en écriture n'est signalée qu'à la première écriture, après le préchauffage.
- Il reste une seule courbe par famille, commune à tous les lecteurs. Calibrer avec un autre lecteur, ou sur un autre nombre de cylindres, remplace cette courbe ; la fenêtre et l'avertissement le signalent.
- Les types simple face sont calibrés sur les deux faces : il faut un lecteur double face. Les formats Atari à 260 et 261 kbit/s sont calibrés comme la double densité standard.
- La fenêtre de la carte « Calibrer le lecteur » demande un écran d'au moins 1 024 pixels de large.

### Pour les développeurs

- Configuration, section `write` : `calWarmupMinutes` (0 à 30, 5 par défaut) et `slowWarmup` (préchauffage de l'écriture lente, activé par défaut). Chaque courbe enregistre sa zone non reproductible dans `contra`.
- Configuration, section `ui` : `homeCalFormat` (dernier type choisi dans la carte « Calibrer le lecteur »).
- Configuration, section `tools` : `cleanWet`, `cleanCyls` et `cleanPreset` (derniers choix de la fenêtre de nettoyage).
- Fenêtre principale : largeur minimale portée de 800 à 816 pixels (`window.width`).

## [12.5] - 2026-10-17

Une calibration n'est plus déclarée « NON CONVERGÉE » parce que le lecteur dérive légèrement d'une passe de vérification à l'autre. Les cylindres qui ne se reproduisent pas sont signalés à part. La limite de précompensation calibrée devient réglable.

### Améliorations

- **Dérive du lecteur entre deux vérifications.** Quand la première vérification corrige la courbe, la seconde réécrit et relit aussi des cylindres non modifiés, appelés témoins : jusqu'à 10 par courbe calibrée (par tête en écriture lente). Leur écart d'une passe à l'autre mesure la dérive du lecteur, par exemple due à la température ou au contact de la tête. Les cylindres corrigés sont jugés sans cette dérive ; les témoins, inchangés, restent jugés sur leur première mesure. Le journal donne la dérive et son incertitude. Un vrai écart régional reste signalé.
- **Cylindres non reproductibles.** Un cylindre isolé dont la mesure part à l'inverse de la correction, ou bien au-delà, est listé à part dans le journal, avec ses deux valeurs. Il ne compte pas pour la convergence. Une correction sans effet, ou plus faible que prévu, reste une non-convergence.
- **Dérive forte signalée.** Une dérive de plus de 8 ns de décalage entre les deux vérifications ouvre la fenêtre de décision : le lecteur ou le support est peut-être instable.
- **Limite de précompensation réglable.** La valeur maximale d'une courbe calibrée, 400 ns par défaut, se règle dans le fichier de configuration, de 300 à 470 ns. Au-delà, la précompensation déplacerait une transition d'un quart de cellule sur une image long track.

### À savoir pour la mise à jour

- Le calcul de calibration reste en version 12.4 : vos courbes sont reprises sans question. Une courbe déjà marquée « NON CONVERGÉE » garde ce verdict ; la prochaine calibration bénéficie des nouvelles règles.
- La seconde vérification réécrit et relit quelques cylindres de plus. Ils sont choisis pour ne pas dépasser le nombre maximal d'écritures par piste que la calibration atteint de toute façon, sauf s'il en manque.
- Si vous abaissez la limite sous celle d'une courbe existante, la calibration rapide ramène ses valeurs à la nouvelle limite et le signale dans le journal.

### Pour les développeurs

- Configuration : champ `precompMaxNs` de la section `write` (300 à 470, 400 par défaut). Chaque courbe enregistre la borne de son calcul dans `maxNs`.

## [12.4] - 2026-10-16

La précompensation calibrée peut désormais atteindre 400 ns, pour les lecteurs qui demandent plus de 300 ns. Une calibration en test fin n'est plus déclarée « NON CONVERGÉE » pour quelques cylindres isolés. Le wiki est réécrit.

### Améliorations

- **Précompensation calibrée jusqu'à 400 ns.** Les passes de mesure restent plafonnées à 300 ns. Au-delà, la valeur d'un cylindre est déduite de ses propres mesures. Si cette déduction est incertaine, elle est combinée avec la tendance de la courbe. La valeur obtenue est ensuite vérifiée sur la disquette, comme les autres. La courbe décalée par la calibration rapide peut, elle aussi, atteindre 400 ns.
- **Plafond de 400 ns.** Au-delà de 400 ns, la courbe reste plafonnée et la fenêtre de décision s'ouvre, comme avant. La fenêtre « Courbe » garde une graduation de 50 ns jusqu'à 400 ns.
- **Besoin au-delà de 300 ns signalé.** Le journal liste ces cylindres et rappelle qu'une disquette sacrifiée fatiguée surestime ce besoin. Il prévient aussi quand ce besoin a nettement augmenté depuis la calibration précédente du même lecteur, restée sous 300 ns.
- **Haute densité en profil « Auto (selon image) ».** Une image haute densité reçoit désormais le profil d'origine de sa famille, jamais un profil calibré. Calibré en double densité, celui-ci peut atteindre 400 ns, bien trop pour une cellule de 1 µs. L'onglet « Écriture » et le journal l'indiquent.
- **Wiki réécrit.** Les pages sont resserrées de près de moitié. Le fonctionnement interne de la calibration passe dans la nouvelle page [Calibration : détails techniques](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Calibration-d%C3%A9tails-techniques).

### Corrections

- **Calibration en test fin presque toujours « NON CONVERGÉE ».** Chaque cylindre vérifié devait rester dans une tolérance de 4 ns, que quelques cylindres isolés dépassent presque toujours. La vérification tient désormais compte du bruit de mesure de la disquette. Seuls les écarts étendus à plusieurs cylindres, ou très forts, sont corrigés et comptent pour la convergence. Les autres sont listés dans le journal sous « Écarts locaux non retenus ». Le test standard garde la règle d'avant pour ses cylindres vérifiés isolés.

### À savoir pour la mise à jour

- Le calcul de calibration passe à 12.4. Au premier démarrage, la fenêtre « Calibrations d'un autre calcul » propose les courbes faites ou conservées avec la 12.3. La configuration est d'abord copiée, par exemple dans `GreaseweazleGUI.json.calib-v12.3-avant-v12.4.bak`.
- Choisissez « Recalibrer (conseillé) » pour bénéficier du nouveau critère de convergence et du plafond de 400 ns. La prochaine écriture qui en a besoin recalibre alors le lecteur : prévoyez une disquette sacrifiée.
- Une courbe conservée garde son verdict, « NON CONVERGÉE » compris, et son plafond de 300 ns. La fenêtre « Calibrations d'un autre calcul » et la restauration signalent une courbe qui atteint ce plafond. La calibration rapide mesure toutefois cette fin de courbe sur un cylindre témoin, et peut la porter jusqu'à 400 ns.

### Pour les développeurs

- Configuration : champ `maxNs` des courbes de `precompCurves`, borne de leurs valeurs (300 ns s'il est absent). `write.calibCalc` vaut 12.4.
- Workflow de release : la section du CHANGELOG est publiée telle quelle, sans titre ajouté.

## [12.3] - 2026-10-16

Une nouvelle calibration rapide ne mesure que le niveau propre à chaque disquette. Une calibration douteuse vous est désormais soumise, et la calibration long track ne reste plus bloquée sur un palier. Les calibrations sont reprises d'une version à l'autre tant que leur calcul ne change pas.

### Nouveautés

- **Calibration rapide.** Nouveau choix « Test rapide : niveau par disquette » dans la liste « Calibration précomp : » de l'onglet « Écriture ». La forme de la courbe de précompensation tient au lecteur, son niveau au support. L'application reprend donc la dernière calibration complète du lecteur (test standard ou test fin), appelée référence, et mesure seulement le niveau sur la disquette à écrire elle-même. Seuls 4 à 9 cylindres par tête sont écrits, et chaque piste concernée reçoit au plus trois écritures du motif de test.
- **Quand elle s'applique.** Avec ce choix, une calibration rapide précède chaque « Écriture rapide » ou « Écriture lente » de l'onglet « Bibliothèque ». En restauration lancée avec ce choix, le niveau est mesuré pour chaque tête, sans refaire la calibration existante du lecteur. Le bouton « Calibrer » mesure le niveau de la disquette insérée sans écrire d'image.
- **Un profil par disquette.** Le profil obtenu, placé dans les champs de précompensation, ne vaut que pour la disquette mesurée. Il est remplacé par celui de la référence au changement d'image, ou dès la fin d'une écriture depuis l'onglet « Bibliothèque ». Après « Calibrer », il reste en place pour « ÉCRIRE LA DISQUETTE ».
- **Sans référence utilisable.** Si le lecteur n'a pas de calibration complète utilisable comme référence, une calibration complète en test fin est faite d'abord et devient la référence. Si elle a été faite sur une disquette sacrifiée, l'application redemande ensuite la disquette à écrire : « Mesurer le niveau et écrire » mesure son niveau, puis écrit l'image. Une image dont le nombre de cylindres ou la densité s'écarte trop de la référence est écrite avec la courbe du lecteur, sans mesure du niveau.
- **Contrôle de la forme et suivi.** L'application vérifie que la disquette suit la forme de la référence. Un écart sur un seul cylindre est écarté du niveau, et une marche déplacée peut signaler un autre lecteur sous la même lettre. D'après les niveaux déjà mesurés avec la même référence, le journal signale une disquette probablement fatiguée, ou une référence mesurée sur une disquette atypique. Voir [Calibration : détails techniques](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Calibration-d%C3%A9tails-techniques).
- **Fenêtre « Courbe ».** Elle montre la courbe décalée de la dernière disquette, ses mesures et, le cas échéant, la mention « FORME NON CONFORME ». Le tableau détaille la dernière calibration rapide.
- **Fenêtre de décision.** Une calibration douteuse ouvre une fenêtre qui montre la courbe et les raisons : non convergée, limite de 0 ou 300 ns atteinte, courbe éloignée des mesures, forme non conforme ou niveau incertain. Avant une écriture, vous choisissez « Écrire l'image » ou « Arrêter ». Après « Calibrer », les boutons sont « Conserver la courbe » et « Abandonner la courbe » en calibration complète, « Conserver le niveau » et « Abandonner le niveau » en calibration rapide. Arrêter ou abandonner rétablit l'état d'avant la calibration. Échap ou la croix vaut « Arrêter » avant une écriture, et conserve le résultat sinon. En calibration rapide, le bouton « Calibration complète » remesure la courbe du lecteur, sauf en restauration et après « Mesurer le niveau et écrire ».

### Améliorations

- **Calibrations reprises d'une version à l'autre.** Chaque courbe enregistre la version du calcul de calibration qui l'a produite, ici 12.3. Ce calcul ne change qu'avec la méthode : les versions suivantes reprennent donc les courbes, au lieu de les abandonner à chaque nouvelle version comme depuis la 12.1.
- **Fenêtre « Calibrations d'un autre calcul ».** Au démarrage, les courbes d'un autre calcul sont mises de côté, sans être utilisées, et listées dans cette fenêtre. « Recalibrer (conseillé) », le choix par défaut, les abandonne avec leurs profils et leurs niveaux. « Conserver ces courbes » les garde telles quelles, sans nouvelle question tant que le calcul ne change pas. La fenêtre « Courbe », le journal et la restauration rappellent alors leur calcul. Fermer la fenêtre reporte la décision au démarrage suivant. « Effacer les calibrations » efface aussi les courbes en attente.
- **Calibration complète et référence.** Le journal compare la forme d'une nouvelle calibration complète à celle de la calibration précédente du même lecteur. Elle devient la nouvelle référence, et les niveaux mesurés avec l'ancienne sont abandonnés.
- **Restauration.** La configuration est enregistrée à la fin de la restauration, réussie ou non, et non plus en cours de route. L'étape « Calibrer le lecteur si nécessaire » affiche le niveau mesuré et ses réserves, et le rapport ajoute une ligne « Niveau ».

### Corrections

- **Calibration long track jamais convergée.** Sur une courbe qui change de sens par une marche, par exemple en long track, la calibration restait sur le même palier, quelle que soit la disquette. La vérification réajuste désormais ces cylindres sur ses propres mesures. Un cylindre isolé peut encore rester hors tolérance et rendre la calibration non convergée : la fenêtre de décision le montre.
- **Virgule décimale.** La ligne de relecture de chaque passe de calibration utilise désormais la virgule décimale, comme la calibration rapide.

### À savoir pour la mise à jour

- Au premier démarrage, la fenêtre « Calibrations d'un autre calcul » propose les courbes de la 12.2 et d'avant. La configuration est d'abord copiée, par exemple dans `GreaseweazleGUI.json.calib-v12.2-avant-v12.3.bak`.
- Avec « Recalibrer (conseillé) », la prochaine écriture qui en a besoin recalibre le lecteur : prévoyez une disquette sacrifiée.
- Une courbe antérieure à la 12.3 ne peut pas servir de référence à la calibration rapide, qui commence alors par une calibration complète en test fin. Une disquette sacrifiée en bon état, du même type que la disquette à écrire, donne la meilleure référence.
- La fenêtre de décision remplace la confirmation à compte à rebours de 120 s de la 12.1. Une écriture ou une restauration sans surveillance attend donc votre réponse si la calibration est douteuse.
- Si vous aviez installé la première 12.3 publiée sans calibrer depuis, les courbes de la 12.2 sont relues dans sa copie `GreaseweazleGUI.json.calib-v12.2.bak` et proposées dans la même fenêtre.

### Pour les développeurs

- Configuration, section `write` : `levelAlgo`, `levelShifts` (avec `verdict` et `shape`) et `calibCalc`.
- Configuration, courbes de `precompCurves` : champs `slope`, `bits`, `test`, `calc` et `keptFor`.
- Une courbe sans `calc` relève du calcul de sa `version` : 12.3 pour la 12.3, plus ancien pour la 12.2 et avant, « antérieur à 12.1 » sans version.

## [12.2] - 2026-10-15

Le contrôle après écriture reconnaît une zone instable due à la disquette écrite et réécrit la piste. Chaque calibration est comparée à la précédente pour repérer un support fatigué.

### Améliorations

- **Zone instable sur la copie.** Une zone instable relevée sur la copie vient de la disquette écrite quand la source n'en a pas à cette piste, par exemple avec un ADF ou une piste stable d'une image SCP. La piste passe alors au moins « À SURVEILLER » et elle est réécrite, au lieu de rester « SAIN ».
- **Pistes « NON JUGÉE ».** Une source peut porter elle-même des bits faibles (IPF, HFE v3, EDSK) ou ne pas être analysée (flux .raw, .kf, .a2r, .ctr, image SCP non analysable). Avec ces sources, une piste à zone instable mais saine par ailleurs s'affiche « NON JUGÉE (zone instable) ». Elle n'est ni réécrite ni comptée saine, et le bilan la cite à part. Voir [Contrôle après écriture](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Contr%C3%B4le-apr%C3%A8s-%C3%A9criture).
- **Onglet « Qualité & alignement ».** Une piste à zone instable est au moins « À SURVEILLER ». La ligne orange évoque une protection contre la copie ou un défaut du support, au lieu d'une protection probable. Trois cylindres consécutifs instables ou plus sur une même face signalent un défaut probable du support.
- **Comparaison des calibrations.** Le journal donne l'écart avec la calibration précédente du même lecteur. Si seule la nouvelle atteint le plafond de 300 ns, il évoque un support de calibration fatigué, ou des têtes à nettoyer.
- **Plafond atteint sur une disquette sacrifiée.** Si une calibration faite sur une disquette sacrifiée atteint le plafond, le journal prévient qu'une disquette fatiguée fait surestimer le besoin de la disquette à écrire. Il conseille d'en prendre une en bon état.

### Corrections

- **Ligne orange des zones instables.** Elle pouvait rester affichée d'une mesure précédente. Chaque contrôle après écriture la met à jour et indique l'origine probable de chaque zone : copie, source, piste déjà critique dans la source ou piste non jugée.
- **Couleur du journal.** Les lignes de zone instable ou de piste non jugée pouvaient s'afficher en vert. Elles sont désormais en orange.

### À savoir pour la mise à jour

- Au premier démarrage, les calibrations de la 12.1 sont abandonnées et les profils calibrés reviennent aux valeurs d'origine. La configuration est d'abord copiée dans `GreaseweazleGUI.json.calib-v12.1.bak`.
- La prochaine écriture qui en a besoin recalibre le lecteur : prévoyez une disquette sacrifiée.

## [12.1] - 2026-10-15

La courbe de calibration peut redescendre quand le besoin de précompensation baisse sur une partie de la disquette. L'application repère les pistes à bits faibles, pour ne pas détruire un original, et trouve seule le lecteur branché.

### Nouveautés

- **Détection des lecteurs.** Au démarrage, l'application essaie le lecteur mémorisé, puis A, B, 0, 1, 2 et 3, et sélectionne le premier qui répond. Chaque essai ramène seulement la tête au cylindre 0, sans faire tourner le moteur ni écrire. Chaque lecteur absent ajoute environ 2,6 s. Si aucun lecteur n'a répondu au démarrage précédent, seul le lecteur mémorisé est essayé. La carte « Tester le Greaseweazle » de l'onglet « Accueil » lance `gw info`, puis teste tous les lecteurs. Le lecteur 3 rejoint les listes.
- **Pistes non reproductibles.** Sur une piste double densité lue en flux, l'application repère les zones qui changent d'un tour à l'autre. Ce sont des bits faibles d'une protection contre la copie, ou un défaut localisé. Comme gw n'écrit qu'un tour d'un flux, une copie ne peut pas les reproduire. L'onglet « Qualité & alignement » marque ces pistes « (zone instable) ».
- **Écriture d'une image SCP protégée.** Si l'image contient de telles pistes, la fenêtre « Protection contre la copie » demande confirmation, « Non » par défaut. Le contrôle après écriture ne réécrit pas ces pistes, ni celles déjà critiques ou illisibles dans l'image, et ne les compte pas parmi les pistes saines.
- **Restauration : l'original est reconnu.** En « Copie exacte du flux », la disquette insérée est comparée à l'original par une empreinte, et l'écriture est refusée si c'est l'original. Pour remplacer une ancienne copie reconnue comme l'original, effacez-la d'abord dans l'onglet « Outils ». « Écraser quand même » sert à rafraîchir l'original. Il ne réécrit jamais les cylindres qui portent une piste non reproductible ou déjà critique, et le rapport les liste en « Préservés ». Si l'original porte de telles pistes, le verdict de la restauration est « avec réserve ». Voir [Restaurer une disquette](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Restaurer-une-disquette).
- **Réglage du jitter.** La carte « Régler le jitter » de l'onglet « Accueil » fixe le jitter maximal d'une piste « SAIN » et d'une piste « À SURVEILLER ». Les préréglages vont de « Standard (120 / 250 ns) » à « Très strict (70 / 140 ns) », et des valeurs personnalisées sont possibles. Ils valent pour l'onglet « Qualité & alignement », le contrôle après écriture et celui de la copie restaurée. Plus ils sont stricts, plus de pistes sont réécrites.
- **Carte « Courbe de calibration ».** Dans l'onglet « Accueil », elle ouvre la fenêtre « Courbe » de la dernière calibration.

### Améliorations

- **Courbe qui peut redescendre.** La courbe de précompensation n'est plus forcée à croître : elle admet deux changements de sens au plus, si les mesures le justifient. Un besoin qui baissait après un pic était auparavant aplati en un palier inadapté. La fenêtre « Courbe » trace ces changements en pointillés.
- **Mesures plus sûres.** En test standard, une chute nette du besoin entre deux cylindres testés déclenche des mesures sur les cylindres intermédiaires, 30 au plus. Sur ces mesures serrées, comme en test fin, un cylindre en désaccord net avec ses voisins est écarté de la courbe, comme défaut ponctuel probable de la disquette. La fenêtre « Courbe » le marque d'une croix, « isolée ». Voir [Calibration : détails techniques](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Calibration-d%C3%A9tails-techniques).
- **Usure de la disquette sacrifiée.** Après une correction, la deuxième vérification de la calibration ne réécrit et ne relit que les cylindres corrigés. L'avertissement affiché avant la calibration annonce le nombre maximal de passes, jusqu'à 8 en test standard et 6 en test fin.
- **Calibration « NON CONVERGÉE » avant une écriture.** Une fenêtre propose « Écrire l'image » ou « Annuler ». Sans réponse, l'écriture démarre seule après 120 s. Une écriture qui réutilise plus tard cette courbe le signale dans le journal.
- **Remise de la disquette à écrire.** Après une calibration sur disquette sacrifiée, cette demande a aussi un compte à rebours de 120 s. Sans réponse, l'image est écrite sur la disquette insérée. En restauration, l'application vérifie d'abord que ce n'est pas l'original.
- **Restauration avec un format.** La confirmation demandée par « Écraser quand même » prévient qu'une protection contre la copie serait détruite. Des secteurs illisibles regroupés sur une ou deux pistes sont signalés comme une protection probable, avec le conseil de relancer en « Copie exacte du flux ».
- **Vouvoiement.** Consignes, infobulles, messages et journal vouvoient désormais l'utilisateur.

### Corrections

- **Calibration déclarée « NON CONVERGÉE » à tort.** Un cylindre bloqué au plafond de 300 ns, ou au plancher de 0 ns, rendait la calibration non convergée. Il est maintenant signalé à part, car une nouvelle calibration n'y changerait rien.

### À savoir pour la mise à jour

- Au premier démarrage, les calibrations de la 12.0 et d'avant sont abandonnées. La configuration est d'abord copiée dans `GreaseweazleGUI.json.calib-ancienne.bak`. Les profils standard et long track reviennent aux valeurs d'origine, de même que les champs « Précompensation (--precomp) : », sauf en profil « Manuel ».
- La prochaine écriture qui en a besoin recalibre le lecteur : prévoyez une disquette sacrifiée.
- Désormais, une calibration n'est reprise que par la version qui l'a faite.
- Le choix « Lecteur : » peut changer au démarrage si le lecteur mémorisé ne répond pas.

### Pour les développeurs

- Algorithme de calibration : `seg1`.
- Configuration : `write.calibVersion`, `write.calibAlgo`, champs `version`, `algo` et `breaks` des courbes, section `quality` (`jitterOk`, `jitterWatch`), `global.detectNone`.

## [12.0] - 2026-10-15

Le nouvel onglet « Restauration » copie une disquette avec les contrôles les plus stricts, et l'onglet « Bibliothèque » écrit une image en un clic. Un onglet « Accueil » regroupe les tâches courantes, et un affichage simplifié masque les onglets techniques. La calibration écrit désormais un motif de test, ce qui la rend reproductible.

### Nouveautés

- **Onglet « Restauration ».** Il copie une disquette d'origine sur une disquette vierge, avec un ou deux lecteurs et les contrôles les plus stricts. Avec un format Amiga, Atari ST ou PC, il refuse d'écrire si un secteur de l'original est illisible, puis compare la copie à l'original secteur par secteur. Voir [Restaurer une disquette](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Restaurer-une-disquette).
- **Restauration : écriture et contrôle.** La copie est écrite tête par tête, avec 20 essais par piste, puis toutes ses pistes sont contrôlées, avec au plus 5 passes de réécriture. La calibration existante du lecteur est reprise, sinon chaque tête est calibrée en test fin. En haute densité, la copie n'est ni calibrée ni contrôlée piste par piste, mais reste comparée à l'original.
- **Restauration : copie exacte du flux.** Le choix « Copie exacte du flux (disquette protégée ou format inconnu) » recopie le signal tel quel, sans précompensation, et ne vérifie la copie que par le contrôle des pistes. Ce mode refuse la haute densité.
- **Restauration : original protégé.** Avec un format, l'écriture est refusée si la disquette insérée semble être l'original, sauf clic sur « Écraser quand même ». En copie de flux avec un seul lecteur, une confirmation est demandée.
- **Restauration : rapport.** Le rapport et les fichiers lus sont enregistrés par défaut dans « Documents\Greaseweazle Studio\Restaurations ».
- **Onglet « Accueil ».** Placé en premier, il propose six tâches courantes, de « Restaurer une disquette » à « Guide pas à pas ».
- **Case « Mode expert ».** Décochée, cette case du bandeau masque les onglets techniques, comme « Conversion » ou « Outils ». Elle se coche d'elle-même quand une fonction a besoin d'un onglet masqué.
- **Bouton « Aide » et touche F1.** Ils ouvrent la page du wiki consacrée à l'onglet affiché.
- **Boutons « Écriture rapide » et « Écriture lente ».** Dans l'onglet « Bibliothèque », ils remplacent « Envoyer vers Écriture » : un clic règle l'onglet « Écriture » et lance l'écriture. « Écriture rapide » écrit les deux têtes ensemble, sans contrôle complet des pistes. « Écriture lente » écrit une tête après l'autre, puis contrôle toutes les pistes et réécrit les pistes faibles.
- **Calibration avant l'écriture.** Si la calibration nécessaire manque ou date d'avant le motif de test, ces deux boutons calibrent d'abord le lecteur. Si elle est refusée ou échoue, l'écriture est annulée. Un flux SCP ou une image haute densité, par exemple, est écrit sans calibration.
- **Avertissement avant calibration.** Avant chaque calibration, une fenêtre rappelle que les passes répétées du motif de test peuvent fatiguer le support, et conseille une disquette sacrifiée. Sans réponse, elle se valide seule au bout de 120 s.
- **Calibration sur une disquette sacrifiée.** Quand la calibration précède une écriture, la case « J'ai inséré une disquette sacrifiée : me redemander la disquette à écrire après la calibration » fait redemander la disquette à écrire ensuite.
- **Bouton « Effacer les calibrations ».** Dans l'onglet « Écriture », il supprime, après confirmation, toutes les courbes de précompensation et remet les profils standard et long track à leurs valeurs d'origine. L'opération est irréversible.

### Améliorations

- **Calibration sur un motif de test.** La calibration écrit un motif pseudo-aléatoire au lieu des pistes de l'image, dont les pistes peu remplies faussaient la mesure. Elle devient reproductible, et une image simple face peut calibrer les deux têtes. Le test fin dure un quart d'heure environ.
- **Calibration plus fiable.** La valeur de chaque cylindre est estimée plus précisément. Si 200 ns ne suffisent pas sur un cylindre, une passe supplémentaire monte jusqu'à 300 ns, valeur maximale. Le journal dresse un bilan, et une calibration incomplète est marquée « NON CONVERGÉE ». La fenêtre « Courbe » indique l'origine de chaque point et hachure la zone extrapolée. Voir [Calibration : détails techniques](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Calibration-d%C3%A9tails-techniques).
- **Libellés simplifiés.** « Essais », « Tours », « Pistes » et « Chrono » remplacent « Retries », « Révolutions », « Tracks » et « --time ». Dans « Lecture / Dump », les cases deviennent « Flux brut (--raw) » et « Face B flippy (--reverse) ». En bas de la fenêtre, « Vider » et « Enregistrer » remplacent « Effacer » et « Paramètres ». Trois boutons de l'onglet « Outils » sont renommés, et les messages parlent d'essais au lieu de retries.
- **Aide dans les champs.** Les champs vides affichent un texte indicatif gris. Les infobulles, plus nombreuses, restent affichées 30 s au lieu de 5 s.
- **Avertissement sur les flux reconstitués.** Le journal avertit qu'un SCP ou un RAW lu avec un format, sans « Flux brut (--raw) », contient un flux reconstitué à partir des secteurs décodés.
- **Documentation réécrite.** Le wiki, réécrit pour les débutants, gagne quatre pages, dont Premiers pas, Glossaire et Formats et limites. Le README renvoie au [wiki](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki) pour le détail.

### Corrections

- **ADF haute densité.** Un ADF haute densité choisi dans l'onglet « Écriture » ou l'onglet « Bibliothèque » recevait le format « amiga.amigados » au lieu de « amiga.amigados_hd ».
- **Images haute densité.** Plusieurs formats haute densité, dont les ADF HD de taille non standard, subissaient le contrôle des pistes prévu pour la double densité. Ils sont désormais reconnus.
- **Image HFE long track.** Le profil « Auto (selon image) » appliquait la précompensation standard à une image HFE v1 long track. Il la reconnaît désormais.
- **« Flux brut (--raw) » et image secteur.** Cochée pour une image secteur (ADF, IMG, IMA, ST, DSK), cette option, que gw refuse, faisait échouer la lecture. Elle est désormais ignorée.
- **Lecteur sans capteur d'index.** La calibration ignorait les options de lecteur de l'onglet « Écriture », dont « Fake index ». Un tel lecteur ne pouvait donc pas être calibré.
- **Calibrations sans objet.** « Calibrer » refuse désormais les cas où la mesure n'a pas de sens : image haute densité, case « Secteurs durs (--hard-sectors) » ou « TG43 lecteur 8 pouces (--gen-tg43) » cochée, image IPF ou HFE de densité hors de la plage mesurable.

### À savoir pour la mise à jour

- Sur une installation existante, « Mode expert » est coché d'office et tous les onglets restent visibles. Décochez-le pour l'affichage simplifié.
- Les calibrations des versions précédentes ont été mesurées sur le contenu d'une image. « Écriture rapide » et « Écriture lente » les refont, et la restauration les utilise en le signalant. Pour les remplacer, lancez « Calibrer » dans l'onglet « Écriture », avec « Écriture lente » cochée pour des courbes par tête.
- Une écriture lancée depuis l'onglet « Bibliothèque » peut désormais commencer par une calibration. La disquette insérée reçoit alors le motif de test avant l'image.

### Pour les développeurs

- Configuration : sections `ui` et `restore`, champ `method` des courbes (`motif`, ou `image` si absent).
- Releases v11.3 à v11.7 : l'exécutable non signé publié par la CI a été remplacé le 14/10/2026 par une version recompilée depuis le tag et signée.
- README complété : signature et procédure de publication, échec de compilation des helpers C#, fichiers de configuration et temporaires, moteur PS2EXE (Microsoft Limited Public License 1.1) embarqué.
- Remerciements (README, accueil du wiki) : le code a été entièrement écrit par Claude (Anthropic), via Claude Code, sous la direction de Bartozorus.
- LICENSE : mention de copyright étendue aux contributeurs.

## [11.8] - 2026-10-14

La nouvelle écriture lente écrit une disquette tête par tête, et le contrôle après écriture relit désormais toutes les pistes pour réécrire les pistes faibles. La calibration de la précompensation est plus courte et donne une valeur pour chaque cylindre.

### Nouveautés

- **Écriture lente.** La nouvelle case « Écriture lente » de l'onglet « Écriture » écrit toutes les pistes de la tête 0, puis toutes celles de la tête 1, chaque tête avec sa propre précompensation. Le champ « Précompensation (--precomp) : » devient alors « Précomp. tête 0 (--precomp) : » et le champ « Précomp. tête 1 (--precomp) : » s'active. L'écriture est plus longue, et la tête 1 n'est pas écrite si la tête 0 échoue. Voir [Écriture lente](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/%C3%89criture-lente).
- **Faces écrites en écriture lente.** Les têtes écrites sont celles du champ « Pistes : », ou à défaut celles présentes dans l'image IPF, HFE ou ADF. Pour une autre image, l'écriture est refusée si « Effacer les pistes vides » est coché et que « Pistes : » ne précise pas les têtes. Cela évite d'effacer la tête 1 d'un format simple face.
- **Calibration par tête.** Quand « Écriture lente » est cochée, « Calibrer » établit et vérifie une courbe pour chaque tête. En écriture lente, ces courbes remplacent ensuite le profil commun de la même famille d'images, sauf si une calibration commune plus récente existe. Avec une image simple face, la calibration par tête est refusée : décochez « Écriture lente » pour une calibration commune.
- **Une valeur par cylindre.** La calibration ajuste une courbe sur les cylindres mesurés et en tire une valeur de précompensation pour chaque cylindre, au lieu de paliers. Le nouveau bouton « Courbe », à côté de « Profil précomp. : », ouvre une fenêtre qui affiche les mesures, la courbe et le tableau des valeurs, avec une courbe par tête en écriture lente. Il est actif dès qu'une courbe a été calibrée pour la famille de l'image.
- **Contrôle de toutes les pistes.** La case « Contrôler toutes les pistes » remplace « Mesurer la disquette après l'écriture », qui ne relisait que quelques cylindres. Chaque piste écrite est relue et jugée avec les critères de l'onglet « Qualité & alignement ». Cet onglet s'affiche à la fin, avec l'état final et le nombre de réécritures de chaque piste. Voir [Contrôle après écriture](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Contr%C3%B4le-apr%C3%A8s-%C3%A9criture).
- **Réécriture des pistes faibles.** Une piste faible (« À SURVEILLER », « CRITIQUE » ou illisible) est réécrite seule, avec pré-effacement, puis remesurée. En écriture lente, chaque tête est réécrite avec sa propre précompensation. Le champ « Passes de réécriture : » fixe le nombre maximal de reprises, de 0 à 10, et 0 limite l'opération au contrôle.
- **Limites du contrôle.** Il ne s'applique qu'au MFM double densité. La haute densité, le GCR, les secteurs durs et le 8 pouces sont écrits sans contrôle. Si plus de la moitié des pistes sont faibles, aucune réécriture n'est lancée et l'application invite à vérifier le format, la disquette et le lecteur.

### Améliorations

- **Calibration plus courte.** La calibration mesure directement le décalage des transitions à la relecture, au lieu d'un score de jitter. Quatre à cinq passes suffisent au lieu de quatorze, vérification comprise.
- **Onglet « Écriture » défilant.** Dans une fenêtre trop basse, l'onglet défile au lieu de masquer ses derniers éléments. Il s'ouvre en haut, sur le choix de l'image.

### Corrections

- **Séquence reprise après un échec de lancement de gw.** Si gw ne pouvait pas être lancé pendant une écriture contrôlée, une calibration ou une comparaison, la commande gw suivante, même sans rapport, reprenait les étapes restantes, écritures comprises. La séquence est désormais abandonnée.
- **Fausse alerte « opération incomplète ».** Elle apparaissait à tort à l'écriture d'une image de moins de 82 pistes. Une écriture n'est plus jugée incomplète que si gw s'arrête sans afficher son bilan de fin.
- **Pistes renumérotées par gw.** Quand gw affichait une piste sous la forme `T1.0 -> Drive 2.0`, la barre de progression n'avançait pas et les retries de cette piste n'étaient pas relevés. Ces lignes sont désormais reconnues par la progression, le relevé des retries et le contrôle.
- **Images HFE.** Leur débit était mal lu : le profil « Auto (selon image) » et la calibration les classaient en long track. Le débit est désormais lu correctement.
- **Bouton « Arrêter ».** Il restait sans effet entre deux commandes gw d'une même séquence. Il l'interrompt désormais à tout moment.
- **Case « Continu ».** La mesure continue de l'onglet « Qualité & alignement » ne lance plus de cycle au milieu d'une écriture, d'une calibration ou d'une comparaison.

### À savoir pour la mise à jour

- La case « Contrôler toutes les pistes » reprend l'état de l'ancienne case « Mesurer la disquette après l'écriture », cochée par défaut. Une écriture contrôlée relit désormais toute la disquette et réécrit d'elle-même les pistes faibles, jusqu'à 3 passes, ce qui la rend plus longue. Réglez « Passes de réécriture : » sur 0 pour un simple contrôle.
- Un profil calibré en 11.5 à 11.7 reste appliqué tel quel, mais le bouton « Courbe » reste grisé faute de courbe enregistrée. Recalibrez pour obtenir une valeur par cylindre avec la nouvelle mesure.
- Si vous avez calibré avec une image HFE en 11.5 à 11.7, le résultat a été enregistré à tort comme profil long track. Recalibrez alors les deux familles, le profil long track avec une image long track.

### Pour les développeurs

- Configuration : nouvelles clés `precomp1`, `slowWrite`, `repairMax` et `precompCurves` dans la section `write`.

## [11.7] - 2026-10-07

Les derniers messages de gw, dont ses messages d'erreur, sont désormais toujours lus, par exemple sur une disquette protégée en écriture. Une commande gw qui s'arrête en cours de route sans code d'erreur est maintenant signalée.

### Améliorations

- **Bilan de commande.** La ligne « <<< Terminé » qui clôt chaque commande gw indique aussi sa durée et le nombre de lignes reçues.

### Corrections

- **Fin de la sortie de gw perdue.** Les dernières lignes de gw n'étaient pas toujours lues. Sur une disquette protégée en écriture, « Command Failed: WriteProtected » manquait ainsi au journal, alors que gw se terminait sans code d'erreur. L'application lit désormais toute la sortie, et ces messages s'affichent en couleur d'erreur.
- **Opération incomplète non signalée.** Une commande gw arrêtée en cours de route sans code d'erreur passait pour réussie. Quand gw se termine ainsi après moins de la moitié des pistes annoncées, le journal affiche désormais « ERREUR : opération incomplète ». La mesure prévue par la case « Mesurer la disquette après l'écriture » n'est pas lancée, et la suite de la séquence, une calibration par exemple, est annulée.

## [11.6] - 2026-10-07

La calibration affiche désormais son avancement. Le lancement de gw fonctionne aussi quand l'application est ouverte depuis un partage réseau.

### Améliorations

- **Progression de la calibration.** Une barre sous « Calibration précomp : » suit l'ensemble des passes. Elle indique la passe en cours, la phase (écriture ou relecture), le pourcentage et le temps restant, estimé d'après la durée des passes déjà faites. En fin de calibration, elle affiche la durée totale.

### Corrections

- **Lancement depuis un partage réseau.** Lancé depuis un chemin `\\serveur\...`, l'exécutable trouvait gw.exe mais ne parvenait pas à le lancer. L'application utilise désormais le dossier de l'exécutable, quel que soit le dossier courant.

### Pour les développeurs

- `Build-Exe.ps1` signe dans tous les cas, y compris sur un poste joint à un domaine (fin de l'exception de la 11.4). Seul `-Sign:$false` compile sans signer. Règle du projet : tout exécutable livré doit être signé.
- Workflow de release : exécutable signé en CI, avec horodatage, si les secrets `CODESIGN_PFX_BASE64` et `CODESIGN_PFX_PASSWORD` existent. Sinon, il est publié non signé et le journal du workflow le signale.
- Workflow de release : notes tirées de la section du CHANGELOG. Un lancement manuel régénère les notes d'une release existante, la dernière par défaut.

## [11.5] - 2026-10-07

La précompensation peut désormais être calibrée automatiquement, et l'interface est disponible en anglais.

### Nouveautés

- **Calibration de la précompensation.** Nouvelle ligne « Calibration précomp : » dans l'onglet « Écriture ». « Calibrer » écrit les cylindres de test de l'image choisie avec plusieurs valeurs de précompensation, puis les relit pour retenir la meilleure valeur par cylindre. Le profil obtenu est enregistré pour la famille de l'image, standard ou long track, puis appliqué par le profil « Auto (selon image) ».
- **Durée et disquette de test.** « Test standard : 1 cylindre sur 10 » dure quelques minutes, « Test fin : tous les cylindres » environ une heure. La disquette insérée est écrasée : prenez-en une vierge ou sans valeur. Une image de flux (SCP, RAW, etc.) est refusée, car gw ne lui applique pas de précompensation.
- **Interface en anglais.** L'interface suit la langue d'affichage de Windows : français, ou anglais pour toute autre langue. Lancez l'application avec `-Language fr` ou `-Language en` pour forcer la langue. La coloration du journal fonctionne dans les deux langues.

### Corrections

- **Libellés tronqués.** Des libellés comme « Images seulement », « Masquer journal » ou « Réindexer » étaient coupés. Boutons et cases à cocher s'ajustent désormais au texte et à la police au démarrage.

### Pour les développeurs

- Traduction : les textes français servent de clés dans le code, la table anglaise est embarquée dans le script.

## [11.4] - 2026-10-07

Aucun changement dans l'application. Seule la compilation de l'exécutable évolue.

### Pour les développeurs

- `Build-Exe.ps1` lancé depuis PowerShell 7 se relance seul sous Windows PowerShell 5.1, que PS2EXE exige, avec `-ExecutionPolicy Bypass`. La relance faite par PS2EXE lui-même, sans ce paramètre, échouait en stratégie Restricted.
- `Build-Exe.ps1` supprime l'exécutable précédent avant de compiler. Il échoue clairement si ce fichier est verrouillé ou si PS2EXE ne produit rien, au lieu de signaler un faux succès.
- `Build-Exe.ps1` ne signe plus sur un poste joint à un domaine ou à Entra ID, sauf `-Sign` explicite.

## [11.3] - 2026-10-07

Greaseweazle Studio, interface graphique Windows de gw.exe, l'outil Greaseweazle, est publié pour la première fois sur GitHub. Il permet de lire, écrire, convertir et contrôler des disquettes.

### Nouveautés

- **Toutes les commandes de gw.** Les 13 actions de gw sont accessibles : info, read, write, convert, erase, clean, seek, delays, update, pin, reset, bandwidth et rpm.
- **Neuf onglets.** « Bibliothèque », « Écriture », « Lecture / Dump », « Conversion », « Comparaison », « Qualité & alignement », « Outils », « Délais » et « Commande libre ».
- **Bibliothèque d'images.** L'onglet « Bibliothèque » parcourt votre dossier d'images, archives ZIP comprises. La recherche est instantanée grâce à un index construit en arrière-plan et conservé d'une session à l'autre. Les documents associés (txt, md, pdf, nfo, images) s'ouvrent dans l'application par défaut.
- **Précompensation selon l'image.** Dans l'onglet « Écriture », le choix « Auto (selon image) » de la liste « Profil précomp. : » applique « Standard 2 us » ou « Long track 1,89 us » d'après l'image IPF, SCP ou HFE. Une image secteur, comme un ADF, reçoit le profil standard. Le choix « Manuel » laisse la précompensation telle que vous l'avez saisie.
- **Script ou exécutable.** L'application est livrée en script PowerShell et en exécutable `GreaseweazleGUI.exe`, à placer dans le dossier de gw.exe.

### Pour les développeurs

- Compilation de l'exécutable avec PS2EXE par `Build-Exe.ps1`, avec signature auto-signée par défaut. `-Sign:$false` compile sans signer.
- Dépôt : sources dans `src/`, sortie de compilation dans `dist/`, workflow GitHub Actions de release.

## Versions antérieures

Historique reconstitué depuis l'en-tête du script ; les versions 10 à 11.2 ne sont pas documentées.

- **v9** : profils de précompensation choisis automatiquement d'après l'image.
- **v8** : onglet Alignement, mesure de qualité de lecture (jitter, asymétrie, dropouts) en continu pendant le réglage du stepper.
- **v7** : onglet Comparaison, convert (référence) + read (disquette) + diff secteur.
- **v6** : fenêtre entièrement redimensionnable, recherche de la bibliothèque en arrière-plan.
