param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.12 (vitesse) : pistes d un SCP analysees en parallele (ScpStats.AnalyzeFile, 030 ; Read-ScpFile, 190).
#  P1  equivalence : sur un fichier SCP ecrit par le test (pistes en double densite, zone instable, intervalles hors
#      classe, piste trop courte, piste hors de la double densite, numeros non contigus, emplacement vide), Read-ScpFile
#      rend exactement ce que rendait la boucle de la 12.11, gardee ici comme reference : chaque champ de chaque tour,
#      le post-traitement de chaque piste et ses metriques, dans les quatre modes (mesure, empreinte, calibration, index
#      simule).
#  P2  fichier a un seul tour, fichier sans piste : memes resultats.
#  P3  fichier tronque : erreur de la piste elle-meme (hors des bornes), jamais celle de la bibliotheque de taches.
#  P4  AnalyzeFile : pistes dans l ordre de la table, numero lu dans l en-tete de piste, deux appels identiques.
#  P5  cablage (statique) : Read-ScpFile appelle AnalyzeFile et plus Decode ni Analyze ; durees des trois analyses au
#      journal sous la garde de la case « Chrono », textes anglais presents.
# Fonctions reelles extraites par l arbre syntaxique, bloc C# ScpStats de 030 copie tel quel ; aucun gw, aucune fenetre.
# Non couvert ici : le gain de temps (il depend du nombre de coeurs du poste) ; l equivalence sur de vraies relectures a
# ete controlee hors depot.
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Set-TestCulture
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mods = Join-Path $Wt 'src\modules'
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
$tFn = [System.Management.Automation.Language.FunctionDefinitionAst]
$tCmd = [System.Management.Automation.Language.CommandAst]
function Get-SpAst([string]$path) {
    $tk = $null; $er = $null
    $a = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message)" }
    return $a
}
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'
$cs = @((Get-SpAst (Join-Path $mods '030-csharp.ps1')).FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'Add-Type' -and $x.Extent.Text -like '*class ScpStats*' }, $true))
if ($cs.Count -ne 1) { throw "statement Add-Type ScpStats : $($cs.Count)" }
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine($cs[0].Extent.Text)
$f190 = @{}
foreach ($fd in (Get-SpAst (Join-Path $mods '190-fn-qualite-alignement.ps1')).FindAll({ param($x) $x -is $tFn }, $false)) {
    $f190[$fd.Name] = $fd
    if ($fd.Name -match '^(Read-Scp|Set-Scp|Get-Scp|Test-Scp|Find-Scp|Get-TrackMetrics$|Get-TrackScore$|Get-HealthLevel$)') { [void]$sb.AppendLine($fd.Extent.Text) }
}
foreach ($st in (Get-SpAst (Join-Path $mods '040-etat-formats.ps1')).EndBlock.Statements) {
    if ($st -is [System.Management.Automation.Language.AssignmentStatementAst] -and ($st.Left.Extent.Text -like '$script:Scp*' -or $st.Left.Extent.Text -eq '$script:ScoreAsymK')) { [void]$sb.AppendLine($st.Extent.Text) }
}
$gen = Join-Path $here 'gen-scp-lecture-parallele.ps1'
[System.IO.File]::WriteAllText($gen, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
$script:RLog = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text, $raw = $false) { $script:RLog.Add($text) }
. $gen
$script:JitterOk = 120.0; $script:JitterWatch = 250.0; $script:HealthErrOk = 2; $script:ScpPostFail = $null

