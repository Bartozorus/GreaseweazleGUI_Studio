# ============================== FONCTIONS : PISTES, OPTIONS DE LECTURE, HAUTE DENSITE ===

function Get-TrackKeyOrder([string]$k) {
    $p = $k -split '\.'
    return ([int]$p[0] * 2 + [int]$p[1])
}

function Sort-TrackKeys($keys) {
    # La virgule empeche PowerShell de transformer un tableau vide en $null au retour de la fonction
    return ,@(@($keys) | Where-Object { $_ } | Sort-Object { Get-TrackKeyOrder $_ })
}

function Format-TrackList($keys, [int]$max = 24) {
    # Liste de pistes pour le journal, tronquee au-dela de $max entrees
    $k = @($keys)
    if ($k.Count -le $max) { return ($k -join ', ') }
    return ((@($k[0..($max - 1)]) -join ', ') + ((T " ... (+{0})") -f "$($k.Count - $max)"))
}

function Get-ImageTrackSet([string]$path) {
    # Pistes presentes dans l image ('cyl.tete' -> $true), $null si non determinable
    $set = @{}
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    try {
        switch ($ext) {
            '.ipf' {
                $d = [System.IO.File]::ReadAllBytes($path); $pos = 0
                while ($pos + 12 -le $d.Length) {
                    $id = [System.Text.Encoding]::ASCII.GetString($d, $pos, 4); $ln = Get-BE32 $d ($pos + 4)
                    if ($ln -lt 12) { break }
                    if ($id -eq 'IMGE' -and $pos + 12 + 44 -le $d.Length) {
                        $cyl  = Get-BE32 $d ($pos + 12)          # piste (cylindre)
                        $side = Get-BE32 $d ($pos + 16)          # face
                        $bits = Get-BE32 $d ($pos + 12 + 36)     # bits de la piste
                        $blk  = Get-BE32 $d ($pos + 12 + 40)     # nombre de blocs : 0 = piste vide
                        if ($blk -gt 0 -and $bits -gt 0 -and $cyl -lt 200 -and $side -le 1) { $set["$cyl.$side"] = $true }
                    } elseif ($id -eq 'DATA' -and $pos + 16 -le $d.Length) { $ln += Get-BE32 $d ($pos + 12) }
                    $pos += $ln
                }
            }
            '.hfe' {
                $fs = [System.IO.File]::OpenRead($path)
                try { $h = New-Object byte[] 16; [void]$fs.Read($h, 0, 16) } finally { $fs.Dispose() }
                $nt = [int]$h[9]; $ns = [math]::Max(1, [math]::Min(2, [int]$h[10]))
                for ($c = 0; $c -lt $nt; $c++) { for ($hd = 0; $hd -lt $ns; $hd++) { $set["$c.$hd"] = $true } }
            }
            '.adf' {
                $n = Get-ImageCylinders $path
                if ($null -ne $n) { for ($c = 0; $c -lt $n; $c++) { $set["$c.0"] = $true; $set["$c.1"] = $true } }
            }
            '.scp' {
                # 12.8 (decision 3 du 21/10/2026) : copie de flux : pistes presentes dans la table des pistes de l en-tete
                # (168 entrees, decalage non nul) ; octet 10 : 0 les deux faces (piste = cylindre x 2 + face), 1 ou 2 une
                # seule face (0 ou 1), numerotee cylindre x 2 + face ou, a l ancienne, par cylindre
                $fs = [System.IO.File]::OpenRead($path)
                $hb = New-Object byte[] (16 + 4 * 168)
                try { $nr = $fs.Read($hb, 0, $hb.Length) } finally { $fs.Dispose() }
                if ($nr -eq $hb.Length -and [System.Text.Encoding]::ASCII.GetString($hb, 0, 3) -eq 'SCP') {
                    $ss = [int]$hb[10]
                    $idx = @(0..167 | Where-Object { [BitConverter]::ToUInt32($hb, 16 + 4 * $_) -ne 0 })
                    if ($ss -eq 1 -or $ss -eq 2) {
                        $hd = $ss - 1
                        $paired = (@($idx | Where-Object { $_ % 2 -ne $hd }).Count -eq 0)
                        foreach ($t in $idx) { $c = if ($paired) { [int][math]::Floor($t / 2) } else { $t }; $set["$c.$hd"] = $true }
                    } else {
                        foreach ($t in $idx) { $set["$([int][math]::Floor($t / 2)).$($t % 2)"] = $true }
                    }
                }
            }
        }
    } catch { $set = @{} }
    if ($set.Count -gt 0) { return $set }
    return $null
}

function Get-TSpecExtras([string]$tspec) {
    # Elements du TSPEC utilisateur autres que c= et h= (step, h0.off, h1.off, hswap...) : conserves
    # tels quels dans les reecritures et relectures ciblees, pour viser les memes pistes physiques.
    if (-not $tspec) { return '' }
    $x = @($tspec -split ':' | Where-Object { $_.Trim() -and $_ -notmatch '^\s*[ch]\s*=' })
    if ($x.Count -eq 0) { return '' }
    return ':' + ($x -join ':')
}

