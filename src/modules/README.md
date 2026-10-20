# Modules de la source

La source de Greaseweazle Studio est découpée en modules : les fichiers `NNN-nom.ps1` de ce dossier. `src/GreaseweazleGUI.ps1` en est l'assemblage, c'est-à-dire la concaténation exacte des modules dans l'ordre de leur numéro. C'est ce fichier unique que PS2EXE compile, que publie chaque release, que l'on lance avec `powershell -File` et que lit le banc de test.

**Règle : on ne modifie plus que les modules, puis on réassemble.**

`src/GreaseweazleGUI.ps1` et `src/GreaseweazleGUI.map.json` sont générés. Ne les modifiez jamais à la main. Ils restent versionnés et se commitent avec les modules.

## Les modules

Les modules forment trois groupes, exécutés dans l'ordre de leur numéro (12.8) :
- **Amorce (000 à 040).** En-tête, textes, assemblies, blocs C#, état initial et table des formats.
- **Fonctions (100 à 300), nommées `NNN-fn-domaine.ps1`.** Elles ne contiennent que des définitions de fonction, regroupées par domaine. Une définition n'exécute rien : elle rend seulement la fonction disponible. Placées avant tout le code de l'interface, les fonctions sont donc toutes définies avant leur premier appel. `T` et `Format-UiNum` restent dans `010-i18n.ps1`, avec la table des textes qu'elles lisent.
- **Déroulé (500 à 600).** Le code du niveau du script, dans l'ordre d'origine : fenêtre et onglets, état et constantes des domaines, minuteur principal, démarrage, puis `[void]$form.ShowDialog()`.

Dans tous les modules, aucune instruction n'est à cheval sur deux modules, et chaque module s'analyse seul, sans erreur.

