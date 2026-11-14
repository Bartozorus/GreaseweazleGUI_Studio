param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-target-n) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out.
# Copie adaptee par la RC6 (10/11/2026, v1210\rc6\make_rc6_copies.py, source v1210\rc5\fix2\logic-1210-target-m.ps1) : refus de la restauration sans courbe croisee « standard » A -> 0 (2c1eb08) au lieu de « ... en double densite » (R9).
# Copie adaptee par la correction fix2 de la RC5 (10/11/2026, v1210\rc5\fix2\make_fix2_copies.py) : Get-WriteImageFamily (140), appelee par Get-TargetWriteInfo, ajoutee aux fonctions extraites ; phrase du cadre d un refus faute de courbe croisee : refus de la restauration au lancement (R9).
# 12.10 (v1210\croisee\etape3) : ecriture pour un lecteur cible (conception-croisee.md § 4) et retrait de la correction
# « lecteur cible » Dk. Fonctions reelles extraites par l arbre syntaxique (fichier de travail gen-1210-target.ps1,
# dot-source) : 140 lecteur cible (Get-DriveIds, Get-TargetDrive, Set-TargetDrive, Get-TargetDriveItems, Get-TargetCurves,
# Get-TargetCurvesText, Get-TargetWriteInfo, Get-TargetWriteBlock, Test-TargetWriteAllowed, Set-TargetDriveLayout,
# Update-TargetDriveUi, Set-TargetDriveFromUi), facteur (Get-WriteFactorPlan, Get-WriteFactorSrcText, Get-WriteFactorNote),
# Update-SlowUi, Start-WriteTabWrite, Start-PresetWrite ; 220 Set-PrecompFields et courbes de famille ; 240 magasin des
# courbes ; 230 famille et calcul ; 274 facteur du lecteur et configuration des mesures ; 120 bloc targetDrive ; 300
# Get-RsCalibText, Start-RestoreWrite ; instructions reelles de Start-ImageWrite, Start-Restore, Load-Config et
# Complete-WriteCheck enveloppees dans des fonctions du fichier genere. Remplacants nommes : T, Append-Log (journal en
# memoire), Show-AppMessage (enregistree, aucune fenetre), Start-ImageWrite et Start-LevelBeforeWrite (comptes),
# Update-PrecompForImage (compte, puis Set-PrecompFields reel), detection de l image (haute densite, cellule, codage :
# d apres le nom du fichier), etapes de la restauration. Controles : pscustomobject, et ComboBox reels crees en memoire
# pour la liste « Lecteur cible » (System.Windows.Forms par Import-TestWinForms, aucun Add-Type, aucune fenetre). Aucun gw,
# aucune application.
#  M : meme lecteur, choix memorise par source, lecteurs inconnus
#  P : Set-PrecompFields (courbes croisees par tete, commune, perimees, absentes), Get-TargetWriteInfo (familles, haute
#      densite, profil force, sans effet), refus (Test-TargetWriteAllowed)
#  F : facteur 1 (Get-WriteFactorPlan : lignes de journal, facteur de marque non applique), Get-WriteFactorNote
#  W : Start-ImageWrite (instructions reelles : ligne « sans effet », champs remis aux courbes croisees, Rep.Target),
#      Start-WriteTabWrite (refus avant la confirmation, mesure non faite), Complete-WriteCheck (verdict)
#  B : Bibliotheque (Start-PresetWrite reel : ni calibration ni mesure, sans effet -> deroule ordinaire)
#  R : restauration (refus de Start-Restore, Start-RestoreWrite reel avec Start-PresetWrite reel, Get-RsCalibText)
#  U : liste « Lecteur cible » (Update-TargetDriveUi, Set-TargetDriveFromUi, Update-SlowUi : case de la mesure)
#  C : configuration (12.9 avec targetCorrection relue sans erreur, bloc targetDrive aller-retour, entrees illisibles,
#      champ dk des mesures ignore)
#  S : statique (aucune reference a Dk dans le code des modules, textes i18n, cablage, CHANGELOG, README)
# Relecture de l etape 3 (09/11/2026) : copie adaptee de etape3\logic-1210-target.ps1, qui la remplace dans la campagne.
# Adaptes : P4 (refus propre aux courbes croisees par tete en ecriture rapide), R1 et Test-RestoreStart
# (Get-RestoreTargetInfo). Ajoutes : P12 (libelle, ecriture rapide par tete seules), P13 (libelle haute densite), F9
# (courbe croisee d un autre calcul gardee), B6 et B7 (refus de Start-PresetWrite avant toute branche de calibration),
# R10 a R14 (refus de la restauration avant la lecture de l original : long track seule, haute densite, GCR sans effet,
# par tete seules ; haute densite detectee : etape 4), S11 (README racine).
# Petits defauts du banc (09/11/2026) : copie adaptee de etape3\revue\logic-1210-target-r.ps1, qui la remplace dans la
# campagne. Adapte : R14 (haute densite reconnue a la lecture de l original : raison propre a la restauration, sans le
# profil Manuel que la restauration n offre pas).
# Finalisation 12.10 (09/11/2026, v1210\finalisation) : copie adaptee de v1210\doc\logic-1210-target-d.ps1, qui la remplace
# dans la campagne (extra.txt). Adaptes : P1 et P2 (courbes croisees dans les champs : Set-PrecompFields ne rend plus de
# complement, la courbe croisee est nommee entre les parentheses du libelle par Get-TargetProfileText, extraite en plus :
# sens, test, date ou dates des tetes, calcul). Le libelle complet est verifie par logic-1210-final (cas A). Harnais :
# Get-WriteFactorHint (appelee par Get-WriteFactorPlan) extraite en plus, remplacant Test-ContentMeasurable (mesure sur
# l image impossible : aucun conseil de mesure, les lignes du facteur attendues ici restent les dernieres ; le conseil est
# verifie par logic-1210-final, cas F).
# Correction fixB de la RC5 (10/11/2026, v1210\rc5\fixB) : copie adaptee de v1210\rc5\fixA\logic-1210-target-k, qui la remplace dans la
# campagne : Update-SlowUi (140) delegue la case de la mesure a Update-WLevelUi (140), qui lit
# Get-TargetWriteInfo et Get-LevelBeforeWriteKind (260) : extraits en plus ; cas U joues avec l image jeu.adf (l etat de la
# case suit l effet du lecteur cible sur l ecriture, et non plus le seul choix) ; S3 lit aussi Update-WLevelUi. Attentes
# inchangees.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR')
[System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR')
# Correction tour 2 de la relecture des captures (10/11/2026, v1210\rc2\fix2) : copie adaptee de
# v1210\finalisation\logic-1210-target-g, qui la remplace dans la campagne. P10, P12 : complements du lecteur cible
# raccourcis (220 Set-PrecompFields : deux lignes du libelle du profil en francais).
# RC4 (10/11/2026, v1210\rc4, 789c19d) : copie adaptee de v1210\rc3\fix1\logic-1210-target-h, qui la remplace dans la
# campagne. Le refus du lecteur cible n est plus un complement rendu par Set-PrecompFields : Sync-WTargetHead (220) le met
# en tete du libelle en sortie d Update-PrecompForImage, d apres Get-TargetWriteInfo (140, BlockKind). Extraits en plus :
# Update-PrecompForImage (220, renomme Update-PrecompForImageR : le remplacant qui compte les appels sert aux cas W, B, R),
# Get-WProfileSpec, Get-HdProfile, Get-HdCommonCurve, Set-WProfileText, Get-WTargetHead, Sync-WTargetHead (220),
# $script:PrecompHdDefault, $script:WFactorNote, $script:WTargetHead, $script:WProfilePath, $script:WProfileLabel,
# $script:WProfileBuilding (040) ; remplacants : Update-CurveButton, libelle du profil simule. Adaptes : P10, P12, P13
# (Set-PrecompFields sans complement de refus ; libelle complet du vrai Update-PrecompForImage, refus court en tete), R9
# (phrase du lecteur cible en tete du cadre « Calibration du lecteur », phrases des familles a sa suite).
# Correction tour 1 de la RC4 (10/11/2026, v1210\rc4\fix1) : copie adaptee de v1210\rc4\logic-1210-target-i, qui la
# remplace dans la campagne : R9 attend la phrase raccourcie du lecteur cible (« a la place de celle du lecteur A »).
# Correction fixA de la RC5 (10/11/2026, v1210\rc5\fixA) : copie adaptee de v1210\rc4\fix1\logic-1210-target-j, qui la
# remplace dans la campagne : Get-RsCalibText (300) tire sa phrase du lecteur cible de Get-RestorePlan (decision de la
# restauration) ; Get-RestoreFormat et Get-RestorePlan (300) extraits en plus. Attentes inchangees (format de la
# restauration : detection automatique, Get-Setting du test).
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mods = Join-Path $Wt 'src\modules'
if (-not (Test-Path -LiteralPath (Join-Path $mods '140-fn-ecriture.ps1'))) { throw "modules introuvables sous $Wt" }

$script:TgAsts = @{}
function Get-TgAst([string]$path) {
    if ($script:TgAsts.ContainsKey($path)) { return $script:TgAsts[$path] }
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message) (ligne $(@($er)[0].Extent.StartLineNumber))" }
    $script:TgAsts[$path] = $ast
    return $ast
}
function Get-TgMod([string]$num) {
    $f = @(Get-ChildItem -LiteralPath $mods -Filter "$num-*.ps1")
    if ($f.Count -ne 1) { throw "module $num : $($f.Count) fichier(s)" }
    return $f[0].FullName
}
function Get-TgFnAst([string]$num, [string]$name) {
    $fd = @((Get-TgAst (Get-TgMod $num)).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) | Where-Object { $_.Name -eq $name })
    if ($fd.Count -ne 1) { throw "fonction $name dans $num : $($fd.Count) (1 attendue)" }
    return $fd[0]
}
function Get-TgFn([string]$num, [string]$name) { return (Get-TgFnAst $num $name).Extent.Text }
function Get-TgAssign([string]$num, [string]$left) {
    $st = @((Get-TgAst (Get-TgMod $num)).EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left.Extent.Text -eq $left })
    if ($st.Count -ne 1) { throw "affectation $left dans $num : $($st.Count) (1 attendue)" }
    return $st[0].Extent.Text
}
function Get-TgStmt([string]$num, [string]$fn, [string]$typeName, [string]$startsWith, [string]$contains = '') {
    # Texte d une instruction d une fonction, par son type d arbre syntaxique, son debut et son contenu : la plus large
    $fd = Get-TgFnAst $num $fn
    $hits = @($fd.Body.FindAll({ param($x) $x.GetType().Name -eq $typeName -and $x.Extent.Text.StartsWith($startsWith) -and (-not $contains -or $x.Extent.Text.Contains($contains)) }, $true) | Sort-Object { $_.Extent.Text.Length } -Descending)
    if ($hits.Count -eq 0) { throw "instruction $typeName introuvable dans $fn ($startsWith / $contains)" }
    return $hits[0].Extent.Text
}

