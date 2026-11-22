param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Before = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 rc4 : verification de gw pendant l ecriture de l image. R9 (controle a la place de la verification) retire a la
# demande de l utilisateur : le controle de toutes les pistes juge le signal sans comparer le contenu a l image, la
# verification de gw compare le contenu ; les deux sont gardees. Decision : Get-WriteVerifyPlan (140), case « Sans
# verification » et champ « Essais » seuls, controle ou non (commandes de la rc3, 49c9b5f) ; jamais grises.
# Attendus des cas : commandes de R9 converties en celles de la rc3 (ConvertTo-VfRc3 : --no-verify seul remplace par
# les options de la case et du champ du cas).
#  S  statique (arbre syntaxique) : S1 une seule decision (Start-ImageWrite, la ligne « Ce qui va se passer », la case et
#     le journal la lisent ; aucune autre fonction de l ecriture ne pose --no-verify ni --retries) ; S2 mesures de la
#     disquette et calibrations (modules 2xx) : aucune reference a la case, au champ ni a la decision, --no-verify en dur
#     comme avant ; S3 reglages de la restauration (Start-RestoreWrite) que le cas V6 rejoue.
#  V  commandes exactes de gw write, avec et sans controle, par chemin : V1 onglet, ecriture rapide ; V2 onglet, ecriture
#     lente ; V3 controle non applicable (haute densite) et controle impose (courbe adaptee) ; V4 lecteur cible ; V5
#     Bibliotheque (vraies Set-WritePreset et Start-PresetWrite) ; V6 restauration (reglages de Start-RestoreWrite, vraie
#     Start-PresetWrite -NoCalib) ; V7 reecritures des pistes faibles (vraie Invoke-WriteCheckAnalysis sur la base que
#     Start-ImageWrite donne au controle) ; V8 image flux ecrite telle quelle (relecture du lot : gw ne verifie pas un
#     flux brut, la ligne le dit, la commande ne change pas).
#  P  ligne « Ce qui va se passer » : segment de la verification de gw = commandes du clic, sauf pour le flux brut, que gw
#     ne verifie jamais (segment propre) ; J journal ; U case « Sans
#     verification », libelle et champ « Essais » (etat, infobulles, valeurs gardees, avant l affichage de la fenetre) ;
#     E poids estimes de l ecriture (barre de l onglet) ; I textes ; D CHANGELOG, README, version montree.
#  B  avec -Before <source d avant le lot> : pour chaque cas, commandes, demandes, fenetres et journal identiques ligne a
#     ligne, aux options --no-verify et --retries des commandes gw write et aux lignes de journal du lot pres ; modules 2xx :
#     lignes --no-verify et --retries identiques.
# Fonctions et instructions reelles extraites par l arbre syntaxique, ecrites dans des fichiers de travail puis chargees
# par dot-source ; controles WinForms reels jamais affiches ; images factices sous le dossier de travail. Aucun gw, aucune
# fenetre, aucune compilation. Non couvert : gw lui-meme (effet de --no-verify sur une disquette), la vraie
# Start-RestoreWrite (ses reglages sont rejoues, son deroulement non), le rendu reel de la case inactive dans la fenetre.
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
function Get-VfMod([string]$root, [string]$px) {
    $f = @(Get-ChildItem -LiteralPath (Join-Path $root 'src\modules') -Filter "$px-*.ps1" -File)
    if ($f.Count -ne 1) { throw "module $px introuvable sous $root" }
    return $f[0].FullName
}
$utf8b = New-Object System.Text.UTF8Encoding($true)
$tAsgA = [System.Management.Automation.Language.AssignmentStatementAst]
$tFnA = [System.Management.Automation.Language.FunctionDefinitionAst]
$tCmdA = [System.Management.Automation.Language.CommandAst]
$tVarA = [System.Management.Automation.Language.VariableExpressionAst]
$tStrA = [System.Management.Automation.Language.StringConstantExpressionAst]
$tExpA = [System.Management.Automation.Language.ExpandableStringExpressionAst]
function Write-VfGen([string]$path, $parts) { [System.IO.File]::WriteAllText($path, ((@($parts) -join "`r`n`r`n") + "`r`n"), $utf8b) }
$mods = Join-Path $Wt 'src\modules'
# Table I18n et fonction T (modules 01x), chargees comme par l application
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'

# =====================================================================================================================
'--- S : statique (arbre syntaxique des modules)'
$fnAst = @{}; $fnMod = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File)) {
    foreach ($d in (Get-Ast $f.FullName).FindAll({ param($x) $x -is $tFnA }, $false)) { $fnAst[$d.Name] = $d; $fnMod[$d.Name] = $f.Name.Substring(0, 3) }
}
function Get-VfCalls([string]$fn) {
    if (-not $fnAst.ContainsKey($fn)) { return ,@() }
    return ,@($fnAst[$fn].Body.FindAll({ param($x) $x -is $tCmdA }, $true) | ForEach-Object { [string]$_.GetCommandName() } | Where-Object { $_ } | Sort-Object -Unique)
}
function Get-VfVars($ast) { return ,@($ast.FindAll({ param($x) $x -is $tVarA }, $true) | ForEach-Object { [string]$_.VariablePath.UserPath } | Sort-Object -Unique) }
function Get-VfStrings($ast) { return ,@($ast.FindAll({ param($x) $x -is $tStrA -or $x -is $tExpA }, $true) | ForEach-Object { [string]$_.Value }) }
$hasDec = ($fnAst.ContainsKey('Get-WriteVerifyPlan') -and $fnAst.ContainsKey('Get-WriteVerifyText'))
# Fonctions de l ecriture et de son controle (140, 145, 160, 170) dont un litteral porte --no-verify ou --retries
$optFns = @()
foreach ($n in @($fnAst.Keys | Sort-Object)) {
    if (@('140', '145', '160', '170') -notcontains $fnMod[$n]) { continue }
    if (@((Get-VfStrings $fnAst[$n].Body) | Where-Object { $_ -match '--no-verify|--retries' }).Count) { $optFns += $n }
}
$siw = Get-VfCalls 'Start-ImageWrite'
$siwVars = if ($fnAst.ContainsKey('Start-ImageWrite')) { Get-VfVars $fnAst['Start-ImageWrite'].Body } else { @() }
$wcaVars = if ($fnAst.ContainsKey('Invoke-WriteCheckAnalysis')) { Get-VfVars $fnAst['Invoke-WriteCheckAnalysis'].Body } else { @() }
$wcaText = if ($fnAst.ContainsKey('Invoke-WriteCheckAnalysis')) { [string]$fnAst['Invoke-WriteCheckAnalysis'].Extent.Text } else { '' }
$siwText = if ($fnAst.ContainsKey('Start-ImageWrite')) { [string]$fnAst['Start-ImageWrite'].Extent.Text } else { '' }
$s1 = [ordered]@{
    'decision presente (Get-WriteVerifyPlan, Get-WriteVerifyText)' = $hasDec
    'Start-ImageWrite lit la decision, sur le controle decide' = ($siw -contains 'Get-WriteVerifyPlan' -and $siwText.Contains('$vp = Get-WriteVerifyPlan $cp') -and $siwText.Contains('$base += $vp.Args'))
    'Start-ImageWrite ne lit plus la case ni le champ' = ($siwVars -notcontains 'chkWNoVerify' -and $siwVars -notcontains 'numWRetries')
    'options posees par la seule decision' = ($optFns -contains 'Get-WriteVerifyPlan' -and @($optFns | Where-Object { @('Get-WriteVerifyPlan', 'Get-WriteVerifyText') -notcontains $_ }).Count -eq 0)
    'ligne « Ce qui va se passer »' = ((Get-VfCalls 'Get-WritePlan') -contains 'Get-WriteVerifyPlan' -and (Get-VfCalls 'Get-WritePlan') -contains 'Get-WriteVerifyText')
    'case et champ' = ((Get-VfCalls 'Update-WVerifyUi') -contains 'Get-WriteVerifyPlan' -and (Get-VfCalls 'Update-WVerifyUi') -contains 'Get-WriteVerifyText' -and (Get-VfCalls 'Update-WritePlanUi') -contains 'Update-WVerifyUi')
    'decision : case et champ seuls, sans le controle' = ($fnAst.ContainsKey('Get-WriteVerifyPlan') -and (Get-VfVars $fnAst['Get-WriteVerifyPlan'].Body) -notcontains 'cp' -and (Get-VfVars $fnAst['Get-WriteVerifyPlan'].Body) -contains 'chkWNoVerify' -and (Get-VfVars $fnAst['Get-WriteVerifyPlan'].Body) -contains 'numWRetries')
    'reecritures tirees de la base du controle' = ($wcaText.Contains('$wbase = @($rep.Base)') -and $wcaVars -notcontains 'chkWNoVerify' -and $wcaVars -notcontains 'numWRetries')
}
$s1Bad = @($s1.Keys | Where-Object { -not $s1[$_] })
Chk 'S1' ($s1Bad.Count -eq 0) "une seule decision de la verification de gw : Get-WriteVerifyPlan, case « Sans verification » et champ « Essais » seuls (le controle n y entre plus) ; Start-ImageWrite, Get-WritePlan et Update-WVerifyUi la lisent, Start-ImageWrite ne lit plus la case ni le champ ; dans 140, 145, 160 et 170, seules Get-WriteVerifyPlan et Get-WriteVerifyText citent --no-verify ou --retries ($($optFns -join ', ')) ; les reecritures des pistes faibles reprennent la base du controle ; ecarts : $(Get-List $s1Bad)"

