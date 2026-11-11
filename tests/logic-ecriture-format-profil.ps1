param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-fix1-c) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out.
# Copie adaptee par la correction fix2 de la RC5 (10/11/2026, v1210\rc5\fix2\make_fix2_copies.py) : Get-WriteImageFamily (140), appelee par Get-TargetWriteInfo, ajoutee aux fonctions extraites.
# Correction tour 1 de la RC4 12.10 (10/11/2026, v1210\rc4\fix1) : libelle du profil de l onglet Ecriture.
#  B1 : format change apres l image : gestionnaires Enter, SelectedIndexChanged, Leave de $cmbWFmt (520) qui appellent
#       Update-PrecompForImage (refus du lecteur cible en tete et complement flux accordes au nouveau format), quand le
#       libelle est celui de l image du champ ($script:WProfilePath ; F8 : format pose par le code apres une nouvelle image) ;
#  m1 : Update-PrecompForImage ne remet plus $script:WTargetHead a vide en entree (corps interrompu : une seule tete) ;
#  m3 : gestionnaire de la case --precomp (520) : Update-WriteFactorNote apres Sync-WTargetHead -IfOwn (complement
#       « facteur » retire quand la case est decochee, remis quand elle est recochee).
# D apres la relecture r7 (v1210\rc4\revue\r7-789c19d\r7-logique.ps1, dont la matrice et les enchainements sont repris).
# Fonctions reelles extraites des modules par l arbre syntaxique : Set-PrecompFields, Get-TargetProfileText,
# Get-WProfileSpec, Get-HdProfile, Get-HdCommonCurve, Get-HeadSpec, Set-WProfileText, Get-WTargetHead, Sync-WTargetHead,
# Update-PrecompForImage (220), Get-CalibFamilyName, Get-ImageFamily (230), Update-WriteFactorNote, Get-WriteFactorNote,
# Get-TargetWriteInfo, Get-TargetWriteBlock, Test-RawFluxWrite, Test-FluxImage, Set-WTabNotice, Clear-WTabNotice,
# Get-WProfileText (140). Gestionnaires de 520 : corps des blocs des instructions de premier niveau « $cmbWFmt.Add_Enter »,
# « $cmbWFmt.Add_SelectedIndexChanged », « $cmbWFmt.Add_Leave », « $chkWPrecomp.Add_CheckedChanged », recopies tels quels
# dans des fonctions nommees (fichier de travail gen-1210-fix1-b-handlers.ps1, dot-source). Vrais controles WinForms en
# memoire (Label, CheckBox, ComboBox ; jamais affiches) ; Enter et Leave de la liste joues par l appel de leur fonction
# (pas de focus sans fenetre). Remplacants pilotes par un scenario ($S) : detection de l image, courbes croisees,
# Get-WriteFactorPlan (memes gardes que 140 : lecteur cible, fichier, profil, case --precomp, puis facteur du scenario).
# Aucun gw, aucune fenetre, aucun Add-Type, aucune evaluation de texte.
# Correction fixB de la RC5 (10/11/2026, v1210\rc5\fixB) : copie adaptee de v1210\rc4\fix1\logic-1210-fix1, qui la remplace dans la
# campagne : remplacant d Update-WLevelUi (140), appele en sortie d Update-PrecompForImage (220) ;
# attentes inchangees (F0a : le gestionnaire de la case --precomp appelle encore Sync-WTargetHead -IfOwn puis
# Update-WriteFactorNote).
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Import-TestWinForms
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$m = Join-Path $Wt 'src/modules'
if (-not (Test-Path -LiteralPath (Join-Path $m '140-fn-ecriture.ps1'))) { throw "modules introuvables sous $Wt" }
$Language = 'fr'
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'

