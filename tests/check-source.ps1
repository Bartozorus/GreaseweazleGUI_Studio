param(
    [string]$Root = '',
    # Cles T() sans traduction admises : aucune depuis la 12.11 (les 8 de la 12.10 ont leur entree dans 019-i18n-1211)
    [int]$MaxI18nMissing = 0
)
# Controles de la source, sans executer le code de l application (lecture seule) :
#  E1 fichiers .ps1 (modules, fichier assemble, outils, Build-Exe.ps1, tests) : UTF-8 avec un seul BOM, CRLF seuls ;
#  E2 CHANGELOG.md, README.md, src\modules\README.md, tests\README.md, workflows : LF sans BOM ;
#  S1 analyse syntaxique sans erreur par l edition qui execute ce script (sous Windows PowerShell 5.1 : preuve que la
#     source s y charge) ; S2 aucun jeton propre a PowerShell 7 (ternaire, ??, ?., &&, ||) ;
#  S3 modules et tests : aucune evaluation de texte ni commande encodee ni ou exclusif binaire (jetons et arbre
#     syntaxique : un commentaire ou une chaine ne comptent pas) ;
#  F1 aucune fonction definie deux fois dans les modules ;
#  A1 blocs Add-Type qui compilent (hors chargement d assembly) : empreintes egales a tests\add-type.txt ;
#  I1 cles T() litterales sans traduction : au plus -MaxI18nMissing (0 par defaut : aucune) ;
#  P1 tests et workflows : aucun chemin du poste de developpement, aucune adresse de reseau prive ni de messagerie.
# Les tests controles sont ceux du dossier de ce script ; -Root designe le depot dont on controle la source.
# Code de sortie : 0 conforme, 1 sinon. Compatible Windows PowerShell 5.1 et PowerShell 7.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$tests = $PSScriptRoot
if (-not $Root) { $Root = Split-Path -Parent $tests }
$Root = (Resolve-Path -LiteralPath $Root).ProviderPath
$mods = Join-Path $Root 'src\modules'
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:N = 0; $script:Bad = 0
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:N++
    $v = 'conforme'; if (-not $ok) { $script:Bad++; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
function Get-List($a, [int]$max = 6) {
    $x = @($a); if ($x.Count -eq 0) { return 'aucun' }
    $t = (@($x | Select-Object -First $max) -join ' | '); if ($x.Count -gt $max) { $t += " | ... ($($x.Count))" }
    return $t
}
"check-source : $Root ; $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"

$ps1 = @()
$ps1 += @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Sort-Object Name)
$ps1 += @(Get-Item -LiteralPath (Join-Path $Root 'src\GreaseweazleGUI.ps1'))
$ps1 += @(Get-ChildItem -LiteralPath (Join-Path $Root 'tools') -Filter '*.ps1' -File | Sort-Object Name)
$ps1 += @(Get-Item -LiteralPath (Join-Path $Root 'Build-Exe.ps1'))
$ps1 += @(Get-ChildItem -LiteralPath $tests -Filter '*.ps1' -File | Sort-Object Name)