function Get-TSpecHeads([string]$tspec) {
    # Tetes 0 et 1 retenues par le TSPEC utilisateur (h=0, h=1, h=0-1, h=0,1) ; les deux si h= est absent
    $m = [regex]::Match(":$tspec", ':\s*h\s*=\s*([^:]*)')
    if (-not $m.Success) { return ,@(0, 1) }
    $hs = @()
    foreach ($r in ($m.Groups[1].Value -split ',')) {
        if ($r -match '^\s*(\d+)\s*-\s*(\d+)\s*$') { for ($i = [int]$Matches[1]; $i -le [int]$Matches[2]; $i++) { $hs += $i } }
        elseif ($r -match '^\s*(\d+)\s*$') { $hs += [int]$Matches[1] }
    }
    return ,@(@(0, 1) | Where-Object { $hs -contains $_ })
}

function Set-TSpecHead([string]$tspec, [int]$h) {
    # TSPEC utilisateur restreint a la tete h : c=, step, h0.off, h1.off et hswap conserves. Sans c=, gw garde
    # les cylindres par defaut du format (ou c=0-81), comme l ecriture normale.
    $parts = @($tspec -split ':' | Where-Object { $_.Trim() -and $_ -notmatch '^\s*h\s*=' })
    return ((@($parts) + "h=$h") -join ':')
}

function Get-TSpecSelection([string]$tspec) {
    # 12.8 (FIX-PISTES) : pistes retenues par c= et h= du champ Pistes, syntaxe de gw (c=0-79, c=0,10,20, c=0-79/2 ; h=0,
    # h=0-1, h=0,1). Renvoie @{ Cyls : cylindres retenus (table), $null sans c= ou si c= est illisible ; Heads : tetes 0
    # et 1 retenues (Get-TSpecHeads) ; Restricts : c= ou h= present ; Ok : $false si c= est illisible (cylindres inconnus) }
    $r = @{ Cyls = $null; Heads = @(0, 1); Restricts = $false; Ok = $true }
    $ts = "$tspec".Trim()
    if (-not $ts) { return $r }
    $mc = [regex]::Match(":$ts", ':\s*c\s*=\s*([^:]*)')
    if ($mc.Success) {
        $r.Restricts = $true
        $cy = @{}
        foreach ($p in ($mc.Groups[1].Value -split ',')) {
            $m = [regex]::Match($p, '^\s*(\d{1,3})\s*(?:-\s*(\d{1,3})\s*(?:/\s*(\d{1,2})\s*)?)?$')
            if (-not $m.Success) { $r.Ok = $false; break }
            $s = [int]$m.Groups[1].Value
            $e = if ($m.Groups[2].Success) { [int]$m.Groups[2].Value } else { $s }
            $st = if ($m.Groups[3].Success) { [math]::Max(1, [int]$m.Groups[3].Value) } else { 1 }
            for ($c = $s; $c -le $e; $c += $st) { $cy[$c] = $true }
        }
        if ($r.Ok) { $r.Cyls = $cy }
    }
    # Get-TSpecHeads rend son tableau sans le derouler (virgule) : pas de @() autour, qui l emboiterait
    if ([regex]::IsMatch(":$ts", ':\s*h\s*=')) { $r.Restricts = $true; $r.Heads = Get-TSpecHeads $ts }
    return $r
}

function Test-TSpecKey($sel, [string]$k) {
    # Piste 'cyl.tete' retenue par une selection de Get-TSpecSelection
    $p = $k -split '\.'
    if (@($sel.Heads) -notcontains [int]$p[1]) { return $false }
    return ($null -eq $sel.Cyls -or $sel.Cyls.ContainsKey([int]$p[0]))
}

