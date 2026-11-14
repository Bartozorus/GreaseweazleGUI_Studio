param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Before = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : onglet « Ecriture » et textes de la 12.11. Test cree par le lot L1 (reperes des champs vides, entrees anglaises) ;
# complete par le lot L9 (onglet en trois etapes, options avancees, barre d onglets, lecteur qui ecrit).
#  C  reperes des champs vides (texte gris d un champ vide : Set-Cue, 100). Appels Set-Cue et largeurs des champs lus dans
#     les modules par l arbre syntaxique ; chaque repere est mesure dans la police de la fenetre (500), en francais et en
#     anglais (vraie fonction T, 010). Regle etalonnee sur une capture de la 12.10 : un repere est entier si sa largeur
#     mesuree ne depasse pas celle du champ (largeur du code, la plus etroite : un champ ancre a droite s elargit).
#     C1 reperes raccourcis par la 12.11 (racine de la Bibliotheque, dossier de la restauration) : entiers ;
#     C2 tous les reperes : aucun repere coupe (lot L9 : champs « Fake index » et « Diskdefs » elargis ; jusqu au lot L9,
#        ce cas attendait exactement ces deux champs coupes) ;
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
#        deux fois, memes {n} dans la cle et dans le texte anglais, aucun texte vide ; I4 textes du lot L9.
# Lot L9 :
#  S  statique (arbre syntaxique) : S1 les 36 variables de controle (les 35 commandes de la 12.10 et btnWCalBack) et les
#     controles nommes de l onglet, crees une fois chacun ; S2 gestionnaires, liaisons de reglage, infobulles, styles et
#     proprietes autres que la place de ces controles : chaque instruction de d8d80d6 (source d avant le lot) est presente,
#     texte identique (empreintes relevees sur cette source ; avec -Before, comparaison instruction par instruction) ;
#     S3 forme du libelle du profil (lue par logic-ecriture-profil-facteur) ; S4 hors de 520 et 145, aucun module ne lit la
#     visibilite, la place ni le parent d une option avancee ni du cadre qui les porte ; S5 appel de Set-WriteTabLayout juste
#     apres Fit-ControlText (600), barre d onglets sur plusieurs rangees (510), lien et « Mode expert » (520).
#  V  disposition : l onglet est construit par les instructions reelles de 500, 510, 520 et 540, puis Fit-ControlText et
#     Set-WriteTabLayout (100, 145), sur de vrais controles jamais affiches. V1 a V4 : francais et anglais, vue simple et
#     mode expert, page de 792 px (fenetre de 800 px : taille par defaut, qui est aussi la taille minimale) et de 808 px
#     (fenetre de 816 px), lecteur A, puis noms les plus larges admis comme lecteur qui ecrit et comme lecteur cible, textes
#     les plus longs des cases et du lien : aucun texte coupe, aucun chevauchement, rien hors cadre, bouton ECRIRE a la meme
#     place dans les deux vues, bas de la vue simple a 370 px au plus, cadre des options avancees affiche avec « Mode
#     expert » seulement ; disposition refaite apres un changement de largeur. V5 parents de la progression et des boutons
#     de calibration, libelle de la calibration jusqu au bord du cadre.
#  W  libelle « Lecteur qui ecrit » : texte de Get-WriteSourceText ; il suit le lecteur du bandeau et la connexion de sa
#     fiche, et nomme le lecteur dont la connexion va a --drive (vraie Get-CommonArgs) ; place, police, infobulle.
#  A  options avancees : A1 valeurs par defaut, aucune comptee ; A2 une option changee a la fois, nommee ; A3 table egale a
#     Set-Defaults (arbre syntaxique) et a $script:SettingDefs, toutes les options du cadre comptees ; A4 toutes changees,
#     infobulle de la ligne ; A5 lien : « Mode expert » inverse, inactif avec la case.
#  E  equivalence : E1 valeurs des 36 controles au demarrage, apres des changements de vue, egales en vue simple et en mode
#     expert (avec -Before, egales a celles de d8d80d6, textes et infobulles compris) ; E2 commandes gw, file d ecriture,
#     controle, prechauffage et mesure demandes par les vraies Start-WriteTabWrite et Start-ImageWrite pour 18
#     configurations de l onglet (options avancees comprises), identiques en vue simple et en mode expert, et a celles de
#     d8d80d6 (empreintes relevees sur cette source ; avec -Before, comparaison ligne a ligne, journal compris).
#  T  barre d onglets : instructions reelles de 510 et 540 sur un vrai TabControl jamais affiche (poignee creee sans
#     fenetre visible) : T1 onze onglets sur deux rangees et six sur une, en francais et en anglais ; T2 hauteur de la page
#     journal affiche (separateur a sa place par defaut) : bouton ECRIRE visible en vue simple.
#  D  CHANGELOG, README des modules et des tests.
# Fonctions et instructions reelles extraites par l arbre syntaxique, ecrites dans des fichiers de travail puis chargees
# par dot-source ; controles WinForms reels jamais affiches. Aucun gw, aucune fenetre, aucune compilation. Non couvert : le
# rendu reel du repere dans la fenetre (marges du champ, EM_SETCUEBANNER), la barre de defilement verticale de l onglet en
# mode expert, le dessin du libelle sur la ligne du titre du cadre.
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
# 12.11 (lot L9) : « Fake index » et « Diskdefs » elargis (140 et 184 px) : aucun repere coupe ; jusqu au lot L9, le cas
# attendait exactement ces deux champs coupes
$fiW = 0; if ($widths.ContainsKey('txtWFakeIdx')) { $fiW = $widths['txtWFakeIdx'] }
$ddW = 0; if ($widths.ContainsKey('txtWDiskdefs')) { $ddW = $widths['txtWDiskdefs'] }
Chk 'C2' ($fontOk -and $rows.Count -ge 17 -and $odd.Count -eq 0 -and $noW.Count -eq 0 -and $cut.Count -eq 0 -and $fiW -eq 140 -and $ddW -eq 184) "$($rows.Count) reperes lus (appels non lus : $(Get-List $odd) ; champs sans largeur lue : $(Get-List $noW)) ; coupes : $(Get-List $cut) ; champs « Fake index » $fiW px et « Diskdefs » $ddW px (lot L9 : 140 et 184)"

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
# I4 (lot L9) : textes de la specification (§ 2.7), mot pour mot, en francais et en anglais ; section L9 de 019
$want9 = [ordered]@{
    '1. Image à écrire' = '1. Image to write'
    '2. Disquette et lecteur' = '2. Disk and drive'
    'Options avancées…' = 'Advanced options…'
    'Options avancées : {0} modifiée(s)…' = 'Advanced options: {0} changed…'
    'Masquer les options avancées' = 'Hide advanced options'
    'options avancées : {0}' = 'advanced options: {0}'
    "Coché : affiche aussi les options avancées de l'onglet Écriture." = 'Checked: also shows the advanced options of the Write tab.'
}
$bad9 = @()
foreach ($k in @($want9.Keys)) {
    if (-not $set019.Contains($k)) { $bad9 += "« $k » absente de 019"; continue }
    if ([string]$script:I18n[$k] -cne [string]$want9[$k]) { $bad9 += "« $k » : « $($script:I18n[$k]) »" }
    if (-not $tKeys.Contains($k)) { $bad9 += "« $k » : aucun appel de T" }
}
$s019 = [System.IO.File]::ReadAllText((Join-Path $mods '019-i18n-1211.ps1'), [System.Text.Encoding]::UTF8)
$i9 = $s019.IndexOf('# --- L9 :'); $i10 = $s019.IndexOf('# --- L10 :')
$sec9 = ''; if ($i9 -ge 0 -and $i10 -gt $i9) { $sec9 = $s019.Substring($i9, $i10 - $i9) }
foreach ($k in @($want9.Keys)) { if (-not $sec9.Contains("['" + $k.Replace("'", "''") + "']") -and -not $sec9.Contains('["' + $k + '"]')) { $bad9 += "« $k » hors de la section L9" } }
Chk 'I4' ($bad9.Count -eq 0) "$($want9.Count) textes du lot L9 (titres des cadres, lien, ligne des options avancees, infobulle de « Mode expert ») : entree anglaise de la specification, cle employee par un appel de T, dans la section L9 de 019 ; ecarts : $(Get-List $bad9)"

# =====================================================================================================================
# Lot L9 : onglet en trois etapes, options avancees, barre d onglets, lecteur qui ecrit
# =====================================================================================================================
[System.Windows.Forms.Application]::EnableVisualStyles()   # comme l application (020) : avant tout controle du lot
$tAsgA = [System.Management.Automation.Language.AssignmentStatementAst]
$tFnA = [System.Management.Automation.Language.FunctionDefinitionAst]
$utf8b = New-Object System.Text.UTF8Encoding($true)
# Les 36 variables de controle de l onglet : les 35 commandes de la 12.10 (15 en vue simple), puis btnWCalBack (L7) ;
# controles nommes sans commande ; options avancees comptees par le lien (Get-WriteAdvDefs) ; contenu du cadre avance
$eoCtl = @('txtWFile', 'btnWFile', 'cmbWFmt', 'chkWPreErase', 'chkWSlow', 'chkWPostCheck', 'chkWUnattended', 'chkWLevel', 'cmbWLevelMode', 'cmbWTarget', 'cmbWCalMode', 'btnWCalib', 'btnWCross', 'btnWCurve', 'btnWrite',
           'chkWEraseEmpty', 'chkWNoVerify', 'numWRetries', 'numWRepair', 'cmbWProfile', 'chkWPrecomp', 'txtWPrecomp', 'txtWPrecomp1', 'txtWTracks', 'cmbWDensel', 'txtWFakeIdx', 'chkWReverse', 'txtWDiskdefs', 'btnWDiskdefs',
           'chkWHard', 'chkWTG43', 'chkWWarm', 'chkWCalWarm', 'numWWarmMin', 'btnWCalReset', 'btnWCalBack')
