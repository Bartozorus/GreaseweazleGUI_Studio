param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-fix2-e) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out.
# Copie adaptee par la RC6 (10/11/2026, v1210\rc6\make_rc6_copies.py, source v1210\rc5\fix2\logic-1210-fix2-d.ps1) : refus de la restauration sans courbe croisee « standard » A -> 0 (2c1eb08) au lieu de « ... en double densite » (F4 : regles attendues, francais et anglais).
# Copie adaptee par la correction fix2 de la RC5 (10/11/2026, v1210\rc5\fix2\make_fix2_copies.py) : Get-WriteImageFamily (140), appelee par Get-TargetWriteInfo, ajoutee aux fonctions extraites.
# Correction tour 2 de la RC4 12.10 (10/11/2026, v1210\rc4\fix2), d apres la relecture r8 (v1210\rc4\revue\r8-ee11880,
# r8-logique.ps1, dont le cadre est repris : fonctions reelles extraites des modules par l arbre syntaxique, ecrites dans un
# fichier de travail puis chargees par dot-source ; gestionnaires de 520 attaches a de vrais controles WinForms jamais
# affiches ; bouchons pilotes par le scenario $script:S).
#  m-B1-DOUBLON : format de l onglet Ecriture pose par le code qui recalcule ensuite le profil (bouton dossier 520,
#      Set-WritePreset 140, Restore-WriteTabState et Start-RestoreWrite 300) sous la garde des liaisons : un seul calcul et
#      une seule ligne « Profil precomp » par operation, meme image comprise ; choix de l utilisateur toujours recalcule.
#  B-RS-REGLES : texte des regles de la copie (Update-RsRules) et infobulle du cadre 2 (Update-RsCalib) selon le lecteur
#      cible avec effet sur la restauration (Get-RestoreTargetInfo) ; format de la restauration (Update-SettingDependents).
#  Mesure : hauteur du texte des regles ($lblRsRules, 540 : 372 px de large, hauteur automatique, haut a 232 px) en
#      francais et en anglais, variante comprise (GDI+, rendu compatible de Windows PowerShell 5.1 ; GDI pour memoire).
# Correction fixA de la RC5 (10/11/2026, v1210\rc5\fixA) : copie adaptee de v1210\rc4\fix2\logic-1210-fix2, qui la
# remplace dans la campagne : regles, cadre et note de l infobulle d apres la decision de la restauration (300
# Get-RestorePlan, extrait en plus). F4 et F5 attendent : copie de flux (cadre sans phrase du lecteur cible, regles et
# note de la copie de flux), haute densite sans lecteur cible (regles et note de la haute densite), haute densite pour un
# lecteur cible (regles du refus, infobulle = cadre seul), GCR pour un lecteur cible (sans effet : cadre sans phrase du
# lecteur cible, regles d origine et phrase de la calibration). F0 a F3, F6, F7 inchanges.
# Aucun gw, aucune fenetre, aucun Add-Type, aucune evaluation de texte.
# Correction fixB de la RC5 (10/11/2026, v1210\rc5\fixB) : copie adaptee de v1210\rc5\fixA\logic-1210-fix2-a, qui la remplace dans la
# campagne : remplacant d Update-WLevelUi (140) ; Get-RsCurveSet (300, bouton « Courbe » du cadre 2,
# lu par Update-RsCalib) et Get-LevelBeforeWriteKind (260, lu par Update-RsRules) extraits ; Get-Setting du test :
# levelBeforeWriteMode (mesure sur l image, regles d avant). Attentes inchangees.
# Correction fix1 de la RC5 (10/11/2026, v1210\rc5\fix1) : copie adaptee de v1210\rc5\fixB\logic-1210-fix2-b, qui la
# remplace dans la campagne : le gestionnaire reel de la case --precomp met a jour le bouton « Courbe »
# (Update-CurveButton, etat du bouton seulement, aucun calcul du profil) : appels comptes a part (PcUpd), hors des
# calculs de F2 ; F4 : lecteur cible sans courbe croisee (refus au lancement) : regles du refus. Autres attentes
# inchangees.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Import-TestWinForms
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$m = Join-Path $Wt 'src/modules'
if (-not (Test-Path -LiteralPath (Join-Path $m '300-fn-restauration.ps1'))) { throw "modules introuvables sous $Wt" }
$Language = 'fr'
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'

$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    if (-not $ok) { $script:Fail++; $script:FailIds += $id }
    '{0,-8} {1,-12} {2}' -f $id, $(if ($ok) { 'conforme' } else { 'NON CONFORME' }), $d
}
function Get-Ast([string]$file) { $tok = $null; $err = $null; return [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tok, [ref]$err) }
function Get-FnText([string]$file, [string[]]$names) {
    $ast = Get-Ast $file
    $out = @()
    foreach ($n in $names) {
        $fn = @($ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | Where-Object { $_.Name -eq $n })
        if ($fn.Count -ne 1) { throw "fonction $n : $($fn.Count) definition(s) dans $file" }
        $out += $fn[0].Extent.Text
    }
    return ($out -join "`r`n`r`n")
}
function Get-HandlerAst([string]$file, [string]$ctl, [string]$member) {
    $ast = Get-Ast $file
    $c = @($ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $x.Expression.Extent.Text -eq $ctl -and $x.Member.Extent.Text -eq $member }, $true))
    if ($c.Count -ne 1) { throw "gestionnaire $ctl.$member : $($c.Count) occurrence(s)" }
    $a = $c[0].Arguments[0]
    if ($a -isnot [System.Management.Automation.Language.ScriptBlockExpressionAst]) { throw "gestionnaire $ctl.$member : argument non bloc" }
    return $a.ScriptBlock
}
function Get-HandlerBlock([string]$file, [string]$ctl, [string]$member) { return (Get-HandlerAst $file $ctl $member).Extent.Text }

