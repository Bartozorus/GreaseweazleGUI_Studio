param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : controles de tests\check-source.ps1 sur un depot factice. Le test ecrit dans son dossier de travail un petit
# depot conforme (4 modules, fichier assemble, outil, Build-Exe.ps1, documents, un test), y copie check-source.ps1, puis
# seme un defaut a la fois et verifie que le controle vise, et lui seul, devient non conforme :
#  B1 depot conforme (9 controles, code 0) ; A0 bloc Add-Type absent de la liste (A1) ;
#  D1 module sans BOM (E1) ; D2 module en LF (E1) ; D3 document en CRLF (E2) ; D4 erreur de syntaxe (S1) ;
#  D5 fonction definie deux fois (F1) ; D6 bloc Add-Type modifie (A1) ; D7 cle T() sans traduction au-dela du seuil
#  (I1), admise quand le seuil la couvre ; D7b la meme cle refusee par le seuil par defaut du controle (0 depuis la
#  12.11 : aucun -MaxI18nMissing transmis) ; D8 chemin du poste dans un test (P1) ; D9 adresse de messagerie dans un
#  test (P1) ; D10 a D13b autres formes refusees par P1 dans un test : chemin a barres obliques, chemin echappe, chemin
#  sous Git Bash, partage reseau (nom court, nom qualifie), adresse de reseau prive 10.x et 172.16 a 172.31 ; D13c numero
#  de version a plusieurs nombres : non signale ; D14 syntaxe propre a PowerShell 7 dans un module (S2 ; sous PowerShell 7
#  seulement) ; D15 a D17 P1 lit aussi les modules, les outils et les documents.
# Aucun defaut seme pour S3 : il faudrait ecrire sur le poste un fichier qui contient une construction interdite.
# Les fichiers factices ne sont jamais executes : check-source.ps1 les lit et les analyse seulement. Les sorties de
# check-source.ps1 ne sont pas recopiees ici (leur ligne de bilan fausserait celle de ce test) : elles sont ecrites dans
# le dossier de travail (B1.txt, D1.txt...). Aucun gw, aucune fenetre, aucune compilation.
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
$exeName = 'powershell.exe'; if ($PSVersionTable.PSEdition -eq 'Core') { $exeName = 'pwsh.exe' }
$exe = Join-Path $PSHOME $exeName
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$ids = @('E1', 'E2', 'S1', 'S2', 'S3', 'F1', 'A1', 'I1', 'P1')

