# ============================== FONCTIONS : DETECTION DU FORMAT ================
# 12.8 (lot 2, points 4 et 6 ; A1 § 3.3, 3.4 et 4.2 ; decisions128 : regle PC / Atari ST sur critere positif, ADF de 81 a
# 83 cylindres ; D12) : format d une disquette (restauration en detection automatique ; comparaison quand la sonde de la
# disquette ne trouve aucun secteur au format de la reference) et d une image de reference (comparaison).
#  - Invoke-DiskFormatDetect enchaine les commandes gw dans $script:Chain : D0 lecture ibm.scan --raw de deux pistes, D1
#    densite et pistes critiques du flux, D2 decodage Amiga hors ligne, D4 secteur de demarrage, D5 (FIX2) flux de trois
#    cylindres de plus quand la piste 0 est vierge (restauration, double densite) ; Select-DiskFormat,
#    fonction pure, decide d apres leurs lignes ; Complete-DiskFormatDetect rend le resultat a la restauration ou a la
#    comparaison.
#  - Get-RefImageFormat : format d une image de reference sans disque (ADF : taille ; ST, IMG, IMA : BPB puis taille), ou
#    candidats a decoder par gw sur deux pistes (IPF, SCP, HFE), departages par Select-RefDecodeFormat (fonction pure).

function Get-FormatGeometry([string]$fmt) {
    # Cylindres, faces et secteurs de 512 octets par piste des formats secteur de la detection (diskdefs de gw 1.23 :
    # diskdefs_amiga.cfg, diskdefs_ibm.cfg, diskdefs_atarist.cfg, relus le 20/10/2026) ; $null pour un autre format
    switch ($fmt) {
        'amiga.amigados'    { return @{ Cyls = 80; Heads = 2; Spt = 11 } }
        'amiga.amigados_hd' { return @{ Cyls = 80; Heads = 2; Spt = 22 } }
        'atarist.360'       { return @{ Cyls = 80; Heads = 1; Spt = 9 } }
        'atarist.400'       { return @{ Cyls = 80; Heads = 1; Spt = 10 } }
        'atarist.440'       { return @{ Cyls = 80; Heads = 1; Spt = 11 } }
        'atarist.720'       { return @{ Cyls = 80; Heads = 2; Spt = 9 } }
        'atarist.800'       { return @{ Cyls = 80; Heads = 2; Spt = 10 } }
        'atarist.880'       { return @{ Cyls = 80; Heads = 2; Spt = 11 } }
        'ibm.160'           { return @{ Cyls = 40; Heads = 1; Spt = 8 } }
        'ibm.180'           { return @{ Cyls = 40; Heads = 1; Spt = 9 } }
        'ibm.320'           { return @{ Cyls = 40; Heads = 2; Spt = 8 } }
        'ibm.360'           { return @{ Cyls = 40; Heads = 2; Spt = 9 } }
        'ibm.720'           { return @{ Cyls = 80; Heads = 2; Spt = 9 } }
        'ibm.800'           { return @{ Cyls = 80; Heads = 2; Spt = 10 } }
        'ibm.1200'          { return @{ Cyls = 80; Heads = 2; Spt = 15 } }
        'ibm.1440'          { return @{ Cyls = 80; Heads = 2; Spt = 18 } }
        'ibm.1680'          { return @{ Cyls = 80; Heads = 2; Spt = 21 } }
        'ibm.2880'          { return @{ Cyls = 80; Heads = 2; Spt = 36 } }
    }
    return $null
}

function Get-GeometryFormat([int]$cyls, [int]$heads, [int]$spt, [string[]]$order) {
    # Format d une geometrie (BPB) parmi $order : memes faces et secteurs par piste, cylindres du format a +3 pres
    # (disquettes de 81 a 83 cylindres) ; cylindres exacts d abord ; '' si aucun
    foreach ($exact in @($true, $false)) {
        foreach ($f in $order) {
            $g = Get-FormatGeometry $f
            if (-not $g -or $g.Heads -ne $heads -or $g.Spt -ne $spt) { continue }
            if ($exact -and $cyls -eq $g.Cyls) { return $f }
            if (-not $exact -and $cyls -gt $g.Cyls -and $cyls -le $g.Cyls + 3) { return $f }
        }
    }
    return ''
}

function Get-SizeFormat([long]$size, [string[]]$order) {
    # Format d une image secteur d apres sa seule taille, parmi $order (cylindres du format, puis jusqu a 3 de plus) ;
    # $null si aucun
    foreach ($d in 0..3) {
        foreach ($f in $order) {
            $g = Get-FormatGeometry $f
            if ($g -and $size -eq [long]($g.Cyls + $d) * $g.Heads * $g.Spt * 512) { return @{ Format = $f; Cyls = $g.Cyls + $d } }
        }
    }
    return $null
}

