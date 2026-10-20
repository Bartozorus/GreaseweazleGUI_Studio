# ============================== FONCTIONS : CONFIGURATION ======================

# --- Reglages a source unique (12.8, point 7) ----------------------------------
# Table $script:SettingDefs (040-etat-formats). Une valeur passe toujours par Set-Setting : bornes et type
# (ConvertTo-SettingValue), stockage (Set-SettingStore), recopie dans les controles d onglet lies sous la garde de
# reentrance $script:SettingSync, puis reglages et affichages dependants (Update-SettingDependents, aiguillage statique).
# Les gestionnaires propres des controles (Update-SlowUi, Update-PrecompForImage...) restent attaches a leurs controles :
# ils s executent a chaque changement, qu il vienne de l utilisateur ou de Set-Setting. Les dialogues (frmHomeCalib,
# frmClean) lisent le reglage a leur ouverture et l ecrivent quand l action est lancee. Un seul Import-Settings
# (Load-Config), Export-Settings (Save-Config) et Reset-Settings (Set-Defaults) pour tous les reglages de la table.

function ConvertTo-SettingValue([string]$k, $v) {
    # Valeur ramenee au type et aux bornes du reglage $k ; absente, tableau ou illisible : defaut. Enum : code exact, ou
    # ancien texte traduit (Legacy, francais ou anglais), ou rang entier (Json 'index', configuration 12.7)
    $d = $script:SettingDefs[$k]
    if (-not $d) { return $null }
    if ($null -eq $v -or $v -is [array]) { return $d.Def }
    switch ($d.Type) {
        'bool' {
            if ($v -is [bool]) { return $v }
            $s = ([string]$v).Trim()
            if ($s -eq 'True') { return $true }
            if ($s -eq 'False') { return $false }
            return $d.Def
        }
        'int' {
            if ($v -is [bool]) { return $d.Def }
            $x = 0.0
            if (-not [double]::TryParse(([string]$v).Trim(), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$x) -or [double]::IsNaN($x) -or [double]::IsInfinity($x)) { return $d.Def }
            return [int][math]::Max([double]$d.Min, [math]::Min([double]$d.Max, [math]::Round($x)))
        }
        'double' {
            if ($v -is [bool]) { return $d.Def }
            $x = 0.0
            if (-not [double]::TryParse(([string]$v).Trim(), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$x) -or [double]::IsNaN($x) -or [double]::IsInfinity($x)) { return $d.Def }
            return [double][math]::Max([double]$d.Min, [math]::Min([double]$d.Max, $x))
        }
        'enum' {
            $s = [string]$v
            foreach ($c in $d.Codes) { if ($c -ceq $s) { return $c } }
            if ($d.Legacy -and $d.Legacy.ContainsKey($s)) { return $d.Legacy[$s] }
            if ($d.Json -eq 'index' -and $v -isnot [bool]) {
                $x = 0.0
                if ([double]::TryParse($s.Trim(), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$x) -and $x -eq [math]::Floor($x) -and $x -ge 0 -and $x -lt $d.Codes.Count) { return $d.Codes[[int]$x] }
            }
            return $d.Def
        }
    }
    return $d.Def
}

function Get-Setting([string]$k) {
    # Valeur courante du reglage $k. Reglages a variable propre (Var) : la variable, que lisent aussi le code existant,
    # les fins de test et l enveloppe du prechauffage de make-test (CalWarmupMinutes)
    switch ($k) {
        'warmMinutes'        { return [double]$script:CalWarmupMinutes }
        'precompThresholdNs' { return [int]$script:PrecompThresholdNs }
        'jitterOk'           { return [int]$script:JitterOk }
        'jitterWatch'        { return [int]$script:JitterWatch }
    }
    return $script:Settings[$k]
}

function Set-SettingStore([string]$k, $v) {
    # Stockage d une valeur deja bornee ; seuils de jitter : paire bornee par Set-JitterThresholds (A SURVEILLER au moins
    # 10 ns au-dessus de SAIN)
    switch ($k) {
        'warmMinutes'        { $script:CalWarmupMinutes = [double]$v; return }
        'precompThresholdNs' { $script:PrecompThresholdNs = [int]$v; return }
        'jitterOk'           { Set-JitterThresholds ([int]$v) ([int]$script:JitterWatch); return }
        'jitterWatch'        { Set-JitterThresholds ([int]$script:JitterOk) ([int]$v); return }
    }
    $script:Settings[$k] = $v
}

function Set-SettingCtlValue($c, [string]$k, $v) {
    # Valeur affichee par un controle lie (CheckBox, ComboBox dans l ordre des codes, NumericUpDown borne a ses limites) ;
    # propriete modifiee seulement si elle change (pas d evenement inutile)
    if ($c -is [System.Windows.Forms.CheckBox]) { if ($c.Checked -ne [bool]$v) { $c.Checked = [bool]$v } }
    elseif ($c -is [System.Windows.Forms.ComboBox]) {
        $i = [array]::IndexOf([string[]]$script:SettingDefs[$k].Codes, [string]$v)
        if ($i -lt $c.Items.Count -and $c.SelectedIndex -ne $i) { $c.SelectedIndex = $i }
    }
    elseif ($c -is [System.Windows.Forms.NumericUpDown]) {
        $x = [decimal]$v
        if ($x -lt $c.Minimum) { $x = $c.Minimum } elseif ($x -gt $c.Maximum) { $x = $c.Maximum }
        if ($c.Value -ne $x) { $c.Value = $x }
    }
}

function Set-Setting([string]$k, $v, $from = $null) {
    # Nouvelle valeur du reglage $k : bornee, stockee si elle change, recopiee dans les controles lies (sauf $from, le
    # controle qui l a changee ; valeur inchangee : controles resynchronises), puis propagee. Garde sauvegardee et
    # retablie : un appel imbrique ne leve pas la garde d un appel en cours
    if (-not $script:SettingDefs.Contains($k)) { return }
    $nv = ConvertTo-SettingValue $k $v
    $cur = Get-Setting $k
    if (-not ($null -ne $cur -and $cur -eq $nv -and $cur.GetType() -eq $nv.GetType())) { Set-SettingStore $k $nv }
    $nv = Get-Setting $k
    $sv = $script:SettingSync; $script:SettingSync = $true
    try {
        if ($script:SettingCtl.ContainsKey($k)) {
            foreach ($c in @($script:SettingCtl[$k])) { if ($c -and -not $c.IsDisposed -and -not [object]::ReferenceEquals($c, $from)) { Set-SettingCtlValue $c $k $nv } }
        }
    } finally { $script:SettingSync = $sv }
    Update-SettingDependents $k
}

