# ============================== FONCTIONS : COMPARAISON ========================

function Get-DecodedExt([string]$fmt) {
    if ($fmt -like 'amiga.*') { return '.adf' }
    if ($fmt -like 'atarist.*') { return '.st' }
    return '.img'
}

function Get-SectorsPerTrack([string]$fmt) {
    switch ($fmt) {
        'amiga.amigados'    { return 11 }
        'amiga.amigados_hd' { return 22 }
        'ibm.720'           { return 9 }
        'ibm.1440'          { return 18 }
        'ibm.360'           { return 9 }
        'atarist.720'       { return 9 }
        'atarist.800'       { return 10 }
        'atarist.880'       { return 11 }
        default             { return 0 }
    }
}

function Get-BadSectorIndexes([byte[]]$b) {
    # Index des blocs de 512 octets remplis par gw du motif « -=[BAD SECTOR]=- » (secteur manquant a la lecture ou a la
    # conversion : codecs AmigaDOS et IBM de gw 1.23) ; tableau vide sinon
    $pat = [System.Text.Encoding]::ASCII.GetBytes('-=[BAD SECTOR]=-')
    $list = New-Object System.Collections.Generic.List[int]
    if ($null -eq $b) { return ,$list.ToArray() }
    for ($s = 0; $s + 512 -le $b.Length; $s += 512) {
        $same = $true
        for ($i = 0; $i -lt 512; $i++) { if ($b[$s + $i] -ne $pat[$i % 16]) { $same = $false; break } }
        if ($same) { $list.Add([int]($s / 512)) }
    }
    return ,$list.ToArray()
}

function Get-CmpFormatChoice {
    # 12.8 (D13) : choix de la liste du format de la comparaison, d apres le texte affiche (un texte pose par le code ne
    # remet pas SelectedIndex a -1) : 'auto' pour « (detection automatique) » (premier element, par defaut), sinon le
    # format choisi ou saisi (liste modifiable : tout format de gw, comme en 12.7)
    if ([string]$cmbCmpFmt.Text -eq $script:CmpAutoItem) { return 'auto' }
    return ([string]$cmbCmpFmt.Text).Trim()
}

function Update-CmpFmtFound {
    # 12.8 (D13) : reglage compareFormat (Update-SettingDependents) : liste resynchronisee quand elle n affiche pas le
    # reglage (format saisi hors de la liste, que la liaison ne sait pas choisir ; texte saisi remplace par Set-Defaults
    # ou Load-Config), sous la garde des liaisons ; une saisie en cours n est jamais touchee : seul un format valide met
    # le reglage a jour (gestionnaire TextChanged, 530). Ligne sous la liste : « Format detecte a la lecture » en
    # detection automatique, vide sinon ; le resultat de la detection y reste apres une comparaison, jusqu au prochain choix
    if (-not $lblCmpFmtFound) { return }
    $v = [string](Get-Setting 'compareFormat')
    if ((Get-CmpFormatChoice) -cne $v) {
        $i = [array]::IndexOf([string[]]$script:SettingDefs['compareFormat'].Codes, $v)
        $sv = $script:SettingSync; $script:SettingSync = $true
        try {
            $cmbCmpFmt.SelectedIndex = -1
            if ($i -ge 0 -and $i -lt $cmbCmpFmt.Items.Count) { $cmbCmpFmt.SelectedIndex = $i } else { $cmbCmpFmt.Text = $v }
        } finally { $script:SettingSync = $sv }
    }
    $t = $(if ((Get-CmpFormatChoice) -eq 'auto') { (T 'Format détecté à la lecture') } else { '' })
    $lblCmpFmtFound.Text = $t; $tip.SetToolTip($lblCmpFmtFound, $t)
}

