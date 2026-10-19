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

function Start-Compare {
    $ref = $txtCmpRef.Text
    if (-not $ref -or -not (Test-Path -LiteralPath $ref)) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Image de référence introuvable.'),(T 'Erreur'),'OK','Warning'); return
    }
    $fmt = $cmbCmpFmt.Text
    if (-not $fmt) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Choisissez un format de décodage.'),(T 'Erreur'),'OK','Warning'); return
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }

    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $ext   = Get-DecodedExt $fmt
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:CmpRefDecoded = Join-Path $script:TempDir "cmp-$stamp-reference$ext"
    $script:CmpDiskRead   = Join-Path $script:TempDir "cmp-$stamp-disquette$ext"
    $script:CmpFmt        = $fmt
    $script:CmpRefName    = [System.IO.Path]::GetFileName($ref)
    $retries = [int]$numCmpRetries.Value

    $txtCmpResult.Text = ((T "Comparaison en cours...`r`nReference : {0}`r`nFormat    : {1}") -f "$ref", "$fmt")
    Append-Log ((T "=== Comparaison : {0} ({1}) ===") -f "$script:CmpRefName", "$fmt")

    $script:CmpRefPath = $ref
    $script:CmpRetries = $retries

    # Etapes = scriptblocks simples (pas de GetNewClosure : un closure tourne dans un
    # module dynamique qui ne voit ni les fonctions du script ni la portee $script:)
    $script:Chain.Clear()
    if ([System.IO.Path]::GetExtension($ref).ToLower() -eq $ext) {
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
    $script:Chain.Enqueue({
        Start-Gw (@('read') + (Get-CommonArgs) + @("--retries=$($script:CmpRetries)", "--format=$($script:CmpFmt)", "`"$($script:CmpDiskRead)`""))
    })
    $script:Chain.Enqueue({ Compare-Images })
    Invoke-NextChainStep
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

        $sectorSize = 512
        if ($script:FastCompare) {
            $diffSectors = [GwCompare]::DiffSectors($a, $b, $sectorSize)
            $diffBytes   = [GwCompare]::DiffBytes($a, $b)
        } else {
            $n = [Math]::Max($a.Length, $b.Length); $diffBytes = 0
            $set = New-Object System.Collections.Generic.HashSet[int]
            for ($i = 0; $i -lt $n; $i++) {
                if ($i -ge $a.Length -or $i -ge $b.Length -or $a[$i] -ne $b[$i]) { $diffBytes++; [void]$set.Add([int][Math]::Floor($i / $sectorSize)) }
            }
            $diffSectors = @($set | Sort-Object)
        }

        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add(((T "Référence : {0}") -f "$($script:CmpRefName)"))
        $lines.Add(((T "Format    : {0}") -f "$fmt"))
        $lines.Add(((T "Taille    : référence {0} o / disquette {1} o") -f "$($a.Length)", "$($b.Length)"))
        $lines.Add(((T "SHA1 ref  : {0}") -f "$ha"))
        $lines.Add(((T "SHA1 disq : {0}") -f "$hb"))
        $lines.Add('')
        if ($ha -eq $hb) {
            $lines.Add((T 'RÉSULTAT : IDENTIQUE - la disquette correspond octet pour octet à la référence'))
            $lines.Add(((T "           sur l'ensemble des pistes décodables au format {0}.") -f "$fmt"))
            Append-Log ((T "Comparaison : IDENTIQUE ({0} octets)") -f "$($a.Length)")
        } else {
            $totalSectors = [Math]::Ceiling([Math]::Max($a.Length, $b.Length) / $sectorSize)
            $lines.Add(((T "RÉSULTAT : DIFFÉRENT - {0} octet(s) sur {1} secteur(s) / {2}") -f "$diffBytes", "$($diffSectors.Count)", "$totalSectors"))
            if ($a.Length -ne $b.Length) { $lines.Add((T '           (tailles différentes : vérifier le format de décodage)')) }
            $lines.Add('')
            $spt = Get-SectorsPerTrack $fmt
            $shown = 0
            $byTrack = [ordered]@{}
            foreach ($sIdx in $diffSectors) {
                if ($spt -gt 0) {
                    $trk = [int][Math]::Floor($sIdx / $spt); $sec = $sIdx % $spt
                    $key = ((T "Cyl {0} Head {1} (piste {2})") -f "$([int][Math]::Floor($trk / 2))", "$($trk % 2)", "$trk")
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
        Show-Tab $tabCmp
    } catch {
        $txtCmpResult.Text = ((T "ERREUR pendant la comparaison : {0}") -f "$($_.Exception.Message)")
        Append-Log ((T "Comparaison : erreur {0}") -f "$($_.Exception.Message)")
    } finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}