$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    if (-not $ok) { $script:Fail++; $script:FailIds += $id }
    '{0,-8} {1,-12} {2}' -f $id, $(if ($ok) { 'conforme' } else { 'NON CONFORME' }), $d
}
function Get-FileAst([string]$file) {
    $tok = $null; $err = $null
    return [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tok, [ref]$err)
}
function Get-FnText([string]$file, [string[]]$names) {
    $ast = Get-FileAst $file
    $out = @()
    foreach ($n in $names) {
        $fn = @($ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | Where-Object { $_.Name -eq $n })
        if ($fn.Count -ne 1) { throw "fonction $n : $($fn.Count) definition(s) dans $file" }
        $out += $fn[0].Extent.Text
    }
    return ($out -join "`r`n`r`n")
}
function Get-HandlerBody([string]$file, [string]$prefix) {
    # Instruction de premier niveau qui commence par $prefix : texte, et corps de son premier bloc (le gestionnaire)
    $st = @((Get-FileAst $file).EndBlock.Statements | Where-Object { $_.Extent.Text.StartsWith($prefix, [System.StringComparison]::Ordinal) })
    if ($st.Count -ne 1) { return @{ N = $st.Count; Stmt = ''; Body = '' } }
    $sb = @($st[0].FindAll({ param($x) $x -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true))
    if ($sb.Count -lt 1) { return @{ N = 1; Stmt = $st[0].Extent.Text; Body = '' } }
    return @{ N = 1; Stmt = $st[0].Extent.Text; Body = $sb[0].ScriptBlock.EndBlock.Extent.Text }
}

# --- 0. Statique : gestionnaires de 520, entree d Update-PrecompForImage (220), garde de Get-WriteFactorPlan (140) -------
$f520 = Join-Path $m '520-ui-ecriture.ps1'
$hE = Get-HandlerBody $f520 '$cmbWFmt.Add_Enter('
$hS = Get-HandlerBody $f520 '$cmbWFmt.Add_SelectedIndexChanged('
$hL = Get-HandlerBody $f520 '$cmbWFmt.Add_Leave('
$hP = Get-HandlerBody $f520 '$chkWPrecomp.Add_CheckedChanged('
foreach ($x in @(@('Enter', $hE), @('SelectedIndexChanged', $hS), @('Leave', $hL), @('CheckedChanged (--precomp)', $hP))) { "  520 $($x[0]) : $($x[1].N) instruction(s) ; corps « $($x[1].Body) »" }
$okH = ($hE.N -eq 1 -and $hS.N -eq 1 -and $hL.N -eq 1 -and $hP.N -eq 1 -and $hE.Body -eq '$script:WFmtOnEnter = $cmbWFmt.Text' `
    -and $hS.Body.Contains('$script:UiReady') -and $hS.Body.Contains('-not $script:SettingSync') -and $hS.Body.Contains('Update-PrecompForImage $txtWFile.Text') -and $hS.Body.Contains('$script:WFmtOnEnter = $cmbWFmt.Text') `
    -and $hS.Body.Contains('$txtWFile.Text -eq [string]$script:WProfilePath') -and $hL.Body.Contains('$txtWFile.Text -eq [string]$script:WProfilePath') `
    -and $hL.Body.Contains('$script:UiReady') -and $hL.Body.Contains('-not $script:SettingSync') -and $hL.Body.Contains('$cmbWFmt.Text -ne $script:WFmtOnEnter') -and $hL.Body.Contains('Update-PrecompForImage $txtWFile.Text') `
    -and $hP.Body.Contains('-not $script:WProfileBuilding') -and $hP.Body.Contains('Sync-WTargetHead -IfOwn; Update-WriteFactorNote'))
Chk 'F0a' $okH "520 : une instruction de chaque gestionnaire ; liste du format : Enter retient le texte, SelectedIndexChanged et Leave (texte change) appellent Update-PrecompForImage apres UiReady, hors SettingSync, quand le libelle est celui de l image du champ (WProfilePath) ; case --precomp : Sync-WTargetHead -IfOwn puis Update-WriteFactorNote"
$t220 = Get-FnText (Join-Path $m '220-fn-profil-precomp.ps1') @('Update-PrecompForImage')
$t140 = Get-FnText (Join-Path $m '140-fn-ecriture.ps1') @('Get-WriteFactorPlan')
$iPc = $t140.IndexOf("elseif (-not `$chkWPrecomp.Checked) { `$r.Why = (T 'précompensation désactivée') }", [System.StringComparison]::Ordinal)
$iAp = $t140.IndexOf('$r.Apply = $true', [System.StringComparison]::Ordinal)
"  220 Update-PrecompForImage : remise a vide de WTargetHead $($t220.Contains("`$script:WTargetHead = ''")) ; 140 Get-WriteFactorPlan : garde de la case a $iPc, premier Apply vrai a $iAp"
Chk 'F0b' (-not $t220.Contains("`$script:WTargetHead = ''") -and $t220.Contains('$script:WProfilePath = $path') -and $iPc -gt 0 -and $iAp -gt $iPc) "220 : WTargetHead garde a l entree d Update-PrecompForImage ; 140 : Get-WriteFactorPlan ne rend Apply vrai qu apres la garde de la case --precomp (remplacant de ce test fidele a cet ordre)"

$code = (Get-FnText (Join-Path $m '220-fn-profil-precomp.ps1') @('Set-PrecompFields', 'Get-TargetProfileText', 'Get-WProfileSpec', 'Get-HdProfile', 'Get-HdCommonCurve', 'Get-HeadSpec', 'Set-WProfileText', 'Get-WTargetHead', 'Sync-WTargetHead', 'Update-PrecompForImage')) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '230-fn-calib-courbe.ps1') @('Get-CalibFamilyName', 'Get-ImageFamily')) + "`r`n`r`n" +
        (Get-FnText (Join-Path $m '140-fn-ecriture.ps1') @('Update-WriteFactorNote', 'Get-WriteFactorNote', 'Get-TargetWriteInfo', 'Get-WriteImageFamily', 'Get-TargetWriteBlock', 'Test-RawFluxWrite', 'Test-FluxImage', 'Set-WTabNotice', 'Clear-WTabNotice', 'Get-WProfileText')) + "`r`n`r`n" +
        "function Invoke-WFmtEnter {`r`n$($hE.Body)`r`n}`r`n`r`nfunction Invoke-WFmtSelChanged {`r`n$($hS.Body)`r`n}`r`n`r`nfunction Invoke-WFmtLeave {`r`n$($hL.Body)`r`n}`r`n`r`nfunction Invoke-WPrecompChanged {`r`n$($hP.Body)`r`n}`r`n"
$gen = Join-Path $here 'gen-1210-fix1-c-handlers.ps1'
[System.IO.File]::WriteAllText($gen, $code, (New-Object System.Text.UTF8Encoding($true)))
. $gen
function Update-WLevelUi { }   # fixB (RC5) : case de la mesure (140), appelee en sortie d Update-PrecompForImage

