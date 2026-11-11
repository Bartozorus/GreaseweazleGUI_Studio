param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : onglet « Ecriture » et textes de la 12.11. Test cree par le lot L1 (reperes des champs vides, entrees anglaises) ;
# les lots de l onglet le completent (disposition, options avancees, barre d onglets).
#  C  reperes des champs vides (texte gris d un champ vide : Set-Cue, 100). Appels Set-Cue et largeurs des champs lus dans
#     les modules par l arbre syntaxique ; chaque repere est mesure dans la police de la fenetre (500), en francais et en
#     anglais (vraie fonction T, 010). Regle etalonnee sur une capture de la 12.10 : un repere est entier si sa largeur
#     mesuree ne depasse pas celle du champ (largeur du code, la plus etroite : un champ ancre a droite s elargit).
#     C1 reperes raccourcis par la 12.11 (racine de la Bibliotheque, dossier de la restauration) : entiers ;
#     C2 tous les reperes : seuls restent coupes ceux des champs « Fake index » et « Diskdefs » de l onglet Ecriture, que
#        le lot L9 elargit. Ce cas attend exactement ces deux la : il devient non conforme des qu ils tiennent, et se
#        resserre alors en « aucun repere coupe » ;
#     C3 repere du dossier de la restauration : fin du dossier par defaut que rend la vraie Get-RestoreDefaultDir (300),
#        dans les deux langues ;
#     C4 instructions reelles de 540 pour ces deux champs (Set-Cue, infobulle), executees sur de vrais champs jamais
#        affiches avec la vraie Set-Cue (100) : repere enregistre egal au texte de la specification, en francais et en
#        anglais ; une infobulle pour chaque champ ; celle de la racine de la Bibliotheque, traduite et plus longue que
#        le repere, garde l ancien texte complet ;
#  I  table I18n (modules 010 a 019), chargee comme par l application :
#     I1 les huit textes de la 12.10 sans entree anglaise ont la leur dans 019, identique, et servent bien de cle a un
#        appel de T ;
#     I2 aucune cle litterale d un appel de T des modules sans entree dans la table ;
#     I3 019 : aucune cle deja definie par un module precedent (sa traduction changerait partout ou elle sert) ni definie
#        deux fois, memes {n} dans la cle et dans le texte anglais, aucun texte vide.
# Fonctions et instructions reelles extraites par l arbre syntaxique, ecrites dans des fichiers de travail puis chargees
# par dot-source ; controles WinForms reels (champs, infobulle) jamais affiches. Aucun gw, aucune fenetre, aucune
# compilation. Non couvert : le rendu reel du repere dans la fenetre (marges du champ, EM_SETCUEBANNER).
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
function Get-TKey($ast) {
    # Cle litterale d un unique appel « T '...' » contenu dans $ast ; $null sinon
    $tc = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'T' }, $true))
    if ($tc.Count -ne 1 -or $tc[0].CommandElements.Count -ne 2) { return $null }
    $k = $tc[0].CommandElements[1]
    if ($k -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { return $null }
    return [string]$k.Value
}
function Get-Ph([string]$s) {
    # Numeros des {n} d un texte, tries et sans double : « 0,1 »
    return (@([regex]::Matches($s, '\{(\d+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ',')
}

$mods = Join-Path $Wt 'src\modules'
$files = @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Sort-Object Name)
$asts = @{}
foreach ($f in $files) { $asts[$f.Name] = Get-Ast $f.FullName }

# --- Table I18n : chargee comme par l application (modules 01x dans l ordre de leur numero), puis lue module par module
$i18nFiles = @($files | Where-Object { $_.Name -match '^01\d-i18n' })
foreach ($f in $i18nFiles) { . $f.FullName }
$script:Lang = 'fr'
# Cles comparees a l octet pres, comme dans la table de l application (deux cles peuvent ne differer que par la casse)
$defs = [System.Collections.Hashtable]::new([System.StringComparer]::Ordinal)   # cle -> modules qui la definissent
$in019 = New-Object System.Collections.Generic.List[string]
$set019 = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
foreach ($f in $i18nFiles) {
    foreach ($a in $asts[$f.Name].FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.IndexExpressionAst] -and $n.Left.Target -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.Left.Target.VariablePath.UserPath -eq 'script:I18n' }, $true)) {
        if ($a.Left.Index -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { continue }
        $k = [string]$a.Left.Index.Value
        if (-not $defs.ContainsKey($k)) { $defs[$k] = @() }
        $defs[$k] += $f.Name.Substring(0, 3)
        if ($f.Name -like '019-*') { $in019.Add($k); [void]$set019.Add($k) }
    }
}
function Get-En([string]$key) {
    # Texte anglais rendu par la vraie fonction T
    $script:Lang = 'en'
    try { return [string](T $key) } finally { $script:Lang = 'fr' }
}