function Read-ScpFileRef([string]$path, [int]$cellsPerRev = 0, [switch]$Finger, [switch]$NoIndexZone) {
    # Reference : boucle de Read-ScpFile jusqu a la 12.11, piste par piste et tour par tour, memes fonctions compilees
    $d = [System.IO.File]::ReadAllBytes($path)
    if ([System.Text.Encoding]::ASCII.GetString($d, 0, 3) -ne 'SCP') { throw 'Fichier SCP invalide' }
    $revs = $d[5]; $res = ($d[11] + 1) * 25
    $zone = (-not $NoIndexZone) -and ((($d[8] -band 1) -eq 1) -or $revs -eq 1)
    $script:ScpPostFail = @{ N = 0; Msg = '' }
    $tracks = @{}
    for ($t = 0; $t -lt 168; $t++) {
        $o = [BitConverter]::ToUInt32($d, 16 + 4 * $t)
        if ($o -eq 0) { continue }
        $tn = $d[$o + 3]; $list = @()
        $fl = New-Object 'System.Collections.Generic.List[int[]]'
        for ($r = 0; $r -lt $revs; $r++) {
            $idx  = [BitConverter]::ToUInt32($d, $o + 4 + 12 * $r)
            $ln   = [BitConverter]::ToUInt32($d, $o + 8 + 12 * $r)
            $doff = [BitConverter]::ToUInt32($d, $o + 12 + 12 * $r)
            $flux = [ScpStats]::Decode($d, [int]($o + $doff), [int]$ln, $res)
            $fl.Add($flux)
            $list += [ScpStats]::Analyze($flux, [double]$idx * $res, $cellsPerRev)
        }
        if ($cellsPerRev -le 0 -and $list.Count -gt 0 -and -not [double]::IsNaN($list[0].Cell) -and $list[0].Cell -ge 1700 -and $list[0].Cell -le 2300) {
            $ins = [ScpStats]::Instability($fl, [double]$list[0].Cell)
            $list[0].Blocks = $ins[0]; $list[0].Unstable = $ins[1]; $list[0].MaxRun = $ins[2]; $list[0].RunPos = $ins[3]
            if ($Finger) { $list[0].Finger = [ScpStats]::Fingerprint($fl[0], [double]$list[0].Cell, 8); $list[0].Rich = [ScpStats]::RichCount($fl[0], [double]$list[0].Cell) }
        }
        if ($cellsPerRev -le 0 -and $list.Count -gt 0) { Set-ScpTrackPost $fl $list $zone }
        $tracks[[int]$tn] = $list
    }
    return $tracks
}

function Format-SpValue($v) {
    # Valeur en texte exact : un double par ses 64 bits, une table par ses cles triees, une liste element par element
    if ($null -eq $v) { return 'nul' }
    if ($v -is [double]) { return [BitConverter]::DoubleToInt64Bits($v).ToString('X16') }
    if ($v -is [string]) { return $v }
    if ($v -is [System.Collections.IDictionary]) { return '{' + ((@($v.Keys | Sort-Object { "$_" }) | ForEach-Object { "$_=" + (Format-SpValue $v[$_]) }) -join ',') + '}' }
    if ($v -is [System.Collections.IEnumerable]) { return '[' + ((@($v) | ForEach-Object { Format-SpValue $_ }) -join ',') + ']' }
    return ([string]$v)
}
function Get-SpDump($tr, [bool]$metrics) {
    # Tout ce que rend une lecture : type de la liste de chaque piste, champs et proprietes ajoutees de chaque tour, metriques
    $o = New-Object System.Text.StringBuilder
    foreach ($tn in @($tr.Keys | Sort-Object)) {
        $list = $tr[$tn]; $r = 0
        [void]$o.AppendLine("T$tn liste $($list.GetType().FullName) $(@($list).Count)")
        foreach ($rv in $list) {
            [void]$o.AppendLine("T$tn r$r " + ((@(foreach ($p in @($rv.PSObject.Properties | Sort-Object Name)) { "$($p.Name)=" + (Format-SpValue $p.Value) })) -join ' '))
            $r++
        }
        if ($metrics) { [void]$o.AppendLine("T$tn metriques " + (Format-SpValue (Get-TrackMetrics $list))) }
    }
    return $o.ToString()
}

