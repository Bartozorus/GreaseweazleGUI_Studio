param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-export) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out. Set-TestCulture vient de commun.ps1.
# 12.10 (v1210\export) : export du tableau de l onglet « Qualite & alignement » (demande du 01/11/2026). Fonctions reelles
# extraites par l arbre syntaxique (texte tel quel, fichier de travail gen-1210-export.ps1, dot-source) : 190 New-AlignRow,
# Get-AlLevel, Get-AlignTableExport, Format-CsvField, ConvertTo-AlignTableText, Get-AlignTableSep, Export-AlignTable ;
# 195 Get-QualStaleText ; affectations $script:Version (000) et $script:QualView (040). Remplacants nommes : T, Append-Log
# (journal en memoire), Get-JitterRedBound, seuils, couleurs, police, $cmbDrive. Tableau : ListView reel cree en memoire,
# aucune fenetre affichee (System.Windows.Forms charge par Import-TestWinForms, aucun Add-Type). Copy-AlignTable (presse-papiers)
# n est pas appelee. Culture fr-FR par defaut (virgule decimale, separateur de liste « ; »), en-US pour un cas.
# Aucun gw, aucune application, aucune fenetre.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Set-TestCulture 'fr-FR'
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mods = Join-Path $Wt 'src\modules'
if (-not (Test-Path -LiteralPath (Join-Path $mods '190-fn-qualite-alignement.ps1'))) { throw "modules introuvables sous $Wt" }

function Get-ExAst([string]$path) {
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message) (ligne $(@($er)[0].Extent.StartLineNumber))" }
    return $ast
}
function Get-ExFnDefs([string]$path) {
    $h = @{}
    foreach ($fd in (Get-ExAst $path).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) { $h[$fd.Name] = $fd }
    return $h
}
function Get-ExAssign([string]$path, [string]$left) {
    $a = Get-ExAst $path
    $st = @($a.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left.Extent.Text -eq $left })
    if ($st.Count -ne 1) { throw "affectation $left dans $path : $($st.Count) (1 attendue)" }
    return $st[0].Extent.Text
}

$parts = New-Object System.Collections.Generic.List[string]; $found = @{}
$d190 = Get-ExFnDefs (Join-Path $mods '190-fn-qualite-alignement.ps1')
$d195 = Get-ExFnDefs (Join-Path $mods '195-fn-qualite-affichage.ps1')
foreach ($p in @(@($d190, '190', @('New-AlignRow', 'Get-AlLevel', 'Get-AlignTableExport', 'Format-CsvField', 'ConvertTo-AlignTableText', 'Get-AlignTableSep', 'Export-AlignTable')),
                 @($d195, '195', @('Get-QualStaleText')))) {
    foreach ($n in $p[2]) {
        if (-not $p[0].ContainsKey($n)) { throw "fonction $n introuvable dans $($p[1]) (correctif pas encore applique ?)" }
        $parts.Add($p[0][$n].Extent.Text); $found[$n] = "$($p[1]):$($p[0][$n].Extent.StartLineNumber)"
    }
}
$parts.Add((Get-ExAssign (Join-Path $mods '000-entete.ps1') '$script:Version'))
$parts.Add((Get-ExAssign (Join-Path $mods '040-etat-formats.ps1') '$script:QualView'))
$gen = Join-Path $here 'gen-1210-export.ps1'
[System.IO.File]::WriteAllText($gen, ((@($parts) -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
. $gen

# ---------------------------------------------------------------- remplacants
function T([string]$s) { return $s }
$script:RLog = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text) { $script:RLog.Add($text) }
function Get-JitterRedBound { return 120.0 }
$script:JitterOk = 50.0; $script:HealthErrOk = 2
$cmbDrive = [pscustomobject]@{ Text = 'Sony (A)' }
Import-TestWinForms
try { $bold = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold) }
catch { [void][System.Reflection.Assembly]::Load('System.Drawing.Common'); $bold = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold) }
$script:AlColors = @{ 0 = [System.Drawing.Color]::FromArgb(86, 196, 108); 1 = [System.Drawing.Color]::FromArgb(188, 214, 94); 2 = [System.Drawing.Color]::FromArgb(245, 176, 66); 3 = [System.Drawing.Color]::FromArgb(233, 86, 80) }
$script:AlFg = @{ 0 = [System.Drawing.Color]::Black; 1 = [System.Drawing.Color]::Black; 2 = [System.Drawing.Color]::Black; 3 = [System.Drawing.Color]::White }
$lvAl = New-Object System.Windows.Forms.ListView
$lvAl.View = 'Details'
foreach ($c in @('Piste', 'État', 'Erreurs', 'Trous', 'Stab', 'Jitter ns', 'Score', 'vs réf', 'Asym.', 'Cell ns')) { [void]$lvAl.Columns.Add($c, 60) }