$eoNamed = @('lblWProfileInfo', 'lblWCal', 'pbWCal', 'lblWPrecomp1', 'lblWRepair', 'lblWLevelMode', 'lblWTarget', 'lblWWarmMin', 'lblWWarmMinU')
$eoAdv = @('chkWEraseEmpty', 'chkWNoVerify', 'numWRetries', 'numWRepair', 'cmbWProfile', 'chkWPrecomp', 'txtWTracks', 'cmbWDensel', 'txtWFakeIdx', 'chkWReverse', 'txtWDiskdefs', 'chkWHard', 'chkWTG43', 'chkWWarm', 'chkWCalWarm', 'numWWarmMin')
$eoAdvBox = @($eoAdv + @('txtWPrecomp', 'txtWPrecomp1', 'lblWPrecomp1', 'lblWRepair', 'lblWRetries', 'btnWDiskdefs', 'lblWWarmMin', 'lblWWarmMinU', 'btnWCalBack', 'btnWCalReset', 'grpWAdv'))
# Empreintes relevees sur d8d80d6, la source d avant le lot L9 (sortie du test lance avec -Before <export de d8d80d6>) :
# S2, debut du SHA-256 de chaque instruction gardee de 520 ; E2, SHA-256 des commandes de chaque configuration
$eoS2Ref = @(
    '01c072a1c29125c7', '02195b377e0acfb8', '05747bbd10720c85', '060245da3155cf99', '06a1300a283e3dc2', '06dfdcfd1de104ee', '09634c241a54bb89', '0aac5a9968a07ab7',
    '0bc5254e1262d859', '0c529a33f4fc7961', '0ddba44c89049bfb', '1313cf5ef60342be', '1459bd09170b53e6', '1a10b06a97740961', '1c09ca9f19d03288', '1c818c45c7beab6a',
    '1cdf33f12e20cedd', '20155d0491d09cba', '21f74b31c1e9e140', '2477718203645d84', '2812637fc71bd142', '29ce0b66fa3d1cf0', '2b86eca4042223df', '2b98bf0d7432a3df',
    '2c93cf7708371bb6', '2cbffe4478eeb7af', '2e45957441cc9a96', '2ea8fa5ff9a86f8d', '2f39350e3e3685a4', '3055aa222e7601b2', '3276c0a7137fc461', '3428463f7863bfed',
    '349b75960c24f412', '3545cfe09586a022', '360336fbc916f93b', '362cbd9e74b23de8', '39468d13e5d2bf9d', '3b69053a1139b2ac', '430e6ae24a658179', '4517f9b7da0b2fa8',
    '4562540f882c54b6', '4620483a7a4be173', '47ef944bf24281ea', '4c93e4f1cb21a940', '4d6c72eeed519527', '4d8d2ebb414cebf4', '4f6d90e70b281b52', '51a6019ae9faa766',
    '5326d78a8d723b50', '544638395bd361be', '55f68ca65ef1fdb1', '565733057dd5b9b4', '57d8874f9afad555', '59eff7114affcdc7', '5bbcced07d13e790', '5cc7b40a4272a109',
    '5e0e44a7348681db', '61a392e79ac93d3a', '61ad5341c8608a5f', '6493b23bdcac9a2e', '65070345bebec45d', '678bc2a117cf5664', '6876e3b7e67b5c9b', '6ab208da63c47f1e',
    '6b9b714a2099354d', '707839f13c0b2efb', '70f7b74d46157bd8', '71d44eae928a65eb', '73189bf25d9dc1dd', '738b6d4257210527', '739cc573e612b576', '75fcb425621b235a',
    '76f25a39a7cc649a', '775cc1c6b96df781', '7b961ae42d016871', '7daab5987e90ba65', '7dbbb4596113d786', '7eba27b04f40d613', '866b6213fa784364', '87429eb8aa498c36',
    '8852f18455c27cbe', '88617cbcbd44669c', '8a2256548cb05f21', '8a321c6f9782aa92', '8c9f0d5bf7db0f2f', '8ead95011b71f319', '8efe15aa6cdb54bb', '909f26f96e91a2ca',
    '91a00e3883871830', '92068eec082e773f', '92cab291df171eef', '9f74d257700d5a20', 'a325616e34a98df4', 'a4bd281dfdb9d9c5', 'a7a3b62e23f2ae53', 'a8eb882c9f84d728',
    'ab898cf19eaf8129', 'ab9b7deb16c7cb32', 'b65380b930bbf3b1', 'b7161fffffd23d36', 'b757ed89c38965f9', 'bab16824807f1702', 'bd69141703b91d1d', 'bd93a81d65a3b185',
    'bee027d9d3d78281', 'c19e00f2612891ea', 'c2cdae63e37652f3', 'c3430af750c1018e', 'c61b8ac594da934f', 'c69785ba831ef49e', 'c7f2082ea1f0942d', 'c8f280b3b8743c04',
    'c984cdbb466b366c', 'c9ba61892158a303', 'cad950be3905eca3', 'caf77646684123ee', 'cd69cfe05dada7b2', 'ce916d77c54dd35f', 'cedc2092f60328a5', 'cf36d1123ee724d1',
    'cfa5981d5bbda8bd', 'd3daab2376c0eda1', 'd6f87f036afddaa6', 'd70abf5f4d708d32', 'd99211a4bec48c53', 'dc055695c703105a', 'dc30f7360d9fee01', 'dc7eda570db8dd08',
    'dea6717d58e08b40', 'e0e763b8a342a6c7', 'e22cf66b040e2aa4', 'e4c8c9967820eff0', 'e605a144bf61fc82', 'e63486738541075c', 'e8231ea248e544a2', 'e89af2ce0b01e4b3',
    'ea8dd628b4c03599', 'ec7ca13be08f7cf5', 'efeb38e6e4309071', 'f02544e7fae3e30f', 'f142f281c864a686', 'f2490846621ea4ca', 'f4a51d7374fc88e2', 'f72afd3ba019557f',
    'f88ca53b5ebe134a', 'f9ff0466d7980c4d', 'fb9807d984fae60e', 'fd55dbecb5b25d96'
)
$eoE2Ref = @{
    E01 = '16d3111066cd4d90'; E02 = '55992ccd99bd50d0'; E03 = '4073def8561dde2c'; E04 = '42424f4776ffe227'; E05 = '59acdc1d2668f429'; E06 = 'ee528337abdcd909'
    E07 = 'efa50701388d6e4a'; E08 = 'cec1a0cc517f5c4c'; E09 = 'b827dfd7c6949649'; E10 = '076f444230598f93'; E11 = 'ccfd55129e25e5d4'; E12 = 'e18645e325c943cd'
    E13 = 'bafdf60ae23065bb'; E14 = '16edf4cb821ec357'; E15 = '8d6b6f9ecdc1620d'; E16 = '0772ed9234fded8a'; E17 = 'd46b3e993da43f61'; E18 = 'cfb6924208d483d2'
}
function Get-EoSha([string]$s, [int]$n = 64) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($s))) -replace '-', '').ToLower().Substring(0, $n) } finally { $h.Dispose() }
}
function Get-EoMod([string]$root, [string]$px) {
    $f = @(Get-ChildItem -LiteralPath (Join-Path $root 'src\modules') -Filter "$px-*.ps1" -File)
    if ($f.Count -ne 1) { throw "module $px introuvable sous $root" }
    return $f[0].FullName
}
function Write-EoGen([string]$path, $parts) { [System.IO.File]::WriteAllText($path, ((@($parts) -join "`r`n`r`n") + "`r`n"), $utf8b) }
function Get-EoKeep([string]$file) {
    # Instructions du niveau du script de 520 qui portent sur un controle de l onglet (ou la liste du bandeau) : gestionnaires,
    # liaisons de reglage, infobulles, styles (Set-Btn), elements de liste et proprietes autres que la place et l ancrage ;
    # textes aux fins de ligne LF, tries
    $geo = @('Location', 'Size', 'Width', 'Height', 'Left', 'Top', 'Anchor')
    $vars = @($eoCtl + $eoNamed + @('cmbDrive'))
    $l = New-Object System.Collections.Generic.List[string]
    foreach ($s in (Get-Ast $file).EndBlock.Statements) {
        $t = ($s.Extent.Text -replace "`r`n", "`n")
        $ok = $false
        if ($t.StartsWith('Register-SettingCtl ')) { $ok = $true }
        elseif ($t -match '^\$tip\.SetToolTip\(\$(\w+)[,)]') { $ok = ($vars -contains $Matches[1]) }
        elseif ($t -match '^Set-Btn \$(\w+)\b') { $ok = ($vars -contains $Matches[1]) }
        elseif ($t -match '^\[void\]\$(\w+)\.') { $ok = ($vars -contains $Matches[1]) }
        elseif ($t -match '^\$(\w+)\.Add_\w+\(') { $ok = ($vars -contains $Matches[1]) }
        elseif ($t -match '^\$(\w+)\.(\w+) = ') { $ok = ($vars -contains $Matches[1] -and $geo -notcontains $Matches[2]) }
        if ($ok) { $l.Add($t) }
    }
    $a = [string[]]$l.ToArray(); [Array]::Sort($a, [System.StringComparer]::Ordinal)
    return ,$a
}

