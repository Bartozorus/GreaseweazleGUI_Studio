param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Before = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 (lot L10) : ligne « Ce qui va se passer » de l onglet Ecriture (specification « onglet-ecriture » § 2.5, corrigee
# par le point bloquant B1 du plan ; amendements « lecteur qui ecrit » et « lecteurs enregistres »).
#  S  statique (arbre syntaxique) : S1 les fonctions qui agissent appellent les decisions extraites (Start-WriteTabWrite :
#     Get-WriteLevelPlan ; Start-LevelBeforeWrite : Get-LevelBeforeWritePlan ; Start-ImageWrite : Get-WriteHeads,
#     Get-WriteErasePlan, Get-WriteSpecPlan, Get-WriteHeadSpecs, Get-WriteCheckPlan) et n appellent plus les fonctions que
#     ces decisions appellent ; S2 Get-WritePlan tire chaque segment de ces memes fonctions ; S3 decisions et phrase sans
#     journal, sans fenetre, sans commande ; S4 appels de la mise a jour (fin d Update-WLevelUi, 520).
#  P1 equivalence de Start-WriteTabWrite (et, derriere elle, des vraies Start-LevelBeforeWrite et Start-ImageWrite) :
#     32 scenarios (ceux du plan, les trois cas de B1, deux lecteurs enregistres sur A) ; commandes gw, demandes, fenetres
#     et lignes de journal, dans l ordre, identiques a celles de d8d80d6 (empreintes relevees sur cette source ; avec
#     -Before, comparaison ligne a ligne). P2 de meme pour Start-ImageWrite appelee seule (24 scenarios : tetes,
#     effacement, profils transmis, controle impose, lecteur cible, restauration).
#  P3 textes exacts (francais, anglais) : exemple de la specification en trois lignes de 512 px.
#  P4 coherence : pour chaque scenario de P1 et P2, refus et mesure annonces = ceux du clic ; sans mesure qui precede,
#     effacement, tetes (ecriture rapide comprise), controle et lecteur cible annonces = commandes et journal du clic.
#  P5 refus en tete, encre d avertissement ; sans image : ligne du lot L9 ; image absente.
#  P6 cas de B1 : « Test rapide » sans reference (refus, premiere phrase du message du clic), case cochee sans reference
#     (sans mesure, raison du journal), image non mesurable sur son contenu (repli au motif, raison du journal) ; revue J :
#     champs d une courbe adaptee et « Test rapide » (la calibration qui precede remplace les champs) : aucun controle
#     impose annonce.
#  P7 cout : memoire par signature ; mise a jour sans changement : aucun calcul ni lecture de l image ; chaque cause
#     d invalidation (image, date du fichier, format, lecteur et sa connexion, lecteur cible, listes, courbes, passes de
#     reecriture, option avancee, courbe adaptee, controle impose) recalcule ; temps medians. U1 : avant l affichage de la
#     fenetre (UiReady faux), aucun calcul.
#  L  deux lecteurs enregistres sur A : la phrase change avec le lecteur et avec sa connexion ; le clic aussi.
#  C  coupe : nom le plus large admis, francais et anglais : segments critiques entiers, phrase dans ses trois lignes,
#     texte complet en infobulle ; refus long : en tete ; zone de la ligne inchangee.
#  N  aucune ligne de journal ni fenetre pendant le calcul de la phrase.
#  I  textes de la section L10 de 019 ; D  CHANGELOG et README.
# Fonctions et instructions reelles extraites par l arbre syntaxique, ecrites dans des fichiers de travail puis chargees
# par dot-source ; controles WinForms reels jamais affiches ; images factices sous le dossier de travail. Aucun gw, aucune
# fenetre, aucune compilation. Non couvert : la mesure, la calibration et l ecriture elles-memes (bouchons qui relevent
# l appel), le rendu reel de la ligne dans la fenetre, une vraie racine reseau (lectures comptees, non chronometrees sur
# un partage).
Import-TestWinForms
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
function Get-Ast([string]$file) {
    $tk = $null; $er = $null
    $a = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $file : $(@($er)[0].Message)" }
    return $a
}
function Get-List($a, [int]$max = 6) {
    $x = @($a); if ($x.Count -eq 0) { return 'aucun' }
    $t = (@($x | Select-Object -First $max) -join ' | '); if ($x.Count -gt $max) { $t += " | ... ($($x.Count))" }
    return $t
}
function Get-PlSha([string]$s, [int]$n = 16) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($s))) -replace '-', '').ToLower().Substring(0, $n) } finally { $h.Dispose() }
}
function Get-PlMod([string]$root, [string]$px) {
    $f = @(Get-ChildItem -LiteralPath (Join-Path $root 'src\modules') -Filter "$px-*.ps1" -File)
    if ($f.Count -ne 1) { throw "module $px introuvable sous $root" }
    return $f[0].FullName
}
$utf8b = New-Object System.Text.UTF8Encoding($true)
$tAsgA = [System.Management.Automation.Language.AssignmentStatementAst]
$tFnA = [System.Management.Automation.Language.FunctionDefinitionAst]
$tCmdA = [System.Management.Automation.Language.CommandAst]
function Write-PlGen([string]$path, $parts) { [System.IO.File]::WriteAllText($path, ((@($parts) -join "`r`n`r`n") + "`r`n"), $utf8b) }
$mods = Join-Path $Wt 'src\modules'
# Table I18n et fonction T (modules 01x), chargees comme par l application
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'

# =====================================================================================================================
'--- S : statique (arbre syntaxique des modules)'
$fnAst = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File)) {
    foreach ($d in (Get-Ast $f.FullName).FindAll({ param($x) $x -is $tFnA }, $false)) { $fnAst[$d.Name] = $d }
}
function Get-PlCalls([string]$fn) {
    if (-not $fnAst.ContainsKey($fn)) { return ,@() }
    return ,@($fnAst[$fn].Body.FindAll({ param($x) $x -is $tCmdA }, $true) | ForEach-Object { [string]$_.GetCommandName() } | Where-Object { $_ } | Sort-Object -Unique)
}
$s1Want = [ordered]@{
    'Start-WriteTabWrite' = @{ In = @('Get-WriteLevelPlan', 'Start-LevelBeforeWrite', 'Start-ImageWrite'); Out = @('Get-WriteLevelKind', 'Get-LevelWriteSkip', 'Test-WriteLevelWanted', 'Get-TargetWriteInfo', 'Test-FluxImage', 'Test-NonMfmWrite', 'Get-HdCalibFamily') }
    'Start-LevelBeforeWrite' = @{ In = @('Get-LevelBeforeWritePlan'); Out = @('Get-LevelRef', 'Test-ContentMeasurable', 'Get-LevelBeforeWriteKind', 'Get-ImageFamily', 'Get-CalibCylinders') }
    'Start-ImageWrite' = @{ In = @('Get-WriteHeads', 'Get-WriteErasePlan', 'Get-WriteSpecPlan', 'Get-WriteHeadSpecs', 'Get-WriteCheckPlan'); Out = @('Get-TSpecHeads', 'Get-ImageTrackSet', 'Test-ImageHighDensity', 'Get-EraseMode', 'Get-WriteEraseKeys', 'Test-ScpDensityUnknown', 'Get-EraseFallbackNote', 'Test-RawFluxWrite', 'Test-LevelAdaptedSpec', 'Get-WriteCheckBlocker') }
}
$s1Bad = @()
foreach ($k in @($s1Want.Keys)) {
    $c = Get-PlCalls $k
    foreach ($x in $s1Want[$k].In) { if ($c -notcontains $x) { $s1Bad += "$k n appelle pas $x" } }
    foreach ($x in $s1Want[$k].Out) { if ($c -contains $x) { $s1Bad += "$k appelle encore $x" } }
}
Chk 'S1' ($s1Bad.Count -eq 0) "les fonctions qui agissent appellent les decisions extraites (Get-WriteLevelPlan, Get-LevelBeforeWritePlan, Get-WriteHeads, Get-WriteErasePlan, Get-WriteSpecPlan, Get-WriteHeadSpecs, Get-WriteCheckPlan) et plus les fonctions qu elles appellent : une seule source de chaque decision ; ecarts : $(Get-List $s1Bad)"
$planCalls = Get-PlCalls 'Get-WritePlan'
$s2Need = @('Get-WriteSourceText', 'Get-TargetWriteInfo', 'Get-WriteLevelPlan', 'Get-LevelBeforeWritePlan', 'Get-WriteHeads', 'Get-WriteErasePlan', 'Get-WriteSpecPlan', 'Get-WriteHeadSpecs', 'Get-WriteCheckPlan', 'Get-TargetCurvesText', 'Get-WriteAdvChanges', 'Get-SettingText')
$s2Miss = @($s2Need | Where-Object { $planCalls -notcontains $_ })
# Aucune decision recopiee : la phrase n appelle aucune des fonctions que les decisions appellent elles-memes
$s2Own = @(@('Get-WriteLevelKind', 'Get-LevelWriteSkip', 'Get-LevelRef', 'Test-ContentMeasurable', 'Get-TSpecHeads', 'Get-ImageTrackSet', 'Get-EraseMode', 'Test-LevelAdaptedSpec', 'Get-WriteCheckBlocker', 'Test-WriteLevelWanted', 'Get-LevelBeforeWriteKind') | Where-Object { $planCalls -contains $_ })
Chk 'S2' ($s2Miss.Count -eq 0 -and $s2Own.Count -eq 0) "Get-WritePlan tire ses segments des fonctions de decision (lecteur qui ecrit, lecteur cible, mesure, tetes, effacement, profils, controle, options avancees) et ne recopie aucune regle (aucun appel aux fonctions qu elles appellent) ; absentes : $(Get-List $s2Miss) ; recopiees : $(Get-List $s2Own)"
$s3Fns = @('Get-WritePlan', 'Get-WritePlanSig', 'Get-WritePlanCached', 'Format-WritePlan', 'Get-WPlanHeight', 'Show-WritePlan', 'Update-WritePlanUi', 'Get-WriteLevelPlan', 'Get-LevelBeforeWritePlan', 'Get-WriteHeads', 'Get-WriteErasePlan', 'Get-WriteSpecPlan', 'Get-WriteHeadSpecs', 'Get-WriteCheckPlan')
$s3Bad = @()
foreach ($fn in $s3Fns) {
    if (-not $fnAst.ContainsKey($fn)) { $s3Bad += "$fn absente"; continue }
    foreach ($c in (Get-PlCalls $fn)) { if ($c -match '^(Append-Log|Show-App\w+|Show-\w+Dialog|Start-\w+|Invoke-\w+|Set-Busy|Save-Config|Backup-\w+|Set-Setting|Update-PrecompForImage)$') { $s3Bad += "$fn appelle $c" } }
}
Chk 'S3' ($s3Bad.Count -eq 0) "$($s3Fns.Count) fonctions (decisions extraites, phrase, memoire, affichage) : ni journal, ni fenetre, ni commande, ni enregistrement, ni reglage ; ecarts : $(Get-List $s3Bad)"
$wl = $fnAst['Update-WLevelUi']
$wlLast = [string]@($wl.Body.EndBlock.Statements)[-1].Extent.Text
$s520 = [System.IO.File]::ReadAllText((Get-PlMod $Wt '520'), [System.Text.Encoding]::UTF8)
$s4 = @(($wlLast -ceq 'if ($lblWPlan) { Update-WritePlanUi }'), $s520.Contains('foreach ($wPlanCtl in @($chkWPreErase, $chkWPostCheck, $txtWPrecomp, $txtWPrecomp1)) { Register-WPlanCtl $wPlanCtl }'),
        $s520.Contains('$lblWPlan.Add_SizeChanged({ Show-WritePlan })'), $s520.Contains("`$lblWPlan.Location = '270,295'; `$lblWPlan.Size = '502,58'"))
