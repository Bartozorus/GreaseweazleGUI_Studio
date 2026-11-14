param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 (lot L7) : revenir a une calibration precedente. Copies de la configuration lues sans effet (Read-DriveCurves,
# Read-CalibBackup, Get-CalibBackFiles, 120), lignes (Get-CalibBackItems), decision unique d une ligne (Get-CalibBackInfo :
# lecteur d aujourd hui par Resolve-DriveOfEra, 112, colonne « Lecteur », detail, bouton), action (Restore-CalibBack),
# commande (Start-CalibBack, 240), fenetre construite sans etre affichee (New-CalibBackDialog, 250), copie d avant le retour
# (Backup-ConfigBeforeRef, motif back, 120).
#  R1 Read-DriveCurves : meme resultat qu Import-DriveCurves (bloc 12.10 a deux lecteurs et cle croisee, bloc 12.9), magasin
#     intact, meme en cas d erreur.
#  R2 Read-CalibBackup : copie 12.10, copie 12.9, JSON tronque, sans bloc write, fichier absent ; Get-CalibBackFiles.
#  R3 Get-CalibBackItems : dedoublonnage, paire par tete, courbe commune, cle croisee « A → 0 », courbe identique a celle en
#     place ecartee, tri, courbe d un autre calcul.
#  R4 Get-CalibBackInfo : courbes remplacees et ajoutees, courbes par tete plus anciennes que la commune en place, textes
#     francais et anglais, courbe deja conservee dans la copie ; ligne mixte (copie, courbe ajoutee restee apres une
#     annulation) et ligne qui ne fait qu ajouter (aucune copie), dites par le detail.
#  R5 Restore-CalibBack : seules les cles de la ligne changent ; copie avant le premier Set-DriveCurve ; copie lue protegee
#     de la rotation (effet de la rotation sans protection) ; enregistrement ou copie en echec : rien n est modifie ; autre
#     calcul : courbe conservee ; courbe en attente du choix retiree (en place ou non), ses niveaux mis de cote repris et
#     toujours ecrits (instructions reelles de Save-Config qui composent levelShifts) ; profil de famille du lecteur du
#     bandeau.
#  R6 aller et retour : configuration de depart rendue, copie d origine intacte (suffixe -r), aucune copie ecrasee.
#  R7 Start-CalibBack : operation en cours, calibration B en attente, aucune ligne, copie illisible, fenetre et action
#     tirees de Get-CalibBackInfo.
#  R8 statique : bouton btnWCalBack (geometrie provisoire), « Effacer les calibrations » inchange, cle de 010 remplacee,
#     textes anglais, decision unique (appelants de Resolve-DriveOfEra, Get-CalibBackInfo, Restore-CalibBack, motif back),
#     documents.
#  A  lecteurs enregistres (amendement du plan, L7) : copie d avant le registre avec et sans attribution posterieure,
#     lecteur renomme, supprime, recree, courbe croisee a un cote renomme, registre vide puis noms recrees dans un autre
#     ordre, fiche refaite par Repair-DriveRegistry, lien ambigu, ligne incertaine refusee sans la case et retablie avec
#     elle, copie .lecteurs-<date>.bak.
# Fonctions reelles extraites par l arbre syntaxique, ecrites dans un fichier de travail et chargees par dot-source ;
# controles WinForms reels jamais affiches ; bouchons : journal, messages, confirmation, rafraichissements, enregistrement
# de la configuration (fichier JSON du magasin reel), horloge. Copies de test factices (courbes synthetiques) sous le
# dossier de travail : aucune donnee de l utilisateur.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
Import-TestWinForms
$tFn = [System.Management.Automation.Language.FunctionDefinitionAst]
$tAsg = [System.Management.Automation.Language.AssignmentStatementAst]
$mods = Join-Path $Wt 'src\modules'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---------------------------------------------------------------- fonctions et etat reels
$script:AstOf = @{}
function Get-RtAst([string]$path) {
    if (-not $script:AstOf.ContainsKey($path)) {
        $tk = $null; $er = $null
        $a = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
        if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message)" }
        $script:AstOf[$path] = $a
    }
    return $script:AstOf[$path]
}
function Get-RtModule([string]$prefix) {
    $f = @(Get-ChildItem -LiteralPath $mods -Filter "$prefix-*.ps1" -File)
    if ($f.Count -ne 1) { throw "module $prefix : $($f.Count) fichier(s)" }
    return $f[0].FullName
}
function Get-RtFn([string]$prefix, [string]$name) {
    foreach ($fd in (Get-RtAst (Get-RtModule $prefix)).FindAll({ param($x) $x -is $tFn }, $false)) { if ($fd.Name -eq $name) { return $fd } }
    return $null
}
$want = [ordered]@{
    '100' = @('Get-DlgPalette', 'New-DlgBanner', 'Get-DlgButtonWidth', 'Set-PrimaryEnabled')
    '112' = @('*')
    '120' = @('ConvertTo-SettingValue', 'Get-Cfg', 'Backup-ConfigBeforeRef', 'Export-CurveView', 'Export-DriveCurves', 'Import-DriveCurves', 'Read-DriveCurves', 'Read-CalibBackup', 'Get-CalibBackFiles')
    '140' = @('Get-DriveIds', 'Get-TargetDrive')
    '220' = @('Get-CurveDate', 'Get-DriveFamilyCurves')
    '230' = @('Test-CurveHd', 'Get-CalibFamilyName', 'Get-CurveCalc', 'Get-CurveCalcRef', 'Test-CurveCalcOk', 'Get-CurveCalcText', 'Test-CurveCalcBefore', 'ConvertTo-CurveConfig', 'ConvertFrom-CurveConfig', 'ConvertTo-LevelConfig')
    '240' = @('Get-CurveKeyLabel', 'Get-DriveCurveKey', 'Split-DriveCurveKey', 'Get-DriveCurve', 'Set-DriveCurve', 'Sync-PrecompCurves', 'Get-DriveCurveKeys', 'Get-DriveCurveLabel', 'Split-CrossDrive',
              'Get-CalibStoreDrive', 'Reset-CalibProfiles', 'Get-CalibResetAfterText', 'Get-CalibBackFamily', 'Get-CalibBackHeadsText', 'Get-CalibBackTestText', 'Test-CalibBackSameCurve', 'Get-CalibBackInfo',
              'Get-CalibBackItems', 'Restore-CalibBack', 'Start-CalibBack')
    '250' = @('New-CalibBackDialog', 'Get-CalibBackDialogIndex', 'Update-CalibBackDialog', 'Get-CalibBackDialogPick')
}
$parts = New-Object System.Collections.Generic.List[string]
$missing = @()
foreach ($px in @($want.Keys)) {
    $fds = @((Get-RtAst (Get-RtModule $px)).FindAll({ param($x) $x -is $tFn }, $false))
    if (@($want[$px]) -contains '*') { foreach ($fd in $fds) { $parts.Add($fd.Extent.Text) }; continue }
    foreach ($n in @($want[$px])) { $hit = @($fds | Where-Object { $_.Name -eq $n }); if ($hit.Count -ne 1) { $missing += $n } else { $parts.Add($hit[0].Extent.Text) } }
}
# Relecture de L7 : niveaux de la calibration rapide qu ecrirait la vraie Save-Config (120) : ses trois instructions qui
# composent levelShifts ($oc, $lvCfg et son complement des niveaux mis de cote), extraites par l arbre syntaxique, dans une
# fonction du fichier de travail (Get-RtSavedLevels) ; le reste de Save-Config reste bouchonne
$svSt = @()
$svFn = Get-RtFn '120' 'Save-Config'
if ($svFn) {
    foreach ($st in $svFn.Body.EndBlock.Statements) {
        if (($st -is $tAsg -and @('$oc', '$lvCfg') -contains $st.Left.Extent.Text) -or ($st -is [System.Management.Automation.Language.IfStatementAst] -and $st.Extent.Text.Contains('$lvCfg +='))) { $svSt += $st.Extent.Text }
    }
}
if ($svSt.Count -ne 3) { $missing += "Save-Config (instructions des niveaux : $($svSt.Count) sur 3)" } else { $parts.Add("function Get-RtSavedLevels {`r`n" + ($svSt -join "`r`n") + "`r`n    return ,@(`$lvCfg)`r`n}") }
$wantState = [ordered]@{
    '000' = @('$script:CalibCalc', '$script:CalibCalcHd')
    '040' = @('$script:PrecompStd', '$script:PrecompLong', '$script:PrecompStdDefault', '$script:PrecompLongDefault', '$script:SettingDefs', '$script:DriveReg', '$script:DriveLast', '$script:DriveChecked',
              '$script:DriveCur', '$script:DriveRescued', '$script:DriveRescueText', '$script:DriveRescuePairs', '$script:DriveBlockKeep', '$script:DriveNameMax', '$script:DriveListWidth', '$script:DriveBackupKeep', '$script:DriveReserved')
    '500' = @('$script:Theme')
    '560' = @('$script:DriveCurves', '$script:PrecompCurves', '$script:CurveKeys', '$script:LevelShifts', '$script:LevelBrands', '$script:ConfigRefBackupKeep', '$script:TargetDrives')
    '565' = @('$script:ContentMeasures')
}
$stateParts = New-Object System.Collections.Generic.List[string]
foreach ($px in @($wantState.Keys)) {
    $seen = @{}
    foreach ($st in (Get-RtAst (Get-RtModule $px)).EndBlock.Statements) { if ($st -is $tAsg -and @($wantState[$px]) -contains $st.Left.Extent.Text -and -not $seen.ContainsKey($st.Left.Extent.Text)) { $stateParts.Add($st.Extent.Text); $seen[$st.Left.Extent.Text] = $true } }
    foreach ($n in @($wantState[$px])) { if (-not $seen.ContainsKey($n)) { $missing += "$px $n" } }
}
if ($missing.Count) { throw "fonctions ou etat introuvables : $($missing -join ', ')" }
$genFn = Join-Path $here 'gen-fonctions.ps1'
[System.IO.File]::WriteAllText($genFn, ((@($parts) -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
$genState = Join-Path $here 'gen-etat.ps1'
[System.IO.File]::WriteAllText($genState, ((@($stateParts) -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
$Language = 'fr'
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' -File | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'
. $genState
. $genFn
$script:CalHardNsUser = 470; $script:OldCalib = $null; $script:CalRedo = $null; $script:CurveForm = $null

# ---------------------------------------------------------------- remplacants
$script:Log = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text) { $script:Log.Add($text) }
$script:Busy = ''
function Get-AppBusy([switch]$Text) { return $script:Busy }
$script:Msgs = New-Object System.Collections.Generic.List[object]; $script:MsgAnswer = 'OK'
function Show-AppMessage([string]$text, [string]$title, [string]$buttons = 'OK', [string]$icon = 'Information') { $script:Msgs.Add(@{ Text = $text; Title = $title; Buttons = $buttons; Icon = $icon }); Append-Log $text; return $script:MsgAnswer }
$script:Confirms = New-Object System.Collections.Generic.List[object]; $script:ConfirmAnswer = $false
function Show-AppConfirm([string]$Title, [string]$Heading, [string]$Text, [string]$Check = '', [string]$GoText = '', [string]$GoGlyph = '', [string]$Level = 'warn', [string]$Picto = 'warn', [string]$AltText = '', $Combo = $null) {
    $script:Confirms.Add(@{ Title = $Title; Heading = $Heading; Text = $Text; Check = $Check; GoText = $GoText }); return $script:ConfirmAnswer
}
$script:NUpd = 0; $script:NBtn = 0
function Update-PrecompForImage([string]$path) { $script:NUpd++ }
function Update-CurveButton([string]$path) { $script:NBtn++ }
function New-DlgPicto([string]$kind, [string]$badge = '') { return $null }
$script:BtnStyle = @{}
function Set-Btn($btn, [string]$glyph, [string]$style = 'normal', [switch]$IconOnly, $IconColor = $null) { $script:BtnStyle[[string]$btn.Name] = $(if ($IconOnly) { 'icon' } else { $style }) }
function Get-WProfileText { return '' }
# Horloge du test : copies et fiches datees de facon reproductible
$script:TNow = New-Object datetime(2026, 11, 20, 18, 2, 11)
function Get-Date {
    param([string]$Format)
    if ($Format) { return $script:TNow.ToString($Format, [System.Globalization.CultureInfo]::InvariantCulture) }
    return $script:TNow
}
# Enregistrement de la configuration : magasin reel (Export-DriveCurves, Export-CurveView) et registre reel
# (Export-DriveRegistry) ecrits dans $script:ConfigFile ; echec a la demande ; fichier tenu ouvert apres l ecriture a la
# demande (la copie qui suit echoue alors)
$script:SaveFail = $false; $script:NSave = 0; $script:LockAfterSave = $false; $script:Lock = $null
function Save-Config {
    $script:NSave++
    if ($script:SaveFail) { Append-Log 'ERREUR sauvegarde configuration : echec simule'; return $false }
    $cfg = [ordered]@{ global = [ordered]@{ drive = (Get-DriveConn ([string]$cmbDrive.Text)) }
                       write = [ordered]@{ calibCalc = $script:CalibCalc; precompCurves = (Export-CurveView $script:OldCalib); driveCurves = (Export-DriveCurves $script:OldCalib) } }
    $dr = Export-DriveRegistry
    if ($dr) { $cfg['drives'] = $dr }
    [System.IO.File]::WriteAllText([string]$script:ConfigFile, ($cfg | ConvertTo-Json -Depth 8), $utf8)
    if ($script:LockAfterSave) { $script:Lock = New-Object System.IO.FileStream([string]$script:ConfigFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None) }
    return $true
}
function Close-RtLock { if ($script:Lock) { $script:Lock.Dispose(); $script:Lock = $null }; $script:LockAfterSave = $false }

# ---------------------------------------------------------------- controles reels, jamais affiches
$form = New-Object System.Windows.Forms.Form
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
$script:BtnFont = New-Object System.Drawing.Font('Segoe UI', 9.75)
$script:BtnFontBold = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold)
$cmbDrive = New-Object System.Windows.Forms.ComboBox
$cmbDrive.DropDownStyle = 'DropDownList'
[void]$cmbDrive.Items.AddRange([object[]]@($script:SettingDefs['drive'].Codes))
$cmbDrive.SelectedItem = 'A'
$txtWFile = New-Object System.Windows.Forms.TextBox; $txtWFile.Text = 'jeu.adf'
$lblWCal = New-Object System.Windows.Forms.Label; $lblWCal.Visible = $false
$pbWCal = New-Object System.Windows.Forms.ProgressBar; $pbWCal.Visible = $true
function Set-RtBanner([string]$id) { if (-not $cmbDrive.Items.Contains($id)) { [void]$cmbDrive.Items.Add($id) }; $cmbDrive.SelectedItem = $id; Sync-PrecompCurves }

# ---------------------------------------------------------------- donnees factices
function New-Cv([string]$drive, [string]$key, [string]$date, [int]$off = 0, [string]$calc = '', [string]$target = '') {
    # Courbe synthetique complete (champs lus par ConvertTo-CurveConfig) ; calcul : celui de la famille par defaut
    $fam = Get-CalibBackFamily $key
    if (-not $calc) { $calc = $(if ($fam -eq 'hd') { $script:CalibCalcHd } else { $script:CalibCalc }) }
    $head = $null; if ($key -match '_h(\d)$') { $head = [int]$Matches[1] }
    $vals = [int[]]@(0..79 | ForEach-Object { 40 + $_ + $off })
    return @{ Family = (Get-CalibFamilyName $fam); Head = $head; Drive = $drive; Target = $target; Date = $date; Model = 'M1'; Spec = ('0={0}:40={1}' -f (40 + $off), (80 + $off)); Method = 'motif'
              Version = $calc; Algo = 'a'; Calc = $calc; KeptFor = ''; Breaks = [int[]]@(); Values = $vals; Cyls = [int[]]@(0, 40, 79); Ys = [double[]]@(40.0, 80.0, 119.0); Sig = [double[]]@(3.0, 3.0, 3.0)
              Kinds = [string[]]@('zero', 'zero', 'zero'); Res = [double[]]@(0.5, -0.5, 0.0); Converged = $true; MaxX = 300; MaxNs = 470; Slope = 0.8; Bits = 101344; Test = 'fine'
              Contra = [int[]]@(); DentLo = [int[]]@(); DentHi = [int[]]@(); DentNs = [double[]]@() }
}
function Set-Rt([string]$sk, $cv) { $p = Split-DriveCurveKey $sk; Set-DriveCurve $p.Drive $p.Key $cv }
function New-RtRec([string]$name, [string]$conn, [string]$id, [string]$created, [string]$from = '', [string]$at = '') { return @{ Name = $name; Conn = $conn; Id = $id; Created = $created; From = $from; At = $at } }
function Set-RtReg($recs) { $script:DriveReg = New-DriveRegTable @($recs); $script:DriveLast = @{} }
function Reset-Rt([string]$case) {
    # Etat vierge, dossier de configuration propre au cas
    Close-RtLock
    $script:DriveCurves = @{}; $script:OldCalib = $null; $script:CalRedo = $null; $script:Busy = ''
    $script:DriveReg = [ordered]@{}; $script:DriveLast = @{}; $script:DriveRescueText = $null; $script:DriveBlockKeep = $false
    $script:LevelShifts = @{}; $script:LevelBrands = @(); $script:ContentMeasures = @(); $script:TargetDrives = @{}
    $script:Log.Clear(); $script:Msgs.Clear(); $script:Confirms.Clear(); $script:SaveFail = $false; $script:MsgAnswer = 'OK'; $script:ConfirmAnswer = $false
    $script:Lang = 'fr'
    $d = Join-Path $here ('cfg-' + $case)
    if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
    [void](New-Item -ItemType Directory -Path $d)
    $script:ConfigFile = Join-Path $d 'GreaseweazleGUI.json'
    Set-RtBanner 'A'
}
function Save-RtCopy([string]$suffix, [datetime]$when) {
    # Copie de l etat actuel, comme l application la ferait : enregistrement, copie octet pour octet, date de la copie
    [void](Save-Config)
    $p = [string]$script:ConfigFile + '.' + $suffix
    [System.IO.File]::Copy([string]$script:ConfigFile, $p, $true)
    [System.IO.File]::SetLastWriteTime($p, $when)
    return $p
}
function Write-RtFile([string]$suffix, [string]$text, [datetime]$when) {
    $p = [string]$script:ConfigFile + '.' + $suffix
    [System.IO.File]::WriteAllText($p, $text, $utf8)
    [System.IO.File]::SetLastWriteTime($p, $when)
    return $p
}
function Get-RtBaks { return @(Get-ChildItem -LiteralPath (Split-Path -Parent ([string]$script:ConfigFile)) -File | Where-Object { $_.Name -like '*.bak' } | ForEach-Object { $_.Name } | Sort-Object) }
function Get-RtHashes {
    $h = @{}
    foreach ($f in @(Get-ChildItem -LiteralPath (Split-Path -Parent ([string]$script:ConfigFile)) -File | Where-Object { $_.Name -like '*.bak' })) {
        $b = [System.IO.File]::ReadAllBytes($f.FullName); $h[$f.Name] = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($b))
    }
    return $h
}
function Get-RtStore { return ((Export-DriveCurves $script:OldCalib) | ConvertTo-Json -Depth 8 -Compress) }
function Get-RtOthers { return (@{ L = $script:LevelShifts; B = @($script:LevelBrands); M = @($script:ContentMeasures); T = $script:TargetDrives; H = $script:CalHardNsUser; P = [string]$cmbDrive.Text } | ConvertTo-Json -Depth 6 -Compress) }
function Get-RtItems { $rd = @(); foreach ($f in @(Get-CalibBackFiles)) { $b = Read-CalibBackup $f; if ($b.Ok) { $rd += ,$b } }; return @(Get-CalibBackItems $rd) }
function Find-RtItem($items, [string]$eraDrive, [string]$date, [string]$file = '') { return @(@($items) | Where-Object { [string]$_.EraDrive -eq $eraDrive -and [string]$_.Date -eq $date -and (-not $file -or [string]$_.FileName -like "*$file") })[0] }
# Fenetre : la vraie New-CalibBackDialog, sans affichage ; choix d une ligne par la vraie Get-CalibBackDialogPick
$script:DlgPick = -1; $script:LastDlg = $null; $script:NDlg = 0
function Show-CalibBackDialog($items, [int]$nFiles, [string[]]$skipped) {
    $script:NDlg++
    $st = New-CalibBackDialog $items $nFiles $skipped
    $script:LastDlg = $st
    $dr = [System.Windows.Forms.DialogResult]::Cancel
    # Ligne choisie : selection posee sur la ligne, relue par la vraie Get-CalibBackDialogIndex (gestionnaire de la liste)
    if ($script:DlgPick -ge 0) { $st.Lv.Items[$script:DlgPick].Selected = $true; Update-CalibBackDialog $st (Get-CalibBackDialogIndex $st.Lv); $dr = [System.Windows.Forms.DialogResult]::OK }
    return (Get-CalibBackDialogPick $st $dr)
}
"logic-calib-retour : CalibCalc $($script:CalibCalc), copies sous $here ; PowerShell $($PSVersionTable.PSVersion)"

# ================================================================ R1 Read-DriveCurves
'--- R1 : Read-DriveCurves (120) : meme lecture qu Import-DriveCurves, sans effet sur le magasin'
$w1210 = ('{"driveCurves":{"A|std":' + ((ConvertTo-CurveConfig (New-Cv 'A' 'std' '01/10/2026 10:00')) | ConvertTo-Json -Depth 6 -Compress) +
          ',"0|std_h0":' + ((ConvertTo-CurveConfig (New-Cv '0' 'std_h0' '02/10/2026 10:00' 3)) | ConvertTo-Json -Depth 6 -Compress) +
          ',"A>0|std_h0":' + ((ConvertTo-CurveConfig (New-Cv '' 'std_h0' '03/10/2026 10:00' 5)) | ConvertTo-Json -Depth 6 -Compress) +
          ',"0|long":' + ((ConvertTo-CurveConfig (New-Cv '0' 'long' '04/10/2026 10:00' 7 '12.9')) | ConvertTo-Json -Depth 6 -Compress) + '}}') | ConvertFrom-Json
$w129 = ('{"precompCurves":{"std":' + ((ConvertTo-CurveConfig (New-Cv '0' 'std' '05/10/2026 10:00' 1)) | ConvertTo-Json -Depth 6 -Compress) +
         ',"long":' + ((ConvertTo-CurveConfig (New-Cv '' 'long' '06/10/2026 10:00' 2)) | ConvertTo-Json -Depth 6 -Compress) + '}}') | ConvertFrom-Json
function Get-RtReadSig($r) {
    $c = @($r.Curves.Keys | Sort-Object | ForEach-Object { "$_=$($r.Curves[$_].Drive)/$($r.Curves[$_].Target)/$(@($r.Curves[$_].Values)[0])" }) -join ';'
    $o = @($r.Old.Keys | ForEach-Object { "$_=$($r.Old[$_].Drive)" }) -join ';'
    return "$c|$o|$($r.N)|$($r.Migrated)|$(@($r.Drives) -join ',')"
}
foreach ($cs in @(@{ Id = 'R1a'; Pcv = $null; Dcv = $w1210.driveCurves; D = 'A'; T = 'bloc 12.10 : deux lecteurs, cle croisee « A>0|std_h0 », courbe d un autre calcul' },
                  @{ Id = 'R1b'; Pcv = $w129.precompCurves; Dcv = $null; D = 'B'; T = 'bloc 12.9 : courbe avec et sans champ drive' })) {
    $sentinel = New-Cv 'B' 'std' '09/09/2026 09:09' 99
    $script:DriveCurves = @{ 'B|std' = $sentinel }; $ref = $script:DriveCurves
    $rd = Read-DriveCurves $cs.Pcv $cs.Dcv $cs.D
    $afterRef = [object]::ReferenceEquals($script:DriveCurves, $ref) -and $script:DriveCurves.Count -eq 1 -and [object]::ReferenceEquals($script:DriveCurves['B|std'], $sentinel)
    $im = Import-DriveCurves $cs.Pcv $cs.Dcv $cs.D
    $imSig = Get-RtReadSig @{ Curves = $script:DriveCurves; Old = $im.Old; N = $im.N; Migrated = $im.Migrated; Drives = $im.Drives }
    $rdSig = Get-RtReadSig $rd
    Chk $cs.Id ($afterRef -and $rdSig -ceq $imSig -and $rd.Curves.Count -ge 1) "$($cs.T) : courbes, mises de cote, nombre, migration et lecteurs identiques a Import-DriveCurves ($rdSig) ; magasin en place intact (meme table, meme courbe)"
}
$script:DriveCurves = @{ 'B|std' = (New-Cv 'B' 'std' '09/09/2026 09:09') }; $ref = $script:DriveCurves
${function:Rt-RealConvFrom} = ${function:ConvertFrom-CurveConfig}
function ConvertFrom-CurveConfig($o) { throw 'erreur simulee' }
$thrown = $false; try { [void](Read-DriveCurves $null $w1210.driveCurves 'A') } catch { $thrown = $true }
${function:ConvertFrom-CurveConfig} = ${function:Rt-RealConvFrom}
Chk 'R1c' ($thrown -and [object]::ReferenceEquals($script:DriveCurves, $ref) -and $script:DriveCurves.Count -eq 1) 'erreur pendant la lecture : elle remonte a l appelant (Read-CalibBackup la note) et le magasin en place est remis (finally)'

# ================================================================ R2 Read-CalibBackup, Get-CalibBackFiles
'--- R2 : Read-CalibBackup et Get-CalibBackFiles (120)'
Reset-Rt 'r2'
Set-Rt 'A|std' (New-Cv 'A' 'std' '01/10/2026 10:00'); Set-Rt '0|std' (New-Cv '0' 'std' '02/10/2026 10:00' 2); Set-Rt 'A>0|std' (New-Cv 'A' 'std' '03/10/2026 10:00' 4 '' '0')
Set-Rt '0|long' (New-Cv '0' 'long' '04/10/2026 10:00' 6 '12.9')
$p1210 = Save-RtCopy 'ref-std-20261001-1000.bak' (New-Object datetime(2026, 10, 10, 10, 0, 0))
$store0 = Get-RtStore
$b1 = Read-CalibBackup $p1210
Chk 'R2a' ($b1.Ok -and (@($b1.Curves.Keys) -join ',') -ceq ((@('0|long', '0|std', 'A|std', 'A>0|std') | Sort-Object) -join ',') -and [string]$b1.Curves['A>0|std'].Target -eq '0' -and [string]$b1.Curves['0|long'].Calc -eq '12.9' -and $b1.Name -eq 'GreaseweazleGUI.json.ref-std-20261001-1000.bak' -and $b1.When -eq (New-Object datetime(2026, 10, 10, 10, 0, 0)) -and $null -eq $b1.Drives -and (Get-RtStore) -ceq $store0) "copie 12.10 : 4 courbes, cle croisee avec son lecteur cible, courbe d un autre calcul gardee ; nom, date de la copie, sans bloc drives ; magasin intact"
$j129 = '{"global":{"drive":"0"},"write":{"precompCurves":{"std":' + ((ConvertTo-CurveConfig (New-Cv 'A' 'std' '05/09/2026 10:00' 1 '12.9')) | ConvertTo-Json -Depth 6 -Compress) + ',"long":' + ((ConvertTo-CurveConfig (New-Cv '' 'long' '06/09/2026 10:00' 2 '12.9')) | ConvertTo-Json -Depth 6 -Compress) + '}}}'
$p129 = Write-RtFile 'calib-12.9-avant-v12.10.bak' $j129 (New-Object datetime(2026, 9, 7, 10, 0, 0))
$b2 = Read-CalibBackup $p129
Chk 'R2b' ($b2.Ok -and (@($b2.Curves.Keys) -join ',') -ceq ((@('0|long', 'A|std') | Sort-Object) -join ',') -and $b2.Drive -eq '0' -and [string]$b2.Curves['0|long'].Drive -eq '0') "copie 12.9 : courbe rangee sous son champ drive (A|std), courbe sans lecteur sous le lecteur de la copie (0|long)"
$pBad = Write-RtFile 'manuel.bak' '{"write":{"driveCurves":{"A|std":{"date":"01/' (New-Object datetime(2026, 9, 1, 10, 0, 0))
$b3 = Read-CalibBackup $pBad
$pNoW = Write-RtFile 'vide.bak' '{"global":{"drive":"A"}}' (New-Object datetime(2026, 9, 2, 10, 0, 0))
$b4 = Read-CalibBackup $pNoW
$b5 = Read-CalibBackup ([string]$script:ConfigFile + '.absente.bak')
Chk 'R2c' (-not $b3.Ok -and [string]$b3.Why -ne '' -and $b3.Curves.Count -eq 0) "JSON tronque : illisible (Ok faux, raison : $($b3.Why))"
Chk 'R2d' ($b4.Ok -and $b4.Curves.Count -eq 0) 'JSON sans bloc write : lisible, aucune courbe'
Chk 'R2e' (-not $b5.Ok -and [string]$b5.Why -ne '') 'fichier absent : Ok faux, raison donnee'
[System.IO.File]::WriteAllText(([string]$script:ConfigFile + '.lecteurs'), '{"drives":{"list":[]}}', $utf8)
[System.IO.File]::WriteAllText(([string]$script:ConfigFile + '.bak'), '{}', $utf8)
[System.IO.File]::WriteAllText((Join-Path (Split-Path -Parent ([string]$script:ConfigFile)) 'autre.json.ref-std-20261001-1000.bak'), '{}', $utf8)
$fl = @(Get-CalibBackFiles | ForEach-Object { [System.IO.Path]::GetFileName($_) })
Chk 'R2f' (($fl -join ',') -ceq 'GreaseweazleGUI.json.ref-std-20261001-1000.bak,GreaseweazleGUI.json.calib-12.9-avant-v12.10.bak,GreaseweazleGUI.json.vide.bak,GreaseweazleGUI.json.manuel.bak') "copies <fichier>.*.bak seules, la plus recente d abord ($($fl -join ', ')) : ni la copie de secours du registre (.lecteurs), ni « <fichier>.bak », ni la copie d un autre fichier"
for ($i = 0; $i -lt 45; $i++) { [void](Write-RtFile ('x{0:00}.bak' -f $i) '{}' (New-Object datetime(2026, 8, 1, 0, 0, 0)).AddMinutes($i)) }
$fl40 = @(Get-CalibBackFiles)
Chk 'R2g' ($fl40.Count -eq 40 -and [System.IO.Path]::GetFileName($fl40[0]) -eq 'GreaseweazleGUI.json.ref-std-20261001-1000.bak' -and @($fl40 | Where-Object { $_ -like '*x00.bak' }).Count -eq 0) '40 copies lues au plus, les plus recentes'

# ================================================================ R3 Get-CalibBackItems
'--- R3 : Get-CalibBackItems (240) : lignes, dedoublonnage, tri'
Reset-Rt 'r3'
Set-Rt 'A|std' (New-Cv 'A' 'std' '01/10/2026 10:00')
Set-Rt 'A|std_h0' (New-Cv 'A' 'std_h0' '02/10/2026 10:00' 1); Set-Rt 'A|std_h1' (New-Cv 'A' 'std_h1' '02/10/2026 10:00' 2)
Set-Rt 'A>0|std' (New-Cv 'A' 'std' '03/10/2026 10:00' 4 '' '0')
Set-Rt '0|long' (New-Cv '0' 'long' '04/10/2026 10:00' 6 '12.9')
$c1 = Save-RtCopy 'ref-std-20261001-1000.bak' (New-Object datetime(2026, 10, 5, 10, 0, 0))
$c2 = Save-RtCopy 'ref-std-20261002-1000.bak' (New-Object datetime(2026, 10, 6, 10, 0, 0))
# Etat d aujourd hui : courbe commune, paire par tete et courbe croisee de A recalibrees (dates nouvelles) ; 0|long
# (autre calcul) identique a celle des copies
Set-Rt 'A|std' (New-Cv 'A' 'std' '10/10/2026 10:00' 9)
Set-Rt 'A|std_h0' (New-Cv 'A' 'std_h0' '11/10/2026 10:00' 11); Set-Rt 'A|std_h1' (New-Cv 'A' 'std_h1' '11/10/2026 10:00' 12)
Set-Rt 'A>0|std' (New-Cv 'A' 'std' '12/10/2026 10:00' 14 '' '0')
$items3 = Get-RtItems
$it3 = @($items3 | ForEach-Object { "$($_.EraDrive)|$((@($_.CurveKeys)) -join '+')|$($_.Date)|$($_.FileName -replace 'GreaseweazleGUI.json.', '')" })
Chk 'R3a' ($items3.Count -eq 3) "3 lignes : $($it3 -join ' ; ')"
$iH = Find-RtItem $items3 'A' '02/10/2026 10:00'
$iC = Find-RtItem $items3 'A' '01/10/2026 10:00'
$iX = Find-RtItem $items3 'A>0' '03/10/2026 10:00'
Chk 'R3b' ($iH -and (@($iH.CurveKeys) -join ',') -ceq 'std_h0,std_h1' -and (Get-CalibBackHeadsText @($iH.CurveKeys)) -ceq 'par tête' -and $iC -and (@($iC.CurveKeys) -join ',') -ceq 'std' -and (Get-CalibBackHeadsText @($iC.CurveKeys)) -ceq 'commune') 'paire par tete : une ligne (« par tete ») ; courbe commune : une ligne (« commune »)'
Chk 'R3c' (@($items3 | Where-Object { $_.Date -eq '01/10/2026 10:00' }).Count -eq 1 -and [string]$iC.FileName -eq 'GreaseweazleGUI.json.ref-std-20261002-1000.bak' -and [string]$iH.FileName -eq 'GreaseweazleGUI.json.ref-std-20261002-1000.bak') 'meme calibration dans deux copies : une ligne, la copie la plus recente citee'
Chk 'R3d' ($iX -and (Get-CalibBackInfo $iX).DriveText -ceq 'A → 0' -and (Get-CalibBackInfo $iX).Drive -ceq 'A>0') 'cle croisee : colonne « Lecteur » « A → 0 », retablie sous « A>0 »'
Chk 'R3e' (@($items3 | Where-Object { $_.EraDrive -eq '0' }).Count -eq 0) 'courbe identique a celle en place (0|long, autre calcul : date, calcul, valeurs) : non listee'
Chk 'R3f' ((@($items3 | ForEach-Object { $_.Date }) -join ',') -ceq '03/10/2026 10:00,02/10/2026 10:00,01/10/2026 10:00') 'tri : date de calibration decroissante'
# Courbe d un autre calcul differente de celle en place
Set-Rt '0|long' (New-Cv '0' 'long' '12/10/2026 10:00' 8)
$items3b = Get-RtItems
$iO = Find-RtItem $items3b '0' '04/10/2026 10:00'
Chk 'R3g' ($iO -and -not $iO.CalcOk -and [string]$iO.Calc -eq '12.9' -and (Get-CalibBackInfo $iO).OtherCalc -and $items3b.Count -eq 4) 'courbe d un autre calcul differente de celle en place : listee, CalcOk faux, calcul 12.9'
# Paire par tete remise a l identique de la copie (les deux tetes) : plus listee ; une seule tete identique : listee
Set-Rt 'A|std_h0' (New-Cv 'A' 'std_h0' '02/10/2026 10:00' 1)
$items3c = Get-RtItems
$iH1 = Find-RtItem $items3c 'A' '02/10/2026 10:00'
Chk 'R3h' ($iH1 -and (@((Get-CalibBackInfo $iH1).Replace) -join ',') -ceq 'A|std_h0,A|std_h1') 'une tete identique a celle en place, l autre non : ligne listee (les deux tetes remplacees)'
Set-Rt 'A|std_h1' (New-Cv 'A' 'std_h1' '02/10/2026 10:00' 2)
$items3d = Get-RtItems
Chk 'R3i' (@($items3d | Where-Object { $_.EraDrive -eq 'A' -and $_.Date -eq '02/10/2026 10:00' }).Count -eq 0 -and $items3d.Count -eq 3) 'paire par tete identique a celle en place (les deux tetes) : non listee'

# ================================================================ R4 Get-CalibBackInfo
'--- R4 : Get-CalibBackInfo (240) : remplacees, ajoutees, tetes plus anciennes que la commune, textes'
Reset-Rt 'r4'
Set-Rt 'A|std_h0' (New-Cv 'A' 'std_h0' '01/10/2026 10:00' 1); Set-Rt 'A|std_h1' (New-Cv 'A' 'std_h1' '01/10/2026 10:00' 2)
$c4 = Save-RtCopy 'ref-std-20261001-1000.bak' (New-Object datetime(2026, 10, 2, 10, 0, 0))
$script:DriveCurves.Remove('A|std_h1')
Set-Rt 'A|std_h0' (New-Cv 'A' 'std_h0' '05/10/2026 10:00' 3)
Set-Rt 'A|std' (New-Cv 'A' 'std' '10/10/2026 10:00' 5)
$i4 = Find-RtItem (Get-RtItems) 'A' '01/10/2026 10:00'
$f4 = Get-CalibBackInfo $i4
Chk 'R4a' ($f4.Ok -and $f4.Sure -and -not $f4.NeedCheck -and (@($f4.Replace) -join ',') -ceq 'A|std_h0' -and (@($f4.Add) -join ',') -ceq 'A|std_h1' -and $f4.Drive -eq 'A') 'courbe en place remplacee (tete 0) et courbe ajoutee (tete 1)'
Chk 'R4b' ($f4.HeadsStale -and $f4.Text.Contains('Ces courbes par tête sont plus anciennes que la courbe commune en place de ce lecteur (10/10/2026 10:00)')) 'courbes par tete plus anciennes que la courbe commune en place : signalees, date de la commune'
Chk 'R4c' ($f4.Text.StartsWith('À rétablir : Standard 2 us (tête 0), lecteur A ; Standard 2 us (tête 1), lecteur A ; calibration du 01/10/2026 10:00, test fin, calcul v12.10.') -and $f4.Text.Contains('Courbes en place remplacées : Standard 2 us (tête 0), lecteur A.') -and $f4.Text.Contains("Les niveaux de la calibration rapide mesurés avec les courbes remplacées ne s'appliqueront plus.") -and $f4.Text.Contains('Copie lue : GreaseweazleGUI.json.ref-std-20261001-1000.bak, du 02/10/2026 10:00.')) 'detail francais : courbes, date, test, calcul, courbes remplacees, niveaux, copie lue'
$script:Lang = 'en'
$f4e = Get-CalibBackInfo $i4
$script:Lang = 'fr'
Chk 'R4d' ($f4e.Text.StartsWith('To restore: Standard 2 us (head 0), drive A ; Standard 2 us (head 1), drive A; calibrated on 01/10/2026 10:00, fine test, calculation v12.10.') -and $f4e.Text.Contains('Curves in place replaced: ') -and $f4e.Text.Contains('These per-head curves are older than the common curve in place for this drive (10/10/2026 10:00)') -and $f4e.Text.Contains('Copy read: GreaseweazleGUI.json.ref-std-20261001-1000.bak, dated 02/10/2026 10:00.')) "detail anglais : $(($f4e.Text -split "`n")[0])"
# Relecture de L7 : ligne mixte (une tete remplacee, l autre ajoutee) : copie faite, la courbe ajoutee reste apres une
# annulation, et le detail le dit
Chk 'R4g' ((@($f4.Backup) -join ',') -ceq 'A|std_h0' -and $f4.Text.Contains('Courbes ajoutées, sans courbe en place : Standard 2 us (tête 1), lecteur A. Elles restent en place si vous annulez ce retour.') -and -not $f4.Text.Contains("Aucune copie n'est faite") -and $f4e.Text.Contains('Curves added, with no curve in place: Standard 2 us (head 1), drive A. They stay in place if you undo this return.')) 'detail d une ligne mixte : copie de la tete remplacee (Backup), tete ajoutee qui reste en place si le retour est annule, francais et anglais'
$ok4 = Restore-CalibBack $i4
$fc4 = Get-DriveFamilyCurves 'A' 'std' $true
Chk 'R4e' ($ok4 -and @($fc4).Count -eq 1 -and [string]@($fc4)[0].Date -eq '10/10/2026 10:00' -and [string](Get-DriveCurve 'A' 'std_h1').Date -eq '01/10/2026 10:00') 'apres le retour : les deux tetes rétablies, mais Get-DriveFamilyCurves rend la courbe commune, plus recente (ecriture lente)'
$i4u = Find-RtItem (Get-RtItems) 'A' '05/10/2026 10:00'
$ok4u = Restore-CalibBack $i4u
Chk 'R4i' ($i4u -and $ok4u -and [string](Get-DriveCurve 'A' 'std_h0').Date -eq '05/10/2026 10:00' -and [string](Get-DriveCurve 'A' 'std_h1').Date -eq '01/10/2026 10:00' -and [string](Get-DriveCurve 'A' 'std').Date -eq '10/10/2026 10:00') 'annulation de ce retour (copie faite avant lui) : la tete remplacee revient, la tete ajoutee reste en place (comportement annonce par le detail et le CHANGELOG)'
# Ligne qui ne fait qu ajouter : aucune copie, le detail le dit
Reset-Rt 'r4h'
Set-Rt 'A|long' (New-Cv 'A' 'long' '01/10/2026 10:00' 1)
[void](Save-RtCopy 'ref-long-20261001-1000.bak' (New-Object datetime(2026, 10, 2, 10, 0, 0)))
Set-Rt 'A|long' $null
$i4h = Find-RtItem (Get-RtItems) 'A' '01/10/2026 10:00'
$f4h = Get-CalibBackInfo $i4h
$nb4h = @(Get-RtBaks).Count
$ok4h = Restore-CalibBack $i4h
Chk 'R4h' ($f4h.Ok -and @($f4h.Backup).Count -eq 0 -and (@($f4h.Add) -join ',') -ceq 'A|long' -and $f4h.Text.Contains("Aucune courbe en place n'est remplacée.") -and $f4h.Text.Contains("Aucune copie n'est faite avant ce retour : il ne s'annule pas par ce bouton, qui rétablit des courbes et n'en retire aucune.") -and -not $f4h.Text.Contains('Courbes ajoutées') -and $ok4h -and @(Get-RtBaks).Count -eq $nb4h -and [string](Get-DriveCurve 'A' 'long').Date -eq '01/10/2026 10:00') 'ligne qui ne fait qu ajouter : Backup vide, le detail dit qu aucune copie n est faite ; retour fait sans copie'
# Courbe d un autre calcul deja conservee dans la copie (KeptFor) : du calcul actuel pour l application, texte du calcul
# d origine et de sa conservation, jamais « v12.10 » seul
Reset-Rt 'r4k'
$cvK = New-Cv 'A' 'long' '01/09/2026 10:00' 1 '12.9'; $cvK.KeptFor = '12.10'
Set-Rt 'A|long' $cvK
[void](Save-RtCopy 'ref-long-20260901-1000.bak' (New-Object datetime(2026, 9, 2, 10, 0, 0)))
Set-Rt 'A|long' (New-Cv 'A' 'long' '10/09/2026 10:00' 3)
$iK = Find-RtItem (Get-RtItems) 'A' '01/09/2026 10:00'
$fK = Get-CalibBackInfo $iK
Chk 'R4f' ($iK -and $iK.CalcOk -and -not $fK.OtherCalc -and $fK.Text.Contains('test fin, calcul v12.9, conservé (calcul actuel v12.10).')) 'courbe deja conservee dans la copie : detail « calcul v12.9, conserve (calcul actuel v12.10) », sans la phrase de l autre calcul'

# ================================================================ R5 Restore-CalibBack
'--- R5 : Restore-CalibBack (240)'
Reset-Rt 'r5'
Set-Rt 'A|std' (New-Cv 'A' 'std' '01/10/2026 10:00' 0)
Set-Rt '0|std' (New-Cv '0' 'std' '02/10/2026 10:00' 2)
Set-Rt 'A>0|std' (New-Cv 'A' 'std' '03/10/2026 10:00' 4 '' '0')
$script:LevelShifts = @{ 'std|c|0|1' = @{ RefKey = 'std'; Tag = 'c|0|1'; Drive = 'A'; Date = '04/10/2026 10:00'; RefDate = '01/10/2026 10:00'; Delta = 5 } }
$script:LevelBrands = @(@{ Brand = 'Sony'; Drive = 'A'; RefDate = '01/10/2026 10:00'; K = 1.1 })
$script:ContentMeasures = @(@{ Drive = 'A'; K = 0.9; Date = '04/10/2026 11:00' })
$script:TargetDrives = @{ A = '0' }; $script:CalHardNsUser = 455
# Calibration A d origine (01/10), puis calibration complete de A (05/10) : copie 'replace' de l application
$t0 = $script:TNow
$script:TNow = New-Object datetime(2026, 10, 5, 10, 0, 0)
[void](Save-Config); $cOrig = Backup-ConfigBeforeRef @('A|std') 'replace'
Set-Rt 'A|std' (New-Cv 'A' 'std' '05/10/2026 10:00' 7); [void](Save-Config)
$storeB = Get-RtStore; $othersB = Get-RtOthers; $h0 = Get-RtHashes
$iA = Find-RtItem (Get-RtItems) 'A' '01/10/2026 10:00'
${function:Rt-RealSetDc} = ${function:Set-DriveCurve}
$script:FirstSetBaks = $null
function Set-DriveCurve([string]$drive, [string]$key, $cv) { if ($null -eq $script:FirstSetBaks) { $script:FirstSetBaks = @(Get-RtBaks) }; Rt-RealSetDc $drive $key $cv }
$script:TNow = New-Object datetime(2026, 10, 6, 9, 0, 0)
$nBak = @(Get-RtBaks).Count
$okA = Restore-CalibBack $iA
${function:Set-DriveCurve} = ${function:Rt-RealSetDc}
$cvA = Get-DriveCurve 'A' 'std'
$keysAfter = @(Get-DriveCurveKeys) -join ','
Chk 'R5a' ($okA -and [string]$cvA.Date -eq '01/10/2026 10:00' -and @($cvA.Values)[0] -eq 40 -and [string](Get-DriveCurve '0' 'std').Date -eq '02/10/2026 10:00' -and [string](Get-DriveCurve 'A>0' 'std').Date -eq '03/10/2026 10:00' -and $keysAfter -ceq ((@('0|std', 'A|std', 'A>0|std') | Sort-Object) -join ',')) "retour fait : seule A|std change (calibration du 01/10) ; 0|std et la courbe croisee A>0|std intactes ($keysAfter)"
Chk 'R5b' ((Get-RtOthers) -ceq $othersB) 'niveaux, memoire par marque, facteurs mesures, lecteur cible, borne precompMaxNs et lecteur du bandeau inchanges'
$backName = 'GreaseweazleGUI.json.ref-std-20261005-1000.bak'
Chk 'R5c' ($null -ne $script:FirstSetBaks -and @($script:FirstSetBaks).Count -eq $nBak + 1 -and @($script:FirstSetBaks) -contains $backName) "copie d avant le retour ($backName) creee avant le premier Set-DriveCurve"
$bk = [System.IO.File]::ReadAllText((Join-Path (Split-Path -Parent ([string]$script:ConfigFile)) $backName), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
Chk 'R5d' ([string]$bk.write.driveCurves.'A|std'.date -eq '05/10/2026 10:00' -and @($script:Log | Where-Object { $_ -like 'Configuration sauvegardée avant le retour à une calibration précédente (référence Standard 2 us du 05/10/2026 10:00) : *' }).Count -eq 1) 'la copie contient l etat d avant le retour (A|std du 05/10) ; ligne de journal de la copie'
Chk 'R5e' ($script:PrecompStd -eq [string]$cvA.Spec -and $script:PrecompCurves['std'] -eq $cvA -and $lblWCal.Text -eq 'Calibration précédente rétablie.' -and $lblWCal.Visible -and -not $pbWCal.Visible -and $script:NUpd -gt 0 -and $script:NBtn -gt 0) 'vue et profil de famille du lecteur du bandeau resynchronises ; ligne de l onglet ; champs --precomp et bouton Courbe rafraichis'
Chk 'R5f' (@($script:Log | Where-Object { $_ -like 'Calibration précédente rétablie : Standard 2 us (commune), lecteur A (calibration du 01/10/2026 10:00, calcul v12.10), lue dans *GreaseweazleGUI.json.ref-std-20261001-1000.bak. Courbes remplacées : Standard 2 us (commune), lecteur A.' }).Count -eq 1) 'ligne de journal du retour'
$h1 = Get-RtHashes
Chk 'R5g' (@($h0.Keys | Where-Object { -not $h1.ContainsKey($_) -or $h1[$_] -cne $h0[$_] }).Count -eq 0) 'aucune copie existante modifiee ni supprimee par le retour'
# Echecs : enregistrement, copie
$st5 = Get-RtStore; $nb5 = @(Get-RtBaks).Count; $iB = Find-RtItem (Get-RtItems) 'A' '05/10/2026 10:00'
$script:SaveFail = $true; $script:Msgs.Clear()
$okF1 = Restore-CalibBack $iB
$script:SaveFail = $false
Chk 'R5h' (-not $okF1 -and (Get-RtStore) -ceq $st5 -and @(Get-RtBaks).Count -eq $nb5 -and $script:Msgs.Count -eq 1 -and $script:Msgs[0].Text -ceq "Retour annulé : l'état actuel n'a pas pu être sauvegardé (voir le journal). Rien n'est modifié.") 'enregistrement en echec : retour annule, rien modifie, aucune copie, message 12'
$script:LockAfterSave = $true; $script:Msgs.Clear(); $script:Log.Clear()
$okF2 = Restore-CalibBack $iB
Close-RtLock
Chk 'R5i' (-not $okF2 -and (Get-RtStore) -ceq $st5 -and @(Get-RtBaks).Count -eq $nb5 -and $script:Msgs.Count -eq 1 -and @($script:Log | Where-Object { $_ -like "Configuration non sauvegardée avant le retour à une calibration précédente (Standard 2 us) : *. Retour annulé : rien n'est modifié." }).Count -eq 1) 'copie en echec (configuration tenue ouverte) : retour annule, rien modifie, ligne de journal 11, message 12'
# Rotation : copie lue protegee quand elle est la plus ancienne de dix ; sans protection, la plus ancienne est supprimee
Reset-Rt 'r5r'
Set-Rt 'A|std' (New-Cv 'A' 'std' '01/09/2026 10:00' 0)
$old = Save-RtCopy 'ref-std-20260901-1000.bak' (New-Object datetime(2026, 9, 1, 11, 0, 0))
# Les neuf copies plus recentes ne portent plus la calibration du 01/09 : la plus ancienne est la seule a la porter
Set-Rt 'A|std' (New-Cv 'A' 'std' '02/09/2026 09:00' 2)
for ($i = 1; $i -le 9; $i++) { [void](Save-RtCopy ('ref-long-2026090{0}-1000.bak' -f $i) ((New-Object datetime(2026, 9, 2, 10, 0, 0)).AddHours($i))) }
Set-Rt 'A|std' (New-Cv 'A' 'std' '15/09/2026 10:00' 3)
$script:TNow = New-Object datetime(2026, 9, 20, 10, 0, 0)
$iR = Find-RtItem (Get-RtItems) 'A' '01/09/2026 10:00'
$okR = Restore-CalibBack $iR
$bR = @(Get-RtBaks)
Chk 'R5j' ($iR -and [string]$iR.File -eq $old -and $okR -and (Test-Path -LiteralPath $old) -and $bR.Count -eq 11 -and @($script:Log | Where-Object { $_ -like 'Ancienne sauvegarde de configuration supprimée*' }).Count -eq 0) "copie lue, la plus ancienne des dix copies .ref- : jamais supprimee par la rotation de ce retour ($($bR.Count) copies)"
$script:TNow = New-Object datetime(2026, 9, 21, 10, 0, 0)
Set-Rt 'A|long' (New-Cv 'A' 'long' '21/09/2026 09:00' 1)
$bk2 = Backup-ConfigBeforeRef @('A|long') 'back'
$bR2 = @(Get-RtBaks)
Chk 'R5k' ($bk2 -and -not (Test-Path -LiteralPath $old) -and $bR2.Count -eq 10) 'effet de la rotation, a dire : sans copie protegee, chaque retour compte parmi les dix copies .ref- et la plus ancienne est supprimee'
# Autre calcul, courbe en attente du choix
Reset-Rt 'r5o'
Set-Rt '0|long' (New-Cv '0' 'long' '01/09/2026 10:00' 1 '12.9')
[void](Save-RtCopy 'calib-12.9-avant-v12.10.bak' (New-Object datetime(2026, 9, 2, 10, 0, 0)))
$script:DriveCurves.Remove('0|long')
$script:OldCalib = @{ Curves = [ordered]@{ '0|long' = (New-Cv '0' 'long' '20/08/2026 10:00' 5 '12.8') }; Std = $null; Long = '0=150'; Levels = @{}; Bak = $null; P0 = $null; P1 = $null }
$iO5 = Find-RtItem (Get-RtItems) '0' '01/09/2026 10:00'
$fO5 = Get-CalibBackInfo $iO5
$okO = Restore-CalibBack $iO5
$cvO = Get-DriveCurve '0' 'long'
# Relecture de L7 (point F/m5) : la courbe en attente du choix n est plus citee parmi les courbes « en place remplacees »
# (elle n est pas en place) mais dans une phrase a part ; attendu adapte dans le meme commit
Chk 'R5l' ($fO5.OtherCalc -and (@($fO5.Pending) -join ',') -ceq '0|long' -and (@($fO5.Backup) -join ',') -ceq '0|long' -and $fO5.Text.Contains('Calcul v12.9, autre que le calcul actuel (v12.10) : ces courbes seront conservées telles quelles') -and $fO5.Text.Contains("Aucune courbe en place n'est remplacée.") -and $fO5.Text.Contains("Courbes en attente du choix « garder ou recalibrer » retirées de l'attente : Long track 1,89 us (commune), lecteur 0.") -and -not $fO5.Text.Contains('Courbes en place remplacées')) 'detail : autre calcul ; courbe en attente du choix citee a part, jamais comme courbe en place remplacee ; copiee avant le retour (Backup)'
Chk 'R5m' ($okO -and [string]$cvO.KeptFor -eq '12.10' -and (Test-CurveCalcOk $cvO) -and (Get-CurveCalcText $cvO) -ceq 'v12.9, conservé (calcul actuel v12.10)' -and $null -eq $script:OldCalib -and @($script:Log | Where-Object { $_ -like '*(calibration du 01/09/2026 10:00, calcul v12.9, conservé (calcul actuel v12.10))*' }).Count -eq 1) 'autre calcul : rétablie comme courbe conservee (KeptFor, Test-CurveCalcOk vrai, jamais presentee comme du calcul actuel) ; retiree de l attente du choix'
# Cle en place et en attente du choix a la fois (recalibree pendant la session) : remplacee, retiree de l attente
Reset-Rt 'r5p'
Set-Rt '0|std' (New-Cv '0' 'std' '01/09/2026 10:00' 1)
[void](Save-RtCopy 'ref-std-20260901-1000.bak' (New-Object datetime(2026, 9, 2, 10, 0, 0)))
Set-Rt '0|std' (New-Cv '0' 'std' '10/09/2026 10:00' 4)
$script:OldCalib = @{ Curves = [ordered]@{ '0|std' = (New-Cv '0' 'std' '20/08/2026 10:00' 5 '12.8'); '0|long' = (New-Cv '0' 'long' '20/08/2026 11:00' 6 '12.8') }; Std = $null; Long = $null; Levels = @{}; Bak = $null; P0 = $null; P1 = $null }
$iP = Find-RtItem (Get-RtItems) '0' '01/09/2026 10:00'
$fP = Get-CalibBackInfo $iP
$okP = Restore-CalibBack $iP
Chk 'R5n' ((@($fP.Replace) -join ',') -ceq '0|std' -and (@($fP.Pending) -join ',') -ceq '0|std' -and $fP.Text.Contains('Courbes en place remplacées : Standard 2 us (commune), lecteur 0.') -and $okP -and $script:OldCalib -and (@($script:OldCalib.Curves.Keys) -join ',') -ceq '0|long' -and [string](Get-DriveCurve '0' 'std').Date -eq '01/09/2026 10:00') 'cle en place et en attente du choix : citee une fois parmi les courbes remplacees, retiree de l attente ; les autres courbes en attente restent'
# Relecture de L7 (point F/B1) : niveaux de la calibration rapide mis de cote avec une courbe en attente du choix que le
# retour retire de l attente : repris dans LevelShifts, comme avec « Conserver ces courbes », et toujours ecrits par les
# instructions reelles de Save-Config (Get-RtSavedLevels)
Reset-Rt 'r5q'
Set-Rt '0|long' (New-Cv '0' 'long' '01/09/2026 10:00' 1 '12.9')
[void](Save-RtCopy 'calib-12.9-avant-v12.10.bak' (New-Object datetime(2026, 9, 2, 10, 0, 0)))
$script:DriveCurves.Remove('0|long'); Sync-PrecompCurves
$lvQ = @{ RefKey = 'long'; Tag = 'c|0|1'; Drive = '0'; Date = '03/09/2026 10:00'; RefDate = '01/09/2026 10:00'; Delta = 5 }
$script:OldCalib = @{ Curves = [ordered]@{ '0|long' = (New-Cv '0' 'long' '01/09/2026 10:00' 1 '12.9') }; Std = $null; Long = $null; Levels = @{ 'long|c|0|1' = $lvQ }; Bak = $null; P0 = $null; P1 = $null }
$svQ0 = Get-RtSavedLevels
$okQ = Restore-CalibBack (Find-RtItem (Get-RtItems) '0' '01/09/2026 10:00')
$svQ1 = Get-RtSavedLevels
Chk 'R5o' ($okQ -and $null -eq $script:OldCalib -and [object]::ReferenceEquals($script:LevelShifts['long|c|0|1'], $lvQ) -and @($svQ0).Count -eq 1 -and @($svQ1).Count -eq 1 -and [string]@($svQ1)[0].refDate -eq '01/09/2026 10:00') "courbe en attente du choix retablie : ses niveaux de la calibration rapide sont repris (LevelShifts), comme avec « Conserver ces courbes » ; niveaux ecrits par Save-Config : $(@($svQ0).Count) avant, $(@($svQ1).Count) apres"
Reset-Rt 'r5s'
Set-Rt '0|long' (New-Cv '0' 'long' '01/09/2026 10:00' 1 '12.9')
[void](Save-RtCopy 'calib-12.9-avant-v12.10.bak' (New-Object datetime(2026, 9, 2, 10, 0, 0)))
$script:DriveCurves.Remove('0|long'); Sync-PrecompCurves
$lvL = @{ RefKey = 'long'; Tag = 'c|0|1'; Drive = '0'; Date = '03/09/2026 10:00'; RefDate = '01/09/2026 10:00'; Delta = 5 }
$lvS = @{ RefKey = 'std'; Tag = 'c|0|1'; Drive = '0'; Date = '03/09/2026 11:00'; RefDate = '01/09/2026 11:00'; Delta = 3 }
$script:OldCalib = @{ Curves = [ordered]@{ '0|long' = (New-Cv '0' 'long' '01/09/2026 10:00' 1 '12.9'); '0|std' = (New-Cv '0' 'std' '01/09/2026 11:00' 2 '12.9') }; Std = $null; Long = $null
                      Levels = @{ 'long|c|0|1' = $lvL; 'std|c|0|1' = $lvS }; Bak = $null; P0 = $null; P1 = $null }
$svS0 = Get-RtSavedLevels
$okS = Restore-CalibBack (Find-RtItem (Get-RtItems) '0' '01/09/2026 10:00')
$svS1 = Get-RtSavedLevels
Chk 'R5p' ($okS -and $script:OldCalib -and (@($script:OldCalib.Curves.Keys) -join ',') -ceq '0|std' -and (@($script:OldCalib.Levels.Keys) -join ',') -ceq 'std|c|0|1' -and [object]::ReferenceEquals($script:LevelShifts['long|c|0|1'], $lvL) -and -not $script:LevelShifts.ContainsKey('std|c|0|1') -and @($svS0).Count -eq 2 -and @($svS1).Count -eq 2) "deux courbes en attente du choix, retour sur l une : ses niveaux passent dans LevelShifts, ceux de l autre restent mis de cote ; niveaux ecrits par Save-Config : $(@($svS0).Count) avant, $(@($svS1).Count) apres (aucun perdu)"
$script:TNow = $t0

# ================================================================ R6 aller et retour
'--- R6 : aller et retour (motif back, suffixe -r, aucune copie ecrasee)'
Reset-Rt 'r6'
Set-Rt 'A|std' (New-Cv 'A' 'std' '01/10/2026 10:00' 0); Set-Rt '0|long' (New-Cv '0' 'long' '01/10/2026 11:00' 2)
$script:TNow = New-Object datetime(2026, 10, 5, 10, 0, 0)
[void](Save-Config); $cO = Backup-ConfigBeforeRef @('A|std') 'replace'
Set-Rt 'A|std' (New-Cv 'A' 'std' '05/10/2026 10:00' 7)
$script:LevelShifts = @{ 'std|c|0|1' = @{ RefKey = 'std'; Tag = 'c|0|1'; Drive = 'A'; Date = '05/10/2026 11:00'; RefDate = '05/10/2026 10:00'; Delta = 3 } }
$script:LevelBrands = @(@{ Brand = 'Sony'; Drive = 'A'; RefDate = '05/10/2026 10:00'; K = 1.05 }); $script:ContentMeasures = @(@{ Drive = 'A'; K = 0.95; Date = '05/10/2026 12:00' }); $script:TargetDrives = @{ A = '0' }
[void](Save-Config)
$start = Get-RtStore; $hStart = Get-RtHashes; $othersStart = Get-RtOthers
$cfgStart = [System.IO.File]::ReadAllText([string]$script:ConfigFile, [System.Text.Encoding]::UTF8)
$script:TNow = New-Object datetime(2026, 10, 6, 9, 0, 0)
$go = Restore-CalibBack (Find-RtItem (Get-RtItems) 'A' '01/10/2026 10:00')
$hMid = Get-RtHashes; $midStore = Get-RtStore
$script:TNow = New-Object datetime(2026, 10, 6, 9, 5, 0)
$iBack = Find-RtItem (Get-RtItems) 'A' '05/10/2026 10:00'
$back = Restore-CalibBack $iBack
$hEnd = Get-RtHashes; $baks6 = @(Get-RtBaks)
$cfgEnd = [System.IO.File]::ReadAllText([string]$script:ConfigFile, [System.Text.Encoding]::UTF8)
Chk 'R6a' ($go -and $midStore -cne $start -and $iBack -and [string]$iBack.FileName -eq 'GreaseweazleGUI.json.ref-std-20261005-1000.bak' -and $back -and (Get-RtStore) -ceq $start -and $cfgEnd -ceq $cfgStart -and (Get-RtOthers) -ceq $othersStart) 'retour, puis retour depuis la copie d avant le retour (ref-std-20261005-1000.bak) : magasin, configuration enregistree (courbes et vue) et autres donnees identiques a l etat de depart'
Chk 'R6b' (@($hStart.Keys | Where-Object { $hEnd[$_] -cne $hStart[$_] }).Count -eq 0 -and @($hMid.Keys | Where-Object { $hEnd[$_] -cne $hMid[$_] }).Count -eq 0 -and $hEnd.ContainsKey([System.IO.Path]::GetFileName($cO))) "copie d origine ($([System.IO.Path]::GetFileName($cO))) intacte, aucune copie ecrasee : $($baks6 -join ', ')"
Chk 'R6c' ($baks6 -contains 'GreaseweazleGUI.json.ref-std-20261001-1000-r20261006-090500.bak' -and $baks6.Count -eq 3) 'la copie d avant le second retour, de meme nom calcule que la copie d origine, prend le suffixe -r<date de la copie>'
$script:TNow = New-Object datetime(2026, 10, 6, 9, 5, 0)
$hPre = Get-RtHashes
$bx = Backup-ConfigBeforeRef @('A|std') 'back'
Chk 'R6d' ([System.IO.Path]::GetFileName([string]$bx) -ceq 'GreaseweazleGUI.json.ref-std-20261005-1000-r20261006-090500.bak') "nom calcule deja pris (copie du 05/10) : suffixe -r<AAAAMMJJ-HHmmss> avant .bak ($([System.IO.Path]::GetFileName([string]$bx)))"
$bx2 = Backup-ConfigBeforeRef @('A|std') 'back'
$bx3 = Backup-ConfigBeforeRef @('A|std') 'back'
$hRep = Get-RtHashes
Chk 'R6e' ([System.IO.Path]::GetFileName([string]$bx2) -ceq 'GreaseweazleGUI.json.ref-std-20261005-1000-r20261006-090500-2.bak' -and [System.IO.Path]::GetFileName([string]$bx3) -ceq 'GreaseweazleGUI.json.ref-std-20261005-1000-r20261006-090500-3.bak' -and @($hPre.Keys | Where-Object { $hRep[$_] -cne $hPre[$_] }).Count -eq 0) "copies suivantes de la meme seconde : -2, puis -3 ($([System.IO.Path]::GetFileName([string]$bx2)), $([System.IO.Path]::GetFileName([string]$bx3))) ; aucune copie existante modifiee"
$script:TNow = New-Object datetime(2026, 10, 7, 9, 0, 0)
[void](Save-Config); $rp1 = Backup-ConfigBeforeRef @('A|std') 'replace'; $rp2 = Backup-ConfigBeforeRef @('A|std') 'replace'
Chk 'R6f' ($rp1 -eq $rp2 -and (Test-Path -LiteralPath $rp1)) 'motif replace inchange : une copie de meme nom est remplacee (regle de la 12.8)'
$script:TNow = $t0

# ================================================================ R7 Start-CalibBack
'--- R7 : Start-CalibBack (240) et fenetre (250, construite sans affichage)'
Reset-Rt 'r7'
Set-Rt 'A|std' (New-Cv 'A' 'std' '01/10/2026 10:00' 0)
[void](Save-RtCopy 'ref-std-20261001-1000.bak' (New-Object datetime(2026, 10, 2, 10, 0, 0)))
Set-Rt 'A|std' (New-Cv 'A' 'std' '05/10/2026 10:00' 4)
${function:Rt-RealFiles} = ${function:Get-CalibBackFiles}
$script:NFiles = 0
function Get-CalibBackFiles([int]$Max = 40) { $script:NFiles++; Rt-RealFiles $Max }
$script:Busy = 'calib'; $script:NDlg = 0
$r7a = Start-CalibBack
Chk 'R7a' (-not $r7a -and $script:Msgs.Count -eq 1 -and $script:Msgs[0].Text -ceq "Opération en cours : attendre la fin de la calibration ou de l'écriture." -and $script:NFiles -eq 0 -and $script:NDlg -eq 0) 'operation en cours : message existant, aucune copie lue, aucune fenetre'
$script:Busy = ''; $script:Msgs.Clear(); $script:CalRedo = @{ Stage = 'confirm' }
$r7b = Start-CalibBack
$script:CalRedo = $null
Chk 'R7b' (-not $r7b -and $script:Msgs.Count -eq 1 -and $script:Msgs[0].Text -ceq "Calibration B en cours ou en attente de décision : terminez-la d'abord." -and $script:NFiles -eq 0) 'calibration B en attente de decision : refus, aucune copie lue'
$script:Msgs.Clear(); $script:DlgPick = -1
[void](Write-RtFile 'abime.bak' '{"write":' (New-Object datetime(2026, 10, 3, 10, 0, 0)))
[void](Write-RtFile 'sans-courbe.bak' '{"global":{"drive":"A"}}' (New-Object datetime(2026, 10, 3, 11, 0, 0)))
$r7c = Start-CalibBack
$st7 = $script:LastDlg
Chk 'R7c' (-not $r7c -and $script:NDlg -eq 1 -and @($script:Log | Where-Object { $_ -like 'Copie de la configuration illisible, ignorée : *GreaseweazleGUI.json.abime.bak (*).' }).Count -eq 1 -and $st7.Skip.Height -gt 0 -and $st7.Skip.Text -ceq 'Copies illisibles ou sans courbe, non listées : GreaseweazleGUI.json.sans-courbe.bak, GreaseweazleGUI.json.abime.bak.') 'copie illisible : une ligne de journal ; copies illisibles ou sans courbe citees au pied de la fenetre ; « Fermer » : rien n est fait'
$lv = $st7.Lv; $inf0 = Get-CalibBackInfo @($st7.Items)[0]
Chk 'R7d' ($st7.Dlg.Name -eq 'frmCalibBack' -and $lv.Name -eq 'lvCalBack' -and $lv.Items.Count -eq 1 -and $lv.Columns.Count -eq 7 -and $lv.Items[0].SubItems[1].Text -ceq $inf0.DriveText -and $lv.Items[0].Text -eq '01/10/2026 10:00' -and $lv.Items[0].SubItems[3].Text -ceq 'commune' -and $lv.Items[0].SubItems[4].Text -ceq 'test fin' -and $lv.Items[0].SubItems[6].Text -ceq 'ref-std-20261001-1000.bak') 'fenetre : une ligne, sept colonnes, colonne « Lecteur » rendue par Get-CalibBackInfo'
Chk 'R7e' (-not $st7.Go.Enabled -and $st7.Dlg.CancelButton -eq $st7.Close -and $null -eq $st7.Dlg.AcceptButton -and $st7.Dlg.ActiveControl -eq $st7.Close -and $st7.Info.Text -eq '' -and $st7.Go.Name -eq 'btnCalBackGo' -and $st7.Close.Name -eq 'btnCalBackClose' -and $st7.Info.Name -eq 'lblCalBackInfo') '« Retablir » inactif sans selection ; « Fermer » : CancelButton et focus ; aucun AcceptButton'
Update-CalibBackDialog $st7 0
Chk 'R7f' ($st7.Go.Enabled -and $st7.Info.Text -ceq $inf0.Text) 'selection : detail et bouton tires de Get-CalibBackInfo'
# Relecture de L7 (point F/m4) : colonne « Calcul » rendue par Get-CalibBackInfo (CalcText), autre calcul compris
Chk 'R7l' ($lv.Items[0].SubItems[5].Text -ceq [string]$inf0.CalcText -and [string]$inf0.CalcText -ceq 'v12.10' -and [string]$fO5.CalcText -ceq 'v12.9 (autre calcul)') "colonne « Calcul » : texte de Get-CalibBackInfo (« $($inf0.CalcText) » ; autre calcul : « $($fO5.CalcText) »)"
# Largeurs : titres des colonnes, date et texte des cellules courtes entiers, en francais et en anglais (police de la
# fenetre, contrôles jamais affiches) ; le detail tient dans sa hauteur
$wBad = @()
foreach ($lg in @('fr', 'en')) {
    $script:Lang = $lg
    $stW = New-CalibBackDialog @($st7.Items) 1 @()
    $cw = @($stW.Lv.Columns | ForEach-Object { [int]$_.Width })
    $i = 0
    foreach ($c in @($stW.Lv.Columns)) { if ([System.Windows.Forms.TextRenderer]::MeasureText([string]$c.Text, $stW.Dlg.Font).Width + 12 -gt [int]$c.Width) { $wBad += "$lg titre $($c.Text)" }; $i++ }
    $cells = @(@(0, '30/12/2026 23:59'), @(1, 'TEAC FD-235HF n°2'), @(1, 'A → 0'), @(2, (Get-CalibFamilyName 'long')), @(2, (Get-CalibFamilyName 'hd')), @(3, (T 'par tête')), @(3, (T 'commune')),
               @(4, (T 'test standard')), @(5, ((T '{0} (autre calcul)') -f 'v12.10')), @(6, 'ref-long+std-20261001-1000.bak'), @(6, 'calib-12.9-avant-v12.10.bak'), @(6, 'lecteurs-20261105-095900.bak'))
    foreach ($ce in $cells) { if ([System.Windows.Forms.TextRenderer]::MeasureText([string]$ce[1], $stW.Dlg.Font).Width + 12 -gt $cw[[int]$ce[0]]) { $wBad += "$lg cellule $($ce[1])" } }
    $hInfo = [System.Windows.Forms.TextRenderer]::MeasureText([string](Get-CalibBackInfo @($st7.Items)[0]).Text, $stW.Dlg.Font, (New-Object System.Drawing.Size($stW.Info.Width, 10000)), ([System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix)).Height
    if ($hInfo -gt $stW.Info.Height) { $wBad += "$lg detail $hInfo px pour $($stW.Info.Height)" }
    $stW.Dlg.Dispose()
}
$script:Lang = 'fr'
Chk 'R7j' ($wBad.Count -eq 0) "colonnes ($((@($cw) | ForEach-Object { "$_" }) -join ', ') px) : titres, dates et cellules courtes entiers, detail dans sa hauteur, francais et anglais ; trop larges : $($wBad -join ' | ')"
$script:Log.Clear(); $script:DlgPick = 0
$r7g = Start-CalibBack
Chk 'R7g' ($r7g -and [string](Get-DriveCurve 'A' 'std').Date -eq '01/10/2026 10:00' -and $script:Confirms.Count -eq 0) 'ligne choisie et « Retablir » : retour fait, sans confirmation (lien certain)'
$script:Msgs.Clear(); $script:DlgPick = -1
$r7h = Start-CalibBack
Chk 'R7h' (-not $r7h -and $script:Msgs.Count -eq 0 -and @($script:LastDlg.Items).Count -eq 1 -and [string]@($script:LastDlg.Items)[0].Date -eq '05/10/2026 10:00') 'apres le retour, la calibration remplacee est listee depuis la copie d avant le retour : un retour s annule de la meme facon'
Reset-Rt 'r7v'
Set-Rt 'A|std' (New-Cv 'A' 'std' '01/10/2026 10:00' 0)
[void](Save-RtCopy 'ref-std-20261001-1000.bak' (New-Object datetime(2026, 10, 2, 10, 0, 0)))
$script:NDlg = 0
$r7i = Start-CalibBack
Chk 'R7i' (-not $r7i -and $script:NDlg -eq 0 -and $script:Msgs.Count -eq 1 -and $script:Msgs[0].Text -ceq ('Aucune calibration précédente à rétablir : aucune des 1 copie(s) de la configuration lue(s) dans « {0} » ne contient de courbe différente des courbes en place.' -f (Split-Path -Parent ([string]$script:ConfigFile)))) 'aucune ligne (courbe identique a celle en place) : message 9, aucune fenetre'
# Relecture de L7 (point F/m6) : aucune copie dans le dossier : message qui le dit, sans « aucune des 0 copie(s) »
Reset-Rt 'r7w'
Set-Rt 'A|std' (New-Cv 'A' 'std' '01/10/2026 10:00' 0)
$script:NDlg = 0
$r7k = Start-CalibBack
Chk 'R7k' (-not $r7k -and $script:NDlg -eq 0 -and $script:Msgs.Count -eq 1 -and $script:Msgs[0].Text -ceq ('Aucune calibration précédente à rétablir : le dossier « {0} » ne contient aucune copie de la configuration (« GreaseweazleGUI.json.….bak »).' -f (Split-Path -Parent ([string]$script:ConfigFile)))) 'aucune copie de la configuration : message propre, aucune fenetre'
${function:Get-CalibBackFiles} = ${function:Rt-RealFiles}

# ================================================================ A lecteurs enregistres
'--- A : lecteurs enregistres (Resolve-DriveOfEra, 112)'
function Get-RtEra($recs) { $l = @(); foreach ($r in @($recs)) { $l += ,([ordered]@{ id = $r.Id; name = $r.Name; conn = $r.Conn; created = $r.Created; from = $r.From; at = $r.At }) }; return [ordered]@{ list = $l; last = [ordered]@{} } }
function Write-RtEraCopy([string]$suffix, $curves, $era, [datetime]$when) {
    # Copie factice : bloc driveCurves (cle de magasin -> courbe), bloc drives de l epoque ($null : sans bloc)
    $dc = [ordered]@{}; foreach ($k in @($curves.Keys)) { $dc[$k] = ConvertTo-CurveConfig $curves[$k] }
    $o = [ordered]@{ global = [ordered]@{ drive = 'A' }; write = [ordered]@{ calibCalc = $script:CalibCalc; driveCurves = $dc } }
    if ($null -ne $era) { $o['drives'] = $era }
    return (Write-RtFile $suffix ($o | ConvertTo-Json -Depth 8) $when)
}
$recSony = New-RtRec 'Sony MPF920' 'A' 'L20261105100000-01' '2026-11-05 10:00:00' 'A' '2026-11-05 10:00:00'
# A1 : copie d avant le registre (lettres seules), avec et sans attribution posterieure
Reset-Rt 'a1'
[void](Write-RtEraCopy 'ref-std-20261001-1000.bak' ([ordered]@{ 'A|std' = (New-Cv 'A' 'std' '01/10/2026 10:00' 0) }) $null (New-Object datetime(2026, 10, 2, 10, 0, 0)))
$fa = Get-CalibBackInfo (Find-RtItem (Get-RtItems) 'A' '01/10/2026 10:00')
Chk 'A1a' ($fa.Ok -and $fa.Sure -and $fa.Drive -eq 'A' -and $fa.DriveText -eq 'A' -and -not $fa.NeedCheck) 'copie d avant le registre, aucun lecteur enregistre : courbe de A, lien certain (12.10)'
Set-RtReg @($recSony)
Set-Rt 'Sony MPF920|std' (New-Cv 'Sony MPF920' 'std' '06/11/2026 10:00' 5)
$iA1 = Find-RtItem (Get-RtItems) 'A' '01/10/2026 10:00'
$fa = Get-CalibBackInfo $iA1
Chk 'A1b' ($fa.Ok -and -not $fa.Sure -and $fa.NeedCheck -and $fa.Drive -eq 'Sony MPF920' -and $fa.DriveText -ceq "Sony MPF920 (à l'époque : A)" -and $fa.Text.Contains('Cette calibration a été faite sur la connexion A, avant que son lecteur soit enregistré sous le nom « Sony MPF920 » : ne la rétablissez que si elle a été faite avec ce lecteur.')) 'attribution posterieure de A au Sony : courbe reliee au Sony, lien incertain, deux noms montres, phrase d avertissement'
$stA1 = Get-RtStore
Chk 'A1c' (-not (Restore-CalibBack $iA1) -and (Get-RtStore) -ceq $stA1) 'ligne incertaine : Restore-CalibBack refuse sans la case (-Confirmed), rien modifie'
$script:DlgPick = 0; $script:ConfirmAnswer = $false
$rA1 = Start-CalibBack
Chk 'A1d' (-not $rA1 -and $script:Confirms.Count -eq 1 -and $script:Confirms[0].Heading -ceq 'Rétablir cette calibration pour le lecteur « Sony MPF920 » ?' -and $script:Confirms[0].Check -ceq "Cette calibration a bien été faite avec le lecteur « Sony MPF920 » (à l'époque : A)" -and $script:Confirms[0].Text -ceq $fa.Text -and (Get-RtStore) -ceq $stA1) 'confirmation a case qui nomme le lecteur d aujourd hui et celui de l epoque ; case non cochee (refus) : rien modifie'
$script:ConfirmAnswer = $true
$rA1 = Start-CalibBack
$cvS = Get-DriveCurve 'Sony MPF920' 'std'
Chk 'A1e' ($rA1 -and [string]$cvS.Date -eq '01/10/2026 10:00' -and [string]$cvS.Drive -eq 'Sony MPF920' -and $null -eq (Get-DriveCurve 'A' 'std') -and (@(Get-DriveCurveKeys) -join ',') -ceq 'Sony MPF920|std') 'case cochee : courbe retablie sous le Sony, champ Drive reecrit, rien sous A'
$recOld = New-RtRec 'Sony MPF920' 'A' 'L20260901100000-01' '2026-09-01 10:00:00' 'A' '2026-09-01 10:00:00'
Set-RtReg @($recOld)
$fa = Get-CalibBackInfo (Find-RtItem (Get-RtItems) 'A' '01/10/2026 10:00')
Chk 'A1f' ($fa.Ok -and $fa.Sure -and $fa.Drive -eq 'A' -and $fa.DriveText -eq 'A') 'attribution anterieure a la courbe : la courbe reste au lecteur non enregistre de A, lien certain'
# A2 : lecteur renomme depuis ; A4 : courbe croisee dont un seul cote a change de nom
Reset-Rt 'a2'
$eraS = Get-RtEra @(New-RtRec 'Sony MPF920' 'A' 'L20261105100000-01' '2026-11-05 10:00:00' 'A' '2026-11-05 10:00:00')
[void](Write-RtEraCopy 'ref-std-20261110-1000.bak' ([ordered]@{ 'Sony MPF920|std' = (New-Cv 'Sony MPF920' 'std' '10/11/2026 10:00' 1); 'Sony MPF920>0|std' = (New-Cv 'Sony MPF920' 'std' '11/11/2026 10:00' 3 '' '0') }) $eraS (New-Object datetime(2026, 11, 12, 10, 0, 0)))
Set-RtReg @(New-RtRec 'Sony MPF-920' 'A' 'L20261105100000-01' '2026-11-05 10:00:00' 'A' '2026-11-05 10:00:00')
$items2 = Get-RtItems
$fa = Get-CalibBackInfo (Find-RtItem $items2 'Sony MPF920' '10/11/2026 10:00')
Chk 'A2a' ($fa.Ok -and $fa.Sure -and $fa.Drive -eq 'Sony MPF-920' -and $fa.DriveText -ceq "Sony MPF-920 (à l'époque : Sony MPF920)") 'lecteur renomme depuis : meme identifiant, relie avec certitude, deux noms montres'
$fx = Get-CalibBackInfo (Find-RtItem $items2 'Sony MPF920>0' '11/11/2026 10:00')
Chk 'A4a' ($fx.Ok -and $fx.Sure -and $fx.Drive -eq 'Sony MPF-920>0' -and $fx.DriveText -ceq "Sony MPF-920 (à l'époque : Sony MPF920) → 0") 'courbe croisee dont un seul cote a change de nom : chaque cote resolu, « Sony MPF-920 (a l epoque : Sony MPF920) → 0 »'
[void](Restore-CalibBack (Find-RtItem $items2 'Sony MPF920' '10/11/2026 10:00'))
[void](Restore-CalibBack (Find-RtItem (Get-RtItems) 'Sony MPF920>0' '11/11/2026 10:00'))
$cx = Get-DriveCurve 'Sony MPF-920>0' 'std'
# 12.11 (CI sous Windows PowerShell 5.1, run du 14/11/2026) : A2b compare l ensemble des cles, trie des deux cotes par la
# meme comparaison : l ordre de Get-DriveCurveKeys (Sort-Object, culture) differe entre 5.1 et 7 pour « >0| » et « | »
Chk 'A2b' ([string](Get-DriveCurve 'Sony MPF-920' 'std').Drive -eq 'Sony MPF-920' -and [string]$cx.Drive -eq 'Sony MPF-920' -and [string]$cx.Target -eq '0' -and (@(Get-DriveCurveKeys | Sort-Object { [string]$_ } -CaseSensitive | ForEach-Object { [string]$_ }) -join ',') -ceq (@(@('Sony MPF-920>0|std', 'Sony MPF-920|std') | Sort-Object { [string]$_ } -CaseSensitive) -join ',')) 'retablies sous le nom d aujourd hui : cles « Sony MPF-920|std » et « Sony MPF-920>0|std », champs Drive et Target reecrits ; rien sous l ancien nom'
# A3 : lecteur supprime depuis ; recree sous le meme nom (autre fiche « L... »)
Reset-Rt 'a3'
[void](Write-RtEraCopy 'ref-std-20261110-1000.bak' ([ordered]@{ 'Sony MPF920|std' = (New-Cv 'Sony MPF920' 'std' '10/11/2026 10:00' 1) }) $eraS (New-Object datetime(2026, 11, 12, 10, 0, 0)))
$i3 = Find-RtItem (Get-RtItems) 'Sony MPF920' '10/11/2026 10:00'
$fa = Get-CalibBackInfo $i3
$st3 = Get-RtStore
Chk 'A3a' (-not $fa.Ok -and $fa.DriveText -ceq 'Sony MPF920 (lecteur supprimé depuis)' -and $fa.Text.Contains("Le lecteur « Sony MPF920 » de cette copie n'est plus enregistré : cette calibration ne peut pas être rétablie.") -and -not $fa.Text.Contains('Les niveaux de la calibration rapide') -and -not (Restore-CalibBack $i3 -Confirmed) -and (Get-RtStore) -ceq $st3) 'lecteur supprime depuis : ligne listee, non retablissable (meme avec -Confirmed), rien modifie'
Set-RtReg @(New-RtRec 'Sony MPF920' 'A' 'L20261115100000-01' '2026-11-15 10:00:00')
$fa = Get-CalibBackInfo (Find-RtItem (Get-RtItems) 'Sony MPF920' '10/11/2026 10:00')
Chk 'A3b' (-not $fa.Ok -and $fa.DriveText -ceq 'Sony MPF920 (lecteur supprimé depuis)') 'lecteur supprime puis recree sous le meme nom (fiche « L... » d un autre identifiant) : non retablissable avec la fiche de l epoque'
$script:DlgPick = -1
[void](Start-CalibBack)
Update-CalibBackDialog $script:LastDlg 0
Chk 'A3c' (-not $script:LastDlg.Go.Enabled -and $script:LastDlg.Info.Text -ceq $fa.Text -and $script:LastDlg.Lv.Items[0].ForeColor -eq [System.Drawing.Color]::Gray) 'fenetre : ligne grisee, « Retablir » inactif, detail qui dit pourquoi'
# A5 : registre vide puis memes noms recrees dans un autre ordre
Reset-Rt 'a5'
$era2 = Get-RtEra @((New-RtRec 'Sony MPF920' 'A' 'L20261001100000-01' '2026-10-01 10:00:00'), (New-RtRec 'TEAC FD-235HF' '0' 'L20261001100500-01' '2026-10-01 10:05:00'))
[void](Write-RtEraCopy 'ref-std-20261010-1000.bak' ([ordered]@{ 'Sony MPF920|std' = (New-Cv 'Sony MPF920' 'std' '10/10/2026 10:00' 1); 'TEAC FD-235HF|std' = (New-Cv 'TEAC FD-235HF' 'std' '10/10/2026 11:00' 2) }) $era2 (New-Object datetime(2026, 10, 12, 10, 0, 0)))
Set-RtReg @((New-RtRec 'TEAC FD-235HF' 'A' 'L20261101100000-01' '2026-11-01 10:00:00'), (New-RtRec 'Sony MPF920' '0' 'L20261101100500-01' '2026-11-01 10:05:00'))
$i5 = @(Get-RtItems)
Chk 'A5a' ($i5.Count -eq 2 -and @($i5 | Where-Object { (Get-CalibBackInfo $_).Ok }).Count -eq 0 -and @($i5 | ForEach-Object { (Get-CalibBackInfo $_).DriveText } | Sort-Object) -join ',' -ceq 'Sony MPF920 (lecteur supprimé depuis),TEAC FD-235HF (lecteur supprimé depuis)') 'registre vide puis noms recrees dans un autre ordre : aucune ligne reliee a un lecteur, aucune a un lecteur d un autre nom'
# A6 : nom sans fiche dans la copie (copie sans bloc drives), fiche d aujourd hui creee apres ou avant la courbe
Reset-Rt 'a6'
[void](Write-RtEraCopy 'ref-std-20261010-1000.bak' ([ordered]@{ 'Sony MPF920|std' = (New-Cv 'Sony MPF920' 'std' '10/10/2026 10:00' 1) }) $null (New-Object datetime(2026, 10, 12, 10, 0, 0)))
Set-RtReg @(New-RtRec 'Sony MPF920' 'A' 'L20261115100000-01' '2026-11-15 10:00:00')
$fa = Get-CalibBackInfo (Find-RtItem (Get-RtItems) 'Sony MPF920' '10/10/2026 10:00')
Chk 'A6a' ($fa.Ok -and $fa.NeedCheck -and $fa.Drive -eq 'Sony MPF920' -and $fa.DriveText -eq 'Sony MPF920' -and $fa.Text.Contains("Cette calibration porte le nom « Sony MPF920 », mais le lecteur enregistré aujourd'hui sous ce nom l'a été après elle : ne la rétablissez que si elle a été faite avec ce lecteur.")) 'nom sans fiche dans la copie, fiche creee apres la courbe (supprime puis recree) : lien incertain, phrase propre, confirmation demandee'
Set-RtReg @(New-RtRec 'Sony MPF920' 'A' 'L20260915100000-01' '2026-09-15 10:00:00')
$fa = Get-CalibBackInfo (Find-RtItem (Get-RtItems) 'Sony MPF920' '10/10/2026 10:00')
Chk 'A6b' ($fa.Ok -and $fa.Sure -and -not $fa.NeedCheck) 'fiche creee avant la courbe : lien certain'
# A7 : fiche refaite par Repair-DriveRegistry (identifiant « R... »)
Reset-Rt 'a7'
[void](Write-RtEraCopy 'ref-std-20261010-1000.bak' ([ordered]@{ 'Sony MPF920|std' = (New-Cv 'Sony MPF920' 'std' '10/10/2026 10:00' 1) }) $era2 (New-Object datetime(2026, 10, 12, 10, 0, 0)))
Set-Rt 'Sony MPF920|long' (New-Cv 'Sony MPF920' 'long' '01/10/2026 10:00' 4)
$rep = @(Repair-DriveRegistry)
$recR = Get-DriveRecord 'Sony MPF920'
$fa = Get-CalibBackInfo (Find-RtItem (Get-RtItems) 'Sony MPF920' '10/10/2026 10:00')
Chk 'A7a' (($rep -join ',') -eq 'Sony MPF920' -and [string]$recR.Id -clike 'R*' -and $fa.Ok -and $fa.NeedCheck -and $fa.Drive -eq 'Sony MPF920' -and $fa.Sides[0].Why -eq 'name-after') 'fiche refaite par Repair-DriveRegistry (« R... ») : reliee par le nom, creee apres la courbe : lien incertain'
# A10 : lien ambigu (le nom de l epoque est aujourd hui celui d une autre fiche)
Reset-Rt 'a10'
[void](Write-RtEraCopy 'ref-std-20261110-1000.bak' ([ordered]@{ 'Sony MPF920|std' = (New-Cv 'Sony MPF920' 'std' '10/11/2026 10:00' 1) }) $eraS (New-Object datetime(2026, 11, 12, 10, 0, 0)))
Set-RtReg @((New-RtRec 'Sony B' 'A' 'L20261105100000-01' '2026-11-05 10:00:00'), (New-RtRec 'Sony MPF920' '0' 'L20261116100000-01' '2026-11-16 10:00:00'))
$fa = Get-CalibBackInfo (Find-RtItem (Get-RtItems) 'Sony MPF920' '10/11/2026 10:00')
Chk 'A10' (-not $fa.Ok -and $fa.DriveText -eq 'Sony MPF920' -and $fa.Text.Contains("Le lecteur « Sony MPF920 » de cette copie ne peut pas être relié avec certitude à un lecteur d'aujourd'hui.")) 'nom de l epoque porte aujourd hui par une autre fiche : non retablissable, raison donnee'
# A9 : copie .lecteurs-<date>.bak lue comme les autres, avec le bloc drives de son epoque (liste vide comprise)
Reset-Rt 'a9'
[void](Write-RtEraCopy 'lecteurs-20261105-095900.bak' ([ordered]@{ 'A|std' = (New-Cv 'A' 'std' '01/11/2026 10:00' 1) }) ([ordered]@{ list = @(); last = [ordered]@{} }) (New-Object datetime(2026, 11, 5, 9, 59, 0)))
$b9 = Read-CalibBackup (@(Get-CalibBackFiles)[0])
$f9 = Get-CalibBackInfo (Find-RtItem (Get-RtItems) 'A' '01/11/2026 10:00')
Chk 'A9' ($b9.Ok -and $null -ne $b9.Drives -and @(Get-DriveBlockItems $b9.Drives).Count -eq 0 -and $f9.Ok -and $f9.Sure -and $f9.Text.Contains('Copie lue : GreaseweazleGUI.json.lecteurs-20261105-095900.bak')) 'copie .lecteurs-<date>.bak : lue comme les autres, bloc drives a liste vide relu'
$script:Lang = 'en'
$fe = Get-CalibBackInfo (Find-RtItem $items2 'Sony MPF920' '10/11/2026 10:00')
Reset-Rt 'a1e'
[void](Write-RtEraCopy 'ref-std-20261001-1000.bak' ([ordered]@{ 'A|std' = (New-Cv 'A' 'std' '01/10/2026 10:00' 0) }) $null (New-Object datetime(2026, 10, 2, 10, 0, 0)))
Set-RtReg @($recSony)
$script:Lang = 'en'
$fe2 = Get-CalibBackInfo (Find-RtItem (Get-RtItems) 'A' '01/10/2026 10:00')
$script:Lang = 'fr'
Chk 'A11' ($fe2.DriveText -ceq 'Sony MPF920 (at the time: A)' -and $fe2.Text.Contains('This calibration was made on connection A, before its drive was registered under the name "Sony MPF920": restore it only if it was made with this drive.')) "textes anglais du lien : $($fe2.DriveText)"

# ================================================================ R8 statique et documents
'--- R8 : bouton, « Effacer les calibrations », textes, documents'
$p520 = Get-RtModule '520'
$a520 = Get-RtAst $p520
$t520 = [System.IO.File]::ReadAllText($p520, [System.Text.Encoding]::UTF8)
$refs = @($a520.FindAll({ param($x) $x -is [System.Management.Automation.Language.VariableExpressionAst] -and $x.VariablePath.UserPath -eq 'btnWCalBack' }, $true) | Sort-Object { $_.Extent.StartOffset })
$create = @($a520.EndBlock.Statements | Where-Object { $_ -is $tAsg -and $_.Left.Extent.Text -eq '$btnWCalBack' })
Chk 'R8a' ($create.Count -eq 1 -and $create[0].Right.Extent.Text -ceq 'New-Object System.Windows.Forms.Button' -and $refs.Count -ge 6 -and $refs[0].Extent.StartOffset -eq $create[0].Left.Extent.StartOffset) "btnWCalBack cree une fois, avant tout autre usage ($($refs.Count) references)"
# 12.11 (lot L9, onglet Ecriture en trois etapes) : R8b et R8c adaptes a la place definitive des boutons (la geometrie
# provisoire du lot L7 est retiree) : retour et « Effacer les calibrations » en bas du cadre des options avancees, rangee
# de la calibration du cadre 2 elargie ; la disposition entiere est controlee par logic-ecriture-onglet (series V et S)
Chk 'R8b' ($t520.Contains("`$btnWCalBack.Name = 'btnWCalBack'; `$btnWCalBack.Text = (T 'Revenir à une calibration précédente…'); `$btnWCalBack.Location = '513,212'; `$btnWCalBack.Size = '34,34'") -and $t520.Contains("Set-Btn `$btnWCalBack 'History' -IconOnly") -and $t520.Contains('$btnWCalBack.Add_Click({ [void](Start-CalibBack) })') -and $t520.Contains('$lblWWarmMinU, $btnWCalBack, $btnWCalReset))')) 'bouton a icone seule (History) en 513,212, 34 x 34, clic : Start-CalibBack ; ajoute au cadre des options avancees, juste avant « Effacer les calibrations » (lot L9)'
Chk 'R8c' ($t520.Contains("`$cmbWCalMode.Location = '153,107'; `$cmbWCalMode.Width = 280; `$cmbWCalMode.DropDownWidth = 280") -and $t520.Contains("`$btnWCalib.Location = '441,102'") -and $t520.Contains("`$btnWCross.Location = '555,102'") -and $t520.Contains("`$btnWCalReset.Text = (T 'Effacer les calibrations'); `$btnWCalReset.Location = '555,212'; `$btnWCalReset.Size = '195,34'") -and $t520.Contains('$btnWCalReset.Add_Click({ Reset-CalibProfiles })')) 'place definitive (lot L9) : liste a 280 px, « Calibrer » en 441, calibration croisee en 555 ; « Effacer les calibrations » : nom, taille et action inchanges, en 555,212 dans le cadre des options avancees, a droite du bouton de retour'
# Infobulle reelle du bouton (instruction de 520), en francais et en anglais
$tip = New-Object System.Windows.Forms.ToolTip
$btnWCalBack = New-Object System.Windows.Forms.Button
$tipSt = @($a520.EndBlock.Statements | Where-Object { $_.Extent.Text.StartsWith('$tip.SetToolTip($btnWCalBack,') })
$script:ConfigFile = Join-Path $here 'GreaseweazleGUI.json'
# Instruction reelle ecrite dans un fichier de travail et chargee par dot-source, comme les fonctions
$genTip = Join-Path $here 'gen-infobulle.ps1'
[System.IO.File]::WriteAllText($genTip, ([string]$tipSt[0].Extent.Text + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
. $genTip
$tipFr = $tip.GetToolTip($btnWCalBack)
$script:Lang = 'en'; . $genTip; $tipEn = $tip.GetToolTip($btnWCalBack); $script:Lang = 'fr'
Chk 'R8d' ($tipSt.Count -eq 1 -and $tipFr.StartsWith("Revenir à une calibration précédente…`nListe les calibrations complètes gardées dans les copies de la configuration (fichiers « GreaseweazleGUI.json.….bak »") -and $tipEn.StartsWith("Return to a previous calibration…`nLists the full calibrations kept in the configuration copies (`"GreaseweazleGUI.json.….bak`" files")) 'infobulle : premiere ligne et explication, francais et anglais'
# Confirmation reelle de « Effacer les calibrations » (Reset-CalibProfiles), arretee a la question
Reset-Rt 'r8'
Set-Rt 'A|std' (New-Cv 'A' 'std' '01/10/2026 10:00' 0)
$script:MsgAnswer = 'No'
Reset-CalibProfiles
$m8 = if ($script:Msgs.Count) { [string]$script:Msgs[0].Text } else { '' }
Chk 'R8e' ($m8.Contains("L'application copie d'abord la configuration dans « GreaseweazleGUI.json.ref-….bak », dans le même dossier. Ensuite, « Revenir à une calibration précédente… » rétablit les courbes de cette copie, une calibration à la fois ; les niveaux, la mémoire par marque et les facteurs mesurés effacés ne reviennent qu'en remettant la copie à la place de « GreaseweazleGUI.json », application fermée.") -and -not $m8.Contains('ne peut pas annuler cet effacement') -and [string](Get-DriveCurve 'A' 'std').Date -eq '01/10/2026 10:00') 'confirmation de « Effacer les calibrations » : texte 14 (cle remplacee) ; « Non » : rien efface'
$t010 = [System.IO.File]::ReadAllText((Get-RtModule '010'), [System.Text.Encoding]::UTF8)
$t019 = [System.IO.File]::ReadAllText((Get-RtModule '019'), [System.Text.Encoding]::UTF8)
$allMods = (@(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Where-Object { $_.Name -notlike '01*' } | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8) }) -join "`n")
Chk 'R8f' (-not $t010.Contains('ne peut pas annuler cet effacement') -and -not $allMods.Contains('ne peut pas annuler cet effacement') -and $t019.Contains('# --- L7 : revenir a une calibration precedente') -and ($script:I18n.ContainsKey('par tête') -and $script:I18n['par tête'] -eq 'per-head')) 'cle de 010 (texte de la 12.8) retiree et plus employee ; section L7 de 019 ; « par tete » : cle existante (m5)'
# Textes anglais : chaque cle litterale de T() des fonctions du lot et du bouton a son entree, aucune redefinie
$lotFns = @(@('240', 'Get-CalibBackHeadsText'), @('240', 'Get-CalibBackTestText'), @('240', 'Get-CalibBackInfo'), @('240', 'Restore-CalibBack'), @('240', 'Start-CalibBack'), @('250', 'New-CalibBackDialog'), @('120', 'Backup-ConfigBeforeRef'), @('240', 'Reset-CalibProfiles'))
$keys8 = @()
foreach ($lf in $lotFns) {
    $fd = Get-RtFn $lf[0] $lf[1]
    foreach ($c in $fd.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'T' -and $x.CommandElements.Count -eq 2 -and $x.CommandElements[1] -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true)) { $keys8 += [string]$c.CommandElements[1].Value }
}
foreach ($c in $a520.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'T' -and $x.Extent.Text -match 'calibration précédente|Liste les calibrations complètes' }, $true)) { $keys8 += [string]$c.CommandElements[1].Value }
$keys8 = @($keys8 | Sort-Object -Unique)
$noEn = @($keys8 | Where-Object { -not $script:I18n.ContainsKey($_) })
Chk 'R8g' ($keys8.Count -ge 40 -and $noEn.Count -eq 0) "$($keys8.Count) cles de T() des fonctions du lot et du bouton : toutes ont leur entree anglaise ; sans entree : $($noEn -join ' | ')"
# Decision unique : qui appelle quoi, dans tous les modules (gestionnaires d evenements compris)
$tCmd = [System.Management.Automation.Language.CommandAst]
$watch = @('Resolve-DriveOfEra', 'Get-CalibBackInfo', 'Restore-CalibBack', 'Show-CalibBackDialog')
$calls = @{}; foreach ($w in $watch) { $calls[$w] = @() }
$backCalls = @()
foreach ($mf in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Where-Object { $_.Name -notlike '01*' } | Sort-Object Name)) {
    foreach ($fd in (Get-RtAst $mf.FullName).FindAll({ param($x) $x -is $tFn }, $false)) {
        foreach ($c in $fd.Body.FindAll({ param($x) $x -is $tCmd }, $true)) {
            $cn = $c.GetCommandName()
            if ($watch -contains $cn) { $calls[$cn] += $fd.Name }
            if ($cn -eq 'Backup-ConfigBeforeRef' -and $c.Extent.Text -match "'back'") { $backCalls += $fd.Name }
        }
    }
}
$sig8 = @($watch | ForEach-Object { "$_ <- $((@($calls[$_] | Sort-Object -Unique)) -join ',')" })
Chk 'R8j' ((@($calls['Resolve-DriveOfEra'] | Sort-Object -Unique) -join ',') -ceq 'Get-CalibBackInfo' -and (@($calls['Get-CalibBackInfo'] | Sort-Object -Unique) -join ',') -ceq 'Get-CalibBackItems,New-CalibBackDialog,Restore-CalibBack,Start-CalibBack' -and (@($calls['Restore-CalibBack'] | Sort-Object -Unique) -join ',') -ceq 'Start-CalibBack' -and (@($calls['Show-CalibBackDialog'] | Sort-Object -Unique) -join ',') -ceq 'Start-CalibBack' -and ($backCalls -join ',') -ceq 'Restore-CalibBack') "decision unique : $($sig8 -join ' ; ') ; motif back : $($backCalls -join ',')"
$ch = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
$sec = ''; $mm = [regex]::Match($ch, '(?s)## \[12\.11\].*?(?=\n## \[)'); if ($mm.Success) { $sec = $mm.Value }
$nouv = ''; $mn = [regex]::Match($sec, '(?s)### Nouveautés.*?(?=\n### )'); if ($mn.Success) { $nouv = $mn.Value }
$sav = ''; $ms = [regex]::Match($sec, '(?s)### À savoir pour la mise à jour.*?(?=\n### )'); if ($ms.Success) { $sav = $ms.Value }
$dev = ''; $md = [regex]::Match($sec, '(?s)### Pour les développeurs.*$'); if ($md.Success) { $dev = $md.Value }
Chk 'R8h' ($nouv.Contains("- **Revenir à une calibration précédente.** Dans les options avancées de l'onglet « Écriture », un bouton à côté de « Effacer les calibrations » liste les calibrations complètes gardées dans les copies de la configuration et rétablit celle que vous choisissez, sans fermer l'application. Seules ses courbes changent ; l'état actuel est d'abord sauvegardé, et un retour s'annule de la même façon.") -and $sav.Contains('**Revenir à une calibration précédente : copies lues, autre calcul.**') -and $sav.Contains('courbe conservée') -and $dev.Contains('`Get-CalibBackInfo($item)`') -and $sec -notmatch 'vérifiée? sur (du )?matériel') 'CHANGELOG : Nouveautes (texte du plan, m7), A savoir, Pour les developpeurs ; aucun texte ne dit le comportement verifie sur materiel'
# Relecture de L7 (point F/B2) : ce que le bouton fait d une courbe ajoutee, dit tel que R4g, R4h et R4i l observent
Chk 'R8k' ($sav.Contains("Le bouton rétablit des courbes et n'en retire aucune : une courbe qu'un retour ajoute là où il n'y en avait aucune reste en place si vous annulez ce retour, et un retour qui ne remplace aucune courbe ne fait pas de copie.") -and $dev.Contains("un retour qui ne fait qu'ajouter des courbes ne fait pas de copie")) 'CHANGELOG : courbe ajoutee qui reste apres une annulation, retour sans copie (À savoir, Pour les développeurs)'
$rd = [System.IO.File]::ReadAllText((Join-Path $mods 'README.md'), [System.Text.Encoding]::UTF8)
$trd = [System.IO.File]::ReadAllText((Join-Path $Wt 'tests\README.md'), [System.Text.Encoding]::UTF8)
Chk 'R8i' ($rd.Contains('`Get-CalibBackInfo`') -and $rd.Contains('`btnWCalBack`') -and $trd.Contains('| `logic-calib-retour` |')) 'README des modules (120, 240, 250, 520) et des tests'

$sw.Stop()
"=== duree : $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail -gt 0) { "Non conformes : $($script:FailIds -join ', ')" }
"=== bilan logic-calib-retour : $($script:NChk - $script:Fail) conformes sur $($script:NChk)"
if ($script:Fail -gt 0) { exit 1 }
exit 0