'--- S : statique (520, 510, 600, tous les modules)'
$p520 = Get-EoMod $Wt '520'
$a520 = Get-Ast $p520
$top520 = @($a520.EndBlock.Statements)
$s1Bad = @(); $s1Types = @{ txt = 'TextBox'; btn = 'Button'; cmb = 'ComboBox'; chk = 'CheckBox'; num = 'NumericUpDown'; pb = 'ProgressBar' }
foreach ($v in @($eoCtl + $eoNamed + @('lblWSource', 'lnkWAdv', 'lblWPlan', 'lblWRetries', 'grpWImage', 'grpWOpt', 'grpWAdv'))) {
    $as = @($top520 | Where-Object { $_ -is $tAsgA -and $_.Left.Extent.Text -eq "`$$v" })
    if ($as.Count -ne 1) { $s1Bad += "$v : $($as.Count) creation(s)"; continue }
    $r = $as[0].Right.Extent.Text
    $px = ([regex]::Match($v, '^[a-z]+')).Value
    if ($s1Types.ContainsKey($px) -and $r -cne "New-Object System.Windows.Forms.$($s1Types[$px])") { $s1Bad += "$v : $r" }
    if ($px -eq 'lbl' -and $r -notmatch '^(New-Label |New-Object System\.Windows\.Forms\.Label$)') { $s1Bad += "$v : $r" }
}
Chk 'S1' ($s1Bad.Count -eq 0 -and $eoCtl.Count -eq 36) "les $($eoCtl.Count) variables de controle (35 commandes de la 12.10 et btnWCalBack), $($eoNamed.Count) controles nommes de la 12.10, les 3 cadres et les 4 controles nommes du lot (lblWSource, lnkWAdv, lblWPlan, lblWRetries) crees une fois chacun, au niveau du script de 520 ; ecarts : $(Get-List $s1Bad)"
# S2 : chaque instruction gardee de d8d80d6 est presente, texte identique (empreintes ci-dessus) ; avec -Before, liste
# complete comparee instruction par instruction
$keepNow = Get-EoKeep $p520
$hNow = @($keepNow | ForEach-Object { Get-EoSha $_ 16 })
$s2Miss = @($eoS2Ref | Where-Object { $hNow -notcontains $_ })
$s2Extra = @($hNow | Where-Object { $eoS2Ref -notcontains $_ })
"  S2 : $($keepNow.Count) instructions gardees dans 520 ; empreintes de d8d80d6 : $($eoS2Ref.Count) ; absentes : $($s2Miss.Count) ; en plus : $($s2Extra.Count)"
Chk 'S2' ($eoS2Ref.Count -gt 100 -and $s2Miss.Count -eq 0) "gestionnaires, liaisons de reglage, infobulles, styles, elements de liste et proprietes autres que la place des controles de l onglet : les $($eoS2Ref.Count) instructions de d8d80d6 sont dans 520, texte identique (empreintes) ; absentes : $(Get-List $s2Miss)"
if ($Before) {
    $keepB = Get-EoKeep (Get-EoMod $Before '520')
    "  S2b : empreintes de la source d avant (a recopier dans `$eoS2Ref si elles changent) : $((@($keepB | ForEach-Object { Get-EoSha $_ 16 }) | Sort-Object -Unique) -join ',')"
    $bMiss = @($keepB | Where-Object { $keepNow -cnotcontains $_ })
    $bExtra = @($keepNow | Where-Object { $keepB -cnotcontains $_ })
    foreach ($x in @($bMiss | Select-Object -First 4)) { "  S2b ABSENTE : $(($x -split "`n")[0])" }
    foreach ($x in @($bExtra | Select-Object -First 8)) { "  S2b en plus : $(($x -split "`n")[0])" }
    Chk 'S2b' ($keepB.Count -gt 100 -and $bMiss.Count -eq 0 -and $bExtra.Count -eq 0) "-Before $Before : $($keepB.Count) instructions de la source d avant, toutes dans 520 a l identique ; aucune en plus ; absentes : $($bMiss.Count) ; en plus : $($bExtra.Count)"
} else { '  S2b saute (sans -Before : comparaison instruction par instruction avec la source d avant le lot)' }
$s520 = [System.IO.File]::ReadAllText($p520, [System.Text.Encoding]::UTF8)
$mPi = [regex]::Match($s520, "\`$lblWProfileInfo\.Location = '(\d+),(\d+)'; \`$lblWProfileInfo\.Size = '(\d+),(\d+)'")
Chk 'S3' ($mPi.Success -and $mPi.Groups[3].Value -eq '458' -and $mPi.Groups[4].Value -eq '58' -and $s520.Contains('$grpWImage.Controls.AddRange(@((New-Label (T ''Image :'') ''12,23''), $txtWFile, $btnWFile, (New-Label (T ''Format :'') ''12,57''), $cmbWFmt, $lblWProfileInfo))')) "libelle du profil sous la forme « Location = '…'; Size = '…' » (lue par logic-ecriture-profil-facteur) : $($mPi.Groups[1].Value),$($mPi.Groups[2].Value) $($mPi.Groups[3].Value) x $($mPi.Groups[4].Value), dans le cadre 1"
# S4 : hors de 520 et 145, aucun module ne lit la visibilite, la place ni le parent d une option avancee ni de son cadre :
# une option repliee garde son effet (le banc, lui, doit cocher « Mode expert » avant un PerformClick)
$watchM = @('Visible', 'Location', 'Left', 'Top', 'Right', 'Bottom', 'Bounds', 'Parent')
$s4 = @()
foreach ($f in $files) {
    if ($f.Name -match '^(520|145)-') { continue }
    foreach ($m in $asts[$f.Name].FindAll({ param($x) $x -is [System.Management.Automation.Language.MemberExpressionAst] -and $x.Expression -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)) {
        $vn = [string]$m.Expression.VariablePath.UserPath
        if ($eoAdvBox -contains $vn -and $watchM -contains $m.Member.Extent.Text) { $s4 += "$($f.Name.Substring(0, 3)):$($m.Extent.StartLineNumber) $($m.Extent.Text)" }
    }
}
Chk 'S4' ($s4.Count -eq 0) "aucune lecture de Visible, Location, Left, Top, Right, Bottom, Bounds ou Parent des $($eoAdvBox.Count) controles du cadre des options avancees hors de 520 et 145 ; trouvees : $(Get-List $s4)"
$top600 = @((Get-Ast (Get-EoMod $Wt '600')).EndBlock.Statements | ForEach-Object { $_.Extent.Text })
$iFit = [array]::IndexOf([string[]]$top600, 'Fit-ControlText $form')
$s510 = [System.IO.File]::ReadAllText((Get-EoMod $Wt '510'), [System.Text.Encoding]::UTF8)
$s5 = @(($iFit -ge 0 -and $iFit + 1 -lt $top600.Count -and $top600[$iFit + 1] -ceq 'Set-WriteTabLayout'), ($s510.Contains("`$tabs.Padding = New-Object System.Drawing.Point(12, 5)`r`n") -and $s510.Contains("`r`n`$tabs.Multiline = `$true`r`n")),
        ($s520.Contains('$lnkWAdv.Add_LinkClicked({ Switch-WAdvView })')), ($s520.Contains('$chkExpert.Add_CheckedChanged({ Set-WriteTabLayout })')), ($s520.Contains('$chkExpert.Add_EnabledChanged({ $lnkWAdv.Enabled = $chkExpert.Enabled })')),
        ($s520.Contains('foreach ($wAdvDef in @(Get-WriteAdvDefs)) { Register-WAdvCtl $wAdvDef.Ctl }')))
Chk 'S5' (@($s5 | Where-Object { -not $_ }).Count -eq 0) "600 : Set-WriteTabLayout juste apres Fit-ControlText $($s5[0]) ; 510 : onglets sur plusieurs rangees $($s5[1]) ; 520 : clic du lien $($s5[2]), « Mode expert » $($s5[3]) et son etat actif $($s5[4]), options avancees suivies $($s5[5])"

# --- Construction reelle de l onglet : fichiers de travail par source (fonctions de tous les modules fn, etat, instructions)
$eoImg = Join-Path $here 'img'
if (-not (Test-Path -LiteralPath $eoImg)) { [void](New-Item -ItemType Directory -Path $eoImg -Force) }
$eoAdf = Join-Path $eoImg 'jeu.adf'; [System.IO.File]::WriteAllBytes($eoAdf, (New-Object byte[] 901120))
$eoImgF = Join-Path $eoImg 'jeu.img'; [System.IO.File]::WriteAllBytes($eoImgF, (New-Object byte[] 737280))
$eoDd = Join-Path $eoImg 'diskdefs.cfg'; [System.IO.File]::WriteAllText($eoDd, "# factice`r`n", $utf8b)
function New-EoGen([string]$root, [string]$tag) {
    $g = @{ Root = $root; Tag = $tag }
    $fns = New-Object System.Collections.Generic.List[string]
    foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'src\modules') -Filter '*.ps1' -File | Where-Object { $_.Name -match '^[1-4]\d\d-fn-' } | Sort-Object Name)) {
        foreach ($fd in (Get-Ast $f.FullName).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) { $fns.Add($fd.Extent.Text) }
    }
    $g.Fn = Join-Path $here "gen-$tag-fonctions.ps1"; Write-EoGen $g.Fn $fns
    # Etat : versions (000), chemins (020, affectations seules, AppDir pose par le test), etats et constantes (040, 550 a 590)
    $st = New-Object System.Collections.Generic.List[string]
    foreach ($px in @('000', '020', '040', '550', '560', '565', '570', '580', '590')) {
        foreach ($s in (Get-Ast (Get-EoMod $root $px)).EndBlock.Statements) {
            $t = $s.Extent.Text
            if ($t -match 'Add-Type|EnableVisualStyles') { continue }
            if ($px -eq '020' -and -not ($s -is $tAsgA -and $t.StartsWith('$script:') -and -not $t.StartsWith('$script:AppDir'))) { continue }
            $st.Add($t)
        }
    }
    $g.State = Join-Path $here "gen-$tag-etat.ps1"; Write-EoGen $g.State $st
    # 500 : fenetre (jamais affichee), infobulles, police grasse, theme, taille des pages, sans le bloc C#
    $g.U500 = Join-Path $here "gen-$tag-500.ps1"
    Write-EoGen $g.U500 @((Get-Ast (Get-EoMod $root '500')).EndBlock.Statements | Where-Object { $_.Extent.Text -notmatch 'Add-Type' } | ForEach-Object { $_.Extent.Text })
    # 510 : bandeau (du panneau a la remise a zero de ses positions relevees), barre d onglets
    $ban = @(); $tbs = @(); $on = $false
    foreach ($s in (Get-Ast (Get-EoMod $root '510')).EndBlock.Statements) {
        $t = $s.Extent.Text
        if ($t.StartsWith('$pnlTop = ')) { $on = $true }
        if ($on) { $ban += $t }
        if ($t.StartsWith('$script:DriveBanner = ')) { $on = $false }
        if ($t -match '^\$tabs( = |\.)') { $tbs += $t }
    }
    $g.U510 = Join-Path $here "gen-$tag-510.ps1"; Write-EoGen $g.U510 $ban
    $g.Tabs = Join-Path $here "gen-$tag-510-onglets.ps1"; Write-EoGen $g.Tabs $tbs
    $g.U520 = Join-Path $here "gen-$tag-520.ps1"; Write-EoGen $g.U520 @((Get-Ast (Get-EoMod $root '520')).EndBlock.Statements | ForEach-Object { $_.Extent.Text })
    # 540 : styles des boutons et reperes des champs de l onglet, infobulle du bouton ECRIRE ; icones des onglets
    $g.U540 = Join-Path $here "gen-$tag-540.ps1"
    Write-EoGen $g.U540 @((Get-Ast (Get-EoMod $root '540')).EndBlock.Statements | Where-Object { $_.Extent.Text -match '^(Set-Btn\s+|Set-Cue\s+|\$tip\.SetToolTip\()\$(\w+)\b' -and $eoCtl -contains $Matches[2] } | ForEach-Object { $_.Extent.Text })
    $g.Ico = Join-Path $here "gen-$tag-540-icones.ps1"
    Write-EoGen $g.Ico @((Get-Ast (Get-EoMod $root '540')).EndBlock.Statements | Where-Object { $_.Extent.Text -match '^(\$imgTabs( = |\.)|foreach \(\$n in @\(''Home''|\$tabs\.ImageList = |\$tab\w+\.ImageKey = )' } | ForEach-Object { $_.Extent.Text })
    # Set-Defaults (120) : instructions qui portent sur l onglet Ecriture, reglages compris, dans leur ordre
    $sd = @((Get-Ast (Get-EoMod $root '120')).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Set-Defaults' }, $false))
    $ds = @($sd[0].Body.EndBlock.Statements | Where-Object { $_.Extent.Text -match '\$(txtW|cmbW|chkW|numW|lblW)' -or $_.Extent.Text -match '^(Reset-Settings|Update-SlowUi|Update-TargetDriveUi)$' } | ForEach-Object { $_.Extent.Text })
    $g.Def = Join-Path $here "gen-$tag-defauts.ps1"
    Write-EoGen $g.Def @("function Invoke-EoDefaults {`r`n" + ($ds -join "`r`n") + "`r`n}")
    $g.NDef = $ds.Count
    return $g
}
function Set-EoStubs {
    # Bouchons : gw, fenetres, journal, prechauffage, controle, mesure, profil de l image et les autres onglets ; les
    # commandes et demandes sont relevees dans $script:EoTrace, le journal dans $script:EoLog
    function script:Start-Gw([string[]]$gwArgs, [switch]$Soft) { [void]$script:EoTrace.Add('gw ' + ($gwArgs -join ' ')) }
    function script:Invoke-NextChainStep {
        foreach ($q in @($script:WriteQueue.ToArray())) { [void]$script:EoTrace.Add('file ' + (@($q) -join ' ')) }
        if ($script:WriteArgs) { [void]$script:EoTrace.Add('ecriture ' + (@($script:WriteArgs) -join ' ')) }
        [void]$script:EoTrace.Add('etapes ' + $script:Chain.Count)
    }
    function script:Start-WriteWarmup([string]$tspec, [bool]$noWarm) {
        foreach ($q in @($script:WriteQueue.ToArray())) { [void]$script:EoTrace.Add('file ' + (@($q) -join ' ')) }
        [void]$script:EoTrace.Add("prechauffage $tspec $noWarm ; case $($chkWWarm.Checked) ; duree $($script:CalWarmupMinutes) ; etapes $($script:Chain.Count)")
    }
    function script:New-WriteCheck([string[]]$base, [string]$image, [string]$userTSpec, [int]$max, [string[]]$readOpts, $headPrecomp, [string]$eraseMode = '') {
        $hp = if ($headPrecomp) { "$($headPrecomp[0])/$($headPrecomp[1])" } else { '-' }
        [void]$script:EoTrace.Add("controle base $($base -join ' ') ; pistes $userTSpec ; passes $max ; relecture $($readOpts -join ' ') ; precomp $hp ; effacement $eraseMode")
        $script:Rep = @{}
    }
    function script:Start-LevelBeforeWrite([string]$mode, [switch]$Restore, [switch]$Measure) { [void]$script:EoTrace.Add("mesure $mode $([bool]$Measure)") }
    function script:Show-AppMessage([string]$text, [string]$title, [string]$buttons = 'OK', [string]$icon = 'Information') { [void]$script:EoTrace.Add("message $title"); [void]$script:EoLog.Add($text); return 'OK' }
    function script:Show-AppConfirm([string]$Title, [string]$Heading, [string]$Text, [string]$Check = '', [string]$GoText = '', [string]$GoGlyph = '', [string]$Level = 'warn', [string]$Picto = 'warn', [string]$AltText = '', $Combo = $null) { [void]$script:EoTrace.Add("confirmation $Title"); [void]$script:EoLog.Add($Text); return $true }
    function script:Append-Log($t) { [void]$script:EoLog.Add([string]$t) }
    function script:Update-PrecompForImage($p) { [void]$script:EoTrace.Add('profil recalcule') }
    function script:Sync-PrecompCurves { }
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
function Get-EoKids($p) { foreach ($c in @($p.Controls)) { $c; if ($c -is [System.Windows.Forms.GroupBox]) { Get-EoKids $c } } }
function Get-EoName($c) {
    if ($c.Name) { return $c.Name }
    foreach ($v in @($eoCtl + $eoNamed + @('grpWImage', 'grpWOpt', 'grpWAdv'))) { if ([object]::ReferenceEquals((Get-Variable -Name $v -ValueOnly -ErrorAction SilentlyContinue), $c)) { return $v } }
    return "$($c.GetType().Name) « $($c.Text) »"
}
function Get-EoTextBad($c) {
    # Texte coupe d un controle : case, lien ou libelle a largeur automatique (largeur preferee), bouton a texte (regle de
    # Fit-ControlText, 100 : texte + 46 px avec icone, 24 sans), liste (element le plus large + 16 px), champ (repere)
    $n = Get-EoName $c
    if ($c -is [System.Windows.Forms.CheckBox] -or $c -is [System.Windows.Forms.LinkLabel] -or ($c -is [System.Windows.Forms.Label] -and $c.AutoSize)) {
        if ($c.PreferredSize.Width -gt $c.Width) { return "$n texte coupe ($($c.PreferredSize.Width) > $($c.Width))" }
    } elseif ($c -is [System.Windows.Forms.Button]) {
        if ($c.Text -and $c.Text -ne '...') {
            $need = [System.Windows.Forms.TextRenderer]::MeasureText($c.Text, $c.Font).Width + $(if ($c.Image) { 46 } else { 24 })
            if ($need -gt $c.Width) { return "$n bouton trop etroit ($need > $($c.Width))" }
        }
    } elseif ($c -is [System.Windows.Forms.ComboBox]) {
        $mx = 0; foreach ($it in @($c.Items)) { $w = [System.Windows.Forms.TextRenderer]::MeasureText([string]$it, $c.Font).Width; if ($w -gt $mx) { $mx = $w } }
        if ($mx + 16 -gt $c.Width) { return "$n element coupe ($mx + 16 > $($c.Width))" }
    } elseif ($c -is [System.Windows.Forms.TextBox]) {
        if ($script:CueText.ContainsKey($c)) { $w = [System.Windows.Forms.TextRenderer]::MeasureText([string]$script:CueText[$c], $c.Font).Width; if ($w -gt $c.Width) { return "$n repere coupe ($w > $($c.Width))" } }
    }
    return $null
}
function Test-EoLayout([bool]$expert) {
    # Defauts de la disposition : textes coupes, controles hors de leur cadre ou de la page, chevauchements entre controles
    # d un meme parent ; vue simple : le cadre des options avancees et son contenu ne comptent pas
    $bad = @()
    $all = @(Get-EoKids $tabW)
    foreach ($c in $all) {
        $p = $c.Parent
        if (-not $expert -and ([object]::ReferenceEquals($c, $grpWAdv) -or [object]::ReferenceEquals($p, $grpWAdv))) { continue }
        $n = Get-EoName $c
        if ($p -is [System.Windows.Forms.GroupBox]) {
            if ($c.Left -lt 0 -or $c.Top -lt 0 -or $c.Right -gt $p.DisplayRectangle.Right -or $c.Bottom -gt $p.ClientSize.Height - 2) { $bad += "$n hors du cadre $(Get-EoName $p) ($($c.Bounds) ; bord $($p.DisplayRectangle.Right), bas $($p.ClientSize.Height - 2))" }
        } elseif ($c.Left -lt 0 -or $c.Top -lt 0 -or $c.Right -gt $p.ClientSize.Width - 2) { $bad += "$n hors de la page ($($c.Bounds) ; page $($p.ClientSize.Width))" }
        $tb = Get-EoTextBad $c
        if ($tb) { $bad += $tb }
    }
    foreach ($p in @($tabW, $grpWImage, $grpWOpt, $grpWAdv)) {
        if (-not $expert -and [object]::ReferenceEquals($p, $grpWAdv)) { continue }
        $k = @($p.Controls | Where-Object { $expert -or -not [object]::ReferenceEquals($_, $grpWAdv) })
        for ($i = 0; $i -lt $k.Count; $i++) { for ($j = $i + 1; $j -lt $k.Count; $j++) {
            if ($k[$i].Bounds.IntersectsWith($k[$j].Bounds)) { $bad += "chevauchement $(Get-EoName $k[$i]) $($k[$i].Bounds) / $(Get-EoName $k[$j]) $($k[$j].Bounds)" }
        } }
    }
    return ,@($bad)
}
function Get-EoBottom {
    # Bas du contenu de la vue simple : les trois etapes (cadres 1 et 2, bouton, lien, ligne)
    $b = 0; foreach ($c in @($grpWImage, $grpWOpt, $btnWrite, $lnkWAdv, $lblWPlan)) { if ($c.Bottom -gt $b) { $b = $c.Bottom } }
    return $b
}
function Get-EoSnap {
    # Valeurs des 36 controles : etat, texte, elements, nom, infobulle (pas la place ni la visibilite)
    $o = New-Object System.Collections.Generic.List[string]
    foreach ($v in $eoCtl) {
        $c = Get-Variable -Name $v -ValueOnly -ErrorAction SilentlyContinue
        if (-not $c) { $o.Add("$v absent"); continue }
        $s = "$v name=$($c.Name) enabled=$($c.Enabled) text=$($c.Text) tip=$($tip.GetToolTip($c))"
        if ($c -is [System.Windows.Forms.CheckBox]) { $s += " checked=$($c.Checked)" }
        elseif ($c -is [System.Windows.Forms.NumericUpDown]) { $s += " value=$($c.Value) min=$($c.Minimum) max=$($c.Maximum)" }
        elseif ($c -is [System.Windows.Forms.ComboBox]) { $s += " index=$($c.SelectedIndex) items=$(@($c.Items) -join '|')" }
        $o.Add($s)
    }
    return ,@($o.ToArray())
}

# Liste des sources : la source testee ; avec -Before, la source d avant le lot (d8d80d6), construite d abord
$eoRoots = @()
if ($Before) { $eoRoots += @{ Root = (Get-TestRoot $Before); Tag = 'avant'; New = $false } }
$eoRoots += @{ Root = $Wt; Tag = 'eo'; New = $true }
$script:EoTrace = New-Object System.Collections.Generic.List[string]
$script:EoLog = New-Object System.Collections.Generic.List[string]
$eoRes = @{}
# Configurations de l equivalence (E2) : image, format, puis reglages poses sur les controles comme le ferait l utilisateur
$eoScn = @(
    @{ Id = 'E01'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { } }
    @{ Id = 'E02'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $false } }
    @{ Id = 'E03'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $chkWNoVerify.Checked = $true; $numWRetries.Value = 3 } }
    @{ Id = 'E04'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $chkWEraseEmpty.Checked = $false; $chkWPreErase.Checked = $false } }
    @{ Id = 'E05'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $chkWReverse.Checked = $true; $chkWHard.Checked = $true; $chkWTG43.Checked = $true } }
    @{ Id = 'E06'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $cmbWDensel.SelectedIndex = 1; $txtWFakeIdx.Text = '300rpm' } }
    @{ Id = 'E07'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $txtWDiskdefs.Text = $eoDd } }
    @{ Id = 'E08'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $txtWTracks.Text = 'c=0-39' } }
    @{ Id = 'E09'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $chkWPrecomp.Checked = $false } }
    @{ Id = 'E10'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $cmbWProfile.SelectedIndex = 3; $txtWPrecomp.Text = '0=90:40=120' } }
    @{ Id = 'E11'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $chkWPostCheck.Checked = $false } }
    @{ Id = 'E12'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $numWRepair.Value = 1 } }
    @{ Id = 'E13'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $false; $chkWWarm.Checked = $false; $numWWarmMin.Value = 2.5 } }
    @{ Id = 'E14'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $false; $chkWCalWarm.Checked = $false; $numWWarmMin.Value = 0 } }
    @{ Id = 'E15'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $chkWSlow.Checked = $true; $cmbWProfile.SelectedIndex = 2; $txtWPrecomp1.Text = '0=80' } }
    @{ Id = 'E16'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $chkWSlow.Checked = $true; $chkWLevel.Checked = $true } }
    @{ Id = 'E17'; Img = 'adf'; Fmt = 'amiga.amigados'; Do = { $cmbWCalMode.SelectedIndex = 2 } }
    @{ Id = 'E18'; Img = 'img'; Fmt = 'ibm.720'; Do = { $chkWSlow.Checked = $true; $chkWEraseEmpty.Checked = $false; $chkWNoVerify.Checked = $true; $numWRetries.Value = 4; $numWRepair.Value = 2; $cmbWProfile.SelectedIndex = 1
                                                         $txtWTracks.Text = 'h=0-1'; $cmbWDensel.SelectedIndex = 2; $txtWFakeIdx.Text = '200ms'; $chkWReverse.Checked = $true; $txtWDiskdefs.Text = $eoDd; $chkWWarm.Checked = $false; $chkWCalWarm.Checked = $false; $numWWarmMin.Value = 7.5 } }
)
function Invoke-EoScenario($sc) {
    # Une configuration : reglages de Set-Defaults (partie Ecriture), image et format, reglages de la configuration, puis la
    # vraie Start-WriteTabWrite (bouton ECRIRE) ; rend les commandes et demandes relevees, et le journal
    Invoke-EoDefaults
    $txtWFile.Text = $(if ($sc.Img -eq 'img') { $eoImgF } else { $eoAdf })
    $cmbWFmt.SelectedItem = $sc.Fmt
    & $sc.Do
    $script:EoTrace.Clear(); $script:EoLog.Clear()
    $script:WriteQueue.Clear(); $script:Chain.Clear(); $script:WriteArgs = $null; $script:Rep = $null
    $script:LevelPostForce = $false; $script:WriteFactorNext = $null; $script:Restore = $null; $script:GwProc = $null
    try { Start-WriteTabWrite } catch { [void]$script:EoTrace.Add("ERREUR $($_.Exception.Message)") }
    $norm = { param($x) ([string]$x).Replace($eoImg, '<img>') }
    return @{ Trace = @($script:EoTrace | ForEach-Object { & $norm $_ }); Log = @($script:EoLog | ForEach-Object { & $norm $_ }) }
}