# --- fichiers SCP du test ---------------------------------------------------------------------------------------------------
$rnd = New-Object System.Random(20261128)
function New-SpClasses([int]$n) {
    $c = New-Object 'int[]' $n
    for ($i = 0; $i -lt $n; $i++) { $u = $rnd.NextDouble(); $c[$i] = if ($u -lt 0.50) { 2 } elseif ($u -lt 0.85) { 3 } else { 4 } }
    return , $c
}
function ConvertTo-SpRev([int[]]$cls, [double]$cell, [int]$jit) {
    # @{ Flux ; DurNs } : intervalles multiples de 25 ns (resolution du fichier), gigue uniforme de +/- $jit ns
    $f = New-Object 'int[]' $cls.Length; [double]$t = 0
    for ($i = 0; $i -lt $cls.Length; $i++) { $f[$i] = 25 * [int][math]::Round(($cls[$i] * $cell + $rnd.Next(-$jit, $jit + 1)) / 25); $t += $f[$i] }
    return @{ Flux = $f; DurNs = $t }
}
function Write-SpScp([string]$path, $tracks, [int]$revs, [int]$flags, $slots = $null) {
    # SCP minimal : en-tete de 16 octets, table de 168 decalages, par piste « TRK », numero, puis par tour duree (tics de
    # 25 ns), nombre d intervalles et decalage des donnees ; intervalles en mots de 16 bits, poids fort d abord.
    # $slots : emplacement de la table pour un numero de piste (par defaut le numero lui-meme)
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $hd = New-Object 'byte[]' (16 + 4 * 168); $hd[0] = 0x53; $hd[1] = 0x43; $hd[2] = 0x50; $hd[5] = [byte]$revs; $hd[8] = [byte]$flags
    $bw.Write($hd)
    $offs = @{}
    foreach ($tn in @($tracks.Keys | Sort-Object)) {
        $slot = if ($slots -and $slots.ContainsKey($tn)) { [int]$slots[$tn] } else { [int]$tn }
        $offs[$slot] = [int]$ms.Position
        $list = $tracks[$tn]
        $bw.Write([byte[]]@(0x54, 0x52, 0x4B, [byte]$tn))
        [int]$doff = 4 + 12 * $revs
        for ($r = 0; $r -lt $revs; $r++) {
            $f = [int[]]$list[$r].Flux
            $bw.Write([uint32][math]::Round([double]$list[$r].DurNs / 25)); $bw.Write([uint32]$f.Length); $bw.Write([uint32]$doff)
            $doff += 2 * $f.Length
        }
        for ($r = 0; $r -lt $revs; $r++) {
            $f = [int[]]$list[$r].Flux; $b = New-Object 'byte[]' (2 * $f.Length)
            for ($i = 0; $i -lt $f.Length; $i++) { $v = [int]($f[$i] / 25); $b[2 * $i] = [byte]($v -shr 8); $b[2 * $i + 1] = [byte]($v -band 255) }
            $bw.Write($b)
        }
    }
    $bw.Flush(); $d = $ms.ToArray(); $bw.Dispose()
    foreach ($slot in @($offs.Keys)) { [array]::Copy([BitConverter]::GetBytes([uint32]$offs[$slot]), 0, $d, 16 + 4 * $slot, 4) }
    [System.IO.File]::WriteAllBytes($path, $d)
}
$n = 12000
$cA = New-SpClasses $n; $cB = New-SpClasses $n; $cC = New-SpClasses $n
# zone instable : 400 intervalles differents a chaque tour
function New-SpWeak([int[]]$base) { $c = [int[]]$base.Clone(); for ($i = 6000; $i -lt 6400; $i++) { $c[$i] = 2 + $rnd.Next(0, 3) }; return , $c }
# hors classe : au debut du tour (zone de l index) et au milieu, les memes a chaque tour
function New-SpOoc([int[]]$base, [double]$cell) {
    $r = ConvertTo-SpRev $base $cell 120
    foreach ($i in 3, 4, 5, 7000, 7001) { $r.DurNs += (5 * 2000 + 1000 - $r.Flux[$i]); $r.Flux[$i] = 5 * 2000 + 1000 }
    return $r
}
$tracks3 = @{
    0  = @((ConvertTo-SpRev $cA 2000 150), (ConvertTo-SpRev $cA 2006 150), (ConvertTo-SpRev $cA 1996 150))
    1  = @((ConvertTo-SpRev (New-SpWeak $cB) 2000 100), (ConvertTo-SpRev (New-SpWeak $cB) 2000 100), (ConvertTo-SpRev (New-SpWeak $cB) 2000 100))
    5  = @((New-SpOoc $cC 2000), (New-SpOoc $cC 2000), (New-SpOoc $cC 2000))
    7  = @((ConvertTo-SpRev ([int[]]$cA[0..29]) 2000 50), (ConvertTo-SpRev ([int[]]$cA[0..29]) 2000 50), (ConvertTo-SpRev ([int[]]$cA[0..29]) 2000 50))
    9  = @((ConvertTo-SpRev $cB 1100 40), (ConvertTo-SpRev $cB 1100 40), (ConvertTo-SpRev $cB 1100 40))   # cellule estimee a 1 650 ns : hors de la double densite
    12 = @((ConvertTo-SpRev $cC 1890 150), (ConvertTo-SpRev $cC 1890 150), (ConvertTo-SpRev $cC 1890 150))
}
$fA = Join-Path $here 'pistes-3-tours.scp'; Write-SpScp $fA $tracks3 3 0x03
$fB = Join-Path $here 'pistes-1-tour.scp'; Write-SpScp $fB @{ 0 = @($tracks3[0][0]); 5 = @($tracks3[5][0]); 12 = @($tracks3[12][0]) } 1 0x02
$fC = Join-Path $here 'sans-piste.scp'; Write-SpScp $fC @{} 3 0x03
# numeros de piste lus dans l en-tete de piste, et non dans la table : pistes 3 et 2 aux emplacements 20 et 21
$fD = Join-Path $here 'numeros.scp'; Write-SpScp $fD @{ 3 = $tracks3[0]; 2 = $tracks3[12] } 3 0x03 @{ 3 = 20; 2 = 21 }
$dA = [System.IO.File]::ReadAllBytes($fA)
$fT = Join-Path $here 'tronque.scp'; [System.IO.File]::WriteAllBytes($fT, [byte[]]$dA[0..([int]($dA.Length * 0.6))])

