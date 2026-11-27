param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Before = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.12 (vitesse) : resultats des lectures d image gardes en memoire, et durees au journal.
#  V1  cle d un resultat garde, par une vraie fonction (Test-NeedsFormat) : un seul resultat pour deux appels ; autre
#      cle pour une autre langue et quand le fichier change ; rien de garde sans fichier.
#  V2  texte de la memoire (le meme dans les dix fonctions) autour d un corps factice : la lecture n est faite qu une
#      fois et son resultat est reemis sous la meme forme (rien, $null, table copiee, tableau emis entier, plusieurs
#      objets) ; une erreur de la lecture sort telle quelle et n est jamais gardee.
#  V4  les dix lectures d image gardees (arbre syntaxique) : chacune porte ce texte a son nom, avec le plafond de 256
#      resultats, et ne lit aucun etat de l application hors la memoire et la langue ; aucune autre fonction ne touche
#      a la memoire.
#  V6  Add-UiTiming : rien sans la case « Chrono », rien sous 100 ms ; ligne en francais et en anglais.
#  V7  (statique) detecteur de blocage de la fenetre (600) et durees de Save-Config et d Update-PrecompForImage : sous la
#      garde de la case « Chrono ».
# Fonctions reelles extraites par l arbre syntaxique ; aucun gw, aucune fenetre, aucune image reelle (fichiers de travail
# de quelques octets, a contenu fixe).
# Non couvert ici : le gain de temps reel (il depend du poste et du partage reseau : durees au journal, case « Chrono »).
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mods = Join-Path $Wt 'src\modules'
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
$tFn = [System.Management.Automation.Language.FunctionDefinitionAst]
$tCmd = [System.Management.Automation.Language.CommandAst]
$tVar = [System.Management.Automation.Language.VariableExpressionAst]
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'
$all = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Where-Object { $_.Name -match '^[1-4]\d\d-fn-' } | Sort-Object Name)) {
    $tk = $null; $er = $null
    $a = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $($f.Name) : $(@($er)[0].Message)" }
    foreach ($fd in $a.FindAll({ param($x) $x -is $tFn }, $false)) { $all[$fd.Name] = $fd }
}
$load = @('Test-NeedsFormat', 'Add-UiTiming')
$miss = @($load | Where-Object { -not $all.ContainsKey($_) })
if ($miss.Count) { throw "fonctions introuvables : $($miss -join ', ')" }
# Texte de la memoire, tel que chaque lecture gardee doit le porter ({N} : son nom) : avant et apres le corps d origine
$PRE = @(
    "    `$mk = ''",
    "    try { if (`$path) { `$mf = New-Object System.IO.FileInfo(`$path); if (`$mf.Exists) { `$mk = '{N}|' + [string]`$script:Lang + '|' + `$mf.Length + '|' + `$mf.LastWriteTimeUtc.Ticks + '|' + `$mf.FullName } } } catch { `$mk = '' }",
    "    if (`$mk -and `$null -ne `$script:FileMemo -and `$script:FileMemo.ContainsKey(`$mk)) { `$mo = `$script:FileMemo[`$mk] }",
    "    else {",
    "        `$mo = @(& {"
) -join "`r`n"
$POST = @(
    "        })",
    "        if (`$mk) { if (`$null -eq `$script:FileMemo -or `$script:FileMemo.Count -ge 256) { `$script:FileMemo = @{} }; `$script:FileMemo[`$mk] = `$mo }",
    "    }",
    "    foreach (`$o in `$mo) { if (`$o -is [hashtable]) { , `$o.Clone() } else { , `$o } }"
) -join "`r`n"
$fake = "function Get-Fake([string]`$path) {`r`n" + $PRE.Replace('{N}', 'Get-Fake') + "`r`n" + @'
    $script:RawN++
    switch ($script:RawMode) {
        'rien' { return }
        'null' { return $null }
        'table' { return @{ A = 1; L = @(1, 2) } }
        'tableau' { return , @(10, 20, 30) }
        'plusieurs' { 'un'; 2; @{ B = 3 } }
        'erreur' { throw 'lecture impossible' }
    }
