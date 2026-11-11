param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-fixA-e) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out.
# Copie adaptee par la RC6 (10/11/2026, v1210\rc6\make_rc6_copies.py, source v1210\rc5\fix2\logic-1210-fixA-d.ps1) : refus de la restauration sans courbe croisee « standard » A -> 0 (2c1eb08) au lieu de « ... en double densite » (A5 : cadre et regles attendus, francais et anglais).
# Copie adaptee par la correction fix2 de la RC5 (10/11/2026, v1210\rc5\fix2\make_fix2_copies.py) : phrase du cadre d un refus faute de courbe croisee : refus de la restauration au lancement (A5).
# Correction fixA de la RC5 12.10 (10/11/2026, v1210\rc5\fixA), d apres la relecture r9 de la RC4 (v1210\rc4\revue\r9-f02fc43,
# r9-restore.ps1, dont le cadre est repris : fonctions reelles extraites des modules par l arbre syntaxique, ecrites dans un
# fichier de travail puis chargees par dot-source ; controles WinForms reels jamais affiches ; bouchons pilotes par $script:S).
#  B-RS-CADRE-FMT : cadre « 2. Calibration du lecteur » (Get-RsCalibText) selon le format de la restauration : copie de flux
#      sans phrase du lecteur cible ; format haute densite choisi pour un lecteur cible : refus en tete, entier dans 262 x 54.
#  m-RS-FLUX-REGLES : regles de la copie (Update-RsRules) et note de l infobulle du cadre (Update-RsCalib) : copie de flux,
#      format haute densite, refus haute densite pour un lecteur cible ; cas d avant inchanges.
#  B-RS-RAPPORT : ligne « Regles » du rapport (Write-RestoreReport reel) d apres la decision de l ecriture ($r.Plan) ou,
#      avant l ecriture, celle du lancement (Get-RestorePlan) ; ligne de journal et decision de Start-RestoreWrite
#      (instructions reelles) ; Start-Restore enregistre le lecteur cible du lancement.
#  m-UN-SEUL-CALCUL : CHANGELOG et commentaires (300 Restore-WriteTabState, 140 Set-WritePreset).
#  Mesures : regles (372 px, 96 a 144 ppp, GDI+ du rendu compatible de Windows PowerShell 5.1) et phrase de refus du cadre.
# Sur la source d avant (f02fc43) : NON CONFORME attendu pour A1 a A4, A7, M1, R1 a R3, J1, S1 a S3 (fixA-test-f02fc43.txt).
# Aucun gw, aucune fenetre, aucun Add-Type, aucune evaluation de texte.
# Correction fixB de la RC5 (10/11/2026, v1210\rc5\fixB) : copie adaptee de v1210\rc5\fixA\logic-1210-fixA, qui la remplace dans la
# campagne : Get-RsCurveSet (300, lu par Update-RsCalib) et Get-LevelBeforeWriteKind (260, lu par
# Update-RsRules et Write-RestoreReport) extraits ; remplacant de Get-HdCalibFamily (format haute densite de la liste).
# Attentes inchangees (Get-Setting du test : liste « Mesure » non posee, regles de la calibration rapide).
# Correction fix1 de la RC5 (10/11/2026, v1210\rc5\fix1) : copie adaptee de v1210\rc5\fixB\logic-1210-fixA-b, qui la
# remplace dans la campagne : lecteur cible sans courbe croisee (refus au lancement) : regles du refus (cle « none »)
# et non l ecriture avec la courbe croisee (A5) ; ligne « Regles » d une restauration arretee avant l ecriture d un
# original reconnu haute densite : « non atteinte » (R-refus-avant, R2) ; CHANGELOG : refus annonce dans les deux cas
# (S3). Autres attentes inchangees.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Import-TestWinForms
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$m = Join-Path $Wt 'src/modules'
if (-not (Test-Path -LiteralPath (Join-Path $m '300-fn-restauration.ps1'))) { throw "modules introuvables sous $Wt" }
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'

$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    if (-not $ok) { $script:Fail++; $script:FailIds += $id }
    '{0,-8} {1,-12} {2}' -f $id, $(if ($ok) { 'conforme' } else { 'NON CONFORME' }), $d
}
function Get-Ast([string]$file) { $tok = $null; $err = $null; return [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tok, [ref]$err) }
function Get-FnAst([string]$file, [string]$n) {
    $fn = @((Get-Ast $file).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | Where-Object { $_.Name -eq $n })
    if ($fn.Count -gt 1) { throw "fonction $n : $($fn.Count) definitions dans $file" }
    if ($fn.Count -eq 0) { return $null }
    return $fn[0]
}
function Get-FnText([string]$file, [string[]]$names, [switch]$Optional) {
    $out = @()
    foreach ($n in $names) {
        $a = Get-FnAst $file $n
        if (-not $a) { if ($Optional) { continue }; throw "fonction $n absente de $file" }
        $out += $a.Extent.Text
    }
    return ($out -join "`r`n`r`n")
}
function Get-Stmt([string]$file, [string]$fn, [string]$typeName, [string]$startsWith) {
    # Texte de l instruction la plus large de la fonction $fn, par son type et son debut ; '' si absente
    $fd = Get-FnAst $file $fn
    $hits = @($fd.Body.FindAll({ param($x) $x.GetType().Name -eq $typeName -and $x.Extent.Text.StartsWith($startsWith) }, $true) | Sort-Object { $_.Extent.Text.Length } -Descending)
    if ($hits.Count -eq 0) { return '' }
    return $hits[0].Extent.Text
}
$f300 = Join-Path $m '300-fn-restauration.ps1'
$hasPlan = [bool](Get-FnAst $f300 'Get-RestorePlan')
# Instructions reelles de Start-RestoreWrite : decision de l ecriture et ligne de journal des regles d ecriture
$sPlan = Get-Stmt $f300 'Start-RestoreWrite' 'AssignmentStatementAst' '$r.Plan = if'
$sLog = Get-Stmt $f300 'Start-RestoreWrite' 'IfStatementAst' 'if ($r.Plan -eq ''flux'')'
if (-not $sLog) { $sLog = Get-Stmt $f300 'Start-RestoreWrite' 'PipelineAst' 'Append-Log ((T "Restauration : écriture tête par tête, {0} essais par piste' }
if (-not $sLog) { throw 'ligne de journal des regles d ecriture introuvable dans Start-RestoreWrite' }
$code = (Get-FnText $f300 @('Get-RestoreFormat', 'Get-RsCalibText', 'Get-RestoreTargetInfo', 'Update-RsCalib', 'Update-RsRules', 'Write-RestoreReport', 'Get-RestoreStem')) + "`r`n`r`n" +
        (Get-FnText $f300 @('Get-RestorePlan', 'Get-RsCurveSet') -Optional) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '260-fn-calib-rapide.ps1') @('Get-LevelBeforeWriteKind') -Optional) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '220-fn-profil-precomp.ps1') @('Get-CurveDate')) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '230-fn-calib-courbe.ps1') @('Get-CalibFamilyName')) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '150-fn-pistes-densite.ps1') @('Test-HdFormat')) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '120-fn-configuration.ps1') @('Update-SettingDependents')) + "`r`n`r`n" +
        "function Invoke-WritePlan(`$r) {`r`n    $sPlan`r`n    $sLog`r`n}`r`n"
