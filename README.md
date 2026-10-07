# Greaseweazle Studio

Interface graphique Windows (PowerShell / WinForms) pour les [Greaseweazle host tools](https://github.com/keirf/greaseweazle) de Keir Fraser. Elle pilote `gw.exe` pour lire, écrire, convertir et contrôler des disquettes, avec un accent sur la préservation de disquettes Amiga.

L'application tient dans un seul script, `GreaseweazleGUI.ps1`, sans dépendance externe. Elle est aussi livrée sous forme d'exécutable `GreaseweazleGUI.exe` compilé avec PS2EXE.

## Fonctionnalités

- Les 13 actions de `gw` : `info`, `read`, `write`, `convert`, `erase`, `clean`, `seek`, `delays`, `update`, `pin`, `reset`, `bandwidth`, `rpm`.
- **Bibliothèque** : arborescence d'images disque, archives ZIP parsées à la volée, index persistant construit en arrière-plan avec recherche instantanée, ouverture des documents associés (txt, pdf, jpg, png, gif, nfo, md) dans l'application par défaut.
- **Écriture** : choix de l'image, profil de précompensation détecté automatiquement d'après l'image (IPF : bits par piste, SCP : flux, HFE : débit), options courantes et avancées, contrôle après écriture.
- **Calibration de la précompensation** : mesure automatique du meilleur `--precomp` pour le lecteur d'écriture, voir ci-dessous.
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
- .NET Framework 4.x (inclus dans Windows) : WinForms et compilation à la volée des helpers C# (comparaison rapide, analyse de flux SCP, index de bibliothèque). Si cette compilation échoue, l'application bascule sur des chemins PowerShell plus lents.
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

L'exécutable est produit par PS2EXE, qui embarque le script dans un hôte .NET. Ce type de binaire déclenche fréquemment SmartScreen et des faux positifs antivirus. L'exécutable publié dans les releases n'est pas signé par une autorité reconnue. En cas de doute, utilisez directement le script `.ps1`, lisible et fonctionnellement identique.

## Calibration de la précompensation

Dans l'onglet Écriture, la ligne « Calibration précomp » détermine le profil `--precomp` adapté au lecteur d'écriture, sans réglage manuel :

1. Choisir l'image à écrire : ses pistes servent de motif de test et son nombre de cylindres est lu dans le fichier (taille d'un ADF, enregistrements d'un IPF, en-tête d'un HFE ; 80 à défaut). Il faut une image à bits ou secteurs (ADF, IPF, HFE, IMG...), car gw n'applique pas la précompensation aux flux SCP ou RAW.
2. Choisir le test : « standard » écrit un cylindre sur dix plus le dernier, en quelques minutes ; « fin » écrit tous les cylindres, pour un profil précis, en une heure environ.
3. Insérer une disquette vierge ou sans valeur dans le lecteur sélectionné, cliquer « Calibrer » et confirmer. Chaque passe écrit les cylindres de test avec une même valeur de précompensation, en une seule commande, puis les relit en flux sur trois tours. Le score d'un cylindre combine le jitter des intervalles courts, l'asymétrie des classes d'intervalles et les intervalles hors classe : plus il est bas, mieux les transitions sont placées.
4. Passes de 0 à 250 ns par pas de 50, puis passes fines par pas de 10 autour des meilleures valeurs. La meilleure valeur de chaque cylindre est retenue, la courbe est lissée en croissante, arrondie à 10 ns et convertie en seuils `c=ns`.

Le profil obtenu remplace celui de la famille de l'image, standard 2 µs ou long track 1,89 µs, est enregistré dans la configuration et appliqué ensuite par le profil Auto à toute image de la même famille. Le journal détaille chaque passe. Les cylindres de test, deux faces, sont écrasés à chaque passe. Le bouton Arrêter interrompt la calibration sans modifier le profil.

## Fichiers créés à l'exécution

| Emplacement | Contenu |
|---|---|
| `GreaseweazleGUI.json` (à côté du script ou de l'exe) | Configuration : options saisies dans les onglets, état de la fenêtre. Créé et mis à jour automatiquement. |
| `%TEMP%\GreaseweazleGUI\` | Extractions ZIP, images intermédiaires de comparaison, flux `align.scp`. |
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

### Signature (par défaut sur un PC personnel)

Par défaut, `Build-Exe.ps1` signe l'exécutable avec un certificat auto-signé `CN=Greaseweazle Studio`, créé à la première exécution dans les magasins utilisateur (`My`, `Root`, `TrustedPublisher`, sans droits administrateur) et horodaté chez DigiCert. `-Sign:$false` désactive la signature.

Cette signature n'est de confiance que sur la machine qui a créé le certificat. Sur un poste joint à un domaine Active Directory ou à Entra ID, le script ne signe pas, sauf si `-Sign` est passé explicitement : déclarer de confiance un certificat auto-signé sur un poste d'entreprise contourne sa politique de sécurité. Demandez plutôt une signature avec le certificat interne à votre équipe sécurité.

## Publication d'une version

Le workflow GitHub Actions [release.yml](.github/workflows/release.yml) compile l'exécutable sur un runner Windows et l'attache à une release GitHub à chaque tag `vX.Y`.

1. Mettre à jour `$script:Version` dans `src/GreaseweazleGUI.ps1` et le [CHANGELOG](CHANGELOG.md).
2. Commit, puis tag et push :

   ```powershell
   git tag v11.6
   git push origin main --tags
   ```

3. Le workflow vérifie que le tag correspond à `$script:Version`, compile, puis attache `GreaseweazleGUI.exe` et `GreaseweazleGUI.ps1` à la release.

L'exécutable produit en CI n'est pas signé : le workflow appelle `Build-Exe.ps1 -Sign:$false`.

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

Greaseweazle est un projet de Keir Fraser ; ses host tools sont placés dans le domaine public sous [Unlicense](https://unlicense.org/) (fichier COPYING du dépôt [keirf/greaseweazle](https://github.com/keirf/greaseweazle)). Ce projet n'est pas affilié à Greaseweazle.
