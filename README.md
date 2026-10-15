# Greaseweazle Studio

Greaseweazle Studio est une application Windows dédiée aux disquettes. Elle pilote une carte [Greaseweazle](https://github.com/keirf/greaseweazle), de Keir Fraser, branchée en USB au PC et reliée à un lecteur de disquette. Elle permet de sauvegarder une disquette dans un fichier, d'écrire une image (un jeu Amiga en ADF, par exemple) sur une disquette, de restaurer une disquette d'origine sur une disquette vierge, et de vérifier l'état d'une disquette ou d'un lecteur. Elle a été conçue en priorité pour la préservation des disquettes Amiga.

Aucune connaissance des commandes de la carte n'est nécessaire : l'application les construit, règle les options et contrôle le résultat. Chaque commande lancée reste visible dans le journal, en bas de la fenêtre.

Sur le plan technique, il s'agit d'une interface graphique PowerShell / WinForms pour les Greaseweazle host tools : elle pilote `gw.exe`. Elle tient dans un seul script, `GreaseweazleGUI.ps1`, sans dépendance externe, et elle est aussi livrée sous forme d'exécutable `GreaseweazleGUI.exe` compilé avec PS2EXE.

La documentation complète, pour débuter comme pour approfondir, se trouve dans le [wiki](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki).

## Matériel et logiciels nécessaires

- Un PC sous Windows 10 ou 11.
- Une carte Greaseweazle, branchée en USB.
- Un lecteur de disquette relié à la carte par une nappe : une nappe de PC avec torsade (twist), ou une nappe droite, typique d'un lecteur Amiga. Ce détail sert à choisir le lecteur dans l'application.
- Les Greaseweazle host tools : le programme `gw.exe`, dans l'archive Windows d'une [release Greaseweazle](https://github.com/keirf/greaseweazle/releases). L'application est développée et testée avec la version 1.23 ; la liste des formats d'images reconnus est alignée sur `gw write --help` de cette version.
- Des disquettes : celles à sauvegarder ou à restaurer, et des disquettes vierges ou sans valeur pour l'écriture. Une écriture remplace tout le contenu de la disquette. Prévoyez aussi, de préférence, une disquette sacrifiée pour la calibration : une disquette sans valeur que vous acceptez d'user, jamais un original (voir « Bon à savoir »).

Prérequis techniques, déjà présents dans Windows : Windows PowerShell 5.1 et .NET Framework 4.x. Le script fonctionne aussi sous PowerShell 7, à installer séparément ; l'exécutable s'appuie sur Windows PowerShell 5.1. .NET Framework fournit WinForms et compile à la volée les helpers C# : comparaison rapide, analyse de flux SCP, index de la bibliothèque. Chaque helper est compilé séparément. Si la comparaison ou l'index ne compile pas, la fonction passe par un chemin PowerShell plus lent, et la recherche dans la bibliothèque se fait sans index. L'analyse de flux SCP n'a pas d'équivalent PowerShell : sans elle, la restauration, la mesure de l'onglet « Qualité & alignement » et la calibration de la précompensation sont refusées, le contrôle après écriture est ignoré, le profil Auto traite tout flux SCP comme une image standard 2 µs, et les boutons « Écriture rapide » et « Écriture lente » écrivent sans calibration automatique, avec le profil courant.

## Installation en 3 étapes

1. Téléchargez l'archive Windows des Greaseweazle host tools depuis leurs [releases](https://github.com/keirf/greaseweazle/releases) et extrayez-la, par exemple dans `C:\greaseweazle-1.23\`.
2. Copiez dans ce même dossier, à côté de `gw.exe`, au choix :
   - `GreaseweazleGUI.exe`, depuis la page [Releases](https://github.com/Bartozorus/GreaseweazleGUI_Studio/releases) de ce dépôt ;
   - ou le script `src/GreaseweazleGUI.ps1`, lisible et fonctionnellement identique.
3. Lancez l'application : double-clic sur `GreaseweazleGUI.exe`, ou, pour le script :

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\GreaseweazleGUI.ps1
   ```

Vérifiez ensuite le bandeau bleu, en haut à droite. « gw.exe prêt », en vert, signifie que l'application a trouvé `gw.exe`. « gw.exe introuvable », en rouge, signifie qu'elle n'est pas dans le dossier de `gw.exe` : le journal le signale aussi au démarrage. `gw.exe` est cherché dans le dossier de l'exécutable ou du script, quel que soit le dossier courant, y compris sur un partage réseau (chemin UNC).

La langue de l'interface suit la langue d'affichage de Windows : français si elle est française, anglais pour toute autre langue. Pour forcer le choix, ajoutez `-Language fr` ou `-Language en`, avec l'exécutable comme avec le script :

```powershell
.\GreaseweazleGUI.exe -Language en
```

La procédure détaillée, branchement compris, figure sur la page [Installation](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Installation) du wiki.

### Avertissements SmartScreen et antivirus

L'exécutable est produit par PS2EXE, qui embarque le script dans un hôte .NET. Ce type de binaire déclenche souvent SmartScreen et des faux positifs antivirus. L'exécutable publié dans les releases est signé avec le certificat auto-signé du projet, `CN=Greaseweazle Studio`, et non par une autorité reconnue : la signature atteste que le fichier n'a pas été modifié, mais elle n'est pas reconnue sur un poste tiers et SmartScreen avertit quand même. En cas de doute, utilisez directement le script `.ps1`, lisible et fonctionnellement identique.

## Premiers pas

Le guide complet, avec deux exemples de bout en bout, figure sur la page [Premiers pas](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Premiers-pas) du wiki. En résumé :

1. Au lancement, l'onglet « Accueil » demande « Que veux-tu faire ? ». Cliquez d'abord sur la carte « Tester le Greaseweazle » : elle lance `gw info`. Dans le journal, sous `Device:`, les lignes `Port:` et `Model:` indiquent le port et le modèle de votre carte. `Not found` à la place signifie que la carte n'est pas détectée.
2. Dans le bandeau, choisissez le réglage « Lecteur : ». « A » ou « B » pour un lecteur sur une nappe de PC avec torsade ; « 0 », « 1 » ou « 2 » pour une nappe droite, comme sur un lecteur Amiga. Laissez « COM : » vide : le texte gris « auto » indique que la carte est détectée automatiquement.
3. Revenez à l'onglet « Accueil » et cliquez sur la carte correspondant à votre tâche : « Restaurer une disquette », « Écrire une image sur une disquette », « Sauvegarder une disquette » ou « Vérifier une disquette ou un lecteur ». L'application ouvre l'onglet adapté.
4. En cas de doute, appuyez sur F1 ou cliquez sur « Aide » dans le bandeau : la page du wiki de l'onglet affiché s'ouvre dans votre navigateur. Placez aussi le pointeur de la souris sur un réglage : son infobulle reste affichée 30 secondes.

Pour aller plus loin :

- [Premiers pas](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Premiers-pas) : premier lancement, écrire un jeu Amiga sur une disquette, sauvegarder une disquette.
- [Restaurer une disquette](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Restaurer-une-disquette) : copier une disquette d'origine sur une disquette vierge, étape par étape.
- [Écriture](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/%C3%89criture) : écrire une image et comprendre les options.
- [Dépannage](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/D%C3%A9pannage) : que faire en cas de problème.

## Ce que fait l'application

- **Accueil** : le premier onglet. Six cartes cliquables : « Restaurer une disquette », « Écrire une image sur une disquette » (ouvre « Bibliothèque »), « Sauvegarder une disquette » (ouvre « Lecture / Dump »), « Vérifier une disquette ou un lecteur » (ouvre « Qualité & alignement »), « Tester le Greaseweazle » (lance `gw info`, avec `--device` si un port COM est saisi) et « Guide pas à pas » (ouvre la page Premiers pas du wiki).
- **Restauration** : copie une disquette d'origine sur une disquette vierge, avec un ou deux lecteurs, en huit étapes affichées : lecture et vérification de l'original, changement de disquette, contrôle que la disquette insérée n'est pas l'original, calibration du lecteur si nécessaire (une calibration existante est conservée, jamais refaite ; sans calibration, chaque tête est calibrée), écriture tête 0 puis tête 1, contrôle de toutes les pistes, comparaison avec l'original. Deux modes : avec un format (Amiga, Atari ST, PC), chaque secteur est lu, vérifié et comparé, et la restauration s'arrête avant toute écriture si un seul secteur de l'original est illisible ; « Copie exacte du flux », pour une disquette protégée contre la copie ou d'un format inconnu. L'original lu, la copie relue (avec un format) et un rapport sont enregistrés.
- **Bibliothèque** : arborescence d'images disque, archives ZIP lues à la volée, index persistant construit en arrière-plan avec recherche instantanée, ouverture des documents associés (txt, pdf, jpg, png, gif, nfo, md) dans l'application par défaut. Les boutons « Écriture rapide » et « Écriture lente » écrivent l'image sélectionnée avec les réglages adaptés, après une calibration automatique si nécessaire, annoncée par un avertissement (voir « Bon à savoir »).
- **Écriture** : profil de précompensation choisi d'après l'image (IPF et HFE : bits par piste, HFE v3 : débit ; SCP : flux), calibration de la précompensation propre à votre lecteur, commune aux deux têtes ou par tête, écriture lente tête 0 puis tête 1, contrôle de toutes les pistes après écriture avec réécriture automatique des pistes faibles.
- **Lecture / Dump** : sauvegarde d'une disquette dans un fichier, SCP pour archiver, ADF pour un émulateur.
- **Qualité & alignement** : mesure continue de la qualité de lecture piste par piste (cellule mesurée, jitter, asymétrie, trous de signal) sur une disquette pressée, pour régler l'alignement d'un lecteur.
- **Mode expert** : case du bandeau. Décochée, seuls les six onglets du quotidien sont affichés : Accueil, Restauration, Bibliothèque, Écriture, Lecture / Dump, Qualité & alignement. Cochée, s'y ajoutent Conversion, Comparaison (conversion de la référence, lecture de la disquette, puis comparaison secteur par secteur), Outils et Délais (erase, clean, seek, rpm, bandwidth, pin, reset, update, delays), et Commande libre, qui lance n'importe quelle ligne de commande `gw`. Une première installation démarre sans le mode expert ; une configuration d'une version précédente l'active, pour ne rien changer aux habitudes. Une fonction qui nécessite un onglet masqué l'active automatiquement. Les 13 actions de `gw` sont couvertes : `info`, `read`, `write`, `convert`, `erase`, `clean`, `seek`, `delays`, `update`, `pin`, `reset`, `bandwidth`, `rpm`.
- **Aide F1** : la touche F1 et le bouton « Aide » du bandeau ouvrent la page du wiki de l'onglet affiché.
- Textes indicatifs gris dans les champs vides, infobulles affichées 30 secondes, journal repliable avec coloration, barre de progression, fenêtre entièrement redimensionnable, interface en français ou en anglais.

## Bon à savoir

- **Calibrations et lecteur.** Les calibrations ne sont pas liées à un lecteur physique : la courbe retient la lettre du lecteur (A, B, 0, 1 ou 2), mais aucun lecteur de disquette n'expose d'identifiant lisible. Après un changement de lecteur, relancez une calibration depuis l'onglet « Écriture », avec « Écriture lente » cochée pour recalibrer chaque tête. La restauration ne le fait pas pour vous : elle ne refait jamais une calibration existante. Elle utilise les courbes par tête si elles sont à jour, sinon la courbe commune aux deux têtes, et ne calibre le lecteur, tête par tête, que s'il n'a aucune calibration pour ce type d'image. Une calibration mesurée sous une autre lettre de lecteur, non convergée ou mesurée sur le contenu d'une image est seulement signalée : étape « Calibrer le lecteur si nécessaire » en orange, remarque dans le journal et dans le rapport.
- **Avertissement avant chaque calibration.** La calibration écrit un motif de test plusieurs fois sur les mêmes pistes, ce qui fatigue le support. Chaque calibration (bouton « Calibrer » de l'onglet « Écriture », « Écriture rapide » ou « Écriture lente » de la Bibliothèque quand une calibration manque ou doit être refaite, restauration sans calibration existante) commence donc par la fenêtre « Calibration precomp », qui le rappelle. Pour une calibration seule, insérez de préférence une disquette sacrifiée. Avant une écriture, pour épargner la disquette à écrire, cochez « J'ai inséré une disquette sacrifiée : me redemander la disquette à écrire après la calibration » (pendant une restauration : « ... la disquette de destination ... »), remplacez-la par une disquette sacrifiée, puis cliquez sur « Lancer la calibration » (touche Entrée) : l'application vous redemande la bonne disquette une fois la calibration terminée (pendant une restauration, la disquette de destination est de nouveau vérifiée avant l'écriture). Elle ne vérifie pas la disquette sacrifiée : n'utilisez jamais l'original comme disquette sacrifiée. Sans réponse, la calibration démarre d'elle-même au bout de 120 secondes sur la disquette insérée (« Sans réponse, la calibration démarre automatiquement dans 120 s. »), pour qu'une opération lancée avant une absence ne reste pas bloquée ; le journal l'indique alors (« Calibration : avertissement validé automatiquement après 120 s sans réponse. »). Cocher ou décocher la case arrête ce compte à rebours. « Annuler » (touche Échap ou croix de la fenêtre) ne lance pas la calibration et l'image n'est pas écrite (« Écriture annulée : la calibration n'a pas été lancée. ») ; une restauration s'arrête alors en échec à l'étape « Calibrer le lecteur si nécessaire ».
- **Format d'une image secteur brute.** Une image IMG, IMA, ST ou DSK sans signature CPC n'a pas de géométrie : gw exige son format. « Écriture rapide » et « Écriture lente » la refusent, avant toute calibration, tant qu'aucun format n'a été choisi pour elle dans l'onglet « Écriture ». Ce format n'est conservé que pour la même source, fichier ou archive et entrée : deux archives ZIP contenant un fichier de même nom ne le partagent pas.
- Le détail technique de la calibration, de l'écriture lente, du contrôle après écriture et des formats pris en charge est dans le wiki : [Précompensation et calibration](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Pr%C3%A9compensation-et-calibration), [Écriture lente](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/%C3%89criture-lente), [Contrôle après écriture](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Contr%C3%B4le-apr%C3%A8s-%C3%A9criture), [Formats et limites](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Formats-et-limites), [Configuration et fichiers](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Configuration-et-fichiers).

### Fichiers créés à l'exécution

| Emplacement | Contenu |
|---|---|
| `GreaseweazleGUI.json` (à côté du script ou de l'exe) | Configuration : options saisies dans les onglets, mode expert, réglages de la restauration, état de la fenêtre, profils de précompensation standard et long track, courbes de calibration, communes et par tête, référence de l'onglet « Qualité & alignement ». Créé et mis à jour automatiquement. Le supprimer, application fermée, efface ces calibrations. |
| `%TEMP%\GreaseweazleGUI\` | Extractions ZIP, images intermédiaires de comparaison, flux `align.scp` (Qualité & alignement), `precomp-pattern.hfe` et `precomp-calib.scp` (calibration : motif de test et relecture), `check-*.scp` (contrôle après écriture) et `restore-probe-*` (restauration : lecture du cylindre 0 de la disquette de destination). Rien n'y est supprimé en fin d'opération. |
| `%LOCALAPPDATA%\GreaseweazleGUI\index-*.tsv` | Index de la bibliothèque, un fichier par racine indexée. |
| `Documents\Greaseweazle Studio\Restaurations\` (dossier par défaut de l'onglet « Restauration ») | `<nom> - original`, `<nom> - copie relue` (avec un format) et `<nom> - rapport.txt`. Rien n'est écrasé : un suffixe « (2) », « (3) »... est ajouté si le nom existe déjà. |

## Compilation de l'exécutable

Prérequis : module [PS2EXE](https://www.powershellgallery.com/packages/ps2exe) sous Windows PowerShell 5.1. Lancé depuis PowerShell 7, le script se relance automatiquement sous Windows PowerShell 5.1 avec `-ExecutionPolicy Bypass`, car PS2EXE exige cette édition pour compiler.

```powershell
Install-Module -Name ps2exe -Scope CurrentUser
```

```powershell
powershell -ExecutionPolicy Bypass -File .\Build-Exe.ps1
```

Le script lit la version dans `src/GreaseweazleGUI.ps1` (variable `$script:Version`), supprime l'exe précédent, compile `src/GreaseweazleGUI.ps1` avec l'icône `src/GreaseweazleGUI.ico`, écrit `dist/GreaseweazleGUI.exe` puis le signe (voir ci-dessous). Si PS2EXE ne produit rien, le script échoue au lieu de réutiliser un ancien exe. Le dossier `dist/` est ignoré par git.

### Signature

Règle du projet : tout exécutable livré est signé. `Build-Exe.ps1` signe l'exécutable avec le certificat de signature de code `CN=Greaseweazle Studio`, créé auto-signé à la première exécution dans les magasins utilisateur (`My`, `Root`, `TrustedPublisher`, sans droits administrateur) et horodaté chez DigiCert. `-Sign:$false` est le seul moyen de compiler sans signer, pour un test ou sur un poste où l'on ne veut pas créer de certificat.

Un certificat auto-signé n'est reconnu que sur les machines qui lui font confiance. Ailleurs, la signature montre seulement que le fichier n'a pas été modifié depuis sa signature par ce certificat, sans prouver son auteur, puisque n'importe qui peut créer un certificat auto-signé au même nom, et SmartScreen avertit quand même. Sur un poste d'entreprise géré, déclarer de confiance un certificat auto-signé contourne sa politique de sécurité : compilez-y avec `-Sign:$false` ou faites signer l'exécutable avec le certificat interne.

## Publication d'une version

Le workflow GitHub Actions [release.yml](.github/workflows/release.yml) compile l'exécutable sur un runner Windows et l'attache à une release GitHub à chaque tag `vX.Y`, avec pour notes la section correspondante du CHANGELOG.

1. Mettre à jour `$script:Version` dans `src/GreaseweazleGUI.ps1` et le [CHANGELOG](CHANGELOG.md).
2. Commit, puis tag et push :

   ```powershell
   git tag v11.8
   git push origin main --tags
   ```

3. Le workflow vérifie que le tag correspond à `$script:Version`, compile, puis attache `GreaseweazleGUI.exe` et `GreaseweazleGUI.ps1` à la release. Tant que le dépôt n'a pas les secrets de signature décrits ci-dessous, cet exe n'est pas signé : le remplacer par l'exe signé compilé localement avec `Build-Exe.ps1` depuis le même commit, par exemple `gh release upload v11.8 dist\GreaseweazleGUI.exe --clobber`.

Un lancement manuel du workflow (workflow_dispatch) régénère les notes d'une release existante depuis le CHANGELOG, sans toucher aux fichiers attachés.

Le workflow signe l'exécutable avec le même certificat si deux secrets existent dans le dépôt, sinon il le publie non signé et le dit dans son journal. Pour les créer, sur le PC qui possède le certificat, exporter la clé privée en PFX puis l'encoder en base64 :

```powershell
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object Subject -eq 'CN=Greaseweazle Studio' | Sort-Object NotAfter -Descending | Select-Object -First 1
$pwd = Read-Host -AsSecureString 'Mot de passe du PFX'
Export-PfxCertificate -Cert $cert -FilePath .\codesign.pfx -Password $pwd | Out-Null
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path .\codesign.pfx).ProviderPath)) | Set-Clipboard
```

Dans GitHub, Settings, Secrets and variables, Actions : créer `CODESIGN_PFX_BASE64` avec le contenu du presse-papiers et `CODESIGN_PFX_PASSWORD` avec le mot de passe choisi, puis supprimer le fichier `codesign.pfx` local. La clé privée est alors stockée chiffrée chez GitHub et n'apparaît pas dans l'interface, mais tout workflow du dépôt peut lire ces secrets : toute personne disposant d'un accès en écriture au dépôt y a donc accès.

La page [Compilation et publication](https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/Compilation-et-publication) du wiki reprend ces procédures.

## Structure du dépôt

```
.
├── .github/workflows/release.yml   Compilation et release à chaque tag vX.Y
├── src/
│   ├── GreaseweazleGUI.ps1         Application (script unique)
│   └── GreaseweazleGUI.ico         Icône de l'exécutable
├── dist/                           Sortie de Build-Exe.ps1 (ignoré par git)
├── .editorconfig, .gitattributes   Encodage et fins de ligne (CRLF pour .ps1, LF pour .md)
├── Build-Exe.ps1                   Compilation PS2EXE et signature auto-signée
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## Remerciements