# --- Appels de T a cle litterale, appels Set-Cue, largeurs des champs : lus dans tous les modules
$tKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
$miss = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
$cues = @(); $odd = @(); $widths = @{}
foreach ($f in $files) {
    $ast = $asts[$f.Name]
    foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        $name = $c.GetCommandName()
        if ($name -eq 'T') {
            if ($c.CommandElements.Count -lt 2) { continue }
            $k = $c.CommandElements[1]
            if ($k -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { continue }
            [void]$tKeys.Add([string]$k.Value)
            if (-not $script:I18n.ContainsKey([string]$k.Value)) { [void]$miss.Add([string]$k.Value) }
        } elseif ($name -eq 'Set-Cue') {
            $e = $c.CommandElements
            $key = $null
            if ($e.Count -eq 3 -and $e[1] -is [System.Management.Automation.Language.VariableExpressionAst]) { $key = Get-TKey $e[2] }
            if ($null -eq $key) { $odd += "$($f.Name):$($c.Extent.StartLineNumber)"; continue }
            $cues += @{ Var = [string]$e[1].VariablePath.UserPath; Key = $key; Where = "$($f.Name.Substring(0, 3)):$($c.Extent.StartLineNumber)" }
        }
    }
    foreach ($a in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.MemberExpressionAst] -and $n.Left -isnot [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Left.Expression -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.Left.Member.Extent.Text -eq 'Width' }, $true)) {
        $txt = $a.Right.Extent.Text.Trim()
        if ($txt -notmatch '^\d+$') { continue }
        $v = [string]$a.Left.Expression.VariablePath.UserPath
        # Plusieurs largeurs pour un champ : la plus etroite
        if (-not $widths.ContainsKey($v) -or [int]$txt -lt $widths[$v]) { $widths[$v] = [int]$txt }
    }
}

# --- Mesure des reperes dans la police de la fenetre
$font = New-Object System.Drawing.Font('Segoe UI', 9.75)
$s500 = [System.IO.File]::ReadAllText((Join-Path $mods '500-fenetre-theme.ps1'))
$fontOk = ($s500.Contains("`$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)") -and $font.Name -eq 'Segoe UI')
$g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $dpi = [double]$g.DpiX; $g.Dispose()
function Get-TextW([string]$s) { return [int][System.Windows.Forms.TextRenderer]::MeasureText($s, $font).Width }
"logic-ecriture-onglet : $Wt ; $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion) ; police de la fenetre Segoe UI 9,75 : $fontOk ; $dpi ppp ; table I18n : $($script:I18n.Count) entrees, dont $($in019.Count) dans 019"

'--- C : reperes des champs vides'
$rows = @()
foreach ($c in $cues) {
    $w = -1; if ($widths.ContainsKey($c.Var)) { $w = [int][Math]::Floor($widths[$c.Var] * $dpi / 96.0) }
    $en = Get-En $c.Key
    $wFr = Get-TextW $c.Key; $wEn = Get-TextW $en
    $fit = ($w -gt 0 -and $wFr -le $w -and $wEn -le $w)
    $rows += @{ Var = $c.Var; Key = $c.Key; En = $en; W = $w; Fr = $wFr; EnW = $wEn; Fit = $fit; Where = $c.Where }
    $etat = 'entier'; if (-not $fit) { $etat = 'COUPE' }
    '  {0,-15} {1,-7} champ {2,4}  fr {3,4}  en {4,4}  {5,-6} {6}  ||  {7}' -f $c.Var, $c.Where, $w, $wFr, $wEn, $etat, $c.Key, $en
}
$short = @('txtLibRoot', 'txtRsDir')
$sRows = @($rows | Where-Object { $short -contains $_.Var })
$sBad = @($sRows | Where-Object { -not $_.Fit } | ForEach-Object { "$($_.Var) (champ $($_.W), fr $($_.Fr), en $($_.EnW))" })
Chk 'C1' ($fontOk -and $sRows.Count -eq 2 -and $sBad.Count -eq 0) "reperes raccourcis par la 12.11 entiers dans leur champ, en francais et en anglais : $(@($sRows | ForEach-Object { "$($_.Var) champ $($_.W), fr $($_.Fr), en $($_.EnW)" }) -join ' ; ') ; coupes : $(Get-List $sBad)"
$noW = @($rows | Where-Object { $_.W -le 0 } | ForEach-Object { $_.Var })
$cut = @($rows | Where-Object { -not $_.Fit } | ForEach-Object { $_.Var } | Sort-Object)
# Attendu jusqu au lot L9, qui elargit ces deux champs des options avancees de l onglet Ecriture ; a vider alors
$cutWant = @('txtWDiskdefs', 'txtWFakeIdx')
Chk 'C2' ($fontOk -and $rows.Count -ge 17 -and $odd.Count -eq 0 -and $noW.Count -eq 0 -and (($cut -join ',') -ceq ($cutWant -join ','))) "$($rows.Count) reperes lus (appels non lus : $(Get-List $odd) ; champs sans largeur lue : $(Get-List $noW)) ; coupes : $(Get-List $cut) ; attendus coupes jusqu au lot L9 : $($cutWant -join ', ')"