Chk 'S4' (@($s4 | Where-Object { -not $_ }).Count -eq 0) "mise a jour : derniere instruction d Update-WLevelUi $($s4[0]) ; cases et champs ajoutes (520) $($s4[1]) ; largeur changee : phrase refaite sans recalcul $($s4[2]) ; ligne a sa place et a sa taille du lot L9 (270,295, 502 x 58) $($s4[3])"

# =====================================================================================================================
# Construction de l onglet : fichiers de travail par source (fonctions de tous les modules fn, etat, instructions de 500,
# 510, 520, 540 et partie Ecriture de Set-Defaults), comme logic-ecriture-onglet
$plCtl = @('txtWFile', 'btnWFile', 'cmbWFmt', 'chkWPreErase', 'chkWSlow', 'chkWPostCheck', 'chkWUnattended', 'chkWLevel', 'cmbWLevelMode', 'cmbWTarget', 'cmbWCalMode', 'btnWCalib', 'btnWCross', 'btnWCurve', 'btnWrite',
           'chkWEraseEmpty', 'chkWNoVerify', 'numWRetries', 'numWRepair', 'cmbWProfile', 'chkWPrecomp', 'txtWPrecomp', 'txtWPrecomp1', 'txtWTracks', 'cmbWDensel', 'txtWFakeIdx', 'chkWReverse', 'txtWDiskdefs', 'btnWDiskdefs',
           'chkWHard', 'chkWTG43', 'chkWWarm', 'chkWCalWarm', 'numWWarmMin', 'btnWCalReset', 'btnWCalBack')
function New-PlGen([string]$root, [string]$tag) {
    $g = @{ Root = $root; Tag = $tag }
    $fns = New-Object System.Collections.Generic.List[string]
    foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'src\modules') -Filter '*.ps1' -File | Where-Object { $_.Name -match '^[1-4]\d\d-fn-' } | Sort-Object Name)) {
        foreach ($fd in (Get-Ast $f.FullName).FindAll({ param($x) $x -is $tFnA }, $false)) { $fns.Add($fd.Extent.Text) }
    }
    $g.Fn = Join-Path $here "gen-$tag-fonctions.ps1"; Write-PlGen $g.Fn $fns
    $st = New-Object System.Collections.Generic.List[string]
    foreach ($px in @('000', '020', '040', '550', '560', '565', '570', '580', '590')) {
        foreach ($s in (Get-Ast (Get-PlMod $root $px)).EndBlock.Statements) {
            $t = $s.Extent.Text
            if ($t -match 'Add-Type|EnableVisualStyles') { continue }
            if ($px -eq '020' -and -not ($s -is $tAsgA -and $t.StartsWith('$script:') -and -not $t.StartsWith('$script:AppDir'))) { continue }
            $st.Add($t)
        }
    }
    $g.State = Join-Path $here "gen-$tag-etat.ps1"; Write-PlGen $g.State $st
    $g.U500 = Join-Path $here "gen-$tag-500.ps1"
    Write-PlGen $g.U500 @((Get-Ast (Get-PlMod $root '500')).EndBlock.Statements | Where-Object { $_.Extent.Text -notmatch 'Add-Type' } | ForEach-Object { $_.Extent.Text })
    $ban = @(); $on = $false
    foreach ($s in (Get-Ast (Get-PlMod $root '510')).EndBlock.Statements) {
        $t = $s.Extent.Text
        if ($t.StartsWith('$pnlTop = ')) { $on = $true }
        if ($on) { $ban += $t }
        if ($t.StartsWith('$script:DriveBanner = ')) { $on = $false }
    }
    $g.U510 = Join-Path $here "gen-$tag-510.ps1"; Write-PlGen $g.U510 $ban
    $g.U520 = Join-Path $here "gen-$tag-520.ps1"; Write-PlGen $g.U520 @((Get-Ast (Get-PlMod $root '520')).EndBlock.Statements | ForEach-Object { $_.Extent.Text })
    $g.U540 = Join-Path $here "gen-$tag-540.ps1"
    Write-PlGen $g.U540 @((Get-Ast (Get-PlMod $root '540')).EndBlock.Statements | Where-Object { $_.Extent.Text -match '^(Set-Btn\s+|Set-Cue\s+|\$tip\.SetToolTip\()\$(\w+)\b' -and $plCtl -contains $Matches[2] } | ForEach-Object { $_.Extent.Text })
    $sd = @((Get-Ast (Get-PlMod $root '120')).FindAll({ param($x) $x -is $tFnA -and $x.Name -eq 'Set-Defaults' }, $false))
    $ds = @($sd[0].Body.EndBlock.Statements | Where-Object { $_.Extent.Text -match '\$(txtW|cmbW|chkW|numW|lblW)' -or $_.Extent.Text -match '^(Reset-Settings|Update-SlowUi|Update-TargetDriveUi)$' } | ForEach-Object { $_.Extent.Text })
    $g.Def = Join-Path $here "gen-$tag-defauts.ps1"
    Write-PlGen $g.Def @("function Invoke-PlDefaults {`r`n" + ($ds -join "`r`n") + "`r`n}")
    return $g
}
function Set-PlStubs {
    # Bouchons : gw, fenetres, journal, prechauffage, controle, mesures, calibration rapide, profil de l image et autres
    # onglets ; commandes, demandes et fenetres relevees dans $script:PlTrace, le journal dans $script:PlLog
    function script:Start-Gw([string[]]$gwArgs, [switch]$Soft) { [void]$script:PlTrace.Add('gw ' + ($gwArgs -join ' ')) }
    function script:Invoke-NextChainStep {
        foreach ($q in @($script:WriteQueue.ToArray())) { [void]$script:PlTrace.Add('file ' + (@($q) -join ' ')) }
        if ($script:WriteArgs) { [void]$script:PlTrace.Add('ecriture ' + (@($script:WriteArgs) -join ' ')) }
        [void]$script:PlTrace.Add('etapes ' + $script:Chain.Count)
    }
    function script:Start-WriteWarmup([string]$tspec, [bool]$noWarm) {
        foreach ($q in @($script:WriteQueue.ToArray())) { [void]$script:PlTrace.Add('file ' + (@($q) -join ' ')) }
        [void]$script:PlTrace.Add("prechauffage $tspec $noWarm ; etapes $($script:Chain.Count)")
    }
    function script:New-WriteCheck([string[]]$base, [string]$image, [string]$userTSpec, [int]$max, [string[]]$readOpts, $headPrecomp, [string]$eraseMode = '') {
        $hp = if ($headPrecomp) { "$($headPrecomp[0])/$($headPrecomp[1])" } else { '-' }
        [void]$script:PlTrace.Add("controle base $($base -join ' ') ; pistes $userTSpec ; passes $max ; relecture $($readOpts -join ' ') ; precomp $hp ; effacement $eraseMode")
        $script:Rep = @{}
    }
    function script:Start-LevelCalib($lr, [switch]$NoConfirm, [switch]$NoFallback, $Geom = $null) {
        [void]$script:PlTrace.Add("calibration rapide unites $(@($lr.Units).Count) repli $([bool]$NoFallback)")
        if (-not $script:PlCalFail) { $script:Cal = @{ Mode = 'level' } }
    }
    function script:Start-DiskMeasure($lr, $brand) { [void]$script:PlTrace.Add("mesure complete unites $(@($lr.Units).Count)") }
    function script:Start-ContentMeasure($chk) { [void]$script:PlTrace.Add("mesure sur l image cylindres $($chk.NCyl) commune $($chk.Common)") }
    function script:Show-AppMessage([string]$text, [string]$title, [string]$buttons = 'OK', [string]$icon = 'Information') { [void]$script:PlTrace.Add("message $title $buttons"); [void]$script:PlLog.Add($text); if ($buttons -eq 'YesNo') { return 'No' }; return 'OK' }
    function script:Show-AppConfirm([string]$Title, [string]$Heading, [string]$Text, [string]$Check = '', [string]$GoText = '', [string]$GoGlyph = '', [string]$Level = 'warn', [string]$Picto = 'warn', [string]$AltText = '', $Combo = $null) { [void]$script:PlTrace.Add("confirmation $Title"); [void]$script:PlLog.Add($Text); return $true }
    function script:Show-Tab($t) { [void]$script:PlTrace.Add('onglet') }
    function script:Append-Log($t) { [void]$script:PlLog.Add([string]$t) }
    function script:Update-PrecompForImage($p) { [void]$script:PlTrace.Add('profil recalcule') }
    function script:Update-DriveChoice { }
    function script:Update-CurveButton($p) { }
    function script:Update-RsDrive { }
    function script:Update-RsRules { }
    function script:Update-RsFmtFound { }
    function script:Update-RsCalib { }
    function script:Update-CmpFmtFound { }
    function script:Reset-LibDat { }
    function script:Save-Config { return $true }
    function script:Set-QualityStale($w) { }
    function script:Render-Banner { }
}

# --- Images factices
$plImg = Join-Path $here 'img'
if (-not (Test-Path -LiteralPath $plImg)) { [void](New-Item -ItemType Directory -Path $plImg -Force) }
function New-PlFile([string]$name, [byte[]]$bytes) { $p = Join-Path $plImg $name; [System.IO.File]::WriteAllBytes($p, $bytes); return $p }
function Set-PlBE32([byte[]]$b, [int]$o, [int]$v) { $b[$o] = [byte](($v -shr 24) -band 255); $b[$o + 1] = [byte](($v -shr 16) -band 255); $b[$o + 2] = [byte](($v -shr 8) -band 255); $b[$o + 3] = [byte]($v -band 255) }
$imAdf = New-PlFile 'jeu.adf' (New-Object byte[] 901120)
$imHd = New-PlFile 'hd.adf' (New-Object byte[] 1802240)
$imImg = New-PlFile 'jeu.img' (New-Object byte[] 737280)
$imSsd = New-PlFile 'jeu.ssd' (New-Object byte[] 204800)
$imScp = New-PlFile 'flux.scp' (New-Object byte[] 4096)
# HFE une face (HXCPICFE, MFM, 250 kbit/s, 80 cylindres, une face) : table des pistes au bloc 1
$hl = 12500; $hb = [int][math]::Ceiling($hl / 512.0); $hfe = New-Object byte[] ((2 + 80 * $hb) * 512)
[System.Text.Encoding]::ASCII.GetBytes('HXCPICFE').CopyTo($hfe, 0); $hfe[9] = 80; $hfe[10] = 1; $hfe[11] = 0; $hfe[12] = 250; $hfe[13] = 0; $hfe[18] = 1; $hfe[19] = 0
for ($i = 0; $i -lt 80; $i++) { $o = 2 + $hb * $i; $hfe[512 + 4 * $i] = [byte]($o -band 255); $hfe[513 + 4 * $i] = [byte]($o -shr 8); $hfe[514 + 4 * $i] = [byte]($hl -band 255); $hfe[515 + 4 * $i] = [byte]($hl -shr 8) }
$imHfe1 = New-PlFile 'une-face.hfe' $hfe
# IPF (enregistrement CAPS, 160 enregistrements IMGE de 100 400 bits et 11 blocs) : temps de la phrase (P7)
$ipf = New-Object byte[] (12 + 80 * 160)
[System.Text.Encoding]::ASCII.GetBytes('CAPS').CopyTo($ipf, 0); Set-PlBE32 $ipf 4 12
for ($i = 0; $i -lt 160; $i++) { $o = 12 + 80 * $i; [System.Text.Encoding]::ASCII.GetBytes('IMGE').CopyTo($ipf, $o); Set-PlBE32 $ipf ($o + 4) 80; Set-PlBE32 $ipf ($o + 12) ([int][math]::Floor($i / 2)); Set-PlBE32 $ipf ($o + 16) ($i % 2); Set-PlBE32 $ipf ($o + 48) 100400; Set-PlBE32 $ipf ($o + 52) 11 }
$imIpf = New-PlFile 'jeu.ipf' $ipf

