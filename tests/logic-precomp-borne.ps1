param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Config = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 rc4 (R2) : borne de precompensation reglable dans les options avancees de l onglet Ecriture. Liste « Borne de
# precompensation » : « Automatique (400 ns ; 470 ns en long track) » ou une valeur de 300 a 470 ns. Une seule entree du
# reglage, Set-PrecompBound (230) ; borne de la famille par Set-CalibScale d apres $script:CalHardAuto : la rc3 lisait
# « precompMaxNs = 400 » comme « non regle » ; 400 ns choisi vaut maintenant 400 ns dans toutes les familles.
#  S  statique (arbre syntaxique) : S1 Set-CalibScale ne compare plus la borne a sa valeur par defaut ; S2 une seule
#     entree du reglage, appelee par Set-Defaults, Load-Config et le gestionnaire de la liste ; S3 les instructions de 520
#     executees au chargement ne lisent pas l etat de 560, charge apres ce module ; S4 cles ecrites par Save-Config.
#  F  borne par famille (vraies Set-PrecompBound, Set-CalibScale, Reset-DiskHardNs, Get-DiskOverNs, Get-DiskHardNs) : F1
#     automatique ; F2 400 ns choisi (470 ns en long track avant ce lot) ; F3 valeurs choisies et bornes de la plage ; F4
#     seuil du controle impose, plafond d une disquette et borne retablie apres une mesure complete ; F5 les courbes deja
#     calculees ne changent pas.
#  C  configuration (instructions reelles de Load-Config, extraites ; expressions reelles de Save-Config) : C1
#     configurations d une version anterieure, sans la cle precompMaxAuto : 400 ns = automatique, autre valeur = valeur
#     reglee, valeur hors plage ou illisible signalee ; C2 toutes les valeurs de 300 a 470 ns et les quatre familles :
#     meme borne que la regle de la rc3 ; C3 cle precompMaxAuto ; C4 enregistrement puis relecture, et relecture du
#     fichier par la regle de la rc3 ; C5, avec -Config <fichier ou dossier> seulement : configurations reelles.
#  U  interface, en francais et en anglais, onglet construit par les instructions reelles de 500, 510, 520 et 540 dans
#     l ordre de l application (etat de 550 a 590 charge apres l interface), controles jamais affiches : U1 liste vide et
#     non comptee avant Set-Defaults ; U2 elements et choix par defaut ; U3 place, textes entiers, aucun chevauchement ;
#     U4 choix d une valeur, de 400 ns, retour a l automatique : reglage, journal, option avancee nommee, infobulle ; U5
#     valeur hors du pas de la liste ; U6 aucun changement pendant une operation ; U7 « Reinitialiser » (partie Ecriture
#     de Set-Defaults) ; U8 infobulle et entrees anglaises ; U9 commandes gw d une ecriture identiques quel que soit le
#     reglage.
#  D  CHANGELOG, README des modules et des tests.
# Fonctions et instructions reelles extraites par l arbre syntaxique, ecrites dans des fichiers de travail puis chargees
# par dot-source ; controles WinForms reels jamais affiches ; images factices sous le dossier de travail. Aucun gw, aucune
# fenetre, aucune compilation. Non couvert : une calibration deroulee de bout en bout avec une borne choisie, le choix
# d un element a la souris dans la fenetre reelle, le rendu de la liste et de son infobulle, la vraie Load-Config entiere
# (jouee par logic-lecteurs-registre et logic-lecteurs-bandeau, sans la liste).
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
function Get-PbMod([string]$px) {
    $f = @(Get-ChildItem -LiteralPath (Join-Path $Wt 'src\modules') -Filter "$px-*.ps1" -File)
    if ($f.Count -ne 1) { throw "module $px introuvable sous $Wt" }
    return $f[0].FullName
}
$utf8b = New-Object System.Text.UTF8Encoding($true)
$tAsgA = [System.Management.Automation.Language.AssignmentStatementAst]
$tFnA = [System.Management.Automation.Language.FunctionDefinitionAst]
$tCmdA = [System.Management.Automation.Language.CommandAst]
$tVarA = [System.Management.Automation.Language.VariableExpressionAst]
$tStrA = [System.Management.Automation.Language.StringConstantExpressionAst]
$tSbA = [System.Management.Automation.Language.ScriptBlockExpressionAst]
$tHashA = [System.Management.Automation.Language.HashtableAst]
function Write-PbGen([string]$path, $parts) { [System.IO.File]::WriteAllText($path, ((@($parts) -join "`r`n`r`n") + "`r`n"), $utf8b) }
$mods = Join-Path $Wt 'src\modules'
# Table I18n et fonction T (modules 01x), chargees comme par l application
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'

# =====================================================================================================================
'--- S : statique (arbre syntaxique des modules)'
$fnAst = @{}; $fnMod = @{}; $modAst = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Sort-Object Name)) {
    $a = Get-Ast $f.FullName; $modAst[$f.Name.Substring(0, 3)] = $a
    foreach ($d in $a.FindAll({ param($x) $x -is $tFnA }, $false)) { $fnAst[$d.Name] = $d; $fnMod[$d.Name] = $f.Name.Substring(0, 3) }
}
function Get-PbOwner($node) {
    # Fonction qui contient un noeud (« (script) » au niveau du script), precedee du numero de son module
    $p = $node.Parent; while ($p -and $p -isnot $tFnA) { $p = $p.Parent }
    if ($p) { return [string]$p.Name }
    return '(script)'
}
function Get-PbSites([scriptblock]$pred) {
    # Emplacements « module:fonction » des noeuds retenus, dans tous les modules, tries
    $o = @()
    foreach ($px in @($modAst.Keys | Sort-Object)) { foreach ($n in $modAst[$px].FindAll($pred, $true)) { $o += "${px}:$(Get-PbOwner $n)" } }
    return ,@($o | Sort-Object)
}
# S1 : la borne du long track suit le reglage automatique ; plus de comparaison a la valeur par defaut
$scs = $fnAst['Set-CalibScale']
$scsVars = @($scs.Body.FindAll({ param($x) $x -is $tVarA }, $true) | ForEach-Object { [string]$_.VariablePath.UserPath } | Sort-Object -Unique)
Chk 'S1' ($scsVars -contains 'script:CalHardAuto' -and $scsVars -notcontains 'script:CalHardNsDefault' -and $scs.Extent.Text.Contains("`$lt = (`$fam -eq 'long' -and [bool]`$script:CalHardAuto)")) "Set-CalibScale : borne du long track d apres `$script:CalHardAuto, sans comparaison de la borne a sa valeur par defaut (CalHardNsDefault lue : $($scsVars -contains 'script:CalHardNsDefault'))"
# S2 : une seule entree du reglage
$asg = Get-PbSites { param($x) $x -is $tAsgA -and @('$script:CalHardAuto', '$script:CalHardNsUser') -contains $x.Left.Extent.Text }
$callers = Get-PbSites { param($x) $x -is $tCmdA -and $x.GetCommandName() -eq 'Set-PrecompBound' }
$sdSt = @($fnAst['Set-Defaults'].Body.EndBlock.Statements | Where-Object { $_.Extent.Text -ceq 'Set-PrecompBound $true' })
Chk 'S2' (($asg -join ', ') -ceq '230:Set-PrecompBound, 230:Set-PrecompBound, 560:(script), 560:(script)' -and ($callers -join ', ') -ceq '120:Load-Config, 120:Set-Defaults, 145:Set-PrecompBoundFromUi' -and $sdSt.Count -eq 1) "reglage pose par la seule Set-PrecompBound (affectations de CalHardAuto et CalHardNsUser : $($asg -join ', ')) ; appelee par : $($callers -join ', ') ; Set-Defaults : « Set-PrecompBound `$true » ($($sdSt.Count))"
# S3 : 520 est charge avant l etat de 560 : ses instructions qui portent sur la liste ne lisent, au chargement, ni
# l etat de la calibration ni les fonctions de la borne (le gestionnaire, lui, s execute plus tard)
$top520 = @($modAst['520'].EndBlock.Statements | Where-Object { $_.Extent.Text -match '\$(cmbWBound|lblWBound)\b' })
$s3Bad = @(); $s3Cmd = @()
foreach ($s in $top520) {
    foreach ($n in $s.FindAll({ param($x) $x -is $tVarA -or $x -is $tCmdA }, $true)) {
        $p = $n.Parent; $inSb = $false
        while ($p -and -not [object]::ReferenceEquals($p, $s)) { if ($p -is $tSbA) { $inSb = $true }; $p = $p.Parent }
        if ($inSb) { continue }
        if ($n -is $tVarA) { if ([string]$n.VariablePath.UserPath -like 'script:*') { $s3Bad += [string]$n.Extent.Text } }
        else { $s3Cmd += [string]$n.GetCommandName() }
    }
}
$s3Cmd = @($s3Cmd | Sort-Object -Unique)
$names = @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object { $_.Name.Substring(0, 3) })
$top600 = @($modAst['600'].EndBlock.Statements | ForEach-Object { $_.Extent.Text })
$iLay = [array]::IndexOf([string[]]$top600, 'Set-WriteTabLayout'); $iDef = [array]::IndexOf([string[]]$top600, 'Set-Defaults'); $iLoad = [array]::IndexOf([string[]]$top600, '$loaded = Load-Config')
$hdl = @($top520 | Where-Object { $_.Extent.Text -ceq '$cmbWBound.Add_SelectedIndexChanged({ Set-PrecompBoundFromUi })' })
Chk 'S3' ($top520.Count -ge 5 -and $s3Bad.Count -eq 0 -and ($s3Cmd -join ', ') -ceq 'New-Label, New-Object, T' -and [array]::IndexOf([string[]]$names, '520') -lt [array]::IndexOf([string[]]$names, '560') -and $iLay -ge 0 -and $iDef -gt $iLay -and $iLoad -gt $iDef -and $hdl.Count -eq 1) "520, charge avant 560 : $($top520.Count) instructions sur la liste et son libelle, aucune variable d etat lue au chargement ($(Get-List $s3Bad)), commandes : $($s3Cmd -join ', ') ; gestionnaire : Set-PrecompBoundFromUi ($($hdl.Count)) ; 600 : Set-WriteTabLayout, puis Set-Defaults, puis Load-Config ($iLay, $iDef, $iLoad)"
# S4 : cles ecrites par Save-Config
$svKv = @{}
foreach ($h in $fnAst['Save-Config'].Body.FindAll({ param($x) $x -is $tHashA }, $true)) { foreach ($kv in $h.KeyValuePairs) { $k = [string]$kv.Item1.Extent.Text; if ($k -like 'precompMax*') { $svKv[$k] = [string]$kv.Item2.Extent.Text } } }
Chk 'S4' ($svKv.Count -eq 2 -and $svKv['precompMaxNs'] -ceq '[int]$script:CalHardNsUser' -and $svKv['precompMaxAuto'] -ceq '[bool]$script:CalHardAuto') "Save-Config, section write : precompMaxNs = $($svKv['precompMaxNs']) ; precompMaxAuto = $($svKv['precompMaxAuto'])"

