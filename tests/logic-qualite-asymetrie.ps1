param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Before = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 (lot L3) : asymetrie signee et expliquee de l onglet « Qualite & alignement » et du controle apres ecriture ;
# correction par la reference du motif retiree (190, 170, 195, 040, 560, 018, 019).
#  S1 a S5  signe d une piste (Get-AsymSign) et texte de la case « Asym. » (Format-AsymCell) ;
#  R1 a R8  resume d un resultat (Get-AsymSummary) et sa phrase (Get-AsymSummaryText) : seuil de 80 %, mediane en classe
#           verte, pistes illisibles, liste vide, phrase anglaise ;
#  N1       score d une piste (Get-TrackScore) et constantes de 040 ; N2 plus aucune trace de la correction ;
#  N3       scores, etats et asymetries de 32 pistes factices : valeurs rendues par la source de la 12.10 ;
#  E1, E2   export : ligne « Asymetrie » de l en-tete, colonne « Asym. » sans signe, ecarts signes, piste illisible ;
#  C1       la case signee tient dans la colonne « Asym. » (largeur lue dans 530, police lue dans 500, format de 195) ;
#  J1 a J6  journal et resultat : mesure (Invoke-AlignAnalysis reelle), mesure continue, controle (Show-WriteCheckTable
#           reelle) ; couleur des lignes au journal (Get-LogColor reelle) ;
#  T1, T2   infobulle du tableau (Update-QualityTip reelle, vrai ToolTip jamais affiche) ; infobulle de la carte
#           (Get-QualityCardModel reelle, theme reel de 500) ;
#  I1       table I18n : textes de la specification dans 019, memes jalons {n}, cles de la correction absentes ;
#  Q0 a Q6  equivalence avec la 12.10, avec -Before <racine d une copie de la source de la 12.10> (aucune dans le depot ;
#           sans elle, une ligne « saute ») : les memes pistes factices passent par les fonctions des deux versions,
#           chacune chargee dans sa portee. Q1 mesure, deux passes (lignes du tableau au signe pres, derniere mesure,
#           resultat, journal a la phrase nouvelle pres) ; Q2 controle apres ecriture, deux passes (etat de chaque piste,
#           pistes faibles, file des commandes de reecriture et de relecture, journal) ; Q3 passe interrompue
#           (Update-RepPartial) ; Q4 tableau du controle ; Q5 fonctions de decision au caractere pres ; Q6 valeurs de N3.
# Fonctions reelles extraites par l arbre syntaxique, ecrites dans un fichier de travail, chargees par dot-source ; vrais
# controles WinForms jamais affiches (ListView, ToolTip) ; bouchons pour le journal, la carte, la lecture des fichiers SCP
# et la chaine d etapes. Aucun gw, aucune fenetre, aucune compilation.
# Non couvert : la ligne de journal du controle dans son enchainement reel (Complete-WriteCheck) ; le dessin de la case
# (Draw-AlSubItem) et celui de la carte (Render-QualityCard).
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
function Get-Short([string]$s, [int]$max = 150) { if ($s.Length -gt $max) { return $s.Substring(0, $max) + '...' }; return $s }
$tFn = [System.Management.Automation.Language.FunctionDefinitionAst]
$tAsg = [System.Management.Automation.Language.AssignmentStatementAst]
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$mods = Join-Path $Wt 'src\modules'

# Textes de la specification (asymetrie, § 2.2) ; le quatrieme est conditionnel comme les deux premiers (plan, § 1.4)
$kPos = "Asymétrie positive sur {0} piste(s) sur {1} (médiane {2}) : les intervalles longs sont relus trop longs, comme après une écriture au-dessus du niveau de précompensation qui centre les intervalles pour ce lecteur. Elle compte pour {3} point(s) du score moyen et ne change pas l'état des pistes."
$ePos = 'Positive asymmetry on {0} of {1} track(s) (median {2}): long intervals are read back too long, as after a write above the precompensation level that centres the intervals for this drive. It accounts for {3} point(s) of the mean score and does not change the track status.'
$kNeg = "Asymétrie négative sur {0} piste(s) sur {1} (médiane {2}) : les intervalles longs sont relus trop courts, comme après une écriture au-dessous du niveau de précompensation qui centre les intervalles pour ce lecteur. Elle compte pour {3} point(s) du score moyen et ne change pas l'état des pistes."
$eNeg = 'Negative asymmetry on {0} of {1} track(s) (median {2}): long intervals are read back too short, as after a write below the precompensation level that centres the intervals for this drive. It accounts for {3} point(s) of the mean score and does not change the track status.'
$kShort = 'médiane {0}, sans signe commun ; {1} point(s) du score moyen'
$eShort = 'median {0}, no common sign; {1} point(s) of the mean score'
$kSign = "Signe de l'asymétrie : + intervalles longs relus trop longs (comme après une écriture au-dessus de la précompensation qui les centre pour ce lecteur) ; - trop courts (comme après une écriture au-dessous) ; sans signe : écarts de sens opposés."
$eSign = 'Asymmetry sign: + long intervals read back too long (as after a write above the precompensation that centres them for this drive); - too short (as after a write below it); no sign: deviations in opposite directions.'
# Cles de la correction retiree (018 jusqu a la 12.10)
$kOld1 = "Mesure : asymétrie et score corrigés du biais de lecture du lecteur {0} sur {1} piste(s), d'après le motif de sa calibration (famille d'après la cellule mesurée)."
$kOld2 = "corrigée du biais de lecture du lecteur sur {0} piste(s), d'après le motif de sa calibration"