# --- 0. Statique : toute affectation du format de l onglet Ecriture par le code est sous la garde des liaisons -------------
# Sites : affectations « $cmbWFmt.SelectedItem / SelectedIndex / Text = » et appels « Set-Combo $cmbWFmt » de tous les
# modules fonctionnels (1xx a 3xx) et du bouton dossier (520). Garde : bloc try dont le finally remet
# « $script:SettingSync = $sv », precede (meme bloc) de « $script:SettingSync = $true ». Exemptes : Set-Defaults (champ Image
# vide avant : gestionnaires sans effet) et Load-Config (demarrage, avant UiReady)
"--- 0 : statique, format pose par le code sous la garde des liaisons"
$sites = @()
$files = @(Get-ChildItem -LiteralPath $m -Filter '*.ps1' | Where-Object { $_.Name -match '^[123]\d\d-' -or $_.Name -eq '520-ui-ecriture.ps1' } | Sort-Object Name)
foreach ($fi in $files) {
    $ast = Get-Ast $fi.FullName
    $hits = @($ast.FindAll({ param($x)
        ($x -is [System.Management.Automation.Language.AssignmentStatementAst] -and $x.Left.Extent.Text -match '^\$cmbWFmt\.(SelectedItem|SelectedIndex|Text)$') -or
        ($x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'Set-Combo' -and $x.CommandElements.Count -ge 2 -and $x.CommandElements[1].Extent.Text -eq '$cmbWFmt') }, $true))
    foreach ($h in $hits) {
        $fn = $h.Parent; while ($fn -and $fn -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) { $fn = $fn.Parent }
        $where = if ($fn) { $fn.Name } elseif ($fi.Name -eq '520-ui-ecriture.ps1') { '520 (niveau du script)' } else { '(niveau du script)' }
        $p = $h.Parent; $try = $null
        while ($p) { if ($p -is [System.Management.Automation.Language.TryStatementAst]) { $try = $p; break }; $p = $p.Parent }
        $guard = $false
        if ($try -and $try.Finally -and $try.Finally.Extent.Text.Contains('$script:SettingSync = $sv')) {
            $blk = $try.Parent
            $sib = if ($blk -is [System.Management.Automation.Language.NamedBlockAst] -or $blk -is [System.Management.Automation.Language.StatementBlockAst]) { @($blk.Statements) } else { @() }
            $i = [array]::IndexOf([object[]]$sib, $try)
            if ($i -gt 0) { foreach ($k in 0..($i - 1)) { if ($sib[$k].Extent.Text.Contains('$script:SettingSync = $true')) { $guard = $true } } }
        }
        $sites += [pscustomobject]@{ File = $fi.Name; Fn = $where; Line = $h.Extent.StartLineNumber; Text = ($h.Extent.Text -replace '\s+', ' '); Guard = $guard }
    }
}
foreach ($s in $sites) { "  {0}:{1,-5} {2,-26} garde {3,-5} {4}" -f $s.File, $s.Line, $s.Fn, $s.Guard, $(if ($s.Text.Length -gt 90) { $s.Text.Substring(0, 90) + '…' } else { $s.Text }) }
$exempt = @('Set-Defaults', 'Load-Config')
$bad0 = @($sites | Where-Object { -not $_.Guard -and $exempt -notcontains $_.Fn })
$need = @('Set-WritePreset', 'Restore-WriteTabState', 'Start-RestoreWrite', '520 (niveau du script)')
$miss0 = @($need | Where-Object { $n = $_; @($sites | Where-Object { $_.Fn -eq $n -and $_.Guard }).Count -eq 0 })
Chk 'F0a' ($sites.Count -ge 6 -and $bad0.Count -eq 0 -and $miss0.Count -eq 0) "$($sites.Count) sites ; hors Set-Defaults et Load-Config, tous sous la garde des liaisons (try / finally SettingSync) : non gardes $($bad0.Count) ; sites attendus gardes absents : $($miss0 -join ', ')"
# Garde limitee au format : profil (reglage lie precompProfile) pose hors de la garde dans Set-WritePreset ; Update-PrecompForImage
# apres la garde dans le bouton dossier et Restore-WriteTabState
$tSwp = Get-FnText (Join-Path $m '140-fn-ecriture.ps1') @('Set-WritePreset')
$iFin = $tSwp.IndexOf('} finally { $script:SettingSync = $sv }', [System.StringComparison]::Ordinal); $iProf = $tSwp.IndexOf('$cmbWProfile.SelectedIndex = 0', [System.StringComparison]::Ordinal)
$btnSb = Get-HandlerAst (Join-Path $m '520-ui-ecriture.ps1') '$btnWFile' 'Add_Click'
$tBtn = $btnSb.Extent.Text
$iBf = $tBtn.IndexOf('finally { $script:SettingSync = $sv }', [System.StringComparison]::Ordinal); $iBu = $tBtn.IndexOf('Update-PrecompForImage $d.FileName', [System.StringComparison]::Ordinal)
$tRws = Get-FnText (Join-Path $m '300-fn-restauration.ps1') @('Restore-WriteTabState')
$iRf = $tRws.IndexOf('finally { $script:SettingSync = $sv }', [System.StringComparison]::Ordinal); $iRu = $tRws.IndexOf('Update-PrecompForImage $txtWFile.Text', [System.StringComparison]::Ordinal); $iRs = $tRws.IndexOf('$chkWSlow.Checked = $s.Slow', [System.StringComparison]::Ordinal)
"  Set-WritePreset : fin de la garde a $iFin, profil a $iProf ; bouton dossier : fin de la garde a $iBf, calcul a $iBu ; Restore-WriteTabState : fin de la garde a $iRf, case lente a $iRs, calcul a $iRu"
Chk 'F0b' ($iFin -gt 0 -and $iProf -gt $iFin -and $iBf -gt 0 -and $iBu -gt $iBf -and $iRf -gt 0 -and $iRs -gt $iRf -and $iRu -gt $iRs) "garde limitee au format : profil de Set-WritePreset et reglages lies de Restore-WriteTabState poses apres la garde (leurs liaisons s executent) ; Update-PrecompForImage apres la garde"