# --- Etat, controles et remplacants --------------------------------------------------------------------------------------
$script:PrecompStd = '0=70:40=100:65=140'; $script:PrecompLong = '0=85:20=110:40=120:65=140'
$script:PrecompStdDefault = $script:PrecompStd; $script:PrecompLongDefault = $script:PrecompLong; $script:PrecompHdDefault = '0=40:79=60'
$script:PrecompThresholdNs = 1950; $script:ScpStatsOk = $true; $script:PrecompCurves = @{}
$script:WFactorNote = $null; $script:WProfileHd = $false
$script:WTargetHead = ''; $script:WProfilePath = ''; $script:WProfileLabel = $null; $script:WProfileBuilding = $false
$script:UiReady = $true; $script:SettingSync = $false; $script:WTabNotice = $null; $script:WFmtOnEnter = $null
$script:UpdCalls = 0
$lblWProfileInfo = New-Object System.Windows.Forms.Label
$lblWProfileInfo.Text = 'Choisissez une image : le format et la précompensation seront déduits automatiquement.'
$lblWProfileInfo.Add_TextChanged({ Clear-WTabNotice; Update-WProfileTip })
$chkWPrecomp = New-Object System.Windows.Forms.CheckBox; $chkWPrecomp.Checked = $true
$chkWPrecomp.Add_CheckedChanged({ Invoke-WPrecompChanged })
$cmbWFmt = New-Object System.Windows.Forms.ComboBox
[void]$cmbWFmt.Items.AddRange(@('(auto)', 'amiga.amigados', 'amiga.amigados_hd', 'ibm.720', 'ibm.1440'))
$script:UiReady = $false; $cmbWFmt.SelectedIndex = 0; $script:UiReady = $true
$cmbWFmt.Add_SelectedIndexChanged({ Invoke-WFmtSelChanged })
$chkWSlow = [pscustomobject]@{ Checked = $false }
$txtWPrecomp = [pscustomobject]@{ Text = '' }; $txtWPrecomp1 = [pscustomobject]@{ Text = '' }; $txtWFile = [pscustomobject]@{ Text = '' }
$cmbDrive = [pscustomobject]@{ Text = 'A' }; $cmbWProfile = [pscustomobject]@{ Text = 'Auto'; SelectedIndex = 0 }
$S = @{}
$script:LogLines = New-Object System.Collections.Generic.List[string]
function Update-CurveButton($p) { $script:UpdCalls++ }
function Update-WProfileTip { }
function Append-Log([string]$t) { $script:LogLines.Add($t) }
function Get-ImageEncoding($p, $f) {
    if ($S.Throw) { throw 'erreur simulee (lecture de l en-tete)' }
    if ($S.NonMfm) { return @{ NonMfm = $true; Name = $S.NonMfm; Src = 'extension'; Enc = 'fm' } }
    return @{ NonMfm = $false; Enc = 'mfm' }
}
function Get-HighDensityReason($p, $f) { if ($S.HdIfFmt -and $f -ne $S.HdIfFmt) { return $null }; return $(if ($S.Hd) { [string]$S.Hd } else { $null }) }
function Get-HdCalibFamily($p, $f) { if ($S.HdIfFmt -and $f -ne $S.HdIfFmt) { return $null }; return $S.HdFam }
function Test-HeadCurvesCurrent($f) { return [bool]$S.HeadsCurrent }
function Get-IpfCellInfo($p) { return $S.Info }
function Get-ScpCellInfo($p) { return $S.Info }
function Get-HfeCellInfo($p) { return $S.Info }
function Get-TargetDrive([string]$src = '') { return [string]$S.Tgt }
function Get-CurveCalcText($c, [switch]$Plain) { return 'v12.10' }
function Get-WriteFactorPlan([string]$img, [string]$fmt, [bool]$slow, $next, [switch]$Peek) {
    # Remplacant : gardes de 140 dans le meme ordre (lecteur cible avec effet, fichier, profil, case --precomp), puis
    # facteur du scenario ($S.F : tete 0, tete 1) ; exception simulee ($S.ThrowFactor)
    if ($S.ThrowFactor) { throw 'erreur simulee (Get-WriteFactorPlan)' }
    $r = @{ Apply = $false; Why = ''; F0 = 1.0; F1 = 1.0; FMean = 1.0 }
    if ((Get-TargetWriteInfo $img $fmt $slow).Applies) { return $r }
    if (-not $img -or -not (Test-Path -LiteralPath $img)) { return $r }
    if ($cmbWProfile.SelectedIndex -ne 0) { return $r }
    if (-not $chkWPrecomp.Checked) { $r.Why = (T 'précompensation désactivée'); return $r }
    if ($S.F) { $r.Apply = $true; $r.F0 = [double]$S.F[0]; $r.F1 = [double]$S.F[1]; $r.FMean = ([double]$S.F[0] + [double]$S.F[1]) / 2 }
    return $r
}
$cx = @{ Spec = '0=90:40=130'; Date = '20/10/2026 09:00'; Test = 'std' }
$cx1 = @{ Spec = '0=95:40=135'; Date = '20/10/2026 09:00'; Test = 'std' }
function Get-TargetCurves($fam, $slow, $src, $tgt) {
    if (-not $S.Tgt) { return }
    $k = if ($S.CrossFam -and $S.CrossFam.ContainsKey($fam)) { $S.CrossFam[$fam] } elseif ($S.CrossFam) { 'none' } else { [string]$S.Cross }
    switch ($k) {
        'common' { $cx }
        'head' { if ($slow) { $cx; $cx1 } }
        'both' { if ($slow) { $cx; $cx1 } else { $cx } }
        default { }
    }
}

$imgDir = Join-Path $here 'img-fix1'
New-Item -ItemType Directory -Force -Path $imgDir | Out-Null
$img = @{}
foreach ($e in 'adf', 'scp', 'raw', 'img', 'ipf', 'hfe', 'd64', 'imd') { $p = Join-Path $imgDir "essai.$e"; if (-not (Test-Path -LiteralPath $p)) { [System.IO.File]::WriteAllBytes($p, [byte[]]@(0)) }; $img[$e] = $p }
$img['absent'] = Join-Path $imgDir 'absente.adf'
$modes = @{ 0 = 'Auto (selon image)'; 1 = 'Standard 2 us'; 2 = 'Long track 1,89 us'; 3 = 'Manuel' }

