param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Before = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 rc2 : ecriture pour un lecteur cible avec le facteur par cylindre de la calibration croisee (spec-facteur-croise).
#  U  Get-TargetTransferSpec et Get-TargetTransferSummary (140) : D = Sp donne X a la chaine pres ; facteur uniforme k
#     (D = k.Sp) : k.X partout (rc5, R13 : sous XferMinNs, facteur du cylindre voisin repris) ; borne et zero ; cylindres au-dela de la longueur
#     d une courbe ; tete par tete (Get-TargetTransferPlan) ; resume (min, mediane, max, cylindres sous le seuil et facteur repris, rc5).
#     12.11 rc6 (R15) : D > Sp, hausse reportee au plus en ns (min(rapport, X + D - Sp)) ; U8 : baisse en rapport, hausse
#     bornee en ns, continuite a k = 1, D = Sp -> X, X < Sp. U9 (relecture) : sous le seuil, facteur repris > 1 et D = Sp
#     apres arrondi : X, jamais au-dessus de X + max(0, D - Sp).
#     12.12 : U10, facteur de la disquette pris avant l arrondi au ns ($dBase, $dF, $dHard) : sans eux, courbe de la
#     12.11 ; courbe propre mise a l echelle : k x X en tout cylindre, aussi sous le seuil, sans reprise d un voisin ;
#     hausse X + (k - 1) x Sp ; base mesuree : rapport sur la valeur non arrondie, reprise du voisin sous le seuil ;
#     base qui ne donne pas D : D arrondi, comme avant ; borne ; cas ou les deux calculs different.
#  A  ecriture « meme lecteur » strictement inchangee : six scenarios (mesure sur l image, test rapide, mesure complete,
#     facteur de marque, ecriture rapide au test rapide, Bibliotheque), mesures simulees jusqu a l ecriture (bouchons qui
#     reprennent la fin reelle : Set-LevelFields, drapeau LevelPostForce, facteur mesure WriteFactorNext, puis la vraie
#     Start-ImageWrite) : commandes gw, demandes et journal identiques a ceux de 62b8ce2 (empreintes relevees sur l export
#     de 62b8ce2 ; avec -Before <export>, ligne a ligne).
#  B  ecriture pour le lecteur cible sans mesure : memes commandes gw qu en 62b8ce2 (D = Sp donne X exactement) ; sans
#     courbe propre du lecteur qui ecrit : courbe croisee telle quelle et ligne qui le dit.
#  C  ecriture pour le lecteur cible avec mesure (sur l image, test rapide, mesure complete), facteur de marque, ecriture
#     rapide, Bibliotheque : la courbe ecrite suit la formule de la specification, tete par tete et cylindre par cylindre,
#     bornee ; D est la courbe que le meme lecteur ecrit dans le scenario A correspondant (regle 1).
#  D  ligne « Ce qui va se passer », case de la mesure et journal tires de la meme decision (Get-TargetWriteInfo, Xfer) :
#     rien d annonce que le clic ne fait ; resume du journal recalcule ; francais et anglais, texte affiche entier.
#  E  aucune mesure ni commande ne fait intervenir le lecteur cible (commandes, mesures simulees, arbre syntaxique).
#  R  ecriture de la restauration pour un lecteur cible (vraie Start-PresetWrite 'slow' -NoCalib, l appel de
#     Start-RestoreWrite) : facteur de marque du lecteur qui ecrit puis facteur par cylindre, journal qui le dit.
#  X  12.11 rc4 (R10) : exces de precompensation memorise avec le controle apres ecriture, pour l asymetrie attendue a la
#     relecture par le lecteur qui ecrit. X1 Get-TargetTransferSpec rend, par cylindre, courbe ecrite - D (borne et zero
#     compris) ; X2 la vraie Start-ImageWrite le pose dans le controle (Rep.AsymExcess), par tete : courbe ecrite pour le
#     lecteur cible - courbe que le meme lecteur ecrit dans le scenario A correspondant, restauration comprise ; rien pour
#     le meme lecteur, ni sans courbe propre, ni avec des courbes chargees d un autre lecteur ; X3 hswap dans le champ
#     Pistes : exces de la tete qui ecrit chaque face. L asymetrie attendue elle-meme : logic-qualite-asymetrie (X1 a X9).
#     X5 (12.11, version finale) : la vraie Start-ImageWrite pose avec la correction par zones ce que peut demander son
#     conseil (Rep.ZoneAdvice, Get-TargetZoneAdvice) : origine du facteur par tete relue et consigne de mesure.
# Relecture de la rc2 : borne max(borne, X, D) (C1, C3 : aucun cylindre ecrit sous la courbe du meme lecteur quand X > Sp),
# cas R1, texte de la vraie fenetre de la mesure sur l image avec un lecteur cible (D5).
# Harnais de logic-ecriture-plan : fonctions reelles de tous les modules fn, etat, onglet construit par les instructions
# reelles de 500, 510, 520 et 540, controles jamais affiches, images factices. Aucun gw, aucune fenetre, aucun materiel.
# Non couvert : les mesures elles-memes (bouchons), la restauration elle-meme (sans mesure de la destination ; son
# ecriture, avec le facteur de marque, est couverte par le cas R1 ; l enveloppe Start-RestoreWrite n est pas jouee), le
# bouton « Calibrer » et la carte de l Accueil avec un lecteur cible (logic-cible-textes T1 et T6), l ecriture reelle sur
# disquette.
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
function Get-FkSha([string]$s, [int]$n = 16) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($s))) -replace '-', '').ToLower().Substring(0, $n) } finally { $h.Dispose() }
}
function Get-FkMod([string]$root, [string]$px) {
    $f = @(Get-ChildItem -LiteralPath (Join-Path $root 'src\modules') -Filter "$px-*.ps1" -File)
    if ($f.Count -ne 1) { throw "module $px introuvable sous $root" }
    return $f[0].FullName
}
$utf8b = New-Object System.Text.UTF8Encoding($true)
$tAsgA = [System.Management.Automation.Language.AssignmentStatementAst]
$tFnA = [System.Management.Automation.Language.FunctionDefinitionAst]
$tCmdA = [System.Management.Automation.Language.CommandAst]
function Write-FkGen([string]$path, $parts) { [System.IO.File]::WriteAllText($path, ((@($parts) -join "`r`n`r`n") + "`r`n"), $utf8b) }
$mods = Join-Path $Wt 'src\modules'
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'

# Valeur d un profil --precomp au cylindre c, ecrite ici sans la fonction de l application : derniere entree c=ns dont
# le cylindre est au plus c (prolongement de gw), 0 avant la premiere
function Get-FkVal([string]$spec, [int]$c) {
    $v = 0
    foreach ($e in ([string]$spec -split ':')) { if ($e -match '^\s*(\d+)\s*=\s*(\d+)\s*$' -and [int]$Matches[1] -le $c) { $v = [int]$Matches[2] } }
    return $v
}
# Courbe attendue par la specification (regle 4), ecrite ici : cylindres 0 a $n - 1
# 12.11 rc5 (R13) : sous le seuil, X x D(c')/Sp(c') du cylindre c' le plus proche ou Sp >= seuil (a distance egale, le
# superieur) ; aucun : X x somme D / somme Sp ; somme Sp nulle : X + D - Sp
# 12.11 rc6 (R15) : D > Sp : min(valeur ci-dessus, X + D - Sp)
# 12.12 : $base, $f, $hard : D est $base mis a l echelle par $f ; la ou arrondi(min(f x base, max(hard, base))) = D, le
# rapport et la hausse sont calcules sur cette valeur non arrondie (De) ; la ou de plus base = Sp > 0 (courbe propre),
# De / Sp est applique aussi sous le seuil ($script:FkExact). Sans $base : regle de la 12.11
function Get-FkExpect([string]$d, [string]$sp, [string]$x, [int]$n, [int]$cap, [int]$min, [string]$base = '', [double]$f = 1.0, [int]$hard = 0) {
    $o = New-Object int[] $n; $script:FkCapped = @()   # rc6 : cylindres ou la hausse est reportee en ns
    $script:FkExact = @(); $script:FkBorrow = @()
    $ok = @(for ($c = 0; $c -lt $n; $c++) { if ((Get-FkVal $sp $c) -ge $min) { $c } })
    $de = New-Object double[] $n; $ow = New-Object bool[] $n
    for ($c = 0; $c -lt $n; $c++) {
        $de[$c] = [double](Get-FkVal $d $c)
        if ($base) {
            $bv = [double](Get-FkVal $base $c); $ev = $f * $bv; $bm = [math]::Max([double]$hard, $bv)
            if ($ev -gt $bm) { $ev = $bm }; if ($ev -lt 0) { $ev = 0.0 }
            if ([math]::Round($ev) -eq $de[$c]) { $de[$c] = $ev; $ow[$c] = ($bv -eq [double](Get-FkVal $sp $c) -and $bv -gt 0) }
        }
    }
    $sD = 0.0; $sS = 0.0; for ($c = 0; $c -lt $n; $c++) { $sD += $de[$c]; $sS += Get-FkVal $sp $c }
    for ($c = 0; $c -lt $n; $c++) {
        $dv = $de[$c]; $sv = [double](Get-FkVal $sp $c); $xv = [double](Get-FkVal $x $c)
        if ($sv -ge $min) { $w = $xv * $dv / $sv }
        elseif ($ow[$c]) { $w = $xv * $dv / $sv; $script:FkExact += $c }
        elseif ($ok.Count) {
            $best = $ok[0]; foreach ($q in $ok) { $dq = [math]::Abs($q - $c); $db = [math]::Abs($best - $c); if ($dq -lt $db -or ($dq -eq $db -and $q -gt $best)) { $best = $q } }
            $w = $xv * $de[$best] / [double](Get-FkVal $sp $best); $script:FkBorrow += $c
        }
        elseif ($sS -gt 0) { $w = $xv * $sD / $sS }
        else { $w = $xv + $dv - $sv }
        # 12.11 rc6 (R15) : D > Sp : au plus X + (D - Sp) (hausse de la disquette reportee en ns)
        # relecture de la rc6 : une hausse au-dessus de X ne depasse jamais X + max(0, D - Sp), y compris quand le facteur
        # repris d un voisin depasse 1 alors que D(c) <= Sp(c)
        $lim = $xv + [math]::Max(0.0, $dv - $sv)
        if ($w -gt $xv -and $w -gt $lim) { $w = $lim; $script:FkCapped += $c }
        $w = [math]::Round($w); if ($w -lt 0) { $w = 0 }; $b = [math]::Max([double]$cap, [math]::Max($xv, [double](Get-FkVal $d $c))); if ($w -gt $b) { $w = $b }
        $o[$c] = [int]$w
    }
    return ,$o
}
function Get-FkVals([string]$spec, [int]$n) { return ,[int[]]@(for ($c = 0; $c -lt $n; $c++) { Get-FkVal $spec $c }) }
# Cylindres ou deux courbes different, un par un dans le pipeline (l appelant les recueille par @())
function Get-FkDiff([int[]]$a, [int[]]$b) { for ($c = 0; $c -lt [math]::Max($a.Count, $b.Count); $c++) { if ($a[$c] -ne $b[$c]) { "c$c $($a[$c])/$($b[$c])" } } }

# =====================================================================================================================
# Construction (fonctions de tous les modules fn, etat, onglet, valeurs par defaut), comme logic-ecriture-plan
$fkCtl = @('txtWFile', 'btnWFile', 'cmbWFmt', 'chkWPreErase', 'chkWSlow', 'chkWPostCheck', 'chkWUnattended', 'chkWLevel', 'cmbWLevelMode', 'cmbWTarget', 'cmbWCalMode', 'btnWCalib', 'btnWCross', 'btnWCurve', 'btnWrite',
           'chkWEraseEmpty', 'chkWNoVerify', 'numWRetries', 'numWRepair', 'cmbWProfile', 'chkWPrecomp', 'txtWPrecomp', 'txtWPrecomp1', 'txtWTracks', 'cmbWDensel', 'txtWFakeIdx', 'chkWReverse', 'txtWDiskdefs', 'btnWDiskdefs',
           'chkWHard', 'chkWTG43', 'chkWWarm', 'chkWCalWarm', 'numWWarmMin', 'btnWCalReset', 'btnWCalBack')