# --- Cadre de r8 : fonctions reelles, gestionnaires reels, bouchons --------------------------------------------------------
$f520 = Join-Path $m '520-ui-ecriture.ps1'
$hand = [ordered]@{
    'Invoke-HFmtEnter'      = Get-HandlerBlock $f520 '$cmbWFmt' 'Add_Enter'
    'Invoke-HFmtSel'        = Get-HandlerBlock $f520 '$cmbWFmt' 'Add_SelectedIndexChanged'
    'Invoke-HFmtLeave'      = Get-HandlerBlock $f520 '$cmbWFmt' 'Add_Leave'
    'Invoke-HPrecomp'       = Get-HandlerBlock $f520 '$chkWPrecomp' 'Add_CheckedChanged'
    'Invoke-HProfile'       = Get-HandlerBlock $f520 '$cmbWProfile' 'Add_SelectedIndexChanged'
    'Invoke-HSlow'          = Get-HandlerBlock $f520 '$chkWSlow' 'Add_CheckedChanged'
    'Invoke-HLblText'       = Get-HandlerBlock $f520 '$lblWProfileInfo' 'Add_TextChanged'
}
# Bouton dossier : corps reel du bloc « if ($d.ShowDialog() -eq 'OK') { ... } », rejoue avec $d remplace (fenetre de choix)
$ifs = @($btnSb.FindAll({ param($x) $x -is [System.Management.Automation.Language.IfStatementAst] -and $x.Clauses[0].Item1.Extent.Text -like '*ShowDialog()*' }, $true))
if ($ifs.Count -ne 1) { throw "bouton dossier : $($ifs.Count) bloc(s) ShowDialog" }
$pickBody = $ifs[0].Clauses[0].Item2.Extent.Text
$pickBody = $pickBody.Substring(1, $pickBody.Length - 2)
$code = (Get-FnText (Join-Path $m '220-fn-profil-precomp.ps1') @('Get-CurveDate', 'Set-PrecompFields', 'Get-TargetProfileText', 'Get-WProfileSpec', 'Get-HdProfile', 'Get-HdCommonCurve', 'Get-HeadSpec', 'Get-HdAutoFields', 'Set-WProfileText', 'Get-WTargetHead', 'Sync-WTargetHead', 'Update-PrecompForImage')) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '230-fn-calib-courbe.ps1') @('Get-CalibFamilyName', 'Get-ImageFamily')) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '140-fn-ecriture.ps1') @('Update-WriteFactorNote', 'Get-WriteFactorNote', 'Get-WriteFactorPlan', 'Get-TargetWriteInfo', 'Get-WriteImageFamily', 'Get-TargetWriteBlock', 'Test-RawFluxWrite', 'Test-FluxImage', 'Set-WTabNotice', 'Clear-WTabNotice', 'Get-WProfileText', 'Set-WritePreset')) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '150-fn-pistes-densite.ps1') @('Test-HdFormat')) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '274-fn-contenu-calcul.ps1') @('Limit-WriteFactor')) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '300-fn-restauration.ps1') @('Save-WriteTabState', 'Restore-WriteTabState', 'Get-RestoreFormat', 'Get-RsCalibText', 'Get-RestoreTargetInfo', 'Update-RsCalib', 'Update-RsRules', 'Get-RestorePlan', 'Get-RsCurveSet')) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '260-fn-calib-rapide.ps1') @('Get-LevelBeforeWriteKind')) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '120-fn-configuration.ps1') @('Set-Combo', 'Set-Num', 'Update-SettingDependents'))
foreach ($k in $hand.Keys) { $code += "`r`n`r`nfunction $k $($hand[$k])" }
$code += "`r`n`r`nfunction Invoke-FolderPickReal(`$d) {`r`n$pickBody`r`n}`r`n"
$gen = Join-Path $here 'gen-1210-fix2-e.ps1'
[System.IO.File]::WriteAllText($gen, $code, (New-Object System.Text.UTF8Encoding($true)))
. $gen
$fl = (Get-Content -LiteralPath (Join-Path $m '040-etat-formats.ps1') -Encoding UTF8 -Raw)
if ($fl -notmatch '(?s)\$Formats = @\((.*?)\)\s*\r?\n') { throw 'liste $Formats introuvable' }
$Formats = @([regex]::Matches($Matches[1], "'([^']*)'") | ForEach-Object { $_.Groups[1].Value })
$rr = (Get-Content -LiteralPath (Join-Path $m '580-etat-restauration.ps1') -Encoding UTF8 -Raw)
if ($rr -notmatch '\$script:RestoreRules = @\{ ReadRevs = \d+; ReadRetries = \d+; SeekRetries = \d+; WriteRetries = (\d+); RepairPasses = (\d+)') { throw 'RestoreRules introuvable (580)' }
$script:RestoreRules = @{ WriteRetries = [int]$Matches[1]; RepairPasses = [int]$Matches[2] }