function Get-BootSectorInfo($b) {
    # Secteur de demarrage (512 octets) : octet 0, somme des 256 mots big-endian (0x1234 : amorcable Atari ST), signature
    # 0x55AA, BPB (octets par secteur 0x0B, total des secteurs 0x13, secteurs par piste 0x18, faces 0x1A ; Bpb : valeurs
    # plausibles) ; $null sans secteur ou pour un secteur non lu (motif « -=[BAD SECTOR]=- » de gw)
    if ($null -eq $b -or $b.Length -lt 512) { return $null }
    $pat = [System.Text.Encoding]::ASCII.GetBytes('-=[BAD SECTOR]=-'); $isBad = $true
    for ($i = 0; $i -lt 512; $i++) { if ($b[$i] -ne $pat[$i % 16]) { $isBad = $false; break } }
    if ($isBad) { return $null }
    $sum = 0
    for ($i = 0; $i -lt 512; $i += 2) { $sum = ($sum + 256 * [int]$b[$i] + [int]$b[$i + 1]) -band 0xFFFF }
    $bps = [int]$b[11] + 256 * [int]$b[12]; $total = [int]$b[19] + 256 * [int]$b[20]
    $spt = [int]$b[24] + 256 * [int]$b[25]; $heads = [int]$b[26] + 256 * [int]$b[27]
    return @{ Byte0 = [int]$b[0]; StSum = $sum; StPositive = ([int]$b[0] -eq 0x60 -or $sum -eq 0x1234); Sig = ([int]$b[510] -eq 0x55 -and [int]$b[511] -eq 0xAA)
              Bps = $bps; Total = $total; Spt = $spt; Heads = $heads
              Bpb = ($bps -eq 512 -and $spt -ge 1 -and $spt -le 63 -and $heads -ge 1 -and $heads -le 2 -and $total -gt 0) }
}

function Read-FileHead([string]$path, [int]$n = 512) {
    # Premiers octets d un fichier ; $null s il est illisible ou plus court
    try {
        $fs = [System.IO.File]::OpenRead($path)
        try { $b = New-Object byte[] $n; $got = $fs.Read($b, 0, $n) } finally { $fs.Dispose() }
        if ($got -lt $n) { return $null }
        return ,$b
    } catch { return $null }
}

function Get-IpfFormattedCyls([string]$path) {
    # Cylindres formates d un IPF : derniere piste IMGE ayant des blocs, plus un (Get-ImageCylinders compte aussi les
    # IMGE vides : 82 ou 84 pour un IPF de 80 cylindres formates, L2-DATA ecart 3) ; $null si illisible
    try {
        $d = [System.IO.File]::ReadAllBytes($path); $max = -1; $pos = 0
        while ($pos + 12 -le $d.Length) {
            $id = [System.Text.Encoding]::ASCII.GetString($d, $pos, 4); $ln = Get-BE32 $d ($pos + 4)
            if ($ln -lt 12) { break }
            if ($id -eq 'IMGE' -and $pos + 12 + 44 -le $d.Length) {
                $t = Get-BE32 $d ($pos + 12)
                if ((Get-BE32 $d ($pos + 12 + 40)) -gt 0 -and $t -gt $max -and $t -lt 200) { $max = $t }
            } elseif ($id -eq 'DATA' -and $pos + 16 -le $d.Length) { $ln += Get-BE32 $d ($pos + 12) }
            $pos += $ln
        }
        if ($max -ge 0) { return [int]($max + 1) }
    } catch { }
    return $null
}

function Get-RefImageFormat([string]$path) {
    # Format d une image de reference de la comparaison, sans disque (A1 § 4.2, decisions128, a5 § 2.3 et 4). Renvoie
    # Format ('' : inconnu), Cyls (cylindres de l image, $null si inconnus), Need ('decode' : IPF, SCP, HFE, a decoder
    # par gw sur les pistes 0.0 et 0.1 avec les candidats Cands, dans l ordre), HD, Why (texte du resultat) :
    #  - ADF : AmigaDOS toujours (un ADF ne represente que des pistes AmigaDOS ; signature DOS ou NDOS sans role), haute
    #    densite selon Test-AdfHd, cylindres d apres la taille (81 a 83 : la comparaison relit ces cylindres) ;
    #  - ST (atarist.*), IMG et IMA (ibm.*, puis atarist.* pour une face de 80 pistes, sans equivalent ibm.*) : BPB du
    #    secteur 0 si son total de secteurs fait la taille du fichier, sinon la taille seule ; un .st de 901 120 octets est
    #    un atarist.880 : l extension decide, a taille egale avec un ADF ;
    #  - IPF, SCP, HFE : densite (cellule IPF ou HFE, Test-ScpHighDensity pour un SCP), puis decodage par gw : AmigaDOS,
    #    puis les formats IBM du plus grand nombre de secteurs au plus petit (un decodeur fixe a 9 secteurs en trouve
    #    aussi 9 sur une piste de 10).
    $r = @{ Format = ''; Cyls = $null; Need = ''; HD = $false; Cands = @(); Why = '' }
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    try { $size = [long](Get-Item -LiteralPath $path -ErrorAction Stop).Length } catch { $r.Why = (T 'image de référence illisible'); return $r }
    $sz = Format-UiNum ([double]$size) '#,0'
    if ($ext -eq '.adf') {
        $r.HD = [bool](Test-AdfHd $path)
        $r.Format = $(if ($r.HD) { 'amiga.amigados_hd' } else { 'amiga.amigados' })
        $unit = $(if ($r.HD) { 22528 } else { 11264 })
        if ($size -gt 0 -and $size % $unit -eq 0) { $r.Cyls = [int]($size / $unit) }
        $r.Why = (T "référence {0} de {1} octets") -f 'ADF', $sz
        if ($null -ne $r.Cyls -and $r.Cyls -ne 80) { $r.Why += ((T ", {0} cylindres") -f "$($r.Cyls)") }
        return $r
    }
    if (@('.st', '.img', '.ima') -contains $ext) {
        $kind = $(if ($ext -eq '.st') { 'ST' } else { 'IMG' })
        $order = if ($ext -eq '.st') { @('atarist.720', 'atarist.800', 'atarist.880', 'atarist.360', 'atarist.400', 'atarist.440') }
                 else { @('ibm.720', 'ibm.1440', 'ibm.360', 'ibm.1200', 'ibm.800', 'ibm.1680', 'ibm.2880', 'ibm.180', 'ibm.160', 'ibm.320', 'atarist.360', 'atarist.400', 'atarist.440', 'atarist.880') }
        $bi = Get-BootSectorInfo (Read-FileHead $path 512)
        if ($bi -and $bi.Bpb -and [long]$bi.Total * 512 -eq $size -and $bi.Total % ($bi.Heads * $bi.Spt) -eq 0) {
            $c = [int]($bi.Total / ($bi.Heads * $bi.Spt))
            $f = Get-GeometryFormat $c $bi.Heads $bi.Spt $order
            if ($f) {
                $r.Format = $f; $r.Cyls = $c
                $r.Why = (T "référence {0} de {1} octets, BPB {2} x {3} x {4}") -f $kind, $sz, "$c", "$($bi.Heads)", "$($bi.Spt)"
                return $r
            }
        }
        $m = Get-SizeFormat $size $order
        if ($m) { $r.Format = $m.Format; $r.Cyls = $m.Cyls; $r.Why = (T "référence {0} de {1} octets") -f $kind, $sz; return $r }
        $r.Why = (T "référence {0} de {1} octets : taille et BPB non reconnus") -f $kind, $sz
        return $r
    }
    if (@('.ipf', '.scp', '.hfe') -contains $ext) {
        $r.Need = 'decode'
        try {
            if ($ext -eq '.ipf') { $r.HD = ([double](Get-IpfCellInfo $path).CellNs -lt 1500); $r.Cyls = Get-IpfFormattedCyls $path }
            elseif ($ext -eq '.hfe') { $r.HD = ([double](Get-HfeCellInfo $path).CellNs -lt 1500) }
            else { $r.HD = [bool](Test-ScpHighDensity $path) }
        } catch { }
        $r.Cands = $(if ($r.HD) { @('amiga.amigados_hd', 'ibm.1440') } else { @('amiga.amigados', 'atarist.880', 'atarist.800', 'ibm.720') })
        $r.Why = (T "référence {0} de {1} octets, décodée par gw sur les pistes 0.0 et 0.1") -f $ext.TrimStart('.').ToUpper(), $sz
        return $r
    }
    $r.Why = (T "extension {0} non prise en charge par la détection automatique") -f $ext
    return $r
}