function Set-Case([hashtable]$sc, [int]$prof, [string]$fmt, [bool]$slow) {
    # Format pose hors gestionnaire (UiReady faux le temps de l affectation), comme avant la fenetre affichee
    $script:S = $sc; $chkWSlow.Checked = $slow; $cmbWProfile.SelectedIndex = $prof; $cmbWProfile.Text = (T $modes[$prof])
    $u = $script:UiReady; $script:UiReady = $false; $cmbWFmt.Text = $fmt; $script:UiReady = $u
}
function Invoke-Upd([string]$p) { $txtWFile.Text = $p; Update-PrecompForImage $p }
function Get-ExpectedHead($tw) {
    if (-not $tw.Block) { return '' }
    $sep = if ($script:Lang -eq 'fr') { ' ; ' } else { '; ' }
    switch ($tw.BlockKind) {
        'hd' { $t = (T " ; lecteur cible {0} : écriture refusée en haute densité (la calibration croisée n'existe qu'en double densité)") -f $tw.Tgt }
        'head' { $t = (T ' ; courbes croisées {1} → {0} par tête : écriture rapide refusée (cochez « Écriture lente »)') -f $tw.Tgt, $tw.Src }
        'none' { $t = (T ' ; aucune courbe croisée {1} → {0} : écriture refusée (« Calibrer pour un lecteur cible… »)') -f $tw.Tgt, $tw.Src }
        default { return '?BlockKind vide avec Block?' }
    }
    $t = $t.Substring($sep.Length)
    return $t.Substring(0, 1).ToUpper() + $t.Substring(1) + $sep
}
$script:Cohe = New-Object System.Collections.Generic.List[string]
function Test-Coherent([string]$name, [string]$path) {
    # Libelle du profil et refus reel (Get-TargetWriteInfo, format du moment) : le libelle commence par la tete attendue,
    # un seul refus annonce si et seulement si l ecriture est refusee. Vrai si conforme ; ecart garde dans $script:Cohe
    $tw = Get-TargetWriteInfo $path $cmbWFmt.Text ([bool]$chkWSlow.Checked)
    $lbl = [string]$lblWProfileInfo.Text
    $exp = Get-ExpectedHead $tw
    $nRef = ([regex]::Matches($lbl, 'refusée|refused')).Count
    $why = @()
    if ($exp) { if (-not $lbl.StartsWith($exp, [System.StringComparison]::Ordinal)) { $why += 'tete attendue absente' }; if ($nRef -ne 1) { $why += "$nRef refus annonces" } }
    elseif ($nRef -ne 0) { $why += "refus annonce ($nRef) sans Block" }
    if ($why.Count) { $script:Cohe.Add("$name : Block $([bool]$tw.Block) ($($tw.BlockKind)) ; $($why -join ', ') ; libelle « $lbl »"); return $false }
    return $true
}
function Count-Head([string]$h) { if (-not $h) { return 0 }; return ([regex]::Matches([string]$lblWProfileInfo.Text, [regex]::Escape($h.TrimEnd()))).Count }
function Show-Cohe([int]$from) { for ($i = $from; $i -lt $script:Cohe.Count -and $i -lt $from + 6; $i++) { "  ECART $($script:Cohe[$i])" } }

# --- 1. Matrice (r7) : profil x image x courbes croisees x ecriture lente x case --precomp x langue -------------------
$imgCases = @(
    @{ N = 'ADF secteur'; P = 'adf'; F = '(auto)' },
    @{ N = 'flux .raw non analyse (auto)'; P = 'raw'; F = '(auto)' },
    @{ N = 'flux .raw --format ibm.720'; P = 'raw'; F = 'ibm.720' },
    @{ N = 'SCP (auto) ecrit tel quel'; P = 'scp'; F = '(auto)'; Info = @{ CellNs = 2000; Bits = 100000; Tracks = 4; DosTracks = -1; Source = 'SCP (flux mesuré)' } },
    @{ N = 'SCP --format ibm.720 analyse std'; P = 'scp'; F = 'ibm.720'; Info = @{ CellNs = 2000; Bits = 100000; Tracks = 4; DosTracks = -1; Source = 'SCP (flux mesuré)' } },
    @{ N = 'SCP --format amiga analyse long'; P = 'scp'; F = 'amiga.amigados'; Info = @{ CellNs = 1890; Bits = 105800; Tracks = 4; DosTracks = -1; Source = 'SCP (flux mesuré)' } },
    @{ N = 'IPF std'; P = 'ipf'; F = '(auto)'; Info = @{ CellNs = 2000; Bits = 100000; Tracks = 160; DosTracks = 0; Source = 'IPF' } },
    @{ N = 'IPF long'; P = 'ipf'; F = '(auto)'; Info = @{ CellNs = 1890; Bits = 105800; Tracks = 160; DosTracks = 0; Source = 'IPF' } },
    @{ N = 'HFE std'; P = 'hfe'; F = '(auto)'; Info = @{ CellNs = 2000; Bits = 100000; Tracks = 160; DosTracks = -1; Source = 'HFE' } },
    @{ N = 'IMG HD calibrable'; P = 'img'; F = 'ibm.1440'; Hd = 'format haute densité ibm.1440'; HdFam = 'hd' },
    @{ N = 'IMG HD non calibrable (ED)'; P = 'img'; F = 'ibm.2880'; Hd = 'format haute densité ibm.2880'; HdFam = $null },
    @{ N = 'flux .raw --format ibm.1440 (HD)'; P = 'raw'; F = 'ibm.1440'; Hd = 'format haute densité ibm.1440'; HdFam = 'hd' },
    @{ N = 'D64 GCR'; P = 'd64'; F = '(auto)'; NonMfm = 'GCR' },
    @{ N = 'IMD FM'; P = 'imd'; F = '(auto)'; NonMfm = 'FM' },
    @{ N = 'fichier absent'; P = 'absent'; F = '(auto)' },
    @{ N = 'chemin vide'; P = ''; F = '(auto)' })