# ---------------------------------------------------------------- fonctions reelles
# Par module : fonctions communes aux deux versions ; puis celles du lot (190) et celles de la correction retiree (190)
$fnCommon = @{
    '110-fn-coeur-gw.ps1'           = @('Get-LogColor')
    '150-fn-pistes-densite.ps1'     = @('Get-TrackKeyOrder', 'Sort-TrackKeys', 'Format-TrackList', 'Get-TSpecExtras', 'Get-TrackGroups', 'Format-EraseTracks')
    '170-fn-controle-ecriture.ps1'  = @('Test-RepFakeIndex', 'Set-CopyUnstable', 'Merge-RepRetries', 'Add-RepReads', 'Invoke-WriteCheckAnalysis', 'Show-WriteCheckTable', 'Update-RepPartial')
    '190-fn-qualite-alignement.ps1' = @('Get-AlLevel', 'Get-HealthLevel', 'Get-JitterRedBound', 'Update-QualityTip', 'Get-TrackMetrics', 'Get-TrackScore', 'New-AlignRow', 'Get-AlignTableExport', 'Get-UnstableClusters', 'Invoke-AlignAnalysis')
    '195-fn-qualite-affichage.ps1'  = @('Get-QualSf', 'Get-QualityCardModel', 'Get-QualStateTitle', 'Get-QualStaleText', 'Get-QualLevelColor', 'Get-QualInk', 'Get-QualDimInk', 'Get-AlName')
    '230-fn-calib-courbe.ps1'       = @('Format-CylList', 'Get-Median')
}
$fnNew = @('Get-AsymSign', 'Format-AsymCell', 'Get-AsymSummary', 'Get-AsymSummaryText')
$fnOld = @('Get-AsymRefTable', 'Get-AsymRefs', 'Set-TrackAsymRef')
$asgCommon = @('$script:HealthErrOk', '$script:JitterStdOk', '$script:JitterStdWatch', '$script:ScpStructMax')
$asgNew = @('$script:ScoreAsymK', '$script:AsymSignPct')
$asgOld = @('$script:QualAsymRefOn')
function New-Gen([string]$root, [string]$outFile, [string[]]$fn190, [string[]]$asg040, [string[]]$asg560) {
    # Fichier de travail : texte des fonctions et des affectations demandees, tel quel ; rend le texte de chaque fonction
    $dir = Join-Path $root 'src\modules'
    $parts = New-Object System.Collections.Generic.List[string]; $defs = @{}
    foreach ($mod in @($fnCommon.Keys | Sort-Object)) {
        $want = @($fnCommon[$mod]); if ($mod -like '190-*') { $want += @($fn190) }
        $have = @{}
        foreach ($fd in @((Get-Ast (Join-Path $dir $mod)).FindAll({ param($x) $x -is $tFn }, $false))) { $have[$fd.Name] = $fd }
        foreach ($n in $want) {
            if (-not $have.ContainsKey($n)) { throw "fonction $n introuvable dans $mod sous $root (lot L3 absent de cette source ?)" }
            $parts.Add($have[$n].Extent.Text); $defs[$n] = $have[$n].Extent.Text
        }
    }
    $asg = @{ '040-etat-formats.ps1' = (@($asgCommon) + @($asg040)); '500-fenetre-theme.ps1' = @('$script:Theme'); '560-etat-calibration.ps1' = @($asg560) }
    foreach ($mod in @($asg.Keys | Sort-Object)) {
        if (@($asg[$mod]).Count -eq 0) { continue }
        $st = @((Get-Ast (Join-Path $dir $mod)).EndBlock.Statements | Where-Object { $_ -is $tAsg })
        foreach ($left in @($asg[$mod])) {
            $hit = @($st | Where-Object { $_.Left.Extent.Text -eq $left })
            if ($hit.Count -ne 1) { throw "affectation $left dans $mod sous $root : $($hit.Count) (1 attendue ; lot L3 absent de cette source ?)" }
            $parts.Add($hit[0].Extent.Text)
        }
    }
    [System.IO.File]::WriteAllText($outFile, ((@($parts) -join "`r`n`r`n") + "`r`n"), $utf8Bom)
    return $defs
}
# System.Drawing avant le fichier des fonctions : le theme de 500 emploie [System.Drawing.Color]
Import-TestWinForms
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' -File | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'
$genNew = Join-Path $here 'gen-apres.ps1'
$defsNew = New-Gen $Wt $genNew $fnNew $asgNew @()
. $genNew

# ---------------------------------------------------------------- remplacants et controles jamais affiches
try { $bold = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold) }
catch { [void][System.Reflection.Assembly]::Load('System.Drawing.Common'); $bold = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold) }
$script:AlColors = @{ 0 = [System.Drawing.Color]::FromArgb(86, 196, 108); 1 = [System.Drawing.Color]::FromArgb(188, 214, 94); 2 = [System.Drawing.Color]::FromArgb(245, 176, 66); 3 = [System.Drawing.Color]::FromArgb(200, 50, 50) }
$script:AlFg = @{ 0 = [System.Drawing.Color]::Black; 1 = [System.Drawing.Color]::Black; 2 = [System.Drawing.Color]::Black; 3 = [System.Drawing.Color]::White }
$script:AlNames = @{ 0 = 'EXCELLENT'; 1 = (T 'BON'); 2 = (T 'MOYEN'); 3 = (T 'MAUVAIS') }
$script:JitterOk = 120; $script:JitterWatch = 250          # reglage par defaut de l Accueil (040 : JitterStdOk / JitterStdWatch)
$script:Version = 'essai'; $script:AlignRefLabel = ''; $script:QualGdi = @{}
$lvAl = New-Object System.Windows.Forms.ListView
$lvAl.View = 'Details'
foreach ($c in @('Piste', 'État', 'Erreurs', 'Trous', 'Stab', 'Jitter ns', 'Score', 'vs réf', 'Asym.', 'Cell ns')) { [void]$lvAl.Columns.Add($c, 60) }
$tip = New-Object System.Windows.Forms.ToolTip
$cmbDrive = [pscustomobject]@{ Text = '0' }
$numAlPause = [pscustomobject]@{ Value = 5 }
$script:RLog = New-Object System.Collections.Generic.List[string]
$script:Calls = New-Object System.Collections.Generic.List[string]
$script:FakeScp = @{}
$script:TempDir = Join-Path $here 'temp'
$script:AlignTmp = Join-Path $here 'mesure-factice.scp'
[System.IO.File]::WriteAllBytes($script:AlignTmp, [byte[]]@())
function Append-Log([string]$text) { $script:RLog.Add($text) }
function Set-QualityResult($res) { $script:LastRes = $res }
function Set-QualityStale([string]$reason) { $script:Calls.Add("Set-QualityStale $reason") }
function Update-AlignGuide([double]$avg) { $script:Calls.Add('Update-AlignGuide ' + $avg.ToString('R', $inv)) }
function Set-UnstableBanner([string[]]$parts) { $script:Calls.Add('Set-UnstableBanner ' + ((@($parts) | Where-Object { $_ }) -join ' / ')) }
function Start-RepPending { $script:Calls.Add('Start-RepPending') }
function Complete-WriteCheck([switch]$GwError) { $script:Calls.Add('Complete-WriteCheck') }
function Stop-WriteCheck([switch]$GwError) { $script:Calls.Add('Stop-WriteCheck') }
function Read-ScpFile([string]$path, [switch]$NoIndexZone) {
    # Lecture factice : pistes posees par le test pour ce chemin (numero gw -> tours)
    if (-not $script:FakeScp.ContainsKey($path)) { throw "lecture factice absente : $path" }
    return $script:FakeScp[$path]
}
function Reset-State {
    $script:RLog.Clear(); $script:Calls.Clear(); $script:LastRes = $null
    $script:AlignLoop = $false; $script:AlignNextAt = $null; $script:AlignBest = @{}; $script:AlignPrev = $null; $script:AlignRef = $null; $script:AlignLast = $null
    $script:QualView = @{ State = 'run'; Kind = 'measure'; Reason = ''; At = $null; Has = $false; Pass = 0; Drive = ''; Heads = ''; Revs = 0; NCyl = 0; RunText = ''; Res = $null }
    $script:Rep = $null; $script:EraseLog = $null; $script:WriteTracks = @{}; $script:WriteRetries = @{}; $script:Lang = 'fr'
    # Courbes du lecteur 0 avec le releve du motif sur tous les cylindres : la source de la 12.10 les lit (Get-AsymRefs),
    # sa correction, livree desactivee, ne s en sert pas
    $cy = [int[]]@(0..16); $a3 = [double[]]@($cy | ForEach-Object { 0.02 }); $a4 = [double[]]@($cy | ForEach-Object { 0.03 })
    $script:PrecompCurves = @{}
    foreach ($k in 'long', 'long_h0', 'long_h1', 'std', 'std_h0', 'std_h1') { $script:PrecompCurves[$k] = @{ Drive = '0'; AsymCyl = $cy; AsymD3 = $a3; AsymD4 = $a4 } }
    $lvAl.Items.Clear()
}