foreach ($eoR in $eoRoots) {
    "--- construction de l onglet : $(if ($eoR.New) { 'source testee' } else { "source d avant le lot ($($eoR.Root))" })"
    $eoG = New-EoGen $eoR.Root $eoR.Tag
    foreach ($eoLang in @($(if ($eoR.New) { @('fr', 'en') } else { @('fr') }))) {
        # Etat, fonctions et bouchons, puis les instructions de l interface dans l ordre de l application
        $script:AppDir = $here
        . $eoG.State
        . $eoG.Fn
        Set-EoStubs
        $script:Lang = $eoLang
        $script:UiReady = $false; $script:ScpStatsOk = $true
        . $eoG.U500
        . $eoG.U510
        . $eoG.U520
        . $eoG.U540
        . $eoG.Def
        # Page de 782 px a la creation (New-TabPage), dans la police de la fenetre ; puis comme 600 : Fit-ControlText et,
        # pour la source testee, Set-WriteTabLayout ; Set-Defaults ; fenetre affichee (UiReady)
        $tabW.Font = $form.Font
        Fit-ControlText $tabW
        if ($eoR.New) { Set-WriteTabLayout }
        Invoke-EoDefaults
        $script:UiReady = $true
        $tabW.Size = New-Object System.Drawing.Size(792, 516)
        $key = "$($eoR.Tag)-$eoLang"
        $eoRes[$key] = @{ Snap0 = (Get-EoSnap) }
        if ($eoLang -eq 'fr') {
            # E2 : configurations ; source testee : vue simple puis mode expert
            $eoRes[$key].E = @{}; $eoRes[$key].EX = @{}
            foreach ($sc in $eoScn) { $eoRes[$key].E[$sc.Id] = Invoke-EoScenario $sc }
            if ($eoR.New) {
                $chkExpert.Checked = $true
                foreach ($sc in $eoScn) { $eoRes[$key].EX[$sc.Id] = Invoke-EoScenario $sc }
                $chkExpert.Checked = $false
            }
            Invoke-EoDefaults
        }
        if (-not $eoR.New) { continue }

        # ---------------------------------------------------------------- V, W, A : source testee, chaque langue
        $L = $eoLang
        if ($L -eq 'fr') { '--- W : libelle « Lecteur qui ecrit »' }
        # W : lecteur A, puis B, puis un lecteur enregistre sur A, puis sa fiche passee sur 0
        $wTxt = @(); $wArg = @()
        $cmbDrive.SelectedItem = 'A'; $wTxt += $lblWSource.Text; $wArg += @(Get-CommonArgs)[0]
        $wExp = @((Get-WriteSourceText))
        $cmbDrive.SelectedItem = 'B'; $wTxt += $lblWSource.Text; $wArg += @(Get-CommonArgs)[0]; $wExp += (Get-WriteSourceText)
        $script:DriveReg = [ordered]@{}
        $script:DriveReg['TEAC FD-235HF'] = @{ Name = 'TEAC FD-235HF'; Conn = 'A'; Id = 'L20261114-100000'; Created = '14/11/2026 10:00:00'; From = ''; At = '' }
        [void]$cmbDrive.Items.Add('TEAC FD-235HF')
        $cmbDrive.SelectedItem = 'TEAC FD-235HF'; $wTxt += $lblWSource.Text; $wArg += @(Get-CommonArgs)[0]; $wExp += (Get-WriteSourceText)
        $wR1 = $lblWSource.Right
        (Get-DriveRecord 'TEAC FD-235HF').Conn = '0'
        Update-TargetDriveUi
        $wTxt += $lblWSource.Text; $wArg += @(Get-CommonArgs)[0]; $wExp += (Get-WriteSourceText)
        $wantW = if ($L -eq 'fr') { @('Lecteur qui écrit : A', 'Lecteur qui écrit : B', 'Lecteur qui écrit : TEAC FD-235HF (A)', 'Lecteur qui écrit : TEAC FD-235HF (0)') } else { @('Writing drive: A', 'Writing drive: B', 'Writing drive: TEAC FD-235HF (A)', 'Writing drive: TEAC FD-235HF (0)') }
        "  W ($L) : $($wTxt -join ' | ') ; --drive : $($wArg -join ' ')"
        Chk "W1$L" ((($wTxt -join '|') -ceq ($wantW -join '|')) -and (($wTxt -join '|') -ceq ($wExp -join '|')) -and (($wArg -join ' ') -ceq '--drive=A --drive=B --drive=A --drive=0')) "($L) le libelle suit le lecteur du bandeau (A, B, lecteur enregistre) et la connexion de sa fiche (A puis 0, sans changement du texte du bandeau), texte de Get-WriteSourceText ; il nomme le lecteur dont la connexion va a --drive (vraie Get-CommonArgs)"
        $capR = 8 + [System.Windows.Forms.TextRenderer]::MeasureText($grpWOpt.Text, $grpWOpt.Font).Width
        $wTip = [string]$tip.GetToolTip($lblWSource)
        $wTipWant = if ($L -eq 'fr') { "Lecteur choisi dans la liste « Lecteur : » du bandeau : c'est lui qui écrit la disquette. Le lecteur cible est celui qui la relira." } else { 'Drive selected in the "Drive:" list of the banner: it is the one that writes the disk. The target drive is the one that will read it back.' }
        Chk "W2$L" ($lblWSource.Font.Bold -and $lblWSource.Font.Name -eq 'Segoe UI' -and $lblWSource.Top -eq 0 -and $lblWSource.Right -eq $grpWOpt.DisplayRectangle.Right -and $wR1 -eq $grpWOpt.DisplayRectangle.Right -and $lblWSource.Left -ge $capR + 12 -and $lblWSource.Bottom -le $chkWPreErase.Top -and $lblWSource.Bottom -le $cmbWTarget.Top -and $lblWSource.Anchor -eq [System.Windows.Forms.AnchorStyles]'Top, Right' -and $wTip -ceq $wTipWant) "($L) libelle en gras sur la ligne du titre du cadre 2 (titre jusqu a $capR px), aligne sur son bord droit ($($lblWSource.Right) px, ancre a droite) apres chaque changement de texte, au-dessus de la rangee 1 et de la liste « Lecteur cible » ; infobulle de la specification"
        $cmbDrive.SelectedItem = 'A'; $script:DriveReg = [ordered]@{}; $cmbDrive.Items.Remove('TEAC FD-235HF')

        if ($L -eq 'fr') { '--- V : disposition (vraies Fit-ControlText et Set-WriteTabLayout, controles jamais affiches)' }
        # Textes les plus longs : case de la mesure (Update-WLevelUi, 140), cases des prechauffages et de --precomp
        # (Update-SlowUi, 140), lien (Update-WAdvLink, 145) ; noms les plus larges admis (Get-DriveWidestName, 112)
        $a140 = Get-Ast (Get-EoMod $Wt '140')
        function Get-EoAsgKeys($fnName, $var) {
            $fd = @($a140.FindAll({ param($x) $x -is $tFnA -and $x.Name -eq $fnName }, $false))[0]
            $ks = @()
            foreach ($as in $fd.Body.FindAll({ param($x) $x -is $tAsgA -and $x.Left.Extent.Text -eq "`$$var.Text" }, $true)) {
                foreach ($c in $as.Right.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'T' }, $true)) { $ks += [string]$c.CommandElements[1].Value }
            }
            return ,@($ks)
        }
        $codes = @('A', 'B', '0', '1', '2', '3')
        function Get-EoWidest($keys, $args1) {
            $best = ''; $bw = -1
            foreach ($k in $keys) { foreach ($a1 in $args1) { foreach ($a2 in $args1) {
                $t = (T $k) -f $a1, $a2
                $w = [System.Windows.Forms.TextRenderer]::MeasureText($t, $form.Font).Width
                if ($w -gt $bw) { $bw = $w; $best = $t }
            } } }
            return $best
        }
        $durs = @(for ($q = 1; $q -le 60; $q++) { Get-WarmMinutesText ($q / 2.0) })
        $longLevel = Get-EoWidest (Get-EoAsgKeys 'Update-WLevelUi' 'chkWLevel') $codes
        $longWarm = Get-EoWidest (Get-EoAsgKeys 'Update-SlowUi' 'chkWWarm') $durs
        $longCalWarm = Get-EoWidest (Get-EoAsgKeys 'Update-SlowUi' 'chkWCalWarm') $durs
        $longPc = Get-EoWidest (Get-EoAsgKeys 'Update-SlowUi' 'chkWPrecomp') @('')
        $links = @((T 'Options avancées…'), ((T 'Options avancées : {0} modifiée(s)…') -f '16'), (T 'Masquer les options avancées'))
        $wide = Get-DriveWidestName $form.Font
        $wide2 = $wide.Substring(0, $wide.Length - 1) + 'M'
        $vRows = @(); $vBad = @(); $vWrite = @{}; $vBottom = 0; $vAdvOk = $true
        foreach ($pw in @(792, 808)) {
            foreach ($case in @('lettre', 'noms')) {
                $cmbDrive.SelectedItem = 'A'
                $script:DriveReg = [ordered]@{}; $script:TargetDrives = @{}
                if ($cmbDrive.Items.Contains($wide)) { $cmbDrive.Items.Remove($wide) }
                if ($cmbDrive.Items.Contains($wide2)) { $cmbDrive.Items.Remove($wide2) }
                if ($case -eq 'noms') {
                    # Nom le plus large admis comme lecteur qui ecrit (sur A) et comme lecteur cible (sur 0)
                    $script:DriveReg[$wide] = @{ Name = $wide; Conn = 'A'; Id = 'L20261114-100001'; Created = '14/11/2026 10:00:01'; From = ''; At = '' }
                    $script:DriveReg[$wide2] = @{ Name = $wide2; Conn = '0'; Id = 'L20261114-100002'; Created = '14/11/2026 10:00:02'; From = ''; At = '' }
                    [void]$cmbDrive.Items.Add($wide); [void]$cmbDrive.Items.Add($wide2)
                    $script:TargetDrives[$wide] = $wide2
                    $cmbDrive.SelectedItem = $wide
                }
                Update-TargetDriveUi
                foreach ($view in @('simple', 'expert')) {
                    # Hauteur de la page : 516 px (journal masque) ; journal affiche, separateur a sa place par defaut : 338 px
                    # en mode courant, 312 px en mode expert (mesures du cas T2). L onglet defile quand son contenu depasse :
                    # sa barre verticale retire alors 17 px aux cadres, ancres a droite
                    $sv = ''
                    foreach ($ph in @(516, $(if ($view -eq 'expert') { 312 } else { 338 }))) {
                        $tabW.Size = New-Object System.Drawing.Size(782, 516)
                        $chkExpert.Checked = ($view -eq 'expert')
                        $tabW.Size = New-Object System.Drawing.Size($pw, $ph)
                        # Largeur changee apres la disposition (fenetre agrandie), puis disposition refaite a cette largeur
                        foreach ($pass in @('apres', 'refaite')) {
                            if ($pass -eq 'refaite') { $chkExpert.Checked = ($view -ne 'expert'); $chkExpert.Checked = ($view -eq 'expert') }
                            foreach ($li in $links) {
                                $chkWLevel.Text = $longLevel; $chkWWarm.Text = $longWarm; $chkWCalWarm.Text = $longCalWarm; $chkWPrecomp.Text = $longPc
                                $lnkWAdv.Text = $li
                                $b = Test-EoLayout ($view -eq 'expert')
                                foreach ($x in $b) { $vBad += "$L $pw x $ph $case $view $pass : $x" }
                            }
                            if (-not $vWrite.ContainsKey($view)) { $vWrite[$view] = @() }
                            $vWrite[$view] += "$($btnWrite.Bounds)"
                            if ($view -eq 'simple') { $bt = Get-EoBottom; if ($bt -gt $vBottom) { $vBottom = $bt } }
                            if ([bool]$grpWAdv.Visible -ne ($view -eq 'expert')) { $vAdvOk = $false }
                        }
                        $sv += " ; page $ph px : defilement $($tabW.VerticalScroll.Visible), cadre 2 jusqu a $($grpWOpt.DisplayRectangle.Right) px"
                    }
                    $vRows += "$L $pw $case $view : lecteur « $($lblWSource.Text) » $($lblWSource.Left)-$($lblWSource.Right) ; cible « $($cmbWTarget.Text) » $($cmbWTarget.Left)-$($cmbWTarget.Right) ; ECRIRE $($btnWrite.Bounds) ; options avancees $($grpWAdv.Bounds) visible $($grpWAdv.Visible)$sv"
                }
                Update-SlowUi; Update-WAdvLink
            }
        }
        $cmbDrive.SelectedItem = 'A'
        $script:DriveReg = [ordered]@{}; $script:TargetDrives = @{}
        foreach ($x in @($cmbDrive.Items)) { if ($codes -notcontains [string]$x) { $cmbDrive.Items.Remove($x) } }
        $chkExpert.Checked = $false; $tabW.Size = New-Object System.Drawing.Size(792, 516)
        Update-SlowUi; Update-WAdvLink
        foreach ($x in @($vRows | Where-Object { $_ -like "* 792 *" })) { "  V $x" }
        foreach ($x in @($vBad | Select-Object -First 10)) { "  V DEFAUT $x" }
        "  V ($L) : case de la mesure « $longLevel » ; prechauffage « $longWarm » ; nom le plus large « $wide » ($([System.Windows.Forms.TextRenderer]::MeasureText($wide, $form.Font).Width) px)"
        Chk "V1$L" ($vBad.Count -eq 0 -and $vRows.Count -eq 8) "($L) $($vRows.Count * 4) dispositions (pages de 792 et 808 px de large, de 516 px de haut et journal affiche, onglet qui defile compris ; lecteur A et noms les plus larges admis ; vue simple et mode expert ; largeur changee apres la disposition, puis disposition refaite), 3 textes du lien chacune : aucun texte coupe, aucun chevauchement, rien hors cadre ; defauts : $($vBad.Count)"
        $vw = @(@($vWrite['simple']) + @($vWrite['expert']) | Sort-Object -Unique)
        Chk "V2$L" ($vw.Count -eq 1 -and $btnWrite.Location -eq (New-Object System.Drawing.Point(10, 295))) "($L) bouton ECRIRE a la meme place dans les deux vues, dans chaque disposition : $($vw -join ' / ')"
        Chk "V3$L" ($vBottom -gt 0 -and $vBottom -le 370) "($L) bas de la vue simple : $vBottom px (370 au plus)"
        Chk "V4$L" ($vAdvOk) "($L) cadre des options avancees affiche avec « Mode expert » et masque sans elle, dans chaque disposition"
        $v5 = @(foreach ($c in @($pbWCal, $lblWCal, $btnWCalib, $btnWCross, $btnWCurve, $cmbWCalMode, $chkWLevel, $cmbWLevelMode, $cmbWTarget, $lblWSource)) { if (-not [object]::ReferenceEquals($c.Parent, $grpWOpt)) { Get-EoName $c } })
        $v5b = @(foreach ($v in $eoAdvBox) { $c = Get-Variable -Name $v -ValueOnly; if ($v -ne 'grpWAdv' -and -not [object]::ReferenceEquals($c.Parent, $grpWAdv)) { $v } })
        Chk "V5$L" ($v5.Count -eq 0 -and $v5b.Count -eq 0 -and $lblWCal.Left -eq 320 -and $lblWCal.Right -eq $grpWOpt.DisplayRectangle.Right -and [object]::ReferenceEquals($lblWProfileInfo.Parent, $grpWImage) -and [object]::ReferenceEquals($grpWAdv.Parent, $tabW)) "($L) progression, calibration, mesure et lecteurs dans le cadre 2 (hors du cadre : $(Get-List $v5)) ; lblWCal de 320 px au bord du cadre ($($lblWCal.Right)) ; options avancees dans leur cadre (hors : $(Get-List $v5b)) ; libelle du profil dans le cadre 1"

        if ($L -eq 'fr') { '--- A : options avancees (Get-WriteAdvDefs, Get-WriteAdvChanges, Update-WAdvLink)' }
        $aDefs = @(Get-WriteAdvDefs)
        $a1 = @(Get-WriteAdvChanges)
        $chkExpert.Checked = $true; $a1x = "$($lnkWAdv.Text)|$($lblWPlan.Text)"; $chkExpert.Checked = $false
        Chk "A1$L" ($aDefs.Count -eq 16 -and $a1.Count -eq 0 -and $lnkWAdv.Text -ceq (T 'Options avancées…') -and $lblWPlan.Text -eq '' -and $a1x -ceq ((T 'Masquer les options avancées') + '|')) "($L) reglages par defaut (Set-Defaults) : aucune des $($aDefs.Count) options avancees comptee ; lien « $($lnkWAdv.Text) », ligne vide ; mode expert : « $(($a1x -split '\|')[0]) »"
        # A2 : une option changee a la fois, dans les deux vues ; nom attendu : texte de la case, ou libelle et valeur
        $chg = [ordered]@{
            chkWEraseEmpty = @({ $chkWEraseEmpty.Checked = $false }, ((T '{0} : décochée') -f (T 'Effacer les pistes vides')))
            chkWNoVerify = @({ $chkWNoVerify.Checked = $true }, (T 'Sans vérification'))
            numWRetries = @({ $numWRetries.Value = 5 }, ((T 'Essais :') + ' 5'))
            numWRepair = @({ $numWRepair.Value = 1 }, ((T 'Passes de réécriture :') + ' 1'))
            cmbWProfile = @({ $cmbWProfile.SelectedIndex = 3 }, ((T 'Profil précomp. :') + ' ' + (T 'Manuel')))
            chkWPrecomp = @({ $chkWPrecomp.Checked = $false }, ((T '{0} : décochée') -f (T 'Précompensation (--precomp) :').TrimEnd(' ', ':')))
            txtWTracks = @({ $txtWTracks.Text = ' c=0-39 ' }, ((T 'Pistes :') + ' c=0-39'))
            cmbWDensel = @({ $cmbWDensel.SelectedIndex = 1 }, ((T 'Densel :') + ' H'))
            txtWFakeIdx = @({ $txtWFakeIdx.Text = '300rpm' }, ((T 'Fake index :') + ' 300rpm'))
            chkWReverse = @({ $chkWReverse.Checked = $true }, (T 'Face B flippy (--reverse)'))
            txtWDiskdefs = @({ $txtWDiskdefs.Text = 'x.cfg' }, ((T 'Diskdefs :') + ' x.cfg'))
            chkWHard = @({ $chkWHard.Checked = $true }, (T 'Secteurs durs (--hard-sectors)'))
            chkWTG43 = @({ $chkWTG43.Checked = $true }, (T 'TG43 lecteur 8 pouces (--gen-tg43)'))
            chkWWarm = @({ $chkWWarm.Checked = $false }, ((T '{0} : décochée') -f ((T "Préchauffer le lecteur avant l'écriture lente ({0} au plus de lecture sans écriture)") -f '5 min')))
            chkWCalWarm = @({ $chkWCalWarm.Checked = $false }, ((T '{0} : décochée') -f ((T "Préchauffer le lecteur avant la calibration complète ({0} au plus de lecture sans écriture)") -f '5 min')))
            numWWarmMin = @({ $numWWarmMin.Value = 2.5 }, ((T 'Durée du préchauffage :') + ' 2 min 30 s'))
        }
        $a2Bad = @(); $a2Ex = @()
        foreach ($k in @($chg.Keys)) {
            Invoke-EoDefaults
            & $chg[$k][0]
            $n = @(Get-WriteAdvChanges)
            $wantPlan = ((T 'options avancées : {0}') -f $chg[$k][1]); $wantPlan = $wantPlan.Substring(0, 1).ToUpper() + $wantPlan.Substring(1) + '.'
            $ls = $lnkWAdv.Text; $pl = $lblWPlan.Text
            $chkExpert.Checked = $true; $lx = $lnkWAdv.Text; $plx = $lblWPlan.Text; $nx = @(Get-WriteAdvChanges).Count; $chkExpert.Checked = $false
            if ($n.Count -ne 1 -or $n[0] -cne $chg[$k][1] -or $ls -cne ((T 'Options avancées : {0} modifiée(s)…') -f '1') -or $pl -cne $wantPlan -or $plx -cne $wantPlan -or $nx -ne 1 -or $lx -cne (T 'Masquer les options avancées')) { $a2Bad += "$k : « $($n -join ' / ') » ; lien « $ls » ; ligne « $pl »" }
            if ($k -in @('chkWEraseEmpty', 'txtWTracks', 'numWWarmMin')) { $a2Ex += "« $pl »" }
        }
        Invoke-EoDefaults
        "  A2 ($L) : $($a2Ex -join ' ; ')"
        Chk "A2$L" ($a2Bad.Count -eq 0 -and @(Get-WriteAdvChanges).Count -eq 0) "($L) chacune des 16 options changee seule : un nom (texte de la case, « : decochee » quand elle l est, ou libelle et valeur), compte du lien « 1 modifiee(s) » en vue simple, ligne qui la nomme dans les deux vues, valeur par defaut remise : plus rien ; ecarts : $(Get-List $a2Bad 3)"
        if ($L -eq 'fr') {
            # A3 : table egale aux defauts de Set-Defaults (120, arbre syntaxique) et de $script:SettingDefs (040) ; toutes les
            # options du cadre comptees (sauf les champs --precomp, remplis par le profil)
            $sdAsg = @{}
            $sdFn = @((Get-Ast (Get-EoMod $Wt '120')).FindAll({ param($x) $x -is $tFnA -and $x.Name -eq 'Set-Defaults' }, $false))[0]
            foreach ($s in $sdFn.Body.EndBlock.Statements) { if ($s -is $tAsgA -and $s.Left.Extent.Text -match '^\$(\w+)\.(Checked|Value|Text|SelectedIndex)$') { $sdAsg[$Matches[1]] = $s.Right.Extent.Text } }
            $a3Bad = @()
            foreach ($d in $aDefs) {
                $vn = Get-EoName $d.Ctl
                $exp = $null
                switch ($vn) {
                    'cmbWProfile' { $exp = [array]::IndexOf([string[]]$script:SettingDefs['precompProfile'].Codes, [string]$script:SettingDefs['precompProfile'].Def) }
                    'chkWWarm' { $exp = [bool]$script:SettingDefs['warmSlowWrite'].Def }
                    'chkWCalWarm' { $exp = [bool]$script:SettingDefs['warmFullCalib'].Def }
                    'numWWarmMin' { $exp = [double]$script:SettingDefs['warmMinutes'].Def }
                    default {
                        if (-not $sdAsg.ContainsKey($vn)) { $a3Bad += "$vn absent de Set-Defaults"; continue }
                        $r = $sdAsg[$vn]
                        if ($r -eq '$true') { $exp = $true } elseif ($r -eq '$false') { $exp = $false } elseif ($r -eq "''") { $exp = '' } elseif ($r -match '^\d+$') { $exp = [int]$r } else { $a3Bad += "$vn : $r" }
                    }
                }
                if ($null -ne $exp -and [string]$exp -ne [string]$d.Def) { $a3Bad += "$vn : table $($d.Def), attendu $exp" }
            }
            $inBox = @(foreach ($c in @($grpWAdv.Controls)) { if ($c -is [System.Windows.Forms.CheckBox] -or $c -is [System.Windows.Forms.NumericUpDown] -or $c -is [System.Windows.Forms.ComboBox] -or $c -is [System.Windows.Forms.TextBox]) { Get-EoName $c } })
            $inTab = @($aDefs | ForEach-Object { Get-EoName $_.Ctl })
            $notCounted = @($inBox | Where-Object { $inTab -notcontains $_ -and @('txtWPrecomp', 'txtWPrecomp1') -notcontains $_ })
            Chk 'A3' ($a3Bad.Count -eq 0 -and $notCounted.Count -eq 0 -and (($inTab | Sort-Object) -join ',') -ceq (($eoAdv | Sort-Object) -join ',')) "Get-WriteAdvDefs : $($aDefs.Count) options, valeurs par defaut egales a Set-Defaults (arbre syntaxique de 120) et, pour le profil, les prechauffages et leur duree, a `$script:SettingDefs (040) ; toutes les options du cadre comptees, sauf les champs --precomp ; ecarts : $(Get-List ($a3Bad + $notCounted))"
        }
        # A4 : les 16 changees ensemble : compte, noms dans l ordre du cadre, ligne trop longue : infobulle du texte complet
        Invoke-EoDefaults
        foreach ($k in @($chg.Keys)) { & $chg[$k][0] }
        $a4 = @(Get-WriteAdvChanges)
        $a4Tip = [string]$tip.GetToolTip($lblWPlan)
        $a4H = $lblWPlan.GetPreferredSize((New-Object System.Drawing.Size($lblWPlan.Width, 0))).Height
        # Ensemble, la duree de 2 min 30 s passe dans le texte des deux cases de prechauffage (Update-SlowUi)
        $a4Want = @($chg.Keys | ForEach-Object { ([string]$chg[$_][1]).Replace('5 min ', '2 min 30 s ') })
        Chk "A4$L" ($a4.Count -eq 16 -and $lnkWAdv.Text -ceq ((T 'Options avancées : {0} modifiée(s)…') -f '16') -and ($a4 -join '|') -ceq ($a4Want -join '|') -and $a4H -gt $lblWPlan.Height -and $a4Tip -ceq $lblWPlan.Text -and $lblWPlan.AutoEllipsis) "($L) les 16 options changees : « $($lnkWAdv.Text) », noms dans l ordre du cadre (duree du prechauffage reprise par le texte des cases) ; ligne de $a4H px pour $($lblWPlan.Height) : points de suspension et texte complet en infobulle (Update-WPlanTip)"
        Invoke-EoDefaults
        $a4b = [string]$tip.GetToolTip($lblWPlan)
        # A5 : lien : inverse « Mode expert » (vraie Switch-WAdvView), sans effet quand la case est inactive, inactif avec elle
        $z = @()
        Switch-WAdvView; $z += "$($chkExpert.Checked)/$($grpWAdv.Visible)/$($lnkWAdv.Text)"
        Switch-WAdvView; $z += "$($chkExpert.Checked)/$($grpWAdv.Visible)/$($lnkWAdv.Text)"
        $chkExpert.Enabled = $false; Switch-WAdvView; $z += "$($chkExpert.Checked)/$($lnkWAdv.Enabled)"
        $chkExpert.Enabled = $true; $z += "$($lnkWAdv.Enabled)"
        $zWant = @("True/True/$(T 'Masquer les options avancées')", "False/False/$(T 'Options avancées…')", 'False/False', 'True')
        Chk "A5$L" (($z -join ' ; ') -ceq ($zWant -join ' ; ') -and $a4b -eq '') "($L) lien : « Mode expert » coche puis decoche, cadre affiche puis masque, texte du lien ; case inactive (restauration) : clic sans effet, lien inactif, puis actif de nouveau : $($z -join ' ; ')"
        $eoRes[$key].Snap1 = (Get-EoSnap)
        # E1 (vues) : changer de vue ne change aucune valeur
        foreach ($k in @($chg.Keys)) { & $chg[$k][0] }
        $s1 = (Get-EoSnap); $chkExpert.Checked = $true; $s2 = (Get-EoSnap); Switch-WAdvView; $s3 = (Get-EoSnap)
        $eoRes[$key].ViewSame = ((($s1 -join "`n") -ceq ($s2 -join "`n")) -and (($s2 -join "`n") -ceq ($s3 -join "`n")))
        Invoke-EoDefaults
    }
}

