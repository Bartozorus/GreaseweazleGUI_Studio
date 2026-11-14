param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Before = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 (lot L4) : plafond de precompensation par disquette, au quart de la cellule de la piste ecrite (265, 260, 270,
# 560, 010, 019). Jusqu a la 12.10, une courbe de disquette dont le besoin depassait la borne montait a 470 ns pour toutes
# les images ; elle monte maintenant au quart de la cellule, 500 ns au plus (Get-DiskCapNs).
#  P1 a P6  cas de la specification : Get-DiskCapNs, Get-DiskHardNs, Get-LevelAdaptHard, courbe adaptee et son bilan
#           (Build-LevelAdaptValues, Get-LevelAdaptOutcome), courbe d une marque (Get-LevelBrandCurveValues), controle
#           statique (emplois de CalHardMaxNs, ordre des instructions de Start-PrecompCalib, appels du conseil) ;
#  P7       carte « Calibrer le lecteur » de l Accueil : unites sans densite (argument reel de Start-LevelCalib), donc
#           470 ns au plus : son profil peut etre place dans les champs d une image d une autre densite ;
#  P8       format gw de plus de 250 kbit/s en double densite (Get-DiskCapBits) : cellules de la piste ecrite, et non
#           celles du motif ; argument reel de Start-LevelCalib avec le format de l onglet Ecriture ; format dont le codec
#           ecrit plus de cellules que le motif d une image secteur (amiga.amigados : 101 344) : cellules du codec ;
#  B1, B2   le plafond ne depasse jamais le quart de la cellule ni 500 ns : toutes les densites de 50 000 a 260 000
#           cellules, puis toutes les courbes de la grille ; B3 tous les formats gw que l application calibre en double
#           densite (Get-FormatCalibInfo reelle, table reelle de 040) : jamais plus du quart de la cellule ecrite, pour le
#           motif du format comme pour celui d une image secteur qui n est pas de ce format (100 000 cellules) ;
#  E1 a E6  equivalence avec la regle de la 12.10 sur une grille de courbes factices (6 densites standard et long track,
#           4 bornes, 8 besoins ; tete 0 : forme adaptee, tete 1 : courbe complete d une marque au depart). La regle de la
#           12.10 est celle d une unite sans densite (470 ns pour toutes) : egalite prouvee avec -Before (Q1), valeurs de la
#           12.10 gardees dans N1 ;
#  C1 a C4  reserve « au-dela de la borne » et controle apres ecriture impose : seuil inchange, courbe adaptee, courbe
#           mesuree, ligne du journal suivie du conseil d essai sur la machine cible ;
#  D1 a D3  courbe de marque enregistree par la 12.10 (curveMaxNs 470) : relue et reprise telle quelle ; D4 reference
#           plus longue que la courbe : cylindres prolonges bornes au plafond de l image (470 ns sans densite) ;
#  M1 a M4  mesure complete de cette disquette : borne posee par Start-PrecompCalib (instructions reelles extraites par
#           l arbre syntaxique), ligne du journal, borne retablie ; M4 format de plus de 250 kbit/s ; M5 image secteur
#           et amiga.amigados, image dont une piste est plus longue que le motif (cellule la plus courte annoncee) ;
#  F1 a F4  lot L4b : cellule de la piste ecrite inconnue, donc sans densite (470 ns, comme en 12.10). Format explicite
#           absent de la table des formats (saisie libre de la liste Format : gw plus recent, fichier diskdefs) :
#           Get-DiskCapBits rend 0, calibration rapide factice a 470 ns, mesure complete a 470 ns avec la ligne de journal
#           de la 12.10, sans division par zero (Get-DiskBoundText) ;
#  A1 a A3  lot L4b : aucun format (vide, « (auto) »). Un cas par type d image auquel gw 1.23 donne un format par defaut
#           (ADF, D64, D81, XDF, HDM, FD, MGT), puis flux, IPF, HFE et images secteur : densite du motif (Get-PatternBits
#           reelle sur des images factices), chemin du plafond emprunte ou non (Get-CalibImageCheck et Get-WriteLevelKind
#           reelles), plafond obtenu : au-dela de 470 ns seulement pour une densite tiree de l image (ADF, IPF, HFE) ;
#  A4, A5   corrections de relecture : IPF et HFE dont une piste est plus longue que les autres (protection) : le plafond
#           suit la piste la plus longue, donc la cellule la plus courte (champ CapBits du motif), la densite du motif
#           (mediane) ne change pas ; HFE v3 (densite tiree du seul debit de l en-tete, longueur des pistes non lue) :
#           470 ns sans format ; format amiga.amigados sur une image secteur qui n est pas un ADF : cellule du codec
#           AmigaDOS (101 344 cellules, 493 ns), calibration rapide factice et mesure complete comprises ;
#  H1, H2  haute densite : aucun chemin du plafond par disquette (Get-LevelRef, Start-DiskMeasure, Set-CalibScale reels),
#           appelants des fonctions du plafond ;
#  P9, F5   lot L12a : conseil « la borne se regle jusqu a N ns » jamais au-dela du plafond de l image (Get-BoundAdviceNs :
#           470 ns au plus ; forme adaptee, forme d une marque et courbe de refus) ; ligne de la borne d une mesure complete
#           qui nomme la piste la plus longue d un IPF ou d un HFE aux pistes inegales (Get-DiskBoundText et le motif).
#           Adaptes a dessein par ce lot : P4 (long track de 110 000 cellules, borne reglee a 460 ns : plus de conseil de
#           relever la borne, deja au-dela du quart de la cellule), P6 (emplois de CalHardMaxNs, appel de Get-DiskBoundText),
#           E2 et Q2 (conseil ramene a 470 ns avant la comparaison pour une image de plafond plus bas), M5 et L1 (textes), H2
#           (appelants de Get-UnitCapNs) ;
#  I1, L1   table I18n (019 ; ligne de la 12.10 retablie dans 010 pour la borne sans cellule connue), CHANGELOG ;
#  N1       resultats de la source de la 12.10 pour les 32 courbes sans densite de la grille ;
#  Q0 a Q7  equivalence avec la 12.10, avec -Before <racine d une copie de la source de la 12.10> (aucune dans le depot ;
#           sans elle, une ligne « saute ») : les memes entrees passent par les fonctions des deux versions, chacune
#           chargee dans sa portee ; Q7 : format absent de la table, borne et journal de la 12.10.
# Fonctions reelles extraites par l arbre syntaxique, ecrites dans un fichier de travail, chargees par dot-source ;
# bouchons : journal (Append-Log), cylindres de controle (Get-LevelCtlCyls) ; Start-PrecompCalib est remplacee par un
# banc compose de ses propres instructions. Aucun gw, aucune fenetre, aucune compilation.
# Non couvert : une calibration rapide ou une mesure complete deroulee de bout en bout avec une borne au-dela de 470 ns
# (passes, zeros estimes, verification) ; l enchainement reel de Start-LevelCalib et de Start-PrecompCalib (fenetres) ;
# toute ecriture reelle au-dela de 470 ns ; la cellule que gw ecrit reellement (aucun gw : elle vient de la table des
# formats, du codec AmigaDOS et des bits par piste lus dans l image : que gw ecrive chaque piste d un IPF ou d un HFE a sa
# propre longueur, et 101 344 cellules avec amiga.amigados quelle que soit l image, n est pas relu dans sa source) ; un
# HFE v3 reel (image factice : signature et en-tete seulement) ; un IPF reel a pistes de longueurs differentes.
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
. (Join-Path $PSScriptRoot 'cal2-commun.ps1')
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
$tFn = [System.Management.Automation.Language.FunctionDefinitionAst]
$tAsg = [System.Management.Automation.Language.AssignmentStatementAst]
$tIf = [System.Management.Automation.Language.IfStatementAst]
$tCmd = [System.Management.Automation.Language.CommandAst]
$tVar = [System.Management.Automation.Language.VariableExpressionAst]
$utf8 = New-Object System.Text.UTF8Encoding($false)
$mods = Join-Path $Wt 'src\modules'
function Get-Short([string]$s, [int]$max = 170) { if ($s.Length -gt $max) { return $s.Substring(0, $max) + '...' }; return $s }
function Get-List($a, [int]$max = 4) {
    $x = @($a); if ($x.Count -eq 0) { return 'aucun' }
    $t = (@($x | Select-Object -First $max) | ForEach-Object { Get-Short ([string]$_) }) -join ' ; '
    if ($x.Count -gt $max) { $t += " ; ... ($($x.Count))" }
    return $t
}

# Textes de la specification (lot1-simple, A.2)
$kBound = "Borne de la courbe de cette disquette : {0} ns, le quart de la cellule de l'image ({2} ns), {3} ns au plus ; au-delà de {1} ns, contrôle après écriture imposé."
$eBound = 'Curve bound for this disk: {0} ns, a quarter of the image cell ({2} ns), {3} ns at most; above {1} ns, post-write check enforced.'
$kAdv = "Au-delà de {0} ns, la calibration ne compense que la chaîne d'écriture et de relecture de ce lecteur : essayez la disquette écrite sur la machine à laquelle elle est destinée (un vrai Amiga, par exemple) avant de vous y fier."
$eAdv = "Above {0} ns, calibration only compensates this drive's own write and read chain: try the written disk on the machine it is meant for (a real Amiga, for example) before relying on it."
# Ligne de la 12.10 (010) : lot L4, remplacee par $kBound ; lot L4b, retablie pour une borne sans cellule connue (470 ns)
$kOldBound = "Borne de la courbe de cette disquette : {0} ns ; au-delà de {1} ns, contrôle après écriture imposé."
$eOldBound = 'Curve bound for this disk: {0} ns; above {1} ns, post-write check enforced.'
$advMark = 'la calibration ne compense que'

# ---------------------------------------------------------------- fonctions reelles
$fnCommon = [ordered]@{
    '220-fn-profil-precomp.ps1'   = @('Get-CurveDate')
    '230-fn-calib-courbe.ps1'     = @('Set-CalibScale', 'Format-CylList', 'Get-Median', 'Get-CurveMaxNs', 'Build-CurveProfile', 'ConvertTo-LevelBrandConfig', 'ConvertFrom-LevelBrandConfig')
    '240-fn-calib-mesure.ps1'     = @('New-CalibUnit')
    '260-fn-calib-rapide.ps1'     = @('Get-LevelRef', 'Set-LevelTargets', 'Test-LevelShape', 'Build-LevelValues', 'New-LevelCalUnits', 'Get-LevelUnitResults')
    '265-fn-calib-adaptative.ps1' = @('New-LevelShape', 'Get-LevelShapeRow', 'Get-LevelPredict', 'Format-LevelSigned', 'Get-LevelAdaptHard', 'Build-LevelAdaptValues', 'Get-LevelAdaptOutcome', 'Get-LevelBrandKey', 'Find-LevelBrand', 'Test-LevelBrandValid', 'Update-LevelBrandStats', 'Set-LevelBrandStart', 'Test-LevelAdaptedSpec', 'Get-DiskHardNs', 'Get-DiskOverNs', 'Test-LevelBrandCurve', 'Get-LevelBrandCurveValues')
    '270-fn-calib-complete.ps1'   = @('Start-DiskMeasure', 'Set-DiskHardNs', 'Reset-DiskHardNs')
}
$fnL4 = @('Get-DiskCellNs', 'Get-DiskCapNs', 'Get-UnitCapNs', 'Get-DiskCapBits', 'Get-DiskBoundText', 'Get-DiskOverAdviceText', 'Get-BoundAdviceNs')   # 265, lots L4, L4b et L12a
# Lot L4 encore : formats gw calibres par l application (cas B3) : fonctions reelles et table des formats de 040
# Lot L4b (cas A) : densite du motif d une image (240, 220) et fonctions qui decident si une image de l onglet Ecriture
# atteint la calibration rapide ou la mesure de la disquette (260 : bouton « Calibrer » ; 140 : bouton ECRIRE ; 150, 230)
$fnFmt = [ordered]@{
    '140-fn-ecriture.ps1'            = @('Get-WriteLevelKind', 'Test-ManualPrecomp')
    '150-fn-pistes-densite.ps1'      = @('Test-HdFormat', 'Test-AdfHd', 'Test-NeedsFormat', 'Get-CellOutOfRange', 'Get-HighDensityReason', 'Get-HdCalibFamily', 'Get-ImageEncoding', 'Test-NonMfmWrite')
    '200-fn-accueil-calibration.ps1' = @('Get-FormatCalibInfo')
    '220-fn-profil-precomp.ps1'      = @('Get-BE32', 'Get-IpfCellInfo', 'Get-HfeCellInfo')
    '230-fn-calib-courbe.ps1'        = @('Get-CalibFamilyName', 'Get-ImageCylinders', 'Get-ImageFamily')
    '240-fn-calib-mesure.ps1'        = @('Get-PatternBits')
    '260-fn-calib-rapide.ps1'        = @('Get-CalibCylinders', 'Get-CalibSettingBlock', 'Get-CalibImageCheck')
}
function Get-FnAst([string]$file, [string]$name) {
    $h = @((Get-Cal2Ast $file).FindAll({ param($x) $x -is $tFn -and $x.Name -eq $name }, $false))
    if ($h.Count -ne 1) { throw "fonction $name : $($h.Count) dans $file (1 attendue)" }
    return $h[0]
}
function Get-StmtIn($fnAst, [scriptblock]$pred, [string]$what) {
    $h = @($fnAst.Body.FindAll($pred, $true))
    if ($h.Count -ne 1) { throw "$what : $($h.Count) instruction(s) dans $($fnAst.Name) (1 attendue)" }
    return $h[0]
}
function Get-ConstTexts([string]$root) {
    # Constantes de la calibration : affectations $script:Cal* et $script:Level* du niveau du script de 560 (sauf celles qui
    # lisent la table des reglages ou un controle), versions du calcul de 000
    $out = New-Object System.Collections.Generic.List[string]
    $a = Get-Cal2Ast (Join-Path $root 'src\modules\560-etat-calibration.ps1')
    foreach ($st in $a.EndBlock.Statements) {
        if ($st -isnot $tAsg) { continue }
        $left = $st.Left.Extent.Text
        if (($left -like '$script:Cal*' -or $left -like '$script:Level*') -and $st.Extent.Text -notmatch 'SettingDefs|\$cmb|\$txt|\$chk') { $out.Add($st.Extent.Text) }
    }
    $a0 = Get-Cal2Ast (Join-Path $root 'src\modules\000-entete.ps1')
    foreach ($st in $a0.EndBlock.Statements) {
        if ($st -is $tAsg -and @('$script:CalibCalc', '$script:CalibCalcHd', '$script:CalibAlgo', '$script:Version') -contains $st.Left.Extent.Text) { $out.Add($st.Extent.Text) }
    }
    return ,$out.ToArray()
}
function New-Gen([string]$root, [string]$outFile, [bool]$l4) {
    # Fichier de travail d une version : texte des fonctions et des constantes, tel quel ; trois bancs composes d instructions
    # de 270 recopiees telles quelles. Rend le texte des fonctions et des instructions extraites
    $dir = Join-Path $root 'src\modules'
    $parts = New-Object System.Collections.Generic.List[string]; $defs = @{}
    foreach ($mod in @($fnCommon.Keys)) {
        $want = @($fnCommon[$mod]); if ($l4 -and $mod -like '265-*') { $want += $fnL4 }
        $have = Get-Cal2FnDefs (Join-Path $dir $mod)
        foreach ($n in $want) {
            if (-not $have.ContainsKey($n)) { throw "fonction $n introuvable dans $mod sous $root (lot L4 absent de cette source ?)" }
            $parts.Add($have[$n]); $defs[$n] = $have[$n]
        }
    }
    foreach ($t in (Get-ConstTexts $root)) { $parts.Add($t) }
    $f270 = Join-Path $dir '270-fn-calib-complete.ps1'
    $sp = Get-FnAst $f270 'Start-PrecompCalib'; $cp = Get-FnAst $f270 'Complete-PrecompCalib'; $cd = Get-FnAst $f270 'Complete-DiskMeasure'
    # Start-PrecompCalib : borne de la mesure complete posee apres Set-CalibScale, puis ligne du journal qui l annonce
    $sA = Get-StmtIn $sp { param($x) $x -is $tIf -and $x.Clauses[0].Item1.Extent.Text -eq '$do' -and $x.Extent.Text.Contains('Set-DiskHardNs') } 'borne de la mesure complete'
    # Lot L4b : la ligne vient de Get-DiskBoundText (265) ; source d avant ($l4 faux) : instruction « if » de la 12.10
    if ($l4) { $sC = Get-StmtIn $sp { param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'Append-Log' -and $x.Extent.Text.Contains('Get-DiskBoundText') } 'ligne de la borne' }
    else { $sC = Get-StmtIn $sp { param($x) $x -is $tIf -and $x.Clauses[0].Item1.Extent.Text -eq '[int]$do.HardNs -gt $thr' } 'ligne de la borne' }
    # Complete-PrecompCalib : reserve « au-dela de la borne » de la courbe d une disquette
    $sO = Get-StmtIn $cp { param($x) $x -is $tIf -and $x.Clauses[0].Item1.Extent.Text -eq '$cal.DiskOnly' -and $x.Extent.Text.Contains('pour cette disquette seulement') } 'reserve au-dela de la borne'
    # Complete-DiskMeasure : controle apres ecriture impose
    $sF = Get-StmtIn $cd { param($x) $x -is $tIf -and $x.Clauses[0].Item2.Extent.Text.Contains('$script:LevelPostForce = $true') -and -not $x.Extent.Text.Contains('Start-ImageWrite') } 'controle impose'
    $nl = "`r`n"
    # Motif factice : cellules ($script:TBits) et, lot L4b, densite tiree de l image ou non ($script:TKnown, champ Known) ;
    # corrections de relecture : cellules de la piste la plus longue de l image ($script:TCap, champ CapBits ; celles du
    # motif par defaut)
    $parts.Add('function Start-PrecompCalib([switch]$ForceFine, $Heads = $null) {' + $nl + '    $do = $script:CalDiskOnly; $script:CalDiskOnly = $null' + $nl + '    $pat = @{ Bits = [int]$script:TBits; Known = [bool]$script:TKnown; CapBits = [int]$(if ([int]$script:TCap -gt 0) { $script:TCap } else { $script:TBits }) }' + $nl + "    Set-CalibScale ''" + $nl + '    ' + $sA.Extent.Text + $nl + '    $script:Cal = @{ DiskOnly = $true; HardNs = [int]$do.HardNs }' + $nl + '    $thr = Get-DiskOverNs' + $nl + '    ' + $sC.Extent.Text + $nl + '}')
    $parts.Add('function Invoke-TDiskOver($cal, $u, $issues, $kinds) {' + $nl + '    ' + $sO.Extent.Text + $nl + '}')
    $parts.Add('function Invoke-TDiskForce($recs) {' + $nl + '    $thr = Get-DiskOverNs' + $nl + '    ' + $sF.Extent.Text + $nl + '}')
    if ($l4) {
        # Start-LevelCalib : cinquieme element de l appel de New-LevelCalUnits (cellules transmises aux unites), recopie tel
        # quel dans un banc qui recoit les deux variables locales qu il lit ; le format vient de $cmbWFmt, pose par le test
        $sl = Get-FnAst (Join-Path $dir '260-fn-calib-rapide.ps1') 'Start-LevelCalib'
        $nu = Get-StmtIn $sl { param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'New-LevelCalUnits' } 'appel de New-LevelCalUnits'
        if ($nu.CommandElements.Count -ne 5) { throw "appel de New-LevelCalUnits dans Start-LevelCalib : $($nu.CommandElements.Count) elements (5 attendus)" }
        $parts.Add('function Get-TUnitBits($Geom, $pat) {' + $nl + '    return ' + $nu.CommandElements[4].Extent.Text + $nl + '}')
        # Formats gw : fonctions reelles qui disent si un format se calibre, table reelle de 040 (affectation et boucle) ;
        # lot L4b : formats implicites des extensions et seuil de famille (040), lus par les fonctions du cas A
        foreach ($mod in @($fnFmt.Keys)) {
            $have = Get-Cal2FnDefs (Join-Path $dir $mod)
            foreach ($n in @($fnFmt[$mod])) { if (-not $have.ContainsKey($n)) { throw "fonction $n introuvable dans $mod sous $root" }; $parts.Add($have[$n]) }
        }
        $nTab = 0
        foreach ($st in @((Get-Cal2Ast (Join-Path $dir '040-etat-formats.ps1')).EndBlock.Statements)) {
            $t = $st.Extent.Text
            if ($t.StartsWith('$script:GwFormatTable = ') -or $t.StartsWith('$script:GwFormats = ') -or $t.StartsWith('foreach ($fe in ($script:GwFormatTable') -or $t.StartsWith('$script:ExtDefaultFmt = ') -or $t.StartsWith('$script:PrecompThresholdNs = ')) { $parts.Add($t); $nTab++ }
        }
        if ($nTab -ne 5) { throw "table des formats, formats implicites et seuil de famille de 040 : $nTab instruction(s) trouvee(s) (5 attendues)" }
    }
    Write-Cal2Gen $outFile $parts
    return @{ Defs = $defs; Stmts = @{ A = $sA.Extent.Text; C = $sC.Extent.Text; Over = $sO.Extent.Text; Force = $sF.Extent.Text }; Lines = @{ A = $sA.Extent.StartLineNumber; C = $sC.Extent.StartLineNumber } }
}
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' -File | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'
$genNew = Join-Path $here 'gen-apres.ps1'
$infoNew = New-Gen $Wt $genNew $true
. $genNew
# Format de l onglet Ecriture, lu par les instructions reelles de Start-PrecompCalib et de Start-LevelCalib (Get-DiskCapBits) :
# aucun par defaut ; les cas P7, P8, M4, F et A le posent puis le retirent
$cmbWFmt = [pscustomobject]@{ Text = '' }
# Lot L4b : autres controles de l onglet Ecriture lus par les fonctions reelles du cas A (image, secteurs durs, lecteur
# 8 pouces, profil Auto, --precomp coche), jamais affiches ; module d analyse SCP declare present
$txtWFile = [pscustomobject]@{ Text = '' }; $chkWHard = [pscustomobject]@{ Checked = $false }; $chkWTG43 = [pscustomobject]@{ Checked = $false }
$cmbWProfile = [pscustomobject]@{ SelectedIndex = 0 }; $chkWPrecomp = [pscustomobject]@{ Checked = $true }
$script:ScpStatsOk = $true
# Motif factice du banc Start-PrecompCalib : densite tiree de l image (champ Known de Get-PatternBits), sauf cas F et A ;
# piste la plus longue (champ CapBits) : celle du motif, sauf cas A5
$script:TKnown = $true; $script:TCap = 0
function New-TPat([int]$bits, [bool]$known, [int]$cap = 0) {
    # Motif factice tel que New-CalibPattern le rend au plafond : cellules, densite tiree de l image ou non, cellules de la
    # piste la plus longue de l image (celles du motif par defaut)
    if ($cap -le 0) { $cap = $bits }
    return @{ Bits = $bits; Known = $known; CapBits = $cap }
}

# ---------------------------------------------------------------- bouchons, entrees factices
$script:RLog = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text) { $script:RLog.Add($text) }
function Get-LevelCtlCyls($units, [int]$maxCyl) { return ,[int[]]@(64, 78) }
function Set-TBound([int]$b) { $script:CalHardNsUser = $b; Set-CalibScale '' }
function New-TRef {
    # Reference factice de 80 cylindres, de 60 a 336 ns ; moyenne 198 ns (exacte en binaire, comme tous les termes du modele)
    $v = New-Object int[] 80
    for ($c = 0; $c -lt 80; $c++) { $v[$c] = 60 + 3 * $c + [int][math]::Floor($c / 2) }
    return ,$v
}
function New-TLr([string]$fam) {
    # Reference par tete telle que Get-LevelRef la rend (deux unites), meme courbe pour les deux tetes
    $units = @()
    foreach ($h in 0, 1) {
        $ref = New-TRef
        $cv = @{ Values = [int[]]$ref; MaxNs = 400; Date = '01/11/2026 10:00'; Test = 'fine'; Drive = 'A'; Breaks = @(); Bits = 101344; Slope = -1.0; Method = 'motif'; Converged = $true }
        $units += ,@{ RefKey = "${fam}_h$h"; Tag = "$h"; Head = $h; Cv = $cv; V = [int[]]$ref; KRef = 1.0; LCyls = [int[]]@(4, 16, 30, 44, 58, 72); Wit = [int[]]@(); Probe = $null; CapLo = 0; D0 = 0; NHist = 0 }
    }
    return @{ Ok = $true; Class = ''; Why = ''; Units = $units; Notes = @(); NCyl = 80; MaxCyl = 79; Family = $fam; Short = $false }
}
function New-TBrand([string]$fam, [int]$peak, [int]$maxNs) {
    # Courbe complete de la marque « Marque X » pour la tete 1 : reference plus une rampe, $peak ns au dernier cylindre
    $ref = New-TRef; $cur = New-Object int[] 80
    for ($c = 0; $c -lt 80; $c++) { $cur[$c] = $ref[$c] + [int][math]::Floor(($peak - 336) * $c / 79) }
    return @{ Brand = 'Marque X'; Drive = 'A'; RefKey = "${fam}_h1"; Tag = '1'; Head = 1; Family = $fam; RefDate = '01/11/2026 10:00'; LevelAlgo = 'lvl2'; Model = 'Mc'
              A = 0.0; S = 0.0; B = 0.0; N = 1; Date = '02/11/2026 09:00'; Levels = @(@{ Date = '02/11/2026 09:00'; Delta = 0 }); Shapes = @()
              Curve = [int[]]$cur; CurveDate = '02/11/2026 09:00'; CurveCalc = [string]$script:CalibCalc; CurveMaxNs = $maxNs; CurveSrc = 'complete' }
}
function New-TEst($u, [double]$delta) {
    # Estimation du niveau d une tete (forme de Get-LevelEstimate) : six cylindres de niveau au meme ecart, forme conforme
    $ds = @{}; $sg = @{}; $kd = @{}; $w = @{}
    foreach ($c in @($u.LCyls)) { $ds[[int]$c] = $delta; $sg[[int]$c] = 2.0; $kd[[int]$c] = 'interp'; $w[[int]$c] = 1.0 / 13.0 }
    return @{ N = 6; K = 1.0; KRaw = $null; KSpan = 0.0; Ds = $ds; Sigs = $sg; Kinds = $kd; Capped = @(); Floored = @(); Outliers = @(); Scatter = 0; Keep = [int[]]@($u.LCyls); W = $w
              Delta = $delta; SE = 1.0; Tau = 1.5; Rbar = 0.5; RTol = 2.0; Wit = @{}; ProbeZ = $null; ProbeKind = '' }
}
function Get-TMax($values) { return [int](@($values) | Measure-Object -Maximum).Maximum }
function Invoke-TRun([int]$bits, [int]$bound, [int]$need, [int]$drift, [string]$FamForce = '', [switch]$Refus) {
    # Calibration rapide factice menee a son bilan par les fonctions reelles (New-LevelCalUnits, Set-LevelBrandStart,
    # Build-LevelAdaptValues, Get-LevelUnitResults et ce qu elles appellent). $bits < 0 : unite sans densite (quatrieme
    # argument de New-LevelCalUnits omis). Tete 0 : forme adaptee (modele Ms), besoin modelise $need au dernier cylindre,
    # derive $drift corrigee avant le plafond. Tete 1 : courbe complete de la marque au depart ($need - 10 au dernier
    # cylindre), niveau mesure + 10 ns. $FamForce : famille imposee (image standard ecrite a plus de 250 kbit/s ; nom
    # distinct de $fam : PowerShell ignore la casse)
    Set-TBound $bound
    $script:LevelShifts = @{}; $script:RLog.Clear()
    $fam = 'std'; if ($bits -ge 104000) { $fam = 'long' }
    if ($FamForce) { $fam = $FamForce }
    $lr = New-TLr $fam
    $script:LevelBrands = @(New-TBrand $fam ($need - 10) 470)
    # Sans @() : New-LevelCalUnits rend le tableau des unites en un seul objet
    if ($bits -lt 0) { $units = New-LevelCalUnits $lr 'Marque X' 'A' } else { $units = New-LevelCalUnits $lr 'Marque X' 'A' $bits }
    $u0 = $units[0]; $u1 = $units[1]
    $s = 0.25; $a = [double]$need - 336.0 - $s * (336.0 - [double]$u0.ShapeV.RBar)
    $cov = New-Object 'double[][]' 2; $cov[0] = [double[]]@(0.0, 0.0); $cov[1] = [double[]]@(0.0, 0.0)
    $fit = @{ Names = [string[]]@('a', 's'); Beta = [double[]]@($a, $s); Cov = $cov; Coef = @{ a = $a; s = $s }; Tau = 1.5 }
    $u0.AN = @{ Model = 'Ms'; Fit = $fit; KPool = 1.05; Center = $null; Reserve = @(); Cs = [int[]]@(4, 16, 30, 44, 58, 72); Eff = 30.0; Zs = @{} }
    $u0.Mode = 'adapte'; $u0.AV = Build-LevelAdaptValues $u0 $fit 'Ms'
    $u0.VR = @{ Delta = [double]$drift; Corr = [bool]($drift -ne 0); RBar = 0.5; GMean = 3.0; RTol = 3.0 }
    $u0.Conv = $true; $u0.Level = [int][math]::Round($a); $u0.Passes = 3; $u0.Est = New-TEst $u0 $a
    $u1.Level = 10; $u1.Conv = $true; $u1.Passes = 2; $u1.Est = New-TEst $u1 10.0
    # Lot L12a : -Refus, tete 1 en courbe de refus (Get-LevelAdaptOutcome, mode « refus » : forme de la marque decalee du niveau)
    if ($Refus) { $u1.Mode = 'refus'; $u1.Refus = 'forme refusee par le test' }
    $cal = @{ Units = $units; Drive = 'A'; Brand = 'Marque X'; Family = $fam; Surf = $null; SurfGross = $false; Medium = $null }
    $res = Get-LevelUnitResults $cal '03/11/2026 12:00'
    $o = @{ Bits = $bits; Bound = $bound; Need = $need; Drift = $drift; Heads = @(); Issues = @(); Log = @($script:RLog.ToArray()); Start1 = [int[]]@($u1.V); HasMemo = [bool]$u1.Memo
            Av0 = @{ Hard = [int]$u0.AV.Hard; Max = (Get-TMax $u0.AV.Values); NSat = @($u0.AV.Sat).Count } }
    foreach ($rec in @($res.Recs)) {
        $o.Heads += ,@{ Head = [int]$rec.Head; Hard = [int]$rec.Hard; Model = [string]$rec.Model; Verdict = [string]$rec.Verdict; Values = [int[]]@($rec.Values); Sat = [int[]]@($rec.Sat)
                        Over = [int[]]@($rec.Over); Floor = [int[]]@($rec.Floor); Spec = [string]$rec.Spec; Delta = [int]$rec.Delta; LevelAlgo = [string]$rec.LevelAlgo }
    }
    for ($i = 0; $i -lt $res.Issues.Count; $i++) { $o.Issues += "$([bool]$res.Info[$i]) | $($res.Issues[$i])" }
    $o.Forced = [bool](Test-LevelAdaptedSpec ([string[]]@($res.Recs | ForEach-Object { [string]$_.Spec })))
    return $o
}
function Remove-TAdvice($lines) { return ,@(@($lines) | Where-Object { ([string]$_).IndexOf($advMark) -lt 0 }) }
function Get-RunLines($o) {
    # Resultat d une calibration factice en lignes de texte : courbes, plafonds, reserves, journal sans la ligne de conseil
    $l = @()
    foreach ($h in @($o.Heads)) {
        $l += "tete $($h.Head) : plafond $($h.Hard) ; modele $($h.Model) ; verdict $($h.Verdict) ; niveau $($h.Delta) ; $($h.LevelAlgo) ; satures [$($h.Sat -join ',')] ; au-dela [$($h.Over -join ',')] ; plancher [$($h.Floor -join ',')]"
        $l += "tete $($h.Head) valeurs : $($h.Values -join ' ')"
        $l += "tete $($h.Head) profil : $($h.Spec)"
    }
    $l += "depart de la tete 1 : $($o.Start1 -join ' ') ; marque : $($o.HasMemo)"
    $l += "courbe adaptee avant derive : plafond $($o.Av0.Hard), maximum $($o.Av0.Max), $($o.Av0.NSat) sature(s) ; controle impose : $($o.Forced)"
    foreach ($x in @($o.Issues)) { $l += "reserve $x" }
    foreach ($x in (Remove-TAdvice $o.Log)) { $l += "journal $x" }
    return ,$l
}
function Get-TNormText($o, [int]$cap) {
    # Reserves et journal ramenes a la forme de la 12.10 : ligne de conseil retiree, plafond annonce remis a 470 ns
    $l = @()
    foreach ($x in @(@($o.Issues) + @(Remove-TAdvice $o.Log))) { $l += ([string]$x).Replace("plafond porté à $cap ns", 'plafond porté à 470 ns') }
    return ,$l
}
function Test-TSameSeq($a, $b) {
    $a = @($a); $b = @($b)
    if ($a.Count -ne $b.Count) { return $false }
    for ($i = 0; $i -lt $a.Count; $i++) { if (-not ([string]$a[$i] -ceq [string]$b[$i])) { return $false } }
    return $true
}
function Get-FirstDiff($a, $b) {
    $a = @($a); $b = @($b)
    for ($i = 0; $i -lt [math]::Min($a.Count, $b.Count); $i++) { if (-not ([string]$a[$i] -ceq [string]$b[$i])) { return "ligne $i : « $(Get-Short ([string]$a[$i]) 120) » / « $(Get-Short ([string]$b[$i]) 120) »" } }
    if ($a.Count -ne $b.Count) { return "longueurs $($a.Count) et $($b.Count)" }
    return ''
}
function Compare-TRuns($r10, $r11, [int]$cap) {
    # $r10 : resultat a la regle de la 12.10 (470 ns pour toutes) ; $r11 : resultat de la 12.11 pour une image de plafond $cap.
    # Par tete : 'same' (plafond par disquette non porte, ni avant ni apres : tout identique) ; 'cap=' (porte, besoin au
    # plus au plafond le plus bas des deux : memes valeurs) ; 'cap+' (porte, besoin au-dela : valeurs ramenees au plafond
    # de l image) ; 'new' (porte en 12.11 seulement : borne reglee a 470 ns et besoin au-dela). Rend le premier ecart
    # Noms distincts de la borne ($bnd) et des tetes ($a, $b) : PowerShell ignore la casse
    $bnd = [int]$r10.Bound; $kinds = @(); $bad = ''
    for ($i = 0; $i -lt 2; $i++) {
        $a = $r10.Heads[$i]; $b = $r11.Heads[$i]
        $h10 = [int]$a.Hard; $h11 = [int]$b.Hard
        $va = [int[]]$a.Values; $vb = [int[]]$b.Values
        $kind = 'new'
        if ($h10 -eq $bnd -and $h11 -eq $bnd) { $kind = 'same' }
        elseif ($h10 -gt $bnd) { if (@($a.Sat).Count -eq 0 -and (Get-TMax $va) -le $h11) { $kind = 'cap=' } else { $kind = 'cap+' } }
        $kinds += $kind
        if ($bad) { continue }
        $w = "tete $i ($kind)"
        # Besoin au-dela du seuil : plafond porte en 12.10, ou borne a 470 ns et cylindres satures
        $trig = ($h10 -gt $bnd) -or ($bnd -eq 470 -and @($a.Sat).Count -gt 0)
        $exp11 = $bnd; if ($bnd -ge 400 -and $cap -gt $bnd -and $trig) { $exp11 = $cap }
        if ($h10 -ne $bnd -and $h10 -ne 470) { $bad = "$w : plafond $h10 a la regle de la 12.10" }
        elseif ($h11 -ne $exp11) { $bad = "$w : plafond $h11 au lieu de $exp11" }
        elseif ([string]$a.Model -ne [string]$b.Model -or [string]$a.Verdict -ne [string]$b.Verdict -or [int]$a.Delta -ne [int]$b.Delta -or [string]$a.LevelAlgo -ne [string]$b.LevelAlgo) { $bad = "$w : modele, verdict ou niveau differents" }
        elseif (-not (Test-TSameSeq $a.Floor $b.Floor)) { $bad = "$w : plancher different" }
        elseif ($kind -eq 'same' -or $kind -eq 'cap=') {
            if (-not (Test-TSameSeq $va $vb)) { $bad = "$w : valeurs differentes" }
            elseif (-not (Test-TSameSeq $a.Sat $b.Sat) -or -not (Test-TSameSeq $a.Over $b.Over)) { $bad = "$w : cylindres satures ou au-dela de la borne differents" }
            elseif ([string]$a.Spec -cne [string]$b.Spec) { $bad = "$w : profil different" }
        } else {
            for ($c = 0; $c -lt $va.Count; $c++) {
                if ($va[$c] -lt 470) { if ($vb[$c] -ne [math]::Min($va[$c], $h11)) { $bad = "$w : c$c vaut $($vb[$c]) au lieu de $([math]::Min($va[$c], $h11))"; break } }
                elseif ($vb[$c] -lt [math]::Min(470, $h11) -or $vb[$c] -gt $h11) { $bad = "$w : c$c vaut $($vb[$c]), hors de $([math]::Min(470, $h11)) a $h11"; break }
            }
        }
    }
    return @{ Bad = $bad; Kinds = $kinds }
}
function Get-TSig($o) {
    # Resume d un resultat : par tete, plafond, plus forte valeur, somme des valeurs, cylindres satures, cylindres au-dela
    return ((@($o.Heads) | ForEach-Object { '{0}:{1}:{2}:{3}:{4}' -f [int]$_.Hard, (Get-TMax $_.Values), [int](@($_.Values) | Measure-Object -Sum).Sum, @($_.Sat).Count, @($_.Over).Count }) -join '|')
}
$gBits = @(100000, 100336, 101344, 105312, 105808, 110000)
$gBound = @(350, 400, 430, 470)
$gNeed = @(@(380, 0), @(398, 0), @(398, 6), @(440, 0), @(470, 0), @(470, 6), @(480, 0), @(520, 0))
function Invoke-TGrid([bool]$withBits) {
    # None : unites sans densite, cle « borne/besoin/derive » ; Bits : unites de chaque densite, cle « cellules/borne/besoin/derive »
    $g = @{ None = @{}; Bits = @{} }
    foreach ($b in $gBound) {
        foreach ($nd in $gNeed) {
            $k = "$b/$($nd[0])/$($nd[1])"
            $g.None[$k] = Invoke-TRun -1 $b $nd[0] $nd[1]
            if ($withBits) { foreach ($bits in $gBits) { $g.Bits["$bits/$k"] = Invoke-TRun $bits $b $nd[0] $nd[1] } }
        }
    }
    return $g
}
function Invoke-TDisk([int]$bits, [int]$bound, [bool]$known = $true, [int]$cap = 0) {
    # Debut de la mesure complete de cette disquette : Start-DiskMeasure reelle, puis le banc Start-PrecompCalib (ses
    # instructions reelles : borne posee apres Set-CalibScale, ligne du journal), puis Reset-DiskHardNs. $known (lot L4b) :
    # densite du motif tiree de l image (champ Known) ; faux : valeur par defaut de la famille (image secteur). $cap :
    # cellules de la piste la plus longue de l image (champ CapBits ; 0 : celles du motif)
    Set-TBound $bound
    $script:RLog.Clear(); $script:Cal = $null; $script:CalDiskOnly = $null; $script:AfterCalib = ''; $script:TBits = $bits; $script:TKnown = $known; $script:TCap = $cap
    Start-DiskMeasure (New-TLr 'std') 'Marque X'
    $script:TKnown = $true; $script:TCap = 0
    $o = @{ Bits = $bits; Bound = $bound; HardNs = -1; During = [int]$script:CalHardNs; Log = @($script:RLog.ToArray()); After = [string]$script:AfterCalib; Left = [bool]($null -eq $script:CalDiskOnly) }
    if ($script:Cal) { $o.HardNs = [int]$script:Cal.HardNs }
    Reset-DiskHardNs
    $o.Reset = [int]$script:CalHardNs
    $script:Cal = $null; $script:AfterCalib = ''
    return $o
}
function Get-DiskLines($o) { return ,@(@("borne $($o.HardNs) ; pendant la mesure $($o.During) ; retablie $($o.Reset) ; suite « $($o.After) » ; demande lue $($o.Left)") + @($o.Log)) }
function Invoke-THd {
    # Haute densite : reference refusee par Get-LevelRef, mesure complete de la disquette refusee, bareme de la famille
    $l = @()
    foreach ($b in 400, 470) {
        Set-TBound $b
        $script:RLog.Clear(); $script:Cal = $null; $script:CalDiskOnly = $null; $script:AfterCalib = 'write'; $script:TBits = 202688
        $lr = Get-LevelRef 'hd' $true 'A' '' $false
        Start-DiskMeasure $lr 'Marque X'
        Set-CalibScale 'hd'
        $l += "borne $b : reference Ok $([bool]$lr.Ok), classe $($lr.Class), $(@($lr.Units).Count) unite(s) ; mesure complete : calibration $([bool]$script:Cal), demande $([bool]$script:CalDiskOnly), suite [$($script:AfterCalib)] ; borne haute densite $([int]$script:CalHardNs) ; reglage de $([int]$script:CalHardMinNs) a $([int]$script:CalHardMaxNs)"
        foreach ($x in @($script:RLog.ToArray())) { $l += "journal $x" }
        Set-CalibScale ''
        $l += "retour double densite : $([int]$script:CalHardNs)"
    }
    return ,$l
}
function Get-CodeText([string]$text) {
    # Texte d une fonction ou d une instruction sans ses commentaires ni ses fins de ligne
    $tk = $null; $er = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tk, [ref]$er)
    return ((@($tk) | Where-Object { [string]$_.Kind -ne 'Comment' -and [string]$_.Kind -ne 'NewLine' -and [string]$_.Kind -ne 'EndOfInput' } | ForEach-Object { $_.Text }) -join ' ')
}
function Get-Quarter([int]$bits) { $rem = [long]0; return [int][math]::DivRem([long]50000000, [long]$bits, [ref]$rem) }   # quart de la cellule, en entiers