# ---------------------------------------------------------------- extraction
$parts = New-Object System.Collections.Generic.List[string]
foreach ($p in @(
        @('010', @('Format-UiNum')),
        @('120', @('Get-Cfg', 'Export-TargetDrives', 'Import-TargetDrives')),
        @('140', @('Get-WarmMinutesText', 'Update-SlowUi', 'Update-WLevelUi', 'Test-FluxImage', 'Test-RawFluxWrite', 'Get-WriteFactorSrcText', 'Get-WriteFactorPlan', 'Get-WriteFactorHint',
                   'Get-WriteFactorNote', 'Get-DriveIds', 'Get-TargetDrive', 'Set-TargetDrive', 'Get-TargetDriveItems', 'Get-TargetCurves',
                   'Get-TargetCurvesText', 'Get-TargetWriteInfo', 'Get-WriteImageFamily', 'Get-TargetWriteBlock', 'Test-TargetWriteAllowed', 'Set-TargetDriveLayout',
                   'Update-TargetDriveUi', 'Set-TargetDriveFromUi', 'Start-WriteTabWrite', 'Start-PresetWrite')),
        @('220', @('Get-CurveDate', 'Test-HeadCurvesCurrent', 'Get-FamilyCurves', 'Get-DriveFamilyCurves', 'Get-HeadSpec', 'Set-PrecompFields', 'Get-TargetProfileText',
                   'Get-WProfileSpec', 'Get-HdProfile', 'Get-HdCommonCurve', 'Set-WProfileText', 'Get-WTargetHead', 'Sync-WTargetHead', 'Update-PrecompForImage')),
        @('230', @('Get-ImageFamily', 'Get-CalibFamilyName', 'Get-CurveCalc', 'Get-CurveCalcRef', 'Get-CurveCalcText', 'Test-CurveHd', 'Get-Median')),
        @('240', @('Get-DriveCurveKey', 'Split-DriveCurveKey', 'Get-DriveCurve', 'Set-DriveCurve', 'Sync-PrecompCurves', 'Get-DriveCurveKeys', 'Split-CrossDrive', 'Get-CrossCalibTargets')),
        @('260', @('Get-LevelBeforeWriteKind')),
        @('265', @('Get-LevelBrandKey')),
        @('274', @('ConvertTo-FiniteOrNull', 'Get-ConfigDouble', 'Get-RecValues', 'ConvertTo-ContentConfig', 'ConvertFrom-ContentConfig', 'Limit-WriteFactor', 'Get-DriveK')),
        @('300', @('Get-RsCalibText', 'Get-RestoreTargetInfo', 'Start-RestoreWrite', 'Get-RestoreFormat', 'Get-RestorePlan')),
        @('150', @('Test-HdFormat')))) {
    foreach ($n in $p[1]) { $parts.Add((Get-TgFn $p[0] $n)) }
}
# RC4 : vrai Update-PrecompForImage (220) renomme Update-PrecompForImageR (le remplacant Update-PrecompForImage, plus bas,
# compte les appels des cas W, B et R) : libelle complet des cas P10, P12, P13
$ixU = -1; for ($i = 0; $i -lt $parts.Count; $i++) { if ($parts[$i] -match '^function Update-PrecompForImage\(') { $ixU = $i } }
if ($ixU -lt 0) { throw 'Update-PrecompForImage (220) introuvable' }
$parts[$ixU] = $parts[$ixU] -replace '^function Update-PrecompForImage\(', 'function Update-PrecompForImageR('
# Instructions reelles enveloppees : Start-ImageWrite (lecteur cible de l ecriture, champs --precomp, Rep.Target)
$parts.Add("function Test-ImageWriteTarget([bool]`$slow) {`r`n    " +
    ((@((Get-TgStmt '140' 'Start-ImageWrite' 'AssignmentStatementAst' '$tw = Get-TargetWriteInfo'),
        (Get-TgStmt '140' 'Start-ImageWrite' 'AssignmentStatementAst' '$tgtDrive = '),
        (Get-TgStmt '140' 'Start-ImageWrite' 'IfStatementAst' 'if ($tw.Tgt -and -not $tw.Applies'),
        (Get-TgStmt '140' 'Start-ImageWrite' 'AssignmentStatementAst' '$tc = @($tw.Curves)'),
        (Get-TgStmt '140' 'Start-ImageWrite' 'IfStatementAst' 'if ($tgtDrive -and $tc.Count -gt 0)'),
        (Get-TgStmt '140' 'Start-ImageWrite' 'IfStatementAst' 'if ($tgtDrive) {' 'Rep.Target'))) -join "`r`n    ") +
    "`r`n    return @{ TgtDrive = `$tgtDrive; Tw = `$tw }`r`n}")
# Start-Restore : refus avant la lecture de l original, ligne de journal
$parts.Add("function Test-RestoreStart([string]`$drv, [string]`$fmt) {`r`n    " +
    (Get-TgStmt '300' 'Start-Restore' 'AssignmentStatementAst' '$rtg = Get-TargetDrive $drv') + "`r`n    " +
    (Get-TgStmt '300' 'Start-Restore' 'AssignmentStatementAst' '$rti = Get-RestoreTargetInfo') + "`r`n    " +
    (Get-TgStmt '300' 'Start-Restore' 'IfStatementAst' 'if ($rti.Block)') + "`r`n    " +
    (Get-TgStmt '300' 'Start-Restore' 'IfStatementAst' 'if ($rti.Applies) {' 'Append-Log') + "`r`n    return 'suite'`r`n}")
# Load-Config : facteurs mesures et bloc targetDrive (configuration 12.9 avec targetCorrection)
$parts.Add("function Test-LoadTarget(`$w) {`r`n    `$script:ContentMeasures = @(); `$cmBad = 0`r`n    " +
    (Get-TgStmt '120' 'Load-Config' 'ForEachStatementAst' "foreach (`$o in @(Get-Cfg `$w 'driveFactors'") + "`r`n    " +
    (Get-TgStmt '120' 'Load-Config' 'IfStatementAst' 'if ($cmBad -gt 0)') + "`r`n    " +
    (Get-TgStmt '120' 'Load-Config' 'AssignmentStatementAst' '$tdi = Import-TargetDrives') + "`r`n    " +
    (Get-TgStmt '120' 'Load-Config' 'IfStatementAst' 'if ([int]$tdi.Bad -gt 0)') + "`r`n    return @{ Cm = @(`$script:ContentMeasures).Count; CmBad = `$cmBad; Tdi = `$tdi }`r`n}")
# Complete-WriteCheck : complement du verdict
$parts.Add("function Test-CheckVerdict(`$rep, [string]`$txt) {`r`n    " + (Get-TgStmt '170' 'Complete-WriteCheck' 'IfStatementAst' 'if ($rep.Target)') + "`r`n    return `$txt`r`n}")
foreach ($k in 'CalibCalc', 'CalibCalcHd', 'ContentCalc') { $parts.Add((Get-TgAssign '000' "`$script:$k")) }
foreach ($k in 'PrecompStd', 'PrecompLong', 'PrecompStdDefault', 'PrecompLongDefault', 'PrecompThresholdNs', 'ContentFMax',
               'PrecompHdDefault', 'WFactorNote', 'WTargetHead', 'WProfilePath', 'WProfileLabel', 'WProfileBuilding') { $parts.Add((Get-TgAssign '040' "`$script:$k")) }
