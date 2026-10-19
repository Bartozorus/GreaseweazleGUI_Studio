<#
.SYNOPSIS
    Assemble src\modules\NNN-*.ps1 en src\GreaseweazleGUI.ps1 et ecrit la table src\GreaseweazleGUI.map.json.

.DESCRIPTION
    La source de Greaseweazle Studio se modifie dans src\modules (voir src\modules\README.md). PS2EXE ne prend qu un
    script : src\GreaseweazleGUI.ps1 est la concatenation exacte des modules, dans l ordre de leur numero, avec une seule
    marque d ordre des octets (BOM) en tete. Ce fichier reste versionne : c est le script publie, celui que lisent le
    banc de test et Build-Exe.ps1. Il ne se modifie jamais a la main.

    Controles de chaque module (une seule erreur suffit : rien n est ecrit) :
      - nom NNN-mots-en-minuscules.ps1, numero d ordre unique sur 3 chiffres ;
      - UTF-8 valide avec BOM, aucun autre BOM, fins de ligne CRLF seules, derniere ligne terminee par CRLF ;
      - module analysable seul par PowerShell, sans erreur, et derniere ligne sans continuation de ligne (accent grave) :
        aucune instruction a cheval sur deux modules ;
      - module NNN-fn-*.ps1 : definitions de fonction seules, aucune instruction du niveau du script (une definition
        n execute rien : les modules fn peuvent preceder tout le code qui les appelle).
    Controle du resultat : fichier assemble analysable sans erreur, chaque instruction du niveau du script dans un seul
    module (garde generale, quelle que soit la cause).

    Ecriture seulement si le resultat change. Si src\GreaseweazleGUI.ps1 a ete modifie depuis le dernier assemblage
    (SHA-256 different de celui de la table), le script refuse de l ecraser, sauf avec -Force.
    Compatible Windows PowerShell 5.1 (Build-Exe.ps1) et PowerShell 7. Aucun code des modules n est execute.

.PARAMETER Root
    Racine du depot. Par defaut : le dossier parent de tools.

.PARAMETER Check
    N ecrit rien. Erreur si src\GreaseweazleGUI.ps1 ou la table ne correspondent pas aux modules.

.PARAMETER Force
    Ecrase src\GreaseweazleGUI.ps1 meme s il a ete modifie depuis le dernier assemblage : cette modification est perdue.

.PARAMETER PassThru
    Renvoie le resultat (Sha256, Lines, Modules, UpToDate, SourceWritten, MapWritten) au lieu de l afficher.

.EXAMPLE
    pwsh -NoProfile -File tools\Assemble-Source.ps1
    Assemble les modules et met a jour src\GreaseweazleGUI.ps1 et la table si besoin.

.EXAMPLE
    pwsh -NoProfile -File tools\Assemble-Source.ps1 -Check
    Verifie, sans rien ecrire, que le fichier assemble et la table sont a jour (code de sortie 1 sinon).
#>
[CmdletBinding()]
param(
    [string]$Root = '',
    [switch]$Check,
    [switch]$Force,
    [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).ProviderPath
$modDir = Join-Path $Root 'src\modules'
$outPath = Join-Path $Root 'src\GreaseweazleGUI.ps1'
$mapPath = Join-Path $Root 'src\GreaseweazleGUI.map.json'
if (-not (Test-Path -LiteralPath $modDir -PathType Container)) { throw "Dossier des modules introuvable : $modDir" }

function Get-Sha256Hex([byte[]]$Bytes) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($h.ComputeHash($Bytes)) -replace '-', '').ToLowerInvariant() }
    finally { $h.Dispose() }
}

function Get-LineOf([string]$Text, [int]$Index) {
    # numero de ligne (1 = premiere) du caractere d indice $Index
    return ([regex]::Matches($Text.Substring(0, $Index), "`n")).Count + 1
}