"logic-calib-plafond-disquette : $Wt ; part de la cellule $($script:CalDiskCapCell), $($script:CalDiskCapMaxNs) ns au plus, repli $($script:CalHardMaxNs) ns ; PowerShell $($PSVersionTable.PSVersion)$(if ($Before) { ' ; source d avant fournie (-Before)' })"

# ---------------------------------------------------------------- P : cas de la specification
'--- P : regle du plafond (specification)'
$p1 = @(@(100000, 500), @(99984, 500), @(100336, 498), @(101344, 493), @(105808, 472), @(105616, 473), @(105312, 474), @(110000, 454), @(50000, 500), @(202688, 246), @(0, 470), @(-1, 470))
$bad = @($p1 | Where-Object { (Get-DiskCapNs $_[0]) -ne $_[1] } | ForEach-Object { "$($_[0]) cellules -> $(Get-DiskCapNs $_[0]) au lieu de $($_[1])" })
Chk 'P1' ($bad.Count -eq 0 -and (Get-DiskCapNs) -eq 470 -and (Get-DiskCapNs 101344) -is [int]) "Get-DiskCapNs : $($p1.Count) densites de la specification (500, 498, 493, 472 a 474, 454 ns ; 246 ns pour 202 688 cellules, sans cas particulier ; 470 ns sans densite) ; ecarts : $(Get-List $bad)"
$p2 = @(@(400, 101344, 493), @(470, 101344, 493), @(470, 110000, 470), @(350, 101344, 350), @(350, 100000, 350), @(350, 0, 350), @(400, 0, 470), @(430, 110000, 454), @(470, 105808, 472), @(399, 100000, 399))
$bad = @(); foreach ($x in $p2) { Set-TBound $x[0]; $g = Get-DiskHardNs $x[1]; if ($g -ne $x[2]) { $bad += "borne $($x[0]), $($x[1]) cellules -> $g au lieu de $($x[2])" } }
Set-TBound 400; $noArg = Get-DiskHardNs
Chk 'P2' ($bad.Count -eq 0 -and $noArg -eq 470) "Get-DiskHardNs : le plus haut de la borne reglee et du plafond de l image ; borne sous 400 ns respectee quelle que soit la densite ; sans densite : 470 ns ($noArg) ; ecarts : $(Get-List $bad)"
function Get-THard([int]$bits, [int]$bound, [string]$model, [int]$need) {
    Set-TBound $bound
    $u = @{ ShapeV = @{ V = [double[]]@(100.0, 200.0, 300.0) } }
    if ($bits -ge 0) { $u.ImgBits = $bits }
    return (Get-LevelAdaptHard $u $model ([double[]]@(100.0, 200.0, [double]$need)) 0.0 @())
}
$p3 = @(@(100000, 400, 'Ms', 480, 500), @(100000, 400, 'Ms', 399, 400), @(100000, 400, 'Ms', 400, 400), @(100000, 400, 'M0', 480, 400), @(100000, 350, 'Ms', 480, 350), @(-1, 400, 'Ms', 480, 470), @(0, 400, 'Ms', 480, 470),
        @(105808, 470, 'Ms', 475, 472), @(105808, 470, 'Ms', 470, 470), @(110000, 400, 'Ms', 465, 454), @(110000, 460, 'Ms', 465, 460), @(101344, 470, 'Ms', 480, 493))