$fn = @($asts['300-fn-restauration.ps1'].FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-RestoreDefaultDir' }, $false))
if ($fn.Count -ne 1) { throw "Get-RestoreDefaultDir : $($fn.Count) definition(s) dans 300" }
$gen = Join-Path $here 'gen-ecriture-onglet.ps1'
[System.IO.File]::WriteAllText($gen, ($fn[0].Extent.Text + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
. $gen
$rsCue = @($rows | Where-Object { $_.Var -eq 'txtRsDir' })
$ell = [string][char]0x2026
if (-not [Environment]::GetFolderPath('MyDocuments')) { '  C3 saute (dossier Documents indisponible sur ce poste)' }
else {
    # Le dossier complet n est pas affiche (il nomme le compte du poste) : seule sa fin l est
    $bad3 = @(); $seen3 = @()
    foreach ($lg in 'fr', 'en') {
        $script:Lang = $lg
        $d = [string](Get-RestoreDefaultDir)
        $tail = $ell + '\' + (Split-Path -Leaf (Split-Path -Parent $d)) + '\' + (Split-Path -Leaf $d)
        $cueTxt = ''; if ($rsCue.Count -eq 1) { $cueTxt = [string](T $rsCue[0].Key) }
        $seen3 += "$lg « $cueTxt »"
        if ($cueTxt -cne $tail) { $bad3 += "$lg : attendu « $tail »" }
    }
    $script:Lang = 'fr'
    Chk 'C3' ($rsCue.Count -eq 1 -and $bad3.Count -eq 0) "repere du dossier de la restauration = fin du dossier par defaut de Get-RestoreDefaultDir : $($seen3 -join ' ; ') ; ecarts : $(Get-List $bad3)"
}
# C4 : instructions reelles de 540 pour les deux champs, executees sur de vrais champs jamais affiches ; vraie Set-Cue
# (100), qui n envoie aucun message a un champ sans poignee ($script:CueOk faux, comme avant l affichage de la fenetre)
$setCue = @($asts['100-fn-interface.ps1'].FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Set-Cue' }, $false))
if ($setCue.Count -ne 1) { throw "Set-Cue : $($setCue.Count) definition(s) dans 100" }
$st540 = @($asts['540-ui-accueil-restauration-barre.ps1'].EndBlock.Statements | Where-Object { $_.Extent.Text -match '^(Set-Cue\s+\$(txtLibRoot|txtRsDir)\s|\$tip\.SetToolTip\(\$(txtLibRoot|txtRsDir),)' } | ForEach-Object { $_.Extent.Text })
$genCue = Join-Path $here 'gen-ecriture-onglet-set-cue.ps1'
[System.IO.File]::WriteAllText($genCue, ($setCue[0].Extent.Text + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
. $genCue
$gen540 = Join-Path $here 'gen-ecriture-onglet-reperes.ps1'
[System.IO.File]::WriteAllText($gen540, (($st540 -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
# Textes de la specification, mot pour mot
$want4 = @{
    fr = @{ txtLibRoot = 'Dossier de vos images disque'; txtRsDir = ($ell + '\Greaseweazle Studio\Restaurations') }
    en = @{ txtLibRoot = 'Folder of your disk images'; txtRsDir = ($ell + '\Greaseweazle Studio\Restorations') }
}
$bad4 = @(); $tipLib = @{}
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    $script:CueOk = $false; $script:CueText = @{}
    $tip = New-Object System.Windows.Forms.ToolTip
    $txtLibRoot = New-Object System.Windows.Forms.TextBox; $txtRsDir = New-Object System.Windows.Forms.TextBox
    . $gen540
    foreach ($v in $short) {
        $tb = Get-Variable -Name $v -ValueOnly
        $cueTxt = [string]$script:CueText[$tb]
        if ($cueTxt -cne [string]$want4[$lg][$v]) { $bad4 += "$lg $v : repere « $cueTxt »" }
        $tt = [string]$tip.GetToolTip($tb)
        if (-not $tt) { $bad4 += "$lg $v : aucune infobulle" }
        if ($v -eq 'txtLibRoot') {
            $tipLib[$lg] = $tt
            if ($tt.Length -le $cueTxt.Length) { $bad4 += "$lg $v : infobulle pas plus longue que le repere" }
        }
    }
    $tip.Dispose(); $txtLibRoot.Dispose(); $txtRsDir.Dispose()
}
$script:Lang = 'fr'
Chk 'C4' ($st540.Count -eq 4 -and $bad4.Count -eq 0 -and [string]$tipLib['fr'] -cne [string]$tipLib['en']) "$($st540.Count) instructions reelles de 540 executees sur de vrais champs jamais affiches : reperes de la specification en francais et en anglais, une infobulle par champ, infobulle de la racine de la Bibliotheque traduite et plus longue que son repere ($(([string]$tipLib['fr']).Length) caracteres en francais) ; ecarts : $(Get-List $bad4)"

'--- I : table I18n'
$eight = @('SHA1 ref  : {0}', '   stable', 'Standard 2 us', 'LONG TRACK ({0})', 'standard 2 us ({0})', '{0} (x{1})', 'Extraction  : {0}', 'Index       : {0}')
$bad1 = @()
foreach ($k in $eight) {
    if (-not $set019.Contains($k)) { $bad1 += "« $k » absente de 019"; continue }
    if ([string]$script:I18n[$k] -cne $k -or (Get-En $k) -cne $k) { $bad1 += "« $k » : texte anglais different" }
    if (-not $tKeys.Contains($k)) { $bad1 += "« $k » : aucun appel de T avec cette cle" }
}
Chk 'I1' ($bad1.Count -eq 0) "les $($eight.Count) textes de la 12.10 sans entree anglaise ont la leur dans 019, identique, et servent de cle a un appel de T ; ecarts : $(Get-List $bad1)"
$missTxt = @($miss | Sort-Object | ForEach-Object { $k1 = ($_ -replace '\s+', ' '); if ($k1.Length -gt 60) { $k1 = $k1.Substring(0, 60) + '...' }; "« $k1 »" })
Chk 'I2' ($miss.Count -eq 0 -and $tKeys.Count -gt 1000) "$($tKeys.Count) cles litterales d appels de T dans les modules ; sans entree dans la table : $($miss.Count) : $(Get-List $missTxt)"
$bad3i = @()
foreach ($k in @($set019)) {
    $k1 = ($k -replace '\s+', ' '); if ($k1.Length -gt 60) { $k1 = $k1.Substring(0, 60) + '...' }
    $where = @($defs[$k])
    if ($where.Count -ne 1) { $bad3i += "« $k1 » definie dans $($where -join ', ')" }
    $en = [string]$script:I18n[$k]
    if (-not $en) { $bad3i += "« $k1 » : texte anglais vide" }
    elseif ((Get-Ph $k) -cne (Get-Ph $en)) { $bad3i += "« $k1 » : {n} differents ($(Get-Ph $k) / $(Get-Ph $en))" }
}
Chk 'I3' ($in019.Count -ge 10 -and $bad3i.Count -eq 0) "$($in019.Count) entrees de 019 : aucune cle deja definie par un module precedent ni definie deux fois, memes {n}, aucun texte vide ; ecarts : $(Get-List $bad3i)"

$nk = ''; if ($script:Fail) { $nk = ' ; non conformes : ' + (@($script:FailIds) -join ', ') }
"=== bilan logic-ecriture-onglet : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
