# ============================== FONCTIONS : PROFIL PRECOMP =====================

# ============================== PROFIL PRECOMP : DETECTION =====================
function Get-BE32([byte[]]$b, [int]$o) {
    return ([int64]$b[$o] * 16777216) + ([int64]$b[$o+1] * 65536) + ([int64]$b[$o+2] * 256) + [int64]$b[$o+3]
}

# IPF : mediane des bits par piste (enregistrements IMGE) -> cellule nominale a 300 tr/min
function Get-IpfCellInfo([string]$path) {
    $d = [System.IO.File]::ReadAllBytes($path)
    if ([System.Text.Encoding]::ASCII.GetString($d, 0, 4) -ne 'CAPS') { throw (T 'Signature IPF absente') }
    $bits = New-Object System.Collections.Generic.List[int64]; $dos = 0; $n = 0
    $pos = 0
    while ($pos + 12 -le $d.Length) {
        $id = [System.Text.Encoding]::ASCII.GetString($d, $pos, 4)
        $ln = Get-BE32 $d ($pos + 4)
        if ($ln -lt 12) { break }
        if ($id -eq 'IMGE' -and $pos + 12 + 44 -le $d.Length) {
            $trkbits = Get-BE32 $d ($pos + 12 + 36)
            $blkcnt  = Get-BE32 $d ($pos + 12 + 40)
            if ($blkcnt -gt 0 -and $trkbits -gt 0) { $bits.Add($trkbits); $n++; if ($blkcnt -eq 11) { $dos++ } }
        } elseif ($id -eq 'DATA' -and $pos + 16 -le $d.Length) {
            $ln += Get-BE32 $d ($pos + 12)
        }
        $pos += $ln
    }
    if ($bits.Count -eq 0) { throw (T 'Aucune piste formatée dans l''IPF') }
    $sorted = $bits | Sort-Object
    $med = [int64]$sorted[[int]($sorted.Count / 2)]
    return @{ CellNs = [double](200000000.0 / $med); Bits = $med; Tracks = $n; DosTracks = $dos; Source = (T 'IPF (bits par piste)') }
}

# SCP : cellule mesuree sur les premieres pistes presentes (revolution 0)
function Get-ScpCellInfo([string]$path) {
    $d = [System.IO.File]::ReadAllBytes($path)
    if ([System.Text.Encoding]::ASCII.GetString($d, 0, 3) -ne 'SCP') { throw (T 'Signature SCP absente') }
    $res = ($d[11] + 1) * 25; $cells = @(); $t = 0
    while ($t -lt 168 -and $cells.Count -lt 4) {
        $o = [BitConverter]::ToUInt32($d, 16 + 4 * $t); $t++
        if ($o -eq 0) { continue }
        $ln = [BitConverter]::ToUInt32($d, $o + 8); $doff = [BitConverter]::ToUInt32($d, $o + 12)
        $flux = [ScpStats]::Decode($d, [int]($o + $doff), [int]$ln, $res)
        $st = [ScpStats]::Analyze($flux, 0)
        if (-not [double]::IsNaN($st.Cell)) { $cells += $st.Cell }
    }
    if ($cells.Count -eq 0) { throw (T 'Aucune piste analysable dans le SCP') }
    $avg = ($cells | Measure-Object -Average).Average
    return @{ CellNs = $avg; Bits = [int64](200000000.0 / $avg); Tracks = $cells.Count; DosTracks = -1; Source = (T 'SCP (flux mesuré)') }
}