$crossCases = @(@{ N = 'sans cible'; Tgt = '' }, @{ N = 'cible, courbe commune'; Tgt = '0'; Cross = 'common' }, @{ N = 'cible, par tete seulement'; Tgt = '0'; Cross = 'head' },
                @{ N = 'cible, par tete et commune'; Tgt = '0'; Cross = 'both' }, @{ N = 'cible, aucune courbe'; Tgt = '0'; Cross = 'none' },
                @{ N = 'cible, courbe std seulement'; Tgt = '0'; CrossFam = @{ std = 'common' } })
"--- 1 : matrice de la relecture r7 (profils, 16 images, 6 etats des courbes croisees, lente et rapide, case cochee, decochee, recochee ; francais et anglais)"
$c0 = $script:Cohe.Count; $nCase = 0; $nOk = 0; $recoch = 0; $build = 0; $blk = @{}
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    foreach ($prof in 0..3) { foreach ($ic in $imgCases) { foreach ($cc in $crossCases) { foreach ($slow in $false, $true) {
        $sc = @{ Tgt = $cc.Tgt; Cross = $cc.Cross; CrossFam = $cc.CrossFam; Info = $ic.Info; Hd = $ic.Hd; HdFam = $ic.HdFam; NonMfm = $ic.NonMfm }
        Set-Case $sc $prof $ic.F $slow
        $path = if ($ic.P) { $img[$ic.P] } else { '' }
        $name = "[$lg | $($modes[$prof]) | $($ic.N) | $($cc.N) | lente $slow]"
        $chkWPrecomp.Checked = $true
        Invoke-Upd $path
        $nCase++
        $k = [string](Get-TargetWriteInfo $path $cmbWFmt.Text $slow).BlockKind; if (-not $blk.ContainsKey($k)) { $blk[$k] = 0 }; $blk[$k]++
        $a = Test-Coherent "$name cochee" $path
        if ($script:WProfileBuilding) { $build++ }
        $before = [string]$lblWProfileInfo.Text
        $chkWPrecomp.Checked = $false
        $b = Test-Coherent "$name decochee" $path
        $chkWPrecomp.Checked = $true
        $c = Test-Coherent "$name recochee" $path
        if ([string]$lblWProfileInfo.Text -cne $before) { $recoch++; $script:Cohe.Add("$name : libelle recoche different") }
        if ($a -and $b -and $c) { $nOk++ }
    } } } }
}
$script:Lang = 'fr'
"  $nCase cas ; BlockKind : $(($blk.GetEnumerator() | Sort-Object Name | ForEach-Object { "'$($_.Name)'=$($_.Value)" }) -join ', ')"
Show-Cohe $c0
Chk 'F1' ($nOk -eq $nCase -and $recoch -eq 0 -and $build -eq 0 -and $nCase -eq 1536) "$nOk/$nCase cas : refus en tete si et seulement si l ecriture est refusee, case cochee, decochee et recochee ; libelle recoche identique ($recoch ecart) ; WProfileBuilding remis a faux ($build ecart)"

