# Greaseweazle Studio

Interface graphique Windows (PowerShell / WinForms) pour les [Greaseweazle host tools](https://github.com/keirf/greaseweazle) de Keir Fraser. Elle pilote `gw.exe` pour lire, écrire, convertir et contrôler des disquettes, avec un accent sur la préservation de disquettes Amiga.

L'application tient dans un seul script, `GreaseweazleGUI.ps1`, sans dépendance externe. Elle est aussi livrée sous forme d'exécutable `GreaseweazleGUI.exe` compilé avec PS2EXE.

## Fonctionnalités

- Les 13 actions de `gw` : `info`, `read`, `write`, `convert`, `erase`, `clean`, `seek`, `delays`, `update`, `pin`, `reset`, `bandwidth`, `rpm`.
- **Bibliothèque** : arborescence d'images disque, archives ZIP parsées à la volée, index persistant construit en arrière-plan avec recherche instantanée, ouverture des documents associés (txt, pdf, jpg, png, gif, nfo, md) dans l'application par défaut. Boutons « Écriture rapide » et « Écriture lente » : écriture de l'image sélectionnée avec les paramètres adaptés et calibration automatique si nécessaire, voir ci-dessous.
- **Écriture** : choix de l'image, profil de précompensation détecté automatiquement d'après l'image (IPF et HFE : bits par piste, HFE v3 : débit ; SCP : flux), options courantes et avancées, contrôle de toutes les pistes après écriture avec réécriture automatique des pistes faibles, écriture lente tête 0 puis tête 1 avec une précompensation par tête, voir ci-dessous.
- **Calibration de la précompensation** : mesure automatique du meilleur `--precomp` pour le lecteur d'écriture, commun aux deux têtes ou propre à chaque tête, voir ci-dessous.
- **Lecture** et **Conversion** : options de `gw read` et `gw convert`.
- **Comparaison** : convert (référence) + read (disquette), puis diff secteur par secteur.
- **Qualité & Alignement** : mesure continue de la qualité de lecture (cellule mesurée, jitter, asymétrie, dropouts) sur une disquette pressée, pour régler l'alignement d'un lecteur.
- **Outils** et **Délais** : erase, clean, seek, rpm, bandwidth, pin, reset, update, delays.
- **Commande libre** : n'importe quelle ligne de commande `gw`.
- Journal repliable avec coloration, barre de progression, fenêtre entièrement redimensionnable.
- Interface en français ou en anglais : la langue est choisie d'après la langue d'affichage de Windows, toute autre langue que le français donnant l'anglais. `-Language fr` ou `-Language en` force le choix.

## Prérequis

- Windows 10 ou 11.
- Windows PowerShell 5.1 (inclus dans Windows) ou PowerShell 7. L'exécutable compilé s'appuie sur Windows PowerShell 5.1.
- .NET Framework 4.x (inclus dans Windows) : WinForms et compilation à la volée des helpers C# (comparaison rapide, analyse de flux SCP, index de bibliothèque). Chaque helper est compilé séparément. Si la compilation de la comparaison ou de l'index échoue, la fonction correspondante bascule sur un chemin PowerShell plus lent, la recherche dans la bibliothèque se faisant alors sans index. L'analyse de flux SCP n'a pas d'équivalent PowerShell : sans elle, la mesure de l'onglet Qualité & alignement et la calibration de la précompensation sont refusées, le contrôle après écriture est ignoré, le profil Auto traite tout flux SCP comme une image standard 2 µs, et les boutons Écriture rapide et Écriture lente écrivent sans calibration automatique, avec le profil courant.
- Greaseweazle host tools : `gw.exe` extrait de l'archive Windows d'une [release](https://github.com/keirf/greaseweazle/releases). Développé et testé avec la version 1.23 ; la liste des formats d'images reconnus est alignée sur `gw write --help` de cette version.

## Installation

1. Télécharger et extraire les Greaseweazle host tools, par exemple dans `C:\greaseweazle-1.23\`.
2. Copier dans ce même répertoire, au choix :
   - `GreaseweazleGUI.exe` depuis la page [Releases](https://github.com/Bartozorus/GreaseweazleGUI_Studio/releases) ;
   - ou `src/GreaseweazleGUI.ps1` depuis ce dépôt.
3. Lancer : double-clic sur `GreaseweazleGUI.exe`, ou pour le script :

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\GreaseweazleGUI.ps1
   ```

`gw.exe` est résolu depuis le répertoire du script ou de l'exécutable. S'il est absent, le journal le signale au démarrage.

Pour forcer la langue de l'interface, ajouter `-Language en` ou `-Language fr` à la commande, avec l'exécutable comme avec le script :

```powershell
.\GreaseweazleGUI.exe -Language en
```

### Avertissements SmartScreen et antivirus

L'exécutable est produit par PS2EXE, qui embarque le script dans un hôte .NET. Ce type de binaire déclenche fréquemment SmartScreen et des faux positifs antivirus. L'exécutable publié dans les releases est signé avec le certificat auto-signé du projet, `CN=Greaseweazle Studio`, et non par une autorité reconnue : la signature atteste que le fichier n'a pas été modifié, mais elle n'est pas reconnue sur un poste tiers et SmartScreen avertit quand même. En cas de doute, utilisez directement le script `.ps1`, lisible et fonctionnellement identique.

## Contrôle après écriture et réécriture des pistes faibles

Avec la case « Contrôler toutes les pistes » de l'onglet Écriture, chaque écriture réussie est suivie d'un contrôle complet :

1. Les pistes que gw a réellement écrites sont relues en flux, sur trois tours, avec le lecteur et les options de lecteur de l'écriture. Une piste vide de l'image, seulement effacée, n'est pas contrôlée. Si le champ « Pistes » est rempli, seules ces pistes sont concernées.
2. Chaque piste est classée avec les critères de l'onglet Qualité & alignement : erreurs hors classe, trous de signal, stabilité entre tours et jitter. Une piste À SURVEILLER, CRITIQUE, illisible ou absente de la relecture est faible.
3. Les pistes faibles, et elles seules, sont réécrites avec pré-effacement, puis seules remesurées. Les commandes visent exactement ces pistes : cylindres à deux faces faibles en `h=0-1`, sinon une face à la fois.
4. L'opération se répète tant qu'il reste des pistes faibles, au plus le nombre de « Passes de réécriture », 3 par défaut, de 0 à 10, enregistré dans la configuration. À 0, le contrôle signale les pistes faibles sans rien réécrire.

Le journal détaille chaque passe. À la fin, l'onglet Qualité & alignement affiche l'état final de chaque piste, avec le nombre de réécritures, et le verdict : toutes les pistes saines, ou pistes encore faibles à recopier sur une autre disquette. Si plus de la moitié des pistes sont faibles au premier contrôle, et que celui-ci porte sur au moins 20 pistes, aucune réécriture n'est lancée : c'est le signe d'un format non MFM, d'une disquette inadaptée ou d'un lecteur en défaut. En deçà de 20 pistes contrôlées, par exemple une sélection réduite dans le champ « Pistes », les pistes faibles sont réécrites normalement. Une piste volontairement instable, comme une protection à bits faibles, restera signalée faible : le nombre de passes borne alors les réécritures inutiles.

Le contrôle ne s'applique qu'au MFM double densité, pour lequel l'analyse de flux est calibrée. Il est automatiquement désactivé, avec un message, pour les images haute densité (format gw à 500 ou 1 000 kbit/s comme `_hd`, `.1440` ou `raw.500`, format implicite d'un HDM, XDF, FDI, DIM, DCP, D2M ou D4M, ADF HD, IMD à 500 kbit/s, image secteur brute d'au moins 1 200 000 octets, IPF ou HFE à cellule courte, flux SCP haute densité), les formats GCR, Commodore 1541 ou Apple II, les secteurs durs et l'option « TG43 lecteur 8 pouces ». L'écriture se fait alors sans contrôle. Le bouton Arrêter interrompt le contrôle à tout moment. Si gw échoue pendant une passe de réécriture, le contrôle s'arrête avec un verdict qui tient compte des pistes déjà remesurées.

## Calibration de la précompensation

Dans l'onglet Écriture, la ligne « Calibration précomp » détermine le profil `--precomp` adapté au lecteur d'écriture, sans réglage manuel :

1. Choisir l'image à écrire : elle fixe la famille, la densité du motif de test et le nombre de cylindres, lu dans le fichier (taille d'un ADF, enregistrements d'un IPF, en-tête d'un HFE ; 80 à défaut). Son contenu n'est pas écrit. Chaque passe écrit un motif de test généré : un HFE de données pseudo-aléatoires codées MFM, à la densité de l'image : 101 344 cellules par piste pour un ADF, soit 1 973,5 ns par cellule comme gw l'écrit avec l'horloge AmigaDOS, nombre de bits par piste pour un IPF ou un HFE, lu dans sa table des pistes (400 × débit pour un HFE v3), 2 µs par cellule pour les autres formats à secteurs. gw calant chaque piste sur un tour du lecteur, c'est ce nombre de cellules qui fixe la densité écrite. Toutes ses pistes ont la même richesse de motifs. Sur une piste pauvre de l'image, comme des secteurs vides, la mesure ne reposait que sur quelques dizaines d'en-têtes et de marques de synchronisation : plus bruitée, et biaisée de quelques nanosecondes, jusqu'à une quinzaine selon deux simulations indépendantes. Le motif rend la calibration reproductible et indépendante de l'image. Il faut une image à bits ou secteurs (ADF, IPF, HFE, IMG...) : la calibration ne détermine pas la densité d'un flux SCP ou RAW. La calibration est refusée avec « Secteurs durs » ou « TG43 » cochés, et pour un IPF ou un HFE dont la cellule sort de 1 700 à 2 300 ns. Une image haute densité (format gw à 500 ou 1 000 kbit/s comme `_hd`, `.1440` ou `raw.500`, format implicite d'un HDM, XDF, FDI, DIM, DCP, D2M ou D4M, ADF HD, IMD à 500 kbit/s, image secteur brute d'au moins 1 200 000 octets, IPF ou HFE à cellule courte) est refusée, les familles calibrées étant double densité.
2. Choisir le test : « standard » écrit un cylindre sur dix plus le dernier, en quelques minutes ; « fin » écrit tous les cylindres, pour un profil précis, en un quart d'heure environ.
3. Insérer une disquette vierge ou sans valeur dans le lecteur sélectionné, cliquer « Calibrer » et confirmer. Chaque passe écrit le motif sur les cylindres de test en une seule commande, puis les relit en flux sur trois tours. L'analyse mesure le décalage de pic résiduel, signé : à la lecture, une transition est repoussée par sa voisine la plus proche, donc un intervalle court encadré par deux longs est lu trop long et un 3T encadré par deux courts trop court. Positif, la précompensation est insuffisante ; négatif, excessive ; nul, le réglage est idéal.
4. Trois passes de mesure écrivent 0, 100 puis 200 ns. Pour chaque cylindre testé, la valeur qui annule le décalage est interpolée entre les deux mesures de signes opposés qui l'encadrent, avec la pente locale, et accompagnée de son incertitude. Un cylindre encore sous-compensé à 200 ns, dont la valeur ne serait qu'extrapolée, reçoit une passe d'encadrement à son estimation plus 80 ns, 300 ns au plus : sa valeur est alors interpolée elle aussi. Une valeur qui reste extrapolée reçoit une incertitude élargie ; une valeur hors de 0 à 300 ns est plafonnée. L'analyse cale la cellule sur le motif, dont le nombre de cellules par tour est connu, et ne retient une piste que si les quatre contextes comparés comptent chacun au moins 30 occurrences ; l'incertitude vient de la dispersion mesurée dans ces contextes.
5. Une courbe est ensuite ajustée sur ces valeurs, pondérées par leur incertitude, puis évaluée pour chaque cylindre de l'image : une valeur entière en nanosecondes par cylindre, y compris entre les cylindres testés en mode standard. Trois formes croissantes vers l'intérieur sont essayées, linéaire en cylindre, en 1/rayon et en 1/rayon², car le besoin suit la densité linéaire des bits ; la mieux ajustée est retenue. Si aucune n'explique les mesures, par exemple un lecteur au comportement en coude, les mesures lissées sont interpolées de façon monotone.
6. Une passe de vérification écrit ce profil et mesure le résidu. Chaque mesure de vérification devient un point de plus pour son cylindre, et l'estimation est recalculée. Aux cylindres hors tolérance, 4 ns, élargie à trois erreurs-types quand la mesure est plus bruitée, la courbe est corrigée localement, la correction étant interpolée entre cylindres vérifiés, puis une dernière passe vérifie. Une anomalie limitée à un seul cylindre n'est mesurée à coup sûr qu'en test fin. En test standard, elle passe inaperçue si elle touche un cylindre non testé ; sur un cylindre testé, elle est mesurée, mais sa correction est interpolée sur les cylindres voisins non testés. Quatre à six passes au total, passe d'encadrement comprise : quelques minutes en test standard, un quart d'heure environ en test fin. Dans une même commande, gw n'accepte qu'une valeur par cylindre, commune aux deux faces : pour une valeur propre à chaque tête, voir l'écriture lente ci-dessous.
7. Le journal termine par un bilan de fiabilité : cylindres non convergés, dont le résidu reste hors tolérance après la dernière vérification ou que celle-ci n'a pas pu relire ; écarts entre la courbe et la mesure supérieurs à la fois à 15 ns et à trois incertitudes, typiquement un besoin non croissant lissé par la courbe ; valeurs extrapolées ou plafonnées. Une calibration non convergée est signalée dans le journal, sur la ligne de calibration tant qu'une autre opération ne remplace pas ce texte, et par « NON CONVERGÉE » dans le titre de la fenêtre Courbe : refaire un test fin sur la zone, ou essayer une autre disquette.

Le profil obtenu remplace celui de la famille de l'image, standard 2 µs ou long track 1,89 µs, est enregistré dans la configuration et appliqué ensuite par le profil Auto à toute image de la même famille. Le journal détaille chaque passe. Les cylindres de test, deux faces, sont écrasés à chaque passe. Le bouton Arrêter interrompt la calibration sans modifier le profil. Le bouton « Effacer les calibrations », sur la même ligne, supprime après confirmation toutes les courbes, communes et par tête, des familles standard et long track, et remet les deux profils de famille à leurs valeurs d'origine ; il est refusé pendant une calibration ou une écriture. Le bouton « Courbe », à côté du profil de précompensation, affiche la courbe de la famille de l'image : mesures avec leur incertitude et leur origine, encadrée, extrapolée ou plafonnée, écarts à la courbe signalés, zone hachurée au-dessus de la plus forte précompensation mesurée, courbe retenue, profil `--precomp` et tableau des valeurs par cylindre avec le résidu de vérification, copiables. Elle s'ouvre aussi en fin de calibration lancée par « Calibrer » ; après une calibration automatique, l'écriture enchaîne et la courbe reste accessible par ce bouton. Elle est enregistrée dans la configuration.

## Écriture rapide et écriture lente depuis la bibliothèque

Dans l'onglet Bibliothèque, deux boutons écrivent l'image sélectionnée en appliquant tous les paramètres adaptés : image entière, profil de précompensation Auto, pré-effacement, effacement des pistes vides, vérification par gw, 10 retries. Les options de lecteur de l'onglet Écriture (flippy, densel, fake index, diskdefs, secteurs durs, TG43) sont conservées, ainsi que les éléments `step`, `h0.off`, `h1.off` et `hswap` du champ Pistes : ils décrivent le matériel. Les relectures de calibration reprennent les options flippy, densel et fake index.

| Bouton | Écriture | Contrôle | Calibration requise |
|---|---|---|---|
| Écriture rapide | Une commande, les deux têtes ensemble | Vérification gw seulement | Commune, pour la famille de l'image |
| Écriture lente | Tête 0 puis tête 1, chacune avec sa précompensation | Contrôle de toutes les pistes, 3 passes de réécriture | Par tête, pour la famille de l'image |

Si la calibration requise n'existe pas, si elle a été mesurée sur le contenu d'une image avant l'arrivée du motif de test, ou, en écriture lente, si les courbes par tête sont antérieures à une calibration commune, le lecteur est d'abord calibré automatiquement, après confirmation. La disquette insérée reçoit alors le motif de test, puis l'image. Refuser la calibration, ou une calibration interrompue ou sans mesure exploitable, annule l'écriture. Sont écrits directement, sans calibration automatique : un flux SCP ou RAW, une image haute densité, une image dont la densité n'est pas établie : toute image autre qu'un ADF, un IPF, un HFE ou une image secteur brute avec un format choisi non GCR, le bouton remettant le format des autres images (IMD, TD0, D88, D64, MSA, DSK CPC...) à `(auto)` ; un IPF ou un HFE dont la cellule sort de 1 700 à 2 300 ns, plage que la calibration sait mesurer (HFE converti d'une image C64, par exemple) ; toute image avec « Secteurs durs » ou « TG43 » cochés, et toute image si le module d'analyse SCP n'a pas pu être compilé. Un ADF haute densité, reconnu à sa taille, est écrit au format `amiga.amigados_hd`.

Une image secteur brute, IMG, IMA, ST ou DSK sans signature CPC, n'a pas de géométrie : gw exige son format. Le bouton refuse alors l'écriture, avant toute calibration, tant qu'aucun format n'a été choisi pour cette image : choisir le format dans l'onglet Écriture, où l'image est déjà sélectionnée, puis cliquer de nouveau sur le bouton. Le format n'est conservé que pour la même source : deux archives ZIP contenant un fichier de même nom ne partagent pas le format. Si le nombre de faces de l'image est inconnu (IMG, ST, IMD, D64, SCP...), « Effacer les pistes vides » est décoché : gw n'écrit alors que les pistes présentes dans l'image. Une image à une seule face (IPF, HFE ou ADF qui le déclarent) n'écrit que cette face : en écriture rapide, `h=0` ou `h=1` est placé dans le champ Pistes.

Les calibrations ne sont pas liées à un lecteur précis : aucun lecteur de disquette n'expose d'identifiant lisible. Après un changement de lecteur, relancer une calibration depuis l'onglet Écriture, avec « Écriture lente » cochée pour recalibrer chaque tête.

## Écriture lente et calibration par tête

La case « Écriture lente » de l'onglet Écriture sépare l'écriture par tête : toutes les pistes de la tête 0 d'abord, puis toutes celles de la tête 1, en deux commandes `gw write` successives. gw n'appliquant `--precomp` que par cylindre, c'est le seul moyen de donner à chaque tête sa propre précompensation. L'écriture est plus longue, le disque étant balayé deux fois.

- Le champ de précompensation devient celui de la tête 0, et un second champ, « Précomp. tête 1 », s'active. Un champ vide écrit la tête correspondante sans `--precomp`.
- Le champ « Pistes » est respecté : `c=0-9:h=1` n'écrit que la tête 1, les éléments `step`, `h0.off`, `h1.off` et `hswap` sont conservés. Avec `hswap`, chaque tête logique reçoit le profil de la tête physique qui l'écrit.
- Sans `h=` dans le champ « Pistes », les têtes écrites sont celles de l'image quand elle les déclare (IPF, HFE, ADF) : une image à une seule face n'écrit que la tête 0. Pour les autres images (IMG, ST, D64...), dont le nombre de faces dépend du format, l'écriture est refusée si « Effacer les pistes vides » est coché : gw effacerait toute la tête 1 d'un format simple face, par exemple la face B d'une disquette flippy. Indiquer alors `h=0-1` ou `h=0` dans « Pistes ». Le bouton « Écriture lente » de la bibliothèque décoche l'option dans ce cas.
- Le contrôle après écriture relit les pistes des deux commandes, et les réécritures de pistes faibles se font aussi tête par tête, chacune avec sa précompensation.
- Si la commande de la tête 0 échoue, par exemple sur une disquette protégée en écriture, celle de la tête 1 n'est pas lancée.

Lancée avec « Écriture lente » cochée, la calibration mesure chaque tête séparément. Les trois passes de mesure restent communes, la même valeur étant écrite sur les deux faces, mais le décalage est analysé face par face : pour chaque tête, une valeur interpolée et son incertitude par cylindre testé, puis une courbe. La passe d'encadrement, si elle a lieu, écrit chaque tête avec ses propres valeurs. La passe de vérification écrit la tête 0 puis la tête 1, chacune avec son profil, et corrige chaque courbe d'après sa propre mesure. Les deux courbes sont enregistrées pour la famille de l'image, sans toucher au profil commun, et le profil Auto les applique en écriture lente. Sans calibration par tête pour la famille, ou si une calibration commune plus récente a été faite, après un changement de lecteur par exemple, l'écriture lente utilise le profil commun pour les deux têtes. Quand « Écriture lente » est cochée et que les courbes par tête de la famille sont à jour, le bouton « Courbe » affiche les deux courbes, tête 0 en bleu et tête 1 en orange, avec le tableau des valeurs de chacune ; sinon, il affiche la courbe commune, s'il en existe une. Une tête illisible, comme sur une disquette simple face, ou une tête dont le décalage ne suit pas la précompensation écrite, signe d'une tête ou d'un circuit d'écriture défaillant, interrompt la calibration sans rien enregistrer. Le motif de test ayant toujours deux faces, une image simple face peut servir à calibrer les deux têtes.
## Fichiers créés à l'exécution

| Emplacement | Contenu |
|---|---|
| `GreaseweazleGUI.json` (à côté du script ou de l'exe) | Configuration : options saisies dans les onglets, état de la fenêtre, profils de précompensation standard et long track, courbes de calibration, communes et par tête, référence de l'onglet Qualité & alignement. Créé et mis à jour automatiquement. Le supprimer, application fermée, efface ces calibrations. |
| `%TEMP%\GreaseweazleGUI\` | Extractions ZIP, images intermédiaires de comparaison, flux `align.scp` (Qualité & alignement), `precomp-pattern.hfe` et `precomp-calib.scp` (calibration : motif de test et relecture) et `check-*.scp` (contrôle après écriture). Rien n'y est supprimé en fin d'opération. |
| `%LOCALAPPDATA%\GreaseweazleGUI\index-*.tsv` | Index de la bibliothèque, un fichier par racine indexée. |

## Compilation de l'exécutable

Prérequis : module [PS2EXE](https://www.powershellgallery.com/packages/ps2exe) sous Windows PowerShell 5.1. Lancé depuis PowerShell 7, le script se relance seul sous Windows PowerShell 5.1 avec `-ExecutionPolicy Bypass`, car PS2EXE exige cette édition pour compiler.

```powershell
Install-Module -Name ps2exe -Scope CurrentUser
```

```powershell
powershell -ExecutionPolicy Bypass -File .\Build-Exe.ps1
```

Le script lit la version dans `src/GreaseweazleGUI.ps1` (variable `$script:Version`), supprime l'exe précédent, compile `src/GreaseweazleGUI.ps1` avec l'icône `src/GreaseweazleGUI.ico`, écrit `dist/GreaseweazleGUI.exe` puis le signe (voir ci-dessous). Si PS2EXE ne produit rien, le script échoue au lieu de réutiliser un ancien exe. Le dossier `dist/` est ignoré par git.

### Signature

Règle du projet : tout exécutable livré est signé. `Build-Exe.ps1` signe l'exécutable avec le certificat de signature de code `CN=Greaseweazle Studio`, créé auto-signé à la première exécution dans les magasins utilisateur (`My`, `Root`, `TrustedPublisher`, sans droits administrateur) et horodaté chez DigiCert. `-Sign:$false` est le seul moyen de compiler sans signer, pour un test ou sur un poste où l'on ne veut pas créer de certificat.

Un certificat auto-signé n'est reconnu que sur les machines qui lui font confiance : ailleurs, la signature montre seulement que le fichier n'a pas été modifié depuis sa signature par ce certificat, sans prouver son auteur, puisque n'importe qui peut créer un certificat auto-signé au même nom, et SmartScreen avertit quand même. Sur un poste d'entreprise managé, déclarer de confiance un certificat auto-signé contourne sa politique de sécurité : compilez-y avec `-Sign:$false` ou faites signer avec le certificat interne.

## Publication d'une version

Le workflow GitHub Actions [release.yml](.github/workflows/release.yml) compile l'exécutable sur un runner Windows et l'attache à une release GitHub à chaque tag `vX.Y`.

1. Mettre à jour `$script:Version` dans `src/GreaseweazleGUI.ps1` et le [CHANGELOG](CHANGELOG.md).
2. Commit, puis tag et push :

   ```powershell
   git tag v11.8
   git push origin main --tags
   ```

3. Le workflow vérifie que le tag correspond à `$script:Version`, compile, puis attache `GreaseweazleGUI.exe` et `GreaseweazleGUI.ps1` à la release. Tant que le dépôt n'a pas les secrets de signature décrits ci-dessous, cet exe n'est pas signé : le remplacer par l'exe signé compilé localement avec `Build-Exe.ps1` depuis le même commit, par exemple `gh release upload v11.8 dist\GreaseweazleGUI.exe --clobber`.

Le workflow signe l'exécutable avec le même certificat si deux secrets existent dans le dépôt, sinon il le publie non signé et le dit dans son journal. Pour les créer, sur le PC qui possède le certificat, exporter la clé privée en PFX puis l'encoder en base64 :

```powershell
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object Subject -eq 'CN=Greaseweazle Studio' | Sort-Object NotAfter -Descending | Select-Object -First 1
$pwd = Read-Host -AsSecureString 'Mot de passe du PFX'
Export-PfxCertificate -Cert $cert -FilePath .\codesign.pfx -Password $pwd | Out-Null
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path .\codesign.pfx).ProviderPath)) | Set-Clipboard
```

Dans GitHub, Settings, Secrets and variables, Actions : créer `CODESIGN_PFX_BASE64` avec le contenu du presse-papiers et `CODESIGN_PFX_PASSWORD` avec le mot de passe choisi, puis supprimer le fichier `codesign.pfx` local. La clé privée est alors stockée chiffrée chez GitHub et n'apparaît pas dans l'interface, mais tout workflow du dépôt peut lire ces secrets : toute personne disposant d'un accès en écriture au dépôt y a donc accès.

## Structure du dépôt

```
.
├── .github/workflows/release.yml   Compilation et release à chaque tag vX.Y
├── src/
│   ├── GreaseweazleGUI.ps1         Application (script unique)
│   └── GreaseweazleGUI.ico         Icône de l'exécutable
├── dist/                           Sortie de Build-Exe.ps1 (ignoré par git)
├── Build-Exe.ps1                   Compilation PS2EXE et signature auto-signée
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## Licence

Code sous licence MIT, voir [LICENSE](LICENSE).

L'exécutable `GreaseweazleGUI.exe` embarque le moteur d'exécution de [PS2EXE](https://github.com/MScholtes/PS2EXE), d'Ingo Karstein et Markus Scholtes, distribué sous Microsoft Limited Public License 1.1. Cette licence limite l'usage de ce moteur à Windows et exige de conserver ses mentions d'attribution. Le script `.ps1` ne contient pas de code de PS2EXE.

Greaseweazle est un projet de Keir Fraser ; ses host tools sont placés dans le domaine public sous [Unlicense](https://unlicense.org/) (fichier COPYING du dépôt [keirf/greaseweazle](https://github.com/keirf/greaseweazle)). Ce projet n'est pas affilié à Greaseweazle.