function Register-SettingCtl([string]$k, $c) {
    # Liaison directe d un controle d onglet au reglage $k : toute modification du controle (utilisateur, code, fin de
    # test) passe par Set-Setting, sauf sous la garde (recopie par Set-Setting). Aucune valeur posee ici : Set-Defaults,
    # puis Load-Config, initialisent les controles au demarrage
    if (-not $script:SettingCtl.ContainsKey($k)) { $script:SettingCtl[$k] = New-Object System.Collections.ArrayList }
    [void]$script:SettingCtl[$k].Add($c); $script:SettingOf[$c] = $k
    if ($c -is [System.Windows.Forms.CheckBox]) { $c.Add_CheckedChanged({ if (-not $script:SettingSync) { Set-Setting $script:SettingOf[$this] $this.Checked $this } }) }
    elseif ($c -is [System.Windows.Forms.ComboBox]) { $c.Add_SelectedIndexChanged({ if (-not $script:SettingSync -and $this.SelectedIndex -ge 0) { $kk = $script:SettingOf[$this]; Set-Setting $kk $script:SettingDefs[$kk].Codes[$this.SelectedIndex] $this } }) }
    elseif ($c -is [System.Windows.Forms.NumericUpDown]) { $c.Add_ValueChanged({ if (-not $script:SettingSync) { Set-Setting $script:SettingOf[$this] $this.Value $this } }) }
}

function Update-SettingDependents([string]$k) {
    # Propagation d un changement : aiguillage statique (appels visibles par impact.ps1 et par static-check). Les controles
    # lies portent deja leurs gestionnaires (ecriture lente, mode de calibration, profil, mesure de qualite) ; restent ici
    # les reglages sans controle propre ou affiches ailleurs : duree du prechauffage (textes et cases de l onglet
    # Ecriture), mesure de la disquette (case cochee et verrouillee en test rapide, D5) ; lot 2 : lecteur de la
    # restauration (cadre 1, D10) et ligne du format detecte (D11) ; format de la comparaison (format saisi, ligne du format
    # detecte, D13)
    switch ($k) {
        'warmMinutes'      { Update-SlowUi }
        'levelBeforeWrite' { Update-SlowUi }
        'drive'            { Update-RsDrive }
        'restoreFormat'    { Update-RsFmtFound }
        'compareFormat'    { Update-CmpFmtFound }
    }
}

function Get-SettingText([string]$k, $v) {
    # Texte de la valeur $v dans la langue de l interface (element de la liste liee) : enregistre sous LegacyKey pour une
    # 12.7 ; sans liste liee : le code
    $d = $script:SettingDefs[$k]
    $i = [array]::IndexOf([string[]]$d.Codes, [string]$v)
    if ($i -ge 0 -and $script:SettingCtl.ContainsKey($k)) {
        foreach ($c in @($script:SettingCtl[$k])) { if ($c -is [System.Windows.Forms.ComboBox] -and $i -lt $c.Items.Count) { return [string]$c.Items[$i] } }
    }
    return [string]$v
}

function Reset-Settings {
    # Set-Defaults : defaut de la table pour chaque reglage
    foreach ($k in @($script:SettingDefs.Keys)) { Set-Setting $k $script:SettingDefs[$k].Def }
}

function Import-Settings($cfg, [string[]]$Only = @(), [string[]]$Except = @()) {
    # Load-Config : chaque reglage lu a sa cle (enum : code d abord, sinon ancien texte traduit de LegacyKey), puis
    # Set-Setting ; cle absente : defaut. Duree du prechauffage : lignes de journal de la 12.6 (valeur illisible, ou
    # ramenee aux bornes). Only / Except : reglages lus a cet appel (Load-Config lit chaque reglage une fois, a la
    # place qu il avait en 12.7)
    foreach ($k in @($script:SettingDefs.Keys)) {
        if ($Only.Count -gt 0 -and $Only -notcontains $k) { continue }
        if ($Except -contains $k) { continue }
        $d = $script:SettingDefs[$k]
        $sec = Get-Cfg $cfg $d.Sec $null
        $raw = Get-Cfg $sec $d.Key $null
        if ($d.LegacyKey) {
            $ok = $false
            if ($null -ne $raw -and $raw -isnot [array]) { foreach ($c in $d.Codes) { if ($c -ceq [string]$raw) { $ok = $true } } }
            if (-not $ok) { $raw = Get-Cfg $sec $d.LegacyKey $null }
        }
        $v = ConvertTo-SettingValue $k $raw
        if ($k -eq 'warmMinutes' -and $null -ne $raw) {
            $wd = 0.0
            if ($raw -isnot [bool] -and $raw -isnot [array] -and [double]::TryParse(([string]$raw).Trim(), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$wd) -and -not [double]::IsNaN($wd) -and -not [double]::IsInfinity($wd)) {
                if ($v -ne $wd) { Append-Log ((T "Préchauffage du lecteur (calWarmupMinutes) de {0} min ramené à {1} min : il va de 0 à {2} min.") -f "$raw", "$v", "$($d.Max)") }
            } else { Append-Log ((T "Préchauffage du lecteur (calWarmupMinutes) illisible ({0}) : {1} min par défaut.") -f "$raw", "$($d.Def)") }
        }
        Set-Setting $k $v
    }
}

function Export-Settings($cfg) {
    # Save-Config : chaque reglage ecrit a sa cle (Json 'index' : rang ; Text : texte traduit aussi sous LegacyKey) ;
    # section creee si elle manque
    foreach ($k in @($script:SettingDefs.Keys)) {
        $d = $script:SettingDefs[$k]
        if (-not $cfg.Contains($d.Sec)) { $cfg[$d.Sec] = @{} }
        $v = Get-Setting $k
        if ($d.Json -eq 'index') { $cfg[$d.Sec][$d.Key] = [int][math]::Max(0, [array]::IndexOf([string[]]$d.Codes, [string]$v)) }
        else { $cfg[$d.Sec][$d.Key] = $v }
        if ($d.Text) { $cfg[$d.Sec][$d.LegacyKey] = Get-SettingText $k $v }
    }
}

