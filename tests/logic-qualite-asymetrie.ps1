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
#  N4 a N6  le signe ne change ni l etat d une piste ni les reecritures, sans -Before aussi : etat de chaque ligne du
#           tableau de la mesure (N4), pistes faibles et commandes de reecriture du controle, passe interrompue comprise
#           (N5) : valeurs rendues par la source de la 12.10 ; les fonctions de decision ne lisent ni l asymetrie ni son
#           signe (N6) ;
#  E1, E2   export : ligne « Asymetrie » de l en-tete, colonne « Asym. » sans signe, ecarts signes, piste illisible ;
#  C1       la case signee tient dans la colonne « Asym. » (largeur lue dans 530, police lue dans 500, format de 195) ;
#  J1 a J6  journal et resultat : mesure (Invoke-AlignAnalysis reelle), mesure continue, controle (Show-WriteCheckTable
#           reelle) ; couleur des lignes au journal (Get-LogColor reelle) ;
#  T1, T2   infobulle du tableau (Update-QualityTip reelle, vrai ToolTip jamais affiche) ; infobulle de la carte
#           (Get-QualityCardModel reelle, theme reel de 500) ;
#  I1       table I18n : textes de la specification dans 019, memes jalons {n}, cles de la correction absentes ;
#  X1 a X9  12.11 rc4 (R10) : asymetrie attendue d une ecriture pour un lecteur cible, relue par le lecteur qui a ecrit.
#           X1 Get-AsymExpected et constantes de 040 ; X2 Set-TrackAsymExpected (attendue, ecart, part comptee au score,
#           valeurs mesurees et etat gardes, attendue nulle ou negative, ecarts de sens opposes, piste illisible) ; X3
#           jugement du resume de part et d autre de chaque seuil (conforme, proche, eloignee ; part des pistes dans la
#           classe verte) ; X4 phrases en francais et en anglais, sans lecteur cible : phrases de toujours ; X5 controle
#           (Show-WriteCheckTable reelle) avec l exces memorise a l ecriture : score, couleur de la case, derniere
#           mesure, resultat, journal, et le meme controle sans cette memoire, inchange ; X6 export : deux colonnes en
#           fin de ligne, en-tete, anglais, douze colonnes sans asymetrie attendue ; X7 la mesure simple de l onglet
#           reste inchangee sur les memes pistes, et seul l affichage du controle pose l asymetrie attendue (arbre
#           syntaxique de tous les modules) ; X8 infobulle de la carte et couleur des lignes au journal ; X9 table I18n ;
#  Y1 a Y7  12.11 rc6 (R14) : asymetrie attendue visible dans l onglet. Y1 ecart median en ns (constante du modele) ; Y2
#           ligne de la carte (Show-WriteCheckTable reelle, Get-AsymExpLine) : jugement, medianes, sous- ou
#           sur-compensee d environ N ns, forme courte, anglais, rien sans asymetrie attendue ; Y3 colonnes « Attendue » et
#           « Ecart » du tableau, retirees sans exces memorise, par une mesure et a la reinitialisation ; Y4 carte
#           (Get-QualityCardModel reelle) : ligne, encre du jugement, grisee, mesure sans ligne ; Y5 place de la ligne
#           (Set-QualityCardRoom reelle, positions lues dans 530, vrais controles jamais affiches) ; Y6 textes entiers a la
#           taille par defaut (ligne de la carte, en-tetes et cases des colonnes, polices lues dans 195 et 500) ; Y7 I18n ;
#  Z1 a Z8  12.11 rc7 (R16) : correction par zones, jeu fictif de 160 pistes passe par la vraie Invoke-WriteCheckAnalysis.
#           Z1 piste isolee, deux voisines, 9 cylindres : aucune zone ; 10 cylindres : une zone ; trou de pistes faibles
#           (plus de 2 cylindres : suite coupee) ; Z2 zones, plafond, commandes de la passe 1 ; Z3 acceptation, repli,
#           passe 2, une seule tentative ; Z4 seuils d acceptation, 8 pistes saines relues au moins ; Z5 commandes de la
#           rc6 sans correction, ecriture rapide ; Z6 profil decale, borne de la courbe ecrite (Rep.ZoneHard) ; Z7 verdict,
#           carte (forme sans les zones quand rien d autre ne tient), libelles, passe interrompue par gw ou par
#           « Arreter » (pistes effacees non reecrites dites vierges) ; Z8 I18n ;
#  Q0 a Q7  equivalence avec la 12.10, avec -Before <racine d une copie de la source de la 12.10> (aucune dans le depot ;
#           sans elle, une ligne « saute ») : les memes pistes factices passent par les fonctions des deux versions,
#           chacune chargee dans sa portee. Q1 mesure, deux passes (lignes du tableau au signe pres, derniere mesure,
#           resultat, journal a la phrase nouvelle pres) ; Q2 controle apres ecriture, deux passes (etat de chaque piste,
#           pistes faibles, file des commandes de reecriture et de relecture, journal) ; Q3 passe interrompue
#           (Update-RepPartial) ; Q4 tableau du controle ; Q5 fonctions de decision au caractere pres ; Q6 valeurs de N3 ;
#           Q7 valeurs de N4 et de N5.
# Fonctions reelles extraites par l arbre syntaxique, ecrites dans un fichier de travail, chargees par dot-source ; vrais
# controles WinForms jamais affiches (ListView, ToolTip) ; bouchons pour le journal, la carte, la lecture des fichiers SCP
# et la chaine d etapes. Aucun gw, aucune fenetre, aucune compilation.
# Non couvert : la ligne de journal du controle dans son enchainement reel (Complete-WriteCheck) ; le dessin de la case
# (Draw-AlSubItem) et celui de la carte (Render-QualityCard) ; R10 : la valeur du gain de repli AsymExpGainFallback, des
# tolerances et des parametres des zones (relevees sur trois essais reels, hors depot), l exces memorise par la vraie
# ecriture (logic-cible-facteur, cas X1 a X4) ; l enchainement reel des commandes gw d une correction par zones.
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
# 12.11 rc4 (R10) : ecriture pour un lecteur cible, asymetrie jugee sur son ecart a l attendu ; ligne de l infobulle
$kOk = "Asymétrie conforme à l'attendu pour une écriture destinée au lecteur cible {0} (médiane attendue {1}, mesurée {2} ; relu par le lecteur {3})."
$eOk = 'Asymmetry as expected for a write intended for target drive {0} (median expected {1}, measured {2}; read back by drive {3}).'
$kNear = "Asymétrie proche de l'attendu pour une écriture destinée au lecteur cible {0} (médiane attendue {1}, mesurée {2} ; relu par le lecteur {3})."
$eNear = 'Asymmetry close to the expected one for a write intended for target drive {0} (median expected {1}, measured {2}; read back by drive {3}).'
$kOff = "Asymétrie éloignée de l'attendu pour une écriture destinée au lecteur cible {0} (médiane attendue {1}, mesurée {2} ; relu par le lecteur {3})."
$eOff = 'Asymmetry far from the expected one for a write intended for target drive {0} (median expected {1}, measured {2}; read back by drive {3}).'
$kTail = "L'écart à l'attendu compte pour {0} point(s) du score moyen, au lieu de {1} pour l'asymétrie mesurée, et ne change pas l'état des pistes. La lecture par le lecteur {2} n'est pas prédite."
$eTail = 'The deviation from the expected value accounts for {0} point(s) of the mean score, instead of {1} for the measured asymmetry, and does not change the track status. Reading by drive {2} is not predicted.'
$kTgt = "Contrôle d'une écriture pour un lecteur cible avec le facteur par cylindre : la case « Asym. » garde la valeur mesurée ; sa couleur et le score jugent l'écart à l'asymétrie attendue pour le lecteur qui relit."
$eTgt = 'Check of a write for a target drive with the per-cylinder factor: the "Asym." cell keeps the measured value; its colour and the score judge the deviation from the asymmetry expected for the drive that reads back.'
# Cles de la correction retiree (018 jusqu a la 12.10)
$kOld1 ="Mesure : asymétrie et score corrigés du biais de lecture du lecteur {0} sur {1} piste(s), d'après le motif de sa calibration (famille d'après la cellule mesurée)."
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
# 12.11 rc4 (R10) : Get-AsymExpected et Set-TrackAsymExpected ; New-AlignLastInfo (12.11 rc3) vient ici : rangee avec les
# fonctions communes, elle empechait de charger la source de la 12.10, qui ne l a pas (cas Q, -Before)
$fnNew = @('Get-AsymSign', 'Format-AsymCell', 'Get-AsymSummary', 'Get-AsymSummaryText', 'Get-AsymExpected', 'Set-TrackAsymExpected', 'New-AlignLastInfo',
           'Get-AsymExpLine', 'Set-AlExpColumns', 'Add-AlExpCells',   # 12.11 rc6 (R14) : les trois dernieres
           'Get-AsymExpGain')                                          # 12.11 rc7 (R16)
$fnOld = @('Get-AsymRefTable', 'Get-AsymRefs', 'Set-TrackAsymRef')
$asgCommon = @('$script:HealthErrOk', '$script:JitterStdOk', '$script:JitterStdWatch', '$script:ScpStructMax')
# 12.11 rc7 (R16) : AsymExpGain (2) remplace par AsymExpGainFallback (1,7) ; constantes de la correction par zones
$asgNew = @('$script:ScoreAsymK', '$script:AsymSignPct', '$script:AsymExpGainFallback', '$script:AsymExpOkTol', '$script:AsymExpNearTol', '$script:AsymExpInPct', '$script:QualCardLine3H', '$script:QualCardRoom',   # 12.11 rc4 (R10) : les quatre dernieres
            '$script:WriteZoneHalfWin', '$script:WriteZoneMinNs', '$script:WriteZoneGap', '$script:WriteZoneMinCyl', '$script:WriteZoneMinTracks', '$script:WriteZoneF', '$script:WriteZoneCapNs', '$script:WriteZoneAccept')
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
$defsNew = New-Gen $Wt $genNew $fnNew $asgNew @('$script:CalHardMaxNs')
. $genNew
# 12.11 rc4 (R10) : fonction du controle (170) absente de la source de la 12.10 : chargee a part de $fnCommon, que les
# deux versions partagent ; la vraie Show-WriteCheckTable ne l appelle que pour un controle qui porte Rep.AsymExcess.
# 12.11 rc7 (R16) : de meme les fonctions de la correction par zones (170 ; Get-SpecValue et Build-CurveProfile de 230) ;
# Complete-WriteCheck et (relecture rc7) Stop-WriteCheck reelles, gardees a part (cas Z7, dans une portee avec leurs bouchons)
$fnX = @('Get-RepAsymExcess', 'Get-RepAsymGain', 'Get-AsymGainText', 'Get-WriteZoneGap', 'Get-WriteZoneScan', 'Get-WriteZoneSpec', 'Get-RepHeadSpec', 'Find-WriteZones', 'Format-WriteZone',
         'Start-WriteZonePass', 'Complete-WriteZonePass', 'Get-WriteZoneCount', 'Invoke-RepNextCmd', 'Complete-WriteCheck', 'Stop-WriteCheck')
$defsX = @{}
# 12.11 rc8 (R17) : recalage du lecteur cible (172), appele par Invoke-AlignAnalysis et Complete-WriteCheck ; aucune
# ecriture pour un lecteur cible en memoire ici : sans effet
$fnR = @('Invoke-TargetRecalOffer', 'Get-TargetWriteMemoryFor', 'Complete-TargetWriteMemory')
foreach ($pm in @(@('170-fn-controle-ecriture.ps1', $fnX), @('230-fn-calib-courbe.ps1', @('Get-SpecValue', 'Build-CurveProfile')), @('172-fn-recalage-cible.ps1', $fnR))) {
    foreach ($fd in @((Get-Ast (Join-Path $mods $pm[0])).FindAll({ param($x) $x -is $tFn }, $false))) { if (@($pm[1]) -contains $fd.Name) { $defsX[$fd.Name] = $fd.Extent.Text } }
}
$missX = @(@($fnX + @('Get-SpecValue', 'Build-CurveProfile') + $fnR) | Where-Object { -not $defsX.ContainsKey($_) })
if ($missX.Count -gt 0) { throw "fonctions $($missX -join ', ') introuvables sous $Wt (lots R10 et R16 absents de cette source ?)" }
$genX = Join-Path $here 'gen-r10.ps1'
[System.IO.File]::WriteAllText($genX, ((@($defsX.Keys | Where-Object { @('Invoke-RepNextCmd', 'Complete-WriteCheck', 'Stop-WriteCheck') -notcontains $_ } | Sort-Object | ForEach-Object { $defsX[$_] }) -join "`r`n`r`n") + "`r`n"), $utf8Bom)
. $genX

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
# 12.11 rc4 (R10, adapte a dessein) : six lignes au lieu de cinq ; la derniere dit ce que jugent la couleur de la case et
# le score au controle d une ecriture pour un lecteur cible ; la ligne du signe reste la cinquieme
Chk 'T1' ($ttL.Count -eq 6 -and $ttL[4] -ceq $kSign -and $ttL[5] -ceq $kTgt -and $tt.Contains('Asymétrie : <0,02 / <0,05 / <0,10') -and $ttL[3].StartsWith('Erreurs : ') -and $ttE.Count -eq 6 -and $ttE[4] -ceq $eSign -and $ttE[5] -ceq $eTgt) "infobulle du tableau : $($ttL.Count) lignes, la cinquieme sur le signe, la derniere sur le controle d une ecriture pour un lecteur cible, en francais et en anglais"
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

