param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Before = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 rc6 (R15) : facteur de la disquette par l asymetrie relue, a la mesure sur l image (274, 276, 040, 000).
#  P1 a P3  Get-ContentAsymFit sur des asymetries lineaires simulees A = s.(w - k.V(c)) + bruit : retrouve k et la pente
#           (rapportee aux 2 / cellule) pour un besoin sous la courbe (k 0,75, trois niveaux), au-dessus (k 1,9, 4e passe
#           aux niveaux 1,6 et 1) et pour une disquette ou la marge serait plate ; erreur-type et jackknife par zone.
#  N1 a N6  non determine, chaque critere : trop peu de cylindres a 2 niveaux, pente nulle ou negative, pente hors de la
#           plage rapportee a la cellule, incertitude, k hors de [0,1 ; 4], extrapolation au-dela de 1,5 x le plus haut
#           niveau ; lignes sans asymetrie (NaN) ignorees.
#  C1 a C4  Get-ContentAsymChoice : asymetrie determinee retenue (ecart avec la marge signale au-dela de 0,3) ; sinon la
#           marge, puis le facteur de la marque, puis 1 (comportement de la 12.10).
#  T1 a T3  Get-ContentTrackAsym : asymetrie signee d une piste de flux factice (rapports 3T/2T et 4T/2T de ScpStats.Analyze
#           moyennes par Get-TrackMetrics, comme au controle) ; piste absente, tour illisible : NaN.
#  K1, K2   enregistrement par marque : methode, facteurs par l asymetrie et par la marge gardes dans la configuration ; k
#           au-dessus de 2 admis pour l asymetrie seulement ; ContentCalc 12.11, CalibCalc inchange ; textes du journal.
#  K3       (relecture) memoire par marque (Get-DriveK) : les mesures par l asymetrie seules dans la mediane quand il y en a.
# Fonctions reelles extraites par l arbre syntaxique (bloc C# ScpStats de 030 charge comme logic-qualite-hors-classe),
# bouchons : T, Append-Log. Aucune relecture reelle, aucun gw, aucune fenetre.
# Non couvert ici : Complete-ContentMeasure elle-meme (enchainement de la mesure, journal complet, ecriture qui suit),
# couverte par le banc GUI seulement.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mods = Join-Path $Wt 'src\modules'
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
function Get-AsAst([string]$path) {
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message)" }
    return $ast
}
$sb = New-Object System.Text.StringBuilder
$ast = Get-AsAst (Join-Path $mods '030-csharp.ps1')
$cmd = @($ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'Add-Type' -and $x.Extent.Text -like '*class ScpStats*' }, $true))
if ($cmd.Count -ne 1) { throw "statement Add-Type ScpStats : $($cmd.Count)" }
[void]$sb.AppendLine($cmd[0].Extent.Text)
$want = @{
    '010-i18n.ps1' = @('Format-UiNum')
    '190-fn-qualite-alignement.ps1' = @('Get-TrackMetrics', 'Get-TrackScore', 'Get-HealthLevel')
    '274-fn-contenu-calcul.ps1' = @('Get-ContentAsymOls', 'Get-ContentAsymFit', 'Get-ContentAsymChoice', 'Get-ContentAppliedK', 'ConvertTo-FiniteOrNull', 'Get-ConfigDouble', 'Get-RecValues', 'ConvertTo-ContentConfig', 'ConvertFrom-ContentConfig')
    '276-fn-contenu-mesure.ps1' = @('Get-ContentTrackAsym', 'Get-ContentAsymWhyText', 'Get-ContentAsymText', 'Get-ContentAppliedAsymText', 'Format-ContentNum')
    # relecture de la rc6 : memoire par marque (Get-DriveK) et ses aides
    '220-fn-profil-precomp.ps1' = @('Get-CurveDate')
    '230-fn-calib-courbe.ps1' = @('Get-Median')
    '265-fn-calib-adaptative.ps1' = @('Get-LevelBrandKey')
}
$want['274-fn-contenu-calcul.ps1'] += 'Get-DriveK'
$found = @{}
foreach ($f in @($want.Keys)) {
    foreach ($fd in (Get-AsAst (Join-Path $mods $f)).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
        if ($want[$f] -contains $fd.Name) { [void]$sb.AppendLine($fd.Extent.Text); $found[$fd.Name] = $true }
    }
}
$miss = @(foreach ($f in @($want.Keys)) { foreach ($n in $want[$f]) { if (-not $found.ContainsKey($n)) { $n } } })
if ($miss.Count) { throw "fonctions introuvables : $($miss -join ', ')" }
foreach ($m in '000-entete.ps1', '040-etat-formats.ps1') {
    foreach ($st in (Get-AsAst (Join-Path $mods $m)).EndBlock.Statements) {
        if ($st -is [System.Management.Automation.Language.AssignmentStatementAst] -and $st.Left.Extent.Text -match '^\$script:(ContentAsym\w+|ContentFMax|ScoreAsymK|ContentCalc|CalibCalc)$') { [void]$sb.AppendLine($st.Extent.Text) }
    }
}
$gen = Join-Path $here 'gen-as-fonctions.ps1'
[System.IO.File]::WriteAllText($gen, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
function T([string]$s) { return $s }
$script:ALog = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text) { $script:ALog.Add($text) }
$script:Lang = 'fr'
. $gen
$script:JitterOk = 120.0; $script:JitterWatch = 250.0; $script:HealthErrOk = 2; $script:ScpStatsOk = $true; $script:ContentKMax = 2.0
Set-TestCulture 'fr-FR'