function New-FkGen([string]$root, [string]$tag) {
    $g = @{ Root = $root; Tag = $tag }
    $fns = New-Object System.Collections.Generic.List[string]
    foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'src\modules') -Filter '*.ps1' -File | Where-Object { $_.Name -match '^[1-4]\d\d-fn-' } | Sort-Object Name)) {
        foreach ($fd in (Get-Ast $f.FullName).FindAll({ param($x) $x -is $tFnA }, $false)) { $fns.Add($fd.Extent.Text) }
    }
    $g.Fn = Join-Path $here "gen-$tag-fonctions.ps1"; Write-FkGen $g.Fn $fns
    $st = New-Object System.Collections.Generic.List[string]
    foreach ($px in @('000', '020', '040', '550', '560', '565', '570', '580', '590')) {
        foreach ($s in (Get-Ast (Get-FkMod $root $px)).EndBlock.Statements) {
            $t = $s.Extent.Text
            if ($t -match 'Add-Type|EnableVisualStyles') { continue }
            if ($px -eq '020' -and -not ($s -is $tAsgA -and $t.StartsWith('$script:') -and -not $t.StartsWith('$script:AppDir'))) { continue }
            $st.Add($t)
        }
    }
    $g.State = Join-Path $here "gen-$tag-etat.ps1"; Write-FkGen $g.State $st
    $g.U500 = Join-Path $here "gen-$tag-500.ps1"
    Write-FkGen $g.U500 @((Get-Ast (Get-FkMod $root '500')).EndBlock.Statements | Where-Object { $_.Extent.Text -notmatch 'Add-Type' } | ForEach-Object { $_.Extent.Text })
    $ban = @(); $on = $false
    foreach ($s in (Get-Ast (Get-FkMod $root '510')).EndBlock.Statements) {
        $t = $s.Extent.Text
        if ($t.StartsWith('$pnlTop = ')) { $on = $true }
        if ($on) { $ban += $t }
        if ($t.StartsWith('$script:DriveBanner = ')) { $on = $false }
    }
    $g.U510 = Join-Path $here "gen-$tag-510.ps1"; Write-FkGen $g.U510 $ban
    $g.U520 = Join-Path $here "gen-$tag-520.ps1"; Write-FkGen $g.U520 @((Get-Ast (Get-FkMod $root '520')).EndBlock.Statements | ForEach-Object { $_.Extent.Text })
    $g.U540 = Join-Path $here "gen-$tag-540.ps1"
    Write-FkGen $g.U540 @((Get-Ast (Get-FkMod $root '540')).EndBlock.Statements | Where-Object { $_.Extent.Text -match '^(Set-Btn\s+|Set-Cue\s+|\$tip\.SetToolTip\()\$(\w+)\b' -and $fkCtl -contains $Matches[2] } | ForEach-Object { $_.Extent.Text })
    $sd = @((Get-Ast (Get-FkMod $root '120')).FindAll({ param($x) $x -is $tFnA -and $x.Name -eq 'Set-Defaults' }, $false))
    $ds = @($sd[0].Body.EndBlock.Statements | Where-Object { $_.Extent.Text -match '\$(txtW|cmbW|chkW|numW|lblW)' -or $_.Extent.Text -match '^(Reset-Settings|Update-SlowUi|Update-TargetDriveUi)$' } | ForEach-Object { $_.Extent.Text })
    $g.Def = Join-Path $here "gen-$tag-defauts.ps1"
    Write-FkGen $g.Def @("function Invoke-FkDefaults {`r`n" + ($ds -join "`r`n") + "`r`n}")
    return $g
}
function Set-FkStubs {
    # Bouchons : gw, fenetres, journal, prechauffage, controle, profil de l image et autres onglets ; mesures simulees
    # jusqu a l ecriture, comme leurs fins reelles (Complete-LevelCalib, Complete-DiskMeasure, Complete-ContentMeasure) :
    # enregistrements de LevelShifts du lecteur du bandeau, vraie Set-LevelFields, drapeau LevelPostForce, facteur mesure
    # WriteFactorNext, puis la vraie Start-ImageWrite
    function script:Start-Gw([string[]]$gwArgs, [switch]$Soft) { [void]$script:FkTrace.Add('gw ' + ($gwArgs -join ' ')) }
    function script:Invoke-NextChainStep {
        foreach ($q in @($script:WriteQueue.ToArray())) { [void]$script:FkTrace.Add('file ' + (@($q) -join ' ')) }
        if ($script:WriteArgs) { [void]$script:FkTrace.Add('ecriture ' + (@($script:WriteArgs) -join ' ')) }
        [void]$script:FkTrace.Add('etapes ' + $script:Chain.Count)
    }
    function script:Start-WriteWarmup([string]$tspec, [bool]$noWarm) {
        foreach ($q in @($script:WriteQueue.ToArray())) { [void]$script:FkTrace.Add('file ' + (@($q) -join ' ')) }
        [void]$script:FkTrace.Add("prechauffage $tspec $noWarm ; etapes $($script:Chain.Count)")
    }
    function script:New-WriteCheck([string[]]$base, [string]$image, [string]$userTSpec, [int]$max, [string[]]$readOpts, $headPrecomp, [string]$eraseMode = '') {
        $hp = if ($headPrecomp) { "$($headPrecomp[0])/$($headPrecomp[1])" } else { '-' }
        [void]$script:FkTrace.Add("controle base $($base -join ' ') ; relecture $($readOpts -join ' ') ; precomp $hp")
        $script:Rep = @{}
    }
    function script:New-FkRecs($lr, [string]$model, [scriptblock]$f) {
        $recs = @()
        foreach ($u in @($lr.Units)) {
            $h = if ($null -eq $u.Head) { 0 } else { [int]$u.Head }
            $v = [int[]]@(for ($c = 0; $c -lt @($u.V).Count; $c++) { [int][math]::Max(0, (& $f $h $c ([int]$u.V[$c]))) })
            $rec = @{ RefKey = [string]$u.RefKey; Tag = [string]$u.Tag; Head = $u.Head; Drive = [string]$cmbDrive.Text; Date = '14/11/2026 10:00'; RefDate = [string]$u.Cv.Date
                      Model = $model; Spec = (Build-CurveProfile $v); Values = $v }
            $script:LevelShifts["$($u.RefKey)|$($u.Tag)"] = $rec
            $recs += ,$rec
        }
        return ,$recs
    }
    function script:Start-LevelCalib($lr, [switch]$NoConfirm, [switch]$NoFallback, $Geom = $null) {
        [void]$script:FkTrace.Add("calibration rapide lecteur $($cmbDrive.Text) references $((@($lr.Units) | ForEach-Object { [string]$_.Cv.Drive }) -join ',')")
        $recs = New-FkRecs $lr 'M1' { param($h, $c, $v) if ($h -eq 0) { [math]::Round(1.10 * $v + 3) } else { [math]::Round(0.90 * $v - 2) } }
        Set-LevelFields $recs ([bool]$chkWSlow.Checked)
        $script:LevelPostForce = $true
        Append-Log 'bouchon : calibration rapide terminee'
        Start-ImageWrite -NoWarmup
    }
    function script:Start-DiskMeasure($lr, $brand) {
        [void]$script:FkTrace.Add("mesure complete lecteur $($cmbDrive.Text) references $((@($lr.Units) | ForEach-Object { [string]$_.Cv.Drive }) -join ',')")
        $recs = New-FkRecs $lr 'mesure' { param($h, $c, $v) if ($h -eq 0 -and $c -ge 70) { $v + 400 } elseif ($h -eq 0) { $v + 40 } else { $v + 20 } }
        Set-LevelFields $recs $true
        $script:LevelPostForce = $true
        Append-Log 'bouchon : mesure complete terminee'
        Start-ImageWrite -NoWarmup
    }
    function script:Start-ContentMeasure($chk) {
        [void]$script:FkTrace.Add("mesure sur l image lecteur $($chk.Drive) famille $($chk.Fam)")
        # 12.11 rc7 (R16) : pentes de l asymetrie relue des deux tetes (facteur par l asymetrie), comme la fin reelle les transmet
        $script:WriteFactorNext = @{ Drive = [string]$chk.Drive; Fam = [string]$chk.Fam; Img = [string]$chk.Img; K = @{ 0 = 1.10; 1 = 0.95 }; Src = @{ 0 = 'mesure'; 1 = 'mesure' }; Date = '14/11/2026 10:00'; Brand = ''; SRel = @{ 0 = 0.815; 1 = 0.765 } }
        Append-Log 'bouchon : mesure sur l image terminee'
        Start-ImageWrite -NoWarmup
    }
    function script:Start-PrecompCalib([switch]$ForceFine) { [void]$script:FkTrace.Add('calibration complete') }
    function script:Show-AppMessage([string]$text, [string]$title, [string]$buttons = 'OK', [string]$icon = 'Information') { [void]$script:FkTrace.Add("message $title $buttons"); [void]$script:FkLog.Add($text); if ($buttons -eq 'YesNo') { return 'No' }; return 'OK' }
    function script:Show-AppConfirm([string]$Title, [string]$Heading, [string]$Text, [string]$Check = '', [string]$GoText = '', [string]$GoGlyph = '', [string]$Level = 'warn', [string]$Picto = 'warn', [string]$AltText = '', $Combo = $null) { [void]$script:FkTrace.Add("confirmation $Title"); [void]$script:FkLog.Add($Text); return $true }
    function script:Show-Tab($t) { [void]$script:FkTrace.Add('onglet') }
    function script:Append-Log($t) { [void]$script:FkLog.Add([string]$t) }
    function script:Update-PrecompForImage($p) { [void]$script:FkTrace.Add('profil recalcule'); [void](Set-PrecompFields $script:PrecompStd 'std') }
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

# --- Images factices et courbes
$fkImg = Join-Path $here 'img'
if (-not (Test-Path -LiteralPath $fkImg)) { [void](New-Item -ItemType Directory -Path $fkImg -Force) }
$imAdf = Join-Path $fkImg 'jeu.adf'; [System.IO.File]::WriteAllBytes($imAdf, (New-Object byte[] 901120))
function New-FkCurve([string]$drive, [int[]]$v, [string]$date) {
    $cy = [int[]]@(for ($c = 0; $c -lt $v.Count; $c += 4) { $c })
    return @{ Values = $v; Cyls = $cy; Kinds = [string[]]@($cy | ForEach-Object { 'interp' }); Res = [double[]]@($cy | ForEach-Object { 0.5 }); Ys = [double[]]@($cy | ForEach-Object { [double]$v[$_] })
              Sig = [double[]]@($cy | ForEach-Object { 1.0 }); Breaks = @(); Date = $date; Test = 'fine'; Drive = $drive; Method = 'motif'; Bits = 101344; Slope = -1.0; Converged = $true; MaxNs = 400
              Spec = (Build-CurveProfile $v); Calc = [string]$script:CalibCalc }
}
function Get-FkLin([int]$a, [int]$b) { return ,[int[]]@(for ($c = 0; $c -lt 80; $c++) { $a + $b * $c }) }
function Set-FkCurves([bool]$own, [bool]$cross) {
    # Courbes propres de A (besoin sous XferMinNs aux cylindres 0 et 1) et courbes croisees A -> 0, communes et par tete
    $script:DriveCurves = @{}
    if ($own) {
        $script:DriveCurves['A|std'] = New-FkCurve 'A' (Get-FkLin 6 3) '01/11/2026 10:00'
        $script:DriveCurves['A|std_h0'] = New-FkCurve 'A' (Get-FkLin 4 3) '01/11/2026 11:00'
        $script:DriveCurves['A|std_h1'] = New-FkCurve 'A' (Get-FkLin 7 2) '01/11/2026 11:00'
    }
    if ($cross) {
        $script:DriveCurves['A>0|std'] = New-FkCurve 'A>0' (Get-FkLin 30 4) '02/11/2026 10:00'
        $script:DriveCurves['A>0|std_h0'] = New-FkCurve 'A>0' (Get-FkLin 25 5) '02/11/2026 11:00'
        $script:DriveCurves['A>0|std_h1'] = New-FkCurve 'A>0' (Get-FkLin 35 4) '02/11/2026 11:00'
    }
    Sync-PrecompCurves
}
function Reset-FkState {
    $script:Restore = $null; $script:GwProc = $null; $script:Cal = $null; $script:AfterCalib = ''; $script:LevelPostForce = $false; $script:WriteFactorNext = $null
    $script:ScpStatsOk = $true; $script:ScpWeakCache = $null; $script:OpOverride = $null; $script:ContentMeasures = @(); $script:LevelBrand = ''
    $script:DriveReg = [ordered]@{}; $script:TargetDrives = @{}; $script:DriveCurves = @{}; $script:LevelShifts = @{}
    $cmbDrive.SelectedItem = 'A'
    Invoke-FkDefaults
    Sync-PrecompCurves
}
$fkNorm = { param($x) ([string]$x).Replace($fkImg, '<img>') }
function Set-FkBrand([double]$k) { $script:ContentMeasures = @(foreach ($h in 0, 1) { @{ Drive = 'A'; Family = 'std'; Head = $h; K = $k; Etat = 'mesure'; Brand = ''; Date = '01/11/2026 10:00'; ContentCalc = $script:ContentCalc; Calc = $script:CalibCalc } }) }

# Scenarios : A (meme lecteur) et leur pendant C (lecteur cible 0), B (lecteur cible sans mesure). Fn : 'tab' (bouton
# ECRIRE, vraie Start-WriteTabWrite), 'preset' (Bibliotheque, vraie Start-PresetWrite 'slow' ou 'fast')
$scA = @(
    @{ Id = 'A1'; T = 'lente, mesure sur l image'; Fn = 'tab'; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $cmbWLevelMode.SelectedIndex = 0 } }
    @{ Id = 'A2'; T = 'lente, Test rapide (niveau et forme)'; Fn = 'tab'; Do = { $chkWSlow.Checked = $true; $cmbWCalMode.SelectedIndex = 2 } }
    @{ Id = 'A3'; T = 'lente, mesure complete'; Fn = 'tab'; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $cmbWLevelMode.SelectedIndex = 2 } }
    @{ Id = 'A4'; T = 'lente, facteur de marque 1,25, sans mesure'; Fn = 'tab'; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $false; Set-FkBrand 1.25 } }
    @{ Id = 'A5'; T = 'rapide, Test rapide'; Fn = 'tab'; Do = { $chkWSlow.Checked = $false; $cmbWCalMode.SelectedIndex = 2 } }
    @{ Id = 'A6'; T = 'Bibliotheque, lente, mesure sur l image'; Fn = 'slow'; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $cmbWLevelMode.SelectedIndex = 0 } }
)
$scB = @(
    @{ Id = 'B1'; T = 'lente, sans mesure, facteur 1'; Fn = 'tab'; Own = $true; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $false } }
    @{ Id = 'B2'; T = 'rapide, sans mesure, facteur 1'; Fn = 'tab'; Own = $true; Do = { $chkWSlow.Checked = $false; $chkWLevel.Checked = $false } }
    @{ Id = 'B3'; T = 'lente, mesure demandee, sans courbe propre de A'; Fn = 'tab'; Own = $false; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $true } }
    @{ Id = 'B4'; T = 'Bibliotheque, lente, sans mesure'; Fn = 'slow'; Own = $true; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $false } }
)
# Restauration pour le lecteur cible 0 : ecriture de Start-RestoreWrite (Start-PresetWrite 'slow' -NoCalib), sans mesure
$scR = @{ Id = 'R1'; T = 'restauration, facteur de marque 1,25'; Fn = 'restore'; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $false; Set-FkBrand 1.25 } }
# 12.11 rc4 (R10, cas X3) : hswap dans le champ Pistes : la face h est ecrite par la tete 1 - h, avec le profil de celle-ci
$scH = @{ Id = 'H1'; T = 'lente, facteur de marque 1,25, hswap'; Fn = 'tab'; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $false; Set-FkBrand 1.25; $txtWTracks.Text = 'hswap' } }
# Empreintes de 62b8ce2 (sortie de ce test lance avec -Before <export de 62b8ce2>) : A, commandes et demandes (T) et
# journal (J) ; B, commandes (T)
$fkRef = @{
    A1 = '4fb4b9d6954e1bb2/34203896f563c2e4'; A2 = 'a309db8b952605a3/4d8bf2d5443cd811'; A3 = '4d91118d53887648/49348136c0b46c21'; A4 = 'e87f0d2f37f00e33/00033c8c0c7ef24e'
    A5 = '2c1217c5a7aaaf6f/dbd4f275b33fea04'; A6 = '4fb4b9d6954e1bb2/34203896f563c2e4'
    B1 = 'c3d3d1e0a1de683d'; B2 = '137929dfbaab410b'; B3 = 'c3d3d1e0a1de683d'; B4 = 'c3d3d1e0a1de683d'
}