$script:PrecompStd = '0=70:40=100:65=140'; $script:PrecompLong = '0=85:20=110:40=120:65=140'
$script:PrecompStdDefault = $script:PrecompStd; $script:PrecompLongDefault = $script:PrecompLong; $script:PrecompHdDefault = '0=40:79=60'
$script:PrecompThresholdNs = 1950; $script:ScpStatsOk = $true; $script:PrecompCurves = @{}
$script:WFactorNote = $null; $script:WProfileHd = $false
$script:WTargetHead = ''; $script:WProfilePath = ''; $script:WProfileLabel = $null; $script:WProfileBuilding = $false
$script:UiReady = $true; $script:SettingSync = $false; $script:WTabNotice = $null; $script:WFmtOnEnter = $null
$script:CalHardNs = 160; $script:CalHardNsUser = 160; $script:ContentFMax = 2.0; $script:LevelBrand = ''; $script:PresetSource = ''
$tip = New-Object System.Windows.Forms.ToolTip
$lblWProfileInfo = New-Object System.Windows.Forms.Label
$lblWProfileInfo.Text = 'Choisissez une image : le format et la précompensation seront déduits automatiquement.'
$lblWProfileInfo.Add_TextChanged({ Invoke-HLblText })
$chkWPrecomp = New-Object System.Windows.Forms.CheckBox; $chkWPrecomp.Checked = $true
# fix1 (RC5) : mise a jour du bouton « Courbe » par le gestionnaire (Update-CurveButton) comptee a part
$script:PcUpd = 0
$chkWPrecomp.Add_CheckedChanged({ $b = $script:UpdCalls; Invoke-HPrecomp; $script:PcUpd += $script:UpdCalls - $b; $script:UpdCalls = $b })
$chkWSlow = New-Object System.Windows.Forms.CheckBox; $chkWSlow.Checked = $false
$chkWSlow.Add_CheckedChanged({ Invoke-HSlow })
$cmbWFmt = New-Object System.Windows.Forms.ComboBox
[void]$cmbWFmt.Items.AddRange([object[]]$Formats); $cmbWFmt.SelectedIndex = 0
# Gestionnaire reel, avec le compte des calculs qu il lance (FmtUpd)
$script:FmtUpd = 0
$cmbWFmt.Add_SelectedIndexChanged({ $b = $script:UpdCalls; Invoke-HFmtSel; $script:FmtUpd += $script:UpdCalls - $b })
$cmbWProfile = New-Object System.Windows.Forms.ComboBox; $cmbWProfile.DropDownStyle = 'DropDownList'
[void]$cmbWProfile.Items.AddRange(@((T 'Auto (selon image)'), (T 'Standard 2 us'), (T 'Long track 1,89 us'), (T 'Manuel'))); $cmbWProfile.SelectedIndex = 0
$cmbWProfile.Add_SelectedIndexChanged({ Invoke-HProfile })
$txtWFile = New-Object System.Windows.Forms.TextBox
$txtWPrecomp = New-Object System.Windows.Forms.TextBox; $txtWPrecomp1 = New-Object System.Windows.Forms.TextBox
$txtWTracks = [pscustomobject]@{ Text = '' }
$cmbDrive = [pscustomobject]@{ Text = 'A'; SelectedItem = 'A' }
$cmbWCalMode = [pscustomobject]@{ SelectedIndex = 0 }
foreach ($n in 'chkWPreErase', 'chkWEraseEmpty', 'chkWNoVerify', 'chkWPostCheck', 'chkWHard', 'chkWTG43') { Set-Variable -Name $n -Value ([pscustomobject]@{ Checked = $false }) }
$numWRetries = [pscustomobject]@{ Value = 10; Minimum = 0; Maximum = 99 }; $numWRepair = [pscustomobject]@{ Value = 3; Minimum = 0; Maximum = 9 }
# Restauration : cadre 2 et regles (540 : 262 x 54 px ; 372 px, hauteur automatique)
$lblRsCal = New-Object System.Windows.Forms.Label; $lblRsCal.Size = New-Object System.Drawing.Size(262, 54); $lblRsCal.AutoEllipsis = $true
$lblRsRules = New-Object System.Windows.Forms.Label; $lblRsRules.AutoSize = $true; $lblRsRules.MinimumSize = New-Object System.Drawing.Size(372, 0); $lblRsRules.MaximumSize = New-Object System.Drawing.Size(372, 0)
$btnRsCurve = [pscustomobject]@{ Enabled = $false }
$S = @{}
$script:LogLines = New-Object System.Collections.Generic.List[string]
$script:UpdCalls = 0; $script:FmtFound = 0
function Update-CurveButton($p) { $script:UpdCalls++ }
function Update-WProfileTip { }
function Update-SlowUi { }
function Update-WLevelUi { }   # fixB (RC5) : case de la mesure (140), appelee en sortie d Update-PrecompForImage
function Update-RsFmtFound { $script:FmtFound++ }
function Update-RsDrive { }
function Update-CmpFmtFound { }
function Reset-LibDat { }
function Append-Log([string]$t) { $script:LogLines.Add($t) }
function Get-Setting([string]$k) { if ($k -eq 'restoreFormat') { return [string]$script:S.RsFmt }; if ($k -eq 'levelBeforeWriteMode') { return 'content' }; throw "Get-Setting $k non prevu par ce test" }
function Get-FmtCase([string]$f) { if ($script:S.FmtCase -and $script:S.FmtCase.ContainsKey($f)) { return $script:S.FmtCase[$f] }; return $null }
function Get-ImageEncoding($p, $f) {
    $fc = Get-FmtCase $f
    if ($fc -and $fc.NonMfm) { return @{ NonMfm = $true; Name = $fc.NonMfm; Src = 'format'; Enc = 'gcr' } }
    return @{ NonMfm = $false; Enc = 'mfm' }
}
function Get-HighDensityReason($p, $f) { $fc = Get-FmtCase $f; if ($fc) { return $fc.Hd }; return $null }
function Get-HdCalibFamily($p, $f) { $fc = Get-FmtCase $f; if ($fc) { return $fc.HdFam }; return $null }
function Test-HeadCurvesCurrent($f) { return $false }
function Get-IpfCellInfo($p) { return $script:S.Info }
function Get-ScpCellInfo($p) { return $script:S.Info }
function Get-HfeCellInfo($p) { return $script:S.Info }
function Get-TargetDrive([string]$src = '') { return [string]$script:S.Tgt }
function Get-CurveCalcText($c, [switch]$Plain) { return 'v12.10' }
function Test-NeedsFormat([string]$p) { return (@('.img', '.ima', '.st') -contains [System.IO.Path]::GetExtension($p).ToLower()) }
function Test-AdfHd([string]$p) { if ($script:S.AdfThrow) { throw 'erreur simulee (Test-AdfHd)' }; return [bool]$script:S.AdfHd }
function Get-TSpecExtras($t) { return '' }
function Get-ImageFaces($p) { return @{ Unknown = $false } }
function Get-FaceSafeWrite($fc, $slow, $extras, $empty) { return @{ Empty = $true; Tracks = ''; Head = $null } }
function Get-WriteLevelKind([string]$img, [string]$fmt) {
    $e = [System.IO.Path]::GetExtension($img).ToLower(); $explicit = ($fmt -and $fmt -ne '(auto)')
    if (@('.scp', '.raw', '.kf', '.a2r', '.ctr') -contains $e) { return '' }
    if ((Test-NeedsFormat $img) -and -not $explicit) { return '' }
    if ((Get-ImageEncoding $img $fmt).NonMfm) { return '' }
    if (Get-HighDensityReason $img $fmt) { if (Get-HdCalibFamily $img $fmt) { return 'hd' }; return '' }
    if (-not (@('.adf', '.ipf', '.hfe') -contains $e) -and -not $explicit) { return '' }
    return 'dd'
}
function Get-FamilyCurves([string]$fam, [bool]$heads) { if ($script:S.NoOwn) { return ,@() }; return ,@(@{ Drive = 'A'; Spec = '0=70:40=100'; Date = '01/11/2026 10:00' }) }
function Get-DriveK([string]$drive, [string]$fam, [int]$h, $brand = $null) { return @{ K = $(if ($h -eq 0) { 1.05 } else { 1.15 }); Src = 'lecteur'; N = 1; Ks = @(1.0) } }
function Get-WriteFactorSrcText { return 'mesure' }
$cx = @{ Spec = '0=90:40=130'; Date = '20/10/2026 09:00'; Test = 'std' }
function Get-TargetCurves($fam, $slow, $src, $tgt) {
    if (-not $script:S.Tgt) { return }
    switch ([string]$script:S.Cross) { 'common' { $cx } default { } }
}
$fmtCase = @{ 'ibm.1440' = @{ Hd = 'format haute densité ibm.1440'; HdFam = 'hd' }; 'amiga.amigados_hd' = @{ Hd = 'format haute densité amiga.amigados_hd'; HdFam = 'hd' }
              'commodore.1541' = @{ NonMfm = 'GCR' } }
New-Item -ItemType Directory -Force -Path (Join-Path $here 'img') | Out-Null
$img = @{}
foreach ($e in 'adf', 'scp', 'img') { $p = Join-Path $here "img/essai.$e"; if (-not (Test-Path -LiteralPath $p)) { [System.IO.File]::WriteAllBytes($p, [byte[]]@(0)) }; $img[$e] = $p }
$img['scp2'] = Join-Path $here 'img/autre.scp'; if (-not (Test-Path -LiteralPath $img.scp2)) { [System.IO.File]::WriteAllBytes($img.scp2, [byte[]]@(0)) }
$img['adf2'] = Join-Path $here 'img/autre.adf'; if (-not (Test-Path -LiteralPath $img.adf2)) { [System.IO.File]::WriteAllBytes($img.adf2, [byte[]]@(0)) }
$scpInfo = @{ CellNs = 2000; Bits = 100000; Tracks = 4; DosTracks = -1; Source = 'SCP' }
function Set-State([hashtable]$sc, [int]$prof, [string]$fmt, [bool]$slow) {
    # etat pose sous la garde des liaisons (aucun gestionnaire), comme Load-Config
    $script:S = $sc
    $script:SettingSync = $true
    try {
        $chkWSlow.Checked = $slow; $cmbWProfile.SelectedIndex = $prof
        if ($cmbWFmt.Items.Contains($fmt)) { $cmbWFmt.SelectedItem = $fmt } else { $cmbWFmt.Text = $fmt }
        $chkWPrecomp.Checked = $true
    } finally { $script:SettingSync = $false }
}
function Get-ProfLines { return @($script:LogLines | Where-Object { $_ -like 'Profil precomp*' }) }
function Start-Count { $script:LogLines.Clear(); $script:UpdCalls = 0; $script:FmtUpd = 0 }