# ---------------------------------------------------------------- X : asymetrie attendue pour un lecteur cible (R10)
"--- X : asymetrie attendue d une ecriture pour un lecteur cible (12.11 rc4, R10)"
# Jeu fictif : le lecteur « Banc 1 » ecrit pour le lecteur cible « Atelier 2 » et relit ; cellule de 2 000 ns ; exces de
# precompensation de 30 ns (tete 0) et de 40 ns (tete 1) : asymetrie attendue 2 x exces / cellule = 0,030 et 0,040
$forX = @{ Target = 'Atelier 2'; Src = 'Banc 1' }
function New-TrackX([double]$d3, [double]$d4, [double]$cell = 2000.0) { return ,@((New-Rev 57.0 (1.5 + $d3) (2.0 + $d4) 0 0 $cell), (New-Rev 57.0 (1.5 + $d3) (2.0 + $d4) 0 0 $cell), (New-Rev 57.0 (1.5 + $d3) (2.0 + $d4) 0 0 $cell)) }
# 12.11 rc7 (R16) : gain explicite de 2 (la constante des rc4 a rc6) pour garder les valeurs de ces cas ; gain par tete et
# repli de 1,7 : X1 et Y1
function New-MsX([int]$n, [double]$d3, [double]$d4, [double]$excess) { return @(1..$n | ForEach-Object { $m = Get-TrackMetrics (New-TrackX $d3 $d4); Set-TrackAsymExpected $m $excess 2.0; $m }) }
function Test-NearX($a, [double]$b) { return ($null -ne $a -and [math]::Abs([double]$a - $b) -lt 1e-9) }
$x1 = @((Get-AsymExpected 30 2000 2.0), (Get-AsymExpected (-20) 2000 2.0), (Get-AsymExpected 30 1888 2.0))
$x1g = @((Get-AsymExpected 30 2000), (Get-AsymExpected 30 2000 1.63), (Get-AsymExpected 30 2000 0), (Get-AsymExpected 30 2000 (-1)), (Get-AsymExpected 30 2000 ([double]::NaN)), (Get-AsymExpected 30 2000 ([double]::PositiveInfinity)))
$x1b = ((Test-NearX $x1g[0] 0.0255) -and (Test-NearX $x1g[1] 0.02445) -and (Test-NearX $x1g[2] 0.0255) -and (Test-NearX $x1g[3] 0.0255) -and (Test-NearX $x1g[4] 0.0255) -and (Test-NearX $x1g[5] 0.0255) -and [double]$script:AsymExpGainFallback -eq 1.7 -and -not (Get-Variable -Name AsymExpGain -Scope Script -ErrorAction SilentlyContinue))
Chk 'X1' ((Test-NearX $x1[0] 0.030) -and (Test-NearX $x1[1] (-0.020)) -and (Test-NearX $x1[2] (60.0 / 1888)) -and $null -eq (Get-AsymExpected 30 0) -and $null -eq (Get-AsymExpected 30 ([double]::NaN)) -and $x1b -and $script:AsymExpOkTol -eq 0.005 -and $script:AsymExpNearTol -eq 0.02 -and $script:AsymExpInPct -eq 80) "asymetrie attendue = g x exces / cellule, g = 2 : +30 ns sur 2 000 ns -> $($x1[0].ToString('0.000', $inv)), -20 ns -> $($x1[1].ToString('0.000', $inv)), +30 ns sur 1 888 ns -> $($x1[2].ToString('0.0000', $inv)) ; g = 1,63 (2 x pente fictive 0,815) -> $($x1g[1].ToString('0.00000', $inv)) ; sans gain, gain nul, negatif, NaN ou infini : repli 1,7 -> $($x1g[0].ToString('0.0000', $inv)) ($x1b) ; sans cellule mesuree : aucune ; tolerances de 040 : conforme a $($script:AsymExpOkTol), proche a $($script:AsymExpNearTol), $($script:AsymExpInPct) % des pistes"
$mX = Get-TrackMetrics (New-TrackX 0.016 0.018); $rawX = "$([int]$mX.Score)/$([int]$mX.Level)"
Set-TrackAsymExpected $mX 30 2.0
$mZ = Get-TrackMetrics (New-TrackX 0.016 0.018); Set-TrackAsymExpected $mZ 0 2.0
$mNg = Get-TrackMetrics (New-TrackX (-0.012) (-0.010)); $rawNg = [int]$mNg.Score; Set-TrackAsymExpected $mNg (-10) 2.0
$mMx = Get-TrackMetrics (New-TrackX 0.030 (-0.010)); $rawMx = [int]$mMx.Score; Set-TrackAsymExpected $mMx 20 2.0
$mBd = Get-TrackMetrics @(); Set-TrackAsymExpected $mBd 30 2.0; Set-TrackAsymExpected $null 30 2.0
$mC0 = Get-TrackMetrics (New-TrackX 0.016 0.018 0.0); $rawC0 = [int]$mC0.Score; Set-TrackAsymExpected $mC0 30 2.0
$x2a = ($rawX -ceq '125/0' -and (Test-NearX $mX.AsymExp 0.030) -and (Test-NearX $mX.AsymGap 0.004) -and (Test-NearX $mX.AsymDev 0.004) -and [int]$mX.Score -eq 65 -and (Test-NearX $mX.Asym 0.034) -and (Test-NearX $mX.R3 1.516) -and (Test-NearX $mX.R4 2.018) -and [int]$mX.Level -eq 0 -and (Test-NearX $mX.AsymGain 2.0))
$x2b = ((Test-NearX $mZ.AsymExp 0.0) -and (Test-NearX $mZ.AsymDev ([double]$mZ.Asym)) -and [int]$mZ.Score -eq 125)
$x2c = ($rawNg -eq 101 -and (Test-NearX $mNg.AsymExp (-0.010)) -and (Test-NearX $mNg.AsymGap (-0.012)) -and (Test-NearX $mNg.AsymDev 0.012) -and [int]$mNg.Score -eq 81)
$x2d = ($rawMx -eq 137 -and (Test-NearX $mMx.AsymGap 0.0) -and (Test-NearX $mMx.AsymDev 0.040) -and [int]$mMx.Score -eq 137)
$x2e = (-not $mBd.ContainsKey('AsymExp') -and -not $mBd.ContainsKey('AsymDev') -and -not $mC0.ContainsKey('AsymExp') -and [int]$mC0.Score -eq $rawC0)
Chk 'X2' ($x2a -and $x2b -and $x2c -and $x2d -and $x2e) "ecarts +0,016 et +0,018, exces 30 ns : attendue 0,030, ecart +0,004, score $rawX -> $([int]$mX.Score) (65 attendu), asymetrie mesuree, rapports et etat gardes ($x2a) ; attendue nulle : score de toujours ($x2b) ; exces negatif : $rawNg -> $([int]$mNg.Score) ($x2c) ; ecarts de sens opposes, somme egale a l attendue : rien d efface, $rawMx -> $([int]$mMx.Score) ($x2d) ; piste illisible ou sans cellule : rien de pose ($x2e)"
$sOk = Get-AsymSummary (New-MsX 160 0.016 0.018 30)
$sOkEdge = Get-AsymSummary (New-MsX 160 0.017 0.0179 30); $sNearLo = Get-AsymSummary (New-MsX 160 0.017 0.0181 30)
$sNearHi = Get-AsymSummary (New-MsX 160 0.0249 0.025 30); $sOffHi = Get-AsymSummary (New-MsX 160 0.0251 0.025 30)
$sOffLo = Get-AsymSummary (New-MsX 160 0.005 0.005 35)
$sIn127 = Get-AsymSummary (@(New-MsX 127 0.016 0.018 30) + @(New-MsX 33 0.040 (-0.006) 30))
$sIn128 = Get-AsymSummary (@(New-MsX 128 0.016 0.018 30) + @(New-MsX 32 0.040 (-0.006) 30))
$sPlain = Get-AsymSummary (New-Ms 160 1.511 2.025)
$sPart = Get-AsymSummary (@(New-MsX 100 0.016 0.018 30) + @(New-Ms 60 1.511 2.025))
$sNg = Get-AsymSummary (New-MsX 160 (-0.012) (-0.010) (-10))
$x3a = ($sOk.NExp -eq 160 -and $sOk.In -eq 160 -and $sOk.Judge -ceq 'ok' -and (Test-NearX $sOk.ExpMed 0.030) -and (Test-NearX $sOk.MeasMed 0.034) -and (Test-NearX $sOk.GapMed 0.004) -and $sOk.DevPoints -eq 8 -and $sOk.Points -eq 68 -and $sOk.Kind -ceq '+')
$x3b = ($sOkEdge.Judge -ceq 'ok' -and $sNearLo.Judge -ceq 'near' -and $sNearHi.Judge -ceq 'near' -and $sOffHi.Judge -ceq 'off' -and $sOffLo.Judge -ceq 'off' -and (Test-NearX $sOffLo.GapMed (-0.025)) -and $sNg.Judge -ceq 'near')
$x3c = ($sIn127.In -eq 127 -and $sIn127.Judge -ceq 'near' -and (Test-NearX $sIn127.GapMed 0.004) -and $sIn127.DevPoints -eq 25 -and $sIn128.In -eq 128 -and $sIn128.Judge -ceq 'ok')
$x3d = ($sPlain.NExp -eq 0 -and $sPlain.Judge -ceq '' -and $sPlain.Points -eq 72 -and $sPart.N -eq 160 -and $sPart.NExp -eq 100 -and $sPart.DevPoints -eq 32)
# Relecture : jugement tete par tete (AsymHead, pose par Show-WriteCheckTable), le moins bon des deux garde : un ecart
# propre a une tete n est pas dilue par l autre. Jeu fictif, 80 pistes par tete. Sans le jugement par tete, les quatre
# premiers resumes donnaient 'near', 'ok', 'ok' et 'ok' (ecart median et part de pistes vertes de l ensemble)
function New-MsH([string]$head, [int]$n, [double]$d3, [double]$d4, [double]$excess) { return @(New-MsX $n $d3 $d4 $excess | ForEach-Object { $_.AsymHead = $head; $_ }) }
$sHead = Get-AsymSummary (@(New-MsH '0' 80 0.016 0.018 30) + @(New-MsH '1' 80 0.029 0.031 30))
$sHeadNear = Get-AsymSummary (@(New-MsH '0' 80 0.015 0.015 30) + @(New-MsH '1' 80 0.018 0.020 30))
$sHeadIn63 = Get-AsymSummary (@(New-MsH '0' 80 0.016 0.018 30) + @(New-MsH '1' 63 0.016 0.018 30) + @(New-MsH '1' 17 0.040 (-0.006) 30))
$sHeadIn64 = Get-AsymSummary (@(New-MsH '0' 80 0.016 0.018 30) + @(New-MsH '1' 64 0.016 0.018 30) + @(New-MsH '1' 16 0.040 (-0.006) 30))
$sHeadOk = Get-AsymSummary (@(New-MsH '0' 80 0.016 0.018 30) + @(New-MsH '1' 80 0.017 0.0179 30))
$sHeadOne = Get-AsymSummary (New-MsH '1' 80 0.029 0.031 30)
$x3e = ((Test-NearX $sHead.GapMed 0.017) -and $sHead.Judge -ceq 'off' -and (Test-NearX $sHeadNear.GapMed 0.004) -and $sHeadNear.In -eq 160 -and $sHeadNear.Judge -ceq 'near' -and
        $sHeadIn63.In -eq 143 -and (Test-NearX $sHeadIn63.GapMed 0.004) -and $sHeadIn63.Judge -ceq 'near' -and $sHeadIn64.In -eq 144 -and $sHeadIn64.Judge -ceq 'ok' -and $sHeadOk.Judge -ceq 'ok' -and $sHeadOne.Judge -ceq 'off' -and $sHead.NExp -eq 160)