# ---------------------------------------------------------------- depot factice
$fx = Join-Path $here 'faux'
if (Test-Path -LiteralPath $fx) { Remove-Item -LiteralPath $fx -Recurse -Force }
foreach ($d in 'src\modules', 'tools', 'tests') { [void](New-Item -ItemType Directory -Path (Join-Path $fx $d) -Force) }
function Set-Ps([string]$rel, [string[]]$lines) {
    # Fichier .ps1 conforme : UTF-8 avec BOM, CRLF
    [System.IO.File]::WriteAllText((Join-Path $fx $rel), (($lines -join "`r`n") + "`r`n"), $utf8Bom)
}
function Set-Doc([string]$rel, [string]$text) { [System.IO.File]::WriteAllText((Join-Path $fx $rel), $text, $utf8) }
$m000 = @('$script:Version = ''0.0''')
$m010 = @('$script:I18n = @{}', '$script:I18n[''Bonjour''] = ''Hello''', 'function T([string]$s) { return $s }')
$m030 = @('try {', '    Add-Type -TypeDefinition @''', 'public static class FauxType { public static int Un() { return 1; } }', '''@ -ErrorAction Stop', '} catch { }')
$m100 = @('function Get-Salut { return (T ''Bonjour'') }')
function Set-Modules {
    Set-Ps 'src\modules\000-entete.ps1' $m000
    Set-Ps 'src\modules\010-i18n.ps1' $m010
    Set-Ps 'src\modules\030-csharp.ps1' $m030
    Set-Ps 'src\modules\100-fn-salut.ps1' $m100
    Set-Ps 'src\GreaseweazleGUI.ps1' ($m000 + $m010 + $m030 + $m100)
}
Set-Modules
Set-Ps 'tools\Outil.ps1' @('''outil factice''')
Set-Ps 'Build-Exe.ps1' @('''compilation factice''')
Set-Ps 'tests\logic-factice.ps1' @('''test factice''')
Set-Doc 'CHANGELOG.md' "# Journal factice`n"
Set-Doc 'README.md' "# Depot factice`n"
Set-Doc 'src\modules\README.md' "# Modules factices`n"
$chk = Join-Path $fx 'tests\check-source.ps1'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'check-source.ps1') -Destination $chk

function Invoke-Check([string]$name, [int]$max = 0) {
    # Lance la copie de check-source.ps1 sur le depot factice ; rend le code de sortie et l etat de chaque controle.
    # $max negatif : aucun -MaxI18nMissing transmis, le seuil par defaut du controle s applique
    $a = @('-Root', $fx); if ($max -ge 0) { $a += @('-MaxI18nMissing', "$max") }
    $ErrorActionPreference = 'Continue'
    $lines = @(& $exe -NoProfile -File $chk @a 2>&1 | ForEach-Object { "$_" })
    $rc = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    [System.IO.File]::WriteAllLines((Join-Path $here "$name.txt"), [string[]]$lines, $utf8)
    $st = @{}
    foreach ($l in $lines) { if ($l -cmatch '^([A-Z]\d)\s+(conforme|NON CONFORME)\s') { $st[$Matches[1]] = ($Matches[2] -ceq 'conforme') } }
    return @{ Rc = $rc; St = $st; Lines = $lines }
}
function Test-Only($r, [string[]]$bad) {
    # Vrai si les 9 controles sont rendus, si ceux de $bad sont non conformes, les autres conformes, et si le code suit
    foreach ($i in $ids) {
        if (-not $r.St.ContainsKey($i)) { return $false }
        if ($r.St[$i] -eq ($bad -contains $i)) { return $false }
    }
    $rcWant = 0; if ($bad.Count) { $rcWant = 1 }
    return ($r.Rc -eq $rcWant)
}
function Get-Bad($r) {
    $b = @($ids | Where-Object { $r.St.ContainsKey($_) -and -not $r.St[$_] })
    $t = 'aucun'; if ($b.Count) { $t = $b -join ', ' }
    return "non conformes : $t ; code $($r.Rc) ; $($r.St.Count) controles rendus"
}
"logic-controle-source : depot factice $fx ; $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"

# Liste des blocs Add-Type : absente d abord (le bloc factice est signale), puis ecrite avec l empreinte que rend
# check-source.ps1 lui-meme
$r = Invoke-Check 'A0'
$a1 = [string](@($r.Lines | Where-Object { $_ -cmatch '^A1\s' }) | Select-Object -First 1)
$hash = [regex]::Match($a1, '[0-9a-f]{64}').Value
Chk 'A0' ((Test-Only $r @('A1')) -and $hash.Length -eq 64 -and $a1.Contains('030-csharp.ps1:2')) "bloc Add-Type absent de tests\add-type.txt : $(Get-Bad $r) ; empreinte rendue : $($hash.Length -eq 64)"
Set-Doc 'tests\add-type.txt' "# liste factice`n$hash  030-csharp.ps1:2`n"
$r = Invoke-Check 'B1'
Chk 'B1' (Test-Only $r @()) "depot factice conforme : $(Get-Bad $r)"

[System.IO.File]::WriteAllText((Join-Path $fx 'src\modules\100-fn-salut.ps1'), (($m100 -join "`r`n") + "`r`n"), $utf8)
$r = Invoke-Check 'D1'; Set-Modules
Chk 'D1' (Test-Only $r @('E1')) "module sans BOM : $(Get-Bad $r)"

[System.IO.File]::WriteAllText((Join-Path $fx 'src\modules\010-i18n.ps1'), (($m010 -join "`n") + "`n"), $utf8Bom)
$r = Invoke-Check 'D2'; Set-Modules
Chk 'D2' (Test-Only $r @('E1')) "module aux fins de ligne LF : $(Get-Bad $r)"

Set-Doc 'README.md' "# Depot factice`r`n"
$r = Invoke-Check 'D3'; Set-Doc 'README.md' "# Depot factice`n"
Chk 'D3' (Test-Only $r @('E2')) "document aux fins de ligne CRLF : $(Get-Bad $r)"

Set-Ps 'src\modules\100-fn-salut.ps1' ($m100 + @('function Get-Casse {'))
$r = Invoke-Check 'D4'; Set-Modules
Chk 'D4' (Test-Only $r @('S1')) "erreur de syntaxe dans un module : $(Get-Bad $r)"

Set-Ps 'src\modules\100-fn-salut.ps1' ($m100 + @('function T([string]$s) { return $s }'))
$r = Invoke-Check 'D5'; Set-Modules
Chk 'D5' (Test-Only $r @('F1')) "fonction definie dans deux modules : $(Get-Bad $r)"

$m030b = @($m030 | ForEach-Object { $_.Replace('return 1;', 'return 2;') })
Set-Ps 'src\modules\030-csharp.ps1' $m030b
$r = Invoke-Check 'D6'; Set-Modules
$a1 = [string](@($r.Lines | Where-Object { $_ -cmatch '^A1\s' }) | Select-Object -First 1)
Chk 'D6' ((Test-Only $r @('A1')) -and $a1.Contains('empreintes sans bloc : 1')) "bloc Add-Type modifie sans mise a jour de la liste : $(Get-Bad $r) ; bloc nouveau et empreinte orpheline signales"

Set-Ps 'src\GreaseweazleGUI.ps1' ($m000 + $m010 + $m030 + $m100 + @('function Get-Autre { return (T ''Sans traduction'') }'))
$r = Invoke-Check 'D7'; $r1 = Invoke-Check 'D7-seuil' 1; $rd = Invoke-Check 'D7-defaut' -1; Set-Modules
Chk 'D7' ((Test-Only $r @('I1')) -and (Test-Only $r1 @()) -and @($r.Lines | Where-Object { $_ -like '*sans traduction : Sans traduction*' }).Count -eq 1) "cle T() sans traduction, seuil 0 : $(Get-Bad $r) ; cle nommee ; seuil 1 : $(Get-Bad $r1)"
Chk 'D7b' ((Test-Only $rd @('I1')) -and @($rd.Lines | Where-Object { $_ -like '*(au plus 0)*' }).Count -eq 1) "cle T() sans traduction, seuil par defaut du controle (0 depuis la 12.11, aucun -MaxI18nMissing transmis) : $(Get-Bad $rd)"

# S2 : syntaxe propre a PowerShell 7 dans un module (fichier analyse, jamais execute). Joue sous PowerShell 7 seulement :
# sous Windows PowerShell 5.1, la meme ligne est une erreur de syntaxe, que S1 signale (cas D4)
if ($PSVersionTable.PSEdition -ne 'Core') { '  D14 saute (jetons de PowerShell 7 : joue sous PowerShell 7 seulement)' }
else {
    Set-Ps 'src\modules\100-fn-salut.ps1' ($m100 + @('function Get-Choix($a) { return ($a ? 1 : 2) }'))
    $r = Invoke-Check 'D14'; Set-Modules
    Chk 'D14' (Test-Only $r @('S2')) "syntaxe propre a PowerShell 7 dans un module : $(Get-Bad $r)"
}

# Chemin et adresse en morceaux : ce fichier ne doit pas etre signale par le controle P1 du depot
$poste = 'C:' + '\Users\' + 'quelquun\lecture.scp'
Set-Ps 'tests\logic-factice.ps1' @("`$f = '$poste'")
$r = Invoke-Check 'D8'
Chk 'D8' ((Test-Only $r @('P1')) -and @($r.Lines | Where-Object { $_.Contains('quelquun') }).Count -eq 0) "chemin du poste dans un test : $(Get-Bad $r) ; texte trouve non affiche"
$mail = 'quelquun' + '@' + 'exemple.org'
Set-Ps 'tests\logic-factice.ps1' @("`$f = '$mail'")
$r = Invoke-Check 'D9'; Set-Ps 'tests\logic-factice.ps1' @('''test factice''')
Chk 'D9' (Test-Only $r @('P1')) "adresse de messagerie dans un test : $(Get-Bad $r)"
# Autres formes, en morceaux elles aussi : barres obliques, forme echappee, forme de Git Bash, partage reseau (nom court,
# nom qualifie), adresses privees hors 192.168
$formes = @(
    @{ Id = 'D10'; N = 'chemin du poste a barres obliques'; T = ('C:' + '/Users/' + 'quelquun/lecture.scp') },
    @{ Id = 'D11'; N = 'chemin du poste echappe'; T = ('C:' + '\\Users\\' + 'quelquun\\lecture.scp') },
    @{ Id = 'D11b'; N = 'chemin du poste sous Git Bash'; T = ('/c' + '/Users/' + 'quelquun/lecture.scp') },
    @{ Id = 'D12'; N = 'partage reseau'; T = ('\\' + 'serveur\partage\' + 'lecture.scp') },
    @{ Id = 'D12b'; N = 'partage reseau, nom qualifie'; T = ('\\' + 'serveur.exemple.test\partage\' + 'lecture.scp') },
    @{ Id = 'D13'; N = 'adresse de reseau prive 10.x'; T = ('10.' + '20.30.40') },
    @{ Id = 'D13b'; N = 'adresse de reseau prive 172.16 a 172.31'; T = ('172.' + '16.4.9') }
)
foreach ($fm in $formes) {
    Set-Ps 'tests\logic-factice.ps1' @("`$f = '$($fm.T)'")
    $r = Invoke-Check $fm.Id
    Chk $fm.Id ((Test-Only $r @('P1')) -and @($r.Lines | Where-Object { $_.Contains('quelquun') -or $_.Contains('serveur') }).Count -eq 0) "$($fm.N) dans un test : $(Get-Bad $r) ; texte trouve non affiche"
}
# Numeros de version a plusieurs nombres, adresse publique : pas des adresses de reseau prive
Set-Ps 'tests\logic-factice.ps1' @("`$f = 'versions 12.10.20.30 et 1.10.20.30.40, adresse 11.20.30.40'")
$r = Invoke-Check 'D13c'; Set-Ps 'tests\logic-factice.ps1' @('''test factice''')
Chk 'D13c' (Test-Only $r @()) "numeros de version a plusieurs nombres et adresse publique dans un test, non signales : $(Get-Bad $r)"
# P1 lit aussi les modules, les outils et les documents (chemin a barres obliques, en morceaux)
$slash = 'C:' + '/Users/' + 'quelquun/lecture.scp'
Set-Ps 'src\modules\100-fn-salut.ps1' ($m100 + @("# lu dans $slash"))
$r = Invoke-Check 'D15'; Set-Modules
Chk 'D15' (Test-Only $r @('P1')) "chemin du poste dans un module : $(Get-Bad $r)"
Set-Ps 'tools\Outil.ps1' @("'outil factice, $slash'")
$r = Invoke-Check 'D16'; Set-Ps 'tools\Outil.ps1' @('''outil factice''')
Chk 'D16' (Test-Only $r @('P1')) "chemin du poste dans un outil : $(Get-Bad $r)"
Set-Doc 'CHANGELOG.md' "# Journal factice`n`nLecture de $slash`n"
$r = Invoke-Check 'D17'; Set-Doc 'CHANGELOG.md' "# Journal factice`n"
Chk 'D17' (Test-Only $r @('P1')) "chemin du poste dans le CHANGELOG : $(Get-Bad $r)"

$nk = ''; if ($script:Fail) { $nk = ' ; non conformes : ' + (@($script:FailIds) -join ', ') }
"=== bilan logic-controle-source : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