$gen = Join-Path $here 'gen-1210-fixA-e.ps1'
[System.IO.File]::WriteAllText($gen, $code, (New-Object System.Text.UTF8Encoding($true)))
. $gen
function Get-HdCalibFamily([string]$p, [string]$f) { if ($f -and $f -ne 'auto' -and (Test-HdFormat $f)) { return 'hd' }; return '' }   # fixB (RC5) : Get-RsCurveSet
$fl = (Get-Content -LiteralPath (Join-Path $m '040-etat-formats.ps1') -Encoding UTF8 -Raw)
if ($fl -notmatch "restoreFormat\s*=\s*@\{[^\r\n]*\r?\n\s*Codes = @\(([^)]*)\)") { throw 'codes de restoreFormat introuvables' }
$codes = @([regex]::Matches($Matches[1], "'([^']*)'") | ForEach-Object { $_.Groups[1].Value })
$rr = (Get-Content -LiteralPath (Join-Path $m '580-etat-restauration.ps1') -Encoding UTF8 -Raw)
if ($rr -notmatch '\$script:RestoreRules = @\{ ReadRevs = (\d+); ReadRetries = (\d+); SeekRetries = (\d+); WriteRetries = (\d+); RepairPasses = (\d+)') { throw 'RestoreRules introuvable' }
$script:RestoreRules = @{ ReadRevs = [int]$Matches[1]; ReadRetries = [int]$Matches[2]; SeekRetries = [int]$Matches[3]; WriteRetries = [int]$Matches[4]; RepairPasses = [int]$Matches[5] }
$RR = $script:RestoreRules
$script:Version = '12.10'
"source : $Wt ; Get-RestorePlan $(if ($hasPlan) { 'presente' } else { 'ABSENTE' }) ; decision de l ecriture (Start-RestoreWrite) $(if ($sPlan) { 'presente' } else { 'ABSENTE' }) ; formats de la liste : $($codes -join ', ')"

# --- Controles et bouchons ---------------------------------------------------------------------------------------------
$font = New-Object System.Drawing.Font('Segoe UI', 9.75)
$tip = New-Object System.Windows.Forms.ToolTip
$lblRsCal = New-Object System.Windows.Forms.Label; $lblRsCal.Font = $font; $lblRsCal.Size = '262,54'; $lblRsCal.AutoEllipsis = $true; $lblRsCal.UseCompatibleTextRendering = $true
$lblRsRules = New-Object System.Windows.Forms.Label; $lblRsRules.Font = $font; $lblRsRules.UseCompatibleTextRendering = $true
$lblRsRules.AutoSize = $true; $lblRsRules.MinimumSize = New-Object System.Drawing.Size(372, 0); $lblRsRules.MaximumSize = New-Object System.Drawing.Size(372, 0)
$btnRsCurve = New-Object System.Windows.Forms.Button
$cmbDrive = [pscustomobject]@{ Text = 'A' }
$script:S = @{}
function Get-Setting([string]$k) { if ($k -eq 'restoreFormat') { return [string]$script:S.Fmt }; return $null }
function Get-TargetDrive([string]$src = '') { return [string]$script:S.Tgt }
function Get-ImageEncoding([string]$p, [string]$f) { return @{ NonMfm = $false; Enc = 'mfm' } }   # formats de la liste : MFM
$cvOwn = @{ Drive = 'A'; Spec = '0=70:40=100'; Date = '01/11/2026 10:00'; Converged = $true }
function Get-FamilyCurves([string]$fam, [bool]$heads) { return ,@($cvOwn) }
$cx = @{ Spec = '0=90:40=130'; Date = '20/10/2026 09:00'; Test = 'std' }
function Get-TargetCurves($fam, $slow, $src, $tgt) {
    if (-not $script:S.Tgt -or $fam -ne 'std') { return }
    switch ([string]$script:S.Cross) { 'common' { $cx } 'head' { if ($slow) { $cx; $cx } } default { } }
}
$script:Calls = @()
function Update-RsFmtFound { $script:Calls += 'Update-RsFmtFound' }
foreach ($n in 'Update-SlowUi', 'Update-RsDrive', 'Update-CmpFmtFound', 'Reset-LibDat') { Set-Item -Path "function:$n" -Value { } }
$script:LogL = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$s) { $script:LogL.Add($s) }
$script:RsStepNames = @('Lire', 'Verifier', 'Changer', 'Sonder', 'Calibrer', 'Ecrire', 'Controler', 'Comparer')
$script:LastCheck = $null