# --- 2. Enchainements (r7, 2a a 2h) ---------------------------------------------------------------------------------------
"--- 2 : enchainements de la relecture r7 (image, facteur, avis, bilan, retablissements, ecriture lente)"
$c0 = $script:Cohe.Count; $r2 = @()
$noX = @{ Tgt = '0'; Cross = 'none' }
Set-Case $noX 0 '(auto)' $false; $chkWPrecomp.Checked = $true
Invoke-Upd $img.adf; $r2 += Test-Coherent '2a ADF aucune courbe' $img.adf
Set-Case @{ Tgt = '0'; Cross = 'none'; NonMfm = 'GCR' } 0 '(auto)' $false; Invoke-Upd $img.d64; $r2 += Test-Coherent '2a puis D64 GCR' $img.d64
Set-Case $noX 0 '(auto)' $false; Invoke-Upd $img.adf; $r2 += Test-Coherent '2a puis ADF de nouveau' $img.adf
# 2c avis de la Bibliotheque, 2d bilan de calibration : jamais modifies par la case
Set-Case $noX 0 '(auto)' $false; $chkWPrecomp.Checked = $true; Invoke-Upd $img.adf
Set-WTabNotice 'Bibliothèque terminée. Onglet Écriture rétabli : essai.adf.'
$chkWPrecomp.Checked = $false; $a = [string]$lblWProfileInfo.Text; $chkWPrecomp.Checked = $true; $b = [string]$lblWProfileInfo.Text
$r2 += ($a -eq 'Bibliothèque terminée. Onglet Écriture rétabli : essai.adf.' -and $b -eq $a)
Set-Case $noX 0 '(auto)' $false; $chkWPrecomp.Checked = $true; Invoke-Upd $img.adf
$lblWProfileInfo.Text = 'Profil Standard 2 us calibré le 10/11/2026 sur le lecteur A : courbe linéaire, de 60 à 140 ns, une valeur par cylindre (bouton Courbe).'
$chkWPrecomp.Checked = $false; $a = [string]$lblWProfileInfo.Text; $chkWPrecomp.Checked = $true; $b = [string]$lblWProfileInfo.Text
$r2 += ($a -eq $b -and $a.StartsWith('Profil Standard'))
# 2e Restore-CalibState, 2f Restore-WriteTabState (case decochee avant)
Set-Case $noX 0 '(auto)' $false; $chkWPrecomp.Checked = $true; Invoke-Upd $img.adf
$chkWPrecomp.Checked = $false
$prev = @{ On = $chkWPrecomp.Checked; Lbl = (Get-WProfileText) }
Invoke-Upd $img.adf; Invoke-Upd $img.adf
$chkWPrecomp.Checked = $prev.On; $lblWProfileInfo.Text = $prev.Lbl
$r2 += Test-Coherent '2e apres Restore-CalibState (case decochee)' $img.adf
$chkWPrecomp.Checked = $true; $r2 += Test-Coherent '2e case recochee ensuite' $img.adf
Set-Case $noX 0 '(auto)' $false; $chkWPrecomp.Checked = $true; Invoke-Upd $img.adf
$chkWPrecomp.Checked = $false
$chkWPrecomp.Checked = $true; Invoke-Upd $img.scp
$chkWPrecomp.Checked = $false; Invoke-Upd $img.adf; $chkWPrecomp.Checked = $false
$r2 += Test-Coherent '2f apres Restore-WriteTabState' $img.adf
$chkWPrecomp.Checked = $true; $r2 += Test-Coherent '2f case recochee ensuite' $img.adf
# 2h ecriture lente cochee puis decochee : courbes par tete seulement
Set-Case @{ Tgt = '0'; Cross = 'head' } 0 '(auto)' $false; $chkWPrecomp.Checked = $true; Invoke-Upd $img.adf; $r2 += Test-Coherent '2h rapide, par tete seulement' $img.adf
$chkWSlow.Checked = $true; Invoke-Upd $img.adf; $r2 += Test-Coherent '2h lente' $img.adf
$chkWSlow.Checked = $false; Invoke-Upd $img.adf; $r2 += Test-Coherent '2h rapide de nouveau' $img.adf
Show-Cohe $c0
Chk 'F2' (@($r2 | Where-Object { -not $_ }).Count -eq 0) "$(@($r2 | Where-Object { $_ }).Count)/$($r2.Count) controles : changement d image, avis de la Bibliotheque et bilan de calibration inchanges par la case, retablissements, ecriture lente"

# --- 3. m1 : corps d Update-PrecompForImage interrompu : une seule tete -------------------------------------------------
"--- 3 : m1, exception dans le corps d Update-PrecompForImage (lecture de l en-tete ; complement « facteur »)"
$c0 = $script:Cohe.Count; $r3 = @()
foreach ($kind in 'Throw', 'ThrowFactor') {
    Set-Case $noX 0 '(auto)' $false; $chkWPrecomp.Checked = $true; Invoke-Upd $img.adf
    $h = $script:WTargetHead
    $S[$kind] = $true
    $ex = ''; try { Invoke-Upd $img.adf } catch { $ex = $_.Exception.Message }
    $S[$kind] = $false
    $n1 = Count-Head $h; $bd = $script:WProfileBuilding
    $chkWPrecomp.Checked = $false; $n2 = Count-Head $h; $co2 = Test-Coherent "3 $kind, case decochee" $img.adf
    $chkWPrecomp.Checked = $true; $n3 = Count-Head $h; $co3 = Test-Coherent "3 $kind, case recochee" $img.adf
    "  $kind : exception « $ex » ; tete $n1 fois apres l exception, $n2 fois case decochee, $n3 fois recochee ; WProfileBuilding $bd ; libelle « $($lblWProfileInfo.Text) »"
    # Lecture de l en-tete en echec : Get-TargetWriteInfo echoue aussi en sortie (refus inconnu) : tete retiree (0) ;
    # complement « facteur » en echec : refus connu, tete gardee une fois (avant la correction : deux fois)
    $r3 += ($h -and $ex -and $n1 -eq $(if ($kind -eq 'Throw') { 0 } else { 1 }) -and -not $bd -and $n2 -eq 0 -and $co2 -and $n3 -eq 1 -and $co3)
}
Show-Cohe $c0
Chk 'F3' (@($r3 | Where-Object { -not $_ }).Count -eq 0 -and $r3.Count -eq 2) "exception dans le corps : complement « facteur » : une seule tete en tete de l ancien libelle (avant la correction : deux) ; lecture de l en-tete (refus inconnu en sortie) : tete retiree ; puis case decochee : aucune tete, recochee : une, libelle conforme au refus reel"