# ---------------------------------------------------------------- pistes factices
function New-Rev([double]$j, [double]$r3, [double]$r4, [double]$ooc = 0, [double]$dr = 0, [double]$cell = 1888.0, [int]$nflux = 40000, [int]$blocks = 0, [int]$unst = 0, [int]$run = 0) {
    # Tour analyse (proprietes de ScpStats.Analyze et de Read-ScpFile que lit Get-TrackMetrics)
    return [pscustomobject]@{ Jitter = $j; R3 = $r3; R4 = $r4; OutOfClass = $ooc; Dropouts = $dr; Cell = $cell; NFlux = $nflux; Blocks = $blocks; Unstable = $unst; MaxRun = $run; RunPos = -1 }
}
function New-Track([double]$r3, [double]$r4, [double]$j = 57.0) { return ,@((New-Rev $j $r3 $r4), (New-Rev $j $r3 $r4), (New-Rev $j $r3 $r4)) }
function New-Ms([int]$n, [double]$r3, [double]$r4) { return @(1..$n | ForEach-Object { Get-TrackMetrics (New-Track $r3 $r4) }) }
function New-FakeTracks([int]$n, [int]$seed) {
    # $n pistes (numero gw : 2 x cylindre + tete) de 3 tours, valeurs deterministes (suite congruente en entiers longs,
    # aucun tirage du systeme). Ecarts 3T et 4T de tous les signes et de toutes les classes de couleur ; jitter, erreurs,
    # trous et ecart du nombre de flux qui donnent les trois etats ; une piste illisible (tour sans valeur), une zone
    # instable de 3 blocs, une de 2 blocs ; cellules long track, standard et haute densite. Graine 1 : premiere lecture ;
    # autre graine : relecture ou la plupart des defauts ont disparu
    $d3 = @(0.012, -0.045, -0.020, 0.005, 0.0, 0.043, 0.017, -0.049, 0.060, 0.009, -0.004)
    $d4 = @(0.024, -0.040, 0.010, 0.010, 0.0, 0.068, 0.031, -0.048, -0.055, 0.010, -0.011)
    $jit = @(25.0, 45.0, 70.0, 95.0, 110.0, 60.0, 180.0, 30.0)
    $x = [long]$seed; $t = @{}
    for ($i = 0; $i -lt $n; $i++) {
        $a = ($i + $seed) % $d3.Count
        $ooc = 0.0; $dr = 0.0; $dn = 0; $cell = 1888.0; $bl = 0; $un = 0; $run = 0; $j = $jit[($i + 3 * $seed) % $jit.Count]
        if ($i % 4 -eq 1) { $cell = 2000.0 }
        if ($i -eq 13) { $cell = 1000.0 }
        if ($i -eq 21) { $j = 300.0 }
        if ($seed -eq 1) {
            switch ($i) { 5 { $bl = 100; $un = 4; $run = 3 } 6 { $bl = 100; $un = 2; $run = 2 } 11 { $ooc = 5.0 } 14 { $dr = 1.0 } 17 { $ooc = 25.0 } 19 { $dn = 6 } 23 { $dr = 2.0 } }
        }
        $revs = @()
        for ($r = 0; $r -lt 3; $r++) {
            $x = ($x * 7919 + 104729) % 1000003
            $e = ([double]($x % 21) - 10.0) / 10000.0
            $jv = $j + [double]($x % 7); if ($i -eq 9 -and $r -eq 2) { $jv = [double]::NaN }
            $nf = 40000 + [int]($x % 2); if ($r -eq 1) { $nf += $dn }
            $revs += New-Rev $jv (1.5 + $d3[$a] + $e) (2.0 + $d4[$a] - $e / 2.0) ($ooc + [double]($x % 3)) $dr $cell $nf $bl $un $run
        }
        $t[$i] = $revs
    }
    return $t
}
function Get-Gold($tracks) {
    # Score, etat et asymetrie (millioniemes) de chaque piste, par numero croissant : entiers seulement
    return (@(@($tracks.Keys) | Sort-Object | ForEach-Object { $m = Get-TrackMetrics $tracks[$_]; "$([int]$m.Score)/$([int]$m.Level)/$([int][math]::Round([double]$m.Asym * 1e6))" }) -join ' ')
}

"logic-qualite-asymetrie : $Wt ; ScoreAsymK $($script:ScoreAsymK), AsymSignPct $($script:AsymSignPct) ; PowerShell $($PSVersionTable.PSVersion)$(if ($Before) { ' ; source d avant fournie (-Before)' })"

# ---------------------------------------------------------------- S : signe d une piste, texte de la case
"--- S : signe d une piste et case « Asym. »"
$mS1 = Get-TrackMetrics (New-Track 1.511 2.025); $mS2 = Get-TrackMetrics (New-Track 1.455 1.960)
$mS3 = Get-TrackMetrics (New-Track 1.480 2.010); $mS4 = Get-TrackMetrics (New-Track 1.505 2.010)
$mNul = Get-TrackMetrics (New-Track 1.5 2.0); $mBad = Get-TrackMetrics @()
Chk 'S1' ((Get-AsymSign $mS1) -eq 1 -and (Format-AsymCell $mS1) -ceq '+0,036') "ecarts +0,011 et +0,025 : signe $(Get-AsymSign $mS1), case « $(Format-AsymCell $mS1) » (+0,036 attendu)"
Chk 'S2' ((Get-AsymSign $mS2) -eq -1 -and (Format-AsymCell $mS2) -ceq '-0,085') "ecarts -0,045 et -0,040 : signe $(Get-AsymSign $mS2), case « $(Format-AsymCell $mS2) » (-0,085 attendu)"
Chk 'S3' ((Get-AsymSign $mS3) -eq 0 -and (Format-AsymCell $mS3) -ceq '0,030') "ecarts de sens opposes (-0,020 et +0,010) : signe $(Get-AsymSign $mS3), case sans signe « $(Format-AsymCell $mS3) »"
Chk 'S4' ((Get-AsymSign $mS4) -eq 1 -and (Format-AsymCell $mS4) -ceq '0,015' -and (Get-AlLevel 'asym' $mS4.Asym) -eq 0) "case verte (0,015) : signe $(Get-AsymSign $mS4), case sans signe « $(Format-AsymCell $mS4) »"
Chk 'S5' ((Get-AsymSign $mNul) -eq 0 -and $mBad.Bad -and (Get-AsymSign $mBad) -eq 0 -and (Get-AsymSign $null) -eq 0 -and (Format-AsymCell $mNul) -ceq '0,000') "ecarts nuls, piste illisible, piste absente : signe $(Get-AsymSign $mNul), $(Get-AsymSign $mBad), $(Get-AsymSign $null)"