function Update-LegacyCleanDefault($cfg) {
    # 12.8 (D9) : nettoyage de l onglet Outils a 3 x 500 ms par defaut ; la 12.7 ecrivait son defaut, 3 x 100 ms, a chaque
    # enregistrement. Configuration d une version anterieure (aucune cle 12.8 : write.calibWarmup, ui.homeCalHeads) avec
    # exactement l ancien defaut : nouveau defaut, ligne de journal ; toute autre valeur est gardee. Load-Config, apres
    # Import-Settings
    if ($null -ne (Get-Cfg (Get-Cfg $cfg 'write' $null) 'calibWarmup' $null) -or $null -ne (Get-Cfg (Get-Cfg $cfg 'ui' $null) 'homeCalHeads' $null)) { return }
    if ((Get-Setting 'cleanPasses') -ne 3 -or (Get-Setting 'cleanLinger') -ne 100) { return }
    Set-Setting 'cleanLinger' $script:SettingDefs['cleanLinger'].Def
    Append-Log ((T "Nettoyage de l'onglet Outils : ancien réglage par défaut (3 passes, {0} ms par position) remplacé par le nouveau, 3 passes de {1} ms par position, comme le préréglage « Standard » de la fenêtre « Nettoyage des têtes ».") -f '100', "$(Get-Setting 'cleanLinger')")
}

# --- Configuration -------------------------------------------------------------
function Set-Defaults {
    $script:CalHardNs = $script:CalHardNsDefault; $script:CalHardNsUser = $script:CalHardNs; Set-CalibScale ''   # 12.7 : bareme double densite
    $script:HomeCalFmt = 'amiga.amigados'
    $txtDev.Text = ''
    $chkTime.Checked = $false

    $txtLibRoot.Text = ''
    $txtLibFilter.Text = ''
    $chkLibImgOnly.Checked = $false

    $txtWFile.Text = ''
    $cmbWFmt.SelectedIndex = 0
    $chkWPreErase.Checked = $true
    $chkWEraseEmpty.Checked = $true
    $chkWNoVerify.Checked = $false
    $chkWReverse.Checked = $false
    $chkWHard.Checked = $false
    $chkWTG43.Checked = $false
    $numWRetries.Value = 10
    $chkWPrecomp.Checked = $true
    $txtWPrecomp.Text = $script:PrecompStd
    $txtWPrecomp1.Text = $script:PrecompStd
    $chkWPostCheck.Checked = $true
    $numWRepair.Value = 3
    # 12.8 (point 7) : reglages de la table (lecteur, mode de calibration, ecriture lente, prechauffages et leur duree,
    # mesure de la disquette, profil precomp, seuil de famille, carte « Calibrer le lecteur », mesure de l onglet
    # Qualite, seuils de jitter, nettoyage de l onglet Outils) : defauts de la table, y compris le seuil precompThresholdNs
    # (12.7 : non remis par defaut)
    Reset-Settings
    Update-SlowUi
    $lblWProfileInfo.Text = ''
    $txtWTracks.Text = ''
    $cmbWDensel.SelectedIndex = 0
    $txtWFakeIdx.Text = ''
    $txtWDiskdefs.Text = ''

    $txtRFile.Text = ''
    $cmbRFmt.SelectedIndex = 0
    $numRevs.Value = 5
    $numRRetries.Value = 10
    $txtRTracks.Text = ''
    $chkRRaw.Checked = $false
    $chkRRev.Checked = $false
    $cmbRDensel.SelectedIndex = 0
    $txtRDiskdefs.Text = ''

    $txtCvIn.Text = ''
    $txtCvOut.Text = ''
    $cmbCvFmt.SelectedIndex = 0
    $txtCvTracks.Text = ''

    $cmbAlHead.SelectedIndex = 2
    $txtAlCyls.Text = '0,10,20,30,40,50,60,70'
    $numAlRevs.Value = 3
    $chkAlLoop.Checked = $false
    $numAlPause.Value = 2
    $chkAlGuide.Checked = $false

    $txtCmpRef.Text = ''
    # 12.8 (D13) : format de la comparaison (compareFormat, detection automatique) remis par Reset-Settings
    $numCmpRetries.Value = 10
    $txtCmpResult.Text = (T "Compare le contenu physique d'une disquette à une image de référence (IPF, ADF, SCP, HFE...).`r`n`r`n") +
                         (T "Principe : la référence est convertie par gw dans le format de décodage choisi, la disquette est`r`n") +
                         (T "lue dans ce même format, puis les deux fichiers sont comparés octet par octet, secteur par secteur.`r`n`r`n") +
                         (T "Détection automatique (par défaut) : format déduit de la référence, puis vérifié sur deux pistes de la`r`ndisquette avant la lecture complète.`r`n`r`n") +
                         (T "Limite : seules les pistes décodables dans ce format sont comparées. Les pistes de protection`r`n") +
                         (T "(non-AmigaDOS) d'un IPF n'apparaissent pas dans la comparaison. Le flux brut (SCP) n'est jamais`r`n") +
                         (T "identique d'une lecture à l'autre : il n'existe pas de comparaison bit à bit au niveau flux.")

    $numSeek.Value = 0
    $txtEraseTracks.Text = ''
    $script:CleanPrefs = @{ Wet = $true; Cyls = 80; Preset = 0 }      # fenetre de nettoyage : humide, 80 pistes, Standard
    $numPin.Value = 2
    $cmbPinLvl.SelectedIndex = 0

    foreach ($k in $script:DelayCtrls.Keys) {
        $c = $script:DelayCtrls[$k]
        $c.Chk.Checked = $false
        $c.Num.Value = $c.Def
    }

    # 12.8 (D10, D13) : restauration a un seul lecteur (celui du bandeau) ; format (restore.formatChoice) dans la table
    $txtRsDir.Text = ''; $txtRsName.Text = ''
    Update-RsRules; Reset-RsSteps; Update-RsFmtFound
    $cmbHelpAct.SelectedItem = 'write'
    $txtC.Text = 'write --pre-erase --erase-empty --retries=10 --precomp 40=140 "jeu.ipf"'
    Update-CurveButton $txtWFile.Text
}

