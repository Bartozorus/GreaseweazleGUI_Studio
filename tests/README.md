# Tests hors ligne

Contrôles de la source et tests logiques de Greaseweazle Studio. Ils ne demandent ni Greaseweazle, ni `gw.exe`, ni lecteur, et n'ouvrent aucune fenêtre : les tests chargent les fonctions réelles des modules de `src/modules/`, extraites par l'arbre syntaxique, et remplacent le reste (gw, fenêtres, configuration) par des bouchons. Les contrôles WinForms qu'ils créent ne sont jamais affichés.

## Lancer

```powershell
pwsh -NoProfile -File tests\Run-Tests.ps1
```

Le lanceur enchaîne, un processus par étape, avec l'édition de PowerShell qui l'exécute (PowerShell 7 ou Windows PowerShell 5.1) :

1. `tools\Assemble-Source.ps1 -Check` : le fichier assemblé et sa table correspondent aux modules ;
2. `tests\check-source.ps1` : contrôles de la source, sans rien exécuter (tableau ci-dessous) ;
3. chaque `tests\logic-*.ps1`, par ordre de nom.

| Paramètre | Effet |
|---|---|
| `-Filter 'calib-*'` | Ne lance que les tests dont le nom, sans le préfixe `logic-`, correspond (jokers admis) |
| `-NoChecks` | Saute les étapes 1 et 2 |
| `-Wiki <dossier>` | Copie locale du wiki : active les cas qui contrôlent ses pages, sautés sans elle |
| `-Root <dépôt>` | Teste la source d'un autre dossier de travail avec les tests de celui-ci |
| `-Out <dossier>` | Dossier des sorties (par défaut `tests\out`, ignoré par git) |
| `-Ci` | Active les cas réservés à l'intégration continue (compilation des blocs C#, marque d'alerte) |

Une étape réussit si son code de sortie est 0 et, pour un test, si sa dernière ligne `=== bilan <nom> : N conformes sur M` compte autant de cas conformes que de cas. Un code 0 sans ligne de bilan est un échec (« bilan absent »). Les lignes qui contiennent « saute » (cas sautés faute de wiki, de données ou hors intégration continue) sont comptées et affichées. Le lanceur rend 0 si tout est conforme, 1 sinon, et 9 si une sortie contient la marque d'alerte des outils du poste de développement (arrêt immédiat).