'--- P. lecture en parallele'
$modes = [ordered]@{
    'mesure' = @{ New = { Read-ScpFile $args[0] }; Ref = { Read-ScpFileRef $args[0] }; M = $true }
    'empreinte' = @{ New = { Read-ScpFile $args[0] -Finger }; Ref = { Read-ScpFileRef $args[0] -Finger }; M = $true }
    'calibration' = @{ New = { Read-ScpFile $args[0] 24000 }; Ref = { Read-ScpFileRef $args[0] 24000 }; M = $false }
    'index simule' = @{ New = { Read-ScpFile $args[0] -NoIndexZone }; Ref = { Read-ScpFileRef $args[0] -NoIndexZone }; M = $true }
}
$p1 = @(); $p1n = 0; $sizes = @()
foreach ($mn in @($modes.Keys)) {
    $a = Get-SpDump (& $modes[$mn].Ref $fA) $modes[$mn].M; $b = Get-SpDump (& $modes[$mn].New $fA) $modes[$mn].M
    if ($a -cne $b) { $p1 += $mn }
    $p1n += @($a -split "`n").Count; $sizes += $a.Length
}
$dm = Get-SpDump (Read-ScpFile $fA -Finger) $true
$want = [ordered]@{
    'liste en tableau d objets' = 'T0 liste System\.Object\[\] 3'; 'zone instable de la piste 1' = 'T1 r0 [^\r\n]*Unstable=[1-9]'
    'empreinte de la piste 0' = 'T0 r0 [^\r\n]*Finger=\[[^\]]'; 'piste 7 sans cellule' = 'T7 r0 [^\r\n]*Cell=FFF8000000000000'
    'piste 9 hors double densite, sans stabilite' = 'T9 r0 [^\r\n]*Blocks=0 '; 'long track 12 avec stabilite' = 'T12 r0 [^\r\n]*Blocks=[1-9]'
}
$p1v = @(foreach ($k in @($want.Keys)) { if ($dm -notmatch $want[$k]) { $k } })
Chk 'P1' ($p1.Count -eq 0 -and $p1v.Count -eq 0 -and @($sizes | Where-Object { $_ -lt 2000 }).Count -eq 0) "6 pistes, 3 tours, $(@($modes.Keys).Count) modes ($(@($modes.Keys) -join ', ')) : Read-ScpFile rend exactement la reference de la 12.11 ($p1n lignes comparees, doubles compares par leurs 64 bits ; modes en ecart : $(if ($p1.Count) { $p1 -join ', ' } else { 'aucun' })) ; le fichier porte les cas voulus ($(@($want.Keys) -join ', ') ; absents : $(if ($p1v.Count) { $p1v -join ', ' } else { 'aucun' }))"

$p2 = @()
foreach ($f in $fB, $fC, $fD) {
    foreach ($mn in 'mesure', 'empreinte') {
        $a = Get-SpDump (& $modes[$mn].Ref $f) $true; $b = Get-SpDump (& $modes[$mn].New $f) $true
        if ($a -cne $b) { $p2 += "$([System.IO.Path]::GetFileName($f))/$mn" }
    }
}
$tD = Read-ScpFile $fD; $tC = Read-ScpFile $fC; $tB = Read-ScpFile $fB
Chk 'P2' ($p2.Count -eq 0 -and $tC.Count -eq 0 -and (@($tD.Keys | Sort-Object) -join ',') -ceq '2,3' -and (@($tB.Keys | Sort-Object) -join ',') -ceq '0,5,12' -and @($tB[0]).Count -eq 1) "fichier a un tour ($(@($tB.Keys | Sort-Object) -join ',')), fichier sans piste ($($tC.Count) piste), numeros de piste lus dans l en-tete de piste (emplacements 20 et 21 -> pistes $(@($tD.Keys | Sort-Object) -join ',')) : memes resultats que la reference (en ecart : $(if ($p2.Count) { $p2 -join ', ' } else { 'aucun' }))"