function Get-GwTrackSectors($lines) {
    # Bilan par piste des lignes de gw (read ou convert avec un format) : « T0.0: IBM MFM (9/9 sectors) from Raw Flux
    # (...) », « T0.1: IBM Empty from ... », « T0.0: AmigaDOS (11/11 sectors) from ... » ; cle « cyl.tete » -> Mode, Found,
    # Total (derniere ligne de la piste). Ignorees : « Unknown mark », grille et bilan de print_summary, « Giving up »,
    # avertissements « Out of range », flux sans decodeur (faux gw : « T0.0: Raw Flux (...) »)
    $t = @{}
    foreach ($l in @($lines)) {
        $s = [string]$l
        if ($s -match '^T(\d+)\.(\d+)\b[^:]*:\s*(IBM MFM|IBM FM|IBM Empty|AmigaDOS)\b(?:\s*\((\d+)/(\d+) sectors\))?') {
            $f = 0; $n = 0
            if ($Matches[4]) { $f = [int]$Matches[4]; $n = [int]$Matches[5] }
            $t["$([int]$Matches[1]).$([int]$Matches[2])"] = @{ Mode = $Matches[3]; Found = $f; Total = $n }
        }
    }
    return $t
}

function New-DiskFormatResult([string]$kind, [string]$fmt, [string]$action, [string]$text, [string]$score, [string]$tail, [string]$name = '', [string]$why = '') {
    # Resultat de Select-DiskFormat ; Log : ligne de journal (scores des decodeurs, decision). FIX2 : Name (nom court du
    # format reconnu : ligne du cadre 1, ligne « Disquette » de la comparaison), Why (raison courte d une copie de flux ou
    # d un arret : etape 2, ligne du cadre 1), Score (scores des decodeurs) ; NeedBoot et BootFmt (D4 a faire, format de
    # decodage du secteur de demarrage), NeedProbe (D5 a faire : piste 0 vierge en restauration)
    return @{ Format = $fmt; Action = $action; Kind = $kind; Text = $text; Log = ((T "Détection du format : {0} ; {1}.") -f $score, $tail); NeedBoot = $false
              BootFmt = ''; NeedProbe = $false; Name = $name; Why = $why; Score = $score }
}

function Get-UnknownFormatResult([bool]$hd, [string]$why, [string]$score) {
    # Format inconnu (A1 § 3.4) : copie exacte du flux en double densite ; arret en haute densite, une copie de flux haute
    # densite ne pouvant pas etre controlee (regle de la 12.7, Complete-RestoreRead)
    if ($hd) {
        return New-DiskFormatResult 'unknown' '' 'stop' ((T "format haute densité non reconnu ({0}) : une copie de flux ne pourrait pas être contrôlée. Si vous connaissez le format, choisissez-le dans la liste.") -f $why) $score (T 'format haute densité non reconnu, arrêt avant toute écriture') '' (T 'format haute densité non reconnu')
    }
    return New-DiskFormatResult 'unknown' '' 'flux' ((T "Format non reconnu ({0}) : copie exacte du flux, sans comparaison par secteur.") -f $why) $score (T 'format non reconnu, copie exacte du flux') '' (T 'format non reconnu')
}

