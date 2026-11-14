param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-final-ac) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out.
# Copie adaptee par la RC6 (10/11/2026, v1210\rc6\make_rc6_copies.py, source v1210\rc5\fix2\logic-1210-final-ab.ps1) : refus de la restauration sans courbe croisee « standard » A -> 0 (2c1eb08) au lieu de « ... en double densite » (R4G, R4G2 : cle de 018 de la RC6).
# Copie adaptee par la correction fix2 de la RC5 (10/11/2026, v1210\rc5\fix2\make_fix2_copies.py) : Get-WriteImageFamily (140), appelee par Get-TargetWriteInfo, ajoutee aux fonctions extraites ; phrase du cadre d un refus faute de courbe croisee : refus de la restauration au lancement.
# 12.10 (finalisation, 09/11/2026) : petits defauts corriges avant la publication. Fonctions reelles extraites par l arbre
# syntaxique (fichier de travail gen-1210-final.ps1, dot-source) ; remplacants nommes : T (table 010 + 018 lue par l arbre
# syntaxique, francais ou anglais), Append-Log (journal en memoire), Show-AppMessage (enregistree, aucune fenetre),
# Set-WTabNotice (enregistre l avis), detection de l image (d apres le nom du fichier), Update-CurveButton, mesure possible
# (Test-ContentMeasurable, Get-LevelWriteSkip, Test-WriteLevelWanted). Libelle du profil : vrai Label WinForms cree en
# memoire (System.Windows.Forms par Assembly.Load, aucun Add-Type, aucune fenetre). Aucun gw, aucune application.
#  A : libelle du profil avec un lecteur cible (220 Set-PrecompFields, Get-TargetProfileText, Get-WProfileSpec,
#      Update-PrecompForImage) : la courbe croisee est nommee (sens, test, date, calcul), le profil propre du lecteur source
#      n y figure plus ; texte qui tient dans le libelle (502 x 40, Segoe UI 9,75 ; 12.11, lot L9 : 458 x 58, taille lue
#      dans 520), en francais et en anglais
#  B : Bibliotheque : refus d une ecriture pour un lecteur cible (Test-TargetWriteAllowed -> OpOverride.Refused,
#      Enter-OpOverride, Show-LibEndNotice) : « ecriture refusee », et non « operation terminee »
#  C : origine des cylindres de test sans parentheses (260 Get-CalibCylinders) dans « Cylindres de test : {0} ({1}) »
#  D : Update-CalibProgress (270) sur un etat simule sans PhaseStart : aucune erreur
#  F : facteur de marque reutilise (140 Get-WriteFactorPlan, Get-WriteFactorHint) : conseil de mesure quand les mesures de
#      la marque s ecartent de 0,2 ou plus, ou en long track sans aucune mesure de la marque ; jamais quand la mesure est
#      cochee, impossible (restauration, test rapide, image non mesurable), pour un lecteur cible ou un profil Manuel
#  S : statique (cles i18n et traductions, README des modules, CHANGELOG)
# Relecture de la finalisation (09/11/2026, v1210\finalisation\revue) : copie adaptee de logic-1210-final, qui la
# remplace dans la campagne. Conseil de mesure : consigne selon l ecriture (lente : cocher la case ; rapide : ecrire en
# ecriture lente avec la case cochee) ; vrai Test-WriteLevelWanted (140) sur une case simulee $chkWLevel a la place du
# remplacant, qui ignorait le mode (une ecriture rapide n est jamais mesuree, case cochee ou non). Adaptes : F1, F3, F8,
# F10, S2 (nouvelles cles) ; ajoute : F11 (case cochee : ecriture rapide, consigne de l ecriture lente ; ecriture lente,
# aucun conseil).
# Correction tour 2 de la relecture des captures (10/11/2026, v1210\rc2\fix2) : copie adaptee de logic-1210-final-t, qui
# la remplace dans la campagne. A11 : complement court. Ajoutes : A14 (complements du lecteur cible en deux lignes avec le
# profil d origine, francais et anglais), A15 (libelle du profil : points de suspension en permanence, infobulle du texte
# complet au-dela de deux lignes, Update-WProfileTip), A16 (attente d echange de la calibration croisee sur une ligne),
# O1 a O7 (texte de la fenetre « Calibrations d un autre calcul » : phrase de la 12.3 seulement pour une courbe d un
# calcul anterieur a 12.3, paragraphe du calcul 12.10), S4 (cles i18n nouvelles traduites, anciennes retirees, cle
# 'Mesure de la disquette' de 012 seule).
# Relecture de a2f6b1f (10/11/2026, v1210\rc3, RC3 51606c1) : copie adaptee de v1210\rc2\fix2\logic-1210-final-t, qui la
# remplace dans la campagne. Extraites en plus : Move-WTargetNoteFirst (220) et Update-WCalTip (140), absentes avant
# 51606c1 (source d avant : cas R3 correspondants non conformes, sans arret du test), Update-WriteFactorNote (140),
# New-Group (100), Get-QualInk, Set-WCalVerdict, Clear-WCalVerdict (195), $script:PrecompHdDefault et $script:WTargetNote
# (040), $grpWOpt et les instructions « $lblWCal... » de premier niveau de 520 (fichier de travail gen-1210-final-u-wcal.ps1).
# Get-WriteFactorNote (140) renommee Get-WriteFactorNoteR ; remplacant Get-WriteFactorNote : complement « facteur » impose
# par $script:R3FactorNote (R3F : un lecteur cible donne un facteur 1, donc un complement vide), sinon la vraie fonction.
# Adaptes (refus du lecteur cible en tete du libelle du profil) : A11, A14. Ajoutes : R3A1 a R3A5, R3B1, R3B2, R3C1, R3C2
# (refus en tete : aucune courbe croisee, par tete en ecriture rapide, haute densite ; francais et anglais), R3D1 a R3D3
# (sans refus : libelle d avant), R3E (FM/GCR, flux tel quel : libelle sans refus), R3F (complement « facteur »), R3G
# (Move-WTargetNoteFirst idempotent), R3M (refus en deux lignes de 502 x 40 px, paires A/0, 0/A, B/2, 2/B), R3W1 a R3W3
# (lblWCal : construction de 520, infobulle du verdict, marge et taille).
# Correction tour 1 de la RC3 (10/11/2026, v1210\rc3\fix1) : copie adaptee de v1210\rc3\logic-1210-final-u, qui la
# remplace dans la campagne. Complements de refus du lecteur cible raccourcis en francais (018, 220 : sans « lecteur cible
# {0} : », deux lignes avec le profil d origine) : A11, A14, R3A1, R3B1, Get-R3Head, R3G, S4 adaptes. Extraite en plus :
# Update-HomeCalDescTip (200, absente avant : R3K non conforme, sans arret) et les instructions « $cardCalib.Controls[3]... »
# de premier niveau de 540 (fichier de travail gen-1210-final-v-card.ps1). Ajoutes : D3 (attente du controle de surface,
# 270 Update-CalibProgress), R3H (haute densite non calibrable avec un lecteur cible : refus en tete, a la place de la ligne
# d information), R3W4 (attente du controle de surface entiere sur la ligne de lblWCal, lecteurs A, B, 0 a 3, francais et
# anglais), R3W5 (avertissement de fin de calibration en tete de lblWCal, entier sur la ligne), R3K (description de la carte
# « Calibrer le lecteur » : points de suspension, infobulle du texte complet au-dela de deux lignes), S5 (270 : avertissement
# de fin en tete de lblWCal et des quatre libelles du profil ; statique : Complete-PrecompCalib n est pas joue).
# Correction tour 2 de la RC3 (10/11/2026, v1210\rc3\fix2, relecture de 408fc0a, P1) : copie de
# v1210\rc3\fix1\logic-1210-final-v, qui la remplace dans la campagne ; aucun cas existant modifie. Extraite en plus :
# Update-WTargetNoteForPrecomp (220, absente avant : cas P1 non conformes, sans arret) ; gestionnaire de 520 (instruction
# « $chkWPrecomp.Add_CheckedChanged » de premier niveau, fichier de travail gen-1210-final-w-precomp.ps1) joue sur une
# vraie case WinForms le temps des cas P1. Ajoutes : P1W (gestionnaire de 520 sur une vraie case), P1A (refus en tete,
# aucune courbe croisee, par tete en ecriture rapide, haute densite calibrable et non calibrable, francais et anglais :
# case decochee, libelle sans le refus et ecriture non refusee ; recochee, libelle et refus d avant), P1E (complement
# « facteur » : base sans le refus puis remise), P1F (sans refus : libelle inchange), P1G (libelle change entre-temps :
# rien n est ajoute ; Update-PrecompForImage refait le libelle), P1H (sequence des retablissements : Update-PrecompForImage
# case decochee, puis case et libelle d avant), P1K (gardes UiReady et SettingSync du gestionnaire).
# RC4 (10/11/2026, v1210\rc4, 789c19d) : copie adaptee de v1210\rc3\fix2\logic-1210-final-w, qui la remplace dans la
# campagne. Refus du lecteur cible annonce en tete du libelle du profil par Sync-WTargetHead (220), d apres le refus de
# l ecriture (Get-TargetWriteInfo, 140, BlockKind ; texte court : Get-WTargetHead), en sortie d Update-PrecompForImage et
# par le gestionnaire de la case --precomp (520 : Sync-WTargetHead -IfOwn, hors Update-PrecompForImage). Extraits a la
# place de Move-WTargetNoteFirst, Update-WTargetNoteForPrecomp et $script:WTargetNote (retires ; extraits encore s ils
# sont la : source d avant) : Get-WTargetHead, Sync-WTargetHead (220), Get-RsCalibText (300), $script:WTargetHead,
# $script:WProfilePath, $script:WProfileLabel, $script:WProfileBuilding (040). Adaptes : R3D1 a R3D3, R3H (tete posee
# $script:WTargetHead a la place du complement garde $script:WTargetNote), R3E (de meme, et aucune tete exigee), R3G
# (Sync-WTargetHead, avec et sans -IfOwn, a la place de Move-WTargetNoteFirst), P1W (gestionnaire qui appelle
# Sync-WTargetHead -IfOwn, garde WProfileBuilding en plus), P1F, P1G ($script:WTargetHead vide, $script:WProfileLabel
# a la place de $script:WTargetNoteCut), P1K (garde WProfileBuilding en plus). Ajoutes : R4A1 a R4A4 (matrice : profils
# Auto, forces, Manuel ; 12 images ; courbes croisees communes, par tete, aucune ; lente et rapide ; case cochee,
# decochee, recochee ; francais et anglais : refus en tete si et seulement si Get-TargetWriteInfo rend un Block, texte
# attendu), R4B (Sync-WTargetHead idempotent, tete retiree puis remise, jamais doublee), R4C (avis de la Bibliotheque,
# bilan de calibration : sans effet), R4D (complement « facteur » accorde), R4E (profil force et flux tel quel : $fxNote,
# aucune courbe croisee nommee), R4F, R4F2 (deux lignes de 502 x 40 px, paires A/0, 0/A, B/2, 2/B), R4G, R4G2 (cadre de
# la restauration : phrase du lecteur cible en tete ; entiere dans 262 x 54 px), R4H (retablissements, case decochee).
# Correction tour 1 de la RC4 (10/11/2026, v1210\rc4\fix1) : copie adaptee de v1210\rc4\logic-1210-final-x, qui la
# remplace dans la campagne : phrase du lecteur cible du cadre « Calibration du lecteur » raccourcie (300, cle 018 :
# « a la place de celle du lecteur {1} », type « commune » au lieu de « commune aux deux tetes ») ; R4G et R4G2 attendent
# la nouvelle phrase (R4G2 : entiere dans 262 x 54 px, courbe croisee commune comprise, francais et anglais).
# Correction fixA de la RC5 (10/11/2026, v1210\rc5\fixA) : copie adaptee de v1210\rc4\fix1\logic-1210-final-y, qui la
# remplace dans la campagne : Get-RsCalibText (300) tire sa phrase du lecteur cible de Get-RestorePlan ; extraits en plus
# s ils sont la : Get-RestoreFormat, Get-RestorePlan, Get-RestoreTargetInfo (300), Test-HdFormat (150) ; remplacant
# Get-Setting (format de la restauration : detection automatique). Attentes inchangees.
# Correction fixB de la RC5 (10/11/2026, v1210\rc5\fixB) : copie adaptee de v1210\rc5\fixA\logic-1210-final-z, qui la remplace dans la
# campagne : remplacant d Update-WLevelUi (140), appele en sortie d Update-PrecompForImage (220) ;
# attentes inchangees.
# 12.11 (lot L9, onglet Ecriture en trois etapes) : libelle du profil sous l image, 458 x 58 (trois lignes) au lieu de 502 x 40
# (deux lignes) ; la taille est lue dans 520 par A12 a A15 et R3M ; adaptes : A15 (texte trop long allonge pour depasser trois
# lignes), R4F et R4F2 (taille de 520 au lieu de 502 x 40 ecrit dans le test, trois lignes) ; aucun cas retire.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR')
[System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR')
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mods = Join-Path $Wt 'src\modules'
if (-not (Test-Path -LiteralPath (Join-Path $mods '140-fn-ecriture.ps1'))) { throw "modules introuvables sous $Wt" }

$script:FAsts = @{}
function Get-FAst([string]$path) {
    if ($script:FAsts.ContainsKey($path)) { return $script:FAsts[$path] }
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message) (ligne $(@($er)[0].Extent.StartLineNumber))" }
    $script:FAsts[$path] = $ast
    return $ast
}
function Get-FMod([string]$num) {
    $f = @(Get-ChildItem -LiteralPath $mods -Filter "$num-*.ps1")
    if ($f.Count -ne 1) { throw "module $num : $($f.Count) fichier(s)" }
    return $f[0].FullName
}
function Get-FFn([string]$num, [string]$name) {
    $fd = @((Get-FAst (Get-FMod $num)).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) | Where-Object { $_.Name -eq $name })
    if ($fd.Count -ne 1) { throw "fonction $name dans $num : $($fd.Count) (1 attendue)" }
    return $fd[0].Extent.Text
}
function Get-FAssign([string]$num, [string]$left) {
    $st = @((Get-FAst (Get-FMod $num)).EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left.Extent.Text -eq $left })
    if ($st.Count -ne 1) { throw "affectation $left dans $num : $($st.Count) (1 attendue)" }
    return $st[0].Extent.Text
}
function Read-I18n([string]$num) {
    # Table de traduction d un module, lue par l arbre syntaxique (cle et texte constants), sans rien executer
    $t = @{}
    foreach ($st in (Get-FAst (Get-FMod $num)).EndBlock.Statements) {
        if ($st -is [System.Management.Automation.Language.AssignmentStatementAst] -and $st.Left -is [System.Management.Automation.Language.IndexExpressionAst] -and $st.Left.Target.Extent.Text -eq '$script:I18n') {
            $t[[string]$st.Left.Index.Value] = [string]$st.Right.Expression.Value
        }
    }
    return $t
}