function Get-WritePartial([string]$img, [string]$fmt, [string]$tspec) {
    # 12.8 (FIX-PISTES, essai du 21/10/2026) : ecriture partielle demandee par c= ou h= du champ Pistes, c est-a-dire des
    # pistes de l image qui ne seraient pas ecrites. $null quand le champ n en retire aucune : champ vide, elements de
    # lecteur seuls (step, hswap, h0.off, h1.off : toutes les pistes ecrites), c= et h= qui couvrent toute l image, ou
    # aucune tete retenue (h=2 : refus de Start-ImageWrite ou erreur de gw, inchanges). Sinon @{ Spec : c= et h= du champ ;
    # Kept : pistes de l image ecrites ; Total : pistes de l image, -1 si inconnues }. Pistes de l image : Get-ImageTrackSet,
    # sinon cylindres (Get-ImageCylinders) et faces du format gw ; inconnues : partielle des que c= est present ou qu une
    # seule tete est retenue.
    # 12.8 (FIX-PISTES-2) : step= autre que 1 (pas du lecteur par cylindre, decision A « c=, h=, step= ») est aussi
    # signale, seul ou avec c= et h= ; seul le bouton ECRIRE consulte cette fonction (Confirm-PartialWrite), jamais la
    # Bibliotheque ni la restauration. Renvoie alors @{ Partial : c= ou h= retirent des pistes (Spec, Kept, Total comme
    # ci-dessus ; sinon Spec vide, Kept et Total a -1) ; Step : valeur de step=, 0 si absent ou egal a 1 }.
    $sel = Get-TSpecSelection $tspec
    if (@($sel.Heads).Count -eq 0) { return $null }
    $ms = [regex]::Match(":$tspec", ':\s*step\s*=\s*(\d{1,2})\s*(?=:|$)')
    $step = if ($ms.Success -and [int]$ms.Groups[1].Value -ne 1) { [int]$ms.Groups[1].Value } else { 0 }
    $p = $null
    if ($sel.Restricts) {
        $spec = (@("$tspec" -split ':' | Where-Object { $_ -match '^\s*[ch]\s*=' } | ForEach-Object { $_.Trim() }) -join ':')
        $set = Get-ImageTrackSet $img
        if ($null -eq $set) {
            $n = Get-ImageCylinders $img
            if ($null -ne $n -and [int]$n -gt 0) {
                $fe = if ($fmt -and $fmt -ne '(auto)' -and $script:GwFormats.Contains($fmt)) { $script:GwFormats[$fmt] } else { $null }
                $hs = @(if ($fe -and [int]$fe.Heads -eq 1) { 0 } else { 0, 1 })
                $set = @{}
                for ($c = 0; $c -lt [int]$n; $c++) { foreach ($h in $hs) { $set["$c.$h"] = $true } }
            }
        }
        if ($null -eq $set -or -not $sel.Ok) {
            # Pistes de l image inconnues : h=0-1 seul ne retire rien
            if (-not ($sel.Ok -and $null -eq $sel.Cyls -and @($sel.Heads).Count -eq 2)) { $p = @{ Spec = $spec; Kept = -1; Total = -1 } }
        } else {
            $kept = @(@($set.Keys) | Where-Object { Test-TSpecKey $sel $_ }).Count
            if ($kept -lt $set.Count) { $p = @{ Spec = $spec; Kept = $kept; Total = $set.Count } }
        }
    }
    if (-not $p -and -not $step) { return $null }
    if ($p) { $p.Partial = $true } else { $p = @{ Partial = $false; Spec = ''; Kept = -1; Total = -1 } }
    $p.Step = $step
    return $p
}

function Get-TrackGroups($keys) {
    # Pistes -> TSPEC exacts (aucune piste en trop) : cylindres a deux faces en h=0-1, puis face 0 seule, puis face 1 seule
    $heads = @{}
    foreach ($k in @($keys)) {
        $p = $k -split '\.'; $c = [int]$p[0]; $hd = [int]$p[1]
        if (-not $heads.ContainsKey($c)) { $heads[$c] = @{} }
        $heads[$c][$hd] = $true
    }
    $both = @(); $h0 = @(); $h1 = @()
    foreach ($c in ($heads.Keys | Sort-Object)) {
        if ($heads[$c].ContainsKey(0) -and $heads[$c].ContainsKey(1)) { $both += [int]$c }
        elseif ($heads[$c].ContainsKey(0)) { $h0 += [int]$c } else { $h1 += [int]$c }
    }
    $g = @()
    if ($both.Count -gt 0) { $g += "c=$(Format-CylList $both):h=0-1" }
    if ($h0.Count -gt 0)   { $g += "c=$(Format-CylList $h0):h=0" }
    if ($h1.Count -gt 0)   { $g += "c=$(Format-CylList $h1):h=1" }
    return ,$g
}

function Test-AdfHd([string]$path) {
    # ADF haute densite : multiple de 22 528 octets (2 faces x 22 secteurs x 512) au-dela de 84 cylindres double
    # densite, meme regle que Get-ImageCylinders et New-CalibPattern
    try { $len = (Get-Item -LiteralPath $path).Length } catch { return $false }
    return ($len -gt 0 -and $len % 22528 -eq 0 -and $len / 11264 -gt 84)
}

function Test-NeedsFormat([string]$path) {
    # Image secteur brute, sans geometrie : gw exige --format (classe IMG pour .img, .ima et .st ; .dsk sans signature
    # CPC, dsk.py : un DSK Apricot est lu par Apridisk, derive d IMG, qui exige aussi le format)
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    if (@('.img', '.ima', '.st') -contains $ext) { return $true }
    if ($ext -ne '.dsk') { return $false }
    try {
        $fs = [System.IO.File]::OpenRead($path)
        try { $b = New-Object byte[] 24; $n = $fs.Read($b, 0, 24) } finally { $fs.Dispose() }
        $s = [System.Text.Encoding]::ASCII.GetString($b, 0, $n)
        if ($s.StartsWith('MV - CPC') -or $s.StartsWith('EXTENDED CPC DSK')) { return $false }
    } catch { }
    return $true
}