function Select-DiskFormat($m) {
    # Fonction pure (A1 § 3.3 et 3.4, decisions128, D12). $m : D0 (lignes de gw de la lecture ibm.scan --raw des pistes
    # 0.0 et 0.1), D2 (lignes du decodage Amiga hors ligne de ce flux), AmigaFmt (format de D2), HD (densite du flux,
    # Test-ScpHighDensity), Tracks et Crit (pistes du flux et pistes critiques, Get-TrackMetrics), Boot (secteur 0 de la
    # piste 0.0 decode en ibm.720 par D4, ou $null) et BootDone (D4 faite, meme sans secteur). Regles, dans l ordre :
    #  1. aucun secteur, et toutes les pistes du flux critiques (ou aucune piste) : disquette vierge, absente ou tetes
    #     sales -> arret ;
    #  2. D3 : un decodeur est retenu s il donne une piste complete et au moins deux fois plus de secteurs valides que
    #     l autre (AmigaDOS contre IBM) ; sinon format inconnu (ambiguite) ;
    #  3. AmigaDOS : format de D2. Une piste incomplete, en double densite : protection contre la copie probable -> copie
    #     exacte du flux d office (D12, mode automatique), sans lecture secteur qui echouerait sur les pistes protegees ;
    #  4. IBM : codage MFM et meme nombre de secteurs sur les deux faces, sinon inconnu (FM, une seule face lisible).
    #     9 secteurs en double densite : « Atari ST » sur critere positif seulement (octet 0 = 0x60, BRA.S du 68000, ou
    #     somme des 256 mots big-endian du secteur de demarrage = 0x1234 : atarist.720) ; sinon « 9 secteurs de 512 octets,
    #     format PC » (ibm.720 ; ibm.360 si le BPB annonce 720 secteurs sur 2 faces), sans affirmer la machine d origine :
    #     0x55AA ne joue aucun role (images ST de mtools) et les donnees sont les memes. 10 et 11 secteurs en double
    #     densite : atarist.800 et atarist.880 ; 18 en haute densite : ibm.1440 ; autre nombre : inconnu. Piste incomplete
    #     en double densite : protection probable, copie exacte du flux ;
    #  5. format inconnu : copie exacte du flux en double densite, arret en haute densite.
    # FIX2 (relecture adverse du lot 2) :
    #  - regle 1, restauration en double densite ($m.CanProbe) : avant de conclure a une disquette vierge, D5 lit trois
    #    cylindres de plus (1, 40, 79 ; Lemmings disque 2 : piste 0 non formatee). Donnees sur l un d eux ($m.ProbeData) :
    #    piste 0 non formatee, protection probable, copie exacte du flux ; sinon arret ;
    #  - regle 4 : D4 pour tout format IBM retenu (9, 10, 11 secteurs en double densite, 18 en haute densite), avec ce
    #    format ($res.BootFmt). Un BPB plausible qui annonce plus de secteurs que le format n en lit (disquette de 81 a 83
    #    cylindres) : copie exacte du flux en double densite, arret en haute densite (gw ne lit que les cylindres du format :
    #    une copie secteur les perdrait) ; ibm.360 seulement si le champ Pistes contient step=2 ($m.Step2), sinon ibm.720
    #    (lecture des 80 cylindres, sans perte).
    # Renvoie Format ('' : aucun ; format reconnu d une disquette protegee), Action (sector : lecture secteur ; flux :
    # copie exacte du flux ; stop : arret avant toute ecriture), Kind (amiga, pc, st, protect, extended, unknown, blank),
    # Text (rapport, infobulle du cadre 1, raison d un arret), Log (journal : scores de chaque decodeur et decision), Name,
    # Why, Score, NeedBoot (D4 pas encore faite : nouvel appel avec Boot et BootDone), NeedProbe (D5 pas encore faite :
    # nouvel appel avec ProbeDone, ProbeData, ProbeTracks).
    $ibm = Get-GwTrackSectors $m.D0
    $ami = Get-GwTrackSectors $m.D2
    $af = $(if ($m.AmigaFmt) { [string]$m.AmigaFmt } else { 'amiga.amigados' })
    $hd = [bool]$m.HD
    $nAmi = 0; $nAmiT = 0; $nIbm = 0; $aFull = 0; $iFull = 0; $aInc = @(); $parts = @()
    foreach ($k in @('0.0', '0.1')) {
        $a = $ami[$k]
        if ($a -and $a.Mode -eq 'AmigaDOS' -and $a.Total -gt 0) {
            $nAmi += $a.Found; $nAmiT += $a.Total
            if ($a.Found -eq $a.Total) { $aFull++ } else { $aInc += $k }
        } else { $aInc += $k }
        $b = $ibm[$k]
        if ($b -and $b.Total -gt 0 -and ($b.Mode -eq 'IBM MFM' -or $b.Mode -eq 'IBM FM')) {
            $nIbm += $b.Found
            if ($b.Found -eq $b.Total) { $iFull++ }
            $parts += "$($b.Mode) $($b.Found)/$($b.Total)"
        } else { $parts += (T 'vide') }
    }
    if ($nAmiT -eq 0) { $nAmiT = 2 * [int](Get-FormatGeometry $af).Spt }
    $score = (T "AmigaDOS {0}/{1}, IBM {2} (pistes 0.0 et 0.1 : {3})") -f "$nAmi", "$nAmiT", "$nIbm", ($parts -join ', ')
    if ($nAmi -eq 0 -and $nIbm -eq 0) {
        if ([int]$m.Tracks -le 0 -or [int]$m.Crit -ge [int]$m.Tracks) {
            $tail = (T "aucun secteur, {0} piste(s) critique(s) sur {1} dans le flux") -f "$([int]$m.Crit)", "$([int]$m.Tracks)"
            if ($m.CanProbe -and -not $hd -and [int]$m.Tracks -gt 0) {
                # FIX2 : piste 0 vierge en double densite (restauration) : D5, trois cylindres de plus, avant de conclure
                if (-not $m.ProbeDone) { $res = New-DiskFormatResult 'blank' '' '' '' $score ''; $res.NeedProbe = $true; return $res }
                if ([int]$m.ProbeData -gt 0) {
                    return New-DiskFormatResult 'protect' '' 'flux' ((T "Piste 0 sans donnée lisible, mais données sur {0} des {1} pistes sondées (cylindres 1, 40 et 79) : piste 0 non formatée, protection contre la copie probable. Copie exacte du flux, sans comparaison par secteur.") -f "$([int]$m.ProbeData)", "$([int]$m.ProbeTracks)") $score ((T "{0} ; données sur {1} des {2} pistes sondées : piste 0 non formatée, copie exacte du flux") -f $tail, "$([int]$m.ProbeData)", "$([int]$m.ProbeTracks)") '' (T 'piste 0 non formatée')
                }
                $tail += ' ; ' + ((T "aucune donnée sur les {0} pistes sondées (cylindres 1, 40 et 79)") -f "$([int]$m.ProbeTracks)")
            }
            return New-DiskFormatResult 'blank' '' 'stop' (T 'aucune donnée lisible : disquette vierge, absente ou têtes sales') $score $tail '' (T 'aucune donnée lisible')
        }
        return Get-UnknownFormatResult $hd (T 'aucun secteur reconnu') $score
    }
    if ($nAmi -gt 0 -and $aFull -ge 1 -and $nAmi -ge 2 * $nIbm) {
        $name = $(if ($af -eq 'amiga.amigados_hd') { (T "Amiga haute densité ({0})") -f $af } else { (T "Amiga double densité ({0})") -f $af })
        $short = $(if ($af -eq 'amiga.amigados_hd') { (T 'Amiga haute densité') } else { (T 'Amiga double densité') })
        $lab = (T "{0}, {1}/{2} secteurs") -f $name, "$nAmi", "$nAmiT"
        if ($aInc.Count -gt 0 -and -not $hd) {
            $k = $aInc[0]; $x = $ami[$k]
            $fx = $(if ($x) { [int]$x.Found } else { 0 }); $tx = $(if ($x -and $x.Total -gt 0) { [int]$x.Total } else { [int](Get-FormatGeometry $af).Spt })
            $res = New-DiskFormatResult 'protect' $af 'flux' ((T "{0} : piste {1} incomplète ({2}/{3} secteurs), protection contre la copie probable. Copie exacte du flux, sans comparaison par secteur.") -f $name, $k, "$fx", "$tx") $score ((T "protection contre la copie probable (piste {0} incomplète), copie exacte du flux") -f $k) $short (T 'protection contre la copie probable')
            return $res
        }
        return New-DiskFormatResult 'amiga' $af 'sector' $lab $score ((T "format retenu : {0}") -f $af) $short
    }
    if ($nIbm -gt 0 -and $iFull -ge 1 -and $nIbm -ge 2 * $nAmi) {
        $t0 = $ibm['0.0']; $t1 = $ibm['0.1']
        if (($t0 -and $t0.Mode -eq 'IBM FM') -or ($t1 -and $t1.Mode -eq 'IBM FM')) { return Get-UnknownFormatResult $hd (T 'codage FM') $score }
        $n0 = $(if ($t0 -and $t0.Mode -eq 'IBM MFM') { [int]$t0.Total } else { 0 }); $n1 = $(if ($t1 -and $t1.Mode -eq 'IBM MFM') { [int]$t1.Total } else { 0 })
        if ($n0 -ne $n1 -or $n0 -eq 0) { return Get-UnknownFormatResult $hd ((T "{0} et {1} secteurs sur les deux faces") -f "$n0", "$n1") $score }
        $spt = $n0; $fmt = ''; $kind = 'pc'; $bootTxt = ''; $note = ''
        # FIX2 : D4 pour tout format IBM retenu, decode avec ce format (9 secteurs : ibm.720, memes secteurs qu atarist.720)
        $bootFmt = $(if (-not $hd -and $spt -eq 9) { 'ibm.720' } elseif (-not $hd -and $spt -eq 10) { 'atarist.800' } elseif (-not $hd -and $spt -eq 11) { 'atarist.880' } elseif ($hd -and $spt -eq 18) { 'ibm.1440' } else { '' })
        if (-not $bootFmt) { return Get-UnknownFormatResult $hd ((T "{0} secteurs par piste") -f "$spt") $score }
        if ($null -eq $m.Boot -and -not $m.BootDone) { $res = New-DiskFormatResult 'pc' '' '' '' $score ''; $res.NeedBoot = $true; $res.BootFmt = $bootFmt; return $res }
        $bi = Get-BootSectorInfo $m.Boot
        if ($bi) { $bootTxt = ' (' + ((T "secteur de démarrage : octet 0 = 0x{0:X2}, somme des mots 0x{1:X4}") -f $bi.Byte0, $bi.StSum) + ')' }
        if ($spt -eq 9 -and -not $hd) {
            if ($bi -and $bi.StPositive) { $fmt = 'atarist.720'; $kind = 'st' }
            elseif ($bi -and $bi.Bpb -and $bi.Total -eq 720 -and $bi.Heads -eq 2 -and $bi.Spt -eq 9) {
                if ($m.Step2) { $fmt = 'ibm.360' }
                else {
                    # FIX2 : sans step=2, ibm.360 ne lirait que les cylindres 0 a 39 ; ibm.720 lit les 80 (rien de perdu)
                    $fmt = 'ibm.720'
                    $note = ' ' + (T "Le secteur de démarrage annonce 40 cylindres : pour une disquette 5,25 pouces de 40 pistes dans un lecteur de 80 pistes, indiquez step=2 dans le champ Pistes de l'onglet Écriture.")
                }
            }
            else { $fmt = 'ibm.720' }
        }
        elseif ($spt -eq 18) { $fmt = 'ibm.1440' }
        else { $fmt = $bootFmt; $kind = 'st' }
        $name = $(if ($kind -eq 'st') { (T "Atari ST, {0} secteurs de 512 octets ({1})") -f "$spt", $fmt } else { (T "{0} secteurs de 512 octets, format PC ({1})") -f "$spt", $fmt })
        $short = $(if ($kind -eq 'st') { (T "Atari ST, {0} secteurs") -f "$spt" } else { (T "PC, {0} secteurs") -f "$spt" })
        $inc = @(@('0.0', '0.1') | Where-Object { $ibm[$_].Found -lt $ibm[$_].Total })
        if ($inc.Count -gt 0 -and -not $hd) {
            $k = $inc[0]
            return New-DiskFormatResult 'protect' $fmt 'flux' ((T "{0} : piste {1} incomplète ({2}/{3} secteurs), protection contre la copie probable. Copie exacte du flux, sans comparaison par secteur.") -f $name, $k, "$($ibm[$k].Found)", "$($ibm[$k].Total)") $score ((T "protection contre la copie probable (piste {0} incomplète), copie exacte du flux") -f $k) $short (T 'protection contre la copie probable')
        }
        # FIX2 : BPB plausible qui annonce plus de secteurs que le format n en lit : gw ne lirait que les cylindres du format
        $g = Get-FormatGeometry $fmt
        if ($bi -and $bi.Bpb -and $g -and [int]$bi.Total -gt $g.Cyls * $g.Heads * $g.Spt) {
            $bc = [int][math]::Ceiling([int]$bi.Total / ([int]$bi.Heads * [int]$bi.Spt))
            $why = (T "le secteur de démarrage annonce {0} secteurs ({1} cylindres de {2} face(s) et {3} secteurs), le format {4} n'en lit que {5} ({6} cylindres)") -f "$($bi.Total)", "$bc", "$($bi.Heads)", "$($bi.Spt)", $fmt, "$($g.Cyls * $g.Heads * $g.Spt)", "$($g.Cyls)"
            if ($hd) {
                return New-DiskFormatResult 'extended' $fmt 'stop' ((T "{0} : {1} ; une copie de flux haute densité ne pourrait pas être contrôlée : arrêt avant toute écriture.") -f $name, $why) $score (((T "format haute densité étendu ({0} cylindres annoncés), arrêt avant toute écriture") -f "$bc") + $bootTxt) $short (T 'format haute densité étendu')
            }
            return New-DiskFormatResult 'extended' $fmt 'flux' ((T "{0} : {1}. Copie exacte du flux, sans comparaison par secteur.") -f $name, $why) $score (((T "format étendu ({0} cylindres annoncés), copie exacte du flux") -f "$bc") + $bootTxt) $short (T 'format étendu au-delà de ses cylindres')
        }
        return New-DiskFormatResult $kind $fmt 'sector' (((T "{0}, {1}/{2} secteurs") -f $name, "$nIbm", "$(2 * $spt)") + $note) $score (((T "format retenu : {0}") -f $fmt) + $bootTxt) $short
    }
    return Get-UnknownFormatResult $hd ((T "ambiguïté : AmigaDOS {0}, IBM {1}") -f "$nAmi", "$nIbm") $score
}