# Mesure simulee : 8 blocs de 5 cylindres (0-4, 10-14, ..., 70-74), courbe V(c) = v0 + v1.c, niveaux par cylindre (chaque
# cylindre porte tous les niveaux, comme les trois passes du plan), w = round(niveau x V), A = s.(w - k.V) + bruit gaussien
# (generateur a graine fixe), cellule 2000 ns (2 / cellule = 0,001)
function New-AsRows([double]$k, [double]$srel, [double]$noise, [double[]]$levels, [int]$nBlocks = 8, [double]$v0 = 10, [double]$v1 = 1.5, [int]$seed = 7, [double]$cell = 2000) {
    $rnd = New-Object System.Random($seed)
    $s = $srel * 2.0 / $cell
    $o = New-Object System.Collections.Generic.List[object]
    for ($b = 0; $b -lt $nBlocks; $b++) {
        for ($j = 0; $j -lt 5; $j++) {
            $c = 10 * $b + $j; $v = [math]::Round($v0 + $v1 * $c)
            foreach ($l in $levels) {
                $w = [int][math]::Round($l * $v)
                $u1 = 1.0 - $rnd.NextDouble(); $u2 = $rnd.NextDouble()
                $g = [math]::Sqrt(-2.0 * [math]::Log($u1)) * [math]::Cos(2 * [math]::PI * $u2)
                $o.Add(@{ C = $c; K = $l; W = $w; V = [double]$v; A = $s * ($w - $k * $v) + $noise * $g; Cell = $cell })
            }
        }
    }
    return ,$o.ToArray()
}
$lv3 = [double[]]@(0.25, 0.6, 1.0); $lv4 = [double[]]@(0.25, 0.6, 1.0, 1.6)