# --- Textes attendus, ecrits ici (independants du code) -----------------------------------------------------------------
$hdF = @('amiga.amigados_hd', 'ibm.1440')
function Get-ExpKind([string]$fmt, [string]$tgt) {
    if ($fmt -eq 'flux') { return 'flux' }
    if ($tgt -and $hdF -contains $fmt) { return 'refused' }
    if ($tgt) { return 'target' }
    if ($hdF -contains $fmt) { return 'hd' }
    return 'sector'
}
$E = @{
    fr = @{
        sector = "Règles appliquées à la copie : disquette de destination mesurée avant l'écriture quand c'est possible (calibration rapide), écriture tête par tête avec la calibration existante du lecteur (calibration par tête si aucune n'existe), effacement avant l'écriture, vérification par gw, {0} essais par piste, contrôle de toutes les pistes ({1} passes de réécriture au plus), puis relecture et comparaison avec l'original."
        target = "Règles appliquées à la copie : écriture tête par tête par le lecteur {2} avec la courbe croisée {2} → {3}, telle quelle, sans calibration ni mesure de la destination, effacement avant l'écriture, vérification par gw, {0} essais par piste, contrôle de toutes les pistes ({1} passes de réécriture au plus), puis relecture par le lecteur {2} et comparaison avec l'original."
        flux = "Règles appliquées à la copie : copie exacte du flux, écrite telle quelle par gw (ni précompensation, ni vérification par gw), sans calibration du lecteur ni mesure de la destination, écriture tête par tête, effacement avant l'écriture, contrôle de toutes les pistes ({1} passes de réécriture au plus), sans comparaison secteur par secteur avec l'original."
        refused = "Règles appliquées à la copie : aucune avec le lecteur cible {3}, la restauration au format haute densité {4} sera refusée au lancement (la calibration croisée n'existe qu'en double densité). Choisissez « (même lecteur) » dans la liste « Lecteur cible » de l'onglet Écriture."
        none = "Règles appliquées à la copie : aucune avec le lecteur cible {3} : sans courbe croisée standard {2} → {3}, la restauration sera refusée au lancement. Lancez « Calibrer pour un lecteur cible… », ou choisissez « (même lecteur) » dans la liste « Lecteur cible » de l'onglet Écriture."
        hd = "Règles appliquées à la copie : écriture tête par tête avec la courbe haute densité existante du lecteur, sinon le profil d'origine, sans calibration ni mesure de la destination (jamais en haute densité), pré-effacement de chaque piste, vérification par gw, {0} essais par piste, sans contrôle des pistes (non applicable à la haute densité), puis relecture et comparaison avec l'original."
        nSector = "Une calibration existante n'est jamais refaite par la restauration. Sans courbe, le lecteur est calibré tête par tête en test fin, éventuellement sur une disquette sacrifiée, avant l'écriture de la copie."
        nHd = "La restauration ne calibre jamais le lecteur en haute densité : la copie est écrite avec la courbe haute densité existante, sinon avec le profil d'origine."
        nFlux = "Une copie exacte du flux est écrite telle quelle par gw, sans précompensation : aucune de ces courbes ne s'y applique, et la restauration ne calibre pas le lecteur ni ne mesure la destination."
        cRef = "Lecteur cible {3} : aucune calibration croisée en haute densité, la restauration au format {4} sera refusée."
        cNone = 'Lecteur cible {3} : aucune courbe croisée standard {2} → {3}, la restauration sera refusée au lancement.'
        cCurve = "Lecteur cible {3} : courbe croisée {2} → {3} ({5}), à la place de celle du lecteur {2}, sans calibration."
        kCommon = 'commune, 20/10/2026'; kHead = 'par tête, 20/10/2026'
    }
    en = @{
        sector = 'Rules applied to the copy: destination disk measured before writing when possible (quick calibration), head-by-head write with the existing drive calibration (per-head calibration if none exists), erase before writing, gw verification, {0} retries per track, check of all tracks (up to {1} rewrite passes), then read-back and comparison with the original.'
        target = 'Rules applied to the copy: head-by-head write by drive {2} with the cross curve {2} → {3}, as is, without calibration or measurement of the destination, erase before writing, gw verification, {0} retries per track, check of all tracks (up to {1} rewrite passes), then read-back by drive {2} and comparison with the original.'
        flux = 'Rules applied to the copy: exact flux copy, written as is by gw (no precompensation, no gw verification), without drive calibration or measurement of the destination, head-by-head write, erase before writing, check of all tracks (up to {1} rewrite passes), no sector-by-sector comparison with the original.'
        refused = 'Rules applied to the copy: none with target drive {3}, the restore in high-density format {4} will be refused at start (cross calibration exists in double density only). Choose "(same drive)" in the "Target drive" list of the Write tab.'
        none = 'Rules applied to the copy: none with target drive {3}: without a standard cross curve {2} → {3}, the restore will be refused at start. Run "Calibrate for a target drive…", or choose "(same drive)" in the "Target drive" list of the Write tab.'
        hd = "Rules applied to the copy: head-by-head write with the drive's existing high-density curve, otherwise the original profile, no calibration or destination measurement (never in high density), pre-erase of each track, gw verification, {0} retries per track, no track check (not applicable to high density), then read-back and comparison with the original."
        nSector = 'The restore never redoes an existing calibration. Without a curve, the drive is calibrated head by head with the fine test, possibly on a sacrificial disk, before the copy is written.'
        nHd = 'The restore never calibrates the drive in high density: the copy is written with the existing high-density curve, otherwise with the original profile.'
        nFlux = 'An exact flux copy is written as is by gw, without precompensation: none of these curves applies to it, and the restore neither calibrates the drive nor measures the destination.'
        cRef = 'Target drive {3}: no cross calibration in high density, the restore in format {4} will be refused.'
        cNone = 'Target drive {3}: no standard cross curve {2} → {3}, the restore will be refused at start.'
        cCurve = "Target drive {3}: cross curve {2} → {3} ({5}), instead of drive {2}'s curve, without calibration."
        kCommon = 'common, 20/10/2026'; kHead = 'per-head, 20/10/2026'
    }
}
function Get-Exp([string]$lg, [string]$key, [string]$src, [string]$tgt, [string]$fmt, [string]$kd = '') {
    return ($E[$lg][$key] -f "$($RR.WriteRetries)", "$($RR.RepairPasses)", $src, $tgt, $fmt, $kd)
}