| Module | Contenu |
|---|---|
| `000-entete.ps1` | En-tête, `param()`, `$script:Version`, versions du calcul de calibration (`CalibCalc`, `CalibCalcHd`) |
| `010-i18n.ps1` | Table I18n (textes anglais), `T`, `Format-UiNum` |
| `020-amorce.ps1` | Assemblies WinForms, chemins, état de gw, extensions reconnues |
| `030-csharp.ps1` | Blocs C# compilés au démarrage : comparateur de secteurs, statistiques SCP, motif de calibration, ajustement de courbe, index rapide |
| `040-etat-formats.ps1` | État de l'application, profils de précompensation, table des réglages (`$script:SettingDefs`), table des formats |
| `100-fn-interface.ps1` | Interface commune : infobulles, aide, glyphes, logo, boutons, onglets, étiquettes, bandeau, cartes de l'Accueil, barre, journal, largeurs ajustées au texte, fenêtre de confirmation commune (`Show-AppConfirm`, `frmConfirm`) |
| `110-fn-coeur-gw.ps1` | Chaîne d'étapes, arguments communs, occupation (`Get-AppBusy`, test unique « opération en cours »), journal et boîtes de message (`Show-AppMessage`), progression, détection des lecteurs, lancement de gw et lecture de sa sortie |
| `120-fn-configuration.ps1` | Réglages à source unique (`Set-Setting`, `Register-SettingCtl`, `Update-SettingDependents`, `Import-Settings`, `Export-Settings`, `Reset-Settings`), valeurs par défaut, enregistrement et chargement de la configuration |
| `130-fn-bibliotheque.ps1` | Bibliothèque : arborescence, archives ZIP, index, recherche, écriture depuis la Bibliothèque ; liste groupée des résultats (12.8, lot 4a : colonnes, tri, badges, filtres, travail différé au minuteur), panneau de détails (bloc INFO des IPF, ADF, documents associés, vignette, disquettes manquantes) ; liste de référence (lot 4b : choix, lecture à la première demande, identification des images et des archives par le travail différé, cache des empreintes ; FIX4B : états revalidés par la date du fichier, image extraite d'une archive contrôlée avant l'écriture, colonne de droite ajustée à la hauteur de la page) |
| `135-fn-bibliotheque-analyse.ps1` | Bibliothèque, analyse sans interface (12.8, lot 4a) : noms TOSEC et No-Intro avec replis (`Get-LibNameInfo`), règle des mots de la recherche (`Select-LibMatches`), disquettes manquantes, CRC-32 par la bibliothèque ZIP native de .NET (`Get-Crc32` : archive en mémoire sans compression, CRC lu dans le répertoire central ; aucun calcul en PowerShell), bloc INFO des IPF (`Get-IpfInfoBlock`), blocs de démarrage et racine des ADF (`Get-AdfInfo`) |
| `136-fn-bibliotheque-dat.ps1` | Bibliothèque, liste de référence sans interface (12.8, lot 4b, D19) : lecture des DAT Logiqx XML (`XmlReader` sans DTD ni résolution externe) et clrmamepro (`Read-LibDat`), correspondance par taille et empreinte, sur l'index `ByHash` (`Get-LibDatMatch` : officiel, modifié, inconnu), CRC-32 d'un fichier par `Get-Crc32` (`Get-LibFileCrc32`), répertoire central des ZIP (`Read-LibZipDir` : CRC des entrées lu sans calcul ; `Test-LibZipEntryData` : image extraite comparée à ce CRC), cache `hash-<md5>.tsv` ; clrmamepro lu sans expression à retour arrière catastrophique (`Get-LibDatRx`) |
| `140-fn-ecriture.ps1` | Écriture : options, préréglages, surcharge d'opération des écritures depuis la Bibliothèque (`Enter-OpOverride`), état de la calibration, mesure de la disquette avant l'écriture |
| `150-fn-pistes-densite.ps1` | Pistes et TSPEC, options de relecture du lecteur, haute densité |
| `160-fn-ecriture-lente.ps1` | Écriture lente : file des commandes, préchauffage du lecteur |
| `170-fn-controle-ecriture.ps1` | Contrôle après écriture, réécriture des pistes faibles |
| `180-fn-comparaison.ps1` | Comparaison d'une image et d'une disquette, détection automatique du format de la comparaison |
| `185-fn-detection-format.ps1` | Détection du format (12.8) : d'une disquette, pour la restauration et la comparaison (`Invoke-DiskFormatDetect`, `Select-DiskFormat`), et d'une image de référence (`Get-RefImageFormat`, `Select-RefDecodeFormat`) |
| `190-fn-qualite-alignement.ps1` | Lecture des SCP, alignement, jitter, métriques de piste, analyse de l'onglet Qualité |
| `195-fn-qualite-affichage.ps1` | Affichage de la qualité (12.8, lot 3) : état unique `$script:QualView` (`Set-QualityPending`, `Set-QualityResult`, `Set-QualityStale`), carte de résultat `pnlQualCard`, pictogrammes de score et d'état (`New-QualityPicto`), ressources GDI+ en cache, icônes d'état de l'onglet Écriture et de la restauration |
| `200-fn-accueil-calibration.ps1` | Carte « Calibrer le lecteur », zone de progression et courbe de l'Accueil |
| `210-fn-nettoyage.ps1` | Nettoyage des têtes : pictogrammes, fenêtre, déroulement |
| `220-fn-profil-precomp.ps1` | Détection de la cellule, profil de précompensation de l'image |
| `230-fn-calib-courbe.ps1` | Calibration : échelle, ajustement, dessin et configuration des courbes |
| `240-fn-calib-mesure.ps1` | Calibration : unités, motif, zéros, vérification, dérive, comparaison des courbes, anciennes calibrations |
| `250-fn-calib-fenetres.ps1` | Fenêtres de décision, de confirmation et de contrôle de surface de la calibration |
| `260-fn-calib-rapide.ps1` | Calibration rapide (niveau par disquette) : référence, passes, décision, bilan, fenêtre de décision |
| `265-fn-calib-adaptative.ps1` | Calibration rapide adaptative (12.8, lot 1c) : forme de la disquette (moindres carrés, validation croisée, contrôles), passes de mesure et de vérification, mémoire par marque |
| `270-fn-calib-complete.ps1` | Calibration complète : lancement, préchauffage, passes, analyse, fin |
| `280-fn-calib-surface.ps1` | Contrôle de surface et de vitesse des calibrations |
| `290-fn-calib-b.ps1` | « Refaire sur une autre disquette » (calibration B) |
| `300-fn-restauration.ps1` | Restauration : étapes, lecture, sonde, écriture, comparaison, rapport |
| `500-fenetre-theme.ps1` | Fenêtre principale, infobulles, thème, bloc C# `GwUi.Native` |
| `510-ui-bandeau-bibliotheque.ps1` | Bandeau (logo, titre, lecteur), onglet Bibliothèque (12.8 : filtres, liste des résultats `lvLib`, panneau de détails ; lot 4b : bouton « Liste de référence… », état et retrait ; FIX4B : compteur sous la liste, colonnes à la largeur de leur titre) |
| `520-ui-ecriture.ps1` | Onglet Écriture |
| `530-ui-onglets-techniques.ps1` | Onglets Lecture, Conversion, Comparaison, Qualité, Outils, Délais, Commande libre |
| `540-ui-accueil-restauration-barre.ps1` | Accueil, interface de la Restauration, barre d'état, journal |
| `550-etat-nettoyage.ps1` | Principe et état du nettoyage des têtes |
| `560-etat-calibration.ps1` | Principe et constantes de la calibration, état des courbes |
| `570-etat-controle-ecriture.ps1` | Principe et état du contrôle après écriture |
| `580-etat-restauration.ps1` | Principe, état et règles de la restauration |
| `590-etat-detection.ps1` | État de la détection des lecteurs |
| `600-minuteur-demarrage.ps1` | Minuteur principal, fermeture, `Shown`, démarrage, `[void]$form.ShowDialog()` |