foreach ($k in 'DriveCurves', 'PrecompCurves', 'CurveKeys', 'TargetDrives', 'LevelBrand') { $parts.Add((Get-TgAssign '560' "`$script:$k")) }
$gen = Join-Path $here 'gen-1210-target-n.ps1'
[System.IO.File]::WriteAllText($gen, ((@($parts) -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
. $gen

# ---------------------------------------------------------------- remplacants
$script:Lang = 'fr'
function T([string]$s) { return $s }
$script:Log = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text) { $script:Log.Add($text) }
$script:Msgs = New-Object System.Collections.Generic.List[string]
function Show-AppMessage([string]$text, [string]$title, [string]$buttons = 'OK', [string]$icon = 'Information') { $script:Msgs.Add("$title|$text"); Append-Log $text; return 'OK' }
$script:N = @{}
function Add-N([string]$k) { if (-not $script:N.ContainsKey($k)) { $script:N[$k] = 0 }; $script:N[$k]++ }
function Get-N([string]$k) { if ($script:N.ContainsKey($k)) { return [int]$script:N[$k] }; return 0 }
function Reset-Run { $script:Log.Clear(); $script:Msgs.Clear(); $script:N = @{}; $script:GwProc = $null }
function Start-ImageWrite([switch]$NoWarmup) { Add-N 'ImageWrite'; $script:GwProc = [pscustomobject]@{ HasExited = $false } }
function Start-LevelBeforeWrite([string]$mode, [switch]$Measure, [switch]$Restore) { Add-N 'LevelBefore' }
function Confirm-PartialWrite([string]$img, [string]$fmt, [string]$tspec) { Add-N 'Partial'; return $true }
$script:StubFam = 'std'
function Update-PrecompForImage([string]$path) { Add-N 'Upd'; $sp = if ($script:StubFam -eq 'long') { $script:PrecompLong } else { $script:PrecompStd }; [void](Set-PrecompFields $sp $script:StubFam) }
function Update-WriteFactorNote { }
function Update-CurveButton([string]$path) { }   # RC4 : appele par le vrai Update-PrecompForImageR
# Detection de l image d apres le nom du fichier
function Get-HighDensityReason([string]$path, [string]$fmt) { if ([System.IO.Path]::GetFileName("$path") -like '*-hd*') { return 'haute densité 1 440 Ko' }; return '' }
function Get-HdCalibFamily([string]$path, [string]$fmt = '') { if ([System.IO.Path]::GetFileName("$path") -like '*-hd*') { return 'hd' }; return '' }
function Get-IpfCellInfo([string]$path) { if ([System.IO.Path]::GetFileName("$path") -like '*long*') { return @{ CellNs = 1890 } }; return @{ CellNs = 2000 } }
function Get-HfeCellInfo([string]$path) { return $null }
function Get-ScpCellInfo([string]$path) { if ([System.IO.Path]::GetFileName("$path") -like '*long*') { return @{ CellNs = 1890 } }; return @{ CellNs = 2000 } }
function Get-ImageEncoding([string]$path, [string]$fmt) {
    if ("$fmt" -like 'commodore.*') { return @{ Enc = 'gcr'; Src = 'format'; Name = 'GCR'; NonMfm = $true } }
    if ([System.IO.Path]::GetExtension("$path").ToLower() -eq '.d64') { return @{ Enc = 'gcr'; Src = 'extension'; Name = 'GCR'; NonMfm = $true } }
    return @{ Enc = 'mfm'; Src = 'extension'; Name = 'MFM'; NonMfm = $false }
}
function Test-NonMfmWrite([string]$img, [string]$fmt) { return [bool](Get-ImageEncoding $img $fmt).NonMfm }
function Write-NonMfmSkip([string]$img, [string]$fmt) { Append-Log 'NonMfmSkip' }
function Write-FluxLevelSkip([string]$img, [string]$fmt) { Append-Log 'FluxLevelSkip' }
function Get-WriteLevelKind([string]$img, [string]$fmt) { if (Test-FluxImage $img) { return '' }; if (Test-NonMfmWrite $img $fmt) { return '' }; if (Get-HighDensityReason $img $fmt) { return 'hd' }; return 'dd' }
function Test-NeedsFormat([string]$img) { return $false }
function Get-CalibCylinders([string]$img, [string]$fmt) { return @{ NCyl = 80 } }
function Get-CalibState([string]$fam, [bool]$heads, [int]$nCyl = 0) { Add-N 'CalibState'; return 'ok' }
function Get-CellOutOfRange([string]$img) { return $null }
$script:WantLevel = $false
function Test-WriteLevelWanted([string]$mode) { return $script:WantLevel }
function Get-LevelWriteSkip([string]$img, [string]$fmt, [string]$ts) { return $null }
function Test-ContentMeasurable([string]$img, [string]$fmt) { return @{ Ok = $false; Why = 'remplacant' } }
function Write-LevelHdNote($hf, $heads) { Append-Log 'LevelHdNote' }
function Get-FormatCalibInfo([string]$name) { return $null }
function Get-HdAutoFields([string]$hf, [bool]$slow) { return @{ P0 = 'hd'; P1 = 'hd' } }
$script:Settings = @{ calMode = 'standard'; levelBeforeWrite = $true; levelBeforeWriteMode = 'content' }
function Get-Setting([string]$k) { return $script:Settings[$k] }
function Format-CalDuration([double]$s) { return "$s s" }
$script:SettingDefs = @{ drive = @{ Codes = @('A', 'B', '0', '1', '2', '3') } }
# Restauration
function Set-WritePreset([string]$mode, [string]$path, [string]$source = '') { $txtWFile.Text = $path; $chkWSlow.Checked = ($mode -eq 'slow'); $cmbWProfile.SelectedIndex = 0; $cmbWProfile.Text = 'Auto (selon image)'; $chkWPrecomp.Checked = $true; $cmbWFmt.Text = '(auto)' }
function Set-Combo($c, $v) { $c.Text = [string]$v }
function Set-Num($c, $v) { $c.Value = $v }
function Get-RestoreKeepCyls { return @() }
function Get-RestoreCalibInfo([string]$fam, [int]$nCyl = 0) { Add-N 'RestoreCalibInfo'; return @{ Need = $false; Text = 'commune aux deux têtes'; Notes = @() } }
function Set-RestoreRepRules { }
$script:Steps = New-Object System.Collections.Generic.List[string]
function Set-RsStep([int]$i, [string]$state, [string]$detail = '') { $script:Steps.Add("$i|$state|$detail") }
$script:Fails = New-Object System.Collections.Generic.List[string]
function Fail-Restore([int]$step, [string]$why) { $script:Fails.Add("$step|$why"); $script:Restore = $null }
function Format-CylList([int[]]$c) { return ($c -join ',') }

# Controles simules
$script:Tips = @{}
$tip = [pscustomobject]@{}
$tip | Add-Member -MemberType ScriptMethod -Name SetToolTip -Value { param($c, $t) $script:Tips[[string]$c.Name] = [string]$t }
$tip | Add-Member -MemberType ScriptMethod -Name GetToolTip -Value { param($c) return [string]$script:Tips[[string]$c.Name] }
$cmbDrive = [pscustomobject]@{ Text = 'A' }
$cmbWProfile = [pscustomobject]@{ SelectedIndex = 0; Text = 'Auto (selon image)' }
$chkWPrecomp = [pscustomobject]@{ Checked = $true; Text = '' }
$chkWSlow = [pscustomobject]@{ Checked = $true }
$txtWPrecomp = [pscustomobject]@{ Text = '' }; $txtWPrecomp1 = [pscustomobject]@{ Text = ''; Enabled = $true }
$lblWPrecomp1 = [pscustomobject]@{ Enabled = $true }
$txtWFile = [pscustomobject]@{ Text = '' }
$lblWProfileInfo = [pscustomobject]@{ Text = '' }   # RC4 : libelle du profil (vrai Update-PrecompForImageR)
$cmbWFmt = [pscustomobject]@{ Text = '(auto)' }
$txtWTracks = [pscustomobject]@{ Text = '' }
$cmbWCalMode = [pscustomobject]@{ SelectedIndex = 1 }
$chkWHard = [pscustomobject]@{ Checked = $false }; $chkWTG43 = [pscustomobject]@{ Checked = $false }
$chkWWarm = [pscustomobject]@{ Text = ''; Enabled = $true }; $chkWCalWarm = [pscustomobject]@{ Text = ''; Enabled = $true }
$numWWarmMin = [pscustomobject]@{ Value = [decimal]5 }
$chkWLevel = [pscustomobject]@{ Name = 'chkWLevel'; Checked = $true; Text = ''; Enabled = $true }
$numWRetries = [pscustomobject]@{ Value = 10 }; $numWRepair = [pscustomobject]@{ Value = 3 }
$chkWNoVerify = [pscustomobject]@{ Checked = $false }; $chkWPostCheck = [pscustomobject]@{ Checked = $true }
$script:CalWarmupMinutes = 5; $script:SettingSync = $false; $script:UiReady = $true
$script:CalHardNs = 400; $script:CalHardNsUser = 400
$script:ScpStatsOk = $true; $script:GwProc = $null; $script:Cal = $null; $script:WriteWarm = $null; $script:GwFormats = @{}
$script:ContentMeasures = @()
$script:RestoreRules = @{ WriteRetries = 20; RepairPasses = 3 }
$wfOk = $false
# 12.11 : en integration continue (-Ci), System.Windows.Forms non chargeable est un echec, pas des cas sautes
try { Import-TestWinForms; $wfOk = $true } catch { if ($Ci) { throw }; "  System.Windows.Forms non chargeable : $($_.Exception.Message) ; cas U sautes" }
if ($wfOk) {
    $form = [pscustomobject]@{ Font = [System.Drawing.SystemFonts]::DefaultFont }
    $cmbWLevelMode = New-Object System.Windows.Forms.ComboBox; $cmbWLevelMode.Name = 'cmbWLevelMode'; $cmbWLevelMode.Width = 260; $cmbWLevelMode.Location = New-Object System.Drawing.Point(100, 492)
    $lblWLevelMode = New-Object System.Windows.Forms.Label; $lblWLevelMode.Name = 'lblWLevelMode'; $lblWLevelMode.Location = New-Object System.Drawing.Point(20, 495)
    $lblWTarget = New-Object System.Windows.Forms.Label; $lblWTarget.Name = 'lblWTarget'; $lblWTarget.Text = 'Lecteur cible :'; $lblWTarget.AutoSize = $true
    $cmbWTarget = New-Object System.Windows.Forms.ComboBox; $cmbWTarget.Name = 'cmbWTarget'; $cmbWTarget.DropDownStyle = 'DropDownList'; $cmbWTarget.Width = 150
} else {
    $cmbWLevelMode = [pscustomobject]@{ Name = 'cmbWLevelMode'; Enabled = $true }; $lblWLevelMode = [pscustomobject]@{ Name = 'lblWLevelMode'; Enabled = $true }
    $cmbWTarget = $null; $lblWTarget = $null
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
function Get-LogIdx([string]$like) { for ($i = 0; $i -lt $script:Log.Count; $i++) { if ($script:Log[$i] -like $like) { return $i } }; return -1 }
function Get-LogN([string]$like) { return @($script:Log | Where-Object { $_ -like $like }).Count }
function Set-Ui([int]$profile = 0, [bool]$slow = $true, [bool]$precomp = $true, [string]$drive = 'A') {
    $cmbWProfile.SelectedIndex = $profile; $cmbWProfile.Text = @('Auto (selon image)', 'Standard 2 us', 'Long track 1,89 us', 'Manuel')[$profile]
    $chkWSlow.Checked = $slow; $chkWPrecomp.Checked = $precomp; $cmbDrive.Text = $drive; $cmbWFmt.Text = '(auto)'
}

# Images de travail (quelques octets : seule leur extension et leur nom comptent)
$imgDir = Join-Path $here 'img-target'
New-Item -ItemType Directory -Force $imgDir | Out-Null
$img = @{}
foreach ($n in 'jeu.adf', 'jeu-long.ipf', 'jeu.ipf', 'jeu-hd.img', 'jeu.scp', 'jeu-long.scp', 'jeu.d64') {
    $p = Join-Path $imgDir $n; [System.IO.File]::WriteAllBytes($p, [byte[]](1, 2, 3, 4)); $img[$n] = $p
}
"logic-1210-target-r : CalibCalc $($script:CalibCalc), lecteurs $((Get-DriveIds) -join ','), WinForms $wfOk ; PowerShell $($PSVersionTable.PSVersion)"

# Courbes : propres de A et de 0, croisees A>0 (std par tete et commune, long commune), A>1 rien
$cvA = New-Cv 'A' '' 'std' $null '20/10/2026 10:00' '0=20:40=40'
$cvA0 = New-Cv 'A' '' 'std' 0 '20/10/2026 10:00' '0=21:40=41'; $cvA1 = New-Cv 'A' '' 'std' 1 '20/10/2026 10:00' '0=22:40=42'
$cv0 = New-Cv '0' '' 'std' $null '21/10/2026 10:00' '0=90:40=180'
$xS = New-Cv 'A' '0' 'std' $null '01/11/2026 17:49' '0=40:40=80' 'standard'
$xH0 = New-Cv 'A' '0' 'std' 0 '02/11/2026 09:00' '0=41:40=81'; $xH1 = New-Cv 'A' '0' 'std' 1 '02/11/2026 09:05' '0=43:40=85'
$xL = New-Cv 'A' '0' 'long' $null '03/11/2026 11:00' '0=60:40=120'
function Reset-Store {
    $script:DriveCurves = @{}
    Set-DriveCurve 'A' 'std' $cvA; Set-DriveCurve 'A' 'std_h0' $cvA0; Set-DriveCurve 'A' 'std_h1' $cvA1; Set-DriveCurve '0' 'std' $cv0
    Set-DriveCurve 'A>0' 'std' $xS; Set-DriveCurve 'A>0' 'std_h0' $xH0; Set-DriveCurve 'A>0' 'std_h1' $xH1; Set-DriveCurve 'A>0' 'long' $xL
    Sync-PrecompCurves 'A'
}
Reset-Store

"--- M : meme lecteur, choix memorise par source"
$script:TargetDrives = @{}
Chk 'M1' ((Get-TargetDrive) -eq '' -and (Get-TargetDrive 'A') -eq '') "aucun choix : meme lecteur ('')"
$o1 = Set-TargetDrive 'A' '0'; $o2 = Set-TargetDrive 'B' '1'
Chk 'M2' ($o1 -eq '' -and (Get-TargetDrive) -eq '0' -and (Get-TargetDrive 'B') -eq '1' -and (Get-TargetDrive '0') -eq '') "choix par source : A -> 0, B -> 1, 0 sans choix ; ancien choix rendu ('')"
$o3 = Set-TargetDrive 'A' 'A'
Chk 'M3' ($o3 -eq '0' -and -not $script:TargetDrives.ContainsKey('A') -and (Get-TargetDrive 'A') -eq '') "cible = source : entree retiree (meme lecteur), ancien choix 0 rendu"
[void](Set-TargetDrive 'A' 'Z'); $script:TargetDrives['B'] = 'Q'
Chk 'M4' (-not $script:TargetDrives.ContainsKey('A') -and (Get-TargetDrive 'B') -eq '') "lecteur inconnu (Z) refuse ; entree memorisee inconnue (Q) lue comme meme lecteur"
$it = Get-TargetDriveItems 'A'   # tableau protege par la virgule, comme l appelle Update-TargetDriveUi
$sUi = Get-TgFn '140' 'Update-TargetDriveUi'
Chk 'M5' ($it.Count -eq 6 -and ($it -join ',') -eq '(même lecteur),B,0,1,2,3' -and -not $sUi.Contains('@(Get-TargetDriveItems')) "liste « Lecteur cible » de A : $($it -join ',') ; Update-TargetDriveUi ne l emballe pas dans @()"
$script:TargetDrives = @{}
Set-Ui 0 $true $true 'A'; $txtWPrecomp.Text = ''; $txtWPrecomp1.Text = ''
$x = Set-PrecompFields $script:PrecompStd 'std'
Chk 'M6' ($txtWPrecomp.Text -eq $cvA0.Spec -and $txtWPrecomp1.Text -eq $cvA1.Spec -and $x -like '*profils calibrés tête 0 et tête 1*') "meme lecteur, ecriture lente : courbes propres par tete de A ($($txtWPrecomp.Text) / $($txtWPrecomp1.Text))"
$twM = Get-TargetWriteInfo $img['jeu.adf'] '(auto)' $true
Chk 'M7' (-not $twM.Tgt -and -not $twM.Applies -and -not $twM.Block -and (Get-TargetWriteBlock $img['jeu.adf'] '(auto)' $true) -eq '' -and (Test-TargetWriteAllowed $img['jeu.adf'] '(auto)' $true)) "meme lecteur : rien a refuser"
Reset-Run
$wfM = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true
Chk 'M8' ($wfM.Apply -and -not $wfM.Target -and @($wfM.Lines).Count -ge 1 -and @($wfM.Lines)[-1] -like 'Facteur de précompensation de cette écriture (lecteur A, marque*') "meme lecteur : facteur ordinaire applique (Apply vrai), ligne « Facteur de precompensation »"

"--- P : courbes croisees dans les champs --precomp, informations et refus"
$script:TargetDrives = @{ A = '0' }
Set-Ui 0 $true; $x = Set-PrecompFields $script:PrecompStd 'std'; $tp1 = Get-TargetProfileText 'std'
Chk 'P1' ($txtWPrecomp.Text -eq $xH0.Spec -and $txtWPrecomp1.Text -eq $xH1.Spec -and $x -eq '' -and $tp1 -eq "courbes croisées A → 0 par tête, test fin, tête 0 du 02/11/2026 09:00, tête 1 du 02/11/2026 09:05, calcul v$($script:CalibCalc)") "ecriture lente, par tete a jour : champs « A>0|std_h0/h1 » ($($txtWPrecomp.Text) / $($txtWPrecomp1.Text)) ; aucun complement ; libelle : $tp1"
Set-Ui 0 $false; $x = Set-PrecompFields $script:PrecompStd 'std'; $tp2 = Get-TargetProfileText 'std'
Chk 'P2' ($txtWPrecomp.Text -eq $xS.Spec -and $txtWPrecomp1.Text -eq $xS.Spec -and $x -eq '' -and $tp2 -eq "courbe croisée A → 0, test standard, 01/11/2026 17:49, calcul v$($script:CalibCalc)") "ecriture rapide : courbe croisee commune pour les deux tetes ; aucun complement ; libelle : $tp2"
# Courbe commune posterieure aux courbes par tete : par tete perimees, commune
$xS2 = New-Cv 'A' '0' 'std' $null '05/11/2026 08:00' '0=45:40=90' 'standard'; Set-DriveCurve 'A>0' 'std' $xS2
Set-Ui 0 $true; $x = Set-PrecompFields $script:PrecompStd 'std'
Chk 'P3' ($txtWPrecomp.Text -eq $xS2.Spec -and $txtWPrecomp1.Text -eq $xS2.Spec) "ecriture lente, courbes par tete anterieures a la commune : commune pour les deux tetes"
Reset-Store
# Courbes par tete seules : lente oui, rapide non (refus)
Set-DriveCurve 'A>0' 'std' $null
$twH = Get-TargetWriteInfo $img['jeu.adf'] '(auto)' $true; $twF = Get-TargetWriteInfo $img['jeu.adf'] '(auto)' $false
Chk 'P4' ($twH.Applies -and @($twH.Curves).Count -eq 2 -and -not $twH.Block -and $twF.Applies -and @($twF.Curves).Count -eq 0 -and $twF.Block -like "Les courbes croisées A → 0 de la famille Standard 2 us sont par tête (calibration croisée faite avec « Écriture lente » cochée) : elles ne servent qu'à une écriture lente. Cochez « Écriture lente »*") "par tete seules : ecriture lente 2 courbes ; ecriture rapide refusee par un message qui le dit ($($twF.Block.Substring(0, 60))...)"
Set-Ui 0 $false; $x12 = Set-PrecompFields $script:PrecompStd 'std'
$script:TargetDrives = @{ A = '1' }; $twF1 = Get-TargetWriteInfo $img['jeu.adf'] '(auto)' $false; $script:TargetDrives = @{ A = '0' }
# RC4 : Set-PrecompFields ne rend plus de complement de refus ; refus court en tete du libelle complet, pose par le vrai
# Update-PrecompForImage (Sync-WTargetHead, d apres Get-TargetWriteInfo)
Set-Ui 0 $false; $txtWFile.Text = $img['jeu.adf']; Update-PrecompForImageR $img['jeu.adf']; $l12 = [string]$lblWProfileInfo.Text; $txtWFile.Text = ''
$e12 = "Courbes croisées A → 0 par tête : écriture rapide refusée (cochez « Écriture lente ») ; Auto : image secteur (.adf) -> standard 2 us ($($script:PrecompStd))"
Chk 'P12' ($txtWPrecomp.Text -eq $script:PrecompStd -and $x12 -eq '' -and $l12 -eq $e12 -and $twF1.Block -like 'Aucune courbe croisée A → 1 pour la famille Standard 2 us*') "par tete seules, ecriture rapide : Set-PrecompFields sans complement (« $x12 ») ; libelle complet « $l12 » (refus en tete) ; aucune courbe (cible 1) : message ordinaire"
Set-Ui 0 $true
Reset-Store
# Famille long track (IPF a cellule courte), profil force, flux SCP long
$twL = Get-TargetWriteInfo $img['jeu-long.ipf'] '(auto)' $true
Chk 'P5' ($twL.Fam -eq 'long' -and @($twL.Curves).Count -eq 1 -and [object]::ReferenceEquals(@($twL.Curves)[0], $xL) -and -not $twL.Block) "image long track : famille long, courbe croisee commune « A>0|long » (pas de courbe par tete : commune en lente)"
Set-Ui 2 $true; $twFL = Get-TargetWriteInfo $img['jeu.adf'] '(auto)' $true
Set-Ui 1 $true; $twFS = Get-TargetWriteInfo $img['jeu-long.ipf'] '(auto)' $true
Chk 'P6' ($twFL.Fam -eq 'long' -and $twFL.Applies -and $twFS.Fam -eq 'std' -and @($twFS.Curves).Count -eq 2) "profil force : Long track sur un ADF -> famille long ; Standard sur un IPF long -> famille std (courbes par tete)"
Set-Ui 0 $true; $cmbWFmt.Text = 'ibm.1440'
$twSL = Get-TargetWriteInfo $img['jeu-long.scp'] 'ibm.1440' $true; $twSS = Get-TargetWriteInfo $img['jeu.scp'] 'ibm.1440' $true
Chk 'P7' ($twSL.Fam -eq 'long' -and $twSS.Fam -eq 'std' -and $twSL.Applies) "flux SCP decode par --format : famille d apres la cellule mesuree (long / std), comme Update-PrecompForImage"
$cmbWFmt.Text = '(auto)'
# Haute densite en Auto : refus ; profil force : famille du profil
$twHd = Get-TargetWriteInfo $img['jeu-hd.img'] '(auto)' $true
Set-Ui 1 $true; $twHdF = Get-TargetWriteInfo $img['jeu-hd.img'] '(auto)' $true; Set-Ui 0 $true
Chk 'P8' ($twHd.Applies -and $twHd.Block -like "Écriture pour le lecteur cible 0 impossible en haute densité : la calibration croisée n'existe qu'en double densité*" -and -not $twHdF.Block -and $twHdF.Fam -eq 'std') "haute densite en Auto : refus ; profil force Standard : courbes croisees std"
$hdA0 = New-Cv 'A' '' 'hd' 0 '22/10/2026 10:00' '0=11:40=12'; $hdA1 = New-Cv 'A' '' 'hd' 1 '22/10/2026 10:00' '0=13:40=14'
Set-DriveCurve 'A' 'hd_h0' $hdA0; Set-DriveCurve 'A' 'hd_h1' $hdA1; Sync-PrecompCurves 'A'
Set-Ui 0 $true; $x13 = Set-PrecompFields 'hdspec' 'hd'; $f13 = "$($txtWPrecomp.Text)|$($txtWPrecomp1.Text)"
Set-Ui 0 $false; $x13f = Set-PrecompFields 'hdspec' 'hd'; $f13f = "$($txtWPrecomp.Text)|$($txtWPrecomp1.Text)"
# RC4 : complement de Set-PrecompFields comme sans lecteur cible ; refus « haute densite » en tete du libelle complet (vrai
# Update-PrecompForImage, profil commun d origine haute densite : Get-HdProfile), ecriture lente et rapide
$hdH = "Lecteur cible 0 : écriture refusée en haute densité (la calibration croisée n'existe qu'en double densité) ; "
$txtWFile.Text = $img['jeu-hd.img']
Set-Ui 0 $true; Update-PrecompForImageR $img['jeu-hd.img']; $l13 = [string]$lblWProfileInfo.Text; $g13 = "$($txtWPrecomp.Text)|$($txtWPrecomp1.Text)"
Set-Ui 0 $false; Update-PrecompForImageR $img['jeu-hd.img']; $l13f = [string]$lblWProfileInfo.Text; $g13f = "$($txtWPrecomp.Text)|$($txtWPrecomp1.Text)"
$txtWFile.Text = ''
$e13 = $hdH + "Auto : image haute densité (haute densité 1 440 Ko) -> Haute densité 1 us ; écriture lente : profils calibrés tête 0 et tête 1 appliqués"
$e13f = $hdH + "Auto : image haute densité (haute densité 1 440 Ko) -> profil d'origine Haute densité 1 us ($($script:PrecompHdDefault)), non calibré : calibrez le lecteur en haute densité (carte « Calibrer le lecteur » de l'Accueil)"
"  P13 : libelles « $l13 » ; « $l13f »"
Chk 'P13' ($f13 -eq '0=11:40=12|0=13:40=14' -and $x13 -eq ' ; écriture lente : profils calibrés tête 0 et tête 1 appliqués' -and $f13f -eq 'hdspec|hdspec' -and $x13f -eq '' -and $g13 -eq '0=11:40=12|0=13:40=14' -and $g13f -eq "$($script:PrecompHdDefault)|$($script:PrecompHdDefault)" -and $l13 -eq $e13 -and $l13f -eq $e13f) "image haute densite calibrable, cible 0 : champs des courbes hd du lecteur, Set-PrecompFields sans complement de refus ; refus « haute densite » en tete du libelle complet, sans proposer la calibration croisee (ecriture lente et rapide)"
Set-DriveCurve 'A' 'hd_h0' $null; Set-DriveCurve 'A' 'hd_h1' $null; Sync-PrecompCurves 'A'; Set-Ui 0 $true
# Sans effet : Manuel, --precomp decoche, flux ecrit tel quel, GCR
Set-Ui 3 $true; $tw1 = Get-TargetWriteInfo $img['jeu.adf'] '(auto)' $true
Set-Ui 0 $true $false; $tw2 = Get-TargetWriteInfo $img['jeu.adf'] '(auto)' $true
Set-Ui 0 $true; $tw3 = Get-TargetWriteInfo $img['jeu.scp'] '(auto)' $true; $tw4 = Get-TargetWriteInfo $img['jeu.d64'] '(auto)' $true
$tw5 = Get-TargetWriteInfo (Join-Path $imgDir 'absente.adf') '(auto)' $true
Chk 'P9' ((@($tw1, $tw2, $tw3, $tw4, $tw5) | Where-Object { $_.Applies -or $_.Block -or $_.Tgt -ne '0' }).Count -eq 0 -and $tw1.Why -eq 'profil Manuel, champ --precomp transmis tel quel' -and $tw2.Why -eq 'précompensation désactivée' -and $tw3.Why -eq 'image flux écrite telle quelle, sans précompensation' -and $tw4.Why -eq 'image en codage GCR, écrite sans précompensation' -and -not $tw5.Why) "lecteur cible sans effet (Manuel, --precomp decoche, flux tel quel, GCR, fichier absent) : ni courbe croisee ni refus, raison donnee"
# Cible sans courbe croisee : A -> 1
$script:TargetDrives = @{ A = '1' }
Set-Ui 0 $true; $x = Set-PrecompFields $script:PrecompStd 'std'
# RC4 : refus court en tete du libelle complet (vrai Update-PrecompForImage), plus dans le complement de Set-PrecompFields
$txtWFile.Text = $img['jeu.adf']; Update-PrecompForImageR $img['jeu.adf']; $l10 = [string]$lblWProfileInfo.Text; $txtWFile.Text = ''
$e10 = "Aucune courbe croisée A → 1 : écriture refusée (« Calibrer pour un lecteur cible… ») ; Auto : image secteur (.adf) -> standard 2 us ($($script:PrecompStd))"
Chk 'P10' ($txtWPrecomp.Text -eq $script:PrecompStd -and $x -eq '' -and $l10 -eq $e10) "cible 1 sans courbe croisee : champs au profil de famille, Set-PrecompFields sans complement (« $x ») ; libelle complet « $l10 » (refus en tete)"
Reset-Run
$ok = Test-TargetWriteAllowed $img['jeu.adf'] '(auto)' $true
Chk 'P11' (-not $ok -and $script:Msgs.Count -eq 1 -and $script:Msgs[0] -eq "Écriture refusée|Écriture refusée : Aucune courbe croisée A → 1 pour la famille Standard 2 us : lancez « Calibrer pour un lecteur cible… » (onglet Écriture, lecteur A dans le bandeau, lecteur cible 1), ou choisissez « (même lecteur) » dans la liste « Lecteur cible »." -and (Get-LogN 'Écriture refusée : Aucune courbe croisée A → 1*') -eq 1) "refus : fenetre « Ecriture refusee » (repondue) et journal"
$script:TargetDrives = @{ A = '0' }

"--- F : facteur 1 (Get-WriteFactorPlan)"
# Facteur de marque du lecteur A pour std (k 1,20 sur les deux tetes, mesures du calcul actuel)
$script:LevelBrand = ''
$script:ContentMeasures = @(foreach ($h in 0, 1) { @{ Drive = 'A'; Family = 'std'; Head = $h; K = 1.2; Etat = 'mesure'; Brand = ''; Date = '01/11/2026 10:00'; ContentCalc = $script:ContentCalc; Calc = $script:CalibCalc } })
$script:TargetDrives = @{}
Set-Ui 0 $true; $wf0 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true
Chk 'F1' ($wf0.Apply -and [math]::Abs($wf0.F0 - 1.2) -lt 1e-9 -and [math]::Abs($wf0.F1 - 1.2) -lt 1e-9) "meme lecteur : facteur de marque 1,20 applique (F0 $($wf0.F0), F1 $($wf0.F1))"
$script:TargetDrives = @{ A = '0' }
$wf1 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true
$l1 = @($wf1.Lines)
Chk 'F2' (-not $wf1.Apply -and $wf1.F0 -eq 1.0 -and $wf1.F1 -eq 1.0 -and $wf1.FMean -eq 1.0 -and $wf1.Target -eq '0' -and $wf1.Fam -eq 'std' -and @($wf1.Curves).Count -eq 2) "lecteur cible : facteur 1 (Apply faux, F0 = F1 = 1), Target 0, 2 courbes croisees"
Chk 'F3' ($l1.Count -eq 2 -and $l1[0] -eq 'Écriture pour le lecteur cible 0 : courbes croisées A → 0 par tête (Standard 2 us, test fin, tête 0 du 02/11/2026 09:00, tête 1 du 02/11/2026 09:05, calcul v12.10), facteur 1,00.' -and $l1[1] -eq 'Facteur de marque non appliqué : écriture pour le lecteur cible 0 (le facteur est mesuré par la relecture du lecteur A, il ne vaut pas pour le lecteur cible).') "journal : « $($l1[0]) » puis « Facteur de marque non applique »"
$wf2 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $false
Chk 'F4' (@($wf2.Lines)[0] -eq 'Écriture pour le lecteur cible 0 : courbe croisée A → 0 (Standard 2 us, test standard, 01/11/2026 17:49, calcul v12.10), facteur 1,00.' -and $wf2.FMean -eq 1.0) "ecriture rapide : courbe croisee commune nommee (test standard, date, calcul), facteur 1,00"
$script:ContentMeasures = @()
$wf3 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true
Chk 'F5' (@($wf3.Lines).Count -eq 2 -and @($wf3.Lines)[1] -like 'Facteur de marque non appliqué*') "sans facteur de marque mesure : la ligne « Facteur de marque non applique » est ecrite aussi"
$wfP = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true $null -Peek
Chk 'F6' (-not $wfP.Apply -and $wfP.Target -eq '0' -and @($wfP.Lines).Count -eq 0 -and (Get-WriteFactorNote $img['jeu.adf']) -eq '') "Peek (libelle du profil) : aucune ligne, complement « facteur » vide"
$script:TargetDrives = @{ A = '1' }
$wf4 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true
Chk 'F7' (-not $wf4.Apply -and -not $wf4.Target -and $wf4.Why -eq 'aucune courbe croisée A → 1' -and @($wf4.Lines).Count -eq 0) "cible sans courbe croisee : Why « aucune courbe croisee A → 1 » (l ecriture est refusee avant)"
$script:TargetDrives = @{ A = '0' }; Set-Ui 3 $true
$script:ContentMeasures = @(foreach ($h in 0, 1) { @{ Drive = 'A'; Family = 'std'; Head = $h; K = 1.2; Etat = 'mesure'; Brand = ''; Date = '01/11/2026 10:00'; ContentCalc = $script:ContentCalc; Calc = $script:CalibCalc } })
$wf5 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true
Chk 'F8' (-not $wf5.Apply -and -not $wf5.Target -and $wf5.Why -eq 'profil précomp. « Manuel »' -and @($wf5.Lines)[0] -like 'Facteur mesuré du lecteur A (tête 0 × 1,20, tête 1 × 1,20) non appliqué à cette écriture : profil précomp. « Manuel »*') "lecteur cible sans effet (Manuel) : regle ordinaire du facteur (non applique, ligne du profil)"
$script:ContentMeasures = @(); Set-Ui 0 $true
$xOld = New-Cv 'A' '0' 'std' $null '20/09/2026 08:00' '0=33:40=66' 'standard'; $xOld.Calc = '12.9'; $xOld.KeptFor = $script:CalibCalc
$script:DriveCurves = @{}; Set-DriveCurve 'A' 'std' $cvA; Set-DriveCurve 'A>0' 'std' $xOld; Sync-PrecompCurves 'A'
$script:TargetDrives = @{ A = '0' }; Set-Ui 0 $true
$wf9 = Get-WriteFactorPlan $img['jeu.adf'] '(auto)' $true; $x9 = Set-PrecompFields $script:PrecompStd 'std'
Chk 'F9' ($wf9.Target -eq '0' -and @($wf9.Curves).Count -eq 1 -and @($wf9.Lines)[0] -eq 'Écriture pour le lecteur cible 0 : courbe croisée A → 0 (Standard 2 us, test standard, 20/09/2026 08:00, calcul v12.9), facteur 1,00.' -and $txtWPrecomp.Text -eq '0=33:40=66' -and $txtWPrecomp1.Text -eq '0=33:40=66') "courbe croisee d un autre calcul gardee au demarrage : appliquee aux deux tetes, calcul v12.9 nomme au journal"
Reset-Store

"--- W : Start-ImageWrite (instructions reelles), Start-WriteTabWrite, Complete-WriteCheck"
$script:TargetDrives = @{ A = '0' }; $script:StubFam = 'std'
Set-Ui 0 $true; $txtWFile.Text = $img['jeu.adf']; $script:Rep = @{}
$txtWPrecomp.Text = $xH0.Spec; $txtWPrecomp1.Text = $xH1.Spec
Reset-Run; $w1 = Test-ImageWriteTarget $true
Chk 'W1' ($w1.TgtDrive -eq '0' -and (Get-N 'Upd') -eq 0 -and $script:Rep.Target -eq '0' -and $script:Rep.TargetSrc -eq 'A' -and (Get-LogN 'Contrôle après écriture pour le lecteur cible 0 : relecture par le lecteur A, pas par le lecteur cible*') -eq 1) "champs deja aux courbes croisees : rien recalcule ; Rep.Target 0, Rep.TargetSrc A, ligne du controle"
$txtWPrecomp.Text = '0=999'; $txtWPrecomp1.Text = '0=998'; $script:Rep = @{}
Reset-Run; $w2 = Test-ImageWriteTarget $true
Chk 'W2' ((Get-N 'Upd') -eq 1 -and $txtWPrecomp.Text -eq $xH0.Spec -and $txtWPrecomp1.Text -eq $xH1.Spec) "champs differents (courbe adaptee, saisie) : profil recalcule, champs remis aux courbes croisees par tete"
$chkWSlow.Checked = $false; $txtWPrecomp.Text = $xH0.Spec; $txtWPrecomp1.Text = '0=1'
Reset-Run; $w3 = Test-ImageWriteTarget $false
Chk 'W3' ((Get-N 'Upd') -eq 1 -and $txtWPrecomp.Text -eq $xS.Spec) "ecriture rapide avec le champ d une courbe par tete : remis a la courbe croisee commune"
Set-Ui 3 $true; $txtWPrecomp.Text = '0=7'; $script:Rep = @{}
Reset-Run; $w4 = Test-ImageWriteTarget $true
Chk 'W4' ($w4.TgtDrive -eq '' -and (Get-N 'Upd') -eq 0 -and -not $script:Rep.Target -and (Get-LogN 'Lecteur cible 0 sans effet sur cette écriture : profil Manuel, champ --precomp transmis tel quel.') -eq 1 -and $txtWPrecomp.Text -eq '0=7') "profil Manuel : ligne « sans effet », champ de l utilisateur garde, pas de Rep.Target"
$script:TargetDrives = @{}; Set-Ui 0 $true; $script:Rep = @{}
Reset-Run; $w5 = Test-ImageWriteTarget $true
Chk 'W5' ($w5.TgtDrive -eq '' -and $script:Log.Count -eq 0 -and (Get-N 'Upd') -eq 0 -and -not $script:Rep.Target) "meme lecteur : aucune ligne, rien recalcule"
$v1 = Test-CheckVerdict @{ Target = '0'; TargetSrc = 'A' } 'CONTRÔLE APRÈS ÉCRITURE : 160/160 pistes saines'
$v2 = Test-CheckVerdict @{ Target = $null } 'CONTRÔLE APRÈS ÉCRITURE : 160/160 pistes saines'
Chk 'W6' ($v1 -eq 'CONTRÔLE APRÈS ÉCRITURE : 160/160 pistes saines (relu par le lecteur A, pas par le lecteur cible 0)' -and $v2 -eq 'CONTRÔLE APRÈS ÉCRITURE : 160/160 pistes saines') "verdict du controle : « (relu par le lecteur A, pas par le lecteur cible 0) » ; inchange sans lecteur cible"
# Start-WriteTabWrite reel
$script:Settings.calMode = 'standard'; $script:WantLevel = $true
$script:TargetDrives = @{ A = '1' }; Set-Ui 0 $true; $txtWFile.Text = $img['jeu.adf']
Reset-Run; Start-WriteTabWrite
Chk 'W7' ((Get-N 'Partial') -eq 0 -and (Get-N 'ImageWrite') -eq 0 -and (Get-N 'LevelBefore') -eq 0 -and $script:Msgs.Count -eq 1 -and $script:Msgs[0] -like 'Écriture refusée|Écriture refusée : Aucune courbe croisée A → 1 pour la famille Standard 2 us*') "bouton ECRIRE, cible 1 sans courbe croisee : refus avant la confirmation d une ecriture partielle, rien d ecrit ni de mesure"
$script:TargetDrives = @{ A = '0' }
Reset-Run; Start-WriteTabWrite
Chk 'W8' ((Get-N 'Partial') -eq 1 -and (Get-N 'ImageWrite') -eq 1 -and (Get-N 'LevelBefore') -eq 0 -and (Get-LogN "Mesure de la disquette avant l'écriture non faite : écriture pour le lecteur cible 0 (la mesure relirait avec le lecteur A)*") -eq 1) "bouton ECRIRE, cible 0 : mesure non faite (journal), ecriture directe"
$script:Settings.calMode = 'level'; $script:WantLevel = $false
Reset-Run; Start-WriteTabWrite
Chk 'W9' ((Get-N 'ImageWrite') -eq 1 -and (Get-N 'LevelBefore') -eq 0) "« Test rapide » : pas de calibration rapide pour un lecteur cible, ecriture directe"
$script:Settings.calMode = 'standard'; $script:WantLevel = $true; Set-Ui 3 $true
Reset-Run; Start-WriteTabWrite
Chk 'W10' ((Get-N 'ImageWrite') -eq 1 -and (Get-N 'LevelBefore') -eq 0 -and (Get-LogN "Mesure de la disquette avant l'écriture non faite : profil précomp. « Manuel » choisi*") -eq 1) "profil Manuel (lecteur cible sans effet) : deroule ordinaire (raison du profil au journal)"
$script:TargetDrives = @{}; Set-Ui 0 $true
Reset-Run; Start-WriteTabWrite
Chk 'W11' ((Get-N 'LevelBefore') -eq 1 -and (Get-N 'ImageWrite') -eq 0) "meme lecteur, mesure demandee : mesure de la disquette lancee (deroule ordinaire inchange)"
$script:WantLevel = $false

"--- B : Bibliotheque (Start-PresetWrite reel)"
$script:TargetDrives = @{ A = '0' }; Set-Ui 0 $true; $txtWFile.Text = $img['jeu.adf']; $cmbWCalMode.SelectedIndex = 1
Reset-Run; Start-PresetWrite 'slow'
Chk 'B1' ((Get-N 'ImageWrite') -eq 1 -and (Get-N 'CalibState') -eq 0 -and (Get-N 'LevelBefore') -eq 0 -and (Get-LogN 'Écriture pour le lecteur cible 0 : ni calibration automatique ni mesure de la disquette (elles reliraient avec le lecteur A)*') -eq 1) "ecriture lente de la Bibliotheque pour la cible 0 : ni calibration automatique ni mesure, ecriture (refus eventuel dans Start-ImageWrite)"
$cmbWCalMode.SelectedIndex = 2
Reset-Run; Start-PresetWrite 'fast'
Chk 'B2' ((Get-N 'ImageWrite') -eq 1 -and (Get-N 'LevelBefore') -eq 0) "« Test rapide » : pas de calibration rapide pour un lecteur cible"
$cmbWCalMode.SelectedIndex = 1; Set-Ui 3 $true
Reset-Run; Start-PresetWrite 'slow'
Chk 'B3' ((Get-N 'CalibState') -eq 1 -and (Get-N 'ImageWrite') -eq 1 -and (Get-LogN 'Écriture pour le lecteur cible*') -eq 0) "profil Manuel (sans effet) : deroule ordinaire (etat de la calibration du lecteur)"
$script:TargetDrives = @{}; Set-Ui 0 $true
Reset-Run; Start-PresetWrite 'slow'
Chk 'B4' ((Get-N 'CalibState') -eq 1 -and (Get-N 'ImageWrite') -eq 1) "meme lecteur : deroule ordinaire"
$s130 = Get-TgFn '130' 'Start-LibWrite'
Chk 'B5' ($s130.Contains('Start-PresetWrite $mode') -and -not $s130.Contains('TargetCorr')) "Start-LibWrite passe par Start-PresetWrite, sans correction Dk"
$script:TargetDrives = @{ A = '0' }; Set-Ui 0 $true; $txtWFile.Text = $img['jeu-hd.img']; $cmbWCalMode.SelectedIndex = 1
Reset-Run; Start-PresetWrite 'slow'
Chk 'B6' ((Get-N 'ImageWrite') -eq 1 -and (Get-N 'CalibState') -eq 0 -and (Get-LogN 'Image haute densité*') -eq 0 -and (Get-LogN 'LevelHdNote') -eq 0) "image haute densite pour la cible 0 : aucune ligne de la branche haute densite, refus porte par Start-ImageWrite"
$txtWFile.Text = $img['jeu.adf']; Set-DriveCurve 'A>0' 'std' $null
Set-Ui 0 $false; Reset-Run; Start-PresetWrite 'fast'
$twB7 = Get-TargetWriteInfo $img['jeu.adf'] '(auto)' $false
Chk 'B7' ((Get-N 'ImageWrite') -eq 1 -and (Get-N 'CalibState') -eq 0 -and (Get-LogN 'Écriture pour le lecteur cible*') -eq 0 -and $twB7.Block -like 'Les courbes croisées A → 0 de la famille Standard 2 us sont par tête*') "ecriture rapide de la Bibliotheque, courbes croisees par tete seules : refus avant la ligne « ni calibration automatique »"
Reset-Store; Set-Ui 0 $true; $script:TargetDrives = @{}

"--- R : restauration"
$script:TargetDrives = @{ A = '1' }
Reset-Run; $r1 = Test-RestoreStart 'A' 'amiga.amigados'
Chk 'R1' ($null -eq $r1 -and $script:Msgs.Count -eq 1 -and $script:Msgs[0] -like "Restauration|Restauration refusée : lecteur cible 1 choisi pour le lecteur A dans l'onglet Écriture, sans courbe croisée A → 1 pour la famille Standard 2 us (copie secteur double densité).*") "Start-Restore, cible 1 sans aucune courbe croisee : refus avant la lecture de l original"
Reset-Run; $r2 = Test-RestoreStart 'A' ''
Chk 'R2' ($r2 -eq 'suite' -and $script:Msgs.Count -eq 0 -and $script:Log.Count -eq 0) "copie de flux (format vide) : pas de refus, pas de ligne (lecteur cible sans effet)"
$script:TargetDrives = @{ A = '0' }
Reset-Run; $r3 = Test-RestoreStart 'A' 'auto'
Chk 'R3' ($r3 -eq 'suite' -and (Get-LogN 'Restauration pour le lecteur cible 0 : une copie secteur sera écrite par le lecteur A avec la courbe croisée A → 0*') -eq 1) "cible 0 avec courbes croisees : ligne de journal, la restauration continue"
$script:DriveCurves = @{}; Set-DriveCurve 'A' 'std' $cvA; Set-DriveCurve 'A>0' 'long' $xL; Sync-PrecompCurves 'A'
Reset-Run; $r10 = Test-RestoreStart 'A' 'amiga.amigados'; $r10a = Test-RestoreStart 'A' 'auto'
Chk 'R10' ($null -eq $r10 -and $null -eq $r10a -and $script:Msgs.Count -eq 2 -and $script:Msgs[0] -like 'Restauration|Restauration refusée : lecteur cible 0 choisi pour le lecteur A*sans courbe croisée A → 0 pour la famille Standard 2 us*') "seule une courbe croisee long track A>0 : copie secteur (format choisi ou detecte) refusee avant la lecture (avant : lue, puis echec a l etape 4)"
Reset-Store
Reset-Run; $r11 = Test-RestoreStart 'A' 'ibm.1440'
Chk 'R11' ($null -eq $r11 -and $script:Msgs.Count -eq 1 -and $script:Msgs[0] -like "Restauration|Restauration refusée : lecteur cible 0 choisi pour le lecteur A dans l'onglet Écriture, et format haute densité ibm.1440 : la calibration croisée n'existe qu'en double densité.*") "format haute densite explicite, courbes croisees std presentes : refus avant la lecture de l original"
$script:TargetDrives = @{ A = '1' }
Reset-Run; $r12 = Test-RestoreStart 'A' 'commodore.1541'
Chk 'R12' ($r12 -eq 'suite' -and $script:Msgs.Count -eq 0 -and $script:Log.Count -eq 0) "format GCR explicite, cible 1 sans courbe croisee : lecteur cible sans effet, ni refus ni ligne"
$script:TargetDrives = @{ A = '0' }; Set-DriveCurve 'A>0' 'std' $null
Reset-Run; $r13 = Test-RestoreStart 'A' 'auto'; $ri13 = Get-RestoreTargetInfo 'A' '0' 'amiga.amigados'
Chk 'R13' ($r13 -eq 'suite' -and $ri13.Applies -and -not $ri13.Block -and (Get-LogN 'Restauration pour le lecteur cible 0*') -eq 1) "courbes croisees std par tete seules (restauration ecrite tete par tete) : pas de refus"
Reset-Store
function New-Restore([string]$mode = 'sector') {
    return @{ Stage = 'compare'; Idle = (Get-Date); InCall = $false; Orig = $img['jeu.adf']; Mode = $mode; Fmt = 'amiga.amigados'; OnOriginal = $false; Read = $null
              Extras = ''; Drive = 'A'; CalibDone = $false; HD = ''; Calib = ''; CalibUsed = $null; LevelNote = ''; Steps = @{}; Target = ''; SwapBack = $false }
}
$script:Steps.Clear(); $script:Fails.Clear(); Reset-Run
$script:Restore = New-Restore; $rr = $script:Restore; Start-RestoreWrite
Chk 'R4' ($rr.Target -eq '0' -and (Get-N 'RestoreCalibInfo') -eq 0 -and (Get-N 'LevelBefore') -eq 0 -and (Get-N 'ImageWrite') -eq 1 -and $script:Fails.Count -eq 0 -and (Get-LogN "Restauration : écriture pour le lecteur cible 0 avec la courbe croisée, le lecteur A n'est pas calibré.") -eq 1 -and (Get-LogN "Restauration : disquette de destination non mesurée avant l'écriture : écriture pour le lecteur cible 0, la mesure relirait avec le lecteur A.") -eq 1) "Start-RestoreWrite (copie secteur, cible 0) : ni calibration ni mesure de la destination, ecriture par Start-PresetWrite reel"
Chk 'R5' (@($script:Steps | Where-Object { $_ -eq '4|skip|écriture pour le lecteur cible 0 : courbe croisée A → 0, ni calibration ni mesure de la destination' }).Count -eq 1 -and @($script:Steps | Where-Object { $_ -like '5|run|*' }).Count -eq 1) "etapes : 4 « skip » qui nomme la courbe croisee, 5 en cours"
$script:TargetDrives = @{ A = '1' }; $script:Steps.Clear(); $script:Fails.Clear(); Reset-Run
$script:Restore = New-Restore; $rr = $script:Restore; Start-RestoreWrite
Chk 'R6' ($script:Fails.Count -eq 1 -and $script:Fails[0] -like "4|écriture pour le lecteur cible 1 refusée, rien n'a été écrit : Aucune courbe croisée A → 1 pour la famille Standard 2 us*" -and (Get-N 'ImageWrite') -eq 0 -and -not $rr.InCall) "copie secteur, cible 1 sans courbe croisee de la famille : echec a l etape 4 avant toute ecriture, raison claire"
$script:TargetDrives = @{ A = '0' }; $script:Steps.Clear(); $script:Fails.Clear(); Reset-Run
$script:Restore = New-Restore 'flux'; $script:Restore.Orig = $img['jeu.scp']; $rr = $script:Restore; Start-RestoreWrite
Chk 'R7' ($rr.Target -eq '' -and $script:Fails.Count -eq 0 -and (Get-N 'ImageWrite') -eq 1) "copie de flux (ecrite telle quelle) : lecteur cible sans effet, ecriture"
$script:TargetDrives = @{}; $script:Steps.Clear(); Reset-Run
$script:Restore = New-Restore; $rr = $script:Restore; Start-RestoreWrite
Chk 'R8' ($rr.Target -eq '' -and (Get-N 'RestoreCalibInfo') -eq 1 -and (Get-N 'LevelBefore') -eq 1) "meme lecteur : calibration existante consultee, mesure de la destination (deroule ordinaire)"
$script:TargetDrives = @{ A = '0' }; $script:Steps.Clear(); $script:Fails.Clear(); Reset-Run
$script:Restore = New-Restore; $script:Restore.Orig = $img['jeu-hd.img']; $script:Restore.Fmt = 'ibm.1440'; $rr = $script:Restore; Start-RestoreWrite
Chk 'R14' ($script:Fails.Count -eq 1 -and $script:Fails[0] -eq "4|écriture pour le lecteur cible 0 refusée, rien n'a été écrit : l'original lu est en haute densité (haute densité 1 440 Ko), et la calibration croisée n'existe qu'en double densité (standard, long track). Choisissez « (même lecteur) » dans la liste « Lecteur cible » de l'onglet Écriture, puis relancez la restauration." -and $script:Fails[0] -notlike '*profil Manuel*' -and (Get-N 'ImageWrite') -eq 0 -and (Get-N 'RestoreCalibInfo') -eq 0) "copie secteur haute densite detectee a la lecture, cible 0 : echec a l etape 4 avant toute ecriture, sans calibration"
$script:TargetDrives = @{}
$script:Restore = $null
$script:TargetDrives = @{ A = '0' }; $t1 = Get-RsCalibText
$script:TargetDrives = @{ A = '1' }; $t2 = Get-RsCalibText
$script:TargetDrives = @{}; $t3 = Get-RsCalibText
# RC4 : phrase du lecteur cible en tete du cadre (avant : en fin, cachee par les points de suspension), phrases des
# familles a sa suite, inchangees
$p9a = 'Lecteur cible 0 : courbe croisée A → 0 (par tête, 02/11/2026), à la place de celle du lecteur A, sans calibration.'
$p9b = "Lecteur cible 1 : aucune courbe croisée standard A → 1, la restauration sera refusée au lancement."
Chk 'R9' ($t3 -and $t1 -eq ($p9a + ' ' + $t3) -and $t2 -eq ($p9b + ' ' + $t3) -and $t3 -notlike '*Lecteur cible*') "cadre « Calibration du lecteur » : phrase du lecteur cible en tete (courbe croisee nommee, ou refus annonce), phrases des familles a sa suite inchangees ; rien sans lecteur cible"

"--- U : liste « Lecteur cible », case de la mesure"
if ($wfOk) {
    $script:TargetDrives = @{ A = '0'; B = '1' }; $cmbDrive.Text = 'A'; Set-Ui 0 $true; $txtWFile.Text = $img['jeu.adf']   # fixB (RC5) : lecteur cible avec effet sur cette image
    $script:Tips[$chkWLevel.Name] = 'infobulle d origine'; $script:WLevelTip = 'infobulle d origine'
    Update-TargetDriveUi
    $iu = @($cmbWTarget.Items | ForEach-Object { [string]$_ })
    Chk 'U1' (($iu -join ',') -eq '(même lecteur),B,0,1,2,3' -and $cmbWTarget.SelectedIndex -eq 2 -and [string]$cmbWTarget.SelectedItem -eq '0' -and $script:Tips['cmbWTarget'] -like 'Lecteur qui relira la disquette écrite par le lecteur A, celui du bandeau.*' -and $lblWTarget.Left -gt $cmbWLevelMode.Right -and $cmbWTarget.Left -gt $lblWTarget.Left) "Update-TargetDriveUi (A) : elements, choix 0 memorise selectionne, infobulle, position apres la liste « Mesure : »"
    $cmbDrive.Text = 'B'; Update-TargetDriveUi
    Chk 'U2' ([string]$cmbWTarget.SelectedItem -eq '1' -and @($cmbWTarget.Items | ForEach-Object { [string]$_ })[1] -eq 'A') "changement de lecteur du bandeau (B) : liste sans B, choix memorise pour B (1)"
    $cmbDrive.Text = 'A'; Update-TargetDriveUi; Reset-Run
    $cmbWTarget.SelectedIndex = 0; Set-TargetDriveFromUi
    Chk 'U3' ((Get-TargetDrive 'A') -eq '' -and (Get-TargetDrive 'B') -eq '1' -and (Get-LogN 'Lecteur cible des écritures du lecteur A : (même lecteur) (avant : 0).') -eq 1 -and (Get-N 'Upd') -eq 1 -and $chkWLevel.Enabled) "choix « (meme lecteur) » : memorise pour A seulement, journal, profil recalcule, case de la mesure active"
    Reset-Run; $cmbWTarget.SelectedIndex = 2; Set-TargetDriveFromUi
    Chk 'U4' ((Get-TargetDrive 'A') -eq '0' -and (Get-LogN 'Lecteur cible des écritures du lecteur A : 0 (avant : (même lecteur)).') -eq 1 -and -not $chkWLevel.Enabled -and -not $cmbWLevelMode.Enabled -and $script:Tips['chkWLevel'] -like 'Mesure de la disquette non disponible pour un lecteur cible : elle relirait avec le lecteur A, pas avec le lecteur cible 0.*') "choix 0 : journal, case et liste de la mesure inactives, infobulle de la case remplacee"
    Reset-Run; Set-TargetDriveFromUi
    Chk 'U5' ($script:Log.Count -eq 0 -and (Get-N 'Upd') -eq 1) "meme choix : aucune ligne de journal"
    $script:SettingSync = $true; Reset-Run; $cmbWTarget.SelectedIndex = 0; Set-TargetDriveFromUi; $script:SettingSync = $false
    Chk 'U6' ((Get-TargetDrive 'A') -eq '0' -and (Get-N 'Upd') -eq 0) "sous la garde des liaisons : gestionnaire sans effet"
    $script:TargetDrives = @{}; Update-SlowUi
    Chk 'U7' ($chkWLevel.Enabled -and $script:Tips['chkWLevel'] -eq 'infobulle d origine') "sans lecteur cible : case active, infobulle d origine"
    $txtWFile.Text = ''
} else { "  cas U sautes (System.Windows.Forms non chargeable)" }

"--- C : configuration"
$cfg129 = @'
{ "write": { "driveFactors": [ { "drive": "A", "family": "std", "head": 0, "k": 0.85, "dk": 1.75, "f": 2.6, "date": "25/10/2026 10:00", "contentCalc": "12.9", "calc": "12.9", "etat": "mesure", "brand": "" } ],
             "targetCorrection": [ { "drive": "A", "dk0": 1.75, "dk1": 1.8, "date": "26/10/2026 09:00", "note": "", "contentCalc": "12.9" } ] } }
'@ | ConvertFrom-Json
Reset-Run; $script:TargetDrives = @{ Z = 'Y' }
$err = $null; try { $lc = Test-LoadTarget $cfg129.write } catch { $err = $_.Exception.Message }
Chk 'C1' (-not $err -and $lc.Cm -eq 1 -and $lc.CmBad -eq 0 -and $lc.Tdi.N -eq 0 -and $lc.Tdi.Bad -eq 0 -and $script:TargetDrives.Count -eq 0 -and $script:Log.Count -eq 0) "configuration 12.9 avec targetCorrection et dk : relue sans erreur ni ligne ($err), mesure gardee, aucun lecteur cible"
$rec = @($script:ContentMeasures)[0]
Chk 'C2' ($null -ne $rec -and -not $rec.ContainsKey('Dk') -and -not (ConvertTo-ContentConfig $rec).Contains('dk') -and [math]::Abs([double]$rec.F - 2.6) -lt 1e-9) "mesure 12.9 : champ dk ignore a la lecture et absent de l ecriture (f garde)"
$cfg1210 = @'
{ "write": { "targetDrive": { "A": "0", "B": "B", "0": "Z", "1": "", "2": "A" } } }
'@ | ConvertFrom-Json
Reset-Run; $lc2 = Test-LoadTarget $cfg1210.write
Chk 'C3' ($lc2.Tdi.N -eq 2 -and $lc2.Tdi.Bad -eq 3 -and (Get-TargetDrive 'A') -eq '0' -and (Get-TargetDrive '2') -eq 'A' -and (Get-LogN 'Configuration : 3 lecteur(s) cible illisible(s) ou inconnu(s), ignoré(s).') -eq 1) "bloc targetDrive : A -> 0 et 2 -> A lus ; cible = source, inconnue, vide : ignorees et comptees (3), une ligne"
$exp = Export-TargetDrives
$js = ConvertTo-Json @{ write = @{ targetDrive = $exp } } -Depth 5
$back = $js | ConvertFrom-Json
$script:TargetDrives = @{}; $ti = Import-TargetDrives $back.write.targetDrive
Chk 'C4' ((@($exp.Keys) -join ',') -eq '2,A' -and $ti.N -eq 2 -and $ti.Bad -eq 0 -and (Get-TargetDrive 'A') -eq '0' -and (Get-TargetDrive '2') -eq 'A') "aller-retour JSON : sources triees, choix relus a l identique"
$script:TargetDrives = @{}; $e0 = Export-TargetDrives; $j0 = ConvertTo-Json @{ t = $e0 } -Compress
$ti0 = Import-TargetDrives $null; $tiA = Import-TargetDrives @('A', '0'); $tiS = Import-TargetDrives 'A'
Chk 'C5' ($j0 -eq '{"t":{}}' -and $ti0.N -eq 0 -and $tiA.N -eq 0 -and $tiS.N -eq 0 -and $script:TargetDrives.Count -eq 0) "aucun choix : bloc vide {} ; bloc absent, tableau ou texte : rien, sans erreur"
$s120 = (Get-TgFn '120' 'Save-Config'); $l120 = (Get-TgFn '120' 'Load-Config')
$keysSave = @((Get-TgFnAst '120' 'Save-Config').FindAll({ param($x) $x -is [System.Management.Automation.Language.HashtableAst] }, $true) | ForEach-Object { $_.KeyValuePairs } | ForEach-Object { $_.Item1.Extent.Text })
$strLoad = @((Get-TgFnAst '120' 'Load-Config').FindAll({ param($x) $x -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { $_.Value })
Chk 'C6' ($keysSave -contains 'targetDrive' -and $keysSave -notcontains 'targetCorrection' -and $strLoad -notcontains 'targetCorrection' -and $strLoad -contains 'targetDrive' -and $l120.Contains('Update-TargetDriveUi')) "Save-Config ecrit targetDrive et plus targetCorrection ; Load-Config ne lit plus targetCorrection, lit targetDrive, met la liste a jour"

"--- S : statique"
# Aucune reference a Dk dans le code des modules (commentaires exclus)
$dkRx = 'TargetCorr|Get-DriveDk|Set-DriveDk|numWTgt|lblWTgt|TgtCorr|Format-WriteFactorDk|targetCorrection|Update-TargetCorrCalc|TargetCorrMax'
$hits = @()
foreach ($f in (Get-ChildItem -LiteralPath $mods -Filter '*.ps1')) {
    $tk = $null; $er = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tk, [ref]$er)
    foreach ($t in @($tk)) {
        if ($t.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment) { continue }
        if ($t.Text -match $dkRx) { $hits += "$($f.Name):$($t.Extent.StartLineNumber):$($t.Text.Substring(0, [math]::Min(50, $t.Text.Length)))" }
        if ($t.Kind -eq [System.Management.Automation.Language.TokenKind]::Variable -and $t.Text -match '^\$(script:)?dk$' -and $f.Name -match '^(140|274|276|120)-') { $hits += "$($f.Name):$($t.Extent.StartLineNumber):$($t.Text)" }
        if ($t.Text -match '\.Dk\b|\bDk0\b|\bDk1\b') { $hits += "$($f.Name):$($t.Extent.StartLineNumber):$($t.Text.Substring(0, [math]::Min(50, $t.Text.Length)))" }
    }
}
Chk 'S1' ($hits.Count -eq 0) "aucune reference a la correction Dk dans le code des modules (commentaires exclus)$(if ($hits.Count) { ' : ' + (($hits | Select-Object -First 6) -join ' ; ') })"
# Cles de la table I18n (affectations $script:I18n[...] des modules 01x, valeur de la cle comme T la recoit), et textes
$keys = New-Object System.Collections.Generic.HashSet[string]; $vals = New-Object System.Collections.Generic.List[string]
foreach ($f in (Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1')) {
    foreach ($as in @((Get-TgAst $f.FullName).FindAll({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and $x.Left -is [System.Management.Automation.Language.IndexExpressionAst] -and $x.Left.Target.Extent.Text -eq '$script:I18n' }, $true))) {
        if ($as.Left.Index -is [System.Management.Automation.Language.StringConstantExpressionAst]) { [void]$keys.Add($as.Left.Index.Value) }
        $vals.Add($as.Right.Extent.Text)
    }
}
$dkKeys = @(@($keys) + @($vals) | Where-Object { $_ -match 'Δk|correction lecteur cible|Correction lecteur cible|Correction « lecteur cible »|correction « lecteur cible »|target drive correction|Target drive correction|"target drive" correction' })
Chk 'S2' ($dkKeys.Count -eq 0 -and $keys.Count -gt 100) "aucun texte i18n de la correction Dk, francais ou anglais ($($keys.Count) cles lues)$(if ($dkKeys.Count) { ' : ' + ($dkKeys[0]) })"
# Cles T(...) des fonctions du lecteur cible : toutes traduites
$tFns = @(@('140', 'Get-TargetWriteInfo'), @('140', 'Get-WriteFactorPlan'), @('140', 'Update-TargetDriveUi'), @('140', 'Set-TargetDriveFromUi'), @('140', 'Test-TargetWriteAllowed'),
          @('140', 'Get-TargetCurvesText'), @('140', 'Get-TargetDriveItems'), @('140', 'Update-SlowUi'), @('140', 'Update-WLevelUi'), @('140', 'Start-ImageWrite'), @('140', 'Start-WriteTabWrite'), @('140', 'Start-PresetWrite'),
          @('220', 'Set-PrecompFields'), @('300', 'Start-Restore'), @('300', 'Start-RestoreWrite'), @('300', 'Get-RsCalibText'), @('300', 'Get-RestoreTargetInfo'), @('170', 'Complete-WriteCheck'), @('120', 'Load-Config'), @('240', 'Reset-CalibProfiles'))
$miss = @()
foreach ($p in $tFns) {
    $fa = Get-TgFnAst $p[0] $p[1]
    foreach ($c in @($fa.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'T' }, $true))) {
        $a = @($c.CommandElements)[1]
        if ($a -is [System.Management.Automation.Language.StringConstantExpressionAst] -and -not $keys.Contains($a.Value)) { $miss += "$($p[1]) : $($a.Value.Substring(0, [math]::Min(60, $a.Value.Length)))" }
    }
}
Chk 'S3' ($miss.Count -eq 0) "textes T(...) du lecteur cible, de la restauration et du facteur : tous traduits$(if ($miss.Count) { ' ; manquants : ' + (($miss | Select-Object -First 4) -join ' | ') })"
$s520 = [System.IO.File]::ReadAllText((Get-TgMod '520'))
# 12.11 (lot L9, onglet Ecriture en trois etapes) : libelle et liste « Lecteur cible » dans le cadre « 2. Disquette et
# lecteur » ($grpWOpt), sur la rangee de la liste « Mesure : », et non plus sur l onglet ($tabW) ; adapte a dessein
$tgtIn2 = [regex]::IsMatch($s520, '(?s)\$grpWOpt\.Controls\.AddRange\(@\([^)]*\$lblWLevelMode, \$cmbWLevelMode, \$lblWTarget, \$cmbWTarget,') -and -not $s520.Contains('$tabW.Controls.AddRange(@($lblWTarget, $cmbWTarget))')
Chk 'S4' ($s520.Contains('$cmbWTarget.Add_SelectedIndexChanged({ if ($script:UiReady) { Set-TargetDriveFromUi } })') -and $s520.Contains("`$cmbDrive.Add_TextChanged({`r`n    Update-TargetDriveUi; Update-SlowUi`r`n    Sync-PrecompCurves`r`n") -and $s520.Contains('$script:WLevelTip = $tip.GetToolTip($chkWLevel)') -and $tgtIn2 -and -not $s520.Contains('numWTgt')) "520 : liste sous UiReady, changement de lecteur du bandeau (liste, case de la mesure, vue), infobulle d origine gardee, champs Dk retires ; libelle et liste dans le cadre 2, apres la liste « Mesure : » (lot L9)"
$sIw = Get-TgFn '140' 'Start-ImageWrite'
$iBusy = $sIw.IndexOf('if ($script:GwProc -and -not $script:GwProc.HasExited) { return }'); $iTa = $sIw.IndexOf('Test-TargetWriteAllowed'); $iGw = $sIw.IndexOf('Start-Gw'); $iQ = $sIw.IndexOf('WriteQueue.Clear()')
Chk 'S5' ($iBusy -ge 0 -and $iTa -gt $iBusy -and $iGw -gt $iTa -and $iQ -gt $iTa -and $sIw.IndexOf('$tc = @($tw.Curves)') -gt $sIw.IndexOf('elseif ($script:WProfileHd)') -and $sIw.IndexOf('$tc = @($tw.Curves)') -lt $sIw.IndexOf('$pc0 = if')) "Start-ImageWrite : refus apres le test d occupation et avant toute commande ; champs remis avant leur lecture (`$pc0)"
$sCw = Get-TgFn '170' 'Complete-WriteCheck'
Chk 'S6' ($sCw.IndexOf('if ($rep.Target)') -gt 0 -and $sCw.IndexOf('if ($rep.Target)') -lt $sCw.IndexOf('Append-Log $txt')) "Complete-WriteCheck : complement du verdict avant son ecriture au journal"
$ch = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'))
$c1210 = $ch.Substring(0, $ch.IndexOf('## [12.9]'))
Chk 'S7' ($c1210.Contains('- **Écriture pour un lecteur cible.**') -and $c1210.Contains('- **Correction « lecteur cible » retirée.**') -and -not $c1210.Contains('tapée au clavier') -and -not $c1210.Contains('La correction « lecteur cible » est conservée') -and -not $c1210.Contains('la correction « lecteur cible » reste valable') -and $c1210.Contains('`Get-TargetWriteInfo($img, $fmt, $slow)`') -and -not $ch.Contains("`r`n")) "CHANGELOG [12.10] : ecriture pour un lecteur cible, correction retiree, plus de point « tapee au clavier » ni « conservee » ; LF seuls"
$rd = [System.IO.File]::ReadAllText((Join-Path $mods 'README.md'))
Chk 'S8' ($rd.Contains('`Get-TargetWriteInfo` : effet, famille, courbes croisées et refus') -and $rd.Contains('12.10 : restauration pour un lecteur cible') -and $rd.Contains('bloc `write.targetDrive`')) "README des modules : 140, 300 et 120"
$d040 = [System.IO.File]::ReadAllText((Get-TgMod '040'))
Chk 'S9' ($d040 -match "drive\s+= @\{ Sec = 'global';\s+Key = 'drive';\s+Type = 'enum';\s+Def = 'A';\s+Codes = @\('A', 'B', '0', '1', '2', '3'\) \}") "remplacant de SettingDefs['drive'] conforme a 040 (codes A, B, 0 a 3)"

# Fonctions qui rendent un tableau protege par la virgule (return ,@(...)) : jamais appelees dans @() (le tableau y serait
# emballe dans un autre : liste « Lecteur cible » a un seul element « System.Object[] », lecteurs de la configuration
# tous inconnus ; defauts trouves par ce test dans la tentative interrompue)
$prot = @(); $wrap = @()
foreach ($f in (Get-ChildItem -LiteralPath $mods -Filter '*-fn-*.ps1')) {
    foreach ($fd in @((Get-TgAst $f.FullName).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))) { if ($fd.Extent.Text -match 'return ,@\(') { $prot += $fd.Name } }
}
foreach ($f in (Get-ChildItem -LiteralPath $mods -Filter '*.ps1')) {
    foreach ($sx in @((Get-TgAst $f.FullName).FindAll({ param($x) $x -is [System.Management.Automation.Language.ArrayExpressionAst] }, $true))) {
        $st = @($sx.SubExpression.Statements)
        if ($st.Count -eq 1 -and $st[0] -is [System.Management.Automation.Language.PipelineAst] -and @($st[0].PipelineElements).Count -eq 1 -and $st[0].PipelineElements[0] -is [System.Management.Automation.Language.CommandAst] -and $prot -contains $st[0].PipelineElements[0].GetCommandName()) { $wrap += "$($f.Name):$($sx.Extent.StartLineNumber):$($sx.Extent.Text.Substring(0, [math]::Min(50, $sx.Extent.Text.Length)))" }
    }
}
Chk 'S10' ($prot -contains 'Get-TargetDriveItems' -and $prot -contains 'Get-DriveIds' -and $wrap.Count -eq 0) "$($prot.Count) fonctions a tableau protege par la virgule, aucune appelee seule dans @()$(if ($wrap.Count) { ' : ' + (($wrap | Select-Object -First 4) -join ' ; ') })"
$rr0 = [System.IO.File]::ReadAllText((Join-Path $Wt 'README.md'))
Chk 'S11' (-not $rr0.Contains('targetCorrection') -and -not $rr0.Contains('correction « lecteur cible »') -and $rr0.Contains('`targetDrive`') -and $rr0.Contains('liste « Lecteur cible »') -and -not $rr0.Contains("`r`n")) "README racine : plus de correction « lecteur cible » ni de bloc targetCorrection ; liste « Lecteur cible » et bloc targetDrive ; LF seuls"

Remove-Item -LiteralPath $imgDir -Recurse -Force -ErrorAction SilentlyContinue
$nk = if ($script:Fail) { ' ; non conformes : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-1210-target-n : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