# =====================================================================================================================
# Fichiers de travail : fonctions de tous les modules fn ; etat lu avant l interface (000, 020, 040) et apres (550 a
# 590), comme l application ; instructions de 500, 510, 520, 540 ; partie Ecriture de Set-Defaults ; instructions de
# Load-Config qui lisent la borne ; expressions de Save-Config qui l ecrivent
$pbCtl = @('txtWFile', 'btnWFile', 'cmbWFmt', 'chkWPreErase', 'chkWSlow', 'chkWPostCheck', 'chkWUnattended', 'chkWLevel', 'cmbWLevelMode', 'cmbWTarget', 'cmbWCalMode', 'btnWCalib', 'btnWCross', 'btnWCurve', 'btnWrite',
           'chkWEraseEmpty', 'chkWNoVerify', 'numWRetries', 'numWRepair', 'cmbWProfile', 'chkWPrecomp', 'txtWPrecomp', 'txtWPrecomp1', 'txtWTracks', 'cmbWDensel', 'txtWFakeIdx', 'chkWReverse', 'txtWDiskdefs', 'btnWDiskdefs',
           'chkWHard', 'chkWTG43', 'chkWWarm', 'chkWCalWarm', 'numWWarmMin', 'btnWCalReset', 'btnWCalBack', 'cmbWBound')
function Get-PbState([string[]]$pxs) {
    $st = New-Object System.Collections.Generic.List[string]
    foreach ($px in $pxs) {
        foreach ($s in $modAst[$px].EndBlock.Statements) {
            $t = $s.Extent.Text
            if ($t -match 'Add-Type|EnableVisualStyles') { continue }
            if ($px -eq '020' -and -not ($s -is $tAsgA -and $t.StartsWith('$script:') -and -not $t.StartsWith('$script:AppDir'))) { continue }
            $st.Add($t)
        }
    }
    return ,@($st.ToArray())
}
$g = @{}
$fns = New-Object System.Collections.Generic.List[string]
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Where-Object { $_.Name -match '^[1-4]\d\d-fn-' } | Sort-Object Name)) {
    foreach ($fd in $modAst[$f.Name.Substring(0, 3)].FindAll({ param($x) $x -is $tFnA }, $false)) { $fns.Add($fd.Extent.Text) }
}
$g.Fn = Join-Path $here 'gen-fonctions.ps1'; Write-PbGen $g.Fn $fns
$g.State0 = Join-Path $here 'gen-etat-avant-interface.ps1'; Write-PbGen $g.State0 (Get-PbState @('000', '020', '040'))
$g.State1 = Join-Path $here 'gen-etat-apres-interface.ps1'; Write-PbGen $g.State1 (Get-PbState @('550', '560', '565', '570', '580', '590'))
$g.U500 = Join-Path $here 'gen-500.ps1'
Write-PbGen $g.U500 @($modAst['500'].EndBlock.Statements | Where-Object { $_.Extent.Text -notmatch 'Add-Type' } | ForEach-Object { $_.Extent.Text })
$ban = @(); $on = $false
foreach ($s in $modAst['510'].EndBlock.Statements) {
    $t = $s.Extent.Text
    if ($t.StartsWith('$pnlTop = ')) { $on = $true }
    if ($on) { $ban += $t }
    if ($t.StartsWith('$script:DriveBanner = ')) { $on = $false }
}
$g.U510 = Join-Path $here 'gen-510.ps1'; Write-PbGen $g.U510 $ban
$g.U520 = Join-Path $here 'gen-520.ps1'; Write-PbGen $g.U520 @($modAst['520'].EndBlock.Statements | ForEach-Object { $_.Extent.Text })
$g.U540 = Join-Path $here 'gen-540.ps1'
Write-PbGen $g.U540 @($modAst['540'].EndBlock.Statements | Where-Object { $_.Extent.Text -match '^(Set-Btn\s+|Set-Cue\s+|\$tip\.SetToolTip\()\$(\w+)\b' -and $pbCtl -contains $Matches[2] } | ForEach-Object { $_.Extent.Text })
$ds = @($fnAst['Set-Defaults'].Body.EndBlock.Statements | Where-Object { $_.Extent.Text -match '\$(txtW|cmbW|chkW|numW|lblW)' -or $_.Extent.Text -match '^(Reset-Settings|Update-SlowUi|Update-TargetDriveUi|Set-PrecompBound \$true)$' } | ForEach-Object { $_.Extent.Text })
$g.Def = Join-Path $here 'gen-defauts.ps1'
Write-PbGen $g.Def @("function Invoke-PbDefaults {`r`n" + ($ds -join "`r`n") + "`r`n}")
# Load-Config : de la lecture de precompMaxNs a l appel de Set-PrecompBound, instructions consecutives d un meme bloc
$ldBlk = $null; $i0 = -1; $i1 = -1
foreach ($sb in $fnAst['Load-Config'].Body.FindAll({ param($x) $x -is [System.Management.Automation.Language.StatementBlockAst] -or $x -is [System.Management.Automation.Language.NamedBlockAst] }, $true)) {
    $sts = @($sb.Statements)
    for ($i = 0; $i -lt $sts.Count; $i++) { if ($sts[$i].Extent.Text.StartsWith("`$hraw = Get-Cfg `$w 'precompMaxNs'")) { $ldBlk = $sts; $i0 = $i } }
}
if ($ldBlk) { for ($i = $i0; $i -lt $ldBlk.Count; $i++) { if ($ldBlk[$i].Extent.Text.StartsWith('Set-PrecompBound ')) { $i1 = $i; break } } }
if ($i0 -lt 0 -or $i1 -le $i0) { throw "Load-Config : instructions de la borne introuvables ($i0, $i1)" }
$ldSt = @($ldBlk[$i0..$i1] | ForEach-Object { $_.Extent.Text })
$g.Load = Join-Path $here 'gen-lecture.ps1'
Write-PbGen $g.Load @("function Invoke-PbLoad(`$w) {`r`n    " + ($ldSt -join "`r`n    ") + "`r`n}",
                      "function Get-PbSaved {`r`n    return @{ precompMaxNs = $($svKv['precompMaxNs']); precompMaxAuto = $($svKv['precompMaxAuto']) }`r`n}")