function Start-Compare {
    # 12.7 : reference convertie dans le format choisi (copiee si elle est deja decodee), disquette lue dans ce format,
    # puis comparaison octet par octet (Compare-Images). 12.8 (lot 2, point 6 ; A1 § 4.2 ; D8, D13 ; decisions128) :
    #  - detection automatique (premier element de la liste, par defaut) : format de la reference sans disque
    #    (Get-RefImageFormat), ou par decodage de ses pistes 0.0 et 0.1 (IPF, SCP, HFE : Start-CompareRefDecode) ; puis
    #    sonde de deux pistes de la disquette dans ce format ; aucun secteur : format de la disquette detecte
    #    (Invoke-DiskFormatDetect) et resultat « formats differents » sans lecture complete ;
    #  - lectures de la disquette avec les options de lecteur de l onglet Ecriture (Get-DriveReadArgs), comme la
    #    restauration ;
    #  - reference secteur de plus de cylindres que le format (ADF de 81 a 83 cylindres) : gw ne lit que les cylindres de
    #    la definition du format (read.py v1.23 : « Out of range for format », piste non emise) ; FIX2 : plus de --tracks
    #    au-dela du format (sans effet, tete deplacee pour rien, sans borne), les cylindres suivants sont signales en
    #    reserve et non comptes comme differents.
    $ref = $txtCmpRef.Text
    if (-not $ref -or -not (Test-Path -LiteralPath $ref)) {
        [void](Show-AppMessage (T 'Image de référence introuvable.') (T 'Erreur') 'OK' 'Warning'); return
    }
    $choice = Get-CmpFormatChoice
    if (-not $choice) {
        [void](Show-AppMessage (T 'Choisissez un format de décodage.') (T 'Erreur') 'OK' 'Warning'); return
    }
    if (Get-AppBusy) { return }                           # 12.8 (D20) : test d occupation unique

    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $script:CmpStamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:CmpRefName = [System.IO.Path]::GetFileName($ref)
    $script:CmpRefPath = $ref
    $script:CmpRetries = [int]$numCmpRetries.Value
    $script:CmpAuto    = $null
    $script:Chain.Clear()
    if ($choice -ne 'auto') { Start-CompareWith $choice; return }

    $ri = Get-RefImageFormat $ref
    $script:CmpAuto = @{ Ref = $ri; RefWhy = $ri.Why; Disk = ''; Cands = @(); Results = @(); Idx = 0 }
    $txtCmpResult.Text = ((T "Comparaison en cours...`r`nReference : {0}`r`nFormat    : {1}") -f "$ref", (T 'détection automatique'))
    $lblCmpFmtFound.Text = (T 'Format détecté à la lecture')
    Append-Log ((T "=== Comparaison : {0} ({1}) ===") -f "$($script:CmpRefName)", (T 'détection automatique'))
    if ($ri.Need -eq 'decode') { $script:CmpAuto.Cands = @($ri.Cands); Start-CompareRefDecode; return }
    if (-not $ri.Format) { Stop-CompareAuto ((T "format de la référence non reconnu ({0}) : choisissez le format de décodage dans la liste.") -f $ri.Why); return }
    Append-Log ((T "Comparaison : format de la référence {0} ({1}).") -f $ri.Format, $ri.Why)
    Start-CompareWith $ri.Format
}

function Stop-CompareAuto([string]$why) {
    # Detection automatique sans format de reference : rien n est lu sur la disquette
    $script:Chain.Clear(); $script:GwCapture = $null; $script:CmpAuto = $null
    $txtCmpResult.Text = ((T "ÉCHEC : {0}") -f $why)
    $lblCmpFmtFound.Text = $why; $tip.SetToolTip($lblCmpFmtFound, $why)
    Append-Log ((T "Comparaison impossible : {0}") -f $why)
}