function New-M([double]$ooc, [double]$dr, [double]$stab, [double]$j, [double]$r3, [double]$r4, [double]$cell, [int]$level, [switch]$Weak, [switch]$Bad, [switch]$Missing, [switch]$Unjudged) {
    $m = @{ Bad = [bool]$Bad; Missing = [bool]$Missing; J = $j; R3 = $r3; R4 = $r4; Ooc = $ooc; Dr = $dr; Cell = $cell; Stab = $stab; Asym = 0.0; Score = 9999; Level = $level; Weak = [bool]$Weak; Unjudged = [bool]$Unjudged }
    if (-not $m.Bad) { $m.Asym = [math]::Abs($r3 - 1.5) + [math]::Abs($r4 - 2.0); $m.Score = [math]::Round($j + 2000 * $m.Asym + 5 * $ooc + 50 * $dr + $stab, 0) }
    return $m
}
function Fill-Table {
    $lvAl.Items.Clear()
    [void]$lvAl.Items.Add((New-AlignRow '0.0' (New-M 0 0 1 23.4 1.512 1.987 2000 0) '' '-' -1))
    [void]$lvAl.Items.Add((New-AlignRow '1.1' (New-M 2.5 0.5 3 1180.2 1.44 2.09 1990 1 -Weak) '' '+5 %' 0))
    [void]$lvAl.Items.Add((New-AlignRow '3.1' (New-M 0 0 0 0 0 0 0 2 -Bad -Missing) ' (réécrite x2)' '-' -1))
    [void]$lvAl.Items.Add((New-AlignRow '40.0' (New-M 0 0 0 30 1.5 2.0 2000 0 -Unjudged) '' '-' -1))
}
function Set-MeasureView {
    $v = $script:QualView
    $v.State = 'result'; $v.Kind = 'measure'; $v.Reason = ''; $v.At = [datetime]::new(2026, 11, 1, 17, 49, 0); $v.Has = $true
    $v.Res = @{ Kind = 'measure'; HealthText = 'SUPPORT SAIN  -  4/4 pistes propres'; ScoreText = 'Qualité de lecture : score 100 - BON, stable'; Ctx = @{ Drive = 'Sony MPF920; A'; Heads = '0+1'; Revs = 3 } }
    $script:AlignRefLabel = 'lecteur A, tête 0, 01/11 17:49'
}
function Get-Lines([string]$text) { return ,@($text -split "`r`n") }

# ---------------------------------------------------------------- controles et sortie
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    if (-not $ok) { $script:Fail++; $script:FailIds += $id }
    '{0,-8} {1,-12} {2}' -f $id, $(if ($ok) { 'conforme' } else { 'NON CONFORME' }), $d
}

"logic-1210-export : $(@($found.Keys).Count) fonctions ($(@($found.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name) $($_.Value)" }) -join ' ; ')) ; PowerShell $($PSVersionTable.PSVersion)"
"Version $($script:Version) ; culture $([System.Globalization.CultureInfo]::CurrentCulture.Name), separateur de liste « $([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ListSeparator) »"