$bad = @(); foreach ($x in $p3) { $g = Get-THard $x[0] $x[1] $x[2] $x[3]; if ($g -ne $x[4]) { $bad += "$($x[0]) cellules, borne $($x[1]), $($x[2]), besoin $($x[3]) -> $g au lieu de $($x[4])" } }
Chk 'P3' ($bad.Count -eq 0) "Get-LevelAdaptHard : $($p3.Count) cas (plafond de l image au-dela du seuil seulement, forme adaptee seulement, borne sous 400 ns respectee, unite sans densite a 470 ns, borne reglee au-dessus du quart de cellule gardee) ; ecarts : $(Get-List $bad)"
$r520 = Invoke-TRun 101344 400 520 0; $r480 = Invoke-TRun 101344 400 480 0; $r350 = Invoke-TRun 101344 350 380 0
$h = $r520.Heads[0]
$okA = ($r520.Av0.Hard -eq 493 -and $r520.Av0.Max -eq 493 -and $r520.Av0.NSat -gt 0 -and $h.Hard -eq 493 -and (Get-TMax $h.Values) -eq 493 -and $h.Sat.Count -gt 0 -and
        @($r520.Issues | Where-Object { $_.StartsWith('True | [tête 0] courbe adaptée au-delà de 400 ns') -and $_.Contains('plafond porté à 493 ns pour cette disquette seulement') }).Count -eq 1 -and
        @($r520.Log | Where-Object { $_.StartsWith('[tête 0] Plafond de 493 ns atteint aux cylindres') -and $_.EndsWith('sous-compensés.') }).Count -eq 1 -and @($r520.Log | Where-Object { $_.StartsWith('[tête 0]') -and $_.Contains('la borne se règle') }).Count -eq 0)
$h = $r480.Heads[0]
$expOver = @(0..79 | Where-Object { $h.Values[$_] -gt 400 })
$okB = ($h.Hard -eq 493 -and (Get-TMax $h.Values) -eq 480 -and $h.Sat.Count -eq 0 -and $expOver.Count -gt 0 -and (Test-TSameSeq $h.Over $expOver))
$h = $r350.Heads[0]
$okC = ($h.Hard -eq 350 -and (Get-TMax $h.Values) -eq 350 -and $h.Sat.Count -gt 0 -and $h.Over.Count -eq 0 -and @($r350.Log | Where-Object { $_.StartsWith('[tête 0] Plafond de 350 ns atteint') -and $_.EndsWith("la borne se règle jusqu'à 470 ns (precompMaxNs).") }).Count -eq 1)
$rLt = Invoke-TRun 110000 400 480 0; $rLt460 = Invoke-TRun 110000 460 480 0
$okD = ($rLt.Heads[0].Hard -eq 454 -and $rLt.Heads[1].Hard -eq 454 -and $rLt.Heads[0].Sat.Count -gt 0 -and $rLt.Heads[1].Sat.Count -gt 0 -and @($rLt.Log | Where-Object { $_.Contains('la borne se règle') }).Count -eq 0 -and
         @($rLt.Log | Where-Object { $_.Contains('] Plafond de 454 ns atteint aux cylindres') -and $_.EndsWith('sous-compensés.') }).Count -eq 2)
# Lot L12a (adapte a dessein) : borne reglee a 460 ns, au-dela du quart de la cellule de l image (454 ns) : borne gardee,
# plus aucun conseil de la relever (jusqu au lot L12a : « jusqu'à 470 ns », qui invitait a depasser le quart de la cellule)
$okE = ($rLt460.Heads[0].Hard -eq 460 -and $rLt460.Heads[1].Hard -eq 460 -and @($rLt460.Log | Where-Object { $_.Contains('] Plafond de 460 ns atteint aux cylindres') -and $_.EndsWith('sous-compensés.') }).Count -eq 2 -and
         @($rLt460.Log + $rLt460.Issues | Where-Object { $_.Contains('la borne se règle') }).Count -eq 0 -and @($rLt460.Log | Where-Object { $_.IndexOf($advMark) -ge 0 }).Count -eq 0)
Chk 'P4' ($okA -and $okB -and $okC -and $okD -and $okE) "courbe adaptee sur un ADF (Build-LevelAdaptValues, Get-LevelAdaptOutcome) : besoin 520 -> 493 ns, cylindres satures, reserve « plafond porté à 493 ns », sans conseil de relever la borne ($okA) ; besoin 480 -> aucune saturation, $($expOver.Count) cylindres au-dela de la borne ($okB) ; borne 350 -> conseil « jusqu'à 470 ns » garde ($okC) ; long track de 110 000 cellules : plafond de 454 ns atteint sur les deux tetes, sans conseil de relever la borne ($okD) ; meme image, borne reglee a 460 ns : borne gardee, sans conseil de la relever, deja au-dela du quart de la cellule ($okE)"
# P9 (lot L12a) : conseil « la borne se regle jusqu a N ns » : N = Get-BoundAdviceNs, le plus bas de 470 ns (haut de la
# plage du reglage) et du plafond de l image ; conseil seulement sous N. Fonction seule, puis calibrations factices par les
# fonctions reelles : forme adaptee (tete 0, 265), forme d une marque (tete 1, 260), courbe de refus (tete 1, 265). Relecture
# de L12a : seuil exact du conseil, 106 382 cellules (470 ns) puis 106 383, premiere densite sous 470 ns (469 ns)
$p9 = @(@(0, 470), @(101344, 470), @(100000, 470), @(105808, 470), @(105312, 470), @(106382, 470), @(106383, 469), @(106384, 469), @(110000, 454), @(202688, 246))
$bad = @($p9 | Where-Object { (Get-BoundAdviceNs @{ ImgBits = $_[0] }) -ne $_[1] } | ForEach-Object { "$($_[0]) cellules -> $(Get-BoundAdviceNs @{ ImgBits = $_[0] }) au lieu de $($_[1])" })
if ((Get-BoundAdviceNs $null) -ne 470 -or (Get-BoundAdviceNs @{}) -ne 470) { $bad += 'unite sans densite : pas 470 ns' }
# Lignes du journal et reserves (« Info | texte ») qui contiennent un texte ; sans virgule : @(...) en compte les lignes
function Get-TAdvLines($o, [string]$what) { return @(@($o.Log) + @($o.Issues) | Where-Object { ([string]$_).Contains($what) }) }
$rLt350 = Invoke-TRun 110000 350 480 0
$okP9a = ($rLt350.Heads[0].Hard -eq 350 -and $rLt350.Heads[1].Hard -eq 350 -and @(Get-TAdvLines $rLt350 "] Plafond de 350 ns atteint").Count -eq 2 -and
          @(Get-TAdvLines $rLt350 "la borne se règle jusqu'à 454 ns (precompMaxNs)").Count -eq 4 -and @(Get-TAdvLines $rLt350 'la borne se règle jusqu''à 470').Count -eq 0)
$rfA = Invoke-TRun 101344 350 480 0 -Refus; $rfL = Invoke-TRun 110000 350 480 0 -Refus; $rfL460 = Invoke-TRun 110000 460 480 0 -Refus
$okP9b = (@(Get-TAdvLines $rfA 'adaptation refusée : forme refusee par le test').Count -eq 1 -and @(Get-TAdvLines $rfA "[tête 1] Plafond de 350 ns atteint aux cylindres").Count -eq 1 -and
          @($rfA.Log | Where-Object { $_.StartsWith('[tête 1] Plafond de 350 ns') -and $_.EndsWith("la borne se règle jusqu'à 470 ns (precompMaxNs).") }).Count -eq 1 -and
          @($rfL.Log | Where-Object { $_.StartsWith('[tête 1] Plafond de 350 ns') -and $_.EndsWith("la borne se règle jusqu'à 454 ns (precompMaxNs).") }).Count -eq 1 -and
          @($rfL460.Log | Where-Object { $_.StartsWith('[tête 1] Plafond de 460 ns') -and $_.EndsWith('sous-compensés.') }).Count -eq 1 -and @(Get-TAdvLines $rfL460 'la borne se règle').Count -eq 0)
$script:Lang = 'en'; $rLtEn = Invoke-TRun 110000 350 480 0; $script:Lang = 'fr'
$okP9c = (@($rLtEn.Log | Where-Object { $_.EndsWith('the bound can be raised to 454 ns (precompMaxNs).') }).Count -eq 2)
Chk 'P9' ($bad.Count -eq 0 -and $okP9a -and $okP9b -and $okP9c) "Get-BoundAdviceNs : $($p9.Count) densites, 470 ns au plus, jamais au-dela du plafond de l image (454 ns pour 110 000 cellules), 470 ns sans densite ; long track de 110 000 cellules, borne 350 : « jusqu'à 454 ns » au journal et dans les reserves des deux tetes, jamais 470 ($okP9a) ; courbe de refus : 470 ns pour un ADF, 454 ns pour ce long track, aucun conseil avec une borne a 460 ns ($okP9b) ; interface anglaise ($okP9c) ; ecarts : $(Get-List $bad)"
Set-TBound 400
$en500 = New-TBrand 'std' 500 500
$v1 = Get-LevelBrandCurveValues $en500 (New-TRef) 101344; $v0 = Get-LevelBrandCurveValues $en500 (New-TRef); $v2 = Get-LevelBrandCurveValues $en500 (New-TRef) 100000
Chk 'P5' ((Get-TMax $v1) -eq 493 -and (Get-TMax $v0) -eq 470 -and (Get-TMax $v2) -eq 500 -and (Test-TSameSeq $v2 $en500.Curve)) "courbe d une marque mesuree jusqu a 500 ns (Get-LevelBrandCurveValues) : ADF -> $(Get-TMax $v1) ns, sans densite -> $(Get-TMax $v0) ns, cellule de 2 us -> $(Get-TMax $v2) ns, telle quelle"
# P6 : controle statique sur tous les modules
$uses = @{}; $calls = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Sort-Object Name)) {
    $ast = Get-Cal2Ast $f.FullName; $num = $f.Name.Substring(0, 3)
    foreach ($x in @($ast.FindAll({ param($n) ($n -is $tVar -and $n.VariablePath.UserPath -eq 'script:CalHardMaxNs') -or ($n -is $tCmd -and @('Get-DiskCapNs', 'Get-UnitCapNs', 'Get-DiskCapBits', 'Get-DiskBoundText', 'Get-DiskHardNs', 'Get-DiskCellNs', 'Get-DiskOverAdviceText', 'Get-LevelAdaptHard', 'Get-LevelBrandCurveValues', 'New-LevelCalUnits', 'Get-BoundAdviceNs') -contains $n.GetCommandName()) }, $true))) {
        $p = $x.Parent; while ($p -and $p -isnot $tFn) { $p = $p.Parent }
        $where = "${num}:" + $(if ($p) { $p.Name } else { '(script)' })
        if ($x -is $tVar) { if (-not $uses.ContainsKey($where)) { $uses[$where] = 0 }; $uses[$where]++ }
        else { $k = $x.GetCommandName(); if (-not $calls.ContainsKey($k)) { $calls[$k] = @() }; $calls[$k] += $where }
    }
}
$usesTxt = (@($uses.Keys | Sort-Object) | ForEach-Object { "$_ x$($uses[$_])" }) -join ', '
# Lot L12a (adapte a dessein) : les trois conditions du conseil de relever la borne (260:Get-LevelUnitResults,
# 265:Get-LevelAdaptOutcome x2) lisent Get-BoundAdviceNs, seule a lire CalHardMaxNs pour ce conseil
$usesExp = '120:Load-Config x2, 265:Get-BoundAdviceNs x1, 265:Get-DiskCapNs x1, 560:(script) x1'
function Get-Callers([string]$name) { return ((@($calls[$name]) | Sort-Object) -join ', ') }
$f270 = Join-Path $mods '270-fn-calib-complete.ps1'
$spAst = Get-FnAst $f270 'Start-PrecompCalib'
$setAt = @($spAst.Body.FindAll({ param($n) $n -is $tAsg -and $n.Left.Extent.Text -eq '$do.HardNs' }, $true))
$useAt = @($spAst.Body.FindAll({ param($n) $n -is $tCmd -and $n.GetCommandName() -eq 'Set-DiskHardNs' }, $true))
$readAt = @($spAst.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.MemberExpressionAst] -and $n.Extent.Text -eq '$do.HardNs' }, $true) | ForEach-Object { $_.Extent.StartOffset } | Sort-Object)
# Lot L4b : cellules de la piste ecrite gardees dans $do.CapBits (une affectation, avant la borne), lues par la borne et par
# la ligne du journal ; le motif transmet son champ Known
$capAt = @($spAst.Body.FindAll({ param($n) $n -is $tAsg -and $n.Left.Extent.Text -eq '$do.CapBits' }, $true))
$lineAt = @($spAst.Body.FindAll({ param($n) $n -is $tCmd -and $n.GetCommandName() -eq 'Get-DiskBoundText' }, $true))
$okOrder = ($setAt.Count -eq 1 -and $useAt.Count -eq 1 -and $capAt.Count -eq 1 -and $capAt[0].Extent.Text -eq '$do.CapBits = Get-DiskCapBits ([int]$pat.CapBits) ([string]$cmbWFmt.Text) ([bool]$pat.Known)' -and $capAt[0].Extent.StartOffset -lt $setAt[0].Extent.StartOffset -and
            $setAt[0].Extent.Text -eq '$do.HardNs = Get-DiskHardNs ([int]$do.CapBits)' -and $setAt[0].Extent.StartOffset -lt $useAt[0].Extent.StartOffset -and $readAt.Count -ge 4 -and $readAt[0] -eq $setAt[0].Extent.StartOffset -and
            $lineAt.Count -eq 1 -and $lineAt[0].Extent.Text -eq 'Get-DiskBoundText ([int]$do.HardNs) ([int]$do.CapBits) $pat' -and $lineAt[0].Extent.StartOffset -gt $useAt[0].Extent.StartOffset)
$dmAst = Get-FnAst $f270 'Start-DiskMeasure'
$okDm = ($dmAst.Extent.Text.Contains('HardNs = 0;') -and (Get-Callers 'Get-DiskHardNs') -eq '265:Get-LevelBrandCurveValues, 270:Start-PrecompCalib')
$okAdv = ((Get-Callers 'Get-DiskOverAdviceText') -eq '260:Get-LevelUnitResults, 265:Get-LevelAdaptOutcome, 270:Complete-PrecompCalib')
$slAst = Get-FnAst (Join-Path $mods '260-fn-calib-rapide.ps1') 'Start-LevelCalib'
$nuAt = @($slAst.Body.FindAll({ param($n) $n -is $tCmd -and $n.GetCommandName() -eq 'New-LevelCalUnits' }, $true))
$patAt = @($slAst.Body.FindAll({ param($n) $n -is $tAsg -and $n.Left.Extent.Text -eq '$pat' }, $true))
$okUnits = ((Get-Callers 'New-LevelCalUnits') -eq '260:Start-LevelCalib' -and $nuAt.Count -eq 1 -and $nuAt[0].CommandElements.Count -eq 5 -and $nuAt[0].CommandElements[4].Extent.Text -eq '$(if ($Geom) { 0 } else { Get-DiskCapBits ([int]$pat.CapBits) ([string]$cmbWFmt.Text) ([bool]$pat.Known) })' -and
            $patAt.Count -eq 1 -and $patAt[0].Extent.Text.Contains('New-CalibPattern') -and $patAt[0].Extent.StartOffset -lt $nuAt[0].Extent.StartOffset)