$eNew = $null; $eRef = $null
try { $null = Read-ScpFile $fT } catch { $eNew = $_.Exception }
try { $null = Read-ScpFileRef $fT } catch { $eRef = $_.Exception }
function Get-SpInner($e) { while ($e -and $e.InnerException) { $e = $e.InnerException }; return $e }
$iN = Get-SpInner $eNew; $iR = Get-SpInner $eRef
Chk 'P3' ($eNew -and $eRef -and $iN -and $iR -and $iN.GetType().FullName -ceq $iR.GetType().FullName -and $iN.Message -ceq $iR.Message -and $iN -isnot [System.AggregateException]) "fichier tronque : erreur $(if ($iN) { $iN.GetType().Name } else { 'absente' }) « $(if ($iN) { $iN.Message } else { '' }) », la meme que la reference ($(if ($iR) { $iR.GetType().Name } else { 'absente' })), et non l erreur groupee de la bibliotheque de taches"

$af1 = [ScpStats]::AnalyzeFile($dA, 0, $true); $af2 = [ScpStats]::AnalyzeFile($dA, 0, $true)
$ord = (@($af1 | ForEach-Object { $_.Tn }) -join ',')
$same = $true
for ($i = 0; $i -lt $af1.Length; $i++) {
    if ((Format-SpValue $af1[$i].Flux) -cne (Format-SpValue $af2[$i].Flux)) { $same = $false }
    for ($r = 0; $r -lt $af1[$i].Revs.Length; $r++) {
        $x = (@(foreach ($p in @($af1[$i].Revs[$r].PSObject.Properties | Sort-Object Name)) { "$($p.Name)=" + (Format-SpValue $p.Value) }) -join ' ')
        $y = (@(foreach ($p in @($af2[$i].Revs[$r].PSObject.Properties | Sort-Object Name)) { "$($p.Name)=" + (Format-SpValue $p.Value) }) -join ' ')
        if ($x -cne $y) { $same = $false }
    }
}
$afD = [ScpStats]::AnalyzeFile([System.IO.File]::ReadAllBytes($fD), 0, $false)
Chk 'P4' ($ord -ceq '0,1,5,7,9,12' -and $same -and (@($afD | ForEach-Object { $_.Tn }) -join ',') -ceq '3,2' -and $af1[0].Flux.Count -eq 3 -and $af1[0].Revs.Length -eq 3 -and $af1[0].Flux[0].Length -eq $n) "AnalyzeFile : pistes dans l ordre de la table ($ord ; emplacements 20 et 21 : $(@($afD | ForEach-Object { $_.Tn }) -join ',')), trois tours decodes et analyses par piste, deux appels identiques ($same)"

'--- cablage'
$rs = $f190['Read-ScpFile'].Extent.Text
$calls = @($f190['Read-ScpFile'].Body.FindAll({ param($x) $x -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $x.Static }, $true) | ForEach-Object { [string]$_.Member.Extent.Text })
$p5a = ($calls -contains 'AnalyzeFile' -and $calls -notcontains 'Decode' -and $calls -notcontains 'Analyze' -and $calls -notcontains 'Instability' -and $rs.Contains('Set-ScpTrackPost $tk.Flux $list $zone'))
$all = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Where-Object { $_.Name -match '^[1-4]\d\d-fn-' } | Sort-Object Name)) {
    foreach ($fd in (Get-SpAst $f.FullName).FindAll({ param($x) $x -is $tFn }, $false)) { $all[$fd.Name] = $fd.Extent.Text }
}
$tm = [ordered]@{ 'Invoke-WriteCheckAnalysis' = 'analyse des pistes relues au contrôle'; 'Invoke-AlignAnalysis' = 'analyse du flux de la mesure'; 'Invoke-ContentAnalysis' = "analyse d'une passe de la mesure sur l'image" }
$p5b = @(foreach ($fnm in @($tm.Keys)) {
    $t = [string]$all[$fnm]; $k = [string]$tm[$fnm]
    if (-not ($t -match 'if \(\$chkTime -and \$chkTime\.Checked\) \{ Add-UiTiming \(T [''"]' + [regex]::Escape($k) + '[''"]\)') -or -not $script:I18n.ContainsKey($k) -or -not [string]$script:I18n[$k]) { $fnm }
})
$users = @($all.Keys | Where-Object { $all[$_] -match '\[ScpStats\]::AnalyzeFile' } | Sort-Object)
Chk 'P5' ($p5a -and $p5b.Count -eq 0 -and ($users -join ',') -ceq 'Read-ScpFile') "Read-ScpFile appelle AnalyzeFile et plus Decode, Analyze ni Instability ($p5a) ; seule fonction a l appeler : $($users -join ', ') ; durees des trois analyses sous la garde de la case « Chrono », texte anglais present (en defaut : $(if ($p5b.Count) { $p5b -join ', ' } else { 'aucune' }))"

foreach ($p in @($gen, $fA, $fB, $fC, $fD, $fT)) { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force } }
$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-scp-lecture-parallele : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