# ---------------------------------------------------------------- extraction
$parts = New-Object System.Collections.Generic.List[string]
foreach ($p in @(
        @('010', @('Format-UiNum')),
        @('140', @('Test-FluxImage', 'Test-RawFluxWrite', 'Get-WriteFactorSrcText', 'Get-WriteFactorPlan', 'Get-WriteFactorHint', 'Get-WriteFactorNote',
                   'Get-DriveIds', 'Get-TargetDrive', 'Get-TargetCurves', 'Get-TargetCurvesText', 'Get-TargetWriteInfo', 'Get-WriteImageFamily', 'Get-TargetWriteBlock',
                   'Test-TargetWriteAllowed', 'Enter-OpOverride', 'Merge-LibKeepState', 'Get-WriteModeText', 'Show-LibEndNotice', 'Test-WriteLevelWanted', 'Update-WProfileTip', 'Update-WriteFactorNote')),
        @('100', @('New-Group')),
        @('195', @('Get-QualInk', 'Set-WCalVerdict', 'Clear-WCalVerdict')),
        @('220', @('Get-CurveDate', 'Test-HeadCurvesCurrent', 'Get-FamilyCurves', 'Get-DriveFamilyCurves', 'Get-HeadSpec', 'Set-PrecompFields',
                   'Get-TargetProfileText', 'Get-WProfileSpec', 'Get-HdProfile', 'Get-HdCommonCurve', 'Set-WProfileText', 'Update-PrecompForImage')),
        @('230', @('Get-ImageFamily', 'Get-CalibFamilyName', 'Get-CurveCalc', 'Get-CurveCalcRef', 'Get-CurveCalcText', 'Test-CurveHd', 'Get-Median',
                   'Test-CurveCalcBefore', 'Get-CurveMaxNs', 'Test-CurveAtMax')),
        @('240', @('Get-DriveCurveKey', 'Split-DriveCurveKey', 'Get-DriveCurve', 'Set-DriveCurve', 'Sync-PrecompCurves', 'Get-DriveCurveKeys', 'Split-CrossDrive', 'Get-CrossCalibTargets',
                   'Get-CurveKeyLabel', 'Get-DriveCurveLabel')),
        @('260', @('Get-CalibCylinders')),
        @('265', @('Get-LevelBrandKey')),
        @('270', @('Update-CalibProgress')),
        @('274', @('Limit-WriteFactor', 'Get-DriveK')))) {
    foreach ($n in $p[1]) { $parts.Add((Get-FFn $p[0] $n)) }
}
foreach ($k in 'CalibCalc', 'CalibCalcHd', 'ContentCalc') { $parts.Add((Get-FAssign '000' "`$script:$k")) }
foreach ($k in 'PrecompStd', 'PrecompLong', 'PrecompStdDefault', 'PrecompLongDefault', 'PrecompThresholdNs', 'ContentFMax', 'PrecompHdDefault') { $parts.Add((Get-FAssign '040' "`$script:$k")) }
foreach ($k in 'DriveCurves', 'PrecompCurves', 'CurveKeys', 'TargetDrives', 'LevelBrand') { $parts.Add((Get-FAssign '560' "`$script:$k")) }
# Texte de la fenetre « Calibrations d un autre calcul » sans la fenetre : Resolve-OldCalibrations (240) coupee avant la
# creation de la fenetre ($W = 700), renommee Get-OldCalibTextT, qui rend $txt
$roText = Get-FFn '240' 'Resolve-OldCalibrations'
$roCut = [regex]::Match($roText, '\r?\n    \$W = 700')
if (-not $roCut.Success) { throw 'Resolve-OldCalibrations : ligne « $W = 700 » introuvable' }
$parts.Add(($roText.Substring(0, $roCut.Index) -replace '^function Resolve-OldCalibrations \{', 'function Get-OldCalibTextT {') + "`r`n    return `$txt`r`n}")
# RC3 : fonctions et etat de 51606c1, absents avant (source d avant : cas R3 correspondants non conformes, sans arret)
function Get-FFnOpt([string]$num, [string]$name) {
    $fd = @((Get-FAst (Get-FMod $num)).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) | Where-Object { $_.Name -eq $name })
    if ($fd.Count -gt 1) { throw "fonction $name dans $num : $($fd.Count) (1 au plus attendue)" }
    if ($fd.Count -eq 0) { return $null }
    return $fd[0].Extent.Text
}
$r3Missing = @()
# RC4 (789c19d) : Get-WTargetHead et Sync-WTargetHead (220) a la place de Move-WTargetNoteFirst et
# Update-WTargetNoteForPrecomp, retirees ; Get-RsCalibText (300, cas R4G)
foreach ($p in @(@('140', 'Update-WCalTip'), @('200', 'Update-HomeCalDescTip'), @('220', 'Get-WTargetHead'), @('220', 'Sync-WTargetHead'), @('300', 'Get-RsCalibText'))) {
    $tx = Get-FFnOpt $p[0] $p[1]
    if ($tx) { $parts.Add($tx) } else { $r3Missing += "$($p[1]) ($($p[0]))" }
}
# fixA (RC5) : decision de la restauration, lue par Get-RsCalibText (300)
foreach ($p in @(@('300', 'Get-RestoreFormat'), @('300', 'Get-RestorePlan'), @('300', 'Get-RestoreTargetInfo'), @('150', 'Test-HdFormat'))) {
    $tx = Get-FFnOpt $p[0] $p[1]
    if ($tx) { $parts.Add($tx) }
}
function Get-FAssignOpt([string]$num, [string]$left) {
    $st = @((Get-FAst (Get-FMod $num)).EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left.Extent.Text -eq $left })
    if ($st.Count -gt 1) { throw "affectation $left dans $num : $($st.Count) (1 au plus attendue)" }
    if ($st.Count -eq 0) { return $null }
    return $st[0].Extent.Text
}
foreach ($k in 'WTargetHead', 'WProfilePath', 'WProfileLabel', 'WProfileBuilding') {
    $tx = Get-FAssignOpt '040' "`$script:$k"
    if ($tx) { $parts.Add($tx) } else { $r3Missing += "`$script:$k (040)" }
}
# Fonctions et etat retires par 789c19d, extraits s ils sont encore la (source d avant, a53108a : ecart des cas R4 montre
# par la meme copie du test)
$r4Old = @()
foreach ($p in @(@('220', 'Move-WTargetNoteFirst'), @('220', 'Update-WTargetNoteForPrecomp'))) {
    $tx = Get-FFnOpt $p[0] $p[1]
    if ($tx) { $parts.Add($tx); $r4Old += $p[1] }
}
foreach ($k in 'WTargetNote', 'WTargetNoteCut') {
    $tx = Get-FAssignOpt '040' "`$script:$k"
    if ($tx) { $parts.Add($tx); $r4Old += "`$script:$k" }
}
# Get-WriteFactorNote (140) renommee Get-WriteFactorNoteR (remplacant Get-WriteFactorNote plus bas)
$ixN = -1; for ($i = 0; $i -lt $parts.Count; $i++) { if ($parts[$i] -match '^function Get-WriteFactorNote\(') { $ixN = $i } }
if ($ixN -lt 0) { throw 'Get-WriteFactorNote (140) introuvable' }
$parts[$ixN] = $parts[$ixN] -replace '^function Get-WriteFactorNote\(', 'function Get-WriteFactorNoteR('
# lblWCal construit comme dans 520 : affectation de $grpWOpt, puis les instructions de premier niveau « $lblWCal... »
# (creation, proprietes, gestionnaires) dans l ordre de 520 ; fichier de travail joue en R3W
$wcal = @((Get-FAst (Get-FMod '520')).EndBlock.Statements | Where-Object { $_.Extent.Text -match '^\$lblWCal\b' } | ForEach-Object { $_.Extent.Text })
$genW = Join-Path $here 'gen-1210-final-ac-wcal.ps1'
[System.IO.File]::WriteAllText($genW, (((@((Get-FAssign '520' '$grpWOpt')) + $wcal) -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
# fix1 : description de la carte « Calibrer le lecteur » comme dans 540 : instructions de premier niveau
# « $cardCalib.Controls[3]... » (points de suspension, gestionnaire TextChanged), jouees en R3K
$card = @((Get-FAst (Get-FMod '540')).EndBlock.Statements | Where-Object { $_.Extent.Text -match '^\$cardCalib\.Controls\[3\]\.(AutoEllipsis|Add_TextChanged)' } | ForEach-Object { $_.Extent.Text })
$genK = Join-Path $here 'gen-1210-final-ac-card.ps1'
[System.IO.File]::WriteAllText($genK, ((@($card) -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
$gen = Join-Path $here 'gen-1210-final-ac.ps1'
[System.IO.File]::WriteAllText($gen, ((@($parts) -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
. $gen
function Update-WLevelUi { }   # fixB (RC5) : case de la mesure (140), appelee en sortie d Update-PrecompForImage
function Get-Setting([string]$k) { return $null }   # fixA (RC5) : format de la restauration (Get-RestoreFormat) : detection automatique

# ---------------------------------------------------------------- remplacants
$script:I18n = Read-I18n '010'
foreach ($e in (Read-I18n '018').GetEnumerator()) { $script:I18n[$e.Key] = $e.Value }
$script:Lang = 'fr'
function T([string]$s) {
    if ($script:Lang -eq 'fr') { return $s }
    $t = $script:I18n[$s]
    if ($null -ne $t) { return $t }
    return $s
}
$script:Log = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text) { $script:Log.Add($text) }
$script:Msgs = New-Object System.Collections.Generic.List[string]
function Show-AppMessage([string]$text, [string]$title, [string]$buttons = 'OK', [string]$icon = 'Information') { $script:Msgs.Add("$title|$text"); Append-Log $text; return 'OK' }
$script:Notice = $null
function Set-WTabNotice([string]$text) { $script:Notice = $text }
function Reset-Run { $script:Log.Clear(); $script:Msgs.Clear(); $script:Notice = $null }
function Update-CurveButton([string]$path) { }
function Format-CalDuration([double]$s) { return "$([int]$s) s" }
function Save-WriteTabState { return @{ File = 'C:/x/avant.adf'; Tracks = '' } }
# Detection de l image d apres le nom du fichier
# RC3 : « -ed » : haute densite non calibrable (famille vide pour Get-HdCalibFamily ci-dessous), information hors R3
function Get-HighDensityReason([string]$path, [string]$fmt) { if ([System.IO.Path]::GetFileName("$path") -like '*-hd*') { return 'haute densité 1 440 Ko' }; if ([System.IO.Path]::GetFileName("$path") -like '*-ed*') { return 'extra-haute densité 2 880 Ko' }; return '' }
function Get-HdCalibFamily([string]$path, [string]$fmt = '') { if ([System.IO.Path]::GetFileName("$path") -like '*-hd*') { return 'hd' }; return '' }
function Get-IpfCellInfo([string]$path) {
    if ([System.IO.Path]::GetFileName("$path") -like '*long*') { return @{ CellNs = 1889.6; Bits = 105850; Tracks = 160; DosTracks = 158; Source = (T 'IPF (bits par piste)') } }
    return @{ CellNs = 1995.2; Bits = 100250; Tracks = 160; DosTracks = 160; Source = (T 'IPF (bits par piste)') }
}
function Get-HfeCellInfo([string]$path) { return @{ CellNs = 1995.2; Bits = 100250; Tracks = -1; DosTracks = -1; Source = ((T "HFE ({0} bits par piste, débit {1} kbit/s)") -f '100250', '250') } }
function Get-ScpCellInfo([string]$path) { return @{ CellNs = 1995.2; Bits = 100250; Tracks = 4; DosTracks = -1; Source = (T 'SCP (flux mesuré)') } }
function Get-ImageEncoding([string]$path, [string]$fmt) {
    if ([System.IO.Path]::GetExtension("$path").ToLower() -eq '.d64') { return @{ Enc = 'gcr'; Src = 'extension'; Name = 'GCR'; NonMfm = $true } }
    return @{ Enc = 'mfm'; Src = 'extension'; Name = 'MFM'; NonMfm = $false }
}
function Get-WriteLevelKind([string]$img, [string]$fmt) { if (Test-FluxImage $img) { return '' }; if ((Get-ImageEncoding $img $fmt).NonMfm) { return '' }; if (Get-HighDensityReason $img $fmt) { return 'hd' }; return 'dd' }
function Get-ImageCylinders([string]$path) { if ([System.IO.Path]::GetFileName("$path") -like '*80cyl*') { return 80 }; return $null }
$chkWLevel = [pscustomobject]@{ Checked = $false }   # case Mesurer la disquette (vrai Test-WriteLevelWanted, 140)
$script:SkipWhy = $null
function Get-LevelWriteSkip([string]$img, [string]$fmt, [string]$ts) { return $script:SkipWhy }
$script:CmOk = $true; $script:CmN = 0
function Test-ContentMeasurable([string]$img, [string]$fmt) { $script:CmN++; return @{ Ok = $script:CmOk; Why = $(if ($script:CmOk) { '' } else { 'champ Pistes : h=0' }) } }
$script:SettingDefs = @{ drive = @{ Codes = @('A', 'B', '0', '1', '2', '3') } }
# RC3 : remplacant de Get-WriteFactorNote (140, renommee Get-WriteFactorNoteR) : complement « facteur » impose par
# $script:R3FactorNote (R3F), sinon la vraie fonction (tous les autres cas)
$script:R3FactorNote = $null
function Get-WriteFactorNote([string]$path) { if ($null -ne $script:R3FactorNote) { return [string]$script:R3FactorNote }; return (Get-WriteFactorNoteR $path) }

# Controles simules ; libelle du profil : vrai Label WinForms (largeur, hauteur et police de 520/500)
$cmbDrive = [pscustomobject]@{ Text = 'A' }
$cmbWProfile = [pscustomobject]@{ SelectedIndex = 0; Text = 'Auto (selon image)' }
$chkWPrecomp = [pscustomobject]@{ Checked = $true }
$chkWSlow = [pscustomobject]@{ Checked = $true }
$txtWPrecomp = [pscustomobject]@{ Text = '' }; $txtWPrecomp1 = [pscustomobject]@{ Text = '' }
$txtWFile = [pscustomobject]@{ Text = '' }
$cmbWFmt = [pscustomobject]@{ Text = '(auto)' }
$txtWTracks = [pscustomobject]@{ Text = '' }
$cmbWCalMode = [pscustomobject]@{ SelectedIndex = 1 }
$pbWCal = [pscustomobject]@{ Value = 0 }; $lblWCal = [pscustomobject]@{ Text = '' }
$script:CalHardNs = 400; $script:CalHardNsUser = 400
$script:ScpStatsOk = $true; $script:GwProc = $null; $script:Cal = $null; $script:Restore = $null; $script:OpOverride = $null
$script:ContentMeasures = @(); $script:GwFormats = @{}
$wfOk = $false
# 12.11 : en integration continue (-Ci), System.Windows.Forms non chargeable est un echec, pas des cas sautes
try { Import-TestWinForms; $wfOk = $true } catch { if ($Ci) { throw }; "  System.Windows.Forms non chargeable : $($_.Exception.Message) ; cas de largeur sautes" }
$s520 = [System.IO.File]::ReadAllText((Get-FMod '520'))
$s500 = [System.IO.File]::ReadAllText((Get-FMod '500'))
$lblSize = if ($s520 -match "\`$lblWProfileInfo\.Location = '\d+,\d+'; \`$lblWProfileInfo\.Size = '(\d+),(\d+)'") { @([int]$Matches[1], [int]$Matches[2]) } else { $null }
$fontOk = $s500.Contains("`$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)")
$autoSz = $s520 -match '\$lblWProfileInfo\.AutoSize'
if ($wfOk -and $lblSize) {
    $lblWProfileInfo = New-Object System.Windows.Forms.Label
    $lblWProfileInfo.AutoSize = $false; $lblWProfileInfo.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
    $lblWProfileInfo.Size = New-Object System.Drawing.Size($lblSize[0], $lblSize[1])
} else { $lblWProfileInfo = [pscustomobject]@{ Text = '' } }
function Test-LabelFits([string]$t) {
    # Hauteur preferee du libelle a sa largeur (retour a la ligne) <= sa hauteur : texte entier visible
    if (-not ($lblWProfileInfo -is [System.Windows.Forms.Label])) { return $true }
    $lblWProfileInfo.Text = $t
    return ($lblWProfileInfo.GetPreferredSize((New-Object System.Drawing.Size($lblWProfileInfo.Width, 0))).Height -le $lblWProfileInfo.Height)
}

$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    if (-not $ok) { $script:Fail++; $script:FailIds += $id }
    '{0,-8} {1,-12} {2}' -f $id, $(if ($ok) { 'conforme' } else { 'NON CONFORME' }), $d
}
function New-Cv([string]$drive, [string]$tgt, [string]$fam, $head, [string]$date, [string]$spec, [string]$test = 'fine') {
    return @{ Family = (Get-CalibFamilyName $fam); Head = $head; Drive = $drive; Target = $tgt; Date = $date; Spec = $spec; Method = 'motif'
              Version = '12.10'; Calc = $script:CalibCalc; Converged = $true; Bits = 100000; Test = $test; Values = [int[]]@(0..79) }
}
function Get-LogN([string]$like) { return @($script:Log | Where-Object { $_ -like $like }).Count }
function Set-Ui([int]$profile = 0, [bool]$slow = $true, [bool]$precomp = $true, [string]$drive = 'A') {
    $cmbWProfile.SelectedIndex = $profile; $cmbWProfile.Text = (T @('Auto (selon image)', 'Standard 2 us', 'Long track 1,89 us', 'Manuel')[$profile])
    $chkWSlow.Checked = $slow; $chkWPrecomp.Checked = $precomp; $cmbDrive.Text = $drive; $cmbWFmt.Text = '(auto)'
}
$imgDir = Join-Path $here 'img-final-u'
New-Item -ItemType Directory -Force $imgDir | Out-Null
$img = @{}
foreach ($n in 'jeu.adf', 'jeu-long.ipf', 'jeu.ipf', 'jeu.hfe', 'jeu.scp', 'jeu.raw', 'jeu.d64', 'jeu-80cyl.adf', 'jeu-hd.img', 'jeu-ed.img') {
    $p = Join-Path $imgDir $n; [System.IO.File]::WriteAllBytes($p, [byte[]](1, 2, 3, 4)); $img[$n] = $p
}
"logic-1210-final-u : CalibCalc $($script:CalibCalc), libelle du profil $(if ($lblSize) { "$($lblSize[0]) x $($lblSize[1])" } else { 'introuvable' }), police Segoe UI 9,75 $fontOk, WinForms $wfOk ; PowerShell $($PSVersionTable.PSVersion)"

# Courbes : propres de A, croisees A>0 (std par tete d une meme date, commune, long commune), A>1 par tete de deux dates
$cvA = New-Cv 'A' '' 'std' $null '20/10/2026 10:00' '0=20:40=40'
$cvAL = New-Cv 'A' '' 'long' $null '20/10/2026 11:00' '0=30:40=50'
$xS = New-Cv 'A' '0' 'std' $null '01/11/2026 17:49' '0=40:40=80' 'standard'
$xH0 = New-Cv 'A' '0' 'std' 0 '02/11/2026 09:00' '0=41:40=81'; $xH1 = New-Cv 'A' '0' 'std' 1 '02/11/2026 09:00' '0=43:40=85'
$xL = New-Cv 'A' '0' 'long' $null '03/11/2026 11:00' '0=60:40=120' 'standard'
$yH0 = New-Cv 'A' '1' 'std' 0 '01/11/2026 17:49' '0=51:40=91' 'standard'; $yH1 = New-Cv 'A' '1' 'std' 1 '02/11/2026 09:05' '0=53:40=95' 'standard'
$yL = New-Cv 'A' '1' 'long' $null '03/11/2026 11:00' '0=61:40=121' 'standard'
function Reset-Store {
    $script:DriveCurves = @{}
    Set-DriveCurve 'A' 'std' $cvA; Set-DriveCurve 'A' 'long' $cvAL
    Set-DriveCurve 'A>0' 'std' $xS; Set-DriveCurve 'A>0' 'std_h0' $xH0; Set-DriveCurve 'A>0' 'std_h1' $xH1; Set-DriveCurve 'A>0' 'long' $xL
    Set-DriveCurve 'A>1' 'std_h0' $yH0; Set-DriveCurve 'A>1' 'std_h1' $yH1; Set-DriveCurve 'A>1' 'long' $yL
    Sync-PrecompCurves 'A'
}
Reset-Store
$calc = "v$($script:CalibCalc)"

"--- A : libelle du profil avec un lecteur cible"
$script:TargetDrives = @{}; Set-Ui 0 $true
Update-PrecompForImage $img['jeu.adf']
Chk 'A1' ($lblWProfileInfo.Text -eq "Auto : image secteur (.adf) -> standard 2 us ($($script:PrecompStd)) ; écriture lente : même profil pour les deux têtes (aucune calibration par tête pour cette famille)" -and $script:PrecompStd -eq $cvA.Spec) "meme lecteur : libelle d avant, profil propre de A ($($lblWProfileInfo.Text))"
$script:TargetDrives = @{ A = '0' }; Set-Ui 0 $true
Update-PrecompForImage $img['jeu.adf']
$a2 = "Auto : image secteur (.adf) -> standard 2 us (courbes croisées A → 0 par tête, test fin, 02/11/2026 09:00, calcul $calc)"
Chk 'A2' ($lblWProfileInfo.Text -eq $a2 -and $txtWPrecomp.Text -eq $xH0.Spec -and $txtWPrecomp1.Text -eq $xH1.Spec -and -not $lblWProfileInfo.Text.Contains($script:PrecompStd)) "cible 0, ecriture lente, courbes par tete d une meme date : $($lblWProfileInfo.Text) ; champs aux courbes croisees, profil propre de A absent"
Set-Ui 0 $false
Update-PrecompForImage $img['jeu.adf']
Chk 'A3' ($lblWProfileInfo.Text -eq "Auto : image secteur (.adf) -> standard 2 us (courbe croisée A → 0, test standard, 01/11/2026 17:49, calcul $calc)" -and $txtWPrecomp.Text -eq $xS.Spec) "cible 0, ecriture rapide, courbe commune : $($lblWProfileInfo.Text)"
Set-DriveCurve 'A>0' 'std_h0' $null; Set-DriveCurve 'A>0' 'std_h1' $null; Set-Ui 0 $true
Update-PrecompForImage $img['jeu.adf']
Chk 'A4' ($lblWProfileInfo.Text -eq "Auto : image secteur (.adf) -> standard 2 us (courbe croisée A → 0 pour les deux têtes, test standard, 01/11/2026 17:49, calcul $calc)" -and $txtWPrecomp1.Text -eq $xS.Spec) "cible 0, ecriture lente, courbe commune seule : $($lblWProfileInfo.Text)"
Reset-Store
$script:TargetDrives = @{ A = '1' }; Set-Ui 0 $true
Update-PrecompForImage $img['jeu.adf']
$a5 = "Auto : image secteur (.adf) -> standard 2 us (courbes croisées A → 1 par tête, test standard, tête 0 du 01/11/2026 17:49, tête 1 du 02/11/2026 09:05, calcul $calc)"
Chk 'A5' ($lblWProfileInfo.Text -eq $a5 -and $txtWPrecomp.Text -eq $yH0.Spec -and $txtWPrecomp1.Text -eq $yH1.Spec) "cible 1, courbes par tete de deux dates : $($lblWProfileInfo.Text)"
$script:TargetDrives = @{ A = '0' }; Set-Ui 2 $true
Update-PrecompForImage $img['jeu.adf']
Chk 'A6' ($lblWProfileInfo.Text -eq "Profil forcé : long track (courbe croisée A → 0 pour les deux têtes, test standard, 03/11/2026 11:00, calcul $calc)" -and $txtWPrecomp.Text -eq $xL.Spec) "profil force Long track : $($lblWProfileInfo.Text)"
Set-Ui 0 $true; Reset-Run
Update-PrecompForImage $img['jeu-long.ipf']
$a7 = "Auto : image .ipf -> LONG TRACK (courbe croisée A → 0 pour les deux têtes, test standard, 03/11/2026 11:00, calcul $calc)"
Chk 'A7' ($lblWProfileInfo.Text -eq $a7 -and (Get-LogN "Profil precomp : $a7") -eq 1 -and $txtWPrecomp.Text -eq $xL.Spec) "IPF long track, Auto : detail de detection reduit a l extension, famille gardee, courbe croisee nommee, meme texte au journal : $($lblWProfileInfo.Text)"
$script:TargetDrives = @{}; Update-PrecompForImage $img['jeu-long.ipf']
Chk 'A8' ($lblWProfileInfo.Text -eq "Auto : IPF (bits par piste) : cellule 1890 ns, 105850 bits/piste, 158/160 pistes DOS -> LONG TRACK ($($script:PrecompLong)) ; écriture lente : même profil pour les deux têtes (aucune calibration par tête pour cette famille)" -and $script:PrecompLong -eq $cvAL.Spec) "meme lecteur, IPF : libelle d avant ($($lblWProfileInfo.Text))"
$script:TargetDrives = @{ A = '0' }; Set-Ui 0 $true; $cmbWFmt.Text = '(auto)'
Update-PrecompForImage $img['jeu.raw']
Chk 'A9' ($lblWProfileInfo.Text -like "Auto : image flux (.raw) -> standard 2 us ($($script:PrecompStd)) ; image flux écrite telle quelle*") "flux ecrit tel quel (--precomp non transmis) : profil d avant et complement du flux, courbe croisee non nommee"
Set-Ui 1 $true
Update-PrecompForImage $img['jeu.d64']
Chk 'A10' ($lblWProfileInfo.Text -like "Profil forcé : standard 2 us ($($script:PrecompStd)) ; image en codage GCR*") "GCR (--precomp non transmis) : profil d avant, complement du codage : $($lblWProfileInfo.Text)"
$script:TargetDrives = @{ A = '2' }; Set-Ui 0 $true
Update-PrecompForImage $img['jeu.adf']
Chk 'A11' ($lblWProfileInfo.Text -eq "Aucune courbe croisée A → 2 : écriture refusée (« Calibrer pour un lecteur cible… ») ; Auto : image secteur (.adf) -> standard 2 us ($($script:PrecompStd))" -and (Test-LabelFits $lblWProfileInfo.Text)) "cible 2 sans courbe croisee : refus annonce en tete (RC3), profil de famille a sa suite, en deux lignes (fix2)"
# Largeur : textes les plus longs, en francais puis en anglais (traductions de 010 et 018)
if ($lblWProfileInfo -is [System.Windows.Forms.Label]) {
    $script:TargetDrives = @{ A = '1' }; $worst = @()
    foreach ($lang in 'fr', 'en') {
        $script:Lang = $lang
        foreach ($case in @(@(0, 'jeu.adf'), @(0, 'jeu-long.ipf'), @(0, 'jeu.hfe'), @(1, 'jeu.adf'), @(2, 'jeu.adf'), @(0, 'jeu.scp'))) {
            Set-Ui $case[0] $true; $cmbWFmt.Text = $(if ($case[1] -eq 'jeu.scp') { 'ibm.1440' } else { '(auto)' })
            Update-PrecompForImage $img[$case[1]]
            $t = $lblWProfileInfo.Text; $fit = Test-LabelFits $t
            $worst += [pscustomobject]@{ L = $lang; T = $t; Fit = $fit; N = $t.Length }
        }
    }
    $script:Lang = 'fr'; $cmbWFmt.Text = '(auto)'
    $nf = @($worst | Where-Object { -not $_.Fit })
    $lmax = ($worst | Measure-Object -Property N -Maximum).Maximum
    $named = @($worst | Where-Object { $_.T -match '(courbes? croisées?|cross curves?) A → 1' }).Count
    Chk 'A12' ($nf.Count -eq 0 -and $named -eq $worst.Count -and -not $autoSz -and $fontOk) "$($worst.Count) libelles avec courbes par tete de deux dates (adf, ipf long, hfe, profils forces, scp decode ; francais et anglais) : tous tiennent dans $($lblSize[0]) x $($lblSize[1]) px (AutoSize faux dans 520, Segoe UI 9,75 dans 500), $lmax caracteres au plus ; $($nf.Count) trop long(s)$(if ($nf.Count) { ' : ' + $nf[0].T })"
    $en = @($worst | Where-Object { $_.L -eq 'en' })[0].T
    Chk 'A13' ($en -eq "Auto: sector image (.adf) -> standard 2 us (cross curves A → 1 per head, standard test, head 0 of 01/11/2026 17:49, head 1 of 02/11/2026 09:05, calculation $calc)") "anglais : $en"
} else { Chk 'A12' $false "libelle du profil introuvable dans 520 (taille $(if ($lblSize) { 'lue' } else { 'non lue' })) ou WinForms indisponible ($wfOk) : A12 et A13 non joues" }
$script:TargetDrives = @{}

# ---- Correction tour 2 (fix2)
# A14 (B1) : complements « lecteur cible » raccourcis (220 Set-PrecompFields) avec le profil d origine de la famille (courbe
# propre de A retiree) : texte exact en francais, deux lignes en francais et en anglais
if ($lblWProfileInfo -is [System.Windows.Forms.Label]) {
    Set-DriveCurve 'A' 'std' $null; Sync-PrecompCurves 'A'
    $r14 = @()
    foreach ($lang in 'fr', 'en') {
        $script:Lang = $lang
        $script:TargetDrives = @{ A = '2' }; Set-Ui 0 $true; Update-PrecompForImage $img['jeu.adf']
        $r14 += [pscustomobject]@{ L = $lang; C = 'sans courbe croisee'; T = $lblWProfileInfo.Text; Fit = (Test-LabelFits $lblWProfileInfo.Text) }
        $script:TargetDrives = @{ A = '1' }; Set-Ui 0 $false; Update-PrecompForImage $img['jeu.adf']
        $r14 += [pscustomobject]@{ L = $lang; C = 'par tete seulement, ecriture rapide'; T = $lblWProfileInfo.Text; Fit = (Test-LabelFits $lblWProfileInfo.Text) }
    }
    $script:Lang = 'fr'; $script:TargetDrives = @{}
    $r14 | ForEach-Object { "  $($_.L), $($_.C) : deux lignes $($_.Fit) : $($_.T)" }
    $d14 = $script:PrecompStdDefault
    Chk 'A14' ($script:PrecompStd -eq $d14 -and @($r14 | Where-Object { -not $_.Fit }).Count -eq 0 `
        -and $r14[0].T -eq "Aucune courbe croisée A → 2 : écriture refusée (« Calibrer pour un lecteur cible… ») ; Auto : image secteur (.adf) -> standard 2 us ($d14)" `
        -and $r14[1].T -eq "Courbes croisées A → 1 par tête : écriture rapide refusée (cochez « Écriture lente ») ; Auto : image secteur (.adf) -> standard 2 us ($d14)" `
        -and $r14[2].T.StartsWith('Target drive 2: no cross curve A → 2 for this family, write refused ("Calibrate for a target drive…"); Auto: ') `
        -and $r14[3].T.StartsWith('Target drive 1: per-head cross curves A → 1 only, fast write refused (check "Slow write"); Auto: ')) "profil d origine $d14 : complements du lecteur cible (sans courbe croisee ; par tete seulement en ecriture rapide) en tete du libelle (RC3), en deux lignes de $($lblSize[0]) x $($lblSize[1]) px, francais et anglais"
    Reset-Store
} else { Chk 'A14' $false 'libelle WinForms indisponible : A14 non joue' }
# A15 (m5) : points de suspension en permanence (520), que Clear-WTabNotice (140) ne retire plus ; infobulle du texte complet
# au-dela de deux lignes (vrai Update-WProfileTip, 140, vrai ToolTip, aucune fenetre) ; dessin hors ecran d un Label de
# meme taille : points de suspension au lieu d une 3e ligne coupee, texte de deux lignes dessine comme avant
$c15 = Get-FFn '140' 'Clear-WTabNotice'
$ae15 = $s520 -match '(?m)^\$lblWProfileInfo\.AutoEllipsis = \$true\r?$'
$ev15 = ($s520 -match '(?m)^\$lblWProfileInfo\.Add_TextChanged\(\{ Clear-WTabNotice; Update-WProfileTip \}\)\r?$') -and ($s520 -match '(?m)^\$lblWProfileInfo\.Add_SizeChanged\(\{ Update-WProfileTip \}\)\r?$')
if ($lblWProfileInfo -is [System.Windows.Forms.Label]) {
    # 12.11 (lot L9) : libelle de 458 x 58 (trois lignes) : texte trop long allonge pour depasser trois lignes ; le texte
    # qui tient garde ses deux lignes
    $long15 = "Auto : image secteur (.adf) -> standard 2 us ($($script:PrecompStdDefault)) ; écriture lente : profils calibrés tête 0 et tête 1 appliqués ; facteur appliqué à l'écriture : tête 0 × 0,85, tête 1 × 0,90 ; courbes par tête du 01/11/2026 17:49 et du 02/11/2026 09:05, calcul v12.10, test fin ; facteur de la marque de la disquette : aucune mesure gardée pour cette marque"
    $fit15 = "Auto : image secteur (.adf) -> standard 2 us ($($script:PrecompStdDefault)) ; écriture lente : profils calibrés tête 0 et tête 1 appliqués"
    $tip = New-Object System.Windows.Forms.ToolTip
    $lblWProfileInfo.Text = $long15; Update-WProfileTip; $tt1 = $tip.GetToolTip($lblWProfileInfo)
    $lblWProfileInfo.Text = $fit15; Update-WProfileTip; $tt2 = $tip.GetToolTip($lblWProfileInfo)
    $w15 = $lblWProfileInfo.Width; $lblWProfileInfo.Width = 900; $lblWProfileInfo.Text = $long15; Update-WProfileTip; $tt3 = $tip.GetToolTip($lblWProfileInfo); $lblWProfileInfo.Width = $w15
    function Get-Ink15([bool]$ell, [string]$t) {
        $l = New-Object System.Windows.Forms.Label
        $l.Font = $lblWProfileInfo.Font; $l.Text = $t; $l.AutoEllipsis = $ell; $l.BackColor = [System.Drawing.Color]::White; $l.Size = $lblWProfileInfo.Size
        $w = $l.Width; $h = $l.Height; $bmp = New-Object System.Drawing.Bitmap($w, $h)
        try {
            $l.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle(0, 0, $w, $h)))
            $bg = [System.Drawing.Color]::White.ToArgb(); $ink = -1; $sb = New-Object System.Text.StringBuilder
            for ($y = 0; $y -lt $h; $y++) {
                $row = 0
                for ($x = 0; $x -lt $w; $x++) { $p = $bmp.GetPixel($x, $y).ToArgb(); if ($p -ne $bg) { $ink = $y; $row = ($row * 31 + $x + ($p -band 0xFF)) % 1000000007 } }
                [void]$sb.Append("$row;")
            }
            return @{ Ink = $ink; Sig = $sb.ToString() }
        } finally { $bmp.Dispose(); $l.Dispose() }
    }
    $iL0 = Get-Ink15 $false $long15; $iL1 = Get-Ink15 $true $long15; $iF0 = Get-Ink15 $false $fit15; $iF1 = Get-Ink15 $true $fit15
    "  infobulle : texte trop long : $(if ($tt1 -eq $long15) { 'texte complet' } elseif ($tt1) { "« $tt1 »" } else { 'aucune' }) ; deux lignes : $(if ($tt2) { "« $tt2 »" } else { 'aucune' }) ; trop long a 900 px de large : $(if ($tt3) { "« $tt3 »" } else { 'aucune' })"
    "  derniere ligne d encre du texte trop long : $($iL0.Ink) px sans, $($iL1.Ink) px avec points de suspension ; texte de deux lignes : $($iF0.Ink) / $($iF1.Ink) px, dessin identique $($iF0.Sig -eq $iF1.Sig)"
    $hh = $lblWProfileInfo.Height
    Chk 'A15' ($ae15 -and $ev15 -and -not ($c15 -match 'AutoEllipsis') -and $tt1 -eq $long15 -and $tt2 -eq '' -and $tt3 -eq '' -and $iL0.Ink -ge ($hh - 4) -and $iL1.Ink -ge 0 -and $iL1.Ink -le ($hh - 5) -and $iF0.Sig -eq $iF1.Sig) "points de suspension en permanence (520 : $ae15), Clear-WTabNotice sans AutoEllipsis (140), Update-WProfileTip au changement de texte et de taille (520 : $ev15) ; libelle de $($lblWProfileInfo.Width) x $hh px (12.11, lot L9 : trois lignes) : infobulle du texte complet seulement au-dela de ses lignes ; derniere ligne coupee remplacee par des points de suspension, texte qui tient dessine comme avant"
    $lblWProfileInfo.Text = ''
} else { Chk 'A15' $false 'libelle WinForms indisponible : A15 non joue' }
# A16 (m4) : attente d un echange de la calibration croisee (270) sur une ligne de lblWCal (Label AutoSize a x = 320 dans
# grpWOpt de 762 px, 520), francais et anglais
if ($wfOk) {
    $f16 = New-Object System.Drawing.Font('Segoe UI', 9.75)
    $g16 = New-Object System.Windows.Forms.GroupBox; $g16.Font = $f16; $g16.Size = New-Object System.Drawing.Size(762, 162)
    $av16 = $g16.DisplayRectangle.Right - 320; $g16.Dispose()
    $w16 = @()
    foreach ($lang in 'fr', 'en') {
        $script:Lang = $lang
        foreach ($p in @(@('A', '0'), @('2', 'B'))) {
            $l16 = New-Object System.Windows.Forms.Label; $l16.Font = $f16; $l16.AutoSize = $true
            $l16.Text = (T 'Calibration croisée : déplacez la disquette du lecteur {0} vers le lecteur {1}') -f $p[0], $p[1]
            $w16 += [pscustomobject]@{ T = $l16.Text; W = $l16.PreferredSize.Width }; $l16.Dispose()
        }
    }
    $script:Lang = 'fr'
    $s270f = [System.IO.File]::ReadAllText((Get-FMod '270'))
    Chk 'A16' (@($w16 | Where-Object { $_.W -gt $av16 }).Count -eq 0 -and $w16[0].T -eq 'Calibration croisée : déplacez la disquette du lecteur A vers le lecteur 0' -and $w16[2].T -eq 'Cross calibration: move the disk from drive A to drive 0' -and $s270f.Contains('$lblWCal.Text = (T "Calibration croisée : déplacez la disquette du lecteur {0} vers le lecteur {1}")')) "attente d echange (270) sur une ligne de $av16 px : $(($w16 | ForEach-Object { "$($_.W) px" }) -join ', ') (francais A -> 0, 2 -> B ; anglais)"
} else { Chk 'A16' $false 'WinForms indisponible : A16 non joue' }

# ---- RC3 (relecture de a2f6b1f, 51606c1)
"--- R3 : refus du lecteur cible en tete du libelle du profil (220 Sync-WTargetHead, Get-WTargetHead : RC4), libelle de la calibration (520 lblWCal, 140 Update-WCalTip)"
if ($r3Missing.Count) { "  absent(s) de la source : $($r3Missing -join ', ') : cas R3 correspondants non conformes" }
$hasSync = [bool](Get-Command -Name 'Sync-WTargetHead' -CommandType Function -ErrorAction SilentlyContinue)   # RC4 : a la place de Move-WTargetNoteFirst
$isLbl = $lblWProfileInfo -is [System.Windows.Forms.Label]
if ($isLbl) { $lblWProfileInfo.AutoEllipsis = $true }   # comme 520
$d0 = $script:PrecompStdDefault
$cal80 = @(0..79 | ForEach-Object { "$_=$(60 + $_)" }) -join ':'
function Set-R3Store([string]$src = 'A', [string]$tgt = '', [string]$spec = '', [switch]$PerHead) {
    # Magasin des courbes : courbes propres de $src (standard et long track, profil $spec) si $spec, sinon aucune (profils
    # d origine) ; -PerHead : courbes croisees $src>$tgt par tete seulement (calibration croisee faite en ecriture lente)
    $script:DriveCurves = @{}
    if ($spec) { Set-DriveCurve $src 'std' (New-Cv $src '' 'std' $null '20/10/2026 10:00' $spec); Set-DriveCurve $src 'long' (New-Cv $src '' 'long' $null '20/10/2026 11:00' $spec) }
    if ($PerHead) {
        Set-DriveCurve "$src>$tgt" 'std_h0' (New-Cv $src $tgt 'std' 0 '01/11/2026 17:49' '0=51:40=91' 'standard')
        Set-DriveCurve "$src>$tgt" 'std_h1' (New-Cv $src $tgt 'std' 1 '02/11/2026 09:05' '0=53:40=95' 'standard')
    }
    Sync-PrecompCurves $src
}
function Get-R3Label([string]$key, [string]$src, [string]$tgt, [int]$profile = 0, [bool]$slow = $true, [string]$fmt = '(auto)') {
    # Libelle du profil pose par le vrai Update-PrecompForImage (220) ; $tgt vide : sans lecteur cible
    $script:TargetDrives = $(if ($tgt) { @{ $src = $tgt } } else { @{} })
    Set-Ui $profile $slow $true $src; $cmbWFmt.Text = $fmt; $txtWFile.Text = [string]$img[$key]
    Update-PrecompForImage $img[$key]
    return [string]$lblWProfileInfo.Text
}
function Get-R3Head([string]$lang, [string]$kind, [string]$src, [string]$tgt) {
    # Attente ecrite en clair : refus en tete, majuscule initiale, separateur du complement a sa suite (« ; » precede d une
    # espace en francais, « ; » seul en anglais)
    if ($lang -eq 'fr') {
        if ($kind -eq 'none') { return "Aucune courbe croisée $src → $tgt : écriture refusée (« Calibrer pour un lecteur cible… ») ; " }
        if ($kind -eq 'head') { return "Courbes croisées $src → $tgt par tête : écriture rapide refusée (cochez « Écriture lente ») ; " }
        return "Lecteur cible $tgt : écriture refusée en haute densité (la calibration croisée n'existe qu'en double densité) ; "
    }
    if ($kind -eq 'none') { return "Target drive ${tgt}: no cross curve $src → $tgt for this family, write refused (`"Calibrate for a target drive…`"); " }
    if ($kind -eq 'head') { return "Target drive ${tgt}: per-head cross curves $src → $tgt only, fast write refused (check `"Slow write`"); " }
    return "Target drive ${tgt}: write refused in high density (cross calibration exists in double density only); "
}
function Get-R3PrefH([string]$t) {
    # Hauteur preferee du libelle du profil a sa largeur (502 px), comme Test-LabelFits ; 0 sans Label WinForms
    if (-not $isLbl) { return 0 }
    $lblWProfileInfo.Text = $t
    return $lblWProfileInfo.GetPreferredSize((New-Object System.Drawing.Size($lblWProfileInfo.Width, 0))).Height
}
$slowFr = " ; écriture lente : même profil pour les deux têtes (aucune calibration par tête pour cette famille)"

# R3A, R3B, R3C : refus en tete. Attente : libelle avec lecteur cible = tete ecrite en clair (Get-R3Head) + libelle sans
# lecteur cible (vraies fonctions ; ecriture rapide : aucun complement, sauf haute densite : meme mode que le cas, le
# complement « ecriture lente : ... » suit le profil)
$rr = @()
foreach ($lang in 'fr', 'en') {
    $script:Lang = $lang
    foreach ($c in @(
            @('R3A1', 'secteur (.adf), profil d origine', 'none', 'jeu.adf', 0, '(auto)', $true, ''),
            @('R3A2', 'secteur (.adf), profil calibre de 80 valeurs', 'none', 'jeu.adf', 0, '(auto)', $true, $cal80),
            @('R3A3', 'SCP analyse (format ibm.1440)', 'none', 'jeu.scp', 0, 'ibm.1440', $true, ''),
            @('R3A4', 'IPF long track', 'none', 'jeu-long.ipf', 0, '(auto)', $true, ''),
            @('R3A5', 'profil force Long track', 'none', 'jeu.adf', 2, '(auto)', $true, ''),
            @('R3B1', 'par tete, ecriture rapide, profil d origine', 'head', 'jeu.adf', 0, '(auto)', $false, ''),
            @('R3B2', 'par tete, ecriture rapide, profil calibre de 80 valeurs', 'head', 'jeu.adf', 0, '(auto)', $false, $cal80),
            @('R3C1', 'haute densite, ecriture lente', 'hd', 'jeu-hd.img', 0, '(auto)', $true, ''),
            @('R3C2', 'haute densite, ecriture rapide', 'hd', 'jeu-hd.img', 0, '(auto)', $false, ''))) {
        $tg = $(if ($c[2] -eq 'none') { '2' } elseif ($c[2] -eq 'head') { '1' } else { '0' })
        Set-R3Store 'A' $tg $c[7] -PerHead:($c[2] -eq 'head')
        $b = Get-R3Label $c[3] 'A' '' $c[4] $(if ($c[2] -eq 'hd') { $c[6] } else { $false }) $c[5]
        $t = Get-R3Label $c[3] 'A' $tg $c[4] $c[6] $c[5]
        $rr += [pscustomobject]@{ Id = $c[0]; L = $lang; C = $c[1]; T = $t; B = $b; H = (Get-R3Head $lang $c[2] 'A' $tg) }
    }
}
$script:Lang = 'fr'
foreach ($x in $rr) { "  $($x.Id) $($x.L) : $($x.T)" }
function Test-R3Rows([string]$id) { $rs = @($rr | Where-Object { $_.Id -eq $id }); return ($rs.Count -eq 2 -and @($rs | Where-Object { $_.T -ne ($_.H + $_.B) -or -not $_.B }).Count -eq 0) }
function Get-R3Row([string]$id, [string]$lang) { return @($rr | Where-Object { $_.Id -eq $id -and $_.L -eq $lang })[0] }
$fr = Get-R3Row 'R3A1' 'fr'; $en = Get-R3Row 'R3A1' 'en'
Chk 'R3A1' ((Test-R3Rows 'R3A1') -and $fr.T -eq "Aucune courbe croisée A → 2 : écriture refusée (« Calibrer pour un lecteur cible… ») ; Auto : image secteur (.adf) -> standard 2 us ($d0)" -and $en.T -eq ('Target drive 2: no cross curve A → 2 for this family, write refused ("Calibrate for a target drive…"); Auto: sector image (.adf) -> standard 2 us (' + $d0 + ')')) "secteur, profil d origine, aucune courbe croisee A → 2 : refus en tete, majuscule, separateur « ; » (francais) et « ; » (anglais), profil a sa suite"
$fr = Get-R3Row 'R3A2' 'fr'; $en = Get-R3Row 'R3A2' 'en'
Chk 'R3A2' ((Test-R3Rows 'R3A2') -and $fr.B -eq "Auto : image secteur (.adf) -> standard 2 us ($cal80)" -and $en.B -eq "Auto: sector image (.adf) -> standard 2 us ($cal80)" -and $fr.T.Length -gt 500 -and $en.T.Length -gt 500) "secteur, profil calibre de 80 valeurs ($($cal80.Length) car. ; libelles de $($fr.T.Length) et $($en.T.Length) car.) : refus en tete, profil a sa suite, francais et anglais"
$fr = Get-R3Row 'R3A3' 'fr'
Chk 'R3A3' ((Test-R3Rows 'R3A3') -and $fr.B -eq "Auto : SCP (flux mesuré) : cellule 1995 ns, 100250 bits/piste -> standard 2 us ($d0)") "SCP analyse (detail de la detection garde) : refus en tete, francais et anglais"
$fr = Get-R3Row 'R3A4' 'fr'
Chk 'R3A4' ((Test-R3Rows 'R3A4') -and $fr.B -eq "Auto : IPF (bits par piste) : cellule 1890 ns, 105850 bits/piste, 158/160 pistes DOS -> LONG TRACK ($($script:PrecompLongDefault))") "IPF long track (pistes DOS) : refus en tete, francais et anglais"
$fr = Get-R3Row 'R3A5' 'fr'; $en = Get-R3Row 'R3A5' 'en'
Chk 'R3A5' ((Test-R3Rows 'R3A5') -and $fr.B -eq "Profil forcé : long track ($($script:PrecompLongDefault))" -and $en.B -eq "Forced profile: long track ($($script:PrecompLongDefault))") "profil force Long track : refus en tete, francais et anglais"
$fr = Get-R3Row 'R3B1' 'fr'; $en = Get-R3Row 'R3B1' 'en'
Chk 'R3B1' ((Test-R3Rows 'R3B1') -and $fr.T -eq "Courbes croisées A → 1 par tête : écriture rapide refusée (cochez « Écriture lente ») ; Auto : image secteur (.adf) -> standard 2 us ($d0)" -and $en.T -eq ('Target drive 1: per-head cross curves A → 1 only, fast write refused (check "Slow write"); Auto: sector image (.adf) -> standard 2 us (' + $d0 + ')')) "courbes croisees A → 1 par tete seulement, ecriture rapide : refus « par tete » en tete, francais et anglais"
$fr = Get-R3Row 'R3B2' 'fr'
Chk 'R3B2' ((Test-R3Rows 'R3B2') -and $fr.B -eq "Auto : image secteur (.adf) -> standard 2 us ($cal80)") "par tete, ecriture rapide, profil calibre de 80 valeurs : refus « par tete » en tete, francais et anglais"
$fr = Get-R3Row 'R3C1' 'fr'; $en = Get-R3Row 'R3C1' 'en'
$hdFl = "Auto : image haute densité (haute densité 1 440 Ko) -> profil d'origine Haute densité 1 us ($($script:PrecompHdDefault)), non calibré : calibrez le lecteur en haute densité (carte « Calibrer le lecteur » de l'Accueil)"
Chk 'R3C1' ((Test-R3Rows 'R3C1') -and $fr.B -eq ($hdFl + $slowFr) -and $fr.T.EndsWith($slowFr) -and $en.T.EndsWith('; slow write: same profile for both heads (no per-head calibration for this family)')) "haute densite, ecriture lente : refus « haute densite » en tete, complement « ecriture lente : ... » a la suite du profil (avant : refus apres lui), francais et anglais"
$fr = Get-R3Row 'R3C2' 'fr'
Chk 'R3C2' ((Test-R3Rows 'R3C2') -and $fr.B -eq $hdFl) "haute densite, ecriture rapide : refus « haute densite » en tete, profil a sa suite, francais et anglais"

# R3D : sans refus, libelle d avant (memes textes qu avec a2f6b1f)
Set-R3Store 'A' '' $cal80
$t1 = Get-R3Label 'jeu.adf' 'A' '' 0 $true; $n1 = $script:WTargetHead
$script:Lang = 'en'; $t1e = Get-R3Label 'jeu.adf' 'A' '' 0 $true; $script:Lang = 'fr'
Chk 'R3D1' ($t1 -eq "Auto : image secteur (.adf) -> standard 2 us ($cal80)$slowFr" -and $t1e -eq "Auto: sector image (.adf) -> standard 2 us ($cal80); slow write: same profile for both heads (no per-head calibration for this family)" -and -not $n1) "sans lecteur cible, profil calibre de 80 valeurs : libelle d avant, francais et anglais, aucune tete de refus (WTargetHead vide, RC4)"
Set-R3Store 'A'
$t2 = Get-R3Label 'jeu.scp' 'A' '' 0 $true 'ibm.1440'; $t2b = Get-R3Label 'jeu-long.ipf' 'A' '' 0 $true
Chk 'R3D2' ($t2 -eq "Auto : SCP (flux mesuré) : cellule 1995 ns, 100250 bits/piste -> standard 2 us ($d0)$slowFr" -and $t2b -eq "Auto : IPF (bits par piste) : cellule 1890 ns, 105850 bits/piste, 158/160 pistes DOS -> LONG TRACK ($($script:PrecompLongDefault))$slowFr" -and -not $script:WTargetHead) "sans lecteur cible, SCP analyse et IPF long track : libelles d avant, aucune tete de refus (RC4)"
Set-R3Store 'A' '' $cal80
Set-DriveCurve 'A>0' 'std' $xS; Set-DriveCurve 'A>0' 'std_h0' $xH0; Set-DriveCurve 'A>0' 'std_h1' $xH1; Set-DriveCurve 'A>0' 'long' $xL
$t3 = Get-R3Label 'jeu.adf' 'A' '0' 0 $true; $n3 = $script:WTargetHead
$t3b = Get-R3Label 'jeu-long.ipf' 'A' '0' 0 $true; $t3c = Get-R3Label 'jeu.adf' 'A' '0' 2 $true; $t3d = Get-R3Label 'jeu.adf' 'A' '0' 0 $false
Chk 'R3D3' ($t3 -eq $a2 -and $t3b -eq $a7 -and $t3c -eq "Profil forcé : long track (courbe croisée A → 0 pour les deux têtes, test standard, 03/11/2026 11:00, calcul $calc)" -and $t3d -eq "Auto : image secteur (.adf) -> standard 2 us (courbe croisée A → 0, test standard, 01/11/2026 17:49, calcul $calc)" -and -not $n3 -and -not $script:WTargetHead) "lecteur cible 0 avec courbes croisees, lecteur source calibre (80 valeurs) : courbe croisee nommee, libelles d avant (A2, A7, profil force, ecriture rapide), aucune tete de refus (RC4)"

# R3E : image FM/GCR ($nmNote) et flux ecrit tel quel ($fxNote), lecteur cible sans courbe croisee : libelle sans refus
Set-R3Store 'A'
$e1 = Get-R3Label 'jeu.d64' 'A' '2' 0 $true; $e1n = $script:WTargetHead
$e2 = Get-R3Label 'jeu.d64' 'A' '2' 1 $true
$e3 = Get-R3Label 'jeu.raw' 'A' '2' 0 $true; $e3n = $script:WTargetHead
$e4 = Get-R3Label 'jeu.scp' 'A' '2' 0 $true
$fxFr = " ; image flux écrite telle quelle (sans --format) : gw n'applique pas la précompensation, --precomp n'est pas transmis"
"  R3E : tete de refus posee par Sync-WTargetHead (RC4) : GCR $(if ($e1n) { 'oui' } else { 'non' }), flux $(if ($e3n) { 'oui' } else { 'non' }) (aucune attendue : ecriture non refusee)"
Chk 'R3E' ($e1 -eq "Auto : image en codage GCR (extension) -> sans précompensation (--precomp n'est pas transmis)" -and $e2 -eq "Profil forcé : standard 2 us ($d0) ; image en codage GCR (extension) : --precomp n'est pas transmis" -and $e3 -eq "Auto : image flux (.raw) -> standard 2 us ($d0)$fxFr" -and $e4 -eq "Auto : SCP (flux mesuré) : cellule 1995 ns, 100250 bits/piste -> standard 2 us ($d0)$fxFr" -and -not $e1n -and -not $e3n) "lecteur cible 2 sans courbe croisee, GCR (Auto, profil force) et flux tel quel (.raw, SCP sans format) : libelles d avant, sans refus (aucune precompensation transmise), aucune tete posee (RC4)"

# R3F : complement « facteur » (Set-WProfileText) : base reordonnee, Update-WriteFactorNote (vrai, 140) garde l ordre
Set-R3Store 'A'; $script:Lang = 'fr'
$hF = Get-R3Head 'fr' 'none' 'A' '2'; $baseF = "Auto : image secteur (.adf) -> standard 2 us ($d0)"
$f0 = Get-R3Label 'jeu.adf' 'A' '2' 0 $true; $nf0 = $script:WFactorNote
$cF = @(($null -ne $nf0), ([string]$nf0.Note -eq ''), ([string]$nf0.Base -eq ($hF + $baseF)), ($f0 -eq ($hF + $baseF)))
Update-WriteFactorNote; $cF += ($lblWProfileInfo.Text -eq $f0)
$okF0 = @($cF | Where-Object { -not $_ }).Count -eq 0
if (-not $okF0) { "  R3F (facteur 1) : etat $($null -ne $nf0), complement vide $($cF[1]) « $([string]$nf0.Note) », base $($cF[2]) « $([string]$nf0.Base) », libelle $($cF[3]), apres Update-WriteFactorNote $($cF[4]) « $($lblWProfileInfo.Text) »" }
$fn1 = " ; facteur appliqué à l'écriture : tête 0 × 0,85, tête 1 × 0,90"; $fn2 = " ; facteur appliqué à l'écriture : tête 0 × 0,80, tête 1 × 0,95"
$script:R3FactorNote = $fn1
$f1 = Get-R3Label 'jeu.adf' 'A' '2' 0 $true; $nf1 = @{ Base = [string]$script:WFactorNote.Base; Note = [string]$script:WFactorNote.Note }   # copie : Update-WriteFactorNote modifie la table
$script:R3FactorNote = $fn2; Update-WriteFactorNote; $f2 = $lblWProfileInfo.Text; $nf2b = [string]$script:WFactorNote.Base
$script:R3FactorNote = ''; Update-WriteFactorNote; $f3 = $lblWProfileInfo.Text
$script:R3FactorNote = $null
"  R3F : facteur 1 (lecteur cible) : « $f0 » ; complement impose : « $f1 » ; refait : « $f2 » ; vide : « $f3 »"
Chk 'R3F' ($okF0 -and $f1 -eq ($hF + $baseF + $fn1) -and [string]$nf1.Base -eq ($hF + $baseF) -and [string]$nf1.Note -eq $fn1 -and $f2 -eq ($hF + $baseF + $fn2) -and $nf2b -eq ($hF + $baseF) -and $f3 -eq ($hF + $baseF)) "complement « facteur » : vrai (lecteur cible, facteur 1 : vide) et impose (remplacant) : base reordonnee (refus en tete), complement a la fin ; Update-WriteFactorNote refait le complement seul, refus toujours en tete"

# R3G : Sync-WTargetHead (RC4, a la place de Move-WTargetNoteFirst) appele deux fois de plus apres Update-PrecompForImage,
# puis avec -IfOwn : libelle et base inchanges
$g = @()
foreach ($lang in 'fr', 'en') {
    $script:Lang = $lang
    Set-R3Store 'A' '' $cal80
    $t = Get-R3Label 'jeu.adf' 'A' '2' 0 $true; $bs = [string]$script:WFactorNote.Base
    if ($hasSync) { Sync-WTargetHead; Sync-WTargetHead; Sync-WTargetHead -IfOwn }
    $g += [pscustomobject]@{ L = $lang; Ok = ($hasSync -and $lblWProfileInfo.Text -eq $t -and [string]$script:WFactorNote.Base -eq $bs -and $t.StartsWith((Get-R3Head $lang 'none' 'A' '2')) -and $t.IndexOf($(if ($lang -eq 'fr') { ' ; aucune courbe croisée' } else { '; target drive' }), [System.StringComparison]::Ordinal) -lt 0) }
}
$script:Lang = 'fr'
Chk 'R3G' ($hasSync -and @($g | Where-Object { -not $_.Ok }).Count -eq 0) "Sync-WTargetHead $(if ($hasSync) { 'appele deux fois de plus, puis avec -IfOwn' } else { 'absent de la source' }) : libelle et base du complement « facteur » inchanges, refus une seule fois, en tete (francais et anglais)"

# R3M : mesure hors ecran (libelle du profil 502 x 40 ; 12.11, lot L9 : 458 x 58, taille lue dans 520 ; Segoe UI 9,75, rendu
# compatible) : le refus, son separateur et des
# points de suspension tiennent en deux lignes (condition suffisante : le refus reste entier quand le libelle depasse)
if ($isLbl) {
    $mm = @()
    foreach ($lang in 'fr', 'en') {
        $script:Lang = $lang
        foreach ($pr in @(@('A', '0'), @('0', 'A'), @('B', '2'), @('2', 'B'))) {
            $s = $pr[0]; $tg = $pr[1]
            foreach ($k in 'none', 'head', 'hd') {
                if ($k -eq 'hd') { Set-R3Store $s; $t = Get-R3Label 'jeu-hd.img' $s $tg 0 $true }
                else { Set-R3Store $s $tg $cal80 -PerHead:($k -eq 'head'); $t = Get-R3Label 'jeu.adf' $s $tg 0 ($k -ne 'head') }
                $h = Get-R3Head $lang $k $s $tg
                $mm += [pscustomobject]@{ L = $lang; P = "$s/$tg"; K = $k; Head = $t.StartsWith($h); HC = (Get-R3PrefH $h.TrimEnd(' ', ';')); HP = (Get-R3PrefH ($h.TrimEnd() + '…')); HA = (Get-R3PrefH $t); N = $t.Length }
            }
        }
    }
    $script:Lang = 'fr'
    $hh = $lblWProfileInfo.Height
    $mm | Group-Object L, K | ForEach-Object { "  R3M $($_.Name) : en tete $(@($_.Group | Where-Object { $_.Head }).Count)/$($_.Count) ; refus seul $(($_.Group | Measure-Object HC -Maximum).Maximum) px, avec separateur et points de suspension $(($_.Group | Measure-Object HP -Maximum).Maximum) px au plus ; libelle entier $(($_.Group | Measure-Object HA -Minimum).Minimum) a $(($_.Group | Measure-Object HA -Maximum).Maximum) px ($(($_.Group | Measure-Object N -Maximum).Maximum) car. au plus)" }
    $bad = @($mm | Where-Object { -not $_.Head -or $_.HP -gt $hh })
    $over = @($mm | Where-Object { $_.K -ne 'hd' -and $_.HA -le $hh })
    Chk 'R3M' ($mm.Count -eq 24 -and $bad.Count -eq 0 -and $over.Count -eq 0 -and $fontOk -and $lblWProfileInfo.UseCompatibleTextRendering) "$($mm.Count) libelles (paires A/0, 0/A, B/2, 2/B ; aucune courbe croisee et par tete avec un profil de 80 valeurs, haute densite ; francais et anglais) : refus en tete et tenant en deux lignes de $($lblWProfileInfo.Width) x $hh px, libelles entiers de plus de deux lignes (profil de 80 valeurs) ; rendu compatible $($lblWProfileInfo.UseCompatibleTextRendering)$(if ($bad.Count) { ' ; hors attente : ' + (($bad | ForEach-Object { "$($_.L) $($_.P) $($_.K)" }) -join ', ') })"
} else { Chk 'R3M' $false 'libelle WinForms indisponible : R3M non joue' }

# Information hors R3 : image haute densite non calibrable (remplacant « -ed ») avec un lecteur cible
Set-R3Store 'A'
$tEd = Get-R3Label 'jeu-ed.img' 'A' '0' 0 $true; $nEd = $script:WTargetHead
$bEd = Get-TargetWriteBlock $img['jeu-ed.img'] '(auto)' $true
"  info : haute densite non calibrable, lecteur cible 0 : libelle « $tEd » ; refus de l ecriture (Get-TargetWriteBlock) : $(if ($bEd) { "« $bEd »" } else { 'aucun' })"
# fix1 (RC3-D2, m1) : refus annonce en tete du libelle, comme pour la haute densite calibrable ; sans lecteur cible : libelle
# d avant, aucun complement ; anglais de meme ; ecriture lente et rapide
$tEd0 = Get-R3Label 'jeu-ed.img' 'A' '' 0 $true; $nEd0 = $script:WTargetHead
$tEdR = Get-R3Label 'jeu-ed.img' 'A' '0' 0 $false; $tEdR0 = Get-R3Label 'jeu-ed.img' 'A' '' 0 $false
$script:Lang = 'en'; $tEdE = Get-R3Label 'jeu-ed.img' 'A' '0' 0 $true; $tEdE0 = Get-R3Label 'jeu-ed.img' 'A' '' 0 $true; $script:Lang = 'fr'
$script:TargetDrives = @{}
"  R3H : sans lecteur cible « $tEd0 » ; anglais « $tEdE »"
Chk 'R3H' ($tEd -eq ((Get-R3Head 'fr' 'hd' 'A' '0') + $tEd0) -and $tEdR -eq ((Get-R3Head 'fr' 'hd' 'A' '0') + $tEdR0) -and $tEdE -eq ((Get-R3Head 'en' 'hd' 'A' '0') + $tEdE0) `
    -and $tEd0 -eq "Auto : image haute densité (extra-haute densité 2 880 Ko) -> profil d'origine Standard 2 us ($d0) : calibration non disponible pour cette image" -and $nEd -and -not $nEd0 -and $bEd) `
    "haute densite non calibrable (« -ed »), lecteur cible 0 : refus « haute densite » en tete du libelle, profil d origine a sa suite, ecriture lente et rapide, francais et anglais ; sans lecteur cible : libelle d avant, aucune tete posee (RC4 : WTargetHead) ; ecriture refusee (Get-TargetWriteBlock)"

# R3W : libelle de la calibration (lblWCal) construit comme dans 520 dans $grpWOpt (762 px, New-Group de 100), police
# heritee d un parent en Segoe UI 9,75 ; vrais Set-WCalVerdict, Clear-WCalVerdict (195), Update-WCalTip (140) par les
# gestionnaires de 520 ; aucune fenetre
if ($wfOk) {
    if ($null -eq $tip) { $tip = New-Object System.Windows.Forms.ToolTip }
    $script:WCalIcon = $null; $script:Lang = 'fr'
    $lblWCalSim = $lblWCal                                # controle simule des cas D (270), retabli apres R3W
    . $genW
    $hW0 = $lblWCal.Height; $fW0 = "$($lblWCal.Font.Name) $($lblWCal.Font.SizeInPoints)"
    $grpWOpt.Controls.Add($lblWCal)                       # 520 : $grpWOpt.Controls.AddRange(@(..., $lblWCal, ...))
    $hostW = New-Object System.Windows.Forms.Panel; $hostW.Size = New-Object System.Drawing.Size(800, 400)
    $hostW.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
    $hostW.Controls.Add($grpWOpt)
    $drR = $grpWOpt.DisplayRectangle.Right
    "  R3W : lblWCal avant le parent : $fW0, hauteur $hW0 px ; apres : $($lblWCal.Font.Name) $($lblWCal.Font.SizeInPoints), $($lblWCal.Width) x $($lblWCal.Height) px (PreferredHeight $($lblWCal.PreferredHeight)) ; groupe $($grpWOpt.Width) px, DisplayRectangle.Right $drR"
    Chk 'R3W1' (-not $lblWCal.AutoSize -and $lblWCal.AutoEllipsis -and $lblWCal.Anchor -eq [System.Windows.Forms.AnchorStyles]'Top, Left, Right' -and $lblWCal.Left -eq 320 -and $lblWCal.Width -eq ($drR - 320) -and $lblWCal.Right -eq $drR -and $lblWCal.Font.Name -eq 'Segoe UI' -and $lblWCal.Font.SizeInPoints -eq 9.75 -and $lblWCal.Height -eq $lblWCal.PreferredHeight -and $lblWCal.UseCompatibleTextRendering) "construit comme dans 520 : AutoSize faux, AutoEllipsis vrai, ancre Top, Left, Right, largeur $($lblWCal.Width) px = DisplayRectangle.Right - 320, hauteur $($lblWCal.Height) px = PreferredHeight apres rattachement (police heritee Segoe UI 9,75)"
    $v = ((T "CONTRÔLE APRÈS ÉCRITURE : {0}/{1} pistes saines") -f '160', '160') + ((T " (relu par le lecteur {0}, pas par le lecteur cible {1})") -f 'A', '0')
    Set-WCalVerdict $v 'h0'
    $tt1 = $tip.GetToolTip($lblWCal); $pd1 = $lblWCal.Padding.Left; $pw1 = $lblWCal.PreferredWidth; $wd1 = $lblWCal.Width
    $lblWCal.Text = (T 'Calibrations effacées.')
    $tt2 = $tip.GetToolTip($lblWCal); $pd2 = $lblWCal.Padding.Left; $ic2 = $script:WCalIcon
    $script:Lang = 'en'
    $ve = ((T "CONTRÔLE APRÈS ÉCRITURE : {0}/{1} pistes saines") -f '160', '160') + ((T " (relu par le lecteur {0}, pas par le lecteur cible {1})") -f 'A', '0')
    Set-WCalVerdict $ve 'h0'; $tt3 = $tip.GetToolTip($lblWCal)
    $lblWCal.Text = (T 'Calibrations effacées.'); $tt4 = $tip.GetToolTip($lblWCal)
    $script:Lang = 'fr'
    "  R3W2 : verdict $pw1 px pour $wd1 px (marge $pd1 px) : infobulle $(if ($tt1 -eq $v) { 'texte complet' } elseif ($tt1) { "« $tt1 »" } else { 'aucune' }) ; « Calibrations effacées. » (marge $pd2 px) : infobulle $(if ($tt2) { "« $tt2 »" } else { 'aucune' }) ; anglais : $(if ($tt3 -eq $ve) { 'texte complet' } elseif ($tt3) { "« $tt3 »" } else { 'aucune' }) puis $(if ($tt4) { "« $tt4 »" } else { 'aucune' })"
    Chk 'R3W2' ($v -eq 'CONTRÔLE APRÈS ÉCRITURE : 160/160 pistes saines (relu par le lecteur A, pas par le lecteur cible 0)' -and $pd1 -eq 20 -and $pw1 -gt $wd1 -and $wd1 -eq ($drR - 320) -and $tt1 -eq $v -and $tt2 -eq '' -and $pd2 -eq 0 -and $null -eq $ic2 -and $ve -eq 'POST-WRITE CHECK: 160/160 healthy tracks (read back by drive A, not by target drive 0)' -and $tt3 -eq $ve -and $tt4 -eq '') "verdict du controle pour un lecteur cible (marge de 20 px de l icone) : infobulle du texte complet ; « Calibrations effacees. » : verdict retire, aucune infobulle ; francais et anglais"
    # Marge et taille : largeur portee a la largeur preferee du texte + 10 px (groupe elargi, libelle ancre a droite)
    $t3w = (T 'Calibration croisée : déplacez la disquette du lecteur {0} vers le lecteur {1}') -f 'A', '0'
    $lblWCal.Text = $t3w
    $pw0 = $lblWCal.PreferredWidth; $gw0 = $grpWOpt.Width; $lw0 = $lblWCal.Width
    $grpWOpt.Width = $gw0 + ($pw0 + 10 - $lw0)
    $lwA = $lblWCal.Width; $ttA = $tip.GetToolTip($lblWCal)
    $lblWCal.Padding = New-Object System.Windows.Forms.Padding(20, 0, 0, 0); $ttB = $tip.GetToolTip($lblWCal)
    $grpWOpt.Width = $grpWOpt.Width + 15; $lwC = $lblWCal.Width; $ttC = $tip.GetToolTip($lblWCal)
    $grpWOpt.Width = $grpWOpt.Width - 15; $ttD = $tip.GetToolTip($lblWCal)
    $lblWCal.Padding = New-Object System.Windows.Forms.Padding(0); $ttE = $tip.GetToolTip($lblWCal)
    $grpWOpt.Width = $gw0; $lwF = $lblWCal.Width
    $q = { param($x) if ($x -eq $t3w) { 'texte' } elseif ($x) { "« $x »" } else { 'aucune' } }
    "  R3W3 : texte de $pw0 px, libelle de $lwA px : marge 0 -> $(& $q $ttA) ; marge 20 -> $(& $q $ttB) ; libelle de $lwC px -> $(& $q $ttC) ; retour a $lwA px -> $(& $q $ttD) ; marge 0 -> $(& $q $ttE) ; groupe rendu a $gw0 px : libelle de $lwF px"
    Chk 'R3W3' ($lwA -eq ($pw0 + 10) -and $ttA -eq '' -and $ttB -eq $t3w -and $lwC -eq ($pw0 + 25) -and $ttC -eq '' -and $ttD -eq $t3w -and $ttE -eq '' -and $lwF -eq $lw0) "infobulle mise a jour au changement de marge (PaddingChanged) et de taille (SizeChanged, libelle ancre a droite du groupe)"
    # fix1 (B1) : attente du controle de surface (270) entiere sur la ligne du libelle : aucune infobulle, lecteurs A, B,
    # 0 a 3, francais et anglais ; texte d avant mesure pour memoire
    $w4 = @()
    foreach ($lang in 'fr', 'en') {
        $script:Lang = $lang
        foreach ($dv in 'A', 'B', '0', '1', '2', '3') {
            $lblWCal.Text = (T "Calibration en attente : décision sur le contrôle de surface (lecteur {0}).") -f $dv
            $w4 += [pscustomobject]@{ L = $lang; D = $dv; PW = $lblWCal.PreferredWidth; W = $lblWCal.Width; Tip = [string]$tip.GetToolTip($lblWCal) }
        }
    }
    $script:Lang = 'fr'
    $lblWCal.Text = 'Calibration en attente : contrôle de surface, décision demandée (lecteur A).'; $pwOld = $lblWCal.PreferredWidth
    "  R3W4 : attente du controle de surface : $(($w4 | Where-Object { $_.L -eq 'fr' } | Measure-Object PW -Maximum).Maximum) px au plus en francais, $(($w4 | Where-Object { $_.L -eq 'en' } | Measure-Object PW -Maximum).Maximum) px en anglais, libelle de $($lblWCal.Width) px ; texte d avant (lecteur A) $pwOld px"
    Chk 'R3W4' ($w4.Count -eq 12 -and @($w4 | Where-Object { $_.PW -gt $_.W -or $_.Tip }).Count -eq 0) "attente du controle de surface entiere sur la ligne de lblWCal (aucune infobulle), lecteurs A, B, 0 a 3, francais et anglais"
    # fix1 (m2) : avertissement de fin de calibration en tete (270 $convHead) : entier sur la ligne du libelle, texte complet
    # (bilan d une calibration croisee) en infobulle
    $w5 = @()
    foreach ($lang in 'fr', 'en') {
        $script:Lang = $lang
        foreach ($c in @((T ' NON CONVERGÉE : voir le journal et la fenêtre Courbe.'), ((T ' Limite de précompensation atteinte (0 ou {0} ns) : voir le journal.') -f '400'))) {
            $lblWCal.Text = $c.Trim(); $hw = $lblWCal.PreferredWidth
            $full = $c.Trim() + ' ' + ((T "Calibration croisée terminée en {0}, {1} échange(s) de disquette") -f '12 min 05 s', '13')
            $lblWCal.Text = $full
            $w5 += [pscustomobject]@{ L = $lang; HW = $hw; W = $lblWCal.Width; PW = $lblWCal.PreferredWidth; Ok = ([string]$tip.GetToolTip($lblWCal) -eq $full) }
        }
    }
    $script:Lang = 'fr'
    "  R3W5 : avertissements de $(($w5 | Measure-Object HW -Minimum).Minimum) a $(($w5 | Measure-Object HW -Maximum).Maximum) px pour $($lblWCal.Width) px ; bilans complets de $(($w5 | Measure-Object PW -Minimum).Minimum) a $(($w5 | Measure-Object PW -Maximum).Maximum) px"
    Chk 'R3W5' ($w5.Count -eq 4 -and @($w5 | Where-Object { $_.HW -gt $_.W -or $_.PW -le $_.W -or -not $_.Ok }).Count -eq 0) "avertissement de fin (non convergee, limite atteinte) en tete d un bilan de calibration croisee : entier sur la ligne de lblWCal, bilan complet en infobulle, francais et anglais"
    $lblWCal.Text = ''; $hostW.Dispose(); $lblWCal = $lblWCalSim; $script:WCalIcon = $null
} else { Chk 'R3W1' $false 'WinForms indisponible : R3W non joue' }

# R3K (fix1, m3) : description de la carte « Calibrer le lecteur » construite comme dans 540 (Label 306 x 44 de New-HomeCard,
# 100 ; police de la fenetre, Segoe UI 9,75 dans 500) ; vrai Update-HomeCalDescTip (200) par le gestionnaire de 540
$hasDescTip = [bool](Get-Command -Name 'Update-HomeCalDescTip' -CommandType Function -ErrorAction SilentlyContinue)
if ($wfOk) {
    if ($null -eq $tip) { $tip = New-Object System.Windows.Forms.ToolTip }
    $lblD = New-Object System.Windows.Forms.Label
    $lblD.Text = 'Choisir un type de disquette, voir sa courbe et calibrer le lecteur : complète ou rapide.'; $lblD.Location = '58,34'; $lblD.Size = '306,44'
    $hostK = New-Object System.Windows.Forms.Panel; $hostK.Size = New-Object System.Drawing.Size(373, 84); $hostK.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
    $hostK.Controls.Add($lblD)
    $cardCalib = [pscustomobject]@{ Controls = @($null, $null, $null, $lblD) }
    . $genK
    $k = @()
    foreach ($lang in 'fr', 'en') {
        $script:Lang = $lang
        $lim = ((T ' Limite de précompensation atteinte (0 ou {0} ns) : voir le journal.') -f '400').Trim()
        $end = (T 'Calibration terminée en {0}') -f '12 min 05 s'
        foreach ($c in @(@('tete', ($lim + ' ' + $end)), @('suite (51606c1)', ($end + ' ' + $lim)), @('court', $end))) {
            $lblD.Text = $c[1]
            $ph = $lblD.GetPreferredSize((New-Object System.Drawing.Size($lblD.Width, 0))).Height
            $k += [pscustomobject]@{ L = $lang; C = $c[0]; PH = $ph; Long = ($ph -gt $lblD.Height); Tip = [string]$tip.GetToolTip($lblD); T = $c[1] }
        }
    }
    $script:Lang = 'fr'
    $lblD.Text = 'Choisir un type de disquette, voir sa courbe et calibrer le lecteur : complète ou rapide.'; $tipS = [string]$tip.GetToolTip($lblD)
    $k | ForEach-Object { "  R3K $($_.L), $($_.C) : hauteur preferee $($_.PH) / $($lblD.Height) px ; infobulle $(if ($_.Tip -eq $_.T) { 'texte complet' } elseif ($_.Tip) { "« $($_.Tip) »" } else { 'aucune' })" }
    # attendu : infobulle = texte complet au-dela de deux lignes, aucune sinon ; bilan « limite atteinte » a la suite (texte
    # de la relecture, 57 px) au-dela de deux lignes ; bilan court en deux lignes au plus
    $badK = @($k | Where-Object { ($_.Long -and $_.Tip -ne $_.T) -or (-not $_.Long -and $_.Tip) -or ($_.C -like 'suite*' -and -not $_.Long) -or ($_.C -eq 'court' -and $_.Long) })
    Chk 'R3K' ($hasDescTip -and $card.Count -eq 2 -and $lblD.AutoEllipsis -and $badK.Count -eq 0 -and $tipS -eq '' -and $lblD.Font.Name -eq 'Segoe UI') "description de la carte « Calibrer le lecteur » (306 x 44) : points de suspension (540), bilan avec « Limite de precompensation atteinte » au-dela de deux lignes : texte complet en infobulle ; bilan court et description d origine : aucune infobulle ; francais et anglais$(if (-not $hasDescTip) { ' ; Update-HomeCalDescTip absente de la source' })"
    $hostK.Dispose(); Remove-Variable cardCalib
} else { Chk 'R3K' $false 'WinForms indisponible : R3K non joue' }

Reset-Store; $script:TargetDrives = @{}; $script:Lang = 'fr'; Set-Ui 0 $true; $script:R3FactorNote = $null; $txtWFile.Text = ''
if ($isLbl) { $lblWProfileInfo.Text = '' }

"--- P1 (correction tour 2 de la RC3) : case --precomp decochee : refus du lecteur cible retire du libelle du profil, remis quand elle est recochee (220 Sync-WTargetHead -IfOwn depuis la RC4, gestionnaire CheckedChanged de 520)"
$hasPc = [bool](Get-Command -Name 'Sync-WTargetHead' -CommandType Function -ErrorAction SilentlyContinue)   # RC4 : a la place d Update-WTargetNoteForPrecomp
$pcSt = @((Get-FAst (Get-FMod '520')).EndBlock.Statements | Where-Object { $_.Extent.Text -match '^\$chkWPrecomp\.Add_CheckedChanged' } | ForEach-Object { $_.Extent.Text })
$pcReal = $wfOk -and $isLbl -and $pcSt.Count -eq 1
"  520 : $($pcSt.Count) instruction(s) « `$chkWPrecomp.Add_CheckedChanged » ; Sync-WTargetHead $(if ($hasPc) { 'presente' } else { 'ABSENTE' }) ; vraie case $pcReal"
$chkSim = $chkWPrecomp; $uiSv = $script:UiReady; $ssSv = $script:SettingSync
if ($pcReal) {
    # vraie case : CheckedChanged leve a chaque changement d etat, y compris par le code (Set-PrecompFields la recoche)
    $chkWPrecomp = New-Object System.Windows.Forms.CheckBox
    $chkWPrecomp.Checked = $true
    $genP = Join-Path $here 'gen-1210-final-ac-precomp.ps1'
    [System.IO.File]::WriteAllText($genP, ($pcSt[0] + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
    . $genP
}
$script:UiReady = $true; $script:SettingSync = $false; $script:WProfileBuilding = $false
function Set-PcBox([bool]$on) { $chkWPrecomp.Checked = $on }
function Get-PcInfo([string]$key, [bool]$slow) { return (Get-TargetWriteInfo ([string]$img[$key]) '(auto)' $slow) }
Chk 'P1W' ($pcReal -and $hasPc -and $pcSt[0].Contains('Sync-WTargetHead -IfOwn') -and $pcSt[0].Contains('$script:UiReady') -and $pcSt[0].Contains('$script:SettingSync') -and $pcSt[0].Contains('-not $script:WProfileBuilding')) "520 : gestionnaire CheckedChanged de la case --precomp (apres UiReady, hors SettingSync, hors Update-PrecompForImage : WProfileBuilding) qui appelle Sync-WTargetHead -IfOwn (RC4), joue sur une vraie case WinForms"

# P1A : refus en tete (aucune courbe croisee, par tete en ecriture rapide, haute densite calibrable, haute densite non
# calibrable), francais et anglais. Case decochee : libelle = libelle d avant sans le refus en tete, ecriture non refusee
# (Get-TargetWriteInfo : Why « precompensation desactivee », Block vide) ; recochee : libelle et refus d avant
$pa = @()
foreach ($lang in 'fr', 'en') {
    foreach ($c in @(@('none', 'jeu.adf', $false), @('head', 'jeu.adf', $false), @('hd', 'jeu-hd.img', $true), @('hd', 'jeu-ed.img', $true))) {
        $script:Lang = $lang
        if ($c[0] -eq 'head') { Set-R3Store 'A' '0' '' -PerHead } else { Set-R3Store 'A' '' $cal80 }
        $l0 = Get-R3Label $c[1] 'A' '0' 0 $c[2]
        $h = Get-R3Head $lang $c[0] 'A' '0'
        $b0 = [string](Get-PcInfo $c[1] $c[2]).Block
        Set-PcBox $false
        $l1 = [string]$lblWProfileInfo.Text; $i1 = Get-PcInfo $c[1] $c[2]
        Set-PcBox $true
        $l2 = [string]$lblWProfileInfo.Text; $b2 = [string](Get-PcInfo $c[1] $c[2]).Block
        $ok = $l0.StartsWith($h, [System.StringComparison]::Ordinal) -and $l0.Length -gt $h.Length -and $b0 -and $l1 -eq $l0.Substring($h.Length) `
            -and -not [string]$i1.Block -and [string]$i1.Why -eq (T 'précompensation désactivée') -and $l2 -eq $l0 -and $b2 -eq $b0
        $pa += [pscustomobject]@{ Id = "$lang/$($c[0])/$($c[1])"; Ok = $ok; L0 = $l0; L1 = $l1; L2 = $l2; Why = [string]$i1.Why }
    }
}
$script:Lang = 'fr'
foreach ($x in @($pa | Where-Object { -not $_.Ok })) { "  P1A $($x.Id) : avant « $($x.L0) » ; decochee « $($x.L1) » (Why « $($x.Why) ») ; recochee « $($x.L2) »" }
$x = $pa[0]; "  P1A fr/none : avant « $($x.L0) » ; decochee « $($x.L1) »"
Chk 'P1A' ($hasPc -and $pcReal -and @($pa | Where-Object { -not $_.Ok }).Count -eq 0) "$($pa.Count) cas (aucune courbe croisee, par tete en ecriture rapide, haute densite calibrable et non calibrable ; francais et anglais) : case decochee, libelle sans le refus, reste inchange, ecriture non refusee (precompensation desactivee) ; recochee, libelle et refus d avant"

# P1E : complement « facteur » (Set-WProfileText, Update-WriteFactorNote vrai) : case decochee, base sans le refus et
# libelle = base + complement ; recochee : base et libelle d avant, complement refait a la suite
$script:Lang = 'fr'; Set-R3Store 'A'
$fnE = " ; facteur appliqué à l'écriture : tête 0 × 0,85, tête 1 × 0,90"; $fnE2 = " ; facteur appliqué à l'écriture : tête 0 × 0,80, tête 1 × 0,95"
$script:R3FactorNote = $fnE
$e0 = Get-R3Label 'jeu.adf' 'A' '2' 0 $true; $hE = Get-R3Head 'fr' 'none' 'A' '2'; $eb0 = [string]$script:WFactorNote.Base
Set-PcBox $false
$e1 = [string]$lblWProfileInfo.Text; $eb1 = [string]$script:WFactorNote.Base
Set-PcBox $true
$e2 = [string]$lblWProfileInfo.Text; $eb2 = [string]$script:WFactorNote.Base
$script:R3FactorNote = $fnE2; Update-WriteFactorNote; $e3 = [string]$lblWProfileInfo.Text
$script:R3FactorNote = $null
"  P1E : avant « $e0 » ; decochee « $e1 » ; recochee « $e2 » ; complement refait « $e3 »"
Chk 'P1E' ($hasPc -and $pcReal -and $eb0.StartsWith($hE, [System.StringComparison]::Ordinal) -and $e0 -eq ($eb0 + $fnE) -and $eb1 -eq $eb0.Substring($hE.Length) -and $e1 -eq ($eb1 + $fnE) -and $eb2 -eq $eb0 -and $e2 -eq $e0 -and $e3 -eq ($eb0 + $fnE2)) "complement « facteur » : case decochee, base sans le refus et libelle = base + complement ; recochee, base et libelle d avant ; Update-WriteFactorNote refait ensuite le complement a la suite de la base (refus en tete)"

# P1F : sans refus (meme lecteur ; lecteur cible avec courbe croisee ; profil Manuel) : decocher puis recocher ne change
# pas le libelle
$pf = @()
foreach ($c in @(@('', 0), @('0', 0), @('0', 3))) {
    Reset-Store; $script:Lang = 'fr'
    $t0 = Get-R3Label 'jeu.adf' 'A' $c[0] $c[1] $false
    Set-PcBox $false; $t1 = [string]$lblWProfileInfo.Text
    Set-PcBox $true; $t2 = [string]$lblWProfileInfo.Text
    $pf += [pscustomobject]@{ Id = "cible '$($c[0])', profil $($c[1])"; Ok = ($t0 -and $t1 -eq $t0 -and $t2 -eq $t0 -and [string]$script:WTargetHead -eq ''); T = $t0 }
}
foreach ($x in $pf) { "  P1F $($x.Id) : « $($x.T) » $(if ($x.Ok) { 'inchange' } else { 'CHANGE' })" }
Chk 'P1F' ($hasPc -and $pcReal -and @($pf | Where-Object { -not $_.Ok }).Count -eq 0) "sans refus (meme lecteur, lecteur cible avec courbe croisee, profil Manuel) : libelle inchange, case decochee puis recochee"

# P1G : libelle pose ailleurs apres la case decochee (fin de calibration...) : la recocher n y ajoute rien ;
# Update-PrecompForImage refait le libelle (refus en tete) et oublie le libelle raccourci
$script:Lang = 'fr'; Set-R3Store 'A' '' $cal80
$g0 = Get-R3Label 'jeu.adf' 'A' '0' 0 $false
Set-PcBox $false
$gO = 'Profils Standard 2 us de cette disquette (mesure complète du 10/11/2026 09:00, lecteur A) : tête 0 de 60 à 139 ns.'
$lblWProfileInfo.Text = $gO
Set-PcBox $true; $g1 = [string]$lblWProfileInfo.Text
Update-PrecompForImage $img['jeu.adf']; $g2 = [string]$lblWProfileInfo.Text; $gc = [string]$script:WProfileLabel
Chk 'P1G' ($hasPc -and $pcReal -and $g1 -eq $gO -and $g2 -eq $g0 -and $gc -eq $g2 -and $g0.StartsWith((Get-R3Head 'fr' 'none' 'A' '0'), [System.StringComparison]::Ordinal)) "libelle change entre-temps : recocher la case n y ajoute pas le refus ; Update-PrecompForImage refait le libelle, refus en tete, libelle du profil retenu par Sync-WTargetHead (WProfileLabel) = libelle refait"

# P1H : sequence des retablissements (Restore-WriteTabState 300, Restore-CalibState 250, champs d avant d une calibration
# 260/270) : case decochee par l utilisateur, libelle copie ; Update-PrecompForImage (Set-PrecompFields recoche la case :
# gestionnaire joue avant que le refus soit pose, sans effet) ; case et libelle d avant remis ; recochee : refus en tete
$h0 = Get-R3Label 'jeu.adf' 'A' '0' 0 $false; $hH = Get-R3Head 'fr' 'none' 'A' '0'
Set-PcBox $false; $prev = [string]$lblWProfileInfo.Text
Update-PrecompForImage $img['jeu.adf']; $hm = [string]$lblWProfileInfo.Text; $hmc = [bool]$chkWPrecomp.Checked
Set-PcBox $false; $hx = [string]$lblWProfileInfo.Text; $lblWProfileInfo.Text = $prev
$hb = [string](Get-PcInfo 'jeu.adf' $false).Block
Set-PcBox $true; $h2 = [string]$lblWProfileInfo.Text
"  P1H : avant « $h0 » ; decochee « $prev » ; apres Update-PrecompForImage « $hm » (case $hmc) ; recochee « $h2 »"
Chk 'P1H' ($hasPc -and $pcReal -and $prev -eq $h0.Substring($hH.Length) -and $hm -eq $h0 -and $hmc -and $hx -eq $prev -and -not $hb -and $h2 -eq $h0) "case decochee, Update-PrecompForImage (case recochee par Set-PrecompFields, refus en tete), case decochee de nouveau (refus retire) et libelle d avant remis : ecriture non refusee ; recochee : refus en tete"

# P1K : gardes du gestionnaire : avant UiReady ou sous SettingSync, la case decochee ne touche pas au libelle
$kk = @()
foreach ($gd in 'UiReady', 'SettingSync', 'WProfileBuilding') {
    $k0 = Get-R3Label 'jeu.adf' 'A' '0' 0 $false
    if ($gd -eq 'UiReady') { $script:UiReady = $false } elseif ($gd -eq 'SettingSync') { $script:SettingSync = $true } else { $script:WProfileBuilding = $true }
    Set-PcBox $false; $k1 = [string]$lblWProfileInfo.Text
    $script:UiReady = $true; $script:SettingSync = $false; $script:WProfileBuilding = $false
    $kk += ($k1 -eq $k0 -and $k0.StartsWith($hH, [System.StringComparison]::Ordinal))
    Set-PcBox $true
}
Chk 'P1K' ($hasPc -and $pcReal -and @($kk | Where-Object { -not $_ }).Count -eq 0) "gestionnaire sans effet avant UiReady, sous SettingSync et pendant Update-PrecompForImage (WProfileBuilding, RC4) : libelle inchange, refus en tete"

if ($pcReal) { $chkWPrecomp.Dispose() }
$chkWPrecomp = $chkSim; $script:UiReady = $uiSv; $script:SettingSync = $ssSv
Reset-Store; $script:TargetDrives = @{}; $script:Lang = 'fr'; Set-Ui 0 $true; $script:R3FactorNote = $null; $txtWFile.Text = ''
if ($isLbl) { $lblWProfileInfo.Text = '' }

"--- R4 (RC4, 789c19d) : refus du lecteur cible annonce d apres le refus reel de l ecriture (220 Sync-WTargetHead, Get-WTargetHead ; 140 Get-TargetWriteInfo), phrase du lecteur cible en tete du cadre de la restauration (300 Get-RsCalibText)"
$hasSyncR4 = [bool](Get-Command -Name 'Sync-WTargetHead' -CommandType Function -ErrorAction SilentlyContinue)
$hasHeadR4 = [bool](Get-Command -Name 'Get-WTargetHead' -CommandType Function -ErrorAction SilentlyContinue)
$hasRsR4 = [bool](Get-Command -Name 'Get-RsCalibText' -CommandType Function -ErrorAction SilentlyContinue)
"  source : Sync-WTargetHead $(if ($hasSyncR4) { 'presente' } else { 'ABSENTE' }), Get-WTargetHead $(if ($hasHeadR4) { 'presente' } else { 'ABSENTE' }), Get-RsCalibText $(if ($hasRsR4) { 'presente' } else { 'ABSENTE' }) ; fonctions et etat retires par 789c19d encore presents : $(if ($r4Old.Count) { $r4Old -join ', ' } else { 'aucun' })"
# Vraie case --precomp et gestionnaire CheckedChanged de 520 recopie a l identique (instruction de premier niveau, comme
# pour les cas P1) ; les appels directs des fonctions de 789c19d sont gardes (source d avant : cas non conformes, sans arret)
$r4Real = $wfOk -and $isLbl -and $pcSt.Count -eq 1
$chkSim4 = $chkWPrecomp; $uiSv4 = $script:UiReady; $ssSv4 = $script:SettingSync
if ($r4Real) {
    $chkWPrecomp = New-Object System.Windows.Forms.CheckBox
    $chkWPrecomp.Checked = $true
    $genP4 = Join-Path $here 'gen-1210-final-ac-precomp.ps1'
    [System.IO.File]::WriteAllText($genP4, ($pcSt[0] + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
    . $genP4
}
$script:UiReady = $true; $script:SettingSync = $false; $script:R3FactorNote = $null
"  520 : $($pcSt[0])"
# Image FM : remplacant de la detection du codage etendu (« -fm » -> FM, comme .d64 -> GCR)
$p4 = Join-Path $imgDir 'jeu-fm.img'; [System.IO.File]::WriteAllBytes($p4, [byte[]](1, 2, 3, 4)); $img['jeu-fm.img'] = $p4
function Get-ImageEncoding([string]$path, [string]$fmt) {
    if ([System.IO.Path]::GetFileName("$path") -like '*-fm*') { return @{ Enc = 'fm'; Src = 'format'; Name = 'FM'; NonMfm = $true } }
    if ([System.IO.Path]::GetExtension("$path").ToLower() -eq '.d64') { return @{ Enc = 'gcr'; Src = 'extension'; Name = 'GCR'; NonMfm = $true } }
    return @{ Enc = 'mfm'; Src = 'extension'; Name = 'MFM'; NonMfm = $false }
}
function Set-R4Store([string]$state, [string]$src = 'A', [string]$tgt = '0') {
    # Courbes croisees $src>$tgt : 'commune' (standard et long track communes), 'tete' (standard par tete seulement),
    # 'aucune' ; aucune courbe propre de $src (profils d origine)
    $script:DriveCurves = @{}
    if ($state -eq 'commune') {
        Set-DriveCurve "$src>$tgt" 'std' (New-Cv $src $tgt 'std' $null '01/11/2026 17:49' '0=40:40=80' 'standard')
        Set-DriveCurve "$src>$tgt" 'long' (New-Cv $src $tgt 'long' $null '03/11/2026 11:00' '0=60:40=120' 'standard')
    } elseif ($state -eq 'tete') {
        Set-DriveCurve "$src>$tgt" 'std_h0' (New-Cv $src $tgt 'std' 0 '01/11/2026 17:49' '0=51:40=91' 'standard')
        Set-DriveCurve "$src>$tgt" 'std_h1' (New-Cv $src $tgt 'std' 1 '02/11/2026 09:05' '0=53:40=95' 'standard')
    }
    Sync-PrecompCurves $src
}
function Get-R4Kind($c, [int]$prof, [string]$state, [bool]$slow) {
    # Refus attendu d apres le scenario, sans 140 : '' (aucun), 'hd', 'head' (courbes par tete seulement, ecriture rapide),
    # 'none' (aucune courbe croisee de la famille). Sans effet : Manuel, flux ecrit tel quel, FM/GCR ; haute densite en Auto ;
    # famille : profil force, sinon celle de l image
    if ($prof -eq 3 -or $c[4] -eq 'flux' -or $c[4] -eq 'nm') { return '' }
    if ($prof -eq 0 -and $c[4] -eq 'hd') { return 'hd' }
    $fam = if ($prof -eq 1) { 'std' } elseif ($prof -eq 2) { 'long' } else { $c[3] }
    if ($state -eq 'commune') { return '' }
    if ($state -eq 'tete' -and $fam -eq 'std') { if ($slow) { return '' }; return 'head' }
    return 'none'
}
function Get-R4Says([string]$t) { return ([regex]::Matches($t, 'refusée|refused')).Count }
$r4Img = @(
    @('secteur (.adf)', 'jeu.adf', '(auto)', 'std', ''),
    @('flux non analyse (.raw) tel quel', 'jeu.raw', '(auto)', 'std', 'flux'),
    @('flux SCP tel quel', 'jeu.scp', '(auto)', 'std', 'flux'),
    @('flux non analyse avec --format', 'jeu.raw', 'amiga.amigados', 'std', ''),
    @('SCP analyse avec --format', 'jeu.scp', 'ibm.720', 'std', ''),
    @('IPF', 'jeu.ipf', '(auto)', 'std', ''),
    @('IPF long track', 'jeu-long.ipf', '(auto)', 'long', ''),
    @('HFE', 'jeu.hfe', '(auto)', 'std', ''),
    @('haute densite calibrable', 'jeu-hd.img', '(auto)', 'std', 'hd'),
    @('haute densite non calibrable', 'jeu-ed.img', '(auto)', 'std', 'hd'),
    @('GCR (.d64)', 'jeu.d64', '(auto)', 'std', 'nm'),
    @('FM', 'jeu-fm.img', '(auto)', 'std', 'nm'))
$r4 = New-Object System.Collections.Generic.List[object]
$sw4 = [System.Diagnostics.Stopwatch]::StartNew()
foreach ($lang in 'fr', 'en') {
    $script:Lang = $lang
    foreach ($state in 'commune', 'tete', 'aucune') {
        Set-R4Store $state
        foreach ($prof in 0, 1, 2, 3) {
            foreach ($slow in $true, $false) {
                foreach ($c in $r4Img) {
                    $p = [string]$img[$c[1]]
                    Set-Ui $prof $slow $true 'A'; $script:TargetDrives = @{ A = '0' }; $cmbWFmt.Text = $c[2]; $txtWFile.Text = $p
                    Update-PrecompForImage $p
                    $l0 = [string]$lblWProfileInfo.Text; $i0 = Get-TargetWriteInfo $p $c[2] $slow
                    $gh = if ($hasHeadR4) { [string](Get-WTargetHead $p) } else { $null }
                    Set-PcBox $false
                    $l1 = [string]$lblWProfileInfo.Text; $i1 = Get-TargetWriteInfo $p $c[2] $slow
                    Set-PcBox $true
                    $l2 = [string]$lblWProfileInfo.Text; $i2 = Get-TargetWriteInfo $p $c[2] $slow
                    $k = Get-R4Kind $c $prof $state $slow
                    $h = if ($k) { Get-R3Head $lang $k 'A' '0' } else { '' }
                    $b0 = [bool][string]$i0.Block
                    $hasH = $b0 -and $l0.StartsWith($h, [System.StringComparison]::Ordinal) -and $l0.Length -gt $h.Length
                    $okHead = ($b0 -eq [bool]$k) -and ((-not $b0 -and (Get-R4Says $l0) -eq 0) -or ($hasH -and (Get-R4Says $l0) -eq 1))
                    $okKind = (-not $i0.ContainsKey('BlockKind')) -or ([string]$i0.BlockKind -eq $k)
                    $okGh = ($null -eq $gh) -or ($gh -eq $h)
                    $rest = if ($hasH) { $l0.Substring($h.Length) } elseif ($b0) { '<tete absente>' } else { $l0 }
                    $okOff = (-not [string]$i1.Block) -and (Get-R4Says $l1) -eq 0 -and $l1 -eq $rest
                    $okOn = ($l2 -eq $l0) -and ([bool][string]$i2.Block -eq $b0)
                    $r4.Add([pscustomobject]@{ L = $lang; S = $state; P = $prof; Slow = $slow; C = $c[0]; K = $k; Blk = $b0; BK = [string]$i0.BlockKind
                            Head = $okHead; Kind = $okKind; Gh = $okGh; Off = $okOff; On = $okOn; L0 = $l0; L1 = $l1; L2 = $l2
                            Man = $(if ($prof -eq 3) { T 'Profil manuel : --precomp non modifié.' } else { '' }) })
                }
            }
        }
    }
}
$script:Lang = 'fr'
function Show-R4Bad($rows, [string]$id, [int]$n = 6) {
    foreach ($x in @($rows | Select-Object -First $n)) { "  $id ECART $($x.L) $($x.S) profil $($x.P) $(if ($x.Slow) { 'lente' } else { 'rapide' }) $($x.C) : refus attendu « $($x.K) », Block $($x.Blk) « $($x.BK) » ; coche « $($x.L0) » ; decochee « $($x.L1) » ; recochee « $($x.L2) »" }
    if (@($rows).Count -gt $n) { "  $id ... $(@($rows).Count - $n) autre(s) ecart(s)" }
}
$rA = @($r4 | Where-Object { $_.P -eq 0 }); $rF = @($r4 | Where-Object { $_.P -eq 1 -or $_.P -eq 2 }); $rM = @($r4 | Where-Object { $_.P -eq 3 })
"  R4A : $($r4.Count) combinaisons en $([int]$sw4.Elapsed.TotalSeconds) s ; refus attendus : $(@($r4 | Where-Object { $_.K }).Count) (haute densite $(@($r4 | Where-Object { $_.K -eq 'hd' }).Count), par tete $(@($r4 | Where-Object { $_.K -eq 'head' }).Count), aucune courbe $(@($r4 | Where-Object { $_.K -eq 'none' }).Count)) ; Block rendus : $(@($r4 | Where-Object { $_.Blk }).Count)"
foreach ($x in @($r4 | Where-Object { $_.L -eq 'fr' -and $_.S -eq 'aucune' -and $_.Slow -and $_.C -eq 'secteur (.adf)' })) { "  exemple profil $($x.P) : « $($x.L0) »" }
foreach ($x in @($r4 | Where-Object { $_.L -eq 'en' -and $_.S -eq 'tete' -and -not $_.Slow -and $_.P -eq 0 -and $_.C -eq 'IPF' })) { "  exemple anglais (par tete, rapide, IPF) : « $($x.L0) »" }
$bA = @($rA | Where-Object { -not ($_.Head -and $_.Kind -and $_.Gh) }); Show-R4Bad $bA 'R4A1'
Chk 'R4A1' ($r4Real -and $rA.Count -eq 144 -and $bA.Count -eq 0) "profil Auto, $($rA.Count) combinaisons (12 images : secteur, flux non analyse et SCP ecrits tels quels, flux non analyse et SCP avec --format, IPF, IPF long, HFE, haute densite calibrable et non calibrable, GCR, FM ; courbes croisees communes, par tete seulement, aucune ; ecriture lente et rapide ; francais et anglais), case cochee : libelle qui commence par le refus court si et seulement si Get-TargetWriteInfo rend un Block, refus attendu d apres le scenario (aucune courbe, par tete, haute densite), une seule fois$(if ($hasHeadR4) { ' ; BlockKind et Get-WTargetHead accordes' })"
$bF = @($rF | Where-Object { -not ($_.Head -and $_.Kind -and $_.Gh) }); Show-R4Bad $bF 'R4A2'
$fxRows = @($rF | Where-Object { $_.C -like '*tel quel' })
"  R4A2 : profil force et flux tel quel : $($fxRows.Count) combinaisons, $(@($fxRows | Where-Object { -not ($_.Head -and $_.Kind -and $_.Gh) }).Count) ecart(s)"
Chk 'R4A2' ($r4Real -and $rF.Count -eq 288 -and $bF.Count -eq 0) "profils forces Standard et Long track, $($rF.Count) combinaisons (memes images, courbes, ecritures, langues), case cochee : refus en tete si et seulement si Block, texte attendu (famille du profil force ; haute densite : courbes de la famille, aucun refus « haute densite ») ; flux ecrit tel quel : aucun refus annonce"
$bM = @($rM | Where-Object { -not ($_.Head -and $_.Kind -and $_.Gh) -or $_.Blk -or $_.L0 -ne $_.Man }); Show-R4Bad $bM 'R4A3'
Chk 'R4A3' ($r4Real -and $rM.Count -eq 144 -and $bM.Count -eq 0) "profil Manuel, $($rM.Count) combinaisons : ni refus ni Block, libelle « $(T 'Profil manuel : --precomp non modifié.') » (anglais : « $(@($rM | Where-Object { $_.L -eq 'en' })[0].Man) »)"
$bO = @($r4 | Where-Object { -not ($_.Off -and $_.On) }); Show-R4Bad $bO 'R4A4'
Chk 'R4A4' ($r4Real -and $r4.Count -eq 576 -and $bO.Count -eq 0) "$($r4.Count) combinaisons, case --precomp decochee par le gestionnaire de 520 : ecriture non refusee (precompensation desactivee) et libelle d avant sans le refus, aucun refus annonce ; recochee : libelle et Block d avant"

# R4B : Sync-WTargetHead idempotent (deux fois, avec et sans -IfOwn) ; case decochee puis recochee trois fois : tete retiree
# puis remise, jamais doublee ; Sync-WTargetHead case decochee : rien a remettre ; base du complement « facteur » d avant
$rb = @()
foreach ($lang in 'fr', 'en') {
    $script:Lang = $lang
    foreach ($k in 'none', 'head', 'hd') {
        if ($k -eq 'hd') { Set-R3Store 'A'; $l0 = Get-R3Label 'jeu-hd.img' 'A' '0' 0 $true }
        else { Set-R3Store 'A' '0' $cal80 -PerHead:($k -eq 'head'); $l0 = Get-R3Label 'jeu.adf' 'A' '0' 0 ($k -ne 'head') }
        $h = Get-R3Head $lang $k 'A' '0'
        $bs0 = if ($script:WFactorNote) { [string]$script:WFactorNote.Base } else { '<nul>' }
        $ok = $hasSyncR4 -and $l0.StartsWith($h, [System.StringComparison]::Ordinal) -and $l0.IndexOf($h, $h.Length, [System.StringComparison]::Ordinal) -lt 0
        if ($hasSyncR4) { Sync-WTargetHead; Sync-WTargetHead; Sync-WTargetHead -IfOwn; Sync-WTargetHead -IfOwn }
        $l1 = [string]$lblWProfileInfo.Text
        $ok = $ok -and $l1 -eq $l0 -and ($(if ($script:WFactorNote) { [string]$script:WFactorNote.Base } else { '<nul>' }) -eq $bs0)
        $seq = @()
        for ($i = 0; $i -lt 3; $i++) {
            Set-PcBox $false; $la = [string]$lblWProfileInfo.Text
            if ($hasSyncR4) { Sync-WTargetHead; Sync-WTargetHead -IfOwn }
            $lb = [string]$lblWProfileInfo.Text
            Set-PcBox $true; $lc = [string]$lblWProfileInfo.Text
            if ($hasSyncR4) { Sync-WTargetHead -IfOwn; Sync-WTargetHead }
            $ld = [string]$lblWProfileInfo.Text
            $seq += ($la -eq $l0.Substring([math]::Min($h.Length, $l0.Length)) -and $lb -eq $la -and $lc -eq $l0 -and $ld -eq $l0)
        }
        $ok = $ok -and @($seq | Where-Object { -not $_ }).Count -eq 0 -and ($(if ($script:WFactorNote) { [string]$script:WFactorNote.Base } else { '<nul>' }) -eq $bs0)
        $rb += [pscustomobject]@{ Id = "$lang/$k"; Ok = $ok; T = $l0; E = [string]$lblWProfileInfo.Text }
    }
}
$script:Lang = 'fr'
foreach ($x in @($rb | Where-Object { -not $_.Ok })) { "  R4B ECART $($x.Id) : avant « $($x.T) » ; apres « $($x.E) »" }
Chk 'R4B' ($r4Real -and $hasSyncR4 -and @($rb | Where-Object { -not $_.Ok }).Count -eq 0) "$($rb.Count) libelles (aucune courbe croisee, par tete en ecriture rapide, haute densite ; francais et anglais) : Sync-WTargetHead$(if (-not $hasSyncR4) { ' (ABSENTE)' }) idempotent, avec et sans -IfOwn ; case decochee puis recochee trois fois : refus retire puis remis, jamais double, base du complement « facteur » d avant"

# R4C : texte qui n est pas le profil (avis de la Bibliotheque, bilan de calibration) : ni la case ni Sync-WTargetHead -IfOwn
# n y touchent, avis pose avant ou apres la case decochee ; Update-PrecompForImage refait ensuite le libelle (refus en tete)
$script:Lang = 'fr'; Set-R3Store 'A'
$rc = @()
foreach ($o in @("Bibliothèque : écriture refusée. Onglet Écriture rétabli : tab.adf, champ Pistes « c=0 ».", 'Profils Standard 2 us de cette disquette (mesure complète du 10/11/2026 09:00, lecteur A) : tête 0 de 60 à 139 ns.')) {
    foreach ($order in 'avis puis case', 'case puis avis') {
        $l0 = Get-R3Label 'jeu.adf' 'A' '2' 0 $true
        if ($order -eq 'avis puis case') { $lblWProfileInfo.Text = $o; Set-PcBox $false; $a = [string]$lblWProfileInfo.Text }
        else { Set-PcBox $false; $lblWProfileInfo.Text = $o; $a = [string]$lblWProfileInfo.Text }
        if ($hasSyncR4) { Sync-WTargetHead -IfOwn }
        $b = [string]$lblWProfileInfo.Text
        Set-PcBox $true; $c2 = [string]$lblWProfileInfo.Text
        if ($hasSyncR4) { Sync-WTargetHead -IfOwn }
        $d = [string]$lblWProfileInfo.Text
        Update-PrecompForImage $img['jeu.adf']; $e = [string]$lblWProfileInfo.Text
        $rc += [pscustomobject]@{ Id = "$order, « $($o.Substring(0, 24))… »"; Ok = ($a -eq $o -and $b -eq $o -and $c2 -eq $o -and $d -eq $o -and $e -eq $l0 -and $l0.StartsWith((Get-R3Head 'fr' 'none' 'A' '2'), [System.StringComparison]::Ordinal)); T = "$a | $b | $c2 | $d | $e" }
    }
}
foreach ($x in @($rc | Where-Object { -not $_.Ok })) { "  R4C ECART $($x.Id) : $($x.T)" }
Chk 'R4C' ($r4Real -and $hasSyncR4 -and @($rc | Where-Object { -not $_.Ok }).Count -eq 0) "$($rc.Count) sequences (avis de la Bibliotheque, bilan de calibration ; avis pose avant ou apres la case decochee) : case decochee puis recochee et Sync-WTargetHead -IfOwn$(if (-not $hasSyncR4) { ' (ABSENTE)' }) sans effet sur ce texte ; Update-PrecompForImage refait le libelle du profil, refus en tete"

# R4D : base et complement « facteur » (Set-WProfileText, vrai Update-WriteFactorNote) accordes : case decochee, complement
# refait, case recochee ; puis case decochee et recochee, complement refait
$script:Lang = 'fr'; Set-R3Store 'A'
$hD = Get-R3Head 'fr' 'none' 'A' '2'; $bD = "Auto : image secteur (.adf) -> standard 2 us ($d0)"
$fA = " ; facteur appliqué à l'écriture : tête 0 × 0,85, tête 1 × 0,90"; $fB = " ; facteur appliqué à l'écriture : tête 0 × 0,80, tête 1 × 0,95"
$script:R3FactorNote = $fA
$d1 = Get-R3Label 'jeu.adf' 'A' '2' 0 $true
Set-PcBox $false; $d2 = [string]$lblWProfileInfo.Text
$script:R3FactorNote = $fB; Update-WriteFactorNote; $d3 = [string]$lblWProfileInfo.Text; $d3b = [string]$script:WFactorNote.Base; $i3 = Get-PcInfo 'jeu.adf' $true
Set-PcBox $true; $d4 = [string]$lblWProfileInfo.Text; $d4b = [string]$script:WFactorNote.Base; $i4 = Get-PcInfo 'jeu.adf' $true
$script:R3FactorNote = $fA; Update-WriteFactorNote; $d5 = [string]$lblWProfileInfo.Text
Set-PcBox $false; Set-PcBox $true; $script:R3FactorNote = $fB; Update-WriteFactorNote; $d6 = [string]$lblWProfileInfo.Text; $d6b = [string]$script:WFactorNote.Base
$script:R3FactorNote = $null
"  R4D : « $d1 » ; decochee « $d2 » ; complement refait « $d3 » (Block « $([string]$i3.Block) ») ; recochee « $d4 » (Block $([bool][string]$i4.Block)) ; refait « $d5 » ; decochee, recochee, refait « $d6 »"
Chk 'R4D' ($r4Real -and $d1 -eq ($hD + $bD + $fA) -and $d2 -eq ($bD + $fA) -and $d3 -eq ($bD + $fB) -and $d3b -eq $bD -and -not [string]$i3.Block -and $d4 -eq ($hD + $bD + $fB) -and $d4b -eq ($hD + $bD) -and [bool][string]$i4.Block -and $d5 -eq ($hD + $bD + $fA) -and $d6 -eq ($hD + $bD + $fB) -and $d6b -eq ($hD + $bD)) "complement « facteur » refait case decochee (base sans refus, ecriture non refusee), puis case recochee : refus remis en tete de la base et du libelle (ecriture refusee) ; complement refait ensuite a la suite ; decochee et recochee, puis refait : base et libelle accordes"

# R4E : profil force et image flux ecrite telle quelle (.raw, SCP sans --format) : complement $fxNote, profil entre
# parentheses sans courbe croisee nommee, aucun refus annonce, ecriture non refusee (lecteur cible sans effet)
$re = @()
foreach ($lang in 'fr', 'en') {
    $script:Lang = $lang
    $fx = T " ; image flux écrite telle quelle (sans --format) : gw n'applique pas la précompensation, --precomp n'est pas transmis"
    foreach ($ts in @(@('0', 'commune'), @('0', 'tete'), @('2', 'aucune'))) {
        Set-R4Store $ts[1] 'A' $ts[0]
        foreach ($prof in 1, 2) {
            foreach ($slow in $true, $false) {
                foreach ($key in 'jeu.raw', 'jeu.scp') {
                    $t = Get-R3Label $key 'A' $ts[0] $prof $slow '(auto)'
                    $ti = Get-TargetWriteInfo ([string]$img[$key]) '(auto)' $slow
                    $e = $(if ($prof -eq 1) { (T "Profil forcé : standard 2 us ({0})") -f $script:PrecompStd } else { (T "Profil forcé : long track ({0})") -f $script:PrecompLong }) + $fx
                    $ok = $t -eq $e -and $t -notmatch 'courbes? croisées?|cross curves?' -and (Get-R4Says $t) -eq 0 -and -not [string]$ti.Block -and -not $ti.Applies -and [string]$ti.Why -eq (T 'image flux écrite telle quelle, sans précompensation')
                    $re += [pscustomobject]@{ Id = "$lang, cible $($ts[0]) ($($ts[1])), profil $prof, $(if ($slow) { 'lente' } else { 'rapide' }), $key"; Ok = $ok; T = $t; E = $e }
                }
            }
        }
    }
}
$script:Lang = 'fr'
"  R4E : exemples « $(@($re | Where-Object { $_.Id -like 'fr, cible 0 (commune), profil 1, lente, jeu.scp' })[0].T) » ; « $(@($re | Where-Object { $_.Id -like 'en, cible 2 (aucune), profil 2, rapide, jeu.raw' })[0].T) »"
foreach ($x in @($re | Where-Object { -not $_.Ok } | Select-Object -First 6)) { "  R4E ECART $($x.Id) : « $($x.T) » ; attendu « $($x.E) »" }
Chk 'R4E' ($re.Count -eq 48 -and @($re | Where-Object { -not $_.Ok }).Count -eq 0) "$($re.Count) libelles (profils forces Standard et Long track ; .raw et SCP sans --format ; lecteur cible 0 avec courbes croisees communes ou par tete, lecteur cible 2 sans courbe ; lente et rapide ; francais et anglais) : profil d origine entre parentheses et complement de l image flux ecrite telle quelle, aucune courbe croisee nommee, aucun refus annonce ; ecriture non refusee (lecteur cible sans effet : image flux ecrite telle quelle)"

# R4F : lignes du libelle du profil (502 x 40, deux lignes ; 12.11, lot L9 : 458 x 58, trois lignes, taille lue dans 520),
# refus en tete et profil d origine de la famille. Mesure hors ecran,
# police en pixels (Segoe UI 13 px = 9,75 pt a 96 ppp, police de la fenetre, 500), rendu compatible (GDI+, defaut sous
# Windows PowerShell 5.1), LineLimit ; sans points de suspension (texte entier) et avec (dessin du Label AutoEllipsis)
$fPx = New-Object System.Drawing.Font('Segoe UI', [single]13.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
function Get-R4Box([string]$text, [int]$w, [int]$h, [bool]$ell) {
    $bmp = New-Object System.Drawing.Bitmap(4, 4); $g = [System.Drawing.Graphics]::FromImage($bmp)
    $sf = New-Object System.Drawing.StringFormat
    $sf.FormatFlags = [System.Drawing.StringFormatFlags]::LineLimit
    $sf.Trimming = $(if ($ell) { [System.Drawing.StringTrimming]::EllipsisCharacter } else { [System.Drawing.StringTrimming]::None })
    $cf = 0; $lf = 0
    try { [void]$g.MeasureString($text, $fPx, (New-Object System.Drawing.SizeF($w, $h)), $sf, [ref]$cf, [ref]$lf) } finally { $sf.Dispose(); $g.Dispose(); $bmp.Dispose() }
    $l = New-Object System.Windows.Forms.Label
    $l.UseCompatibleTextRendering = $true; $l.Font = $fPx; $l.AutoSize = $false; $l.AutoEllipsis = $true; $l.Size = New-Object System.Drawing.Size($w, $h); $l.Text = $text
    $ph = $l.GetPreferredSize((New-Object System.Drawing.Size($w, 0))).Height; $l.Dispose()
    return @{ Fit = $cf; Lines = $lf; PH = $ph }
}
$rf = @()
# 12.11 (lot L9) : taille du libelle lue dans 520 ($lblSize : 458 x 58), trois lignes au plus
$r4W = 502; $r4H = 40; $r4L = 2
if ($lblSize) { $r4W = $lblSize[0]; $r4H = $lblSize[1]; $r4L = [int][math]::Floor($r4H / 18) }
foreach ($lang in 'fr', 'en') {
    $script:Lang = $lang
    foreach ($pr in @(@('A', '0'), @('0', 'A'), @('B', '2'), @('2', 'B'))) {
        $s = $pr[0]; $tg = $pr[1]
        foreach ($k in 'none', 'head', 'hd', 'ed') {
            if ($k -eq 'none') { Set-R3Store $s; $t = Get-R3Label 'jeu.adf' $s $tg 0 $true }
            elseif ($k -eq 'head') { Set-R3Store $s $tg '' -PerHead; $t = Get-R3Label 'jeu.adf' $s $tg 0 $false }
            elseif ($k -eq 'hd') { Set-R3Store $s; $t = Get-R3Label 'jeu-hd.img' $s $tg 0 $true }
            else { Set-R3Store $s; $t = Get-R3Label 'jeu-ed.img' $s $tg 0 $true }
            $h = Get-R3Head $lang $(if ($k -eq 'ed') { 'hd' } else { $k }) $s $tg
            $bx = Get-R4Box $t $r4W $r4H $false; $bxE = Get-R4Box $t $r4W $r4H $true
            $rf += [pscustomobject]@{ L = $lang; P = "$s/$tg"; K = $k; T = $t; N = $t.Length; Head = $t.StartsWith($h, [System.StringComparison]::Ordinal); HL = $h.TrimEnd().Length
                Fit = $bx.Fit; Lines = $bx.Lines; PH = $bx.PH; FitE = $bxE.Fit; Orig = $t.Contains($(if ($k -eq 'hd') { $script:PrecompHdDefault } else { $script:PrecompStdDefault })) }
        }
    }
}
$script:Lang = 'fr'
$rf | Group-Object L, K | ForEach-Object { "  R4F $($_.Name) : $($_.Count) libelles de $(($_.Group | Measure-Object N -Minimum).Minimum) a $(($_.Group | Measure-Object N -Maximum).Maximum) car. ; hauteur preferee $(($_.Group | Measure-Object PH -Maximum).Maximum) px au plus ; lignes $(($_.Group | Measure-Object Lines -Maximum).Maximum) au plus ; visibles (points de suspension) $(($_.Group | Measure-Object FitE -Minimum).Minimum) car. au moins, refus de $(($_.Group | Measure-Object HL -Maximum).Maximum) car. au plus" }
foreach ($x in @($rf | Where-Object { $_.L -eq 'en' -and $_.P -eq '2/B' })) { "  R4F en 2/B $($x.K) : « $($x.T) »" }
$bf = @($rf | Where-Object { $_.K -in 'none', 'head' -and -not ($_.Head -and $_.Orig -and $_.Fit -ge $_.N -and $_.Lines -le $r4L -and $_.PH -le $r4H -and $_.FitE -ge $_.N) })
$bf2 = @($rf | Where-Object { $_.K -in 'hd', 'ed' -and -not ($_.Head -and $_.Orig -and $_.FitE -ge $_.HL) })
foreach ($x in @($bf + $bf2)) { "  R4F ECART $($x.L) $($x.P) $($x.K) : en tete $($x.Head), profil d origine $($x.Orig), $($x.Fit)/$($x.N) car. sur $($x.Lines) ligne(s), hauteur $($x.PH) px, visibles $($x.FitE) : « $($x.T) »" }
Chk 'R4F' ($isLbl -and @($rf | Where-Object { $_.K -in 'none', 'head' }).Count -eq 16 -and $bf.Count -eq 0 -and $r4L -eq 3) "16 libelles (paires A/0, 0/A, B/2, 2/B ; aucune courbe croisee et par tete en ecriture rapide ; francais et anglais) : refus en tete et profil d origine de la famille standard entiers en $r4L lignes de $r4W x $r4H px, taille du libelle de 520 (Segoe UI 13 px, rendu compatible, LineLimit, avec et sans points de suspension)"
Chk 'R4F2' ($isLbl -and @($rf | Where-Object { $_.K -in 'hd', 'ed' }).Count -eq 16 -and $bf2.Count -eq 0) "16 libelles haute densite (calibrable : profil d origine haute densite non calibre ; non calibrable : profil d origine standard ; memes paires et langues) : au-dela de $r4L lignes, refus en tete entier avant les points de suspension"

# R4G : cadre « Calibration du lecteur » de la restauration (lblRsCal, 540 : 262 x 54, AutoEllipsis) : phrase du lecteur
# cible en tete (vrai Get-RsCalibText, 300), phrases des familles a sa suite inchangees, phrase entiere dans le cadre
$rg = @()
foreach ($lang in 'fr', 'en') {
    $script:Lang = $lang
    foreach ($pr in @(@('A', '0'), @('0', 'A'), @('B', '2'), @('2', 'B'))) {
        $s = $pr[0]; $tg = $pr[1]
        foreach ($own in 'tete', 'aucune') {
            foreach ($cs in 'tete', 'commune', 'aucune') {
                $script:DriveCurves = @{}
                if ($own -eq 'tete') { Set-DriveCurve $s 'std_h0' (New-Cv $s '' 'std' 0 '01/11/2026 10:00' '0=21:40=41'); Set-DriveCurve $s 'std_h1' (New-Cv $s '' 'std' 1 '01/11/2026 10:00' '0=22:40=42') }
                if ($cs -eq 'tete') { Set-DriveCurve "$s>$tg" 'std_h0' (New-Cv $s $tg 'std' 0 '02/11/2026 09:00' '0=41:40=81'); Set-DriveCurve "$s>$tg" 'std_h1' (New-Cv $s $tg 'std' 1 '02/11/2026 09:00' '0=43:40=85') }
                elseif ($cs -eq 'commune') { Set-DriveCurve "$s>$tg" 'std' (New-Cv $s $tg 'std' $null '01/11/2026 17:49' '0=40:40=80' 'standard') }
                Sync-PrecompCurves $s
                Set-Ui 0 $true $true $s
                $script:TargetDrives = @{}; $rest = if ($hasRsR4) { [string](Get-RsCalibText) } else { '' }
                $script:TargetDrives = @{ $s = $tg }; $t = if ($hasRsR4) { [string](Get-RsCalibText) } else { '' }
                if ($cs -eq 'aucune') { $ph = (T "Lecteur cible {0} : aucune courbe croisée standard {1} → {0}, la restauration sera refusée au lancement.") -f $tg, $s }
                else {
                    $kd = $(if ($cs -eq 'tete') { (T 'par tête') + ', 02/11/2026' } else { (T 'commune') + ', 01/11/2026' })
                    $ph = (T "Lecteur cible {0} : courbe croisée {1} → {0} ({2}), à la place de celle du lecteur {1}, sans calibration.") -f $tg, $s, $kd
                }
                $bx = Get-R4Box $t 262 54 $false; $bxE = Get-R4Box $t 262 54 $true
                $rg += [pscustomobject]@{ Id = "$lang, $s/$tg, courbes propres $own, courbes croisees $cs"; L = $lang; P = "$s/$tg"; Cs = $cs; T = $t; Ph = $ph; Rest = $rest
                    Head = ($t -eq ($ph + ' ' + $rest) -and $rest -and $rest -notmatch 'Lecteur cible|Target drive'); Whole = ($bx.Fit -ge $ph.Length -and $bxE.Fit -ge $ph.Length)
                    Fit = $bx.Fit; FitE = $bxE.Fit; Lines = $bx.Lines; Vis = $t.Substring(0, [math]::Min($t.Length, $bxE.Fit)) }
            }
        }
    }
}
$script:Lang = 'fr'; $script:TargetDrives = @{}; $cmbDrive.Text = 'A'
$rg | Group-Object L, Cs | ForEach-Object { "  R4G $($_.Name) : $($_.Count) textes, phrase de $(($_.Group | ForEach-Object { $_.Ph.Length } | Measure-Object -Maximum).Maximum) car. au plus, $(($_.Group | Measure-Object Fit -Minimum).Minimum) car. visibles au moins (marge minimale $(($_.Group | ForEach-Object { $_.Fit - $_.Ph.Length } | Measure-Object -Minimum).Minimum) car.)" }
foreach ($x in @($rg | Where-Object { $_.Id -eq 'fr, A/0, courbes propres tete, courbes croisees tete' -or $_.Id -eq 'en, A/0, courbes propres tete, courbes croisees commune' })) { "  R4G $($x.Id) : « $($x.T) »" }
$badG = @($rg | Where-Object { -not ($_.Head -and $_.Whole) })
foreach ($x in @($badG | Select-Object -First 8)) { "  R4G ECART $($x.Id) : en tete $($x.Head) ; phrase de $($x.Ph.Length) car., $($x.Fit) / $($x.FitE) car. visibles ; visible « $($x.Vis) »" }
if ($badG.Count -gt 8) { "  R4G ... $($badG.Count - 8) autre(s) ecart(s)" }
$p9 = @($rg | Where-Object { $_.Id -eq 'fr, A/0, courbes propres tete, courbes croisees tete' })[0].Ph
Chk 'R4G' ($hasRsR4 -and $rg.Count -eq 48 -and @($rg | Where-Object { -not $_.Head }).Count -eq 0 -and $p9 -eq 'Lecteur cible 0 : courbe croisée A → 0 (par tête, 02/11/2026), à la place de celle du lecteur A, sans calibration.') "$($rg.Count) textes (paires A/0, 0/A, B/2, 2/B ; courbes propres par tete ou aucune ; courbes croisees par tete, commune, aucune ; francais et anglais) : phrase du lecteur cible en tete, phrases des familles a sa suite inchangees ($(@($rg | Where-Object { $_.Head }).Count)/$($rg.Count))"
$wG = @($rg | Where-Object { $_.Head -and -not $_.Whole })
Chk 'R4G2' ($hasRsR4 -and $rg.Count -eq 48 -and @($rg | Where-Object { -not ($_.Head -and $_.Whole) }).Count -eq 0) "phrase du lecteur cible en tete et entiere dans 262 x 54 px (Segoe UI 13 px, rendu compatible, LineLimit, avec et sans points de suspension) : $(@($rg | Where-Object { $_.Head -and $_.Whole }).Count)/$($rg.Count)$(if ($wG.Count) { ' ; coupee : ' + ((@($wG | ForEach-Object { "$($_.L) $($_.Cs)" }) | Sort-Object -Unique) -join ', ') + ' (fin cachee par les points de suspension)' })"

# R4H : retablissements avec la case decochee (250 Restore-CalibState : fin de calibration puis retablissement ; 300
# Restore-WriteTabState : Update-PrecompForImage puis case remise) : libelle et ecriture coherents, puis case recochee
$rh = @()
$script:Lang = 'fr'
foreach ($k in 'none', 'head', 'hd') {
    $key = if ($k -eq 'hd') { 'jeu-hd.img' } else { 'jeu.adf' }; $slow = ($k -ne 'head')
    if ($k -eq 'head') { Set-R3Store 'A' '0' '' -PerHead } else { Set-R3Store 'A' }
    $l0 = Get-R3Label $key 'A' '0' 0 $slow; $h = Get-R3Head 'fr' $k 'A' '0'
    Set-PcBox $false; $snapL = [string]$lblWProfileInfo.Text; $snapOn = [bool]$chkWPrecomp.Checked
    Update-PrecompForImage $img[$key]; Update-PrecompForImage $img[$key]
    $chkWPrecomp.Checked = $snapOn; $lblWProfileInfo.Text = $snapL
    $c1 = [string]$lblWProfileInfo.Text; $ic1 = Get-PcInfo $key $slow
    Set-PcBox $true; $c2 = [string]$lblWProfileInfo.Text; $ic2 = Get-PcInfo $key $slow
    Set-PcBox $false; Update-PrecompForImage $img[$key]; $chkWPrecomp.Checked = $false
    $e1 = [string]$lblWProfileInfo.Text; $ie1 = Get-PcInfo $key $slow
    Set-PcBox $true; $e2 = [string]$lblWProfileInfo.Text; $ie2 = Get-PcInfo $key $slow
    $cut = $l0.Substring([math]::Min($h.Length, $l0.Length))
    $ok = $l0.StartsWith($h, [System.StringComparison]::Ordinal) -and $c1 -eq $cut -and -not [string]$ic1.Block -and $c2 -eq $l0 -and [bool][string]$ic2.Block -and $e1 -eq $cut -and -not [string]$ie1.Block -and $e2 -eq $l0 -and [bool][string]$ie2.Block
    $rh += [pscustomobject]@{ Id = $k; Ok = $ok; T = "« $c1 » ; « $c2 » ; « $e1 » ; « $e2 »" }
}
foreach ($x in @($rh | Where-Object { -not $_.Ok })) { "  R4H ECART $($x.Id) : $($x.T)" }
Chk 'R4H' ($r4Real -and @($rh | Where-Object { -not $_.Ok }).Count -eq 0) "retablissement d une calibration refusee (250) et de l onglet Ecriture (300) avec la case decochee (aucune courbe croisee, par tete en ecriture rapide, haute densite) : libelle sans refus et ecriture non refusee ; case recochee : refus en tete et ecriture refusee"

if ($r4Real) { $chkWPrecomp.Dispose() }
$chkWPrecomp = $chkSim4; $script:UiReady = $uiSv4; $script:SettingSync = $ssSv4
Reset-Store; $script:TargetDrives = @{}; $script:Lang = 'fr'; Set-Ui 0 $true; $script:R3FactorNote = $null; $txtWFile.Text = ''
if ($isLbl) { $lblWProfileInfo.Text = '' }

"--- O : fenetre « Calibrations d un autre calcul » (240 Resolve-OldCalibrations, texte sans la fenetre)"
$kA = "Recalibrer (conseillé) : ces calibrations sont abandonnées et leurs profils reviennent aux valeurs d'origine. Recalibrez chaque lecteur concerné depuis la carte « Calibrer le lecteur » de l'Accueil, sur une disquette sacrifiée ; d'ici là, en « Test rapide », l'écriture d'une image calibrable est refusée.`nConserver ces courbes : elles restent utilisées telles quelles ; la fenêtre Courbe et le journal rappellent leur calcul. Le calcul ayant changé, une nouvelle calibration peut donner une courbe plus juste."
$s123 = "Une courbe antérieure à la 12.3 ne peut pas servir de référence au test rapide (pente et densité non enregistrées)."
$kClose = "Fermer la fenêtre (ou Échap) : décision au prochain démarrage ; d'ici là, ces calibrations ne sont pas utilisées."
$oldFixed = $kA + ' ' + $s123 + "`n" + $kClose
$p1210 = "Depuis le calcul 12.10, la vérification corrige l'erreur de modèle d'un lecteur à fort besoin au-delà du plus fort niveau mesuré, et les passes de mesure du long track écrivent 0, 60 et 200 ns (0, 30 et 100 ns avec le calcul 12.9). Une courbe long track du calcul 12.9 reposait surtout sur des extrapolations ; sur un lecteur à fort besoin, une courbe double densité d'un calcul antérieur pouvait rester trop haute d'environ 3 ns aux cylindres intérieurs : recalibrer est conseillé."
$p1210Old = "Depuis le calcul 12.10, la vérification corrige l'erreur de modèle d'un lecteur à fort besoin au-delà du plus fort niveau mesuré, et les passes de mesure du long track écrivent 0, 60 et 200 ns au lieu de 0, 30 et 100 ns. Sur un tel lecteur, une courbe double densité d'un calcul antérieur pouvait rester trop haute d'environ 3 ns aux cylindres intérieurs, et une courbe long track reposait surtout sur des extrapolations : recalibrer est conseillé."
function New-OldCv([string]$calc, [string]$drive = 'A') {
    return @{ Family = 'Standard 2 us'; Head = $null; Drive = $drive; Target = ''; Date = '20/10/2026 10:00'; Spec = '0=20:40=40'; Method = 'motif'
              Version = $calc; Calc = $calc; Converged = $true; Bits = 100000; Test = 'fine'; Values = [int[]]@(0..79) }
}
function Get-OldText([hashtable]$curves) { $script:OldCalib = @{ Curves = $curves; Bak = $null }; return [string](Get-OldCalibTextT) }
$t1 = Get-OldText @{ 'A|std' = (New-OldCv '12.9') }
Chk 'O1' ($t1.EndsWith("`n`n" + $kA + "`n" + $kClose + "`n`n" + $p1210) -and -not $t1.Contains($s123) -and -not $t1.Contains('Depuis le calcul 12.9,')) "courbe du calcul 12.9 : texte fixe sans la phrase de la 12.3, puis le seul paragraphe du calcul 12.10"
$t2 = Get-OldText @{ 'A|std' = (New-OldCv '12.2') }
Chk 'O2' ($t2.Contains("`n`n" + $oldFixed + "`n`nDepuis le calcul 12.9,") -and $t2.EndsWith("`n`n" + $p1210) -and $p1210.Contains('(0, 30 et 100 ns avec le calcul 12.9)') -and -not $t2.Contains('au lieu de 0, 30 et 100 ns')) "courbe du calcul 12.2 : texte fixe d avant (phrase de la 12.3 a sa place), paragraphes des calculs 12.9 et 12.10 ; niveaux 0, 30 et 100 ns attribues au calcul 12.9"
$t3 = Get-OldText @{ 'A|std' = (New-OldCv '') }
Chk 'O3' ($t3.Contains("`n`n" + $oldFixed + "`n`nDepuis le calcul 12.9,") -and $t3.EndsWith("`n`n" + $p1210)) "courbe sans version (anterieure a 12.1) : phrase de la 12.3, paragraphes 12.9 et 12.10"
$t4 = Get-OldText @{ 'A|std' = (New-OldCv '12.3') }
Chk 'O4' (-not $t4.Contains($s123) -and $t4.Contains("`n`n" + $kA + "`n" + $kClose + "`n`nDepuis le calcul 12.9,") -and $t4.EndsWith("`n`n" + $p1210)) "courbe du calcul 12.3 (borne) : pas de phrase de la 12.3, paragraphes 12.9 et 12.10"
$t5 = Get-OldText @{ 'A|std' = (New-OldCv '12.9'); '0|long' = (New-OldCv '12.2' '0'); 'A|std_h0' = (New-OldCv '') }
Chk 'O5' ([regex]::Matches($t5, [regex]::Escape($s123)).Count -eq 1 -and $t5.Contains("`n`n" + $oldFixed + "`n`n")) "melange 12.9, 12.2 (lecteur 0) et sans version : phrase de la 12.3 une seule fois, a sa place"
$t6 = Get-OldText @{ 'A|std' = (New-OldCv 'x.y') }
Chk 'O6' (-not $t6.Contains($s123) -and $t6.Contains("`n`n" + $kA + "`n" + $kClose) -and -not $t6.Contains('Depuis le calcul')) "version illisible : ni phrase de la 12.3 ni paragraphe (Test-CurveCalcBefore faux)"
$script:Lang = 'en'
$t7 = Get-OldText @{ 'A|std' = (New-OldCv '12.2') }
$script:Lang = 'fr'
Chk 'O7' ($t7.Contains(' ' + $script:I18n[$s123] + "`n" + $script:I18n[$kClose]) -and $t7.Contains($script:I18n[$kA] + ' ' + $script:I18n[$s123]) -and $t7.Contains('(0, 30 and 100 ns with calculation 12.9)') -and -not ($t7 -match 'Fermer la fenêtre|Une courbe antérieure|Depuis le calcul 12\.10|au lieu de')) "anglais : texte fixe, phrase de la 12.3, fin du texte et paragraphe du calcul 12.10 traduits (le paragraphe du calcul 12.9 est traduit hors de 010 et 018, tables de ce test)"
if (-not ($t7.Contains('(0, 30 and 100 ns with calculation 12.9)'))) { "  texte anglais : $($t7 -replace "`n", ' | ')" }
$script:OldCalib = $null

"--- B : Bibliotheque, ecriture refusee pour un lecteur cible"
$script:OpOverride = $null; Enter-OpOverride 'library'
Chk 'B1' ($script:OpOverride.Refused -eq $false) "Enter-OpOverride : Refused faux au depart"
$script:TargetDrives = @{ A = '2' }; Set-Ui 0 $true; Reset-Run
$okW = Test-TargetWriteAllowed $img['jeu.adf'] '(auto)' $true
Chk 'B2' (-not $okW -and $script:OpOverride.Refused -eq $true -and $script:Msgs.Count -eq 1) "refus (cible 2 sans courbe croisee) : fenetre « Ecriture refusee » et OpOverride.Refused pose"
Enter-OpOverride 'library'
Chk 'B3' ($script:OpOverride.Refused -eq $false) "surcharge deja active reprise par une nouvelle operation : Refused remis a faux"
$script:OpOverride = $null; Reset-Run
$okW2 = Test-TargetWriteAllowed $img['jeu.adf'] '(auto)' $true
Chk 'B4' (-not $okW2 -and $null -eq $script:OpOverride) "refus hors operation de la Bibliotheque (bouton ECRIRE) : aucune surcharge creee, aucune erreur"
$script:TargetDrives = @{}
$sv = @{ File = 'C:\x\tab.adf'; Tracks = 'c=0' }
$m0 = @{ State = $sv; Kept = $false; Cut = ''; Head = $null; EmptyOff = $false; Archive = $false }
Reset-Run; Show-LibEndNotice @{ Kind = 'library'; Saved = $sv; Refused = $true; Stopped = $false } 'C:\x\op.adf' $m0
$b5l = "Bibliothèque : écriture refusée, réglages de l'onglet Écriture rétablis (le préréglage de la Bibliothèque n'est pas enregistré) : tab.adf, champ Pistes « c=0 »."
$b5n = "Bibliothèque : écriture refusée. Onglet Écriture rétabli : tab.adf, champ Pistes « c=0 »."
Chk 'B5' (($script:Log -join '|') -eq $b5l -and $script:Notice -eq $b5n) "refus : journal « $($script:Log -join '|') » ; avis « $($script:Notice) »"
Reset-Run; Show-LibEndNotice @{ Kind = 'library'; Saved = $sv; Refused = $false; Stopped = $false } 'C:\x\op.adf' $m0
Chk 'B6' (($script:Log -join '|') -eq "Bibliothèque : opération terminée, réglages de l'onglet Écriture rétablis (le préréglage de la Bibliothèque n'est pas enregistré) : tab.adf, champ Pistes « c=0 »." -and $script:Notice -eq "Bibliothèque terminée. Onglet Écriture rétabli : tab.adf, champ Pistes « c=0 ».") "sans refus : textes d avant (« operation terminee »)"
Reset-Run; Show-LibEndNotice @{ Kind = 'library'; Saved = $sv; Stopped = $true } 'C:\x\op.adf' $m0
Chk 'B7' (@($script:Log)[0] -like "Bibliothèque : opération arrêtée, réglages*" -and $script:Notice -like "Bibliothèque arrêtée : pour reprendre*") "arret sans refus (surcharge sans cle Refused) : textes d avant (« operation arretee »)"
$script:Lang = 'en'; Reset-Run; Show-LibEndNotice @{ Kind = 'library'; Saved = $sv; Refused = $true; Stopped = $false } 'C:\x\op.adf' $m0; $script:Lang = 'fr'
Chk 'B8' (($script:Log -join '|') -like 'Library: write refused, Write tab settings restored*' -and $script:Notice -like 'Library: write refused. Write tab restored*') "anglais : $($script:Log -join '|') / $($script:Notice)"

"--- C : origine des cylindres de test sans parentheses"
$c1 = Get-CalibCylinders $img['jeu.adf'] '(auto)'
$c2 = Get-CalibCylinders $img['jeu-80cyl.adf'] '(auto)'
$script:GwFormats = @{ 'acorn.dfs.ss' = @{ Cyls = 40 }; 'raw.15' = @{ Cyls = 15 } }
$c3 = Get-CalibCylinders $img['jeu.adf'] 'raw.15'; $c4 = Get-CalibCylinders $img['jeu.adf'] 'acorn.dfs.ss'
$script:GwFormats = @{}
$ln = @($c1, $c2, $c3, $c4 | ForEach-Object { (T "Cylindres de test : {0} ({1})") -f '0-79', "$($_.Src)" })
$nested = @($ln | Where-Object { ([regex]::Matches($_, '\(')).Count -ne 1 -or ([regex]::Matches($_, '\)')).Count -ne 1 })
Chk 'C1' ($null -eq $c1.NCyl -and $c1.Src -eq "80 cylindres par défaut, nombre non lisible dans l'image" -and $c2.NCyl -eq 80 -and $c3.NCyl -eq 35 -and $c3.Src -eq '35 cylindres pour le format raw.15 : 15 dans la définition de gw, 35 au moins pour la calibration' -and $c4.Src -eq "40 cylindres d'après le format acorn.dfs.ss") "origines : « $($c1.Src) » ; « $($c3.Src) »"
Chk 'C2' ($nested.Count -eq 0) "« Cylindres de test : {0} ({1}) » : une seule paire de parentheses sur les 4 origines$(if ($nested.Count) { ' ; ' + $nested[0] })"
$script:Lang = 'en'; $c5 = Get-CalibCylinders $img['jeu.adf'] '(auto)'; $script:GwFormats = @{ 'raw.15' = @{ Cyls = 15 } }; $c6 = Get-CalibCylinders $img['jeu.adf'] 'raw.15'; $script:GwFormats = @{}; $script:Lang = 'fr'
Chk 'C3' ($c5.Src -eq '80 cylinders by default, count not readable from the image' -and $c6.Src -eq '35 cylinders for format raw.15: 15 in the gw definition, at least 35 for the calibration') "anglais : « $($c5.Src) » ; « $($c6.Src) »"

"--- D : barre de la calibration sur un etat simule sans PhaseStart"
$script:Cal = @{ Hold = $false; SwapHold = $null; Stage = 'coarse'; Cyls = @(0, 10, 20, 30); WriteDurs = @(); ReadDurs = @(); EstTrack = 0.7; EstErase = 0.0
                 Cond = $false; CondRun = $false; TotalPasses = 5; PassesDone = 1; Phase = 'write'; PhaseStart = $null; Mode = ''; ValueTxt = '30 ns'; Drive = 'A' }
$errD = ''; try { Update-CalibProgress } catch { $errD = $_.Exception.Message }
$t1 = $lblWCal.Text; $v1 = $pbWCal.Value
$script:Cal.PhaseStart = (Get-Date).AddSeconds(-3)
$errD2 = ''; try { Update-CalibProgress } catch { $errD2 = $_.Exception.Message }
$v2 = $pbWCal.Value
Chk 'D1' (-not $errD -and $t1 -like 'Calibration : 20 %, reste environ*' -and $v1 -eq 20) "PhaseStart nul : aucune erreur$(if ($errD) { ' (' + $errD + ')' }), passe en cours a 0 : $t1"
Chk 'D2' (-not $errD2 -and $v2 -gt $v1) "PhaseStart pose : avancement de la phase compte ($v1 % -> $v2 %)"
# fix1 (B1) : fenetre du controle de surface ouverte (Hold) : texte court, francais et anglais
$script:Cal.Hold = $true; Update-CalibProgress; $t3 = $lblWCal.Text
$script:Lang = 'en'; Update-CalibProgress; $t3e = $lblWCal.Text; $script:Lang = 'fr'
Chk 'D3' ($t3 -eq 'Calibration en attente : décision sur le contrôle de surface (lecteur A).' -and $t3e -eq 'Calibration on hold: surface check, decision requested (drive A).') "controle de surface en attente : « $t3 » ; « $t3e »"
$script:Cal = $null

"--- F : facteur de marque reutilise, conseil de mesure"
function New-Km([string]$brand, [int]$h, [double]$k, [string]$date, [string]$fam = 'std') {
    return @{ Drive = 'A'; Family = $fam; Head = $h; K = $k; ContentCalc = $script:ContentCalc; Calc = $script:CalibCalc; Etat = 'mesure'; Brand = $brand; Date = $date }
}
function Set-Km([string]$brand, [double[]]$ks, [string]$fam = 'std') {
    $script:ContentMeasures = @(); $d = 1
    foreach ($k in $ks) { foreach ($h in 0, 1) { $script:ContentMeasures += New-Km $brand $h $k ('0{0}/11/2026 10:00' -f $d) $fam }; $d++ }
}
function Get-Hint($wf) { return ,@(@($wf.Lines) | Where-Object { $_ -like 'Les mesures de la marque*' -or $_ -like 'Aucun facteur mesuré pour la marque*' }) }
$script:TargetDrives = @{}; $script:LevelBrand = 'Sony'; Set-Ui 0 $true; $chkWLevel.Checked = $false; $script:CmOk = $true; $script:SkipWhy = $null; $script:Restore = $null; $cmbWCalMode.SelectedIndex = 1
$hA = "Les mesures de la marque « Sony » sur ce lecteur varient de 0,20 d'une disquette à l'autre : pour mesurer celle-ci avant l'écriture, cochez « Mesurer la disquette avant l'écriture lente », avec la mesure « sur l'image à écrire »."
$hC = "Les mesures de la marque « Sony » sur ce lecteur varient de 0,30 d'une disquette à l'autre : pour mesurer celle-ci avant l'écriture, écrivez l'image en écriture lente, avec « Mesurer la disquette avant l'écriture lente » cochée et la mesure « sur l'image à écrire »."
Set-Km 'Sony' @(0.95, 1.05, 1.15)
$wf1 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true
$h1 = Get-Hint $wf1
Chk 'F1' ($wf1.Apply -and $h1.Count -eq 1 -and $h1[0] -eq $hA -and @($wf1.Lines)[-1] -eq $hA -and @($wf1.Lines)[-2] -like 'Facteur de précompensation de cette écriture (lecteur A, marque « Sony »)*médiane des 3 dernières mesures*') "mesures 0,95 / 1,05 / 1,15 (ecart 0,20, flottant 0,1999...) : conseil apres la ligne du facteur : $($h1 -join ' | ')"
Set-Km 'Sony' @(1.00, 1.05, 1.15)
$wf2 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true
Chk 'F2' ((Get-Hint $wf2).Count -eq 0 -and $wf2.Apply) "ecart 0,15 : aucun conseil"
Set-Km 'Sony' @(0.90, 1.20)
$wf3 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $false
Chk 'F3' ((Get-Hint $wf3).Count -eq 1 -and (Get-Hint $wf3)[0] -eq $hC) "ecriture rapide, case decochee, deux mesures 0,90 / 1,20 : conseil (ecart 0,30, consigne de l ecriture lente) : $((Get-Hint $wf3) -join '')"
Set-Km 'Sony' @(1.10)
$wf4 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true
Chk 'F4' ((Get-Hint $wf4).Count -eq 0) "une seule mesure de la marque (aucun ecart) : aucun conseil"
Set-Km 'Sony' @(0.95, 1.05, 1.15)
$chkWLevel.Checked = $true; $wf5 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true; $chkWLevel.Checked = $false
$script:Restore = @{ Step = 4 }; $wf6 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true; $script:Restore = $null
$cmbWCalMode.SelectedIndex = 2; $wf7 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true; $cmbWCalMode.SelectedIndex = 1
$script:CmOk = $false; $wf8 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true; $script:CmOk = $true
$script:SkipWhy = @{ Why = 'une face' }; $wf9 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true; $script:SkipWhy = $null
Chk 'F5' (@($wf5, $wf6, $wf7, $wf8, $wf9 | Where-Object { (Get-Hint $_).Count -gt 0 }).Count -eq 0 -and @($wf5, $wf6, $wf7, $wf8, $wf9 | Where-Object { -not $_.Apply }).Count -eq 0) "ecart 0,20 mais mesure cochee, restauration, test rapide, image non mesurable sur son contenu, image qui ne recouvre pas le motif : aucun conseil (facteur toujours applique)"
$next = @{ Drive = 'A'; Fam = 'std'; Img = $img['jeu.adf']; K = @{ 0 = 1.12; 1 = 1.08 }; Src = @{ 0 = 'mesure'; 1 = 'mesure' }; Brand = 'Sony' }
$wf10 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true $next
$cmN = $script:CmN; $wf11 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true $null -Peek
Chk 'F6' ((Get-Hint $wf10).Count -eq 0 -and $wf10.Src[0] -eq 'mesure' -and (Get-Hint $wf11).Count -eq 0 -and $wf11.Apply -and $script:CmN -eq $cmN) "facteur mesure sur cette disquette : aucun conseil ; calcul seul (-Peek, libelle) : aucun conseil, mesure possible non evaluee"
$script:TargetDrives = @{ A = '0' }; $wf12 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true; $script:TargetDrives = @{}
Set-Ui 3 $true; $wf13 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true; Set-Ui 0 $true
Chk 'F7' ((Get-Hint $wf12).Count -eq 0 -and $wf12.Target -eq '0' -and (Get-Hint $wf13).Count -eq 0 -and -not $wf13.Apply) "lecteur cible (facteur 1) et profil Manuel (facteur non applique) : aucun conseil"
# Long track sans aucune mesure de la marque
$hB = "Aucun facteur mesuré pour la marque « Sony » sur ce lecteur : en long track, le meilleur facteur s'écarte souvent de 1 ; pour le mesurer, cochez « Mesurer la disquette avant l'écriture lente », avec la mesure « sur l'image à écrire »."
$script:ContentMeasures = @(New-Km 'Kao' 0 1.2 '01/11/2026 10:00' 'long'; New-Km 'Kao' 1 1.2 '01/11/2026 10:00' 'long')
$wf14 = Get-WriteFactorPlan $img['jeu-long.ipf'] '(auto)' $true
Chk 'F8' ($wf14.Apply -and $wf14.Fam -eq 'long' -and (Get-Hint $wf14).Count -eq 1 -and (Get-Hint $wf14)[0] -eq $hB -and @($wf14.Lines)[-2] -like '*tête 0 × 1,00 (k 1 (aucune mesure de ce lecteur pour la marque « Sony » ; 1 mesure(s) d''autres marques))*') "long track, k 1 faute de mesure de la marque (mesures d une autre marque non empruntees) : $((Get-Hint $wf14) -join '')"
$wf15 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true
Set-Km 'Sony' @(1.00, 1.02) 'long'; $wf16 = Get-WriteFactorPlan $img['jeu-long.ipf'] '(auto)' $true
$chkWLevel.Checked = $true; $script:ContentMeasures = @(); $wf17 = Get-WriteFactorPlan $img['jeu-long.ipf'] '(auto)' $true; $chkWLevel.Checked = $false
$script:CmOk = $false; $wf18 = Get-WriteFactorPlan $img['jeu-long.ipf'] '(auto)' $true; $script:CmOk = $true
Chk 'F9' (@($wf15, $wf16, $wf17, $wf18 | Where-Object { (Get-Hint $_).Count -gt 0 }).Count -eq 0) "aucun conseil : standard sans mesure, long track avec des mesures proches de la marque, mesure cochee, image long track non mesurable"
$script:LevelBrand = ''; $script:ContentMeasures = @(); $wf19 = Get-WriteFactorPlan $img['jeu-long.ipf'] '(auto)' $false
$script:Lang = 'en'; $script:LevelBrand = 'Sony'; $wf20 = Get-WriteFactorPlan $img['jeu-long.ipf'] '(auto)' $false; Set-Km 'Sony' @(0.95, 1.05, 1.15); $wf21 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true; $script:Lang = 'fr'
Chk 'F10' ((Get-Hint $wf19)[0] -like 'Aucun facteur mesuré pour la marque « (non précisée) »*' -and @($wf20.Lines)[-1] -eq 'No measured factor for brand "Sony" on this drive: in long track, the best factor often differs from 1; to measure it, write the image as a slow write, with "Measure the disk before the slow write" checked and the "on the image to write" measure.' -and @($wf21.Lines)[-1] -eq 'Measurements of brand "Sony" on this drive vary by 0.20 from one disk to another: to measure this disk before writing, check "Measure the disk before the slow write", with the "on the image to write" measure.') "marque non precisee ; anglais : $(@($wf20.Lines)[-1])"
# Relecture : case Mesurer la disquette cochee (etat par defaut) : ecriture rapide jamais mesuree -> conseil, consigne de
# l ecriture lente (et non « cochez » une case deja cochee) ; ecriture lente -> mesure demandee, aucun conseil
$script:LevelBrand = 'Sony'; Set-Km 'Sony' @(0.90, 1.20); $chkWLevel.Checked = $true
$wf22 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $false; $wf23 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true
$script:ContentMeasures = @(); $wf24 = Get-WriteFactorPlan $img['jeu-long.ipf'] '(auto)' $false; $chkWLevel.Checked = $false
$hD = "Aucun facteur mesuré pour la marque « Sony » sur ce lecteur : en long track, le meilleur facteur s'écarte souvent de 1 ; pour le mesurer, écrivez l'image en écriture lente, avec « Mesurer la disquette avant l'écriture lente » cochée et la mesure « sur l'image à écrire »."
Chk 'F11' ((Get-Hint $wf22).Count -eq 1 -and (Get-Hint $wf22)[0] -eq $hC -and (Get-Hint $wf23).Count -eq 0 -and $wf23.Apply -and (Get-Hint $wf24).Count -eq 1 -and (Get-Hint $wf24)[0] -eq $hD -and @(@($wf22.Lines; $wf24.Lines) | Where-Object { $_ -like '*cochez « Mesurer*' }).Count -eq 0) "case cochee : ecriture rapide -> $((Get-Hint $wf22) -join '') ; ecriture lente -> aucun conseil ; long track rapide -> $((Get-Hint $wf24) -join '')"
$script:ContentMeasures = @(); $script:LevelBrand = ''

"--- S : statique"
$s140 = [System.IO.File]::ReadAllText((Get-FMod '140'))
$s270 = [System.IO.File]::ReadAllText((Get-FMod '270'))
Chk 'S1' ($s140.Contains('if ($script:OpOverride) { $script:OpOverride.Refused = $true }') -and $s270.Contains('$elapsed = if ($cal.PhaseStart -is [datetime]) { ((Get-Date) - $cal.PhaseStart).TotalSeconds } else { 0.0 }') -and $s140.Contains('$hint = Get-WriteFactorHint')) 'cablage : refus note dans la surcharge, garde de PhaseStart, conseil du facteur'
$i010 = Read-I18n '010'; $i018 = Read-I18n '018'
$newK = @("courbe croisée {0} → {1}, {2}, {3}, calcul {4}", "courbe croisée {0} → {1} pour les deux têtes, {2}, {3}, calcul {4}", "courbes croisées {0} → {1} par tête, {2}, {3}, calcul {4}",
          "courbes croisées {0} → {1} par tête, {2}, tête 0 du {3}, tête 1 du {4}, calcul {5}", "Auto : image {0} -> ",
          "Bibliothèque : écriture refusée, réglages de l'onglet Écriture rétablis (le préréglage de la Bibliothèque n'est pas enregistré) : {0}{1}.",
          "Bibliothèque : écriture refusée. Onglet Écriture rétabli : {0}{1}.", "80 cylindres par défaut, nombre non lisible dans l'image",
          "{0} cylindres pour le format {1} : {2} dans la définition de gw, {0} au moins pour la calibration",
          "Les mesures de la marque « {0} » sur ce lecteur varient de {1} d'une disquette à l'autre : pour mesurer celle-ci avant l'écriture, {2}.",
          "Aucun facteur mesuré pour la marque « {0} » sur ce lecteur : en long track, le meilleur facteur s'écarte souvent de 1 ; pour le mesurer, {1}.",
          "cochez « Mesurer la disquette avant l'écriture lente », avec la mesure « sur l'image à écrire »",
          "écrivez l'image en écriture lente, avec « Mesurer la disquette avant l'écriture lente » cochée et la mesure « sur l'image à écrire »")
$bad = @()
foreach ($k in $newK) {
    $v = $i018[$k]
    if (-not $v) { $bad += "absente : $k"; continue }
    foreach ($m in [regex]::Matches($k, '\{\d\}')) { if (-not $v.Contains($m.Value)) { $bad += "$($m.Value) : $k" } }
    if ($v -match '[éèàùçÉ«»]') { $bad += "non traduite : $k" }
}
$oldK = @(' ; lecteur cible {0} : courbes croisées {1} → {0} par tête du {2}', ' ; lecteur cible {0} : courbe croisée {1} → {0} du {2}, pour les deux têtes',
          "Les mesures de la marque « {0} » sur ce lecteur varient de {1} d'une disquette à l'autre : cochez « Mesurer la disquette avant l'écriture lente » (écriture lente, mesure « sur l'image à écrire ») pour mesurer celle-ci avant l'écriture.",
          "Aucun facteur mesuré pour la marque « {0} » sur ce lecteur : en long track, le meilleur facteur s'écarte souvent de 1 ; cochez « Mesurer la disquette avant l'écriture lente » (écriture lente, mesure « sur l'image à écrire ») pour le mesurer.")
$gone = @(@('80 cylindres par défaut (nombre non lisible dans l''image)', '{0} cylindres pour le format {1} ({2} dans la définition de gw, {0} au moins pour la calibration)') | Where-Object { $i010.ContainsKey($_) -or $i018.ContainsKey($_) }) + @($oldK | Where-Object { $i018.ContainsKey($_) })
Chk 'S2' ($bad.Count -eq 0 -and $gone.Count -eq 0) "$($newK.Count) nouvelles cles traduites dans 018 (memes {n}) ; anciennes cles retirees (010, 018)$(if ($bad.Count + $gone.Count) { ' ; ' + ((@($bad) + @($gone)) -join ' | ') })"
$rd = [System.IO.File]::ReadAllText((Join-Path $mods 'README.md'))
Chk 'S3' ($rd -match "300-fn-restauration\.ps1`` \| [^\n]*haute densité n'est reconnue qu'à la lecture de l'original") 'README des modules : refus de l etape 4 de la restauration (haute densite reconnue a la lecture) cite a la ligne du module 300'

# S4 (fix2) : cles nouvelles traduites (memes {n}), anciennes retirees ; 'Mesure de la disquette' traduite par 012 seule (m1)
$i012 = Read-I18n '012'
$k4 = @(@('010', $kA), @('010', $s123), @('010', $kClose),
        @('018', ' ; aucune courbe croisée {1} → {0} : écriture refusée (« Calibrer pour un lecteur cible… »)'),
        @('018', ' ; courbes croisées {1} → {0} par tête : écriture rapide refusée (cochez « Écriture lente »)'), @('010', 'Calibration en attente : décision sur le contrôle de surface (lecteur {0}).'),
        @('018', 'Calibration croisée : déplacez la disquette du lecteur {0} vers le lecteur {1}'), @('018', $p1210))
$bad4 = @()
foreach ($p in $k4) {
    $tb = if ($p[0] -eq '010') { $i010 } else { $i018 }
    $v = $tb[$p[1]]
    if (-not $v) { $bad4 += "absente de $($p[0]) : $($p[1])"; continue }
    foreach ($m in [regex]::Matches($p[1], '\{\d\}')) { if (-not $v.Contains($m.Value)) { $bad4 += "$($m.Value) : $($p[1])" } }
    if ($v -match '[éèàùçÉ«»]') { $bad4 += "non traduite : $($p[1])" }
}
$old4 = @($oldFixed, ' ; lecteur cible {0} : aucune courbe croisée {1} → {0} pour cette famille, écriture refusée (« Calibrer pour un lecteur cible… »)',
          ' ; lecteur cible {0} : courbes croisées {1} → {0} par tête seulement, écriture rapide refusée (cochez « Écriture lente »)',
          'Calibration croisée en attente : déplacez la disquette du lecteur {0} vers le lecteur {1}, puis confirmez.', $p1210Old,
          ' ; lecteur cible {0} : aucune courbe croisée {1} → {0}, écriture refusée (« Calibrer pour un lecteur cible… »)', ' ; lecteur cible {0} : courbes croisées {1} → {0} par tête, écriture rapide refusée (cochez « Écriture lente »)', 'Calibration en attente : contrôle de surface, décision demandée (lecteur {0}).')
$gone4 = @($old4 | Where-Object { $i010.ContainsKey($_) -or $i018.ContainsKey($_) })
$m14 = (-not $i018.ContainsKey('Mesure de la disquette')) -and $i012['Mesure de la disquette'] -eq 'Disk measurement'
Chk 'S4' ($bad4.Count -eq 0 -and $gone4.Count -eq 0 -and $m14) "$($k4.Count) nouvelles cles traduites (010, 018) ; $($old4.Count) anciennes retirees ; 'Mesure de la disquette' : 012 seule ('$($i012['Mesure de la disquette'])')$(if ($bad4.Count + $gone4.Count) { ' ; ' + ((@($bad4) + @($gone4 | ForEach-Object { 'encore la : ' + $_.Substring(0, [math]::Min(60, $_.Length)) })) -join ' | ') })"

# S5 (fix1, m2) : avertissement de fin de calibration en tete de lblWCal et des quatre libelles du profil (270
# Complete-PrecompCalib, non joue ici : lecture du texte de la fonction)
$cpc = Get-FFn '270' 'Complete-PrecompCalib'
$s5 = @(($cpc.Contains("`$convHead = if (`$convTxt) { `$convTxt.Trim() + ' ' } else { '' }")), ([regex]::Matches($cpc, [regex]::Escape('$lblWProfileInfo.Text = $convHead + ((T "')).Count -eq 4),
        ($cpc.Contains('if ($convTxt) { $lblWCal.Text = $convHead + $lblWCal.Text }')), (-not $cpc.Contains('+ $convTxt')), (-not $cpc.Contains('+= $convTxt')))
Chk 'S5' (@($s5 | Where-Object { -not $_ }).Count -eq 0) "270 Complete-PrecompCalib : avertissement (`$convHead) en tete de lblWCal et des 4 libelles de fin du profil, plus a leur suite ($(($s5 | ForEach-Object { if ($_) { 'oui' } else { 'NON' } }) -join ', '))"

Remove-Item -LiteralPath $imgDir -Recurse -Force -ErrorAction SilentlyContinue
$nk = if ($script:Fail) { ' ; non conformes : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-1210-final-ac : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