# ---------------------------------------------------------------- A : structure de l export (mesure)
"--- A : structure (mesure, 4 pistes)"
Fill-Table; Set-MeasureView
$x = Get-AlignTableExport
$labels = @($x.Head | ForEach-Object { [string]$_[0] })
$vals = @{}; foreach ($h in $x.Head) { $vals[[string]$h[0]] = [string]$h[1] }
Chk 'A1' (@($x.Rows).Count -eq 4 -and @($x.Cols).Count -eq 12 -and @($x.Rows | Where-Object { @($_).Count -ne 12 }).Count -eq 0) "$(@($x.Rows).Count) ligne(s) de $(@($x.Cols).Count) colonnes"
Chk 'A2' (($labels -join '|') -eq 'Application|Export|Résultat|Heure du résultat|Lecteur|Têtes|Tours|État du support|Score|Référence|Pistes') "en-tete : $($labels -join ' | ')"
Chk 'A3' ($vals['Application'] -eq "Greaseweazle Studio $($script:Version)" -and $vals['Résultat'] -eq 'Mesure de la disquette' -and $vals['Heure du résultat'] -eq '01/11/2026 17:49:00' -and $vals['Lecteur'] -eq 'Sony MPF920; A' -and $vals['Têtes'] -eq '0+1' -and $vals['Tours'] -eq '3' -and $vals['Pistes'] -eq '4' -and $vals['Référence'] -eq 'lecteur A, tête 0, 01/11 17:49') "valeurs : $($vals['Application']) ; $($vals['Résultat']) ; $($vals['Heure du résultat']) ; $($vals['Lecteur']) ; $($vals['Têtes']) ; $($vals['Tours']) ; $($vals['Pistes'])"
Chk 'A4' ($vals['Export'] -match '^\d\d/\d\d/\d{4} \d\d:\d\d:\d\d$') "date d export : $($vals['Export'])"
Chk 'A5' ($lvAl.Items[0].Tag.M.Score -eq 74 -and $lvAl.Items[1].Tag.M.Weak -and $lvAl.Items[2].Tag.M.Bad) "Tag.M present sur les lignes (score piste 1 : $($lvAl.Items[0].Tag.M.Score))"

# ---------------------------------------------------------------- B : CSV francais
"--- B : CSV fr-FR (« ; », virgule decimale)"
$sep = Get-AlignTableSep 'C:\x\gw-qualite.csv'
$txt = ConvertTo-AlignTableText $x $sep
$L = Get-Lines $txt
Chk 'B1' ($sep -eq ';' -and $L.Count -eq 17 -and $L[16] -eq '' -and -not ($txt -replace "`r`n", '').Contains("`n")) "separateur « $sep », $($L.Count - 1) lignes, CRLF seules"
Chk 'B2' ($L[4] -eq 'Lecteur;"Sony MPF920; A"') "champ avec « ; » entre guillemets : $($L[4])"
Chk 'B3' ($L[11] -eq 'Piste;État;Erreurs/tour;Trous/tour;Stabilité;Jitter ns;Score;vs réf;Asym.;Écart 3T;Écart 4T;Cellule ns') "colonnes : $($L[11])"
Chk 'B4' ($L[12] -eq '0.0;SAIN;0,0;0,0;1;23;74;-;0,025;+0,012;-0,013;2000') "piste saine : $($L[12])"
Chk 'B5' ($L[13] -eq '1.1;À SURVEILLER (zone instable);2,5;0,5;3;1180;1521;+5 %;0,150;-0,060;+0,090;1990') "piste a surveiller, score sans separateur de milliers : $($L[13])"
Chk 'B6' ($L[14] -eq '3.1;ABSENTE (réécrite x2);-;-;-;-;-;-;-;-;-;-') "piste absente : $($L[14])"
Chk 'B7' ($L[15] -eq '40.0;NON JUGÉE;0,0;0,0;0;30;30;-;0,000;0,000;0,000;2000') "piste non jugee, ecarts nuls : $($L[15])"
$shown = [string]$lvAl.Items[1].SubItems[6].Text
Chk 'B8' ($shown -ne '1521' -and $shown -match '^1.521$') "score affiche a l ecran avec separateur de milliers (« $shown »), exporte « 1521 »"