# ---------------------------------------------------------------- R : resume d un resultat
"--- R : resume d un resultat et sa phrase"
$s1 = Get-AsymSummary (New-Ms 160 1.511 2.025); $t1 = Get-AsymSummaryText $s1
Chk 'R1' ($s1.N -eq 160 -and $s1.Pos -eq 160 -and $s1.Neg -eq 0 -and [math]::Abs($s1.Med - 0.036) -lt 1e-9 -and $s1.Points -eq 72 -and $s1.Kind -ceq '+' -and $t1 -ceq ($kPos -f '160', '160', '0,036', '72')) "160 pistes positives : N $($s1.N), Pos $($s1.Pos), Points $($s1.Points), Kind « $($s1.Kind) » ; $(Get-Short $t1 70)"
$s2 = Get-AsymSummary (@(New-Ms 128 1.511 2.025) + @(New-Ms 32 1.480 2.010))
Chk 'R2' ($s2.N -eq 160 -and $s2.Pos -eq 128 -and $s2.Kind -ceq '+' -and (Get-AsymSummaryText $s2) -ceq ($kPos -f '128', '160', '0,036', "$($s2.Points)")) "128 positives et 32 de sens opposes (80 % exactement) : Kind « $($s2.Kind) », Pos $($s2.Pos) sur $($s2.N)"
$s3 = Get-AsymSummary (@(New-Ms 127 1.511 2.025) + @(New-Ms 33 1.480 2.010)); $t3 = Get-AsymSummaryText $s3; $t3a = Get-AsymSummaryText $s3 -Always
Chk 'R3' ($s3.Pos -eq 127 -and $s3.Kind -ceq '' -and $t3 -ceq '' -and $s3.Points -eq 70 -and $t3a -ceq ($kShort -f '0,036', '70')) "127 positives sur 160 (sous 80 %) : Kind vide, texte vide ; avec -Always : « $t3a »"
$s4 = Get-AsymSummary (New-Ms 160 1.509 2.010)
Chk 'R4' ($s4.Pos -eq 160 -and [math]::Abs($s4.Med - 0.019) -lt 1e-9 -and $s4.Kind -ceq '' -and (Get-AsymSummaryText $s4) -ceq '') "160 pistes positives a 0,019 : mediane en classe verte, Kind vide (Pos $($s4.Pos))"
$s5 = Get-AsymSummary (New-Ms 160 1.455 1.960); $t5 = Get-AsymSummaryText $s5
Chk 'R5' ($s5.Neg -eq 160 -and $s5.Pos -eq 0 -and $s5.Kind -ceq '-' -and $s5.Points -eq 170 -and $t5 -ceq ($kNeg -f '160', '160', '0,085', '170')) "160 pistes negatives : Kind « $($s5.Kind) », Points $($s5.Points) ; $(Get-Short $t5 70)"
$s6 = Get-AsymSummary (@(New-Ms 150 1.511 2.025) + @(1..10 | ForEach-Object { Get-TrackMetrics @() }))
Chk 'R6' ($s6.N -eq 150 -and $s6.Pos -eq 150 -and $s6.Kind -ceq '+' -and $s6.Points -eq 72) "150 positives et 10 illisibles : N $($s6.N), Kind « $($s6.Kind) »"
$s7 = Get-AsymSummary @(); $s7n = Get-AsymSummary $null; $s7b = Get-AsymSummary @((Get-TrackMetrics @()))
Chk 'R7' ($s7.N -eq 0 -and $s7.Kind -ceq '' -and $s7n.N -eq 0 -and $s7b.N -eq 0 -and (Get-AsymSummaryText $s7) -ceq '' -and (Get-AsymSummaryText $s7 -Always) -ceq '' -and (Get-AsymSummaryText $null -Always) -ceq '') "liste vide, absente, ou d une piste illisible : N 0, Kind vide, texte vide meme avec -Always"
$script:Lang = 'en'
$t1e = Get-AsymSummaryText $s1; $t5e = Get-AsymSummaryText $s5; $t3e = Get-AsymSummaryText $s3 -Always
$script:Lang = 'fr'
Chk 'R8' ($t1e -ceq ($ePos -f '160', '160', '0.036', '72') -and $t5e -ceq ($eNeg -f '160', '160', '0.085', '170') -and $t3e -ceq ($eShort -f '0.036', '70')) "interface anglaise : $(Get-Short $t1e 60) ; « $t3e »"

# ---------------------------------------------------------------- N : non-regression du score, correction retiree
"--- N : score inchange, correction retiree"
$n1 = Get-TrackScore @{ J = 57.0; Asym = 0.042; Ooc = 1.33; Dr = 0.0; Stab = 0.0 }
$k0 = $script:ScoreAsymK; $script:ScoreAsymK = 1000; $n1b = Get-TrackScore @{ J = 57.0; Asym = 0.042; Ooc = 1.33; Dr = 0.0; Stab = 0.0 }; $script:ScoreAsymK = $k0
Chk 'N1' ($n1 -eq 148 -and $script:ScoreAsymK -eq 2000 -and $script:AsymSignPct -eq 80 -and $n1b -eq 106) "jitter 57, asymetrie 0,042, 1,33 erreur : score $n1 (148 attendu) ; poids lu dans ScoreAsymK (a 1000 : $n1b)"
$names = @('Set-TrackAsymRef', 'Get-AsymRefs', 'Get-AsymRefTable', 'QualAsymRefOn', 'AsymRaw')
$hits = @()
foreach ($f in (@(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Sort-Object Name) + @(Get-Item -LiteralPath (Join-Path $Wt 'src\GreaseweazleGUI.ps1')))) {
    $txt = [System.IO.File]::ReadAllText($f.FullName)
    foreach ($n in $names) { if ($txt.Contains($n)) { $hits += "$($f.Name) : $n" } }
}
Chk 'N2' (-not $mS1.ContainsKey('AsymRaw') -and -not $mS1.ContainsKey('AsymRef') -and $hits.Count -eq 0) "metriques sans cle AsymRaw ni AsymRef ; fonctions et drapeau de la correction dans les modules et le fichier assemble : $(if ($hits.Count) { $hits -join ' ; ' } else { 'aucun' })"
# Valeurs rendues par Get-TrackMetrics de la source de la 12.10 (c8a3c72) pour New-FakeTracks 32 1 ; Q6 les recalcule
$gold = '274/0/85017 178/0/30450 93/0/14950 185/1/700 267/0/111433 129/0/48033 243/0/97150 313/0/116000 142/0/19250 9999/2/0 141/0/35900 385/1/84883 100/0/30950 67/0/15083 103/1/350 301/0/110800 197/0/47917 434/2/96883 297/0/114950 234/1/19317 68/0/15200 389/2/36250 219/0/85000 241/2/29750 136/0/14817 119/0/450 296/0/111183 284/1/48133 231/0/97033 268/0/114400 91/0/18933 108/0/15050'
$goldNow = Get-Gold (New-FakeTracks 32 1)
Chk 'N3' ($goldNow -ceq $gold) "score, etat et asymetrie de 32 pistes factices = valeurs de la 12.10 ($(@($goldNow -split ' ').Count) pistes ; $(Get-Short $goldNow 60))"

# ---------------------------------------------------------------- E : export
"--- E : export du tableau"
function Set-ResultView {
    $v = $script:QualView
    $v.State = 'result'; $v.Kind = 'measure'; $v.Reason = ''; $v.At = [datetime]::new(2026, 11, 11, 10, 0, 0); $v.Has = $true
    $v.Res = @{ Kind = 'measure'; HealthText = 'SUPPORT SAIN'; ScoreText = 'Qualité de lecture : score 129' }
}
function Get-HeadMap($x) { $h = @{}; foreach ($l in $x.Head) { $h[[string]$l[0]] = [string]$l[1] }; return $h }
Reset-State; Set-ResultView
[void]$lvAl.Items.Add((New-AlignRow '0.0' $mS1 '' '-' -1)); [void]$lvAl.Items.Add((New-AlignRow '0.1' (Get-TrackMetrics (New-Track 1.511 2.025)) '' '-' -1)); [void]$lvAl.Items.Add((New-AlignRow '1.0' $mBad '' '-' -1))
$x = Get-AlignTableExport; $hm = Get-HeadMap $x; $labels = @($x.Head | ForEach-Object { [string]$_[0] })
$iA = [array]::IndexOf($labels, 'Asymétrie')
Chk 'E1' ($iA -ge 0 -and $iA -eq $labels.Count - 2 -and $labels[$labels.Count - 1] -ceq 'Pistes' -and $hm['Asymétrie'] -ceq ($kPos -f '2', '2', '0,036', '72') -and [string]$lvAl.Items[0].SubItems[8].Text -ceq '+0,036' -and [string]$x.Rows[0][8] -ceq '0,036' -and [string]$x.Rows[0][9] -ceq '+0,011' -and [string]$x.Rows[0][10] -ceq '+0,025' -and (@($x.Rows[2]) -join ';') -ceq '1.0;ILLISIBLE;-;-;-;-;-;-;-;-;-;-') "ligne « Asymétrie » avant « Pistes » : $(Get-Short $hm['Asymétrie'] 50) ; ecran « $($lvAl.Items[0].SubItems[8].Text) », export « $($x.Rows[0][8]) », ecarts « $($x.Rows[0][9]) » et « $($x.Rows[0][10]) » ; illisible : $(@($x.Rows[2]) -join ';')"
$lvAl.Items.Clear()
[void]$lvAl.Items.Add((New-AlignRow '0.0' $mS1 '' '-' -1)); [void]$lvAl.Items.Add((New-AlignRow '0.1' $mS3 '' '-' -1))
$hm2 = Get-HeadMap (Get-AlignTableExport)
$script:Lang = 'en'; $hm2e = Get-HeadMap (Get-AlignTableExport); $script:Lang = 'fr'
$lvAl.Items.Clear(); [void]$lvAl.Items.Add((New-AlignRow '1.0' $mBad '' '-' -1))
$hm3 = Get-HeadMap (Get-AlignTableExport)
$lvAl.Items.Clear()
Chk 'E2' ($hm2['Asymétrie'] -ceq ($kShort -f '0,033', '66') -and $hm2e['Asymmetry'] -ceq ($eShort -f '0.033', '66') -and $hm3['Asymétrie'] -ceq '-') "sans signe commun : « $($hm2['Asymétrie']) » ; en anglais : « $($hm2e['Asymmetry']) » ; aucune piste lisible : « $($hm3['Asymétrie']) »"