'--- P : estimateur sur des asymetries lineaires simulees'
$p1 = Get-ContentAsymFit (New-AsRows 0.75 0.9 0.004 $lv3)
Chk 'P1' ($p1.Det -and [math]::Abs($p1.K - 0.75) -le 0.03 -and [math]::Abs($p1.SRel - 0.9) -le 0.05 -and $p1.NCyl -eq 40 -and $p1.N -eq 120 -and $p1.SeK -le 0.05 -and $p1.Jack -le 0.08 -and $p1.TS -ge 10) "k 0,75, pente 0,9 x 2/cellule, bruit 0,004 (residus reels 0,005 a 0,008), 3 niveaux : k = $([math]::Round($p1.K, 3)) ± $([math]::Round($p1.SeK, 3)) (jackknife $([math]::Round($p1.Jack, 3))), pente $([math]::Round($p1.SRel, 3)), t $([math]::Round($p1.TS, 0)), $($p1.NCyl) cylindres, $($p1.N) pistes"
# P2 : besoin au-dessus de la courbe (k 1,9 avec un lecteur a faible besoin), 4e passe aux niveaux 1,6 et 1
$p2 = Get-ContentAsymFit (New-AsRows 1.9 0.85 0.006 $lv4 -v0 2 -v1 0.7 -seed 11)
Chk 'P2' ($p2.Det -and [math]::Abs($p2.K - 1.9) -le 0.08 -and [math]::Abs($p2.SRel - 0.85) -le 0.05 -and $p2.KTop -eq 1.6) "k 1,9 au-dessus du plus haut niveau 1,6 (courbe de 2 a 54 ns, 4 niveaux) : k = $([math]::Round($p2.K, 3)) ± $([math]::Round($p2.SeK, 3)), pente $([math]::Round($p2.SRel, 3)), extrapolation permise jusqu a $(1.5 * $p2.KTop)"
# P3 : sans bruit, valeurs exactes a l arrondi de w pres (k et pente retrouves a 1e-6 quand w n est pas arrondi : V entiers, niveaux 0, 1, 2)
$p3 = Get-ContentAsymFit (New-AsRows 0.65 0.7 0.0 ([double[]]@(0.0, 1.0, 2.0)))
Chk 'P3' ($p3.Det -and [math]::Abs($p3.K - 0.65) -le 1e-6 -and [math]::Abs($p3.SRel - 0.7) -le 1e-6) "sans bruit, niveaux 0/1/2 (w exacts) : k = $($p3.K), pente $($p3.SRel) (0,65 et 0,7 attendus)"