# --- Liste des modules : nom et numero d ordre ---------------------------------------------------------------------
$problems = New-Object System.Collections.Generic.List[string]
$mods = New-Object System.Collections.Generic.List[object]
foreach ($f in @(Get-ChildItem -LiteralPath $modDir -File | Where-Object { $_.Extension -eq '.ps1' })) {
    $mm = [regex]::Match($f.Name, '^(\d{3})-[a-z0-9]+(?:-[a-z0-9]+)*\.ps1$')
    if (-not $mm.Success) { $problems.Add("$($f.Name) : nom attendu NNN-mots-en-minuscules.ps1 (NNN : numéro d'ordre sur 3 chiffres)"); continue }
    $mods.Add([pscustomobject]@{ Name = $f.Name; Num = [int]$mm.Groups[1].Value; Path = $f.FullName })
}
foreach ($g in @($mods | Group-Object Num | Where-Object { $_.Count -gt 1 })) {
    $problems.Add("numéro d'ordre $('{0:000}' -f [int]$g.Name) porté par plusieurs modules : $(@($g.Group | ForEach-Object { $_.Name }) -join ', ')")
}
$mods = @($mods | Sort-Object Num)
if ($mods.Count -eq 0) { $problems.Add("aucun module NNN-*.ps1 dans $modDir") }

# --- Controle et lecture de chaque module --------------------------------------------------------------------------
$strict = New-Object System.Text.UTF8Encoding($false, $true)
$parts = New-Object System.Collections.Generic.List[object]
$map = New-Object System.Collections.Generic.List[object]
$line = 1
$total = 3
foreach ($m in $mods) {
    $b = [System.IO.File]::ReadAllBytes($m.Path)
    if ($b.Length -lt 3 -or $b[0] -ne 0xEF -or $b[1] -ne 0xBB -or $b[2] -ne 0xBF) { $problems.Add("$($m.Name) : BOM UTF-8 absent (enregistrer en UTF-8 avec BOM)"); continue }
    if ($b.Length -eq 3) { $problems.Add("$($m.Name) : module vide"); continue }
    $t = $null
    try { $t = $strict.GetString($b, 3, $b.Length - 3) } catch { $problems.Add("$($m.Name) : UTF-8 invalide ($($_.Exception.Message))"); continue }
    $n = ([regex]::Matches($t, "`n")).Count
    $ok = $true
    $i = $t.IndexOf([char]0xFEFF)
    if ($i -ge 0) { $problems.Add("$($m.Name) : BOM en trop, l. $(Get-LineOf $t $i)"); $ok = $false }
    $bad = [regex]::Match($t, "(?<!`r)`n|`r(?!`n)")
    if ($bad.Success) { $problems.Add("$($m.Name) : fin de ligne autre que CRLF, l. $(Get-LineOf $t $bad.Index) (CRLF seules)"); $ok = $false }
    elseif (-not $t.EndsWith("`r`n")) { $problems.Add("$($m.Name) : la dernière ligne doit finir par CRLF"); $ok = $false }
    $tk = $null; $pe = $null
    $ma = [System.Management.Automation.Language.Parser]::ParseInput($t, [ref]$tk, [ref]$pe)
    if ($pe -and $pe.Count -gt 0) {
        $e = $pe[0]
        $problems.Add("$($m.Name) : $($pe.Count) erreur(s) d'analyse du module seul, l. $($e.Extent.StartLineNumber) (l. $($line + $e.Extent.StartLineNumber - 1) de l'assemblage) : $($e.Message)")
        $ok = $false
    } elseif ($m.Name -match '^\d{3}-fn-') {
        # Module de fonctions : definitions seules (bloc param, begin, process et instructions du script refuses)
        $sts = if ($ma.EndBlock) { @($ma.EndBlock.Statements) } else { @() }
        $other = @($sts | Where-Object { $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] })
        foreach ($nb in @($ma.ParamBlock, $ma.DynamicParamBlock, $ma.BeginBlock, $ma.ProcessBlock)) { if ($nb) { $other = @($nb) + $other } }
        if ($other.Count -gt 0) {
            $x = $other[0].Extent.StartLineNumber
            $problems.Add("$($m.Name) : un module fn ne contient que des définitions de fonction ; instruction du niveau du script l. $x (l. $($line + $x - 1) de l'assemblage)")
            $ok = $false
        } elseif ($sts.Count -eq 0) {
            $problems.Add("$($m.Name) : module fn sans aucune fonction")
            $ok = $false
        }
    }
    if ($ok) {
        # Derniere ligne terminee par une continuation (accent grave suivi de CRLF) : le module s analyse seul sans erreur,
        # mais son instruction se poursuivrait dans le module suivant (ParseInput ne le signale pas en fin de texte)
        $j = $tk.Count - 1
        while ($j -ge 0 -and ($tk[$j].Kind -eq [System.Management.Automation.Language.TokenKind]::NewLine -or $tk[$j].Kind -eq [System.Management.Automation.Language.TokenKind]::EndOfInput)) { $j-- }
        if ($j -ge 0 -and $tk[$j].Kind -eq [System.Management.Automation.Language.TokenKind]::LineContinuation) {
            $x = $tk[$j].Extent.StartLineNumber
            $problems.Add("$($m.Name) : la dernière ligne finit par une continuation de ligne (accent grave), l. $x (l. $($line + $x - 1) de l'assemblage) : instruction à cheval sur le module suivant")
            $ok = $false
        }
    }
    if ($ok) {
        $map.Add([pscustomobject]@{ File = $m.Name; First = $line; Last = $line + $n - 1 })
        $parts.Add($b)
        $total += $b.Length - 3
    }
    $line += $n
}
if ($problems.Count -gt 0) {
    throw ("Assemblage impossible, rien n'a été écrit :`n  - " + ($problems -join "`n  - "))
}