# S2 : mesures de la disquette, calibrations et controle de surface (modules 2xx) : rien ne lit la case, le champ ni la
# decision ; --no-verify en dur dans la calibration (270) et la mesure sur l image (276), comme avant le lot
$s2Bad = @(); $nv = @{}
$m2 = @(Get-ChildItem -LiteralPath $mods -Filter '2*-fn-*.ps1' -File | Sort-Object Name)
foreach ($f in $m2) {
    $a = Get-Ast $f.FullName
    foreach ($v in (Get-VfVars $a)) { if (@('chkWNoVerify', 'numWRetries') -contains $v) { $s2Bad += "$($f.Name) lit `$$v" } }
    if (@($a.FindAll({ param($x) $x -is $tCmdA }, $true) | Where-Object { [string]$_.GetCommandName() -like 'Get-WriteVerify*' }).Count) { $s2Bad += "$($f.Name) appelle la decision" }
    $st = Get-VfStrings $a
    if (@($st | Where-Object { $_ -match '--retries' }).Count) { $s2Bad += "$($f.Name) pose --retries" }
    $nv[$f.Name.Substring(0, 3)] = @($st | Where-Object { $_ -ceq '--no-verify' }).Count
}
$s2Same = 'saute (sans -Before)'
if ($Before) {
    # Lignes visees seulement (options de la verification de gw, case, champ, decision) : les lots suivants changent les
    # modules 2xx pour d autres raisons, et la comparaison a l octet ne valait qu au commit du lot
    $bm = Join-Path (Get-TestRoot $Before) 'src\modules'; $dif = @()
    $pick = { param($p) if (Test-Path -LiteralPath $p) { (@([System.IO.File]::ReadAllLines($p, [System.Text.Encoding]::UTF8) | Where-Object { $_ -match '--no-verify|--retries|chkWNoVerify|numWRetries|Get-WriteVerify' }) -join "`n") } else { $null } }
    foreach ($f in $m2) { if ((& $pick (Join-Path $bm $f.Name)) -cne (& $pick $f.FullName)) { $dif += $f.Name } }
    $s2Same = "$($m2.Count - $dif.Count) sur $($m2.Count) aux lignes --no-verify et --retries identiques a celles de la source d avant"
    if ($dif.Count) { $s2Bad += "modules 2xx aux lignes --no-verify ou --retries changees : $($dif -join ', ')" }
}
Chk 'S2' ($s2Bad.Count -eq 0 -and $m2.Count -ge 10 -and [int]$nv['270'] -ge 1 -and [int]$nv['276'] -ge 1) "mesures de la disquette, calibrations et controle de surface ($($m2.Count) modules 2xx) : aucun ne lit la case « Sans verification », le champ « Essais » ni la decision, aucun ne pose --retries ; --no-verify en dur dans la calibration (270 : $($nv['270'])) et la mesure sur l image (276 : $($nv['276'])), comme avant ; modules : $s2Same ; ecarts : $(Get-List $s2Bad)"

# S3 : reglages que Start-RestoreWrite pose avant son ecriture (rejoues par le cas V6)
$srw = if ($fnAst.ContainsKey('Start-RestoreWrite')) { [string]$fnAst['Start-RestoreWrite'].Extent.Text } else { '' }
$s3 = @($srw.Contains("Set-WritePreset 'slow' `$r.Orig"), $srw.Contains('Set-Num $numWRetries $script:RestoreRules.WriteRetries'), $srw.Contains('Set-Num $numWRepair $script:RestoreRules.RepairPasses'),
        $srw.Contains('$chkWNoVerify.Checked = $false; $chkWPostCheck.Checked = $true; $chkWPrecomp.Checked = $true'), $srw.Contains("Start-PresetWrite 'slow' -NoCalib:"))
Chk 'S3' (@($s3 | Where-Object { -not $_ }).Count -eq 0) "Start-RestoreWrite : prereglage de l ecriture lente, essais et passes de la restauration, verification gw non decochee par elle-meme, controle demande, puis Start-PresetWrite 'slow' -NoCalib ($($s3 -join ' ')) : reglages rejoues par V6"

# =====================================================================================================================
# Construction de l onglet : fichiers de travail par source (fonctions de tous les modules fn, etat, instructions de 500,
# 510, 520, 540 et partie Ecriture de Set-Defaults), comme logic-ecriture-plan
$vfCtl = @('txtWFile', 'btnWFile', 'cmbWFmt', 'chkWPreErase', 'chkWSlow', 'chkWPostCheck', 'chkWUnattended', 'chkWLevel', 'cmbWLevelMode', 'cmbWTarget', 'cmbWCalMode', 'btnWCalib', 'btnWCross', 'btnWCurve', 'btnWrite',
           'chkWEraseEmpty', 'chkWNoVerify', 'numWRetries', 'numWRepair', 'cmbWProfile', 'chkWPrecomp', 'txtWPrecomp', 'txtWPrecomp1', 'txtWTracks', 'cmbWDensel', 'txtWFakeIdx', 'chkWReverse', 'txtWDiskdefs', 'btnWDiskdefs',
           'chkWHard', 'chkWTG43', 'chkWWarm', 'chkWCalWarm', 'numWWarmMin', 'btnWCalReset', 'btnWCalBack')