'--- E : equivalence avec la source d avant le lot'
$rf = $eoRes['eo-fr']
$e1Same = (($rf.Snap0 -join "`n") -ceq ($rf.Snap1 -join "`n"))
Chk 'E1' ($rf.ViewSame -and $eoRes['eo-en'].ViewSame -and $e1Same -and $rf.Snap0.Count -eq 36) "valeurs, textes, noms, etats et infobulles des 36 controles : identiques apres les changements de vue (16 options changees, mode expert coche puis decoche par le lien), en francais et en anglais ; demarrage identique avant et apres les cas W, V et A"
if ($Before) {
    $ra = $eoRes['avant-fr']
    $sb = @(); for ($i = 0; $i -lt 36; $i++) { if ($ra.Snap0[$i] -cne $rf.Snap0[$i]) { $sb += "$($ra.Snap0[$i]) => $($rf.Snap0[$i])" } }
    foreach ($x in @($sb | Select-Object -First 4)) { "  E1b ECART $x" }
    Chk 'E1b' ($sb.Count -eq 0) "-Before : valeurs, textes, noms, etats, elements et infobulles des 36 controles au demarrage identiques a ceux de la source d avant ; ecarts : $($sb.Count)"
} else { '  E1b saute (sans -Before)' }
$e2Bad = @(); $e2Hash = @{}; $e2Diff = @()
foreach ($sc in $eoScn) {
    $t = $rf.E[$sc.Id]; $tx = $rf.EX[$sc.Id]
    $txt = ($t.Trace -join "`n")
    $e2Hash[$sc.Id] = Get-EoSha $txt 16
    if ($txt -cne ($tx.Trace -join "`n") -or ($t.Log -join "`n") -cne ($tx.Log -join "`n")) { $e2Diff += $sc.Id }
    if (@($t.Trace | Where-Object { $_ -like 'ERREUR*' }).Count) { $e2Bad += "$($sc.Id) : $(@($t.Trace | Where-Object { $_ -like 'ERREUR*' })[0])" }
    if ($eoE2Ref.Count -and $eoE2Ref[$sc.Id] -cne $e2Hash[$sc.Id]) { $e2Bad += "$($sc.Id) : empreinte $($e2Hash[$sc.Id]), attendu $($eoE2Ref[$sc.Id])" }
}
foreach ($sc in @($eoScn | Select-Object -First 2)) { foreach ($x in $rf.E[$sc.Id].Trace) { "  $($sc.Id) $x" } }
foreach ($sc in @($eoScn | Where-Object { $_.Id -in @('E13', 'E16', 'E17', 'E18') })) { foreach ($x in $rf.E[$sc.Id].Trace) { "  $($sc.Id) $x" } }
"  E2 : empreintes (a recopier dans `$eoE2Ref si les commandes changent a dessein) : $((@($eoScn | ForEach-Object { "$($_.Id)=$($e2Hash[$_.Id])" })) -join ' ')"
Chk 'E2' ($e2Bad.Count -eq 0 -and $e2Diff.Count -eq 0 -and $eoE2Ref.Count -eq $eoScn.Count) "$($eoScn.Count) configurations (rapide, lente, chaque option avancee, toutes ensemble, mesure, test rapide, IMG ibm.720) : commandes gw, file d ecriture, controle, prechauffage et mesure de la vraie Start-WriteTabWrite identiques en vue simple et en mode expert (journal compris : ecarts $($e2Diff.Count)) et egales a celles de d8d80d6 (empreintes) ; ecarts : $(Get-List $e2Bad 3)"
if ($Before) {
    $ra = $eoRes['avant-fr']
    $eb = @()
    foreach ($sc in $eoScn) {
        $a = $ra.E[$sc.Id]; $n = $rf.E[$sc.Id]
        if (($a.Trace -join "`n") -cne ($n.Trace -join "`n")) { $eb += "$($sc.Id) commandes" }
        if (($a.Log -join "`n") -cne ($n.Log -join "`n")) { $eb += "$($sc.Id) journal" }
    }
    Chk 'E2b' ($eb.Count -eq 0) "-Before : pour les $($eoScn.Count) configurations, commandes, demandes et journal identiques ligne a ligne a ceux de la source d avant ; ecarts : $(Get-List $eb)"
} else { '  E2b saute (sans -Before)' }