# ---------------------------------------------------------------- C : la case signee tient dans sa colonne
"--- C : largeur de la case"
$s530 = [System.IO.File]::ReadAllText((Join-Path $mods '530-ui-onglets-techniques.ps1'))
$s500 = [System.IO.File]::ReadAllText((Join-Path $mods '500-fenetre-theme.ps1'))
$mW = [regex]::Match($s530, "@\('Asym\.',\s*(\d+)\)")
$mF = [regex]::Match($s500, "\`$monoBig\s*=\s*New-Object System\.Drawing\.Font\('([^']+)',\s*([0-9.]+)\)")
$c1 = $false; $c1d = 'largeur de la colonne (530) ou police du tableau (500) introuvable'
if ($mW.Success -and $mF.Success) {
    # Draw-AlSubItem (195) : texte dans la largeur de la colonne moins 8 px, une ligne, points de suspension s il depasse
    $font = New-Object System.Drawing.Font($mF.Groups[1].Value, [single][double]::Parse($mF.Groups[2].Value, $inv))
    $bmp = New-Object System.Drawing.Bitmap(200, 40); $g = [System.Drawing.Graphics]::FromImage($bmp)
    $sf = Get-QualSf 'center'; $wCell = [int]$mW.Groups[1].Value - 8; $worst = 0.0; $cut = @()
    foreach ($txt in '+0,150', '-0,085', '+1,234') {
        $w = $g.MeasureString($txt, $font, 1000, $sf).Width; if ($w -gt $worst) { $worst = $w }
        $nc = 0; $nl = 0
        [void]$g.MeasureString($txt, $font, (New-Object System.Drawing.SizeF([single]$wCell, [single]40)), $sf, [ref]$nc, [ref]$nl)
        if ($nc -lt $txt.Length) { $cut += $txt }
    }
    $c1 = ($worst -le $wCell -and $cut.Count -eq 0)
    $c1d = "case signee de 6 caracteres en $($font.Name) $($mF.Groups[2].Value) : $([int][math]::Ceiling($worst)) px pour $wCell px utiles (colonne de $($mW.Groups[1].Value) px) ; textes coupes : $(if ($cut.Count) { $cut -join ' ' } else { 'aucun' })"
    $g.Dispose(); $bmp.Dispose(); $font.Dispose()
}
Chk 'C1' $c1 $c1d

# ---------------------------------------------------------------- J : journal et resultat
"--- J : journal et resultat (mesure, mesure continue, controle)"
function Get-TrackSet([int]$n, [double]$r3, [double]$r4, [int]$from = 0) { $t = @{}; for ($i = 0; $i -lt $n; $i++) { $t[$from + $i] = New-Track $r3 $r4 }; return $t }
function Get-AsymLines { return @($script:RLog | Where-Object { $_ -match 'Asymétrie (positive|négative) sur ' }) }
Reset-State
# 11 pistes et une douzieme a zone instable (3 blocs sur 100) : comptee dans le resume comme les autres
$trJ1 = Get-TrackSet 11 1.511 2.025
$trJ1[11] = @((New-Rev 57.0 1.511 2.025 0 0 1888.0 40000 100 4 3), (New-Rev 57.0 1.511 2.025), (New-Rev 57.0 1.511 2.025))
$script:FakeScp[$script:AlignTmp] = $trJ1
$null = Invoke-AlignAnalysis
$expJ1 = ($kPos -f '12', '12', '0,036', '72')
$log = @($script:RLog); $iScore = -1; $iAsym = -1
for ($i = 0; $i -lt $log.Count; $i++) { if ($log[$i].StartsWith('Mesure : score moyen ')) { $iScore = $i }; if ($log[$i] -ceq "Mesure : $expJ1") { $iAsym = $i } }
$cells = @(@($lvAl.Items) | ForEach-Object { [string]$_.SubItems[8].Text } | Sort-Object -Unique)
Chk 'J1' ($script:LastRes.AsymText -ceq $expJ1 -and $iScore -ge 0 -and $iAsym -eq $iScore + 1 -and @(Get-AsymLines).Count -eq 1 -and $script:LastRes.Score -eq 129 -and ($cells -join ' ') -ceq '+0,036' -and @($script:RLog | Where-Object { $_ -like 'Mesure : zone instable*' }).Count -eq 1) "mesure de 12 pistes positives, dont une a zone instable : phrase dans le resultat, une ligne au journal juste apres le score moyen ($($script:LastRes.Score)) ; cases « $($cells -join ' ') »"
Reset-State; $script:AlignLoop = $true; $script:QualView.Pass = 1
$script:FakeScp[$script:AlignTmp] = Get-TrackSet 12 1.511 2.025
$null = Invoke-AlignAnalysis; $nP1 = @(Get-AsymLines).Count
$script:RLog.Clear(); $script:QualView.Pass = 2
$null = Invoke-AlignAnalysis; $nP2 = @(Get-AsymLines).Count; $resP2 = [string]$script:LastRes.AsymText
Chk 'J2' ($nP1 -eq 1 -and $nP2 -eq 0 -and $resP2 -ceq $expJ1) "mesure continue : $nP1 ligne a la passe 1, $nP2 a la passe 2 ; le resultat de la passe 2 garde la phrase (infobulle, export)"
Reset-State
$mix = Get-TrackSet 6 1.511 2.025; foreach ($i in 6..11) { $mix[$i] = New-Track 1.480 2.010 }
$script:FakeScp[$script:AlignTmp] = $mix
$null = Invoke-AlignAnalysis; $nMix = @(Get-AsymLines).Count; $resMix = [string]$script:LastRes.AsymText
Reset-State
$script:FakeScp[$script:AlignTmp] = @{ 0 = @((New-Rev ([double]::NaN) 1.5 2.0)) }
$null = Invoke-AlignAnalysis
Chk 'J3' ($nMix -eq 0 -and $resMix -ceq '' -and @(Get-AsymLines).Count -eq 0 -and [string]$script:LastRes.AsymText -ceq '' -and $script:LastRes.Bad -eq 1) "sans signe commun (6 positives, 6 de sens opposes), puis une seule piste illisible : aucune ligne, phrase vide"
function New-CheckRep($state) { return @{ State = $state; Rewrites = @{ '0.1' = 2 }; Retries = @{}; Ignore = $null; SrcWeak = $null } }
Reset-State
$st = @{}; foreach ($i in 0..9) { $st["$([math]::Floor($i / 2)).$($i % 2)"] = Get-TrackMetrics (New-Track 1.455 1.960) }
$mMiss = Get-TrackMetrics @(); $mMiss.Missing = $true; $st['5.0'] = $mMiss
$null = Show-WriteCheckTable (New-CheckRep $st)
$expJ4 = ($kNeg -f '10', '10', '0,085', '170')
$cells = @(@($lvAl.Items) | ForEach-Object { [string]$_.SubItems[8].Text } | Sort-Object -Unique)
Chk 'J4' ($script:LastRes.AsymText -ceq $expJ4 -and @(Get-AsymLines).Count -eq 1 -and @($script:RLog) -ccontains "Contrôle après écriture : $expJ4" -and $script:LastRes.Count -eq 10 -and $script:LastRes.Bad -eq 1 -and ($cells -join ' ') -ceq '- -0,085') "controle de 10 pistes negatives et une absente : phrase dans le resultat et une ligne « Contrôle après écriture : ... » ; cases « $($cells -join ' ') »"
Reset-State
$st = @{}; foreach ($i in 0..9) { $r = New-Track 1.511 2.025; if ($i -ge 6) { $r = New-Track 1.480 2.010 }; $st["$([math]::Floor($i / 2)).$($i % 2)"] = Get-TrackMetrics $r }
$null = Show-WriteCheckTable (New-CheckRep $st)
Chk 'J5' ([string]$script:LastRes.AsymText -ceq '' -and @(Get-AsymLines).Count -eq 0 -and $script:LastRes.Count -eq 10) "controle sans signe commun (6 positives sur 10) : aucune ligne, phrase vide"
# Couleur des lignes dans le journal : texte courant, ni erreur ni reserve (aucun mot des motifs de Get-LogColor)
$script:LogColors = @{ cmd = 'cmd'; dim = 'dim'; std = 'std'; ok = 'ok'; warn = 'warn'; err = 'err' }
$cols = @()
foreach ($lang in 'fr', 'en') {
    $script:Lang = $lang
    $cols += [string](Get-LogColor ((T "Mesure : {0}") -f (Get-AsymSummaryText $s1)))
    $cols += [string](Get-LogColor ((T "Contrôle après écriture : {0}") -f (Get-AsymSummaryText $s5)))
}
$script:Lang = 'fr'
Chk 'J6' (($cols -join ' ') -ceq 'std std std std') "couleur des lignes au journal (vraie Get-LogColor), mesure puis controle, en francais puis en anglais : $($cols -join ' ') (texte courant attendu : ni erreur ni reserve)"