function New-VfGen([string]$root, [string]$tag) {
    $g = @{ Root = $root; Tag = $tag }
    $fns = New-Object System.Collections.Generic.List[string]
    foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'src\modules') -Filter '*.ps1' -File | Where-Object { $_.Name -match '^[1-4]\d\d-fn-' } | Sort-Object Name)) {
        foreach ($fd in (Get-Ast $f.FullName).FindAll({ param($x) $x -is $tFnA }, $false)) { $fns.Add($fd.Extent.Text) }
    }
    $g.Fn = Join-Path $here "gen-$tag-fonctions.ps1"; Write-VfGen $g.Fn $fns
    $st = New-Object System.Collections.Generic.List[string]
    foreach ($px in @('000', '020', '040', '550', '560', '565', '570', '580', '590')) {
        foreach ($s in (Get-Ast (Get-VfMod $root $px)).EndBlock.Statements) {
            $t = $s.Extent.Text
            if ($t -match 'Add-Type|EnableVisualStyles') { continue }
            if ($px -eq '020' -and -not ($s -is $tAsgA -and $t.StartsWith('$script:') -and -not $t.StartsWith('$script:AppDir'))) { continue }
            $st.Add($t)
        }
    }
    $g.State = Join-Path $here "gen-$tag-etat.ps1"; Write-VfGen $g.State $st
    $g.U500 = Join-Path $here "gen-$tag-500.ps1"
    Write-VfGen $g.U500 @((Get-Ast (Get-VfMod $root '500')).EndBlock.Statements | Where-Object { $_.Extent.Text -notmatch 'Add-Type' } | ForEach-Object { $_.Extent.Text })
    $ban = @(); $on = $false
    foreach ($s in (Get-Ast (Get-VfMod $root '510')).EndBlock.Statements) {
        $t = $s.Extent.Text
        if ($t.StartsWith('$pnlTop = ')) { $on = $true }
        if ($on) { $ban += $t }
        if ($t.StartsWith('$script:DriveBanner = ')) { $on = $false }
    }
    $g.U510 = Join-Path $here "gen-$tag-510.ps1"; Write-VfGen $g.U510 $ban
    $g.U520 = Join-Path $here "gen-$tag-520.ps1"; Write-VfGen $g.U520 @((Get-Ast (Get-VfMod $root '520')).EndBlock.Statements | ForEach-Object { $_.Extent.Text })
    $g.U540 = Join-Path $here "gen-$tag-540.ps1"
    Write-VfGen $g.U540 @((Get-Ast (Get-VfMod $root '540')).EndBlock.Statements | Where-Object { $_.Extent.Text -match '^(Set-Btn\s+|Set-Cue\s+|\$tip\.SetToolTip\()\$(\w+)\b' -and $vfCtl -contains $Matches[2] } | ForEach-Object { $_.Extent.Text })
    $sd = @((Get-Ast (Get-VfMod $root '120')).FindAll({ param($x) $x -is $tFnA -and $x.Name -eq 'Set-Defaults' }, $false))
    $ds = @($sd[0].Body.EndBlock.Statements | Where-Object { $_.Extent.Text -match '\$(txtW|cmbW|chkW|numW|lblW)' -or $_.Extent.Text -match '^(Reset-Settings|Update-SlowUi|Update-TargetDriveUi)$' } | ForEach-Object { $_.Extent.Text })
    $g.Def = Join-Path $here "gen-$tag-defauts.ps1"
    Write-VfGen $g.Def @("function Invoke-VfDefaults {`r`n" + ($ds -join "`r`n") + "`r`n}")
    return $g
}
function Set-VfStubs {
    # Bouchons : gw, fenetres, journal, prechauffage, controle, mesures, profil de l image et autres onglets ; commandes,
    # demandes et fenetres relevees dans $script:VfTrace, le journal dans $script:VfLog, les commandes gw (tableaux
    # d arguments) dans $script:VfCmds, la base donnee au controle dans $script:VfBase
    function script:Start-Gw([string[]]$gwArgs, [switch]$Soft) { [void]$script:VfTrace.Add('gw ' + ($gwArgs -join ' ')); $script:VfCmds.Add([string[]]$gwArgs) }
    function script:Invoke-NextChainStep {
        foreach ($q in @($script:WriteQueue.ToArray())) { [void]$script:VfTrace.Add('file ' + (@($q) -join ' ')); $script:VfCmds.Add([string[]]@($q)) }
        if ($script:WriteArgs) { [void]$script:VfTrace.Add('ecriture ' + (@($script:WriteArgs) -join ' ')); $script:VfCmds.Add([string[]]@($script:WriteArgs)) }
        [void]$script:VfTrace.Add('etapes ' + $script:Chain.Count)
    }
    function script:Start-WriteWarmup([string]$tspec, [bool]$noWarm) {
        foreach ($q in @($script:WriteQueue.ToArray())) { [void]$script:VfTrace.Add('file ' + (@($q) -join ' ')); $script:VfCmds.Add([string[]]@($q)) }
        [void]$script:VfTrace.Add("prechauffage $tspec $noWarm ; etapes $($script:Chain.Count)")
    }
    function script:New-WriteCheck([string[]]$base, [string]$image, [string]$userTSpec, [int]$max, [string[]]$readOpts, $headPrecomp, [string]$eraseMode = '') {
        $hp = if ($headPrecomp) { "$($headPrecomp[0])/$($headPrecomp[1])" } else { '-' }
        [void]$script:VfTrace.Add("controle base $($base -join ' ') ; pistes $userTSpec ; passes $max ; relecture $($readOpts -join ' ') ; precomp $hp ; effacement $eraseMode")
        $script:VfBase = @($base); $script:VfHeadPc = $headPrecomp
        $script:Rep = @{}
    }
    function script:Start-LevelCalib($lr, [switch]$NoConfirm, [switch]$NoFallback, $Geom = $null) { [void]$script:VfTrace.Add('calibration rapide'); $script:Cal = @{ Mode = 'level' } }
    function script:Start-DiskMeasure($lr, $brand) { [void]$script:VfTrace.Add('mesure complete') }
    function script:Start-ContentMeasure($chk) { [void]$script:VfTrace.Add('mesure sur l image') }
    function script:Start-PrecompCalib { [void]$script:VfTrace.Add('calibration complete') }
    function script:Show-AppMessage([string]$text, [string]$title, [string]$buttons = 'OK', [string]$icon = 'Information') { [void]$script:VfTrace.Add("message $title $buttons"); [void]$script:VfLog.Add($text); if ($buttons -eq 'YesNo') { return 'No' }; return 'OK' }
    function script:Show-AppConfirm([string]$Title, [string]$Heading, [string]$Text, [string]$Check = '', [string]$GoText = '', [string]$GoGlyph = '', [string]$Level = 'warn', [string]$Picto = 'warn', [string]$AltText = '', $Combo = $null) { [void]$script:VfTrace.Add("confirmation $Title"); [void]$script:VfLog.Add($Text); return $true }
    function script:Show-Tab($t) { [void]$script:VfTrace.Add('onglet') }
    function script:Append-Log($t) { [void]$script:VfLog.Add([string]$t) }
    function script:Update-PrecompForImage($p) { [void]$script:VfTrace.Add('profil recalcule') }
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
$vfImg = Join-Path $here 'img'
if (-not (Test-Path -LiteralPath $vfImg)) { [void](New-Item -ItemType Directory -Path $vfImg -Force) }
function New-VfFile([string]$name, [byte[]]$bytes) { $p = Join-Path $vfImg $name; [System.IO.File]::WriteAllBytes($p, $bytes); return $p }
$imAdf = New-VfFile 'jeu.adf' (New-Object byte[] 901120)
$imHd = New-VfFile 'hd.adf' (New-Object byte[] 1802240)
# Image flux factice (KryoFlux .raw) : sans format, gw l ecrit telle quelle et ne la verifie jamais (cas T16 a T18)
$imRaw = New-VfFile 'flux.raw' (New-Object byte[] 4096)
$vfNorm = { param($x) ([string]$x).Replace($vfImg, '<img>') }

# --- Courbes factices (magasin par lecteur ; vue du lecteur courant par la vraie Sync-PrecompCurves)
function New-VfCurve([string]$drive, [string]$date = '01/11/2026 10:00') {
    $v = [int[]]@(for ($c = 0; $c -lt 80; $c++) { 120 + [int][math]::Floor($c / 2) })
    $cy = [int[]]@(for ($c = 0; $c -lt 80; $c += 4) { $c })
    return @{ Values = $v; Cyls = $cy; Kinds = [string[]]@($cy | ForEach-Object { 'interp' }); Res = [double[]]@($cy | ForEach-Object { 0.5 }); Ys = [double[]]@($cy | ForEach-Object { [double]$v[$_] })
              Sig = [double[]]@($cy | ForEach-Object { 1.0 }); Breaks = @(); Date = $date; Test = 'fine'; Drive = $drive; Method = 'motif'; Bits = 101344; Slope = -1.0; Converged = $true; MaxNs = 400
              Spec = "0=120:79=$($v[79])"; Calc = '12.10' }
}
function Set-VfCurves([string]$set) {
    if ($set -eq 'motif') { $script:DriveCurves['A|std'] = New-VfCurve 'A'; foreach ($h in 0, 1) { $script:DriveCurves["A|std_h$h"] = New-VfCurve 'A' '01/11/2026 11:00' } }
    elseif ($set -eq 'croisee') { $script:DriveCurves['A>0|std'] = New-VfCurve 'A>0' }
    Sync-PrecompCurves
}
function Reset-VfState {
    $script:Restore = $null; $script:GwProc = $null; $script:Cal = $null; $script:AfterCalib = ''; $script:LevelPostForce = $false; $script:WriteFactorNext = $null
    $script:ScpStatsOk = $true; $script:ScpWeakCache = $null; $script:OpOverride = $null; $script:PresetSource = ''
    $script:DriveReg = [ordered]@{}; $script:TargetDrives = @{}; $script:DriveCurves = @{}; $script:LevelShifts = @{}
    $cmbDrive.SelectedItem = 'A'
    Invoke-VfDefaults
    Sync-PrecompCurves
}

# Cas : image, format (vide : « (auto) »), chemin (tab : bouton ECRIRE, vraie Start-WriteTabWrite ; image : vraie
# Start-ImageWrite seule ; fast, slow : Bibliotheque, vraie Start-PresetWrite ; restore : vraie Start-PresetWrite 'slow'
# -NoCalib), reglages poses sur les controles comme le ferait l utilisateur ou le code, puis ce qui est attendu : By
# (le controle s applique : il remplace la verification de gw), W (commandes gw write et base du controle, mot pour mot)
$p0 = '0=100:40=130'; $p1 = '0=110:40=140'; $px = '0=120:79=159'
$vfFields = { $txtWPrecomp.Text = $p0; $txtWPrecomp1.Text = $p1 }
$cFast = "--precomp $p0 --format=amiga.amigados"
$adf = '"<img>\jeu.adf"'; $hdf = '"<img>\hd.adf"'
$ctlTail = { param([int]$n, [string]$hp) " ; pistes  ; passes $n ; relecture  ; precomp $hp ; effacement hfreq" }
$vfCases = @(
    @{ Id = 'T01'; G = 'V1'; T = 'onglet, rapide, controle coche'; Img = $imAdf; Fmt = 'amiga.amigados'; Fn = 'tab'; By = $true; Do = { & $vfFields }
       W = @("controle base write --drive=A --erase-empty --no-verify $cFast$(& $ctlTail 3 '-')", "ecriture write --drive=A --erase-empty --no-verify $cFast $adf") }
    @{ Id = 'T02'; G = 'V1'; T = 'onglet, rapide, controle decoche'; Img = $imAdf; Fmt = 'amiga.amigados'; Fn = 'tab'; By = $false; Do = { & $vfFields; $chkWPostCheck.Checked = $false }
       W = @("ecriture write --drive=A --erase-empty --retries=10 $cFast $adf") }
    @{ Id = 'T03'; G = 'V1'; T = 'onglet, rapide, controle decoche, « Sans verification » cochee, 4 essais'; Img = $imAdf; Fmt = 'amiga.amigados'; Fn = 'tab'; By = $false; Do = { & $vfFields; $chkWPostCheck.Checked = $false; $chkWNoVerify.Checked = $true; $numWRetries.Value = 4 }
       W = @("ecriture write --drive=A --erase-empty --no-verify --retries=4 $cFast $adf") }
    @{ Id = 'T04'; G = 'V1'; T = 'onglet, rapide, controle coche, « Sans verification » cochee, 4 essais'; Img = $imAdf; Fmt = 'amiga.amigados'; Fn = 'tab'; By = $true; Do = { & $vfFields; $chkWNoVerify.Checked = $true; $numWRetries.Value = 4 }
       W = @("controle base write --drive=A --erase-empty --no-verify $cFast$(& $ctlTail 3 '-')", "ecriture write --drive=A --erase-empty --no-verify $cFast $adf") }
    @{ Id = 'T05'; G = 'V2'; T = 'onglet, lente, controle coche'; Img = $imAdf; Fmt = 'amiga.amigados'; Fn = 'tab'; By = $true; Do = { & $vfFields; $chkWSlow.Checked = $true; $chkWLevel.Checked = $false; & $vfFields }
       W = @("controle base write --drive=A --erase-empty --no-verify --format=amiga.amigados$(& $ctlTail 3 "$p0/$p1")", "file write --drive=A --erase-empty --no-verify --format=amiga.amigados --precomp $p0 --tracks=h=0 $adf", "file write --drive=A --erase-empty --no-verify --format=amiga.amigados --precomp $p1 --tracks=h=1 $adf") }
    @{ Id = 'T06'; G = 'V2'; T = 'onglet, lente, controle decoche'; Img = $imAdf; Fmt = 'amiga.amigados'; Fn = 'tab'; By = $false; Do = { & $vfFields; $chkWSlow.Checked = $true; $chkWLevel.Checked = $false; $chkWPostCheck.Checked = $false; & $vfFields }
       W = @("file write --drive=A --erase-empty --retries=10 --format=amiga.amigados --precomp $p0 --tracks=h=0 $adf", "file write --drive=A --erase-empty --retries=10 --format=amiga.amigados --precomp $p1 --tracks=h=1 $adf") }
    @{ Id = 'T07'; G = 'V3'; T = 'controle coche, non applicable (haute densite)'; Img = $imHd; Fmt = 'amiga.amigados_hd'; Fn = 'image'; By = $false; Do = { & $vfFields }
       W = @("gw write --drive=A --pre-erase --erase-empty --retries=10 --precomp $p0 --format=amiga.amigados_hd $hdf") }
    @{ Id = 'T08'; G = 'V3'; T = 'controle decoche, impose par la courbe adaptee'; Img = $imAdf; Fmt = 'amiga.amigados'; Fn = 'image'; By = $true; Do = { $chkWPostCheck.Checked = $false; $txtWPrecomp.Text = '0=111:40=131'; $script:LevelShifts['std|c'] = @{ Model = 'M1'; Spec = '0=111:40=131'; Values = @(111) } }
       W = @("controle base write --drive=A --erase-empty --no-verify --precomp 0=111:40=131 --format=amiga.amigados$(& $ctlTail 3 '-')", "ecriture write --drive=A --erase-empty --no-verify --precomp 0=111:40=131 --format=amiga.amigados $adf") }
    @{ Id = 'T15'; G = 'V3'; T = 'controle coche, module d analyse SCP indisponible (controle ignore apres l ecriture)'; Img = $imAdf; Fmt = 'amiga.amigados'; Fn = 'image'; By = $false; Do = { & $vfFields; $script:ScpStatsOk = $false }
       W = @("controle base write --drive=A --erase-empty --retries=10 $cFast$(& $ctlTail 3 '-')", "ecriture write --drive=A --erase-empty --retries=10 $cFast $adf") }
    # Image flux ecrite telle quelle (sans format) : gw ne verifie pas un flux brut ; la commande reste celle de la 12.10
    # (--retries transmis, sans effet), seul le segment de la ligne le dit (Seg). « Sans verification » cochee : segment
    # ordinaire. Controle coche : il s applique (aucune raison ne l empeche), segment ordinaire
    @{ Id = 'T16'; G = 'V8'; T = 'image flux ecrite telle quelle, controle decoche : gw ne la verifie pas'; Img = $imRaw; Fmt = ''; Fn = 'image'; By = $false; Seg = 'raw'; Do = { $chkWPostCheck.Checked = $false }
       W = @('gw write --drive=A --pre-erase --erase-empty --retries=10 "<img>\flux.raw"') }
    @{ Id = 'T17'; G = 'V8'; T = 'image flux ecrite telle quelle, controle decoche, « Sans verification » cochee'; Img = $imRaw; Fmt = ''; Fn = 'image'; By = $false; Do = { $chkWPostCheck.Checked = $false; $chkWNoVerify.Checked = $true }
       W = @('gw write --drive=A --pre-erase --erase-empty --no-verify --retries=10 "<img>\flux.raw"') }
    @{ Id = 'T18'; G = 'V8'; T = 'image flux ecrite telle quelle, controle coche : gw ne la verifie pas'; Img = $imRaw; Fmt = ''; Fn = 'image'; By = $true; Seg = 'raw'; Do = { }
       W = @("controle base write --drive=A --pre-erase --erase-empty --no-verify ; pistes  ; passes 3 ; relecture  ; precomp - ; effacement hfreq", 'ecriture write --drive=A --pre-erase --erase-empty --no-verify "<img>\flux.raw"') }
    @{ Id = 'T09'; G = 'V4'; T = 'lecteur cible, lente, controle coche'; Img = $imAdf; Fmt = 'amiga.amigados'; Fn = 'image'; By = $true; Do = { Set-VfCurves 'croisee'; $script:TargetDrives['A'] = '0'; $chkWSlow.Checked = $true; $txtWPrecomp.Text = $px; $txtWPrecomp1.Text = $px }
       W = @("controle base write --drive=A --erase-empty --no-verify --format=amiga.amigados$(& $ctlTail 3 "$px/$px")", "file write --drive=A --erase-empty --no-verify --format=amiga.amigados --precomp $px --tracks=h=0 $adf", "file write --drive=A --erase-empty --no-verify --format=amiga.amigados --precomp $px --tracks=h=1 $adf") }
    @{ Id = 'T10'; G = 'V4'; T = 'lecteur cible, lente, controle decoche'; Img = $imAdf; Fmt = 'amiga.amigados'; Fn = 'image'; By = $false; Do = { Set-VfCurves 'croisee'; $script:TargetDrives['A'] = '0'; $chkWSlow.Checked = $true; $chkWPostCheck.Checked = $false; $txtWPrecomp.Text = $px; $txtWPrecomp1.Text = $px }
       W = @("file write --drive=A --erase-empty --retries=10 --format=amiga.amigados --precomp $px --tracks=h=0 $adf", "file write --drive=A --erase-empty --retries=10 --format=amiga.amigados --precomp $px --tracks=h=1 $adf") }
    @{ Id = 'T11'; G = 'V5'; T = 'Bibliotheque, ecriture lente (controle du prereglage)'; Img = $imAdf; Fmt = 'amiga.amigados'; Fn = 'slow'; By = $true; Do = { Set-VfCurves 'motif'; Set-WritePreset 'slow' $imAdf $imAdf; $chkWLevel.Checked = $false; & $vfFields }
       W = @("controle base write --drive=A --erase-empty --no-verify --format=amiga.amigados$(& $ctlTail 3 "$p0/$p1")", "file write --drive=A --erase-empty --no-verify --format=amiga.amigados --precomp $p0 --tracks=h=0 $adf", "file write --drive=A --erase-empty --no-verify --format=amiga.amigados --precomp $p1 --tracks=h=1 $adf") }
    @{ Id = 'T12'; G = 'V5'; T = 'Bibliotheque, ecriture rapide (prereglage sans controle)'; Img = $imAdf; Fmt = 'amiga.amigados'; Fn = 'fast'; By = $false; Do = { Set-VfCurves 'motif'; Set-WritePreset 'fast' $imAdf $imAdf; & $vfFields }
       W = @("ecriture write --drive=A --erase-empty --retries=10 $cFast $adf") }
    @{ Id = 'T13'; G = 'V6'; T = 'restauration, copie secteur double densite'; Img = $imAdf; Fmt = 'amiga.amigados'; Fn = 'restore'; By = $true
       Do = { Set-VfCurves 'motif'; Set-WritePreset 'slow' $imAdf "restore|$imAdf"; Set-Num $numWRetries $script:RestoreRules.WriteRetries; Set-Num $numWRepair $script:RestoreRules.RepairPasses; $chkWNoVerify.Checked = $false; $chkWPostCheck.Checked = $true; $chkWPrecomp.Checked = $true; $chkWLevel.Checked = $false; & $vfFields; $script:Restore = @{ OnOriginal = $false; Saved = $null; Mode = 'sector' } }
       W = @("controle base write --drive=A --erase-empty --no-verify --format=amiga.amigados$(& $ctlTail 5 "$p0/$p1")", "file write --drive=A --erase-empty --no-verify --format=amiga.amigados --precomp $p0 --tracks=h=0 $adf", "file write --drive=A --erase-empty --no-verify --format=amiga.amigados --precomp $p1 --tracks=h=1 $adf") }
    @{ Id = 'T14'; G = 'V6'; T = 'restauration, haute densite (controle non applicable)'; Img = $imHd; Fmt = 'amiga.amigados_hd'; Fn = 'restore'; By = $false
       Do = { Set-WritePreset 'slow' $imHd "restore|$imHd"; Set-Num $numWRetries $script:RestoreRules.WriteRetries; Set-Num $numWRepair $script:RestoreRules.RepairPasses; $chkWNoVerify.Checked = $false; $chkWPostCheck.Checked = $true; $chkWPrecomp.Checked = $true; $chkWLevel.Checked = $false; & $vfFields; $script:Restore = @{ OnOriginal = $false; Saved = $null; Mode = 'sector' } }
       W = @("file write --drive=A --pre-erase --erase-empty --retries=20 --format=amiga.amigados_hd --precomp $p0 --tracks=h=0 $hdf", "file write --drive=A --pre-erase --erase-empty --retries=20 --format=amiga.amigados_hd --precomp $p1 --tracks=h=1 $hdf") }
)
$logR9 = 'Écriture sans vérification de gw (--no-verify, sans --retries)'
$logPreset = 'Écriture lente : image entière, profil Auto'
function ConvertTo-VfRc3($cmds, $set) {
    # Attendus ecrits pour R9 (--no-verify sans --retries quand le controle s appliquait) : commandes de la rc3, options de
    # la case « Sans verification » et du champ « Essais » du cas, a la meme place
    $o = if ($set.NoVer) { " --no-verify --retries=$($set.Ret)" } else { " --retries=$($set.Ret)" }
    return @(@($cmds) | ForEach-Object { if ([string]$_ -match ' --retries=\d+') { [string]$_ } else { ([string]$_).Replace(' --no-verify', $o) } })
}
function Invoke-VfCase($sc, [bool]$new) {
    # Un cas : etat remis, image et format, reglages ; source testee : mise a jour de l onglet (ligne, case, champ) et plan
    # de la phrase ; puis la vraie fonction du chemin. Rend commandes et demandes, journal, plan, etat de la case
    Reset-VfState
    $script:VfTrace.Clear(); $script:VfLog.Clear(); $script:VfCmds.Clear(); $script:VfBase = $null; $script:VfHeadPc = $null
    $txtWFile.Text = $sc.Img
    if ($sc.Fmt) { $cmbWFmt.SelectedItem = $sc.Fmt } else { $cmbWFmt.SelectedIndex = 0 }
    & $sc.Do
    $o = @{ Plan = $null; Ui = $null; Side = 0; Set = @{ NoVer = [bool]$chkWNoVerify.Checked; Ret = [int]$numWRetries.Value; Rep = [int]$numWRepair.Value } }
    $script:VfTrace.Clear()
    if ($new) {
        $n0 = $script:VfTrace.Count + $script:VfLog.Count
        if (Get-Command 'Update-WLevelUi' -ErrorAction SilentlyContinue) { Update-WLevelUi }
        $o.Plan = Get-WritePlan
        $o.Side = $script:VfTrace.Count + $script:VfLog.Count - $n0
        $o.Ui = @{ Chk = [bool]$chkWNoVerify.Enabled; Num = [bool]$numWRetries.Enabled; Lbl = [bool]$lblWRetries.Enabled; Tip = [string]$tip.GetToolTip($chkWNoVerify); TipN = [string]$tip.GetToolTip($numWRetries); Line = [string]$script:WPlanFull }
    }
    $script:WriteQueue.Clear(); $script:Chain.Clear(); $script:WriteArgs = $null; $script:Rep = $null
    try {
        if ($sc.Fn -eq 'tab') { Start-WriteTabWrite } elseif ($sc.Fn -eq 'image') { Start-ImageWrite } elseif ($sc.Fn -eq 'fast') { Start-PresetWrite 'fast' }
        elseif ($sc.Fn -eq 'slow') { Start-PresetWrite 'slow' } else { Start-PresetWrite 'slow' -NoCalib }
    } catch { [void]$script:VfTrace.Add("ERREUR $($_.Exception.Message)") }
    $o.Trace = @($script:VfTrace | ForEach-Object { & $vfNorm $_ })
    $o.Log = @($script:VfLog | ForEach-Object { & $vfNorm $_ })
    $o.Cmds = @($script:VfCmds.ToArray()); $o.Base = $script:VfBase; $o.HeadPc = $script:VfHeadPc
    $o.Kept = ([bool]$chkWNoVerify.Checked -eq $o.Set.NoVer -and [int]$numWRetries.Value -eq $o.Set.Ret)
    $script:Restore = $null
    return $o
}
function Get-VfWrites($r) { return ,@(@($r.Trace) | Where-Object { $_ -match '^(controle base write|file write|ecriture write|gw write) ' }) }

$script:VfTrace = New-Object System.Collections.Generic.List[string]
$script:VfLog = New-Object System.Collections.Generic.List[string]
$script:VfCmds = New-Object System.Collections.Generic.List[object]
$stOp = New-Object System.Windows.Forms.ToolStripStatusLabel; $status = New-Object System.Windows.Forms.StatusStrip
$vfRoots = @()
if ($Before) { $vfRoots += @{ Root = (Get-TestRoot $Before); Tag = 'avant'; New = $false } }
$vfRoots += @{ Root = $Wt; Tag = 'vf'; New = $true }
$res = @{}
foreach ($pr in $vfRoots) {
    "--- construction de l onglet : $(if ($pr.New) { 'source testee' } else { "source d avant le lot ($($pr.Root))" })"
    $g = New-VfGen $pr.Root $pr.Tag
    $script:AppDir = $here
    . $g.State
    . $g.Fn
    Set-VfStubs
    $script:Lang = 'fr'
    $script:UiReady = $false; $script:ScpStatsOk = $true
    . $g.U500
    . $g.U510
    . $g.U520
    . $g.U540
    . $g.Def
    $tabW.Font = $form.Font
    Fit-ControlText $tabW
    Set-WriteTabLayout
    Invoke-VfDefaults
    $script:UiReady = $true
    $tabW.Size = New-Object System.Drawing.Size(792, 516)
    $res[$pr.Tag] = @{}
    foreach ($sc in $vfCases) { $res[$pr.Tag][$sc.Id] = Invoke-VfCase $sc $pr.New }
}
$cur = $res['vf']
$hasUi = [bool](Get-Command 'Update-WVerifyUi' -ErrorAction SilentlyContinue)

# =====================================================================================================================
'--- V : commandes gw write, avec et sans controle, par chemin'
# Releve complet dans le dossier de travail, pour un ecart a examiner
$dump = New-Object System.Collections.Generic.List[string]
foreach ($sc in $vfCases) { $r = $cur[$sc.Id]; $dump.Add("=== $($sc.Id) $($sc.T)"); foreach ($x in $r.Trace) { $dump.Add("  T $x") }; foreach ($x in $r.Log) { $dump.Add("  J $x") }; if ($r.Plan) { $dump.Add("  P $($r.Ui.Line)") } }
[System.IO.File]::WriteAllLines((Join-Path $here 'releve.txt'), [string[]]$dump.ToArray(), $utf8b)
$vTitle = [ordered]@{
    V1 = 'onglet « Ecriture », ecriture rapide (bouton ECRIRE, vraie Start-WriteTabWrite) : controle coche ou non, --retries=10, et --no-verify --retries=4 avec « Sans verification » cochee'
    V2 = 'onglet « Ecriture », ecriture lente : une commande par tete, controle coche ou non : --retries=10'
    V3 = 'controle non applicable (haute densite), impose par la courbe adaptee, module d analyse SCP indisponible : verification de gw selon la case et le champ, --retries=10'
    V4 = 'ecriture pour un lecteur cible (courbe croisee, ecriture lente) : controle coche ou non, --retries=10'
    V5 = 'Bibliotheque (vraies Set-WritePreset et Start-PresetWrite) : ecritures lente (controle du prereglage) et rapide, --retries=10'
    V6 = 'restauration (reglages de Start-RestoreWrite, vraie Start-PresetWrite -NoCalib) : copie secteur double densite (5 passes du controle) et haute densite, --retries=20'
    V8 = 'image flux ecrite telle quelle (.raw, sans format) : commande de la 12.10 (--retries=10, que gw ignore pour un flux brut ; --no-verify --retries=10 avec « Sans verification »), controle coche ou non'
}
foreach ($gk in @($vTitle.Keys)) {
    $bad = @(); $n = 0
    foreach ($sc in @($vfCases | Where-Object { $_.G -eq $gk })) {
        $n++
        $r = $cur[$sc.Id]; $w = Get-VfWrites $r
        "  $($sc.Id) $($sc.T)"
        foreach ($x in $w) { "      $x" }
        if (@($r.Trace | Where-Object { $_ -like 'ERREUR*' }).Count) { $bad += "$($sc.Id) : $(@($r.Trace | Where-Object { $_ -like 'ERREUR*' })[0])" }
        $wx = @(ConvertTo-VfRc3 $sc.W $r.Set)
        if (($w -join "`n") -cne ($wx -join "`n")) { $bad += "$($sc.Id) : « $(Get-List $w 3) » au lieu de « $(Get-List $wx 3) »" }
        if (@($w | Where-Object { $_ -notmatch ' --retries=\d+ ' }).Count) { $bad += "$($sc.Id) : verification de gw gardee, commande sans --retries" }
    }
    Chk $gk ($bad.Count -eq 0 -and $n -ge 2) "$($vTitle[$gk]) ; $n cas, commandes mot pour mot ; ecarts : $(Get-List $bad 2)"
}

# V7 : reecritures des pistes faibles : vraie Invoke-WriteCheckAnalysis (170) sur la base que Start-ImageWrite a donnee au
# controle (T01, ecriture rapide ; T05, ecriture lente, --precomp par tete) ; relecture factice de quatre pistes dont deux
# faibles (0.1 et 1.0), effacement haute frequence de la double densite
function script:Read-ScpFile([string]$path, [switch]$NoIndexZone) { return $script:VfScp[$path] }
function script:Get-TrackMetrics($st) {
    $m = @{ Bad = $false; Missing = $false; J = 0.0; R3 = 0.0; R4 = 0.0; Ooc = 0.0; Dr = 0.0; Cell = 0.0; Stab = 0.0; Asym = 0.0; Score = 10; Level = 0; Weak = $false; Unjudged = $false; CopyDefect = $false
            ZoneOoc = 0; StructOoc = 0; StructOver = 0; ZoneFarNs = 0; StabFallback = $false }
    if (@($st).Count -eq 0) { $m.Bad = $true; $m.Level = 2; return $m }
    if ([string]$st -eq 'faible') { $m.Level = 1; $m.Ooc = 1.0 }
    return $m
}
function script:Start-RepPending { [void]$script:VfTrace.Add('passe du controle lancee') }
function script:Complete-WriteCheck([switch]$GwError) { [void]$script:VfTrace.Add('controle termine') }
function script:Stop-WriteCheck([switch]$GwError) { [void]$script:VfTrace.Add('controle arrete') }
$script:TempDir = Join-Path $here 'temp'
function Invoke-VfRewrite($base, $headPc) {
    $scp0 = Join-Path $here 'controle-0.scp'
    [System.IO.File]::WriteAllBytes($scp0, [byte[]]@())
    $script:VfScp = @{}; $script:VfScp[$scp0] = @{ 0 = 'saine'; 1 = 'faible'; 2 = 'faible'; 3 = 'saine' }
    $scope = @{}; foreach ($k in '0.0', '0.1', '1.0', '1.1') { $scope[$k] = $true }
    $script:Rep = @{ Base = @($base); Image = $imAdf; UserTSpec = ''; Max = 3; EraseMode = 'hfreq'; Common = @(Get-CommonArgs); ReadOpts = @(); HeadPrecomp = $headPc; Written = @{}
                     Round = 0; Scope = $scope; Weak = @(); State = @{}; Retries = @{}; Rewrites = @{}; Pending = (New-Object System.Collections.Queue); Scps = @($scp0); Safety = $false; Measured = 0
                     UnstDefect = $true; NoJudge = $null; SrcWeak = $null; SrcOver = $null; Ignore = $null }
    $script:VfTrace.Clear(); $script:VfLog.Clear()
    try { Invoke-WriteCheckAnalysis } catch { [void]$script:VfTrace.Add("ERREUR $($_.Exception.Message)") }
    $p = @($script:Rep.Pending.ToArray() | ForEach-Object { & $vfNorm ((@($_) | ForEach-Object { if ("$_" -like '"*.scp"') { '"' + (Split-Path -Leaf "$_".Trim('"')) + '"' } else { "$_" } }) -join ' ') })
    $r = @{ Cmds = $p; Trace = @($script:VfTrace); Round = [int]$script:Rep.Round; Weak = @($script:Rep.Weak) }
    $script:Rep = $null
    return $r
}
$rwWant = @{
    T01 = @('erase --drive=A --hfreq --tracks=c=1:h=0', "write --drive=A --erase-empty --no-verify $cFast --tracks=c=1:h=0 $adf", 'erase --drive=A --hfreq --tracks=c=0:h=1', "write --drive=A --erase-empty --no-verify $cFast --tracks=c=0:h=1 $adf",
            'read --drive=A --revs=3 --tracks=c=1:h=0 "check-r1-0.scp"', 'read --drive=A --revs=3 --tracks=c=0:h=1 "check-r1-1.scp"')
    T05 = @('erase --drive=A --hfreq --tracks=c=1:h=0', "write --drive=A --erase-empty --no-verify --format=amiga.amigados --precomp $p0 --tracks=c=1:h=0 $adf", 'erase --drive=A --hfreq --tracks=c=0:h=1', "write --drive=A --erase-empty --no-verify --format=amiga.amigados --precomp $p1 --tracks=c=0:h=1 $adf",
            'read --drive=A --revs=3 --tracks=c=1:h=0 "check-r1-0.scp"', 'read --drive=A --revs=3 --tracks=c=0:h=1 "check-r1-1.scp"')
}
$v7Bad = @()
foreach ($id in 'T01', 'T05') {
    $b = $cur[$id].Base
    if (-not $b) { $v7Bad += "$id : aucune base donnee au controle"; continue }
    $rw = Invoke-VfRewrite $b $cur[$id].HeadPc
    "  $id reecriture des pistes faibles $($rw.Weak -join ', ') (passe $($rw.Round)) :"
    foreach ($x in $rw.Cmds) { "      $x" }
    $ww = @($rw.Cmds | Where-Object { $_ -like 'write *' })
    if (@($rw.Trace | Where-Object { $_ -like 'ERREUR*' }).Count) { $v7Bad += "$id : $(@($rw.Trace | Where-Object { $_ -like 'ERREUR*' })[0])" }
    if (($rw.Cmds -join "`n") -cne (@(ConvertTo-VfRc3 $rwWant[$id] $cur[$id].Set) -join "`n")) { $v7Bad += "$id : « $(Get-List $rw.Cmds 3) »" }
    if ($ww.Count -ne 2 -or @($ww | Where-Object { $_ -notmatch ' --retries=\d+ ' }).Count) { $v7Bad += "$id : reecriture sans --retries" }
}
Chk 'V7' ($v7Bad.Count -eq 0) "reecritures des pistes faibles (vraie Invoke-WriteCheckAnalysis, base donnee au controle par Start-ImageWrite, ecriture rapide et ecriture lente avec --precomp par tete) : effacement haute frequence, puis gw write avec les options de l ecriture (--retries=10, verification de gw gardee), puis remesure ; commandes mot pour mot ; ecarts : $(Get-List $v7Bad 2)"

# =====================================================================================================================
'--- P, J, U, E : phrase, journal, case et champ, poids estimes'
$segNo = (T 'sans vérification gw'); $segRaw = (T 'sans vérification gw (image flux écrite telle quelle)')
$pBad = @(); $jBad = @(); $uBad = @(); $kBad = @()
$tip520 = (T '--no-verify : DÉCONSEILLÉ. Supprime la relecture de contrôle de chaque piste.'); $tipN520 = (T '--retries : nombre de réécritures d''une piste dont la vérification échoue.')
foreach ($sc in $vfCases) {
    $r = $cur[$sc.Id]; $w = @((Get-VfWrites $r) | Where-Object { $_ -notlike 'controle base*' })
    $segs = @(); if ($r.Plan) { $segs = @($r.Plan.Segs | ForEach-Object { [string]$_.T }) }
    $noV = (@($w | Where-Object { $_ -match ' --no-verify ' }).Count -eq $w.Count -and $w.Count -gt 0)
    # P : segment de la verification = options des commandes du clic, juste apres le segment du controle
    $want = $segNo
    if (-not $noV) { $rm = [regex]::Match([string]$w[0], ' --retries=(\d+) '); $want = ((T 'vérification gw, {0} essai(s) au plus') -f $rm.Groups[1].Value) }
    # Image flux ecrite telle quelle, sans --no-verify : la commande porte --retries, mais gw ne verifie pas un flux brut
    # (tools/write.py de gw : seules les pistes MasterTrack sont verifiees) ; le segment attendu ne se deduit pas des
    # options de la commande, il dit le fait
    if ($sc.Seg -eq 'raw') {
        $want = $segRaw
        if (@($segs | Where-Object { $_ -like 'vérification gw*' }).Count) { $pBad += "$($sc.Id) : la ligne annonce une verification de gw pour un flux brut" }
    } elseif ($segs -ccontains $segRaw) { $pBad += "$($sc.Id) : segment du flux brut hors de son cas" }
    $ix = [array]::IndexOf([string[]]$segs, $want)
    if ($ix -lt 1) { $pBad += "$($sc.Id) : « $want » absent de « $($segs -join ' | ') »" }
    elseif (-not ($segs[$ix - 1].StartsWith((T 'contrôle de toutes les pistes, sans réécriture').Split(',')[0]) -or $segs[$ix - 1] -ceq (T 'contrôle complet non demandé'))) { $pBad += "$($sc.Id) : segment place apres « $($segs[$ix - 1]) »" }
    if ($r.Side -ne 0) { $pBad += "$($sc.Id) : le calcul de la phrase a ecrit ou ouvert ($($r.Side))" }
    if ($r.Ui -and $ix -ge 1 -and -not $r.Ui.Line.Contains($want)) { $pBad += "$($sc.Id) : ligne affichee sans « $want »" }
    # J : ligne de journal du lot si et seulement si le controle remplace la verification, avec ses passes
    $jl = @($r.Log | Where-Object { $_.StartsWith($logR9) })
    if ($jl.Count -ne 0) { $jBad += "$($sc.Id) : ligne « $logR9 » au journal" }
    # U : case, libelle et champ inactifs si et seulement si le controle remplace la verification ; infobulles accordees
    if ($r.Ui) {
        $en = $true
        if ($r.Ui.Chk -ne $en -or $r.Ui.Num -ne $en -or $r.Ui.Lbl -ne $en) { $uBad += "$($sc.Id) : case $($r.Ui.Chk), champ $($r.Ui.Num), libelle $($r.Ui.Lbl) au lieu de $en" }
        if (($r.Ui.Tip -cne $tip520 -or $r.Ui.TipN -cne $tipN520)) { $uBad += "$($sc.Id) : infobulle « $($r.Ui.Tip) » / « $($r.Ui.TipN) »" }
    } else { $uBad += "$($sc.Id) : etat de la case non releve" }
    if (-not $r.Kept) { $kBad += $sc.Id }
}
Chk 'P1' ($pBad.Count -eq 0) "ligne « Ce qui va se passer », $($vfCases.Count) cas : « $segNo » quand les commandes du clic portent --no-verify (controle applique, ou case cochee sans controle), « vérification gw, N essai(s) au plus » avec le N de --retries sinon, sauf pour une image flux ecrite telle quelle sans --no-verify (T16) : « $segRaw », jamais une verification annoncee, gw ne verifiant pas un flux brut ; segment juste apres celui du controle ; calcul sans journal ni fenetre ; ecarts : $(Get-List $pBad 2)"
Chk 'J1' ($jBad.Count -eq 0) "journal : plus de ligne « $logR9 : ... » (R9 retire), journal de la 12.10 ; ecarts : $(Get-List $jBad 2)"
Chk 'U1' ($uBad.Count -eq 0 -and $kBad.Count -eq 0) "case « Sans verification », libelle et champ « Essais » : toujours actifs, jamais grises par le controle, infobulles de 520 ; valeurs de la case et du champ jamais changees par l application (ecarts : $(Get-List $kBad)) ; ecarts : $(Get-List $uBad 2)"

# U2 : sans image, avant l affichage de la fenetre, bascule de la case « Controler toutes les pistes », anglais
$u2 = [ordered]@{}
if ($hasUi) {
    Reset-VfState; $txtWFile.Text = ''; $chkWNoVerify.Checked = $true; $numWRetries.Value = 4
    Update-WLevelUi; $a = @([bool]$chkWNoVerify.Enabled, [bool]$numWRetries.Enabled, [bool]$lblWRetries.Enabled, [string]$tip.GetToolTip($chkWNoVerify), [string]$tip.GetToolTip($numWRetries))
    $chkWPostCheck.Checked = $false; $b = @([bool]$chkWNoVerify.Enabled, [bool]$numWRetries.Enabled, [bool]$lblWRetries.Enabled)
    $chkWPostCheck.Checked = $true; $c = @([bool]$chkWNoVerify.Enabled, [bool]$numWRetries.Enabled, [bool]$lblWRetries.Enabled)
    $u2['sans image : actifs, controle coche ou non'] = ($a[0] -and $a[1] -and $a[2] -and $a[3] -ceq $tip520 -and $a[4] -ceq $tipN520 -and $b[0] -and $b[1] -and $b[2] -and $c[0] -and $c[1] -and $c[2])
    $u2['valeurs gardees'] = ([bool]$chkWNoVerify.Checked -and [int]$numWRetries.Value -eq 4)
    # Avant l affichage de la fenetre (UiReady faux), puis image jugee : actifs, controle coche
    Reset-VfState; $txtWFile.Text = $imAdf; $cmbWFmt.SelectedItem = 'amiga.amigados'; $chkWPostCheck.Checked = $true
    $script:UiReady = $false; $script:WPlanMemo = $null; $script:WPlanCur = $null; Update-WLevelUi; $d = [bool]$chkWNoVerify.Enabled
    $script:UiReady = $true; Update-WLevelUi; $e = [bool]$chkWNoVerify.Enabled
    $u2['avant l affichage et image jugee : actifs'] = ($d -and $e)
    # Anglais : infobulle de 520 et segment traduits
    $script:Lang = 'en'
    Reset-VfState; $txtWFile.Text = $imAdf; $cmbWFmt.SelectedItem = 'amiga.amigados'; Update-WLevelUi
    $enTip = [string]$tip.GetToolTip($chkWNoVerify); $enLine = [string]$script:WPlanFull
    $script:Lang = 'fr'
    $u2['anglais'] = ($enTip -ceq [string]$script:I18n['--no-verify : DÉCONSEILLÉ. Supprime la relecture de contrôle de chaque piste.'] -and $enLine.Contains('; gw verification, up to '))
    # Decision avec un controle qui s applique : case et champ seuls, ByCheck faux ; aucune ligne de journal propre
    Reset-VfState; $chkWNoVerify.Checked = $false
    $vp = Get-WriteVerifyPlan @{ Post = $true; Blocker = $null; Forced = $true }
    $u2['controle applique : verification de gw gardee'] = (-not $vp.ByCheck -and (@($vp.Args) -join ' ') -ceq "--retries=$([int]$numWRetries.Value)" -and (Get-WriteVerifyText $vp 'log') -eq '' -and (Get-WriteVerifyText @{ ByCheck = $false; NoVerify = $false; Retries = 0; Passes = 3 } 'seg') -ceq (T 'vérification gw, sans nouvel essai'))
    Reset-VfState
    # Infobulle de « Controler toutes les pistes » : texte de 520, sans la regle de R9
    $pcTip = [string]$tip.GetToolTip($chkWPostCheck)
    $u2['infobulle du controle'] = ($pcTip.StartsWith('Après une écriture réussie, relit en flux toutes les pistes écrites') -and -not $pcTip.Contains('gw écrit sans vérification'))
} else { $u2['Update-WVerifyUi presente'] = $false }
$u2Bad = @($u2.Keys | Where-Object { -not $u2[$_] })
Chk 'U2' ($u2Bad.Count -eq 0) "case et champ sans image (actifs, case « Controler toutes les pistes » cochee ou non), valeurs gardees, avant l affichage et image jugee (actifs), anglais, decision avec controle (verification gardee, aucune ligne de journal), infobulle du controle sans la regle de R9 ; avant l affichage de la fenetre : d apres la case seule, sans acces a l image, puis d apres l image (haute densite : actifs) ; anglais (infobulle, segment, journal) ; infobulle de « Controler toutes les pistes » completee ; journal a 0 passe de reecriture ; ecarts : $(Get-List $u2Bad)"

# E : poids estimes de l ecriture (Get-GwCmdUnits, Get-WriteProgUnits : barre de l onglet) : la part de la verification
# de gw n est plus comptee quand le controle la remplace
$cw1 = @($cur['T01'].Cmds | Where-Object { @($_)[0] -ceq 'write' }); $cw2 = @($cur['T02'].Cmds | Where-Object { @($_)[0] -ceq 'write' })
$e1 = $false; $eTxt = ''
if ($cw1.Count -eq 1 -and $cw2.Count -eq 1) {
    $ua = Get-GwCmdUnits ([string[]]@($cw1[0])) 160; $ub = Get-GwCmdUnits ([string[]]@($cw2[0])) 160
    $wa = Get-WriteProgUnits @($cur['T01'].Cmds) $true; $wb = Get-WriteProgUnits @($cur['T02'].Cmds) $false
    $pc = $script:ProgCost
    $pa = [double]$pc.Write; if (-not (@($cw1[0]) -contains '--no-verify')) { $pa += [double]$pc.Verify }
    $pb = [double]$pc.Write; if (-not (@($cw2[0]) -contains '--no-verify')) { $pb += [double]$pc.Verify }
    $e1 = ([math]::Abs([double]$ua.Per - $pa) -lt 1e-9 -and [math]::Abs([double]$ub.Per - $pb) -lt 1e-9 -and -not (@($cw1[0]) -contains '--no-verify') -and [double]$wa.Check -gt 0 -and [double]$wb.Check -eq 0)
    $eTxt = "par piste $($ua.Per) avec le controle, $($ub.Per) sans ; ecriture $([math]::Round($wa.Write, 1)) + controle $([math]::Round($wa.Check, 1)), contre $([math]::Round($wb.Write, 1))"
}
Chk 'E1' $e1 "poids estimes de l ecriture rapide de 160 pistes (barre de l onglet) : avec le controle, ecriture et verification de gw comptees (verification gardee) et la relecture du controle s ajoute ; sans controle, ecriture et verification ($eTxt)"

# =====================================================================================================================
if ($Before) {
    '--- B : equivalence avec la source d avant le lot, au point vise pres'
    $ra = $res['avant']; $bBad = @(); $nCmd = 0; $nLog = 0
    $bn = { param($l) if ($l -match '^(controle base write|file write|ecriture write|gw write) ') { return (($l -replace ' --no-verify', '') -replace ' --retries=\d+', '') }; return $l }
    foreach ($sc in $vfCases) {
        $a = $ra[$sc.Id]; $n = $cur[$sc.Id]
        $ta = @($a.Trace | ForEach-Object { & $bn $_ }); $tn = @($n.Trace | ForEach-Object { & $bn $_ })
        if (($a.Trace -join "`n") -cne ($n.Trace -join "`n")) { $nCmd++ }
        if (($ta -join "`n") -cne ($tn -join "`n")) { $bBad += "$($sc.Id) commandes : « $(Get-List @($ta | Where-Object { $tn -cnotcontains $_ }) 1) » / « $(Get-List @($tn | Where-Object { $ta -cnotcontains $_ }) 1) »" }
        $la = @($a.Log | Where-Object { -not $_.StartsWith($logPreset) }); $ln = @($n.Log | Where-Object { -not $_.StartsWith($logR9) -and -not $_.StartsWith($logPreset) })
        if (($a.Log -join "`n") -cne ($n.Log -join "`n")) { $nLog++ }
        if (($la -join "`n") -cne ($ln -join "`n")) { $bBad += "$($sc.Id) journal" }
        if ($sc.By -ne (($a.Trace -join "`n") -cne ($n.Trace -join "`n"))) { $bBad += "$($sc.Id) : commandes $(if ($sc.By) { 'inchangees avec le controle' } else { 'changees sans controle' })" }
    }
    Chk 'B1' ($bBad.Count -eq 0 -and $nCmd -eq @($vfCases | Where-Object { $_.By }).Count) "-Before $Before : $($vfCases.Count) cas ; commandes, demandes, fenetres et journal identiques ligne a ligne a ceux de la source d avant, aux options --no-verify et --retries des commandes gw write et aux lignes de journal du lot pres (ligne « $logR9 », ligne du prereglage de l ecriture lente) ; commandes changees dans les $nCmd cas ou le controle s applique, et dans eux seuls ; journal change dans $nLog cas ; ecarts : $(Get-List $bBad 3)"
} else { '  B1 saute (sans -Before : comparaison ligne a ligne avec la source d avant le lot)' }

# =====================================================================================================================
'--- I : textes (019, section rc4)'
# Cles de la section rc4 de 019 : affectations $script:I18n[cle] placees apres le titre de la section (arbre syntaxique :
# valeur de la cle, retours a la ligne compris)
$a019 = Get-Ast (Get-VfMod $Wt '019')
$i4 = ([string]$a019.Extent.Text).IndexOf('# --- rc4 :')
$tIdxA = [System.Management.Automation.Language.IndexExpressionAst]
$rc4Keys = @()
if ($i4 -ge 0) {
    $rc4Keys = @($a019.FindAll({ param($x) $x -is $tAsgA -and $x.Left -is $tIdxA -and $x.Left.Index -is $tStrA -and $x.Extent.StartOffset -gt $i4 }, $false) | ForEach-Object { [string]$_.Left.Index.Value })
}
$keys = New-Object System.Collections.Generic.List[string]
foreach ($fn in @('Get-WriteVerifyText')) { if ($fnAst.ContainsKey($fn)) { foreach ($c in $fnAst[$fn].Body.FindAll({ param($x) $x -is $tCmdA -and $x.GetCommandName() -eq 'T' }, $true)) { $keys.Add([string]$c.CommandElements[1].Value) } } }
# Segment du flux brut, pose par Get-WritePlan (145) d apres Test-RawFluxWrite : cle lue dans la fonction
$nRawKey = 0
if ($fnAst.ContainsKey('Get-WritePlan')) { foreach ($c in $fnAst['Get-WritePlan'].Body.FindAll({ param($x) $x -is $tCmdA -and $x.GetCommandName() -eq 'T' -and $x.CommandElements.Count -ge 2 }, $true)) { $k = [string]$c.CommandElements[1].Value; if ($k.StartsWith('sans vérification gw')) { $keys.Add($k); $nRawKey++ } } }
$allT = New-Object System.Collections.Generic.List[string]
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Where-Object { $_.Name -notmatch '^01' })) {
    foreach ($c in (Get-Ast $f.FullName).FindAll({ param($x) $x -is $tCmdA -and $x.GetCommandName() -eq 'T' -and $x.CommandElements.Count -ge 2 }, $true)) { $allT.Add([string]$c.CommandElements[1].Value) }
}
foreach ($k in @($allT | Where-Object { $_ -match 'ou, à défaut, vérification' -or $_.StartsWith("Quand ce contrôle s'applique à l'écriture, gw écrit sans vérification") } | Sort-Object -Unique)) { $keys.Add($k) }
$old520 = @('--no-verify : DÉCONSEILLÉ. Supprime la relecture de contrôle de chaque piste.', '--retries : nombre de réécritures d''une piste dont la vérification échoue.')
$iBad = @(); $nNew = 0
foreach ($k in @($keys | Sort-Object -Unique)) {
    if (-not $script:I18n.ContainsKey($k) -or [string]$script:I18n[$k] -ceq $k) { $iBad += "sans entree anglaise : « $($k.Substring(0, [math]::Min(60, $k.Length))) »"; continue }
    if ($old520 -contains $k) { continue }
    $nNew++
    if ($rc4Keys -cnotcontains $k) { $iBad += "hors de la section rc4 : « $($k.Substring(0, [math]::Min(60, $k.Length))) »" }
}
$stale = @($allT | Where-Object { $_ -match 'ou, à défaut, vérification|gw écrit sans vérification|Écriture sans vérification de gw|Sans objet tant que le contrôle' })
$nRs = @($keys | Where-Object { $_ -match 'ou, à défaut, vérification' } | Sort-Object -Unique).Count
Chk 'I1' ($iBad.Count -eq 0 -and $nNew -eq 4 -and $nRawKey -eq 1 -and $segRaw -ceq 'sans vérification gw (image flux écrite telle quelle)' -and [string]$script:I18n[$segRaw] -ceq 'no gw verification (flux image written as is)' -and $nRs -eq 0 -and $stale.Count -eq 0) "$nNew textes nouveaux ou changes (segments, dont celui du flux brut pose par Get-WritePlan, journal, infobulles ; prereglage de l ecriture lente, regles, journal et rapport de la restauration : $nRs textes « controle de toutes les pistes ... ou, a defaut, verification gw ») : entree anglaise dans la section rc4 de 019 ; plus aucun texte « verification gw, N essais, controle de toutes les pistes » dans les modules ($($stale.Count)) ; ecarts : $(Get-List $iBad 3)"