# ---------------------------------------------------------------- C : CSV anglais
"--- C : CSV en-US (« , », point decimal)"
Set-TestCulture 'en-US'
$sepE = Get-AlignTableSep 'C:\x\gw-qualite.csv'
$xe = Get-AlignTableExport
$LE = Get-Lines (ConvertTo-AlignTableText $xe $sepE)
Set-TestCulture 'fr-FR'
Chk 'C1' ($sepE -eq ',' -and $LE[12] -eq '0.0,SAIN,0.0,0.0,1,23,74,-,0.025,+0.012,-0.013,2000') "separateur « $sepE » : $($LE[12])"
Chk 'C2' ($LE[8] -eq 'Score,"Qualité de lecture : score 100 - BON, stable"') "texte du score avec virgule entre guillemets : $($LE[8])"

# ---------------------------------------------------------------- D : texte tabule
"--- D : texte tabule (.txt)"
$sepT = Get-AlignTableSep 'C:\x\gw-qualite.txt'
$LT = Get-Lines (ConvertTo-AlignTableText $x $sepT)
Chk 'D1' ($sepT -eq "`t" -and $LT[4] -eq "Lecteur`tSony MPF920; A" -and $LT[12] -eq "0.0`tSAIN`t0,0`t0,0`t1`t23`t74`t-`t0,025`t+0,012`t-0,013`t2000") "tabulations, « ; » non protege : $($LT[4])"

# ---------------------------------------------------------------- E : etats du resultat
"--- E : resultat perime, controle apres ecriture"
$script:QualView.State = 'stale'; $script:QualView.Reason = 'written'
$xs = Get-AlignTableExport; $vs = @{}; foreach ($h in $xs.Head) { $vs[[string]$h[0]] = [string]$h[1] }
Chk 'E1' ($vs['Résultat'] -eq 'Mesure de la disquette (périmé) : Disquette écrite depuis la mesure') "perime : $($vs['Résultat'])"
$v = $script:QualView; $v.State = 'result'; $v.Kind = 'check'; $v.Reason = ''
$v.Res = @{ Kind = 'check'; HealthText = 'COPIE SAINE'; ScoreText = 'Contrôle après écriture : score moyen 80 (BON) sur 4 piste(s) lisible(s)' }
$script:AlignRefLabel = ''
$xc = Get-AlignTableExport; $vc = @{}; foreach ($h in $xc.Head) { $vc[[string]$h[0]] = [string]$h[1] }
$lc = @($xc.Head | ForEach-Object { [string]$_[0] })
Chk 'E2' ($vc['Résultat'] -eq 'Contrôle après écriture' -and $vc['Lecteur'] -eq 'Sony (A)' -and -not $vc.ContainsKey('Têtes') -and -not $vc.ContainsKey('Tours') -and -not $vc.ContainsKey('Référence') -and $vc['État du support'] -eq 'COPIE SAINE') "controle : $($lc -join ' | ') ; lecteur $($vc['Lecteur'])"
Set-MeasureView