# Get-DiskCapBits : la calibration rapide (une fois) et la mesure complete de la disquette (une fois : la borne et la ligne
# du journal lisent la meme valeur, $do.CapBits) ; Get-DiskBoundText : la mesure complete seule. New-CalibPattern rend le
# champ Known du motif (Get-PatternBits). Corrections de relecture : les deux appels lisent le champ CapBits du motif
# (piste la plus longue de l image), que New-CalibPattern transmet ; plus aucune lecture de $pat.Bits par le plafond ;
# Get-DiskCapBits lit les cellules du codec du format dans Get-FormatCalibInfo (un appel)
$okBits = ((Get-Callers 'Get-DiskCapBits') -eq '260:Start-LevelCalib, 270:Start-PrecompCalib' -and (Get-Callers 'Get-DiskBoundText') -eq '270:Start-PrecompCalib' -and (Get-Callers 'Get-BoundAdviceNs') -eq '260:Get-LevelUnitResults, 265:Get-LevelAdaptOutcome')
$ncpTxt = (Get-FnAst (Join-Path $mods '240-fn-calib-mesure.ps1') 'New-CalibPattern').Extent.Text
$okKnown = ($ncpTxt.Contains('$pb = Get-PatternBits $family $img') -and $ncpTxt.Contains('Known = [bool]$pb.Known') -and $ncpTxt.Contains('CapBits = [int]$pb.CapBits'))
$dcbAst = Get-FnAst (Join-Path $mods '265-fn-calib-adaptative.ps1') 'Get-DiskCapBits'
$fciAt = @($dcbAst.Body.FindAll({ param($n) $n -is $tCmd -and $n.GetCommandName() -eq 'Get-FormatCalibInfo' }, $true))
$okCodec = ($fciAt.Count -eq 1 -and $fciAt[0].Extent.Text -eq 'Get-FormatCalibInfo $fmt')
Chk 'P6' ($usesTxt -eq $usesExp -and $okOrder -and $okDm -and $okAdv -and $okUnits -and $okBits -and $okKnown -and $okCodec) "Get-DiskCapBits lit les cellules du codec du format (Get-FormatCalibInfo, $okCodec) ; CalHardMaxNs dans le code : $usesTxt ; Start-PrecompCalib garde les cellules de la piste ecrite, pose la borne avant Set-DiskHardNs et avant toute lecture, puis ecrit la ligne de Get-DiskBoundText avec ces memes cellules ($okOrder) ; Start-DiskMeasure ne la calcule plus ($okDm) ; conseil appele par : $(Get-Callers 'Get-DiskOverAdviceText') ; Start-LevelCalib, seul appelant de New-LevelCalUnits, lui transmet les cellules de la piste ecrite une fois le motif cree, aucune pour la carte de l Accueil ($okUnits) ; Get-DiskCapBits appelee par : $(Get-Callers 'Get-DiskCapBits') ; Get-DiskBoundText par : $(Get-Callers 'Get-DiskBoundText') ($okBits) ; New-CalibPattern transmet le champ Known du motif ($okKnown)"
# P7 : carte « Calibrer le lecteur » de l Accueil (Geom). Le profil de sa calibration rapide peut etre place dans les champs
# --precomp d une image de la meme famille et d une autre densite (Complete-LevelCalib : condition de $toFields, qui ne lit
# pas la densite) : l argument reel de Start-LevelCalib ne transmet aucune densite, les unites gardent donc 470 ns, sous le
# quart de la cellule de toute image de la famille standard (487 ns a 1 950 ns, seuil de famille par defaut)
$clAst = Get-FnAst (Join-Path $mods '260-fn-calib-rapide.ps1') 'Complete-LevelCalib'
$tfAt = @($clAst.Body.FindAll({ param($n) $n -is $tAsg -and $n.Left.Extent.Text -eq '$toFields' }, $true))
$geomT = @{ Img = 'geometrie.hfe'; Label = 'ibm.720' }
# Lot L4b : motifs dont la densite est tiree de l image (champ Known ; l image de geometrie de la carte est un HFE)
$cmbWFmt.Text = 'atarist.880'; $bHome = Get-TUnitBits $geomT (New-TPat 100000 $true)
$cmbWFmt.Text = ''; $bHomeAdf = Get-TUnitBits $geomT (New-TPat 101344 $true); $bTab = Get-TUnitBits $null (New-TPat 100000 $true); $bTabAdf = Get-TUnitBits $null (New-TPat 101344 $true)
$rHome = Invoke-TRun $bHome 400 520 0
Chk 'P7' ($tfAt.Count -eq 1 -and $tfAt[0].Right.Extent.Text -eq '(-not $cal.Home) -or ((Get-WriteTabFamily) -eq $cal.Family -and -not $tgtL.Applies)' -and $bHome -eq 0 -and $bHomeAdf -eq 0 -and $bTab -eq 100000 -and $bTabAdf -eq 101344 -and
          $rHome.Heads[0].Hard -eq 470 -and $rHome.Heads[1].Hard -eq 470 -and (Get-TMax $rHome.Heads[0].Values) -eq 470 -and (Get-TMax $rHome.Heads[1].Values) -eq 470 -and (Get-DiskCapNs 102560) -eq 487) "carte de l Accueil : profil place dans les champs d apres la famille seule (Complete-LevelCalib) ; argument reel de Start-LevelCalib : $bHome et $bHomeAdf cellule pour la carte, $bTab et $bTabAdf pour l onglet Ecriture ; unites sans densite : $(Get-TMax $rHome.Heads[0].Values) et $(Get-TMax $rHome.Heads[1].Values) ns au plus pour un besoin de 520 ns, sous le quart de la cellule de toute image standard ($(Get-DiskCapNs 102560) ns a 1 950 ns)"
# P8 : format gw double densite de plus de 250 kbit/s (atari.130, atarist.440, atarist.880) : la piste ecrite compte
# 400 x debit cellules, plus que le motif (100 000 a 2 us) : le plafond suit la cellule ecrite. Format de la table a
# 250 kbit/s ou haute densite, image qui compte deja plus de cellules, unite sans densite : cellules inchangees.
# Lot L4b : quatrieme element, densite du motif tiree de l image (champ Known) : sans effet avec un format de la table ;
# sans format (vide, « (auto) ») les cellules ne sont gardees que si elle l est ; format absent de la table : 0 (cas F1 ;
# ce cas attendait 100 000 au lot L4)
# Corrections de relecture : format de la table dont le codec ecrit plus de cellules que le motif d une image secteur
# (amiga.amigados : 101 344, Get-FormatCalibInfo ; gw l ecrit que l image soit un ADF ou non) : jamais moins que celles
# du codec, densite tiree de l image ou non ; un motif plus long que le codec garde ses cellules
$p8 = @(@(100000, 'amiga.amigados', 101344, $false), @(100000, 'amiga.amigados', 101344, $true), @(100400, 'amiga.amigados', 101344, $true), @(105500, 'amiga.amigados', 105500, $true), @(105500, 'ibm.720', 105500, $true), @(105500, '', 105500, $true), @(105500, '', 0, $false),
        @(200000, 'amiga.amigados_hd', 202688, $false), @(202688, 'amiga.amigados_hd', 202688, $true), @(100000, 'atarist.880', 104400, $false), @(100000, 'atarist.440', 104400, $false), @(100000, 'atari.130', 104000, $false), @(100000, 'ibm.720', 100000, $false), @(100000, 'atarist.720', 100000, $false),
        @(100000, '(auto)', 100000, $true), @(100000, '', 100000, $true), @(100000, 'format.inconnu', 0, $false), @(101344, 'amiga.amigados', 101344, $true), @(101344, '', 101344, $true),
        @(105808, 'atarist.880', 105808, $true), @(200000, 'ibm.1440', 200000, $false), @(0, 'atarist.880', 0, $false), @(0, '', 0, $true),
        @(100000, 'atarist.880', 104400, $true), @(100000, 'ibm.720', 100000, $true), @(101344, 'amiga.amigados', 101344, $false))
$bad = @($p8 | Where-Object { (Get-DiskCapBits $_[0] $_[1] $_[3]) -ne $_[2] } | ForEach-Object { "$($_[0]) cellules, format « $($_[1]) », densite tiree de l image $($_[3]) -> $(Get-DiskCapBits $_[0] $_[1] $_[3]) au lieu de $($_[2])" })
# Image secteur (densite du motif par defaut : Known faux) et format de la table : argument reel de Start-LevelCalib
$cmbWFmt.Text = 'atarist.880'; $bSt = Get-TUnitBits $null (New-TPat 100000 $false); $cmbWFmt.Text = 'ibm.720'; $bIbm = Get-TUnitBits $null (New-TPat 100000 $false)
# Corrections de relecture : image secteur et amiga.amigados (cellules du codec) ; motif dont une piste est plus longue
# (champ CapBits : le plafond le lit, et non la densite du motif)
$cmbWFmt.Text = 'amiga.amigados'; $bAmi = Get-TUnitBits $null (New-TPat 100000 $false); $cmbWFmt.Text = ''; $bLongTrk = Get-TUnitBits $null (New-TPat 100400 $true 105500)
$rSt = Invoke-TRun $bSt 400 520 0 'std'
$okSt = ($rSt.Heads[0].Hard -eq 478 -and $rSt.Heads[1].Hard -eq 478 -and (Get-TMax $rSt.Heads[0].Values) -eq 478 -and (Get-TMax $rSt.Heads[1].Values) -eq 478 -and
         @($rSt.Issues | Where-Object { $_.Contains('plafond porté à 478 ns pour cette disquette seulement') }).Count -eq 2)
$rAmi = Invoke-TRun $bAmi 400 520 0 'std'
$okAmi = ($bAmi -eq 101344 -and $rAmi.Heads[0].Hard -eq 493 -and $rAmi.Heads[1].Hard -eq 493 -and (Get-TMax $rAmi.Heads[0].Values) -eq 493 -and (Get-TMax $rAmi.Heads[1].Values) -eq 493 -and
          @($rAmi.Issues | Where-Object { $_.Contains('plafond porté à 493 ns pour cette disquette seulement') }).Count -eq 2)
Chk 'P8' ($bad.Count -eq 0 -and (Get-DiskCapBits 100000 'atarist.880') -is [int] -and (Get-DiskCapNs (Get-DiskCapBits 100000 'atarist.880')) -eq 478 -and (Get-DiskCapNs (Get-DiskCapBits 100000 'atari.130')) -eq 480 -and
          (Get-DiskCapNs (Get-DiskCapBits 0 'atarist.880')) -eq 470 -and $bSt -eq 104400 -and $bIbm -eq 100000 -and $okSt -and (Get-DiskCapBits 100000 'amiga.amigados' $false) -eq 101344 -and (Get-DiskCapBits 100000 'amiga.amigados' $false) -is [int] -and
          (Get-DiskCapNs (Get-DiskCapBits 100000 'amiga.amigados' $false)) -eq 493 -and $okAmi -and $bLongTrk -eq 105500) "Get-DiskCapBits : $($p8.Count) cas (format de plus de 250 kbit/s : 400 x debit cellules ; format dont le codec ecrit plus de cellules que le motif, amiga.amigados : cellules du codec ; autres formats de la table, densite tiree de l image sans format, image de plus de cellules, unite sans densite : inchange ; format absent de la table : 0) ; plafond de 478 ns a 261 kbit/s et de 480 ns a 260 kbit/s, et non 500 ; argument reel de Start-LevelCalib avec atarist.880 : $bSt cellules ($bIbm avec ibm.720, $bAmi avec amiga.amigados, $bLongTrk pour un motif de 100 400 cellules dont une piste en compte 105 500) ; calibration factice, besoin de 520 ns : $(Get-TMax $rSt.Heads[0].Values) et $(Get-TMax $rSt.Heads[1].Values) ns au plus, reserve « plafond porté à 478 ns » ($okSt) ; image secteur et amiga.amigados : $(Get-TMax $rAmi.Heads[0].Values) et $(Get-TMax $rAmi.Heads[1].Values) ns, reserve « plafond porté à 493 ns » ($okAmi) ; ecarts : $(Get-List $bad)"

# ---------------------------------------------------------------- B : jamais plus du quart de la cellule ni 500 ns
'--- B : le plafond ne depasse jamais le quart de la cellule reelle ni 500 ns'
$nB = 0; $bad = @(); $minCap = 9999; $maxCap = 0
for ($bits = 50000; $bits -le 260000; $bits += 16) {
    $nB++
    $capB = Get-DiskCapNs $bits; $q = Get-Quarter $bits
    if ($capB -lt $minCap) { $minCap = $capB }; if ($capB -gt $maxCap) { $maxCap = $capB }
    if ($capB -ne [math]::Min(500, $q)) { $bad += "$bits cellules : $capB au lieu de $([math]::Min(500, $q))" }
}
foreach ($bits in 99999, 100001, 101345, 105807, 106382, 106383, 149999, 150000) {
    $nB++
    $capB = Get-DiskCapNs $bits; if ($capB -ne [math]::Min(500, (Get-Quarter $bits))) { $bad += "$bits cellules : $capB" }
}
Chk 'B1' ($bad.Count -eq 0 -and $maxCap -eq 500 -and $minCap -eq 192 -and (Get-DiskCapNs 106382) -eq 470 -and (Get-DiskCapNs 106383) -eq 469) "Get-DiskCapNs sur $nB densites (50 000 a 260 000 cellules, pas de 16, et 8 densites impaires) : toujours le quart de la cellule arrondi au ns inferieur (calcul en entiers), 500 ns au plus ; de $minCap a $maxCap ns ; 470 ns jusqu a 106 382 cellules (1,88 us), moins au-dela ; ecarts : $(Get-List $bad)"
$gridNew = Invoke-TGrid $true
$bad = @(); $nV = 0
foreach ($k in @($gridNew.Bits.Keys | Sort-Object)) {
    $r = $gridNew.Bits[$k]; $lim = [math]::Min(500, [math]::Max([int]$r.Bound, (Get-Quarter $r.Bits)))
    foreach ($h in @($r.Heads)) { $nV += $h.Values.Count; if ((Get-TMax $h.Values) -gt $lim -or $h.Hard -gt $lim) { $bad += "$k tete $($h.Head) : $(Get-TMax $h.Values) ns, plafond $($h.Hard), limite $lim" } }
    if ((Get-TMax $r.Start1) -gt $lim) { $bad += "$k : depart de la marque a $(Get-TMax $r.Start1) ns, limite $lim" }
}
Chk 'B2' ($bad.Count -eq 0 -and $gridNew.Bits.Count -eq 192) "$($gridNew.Bits.Count) calibrations factices ($nV valeurs de courbe) : aucune valeur ni aucun plafond au-dela du quart de la cellule de l image, sauf borne reglee plus haut (elle reste appliquee), jamais plus de 500 ns ; ecarts : $(Get-List $bad)"
# B3 : tous les formats gw que l application calibre en double densite (Get-FormatCalibInfo reelle : Cal « std »), table
# reelle de 040. Cellules de la piste ecrite, calcul independant de Get-DiskCapBits : codec AmigaDOS de gw (101 344), sinon
# 400 x debit (250 kbit/s par defaut). Le plafond ne depasse jamais le quart de cette cellule ; sans Get-DiskCapBits
# (densite du motif seule), les formats a 260 et 261 kbit/s le depassaient
# Corrections de relecture : le motif du format (Bits de Get-FormatCalibInfo : 101 344 pour amiga.amigados) n est celui
# d une image de ce format que pour un ADF ; une image secteur qui n est pas un ADF (IMG, ST, DSK) garde un motif de
# 100 000 cellules quel que soit le format (Get-PatternBits), densite non tiree de l image : le plafond ne depasse pas non
# plus le quart de la cellule ecrite pour ce motif-la (amiga.amigados : 500 ns pour un quart de 493 ns avant la correction)
$nF = 0; $bad = @(); $chg = @(); $over0 = @(); $chgS = @()
foreach ($name in @($script:GwFormats.Keys)) {
    $fi = Get-FormatCalibInfo $name
    if ([string]$fi.Cal -ne 'std') { continue }
    $nF++
    $fe1 = $script:GwFormats[$name]
    $wr = 100000; if ([string]$fe1.Enc -eq 'amiga') { $wr = 101344 } elseif ([int]$fe1.Rate -gt 0) { $wr = 400 * [int]$fe1.Rate }
    $qF = Get-Quarter $wr
    $bitsF = Get-DiskCapBits ([int]$fi.Bits) $name; $capF = Get-DiskCapNs $bitsF
    if ($capF -gt $qF -or $capF -gt 500) { $bad += "$name : $capF ns pour un quart de cellule de $qF ns" }
    $bitsS = Get-DiskCapBits 100000 $name $false; $capS = Get-DiskCapNs $bitsS
    if ($capS -gt $qF -or $capS -gt 500) { $bad += "$name, image secteur : $capS ns pour un quart de cellule de $qF ns" }
    if ((Get-DiskCapNs ([int]$fi.Bits)) -gt $qF) { $over0 += $name }
    if ($bitsF -ne [int]$fi.Bits) { $chg += "$name $capF" }
    if ($bitsS -ne 100000) { $chgS += "$name $capS" }
}
Chk 'B3' ($bad.Count -eq 0 -and $nF -ge 60 -and ($chg -join ', ') -ceq 'atari.130 480, atarist.440 478, atarist.880 478' -and ($over0 -join ', ') -ceq 'atari.130, atarist.440, atarist.880' -and ($chgS -join ', ') -ceq 'amiga.amigados 493, atari.130 480, atarist.440 478, atarist.880 478') "$nF formats gw calibres en double densite (table de 040, Get-FormatCalibInfo reelle), sur $($script:GwFormats.Count) : plafond jamais au-dela du quart de la cellule de la piste ecrite, pour le motif du format comme pour celui d une image secteur (100 000 cellules, densite non tiree de l image) ; formats dont le plafond suit le debit : $($chg -join ', ') ns ; image secteur, formats dont le plafond ne suit pas le motif : $($chgS -join ', ') ns ; sur la seule densite du motif, au-dela du quart : $($over0 -join ', ') ; ecarts : $(Get-List $bad)"