'@ + "`r`n" + $POST + "`r`n}"
$gen = Join-Path $here 'gen-vitesse-fonctions.ps1'
[System.IO.File]::WriteAllText($gen, ((@($load | ForEach-Object { $all[$_].Extent.Text }) -join "`r`n`r`n") + "`r`n`r`n" + $fake + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
. $gen
$script:VLog = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text) { $script:VLog.Add($text) }
$enc = New-Object System.Text.UTF8Encoding($false)
function Set-VFile([string]$name, [string]$text) { $p = Join-Path $here $name; [System.IO.File]::WriteAllText($p, $text, $enc); return $p }
function Get-MemoN { if ($null -eq $script:FileMemo) { return 0 } else { return [int]$script:FileMemo.Count } }

'--- V1 : cle (vraie fonction gardee, Test-NeedsFormat)'
$script:FileMemo = $null
$fA = Set-VFile 'memo-a.dsk' 'MV - CPC disquette factice'
$r1 = Test-NeedsFormat $fA; $c1 = Get-MemoN
$r2 = Test-NeedsFormat $fA; $c2 = Get-MemoN
$key1 = [string](@($script:FileMemo.Keys)[0])
$script:Lang = 'en'; $rEn = Test-NeedsFormat $fA; $cEn = Get-MemoN; $script:Lang = 'fr'
[void](Set-VFile 'memo-a.dsk' 'autre contenu, sans la signature du format')
$r3 = Test-NeedsFormat $fA; $c3 = Get-MemoN
$abs = Join-Path $here 'absent.dsk'
$r4 = Test-NeedsFormat $abs; $r5 = Test-NeedsFormat ''; $c5 = Get-MemoN
$fI = Set-VFile 'memo-c.img' 'x'; $r6 = Test-NeedsFormat $fI
Chk 'V1' ($r1 -eq $false -and $r2 -eq $false -and $c1 -eq 1 -and $c2 -eq 1 -and $key1.StartsWith('Test-NeedsFormat|fr|26|') -and $key1.EndsWith('|' + $fA) -and $rEn -eq $false -and $cEn -eq 2 -and $r3 -eq $true -and $c3 -eq 3 -and $r4 -eq $true -and $c5 -eq 3 -and $r6 -eq $true) "un seul resultat garde pour deux appels ($c2) ; autre cle pour une autre langue ($cEn) et quand le fichier change ($c3, resultat refait : $r3) ; fichier absent ou chemin vide : rien de garde ($c5), reponse d avant ($r4, $r5)"

'--- V2 : une seule lecture, meme forme a la reemission (texte de la memoire autour d un corps factice)'
$script:FileMemo = $null; $script:RawN = 0; $script:RawMode = ''
$shape = @{}
$i = 0
foreach ($md in 'rien', 'null', 'table', 'tableau', 'plusieurs') {
    $i++
    $fp = Set-VFile "memo-forme-$i.bin" ('x' * $i)
    $script:RawMode = $md; $n0 = $script:RawN
    $a1 = @(Get-Fake $fp); $a2 = @(Get-Fake $fp)
    if ($md -eq 'table') { $a1[0].A = 99; $a3 = @(Get-Fake $fp) }
    $shape[$md] = @{ Calls = ($script:RawN - $n0); A = $a1; B = $a2 }
}
$tb = $shape['table']
$v2 = ($shape['rien'].Calls -eq 1 -and $shape['rien'].A.Count -eq 0 -and $shape['rien'].B.Count -eq 0)
$v2 = ($v2 -and $shape['null'].Calls -eq 1 -and $shape['null'].B.Count -eq 1 -and $null -eq $shape['null'].B[0])
$v2 = ($v2 -and $tb.Calls -eq 1 -and $tb.B[0] -is [hashtable] -and [int]$tb.B[0].A -eq 1 -and [int]$a3[0].A -eq 1 -and -not [object]::ReferenceEquals($tb.A[0], $tb.B[0]))
$v2 = ($v2 -and $shape['tableau'].Calls -eq 1 -and $shape['tableau'].B.Count -eq 1 -and @($shape['tableau'].B[0]).Count -eq 3 -and [int]$shape['tableau'].B[0][2] -eq 30)
$v2 = ($v2 -and $shape['plusieurs'].Calls -eq 1 -and $shape['plusieurs'].B.Count -eq 3 -and [string]$shape['plusieurs'].B[0] -ceq 'un' -and [int]$shape['plusieurs'].B[1] -eq 2 -and [int]$shape['plusieurs'].B[2].B -eq 3)
# Erreur de la lecture : elle sort telle quelle, rien n est garde, la lecture est refaite a l appel suivant
$fe = Set-VFile 'memo-forme-err.bin' 'erreur'
$script:RawMode = 'erreur'; $n0 = $script:RawN; $cE0 = Get-MemoN; $m1 = ''; $m2 = ''
try { [void](Get-Fake $fe) } catch { $m1 = "$($_.Exception.Message)" }
try { [void](Get-Fake $fe) } catch { $m2 = "$($_.Exception.Message)" }
$v2e = ($m1 -ceq 'lecture impossible' -and $m2 -ceq 'lecture impossible' -and ($script:RawN - $n0) -eq 2 -and (Get-MemoN) -eq $cE0)
Chk 'V2' ($v2 -and $v2e) "une lecture pour deux appels, dans les cinq formes (rien, `$null, table copiee, tableau entier, plusieurs objets) : $v2 ; erreur de la lecture rendue telle quelle et jamais gardee : $v2e"

'--- V4 : les dix lectures gardees'
$readers = @('Get-ImageTrackSet', 'Test-NeedsFormat', 'Test-ScpHighDensity', 'Get-ImageGeometryTrackSet', 'Get-IpfCellInfo', 'Get-ScpCellInfo', 'Get-HfeCellInfo', 'Get-ImageCylinders', 'Get-IpfTrackInfo', 'Get-IpfFormattedCyls')
$badW = New-Object System.Collections.Generic.List[string]
foreach ($n in $readers) {
    if (-not $all.ContainsKey($n)) { $badW.Add("$n : absente"); continue }
    $w = $all[$n]; $tx = [string]$w.Extent.Text
    if (-not $tx.Contains($PRE.Replace('{N}', $n)) -or -not $tx.TrimEnd().EndsWith($POST + "`r`n}")) { $badW.Add("$n : texte de la memoire different") }
    # la lecture ne depend que de son fichier : aucun etat de l application hors la memoire et la langue, aucun controle
    $st = @($w.FindAll({ param($x) $x -is $tVar }, $true) | ForEach-Object { $_.VariablePath.UserPath } | Where-Object { ($_ -match '^script:' -and $_ -notmatch '^script:(FileMemo|Lang)$') -or $_ -cmatch '^(cmb|chk|txt|num|lbl|btn|form|tab)[A-Z]' } | Sort-Object -Unique)
    if ($st.Count) { $badW.Add("$n lit $($st -join ', ')") }
}
$others = @($all.Keys | Where-Object { $readers -notcontains $_ -and ([string]$all[$_].Extent.Text).Contains('$script:FileMemo') })
Chk 'V4' ($badW.Count -eq 0 -and $others.Count -eq 0) "dix lectures gardees, chacune avec le meme texte de memoire a son nom (plafond de 256 resultats compris) et sans autre etat que la memoire et la langue : $(if ($badW.Count) { $badW -join ' ; ' } else { 'conformes' }) ; autre fonction qui touche a la memoire : $(if ($others.Count) { $others -join ', ' } else { 'aucune' })"

'--- V6 : durees au journal'
$script:VLog.Clear()
Add-UiTiming 'changement de lecteur' 1250 'dont lecteurs et courbes 0,02 s'
$n0 = $script:VLog.Count
$chkTime = [pscustomobject]@{ Checked = $false }
Add-UiTiming 'changement de lecteur' 1250
$n1 = $script:VLog.Count
$chkTime.Checked = $true
Add-UiTiming 'changement de lecteur' 99
$n2 = $script:VLog.Count
Add-UiTiming (T 'fenêtre sans réponse') 1250 'détail'
Add-UiTiming (T 'enregistrement de la configuration') 100
$script:Lang = 'en'
Add-UiTiming (T 'fenêtre sans réponse') 1250
Add-UiTiming (T "profil de l'image et ligne « Ce qui va se passer »") 480
$script:Lang = 'fr'
$lg = @($script:VLog)
Chk 'V6' ($n0 -eq 0 -and $n1 -eq 0 -and $n2 -eq 0 -and $lg.Count -eq 4 -and $lg[0] -ceq 'Durée : fenêtre sans réponse, 1,25 s (détail)' -and $lg[1] -ceq 'Durée : enregistrement de la configuration, 0,10 s' -and $lg[2] -ceq 'Duration: window not responding, 1.25 s' -and $lg[3] -ceq 'Duration: image profile and "What will happen" line, 0.48 s') "sans la case « Chrono », case decochee, sous 100 ms : rien ; sinon : « $($lg -join ' » ; « ') »"

$s600 = [System.IO.File]::ReadAllText((Join-Path $mods '600-minuteur-demarrage.ps1'), [System.Text.Encoding]::UTF8)
$s120 = [string]$all['Save-Config'].Extent.Text; $s220 = [string]$all['Update-PrecompForImage'].Extent.Text
$g = 'if ($chkTime -and $chkTime.Checked) { Add-UiTiming '
Chk 'V7' ($s600.Contains('$timerUi.Interval = 250') -and $s600.Contains('if ($msUi -ge 750 -and $chkTime.Checked) { Add-UiTiming (T ''fenêtre sans réponse'') ($msUi - 250) }') -and $s600.Contains('$timerUi.Start()') -and $s120.Contains($g) -and $s220.Contains($g) -and ([regex]::Matches($s120 + $s220, [regex]::Escape($g))).Count -eq 2) "detecteur de blocage (600) : battement de 250 ms, ligne au-dela de 750 ms, case « Chrono » ; enregistrement de la configuration et profil de l image : duree calculee sous la meme garde, une fois chacun"
foreach ($p in @(Get-ChildItem -LiteralPath $here -Filter 'memo-*' -File | ForEach-Object { $_.FullName }) + @($gen)) { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force } }
$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-vitesse-memoire : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
