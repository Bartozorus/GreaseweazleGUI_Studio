param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : compilation des blocs C# de l application par l edition de PowerShell qui execute le test. L application les
# compile dans « try { Add-Type ... -ErrorAction Stop ; drapeau } catch { } » : un echec y est muet (le drapeau reste
# faux, la calibration est refusee : « module d analyse SCP indisponible »). Les instructions Add-Type qui compilent
# (celles du controle A1 de check-source.ps1 : 030-csharp.ps1 et 500-fenetre-theme.ps1) sont extraites par l arbre
# syntaxique ; avec -Ci, chacune est ecrite telle quelle dans un fichier de travail, executee hors de son try/catch,
# puis les types attendus sont verifies. Sous Windows PowerShell 5.1 (CI), la compilation passe par csc.exe (C# 5).
#  X1 : autant d instructions trouvees que d empreintes dans tests\add-type.txt (sans compilation, toujours joue) ;
#  C1 a C5 (une par instruction), T1 : compilation et types, reserves a la CI : sans -Ci, rien n est compile (« saute »).
# Aucun gw, aucune fenetre.
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
"logic-csharp-compilation : $Wt ; $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion) ; -Ci $([bool]$Ci)"

$mods = Join-Path $Wt 'src\modules'
$blocks = @()
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Sort-Object Name)) {
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $($f.Name) : $(@($er)[0].Message)" }
    foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Add-Type' }, $true)) {
        $txt = ([regex]::Replace($c.Extent.Text, '\s+', ' ')).Trim()
        if ($txt -match '^Add-Type -AssemblyName [\w.]+$') { continue }
        $blocks += @{ Where = "$($f.Name):$($c.Extent.StartLineNumber)"; Text = $c.Extent.Text }
    }
}
# Nombre attendu : celui des empreintes de tests\add-type.txt (liste du controle A1), a cote de ce test
$nList = @([System.IO.File]::ReadAllLines((Join-Path $PSScriptRoot 'add-type.txt')) | Where-Object { $_ -match '^[0-9a-f]{64}\b' }).Count
Chk 'X1' ($blocks.Count -eq $nList -and $nList -gt 0) "$($blocks.Count) instruction(s) Add-Type qui compilent ($nList dans tests\add-type.txt) : $(@($blocks | ForEach-Object { $_.Where }) -join ', ')"

if (-not $Ci) { '  C1 a C5 et T1 sautes (compilation reservee a la CI : -Ci)' }
else {
    $i = 0
    foreach ($b in $blocks) {
        $i++
        $gen = Join-Path $here "gen-csharp-$i.ps1"
        [System.IO.File]::WriteAllText($gen, ($b.Text + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
        $err = ''
        try { . $gen } catch { $err = [string]$_.Exception.Message }
        $res = 'reussie'; if ($err) { $res = 'en echec : ' + ($err -replace '\s+', ' ') }
        Chk "C$i" (-not $err) "$($b.Where) : compilation $res"
    }
    $types = @('GwCompare', 'ScpRev', 'ScpStats', 'CalibPattern', 'CurveFit', 'IdxEntry', 'FastIndex', 'GwUi.Native')
    $miss = @($types | Where-Object { -not ($_ -as [type]) })
    $missTxt = 'aucun'; if ($miss.Count) { $missTxt = $miss -join ', ' }
    Chk 'T1' ($miss.Count -eq 0) "$($types.Count) types attendus apres la compilation ; absents : $missTxt"
}

$nk = ''; if ($script:Fail) { $nk = ' ; non conformes : ' + (@($script:FailIds) -join ', ') }
"=== bilan logic-csharp-compilation : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