function Select-RefDecodeFormat($results) {
    # Fonction pure (A1 § 4.2, regle de D3) : format d une image IPF, SCP ou HFE d apres le decodage de ses pistes 0.0 et
    # 0.1 par chaque candidat ($results : Fmt, Lines, dans l ordre d essai). Le premier candidat dont les deux pistes sont
    # completes ; sinon celui qui a une piste complete et au moins deux fois plus de secteurs que le second (pistes
    # incompletes : protection probable, signalee) ; sinon inconnu. Renvoie Format ('' : inconnu), Found, Total, Inc
    # (pistes incompletes), Text
    $rows = @()
    foreach ($x in @($results)) {
        if (-not $x) { continue }
        $t = Get-GwTrackSectors $x.Lines; $f = 0; $n = 0; $full = 0; $inc = @()
        foreach ($k in @('0.0', '0.1')) {
            $e = $t[$k]
            if ($e -and $e.Total -gt 0 -and $e.Mode -ne 'IBM Empty') { $f += $e.Found; $n += $e.Total; if ($e.Found -eq $e.Total) { $full++ } else { $inc += $k } }
            else { $inc += $k }
        }
        $rows += ,@{ Fmt = [string]$x.Fmt; Found = $f; Total = $n; Full = $full; Inc = $inc }
    }
    $pick = $null
    foreach ($w in $rows) { if ($w.Full -eq 2) { $pick = $w; break } }
    if (-not $pick -and $rows.Count -gt 0) {
        $s = @($rows | Sort-Object -Property @{ Expression = { [int]$_.Found }; Descending = $true })
        $second = $(if ($s.Count -gt 1) { [int]$s[1].Found } else { 0 })
        if ($s[0].Found -gt 0 -and $s[0].Full -ge 1 -and $s[0].Found -ge 2 * $second) { $pick = $s[0] }
    }
    if (-not $pick) {
        $best = @($rows | ForEach-Object { "$($_.Fmt) $($_.Found)/$($_.Total)" }) -join ', '
        return @{ Format = ''; Found = 0; Total = 0; Inc = @(); Text = ((T "aucun format reconnu sur les pistes 0.0 et 0.1 ({0})") -f $best) }
    }
    $txt = (T "{0}/{1} secteurs sur les pistes 0.0 et 0.1") -f "$($pick.Found)", "$($pick.Total)"
    # FIX2 : les secteurs manquants de ces pistes portent le motif « secteur illisible » de gw dans la reference convertie ;
    # Compare-Images les signale comme non compares (et non plus « la comparaison signalera ces pistes »)
    if (@($pick.Inc).Count -gt 0) { $txt += ' ; ' + ((T "piste(s) {0} incomplète(s) : protection contre la copie probable, ces pistes ne peuvent pas être comparées au format {1}") -f ($pick.Inc -join ', '), $pick.Fmt) }
    return @{ Format = $pick.Fmt; Found = $pick.Found; Total = $pick.Total; Inc = $pick.Inc; Text = $txt }
}