# ---------------------------------------------------------------- E : equivalence avec la regle de la 12.10
'--- E : equivalence avec la regle de la 12.10 (unite sans densite : 470 ns pour toutes)'
$bad = @(); $cnt = @{ 'same' = 0; 'cap=' = 0; 'cap+' = 0; 'new' = 0 }; $kindOf = @{}
foreach ($k in @($gridNew.Bits.Keys | Sort-Object)) {
    $r = $gridNew.Bits[$k]; $k0 = "$($r.Bound)/$($r.Need)/$($r.Drift)"
    $c = Compare-TRuns $gridNew.None[$k0] $r (Get-DiskCapNs $r.Bits)
    $kindOf[$k] = $c.Kinds; foreach ($x in $c.Kinds) { $cnt[$x]++ }
    if ($c.Bad) { $bad += "$k : $($c.Bad)" }
}
Chk 'E1' ($bad.Count -eq 0 -and $cnt['same'] -gt 0 -and $cnt['cap='] -gt 0 -and $cnt['cap+'] -gt 0 -and $cnt['new'] -gt 0) "$($gridNew.Bits.Count) calibrations factices, deux tetes chacune : $($cnt['same']) tetes sans plafond par disquette (identiques), $($cnt['cap=']) au plafond porte avec les memes valeurs, $($cnt['cap+']) ramenees au plafond de l image, $($cnt['new']) portees au-dela d une borne reglee a 470 ns ; ecarts : $(Get-List $bad)"
$bad = @(); $n2 = 0; $n3 = 0; $bad3 = @(); $n2Adv = 0
# Lot L12a (adapte a dessein) : conseil « la borne se regle jusqu a N ns » de la 12.11 ramene a 470 ns avant la comparaison,
# pour une image de plafond plus bas que 470 ns seulement (N = Get-BoundAdviceNs, verifie par P9) ; compte de ces cas
function Get-TAdvNorm($lines, [int]$bits) {
    $lim = [math]::Min(470, (Get-DiskCapNs $bits)); if ($lim -ge 470) { return ,@($lines) }
    $out = @(); foreach ($x in @($lines)) { $y = ([string]$x).Replace("jusqu'à $lim ns (precompMaxNs)", "jusqu'à 470 ns (precompMaxNs)"); if ($y -cne [string]$x) { $script:NAdvNorm++ }; $out += $y }
    return ,$out
}
$script:NAdvNorm = 0
foreach ($k in @($gridNew.Bits.Keys | Sort-Object)) {
    $r = $gridNew.Bits[$k]; $r0 = $gridNew.None["$($r.Bound)/$($r.Need)/$($r.Drift)"]; $kd = @($kindOf[$k])
    if ($kd[0] -eq 'same' -and $kd[1] -eq 'same') {
        $n2++; $d = Get-FirstDiff (Get-RunLines $r0) (Get-TAdvNorm (Get-RunLines $r) $r.Bits)
        if ($d -or @($r.Log | Where-Object { $_.IndexOf($advMark) -ge 0 }).Count -gt 0) { $bad += "$k : $d" }
    } elseif (@($kd | Where-Object { $_ -ne 'same' -and $_ -ne 'cap=' }).Count -eq 0) {
        $n3++; $d = Get-FirstDiff (Get-TNormText $r0 470) (Get-TNormText $r (Get-DiskCapNs $r.Bits))
        if ($d) { $bad3 += "$k : $d" }
    }
}
Chk 'E2' ($bad.Count -eq 0 -and $n2 -ge 60 -and $script:NAdvNorm -gt 0) "plafond par disquette non porte (besoin au plus au seuil, ou borne sous 400 ns) : $n2 calibrations identiques au caractere pres (courbes, plafonds, profils, reserves, journal), sans ligne de conseil d essai sur la machine cible ; lot L12a : $($script:NAdvNorm) lignes « la borne se regle jusqu a 454 ns » d une image de plafond plus bas ramenees a 470 ns avant la comparaison ; ecarts : $(Get-List $bad)"
Chk 'E3' ($bad3.Count -eq 0 -and $n3 -ge 20) "plafond porte, besoin au plus a 470 ns et au plafond de l image : $n3 calibrations aux memes courbes ; reserves et journal identiques a deux differences pres, le plafond annonce (celui de l image au lieu de 470 ns) et la ligne de conseil ; ecarts : $(Get-List $bad3)"
$bad = @(); $n4 = 0
foreach ($k in @($gridNew.Bits.Keys | Sort-Object)) {
    $r = $gridNew.Bits[$k]; if ((Get-DiskCapNs $r.Bits) -lt 470) { continue }
    $r0 = $gridNew.None["$($r.Bound)/$($r.Need)/$($r.Drift)"]
    for ($i = 0; $i -lt 2; $i++) {
        if (@($r0.Heads[$i].Sat).Count -gt 0) { continue }
        $n4++; if (-not (Test-TSameSeq $r0.Heads[$i].Values $r.Heads[$i].Values) -or [string]$r0.Heads[$i].Spec -cne [string]$r.Heads[$i].Spec) { $bad += "$k tete $i" }
    }
}
Chk 'E4' ($bad.Count -eq 0 -and $n4 -ge 120)"besoin de 470 ns ou moins (aucun cylindre sature a la regle de la 12.10), image de cellule 1,88 us ou plus : $n4 courbes identiques, valeur par valeur ; ecarts : $(Get-List $bad)"
$bad = @(); $n5 = 0
foreach ($k in @($gridNew.Bits.Keys | Sort-Object)) {
    $r = $gridNew.Bits[$k]; if ($r.Bound -ne 470 -or ($r.Need + $r.Drift) -gt 470) { continue }
    $n5++; $d = Get-FirstDiff (Get-RunLines $gridNew.None["$($r.Bound)/$($r.Need)/$($r.Drift)"]) (Get-RunLines $r)
    if ($d) { $bad += "$k : $d" }
}
Chk 'E5' ($bad.Count -eq 0 -and $n5 -eq 30)"borne precompMaxNs reglee a 470 ns, besoin de 470 ns ou moins : $n5 calibrations identiques au caractere pres, quelle que soit l image ; ecarts : $(Get-List $bad)"
$r454 = $gridNew.Bits['110000/400/470/0']; $r454b = $gridNew.Bits['110000/470/470/0']; $rNew = $gridNew.Bits['101344/470/480/0']; $rNew0 = $gridNew.None['470/480/0']
Set-TBound 460; $r460 = Get-THard 110000 460 'Ms' 465
Chk 'E6' ((Get-TMax $r454.Heads[0].Values) -eq 454 -and $r454.Heads[0].Hard -eq 454 -and (Get-TMax $r454b.Heads[0].Values) -eq 470 -and $r460 -eq 460 -and (Get-TMax $rNew.Heads[0].Values) -eq 480 -and (Get-TMax $rNew0.Heads[0].Values) -eq 470) "changements voulus : long track de 110 000 cellules (1,82 us), borne 400, besoin 470 -> $(Get-TMax $r454.Heads[0].Values) ns au lieu de 470 ; meme image, borne reglee a 470 -> $(Get-TMax $r454b.Heads[0].Values) ns (la borne reglee l emporte) ; ADF, borne reglee a 470, besoin 480 -> $(Get-TMax $rNew.Heads[0].Values) ns au lieu de $(Get-TMax $rNew0.Heads[0].Values)"

# ---------------------------------------------------------------- C : reserve et controle apres ecriture
'--- C : reserve « au-dela de la borne » et controle apres ecriture impose'
$bad = @(); foreach ($x in @(@(300, 400), @(350, 400), @(400, 400), @(430, 430), @(470, 470))) { Set-TBound $x[0]; if ((Get-DiskOverNs) -ne $x[1]) { $bad += "borne $($x[0]) -> $(Get-DiskOverNs)" } }
Chk 'C1' ($bad.Count -eq 0) "seuil du controle impose (Get-DiskOverNs) : le plus haut de 400 ns et de la borne reglee, comme en 12.10 ; ecarts : $(Get-List $bad)"
$bad = @(); $nOver = 0; $nAll = 0
foreach ($k in @($gridNew.Bits.Keys | Sort-Object)) {
    $r = $gridNew.Bits[$k]; $nAll++
    if (-not $r.Forced) { $bad += "$k : controle non impose" }
    for ($i = 0; $i -lt 2; $i++) {
        $h = $r.Heads[$i]; $exp = @(0..79 | Where-Object { $h.Values[$_] -gt $r.Bound })
        if ($h.Hard -le $r.Bound) { if ($h.Over.Count -ne 0) { $bad += "$k tete $i : cylindres au-dela sans plafond porte" }; continue }
        if (-not (Test-TSameSeq $h.Over $exp)) { $bad += "$k tete $i : cylindres au-dela de la borne" ; continue }
        if ($exp.Count -eq 0) { continue }
        $nOver++
        $pfx = "[tête $i] "
        $iss = @($r.Issues | Where-Object { $_.StartsWith("True | ${pfx}courbe adaptée au-delà de $($r.Bound) ns aux cylindres ") -and $_.EndsWith("plafond porté à $($h.Hard) ns pour cette disquette seulement) : contrôle après écriture imposé") })
        $at = -1; for ($j = 0; $j -lt $r.Log.Count; $j++) { if ($r.Log[$j].StartsWith("${pfx}Courbe adaptée au-delà de $($r.Bound) ns aux cylindres ")) { $at = $j } }
        $advOk = ($at -ge 0 -and $at + 1 -lt $r.Log.Count -and $r.Log[$at + 1] -ceq ($pfx + ($kAdv -f "$($r.Bound)")))
        if ($iss.Count -ne 1 -or -not $advOk -or -not $r.Log[$at].EndsWith("plafond porté à $($h.Hard) ns pour cette disquette seulement ; contrôle après écriture imposé.")) { $bad += "$k tete $i : reserve $($iss.Count), ligne du journal $at, conseil $advOk" }
    }
}
$nAdv = 0; foreach ($k in @($gridNew.Bits.Keys)) { $nAdv += @($gridNew.Bits[$k].Log | Where-Object { $_.IndexOf($advMark) -ge 0 }).Count }
Chk 'C2' ($bad.Count -eq 0 -and $nOver -ge 100 -and $nAdv -eq $nOver) "$nAll calibrations : controle apres ecriture impose pour chacune (Test-LevelAdaptedSpec reelle sur les profils enregistres) ; $nOver courbes au-dela de la borne : cylindres recenses, reserve d information « contrôle après écriture imposé », ligne du journal suivie du conseil d essai sur la machine cible, meme tete ($nAdv lignes de conseil) ; ecarts : $(Get-List $bad)"
Set-TBound 400
$vm = New-TRef; for ($c = 70; $c -lt 80; $c++) { $vm[$c] = 420 + 8 * ($c - 70) }   # courbe mesuree jusqu a 492 ns
$script:LevelShifts = @{ 'std_h0|0' = @{ Model = 'mesure'; Spec = (Build-CurveProfile $vm); Values = [int[]]$vm } }
$fHigh = Test-LevelAdaptedSpec ([string[]]@(Build-CurveProfile $vm))
$script:LevelShifts = @{ 'std_h0|0' = @{ Model = 'mesure'; Spec = (Build-CurveProfile (New-TRef)); Values = [int[]](New-TRef) } }
$fLow = Test-LevelAdaptedSpec ([string[]]@(Build-CurveProfile (New-TRef)))
$script:LevelPostForce = $false; $script:RLog.Clear()
Invoke-TDiskForce @(@{ Values = [int[]]$vm }, @{ Values = [int[]](New-TRef) })
$f1 = [bool]$script:LevelPostForce; $l1 = @($script:RLog.ToArray())
$script:LevelPostForce = $false; $script:RLog.Clear()
Invoke-TDiskForce @(@{ Values = [int[]](New-TRef) })
Chk 'C3' ($fHigh -and -not $fLow -and $f1 -and $l1.Count -eq 1 -and $l1[0] -ceq 'Contrôle après écriture imposé : courbe de cette disquette au-delà de 400 ns.' -and -not $script:LevelPostForce -and $script:RLog.Count -eq 0) "courbe mesuree sur la disquette : controle impose au-dela de 400 ns (Test-LevelAdaptedSpec : $fHigh ; instruction reelle de Complete-DiskMeasure : $f1, « $(Get-List $l1 1) »), pas en dessous ($fLow, $([bool]$script:LevelPostForce))"
$script:RLog.Clear(); $script:LevelShifts = @{}
$iss = New-Object System.Collections.Generic.List[string]; $kin = New-Object System.Collections.Generic.List[string]
Invoke-TDiskOver @{ DiskOnly = $true; HardNs = 493 } @{ Prefix = '[tête 1] '; Fit = @{ Values = [int[]]$vm } } $iss $kin
$l1 = @($script:RLog.ToArray())
$script:RLog.Clear(); $iss2 = New-Object System.Collections.Generic.List[string]; $kin2 = New-Object System.Collections.Generic.List[string]
Invoke-TDiskOver @{ DiskOnly = $true; HardNs = 493 } @{ Prefix = '[tête 1] '; Fit = @{ Values = [int[]](New-TRef) } } $iss2 $kin2
Chk 'C4' ($l1.Count -eq 2 -and $l1[0] -ceq "[tête 1] Courbe de cette disquette au-delà de 400 ns aux cylindres 70-79 (jusqu'à 492 ns) : plafond porté à 493 ns pour cette disquette seulement ; contrôle après écriture imposé." -and $l1[1] -ceq ('[tête 1] ' + ($kAdv -f '400')) -and $iss.Count -eq 1 -and $iss[0].EndsWith('contrôle après écriture imposé') -and $kin.Count -eq 1 -and $kin[0] -eq 'over' -and $script:RLog.Count -eq 0 -and $iss2.Count -eq 0) "fin de la mesure complete de la disquette (instruction reelle de Complete-PrecompCalib) : reserve « over » et ligne du journal au-dela de 400 ns, suivie du conseil ; rien en dessous"

# ---------------------------------------------------------------- D : courbe existante
'--- D : courbe de marque enregistree par la 12.10 (curveMaxNs 470)'
$json = '{"brand":"Marque X","drive":"A","refKey":"std_h1","tag":"1","head":1,"family":"std","refDate":"01/11/2026 10:00","levelAlgo":"lvl2","model":"Mc","a":0.0,"s":0.0,"b":0.0,"n":1,"date":"02/11/2026 09:00","levels":[{"date":"02/11/2026 09:00","delta":0}],"shapes":[],"curve":[#C#],"curveDate":"02/11/2026 09:00","curveCalc":"#K#","curveMaxNs":470,"curveSrc":"complete"}'
$cur468 = [int[]](New-TBrand 'std' 468 470).Curve
$enIn = ConvertFrom-LevelBrandConfig (ConvertFrom-Json $json.Replace('#C#', ($cur468 -join ',')).Replace('#K#', [string]$script:CalibCalc))
$back = ConvertTo-LevelBrandConfig $enIn
Chk 'D1' ($enIn -and [int]$enIn.CurveMaxNs -eq 470 -and [string]$enIn.CurveCalc -eq [string]$script:CalibCalc -and [string]$script:CalibCalc -eq '12.10' -and (Test-TSameSeq $enIn.Curve $cur468) -and [int]$back.curveMaxNs -eq 470 -and (Test-TSameSeq $back.curve $cur468) -and [string]$back.curveSrc -eq 'complete' -and (Get-CurveMaxNs @{ MaxNs = 470 }) -eq 470 -and (Get-CurveMaxNs @{}) -eq 300) "entree de marque d une configuration de la 12.10 : relue (ConvertFrom-LevelBrandConfig) et reecrite (ConvertTo-LevelBrandConfig) avec sa courbe et son curveMaxNs de 470 ns ; borne d une courbe de reference lue comme avant (Get-CurveMaxNs : 470, et 300 sans le champ)"
function Get-TStart([int]$bits, [int]$bound, $en = $null) {
    # Point de depart de la tete 1 quand la marque porte la courbe relue ($enIn, ou $en) : Set-LevelBrandStart reelle
    Set-TBound $bound
    if ($null -eq $en) { $en = $enIn }
    $script:LevelBrands = @($en); $lr = New-TLr 'std'
    if ($bits -lt 0) { $us = New-LevelCalUnits $lr 'Marque X' 'A' } else { $us = New-LevelCalUnits $lr 'Marque X' 'A' $bits }
    return @{ V = [int[]]@($us[1].V); Memo = $us[1].Memo; V0 = [int[]]@($us[0].V); Bits0 = $us[0].ImgBits; Bits1 = $us[1].ImgBits }
}
$bad = @()
foreach ($x in @(@(-1, 400), @(100000, 400), @(101344, 400), @(105808, 400), @(105312, 430), @(101344, 470), @(110000, 470))) {
    $st = Get-TStart $x[0] $x[1]
    if (-not (Test-TSameSeq $st.V $cur468) -or -not ($st.Memo -and $st.Memo.Curve) -or -not (Test-TSameSeq $st.V0 (New-TRef))) { $bad += "$($x[0]) cellules, borne $($x[1])" }
    if ($x[0] -ge 0 -and ([int]$st.Bits0 -ne $x[0] -or [int]$st.Bits1 -ne $x[0])) { $bad += "$($x[0]) cellules : densite non gardee par l unite" }
}
$st0 = Get-TStart -1 400
Chk 'D2' ($bad.Count -eq 0 -and [int]$st0.Bits0 -eq 0) "courbe de marque de la 12.10 (jusqu a 468 ns) reprise telle quelle comme point de depart (New-LevelCalUnits et Set-LevelBrandStart reelles) : sans densite, cellule de 2 us, ADF, long track, borne reglee a 470 ns ; la densite de l image est gardee par chaque unite (0 sans elle) ; ecarts : $(Get-List $bad)"
$stLo = Get-TStart 110000 400; $st350 = Get-TStart 101344 350; $st500 = Get-TStart 101344 400 $en500; $st500n = Get-TStart -1 400 $en500
Chk 'D3' ((Get-TMax $stLo.V) -eq 454 -and (Get-TMax $st350.V) -eq 350 -and (Get-TMax $st500.V) -eq 493 -and (Get-TMax $st500n.V) -eq 470) "meme courbe, cas ou elle est ramenee : long track de 110 000 cellules -> $(Get-TMax $stLo.V) ns (quart de sa cellule ; 470 en 12.10) ; borne reglee a 350 ns -> $(Get-TMax $st350.V) ns (comme en 12.10) ; courbe de marque mesuree jusqu a 500 ns reprise pour un ADF -> $(Get-TMax $st500.V) ns, sans densite -> $(Get-TMax $st500n.V) ns"
# D4 : reference plus longue que la courbe de la marque (image de 84 cylindres, courbe de 80) : cylindres de la courbe repris
# tels quels ; cylindres manquants prolonges (reference decalee de l ecart du dernier cylindre) et bornes au plafond de
# l image, 470 ns sans densite (regle de la 12.10)
Set-TBound 400
$ref84 = New-Object int[] 84; for ($c = 0; $c -lt 84; $c++) { $ref84[$c] = 60 + 4 * $c }
$en468 = @{ Curve = [int[]]$cur468 }
$xA = Get-LevelBrandCurveValues $en468 $ref84 101344; $xL = Get-LevelBrandCurveValues $en468 $ref84 105808; $xN = Get-LevelBrandCurveValues $en468 $ref84
Chk 'D4' ((Test-TSameSeq @($xA[0..79]) $cur468) -and (Test-TSameSeq @($xL[0..79]) $cur468) -and (Test-TSameSeq @($xN[0..79]) $cur468) -and (@($xA[80..83]) -join ' ') -ceq '472 476 480 484' -and (@($xL[80..83]) -join ' ') -ceq '472 472 472 472' -and (@($xN[80..83]) -join ' ') -ceq '470 470 470 470') "courbe de marque de la 12.10 (80 cylindres, 468 ns au plus) et reference de 84 cylindres : les 80 cylindres de la courbe repris tels quels ; cylindres prolonges : ADF $(@($xA[80..83]) -join ' ') (plafond de 493 ns), long track $(@($xL[80..83]) -join ' ') (472 ns), sans densite $(@($xN[80..83]) -join ' ') (470 ns, comme en 12.10)"

# ---------------------------------------------------------------- M : mesure complete de cette disquette
'--- M : mesure complete de cette disquette'
$m1 = @(@(101344, 350, 350), @(101344, 400, 493), @(101344, 430, 493), @(101344, 470, 493), @(100000, 400, 500), @(100336, 400, 498), @(105808, 400, 472), @(105808, 470, 472), @(105312, 430, 474), @(110000, 400, 454), @(110000, 430, 454), @(110000, 470, 470))
$bad = @(); $dk = @{}
foreach ($x in $m1) {
    $o = Invoke-TDisk $x[0] $x[1]; $dk["$($x[0])/$($x[1])"] = $o
    if ($o.HardNs -ne $x[2] -or $o.During -ne $x[2] -or $o.Reset -ne $x[1] -or $o.After -ne 'write' -or -not $o.Left -or $o.Log.Count -ne 1) { $bad += "$($x[0]) cellules, borne $($x[1]) : $(Get-List (Get-DiskLines $o) 1)" }
}
Chk 'M1' ($bad.Count -eq 0) "borne de la mesure complete (Start-DiskMeasure reelle, instructions reelles de Start-PrecompCalib, lignes $($infoNew.Lines.A) et $($infoNew.Lines.C) de 270) : $($m1.Count) cas, le plus haut de la borne reglee et du quart de la cellule ; borne sous 400 ns respectee ; posee pendant la mesure, retablie ensuite (Reset-DiskHardNs) ; ecarts : $(Get-List $bad)"
$lA = [string]$dk['101344/400'].Log[0]; $lB = [string]$dk['101344/350'].Log[0]; $lC = [string]$dk['110000/470'].Log[0]; $lD = [string]$dk['105808/470'].Log[0]
Chk 'M2' ($lA -ceq "Borne de la courbe de cette disquette : 493 ns, le quart de la cellule de l'image (1973 ns), 500 ns au plus ; au-delà de 400 ns, contrôle après écriture imposé." -and $lB -ceq 'Borne de la courbe de cette disquette : 350 ns (precompMaxNs).' -and $lC -ceq 'Borne de la courbe de cette disquette : 470 ns (precompMaxNs).' -and $lD -ceq "Borne de la courbe de cette disquette : 472 ns, le quart de la cellule de l'image (1890 ns), 500 ns au plus ; au-delà de 470 ns, contrôle après écriture imposé.") "ligne du journal : « $(Get-Short $lA 90) » ; borne reglee qui l emporte : « $lC »"
$script:Lang = 'en'
$oEn = Invoke-TDisk 101344 400; $advEn = Get-DiskOverAdviceText 400
$script:Lang = 'fr'
Chk 'M3' ([string]$oEn.Log[0] -ceq 'Curve bound for this disk: 493 ns, a quarter of the image cell (1973 ns), 500 ns at most; above 400 ns, post-write check enforced.' -and $advEn -ceq ($eAdv -f '400') -and (Get-DiskOverAdviceText 430) -ceq ($kAdv -f '430')) "interface anglaise : ligne de la borne et conseil (« $(Get-Short $advEn 70) »)"
# M4 : image secteur ecrite avec un format de plus de 250 kbit/s (motif de 100 000 cellules) : borne et cellule annoncee
# d apres la piste ecrite (instructions reelles de Start-PrecompCalib, format lu dans $cmbWFmt ; lot L4b : motif d une
# image secteur, densite par defaut, champ Known faux : un format de la table suffit a connaitre la cellule)
$cmbWFmt.Text = 'atarist.880'; $oSt = Invoke-TDisk 100000 400 $false; $oSt470 = Invoke-TDisk 100000 470 $false
$cmbWFmt.Text = 'ibm.720'; $oIbm = Invoke-TDisk 100000 400 $false
$cmbWFmt.Text = ''
Chk 'M4' ($oSt.HardNs -eq 478 -and $oSt.During -eq 478 -and $oSt.Reset -eq 400 -and $oSt.Log.Count -eq 1 -and [string]$oSt.Log[0] -ceq "Borne de la courbe de cette disquette : 478 ns, le quart de la cellule de l'image (1916 ns), 500 ns au plus ; au-delà de 400 ns, contrôle après écriture imposé." -and
          $oSt470.HardNs -eq 478 -and $oIbm.HardNs -eq 500 -and [string]$oIbm.Log[0] -ceq "Borne de la courbe de cette disquette : 500 ns, le quart de la cellule de l'image (2000 ns), 500 ns au plus ; au-delà de 400 ns, contrôle après écriture imposé.") "mesure complete, image secteur et format atarist.880 (261 kbit/s) : borne $($oSt.HardNs) ns et non 500, « $(Get-Short ([string]$oSt.Log[0]) 100) » ; borne reglee a 470 ns : $($oSt470.HardNs) ns ; format ibm.720 : $($oIbm.HardNs) ns"