# --- Assemblage : un BOM, puis le contenu de chaque module, octet pour octet ---------------------------------------
$out = New-Object byte[] $total
$out[0] = 0xEF; $out[1] = 0xBB; $out[2] = 0xBF
$o = 3
foreach ($b in $parts) { [System.Array]::Copy($b, 3, $out, $o, $b.Length - 3); $o += $b.Length - 3 }
$sha = Get-Sha256Hex $out
$lines = $line - 1

# Garde generale sur le fichier assemble : analysable sans erreur, et chaque instruction du niveau du script (bloc param
# compris) commence et finit dans le meme module. Les controles de chaque module en donnent la cause connue ; celle-ci
# couvre tout autre cas. Instructions dans l ordre du fichier : un seul parcours de la table
$atk = $null; $ape = $null
$aa = [System.Management.Automation.Language.Parser]::ParseInput($strict.GetString($out, 3, $out.Length - 3), [ref]$atk, [ref]$ape)
if ($ape -and $ape.Count -gt 0) {
    $x = $ape[0].Extent.StartLineNumber
    $mx = @($map | Where-Object { $x -ge $_.First -and $x -le $_.Last }) | Select-Object -First 1
    $problems.Add("fichier assemblé : $($ape.Count) erreur(s) d'analyse, l. $x$(if ($mx) { " ($($mx.File) l. $($x - $mx.First + 1))" }) : $($ape[0].Message)")
}
$top = New-Object System.Collections.Generic.List[object]
if ($aa.ParamBlock) { $top.Add($aa.ParamBlock) }
foreach ($nb in @($aa.BeginBlock, $aa.ProcessBlock, $aa.EndBlock)) { if ($nb) { foreach ($st in $nb.Statements) { $top.Add($st) } } }
$mi = 0
foreach ($st in $top) {
    $s0 = $st.Extent.StartLineNumber; $s1 = $st.Extent.EndLineNumber
    while ($mi -lt $map.Count - 1 -and $s0 -gt $map[$mi].Last) { $mi++ }
    if ($s1 -gt $map[$mi].Last) {
        $me = @($map | Where-Object { $s1 -ge $_.First -and $s1 -le $_.Last }) | Select-Object -First 1
        $problems.Add("$($map[$mi].File) l. $($s0 - $map[$mi].First + 1) : instruction à cheval sur le module $($me.File) (l. $s0 à $s1 de l'assemblage)")
    }
}
if ($problems.Count -gt 0) {
    throw ("Assemblage impossible, rien n'a été écrit :`n  - " + ($problems -join "`n  - "))
}

# Table de correspondance : texte fixe (meme octets sous 5.1 et 7), lignes du fichier assemble, bornes incluses
$nl = "`r`n"
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('{' + $nl)
[void]$sb.Append('  "format": 1,' + $nl)
[void]$sb.Append('  "note": "Genere par tools/Assemble-Source.ps1, ne pas modifier. Lignes de src/GreaseweazleGUI.ps1, bornes incluses.",' + $nl)
[void]$sb.Append('  "source": "src/GreaseweazleGUI.ps1",' + $nl)
[void]$sb.Append('  "sha256": "' + $sha + '",' + $nl)
[void]$sb.Append('  "lines": ' + $lines + ',' + $nl)
[void]$sb.Append('  "modules": [' + $nl)
for ($k = 0; $k -lt $map.Count; $k++) {
    $e = $map[$k]
    $sep = if ($k -lt $map.Count - 1) { ',' } else { '' }
    [void]$sb.Append('    { "file": "' + $e.File + '", "first": ' + $e.First + ', "last": ' + $e.Last + ' }' + $sep + $nl)
}
[void]$sb.Append('  ]' + $nl + '}' + $nl)
$mapText = $sb.ToString()

