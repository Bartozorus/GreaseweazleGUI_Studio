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
        # 12.10 (lot 1, B1) : octet d encodage (offset 11, table EncodingType de hfe.py) : FM 0x02, 0x03, 0x04, 0x0E, 0x14 ;
        # GCR 0x06 a 0x09 (Apple II), 0x10 (Macintosh), 0x12 (C64), 0x13 (Victor 9000) ; codage propre 0x0F (M2FM du DEC
        # RX02) ; MFM 0x00, 0x01, 0x05, 0x0C, 0x0D ; 0xFF (valeur que gw ecrit par defaut) et autres : inconnu (''), MFM
        # suppose comme en 12.8 (decision B-D2). FM et Apple II sont enregistres a double debit (convention HFE, emit_track
        # de hfe.py) : DoubleRate, cellule physique double de celle des bits du fichier. MFM et inconnu : cellule et bits
        # inchanges (densite du motif de Get-PatternBits)
        $eb = [int]$h[11]
        $enc = if (@(2, 3, 4, 14, 20) -contains $eb) { 'fm' } elseif (@(6, 7, 8, 9, 16, 18, 19) -contains $eb) { 'gcr' } elseif ($eb -eq 15) { 'other' } elseif (@(0, 1, 5, 12, 13) -contains $eb) { 'mfm' } else { '' }
        $dbl = ($enc -eq 'fm' -or ($eb -ge 6 -and $eb -le 9))
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
    $cell = [double](200000000.0 / $bits)
    if ($dbl) { $cell *= 2; $bits = [int64][math]::Floor($bits / 2) }   # 12.10 (lot 1, B1) : double debit (FM, Apple II)
    return @{ CellNs = $cell; Bits = $bits; Tracks = -1; DosTracks = -1; Source = $src; EncByte = $eb; Enc = $enc; DoubleRate = $dbl }
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

function Get-DriveFamilyCurves([string]$drive, [string]$family, [bool]$preferHeads) {
    # 12.10 : courbes d un lecteur du magasin (cle « lecteur », ou « source>cible » pour les courbes croisees) appliquees a
    # la famille, memes regles que Get-FamilyCurves : par tete si elles sont presentes et au moins aussi recentes que la
    # courbe commune, sinon la courbe commune ; tableau protege par la virgule (pas de @() autour de l appel)
    $h0 = Get-DriveCurve $drive "${family}_h0"; $h1 = Get-DriveCurve $drive "${family}_h1"; $one = Get-DriveCurve $drive $family
    if ($preferHeads -and $h0 -and $h1 -and $h0.Spec -and $h1.Spec -and (-not $one -or (Get-CurveDate $h0) -ge (Get-CurveDate $one))) { return ,@($h0, $h1) }
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
    # 12.10 : lecteur cible choisi dans l onglet Ecriture (Get-TargetDrive, 140) : courbes croisees « source>cible » de la
    # famille (Get-TargetCurves : par tete a jour en ecriture lente, sinon commune, pour les deux tetes) a la place des
    # courbes du lecteur ; sans courbe croisee : champs remplis comme sans lecteur cible, complement qui annonce le refus
    # de l ecriture (Test-TargetWriteAllowed, 140). Relecture de l etape 3 : famille haute densite (hd : pas de calibration
    # croisee) : champs remplis comme sans lecteur cible, complement $tn qui annonce le refus sans proposer la calibration
    # croisee ; ecriture rapide avec des courbes croisees par tete seulement : complement qui le dit (Get-TargetWriteInfo).
    # Finalisation 12.10 : courbes croisees dans les champs : aucun complement, la courbe croisee est nommee entre les
    # parentheses du libelle a la place du profil propre du lecteur source (Get-WProfileSpec, Get-TargetProfileText)
    $chkWPrecomp.Checked = $true
    $tgt = Get-TargetDrive
    # 12.10 (relecture de la RC) : refus du lecteur cible annonce en tete du libelle par Sync-WTargetHead, d apres le refus
    # de l ecriture elle-meme (Get-TargetWriteInfo, 140), et non plus par un complement rendu ici, qui pouvait annoncer un
    # refus qui n avait pas lieu (flux ecrit tel quel en profil force, case --precomp decochee) ; haute densite : champs et
    # complements comme sans lecteur cible
    if ($tgt -and @('std', 'long') -contains $fam) {
        $src = [string]$cmbDrive.Text
        $cvs = @(Get-TargetCurves $fam ([bool]$chkWSlow.Checked) $src $tgt)
        if ($cvs.Count -ge 2) { $txtWPrecomp.Text = [string]$cvs[0].Spec; $txtWPrecomp1.Text = [string]$cvs[1].Spec; return '' }
        if ($cvs.Count -eq 1) { $txtWPrecomp.Text = [string]$cvs[0].Spec; $txtWPrecomp1.Text = [string]$cvs[0].Spec; return '' }
        # sans courbe croisee : champs du profil de la famille, ecriture refusee (refus en tete du libelle : Sync-WTargetHead)
        $txtWPrecomp.Text = $spec; $txtWPrecomp1.Text = $spec
        return ''
    }
    if ($chkWSlow.Checked -and (Test-HeadCurvesCurrent $fam)) {
        $txtWPrecomp.Text = Get-HeadSpec $fam 0; $txtWPrecomp1.Text = Get-HeadSpec $fam 1
        return (T ' ; écriture lente : profils calibrés tête 0 et tête 1 appliqués')
    }
    $txtWPrecomp.Text = $spec; $txtWPrecomp1.Text = $spec
    if (-not $chkWSlow.Checked) { return '' }
    if ((Get-HeadSpec $fam 0) -and (Get-HeadSpec $fam 1)) { return (T ' ; écriture lente : courbes par tête antérieures au profil commun, profil commun pour les deux têtes') }
    return (T ' ; écriture lente : même profil pour les deux têtes (aucune calibration par tête pour cette famille)')
}