# --- Courbes factices (magasin par lecteur, $script:DriveCurves ; vue du lecteur courant par la vraie Sync-PrecompCurves)
function New-PlCurve([string]$drive, [int]$n = 80, [string]$date = '01/11/2026 10:00', [string]$method = 'motif') {
    $v = [int[]]@(for ($c = 0; $c -lt $n; $c++) { 120 + [int][math]::Floor($c / 2) })
    $cy = [int[]]@(for ($c = 0; $c -lt $n; $c += 4) { $c })
    return @{ Values = $v; Cyls = $cy; Kinds = [string[]]@($cy | ForEach-Object { 'interp' }); Res = [double[]]@($cy | ForEach-Object { 0.5 }); Ys = [double[]]@($cy | ForEach-Object { [double]$v[$_] })
              Sig = [double[]]@($cy | ForEach-Object { 1.0 }); Breaks = @(); Date = $date; Test = 'fine'; Drive = $drive; Method = $method; Bits = 101344; Slope = -1.0; Converged = $true; MaxNs = 400
              Spec = "0=120:$($n - 1)=$($v[$n - 1])"; Calc = '12.10' }
}
function Set-PlCurves([string]$set, [string]$drive = 'A') {
    switch ($set) {
        'commune' { $script:DriveCurves["$drive|std"] = New-PlCurve $drive }
        'motif'   { $script:DriveCurves["$drive|std"] = New-PlCurve $drive; foreach ($h in 0, 1) { $script:DriveCurves["$drive|std_h$h"] = New-PlCurve $drive 80 '01/11/2026 11:00' } }
        'courte'  { $script:DriveCurves["$drive|std"] = New-PlCurve $drive 77; foreach ($h in 0, 1) { $script:DriveCurves["$drive|std_h$h"] = New-PlCurve $drive 77 '01/11/2026 11:00' } }
        'domaine' { $script:DriveCurves["$drive|std"] = New-PlCurve $drive 86 }
        'contenu' { $script:DriveCurves["$drive|std"] = New-PlCurve $drive 80 '01/11/2026 10:00' 'content' }
        'croisee' { $script:DriveCurves["$drive>0|std"] = New-PlCurve "$drive>0" }
    }
    Sync-PrecompCurves
}
$plCodes = @('A', 'B', '0', '1', '2', '3')
function Set-PlDrives([string[]]$names, [string]$pick) {
    # Lecteurs enregistres sur A (fiches du registre, elements de la liste du bandeau), puis lecteur du bandeau
    $i = 0
    foreach ($n in $names) { $i++; $script:DriveReg[$n] = @{ Name = $n; Conn = 'A'; Id = "L20261114-10000$i"; Created = "14/11/2026 10:00:0$i"; From = ''; At = '' }; if (-not $cmbDrive.Items.Contains($n)) { [void]$cmbDrive.Items.Add($n) } }
    $cmbDrive.SelectedItem = $pick
}
function Reset-PlState {
    $script:Restore = $null; $script:GwProc = $null; $script:Cal = $null; $script:AfterCalib = ''; $script:LevelPostForce = $false; $script:WriteFactorNext = $null
    $script:PlCalFail = $false; $script:ScpStatsOk = $true; $script:ScpWeakCache = $null; $script:OpOverride = $null
    $script:DriveReg = [ordered]@{}; $script:TargetDrives = @{}; $script:DriveCurves = @{}; $script:LevelShifts = @{}
    $cmbDrive.SelectedItem = 'A'
    foreach ($x in @($cmbDrive.Items)) { if ($plCodes -notcontains [string]$x) { $cmbDrive.Items.Remove($x) } }
    Invoke-PlDefaults
    Sync-PrecompCurves
}
$plNorm = { param($x) ([string]$x).Replace($plImg, '<img>') }

# Scenarios de P1 (bouton ECRIRE : vraie Start-WriteTabWrite) : image, format (rang 0 : « (auto) »), reglages poses sur les
# controles comme le ferait l utilisateur. Liste « Calibration precomp » : rang 2 « Test rapide » ; liste « Mesure : » :
# 0 sur l image, 1 au motif, 2 complete
$scP1 = @(
    @{ Id = 'S01'; T = 'rapide'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif' } }
    @{ Id = 'S02'; T = 'lente, mesure sur l image'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true } }
    @{ Id = 'S03'; T = 'lente, mesure au motif'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $cmbWLevelMode.SelectedIndex = 1 } }
    @{ Id = 'S04'; T = 'lente, mesure complete'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $cmbWLevelMode.SelectedIndex = 2 } }
    @{ Id = 'S05'; T = 'Test rapide, ecriture rapide'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'commune'; $cmbWCalMode.SelectedIndex = 2 } }
    @{ Id = 'S06'; T = 'B1 : Test rapide sans reference'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $cmbWCalMode.SelectedIndex = 2 } }
    @{ Id = 'S07'; T = 'B1 : case cochee sans reference'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $cmbWLevelMode.SelectedIndex = 1 } }
    @{ Id = 'S08'; T = 'B1 : image non mesurable sur son contenu'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'courte'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true } }
    @{ Id = 'S09'; T = 'lecteur cible avec effet'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; Set-PlCurves 'croisee'; $script:TargetDrives['A'] = '0'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true } }
    @{ Id = 'S10'; T = 'lecteur cible sans effet (Manuel)'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $script:TargetDrives['A'] = '0'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $cmbWProfile.SelectedIndex = 3; $txtWPrecomp.Text = '0=90:40=120' } }
    @{ Id = 'S11'; T = 'lecteur cible refuse'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $script:TargetDrives['A'] = '0'; $chkWSlow.Checked = $true } }
    @{ Id = 'S12'; T = 'flux'; Img = $imScp; Fmt = ''; Do = { $script:ScpStatsOk = $false; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $chkWEraseEmpty.Checked = $false } }
    @{ Id = 'S13'; T = 'FM'; Img = $imSsd; Fmt = ''; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $chkWEraseEmpty.Checked = $false } }
    @{ Id = 'S14'; T = 'haute densite'; Img = $imHd; Fmt = 'amiga.amigados_hd'; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $true } }
    @{ Id = 'S15'; T = 'profil force'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $cmbWProfile.SelectedIndex = 1 } }
    @{ Id = 'S16'; T = 'Manuel'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $cmbWProfile.SelectedIndex = 3; $txtWPrecomp.Text = '0=90:40=120'; $txtWPrecomp1.Text = '0=95' } }
    @{ Id = 'S17'; T = '--precomp decoche'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $chkWPrecomp.Checked = $false } }
    @{ Id = 'S18'; T = 'Pistes c='; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $txtWTracks.Text = 'c=0-39' } }
    @{ Id = 'S19'; T = 'une face'; Img = $imHfe1; Fmt = ''; Do = { Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true } }
    @{ Id = 'S20'; T = 'faces inconnues'; Img = $imImg; Fmt = 'ibm.720'; Do = { Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true } }
    @{ Id = 'S21'; T = 'Test rapide, lente, liste complete'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $cmbWCalMode.SelectedIndex = 2; $cmbWLevelMode.SelectedIndex = 2 } }
    @{ Id = 'S22'; T = 'Test rapide, rapide, liste complete'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'commune'; $cmbWCalMode.SelectedIndex = 2; $cmbWLevelMode.SelectedIndex = 2 } }
    @{ Id = 'S23'; T = 'Test rapide, lente, liste sur l image'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $cmbWCalMode.SelectedIndex = 2 } }
    @{ Id = 'S24'; T = 'Test rapide, reference hors domaine'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'domaine'; $cmbWCalMode.SelectedIndex = 2 } }
    @{ Id = 'S25'; T = 'Test rapide, calibration non lancee'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'commune'; $cmbWCalMode.SelectedIndex = 2; $script:PlCalFail = $true } }
    @{ Id = 'S26'; T = 'deux lecteurs sur A : Sony MPF920'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlDrives @('Sony MPF920', 'TEAC FD-235HF') 'Sony MPF920'; Set-PlCurves 'commune' 'Sony MPF920'; $cmbWCalMode.SelectedIndex = 2 } }
    @{ Id = 'S27'; T = 'deux lecteurs sur A : TEAC FD-235HF'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlDrives @('Sony MPF920', 'TEAC FD-235HF') 'TEAC FD-235HF'; Set-PlCurves 'commune' 'Sony MPF920'; $cmbWCalMode.SelectedIndex = 2 } }
    @{ Id = 'S28'; T = 'lente, case decochee'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $false } }
    # Revue J : reference plus courte que l image, image absente, tetes d une ecriture rapide (h=0 : image a une face gardee
    # apres une ecriture rapide de la Bibliotheque), champs d une courbe adaptee remplaces par la calibration qui precede
    @{ Id = 'S29'; T = 'Test rapide, reference courte (70 cylindres)'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $script:DriveCurves['A|std'] = New-PlCurve 'A' 70; Sync-PrecompCurves; $cmbWCalMode.SelectedIndex = 2 } }
    @{ Id = 'S30'; T = 'Test rapide, image absente'; Img = (Join-Path $plImg 'absente.adf'); Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'commune'; $cmbWCalMode.SelectedIndex = 2 } }
    @{ Id = 'S31'; T = 'rapide, Pistes h=0'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $txtWTracks.Text = 'h=0' } }
    @{ Id = 'S32'; T = 'Test rapide, lente, champs d une courbe adaptee'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $cmbWCalMode.SelectedIndex = 2; $chkWPostCheck.Checked = $false; $txtWPrecomp.Text = '0=111:40=131'; $txtWPrecomp1.Text = '0=112:40=132'; $script:LevelShifts['std_h0|0'] = @{ Model = 'M1'; Spec = '0=111:40=131'; Values = @(111) }; $script:LevelShifts['std_h1|1'] = @{ Model = 'M1'; Spec = '0=112:40=132'; Values = @(112) } } }
)
# Scenarios de P2 (Start-ImageWrite appelee seule : Bibliotheque, fin d une calibration)
$scP2 = @(
    @{ Id = 'W01'; T = 'rapide'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { } }
    @{ Id = 'W02'; T = 'lente'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $chkWSlow.Checked = $true } }
    @{ Id = 'W03'; T = 'lente, h=1'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $chkWSlow.Checked = $true; $txtWTracks.Text = 'h=1' } }
    @{ Id = 'W04'; T = 'lente, hswap, profils par tete'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $chkWSlow.Checked = $true; $txtWTracks.Text = 'h=0-1:hswap'; $txtWPrecomp.Text = '0=100'; $txtWPrecomp1.Text = '0=140' } }
    @{ Id = 'W05'; T = 'lente, une face'; Img = $imHfe1; Fmt = ''; Do = { $chkWSlow.Checked = $true } }
    @{ Id = 'W06'; T = 'lente, faces inconnues'; Img = $imImg; Fmt = 'ibm.720'; Do = { $chkWSlow.Checked = $true } }
    @{ Id = 'W07'; T = 'lente, aucune tete'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $chkWSlow.Checked = $true; $txtWTracks.Text = 'h=2' } }
    @{ Id = 'W08'; T = 'haute densite'; Img = $imHd; Fmt = 'amiga.amigados_hd'; Do = { } }
    @{ Id = 'W09'; T = 'image sans format, pistes inconnues'; Img = $imImg; Fmt = ''; Do = { } }
    @{ Id = 'W10'; T = 'flux, densite inconnue'; Img = $imScp; Fmt = ''; Do = { $script:ScpStatsOk = $false } }
    @{ Id = 'W11'; T = '--densel'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $cmbWDensel.SelectedIndex = 1 } }
    @{ Id = 'W12'; T = 'secteurs durs'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $chkWHard.Checked = $true } }
    @{ Id = 'W13'; T = 'FM, profil Auto'; Img = $imSsd; Fmt = ''; Do = { } }
    @{ Id = 'W14'; T = 'FM, profil Manuel'; Img = $imSsd; Fmt = ''; Do = { $cmbWProfile.SelectedIndex = 3; $txtWPrecomp.Text = '0=80' } }
    @{ Id = 'W15'; T = 'courbe adaptee : controle impose'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $chkWPostCheck.Checked = $false; $txtWPrecomp.Text = '0=111:40=131'; $script:LevelShifts['std|c'] = @{ Model = 'M1'; Spec = '0=111:40=131'; Values = @(111) } } }
    @{ Id = 'W16'; T = 'controle impose par la calibration qui precede'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $chkWPostCheck.Checked = $false; $script:LevelPostForce = $true } }
    @{ Id = 'W17'; T = 'sans effacement'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $chkWPreErase.Checked = $false } }
    @{ Id = 'W18'; T = 'lecteur cible, lente'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlCurves 'croisee'; $script:TargetDrives['A'] = '0'; $chkWSlow.Checked = $true } }
    @{ Id = 'W19'; T = 'restauration sur l original'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $chkWSlow.Checked = $true; $script:Restore = @{ OnOriginal = $true; Saved = $null } } }
    @{ Id = 'W20'; T = 'rapide, Pistes c=0-39, options'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $txtWTracks.Text = 'c=0-39'; $chkWNoVerify.Checked = $true; $numWRetries.Value = 4; $chkWEraseEmpty.Checked = $false } }
    @{ Id = 'W21'; T = 'lecteur enregistre'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { Set-PlDrives @('Sony MPF920', 'TEAC FD-235HF') 'Sony MPF920' } }
    # Revue J : haute densite avec --densel, controle impose par la calibration avec des champs adaptes, effacement haute
    # frequence sans piste a effacer (champ Pistes hors de l image)
    @{ Id = 'W22'; T = 'haute densite, --densel'; Img = $imHd; Fmt = 'amiga.amigados_hd'; Do = { $cmbWDensel.SelectedIndex = 1 } }
    @{ Id = 'W23'; T = 'controle impose par la calibration, champs adaptes'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $chkWPostCheck.Checked = $false; $txtWPrecomp.Text = '0=111:40=131'; $script:LevelShifts['std|c'] = @{ Model = 'M1'; Spec = '0=111:40=131'; Values = @(111) }; $script:LevelPostForce = $true } }
    @{ Id = 'W24'; T = 'rapide, Pistes c=82-83'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { $txtWTracks.Text = 'c=82-83' } }
)
# Empreintes relevees sur d8d80d6 (sortie du test lance avec -Before <export de d8d80d6>) : commandes, demandes et fenetres
# (T), journal (J), par scenario
$plRef = @{
    S01 = 'e624a56728551b44/f6f818805418477f'; S02 = 'f40a6d209d3a2a39/e3b0c44298fc1c14'; S03 = '968e88fda3a51d8b/e3b0c44298fc1c14'; S04 = '23c1adced9b9ae13/e3b0c44298fc1c14'
    S05 = '2cd3a03cd88b533c/5b814566e5ebaa3e'; S06 = 'f7728a08a4f467ef/bafd5731497abed4'; S07 = '582191f22046c9b1/e3c8c2f2a41f0391'; S08 = '968e88fda3a51d8b/84382efb09734831'
    S09 = '3523ef1a80f11555/cd2ca75f20137ace'; S10 = '92a3341d42f81092/1634b78d65c527f7'; S11 = 'b7bf5f6845004cfa/f42f0a5eafa1c47a'; S12 = '7b68ef52a893307b/e086a6737fbfc731'
    S13 = '0ff1729b6eb66c48/a7bb4bdeb3cdc1cb'; S14 = 'f1ce6b44d56f0d8b/6ff328e433b75cae'; S15 = '582191f22046c9b1/8f61a5a7ddbe748b'; S16 = '3523cf60b9ba0ae6/19da9c3fc1b061df'
    S17 = '8a880c566d208a41/389d2fa657c4b469'; S18 = 'feaff7b1bfe8cd05/01c2e762a616aa39'; S19 = '4512b35f0a0fe8ea/85f77b15dba62aee'; S20 = '6d55d92b00395b21/4fa18cb20cadbb58'
    S21 = '23c1adced9b9ae13/e3b0c44298fc1c14'; S22 = '2cd3a03cd88b533c/1a467b75756caa51'; S23 = '968e88fda3a51d8b/5b814566e5ebaa3e'; S24 = '4e59ff6e2740cda2/9878de4f89dfd731'
    S25 = '063cf1106f68eb1e/80ef31cbde4c622b'; S26 = '2cd3a03cd88b533c/5b814566e5ebaa3e'; S27 = 'f7728a08a4f467ef/d879a545c51c9f65'; S28 = '582191f22046c9b1/bd374b7b4cea8134'
    W01 = '4e59ff6e2740cda2/d91545fc0d919c4c'; W02 = '582191f22046c9b1/e6ee499cd7f76208'; W03 = '425749e6b9487375/e76c080455586978'; W04 = 'a450c9ef2015e382/82edac566160419d'
    W05 = '6a04d07d425ab285/8580e0c719eed7d4'; W06 = '6d55d92b00395b21/4fa18cb20cadbb58'; W07 = '6d55d92b00395b21/54ccdbaeb3d51156'; W08 = 'a44563feaafaef93/75c5cb21d5795c23'
    W09 = '987bf20fc91b5ea8/72a8a435aff7675d'; W10 = '2fa1cb915576554b/4cac8bbd5a99794b'; W11 = 'f0cb9b7c4d43e004/ab11bfe34801aca8'; W12 = 'c3f776a698bd39b8/45acba1492f3302e'
    W13 = 'a4536535963d9f2e/c6892cfe17a87002'; W14 = '05dbbd27c6d38abe/90659da571963047'; W15 = '9650771b5d762b87/441ec90c93b63b50'; W16 = 'e624a56728551b44/d91545fc0d919c4c'
    W17 = '631ffd0518b95c25/e3b0c44298fc1c14'; W18 = '16775819cacfcd08/003107d7bbcb5f61'; W19 = '00c2c1d301a051bd/14c560e888fadc45'; W20 = '2c592b23d3f7552e/b1fcd512270daf7a'
    W21 = '6540067d6f40bfc7/3ced2d52945403b0'
    S29 = 'f7728a08a4f467ef/1668d9ade2f6b50f'; S30 = '6d55d92b00395b21/1f4b7b28e2112e12'; S31 = 'e165044055d3712d/49d2313f53684812'; S32 = '968e88fda3a51d8b/5b814566e5ebaa3e'
    W22 = 'f4bee6cfa440639f/75c5cb21d5795c23'; W23 = '9650771b5d762b87/d91545fc0d919c4c'; W24 = 'e6be3a723ef94bfe/e3b0c44298fc1c14'
}