# --- 4. B1 : format choisi dans la liste apres l image -----------------------------------------------------------------
"--- 4 : B1, format choisi dans la liste apres l image (SelectedIndexChanged)"
$c0 = $script:Cohe.Count; $r4 = @()
$scpInfo = @{ CellNs = 2000; Bits = 100000; Tracks = 4; DosTracks = -1; Source = 'SCP (flux mesuré)' }
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    Set-Case @{ Tgt = '0'; Cross = 'none'; Info = $scpInfo } 0 '(auto)' $false; $chkWPrecomp.Checked = $true
    Invoke-Upd $img.scp; $a0 = Test-Coherent "4 $lg SCP (auto)" $img.scp; $l0 = [string]$lblWProfileInfo.Text
    $script:UpdCalls = 0; $cmbWFmt.SelectedItem = 'ibm.720'; $n1 = $script:UpdCalls
    $a1 = Test-Coherent "4 $lg SCP puis ibm.720 choisi" $img.scp; $l1 = [string]$lblWProfileInfo.Text
    $script:UpdCalls = 0; $cmbWFmt.SelectedIndex = 0; $n2 = $script:UpdCalls
    $a2 = Test-Coherent "4 $lg SCP puis (auto) de nouveau" $img.scp; $l2 = [string]$lblWProfileInfo.Text
    $fx = (T " ; image flux écrite telle quelle (sans --format) : gw n'applique pas la précompensation, --precomp n'est pas transmis").TrimStart(' ', ';')
    "  $lg SCP : (auto) « $l0 »"
    "     ibm.720 ($n1 appel) « $l1 »"
    "     (auto) ($n2 appel) « $l2 »"
    $r4 += ($a0 -and $a1 -and $a2 -and $n1 -eq 1 -and $n2 -eq 1 -and $l0.Contains($fx) -and -not $l1.Contains($fx) -and $l1 -match 'refusée|refused' -and $l2 -eq $l0)
    Set-Case @{ Tgt = '0'; Cross = 'common'; Hd = 'format haute densité ibm.1440'; HdFam = 'hd'; HdIfFmt = 'ibm.1440' } 0 '(auto)' $false; $chkWPrecomp.Checked = $true
    Invoke-Upd $img.img; $b0 = Test-Coherent "4 $lg IMG (auto), courbe croisee" $img.img; $m0 = [string]$lblWProfileInfo.Text
    $script:UpdCalls = 0; $cmbWFmt.SelectedItem = 'ibm.1440'; $n3 = $script:UpdCalls
    $b1 = Test-Coherent "4 $lg IMG puis ibm.1440 choisi" $img.img; $m1 = [string]$lblWProfileInfo.Text
    $hdHead = Get-ExpectedHead (Get-TargetWriteInfo $img.img 'ibm.1440' $false)
    "  $lg IMG : (auto) « $m0 »"
    "     ibm.1440 ($n3 appel) « $m1 »"
    $r4 += ($b0 -and $b1 -and $n3 -eq 1 -and $hdHead -and $m1.StartsWith($hdHead, [System.StringComparison]::Ordinal) -and $m0 -notmatch 'refusée|refused')
    $script:UiReady = $false; $cmbWFmt.SelectedIndex = 0; $script:UiReady = $true
}
$script:Lang = 'fr'
Show-Cohe $c0
Chk 'F4' (@($r4 | Where-Object { -not $_ }).Count -eq 0 -and $r4.Count -eq 4) "francais et anglais : SCP (auto) puis ibm.720 : complement « flux ecrit tel quel » remplace par le refus du lecteur cible (aucune courbe croisee), retour a (auto) : libelle d avant ; IMG (auto) puis ibm.1440 : refus haute densite en tete ; un appel d Update-PrecompForImage par choix"

# --- 5. B1 : saisie libre (Enter, texte tape, Leave) ----------------------------------------------------------------------
"--- 5 : B1, format tape au clavier (Leave)"
$c0 = $script:Cohe.Count
Set-Case @{ Tgt = '0'; Cross = 'common'; Hd = 'format haute densité ibm.1200'; HdFam = 'hd'; HdIfFmt = 'ibm.1200' } 0 '(auto)' $false; $chkWPrecomp.Checked = $true
Invoke-Upd $img.img; $d0 = Test-Coherent '5 IMG (auto)' $img.img
Invoke-WFmtEnter
$script:UpdCalls = 0; $cmbWFmt.Text = 'ibm.1200'; $n1 = $script:UpdCalls
$stale = -not (Test-Coherent '5 ibm.1200 tape, avant Leave (perime attendu, non juge)' $img.img)
$script:UpdCalls = 0; Invoke-WFmtLeave; $n2 = $script:UpdCalls
$d1 = Test-Coherent '5 ibm.1200 tape, apres Leave' $img.img
$l5 = [string]$lblWProfileInfo.Text
$script:UpdCalls = 0; Invoke-WFmtEnter; Invoke-WFmtLeave; $n3 = $script:UpdCalls
"  texte tape : $n1 appel pendant la saisie (libelle perime avant Leave : $stale), $n2 appel au Leave ; Enter puis Leave sans changement : $n3 appel ; libelle « $l5 »"
if ($stale) { $script:Cohe.RemoveAt($script:Cohe.Count - 1) }   # ecart attendu avant Leave, non juge
Show-Cohe $c0
Chk 'F5' ($d0 -and $d1 -and $n1 -eq 0 -and $n2 -eq 1 -and $n3 -eq 0) "format hors liste tape (ibm.1200, haute densite) : libelle recalcule au Leave (refus haute densite en tete), un appel ; Leave sans changement du texte : aucun appel"

# --- 6. B1 : choix dans la liste puis Leave : un seul appel ; gardes UiReady et SettingSync -------------------------------
"--- 6 : B1, appel unique et gardes"
Set-Case @{ Tgt = ''; Info = $scpInfo } 0 '(auto)' $false; Invoke-Upd $img.scp
Invoke-WFmtEnter
$script:UpdCalls = 0; $cmbWFmt.SelectedItem = 'ibm.720'; Invoke-WFmtLeave; $n1 = $script:UpdCalls
$script:UiReady = $false; $script:UpdCalls = 0; Invoke-WFmtEnter; $cmbWFmt.SelectedItem = 'amiga.amigados'; Invoke-WFmtLeave; $n2 = $script:UpdCalls; $script:UiReady = $true
$script:SettingSync = $true; $script:UpdCalls = 0; Invoke-WFmtEnter; $cmbWFmt.SelectedIndex = 0; Invoke-WFmtLeave; $n3 = $script:UpdCalls; $script:SettingSync = $false
$script:UpdCalls = 0; $cmbWFmt.SelectedIndex = 0; $n4 = $script:UpdCalls
"  liste puis Leave : $n1 appel ; UiReady faux : $n2 ; SettingSync vrai : $n3 ; meme element choisi de nouveau : $n4"
Chk 'F6' ($n1 -eq 1 -and $n2 -eq 0 -and $n3 -eq 0 -and $n4 -eq 0) "choix dans la liste puis sortie du champ : un seul Update-PrecompForImage ; aucun avant la fenetre affichee (UiReady) ni sous la garde des liaisons (SettingSync) ; aucun sans changement"