Merci à Keir Fraser pour [Greaseweazle](https://github.com/keirf/greaseweazle) et ses host tools : sans eux, cette application n'existerait pas.

Le code de Greaseweazle Studio a été entièrement écrit par **Claude**, l'assistant d'intelligence artificielle d'[Anthropic](https://www.anthropic.com/), utilisé avec Claude Code : l'application, ses scripts de compilation et de publication, et sa documentation. Bartozorus a défini les besoins, dirigé chaque évolution, testé l'application sur son matériel et décidé de ce qui était publié. Le mérite de l'écriture du code revient à Claude, qui en a été l'exécutant.

Merci, Claude.

## Licence

Code sous licence MIT, voir [LICENSE](LICENSE).

L'exécutable `GreaseweazleGUI.exe` embarque le moteur d'exécution de [PS2EXE](https://github.com/MScholtes/PS2EXE), d'Ingo Karstein et Markus Scholtes, distribué sous Microsoft Limited Public License 1.1. Cette licence limite l'usage de ce moteur à Windows et exige de conserver ses mentions d'attribution. Le script `.ps1` ne contient pas de code de PS2EXE.

Greaseweazle est un projet de Keir Fraser ; ses host tools sont placés dans le domaine public sous [Unlicense](https://unlicense.org/) (fichier COPYING du dépôt [keirf/greaseweazle](https://github.com/keirf/greaseweazle)). Ce projet n'est pas affilié à Greaseweazle.
