param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.12 (interface, lot A) : cadre de la nouvelle interface (100, 500, 540, 600).
#  N1  rubriques du rail (instruction reelle de 540) : chaque page attachee appartient a une rubrique et une seule, la
#      premiere page d une rubrique est sa page d entree ; sans le mode expert, seules « Delais » et « Commande libre »
#      manquent.
#  N2  Get-NavKey, Show-NavPage et Update-NavRail reels, sur de vrais controles jamais affiches : page d entree de chaque
#      rubrique, rubrique en evidence, titre de la page, lien de retour pour une page qui n est pas la page d entree, journal.
#  N3  New-NavButton et New-TaskCard reels : nom, etiquette, action au clic sur toute la carte (comme une carte de l Accueil).
#  N4  page « Disquettes » : les six taches ouvrent les pages existantes ; pages provisoires « Lecteurs » et « Parametres » :
#      actions des cartes de l Accueil reprises telles quelles.
#  N5  fenetre et assemblage (statique) : 1 000 x 700, taille minimale elargie du rail, en-tetes des onglets masques, rail
#      ancre a la fenetre avant les barres du bas, bande de titre au-dessus des pages, page de demarrage.
# Fonctions reelles extraites par l arbre syntaxique ; aucun gw, aucune fenetre affichee.
# Non couvert ici : le rendu de la fenetre entiere (controle hors depot, image par image).
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Set-TestCulture
Import-TestWinForms
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mods = Join-Path $Wt 'src\modules'
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
$tFn = [System.Management.Automation.Language.FunctionDefinitionAst]
function Get-IcAst([string]$path) {
    $tk = $null; $er = $null
    $a = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message)" }
    return $a
}
function Get-IcMod([string]$px) { return @(Get-ChildItem -LiteralPath $mods -Filter "$px-*.ps1" -File)[0].FullName }
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'
$st540 = @((Get-IcAst (Get-IcMod '540')).EndBlock.Statements | ForEach-Object { [string]$_.Extent.Text })
$st500 = @((Get-IcAst (Get-IcMod '500')).EndBlock.Statements | ForEach-Object { [string]$_.Extent.Text })
$st600 = @((Get-IcAst (Get-IcMod '600')).EndBlock.Statements | ForEach-Object { [string]$_.Extent.Text })
$fn100 = @{}
foreach ($fd in (Get-IcAst (Get-IcMod '100')).FindAll({ param($x) $x -is $tFn }, $false)) { $fn100[$fd.Name] = $fd.Extent.Text }
$load = @('Get-NavKey', 'New-NavButton', 'Show-NavPage', 'Update-NavRail', 'New-TaskCard', 'Get-HomeCard', 'New-GlyphBitmap')
$miss = @($load | Where-Object { -not $fn100.ContainsKey($_) })
if ($miss.Count) { throw "fonctions introuvables : $($miss -join ', ')" }
$gen = Join-Path $here 'gen-interface-cadre.ps1'
[System.IO.File]::WriteAllText($gen, ((@($load | ForEach-Object { $fn100[$_] }) -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
. $gen

'--- N. rubriques et rail'
function Get-IcVars([string]$text) { return @([regex]::Matches($text, '\$(tab\w+)') | ForEach-Object { $_.Groups[1].Value }) }
$allV = Get-IcVars ([string]@($st540 | Where-Object { $_ -match '^\$script:AllTabs = ' })[0])
$novV = Get-IcVars ([string]@($st540 | Where-Object { $_ -match '^\$script:NoviceTabs = ' })[0])
$navSt = [string]@($st540 | Where-Object { $_ -match '^\$script:NavPages = ' })[0]
$nav = [ordered]@{}
foreach ($m in [regex]::Matches($navSt, '(\w+) = @\(([^)]*)\)')) { $nav[$m.Groups[1].Value] = @(Get-IcVars $m.Groups[2].Value) }
$inNav = @(foreach ($k in @($nav.Keys)) { $nav[$k] })
$dup = @($inNav | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
$out = @($allV | Where-Object { $inNav -notcontains $_ }); $ext = @($inNav | Where-Object { $allV -notcontains $_ })
$novMiss = @($allV | Where-Object { $novV -notcontains $_ } | Sort-Object)
$first = (@($nav.Keys | ForEach-Object { "$_=$($nav[$_][0])" }) -join ' ')
Chk 'N1' ($allV.Count -eq 14 -and $inNav.Count -eq 14 -and $dup.Count -eq 0 -and $out.Count -eq 0 -and $ext.Count -eq 0 -and ($novMiss -join ',') -ceq 'tabC,tabD' -and (@($nav.Keys) -join ',') -ceq 'Lib,Disk,Drives,Set,Help' -and $first -ceq 'Lib=tabL Disk=tabDk Drives=tabDr Set=tabSet Help=tabH') "$($allV.Count) pages attachees, $($inNav.Count) dans les rubriques $(@($nav.Keys) -join ', ') : aucune page hors rubrique ($($out -join ',')), aucune en double ($($dup -join ',')) ; pages d entree : $first ; sans le mode expert, absentes : $($novMiss -join ', ')"

# Monde de test : vrais controles, jamais affiches ; pages nommees comme les variables de l application
$script:Theme = @{ Accent = [System.Drawing.Color]::FromArgb(37, 99, 168); Accent2 = [System.Drawing.Color]::FromArgb(22, 54, 98); Muted = [System.Drawing.Color]::FromArgb(110, 116, 128); Page = [System.Drawing.Color]::White }
$script:IconFont = $null; $script:Glyph = @{}
$script:NavBack = [System.Drawing.Color]::FromArgb(243, 245, 249); $script:NavSel = [System.Drawing.Color]::FromArgb(226, 236, 250)
$tabs = New-Object System.Windows.Forms.TabControl
$pg = @{}
foreach ($v in $allV) { $p = New-Object System.Windows.Forms.TabPage; $p.Text = "page $v"; $pg[$v] = $p; $tabs.TabPages.Add($p) }
$script:NavPages = [ordered]@{}
foreach ($k in @($nav.Keys)) { $script:NavPages[$k] = @($nav[$k] | ForEach-Object { $pg[$_] }) }
$split = New-Object System.Windows.Forms.SplitContainer
$script:LogCalls = New-Object System.Collections.Generic.List[string]
function Set-LogVisible([bool]$visible) { $script:LogCalls.Add("$visible"); $split.Panel2Collapsed = -not $visible }
function Show-Tab($page) { $tabs.SelectedTab = $page }
function Clear-HomeProgress { $script:Cleared++ }
$lblPageTitle = New-Object System.Windows.Forms.Label; $lblPageTitle.AutoSize = $true
$lnkPageBack = New-Object System.Windows.Forms.LinkLabel; $lnkPageBack.AutoSize = $true; $lnkPageBack.Location = New-Object System.Drawing.Point(12, 8)
$script:NavButtons = @(foreach ($k in @($nav.Keys)) { New-NavButton $k 'Help' "rubrique $k" })

$keys = (@($allV | ForEach-Object { "$_=$(Get-NavKey $pg[$_])" }) -join ' ')
$wantKeys = (@($allV | ForEach-Object { $v = $_; "$v=$(@($nav.Keys | Where-Object { $nav[$_] -contains $v })[0])" }) -join ' ')
$n2 = @()
foreach ($k in @($nav.Keys)) {
    Show-NavPage $k
    $on = @($script:NavButtons | Where-Object { $_.Tag.On } | ForEach-Object { [string]$_.Tag.Key })
    if ($tabs.SelectedTab -ne $pg[$nav[$k][0]] -or ($on -join ',') -cne $k -or $lblPageTitle.Text -cne "page $($nav[$k][0])" -or $lnkPageBack.Visible) { $n2 += "entree $k" }
    foreach ($v in @($nav[$k] | Select-Object -Skip 1)) {
        $tabs.SelectedTab = $pg[$v]; Update-NavRail
        $on = @($script:NavButtons | Where-Object { $_.Tag.On } | ForEach-Object { [string]$_.Tag.Key })
        if (($on -join ',') -cne $k -or $lblPageTitle.Text -cne "page $v" -or -not $lnkPageBack.Visible -or $lnkPageBack.Text -cne ('‹ ' + "page $($nav[$k][0])") -or [string]$lnkPageBack.Tag -cne $k -or $lblPageTitle.Left -le $lnkPageBack.Left) { $n2 += "page $v" }
    }
}
$selBtn = @($script:NavButtons | Where-Object { $_.Tag.On })[0]
$styleOk = ($selBtn.BackColor.ToArgb() -eq $script:NavSel.ToArgb() -and $selBtn.Font.Name -ceq 'Segoe UI Semibold' -and @($script:NavButtons | Where-Object { -not $_.Tag.On -and $_.BackColor.ToArgb() -ne $script:NavBack.ToArgb() }).Count -eq 0)
$before = $tabs.SelectedTab; $split.Panel2Collapsed = $false
Show-NavPage 'Log'; $l1 = $split.Panel2Collapsed; Show-NavPage 'Log'; $l2 = $split.Panel2Collapsed
$none = (Get-NavKey (New-Object System.Windows.Forms.TabPage))
Chk 'N2' ($keys -ceq $wantKeys -and $n2.Count -eq 0 -and $styleOk -and $l1 -and -not $l2 -and ($script:LogCalls -join ',') -ceq 'False,True' -and $tabs.SelectedTab -eq $before -and $none -ceq '') "rubrique de chaque page ($($keys -ceq $wantKeys)) ; chaque rubrique ouvre sa page d entree, se met en evidence, donne le titre de la page ; une autre page de la rubrique montre le lien de retour vers la page d entree (ecarts : $(if ($n2.Count) { $n2 -join ', ' } else { 'aucun' })) ; style de l entree choisie ($styleOk) ; « Journal » masque puis montre le journal sans changer de page ($($script:LogCalls -join ',')) ; page hors rubrique : aucune rubrique"

$script:Cleared = 0; $script:Hit = ''
$card = New-TaskCard 'Help' 'Titre' 'Description de la tâche.' '14,66' { $script:Hit = 'action' }
$kids = @($card.Controls | ForEach-Object { $_.GetType().Name })
$viaChild = (Get-HomeCard $card.Controls[1])
& $card.Tag
$b0 = $script:NavButtons[0]
$n3t = $fn100['New-TaskCard']
Chk 'N3' ($card.Name -ceq 'HomeCard' -and $card.Size.Width -eq 250 -and $card.Size.Height -eq 120 -and ($kids -join ',') -ceq 'PictureBox,Label,Label' -and $viaChild -eq $card -and $script:Hit -ceq 'action' -and $n3t.Contains('$c.Add_Click({ $card = Get-HomeCard $this; if ($card -and $card.Tag) { Clear-HomeProgress; & $card.Tag } })') -and $b0.Name -ceq 'btnNavLib' -and $b0.Text.Trim() -ceq 'rubrique Lib' -and [string]$b0.Tag.Key -ceq 'Lib' -and [string]$b0.FlatStyle -ceq 'Flat' -and $b0.Width -eq 148) "carte de tache : nommee comme une carte de l Accueil (clic sur toute la carte, par Get-HomeCard), 250 x 120, icone, titre et description, action gardee dans son Tag ; entree du rail : $($b0.Name), bouton plat de $($b0.Width) px, rubrique dans son Tag"

'--- pages et assemblage'
function Get-IcCard([string]$var) { return [string]@($st540 | Where-Object { $_.StartsWith('$' + $var + ' ') -or $_.StartsWith('$' + $var + '=') })[0] }
$tasks = [ordered]@{ cardDkRead = '{ Show-Tab $tabR }'; cardDkRestore = '{ Show-Tab $tabRs }'; cardDkCheck = '{ Show-Tab $tabAl }'; cardDkCompare = '{ Show-Tab $tabCmp }'; cardDkConvert = '{ Show-Tab $tabCv }'; cardDkClean = '{ Show-CleanDialog }' }
$n4a = @(foreach ($k in @($tasks.Keys)) { $t = Get-IcCard $k; if (-not $t -or $t -notmatch '^\$' + $k + '\s+= New-TaskCard ' -or -not $t.EndsWith($tasks[$k])) { $k } })
$reuse = [ordered]@{ cardDrList = '$cardDrives.Tag'; cardDrCalib = '$cardCalib.Tag'; cardDrTest = '$cardTest.Tag'; cardDrClean = '$cardClean.Tag'; cardSetJitter = '$cardJitter.Tag'; cardSetTools = '{ Show-Tab $tabT }'; cardSetDelays = '{ Show-Tab $tabD }'; cardSetCmd = '{ Show-Tab $tabC }' }
$n4b = @(foreach ($k in @($reuse.Keys)) { $t = Get-IcCard $k; if (-not $t -or $t -notmatch '^\$' + $k + '\s+= New-HomeCard ' -or -not $t.EndsWith($reuse[$k])) { $k } })
$dkAdd = [string]@($st540 | Where-Object { $_.StartsWith('$tabDk.Controls.AddRange(') })[0]
$n4c = (@($tasks.Keys | Where-Object { -not $dkAdd.Contains('$' + $_) }).Count -eq 0 -and $dkAdd.Contains('$lnkDkWrite') -and @($st540 | Where-Object { $_ -ceq '$lnkDkWrite.Add_LinkClicked({ Show-Tab $tabW })' }).Count -eq 1)
Chk 'N4' ($n4a.Count -eq 0 -and $n4b.Count -eq 0 -and $n4c) "page « Disquettes » : six cartes de tache, chacune avec l action attendue (Sauvegarder, Restaurer, Verifier, Comparer, Convertir vers leurs pages ; Nettoyer vers la procedure de nettoyage ; en ecart : $(if ($n4a.Count) { $n4a -join ', ' } else { 'aucune' })), lien vers la page d ecriture ($n4c) ; pages provisoires : actions des cartes de l Accueil reprises par leur Tag, pages techniques ouvertes par Show-Tab (en ecart : $(if ($n4b.Count) { $n4b -join ', ' } else { 'aucune' }))"

$i500 = @($st500 | Where-Object { $_ -match '^\$form\.(ClientSize|MinimumSize) = ' })
$iHide = @($st540 | Where-Object { $_ -match '^\$tabs\.(Multiline = \$false|Appearance = ''FlatButtons''|SizeMode = ''Fixed''|ItemSize = New-Object System\.Drawing\.Size\(0, 1\))$' })
$adds = @($st540 | Where-Object { $_ -match '^\$form\.Controls\.Add\(\$(\w+)\)$' } | ForEach-Object { [regex]::Match($_, '\$(\w+)\)$').Groups[1].Value })
$p1 = @($st540 | Where-Object { $_ -match '^\$split\.Panel1\.Controls\.Add\(\$(\w+)\)$' } | ForEach-Object { [regex]::Match($_, '\$(\w+)\)$').Groups[1].Value })
$rail = @($st540 | Where-Object { $_ -match '^\$pnlRail\.(Dock = ''Left''|Width = 148)$' })
$bar = @($st540 | Where-Object { $_ -match '^\$pnlPageBar\.(Dock = ''Top''|Height = 34)$' })
$ev = @($st540 | Where-Object { $_ -ceq '$tabs.Add_SelectedIndexChanged({ Update-NavRail })' })
$i600 = [array]::IndexOf($st600, 'Update-TabSet')
$start = ($i600 -ge 0 -and $i600 + 2 -lt $st600.Count -and $st600[$i600 + 1] -ceq 'if ($txtLibRoot.Text.Trim()) { $tabs.SelectedTab = $tabL }' -and $st600[$i600 + 2] -ceq 'Update-NavRail')
Chk 'N5' (($i500 -join ' | ') -ceq '$form.ClientSize = New-Object System.Drawing.Size(1000, 700) | $form.MinimumSize = New-Object System.Drawing.Size(964, 620)' -and $iHide.Count -eq 4 -and ($adds -join ',') -ceq 'pnlRail,flowButtons,status,pnlTop,split' -and ($p1 -join ',') -ceq 'tabs,pnlPageBar' -and $rail.Count -eq 2 -and $bar.Count -eq 2 -and $ev.Count -eq 1 -and $start) "fenetre de 1 000 x 700, au moins 964 x 620 ; en-tetes des onglets masques ($($iHide.Count) instructions) ; rail de 148 px ancre a gauche de la fenetre, ajoute avant les barres du bas, le bandeau et le volet des pages ($($adds -join ', ')) ; volet des pages : $($p1 -join ', ') ; rail accorde a chaque changement de page ($($ev.Count)) ; demarrage sur la Bibliotheque quand son dossier est regle, rail accorde ($start)"

foreach ($c in @($card, $tabs, $split, $lblPageTitle, $lnkPageBack) + @($script:NavButtons)) { try { $c.Dispose() } catch { } }
if (Test-Path -LiteralPath $gen) { Remove-Item -LiteralPath $gen -Force }
$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-interface-cadre : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