function Invoke-FkScenario($sc, [bool]$tgt, [bool]$own, [bool]$withPlan, [scriptblock]$Desync = $null) {
    Reset-FkState
    $txtWFile.Text = $imAdf; $cmbWFmt.SelectedItem = 'amiga.amigados'
    Set-FkCurves $own $true
    if ($tgt) { $script:TargetDrives['A'] = '0' }
    & $sc.Do
    # 12.11 rc2.1 (cas G) : vue de travail desaccordee du magasin apres la mise en place ; decision relevee avant l ecriture
    if ($Desync) { & $Desync }
    $twx = Get-TargetWriteInfo ([string]$txtWFile.Text) ([string]$cmbWFmt.Text) ([bool]$chkWSlow.Checked)
    # Case de la mesure et ligne accordees au lecteur cible pose dans l etat (comme en sortie d Update-PrecompForImage)
    Update-WLevelUi
    $plan = $null; $chk = $null; $side = 0
    if ($withPlan) {
        $script:FkTrace.Clear(); $script:FkLog.Clear()
        $plan = Get-WritePlan
        $chk = @{ Enabled = [bool]$chkWLevel.Enabled; Text = [string]$chkWLevel.Text; Tip = [string]$tip.GetToolTip($chkWLevel) }
        $side = $script:FkTrace.Count + $script:FkLog.Count
    }
    $script:FkTrace.Clear(); $script:FkLog.Clear()
    $script:WriteQueue.Clear(); $script:Chain.Clear(); $script:WriteArgs = $null; $script:Rep = $null
    try {
        if ($sc.Fn -eq 'tab') { Start-WriteTabWrite } elseif ($sc.Fn -eq 'slow') { $chkWSlow.Checked = $true; Start-PresetWrite 'slow' }
        elseif ($sc.Fn -eq 'restore') { $chkWSlow.Checked = $true; Start-PresetWrite 'slow' -NoCalib } else { Start-PresetWrite 'fast' }
    } catch { [void]$script:FkTrace.Add("ERREUR $($_.Exception.Message)") }
    $tr = @($script:FkTrace | ForEach-Object { & $fkNorm $_ })
    $wr = @{}
    foreach ($t in $tr) {
        if ($t -notmatch '^(file|gw|ecriture) write ') { continue }
        $m = [regex]::Match($t, '--precomp (\S+)'); if (-not $m.Success) { continue }
        $hm = [regex]::Match($t, '--tracks=\S*h=(\d)(?![-,\d])')
        $k = if ($hm.Success) { [int]$hm.Groups[1].Value } else { 'r' }
        $wr[$k] = $m.Groups[1].Value
    }
    # 12.11 rc4 (R10) : Rep, controle apres ecriture tel que la vraie Start-ImageWrite le laisse (bouchon de New-WriteCheck :
    # table vide, que l ecriture complete : lecteur cible, exces memorise)
    return @{ Trace = $tr; Log = @($script:FkLog | ForEach-Object { & $fkNorm $_ }); Plan = $plan; Chk = $chk; Side = $side; W = $wr; Slow = [bool]$chkWSlow.Checked; Tw = $twx; Rep = $script:Rep }
}
function Get-FkPrint($r, [switch]$TOnly) {
    $t = Get-FkSha (@($r.Trace) -join "`n")
    if ($TOnly) { return $t }
    return "$t/$(Get-FkSha (@($r.Log) -join "`n"))"
}

# =====================================================================================================================
$script:FkTrace = New-Object System.Collections.Generic.List[string]
$script:FkLog = New-Object System.Collections.Generic.List[string]
$stOp = New-Object System.Windows.Forms.ToolStripStatusLabel; $status = New-Object System.Windows.Forms.StatusStrip
$fkRoots = @()
if ($Before) { $fkRoots += @{ Root = (Get-TestRoot $Before); Tag = 'avant'; New = $false } }
$fkRoots += @{ Root = $Wt; Tag = 'fk'; New = $true }
$res = @{}
foreach ($pr in $fkRoots) {
    "--- construction de l onglet : $(if ($pr.New) { 'source testee' } else { "source d avant ($($pr.Root))" })"
    $g = New-FkGen $pr.Root $pr.Tag
    $script:AppDir = $here
    . $g.State
    . $g.Fn
    # Vraie Start-ContentMeasure gardee avant son bouchon (D5 : texte de sa fenetre)
    if ($pr.New) { $fkRealCm = ${function:Start-ContentMeasure} }
    Set-FkStubs
    $script:Lang = 'fr'
    $script:UiReady = $false; $script:ScpStatsOk = $true
    . $g.U500
    . $g.U510
    . $g.U520
    . $g.U540
    . $g.Def
    $tabW.Font = $form.Font
    Fit-ControlText $tabW
    if ($pr.New) { Set-WriteTabLayout }
    Invoke-FkDefaults
    $script:UiReady = $true
    $tabW.Size = New-Object System.Drawing.Size(792, 516)
    $rr = @{}
    foreach ($sc in $scA) { $rr[$sc.Id] = Invoke-FkScenario $sc $false $true $false }
    foreach ($sc in $scB) { $rr[$sc.Id] = Invoke-FkScenario $sc $true ([bool]$sc.Own) $pr.New }
    if ($pr.New) {
        foreach ($sc in $scA) { $rr['C' + $sc.Id.Substring(1)] = Invoke-FkScenario $sc $true $true $true }
        # 12.12 (X4, X5) : memes ecritures que C1 a C6, case « Corriger les zones ecartees de l attendu (lecteur cible) »
        # cochee apres la mise en place (elle est decochee par defaut)
        foreach ($sc in $scA) { $rr['Z' + $sc.Id.Substring(1)] = Invoke-FkScenario $sc $true $true $true { $chkWZones.Checked = $true } }
        $rr['R1'] = Invoke-FkScenario $scR $true $true $false
        # 12.11 rc2.1 (cas G) : courbes propres de A au magasin, vue de travail vide (profil non calibre) ou portant les
        # courbes d un autre lecteur (memes valeurs, lecteur 0) ; G3 : vue accordee. Ecriture lente, mesure demandee (B3)
        $rr['G1'] = Invoke-FkScenario $scB[2] $true $true $true { foreach ($k in $script:CurveKeys) { $script:PrecompCurves[$k] = $null }; $script:PrecompStd = $script:PrecompStdDefault }
        $rr['G2'] = Invoke-FkScenario $scB[2] $true $true $true { foreach ($k in @('std', 'std_h0', 'std_h1')) { $o = $script:PrecompCurves[$k].Clone(); $o.Drive = '0'; $script:PrecompCurves[$k] = $o } }
        $rr['G3'] = Invoke-FkScenario $scB[2] $true $true $true
        # 12.11 rc4 (R10, cas X3) : hswap, meme lecteur puis lecteur cible
        $rr['H0'] = Invoke-FkScenario $scH $false $true $false
        $rr['H1'] = Invoke-FkScenario $scH $true $true $false
    }
    $res[$pr.Tag] = $rr
}
$cur = $res['fk']

# =====================================================================================================================
'--- U : Get-TargetTransferSpec, Get-TargetTransferSummary, Get-TargetTransferPlan'
$min = [int]$script:XferMinNs; $cap = 400
Chk 'U0' ($min -eq 10) "seuil XferMinNs (040) : $min ns"
# U1 : D = Sp, profils quelconques (besoin propre sous 10 ns au bord, entrees non alignees) : X rendue telle quelle
$u1 = @(@('0=4:2=12:40=50:79=90', '0=40:30=80:79=150'), @('0=0:5=9:6=30', '0=12:3=13:9=500'), @('0=200', '0=7:1=8'))
$u1Bad = @()
foreach ($p in $u1) { $t = Get-TargetTransferSpec $p[0] $p[0] $p[1] 0 $cap; if ($t.Spec -cne $p[1] -or -not $t.Same) { $u1Bad += "$($p[0]) -> $($t.Spec)" } }
Chk 'U1' ($u1Bad.Count -eq 0) "regle 5 : D = Sp donne X a la chaine pres (meme profil transmis qu en rc1), $($u1.Count) jeux dont une courbe croisee au-dessus de la borne ; ecarts : $(Get-List $u1Bad)"
# U2 : facteur uniforme k = 1,5 (D = 1,5 Sp exactement), X > Sp. rc5 (R13) : 1,5 X partout ; 12.11 rc6 (R15) : la
# disquette demande plus que la courbe propre, hausse reportee en ns : X + 0,5 Sp = 22 + 3c sur les 80 cylindres (sous
# 10 ns aussi : X x 1,5 du cylindre 3 repris serait plus haut), sans marche au seuil
$sp2 = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { 4 + 2 * $c }))
$d2 = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { 6 + 3 * $c }))
$x2 = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { 20 + 2 * $c }))
$t2 = Get-TargetTransferSpec $d2 $sp2 $x2 0 1000
$e2 = [int[]]@(for ($c = 0; $c -lt 80; $c++) { 22 + 3 * $c })
$g2 = Get-FkVals $t2.Spec 80
$df2 = @(Get-FkDiff $g2 $e2)
$bw2 = @(foreach ($c in 0, 1, 2) { if ($t2.Borrow -and $t2.Borrow.ContainsKey($c)) { "$c>$($t2.Borrow[$c])" } }) -join ','
Chk 'U2' ($df2.Count -eq 0 -and @($t2.Added).Count -eq 0 -and $bw2 -eq '0>3,1>3,2>3' -and @($t2.Ratio.Keys).Count -eq 77 -and @($t2.Capped).Count -eq 80) "facteur uniforme 1,5, X > Sp : X + 0,5 Sp aux 80 cylindres (hausse reportee en ns, $(@($t2.Capped).Count) cylindres marques), sans marche au seuil ; cylindres 0 a 2 (Sp < 10 ns) : facteur du cylindre 3 repris pour la part en rapport ($bw2) ; ecarts : $(Get-List $df2)"
# U8 (12.11 rc6, R15) : regle min(rapport, ns), ecrite ici sans Get-FkExpect. Sp = 4 + 2c, X = 20 + 2c (X > Sp)
#  a) baisse k = 0,5 : X x 0,5 partout (regle de la rc5, aucun cylindre marque) ;
#  b) hausse k = 2 : X + Sp (au lieu de 2 X) ;
#  c) continuite autour de k = 1 : k 0,99 et 1,01 a 1 ns au plus de X ; k = 1 (D = Sp) : X a la chaine pres ;
#  d) X < Sp et baisse (Sp = 40 + 2c, X = 20 + c, k 0,5) : en rapport, 0,5 X (et non X - 0,5 Sp, qui irait a 0) ;
#  e) X < Sp et hausse (k 1,5) : la part en rapport, 1,5 X, est sous X + 0,5 Sp : 1,5 X retenu
$u8Bad = @()
$sp8 = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { 4 + 2 * $c })); $x8 = $x2
foreach ($q in @(@(0.5, { param($c) 0.5 * (20 + 2 * $c) }, 0), @(2.0, { param($c) (20 + 2 * $c) + (4 + 2 * $c) }, 80))) {
    $dq = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { [int][math]::Round($q[0] * (4 + 2 * $c)) }))
    $tq = Get-TargetTransferSpec $dq $sp8 $x8 0 1000
    $gq = Get-FkVals $tq.Spec 80
    $bad = @(for ($c = 3; $c -lt 80; $c++) { if ([math]::Abs($gq[$c] - (& $q[1] $c)) -gt 1) { "c$c $($gq[$c])" } })
    if ($bad.Count -or @($tq.Capped).Count -ne $q[2]) { $u8Bad += "k $($q[0]) : $(Get-List $bad 3), $(@($tq.Capped).Count) marques" }
}
$g99 = Get-FkVals (Get-TargetTransferSpec (ConvertTo-ScaledSpec $sp8 0.99 1000) $sp8 $x8 0 1000).Spec 80
$g101 = Get-FkVals (Get-TargetTransferSpec (ConvertTo-ScaledSpec $sp8 1.01 1000) $sp8 $x8 0 1000).Spec 80
$t100 = Get-TargetTransferSpec $sp8 $sp8 $x8 0 1000
$cont = @(for ($c = 0; $c -lt 80; $c++) { if ([math]::Abs($g99[$c] - (20 + 2 * $c)) -gt 2 -or [math]::Abs($g101[$c] - (20 + 2 * $c)) -gt 2) { "c$c $($g99[$c])/$($g101[$c])" } })
if ($cont.Count -or $t100.Spec -cne $x8 -or @($t100.Capped).Count) { $u8Bad += "continuite : $(Get-List $cont 3) ; D = Sp : $($t100.Spec -ceq $x8)" }
$spD = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { 40 + 2 * $c })); $xD = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { 20 + $c }))
$gD = Get-FkVals (Get-TargetTransferSpec (ConvertTo-ScaledSpec $spD 0.5 1000) $spD $xD 0 1000).Spec 80
$tE = Get-TargetTransferSpec (ConvertTo-ScaledSpec $spD 1.5 1000) $spD $xD 0 1000; $gE = Get-FkVals $tE.Spec 80
$dE = @(for ($c = 0; $c -lt 80; $c++) { if ([math]::Abs($gD[$c] - 0.5 * (20 + $c)) -gt 1) { "d c$c $($gD[$c])" }; if ([math]::Abs($gE[$c] - 1.5 * (20 + $c)) -gt 1) { "e c$c $($gE[$c])" } })
if ($dE.Count -or @($tE.Capped).Count) { $u8Bad += "X < Sp : $(Get-List $dE 4) ; marques $(@($tE.Capped).Count)" }
Chk 'U8' ($u8Bad.Count -eq 0) "rc6 (R15) : baisse k 0,5 en rapport (c40 : $((Get-FkVals (Get-TargetTransferSpec (ConvertTo-ScaledSpec $sp8 0.5 1000) $sp8 $x8 0 1000).Spec 80)[40]) ns pour X 100) ; hausse k 2 bornee en ns (X + Sp) ; continuite a k = 1 (c40 : $($g99[40]) / $($g101[40]) ns) ; D = Sp -> X ; X < Sp : baisse et hausse en rapport (c40 : $($gD[40]) / $($gE[40]) ns pour X 60) ; ecarts : $(Get-List $u8Bad)"
# U9 (relecture de la rc6) : hausse faible (k 1,2) et Sp au bord sous 10 ns : D = round(1,2 Sp) vaut Sp a c0 (Sp 2) ; le
# facteur 1,2 repris du cylindre 8 ne doit pas y porter la courbe a 1,2 X (48 ns) : X (40 ns). Partout : au plus
# X + max(0, D - Sp) ; baisse k 0,8 : 0,8 X au bord comme en rc5 (facteur repris, aucun cylindre marque)
$sp9 = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { 2 + $c })); $x9 = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { 40 + 2 * $c }))
$d9 = ConvertTo-ScaledSpec $sp9 1.2 1000; $t9 = Get-TargetTransferSpec $d9 $sp9 $x9 0 1000; $g9 = Get-FkVals $t9.Spec 80
$o9 = @(for ($c = 0; $c -lt 80; $c++) { $lim = (40 + 2 * $c) + [math]::Max(0, (Get-FkVal $d9 $c) - (2 + $c)); if ($g9[$c] -gt $lim) { "c$c $($g9[$c])>$lim" } })
$t9b = Get-TargetTransferSpec (ConvertTo-ScaledSpec $sp9 0.8 1000) $sp9 $x9 0 1000; $g9b = Get-FkVals $t9b.Spec 80
Chk 'U9' ($g9[0] -eq 40 -and $o9.Count -eq 0 -and @($t9.Capped) -contains 0 -and $t9.Borrow[0] -eq 8 -and $g9b[0] -eq 32 -and @($t9b.Capped).Count -eq 0) "k 1,2, Sp 2 ns a c0 (D = Sp apres arrondi), facteur du cylindre $($t9.Borrow[0]) repris : c0 $($g9[0]) ns (X 40, 48 sans borne) ; au-dessus de X + max(0, D - Sp) : $(Get-List $o9) ; baisse k 0,8 : c0 $($g9b[0]) ns (0,8 X), $(@($t9b.Capped).Count) cylindre marque"
# U10 (12.12) : facteur de la disquette pris avant l arrondi au ns. Sp = 2 + c (sous le seuil de c0 a c7), X = 31 + 2c (impair : jamais de demi-ns a l arrondi de 0,83 x X)
$spU = (0..79 | ForEach-Object { "$_=$(2 + $_)" }) -join ':'; $xU = (0..79 | ForEach-Object { "$_=$(31 + 2 * $_)" }) -join ':'
$u10 = @()
# a. sans base (defaut) et base vide : meme resultat ; base = Sp et facteur 1 : courbe croisee telle quelle
$dU = ConvertTo-ScaledSpec $spU 0.83 $cap
$tA = Get-TargetTransferSpec $dU $spU $xU 80 $cap; $tB = Get-TargetTransferSpec $dU $spU $xU 80 $cap 0 '' 0.83 $cap
if ([string]$tA.Spec -cne [string]$tB.Spec -or (@($tA.Values) -join ',') -ne (@($tB.Values) -join ',') -or @($tB.Exact).Count -ne 0) { $u10 += 'a : base vide' }
$t1 = Get-TargetTransferSpec $spU $spU $xU 80 $cap 0 $spU 1.0 $cap
if ([string]$t1.Spec -cne $xU -or -not $t1.Same) { $u10 += 'a : facteur 1' }
# b. courbe propre x 0,83 : arrondi(0,83 x X) en tout cylindre, aucun facteur repris, cylindres sous le seuil dans Exact
$tN = Get-TargetTransferSpec $dU $spU $xU 80 $cap 0 $spU 0.83 $cap
$bad = @(for ($c = 0; $c -lt 80; $c++) { if ([int]$tN.Values[$c] -ne [int][math]::Round(0.83 * (31 + 2 * $c))) { $c } })
if ($bad.Count -or $tN.Borrow.Count -ne 0 -or (@($tN.Exact) -join ',') -ne '0,1,2,3,4,5,6,7' -or $tN.Same) { $u10 += "b : $($bad.Count) cyl., repris $($tN.Borrow.Count), exacts $(@($tN.Exact) -join ',')" }
# c. le calcul de la 12.11 (D arrondi) s en ecarte : au moins un cylindre a plus de 0,5 ns de 0,83 x X, et repris sous le seuil
$far = @(for ($c = 0; $c -lt 80; $c++) { if ([math]::Abs([int]$tA.Values[$c] - 0.83 * (31 + 2 * $c)) -gt 0.5) { $c } })
$nDiff = @(for ($c = 0; $c -lt 80; $c++) { if ([int]$tA.Values[$c] -ne [int]$tN.Values[$c]) { $c } }).Count
if ($far.Count -eq 0 -or $nDiff -eq 0 -or $tA.Borrow.Count -ne 8) { $u10 += "c : $($far.Count) loin, $nDiff differents, repris $($tA.Borrow.Count)" }
# d. Excess reste compte sur D arrondi (ce que le meme lecteur ecrit)
$bad = @(for ($c = 0; $c -lt 80; $c++) { if ([int]$tN.Excess[$c] -ne [int]$tN.Values[$c] - (Get-FkVal $dU $c)) { $c } })
if ($bad.Count) { $u10 += "d : exces $($bad.Count) cyl." }
# e. courbe propre x 1,60 (hausse) : min(1,6 x X, X + 0,6 x Sp), arrondi ; hausse reportee en ns en tout cylindre (X > Sp)
$dH = ConvertTo-ScaledSpec $spU 1.60 $cap
$tH = Get-TargetTransferSpec $dH $spU $xU 80 $cap 0 $spU 1.60 $cap
$bad = @(for ($c = 0; $c -lt 80; $c++) { $xv = 31 + 2 * $c; $sv = 2 + $c; if ([int]$tH.Values[$c] -ne [int][math]::Round([math]::Min(1.60 * $xv, $xv + 0.60 * $sv))) { $c } })
if ($bad.Count -or @($tH.Capped).Count -ne 80) { $u10 += "e : $($bad.Count) cyl., hausse en ns sur $(@($tH.Capped).Count)" }
# f. base mesuree (autre que Sp) x 0,90 : X x (0,9 x base) / Sp au-dessus du seuil ; dessous, facteur non arrondi du
#    cylindre c8 repris (Borrow) ; rien dans Exact
$bM = (0..79 | ForEach-Object { "$_=$(5 + 2 * $_)" }) -join ':'; $dM = ConvertTo-ScaledSpec $bM 0.90 $cap
$tM = Get-TargetTransferSpec $dM $spU $xU 80 $cap 0 $bM 0.90 $cap
$eM = Get-FkExpect $dM $spU $xU 80 $cap $min $bM 0.90 $cap
$bad = @(Get-FkDiff ([int[]]$tM.Values) $eM)
$r8 = 0.90 * (5 + 2 * 8) / (2 + 8)
$lowBad = @(for ($c = 0; $c -lt 8; $c++) { $xv = 31 + 2 * $c; $w = $r8 * $xv; $lim = $xv + [math]::Max(0.0, 0.90 * (5 + 2 * $c) - (2 + $c)); if ($w -gt $xv -and $w -gt $lim) { $w = $lim }; if ([int]$tM.Values[$c] -ne [int][math]::Round($w)) { $c } })
if ($bad.Count -or $lowBad.Count -or $tM.Borrow.Count -ne 8 -or @($tM.Exact).Count -ne 0 -or @($script:FkExact).Count -ne 0) { $u10 += "f : $(Get-List $bad 3), sous le seuil $($lowBad -join ','), repris $($tM.Borrow.Count)" }
# g. base qui ne donne pas D (facteur annonce 0,5 pour un D fait a 0,83) : aucun cylindre pris sur la base, courbe de la 12.11
$tW = Get-TargetTransferSpec $dU $spU $xU 80 $cap 0 $spU 0.5 $cap
$same = @(for ($c = 0; $c -lt 80; $c++) { if ([math]::Round(0.5 * (2 + $c)) -eq (Get-FkVal $dU $c)) { $c } })
$bad = @(for ($c = 0; $c -lt 80; $c++) { if ($same -notcontains $c -and [int]$tW.Values[$c] -ne [int]$tA.Values[$c] -and $c -ge 8) { $c } })
if ($bad.Count -or $same.Count -gt 3) { $u10 += "g : $($bad.Count) cyl. (arrondis egaux par hasard : $($same -join ','))" }
# h. borne : base 300 x 1,5 = 450 > max(borne 400, 300) : De = 400 = D ; X 350, Sp 300 : min(350 x 400 / 300, 350 + 100) = 450,
#    ramene a max(borne, X, D) = 400
$tC = Get-TargetTransferSpec (ConvertTo-ScaledSpec '0=300' 1.5 400) '0=300' '0=350' 80 400 0 '0=300' 1.5 400
if ([int]$tC.Values[0] -ne 400 -or (ConvertTo-ScaledSpec '0=300' 1.5 400) -cne '0=400') { $u10 += "h : $($tC.Values[0])" }
# i. Sp nul en un cylindre (pas de rapport) : facteur non arrondi du voisin repris, soit k x X
$sp0 = '0=0:1=12:2=13'; $x0 = '0=40:1=42:2=44'; $d0 = ConvertTo-ScaledSpec $sp0 0.83 $cap
$tZ = Get-TargetTransferSpec $d0 $sp0 $x0 3 $cap 0 $sp0 0.83 $cap
if ([int]$tZ.Values[0] -ne [int][math]::Round(0.83 * 40) -or [int]$tZ.Borrow[0] -ne 1 -or @($tZ.Exact).Count -ne 0) { $u10 += "i : $($tZ.Values[0]), repris $($tZ.Borrow[0])" }
Chk 'U10' ($u10.Count -eq 0) "facteur de la disquette avant l arrondi au ns : sans base, courbe de la 12.11 ; courbe propre x 0,83 : arrondi(0,83 x X) aux 80 cylindres, dont les 8 sous le seuil sans facteur repris (12.11 : $nDiff cylindre(s) differents, $($far.Count) a plus de 0,5 ns de 0,83 x X) ; x 1,60 : min(1,6 x X, X + 0,6 x Sp) ; base mesuree : valeur non arrondie, voisin repris sous le seuil ; base incoherente : D arrondi ; borne ; Sp nul ; ecarts : $(Get-List $u10)"
# U2b (R13, constat sur materiel) : k = 0,65, Sp au bord sous 10 ns : 0,65 X partout (rc4 : X - 0,35 Sp sous le seuil)
$sp2b = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { 2 + $c }))
$d2b = ConvertTo-ScaledSpec $sp2b 0.65 1000
$x2b = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { 44 + $c }))
$t2b = Get-TargetTransferSpec $d2b $sp2b $x2b 0 1000
$e2b = Get-FkExpect $d2b $sp2b $x2b 80 1000 $min
$g2b = Get-FkVals $t2b.Spec 80
$df2b = @(Get-FkDiff $g2b $e2b)
# Saut au seuil (c7 -> c8, Sp 9 -> 10) au plus celui de X x f a l arrondi pres ; valeurs sous le seuil = 0,65 X a l arrondi de D pres
$f8 = (Get-FkVal $d2b 8) / 10.0
$lo = @(for ($c = 0; $c -lt 8; $c++) { if ([math]::Abs($g2b[$c] - (44 + $c) * $f8) -gt 0.51) { "c$c $($g2b[$c])" } })
Chk 'U2b' ($df2b.Count -eq 0 -and $lo.Count -eq 0 -and [math]::Abs(($g2b[8] - $g2b[7]) - $f8) -le 1 -and $g2b[0] -le [math]::Round(0.7 * 44)) "k 0,65, Sp de 2 a 81 ns, X de 44 a 123 ns : cylindres 0 a 7 = X x D(8)/Sp(8) ($f8), c0 $($g2b[0]) ns (rc4 : 43 ns), c7 -> c8 $($g2b[7]) -> $($g2b[8]) ns ; ecarts : $(Get-List (@($df2b) + $lo))"
# U2c : D de forme libre (test rapide, mesure complete) : continuite au seuil, facteur du premier cylindre au-dessus ;
# creux interieur de Sp (c40-41 sous 10 ns : c40 -> c39, c41 -> c42) ;
# cylindre a egale distance (c60 seul sous le seuil : c61 repris) ; Sp partout sous le seuil (facteur moyen) ; Sp nul (ecart reporte)
$sp2c = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { if ($c -in 40, 41, 60) { 5 } elseif ($c -lt 6) { 3 + $c } else { 10 + $c } }))
$d2c = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { 20 + [int](15 * [math]::Sin($c / 7.0)) + $c }))
$x2c = Build-CurveProfile ([int[]]@(for ($c = 0; $c -lt 80; $c++) { 50 + 2 * $c }))
$t2c = Get-TargetTransferSpec $d2c $sp2c $x2c 0 1000
$e2c = Get-FkExpect $d2c $sp2c $x2c 80 1000 $min; $cap2c = @($script:FkCapped)
$df2c = @(Get-FkDiff (Get-FkVals $t2c.Spec 80) $e2c)
$bw2c = @(foreach ($c in 0, 5, 40, 41, 60) { "$c>$(if ($t2c.Borrow) { $t2c.Borrow[$c] })" }) -join ','
$t2d = Get-TargetTransferSpec '0=4:10=8' '0=3:10=6' '0=40:10=60' 0 1000
$e2d = Get-FkExpect '0=4:10=8' '0=3:10=6' '0=40:10=60' 11 1000 $min
$t2e = Get-TargetTransferSpec '0=5' '0=0' '0=30' 0 1000
$df2d = @(Get-FkDiff (Get-FkVals $t2d.Spec 11) $e2d)
Chk 'U2c' ($df2c.Count -eq 0 -and $bw2c -eq '0>6,5>6,40>39,41>42,60>61' -and $df2d.Count -eq 0 -and @($t2d.Pooled).Count -eq 11 -and @($t2e.Added).Count -eq 1 -and (Get-FkVal $t2e.Spec 0) -eq 35) "D de forme libre : $($df2c.Count) ecart(s) a la regle ecrite ici, cylindres repris $bw2c ; Sp partout sous 10 ns : facteur moyen $(Format-UiNum $t2d.PoolF '0.00') sur $(@($t2d.Pooled).Count) cylindres ; Sp nul : ecart reporte ($($t2e.Spec)) ; ecarts : $(Get-List (@($df2c) + $df2d))"
# U3 : borne et zero
# rc6 (R15) : X porte a 200 ns a c0 : X + (D - Sp) = 450 ns depasse aussi la borne (avec X = 100 : 350 ns, sous la borne)
$t3a = Get-TargetTransferSpec '0=300' '0=50' '0=200:10=450' 0 $cap
$t3b = Get-TargetTransferSpec '0=0:5=0' '0=5:5=40' '0=3:5=80' 0 $cap
# Relecture B1 : D au-dessus de la borne (mesure) : la courbe ecrite n est jamais ramenee sous D (X/Sp = 2 : 1000 -> D)
$t3c = Get-TargetTransferSpec '0=500:10=420' '0=50' '0=100:10=60' 0 $cap
Chk 'U3' ((Get-FkVal $t3a.Spec 0) -eq $cap -and (Get-FkVal $t3a.Spec 10) -eq 450 -and (Get-FkVal $t3b.Spec 0) -eq 0 -and (Get-FkVal $t3b.Spec 5) -eq 0 -and (Get-FkVal $t3c.Spec 0) -eq 500 -and (Get-FkVal $t3c.Spec 10) -eq 420) "borne max($cap ns, X, D) : X + D - Sp (450 ns) ramene a $cap ns, X deja au-dessus gardee (450 ns), D deja au-dessus gardee (500 ns avec X/Sp = 2 ; 420 ns avec X/Sp = 1,2) ; zero : facteur nul (D 0) sous le seuil (c0, Sp 5) et au-dessus (Sp 40) ramenes a 0 ($($t3a.Spec) ; $($t3b.Spec) ; $($t3c.Spec))"
# U4 : cylindres au-dela de la longueur d une courbe (prolongement par la derniere valeur)
$t4 = Get-TargetTransferSpec '0=22:5=33' '0=20:10=30' '0=40:50=60' 0 $cap
$t4b = Get-TargetTransferSpec '0=22:5=33' '0=20:10=30' '0=40:50=60' 84 $cap
$e4 = Get-FkExpect '0=22:5=33' '0=20:10=30' '0=40:50=60' 84 $cap $min
$df4 = @(Get-FkDiff (Get-FkVals $t4.Spec 84) $e4)
Chk 'U4' ($df4.Count -eq 0 -and @($t4.Values).Count -eq 51 -and @($t4b.Values).Count -eq 84 -and (Get-FkVal $t4.Spec 83) -eq (60 + 33 - 30)) "D de 6 entrees, Sp de 11, X de 51 cylindres : valeurs calculees jusqu a la derniere entree des trois (51 cylindres, 84 demandes), au-dela la derniere valeur (c83 : $(Get-FkVal $t4.Spec 83) ns) ; ecarts : $(Get-List $df4)"
# U5 : tete par tete (Get-TargetTransferPlan) : courbes propres et croisees par tete, facteur par tete ; courbe propre commune
$o0 = @{ Spec = '0=4:2=20:40=60' }; $o1 = @{ Spec = '0=8:2=30:40=90' }; $x0 = @{ Spec = '0=40:40=100' }; $x1 = @{ Spec = '0=50:40=140' }
$twU = @{ Src = 'A'; Tgt = '0'; Fam = 'std'; Own = @($o0, $o1); Curves = @($x0, $x1) }
$wfU = @{ Apply = $true; F0 = 1.2; F1 = 0.8; FMean = 1.0; Hard = $cap; SrcText = @{ 0 = 'k 1,20 mesuré sur cette disquette'; 1 = 'k 0,80 mesuré sur cette disquette' } }
$tdU = @{ P0 = $o0.Spec; P1 = $o1.Spec; Kind = @{ 0 = 'own'; 1 = 'own' } }
$pU = Get-TargetTransferPlan $twU $wfU $tdU $true
$e5a = Get-FkExpect (ConvertTo-ScaledSpec $o0.Spec 1.2 $cap) $o0.Spec $x0.Spec 84 $cap $min
$e5b = Get-FkExpect (ConvertTo-ScaledSpec $o1.Spec 0.8 $cap) $o1.Spec $x1.Spec 84 $cap $min
$twC = @{ Src = 'A'; Tgt = '0'; Fam = 'std'; Own = @($o0); Curves = @($x0, $x1) }
$pC = Get-TargetTransferPlan $twC @{ Apply = $false; Hard = $cap } @{ P0 = $o0.Spec; P1 = $o0.Spec; Kind = @{ 0 = 'own'; 1 = 'own' } } $true
$d5 = @(Get-FkDiff (Get-FkVals $pU.P0 84) $e5a) + @(Get-FkDiff (Get-FkVals $pU.P1 84) $e5b)
Chk 'U5' ($d5.Count -eq 0 -and $pC.P0 -ceq $x0.Spec -and $pC.P1 -ceq $x1.Spec) "ecriture lente : tete 0 = f(1,2 Sp0, Sp0, X0), tete 1 = f(0,8 Sp1, Sp1, X1) ; courbe propre commune, sans facteur : chaque tete recoit sa courbe croisee telle quelle ($($pC.P0) / $($pC.P1)) ; ecarts : $(Get-List $d5)"
# U6 : resume (facteur X/Sp sur les cylindres ou Sp >= 10 ns ; rc5, R13 : cylindres sous le seuil et cylindre repris,
# facteur moyen, ecart reporte)
$s6 = Get-TargetTransferSummary $t2
$r6 = @(for ($c = 3; $c -lt 80; $c++) { (20.0 + 2 * $c) / (4 + 2 * $c) })
$m6 = @($r6 | Sort-Object); $med6 = ($m6[38])
# rc6 (R15) : cylindres ou la hausse est reportee en ns en fin de parenthese (t2 : tous ; t2c : ceux de la regle ecrite
# ici ; t2d : tous ; t2e : aucun, l ecart y est deja reporte en ns)
$ctx = T 'c{0} : besoin de la disquette au-dessus de la courbe du lecteur, hausse reportée en ns'
$w6 = ((T 'facteur de {0} à {1}, médiane {2}') -f (Format-UiNum $m6[0] '0.00'), (Format-UiNum $m6[-1] '0.00'), (Format-UiNum $med6 '0.00')) + ' (' + ((T 'c{0} sous {1} ns : facteur du cylindre c{2} repris') -f '0-2', '10', '3') + ', ' + ($ctx -f '0-79') + ')'
$s6c = (Get-TargetTransferSummary $t2c).Text; $s6d = (Get-TargetTransferSummary $t2d).Text; $s6e = (Get-TargetTransferSummary $t2e).Text
$u6Bad = @()
foreach ($p in @(@($s6c, ('c0-5 sous 10 ns : facteur du cylindre c6 repris, c40 sous 10 ns : facteur du cylindre c39 repris, c41 sous 10 ns : facteur du cylindre c42 repris, c60 sous 10 ns : facteur du cylindre c61 repris, ' + ($ctx -f (Format-CylList ([int[]]$cap2c))) + ')')),
                 @($s6d, ('aucun cylindre où le besoin propre atteint 10 ns (c0-10 sous 10 ns : facteur moyen de la disquette repris (' + (Format-UiNum $t2d.PoolF '0.00') + '), ' + ($ctx -f '0-10') + ')')),
                 @($s6e, 'aucun cylindre où le besoin propre atteint 10 ns (c0 sous 10 ns : écart reporté en ns)'))) { if (-not ([string]$p[0]).EndsWith($p[1], [System.StringComparison]::Ordinal)) { $u6Bad += $p[0] } }
Chk 'U6' ([math]::Abs($s6.Min - ($m6[0])) -lt 1e-9 -and [math]::Abs($s6.Max - ($m6[-1])) -lt 1e-9 -and [math]::Abs($s6.Med - $med6) -lt 1e-9 -and @($s6.Added).Count -eq 0 -and $s6.Text -ceq $w6 -and $u6Bad.Count -eq 0) "resume : $($s6.Text) ; creux, facteur moyen, Sp nul : $(Get-List $u6Bad)"
# U7 (relecture m2) : courbe propre du lecteur qui ecrit posterieure a la courbe croisee : note au journal, courbe ecrite inchangee
$noteD = (T 'courbe du lecteur {0} postérieure à la calibration croisée {0} → {1}') -f 'A', '0'
$tdD = @{ P0 = '0=20:40=60'; P1 = '0=20:40=60'; Kind = @{ 0 = 'own'; 1 = 'own' } }
$pD = @(foreach ($od in '03/11/2026 10:00', '01/11/2026 10:00') { Get-TargetTransferPlan @{ Src = 'A'; Tgt = '0'; Fam = 'std'; Own = @(@{ Spec = '0=20:40=60'; Date = $od }); Curves = @(@{ Spec = '0=40:40=100'; Date = '02/11/2026 10:00' }) } @{ Apply = $false; Hard = $cap } $tdD $false })
Chk 'U7' ($pD[0].Line.Contains($noteD) -and -not $pD[1].Line.Contains($noteD) -and $pD[0].P0 -ceq $pD[1].P0) "courbe propre de A du 03/11 apres la courbe croisee du 02/11 : « $noteD » au journal ; du 01/11 : aucune note ; courbe ecrite identique ($($pD[0].P0))"
# X1 (12.11 rc4, R10) : Excess, par cylindre, courbe ecrite - D : facteur uniforme, borne, zero, D au-dessus de la borne,
# courbes de longueurs differentes, D = Sp (exces = X - Sp) ; meme longueur que Values
$x1Bad = @()
foreach ($p in @(@('facteur 1,5', $t2, $d2), @('borne', $t3a, '0=300'), @('zero', $t3b, '0=0:5=0'), @('D au-dessus de la borne', $t3c, '0=500:10=420'), @('longueurs', $t4b, '0=22:5=33'),
                 @('D = Sp', (Get-TargetTransferSpec '0=4:2=12:40=50:79=90' '0=4:2=12:40=50:79=90' '0=40:30=80:79=150' 0 $cap), '0=4:2=12:40=50:79=90'))) {
    $t = $p[1]; $ex = @($t.Excess); $vv = @($t.Values)
    if ($ex.Count -ne $vv.Count -or $ex.Count -eq 0) { $x1Bad += "$($p[0]) : $($ex.Count) exces pour $($vv.Count) valeurs"; continue }
    $df = @(for ($c = 0; $c -lt $vv.Count; $c++) { if ([int]$ex[$c] -ne [int]$vv[$c] - (Get-FkVal $p[2] $c)) { "c$c $($ex[$c])" } })
    if ($df.Count) { $x1Bad += "$($p[0]) : $(Get-List $df 3)" }
}
# Valeurs relevees sans erreur quand la source testee ne rend pas l exces (source d avant le lot : cas non conforme)
$x1n = @(@($t3b.Excess) | Where-Object { $_ -lt 0 }).Count
$x1v = @(foreach ($p in @(@($t2, 40), @($t3a, 0), @($t3c, 0))) { $ex = @($p[0].Excess); if ($ex.Count -gt $p[1]) { [int]$ex[$p[1]] } else { -9999 } })
Chk 'X1' ($x1Bad.Count -eq 0 -and $x1v[1] -eq ($cap - 300) -and $x1v[2] -eq 0 -and $x1n -eq 0 -and $x1v[0] -eq ([int]$t2.Values[40] - (6 + 3 * 40))) "exces par cylindre = courbe ecrite - D, six jeux (facteur 1,5 a c40 : $($t2.Values[40]) - $(6 + 3 * 40) = $($x1v[0]) ns ; borne : $cap - 300 = $($x1v[1]) ns ; D au-dessus de la borne : $($x1v[2]) ns) ; ecarts : $(Get-List $x1Bad)"

# =====================================================================================================================
'--- A : ecriture « meme lecteur » inchangee (62b8ce2)'
$aBad = @(); $aPrint = @()
foreach ($sc in $scA) {
    $r = $cur[$sc.Id]; $p = Get-FkPrint $r; $aPrint += "$($sc.Id) = '$p'"
    if ($Before) {
        $o = $res['avant'][$sc.Id]
        if ((@($o.Trace) -join "`n") -cne (@($r.Trace) -join "`n")) { $aBad += "$($sc.Id) commandes" }
        if ((@($o.Log) -join "`n") -cne (@($r.Log) -join "`n")) { $aBad += "$($sc.Id) journal" }
    } elseif ($p -ne $fkRef[$sc.Id]) { $aBad += "$($sc.Id) : $p, attendu $($fkRef[$sc.Id])" }
    if (@($r.Trace | Where-Object { $_ -like 'ERREUR*' }).Count) { $aBad += "$($sc.Id) : $(@($r.Trace | Where-Object { $_ -like 'ERREUR*' })[0])" }
}
$aMeas = @(foreach ($id in 'A1', 'A2', 'A3', 'A5', 'A6') { @($cur[$id].Trace | Where-Object { $_ -match '^(calibration rapide|mesure complete|mesure sur l image)' }).Count })
"  empreintes A (source testee) : $($aPrint -join '; ')"
Chk 'A1' ($aBad.Count -eq 0 -and @($aMeas | Where-Object { $_ -ne 1 }).Count -eq 0 -and $cur['A1'].W.Count -eq 2 -and $cur['A5'].W.Count -eq 1) "$($scA.Count) scenarios du meme lecteur (mesure sur l image, test rapide, mesure complete, facteur de marque, ecriture rapide, Bibliotheque), mesures simulees jusqu a l ecriture : commandes gw, demandes et journal identiques a ceux de 62b8ce2 ($(if ($Before) { 'ligne a ligne' } else { 'empreintes' })) ; ecarts : $(Get-List $aBad)"

'--- B : lecteur cible sans mesure'
$bBad = @(); $bPrint = @()
foreach ($sc in $scB) {
    $r = $cur[$sc.Id]; $p = Get-FkPrint $r -TOnly; $bPrint += "$($sc.Id) = '$p'"
    if ($Before) { if ((@($res['avant'][$sc.Id].Trace) -join "`n") -cne (@($r.Trace) -join "`n")) { $bBad += "$($sc.Id) commandes" } }
    elseif ($p -ne $fkRef[$sc.Id]) { $bBad += "$($sc.Id) : $p, attendu $($fkRef[$sc.Id])" }
}
"  empreintes B (source testee) : $($bPrint -join '; ')"
$xs = @{ 0 = [string]$script:DriveCurves['A>0|std_h0'].Spec; 1 = [string]$script:DriveCurves['A>0|std_h1'].Spec; 'r' = [string]$script:DriveCurves['A>0|std'].Spec }
$b1 = $cur['B1']; $b2 = $cur['B2']; $b3 = $cur['B3']
$bX = ($b1.W[0] -ceq $xs[0] -and $b1.W[1] -ceq $xs[1] -and $b2.W['r'] -ceq $xs['r'] -and $b3.W[0] -ceq $xs[0] -and $b3.W[1] -ceq $xs[1] -and $cur['B4'].W[0] -ceq $xs[0])
Chk 'B1' ($bBad.Count -eq 0 -and $bX) "lecteur cible sans mesure, facteur 1 (ecriture lente, rapide, Bibliotheque) et sans courbe propre de A : memes commandes gw qu en 62b8ce2, courbe croisee transmise a la chaine pres ; ecarts : $(Get-List $bBad)"
$l3 = @($b3.Log | Where-Object { $_ -like 'Écriture pour le lecteur cible 0*' })
Chk 'B2' (@($b3.Trace | Where-Object { $_ -match '^(calibration rapide|mesure complete|mesure sur l image)' }).Count -eq 0 -and $l3.Count -eq 1 -and $l3[0] -like '*, facteur 1,00 ; pas de courbe propre du lecteur A pour cette famille : courbe croisée telle quelle.' -and @($b3.Log | Where-Object { $_ -like "Mesure de la disquette avant l'écriture non faite : écriture pour le lecteur cible 0, sans courbe propre du lecteur A*" }).Count -eq 1) "sans courbe propre de A, mesure demandee : aucune mesure, courbe croisee telle quelle, deux lignes qui en donnent la raison"

'--- G : garde (12.11 rc2.1) : courbes chargees qui ne sont pas les courbes propres du lecteur qui ecrit'
# Courbe croisee telle quelle (commandes du scenario B3, rc1), aucune mesure, ligne de journal, case, ligne et infobulle
# qui le disent ; G3 : courbes chargees accordees, decision de la rc2 inchangee (mesure, facteur par cylindre)
$gWhy = 'les courbes chargées ne sont pas celles du lecteur A pour cette famille'
$gBad = @()
foreach ($g in @('G1', 'G2')) {
    $r = $cur[$g]
    if (-not ($r.Tw.Applies -and -not $r.Tw.Xfer -and [string]$r.Tw.ViewWhy -ceq $gWhy)) { $gBad += "$g decision Applies $($r.Tw.Applies) Xfer $($r.Tw.Xfer) « $($r.Tw.ViewWhy) »" }
    $pg = Get-FkPrint $r -TOnly
    if ($pg -ne $fkRef['B3'] -or $r.W[0] -cne $xs[0] -or $r.W[1] -cne $xs[1]) { $gBad += "$g commandes $pg (attendu $($fkRef['B3']), courbes croisees transmises telles quelles)" }
    if (@($r.Trace | Where-Object { $_ -match '^(calibration rapide|mesure complete|mesure sur l image)' }).Count -ne 0) { $gBad += "$g mesure faite" }
    $gl = @($r.Log | Where-Object { $_ -like "Écriture pour le lecteur cible 0 : *, facteur 1,00 ; $gWhy : courbe croisée telle quelle, sans le facteur par cylindre." })
    $gm = @($r.Log | Where-Object { $_ -ceq "Mesure de la disquette avant l'écriture non faite : écriture pour le lecteur cible 0 ($gWhy). Écriture avec la courbe croisée telle quelle." })
    $gx = @($r.Log | Where-Object { $_ -like '*facteur par cylindre de la calibration croisée A → 0 (*' -or $_ -like '*pas de courbe propre*' })
    if ($gl.Count -ne 1 -or $gm.Count -ne 1 -or $gx.Count -ne 0) { $gBad += "$g journal : ligne de l ecriture $($gl.Count), mesure non faite $($gm.Count), formule ou autre raison $($gx.Count)" }
    $segs = @($r.Plan.Segs | ForEach-Object { [string]$_.T })
    # Relecture rc2.1 : ecriture lente avec courbes croisees par tete (B3) : « courbes croisees ... par tete (...) telles
    # quelles » (accord) ; sinon « courbe croisee ... telle quelle »
    $gAgr = if ($r.Slow) { "pour le lecteur cible 0 : courbes croisées A → 0 par tête (*) telles quelles, sans le facteur par cylindre ($gWhy)" } else { "pour le lecteur cible 0 : courbe croisée A → 0 (*) telle quelle, sans le facteur par cylindre ($gWhy)" }
    $sg = @($r.Plan.Segs | Where-Object { [string]$_.T -clike $gAgr -and $_.Crit })
    if ($sg.Count -ne 1 -or $segs -notcontains 'sans mesure de la disquette (lecteur cible 0)' -or @($segs | Where-Object { $_ -like '*× facteur par cylindre*' }).Count -ne 0) { $gBad += "$g ligne : $($segs -join ' ; ')" }
    if ($r.Chk.Enabled -or $r.Chk.Tip -cne "Mesure de la disquette non disponible pour le lecteur cible 0 : $gWhy. L'image est écrite avec la courbe croisée telle quelle, sans le facteur par cylindre.") { $gBad += "$g case active $($r.Chk.Enabled), infobulle « $($r.Chk.Tip) »" }
}
$g3 = $cur['G3']
if (-not ($g3.Tw.Xfer -and -not $g3.Tw.ViewWhy) -or @($g3.Trace | Where-Object { $_ -match '^mesure sur l image' }).Count -ne 1 -or @($g3.Log | Where-Object { $_ -like 'Écriture pour le lecteur cible 0 : courbe de cette disquette (lecteur A, *' }).Count -ne 1) { $gBad += "G3 Xfer $($g3.Tw.Xfer), « $($g3.Tw.ViewWhy) »" }
Chk 'G1' ($gBad.Count -eq 0) "courbes propres de A au magasin, courbes chargees vides (G1) ou d un autre lecteur aux memes valeurs (G2) : aucune formule, courbe croisee telle quelle (commandes de B3), journal, ligne, case et infobulle qui le disent ; accordees (G3) : mesure et facteur par cylindre ; ecarts : $(Get-List $gBad)"

'--- C : lecteur cible avec mesure : formule de la specification, tete par tete, cylindre par cylindre'
$own = @{ 0 = [string]$script:DriveCurves['A|std_h0'].Spec; 1 = [string]$script:DriveCurves['A|std_h1'].Spec; 'r' = [string]$script:DriveCurves['A|std'].Spec }
$cBad = @(); $cInfo = @()
# 12.12 : scenarios ou un facteur met a l echelle la courbe propre (mesure sur l image k 1,10 / 0,95 par tete, facteur de
# marque 1,25) : base et facteur donnes a la regle ; les autres (profil mesure sur cette disquette, sans facteur) : D seul
$fkF = @{ A1 = @{ 0 = 1.10; 1 = 0.95 }; A6 = @{ 0 = 1.10; 1 = 0.95 }; A4 = @{ 0 = 1.25; 1 = 1.25 } }
foreach ($sc in $scA) {
    $cid = 'C' + $sc.Id.Substring(1); $a = $cur[$sc.Id]; $c = $cur[$cid]
    $keys = @($a.W.Keys)
    if ($keys.Count -eq 0 -or @($c.W.Keys).Count -ne $keys.Count) { $cBad += "$cid : tetes ecrites $(@($c.W.Keys) -join ',') / meme lecteur $($keys -join ',')"; continue }
    foreach ($k in $keys) {
        $e = if ($fkF.ContainsKey($sc.Id) -and $null -ne $fkF[$sc.Id][$k]) { Get-FkExpect ([string]$a.W[$k]) $own[$k] $xs[$k] 84 $cap $min $own[$k] ([double]$fkF[$sc.Id][$k]) $cap } else { Get-FkExpect ([string]$a.W[$k]) $own[$k] $xs[$k] 84 $cap $min }
        $df = @(Get-FkDiff (Get-FkVals ([string]$c.W[$k]) 84) $e)
        if ($df.Count) { $cBad += "$cid tete $k : $(Get-List $df 3)" }
        $nAt = @(for ($cy = 0; $cy -lt 84; $cy++) { if ($e[$cy] -eq [math]::Max($cap, [math]::Max((Get-FkVal $xs[$k] $cy), (Get-FkVal $a.W[$k] $cy))) -and $e[$cy] -ne (Get-FkVal $xs[$k] $cy)) { $cy } }).Count
        $cInfo += "$cid/$k : D $(Get-FkVal $a.W[$k] 40) ns a c40 -> $(Get-FkVal $c.W[$k] 40) ns (X $(Get-FkVal $xs[$k] 40), Sp $(Get-FkVal $own[$k] 40))$(if ($nAt) { ", $nAt cyl. a la borne" })"
    }
    if ((@($a.W.Values) -join '|') -ceq (@($c.W.Values) -join '|')) { $cBad += "$cid : meme courbe que le meme lecteur" }
}
"  $($cInfo -join ' ; ')"
$cMeas = @(foreach ($sc in $scA) { $cid = 'C' + $sc.Id.Substring(1); "$cid=" + (@($cur[$cid].Trace | Where-Object { $_ -match '^(calibration rapide|mesure complete|mesure sur l image)' }) -join '+') })
Chk 'C1' ($cBad.Count -eq 0) "$($scA.Count) ecritures pour le lecteur cible 0 (mesure sur l image k 1,10/0,95, test rapide niveau et forme, mesure complete jusqu a +400 ns, facteur de marque 1,25, ecriture rapide, Bibliotheque) : par tete et par cylindre (0 a 83), X x D / Sp (Sp >= 10 ns) ou X + D - Sp, arrondi, borne 0..max($cap ns, X, D), D = courbe ecrite par le meme lecteur dans le scenario A ; ecarts : $(Get-List $cBad)"
Chk 'C2' (@($cMeas | Where-Object { $_ -notmatch '=(calibration rapide|mesure complete|mesure sur l image)' -and $_ -notlike 'C4=*' }).Count -eq 0 -and $cMeas[3] -eq 'C4=') "mesures faites comme pour le meme lecteur : $($cMeas -join ' ; ')"
$c3 = $cur['C3']; $a3 = $cur['A3']
# Relecture B1 (contre-essai CT1) : D au-dessus de la borne aux cylindres 70 a 79 ; borne max($cap, X, D) ; la ou X > Sp
# (le lecteur cible demande plus que le lecteur qui ecrit), jamais ecrit sous la courbe du meme lecteur (scenario A3)
$b3 = @(for ($cy = 0; $cy -lt 84; $cy++) { [math]::Max($cap, [math]::Max((Get-FkVal $xs[0] $cy), (Get-FkVal $a3.W[0] $cy))) })
$nb = @(for ($cy = 0; $cy -lt 84; $cy++) { if ((Get-FkVal $c3.W[0] $cy) -eq $b3[$cy]) { $cy } }).Count
$no = @(for ($cy = 0; $cy -lt 84; $cy++) { if ((Get-FkVal $c3.W[0] $cy) -gt $b3[$cy]) { $cy } }).Count
$un = @(for ($cy = 0; $cy -lt 84; $cy++) { if ((Get-FkVal $xs[0] $cy) -gt (Get-FkVal $own[0] $cy) -and (Get-FkVal $c3.W[0] $cy) -lt (Get-FkVal $a3.W[0] $cy)) { "c$cy" } })
$hi = @(for ($cy = 70; $cy -lt 80; $cy++) { if ((Get-FkVal $a3.W[0] $cy) -gt $cap) { $cy } }).Count
Chk 'C3' ($hi -eq 10 -and $nb -gt 0 -and $no -eq 0 -and $un.Count -eq 0) "mesure complete au-dela de la borne (+400 ns aux cylindres 70 a 79, tete 0 : $hi cylindre(s) de D au-dessus de $cap ns) : $nb cylindre(s) a la borne max($cap ns, X, D), aucun au-dessus ; X > Sp : aucun cylindre ecrit sous la courbe du meme lecteur (c70 : D $(Get-FkVal $a3.W[0] 70) ns -> $(Get-FkVal $c3.W[0] 70) ns) ; ecarts : $(Get-List $un)"

'--- R : ecriture de la restauration pour un lecteur cible'
# Relecture B2 (contre-essai CT2) : Start-PresetWrite 'slow' -NoCalib (appel de Start-RestoreWrite), facteur de marque 1,25 :
# D = ConvertTo-ScaledSpec(Sp, 1,25), courbe ecrite = formule (D, Sp, X) tete par tete ; aucune mesure ; journal qui le dit
$r1 = $cur['R1']; $rBad = @()
foreach ($h in 0, 1) {
    $e = Get-FkExpect (ConvertTo-ScaledSpec $own[$h] 1.25 $cap) $own[$h] $xs[$h] 84 $cap $min $own[$h] 1.25 $cap
    if (-not $r1.W.ContainsKey($h)) { $rBad += "tete $h non ecrite"; continue }
    $df = @(Get-FkDiff (Get-FkVals ([string]$r1.W[$h]) 84) $e)
    if ($df.Count) { $rBad += "tete $h : $(Get-List $df 3)" }
}
$rMeas = @($r1.Trace | Where-Object { $_ -match '^(calibration rapide|mesure complete|mesure sur l image|calibration complete)' -or $_ -like 'ERREUR*' })
$rLog = @($r1.Log | Where-Object { $_.StartsWith('Écriture pour le lecteur cible 0 : courbe de cette disquette (lecteur A, tête 0 : courbe du lecteur × 1,25', [System.StringComparison]::Ordinal) -and $_.Contains('tête 1 : courbe du lecteur × 1,25') })
Chk 'R1' ($rBad.Count -eq 0 -and $rMeas.Count -eq 0 -and $rLog.Count -eq 1) "restauration pour le lecteur cible 0 (Start-PresetWrite 'slow' -NoCalib), facteur de marque 1,25 : par tete et par cylindre, formule appliquee a 1,25 x Sp (c40 tete 0 : X $(Get-FkVal $xs[0] 40) ns -> $(Get-FkVal $r1.W[0] 40) ns) ; aucune mesure ($(Get-List $rMeas)) ; ligne de journal du facteur de marque et du facteur par cylindre : $($rLog.Count) ; ecarts : $(Get-List $rBad)"

'--- X : exces de precompensation memorise avec le controle apres ecriture (12.11 rc4, R10)'
# X2 : vraie Start-ImageWrite : Rep.AsymExcess, par tete, = courbe ecrite pour le lecteur cible - courbe que le meme
# lecteur ecrit dans le scenario A correspondant (D), cylindres 0 a 83 (au-dela du tableau : sa derniere valeur) ;
# ecriture rapide : la meme courbe pour les deux tetes
function Get-FkExcessDiff($rep, $h, [string]$wSpec, [string]$dSpec) {
    # Ecarts un par un dans le pipeline (l appelant les recueille par @()), comme Get-FkDiff
    if (-not $rep -or -not $rep.AsymExcess -or $null -eq $rep.AsymExcess[[int]$h]) { "tete $h : aucun exces memorise"; return }
    $ex = @($rep.AsymExcess[[int]$h])
    for ($cy = 0; $cy -lt 84; $cy++) { $got = [int]$ex[[math]::Min($cy, $ex.Count - 1)]; $want = (Get-FkVal $wSpec $cy) - (Get-FkVal $dSpec $cy); if ($got -ne $want) { "tete $h c$cy $got/$want" } }
}
$x2Bad = @()
foreach ($sc in $scA) {
    $cid = 'C' + $sc.Id.Substring(1); $a = $cur[$sc.Id]; $c = $cur[$cid]
    foreach ($k in @($a.W.Keys)) {
        foreach ($h in $(if ("$k" -eq 'r') { @(0, 1) } else { @([int]$k) })) {
            $df = @(Get-FkExcessDiff $c.Rep $h ([string]$c.W[$k]) ([string]$a.W[$k]))
            if ($df.Count) { $x2Bad += "$cid : $(Get-List $df 3)" }
        }
    }
    if ([string]$c.Rep.Target -cne '0' -or [string]$c.Rep.TargetSrc -cne 'A') { $x2Bad += "$cid : lecteurs du controle « $($c.Rep.TargetSrc) » -> « $($c.Rep.Target) »" }
    if ($a.Rep -and $a.Rep.ContainsKey('AsymExcess')) { $x2Bad += "$($sc.Id) : exces memorise pour le meme lecteur" }
}
foreach ($h in 0, 1) {
    $df = @(Get-FkExcessDiff $cur['R1'].Rep $h ([string]$cur['R1'].W[$h]) (ConvertTo-ScaledSpec $own[$h] 1.25 $cap)); if ($df.Count) { $x2Bad += "R1 : $(Get-List $df 3)" }
    $df = @(Get-FkExcessDiff $cur['B1'].Rep $h ([string]$cur['B1'].W[$h]) $own[$h]); if ($df.Count) { $x2Bad += "B1 : $(Get-List $df 3)" }
}
foreach ($id in 'B3', 'G1', 'G2') { $rp = $cur[$id].Rep; if (-not $rp -or [string]$rp.Target -cne '0' -or $rp.ContainsKey('AsymExcess')) { $x2Bad += "$id : controle absent ou exces memorise sans courbe D connue" } }
# Tableaux releves sans erreur quand la source testee ne memorise rien (source d avant le lot : cas non conforme)
function Get-FkExcess($r, [int]$h) { if ($r -and $r.Rep -and $r.Rep.AsymExcess -and $null -ne $r.Rep.AsymExcess[$h]) { return ,@($r.Rep.AsymExcess[$h]) }; return ,@() }
$exC1 = Get-FkExcess $cur['C1'] 0; $exC5a = Get-FkExcess $cur['C5'] 0; $exC5b = Get-FkExcess $cur['C5'] 1
Chk 'X2' ($x2Bad.Count -eq 0 -and $exC1.Count -ge 80 -and @($exC1 | Where-Object { $_ -gt 0 }).Count -gt 60 -and $exC5a.Count -ge 80 -and ($exC5a -join ',') -ceq ($exC5b -join ',')) "$($scA.Count) ecritures pour le lecteur cible 0, la restauration et l ecriture sans mesure (D = courbe propre) : exces memorise avec le controle = courbe ecrite - courbe du meme lecteur, par tete, cylindres 0 a 83 (C1 tete 0, c40 : $(if ($exC1.Count -gt 40) { $exC1[40] } else { 'absent' }) ns) ; ecriture rapide : une courbe pour les deux tetes ; meme lecteur (A1 a A6), sans courbe propre (B3), courbes chargees vides ou d un autre lecteur (G1, G2) : rien de memorise ; ecarts : $(Get-List $x2Bad)"
# X3 : hswap : la face 0 est ecrite par la tete 1 (profil et exces de la tete 1), la face 1 par la tete 0
$h0 = $cur['H0']; $h1 = $cur['H1']; $x3Bad = @()
foreach ($h in 0, 1) {
    $ph = 1 - $h
    if (-not $h1.W.ContainsKey($h) -or -not $h0.W.ContainsKey($h)) { $x3Bad += "face $h non ecrite"; continue }
    $e = Get-FkExpect (ConvertTo-ScaledSpec $own[$ph] 1.25 $cap) $own[$ph] $xs[$ph] 84 $cap $min $own[$ph] 1.25 $cap
    $df = @(Get-FkDiff (Get-FkVals ([string]$h1.W[$h]) 84) $e); if ($df.Count) { $x3Bad += "face $h, profil de la tete $ph : $(Get-List $df 3)" }
    $df = @(Get-FkExcessDiff $h1.Rep $h ([string]$h1.W[$h]) ([string]$h0.W[$h])); if ($df.Count) { $x3Bad += "face $h, exces : $(Get-List $df 3)" }
}
$exH0 = Get-FkExcess $h1 0; $exH1 = Get-FkExcess $h1 1; $exR1 = Get-FkExcess $cur['R1'] 1
$x3Swap = ($exH0.Count -ge 80 -and ($exH0 -join ',') -cne ($exH1 -join ',') -and ($exH0 -join ',') -ceq ($exR1 -join ','))
Chk 'X3' ($x3Bad.Count -eq 0 -and $x3Swap -and @($h1.Trace | Where-Object { $_ -like 'ERREUR*' }).Count -eq 0) "hswap dans le champ Pistes, facteur de marque 1,25 : chaque face recoit le profil et l exces de la tete qui l ecrit (face 0 : ceux de la tete 1 sans hswap ; c40 : $(if ($exH0.Count -gt 40) { $exH0[40] } else { 'absent' }) ns face 0, $(if ($exH1.Count -gt 40) { $exH1[40] } else { 'absent' }) ns face 1) ; ecarts : $(Get-List $x3Bad)"
# X4 (12.11 rc7, R16) : gain de l asymetrie attendue memorise avec le controle (Rep.AsymGain) : 2 x pente de la mesure sur
# l image qui precede (C1 : pentes fictives 0,815 et 0,765 transmises par WriteFactorNext), repli 1,7 sans pente (facteur de
# marque sans mesure par l asymetrie, calibration rapide, mesure complete) ; ligne de journal ; correction par zones decidee
# par Get-WriteZonePlan (Rep.ZoneFix ; case, controle, 2 passes au moins), segment de la ligne « Ce qui va se passer ».
# Relecture rc7 : borne de la courbe decalee sur une zone (Rep.ZoneHard) = borne de la courbe ecrite, famille standard,
# borne automatique (CalHardNsUser)
function Get-FkGain($r) { if ($r -and $r.Rep -and $r.Rep.AsymGain) { return ('{0}/{1}' -f ([double]$r.Rep.AsymGain[0]).ToString('0.00', [Globalization.CultureInfo]::InvariantCulture), ([double]$r.Rep.AsymGain[1]).ToString('0.00', [Globalization.CultureInfo]::InvariantCulture)) }; return '-' }
$gWant = @{ C1 = '1.63/1.53'; C2 = '1.70/1.70'; C3 = '1.70/1.70'; C4 = '1.70/1.70'; C5 = '1.70/1.70'; C6 = '1.63/1.53' }
$x4Bad = @(foreach ($id in @($gWant.Keys | Sort-Object)) { $gv = Get-FkGain $cur[$id]; if ($gv -cne $gWant[$id] -or $cur[$id].Rep.ZoneFix -isnot [bool] -or $cur[$id].Rep.ZoneFix -or [int]$cur[$id].Rep.ZoneHard -ne [int]$script:CalHardNsUser -or [int]$script:CalHardNsUser -le 0) { "$id : gain $gv, correction par zones $([bool]$cur[$id].Rep.ZoneFix), borne $($cur[$id].Rep.ZoneHard)" } })
foreach ($id in @($scA | ForEach-Object { $_.Id })) { if ($cur[$id].Rep -and ($cur[$id].Rep.ContainsKey('AsymGain') -or $cur[$id].Rep.ContainsKey('ZoneFix') -or $cur[$id].Rep.ContainsKey('ZoneHard'))) { $x4Bad += "$id : gain ou correction par zones pour le meme lecteur" } }
$gLine = "Contrôle après écriture : asymétrie attendue = g × excès de précompensation / cellule ; tête 0 : g = 1,63, deux fois la pente mesurée sur l'image ; tête 1 : g = 1,53, deux fois la pente mesurée sur l'image."
$gLine4 = "Contrôle après écriture : asymétrie attendue = g × excès de précompensation / cellule ; tête 0 : g = 1,70 par défaut, pente non mesurée ; tête 1 : g = 1,70 par défaut, pente non mesurée."
$x4l = (@($cur['C1'].Log) -ccontains $gLine -and @($cur['C4'].Log) -ccontains $gLine4)
$zSeg = "correction des zones écartées de l'attendu, d'après la relecture par le lecteur qui écrit"
$x4p = (@($cur['C1'].Plan.Segs | Where-Object { [string]$_.T -ceq $zSeg }).Count -eq 0 -and @($cur['Z1'].Plan.Segs | Where-Object { [string]$_.T -ceq $zSeg }).Count -eq 1 -and @(1..6 | Where-Object { $cur["Z$_"].Rep.ZoneFix -ne $true -or [int]$cur["Z$_"].Rep.ZoneHard -ne [int]$script:CalHardNsUser }).Count -eq 0 -and $cur['B3'].Plan -and @($cur['B3'].Plan.Segs | Where-Object { [string]$_.T -ceq $zSeg }).Count -eq 0)
$cpOk = @{ Post = $true; Blocker = $null }
$zKeep = $chkWZones.Checked
$chkWZones.Checked = $true; $zp = @((Get-WriteZonePlan $true $cpOk 2).On, (Get-WriteZonePlan $true $cpOk 1).On, (Get-WriteZonePlan $false $cpOk 3).On, (Get-WriteZonePlan $true @{ Post = $false; Blocker = $null } 3).On, (Get-WriteZonePlan $true @{ Post = $true; Blocker = 'secteurs durs' } 3).On)
$chkWZones.Checked = $false; $zp += @((Get-WriteZonePlan $true $cpOk 3).On, (Get-WriteZonePlan $true $cpOk 3).Asked)
$chkWZones.Checked = $zKeep
$x4z = (($zp | ForEach-Object { [int][bool]$_ }) -join '') -ceq '1000000'
# 12.12 : case decochee par defaut (vraie Set-Defaults, Invoke-FkDefaults)
$chkWZones.Checked = $true; Invoke-FkDefaults; $x4d = (-not $chkWZones.Checked)
Chk 'X4' ($x4Bad.Count -eq 0 -and $x4l -and $x4p -and $x4z -and $x4d) "case de la correction par zones decochee par defaut ($x4d) : aucune correction demandee pour C1 a C6, demandee pour Z1 a Z6 (case cochee) et annoncee dans la ligne de Z1 ; gain memorise par tete (vraie Start-ImageWrite) : C1 $(Get-FkGain $cur['C1']) (2 x pentes 0,815 et 0,765), C4 $(Get-FkGain $cur['C4']) (repli) ; aucun pour le meme lecteur ; ecarts : $(Get-List $x4Bad) ; ligne de journal du gain ($x4l) ; segment « correction des zones » de la ligne pour le lecteur cible seulement ($x4p) ; Get-WriteZonePlan : case cochee, 2 passes : oui ; 1 passe, sans facteur par cylindre, sans controle, controle non applicable, case decochee : non ($(($zp | ForEach-Object { [int][bool]$_ }) -join ''))"
# X5 (12.11, version finale) : conseil des zones qui couvrent presque toute une tete, decide au lancement par la vraie
# Start-ImageWrite (Rep.ZoneAdvice) : C1 facteur mesure sur l image (consigne 'mesure' : la mesure a precede) ; C2 Test rapide ;
# C3 mesure complete (case cochee, autre mesure que sur l image) ; C4 facteur de la marque, case decochee ; rien pour le
# meme lecteur
function Get-FkZoneAdv($r) { if ($r -and $r.Rep -and $r.Rep.ZoneAdvice) { $a = $r.Rep.ZoneAdvice; return "$($a.KSrc[0])/$($a.KSrc[1]) $($a.How)" }; return '-' }
# 12.12 : conseil decide seulement quand la correction est demandee (Z1 a Z4, case cochee) ; aucun par defaut (C1 a C4)
$x5Want = [ordered]@{ Z1 = 'mesure/mesure mesure'; Z2 = 'defaut/defaut quickslow'; Z3 = 'defaut/defaut mode'; Z4 = 'lecteur/lecteur slow'; C1 = '-'; C2 = '-'; C3 = '-'; C4 = '-' }
$x5Bad = @(foreach ($id in @($x5Want.Keys)) { $v = Get-FkZoneAdv $cur[$id]; if ($v -cne $x5Want[$id]) { "$id : $v" } })
foreach ($id in @($scA | ForEach-Object { $_.Id })) { if ($cur[$id].Rep -and $cur[$id].Rep.ContainsKey('ZoneAdvice')) { $x5Bad += "$id : conseil des zones pour le meme lecteur" } }
Chk 'X5' ($x5Bad.Count -eq 0) "origine du facteur par tete relue et consigne (vraie Start-ImageWrite) : $(@($x5Want.Keys | ForEach-Object { "$_ $(Get-FkZoneAdv $cur[$_])" }) -join ' ; ') ; ecarts : $(Get-List $x5Bad)"

# =====================================================================================================================
'--- D : phrase, case de la mesure et journal tires de la meme decision'
$segX = (T 'pour le lecteur cible {0} : courbe de cette disquette × facteur par cylindre de la calibration croisée {1} → {0}') -f '0', 'A'
$kt = @{ content = (Get-SettingText 'levelBeforeWriteMode' 'content'); quick = (Get-SettingText 'levelBeforeWriteMode' 'quick'); complete = (Get-SettingText 'levelBeforeWriteMode' 'complete') }
$dBad = @()
foreach ($id in @('C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'B1', 'B2', 'B3', 'B4')) {
    $r = $cur[$id]; $segs = @($r.Plan.Segs | ForEach-Object { [string]$_.T })
    $xfer = ($id -ne 'B3')
    $jl = @($r.Log | Where-Object { $_.StartsWith("Écriture pour le lecteur cible 0 : courbe de cette disquette (lecteur A, ", [System.StringComparison]::Ordinal) })
    if ($r.Side -ne 0) { $dBad += "$id : la phrase a ecrit au journal ou lance une commande" }
    if ($xfer -and ($segs -notcontains $segX -or $jl.Count -ne 1)) { $dBad += "$id : segment « lecteur cible » $($segs -contains $segX), lignes du journal $($jl.Count)" }
    if (-not $xfer -and ($segs -contains $segX -or $jl.Count -ne 0)) { $dBad += "$id : facteur par cylindre annonce sans courbe propre" }
    if (@($segs | Where-Object { $_ -like 'sans mesure de la disquette (lecteur cible*' }).Count -and $xfer) { $dBad += "$id : « sans mesure de la disquette (lecteur cible) » avec la courbe propre" }
    if (@($r.Log | Where-Object { $_ -like '*facteur 1,00.' -or $_ -like 'Facteur de marque non appliqué*' }).Count) { $dBad += "$id : ligne de la rc1" }
    $mPre = (T 'mesure de la disquette : {0}') -f ''
    $ms = @($segs | Where-Object { $_.StartsWith($mPre) }); $want = ''
    if ($ms.Count -eq 1) { foreach ($k in 'content', 'quick', 'complete') { if ($ms[0].StartsWith($mPre + $kt[$k])) { $want = $k } } }
    $meas = @($r.Trace | Where-Object { $_ -match '^(calibration rapide|mesure complete|mesure sur l image)' })
    $got = if ($meas.Count) { switch -Wildcard ($meas[0]) { 'calibration rapide*' { 'quick' } 'mesure complete*' { 'complete' } default { 'content' } } } else { '' }
    if ($want -ne $got) { $dBad += "$id : mesure annoncee « $want », faite « $got »" }
    # Case de la mesure (ecriture lente, liste au test standard ou fin) : active avec la courbe propre, infobulle de la rc2
    if ($r.Slow -and $r.Chk -and $id -notin 'C2', 'C5') {
        $tx = $r.Chk.Tip.StartsWith(((T "Écriture pour le lecteur cible {1} : la disquette est mesurée par le lecteur {0}, celui qui écrit, comme pour une écriture ordinaire ; le facteur de la calibration croisée {0} → {1} est ensuite appliqué à la courbe de cette disquette, cylindre par cylindre.") -f 'A', '0'), [System.StringComparison]::Ordinal)
        if ($xfer -and -not ($r.Chk.Enabled -and $tx)) { $dBad += "$id : case active $($r.Chk.Enabled), infobulle « $($r.Chk.Tip.Split("`n")[0]) »" }
        if (-not $xfer -and ($r.Chk.Enabled -or $tx)) { $dBad += "$id : case active sans courbe propre" }
    }
}
Chk 'D1' ($dBad.Count -eq 0) "10 ecritures pour le lecteur cible : segment « $segX » et ligne de journal « Ecriture pour le lecteur cible 0 : courbe de cette disquette (lecteur A, ...) » ensemble, et seulement avec la courbe propre de A ; mesure annoncee = mesure faite ; case de la mesure et infobulle ; plus de ligne « facteur 1,00 » ni « Facteur de marque non applique » ; ecarts : $(Get-List $dBad)"
# Journal : resume par tete recalcule ici (X/Sp sur les cylindres ou Sp >= 10 ns), cylindres en ecart reporte, origine de D
$jC1 = @($cur['C1'].Log | Where-Object { $_.StartsWith('Écriture pour le lecteur cible 0 : courbe de cette disquette', [System.StringComparison]::Ordinal) })[0]
$jW = @(foreach ($h in 0, 1) {
    $q = @(for ($cy = 0; $cy -lt 80; $cy++) { $s = Get-FkVal $own[$h] $cy; if ($s -ge $min) { (Get-FkVal $xs[$h] $cy) / [double]$s } })
    $qs = @($q | Sort-Object); $md = if ($qs.Count % 2) { $qs[[int][math]::Floor($qs.Count / 2)] } else { ($qs[$qs.Count / 2 - 1] + $qs[$qs.Count / 2]) / 2 }
    # rc5 (R13) : cylindres sous le seuil (c0-1 pour ces courbes), facteur du premier cylindre au-dessus repris
    # 12.12 : plus pour la courbe propre mise a l echelle (C1 : k mesure sur l image), le facteur k y est applique tel quel
    $tp = @()
    # rc6 (R15) : cylindres ou la hausse de la disquette (D = courbe du meme lecteur, scenario A1) est reportee en ns,
    # d apres la regle ecrite ici (Get-FkExpect), sur les cylindres que la fonction calcule (derniere entree des trois + 1)
    $dA1 = [string]$cur['A1'].W[$h]; $nL = 0
    foreach ($s in @($dA1, $own[$h], $xs[$h])) { foreach ($m in [regex]::Matches($s, '(\d+)\s*=\s*(\d+)')) { if ([int]$m.Groups[1].Value -gt $nL) { $nL = [int]$m.Groups[1].Value } } }
    [void](Get-FkExpect $dA1 $own[$h] $xs[$h] ($nL + 1) $cap $min $own[$h] ([double]$fkF['A1'][$h]) $cap)
    if (@($script:FkCapped).Count) { $tp += (T 'c{0} : besoin de la disquette au-dessus de la courbe du lecteur, hausse reportée en ns') -f (Format-CylList ([int[]]@($script:FkCapped))) }
    $tl = if ($tp.Count) { ' (' + ($tp -join ', ') + ')' } else { '' }
    (T 'tête {0} : {1}') -f "$h", (((T 'facteur de {0} à {1}, médiane {2}') -f (Format-UiNum $qs[0] '0.00'), (Format-UiNum $qs[-1] '0.00'), (Format-UiNum $md '0.00')) + $tl)
})
$jWant = 'tête 0 : calibration rapide de cette disquette'
Chk 'D2' ($jC1 -and $jC1.Contains(($jW -join ' ; ')) -and -not $jC1.Contains('repris') -and @($cur['C2'].Log | Where-Object { $_.Contains('c0-1 sous 10 ns : facteur du cylindre c2 repris') }).Count -eq 1 -and -not $jC1.Contains('écart reporté') -and $jC1.Contains('tête 0 : courbe du lecteur × 1,10 (k 1,10 mesuré sur cette disquette), tête 1 : courbe du lecteur × 0,95 (k 0,95 mesuré sur cette disquette)') -and @($cur['C2'].Log | Where-Object { $_.Contains($jWant) }).Count -eq 1 -and @($cur['C3'].Log | Where-Object { $_.Contains('tête 0 : mesure complète de cette disquette') }).Count -eq 1) "journal de l ecriture (C1) : « $jC1 » ; origine de D nommee (mesure sur l image, test rapide, mesure complete)"
# Anglais et texte affiche entier (ligne « Ce qui va se passer », instructions reelles de l onglet)
$dShow = @()
foreach ($lang in 'fr', 'en') {
    $script:Lang = $lang
    foreach ($id in 'A1', 'A2') {
        $sc = @($scA | Where-Object { $_.Id -eq $id })[0]
        Reset-FkState; $txtWFile.Text = $imAdf; $cmbWFmt.SelectedItem = 'amiga.amigados'; Set-FkCurves $true $true; $script:TargetDrives['A'] = '0'; & $sc.Do
        $script:WPlanMemo = $null; Update-WLevelUi
        $seg = (T 'pour le lecteur cible {0} : courbe de cette disquette × facteur par cylindre de la calibration croisée {1} → {0}') -f '0', 'A'
        $sh = (T 'pour le lecteur cible {0} : facteur par cylindre de la calibration croisée') -f '0'
        $txt = [string]$lblWPlan.Text; $tp = [string]$tip.GetToolTip($lblWPlan); $full = [string]$script:WPlanFull
        # Segment critique : affiche entier, ou dans sa forme courte quand la phrase est coupee (texte complet en infobulle)
        $okSeg = $full.Contains($seg) -and ($txt.Contains($seg) -or ($txt.Contains($sh) -and $tp -ceq $full -and $txt.EndsWith('…')))
        $okLang = ($lang -eq 'fr') -or (-not $full.Contains('lecteur cible') -and $full.Contains('target drive 0'))
        $hgt = Get-WPlanHeight $txt
        $dShow += @{ Id = "$lang/$id"; Ok = ($okSeg -and $okLang -and $hgt -le $lblWPlan.Height); T = "$lang/$id $(if ($txt.Contains($seg)) { 'segment entier' } elseif ($txt.Contains($sh)) { 'forme courte' } else { 'segment absent' }) « $txt » ($hgt px)" }
    }
}
$script:Lang = 'fr'
Chk 'D3' (@($dShow | Where-Object { -not $_.Ok }).Count -eq 0) "francais et anglais : segment du lecteur cible (critique) dans le texte affiche, entier ou dans sa forme courte quand la phrase est coupee par segments entiers (texte complet en infobulle) ; texte dans ses trois lignes : $((@($dShow | ForEach-Object { $_.T })) -join ' ; ')"
# Case de la mesure au « Test rapide » sans courbe propre : texte qui remplace celui de la rc1, pas plus large que lui
$wide = 'WWWWWWWWW'
$dW = @()
foreach ($lang in 'fr', 'en') {
    $script:Lang = $lang
    $n = [System.Windows.Forms.TextRenderer]::MeasureText(((T "Mesurer la disquette avant l'écriture : toujours en « Test rapide », sauf pour le lecteur cible {0} (sans courbe du lecteur {1})") -f $wide, $wide), $chkWLevel.Font).Width
    $o = [System.Windows.Forms.TextRenderer]::MeasureText(((T "Mesurer la disquette avant l'écriture : toujours en « Test rapide », sauf pour le lecteur cible {0} (elle relirait avec le lecteur {1})") -f $wide, $wide), $chkWLevel.Font).Width
    $dW += "$lang $n/$o px"
    if ($n -gt $o) { $dW += 'PLUS LARGE' }
}
$script:Lang = 'fr'
Chk 'D4' (@($dW | Where-Object { $_ -eq 'PLUS LARGE' }).Count -eq 0) "case de la mesure, « Test rapide » sans courbe propre : texte au plus aussi large que celui de la rc1 (nom de lecteur le plus large admis) : $($dW -join ' ; ')"
# D5 (relecture B5) : vraie fenetre « Mesure de la disquette sur l image » (vraie Start-ContentMeasure ; Show-AppConfirm
# bouchon qui garde le texte et ferme la fenetre : ecriture annulee) : lecteur cible 0 avec la courbe propre de A,
# paragraphe du facteur par cylindre ; meme lecteur : absent ; anglais
function script:Show-AppConfirm([string]$Title, [string]$Heading, [string]$Text, [string]$Check = '', [string]$GoText = '', [string]$GoGlyph = '', [string]$Level = 'warn', [string]$Picto = 'warn', [string]$AltText = '', $Combo = $null) { [void]$script:FkLog.Add("FENETRE $Text"); $script:ConfirmChoice = $null; return $false }
$d5 = @(); $d5Txt = ''
foreach ($x in @(@{ L = 'fr'; Tg = $true }, @{ L = 'fr'; Tg = $false }, @{ L = 'en'; Tg = $true })) {
    $script:Lang = $x.L
    Reset-FkState; $txtWFile.Text = $imAdf; $cmbWFmt.SelectedItem = 'amiga.amigados'; Set-FkCurves $true $true
    if ($x.Tg) { $script:TargetDrives['A'] = '0' }
    $chkWSlow.Checked = $true; $chkWLevel.Checked = $true; $cmbWLevelMode.SelectedIndex = 0
    $cm = Test-ContentMeasurable $imAdf 'amiga.amigados'
    $script:FkTrace.Clear(); $script:FkLog.Clear()
    try { & $fkRealCm $cm } catch { [void]$script:FkLog.Add("ERREUR $($_.Exception.Message)") }
    $win = @($script:FkLog | Where-Object { $_.StartsWith('FENETRE ') })
    $par = (T "Écriture pour le lecteur cible {1} : la courbe ainsi obtenue (niveau mesuré, ou facteur de la marque avec « Écrire sans mesure ») est ensuite multipliée, cylindre par cylindre, par le facteur de la calibration croisée {0} → {1} ; sans mesure ni facteur de la marque, la courbe croisée est écrite telle quelle.") -f 'A', '0'
    $w = if ($win.Count -eq 1) { $win[0] } else { '' }
    $ok = ($cm.Ok -and $win.Count -eq 1 -and $w.Contains("`n`n" + $par) -eq $x.Tg -and $w.Contains($par) -eq $x.Tg -and ($x.L -eq 'fr' -or -not $w.Contains('lecteur cible')))
    if ($x.L -eq 'fr' -and $x.Tg -and $w.Contains($par)) { $d5Txt = $par.Substring(0, 60) + '…' }
    if (-not $ok) { $d5 += "$($x.L)/$(if ($x.Tg) { 'cible' } else { 'meme lecteur' }) : mesurable $($cm.Ok), fenetres $($win.Count), paragraphe $($w.Contains($par)) $(@($script:FkLog | Where-Object { $_ -like 'ERREUR*' }) -join ' ')" }
}
$script:Lang = 'fr'
Set-FkStubs
Chk 'D5' ($d5.Count -eq 0) "vraie fenetre de la mesure sur l image : paragraphe du facteur par cylindre avec le lecteur cible 0 (francais, anglais), absent pour le meme lecteur : « $d5Txt » ; ecarts : $(Get-List $d5)"