function Invoke-PlScenario($sc, [string]$fn, [bool]$withPlan) {
    # Un scenario : etat remis, image et format, reglages, puis (source testee) la phrase, puis la vraie fonction ; rend
    # les commandes et demandes relevees, le journal, le plan de la phrase et ce que son calcul a ecrit ou ouvert
    Reset-PlState
    $txtWFile.Text = $sc.Img
    if ($sc.Fmt) { $cmbWFmt.SelectedItem = $sc.Fmt } else { $cmbWFmt.SelectedIndex = 0 }
    & $sc.Do
    $plan = $null; $side = 0
    if ($withPlan) {
        $script:PlTrace.Clear(); $script:PlLog.Clear()
        $plan = Get-WritePlan
        $side = $script:PlTrace.Count + $script:PlLog.Count
    }
    $script:PlTrace.Clear(); $script:PlLog.Clear()
    $script:WriteQueue.Clear(); $script:Chain.Clear(); $script:WriteArgs = $null; $script:Rep = $null
    try { if ($fn -eq 'image') { Start-ImageWrite } else { Start-WriteTabWrite } } catch { [void]$script:PlTrace.Add("ERREUR $($_.Exception.Message)") }
    [void]$script:PlTrace.Add("fin calibration=$([bool]$script:Cal) suite=$($script:AfterCalib)")
    return @{ Trace = @($script:PlTrace | ForEach-Object { & $plNorm $_ }); Log = @($script:PlLog | ForEach-Object { & $plNorm $_ }); Plan = $plan; Side = $side; Slow = [bool]$chkWSlow.Checked; Repair = [int]$numWRepair.Value }
}

function Test-PlAgree($r) {
    # P4 : ce que la phrase annonce est ce que le clic a fait. Rend les ecarts
    $bad = @()
    $p = $r.Plan; $tr = @($r.Trace); $lg = @($r.Log)
    $write = @($tr | Where-Object { $_ -match '^(gw write|file write|ecriture write)' })
    $erase = @($tr | Where-Object { $_ -match '^(file|gw) erase .*--hfreq' })
    $meas = @($tr | Where-Object { $_ -match '^(calibration rapide|mesure complete|mesure sur l image)' })
    $ctl = @($tr | Where-Object { $_ -like 'controle *' })
    $started = ($write.Count + $erase.Count + $meas.Count + $ctl.Count + @($tr | Where-Object { $_ -like 'prechauffage*' }).Count) -gt 0
    if ($p.Refuse) { if ($started) { $bad += "refus annonce, mais le clic a lance : $($tr[0])" }; return ,$bad }
    if (-not $started) { $bad += "phrase sans refus, mais le clic n a rien lance : $(Get-List $tr 2)" ; return ,$bad }
    $segs = @($p.Segs | ForEach-Object { [string]$_.T })
    $all = $segs -join ' | '
    # Mesure
    $kt = @{ content = (Get-SettingText 'levelBeforeWriteMode' 'content'); quick = (Get-SettingText 'levelBeforeWriteMode' 'quick'); complete = (Get-SettingText 'levelBeforeWriteMode' 'complete') }
    $mPre = ((T 'mesure de la disquette : {0}') -f '')
    $ms = @($segs | Where-Object { $_.StartsWith($mPre) })
    $want = ''
    if ($ms.Count -eq 1) { foreach ($k in 'content', 'quick', 'complete') { if ($ms[0].StartsWith($mPre + $kt[$k])) { $want = $k } } }
    $got = ''
    if ($meas.Count) { $got = switch -Wildcard ($meas[0]) { 'calibration rapide*' { 'quick' } 'mesure complete*' { 'complete' } default { 'content' } } }
    if ($want -ne $got) { $bad += "mesure annoncee « $want », faite « $got »" }
    if ($meas.Count) { return ,$bad }
    # Ecriture faite sans mesure : effacement, tetes, controle, lecteur cible
    $em = if ($all.Contains((T 'effacement haute fréquence des pistes'))) { 'hfreq' } elseif ($all.Contains((T 'pré-effacement de chaque piste'))) { 'pre' } else { 'none' }
    $pre = @($write | Where-Object { $_.Contains('--pre-erase') }).Count -gt 0
    $eg = if ($erase.Count) { 'hfreq' } elseif ($pre) { 'pre' } else { 'none' }
    if ($em -ne $eg) { $bad += "effacement annonce $em, fait $eg" }
    $hs = @(foreach ($w in $write) { $m = [regex]::Match($w, '--tracks=[^ ]*h=(\d)'); if ($m.Success) { [int]$m.Groups[1].Value } })
    if ($r.Slow) {
        $hw = if ($hs.Count -eq 2) { (T 'écriture tête 0 puis tête 1') } elseif ($hs.Count -eq 1) { (T 'écriture de la tête {0} seule') -f "$($hs[0])" } else { '?' }
    } else {
        # Ecriture rapide (revue J) : tetes de --tracks (h=0 : tete 0 seule), sinon les deux ensemble
        $fh = @(foreach ($w in $write) { $m = [regex]::Match($w, '--tracks=[^ ]*h=(\d)(?![-,\d])'); if ($m.Success) { [int]$m.Groups[1].Value } })
        $hw = if ($write.Count -ne 1) { '?' } elseif ($fh.Count -eq 1) { (T 'écriture de la tête {0} seule') -f "$($fh[0])" } else { (T 'écriture des deux têtes ensemble') }
    }
    if ($segs -notcontains $hw) { $bad += "tetes : ecrites « $hw », phrase « $all »" }
    $cw = $ctl.Count -gt 0
    # Controle annonce : « controle de toutes les pistes, ... » ou « ... impose ... » ; pas « ... non applicable (...) »
    $cPre = (T 'contrôle de toutes les pistes, sans réécriture').Split(',')[0]
    $cNa = ((T 'contrôle de toutes les pistes non applicable ({0})') -f '').TrimEnd('(', ')', ' ')
    $cs = (@($segs | Where-Object { $_.StartsWith($cPre) -and -not $_.StartsWith($cNa) }).Count -gt 0)
    if ($cw -ne $cs) { $bad += "controle annonce $cs, fait $cw" }
    if ($cw -and -not ($ctl[0] -match " ; passes $($r.Repair) ;")) { $bad += "passes de reecriture : $($ctl[0])" }
    $tgtW = @($lg | Where-Object { $_.StartsWith(((T "Écriture pour le lecteur cible {0} : {1}, facteur 1,00.") -f 'X', 'Y').Split('X')[0]) }).Count -gt 0
    $tgtP = $all.Contains(((T 'pour le lecteur cible {0} : {1}') -f 'X', 'Y').Split('X')[0])
    if ($tgtW -ne $tgtP) { $bad += "lecteur cible : ecrit $tgtW, annonce $tgtP" }
    return ,$bad
}