# --- 1. m-B1-DOUBLON : un calcul et une ligne « Profil precomp » par operation (format pose par le code) ---------------------
"--- 1 : format pose par le code : calculs et lignes « Profil precomp » par operation"
$rows = @()
foreach ($case in @(
    @{ Id = 'F1a'; N = 'dossier : nouvelle image SCP (ibm.720 avant)'; Img = 'scp2'; Pre = 'ibm.720'; Op = 'folder' },
    @{ Id = 'F1b'; N = 'dossier : meme image SCP (ibm.720 avant)'; Img = 'scp'; Pre = 'ibm.720'; Op = 'folder' },
    @{ Id = 'F1c'; N = 'dossier : meme image SCP ((auto) avant)'; Img = 'scp'; Pre = '(auto)'; Op = 'folder' },
    @{ Id = 'F1d'; N = 'dossier : meme image ADF (ibm.720 avant)'; Img = 'adf'; Pre = 'ibm.720'; Op = 'folder'; Start = 'adf' },
    @{ Id = 'F1e'; N = 'dossier : nouvelle image ADF HD (ibm.720 avant)'; Img = 'adf2'; Pre = 'ibm.720'; Op = 'folder'; Start = 'adf'; AdfHd = $true },
    @{ Id = 'F1f'; N = 'Bibliotheque : nouvelle image SCP'; Img = 'scp2'; Pre = 'ibm.720'; Op = 'lib' },
    @{ Id = 'F1g'; N = 'Bibliotheque : meme image SCP (ibm.720 avant)'; Img = 'scp'; Pre = 'ibm.720'; Op = 'lib' },
    @{ Id = 'F1h'; N = 'Bibliotheque : meme image SCP ((auto) avant)'; Img = 'scp'; Pre = '(auto)'; Op = 'lib' },
    @{ Id = 'F1i'; N = 'Bibliotheque : meme image ADF (ibm.720 avant)'; Img = 'adf'; Pre = 'ibm.720'; Op = 'lib'; Start = 'adf' },
    @{ Id = 'F1j'; N = 'Bibliotheque : meme image IMG ibm.720 (ibm.720 garde)'; Img = 'img'; Pre = 'ibm.720'; Op = 'lib'; Start = 'img' })) {
    foreach ($tg in '', '0') {
        $st = if ($case.Start) { $case.Start } else { 'scp' }
        Set-State @{ Info = $scpInfo; Tgt = $tg; Cross = 'none'; FmtCase = $fmtCase; AdfHd = [bool]$case.AdfHd } 0 $case.Pre $false
        $txtWFile.Text = $img[$st]; $script:PresetSource = $img[$st]; Update-PrecompForImage $img[$st]
        Start-Count
        if ($case.Op -eq 'folder') { Invoke-FolderPickReal ([pscustomobject]@{ FileName = $img[$case.Img] }) }
        else { Set-WritePreset 'fast' $img[$case.Img] $img[$case.Img]; Update-PrecompForImage $img[$case.Img] }   # Start-LibWrite (130)
        $pl = Get-ProfLines; $u = $script:UpdCalls; $fu = $script:FmtUpd; $gs = $script:SettingSync
        # reference : lignes d un seul calcul dans cet etat (image secteur : aucune ligne « Profil precomp », comme avant)
        $script:LogLines.Clear(); Update-PrecompForImage $img[$case.Img]; $nRef = @(Get-ProfLines).Count
        $ok = ($u -eq 1 -and $pl.Count -eq $nRef -and $nRef -le 1 -and $fu -eq 0 -and -not $gs -and $txtWFile.Text -eq $img[$case.Img])
        $rows += $ok
        "  {0,-4} {1,-55} cible {2,-2} : format {3,-18} calculs {4} (gestionnaire de la liste {5}) ; lignes « Profil precomp » {6} (un calcul : {7}) ; garde remise {8}" -f $case.Id, $case.N, $(if ($tg) { $tg } else { '-' }), $cmbWFmt.Text, $u, $fu, $pl.Count, $nRef, (-not $gs)
    }
}
Chk 'F1' (@($rows | Where-Object { -not $_ }).Count -eq 0) "bouton dossier et ecriture par la Bibliotheque (Set-WritePreset puis Update-PrecompForImage), nouvelle image ou meme image au format change, ADF et HD compris, avec et sans lecteur cible : un seul calcul, une seule ligne « Profil precomp », aucun par le gestionnaire de la liste, garde des liaisons remise"

# Restore-WriteTabState apres une operation de la Bibliotheque sur la meme image : aucun calcul par le gestionnaire de la
# liste ; calculs restants : case « Ecriture lente » remise (reglage lie, gestionnaire reel) et Update-PrecompForImage
"--- 2 : Restore-WriteTabState reel apres une operation de la Bibliotheque sur la meme image"
$r2 = @()
foreach ($pc in $true, $false) { foreach ($slowBefore in $false, $true) {
    Set-State @{ Info = $scpInfo; Tgt = '0'; Cross = 'none'; FmtCase = $fmtCase } 0 'ibm.720' $slowBefore
    $txtWFile.Text = $img.scp; $script:PresetSource = $img.scp; Update-PrecompForImage $img.scp
    $script:SettingSync = $true; $chkWPrecomp.Checked = $pc; $script:SettingSync = $false
    if (-not $pc) { Sync-WTargetHead -IfOwn; Update-WriteFactorNote }
    $sv0 = Save-WriteTabState
    Set-WritePreset 'slow' $img.scp $img.scp; $chkWSlow.Checked = $true; Update-PrecompForImage $img.scp   # Start-LibWrite lente
    Start-Count
    Restore-WriteTabState $sv0
    $pl = Get-ProfLines
    $expU = 1 + $(if ($slowBefore) { 0 } else { 1 })          # case lente remise a decochee : son gestionnaire recalcule
    $ok = ($script:FmtUpd -eq 0 -and $script:UpdCalls -eq $expU -and $pl.Count -eq $expU -and $cmbWFmt.Text -eq 'ibm.720' -and $chkWPrecomp.Checked -eq $pc -and -not $script:SettingSync)
    $r2 += $ok
    "  case --precomp {0,-5}, lente avant {1,-5} : format {2} ; calculs {3} (attendu {4}, gestionnaire de la liste {5}) ; lignes « Profil precomp » {6} ; libelle « {7} »" -f $pc, $slowBefore, $cmbWFmt.Text, $script:UpdCalls, $expU, $script:FmtUpd, $pl.Count, $lblWProfileInfo.Text
} }
Chk 'F2' (@($r2 | Where-Object { -not $_ }).Count -eq 0) "Restore-WriteTabState : format remis sans calcul du gestionnaire de la liste ; un calcul par reglage lie remis qui change (case lente) plus le sien ; format et case --precomp remis"