function Start-CompareRefDecode {
    # IPF, SCP, HFE en detection automatique : pistes 0.0 et 0.1 de la reference decodees par gw avec chaque candidat de
    # Get-RefImageFormat, jusqu au premier dont les deux pistes sont completes ; puis Select-RefDecodeFormat
    $a = $script:CmpAuto
    if (-not $a) { return }
    if ($a.Idx -ge @($a.Cands).Count) { Complete-CompareRefDecode; return }
    $f = [string]@($a.Cands)[$a.Idx]
    $out = Join-Path $script:TempDir ("cmp-$($script:CmpStamp)-reference-sonde$($a.Idx)" + (Get-DecodedExt $f))
    $script:CmpGwArgs = @('convert', "--format=$f", '--tracks=c=0:h=0-1', "`"$($script:CmpRefPath)`"", "`"$out`"")
    $script:GwCapture = New-Object System.Collections.Generic.List[string]
    $script:Chain.Enqueue({ Start-Gw $script:CmpGwArgs })
    $script:Chain.Enqueue({ Step-CompareRefDecode })
    Invoke-NextChainStep
}

function Step-CompareRefDecode {
    $a = $script:CmpAuto
    if (-not $a) { return }
    $lines = @(if ($script:GwCapture) { @($script:GwCapture) } else { @() }); $script:GwCapture = $null
    $a.Results = @($a.Results) + ,@{ Fmt = [string]@($a.Cands)[$a.Idx]; Lines = $lines }
    $a.Idx++
    $sel = Select-RefDecodeFormat $a.Results
    if ($sel.Format -and @($sel.Inc).Count -eq 0) { $a.Idx = @($a.Cands).Count }   # deux pistes completes : la suite est inutile
    Start-CompareRefDecode
}

function Complete-CompareRefDecode {
    $a = $script:CmpAuto
    if (-not $a) { return }
    $sel = Select-RefDecodeFormat $a.Results
    if (-not $sel.Format) { Stop-CompareAuto ((T "format de la référence non reconnu ({0}) : choisissez le format de décodage dans la liste.") -f ($a.RefWhy + ' ; ' + $sel.Text)); return }
    $a.RefWhy = $a.RefWhy + ' : ' + $sel.Text
    Append-Log ((T "Comparaison : format de la référence {0} ({1}).") -f $sel.Format, $a.RefWhy)
    Start-CompareWith $sel.Format
}

function Get-CompareReadArgs([string]$out, [switch]$Probe) {
    # Lecture de la disquette (12.8, D8 : options de lecteur de l onglet Ecriture) : sonde des pistes 0.0 et 0.1 (2 tours,
    # sans nouvel essai), ou lecture complete (essais de l onglet ; cylindres du format, FIX2)
    $a = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs)
    if ($Probe) { $a += @("--format=$($script:CmpFmt)", '--tracks=c=0:h=0-1', '--revs=2', '--retries=0') }
    else { $a += @("--retries=$($script:CmpRetries)", "--format=$($script:CmpFmt)") }
    return @($a + @("`"$out`""))
}

function Start-CompareWith([string]$fmt) {
    # Comparaison dans le format $fmt (choisi, ou detecte pour la reference) : reference copiee ou convertie, puis
    # disquette lue (detection automatique : sonde de deux pistes d abord, Step-CompareProbe), puis Compare-Images
    $ref = $script:CmpRefPath
    $ext = Get-DecodedExt $fmt
    $st = $script:CmpStamp
    $script:CmpRefDecoded = Join-Path $script:TempDir "cmp-$st-reference$ext"
    $script:CmpDiskRead   = Join-Path $script:TempDir "cmp-$st-disquette$ext"
    $script:CmpProbe      = Join-Path $script:TempDir "cmp-$st-sonde$ext"
    $script:CmpFmt        = $fmt
    $script:CmpRefCyls    = 0
    $copy = ([System.IO.Path]::GetExtension($ref).ToLower() -eq $ext)
    $g = Get-FormatGeometry $fmt
    if ($copy) {
        # Reference deja decodee de plus de cylindres que le format (decisions128) : FIX2, gw ne lit que les cylindres du
        # format ; les suivants sont signales (Compare-Images), sans --tracks
        $ri = $(if ($script:CmpAuto) { $script:CmpAuto.Ref } else { Get-RefImageFormat $ref })
        if ($ri -and $ri.Format -eq $fmt -and $null -ne $ri.Cyls -and $g -and [int]$ri.Cyls -gt $g.Cyls) { $script:CmpRefCyls = [int]$ri.Cyls }
    }
    $shown = $(if ($script:CmpAuto) { (T "{0} (détecté : {1})") -f $fmt, $script:CmpAuto.RefWhy } else { $fmt })
    $txtCmpResult.Text = ((T "Comparaison en cours...`r`nReference : {0}`r`nFormat    : {1}") -f "$ref", "$shown")
    if (-not $script:CmpAuto) { Append-Log ((T "=== Comparaison : {0} ({1}) ===") -f "$($script:CmpRefName)", "$fmt") }
    if ($script:CmpRefCyls -gt 0) { Append-Log ((T "Comparaison : référence de {0} cylindres ; gw ne lit que les {1} cylindres du format {2} : les cylindres {1} à {3} ne seront pas comparés.") -f "$($script:CmpRefCyls)", "$($g.Cyls)", $fmt, "$($script:CmpRefCyls - 1)") }

    # Etapes = scriptblocks simples (pas de GetNewClosure : un closure tourne dans un
    # module dynamique qui ne voit ni les fonctions du script ni la portee $script:)
    $script:Chain.Clear()
    if ($copy) {
        $script:Chain.Enqueue({
            Copy-Item -LiteralPath $script:CmpRefPath -Destination $script:CmpRefDecoded -Force
            Append-Log (T 'Référence déjà au format décodé : copiée sans conversion.')
            Invoke-NextChainStep
        })
    } else {
        $script:Chain.Enqueue({
            Start-Gw @('convert', "--format=$($script:CmpFmt)", "`"$($script:CmpRefPath)`"", "`"$($script:CmpRefDecoded)`"")
        })
    }
    if ($script:CmpAuto) {
        $script:Chain.Enqueue({ $script:GwCapture = New-Object System.Collections.Generic.List[string]; Start-Gw (Get-CompareReadArgs $script:CmpProbe -Probe) })
        $script:Chain.Enqueue({ Step-CompareProbe })
    } else {
        $script:Chain.Enqueue({ Start-Gw (Get-CompareReadArgs $script:CmpDiskRead) })
        $script:Chain.Enqueue({ Compare-Images })
    }
    Invoke-NextChainStep
}