# =====================================================================================================================
$script:PlTrace = New-Object System.Collections.Generic.List[string]
$script:PlLog = New-Object System.Collections.Generic.List[string]
$stOp = New-Object System.Windows.Forms.ToolStripStatusLabel; $status = New-Object System.Windows.Forms.StatusStrip
$plRoots = @()
if ($Before) { $plRoots += @{ Root = (Get-TestRoot $Before); Tag = 'avant'; New = $false } }
$plRoots += @{ Root = $Wt; Tag = 'pl'; New = $true }
$res = @{}
foreach ($pr in $plRoots) {
    "--- construction de l onglet : $(if ($pr.New) { 'source testee' } else { "source d avant le lot ($($pr.Root))" })"
    $g = New-PlGen $pr.Root $pr.Tag
    foreach ($lang in @($(if ($pr.New) { @('fr', 'en') } else { @('fr') }))) {
        $script:AppDir = $here
        . $g.State
        . $g.Fn
        Set-PlStubs
        $script:Lang = $lang
        $script:UiReady = $false; $script:ScpStatsOk = $true
        . $g.U500
        . $g.U510
        . $g.U520
        . $g.U540
        . $g.Def
        $tabW.Font = $form.Font
        Fit-ControlText $tabW
        if ($pr.New) { Set-WriteTabLayout }
        Invoke-PlDefaults
        $script:UiReady = $true
        $tabW.Size = New-Object System.Drawing.Size(792, 516)
        $key = "$($pr.Tag)-$lang"
        $res[$key] = @{ P1 = @{}; P2 = @{} }
        if ($lang -eq 'fr') {
            foreach ($sc in $scP1) { $res[$key].P1[$sc.Id] = Invoke-PlScenario $sc 'tab' $pr.New }
            foreach ($sc in $scP2) { $res[$key].P2[$sc.Id] = Invoke-PlScenario $sc 'image' $pr.New }
        }
        if (-not $pr.New) { continue }
        $L = $lang
        # ------------------------------------------------------------------------- P3 : textes exacts
        if ($L -eq 'fr') { '--- P3 a P7, L, C, N : phrase (source testee)' }
        function Get-PlShown($sc) {
            # Etat d un scenario, puis la mise a jour de l application (fin d Update-WLevelUi, appelee a la sortie
            # d Update-PrecompForImage) : texte affiche, infobulle, encre, texte complet
            Reset-PlState
            $txtWFile.Text = $sc.Img
            if ($sc.Fmt) { $cmbWFmt.SelectedItem = $sc.Fmt } else { $cmbWFmt.SelectedIndex = 0 }
            & $sc.Do
            $n0 = $script:PlTrace.Count + $script:PlLog.Count
            Update-WLevelUi
            $script:PlSide += ($script:PlTrace.Count + $script:PlLog.Count - $n0)
            return @{ Text = [string]$lblWPlan.Text; Tip = [string]$tip.GetToolTip($lblWPlan); Warn = ($lblWPlan.ForeColor.ToArgb() -eq $script:Theme.WarnInk.ToArgb()); Full = [string]$script:WPlanFull; H = (Get-WPlanHeight ([string]$lblWPlan.Text)); Err = [string]$script:WPlanError }
        }
        $script:PlSide = 0
        $want3 = if ($L -eq 'fr') {
            @{ S01 = "Ce qui va se passer : Lecteur qui écrit : A ; effacement haute fréquence des pistes ; écriture des deux têtes ensemble ; contrôle de toutes les pistes, 3 passe(s) de réécriture au plus."
               S02 = "Ce qui va se passer : Lecteur qui écrit : A ; effacement haute fréquence des pistes ; mesure de la disquette : sur l'image à écrire (environ 12 min) ; écriture tête 0 puis tête 1 ; contrôle de toutes les pistes, 3 passe(s) de réécriture au plus." }
        } else {
            @{ S01 = 'What will happen: Writing drive: A; high-frequency erase of the tracks; write of both heads together; full track check, up to 3 rewrite pass(es).'
               S02 = 'What will happen: Writing drive: A; high-frequency erase of the tracks; disk measurement: on the image to write (about 12 min); write of head 0 then head 1; full track check, up to 3 rewrite pass(es).' }
        }
        $p3 = @()
        foreach ($id in 'S01', 'S02') {
            $sh = Get-PlShown @($scP1 | Where-Object { $_.Id -eq $id })[0]
            if ($sh.Text -cne $want3[$id] -or $sh.Tip -ne '' -or $sh.Warn -or $sh.H -gt $lblWPlan.Height -or $sh.Err) { $p3 += "$id « $($sh.Text) » (infobulle « $($sh.Tip) », $($sh.H) px$(if ($sh.Err) { ", erreur $($sh.Err)" }))" }
        }
        "  P3 ($L) : « $($want3['S02']) »"
        Chk "P3$L" ($p3.Count -eq 0 -and $lblWPlan.Width -eq 512 -and $lblWPlan.Height -eq 58) "($L) ecriture rapide et exemple de la specification (ecriture lente mesuree sur l image) : texte exact, premier segment « Lecteur qui ecrit », tient dans les trois lignes de $($lblWPlan.Width) x $($lblWPlan.Height) px sans infobulle ; ecarts : $(Get-List $p3 2)"

        if ($L -eq 'fr') {
            # ----------------------------------------------------------------- P4 : la phrase annonce ce que le clic fait
            $p4 = @(); $p4n = 0
            foreach ($sc in @($scP1 + $scP2)) {
                $r = if ($sc.Id -like 'S*') { $res[$key].P1[$sc.Id] } else { $res[$key].P2[$sc.Id] }
                $p4n++
                foreach ($x in (Test-PlAgree $r)) { $p4 += "$($sc.Id) $x" }
            }
            foreach ($x in @($p4 | Select-Object -First 6)) { "  P4 ECART $x" }
            Chk 'P4' ($p4.Count -eq 0 -and $p4n -eq ($scP1.Count + $scP2.Count)) "$p4n scenarios (bouton ECRIRE et ecriture seule) : refus annonce si et seulement si le clic ne lance rien ; mesure annoncee (sur l image, au motif, complete) = mesure lancee ; ecriture sans mesure : effacement, tetes ecrites, controle et ses passes, lecteur cible annonces = commandes et journal du clic ; ecarts : $(Get-List $p4 3)"
            # ----------------------------------------------------------------- P5 : refus en tete, sans image, image absente
            $s11 = Get-PlShown @($scP1 | Where-Object { $_.Id -eq 'S11' })[0]
            $s20 = Get-PlShown @($scP1 | Where-Object { $_.Id -eq 'S20' })[0]
            $none = Get-PlShown @{ Img = ''; Fmt = 'amiga.amigados'; Do = { } }
            $noneAdv = Get-PlShown @{ Img = ''; Fmt = 'amiga.amigados'; Do = { $chkWNoVerify.Checked = $true } }
            $gone = Get-PlShown @{ Img = (Join-Path $plImg 'absente.adf'); Fmt = 'amiga.amigados'; Do = { } }
            $r11 = $res[$key].P1['S11']; $r20 = $res[$key].P1['S20']
            $p5 = [ordered]@{
                'cible refusee' = ($s11.Warn -and $s11.Text.StartsWith('Écriture refusée : ') -and @($r11.Log)[0] -ceq $s11.Text)
                'faces inconnues' = ($s20.Warn -and $s20.Text -ceq (@($r20.Log)[-1] -replace "`n", ' '))
                'sans image' = ($none.Text -eq '' -and -not $none.Warn -and $none.Tip -eq '')
                'sans image, option' = ($noneAdv.Text -ceq 'Options avancées : Sans vérification.')
                'image absente' = ($gone.Warn -and $gone.Text -ceq 'Fichier image introuvable.')
            }
            "  P5 : cible « $($s11.Text) » ; faces « $($s20.Text) »"
            Chk 'P5' (@($p5.Keys | Where-Object { -not $p5[$_] }).Count -eq 0) "refus a la place de la phrase, a l encre d avertissement, texte du refus du clic (lecteur cible : fenetre de Test-TargetWriteAllowed ; faces inconnues : fenetre de Start-ImageWrite) ; sans image : ligne du lot L9 (vide, ou options avancees nommees) ; image absente : « Fichier image introuvable. » ; ecarts : $(Get-List @($p5.Keys | Where-Object { -not $p5[$_] }))"
            # ----------------------------------------------------------------- P6 : cas de B1
            $b6 = Get-PlShown @($scP1 | Where-Object { $_.Id -eq 'S06' })[0]; $r6 = $res[$key].P1['S06']
            $b7 = Get-PlShown @($scP1 | Where-Object { $_.Id -eq 'S07' })[0]; $r7 = $res[$key].P1['S07']
            $b8 = Get-PlShown @($scP1 | Where-Object { $_.Id -eq 'S08' })[0]; $r8 = $res[$key].P1['S08']
            $b9 = Get-PlShown @($scP1 | Where-Object { $_.Id -eq 'S32' })[0]
            $m6 = [string]@($r6.Log)[-1]; $i6 = $m6.IndexOf(" Rien n'a été écrit.")
            $w7 = [regex]::Match([string](@($r7.Log | Where-Object { $_.StartsWith("Mesure de la disquette avant l'écriture non faite : ") })[0]), "non faite : (.+)\. Écriture avec").Groups[1].Value
            $w8 = [regex]::Match([string](@($r8.Log | Where-Object { $_.StartsWith("Mesure sur l'image non faite (") })[0]), "^Mesure sur l'image non faite \((.+)\) : calibration rapide").Groups[1].Value
            $p6 = [ordered]@{
                'champs adaptes, Test rapide' = (-not $b9.Full.Contains((T 'contrôle de toutes les pistes imposé')) -and $b9.Full.Contains((T 'contrôle complet non demandé')))
                'B1 refus' = ($i6 -gt 0 -and $b6.Warn -and $b6.Text -ceq $m6.Substring(0, $i6) -and @($r6.Trace)[0] -eq 'message Calibration precomp YesNo' -and $b6.Text.Contains("le test rapide n'a pas de référence utilisable pour cette image ("))
                'B1 case cochee' = ($w7 -and -not $b7.Warn -and $b7.Text.Contains(((T 'sans mesure de la disquette ({0})') -f $w7)) -and @($r7.Trace | Where-Object { $_ -like 'file write*' }).Count -eq 2)
                'B1 contenu' = ($w8 -and $b8.Text.Contains(((T "mesure de la disquette : {0}, au lieu de la mesure sur l'image ({1})") -f (Get-SettingText 'levelBeforeWriteMode' 'quick'), $w8)) -and @($r8.Trace)[0] -like 'calibration rapide*')
            }
            "  P6 : « $($b6.Text) » | « $($b7.Text) » | « $($b8.Text) »"
            Chk 'P6' (@($p6.Keys | Where-Object { -not $p6[$_] }).Count -eq 0) "cas de B1 : Test rapide sans reference (refus en tete, premiere phrase du message du clic, rien d ecrit) ; case cochee sans reference (« sans mesure de la disquette (raison) », raison du journal du clic, ecriture des deux tetes) ; image non mesurable sur son contenu (mesure au motif « au lieu de la mesure sur l image », raison du journal, calibration rapide lancee) ; champs d une courbe adaptee au « Test rapide » : la calibration qui precede les remplace, aucun controle impose annonce ; ecarts : $(Get-List @($p6.Keys | Where-Object { -not $p6[$_] }))"

            # ----------------------------------------------------------------- L : deux lecteurs enregistres sur A
            $l1 = Get-PlShown @($scP1 | Where-Object { $_.Id -eq 'S26' })[0]
            $l2 = Get-PlShown @($scP1 | Where-Object { $_.Id -eq 'S27' })[0]
            # Meme registre, lecteur change dans la liste du bandeau : vraie mise a jour de l onglet (gestionnaire de 520), puis
            # fin d Update-PrecompForImage (Update-WLevelUi)
            $cmbDrive.SelectedItem = 'Sony MPF920'; Update-WLevelUi; $l3 = [string]$lblWPlan.Text
            $cmbDrive.SelectedItem = 'TEAC FD-235HF'; Update-WLevelUi; $l4 = [string]$lblWPlan.Text
            # Fiche du Sony passee sur 0 (fenetre « Lecteurs enregistres ») : texte du bandeau inchange, libelle du lecteur change
            $cmbDrive.SelectedItem = 'Sony MPF920'; Update-WLevelUi
            (Get-DriveRecord 'Sony MPF920').Conn = '0'; Update-TargetDriveUi; Update-WLevelUi; $l5 = [string]$lblWPlan.Text; $l5a = @(Get-CommonArgs)[0]
            $ra = $res[$key].P1['S26']; $rb = $res[$key].P1['S27']
            $lw = [ordered]@{
                'Sony' = ($l1.Text.StartsWith('Ce qui va se passer : Lecteur qui écrit : Sony MPF920 (A) ; ') -and $l1.Text.Contains(((T 'mesure de la disquette : {0}') -f (Get-SettingText 'levelBeforeWriteMode' 'quick'))) -and @($ra.Trace)[0] -like 'calibration rapide*')
                'TEAC' = ($l2.Warn -and $l2.Text.StartsWith("Écriture refusée : le test rapide n'a pas de référence") -and @($rb.Trace)[0] -eq 'message Calibration precomp YesNo')
                'changement de lecteur' = ($l3 -ceq $l1.Text -and $l4 -ceq $l2.Text)
                'connexion changee' = ($l5 -ceq $l1.Text.Replace('Sony MPF920 (A)', 'Sony MPF920 (0)') -and $l5a -eq '--drive=0')
            }
            "  L : Sony « $($l1.Text) »"
            "  L : TEAC « $($l2.Text) » ; Sony passe sur 0 : « $l5 » ($l5a)"
            Chk 'L1' (@($lw.Keys | Where-Object { -not $lw[$_] }).Count -eq 0) "deux lecteurs enregistres sur A, Test rapide : Sony (reference) « Lecteur qui ecrit : Sony MPF920 (A) », mesure au motif, et le clic la lance ; TEAC (sans reference) : refus, et le clic refuse ; la phrase suit le lecteur choisi dans la liste du bandeau, et sa connexion ; ecarts : $(Get-List @($lw.Keys | Where-Object { -not $lw[$_] }))"

            # ----------------------------------------------------------------- P7 : memoire par signature, cout
            Reset-PlState
            $txtWFile.Text = $imAdf; $cmbWFmt.SelectedItem = 'amiga.amigados'; Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true
            Update-WLevelUi
            $script:PlOrig = @{}
            foreach ($n in @('Get-WritePlan', 'Get-ImageTrackSet', 'Get-ImageCylinders', 'Get-ImageEncoding', 'Get-ImageFamily', 'Get-PatternBits', 'Test-ContentMeasurable', 'Get-LevelRef', 'Get-WriteEraseKeys')) { $script:PlOrig[$n] = (Get-Command $n -CommandType Function).ScriptBlock }
            $script:PlRuns = 0; $script:PlIo = 0
            function script:Get-WritePlan { $script:PlRuns++; & $script:PlOrig['Get-WritePlan'] @args }
            function script:Get-ImageTrackSet { $script:PlIo++; & $script:PlOrig['Get-ImageTrackSet'] @args }
            function script:Get-ImageCylinders { $script:PlIo++; & $script:PlOrig['Get-ImageCylinders'] @args }
            function script:Get-ImageEncoding { $script:PlIo++; & $script:PlOrig['Get-ImageEncoding'] @args }
            function script:Get-ImageFamily { $script:PlIo++; & $script:PlOrig['Get-ImageFamily'] @args }
            function script:Get-PatternBits { $script:PlIo++; & $script:PlOrig['Get-PatternBits'] @args }
            function script:Test-ContentMeasurable { $script:PlIo++; & $script:PlOrig['Test-ContentMeasurable'] @args }
            function script:Get-LevelRef { $script:PlIo++; & $script:PlOrig['Get-LevelRef'] @args }
            function script:Get-WriteEraseKeys { $script:PlIo++; & $script:PlOrig['Get-WriteEraseKeys'] @args }
            $t0 = [string]$lblWPlan.Text
            $tc = @(); for ($i = 0; $i -lt 20; $i++) { $q = [System.Diagnostics.Stopwatch]::StartNew(); Update-WritePlanUi; $q.Stop(); $tc += $q.Elapsed.TotalMilliseconds }
            $c20 = @{ Runs = $script:PlRuns; Io = $script:PlIo }
            # Une cause d invalidation a la fois : un calcul, et un seul ; puis retour a l etat de depart
            $inv = [ordered]@{
                'date du fichier' = { [System.IO.File]::SetLastWriteTimeUtc($imAdf, [datetime]::UtcNow.AddMinutes(-3)) }
                'image remplacee' = { [System.IO.File]::WriteAllBytes($imAdf, (New-Object byte[] 901120)) }
                'format' = { $cmbWFmt.SelectedIndex = 0 }
                'lecteur' = { $cmbDrive.SelectedItem = 'B' }
                'lecteur cible' = { $script:TargetDrives['A'] = '0' }
                'liste Calibration precomp' = { $cmbWCalMode.SelectedIndex = 2 }
                'liste Mesure' = { $cmbWLevelMode.SelectedIndex = 1 }
                'date d une courbe' = { $script:DriveCurves['A|std_h0'].Date = '02/11/2026 09:00'; Sync-PrecompCurves }
                'case Effacer avant d ecrire' = { $chkWPreErase.Checked = $false }
                'passes de reecriture' = { $numWRepair.Value = 0 }
                'option avancee' = { $chkWNoVerify.Checked = $true }
                'courbe adaptee' = { $script:LevelShifts['std_h0|0'] = @{ Model = 'M1'; Spec = '0=1'; Values = @(1) } }
                'controle impose' = { $script:LevelPostForce = $true }
            }
            $p7 = @(); $p7r = @()
            foreach ($k in @($inv.Keys)) {
                Reset-PlState
                $txtWFile.Text = $imAdf; $cmbWFmt.SelectedItem = 'amiga.amigados'; Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true
                Update-WLevelUi
                $script:PlRuns = 0
                & $inv[$k]
                Update-WLevelUi; Update-WLevelUi
                $p7r += "$k $($script:PlRuns)"
                if ($script:PlRuns -lt 1) { $p7 += "$k : aucun recalcul" }
            }
            # Temps d un calcul complet (sans memoire), ADF et IPF
            $tf = @{}
            foreach ($im in @($imAdf, $imIpf)) {
                Reset-PlState
                $txtWFile.Text = $im; $cmbWFmt.SelectedIndex = 0; Set-PlCurves 'motif'; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true
                $script:PlIo = 0
                $ts = @(); for ($i = 0; $i -lt 20; $i++) { $q = [System.Diagnostics.Stopwatch]::StartNew(); [void](Get-WritePlan); $q.Stop(); $ts += $q.Elapsed.TotalMilliseconds }
                $tf[[System.IO.Path]::GetExtension($im)] = @{ Med = [double](@($ts | Sort-Object)[10]); Io = $script:PlIo / 20 }
            }
            # U1 (revue J) : avant l affichage de la fenetre (UiReady faux), aucun calcul de la phrase ni acces a l image
            Reset-PlState; $txtWFile.Text = $imAdf; $cmbWFmt.SelectedItem = 'amiga.amigados'; Set-PlCurves 'motif'
            $script:UiReady = $false; $script:PlRuns = 0; $script:WPlanMemo = $null; $script:WPlanCur = $null; Update-WLevelUi; $u1 = $script:PlRuns; $u1t = [string]$lblWPlan.Text; $script:UiReady = $true; Update-WLevelUi
            Chk 'U1' ($u1 -eq 0 -and $u1t -eq '') "avant l affichage de la fenetre (UiReady faux) : aucun calcul de la phrase ($u1), ligne du lot L9 « $u1t »"
            $medC = [double](@($tc | Sort-Object)[10])
            "  P7 : 20 mises a jour sans changement : $($c20.Runs) calcul(s), $($c20.Io) lecture(s) de l image, mediane $('{0:0.0}' -f $medC) ms ; calcul complet : ADF $('{0:0.0}' -f $tf['.adf'].Med) ms ($($tf['.adf'].Io) lectures), IPF $('{0:0.0}' -f $tf['.ipf'].Med) ms ($($tf['.ipf'].Io) lectures)"
            "  P7 : recalculs par cause : $($p7r -join ' ; ')"
            Chk 'P7' ($c20.Runs -eq 0 -and $c20.Io -eq 0 -and $p7.Count -eq 0 -and $medC -lt 30 -and [string]$lblWPlan.Text -ne '' -and $t0 -ne '') "memoire par signature : 20 mises a jour sans changement, aucun calcul ni lecture de l image (signature : un acces a la date du fichier), mediane sous 30 ms ; chaque cause d invalidation ($($inv.Count) : date et contenu du fichier, format, lecteur, lecteur cible, deux listes, date d une courbe, case, passes de reecriture, option avancee, courbe adaptee, controle impose) recalcule la phrase ; ecarts : $(Get-List $p7)"
            # Fonctions d origine rendues (cas suivants)
            foreach ($n in @($script:PlOrig.Keys)) { Set-Item -Path "function:script:$n" -Value $script:PlOrig[$n] }
            "  P7 : fonctions d origine rendues : $(@(@($script:PlOrig.Keys) | Where-Object { (Get-Command $_ -CommandType Function).ScriptBlock -eq $script:PlOrig[$_] }).Count) sur $($script:PlOrig.Count)"
        }

        # ----------------------------------------------------------------- C : coupe, nom le plus large admis
        $wide = Get-DriveWidestName $form.Font
        $wide2 = $wide.Substring(0, $wide.Length - 1) + 'M'
        $setWide = {
            $script:DriveReg[$wide] = @{ Name = $wide; Conn = 'A'; Id = 'L20261114-110001'; Created = '14/11/2026 11:00:01'; From = ''; At = '' }
            $script:DriveReg[$wide2] = @{ Name = $wide2; Conn = '0'; Id = 'L20261114-110002'; Created = '14/11/2026 11:00:02'; From = ''; At = '' }
            [void]$cmbDrive.Items.Add($wide); [void]$cmbDrive.Items.Add($wide2)
            $script:TargetDrives[$wide] = $wide2
            $cmbDrive.SelectedItem = $wide
        }
        $advAll = { $chkWNoVerify.Checked = $true; $numWRetries.Value = 4; $chkWEraseEmpty.Checked = $false; $cmbWDensel.SelectedIndex = 1; $txtWFakeIdx.Text = '300rpm'; $chkWReverse.Checked = $true; $txtWDiskdefs.Text = 'diskdefs.cfg'; $chkWWarm.Checked = $false; $chkWCalWarm.Checked = $false; $numWWarmMin.Value = 2.5 }
        $cCases = @(
            # C1 : lecteur cible sans effet (Manuel), mesure refusee (secteurs durs), controle non applicable, options avancees
            @{ Id = 'C1'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { & $setWide; Set-PlCurves 'motif' $wide; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $cmbWProfile.SelectedIndex = 3; $txtWPrecomp.Text = '0=90:40=120'; $chkWHard.Checked = $true; & $advAll } }
            # C2 : profil Manuel (aucune mesure ne precede : les champs sont ceux de l ecriture), controle impose par la courbe
            # adaptee, lecteur cible sans effet, options avancees. Revue J : avec une mesure qui precede (repli au motif), le
            # controle impose ne s annonce plus d apres les champs, que la calibration remplace
            @{ Id = 'C2'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { & $setWide; Set-PlCurves 'motif' $wide; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $cmbWProfile.SelectedIndex = 3; $chkWPostCheck.Checked = $false; $txtWPrecomp.Text = '0=111:40=131'; $script:LevelShifts['std|c'] = @{ Model = 'M1'; Spec = '0=111:40=131'; Values = @(111) }; & $advAll } }
            # C2b (revue J) : cas de l ancien C2, mesure repliee au motif avec des champs adaptes : repli critique garde par la
            # coupe, aucun controle impose annonce (la calibration qui precede remplace les champs)
            @{ Id = 'C2b'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { & $setWide; [void]$script:TargetDrives.Remove($wide); Set-PlCurves 'courte' $wide; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $chkWPostCheck.Checked = $false; $txtWPrecomp.Text = '0=111:40=131'; $script:LevelShifts['std|c'] = @{ Model = 'M1'; Spec = '0=111:40=131'; Values = @(111) }; & $advAll } }
            # C3 : lecteur cible avec effet (courbe croisee nommee : segment descriptif long), mesure non faite pour le lecteur
            # cible, options avancees
            @{ Id = 'C3'; Img = $imAdf; Fmt = 'amiga.amigados'; Do = { & $setWide; $script:DriveCurves["$wide>$wide2|std"] = New-PlCurve "$wide>$wide2"; Sync-PrecompCurves; $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; & $advAll } }
        )
        $cBad = @(); $cRows = @()
        foreach ($cc in $cCases) {
            $sh = Get-PlShown $cc
            $critSegs = @(@($script:WPlanCur.Segs) | Where-Object { $_.Crit })
            $crit = @($critSegs | ForEach-Object { [string]$_.T })
            $allT = @(@($script:WPlanCur.Segs) | ForEach-Object { [string]$_.T })
            $cut = ($sh.Text -cne $sh.Full)
            # Segment critique dans le texte affiche (en tete de phrase, sa premiere lettre est en majuscule) : entier, ou sa
            # forme courte (le fait sans sa raison) seulement quand les segments critiques entiers ne tiennent pas seuls
            $inTxt = { param($x) ($x -and ($sh.Text.Contains($x) -or $sh.Text.Contains($x.Substring(0, 1).ToUpper() + $x.Substring(1)))) }
            $miss = @(); $short = 0
            foreach ($cs in $critSegs) {
                if (& $inTxt ([string]$cs.T)) { continue }
                if (& $inTxt ([string]$cs.S)) { $short++; continue }
                $miss += [string]$cs.T
            }
            if ($short -gt 0 -and (Get-WPlanHeight (Format-WritePlan $critSegs -Cut)) -le $lblWPlan.Height) { $cBad += "$($cc.Id) : forme courte sans necessite" }
            $cRows += "$($cc.Id) : $($allT.Count) segments dont $($crit.Count) critiques ($short en forme courte) ; affiche « $($sh.Text) » ($($sh.H) px)"
            if ($sh.Err) { $cBad += "$($cc.Id) erreur $($sh.Err)" }
            if ($sh.H -gt $lblWPlan.Height) { $cBad += "$($cc.Id) : $($sh.H) px pour $($lblWPlan.Height)" }
            if ($miss.Count) { $cBad += "$($cc.Id) : segments critiques coupes : $(Get-List $miss 2)" }
            if ($cut -and $sh.Tip -cne $sh.Full) { $cBad += "$($cc.Id) : infobulle differente du texte complet" }
            if ($cut -and -not $sh.Text.EndsWith(((T 'Ce qui va se passer : {0} ; …') -f 'X').Substring(((T 'Ce qui va se passer : {0} ; …') -f 'X').IndexOf('X') + 1))) { $cBad += "$($cc.Id) : coupe sans marque finale" }
            if ($cc.Id -ne 'C3' -and -not $cut) { $cBad += "$($cc.Id) : phrase non coupee (cas sans objet)" }
            if (@($allT | Where-Object { -not $sh.Full.Contains($_) }).Count) { $cBad += "$($cc.Id) : texte complet incomplet" }
            if ($cc.Id -eq 'C1' -and $crit.Count -lt 3) { $cBad += "C1 : $($crit.Count) segments critiques au lieu de 3" }
            if ($cc.Id -eq 'C2' -and ($crit.Count -lt 3 -or $short -lt 1)) { $cBad += "C2 : $($crit.Count) segments critiques au lieu de 3, $short en forme courte" }
            $rpMid = ((T "mesure de la disquette : {0}, au lieu de la mesure sur l'image ({1})") -f 'X', 'Y').Split('X')[1].Split('Y')[0]
            if ($cc.Id -eq 'C2b' -and (@($crit | Where-Object { $_.Contains($rpMid) }).Count -ne 1 -or @($allT | Where-Object { $_.StartsWith((T 'contrôle de toutes les pistes imposé')) }).Count)) { $cBad += "C2b : repli critique absent ou controle impose annonce ($(Get-List $crit 2))" }
        }
        # Borne : les trois segments critiques qui peuvent coexister (mesure, controle, lecteur cible), dans leur forme courte la
        # plus longue et avec le nom le plus large admis, tiennent dans les trois lignes
        $worst = Format-WritePlan @(@{ T = ((T "mesure de la disquette : {0}, au lieu de la mesure sur l'image") -f (Get-SettingText 'levelBeforeWriteMode' 'complete')) }, @{ T = (T 'contrôle de toutes les pistes non applicable') }, @{ T = ((T 'lecteur cible {0} sans effet') -f $wide2) }) -Cut
        $worstH = Get-WPlanHeight $worst
        if ($worstH -gt $lblWPlan.Height) { $cBad += "formes courtes : $worstH px pour $($lblWPlan.Height) (« $worst »)" }
        # C4 : refus long, noms les plus larges (lecteur cible sans courbe croisee) : refus en tete, encre, infobulle complete
        $c4 = Get-PlShown @{ Img = $imAdf; Fmt = 'amiga.amigados'; Do = { & $setWide; Set-PlCurves 'motif' $wide; $chkWSlow.Checked = $true } }
        $c4Long = ((Get-WPlanHeight $c4.Full) -gt $lblWPlan.Height)
        if (-not ($c4.Warn -and $c4.Text.StartsWith(((T "Écriture refusée : {0}") -f 'X').Split('X')[0]) -and ($c4.Tip -ceq $c4.Full -or -not $c4Long) -and $lblWPlan.AutoEllipsis)) { $cBad += "C4 refus « $($c4.Text) » (infobulle « $($c4.Tip) »)" }
        # Zone de la ligne inchangee (lot L9) : ni plus haute, ni deplacee ; bouton ECRIRE a sa place
        if ($lblWPlan.Location -ne (New-Object System.Drawing.Point(270, 295)) -or $lblWPlan.Height -ne 58 -or $btnWrite.Location -ne (New-Object System.Drawing.Point(10, 295))) { $cBad += "zone de la ligne : $($lblWPlan.Bounds), bouton $($btnWrite.Bounds)" }
        foreach ($x in $cRows) { "  C ($L) $x" }
        "  C ($L) : refus long « $($c4.Text) »$(if ($c4Long) { ' (depasse : texte complet en infobulle)' } else { '' })"
        "  C ($L) : formes courtes les plus longues ensemble : $worstH px (« $worst »)"
        Chk "C1$L" ($cBad.Count -eq 0) "($L) nom le plus large admis « $wide » comme lecteur qui ecrit et comme lecteur cible : phrases longues (lecteur cible sans effet, mesure refusee ou repliee, controle impose ou non applicable, seize options avancees) : chaque segment critique dans le texte affiche, entier, ou dans sa forme courte quand les segments critiques entiers ne tiennent pas seuls (raison en infobulle) ; texte dans les trois lignes ($($lblWPlan.Width) x $($lblWPlan.Height) px) ; segments descriptifs seuls retires ; phrase finie par « ; … », texte complet en infobulle ; les trois formes courtes les plus longues tiennent ensemble ; refus long en tete, a l encre d avertissement ; ligne a sa place et a sa taille du lot L9, bouton ECRIRE inchange ; ecarts : $(Get-List $cBad 3)"
        # Largeur de la page changee (fenetre agrandie) : phrase refaite a la nouvelle largeur, sans recalcul (meme plan en
        # memoire)
        [void](Get-PlShown $cCases[0])
        $memo = $script:WPlanMemo; $cutTxt = [string]$lblWPlan.Text
        $tabW.Size = New-Object System.Drawing.Size(1100, 516); $wideTxt = [string]$lblWPlan.Text
        $tabW.Size = New-Object System.Drawing.Size(792, 516); $backTxt = [string]$lblWPlan.Text
        Chk "C2$L" ($wideTxt.Length -gt $backTxt.Length -and $backTxt -ceq $cutTxt -and (Get-WPlanHeight $backTxt) -le $lblWPlan.Height -and [object]::ReferenceEquals($memo, $script:WPlanMemo)) "($L) page elargie a 1 100 px : la ligne montre plus de segments ($($wideTxt.Length) caracteres au lieu de $($backTxt.Length)) ; revenue a 792 px : meme texte, de nouveau dans ses trois lignes ; plan non recalcule (Show-WritePlan au changement de taille)"
        Chk "N$L" ($script:PlSide -eq 0) "($L) calcul et affichage de la phrase, dans tous les cas ci-dessus : aucune ligne de journal, aucune fenetre, aucune commande ($($script:PlSide))"
    }
}