function Get-FmtDetectInput($d) {
    # Entree de Select-DiskFormat d apres l etat de la detection en cours ($script:FmtDetect). FIX2 : sonde D5 en
    # restauration seulement (CanProbe), step=2 dans la geometrie du champ Pistes (Step2)
    return @{ D0 = $d.D0; D2 = $d.D2; AmigaFmt = $d.AmigaFmt; HD = $d.HD; Tracks = $d.Tracks; Crit = $d.Crit; Boot = $d.BootBytes; BootDone = $d.BootDone
              CanProbe = ($d.Owner -eq 'restore'); ProbeDone = $d.ProbeDone; ProbeData = $d.ProbeData; ProbeTracks = $d.ProbeTracks
              Step2 = [bool](":$($d.Extras)" -match ':\s*step\s*=\s*2\s*(:|$)') }
}

function Invoke-DiskFormatDetect([string]$owner, [string]$extras = '') {
    # Detection du format de la disquette inseree (A1 § 3.3), pour la restauration ($owner 'restore') ou la comparaison
    # ('compare'). D0 : une seule lecture physique, ibm.scan --raw sur les pistes 0.0 et 0.1, 2 tours (un secteur a
    # cheval sur l index se decode sur deux tours), sans nouvel essai, avec les options de lecteur (Get-DriveReadArgs, D8)
    # et la geometrie du champ Pistes ($extras : step, hswap). Etapes suivantes dans $script:Chain, lancees par le
    # minuteur a la fin de gw (code 0) : Step-FmtDetectFlux, Step-FmtDetectAmiga, Step-FmtDetectBoot ou (FIX2)
    # Start-FmtDetectProbe et Step-FmtDetectProbe ; fin par
    # Complete-DiskFormatDetect. Erreur de gw : chemin commun de la chaine (restauration arretee, comparaison en echec)
    if (-not (Test-Path -LiteralPath $script:TempDir)) { New-Item -ItemType Directory -Force -Path $script:TempDir | Out-Null }
    $base = Join-Path $script:TempDir ('detect-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $script:FmtDetect = @{ Owner = $owner; Scp = "$base.scp"; Adf = "$base-amiga.adf"; BootImg = "$base-boot.img"; D0 = @(); D2 = @()
                           AmigaFmt = 'amiga.amigados'; HD = $false; Tracks = 0; Crit = 0; BootBytes = $null; BootDone = $false
                           Extras = $extras; ProbeScp = "$base-sonde.scp"; ProbeDone = $false; ProbeData = 0; ProbeTracks = 0 }
    $script:FmtDetectArgs = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @('--format=ibm.scan', '--raw', '--revs=2', '--retries=0', "--tracks=c=0:h=0-1$extras", "`"$($script:FmtDetect.Scp)`"")
    $script:GwCapture = New-Object System.Collections.Generic.List[string]
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw $script:FmtDetectArgs })
    $script:Chain.Enqueue({ Step-FmtDetectFlux })
    Invoke-NextChainStep
}

function Step-FmtDetectFlux {
    # Apres D0 : lignes de gw ; D1 : densite et pistes critiques du flux (jugees aux seuils Standard, comme un original
    # en copie de flux) ; puis D2 : decodage AmigaDOS hors ligne du meme flux (double ou haute densite selon D1)
    $d = $script:FmtDetect
    if (-not $d) { return }
    $d.D0 = @(if ($script:GwCapture) { @($script:GwCapture) } else { @() }); $script:GwCapture = $null
    if (-not (Test-Path -LiteralPath $d.Scp) -or (Get-Item -LiteralPath $d.Scp).Length -eq 0) {
        Complete-DiskFormatDetect (New-DiskFormatResult 'nofile' '' 'stop' (T 'la lecture n''a produit aucun fichier (disquette absente ou lecteur incorrect ?)') (T 'pistes 0.0 et 0.1') (T 'aucun flux lu'))
        return
    }
    if ($script:ScpStatsOk) {
        try { $d.HD = [bool](Test-ScpHighDensity $d.Scp) } catch { $d.HD = $false }
        try {
            $t = Read-ScpFile $d.Scp
            foreach ($tn in @($t.Keys)) {
                $mm = Get-TrackMetrics $t[$tn]; $d.Tracks++
                $lv = if ($mm.Bad) { 2 } else { Get-HealthLevel $mm.Ooc $mm.Dr $mm.Stab $mm.J $script:JitterStdOk $script:JitterStdWatch }
                if ($lv -ge 2) { $d.Crit++ }
            }
        } catch { }
    }
    $d.AmigaFmt = $(if ($d.HD) { 'amiga.amigados_hd' } else { 'amiga.amigados' })
    $script:FmtDetectArgs = @('convert', "--format=$($d.AmigaFmt)", '--tracks=c=0:h=0-1', "`"$($d.Scp)`"", "`"$($d.Adf)`"")
    $script:GwCapture = New-Object System.Collections.Generic.List[string]
    $script:Chain.Enqueue({ Start-Gw $script:FmtDetectArgs })
    $script:Chain.Enqueue({ Step-FmtDetectAmiga })
    Invoke-NextChainStep
}