function Test-HdFormat([string]$fmt) {
    # Formats gw a 500 ou 1000 kbit/s (diskdefs) : *_hd, *.1200, *.1440, *.1600, *.1680, *.dmf, *.2880, pc98.2hd/2hs,
    # *.hd, *.ed, os9.80dshd_*, luxor.1000.*, hp.mmfm.* (cellule de 1 us), raw.500, raw.1000
    if (-not $fmt) { return $false }
    return ($fmt -match '(_hd|dshd_\d+|\.(1200|1440|1600|1680|dmf|2880|2hd|2hs|hd|ed))$' -or $fmt -match '^(raw\.(500|1000)$|luxor\.1000\.|hp\.mmfm\.)')
}

function Get-CellOutOfRange([string]$path) {
    # Cellule d une image IPF ou HFE hors des plages que la calibration sait mesurer : ScpStats exige des 2T entre
    # 3 et 5 us, soit une cellule de 1,5 a 2,5 us ; marges retenues 1 700 a 2 300 ns (MFM double densite, long track
    # compris) et, 12.7, 900 a 1 100 ns (haute densite). Renvoie la cellule arrondie (ns), $null si elle est dans une
    # plage ou non lue (autres formats).
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    $info = $null
    try { switch ($ext) { '.ipf' { $info = Get-IpfCellInfo $path } '.hfe' { $info = Get-HfeCellInfo $path } } } catch { return $null }
    if ($null -eq $info -or [double]::IsNaN([double]$info.CellNs)) { return $null }
    $cn = [double]$info.CellNs
    if (-not (($cn -ge 1700 -and $cn -le 2300) -or ($cn -ge 900 -and $cn -le 1100))) { return [int][math]::Round($cn, 0) }
    return $null
}

function Get-DriveReadArgs {
    # Options de lecteur de l onglet Ecriture utilisables en relecture (controle apres ecriture, calibration) : sans
    # --fake-index, un lecteur sans capteur d index ne relit rien
    $o = @()
    if ($chkWReverse.Checked)         { $o += '--reverse' }
    if ($cmbWDensel.Text -ne '(non)') { $o += "--densel=$($cmbWDensel.Text)" }
    if ($txtWFakeIdx.Text.Trim())     { $o += "--fake-index=$($txtWFakeIdx.Text.Trim())" }
    return $o
}

function Get-HighDensityReason([string]$path, [string]$fmt) {
    # Image ou format haute densite ; $null sinon. 12.7 : une haute densite calibrable a sa propre famille (hd,
    # Get-HdCalibFamily), distincte des familles double densite (standard 2 us, long track 1,89 us).
    # Sans format explicite : format implicite de gw pour l extension (HDM, XDF, FDI, DIM, DCP : pc98.2hd ou 2hs ;
    # D2M, D4M : CMD FD2000 HD, FD4000 ED), image secteur brute de 1 200 000 octets ou plus, mode de la premiere
    # piste d un IMD.
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    if (-not $fmt -or $fmt -eq '(auto)') {
        $def = @{ '.hdm' = 'pc98.2hd'; '.xdf' = 'pc98.2hd'; '.fdi' = 'pc98.2hd'; '.dim' = 'pc98.2hd'; '.dcp' = 'pc98.2hd'
                  '.d2m' = 'commodore.cmd.fd2000.hd'; '.d4m' = 'commodore.cmd.fd4000.ed' }
        if ($def.ContainsKey($ext)) { $fmt = $def[$ext] }
    }
    if (Test-HdFormat $fmt) { return ((T "format haute densité {0}") -f "$fmt") }
    try {
        if ($ext -eq '.adf' -and (Test-AdfHd $path)) { return (T 'ADF haute densité') }
        if (@('.img', '.ima', '.st', '.dsk', '.msa') -contains $ext) {
            $len = (Get-Item -LiteralPath $path).Length
            if ($len -ge 1200000) { return ((T "image secteur de {0} octets") -f "$len") }
        }
        if ($ext -eq '.imd') {
            # IMD : en-tete texte termine par 0x1A, puis mode de la premiere piste (0 = FM, 3 = MFM a 500 kbit/s)
            $fs = [System.IO.File]::OpenRead($path)
            try { $b = New-Object byte[] 65536; $n = $fs.Read($b, 0, $b.Length) } finally { $fs.Dispose() }
            $i = [Array]::IndexOf($b, [byte]0x1A, 0, $n)
            if ($i -ge 0 -and $i + 1 -lt $n -and ($b[$i + 1] -eq 0 -or $b[$i + 1] -eq 3)) { return (T 'image IMD à 500 kbit/s') }
        }
        $info = $null
        switch ($ext) { '.ipf' { $info = Get-IpfCellInfo $path } '.hfe' { $info = Get-HfeCellInfo $path } }
        if ($null -ne $info -and $info.CellNs -lt 1500) { return ((T "image haute densité, cellule {0} ns") -f "$([math]::Round($info.CellNs, 0))") }
    } catch { }
    return $null
}