**Où placer du code.**
- Une nouvelle fonction va dans le module `fn` de son domaine, ou dans un nouveau module `fn`. L'assembleur refuse toute autre instruction dans un module `fn`.
- Le code du niveau du script va dans un module de déroulé, à sa place dans l'ordre d'exécution : création d'un contrôle, gestionnaire d'événement, variable d'état ou constante.
- Un réglage modifiable à plusieurs endroits, ou enregistré dans la configuration (12.8) : une entrée de `$script:SettingDefs` (`040`), la liaison `Register-SettingCtl` de son contrôle d'onglet après la création du contrôle, et sa propagation éventuelle dans `Update-SettingDependents` (`120`). Une fenêtre lit le réglage par `Get-Setting` à son ouverture et l'écrit par `Set-Setting` quand l'action est lancée. Lecture, enregistrement et valeur par défaut passent par la table : rien à ajouter dans `Load-Config`, `Save-Config` ni `Set-Defaults`.

**Le numéro fixe l'ordre d'exécution.** Le script s'exécute de haut en bas, comme un seul fichier :
- une fonction appelée au niveau du script doit être définie plus haut, ce que garantissent les modules `fn` placés avant le déroulé ;
- un contrôle doit être créé avant d'être utilisé.

Déplacer une fonction d'un module `fn` à un autre ne change rien à l'exécution, tant qu'aucun nom de fonction n'est défini deux fois. Déplacer du code du niveau du script change l'ordre d'exécution. Après un tel déplacement, le contrôle statique du banc (« contrôle utilisé avant sa création », « fonction appelée avant sa définition ») doit rester à zéro constat.

## Modifier un module

1. Ouvrez le module et modifiez-le.
   - Encodage : UTF-8 avec BOM, fins de ligne CRLF. `.editorconfig` et `.gitattributes` les imposent déjà.
   - Méfiez-vous des outils qui réécrivent le fichier, comme `sed` ou Python en mode texte : ils peuvent retirer le BOM ou les CR. L'assembleur le refuse, en donnant le module et la ligne.
   - Conventions inchangées : commentaires en français sans accents, et chaque texte de l'interface passe par `T`, avec son entrée anglaise dans `010-i18n.ps1`.
   - La version de l'application est dans `000-entete.ps1` (`$script:Version`).
2. Les messages de PowerShell, de PS2EXE et du banc de test donnent les lignes du fichier assemblé. Pour retrouver le module :

   ```powershell
   pwsh -NoProfile -File tools\Resolve-ModuleLine.ps1 -Line <N>[,<N2>...]
   # GreaseweazleGUI.ps1:<N> -> <module>.ps1:<ligne du module>
   pwsh -NoProfile -File tools\Resolve-ModuleLine.ps1 -Module 500 -At 22
   # 500-fenetre-theme.ps1:22 -> GreaseweazleGUI.ps1:<N>
   ```

   Les lignes du fichier assemblé changent à chaque réassemblage qui ajoute ou retire des lignes : ne les recopiez pas dans la documentation, citez le module et sa ligne.

## Réassembler

```powershell
pwsh -NoProfile -File tools\Assemble-Source.ps1
```

Le script fonctionne aussi sous Windows PowerShell 5.1, l'édition qu'utilise `Build-Exe.ps1`. Il n'exécute aucun code des modules.