function Step-FmtDetectAmiga {
    # Apres D2 : decision ; format IBM : D4, secteur 0 de la piste 0.0 decode hors ligne avec le format retenu (FIX2 :
    # BootFmt ; 9, 10, 11 et 18 secteurs) ; piste 0 vierge en restauration double densite : D5 (FIX2)
    $d = $script:FmtDetect
    if (-not $d) { return }
    $d.D2 = @(if ($script:GwCapture) { @($script:GwCapture) } else { @() }); $script:GwCapture = $null
    $res = Select-DiskFormat (Get-FmtDetectInput $d)
    if ($res.NeedProbe) { Start-FmtDetectProbe; return }
    if (-not $res.NeedBoot) { Complete-DiskFormatDetect $res; return }
    $script:FmtDetectArgs = @('convert', "--format=$($res.BootFmt)", '--tracks=c=0:h=0', "`"$($d.Scp)`"", "`"$($d.BootImg)`"")
    $script:Chain.Enqueue({ Start-Gw $script:FmtDetectArgs })
    $script:Chain.Enqueue({ Step-FmtDetectBoot })
    Invoke-NextChainStep
}

function Start-FmtDetectProbe {
    # FIX2 (D5) : piste 0 sans donnee lisible en double densite (restauration) : lecture du flux de trois cylindres de plus
    # (1, 40 et 79, 2 tours, options et geometrie du lecteur comme D0) avant de conclure a une disquette vierge : une piste
    # 0 non formatee est une protection (Lemmings disque 2 d apres l IPF SPS)
    $d = $script:FmtDetect
    if (-not $d) { return }
    $script:FmtDetectArgs = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @('--revs=2', "--tracks=c=1,40,79:h=0-1$($d.Extras)", "`"$($d.ProbeScp)`"")
    $script:Chain.Enqueue({ Start-Gw $script:FmtDetectArgs })
    $script:Chain.Enqueue({ Step-FmtDetectProbe })
    Invoke-NextChainStep
}

function Step-FmtDetectProbe {
    # Apres D5 : pistes avec des donnees (ni vierges ni critiques aux seuils Standard, comme D1), puis decision
    $d = $script:FmtDetect
    if (-not $d) { return }
    $d.ProbeDone = $true
    if ((Test-Path -LiteralPath $d.ProbeScp) -and $script:ScpStatsOk) {
        try {
            $t = Read-ScpFile $d.ProbeScp
            foreach ($tn in @($t.Keys)) {
                $mm = Get-TrackMetrics $t[$tn]; $d.ProbeTracks++
                $lv = if ($mm.Bad) { 2 } else { Get-HealthLevel $mm.Ooc $mm.Dr $mm.Stab $mm.J $script:JitterStdOk $script:JitterStdWatch }
                if ($lv -lt 2) { $d.ProbeData++ }
            }
        } catch { }
    }
    Complete-DiskFormatDetect (Select-DiskFormat (Get-FmtDetectInput $d))
}

function Step-FmtDetectBoot {
    # Apres D4 : secteur de demarrage (absent ou non lu : aucun critere positif Atari ST, format PC), puis decision
    $d = $script:FmtDetect
    if (-not $d) { return }
    $d.BootDone = $true
    if (Test-Path -LiteralPath $d.BootImg) { $d.BootBytes = Read-FileHead $d.BootImg 512 }
    Complete-DiskFormatDetect (Select-DiskFormat (Get-FmtDetectInput $d))
}

function Complete-DiskFormatDetect($res) {
    # Fin de la detection : ligne de journal (scores, decision), puis suite de la restauration ou de la comparaison
    $d = $script:FmtDetect; $script:FmtDetect = $null
    if (-not $d) { return }
    if ($res.Log) { Append-Log $res.Log }
    switch ($d.Owner) {
        'restore' { Complete-RestoreDetection $res }
        'compare' { Complete-CompareDetect $res }
    }
}
