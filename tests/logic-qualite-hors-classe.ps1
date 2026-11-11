param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Reads = '', [string]$Before = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-struct-r) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out. Relectures reelles (-Reads) et source d avant (-Before) facultatives :
# sans elles, les cas R1 a R8, C3, C4, C5 et C7 sont sautes ; T7 ne controle la reference que si elle est donnee.
# 12.10 (WP5, S13) : intervalles hors classe reproductibles d un tour a l autre non comptes (Get-ScpStructOoc, Set-ScpTrackPost,
# Get-TrackMetrics ; 190, 040). Code reel : statement Add-Type ScpStats (030) copie tel quel par l arbre syntaxique, fonctions
# Read-ScpFile, Read-ScpTrackFlux, Set-ScpTrackPost, Get-Scp*, Test-Scp*, Find-Scp*, Get-TrackMetrics, Get-HealthLevel (190),
# constantes $script:Scp* (040) ; remplacants : T, Append-Log, seuils de jitter. Cas S : flux synthetiques (int[] en ns) ; cas
# R : relectures reelles si les fichiers existent (sautes sinon). Aucun gw, aucune fenetre.
# Finalisation 12.10 (09/11/2026, v1210\finalisation) : copie adaptee de wp5\logic-1210-struct.ps1, qui la remplace dans la
# campagne. Plafond ScpStructMax (decision S13 du 09/11/2026) et cout de S13 (sortie immediate, recherche dichotomique,
# arret au plafond). Adapte : New-Rev compte OutOfClass comme Analyze (la sortie immediate lit OutOfClass ; l ancien
# remplacant le laissait a 0) ; A1 (ScpStructMax) ; T1 a T3 (cablage du plafond, nouveau texte de la ligne de la mesure).
# Ajoute : S9 a S16 (6 et 7 par tour, deux tours, trous, plus grand des comptes, comptes partiels, StructOver,
# Get-TrackMetrics), R4 a R8 (relectures reelles : raccord-long sans plafond atteint, fort-besoin 79.1, ecriture-ratee
# 65.1 a 69.1, protection 0.1, raccord-c), C1 a C5 (cout : sortie immediate, recherche dichotomique, equivalence a l ancienne boucle sur cas
# aleatoires et sur pistes reelles), T4 a T6 (lignes de journal des pistes au-dela du plafond, cles i18n).
# Relecture de la finalisation (09/11/2026, v1210\finalisation\revue) : copie adaptee de logic-1210-struct-f, qui la
# remplace dans la campagne. Get-ScpStructOoc ne compte plus le premier intervalle du tour 0 (deja retire par S10) :
# reference (boucle lineaire d avant) completee de la meme regle pour C3, C4 et C7 ; ajoutes : S17 (S10 non retire deux
# fois : un hors classe propre au tour 0 reste compte), C8 (sortie immediate avec les bouts de la zone de l index et un
# trou : rien, comme la reference ; meme cas avec un hors classe commun hors des bouts : compte), T7 (cablage de la regle).
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mods = Join-Path $Wt 'src\modules'
# 12.11 : relectures reelles facultatives (aucune dans le depot). -Reads : dossier ou le test cherche, par role :
#   raccord-long.scp   long track ecrite par un lecteur a fort besoin : 1 a 4 hors classe reproductibles par tour
#   fort-besoin.scp    relecture dont la piste 79.1 est ratee (environ 240 erreurs par tour)
#   ecriture-ratee.scp mesure dont les pistes 65.1 a 69.1 sont ratees
#   protection.scp     disquette protegee : 17 hors classe reproductibles par tour sur la piste 0.1
#   raccord-b.scp, raccord-c.scp  disquettes du commerce a raccords d ecriture (1 a 4 par tour)
# Sans -Reads, ou fichier absent : cas sautes (ligne « saute »).
$rd = if ($Reads) { $Reads } else { Join-Path $here 'lectures-absentes' }
$Scp = Join-Path $rd 'raccord-long.scp'; $rdFort = Join-Path $rd 'fort-besoin.scp'; $rdRate = Join-Path $rd 'ecriture-ratee.scp'
$rdProt = Join-Path $rd 'protection.scp'; $rdB = Join-Path $rd 'raccord-b.scp'; $rdC = Join-Path $rd 'raccord-c.scp'
function Get-StAst([string]$path) {
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message) (ligne $(@($er)[0].Extent.StartLineNumber))" }
    return $ast
}
$sb = New-Object System.Text.StringBuilder
$ast = Get-StAst (Join-Path $mods '030-csharp.ps1')
$cmd = @($ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'Add-Type' -and $x.Extent.Text -like '*class ScpStats*' }, $true))
if ($cmd.Count -ne 1) { throw "statement Add-Type ScpStats : $($cmd.Count)" }
[void]$sb.AppendLine($cmd[0].Extent.Text)
$found = @{}
foreach ($fd in (Get-StAst (Join-Path $mods '190-fn-qualite-alignement.ps1')).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
    if ($fd.Name -match '^(Read-Scp|Set-Scp|Get-Scp|Test-Scp|Find-Scp|Get-TrackMetrics$|Get-TrackScore$|Get-HealthLevel$|Get-ScpStructOoc$)') { [void]$sb.AppendLine($fd.Extent.Text); $found[$fd.Name] = $fd.Extent.StartLineNumber }
}
if (-not $found.ContainsKey('Get-ScpStructOoc')) { throw 'Get-ScpStructOoc introuvable' }
foreach ($st in (Get-StAst (Join-Path $mods '040-etat-formats.ps1')).EndBlock.Statements) {
    # 12.11 : $script:ScoreAsymK aussi, poids de l asymetrie que lit Get-TrackScore (2000 en dur jusqu a la 12.10)
    if ($st -is [System.Management.Automation.Language.AssignmentStatementAst] -and ($st.Left.Extent.Text -like '$script:Scp*' -or $st.Left.Extent.Text -eq '$script:ScoreAsymK')) { [void]$sb.AppendLine($st.Extent.Text) }
}
# Reference : boucle lineaire de Get-ScpStructOoc avant la finalisation (HEAD 9249293), renommee. 12.11 : -Before donne
# la racine d une copie de la source d avant (aucune dans le depot)
$refFile = if ($Before) { Join-Path $Before 'src\modules\190-fn-qualite-alignement.ps1' } else { Join-Path $here 'avant-absent\190-fn-qualite-alignement.ps1' }
$refOk = Test-Path -LiteralPath $refFile
if ($refOk) {
    $rf = @((Get-StAst $refFile).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-ScpStructOoc' }, $false))
    $refRule = $rf[0].Extent.Text.Contains('foreach ($p in $xs[$r]) {')
    [void]$sb.AppendLine($rf[0].Extent.Text.Replace('function Get-ScpStructOoc(', 'function Get-ScpStructOocRef(').Replace('foreach ($p in $xs[$r]) {', 'foreach ($p in $xs[$r]) { if ($r -eq 0 -and $p -eq 0) { continue }   # relecture : regle S10'))
}
$gen = Join-Path $here 'gen-1210-struct-r.ps1'
[System.IO.File]::WriteAllText($gen, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
function T([string]$s) { return $s }
$script:RLog = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text) { $script:RLog.Add($text) }
. $gen
$script:JitterOk = 120.0; $script:JitterWatch = 250.0; $script:HealthErrOk = 2; $script:ScpPostFail = $null   # seuils par defaut de l application (040 : JitterStdOk / JitterStdWatch)

$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    if (-not $ok) { $script:Fail++; $script:FailIds += $id }
    '{0,-8} {1,-12} {2}' -f $id, $(if ($ok) { 'conforme' } else { 'NON CONFORME' }), $d
}
"logic-1210-struct-r : $($found.Count) fonctions de 190 (Get-ScpStructOoc 190:$($found['Get-ScpStructOoc'])) ; ScpStructOn $($script:ScpStructOn), ScpStructTol $($script:ScpStructTol), ScpStructMax $($script:ScpStructMax), ScpRevWin $($script:ScpRevWin) ; reference $(if ($refOk) { 'avant/ presente' } else { 'absente (C3, C4 sautes)' }) ; PowerShell $($PSVersionTable.PSVersion)"