# Choix de l utilisateur apres une operation du code : toujours recalcule (B1 garde) ; exception dans la garde : garde remise
"--- 3 : choix de l utilisateur apres le code ; exception sous la garde"
Set-State @{ Info = $scpInfo; Tgt = '0'; Cross = 'none'; FmtCase = $fmtCase } 0 '(auto)' $false
$txtWFile.Text = $img.scp; Update-PrecompForImage $img.scp
Invoke-FolderPickReal ([pscustomobject]@{ FileName = $img.scp })
Start-Count; $cmbWFmt.SelectedItem = 'ibm.720'; $u1 = $script:UpdCalls; $f1 = $script:FmtUpd
Set-WritePreset 'fast' $img.scp $img.scp; Update-PrecompForImage $img.scp
Start-Count; $cmbWFmt.SelectedItem = 'ibm.1440'; $u2 = $script:UpdCalls; $f2 = $script:FmtUpd
"  apres le bouton dossier, format choisi : $u1 calcul (gestionnaire $f1) ; apres la Bibliotheque : $u2 (gestionnaire $f2)"
$script:S.AdfThrow = $true
$e1 = try { Invoke-FolderPickReal ([pscustomobject]@{ FileName = $img.adf }); 'aucune' } catch { $_.Exception.Message }
$g1 = $script:SettingSync
$e2 = try { Set-WritePreset 'fast' $img.adf $img.adf; 'aucune' } catch { $_.Exception.Message }
$g2 = $script:SettingSync
$script:S.AdfThrow = $false
"  exception de Test-AdfHd : bouton dossier « $e1 », garde apres $g1 ; Set-WritePreset « $e2 », garde apres $g2"
Chk 'F3' ($u1 -eq 1 -and $f1 -eq 1 -and $u2 -eq 1 -and $f2 -eq 1 -and $e1 -like '*Test-AdfHd*' -and $e2 -like '*Test-AdfHd*' -and -not $g1 -and -not $g2) "format choisi dans la liste par l utilisateur apres le bouton dossier ou la Bibliotheque : recalcule une fois par le gestionnaire ; exception sous la garde : propagee, garde des liaisons remise"

# --- 4. B-RS-REGLES : regles de la copie et infobulle du cadre 2 selon le lecteur cible -------------------------------------
"--- 4 : regles de la copie et infobulle du cadre « Calibration du lecteur »"
$calTip = @{ fr = "Une calibration existante n'est jamais refaite par la restauration. Sans courbe, le lecteur est calibré tête par tête en test fin, éventuellement sur une disquette sacrifiée, avant l'écriture de la copie."
             en = 'The restore never redoes an existing calibration. Without a curve, the drive is calibrated head by head with the fine test, possibly on a sacrificial disk, before the copy is written.' }
$wr = $script:RestoreRules.WriteRetries; $rp = $script:RestoreRules.RepairPasses
function Get-ExpRules([string]$lg, [string]$src, [string]$tgt, [bool]$applies) {
    # Textes attendus, ecrits ici (independants du code) : variante pour le lecteur cible, sinon les regles d origine
    if ($lg -eq 'fr') {
        if ($applies) { return "Règles appliquées à la copie : écriture tête par tête par le lecteur $src avec la courbe croisée $src → $tgt, telle quelle, sans calibration ni mesure de la destination, effacement avant l'écriture, vérification par gw, $wr essais par piste, contrôle de toutes les pistes ($rp passes de réécriture au plus), puis relecture par le lecteur $src et comparaison avec l'original." }
        return "Règles appliquées à la copie : disquette de destination mesurée avant l'écriture quand c'est possible (calibration rapide), écriture tête par tête avec la calibration existante du lecteur (calibration par tête si aucune n'existe), effacement avant l'écriture, vérification par gw, $wr essais par piste, contrôle de toutes les pistes ($rp passes de réécriture au plus), puis relecture et comparaison avec l'original."
    }
    if ($applies) { return "Rules applied to the copy: head-by-head write by drive $src with the cross curve $src → $tgt, as is, without calibration or measurement of the destination, erase before writing, gw verification, $wr retries per track, check of all tracks (up to $rp rewrite passes), then read-back by drive $src and comparison with the original." }
    return "Rules applied to the copy: destination disk measured before writing when possible (quick calibration), head-by-head write with the existing drive calibration (per-head calibration if none exists), erase before writing, gw verification, $wr retries per track, check of all tracks (up to $rp rewrite passes), then read-back and comparison with the original."
}
# fixA (RC5) : decision attendue (ecrite ici, independante du code) et textes qui en derivent
$noteK = @{ fr = @{ hd = "La restauration ne calibre jamais le lecteur en haute densité : la copie est écrite avec la courbe haute densité existante, sinon avec le profil d'origine."
                    flux = "Une copie exacte du flux est écrite telle quelle par gw, sans précompensation : aucune de ces courbes ne s'y applique, et la restauration ne calibre pas le lecteur ni ne mesure la destination." }
            en = @{ hd = 'The restore never calibrates the drive in high density: the copy is written with the existing high-density curve, otherwise with the original profile.'
                    flux = 'An exact flux copy is written as is by gw, without precompensation: none of these curves applies to it, and the restore neither calibrates the drive nor measures the destination.' } }