function Get-HdCalibFamily([string]$path, [string]$fmt) {
    # 12.7 : famille de calibration haute densite d une image : 'hd' (MFM, 1 us par cellule, 300 tr/min) ou $null (double
    # densite, ou haute densite non calibrable : ED, codages propres, 360 tr/min). Format explicite de la table, ou
    # implicite de l extension (meme table que Get-HighDensityReason) : sa famille (Get-FormatCalibInfo), le format
    # l emporte ; sinon ADF HD ; sinon IPF ou HFE de cellule 900 a 1 100 ns (cellule lue pour un tour de 200 ms : un HFE
    # haute densite a 360 tr/min se lit a 1 200 ns, hors plage, comme en 12.6).
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    $f = $fmt
    if (-not $f -or $f -eq '(auto)') {
        $def = @{ '.hdm' = 'pc98.2hd'; '.xdf' = 'pc98.2hd'; '.fdi' = 'pc98.2hd'; '.dim' = 'pc98.2hd'; '.dcp' = 'pc98.2hd'
                  '.d2m' = 'commodore.cmd.fd2000.hd'; '.d4m' = 'commodore.cmd.fd4000.ed' }
        $f = if ($def.ContainsKey($ext)) { $def[$ext] } else { '' }
    }
    if ($f -and $script:GwFormats.Contains($f)) {
        if ([string](Get-FormatCalibInfo $f).Cal -eq 'hd') { return 'hd' }
        return $null
    }
    try {
        if ($ext -eq '.adf' -and (Test-AdfHd $path)) { return 'hd' }
        $info = $null
        switch ($ext) { '.ipf' { $info = Get-IpfCellInfo $path } '.hfe' { $info = Get-HfeCellInfo $path } }
        if ($null -ne $info -and [double]$info.CellNs -ge 900 -and [double]$info.CellNs -le 1100) { return 'hd' }
    } catch { }
    return $null
}

function Test-ScpHighDensity([string]$path) {
    # Flux MFM double densite : aucun intervalle sous 3 us (2T = 4 us). Haute densite : 2T = 2 us, donc
    # une large part d intervalles sous 2,6 us. Premier tour de la premiere piste presente.
    $d = [System.IO.File]::ReadAllBytes($path)
    if ($d.Length -lt 700 -or [System.Text.Encoding]::ASCII.GetString($d, 0, 3) -ne 'SCP') { return $false }
    $res = ($d[11] + 1) * 25
    for ($t = 0; $t -lt 168; $t++) {
        $o = [BitConverter]::ToUInt32($d, 16 + 4 * $t)
        if ($o -eq 0) { continue }
        $ln = [BitConverter]::ToUInt32($d, $o + 8); $doff = [BitConverter]::ToUInt32($d, $o + 12)
        $flux = [ScpStats]::Decode($d, [int]($o + $doff), [int]$ln, $res)
        if ($flux.Count -lt 1000) { continue }
        $short = @($flux | Where-Object { $_ -gt 500 -and $_ -lt 2600 }).Count
        return ($short -gt 0.2 * $flux.Count)
    }
    return $false
}

# --- Effacement avant l ecriture (12.8.2) ----------------------------------------------------------------------------
# Essais du 27/10/2026 (E1, E2, E5) : un lecteur haute densite (Sony MPF920-Z) qui ecrit des disquettes double densite
# (cellule 2 us) perd 35 a 65 ns de marge, relue sur un lecteur double densite, avec le pre-effacement de gw
# (--pre-erase : effacement en courant continu, WGATE sans WDATA, 1,1 tour avant chaque essai d ecriture) ; un effacement
# haute frequence des pistes par le lecteur qui ecrit (gw erase --hfreq), puis une ecriture sans --pre-erase, gagne +61 /
# +64 ns sur cette methode. Regle « double densite » : toute ecriture, mesure ou calibration dont l image ou la famille
# n est pas haute densite : effacement haute frequence ('hfreq') ; haute densite, non essayee : pre-effacement de la
# 12.8.1 ('pre'). --erase-empty inchange (pistes absentes de l image, effacees en continu par gw : sans donnees).

function Test-ScpDensityUnknown([string]$img) {
    # Flux SCP dont la densite n est pas mesurable : module d analyse SCP absent (Test-ScpHighDensity a besoin de ScpStats)
    return ((-not $script:ScpStatsOk) -and [System.IO.Path]::GetExtension("$img").ToLower() -eq '.scp')
}