'--- N : non determine'
$n1 = Get-ContentAsymFit (New-AsRows 0.75 0.9 0.004 $lv3 -nBlocks 4)
$n1b = Get-ContentAsymFit (New-AsRows 0.75 0.9 0.004 ([double[]]@(0.6)))
Chk 'N1' (-not $n1.Det -and $n1.Why -eq 'peu' -and $n1.NCyl -eq 20 -and -not $n1b.Det -and $n1b.Why -eq 'peu' -and $n1b.NCyl -eq 0) "20 cylindres a 2 niveaux : $($n1.Why) ($($n1.NCyl)) ; un seul niveau par cylindre : $($n1b.Why) ($($n1b.NCyl) cylindres a 2 niveaux)"
$n2a = Get-ContentAsymFit (New-AsRows 0.75 -0.5 0.004 $lv3)
$n2b = Get-ContentAsymFit (New-AsRows 0.75 0.2 0.0005 $lv3)
$n2c = Get-ContentAsymFit (New-AsRows 0.75 2.0 0.004 $lv3)
Chk 'N2' (-not $n2a.Det -and $n2a.Why -eq 'pente' -and -not $n2b.Det -and $n2b.Why -eq 'pente' -and -not $n2c.Det -and $n2c.Why -eq 'pente') "pente negative : $($n2a.Why) ; 0,2 x 2/cellule : $($n2b.Why) ($([math]::Round($n2b.SRel, 2))) ; 2 x 2/cellule : $($n2c.Why) ($([math]::Round($n2c.SRel, 2)))"
$n3 = Get-ContentAsymFit (New-AsRows 0.75 0.0 0.004 $lv3)
$n3b = Get-ContentAsymFit (New-AsRows 0.75 0.5 0.08 $lv3)
Chk 'N3' (-not $n3.Det -and @('pente', 'tpente') -contains $n3.Why -and -not $n3b.Det -and @('pente', 'tpente', 'incert') -contains $n3b.Why) "asymetrie sans pente (disquette insensible) : $($n3.Why) ; bruit 0,08 (dix fois le reel) : $($n3b.Why) (k $([math]::Round($n3b.K, 2)) ± $([math]::Round($n3b.SeK, 2)), t $([math]::Round($n3b.TS, 1)))"
$n4 = Get-ContentAsymFit (New-AsRows 0.05 0.9 0.002 $lv3)
$n4b = Get-ContentAsymFit (New-AsRows 4.6 0.9 0.004 ([double[]]@(1.0, 2.0, 3.2)))
Chk 'N4' (-not $n4.Det -and $n4.Why -eq 'borne' -and -not $n4b.Det -and $n4b.Why -eq 'borne') "k 0,05 sous 0,1 : $($n4.Why) (k $([math]::Round($n4.K, 3))) ; k 4,6 au-dessus de ContentFMax 4 : $($n4b.Why) (k $([math]::Round($n4b.K, 2)))"
$n5 = Get-ContentAsymFit (New-AsRows 1.8 0.9 0.004 $lv3)
Chk 'N5' (-not $n5.Det -and $n5.Why -eq 'extrap' -and [math]::Abs($n5.K - 1.8) -le 0.1) "k 1,8 pour un plus haut niveau ecrit de 1 (1,5 permis) : $($n5.Why) (k $([math]::Round($n5.K, 2)))"
$rn = New-AsRows 0.75 0.9 0.004 $lv3
$rn6 = @($rn) + @(@{ C = 5; K = 1.6; W = 30; V = 18.0; A = [double]::NaN; Cell = 2000.0 }, @{ C = 15; K = 1.6; W = 50; V = 33.0; A = [double]::PositiveInfinity; Cell = 2000.0 })
$p6 = Get-ContentAsymFit $rn6
Chk 'N6' ($p6.Det -and $p6.N -eq 120 -and [math]::Abs($p6.K - $p1.K) -lt 1e-12 -and $p6.KTop -eq 1.0) "lignes sans asymetrie (NaN, infinie) ignorees : $($p6.N) pistes, k identique ($([math]::Round($p6.K, 4))), plus haut niveau $($p6.KTop)"

'--- C : facteur applique'
$c1 = Get-ContentAsymChoice $p1 'mesure' 0.7 1.3 2.0
$c1b = Get-ContentAsymChoice $p1 'mesure' 1.2 $null 2.0
Chk 'C1' ($c1.By -eq 'asym' -and $c1.Src -eq 'mesure' -and $c1.K -eq $p1.K -and -not $c1.Gap -and $c1b.By -eq 'asym' -and $c1b.Gap) "asymetrie determinee : k $([math]::Round($c1.K, 3)) par l asymetrie (marge 0,70, ecart sous 0,3 : non signale) ; marge 1,20 : ecart signale ($($c1b.Gap)), l asymetrie reste retenue"
$c2 = Get-ContentAsymChoice $p2 'plate' 2.35 0.8 2.0
Chk 'C2' ($c2.By -eq 'asym' -and [math]::Abs($c2.K - $p2.K) -lt 1e-12 -and -not $c2.Gap) "marge plate et asymetrie determinee : k $([math]::Round($c2.K, 2)) applique, et non le facteur de la marque 0,8 ; pas d ecart signale (marge non determinee)"
$c3 = Get-ContentAsymChoice $n1 'mesure' 0.82 1.3 2.0
$c3b = Get-ContentAsymChoice $n1 'haute' 2.6 $null 2.0
Chk 'C3' ($c3.By -eq 'marge' -and $c3.K -eq 0.82 -and $c3.Src -eq 'mesure' -and $c3b.K -eq 2.0 -and $c3b.By -eq 'marge') "asymetrie non determinee, marge determinee : k $($c3.K) par la marge ; optimum de la marge au-dela de 2 : $($c3b.K) (borne, comme en 12.10)"
$c4 = Get-ContentAsymChoice $n1 'plate' 2.3 0.9 2.0
$c4b = Get-ContentAsymChoice $null 'peu' 2.0 $null 2.0
$c4c = Get-ContentAsymChoice $n1 'echec' ([double]::NaN) $null 2.0
Chk 'C4' ($c4.K -eq 0.9 -and $c4.Src -eq 'lecteur' -and $c4.By -eq '' -and $c4b.K -eq 1.0 -and $c4b.Src -eq 'defaut' -and $c4c.K -eq 1.0 -and $c4c.Src -eq 'defaut') "rien de determine : facteur de la marque $($c4.K) ($($c4.Src)) ; sans marque : $($c4b.K) ($($c4b.Src)) ; sans ajustement de la marge : $($c4c.K) ($($c4c.Src))"

