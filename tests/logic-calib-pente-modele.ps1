param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Prof = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-slope) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out. Profil synthetique par defaut ; -Prof <fichier> rejoue un profil reel.
# 12.10 (v1210\slope) : erreur de modele aux forts besoins (Get-VerifySlope, 240 ; cablage 270 ; constantes 560 ; CalibCalc
# 12.10). Fonctions reelles extraites par l arbre syntaxique (gen-1210-slope.ps1) : 240 Get-VerifySlope, 230 Get-Median ;
# constantes CalSlope* (560) et CalibCalc (000) extraites. Unite simulee : profil d un lecteur a fort besoin (58 a
# 215 ns ; synthetique dans le depot), residus = droite + bruit deterministe. Aucun gw, aucune application, aucune fenetre.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR')
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mods = Join-Path $Wt 'src\modules'
function Get-SlAst([string]$path) {
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message) (ligne $(@($er)[0].Extent.StartLineNumber))" }
    return $ast
}
function Get-SlFn([string]$path, [string]$name) {
    foreach ($fd in (Get-SlAst $path).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) { if ($fd.Name -eq $name) { return $fd } }
    throw "fonction $name introuvable dans $path"
}
function Get-SlAssign([string]$path, [string]$left) {
    $st = @((Get-SlAst $path).EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left.Extent.Text -eq $left })
    if ($st.Count -ne 1) { throw "affectation $left dans $path : $($st.Count) (1 attendue)" }
    return $st[0].Extent.Text
}
$parts = New-Object System.Collections.Generic.List[string]
$fd = Get-SlFn (Join-Path $mods '240-fn-calib-mesure.ps1') 'Get-VerifySlope'; $parts.Add($fd.Extent.Text); $lineFn = $fd.Extent.StartLineNumber
$parts.Add((Get-SlFn (Join-Path $mods '230-fn-calib-courbe.ps1') 'Get-Median').Extent.Text)
foreach ($k in 'CalSlopeOn', 'CalSlopeMinCyl', 'CalSlopeMinNsNs', 'CalSlopeSigK', 'CalSlopeMinNs', 'CalCoarse') { $parts.Add((Get-SlAssign (Join-Path $mods '560-etat-calibration.ps1') "`$script:$k")) }
$parts.Add((Get-SlAssign (Join-Path $mods '000-entete.ps1') '$script:CalibCalc'))
$gen = Join-Path $here 'gen-1210-slope.ps1'
[System.IO.File]::WriteAllText($gen, ((@($parts) -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
. $gen
$script:CalHardNs = 400.0

# ---------------------------------------------------------------- unite simulee
# 12.11 : profil synthetique par defaut (aucune donnee de lecteur dans le depot) : c0 a c43 : 60 + 2,2 c ; c44 a c79 :
# 58 + 4,5 (c - 44) ; valeurs arrondies vers le bas, de 58 a 215 ns. -Prof : fichier « c=ns:c=ns... » d un profil reel.
$vals = New-Object int[] 80
if ($Prof) {
    $txt = [System.IO.File]::ReadAllText($Prof).Trim()
    $ent = @($txt.Split(':') | ForEach-Object { $a = $_.Split('='); ,@([int]$a[0], [int]$a[1]) } | Sort-Object { $_[0] })   # virgule : un tableau par entree, non deroule
    $cur = $ent[0][1]; $j = 0
    for ($c = 0; $c -lt 80; $c++) { while ($j -lt $ent.Count -and $ent[$j][0] -le $c) { $cur = $ent[$j][1]; $j++ }; $vals[$c] = $cur }
} else {
    for ($c = 0; $c -lt 80; $c++) { $vals[$c] = if ($c -le 43) { [int][math]::Floor((600 + 22 * $c) / 10.0) } else { [int][math]::Floor((116 + 9 * ($c - 44)) / 2.0) } }
}
function Noise([int]$c) { return 0.9 * [math]::Sin(1.7 * $c) + 0.6 * [math]::Cos(0.37 * $c * $c) }   # bruit deterministe, environ +-1,3 ns
function New-Unit([scriptblock]$shiftOf, [int[]]$outliers = @(), $profile = $null) {
    $pv = if ($null -ne $profile) { $profile } else { $vals }
    $u = @{ Fit = @{ Values = [int[]]$pv }; Verify = @{}; VerifyP = @{}; Outliers = [int[]]$outliers; Est = @{} }
    for ($c = 0; $c -lt $pv.Count; $c++) { $u.Verify[$c] = @{ Shift = [double](& $shiftOf $c ([double]$pv[$c])); SE = 1.0; Score = 0 }; $u.VerifyP[$c] = [int]$pv[$c]; $u.Est[$c] = [double]$pv[$c] }
    return $u
}
$B = -0.0475; $A100 = 2.1      # TEAC tete 0 (pente.py sur l essai 5 : -0,0475 ns/ns ; niveau +2,1 ns a 100 ns)
$teac = { param($c, $p) $A100 + $B * ($p - 100.0) + (Noise $c) }
$flat = { param($c, $p) -0.7 + (Noise $c) }
$nAbove = @(0..79 | Where-Object { $vals[$_] -gt 100 }).Count

# ---------------------------------------------------------------- controles et sortie
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    if (-not $ok) { $script:Fail++; $script:FailIds += $id }
    '{0,-8} {1,-12} {2}' -f $id, $(if ($ok) { 'conforme' } else { 'NON CONFORME' }), $d
}
function F([double]$x, [string]$f = '0.000') { return $x.ToString($f, [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR')) }
"logic-1210-slope : Get-VerifySlope 240:$lineFn ; CalibCalc $($script:CalibCalc) ; constantes On $($script:CalSlopeOn) MinCyl $($script:CalSlopeMinCyl) MinNsNs $($script:CalSlopeMinNsNs) SigK $($script:CalSlopeSigK) MinNs $($script:CalSlopeMinNs) ; profil $(if ($Prof) { 'lu par -Prof' } else { 'synthetique' }) : $nAbove cylindres au-dela de 100 ns ; PowerShell $($PSVersionTable.PSVersion)"

"--- A : constantes et version"
Chk 'A1' ($script:CalibCalc -eq '12.10') "CalibCalc $($script:CalibCalc) (12.10 attendu)"
Chk 'A2' ($script:CalSlopeOn -eq $true -and $script:CalSlopeMinCyl -eq 10 -and [math]::Abs($script:CalSlopeMinNsNs - 0.02) -lt 1e-9 -and $script:CalSlopeSigK -eq 2.5 -and $script:CalSlopeMinNs -eq 2.0) 'constantes CalSlope* aux valeurs de conception (SigK 2,5 depuis le banc 1210-b)'

"--- T : lecteur a fort besoin (pente -0,0475 ns/ns, bruit +-1,3 ns)"
$u = New-Unit $teac
$r = Get-VerifySlope $u -1.0 $script:CalSlopeMinCyl $script:CalSlopeSigK $script:CalSlopeMinNsNs $script:CalSlopeMinNs
Chk 'T1' ($r.Ok -and $r.N -eq $nAbove -and $r.X0 -eq 100.0) "Ok $($r.Ok), N $($r.N) ($nAbove attendus), X0 $($r.X0), Why « $($r.Why) »"
Chk 'T2' ([math]::Abs($r.B - $B) -lt 0.006 -and [math]::Abs($r.A - $A100) -lt 0.8) "pente $(F $r.B) (attendue $(F $B)), niveau a 100 ns $(F $r.A '0.00') (attendu $(F $A100 '0.00')), incertitude $(F $r.SB)"
Chk 'T3' ($r.SB -gt 0 -and $r.SB -lt 0.012 -and [math]::Abs($r.B) -gt 2 * $r.SB) "incertitude $(F $r.SB) : pente a $(F ([math]::Abs($r.B) / $r.SB) '0.0') erreurs-types"
$expBad = @(0..79 | Where-Object { $vals[$_] -gt 100 -and [math]::Abs($A100 + $B * ($vals[$_] - 100.0)) -gt 2.0 })
$gotBad = @($r.Bad.Keys | ForEach-Object { [int]$_ } | Sort-Object)
$diff = @(Compare-Object $expBad $gotBad -PassThru)
Chk 'T4' ($gotBad.Count -gt 0 -and $diff.Count -le 2) "cylindres a corriger : $($gotBad.Count) ($($expBad.Count) par la droite exacte ; ecart $($diff.Count)) : $(($gotBad | ForEach-Object { "c$_" }) -join ' ')"
Chk 'T5' ($r.Fit.Count -eq $nAbove -and $r.PMin -gt 100 -and $r.PMax -eq 215 -and $r.FMax -lt -2.5 -and $r.FMax -gt -4.5 -and $r.FMin -gt 1.0) "Fit sur $($r.Fit.Count) cylindres ; valeurs ecrites $($r.PMin) a $($r.PMax) ns ; droite $(F $r.FMin '0.0') a $(F $r.FMax '0.0') ns"
# cylindres au-dela du niveau mesure dans la tolerance de 4 ns mais corriges par la tendance : au moins les plus interieurs
Chk 'T6' (@($gotBad | Where-Object { $_ -ge 74 }).Count -ge 4 -and -not $r.Bad.ContainsKey(60)) "c74-c79 retenus $(@($gotBad | Where-Object { $_ -ge 74 }).Count)/6, c60 (droite $(F $r.Fit[60] '0.0') ns) non retenu"

"--- F : sans pente (meme lecteur, residus plats) et exclusions"
$u2 = New-Unit $flat
$r2 = Get-VerifySlope $u2 -1.0 $script:CalSlopeMinCyl $script:CalSlopeSigK $script:CalSlopeMinNsNs $script:CalSlopeMinNs
Chk 'F1' (-not $r2.Ok -and $r2.N -eq $nAbove -and ($r2.Why -eq 'faible' -or $r2.Why -eq 'nonsig') -and $r2.Bad.Count -eq 0) "Ok $($r2.Ok), Why « $($r2.Why) », pente $(F $r2.B), incertitude $(F $r2.SB), Bad $($r2.Bad.Count)"
$u3 = New-Unit $teac @(70, 75)
$u3.Verify[70].Shift = 40.0; $u3.Verify[75].Shift = -40.0
$r3 = Get-VerifySlope $u3 -1.0 $script:CalSlopeMinCyl $script:CalSlopeSigK $script:CalSlopeMinNsNs $script:CalSlopeMinNs
Chk 'F2' ($r3.Ok -and $r3.N -eq $nAbove - 2 -and [math]::Abs($r3.B - $B) -lt 0.006 -and -not $r3.Bad.ContainsKey(70) -and -not $r3.Bad.ContainsKey(75)) "points isoles exclus : N $($r3.N), pente $(F $r3.B), c70/c75 hors Bad"
$u4 = New-Unit $teac
$u4.VerifyP[79] = 400; $u4.Verify[79].Shift = 5.0           # au plafond, encore sous-compense : limite physique, exclu
$r4 = Get-VerifySlope $u4 -1.0 $script:CalSlopeMinCyl $script:CalSlopeSigK $script:CalSlopeMinNsNs $script:CalSlopeMinNs
Chk 'F3' ($r4.N -eq $nAbove - 1 -and -not $r4.Fit.ContainsKey(79)) "plafond exclu : N $($r4.N)"
$sony = New-Object int[] 80; for ($c = 0; $c -lt 80; $c++) { $sony[$c] = 8 + [int]($c * 0.75) }    # faible besoin : 8 a 67 ns
$u5 = New-Unit $teac @() $sony
$r5 = Get-VerifySlope $u5 -1.0 $script:CalSlopeMinCyl $script:CalSlopeSigK $script:CalSlopeMinNsNs $script:CalSlopeMinNs
Chk 'F4' (-not $r5.Ok -and $r5.Why -eq 'cylindres' -and $r5.N -eq 0) "faible besoin (tout <= 100 ns) : Why « $($r5.Why) », N $($r5.N)"
$u6 = New-Unit $teac
foreach ($c in 0..79) { if ($vals[$c] -gt 100 -and $c -lt 75) { [void]$u6.Verify.Remove($c) } }   # 5 cylindres au-dela de 100 seulement (c75-c79)
$r6 = Get-VerifySlope $u6 -1.0 $script:CalSlopeMinCyl $script:CalSlopeSigK $script:CalSlopeMinNsNs $script:CalSlopeMinNs
Chk 'F5' (-not $r6.Ok -and $r6.Why -eq 'cylindres' -and $r6.N -lt $script:CalSlopeMinCyl) "trop peu de cylindres : N $($r6.N), Why « $($r6.Why) »"
$u7 = New-Unit { param($c, $p) 0.5 + 0.012 * ($p - 100.0) + (Noise $c) }
$r7 = Get-VerifySlope $u7 -1.0 $script:CalSlopeMinCyl $script:CalSlopeSigK $script:CalSlopeMinNsNs $script:CalSlopeMinNs
Chk 'F6' (-not $r7.Ok -and $r7.Why -eq 'faible' -and $r7.Bad.Count -eq 0) "pente +0,012 ns/ns sous le minimum : Why « $($r7.Why) », pente $(F $r7.B)"
$u8 = New-Unit $teac
$r8 = Get-VerifySlope $u8 -1.0 $script:CalSlopeMinCyl 50.0 $script:CalSlopeMinNsNs $script:CalSlopeMinNs
Chk 'F7' (-not $r8.Ok -and $r8.Why -eq 'nonsig' -and $r8.Bad.Count -eq 0) "exigence de 50 erreurs-types : Why « $($r8.Why) »"

"--- S : cablage (270), unite (240), textes (018)"
$s270 = [System.IO.File]::ReadAllText((Join-Path $mods '270-fn-calib-complete.ps1'))
$i1 = $s270.IndexOf('$sp = Get-VerifySlope $u ([double]$cal.MaxCoarse)'); $i2 = $s270.IndexOf('$fl = Get-ResidualFlags $u'); $i3 = $s270.IndexOf('if ($u.SlopeBad -and $u.SlopeBad.Count -gt 0) {')   # 12.10 (asym) : niveau maximal de la famille passe explicitement
Chk 'S1' ($s270.Contains('Slope = [bool]$script:CalSlopeOn') -and $i1 -gt 0 -and $s270.Contains('[bool]$cal.Slope -and $null -ne $u.Fit') -and $s270.Contains('if ($sp.Ok -and $sp.Bad.Count -gt 0) {') -and $s270.Contains('$u.SlopeBad = $sp.Bad') -and $s270.Contains('elseif ($sp.Ok) { Append-Log')) 'drapeau du bareme, appel a la verification complete, SlopeBad pose seulement avec des cylindres a corriger, ligne « aucune correction » sinon'
Chk 'S2' ($i2 -gt 0 -and $i3 -gt $i2 -and $i3 - $i2 -lt 600 -and $s270.Contains('$fl.Bad[[int]$c] = $true') -and $s270.Contains('$fl.Spot = @($fl.Spot | Where-Object { -not $u.SlopeBad.ContainsKey([int]$_) })')) 'cylindres de la tendance ajoutes aux retenus juste apres Get-ResidualFlags, retires des ecarts locaux'
$s240 = [System.IO.File]::ReadAllText((Join-Path $mods '240-fn-calib-mesure.ps1'))
Chk 'S3' ($s240.Contains('VOff = $null; VSlope = $null; SlopeBad = $null }')) 'New-CalibUnit : VSlope et SlopeBad'
$keys = New-Object System.Collections.Generic.HashSet[string]
foreach ($f in (Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1')) {
    $t = [System.IO.File]::ReadAllText($f.FullName)
    foreach ($mm in [regex]::Matches($t, "\`$script:I18n\[`"([^`"]*)`"\]")) { [void]$keys.Add($mm.Groups[1].Value) }
}
$blk = $s270.Substring($i1, $s270.IndexOf("if (`$cal.Stage -eq 'level') { Write-LevelPassLog", $i1) - $i1)
$used = @([regex]::Matches($blk, "\(T `"([^`"]*)`"\)") | ForEach-Object { $_.Groups[1].Value })
$missing = @($used | Where-Object { -not $keys.Contains($_) })
Chk 'S4' ($used.Count -eq 3 -and $missing.Count -eq 0) "$($used.Count) textes T() du bloc (3 attendus), $($missing.Count) sans traduction"
$ch = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'))
Chk 'S5' ($ch.Contains('**Lecteurs à fort besoin : erreur de modèle corrigée à la vérification.**') -and $ch.Contains('**Calibrations double densité à refaire.**') -and $ch.Contains('`CalibCalc` passe à 12.10') -and -not $ch.Contains('**Rien à recalibrer.**')) 'CHANGELOG : amelioration, a savoir, developpeurs, plus de « Rien a recalibrer »'

$nk = if ($script:Fail) { ' ; non conformes : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-1210-slope : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