function Backup-ConfigBeforeRef([string[]]$keys, [string]$why = 'replace') {
    # 12.8 (lot 1c, point 4) : copie octet pour octet du fichier de configuration sur disque (dernier etat enregistre, qui
    # contient encore la reference en place), juste avant qu une reference existante soit remplacee ($why 'replace' :
    # Complete-PrecompCalib, toute calibration complete) ou effacee ('reset' : Reset-CalibProfiles). Rien si aucune des
    # cles n a de courbe (courbe d un autre calcul en attente du choix comprise) ou sans fichier. Nom :
    # <fichier>.ref-<familles>-<AAAAMMJJ-HHMM>.bak, a cote du fichier, date de la plus recente des references remplacees
    # (meme nom : meme reference, copie remplacee par l etat plus recent) ; date de modification de la copie mise a l heure
    # de la copie (rotation : copies les plus recentes, meme apres le retablissement manuel d une ancienne copie).
    # Rotation : ConfigRefBackupKeep copies gardees, les plus anciennes <fichier>.ref-*.bak supprimees (copies de
    # l application seulement), une ligne de journal par fichier. Echec de la copie : une ligne de journal, l operation
    # continue, sans rotation. Retablir une copie reste manuel (application fermee). Renvoie le chemin de la copie ou $null
    $oc = $script:OldCalib
    $cvs = @{}
    foreach ($k in @($keys | Where-Object { $_ } | Sort-Object -Unique)) {
        $cv = $script:PrecompCurves[$k]
        if (-not $cv -and $oc -and $oc.Curves -and $oc.Curves.Contains($k)) { $cv = $oc.Curves[$k] }
        if ($cv) { $cvs[$k] = $cv }
    }
    if ($cvs.Count -eq 0) { return $null }
    $cfg = [string]$script:ConfigFile
    if (-not $cfg -or -not (Test-Path -LiteralPath $cfg -PathType Leaf)) { return $null }
    $newest = @($cvs.Keys | Sort-Object { Get-CurveDate $cvs[$_] } -Descending)[0]
    $dt = Get-CurveDate $cvs[$newest]
    $stamp = if ($dt -ne [datetime]::MinValue) { $dt.ToString('yyyyMMdd-HHmm', [System.Globalization.CultureInfo]::InvariantCulture) } else { 'sans-date' }
    $fams = @($cvs.Keys | ForEach-Object { if ($_ -like 'hd*') { 'hd' } elseif ($_ -like 'long*') { 'long' } else { 'std' } } | Sort-Object -Unique)
    $leaf = [System.IO.Path]::GetFileName($cfg); $dir = Split-Path -Parent $cfg
    $bak = Join-Path $dir ($leaf + '.ref-' + ($fams -join '+') + '-' + $stamp + '.bak')
    $famTxt = (@($fams | ForEach-Object { Get-CalibFamilyName $_ })) -join ', '
    $dateTxt = [string]$cvs[$newest].Date
    try {
        # File.Copy : copie du fichier seul (jamais dans un dossier de ce nom), remplace une copie de meme nom
        [System.IO.File]::Copy($cfg, $bak, $true)
        [System.IO.File]::SetLastWriteTime($bak, (Get-Date))
    } catch {
        $msg = ([string]$(if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message })).Trim().TrimEnd('.')
        if ($why -eq 'reset') { Append-Log ((T "Configuration non sauvegardée avant l'effacement des calibrations ({0}) : {1}. L'effacement continue sans copie.") -f "$famTxt", "$msg") }
        else { Append-Log ((T "Configuration non sauvegardée avant le remplacement de la référence {0} : {1}. La calibration continue sans copie.") -f "$famTxt", "$msg") }
        return $null
    }
    if ($why -eq 'reset') { Append-Log ((T "Configuration sauvegardée avant l'effacement des calibrations (référence {0} du {1}) : {2}") -f "$famTxt", "$dateTxt", "$bak") }
    else { Append-Log ((T "Configuration sauvegardée avant le remplacement de la référence {0} du {1} : {2}") -f "$famTxt", "$dateTxt", "$bak") }
    $keep = [math]::Max(1, [int]$script:ConfigRefBackupKeep)
    try {
        $bakName = [System.IO.Path]::GetFileName($bak)
        $all = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction Stop | Where-Object { $_.Name -like ($leaf + '.ref-*.bak') -and $_.Name -ne $bakName } | Sort-Object LastWriteTime -Descending)
        foreach ($f in @($all | Select-Object -Skip ($keep - 1))) {
            try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; Append-Log ((T "Ancienne sauvegarde de configuration supprimée ({1} gardées) : {0}") -f "$($f.FullName)", "$keep") } catch { }
        }
    } catch { }
    return $bak
}