function Test-ImageHighDensity([string]$img, [string]$fmt) {
    # Image haute densite pour l effacement avant l ecriture : famille hd (Get-ImageFamily), haute densite non calibrable
    # (Get-HighDensityReason : ED, 360 tr/min, codages propres...) ou flux SCP haute densite (Test-ScpHighDensity, module
    # d analyse SCP present) ; flux SCP de densite inconnue (Test-ScpDensityUnknown) : traite comme haute densite, donc
    # pre-effacement de la 12.8.1 (revue 12.8.2) ; autre densite inconnue ou fichier illisible : double densite, comme
    # Get-ImageFamily
    try {
        if ((Get-ImageFamily $img $fmt) -eq 'hd') { return $true }
        if (Get-HighDensityReason $img $fmt) { return $true }
        if (Test-ScpDensityUnknown $img) { return $true }
        if ($script:ScpStatsOk -and [System.IO.Path]::GetExtension("$img").ToLower() -eq '.scp' -and (Test-Path -LiteralPath $img) -and (Test-ScpHighDensity $img)) { return $true }
    } catch { }
    return $false
}

function Get-EraseFallbackNote {
    # Options de lecteur de l onglet Ecriture qui imposent le pre-effacement de la 12.8.1 (Get-EraseMode) : texte de la
    # ligne de journal, $null sinon. gw erase 1.23 n accepte que --device, --drive, --revs, --tracks, --hfreq et
    # --fake-index : secteurs durs (gw erase mesure la duree d un tour sur l index, qu un disque a secteurs durs
    # fausserait) ; TG43 et --densel (revue 12.8.2) : broche 2, que gw erase ne regle pas, l effacement se ferait dans un
    # autre etat de la broche que l ecriture (5,25 pouces haute densite bivitesse, 8 pouces : non essaye)
    if ($chkWHard.Checked -or $chkWTG43.Checked) { return (T "Effacement avant l'écriture : secteurs durs ou lecteur 8 pouces (TG43), que gw erase ne prend pas en charge : pré-effacement de chaque piste (--pre-erase), comme avant.") }
    if ($cmbWDensel.Text -and $cmbWDensel.Text -ne '(non)') { return ((T "Effacement avant l'écriture : broche 2 du lecteur réglée (--densel={0}), que gw erase ne règle pas : pré-effacement de chaque piste (--pre-erase), comme avant.") -f "$($cmbWDensel.Text)") }
    return $null
}

function Get-EraseMode([bool]$hd) {
    # Effacement avant une ecriture : 'hfreq' (double densite) ou 'pre' (haute densite ; options de lecteur que gw erase ne
    # prend pas en charge, Get-EraseFallbackNote : secteurs durs, TG43, --densel)
    if ($hd -or (Get-EraseFallbackNote)) { return 'pre' }
    return 'hfreq'
}

function Get-CalibEraseEst([bool]$hd) {
    # Duree estimee de l effacement haute frequence d une passe de calibration, en s par piste (0 sans effacement) :
    # EraseEstTrack (565, essai E5 : 52 pistes en 19 s), compte dans les durees annoncees et l estimation de la barre
    if ((Get-EraseMode $hd) -eq 'hfreq') { return [double]$script:EraseEstTrack }
    return 0.0
}

function Get-EraseDriveArgs {
    # Options de lecteur de l ecriture (Get-WriteFormatArgs) que gw erase accepte : --fake-index seul (lecteur sans capteur
    # d index) ; gw erase n a ni --densel ni --reverse
    return @(Get-WriteFormatArgs | Where-Object { $_ -match '^--fake-index=' })
}

function Get-EraseTSpecs($keys) {
    # Pistes 'cyl.tete' (tetes 0 et 1) -> TSPEC exacts de gw erase, aucune piste en trop : cylindres a deux faces en h=0-1,
    # puis face 0 seule, puis face 1 seule (memes groupes que Get-TrackGroups), cylindres en plages (Format-CylRanges, 276 :
    # « 0-39,41-79 »). Tableau protege par la virgule : pas de @() autour de l appel
    $hs = @{}
    foreach ($k in @($keys)) {
        if ("$k" -notmatch '^(\d+)\.([01])$') { continue }
        $c = [int]$Matches[1]; $h = [int]$Matches[2]
        if (-not $hs.ContainsKey($c)) { $hs[$c] = @{} }
        $hs[$c][$h] = $true
    }
    $g = [ordered]@{ '0-1' = @(); '0' = @(); '1' = @() }
    foreach ($c in @($hs.Keys | Sort-Object)) {
        $n = if ($hs[$c].ContainsKey(0) -and $hs[$c].ContainsKey(1)) { '0-1' } elseif ($hs[$c].ContainsKey(0)) { '0' } else { '1' }
        $g[$n] += [int]$c
    }
    return ,@(foreach ($n in @($g.Keys)) { if (@($g[$n]).Count -gt 0) { "c=$(Format-CylRanges ([int[]]@($g[$n]))):h=$n" } })
}