# =====================================================================================================================
'--- E : le lecteur cible n intervient dans aucune mesure ni commande'
$eBad = @()
foreach ($k in @($cur.Keys)) {
    foreach ($t in @($cur[$k].Trace)) {
        if ($t -match '--drive=(\S+)' -and $Matches[1] -ne 'A') { $eBad += "$k : $t" }
        if ($t -match '^(calibration rapide|mesure complete|mesure sur l image)' -and ($t -notmatch 'lecteur A( |$)' -or $t -match 'references .*0')) { $eBad += "$k : $t" }
    }
}
$fnAst = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File)) { foreach ($d in (Get-Ast $f.FullName).FindAll({ param($x) $x -is $tFnA }, $false)) { $fnAst[$d.Name] = $d } }
function Get-FkCalls([string]$fn) { if (-not $fnAst.ContainsKey($fn)) { return ,@('ABSENTE') }; return ,@($fnAst[$fn].Body.FindAll({ param($x) $x -is $tCmdA }, $true) | ForEach-Object { [string]$_.GetCommandName() } | Where-Object { $_ } | Sort-Object -Unique) }
# Relecture B5 : Start-ContentMeasure lit Get-TargetWriteInfo pour le seul texte de sa fenetre (deux lignes : $twc pose,
# puis ajoute au texte de la confirmation $cq) ; aucune autre lecture du lecteur cible dans les fonctions de mesure
$cmL = @()
if ($fnAst.ContainsKey('Start-ContentMeasure')) { $cmL = @(($fnAst['Start-ContentMeasure'].Extent.Text -split "`r?`n") | ForEach-Object { $_.Trim() } | Where-Object { -not $_.StartsWith('#') -and $_ -match '\$twc\b|Get-Target' }) }
$cmOk = ($cmL.Count -eq 2 -and $cmL[0].StartsWith('$twc = Get-TargetWriteInfo ') -and $cmL[1] -match '^if \(\$twc\.Xfer\) \{ \$cq\.Text \+= ' -and [regex]::Matches($cmL[1], 'Get-Target').Count -eq 0)
if (-not $cmOk) { $eBad += "Start-ContentMeasure : lecture du lecteur cible hors du texte de la fenetre ($(Get-List $cmL 3))" }
foreach ($fn in 'Start-LevelBeforeWrite', 'Get-LevelBeforeWritePlan', 'Get-LevelRef', 'Test-ContentMeasurable', 'Start-ContentMeasure', 'Start-LevelCalib', 'Start-DiskMeasure') {
    foreach ($c in (Get-FkCalls $fn)) {
        if ($fn -eq 'Start-ContentMeasure' -and $c -eq 'Get-TargetWriteInfo' -and $cmOk) { continue }
        if ($c -match '^(Get-TargetDrive|Get-TargetWriteInfo|Get-TargetCurves|Get-TargetDFields|Get-TargetTransfer\w*|ABSENTE)$') { $eBad += "$fn : $c" }
    }
}
foreach ($fn in 'Get-TargetTransferSpec', 'Get-TargetTransferSummary', 'Get-TargetDFields', 'Get-TargetTransferPlan') {
    foreach ($c in (Get-FkCalls $fn)) { if ($c -match '^(Append-Log|Show-\w+|Start-\w+|Invoke-\w+|Set-\w+|Save-Config|ABSENTE)$') { $eBad += "$fn : $c" } }
}
Chk 'E1' ($eBad.Count -eq 0) "commandes gw de tous les scenarios sur le lecteur A seul (--drive=A), mesures simulees lancees pour A sur des references de A ; fonctions de mesure sans lecteur cible ni courbe croisee (Start-ContentMeasure : texte de sa fenetre seulement) ; fonctions du facteur par cylindre sans journal, fenetre ni commande (arbre syntaxique) ; ecarts : $(Get-List $eBad)"