Sorties : `tests\out\<étape>.txt`, `tests\out\tests.log` (les lignes affichées) et un dossier de travail par test, `tests\out\<test>\` (fonctions extraites, images factices de quelques octets, rapports).

## Contrôles de la source (`check-source.ps1`)

| Cas | Contrôle |
|---|---|
| E1 | Modules, fichier assemblé, outils, `Build-Exe.ps1`, tests : UTF-8 avec un seul BOM, fins de ligne CRLF |
| E2 | `CHANGELOG.md`, `README.md`, `src/modules/README.md`, `tests/README.md`, workflows : LF, sans BOM |
| S1 | Analyse syntaxique sans erreur par l'édition qui exécute le contrôle |
| S2 | Aucun jeton propre à PowerShell 7 (ternaire, `??`, `?.`, `&&`, `\|\|`) |
| S3 | Modules et tests : ni évaluation de texte, ni commande encodée, ni ou exclusif binaire |
| F1 | Aucune fonction définie deux fois dans les modules |
| A1 | Blocs `Add-Type` qui compilent : empreintes égales à `tests/add-type.txt` |
| I1 | Clés `T()` littérales sans traduction anglaise : au plus `-MaxI18nMissing` |
| P1 | Tests et workflows : aucun chemin du poste de développement, aucune adresse de réseau privé ni de messagerie |

Modifier un bloc C# impose de mettre `tests/add-type.txt` à jour dans le même commit : le cas A1 affiche l'empreinte attendue.

## Écrire un test

Un test est un script `tests\logic-<thème>.ps1`, en UTF-8 avec BOM et CRLF comme les modules (sans BOM, Windows PowerShell 5.1 lit mal les caractères accentués). Il commence par l'en-tête commun :

```powershell
param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
```

- `$Wt` est la racine du dépôt testé et `$here` le dossier de travail du test : tout fichier créé va sous `$here`, jamais à côté des tests. `$Wt`, `$Wiki`, `$Work` et `$Ci` sont des paramètres typés : ne pas s'en servir comme variables locales.
- `commun.ps1` fixe la culture fr-FR (`Set-TestCulture`) et fournit `Import-TestWinForms`, qui charge WinForms sans `Add-Type` sous les deux éditions. `cal2-commun.ps1` est le harnais des tests de calibration (extraction des fonctions, tirages à graine fixe, besoins simulés).
- Chaque cas passe par `Chk <id> <condition> <description>`, qui affiche `conforme` ou `NON CONFORME`. Le test finit par la ligne `=== bilan <nom> : N conformes sur M` et par `exit 1` si un cas n'est pas conforme. Un cas sauté s'annonce par une ligne qui contient « saute ».
- Données synthétiques seulement : aucune lecture réelle, aucun journal, aucune configuration d'utilisateur, aucun chemin de poste (cas P1). Un test qui accepte des données réelles les reçoit par un paramètre facultatif, vide par défaut.
- Les deux éditions doivent convenir : pas de syntaxe propre à PowerShell 7 (cas S2), lectures et écritures de fichiers par `[System.IO.File]` avec un codage explicite, format explicite pour tout nombre comparé, aucune comparaison du texte d'une exception du système.
- Un changement de code qui casse un test l'adapte dans le même commit.

## Tests et noms d'origine

Vingt tests viennent de la campagne hors dépôt des versions 12.9 et 12.10 ; leur ligne de bilan garde ce nom d'origine.

| Test | Nom d'origine | Vérifie |
|---|---|---|
| `logic-barre-etat-restauration` | `logic-1210-rc11` | Barre d'état de la restauration, échec du lancement de gw |
| `logic-calib-bout-en-bout` | `logic-129-cal2-e2e` | Calibration simulée de bout en bout, graine fixe (scénario HD avec `-Base` seulement) |
| `logic-calib-croisee` | `logic-1210-cross-k` | Calibration croisée simulée de bout en bout |
| `logic-calib-niveaux-asymetrie` | `logic-1210-asym-d` | Niveaux de mesure par famille, asymétrie de référence |
| `logic-calib-nouvel-essai` | `logic-129-cal2-retest-1210` | Nouvel essai, cylindre non convergé |
| `logic-calib-pente-modele` | `logic-1210-slope` | Erreur de modèle aux forts besoins (profil synthétique ; `-Prof` pour un profil réel) |
| `logic-cible-refus` | `logic-1210-fix1-rc5-d` | Lecteur cible : refus (secteurs durs, courbe croisée absente), rapport |
| `logic-cible-textes` | `logic-1210-fixB-f` | Lecteur cible : textes, mesure complète, boutons « Courbe » |
| `logic-courbe-apres-croisee` | `logic-1210-rc5fix6` | Bouton « Courbe » après une calibration croisée |
| `logic-courbe-precomp` | `logic-1210-rc6fix1-d` | Bouton « Courbe » et `--precomp` transmis à gw |
| `logic-courbe-textes` | `logic-1210-rc6fix3` | Textes du bouton « Courbe » |
| `logic-courbe-transmission` | `logic-1210-rc6-e` | Bouton « Courbe » selon ce que l'écriture transmet |
| `logic-courbes-par-lecteur` | `logic-1210-drivecurves-e3` | Courbes par lecteur, migration d'une configuration 12.9 |
| `logic-ecriture-format-profil` | `logic-1210-fix1-c` | Gestionnaires du format et de la case `--precomp` |
| `logic-ecriture-profil-facteur` | `logic-1210-final-ac` | Libellé du profil, refus de la Bibliothèque, facteur de marque |
| `logic-lecteur-cible` | `logic-1210-target-n` | Écriture pour un lecteur cible |
| `logic-qualite-export` | `logic-1210-export` | Export du tableau « Qualité & alignement », cultures fr-FR et en-US |
| `logic-qualite-hors-classe` | `logic-1210-struct-r` | Intervalles hors classe reproductibles (cas sur lectures réelles avec `-Reads` seulement) |
| `logic-restauration-rapport` | `logic-1210-fixA-e` | Restauration : cadre, règles et rapport |
| `logic-restauration-regles` | `logic-1210-fix2-e` | Restauration : règles et cadre, mesures de texte |

Trois tests portent sur les outils eux-mêmes : `logic-lanceur` (verdicts du lanceur sur des tests factices), `logic-controle-source` (un défaut semé par contrôle dans un dépôt factice) et `logic-csharp-compilation` (les cinq blocs `Add-Type` de l'application compilent et donnent leurs types ; la compilation n'a lieu qu'avec `-Ci`).

## Ce qui reste hors du dépôt

- Les essais sur matériel et le banc de test de l'interface (fenêtres réelles, simulateur de `gw.exe`).
- Les tests qui rejouent des données réelles (journaux de calibration, relevés, lectures `.scp`) ou qui comparent la source à une copie d'une version antérieure. `logic-qualite-hors-classe -Reads <dossier> -Before <copie de la source d'avant>`, `logic-calib-bout-en-bout -Base <copie>` et `logic-calib-pente-modele -Prof <fichier>` rejouent ces cas sur le poste qui a ces données.