function New-HfreqEraseCmds($keys, [string]$extras = '', $driveArgs = $null) {
    # Commandes gw erase --hfreq des pistes 'cyl.tete' : une par TSPEC de Get-EraseTSpecs (une seule quand toutes les pistes
    # ont les memes tetes, trois au plus), lecteur et port de l ecriture, --fake-index de l onglet Ecriture ($driveArgs ;
    # $null : Get-CommonArgs et Get-EraseDriveArgs), elements de lecteur du champ Pistes ($extras, forme de
    # Get-TSpecExtras : step, hswap, h0.off, h1.off, memes pistes physiques que l ecriture). Tableau de string[], vide sans
    # piste ; protege par la virgule : pas de @() autour de l appel
    $da = if ($null -ne $driveArgs) { @($driveArgs) } else { @(@(Get-CommonArgs) + @(Get-EraseDriveArgs)) }
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($ts in (Get-EraseTSpecs $keys)) {
        $out.Add([string[]](@('erase') + $da + @('--hfreq', "--tracks=$ts$extras")))
    }
    return ,$out.ToArray()
}

function Format-EraseTracks($cmds) {
    # Pistes des commandes de New-HfreqEraseCmds pour le journal : valeurs de --tracks, separees par « ; »
    return ((@(foreach ($c in @($cmds)) { foreach ($a in @($c)) { if ("$a" -like '--tracks=*') { "$a".Substring(9) } } })) -join ' ; ')
}

function Get-TSpecKeys([string]$tspec) {
    # Pistes 'cyl.tete' d un TSPEC a c= lisible (« c=0-4,10:h=0-1 » ; sans h= : tetes 0 et 1, comme Get-TSpecSelection) ;
    # tableau vide sans c= ou c= illisible. Protege par la virgule : pas de @() autour de l appel
    $sel = Get-TSpecSelection $tspec
    if (-not $sel.Ok -or $null -eq $sel.Cyls) { return ,@() }
    $k = @(foreach ($c in @($sel.Cyls.Keys)) { foreach ($h in @($sel.Heads)) { "$c.$h" } })
    return ,(Sort-TrackKeys $k)
}

function Get-ImageDefaultGwFormat([string]$img) {
    # Format que gw 1.23 prend sans --format pour l extension (default_format des classes d image : adf.py, d64.py,
    # d81.py) ; $null sinon (SCP, HFE, IPF, MSA, DSK, EDSK... : pistes par defaut c=0-81:h=0-1, tools/write.py)
    switch ([System.IO.Path]::GetExtension("$img").ToLower()) {
        '.adf' { return 'amiga.amigados' }
        '.d64' { return 'commodore.1541' }
        '.d71' { return 'commodore.1571' }
        '.d81' { return 'commodore.1581' }
    }
    return $null
}

function Get-ImageGeometryTrackSet([string]$path) {
    # 12.8.2 (revue) : pistes d une image secteur double densite dont l en-tete donne la geometrie ('cyl.tete' -> $true),
    # pour l effacement avant l ecriture seulement (Get-WriteEraseKeys ; Get-ImageTrackSet et ses autres usages sont
    # inchanges) ; $null sinon. Lecture conforme a gw 1.23 (image/msa.py, edsk.py, dsk.py) :
    #  - MSA (Atari ST) : 10 octets big-endian, signature 0E 0F, secteurs par piste, faces - 1, premier et dernier
    #    cylindre (inclus) ; plus de 12 secteurs par piste (haute densite, que la taille du fichier compresse ne revele
    #    pas toujours a Get-HighDensityReason) : $null ;
    #  - DSK et EDSK (Amstrad CPC) : signature « MV - CPC » ou « EXTENDED CPC DSK », cylindres a 0x30, faces a 0x31 ; EDSK :
    #    table des tailles de piste a 0x34 (par 256 octets, cylindre x faces + face, 0 = piste absente) ; DSK : taille
    #    commune a 0x32. Piste de plus de 6 656 octets (plus de 12 secteurs de 512 : haute densite) : $null. DSK sans ces
    #    signatures (image brute, --format exige) : $null
    $ext = [System.IO.Path]::GetExtension("$path").ToLower()
    if (@('.msa', '.dsk', '.edsk') -notcontains $ext) { return $null }
    $set = @{}
    try {
        $fs = [System.IO.File]::OpenRead($path)
        try { $b = New-Object byte[] 256; $n = $fs.Read($b, 0, 256) } finally { $fs.Dispose() }
        if ($ext -eq '.msa') {
            if ($n -lt 10 -or $b[0] -ne 0x0E -or $b[1] -ne 0x0F) { return $null }
            $spt = [int]$b[2] * 256 + [int]$b[3]; $ns = [int]$b[4] * 256 + [int]$b[5] + 1
            $st = [int]$b[6] * 256 + [int]$b[7]; $et = [int]$b[8] * 256 + [int]$b[9]
            if ($spt -lt 1 -or $spt -gt 12 -or $ns -lt 1 -or $ns -gt 2 -or $st -gt $et -or $et -gt 99) { return $null }
            for ($c = $st; $c -le $et; $c++) { for ($h = 0; $h -lt $ns; $h++) { $set["$c.$h"] = $true } }
        } else {
            if ($n -lt 0x34) { return $null }
            $sig = [System.Text.Encoding]::ASCII.GetString($b, 0, 16)
            $nc = [int]$b[0x30]; $ns = [int]$b[0x31]
            if ($nc -lt 1 -or $ns -lt 1 -or $ns -gt 2) { return $null }
            if ($sig.StartsWith('EXTENDED CPC DSK')) {
                if (0x34 + $nc * $ns -gt $n) { return $null }
                for ($i = 0; $i -lt $nc * $ns; $i++) {
                    $sz = [int]$b[0x34 + $i]
                    if ($sz -gt 0x1A) { return $null }
                    if ($sz -gt 0) { $set["$([int][math]::Floor($i / $ns)).$($i % $ns)"] = $true }
                }
            } elseif ($sig.StartsWith('MV - CPC')) {
                if ([int]$b[0x32] + 256 * [int]$b[0x33] -gt 0x1A00) { return $null }
                for ($c = 0; $c -lt $nc; $c++) { for ($h = 0; $h -lt $ns; $h++) { $set["$c.$h"] = $true } }
            } else { return $null }
        }
    } catch { return $null }
    if ($set.Count -gt 0) { return $set }
    return $null
}