# --- A. Matrice : format x lecteur cible x courbe croisee x langue -----------------------------------------------------
"--- A : cadre 2, infobulle et regles de la copie selon le format de la restauration"
$rows = @()
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    foreach ($src in 'A', '0') {
        $cmbDrive.Text = $src
        foreach ($fmt in $codes) {
            foreach ($tc in @(@{ N = 'sans cible'; Tgt = ''; Cross = '' }, @{ N = 'commune'; Tgt = $(if ($src -eq 'A') { '0' } else { 'B' }); Cross = 'common' }, @{ N = 'par tete'; Tgt = $(if ($src -eq 'A') { '0' } else { 'B' }); Cross = 'head' }, @{ N = 'aucune'; Tgt = $(if ($src -eq 'A') { '3' } else { 'A' }); Cross = 'none' })) {
                $script:S = @{ Fmt = $fmt; Tgt = ''; Cross = '' }; $rest = Get-RsCalibText
                $script:S = @{ Fmt = $fmt; Tgt = $tc.Tgt; Cross = $tc.Cross }
                $lblRsCal.Text = ''; $tip.SetToolTip($lblRsCal, ''); $lblRsRules.Text = ''
                Update-RsCalib
                $rf = Get-RestoreFormat
                $k = Get-ExpKind $fmt $tc.Tgt
                # cadre attendu
                $head = ''
                if ($k -eq 'refused') { $head = Get-Exp $lg 'cRef' $src $tc.Tgt $rf }
                elseif ($k -eq 'target' -and $tc.Cross -eq 'none') { $head = Get-Exp $lg 'cNone' $src $tc.Tgt $rf }
                elseif ($k -eq 'target') { $head = Get-Exp $lg 'cCurve' $src $tc.Tgt $rf $(if ($tc.Cross -eq 'head') { $E[$lg].kHead } else { $E[$lg].kCommon }) }
                $eCal = if ($head) { $head + ' ' + $rest } else { $rest }
                $note = switch ($k) { 'sector' { $E[$lg].nSector } 'hd' { $E[$lg].nHd } 'flux' { $E[$lg].nFlux } default { '' } }
                $eTip = if ($note) { $eCal + "`n`n" + $note } else { $eCal }
                $eRul = if ($k -eq 'target' -and $tc.Cross -eq 'none') { Get-Exp $lg 'none' $src $tc.Tgt $rf } else { Get-Exp $lg $k $src $tc.Tgt $rf }
                $gCal = [string]$lblRsCal.Text; $gTip = [string]$tip.GetToolTip($lblRsCal); $gRul = [string]$lblRsRules.Text
                # decision de Start-Restore (refus au lancement) : Get-RestoreTargetInfo reel
                $ti = Get-RestoreTargetInfo $src $tc.Tgt $rf
                $rows += [pscustomobject]@{ Lang = $lg; Src = $src; Fmt = $fmt; Case = $tc.N; Tgt = $tc.Tgt; Kind = $k; Block = [bool]$ti.Block
                    OkCal = ($gCal -ceq $eCal); OkTip = ($gTip -ceq $eTip); OkRul = ($gRul -ceq $eRul); Cal = $gCal; Tip = $gTip; Rul = $gRul; ECal = $eCal; ERul = $eRul; ETip = $eTip; Head = $head }
            }
        }
    }
}
$script:Lang = 'fr'; $cmbDrive.Text = 'A'
$bad = @($rows | Where-Object { -not ($_.OkCal -and $_.OkTip -and $_.OkRul) })
foreach ($x in @($bad | Select-Object -First 10)) {
    "  ECART [$($x.Lang) $($x.Src) -> $(if ($x.Tgt) { $x.Tgt } else { '-' }) | $($x.Fmt) | $($x.Case)] cadre $($x.OkCal), infobulle $($x.OkTip), regles $($x.OkRul)"
    if (-not $x.OkCal) { "     cadre « $($x.Cal) »`n     attendu « $($x.ECal) »" }
    if (-not $x.OkRul) { "     regles « $($x.Rul) »`n     attendu « $($x.ERul) »" }
    if (-not $x.OkTip) { "     infobulle « $($x.Tip -replace "`n", ' | ') »" }
}
if ($bad.Count -gt 10) { "  ... $($bad.Count - 10) autre(s) ecart(s)" }
"  cas joues : $($rows.Count) ; ecarts : $($bad.Count) ; par decision attendue : $(($rows | Group-Object Kind | ForEach-Object { "$($_.Name) $($_.Count)" }) -join ', ')"
$gF = @($rows | Where-Object { $_.Fmt -eq 'flux' }); $gR = @($rows | Where-Object { $_.Kind -eq 'refused' }); $gH = @($rows | Where-Object { $_.Kind -eq 'hd' })
$gO = @($rows | Where-Object { $_.Kind -in 'sector', 'target' })
Chk 'A1' ($gF.Count -eq 16 -and @($gF | Where-Object { -not ($_.OkCal -and $_.OkTip) }).Count -eq 0 -and @($gF | Where-Object { $_.Cal -match 'Lecteur cible|Target drive' }).Count -eq 0) "copie exacte du flux, avec ou sans lecteur cible (courbe croisee commune, par tete, aucune) : cadre sans phrase du lecteur cible (identique au cadre sans lecteur cible), infobulle = cadre puis la note de la copie de flux (« ecrite telle quelle par gw, sans precompensation ... »), sans la phrase de la calibration d un lecteur sans courbe ; $($gF.Count) cas, francais et anglais"
Chk 'A2' ($gR.Count -eq 24 -and @($gR | Where-Object { -not ($_.OkCal -and $_.OkTip -and $_.OkRul -and $_.Block) }).Count -eq 0) "format haute densite choisi pour un lecteur cible (amiga.amigados_hd, ibm.1440 ; courbe croisee commune, par tete, aucune) : refus au lancement par Start-Restore (Get-RestoreTargetInfo reel) ; cadre qui commence par « Lecteur cible X : aucune calibration croisee en haute densite, la restauration au format F sera refusee. », regles « ... aucune avec le lecteur cible X, la restauration au format haute densite F sera refusee au lancement ... », infobulle = cadre seul ; $($gR.Count) cas"
Chk 'A3' (@($gF | Where-Object { -not $_.OkRul }).Count -eq 0 -and @($gF | Where-Object { $_.Rul -match 'mesurée avant|calibration existante|measured before|existing drive calibration|vérification par gw, \d|gw verification, \d' }).Count -eq 0) "copie exacte du flux : regles « copie exacte du flux, ecrite telle quelle par gw (ni precompensation, ni verification par gw), sans calibration du lecteur ni mesure de la destination, ... controle de toutes les pistes (N passes ...), sans comparaison secteur par secteur » ; ni mesure, ni calibration, ni essais de la verification gw annonces"
Chk 'A4' ($gH.Count -eq 8 -and @($gH | Where-Object { -not ($_.OkCal -and $_.OkTip -and $_.OkRul) }).Count -eq 0) "format haute densite sans lecteur cible : regles « ... courbe haute densite existante du lecteur, sinon le profil d origine, sans calibration ni mesure de la destination (jamais en haute densite), pre-effacement ..., sans controle des pistes ... », note « La restauration ne calibre jamais le lecteur en haute densite ... » ; $($gH.Count) cas"
Chk 'A5' ($gO.Count -gt 0 -and @($gO | Where-Object { -not ($_.OkCal -and $_.OkTip -and $_.OkRul) }).Count -eq 0 -and @($gO | Where-Object { $_.Kind -eq 'target' -and $_.Case -eq 'aucune' -and -not $_.Block }).Count -eq 0) "cas inchanges ($($gO.Count)) : detection automatique et formats double densite sans lecteur cible (regles d origine, note de la calibration) ; avec un lecteur cible (variante de la courbe croisee, cadre qui nomme la courbe croisee ou annonce le refus faute de courbe croisee, refus au lancement dans ce cas, infobulle = cadre seul)"

# --- A6/A7. Format change (Update-SettingDependents reel) --------------------------------------------------------------
"--- A7 : format de la restauration change (Update-SettingDependents 'restoreFormat')"
$cmbDrive.Text = 'A'
$script:S = @{ Fmt = 'amiga.amigados'; Tgt = '0'; Cross = 'common' }; Update-RsCalib
$a0 = @{ C = [string]$lblRsCal.Text; R = [string]$lblRsRules.Text; T = [string]$tip.GetToolTip($lblRsCal) }
$seq = @()
foreach ($nf in 'flux', 'ibm.1440', 'auto', 'amiga.amigados') {
    $script:S.Fmt = $nf; $script:Calls = @(); Update-SettingDependents 'restoreFormat'
    $x = $rows | Where-Object { $_.Lang -eq 'fr' -and $_.Src -eq 'A' -and $_.Fmt -eq $nf -and $_.Case -eq 'commune' } | Select-Object -First 1
    $seq += [pscustomobject]@{ F = $nf; Ok = ([string]$lblRsCal.Text -ceq $x.ECal -and [string]$lblRsRules.Text -ceq $x.ERul -and [string]$tip.GetToolTip($lblRsCal) -ceq $x.ETip); Found = @($script:Calls | Where-Object { $_ -eq 'Update-RsFmtFound' }).Count; Cal = [string]$lblRsCal.Text }
}
foreach ($x in $seq) { "  -> $($x.F) : cadre, regles et infobulle attendus $($x.Ok) ; ligne du format detecte refaite $($x.Found) fois ; cadre « $($x.Cal.Substring(0, [math]::Min(90, $x.Cal.Length)))… »" }
Chk 'A7' (@($seq | Where-Object { -not ($_.Ok -and $_.Found -eq 1) }).Count -eq 0 -and $seq[3].Cal -ceq $a0.C) "lecteur A -> 0, courbe croisee commune : amiga.amigados -> flux (phrase du lecteur cible retiree, regles et note de la copie de flux) -> ibm.1440 (refus en tete, regles du refus) -> auto -> amiga.amigados (cadre d origine) ; cadre, regles et infobulle refaits a chaque changement"
$e8 = try { $k1 = $lblRsRules; $k2 = $lblRsCal; $lblRsRules = $null; $lblRsCal = $null; Update-RsRules; Update-RsCalib; 'aucune' } catch { $_.Exception.Message } finally { $lblRsRules = $k1; $lblRsCal = $k2 }
Chk 'A8' ($e8 -eq 'aucune') "Update-RsRules et Update-RsCalib sans les controles de l onglet (demarrage, avant 540) : exception $e8"

# --- M. Mesures --------------------------------------------------------------------------------------------------------
"--- M : mesures (rendu compatible GDI+, Segoe UI)"
$fPx = New-Object System.Drawing.Font('Segoe UI', [single]13.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
function Get-Box([string]$text, [int]$w, [int]$h, [bool]$ell) {
    $bmp = New-Object System.Drawing.Bitmap(4, 4); $g = [System.Drawing.Graphics]::FromImage($bmp)
    $sf = New-Object System.Drawing.StringFormat
    $sf.FormatFlags = [System.Drawing.StringFormatFlags]::LineLimit
    $sf.Trimming = $(if ($ell) { [System.Drawing.StringTrimming]::EllipsisCharacter } else { [System.Drawing.StringTrimming]::None })
    $cf = 0; $lf = 0
    try { [void]$g.MeasureString($text, $fPx, (New-Object System.Drawing.SizeF($w, $h)), $sf, [ref]$cf, [ref]$lf) } finally { $sf.Dispose(); $g.Dispose(); $bmp.Dispose() }
    return @{ Fit = $cf; Lines = $lf }
}
$mc = @()
foreach ($x in $gR) {
    $b = Get-Box $x.Cal 262 54 $false; $be = Get-Box $x.Cal 262 54 $true
    $mc += [pscustomobject]@{ Id = "$($x.Lang) $($x.Src)->$($x.Tgt) $($x.Fmt)"; N = $x.Head.Length; Fit = [math]::Min($b.Fit, $be.Fit); Ok = ($x.Head -and $x.Cal.StartsWith($x.Head) -and $b.Fit -ge $x.Head.Length -and $be.Fit -ge $x.Head.Length) }
}
"  phrase de refus du cadre (262 x 54) : $($mc.Count) textes, $(($mc | Measure-Object N -Maximum).Maximum) car. au plus, $(($mc | Measure-Object Fit -Minimum).Minimum) car. visibles au moins"
Chk 'M1' ($mc.Count -eq 24 -and @($mc | Where-Object { -not $_.Ok }).Count -eq 0) "phrase de refus en haute densite en tete du cadre et entiere dans 262 x 54 px (Segoe UI 13 px, LineLimit, avec et sans points de suspension), francais et anglais, lecteurs A, 0, B, 3"
$res = @()
foreach ($dpi in 96, 120, 144) {
    $sc = $dpi / 96.0; $w = [int][math]::Round(372 * $sc)
    $bmp = New-Object System.Drawing.Bitmap(4, 4); $bmp.SetResolution($dpi, $dpi); $g = [System.Drawing.Graphics]::FromImage($bmp)
    $sf = New-Object System.Drawing.StringFormat; $sf.FormatFlags = [System.Drawing.StringFormatFlags]::LineLimit
    foreach ($lg in 'fr', 'en') {
        $cf = 0; $lfO = 0; [void]$g.MeasureString((Get-Exp 'fr' 'sector' 'A' '' ''), $font, (New-Object System.Drawing.SizeF($w, 10000)), $sf, [ref]$cf, [ref]$lfO)
        foreach ($k in 'sector', 'target', 'flux', 'refused', 'hd') {
            foreach ($v in @(Get-Exp $lg $k 'A' '3' 'amiga.amigados_hd')) {
                $cf = 0; $lf = 0; $h = $g.MeasureString($v, $font, (New-Object System.Drawing.SizeF($w, 10000)), $sf, [ref]$cf, [ref]$lf).Height
                $res += [pscustomobject]@{ Dpi = $dpi; Lang = $lg; K = $k; Lines = $lf; Max = $lfO; Bottom = 232 + $h / $sc }
            }
        }
    }
    $sf.Dispose(); $g.Dispose(); $bmp.Dispose()
}
foreach ($grp in ($res | Group-Object Dpi, Lang)) { "  {0,-8} {1}" -f $grp.Name, (($grp.Group | ForEach-Object { "{0} {1} l. (bas {2:N1})" -f $_.K, $_.Lines, $_.Bottom }) -join ' ; ') }
$over = @($res | Where-Object { $_.Lines -gt $_.Max -or $_.Bottom -gt 516 })
Chk 'M2' ($res.Count -eq 30 -and $over.Count -eq 0) "regles de la copie (372 px, 96 a 144 ppp, francais et anglais) : pas plus de lignes que les regles d origine en francais ($(($res | Select-Object -First 1).Max)), bas sous 516 px (bas de l onglet a la taille par defaut) ; $($over.Count) cas au-dela"
$hdR = @(); foreach ($lg in 'fr', 'en') { $script:Lang = $lg; $script:S = @{ Fmt = 'ibm.1440'; Tgt = ''; Cross = '' }; Update-RsRules; $hdR += $lblRsRules.GetPreferredSize((New-Object System.Drawing.Size(372, 0))).Height }
$script:Lang = 'fr'
"  hauteur preferee du libelle des regles (haute densite) : $($hdR -join ' / ') px (francais / anglais)"

# --- R. Rapport : ligne « Regles » (Write-RestoreReport reel) -----------------------------------------------------------
"--- R : ligne « Regles » du rapport"
$outR = Join-Path $here 'out-rapports'
if (-not (Test-Path -LiteralPath $outR)) { New-Item -ItemType Directory -Path $outR | Out-Null }
$ER = @{
    fr = @{
        sector = "Règles      : lecture {0} tours, {1} essais x {2} séries ; destination mesurée avant l'écriture quand c'est possible (calibration rapide) ; écriture tête par tête, calibration existante conservée (calibration par tête en test fin si aucune n'existe), effacement avant l'écriture (haute fréquence en double densité, pré-effacement en haute densité), vérification gw, {3} essais par piste ; contrôle de toutes les pistes, {4} passes de réécriture au plus ; relecture finale sans nouvel essai."
        flux = "Règles      : lecture {0} tours ; copie exacte du flux, écrite telle quelle par gw (ni précompensation, ni vérification gw), sans calibration du lecteur ni mesure de la destination ; écriture tête par tête, effacement avant l'écriture ; contrôle de toutes les pistes, {4} passes de réécriture au plus ; pas de comparaison secteur par secteur."
        target = "Règles      : lecture {0} tours, {1} essais x {2} séries ; écriture tête par tête par le lecteur {5} avec la courbe croisée {5} → {6}, telle quelle, sans calibration ni mesure de la destination, effacement avant l'écriture, vérification gw, {3} essais par piste ; contrôle de toutes les pistes, {4} passes de réécriture au plus ; relecture finale par le lecteur {5} sans nouvel essai."
        refused = "Règles      : lecture {0} tours, {1} essais x {2} séries ; écriture pour le lecteur cible {6} refusée, rien n'a été écrit."
        refusedNo = "Règles      : lecture {0} tours, {1} essais x {2} séries ; écriture pour le lecteur cible {6} non atteinte (elle serait refusée en haute densité : la calibration croisée n'existe qu'en double densité)."
        hd = "Règles      : lecture {0} tours, {1} essais x {2} séries ; écriture tête par tête avec la courbe haute densité existante du lecteur, sinon le profil d'origine, sans calibration ni mesure de la destination (jamais en haute densité), pré-effacement de chaque piste, vérification gw, {3} essais par piste ; pas de contrôle des pistes (non applicable à la haute densité) ; relecture finale sans nouvel essai."
    }
    en = @{
        sector = 'Rules       : read {0} revolutions, {1} retries x {2} series; destination measured before writing when possible (quick calibration); head-by-head write, existing calibration kept (per-head calibration with the fine test if none exists), erase before writing (high-frequency on double density, pre-erase on high density), gw verification, {3} retries per track; check of all tracks, up to {4} rewrite passes; final read-back without retry.'
        flux = 'Rules       : read {0} revolutions; exact flux copy, written as is by gw (no precompensation, no gw verification), without drive calibration or destination measurement; head-by-head write, erase before writing; check of all tracks, up to {4} rewrite passes; no sector-by-sector comparison.'
        target = 'Rules       : read {0} revolutions, {1} retries x {2} series; head-by-head write by drive {5} with the cross curve {5} → {6}, as is, without calibration or measurement of the destination, erase before writing, gw verification, {3} retries per track; check of all tracks, up to {4} rewrite passes; final read-back by drive {5} without retry.'
        refused = 'Rules       : read {0} revolutions, {1} retries x {2} series; write for target drive {6} refused, nothing was written.'
        refusedNo = 'Rules       : read {0} revolutions, {1} retries x {2} series; write for target drive {6} not reached (it would be refused in high density: cross calibration exists in double density only).'
        hd = "Rules       : read {0} revolutions, {1} retries x {2} series; head-by-head write with the drive's existing high-density curve, otherwise the original profile, no calibration or destination measurement (never in high density), pre-erase of each track, gw verification, {3} retries per track; no track check (not applicable to high density); final read-back without retry."
    }
}
function Get-ExpRep([string]$lg, [string]$k, [string]$drv, [string]$tgt) {
    return ($ER[$lg][$k] -f "$($RR.ReadRevs)", "$($RR.ReadRetries)", "$($RR.SeekRetries + 1)", "$($RR.WriteRetries)", "$($RR.RepairPasses)", $drv, $tgt)
}
function New-Rs([string]$mode, [string]$fmt, [string]$choice, [string]$plan, [string]$target, [string]$tgtChoice, [string]$id) {
    return @{ Mode = $mode; Fmt = $fmt; Choice = $choice; Plan = $plan; Target = $target; TgtChoice = $tgtChoice; Drive = 'A'; Name = $id; Dir = $outR; Found = ''
              Orig = ''; Back = (Join-Path $outR "$id - copie.adf"); Report = (Join-Path $outR "$id - rapport.txt"); Stem = (Join-Path $outR $id); SectorRead = $null; Read = $null
              Level = $null; Preserved = @(); Start = (Get-Date); Steps = @{} }
}
$repCases = @(
    @{ Id = 'R-flux';         Mode = 'flux';   Fmt = '';               Choice = '';               Plan = 'flux';    Target = '';  TgtC = '';  K = 'flux';    Tg = '';  Cross = '' }
    @{ Id = 'R-flux-cible';   Mode = 'flux';   Fmt = '';               Choice = 'auto';           Plan = '';        Target = '';  TgtC = '0'; K = 'flux';    Tg = '0'; Cross = 'common' }
    @{ Id = 'R-cible';        Mode = 'sector'; Fmt = 'amiga.amigados'; Choice = 'amiga.amigados'; Plan = 'target';  Target = '0'; TgtC = '0'; K = 'target';  Tg = '0'; Cross = 'common' }
    @{ Id = 'R-cible-avant';  Mode = '';       Fmt = '';               Choice = 'auto';           Plan = '';        Target = '';  TgtC = '0'; K = 'target';  Tg = '0'; Cross = 'head' }
    @{ Id = 'R-refus';        Mode = 'sector'; Fmt = 'amiga.amigados_hd'; Choice = 'auto';        Plan = 'refused'; Target = '0'; TgtC = '0'; K = 'refused'; Tg = '0'; Cross = 'common' }
    @{ Id = 'R-refus-avant';  Mode = 'sector'; Fmt = 'ibm.1440';       Choice = 'auto';           Plan = '';        Target = '';  TgtC = '0'; K = 'refusedNo'; Tg = '0'; Cross = 'common' }
    @{ Id = 'R-hd';           Mode = 'sector'; Fmt = 'ibm.1440';       Choice = 'ibm.1440';       Plan = 'hd';      Target = '';  TgtC = '';  K = 'hd';      Tg = '';  Cross = '' }
    @{ Id = 'R-hd-avant';     Mode = 'sector'; Fmt = 'amiga.amigados_hd'; Choice = 'amiga.amigados_hd'; Plan = ''; Target = '';  TgtC = '';  K = 'hd';      Tg = '';  Cross = '' }
    @{ Id = 'R-secteur';      Mode = 'sector'; Fmt = 'ibm.720';        Choice = 'ibm.720';        Plan = 'sector';  Target = '';  TgtC = '';  K = 'sector';  Tg = '';  Cross = '' }
    @{ Id = 'R-secteur-avant'; Mode = '';      Fmt = '';               Choice = 'auto';           Plan = '';        Target = '';  TgtC = '';  K = 'sector';  Tg = '';  Cross = '' }
)
$rep = @()
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    foreach ($c in $repCases) {
        $script:S = @{ Fmt = $c.Choice; Tgt = $c.Tg; Cross = $c.Cross }
        $script:Restore = New-Rs $c.Mode $c.Fmt $c.Choice $c.Plan $c.Target $c.TgtC "$($c.Id)-$lg"
        Remove-Item -LiteralPath $script:Restore.Report -ErrorAction SilentlyContinue
        $e = try { Write-RestoreReport $true 'RESTAURATION RÉUSSIE'; '' } catch { $_.Exception.Message }
        $lines = if (Test-Path -LiteralPath $script:Restore.Report) { @(Get-Content -LiteralPath $script:Restore.Report -Encoding UTF8) } else { @() }
        $got = @($lines | Where-Object { $_ -match '^(Règles|Rules) ' })
        $exp = Get-ExpRep $lg $c.K 'A' $c.Tg
        $rep += [pscustomobject]@{ Lang = $lg; Id = $c.Id; K = $c.K; Ok = ($got.Count -eq 1 -and $got[0] -ceq $exp -and -not $e); Got = $(if ($got.Count) { $got[0] } else { "(aucune ligne ; $e)" }); Exp = $exp }
    }
}
$script:Lang = 'fr'; $script:Restore = $null
foreach ($x in @($rep | Where-Object { -not $_.Ok } | Select-Object -First 8)) { "  ECART [$($x.Lang) $($x.Id)] « $($x.Got) »`n     attendu « $($x.Exp) »" }
foreach ($x in @($rep | Where-Object { $_.Lang -eq 'fr' -and $_.Id -in 'R-flux', 'R-cible', 'R-hd' })) { "  [$($x.Id)] « $($x.Got) »" }
$rOk = { param($ids) @($rep | Where-Object { $ids -contains $_.Id -and -not $_.Ok }).Count -eq 0 -and @($rep | Where-Object { $ids -contains $_.Id }).Count -eq 2 * $ids.Count }
Chk 'R1' (& $rOk @('R-flux', 'R-flux-cible')) "copie exacte du flux (decision de l ecriture, ou relance en copie de flux avant l ecriture avec un lecteur cible) : « Regles : lecture 5 tours ; copie exacte du flux, ecrite telle quelle par gw (ni precompensation, ni verification gw), sans calibration du lecteur ni mesure de la destination ; ... ; pas de comparaison secteur par secteur. »"
Chk 'R2' (& $rOk @('R-cible', 'R-cible-avant', 'R-refus', 'R-refus-avant')) "lecteur cible : ecriture par le lecteur A avec la courbe croisee A -> 0, telle quelle, sans calibration ni mesure de la destination, relecture finale par le lecteur A (decision de l ecriture, ou du lancement avant l ecriture) ; refus de l ecriture pour le lecteur cible (haute densite reconnue a la lecture) : « ecriture pour le lecteur cible 0 refusee, rien n a ete ecrit »"
Chk 'R3' (& $rOk @('R-hd', 'R-hd-avant')) "haute densite : « ... courbe haute densite existante du lecteur, sinon le profil d origine, sans calibration ni mesure de la destination (jamais en haute densite), pre-effacement ..., pas de controle des pistes ... ; relecture finale sans nouvel essai. »"
Chk 'R4' (& $rOk @('R-secteur', 'R-secteur-avant')) "copie secteur double densite sans lecteur cible, et detection automatique avant la fin de la detection : ligne d origine, inchangee"

# --- J. Decision et ligne de journal de Start-RestoreWrite (instructions reelles) ---------------------------------------
"--- J : decision de l ecriture et ligne de journal (instructions reelles de Start-RestoreWrite)"
$jl = @{
    fr = @{ flux = "Restauration : copie exacte du flux écrite tête par tête, telle quelle, contrôle de toutes les pistes ({1} passes au plus)."
            hd = "Restauration : écriture tête par tête, {0} essais par piste, sans contrôle des pistes (non applicable à la haute densité)."
            other = "Restauration : écriture tête par tête, {0} essais par piste, contrôle de toutes les pistes ({1} passes au plus)." }
    en = @{ flux = 'Restore: exact flux copy written head by head, as is, check of all tracks (up to {1} passes).'
            hd = 'Restore: head-by-head write, {0} retries per track, no track check (not applicable to high density).'
            other = 'Restore: head-by-head write, {0} retries per track, check of all tracks (up to {1} passes).' }
}
$jr = @()
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    foreach ($c in @(@{ Mode = 'flux'; HD = ''; Target = ''; P = 'flux'; L = 'flux' }, @{ Mode = 'sector'; HD = 'haute densité 1 440 Ko'; Target = ''; P = 'hd'; L = 'hd' },
                     @{ Mode = 'sector'; HD = ''; Target = '0'; P = 'target'; L = 'other' }, @{ Mode = 'sector'; HD = ''; Target = ''; P = 'sector'; L = 'other' })) {
        $rs = @{ Mode = $c.Mode; HD = $c.HD; Target = $c.Target; Plan = '' }
        $script:LogL.Clear()
        $e = try { Invoke-WritePlan $rs; '' } catch { $_.Exception.Message }
        $el = $jl[$lg][$c.L] -f "$($RR.WriteRetries)", "$($RR.RepairPasses)"
        $jr += [pscustomobject]@{ Lang = $lg; Mode = $c.Mode; P = $c.P; Ok = (-not $e -and [string]$rs.Plan -eq $c.P -and $script:LogL.Count -eq 1 -and $script:LogL[0] -ceq $el); Got = "$($rs.Plan) | $($script:LogL -join ' | ') $e"; Exp = "$($c.P) | $el" }
    }
}
$script:Lang = 'fr'
foreach ($x in @($jr | Where-Object { -not $_.Ok } | Select-Object -First 6)) { "  ECART [$($x.Lang) $($x.Mode) $($x.P)] « $($x.Got) »`n     attendu « $($x.Exp) »" }
Chk 'J1' ($jr.Count -eq 8 -and @($jr | Where-Object { -not $_.Ok }).Count -eq 0) "decision enregistree pour le rapport (Plan : flux, hd, target, sector) et ligne de journal des regles d ecriture : copie de flux sans essais de la verification gw, haute densite sans controle des pistes, autres cas inchanges ; francais et anglais"

# --- S. Statique ----------------------------------------------------------------------------------------------------------
"--- S : statique"
$tSr = Get-FnText $f300 @('Start-Restore'); $tSw = Get-FnText $f300 @('Start-RestoreWrite')
$okS1 = $tSr.Contains("Plan = ''; TgtChoice = `$rtg") -and $tSr.IndexOf('$rtg = Get-TargetDrive $drv') -ge 0 -and $tSr.IndexOf('$rtg = Get-TargetDrive $drv') -lt $tSr.IndexOf("TgtChoice = `$rtg") -and $tSw.Contains("`$r.InCall = `$false; `$r.Plan = 'refused'")
Chk 'S1' $okS1 "Start-Restore enregistre la decision a venir (Plan vide) et le lecteur cible du lancement (TgtChoice = `$rtg, apres Get-TargetDrive) ; Start-RestoreWrite enregistre « refused » au refus de l ecriture pour le lecteur cible, avant Fail-Restore"
$ch = Get-Content -LiteralPath (Join-Path $Wt 'CHANGELOG.md') -Encoding UTF8 -Raw
$t227 = Get-FnText $f300 @('Restore-WriteTabState'); $t140 = Get-FnText (Join-Path $m '140-fn-ecriture.ps1') @('Set-WritePreset')
$okS2 = $ch.Contains('même image comprise : un seul calcul pour le format (le profil et la case « Écriture lente » gardent leurs liaisons, comme en 12.9) ;') -and -not $ch.Contains('même image comprise : un seul calcul ;') -and
        -not $t227.Contains('recalcule une seule fois') -and $t227.Contains('gardent leurs liaisons') -and -not $t140.Contains('etait calculee deux fois') -and $t140.Contains('gardent leurs liaisons')
Chk 'S2' $okS2 "m-UN-SEUL-CALCUL : CHANGELOG (« un seul calcul pour le format (le profil et la case « Ecriture lente » gardent leurs liaisons, comme en 12.9) »), commentaires de Restore-WriteTabState (300) et de Set-WritePreset (140) precises"
$c12 = $ch.Substring(0, $ch.IndexOf('## [12.9]'))
$okS3 = $c12.Contains('- **Règles de la copie d''une restauration.**') -and $c12.Contains('format haute densité choisi ou aucune courbe croisée standard, le cadre et le texte des règles annoncent ce refus avant le clic') -and $c12.Contains('`Get-RestorePlan($drv, $tgt, $fmt)`')
Chk 'S3' $okS3 "CHANGELOG 12.10 : entree « Regles de la copie d une restauration » (Corrections), refus haute densite et copie de flux dans la Nouveaute du lecteur cible, ligne des developpeurs (Get-RestorePlan)"

"=== bilan logic-1210-fixA-e : $($script:NChk - $script:Fail) conformes sur $($script:NChk) ; $([int]$sw.Elapsed.TotalSeconds) s$(if ($script:Fail) { ' ; NON CONFORMES : ' + ($script:FailIds -join ', ') })"
if ($script:Fail) { exit 1 }
exit 0