# HFE : debit binaire declare dans l en-tete (kbit/s) -> cellule = 500 000 / debit
function Get-HfeCellInfo([string]$path) {
    # Densite d un HFE telle que gw l ecrit (hfe.py) : par face, 8 x (longueur // 2) bits, la longueur (octets, deux
    # faces) etant lue dans la table des pistes (bloc ToUInt16(18), une entree de 4 octets par cylindre : bloc des
    # donnees, longueur) ; gw cale chaque piste sur un tour du lecteur, d ou une cellule de 200 ms / bits a 300 tr/min
    # (mediane des pistes). Table retenue si elle suit l en-tete, est complete et designe pour au moins la moitie des
    # cylindres des donnees presentes dans le fichier. HFE v3 (opcodes dans le flux de bits) ou table inexploitable :
    # 400 x debit de l en-tete.
    $fs = [System.IO.File]::OpenRead($path)
    try {
        $h = New-Object byte[] 32; [void]$fs.Read($h, 0, 32)
        $sig = [System.Text.Encoding]::ASCII.GetString($h, 0, 8)
        if ($sig -notmatch '^HXCPICFE|^HXCHFEV3') { throw (T 'Signature HFE absente') }
        $rate = [BitConverter]::ToUInt16($h, 12)          # en-tete HFE : bitRate (kbit/s) a l offset 12
        if ($rate -le 0) { throw (T 'Débit HFE nul') }
        if ($rate -lt 100 -or $rate -gt 1000) { throw ((T "Débit HFE invalide ({0} kbit/s)") -f "$rate") }
        $bits = [int64](400 * [int]$rate); $src = ((T "HFE (débit {0} kbit/s)") -f "$rate")
        $nCyl = [int]$h[9]; $tlBase = [int][BitConverter]::ToUInt16($h, 18)
        if ($sig -eq 'HXCPICFE' -and $nCyl -gt 0 -and $tlBase -ge 1) {
            $tl = New-Object byte[] (4 * $nCyl)
            [void]$fs.Seek([int64]$tlBase * 512, [System.IO.SeekOrigin]::Begin)
            $got = $fs.Read($tl, 0, $tl.Length)
            if ($got -eq $tl.Length) {
                $flen = $fs.Length
                $lens = @(@(for ($i = 0; $i + 4 -le $got; $i += 4) {
                    $off = [int64][BitConverter]::ToUInt16($tl, $i); $l = [int][BitConverter]::ToUInt16($tl, $i + 2)
                    if ($l -ge 2 -and $off -gt $tlBase -and $off * 512 + $l -le $flen + 512) { 8 * [int64][math]::Floor($l / 2) }
                }) | Sort-Object)
                if ($lens.Count -gt 0 -and $lens.Count -ge [math]::Ceiling($nCyl / 2)) {
                    $med = [int64]$lens[[int][math]::Floor($lens.Count / 2)]
                    if ($med -ge 20000 -and $med -le 600000) { $bits = $med; $src = ((T "HFE ({0} bits par piste, débit {1} kbit/s)") -f "$med", "$rate") }
                }
            }
        }
    } finally { $fs.Dispose() }
    return @{ CellNs = [double](200000000.0 / $bits); Bits = $bits; Tracks = -1; DosTracks = -1; Source = $src }
}

function Get-CurveDate($cv) {
    # Date d une courbe (dd/MM/yyyy HH:mm, separateur de la culture courante a l enregistrement) ; MinValue si illisible
    $d = [datetime]::MinValue
    if (-not $cv -or -not $cv.Date) { return $d }
    foreach ($ci in @([System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.CultureInfo]::CurrentCulture)) {
        if ([datetime]::TryParseExact([string]$cv.Date, 'dd/MM/yyyy HH:mm', $ci, [System.Globalization.DateTimeStyles]::None, [ref]$d)) { return $d }
    }
    return [datetime]::MinValue
}

function Test-HeadCurvesCurrent([string]$fam) {
    # Courbes par tete applicables : les deux presentes et au moins aussi recentes que la courbe commune de la famille
    # (une calibration commune posterieure, apres un changement de lecteur par exemple, les rend perimees).
    $h0 = $script:PrecompCurves["${fam}_h0"]; $h1 = $script:PrecompCurves["${fam}_h1"]
    if (-not $h0 -or -not $h1 -or -not $h0.Spec -or -not $h1.Spec) { return $false }
    $one = $script:PrecompCurves[$fam]
    if (-not $one) { return $true }
    return ((Get-CurveDate $h0) -ge (Get-CurveDate $one))
}

function Get-FamilyCurves([string]$family, [bool]$preferHeads) {
    # Courbes appliquees a la famille : par tete en ecriture lente si elles sont a jour, sinon la courbe commune
    if ($preferHeads -and (Test-HeadCurvesCurrent $family)) { return ,@($script:PrecompCurves["${family}_h0"], $script:PrecompCurves["${family}_h1"]) }
    $one = $script:PrecompCurves[$family]
    if ($one) { return ,@($one) }
    return ,@()
}

function Get-HeadSpec([string]$fam, [int]$h) {
    # Profil calibre d une tete (ecriture lente), $null si la famille n a pas de calibration par tete
    $cv = $script:PrecompCurves["${fam}_h$h"]
    if ($cv -and $cv.Spec) { return [string]$cv.Spec }
    return $null
}