function Get-WriteEraseKeys([string]$img, [string]$fmt, [string]$userTs, [int[]]$heads) {
    # Pistes 'cyl.tete' qu une ecriture d image ecrit (Start-ImageWrite), d apres gw 1.23 (tools/write.py) : gw parcourt
    # les pistes du format (explicite, sinon format implicite de l extension, Get-ImageDefaultGwFormat ; sans format :
    # c=0-81:h=0-1), dont c= et h= du champ Pistes remplacent les cylindres et les tetes, et n ecrit que celles que l image
    # contient. Pistes de l image : Get-ImageTrackSet, sinon geometrie de l en-tete (Get-ImageGeometryTrackSet : MSA, DSK et
    # EDSK), sinon toutes les pistes du format explicite ; retenues aussi par les tetes ecrites ($heads : faces de l image
    # en ecriture lente). Revue 12.8.2 : cylindres de l image au-dela du format (ADF de 84 cylindres en amiga.amigados) ou
    # au-dela de 81 sans format (SCP, HFE, IPF de 84 cylindres) : jamais effaces, gw ne les ecrit pas. Pistes absentes de
    # l image : non comptees (--erase-empty les efface en continu, elles ne portent pas de donnees). $null : pistes
    # inconnues (image sans table de pistes ni geometrie lisible ni format explicite, format absent de la table GwFormats,
    # c= illisible) ; l ecriture garde alors le pre-effacement. Protege par la virgule
    $sel = Get-TSpecSelection $userTs
    if (-not $sel.Ok) { return $null }
    $explicit = ($fmt -and $fmt -ne '(auto)')
    $fn = if ($explicit) { $fmt } else { Get-ImageDefaultGwFormat $img }
    $fe = $null
    if ($fn) {
        if (-not $script:GwFormats.Contains($fn)) { return $null }
        $fe = $script:GwFormats[$fn]
        if ([int]$fe.Cyls -le 0) { return $null }
    }
    $fh = @(if ($fe -and [int]$fe.Heads -eq 1) { 0 } else { 0, 1 })
    $set = Get-ImageTrackSet $img
    if ($null -eq $set) { $set = Get-ImageGeometryTrackSet $img }
    if ($null -eq $set) {
        if (-not $explicit -or -not $fe) { return $null }
        $set = @{}
        for ($c = 0; $c -lt [int]$fe.Cyls; $c++) { foreach ($h in $fh) { $set["$c.$h"] = $true } }
    }
    $nc = if ($fe) { [int]$fe.Cyls } else { 82 }
    $hasH = [regex]::IsMatch(":$userTs", ':\s*h\s*=')
    $keys = @(@($set.Keys) | Where-Object {
        $p = ([string]$_ -split '\.'); $c = [int]$p[0]; $h = [int]$p[1]
        (Test-TSpecKey $sel $_) -and @($heads) -contains $h -and ($null -ne $sel.Cyls -or $c -lt $nc) -and ($hasH -or $fh -contains $h)
    })
    return ,(Sort-TrackKeys $keys)
}