'--- T : asymetrie d une piste relue'
# Tours factices : 2T, 3T, 4T en sequence fixe (cellule 2000 ns), 3T et 4T allonges de d3 et d4 ns : A = d3/4000 + 2.d4/4000
function New-AsRev([int]$d3, [int]$d4, [int]$n = 3000) {
    $seq = @(2, 3, 2, 4, 2, 2, 3, 4, 2, 3)
    $f = New-Object int[] $n
    for ($i = 0; $i -lt $n; $i++) { $t = $seq[$i % $seq.Count]; $f[$i] = switch ($t) { 2 { 4000 } 3 { 6000 + $d3 } 4 { 8000 + $d4 } } }
    return @{ Flux = $f; DurNs = 200000000.0 }
}
$ta = Get-ContentTrackAsym @((New-AsRev 40 40), (New-AsRev 40 40), (New-AsRev 40 40))
$tb = Get-ContentTrackAsym @((New-AsRev -60 -20), (New-AsRev -60 -20))
$want1 = 40 / 4000.0 + 40 / 4000.0; $want2 = -60 / 4000.0 - 20 / 4000.0
Chk 'T1' ([math]::Abs($ta.A - $want1) -lt 1e-9 -and [math]::Abs($ta.Cell - 2000) -lt 1e-9 -and [math]::Abs($tb.A - $want2) -lt 1e-9) "3T et 4T relus 40 ns trop longs : A = $([math]::Round($ta.A, 6)) ($want1 attendu), cellule $($ta.Cell) ns ; 60 et 20 ns trop courts : $([math]::Round($tb.A, 6)) ($want2)"
$mx = Get-ContentTrackAsym @((New-AsRev 40 40), (New-AsRev 0 0))
Chk 'T2' ([math]::Abs($mx.A - $want1 / 2) -lt 1e-9) "rapports moyennes sur les tours (Get-TrackMetrics) : tours a +0,02 et 0 : A = $([math]::Round($mx.A, 6)) ($($want1 / 2) attendu)"
$bad = Get-ContentTrackAsym @((New-AsRev 40 40), @{ Flux = [int[]]@(4000, 6000, 8000); DurNs = 1.0 })
$none = Get-ContentTrackAsym $null
$script:ScpStatsOk = $false; $noCs = Get-ContentTrackAsym @((New-AsRev 40 40)); $script:ScpStatsOk = $true
Chk 'T3' ([double]::IsNaN($bad.A) -and [double]::IsNaN($none.A) -and [double]::IsNaN($noCs.A)) "un tour sans cellule mesuree (piste illisible pour le controle) : A NaN ($($bad.A)) ; piste absente : $($none.A) ; analyse compilee absente : $($noCs.A)"