# =====================================================================================================================
'--- P1, P2 : equivalence avec la source d avant les extractions (d8d80d6)'
$rn = $res['pl-fr']
# Releve complet (commandes, journal et phrase de chaque scenario) dans le dossier de travail, pour un ecart a examiner
$dump = New-Object System.Collections.Generic.List[string]
foreach ($sc in @($scP1 + $scP2)) {
    $r = if ($sc.Id -like 'S*') { $rn.P1[$sc.Id] } else { $rn.P2[$sc.Id] }
    $dump.Add("=== $($sc.Id) $($sc.T)")
    foreach ($x in $r.Trace) { $dump.Add("  T $x") }
    foreach ($x in $r.Log) { $dump.Add("  J $x") }
    if ($r.Plan) { if ($r.Plan.Refuse) { $dump.Add("  P refus : $($r.Plan.Refuse)") } else { foreach ($s in @($r.Plan.Segs)) { $dump.Add("  P $(if ($s.Crit) { '!' } else { ' ' }) $($s.T)") } } }
}
[System.IO.File]::WriteAllLines((Join-Path $here 'releve-p1-p2.txt'), [string[]]$dump.ToArray(), $utf8b)
$hashes = @{}; $p1Bad = @(); $p1Err = @(); $p1Side = @()
foreach ($sc in @($scP1 + $scP2)) {
    $r = if ($sc.Id -like 'S*') { $rn.P1[$sc.Id] } else { $rn.P2[$sc.Id] }
    $ht = Get-PlSha ($r.Trace -join "`n"); $hj = Get-PlSha ($r.Log -join "`n")
    $hashes[$sc.Id] = "$ht/$hj"
    if (@($r.Trace | Where-Object { $_ -like 'ERREUR*' }).Count) { $p1Err += "$($sc.Id) : $(@($r.Trace | Where-Object { $_ -like 'ERREUR*' })[0])" }
    if ($r.Side -ne 0) { $p1Side += $sc.Id }
    if ($plRef.Count -and [string]$plRef[$sc.Id] -cne $hashes[$sc.Id]) { $p1Bad += "$($sc.Id) : $($hashes[$sc.Id]), attendu $($plRef[$sc.Id])" }
}
foreach ($id in @('S02', 'S06', 'S08', 'W04', 'W15')) { $r = if ($id -like 'S*') { $rn.P1[$id] } else { $rn.P2[$id] }; foreach ($x in @($r.Trace | Select-Object -First 4)) { "  $id $x" } }
"  P1/P2 : empreintes (a recopier dans `$plRef si les commandes ou le journal changent a dessein) :"
$ids = @(@($scP1 + $scP2) | ForEach-Object { $_.Id })
for ($i = 0; $i -lt $ids.Count; $i += 4) { '    ' + (@($ids[$i..([math]::Min($i + 3, $ids.Count - 1))] | ForEach-Object { "$_ = '$($hashes[$_])'" }) -join '; ') }
$p1Ids = @($scP1 | ForEach-Object { $_.Id }); $p2Ids = @($scP2 | ForEach-Object { $_.Id })
Chk 'P1' ($p1Err.Count -eq 0 -and $p1Side.Count -eq 0 -and $plRef.Count -eq $ids.Count -and @($p1Bad | Where-Object { $_ -like 'S*' }).Count -eq 0) "$($p1Ids.Count) scenarios du bouton ECRIRE (vraie Start-WriteTabWrite, vraies Start-LevelBeforeWrite et Start-ImageWrite derriere elle) : commandes gw, demandes de mesure ou de calibration, fenetres et journal identiques a ceux de d8d80d6 (empreintes) ; calcul de la phrase avant le clic sans effet ; ecarts : $(Get-List (@($p1Bad | Where-Object { $_ -like 'S*' }) + $p1Err + $p1Side) 3)"
Chk 'P2' ($plRef.Count -eq $ids.Count -and @($p1Bad | Where-Object { $_ -like 'W*' }).Count -eq 0) "$($p2Ids.Count) scenarios de l ecriture seule (vraie Start-ImageWrite : tetes, effacement, profils transmis, controle impose, lecteur cible, restauration, lecteur enregistre) : file de commandes, controle, prechauffage et journal identiques a ceux de d8d80d6 (empreintes) ; ecarts : $(Get-List @($p1Bad | Where-Object { $_ -like 'W*' }) 3)"
if ($Before) {
    $ra = $res['avant-fr']
    $eb = @()
    foreach ($sc in @($scP1 + $scP2)) {
        $a = if ($sc.Id -like 'S*') { $ra.P1[$sc.Id] } else { $ra.P2[$sc.Id] }
        $n = if ($sc.Id -like 'S*') { $rn.P1[$sc.Id] } else { $rn.P2[$sc.Id] }
        for ($i = 0; $i -lt [math]::Max(@($a.Trace).Count, @($n.Trace).Count); $i++) { if ([string]@($a.Trace)[$i] -cne [string]@($n.Trace)[$i]) { $eb += "$($sc.Id) commande $i : « $(@($a.Trace)[$i]) » / « $(@($n.Trace)[$i]) »"; break } }
        for ($i = 0; $i -lt [math]::Max(@($a.Log).Count, @($n.Log).Count); $i++) { if ([string]@($a.Log)[$i] -cne [string]@($n.Log)[$i]) { $eb += "$($sc.Id) journal $i : « $(@($a.Log)[$i]) » / « $(@($n.Log)[$i]) »"; break } }
    }
    foreach ($x in @($eb | Select-Object -First 6)) { "  P1b ECART $x" }
    Chk 'P1b' ($eb.Count -eq 0) "-Before $Before : pour les $($ids.Count) scenarios, commandes, demandes, fenetres et journal identiques ligne a ligne a ceux de la source d avant ; ecarts : $($eb.Count)"
} else { '  P1b saute (sans -Before : comparaison ligne a ligne avec la source d avant les extractions)' }