'--- T : barre d onglets (TabControl reel, poignee creee sans fenetre visible)'
$eoG = New-EoGen $Wt 'eo'
$tabVars = @()
foreach ($px in @('510', '520', '530', '540')) {
    foreach ($s in (Get-Ast (Get-EoMod $Wt $px)).EndBlock.Statements) {
        $t = $s.Extent.Text
        if ($t -match "^\`$(tab\w+) = New-TabPage \(T '([^']+)'\)$") { $tabVars += @{ Var = $Matches[1]; Key = $Matches[2]; T = $true } }
        elseif ($t -match "^\`$(tab\w+) = New-TabPage '([^']+)'$") { $tabVars += @{ Var = $Matches[1]; Key = $Matches[2]; T = $false } }
    }
}
$allSt = [string]@((Get-Ast (Get-EoMod $Wt '540')).EndBlock.Statements | Where-Object { $_.Extent.Text -match '^\$script:AllTabs = ' })[0].Extent.Text
$novSt = [string]@((Get-Ast (Get-EoMod $Wt '540')).EndBlock.Statements | Where-Object { $_.Extent.Text -match '^\$script:NoviceTabs = ' })[0].Extent.Text
$allV = @([regex]::Matches($allSt, '\$(tab\w+)') | ForEach-Object { $_.Groups[1].Value })
$novV = @([regex]::Matches($novSt, '\$(tab\w+)') | ForEach-Object { $_.Groups[1].Value })
$tRows = @(); $tH = @{}
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    foreach ($set in @(@{ N = 11; V = $allV }, @{ N = 6; V = $novV })) {
        foreach ($h in @(546, 372)) {
            . $eoG.Tabs
            $tabs.Dock = 'None'; $tabs.Font = $form.Font; $tabs.Size = New-Object System.Drawing.Size(800, $h)
            foreach ($tv in $tabVars) { Set-Variable -Name $tv.Var -Value (New-TabPage $(if ($tv.T) { T $tv.Key } else { $tv.Key })) }
            . $eoG.Ico
            foreach ($v in $set.V) { $tabs.TabPages.Add((Get-Variable -Name $v -ValueOnly)) }
            # Poignee creee sans fenetre visible : le nombre de rangees et la page ne se lisent qu avec elle
            $tErr = ''
            try { $null = $tabs.Handle } catch { $tErr = $_.Exception.Message }
            $dr = $tabs.DisplayRectangle
            $tRows += @{ L = $lg; N = $set.N; H = $h; Rows = $(if ($tErr) { -1 } else { $tabs.RowCount }); Multi = $tabs.Multiline; PageH = $dr.Height; PageW = $dr.Width; Err = $tErr }
            $tabs.Dispose()
        }
    }
}
$script:Lang = 'fr'
foreach ($r in $tRows) { "  T $($r.L) : $($r.N) onglets, barre de $($r.H) px : $($r.Rows) rangee(s), page $($r.PageW) x $($r.PageH)$(if ($r.Err) { " ; poignee non creee : $($r.Err)" })" }
$t1 = @($tRows | Where-Object { -not $_.Multi -or ($_.N -eq 11 -and $_.Rows -ne 2) -or ($_.N -eq 6 -and $_.Rows -ne 1) })
Chk 'T1' ($tRows.Count -eq 8 -and $t1.Count -eq 0 -and $allV.Count -eq 11 -and $novV.Count -eq 6) "instructions reelles de 510 (Multiline) et de 540 (icones), fenetre de 800 px : mode expert, 11 onglets sur 2 rangees ; mode courant, 6 onglets sur 1 rangee, en francais et en anglais"
$p6 = @($tRows | Where-Object { $_.N -eq 6 -and $_.H -eq 372 }); $p11 = @($tRows | Where-Object { $_.N -eq 11 -and $_.H -eq 372 })
$t2 = @($p6 | Where-Object { $_.PageH -lt $btnWrite.Bottom })
"  T2 : journal affiche (zone des onglets de 372 px, separateur a sa place par defaut, 510) : page de $(@($p6 | ForEach-Object { $_.PageH }) -join '/') px en mode courant, $(@($p11 | ForEach-Object { $_.PageH }) -join '/') px en mode expert ; bas du bouton ECRIRE a $($btnWrite.Bottom) px"
Chk 'T2' ($p6.Count -eq 2 -and $t2.Count -eq 0 -and $btnWrite.Bottom -eq 335) "journal affiche, mode courant : le bouton ECRIRE (bas a $($btnWrite.Bottom) px) tient dans la page sans defilement, en francais et en anglais ; mode expert : l onglet defile (dit au CHANGELOG)"

