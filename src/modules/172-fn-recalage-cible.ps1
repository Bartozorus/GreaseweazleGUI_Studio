# --- 12.11 rc8 (R17) : recalage de la courbe croisee par une relecture du lecteur cible ---------------------------------
# Les ecritures pour un lecteur cible (regle rc6 : courbe ecrite = min(k x X, X + (k - 1) x Sp), X courbe croisee, Sp courbe
# propre du lecteur qui ecrit, k facteur de la disquette ; correction par zones rc7) sont relues par le lecteur cible avec
# une asymetrie signee legerement positive : quelques ns de trop, que le lecteur qui ecrit ne peut pas voir. Le recalage est
# un decalage constant par tete, en ns, ajoute a la courbe ecrite apres la regle (Get-TargetTransferSpec, 140), appris sur
# la relecture par le lecteur cible d une disquette ecrite pour lui (mesure de l onglet Qualite : Invoke-AlignAnalysis,
# 190). Il est range a cote de la courbe croisee, qu il ne modifie jamais, et lie a la date de la courbe croisee employee
# (XDate) et au calcul de calibration (Calc) : une nouvelle calibration croisee, ou un autre calcul, le rend sans effet et
# la relecture suivante repart de zero. Magasins (etat : 560 ; configuration : blocs write.targetRecal et
# write.lastTargetWrite, 120) : $script:TargetRecal, « source>cible|famille_hN » (N : tete physique du lecteur qui ecrit,
# celle de la courbe croisee) -> @{ Ns ; N ; Items ; XDate ; XKey ; Calc ; At } ; $script:LastTargetWrites, « source>cible » ->
# memoire de la derniere ecriture pour ce lecteur cible (New-TargetWriteMemory). Constantes : 040 (TargetRecal*).
# Validation (hors depot, quatre ecritures bien reglees, une paire de lecteurs, double densite standard) : decalage constant
# en ns, plafond 8 ns ; jamais appris ni applique quand le facteur k de l ecriture n a pas ete mesure. 12.11, decision de
# l utilisateur pour la version finale : part de l ecart moyen retenue f = n / (n + p), p = 1/3 (TargetRecalFirstShare,
# 040 : les trois quarts des la premiere ecriture relue ; rc8 : f = n / (n + 1)) ; seule une ecriture dont le facteur k a
# ete mesure sur la disquette elle-meme (origine 'mesure') apprend le recalage a sa relecture (Test-TargetRecalKLearn a
# l ecriture, Get-TargetWriteKLearnWhy a la relecture) ; un facteur repris des mesures du lecteur pour la marque
# ('lecteur') applique le recalage sans l apprendre (Test-TargetRecalKMeasured), sa relecture n est pas proposee et le
# journal dit pourquoi. Les ecritures deja relues du magasin (Items) ne portent pas l origine de leur k : elles restent.

# 12.12 (essais du 25 et du 26/11/2026) : un recalage par regime d ecriture. La regle ecrit min(k x X, X + (k - 1) x Sp) :
# pour k <= 1 la courbe croisee est multipliee par k, pour k > 1 la hausse (k - 1) x Sp est ajoutee en ns. Les relectures
# par le lecteur cible donnent des estimations de signes opposes selon ce regime (quelques ns de trop pour k <= 1,
# quelques ns de moins pour k > 1, meme tete, meme courbe croisee) : une seule moyenne par tete les melangeait et
# decalait les ecritures de l autre regime. Entree du regime k > 1 : meme cle suivie de « + » (Test-TargetRecalUp ;
# une 12.11 l ignore) ; entree sans « + » : regime k <= 1, inchangee. Chaque ecriture relue garde son k (Items, K) ;
# une ecriture relue par une 12.11 (sans K) dont la mesure sur l image donnait k > 1 est reclassee au chargement
# (Import-TargetRecal, Get-TargetRecalItemK). Hypothese tiree de cinq ecritures relues, a confirmer sur d autres

function Test-TargetRecalUp([double]$k) {
    # Regime d ecriture d une tete : vrai pour un facteur de la disquette au-dessus de 1 (hausse ajoutee en ns), sur k
    # arrondi a 0,001 comme dans la memoire de l ecriture (New-TargetWriteMemory, K) : meme regime au lancement de
    # l ecriture (Get-TargetRecalPlan) et a sa relecture (Get-TargetRecalUpdate)
    return ([math]::Round($k, 3) -gt 1.0)
}

function Get-TargetRecalK($wf, [int]$h, [bool]$slow) {
    # Facteur de la disquette d une tete physique d une ecriture (Get-WriteFactorPlan, 140) : K de la tete en ecriture
    # lente, facteur moyen des deux tetes (FMean) en ecriture rapide ; 1 sans lui (plan partiel)
    $kv = 1.0
    if ($slow) { if ($wf -and $wf.K -and $null -ne $wf.K[$h]) { $kv = [double]$wf.K[$h] } } elseif ($wf -and $null -ne $wf.FMean) { $kv = [double]$wf.FMean }
    return $kv
}

function Get-TargetRecalKey([string]$src, [string]$tgt, [string]$fam, [int]$h, [bool]$up = $false) {
    # Cle du magasin $script:TargetRecal : « source>cible|famille_hN » (N : tete physique du lecteur qui ecrit), suivie de
    # « + » pour le regime k > 1 ($up, Test-TargetRecalUp)
    return "$src>$tgt|$($fam)_h$h$(if ($up) { '+' } else { '' })"
}

function Get-TargetRecalEntry([string]$src, [string]$tgt, [string]$fam, [int]$h, [bool]$up = $false) {
    # Entree brute du magasin pour un regime, sans condition ; $null sans elle
    if ($null -eq $script:TargetRecal) { return $null }
    return $script:TargetRecal[(Get-TargetRecalKey $src $tgt $fam $h $up)]
}