function Save-Config {
    $delays = @{}
    foreach ($k in $script:DelayCtrls.Keys) {
        $c = $script:DelayCtrls[$k]
        $delays[$k] = @{ on = [bool]$c.Chk.Checked; val = [int]$c.Num.Value }
    }
    $curvesCfg = [ordered]@{}
    $oc = $script:OldCalib          # calibrations d un autre calcul en attente du choix : gardees telles quelles
    foreach ($k in $script:CurveKeys) {
        $cv = $script:PrecompCurves[$k]
        if (-not $cv -and $oc -and $oc.Curves.Contains($k)) { $cv = $oc.Curves[$k] }
        if (-not $cv -and $k -like 'hd*') { continue }   # 12.7 : cles haute densite ecrites seulement avec une courbe (configuration DD inchangee)
        $curvesCfg[$k] = ConvertTo-CurveConfig $cv
    }
    $lvCfg = @(@($script:LevelShifts.Values) | Where-Object { $_ } | ForEach-Object { ConvertTo-LevelConfig $_ })
    if ($oc) { $lvCfg += @(@($oc.Levels.Values) | Where-Object { $_ -and -not $script:PrecompCurves[$_.RefKey] } | ForEach-Object { ConvertTo-LevelConfig $_ }) }
    # 12.8 (lot 1c, § 10.2) : memoire par marque de disquette (une 12.7 l ignore)
    $brCfg = @(@($script:LevelBrands) | Where-Object { $_ } | ForEach-Object { ConvertTo-LevelBrandConfig $_ })
    $cfg = [ordered]@{
        _comment = (T 'Configuration GreaseweazleGUI - régénérée automatiquement. Supprimable sans risque.')
        _saved   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        window   = @{
            width  = $(if ($form.WindowState -eq 'Normal') { $form.Width }  else { $form.RestoreBounds.Width })
            height = $(if ($form.WindowState -eq 'Normal') { $form.Height } else { $form.RestoreBounds.Height })
            split = $split.SplitterDistance; maximized = ($form.WindowState -eq 'Maximized')
            logVisible = -not $split.Panel2Collapsed
        }
        global   = @{ device = $txtDev.Text; time = [bool]$chkTime.Checked; detectNone = [bool]$script:DetectNone }
        library  = @{ root = $txtLibRoot.Text; imagesOnly = [bool]$chkLibImgOnly.Checked }
        write    = @{
            file = $txtWFile.Text; format = $cmbWFmt.Text
            preErase = [bool]$chkWPreErase.Checked; eraseEmpty = [bool]$chkWEraseEmpty.Checked
            noVerify = [bool]$chkWNoVerify.Checked; reverse = [bool]$chkWReverse.Checked
            hardSectors = [bool]$chkWHard.Checked; genTg43 = [bool]$chkWTG43.Checked
            retries = [int]$numWRetries.Value
            precompOn = [bool]$chkWPrecomp.Checked; precomp = $txtWPrecomp.Text; precomp1 = $txtWPrecomp1.Text
            postCheck = [bool]$chkWPostCheck.Checked; repairMax = [int]$numWRepair.Value
            precompStd = $(if ($oc -and $oc.Std -and -not $script:PrecompCurves['std']) { $oc.Std } else { $script:PrecompStd })
            precompLong = $(if ($oc -and $oc.Long -and -not $script:PrecompCurves['long']) { $oc.Long } else { $script:PrecompLong })
            precompMaxNs = [int]$script:CalHardNsUser   # borne des valeurs calibrees (300 a 470 ns, 400 par defaut ; 12.7 : celle de la double densite, la haute densite en prend la moitie)
            calibVersion = $script:Version     # version de l application qui a enregistre (information)
            calibCalc = $script:CalibCalc      # calcul de calibration courant ; chaque courbe porte le sien (calc)
            calibAlgo = $script:CalibAlgo
            precompCurves = $curvesCfg
            levelAlgo = $script:LevelFormat; levelShifts = $lvCfg   # 12.8 (G2) : format 'lvl1', relu par une 12.7
            levelBrand = [string]$script:LevelBrand; levelBrands = $brCfg
            tracks = $txtWTracks.Text; densel = $cmbWDensel.Text
            fakeIndex = $txtWFakeIdx.Text; diskdefs = $txtWDiskdefs.Text
        }
        read     = @{
            file = $txtRFile.Text; format = $cmbRFmt.Text
            revs = [int]$numRevs.Value; retries = [int]$numRRetries.Value
            tracks = $txtRTracks.Text; raw = [bool]$chkRRaw.Checked; reverse = [bool]$chkRRev.Checked
            densel = $cmbRDensel.Text; diskdefs = $txtRDiskdefs.Text
        }
        convert  = @{ input = $txtCvIn.Text; output = $txtCvOut.Text; format = $cmbCvFmt.Text; tracks = $txtCvTracks.Text }
        # 12.8 (D13) : compare.format (12.7) n est plus ecrit ; le format est compare.formatChoice (Export-Settings)
        compare  = @{ reference = $txtCmpRef.Text; retries = [int]$numCmpRetries.Value }
        align    = @{ head = $cmbAlHead.Text; cyls = $txtAlCyls.Text; revs = [int]$numAlRevs.Value; loop = [bool]$chkAlLoop.Checked; pause = [int]$numAlPause.Value
                      guide = [bool]$chkAlGuide.Checked
                      reference = $(if ($script:AlignRef) { $r = @{}; foreach ($k in $script:AlignRef.Keys) { $r[$k] = [double]$script:AlignRef[$k].Score }; $r } else { $null })
                      referenceLabel = $script:AlignRefLabel }
        tools    = @{
            seek = [int]$numSeek.Value; eraseTracks = $txtEraseTracks.Text
            cleanWet = [bool]$script:CleanPrefs.Wet; cleanCyls = [int]$script:CleanPrefs.Cyls; cleanPreset = [int]$script:CleanPrefs.Preset
            pin = [int]$numPin.Value; pinLevel = $cmbPinLvl.Text
        }
        delays   = $delays
        free     = @{ command = $txtC.Text; helpAction = $cmbHelpAct.Text }
        ui       = @{ expert = [bool]$chkExpert.Checked; homeCalFormat = [string]$script:HomeCalFmt }   # type de la carte Calibration
        # 12.8 (D10, D13) : restore.source, restore.target et restore.format (12.7) ne sont plus ecrits : ils disparaissent
        # au premier enregistrement ; le format est restore.formatChoice, reglage de la table (Export-Settings)
        restore  = @{ folder = $txtRsDir.Text }
    }
    # 12.8 (point 7) : reglages de la table (global.drive ; write.calMode, slowWrite, slowWarmup, calibWarmup,
    # calWarmupMinutes, levelBeforeWrite, precompProfileCode et precompProfile, precompThresholdNs ; ui.homeCalHeads et
    # homeCalCyls ; align.presetCode et preset ; quality ; tools.passes et linger ; restore.formatChoice ;
    # compare.formatChoice), puis, pendant
    # une operation surchargee (D4 : ecriture depuis la Bibliotheque ; lot 2 : restauration), reglages de l onglet
    # Ecriture d avant l operation
    Export-Settings $cfg
    if ($script:OpOverride) { Set-OpOverrideConfig $cfg }
    try {
        $cfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:ConfigFile -Encoding UTF8
        return $true
    } catch {
        Append-Log ((T "ERREUR sauvegarde configuration : {0}") -f "$($_.Exception.Message)")
        return $false
    }
}

function Get-Cfg($obj, [string]$name, $default) {
    if ($null -ne $obj -and ($obj.PSObject.Properties.Name -contains $name) -and $null -ne $obj.$name) { return $obj.$name }
    return $default
}

function Set-Num($ctrl, $value) {
    try {
        $v = [decimal]$value
        if ($v -lt $ctrl.Minimum) { $v = $ctrl.Minimum }
        if ($v -gt $ctrl.Maximum) { $v = $ctrl.Maximum }
        $ctrl.Value = $v
    } catch { }
}

function Set-Combo($ctrl, $value) {
    if ([string]::IsNullOrEmpty($value)) { return }
    if ($ctrl.Items.Contains($value)) { $ctrl.SelectedItem = $value }
    elseif ($ctrl.DropDownStyle -ne 'DropDownList') { $ctrl.Text = $value }
}