'--- D : CHANGELOG et README'
$ch = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
$sec = ''; $mm = [regex]::Match($ch, '(?s)## \[12\.11\].*?(?=\n## \[)'); if ($mm.Success) { $sec = $mm.Value }
$nouv = ''; $mn = [regex]::Match($sec, '(?s)### Nouveautés.*?(?=\n### )'); if ($mn.Success) { $nouv = $mn.Value }
$amel = ''; $ma = [regex]::Match($sec, '(?s)### Améliorations.*?(?=\n### )'); if ($ma.Success) { $amel = $ma.Value }
$corr = ''; $mc = [regex]::Match($sec, '(?s)### Corrections.*?(?=\n### )'); if ($mc.Success) { $corr = $mc.Value }
$sav = ''; $ms = [regex]::Match($sec, '(?s)### À savoir pour la mise à jour.*?(?=\n### )'); if ($ms.Success) { $sav = $ms.Value }
$dev = ''; $md = [regex]::Match($sec, '(?s)### Pour les développeurs.*$'); if ($md.Success) { $dev = $md.Value }
$d1 = [ordered]@{
    'nouveaute' = $nouv.Contains('**Onglet « Écriture » en trois étapes.**')
    'lecteur qui ecrit' = $nouv.Contains("L'onglet affiche le lecteur qui écrit, au-dessus de la liste « Lecteur cible ».")
    'seize commandes' = $nouv.Contains('seize commandes au lieu de trente-cinq')
    'options avancees' = $amel.Contains('**Options avancées repliées, comptées et nommées.**')
    'reperes' = $corr.Contains('« Fake index » et « Diskdefs »')
    'deux rangees' = $corr.Contains('**Mode expert : onglets sur deux rangées.**')
    'a savoir' = $sav.Contains('**Onglet « Écriture » réorganisé.**')
    'module 145' = $dev.Contains('`145-fn-onglet-ecriture.ps1`')
    'decision' = $dev.Contains('`Get-WriteAdvChanges`')
    'retour L7' = $nouv.Contains("Dans les options avancées de l'onglet « Écriture », un bouton à côté de « Effacer les calibrations »")
    'materiel' = ($sec -notmatch 'vérifiée? sur (du )?matériel')
    # 12.11 (lot L10) : entree « Ce qui va se passer » attendue (jusqu au lot L10, ce cas attendait son absence)
    'L10' = $nouv.Contains('**Ligne « Ce qui va se passer ».**')
}
$d1Bad = @($d1.Keys | Where-Object { -not $d1[$_] })
Chk 'D1' ($d1Bad.Count -eq 0) "CHANGELOG 12.11 : Nouveautes (trois etapes, seize commandes, lecteur qui ecrit au-dessus de la liste « Lecteur cible » ; l entree du lot L7, « dans les options avancees ... a cote de « Effacer les calibrations » », vraie depuis ce lot), Ameliorations (options avancees repliees, comptees et nommees), Corrections (reperes « Fake index » et « Diskdefs », deux rangees d onglets), A savoir (onglet reorganise), Pour les developpeurs (module 145, Get-WriteAdvChanges) ; ligne « Ce qui va se passer » du lot L10 annoncee, aucun texte ne dit un comportement verifie sur materiel ; ecarts : $(Get-List $d1Bad)"
$rd = [System.IO.File]::ReadAllText((Join-Path $mods 'README.md'), [System.Text.Encoding]::UTF8)
$trd = [System.IO.File]::ReadAllText((Join-Path $Wt 'tests\README.md'), [System.Text.Encoding]::UTF8)
$fn145 = @((Get-Ast (Get-EoMod $Wt '145')).FindAll({ param($x) $x -is $tFnA }, $false) | ForEach-Object { $_.Name })
$rd145 = ''; $mr = [regex]::Match($rd, '\| `145-fn-onglet-ecriture\.ps1` \|[^\n]*'); if ($mr.Success) { $rd145 = $mr.Value }
$noDoc = @($fn145 | Where-Object { -not $rd145.Contains("``$_``") })
Chk 'D2' ($fn145.Count -ge 8 -and $noDoc.Count -eq 0 -and $trd.Contains('| `logic-ecriture-onglet` |') -and $trd.Contains('Set-WriteTabLayout')) "README des modules : ligne de 145 qui cite ses $($fn145.Count) fonctions (absentes : $(Get-List $noDoc)) ; README des tests : ligne de logic-ecriture-onglet completee"

$nk = ''; if ($script:Fail) { $nk = ' ; non conformes : ' + (@($script:FailIds) -join ', ') }
"=== bilan logic-ecriture-onglet : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