$ps7 = @('QuestionQuestion', 'QuestionQuestionEquals', 'QuestionDot', 'QuestionLBracket', 'AndAnd', 'OrOr', 'QuestionMark')
$evalCmd = @(('Invoke-' + 'Expression'), ('ie' + 'x'))
$xorKind = 'B' + 'xor'
$enc = @(); $syn = @(); $tok7 = @(); $evil = @(); $asts = @{}
foreach ($f in $ps1) {
    $b = [System.IO.File]::ReadAllBytes($f.FullName)
    $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
    $skip = 0; if ($bom) { $skip = 3 }
    $t = [System.Text.Encoding]::UTF8.GetString($b, $skip, $b.Length - $skip)
    $cr = ([regex]::Matches($t, "`r")).Count; $lf = ([regex]::Matches($t, "`n")).Count; $crlf = ([regex]::Matches($t, "`r`n")).Count
    if (-not $bom -or $t.Contains([string][char]0xFEFF) -or $cr -ne $lf -or $crlf -ne $lf -or -not $t.EndsWith("`r`n")) { $enc += "$($f.Name) (BOM $bom, CR $cr, LF $lf, CRLF $crlf)" }
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tk, [ref]$er)
    $asts[$f.FullName] = $ast
    foreach ($e in @($er)) { $syn += "$($f.Name):$($e.Extent.StartLineNumber) $($e.Message)" }
    $own = ($f.DirectoryName -eq $mods -or $f.DirectoryName -eq $tests)
    foreach ($k in @($tk)) {
        $kind = [string]$k.Kind
        if ($ps7 -contains $kind) { $tok7 += "$($f.Name):$($k.Extent.StartLineNumber) $kind" }
        if (-not $own) { continue }
        if (($kind -eq 'Generic' -or $kind -eq 'Identifier') -and $evalCmd -contains [string]$k.Text) { $evil += "$($f.Name):$($k.Extent.StartLineNumber) $($k.Text)" }
        elseif ($kind -eq $xorKind) { $evil += "$($f.Name):$($k.Extent.StartLineNumber) ou exclusif binaire" }
        elseif ($kind -eq 'Parameter' -and ([string]$k.Text) -match '^-(ec|enc|encodedcommand)$') { $evil += "$($f.Name):$($k.Extent.StartLineNumber) commande encodee" }
    }
    if ($own) {
        foreach ($x in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Static -and $n.Expression -is [System.Management.Automation.Language.TypeExpressionAst] -and $n.Expression.TypeName.Name -eq 'scriptblock' -and [string]$n.Member -eq 'Create' }, $true)) {
            $evil += "$($f.Name):$($x.Extent.StartLineNumber) bloc de code cree depuis un texte"
        }
    }
}
Chk 'E1' ($enc.Count -eq 0) "$($ps1.Count) fichiers .ps1 en UTF-8 avec BOM et CRLF seuls ; en defaut : $(Get-List $enc)"
$docs = @((Join-Path $Root 'CHANGELOG.md'), (Join-Path $Root 'README.md'), (Join-Path $mods 'README.md'), (Join-Path $tests 'README.md'))
$wf = Join-Path $Root '.github\workflows'
$wfFiles = @()
if (Test-Path -LiteralPath $wf) { $wfFiles = @(Get-ChildItem -LiteralPath $wf -File | Where-Object { $_.Extension -eq '.yml' -or $_.Extension -eq '.yaml' } | Sort-Object Name | ForEach-Object { $_.FullName }) }
$docs += $wfFiles
$docBad = @(); $nDoc = 0
foreach ($p in $docs) {
    if (-not (Test-Path -LiteralPath $p)) { continue }
    $nDoc++
    $b = [System.IO.File]::ReadAllBytes($p)
    $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
    if ($bom -or [System.Array]::IndexOf($b, [byte]13) -ge 0) { $docBad += (Split-Path -Leaf $p) }
}
Chk 'E2' ($docBad.Count -eq 0) "$nDoc fichiers .md et .yml en LF sans BOM ; en defaut : $(Get-List $docBad)"
Chk 'S1' ($syn.Count -eq 0) "analyse syntaxique $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion) ; erreurs : $(Get-List $syn 3)"
Chk 'S2' ($tok7.Count -eq 0) "jetons propres a PowerShell 7 : $(Get-List $tok7)"
Chk 'S3' ($evil.Count -eq 0) "modules et tests, constructions interdites : $(Get-List $evil)"

$defs = @{}
foreach ($f in @($ps1 | Where-Object { $_.DirectoryName -eq $mods })) {
    foreach ($fd in $asts[$f.FullName].FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        $k = $fd.Name.ToLowerInvariant()
        if (-not $defs.ContainsKey($k)) { $defs[$k] = @() }
        $defs[$k] += "$($f.Name):$($fd.Extent.StartLineNumber)"
    }
}
$dups = @($defs.Keys | Where-Object { $defs[$_].Count -gt 1 } | Sort-Object | ForEach-Object { "$_ ($($defs[$_] -join ', '))" })
Chk 'F1' ($dups.Count -eq 0) "$($defs.Count) fonctions des modules ; definies deux fois : $(Get-List $dups)"