Chk 'X3' ($x3a -and $x3b -and $x3c -and $x3d -and $x3e) "jugement tete par tete, le moins bon garde : une tete a +0,004 et l autre a +0,030 (ecart median de l ensemble 0,017) : « $($sHead.Judge) » ; une tete a 0 et l autre a +0,008 (ensemble 0,004) : « $($sHeadNear.Judge) » ; une tete a 63 puis 64 pistes vertes sur 80 (ensemble 143 et 144 sur 160) : « $($sHeadIn63.Judge) » puis « $($sHeadIn64.Judge) » ; deux tetes conformes : « $($sHeadOk.Judge) » ; une seule tete ecrite : « $($sHeadOne.Judge) » ($x3e) ; 160 pistes a +0,004 de l attendue : « $($sOk.Judge) », $($sOk.DevPoints) point(s) sur l ecart au lieu de $($sOk.Points) ($x3a) ; ecart median 0,0049 / 0,0051 / 0,0199 / 0,0201 / -0,025 : $($sOkEdge.Judge) / $($sNearLo.Judge) / $($sNearHi.Judge) / $($sOffHi.Judge) / $($sOffLo.Judge) ($x3b) ; meme ecart median, 127 puis 128 pistes sur 160 dans la classe verte : $($sIn127.Judge) puis $($sIn128.Judge) ($x3c) ; sans asymetrie attendue : jugement vide, resume de toujours ; 100 pistes sur 160 avec : part du score $($sPart.DevPoints) ($x3d)"
$tOk = Get-AsymSummaryText $sOk -For $forX; $tNear = Get-AsymSummaryText $sNearLo -For $forX; $tOff = Get-AsymSummaryText $sOffLo -For $forX; $tNg = Get-AsymSummaryText $sNg -For $forX -Always
$expOk = ($kOk -f 'Atelier 2', '+0,030', '+0,034', 'Banc 1') + ' ' + ($kTail -f '8', '68', 'Atelier 2')
$expNear = ($kNear -f 'Atelier 2', '+0,030', '+0,035', 'Banc 1') + ' ' + ($kTail -f '10', '70', 'Atelier 2')
$expOff = ($kOff -f 'Atelier 2', '+0,035', '+0,010', 'Banc 1') + ' ' + ($kTail -f '50', '20', 'Atelier 2')
$expNg = ($kNear -f 'Atelier 2', '-0,010', '-0,022', 'Banc 1') + ' ' + ($kTail -f '24', '44', 'Atelier 2')
$script:Lang = 'en'
$tOkE = Get-AsymSummaryText $sOk -For $forX; $tNearE = Get-AsymSummaryText $sNearLo -For $forX; $tOffE = Get-AsymSummaryText $sOffLo -For $forX
$script:Lang = 'fr'
$x4a = ($tOk -ceq $expOk -and $tNear -ceq $expNear -and $tOff -ceq $expOff -and $tNg -ceq $expNg)
$x4b = ($tOkE -ceq (($eOk -f 'Atelier 2', '+0.030', '+0.034', 'Banc 1') + ' ' + ($eTail -f '8', '68', 'Atelier 2')) -and $tNearE -ceq (($eNear -f 'Atelier 2', '+0.030', '+0.035', 'Banc 1') + ' ' + ($eTail -f '10', '70', 'Atelier 2')) -and $tOffE -ceq (($eOff -f 'Atelier 2', '+0.035', '+0.010', 'Banc 1') + ' ' + ($eTail -f '50', '20', 'Atelier 2')))
$x4c = ((Get-AsymSummaryText $sOk) -ceq ($kPos -f '160', '160', '0,034', '68') -and (Get-AsymSummaryText $sPlain -For $forX) -ceq ($kPos -f '160', '160', '0,036', '72') -and (Get-AsymSummaryText (Get-AsymSummary @()) -For $forX) -ceq '')
$x4d = (@($tOk, $tNear, $tOff) | Where-Object { $_ -notlike "*La lecture par le lecteur Atelier 2 n'est pas prédite." -or $_ -notlike '*relu par le lecteur Banc 1*' }).Count -eq 0
Chk 'X4' ($x4a -and $x4b -and $x4c -and $x4d) "phrases du jugement, lecteur cible et lecteur qui relit nommes, medianes signees : $(Get-Short $tOk 150) ($x4a) ; en anglais ($x4b) ; sans lecteur cible ou sans asymetrie attendue : phrases de toujours ($x4c) ; chacune dit que la lecture par le lecteur cible n est pas predite ($x4d)"
function New-StateX {
    # Dix pistes lisibles (cinq cylindres, deux tetes) et une absente ; metriques neuves a chaque appel
    $st = @{}
    foreach ($c in 0..4) { $st["$c.0"] = Get-TrackMetrics (New-TrackX 0.016 0.018); $st["$c.1"] = Get-TrackMetrics (New-TrackX 0.021 0.023) }
    $mm = Get-TrackMetrics @(); $mm.Missing = $true; $st['5.0'] = $mm
    return $st
}
function New-CheckRepX($excess) {
    # Controle d une ecriture pour le lecteur cible ; $excess : memoire de l ecriture (par tete, exces par cylindre)
    # 12.11 rc7 (R16) : gain de 2 par tete (Rep.AsymGain) : valeurs des rc4 a rc6 gardees ; repli sans lui : Y1
    $r = @{ State = (New-StateX); Rewrites = @{}; Retries = @{}; Ignore = $null; SrcWeak = $null; Target = 'Atelier 2'; TargetSrc = 'Banc 1' }
    if ($excess) { $r.AsymExcess = $excess; $r.AsymGain = @{ 0 = 2.0; 1 = 2.0 } }
    return $r
}
function Get-CellsX { return @(@($lvAl.Items) | ForEach-Object { $it = $_; "$([string]$it.SubItems[0].Text)=$([string]$it.SubItems[8].Text)/$([string]$it.SubItems[6].Text)/" + $(if ($it.SubItems.Count -gt 8) { [string]([array]::IndexOf(@(0..3 | ForEach-Object { $script:AlColors[$_].ToArgb() }), $it.SubItems[8].BackColor.ToArgb())) } else { '' }) }) }
Reset-State
# Tete 1 : tableau de deux cylindres seulement ; au-dela, la derniere valeur (les profils y sont constants)
$repX = New-CheckRepX @{ 0 = [int[]]@(30, 30, 30, 30, 30, 30); 1 = [int[]]@(40, 40) }
$null = Show-WriteCheckTable $repX
$resX = $script:LastRes; $logX = @($script:RLog); $lastX = $script:AlignLast; $cellsX = @(Get-CellsX)
$expX5 = ($kOk -f 'Atelier 2', '+0,035', '+0,039', 'Banc 1') + ' ' + ($kTail -f '8', '78', 'Atelier 2')
$wantCells = @(foreach ($c in 0..4) { "$c.0=+0,034/65/0"; "$c.1=+0,044/65/0" }) + @('5.0=-/-/-1')
$x5a = (($cellsX -join ' ') -ceq ($wantCells -join ' '))
$x5b = ($resX.Score -eq 65 -and $resX.Count -eq 10 -and $resX.Bad -eq 1 -and [string]$resX.AsymText -ceq $expX5 -and $resX.AsymFor -and [string]$resX.AsymFor.Target -ceq 'Atelier 2' -and [string]$resX.AsymFor.Src -ceq 'Banc 1' -and ($logX -ccontains "Contrôle après écriture : $expX5") -and @(Get-AsymLines).Count -eq 0)
$x5c = ([int]$lastX['0.0'].Score -eq 65 -and [int]$lastX['4.1'].Score -eq 65 -and (Test-NearX $lastX['0.1'].Asym 0.044) -and (Test-NearX $repX.State['4.1'].AsymExp 0.040) -and (Test-NearX $repX.State['4.0'].AsymExp 0.030) -and (Test-NearX $repX.State['0.1'].Asym 0.044) -and [int]$repX.State['0.1'].Level -eq 0 -and -not $repX.State['5.0'].ContainsKey('AsymExp'))
Reset-State
$repL = New-CheckRepX $null
$null = Show-WriteCheckTable $repL
$resL = $script:LastRes; $cellsL = @(Get-CellsX)
$wantCellsL = @(foreach ($c in 0..4) { "$c.0=+0,034/125/1"; "$c.1=+0,044/145/1" }) + @('5.0=-/-/-1')
$expL = ($kPos -f '10', '10', '0,039', '78')
$x5d = (($cellsL -join ' ') -ceq ($wantCellsL -join ' ') -and $resL.Score -eq 135 -and [string]$resL.AsymText -ceq $expL -and -not $resL.ContainsKey('AsymFor') -and @($repL.State.Values | Where-Object { $_.ContainsKey('AsymExp') }).Count -eq 0 -and (@($script:RLog) -ccontains "Contrôle après écriture : $expL"))
# Relecture : la vraie Show-WriteCheckTable pose la tete de chaque piste a asymetrie attendue (AsymHead) ; exces de 20 ns
# seulement pour la tete 1 (attendue 0,020, mesuree 0,044 : ecart +0,024, au-dela de « proche ») : la phrase dit
# « eloignee », alors que l ecart median des dix pistes (0,014) aurait donne « proche »
$x5e0 = ([string]$repX.State['4.1'].AsymHead -ceq '1' -and [string]$repX.State['4.0'].AsymHead -ceq '0' -and -not $repX.State['5.0'].ContainsKey('AsymHead') -and @($repL.State.Values | Where-Object { $_.ContainsKey('AsymHead') }).Count -eq 0)
Reset-State
$repH = New-CheckRepX @{ 0 = [int[]]@(30); 1 = [int[]]@(20) }
$null = Show-WriteCheckTable $repH
$resH = $script:LastRes
$sumH = Get-AsymSummary @($repH.State.Values)
$expH = ($kOff -f 'Atelier 2', '+0,025', '+0,039', 'Banc 1') + ' ' + ($kTail -f '28', '78', 'Atelier 2')
$x5e = ($x5e0 -and (Test-NearX $sumH.GapMed 0.014) -and $sumH.Judge -ceq 'off' -and [string]$resH.AsymText -ceq $expH -and (@($script:RLog) -ccontains "Contrôle après écriture : $expH"))
Chk 'X5' ($x5a -and $x5b -and $x5c -and $x5d -and $x5e) "tete de chaque piste posee avec l asymetrie attendue, et une tete eloignee de l attendu (exces 30 ns tete 0, 20 ns tete 1 : ecart median de l ensemble 0,014) : phrase « eloignee » au resultat et au journal ($x5e) ; controle d une ecriture pour « Atelier 2 » relue par « Banc 1 », exces memorise (30 ns tete 0, 40 ns tete 1) : cases a la valeur mesuree et vertes, score 65 par piste ($x5a) ; score moyen $($resX.Score), phrase « conforme » au resultat et au journal, lecteurs gardes avec le resultat ($x5b) ; derniere mesure au score affiche, asymetrie mesuree et etat gardes, cylindre au-dela du tableau : derniere valeur ($x5c) ; meme controle sans cette memoire : score moyen $($resL.Score), cases de la couleur de la valeur mesuree, phrase de toujours ($x5d)"
# Export du controle : tableau et resultat de X5 (avec exces memorise), puis sans
function Set-CheckViewX($res) { $v = $script:QualView; $v.State = 'result'; $v.Kind = 'check'; $v.Reason = ''; $v.At = [datetime]::new(2026, 11, 11, 10, 0, 0); $v.Has = $true; $v.Res = $res }
function Get-RowX($x, [string]$lab) { return @(@($x.Rows) | Where-Object { [string]$_[0] -ceq $lab })[0] }
Reset-State
$null = Show-WriteCheckTable (New-CheckRepX @{ 0 = [int[]]@(30, 30, 30, 30, 30, 30); 1 = [int[]]@(40, 40) })
Set-CheckViewX $script:LastRes
$xX = Get-AlignTableExport; $hmX = Get-HeadMap $xX
$script:Lang = 'en'; $xXe = Get-AlignTableExport; $hmXe = Get-HeadMap $xXe; $script:Lang = 'fr'
$r00 = Get-RowX $xX '0.0'; $r01 = Get-RowX $xX '0.1'; $r50 = Get-RowX $xX '5.0'
$x6a = (@($xX.Cols).Count -eq 14 -and [string]$xX.Cols[11] -ceq 'Cellule ns' -and [string]$xX.Cols[12] -ceq 'Asym. attendue' -and [string]$xX.Cols[13] -ceq "Écart à l'attendu" -and @($xX.Rows | Where-Object { @($_).Count -ne 14 }).Count -eq 0 -and @($xX.Rows).Count -eq 11)
$x6b = ((@($r00[6], $r00[8], $r00[9], $r00[10], $r00[11], $r00[12], $r00[13]) -join ' ') -ceq '65 0,034 +0,016 +0,018 2000 +0,030 +0,004' -and (@($r01[8], $r01[12], $r01[13]) -join ' ') -ceq '0,044 +0,040 +0,004' -and (@($r50[12], $r50[13]) -join ' ') -ceq '- -')
$x6c = ($hmX['Asymétrie'] -ceq $expX5 -and [string]$xXe.Cols[12] -ceq 'Expected asym.' -and [string]$xXe.Cols[13] -ceq 'Deviation from expected' -and $hmXe['Asymmetry'] -ceq (($eOk -f 'Atelier 2', '+0.035', '+0.039', 'Banc 1') + ' ' + ($eTail -f '8', '78', 'Atelier 2')))
Reset-State
$null = Show-WriteCheckTable (New-CheckRepX $null)
Set-CheckViewX $script:LastRes
$xL = Get-AlignTableExport; $hmL = Get-HeadMap $xL; $rL0 = Get-RowX $xL '0.0'
$x6d = (@($xL.Cols).Count -eq 12 -and @($xL.Rows | Where-Object { @($_).Count -ne 12 }).Count -eq 0 -and $hmL['Asymétrie'] -ceq $expL -and [string]$rL0[6] -ceq '125')
Chk 'X6' ($x6a -and $x6b -and $x6c -and $x6d) "export du controle : $(@($xX.Cols).Count) colonnes, « Asym. attendue » et « Écart à l'attendu » en fin de ligne ($x6a) ; piste 0.0 : $(@($r00[6], $r00[8], $r00[12], $r00[13]) -join ' ; '), piste absente « - » ($x6b) ; en-tete « Asymétrie » : la phrase du journal, colonnes et phrase en anglais ($x6c) ; sans exces memorise : $(@($xL.Cols).Count) colonnes, phrase et score de toujours ($x6d)"
# Mesure simple de l onglet sur les memes pistes (aucune memoire de l ecriture) : inchangee
Reset-State
$trX = @{}; foreach ($c in 0..4) { $trX[2 * $c] = New-TrackX 0.016 0.018; $trX[2 * $c + 1] = New-TrackX 0.021 0.023 }
$script:FakeScp[$script:AlignTmp] = $trX
$null = Invoke-AlignAnalysis
$resM = $script:LastRes; $cellsM = @(Get-CellsX)
$wantCellsM = @(foreach ($c in 0..4) { "$c.0=+0,034/125/1"; "$c.1=+0,044/145/1" })
$x7a = (($cellsM -join ' ') -ceq ($wantCellsM -join ' ') -and $resM.Score -eq 135 -and [string]$resM.AsymText -ceq $expL -and -not $resM.ContainsKey('AsymFor') -and @(@($lvAl.Items) | Where-Object { $_.Tag.M.ContainsKey('AsymExp') }).Count -eq 0)
# Arbre syntaxique de tous les modules : seul l affichage du controle pose l asymetrie attendue ; l exces n est ecrit que
# par l ecriture et lu que par le controle ; la mesure de l onglet et les fonctions de decision n y touchent pas
$tCmd = [System.Management.Automation.Language.CommandAst]; $tMem = [System.Management.Automation.Language.MemberExpressionAst]
$callX = @(); $useX = @()
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Sort-Object Name)) {
    foreach ($fd in @((Get-Ast $f.FullName).FindAll({ param($x) $x -is $tFn }, $true))) {
        if (@($fd.Body.FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'Set-TrackAsymExpected' }, $true)).Count) { $callX += $fd.Name }
        if (@($fd.Body.FindAll({ param($x) $x -is $tMem -and $x.Member.Extent.Text -eq 'AsymExcess' }, $true)).Count) { $useX += $fd.Name }
    }
}
$callX = @($callX | Sort-Object -Unique); $useX = @($useX | Sort-Object -Unique)
$measX = @(@('Invoke-AlignAnalysis', 'Get-TrackMetrics') | Where-Object { $defsNew[$_] -match 'AsymExp|AsymFor|AsymExcess|AsymDev|AsymGap' })
# 12.11 rc7 (R16) : Find-WriteZones lit aussi la presence de l exces (correction par zones d une ecriture pour un lecteur cible)
$x7b = (($callX -join ',') -ceq 'Show-WriteCheckTable' -and ($useX -join ',') -ceq 'Find-WriteZones,Get-RepAsymExcess,Show-WriteCheckTable,Start-ImageWrite' -and $measX.Count -eq 0)
Chk 'X7' ($x7a -and $x7b) "mesure simple de l onglet sur les memes pistes : score moyen $($resM.Score), cases de la couleur de la valeur mesuree, phrase de toujours, aucune asymetrie attendue ($x7a) ; Set-TrackAsymExpected appelee par : $($callX -join ', ') ; exces memorise ecrit ou lu par : $($useX -join ', ') ; la mesure et les metriques d une piste n en lisent rien ($x7b)"
# Infobulle de la carte et couleur des lignes au journal
$resX.At = [datetime]::new(2026, 11, 11, 10, 0, 0)
$vX = @{ State = 'result'; Kind = 'check'; Reason = ''; At = $resX.At; Has = $true; Pass = 0; Drive = ''; Heads = ''; Revs = 0; NCyl = 0; RunText = ''; Res = $resX }
$tipX = @(([string](Get-QualityCardModel $vX).Tip) -split "`n")
$iSX = [array]::IndexOf($tipX, [string]$resX.ScoreText); $iAX = [array]::IndexOf($tipX, $expX5)
$colsX = @()
foreach ($lang in 'fr', 'en') {
    $script:Lang = $lang
    foreach ($s in @($sOk, $sNearLo, $sOffLo)) { $colsX += [string](Get-LogColor ((T "Contrôle après écriture : {0}") -f (Get-AsymSummaryText $s -For $forX))) }
}
$script:Lang = 'fr'
Chk 'X8' ($iSX -ge 0 -and $iAX -eq $iSX + 1 -and ($colsX -join ' ') -ceq 'std std std std std std') "infobulle de la carte (vraie Get-QualityCardModel) : phrase du jugement juste apres le texte du score (ligne $($iAX + 1) sur $($tipX.Count)) ; couleur au journal des trois jugements, en francais puis en anglais : $($colsX -join ' ') (texte courant attendu)"
$iRc4 = $t019.IndexOf('# --- rc4 :'); $badX = @()
foreach ($p in @(@($kOk, $eOk, 'conforme'), @($kNear, $eNear, 'proche'), @($kOff, $eOff, 'eloignee'), @($kTail, $eTail, 'part du score'), @($kTgt, $eTgt, 'infobulle'), @('Asym. attendue', 'Expected asym.', 'colonne 13'), @("Écart à l'attendu", 'Deviation from expected', 'colonne 14'))) {
    $ph1 = (@([regex]::Matches($p[0], '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join '')
    $ph2 = (@([regex]::Matches($p[1], '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join '')
    if (-not ([string]$script:I18n[$p[0]] -ceq $p[1]) -or $iRc4 -lt 0 -or $t019.IndexOf($p[0], [System.StringComparison]::Ordinal) -lt $iRc4 -or $ph1 -ne $ph2) { $badX += $p[2] }
}
Chk 'X9' ($badX.Count -eq 0) "sept textes du lot dans la section « rc4 » de 019, memes jalons : en defaut $(if ($badX.Count) { $badX -join ', ' } else { 'aucun' })"

# ---------------------------------------------------------------- Y : asymetrie attendue dans l onglet (R14)
"--- Y : asymetrie attendue dans l onglet (12.11 rc6, R14)"
# Fonctions de la carte (195) absentes de la source de la 12.10 : chargees a part, comme Get-RepAsymExcess
$fdY = @((Get-Ast (Join-Path $mods '195-fn-qualite-affichage.ps1')).FindAll({ param($x) $x -is $tFn -and @('Set-QualityCardRoom', 'Get-QualFitText', 'Update-QualityView', 'Render-QualityCard') -contains $x.Name }, $false))
$defsY = @{}; foreach ($fd in $fdY) { $defsY[$fd.Name] = $fd.Extent.Text }
$genY = Join-Path $here 'gen-r14.ps1'
[System.IO.File]::WriteAllText($genY, (($defsY['Set-QualityCardRoom'], $defsY['Get-QualFitText']) -join "`r`n`r`n") + "`r`n", $utf8Bom)
. $genY
# Y1 : ecart median en ns (constante du modele) : X5 (ecart +0,004 partout, cellule 2000 ns) : 4 ns ; $repH (tete 0 +0,004,
# tete 1 +0,024) : mediane de 4 et 24 = 14 ns ; exces de 60 ns (attendue 0,060, mesurees 0,034 et 0,044) : -21 ns
Reset-State
$null = Show-WriteCheckTable (New-CheckRepX @{ 0 = [int[]]@(60); 1 = [int[]]@(60) })
$resU = $script:LastRes; $colsU = @(@($lvAl.Columns) | ForEach-Object { "$($_.Text)/$($_.Width)" })
$rowU0 = @(@($lvAl.Items) | Where-Object { $_.SubItems[0].Text -ceq '0.0' })[0]; $rowU5 = @(@($lvAl.Items) | Where-Object { $_.SubItems[0].Text -ceq '5.0' })[0]
$sumX = Get-AsymSummary @((New-CheckRepX $null).State.Values | ForEach-Object { $_ })
# 12.11 rc7 (R16) : gain de chaque piste (AsymGain) : sans Rep.AsymGain, repli 1,7 (attendue 1,7 x 60 / 2000 = 0,051 ;
# ecarts -0,017 et -0,007 : -20 et -8,2 ns, mediane -14,1 ns) ; gains differents par tete (1,6 et 1,8 : attendues 0,024
# et 0,027, ecarts +0,010 et +0,017 : +12,5 et +18,9 ns, mediane +15,7 ns)
$repF = New-CheckRepX @{ 0 = [int[]]@(60); 1 = [int[]]@(60) }; $repF.Remove('AsymGain'); $null = Show-WriteCheckTable $repF; $sumF = Get-AsymSummary @($repF.State.Values)
$repG = New-CheckRepX @{ 0 = [int[]]@(30); 1 = [int[]]@(30) }; $repG.AsymGain = @{ 0 = 1.6; 1 = 1.8 }; $null = Show-WriteCheckTable $repG; $sumG = Get-AsymSummary @($repG.State.Values)
$y1b = ((Test-NearX $repF.State['0.0'].AsymGain 1.7) -and (Test-NearX $repF.State['0.0'].AsymExp 0.051) -and [math]::Abs([double]$sumF.GapNs - (-14.117647)) -lt 1e-5 -and
        (Test-NearX $repG.State['2.0'].AsymExp 0.024) -and (Test-NearX $repG.State['2.1'].AsymExp 0.027) -and [math]::Abs([double]$sumG.GapNs - ((12.5 + 18.888889) / 2)) -lt 1e-5)
$y1 = ((Test-NearX $sumH.GapNs 14.0) -and (Test-NearX (Get-AsymSummary @($repX.State.Values)).GapNs 4.0) -and -not $sumX.ContainsKey('GapNs') -and $y1b)
Chk 'Y1' $y1 "ecart median a l attendu en ns, ecart x cellule / g de chaque piste : gain 2 : $($sumH.GapNs) ns (14 attendu) ; sans gain memorise, repli 1,7 : $(([double]$sumF.GapNs).ToString('0.0', $inv)) ns (-14,1 attendu) ; gains 1,6 et 1,8 par tete : $(([double]$sumG.GapNs).ToString('0.0', $inv)) ns (+15,7 attendu) ($y1b) ; sans asymetrie attendue : aucun"
# Y2 : ligne de la carte (vraie Show-WriteCheckTable puis Get-AsymExpLine) : jugement, medianes signees, sens et taille
$wOk = "Lecteur cible Atelier 2 : asymétrie conforme à l'attendu (attendue +0,035, mesurée +0,039)"
$wOff = "Lecteur cible Atelier 2 : asymétrie éloignée de l'attendu (attendue +0,025, mesurée +0,039) ; disquette sur-compensée d'environ 14 ns"
$wOffS = "Asymétrie éloignée de l'attendu (attendue +0,025, mesurée +0,039) ; disquette sur-compensée pour le lecteur cible d'environ 14 ns"
$wU = "Lecteur cible Atelier 2 : asymétrie éloignée de l'attendu (attendue +0,060, mesurée +0,039) ; disquette sous-compensée d'environ 21 ns"
$sNearY = @{ N = 10; NExp = 10; Judge = 'near'; ExpMed = 0.051; MeasMed = 0.040; GapNs = -0.3 }
$y2a = ([string]$resX.AsymLine -ceq $wOk -and [string]$resX.AsymJudge -ceq 'ok' -and [string]$resX.AsymLineShort -ceq "Asymétrie conforme à l'attendu (attendue +0,035, mesurée +0,039)" -and [string]$resH.AsymLine -ceq $wOff -and [string]$resH.AsymLineShort -ceq $wOffS -and [string]$resH.AsymJudge -ceq 'off' -and [string]$resU.AsymLine -ceq $wU)
$y2b = ((Get-AsymExpLine $sNearY $forX) -ceq "Lecteur cible Atelier 2 : asymétrie proche de l'attendu (attendue +0,051, mesurée +0,040) ; disquette sous-compensée d'environ 1 ns" -and (Get-AsymExpLine $sNearY $null) -ceq '' -and (Get-AsymExpLine $sumX $forX) -ceq '' -and (Get-AsymExpLine $null $forX) -ceq '')
$y2c = ([string]$resL.AsymLine -ceq '' -and [string]$resL.AsymJudge -ceq '' -and -not $resM.ContainsKey('AsymLine') -and -not (([string]$resX.AsymLine + [string]$resH.AsymLine + $wU) -match 'score|lira|prédit'))
$script:Lang = 'en'
$y2d = ((Get-AsymExpLine $sumH $forX) -ceq 'Target drive Atelier 2: asymmetry far from the expected one (expected +0.025, measured +0.039); disk over-compensated by about 14 ns' -and (Get-AsymExpLine $sumH $forX -Short) -ceq 'Asymmetry far from the expected one (expected +0.025, measured +0.039); disk over-compensated for the target drive by about 14 ns' -and (Get-AsymExpLine $sNearY $forX -Short) -ceq 'Asymmetry close to the expected one (expected +0.051, measured +0.040); disk under-compensated for the target drive by about 1 ns')
$script:Lang = 'fr'
Chk 'Y2' ($y2a -and $y2b -and $y2c -and $y2d) "ligne de la carte : « $wOk » ($y2a) ; « proche », taille au moins 1 ns, sans lecteur cible ou sans asymetrie attendue : rien ($y2b) ; controle sans exces memorise et mesure : aucune ligne, aucune prediction du lecteur cible ($y2c) ; anglais, formes longue et courte ($y2d)"
# Y3 : colonnes du tableau : en fin de ligne avec un exces memorise, retirees sans lui, par une mesure et a la reinitialisation
$base10 = 'Piste/60 État/222 Erreurs/60 Trous/60 Stab/60 Jitter ns/60 Score/60 vs réf/60 Asym./60 Cell ns/60'
$y3a = (($colsU -join ' ') -ceq ($base10 + ' Attendue/80 Écart/70') -and (@(0..11 | ForEach-Object { $rowU0.SubItems[$_].Text })[10, 11] -join ' ') -ceq '+0,060 -0,026' -and ($rowU5.SubItems.Count -eq 12) -and ($rowU5.SubItems[10].Text + ' ' + $rowU5.SubItems[11].Text) -ceq '- -' -and @(@($lvAl.Items) | Where-Object { $_.SubItems.Count -ne 12 }).Count -eq 0)
$null = Show-WriteCheckTable (New-CheckRepX $null)
$y3b = ((@(@($lvAl.Columns) | ForEach-Object { "$($_.Text)/$($_.Width)" }) -join ' ') -ceq $base10 -and @(@($lvAl.Items) | Where-Object { $_.SubItems.Count -ne 10 }).Count -eq 0)
$null = Show-WriteCheckTable (New-CheckRepX @{ 0 = [int[]]@(30); 1 = [int[]]@(40) }); $nAfterX = $lvAl.Columns.Count
$null = Show-WriteCheckTable (New-CheckRepX @{ 0 = [int[]]@(30); 1 = [int[]]@(40) }); $nAgain = $lvAl.Columns.Count
$script:FakeScp[$script:AlignTmp] = $trX
$null = Invoke-AlignAnalysis
$y3c = ($nAfterX -eq 12 -and $nAgain -eq 12 -and $lvAl.Columns.Count -eq 10 -and ((@(@($lvAl.Columns) | ForEach-Object { "$($_.Text)/$($_.Width)" }) -join ' ') -ceq $base10))
Set-AlExpColumns $true; Set-AlExpColumns $false
$y3d = ($lvAl.Columns.Count -eq 10 -and [regex]::IsMatch($s530, '\$lvAl\.Items\.Clear\(\); Set-AlExpColumns \$false'))
Chk 'Y3' ($y3a -and $y3b -and $y3c -and $y3d) "colonnes « Attendue » et « Écart » en fin de ligne (attendue, ecart signes ; piste absente « - ») ($y3a) ; controle sans exces : colonnes de toujours ($y3b) ; deux controles de suite : $nAfterX puis $nAgain colonnes, puis mesure : $($lvAl.Columns.Count) ($y3c) ; retrait idempotent et au bouton Reinitialiser de 530 ($y3d)"
# Y4 : carte (vraie Get-QualityCardModel) : ligne et encre du jugement ; grise et perimee ; mesure : aucune
$cY = Get-QualityCardModel $vX
$vH = @{} + $vX; $resH.At = $resX.At; $vH.Res = $resH; $cH = Get-QualityCardModel $vH
$vS = @{} + $vH; $vS.State = 'stale'; $vS.Reason = 'written'; $cS = Get-QualityCardModel $vS
$resM.At = $resX.At; $vM = @{} + $vX; $vM.Kind = 'measure'; $vM.Res = $resM; $cM = Get-QualityCardModel $vM
$y4 = ([string]$cY.Line3 -ceq $wOk -and $cY.Line3Ink.ToArgb() -eq (Get-QualInk 0).ToArgb() -and [string]$cH.Line3 -ceq $wOff -and [string]$cH.Line3Short -ceq $wOffS -and $cH.Line3Ink.ToArgb() -eq (Get-QualInk 3).ToArgb() -and
       [string]$cS.Line3 -ceq $wOff -and $cS.Line3Ink.ToArgb() -eq (Get-QualDimInk).ToArgb() -and [string]$cM.Line3 -ceq '' -and ([string]$cH.Access).EndsWith($wOff) -and -not ([string]$cM.Access).Contains('attendu') -and [string]$cH.State -ceq [string]$cY.State)
Chk 'Y4' $y4 "carte du controle : ligne « conforme » en vert, « eloignee » en rouge, grisee si perimee, reprise par le nom accessible ; mesure : aucune ligne ; etat (COPIE SAINE...) inchange"
# Y5 : place de la ligne : la carte grandit, la ligne du guide et le tableau descendent (bas du tableau fixe) ; positions de
# toujours (530) sans elle
$pos = @{}
foreach ($n in 'pnlQualCard', 'lblAlReco', 'lvAl') { $mm = [regex]::Match($s530, "\`$$n\.Location = '(\d+),(\d+)'; \`$$n\.Size = '(\d+),(\d+)'"); if ($mm.Success) { $pos[$n] = @([int]$mm.Groups[2].Value, [int]$mm.Groups[4].Value) } }
$y5 = $false; $y5d = 'positions introuvables dans 530'
if ($pos.Count -eq 3) {
    $lvKeep = $lvAl
    $pnlQualCard = New-Object System.Windows.Forms.Panel; $pnlQualCard.Top = $pos.pnlQualCard[0]; $pnlQualCard.Height = $pos.pnlQualCard[1]
    $lblAlReco = New-Object System.Windows.Forms.Label; $lblAlReco.Top = $pos.lblAlReco[0]; $lblAlReco.Height = $pos.lblAlReco[1]
    $lvAl = New-Object System.Windows.Forms.ListView; $lvAl.Top = $pos.lvAl[0]; $lvAl.Height = $pos.lvAl[1]
    $script:QualCardRoom = 0
    $snap = { "$($pnlQualCard.Top)/$($pnlQualCard.Height) $($lblAlReco.Top) $($lvAl.Top)/$($lvAl.Height)/$($lvAl.Bottom)" }
    $p0 = & $snap; Set-QualityCardRoom $false; $p1 = & $snap; Set-QualityCardRoom $true; $p2 = & $snap; Set-QualityCardRoom $true; $p3 = & $snap; Set-QualityCardRoom $false; $p4 = & $snap
    $bot = $pos.lvAl[0] + $pos.lvAl[1]
    $want2 = "$($pos.pnlQualCard[0])/$($pos.pnlQualCard[1] + 20) $($pos.lblAlReco[0] + 20) $($pos.lvAl[0] + 20)/$($pos.lvAl[1] - 20)/$bot"
    $y5 = ($p1 -ceq $p0 -and $p2 -ceq $want2 -and $p3 -ceq $p2 -and $p4 -ceq $p0 -and [int]$script:QualCardLine3H -eq 20 -and
           [regex]::IsMatch($defsY['Update-QualityView'], 'Get-QualityCardModel \$script:QualView\s+Set-QualityCardRoom \(\[bool\]\$script:QualCard\.Line3\)') -and
           $pos.pnlQualCard[0] + $pos.pnlQualCard[1] + 20 -le $pos.lblAlReco[0] + 20)
    $y5d = "sans ligne : $p0 (inchange : $($p1 -ceq $p0)) ; avec : $p2 ($want2 attendu) ; deuxieme appel : inchange ; retour : $p4"
    $lvAl = $lvKeep; $pnlQualCard = $null; $lblAlReco = $null; $script:QualCardRoom = 0
}
Chk 'Y5' $y5 $y5d
# Y6 : textes entiers a la taille par defaut : ligne de la carte (police et largeur lues dans 195 et 530), en francais et en
# anglais ; nom de lecteur long : forme courte ; en-tetes et cases des colonnes (polices de 500, largeurs de Set-AlExpColumns)
$mCard = [regex]::Match($s530, "\`$pnlQualCard\.Size = '(\d+),")
$okSrc = ($mCard.Success -and $defsY['Render-QualityCard'] -match "\`$fSmall = Get-QualFont 'Segoe UI' 8\.25" -and $defsY['Render-QualityCard'] -match 'Get-QualFitText \$m\.Line3 \$m\.Line3Short \$fSmall \(\$w - 22\) \$m\.Line3More')
$y6 = $false; $y6d = 'police ou largeur de la carte introuvable'
if ($okSrc) {
    $avail = [int]$mCard.Groups[1].Value - 22
    $fS = New-Object System.Drawing.Font('Segoe UI', [single]8.25)
    $tfY = [System.Windows.Forms.TextFormatFlags]::NoPrefix -bor [System.Windows.Forms.TextFormatFlags]::SingleLine
    $wid = { param($s) [System.Windows.Forms.TextRenderer]::MeasureText($s, $fS, (New-Object System.Drawing.Size(32000, 100)), $tfY).Width }
    $sW = @{ N = 160; NExp = 160; Judge = 'off'; ExpMed = -0.123; MeasMed = -0.456; GapNs = 128.4 }
    $forW = @{ Target = 'Lecteur B-235'; Src = 'Banc 1' }; $forL = @{ Target = ('Lecteur au nom vraiment très long ' * 2); Src = 'Banc 1' }
    $worstL = 0; $worstS = 0; $longPick = @(); $zoneCut = @()
    foreach ($lang in 'fr', 'en') {
        $script:Lang = $lang
        foreach ($g in 128.4, -128.4) {
            $sW.GapNs = $g
            $lw = & $wid (Get-AsymExpLine $sW $forW); if ($lw -gt $worstL) { $worstL = $lw }
            $sl = Get-AsymExpLine $sW $forL -Short; $swd = & $wid $sl; if ($swd -gt $worstS) { $worstS = $swd }
            if ((Get-QualFitText (Get-AsymExpLine $sW $forL) $sl $fS $avail) -cne $sl) { $longPick += "$lang/$g" }
            # Relecture rc7 (R16) : zones corrigees a la suite (formes de Show-WriteCheckTable, 170) : la forme retenue tient
            $zt = (T ' ; zones corrigées : {0} sur {1}') -f '10', '10'; $sb = Get-AsymExpLine $sW $forW -Short
            $zPick = Get-QualFitText ((Get-AsymExpLine $sW $forW) + $zt) ($sb + $zt) $fS $avail @($sb)
            if ((& $wid $zPick) -gt $avail) { $zoneCut += "$lang/$g" }
        }
    }
    $script:Lang = 'fr'
    $mB = [regex]::Match($s500, "\`$bold\s*=\s*New-Object System\.Drawing\.Font\('([^']+)',\s*([0-9.]+),\s*\[System\.Drawing\.FontStyle\]::Bold\)")
    $mWc = [regex]::Matches($defsNew['Set-AlExpColumns'], "Columns\.Add\(\(T '([^']+)'\),\s*(\d+)\)")
    $cutC = @()
    if ($mB.Success -and $mF.Success -and $mWc.Count -eq 2) {
        $fB = New-Object System.Drawing.Font($mB.Groups[1].Value, [single][double]::Parse($mB.Groups[2].Value, $inv), [System.Drawing.FontStyle]::Bold)
        $fM = New-Object System.Drawing.Font($mF.Groups[1].Value, [single][double]::Parse($mF.Groups[2].Value, $inv))
        $bmp = New-Object System.Drawing.Bitmap(200, 40); $gr = [System.Drawing.Graphics]::FromImage($bmp)
        foreach ($mc in $mWc) {
            $cw = [int]$mc.Groups[2].Value - 8
            foreach ($lang in 'fr', 'en') { $script:Lang = $lang; $h = (T $mc.Groups[1].Value); if ($gr.MeasureString($h, $fB, 1000, (Get-QualSf 'hcenter')).Width -gt $cw) { $cutC += $h } }
            foreach ($v in '+0,123', '-0,456', '+0.123') { if ($gr.MeasureString($v, $fM, 1000, (Get-QualSf 'center')).Width -gt $cw) { $cutC += $v } }
        }
        $script:Lang = 'fr'; $gr.Dispose(); $bmp.Dispose(); $fB.Dispose(); $fM.Dispose()
    } else { $cutC += 'polices ou colonnes introuvables' }
    $y6 = ($worstL -le $avail -and $worstS -le $avail -and $longPick.Count -eq 0 -and $cutC.Count -eq 0 -and $zoneCut.Count -eq 0)
    $y6d = "ligne de la carte, lecteur « Lecteur B-235 », valeurs a 3 decimales et 128 ns, francais et anglais : $worstL px ; forme courte : $worstS px ; pour $avail px utiles ; nom long : forme courte retenue (en defaut : $(if ($longPick.Count) { $longPick -join ' ' } else { 'aucun' })) ; avec « zones corrigees : 10 sur 10 » : forme retenue entiere (en defaut : $(if ($zoneCut.Count) { $zoneCut -join ' ' } else { 'aucun' })) ; en-tetes et cases des colonnes coupes : $(if ($cutC.Count) { $cutC -join ', ' } else { 'aucun' })"
    $fS.Dispose()
}
Chk 'Y6' $y6 $y6d
# Y7 : table I18n : textes du lot dans la section « rc6 » R14 de 019, memes jalons
$iRc6 = $t019.IndexOf('# --- rc6 : asymetrie attendue'); $badY = @()
foreach ($p in @(
    @("Lecteur cible {0} : asymétrie conforme à l'attendu (attendue {1}, mesurée {2})", 'Target drive {0}: asymmetry as expected (expected {1}, measured {2})'),
    @("Lecteur cible {0} : asymétrie proche de l'attendu (attendue {1}, mesurée {2})", 'Target drive {0}: asymmetry close to the expected one (expected {1}, measured {2})'),
    @("Lecteur cible {0} : asymétrie éloignée de l'attendu (attendue {1}, mesurée {2})", 'Target drive {0}: asymmetry far from the expected one (expected {1}, measured {2})'),
    @("Asymétrie conforme à l'attendu (attendue {0}, mesurée {1})", 'Asymmetry as expected (expected {0}, measured {1})'),
    @("Asymétrie proche de l'attendu (attendue {0}, mesurée {1})", 'Asymmetry close to the expected one (expected {0}, measured {1})'),
    @("Asymétrie éloignée de l'attendu (attendue {0}, mesurée {1})", 'Asymmetry far from the expected one (expected {0}, measured {1})'),
    @("disquette sous-compensée d'environ {0} ns", 'disk under-compensated by about {0} ns'), @("disquette sur-compensée d'environ {0} ns", 'disk over-compensated by about {0} ns'),
    @("disquette sous-compensée pour le lecteur cible d'environ {0} ns", 'disk under-compensated for the target drive by about {0} ns'),
    @("disquette sur-compensée pour le lecteur cible d'environ {0} ns", 'disk over-compensated for the target drive by about {0} ns'),
    @('{0} ; {1}', '{0}; {1}'), @('Attendue', 'Expected'), @('Écart', 'Gap'))) {
    $ph1 = (@([regex]::Matches($p[0], '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join '')
    $ph2 = (@([regex]::Matches($p[1], '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join '')
    $at = $t019.IndexOf("I18n[" + $(if ($p[0].Contains("'")) { '"' + $p[0] + '"' } else { "'" + $p[0] + "'" }) + "]", [System.StringComparison]::Ordinal)
    if (-not ([string]$script:I18n[$p[0]] -ceq $p[1]) -or $iRc6 -lt 0 -or $at -lt $iRc6 -or $ph1 -ne $ph2) { $badY += $p[0] }
}
Chk 'Y7' ($badY.Count -eq 0) "treize textes du lot dans la section « rc6 » (R14) de 019, memes jalons : en defaut $(if ($badY.Count) { $badY -join ' | ' } else { 'aucun' })"

# ---------------------------------------------------------------- Z : correction par zones (R16)
"--- Z : correction par zones d une ecriture pour un lecteur cible (12.11 rc7, R16)"
# Jeu fictif : « Banc 1 » ecrit pour « Atelier 2 » et relit ; 80 cylindres, deux tetes, cellule de 2 000 ns, exces de 30 ns
# partout, gains 1,6 (tete 0) et 1,8 (tete 1). Chaque piste porte l ecart e voulu (ns) a son attendue : ecarts 3T et 4T
# egaux, chacun g x (30 + e) / 2 / 2000. Pistes faibles : 6 erreurs par tour. Commandes en file relevees apres la vraie
# Invoke-WriteCheckAnalysis (Start-RepPending : bouchon), relectures posees par le test
$zG = @{ 0 = 1.6; 1 = 1.8 }
function New-ZTrack([double]$g, [double]$e, [double]$ooc) { $s = $g * (30.0 + $e) / 2000.0 / 2; return ,@((New-Rev 57.0 (1.5 + $s) (2.0 + $s) $ooc 0 2000.0), (New-Rev 57.0 (1.5 + $s) (2.0 + $s) $ooc 0 2000.0), (New-Rev 57.0 (1.5 + $s) (2.0 + $s) $ooc 0 2000.0)) }
function New-ZTracks([scriptblock]$ef, $weak) {
    $t = @{}
    foreach ($c in 0..79) { foreach ($h in 0, 1) { $t[2 * $c + $h] = New-ZTrack $zG[$h] ([double](& $ef $c $h)) $(if (@($weak) -contains "$c.$h") { 6.0 } else { 0.0 }) } }
    return $t
}
function New-ZRep([scriptblock]$ef, $weak = @(), [hashtable]$set = @{}) {
    Reset-State
    $scope = @{}; foreach ($c in 0..79) { $scope["$c.0"] = $true; $scope["$c.1"] = $true }
    $scp0 = Join-Path $here 'zones-0.scp'; [System.IO.File]::WriteAllBytes($scp0, [byte[]]@())
    $script:FakeScp = @{}; $script:FakeScp[$scp0] = New-ZTracks $ef $weak
    $ex = [int[]]@(1..80 | ForEach-Object { 30 })
    $rep = @{ Round = 0; Max = 3; Scps = @($scp0); Scope = $scope; Weak = @(); Rewrites = @{}; Retries = @{}; Written = @{}; State = @{}
              Ignore = $null; SrcOver = $null; SrcWeak = @{}; NoJudge = @{}; UnstDefect = $true; ReadOpts = @(); Base = @('write', '--drive=0', '--retries=10')
              Common = @('--drive=0'); UserTSpec = ''; EraseMode = 'hfreq'; HeadPrecomp = @{ 0 = '0=40:40=80'; 1 = '0=0:10=60' }
              Pending = (New-Object System.Collections.Queue); Image = 'image-factice.adf'; Safety = $false; Measured = 0
              Target = 'Atelier 2'; TargetSrc = 'Banc 1'; AsymExcess = @{ 0 = $ex; 1 = $ex }; AsymGain = @{ 0 = 1.6; 1 = 1.8 }; ZoneFix = $true }
    foreach ($k in @($set.Keys)) { if ($null -eq $set[$k]) { $rep.Remove($k) } else { $rep[$k] = $set[$k] } }
    $script:Rep = $rep
    return $rep
}
function Set-ZReads($rep, [scriptblock]$ef, $weak = @()) {
    # Relecture de la passe : pistes de Rep.Weak dans le premier fichier de relecture, rien dans les autres
    $all = New-ZTracks $ef $weak; $sel = @{}
    foreach ($k in @($rep.Weak)) { $tn = [int](Get-TrackKeyOrder $k); $sel[$tn] = $all[$tn] }
    $i = 0
    foreach ($s in @($rep.Scps)) { [System.IO.File]::WriteAllBytes($s, [byte[]]@()); $script:FakeScp[$s] = $(if ($i -eq 0) { $sel } else { @{} }); $i++ }
}
function Get-ZCmds($rep) { return @(@($rep.Pending.ToArray()) | ForEach-Object { (@($_) | ForEach-Object { if ("$_" -like '"*.scp"') { Split-Path -Leaf "$_".Trim('"') } else { "$_" } }) -join ' ' }) }
function Get-ZZones($rep) { return ((@($rep.Zones) | Where-Object { $_ } | ForEach-Object { "h$($_.H) c$($_.C0)-$($_.C1) $(([double]$_.E0).ToString('0.0', $inv)) $($_.Dz) $($_.State)" }) -join ' ; ') }
function Get-ZCyl([int[]]$cs) { return Format-CylList $cs }
$zFlat = { param($c, $h) 0 }

# Z1 : piste isolee, deux pistes voisines, suite de 9 cylindres : jamais de zone ; meme a 40 ns
$zIso = { param($c, $h) if ($h -eq 0 -and $c -eq 30) { 40 } elseif ($h -eq 1 -and ($c -eq 50 -or $c -eq 51)) { -40 } elseif ($h -eq 1 -and $c -ge 10 -and $c -le 18) { 20 } else { 0 } }
$r1z = New-ZRep $zIso
$null = Invoke-WriteCheckAnalysis
$z1a = ((Get-ZZones $r1z) -ceq '' -and $r1z.Pending.Count -eq 0 -and $r1z.Round -eq 0 -and @($script:Calls) -ccontains 'Complete-WriteCheck' -and [string]$r1z.HeadPrecomp[0] -ceq '0=40:40=80')
$zTen = { param($c, $h) if ($h -eq 1 -and $c -ge 10 -and $c -le 19) { 20 } else { 0 } }
$r1t = New-ZRep $zTen
$null = Invoke-WriteCheckAnalysis
$z1t = @(Get-WriteZoneScan $r1t)
$z1b = ($z1t.Count -eq 1 -and [int]$z1t[0].H -eq 1 -and [int]$z1t[0].C0 -eq 10 -and [int]$z1t[0].C1 -eq 19 -and [int]$z1t[0].Dz -eq -10 -and (Get-ZZones $r1t) -ceq 'h1 c10-19 20.0 -10 pending')
# Relecture rc7 : cylindres sans piste retenue (pistes faibles) au milieu d une suite : 3 (plus de 2) la coupent en deux
# suites trop courtes (c10-14 et c18-24 : aucune zone) ; 2 la laissent entiere (c10-24, 13 pistes retenues)
$zHole = { param($c, $h) if ($h -eq 0 -and $c -ge 10 -and $c -le 24) { 20 } else { 0 } }
$r1h = New-ZRep $zHole @('15.0', '16.0', '17.0')
$null = Invoke-WriteCheckAnalysis
$z1h3 = @(Get-WriteZoneScan $r1h)
$r1h = New-ZRep $zHole @('15.0', '16.0')
$null = Invoke-WriteCheckAnalysis
$z1h2 = @(Get-WriteZoneScan $r1h)
$z1c = ($z1h3.Count -eq 0 -and $z1h2.Count -eq 1 -and [int]$z1h2[0].C0 -eq 10 -and [int]$z1h2[0].C1 -eq 24 -and [int]$z1h2[0].N -eq 13)
Chk 'Z1' ($z1a -and $z1b -and $z1c) "piste isolee a +40 ns (30.0), deux voisines a -40 ns (50.1 et 51.1), suite de 9 cylindres a +20 ns (c10-18 tete 1) : aucune zone, aucune commande, controle termine ($z1a) ; la meme suite sur 10 cylindres : zone c10-19 tete 1, correction -10 ns, reecrite ($z1b) ; c10-24 a +20 ns avec 3 pistes faibles au milieu : $($z1h3.Count) zone ; avec 2 : $(@($z1h2 | ForEach-Object { "c$($_.C0)-$($_.C1), $($_.N) pistes" }) -join ' ; ') ($z1c)"

# Z2 : zones detectees, correction bornee et plafonnee ; une piste isolee et deux voisines dans une zone ne la cassent pas ;
# commandes gw exactes de la passe 1 (pistes faibles dans et hors zone)
$zMain = { param($c, $h)
    if ($h -eq 0 -and ($c -eq 24 -or $c -eq 33 -or $c -eq 34)) { return -40 }
    if ($h -eq 0 -and $c -ge 20 -and $c -le 39) { return 14 }
    if ($h -eq 0 -and $c -ge 50 -and $c -le 69) { return 40 }
    if ($h -eq 1 -and $c -le 19) { return -20 }
    if ($h -eq 1 -and ($c -eq 50 -or $c -eq 51)) { return 40 }
    return 0 }
$zWeak = @('25.0', '45.0', '60.1')
$r2 = New-ZRep $zMain $zWeak
$null = Invoke-WriteCheckAnalysis
$c0 = Get-ZCyl ([int[]]@(@(20..39) + @(45) + @(50..69))); $c1 = Get-ZCyl ([int[]]@(@(0..19) + @(60))); $c0r = Get-ZCyl ([int[]]@(@(20..39) + @(45) + @(50..59) + @(61..69)))
# Relectures : groupes exacts de Get-TrackGroups (c60 a ses deux faces a relire : 60.0 dans une zone, 60.1 faible)
$want2 = @("erase --drive=0 --hfreq --tracks=c=$($c0):h=0", "write --drive=0 --retries=10 --precomp 0=40:20=33:40=80:50=65:70=80 --tracks=c=$($c0):h=0 `"image-factice.adf`"",
           "erase --drive=0 --hfreq --tracks=c=$($c1):h=1", "write --drive=0 --retries=10 --precomp 0=0:10=70:20=60 --tracks=c=$($c1):h=1 `"image-factice.adf`"",
           "read --drive=0 --revs=3 --tracks=c=60:h=0-1 check-r1-0.scp", "read --drive=0 --revs=3 --tracks=c=$($c0r):h=0 check-r1-1.scp", "read --drive=0 --revs=3 --tracks=c=0-19:h=1 check-r1-2.scp")
$cmd2 = @(Get-ZCmds $r2)
$z2a = ((Get-ZZones $r2) -ceq 'h0 c20-39 14.0 -7 pending ; h0 c50-69 40.0 -15 pending ; h1 c0-19 -20.0 10 pending' -and $r2.Round -eq 1 -and $r2.ZonePass -and @($r2.Weak).Count -eq 62)
$z2b = (($cmd2 -join "`n") -ceq ($want2 -join "`n") -and [string]$r2.HeadPrecompOrig[0] -ceq '0=40:40=80' -and [string]$r2.HeadPrecompOrig[1] -ceq '0=0:10=60')
$det2 = "Contrôle après écriture : 3 zone(s) écartée(s) de l'attendu à la relecture par le lecteur Banc 1 (tête 0 c20-39 : écart médian +14,0 ns, correction -7 ns ; tête 0 c50-69 : écart médian +40,0 ns, correction -15 ns ; tête 1 c0-19 : écart médian -20,0 ns, correction +10 ns). Leurs 60 piste(s) sont réécrites à la passe 1/3 avec la précompensation décalée sur ces cylindres, puis relues ; une zone qui ne se rapproche pas de l'attendu reprend sa courbe d'origine."
$z2c = (@($script:RLog) -ccontains $det2 -and @($script:RLog) -ccontains "Réécriture des pistes faibles, passe 1/3 : 25.0, 45.0, 60.1" -and @($script:RLog | Where-Object { $_ -like 'Effacement haute fréquence des pistes à réécrire (pistes faibles et zones*' }).Count -eq 1)
Chk 'Z2' ($z2a -and $z2b -and $z2c) "zones : $(Get-ZZones $r2) (+40 ns : correction plafonnee a -15 ns ; piste isolee et paire a -40 ns dans c20-39 sans effet ; paire de la tete 1 ignoree ; courbe nulle de c0-9 gardee nulle) ($z2a) ; commandes de la passe 1 : effacement, reecriture par tete avec la courbe decalee sur les zones (piste faible 25.0 dans une zone : courbe corrigee ; 45.0 et 60.1 hors zone : courbe d origine), relectures ($z2b) ; journal : une ligne des zones, ligne des pistes faibles, effacement ($z2c)"

# Z3 : acceptation et repli a la relecture de la passe 1 : c20-39 rapprochee de 7 ns (gardee) ; c50-69 rapprochee de 1 ns
# seulement (moins de la moitie de 15 : reprise) ; tete 1 passee de -20 a +10 ns (plus de 8 ns de l autre cote : reprise).
# Passe 2 : piste encore faible et pistes des zones reprises, courbes retenues (corrigee sur c20-39 seulement, d origine
# ailleurs ; tete 1 : profil d origine, meme chaine)
$zAfter = { param($c, $h)
    if ($h -eq 0 -and ($c -eq 24 -or $c -eq 33 -or $c -eq 34)) { return -47 }
    if ($h -eq 0 -and $c -ge 20 -and $c -le 39) { return 7 }
    if ($h -eq 0 -and $c -ge 50 -and $c -le 69) { return 39 }
    if ($h -eq 1 -and $c -le 19) { return 10 }
    return 0 }
$script:RLog.Clear(); $script:Calls.Clear()
Set-ZReads $r2 $zAfter @('45.0')
$null = Invoke-WriteCheckAnalysis
$c0b = Get-ZCyl ([int[]]@(@(45) + @(50..69)))
$want3 = @("erase --drive=0 --hfreq --tracks=c=$($c0b):h=0", "write --drive=0 --retries=10 --precomp 0=40:20=33:40=80 --tracks=c=$($c0b):h=0 `"image-factice.adf`"",
           "erase --drive=0 --hfreq --tracks=c=0-19:h=1", "write --drive=0 --retries=10 --precomp 0=0:10=60 --tracks=c=0-19:h=1 `"image-factice.adf`"",
           "read --drive=0 --revs=3 --tracks=c=$($c0b):h=0 check-r2-0.scp", "read --drive=0 --revs=3 --tracks=c=0-19:h=1 check-r2-1.scp")
$cmd3 = @(Get-ZCmds $r2)
$z3a = ((Get-ZZones $r2) -ceq 'h0 c20-39 14.0 -7 ok ; h0 c50-69 40.0 -15 back ; h1 c0-19 -20.0 10 back' -and -not $r2.ZonePass -and $r2.Round -eq 2 -and [string]$r2.HeadPrecomp[0] -ceq '0=40:20=33:40=80' -and [string]$r2.HeadPrecomp[1] -ceq '0=0:10=60')
$z3b = (($cmd3 -join "`n") -ceq ($want3 -join "`n") -and [int]$r2.Rewrites['25.0'] -eq 1 -and [int]$r2.Rewrites['20.0'] -eq 1)
$zl = @("Zone écartée de l'attendu, tête 0 c20-39 : écart médian +14,0 ns avant, +7,0 ns après la correction de -7 ns (relecture par le lecteur Banc 1) : correction gardée.",
        "Zone écartée de l'attendu, tête 0 c50-69 : écart médian +40,0 ns avant, +39,0 ns après la correction de -15 ns (relecture par le lecteur Banc 1) : correction reprise, courbe d'origine sur ces cylindres, pistes réécrites à la passe suivante.",
        "Zone écartée de l'attendu, tête 1 c0-19 : écart médian -20,0 ns avant, +10,0 ns après la correction de +10 ns (relecture par le lecteur Banc 1) : correction reprise, courbe d'origine sur ces cylindres, pistes réécrites à la passe suivante.")
$z3c = (@($zl | Where-Object { @($script:RLog) -cnotcontains $_ }).Count -eq 0 -and @($script:RLog | Where-Object { $_ -like 'Zone écartée*' }).Count -eq 3)
# Passe 2 relue : les zones ne sont plus jugees (une seule tentative) ; aucune autre correction
$script:RLog.Clear()
Set-ZReads $r2 $zMain @()
$null = Invoke-WriteCheckAnalysis
$z3d = ((Get-ZZones $r2) -ceq 'h0 c20-39 14.0 -7 ok ; h0 c50-69 40.0 -15 back ; h1 c0-19 -20.0 10 back' -and @($script:RLog | Where-Object { $_ -like 'Zone écartée*' -or $_ -like '*zone(s) écartée(s)*' }).Count -eq 0 -and @($script:Calls) -ccontains 'Complete-WriteCheck')
Chk 'Z3' ($z3a -and $z3b -and $z3c -and $z3d) "relecture de la passe 1 : $(Get-ZZones $r2) ; profils retenus : tete 0 « $($r2.HeadPrecomp[0]) », tete 1 d origine ($z3a) ; passe 2 : piste encore faible 45.0 et pistes des zones reprises, courbe corrigee gardee sur c20-39 seulement ($z3b) ; une ligne de journal par zone, avant et apres en ns, correction, gardee ou reprise ($z3c) ; passe 2 relue : aucune nouvelle tentative ($z3d)"

# Z4 : critere d acceptation de part et d autre de ses seuils (Complete-WriteZonePass reelle, zone de la tete 0 c20-39,
# E0 = +14, correction -7) : rapprochee de 3,6 ns (gardee) ou de 3,4 (reprise) ; de l autre cote a -7,9 ns (gardee) ou
# -8,1 (reprise) ; aucune piste saine relue (reprise). Relecture rc7 : jugee sur 8 pistes saines relues au moins (12 des 20
# pistes devenues faibles : gardee ; 13 : reprise, ecart pourtant rapproche)
function Test-ZAccept([double]$e1, [switch]$Bad, [int]$NWeak = 0) {
    $ef = { param($c, $h) if ($h -eq 0 -and $c -ge 20 -and $c -le 39) { 14 } else { 0 } }
    $r = New-ZRep $ef
    $null = Invoke-WriteCheckAnalysis
    $weakNow = @(if ($Bad) { @($r.Zones[0].Tracks) } elseif ($NWeak -gt 0) { @($r.Zones[0].Tracks) | Select-Object -First $NWeak })
    $script:ZE1 = $e1
    Set-ZReads $r { param($c, $h) if ($h -eq 0 -and $c -ge 20 -and $c -le 39) { $script:ZE1 } else { 0 } } $weakNow
    $script:RLog.Clear()
    $null = Invoke-WriteCheckAnalysis
    return [string]$r.Zones[0].State
}
$z4 = @((Test-ZAccept 10.4), (Test-ZAccept 10.6), (Test-ZAccept (-7.9)), (Test-ZAccept (-8.1)), (Test-ZAccept 7 -Bad))
$z4l = @($script:RLog | Where-Object { $_ -ceq "Zone écartée de l'attendu, tête 0 c20-39 : écart médian +14,0 ns avant la correction de -7 ns, 0 piste(s) saine(s) relue(s) après, il en faut 8 : correction reprise, courbe d'origine sur ces cylindres, pistes réécrites à la passe suivante." }).Count -eq 1
$z4 += @((Test-ZAccept 7 -NWeak 12), (Test-ZAccept 7 -NWeak 13))
$z4m = @($script:RLog | Where-Object { $_ -like "Zone écartée de l'attendu, tête 0 c20-39 : écart médian +14,0 ns avant la correction de -7 ns, 7 piste(s) saine(s) relue(s) après, il en faut 8 :*" }).Count -eq 1
Chk 'Z4' (($z4 -join ' ') -ceq 'ok back ok back back ok back' -and $z4l -and $z4m) "ecart median apres la correction de -7 ns : +10,4 / +10,6 / -7,9 / -8,1 / pistes toutes faibles / +7 avec 8 pistes saines sur 20 / +7 avec 7 -> $($z4 -join ' / ') (ok back ok back back ok back attendu) ; lignes de journal sans piste saine ($z4l) et avec 7 pistes saines ($z4m)"

# Z5 : sans correction par zones, commandes de la rc6 : case decochee (Rep.ZoneFix faux), ecriture meme lecteur (sans exces),
# une seule passe de reecriture, garde-fou declenche ; ecriture rapide : avec zones, profil commun retire de la base et une
# reecriture par tete ; sans zone ni case, commandes groupees de toujours
$want5 = @("erase --drive=0 --hfreq --tracks=c=25,45:h=0", "write --drive=0 --retries=10 --precomp 0=40:40=80 --tracks=c=25,45:h=0 `"image-factice.adf`"",
           "erase --drive=0 --hfreq --tracks=c=60:h=1", "write --drive=0 --retries=10 --precomp 0=0:10=60 --tracks=c=60:h=1 `"image-factice.adf`"",
           "read --drive=0 --revs=3 --tracks=c=25,45:h=0 check-r1-0.scp", "read --drive=0 --revs=3 --tracks=c=60:h=1 check-r1-1.scp")
$o5 = @()
foreach ($st in @(@{ ZoneFix = $false }, @{ AsymExcess = $null; AsymGain = $null; ZoneFix = $null; Target = $null; TargetSrc = $null }, @{ Max = 1 })) {
    $r = New-ZRep $zMain $zWeak $st
    $null = Invoke-WriteCheckAnalysis
    $o5 += [bool]((@(Get-ZCmds $r) -join "`n") -ceq ($want5 -join "`n") -and (Get-ZZones $r) -ceq '' -and -not $r.ContainsKey('HeadPrecompOrig') -and @($script:RLog | Where-Object { $_ -like '*zone(s) écartée(s)*' }).Count -eq 0)
}
$weakMany = @(@(foreach ($c in 0..79) { "$c.1" }) + @('25.0', '45.0'))
$r = New-ZRep $zMain $weakMany
$null = Invoke-WriteCheckAnalysis
$o5 += [bool]($r.Safety -and $r.Pending.Count -eq 0 -and (Get-ZZones $r) -ceq '')
$fastBase = @('write', '--drive=0', '--retries=10', '--precomp', '0=40:40=80')
$r = New-ZRep $zMain $zWeak @{ HeadPrecomp = $null; Base = $fastBase; ZoneFix = $false }
$null = Invoke-WriteCheckAnalysis
$wantF0 = @("erase --drive=0 --hfreq --tracks=c=25,45:h=0", "write --drive=0 --retries=10 --precomp 0=40:40=80 --tracks=c=25,45:h=0 `"image-factice.adf`"",
            "erase --drive=0 --hfreq --tracks=c=60:h=1", "write --drive=0 --retries=10 --precomp 0=40:40=80 --tracks=c=60:h=1 `"image-factice.adf`"")
$o5 += [bool](((@(Get-ZCmds $r) | Select-Object -First 4) -join "`n") -ceq ($wantF0 -join "`n") -and $null -eq $r.HeadPrecomp)
$zH0 = { param($c, $h) if ($h -eq 0 -and $c -ge 20 -and $c -le 39) { 14 } else { 0 } }
$r = New-ZRep $zH0 @('60.1') @{ HeadPrecomp = $null; Base = $fastBase }
$null = Invoke-WriteCheckAnalysis
$wantF = @("erase --drive=0 --hfreq --tracks=c=20-39:h=0", "write --drive=0 --retries=10 --precomp 0=40:20=33:40=80 --tracks=c=20-39:h=0 `"image-factice.adf`"",
           "erase --drive=0 --hfreq --tracks=c=60:h=1", "write --drive=0 --retries=10 --precomp 0=40:40=80 --tracks=c=60:h=1 `"image-factice.adf`"")
$o5 += [bool](((@(Get-ZCmds $r) | Select-Object -First 4) -join "`n") -ceq ($wantF -join "`n") -and (@($r.Base) -join ' ') -ceq 'write --drive=0 --retries=10' -and [string]$r.HeadPrecomp[1] -ceq '0=40:40=80')
Chk 'Z5' (($o5 | ForEach-Object { [int]$_ }) -join '' -ceq '111111') "case decochee, ecriture meme lecteur, une passe de reecriture : memes commandes que la rc6 (pistes faibles seules, courbes d origine), aucune zone ; garde-fou declenche : aucune reecriture ; ecriture rapide sans zone : profil commun de la base ; avec une zone : profil retire de la base, une reecriture par tete (tete 0 corrigee, tete 1 d origine) ($(($o5 | ForEach-Object { [int]$_ }) -join ''))"

# Z6 : profil decale (Get-WriteZoneSpec reelle) : valeur nulle gardee, borne de 470 ns, valeur deja au-dessus jamais
# augmentee, elements autres que c=ns gardes, zone au-dela de la derniere entree, sans zone : meme chaine
$z6 = @((Get-WriteZoneSpec '0=40:40=80' @(@{ C0 = 20; C1 = 39; Dz = 500 })), (Get-WriteZoneSpec '0=480' @(@{ C0 = 0; C1 = 9; Dz = 10 })), (Get-WriteZoneSpec '0=480' @(@{ C0 = 0; C1 = 9; Dz = -15 })),
        (Get-WriteZoneSpec 'type=mfm:0=0:10=60' @(@{ C0 = 5; C1 = 14; Dz = 5 })), (Get-WriteZoneSpec '0=40' @(@{ C0 = 70; C1 = 79; Dz = -10 })), (Get-WriteZoneSpec '0=40:40=80' @()), (Get-WriteZoneSpec '0=20' @(@{ C0 = 0; C1 = 9; Dz = -30 })))
# Relecture rc7 : borne de la courbe ecrite transmise (Rep.ZoneHard, 400 ns ici) : hausse arretee a la borne, valeur deja
# au-dessus jamais augmentee mais abaissee ; une zone dont la hausse ne change rien a cause de la borne n est pas retenue
# (Find-WriteZones) ; commande de la passe 1 bornee
$z6 += @((Get-WriteZoneSpec '0=390' @(@{ C0 = 0; C1 = 9; Dz = 15 }) 400), (Get-WriteZoneSpec '0=420' @(@{ C0 = 0; C1 = 9; Dz = 10 }) 400), (Get-WriteZoneSpec '0=420' @(@{ C0 = 0; C1 = 9; Dz = -15 }) 400), (Get-WriteZoneSpec '0=390' @(@{ C0 = 0; C1 = 9; Dz = 15 }) 0))
$zLow = { param($c, $h) if ($h -eq 1 -and $c -ge 40 -and $c -le 59) { -20 } else { 0 } }
$r6a = New-ZRep $zLow @() @{ HeadPrecomp = @{ 0 = '0=40:40=80'; 1 = '0=0:40=400' }; ZoneHard = 400 }
$null = Invoke-WriteCheckAnalysis
$z6a = @(Find-WriteZones $r6a).Count
$r6a.ZoneHard = 0; $z6a0 = @(Find-WriteZones $r6a).Count
$r6b = New-ZRep $zLow @() @{ HeadPrecomp = @{ 0 = '0=40:40=80'; 1 = '0=0:40=395' }; ZoneHard = 400 }
$null = Invoke-WriteCheckAnalysis
$z6b = @(Get-ZCmds $r6b | Where-Object { $_ -like 'write *' })
$z6ok = ($z6a -eq 0 -and $z6a0 -eq 1 -and $r6a.Pending.Count -eq 0 -and $z6b.Count -eq 1 -and $z6b[0] -ceq "write --drive=0 --retries=10 --precomp 0=0:40=400:60=395 --tracks=c=40-59:h=1 `"image-factice.adf`"")
Chk 'Z6' (($z6 -join ' | ') -ceq '0=40:20=470:40=80 | 0=480 | 0=465:10=480 | type=mfm:0=0:10=65:15=60 | 0=40:70=30:80=40 | 0=40:40=80 | 0=0:10=20 | 0=400:10=390 | 0=420 | 0=405:10=420 | 0=405:10=390' -and $z6ok) "profils decales : $($z6 -join ' | ') ; borne de 400 ns : zone sans effet ecartee ($z6a zone ; sans borne transmise, 470 ns : $z6a0), reecriture « $(if ($z6b.Count) { $z6b[0] } else { 'aucune' }) » ($z6ok)"

# Z7 : verdict de fin et carte (vraies Complete-WriteCheck et Show-WriteCheckTable, bouchons de l interface) : zones corrigees
# sur combien ; passe 1 interrompue par gw : zones reecrites non jugees ; libelle de la passe (vraie Invoke-RepNextCmd)
function Invoke-ZComplete($rep, [switch]$GwError) {
    $gc = Join-Path $here 'gen-r16-fin.ps1'
    [System.IO.File]::WriteAllText($gc, ($defsX['Complete-WriteCheck'] + "`r`n`r`n" + $defsX['Invoke-RepNextCmd'] + "`r`n"), $utf8Bom)
    function Set-SeqEnd([string]$t, [string]$k) { }
    function Set-QualityCheckState([int]$l, [string]$t, [string]$s, [int]$n) { $script:ZState = @{ Text = $t; Short = $s } }
    function Set-WCalVerdict([string]$t, [string]$k) { }
    function Exit-CheckTab { }
    . $gc
    $script:Restore = $null; $script:Rep = $rep
    if ($GwError) { Complete-WriteCheck -GwError } else { Complete-WriteCheck }
    return $script:ZState.Text
}
$r = New-ZRep $zMain $zWeak
$null = Invoke-WriteCheckAnalysis
Set-ZReads $r $zAfter @()
$null = Invoke-WriteCheckAnalysis
$r.Weak = @(); $script:RLog.Clear()
$t7 = Invoke-ZComplete $r
$res7 = $script:LastRes
$z7a = ($t7 -ceq "CONTRÔLE APRÈS ÉCRITURE : 160/160 pistes saines, après réécriture de 62 piste(s) en 2 passe(s) ; zones écartées de l'attendu corrigées : 1 sur 3 (relu par le lecteur Banc 1, pas par le lecteur cible Atelier 2)" -and @($script:RLog) -ccontains $t7 -and ([string]$res7.AsymLine).EndsWith(' ; zones corrigées : 1 sur 3') -and ([string]$res7.AsymLineShort).EndsWith(' ; zones corrigées : 1 sur 3'))
# Relecture rc7 : carte (vraie Get-QualityCardModel, vraie Get-QualFitText) : forme courte sans les zones en derniere forme,
# retenue quand aucune autre ne tient (pas de ligne coupee) ; large : forme longue avec les zones
$v7 = @{ State = 'result'; Kind = 'check'; Reason = ''; At = [datetime]::new(2026, 11, 11, 10, 0, 0); Has = $true; Pass = 0; Drive = ''; Heads = ''; Revs = 0; NCyl = 0; RunText = ''; Res = $res7 }
$c7 = Get-QualityCardModel $v7
$bare7 = [string]$res7.AsymLineBare
$f7 = New-Object System.Drawing.Font('Segoe UI', [single]8.25)
$z7d = ($bare7 -and ([string]$res7.AsymLineShort) -ceq ($bare7 + ' ; zones corrigées : 1 sur 3') -and @($c7.Line3More).Count -eq 1 -and [string]@($c7.Line3More)[0] -ceq $bare7 -and
        (Get-QualFitText $c7.Line3 $c7.Line3Short $f7 32000 $c7.Line3More) -ceq [string]$c7.Line3 -and (Get-QualFitText $c7.Line3 $c7.Line3Short $f7 40 $c7.Line3More) -ceq $bare7)
$f7.Dispose()
$r = New-ZRep $zMain $zWeak
$null = Invoke-WriteCheckAnalysis
$lblWCal = [pscustomobject]@{ Text = '' }
function Set-QualityRunText([string]$t) { }
function Start-Gw([string[]]$a) { }
$lab = @()
$gl = Join-Path $here 'gen-r16-lib.ps1'; [System.IO.File]::WriteAllText($gl, ($defsX['Invoke-RepNextCmd'] + "`r`n"), $utf8Bom); . $gl
$q = $r.Pending.ToArray(); $r.Pending.Clear(); foreach ($x in @($q[0], $q[1])) { $r.Pending.Enqueue($x) }
Invoke-RepNextCmd; $lab += $lblWCal.Text; Invoke-RepNextCmd; $lab += $lblWCal.Text
$z7b = (($lab -join ' | ') -ceq "Contrôle après écriture : effacement haute fréquence avant la réécriture 1/3 de 62 piste(s) (pistes faibles et zones écartées de l'attendu)... | Contrôle après écriture : réécriture 1/3 de 62 piste(s) (pistes faibles et zones écartées de l'attendu)...")
$script:RLog.Clear()
$t7g = Invoke-ZComplete $r -GwError
$z7c = ($t7g -like "*; zones écartées de l'attendu : 0 corrigée(s) sur 3, 3 non jugée(s), leurs pistes ont pu être réécrites avec la correction (relu par le lecteur Banc 1, pas par le lecteur cible Atelier 2)")
# Relecture rc7 : « Arreter » pendant la passe 1 (vraie Stop-WriteCheck) : tete 0 effacee et reecrite, tete 1 effacee
# seulement : ses pistes (zone c0-19 et piste faible 60.1) sont dites vierges ; arret avant tout effacement : rien
function Invoke-ZStop($rep) {
    $gs = Join-Path $here 'gen-r16-arret.ps1'
    [System.IO.File]::WriteAllText($gs, ($defsX['Stop-WriteCheck'] + "`r`n"), $utf8Bom)
    function Set-WCalVerdict([string]$t, [string]$k) { }
    function Exit-CheckTab { }
    . $gs
    $script:Restore = $null; $script:Rep = $rep
    Stop-WriteCheck
}
$r = New-ZRep $zMain $zWeak
$null = Invoke-WriteCheckAnalysis
$el7 = $script:EraseLog
foreach ($k in @($r.Weak)) { $el7.Erased[[string]$k] = $true; if (([string]$k).EndsWith('.0')) { $el7.Written[[string]$k] = $true } }
$script:RLog.Clear()
Invoke-ZStop $r
$w7e = "Contrôle après écriture : piste(s) effacée(s) en haute fréquence et non réécrite(s) après l'arrêt de gw : $(Format-TrackList (Sort-TrackKeys @(@(0..19 | ForEach-Object { "$_.1" }) + @('60.1')))). Elles sont vierges sur la disquette : réécrivez l'image."
$log7e = @($script:RLog)
$r = New-ZRep $zMain $zWeak
$null = Invoke-WriteCheckAnalysis
$script:RLog.Clear()
Invoke-ZStop $r
$log7f = @($script:RLog)
$z7e = ($log7e.Count -eq 2 -and $log7e[0] -ceq 'Contrôle après écriture interrompu.' -and $log7e[1] -ceq $w7e -and $null -eq $script:Rep -and ($log7f -join '|') -ceq 'Contrôle après écriture interrompu.')
Chk 'Z7' ($z7a -and $z7b -and $z7c -and $z7d -and $z7e) "verdict : « $(Get-Short $t7 200) » ; ligne de la carte terminee par « zones corrigees : 1 sur 3 » ($z7a) ; libelles de la passe 1 avec des zones ($z7b) ; passe interrompue par gw (ici avant toute commande) : « $(Get-Short $t7g 90) », sans dire les pistes reecrites ($z7c) ; carte : forme courte sans les zones quand rien d autre ne tient ($z7d) ; Arreter pendant la passe 1 : pistes effacees non reecrites dites vierges, rien avant tout effacement ($z7e)"

# Z8 : textes du lot dans la section « rc7 » de 019, memes jalons
$iRc7 = $t019.IndexOf('# --- rc7 :'); $badZ = @()
# 12.11 rc8 : la section « rc7 » s arrete a la section suivante (« rc8 »), ou a la fin du module
$eRc7 = if ($iRc7 -ge 0) { $t019.IndexOf("`n# --- ", $iRc7 + 5) } else { -1 }; if ($eRc7 -lt 0) { $eRc7 = $t019.Length }
$zKeys = @([regex]::Matches($t019.Substring([math]::Max(0, $iRc7), $eRc7 - [math]::Max(0, $iRc7)), '(?m)^\$script:I18n\[(?:"([^"]+)"|''([^'']+)'')\]') | ForEach-Object { if ($_.Groups[1].Success) { $_.Groups[1].Value.Replace('`n', "`n") } else { $_.Groups[2].Value.Replace("''", "'") } })
foreach ($k in $zKeys) {
    $ph1 = (@([regex]::Matches($k, '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join '')
    $ph2 = (@([regex]::Matches([string]$script:I18n[$k], '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join '')
    if (-not $script:I18n.ContainsKey($k) -or $ph1 -ne $ph2 -or -not [string]$script:I18n[$k]) { $badZ += $k }
}
Chk 'Z8' ($iRc7 -gt 0 -and $zKeys.Count -eq 18 -and $badZ.Count -eq 0) "$($zKeys.Count) textes du lot dans la section « rc7 » de 019, memes jalons : en defaut $(if ($badZ.Count) { $badZ -join ' | ' } else { 'aucun' })"

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
function Get-ResDigest($res) { $h = @{}; foreach ($k in @($res.Keys)) { if (@('AsymText', 'AsymLine', 'AsymLineShort', 'AsymJudge') -notcontains $k) { $h[$k] = $res[$k] } }; return (Format-V $h) }   # 12.11 rc6 (R14) : ligne de la carte, absente de la 12.10
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
# N4 a N6 : sans -Before aussi : etats de la mesure, pistes faibles et commandes de reecriture du controle (scenario des
# cas Q), valeurs rendues par la source de la 12.10 (c8a3c72) ; Q7 les recalcule avec -Before
function Get-StateDigest($o) {
    # Etat de chaque ligne du tableau de la mesure (icone d etat posee par New-AlignRow), premiere puis seconde passe
    return ((@(@($o.M1.Rows) + @($o.M2.Rows)) | ForEach-Object { $p = @($_ -split '\|'); $p[0] + ':' + $p[10] }) -join ' ')
}
function Get-DecisionDigest($o) {
    # Pistes faibles et commandes en file (verbe et pistes) : premiere relecture, remesure, passe interrompue
    $l = @()
    foreach ($st in @($o.C0, $o.C1, $o.P)) {
        foreach ($x in @($st)) {
            if ($x -like 'faibles *') { $l += $x }
            elseif ($x -like 'commande *') { $w = @($x -split ' '); $l += ($w[1] + ' ' + ([string](@($w | Where-Object { $_ -like '--tracks=*' })[0])).Substring(9)) }
        }
        $l += '--'
    }
    return ($l -join ' / ')
}
$goldStates = '0.0:h0 0.1:h0 1.0:h0 1.1:h1 2.0:h0 2.1:h1 3.0:h0 3.1:h0 4.0:h0 4.1:h2 5.0:h0 5.1:h1 6.0:h0 6.1:h0 7.0:h1 7.1:h0 8.0:h0 8.1:h2 9.0:h0 9.1:h1 10.0:h0 10.1:h2 11.0:h0 11.1:h2 12.0:h0 12.1:h0 13.0:h0 13.1:h1 14.0:h0 14.1:h0 15.0:h0 15.1:h0 0.0:h1 0.1:h0 1.0:h0 1.1:h0 2.0:h0 2.1:h0 3.0:h0 3.1:h0 4.0:h1 4.1:h2 5.0:h0 5.1:h0 6.0:h0 6.1:h0 7.0:h0 7.1:h0 8.0:h1 8.1:h0 9.0:h0 9.1:h0 10.0:h0 10.1:h2 11.0:h0 11.1:h0 12.0:h1 12.1:h0 13.0:h0 13.1:h0 14.0:h0 14.1:h0 15.0:h0 15.1:h0'
$goldDecisions = 'faibles 1.1,2.1,4.1,5.1,7.0,9.1,10.1,11.1,16.0 / erase c=7,16:h=0 / write c=7,16:h=0 / erase c=1,2,4,5,9,10,11:h=1 / write c=1,2,4,5,9,10,11:h=1 / read c=7,16:h=0 / read c=1,2,4,5,9,10,11:h=1 / -- / faibles 4.1,10.1,16.0 / erase c=16:h=0 / write c=16:h=0 / erase c=4,10:h=1 / write c=4,10:h=1 / read c=16:h=0 / read c=4,10:h=1 / -- / faibles 4.1,10.1,16.0 / erase c=7,16:h=0 / write c=7,16:h=0 / erase c=1,2,4,5,9,10,11:h=1 / write c=1,2,4,5,9,10,11:h=1 / read c=7,16:h=0 / read c=1,2,4,5,9,10,11:h=1 / --'
'--- N (suite) : etats et reecritures inchanges (valeurs de la 12.10, sans -Before)'
$now = & $scenario
$stNow = Get-StateDigest $now; $decNow = Get-DecisionDigest $now
Chk 'N4' ($stNow -ceq $goldStates) "mesure, deux passes : etat de chacune des $(@($stNow -split ' ').Count) lignes du tableau = valeurs de la 12.10 ($(Get-Short $stNow 60))"
Chk 'N5' ($decNow -ceq $goldDecisions) "controle : pistes faibles et commandes en file (relecture, remesure, passe interrompue) = valeurs de la 12.10 ($(Get-Short $decNow 80))"
$decFns = @('Invoke-WriteCheckAnalysis', 'Update-RepPartial', 'Set-CopyUnstable', 'Merge-RepRetries', 'Add-RepReads')
$noText = @(@($decFns + @('Get-HealthLevel')) | Where-Object { -not $defsNew[$_] })
$readAsym = @($decFns | Where-Object { $defsNew[$_] -match 'Asym|\.R3\b|\.R4\b' })
# 12.11 rc7 (R16) : seule exception voulue, la correction par zones d une ecriture pour un lecteur cible : Invoke-WriteCheckAnalysis
# ne lit l asymetrie que par Find-WriteZones et Complete-WriteZonePass, et la premiere ne rend rien sans Rep.ZoneFix ni
# Rep.AsymExcess (cas Z) ; l etat d une piste (Get-HealthLevel) n en depend jamais
$zoneCalls = @('Find-WriteZones', 'Complete-WriteZonePass', 'Start-WriteZonePass' | Where-Object { $defsNew['Invoke-WriteCheckAnalysis'] -match [regex]::Escape($_) })
$zoneGate = ($defsX['Find-WriteZones'] -match 'if \(-not \$rep -or -not \$rep\.ZoneFix -or -not \$rep\.AsymExcess -or \[int\]\$rep\.Max -lt 2 -or \$rep\.Safety\) \{ return \}')
Chk 'N6' ($noText.Count -eq 0 -and $readAsym.Count -eq 0 -and $defsNew['Get-HealthLevel'] -notmatch '\$asym|\.Asym|Get-AsymSign' -and $zoneCalls.Count -eq 3 -and $zoneGate) "les fonctions qui decident de l etat d une piste et des reecritures du controle ($($decFns.Count + 1) textes lus, $($noText.Count) absent) ne lisent ni l asymetrie ni son signe ; en defaut : $(if ($readAsym.Count) { $readAsym -join ', ' } else { 'aucune' }) ; exception de la rc7 : appels de la correction par zones $($zoneCalls -join ', '), Find-WriteZones sans effet sans Rep.ZoneFix, Rep.AsymExcess, 2 passes et sans garde-fou ($zoneGate)"
if (-not $Before) {
    'Q0-Q7    saute : sans -Before <copie de la source de la 12.10>, l equivalence avec la 12.10 n est pas rejouee (N1, N3, N4 et N5 en gardent les valeurs)'
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
    Chk 'Q7' ((Get-StateDigest $a) -ceq $goldStates -and (Get-DecisionDigest $a) -ceq $goldDecisions) "valeurs de N4 et de N5 = celles que rend la source d avant"
}

$lvAl.Dispose(); $tip.Dispose(); $bold.Dispose()
$nk = ''; if ($script:Fail) { $nk = ' ; non conformes : ' + (@($script:FailIds) -join ', ') }
"=== bilan logic-qualite-asymetrie : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