function Get-TargetRecalItemK([string]$drive, [string]$fam, [int]$h, [string]$writeId) {
    # Facteur k d une ecriture relue par une 12.11 (Items sans K), retrouve dans les mesures sur l image gardees
    # ($script:ContentMeasures) : mesure du lecteur qui a ecrit, de cette famille et de cette tete, terminee dans les
    # TargetRecalItemKMin minutes qui precedent le lancement de l ecriture (identifiant « W » + date du lancement, que la
    # mesure precede de moins d une minute) ; la plus proche. $null sans mesure correspondante ou identifiant illisible
    $wd = [datetime]::MinValue
    if (-not $writeId -or -not [datetime]::TryParseExact($writeId.TrimStart('W'), 'yyyyMMddHHmmss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$wd)) { return $null }
    $best = $null; $lim = [double]$script:TargetRecalItemKMin; $ba = [double]::MaxValue
    foreach ($r in @($script:ContentMeasures)) {
        if ($null -eq $r -or [string]$r.Drive -cne $drive -or [string]$r.Family -ne $fam -or $null -eq $r.Head -or [int]$r.Head -ne $h) { continue }
        $k = [double]$r.K
        if ([double]::IsNaN($k) -or [double]::IsInfinity($k)) { continue }
        $d = Get-CurveDate $r
        if ($d -eq [datetime]::MinValue) { continue }
        # Date de la mesure a la minute : le lancement de l ecriture peut tomber jusqu a 59 s « avant » elle
        $dm = ($wd - $d).TotalMinutes; $ad = [math]::Abs($dm)
        if ($dm -gt -1 -and $dm -lt $lim -and $ad -lt $ba) { $best = $k; $ba = $ad }
    }
    return $best
}

function Test-TargetRecalValid($e, [string]$xDate) {
    # Entree applicable a une ecriture faite avec une courbe croisee de date $xDate : meme date que la courbe qui a servi a
    # l apprendre, calcul de calibration courant, au moins une ecriture relue
    return ($null -ne $e -and [string]$e.XDate -ceq $xDate -and [string]$e.Calc -ceq [string]$script:CalibCalc -and @($e.Items | Where-Object { $_ }).Count -gt 0)
}

function Get-TargetRecalNs($items) {
    # Recalage d une tete : borne(somme des estimations / (n + p), +/- TargetRecalCapNs), une decimale ; n : ecritures relues
    # (TargetRecalMaxItems au plus) ; p = (1 - F) / F, F = TargetRecalFirstShare (040). Revient a f = n / (n + p) de la
    # moyenne des estimations ; F = 0,75 (12.11, decision de l utilisateur pour la version finale ; rc8 : p = 1) : 0,75 apres
    # une relecture, puis 6/7, 0,9, 12/13 et 15/16 ; moyenne retrecie vers 0, sans integrateur, donc sans oscillation.
    # Calcule sous la forme egale somme x F / (n x F + 1 - F), exacte pour F = 0,75 (n x 0,75 + 0,25 sans erreur
    # d arrondi : une moitie exacte comme -3,75 reste exacte pour l arrondi au pair de [math]::Round, -3,8). F hors de
    # ]0 ; 1] : 0 (aucun recalage). Aucune ecriture : 0. Seul calcul du recalage : cumul apres une relecture
    # (Get-TargetRecalUpdate) et chargement de la configuration (Import-TargetRecal : une entree enregistree par une version
    # anterieure suit la regle courante)
    $it = @($items | Where-Object { $_ })
    if ($it.Count -eq 0) { return 0.0 }
    $f = [double]$script:TargetRecalFirstShare
    if (-not ($f -gt 0 -and $f -le 1)) { return 0.0 }
    $s = 0.0
    foreach ($x in $it) { $s += [double]$x.Est }
    $cap = [double]$script:TargetRecalCapNs
    return [double][math]::Round([math]::Max(-$cap, [math]::Min($cap, $s * $f / ($it.Count * $f + (1 - $f)))), 1)
}

function ConvertTo-RecalDate([string]$s) {
    # Date d une memoire ou d un recalage (yyyy-MM-dd HH:mm:ss, culture invariante) ; MinValue si elle est vide ou
    # illisible (meme forme que les fiches des lecteurs, sans dependre du module 112)
    $d = [datetime]::MinValue
    if ($s -and [datetime]::TryParseExact($s, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$d)) { return $d }
    return [datetime]::MinValue
}

function Get-TargetRecalReads($e) {
    # Relectures acceptees d une entree (somme des relectures de ses ecritures) et date de la derniere : @{ N ; Last }
    $n = 0; $last = ''
    foreach ($x in @($e.Items | Where-Object { $_ })) { $n += [math]::Max(1, [int]$x.NR) }
    if ($e -and $e.At) { $last = [string]$e.At }
    return @{ N = $n; Last = $last }
}

function Test-TargetRecalKMeasured($wf, [int]$h, [bool]$slow) {
    # APPLICATION du recalage (Get-TargetRecalPlan) : facteur k de la disquette mesure pour la tete physique $h ($wf :
    # Get-WriteFactorPlan, 140) : facteur applique, origine mesure sur cette disquette ('mesure') ou mesures du lecteur pour
    # la marque ('lecteur' : derniere, ou mediane des 3 dernieres) ; 'defaut' (k = 1, aucune mesure) : non. Ecriture
    # rapide : facteur moyen des deux tetes, mesure si les deux le sont. L apprentissage est plus strict :
    # Test-TargetRecalKLearn
    if (-not $wf -or -not $wf.Apply -or -not $wf.Src) { return $false }
    $hs = if ($slow) { @($h) } else { @(0, 1) }
    foreach ($q in $hs) {
        $s = [string]$wf.Src[$q]
        if (-not $s) { $s = [string]$wf.Src["$q"] }
        if (-not $s -or $s -eq 'defaut') { return $false }
    }
    return $true
}

function Test-TargetRecalKLearn($wf, [int]$h, [bool]$slow) {
    # APPRENTISSAGE du recalage (12.11, decision de l utilisateur pour la version finale : mesure obligatoire) : ecriture
    # dont la relecture par le lecteur cible pourra recaler la courbe croisee pour la tete physique $h : facteur applique
    # (Test-TargetRecalKMeasured) et mesure sur cette disquette elle-meme (origine 'mesure'), pour cette tete en ecriture
    # lente, pour les deux tetes en ecriture rapide (facteur moyen). Facteur repris des mesures du lecteur pour la marque
    # ('lecteur') : applique, jamais appris ; 'defaut' : ni l un ni l autre. Garde dans la memoire de l ecriture (KLearn,
    # New-TargetWriteMemory), lue a la relecture par Get-TargetWriteKLearnWhy
    if (-not (Test-TargetRecalKMeasured $wf $h $slow)) { return $false }
    $hs = if ($slow) { @($h) } else { @(0, 1) }
    foreach ($q in $hs) {
        $s = [string]$wf.Src[$q]
        if (-not $s) { $s = [string]$wf.Src["$q"] }
        if ($s -cne 'mesure') { return $false }
    }
    return $true
}

function Get-TargetWriteKLearnWhy($mem, [string]$lk) {
    # Raison, pour le journal, pour laquelle la tete logique $lk d une ecriture gardee en memoire (New-TargetWriteMemory) ne
    # peut pas recaler la courbe croisee ; '' quand elle le peut. Origine du facteur de cette tete (KSrc) : 'lecteur' (mesures
    # du lecteur pour la marque), 'defaut' (k = 1) ou absente et inconnue (prudence) : refus. Origine 'mesure' : memoire de la
    # version finale, KLearn et KMeasured (Test-TargetRecalKLearn a l ecriture : en ecriture rapide, l autre tete compte
    # aussi) ; memoire de la rc8, sans KLearn : KMeasured, et en ecriture rapide l origine 'mesure' des deux tetes ecrites
    # (une seule tete ecrite : origine de l autre inconnue, refus). Relecture : le fait seul, sans conclusion, comme les
    # raisons voisines (la fenetre de confirmation liste aussi la raison d une tete exclue quand l autre recale)
    $hm = $null
    if ($mem -and $mem.H) { $hm = $mem.H[$lk] }
    $ks = if ($hm) { [string]$hm.KSrc } else { '' }
    if ($ks -ceq 'lecteur') { return ((T 'tête {0} : facteur de la disquette repris des mesures du lecteur pour la marque, pas mesuré sur cette disquette') -f $lk) }
    if ($ks -ceq 'defaut') { return ((T "tête {0} : facteur de la disquette non mesuré à l'écriture (k = 1 par défaut)") -f $lk) }
    $unk = (T 'tête {0} : origine du facteur de la disquette inconnue') -f $lk
    if ($ks -cne 'mesure') { return $unk }
    $fast = (T "tête {0} : écriture rapide avec le facteur moyen des deux têtes, dont une n'a pas été mesurée sur cette disquette") -f $lk
    $km = ($hm.KMeasured -eq $true)
    if ($null -ne $hm.KLearn) {
        if ($hm.KLearn -eq $true -and $km) { return '' }
        if (-not $mem.Slow) { return $fast }
        return $unk
    }
    if ($mem.Slow) { if ($km) { return '' } else { return $unk } }
    # Memoire de la rc8, ecriture rapide : KMeasured faux avec cette tete 'mesure' : l autre etait a k = 1
    if (-not $km) { return $fast }
    foreach ($q in '0', '1') {
        $x = $mem.H[$q]
        if (-not $x) { return $unk }
        if ([string]$x.KSrc -cne 'mesure') { return $fast }
    }
    return ''
}

function Get-TargetWriteNoLearn($mem) {
    # Tetes logiques ecrites d une memoire (New-TargetWriteMemory) qui ne peuvent pas recaler la courbe croisee
    # (Get-TargetWriteKLearnWhy), triees : Heads = @(@{ Lk ; Phys (tete physique qui l a ecrite) ; Why }) ; All : aucune
    # tete ecrite ne le peut (fin de l ecriture : ligne sans promesse ; relecture : refus avec ces raisons, quelle que soit
    # la couverture de la mesure)
    $out = @(); $n = 0
    if ($mem -and $mem.H) {
        foreach ($lk in @($mem.H.Keys | ForEach-Object { [string]$_ } | Sort-Object)) {
            $n++
            $w = Get-TargetWriteKLearnWhy $mem $lk
            if ($w) { $out += ,@{ Lk = $lk; Phys = [int]$mem.H[$lk].Phys; Why = $w } }
        }
    }
    return @{ Heads = $out; All = ($n -gt 0 -and $out.Count -eq $n) }
}

function Get-TargetWriteLearnHow($wf, [bool]$slow, [string]$img) {
    # Consigne de la ligne de fin d une ecriture pour un lecteur cible dont aucune tete ne peut recaler la courbe croisee
    # (Complete-TargetWriteMemory), decidee au lancement (New-TargetWriteMemory) d apres l onglet Ecriture, avec les gardes
    # de Get-WriteFactorHint (140) pour ne jamais demander ce qui est deja fait ou sans effet. Rend un code :
    #  - 'mesure' : une mesure sur l image a precede l ecriture (Get-WriteFactorPlan, Next) sans determiner le facteur ;
    #  - 'sans' : « Ecrire sans mesure » choisi dans la fenetre de la mesure ;
    #  sinon, seulement si la mesure sur l image est possible pour cette image (Get-LevelWriteSkip, Test-ContentMeasurable) :
    #  - 'quickslow', 'quickfast' : « Test rapide » (mesure au motif, case cochee et verrouillee) ;
    #  - 'fast' : ecriture rapide, jamais mesuree ; 'slow' : case « Mesurer la disquette » decochee ;
    #  - 'mode' : case cochee, liste « Mesure » autre que sur l image (Get-LevelBeforeWriteKind).
    # '' : aucune consigne (facteur non applique, restauration, image non mesurable sur son contenu, ou mesure demandee qui
    # n a pas eu lieu pour une autre raison)
    if (-not $wf -or -not $wf.Apply -or $script:Restore) { return '' }
    $nx = [string]$wf.Next
    if ($nx -ceq 'mesure' -or $nx -ceq 'sans') { return $nx }
    try {
        $fmt = [string]$cmbWFmt.Text
        if (Get-LevelWriteSkip $img $fmt ([string]$txtWTracks.Text)) { return '' }
        if (-not (Test-ContentMeasurable $img $fmt).Ok) { return '' }
    } catch { return '' }
    if ($cmbWCalMode.SelectedIndex -eq 2) { if ($slow) { return 'quickslow' } else { return 'quickfast' } }
    if (-not $slow) { return 'fast' }
    if (-not (Test-WriteLevelWanted 'slow')) { return 'slow' }
    if ([string](Get-LevelBeforeWriteKind 'slow' $false $true) -cne 'content') { return 'mode' }
    return ''
}

function Get-TargetWriteLearnHowText([string]$how) {
    # Phrase de la consigne (Get-TargetWriteLearnHow) ajoutee a la ligne de fin d ecriture ; '' sans consigne
    if ($how -ceq 'mesure') { return (T "La mesure sur l'image faite avant cette écriture n'a pas déterminé ce facteur (voir ses lignes dans le journal) : une écriture recalera cette courbe quand cette mesure le déterminera.") }
    $x = Get-TargetWriteHowPhrase $how
    if (-not $x) { return '' }
    return ((T "Pour qu'une écriture recale cette courbe, {0}.") -f $x)
}

function Get-TargetWriteHowPhrase([string]$how) {
    # Geste a faire pour mesurer la disquette sur l image avant une ecriture, d apres un code de Get-TargetWriteLearnHow
    # ('sans', 'slow', 'fast', 'mode', 'quickslow', 'quickfast') ; '' pour 'mesure', '' ou un code inconnu. Lue par la
    # ligne de fin d ecriture (Get-TargetWriteLearnHowText) et, 12.11 (version finale), par le conseil des zones qui
    # couvrent presque toute une tete (Get-WriteZoneHeadAdvice, 170)
    switch -CaseSensitive ($how) {
        'sans' { return (T "mesurez la disquette au lieu de choisir « Écrire sans mesure »") }
        'slow' { return (T "cochez « Mesurer la disquette avant l'écriture lente », avec la mesure « sur l'image à écrire »") }
        'fast' { return (T "écrivez l'image en écriture lente, avec « Mesurer la disquette avant l'écriture lente » cochée et la mesure « sur l'image à écrire »") }
        'mode' { return (T "choisissez la mesure « sur l'image à écrire »") }
        'quickslow' { return (T "choisissez le test standard ou fin dans « Calibration précomp », avec « Mesurer la disquette avant l'écriture lente » cochée et la mesure « sur l'image à écrire »") }
        'quickfast' { return (T "écrivez l'image en écriture lente, avec le test standard ou fin dans « Calibration précomp », « Mesurer la disquette avant l'écriture lente » cochée et la mesure « sur l'image à écrire »") }
    }
    return ''
}

function Get-TargetZoneAdvice($wf, [bool]$slow, [string]$userTs, [string]$img) {
    # 12.11 (version finale) : ce que peut demander le conseil des zones qui couvrent presque toute une tete
    # (Get-WriteZoneHeadAdvice, 170), decide au lancement d une ecriture pour un lecteur cible avec correction par zones
    # (Start-ImageWrite, 140 : Rep.ZoneAdvice), d apres l onglet a ce moment-la. KSrc : origine du facteur de la disquette
    # de chaque tete logique relue ('mesure', 'lecteur', 'defaut' ; $wf : Get-WriteFactorPlan, par tete physique ; hswap
    # compris, Get-WriteHeadSpecs) ; ecriture rapide, facteur moyen des deux tetes : 'mesure' seulement si les deux le sont
    # (comme Test-TargetRecalKLearn). How : consigne de mesure de Get-TargetWriteLearnHow (jamais ce qui est deja fait ou
    # sans effet ; '' : aucune, restauration ou image non mesurable par exemple). Relecture de la version finale : KSrc est
    # une precaution ; aujourd hui une origine 'mesure' implique How 'mesure' (facteur mesure sur l image juste avant
    # l ecriture, Next), et le texte du conseil ne depend que de How
    $s = @{}
    foreach ($p in 0, 1) { $v = ''; if ($wf -and $wf.Src) { $v = [string]$wf.Src[$p]; if (-not $v) { $v = [string]$wf.Src["$p"] } }; $s[$p] = $v }
    if (-not $slow) {
        $m = if ($s[0] -ceq 'mesure' -and $s[1] -ceq 'mesure') { 'mesure' } elseif ($s[0] -ceq 'lecteur' -or $s[1] -ceq 'lecteur') { 'lecteur' } else { 'defaut' }
        $s[0] = $m; $s[1] = $m
    }
    return @{ KSrc = (Get-WriteHeadSpecs $userTs $s[0] $s[1]); How = [string](Get-TargetWriteLearnHow $wf $slow $img) }
}

function Get-TargetRecalPlan($tw, $wf, $xc, [bool]$slow) {
    # Recalage a passer a Get-TargetTransferSpec pour chaque tete physique d une ecriture pour un lecteur cible
    # (Get-TargetTransferPlan, 140) : entree du magasin valable pour la courbe croisee employee (meme date, calcul courant :
    # Test-TargetRecalValid), facteur k mesure pour cette tete (Test-TargetRecalKMeasured : sur cette disquette ou par les
    # mesures du lecteur pour la marque ; la version finale n exige la mesure sur la disquette que pour l apprentissage,
    # Test-TargetRecalKLearn), hors profil Manuel ; sinon 0.
    # Ecriture rapide : moyenne des recalages des deux tetes (0 pour une tete sans entree valable), sur la courbe commune.
    # Rend @{ O = @{ 0 ; 1 } (ns) ; Used (au moins une entree appliquee) ; Text (segment du journal, '' sans entree) ;
    # XDate, XKey = @{ 0 ; 1 } (date et cle de la courbe croisee de chaque tete) ; Reads ; Last }
    $src = [string]$tw.Src; $tgt = [string]$tw.Tgt; $fam = [string]$tw.Fam
    $l = @($xc | Where-Object { $_ })
    $r = @{ O = @{ 0 = 0.0; 1 = 0.0 }; Used = $false; Text = ''; XDate = @{ 0 = ''; 1 = '' }; XKey = @{ 0 = ''; 1 = '' }; Reads = 0; Last = '' }
    if ($l.Count -eq 0) { return $r }
    $why = New-Object System.Collections.Generic.List[string]
    $any = $false; $ap = @{ 0 = $false; 1 = $false }; $upH = @{ 0 = $false; 1 = $false }
    $man = [bool](Test-ManualPrecomp)
    foreach ($h in 0, 1) {
        $cv = if ($slow) { $l[$(if ($h -eq 0) { 0 } else { $l.Count - 1 })] } else { $l[0] }
        $r.XDate[$h] = [string]$cv.Date
        $r.XKey[$h] = $(if ($null -ne $cv.Head) { "$($fam)_h$([int]$cv.Head)" } else { $fam })
        # 12.12 : entree du regime de cette ecriture (facteur de la disquette de cette tete au-dessus de 1 ou non) ; un
        # recalage appris pour l autre regime seulement n est pas applique, et le journal le dit
        $up = Test-TargetRecalUp (Get-TargetRecalK $wf $h $slow); $upH[$h] = $up
        $e = Get-TargetRecalEntry $src $tgt $fam $h $up
        if ($null -eq $e) {
            if ($null -ne (Get-TargetRecalEntry $src $tgt $fam $h (-not $up))) {
                $any = $true
                if (-not $man) { $why.Add($(if ($up) { (T 'tête {0} : recalage appris pour un facteur de la disquette de 1 ou moins, celui de cette écriture est au-dessus de 1') -f "$h" } else { (T 'tête {0} : recalage appris pour un facteur de la disquette au-dessus de 1, celui de cette écriture est de 1 ou moins') -f "$h" })) }
            }
            continue
        }
        $any = $true
        if ($man) { continue }
        if (-not (Test-TargetRecalValid $e $r.XDate[$h])) { $why.Add(((T 'tête {0} : courbe croisée recalibrée ou calcul changé depuis le recalage') -f "$h")); continue }
        if (-not (Test-TargetRecalKMeasured $wf $h $slow)) { $why.Add(((T 'tête {0} : facteur de la disquette non mesuré (k = 1 par défaut)') -f "$h")); continue }
        $r.O[$h] = [double]$e.Ns; $r.Used = $true; $ap[$h] = $true
        $rd = Get-TargetRecalReads $e
        if ([int]$rd.N -gt $r.Reads) { $r.Reads = [int]$rd.N }
        if ([string]$rd.Last -and (-not $r.Last -or (ConvertTo-RecalDate ([string]$rd.Last)) -gt (ConvertTo-RecalDate $r.Last))) { $r.Last = [string]$rd.Last }
    }
    if (-not $slow) { $m = ([double]$r.O[0] + [double]$r.O[1]) / 2; $r.O[0] = $m; $r.O[1] = $m }
    if (-not $any) { return $r }
    if ($man) { $r.Text = (T 'recalage du lecteur cible non appliqué : profil Manuel'); return $r }
    $sg = '+0.0;-0.0;0.0'
    $lastTxt = if ($r.Last) { (ConvertTo-RecalDate $r.Last).ToString('dd/MM/yyyy', [System.Globalization.CultureInfo]::InvariantCulture) } else { '?' }
    if ($r.Used) {
        $hv = @{}; foreach ($h in 0, 1) { $hv[$h] = $(if ($ap[$h] -and $upH[$h]) { (T '{0} ns (facteur au-dessus de 1)') -f (Format-UiNum ([double]$r.O[$h]) $sg) } elseif ($ap[$h]) { (T '{0} ns') -f (Format-UiNum ([double]$r.O[$h]) $sg) } else { (T 'aucun') }) }
        $vals = if ($slow) { (T 'tête 0 {0}, tête 1 {1}') -f $hv[0], $hv[1] } else { (T '{0} ns, moyenne des deux têtes') -f (Format-UiNum ([double]$r.O[0]) $sg) }
        $r.Text = (T 'recalage du lecteur cible : {0} ({1} relecture(s), dernière le {2}), arrondi au ns et ajouté à la courbe écrite') -f $vals, "$($r.Reads)", $lastTxt
        if ($why.Count -gt 0) { $r.Text += ' (' + ((T 'non appliqué : {0}') -f ($why -join ', ')) + ')' }
    } else {
        $r.Text = (T 'recalage du lecteur cible non appliqué : {0}') -f ($why -join ', ')
    }
    return $r
}

function New-TargetWriteMemory($tw, $wf, $xp, $rc, [bool]$slow, [string]$userTs, [string]$img, $heads, [bool]$check, [int]$planTracks) {
    # Memoire d une ecriture pour un lecteur cible, posee au lancement (Start-ImageWrite, 140 : $script:TargetWritePending)
    # et gardee a la fin de l ecriture (Complete-TargetWriteMemory) : identifiant, lecteurs, famille, image, ecriture lente
    # ou rapide, tetes logiques ecrites, controle prevu ; par tete logique ecrite (H, cle '0' ou '1') : tete physique qui
    # l ecrit (hswap compris, Get-WriteHeadSpecs), courbe ecrite (profil --precomp, apres le recalage ; zones de la
    # correction R16 ajoutees a la fin), recalage applique (O : ns entiers ajoutes, ORecal : valeur du magasin), date et cle
    # de la courbe croisee employee, facteur k, son origine (KSrc, origine de la tete physique), s il est mesure
    # (KMeasured : le recalage s applique) et s il apprend (KLearn, version finale : mesure sur la disquette elle-meme,
    # Test-TargetRecalKLearn), cylindres des zones. $planTracks : pistes de l operation (Get-WriteErasePlan), repli du
    # nombre de pistes ecrites
    $map = Get-WriteHeadSpecs $userTs 0 1
    $hs = @{}
    foreach ($lh in @($heads | ForEach-Object { [int]$_ } | Sort-Object -Unique)) {
        $p = [int]$map[$lh]
        $t = if ($slow) { $xp.T[$p] } else { $xp.T[0] }
        # Champs absents (plan partiel) : k 1, origine vide (non mesure), recalage 0
        $kv = Get-TargetRecalK $wf $p $slow
        $ks = if ($wf.Src) { [string]$wf.Src[$p] } else { '' }
        $ro = 0.0; $rx = ''; $rk = ''
        if ($rc) { if ($rc.O) { $ro = [double]$rc.O[$p] }; if ($rc.XDate) { $rx = [string]$rc.XDate[$p] }; if ($rc.XKey) { $rk = [string]$rc.XKey[$p] } }
        $hs["$lh"] = @{ Phys = $p; W = [string]$t.Spec; O = [int]$t.Recal; ORecal = $ro; XDate = $rx; XKey = $rk
                         K = [math]::Round($kv, 3); KSrc = $ks; KMeasured = [bool](Test-TargetRecalKMeasured $wf $p $slow); KLearn = [bool](Test-TargetRecalKLearn $wf $p $slow); Zones = [int[]]@() }
    }
    # Aucune tete n apprend : consigne de la ligne de fin d ecriture decidee maintenant, d apres l onglet au lancement
    # (Get-TargetWriteLearnHow) ; How, comme ImgPath, n est pas garde dans la memoire finale
    $how = ''
    # Consigne seulement : une erreur ici ne prive pas l ecriture de sa memoire (raison du refus a la relecture)
    if (@($hs.Values | Where-Object { $_.KLearn }).Count -eq 0) { try { $how = Get-TargetWriteLearnHow $wf $slow $img } catch { $how = '' } }
    $now = Get-Date
    return @{ Id = 'W' + $now.ToString('yyyyMMddHHmmss', [System.Globalization.CultureInfo]::InvariantCulture); Src = [string]$tw.Src; Tgt = [string]$tw.Tgt
              Fam = [string]$tw.Fam; Image = [System.IO.Path]::GetFileName($img); Slow = $slow; Heads = [int[]]@($hs.Keys | ForEach-Object { [int]$_ } | Sort-Object)
              Check = $check; Written = @{}; PlanTracks = $planTracks; ImgPath = $img; How = $how; Tracks = 0; H = $hs; Verdict = ''; Calc = [string]$script:CalibCalc; Date = ''; At = '' }
}

function Set-TargetWritePending($p) {
    # Memoire d une ecriture pour un lecteur cible mise en attente au lancement (Start-ImageWrite, 140 ; $p :
    # New-TargetWriteMemory). Relecture de la rc8 : la memoire de l ecriture precedente pour la meme paire source>cible est
    # retiree des maintenant, et non a la fin : ce n est plus la derniere ecriture pour ce lecteur cible, et une ecriture
    # coupee sans fin traitee (fenetre fermee pendant l ecriture, arret brutal) ne doit pas la laisser proposer sur une
    # disquette en partie reecrite. Le retrait est enregistre par le Save-Config du lancement de gw (Start-Gw, 110)
    $script:TargetWritePending = $p
    if ($p -and $null -ne $script:LastTargetWrites) { $script:LastTargetWrites.Remove("$([string]$p.Src)>$([string]$p.Tgt)") }
}

function Get-TargetWriteZoneCyls($rep, [int]$lh) {
    # Cylindres d une tete logique que la relecture par le lecteur cible ne doit pas compter (Get-TargetRecalReadback) :
    # ceux des zones de la correction R16 (Rep.Zones, 170) dont les pistes ne portent pas la courbe d origine, tries ; aucun
    # sans zone. 12.12 : une zone reprise (State 'back') dont les pistes ont ete reecrites avec la courbe d origine n est
    # plus exclue : c est le cas des qu une passe de reecriture a suivi son jugement (Rep.Round >= 2 : ses pistes
    # rejoignent les pistes faibles de la passe 2, Complete-WriteZonePass, et une erreur de gw retire la memoire). Avant,
    # toute zone etait exclue, meme reprise : une tete a grandes zones reprises n avait plus assez de pistes pour recaler.
    # Zone gardee, non jugee, ou reprise sans passe de reecriture ensuite (Rep.Round < 2) : exclue comme avant
    $cs = @{}
    $rew = ([int]$rep.Round -ge 2)
    foreach ($z in @(@($rep.Zones) | Where-Object { $_ -and [int]$_.H -eq $lh })) {
        if ($rew -and [string]$z.State -ceq 'back') { continue }
        for ($c = [int]$z.C0; $c -le [int]$z.C1; $c++) { $cs[$c] = $true }
    }
    return ,[int[]]@($cs.Keys | ForEach-Object { [int]$_ } | Sort-Object)
}

function Complete-TargetWriteMemory([bool]$ok, $rep = $null) {
    # Fin d une ecriture pour un lecteur cible dont la memoire est en attente ($script:TargetWritePending) : avec controle
    # (Complete-WriteCheck, Stop-WriteCheck, 170), sinon a la fin de la derniere commande gw write (Update-TargetWriteMemoryGw).
    # Ecriture reussie : verdict R10 du controle (Get-AsymSummary, Judge : 'ok', 'near', 'off' ; '' sans controle), courbe
    # finale de chaque tete (Get-RepHeadSpec : zones gardees comprises) et cylindres des zones, pistes ecrites (Rep.Written
    # ou pistes « Writing Track » des commandes, a defaut celles du plan), date ; memoire gardee pour la paire source>cible
    # (elle remplace la precedente), une ligne de journal, configuration enregistree (hors restauration). Ecriture
    # interrompue : memoire de cette paire retiree (la disquette ne porte plus l ecriture precedente), une ligne
    $p = $script:TargetWritePending; $script:TargetWritePending = $null
    if (-not $p) { return }
    if ($null -eq $script:LastTargetWrites) { $script:LastTargetWrites = @{} }
    $src = [string]$p.Src; $tgt = [string]$p.Tgt
    $pk = "$src>$tgt"
    if (-not $ok) {
        $had = $script:LastTargetWrites.ContainsKey($pk)
        if ($had) { $script:LastTargetWrites.Remove($pk) }
        Append-Log ((T "Écriture pour le lecteur cible {0} interrompue : elle ne servira pas à recaler la courbe croisée {1} → {0}.") -f $tgt, $src)
        if ($had -and -not $script:Restore) { [void](Save-Config) }
        return
    }
    $n = 0
    if ($rep) {
        $p.Verdict = [string](Get-AsymSummary @(@($rep.State.Keys) | ForEach-Object { $rep.State[$_] })).Judge
        foreach ($lk in @($p.H.Keys)) {
            $sp = Get-RepHeadSpec $rep ([int]$lk)
            if ($sp) { $p.H[$lk].W = [string]$sp }
            $p.H[$lk].Zones = Get-TargetWriteZoneCyls $rep ([int]$lk)
        }
        $n = @($rep.Written.Keys).Count
        if ($n -eq 0) { $n = @($rep.State.Keys).Count }
    } else { $n = @($p.Written.Keys).Count }
    if ($n -eq 0) { $n = [int]$p.PlanTracks }
    $p.Tracks = $n
    $now = Get-Date
    $p.Date = $now.ToString('dd/MM/yyyy HH:mm', [System.Globalization.CultureInfo]::InvariantCulture)
    $p.At = $now.ToString('yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
    # Lecteurs tires de la cle (une memoire relue ou deplacee par Edit-DriveData ne les porte pas)
    $how = [string]$p.How
    foreach ($f in 'Written', 'PlanTracks', 'Check', 'ImgPath', 'How', 'Src', 'Tgt') { $p.Remove($f) }
    $script:LastTargetWrites[$pk] = $p
    # Version finale (mesure obligatoire) : tetes dont le facteur n a pas ete mesure sur la disquette elle-meme
    # (Get-TargetWriteNoLearn). Aucune tete ne peut apprendre : la ligne ne promet plus de recalage, avec la consigne
    # decidee au lancement (Get-TargetWriteLearnHow : jamais ce qui est deja fait ou sans effet, aucune quand la mesure sur
    # l image est impossible) ; la memoire est gardee quand meme : une relecture par le lecteur cible dit alors pourquoi
    # elle n est pas proposee, et non qu aucune ecriture n est en memoire. Tete exclue nommee par la tete physique qui l a
    # ecrite, comme les lignes du facteur de cette ecriture (Get-TargetTransferPlan, 140)
    $nlw = Get-TargetWriteNoLearn $p
    if ($nlw.All) {
        $line = (T "Écriture pour le lecteur cible {0} terminée ({1}, {2} piste(s)) : elle ne pourra pas recaler la courbe croisée {3} → {0}, car son facteur n'a pas été mesuré sur la disquette elle-même.") -f $tgt, "$($p.Date)", "$n", $src
        $ht = Get-TargetWriteLearnHowText $how
        if ($ht) { $line += ' ' + $ht }
        Append-Log $line
    } else {
        $line = (T "Écriture pour le lecteur cible {0} gardée en mémoire ({1}, {2} piste(s)) : une mesure de cette disquette par le lecteur {0} dans l'onglet « Qualité & alignement » pourra recaler la courbe croisée {3} → {0}.") -f $tgt, "$($p.Date)", "$n", $src
        if (@($nlw.Heads).Count -gt 0) { $line += ' ' + ((T "La tête {0} ne servira pas à ce recalage : son facteur n'a pas été mesuré sur la disquette elle-même.") -f ((@($nlw.Heads) | ForEach-Object { "$($_.Phys)" }) -join ', ')) }
        Append-Log $line
    }
    if (-not $script:Restore) { [void](Save-Config) }
}

function Update-TargetWriteMemoryGw([int]$code, [bool]$incomplete) {
    # Fin d une commande gw write (minuteur, 600) pendant une ecriture pour un lecteur cible sans controle complet : pistes
    # « Writing Track » de la commande ajoutees a la memoire en attente ; erreur ou commande incomplete : ecriture
    # interrompue ; derniere commande de la file (WriteQueue vide) : ecriture terminee. Avec controle : rien (le controle
    # termine la memoire, 170). Commande d une autre operation (calibration, mesure sur l image) ou d une autre image
    # (derniere commande gw, GwLastArgs, sans l image de la memoire) : rien
    $p = $script:TargetWritePending
    if (-not $p -or $p.Check -or $script:Cal) { return }
    if (@($script:GwLastArgs) -notcontains ('"' + [string]$p.ImgPath + '"')) { return }
    foreach ($k in @($script:WriteTracks.Keys)) { $p.Written[[string]$k] = $true }
    if ($code -ne 0 -or $incomplete) { Complete-TargetWriteMemory $false; return }
    if ($script:WriteQueue.Count -eq 0) { Complete-TargetWriteMemory $true }
}

function Get-TargetWriteMemoryFor([string]$tgt) {
    # Memoire de la derniere ecriture pour le lecteur cible $tgt, toutes sources confondues (la plus recente) :
    # @{ Key ; Src ; Tgt ; Mem } ; $null sans elle
    if (-not $tgt -or $null -eq $script:LastTargetWrites) { return $null }
    $best = $null; $bd = [datetime]::MinValue
    foreach ($k in @($script:LastTargetWrites.Keys)) {
        $x = Split-CrossDrive ([string]$k)
        if (-not $x -or [string]$x.Tgt -cne $tgt) { continue }
        $m = $script:LastTargetWrites[$k]
        if (-not $m) { continue }
        $d = ConvertTo-RecalDate ([string]$m.At)
        if (-not $best -or $d -gt $bd) { $best = @{ Key = [string]$k; Src = [string]$x.Src; Tgt = [string]$x.Tgt; Mem = $m }; $bd = $d }
    }
    return $best
}

function Get-TargetReadGain([string]$drive, [string]$fam, [int]$h) {
    # Gain de l asymetrie relue par le lecteur cible : 2 x pente de la derniere mesure sur l image de ce lecteur, de cette
    # famille et de cette tete (SRelAsym fini et positif, calculs ContentCalc et CalibCalc courants ; plus recente par date,
    # puis ordre d ajout), bornee a ContentAsymSRelMin et ContentAsymSRelMax ; sans elle, AsymExpGainFallback (040).
    # Rend @{ G ; Measured }
    $best = $null; $bd = [datetime]::MinValue; $i = 0
    foreach ($r in @($script:ContentMeasures)) {
        $i++
        if ($null -eq $r -or [string]$r.Drive -cne $drive -or [string]$r.Family -ne $fam -or $null -eq $r.Head -or [int]$r.Head -ne $h) { continue }
        if ([string]$r.ContentCalc -ne [string]$script:ContentCalc -or [string]$r.Calc -ne [string]$script:CalibCalc) { continue }
        if ($null -eq $r.SRelAsym) { continue }
        $s = [double]$r.SRelAsym
        if ([double]::IsNaN($s) -or [double]::IsInfinity($s) -or $s -le 0) { continue }
        $d = Get-CurveDate $r
        if ($null -eq $best -or $d -ge $bd) { $best = $s; $bd = $d }
    }
    if ($null -eq $best) { return @{ G = [double]$script:AsymExpGainFallback; Measured = $false } }
    $s = [math]::Max([double]$script:ContentAsymSRelMin, [math]::Min([double]$script:ContentAsymSRelMax, [double]$best))
    return @{ G = 2 * $s; Measured = $true }
}

function Get-TargetReadFamily($tracks) {
    # Famille d une relecture d apres la cellule mediane de ses pistes lisibles : sous 1 500 ns, haute densite ; sous
    # PrecompThresholdNs, long track ; sinon standard. Rend @{ Fam ; Cell }
    $cs = @(foreach ($k in @($tracks.Keys)) { $m = $tracks[$k]; if ($m -and -not $m.Bad -and [double]$m.Cell -gt 0) { [double]$m.Cell } })
    if ($cs.Count -eq 0) { return @{ Fam = ''; Cell = 0.0 } }
    $c = [double](Get-Median $cs)
    $f = if ($c -lt 1500) { 'hd' } elseif ($c -lt [double]$script:PrecompThresholdNs) { 'long' } else { 'std' }
    return @{ Fam = $f; Cell = $c }
}

function Get-TargetRecalReadback($mem, $tracks, [int]$health, $at, [string]$drive, [string]$tgt, [string]$src = '') {
    # Relecture par le lecteur cible d une disquette ecrite pour lui, jugee par la regle R17 sans rien changer. $mem :
    # memoire de l ecriture (New-TargetWriteMemory) ; $tracks : cle 'cylindre.tete' -> metriques de la mesure (Get-TrackMetrics,
    # 190 : Level, Bad, Weak, Ooc, R3, R4, Cell) ; $health : etat du support de la mesure (0 : « SUPPORT SAIN ») ; $at : heure
    # de la mesure ; $drive : lecteur qui a relu ; $tgt : lecteur cible de l ecriture (cle de la memoire,
    # Get-TargetWriteMemoryFor : la memoire ne porte pas les lecteurs). Refus de toute la relecture (Why, codes et textes) : aucune memoire ou
    # autre lecteur que le lecteur cible (1) ; relecture pas « SUPPORT SAIN », une piste illisible, marginale, en erreur ou
    # instable suffit (2) ; nombre de pistes, tetes ou famille autres que ceux de l ecriture, ou relecture anterieure a
    # l ecriture (3) ; controle de l ecriture « eloigne de l attendu » (6). Par tete logique ecrite (Heads) : pistes retenues
    # SAINES, sans erreur par tour, hors cylindres des zones R16, cellule et rapports mesures ; refus de la tete : facteur k
    # non mesure sur la disquette elle-meme (5 ; version finale : origine 'lecteur', 'defaut' ou inconnue, ecriture rapide
    # dont une tete n est pas 'mesure' : Get-TargetWriteKLearnWhy), moins de TargetRecalMinTracks pistes retenues ou moins
    # de TargetRecalMinBlocks blocs de 10 cylindres a TargetRecalBlockTracks pistes (4), |mediane de e| au-dela de TargetRecalMaxGapNs (7). e(c) = (ecart 3T + ecart 4T)
    # x cellule / g (Get-TargetReadGain : g de la tete qui relit) ; Est = recalage applique a cette ecriture (O, ns entiers)
    # - mediane de e : estimation absolue, l ecriture portant deja son recalage. La confirmation de l utilisateur (8) est
    # demandee par Invoke-TargetRecalOffer. Rend @{ Ok (aucun refus global et une tete retenue) ; Why ; Fam ; Cell ;
    # Heads = @{ '0' ; '1' -> @{ Ok ; Why ; N ; Blocks ; Med ; Est ; G ; GMeasured ; Phys ; O } } }
    # Relecture de la rc8 : $src, lecteur qui a ecrit (Invoke-TargetRecalOffer) : refus aussi d une tete dont la courbe
    # croisee employee par l ecriture (XKey, a defaut la courbe par tete puis la commune ; XDate) n est plus celle du magasin,
    # ou dont le calcul de calibration a change depuis l ecriture : le recalage appris ne vaudrait que pour l ancienne courbe
    # (Test-TargetRecalValid) et la fenetre annoncerait un effet qu il n aurait pas. $src vide : pas de ce controle
    $r = @{ Ok = $false; Why = New-Object System.Collections.Generic.List[object]; Fam = ''; Cell = 0.0; Heads = @{} }
    if (-not $mem) { $r.Why.Add(@{ Code = 'nomem'; Text = ((T 'aucune écriture pour le lecteur cible {0} en mémoire') -f $drive) }); return $r }
    if ($tgt -cne $drive) { $r.Why.Add(@{ Code = 'notarget'; Text = ((T "lecteur {0} : ce n'est pas le lecteur cible de l'écriture ({1})") -f $drive, $tgt) }) }
    $keys = @($tracks.Keys | ForEach-Object { [string]$_ })
    $bad = @($keys | Where-Object { $m = $tracks[$_]; -not $m -or $m.Bad -or [int]$m.Level -ne 0 -or $m.Weak })
    if ($health -ne 0 -or $bad.Count -gt 0) {
        $bl = if ($bad.Count -gt 0) { Format-TrackList (Sort-TrackKeys $bad) } else { '-' }
        $r.Why.Add(@{ Code = 'health'; Text = ((T "la relecture n'est pas « SUPPORT SAIN » (piste(s) illisible(s), marginale(s), en erreur ou instable(s) : {0})") -f $bl) })
    }
    if ($keys.Count -ne [int]$mem.Tracks) { $r.Why.Add(@{ Code = 'tracks'; Text = ((T "{0} piste(s) relue(s), l'écriture en a écrit {1} : mesurez les mêmes cylindres et les mêmes têtes") -f "$($keys.Count)", "$([int]$mem.Tracks)") }) }
    $rh = @($keys | ForEach-Object { [int](@($_ -split '\.')[1]) } | Sort-Object -Unique)
    $wh = @(@($mem.Heads) | ForEach-Object { [int]$_ } | Sort-Object -Unique)
    if (($rh -join '+') -ne ($wh -join '+')) { $r.Why.Add(@{ Code = 'heads'; Text = ((T 'têtes relues {0}, têtes écrites {1}') -f $(if ($rh.Count) { $rh -join '+' } else { '-' }), ($wh -join '+')) }) }
    $rf = Get-TargetReadFamily $tracks
    $r.Fam = [string]$rf.Fam; $r.Cell = [double]$rf.Cell
    if ($r.Fam -ne [string]$mem.Fam) { $r.Why.Add(@{ Code = 'family'; Text = ((T "famille de la relecture : {0} (cellule médiane {1} ns), celle de l'écriture : {2}") -f $(if ($r.Fam) { Get-CalibFamilyName $r.Fam } else { '-' }), (Format-UiNum $r.Cell '0'), (Get-CalibFamilyName ([string]$mem.Fam))) }) }
    $wd = ConvertTo-RecalDate ([string]$mem.At)
    if ($null -ne $at -and $wd -ne [datetime]::MinValue -and ([datetime]$at) -lt $wd) { $r.Why.Add(@{ Code = 'before'; Text = ((T "relecture antérieure à l'écriture du {0}") -f "$($mem.Date)") }) }
    if ([string]$mem.Verdict -eq 'off') { $r.Why.Add(@{ Code = 'verdict'; Text = (T "le contrôle de cette écriture a jugé l'asymétrie « éloignée de l'attendu »") }) }
    $nMin = [int]$script:TargetRecalMinTracks; $bMin = [int]$script:TargetRecalMinBlocks; $bTr = [int]$script:TargetRecalBlockTracks; $gMax = [double]$script:TargetRecalMaxGapNs
    $nOk = 0
    foreach ($lh in $wh) {
        $hm = $mem.H["$lh"]
        $o = @{ Ok = $false; Why = New-Object System.Collections.Generic.List[string]; N = 0; Blocks = 0; Med = $null; Est = $null; G = 0.0; GMeasured = $false; Phys = $lh; O = 0 }
        if ($hm) { $o.Phys = [int]$hm.Phys; $o.O = [int]$hm.O }
        $zs = @{}; if ($hm) { foreach ($c in @($hm.Zones)) { $zs[[int]$c] = $true } }
        $gn = Get-TargetReadGain $drive ([string]$mem.Fam) $lh
        $o.G = [double]$gn.G; $o.GMeasured = [bool]$gn.Measured
        $es = New-Object System.Collections.Generic.List[double]; $blk = @{}
        foreach ($k in $keys) {
            $pp = @($k -split '\.')
            if ($pp.Count -ne 2 -or [int]$pp[1] -ne $lh) { continue }
            $c = [int]$pp[0]; $m = $tracks[$k]
            if (-not $m -or $m.Bad -or [int]$m.Level -ne 0 -or $m.Weak -or [double]$m.Ooc -ne 0 -or $zs.ContainsKey($c)) { continue }
            $d3 = [double]$m.R3 - 1.5; $d4 = [double]$m.R4 - 2.0; $cell = [double]$m.Cell
            if ([double]::IsNaN($d3) -or [double]::IsNaN($d4) -or -not ($cell -gt 0)) { continue }
            $es.Add(($d3 + $d4) * $cell / $o.G)
            $b = [int][math]::Floor($c / 10); $blk[$b] = 1 + $(if ($blk.ContainsKey($b)) { [int]$blk[$b] } else { 0 })
        }
        $o.N = $es.Count
        $o.Blocks = @($blk.Keys | Where-Object { [int]$blk[$_] -ge $bTr }).Count
        if ($es.Count -gt 0) { $o.Med = [double](Get-Median $es.ToArray()); $o.Est = [double]$o.O - [double]$o.Med }
        # Version finale (mesure obligatoire) : facteur de cette tete mesure sur la disquette elle-meme, sinon la raison
        $kw = Get-TargetWriteKLearnWhy $mem "$lh"
        if ($kw) { $o.Why.Add($kw) }
        if ($src -and $hm) {
            $cur = $false
            $cks = if ([string]$hm.XKey) { @([string]$hm.XKey) } else { @("$($mem.Fam)_h$([int]$hm.Phys)", [string]$mem.Fam) }
            foreach ($ck in $cks) { $cv = Get-DriveCurve "$src>$tgt" $ck; if ($cv -and [string]$cv.Date -ceq [string]$hm.XDate) { $cur = $true; break } }
            if (-not $cur -or [string]$mem.Calc -cne [string]$script:CalibCalc) { $o.Why.Add(((T 'tête {0} : courbe croisée recalibrée ou calcul changé depuis cette écriture, le recalage ne vaudrait plus pour la courbe croisée actuelle') -f "$lh")) }
        }
        if ($o.N -lt $nMin) { $o.Why.Add(((T 'tête {0} : {1} piste(s) retenue(s) (saines, sans erreur, hors zones corrigées), il en faut {2}') -f "$lh", "$($o.N)", "$nMin")) }
        elseif ($o.Blocks -lt $bMin) { $o.Why.Add(((T 'tête {0} : {1} bloc(s) de 10 cylindres ayant au moins {2} pistes retenues, il en faut {3}') -f "$lh", "$($o.Blocks)", "$bTr", "$bMin")) }
        if ($null -ne $o.Med -and [math]::Abs([double]$o.Med) -gt $gMax) { $o.Why.Add(((T 'tête {0} : écart médian {1} ns, au-delà de ± {2} ns : trop grand pour venir de la courbe croisée, vérifiez le facteur de la disquette') -f "$lh", (Format-UiNum ([double]$o.Med) '+0.0;-0.0;0.0'), (Format-UiNum $gMax '0'))) }
        $o.Ok = ($o.Why.Count -eq 0)
        if ($o.Ok) { $nOk++ }
        $o.Why = [string[]]$o.Why.ToArray()
        $r.Heads["$lh"] = $o
    }
    $r.Ok = ($r.Why.Count -eq 0 -and $nOk -gt 0)
    # Tableaux et non listes : sous PowerShell 7, @() sur une List[object] de tables echoue (liaison dynamique)
    $r.Why = [object[]]$r.Why.ToArray()
    return $r
}

function Get-TargetRecalUpdate([string]$src, [string]$tgt, $mem, $ev, $now) {
    # Entrees du magasin apres une relecture admise (Get-TargetRecalReadback), sans rien changer : par tete logique retenue,
    # entree de sa tete physique (cle Get-TargetRecalKey). Entree d une autre courbe croisee (XDate) ou d un autre calcul :
    # remise a zero. Ecriture deja relue (meme identifiant) : son estimation devient la moyenne de ses relectures (NR) ;
    # sinon elle s ajoute, et seules les TargetRecalMaxItems ecritures les plus recentes restent. Ns : Get-TargetRecalNs.
    # Rend une liste de @{ Key ; Head (logique) ; Phys ; Old (entree d avant ou $null) ; Reset ; New }
    $out = New-Object System.Collections.Generic.List[object]
    $stamp = ([datetime]$now).ToString('yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
    $max = [math]::Max(1, [int]$script:TargetRecalMaxItems)
    foreach ($lk in @($ev.Heads.Keys | Sort-Object)) {
        $o = $ev.Heads[$lk]
        if (-not $o.Ok) { continue }
        $hm = $mem.H[[string]$lk]
        # 12.12 : entree du regime de l ecriture relue (k de la tete dans sa memoire) ; chaque ecriture garde son k
        $kw = if ($hm -and $null -ne $hm.K) { [double]$hm.K } else { 1.0 }
        $up = Test-TargetRecalUp $kw
        $key = Get-TargetRecalKey $src $tgt ([string]$mem.Fam) ([int]$o.Phys) $up
        $old = $null; if ($script:TargetRecal) { $old = $script:TargetRecal[$key] }
        $xd = [string]$hm.XDate
        $reset = ($null -ne $old -and ([string]$old.XDate -cne $xd -or [string]$old.Calc -cne [string]$script:CalibCalc))
        $items = New-Object System.Collections.Generic.List[object]
        if ($old -and -not $reset) { foreach ($it in @($old.Items | Where-Object { $_ })) { $items.Add(@{ WriteId = [string]$it.WriteId; Date = [string]$it.Date; Est = [double]$it.Est; Tracks = [int]$it.Tracks; NR = [math]::Max(1, [int]$it.NR); Read = [string]$it.Read; K = $it.K }) } }
        $hit = $null
        foreach ($it in $items) { if ([string]$it.WriteId -ceq [string]$mem.Id) { $hit = $it } }
        if ($hit) {
            # Ecriture deja relue : moyenne de ses relectures, a sa place (ordre des ecritures)
            $hit.Est = [math]::Round(([double]$hit.Est * [int]$hit.NR + [double]$o.Est) / ([int]$hit.NR + 1), 2)
            $hit.NR = [int]$hit.NR + 1; $hit.Read = $stamp; $hit.Tracks = [int]$o.N; $hit.K = $kw
        } else {
            $items.Add(@{ WriteId = [string]$mem.Id; Date = [string]$mem.Date; Est = [math]::Round([double]$o.Est, 2); Tracks = [int]$o.N; NR = 1; Read = $stamp; K = $kw })
        }
        while ($items.Count -gt $max) { $items.RemoveAt(0) }
        $arr = $items.ToArray()
        $new = @{ Ns = (Get-TargetRecalNs $arr); N = $arr.Count; Items = $arr; XDate = $xd; XKey = [string]$hm.XKey; Calc = [string]$script:CalibCalc; At = $stamp }
        $out.Add(@{ Key = $key; Head = [int]$lk; Phys = [int]$o.Phys; Old = $old; Reset = $reset; New = $new; Up = $up })
    }
    return ,$out.ToArray()
}

function Get-TargetRecalHeadText($mem, $o, $u, [string]$tgt) {
    # Ligne d une tete dans la fenetre de confirmation : pistes retenues, ecart median relu, recalage propose et recalage
    # d avant, effet sur la courbe ecrite pour le lecteur cible par rapport a l ecriture relue (ns entiers, et en % de cette
    # courbe sur ses cylindres non nuls ; relecture de la rc8 : decalage de chaque cylindre limite a TargetRecalWShare de sa
    # valeur, comme Get-TargetTransferSpec, pour ne jamais annoncer plus que ce qui sera ecrit)
    $sg = '+0.0;-0.0;0.0'
    $lk = [int]$u.Head
    $med = [double]$o.Med
    $sens = if ($med -gt 0) { (T 'trop de précompensation pour le lecteur cible') } elseif ($med -lt 0) { (T 'pas assez de précompensation pour le lecteur cible') } else { (T 'centrée pour le lecteur cible') }
    $oldTxt = if ($u.Reset) { (T 'aucun, le précédent est remis à zéro (courbe croisée recalibrée ou calcul changé)') }
              elseif ($u.Old) { (T '{0} ns sur {1} relecture(s)') -f (Format-UiNum ([double]$u.Old.Ns) $sg), "$((Get-TargetRecalReads $u.Old).N)" }
              else { (T 'aucun') }
    $dl = [int][math]::Round([double]$u.New.Ns) - [int]$o.O
    $hm = $mem.H["$lk"]
    $pc = @()
    if ($hm) { foreach ($m in [regex]::Matches([string]$hm.W, '(\d+)\s*=\s*(\d+)')) { $w = [int]$m.Groups[2].Value; if ($w -gt 0) { $lw = [int][math]::Floor([double]$script:TargetRecalWShare * $w); $pc += 100.0 * [math]::Max(-$lw, [math]::Min($lw, $dl)) / $w } } }
    # 12.11 (version finale, rendu de la fenetre) : « (-3 % a -2 % selon le cylindre) » se coupait entre la valeur et « % » :
    # valeurs et unites de l effet insecables, comme Get-TargetRecalSummaryText (espace insecable avant « % » et « ns » dans
    # le modele traduit, signe moins U+2212 des seules valeurs) ; nom du lecteur cible et cles I18n inchanges
    $nb = [string][char]0x00A0; $mn = [string][char]0x2212
    $dlt = ('{0:+0;-0;0}' -f $dl).Replace('-', $mn)
    $eff = if ($dl -eq 0) { (T 'courbe écrite pour le lecteur {0} inchangée par rapport à cette écriture') -f $tgt }
           elseif ($pc.Count -gt 0) { (T 'courbe écrite pour le lecteur {0} : {1} ns par rapport à cette écriture ({2} % à {3} % selon le cylindre)').Replace(' %', $nb + '%').Replace(' ns', $nb + 'ns') -f $tgt, $dlt, (Format-UiNum ([double]($pc | Measure-Object -Minimum).Minimum) '+0;-0;0').Replace('-', $mn), (Format-UiNum ([double]($pc | Measure-Object -Maximum).Maximum) '+0;-0;0').Replace('-', $mn) }
           else { (T 'courbe écrite pour le lecteur {0} : {1} ns par rapport à cette écriture').Replace(' ns', $nb + 'ns') -f $tgt, $dlt }
    return ((T 'Tête {0} : {1} pistes retenues, écart médian {2} ns ({3}) ; recalage {4} ns, au lieu de {5} ; {6}.') -f "$lk", "$($o.N)", (Format-UiNum $med $sg), $sens, (Format-UiNum ([double]$u.New.Ns) $sg), $oldTxt, $eff)
}

function Invoke-TargetRecalOffer($res, $tracks) {
    # Fin d une mesure de l onglet Qualite (Invoke-AlignAnalysis, 190) : quand le lecteur qui a relu est le lecteur cible de
    # la derniere ecriture gardee en memoire pour lui (Get-TargetWriteMemoryFor), la relecture est jugee par la regle R17
    # (Get-TargetRecalReadback). Refus : une ligne de journal qui dit pourquoi (ecriture dont aucune tete ne peut recaler la
    # courbe croisee : cette raison seule, avant toute autre, Get-TargetWriteNoLearn). Admise : fenetre de confirmation (frmConfirm,
    # Show-AppConfirm) qui rappelle l ecriture (date, image), demande de confirmer que c est bien cette disquette (case) et
    # montre le recalage calcule par tete (Get-TargetRecalHeadText) ; confirmee : entrees du magasin remplacees
    # (Get-TargetRecalUpdate), une ligne de journal, configuration enregistree. Pendant une mesure continue : rien
    # d evalue, une ligne a la premiere passe. Sans memoire pour ce lecteur : rien (une mesure ordinaire ne dit rien).
    # Rend 'none', 'loop', 'refused', 'declined' ou 'stored'
    if (-not $res -or [string]$res.Kind -ne 'measure') { return 'none' }
    $drv = if ($res.Ctx -and $res.Ctx.Drive) { [string]$res.Ctx.Drive } else { [string]$cmbDrive.Text }
    $wm = Get-TargetWriteMemoryFor $drv
    if (-not $wm) { return 'none' }
    $mem = $wm.Mem; $src = [string]$wm.Src; $tgt = [string]$wm.Tgt
    # Version finale (relecture) : aucune tete de cette ecriture ne peut recaler la courbe croisee (Get-TargetWriteNoLearn :
    # facteur de la marque, k = 1, origine inconnue) : cette raison seule, a toute relecture par le lecteur cible (mesure
    # partielle ou continue comprises), et jamais l invitation a mesurer toute la disquette, qui serait refusee aussi
    $nlw = Get-TargetWriteNoLearn $mem
    $nlTxt = if ($nlw.All) { (T "Recalage de la courbe croisée {0} → {1} sur cette relecture non proposé : l'écriture du {2} ne peut pas recaler la courbe croisée ({3}).") -f $src, $tgt, "$($mem.Date)", ((@($nlw.Heads) | ForEach-Object { [string]$_.Why }) -join (T ' ; ')) } else { '' }
    if ($script:AlignLoop) {
        if ([int]$script:QualView.Pass -le 1) {
            if ($nlTxt) { Append-Log $nlTxt }
            else { Append-Log ((T "Recalage de la courbe croisée {0} → {1} : non proposé pendant une mesure continue. Faites une mesure simple de toute la disquette écrite le {2} (mêmes cylindres et mêmes têtes que l'écriture).") -f $src, $tgt, "$($mem.Date)") }
        }
        return 'loop'
    }
    if ($nlTxt) { Append-Log $nlTxt; return 'refused' }
    $ev = Get-TargetRecalReadback $mem $tracks ([int]$res.Health) $res.At $drv $tgt $src
    $hw = @(foreach ($lk in @($ev.Heads.Keys | Sort-Object)) { foreach ($w in @($ev.Heads[$lk].Why)) { $w } })
    if (-not $ev.Ok) {
        # Mesure qui ne couvre pas l ecriture (pistes, tetes, famille : une mesure ordinaire de quelques cylindres, par
        # exemple) : ses seules raisons globales, sans le detail par tete
        $cmp = (@($ev.Why | Where-Object { @('tracks', 'heads', 'family') -contains [string]$_.Code }).Count -gt 0)
        $all = @(@($ev.Why | ForEach-Object { [string]$_.Text }) + $(if ($cmp) { @() } else { $hw }))
        Append-Log ((T 'Recalage de la courbe croisée {0} → {1} sur cette relecture non proposé : {2}.') -f $src, $tgt, ($all -join (T ' ; ')))
        return 'refused'
    }
    if ($hw.Count -gt 0) { Append-Log ((T 'Recalage de la courbe croisée {0} → {1} : {2}.') -f $src, $tgt, ($hw -join (T ' ; '))) }
    $up = Get-TargetRecalUpdate $src $tgt $mem $ev (Get-Date)
    $lines = @(foreach ($u in $up) { Get-TargetRecalHeadText $mem $ev.Heads["$($u.Head)"] $u $tgt })
    # 12.12 : tete dont le facteur de la disquette depasse 1 : son recalage est tenu a part (Test-TargetRecalUp)
    $lines += @(foreach ($u in $up) { if ($u.Up) { (T 'Tête {0} : facteur de la disquette au-dessus de 1 ; ce recalage ne vaut que pour les écritures dont le facteur dépasse 1, tenu à part de celui des autres.') -f "$($u.Head)" } })
    $lines += @($hw)
    # rc8 (rendu) : g des deux tetes separes par T(' ; ') comme les listes de Format-WritePlan (145) : « ; » en anglais
    $gt = @(foreach ($lk in @($ev.Heads.Keys | Sort-Object)) { $o = $ev.Heads[$lk]; if ($o.GMeasured) { (T "tête {0} : g = {1}, deux fois la pente mesurée sur l'image") -f "$lk", (Format-UiNum ([double]$o.G) '0.00') } else { (T 'tête {0} : g = {1} par défaut, pente non mesurée') -f "$lk", (Format-UiNum ([double]$o.G) '0.00') } })
    $txt = ((T "Le lecteur {0} a relu la disquette écrite pour lui par le lecteur {1} le {2} (image « {3} », {4}, {5} pistes).`n`n{6}`n`nÉcart relu = (écart 3T + écart 4T) × cellule / g ({7}). Le recalage moyenne les {8} dernières écritures relues en se rapprochant de leur écart à mesure qu'elles s'ajoutent, au plus ± {9} ns ; arrondi au ns, il s'ajoute à la courbe écrite pour le lecteur {0} (au plus 25 % de sa valeur), sans modifier la courbe croisée. La fenêtre « Lecteurs » le montre et l'annule.`n`nUne autre disquette fausserait le recalage : confirmez que c'est bien celle-là.") -f $tgt, $src, "$($mem.Date)", "$($mem.Image)", (Get-CalibFamilyName ([string]$mem.Fam)), "$([int]$mem.Tracks)", ($lines -join "`n"), ($gt -join (T ' ; ')), "$($script:TargetRecalMaxItems)", (Format-UiNum ([double]$script:TargetRecalCapNs) '0'))
    $go = [bool](Show-AppConfirm -Title (T 'Recalage de la courbe croisée') -Heading ((T 'Recaler la courbe croisée {0} → {1} sur cette relecture ?') -f $src, $tgt) -Text $txt -Check ((T 'Disquette écrite le {0} pour le lecteur {1}') -f "$($mem.Date)", $tgt) -GoText (T 'Recaler la courbe croisée') -GoGlyph 'Check' -Level 'info' -Picto 'data')
    if (-not $go) { Append-Log ((T 'Recalage de la courbe croisée {0} → {1} non enregistré : non confirmé.') -f $src, $tgt); return 'declined' }
    if ($null -eq $script:TargetRecal) { $script:TargetRecal = @{} }
    $sg = '+0.0;-0.0;0.0'
    $it = @(foreach ($u in $up) { $script:TargetRecal[[string]$u.Key] = $u.New; if ($u.Up) { (T 'tête {0} {1} ns (facteur au-dessus de 1)') -f "$($u.Phys)", (Format-UiNum ([double]$u.New.Ns) $sg) } else { (T 'tête {0} {1} ns') -f "$($u.Phys)", (Format-UiNum ([double]$u.New.Ns) $sg) } })
    Append-Log ((T "Courbe croisée {0} → {1} recalée sur la relecture de l'écriture du {2} : {3} ; ajouté aux prochaines écritures pour le lecteur {1} (courbe croisée inchangée).") -f $src, $tgt, "$($mem.Date)", ($it -join (T ' ; ')))
    [void](Save-Config)
    return 'stored'
}

function Remove-TargetRecal([string]$src, [string]$tgt, [string]$fam) {
    # Recalages des deux tetes d une courbe croisee source>cible d une famille retires du magasin, pour les deux regimes
    # (12.12 : k <= 1 et k > 1) ; rend le nombre de tetes dont un recalage au moins est retire
    $n = 0
    if ($null -eq $script:TargetRecal) { return 0 }
    foreach ($h in 0, 1) {
        $hit = $false
        foreach ($up in $false, $true) { $k = Get-TargetRecalKey $src $tgt $fam $h $up; if ($script:TargetRecal.ContainsKey($k)) { $script:TargetRecal.Remove($k); $hit = $true } }
        if ($hit) { $n++ }
    }
    return $n
}

function Get-TargetRecalSummaryText([string]$src, [string]$tgt, [string]$fam) {
    # Ligne du recalage d une courbe croisee dans la fenetre « Lecteurs » (112) : valeur par tete, relectures, date de la
    # derniere ; « sans effet » quand la courbe croisee de la tete a ete recalibree (ou le calcul a change) depuis ; '' sans
    # recalage. rc8 (rendu) : « tete 1 -2,3 ns » insecable (jamais coupe entre la tete, la valeur et l unite) : espaces
    # insecables, et signe moins U+2212 (le trait d union, coupure possible apres lui, renvoyait « 2,3 ns » a la ligne)
    $sg = '+0.0;-0.0;0.0'
    $nb = [string][char]0x00A0
    $parts = @(); $reads = 0; $last = ''; $stale = $false
    # 12.12 : les deux regimes de chaque tete (k <= 1, puis k > 1 suivi de « (facteur au-dessus de 1) », hors du bloc insecable)
    foreach ($hu in @(@(0, $false), @(0, $true), @(1, $false), @(1, $true))) {
        $h = [int]$hu[0]; $up = [bool]$hu[1]
        $e = Get-TargetRecalEntry $src $tgt $fam $h $up
        if (-not $e) { continue }
        $pv = ((T 'tête {0} {1} ns') -f "$h", (Format-UiNum ([double]$e.Ns) $sg).Replace('-', [string][char]0x2212)).Replace(' ', $nb)
        if ($up) { $pv += ' ' + (T '(facteur au-dessus de 1)') }
        $parts += $pv
        $rd = Get-TargetRecalReads $e
        if ([int]$rd.N -gt $reads) { $reads = [int]$rd.N }
        if ([string]$rd.Last -and (-not $last -or (ConvertTo-RecalDate ([string]$rd.Last)) -gt (ConvertTo-RecalDate $last))) { $last = [string]$rd.Last }
        # Courbe croisee qui a servi a l apprendre (XKey ; sans elle, la courbe par tete puis la commune) : absente, d une autre
        # date, ou calcul change : sans effet
        $ok = $false
        $cks = if ([string]$e.XKey) { @([string]$e.XKey) } else { @("$($fam)_h$h", $fam) }
        foreach ($ck in $cks) { $cv = Get-DriveCurve "$src>$tgt" $ck; if ($cv -and [string]$cv.Date -ceq [string]$e.XDate) { $ok = $true; break } }
        if (-not $ok -or [string]$e.Calc -cne [string]$script:CalibCalc) { $stale = $true }
    }
    if ($parts.Count -eq 0) { return '' }
    $lt = if ($last) { (ConvertTo-RecalDate $last).ToString('dd/MM/yyyy', [System.Globalization.CultureInfo]::InvariantCulture) } else { '?' }
    $t = (T 'Recalage de la courbe croisée {0} → {1} ({2}) : {3} ; {4} relecture(s), dernière le {5}.') -f $src, $tgt, (Get-CalibFamilyName $fam), ($parts -join ', '), "$reads", $lt
    if ($stale) { $t += ' ' + (T 'Sans effet : courbe croisée recalibrée ou calcul changé depuis.') }
    return $t
}

function Export-TargetRecal {
    # Bloc write.targetRecal de la configuration : cle -> { ns ; n ; xDate ; calc ; at ; items : [ { writeId ; date ; est ;
    # pistes ; nr ; read } ] }, cles triees ; une version anterieure ignore ce bloc
    $o = [ordered]@{}
    if ($null -eq $script:TargetRecal) { return $o }
    foreach ($k in @($script:TargetRecal.Keys | Sort-Object)) {
        $e = $script:TargetRecal[$k]
        if (-not $e) { continue }
        # 12.12 : k de l ecriture relue (regime), absent d une ecriture relue par une 12.11 et non retrouvee
        $its = @(foreach ($it in @($e.Items | Where-Object { $_ })) { $d = [ordered]@{ writeId = [string]$it.WriteId; date = [string]$it.Date; est = [math]::Round([double]$it.Est, 2); pistes = [int]$it.Tracks; nr = [math]::Max(1, [int]$it.NR); read = [string]$it.Read }; if ($null -ne $it.K) { $d['k'] = [math]::Round([double]$it.K, 3) }; $d })
        $o[[string]$k] = [ordered]@{ ns = [double]$e.Ns; n = $its.Count; xDate = [string]$e.XDate; xKey = [string]$e.XKey; calc = [string]$e.Calc; at = [string]$e.At; items = $its }
    }
    return $o
}

function Import-TargetRecal($o) {
    # Bloc write.targetRecal -> $script:TargetRecal (vide d abord). Cle « source>cible|famille_hN » et au moins une
    # estimation finie exigees ; Ns et N recalcules sur les estimations (Get-TargetRecalNs), les TargetRecalMaxItems
    # dernieres : la valeur ns enregistree n est jamais reprise, et une entree enregistree par la rc8 (f = n / (n + 1)) suit
    # la regle courante des le demarrage suivant. Entree illisible : ignoree et comptee. 12.12 : cle suivie de « + » pour
    # le regime k > 1 ; k de chaque ecriture relue (K, $null sans lui) ; ecritures relues par une 12.11 (sans k) dans une
    # entree sans « + » : celles dont la mesure sur l image donnait k > 1 (Get-TargetRecalItemK, apres le chargement des
    # mesures : Load-Config) passent dans l entree « + », creee au besoin avec la meme courbe croisee ; les autres restent
    # (k <= 1 ou mesure introuvable). Rend @{ N ; Bad ; Moved (ecritures reclassees) }
    $script:TargetRecal = @{}
    $n = 0; $bad = 0; $moved = 0
    if ($null -eq $o -or $o -is [array] -or $o -is [string] -or $o -is [ValueType]) { return @{ N = 0; Bad = 0; Moved = 0 } }
    $max = [math]::Max(1, [int]$script:TargetRecalMaxItems)
    $raw = @{}
    foreach ($p in @($o.PSObject.Properties)) {
        $k = [string]$p.Name; $v = $p.Value
        try {
            if ($k -notmatch '^[^>|]+>[^>|]+\|(std|long|hd)_h[01]\+?$' -or $null -eq $v) { $bad++; continue }
            $its = New-Object System.Collections.Generic.List[object]
            foreach ($it in @($v.items)) {
                if ($null -eq $it) { continue }
                $est = ConvertTo-FiniteOrNull $it.est
                if ($null -eq $est -or -not [string]$it.writeId) { continue }
                $its.Add(@{ WriteId = [string]$it.writeId; Date = [string]$it.date; Est = [double]$est; Tracks = [int]$it.pistes; NR = [math]::Max(1, [int]$it.nr); Read = [string]$it.read; K = (ConvertTo-FiniteOrNull $it.k) })
            }
            if ($its.Count -eq 0 -or -not [string]$v.xDate) { $bad++; continue }
            $raw[$k] = @{ Items = $its; XDate = [string]$v.xDate; XKey = [string]$v.xKey; Calc = [string]$v.calc; At = [string]$v.at }
        } catch { $bad++ }
    }
    # Reclassement des ecritures relues par une 12.11 dont le facteur depassait 1
    foreach ($k in @($raw.Keys | Where-Object { -not ([string]$_).EndsWith('+') } | Sort-Object)) {
        try {
            $e = $raw[$k]
            if ($k -notmatch '^([^>|]+)>[^>|]+\|(std|long|hd)_h([01])$') { continue }
            $drv = [string]$Matches[1]; $fam = [string]$Matches[2]; $h = [int]$Matches[3]
            $keep = New-Object System.Collections.Generic.List[object]; $mv = New-Object System.Collections.Generic.List[object]
            foreach ($it in $e.Items) {
                if ($null -ne $it.K) { $keep.Add($it); continue }
                $ik = Get-TargetRecalItemK $drv $fam $h ([string]$it.WriteId)
                if ($null -ne $ik -and (Test-TargetRecalUp ([double]$ik))) { $it.K = [double]$ik; $mv.Add($it) } else { $keep.Add($it) }
            }
            if ($mv.Count -eq 0) { continue }
            $moved += $mv.Count
            $ku = $k + '+'
            if (-not $raw.ContainsKey($ku)) { $raw[$ku] = @{ Items = (New-Object System.Collections.Generic.List[object]); XDate = [string]$e.XDate; XKey = [string]$e.XKey; Calc = [string]$e.Calc; At = [string]$e.At } }
            # Meme courbe croisee seulement : une entree « + » d une autre date garde ses ecritures, les reclassees sont perdues
            if ([string]$raw[$ku].XDate -ceq [string]$e.XDate) {
                foreach ($it in $mv) { $raw[$ku].Items.Add($it) }
                $srt = @($raw[$ku].Items | Sort-Object -Property @{ Expression = { [string]$_.WriteId } })
                $raw[$ku].Items = New-Object System.Collections.Generic.List[object]; foreach ($it in $srt) { $raw[$ku].Items.Add($it) }
            }
            $e.Items = $keep
            if ($keep.Count -eq 0) { $raw.Remove($k) }
        } catch { }
    }
    foreach ($k in @($raw.Keys)) {
        $e = $raw[$k]
        while ($e.Items.Count -gt $max) { $e.Items.RemoveAt(0) }
        if ($e.Items.Count -eq 0) { continue }
        $arr = $e.Items.ToArray()
        $script:TargetRecal[$k] = @{ Ns = (Get-TargetRecalNs $arr); N = $arr.Count; Items = $arr; XDate = [string]$e.XDate; XKey = [string]$e.XKey; Calc = [string]$e.Calc; At = [string]$e.At }
        $n++
    }
    return @{ N = $n; Bad = $bad; Moved = $moved }
}

function Export-LastTargetWrites {
    # Bloc write.lastTargetWrite de la configuration : « source>cible » -> memoire de la derniere ecriture pour ce lecteur
    # cible (Complete-TargetWriteMemory), cles triees ; une version anterieure ignore ce bloc. Version finale : kLearn par
    # tete (Test-TargetRecalKLearn), null pour une memoire de la rc8 qui ne l a pas (Get-TargetWriteKLearnWhy decide alors
    # d apres kSrc ; un faux ecrit a sa place la priverait de l apprentissage)
    $o = [ordered]@{}
    if ($null -eq $script:LastTargetWrites) { return $o }
    foreach ($k in @($script:LastTargetWrites.Keys | Sort-Object)) {
        $m = $script:LastTargetWrites[$k]
        if (-not $m) { continue }
        $hs = [ordered]@{}
        foreach ($lk in @($m.H.Keys | Sort-Object)) {
            $h = $m.H[$lk]
            $hs[[string]$lk] = [ordered]@{ phys = [int]$h.Phys; w = [string]$h.W; o = [int]$h.O; oRecal = [double]$h.ORecal; xDate = [string]$h.XDate; xKey = [string]$h.XKey
                                          k = [double]$h.K; kSrc = [string]$h.KSrc; kMeasured = [bool]$h.KMeasured; kLearn = $(if ($null -ne $h.KLearn) { [bool]$h.KLearn } else { $null })
                                          zones = @(@($h.Zones) | ForEach-Object { [int]$_ }) }
        }
        $o[[string]$k] = [ordered]@{ id = [string]$m.Id; date = [string]$m.Date; at = [string]$m.At; image = [string]$m.Image; fam = [string]$m.Fam; slow = [bool]$m.Slow
                                     tracks = [int]$m.Tracks; heads = @(@($m.Heads) | ForEach-Object { [int]$_ }); verdict = [string]$m.Verdict; calc = [string]$m.Calc; h = $hs }
    }
    return $o
}

function Import-LastTargetWrites($o) {
    # Bloc write.lastTargetWrite -> $script:LastTargetWrites (vide d abord) : cle « source>cible », identifiant, date,
    # famille et une tete au moins exiges ; entree illisible ignoree et comptee. kLearn absent ou null (memoire de la rc8) :
    # KLearn $null ; kSrc absent : KSrc vide, tete qui n apprend pas (Get-TargetWriteKLearnWhy). Rend @{ N ; Bad }
    $script:LastTargetWrites = @{}
    $n = 0; $bad = 0
    if ($null -eq $o -or $o -is [array] -or $o -is [string] -or $o -is [ValueType]) { return @{ N = 0; Bad = 0 } }
    foreach ($p in @($o.PSObject.Properties)) {
        $k = [string]$p.Name; $v = $p.Value
        try {
            if (-not (Split-CrossDrive $k) -or $null -eq $v -or -not [string]$v.id -or -not [string]$v.at -or -not [string]$v.fam -or $null -eq $v.h) { $bad++; continue }
            $hs = @{}
            foreach ($q in @($v.h.PSObject.Properties)) {
                $h = $q.Value
                if ([string]$q.Name -notmatch '^[01]$' -or $null -eq $h) { continue }
                $hs[[string]$q.Name] = @{ Phys = [int]$h.phys; W = [string]$h.w; O = [int]$h.o; ORecal = (Get-ConfigDouble $h.oRecal 0.0); XDate = [string]$h.xDate; XKey = [string]$h.xKey
                                          K = (Get-ConfigDouble $h.k 1.0); KSrc = [string]$h.kSrc; KMeasured = ($h.kMeasured -eq $true); KLearn = $(if ($null -ne $h.kLearn) { ($h.kLearn -eq $true) } else { $null })
                                          Zones = [int[]]@(@($h.zones) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ }) }
            }
            if ($hs.Count -eq 0) { $bad++; continue }
            $script:LastTargetWrites[$k] = @{ Id = [string]$v.id; Date = [string]$v.date; At = [string]$v.at; Image = [string]$v.image; Fam = [string]$v.fam; Slow = ($v.slow -eq $true)
                                              Tracks = [int]$v.tracks; Heads = [int[]]@(@($v.heads) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ }); Verdict = [string]$v.verdict; Calc = [string]$v.calc; H = $hs }
            $n++
        } catch { $bad++ }
    }
    return @{ N = $n; Bad = $bad }
}