$sha = [System.Security.Cryptography.SHA256]::Create()
$cur = @()
foreach ($f in @($ps1 | Where-Object { $_.DirectoryName -eq $mods })) {
    foreach ($c in $asts[$f.FullName].FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Add-Type' }, $true)) {
        $txt = ([regex]::Replace($c.Extent.Text, '\s+', ' ')).Trim()
        if ($txt -match '^Add-Type -AssemblyName [\w.]+$') { continue }
        $h = [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($txt))).Replace('-', '').ToLowerInvariant()
        $cur += "$h  $($f.Name):$($c.Extent.StartLineNumber)"
    }
}
$allowFile = Join-Path $tests 'add-type.txt'
$allow = @()
if (Test-Path -LiteralPath $allowFile) { $allow = @([System.IO.File]::ReadAllLines($allowFile) | Where-Object { $_ -match '^[0-9a-f]{64}\b' } | ForEach-Object { $_.Substring(0, 64) }) }
$new = @($cur | Where-Object { $allow -notcontains $_.Substring(0, 64) })
$gone = @($allow | Where-Object { $h0 = $_; @($cur | Where-Object { $_.Substring(0, 64) -eq $h0 }).Count -eq 0 })
Chk 'A1' ($new.Count -eq 0 -and $gone.Count -eq 0) "$($cur.Count) bloc(s) Add-Type qui compilent ; absents de tests\add-type.txt : $(Get-List $new) ; empreintes sans bloc : $($gone.Count)"

$src = $asts[(Join-Path $Root 'src\GreaseweazleGUI.ps1')]
$table = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
foreach ($a in $src.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.IndexExpressionAst] -and $n.Left.Target -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.Left.Target.VariablePath.UserPath -eq 'script:I18n' }, $true)) {
    if ($a.Left.Index -is [System.Management.Automation.Language.StringConstantExpressionAst]) { [void]$table.Add([string]$a.Left.Index.Value) }
}
$miss = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
foreach ($c in $src.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'T' }, $true)) {
    if ($c.CommandElements.Count -lt 2) { continue }
    $k = $c.CommandElements[1]
    if ($k -is [System.Management.Automation.Language.StringConstantExpressionAst] -and -not $table.Contains([string]$k.Value)) { [void]$miss.Add([string]$k.Value) }
}
Chk 'I1' ($miss.Count -le $MaxI18nMissing) "table I18n : $($table.Count) cles ; cles T() sans traduction : $($miss.Count) (au plus $MaxI18nMissing)"
foreach ($k in @($miss | Sort-Object)) { $k1 = ($k -replace '\s+', ' '); if ($k1.Length -gt 110) { $k1 = $k1.Substring(0, 110) + '...' }; "         sans traduction : $k1" }

# Motifs en morceaux : ce script ne doit pas se signaler lui-meme
$pat = '(?i)[a-z]:\\Users\\|\\App' + 'Data\\|192\.168\.|[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}'
$paths = @()
$pFiles = @(Get-ChildItem -LiteralPath $tests -File | Where-Object { $_.Extension -eq '.ps1' -or $_.Extension -eq '.md' -or $_.Extension -eq '.txt' } | ForEach-Object { $_.FullName })
$pFiles += $wfFiles
foreach ($p in $pFiles) {
    # Le texte trouve n est pas affiche : la sortie de la CI est publique
    $txt = [System.IO.File]::ReadAllText($p)
    $m = [regex]::Match($txt, $pat)
    if ($m.Success) { $ln = $txt.Substring(0, $m.Index).Split([char]10).Count; $paths += "$(Split-Path -Leaf $p):$ln" }
}
Chk 'P1' ($paths.Count -eq 0) "$($pFiles.Count) fichiers (tests, workflows) sans chemin du poste, adresse de reseau prive ni adresse de messagerie ; en defaut : $(Get-List $paths)"

"=== bilan check-source : $($script:N - $script:Bad) conformes sur $($script:N) ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Bad) { exit 1 }
exit 0