# =====================================================================================================================
'--- I : textes, CHANGELOG'
$s019 = [System.IO.File]::ReadAllText((Join-Path $mods '019-i18n-1211.ps1'), [System.Text.Encoding]::UTF8)
$iRc2 = $s019.IndexOf('# --- rc2 :')
$cl = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
$c12 = $cl.Substring(0, [math]::Max(0, $cl.IndexOf('## [12.10]')))
$iBad = @()
foreach ($k in @("Écriture pour le lecteur cible {0} : courbe de cette disquette (lecteur {1}, {2}) × facteur par cylindre de la calibration croisée {1} → {0} ({3}) ; {4}", 'pour le lecteur cible {0} : courbe de cette disquette × facteur par cylindre de la calibration croisée {1} → {0}')) {
    if (-not $script:I18n.ContainsKey($k) -or $iRc2 -lt 0 -or $s019.IndexOf($k, [System.StringComparison]::Ordinal) -lt $iRc2) { $iBad += $k }
}
foreach ($p in @('Écriture pour un lecteur cible avec la mesure de la disquette', 'cylindre par cylindre', "Le lecteur cible n'a pas à être branché", 'validés sur trois disquettes et une paire de lecteurs', 'cette hausse est ajoutée en ns à la courbe croisée')) { if (-not $c12.Contains($p)) { $iBad += "CHANGELOG : $p" } }
Chk 'I1' ($iBad.Count -eq 0) "entrees anglaises dans la section rc2 de 019 ; CHANGELOG 12.11 (Ameliorations, A savoir) ; ecarts : $(Get-List $iBad)"

"=== bilan logic-cible-facteur : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$(if ($script:Fail) { " ; NON CONFORMES : $($script:FailIds -join ', ')" }) ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
