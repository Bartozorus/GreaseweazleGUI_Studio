param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 (lot SB, trouve par le banc GUI complet du 13/11/2026) : barre d etat de hauteur constante. Depuis le lot L8, la
# barre de progression de la barre d etat ($stBar, 540) est masquee au repos ; avec ses marges, elle depasse les libelles
# d un pixel : le StatusStrip perdait un pixel au repos, et toute la zone des onglets sautait d un pixel au debut et a la
# fin de chaque operation (banc : onglet 775x284 au repos, 775x283 pendant une operation). 540 donne au StatusStrip une
# hauteur minimale, sa hauteur preferee mesuree a la construction, barre encore visible.
#  C  construction : instructions reelles de 540 (barre d etat, pictogrammes), mesure juste apres l ajout des trois
#     elements, barre masquee juste apres la mesure, aucune poignee creee ;
#  H  hauteur preferee : minimum egal a la hauteur barre visible sans ce minimum (celle d une operation en 12.10 et depuis
#     le lot L8) ; hauteur identique barre visible et barre masquee dans chaque etat de la barre d etat, en francais et en
#     anglais ; temoin : sans le minimum, la barre masquee raccourcit le StatusStrip ;
#  F  fenetre jamais affichee (taille et police reelles de 500) : zone des onglets de meme hauteur au repos et pendant une
#     operation, egale a celle d une operation sans le minimum ; temoin : sans le minimum, elle grandit au repos ;
#  B  arbre syntaxique de tous les modules : aucune propriete de la barre d etat ni de ses elements qui joue sur la
#     hauteur n est posee apres la mesure ; pictogrammes de la barre d etat tous tires de $script:StIcons ;
#  D  CHANGELOG et README.
# Le theme n a qu une taille de police (500 : Segoe UI 9,75 pour la fenetre et la barre d etat) : un seul jeu de mesures.
# Controles WinForms reels jamais affiches ; New-GlyphBitmap reelle (100), sans police d icones (pastille de 16 px, la
# taille des pictogrammes reels). Aucun gw, aucune fenetre affichee, aucune compilation.
# Non couvert : la fenetre affichee (banc GUI), un poste a une autre echelle d affichage, la mise en page refaite par
# Windows apres l affichage.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Import-TestWinForms
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$m = Join-Path $Wt 'src\modules'
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '01*-i18n*.ps1' -File | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'

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
$tFn = [System.Management.Automation.Language.FunctionDefinitionAst]
$tAsg = [System.Management.Automation.Language.AssignmentStatementAst]
$tMem = [System.Management.Automation.Language.MemberExpressionAst]
$tVar = [System.Management.Automation.Language.VariableExpressionAst]