# M5 (corrections de relecture) : borne et cellule annoncee d apres la cellule la plus courte ecrite. Image secteur et
# format amiga.amigados (motif de 100 000 cellules, densite non tiree de l image) : cellules du codec AmigaDOS, 493 ns et
# « (1973 ns) », et non 500 ns et « (2000 ns) ». Motif de 100 000 ou de 100 400 cellules dont une piste de l image en
# compte 105 504 ou 105 500 (champ CapBits) : 473 ns et « (1896 ns) », sans format comme avec ibm.720
$cmbWFmt.Text = 'amiga.amigados'; $oAmi = Invoke-TDisk 100000 400 $false; $oAmi470 = Invoke-TDisk 100000 470 $false
$cmbWFmt.Text = ''; $oMix = Invoke-TDisk 100000 400 $true 105504; $oMix2 = Invoke-TDisk 100400 400 $true 105500; $oMix350 = Invoke-TDisk 100400 350 $true 105500
$cmbWFmt.Text = 'ibm.720'; $oMixF = Invoke-TDisk 100400 400 $true 105500
$cmbWFmt.Text = ''
# Lot L12a (adapte a dessein) : la ligne nomme la piste la plus longue de l image (jusqu au lot L12a : « de l'image »)
$lMix = "Borne de la courbe de cette disquette : 473 ns, le quart de la cellule de la piste la plus longue de l'image (1896 ns), 500 ns au plus ; au-delà de 400 ns, contrôle après écriture imposé."
Chk 'M5' ($oAmi.HardNs -eq 493 -and $oAmi.During -eq 493 -and $oAmi.Reset -eq 400 -and $oAmi.Log.Count -eq 1 -and [string]$oAmi.Log[0] -ceq "Borne de la courbe de cette disquette : 493 ns, le quart de la cellule de l'image (1973 ns), 500 ns au plus ; au-delà de 400 ns, contrôle après écriture imposé." -and $oAmi470.HardNs -eq 493 -and
          $oMix.HardNs -eq 473 -and $oMix.During -eq 473 -and [string]$oMix.Log[0] -ceq $lMix -and $oMix2.HardNs -eq 473 -and [string]$oMix2.Log[0] -ceq $lMix -and $oMix350.HardNs -eq 350 -and $oMixF.HardNs -eq 473 -and [string]$oMixF.Log[0] -ceq $lMix) "mesure complete, image secteur et format amiga.amigados : borne $($oAmi.HardNs) ns et non 500, « $(Get-Short ([string]$oAmi.Log[0]) 100) » ; motif de 100 000 cellules dont une piste de l image en compte 105 504 : borne $($oMix.HardNs) ns, « $(Get-Short ([string]$oMix.Log[0]) 100) » ; meme regle avec le format ibm.720 ($($oMixF.HardNs) ns) ; borne reglee a 350 ns respectee ($($oMix350.HardNs) ns)"

# ---------------------------------------------------------------- F : format absent de la table (lot L4b)
'--- F : format explicite absent de la table (cellule de la piste ecrite inconnue : 470 ns, comme en 12.10)'
function Reset-TState {
    # Etat du test apres un cas qui peut lever (source d avant le lot) : format, langue, motif, calibration, borne
    $cmbWFmt.Text = ''; $txtWFile.Text = ''; $script:Lang = 'fr'; $script:TKnown = $true
    $script:Cal = $null; $script:CalDiskOnly = $null; $script:AfterCalib = ''; Reset-DiskHardNs
}
# F1 : la liste Format de l onglet Ecriture admet une saisie libre (gw plus recent, fichier diskdefs). Pour un format que la
# table $script:GwFormats ne connait pas, l application ignore quelle cellule gw ecrira : Get-DiskCapBits rend 0 (sans
# densite), que la densite du motif soit tiree de l image ou non ; un format de la table garde ses cellules
$fUnk = @(@(100000, 'format.inconnu', $false), @(100000, 'format.inconnu', $true), @(101344, 'ibm.9999', $true), @(105808, 'mon.diskdef', $true), @(100000, ' ibm.720', $false), @(100000, 'atarist.8800', $false))
$bad = @($fUnk | Where-Object { (Get-DiskCapBits $_[0] $_[1] $_[2]) -ne 0 -or (Get-DiskCapNs (Get-DiskCapBits $_[0] $_[1] $_[2])) -ne 470 } | ForEach-Object { "$($_[0]) cellules, format « $($_[1]) » -> $(Get-DiskCapBits $_[0] $_[1] $_[2]) cellules" })
$inTab = @($fUnk | Where-Object { $script:GwFormats.Contains($_[1]) })
foreach ($x in @(@(350, 350), @(400, 470), @(430, 470), @(470, 470))) { Set-TBound $x[0]; $g = Get-DiskHardNs (Get-DiskCapBits 100000 'format.inconnu' $false); if ($g -ne $x[1]) { $bad += "borne $($x[0]) -> $g au lieu de $($x[1])" } }
$cmbWFmt.Text = 'format.inconnu'; $bUnk = Get-TUnitBits $null (New-TPat 100000 $false); $bUnkK = Get-TUnitBits $null (New-TPat 101344 $true); $cmbWFmt.Text = ''
Chk 'F1' ($bad.Count -eq 0 -and $inTab.Count -eq 0 -and (Get-DiskCapBits 100000 'format.inconnu') -is [int] -and $bUnk -eq 0 -and $bUnkK -eq 0 -and (Get-DiskCapBits 100000 'ibm.720' $false) -eq 100000 -and (Get-DiskCapNs (Get-DiskCapBits 100000 'ibm.720' $false)) -eq 500) "Get-DiskCapBits, format absent de la table ($($fUnk.Count) cas, densite du motif tiree de l image ou non) : 0 cellule, donc 470 ns (Get-DiskCapNs) ; borne de la mesure complete : 470 ns des 400 ns de reglage, borne sous 400 ns respectee ; argument reel de Start-LevelCalib : $bUnk et $bUnkK ; un format de la table garde ses cellules (ibm.720 : $(Get-DiskCapBits 100000 'ibm.720' $false), 500 ns) ; ecarts : $(Get-List $bad)"
# F2 : calibration rapide factice, besoin de 520 ns, unites creees avec ces cellules : 470 ns au plus, resultat identique au
# caractere pres a celui d une unite sans densite (la regle de la 12.10 : cas N1, et Q1 avec -Before)
$rUnk = Invoke-TRun $bUnk 400 520 0 'std'; $rNone = Invoke-TRun -1 400 520 0; $rTab = Invoke-TRun $bIbm 400 520 0 'std'
$dUnk = Get-FirstDiff (Get-RunLines $rNone) (Get-RunLines $rUnk)
Chk 'F2' ($rUnk.Heads[0].Hard -eq 470 -and $rUnk.Heads[1].Hard -eq 470 -and (Get-TMax $rUnk.Heads[0].Values) -eq 470 -and (Get-TMax $rUnk.Heads[1].Values) -eq 470 -and @($rUnk.Issues | Where-Object { $_.Contains('plafond porté à 470 ns pour cette disquette seulement') }).Count -eq 2 -and
          $dUnk -eq '' -and $rTab.Heads[0].Hard -eq 500 -and (Get-TMax $rTab.Heads[0].Values) -eq 500) "calibration rapide factice, format absent de la table, besoin de 520 ns : $(Get-TMax $rUnk.Heads[0].Values) et $(Get-TMax $rUnk.Heads[1].Values) ns au plus, reserve « plafond porté à 470 ns », courbes, reserves et journal identiques a ceux d une unite sans densite (ecart : $dUnk) ; meme image avec ibm.720 : $(Get-TMax $rTab.Heads[0].Values) ns"
# F3 : mesure complete de cette disquette (instructions reelles de Start-PrecompCalib) : borne de 470 ns, ligne de journal
# de la 12.10, aucune exception (sans cellule, aucune division) ; borne reglee a 470 ns ou sous 400 ns : ligne precompMaxNs
$oU = @{}; $oUk = $null; $oUen = $null; $errU = ''
try {
    $cmbWFmt.Text = 'format.inconnu'
    foreach ($b in 350, 400, 430, 470) { $oU[$b] = Invoke-TDisk 100000 $b $false }
    $oUk = Invoke-TDisk 101344 400 $true
    $script:Lang = 'en'; $oUen = Invoke-TDisk 100000 400 $false
} catch { $errU = [string]$_.Exception.Message }
Reset-TState
$lU400 = 'Borne de la courbe de cette disquette : 470 ns ; au-delà de 400 ns, contrôle après écriture imposé.'
$okU = ($errU -eq '' -and $oU.Count -eq 4 -and $oU[400].HardNs -eq 470 -and $oU[400].During -eq 470 -and $oU[400].Reset -eq 400 -and $oU[400].Log.Count -eq 1 -and [string]$oU[400].Log[0] -ceq $lU400 -and
        $oU[430].HardNs -eq 470 -and [string]$oU[430].Log[0] -ceq 'Borne de la courbe de cette disquette : 470 ns ; au-delà de 430 ns, contrôle après écriture imposé.' -and
        $oU[470].HardNs -eq 470 -and [string]$oU[470].Log[0] -ceq 'Borne de la courbe de cette disquette : 470 ns (precompMaxNs).' -and
        $oU[350].HardNs -eq 350 -and $oU[350].During -eq 350 -and [string]$oU[350].Log[0] -ceq 'Borne de la courbe de cette disquette : 350 ns (precompMaxNs).')
$okUk = ($oUk -and $oUk.HardNs -eq 470 -and $oUk.Log.Count -eq 1 -and [string]$oUk.Log[0] -ceq $lU400)
$okUen = ($oUen -and [string]$oUen.Log[0] -ceq 'Curve bound for this disk: 470 ns; above 400 ns, post-write check enforced.')
Chk 'F3' ($okU -and $okUk -and $okUen) "mesure complete, format absent de la table : aucune exception (« $errU ») ; borne de 470 ns pour un reglage de 400 ou 430 ns, ligne de la 12.10 « $(Get-Short ([string]$(if ($oU[400]) { $oU[400].Log[0] })) 110) » ; reglage a 470 ou 350 ns : ligne precompMaxNs ($okU) ; image dont la densite est lue (101 344 cellules) : meme borne et meme ligne ($okUk) ; interface anglaise ($okUen)"
# F4 : Get-DiskBoundText seule : trois formes de la ligne, tirees de la borne, du seuil du controle impose et des cellules
$fTxt = @(@(400, 493, 101344, ($kBound -f '493', '400', '1973', '500')), @(400, 478, 104400, ($kBound -f '478', '400', '1916', '500')), @(470, 472, 105808, ($kBound -f '472', '470', '1890', '500')),
        @(400, 470, 0, ($kOldBound -f '470', '400')), @(430, 470, 0, ($kOldBound -f '470', '430')), @(470, 470, 0, 'Borne de la courbe de cette disquette : 470 ns (precompMaxNs).'),
        @(350, 350, 0, 'Borne de la courbe de cette disquette : 350 ns (precompMaxNs).'), @(350, 350, 101344, 'Borne de la courbe de cette disquette : 350 ns (precompMaxNs).'), @(470, 470, 110000, 'Borne de la courbe de cette disquette : 470 ns (precompMaxNs).'))
$bad = @(); $errB = ''
try {
    foreach ($x in $fTxt) { Set-TBound $x[0]; $g = [string](Get-DiskBoundText $x[1] $x[2]); if ($g -cne [string]$x[3]) { $bad += "borne $($x[0]), $($x[1]) ns, $($x[2]) cellules -> « $(Get-Short $g 90) »" } }
    Set-TBound 400; $noBits = [string](Get-DiskBoundText 470)
} catch { $errB = [string]$_.Exception.Message }
Set-TBound 400
Chk 'F4' ($errB -eq '' -and $bad.Count -eq 0 -and $noBits -ceq $lU400) "Get-DiskBoundText : $($fTxt.Count) cas (cellule connue : quart de la cellule annonce ; inconnue : ligne de la 12.10, sans cellule ; borne au plus au seuil : precompMaxNs), sans cellules en argument : ligne de la 12.10 ; aucune exception (« $errB ») ; ecarts : $(Get-List $bad)"
# F5 (lot L12a) : Get-DiskBoundText et le motif ($pat) : les cellules retenues (Get-DiskCapBits) sont celles de la piste la
# plus longue de l image quand elles egalent CapBits et depassent la densite du motif (IPF, HFE aux pistes inegales) : la
# ligne nomme cette piste ; sinon (pistes egales, ADF, image secteur, codec ou format au-dela de la piste la plus longue,
# sans motif) : ligne du lot L4. Textes de la table (019) ; plus aucune cle « jusqu'a 470 ns » ecrit en dur dans les modules
$kLong = "Borne de la courbe de cette disquette : {0} ns, le quart de la cellule de la piste la plus longue de l'image ({2} ns), {3} ns au plus ; au-delà de {1} ns, contrôle après écriture imposé."
$eLong = 'Curve bound for this disk: {0} ns, a quarter of the cell of the longest track of the image ({2} ns), {3} ns at most; above {1} ns, post-write check enforced.'
$f5 = @(@(473, 105500, @{ Bits = 100400; CapBits = 105500 }, ($kLong -f '473', '400', '1896', '500')), @(473, 105504, @{ Bits = 100000; CapBits = 105504 }, ($kLong -f '473', '400', '1896', '500')),
        @(493, 101344, @{ Bits = 101344; CapBits = 101344 }, ($kBound -f '493', '400', '1973', '500')), @(493, 101344, @{ Bits = 100000; CapBits = 100000 }, ($kBound -f '493', '400', '1973', '500')),
        @(478, 104400, @{ Bits = 100000; CapBits = 100000 }, ($kBound -f '478', '400', '1916', '500')), @(493, 101344, @{ Bits = 100000; CapBits = 100800 }, ($kBound -f '493', '400', '1973', '500')),
        @(473, 105500, $null, ($kBound -f '473', '400', '1896', '500')), @(470, 0, @{ Bits = 100400; CapBits = 105500 }, ($kOldBound -f '470', '400')),
        @(400, 105500, @{ Bits = 100400; CapBits = 105500 }, 'Borne de la courbe de cette disquette : 400 ns (precompMaxNs).'))
$bad = @(); $errF5 = ''
try {
    Set-TBound 400
    foreach ($x in $f5) { $g = [string](Get-DiskBoundText $x[0] $x[1] $x[2]); if ($g -cne [string]$x[3]) { $bad += "$($x[0]) ns, $($x[1]) cellules, motif $(if ($x[2]) { "$($x[2].Bits)/$($x[2].CapBits)" } else { 'absent' }) -> « $(Get-Short $g 90) »" } }
    $script:Lang = 'en'; $gEn = [string](Get-DiskBoundText 473 105500 @{ Bits = 100400; CapBits = 105500 }); $script:Lang = 'fr'
    if ($gEn -cne ($eLong -f '473', '400', '1896', '500')) { $bad += "anglais : « $(Get-Short $gEn 90) »" }
} catch { $errF5 = [string]$_.Exception.Message; $script:Lang = 'fr' }
$hard470 = @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Where-Object { $t = [System.IO.File]::ReadAllText($_.FullName); $t.Contains("jusqu''à 470 ns (precompMaxNs)") -or $t.Contains("jusqu'à 470 ns (precompMaxNs)") } | ForEach-Object { $_.Name })
Chk 'F5' ($errF5 -eq '' -and $bad.Count -eq 0 -and [string]$script:I18n[$kLong] -ceq $eLong -and [System.IO.File]::ReadAllText((Join-Path $mods '019-i18n-1211.ps1')).Contains($kLong) -and $hard470.Count -eq 0) "Get-DiskBoundText avec le motif : $($f5.Count) cas (IPF ou HFE aux pistes inegales : piste la plus longue nommee ; pistes egales, ADF, image secteur, codec au-dela de la piste la plus longue, sans motif : ligne du lot L4), anglais ; texte et anglais dans 019 ; modules qui ecrivent encore « jusqu'à 470 ns » en dur : $(Get-List $hard470) ; exception : « $errF5 » ; ecarts : $(Get-List $bad)"