$hdF2 = @('ibm.1440', 'amiga.amigados_hd')
function Get-ExpKind2([string]$rf, [string]$tgt, [string]$cr = '') {
    if ($rf -eq 'flux') { return 'flux' }
    if ($tgt -and $hdF2 -contains $rf) { return 'refused' }
    if ($tgt -and $rf -ne 'commodore.1541' -and $cr -eq 'none') { return 'none' }      # fix1 (RC5) : refus faute de courbe croisee
    if ($tgt -and $rf -ne 'commodore.1541') { return 'target' }
    if ($hdF2 -contains $rf) { return 'hd' }
    return 'sector'
}
function Get-ExpRulesK([string]$lg, [string]$src, [string]$tgt, [string]$k, [string]$rf) {
    if ($k -eq 'target') { return Get-ExpRules $lg $src $tgt $true }
    if ($k -eq 'sector') { return Get-ExpRules $lg $src $tgt $false }
    if ($k -eq 'none' -and $lg -eq 'fr') { return "Règles appliquées à la copie : aucune avec le lecteur cible $tgt : sans courbe croisée standard $src → $tgt, la restauration sera refusée au lancement. Lancez « Calibrer pour un lecteur cible… », ou choisissez « (même lecteur) » dans la liste « Lecteur cible » de l'onglet Écriture." }
    if ($k -eq 'none') { return "Rules applied to the copy: none with target drive $tgt`: without a standard cross curve $src → $tgt, the restore will be refused at start. Run `"Calibrate for a target drive…`", or choose `"(same drive)`" in the `"Target drive`" list of the Write tab." }
    if ($lg -eq 'fr') {
        if ($k -eq 'flux') { return "Règles appliquées à la copie : copie exacte du flux, écrite telle quelle par gw (ni précompensation, ni vérification par gw), sans calibration du lecteur ni mesure de la destination, écriture tête par tête, effacement avant l'écriture, contrôle de toutes les pistes ($rp passes de réécriture au plus), sans comparaison secteur par secteur avec l'original." }
        if ($k -eq 'refused') { return "Règles appliquées à la copie : aucune avec le lecteur cible $tgt, la restauration au format haute densité $rf sera refusée au lancement (la calibration croisée n'existe qu'en double densité). Choisissez « (même lecteur) » dans la liste « Lecteur cible » de l'onglet Écriture." }
        return "Règles appliquées à la copie : écriture tête par tête avec la courbe haute densité existante du lecteur, sinon le profil d'origine, sans calibration ni mesure de la destination (jamais en haute densité), pré-effacement de chaque piste, vérification par gw, $wr essais par piste, sans contrôle des pistes (non applicable à la haute densité), puis relecture et comparaison avec l'original."
    }
    if ($k -eq 'flux') { return "Rules applied to the copy: exact flux copy, written as is by gw (no precompensation, no gw verification), without drive calibration or measurement of the destination, head-by-head write, erase before writing, check of all tracks (up to $rp rewrite passes), no sector-by-sector comparison with the original." }
    if ($k -eq 'refused') { return "Rules applied to the copy: none with target drive $tgt, the restore in high-density format $rf will be refused at start (cross calibration exists in double density only). Choose `"(same drive)`" in the `"Target drive`" list of the Write tab." }
    return "Rules applied to the copy: head-by-head write with the drive's existing high-density curve, otherwise the original profile, no calibration or destination measurement (never in high density), pre-erase of each track, gw verification, $wr retries per track, no track check (not applicable to high density), then read-back and comparison with the original."
}
function Get-ExpNote([string]$lg, [string]$k) { if ($k -eq 'sector') { return $calTip[$lg] }; if ($k -eq 'hd' -or $k -eq 'flux') { return $noteK[$lg][$k] }; return '' }
$n4 = 0; $bad4 = 0; $nApp = 0
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    foreach ($src in 'A', 'B', '0') { foreach ($tgt in '', '1', '0') {
        if ($tgt -eq $src) { continue }
        foreach ($rf in 'auto', 'flux', 'amiga.amigados', 'ibm.720', 'ibm.1440', 'amiga.amigados_hd', 'commodore.1541') { foreach ($cr in 'common', 'none') {
            $cmbDrive.Text = $src
            $script:S = @{ Tgt = $tgt; Cross = $cr; RsFmt = $rf; FmtCase = $fmtCase }
            $lblRsCal.Text = ''; $tip.SetToolTip($lblRsCal, ''); $lblRsRules.Text = ''
            Update-RsCalib
            $n4++
            # attendu : lecteur cible avec effet = lecteur cible choisi, copie secteur (pas le flux), format detecte ou MFM
            $k2 = Get-ExpKind2 $rf $tgt $cr; $app = ($k2 -eq 'target')
            if ($app) { $nApp++ }
            $er = Get-ExpRulesK $lg $src $tgt $k2 $rf
            $nt = Get-ExpNote $lg $k2
            $et = [string]$lblRsCal.Text; if ($nt) { $et += "`n`n" + $nt }
            $gotR = [string]$lblRsRules.Text; $gotT = [string]$tip.GetToolTip($lblRsCal)
            $okC = ($gotR -ceq $er -and $gotT -ceq $et -and $lblRsCal.Text -eq (Get-RsCalibText))
            if (-not $okC) { $bad4++; if ($bad4 -le 8) { "  ECART [$lg $src -> $(if ($tgt) { $tgt } else { '-' }) | $rf | $cr] regles « $gotR »`n     attendu « $er »`n     infobulle « $($gotT -replace "`n", ' | ') »" } }
        } }
    } }
}
$script:Lang = 'fr'
"  cas joues : $n4 (lecteur cible avec effet : $nApp) ; ecarts : $bad4"
Chk 'F4' ($bad4 -eq 0 -and $nApp -gt 0 -and $nApp -lt $n4) "lecteur cible avec effet (format detecte, MFM double densite, avec ou sans courbe croisee) : regles « ecriture ... par le lecteur X avec la courbe croisee X -> Y, telle quelle, sans calibration ni mesure de la destination ... relecture par le lecteur X » et infobulle = texte du cadre seul ; fixA : format haute densite pour un lecteur cible : regles du refus, infobulle = cadre seul ; copie de flux, avec ou sans lecteur cible : regles et note de la copie de flux ; haute densite sans lecteur cible : regles et note de la haute densite ; sans lecteur cible ou format GCR : regles d origine et phrase de la calibration en infobulle ; francais et anglais"
# Exemples
$cmbDrive.Text = 'A'
foreach ($lg in 'fr', 'en') { $script:Lang = $lg; $script:S = @{ Tgt = '0'; Cross = 'common'; RsFmt = 'auto'; FmtCase = $fmtCase }; Update-RsCalib; "  [$lg A -> 0, detection] « $($lblRsRules.Text) »" }
$script:Lang = 'fr'

# Format de la restauration change seul (texte du cadre inchange) : regles et infobulle suivent (Update-SettingDependents)
"--- 5 : format de la restauration change (Update-SettingDependents 'restoreFormat')"
$cmbDrive.Text = 'A'; $script:S = @{ Tgt = '0'; Cross = 'common'; RsFmt = 'auto'; FmtCase = $fmtCase }
$lblRsCal.Text = ''; $tip.SetToolTip($lblRsCal, ''); Update-RsCalib
$c0 = [string]$lblRsCal.Text; $t0 = [string]$tip.GetToolTip($lblRsCal); $r0 = [string]$lblRsRules.Text
# fixA (RC5) : copie de flux et format GCR (lecteur cible sans effet) : cadre sans la phrase du lecteur cible (cadre attendu :
# celui sans lecteur cible), note de la copie de flux ou de la calibration
$script:S.Tgt = ''; $cNoT = [string](Get-RsCalibText); $script:S.Tgt = '0'
$seq = @()
foreach ($rf in 'flux', 'commodore.1541', 'ibm.720', 'auto') {
    $script:S.RsFmt = $rf; $script:FmtFound = 0
    Update-SettingDependents 'restoreFormat'
    $k2 = Get-ExpKind2 $rf '0'; $app = ($k2 -eq 'target')
    $ec = if ($app) { $c0 } else { $cNoT }; $nt = Get-ExpNote 'fr' $k2
    $seq += [pscustomobject]@{ F = $rf; Cal = ([string]$lblRsCal.Text -eq $ec); TipOk = ([string]$tip.GetToolTip($lblRsCal) -ceq $(if ($nt) { $ec + "`n`n" + $nt } else { $ec })); Rules = ([string]$lblRsRules.Text -ceq (Get-ExpRulesK 'fr' 'A' '0' $k2 $rf)); Found = $script:FmtFound }
}
foreach ($x in $seq) { "  format $($x.F) : cadre attendu $($x.Cal) ; infobulle attendue $($x.TipOk) ; regles attendues $($x.Rules) ; ligne du format detecte refaite $($x.Found) fois" }
Chk 'F5' ($t0 -ceq $c0 -and $r0 -ceq (Get-ExpRules 'fr' 'A' '0' $true) -and @($seq | Where-Object { -not ($_.Cal -and $_.TipOk -and $_.Rules -and $_.Found -eq 1) }).Count -eq 0) "format de la restauration change : cadre, infobulle et regles suivent (fixA : copie de flux : cadre sans phrase du lecteur cible, regles et note de la copie de flux ; GCR : cadre sans phrase du lecteur cible, regles d origine et phrase de la calibration ; MFM, detection : variante), ligne du format detecte toujours refaite"
# Sans les controles de l onglet (avant 540) : aucun appel en erreur
$sR = $lblRsRules; $sC = $lblRsCal; $lblRsRules = $null; $lblRsCal = $null
$e6 = try { Update-RsRules; Update-RsCalib; Update-SettingDependents 'restoreFormat'; 'aucune' } catch { $_.Exception.Message }
$lblRsRules = $sR; $lblRsCal = $sC
Chk 'F6' ($e6 -eq 'aucune') "Update-RsRules, Update-RsCalib et Update-SettingDependents 'restoreFormat' sans les controles de la restauration (demarrage, avant 540) : $e6"

# --- 7. Mesure : hauteur du texte des regles (372 px, haut a 232 px) --------------------------------------------------------
# GDI+ (rendu compatible de Windows PowerShell 5.1 : MeasureString, lignes entieres) a 96, 120 et 144 ppp (largeur mise a
# l echelle), toutes les paires de lecteurs du bandeau ; bas du texte rapporte a 96 ppp compare au bas de l onglet a la
# taille par defaut (516 px, 140 Set-TargetDriveLayout) ; GDI (TextRenderer) pour memoire
"--- 7 : hauteur du texte des regles"
$drives = @('A', 'B', '0', '1', '2', '3')
$res = @()
foreach ($dpi in 96, 120, 144) {
    $sc = $dpi / 96.0; $w = [int][math]::Round(372 * $sc)
    $font = New-Object System.Drawing.Font('Segoe UI', 9.75)
    $bmp = New-Object System.Drawing.Bitmap(4, 4); $bmp.SetResolution($dpi, $dpi); $g = [System.Drawing.Graphics]::FromImage($bmp)
    $sf = New-Object System.Drawing.StringFormat; $sf.FormatFlags = [System.Drawing.StringFormatFlags]::LineLimit
    foreach ($lg in 'fr', 'en') {
        $base = Get-ExpRules $lg 'A' '0' $false
        $cf = 0; $lfB = 0; $hB = $g.MeasureString($base, $font, (New-Object System.Drawing.SizeF($w, 10000)), $sf, [ref]$cf, [ref]$lfB).Height
        foreach ($s in $drives) { foreach ($t in $drives) {
            if ($s -eq $t) { continue }
            $v = Get-ExpRules $lg $s $t $true
            $cf = 0; $lf = 0; $h = $g.MeasureString($v, $font, (New-Object System.Drawing.SizeF($w, 10000)), $sf, [ref]$cf, [ref]$lf).Height
            $flags = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
            # GDI : TextRenderer sans Graphics mesure a la resolution de l ecran : a 96 ppp seulement
            $hG = if ($dpi -eq 96) { [System.Windows.Forms.TextRenderer]::MeasureText($v, $font, (New-Object System.Drawing.Size($w, 10000)), $flags).Height } else { 0 }
            $res += [pscustomobject]@{ Dpi = $dpi; Lang = $lg; Pair = "$s>$t"; Lines = $lf; BaseLines = $lfB; Bottom = 232 + $h / $sc; BaseBottom = 232 + $hB / $sc; GdiBottom = $(if ($hG) { 232 + $hG } else { 0 }) }
        } }
    }
    $sf.Dispose(); $g.Dispose(); $bmp.Dispose(); $font.Dispose()
}
foreach ($grp in ($res | Group-Object Dpi, Lang)) {
    $x = $grp.Group
    "  {0,-8} variante {1}-{2} lignes (regles d origine {3}) ; bas a 96 ppp {4:N1}-{5:N1} px (origine {6:N1}){7}" -f $grp.Name, ($x | Measure-Object Lines -Minimum).Minimum, ($x | Measure-Object Lines -Maximum).Maximum, $x[0].BaseLines,
        ($x | Measure-Object Bottom -Minimum).Minimum, ($x | Measure-Object Bottom -Maximum).Maximum, $x[0].BaseBottom, $(if ($x[0].GdiBottom) { " ; GDI {0:N1}-{1:N1} px" -f ($x | Measure-Object GdiBottom -Minimum).Minimum, ($x | Measure-Object GdiBottom -Maximum).Maximum } else { '' })
}
$over = @($res | Where-Object { $_.Bottom -gt 516 -or $_.GdiBottom -gt 516 -or $_.Lines -gt $_.BaseLines })
Chk 'F7' ($res.Count -gt 0 -and $over.Count -eq 0) "texte des regles avec un lecteur cible : pas plus de lignes que les regles d origine, bas sous 516 px (bas de l onglet a la taille par defaut), GDI+ et GDI, 96 a 144 ppp, francais et anglais ($($over.Count) cas au-dela)"

"=== bilan logic-1210-fix2-e : $($script:NChk - $script:Fail) conformes sur $($script:NChk) ; $([int]$sw.Elapsed.TotalSeconds) s$(if ($script:Fail) { ' ; NON CONFORMES : ' + ($script:FailIds -join ', ') })"
if ($script:Fail) { exit 1 }
exit 0