"--- A : constantes"
Chk 'A1' ($script:ScpStructOn -eq $true -and $script:ScpStructTol -eq 3 -and $script:ScpStructMax -eq 6) "ScpStructOn $($script:ScpStructOn), ScpStructTol $($script:ScpStructTol), ScpStructMax $($script:ScpStructMax) (6 attendu)"

"--- S : flux synthetiques (cellule 1 900 ns : 2T 3 800, 3T 5 700, 4T 7 600)"
function New-Flux([int]$n, [int]$seed, [int[]]$odd = @(), [int]$oddNs = 2900, [int[]]$holes = @()) {
    # motif deterministe 2T/3T/4T ; $odd : indices recevant un intervalle de $oddNs (hors classe) ; $holes : trous de 25 us
    $f = [int[]]::new($n); $x = $seed
    for ($i = 0; $i -lt $n; $i++) { $x = ($x * 1103515245 + 12345) -band 0x7fffffff; $k = 2 + ($x % 3); $f[$i] = 1900 * $k }
    foreach ($o in $odd) { $f[$o] = $oddNs }
    foreach ($h in $holes) { $f[$h] = 25000 }
    return $f
}
function New-Rev([int[]]$f) {
    # Adapte (finalisation) : OutOfClass compte comme Analyze, hors classe hors trous (Get-ScpStructOoc sort tout de suite
    # quand un tour n en a aucun)
    $c = [ScpStats]::Classes($f, 1900.0); $n = 0
    for ($i = 0; $i -lt $f.Length; $i++) { if ($c[$i] -eq [char]'x' -and $f[$i] -lt 20000) { $n++ } }
    return [pscustomobject]@{ Cell = 1900.0; NFlux = $f.Length; OutOfClass = $n }
}
function Get-St($fls, [int]$skip = 0, [int]$cap = -1) {
    $l = @(foreach ($f in $fls) { New-Rev $f })
    return ((Get-ScpStructOoc $fls $l $skip $cap) -join ',')
}
$f0 = New-Flux 4000 7 @(1000, 2500); $f1 = New-Flux 4000 7 @(1000, 2500); $f2 = New-Flux 4000 7 @(1002, 2500)   # meme position (tol 3)
$st = Get-St @($f0, $f1, $f2)
Chk 'S1' ($st -eq '2,2,2') "deux hors classe reproduits dans les 3 tours (le 2e decale de 2 au tour 3) : $st par tour (2,2,2 attendu)"
$g0 = New-Flux 4000 7 @(1000); $g1 = New-Flux 4000 7 @(1000, 3000); $g2 = New-Flux 4000 7 @(1000)
$st2 = Get-St @($g0, $g1, $g2)
Chk 'S2' ($st2 -eq '1,1,1') "hors classe du seul tour 2 (indice 3000) non reproductible : $st2 (1,1,1 attendu)"
$h0 = New-Flux 4000 7 @(1000); $h1 = New-Flux 4000 7 @(1006); $h2 = New-Flux 4000 7 @(1000)
$st3 = Get-St @($h0, $h1, $h2)
Chk 'S3' ($st3 -eq '0,0,0') "decalage de 6 indices au tour 2, tolerance 3 : rien (0,0,0) : $st3"
$i0 = New-Flux 4000 7 @(1000); $i1 = New-Flux 4003 7 @(1003); $i2 = New-Flux 4000 7 @(1000)   # tour 2 : 3 flux de plus, decalage 3
$st4 = Get-St @($i0, $i1, $i2)
Chk 'S4' ($st4 -eq '1,1,1') "tolerance elargie de l ecart des comptes de flux (3 + 3) : $st4 (1,1,1 attendu)"
$j0 = New-Flux 4000 7 @() 2900 @(1500); $j1 = New-Flux 4000 7 @() 2900 @(1500); $j2 = New-Flux 4000 7 @() 2900 @(1500)
$st5 = Get-St @($j0, $j1, $j2)
Chk 'S5' ($st5 -eq '0,0,0') "trou de 25 us reproductible : pas un hors classe, non retire : $st5"
$st6 = Get-St @($f0, $f1, $f2) 1100
Chk 'S6' ($st6 -eq '1,1,1') "bouts ignores (skip 1100 : indice 1000 exclu, 2500 garde) : $st6 (1,1,1 attendu)"
$st7 = Get-St @(, $f0)
Chk 'S7' ($st7 -eq '0') "un seul tour : rien ($st7)"
$st8 = Get-St @($f0, $f1)
Chk 'S8' ($st8 -eq '2,2') "deux tours : les deux doivent l avoir : $st8"