# ---------------------------------------------------------------- T : infobulles
"--- T : infobulles"
Reset-State
Update-QualityTip
$tt = [string]$tip.GetToolTip($lvAl); $ttL = @($tt -split "`n")
$script:Lang = 'en'; Update-QualityTip; $ttE = @(([string]$tip.GetToolTip($lvAl)) -split "`n"); $script:Lang = 'fr'
Chk 'T1' ($ttL.Count -eq 5 -and $ttL[4] -ceq $kSign -and $tt.Contains('Asymétrie : <0,02 / <0,05 / <0,10') -and $ttL[3].StartsWith('Erreurs : ') -and $ttE.Count -eq 5 -and $ttE[4] -ceq $eSign) "infobulle du tableau : $($ttL.Count) lignes, la derniere sur le signe, en francais et en anglais"
# Infobulle de la carte : vraie Get-QualityCardModel sur le resultat d une mesure reelle de 12 pistes positives
Reset-State
$script:FakeScp[$script:AlignTmp] = Get-TrackSet 12 1.511 2.025
$null = Invoke-AlignAnalysis
$resT = $script:LastRes; $resT.At = [datetime]::new(2026, 11, 11, 10, 0, 0)
$vT = @{ State = 'result'; Kind = 'measure'; Reason = ''; At = $resT.At; Has = $true; Pass = 0; Drive = '0'; Heads = '0+1'; Revs = 3; NCyl = 6; RunText = ''; Res = $resT }
$tipR = @(([string](Get-QualityCardModel $vT).Tip) -split "`n")
$iS = [array]::IndexOf($tipR, [string]$resT.ScoreText); $iA = [array]::IndexOf($tipR, [string]$resT.AsymText)
$vT.State = 'stale'; $vT.Reason = 'written'
$tipS = @(([string](Get-QualityCardModel $vT).Tip) -split "`n")
$resT.AsymText = ''; $vT.State = 'result'; $vT.Reason = ''
$tipN = @(([string](Get-QualityCardModel $vT).Tip) -split "`n")
Chk 'T2' ($iS -ge 0 -and $iA -eq $iS + 1 -and $tipR[$iA] -ceq $expJ1 -and ($tipS -ccontains $expJ1) -and @($tipN | Where-Object { $_ -like 'Asymétrie *' }).Count -eq 0 -and $tipN.Count -eq $tipR.Count - 1) "infobulle de la carte (vraie Get-QualityCardModel) : phrase de l asymetrie juste apres le texte du score (ligne $($iA + 1) sur $($tipR.Count)), gardee sur un resultat perime, absente sans signe commun"