# --- 8. B1 : format pose par le code juste apres une nouvelle image (bouton dossier, Set-WritePreset) ; sans image --------
"--- 8 : B1, format pose apres une nouvelle image (libelle d une autre image) ; aucune image"
Set-Case @{ Tgt = ''; Info = $scpInfo } 0 '(auto)' $false; Invoke-Upd $img.scp
# bouton dossier : image changee dans le champ, puis format pose, puis Update-PrecompForImage du code (520)
$txtWFile.Text = $img.adf; $script:UpdCalls = 0; $cmbWFmt.SelectedItem = 'amiga.amigados'; $n1 = $script:UpdCalls
Update-PrecompForImage $img.adf; $n1b = $script:UpdCalls
# meme image ensuite : format change par l utilisateur -> recalcule
$script:UpdCalls = 0; $cmbWFmt.SelectedIndex = 0; $n2 = $script:UpdCalls
# champ Image vide (Set-Defaults) : aucun calcul
$txtWFile.Text = ''; Update-PrecompForImage ''; $script:UpdCalls = 0; $cmbWFmt.SelectedItem = 'ibm.720'; Invoke-WFmtEnter; $cmbWFmt.Text = 'ibm.1440'; Invoke-WFmtLeave; $n3 = $script:UpdCalls
$script:UiReady = $false; $cmbWFmt.SelectedIndex = 0; $script:UiReady = $true
"  nouvelle image puis format pose par le code : $n1 appel avant celui du code ($n1b en tout) ; meme image, format change : $n2 ; sans image : $n3"
Chk 'F8' ($n1 -eq 0 -and $n1b -eq 1 -and $n2 -eq 1 -and $n3 -eq 0) "format pose apres une nouvelle image, avant son calcul : aucun appel de plus (le code qui change l image recalcule : ni calcul ni ligne de journal en double) ; libelle de l image du champ : recalcule ; sans image : aucun appel"

# --- 7. m3 : complement « facteur » et case --precomp ---------------------------------------------------------------------
"--- 7 : m3, complement « facteur » retire case decochee, remis recochee"
$c0 = $script:Cohe.Count; $r7 = @()
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    foreach ($slow in $false, $true) {
        Set-Case @{ Tgt = ''; F = @(1.05, 1.15) } 0 '(auto)' $slow; $chkWPrecomp.Checked = $true
        Invoke-Upd $img.adf
        $l0 = [string]$lblWProfileInfo.Text; $note = [string]$script:WFactorNote.Note; $base = [string]$script:WFactorNote.Base
        $chkWPrecomp.Checked = $false; $l1 = [string]$lblWProfileInfo.Text; $n1 = [string]$script:WFactorNote.Note
        $chkWPrecomp.Checked = $true; $l2 = [string]$lblWProfileInfo.Text
        "  $lg, lente $slow : cochee « $l0 »"
        "     decochee « $l1 »"
        $r7 += ($note -and $l0 -eq ($base + $note) -and $l1 -eq $base -and -not $n1 -and $l2 -eq $l0)
    }
}
$script:Lang = 'fr'
# Avis de la Bibliotheque pose apres un libelle a complement « facteur » : inchange par la case
Set-Case @{ Tgt = ''; F = @(1.10, 1.10) } 0 '(auto)' $false; $chkWPrecomp.Checked = $true; Invoke-Upd $img.adf
Set-WTabNotice 'Bibliothèque terminée. Onglet Écriture rétabli : essai.adf.'
$chkWPrecomp.Checked = $false; $a = [string]$lblWProfileInfo.Text; $chkWPrecomp.Checked = $true; $b = [string]$lblWProfileInfo.Text
"  avis de la Bibliotheque, case decochee puis recochee : « $a » / « $b »"
$r7 += ($a -eq 'Bibliothèque terminée. Onglet Écriture rétabli : essai.adf.' -and $b -eq $a)
# Profil force : aucun facteur, case sans effet sur le complement
Set-Case @{ Tgt = ''; F = @(1.10, 1.10) } 1 '(auto)' $false; $chkWPrecomp.Checked = $true; Invoke-Upd $img.adf
$a = [string]$lblWProfileInfo.Text; $chkWPrecomp.Checked = $false; $b = [string]$lblWProfileInfo.Text; $chkWPrecomp.Checked = $true
$r7 += ($a -eq $b -and $a -notmatch 'facteur|factor')
Show-Cohe $c0
Chk 'F7' (@($r7 | Where-Object { -not $_ }).Count -eq 0 -and $r7.Count -eq 6) "profil Auto, ecriture rapide et lente, francais et anglais : complement « facteur » retire du libelle case decochee (aucun facteur applique), remis a l identique recochee ; avis de la Bibliotheque et profil force inchanges"

Remove-Item -LiteralPath $imgDir -Recurse -Force -ErrorAction SilentlyContinue
$nk = if ($script:Fail) { ' ; non conformes : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-1210-fix1-c : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