'--- D : CHANGELOG, README, version montree'
$ch = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
$sec = ''; $mm = [regex]::Match($ch, '(?s)## \[12\.11\].*?(?=\n## \[)'); if ($mm.Success) { $sec = $mm.Value }
$ame = ''; $ma = [regex]::Match($sec, '(?s)### Améliorations.*?(?=\n### )'); if ($ma.Success) { $ame = $ma.Value }
$sav = ''; $ms = [regex]::Match($sec, '(?s)### À savoir pour la mise à jour.*?(?=\n### )'); if ($ms.Success) { $sav = $ms.Value }
$rd = [System.IO.File]::ReadAllText((Join-Path $mods 'README.md'), [System.Text.Encoding]::UTF8)
$trd = [System.IO.File]::ReadAllText((Join-Path $Wt 'tests\README.md'), [System.Text.Encoding]::UTF8)
$e000 = [System.IO.File]::ReadAllText((Get-VfMod $Wt '000'), [System.Text.Encoding]::UTF8)
$d1 = [ordered]@{
    'amelioration de R9 retiree' = (-not $sec.Contains('**Écriture sans la vérification de gw quand le contrôle de toutes les pistes s''applique.**'))
    'mesure sur l image accordee' = (-not $sec.Contains('elle suit toujours la case « Sans vérification » et le nombre d''essais') -and -not $sec.Contains('voir « Écriture sans la vérification de gw'))
    'a savoir : les deux gardes' = ($sav.Contains('**Contrôle de toutes les pistes et vérification de gw : les deux gardés.**') -and -not $sav.Contains('**Piste mal écrite : réécrite par le contrôle, plus par gw.**'))
    'flux brut' = $sec.Contains('« sans vérification gw (image flux écrite telle quelle) »')
    'ligne : plus de verification retiree' = (-not $sec.Contains('sans la vérification de gw que la ligne annonçait'))
    'materiel' = ($sec -notmatch 'vérifiée? sur (du )?matériel')
    'README 140' = ([regex]::Match($rd, '\| `140-fn-ecriture\.ps1` \|[^\n]*').Value.Contains('`Get-WriteVerifyPlan`'))
    'README 145' = ([regex]::Match($rd, '\| `145-fn-onglet-ecriture\.ps1` \|[^\n]*').Value.Contains('`Update-WVerifyUi`'))
    'README tests' = $trd.Contains('| `logic-ecriture-verification` |')
    'version montree' = ($e000 -match "(?m)^\`$script:VersionLabel = '12\.11 rc8'" -and $e000 -match "(?m)^\`$script:Version = '12\.11'")   # 12.11 rc8 : preversion suivante
}
Chk 'D1' (@($d1.Keys | Where-Object { -not $d1[$_] }).Count -eq 0) "CHANGELOG 12.11 : $(@($d1.Keys | Where-Object { -not $d1[$_] }) -join ', ') ; R9 retire (entree d Ameliorations retiree ; l entree de la mesure sur l image ne dit plus que l ecriture de l image suit toujours la case), A savoir (piste mal ecrite reecrite par le controle, cas de 0 passe ; relecture : le controle ne compare pas les donnees relues a l image, l image flux ecrite telle quelle n est jamais verifiee par gw, la verification annoncee par la ligne peut etre retiree par une mesure), aucun texte ne dit un comportement verifie sur materiel ; README des modules (140, 145) et des tests ; version montree « 12.11 rc4 », version des donnees « 12.11 » ; ecarts : $(Get-List @($d1.Keys | Where-Object { -not $d1[$_] }))"

$nk = ''; if ($script:Fail) { $nk = ' ; non conformes : ' + (@($script:FailIds) -join ', ') }
"=== bilan logic-ecriture-verification : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
