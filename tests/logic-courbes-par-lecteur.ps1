param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-drivecurves-e3) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out.
# 12.10 (v1210\croisee\etape3 : copie de logic-1210-drivecurves-e2, S3 adapte au gestionnaire du bandeau sans la correction
# Dk, « Update-TargetDriveUi; Update-SlowUi ») ; 12.10 (v1210\croisee\etape2, copie adaptee du test de l etape 1 par la relecture de l etape 2 : S1 attend le lecteur de magasin Get-CalibStoreDrive, Split-CrossDrive et Get-CalibStoreDrive extraits avec le magasin (Get-DriveCurveLabel nomme les deux lecteurs d une cle croisee)) : courbes de calibration par lecteur (conception croisee § 2). Fonctions reelles extraites par
# l arbre syntaxique (gen-1210-drivecurves-e3.ps1) : 240 magasin et vue (Get-DriveCurveKey, Split-DriveCurveKey, Get-DriveCurve,
# Set-DriveCurve, Sync-PrecompCurves, Get-DriveCurveKeys, Get-DriveCurveLabel, Get-CurveKeyLabel), 230 configuration des courbes
# (ConvertTo/ConvertFrom-CurveConfig, Get-CurveCalc, Get-CurveCalcRef, Test-CurveCalcOk, Test-CurveHd, Get-CalibFamilyName),
# 120 configuration par lecteur (Import-DriveCurves, Export-DriveCurves, Export-CurveView, Get-Cfg), 250 copie d etat
# (Get-CalibSnapshot, Restore-CalibState) ; constantes CurveKeys (560), CalibCalc et CalibCalcHd (000), profils d origine (040).
# Remplacants nommes : T, Append-Log (journal en memoire), Get-WProfileText, Update-PrecompForImage (compte), Save-Config
# (compte), controles en pscustomobject. Aucun gw, aucune application, aucune fenetre.
#  A : magasin et vue (ecriture, lecteur courant, autre lecteur, retrait, changement de lecteur, profils de famille, cles, libelles)
#  B : migration d une configuration 12.9 a deux lecteurs (courbe sans lecteur, courbe d un autre calcul mise de cote)
#  C : bloc driveCurves (export, aller-retour JSON, bloc 12.9 ignore, vue du lecteur courant pour une 12.9)
#  D : copie d etat et retablissement par lecteur (cles de magasin, cles de courbe)
#  S : cablage (fin de calibration, gestionnaire du bandeau, configuration, aucune ecriture directe de la vue, textes, CHANGELOG, README)
#  E : relecture (08/11/2026) : bloc driveCurves (courbe sans lecteur, cle croisee, cles illisibles), retablissement d une copie d un
#      autre lecteur (profils du bandeau intacts), niveaux abandonnes du seul lecteur calibre (boucle reelle de Complete-PrecompCalib),
#      niveaux relus par lecteur (boucle reelle de Load-Config), copie .bak sur cles de magasin (Backup-ConfigBeforeRef, fichier
#      temporaire), export sans courbe, cablage 250/270/290, cle i18n retiree
#  F : relecture 2 (08/11/2026) : profil de famille au chargement (instructions reelles de Load-Config) : courbe commune sous un autre
#      lecteur que celui de la configuration, reprise ou mise de cote : rien de « perdu » ; aucune courbe : profil calibre sans courbe
#      signale ; cle croisee seule non comptee ; CHANGELOG
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mods = Join-Path $Wt 'src\modules'
function Get-DcAst([string]$path) {
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message) (ligne $(@($er)[0].Extent.StartLineNumber))" }
    return $ast
}
function Get-DcFn([string]$path, [string]$name) {
    foreach ($fd in (Get-DcAst $path).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) { if ($fd.Name -eq $name) { return $fd.Extent.Text } }
    throw "fonction $name introuvable dans $path"
}
function Get-DcAssign([string]$path, [string]$left) {
    $st = @((Get-DcAst $path).EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left.Extent.Text -eq $left })
    if ($st.Count -ne 1) { throw "affectation $left dans $path : $($st.Count) (1 attendue)" }
    return $st[0].Extent.Text
}
function Get-DcStmt([string]$path, [string]$fn, [string]$typeName, [string]$startsWith, [string]$contains) {
    # Texte d une instruction d une fonction, par son type d arbre syntaxique, son debut et son contenu : la plus large qui convient
    $fd = @((Get-DcAst $path).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) | Where-Object { $_.Name -eq $fn })
    if ($fd.Count -ne 1) { throw "fonction $fn dans $path : $($fd.Count) (1 attendue)" }
    $hits = @($fd[0].Body.FindAll({ param($x) $x.GetType().Name -eq $typeName -and (-not $startsWith -or $x.Extent.Text.StartsWith($startsWith)) -and (-not $contains -or $x.Extent.Text.Contains($contains)) }, $true) | Sort-Object { $_.Extent.Text.Length } -Descending)
    if ($hits.Count -eq 0) { throw "instruction $typeName introuvable dans $fn ($startsWith / $contains)" }
    return $hits[0].Extent.Text
}
$parts = New-Object System.Collections.Generic.List[string]
foreach ($n in 'Get-CurveKeyLabel', 'Get-DriveCurveKey', 'Split-DriveCurveKey', 'Get-DriveCurve', 'Set-DriveCurve', 'Sync-PrecompCurves', 'Get-DriveCurveKeys', 'Get-DriveCurveLabel', 'Split-CrossDrive', 'Get-CalibStoreDrive', 'Get-CalibUnitKey') { $parts.Add((Get-DcFn (Join-Path $mods '240-fn-calib-mesure.ps1') $n)) }
foreach ($n in 'ConvertTo-CurveConfig', 'ConvertFrom-CurveConfig', 'Get-CurveCalc', 'Get-CurveCalcRef', 'Test-CurveCalcOk', 'Test-CurveHd', 'Get-CalibFamilyName', 'ConvertTo-LevelConfig', 'ConvertFrom-LevelConfig') { $parts.Add((Get-DcFn (Join-Path $mods '230-fn-calib-courbe.ps1') $n)) }
foreach ($n in 'Import-DriveCurves', 'Export-DriveCurves', 'Export-CurveView', 'Get-Cfg', 'Backup-ConfigBeforeRef') { $parts.Add((Get-DcFn (Join-Path $mods '120-fn-configuration.ps1') $n)) }
foreach ($n in 'Get-CalibSnapshot', 'Restore-CalibState') { $parts.Add((Get-DcFn (Join-Path $mods '250-fn-calib-fenetres.ps1') $n)) }
$parts.Add((Get-DcFn (Join-Path $mods '220-fn-profil-precomp.ps1') 'Get-CurveDate'))
$parts.Add((Get-DcAssign (Join-Path $mods '560-etat-calibration.ps1') '$script:ConfigRefBackupKeep'))
# Relecture : boucles reelles de Complete-PrecompCalib (abandon des niveaux a une nouvelle reference) et de Load-Config (niveaux relus),
# enveloppees dans une fonction du fichier genere (variables locales du code reel : $dropped, $oldLv, $w, $old)
$parts.Add("function Test-DropLevels(`$cal) {`r`n    `$dropped = @()`r`n    " + (Get-DcStmt (Join-Path $mods '270-fn-calib-complete.ps1') 'Complete-PrecompCalib' 'ForEachStatementAst' 'foreach ($u in $cal.Units) {' 'LevelShifts.Remove') + "`r`n    return @(`$dropped)`r`n}")
$parts.Add("function Test-LoadLevels(`$w, `$old) {`r`n    `$script:LevelShifts = @{}; `$oldLv = @{}`r`n    " + (Get-DcStmt (Join-Path $mods '120-fn-configuration.ps1') 'Load-Config' 'IfStatementAst' 'if (@(''lvl1'', ''lvl2'') -contains [string](Get-Cfg $w ''levelAlgo'' '''')) {' '') + "`r`n    return @{ Lv = `$script:LevelShifts; OldLv = `$oldLv }`r`n}")
# Relecture 2 : profil de famille au chargement (quatre instructions reelles de Load-Config : $anyStd, $anyLong, les deux if)
$p120 = Join-Path $mods '120-fn-configuration.ps1'
$parts.Add("function Test-LoadProfiles(`$old, [string]`$ldDrive, [string]`$cfgStd, [string]`$cfgLong) {`r`n    `$oldStd = `$null; `$oldLong = `$null; `$lostProf = `$false`r`n    " +
    (Get-DcStmt $p120 'Load-Config' 'AssignmentStatementAst' '$anyStd = ' '') + "`r`n    " + (Get-DcStmt $p120 'Load-Config' 'AssignmentStatementAst' '$anyLong = ' '') + "`r`n    " +
    (Get-DcStmt $p120 'Load-Config' 'IfStatementAst' 'if (-not $script:PrecompCurves[''std''])' '') + "`r`n    " + (Get-DcStmt $p120 'Load-Config' 'IfStatementAst' 'if (-not $script:PrecompCurves[''long''])' '') +
    "`r`n    return @{ OldStd = `$oldStd; OldLong = `$oldLong; Lost = `$lostProf; AnyStd = `$anyStd; AnyLong = `$anyLong }`r`n}")
$parts.Add((Get-DcAssign (Join-Path $mods '560-etat-calibration.ps1') '$script:CurveKeys'))
$parts.Add((Get-DcAssign (Join-Path $mods '560-etat-calibration.ps1') '$script:DriveCurves'))
$parts.Add((Get-DcAssign (Join-Path $mods '560-etat-calibration.ps1') '$script:PrecompCurves'))
foreach ($k in 'CalibCalc', 'CalibCalcHd') { $parts.Add((Get-DcAssign (Join-Path $mods '000-entete.ps1') "`$script:$k")) }
foreach ($k in 'PrecompStd', 'PrecompLong', 'PrecompStdDefault', 'PrecompLongDefault') { $parts.Add((Get-DcAssign (Join-Path $mods '040-etat-formats.ps1') "`$script:$k")) }
$gen = Join-Path $here 'gen-1210-drivecurves-e3.ps1'
[System.IO.File]::WriteAllText($gen, ((@($parts) -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
. $gen

# ---------------------------------------------------------------- remplacants
function T([string]$s) { return $s }
$script:Log = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text) { $script:Log.Add($text) }
function Get-WProfileText { return $lblWProfileInfo.Text }
$script:NUpd = 0; $script:NSave = 0
function Update-PrecompForImage([string]$path) { $script:NUpd++ }
function Save-Config { $script:NSave++; return $true }
$cmbDrive = [pscustomobject]@{ Text = 'A' }
$cmbWProfile = [pscustomobject]@{ SelectedIndex = 0 }
$chkWPrecomp = [pscustomobject]@{ Checked = $true }
$txtWPrecomp = [pscustomobject]@{ Text = '0=1' }; $txtWPrecomp1 = [pscustomobject]@{ Text = '0=2' }
$lblWProfileInfo = [pscustomobject]@{ Text = 'profil' }
$script:Restore = $null; $script:CurveForm = $null; $script:LevelShifts = @{}; $script:WTabNotice = $null

$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    if (-not $ok) { $script:Fail++; $script:FailIds += $id }
    '{0,-8} {1,-12} {2}' -f $id, $(if ($ok) { 'conforme' } else { 'NON CONFORME' }), $d
}
function New-Cv([string]$drive, [string]$fam, $head, [string]$date, [string]$spec, [string]$calc = '', [int]$bits = 100000) {
    # Courbe simulee complete (champs lus par ConvertTo-CurveConfig) ; calcul : celui de la famille par defaut
    if (-not $calc) { $calc = $(if ($bits -ge 150000) { $script:CalibCalcHd } else { $script:CalibCalc }) }
    $vals = [int[]]@(0..79 | ForEach-Object { 40 + $_ })
    return @{ Family = (Get-CalibFamilyName $fam); Head = $head; Drive = $drive; Target = ''; Date = $date; Model = 'M1'; Spec = $spec; Method = 'motif'
              Version = '12.10'; Algo = 'a'; Calc = $calc; Breaks = [int[]]@(); Values = $vals; Cyls = [int[]]@(0, 40, 79); Ys = [double[]]@(40.0, 80.0, 119.0); Sig = [double[]]@(3.0, 3.0, 3.0)
              Kinds = [string[]]@('zero', 'zero', 'zero'); Res = [double[]]@(0.5, -0.5, 0.0); Converged = $true; MaxX = 300; MaxNs = 400; Slope = 0.8; Bits = $bits; Test = 'fine'
              Contra = [int[]]@(); DentLo = [int[]]@(); DentHi = [int[]]@(); DentNs = [double[]]@() }
}
function Test-CvSame($a, $b) {
    if ($null -eq $a -or $null -eq $b) { return ($null -eq $a -and $null -eq $b) }
    return ((@($a.Values) -join ',') -eq (@($b.Values) -join ',') -and [string]$a.Drive -eq [string]$b.Drive -and [string]$a.Date -eq [string]$b.Date -and [string]$a.Spec -eq [string]$b.Spec -and [string]$a.Target -eq [string]$b.Target -and [string]$a.Calc -eq [string]$b.Calc -and [string]$a.Head -eq [string]$b.Head)
}
"logic-1210-drivecurves-e3 : CalibCalc $($script:CalibCalc), CalibCalcHd $($script:CalibCalcHd), cles $($script:CurveKeys -join '/') ; PowerShell $($PSVersionTable.PSVersion)"

"--- A : magasin et vue"
$cvA0 = New-Cv 'A' 'std' 0 '01/11/2026 17:49' '0=10:40=50'
$cvA1 = New-Cv 'A' 'std' 1 '01/11/2026 17:49' '0=12:40=55'
$cv00 = New-Cv '0' 'std' 0 '02/11/2026 10:00' '0=60:40=120'
$cvAc = New-Cv 'A' 'std' $null '30/10/2026 09:00' '0=20:40=60'
Set-DriveCurve 'A' 'std_h0' $cvA0
Chk 'A1' ($script:DriveCurves.ContainsKey('A|std_h0') -and [object]::ReferenceEquals($script:PrecompCurves['std_h0'], $cvA0)) "lecteur courant A : magasin « A|std_h0 » et vue std_h0 ecrits"
Set-DriveCurve '0' 'std_h0' $cv00
Chk 'A2' ($script:DriveCurves.ContainsKey('0|std_h0') -and [object]::ReferenceEquals($script:PrecompCurves['std_h0'], $cvA0)) "autre lecteur 0 : magasin « 0|std_h0 » ecrit, vue du lecteur A inchangee"
Set-DriveCurve 'A' 'std_h1' $cvA1; Set-DriveCurve 'A' 'std' $cvAc
Sync-PrecompCurves
Chk 'A3' ([object]::ReferenceEquals($script:PrecompCurves['std_h0'], $cvA0) -and [object]::ReferenceEquals($script:PrecompCurves['std'], $cvAc) -and $null -eq $script:PrecompCurves['long'] -and $script:PrecompStd -eq '0=20:40=60' -and $script:PrecompLong -eq $script:PrecompLongDefault) "Sync lecteur A : vue des trois courbes, long $null ; PrecompStd = Spec de la courbe commune ($($script:PrecompStd)), PrecompLong d origine"
$cmbDrive.Text = '0'; Sync-PrecompCurves
Chk 'A4' ([object]::ReferenceEquals($script:PrecompCurves['std_h0'], $cv00) -and $null -eq $script:PrecompCurves['std_h1'] -and $null -eq $script:PrecompCurves['std'] -and $script:PrecompStd -eq $script:PrecompStdDefault) "changement de lecteur (0) : vue std_h0 du lecteur 0, std_h1 et std $null, PrecompStd d origine ($($script:PrecompStd))"
Set-DriveCurve 'A' 'std_h0' $null
Chk 'A5' (-not $script:DriveCurves.ContainsKey('A|std_h0') -and [object]::ReferenceEquals($script:PrecompCurves['std_h0'], $cv00)) "retrait « A|std_h0 » (courbe $null) : entree retiree, vue du lecteur 0 inchangee"
$cmbDrive.Text = 'A'; Sync-PrecompCurves
Chk 'A6' ($null -eq $script:PrecompCurves['std_h0'] -and [object]::ReferenceEquals($script:PrecompCurves['std_h1'], $cvA1)) "retour au lecteur A : std_h0 $null, std_h1 presente"
Set-DriveCurve '0' 'std_h0' $null; Set-DriveCurve '0' 'std_h0' $null
Chk 'A7' ((@(Get-DriveCurveKeys) -join ',') -eq 'A|std,A|std_h1' -and (@(Get-DriveCurveKeys 'A') -join ',') -eq 'A|std,A|std_h1' -and @(Get-DriveCurveKeys '0').Count -eq 0 -and $null -eq (Get-DriveCurve '0' 'std_h0') -and (Get-DriveCurve 'A' 'std').Spec -eq '0=20:40=60') "cles triees $(@(Get-DriveCurveKeys) -join ','), par lecteur, double retrait sans erreur, Get-DriveCurve"
$sp = Split-DriveCurveKey 'A>0|long_h1'; $sq = Split-DriveCurveKey 'std_h0'
Chk 'A8' ($sp.Drive -eq 'A>0' -and $sp.Key -eq 'long_h1' -and $sq.Drive -eq 'A' -and $sq.Key -eq 'std_h0' -and (Get-DriveCurveKey '0' 'hd') -eq '0|hd') "Split : « A>0|long_h1 » -> $($sp.Drive) / $($sp.Key) ; cle de courbe seule -> lecteur courant $($sq.Drive)"
Chk 'A9' ((Get-CurveKeyLabel 'A|long_h1') -eq 'Long track 1,89 us (tête 1)' -and (Get-CurveKeyLabel 'hd') -eq 'Haute densité 1 us (commune)' -and (Get-DriveCurveLabel '0|std') -eq 'Standard 2 us (commune), lecteur 0' -and (Get-DriveCurveLabel 'std_h0') -eq 'Standard 2 us (tête 0), lecteur A') "libelles : $(Get-CurveKeyLabel 'A|long_h1') ; $(Get-DriveCurveLabel '0|std') ; cle seule -> $(Get-DriveCurveLabel 'std_h0')"
$script:DriveCurves = $null; Set-DriveCurve 'B' 'long' (New-Cv 'B' 'long' $null '03/11/2026 08:00' '0=90')
Chk 'A10' ($script:DriveCurves -is [hashtable] -and $script:DriveCurves.Count -eq 1 -and $null -eq (Get-DriveCurve 'A' 'std') -and @(Get-DriveCurveKeys 'A').Count -eq 0) "magasin absent ($null, bancs) : cree par Set-DriveCurve, Get-DriveCurve et Get-DriveCurveKeys sans erreur"

"--- B : migration d une configuration 12.9 a deux lecteurs"
function ConvertTo-Cfg($o) { return ($o | ConvertTo-Json -Depth 8 | ConvertFrom-Json) }   # aller-retour JSON : objets de Load-Config
$cmbDrive.Text = 'A'
$pcv129 = [ordered]@{}
$pcv129['std'] = ConvertTo-CurveConfig (New-Cv '' 'std' $null '20/10/2026 12:00' '0=25:40=70')                  # sans lecteur : lecteur de la configuration
$pcv129['long'] = ConvertTo-CurveConfig (New-Cv '0' 'long' $null '02/11/2026 11:00' '0=100:40=200')
$pcv129['std_h0'] = ConvertTo-CurveConfig (New-Cv 'A' 'std' 0 '01/11/2026 17:49' '0=10:40=50')
$pcv129['std_h1'] = ConvertTo-CurveConfig (New-Cv 'A' 'std' 1 '01/11/2026 17:49' '0=12:40=55')
$pcv129['long_h0'] = ConvertTo-CurveConfig (New-Cv '0' 'long' 0 '28/10/2026 09:00' '0=95' '12.9')               # autre calcul : mise de cote
$pcv129['long_h1'] = $null
$pcv129['hd'] = ConvertTo-CurveConfig (New-Cv '0' 'hd' $null '25/10/2026 09:00' '0=30' '' 200000)                # haute densite, calcul 12.7
$w129 = ConvertTo-Cfg ([ordered]@{ precompCurves = $pcv129; precompStd = '0=25:40=70' })
$imp = Import-DriveCurves (Get-Cfg $w129 'precompCurves' $null) (Get-Cfg $w129 'driveCurves' $null) 'A'
$keysB = @(Get-DriveCurveKeys) -join ','
Chk 'B1' ($keysB -eq '0|hd,0|long,A|std,A|std_h0,A|std_h1' -and $imp.N -eq 5 -and $imp.Migrated -and (@($imp.Drives) -join ',') -eq '0,A') "bloc 12.9 : magasin $keysB ; $($imp.N) reprises ; migree $($imp.Migrated) ; lecteurs $(@($imp.Drives) -join ',')"
Chk 'B2' ($imp.Old.Count -eq 1 -and $imp.Old.Contains('0|long_h0') -and $imp.Old['0|long_h0'].Calc -eq '12.9') "courbe d un autre calcul mise de cote sous sa cle de magasin : $(@($imp.Old.Keys) -join ',')"
Chk 'B3' ((Get-DriveCurve 'A' 'std').Drive -eq 'A' -and (Get-DriveCurve 'A' 'std').Spec -eq '0=25:40=70' -and (Get-DriveCurve '0' 'hd').Drive -eq '0') "courbe sans lecteur rangee sous le lecteur de la configuration (A), champ Drive pose ; haute densite sous le lecteur 0"
Sync-PrecompCurves 'A'
Chk 'B4' ($script:PrecompStd -eq '0=25:40=70' -and $script:PrecompLong -eq $script:PrecompLongDefault -and $null -ne $script:PrecompCurves['std_h1'] -and $null -eq $script:PrecompCurves['long']) "vue du lecteur A : profil standard de sa courbe, long track d origine (la courbe long est celle du lecteur 0)"
Sync-PrecompCurves '0'
Chk 'B5' ($script:PrecompLong -eq '0=100:40=200' -and $script:PrecompStd -eq $script:PrecompStdDefault -and $null -ne $script:PrecompCurves['hd'] -and $null -eq $script:PrecompCurves['std_h0']) "vue du lecteur 0 : long track de sa courbe, standard d origine, hd presente, std_h0 absente"
$impE = Import-DriveCurves $null $null 'A'
Chk 'B6' ($impE.N -eq 0 -and -not $impE.Migrated -and $impE.Old.Count -eq 0 -and $script:DriveCurves.Count -eq 0) 'sans aucun bloc : magasin vide, rien de migre'

"--- C : bloc driveCurves (12.10)"
$cmbDrive.Text = 'A'
$imp = Import-DriveCurves (Get-Cfg $w129 'precompCurves' $null) $null 'A'
$oc = @{ Curves = $imp.Old; Std = $null; Long = $null; Levels = @{} }
Sync-PrecompCurves
$dc = Export-DriveCurves $oc
$cvw = Export-CurveView $oc
Chk 'C1' ((@($dc.Keys) -join ',') -eq '0|hd,0|long,0|long_h0,A|std,A|std_h0,A|std_h1' -and $dc['0|long_h0'].calc -eq '12.9' -and $dc['A|std_h0'].target -eq '') "export : cles triees, courbe mise de cote comprise : $(@($dc.Keys) -join ',') ; champ target vide"
Chk 'C2' ((@($cvw.Keys) -join ',') -eq 'std,long,std_h0,std_h1,long_h0,long_h1' -and $null -ne $cvw['std'] -and $null -eq $cvw['long'] -and $null -eq $cvw['long_h0'] -and $cvw['std_h0'].drive -eq 'A') "vue 12.9 du lecteur A : six cles double densite, hd absente sans courbe du lecteur, courbes du lecteur 0 non vues : $(@($cvw.Keys) -join ',')"
$cmbDrive.Text = '0'; Sync-PrecompCurves
$cvw0 = Export-CurveView $oc
Chk 'C3' ($null -ne $cvw0['long'] -and $null -ne $cvw0['long_h0'] -and $cvw0['long_h0'].calc -eq '12.9' -and $null -ne $cvw0['hd'] -and $null -eq $cvw0['std_h0']) "vue 12.9 du lecteur 0 : long, long_h0 (mise de cote, gardee pour une 12.9), hd ; std_h0 du lecteur A non vue"
$cmbDrive.Text = 'A'; Sync-PrecompCurves
$w1210 = ConvertTo-Cfg ([ordered]@{ precompCurves = $cvw; driveCurves = $dc })
$before = @{}; foreach ($k in @(Get-DriveCurveKeys)) { $before[$k] = $script:DriveCurves[$k] }
$imp2 = Import-DriveCurves (Get-Cfg $w1210 'precompCurves' $null) (Get-Cfg $w1210 'driveCurves' $null) 'B'
$same = $true; foreach ($k in @($before.Keys)) { if (-not (Test-CvSame $before[$k] (Get-DriveCurve (Split-DriveCurveKey $k).Drive (Split-DriveCurveKey $k).Key))) { $same = $false } }
Chk 'C4' ($same -and (@(Get-DriveCurveKeys) -join ',') -eq '0|hd,0|long,A|std,A|std_h0,A|std_h1' -and $imp2.Old.Count -eq 1 -and $imp2.Old.Contains('0|long_h0') -and -not $imp2.Migrated -and $imp2.N -eq 5 -and (@($imp2.Drives) -join ',') -eq '0,A') "aller-retour JSON du bloc driveCurves : memes courbes (valeurs, lecteur, date, profil, cible, calcul), mise de cote retrouvee, rien de migre"
$pcvX = [ordered]@{ std = (ConvertTo-CurveConfig (New-Cv 'A' 'std' $null '09/11/2026 09:00' '0=99')) }
$wX = ConvertTo-Cfg ([ordered]@{ precompCurves = $pcvX; driveCurves = $dc })
$imp3 = Import-DriveCurves (Get-Cfg $wX 'precompCurves' $null) (Get-Cfg $wX 'driveCurves' $null) 'A'
Chk 'C5' ((Get-DriveCurve 'A' 'std').Spec -eq '0=25:40=70' -and -not $imp3.Migrated) "bloc driveCurves present : le bloc precompCurves (vue) n est pas relu ($((Get-DriveCurve 'A' 'std').Spec))"
$wE = ConvertTo-Cfg ([ordered]@{ precompCurves = [ordered]@{ std = $null; long = $null }; driveCurves = [ordered]@{} })
$imp4 = Import-DriveCurves (Get-Cfg $wE 'precompCurves' $null) (Get-Cfg $wE 'driveCurves' $null) 'A'
Chk 'C6' ($imp4.N -eq 0 -and $imp4.Old.Count -eq 0 -and $script:DriveCurves.Count -eq 0 -and -not $imp4.Migrated) "configuration 12.10 sans courbe (driveCurves vide, vue vide) : magasin vide, rien de migre"
$cvT = New-Cv 'A' 'std' 0 '05/11/2026 10:00' '0=30'; $cvT.Target = '0'
$rt = ConvertFrom-CurveConfig (ConvertTo-Cfg (ConvertTo-CurveConfig $cvT))
$rtOld = ConvertFrom-CurveConfig (ConvertTo-Cfg ([ordered]@{ family = 'Standard 2 us'; head = 0; drive = 'A'; date = '01/11/2026 17:49'; model = 'M1'; spec = '0=10'; values = @(10, 11, 12); cyls = @(0, 2); ys = @(10.0, 12.0); sig = @(1.0, 1.0); calc = '12.10' }))
Chk 'C7' ($rt.Target -eq '0' -and $rtOld.Target -eq '' -and $rtOld.Drive -eq 'A') "champ Target : conserve a l aller-retour ($($rt.Target)), vide pour une courbe sans ce champ (12.9)"

"--- D : copie d etat et retablissement par lecteur"
$cmbDrive.Text = 'A'
$imp = Import-DriveCurves (Get-Cfg $w129 'precompCurves' $null) $null 'A'; Sync-PrecompCurves
$script:PrecompStd = 'S-A'; $script:PrecompLong = 'L-A'
$cv0a = Get-DriveCurve '0' 'long'
$snap = Get-CalibSnapshot @('0|long', '0|long_h0', '0|long_h1')
Chk 'D1' ($snap.Drive -eq '0' -and (@($snap.Curves.Keys | Sort-Object) -join ',') -eq 'long,long_h0,long_h1' -and [object]::ReferenceEquals($snap.Curves['long'], $cv0a) -and $null -eq $snap.Curves['long_h0'] -and $snap.Std -eq 'S-A') "cles de magasin du lecteur 0 : Drive $($snap.Drive), courbes par cle de courbe ($(@($snap.Curves.Keys | Sort-Object) -join ',')), profils du moment"
Set-DriveCurve '0' 'long' (New-Cv '0' 'long' $null '08/11/2026 15:00' '0=111'); Set-DriveCurve '0' 'long_h0' (New-Cv '0' 'long' 0 '08/11/2026 15:00' '0=112')
$script:PrecompLong = 'L-nouveau'; $script:NUpd = 0; $script:NSave = 0
Restore-CalibState $snap
Chk 'D2' ([object]::ReferenceEquals((Get-DriveCurve '0' 'long'), $cv0a) -and $null -eq (Get-DriveCurve '0' 'long_h0') -and -not $script:DriveCurves.ContainsKey('0|long_h0') -and $script:PrecompLong -eq 'L-nouveau' -and $null -ne (Get-DriveCurve 'A' 'std_h0')) "retablissement : courbe long du lecteur 0 d avant, long_h0 retiree du magasin, profils de la vue du lecteur A non touches par une copie du lecteur 0 (relecture), courbes du lecteur A intactes"
Chk 'D3' ($null -eq $script:PrecompCurves['long'] -and $null -ne $script:PrecompCurves['std_h0'] -and $script:NUpd -eq 1 -and $script:NSave -eq 1 -and $txtWPrecomp.Text -eq '0=1') "vue du lecteur courant A non touchee par un retablissement du lecteur 0 ; Update-PrecompForImage $($script:NUpd), Save-Config $($script:NSave), champs --precomp retablis"
$snapA = Get-CalibSnapshot @('std_h0', 'std_h1')
$ref0 = $script:PrecompCurves['std_h0']
Set-DriveCurve 'A' 'std_h0' (New-Cv 'A' 'std' 0 '08/11/2026 16:00' '0=5')
Restore-CalibState $snapA
Chk 'D4' ($snapA.Drive -eq 'A' -and [object]::ReferenceEquals((Get-DriveCurve 'A' 'std_h0'), $ref0) -and [object]::ReferenceEquals($script:PrecompCurves['std_h0'], $ref0)) "cles de courbe seules : lecteur du bandeau (A), magasin et vue retablis"
$cmbDrive.Text = '0'; Sync-PrecompCurves
$snapX = @{ Std = 'x'; Long = 'y'; Curves = @{ std = (New-Cv '0' 'std' $null '08/11/2026 17:00' '0=7') }; Prof = 0; On = $true; P0 = '0=7'; P1 = '0=7'; Lbl = 'l' }
Restore-CalibState $snapX
Chk 'D5' ((Get-DriveCurve '0' 'std').Spec -eq '0=7' -and $script:PrecompCurves['std'].Spec -eq '0=7' -and (Get-DriveCurve 'A' 'std').Spec -eq '0=25:40=70') "copie sans lecteur (ancienne) : lecteur du bandeau (0), courbe std du lecteur A intacte"

"--- S : cablage"
$s270 = [System.IO.File]::ReadAllText((Join-Path $mods '270-fn-calib-complete.ps1'))
Chk 'S1' ($s270.Contains('Set-DriveCurve (Get-CalibStoreDrive $cal) $key @{') -and $s270.Contains("Drive = `$cal.Drive; Target = `$(if (`$cal.Cross) { [string]`$cal.Cross.Tgt } else { '' }); Date = `$date;") -and $s270.Contains('$prev = $script:PrecompCurves[$pkey]   # 12.10 : vue du lecteur courant') -and $s270.Contains('if ($prev -and [string]$prev.Drive -eq [string]$cal.Drive -and') -and $s270.Contains('Get-CalibSnapshot @($cal.Units | ForEach-Object { Get-DriveCurveKey (Get-CalibStoreDrive $cal) (Get-CalibUnitKey $cal $_) })') -and $s270.Contains('Backup-ConfigBeforeRef @($cal.Units | ForEach-Object { Get-DriveCurveKey (Get-CalibStoreDrive $cal) (Get-CalibUnitKey $cal $_) })')) 'fin de calibration : courbe, calibration precedente, copie d etat et copie .bak sur le lecteur de magasin de la calibration (etape 2 : Get-CalibStoreDrive, « source>cible » en croise)'
$direct = @()
foreach ($f in (Get-ChildItem -LiteralPath $mods -Filter '*.ps1')) {
    $t = [System.IO.File]::ReadAllText($f.FullName)
    foreach ($mm in [regex]::Matches($t, '\$script:PrecompCurves\[[^\]]+\]\s*=[^=]')) {
        $ln = ($t.Substring(0, $mm.Index) -split "`n").Count
        $direct += "$($f.Name):$ln"
    }
}
Chk 'S2' ($direct.Count -eq 2 -and @($direct | Where-Object { $_ -like '240-*' }).Count -eq 2) "ecritures directes de la vue : $($direct -join ', ') (Set-DriveCurve et Sync-PrecompCurves seulement)"
$s520 = [System.IO.File]::ReadAllText((Join-Path $mods '520-ui-ecriture.ps1'))
Chk 'S3' ($s520.Contains("`$cmbDrive.Add_TextChanged({`r`n    Update-TargetDriveUi; Update-SlowUi`r`n    Sync-PrecompCurves`r`n") -and $s520.Contains('if ($form.Visible) { Update-PrecompForImage $txtWFile.Text }') -and $s520.Contains('if ($script:CurveForm -and -not $script:CurveForm.IsDisposed) { $script:CurveForm.Close() }')) 'changement de lecteur du bandeau : vue, fenetre Courbe fermee, profil de l image une fois la fenetre affichee'
$s120 = [System.IO.File]::ReadAllText((Join-Path $mods '120-fn-configuration.ps1'))
Chk 'S4' ($s120.Contains('driveCurves = $dcCfg') -and $s120.Contains('$curvesCfg = Export-CurveView $oc') -and $s120.Contains("`$ldDrive = [string](ConvertTo-SettingValue 'drive' (Get-Cfg (Get-Cfg `$cfg 'global' `$null) 'drive' `$null))") -and $s120.Contains('Sync-PrecompCurves $ldDrive') -and $s120.Contains('$rc = Get-DriveCurve ([string]$lr.Drive) ([string]$lr.RefKey)') -and -not $s120.Contains("if (`$script:PrecompCurves['std']) { `$script:PrecompStd = `$cfgStd }")) 'configuration : bloc driveCurves ecrit, lecteur de la configuration lu avant les reglages, vue synchronisee, niveaux cherches dans le magasin de leur lecteur'
$s240 = [System.IO.File]::ReadAllText((Join-Path $mods '240-fn-calib-mesure.ps1'))
Chk 'S5' ($s240.Contains('$p = Split-DriveCurveKey $k; Set-DriveCurve $p.Drive $p.Key $cv }') -and $s240.Contains('$curves = @(Get-DriveCurveKeys)') -and $s240.Contains('$script:DriveCurves = @{}; Sync-PrecompCurves') -and $s240.Contains('Where-Object { -not $script:DriveCurves.ContainsKey($_) }')) 'anciennes calibrations conservees par Set-DriveCurve ; remise a zero : tous les lecteurs, magasin vide puis vue'
$s200 = [System.IO.File]::ReadAllText((Join-Path $mods '200-fn-accueil-calibration.ps1'))
Chk 'S6' (-not $s200.Contains("La courbe actuelle vient du lecteur {0}")) 'carte Calibrer le lecteur : avertissement d une courbe d un autre lecteur retire'
$keys = New-Object System.Collections.Generic.HashSet[string]
foreach ($f in (Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1')) {
    $t = [System.IO.File]::ReadAllText($f.FullName)
    foreach ($mm in [regex]::Matches($t, "\`$script:I18n\[`"([^`"]*)`"\]")) { [void]$keys.Add($mm.Groups[1].Value) }
    foreach ($mm in [regex]::Matches($t, "\`$script:I18n\['((?:[^']|'')*)'\]")) { [void]$keys.Add($mm.Groups[1].Value.Replace("''", "'")) }
}
Chk 'S7' ($keys.Contains('{0}, lecteur {1}') -and $keys.Contains("Configuration d'une version antérieure : {0} courbe(s) de calibration rangée(s) par lecteur ({1}).") -and $keys.Contains('{0}, calcul {1}')) 'textes anglais des cles nouvelles et reprises'
$ch = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'))
$rd = [System.IO.File]::ReadAllText((Join-Path $mods 'README.md'))
Chk 'S8' ($ch.Contains('- **Courbes de calibration par lecteur.**') -and $ch.Contains('- **Courbes par lecteur.** La configuration gagne un bloc `driveCurves`') -and $ch.Contains('`Set-DriveCurve($drive, $key, $cv)`') -and $rd.Contains('`Sync-PrecompCurves`') -and $rd.Contains('`Import-DriveCurves`') -and $rd.Contains('`$script:DriveCurves`')) 'CHANGELOG (nouveaute, a savoir, developpeurs) et README (120, 240, 560)'

"--- E : relecture (08/11/2026) : cas limites et correctifs"
# Bloc driveCurves : courbe sans lecteur (champ drive vide), cle croisee « A>0|std », cle sans « | », cle a lecteur vide
$cmbDrive.Text = 'A'
$cvNoDrv = New-Cv '' 'std' $null '04/11/2026 10:00' '0=33'
$cvCross = New-Cv 'A' 'std' $null '05/11/2026 10:00' '0=44'; $cvCross.Target = '0'
$dcvE = [ordered]@{}
$dcvE['A|std'] = ConvertTo-CurveConfig $cvNoDrv
$dcvE['0|std'] = ConvertTo-CurveConfig (New-Cv '0' 'std' $null '06/11/2026 10:00' '0=55')
$dcvE['A>0|std'] = ConvertTo-CurveConfig $cvCross
$dcvE['sanscle'] = ConvertTo-CurveConfig (New-Cv 'A' 'long' $null '06/11/2026 10:00' '0=66')
$dcvE['|long'] = ConvertTo-CurveConfig (New-Cv 'A' 'long' $null '06/11/2026 10:00' '0=77')
$wE1 = ConvertTo-Cfg ([ordered]@{ precompCurves = [ordered]@{ std = (ConvertTo-CurveConfig (New-Cv 'A' 'std' $null '09/11/2026 09:00' '0=99')) }; driveCurves = $dcvE })
$impE1 = Import-DriveCurves (Get-Cfg $wE1 'precompCurves' $null) (Get-Cfg $wE1 'driveCurves' $null) 'B'
$ksE1 = @(Get-DriveCurveKeys)
Chk 'E1' ((Get-DriveCurve 'A' 'std').Drive -eq 'A' -and (Get-DriveCurve 'A' 'std').Spec -eq '0=33' -and (Get-DriveCurve 'A>0' 'std').Drive -eq 'A' -and (Get-DriveCurve 'A>0' 'std').Target -eq '0' -and $impE1.N -eq 3 -and (@($impE1.Drives) -join ',') -eq '0,A,A>0' -and $ksE1.Count -eq 3 -and $ksE1 -contains '0|std' -and $ksE1 -contains 'A>0|std' -and $ksE1 -contains 'A|std' -and -not $impE1.Migrated -and $null -eq (Get-DriveCurve 'A' 'long')) "bloc driveCurves : courbe sans lecteur -> lecteur de la cle (A), courbe croisee gardee telle quelle (Drive A, Target 0), cles sans lecteur ignorees ; lecteurs $(@($impE1.Drives) -join ',')"
Sync-PrecompCurves 'A'
Chk 'E2' ($script:PrecompCurves['std'].Spec -eq '0=33' -and (@(Get-DriveCurveKeys 'A') -join ',') -eq 'A|std' -and (@(Get-DriveCurveKeys 'A>0') -join ',') -eq 'A>0|std' -and $null -eq (Get-DriveCurve 'B' 'std') -and (Get-DriveCurveLabel 'A>0|std') -eq 'Standard 2 us (commune), écriture par le lecteur A pour le lecteur 0') "vue du lecteur A sans la courbe croisee ; cles par lecteur (A : A|std ; A>0 : A>0|std) ; lecteur sans courbe (B) : $null ; libelle d une cle croisee : $(Get-DriveCurveLabel 'A>0|std')"
# Retablissement d une copie d un autre lecteur que celui du bandeau : courbes de ce lecteur retablies, profils de la vue intacts
$cmbDrive.Text = 'A'; Sync-PrecompCurves
$cv0b = Get-DriveCurve '0' 'std'
$snap0 = @{ Std = 'S-0'; Long = 'L-0'; Drive = '0'; Curves = @{ std = $cv0b; std_h0 = $null }; Levels = $null; Prof = 0; On = $true; P0 = '0=1'; P1 = '0=2'; Lbl = 'l' }
Set-DriveCurve '0' 'std' (New-Cv '0' 'std' $null '08/11/2026 18:00' '0=88'); Set-DriveCurve '0' 'std_h0' (New-Cv '0' 'std' 0 '08/11/2026 18:00' '0=89')
Restore-CalibState $snap0
Chk 'E3' ($script:PrecompStd -eq '0=33' -and $script:PrecompLong -eq $script:PrecompLongDefault -and [object]::ReferenceEquals((Get-DriveCurve '0' 'std'), $cv0b) -and -not $script:DriveCurves.ContainsKey('0|std_h0') -and $script:PrecompCurves['std'].Spec -eq '0=33') "copie du lecteur 0 retablie pendant que le bandeau montre A : courbes du lecteur 0 retablies (std d avant, std_h0 retiree), profils ($($script:PrecompStd)) et vue du lecteur A intacts"
$snapA2 = @{ Std = 'S-A2'; Long = 'L-A2'; Drive = 'A'; Curves = @{}; Levels = $null; Prof = 0; On = $true; P0 = '0=1'; P1 = '0=2'; Lbl = 'l' }
Restore-CalibState $snapA2
Chk 'E4' ($script:PrecompStd -eq 'S-A2' -and $script:PrecompLong -eq 'L-A2') "copie du lecteur du bandeau (A) : profils de famille retablis ($($script:PrecompStd), $($script:PrecompLong))"
# Niveaux de la calibration rapide abandonnes a une nouvelle reference : ceux du lecteur calibre seulement (boucle reelle de 270)
$script:LevelShifts = @{ 'std|c' = @{ RefKey = 'std'; Drive = '0'; Tag = 'c' }; 'std|0' = @{ RefKey = 'std'; Drive = 'A'; Tag = '0' }; 'long|c' = @{ RefKey = 'long'; Drive = 'A'; Tag = 'c' }; 'std_h0|c' = @{ RefKey = 'std_h0'; Drive = 'A'; Tag = 'c' } }
$drA = @(Test-DropLevels @{ Drive = 'A'; Family = 'std'; Units = @(@{ Head = $null }) })
Chk 'E5' ((@($drA) -join ',') -eq 'std' -and $script:LevelShifts.ContainsKey('std|c') -and -not $script:LevelShifts.ContainsKey('std|0') -and $script:LevelShifts.ContainsKey('long|c') -and $script:LevelShifts.ContainsKey('std_h0|c')) "nouvelle reference std du lecteur A : son niveau std abandonne ($(@($drA) -join ',')), niveau std du lecteur 0 et autres cles gardes ($(@($script:LevelShifts.Keys | Sort-Object) -join ','))"
$dr0 = @(Test-DropLevels @{ Drive = '0'; Family = 'std'; Units = @(@{ Head = 0 }, @{ Head = 1 }) })
Chk 'E6' (@($dr0).Count -eq 0 -and $script:LevelShifts.ContainsKey('std|c') -and $script:LevelShifts.ContainsKey('std_h0|c')) "reference par tete du lecteur 0 : aucun niveau abandonne (std_h0 du lecteur A garde, std commune du lecteur 0 non concernee)"
$dr0c = @(Test-DropLevels @{ Drive = '0'; Family = 'std'; Units = @(@{ Head = $null }) })
Chk 'E7' ((@($dr0c) -join ',') -eq 'std' -and -not $script:LevelShifts.ContainsKey('std|c') -and $script:LevelShifts.ContainsKey('long|c')) "reference std du lecteur 0 : son niveau std abandonne, long du lecteur A garde"
# Niveaux relus au chargement : reference cherchee dans le magasin de leur lecteur (boucle reelle de Load-Config)
function New-Lv([string]$refKey, [string]$tag, [string]$drive, [string]$refDate, [string]$algo = 'lvl2') {
    return @{ RefKey = $refKey; Tag = $tag; Head = $null; Drive = $drive; Date = '08/11/2026 12:00'; RefDate = $refDate; RefTest = 'fine'; Delta = 3; Est = 3.0; SE = 0.5; Tau = 1.0; Verdict = 'ok'; Shape = 'ok'; Reasons = @(); Conv = $true; Passes = 2
              Cyls = @(0, 40); Zs = @(1.0, 2.0); Ds = @(0.1, 0.2); Sigs = @(1.0, 1.0); Kinds = @('zero', 'zero'); Values = @(10, 11); Spec = '0=10'; Sat = @(); Floor = @(); Hist = @(); Version = '12.10'; Algo = 'a'; LevelAlgo = $algo; S = 0.0; B = 0.0; Model = 'M0'; Mode = 'lvl2'; Brand = ''; Ctl = @(); K = $null }
}
$script:DriveCurves = @{}
Set-DriveCurve 'A' 'std' (New-Cv 'A' 'std' $null '01/11/2026 17:49' '0=10')
Set-DriveCurve '0' 'std' (New-Cv '0' 'std' $null '06/11/2026 10:00' '0=50')
$oldE = [ordered]@{ '0|long_h0' = (New-Cv '0' 'long' 0 '28/10/2026 09:00' '0=95' '12.9') }
$wLv = ConvertTo-Cfg ([ordered]@{ levelAlgo = 'lvl2'; levelShifts = @((ConvertTo-LevelConfig (New-Lv 'std' 'c' 'A' '01/11/2026 17:49')), (ConvertTo-LevelConfig (New-Lv 'std' '0' '0' '06/11/2026 10:00')), (ConvertTo-LevelConfig (New-Lv 'std' '1' 'A' '31/10/2026 00:00')), (ConvertTo-LevelConfig (New-Lv 'std' 'x' 'B' '01/11/2026 17:49')), (ConvertTo-LevelConfig (New-Lv 'long_h0' '0' '0' '28/10/2026 09:00')), (ConvertTo-LevelConfig (New-Lv 'std' 'z' 'A' '01/11/2026 17:49' 'lvl0'))) })
$lvr = Test-LoadLevels $wLv $oldE
Chk 'E8' ((@($lvr.Lv.Keys | Sort-Object) -join ',') -eq 'std|0,std|c' -and $lvr.Lv['std|c'].Drive -eq 'A' -and $lvr.Lv['std|0'].Drive -eq '0' -and (@($lvr.OldLv.Keys) -join ',') -eq 'long_h0|0') "niveaux relus : std|c (lecteur A) et std|0 (lecteur 0) gardes, date differente et lecteur sans courbe (B) ecartes, algorithme inconnu ignore, niveau d une reference mise de cote range avec elle ($(@($lvr.Lv.Keys | Sort-Object) -join ',') ; $(@($lvr.OldLv.Keys) -join ','))"
$wLv1 = ConvertTo-Cfg ([ordered]@{ levelAlgo = 'lvl0'; levelShifts = @((ConvertTo-LevelConfig (New-Lv 'std' 'c' 'A' '01/11/2026 17:49'))) })
$lvr1 = Test-LoadLevels $wLv1 $oldE
Chk 'E9' ($lvr1.Lv.Count -eq 0 -and $lvr1.OldLv.Count -eq 0) 'algorithme de niveau de la configuration inconnu : aucun niveau relu'
# Copie .bak sur cles de magasin (fichier temporaire) : familles des courbes presentes ou en attente, date de la plus recente
$bkDir = Join-Path $here 'out\cfg-bak'
if (Test-Path -LiteralPath $bkDir) { Remove-Item -LiteralPath $bkDir -Recurse -Force }
[void](New-Item -ItemType Directory -Path $bkDir)
$script:ConfigFile = Join-Path $bkDir 'config.json'; [System.IO.File]::WriteAllText($script:ConfigFile, '{}')
$script:OldCalib = @{ Curves = $oldE; Std = $null; Long = $null; Levels = @{} }
$script:Log.Clear()
$bk1 = Backup-ConfigBeforeRef @('A|std', '0|long_h0', 'B|std') 'replace'
Chk 'E10' ($bk1 -and (Test-Path -LiteralPath $bk1) -and ([System.IO.Path]::GetFileName($bk1)) -eq 'config.json.ref-long+std-20261101-1749.bak' -and @($script:Log | Where-Object { $_ -like 'Configuration sauvegardée avant le remplacement de la référence Long track 1,89 us, Standard 2 us du 01/11/2026 17:49 : *' }).Count -eq 1) "copie .bak sur cles de magasin : familles long+std (courbe en attente comprise), date de la plus recente : $([System.IO.Path]::GetFileName("$bk1"))"
$bk2 = Backup-ConfigBeforeRef @('B|std', 'A|hd') 'reset'
Chk 'E11' ($null -eq $bk2 -and @(Get-ChildItem -LiteralPath $bkDir -Filter '*.bak').Count -eq 1) 'cles sans courbe (lecteur B, haute densite de A) : aucune copie'
$script:OldCalib = $null
# Export sans courbe ni calibration en attente
$script:DriveCurves = @{}; $cmbDrive.Text = 'A'; Sync-PrecompCurves
$dcN = Export-DriveCurves $null; $cvN = Export-CurveView $null
Chk 'E12' ($dcN.Count -eq 0 -and (@($cvN.Keys) -join ',') -eq 'std,long,std_h0,std_h1,long_h0,long_h1' -and @($cvN.Values | Where-Object { $null -ne $_ }).Count -eq 0 -and $script:PrecompStd -eq $script:PrecompStdDefault) "sans courbe : bloc driveCurves vide, vue 12.9 des six cles double densite a null, profils d origine"
# Cablage des correctifs de la relecture
Chk 'E13' ($s270.Contains('if ([string]$cal.Drive -eq [string]$cmbDrive.Text) {') -and $s270.Contains("            if (`$cal.Family -eq 'long') { `$script:PrecompLong = `$spec } elseif ([string]`$cal.Family -ne 'hd') { `$script:PrecompStd = `$spec }") -and $s270.Contains('$script:LevelShifts[$k].RefKey -eq $key -and [string]$script:LevelShifts[$k].Drive -eq [string]$cal.Drive)')) 'fin de calibration : profil de famille pour le lecteur du bandeau seulement ; niveaux abandonnes du seul lecteur calibre'
$s290 = [System.IO.File]::ReadAllText((Join-Path $mods '290-fn-calib-b.ps1'))
Chk 'E14' ($s290.Contains('$acv = Get-DriveCurve ([string]$cal.Drive) $k') -and $s290.Contains('AState = (Get-CalibSnapshot @($keys | ForEach-Object { Get-DriveCurveKey ([string]$cal.Drive) $_ }))') -and -not $s290.Contains('$script:PrecompCurves[')) 'calibration B : courbe A et copie d etat sur le lecteur de la calibration, plus aucune lecture de la vue'
$s250 = [System.IO.File]::ReadAllText((Join-Path $mods '250-fn-calib-fenetres.ps1'))
Chk 'E15' ($s250.Contains('if ($pd -eq [string]$cmbDrive.Text) { $script:PrecompStd = $prev.Std; $script:PrecompLong = $prev.Long }')) 'retablissement : profils pour le lecteur du bandeau seulement'
Chk 'E16' (-not $keys.Contains("La courbe actuelle vient du lecteur {0} : elle sera remplacée, et la nouvelle s'appliquera à tous les lecteurs (une courbe par famille).") -and $ch.Contains("n'abandonne que les niveaux de ce lecteur")) 'cle i18n de l avertissement retire supprimee de la table ; CHANGELOG : niveaux du seul lecteur calibre'

"--- F : relecture 2 (08/11/2026) : profil de famille au chargement, courbe commune sous un autre lecteur"
# Configuration 12.9 relue en 12.10 : la courbe std (calcul 12.9, mise de cote) est celle du lecteur 0, le lecteur de la
# configuration est A (bandeau change avant la fermeture) ; precompStd de la 12.9 = profil de cette courbe
$cmbDrive.Text = 'A'; $script:DriveCurves = @{}
$oldF = [ordered]@{ '0|std' = (New-Cv '0' 'std' $null '20/10/2026 12:00' '0=25:40=70' '12.9') }
Sync-PrecompCurves 'A'
$pf1 = Test-LoadProfiles $oldF 'A' '0=25:40=70' $script:PrecompLongDefault
Chk 'F1' (-not $pf1.Lost -and $null -eq $pf1.OldStd -and $null -eq $pf1.OldLong -and $pf1.AnyStd -and -not $pf1.AnyLong) "courbe std mise de cote sous le lecteur 0, configuration du lecteur A : rien de perdu (Lost $($pf1.Lost)), aucun profil mis de cote pour A"
Sync-PrecompCurves '0'
$pf2 = Test-LoadProfiles $oldF '0' '0=25:40=70' $script:PrecompLongDefault
Chk 'F2' (-not $pf2.Lost -and $pf2.OldStd -eq '0=25:40=70' -and $null -eq $pf2.OldLong) "meme courbe, configuration du lecteur 0 : profil standard mis de cote avec sa courbe ($($pf2.OldStd)), rien de perdu"
# Aucune courbe commune d aucun lecteur : profil calibre sans courbe (anterieur a 12.1) toujours signale
Sync-PrecompCurves 'A'
$pf3 = Test-LoadProfiles ([ordered]@{}) 'A' '0=25:40=70' '0=99'
Chk 'F3' ($pf3.Lost -and $null -eq $pf3.OldStd -and $null -eq $pf3.OldLong -and -not $pf3.AnyStd -and -not $pf3.AnyLong) "aucune courbe commune : profils calibres sans courbe signales (Lost $($pf3.Lost))"
# Courbe long reprise (calcul actuel) sous l autre lecteur, courbe par tete seule pour std : la courbe par tete ne compte pas
Set-DriveCurve '0' 'long' (New-Cv '0' 'long' $null '02/11/2026 11:00' '0=100:40=200'); Set-DriveCurve '0' 'std_h0' (New-Cv '0' 'std' 0 '02/11/2026 11:00' '0=10')
Sync-PrecompCurves 'A'
$pf4 = Test-LoadProfiles ([ordered]@{}) 'A' $script:PrecompStdDefault '0=100:40=200'
Chk 'F4' (-not $pf4.Lost -and $pf4.AnyLong -and -not $pf4.AnyStd -and $null -eq $pf4.OldLong -and $script:PrecompLong -eq $script:PrecompLongDefault) "courbe long reprise sous le lecteur 0 : profil long track de la configuration non perdu, vue du lecteur A au profil d origine ; courbe par tete std_h0 non comptee comme courbe commune"
# Cle croisee seule (A>0|std) : sa courbe n entre pas dans la vue, elle ne compte pas
$script:DriveCurves = @{}; Set-DriveCurve 'A>0' 'std' (New-Cv 'A' 'std' $null '05/11/2026 10:00' '0=44'); Sync-PrecompCurves 'A'
$pf5 = Test-LoadProfiles ([ordered]@{}) 'A' '0=44' $script:PrecompLongDefault
Chk 'F5' ($pf5.Lost -and -not $pf5.AnyStd -and $null -eq $script:PrecompCurves['std']) "courbe croisee A>0 seule : non comptee (Lost $($pf5.Lost)), vue std du lecteur A vide"
# Profils d origine sans courbe : rien a signaler ; courbe std reprise sous le lecteur de la configuration : profil de la courbe
$pf6 = Test-LoadProfiles ([ordered]@{}) 'A' $script:PrecompStdDefault $script:PrecompLongDefault
$script:DriveCurves = @{}; Set-DriveCurve 'A' 'std' (New-Cv 'A' 'std' $null '20/10/2026 12:00' '0=25:40=70'); Sync-PrecompCurves 'A'
$pf7 = Test-LoadProfiles $oldF 'A' '0=25:40=70' $script:PrecompLongDefault
Chk 'F6' (-not $pf6.Lost -and -not $pf7.Lost -and $null -eq $pf7.OldStd -and $script:PrecompStd -eq '0=25:40=70') "profils d origine sans courbe : rien ; courbe std reprise sous A : vue au profil de la courbe ($($script:PrecompStd)), rien de mis de cote"
Chk 'F7' ($s120.Contains('$anyStd = (@(@(Get-DriveCurveKeys) + @($old.Keys) | Where-Object {') -and $ch.Contains("ne signale un profil de famille calibré sans courbe (version antérieure à 12.1) que si aucun lecteur n'a de courbe commune de la famille")) 'cablage : courbes mises de cote comptees dans Load-Config ; CHANGELOG (developpeurs)'

$nk = if ($script:Fail) { ' ; non conformes : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-1210-drivecurves-e3 : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