# ---------------------------------------------------------------- I : table I18n
"--- I : table I18n"
$t019 = [System.IO.File]::ReadAllText((Join-Path $mods '019-i18n-1211.ps1'))
$t018 = [System.IO.File]::ReadAllText((Join-Path $mods '018-i18n-1210.ps1'))
$badKeys = @()
foreach ($p in @(@($kPos, $ePos, 'positive'), @($kNeg, $eNeg, 'negative'), @($kShort, $eShort, 'courte'), @($kSign, $eSign, 'signe'))) {
    $ph1 = (@([regex]::Matches($p[0], '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join '')
    $ph2 = (@([regex]::Matches($p[1], '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join '')
    if (-not ([string]$script:I18n[$p[0]] -ceq $p[1]) -or -not $t019.Contains($p[0]) -or $ph1 -ne $ph2) { $badKeys += $p[2] }
}
Chk 'I1' ($badKeys.Count -eq 0 -and -not $script:I18n.ContainsKey($kOld1) -and -not $script:I18n.ContainsKey($kOld2) -and -not $t018.Contains('biais de lecture') -and [string]$script:I18n['Asymétrie'] -ceq 'Asymmetry') "quatre textes de la specification dans 019, memes jalons : en defaut $(if ($badKeys.Count) { $badKeys -join ', ' } else { 'aucun' }) ; cles de la correction absentes de la table ; « Asymétrie » gardee"

# ---------------------------------------------------------------- Q : equivalence avec la source d avant
"--- Q : equivalence avec la 12.10 (-Before)"
function Format-V($v) {
    # Texte complet d une valeur (nombres decimaux au format aller-retour, tables par cle triee)
    if ($null -eq $v) { return '<nul>' }
    if ($v -is [double] -or $v -is [single]) { return ([double]$v).ToString('R', $inv) }
    if ($v -is [string]) { return $v }
    if ($v -is [System.Collections.IDictionary]) { return '{' + ((@($v.Keys | Sort-Object { "$_" }) | ForEach-Object { "$_=" + (Format-V $v[$_]) }) -join ';') + '}' }
    if ($v -is [System.Collections.IEnumerable]) { return '[' + ((@($v) | ForEach-Object { Format-V $_ }) -join ',') + ']' }
    return "$v"
}
function Get-RowsDigest { return @(@($lvAl.Items) | ForEach-Object { $it = $_; ((0..9 | ForEach-Object { [string]$it.SubItems[$_].Text }) -join '|') + '|' + [string]$it.Tag.State + '|' + [string]$it.Tag.Score }) }
function Get-ResDigest($res) { $h = @{}; foreach ($k in @($res.Keys)) { if ($k -ne 'AsymText') { $h[$k] = $res[$k] } }; return (Format-V $h) }
function Get-ViewDigest { return @{ Rows = @(Get-RowsDigest); Rest = @('derniere ' + (Format-V $script:AlignLast)) + @('resultat ' + (Get-ResDigest $script:LastRes)) + @($script:RLog) + @($script:Calls) } }
function Get-RepDigest($rep) {
    $l = @()
    foreach ($k in (Sort-TrackKeys @($rep.State.Keys))) { $l += "piste $k " + (Format-V $rep.State[$k]) }
    $l += 'faibles ' + (@($rep.Weak) -join ',')
    $l += "passe $($rep.Round)/$($rep.Max) ; garde-fou $($rep.Safety) ; mesurees $($rep.Measured)"
    $l += 'reecrites ' + (Format-V $rep.Rewrites)
    foreach ($c in @($rep.Pending.ToArray())) { $l += 'commande ' + ((@($c) | ForEach-Object { if ("$_" -like '"*.scp"') { Split-Path -Leaf "$_".Trim('"') } else { "$_" } }) -join ' ') }
    $l += 'relectures ' + ((@($rep.Scps) | ForEach-Object { Split-Path -Leaf $_ }) -join ',')
    return @($l) + @($script:RLog) + @($script:Calls)
}
function New-RepRound0 {
    # Controle factice apres l analyse de sa premiere relecture : 33 pistes attendues dont une absente de la relecture,
    # une piste deja critique dans la source et une deja hors norme (ignorees), zone instable jugee defaut de la copie ;
    # effacement haute frequence avant les reecritures. Puis la relecture de la passe 1 est posee (graine 2)
    $scope = @{}; foreach ($i in 0..32) { $scope["$([math]::Floor($i / 2)).$($i % 2)"] = $true }
    $scp0 = Join-Path $here 'controle-0.scp'
    [System.IO.File]::WriteAllBytes($scp0, [byte[]]@())
    $script:FakeScp = @{}; $script:FakeScp[$script:AlignTmp] = @{}; $script:FakeScp[$scp0] = New-FakeTracks 32 1
    $rep = @{ Round = 0; Max = 2; Scps = @($scp0); Scope = $scope; Weak = @(); Rewrites = @{}; Retries = @{}; Written = @{}; State = @{}
              Ignore = @{ '13.1' = $true; '8.1' = $true }; SrcOver = @{ '8.1' = $true }; SrcWeak = @{}; NoJudge = @{}; UnstDefect = $true
              ReadOpts = @(); Base = @('write', '--drive=0', '--precomp=0-9:c=10'); Common = @('--drive=0'); UserTSpec = ''; EraseMode = 'hfreq'; HeadPrecomp = $null
              Pending = (New-Object System.Collections.Queue); Image = 'image-factice.adf'; Safety = $false; Measured = 0 }
    $script:Rep = $rep
    $null = Invoke-WriteCheckAnalysis
    $t2 = New-FakeTracks 33 2; $sel = @{}
    foreach ($k in @($rep.Weak)) { $tn = [int](Get-TrackKeyOrder $k); $sel[$tn] = $t2[$tn] }
    $i = 0
    foreach ($s in @($rep.Scps)) { [System.IO.File]::WriteAllBytes($s, [byte[]]@()); if ($i -eq 0) { $script:FakeScp[$s] = $sel } else { $script:FakeScp[$s] = @{} }; $i++ }
    return $rep
}
$scenario = {
    $o = @{ Corr = [bool](Get-Command 'Set-TrackAsymRef' -ErrorAction SilentlyContinue); Flag = $script:QualAsymRefOn; Gold = (Get-Gold (New-FakeTracks 32 1)) }
    # Mesure : premiere passe, puis seconde avec la premiere pour reference (colonne « vs ref », tendance)
    Reset-State
    $script:FakeScp[$script:AlignTmp] = New-FakeTracks 32 1
    $null = Invoke-AlignAnalysis
    $o.M1 = Get-ViewDigest
    $script:AlignRef = $script:AlignLast; $script:RLog.Clear(); $script:Calls.Clear()
    $script:FakeScp[$script:AlignTmp] = New-FakeTracks 32 2
    $null = Invoke-AlignAnalysis
    $o.M2 = Get-ViewDigest
    # Controle apres ecriture : premiere relecture, remesure des pistes reecrites, tableau final
    Reset-State
    $rep = New-RepRound0
    $o.C0 = Get-RepDigest $rep
    $script:RLog.Clear(); $script:Calls.Clear()
    $null = Invoke-WriteCheckAnalysis
    $o.C1 = Get-RepDigest $rep
    $script:RLog.Clear(); $script:Calls.Clear()
    $null = Show-WriteCheckTable $rep
    $o.T = Get-ViewDigest
    # Passe de reecriture interrompue par gw : une piste faible effacee, non reecrite et non remesuree
    Reset-State
    $rep = New-RepRound0
    $w = @($rep.Weak); $last = [string]$w[$w.Count - 1]
    $script:FakeScp[@($rep.Scps)[0]].Remove([int](Get-TrackKeyOrder $last))
    $script:EraseLog = @{ Owner = 'check'; Round = [int]$rep.Round; Erased = @{ $last = $true }; Written = @{} }
    $script:RLog.Clear(); $script:Calls.Clear()
    $null = Update-RepPartial
    $o.P = Get-RepDigest $rep
    $o.Blank = $last
    return $o
}
function Invoke-InVersion([string]$gen, [scriptblock]$body) {
    # Fonctions d une version chargees dans la portee de cette fonction : elles y masquent celles du script, pour le
    # bloc execute et pour tout ce qu il appelle
    . $gen
    & $body
}
function Compare-Seq($a, $b) {
    # Chaine vide si les deux suites de textes sont identiques, sinon la premiere difference
    $a = @($a); $b = @($b)
    for ($i = 0; $i -lt [math]::Min($a.Count, $b.Count); $i++) { if (-not ([string]$a[$i] -ceq [string]$b[$i])) { return "element $i : « $(Get-Short ([string]$a[$i]) 110) » / « $(Get-Short ([string]$b[$i]) 110) »" } }
    if ($a.Count -ne $b.Count) { return "longueurs $($a.Count) et $($b.Count)" }
    return ''
}
function Remove-CellSign($rows) {
    # Lignes du tableau : signe de la colonne « Asym. » (neuvieme valeur) retire
    return @(@($rows) | ForEach-Object { $p = @($_ -split '\|'); if ($p.Count -ge 12 -and $p[8] -match '^[+-]\d') { $p[8] = $p[8].Substring(1) }; $p -join '|' })
}
function Remove-AsymLines($lines) { return @(@($lines) | Where-Object { $_ -notmatch '^(Mesure|Contrôle après écriture) : Asymétrie (positive|négative) sur ' }) }
function Get-SignCount($rows) { return @(@($rows) | Where-Object { $p = @($_ -split '\|'); $p.Count -ge 12 -and $p[8] -match '^[+-]\d' }).Count }
if (-not $Before) {
    'Q0-Q6    saute : sans -Before <copie de la source de la 12.10>, l equivalence avec la 12.10 n est pas rejouee (N1 et N3 en gardent les valeurs)'
} else {
    if (-not (Test-Path -LiteralPath (Join-Path $Before 'src\modules\190-fn-qualite-alignement.ps1'))) { throw "source d avant introuvable sous $Before" }
    $genOld = Join-Path $here 'gen-avant.ps1'
    $defsOld = New-Gen $Before $genOld $fnOld @() $asgOld
    $a = Invoke-InVersion $genOld $scenario
    $b = Invoke-InVersion $genNew $scenario
    Chk 'Q0' ($a.Corr -and $a.Flag -eq $false -and -not $b.Corr) "source d avant : fonctions de la correction presentes ($($a.Corr)), drapeau QualAsymRefOn $($a.Flag) (livree desactivee), releve du motif pose dans les courbes du lecteur ; source testee : correction absente ($(-not $b.Corr))"
    $d1 = Compare-Seq $a.M1.Rows (Remove-CellSign $b.M1.Rows); $d2 = Compare-Seq $a.M1.Rest (Remove-AsymLines $b.M1.Rest)
    $d3 = Compare-Seq $a.M2.Rows (Remove-CellSign $b.M2.Rows); $d4 = Compare-Seq $a.M2.Rest (Remove-AsymLines $b.M2.Rest)
    $nSig = (Get-SignCount $b.M1.Rows) + (Get-SignCount $b.M2.Rows)
    Chk 'Q1' (-not $d1 -and -not $d2 -and -not $d3 -and -not $d4 -and @($a.M1.Rows).Count -eq 32 -and @($a.M2.Rows).Count -eq 32 -and (Get-SignCount $a.M1.Rows) -eq 0 -and $nSig -gt 0) "mesure, deux passes de 32 pistes : memes lignes du tableau (au signe pres : $nSig cases signees), memes scores, etats, derniere mesure, resultat et journal$(if ($d1 + $d2 + $d3 + $d4) { ' ; ecart : ' + (@($d1, $d2, $d3, $d4) | Where-Object { $_ } | Select-Object -First 1) })"
    $d1 = Compare-Seq $a.C0 $b.C0; $d2 = Compare-Seq $a.C1 $b.C1
    $nCmd = @($a.C0 | Where-Object { $_ -like 'commande *' }).Count; $nCmd1 = @($a.C1 | Where-Object { $_ -like 'commande *' }).Count
    $wk0 = [string](@($a.C0 | Where-Object { $_ -like 'faibles *' })[0]); $wk1 = [string](@($a.C1 | Where-Object { $_ -like 'faibles *' })[0])
    Chk 'Q2' (-not $d1 -and -not $d2 -and $nCmd -ge 3 -and $nCmd1 -ge 3 -and $wk0.Length -gt 12 -and $wk1.Length -gt 8) "controle, relecture puis remesure : meme etat de chaque piste, memes pistes faibles ($(Get-Short $wk0 60) ; puis $wk1), memes commandes en file ($nCmd puis $nCmd1), meme journal$(if ($d1 + $d2) { ' ; ecart : ' + (@($d1, $d2) | Where-Object { $_ } | Select-Object -First 1) })"
    $d1 = Compare-Seq $a.P $b.P
    Chk 'Q3' (-not $d1 -and $a.Blank -ceq $b.Blank -and @($a.P | Where-Object { $_ -like "piste $($a.Blank) *Missing=True*" }).Count -eq 1) "passe interrompue (Update-RepPartial) : meme etat, memes pistes faibles, piste $($a.Blank) effacee et non reecrite comptee absente$(if ($d1) { ' ; ecart : ' + $d1 })"
    $d1 = Compare-Seq $a.T.Rows (Remove-CellSign $b.T.Rows); $d2 = Compare-Seq $a.T.Rest (Remove-AsymLines $b.T.Rest)
    Chk 'Q4' (-not $d1 -and -not $d2 -and @($a.T.Rows).Count -eq 33) "tableau du controle : $(@($a.T.Rows).Count) lignes identiques au signe pres ($(Get-SignCount $b.T.Rows) cases signees), meme derniere mesure, meme resultat$(if ($d1 + $d2) { ' ; ecart : ' + (@($d1, $d2) | Where-Object { $_ } | Select-Object -First 1) })"
    # Texte des fonctions de decision : identique ; Get-TrackMetrics au commentaire de la correction pres ;
    # Invoke-WriteCheckAnalysis et Update-RepPartial aux appels retires pres
    function Get-Lf([string]$s) { return $s.Replace("`r", '') }
    $same = @('Get-HealthLevel', 'Get-AlLevel', 'Get-JitterRedBound', 'Set-CopyUnstable', 'Get-TrackKeyOrder', 'Sort-TrackKeys', 'Get-TrackGroups', 'Get-TSpecExtras', 'Merge-RepRetries', 'Add-RepReads', 'Test-RepFakeIndex', 'Format-CylList')
    $diff = @($same | Where-Object { -not ((Get-Lf $defsOld[$_]) -ceq (Get-Lf $defsNew[$_])) })
    $tmOld = (Get-Lf $defsOld['Get-TrackMetrics']) -replace ' +# 12\.10 : meme formule apres correction de l asymetrie \(Set-TrackAsymRef\)', ''
    $waOld = (Get-Lf $defsOld['Invoke-WriteCheckAnalysis']).Replace('; [void](Set-TrackAsymRef $m ([int][math]::Floor([int]$tn / 2)) ([int]$tn % 2) $arefs) }', ' }')
    $waOld = $waOld -replace '(?m)^ +\$arefs = Get-AsymRefs \(\[string\]\$cmbDrive\.Text\) +# 12\.10 : [^\n]*\n', ''
    $rpOld = (Get-Lf $defsOld['Update-RepPartial']).Replace('; [void](Set-TrackAsymRef $mm ([int][math]::Floor([int]$tn / 2)) ([int]$tn % 2) (Get-AsymRefs ([string]$cmbDrive.Text)))', '')
    if (-not ($tmOld -ceq (Get-Lf $defsNew['Get-TrackMetrics']))) { $diff += 'Get-TrackMetrics' }
    if (-not ($waOld -ceq (Get-Lf $defsNew['Invoke-WriteCheckAnalysis']))) { $diff += 'Invoke-WriteCheckAnalysis' }
    if (-not ($rpOld -ceq (Get-Lf $defsNew['Update-RepPartial']))) { $diff += 'Update-RepPartial' }
    Chk 'Q5' ($diff.Count -eq 0) "$($same.Count) fonctions de decision au caractere pres ; Get-TrackMetrics au commentaire pres ; Invoke-WriteCheckAnalysis et Update-RepPartial aux appels retires pres ; differentes : $(if ($diff.Count) { $diff -join ', ' } else { 'aucune' })"
    Chk 'Q6' ($a.Gold -ceq $gold -and $b.Gold -ceq $gold) "valeurs de N3 = celles que rend la source d avant$(if (-not ($a.Gold -ceq $gold)) { ' ; source d avant : ' + $a.Gold })"
}

$lvAl.Dispose(); $tip.Dispose(); $bold.Dispose()
$nk = ''; if ($script:Fail) { $nk = ' ; non conformes : ' + (@($script:FailIds) -join ', ') }
"=== bilan logic-qualite-asymetrie : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
