# Fonctions communes des tests logiques des corrections du calcul de calibration (12.9, v129\cal2), chargees par
# dot-source. Niveau 2 : definitions de fonction et affectations du niveau du script extraites des modules par l arbre
# syntaxique, ecrites telles quelles dans un fichier .ps1 de travail (gen-*.ps1, dossier du test), puis dot-source ; type
# C# CurveFit : statement Add-Type de 030-csharp.ps1 recopie tel quel (aucun bloc nouveau ni modifie). Aucun gw, aucune
# application, aucune fenetre, aucune evaluation de texte, aucun bloc de code range dans une variable.

function Get-Cal2Modules([string]$root) {
    # Dossier des modules : <racine>\src\modules (copie de travail), <racine>\modules (copie des modules) ou <racine>
    foreach ($p in @((Join-Path $root 'src\modules'), (Join-Path $root 'modules'), $root)) {
        if (Test-Path -LiteralPath (Join-Path $p '240-fn-calib-mesure.ps1')) { return (Resolve-Path -LiteralPath $p).ProviderPath }
    }
    throw "modules introuvables sous $root"
}

function Get-Cal2Ast([string]$path) {
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message) (ligne $(@($er)[0].Extent.StartLineNumber))" }
    return $ast
}

function Get-Cal2FnDefs([string]$path) {
    # Definitions de fonction de premier niveau d un fichier : nom -> texte
    $h = @{}
    $ast = Get-Cal2Ast $path
    foreach ($fd in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) { $h[$fd.Name] = $fd.Extent.Text }
    return $h
}

function Get-Cal2SpecFns([string]$md) {
    # Definitions de fonction des blocs de code PowerShell d une specification Markdown (blocs analysables sans erreur
    # seulement : les fragments partiels sont ignores) : nom -> texte
    $h = @{}
    $txt = [System.IO.File]::ReadAllText($md)
    foreach ($m in [regex]::Matches($txt, '(?ms)^```powershell\r?\n(.*?)^```')) {
        $tk = $null; $er = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($m.Groups[1].Value, [ref]$tk, [ref]$er)
        if (@($er).Count) { continue }
        foreach ($fd in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) { $h[$fd.Name] = $fd.Extent.Text }
    }
    return $h
}

function Get-Cal2CurveFit([string]$mods) {
    # Statement Add-Type du type C# CurveFit (030), recopie tel quel
    $ast = Get-Cal2Ast (Join-Path $mods '030-csharp.ps1')
    $cmd = @($ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'Add-Type' -and $x.Extent.Text -like '*class CurveFit*' }, $true))
    if ($cmd.Count -ne 1) { throw "statement Add-Type de CurveFit introuvable ($($cmd.Count))" }
    return $cmd[0].Extent.Text
}

function Get-Cal2Consts([string]$mods) {
    # Constantes de la calibration : affectations $script:Cal* du niveau du script de 560 (sauf celles qui lisent la table
    # des reglages ou un controle), puis versions du calcul de 000 (CalibCalc, CalibCalcHd, CalibAlgo, Version)
    $out = New-Object System.Collections.Generic.List[string]
    $a = Get-Cal2Ast (Join-Path $mods '560-etat-calibration.ps1')
    foreach ($st in $a.EndBlock.Statements) {
        if ($st -is [System.Management.Automation.Language.AssignmentStatementAst] -and $st.Left.Extent.Text -like '$script:Cal*' -and $st.Extent.Text -notmatch 'SettingDefs|\$cmb|\$txt|\$chk') { $out.Add($st.Extent.Text) }
    }
    $a0 = Get-Cal2Ast (Join-Path $mods '000-entete.ps1')
    foreach ($st in $a0.EndBlock.Statements) {
        if ($st -is [System.Management.Automation.Language.AssignmentStatementAst] -and @('$script:CalibCalc', '$script:CalibCalcHd', '$script:CalibAlgo', '$script:Version') -contains $st.Left.Extent.Text) { $out.Add($st.Extent.Text) }
    }
    return ,$out.ToArray()
}

function Get-Cal2Assign([string]$path, [string[]]$lefts) {
    # Affectations du niveau du script dont la cible est dans $lefts (texte tel quel)
    $a = Get-Cal2Ast $path
    return ,@($a.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and @($lefts) -contains $_.Left.Extent.Text } | ForEach-Object { $_.Extent.Text })
}