function Step-CompareProbe {
    # Detection automatique, apres la sonde : au moins un secteur au format de la reference -> lecture complete ; aucun ->
    # format de la disquette detecte, puis « formats differents » sans lecture complete (Complete-CompareDetect)
    $a = $script:CmpAuto
    if (-not $a) { return }
    $lines = @(if ($script:GwCapture) { @($script:GwCapture) } else { @() }); $script:GwCapture = $null
    $t = Get-GwTrackSectors $lines; $f = 0; $n = 0
    foreach ($k in @('0.0', '0.1')) { if ($t[$k]) { $f += [int]$t[$k].Found; $n += [int]$t[$k].Total } }
    if ($n -eq 0) { $g = Get-FormatGeometry $script:CmpFmt; if ($g) { $n = 2 * $g.Spt } }
    $a.Disk = (T "{0}/{1} secteurs sur les pistes 0.0 et 0.1") -f "$f", "$n"
    if ($f -gt 0) {
        Append-Log ((T "Comparaison : sonde de la disquette au format {0}, {1} : lecture complète.") -f $script:CmpFmt, $a.Disk)
        $script:Chain.Enqueue({ Start-Gw (Get-CompareReadArgs $script:CmpDiskRead) })
        $script:Chain.Enqueue({ Compare-Images })
        Invoke-NextChainStep
        return
    }
    Append-Log ((T "Comparaison : aucun secteur au format {0} sur les pistes 0.0 et 0.1 de la disquette : détection de son format, sans lecture complète.") -f $script:CmpFmt)
    Invoke-DiskFormatDetect 'compare' ''
}