**Contrôles de chaque module.** À la moindre erreur, rien n'est écrit et le message nomme le module et la ligne. Chaque module doit avoir :
- un nom `NNN-mots-en-minuscules.ps1`, avec un numéro d'ordre unique sur 3 chiffres ;
- un encodage UTF-8 valide avec BOM, sans autre BOM ;
- des fins de ligne CRLF seules, y compris à la fin de la dernière ligne ;
- un texte qui s'analyse seul, sans erreur ;
- une dernière ligne qui ne finit pas par une continuation de ligne (accent grave) : l'instruction se poursuivrait dans le module suivant, sans erreur d'analyse ;
- pour un module `NNN-fn-*.ps1` : au moins une définition de fonction, et rien d'autre (ni instruction du niveau du script, ni bloc `param`, `begin` ou `process`).

**Contrôle du résultat.** Le fichier assemblé doit s'analyser sans erreur, et chaque instruction du niveau du script, bloc `param` compris, doit commencer et finir dans le même module. Cette garde générale couvre tout cas qu'aurait laissé passer le contrôle de chaque module.

**Écritures.**
- `src/GreaseweazleGUI.ps1` est écrit seulement si son contenu change. Il commence par un seul BOM, suivi du contenu des modules, octet pour octet.
- `src/GreaseweazleGUI.map.json` contient le SHA-256 du fichier assemblé, son nombre de lignes, et les lignes de début et de fin de chaque module dans ce fichier.

**Modification à la main.** Si `src/GreaseweazleGUI.ps1` a été modifié depuis le dernier assemblage, son SHA-256 ne correspond plus à celui de la table.
- L'assembleur refuse alors de l'écraser et indique la première ligne différente, avec son module.
- Reportez la modification dans ce module, puis relancez.
- `-Force` écrase le fichier, et la modification est perdue.

## Contrôler

```powershell
pwsh -NoProfile -File tools\Assemble-Source.ps1 -Check
```

`-Check` n'écrit rien. Outre les contrôles des modules et du résultat, il échoue (code de sortie 1) dans quatre cas :
- le fichier assemblé est absent ;
- le fichier assemblé n'est plus à jour, parce qu'un module a changé sans réassemblage ;
- le fichier assemblé a été modifié à la main ;
- la table n'est plus à jour.

Ensuite, contrôlez et testez le fichier assemblé, comme avant les modules :
- le banc de test lit `src/GreaseweazleGUI.ps1` : réassemblez avant de tester ;
- son contrôle statique lance aussi `-Check`, et signale une erreur si l'assemblage n'est pas à jour.

**Découpage ou renommage seul.** Si vous découpez ou renommez des modules sans en changer le texte, le fichier assemblé reste identique : même SHA-256. C'est la preuve qu'aucun octet n'a bougé.

## Ajouter, découper ou renommer un module

- **Numéros.** Ils vont de 10 en 10, pour laisser de la place : un module à placer entre `120` et `130` prend par exemple `125`. Un module d'amorce prend un numéro de 000 à 099, un module `fn` de 100 à 499, un module de déroulé de 500 à 999.
- **Découpage.** Coupez entre deux instructions du niveau du script, jamais à l'intérieur d'une fonction, d'une chaîne multiligne (here-string) ou d'une table. Un module `fn` se découpe entre deux fonctions.
- **Renommage.** Utilisez `git mv`, pour garder l'historique.
- **Nouveau fichier.** Créez-le en UTF-8 avec BOM et CRLF, et terminez sa dernière ligne par CRLF.

## Blocs C# (`Add-Type`)

Les cinq blocs compilés au démarrage sont dans deux modules :
- quatre dans `030-csharp.ps1` ;
- un dans `500-fenetre-theme.ps1` (`GwUi.Native`).

Leur texte ne change pas sans validation de sécurité : le banc de test compare l'empreinte de chaque bloc à une liste blanche. N'ajoutez pas de nouveau bloc.

## Compilation

`Build-Exe.ps1` assemble avant d'appeler PS2EXE, et toute erreur d'assemblage arrête la construction.

Si l'assemblage modifie `src/GreaseweazleGUI.ps1`, la construction s'arrête aussi : ce fichier n'est pas celui qui a été contrôlé. Contrôlez-le et testez-le, puis relancez `Build-Exe.ps1`. Le workflow de release, qui appelle `Build-Exe.ps1`, échoue donc lui aussi si le fichier assemblé commité n'est pas à jour.

## Commit

Commitez ensemble :
- les modules modifiés ;
- `src/GreaseweazleGUI.ps1` ;
- `src/GreaseweazleGUI.map.json`.

Un commit qui ne contient que les modules laisse un fichier assemblé périmé : le workflow de release le refuse.