function Get-Cal2CalStateFn([string]$mods) {
    # Etat de la calibration tel que Start-PrecompCalib le construit : affectation « $script:Cal = @{ ... } » de 270,
    # recopiee telle quelle par l arbre syntaxique dans une fonction de travail New-Cal2CalState, dont les parametres sont
    # les variables locales de Start-PrecompCalib que la table lit (calculees par le test selon la specification)
    $ast = Get-Cal2Ast (Join-Path $mods '270-fn-calib-complete.ps1')
    $fd = @($ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Start-PrecompCalib' }, $false))
    if ($fd.Count -ne 1) { throw 'Start-PrecompCalib introuvable' }
    $as = @($fd[0].Body.FindAll({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and $x.Left.Extent.Text -eq '$script:Cal' -and $x.Right.Extent.Text -like '@{*' }, $true))
    if ($as.Count -ne 1) { throw "affectation de l etat de la calibration introuvable dans Start-PrecompCalib ($($as.Count))" }
    $hdr = 'function New-Cal2CalState($fine, $cyls, $maxCyl, $family, $slow, $img, $pat, $cylList, $units, $ans, $redo, $nPassEst, $estEr, $noWarm, $nPassMax, $cond, $LevelAfter, $Geom) {'
    return ($hdr + "`r`n" + $as[0].Extent.Text + "`r`n}")
}

function Get-Cal2Renamed($defs, [string]$name, [string]$newName) {
    # Texte d une fonction sous un autre nom (version reelle gardee a cote d un remplacant du meme nom)
    $t = [string]$defs[$name]
    if (-not $t) { throw "fonction $name introuvable" }
    $p = "function $name"
    if (-not $t.StartsWith($p)) { throw "en-tete inattendu pour $name" }
    return ("function $newName" + $t.Substring($p.Length))
}

function Add-Cal2Fns($parts, $defs, [string[]]$names, $found, [string]$where) {
    # Ajoute aux parties du fichier de travail les fonctions demandees ('*' : toutes) d une table nom -> texte
    $all = @($names) -contains '*'
    foreach ($k in @($defs.Keys | Sort-Object)) {
        if ($all -or @($names) -contains $k) { $parts.Add($defs[$k]); $found[$k] = $where }
    }
}

function Write-Cal2Gen([string]$out, $parts) {
    [System.IO.File]::WriteAllText($out, ((@($parts) -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
}

function Test-Cal2Missing([string[]]$names, $found) {
    $miss = @($names | Where-Object { $_ -ne '*' -and -not $found.ContainsKey($_) })
    if ($miss.Count) { throw "fonctions introuvables (correction pas encore implementee ?) : $($miss -join ', ')" }
}

# ---------------------------------------------------------------- controles et sortie
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    if (-not $ok) { $script:Fail++; $script:FailIds += $id }
    '{0,-8} {1,-12} {2}' -f $id, $(if ($ok) { 'conforme' } else { 'NON CONFORME' }), $d
}

function Get-Cal2Bilan([string]$name) {
    $nk = if ($script:Fail) { ' ; non conformes : ' + (@($script:FailIds) -join ', ') } else { '' }
    return "=== bilan $name : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk"
}

function F([double]$x, [string]$f = '0.00') {
    # Nombre a la francaise (sortie lisible ; les comparaisons portent sur les nombres)
    if ([double]::IsNaN($x)) { return '-' }
    return $x.ToString($f, [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR'))
}

function Format-Set($a) {
    $x = @(@($a) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique)
    if ($x.Count -eq 0) { return '-' }
    return ($x -join ',')
}

function Get-SegTxt($f) { return ((@($f.Segs) | Where-Object { $null -ne $_ } | ForEach-Object { "[$($_.Lo)-$($_.Hi) $(if ([int]$_.Dir -gt 0) { '+' } else { '-' })]" }) -join '') }

# ---------------------------------------------------------------- tirages (System.Random, graine fixe)
function Set-Cal2Rng([int]$seed) { $script:Rng = New-Object System.Random($seed) }
function Get-N01 {
    $u1 = 1.0 - $script:Rng.NextDouble(); $u2 = $script:Rng.NextDouble()
    return [math]::Sqrt(-2.0 * [math]::Log($u1)) * [math]::Cos(2.0 * [math]::PI * $u2)
}
function Get-U11 { return 2.0 * $script:Rng.NextDouble() - 1.0 }

# ---------------------------------------------------------------- besoins des simulations (§ 11.3, sim_dents_final.py)
function Get-NeedA([int]$c, [int]$h, [bool]$dent) {
    # Lecteur A : rupture c43/c44 ; dent c64/c65 de 6,5 ns remontant en 4 cylindres ; tete 1 : + 3 ns
    if ($c -le 43) { $z = 7.0 + 0.9 * $c }
    elseif (-not $dent -or $c -le 64) { $z = 16.0 + 1.1 * ($c - 44) }
    elseif ($c -le 69) { $z = 31.5 + 1.5 * ($c - 65) }
    else { $z = 37.5 + 1.0 * ($c - 69) }
    return $z + 3.0 * $h
}
function Get-Need0([int]$c) {
    # Lecteur a fort besoin (type lecteur 0) : 51 a 385 ns, rupture c43/c44 de 30 ns, sans dent
    if ($c -le 43) { return 51.0 + 4.0 * $c }
    return 193.0 + 4.5 * ($c - 44)
}
function Get-Cal2Shift([double]$w, [double]$z, [double]$k, [double]$kap, [double]$lam) {
    # Decalage lu sans bruit : -k (W - z) + kap (exp(-W/lam) - exp(-z/lam))
    return -$k * ($w - $z) + $kap * ([math]::Exp(-$w / $lam) - [math]::Exp(-$z / $lam))
}