function Complete-CompareDetect($res) {
    # Format de la disquette detecte apres une sonde sans secteur (Complete-DiskFormatDetect) : meme format que la
    # reference -> lecture complete quand meme (FIX2 : quelle que soit l action de la restauration, pistes protegees
    # comprises : Compare-Images les signale) ; sinon resultat « DIFFERENT : formats differents », sans lecture complete
    $a = $script:CmpAuto
    if (-not $a) { return }
    if ($res.Format -and $res.Format -eq $script:CmpFmt) {
        $a.Disk = $a.Disk + ' ; ' + ((T "format {0} détecté ensuite") -f $res.Format)
        Append-Log ((T "Comparaison : format {0} détecté sur la disquette, celui de la référence : lecture complète.") -f $res.Format)
        $script:Chain.Enqueue({ Start-Gw (Get-CompareReadArgs $script:CmpDiskRead) })
        $script:Chain.Enqueue({ Compare-Images })
        Invoke-NextChainStep
        return
    }
    $disk = $(if ($res.Kind -eq 'blank' -or $res.Kind -eq 'nofile') { (T 'aucune donnée lisible') } elseif ($res.Format) { $res.Format } else { (T 'format non reconnu') })
    # FIX2 : ligne « Disquette » propre a la comparaison (format reconnu ou non, scores des decodeurs), sans l action de la
    # restauration (« copie exacte du flux… »)
    $dn = $(if ($res.Kind -eq 'blank' -or $res.Kind -eq 'nofile') { (T 'aucune donnée lisible') } elseif ($res.Format -and $res.Name) { "$($res.Name) ($($res.Format))" } elseif ($res.Format) { $res.Format } else { (T 'format non reconnu') })
    if ($res.Kind -eq 'protect' -and $res.Format) { $dn += ' ; ' + (T 'piste 0.0 ou 0.1 incomplète') }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(((T "Référence : {0}") -f "$($script:CmpRefName)"))
    $lines.Add(((T "Format    : {0} (détecté : {1} ; disquette {2})") -f $script:CmpFmt, $a.RefWhy, $a.Disk))
    $lines.Add(((T "Disquette : {0} ; détection : {1}") -f $dn, "$($res.Score)"))
    $lines.Add('')
    $lines.Add(((T "RÉSULTAT : DIFFÉRENT - formats différents (référence {0}, disquette {1})") -f $script:CmpFmt, $disk))
    $lines.Add(((T "           aucun secteur au format {0} sur les pistes 0.0 et 0.1 de la disquette : pas de lecture complète.") -f $script:CmpFmt))
    $txtCmpResult.Text = ($lines -join "`r`n")
    $t = (T "Référence {0}, disquette {1}") -f $script:CmpFmt, $disk
    $lblCmpFmtFound.Text = $t; $tip.SetToolTip($lblCmpFmtFound, $t)
    Append-Log ((T "Comparaison : DIFFÉRENT - formats différents (référence {0}, disquette {1})") -f $script:CmpFmt, $disk)
    $script:CmpAuto = $null
    Show-Tab $tabCmp
}