function Get-TargetProfileText([string]$fam) {
    # Finalisation 12.10 : courbes croisees que Set-PrecompFields met dans les champs pour le lecteur cible de l onglet
    # Ecriture (Get-TargetCurves, memes regles : par tete a jour en ecriture lente, sinon commune), nommees dans le libelle
    # du profil a la place du profil propre du lecteur source : sens, test, date (courbes par tete : une date si les deux
    # tetes ont la meme), calcul. Chaine vide sans lecteur cible, hors double densite ou sans courbe croisee. Texte court : le
    # libelle (lblWProfileInfo, 520 : 502 x 40 px, deux lignes, AutoSize faux) n a pas la place de la famille ni du calcul
    # conserve de Get-TargetCurvesText, qui restent au journal de l ecriture
    $tgt = Get-TargetDrive
    if (-not $tgt -or @('std', 'long') -notcontains $fam) { return '' }
    $src = [string]$cmbDrive.Text
    $cvs = @(Get-TargetCurves $fam ([bool]$chkWSlow.Checked) $src $tgt)
    if ($cvs.Count -eq 0) { return '' }
    $c0 = $cvs[0]
    $test = if ([string]$c0.Test -eq 'fine') { (T 'test fin') } else { (T 'test standard') }
    $calc = Get-CurveCalcText $c0 -Plain
    if ($cvs.Count -ge 2) {
        if ([string]$cvs[1].Date -eq [string]$c0.Date) { return ((T 'courbes croisées {0} → {1} par tête, {2}, {3}, calcul {4}') -f "$src", "$tgt", "$test", "$($c0.Date)", "$calc") }
        return ((T 'courbes croisées {0} → {1} par tête, {2}, tête 0 du {3}, tête 1 du {4}, calcul {5}') -f "$src", "$tgt", "$test", "$($c0.Date)", "$($cvs[1].Date)", "$calc")
    }
    if ($chkWSlow.Checked) { return ((T 'courbe croisée {0} → {1} pour les deux têtes, {2}, {3}, calcul {4}') -f "$src", "$tgt", "$test", "$($c0.Date)", "$calc") }
    return ((T 'courbe croisée {0} → {1}, {2}, {3}, calcul {4}') -f "$src", "$tgt", "$test", "$($c0.Date)", "$calc")
}