# --- Etat actuel du fichier assemble et de la table ----------------------------------------------------------------
$cur = $null; $curSha = $null
if (Test-Path -LiteralPath $outPath) { $cur = [System.IO.File]::ReadAllBytes($outPath); $curSha = Get-Sha256Hex $cur }
$curMap = $null
if (Test-Path -LiteralPath $mapPath) { $curMap = [System.IO.File]::ReadAllText($mapPath) }
$srcOk = ($curSha -eq $sha)
$mapOk = ($null -ne $curMap) -and ($curMap.Replace("`r`n", "`n") -ceq $mapText.Replace("`r`n", "`n"))

# Modifie a la main : le fichier present n est ni l assemblage actuel ni celui que la table a enregistre
$handEdited = $false
$where = ''
if ($null -ne $cur -and -not $srcOk) {
    $prev = $null
    if ($curMap) { $pm = [regex]::Match($curMap, '"sha256"\s*:\s*"([0-9a-f]{64})"'); if ($pm.Success) { $prev = $pm.Groups[1].Value } }
    $handEdited = ($prev -ne $curSha)
    if ($handEdited) {
        $la = [System.Text.Encoding]::UTF8.GetString($cur) -split "`r`n"
        $lb = [System.Text.Encoding]::UTF8.GetString($out) -split "`r`n"
        $d = 0
        while ($d -lt $la.Count -and $d -lt $lb.Count -and $la[$d] -ceq $lb[$d]) { $d++ }
        $dl = $d + 1
        $mod = @($map | Where-Object { $dl -ge $_.First -and $dl -le $_.Last }) | Select-Object -First 1
        $where = if ($mod) { "première différence l. $dl, soit $($mod.File) l. $($dl - $mod.First + 1)" } else { "première différence l. $dl" }
    }
}

$res = [pscustomobject]@{
    Sha256 = $sha; Lines = $lines; Modules = $map.ToArray(); UpToDate = ($srcOk -and $mapOk)
    SourceWritten = $false; MapWritten = $false
}

if ($Check) {
    if ($null -eq $cur) { throw 'src\GreaseweazleGUI.ps1 absent : lancez tools\Assemble-Source.ps1.' }
    if ($handEdited) { throw "src\GreaseweazleGUI.ps1 a été modifié sans passer par les modules ($where) : reportez la modification dans le module, puis lancez tools\Assemble-Source.ps1." }
    if (-not $srcOk) { throw 'src\GreaseweazleGUI.ps1 n''est pas à jour : les modules ont changé depuis le dernier assemblage. Lancez tools\Assemble-Source.ps1.' }
    if (-not $mapOk) { throw 'src\GreaseweazleGUI.map.json absent ou pas à jour : lancez tools\Assemble-Source.ps1.' }
} else {
    if ($handEdited -and -not $Force) {
        throw "src\GreaseweazleGUI.ps1 a été modifié depuis le dernier assemblage ($where). Reportez cette modification dans le module, puis relancez ; -Force écrase le fichier et la perd."
    }
    if (-not $srcOk) { [System.IO.File]::WriteAllBytes($outPath, $out); $res.SourceWritten = $true }
    if (-not $mapOk) { [System.IO.File]::WriteAllText($mapPath, $mapText, (New-Object System.Text.UTF8Encoding($false))); $res.MapWritten = $true }
}

if ($PassThru) { return $res }
Write-Host ("Assemblage : {0} modules, {1} lignes, SHA-256 {2}" -f $map.Count, $lines, $sha)
if ($Check) {
    Write-Host 'src\GreaseweazleGUI.ps1 et src\GreaseweazleGUI.map.json sont à jour.'
} else {
    Write-Host ('src\GreaseweazleGUI.ps1 : {0}' -f $(if ($res.SourceWritten) { 'écrit' } else { 'à jour, inchangé' }))
    Write-Host ('src\GreaseweazleGUI.map.json : {0}' -f $(if ($res.MapWritten) { 'écrit' } else { 'à jour, inchangé' }))
}