# ---------------------------------------------------------------- F : fichier
"--- F : fichier CSV (UTF-8 avec BOM) et tableau vide"
$out = Join-Path $here 'out-export.csv'
if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force }
$n0 = $script:RLog.Count
$n = Export-AlignTable $out
$bytes = [System.IO.File]::ReadAllBytes($out)
$body = [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
$new = @($script:RLog | Select-Object -Skip $n0)
Chk 'F1' ($n -eq 4 -and $bytes.Length -gt 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) "4 pistes, BOM UTF-8 ($($bytes.Length) octets)"
Chk 'F2' ($body -eq (ConvertTo-AlignTableText (Get-AlignTableExport) ';') -or ($body -split "`r`n")[12] -eq '0.0;SAIN;0,0;0,0;1;23;74;-;0,025;+0,012;-0,013;2000') "contenu du fichier = texte « ; »"
Chk 'F3' ($new.Count -eq 1 -and $new[0] -eq "Qualité : tableau de 4 piste(s) exporté dans $out.") "journal : $($new -join ' / ')"
Remove-Item -LiteralPath $out -Force
$lvAl.Items.Clear()
$n0 = $script:RLog.Count
$n = Export-AlignTable $out
$new = @($script:RLog | Select-Object -Skip $n0)
Chk 'F4' ($n -eq 0 -and -not (Test-Path -LiteralPath $out) -and $new.Count -eq 1 -and $new[0] -eq 'Qualité : aucun tableau à exporter (lancez une mesure ou un contrôle).') "tableau vide : $n piste, fichier absent, journal : $($new -join ' / ')"

# ---------------------------------------------------------------- G : ligne sans Tag.M (repli sur le texte affiche)
"--- G : ligne sans metriques"
$it = New-Object System.Windows.Forms.ListViewItem('5.0')
foreach ($s in @('SAIN', '0,0', '0,0', '1', '23', '1 521', '-', '0,025', '2000')) { [void]$it.SubItems.Add($s) }
[void]$lvAl.Items.Add($it)
$xg = Get-AlignTableExport
Chk 'G1' ((@($xg.Rows[0]) -join ';') -eq '5.0;SAIN;0,0;0,0;1;23;1 521;-;0,025;-;-;2000') "repli : $(@($xg.Rows[0]) -join ';')"

# ---------------------------------------------------------------- H : cablage (530) et textes anglais (018)
"--- H : cablage de l onglet et traductions"
$s530 = [System.IO.File]::ReadAllText((Join-Path $mods '530-ui-onglets-techniques.ps1'))
Chk 'H1' ($s530.Contains('$btnAlExport = New-Object System.Windows.Forms.Button') -and $s530.Contains('$lblAlRef, $btnAlExport,') -and $s530.Contains('$lvAl.ContextMenuStrip = $mnuAl') -and $s530.Contains('$lvAl.Add_KeyDown(') -and $s530.Contains('Export-AlignTable $d.FileName') -and $s530.Contains('[void](Copy-AlignTable)')) 'bouton dans l onglet, menu contextuel, Ctrl+C, appels Export/Copy'
$p018 = Join-Path $mods '018-i18n-1210.ps1'
$b018 = [System.IO.File]::ReadAllBytes($p018)
$t018 = [System.Text.Encoding]::UTF8.GetString($b018, 3, $b018.Length - 3)
Chk 'H2' ($b018[0] -eq 0xEF -and $b018[1] -eq 0xBB -and $b018[2] -eq 0xBF -and -not ($t018 -replace "`r`n", '').Contains("`n") -and $t018.EndsWith("`r`n")) '018 : BOM UTF-8, CRLF seules, fin de ligne finale'
# cles T() des nouvelles fonctions (190) et du bloc 530 : toutes traduites dans 010-018
$keys = New-Object System.Collections.Generic.HashSet[string]
foreach ($f in (Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1')) {
    $t = [System.IO.File]::ReadAllText($f.FullName)
    foreach ($mm in [regex]::Matches($t, "\`$script:I18n\['((?:[^']|'')*)'\]")) { [void]$keys.Add($mm.Groups[1].Value.Replace("''", "'")) }
    foreach ($mm in [regex]::Matches($t, "\`$script:I18n\[`"([^`"]*)`"\]")) { [void]$keys.Add($mm.Groups[1].Value) }
}
$newCode = (@('Get-AlignTableExport', 'Export-AlignTable', 'Copy-AlignTable') | ForEach-Object { $d190[$_].Extent.Text }) -join "`n"
$i0 = $s530.IndexOf('$btnAlExport = New-Object'); $i1 = $s530.IndexOf('$tabAl.Controls.AddRange')
$newCode += "`n" + $s530.Substring($i0, $i1 - $i0)
$used = New-Object System.Collections.Generic.HashSet[string]
foreach ($mm in [regex]::Matches($newCode, "\(T '((?:[^']|'')*)'\)")) { [void]$used.Add($mm.Groups[1].Value.Replace("''", "'")) }
foreach ($mm in [regex]::Matches($newCode, "\(T `"([^`"]*)`"\)")) { [void]$used.Add($mm.Groups[1].Value) }
$missing = @($used | Where-Object { -not $keys.Contains($_) })
Chk 'H3' ($used.Count -ge 25 -and $missing.Count -eq 0) "$($used.Count) cles T() dans le nouveau code, $($missing.Count) sans traduction$(if ($missing.Count) { ' : ' + ($missing -join ' ; ') })"

$lvAl.Dispose(); $bold.Dispose()
$nk = if ($script:Fail) { ' ; non conformes : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-1210-export : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