# =====================================================================================================================
'--- I : textes (019, section L10)'
$i18nFiles = @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' | Sort-Object Name)
foreach ($f in $i18nFiles) { . $f.FullName }
$s019 = [System.IO.File]::ReadAllText((Get-PlMod $Wt '019'), [System.Text.Encoding]::UTF8)
$i10 = $s019.IndexOf('# --- L10 :'); $i11 = $s019.IndexOf('# --- L11 :')
$sec10 = ''; if ($i10 -ge 0 -and $i11 -gt $i10) { $sec10 = $s019.Substring($i10, $i11 - $i10) }
# Textes de la specification (§ 2.7, T1 a T14, R1 a R9) et du plan (B1), mot pour mot
$want10 = [ordered]@{
    'Ce qui va se passer : {0}.' = 'What will happen: {0}.'; ' ; ' = '; '
    'effacement haute fréquence des pistes' = 'high-frequency erase of the tracks'; 'pré-effacement de chaque piste' = 'pre-erase of each track'; 'sans effacement' = 'no erase'
    'mesure de la disquette : {0}' = 'disk measurement: {0}'; 'sans mesure de la disquette ({0})' = 'no disk measurement ({0})'
    'lecteur cible {0}' = 'target drive {0}'; 'image flux' = 'flux image'; 'image en codage {0}' = '{0}-encoded image'
    'image non calibrable' = 'image that cannot be calibrated'; 'haute densité' = 'high density'; 'profil « {0} »' = 'profile "{0}"'
    'champ Pistes' = 'Tracks field'; 'image à une seule face' = 'single-sided image'
    'écriture des deux têtes ensemble' = 'write of both heads together'; 'écriture tête 0 puis tête 1' = 'write of head 0 then head 1'; 'écriture de la tête {0} seule' = 'write of head {0} only'
    'contrôle de toutes les pistes, {0} passe(s) de réécriture au plus' = 'full track check, up to {0} rewrite pass(es)'; 'contrôle de toutes les pistes, sans réécriture' = 'full track check, no rewrite'
    'contrôle de toutes les pistes non applicable ({0})' = 'full track check not applicable ({0})'; 'contrôle complet non demandé' = 'full track check not requested'
    'pour le lecteur cible {0} : {1}' = 'for target drive {0}: {1}'
    "Écriture refusée : le test rapide n'a pas de référence utilisable pour cette image ({0})." = 'Write refused: the quick test has no usable reference for this image ({0}).'
}
$iBad = @()
foreach ($k in @($want10.Keys)) {
    if ([string]$script:I18n[$k] -cne [string]$want10[$k]) { $iBad += "« $k » : « $($script:I18n[$k]) »" }
    if (-not $sec10.Contains("['" + $k.Replace("'", "''") + "']") -and -not $sec10.Contains('["' + $k + '"]')) { $iBad += "« $k » hors de la section L10" }
}
# Toute cle de T() des fonctions de la phrase a son entree anglaise
foreach ($fn in @('Get-WritePlan', 'Format-WritePlan', 'Get-WriteHeads')) {
    foreach ($c in $fnAst[$fn].Body.FindAll({ param($x) $x -is $tCmdA -and $x.GetCommandName() -eq 'T' }, $true)) {
        $k = [string]$c.CommandElements[1].Value
        if (-not $script:I18n.ContainsKey($k)) { $iBad += "« $k » sans entree anglaise ($fn)" }
    }
}
Chk 'I1' ($iBad.Count -eq 0) "$($want10.Count) textes de la specification et du plan (phrase, separateur, T1 a T14, R1 a R9, refus du Test rapide) : entree anglaise mot pour mot, dans la section L10 de 019 ; toute cle de la phrase traduite ; ecarts : $(Get-List $iBad 3)"