# Plafond : Set-ScpTrackPost sur des tours analyses par ScpStats.Analyze (cellule 1 900, jitter nul, un index factice :
# tours de 23 ms, ni zone de l index ni tours alignes), $zone faux
function New-Track([int]$nr, [int[]]$odd, [int[]]$holes = @(), [hashtable]$extra = @{}) {
    # $nr tours de 4 000 intervalles, memes hors classe $odd et trous $holes ; $extra : tour -> indices hors classe en plus
    $fl = New-Object 'System.Collections.Generic.List[int[]]'; $list = @()
    for ($r = 0; $r -lt $nr; $r++) {
        $o = @($odd); if ($extra.ContainsKey($r)) { $o += @($extra[$r]) }
        $f = New-Flux 4000 (11 + $r) ([int[]]$o) 2900 $holes
        $tot = [long]0; foreach ($v in $f) { $tot += $v }
        $fl.Add($f); $list += [ScpStats]::Analyze($f, [double]$tot)
    }
    return @{ Fl = $fl; List = $list }
}
function Invoke-Post($t) {
    $before = @($t.List | ForEach-Object { [int]$_.OutOfClass })
    Set-ScpTrackPost $t.Fl $t.List $false
    $p = $t.List[0].PSObject.Properties['Post']
    $m = Get-TrackMetrics $t.List
    return @{ Before = ($before -join ','); After = (@($t.List | ForEach-Object { [int]$_.OutOfClass }) -join ','); Post = $(if ($p) { $p.Value } else { $null }); M = $m }
}
$six = @(300, 800, 1300, 1800, 2300, 2800); $seven = @(300, 800, 1300, 1800, 2300, 2800, 3300)
$p9 = Invoke-Post (New-Track 3 $six)
Chk 'S9' ($p9.Before -eq '6,6,6' -and $p9.After -eq '0,0,0' -and $p9.Post.StructOoc -eq 18 -and $p9.Post.StructOver -eq 0 -and $p9.M.StructOoc -eq 18 -and $p9.M.StructOver -eq 0 -and $p9.M.Ooc -eq 0) "6 par tour (plafond) : retires (OutOfClass $($p9.Before) -> $($p9.After), StructOoc $($p9.Post.StructOoc), StructOver $($p9.Post.StructOver)), erreurs/tour $($p9.M.Ooc)"
$p10 = Invoke-Post (New-Track 3 $seven)
Chk 'S10' ($p10.Before -eq '7,7,7' -and $p10.After -eq '7,7,7' -and $p10.Post.StructOoc -eq 0 -and $p10.Post.StructOver -ge 7 -and $p10.M.StructOver -eq $p10.Post.StructOver -and $p10.M.StructOoc -eq 0 -and $p10.M.Ooc -eq 7) "7 par tour : rien retire (OutOfClass $($p10.Before) -> $($p10.After)), StructOver $($p10.Post.StructOver) (>= 7 : compte arrete au plafond), Get-TrackMetrics : StructOver $($p10.M.StructOver), erreurs/tour $($p10.M.Ooc) (7)"
$p11a = Invoke-Post (New-Track 2 $six); $p11b = Invoke-Post (New-Track 2 $seven)
Chk 'S11' ($p11a.After -eq '0,0' -and $p11a.Post.StructOoc -eq 12 -and $p11b.After -eq '7,7' -and $p11b.Post.StructOver -ge 7 -and $p11b.Post.StructOoc -eq 0) "deux tours : 6 par tour retires ($($p11a.Before) -> $($p11a.After)) ; 7 par tour comptes ($($p11b.Before) -> $($p11b.After), StructOver $($p11b.Post.StructOver))"
$p12 = Invoke-Post (New-Track 3 $six @(500, 1500, 2600))
Chk 'S12' ($p12.Before -eq '6,6,6' -and $p12.After -eq '0,0,0' -and $p12.M.Dr -eq 3 -and $p12.Post.StructOver -eq 0) "6 hors classe et 3 trous reproductibles par tour : trous hors plafond et toujours comptes (trous/tour $($p12.M.Dr)), hors classe retires ($($p12.Before) -> $($p12.After))"
$p13 = Invoke-Post (New-Track 3 $six @() @{ 0 = @(2802) })
Chk 'S13' ($p13.Before -eq '7,6,6' -and $p13.After -eq '7,6,6' -and $p13.Post.StructOver -ge 7 -and $p13.Post.StructOoc -eq 0) "tour 0 : 7 (2800 et 2802 voisins du 2800 des autres tours), tours 1 et 2 : 6 : le plus grand des comptes depasse, rien retire ($($p13.Before) -> $($p13.After), StructOver $($p13.Post.StructOver))"
$t14 = New-Track 3 @(200, 500, 800, 1100, 1400, 1700, 2000, 2300, 2600, 2900)
$full14 = (Get-ScpStructOoc $t14.Fl $t14.List 0 -1) -join ','; $cap14 = (Get-ScpStructOoc $t14.Fl $t14.List 0 6) -join ','
$p14 = Invoke-Post $t14
Chk 'S14' ($full14 -eq '10,10,10' -and $cap14 -eq '7,0,0' -and $p14.Post.StructOver -eq 7 -and $p14.After -eq '10,10,10') "10 par tour : sans plafond $full14 ; plafond 6 : arret au 7e du tour 0 ($cap14) ; StructOver $($p14.Post.StructOver) = minorant (ScpStructMax + 1), OutOfClass inchange ($($p14.After))"
$t15 = New-Track 3 $seven
$script:ScpStructMax = 7; $p15 = Invoke-Post $t15; $script:ScpStructMax = 6
Chk 'S15' ($p15.After -eq '0,0,0' -and $p15.Post.StructOoc -eq 21 -and $p15.Post.StructOver -eq 0) "plafond lu dans ScpStructMax (7 le temps du cas) : 7 par tour retires ($($p15.Before) -> $($p15.After))"
$t16 = New-Track 3 $seven
$script:ScpStructOn = $false; $p16 = Invoke-Post $t16; $script:ScpStructOn = $true
Chk 'S16' ($p16.After -eq '7,7,7' -and $p16.Post.StructOoc -eq 0 -and $p16.Post.StructOver -eq 0 -and $p16.M.StructOver -eq 0) "ScpStructOn faux : ni retrait ni signalement (StructOver $($p16.Post.StructOver))"