function Set-PrecompFields([string]$spec, [string]$fam) {
    # Champs --precomp : commun (tete 0 en ecriture lente) et tete 1. Ecriture lente : profils calibres par tete
    # de la famille s ils sont a jour, sinon le profil commun pour les deux tetes. Renvoie le complement du libelle.
    $chkWPrecomp.Checked = $true
    if ($chkWSlow.Checked -and (Test-HeadCurvesCurrent $fam)) {
        $txtWPrecomp.Text = Get-HeadSpec $fam 0; $txtWPrecomp1.Text = Get-HeadSpec $fam 1
        return (T ' ; écriture lente : profils calibrés tête 0 et tête 1 appliqués')
    }
    $txtWPrecomp.Text = $spec; $txtWPrecomp1.Text = $spec
    if (-not $chkWSlow.Checked) { return '' }
    if ((Get-HeadSpec $fam 0) -and (Get-HeadSpec $fam 1)) { return (T ' ; écriture lente : courbes par tête antérieures au profil commun, profil commun pour les deux têtes') }
    return (T ' ; écriture lente : même profil pour les deux têtes (aucune calibration par tête pour cette famille)')
}

function Get-HdProfile([string]$hf) {
    # 12.7 : profil commun d une famille haute densite : Spec de sa courbe commune, sinon profil d origine haute densite
    # (pas de champ de configuration : il suit la courbe, retablie avec elle par Restore-CalibState)
    $cv = $script:PrecompCurves[$hf]
    if ($cv -and $cv.Spec) { return [string]$cv.Spec }
    return $script:PrecompHdDefault
}

function Get-HdCommonCurve([string]$hf) {
    # 12.7 : courbe commune d une famille haute densite dont Get-HdProfile tire le profil commun ; $null sans elle
    $cv = $script:PrecompCurves[$hf]
    if ($cv -and $cv.Spec) { return $cv }
    return $null
}

function Get-HdAutoFields([string]$hf, [bool]$slow) {
    # 12.7 : champs --precomp du mode Auto pour une image haute densite calibrable (meme regle que Set-PrecompFields)
    if ($slow -and (Test-HeadCurvesCurrent $hf)) { return @{ P0 = [string](Get-HeadSpec $hf 0); P1 = [string](Get-HeadSpec $hf 1) } }
    $s = Get-HdProfile $hf
    return @{ P0 = $s; P1 = $s }
}