function Compare-Images {
    $refPath = $script:CmpRefDecoded
    $dskPath = $script:CmpDiskRead
    $fmt     = $script:CmpFmt
    if (-not (Test-Path -LiteralPath $refPath) -or -not (Test-Path -LiteralPath $dskPath)) {
        $txtCmpResult.Text = ((T "ÉCHEC : un des deux fichiers décodés est absent.`r`n{0}`r`n{1}") -f "$refPath", "$dskPath")
        Append-Log (T 'Comparaison impossible : fichier décodé manquant.')
        return
    }
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try {
        $a = [System.IO.File]::ReadAllBytes($refPath)
        $b = [System.IO.File]::ReadAllBytes($dskPath)
        $sha = [System.Security.Cryptography.SHA1]::Create()
        $ha = [System.BitConverter]::ToString($sha.ComputeHash($a)).Replace('-','')
        $hb = [System.BitConverter]::ToString($sha.ComputeHash($b)).Replace('-','')

        # 12.8 (decisions128) : reference de plus de cylindres que le format, disquette relue sur autant de cylindres
        # (Start-CompareWith) : les cylindres que gw n a pas relus (disquette decodee plus courte d un nombre entier de
        # cylindres, au moins ceux du format) ne sont pas comptes comme differents ; ils sont signales
        $g = Get-FormatGeometry $fmt
        $skip = ''; $aCmp = $a
        if ($script:CmpRefCyls -gt 0 -and $g -and $b.Length -lt $a.Length) {
            $cb = $g.Heads * $g.Spt * 512
            if ($b.Length % $cb -eq 0 -and $b.Length / $cb -ge $g.Cyls) {
                $nb = [int]($b.Length / $cb)
                $skip = (T "cylindres {0} à {1} de la référence non relus : gw a lu la disquette sur {2} cylindres au format {3}") -f "$nb", "$($script:CmpRefCyls - 1)", "$nb", $fmt
                $aCmp = New-Object byte[] $b.Length; [Array]::Copy($a, $aCmp, $b.Length)
            }
        }

        $sectorSize = 512
        if ($script:FastCompare) {
            $diffSectors = [GwCompare]::DiffSectors($aCmp, $b, $sectorSize)
            $diffBytes   = [GwCompare]::DiffBytes($aCmp, $b)
        } else {
            $n = [Math]::Max($aCmp.Length, $b.Length); $diffBytes = 0
            $set = New-Object System.Collections.Generic.HashSet[int]
            for ($i = 0; $i -lt $n; $i++) {
                if ($i -ge $aCmp.Length -or $i -ge $b.Length -or $aCmp[$i] -ne $b[$i]) { $diffBytes++; [void]$set.Add([int][Math]::Floor($i / $sectorSize)) }
            }
            $diffSectors = @($set | Sort-Object)
        }
        $same = ($ha -eq $hb) -or ($skip -and @($diffSectors).Count -eq 0)

        # FIX2 : secteurs illisibles des deux cotes (motif « -=[BAD SECTOR]=- » de gw dans la reference convertie et dans
        # la lecture de la disquette : piste protegee, copie de flux ratee) : egaux octet pour octet, mais non compares ;
        # jamais « IDENTIQUE » sans reserve
        $badA = Get-BadSectorIndexes $aCmp
        $setB = New-Object 'System.Collections.Generic.HashSet[int]'
        foreach ($x in (Get-BadSectorIndexes $b)) { [void]$setB.Add([int]$x) }
        $both = @($badA | Where-Object { $setB.Contains([int]$_) })
        $bothTxt = ''
        if ($both.Count -gt 0) {
            $spt0 = Get-SectorsPerTrack $fmt; $hd0 = 2
            if ($g) { $spt0 = $g.Spt; $hd0 = $g.Heads }
            $tk = @{}
            if ($spt0 -gt 0) { foreach ($sIdx in $both) { $tr = [int][Math]::Floor([int]$sIdx / $spt0); $tk["$([int][Math]::Floor($tr / $hd0)).$($tr % $hd0)"] = $true } }
            $bothTxt = (T "{0} secteur(s) illisible(s) des deux côtés, non comparé(s) (pistes {1})") -f "$($both.Count)", "$(Format-TrackList (Sort-TrackKeys @($tk.Keys)))"
        }

        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add(((T "Référence : {0}") -f "$($script:CmpRefName)"))
        if ($script:CmpAuto) { $lines.Add(((T "Format    : {0} (détecté : {1} ; disquette {2})") -f $fmt, $script:CmpAuto.RefWhy, $script:CmpAuto.Disk)) }
        else { $lines.Add(((T "Format    : {0}") -f "$fmt")) }
        $lines.Add(((T "Taille    : référence {0} o / disquette {1} o") -f "$($a.Length)", "$($b.Length)"))
        $lines.Add(((T "SHA1 ref  : {0}") -f "$ha"))
        $lines.Add(((T "SHA1 disq : {0}") -f "$hb"))
        $lines.Add('')
        if ($same -and $bothTxt) {
            $lines.Add(((T "RÉSULTAT : IDENTIQUE SUR LES SECTEURS LUS - {0}") -f $bothTxt))
            $lines.Add((T '           Ces secteurs portent des deux côtés le motif « secteur illisible » de gw (piste protégée, ou copie'))
            $lines.Add(((T "           ratée) : ils ne sont pas vérifiés. Les autres secteurs correspondent octet pour octet au format {0}.") -f "$fmt"))
            if ($skip) { $lines.Add('           ' + ((T "Réserve : {0}.") -f $skip)) }
            Append-Log (((T "Comparaison : IDENTIQUE sur les secteurs lus ({0} octets) ; {1}") -f "$($aCmp.Length)", $bothTxt) + $(if ($skip) { ' ; ' + $skip } else { '' }))
        } elseif ($same) {
            $lines.Add((T 'RÉSULTAT : IDENTIQUE - la disquette correspond octet pour octet à la référence'))
            $lines.Add(((T "           sur l'ensemble des pistes décodables au format {0}.") -f "$fmt"))
            if ($skip) { $lines.Add('           ' + ((T "Réserve : {0}.") -f $skip)) }
            Append-Log (((T "Comparaison : IDENTIQUE ({0} octets)") -f "$($aCmp.Length)") + $(if ($skip) { ' ; ' + $skip } else { '' }))
        } else {
            $totalSectors = [Math]::Ceiling([Math]::Max($aCmp.Length, $b.Length) / $sectorSize)
            $lines.Add(((T "RÉSULTAT : DIFFÉRENT - {0} octet(s) sur {1} secteur(s) / {2}") -f "$diffBytes", "$($diffSectors.Count)", "$totalSectors"))
            if ($aCmp.Length -ne $b.Length) { $lines.Add((T '           (tailles différentes : vérifier le format de décodage)')) }
            if ($skip) { $lines.Add('           ' + ((T "Réserve : {0}.") -f $skip)) }
            if ($bothTxt) { $lines.Add('           ' + ((T "Réserve : {0}.") -f $bothTxt)) }
            $lines.Add('')
            # 12.8 : secteurs et faces de la geometrie du format (formats a une face, formats hors de la liste)
            $spt = Get-SectorsPerTrack $fmt; $hds = 2
            if ($g) { $spt = $g.Spt; $hds = $g.Heads }
            $shown = 0
            $byTrack = [ordered]@{}
            foreach ($sIdx in $diffSectors) {
                if ($spt -gt 0) {
                    $trk = [int][Math]::Floor($sIdx / $spt); $sec = $sIdx % $spt
                    $key = ((T "Cyl {0} Head {1} (piste {2})") -f "$([int][Math]::Floor($trk / $hds))", "$($trk % $hds)", "$trk")
                    if (-not $byTrack.Contains($key)) { $byTrack[$key] = New-Object System.Collections.Generic.List[int] }
                    $byTrack[$key].Add($sec)
                } else {
                    if ($shown -lt 40) { $lines.Add(((T "secteur logique {0} (offset 0x{1:X})") -f $sIdx, ($sIdx * $sectorSize))) }
                    $shown++
                }
            }
            if ($spt -gt 0) {
                $lines.Add(((T "Pistes en écart ({0}) :") -f "$($byTrack.Count)"))
                foreach ($k in $byTrack.Keys) {
                    if ($shown -ge 60) { $lines.Add('  ...'); break }
                    $secs = $byTrack[$k]
                    $lines.Add(((T "  {0,-28} secteurs : {1}") -f $k, (($secs | Sort-Object) -join ',')))
                    $shown++
                }
                if ($byTrack.Count -gt 0) {
                    $lines.Add('')
                    $lines.Add((T 'Une piste dont TOUS les secteurs diffèrent est probablement illisible'))
                    $lines.Add((T 'ou non-AmigaDOS (protection) ; quelques secteurs isolés = support marginal.'))
                }
            } elseif ($shown -gt 40) { $lines.Add(((T "  ... {0} autre(s)") -f "$($shown - 40)")) }
            Append-Log ((T "Comparaison : DIFFÉRENT - {0} octet(s), {1} secteur(s)") -f "$diffBytes", "$($diffSectors.Count)")
        }
        $lines.Add('')
        $lines.Add((T "Fichiers décodés conservés :"))
        $lines.Add("  $refPath")
        $lines.Add("  $dskPath")
        $txtCmpResult.Text = ($lines -join "`r`n")
        if ($script:CmpAuto) {
            $t = (T "{0} : {1} ; disquette {2}") -f $fmt, $script:CmpAuto.RefWhy, $script:CmpAuto.Disk
            $lblCmpFmtFound.Text = $t; $tip.SetToolTip($lblCmpFmtFound, $t)
        }
        Show-Tab $tabCmp
    } catch {
        $txtCmpResult.Text = ((T "ERREUR pendant la comparaison : {0}") -f "$($_.Exception.Message)")
        Append-Log ((T "Comparaison : erreur {0}") -f "$($_.Exception.Message)")
    } finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $script:CmpAuto = $null
    }
}