# Relecture : premier intervalle du tour 0 jamais compte par S13 (S10 l a deja retire, meme critere) ; hors classe en 0
# dans les 3 tours et un hors classe du seul tour 0 en 3 000 : celui-ci reste compte (avant : le premier intervalle etait
# retire deux fois au tour 0 et le masquait)
$t17 = New-Track 3 @(0) @() @{ 0 = @(3000) }
$st17 = (Get-ScpStructOoc $t17.Fl $t17.List 0 6) -join ','
$p17 = Invoke-Post $t17
Chk 'S17' ($st17 -eq '0,1,1' -and $p17.Before -eq '2,1,1' -and $p17.After -eq '1,0,0' -and $p17.Post.First -eq 'ooc' -and $p17.Post.StructOoc -eq 2 -and $p17.Post.StructOver -eq 0 -and $p17.M.StructOoc -eq 2) "S10 et S13 : premier intervalle du tour 0 retire une fois (First $($p17.Post.First)), S13 $st17 (0,1,1 attendu), OutOfClass $($p17.Before) -> $($p17.After) (1,0,0 attendu : le hors classe en 3000 du tour 0 reste compte), StructOoc $($p17.Post.StructOoc)"

"--- C : cout de S13 (sortie immediate, recherche dichotomique, arret au plafond)"
# Sortie immediate avant tout calcul de classes : un tour qui ne serait pas un flux (ScpStats.Classes echouerait) ou une
# cellule illisible (conversion en double impossible) ne sont jamais lus
$c0 = New-Flux 4000 7 @(1000, 2500); $c1 = New-Flux 4000 7 @(); $c2 = New-Flux 4000 7 @(1000, 2500)
$stc = Get-St @($c0, $c1, $c2)
$e1 = ''; try { $stc1 = (Get-ScpStructOoc @($c0, 'pas un flux', $c2) @((New-Rev $c0), [pscustomobject]@{ Cell = 'x'; NFlux = 4000; OutOfClass = 0 }, (New-Rev $c2)) 0 6) -join ',' } catch { $e1 = $_.Exception.Message }
$e2 = ''; try { [void](Get-ScpStructOoc @($c0, $c0) @([pscustomobject]@{ Cell = 'x'; OutOfClass = 2 }, [pscustomobject]@{ Cell = 'x'; OutOfClass = 2 }) 0 6) } catch { $e2 = 'erreur attendue' }
Chk 'C1' ($stc -eq '0,0,0' -and -not $e1 -and $stc1 -eq '0,0,0' -and $e2) "sortie immediate : tour 2 sans hors classe -> $stc ; tour non lisible jamais classe ($(if ($e1) { $e1 } else { $stc1 })) ; temoin : classes calculees quand chaque tour en a ($e2)"
$fnText = (@((Get-StAst (Join-Path $mods '190-fn-qualite-alignement.ps1')).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-ScpStructOoc' }, $false)))[0].Extent.Text
Chk 'C2' ($fnText.Contains('[System.Array]::BinarySearch($a, [int]($p - $t))') -and -not $fnText.Contains('foreach ($p2 in') -and $fnText.Contains('$xs[$r] = $ix.ToArray()') -and $fnText.Contains('$nx = [int]$list[$r].OutOfClass') -and $fnText.Contains('if ($nx -le 0) { return $out }') -and $fnText.Contains('if ($cap -ge 0 -and $out[$r] -gt $cap) { return $out }') -and $fnText.Contains('$s = [ScpStats]::Classes($f, [double]$list[$r].Cell)') -and -not $fnText.Contains('New-Object System.Collections.Generic.List')) "Get-ScpStructOoc : int[] croissants, Array.BinarySearch (plus de boucle sur les indices de l autre tour), sortie immediate (bouts deduits), arret au plafond, classes par appel direct"
if ($refOk) {
    # Cas aleatoires : 2 ou 3 tours, longueurs 3 990 a 4 010, hors classe communs decales de 0 a 6, propres a un tour,
    # trous, skip 0 ou 150 : comptes identiques a la boucle lineaire d avant (sans plafond)
    $rnd = New-Object System.Random 1210; $nDiff = 0; $nCase = 300; $nNz = 0; $firstDiff = ''
    for ($c = 0; $c -lt $nCase; $c++) {
        $nr = 2 + $rnd.Next(2); $nc = $rnd.Next(0, 12); $common = @(for ($k = 0; $k -lt $nc; $k++) { 20 + $rnd.Next(3900) })
        $fls = @(); $ls = @()
        for ($r = 0; $r -lt $nr; $r++) {
            $len = 3990 + $rnd.Next(21); $no = $rnd.Next(0, 6); $nh = $rnd.Next(0, 3)
            $o = @($common | ForEach-Object { [math]::Min($len - 1, $_ + $rnd.Next(7)) }) + @(for ($k = 0; $k -lt $no; $k++) { $rnd.Next($len) })
            $h = @(for ($k = 0; $k -lt $nh; $k++) { $rnd.Next($len) })
            $f = New-Flux $len (100 + $c) ([int[]]$o) (2900 + 100 * $rnd.Next(2)) ([int[]]$h)
            $fls += , $f; $ls += New-Rev $f
        }
        $sk = if ($rnd.Next(2) -eq 0) { 0 } else { 150 }
        $a = (Get-ScpStructOoc $fls $ls $sk -1) -join ','; $b = (Get-ScpStructOoc $fls $ls $sk) -join ','; $ref = (Get-ScpStructOocRef $fls $ls $sk) -join ','
        if ($a -ne $ref -or $b -ne $ref) { $nDiff++; if (-not $firstDiff) { $firstDiff = "cas $c : $a / $b / ref $ref" } }
        if ($ref -match '[1-9]') { $nNz++ }
    }
    Chk 'C3' ($nDiff -eq 0 -and $nNz -ge 100) "$nCase cas aleatoires : $nDiff difference(s) avec la boucle lineaire d avant ($nNz cas avec des reproductibles)$(if ($firstDiff) { ' ; ' + $firstDiff })"
    # Pistes reelles : comptes sans plafond identiques a la reference, skip 0 et 2 048 (zone de l index)
    $reals = @(@{ P = $Scp; T = @(0..159) }, @{ P = $rdFort; T = @(140..159) }, @{ P = $rdProt; T = @(0..9) })
    $nT = 0; $nD = 0; $nSum = 0; $fd = ''; $swr = [System.Diagnostics.Stopwatch]::StartNew(); $tNew = 0.0; $tRef = 0.0
    foreach ($re in $reals) {
        if (-not (Test-Path -LiteralPath $re.P)) { continue }
        foreach ($tn in $re.T) {
            $fl = Read-ScpTrackFlux $re.P $tn
            if ($fl.Count -lt 2) { continue }
            $ls = @(foreach ($f in $fl) { [ScpStats]::Analyze($f, 0.0) })
            if (@($ls | Where-Object { [double]::IsNaN([double]$_.Jitter) }).Count) { continue }
            foreach ($sk in 0, 2048) {
                $s1 = [System.Diagnostics.Stopwatch]::StartNew(); $a = (Get-ScpStructOoc $fl $ls $sk -1) -join ','; $tNew += $s1.Elapsed.TotalMilliseconds
                $s1 = [System.Diagnostics.Stopwatch]::StartNew(); $ref = (Get-ScpStructOocRef $fl $ls $sk) -join ','; $tRef += $s1.Elapsed.TotalMilliseconds
                $nT++; if ($a -ne $ref) { $nD++; if (-not $fd) { $fd = "$([System.IO.Path]::GetFileName($re.P)) t$tn skip $sk : $a / ref $ref" } }
                $nSum += (@($ref -split ',') | ForEach-Object { [int]$_ } | Measure-Object -Sum).Sum
            }
        }
    }
    if ($nT -gt 0) { Chk 'C4' ($nD -eq 0) "$nT comparaisons sur pistes reelles (raccord-long, fort-besoin 70.0 a 79.1, protection 0.0 a 4.1 ; skip 0 et 2 048) : $nD difference(s), $nSum reproductibles ; Get-ScpStructOoc $([int]$tNew) ms, boucle lineaire $([int]$tRef) ms$(if ($fd) { ' ; ' + $fd })" }
    else { "  fichiers reels absents : C4 saute" }
} else { "  reference avant/ absente : C3 et C4 sautes" }
# Arret au plafond sur une piste reelle : fort-besoin 79.1, comptes partiels
$p79 = $rdFort
if (Test-Path -LiteralPath $p79) {
    $fl = Read-ScpTrackFlux $p79 159; $ls = @(foreach ($f in $fl) { [ScpStats]::Analyze($f, 0.0) })
    $s1 = [System.Diagnostics.Stopwatch]::StartNew(); $full = Get-ScpStructOoc $fl $ls 0 -1; $tf = $s1.Elapsed.TotalMilliseconds
    $s1 = [System.Diagnostics.Stopwatch]::StartNew(); $part = Get-ScpStructOoc $fl $ls 0 6; $tp = $s1.Elapsed.TotalMilliseconds
    Chk 'C5' (($part -join ',') -eq '7,0,0' -and [int]$full[0] -ge 200) "fort-besoin 79.1 : sans plafond $($full -join ',') ($([int]$tf) ms) ; plafond 6 : $($part -join ',') ($([int]$tp) ms)"
} else { "  fort-besoin absente : C5 saute" }
# Bouts deduits : hors classe des bouts comptes sur les classes des bouts (Get-ScpEdgeOoc) egaux au compte direct, et
# comptes de Get-ScpStructOoc avec les bouts identiques a la reference (pistes reelles, zone de l index : skip ScpRevWin)
function Get-EdgeOocBrut($f, [double]$cell, [int]$skip) {
    $s = [ScpStats]::Classes($f, $cell); $n = $f.Length; $k = 0
    for ($i = 0; $i -lt $n; $i++) { if (($i -lt $skip -or $i -ge [math]::Max($skip, $n - $skip)) -and $s[$i] -eq [char]'x' -and $f[$i] -lt 20000) { $k++ } }
    return $k
}
$skw = [int]$script:ScpRevWin; $nE = 0; $nEd = 0; $fe = ''
foreach ($len in 600, 3000, 4200, 9000) {
    foreach ($r in 0, 1) {
        $odd = @(@(0, 5, 2047, 2048, 4095, 4096, ($len - 4097), ($len - 2049), ($len - 2048), ($len - 1)) | ForEach-Object { [math]::Max(0, [math]::Min($len - 1, $_)) })
        $f = New-Flux $len (40 + $len) ([int[]]$odd) 2900 @(1, ($len - 2))
        $e = Get-ScpEdgeClasses $f 1900.0 $(if ($r -eq 0) { [int]$script:ScpPostWin } else { $skw })
        $a = Get-ScpEdgeOoc $f $e $skw; $b = Get-EdgeOocBrut $f 1900.0 $skw; $nE++
        if ($a -ne $b) { $nEd++; if (-not $fe) { $fe = "n $len tour $r : $a / $b" } }
    }
}
Chk 'C6' ($nEd -eq 0) "Get-ScpEdgeOoc : $nE tours synthetiques (600 a 9 000 intervalles, tour 0 a ScpPostWin, autres a ScpRevWin, hors classe aux limites, trous) : $nEd difference(s) avec le compte direct$(if ($fe) { ' ; ' + $fe })"
if ($refOk) {
    $nT = 0; $nD = 0; $nX = 0; $nB = 0; $fd = ''
    foreach ($re in @(@{ P = $Scp; T = @(0..159) }, @{ P = $rdB; T = @(0..159) }, @{ P = $rdFort; T = @(140..159) })) {
        if (-not (Test-Path -LiteralPath $re.P)) { continue }
        foreach ($tn in $re.T) {
            $fl = Read-ScpTrackFlux $re.P $tn
            if ($fl.Count -lt 2) { continue }
            $ls = @(foreach ($f in $fl) { [ScpStats]::Analyze($f, 0.0) })
            if (@($ls | Where-Object { [double]::IsNaN([double]$_.Jitter) }).Count) { continue }
            $ed = @(for ($r = 0; $r -lt $fl.Count; $r++) { , (Get-ScpEdgeClasses $fl[$r] ([double]$ls[$r].Cell) $(if ($r -eq 0) { [int]$script:ScpPostWin } else { $skw })) })
            foreach ($r in 0..($fl.Count - 1)) { if ((Get-ScpEdgeOoc $fl[$r] $ed[$r] $skw) -ne (Get-EdgeOocBrut $fl[$r] ([double]$ls[$r].Cell) $skw)) { $nB++ } }
            $a = (Get-ScpStructOoc $fl $ls $skw -1 $ed) -join ','; $ref = (Get-ScpStructOocRef $fl $ls $skw) -join ','
            $nT++; if ($a -ne $ref) { $nD++; if (-not $fd) { $fd = "$([System.IO.Path]::GetFileName($re.P)) t$tn : $a / ref $ref" } }
            $mid = $true
            for ($r = 0; $r -lt $fl.Count; $r++) { if ([int]$ls[$r].OutOfClass - (Get-ScpEdgeOoc $fl[$r] $ed[$r] $skw) -le 0) { $mid = $false } }
            if (-not $mid) { $nX++ }
        }
    }
    if ($nT -gt 0) { Chk 'C7' ($nD -eq 0 -and $nB -eq 0 -and $nX -ge 100) "$nT pistes reelles (raccord-long, raccord-b, fort-besoin 70.0 a 79.1), skip $skw avec les classes des bouts : $nD difference(s) avec la boucle lineaire, $nB compte(s) des bouts faux ; sortie immediate sur $nX pistes (aucun hors classe hors des bouts dans un tour)$(if ($fd) { ' ; ' + $fd })" }
    else { "  fichiers reels absents : C7 saute" }
} else { "  reference avant/ absente : C7 sautee" }

# Relecture : sortie immediate avec les bouts de la zone de l index (skip ScpRevWin, classes des bouts) : tour 1 dont les
# seuls hors classe sont dans les bouts ignores (100 et 8 950) et un trou en 5 000 ; tours 0 et 2 : hors classe en 5 000
# -> rien ; meme cas avec un hors classe en 5 001 au tour 1 -> un par tour ; reference identique dans les deux cas
function New-EdgeCase([int[]]$odd1, [int[]]$holes1) {
    $fls = @(); $ls = @(); $eds = @()
    for ($r = 0; $r -lt 3; $r++) {
        $o = if ($r -eq 1) { $odd1 } else { @(5000) }
        $h = if ($r -eq 1) { $holes1 } else { @() }
        $f = New-Flux 9000 (60 + $r) ([int[]]$o) 2900 ([int[]]$h)
        $fls += , $f; $ls += New-Rev $f
        $eds += , (Get-ScpEdgeClasses $f 1900.0 $(if ($r -eq 0) { [int]$script:ScpPostWin } else { [int]$script:ScpRevWin }))
    }
    return @{ Fl = $fls; L = $ls; E = $eds }
}
$sk8 = [int]$script:ScpRevWin
$e8a = New-EdgeCase @(100, 8950) @(5000); $e8b = New-EdgeCase @(100, 8950, 5001) @()
$a8 = (Get-ScpStructOoc $e8a.Fl $e8a.L $sk8 6 $e8a.E) -join ','; $b8 = (Get-ScpStructOoc $e8b.Fl $e8b.L $sk8 6 $e8b.E) -join ','
$ra8 = if ($refOk) { (Get-ScpStructOocRef $e8a.Fl $e8a.L $sk8) -join ',' } else { '0,0,0' }
$rb8 = if ($refOk) { (Get-ScpStructOocRef $e8b.Fl $e8b.L $sk8) -join ',' } else { '1,1,1' }
$eo8 = Get-ScpEdgeOoc $e8a.Fl[1] $e8a.E[1] $sk8
Chk 'C8' ($a8 -eq '0,0,0' -and $ra8 -eq '0,0,0' -and $b8 -eq '1,1,1' -and $rb8 -eq '1,1,1' -and [int]$e8a.L[1].OutOfClass -eq 2 -and $eo8 -eq 2 -and [int]$e8a.L[1].NFlux -eq 9000) "sortie immediate, bouts ignores et trou : tour 1 OutOfClass $($e8a.L[1].OutOfClass), dont $eo8 dans les bouts -> $a8 (reference $ra8) ; hors classe commun hors des bouts -> $b8 (reference $rb8)"

"--- R : relectures reelles"
if (Test-Path -LiteralPath $Scp) {
    $tr = Read-ScpFile $Scp
    $m80 = Get-TrackMetrics $tr[80]; $m158 = Get-TrackMetrics $tr[158]; $m159 = Get-TrackMetrics $tr[159]
    Chk 'R1' ($m80.StructOoc -eq 3 -and $m80.Ooc -le 0.34) "c40.0 : StructOoc $($m80.StructOoc) (3 attendu : un par tour), erreurs/tour apres retrait $('{0:0.00}' -f $m80.Ooc)"
    Chk 'R2' ($m158.StructOoc -ge 3 -and $m158.Ooc -le 0.34 -and $m159.StructOoc -ge 3) "c79.0 : StructOoc $($m158.StructOoc), erreurs $('{0:0.00}' -f $m158.Ooc) ; c79.1 : StructOoc $($m159.StructOoc), erreurs $('{0:0.00}' -f $m159.Ooc)"
    $n = 0; $nSt = 0; $sumOoc = 0.0; $sumSt = 0; $watch = 0; $nOver = 0
    foreach ($tn in @($tr.Keys)) { $m = Get-TrackMetrics $tr[$tn]; if ($m.Bad) { continue }; $n++; $sumOoc += $m.Ooc; $sumSt += $m.StructOoc; if ($m.StructOoc -gt 0) { $nSt++ }; if ($m.StructOver -gt 0) { $nOver++ }; if ($m.Level -ge 1) { $watch++ } }
    Chk 'R3' ($n -ge 150 -and $nSt -ge 100 -and ($sumOoc / $n) -lt 0.5 -and $watch -le 10) "$n pistes : hors classe reproductibles retires sur $nSt pistes ($sumSt au total), erreurs/tour moyennes restantes $('{0:0.00}' -f ($sumOoc / $n)) (< 0,5 attendu ; 1,1 avant), pistes non SAINES $watch (<= 10 attendu aux seuils par defaut ; 30 reecrites le 02/11)"
    Chk 'R4' ($nOver -eq 0) "raccord-long (long track ecrite par un lecteur a fort besoin, 1 a 4 par tour) : aucune piste au-dela du plafond ($nOver), toutes les pistes de raccord retirees"
} else { "  raccord-long absente : R1 a R4 sautes" }
function Get-Real([string]$p) { if (Test-Path -LiteralPath $p) { return (Read-ScpFile $p) } else { return $null } }
$t4 = Get-Real $p79
if ($t4) {
    $m = Get-TrackMetrics $t4[159]
    Chk 'R5' ($m.StructOoc -eq 0 -and $m.StructOver -gt 0 -and $m.Ooc -ge 200 -and $m.Ooc -le 280 -and $m.Level -eq 2) "fort-besoin 79.1 (tn 159) : rien retire (StructOoc $($m.StructOoc)), StructOver $($m.StructOver), erreurs/tour $('{0:0.00}' -f $m.Ooc) (environ 240), niveau $($m.Level) (2)"
} else { "  fort-besoin absente : R5 saute" }
$tp4 = Get-Real $rdRate
if ($tp4) {
    $bad = @(); $txt = @()
    foreach ($c in 65..69) { $tn = 2 * $c + 1; $m = Get-TrackMetrics $tp4[$tn]; $txt += "$c.1 : $('{0:0}' -f $m.Ooc)/tour, StructOver $($m.StructOver)"; if ($m.StructOoc -ne 0 -or $m.StructOver -le 0) { $bad += "$c.1" } }
    Chk 'R6' ($bad.Count -eq 0) "ecriture-ratee, 65.1 a 69.1 : rien retire, toutes signalees ($($txt -join ' ; '))"
} else { "  ecriture-ratee absente : R6 saute" }
$tl = Get-Real $rdProt
if ($tl) {
    $m = Get-TrackMetrics $tl[1]
    $script:ScpStructOn = $false; $tl0 = Read-ScpFile $rdProt; $script:ScpStructOn = $true
    $m0 = Get-TrackMetrics $tl0[1]
    Chk 'R7' ($m.StructOoc -eq 0 -and $m.StructOver -gt 0 -and $m.Level -eq 1 -and $m0.Level -eq 1 -and [math]::Abs($m.Ooc - $m0.Ooc) -lt 0.001) "protection 0.1 (17 par tour) : rien retire, StructOver $($m.StructOver), erreurs/tour $('{0:0.00}' -f $m.Ooc) comme sans S13 ($('{0:0.00}' -f $m0.Ooc)), niveau $($m.Level) (1, comme en 12.9 : $($m0.Level))"
} else { "  protection absente : R7 saute" }
$tm = Get-Real $rdC
if ($tm) {
    $nA = 0; $nO = 0
    foreach ($tn in @($tm.Keys)) { $m = Get-TrackMetrics $tm[$tn]; if ($m.StructOoc -gt 0) { $nA++ }; if ($m.StructOver -gt 0) { $nO++ } }
    Chk 'R8' ($nA -ge 70 -and $nO -eq 0) "raccord-c (1 a 4 par tour) : S13 applique sur $nA pistes (>= 70), aucune au-dela du plafond ($nO)"
} else { "  raccord-c absente : R8 saute" }

"--- T : cablage"
$s190 = [System.IO.File]::ReadAllText((Join-Path $mods '190-fn-qualite-alignement.ps1'))
Chk 'T1' ($s190.Contains('$st = if ($post.Zone) { Get-ScpStructOoc $fl $list ([int]$script:ScpRevWin) $smax $edges } else { Get-ScpStructOoc $fl $list 0 $smax }') -and $s190.Contains('if ($sHi -gt $smax) { $post.StructOver = $sSum }') -and $s190.Contains('StructOoc = 0; StructOver = 0 }') -and $s190.Contains("if (`$pp.Value.ContainsKey('StructOoc')) { `$m.StructOoc = [int]`$pp.Value.StructOoc }") -and $s190.Contains("if (`$pp.Value.ContainsKey('StructOver')) { `$m.StructOver = [int]`$pp.Value.StructOver }") -and $s190.Contains('[math]::Max(0, [int]$list[$r].OutOfClass - $dOoc[$r])')) 'Set-ScpTrackPost (S13 apres la zone, plafond ScpStructMax, tout ou rien), Post.StructOoc / StructOver, Get-TrackMetrics, OutOfClass jamais negatif'
Chk 'T2' ($s190.Contains('if ($so -gt 0) { Append-Log ((T "Mesure : {0} intervalle(s) hors classe reproductibles d''un tour à l''autre à la même position, sur {1} piste(s), non compté(s) : raccord d''écriture d''une longue piste ou protection ; un petit défaut fixe du support (jusqu''à {2} intervalles par tour) y passerait aussi.") -f "$so", "$sot", "$($script:ScpStructMax)") }')) 'ligne de journal de la mesure (petit defaut fixe, jusqu a ScpStructMax par tour)'
$s170 = [System.IO.File]::ReadAllText((Join-Path $mods '170-fn-controle-ecriture.ps1'))
Chk 'T3' ($s170.Contains('if ($so -gt 0) { Append-Log ((T "Contrôle après écriture : {0} intervalle(s) hors classe reproductibles') -and $s170.Contains('if ([int]$ms.StructOoc -gt 0) { $so += [int]$ms.StructOoc; $sot++ }')) 'ligne de journal du controle (retires)'
$l190 = 'if ($sov.Count -gt 0) { Append-Log ((T "Mesure : {0} piste(s) avec plus de {1} intervalles hors classe reproductibles par tour, tous comptés comme erreurs (au-delà d''un raccord d''écriture ou d''une protection : défaut du support ou écriture à revoir) : {2}.") -f "$($sov.Count)", "$($script:ScpStructMax)", "$(Format-TrackList $sov)") }'
$l170 = 'if ($sov.Count -gt 0) { Append-Log ((T "Contrôle après écriture : {0} piste(s) avec plus de {1} intervalles hors classe reproductibles par tour, tous comptés comme erreurs (au-delà d''un raccord d''écriture ou d''une protection : défaut du support ou écriture à revoir) : {2}.") -f "$($sov.Count)", "$($script:ScpStructMax)", "$(Format-TrackList $sov)") }'
# Ligne de la mesure dans le bloc de la premiere passe, apres celle des retires ; pistes au-dela par leur libelle
$iSo = $s190.IndexOf('if ($so -gt 0) { Append-Log ((T "Mesure : {0} intervalle(s)'); $iSov = $s190.IndexOf($l190); $iPass = $s190.IndexOf('if (-not $script:AlignLoop -or [int]$script:QualView.Pass -le 1) {')
Chk 'T4' ($iSov -gt $iSo -and $iSo -gt $iPass -and $iPass -gt 0 -and $s190.Contains('if ($m.StructOver -gt 0) { $sov += $lab }') -and $s190.Contains('$so = 0; $sot = 0; $sov = @()')) 'mesure (190) : pistes au-dela du plafond recueillies par leur libelle, ligne a la premiere passe, apres celle des retires (Format-TrackList)'
Chk 'T5' ($s170.Contains($l170) -and $s170.Contains('if ([int]$ms.StructOver -gt 0 -and -not ($rep.Ignore -and $rep.Ignore.ContainsKey($k))) { $sov += $k }') -and $s170.IndexOf($l170) -gt $s170.IndexOf('if ($so -gt 0) { Append-Log ((T "Contrôle après écriture : {0} intervalle(s) hors classe reproductibles')) 'controle (170) : pistes au-dela du plafond, hors pistes non comptees (Rep.Ignore), ligne a chaque analyse apres celle des retires'
$s018 = [System.IO.File]::ReadAllText((Join-Path $mods '018-i18n-1210.ps1'))
$k1 = "Mesure : {0} piste(s) avec plus de {1} intervalles hors classe reproductibles par tour, tous comptés comme erreurs (au-delà d'un raccord d'écriture ou d'une protection : défaut du support ou écriture à revoir) : {2}."
$k2 = "Contrôle après écriture : {0} piste(s) avec plus de {1} intervalles hors classe reproductibles par tour, tous comptés comme erreurs (au-delà d'un raccord d'écriture ou d'une protection : défaut du support ou écriture à revoir) : {2}."
$k3 = "Mesure : {0} intervalle(s) hors classe reproductibles d'un tour à l'autre à la même position, sur {1} piste(s), non compté(s) : raccord d'écriture d'une longue piste ou protection ; un petit défaut fixe du support (jusqu'à {2} intervalles par tour) y passerait aussi."
# Table lue par l arbre syntaxique (cle et texte constants de chaque affectation), sans rien executer
$script:I18n = @{}
foreach ($st in (Get-StAst (Join-Path $mods '018-i18n-1210.ps1')).EndBlock.Statements) {
    if ($st -is [System.Management.Automation.Language.AssignmentStatementAst] -and $st.Left -is [System.Management.Automation.Language.IndexExpressionAst] -and $st.Left.Target.Extent.Text -eq '$script:I18n') {
        $script:I18n[[string]$st.Left.Index.Value] = [string]$st.Right.Expression.Value
    }
}
$okK = $true; $kd = @()
foreach ($k in $k1, $k2, $k3) {
    $v = $script:I18n[$k]
    if (-not $v) { $okK = $false; $kd += 'absente'; continue }
    foreach ($ph in '{0}', '{1}', '{2}') { if ($k.Contains($ph) -ne $v.Contains($ph)) { $okK = $false; $kd += "$ph" } }
    if ($v -match '[éèàùç]') { $okK = $false; $kd += 'accent' }
}
Chk 'T6' ($okK -and -not $s018.Contains('un défaut fixe du support y passerait aussi')) "cles i18n (018) : deux lignes du plafond et ligne des retires mise a jour, traduites, memes {n} ; ancienne cle retiree$(if ($kd) { ' ; ' + ($kd -join ', ') })"

Chk 'T7' ($s190.Contains('if ($r -eq 0 -and $p -eq 0) { continue }') -and (-not $refOk -or $refRule)) "Get-ScpStructOoc : premier intervalle du tour 0 jamais compte (regle S10)$(if ($refOk) { ', reference completee de la meme regle' } else { ' ; reference absente : sa regle n est pas controlee' })"

$nk = if ($script:Fail) { ' ; non conformes : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-1210-struct-r : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