# ---------------------------------------------------------------- A : aucun format (lot L4b)
'--- A : aucun format (vide ou « (auto) ») : plafond au-dela de 470 ns pour une densite tiree de l image seulement'
# Images factices (contenu nul, sauf en-tetes) dans le dossier de travail. Sans format, gw 1.23 refuse une image secteur
# (img.py : « Sector image requires a disk format to be specified »), sauf les types a format par defaut (attribut
# default_format de leur classe ; adf.py : amiga.amigados). L application ne lit la densite que d un ADF (codec AmigaDOS),
# d un IPF et d un HFE (bits par piste) : champ Known de Get-PatternBits. Pour toute autre image sans format, le motif
# prend la valeur par defaut de la famille et la cellule que gw ecrira n est pas etablie : 470 ns
$imgDir = Join-Path $here 'images'
if (-not (Test-Path -LiteralPath $imgDir)) { [void](New-Item -ItemType Directory -Path $imgDir -Force) }
function New-TFile([string]$name, [byte[]]$bytes) { $p = Join-Path $imgDir $name; [System.IO.File]::WriteAllBytes($p, $bytes); return $p }
function Set-TBE32([byte[]]$b, [int]$o, [int]$v) { $b[$o] = [byte](($v -shr 24) -band 255); $b[$o + 1] = [byte](($v -shr 16) -band 255); $b[$o + 2] = [byte](($v -shr 8) -band 255); $b[$o + 3] = [byte]($v -band 255) }
function New-TIpf([string]$name, [int]$trkBits) {
    # IPF minimal : enregistrement CAPS, puis deux enregistrements IMGE (cylindres 0 et 1) de $trkBits bits et 11 blocs
    $b = New-Object byte[] 172
    [System.Text.Encoding]::ASCII.GetBytes('CAPS').CopyTo($b, 0); Set-TBE32 $b 4 12
    foreach ($i in 0, 1) {
        $o = 12 + 80 * $i
        [System.Text.Encoding]::ASCII.GetBytes('IMGE').CopyTo($b, $o); Set-TBE32 $b ($o + 4) 80
        Set-TBE32 $b ($o + 12) $i; Set-TBE32 $b ($o + 48) $trkBits; Set-TBE32 $b ($o + 52) 11
    }
    return (New-TFile $name $b)
}
function New-THfe([string]$name, [int]$trackLen) {
    # HFE minimal (HXCPICFE, MFM, 250 kbit/s, 2 cylindres) : table des pistes au bloc 1, pistes de $trackLen octets
    # (deux faces), soit 8 x ($trackLen // 2) bits par face
    $blk = [int][math]::Ceiling($trackLen / 512.0)
    $b = New-Object byte[] ((2 + $blk) * 512 + $trackLen)
    [System.Text.Encoding]::ASCII.GetBytes('HXCPICFE').CopyTo($b, 0); $b[9] = 2; $b[10] = 2; $b[11] = 0; $b[12] = 250; $b[13] = 0; $b[18] = 1; $b[19] = 0
    foreach ($i in 0, 1) { $off = 2 + $blk * $i; $b[512 + 4 * $i] = [byte]($off -band 255); $b[513 + 4 * $i] = [byte]($off -shr 8); $b[514 + 4 * $i] = [byte]($trackLen -band 255); $b[515 + 4 * $i] = [byte]($trackLen -shr 8) }
    return (New-TFile $name $b)
}
function Get-TImage([string]$path, [string]$fmt) {
    # Ce que l application decide pour une image et un format de l onglet Ecriture, par ses fonctions reelles : famille
    # (Get-ImageFamily), densite du motif et son origine (Get-PatternBits), calibration admise par le bouton « Calibrer »
    # (Get-CalibImageCheck : Start-LevelCalibButton ne controle rien d autre avant la reference), mesure avant l ecriture
    # du bouton ECRIRE (Get-WriteLevelKind : « dd »), cellules transmises aux unites (argument reel de Start-LevelCalib),
    # plafond. Rend une ligne « famille|cellules du motif|tirees de l image|Calibrer|ECRIRE|cellules retenues|plafond »
    $txtWFile.Text = $path; $cmbWFmt.Text = $fmt
    $fam = Get-ImageFamily $path $fmt; $pb = Get-PatternBits $fam $path
    $chk = Get-CalibImageCheck; $kind = [string](Get-WriteLevelKind $path $fmt)
    $cb = [int](Get-TUnitBits $null $pb)
    $txtWFile.Text = ''; $cmbWFmt.Text = ''
    return ('{0}|{1}|{2}|{3}|{4}|{5}|{6}' -f $fam, [int]$pb.Bits, [bool]$pb.Known, [bool]$chk.Ok, $(if ($kind) { $kind } else { '-' }), $cb, (Get-DiskCapNs $cb))
}
function Test-TImages($rows, [string[]]$fmts) {
    # $rows : @(chemin, ligne attendue) ; rend les ecarts pour chaque format de $fmts
    $bad = @()
    foreach ($x in @($rows)) { foreach ($f in $fmts) { $g = Get-TImage ([string]$x[0]) $f; if ($g -cne [string]$x[1]) { $bad += "$([System.IO.Path]::GetFileName([string]$x[0])), format « $f » : $g au lieu de $($x[1])" } } }
    return ,$bad
}
$zAdf = New-TFile 'defaut.adf' (New-Object byte[] 901120)
$small = New-Object byte[] 4096
$zD64 = New-TFile 'defaut.d64' $small; $zD81 = New-TFile 'defaut.d81' $small; $zXdf = New-TFile 'defaut.xdf' $small; $zHdm = New-TFile 'defaut.hdm' $small
$zFd = New-TFile 'defaut.fd' $small; $zMgt = New-TFile 'defaut.mgt' $small
$zScp = New-TFile 'flux.scp' $small; $zImg = New-TFile 'secteurs.img' (New-Object byte[] 737280); $zSt = New-TFile 'secteurs.st' $small; $zMsa = New-TFile 'secteurs.msa' $small
$zIpf = New-TIpf 'long.ipf' 105500; $zHfe = New-THfe 'deux-us.hfe' 25000
$zIpfBad = New-TFile 'illisible.ipf' $small; $zHfeBad = New-TFile 'illisible.hfe' $small
# Corrections de relecture (cas A4, A5) : images dont les pistes n ont pas toutes la meme longueur, et HFE v3
function New-TIpfTracks([string]$name, [int[]]$trkBits) {
    # IPF minimal : enregistrement CAPS, puis un enregistrement IMGE de 11 blocs par element de $trkBits (bits de la piste)
    $b = New-Object byte[] (12 + 80 * $trkBits.Count)
    [System.Text.Encoding]::ASCII.GetBytes('CAPS').CopyTo($b, 0); Set-TBE32 $b 4 12
    for ($i = 0; $i -lt $trkBits.Count; $i++) {
        $o = 12 + 80 * $i
        [System.Text.Encoding]::ASCII.GetBytes('IMGE').CopyTo($b, $o); Set-TBE32 $b ($o + 4) 80
        Set-TBE32 $b ($o + 12) $i; Set-TBE32 $b ($o + 48) $trkBits[$i]; Set-TBE32 $b ($o + 52) 11
    }
    return (New-TFile $name $b)
}
function New-THfeTracks([string]$name, [int[]]$lens, [string]$sig = 'HXCPICFE') {
    # HFE minimal (MFM, 250 kbit/s) : table des pistes au bloc 1, un cylindre par element de $lens (octets, deux faces), soit
    # 8 x (longueur // 2) bits par face. $sig 'HXCHFEV3' : HFE v3, dont l application ne lit pas la table des pistes
    $offs = @(); $next = 2
    foreach ($l in $lens) { $offs += $next; $next += [int][math]::Ceiling($l / 512.0) }
    $b = New-Object byte[] ($next * 512)
    [System.Text.Encoding]::ASCII.GetBytes($sig).CopyTo($b, 0); $b[9] = [byte]$lens.Count; $b[10] = 2; $b[11] = 0; $b[12] = 250; $b[13] = 0; $b[18] = 1; $b[19] = 0
    for ($i = 0; $i -lt $lens.Count; $i++) { $b[512 + 4 * $i] = [byte]($offs[$i] -band 255); $b[513 + 4 * $i] = [byte]($offs[$i] -shr 8); $b[514 + 4 * $i] = [byte]($lens[$i] -band 255); $b[515 + 4 * $i] = [byte]($lens[$i] -shr 8) }
    return (New-TFile $name $b)
}
# IPF : 7 pistes de 100 400 bits et une de 105 500 (mediane 100 400) ; 6 pistes de 100 000 bits et 2 de 105 500 (mediane
# 100 000). HFE : 3 cylindres de 25 000 octets (100 000 bits par face) et un de 26 376 (105 504 bits) ; le meme en HFE v3 ;
# HFE v3 aux pistes egales. IMG et DSK de la taille d une disquette Amiga (901 120 octets)
$zIpfMix = New-TIpfTracks 'piste-longue.ipf' ([int[]]@(100400, 100400, 105500, 100400, 100400, 100400, 100400, 100400))
$zIpfMix2 = New-TIpfTracks 'pistes-longues.ipf' ([int[]]@(100000, 105500, 100000, 100000, 100000, 105500, 100000, 100000))
$zHfeMix = New-THfeTracks 'piste-longue.hfe' ([int[]]@(25000, 25000, 26376, 25000))
$zHfeV3 = New-THfeTracks 'v3.hfe' ([int[]]@(25000, 25000, 25000, 25000)) 'HXCHFEV3'; $zHfeV3Mix = New-THfeTracks 'v3-piste-longue.hfe' ([int[]]@(25000, 25000, 26376, 25000)) 'HXCHFEV3'
$zImgAmi = New-TFile 'amiga.img' (New-Object byte[] 901120); $zDskAmi = New-TFile 'amiga.dsk' (New-Object byte[] 901120)
$errA = ''; $badA1 = @('non joue'); $badA2 = @('non joue'); $badA3 = @('non joue'); $badA4 = @('non joue'); $badA5 = @('non joue'); $cellA4 = @()
try {
    # A1 : un cas par type auquel gw 1.23 donne un format par defaut. ADF (amiga.amigados, 101 344 cellules) : densite du
    # codec, chemin emprunte, 493 ns, le quart de sa cellule. D64 (commodore.1541, GCR) : calibration refusee, aucun chemin.
    # XDF, HDM (pc98.2hd, haute densite a 360 tr/min) : calibration refusee, aucun chemin. D81 (commodore.1581), FD
    # (thomson.1s320), MGT (ibm.800), MFM a 250 kbit/s : aucune mesure depuis ECRIRE (densite non etablie), mais le bouton
    # « Calibrer » en test rapide les admet : motif par defaut de 100 000 cellules, cellule non etablie, 470 ns
    $a1 = @(@($zAdf, 'std|101344|True|True|dd|101344|493'), @($zD64, 'std|100000|False|False|-|0|470'), @($zD81, 'std|100000|False|True|-|0|470'), @($zXdf, 'std|100000|False|False|-|0|470'),
            @($zHdm, 'std|100000|False|False|-|0|470'), @($zFd, 'std|100000|False|True|-|0|470'), @($zMgt, 'std|100000|False|True|-|0|470'))
    $badA1 = Test-TImages $a1 @('(auto)', '')
    # A2 : autres images sans format. Flux SCP : calibration refusee, aucun chemin. Image secteur brute (IMG, ST : gw exige
    # un format) et MSA : admises par « Calibrer », cellule non etablie, 470 ns. IPF et HFE lisibles : bits par piste de
    # l image, chemin emprunte, quart de cette cellule (473 ns pour 105 500 cellules, 500 ns pour 100 000). IPF ou HFE dont
    # la densite ne se lit pas : chemin emprunte avec le motif par defaut, 470 ns. Corrections de relecture : les cellules
    # retenues sont celles de la piste la plus longue de l image (IPF : 105 500, le motif en compte 105 488, multiple de 16)
    $a2 = @(@($zScp, 'std|100000|False|False|-|0|470'), @($zImg, 'std|100000|False|True|-|0|470'), @($zSt, 'std|100000|False|True|-|0|470'), @($zMsa, 'std|100000|False|True|-|0|470'),
            @($zIpf, 'long|105488|True|True|dd|105500|473'), @($zHfe, 'std|100000|True|True|dd|100000|500'), @($zIpfBad, 'std|100000|False|True|dd|0|470'), @($zHfeBad, 'std|100000|False|True|dd|0|470'))
    $badA2 = Test-TImages $a2 @('(auto)', '')
    # A3 : memes images avec un format explicite : un format de la table suffit a connaitre la cellule (500 ns a
    # 250 kbit/s, 478 ns a 261 kbit/s) ; un format absent de la table emprunte le chemin (« Calibrer » et ECRIRE) et garde
    # 470 ns, meme quand la densite de l image est lue (gw decode alors l image par ce format)
    $badA3 = @()
    foreach ($x in @(@($zImg, 'ibm.720', 'std|100000|False|True|dd|100000|500'), @($zImg, 'atarist.880', 'std|100000|False|True|dd|104400|478'), @($zImg, 'format.inconnu', 'std|100000|False|True|dd|0|470'),
                     @($zIpf, 'format.inconnu', 'long|105488|True|True|dd|0|470'), @($zHfe, 'format.inconnu', 'std|100000|True|True|dd|0|470'), @($zAdf, 'amiga.amigados', 'std|101344|True|True|dd|101344|493'))) {
        $g = Get-TImage ([string]$x[0]) ([string]$x[1]); if ($g -cne [string]$x[2]) { $badA3 += "$([System.IO.Path]::GetFileName([string]$x[0])), format « $($x[1]) » : $g au lieu de $($x[2])" }
    }
    # A4 (corrections de relecture) : IPF et HFE dont une piste est plus longue que les autres. La densite du motif reste la
    # mediane des pistes (100 400 et 100 000 cellules : la calibration ne change pas) ; le plafond suit la piste la plus
    # longue, donc la cellule la plus courte : 473 ns pour 105 500 ou 105 504 cellules, et non 498 ou 500 ns. HFE v3 : la
    # longueur des pistes n est pas lue (densite tiree du seul debit de l en-tete) : cellule non etablie, 470 ns, que ses
    # pistes soient egales ou non. Lectures directes de Get-IpfCellInfo, Get-HfeCellInfo et Get-PatternBits : champs
    # MaxBits et CapBits
    $a4 = @(@($zIpfMix, 'std|100400|True|True|dd|105500|473'), @($zIpfMix2, 'std|100000|True|True|dd|105500|473'), @($zHfeMix, 'std|100000|True|True|dd|105504|473'),
            @($zHfeV3, 'std|100000|False|True|dd|0|470'), @($zHfeV3Mix, 'std|100000|False|True|dd|0|470'))
    $badA4 = Test-TImages $a4 @('(auto)', '')
    $iI = Get-IpfCellInfo $zIpfMix; $iH = Get-HfeCellInfo $zHfeMix; $iV = Get-HfeCellInfo $zHfeV3Mix; $iU = Get-HfeCellInfo $zHfe; $iL = Get-IpfCellInfo $zIpf
    $pI = Get-PatternBits 'std' $zIpfMix; $pH = Get-PatternBits 'std' $zHfeMix; $pV = Get-PatternBits 'std' $zHfeV3Mix; $pS = Get-PatternBits 'std' $zImg; $pA = Get-PatternBits 'std' $zAdf; $pB = Get-PatternBits 'std' $zHfeBad; $pLg = Get-PatternBits 'long' $zImg
    $cellA4 = @("IPF $([int64]$iI.Bits)/$([int64]$iI.MaxBits)", "HFE $([int64]$iH.Bits)/$([int64]$iH.MaxBits)", "HFE v3 $([int64]$iV.Bits)/$([int64]$iV.MaxBits)", "HFE egal $([int64]$iU.Bits)/$([int64]$iU.MaxBits)", "IPF egal $([int64]$iL.Bits)/$([int64]$iL.MaxBits)",
                "motif IPF $([int]$pI.Bits)/$([int]$pI.CapBits)/$([bool]$pI.Known)", "motif HFE $([int]$pH.Bits)/$([int]$pH.CapBits)/$([bool]$pH.Known)", "motif HFE v3 $([int]$pV.Bits)/$([int]$pV.CapBits)/$([bool]$pV.Known)",
                "motif IMG $([int]$pS.Bits)/$([int]$pS.CapBits)/$([bool]$pS.Known)", "motif ADF $([int]$pA.Bits)/$([int]$pA.CapBits)/$([bool]$pA.Known)", "motif HFE illisible $([int]$pB.Bits)/$([int]$pB.CapBits)/$([bool]$pB.Known)", "motif long par defaut $([int]$pLg.Bits)/$([int]$pLg.CapBits)/$([bool]$pLg.Known)")
    # A5 (corrections de relecture) : format explicite. amiga.amigados sur une image secteur qui n est pas un ADF (IMG,
    # DSK de 901 120 octets) : motif de 100 000 cellules, cellules du codec AmigaDOS retenues, 493 ns et non 500 ; IPF ou
    # HFE a piste longue avec un format de la table a 250 kbit/s : la piste la plus longue reste retenue (473 ns) ; HFE v3
    # avec un format de la table : cellule du format (500 ns a 250 kbit/s, 493 ns pour amiga.amigados) ; HFE v3 et format
    # absent de la table : 470 ns
    $badA5 = @()
    foreach ($x in @(@($zImgAmi, 'amiga.amigados', 'std|100000|False|True|dd|101344|493'), @($zDskAmi, 'amiga.amigados', 'std|100000|False|True|dd|101344|493'), @($zImg, 'amiga.amigados', 'std|100000|False|True|dd|101344|493'),
                     @($zIpfMix, 'ibm.720', 'std|100400|True|True|dd|105500|473'), @($zIpfMix, 'amiga.amigados', 'std|100400|True|True|dd|105500|473'), @($zHfeMix, 'ibm.720', 'std|100000|True|True|dd|105504|473'),
                     @($zHfeV3, 'ibm.720', 'std|100000|False|True|dd|100000|500'), @($zHfeV3, 'amiga.amigados', 'std|100000|False|True|dd|101344|493'), @($zHfeV3Mix, 'format.inconnu', 'std|100000|False|True|dd|0|470'))) {
        $g = Get-TImage ([string]$x[0]) ([string]$x[1]); if ($g -cne [string]$x[2]) { $badA5 += "$([System.IO.Path]::GetFileName([string]$x[0])), format « $($x[1]) » : $g au lieu de $($x[2])" }
    }
} catch { $errA = [string]$_.Exception.Message }
Reset-TState
# Bibliotheque et restauration (Start-PresetWrite) : sans format, seuls ADF, IPF et HFE atteignent la calibration ou la mesure
$ddAt = @((Get-Cal2Ast (Join-Path $mods '140-fn-ecriture.ps1')).FindAll({ param($n) $n -is $tAsg -and $n.Left.Extent.Text -eq '$ddKnown' }, $true))
$okDd = ($ddAt.Count -eq 1 -and $ddAt[0].Right.Extent.Text -eq "(@('.adf', '.ipf', '.hfe') -contains `$ext) -or (`$explicit -and `$fmt -notmatch '^(commodore\.15[47]1|mac\.|apple2\.)')")
Chk 'A1' ($errA -eq '' -and $badA1.Count -eq 0 -and $okDd) "types a format par defaut de gw 1.23, sans format (« (auto) » et vide, $($a1.Count) types) : ADF 101 344 cellules lues, chemin emprunte, 493 ns ; D64 (GCR), XDF et HDM (haute densite a 360 tr/min) : calibration refusee, aucun chemin ; D81, FD, MGT : admis par « Calibrer » seulement, motif par defaut, 470 ns ; depuis la Bibliotheque, seuls ADF, IPF et HFE sont mesures sans format ($okDd) ; exception : « $errA » ; ecarts : $(Get-List $badA1)"
Chk 'A2' ($errA -eq '' -and $badA2.Count -eq 0) "autres images sans format : SCP refuse (aucun chemin) ; IMG, ST, MSA admis par « Calibrer », 470 ns ; IPF de 105 488 cellules : 473 ns ; HFE de 100 000 cellules : 500 ns ; IPF ou HFE de densite illisible : chemin emprunte, 470 ns ; ecarts : $(Get-List $badA2)"
Chk 'A3' ($errA -eq '' -and $badA3.Count -eq 0) "format explicite sur ces images : ibm.720 500 ns, atarist.880 478 ns ; format absent de la table : chemin emprunte, 470 ns, densite de l image lue ou non ; ADF et amiga.amigados : 493 ns ; ecarts : $(Get-List $badA3)"
$cellExp = 'IPF 100400/105500 ; HFE 100000/105504 ; HFE v3 100000/0 ; HFE egal 100000/100000 ; IPF egal 105500/105500 ; motif IPF 100400/105500/True ; motif HFE 100000/105504/True ; motif HFE v3 100000/100000/False ; motif IMG 100000/100000/False ; motif ADF 101344/101344/True ; motif HFE illisible 100000/100000/False ; motif long par defaut 105808/105808/False'
Chk 'A4' ($errA -eq '' -and $badA4.Count -eq 0 -and ($cellA4 -join ' ; ') -ceq $cellExp) "IPF et HFE dont une piste est plus longue que les autres, sans format : densite du motif inchangee (mediane), plafond d apres la piste la plus longue, 473 ns et non 498 ou 500 ; HFE v3 (longueur des pistes non lue) : 470 ns ; cellules mediane/plus longue lues par Get-IpfCellInfo et Get-HfeCellInfo, motif/retenues/tirees de l image par Get-PatternBits : $($cellA4 -join ' ; ') ; exception : « $errA » ; ecarts : $(Get-List $badA4)"
Chk 'A5' ($errA -eq '' -and $badA5.Count -eq 0) "format explicite : amiga.amigados sur une image secteur qui n est pas un ADF (IMG, DSK) : cellules du codec AmigaDOS, 493 ns et non 500 ; IPF ou HFE a piste longue avec ibm.720 ou amiga.amigados : 473 ns ; HFE v3 avec un format de la table : cellule du format (500 ns, 493 ns) ; HFE v3 et format absent de la table : 470 ns ; ecarts : $(Get-List $badA5)"

# ---------------------------------------------------------------- H : haute densite
'--- H : haute densite'
$hdNew = Invoke-THd
$hdExp = @("borne 400 : reference Ok False, classe domain, 0 unite(s) ; mesure complete : calibration False, demande False, suite [] ; borne haute densite 200 ; reglage de 300 a 470",
           'journal Mesure complète de cette disquette impossible : elle demande la référence du lecteur par tête (écriture lente). Écriture annulée.', 'retour double densite : 400',
           "borne 470 : reference Ok False, classe domain, 0 unite(s) ; mesure complete : calibration False, demande False, suite [] ; borne haute densite 235 ; reglage de 300 a 470",
           'journal Mesure complète de cette disquette impossible : elle demande la référence du lecteur par tête (écriture lente). Écriture annulée.', 'retour double densite : 470')