function Set-PbStubs {
    # Bouchons : gw, fenetres, journal, prechauffage, controle, mesures, profil de l image et autres onglets ; commandes et
    # demandes relevees dans $script:PbTrace, le journal dans $script:PbLog
    function script:Start-Gw([string[]]$gwArgs, [switch]$Soft) { [void]$script:PbTrace.Add('gw ' + ($gwArgs -join ' ')) }
    function script:Invoke-NextChainStep {
        foreach ($q in @($script:WriteQueue.ToArray())) { [void]$script:PbTrace.Add('file ' + (@($q) -join ' ')) }
        if ($script:WriteArgs) { [void]$script:PbTrace.Add('ecriture ' + (@($script:WriteArgs) -join ' ')) }
        [void]$script:PbTrace.Add('etapes ' + $script:Chain.Count)
    }
    function script:Start-WriteWarmup([string]$tspec, [bool]$noWarm) {
        foreach ($q in @($script:WriteQueue.ToArray())) { [void]$script:PbTrace.Add('file ' + (@($q) -join ' ')) }
        [void]$script:PbTrace.Add("prechauffage $tspec $noWarm ; etapes $($script:Chain.Count)")
    }
    function script:New-WriteCheck([string[]]$base, [string]$image, [string]$userTSpec, [int]$max, [string[]]$readOpts, $headPrecomp, [string]$eraseMode = '') {
        $hp = if ($headPrecomp) { "$($headPrecomp[0])/$($headPrecomp[1])" } else { '-' }
        [void]$script:PbTrace.Add("controle base $($base -join ' ') ; pistes $userTSpec ; passes $max ; relecture $($readOpts -join ' ') ; precomp $hp ; effacement $eraseMode")
        $script:Rep = @{}
    }
    function script:Start-LevelCalib($lr, [switch]$NoConfirm, [switch]$NoFallback, $Geom = $null) { [void]$script:PbTrace.Add('calibration rapide') }
    function script:Start-DiskMeasure($lr, $brand) { [void]$script:PbTrace.Add('mesure complete') }
    function script:Start-ContentMeasure($chk) { [void]$script:PbTrace.Add('mesure sur l image') }
    function script:Start-PrecompCalib { [void]$script:PbTrace.Add('calibration complete') }
    function script:Show-AppMessage([string]$text, [string]$title, [string]$buttons = 'OK', [string]$icon = 'Information') { [void]$script:PbTrace.Add("message $title $buttons"); if ($buttons -eq 'YesNo') { return 'No' }; return 'OK' }
    function script:Show-AppConfirm([string]$Title, [string]$Heading, [string]$Text, [string]$Check = '', [string]$GoText = '', [string]$GoGlyph = '', [string]$Level = 'warn', [string]$Picto = 'warn', [string]$AltText = '', $Combo = $null) { [void]$script:PbTrace.Add("confirmation $Title"); return $true }
    function script:Show-Tab($t) { }
    function script:Append-Log($t) { [void]$script:PbLog.Add([string]$t) }
    function script:Update-PrecompForImage($p) { [void]$script:PbTrace.Add('profil recalcule') }
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
$pbImg = Join-Path $here 'img'
if (-not (Test-Path -LiteralPath $pbImg)) { [void](New-Item -ItemType Directory -Path $pbImg -Force) }
$imAdf = Join-Path $pbImg 'jeu.adf'; [System.IO.File]::WriteAllBytes($imAdf, (New-Object byte[] 901120))
$script:PbTrace = New-Object System.Collections.Generic.List[string]
$script:PbLog = New-Object System.Collections.Generic.List[string]
$stOp = New-Object System.Windows.Forms.ToolStripStatusLabel; $status = New-Object System.Windows.Forms.StatusStrip

# --- Aides des cas
function Get-PbFam([string]$fam) {
    # Borne posee par la vraie Set-CalibScale pour une famille, bareme remis a la double densite ensuite (repos)
    Set-CalibScale $fam
    $r = "$($script:CalHardNs)/$($script:CalScaleFam)"
    Set-CalibScale ''
    return $r
}
function Get-PbFams { return (@(foreach ($f in 'std', 'long', 'hd', '') { Get-PbFam $f }) -join ' ') }
function Get-PbSet { return "$(if ($script:CalHardAuto) { 'auto' } else { 'choisie' }) $($script:CalHardNsUser)" }
function Get-PbRc3([int]$user, [string]$fam) {
    # Regle de la rc3 (borne de la reference propre a la famille) : valeur lue ramenee a 300..470 ns ; long track : 470 ns
    # quand elle vaut 400, sinon la valeur ; haute densite : moitie
    $u = [int][math]::Max(300, [math]::Min(470, $user))
    if ($fam -eq 'hd') { return "$([int][math]::Round([double]$u * 0.5))/hd" }
    if ($fam -eq 'long' -and $u -eq 400) { return '470/long' }
    return "$u/dd"
}
function Get-PbRc3Fams([int]$user) { return (@(foreach ($f in 'std', 'long', 'hd', '') { Get-PbRc3 $user $f }) -join ' ') }
function ConvertTo-PbW([string]$json) { return ($json | ConvertFrom-Json) }
function Invoke-PbRead([string]$json) {
    # Section write donnee en JSON, lue par les instructions reelles de Load-Config ; rend reglage, bornes et journal
    $script:PbLog.Clear()
    Invoke-PbLoad (ConvertTo-PbW $json)
    return @{ Set = (Get-PbSet); Fams = (Get-PbFams); Log = @($script:PbLog.ToArray()); Item = [string]$cmbWBound.Text }
}
function Get-PbAdvNames {
    # Options avancees modifiees que nomme la vraie Get-WriteAdvChanges, reunies par « / » ; '' : aucune
    return (@(Get-WriteAdvChanges) -join ' / ')
}
function Get-PbBoundCounted([string]$lbl) { return @(@(Get-WriteAdvChanges) | Where-Object { ([string]$_).StartsWith($lbl) }).Count }
function Get-PbGeo {
    # Defauts de place de la liste et de son libelle dans le cadre des options avancees
    $bad = @()
    foreach ($c in @($lblWBound, $cmbWBound)) {
        if (-not [object]::ReferenceEquals($c.Parent, $grpWAdv)) { $bad += "$($c.Name) hors du cadre des options avancees" }
        if ($c.Left -lt 0 -or $c.Top -lt 0 -or $c.Right -gt $grpWAdv.DisplayRectangle.Right -or $c.Bottom -gt $grpWAdv.ClientSize.Height - 2) { $bad += "$($c.Name) deborde du cadre ($($c.Bounds) ; bord $($grpWAdv.DisplayRectangle.Right), bas $($grpWAdv.ClientSize.Height - 2))" }
        foreach ($o in @($grpWAdv.Controls)) { if (-not [object]::ReferenceEquals($o, $c) -and $o.Bounds.IntersectsWith($c.Bounds)) { $bad += "$($c.Name) chevauche « $($o.Text) » $($o.Bounds)" } }
    }
    if ($lblWBound.PreferredSize.Width -gt $lblWBound.Width) { $bad += "libelle coupe ($($lblWBound.PreferredSize.Width) > $($lblWBound.Width))" }
    $mx = 0; foreach ($it in @($cmbWBound.Items)) { $w = [System.Windows.Forms.TextRenderer]::MeasureText([string]$it, $cmbWBound.Font).Width; if ($w -gt $mx) { $mx = $w } }
    if ($mx + 16 -gt $cmbWBound.Width) { $bad += "element coupe ($mx + 16 > $($cmbWBound.Width))" }
    if ($cmbWBound.Left -lt $lblWBound.Right) { $bad += "liste sur son libelle ($($cmbWBound.Left) < $($lblWBound.Right))" }
    if ($lblWBound.Top -lt $cmbWBound.Top -or $lblWBound.Bottom -gt $cmbWBound.Bottom + 2) { $bad += "libelle hors de la rangee de la liste ($($lblWBound.Bounds) / $($cmbWBound.Bounds))" }
    return ,@($bad)
}
function Invoke-PbWrite([scriptblock]$do) {
    # Une ecriture par le bouton ECRIRE (vraie Start-WriteTabWrite), image ADF factice, champs --precomp poses ; rend les
    # commandes et demandes relevees
    Invoke-PbDefaults
    $txtWFile.Text = $imAdf
    $cmbWFmt.SelectedItem = 'amiga.amigados'
    $txtWPrecomp.Text = '0=100:40=130'; $txtWPrecomp1.Text = '0=110:40=140'
    & $do
    $script:PbTrace.Clear()
    $script:WriteQueue.Clear(); $script:Chain.Clear(); $script:WriteArgs = $null; $script:Rep = $null
    $script:LevelPostForce = $false; $script:WriteFactorNext = $null; $script:Restore = $null; $script:GwProc = $null
    try { Start-WriteTabWrite } catch { [void]$script:PbTrace.Add("ERREUR $($_.Exception.Message)") }
    $t = @($script:PbTrace | ForEach-Object { ([string]$_).Replace($pbImg, '<img>') })
    $script:WriteQueue.Clear(); $script:Chain.Clear(); $script:WriteArgs = $null; $script:Rep = $null
    return ,$t
}

$wantAuto = @{ fr = 'Automatique (400 ns ; 470 ns en long track)'; en = 'Automatic (400 ns; 470 ns for long track)' }
$wantLbl = @{ fr = 'Borne de précompensation :'; en = 'Precompensation bound:' }
$wantLog = @{ fr = 'Borne de précompensation : {0} (avant : {1}).'; en = 'Precompensation bound: {0} (before: {1}).' }
$wantOver = @{ fr = "dès qu'elle dépasse {0} ns."; en = 'as soon as it exceeds {0} ns.' }
$wantBusy = @{ fr = 'Borne de précompensation inchangée : une opération est en cours ou une calibration attend votre décision.'; en = 'Precompensation bound unchanged: an operation is running or a calibration awaits your decision.' }
# 12.11 rc4 (decision de l utilisateur) : en automatique, borne de la courbe ecrite avec un facteur propre a la famille
# (400 ns en standard, 470 ns en long track) ; une borne choisie, la meme partout
$wantCap0 = @{ fr = "À l'écriture, la borne en place plafonne aussi la courbe multipliée par le facteur de précompensation et la mesure sur l'image : {0} ; une valeur déjà au-dessus n'est jamais augmentée."; en = 'At write time, the bound in place also caps the curve multiplied by the precompensation factor and the measurement on the image: {0}; a value already above it is never increased.' }
$wantCapA = @{ fr = ($wantCap0['fr'] -f '400 ns au plus, 470 ns en long track'); en = ($wantCap0['en'] -f '400 ns at most, 470 ns in long track') }
$wantCapC = @{ fr = ($wantCap0['fr'] -f '450 ns au plus, long track compris'); en = ($wantCap0['en'] -f '450 ns at most, long track included') }
$std = @(0) + @(for ($v = 300; $v -le 470; $v += 10) { $v })
foreach ($L in @('fr', 'en')) {
    "--- onglet construit dans l ordre de l application, langue $L"
    $script:AppDir = $here
    . $g.State0
    . $g.Fn
    . $g.Load
    Set-PbStubs
    $script:Lang = $L
    $script:UiReady = $false
    # Etat de 560 retire avant l interface : dans l application, il n existe pas encore quand 520 s execute
    foreach ($v in @('CalHardAuto', 'CalHardNsUser', 'CalHardNs', 'CalHardNsDefault', 'CalHardMinNs', 'CalHardMaxNs')) { Remove-Variable -Scope Script -Name $v -ErrorAction SilentlyContinue }
    . $g.U500
    . $g.U510
    . $g.U520
    . $g.U540
    . $g.Def
    # U1 : avant l etat de 560 et avant Set-Defaults, la liste est vide, sans infobulle, et ne compte pas comme une option
    # avancee modifiee
    $u1a = "$($cmbWBound.Items.Count)/$(Get-PbBoundCounted $wantLbl[$L])/$([string]$tip.GetToolTip($cmbWBound))"
    . $g.State1
    $script:ScpStatsOk = $true
    $tabW.Font = $form.Font
    Fit-ControlText $tabW
    Set-WriteTabLayout
    $u1b = "$($cmbWBound.Items.Count)/$(Get-PbBoundCounted $wantLbl[$L])"
    Chk "U1$L" ($u1a -ceq '0/0/' -and $u1b -ceq '0/0' -and $lblWBound.Text -ceq $wantLbl[$L] -and $cmbWBound.DropDownStyle -eq [System.Windows.Forms.ComboBoxStyle]::DropDownList) "($L) avant l etat de 560, puis avant Set-Defaults : liste vide, sans infobulle, jamais comptee comme option modifiee (elements/comptee/infobulle : $u1a ; apres l etat et la disposition : $u1b) ; libelle « $($lblWBound.Text) », liste fermee"
    Invoke-PbDefaults
    $script:UiReady = $true
    $tabW.Size = New-Object System.Drawing.Size(792, 516)
    # U2 : elements et choix par defaut
    $items = @($cmbWBound.Items | ForEach-Object { [string]$_ })
    $wantItems = @($wantAuto[$L]) + @($std | Where-Object { $_ -gt 0 } | ForEach-Object { "$_ ns" })
    Chk "U2$L" (($items -join '|') -ceq ($wantItems -join '|') -and $items.Count -eq 19 -and $cmbWBound.SelectedIndex -eq 0 -and (@($cmbWBound.Tag) -join ',') -ceq ($std -join ',') -and (Get-PbSet) -ceq 'auto 400' -and (Get-PbAdvNames) -ceq '' -and (Get-PrecompBoundText 0) -ceq $wantAuto[$L]) "($L) apres Set-Defaults : $($items.Count) elements, « $($items[0]) » puis « $($items[1]) » a « $($items[$items.Count - 1]) » par pas de 10 ns ; element choisi : $($cmbWBound.SelectedIndex) ; reglage : $(Get-PbSet) ; aucune option avancee modifiee"
    # U3 : place et textes entiers, vue experte, pages de 792 et 808 px, onglet qui defile compris, valeur hors du pas
    $geo = @(); $nGeo = 0
    foreach ($pw in @(792, 808)) { foreach ($ph in @(516, 312)) {
        $tabW.Size = New-Object System.Drawing.Size(782, 516); $chkExpert.Checked = $true; $tabW.Size = New-Object System.Drawing.Size($pw, $ph)
        $chkExpert.Checked = $false; $chkExpert.Checked = $true
        foreach ($x in (Get-PbGeo)) { $geo += "$pw x $ph : $x" }; $nGeo++
    } }
    Set-PrecompBound $false 454
    foreach ($x in (Get-PbGeo)) { $geo += "valeur hors du pas : $x" }; $nGeo++
    Set-PrecompBound $true
    $u3b = "$($lblWBound.Bounds) ; liste $($cmbWBound.Bounds) ; cadre $($grpWAdv.Bounds)"
    $chkExpert.Checked = $false; $tabW.Size = New-Object System.Drawing.Size(792, 516)
    Chk "U3$L" ($geo.Count -eq 0 -and $nGeo -eq 5) "($L) liste et libelle dans le cadre des options avancees, textes entiers (libelle, chaque element + 16 px), liste a la suite de son libelle, aucun chevauchement : $nGeo dispositions (792 et 808 px, onglet qui defile compris, valeur hors du pas) ; libelle $u3b ; defauts : $(Get-List $geo 3)"
    # U4 : choix de 450 ns, puis de 400 ns, puis retour a l automatique
    $script:PbLog.Clear()
    $cmbWBound.SelectedIndex = [array]::IndexOf([int[]]@($cmbWBound.Tag), 450)
    $u4a = @{ Set = (Get-PbSet); Fams = (Get-PbFams); Adv = (Get-PbAdvNames); Link = [string]$lnkWAdv.Text; Log = ($script:PbLog -join ' # '); Tip = [string]$tip.GetToolTip($cmbWBound); Over = (Get-DiskOverNs) }
    $script:PbLog.Clear()
    $cmbWBound.SelectedIndex = [array]::IndexOf([int[]]@($cmbWBound.Tag), 400)
    $u4b = @{ Set = (Get-PbSet); Fams = (Get-PbFams); Adv = (Get-PbAdvNames); Log = ($script:PbLog -join ' # '); Tip = [string]$tip.GetToolTip($cmbWBound); Over = (Get-DiskOverNs) }
    $script:PbLog.Clear()
    $cmbWBound.SelectedIndex = 0
    $u4c = @{ Set = (Get-PbSet); Fams = (Get-PbFams); Adv = (Get-PbAdvNames); Log = ($script:PbLog -join ' # '); Link = [string]$lnkWAdv.Text }
    $script:PbLog.Clear()
    $cmbWBound.SelectedIndex = 0
    $u4d = $script:PbLog.Count
    $okA = ($u4a.Set -ceq 'choisie 450' -and $u4a.Fams -ceq '450/dd 450/dd 225/hd 450/dd' -and $u4a.Adv -ceq "$($wantLbl[$L]) 450 ns" -and $u4a.Link -ceq ((T 'Options avancées : {0} modifiée(s)…') -f '1') -and $u4a.Log -ceq ($wantLog[$L] -f '450 ns', $wantAuto[$L]) -and $u4a.Over -eq 450 -and $u4a.Tip.Contains(($wantOver[$L] -f '450')))
    $okB = ($u4b.Set -ceq 'choisie 400' -and $u4b.Fams -ceq '400/dd 400/dd 200/hd 400/dd' -and $u4b.Adv -ceq "$($wantLbl[$L]) 400 ns" -and $u4b.Log -ceq ($wantLog[$L] -f '400 ns', '450 ns') -and $u4b.Over -eq 400 -and $u4b.Tip.Contains(($wantOver[$L] -f '400')))
    $okC = ($u4c.Set -ceq 'auto 400' -and $u4c.Fams -ceq '400/dd 470/long 200/hd 400/dd' -and $u4c.Adv -ceq '' -and $u4c.Log -ceq ($wantLog[$L] -f $wantAuto[$L], '400 ns') -and $u4c.Link -ceq (T 'Options avancées…') -and $u4d -eq 0)
    Chk "U4$L" ($okA -and $okB -and $okC) "($L) 450 ns choisi : $($u4a.Set), bornes std long hd sans famille $($u4a.Fams), option « $($u4a.Adv) », lien « $($u4a.Link) », journal « $($u4a.Log) », controle impose au-dela de $($u4a.Over) ns dans l infobulle ($okA) ; 400 ns choisi : $($u4b.Set), $($u4b.Fams), « $($u4b.Adv) » ($okB) ; automatique : $($u4c.Set), $($u4c.Fams), journal « $($u4c.Log) », meme choix une seconde fois : $u4d ligne ($okC)"
    # U5 : valeur hors du pas de la liste (fichier de configuration) : elle prend son rang, reste choisie, puis reste
    # proposee quand une autre valeur est choisie (la liste n est jamais refaite pendant un choix)
    Set-PrecompBound $false 454
    $it5 = @($cmbWBound.Items | ForEach-Object { [string]$_ }); $i454 = [array]::IndexOf([string[]]$it5, '454 ns')
    $u5a = "$($it5.Count) elements, « 454 ns » entre « $($it5[$i454 - 1]) » et « $($it5[$i454 + 1]) », choisi : $([string]$cmbWBound.Text), reglage $(Get-PbSet), option « $(Get-PbAdvNames) »"
    $cmbWBound.SelectedIndex = [array]::IndexOf([int[]]@($cmbWBound.Tag), 460)
    $u5b = "$(@($cmbWBound.Items).Count) elements, choisi : $([string]$cmbWBound.Text), reglage $(Get-PbSet)"
    Invoke-PbDefaults
    $u5c = "$([string]$cmbWBound.Text) ; $(Get-PbSet)"
    Chk "U5$L" ($u5a -ceq "20 elements, « 454 ns » entre « 450 ns » et « 460 ns », choisi : 454 ns, reglage choisie 454, option « $($wantLbl[$L]) 454 ns »" -and $u5b -ceq '20 elements, choisi : 460 ns, reglage choisie 460' -and $u5c -ceq "$($wantAuto[$L]) ; auto 400") "($L) borne de 454 ns posee hors de la liste : $u5a ; puis 460 ns choisi : $u5b ; Set-Defaults : $u5c"
    # U6 : aucun changement pendant une operation (Get-AppBusy) ni avec une calibration B en attente
    $u6 = @(); $u6Log = @()
    foreach ($busy in @({ $script:Cal = @{ Mode = 'full' } }, { $script:CalRedo = @{ Wait = $true } })) {
        $script:PbLog.Clear()
        & $busy
        $cmbWBound.SelectedIndex = [array]::IndexOf([int[]]@($cmbWBound.Tag), 430)
        $u6 += "$(Get-PbSet)/$($cmbWBound.SelectedIndex)/$($script:PbLog.Count)/$(Get-PbFam 'long')"; $u6Log += @($script:PbLog.ToArray())
        $script:Cal = $null; $script:CalRedo = $null
    }
    $cmbWBound.SelectedIndex = [array]::IndexOf([int[]]@($cmbWBound.Tag), 430); $u6 += (Get-PbSet)
    Chk "U6$L" (($u6 -join ' ; ') -ceq 'auto 400/0/1/470/long ; auto 400/0/1/470/long ; choisie 430' -and ($u6Log -join ' # ') -ceq (@($wantBusy[$L], $wantBusy[$L]) -join ' # ')) "($L) calibration en cours, puis calibration B en attente : reglage, element choisi et borne du long track inchanges, une ligne de journal qui dit le refus (« $($wantBusy[$L]) ») ; au repos, le meme choix s applique : $($u6 -join ' ; ')"
    # U6b : molette sur la liste fermee (gestionnaire MouseWheel reel de 520, evenement reel, liste sans poignee :
    # DroppedDown faux) : evenement marque traite, element et reglage inchanges ; liste deroulee (corps reel du
    # gestionnaire, $this et $_ poses comme WinForms les pose) : rien, la molette la fait defiler
    $evW = New-Object System.Windows.Forms.HandledMouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 5, 5, -120)
    $script:PbLog.Clear(); $i430 = [array]::IndexOf([int[]]@($cmbWBound.Tag), 430)
    [System.Windows.Forms.Control].GetMethod('OnMouseWheel', [System.Reflection.BindingFlags]'Instance,NonPublic').Invoke($cmbWBound, [object[]]@([System.Windows.Forms.MouseEventArgs]$evW)) | Out-Null
    $u6b = "$($evW.Handled)/$($cmbWBound.SelectedIndex -eq $i430 -and $i430 -gt 0)/$(Get-PbSet)/$($script:PbLog.Count)"
    $whl = @($top520 | Where-Object { $_.Extent.Text.StartsWith('$cmbWBound.Add_MouseWheel(') })
    $evO = New-Object System.Windows.Forms.HandledMouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 5, 5, -120)
    $evC = New-Object System.Windows.Forms.HandledMouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 5, 5, 120)
    if ($whl.Count -eq 1) {
        $whlSb = @($whl[0].FindAll({ param($x) $x -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true))[0]
        Write-PbGen (Join-Path $here 'gen-molette.ps1') @("function Invoke-PbWheel(`$o, `$e) {`r`n    `$this = `$o; `$_ = `$e`r`n    " + [string]$whlSb.ScriptBlock.EndBlock.Extent.Text + "`r`n}")
        . (Join-Path $here 'gen-molette.ps1')
        Invoke-PbWheel ([pscustomobject]@{ DroppedDown = $true }) $evO
        Invoke-PbWheel ([pscustomobject]@{ DroppedDown = $false }) $evC
    }
    Chk "U6b$L" ($whl.Count -eq 1 -and $u6b -ceq 'True/True/choisie 430/0' -and -not $evO.Handled -and $evC.Handled) "($L) molette sur la liste fermee, 430 ns choisi (gestionnaire MouseWheel reel de 520) : evenement marque traite, element, reglage et journal inchanges ($u6b) ; liste deroulee : rien (la molette la fait defiler) ; non couvert : le defilement reel de l onglet dans la fenetre"
    # U7 : « Reinitialiser » (partie Ecriture de Set-Defaults)
    Invoke-PbDefaults
    Chk "U7$L" ((Get-PbSet) -ceq 'auto 400' -and $cmbWBound.SelectedIndex -eq 0 -and (Get-PbFams) -ceq '400/dd 470/long 200/hd 400/dd' -and (Get-PbAdvNames) -ceq '') "($L) Set-Defaults apres une borne choisie : $(Get-PbSet), element $($cmbWBound.SelectedIndex), bornes $(Get-PbFams), aucune option avancee modifiee"
    # U8 : infobulle
    $tipL = [string]$tip.GetToolTip($cmbWBound); $tl = @($tipL -split "`n")
    $need = if ($L -eq 'fr') { @('400 ns pour une image standard', '470 ns pour une image long track', 'le quart de sa cellule', 'de 300 à 470 ns', 'la moitié de la borne', 'la borne ne dépasse pas 470 ns', '(500 ns au plus)', "dès qu'elle dépasse 400 ns", 'garde la borne de son calcul', '(precompMaxNs)') }
            else { @('400 ns for a standard image', '470 ns for a long track image', 'a quarter of its', 'from 300 to 470 ns', 'half the bound', 'the bound does not exceed 470 ns', '(500 ns at most)', 'as soon as it exceeds 400 ns', 'keeps the bound of its computation', '(precompMaxNs)') }
    # Relecture : la sixieme ligne dit aussi la borne de la courbe ecrite avec un facteur (CalHardNsUser : 400 ns en
    # automatique, long track compris ; la valeur choisie sinon, cas U4 ; commandes : cas U9)
    $need += $wantCapA[$L]
    $missT = @($need | Where-Object { -not $tipL.Contains($_) })
    Chk "U8$L" ($tl.Count -eq 7 -and $missT.Count -eq 0 -and $tipL -ceq (Get-PrecompBoundTip) -and $tl[5].EndsWith($wantCapA[$L]) -and $u4a.Tip.Contains($wantCapC[$L])) "($L) infobulle de la liste : $($tl.Count) lignes, tirees des constantes de la borne et de Get-DiskOverNs (borne automatique, plage, quart de cellule, haute densite, plafond d une disquette, controle impose, courbes deja calculees et borne de la courbe ecrite avec un facteur : 400 ns en automatique, 450 ns avec 450 ns choisi, cle de la configuration) ; absents : $(Get-List $missT)"
    if ($L -ne 'fr') { continue }

    # ================================================================= F : borne par famille
    '--- F : borne par famille'
    Set-PrecompBound $true
    $f1 = Get-PbFams
    Chk 'F1' ($f1 -ceq '400/dd 470/long 200/hd 400/dd' -and (Get-PbSet) -ceq 'auto 400') "automatique : standard, long track, haute densite, sans famille : $f1"
    Set-PrecompBound $false 400
    $f2 = Get-PbFams
    Chk 'F2' ($f2 -ceq '400/dd 400/dd 200/hd 400/dd' -and (Get-PbSet) -ceq 'choisie 400' -and $f2 -cne (Get-PbRc3Fams 400)) "400 ns choisi : $f2 (regle de la rc3, qui lisait 400 comme « non regle » : $(Get-PbRc3Fams 400))"
    $f3 = @(); $f3Bad = @()
    foreach ($v in @(300, 350, 430, 454, 470)) { Set-PrecompBound $false $v; $x = Get-PbFams; $f3 += "$v : $x"; if ($x -cne "$v/dd $v/dd $([int]($v / 2))/hd $v/dd") { $f3Bad += "$v : $x" } }
    Set-PrecompBound $false 250; $f3lo = Get-PbSet; Set-PrecompBound $false 600; $f3hi = Get-PbSet; Set-PrecompBound $true 450; $f3au = Get-PbSet
    Chk 'F3' ($f3Bad.Count -eq 0 -and $f3lo -ceq 'choisie 300' -and $f3hi -ceq 'choisie 470' -and $f3au -ceq 'auto 400') "valeurs choisies, la meme en standard et en long track, moitie en haute densite : $($f3 -join ' ; ') ; 250 ns : $f3lo ; 600 ns : $f3hi ; automatique avec une valeur : $f3au"
    $f4 = @()
    foreach ($c in @(@($true, 0), @($false, 400), @($false, 450), @($false, 350))) {
        Set-PrecompBound $c[0] $c[1]
        Set-CalibScale 'long'; Set-DiskHardNs @{ DiskOnly = $true; HardNs = 472 }; $during = [int]$script:CalHardNs
        Reset-DiskHardNs; $after = "$($script:CalHardNs)/$($script:CalScaleFam)"; Set-CalibScale ''
        $f4 += "$(Get-PbSet) : controle au-dela de $(Get-DiskOverNs), plafond long track $(Get-DiskHardNs 105808), mesure complete $during puis $after"
    }
    Set-PrecompBound $true
    $f4Want = @('auto 400 : controle au-dela de 400, plafond long track 472, mesure complete 472 puis 470/long', 'choisie 400 : controle au-dela de 400, plafond long track 472, mesure complete 472 puis 400/dd',
                'choisie 450 : controle au-dela de 450, plafond long track 472, mesure complete 472 puis 450/dd', 'choisie 350 : controle au-dela de 400, plafond long track 350, mesure complete 472 puis 350/dd')
    Chk 'F4' (($f4 -join ' | ') -ceq ($f4Want -join ' | ')) "seuil du controle impose (Get-DiskOverNs), plafond d une disquette long track de 105 808 cellules (Get-DiskHardNs), borne pendant puis apres une mesure complete en long track (Set-DiskHardNs, Reset-DiskHardNs) : $($f4 -join ' | ')"
    $script:DriveCurves = @{ 'A|long' = @{ Values = [int[]]@(380, 400, 400); Cyls = [int[]]@(0, 40, 79); MaxNs = 400; Date = '01/11/2026 10:00'; Drive = 'A'; Calc = '12.10' }; 'A|std' = @{ Values = [int[]]@(100, 300, 470); Cyls = [int[]]@(0, 40, 79); MaxNs = 470; Date = '01/11/2026 11:00'; Drive = 'A'; Calc = '12.10' } }
    $cv0 = ($script:DriveCurves | ConvertTo-Json -Depth 5 -Compress)
    foreach ($c in @(@($false, 300), @($false, 470), @($false, 400), @($true, 0))) { Set-PrecompBound $c[0] $c[1] }
    $cv1 = ($script:DriveCurves | ConvertTo-Json -Depth 5 -Compress)
    Chk 'F5' ($cv0 -ceq $cv1 -and (Get-CurveMaxNs $script:DriveCurves['A|long']) -eq 400 -and (Get-CurveMaxNs $script:DriveCurves['A|std']) -eq 470) "courbes deja calculees : valeurs et borne de leur calcul inchangees apres quatre reglages (300, 470 et 400 ns choisis, automatique) : $(Get-CurveMaxNs $script:DriveCurves['A|long']) et $(Get-CurveMaxNs $script:DriveCurves['A|std']) ns"
    $script:DriveCurves = @{}

    # ================================================================= C : configuration
    '--- C : configuration (instructions reelles de Load-Config, expressions reelles de Save-Config)'
    $kSet = 'réglée dans la configuration (precompMaxNs) : {0} ns'; $kClamp = 'ramenée à {0} ns'; $kBad = 'illisible'; $kPick = 'Borne de précompensation choisie : 400 ns en standard comme en long track (en automatique : 470 ns en long track) ; la haute densité en prend la moitié.'
    # C1 : version anterieure (aucune cle precompMaxAuto)
    $c1 = @(
        @('{}', 'auto 400', ''), @('{"precompMaxNs":400}', 'auto 400', ''), @('{"precompMaxNs":400.4}', 'auto 400', ''), @('{"precompMaxNs":"400"}', 'auto 400', ''), @('{"precompMaxNs":null}', 'auto 400', ''),
        @('{"precompMaxNs":430}', 'choisie 430', ($kSet -f '430')), @('{"precompMaxNs":470}', 'choisie 470', ($kSet -f '470')), @('{"precompMaxNs":350}', 'choisie 350', ($kSet -f '350')), @('{"precompMaxNs":399}', 'choisie 399', ($kSet -f '399')),
        @('{"precompMaxNs":250}', 'choisie 300', ($kClamp -f '300')), @('{"precompMaxNs":900}', 'choisie 470', ($kClamp -f '470')), @('{"precompMaxNs":"abc"}', 'auto 400', $kBad), @('{"precompMaxNs":true}', 'auto 400', $kBad))
    $c1Bad = @()
    foreach ($c in $c1) {
        $r = Invoke-PbRead $c[0]
        $okLog = if ($c[2]) { ($r.Log.Count -eq 1 -and ([string]$r.Log[0]).Contains($c[2])) } else { ($r.Log.Count -eq 0) }
        $wantItem = if ($c[1] -ceq 'auto 400') { $wantAuto['fr'] } else { ($c[1] -replace '^choisie ', '') + ' ns' }
        if ($r.Set -cne $c[1] -or -not $okLog -or $r.Item -cne $wantItem) { $c1Bad += "$($c[0]) : $($r.Set), liste « $($r.Item) », journal $($r.Log.Count) ligne(s)" }
    }
    Chk 'C1' ($c1Bad.Count -eq 0 -and $c1.Count -eq 13) "$($c1.Count) sections write d une version anterieure (sans precompMaxAuto) : cle absente ou 400 ns = automatique, sans ligne de journal ; autre valeur = valeur reglee, signalee comme avant ; valeur hors plage ramenee a 300 ou 470 ns ; valeur illisible = automatique, signalee ; la liste montre le reglage ; ecarts : $(Get-List $c1Bad 3)"
    # C2 : toutes les valeurs, toutes les familles : la regle de la rc3
    $c2Bad = @(); $n2 = 0
    foreach ($v in @(@(250..520) + @(0, -5, 1000))) {
        $r = Invoke-PbRead "{`"precompMaxNs`":$v}"; $n2++
        if ($r.Fams -cne (Get-PbRc3Fams $v)) { $c2Bad += "$v : $($r.Fams) au lieu de $(Get-PbRc3Fams $v)" }
    }
    Chk 'C2' ($c2Bad.Count -eq 0 -and $n2 -eq 274) "$n2 valeurs de precompMaxNs d une version anterieure (250 a 520 ns, 0, -5, 1000) : bornes standard, long track, haute densite et sans famille egales a celles de la regle de la rc3 (aucun changement pour une configuration existante) ; ecarts : $(Get-List $c2Bad 3)"
    # C3 : cle precompMaxAuto
    $c3 = @(
        @('{"precompMaxNs":400,"precompMaxAuto":true}', 'auto 400', 0), @('{"precompMaxNs":400,"precompMaxAuto":false}', 'choisie 400', 1), @('{"precompMaxNs":400,"precompMaxAuto":"false"}', 'choisie 400', 1),
        @('{"precompMaxNs":430,"precompMaxAuto":true}', 'choisie 430', 1), @('{"precompMaxNs":430,"precompMaxAuto":false}', 'choisie 430', 1), @('{"precompMaxAuto":false}', 'auto 400', 0),
        @('{"precompMaxNs":"abc","precompMaxAuto":false}', 'auto 400', 1), @('{"precompMaxNs":400,"precompMaxAuto":"non"}', 'auto 400', 0), @('{"precompMaxNs":400,"precompMaxAuto":0}', 'auto 400', 0),
        @('{"precompMaxNs":400,"precompMaxAuto":[false,true]}', 'auto 400', 0), @('{"precompMaxNs":400,"precompMaxAuto":null}', 'auto 400', 0))
    $c3Bad = @()
    foreach ($c in $c3) { $r = Invoke-PbRead $c[0]; if ($r.Set -cne $c[1] -or $r.Log.Count -ne $c[2]) { $c3Bad += "$($c[0]) : $($r.Set), $($r.Log.Count) ligne(s)" } }
    $r400 = Invoke-PbRead '{"precompMaxNs":400,"precompMaxAuto":false}'
    Chk 'C3' ($c3Bad.Count -eq 0 -and $c3.Count -eq 11 -and $r400.Fams -ceq '400/dd 400/dd 200/hd 400/dd' -and $r400.Log.Count -eq 1 -and [string]$r400.Log[0] -ceq $kPick -and $r400.Item -ceq '400 ns') "$($c3.Count) sections write avec precompMaxAuto : 400 ns et faux = 400 ns choisi ($($r400.Fams) ; journal « $($r400.Log -join ' # ') ») ; 400 ns et vrai, cle illisible ou valeur non lue = automatique ; une valeur autre que 400 ns reste une valeur reglee quoi que dise la cle ; ecarts : $(Get-List $c3Bad 3)"
    # C4 : enregistrement (expressions de Save-Config) puis relecture ; meme fichier relu par la regle de la rc3
    $c4Bad = @(); $c4 = @()
    foreach ($c in @(@($true, 0), @($false, 400), @($false, 300), @($false, 450), @($false, 454), @($false, 470))) {
        Set-PrecompBound $c[0] $c[1]
        $s0 = Get-PbSet; $f0 = Get-PbFams
        $sv = Get-PbSaved
        $json = (@{ write = $sv } | ConvertTo-Json -Depth 4)
        Set-PrecompBound $true
        $script:PbLog.Clear()
        Invoke-PbLoad (ConvertTo-PbW $json).write
        $c4 += "$s0 -> precompMaxNs $($sv.precompMaxNs), precompMaxAuto $($sv.precompMaxAuto)"
        if ((Get-PbSet) -cne $s0 -or (Get-PbFams) -cne $f0 -or $sv.precompMaxNs -isnot [int] -or $sv.precompMaxAuto -isnot [bool]) { $c4Bad += "$s0 relu $(Get-PbSet), $(Get-PbFams)" }
        if ($c[0] -and ($sv.precompMaxNs -ne 400 -or (Get-PbRc3Fams ([int]$sv.precompMaxNs)) -cne $f0)) { $c4Bad += "automatique enregistre $($sv.precompMaxNs) : une version anterieure ne le relirait pas comme avant" }
    }
    Set-PrecompBound $true
    Chk 'C4' ($c4Bad.Count -eq 0 -and $c4.Count -eq 6 -and $c4[0] -ceq 'auto 400 -> precompMaxNs 400, precompMaxAuto True' -and $c4[1] -ceq 'choisie 400 -> precompMaxNs 400, precompMaxAuto False') "enregistrement puis relecture, reglage et bornes retrouves : $($c4 -join ' ; ') ; le reglage automatique s enregistre a 400 ns, qu une version anterieure relit comme avant ; ecarts : $(Get-List $c4Bad 3)"
    # C5 : configurations reelles, avec -Config seulement (aucune valeur affichee)
    if (-not $Config) { 'C5       saute : sans -Config <fichier ou dossier>, aucune configuration reelle n est relue' }
    else {
        $cf = @(if (Test-Path -LiteralPath $Config -PathType Container) { Get-ChildItem -LiteralPath $Config -Filter '*.json' -File -Recurse | ForEach-Object { $_.FullName } } else { $Config })
        $c5Bad = 0; $n5 = 0; $n5Auto = 0
        foreach ($p in $cf) {
            $o = $null; try { $o = ([System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) | ConvertFrom-Json) } catch { }
            if ($null -eq $o -or -not ($o.PSObject.Properties.Name -contains 'write')) { continue }
            $n5++
            $raw = Get-Cfg $o.write 'precompMaxNs' 400
            $script:PbLog.Clear()
            Invoke-PbLoad $o.write
            $x = 0.0; $rv = 400
            if ([double]::TryParse(([string]$raw).Trim(), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$x)) { $rv = [int][math]::Round([math]::Max(-1e9, [math]::Min(1e9, $x))) }
            if ($script:CalHardAuto) { $n5Auto++ }
            if ((Get-PbFams) -cne (Get-PbRc3Fams $rv) -and -not ($o.write.PSObject.Properties.Name -contains 'precompMaxAuto')) { $c5Bad++ }
        }
        Set-PrecompBound $true
        Chk 'C5' ($n5 -gt 0 -and $c5Bad -eq 0) "-Config : $n5 configuration(s) reelle(s) relue(s), dont $n5Auto en reglage automatique : bornes des quatre familles egales a celles de la regle de la rc3 ; ecarts : $c5Bad"
    }

    # ================================================================= U9 : commandes gw
    '--- U9 : commandes gw d une ecriture'
    $w0 = Invoke-PbWrite { }
    $wSets = @(@($false, 400), @($false, 450), @($false, 300), @($false, 470))
    $u9Bad = @()
    foreach ($c in $wSets) { $w = Invoke-PbWrite { Set-PrecompBound $c[0] $c[1] }; if (($w -join "`n") -cne ($w0 -join "`n")) { $u9Bad += "rapide, $($c[1]) ns" } }
    $s0 = Invoke-PbWrite { $chkWSlow.Checked = $true; $chkWLevel.Checked = $false; $txtWPrecomp.Text = '0=100:40=130'; $txtWPrecomp1.Text = '0=110:40=140' }
    foreach ($c in $wSets) { $w = Invoke-PbWrite { $chkWSlow.Checked = $true; $chkWLevel.Checked = $false; $txtWPrecomp.Text = '0=100:40=130'; $txtWPrecomp1.Text = '0=110:40=140'; Set-PrecompBound $c[0] $c[1] }; if (($w -join "`n") -cne ($s0 -join "`n")) { $u9Bad += "lente, $($c[1]) ns" } }
    Invoke-PbDefaults
    $nW = @(@($w0) + @($s0) | Where-Object { $_ -match '^(ecriture|file) write ' }).Count; $nErr = @(@($w0) + @($s0) | Where-Object { $_ -like 'ERREUR*' }).Count
    foreach ($x in @($w0 | Where-Object { $_ -match ' write ' })) { "  U9 rapide : $x" }
    Chk 'U9' ($u9Bad.Count -eq 0 -and $nW -eq 3 -and $nErr -eq 0) "ecriture rapide puis lente d une image ADF par le bouton ECRIRE (vraie Start-WriteTabWrite), au facteur 1 : commandes gw, file d ecriture, controle et demandes identiques avec la borne automatique et avec 400, 450, 300 et 470 ns choisis ($nW commandes gw write, $nErr erreur) ; ecarts : $(Get-List $u9Bad)"
    # U9b (relecture) : ecriture avec un facteur de precompensation (facteur 1,20 mesure sur la disquette, pose comme le
    # fait la mesure qui precede l ecriture ; courbe du lecteur factice en magasin, champs 0=280:40=350, vraie
    # Start-ImageWrite) : la borne en place plafonne la courbe ecrite, w = min(round(f x v), max(borne, v)) ; le journal le dit
    function New-PbCurve {
        $v = [int[]]@(for ($c = 0; $c -lt 80; $c++) { 120 + [int][math]::Floor($c / 2) })
        $cy = [int[]]@(for ($c = 0; $c -lt 80; $c += 4) { $c })
        return @{ Values = $v; Cyls = $cy; Kinds = [string[]]@($cy | ForEach-Object { 'interp' }); Res = [double[]]@($cy | ForEach-Object { 0.5 }); Ys = [double[]]@($cy | ForEach-Object { [double]$v[$_] })
                  Sig = [double[]]@($cy | ForEach-Object { 1.0 }); Breaks = @(); Date = '01/11/2026 10:00'; Test = 'fine'; Drive = 'A'; Method = 'motif'; Bits = 101344; Slope = -1.0; Converged = $true; MaxNs = 400
                  Spec = "0=120:79=$($v[79])"; Calc = '12.10' }
    }
    function Invoke-PbFactorWrite([bool]$auto, [int]$ns, [string]$fam = 'std') {
        Invoke-PbDefaults
        $script:DriveCurves = @{ "A|$fam" = (New-PbCurve) }; Sync-PrecompCurves
        $txtWFile.Text = $imAdf; $cmbWFmt.SelectedItem = 'amiga.amigados'
        Set-PrecompBound $auto $ns
        $txtWPrecomp.Text = '0=280:40=350'; $txtWPrecomp1.Text = '0=280:40=350'; $chkWPostCheck.Checked = $false
        $script:PbTrace.Clear(); $script:PbLog.Clear()
        $script:WriteQueue.Clear(); $script:Chain.Clear(); $script:WriteArgs = $null; $script:Rep = $null
        $script:LevelPostForce = $false; $script:Restore = $null; $script:GwProc = $null
        $script:WriteFactorNext = @{ Drive = 'A'; Fam = $fam; Img = $imAdf; K = @{ 0 = 1.2; 1 = 1.2 }; Brand = 'Marque inventee' }
        try { Start-ImageWrite } catch { [void]$script:PbTrace.Add("ERREUR $($_.Exception.Message)") }
        $w = @($script:PbTrace | Where-Object { $_ -match '^(ecriture|file|gw) write ' -or $_ -like 'ERREUR*' } | ForEach-Object { ([string]$_).Replace($pbImg, '<img>') })
        $j = @($script:PbLog | Where-Object { $_ -match 'bornée à 0\.\.\d+ ns' } | ForEach-Object { [regex]::Match([string]$_, 'bornée à 0\.\.\d+ ns').Value })
        $script:WriteQueue.Clear(); $script:Chain.Clear(); $script:WriteArgs = $null; $script:Rep = $null; $script:WriteFactorNext = $null
        return "$($w -join ' | ') # $($j -join ' | ')"
    }
    $u9f = [ordered]@{}
    foreach ($c in @(@($true, 0), @($false, 300), @($false, 470))) { $u9f["$(if ($c[0]) { 'automatique' } else { "$($c[1]) ns" })"] = Invoke-PbFactorWrite $c[0] $c[1] }
    # 12.11 rc4 (decision de l utilisateur) : image long track (famille simulee : Get-ImageFamily remplacee le temps des
    # deux ecritures, puis remise) : en automatique, borne de la reference long track (470 ns) ; 400 ns choisi : 400 ns
    $gifSave = ${function:Get-ImageFamily}
    Set-Item -Path function:script:Get-ImageFamily -Value { param([string]$path, [string]$fmt = '') return 'long' }
    $u9l = [ordered]@{ 'automatique, long track' = (Invoke-PbFactorWrite $true 0 'long'); '400 ns, long track' = (Invoke-PbFactorWrite $false 400 'long') }
    Set-Item -Path function:script:Get-ImageFamily -Value $gifSave
    foreach ($k in @($u9l.Keys)) { "  U9c $k : $($u9l[$k])" }
    Chk 'U9c' ($u9l['automatique, long track'].Contains('--precomp 0=336:40=420 ') -and $u9l['automatique, long track'].EndsWith('# bornée à 0..470 ns') -and $u9l['400 ns, long track'].Contains('--precomp 0=336:40=400 ') -and $u9l['400 ns, long track'].EndsWith('# bornée à 0..400 ns')) "image long track, facteur 1,20 (vraie Start-ImageWrite, champs 0=280:40=350) : en automatique, courbe ecrite bornee a 470 ns comme la reference de la famille (0=336:40=420) ; 400 ns choisi : 400 ns (0=336:40=400)"
    $script:DriveCurves = @{}; Sync-PrecompCurves; Invoke-PbDefaults
    $u9w = { param($p, $b) "ecriture write --drive=A --erase-empty --retries=10 --precomp $p --format=amiga.amigados `"<img>\jeu.adf`" # bornée à 0..$b ns" }
    $u9fWant = [ordered]@{ 'automatique' = (& $u9w '0=336:40=400' 400); '300 ns' = (& $u9w '0=300:40=350' 300); '470 ns' = (& $u9w '0=336:40=420' 470) }
    $u9fBad = @($u9fWant.Keys | Where-Object { [string]$u9f[$_] -cne [string]$u9fWant[$_] } | ForEach-Object { "$_ : « $($u9f[$_]) »" })
    foreach ($k in @($u9f.Keys)) { "  U9b $k : $($u9f[$k])" }
    Chk 'U9b' ($u9fBad.Count -eq 0 -and (Get-PbSet) -ceq 'auto 400') "ecriture rapide de la meme image avec un facteur de precompensation de 1,20 (vraie Start-ImageWrite, champs 0=280:40=350) : la borne en place plafonne la courbe ecrite : --precomp 0=336:40=400 en automatique, 0=300:40=350 avec 300 ns choisi (350, deja au-dessus, n est pas augmente), 0=336:40=420 avec 470 ns choisi ; le journal dit « bornée à 0..N ns » ; non couvert : image long track ; ecarts : $(Get-List $u9fBad 2)"
}

# =====================================================================================================================
'--- I, D : textes et documents'
# I1 : cles T du lot (fonctions de la borne, libelle de 520, ligne de Load-Config) : entree anglaise dans 019, differente
# du francais, memes {n}
$keys = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
$src = @($fnAst['Get-PrecompBoundTip'].Body, $fnAst['Get-PrecompBoundText'].Body, $fnAst['Set-PrecompBoundFromUi'].Body) + @($top520)
foreach ($n in $src) {
    foreach ($c in $n.FindAll({ param($x) $x -is $tCmdA -and $x.GetCommandName() -eq 'T' }, $true)) {
        if ($c.CommandElements.Count -eq 2 -and $c.CommandElements[1] -is $tStrA) { [void]$keys.Add([string]$c.CommandElements[1].Value) }
    }
}
foreach ($c in $fnAst['Load-Config'].Body.FindAll({ param($x) $x -is $tCmdA -and $x.GetCommandName() -eq 'T' }, $true)) {
    if ($c.CommandElements.Count -eq 2 -and $c.CommandElements[1] -is $tStrA -and ([string]$c.CommandElements[1].Value).StartsWith('Borne de précompensation choisie')) { [void]$keys.Add([string]$c.CommandElements[1].Value) }
}
$t019 = [System.IO.File]::ReadAllText((Get-PbMod '019'), [System.Text.Encoding]::UTF8)
$iR2 = $t019.IndexOf('# R2 : borne de precompensation reglable'); $iRc4 = $t019.IndexOf('# --- rc4 :')
function Get-PbPh([string]$s) { return ((@([regex]::Matches($s, '\{\d+\}') | ForEach-Object { $_.Value } | Sort-Object -Unique)) -join '') }
$i1Bad = @()
foreach ($k in $keys) {
    if (-not $script:I18n.ContainsKey($k)) { $i1Bad += "sans entree : $k"; continue }
    $en = [string]$script:I18n[$k]
    if (-not $en -or $en -ceq $k) { $i1Bad += "non traduite : $k" }
    if ((Get-PbPh $en) -cne (Get-PbPh $k)) { $i1Bad += "{n} differents : $k" }
    $ik = $t019.IndexOf($k, [System.StringComparison]::Ordinal)
    if ($ik -lt $iR2) { $i1Bad += "hors de la section R2 de 019 : $k" }
}
Chk 'I1' ($keys.Count -eq 14 -and $i1Bad.Count -eq 0 -and $iRc4 -ge 0 -and $iR2 -gt $iRc4) "$($keys.Count) textes du lot (libelle, element « automatique », sept lignes de l infobulle, trois lignes de journal, dont celle du choix refuse pendant une operation) : entree anglaise dans la section R2 de 019 (sous « rc4 »), differente du francais, memes {n} ; ecarts : $(Get-List $i1Bad 3)"
$ch = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
$m = [regex]::Match($ch, '(?s)## \[12\.11\].*?(?=\n## \[)'); $sec = if ($m.Success) { $m.Value } else { '' }
$amel = ''; $ma = [regex]::Match($sec, '(?s)### Améliorations.*?(?=\n### )'); if ($ma.Success) { $amel = $ma.Value }
$sav = ''; $ms = [regex]::Match($sec, '(?s)### À savoir pour la mise à jour.*?(?=\n### )'); if ($ms.Success) { $sav = $ms.Value }
$dev = ''; $md = [regex]::Match($sec, '(?s)### Pour les développeurs.*$'); if ($md.Success) { $dev = $md.Value }
$d1 = [ordered]@{
    'entree des Améliorations' = $amel.Contains('**Borne de précompensation : 470 ns en long track, réglable dans les options avancées.**')
    'liste nommee' = $amel.Contains('« Borne de précompensation »') -and $amel.Contains('« Automatique (400 ns ; 470 ns en long track) »')
    'courbes deja calculees' = $amel.Contains('garde la borne de son calcul')
    'borne de la courbe ecrite avec un facteur' = ($amel.Contains('la borne en place plafonne aussi la courbe multipliée par le facteur de précompensation') -and $amel.Contains('400 ns en standard et 470 ns en long track, comme la courbe de référence de la famille'))
    'a savoir : haute densite a la moitie' = $sav.Contains('la même en standard et en long track (la haute densité en prend la moitié)')
    'a savoir : configuration existante' = ($sav.Contains('**Borne de précompensation : ce que devient le réglage d''une configuration existante.**') -and $sav.Contains('passe au réglage automatique') -and $sav.Contains('choisissez « 400 ns » dans la liste « Borne de précompensation »'))
    'plus de detour par 399 ns' = (-not $sec.Contains('399 ns'))
    'developpeurs' = ($dev.Contains('`Set-PrecompBound([bool]$auto, [int]$ns)`') -and $dev.Contains('`write.precompMaxAuto`') -and $dev.Contains('`tests/logic-precomp-borne.ps1`'))
    'materiel' = ($sec -notmatch 'vérifiée? sur (du )?matériel')
}
$d1Bad = @($d1.Keys | Where-Object { -not $d1[$_] })
Chk 'D1' ($d1Bad.Count -eq 0) "CHANGELOG 12.11 : Améliorations (borne propre a la famille et reglage dans les options avancees, liste et son element automatique, courbes deja calculees), A savoir (reglage d une configuration existante : 400 ns passe a l automatique, 400 ns en long track par la liste, plus de valeur de contournement), Pour les developpeurs (Set-PrecompBound, precompMaxAuto, ce test) ; ecarts : $(Get-List $d1Bad)"
$rd = [System.IO.File]::ReadAllText((Join-Path $mods 'README.md'), [System.Text.Encoding]::UTF8)
$trd = [System.IO.File]::ReadAllText((Join-Path $Wt 'tests\README.md'), [System.Text.Encoding]::UTF8)
$noDoc = @(@('Set-PrecompBound', 'Get-PrecompBoundChoices', 'Get-PrecompBoundText', 'Update-WBoundUi', 'Get-PrecompBoundTip', 'Set-PrecompBoundFromUi') | Where-Object { -not $rd.Contains("``$_``") })
Chk 'D2' ($noDoc.Count -eq 0 -and $rd.Contains('`cmbWBound`') -and $rd.Contains('`$script:CalHardAuto`') -and $trd.Contains('| `logic-precomp-borne` |')) "README des modules : fonctions de la borne citees (absentes : $(Get-List $noDoc)), liste cmbWBound, etat CalHardAuto ; README des tests : ligne de logic-precomp-borne"

$nk = ''; if ($script:Fail) { $nk = ' ; non conformes : ' + (@($script:FailIds) -join ', ') }
"=== bilan logic-precomp-borne : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