function Update-PrecompForImage([string]$path) {
    Update-CurveButton $path
    $script:WProfileHd = $false
    $mode = $cmbWProfile.Text
    if ($mode -eq (T 'Manuel')) { $lblWProfileInfo.Text = (T 'Profil manuel : --precomp non modifié.'); return }
    if ($mode -eq (T 'Standard 2 us'))      { $x = Set-PrecompFields $script:PrecompStd 'std';   $lblWProfileInfo.Text = ((T "Profil forcé : standard 2 us ({0})") -f "$($script:PrecompStd)") + $x; return }
    if ($mode -eq (T 'Long track 1,89 us')) { $x = Set-PrecompFields $script:PrecompLong 'long'; $lblWProfileInfo.Text = ((T "Profil forcé : long track ({0})") -f "$($script:PrecompLong)") + $x; return }
    # Auto
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { $lblWProfileInfo.Text = ''; return }
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    # 12.8 (S3-FLUX, decision 2 du 21/10/2026) : image flux sans --format (Test-RawFluxWrite) : gw n y applique pas la
    # precompensation ; champs remplis comme avant (ils servent si un format est choisi), mais le libelle ne les dit plus
    # « appliques » : complement $fxNote a la place de celui de Set-PrecompFields
    $fxNote = if (Test-RawFluxWrite $path $cmbWFmt.Text) { (T " ; image flux écrite telle quelle (sans --format) : gw n'applique pas la précompensation, --precomp n'est pas transmis") } else { '' }
    # Image haute densite (12.7) : calibrable (famille hd) -> profil calibre de sa famille, par tete en ecriture lente si
    # les courbes par tete sont a jour, sinon profil d origine haute densite ; non calibrable (ED, codages propres,
    # 360 tr/min) -> profil d origine de sa famille double densite, comme en 12.6. Pour les deux tetes, ecriture lente
    # comprise ; jamais une courbe double densite (jusqu a CalHardNs ns, trop forte pour une cellule de 1 us).
    $hd = Get-HighDensityReason $path $cmbWFmt.Text
    if ($hd) {
        $hf = Get-HdCalibFamily $path $cmbWFmt.Text
        if ($hf) {
            $spec = Get-HdProfile $hf
            $x = Set-PrecompFields $spec $hf
            # Profil commun dit calibre seulement s il vient de la courbe commune ; sans elle, en ecriture lente avec des
            # courbes par tete a jour, le profil d origine n est pas ecrit : le complement de Set-PrecompFields nomme les
            # profils des tetes
            $fn = Get-CalibFamilyName $hf
            $hcv = Get-HdCommonCurve $hf
            if ($hcv) { $fl = (T "Auto : image haute densité ({0}) -> profil calibré {1} ({2})") -f "$hd", "$fn", "$spec" }
            elseif ($chkWSlow.Checked -and (Test-HeadCurvesCurrent $hf)) { $fl = (T "Auto : image haute densité ({0}) -> {1}") -f "$hd", "$fn" }
            else { $fl = (T "Auto : image haute densité ({0}) -> profil d'origine {1} ({2}), non calibré : calibrez le lecteur en haute densité (carte « Calibrer le lecteur » de l'Accueil)") -f "$hd", "$fn", "$spec" }
            $lblWProfileInfo.Text = $fl + $(if ($fxNote) { $fxNote } else { $x })
        } else {
            $hf = Get-ImageFamily $path $cmbWFmt.Text
            $def = if ($hf -eq 'long') { $script:PrecompLongDefault } else { $script:PrecompStdDefault }
            $chkWPrecomp.Checked = $true; $txtWPrecomp.Text = $def; $txtWPrecomp1.Text = $def
            $lblWProfileInfo.Text = ((T "Auto : image haute densité ({0}) -> profil d'origine {1} ({2}) : calibration non disponible pour cette image") -f "$hd", (Get-CalibFamilyName $hf), "$def") + $fxNote
        }
        Append-Log ((T "Profil precomp : {0}") -f "$($lblWProfileInfo.Text)")
        $script:WProfileHd = $true
        return
    }
    $info = $null
    try {
        switch ($ext) {
            '.ipf' { $info = Get-IpfCellInfo $path }
            '.scp' { if ($script:ScpStatsOk) { $info = Get-ScpCellInfo $path } }
            '.hfe' { $info = Get-HfeCellInfo $path }
        }
    } catch { Append-Log ((T "Détection du profil impossible ({0}) : {1}") -f "$ext", "$($_.Exception.Message)"); $info = $null }
    if ($null -eq $info) {
        # formats secteur (ADF, IMG, ST...) : cellule standard par definition ; 12.8 (S3-FLUX) : flux non analyse (KryoFlux,
        # A2R, CTR, SCP sans module d analyse) : dit « image flux », et non « image secteur »
        $x = Set-PrecompFields $script:PrecompStd 'std'
        if (Test-FluxImage $path) { $lblWProfileInfo.Text = ((T "Auto : image flux ({0}) -> standard 2 us ({1})") -f "$ext", "$($script:PrecompStd)") + $(if ($fxNote) { $fxNote } else { $x }); return }
        $lblWProfileInfo.Text = ((T "Auto : image secteur ({0}) -> standard 2 us ({1})") -f "$ext", "$($script:PrecompStd)") + $x
        return
    }
    $long = $info.CellNs -lt $script:PrecompThresholdNs
    $x = if ($long) { Set-PrecompFields $script:PrecompLong 'long' } else { Set-PrecompFields $script:PrecompStd 'std' }
    if ($fxNote) { $x = $fxNote }
    $detail = ((T "cellule {0} ns, {1} bits/piste") -f "$([math]::Round($info.CellNs,0))", "$($info.Bits)")
    if ($info.DosTracks -ge 0 -and $info.Tracks -gt 0) { $detail += ((T ", {0}/{1} pistes DOS") -f "$($info.DosTracks)", "$($info.Tracks)") }
    $lblWProfileInfo.Text = ((T "Auto : {0} : {1} -> ") -f "$($info.Source)", "$detail") + $(if ($long) { ((T "LONG TRACK ({0})") -f "$($script:PrecompLong)") } else { ((T "standard 2 us ({0})") -f "$($script:PrecompStd)") }) + $x
    Append-Log ((T "Profil precomp : {0}") -f "$($lblWProfileInfo.Text)")
}