Chk 'H1' ((Get-FirstDiff $hdExp $hdNew) -eq '') "haute densite (Get-LevelRef, Start-DiskMeasure, Set-CalibScale reelles) : aucune reference de calibration rapide, mesure complete de la disquette refusee, borne a la moitie du reglage (200 et 235 ns), reglage de 300 a 470 ns : valeurs de la 12.10 ; ecart : $(Get-FirstDiff $hdExp $hdNew)"
$cA = Get-Callers 'Get-DiskCapNs'; $cB = Get-Callers 'Get-UnitCapNs'; $cC = Get-Callers 'Get-DiskCellNs'; $cD = Get-Callers 'Get-LevelAdaptHard'; $cE = Get-Callers 'Get-LevelBrandCurveValues'
$refTxt = (Get-FnAst $f270 'Complete-PrecompCalib').Extent.Text
# Lot L12a (adapte a dessein) : Get-BoundAdviceNs lit aussi Get-UnitCapNs (conseil de relever la borne)
Chk 'H2' ($cA -eq '265:Get-DiskHardNs, 265:Get-UnitCapNs' -and $cB -eq '260:Get-LevelUnitResults, 265:Get-BoundAdviceNs, 265:Get-LevelAdaptHard' -and $cC -eq '265:Get-DiskBoundText, 265:Get-DiskCapNs' -and $cD -eq '265:Build-LevelAdaptValues, 265:Get-LevelAdaptOutcome' -and $cE -eq '265:Set-LevelBrandStart' -and $refTxt.Contains('MaxNs = [int]$script:CalHardNs')) "appelants des fonctions du plafond, tous modules : Get-DiskCapNs <- $cA ; Get-UnitCapNs <- $cB ; Get-DiskCellNs <- $cC : calibration rapide et mesure complete de la disquette seulement, que la haute densite n atteint pas ; la reference du lecteur enregistre toujours la borne CalHardNs"

# ---------------------------------------------------------------- I, L : textes
'--- I, L : textes'
$txt019 = [System.IO.File]::ReadAllText((Join-Path $mods '019-i18n-1211.ps1'))
$oldIn = @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Sort-Object Name | Where-Object { [System.IO.File]::ReadAllText($_.FullName).Contains($kOldBound) } | ForEach-Object { $_.Name })
# Lot L4b : la ligne de la 12.10, retiree par le lot L4, est retablie dans 010 avec sa traduction d origine ; seule
# Get-DiskBoundText (265) l emploie, pour une borne sans cellule connue
Chk 'I1' ([string]$script:I18n[$kBound] -ceq $eBound -and [string]$script:I18n[$kAdv] -ceq $eAdv -and $txt019.Contains($kBound) -and $txt019.Contains($kAdv) -and [string]$script:I18n[$kOldBound] -ceq $eOldBound -and ($oldIn -join ', ') -ceq '010-i18n.ps1, 265-fn-calib-adaptative.ps1') "table I18n : les deux textes de la specification et leur anglais dans 019 ; ligne de la borne de la 12.10 retablie dans 010 avec son anglais d origine, employee par 265 seulement ($(Get-List $oldIn))"
$ch = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'))
$i11 = $ch.IndexOf('## [12.11]'); $i10 = $ch.IndexOf('## [12.10]')
$sec = ''; if ($i11 -ge 0 -and $i10 -gt $i11) { $sec = $ch.Substring($i11, $i10 - $i11) }
$iAm = $sec.IndexOf('### Améliorations'); $iCo = $sec.IndexOf('### Corrections'); $iSa = $sec.IndexOf('### À savoir pour la mise à jour'); $iDe = $sec.IndexOf('### Pour les développeurs')
$t1 = $sec.IndexOf("**Plafond d'une disquette selon son image.**"); $t2 = $sec.IndexOf('**Plafond au-delà de 470 ns non éprouvé sur matériel.**')
# Lot L4b : phrase du plafond garde a 470 ns quand la cellule ecrite n est pas connue, dans l entree des Améliorations ;
# Get-DiskBoundText citee pour les developpeurs
$t3 = $sec.IndexOf("format saisi à la main dans la liste « Format » et inconnu de l'application"); $t4 = $sec.IndexOf('`Get-DiskBoundText([int]$hard, [int]$bits, $pat)`')   # lot L12a : troisieme parametre, le motif
# Corrections de relecture : HFE v3 a 470 ns, piste la plus longue d un IPF ou d un HFE, cellule du codec AmigaDOS avec
# amiga.amigados (Améliorations) ; cellules du codec du format et champ CapBits (developpeurs) ; README : meme regle
$t5 = $sec.IndexOf('ni un ADF, ni un IPF, ni un HFE dont la longueur des pistes se lit dans le fichier (un HFE v3 garde 470 ns)'); $t6 = $sec.IndexOf('le plafond suit la piste la plus longue, donc la cellule la plus courte')
$t7 = $sec.IndexOf("il suit la cellule du codec AmigaDOS (493 ns), que l'image soit un ADF ou non"); $t8 = $sec.IndexOf('Pour un format de la table, elle ne rend jamais moins que les cellules du codec du format'); $t9 = $sec.IndexOf('`CapBits`')
$rdm = [System.IO.File]::ReadAllText((Join-Path $Wt 'README.md'))
$okRd = ($rdm.Contains('ni un ADF, ni un IPF, ni un HFE dont la longueur des pistes se lit dans le fichier ; pour un IPF ou un HFE, la piste la plus longue fait foi)'))
Chk 'L1' ($t1 -gt $iAm -and $t1 -lt $iCo -and $t2 -gt $iSa -and $t2 -lt $iDe -and $sec.Contains('entre 471 et 500 ns, la règle du quart de cellule repose sur une simulation du décodage') -and $sec.Contains('logic-calib-plafond-disquette') -and $t3 -gt $t1 -and $t3 -lt $iCo -and $t4 -gt $iDe -and
          $t5 -gt $t3 -and $t6 -gt $t5 -and $t7 -gt $t6 -and $t7 -lt $iCo -and $t8 -gt $iDe -and $t9 -gt $iDe -and $okRd) "CHANGELOG, section 12.11 : entree « Plafond d'une disquette selon son image » dans les Améliorations, avec le plafond garde a 470 ns pour un format inconnu de l application et pour un HFE v3, la piste la plus longue d un IPF ou d un HFE et la cellule du codec AmigaDOS ; entree « Plafond au-delà de 470 ns non éprouvé sur matériel » dans À savoir ; test, Get-DiskBoundText, cellules du codec du format et champ CapBits cites pour les développeurs ; README : meme regle ($okRd)"

# ---------------------------------------------------------------- N : valeurs de la 12.10
'--- N : resultats de la source de la 12.10 (unites sans densite)'
# Par courbe sans densite « borne/besoin/derive » : par tete, plafond:maximum:somme:satures:au-dela, rendus par la source de
# la 12.10 (c8a3c72) pour les memes entrees ; rejoues par Q6 avec -Before
$sig1210 = @{
    '350/380/0' = '350:350:16480:7:0|350:350:17833:8:0';    '350/398/0' = '350:350:17750:12:0|350:350:18381:12:0'
    '350/398/6' = '350:350:18156:13:0|350:350:18381:12:0';  '350/440/0' = '350:350:20423:21:0|350:350:19457:20:0'
    '350/470/0' = '350:350:22086:28:0|350:350:20085:24:0';  '350/470/6' = '350:350:22394:29:0|350:350:20085:24:0'
    '350/480/0' = '350:350:22594:30:0|350:350:20276:25:0';  '350/520/0' = '350:350:24400:39:0|350:350:20950:30:0'
    '400/380/0' = '400:380:16600:0:0|400:380:17961:0:0';    '400/398/0' = '400:398:18040:0:0|400:398:18681:0:0'
    '400/398/6' = '470:404:18520:0:1|400:398:18681:0:0';    '400/440/0' = '470:440:21400:0:10|470:440:20361:0:9'
    '400/470/0' = '470:470:23800:0:16|470:470:21561:0:14';  '400/470/6' = '470:470:24272:2:18|470:470:21561:0:14'
    '400/480/0' = '470:470:24583:3:19|470:470:21946:2:16';  '400/520/0' = '470:470:27486:12:28|470:470:23319:9:21'
    '430/380/0' = '430:380:16600:0:0|430:380:17961:0:0';    '430/398/0' = '430:398:18040:0:0|430:398:18681:0:0'
    '430/398/6' = '430:404:18520:0:0|430:398:18681:0:0';    '430/440/0' = '470:440:21400:0:3|470:440:20361:0:2'
    '430/470/0' = '470:470:23800:0:10|470:470:21561:0:8';   '430/470/6' = '470:470:24272:2:11|470:470:21561:0:8'
    '430/480/0' = '470:470:24583:3:12|470:470:21946:2:10';  '430/520/0' = '470:470:27486:12:21|470:470:23319:9:16'
    '470/380/0' = '470:380:16600:0:0|470:380:17961:0:0';    '470/398/0' = '470:398:18040:0:0|470:398:18681:0:0'
    '470/398/6' = '470:404:18520:0:0|470:398:18681:0:0';    '470/440/0' = '470:440:21400:0:0|470:440:20361:0:0'
    '470/470/0' = '470:470:23800:0:0|470:470:21561:0:0';    '470/470/6' = '470:470:24272:2:0|470:470:21561:0:0'
    '470/480/0' = '470:470:24583:3:0|470:470:21946:2:0';    '470/520/0' = '470:470:27486:12:0|470:470:23319:9:0'
}
$bad = @()
foreach ($k in @($gridNew.None.Keys | Sort-Object)) { $sg = Get-TSig $gridNew.None[$k]; if ([string]$sig1210[$k] -cne $sg) { $bad += "$k : $sg au lieu de $($sig1210[$k])" } }
Chk 'N1' ($bad.Count -eq 0 -and $gridNew.None.Count -eq 32 -and $sig1210.Count -eq 32) "$($gridNew.None.Count) calibrations factices sans densite : plafonds, plus fortes valeurs, sommes des courbes, cylindres satures et au-dela de la borne egaux a ceux de la source de la 12.10 ; ecarts : $(Get-List $bad)"

# ---------------------------------------------------------------- Q : equivalence avec la 12.10 (-Before)
'--- Q : equivalence avec la 12.10 (-Before)'
function Invoke-InVersion([string]$gen, [scriptblock]$body) {
    # Fonctions d une version chargees dans la portee de cette fonction : elles y masquent celles du script, pour le bloc
    # execute et pour tout ce qu il appelle
    . $gen
    & $body
}
if (-not $Before) {
    'Q0-Q7    saute : sans -Before <copie de la source de la 12.10>, l equivalence avec la 12.10 n est pas rejouee (N1 en garde les valeurs)'
} else {
    if (-not (Test-Path -LiteralPath (Join-Path $Before 'src\modules\265-fn-calib-adaptative.ps1'))) { throw "source d avant introuvable sous $Before" }
    $genOld = Join-Path $here 'gen-avant.ps1'
    $infoOld = New-Gen $Before $genOld $false
    $oldHas = @((Get-Cal2FnDefs (Join-Path $Before 'src\modules\265-fn-calib-adaptative.ps1')).Keys | Where-Object { $fnL4 -contains $_ })
    Chk 'Q0' ($oldHas.Count -eq 0 -and $infoOld.Defs['Get-DiskHardNs'].StartsWith('function Get-DiskHardNs {') -and $infoOld.Defs['New-LevelCalUnits'].StartsWith('function New-LevelCalUnits($lr, [string]$brand, [string]$drive) {')) "source d avant : aucune des fonctions du lot ($(Get-List $oldHas)), Get-DiskHardNs sans parametre, New-LevelCalUnits sans densite"
    # DiskF (lot L4b) : mesure complete d une image secteur de 100 000 cellules aux quatre bornes du cas F3 (la 12.10 ne lit
    # ni le format ni l origine de la densite)
    $old = Invoke-InVersion $genOld { @{ Grid = (Invoke-TGrid $true); Disk = @($m1 | ForEach-Object { Invoke-TDisk $_[0] $_[1] }); Hd = (Invoke-THd); DiskF = @(350, 400, 430, 470 | ForEach-Object { Invoke-TDisk 100000 $_ $false }) } }
    $script:Lang = 'fr'
    # Q1 : une unite sans densite de la 12.11 se comporte comme la 12.10, a la ligne de conseil pres ; la 12.10 ignore la densite
    $bad = @(); $nAdv0 = 0
    foreach ($k in @($gridNew.None.Keys | Sort-Object)) {
        $d = Get-FirstDiff (Get-RunLines $old.Grid.None[$k]) (Get-RunLines $gridNew.None[$k]); if ($d) { $bad += "$k : $d" }
        $nAdv0 += @($old.Grid.None[$k].Log | Where-Object { $_.IndexOf($advMark) -ge 0 }).Count
        foreach ($bits in $gBits) { $d = Get-FirstDiff (Get-RunLines $old.Grid.None[$k]) (Get-RunLines $old.Grid.Bits["$bits/$k"]); if ($d) { $bad += "12.10, $bits/$k : $d" } }
    }
    Chk 'Q1' ($bad.Count -eq 0 -and $nAdv0 -eq 0 -and $old.Grid.None.Count -eq 32) "$($old.Grid.None.Count) calibrations sans densite : la 12.11 rend les courbes, plafonds, profils, reserves et journal de la 12.10 au caractere pres, plus la ligne de conseil ; la 12.10 rend le meme resultat quelle que soit la densite ($($old.Grid.Bits.Count) calibrations) ; ecarts : $(Get-List $bad)"
    $bad = @(); $cq = @{ 'same' = 0; 'cap=' = 0; 'cap+' = 0; 'new' = 0 }; $badT = @(); $nT = 0
    foreach ($k in @($gridNew.Bits.Keys | Sort-Object)) {
        $r = $gridNew.Bits[$k]; $ro = $old.Grid.Bits[$k]; $capK = Get-DiskCapNs $r.Bits
        $c = Compare-TRuns $ro $r $capK
        foreach ($x in $c.Kinds) { $cq[$x]++ }
        if ($c.Bad) { $bad += "$k : $($c.Bad)" }
        # Lot L12a (adapte a dessein) : conseil « jusqu a N ns » ramene a 470 ns pour une image de plafond plus bas (Get-TAdvNorm, E2)
        if (@($c.Kinds | Where-Object { $_ -ne 'same' -and $_ -ne 'cap=' }).Count -eq 0) { $nT++; $d = Get-FirstDiff (Get-TNormText $ro 470) (Get-TAdvNorm (Get-TNormText $r $capK) $r.Bits); if ($d) { $badT += "$k : $d" } }
    }
    Chk 'Q2' ($bad.Count -eq 0 -and $badT.Count -eq 0 -and $cq['same'] -eq $cnt['same'] -and $cq['cap='] -eq $cnt['cap='] -and $cq['cap+'] -eq $cnt['cap+'] -and $cq['new'] -eq $cnt['new']) "$($gridNew.Bits.Count) calibrations avec densite, 12.10 reelle contre 12.11 : memes classes qu en E1 ($($cq['same']), $($cq['cap=']), $($cq['cap+']), $($cq['new'])) ; $nT calibrations aux memes courbes : reserves et journal identiques au plafond annonce et a la ligne de conseil pres ; ecarts : $(Get-List (@($bad) + @($badT)))"
    $bad = @()
    for ($i = 0; $i -lt $m1.Count; $i++) {
        $x = $m1[$i]; $oo = $old.Disk[$i]; $on = $dk["$($x[0])/$($x[1])"]
        $exp10 = $x[1]; if ($x[1] -ge 400) { $exp10 = 470 }
        if ($oo.HardNs -ne $exp10 -or $oo.During -ne $exp10 -or $oo.Reset -ne $x[1]) { $bad += "12.10, $($x[0])/$($x[1]) : $(Get-List (Get-DiskLines $oo) 1)" }
        if ($x[1] -lt 400 -or $x[2] -eq $exp10) {
            # meme borne : meme journal, sauf la ligne de la borne quand elle depasse le seuil (texte nouveau)
            if ($on.HardNs -ne $oo.HardNs) { $bad += "$($x[0])/$($x[1]) : bornes $($oo.HardNs) et $($on.HardNs)" }
            elseif ($oo.HardNs -le [math]::Max(400, $x[1]) -and (Get-FirstDiff (Get-DiskLines $oo) (Get-DiskLines $on))) { $bad += "$($x[0])/$($x[1]) : $(Get-FirstDiff (Get-DiskLines $oo) (Get-DiskLines $on))" }
        }
    }
    $oldLine = [string]$old.Disk[1].Log[0]
    Chk 'Q3' ($bad.Count -eq 0 -and $oldLine -ceq 'Borne de la courbe de cette disquette : 470 ns ; au-delà de 400 ns, contrôle après écriture imposé.') "mesure complete de la disquette : la 12.10 posait 470 ns pour toute image des que la borne valait 400 ns ou plus (« $oldLine ») ; borne sous 400 ns, ou borne reglee a 470 ns sur un long track de 110 000 cellules : meme borne et meme journal dans les deux versions ; ecarts : $(Get-List $bad)"
    Chk 'Q4' ((Get-FirstDiff $old.Hd $hdNew) -eq '') "haute densite : memes resultats et meme journal dans les deux versions ; ecart : $(Get-FirstDiff $old.Hd $hdNew)"
    $sameFn = @('Set-CalibScale', 'Get-CurveMaxNs', 'ConvertTo-LevelBrandConfig', 'ConvertFrom-LevelBrandConfig', 'Build-LevelValues', 'Build-LevelAdaptValues', 'Test-LevelAdaptedSpec', 'Get-DiskOverNs', 'Test-LevelBrandCurve', 'Set-DiskHardNs', 'Reset-DiskHardNs')
    $diffFn = @('Get-LevelAdaptHard', 'Get-LevelAdaptOutcome', 'Set-LevelBrandStart', 'Get-DiskHardNs', 'Get-LevelBrandCurveValues', 'New-LevelCalUnits', 'Get-LevelUnitResults', 'Start-DiskMeasure')
    $bad = @($sameFn | Where-Object { (Get-CodeText $infoOld.Defs[$_]) -cne (Get-CodeText $infoNew.Defs[$_]) })
    $bad2 = @($diffFn | Where-Object { (Get-CodeText $infoOld.Defs[$_]) -ceq (Get-CodeText $infoNew.Defs[$_]) })
    $stSame = ((Get-CodeText $infoOld.Stmts.Force) -ceq (Get-CodeText $infoNew.Stmts.Force))
    Chk 'Q5' ($bad.Count -eq 0 -and $bad2.Count -eq 0 -and $stSame) "code hors commentaires : $($sameFn.Count) fonctions de decision inchangees (bareme, seuil et controle impose, courbes, lecture des marques ; modifiees : $(Get-List $bad)) ; $($diffFn.Count) fonctions modifiees par le lot (inchangees : $(Get-List $bad2)) ; instruction du controle impose de Complete-DiskMeasure inchangee ($stSame)"
    $bad = @()
    foreach ($k in @($old.Grid.None.Keys | Sort-Object)) { $sg = Get-TSig $old.Grid.None[$k]; if ([string]$sig1210[$k] -cne $sg) { $bad += "$k"; "         12.10 : '$k' = '$sg'" } }
    Chk 'Q6' ($bad.Count -eq 0) "valeurs de N1 : celles que rend la source d avant pour les $($old.Grid.None.Count) calibrations sans densite ; ecarts : $(Get-List $bad 8)"
    # Q7 (lot L4b) : format absent de la table : borne et journal de la mesure complete (cas F3) egaux a ceux de la 12.10
    $bad = @(); $ix7 = 0
    foreach ($b in 350, 400, 430, 470) {
        $oo = $old.DiskF[$ix7]; $on = $oU[$b]; $ix7++
        if (-not $on -or $oo.HardNs -ne $on.HardNs -or $oo.During -ne $on.During -or $oo.Reset -ne $on.Reset) { $bad += "borne $b : $($oo.HardNs) en 12.10" ; continue }
        $d = Get-FirstDiff (Get-DiskLines $oo) (Get-DiskLines $on); if ($d) { $bad += "borne $b : $d" }
    }
    Chk 'Q7' ($bad.Count -eq 0 -and @($old.DiskF).Count -eq 4 -and [string]$old.DiskF[1].Log[0] -ceq $lU400) "format absent de la table, mesure complete de la disquette aux bornes de 350, 400, 430 et 470 ns : meme borne et meme journal que la 12.10, au caractere pres (« $(Get-Short ([string]$old.DiskF[1].Log[0]) 100) ») ; ecarts : $(Get-List $bad)"
}

"=== bilan logic-calib-plafond-disquette : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$(if ($script:Fail) { ' ; non conformes : ' + (@($script:FailIds) -join ', ') }) ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