function Get-WProfileSpec([string]$spec, [string]$fam, [bool]$asIs = $false) {
    # Finalisation 12.10 : texte entre les parentheses du libelle du profil, apres Set-PrecompFields : courbes croisees du
    # lecteur cible quand les champs les portent (Get-TargetProfileText), sinon le profil $spec. $asIs : profil seul (image
    # a laquelle --precomp n est pas transmis : flux ecrit tel quel, FM, GCR ; le complement du libelle le dit)
    if (-not $asIs) { $t = Get-TargetProfileText $fam; if ($t) { return $t } }
    return $spec
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

function Set-WProfileText([string]$base, [string]$note) {
    # 12.8.1 (spec-1281 § D.4) : libelle du profil Auto double densite et son complement « facteur » (T-C12,
    # Get-WriteFactorNote), gardes separement : Update-WriteFactorNote refait le complement seul
    $script:WFactorNote = @{ Base = $base; Note = $note }
    $lblWProfileInfo.Text = $base + $note
}

function Get-WTargetHead([string]$path) {
    # 12.10 (relecture de la RC) : refus du lecteur cible que le libelle du profil annonce en tete : celui de l ecriture
    # elle-meme (Get-TargetWriteInfo, 140 : BlockKind), en texte court (deux lignes du libelle, 520 : 502 x 40 px, avec le
    # profil d origine de la famille), majuscule initiale, suivi du separateur du complement (« ; » precede d une espace en
    # francais) ; '' sans refus (meme lecteur, profil Manuel, --precomp decoche, image sans precompensation, courbe croisee)
    $ti = Get-TargetWriteInfo $path ([string]$cmbWFmt.Text) ([bool]$chkWSlow.Checked)
    $n = switch ([string]$ti.BlockKind) {
        'hd'   { (T " ; lecteur cible {0} : écriture refusée en haute densité (la calibration croisée n'existe qu'en double densité)") -f "$($ti.Tgt)" }
        'head' { (T ' ; courbes croisées {1} → {0} par tête : écriture rapide refusée (cochez « Écriture lente »)') -f "$($ti.Tgt)", "$($ti.Src)" }
        'none' { (T ' ; aucune courbe croisée {1} → {0} : écriture refusée (« Calibrer pour un lecteur cible… »)') -f "$($ti.Tgt)", "$($ti.Src)" }
        default { '' }
    }
    $n = [string]$n
    $core = $n.TrimStart(' ', ';')
    if (-not $core) { return '' }
    return $core.Substring(0, 1).ToUpper() + $core.Substring(1) + $n.Substring(0, $n.Length - $core.Length)
}

function Sync-WTargetHead([switch]$IfOwn) {
    # 12.10 (relecture de la RC) : refus en tete du libelle du profil accorde au refus reel de l ecriture pour l image du
    # libelle ($script:WProfilePath ; Get-WTargetHead) : en sortie d Update-PrecompForImage, et au changement de la case
    # « Precompensation (--precomp) » (520, -IfOwn : seulement si le libelle est celui du profil, $script:WProfileLabel ou
    # base et complement « facteur », et non un avis de la Bibliotheque, un bilan de calibration ou un texte restaure).
    # Ancienne tete retiree si le libelle la porte encore ($script:WTargetHead), nouvelle tete mise ; base du complement
    # « facteur » (Set-WProfileText, Update-WriteFactorNote) accordee de meme. Apres un profil calibre ou le detail d une
    # image analysee, un refus place en fin passait au-dela des deux lignes du libelle, cache par les points de suspension
    $txt = [string]$lblWProfileInfo.Text
    $n = $script:WFactorNote
    $fn = ($n -and $txt -eq ([string]$n.Base + [string]$n.Note))
    if ($IfOwn -and -not $fn -and $txt -ne [string]$script:WProfileLabel) { return }
    $want = ''
    try { $want = Get-WTargetHead ([string]$script:WProfilePath) } catch { $want = '' }
    $have = [string]$script:WTargetHead
    if ($have -and -not $txt.StartsWith($have, [System.StringComparison]::Ordinal)) { $have = '' }
    $script:WTargetHead = $want
    if ($want -ne $have) {
        if ($fn -and ([string]$n.Base).StartsWith($have, [System.StringComparison]::Ordinal)) { $n.Base = $want + ([string]$n.Base).Substring($have.Length) }
        $txt = $want + $txt.Substring($have.Length)
        $lblWProfileInfo.Text = $txt
    }
    $script:WProfileLabel = $txt
}

function Update-PrecompForImage([string]$path) {
    # 12.10 (relecture de la RC) : bouton « Courbe » (Update-CurveButton) recalcule en sortie (finally), apres le profil et la
    # case --precomp recochee par Set-PrecompFields (gestionnaire de la case inactif d ici la) ; avant : en entree, d apres la
    # case encore decochee (courbe propre du lecteur montree a la place de la courbe croisee ecrite)
    $script:WProfileHd = $false
    $script:WFactorNote = $null
    $script:WProfilePath = $path
    # 12.10 (relecture de la RC) : refus du lecteur cible en tete du libelle a chaque sortie (finally : Sync-WTargetHead ;
    # corps garde a son retrait) ; gestionnaire de la case --precomp (recochee par Set-PrecompFields) inactif d ici la.
    # $script:WTargetHead n est pas remis a vide : un corps interrompu avant le nouveau libelle laisse l ancien avec sa tete,
    # que Sync-WTargetHead remplace au lieu d en ajouter une seconde ; un libelle refait ne la porte pas (tete ignoree)
    $script:WProfileBuilding = $true
    try {
    $mode = $cmbWProfile.Text
    if ($mode -eq (T 'Manuel')) { $lblWProfileInfo.Text = (T 'Profil manuel : --precomp non modifié.'); return }
    # 12.10 (lot 1, B1) : image FM, GCR ou a codage propre (Get-ImageEncoding) : --precomp n est pas transmis
    # (Start-ImageWrite), en profil Auto comme en profil force (decision B-D1) ; champs remplis comme avant (ils servent si
    # le format change), complement $nmNote a la place de celui de Set-PrecompFields
    $ie = if ($path -and (Test-Path -LiteralPath $path)) { Get-ImageEncoding $path $cmbWFmt.Text } else { $null }
    $nmNote = if ($ie -and $ie.NonMfm) { (T " ; image en codage {0} ({1}) : --precomp n'est pas transmis") -f "$($ie.Name)", "$($ie.Src)" } else { '' }
    # 12.10 (relecture de la RC) : $fxNote (image flux ecrite telle quelle, voir plus bas) calcule ici pour le profil force
    # aussi : son libelle ne nomme plus un profil ou une courbe croisee que gw ne recoit pas
    $fxNote = if ($path -and (Test-Path -LiteralPath $path) -and (Test-RawFluxWrite $path $cmbWFmt.Text)) { (T " ; image flux écrite telle quelle (sans --format) : gw n'applique pas la précompensation, --precomp n'est pas transmis") } else { '' }
    # Finalisation 12.10 : parentheses du libelle : courbes croisees du lecteur cible quand les champs les portent (Get-WProfileSpec)
    if ($mode -eq (T 'Standard 2 us'))      { $x = Set-PrecompFields $script:PrecompStd 'std';   $lblWProfileInfo.Text = ((T "Profil forcé : standard 2 us ({0})") -f (Get-WProfileSpec $script:PrecompStd 'std' ([bool]($nmNote -or $fxNote)))) + $(if ($nmNote) { $nmNote } elseif ($fxNote) { $fxNote } else { $x }); return }
    if ($mode -eq (T 'Long track 1,89 us')) { $x = Set-PrecompFields $script:PrecompLong 'long'; $lblWProfileInfo.Text = ((T "Profil forcé : long track ({0})") -f (Get-WProfileSpec $script:PrecompLong 'long' ([bool]($nmNote -or $fxNote)))) + $(if ($nmNote) { $nmNote } elseif ($fxNote) { $fxNote } else { $x }); return }
    # Auto
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { $lblWProfileInfo.Text = ''; return }
    if ($nmNote) {
        $x = Set-PrecompFields $script:PrecompStd 'std'
        $lblWProfileInfo.Text = (T "Auto : image en codage {0} ({1}) -> sans précompensation (--precomp n'est pas transmis)") -f "$($ie.Name)", "$($ie.Src)"
        Append-Log ((T "Profil precomp : {0}") -f "$($lblWProfileInfo.Text)")
        return
    }
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    # 12.8 (S3-FLUX, decision 2 du 21/10/2026) : image flux sans --format (Test-RawFluxWrite) : gw n y applique pas la
    # precompensation ; champs remplis comme avant (ils servent si un format est choisi), mais le libelle ne les dit plus
    # « appliques » : complement $fxNote a la place de celui de Set-PrecompFields
    # ($fxNote : calcule en tete de la fonction, profil force compris)
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
            # 12.10 (relecture de la RC) : lecteur cible : refus de l ecriture (Get-TargetWriteInfo, 140, refuse toute image
            # haute densite en Auto) annonce en tete du libelle comme pour la haute densite calibrable (Sync-WTargetHead)
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
        if (Test-FluxImage $path) { $lblWProfileInfo.Text = ((T "Auto : image flux ({0}) -> standard 2 us ({1})") -f "$ext", (Get-WProfileSpec $script:PrecompStd 'std' ([bool]$fxNote))) + $(if ($fxNote) { $fxNote } else { $x }); return }
        # 12.8.1 : facteur de precompensation different de 1 (mesure du lecteur) : complement
        Set-WProfileText (((T "Auto : image secteur ({0}) -> standard 2 us ({1})") -f "$ext", (Get-WProfileSpec $script:PrecompStd 'std')) + $x) (Get-WriteFactorNote $path)
        return
    }
    $long = $info.CellNs -lt $script:PrecompThresholdNs
    $x = if ($long) { Set-PrecompFields $script:PrecompLong 'long' } else { Set-PrecompFields $script:PrecompStd 'std' }
    if ($fxNote) { $x = $fxNote }
    # Finalisation 12.10 : courbes croisees du lecteur cible dans les champs : elles sont nommees dans les parentheses, le
    # detail de la detection est reduit a l extension (largeur du libelle : deux lignes, anglais compris ; la famille reste)
    $sp = if ($fxNote) { '' } else { Get-TargetProfileText $(if ($long) { 'long' } else { 'std' }) }
    if ($sp) { $head = (T "Auto : image {0} -> ") -f "$ext" }
    else {
        $detail = ((T "cellule {0} ns, {1} bits/piste") -f "$([math]::Round($info.CellNs,0))", "$($info.Bits)")
        if ($info.DosTracks -ge 0 -and $info.Tracks -gt 0) { $detail += ((T ", {0}/{1} pistes DOS") -f "$($info.DosTracks)", "$($info.Tracks)") }
        $head = (T "Auto : {0} : {1} -> ") -f "$($info.Source)", "$detail"
        $sp = if ($long) { $script:PrecompLong } else { $script:PrecompStd }
    }
    Set-WProfileText ($head + $(if ($long) { ((T "LONG TRACK ({0})") -f "$sp") } else { ((T "standard 2 us ({0})") -f "$sp") }) + $x) (Get-WriteFactorNote $path)
    Append-Log ((T "Profil precomp : {0}") -f "$($lblWProfileInfo.Text)")
    # 12.10 (relecture de la RC) : case de la mesure accordee a l effet du lecteur cible sur cette image (Update-WLevelUi, 140)
    } finally { $script:WProfileBuilding = $false; Sync-WTargetHead; Update-WLevelUi; Update-CurveButton $path }
}