function Load-Config {
    if (-not (Test-Path -LiteralPath $script:ConfigFile)) { return $false }
    try {
        $cfg = Get-Content -LiteralPath $script:ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Append-Log ((T "Configuration illisible, valeurs par défaut conservées : {0}") -f "$($_.Exception.Message)")
        return $false
    }

    $win = Get-Cfg $cfg 'window' $null
    if ($win) {
        $w = [int](Get-Cfg $win 'width' $form.Width); $h = [int](Get-Cfg $win 'height' $form.Height)
        # Largeur enregistree avec le minimum de 800 px des versions anterieures a la 12.6 : portee au minimum actuel, la
        # hauteur enregistree est conservee
        if ($w -ge 800 -and $w -lt $form.MinimumSize.Width) { $w = $form.MinimumSize.Width }
        if ($w -ge $form.MinimumSize.Width -and $h -ge $form.MinimumSize.Height) { $form.Size = New-Object System.Drawing.Size($w, $h) }
        $script:PendingSplit = [int](Get-Cfg $win 'split' 0)
        if ([bool](Get-Cfg $win 'maximized' $false)) { $form.WindowState = 'Maximized' }
        $script:PendingLogVisible = [bool](Get-Cfg $win 'logVisible' $true)
    }

    $g = Get-Cfg $cfg 'global' $null
    $txtDev.Text = [string](Get-Cfg $g 'device' '')
    $chkTime.Checked = [bool](Get-Cfg $g 'time' $false)
    $script:DetectNone = [bool](Get-Cfg $g 'detectNone' $false)

    $l = Get-Cfg $cfg 'library' $null
    $txtLibRoot.Text = [string](Get-Cfg $l 'root' '')
    $chkLibImgOnly.Checked = [bool](Get-Cfg $l 'imagesOnly' $false)

    $w = Get-Cfg $cfg 'write' $null
    $txtWFile.Text = [string](Get-Cfg $w 'file' '')
    Set-Combo $cmbWFmt (Get-Cfg $w 'format' '(auto)')
    $chkWPreErase.Checked   = [bool](Get-Cfg $w 'preErase' $true)
    $chkWEraseEmpty.Checked = [bool](Get-Cfg $w 'eraseEmpty' $true)
    $chkWNoVerify.Checked   = [bool](Get-Cfg $w 'noVerify' $false)
    $chkWReverse.Checked    = [bool](Get-Cfg $w 'reverse' $false)
    $chkWHard.Checked       = [bool](Get-Cfg $w 'hardSectors' $false)
    $chkWTG43.Checked       = [bool](Get-Cfg $w 'genTg43' $false)
    Set-Num $numWRetries (Get-Cfg $w 'retries' 10)
    $chkWPrecomp.Checked    = [bool](Get-Cfg $w 'precompOn' $true)
    # Calibrations : courbe reprise si elle a ete faite avec le calcul de calibration actuel ($script:CalibCalc), quelle que
    # soit la version de l application qui l a faite, ou si l utilisateur l a conservee pour ce calcul (KeptFor). Courbe
    # d un autre calcul : mise de cote ($script:OldCalib) avec son profil de famille et ses niveaux ; au demarrage,
    # l utilisateur choisit de la conserver ou de recalibrer (Resolve-OldCalibrations) ; d ici la, elle n est pas utilisee.
    $calVer = [string](Get-Cfg $w 'calibVersion' '')
    $pcv = Get-Cfg $w 'precompCurves' $null
    $cfgStd = [string](Get-Cfg $w 'precompStd' $script:PrecompStdDefault)
    $cfgLong = [string](Get-Cfg $w 'precompLong' $script:PrecompLongDefault)
    # Premiere 12.3 publiee : elle a abandonne les courbes 12.2 et reecrit la configuration sans elles (sans calibCalc),
    # apres en avoir fait la copie .calib-v12.2.bak : ces courbes y sont relues pour etre proposees au choix
    $fromBak = $null
    $hasCurve = ($pcv -and @($script:CurveKeys | Where-Object { Get-Cfg $pcv $_ $null }).Count -gt 0)
    $bak122 = $script:ConfigFile + '.calib-v12.2.bak'
    if (-not $hasCurve -and $calVer -eq '12.3' -and $null -eq (Get-Cfg $w 'calibCalc' $null) -and (Test-Path -LiteralPath $bak122)) {
        try {
            $bw = Get-Cfg (Get-Content -LiteralPath $bak122 -Raw -Encoding UTF8 | ConvertFrom-Json) 'write' $null
            $bpcv = Get-Cfg $bw 'precompCurves' $null
            if ($bpcv -and @($script:CurveKeys | Where-Object { Get-Cfg $bpcv $_ $null }).Count -gt 0) {
                $pcv = $bpcv; $fromBak = $bak122
                $cfgStd = [string](Get-Cfg $bw 'precompStd' $script:PrecompStdDefault); $cfgLong = [string](Get-Cfg $bw 'precompLong' $script:PrecompLongDefault)
            }
        } catch { }
    }
    $old = [ordered]@{}
    foreach ($fam in $script:CurveKeys) {
        $cv = if ($pcv) { ConvertFrom-CurveConfig (Get-Cfg $pcv $fam $null) } else { $null }
        if ($cv -and -not (Test-CurveCalcOk $cv)) { $old[$fam] = $cv; $cv = $null }
        $script:PrecompCurves[$fam] = $cv
    }
    # Profil de famille : celui de la configuration s il accompagne une courbe reprise ; mis de cote avec sa courbe ;
    # profil calibre sans courbe (anterieur a 12.1) : abandonne
    $oldStd = $null; $oldLong = $null; $lostProf = $false
    if ($script:PrecompCurves['std']) { $script:PrecompStd = $cfgStd }
    else { $script:PrecompStd = $script:PrecompStdDefault; if ($old.Contains('std')) { $oldStd = $cfgStd } elseif ($cfgStd -ne $script:PrecompStdDefault) { $lostProf = $true } }
    if ($script:PrecompCurves['long']) { $script:PrecompLong = $cfgLong }
    else { $script:PrecompLong = $script:PrecompLongDefault; if ($old.Contains('long')) { $oldLong = $cfgLong } elseif ($cfgLong -ne $script:PrecompLongDefault) { $lostProf = $true } }
    # Niveaux de la calibration rapide : gardes avec leur reference (meme courbe, meme lecteur, meme algorithme de niveau) ;
    # ceux d une reference mise de cote le sont avec elle
    # 12.8 (lot 1c, § 12.1) : format 'lvl1' (12.7 et 12.8) ou 'lvl2' ; enregistrement 'lvl1' (relu avec s = b = 0) ou
    # 'lvl2' (forme adaptee)
    $script:LevelShifts = @{}; $oldLv = @{}
    if (@('lvl1', 'lvl2') -contains [string](Get-Cfg $w 'levelAlgo' '')) {
        foreach ($o in @(Get-Cfg $w 'levelShifts' @())) {
            $lr = ConvertFrom-LevelConfig $o
            if (-not $lr -or @('lvl1', 'lvl2') -notcontains [string]$lr.LevelAlgo) { continue }
            $rc = $script:PrecompCurves[$lr.RefKey]; $tgt = $script:LevelShifts
            if (-not $rc -and $old.Contains($lr.RefKey)) { $rc = $old[$lr.RefKey]; $tgt = $oldLv }
            if (-not $rc -or [string]$rc.Date -ne [string]$lr.RefDate -or [string]$rc.Drive -ne [string]$lr.Drive) { continue }
            $tgt["$($lr.RefKey)|$($lr.Tag)"] = $lr
        }
    }
    # 12.8 (lot 1c, § 10.2) : memoire par marque ; entrees gardees quelle que soit leur reference (une entree d une autre
    # reference n est plus un point de depart, Test-LevelBrandValid) ; entree illisible : ignoree, une ligne de journal
    $script:LevelBrand = [string](Get-Cfg $w 'levelBrand' '')
    $script:LevelBrands = @(); $brBad = 0
    foreach ($o in @(Get-Cfg $w 'levelBrands' @())) { $en = ConvertFrom-LevelBrandConfig $o; if ($en) { $script:LevelBrands += ,$en } else { $brBad++ } }
    if ($brBad -gt 0) { Append-Log ((T 'Mémoire par marque de disquette : {0} entrée(s) illisible(s) ignorée(s).') -f "$brBad") }
    $script:OldCalib = $null
    $calPurged = $lostProf
    if ($old.Count -gt 0) {
        $calPurged = $true
        $tags = @(@($old.Values) | ForEach-Object { Get-CurveCalc $_ } | Sort-Object -Unique)
        $tag = if ($tags.Count -eq 1 -and $tags[0]) { "v$($tags[0])" } elseif ($calVer) { "v$calVer" } else { 'ancienne' }
        # Copie de la configuration avant tout enregistrement, quel que soit le choix : une fois par passage d un calcul au
        # calcul actuel ; courbes relues dans la copie de la 12.3 publiee : cette copie
        if ($fromBak) { $bak = $fromBak; Append-Log ((T "Courbes de la version 12.2 relues dans la copie faite par la première version 12.3 : {0}") -f "$fromBak") }
        else {
            $bak = $script:ConfigFile + '.calib-' + $tag + '-avant-v' + $script:CalibCalc + '.bak'
            if (-not (Test-Path -LiteralPath $bak)) { try { Copy-Item -LiteralPath $script:ConfigFile -Destination $bak -ErrorAction Stop; Append-Log ((T "Configuration sauvegardée avant le choix sur les anciennes calibrations : {0}") -f "$bak") } catch { $bak = $null } }
        }
        $script:OldCalib = @{ Curves = $old; Std = $oldStd; Long = $oldLong; Levels = $oldLv; Bak = $bak; P0 = $null; P1 = $null }
        Append-Log ((T "Calibrations faites avec un autre calcul de calibration que le calcul actuel (v{0}) : {1}. Elles sont mises de côté jusqu'à votre choix.") -f "$($script:CalibCalc)", ((@($old.Keys | ForEach-Object { (T "{0}, calcul {1}") -f (Get-CurveKeyLabel $_), (Get-CurveCalcText $old[$_] -Plain) })) -join ' ; '))
    }
    if ($lostProf) { Append-Log (T 'Profil de famille calibré sans courbe (version antérieure à 12.1) : profil d''origine rétabli.') }
    # Borne des valeurs calibrees : reglage de la configuration, ramene a 300..470 ns ; valeur illisible : defaut, signale
    $hraw = Get-Cfg $w 'precompMaxNs' $null
    $hn = $script:CalHardNsDefault; $hd = 0.0
    if ($null -ne $hraw) {
        if ($hraw -isnot [bool] -and $hraw -isnot [array] -and [double]::TryParse(([string]$hraw).Trim(), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$hd) -and -not [double]::IsNaN($hd) -and -not [double]::IsInfinity($hd)) {
            $hn = [int][math]::Round([math]::Max(-1e9, [math]::Min(1e9, $hd)))
        } else { Append-Log ((T "Borne de précompensation (precompMaxNs) illisible ({0}) : {1} ns par défaut.") -f "$hraw", "$($script:CalHardNsDefault)") }
    }
    $script:CalHardNs = [int][math]::Max($script:CalHardMinNs, [math]::Min($script:CalHardMaxNs, $hn))
    if ($script:CalHardNs -ne $hn) { Append-Log ((T "Borne de précompensation (precompMaxNs) de {0} ns ramenée à {1} ns : elle va de {2} à {3} ns. Au-delà de 470 ns, la précompensation déplacerait une transition d'un quart de cellule en long track (1,89 µs).") -f "$hraw", "$($script:CalHardNs)", "$($script:CalHardMinNs)", "$($script:CalHardMaxNs)") }
    elseif ($script:CalHardNs -ne $script:CalHardNsDefault) { Append-Log ((T "Borne de précompensation réglée dans la configuration (precompMaxNs) : {0} ns, au lieu de {1} ns par défaut.") -f "$($script:CalHardNs)", "$($script:CalHardNsDefault)") }
    $script:CalHardNsUser = $script:CalHardNs; Set-CalibScale ''   # 12.7 : borne configuree, bareme double densite
    # 12.8 (point 7) : reglages de la table, sauf ceux de l ecriture lente lus plus bas, a la place qu ils avaient en 12.7
    # (apres les champs --precomp) : lecteur, mode de calibration, duree du prechauffage (lignes de journal d une valeur
    # illisible ou ramenee a 0..30 min), profil precomp (code, sinon ancien texte francais ou anglais), seuil de famille,
    # carte « Calibrer le lecteur », mesure de l onglet Qualite, seuils de jitter, nettoyage de l onglet Outils
    $lateKeys = @('slowWrite', 'warmSlowWrite', 'warmFullCalib', 'levelBeforeWrite')
    Import-Settings $cfg -Except $lateKeys
    Update-LegacyCleanDefault $cfg             # 12.8 (D9) : ancien defaut du nettoyage de l onglet Outils
    $chkWPostCheck.Checked = [bool](Get-Cfg $w 'postCheck' $true)
    $rm = [int](Get-Cfg $w 'repairMax' 3); $numWRepair.Value = [math]::Max(0, [math]::Min(10, $rm))
    $numWRepair.Enabled = $chkWPostCheck.Checked; $lblWRepair.Enabled = $chkWPostCheck.Checked
    $txtWPrecomp.Text  = [string](Get-Cfg $w 'precomp' $script:PrecompStd)
    $txtWPrecomp1.Text = [string](Get-Cfg $w 'precomp1' $txtWPrecomp.Text)
    if ($script:OldCalib) { $script:OldCalib.P0 = $txtWPrecomp.Text; $script:OldCalib.P1 = $txtWPrecomp1.Text }   # retablis si conservees
    # Champs --precomp remplis par une ancienne calibration : profil d origine (sauf profil manuel, choisi par l utilisateur)
    if ($calPurged -and (Get-Setting 'precompProfile') -ne 'manual') { $txtWPrecomp.Text = $script:PrecompStd; $txtWPrecomp1.Text = $script:PrecompStd }
    Import-Settings $cfg -Only $lateKeys       # ecriture lente, prechauffages (D6), mesure de la disquette
    Update-SlowUi
    $txtWTracks.Text   = [string](Get-Cfg $w 'tracks' '')
    Set-Combo $cmbWDensel (Get-Cfg $w 'densel' '(non)')
    $txtWFakeIdx.Text  = [string](Get-Cfg $w 'fakeIndex' '')
    $txtWDiskdefs.Text = [string](Get-Cfg $w 'diskdefs' '')

    $r = Get-Cfg $cfg 'read' $null
    $txtRFile.Text = [string](Get-Cfg $r 'file' '')
    Set-Combo $cmbRFmt (Get-Cfg $r 'format' '(auto)')
    Set-Num $numRevs     (Get-Cfg $r 'revs' 5)
    Set-Num $numRRetries (Get-Cfg $r 'retries' 10)
    $txtRTracks.Text = [string](Get-Cfg $r 'tracks' '')
    $chkRRaw.Checked = [bool](Get-Cfg $r 'raw' $false)
    $chkRRev.Checked = [bool](Get-Cfg $r 'reverse' $false)
    Set-Combo $cmbRDensel (Get-Cfg $r 'densel' '(non)')
    $txtRDiskdefs.Text = [string](Get-Cfg $r 'diskdefs' '')

    $c = Get-Cfg $cfg 'convert' $null
    $txtCvIn.Text  = [string](Get-Cfg $c 'input' '')
    $txtCvOut.Text = [string](Get-Cfg $c 'output' '')
    Set-Combo $cmbCvFmt (Get-Cfg $c 'format' '(auto)')
    $txtCvTracks.Text = [string](Get-Cfg $c 'tracks' '')

    $al = Get-Cfg $cfg 'align' $null
    $ref = Get-Cfg $al 'reference' $null
    if ($ref) {
        $script:AlignRef = @{}
        foreach ($prop in $ref.PSObject.Properties) { $script:AlignRef[[string]$prop.Name] = @{ Score = [double]$prop.Value } }
        $script:AlignRefLabel = [string](Get-Cfg $al 'referenceLabel' '')
        $lblAlRef.Text = ((T "Référence : {0} ({1} piste(s))") -f "$($script:AlignRefLabel)", "$($script:AlignRef.Count)")
    }
    Set-Combo $cmbAlHead (Get-Cfg $al 'head' '0+1')
    $txtAlCyls.Text = [string](Get-Cfg $al 'cyls' '0,10,20,30,40,50,60,70')
    $chkAlGuide.Checked = [bool](Get-Cfg $al 'guide' $false)
    Set-Num $numAlRevs (Get-Cfg $al 'revs' 3)
    $chkAlLoop.Checked = [bool](Get-Cfg $al 'loop' $false)
    Set-Num $numAlPause (Get-Cfg $al 'pause' 2)

    $cm = Get-Cfg $cfg 'compare' $null
    $txtCmpRef.Text = [string](Get-Cfg $cm 'reference' '')
    # 12.8 (D13) : compare.format (12.7) non relu, son defaut amiga.amigados n etant pas un choix : compare.formatChoice,
    # lu par Import-Settings, auto par defaut
    Set-Num $numCmpRetries (Get-Cfg $cm 'retries' 10)

    $t = Get-Cfg $cfg 'tools' $null
    Set-Num $numSeek   (Get-Cfg $t 'seek' 0)
    $txtEraseTracks.Text = [string](Get-Cfg $t 'eraseTracks' '')
    # Fenetre de nettoyage : humide sauf false explicite, 40 pistes ou 80, prereglage de duree 0..2
    $cc = 0; [void][int]::TryParse([string](Get-Cfg $t 'cleanCyls' 80), [ref]$cc)
    $cp = 0; [void][int]::TryParse([string](Get-Cfg $t 'cleanPreset' 0), [ref]$cp)
    $script:CleanPrefs = @{ Wet = ([string](Get-Cfg $t 'cleanWet' $true) -ne 'False'); Cyls = $(if ($cc -eq 40) { 40 } else { 80 }); Preset = [math]::Max(0, [math]::Min(2, $cp)) }
    Set-Num $numPin    (Get-Cfg $t 'pin' 2)
    Set-Combo $cmbPinLvl (Get-Cfg $t 'pinLevel' 'H')

    $dl = Get-Cfg $cfg 'delays' $null
    foreach ($k in $script:DelayCtrls.Keys) {
        $ctl = $script:DelayCtrls[$k]
        $e = Get-Cfg $dl $k $null
        if ($null -ne $e) {
            Set-Num $ctl.Num (Get-Cfg $e 'val' $ctl.Def)
            $ctl.Chk.Checked = [bool](Get-Cfg $e 'on' $false)
        }
    }

    $f = Get-Cfg $cfg 'free' $null
    $txtC.Text = [string](Get-Cfg $f 'command' $txtC.Text)
    Set-Combo $cmbHelpAct (Get-Cfg $f 'helpAction' 'write')

    # Configuration d une version precedente (sans section ui) : tous les onglets, comme avant
    $ui = Get-Cfg $cfg 'ui' $null
    $chkExpert.Checked = [bool](Get-Cfg $ui 'expert' ($null -eq $ui))
    # Type de disquette de la carte Calibration de l Accueil : nom de la table (format gw 1.23 ou type d image app.*)
    $hcf = [string](Get-Cfg $ui 'homeCalFormat' '')
    if ($hcf -and ($script:HomeCalApp -contains $hcf -or $script:GwFormats.Contains($hcf))) { $script:HomeCalFmt = $hcf }
    # 12.8 (D10, D13) : restore.source et restore.target ignores (un seul lecteur) ; restore.format (12.7) non relu, son
    # defaut amiga.amigados n etant pas un choix : restore.formatChoice, lu par Import-Settings, auto par defaut
    $rs = Get-Cfg $cfg 'restore' $null
    $txtRsDir.Text = [string](Get-Cfg $rs 'folder' '')

    return $true
}