'--- D : CHANGELOG et README'
$ch = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
$sec = ''; $mm = [regex]::Match($ch, '(?s)## \[12\.11\].*?(?=\n## \[)'); if ($mm.Success) { $sec = $mm.Value }
$nouv = ''; $mn = [regex]::Match($sec, '(?s)### Nouveautés.*?(?=\n### )'); if ($mn.Success) { $nouv = $mn.Value }
$dev = ''; $md = [regex]::Match($sec, '(?s)### Pour les développeurs.*$'); if ($md.Success) { $dev = $md.Value }
$rd = [System.IO.File]::ReadAllText((Join-Path $mods 'README.md'), [System.Text.Encoding]::UTF8)
$trd = [System.IO.File]::ReadAllText((Join-Path $Wt 'tests\README.md'), [System.Text.Encoding]::UTF8)
$d1 = [ordered]@{
    'nouveaute' = $nouv.Contains('**Ligne « Ce qui va se passer ».**')
    'refus avant le clic' = $nouv.Contains('Un refus se lit avant le clic')
    'developpeurs' = ($dev.Contains('`Get-WritePlan`') -and $dev.Contains('`Get-LevelBeforeWritePlan(') -and $dev.Contains('`tests/logic-ecriture-plan.ps1`'))
    'materiel' = ($sec -notmatch 'vérifiée? sur (du )?matériel')
    'README 145' = ([regex]::Match($rd, '\| `145-fn-onglet-ecriture\.ps1` \|[^\n]*').Value.Contains('`Get-WritePlan`'))
    'README 140' = ([regex]::Match($rd, '\| `140-fn-ecriture\.ps1` \|[^\n]*').Value.Contains('`Get-WriteLevelPlan`'))
    'README 260' = ([regex]::Match($rd, '\| `260-fn-calib-rapide\.ps1` \|[^\n]*').Value.Contains('`Get-LevelBeforeWritePlan`'))
    'README tests' = $trd.Contains('| `logic-ecriture-plan` |')
}
Chk 'D1' (@($d1.Keys | Where-Object { -not $d1[$_] }).Count -eq 0) "CHANGELOG 12.11 : Nouveautes (ligne « Ce qui va se passer », un refus se lit avant le clic), Pour les developpeurs (Get-WritePlan, Get-LevelBeforeWritePlan), aucun texte ne dit un comportement verifie sur materiel ; README des modules (140, 145, 260) et des tests ; ecarts : $(Get-List @($d1.Keys | Where-Object { -not $d1[$_] }))"

$nk = ''; if ($script:Fail) { $nk = ' ; non conformes : ' + (@($script:FailIds) -join ', ') }
"=== bilan logic-ecriture-plan : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