'--- K : enregistrement, calcul, textes'
$recA = @{ Model = 'contenu'; Drive = 'A'; Family = 'std'; Head = 0; Date = '05/03/2026 09:30'; K = 3.1; Etat = 'mesure'; Method = 'asym'; KAsym = 3.1; SeKAsym = 0.04; SRelAsym = 0.85; KMarge = 2.35; EtatMarge = 'plate'; Levels = @(1.0); Values = @(10, 20) }
$recM = @{} + $recA; $recM.Method = 'marge'
$ra = ConvertFrom-ContentConfig ((ConvertTo-ContentConfig $recA) | ConvertTo-Json -Depth 5 | ConvertFrom-Json)
$rm = ConvertFrom-ContentConfig ((ConvertTo-ContentConfig $recM) | ConvertTo-Json -Depth 5 | ConvertFrom-Json)
Chk 'K1' ($ra -and $ra.K -eq 3.1 -and $ra.Method -eq 'asym' -and $ra.KAsym -eq 3.1 -and $ra.KMarge -eq 2.35 -and $ra.EtatMarge -eq 'plate' -and $ra.SRelAsym -eq 0.85 -and $null -eq $rm) "configuration : methode $($ra.Method), k $($ra.K) par l asymetrie (marge $($ra.KMarge), $($ra.EtatMarge)) relus ; k 3,1 par la marge : rejete comme avant (au-dela de ContentKMax 2) : $($null -eq $rm)"
$txD = Get-ContentAsymText $p1; $txN = Get-ContentAsymText $n1; $txG = Get-ContentAppliedAsymText '[tête 0] ' $c1b 1.2
Chk 'K2' ($script:ContentCalc -eq '12.11' -and $script:CalibCalc -eq '12.10' -and $txD.StartsWith("Facteur par l'asymétrie : k = 0,7") -and $txN -ceq "Facteur par l'asymétrie non déterminé (20 cylindres à 2 niveaux lisibles, il en faut 24) : la marge décide." -and $txG.Contains('la marge donnait k = 1,20, écart au-delà de 0,3')) "ContentCalc $($script:ContentCalc) (mesures 12.9 mises de cote), CalibCalc $($script:CalibCalc) (courbes gardees) ; journal : « $txD » ; « $txN » ; « $txG »"

# K3 (relecture de la rc6) : memoire par marque, un seul calcul dans la mediane : des qu une mesure par l asymetrie existe
# pour ce lecteur, cette famille, cette tete et cette marque, les mesures dont la marge a decide (etat 'mesure' aussi) ne
# comptent plus ; sans mesure par l asymetrie, la marge reste le facteur memorise (repli de la 12.10)
function New-K3Rec([string]$date, [double]$k, [string]$meth) { return @{ Model = 'contenu'; Drive = 'A'; Family = 'std'; Head = 0; Date = $date; K = $k; Etat = 'mesure'; Method = $meth; Brand = 'X'; ContentCalc = $script:ContentCalc; Calc = $script:CalibCalc } }
$script:ContentMeasures = @((New-K3Rec '03/03/2026 10:00' 1.12 'marge'), (New-K3Rec '04/03/2026 10:00' 0.71 'asym'), (New-K3Rec '04/03/2026 11:00' 1.15 'marge'))
$k3a = Get-DriveK 'A' 'std' 0 'X'
$script:ContentMeasures = @((New-K3Rec '03/03/2026 10:00' 1.12 'marge'), (New-K3Rec '04/03/2026 11:00' 0.90 'marge'))
$k3b = Get-DriveK 'A' 'std' 0 'X'
Chk 'K3' ($k3a.K -eq 0.71 -and $k3a.N -eq 1 -and $k3a.Src -eq 'lecteur' -and [math]::Abs($k3b.K - 1.01) -lt 1e-9 -and $k3b.N -eq 2) "mesures marge 1,12 et 1,15 et asymetrie 0,71 : k memorise $($k3a.K) ($($k3a.N) mesure, et non la mediane 1,12 des trois) ; marge seule 1,12 et 0,90 : $($k3b.K) ($($k3b.N) mesures)"

$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-contenu-asymetrie : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