# --- Instructions reelles ------------------------------------------------------------------------------------------
$a100 = Get-Ast (Join-Path $m '100-fn-interface.ps1')
$a500 = Get-Ast (Join-Path $m '500-fenetre-theme.ps1')
$a540 = Get-Ast (Join-Path $m '540-ui-accueil-restauration-barre.ps1')
$fnGlyph = @($a100.FindAll({ param($x) $x -is $tFn -and $x.Name -eq 'New-GlyphBitmap' }, $false))
if ($fnGlyph.Count -ne 1) { throw "New-GlyphBitmap dans 100 : $($fnGlyph.Count)" }
function Get-TopStmt($ast, [string]$rx) {
    # Rangs des instructions de premier niveau d un module dont le texte correspond
    $r = New-Object System.Collections.Generic.List[int]
    $s = @($ast.EndBlock.Statements)
    for ($i = 0; $i -lt $s.Count; $i++) { if ([string]$s[$i].Extent.Text -match $rx) { $r.Add($i) } }
    return @($r)
}
$s500 = @($a500.EndBlock.Statements); $s540 = @($a540.EndBlock.Statements)
$i5Theme = @(Get-TopStmt $a500 '^\$script:Theme = @\{'); $i5Size = @(Get-TopStmt $a500 '^\$form\.ClientSize = '); $i5Font = @(Get-TopStmt $a500 '^\$form\.Font = ')
if ($i5Theme.Count -ne 1 -or $i5Size.Count -ne 1 -or $i5Font.Count -ne 1) { throw "theme, taille ou police de la fenetre dans 500 : $($i5Theme.Count), $($i5Size.Count), $($i5Font.Count)" }
$iNew = @(Get-TopStmt $a540 '^\$status = New-Object System\.Windows\.Forms\.StatusStrip$')
$iAdd = @(Get-TopStmt $a540 '^\[void\]\$status\.Items\.AddRange\(@\(\$stOp, \$stTrack, \$stBar\)\)$')
$iMin = @(Get-TopStmt $a540 '^\$status\.MinimumSize = ')
$iHide = @(Get-TopStmt $a540 '^\$stBar\.Visible = \$false$')
$iIcons = @(Get-TopStmt $a540 '^\$script:StIcons = @\{')
$iImg = @(Get-TopStmt $a540 '^\$stOp\.Image = \$script:StIcons\.idle$')
$found = "creation $($iNew.Count), ajout $($iAdd.Count), mesure $($iMin.Count), masquage $($iHide.Count), pictogrammes $($iIcons.Count), pictogramme du repos $($iImg.Count)"
if ($iNew.Count -ne 1 -or $iAdd.Count -ne 1 -or $iMin.Count -ne 1 -or $iHide.Count -ne 1 -or $iIcons.Count -ne 1 -or $iImg.Count -ne 1) { throw "instructions de la barre d etat dans 540 : $found" }
$iNew = $iNew[0]; $iAdd = $iAdd[0]; $iMin = $iMin[0]; $iHide = $iHide[0]; $iIcons = $iIcons[0]; $iImg = $iImg[0]
$order = ($iNew -lt $iAdd -and $iMin -eq $iAdd + 1 -and $iHide -eq $iMin + 1 -and $iIcons -gt $iHide -and $iImg -gt $iIcons)
function Get-StatusBody([bool]$withMin) {
    # Instructions reelles de la creation de la barre d etat au masquage de la barre, puis pictogrammes ; sans la mesure
    # pour $withMin faux (construction du lot L8 et, barre visible, hauteur d une operation en 12.10)
    $b = New-Object System.Collections.Generic.List[string]
    for ($i = $iNew; $i -le $iHide; $i++) { if ($withMin -or $i -ne $iMin) { $b.Add([string]$s540[$i].Extent.Text) } }
    $b.Add([string]$s540[$iIcons].Extent.Text); $b.Add([string]$s540[$iImg].Extent.Text)
    $b.Add('return @{ Status = $status; Op = $stOp; Track = $stTrack; Bar = $stBar }')
    return ($b -join "`r`n")
}
$parts = New-Object System.Collections.Generic.List[string]
$parts.Add([string]$fnGlyph[0].Extent.Text)
$parts.Add([string]$s500[$i5Theme[0]].Extent.Text)
$parts.Add("function New-Status540 {`r`n" + (Get-StatusBody $true) + "`r`n}")
$parts.Add("function New-Status540SansMin {`r`n" + (Get-StatusBody $false) + "`r`n}")
$parts.Add("function New-Form500 {`r`n`$form = New-Object System.Windows.Forms.Form`r`n" + [string]$s500[$i5Size[0]].Extent.Text + "`r`n" + [string]$s500[$i5Font[0]].Extent.Text + "`r`nreturn `$form`r`n}")
$gen = Join-Path $here 'gen-barre-etat-hauteur.ps1'
[System.IO.File]::WriteAllText($gen, (($parts -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
# Bouchons de New-GlyphBitmap : aucune police d icones, donc la pastille de repli, a la taille demandee (16 px)
$script:IconFont = $null; $script:Glyph = @{}
. $gen

function New-Layout([bool]$withMin) {
    # Fenetre de 500 (taille et police reelles), barre d etat de 540 et un panneau ancre au reste de la fenetre, comme le
    # separateur des onglets et du journal ($split, 540) ; mise en page demandee a chaque changement, comme a l ecran.
    # Toujours dans une fenetre : une barre d etat sans parent ne retrouve pas la hauteur de sa barre de progression
    # masquee puis montree (constat sous PowerShell 7), ce que l application ne fait jamais
    $f = New-Form500
    $s = if ($withMin) { New-Status540 } else { New-Status540SansMin }
    $p = New-Object System.Windows.Forms.Panel; $p.Dock = 'Fill'
    $f.Controls.Add($s.Status); $f.Controls.Add($p); $p.BringToFront()
    $f.PerformLayout()
    return @{ Form = $f; S = $s; Fill = $p }
}
function Get-BarH($l, [bool]$visible) {
    # Hauteur preferee de la barre d etat, barre de progression visible ou masquee
    $l.S.Bar.Visible = $visible; $l.Form.PerformLayout()
    return [int]$l.S.Status.GetPreferredSize([System.Drawing.Size]::Empty).Height
}

# ================================================================ C. construction
'--- C. construction (instructions reelles de 540)'
$r = New-Status540
$min = $r.Status.MinimumSize
Chk 'C1' ($order -and -not $r.Bar.Available -and $r.Bar.Size.Width -eq 280 -and $r.Bar.Size.Height -eq 18 -and $min.Width -eq 0 -and $min.Height -gt 0 -and -not $r.Status.IsHandleCreated -and $r.Status.AutoSize -and $r.Op.Text -ceq 'Prêt.') "mesure juste apres l ajout des trois elements, barre masquee juste apres ($found) ; barre de 280x18 masquee a la fin de la construction ; minimum 0x$($min.Height) ; aucune poignee creee ; taille automatique gardee ; « Prêt. »"

# ================================================================ H. hauteur preferee
'--- H. hauteur preferee, barre visible et barre masquee'
$lref = New-Layout $false
$hRefIdle = Get-BarH $lref $false; $hRefOp = Get-BarH $lref $true
$lmin = New-Layout $true
Chk 'H1' ($min.Height -eq $hRefOp -and $lmin.S.Status.MinimumSize.Height -eq $hRefOp -and (Get-BarH $lmin $true) -eq $hRefOp) "hauteur minimale $($min.Height) px = hauteur barre visible sans le minimum ($hRefOp px), celle d une operation en 12.10 et depuis le lot L8"
Chk 'H2' ($hRefIdle -lt $hRefOp) "temoin : sans le minimum, la barre masquee raccourcit la barre d etat ($hRefIdle px au repos, $hRefOp px pendant une operation)"
$lref.Form.Dispose(); $lmin.Form.Dispose()
# Etats de la barre d etat : repos, commande sans annonce (barre animee), compteur de pistes, fin d une commande, echec,
# fin de sequence ; textes et pictogrammes reels
$states = 0; $bad = New-Object System.Collections.Generic.List[string]
foreach ($lang in 'fr', 'en') {
    $script:Lang = $lang
    $lq = New-Layout $true; $q = $lq.S
    $ic = $script:StIcons
    $set = @(
        @{ N = 'repos'; Op = (T 'Prêt.'); Img = $ic.idle; Track = ''; Style = 'Continuous' },
        @{ N = 'commande'; Op = ((T "{0} en cours...") -f (T 'Lecture')); Img = $ic.run; Track = ''; Style = 'Marquee' },
        @{ N = 'compteur'; Op = ((T "{0} en cours...") -f (T 'Écriture')); Img = $ic.run; Track = 'piste 12.0  (24/160, 15 %)'; Style = 'Continuous' },
        @{ N = 'fin'; Op = ((T "{0} terminé(e)  -  {1}") -f (T 'Lecture'), '12:00:00'); Img = $ic.ok; Track = 'piste 79.1  (160/160, 100 %)'; Style = 'Continuous' },
        @{ N = 'echec'; Op = ((T "{0} en échec (code {1})  -  {2}") -f (T 'Lecture'), '1', '12:00:00'); Img = $ic.err; Track = 'piste 9.1  (19/164, 11 %)'; Style = 'Continuous' },
        @{ N = 'fin de sequence'; Op = ((T 'Restauration échouée') + '  -  12:00:00'); Img = $ic.err; Track = ''; Style = 'Continuous' })
    foreach ($e in $set) {
        $q.Op.Text = [string]$e.Op; $q.Op.Image = $e.Img; $q.Track.Text = [string]$e.Track; $q.Bar.Style = [string]$e.Style
        $hv = Get-BarH $lq $true; $hh = Get-BarH $lq $false
        $states++
        if ($hv -ne $min.Height -or $hh -ne $min.Height) { $bad.Add("$lang/$($e.N) : $hv/$hh") }
    }
    $lq.Form.Dispose()
}
$script:Lang = 'fr'
Chk 'H3' ($bad.Count -eq 0 -and $states -eq 12) "hauteur preferee identique barre visible et barre masquee, egale au minimum ($($min.Height) px), dans $states etats (repos, commande, compteur, fin, echec, fin de sequence ; francais et anglais)$(if ($bad.Count) { ' ; ecarts : ' + ($bad -join ', ') })"

# ================================================================ F. fenetre jamais affichee
'--- F. zone des onglets dans une fenetre jamais affichee'
function Get-Zone($l, [bool]$visible) { $l.S.Bar.Visible = $visible; $l.Form.PerformLayout(); return "$($l.Fill.Width)x$($l.Fill.Height)|$($l.S.Status.Height)" }
$lw = New-Layout $true
$seq = @(); foreach ($v in $false, $true, $false, $true, $false) { $seq += (Get-Zone $lw $v) }
$lr = New-Layout $false
$zRefOp = Get-Zone $lr $true; $zRefIdle = Get-Zone $lr $false
$distinct = @($seq | Select-Object -Unique)
Chk 'F1' ($distinct.Count -eq 1 -and $distinct[0] -eq $zRefOp -and -not $lw.Form.IsHandleCreated -and -not $lw.Form.Visible) "zone des onglets et barre d etat ($($distinct -join ' / ')) identiques au repos et pendant deux operations, egales a celles d une operation sans le minimum ($zRefOp) ; fenetre jamais affichee, sans poignee"
$hOp = [int]$zRefOp.Split('|')[0].Split('x')[1]; $hIdle = [int]$zRefIdle.Split('|')[0].Split('x')[1]
Chk 'F2' ($hIdle -gt $hOp) "temoin du banc : sans le minimum, la zone des onglets grandit au repos ($zRefIdle au repos, $zRefOp pendant une operation)"
$lw.Form.Dispose(); $lr.Form.Dispose()

# ================================================================ B. arbre syntaxique
'--- B. aucune geometrie posee apres la mesure'
# Proprietes posees pendant le fonctionnement (110, 300, 540), sans effet sur la hauteur : texte, pictogramme, visibilite
# de la barre et sa valeur. Toute autre propriete de $status, $stOp, $stTrack ou $stBar ne se pose qu a la construction
# (540, avant la mesure)
$runtime = @('Text', 'Image', 'Visible', 'Style', 'Value', 'Minimum', 'Maximum')
function Test-InFunction($node) {
    $p = $node.Parent
    while ($p) { if ($p -is $tFn) { return $true }; $p = $p.Parent }
    return $false
}
$late = New-Object System.Collections.Generic.List[string]; $nAsg = 0; $imgBad = New-Object System.Collections.Generic.List[string]
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '*.ps1' -File | Sort-Object Name)) {
    $ast = Get-Ast $f.FullName
    $top = @($ast.EndBlock.Statements)
    foreach ($as in @($ast.FindAll({ param($x) $x -is $tAsg -and $x.Left -is $tMem -and $x.Left.Expression -is $tVar -and @('status', 'stOp', 'stTrack', 'stBar') -contains $x.Left.Expression.VariablePath.UserPath }, $true))) {
        $nAsg++
        $prop = [string]$as.Left.Member.Extent.Text
        if ($as.Left.Expression.VariablePath.UserPath -eq 'stOp' -and $prop -eq 'Image' -and [string]$as.Right.Extent.Text -notmatch '\$script:StIcons') { $imgBad.Add("$($f.Name):$($as.Extent.StartLineNumber)") }
        if ($runtime -contains $prop -and $as.Left.Expression.VariablePath.UserPath -ne 'status') { continue }
        $rank = -1; for ($i = 0; $i -lt $top.Count; $i++) { if ([object]::ReferenceEquals($top[$i], $as) -or ($top[$i].Extent.StartOffset -le $as.Extent.StartOffset -and $top[$i].Extent.EndOffset -ge $as.Extent.EndOffset)) { $rank = $i; break } }
        if ($f.Name -ne '540-ui-accueil-restauration-barre.ps1' -or (Test-InFunction $as) -or $rank -lt $iNew -or $rank -gt $iMin) { $late.Add("$($f.Name):$($as.Extent.StartLineNumber) $($as.Left.Extent.Text)") }
    }
}
Chk 'B1' ($late.Count -eq 0 -and $nAsg -gt 0) "$nAsg affectations de proprietes de la barre d etat et de ses elements dans les modules : hors texte, pictogramme, visibilite et valeur de la barre, toutes dans 540 avant la mesure$(if ($late.Count) { ' ; posees ailleurs ou apres : ' + ($late -join ', ') })"
Chk 'B2' ($imgBad.Count -eq 0) "pictogrammes de la barre d etat tous tires de `$script:StIcons (pastilles de 16 px mesurees en H3)$(if ($imgBad.Count) { ' ; autres : ' + ($imgBad -join ', ') })"

# ================================================================ D. documents
'--- D. CHANGELOG et README'
function Read-Doc([string]$rel) { return [System.IO.File]::ReadAllText((Join-Path $Wt $rel), [System.Text.Encoding]::UTF8) }
$cl = Read-Doc 'CHANGELOG.md'
$i11 = $cl.IndexOf('## [12.11]'); $i10 = $cl.IndexOf('## [12.10]')
$sec = if ($i11 -ge 0 -and $i10 -gt $i11) { $cl.Substring($i11, $i10 - $i11) } else { '' }
function Get-Rub([string]$title) {
    $a = $sec.IndexOf("### $title"); if ($a -lt 0) { return '' }
    $b = $sec.IndexOf("`n### ", $a + 4); if ($b -lt 0) { $b = $sec.Length }
    return $sec.Substring($a, $b - $a)
}
$co = @((Get-Rub 'Corrections') -split "`n" | Where-Object { $_.Contains('ne bouge plus d''un pixel au début et à la fin d''une opération') })
$dv = @((Get-Rub 'Pour les développeurs') -split "`n" | Where-Object { $_.StartsWith('- Barre d''état de hauteur constante') })
Chk 'D1' ($co.Count -eq 1 -and $co[0] -notmatch 'matériel' -and $co[0] -notmatch 'MinimumSize') "CHANGELOG 12.11, « Corrections » : l onglet ne bouge plus d un pixel au debut et a la fin d une operation, sans detail interne ni mention du materiel"
$nTests = @(Get-ChildItem -LiteralPath (Join-Path $Wt 'tests') -Filter 'logic-*.ps1' -File).Count
$nWords = @{ 33 = 'trente-trois'; 34 = 'trente-quatre'; 35 = 'trente-cinq' }
$cnt = if ($nWords.ContainsKey($nTests)) { [string]$nWords[$nTests] + ' tests logiques' } else { "$nTests tests logiques" }
Chk 'D2' ($dv.Count -eq 1 -and $dv[0].Contains('`$status.MinimumSize`') -and $dv[0].Contains('`tests/logic-barre-etat-hauteur.ps1`') -and $sec.Contains($cnt)) "CHANGELOG 12.11, « Pour les développeurs » : hauteur minimale et test nouveau ; compte des tests logiques ($cnt)"
$rm = Read-Doc 'src\modules\README.md'; $rt = Read-Doc 'tests\README.md'
Chk 'D3' ($rm.Contains('`$status.MinimumSize`') -and $rt.Contains('| `logic-barre-etat-hauteur` |')) "README des modules : hauteur minimale de la barre d etat (540) ; README des tests : ligne de logic-barre-etat-hauteur"

$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + ($script:FailIds -join ', ') } else { '' }
"=== bilan logic-barre-etat-hauteur : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
exit $(if ($script:Fail) { 1 } else { 0 })
