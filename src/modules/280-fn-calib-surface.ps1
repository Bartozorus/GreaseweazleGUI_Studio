# ============================== FONCTIONS : CALIBRATION : CONTROLE DE SURFACE ET DE VITESSE ===

# 12.7 : controle de surface de la disquette de calibration a la passe 1 (fonctions pures, appelees par Invoke-CalibAnalysis
# et Complete-PrecompCalib). Defaut grossier (arbitrage 1) : fenetre sans compte a rebours pendant la calibration ;
# disquette douteuse sans defaut grossier : reserve « support » de la fenetre de decision ; bilan par face toujours au journal
function Get-CalibSurface($tracks, [int[]]$cyls) {
    # Controle de surface de la disquette de calibration sur la relecture de la passe 1 (motif ecrit a 0 ns, 3 tours) :
    # par face et par cylindre teste, trous de signal (Dropouts), hors classe (OutOfClass, juges seulement sous
    # CalSurfShiftMax ns de decalage), ecart du nombre de flux entre tours (NFlux), piste illisible (absente ou sans tour
    # mesurable). Face douteuse : CalSurfMinBad pistes defectueuses au moins, ou CalSurfFrac des cylindres testes, ou
    # CalSurfRun cylindres testes consecutifs, ou hors classe sur toute la face. Seuils provisoires (H). Par face aussi :
    # tours avec trous de signal (DropTot) sur les tours relus (RevTot), pour le journal.
    $res = @{ Faces = @{}; Bad = @(); Defective = $false; Why = @() }
    foreach ($h in 0, 1) {
        $rows = @()
        foreach ($c in $cyls) {
            $tn = [int]$c * 2 + $h
            $r = @{ C = [int]$c; Missing = $true; Valid = 0; NRev = 0; DropRevs = 0; Ooc = 0.0; Stab = 0; Shift = [double]::NaN }
            if ($tracks.ContainsKey($tn)) {
                $revs = @($tracks[$tn] | Where-Object { $null -ne $_ })
                $r.NRev = $revs.Count; $r.Missing = ($revs.Count -eq 0)
                $sh = @(); $oc = @(); $nf = @()
                foreach ($x in $revs) {
                    if ([int]$x.Dropouts -gt 0) { $r.DropRevs++ }
                    $oc += [double]$x.OutOfClass; $nf += [int]$x.NFlux
                    if ($null -ne $x.Shift -and -not [double]::IsNaN([double]$x.Shift)) { $sh += [double]$x.Shift }
                }
                $r.Valid = $sh.Count
                if ($oc.Count -gt 0) { $r.Ooc = Get-Median $oc }
                if ($nf.Count -gt 0) { $r.Stab = [int](($nf | Measure-Object -Maximum).Maximum - ($nf | Measure-Object -Minimum).Minimum) }
                if ($sh.Count -gt 0) { $r.Shift = ($sh | Measure-Object -Average).Average }
            }
            $rows += $r
        }
        # Reference de la face : pistes mesurables (et, pour les hors classe, de decalage jugeable)
        $ok = @($rows | Where-Object { $_.Valid -gt 0 })
        $jo = @($ok | Where-Object { [math]::Abs($_.Shift) -le $script:CalSurfShiftMax })
        $mo = if ($jo.Count) { Get-Median @($jo | ForEach-Object { $_.Ooc }) } else { 0.0 }
        $ao = if ($jo.Count) { 1.4826 * (Get-Median @($jo | ForEach-Object { [math]::Abs($_.Ooc - $mo) })) } else { 0.0 }
        $ms = if ($ok.Count) { Get-Median @($ok | ForEach-Object { $_.Stab }) } else { 0.0 }
        $as = if ($ok.Count) { 1.4826 * (Get-Median @($ok | ForEach-Object { [math]::Abs($_.Stab - $ms) })) } else { 0.0 }
        $to = [math]::Max([double]$script:CalSurfOocFloor, $mo + $script:CalSurfMadK * [math]::Max(1.0, $ao))
        $ts = [math]::Max([double]$script:CalSurfStabFloor, $ms + $script:CalSurfMadK * [math]::Max(1.0, $as))
        $bad = @(); $part = @(); $nj = @(); $run = 0; $top = 0; $smax = 0; $dt = 0; $rt = 0
        foreach ($r in $rows) {
            $why = @()
            $dt += [int]$r.DropRevs; $rt += [int]$r.NRev
            if ($r.Missing -or $r.Valid -eq 0) { $why += 'unread' }
            else {
                if ($r.Valid -lt $r.NRev) { $part += $r.C }
                if ($r.DropRevs -ge $script:CalSurfDropRevs) { $why += 'drop' }
                if ([math]::Abs($r.Shift) -gt $script:CalSurfShiftMax) { $nj += $r.C }
                elseif ($r.Ooc -gt $to) { $why += 'ooc' }
                if ($r.Stab -gt $ts) { $why += 'stab' }
                if ($r.Stab -gt $smax) { $smax = $r.Stab }
            }
            if ($why.Count) { $bad += @{ C = $r.C; H = $h; Why = $why }; $run++; if ($run -gt $top) { $top = $run } } else { $run = 0 }
        }
        $need = [math]::Max([int]$script:CalSurfMinBad, [int][math]::Ceiling($script:CalSurfFrac * $rows.Count))
        $noisy = ($jo.Count -ge 3 -and $mo -gt $script:CalSurfOocFloor)
        $def = ($bad.Count -ge $need) -or ($top -ge $script:CalSurfRun) -or $noisy
        $res.Faces[$h] = @{ N = $rows.Count; Bad = $bad; Part = $part; NotJudged = $nj; OocMed = $mo; OocThr = $to; StabMax = $smax; StabThr = $ts; Run = $top; Need = $need; Noisy = $noisy; Defective = $def
                            DropTot = $dt; RevTot = $rt }
        $res.Bad += $bad
        if ($def) { $res.Defective = $true; $res.Why += $h }
    }
    return $res
}

function Get-CalibSurfaceOptions([bool]$restore, [bool]$redo, [bool]$toWrite, [bool]$swap) {
    # Boutons et texte de la fenetre du controle de surface selon le contexte. Restauration sans disquette sacrifiee :
    # la destination, deja sondee, ne peut pas etre changee ici.
    if ($restore) { return @{ Change = $swap; SwapBox = $false; Variant = $(if ($swap) { 'restore-swap' } else { 'restore' }) } }
    if ($redo) { return @{ Change = $true; SwapBox = $false; Variant = 'redo' } }
    if ($toWrite -and $swap) { return @{ Change = $true; SwapBox = $false; Variant = 'swap' } }
    if ($toWrite) { return @{ Change = $true; SwapBox = $true; Variant = 'write' } }
    return @{ Change = $true; SwapBox = $false; Variant = 'normal' }
}

function Get-CalibSurfaceReasons($bad) {
    # Defauts d une face regroupes par nature : « trous de signal aux cylindres 9-11 ; illisible aux cylindres 40 »
    $names = [ordered]@{ unread = (T 'illisible'); drop = (T 'trous de signal'); ooc = (T 'intervalles hors classe'); stab = (T "lecture différente d'un tour à l'autre") }
    $parts = @()
    foreach ($k in @($names.Keys)) {
        $cs = [int[]]@(@($bad) | Where-Object { @($_.Why) -contains $k } | ForEach-Object { [int]$_.C } | Sort-Object -Unique)
        if ($cs.Count) { $parts += ((T "{0} aux cylindres {1}") -f "$($names[$k])", (Format-CylList $cs)) }
    }
    return ($parts -join ' ; ')
}

function Format-CalibSurfaceShort($sf) {
    # Resume du verdict : « face 1 : 3 piste(s) défectueuse(s) sur 80 ; face 0 : hors classe sur toute la face »
    $p = @()
    foreach ($h in 0, 1) {
        $f = $sf.Faces[$h]
        if (-not $f -or -not $f.Defective) { continue }
        if ($f.Noisy) { $p += ((T "face {0} : hors classe sur toute la face") -f "$h") }
        else { $p += ((T "face {0} : {1} piste(s) défectueuse(s) sur {2}") -f "$h", "$(@($f.Bad).Count)", "$($f.N)") }
    }
    return ($p -join ' ; ')
}

function Get-CalibSurfaceFaceLines($sf) {
    # Bilan de chaque face, tous ses compteurs (journal ; 12.7 point 5 : fenetre de la disquette a ecrire)
    $faces = @()
    foreach ($h in 0, 1) {
        $f = $sf.Faces[$h]
        $det = if (@($f.Bad).Count) { ' (' + (Get-CalibSurfaceReasons $f.Bad) + ')' } else { '' }
        $s = (T "face {0} : {1} cylindres, {2} défectueux{3}, trous de signal dans {4} tour(s) sur {5}, hors classe {6} par tour en médiane (seuil {7}), écart du nombre de flux entre tours jusqu'à {8} (seuil {9})") -f "$h", "$($f.N)", "$(@($f.Bad).Count)", $det, "$([int]$f.DropTot)", "$([int]$f.RevTot)", (Format-UiNum $f.OocMed), (Format-UiNum $f.OocThr), "$($f.StabMax)", (Format-UiNum $f.StabThr)
        if (@($f.NotJudged).Count) { $s += (T ", non jugés sur les hors classe aux cylindres {0} (décalage au-delà de {1} ns)") -f (Format-CylList ([int[]]$f.NotJudged)), "$($script:CalSurfShiftMax)" }
        if (@($f.Part).Count) { $s += (T ", lecture partielle aux cylindres {0}") -f (Format-CylList ([int[]]$f.Part)) }
        $faces += $s
    }
    return ,$faces
}

function Format-CalibSurfaceFaceDefect($f, [int]$h) {
    # 12.7, arbitrage 14 : defauts d une face douteuse dans la fenetre du controle de surface, avec tous les compteurs
    # releves : hors classe sur toute la face, pistes defectueuses par nature, tours avec trous de signal
    $p = @()
    if ($f.Noisy) { $p += ((T 'intervalles hors classe sur toute la face ({0} par tour en médiane)') -f (Format-UiNum $f.OocMed)) }
    if (@($f.Bad).Count) { $p += (Get-CalibSurfaceReasons $f.Bad) }
    if ([int]$f.DropTot -gt 0) { $p += ((T 'trous de signal dans {0} tour(s) sur {1}') -f "$([int]$f.DropTot)", "$([int]$f.RevTot)") }
    return ((T "face {0} : {1}") -f "$h", ($p -join ' ; '))
}

function Test-CalibCleanHint($sf, $mc, [bool]$hd) {
    # 12.7, arbitrage 14 : conseil de nettoyer les tetes seulement pour des trous de signal (pistes defectueuses par trous
    # reproductibles) sur les deux faces d un support a la bonne densite : vitesse et densite relues conformes
    # (Get-CalibMediumCheck). Jamais en haute densite : des trous sur les deux faces y viennent le plus souvent d une
    # disquette double densite, que le nombre de flux relu ne distingue pas (cas D2 de l addendum HD : flux a 99 %, cas X3
    # de cross127) ; le paragraphe haute densite de la fenetre donne alors la cause probable
    if ($hd) { return $false }
    foreach ($h in 0, 1) {
        $f = $sf.Faces[$h]
        if (-not $f -or @(@($f.Bad) | Where-Object { @($_.Why) -contains 'drop' }).Count -eq 0) { return $false }
    }
    if ($mc -and ($mc.Flux -or $mc.Rot)) { return $false }
    return $true
}

function Format-CalibSurfaceLog($sf, [bool]$std, [string]$verdict = 'hold') {
    # Lignes du journal : bilan des deux faces (toujours, donnees pour recaler les seuils), puis verdict. $verdict : 'hold'
    # (disquette douteuse : decision demandee), 'reserve' (douteuse sans defaut grossier : reserve au bilan, arbitrage 1 de
    # la 12.7), 'none' (bilan seul : l appelant ecrit le verdict d un defaut grossier)
    $faces = Get-CalibSurfaceFaceLines $sf
    $sfx = if ($std) { (T ' ; contrôle partiel en test standard, cylindres de test seulement') } else { '' }
    $lines = @((T "Contrôle de surface (passe 1, motif écrit sans précompensation) : {0}{1}.") -f ($faces -join ' ; '), $sfx)
    if ($verdict -eq 'none') { return ,$lines }
    if ($sf.Defective) {
        if ($verdict -eq 'reserve') { $lines += ((T "Contrôle de surface : disquette de calibration douteuse ({0}) ; la calibration continue, avec une réserve au bilan.") -f (Format-CalibSurfaceShort $sf)) }
        else { $lines += ((T "Contrôle de surface : disquette de calibration douteuse ({0}) : décision demandée.") -f (Format-CalibSurfaceShort $sf)) }
    }
    elseif (@($sf.Bad).Count) {
        $p = @(); foreach ($h in 0, 1) { $b = @($sf.Faces[$h].Bad); if ($b.Count) { $p += ((T "face {0} : {1}") -f "$h", (Get-CalibSurfaceReasons $b)) } }
        $lines += ((T "Contrôle de surface : défaut ponctuel de la disquette de calibration ({0}) ; la calibration continue.") -f ($p -join ' ; '))
    }
    return ,$lines
}

function Get-CalibSurfaceText($sf, $opt, [bool]$std, [bool]$autoStart, [string[]]$Extra = @(), [string[]]$Notes = @(), $Medium = $null, [bool]$Hd = $false) {
    # Texte de la fenetre du controle de surface (lblSurfText). Extra : lignes de la vitesse du lecteur et de la densite
    # relue (Get-CalibMediumCheck) apres celles des faces ; Notes : paragraphes qui les expliquent. 12.7 : $opt.Speed (defaut
    # de vitesse seul, Test-CalibSpeedOnly) : en-tete qui nomme le lecteur, sans la phrase sur le support ; $opt.Change
    # faux hors restauration : premiere ligne des choix (« Changer de disquette ») retiree. Arbitrage 14 : chaque face
    # douteuse avec tous ses compteurs (Format-CalibSurfaceFaceDefect) ; conseil de nettoyer les tetes seulement pour des
    # trous de signal sur les deux faces a la bonne densite (Test-CalibCleanHint ; Medium, Hd : famille haute densite)
    $spd = [bool]$opt.Speed
    $t = if ($spd) { (T 'Le lecteur ne tourne pas à la vitesse de ce type de disquette. Le contrôle de la première passe, où le motif de test est écrit sans précompensation puis relu sur 3 tours, a trouvé :') } else { (T "La disquette de calibration semble défectueuse. Le contrôle de surface de la première passe, où le motif de test est écrit sans précompensation puis relu sur 3 tours, a trouvé :") }
    foreach ($h in 0, 1) {
        $f = $sf.Faces[$h]
        if (-not $f.Defective) { continue }
        $t += "`n  - " + (Format-CalibSurfaceFaceDefect $f $h)
    }
    foreach ($x in @($Extra)) { if ($x) { $t += "`n  - " + $x } }
    if ($spd) { $t += "`n" } else { $t += "`n`n" + (T "Sur une telle disquette, la calibration risque de mesurer le défaut du support plutôt que le besoin du lecteur.") }
    foreach ($x in @($Notes)) { if ($x) { $t += "`n" + $x } }
    if (Test-CalibCleanHint $sf $Medium $Hd) { $t += "`n" + (T "Des trous de signal sur les deux faces viennent souvent de têtes sales : nettoyez-les (carte « Nettoyer les têtes du lecteur » de l'Accueil), puis recommencez.") }
    if ($std) { $t += "`n" + (T 'Test standard : seuls les cylindres de test ont été contrôlés.') }
    $t += "`n`n"
    $pre = ''
    switch ($opt.Variant) {
        'write' {
            $pre = (T "La disquette insérée est la disquette à écrire : elle recevra le motif de test, puis l'image.") + "`n"
            if ($autoStart) { $pre += (T "L'avertissement a été validé automatiquement : la disquette insérée est donc celle à écrire.") + "`n" }
            $act = (T "Changer de disquette : insérez une autre disquette et cochez la première case ; cochez aussi la seconde si c'est une disquette sacrifiée, la disquette à écrire vous sera alors redemandée après la calibration. La calibration reprend à la première passe, avec les mêmes réglages et sans nouvel avertissement.`nContinuer : la calibration se poursuit sur cette disquette, puis l'image y est écrite.`nArrêter : la calibration s'arrête et l'image n'est pas écrite.")
        }
        'swap' { $act = (T "Changer de disquette : insérez une autre disquette sacrifiée, cochez la case, puis cliquez sur « Changer de disquette » ; la calibration reprend à la première passe, avec les mêmes réglages, et la disquette à écrire vous sera redemandée ensuite.`nContinuer : la calibration se poursuit sur cette disquette.`nArrêter : la calibration s'arrête et l'image n'est pas écrite.") }
        'restore-swap' { $act = (T "Changer de disquette : insérez une autre disquette sacrifiée, cochez la case, puis cliquez sur « Changer de disquette » ; la calibration reprend à la première passe, et la disquette de destination vous sera redemandée ensuite.`nContinuer : la calibration se poursuit sur cette disquette.`nArrêter : la calibration et la restauration s'arrêtent.") }
        'restore' {
            # Defaut de vitesse seul (arbitrage 12) : une autre disquette de destination n y changerait rien
            $act = if ($spd) { (T "Continuer : la calibration se poursuit sur cette disquette, puis la copie y est écrite.`nArrêter : la calibration et la restauration s'arrêtent.") }
                   else { (T "La calibration se fait sur la disquette de destination, déjà contrôlée par la restauration : elle ne peut pas être changée ici.`nContinuer : la calibration se poursuit sur cette disquette, puis la copie y est écrite.`nArrêter : la calibration et la restauration s'arrêtent ; relancez la restauration avec une autre disquette de destination.") }
        }
        'redo' { $act = (T "Changer de disquette : insérez une autre disquette sacrifiée, cochez la case, puis cliquez sur « Changer de disquette » ; la calibration B reprend à la première passe.`nContinuer : la calibration B se poursuit sur cette disquette.`nArrêter : la calibration B s'arrête, puis vous décidez de la courbe A.") }
        default { $act = (T "Changer de disquette : insérez une autre disquette sacrifiée, cochez la case, puis cliquez sur « Changer de disquette » ; la calibration reprend à la première passe, avec les mêmes réglages et sans nouvel avertissement.`nContinuer : la calibration se poursuit sur cette disquette.`nArrêter : la calibration s'arrête, rien de plus n'est écrit.") }
    }
    if (-not $opt.Change -and $opt.Variant -ne 'restore') { $act = (@($act -split "`n") | Select-Object -Skip 1) -join "`n" }
    $t += $pre + $act
    $t += "`n`n" + (T "Pas de décision automatique : la calibration attend votre réponse. Fermer la fenêtre équivaut à « Arrêter ».")
    return $t
}

function Get-CalibMediumCheck($tracks, [int[]]$cyls, [int]$bits, [int]$rpm) {
    # 12.7 : vitesse du lecteur et densite relue a la passe 1 (champs IndexMs et NFlux de ScpRev, deja lus), toutes
    # familles. En calibration, la cellule mesuree vaut duree du tour / cellules du motif : « cellule a +/- 10 % de celle
    # du motif » (arbitrage 1) equivaut a « tour a +/- 10 % de 60 000 / tr/min ms ». Flux attendus par tour :
    # CalFluxPerCell x cellules. Par piste : mediane des tours ; tour sans IndexMs positif (objets simules des tests) :
    # ignore ; face sans piste mesuree : non jugee, absente de la ligne de journal (aucune ligne si aucune face).
    $revMs = 60000.0 / [double]$rpm; $nfx = $script:CalFluxPerCell * [double]$bits
    $res = @{ Faces = @{}; Gross = $false; Rot = $false; Flux = $false; Lines = @(); Log = $null; RevMs = $revMs }
    $parts = @()
    foreach ($h in 0, 1) {
        $tr = @(); $fr = @(); $im = @()
        foreach ($c in $cyls) {
            $tn = [int]$c * 2 + $h
            if (-not $tracks.ContainsKey($tn)) { continue }
            $revs = @($tracks[$tn] | Where-Object { $null -ne $_ -and $null -ne $_.IndexMs -and [double]$_.IndexMs -gt 0 })
            if ($revs.Count -eq 0) { continue }
            $m = [double](Get-Median @($revs | ForEach-Object { [double]$_.IndexMs }))
            $im += $m; $tr += $m / $revMs
            $fr += [double](Get-Median @($revs | ForEach-Object { [double]$_.NFlux })) / $nfx
        }
        $n = $tr.Count
        $f = @{ N = $n; RevMed = [double]::NaN; FluxMed = [double]::NaN; RotBad = 0; FluxBad = 0; RotGross = $false; FluxGross = $false }
        if ($n -gt 0) {
            $f.RevMed = [double](Get-Median $im); $f.FluxMed = [double](Get-Median $fr)
            $f.RotBad = @($tr | Where-Object { [math]::Abs($_ - 1.0) -gt $script:CalSurfRotTol }).Count
            $f.FluxBad = @($fr | Where-Object { [math]::Abs($_ - 1.0) -gt $script:CalSurfFluxTol }).Count
            $need = [math]::Max(1, [int][math]::Ceiling($script:CalSurfGrossFrac * $n))
            $f.RotGross = ($f.RotBad -ge $need); $f.FluxGross = ($f.FluxBad -ge $need)
            $parts += ((T "face {0} : tour de {1} ms en médiane ({2} ms attendues), flux à {3} % du motif") -f "$h", (Format-UiNum $f.RevMed '0.00'), (Format-UiNum $revMs '0.#'), (Format-UiNum (100.0 * $f.FluxMed) '0.0'))
            if ($f.RotGross) { $res.Rot = $true; $res.Lines += ((T "face {0} : tour de {1} ms en médiane au lieu de {2} ms ({3} piste(s) sur {4}) : lecteur à environ {5} tr/min, ce type de disquette en demande {6}") -f "$h", (Format-UiNum $f.RevMed '0.0'), (Format-UiNum $revMs '0.#'), "$($f.RotBad)", "$n", "$([int][math]::Round(60000.0 / $f.RevMed))", "$rpm") }
            if ($f.FluxGross) { $res.Flux = $true; $res.Lines += ((T "face {0} : nombre de flux à {1} % de celui du motif en médiane ({2} piste(s) sur {3} à plus de {4} % d'écart) : la densité relue n'est pas celle du motif écrit") -f "$h", (Format-UiNum (100.0 * $f.FluxMed) '0'), "$($f.FluxBad)", "$n", (Format-UiNum (100.0 * $script:CalSurfFluxTol) '0')) }
        }
        $res.Faces[$h] = $f
    }
    $res.Gross = ($res.Rot -or $res.Flux)
    if ($parts.Count -gt 0) { $res.Log = ((T "Contrôle de vitesse et de densité (passe 1) : {0}.") -f ($parts -join ' ; ')) }
    return $res
}

function Test-CalibSurfaceGross($sf, $mc) {
    # Arbitrage 1 de la 12.7 : defaut grossier de la disquette de calibration, qui ouvre la fenetre du controle de surface
    # pendant la calibration ; une face suffit : au moins CalSurfGrossFrac de ses cylindres testes defectueux selon les
    # regles de Get-CalibSurface (une face sans aucun tour mesurable en fait partie : toutes ses pistes sont illisibles),
    # ou vitesse du lecteur ou densite relue hors tolerance (Get-CalibMediumCheck, arbitrage 10). Disquette douteuse
    # sans defaut grossier : reserve au bilan (Format-CalibSurfaceReserve), sans fenetre pendant la calibration.
    if ($mc -and $mc.Gross) { return $true }
    foreach ($h in 0, 1) {
        $f = $sf.Faces[$h]
        if (-not $f -or [int]$f.N -le 0) { continue }
        if (@($f.Bad).Count -ge [math]::Max(1, [int][math]::Ceiling($script:CalSurfGrossFrac * [int]$f.N))) { return $true }
    }
    return $false
}

function Test-CalibSpeedOnly($sf, $mc) {
    # 12.7 : defaut grossier de la seule vitesse du lecteur (duree du tour hors tolerance, Get-CalibMediumCheck), sans face
    # defectueuse au controle de surface : le lecteur est en cause, pas la disquette (addendum HD, § 4.4 : paragraphe de
    # vitesse). Fenetre sans « Changer de disquette » ni paragraphe haute densite, verdicts qui nomment le lecteur
    if (-not $mc -or -not $mc.Rot) { return $false }
    if ($sf -and ($sf.Defective -or (Test-CalibSurfaceGross $sf $null))) { return $false }
    return $true
}

function Format-CalibSurfaceVerdict($sf, $mc) {
    # Resume d un defaut grossier (journal, bilan d une calibration poursuivie) : faces douteuses, puis vitesse du lecteur
    # et densite relue hors tolerance
    $p = @()
    $s = Format-CalibSurfaceShort $sf; if ($s) { $p += $s }
    if ($mc -and $mc.Rot) { $p += (T 'vitesse du lecteur différente de celle du type de disquette') }
    if ($mc -and $mc.Flux) { $p += (T 'densité relue différente de celle du motif') }
    return ($p -join ' ; ')
}

function Format-CalibSurfaceReserve($sf) {
    # Arbitrage 1 de la 12.7 : reserve de la fenetre de decision pour une disquette douteuse sans defaut grossier (pistes
    # defectueuses de la passe 1 par face et par nature ; intervalles hors classe sur toute une face)
    $p = @(); $n = 0
    foreach ($h in 0, 1) {
        $f = $sf.Faces[$h]
        if (-not $f) { continue }
        if ($f.Noisy) { $p += ((T "face {0} : intervalles hors classe sur toute la face ({1} par tour en médiane)") -f "$h", (Format-UiNum $f.OocMed)) }
        $b = @($f.Bad); $n += $b.Count
        if ($b.Count) { $p += ((T "face {0} : {1}") -f "$h", (Get-CalibSurfaceReasons $b)) }
    }
    if ($n -eq 0) { return ((T "support : {0} à la première passe") -f ($p -join ' ; ')) }
    return ((T "support : {0} piste(s) défectueuse(s) à la première passe ({1})") -f "$n", ($p -join ' ; '))
}

function Get-LevelSurface($tracks, $cal, [int]$rpm) {
    # 12.7 point 5 : controle de surface (Get-CalibSurface) et de vitesse et de densite (Get-CalibMediumCheck) de la
    # premiere passe de la calibration rapide, chaque face sur ses cylindres ecrits a cette passe (cibles de ses unites :
    # cylindres de niveau, temoins de marche et du plafond ; courbe commune : memes cylindres pour les deux faces). Les
    # deux fonctions jugent chaque face a part : appel par face quand les cylindres different (pistes de la seule face
    # pour Get-CalibMediumCheck : une ligne de vitesse par face). Renvoie @{ Surf ; Medium ; Logs }.
    $cy = @{ 0 = @{}; 1 = @{} }
    foreach ($u in @($cal.Units)) {
        $hs = if ($null -eq $u.Head) { @(0, 1) } else { @([int]$u.Head) }
        foreach ($c in @($u.LTarget.Keys)) { foreach ($h in $hs) { $cy[$h][[int]$c] = $true } }
    }
    $c0 = [int[]]@($cy[0].Keys | Sort-Object); $c1 = [int[]]@($cy[1].Keys | Sort-Object)
    $bits = [int]$cal.PatternBits
    if (($c0 -join ',') -eq ($c1 -join ',')) {
        $mc = Get-CalibMediumCheck $tracks $c0 $bits $rpm
        return @{ Surf = (Get-CalibSurface $tracks $c0); Medium = $mc; Logs = @($(if ($mc.Log) { $mc.Log })) }
    }
    $sf = @{ Faces = @{}; Bad = @(); Defective = $false; Why = @() }
    $mc = @{ Faces = @{}; Gross = $false; Rot = $false; Flux = $false; Lines = @(); Log = $null; RevMs = 60000.0 / [double]$rpm }
    $logs = @()
    foreach ($h in 0, 1) {
        $cs = if ($h -eq 0) { $c0 } else { $c1 }
        $f = (Get-CalibSurface $tracks $cs).Faces[$h]
        $sf.Faces[$h] = $f; $sf.Bad += @($f.Bad)
        if ($f.Defective) { $sf.Defective = $true; $sf.Why += $h }
        $th = @{}; foreach ($c in $cs) { $tn = [int]$c * 2 + $h; if ($tracks.ContainsKey($tn)) { $th[$tn] = $tracks[$tn] } }
        $m1 = Get-CalibMediumCheck $th $cs $bits $rpm
        $mc.Faces[$h] = $m1.Faces[$h]
        if ($m1.Rot) { $mc.Rot = $true }
        if ($m1.Flux) { $mc.Flux = $true }
        $mc.Lines += @($m1.Lines)
        if ($m1.Log) { $logs += $m1.Log }
    }
    $mc.Gross = ($mc.Rot -or $mc.Flux)
    return @{ Surf = $sf; Medium = $mc; Logs = $logs }
}

function Get-LevelSurfaceText($sf, $mc, [bool]$restore, [bool]$spd, [string[]]$notes) {
    # 12.7 point 5 : texte de la fenetre « Disquette a ecrire defectueuse » : synthese par face (compteurs du journal),
    # vitesse et densite relue, risque, conseil de nettoyage (arbitrage 14), choix, absence de decision automatique
    $t = if ($spd) { (T 'Le lecteur ne tourne pas à la vitesse de ce type de disquette. La première passe de la mesure du niveau, où le motif de test est écrit sur les cylindres mesurés puis relu sur 3 tours, a trouvé :') }
         else { (T 'La disquette à écrire semble défectueuse. La première passe de la mesure du niveau, où le motif de test est écrit sur les cylindres mesurés puis relu sur 3 tours, a trouvé :') }
    foreach ($x in (Get-CalibSurfaceFaceLines $sf)) { $t += "`n  - " + $x }
    foreach ($x in @($mc.Lines)) { if ($x) { $t += "`n  - " + $x } }
    if ($spd) { $t += "`n" } else { $t += "`n`n" + (T "Sur une telle disquette, l'image risque d'être mal écrite et mal relue.") }
    foreach ($x in @($notes)) { if ($x) { $t += "`n" + $x } }
    if (Test-CalibCleanHint $sf $mc $false) { $t += "`n" + (T "Des trous de signal sur les deux faces viennent souvent de têtes sales : nettoyez-les (carte « Nettoyer les têtes du lecteur » de l'Accueil), puis recommencez.") }
    # Restauration, defaut de vitesse seul (arbitrage 12) : une autre disquette de destination n y changerait rien
    $t += "`n`n" + $(if ($restore -and $spd) { (T "Écrire quand même : la mesure du niveau se poursuit, puis la copie est écrite sur cette disquette.`nArrêter : la restauration s'arrête.") }
                     elseif ($restore) { (T "Écrire quand même : la mesure du niveau se poursuit, puis la copie est écrite sur cette disquette.`nArrêter : la restauration s'arrête ; relancez-la avec une autre disquette de destination.") }
                     else { (T "Écrire quand même : la mesure du niveau se poursuit, puis l'image est écrite sur cette disquette.`nArrêter : rien de plus n'est écrit, l'image n'est pas écrite.") })
    $t += "`n`n" + (T "Pas de décision automatique : l'écriture attend votre réponse. Fermer la fenêtre équivaut à « Arrêter ».")
    return $t
}

function Invoke-LevelSurface($cal, $tracks) {
    # 12.7 point 5 : etat de la surface de la disquette sur la relecture de la premiere passe de la calibration rapide
    # (regles du controle de surface du point 1, cylindres mesures : Get-LevelSurface). Bilan par face toujours au
    # journal. Defaut grossier (arbitrage 1 ; vitesse et densite : arbitrage 10) avant une ecriture : fenetre bloquante sans
    # compte a rebours (Show-CalibSurface, variante 'level' : « Ecrire quand meme », « Arreter », fermeture = Arreter),
    # avant l ecriture de l image ; defaut modere, ou defaut grossier d une calibration rapide sans ecriture : journal, et
    # reserve de la fenetre de decision si elle s ouvre (Complete-LevelCalib). Renvoie $false si l ecriture est arretee.
    $cal.SurfDone = $true
    $rpm = if ($cal.Rpm) { [int]$cal.Rpm } else { 300 }
    $r = Get-LevelSurface $tracks $cal $rpm
    $sf = $r.Surf; $mc = $r.Medium
    $gross = Test-CalibSurfaceGross $sf $mc
    $cal.Surf = $sf; $cal.Medium = $mc; $cal.SurfGross = $gross
    Append-Log ((T 'Contrôle de surface de la disquette (calibration rapide, passe 1, cylindres mesurés seulement) : {0}.') -f ((Get-CalibSurfaceFaceLines $sf) -join ' ; '))
    foreach ($l in @($r.Logs)) { Append-Log $l }
    $verdict = Format-CalibSurfaceVerdict $sf $mc
    # Decision 3 de decisions127-p5.md : liste « Calibration precomp » au test rapide (index 2 ; en restauration, celle d avant
    # la restauration) : chemins de la 12.6, sans fenetre ; journal et reserve seulement
    $cm = if ($script:Restore -and $script:Restore.Saved) { [int]$script:Restore.Saved.CalMode } else { [int]$cmbWCalMode.SelectedIndex }
    if ($gross -and $script:AfterCalib -eq 'write' -and $cm -ne 2) {
        # Arbitrage 12 : defaut de vitesse seul : journal et titre qui ne mettent pas la disquette en cause
        $spd = Test-CalibSpeedOnly $sf $mc
        if ($spd) { Append-Log ((T 'Contrôle de vitesse et de densité : {0} : décision demandée.') -f "$verdict") }
        else { Append-Log ((T 'Contrôle de surface : disquette à écrire défectueuse ({0}) : décision demandée.') -f "$verdict") }
        $notes = @()
        if ($mc.Rot) { $notes += (T "Vitesse du lecteur différente de celle du type de disquette : un format à 300 tr/min demande un lecteur à 300 tr/min (3,5 pouces, ou 5,25 pouces double densité), un format à 360 tr/min un lecteur à 360 tr/min (5,25 pouces haute densité, ou 3,5 pouces réglé à 360 tr/min). Changer de disquette n'y change rien.") }
        $opt = @{ Change = $false; SwapBox = $false; Variant = 'level'; Title = $(if ($spd) { (T 'Contrôle de surface') } else { (T 'Disquette à écrire défectueuse') }); GoText = (T 'Écrire quand même') }
        $txt = Get-LevelSurfaceText $sf $mc ([bool]$script:Restore) $spd $notes
        $cal.Hold = $true; Update-CalibProgress; if ($cal.Home) { Update-HomeCalibCard }
        if ($script:Restore) { $script:Restore.InCall = $true }
        try { $ch = Show-CalibSurface $opt $txt }
        finally { $cal.Hold = $false; if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
        if ($ch.Choice -ne 'continue') {
            Append-Log (T "Contrôle de surface : écriture arrêtée à votre demande, l'image n'est pas écrite.")
            Stop-PrecompCalib; return $false
        }
        $cal.SurfKept = $true
        Append-Log (T 'Contrôle de surface : écriture poursuivie sur cette disquette à votre demande.')
        return $true
    }
    if ($gross -or $sf.Defective) { Append-Log ((T "Contrôle de surface : disquette douteuse ({0}) ; la calibration rapide continue, avec une réserve si la fenêtre de décision s'ouvre.") -f "$verdict") }
    elseif (@($sf.Bad).Count) {
        $p = @(); foreach ($h in 0, 1) { $b = @($sf.Faces[$h].Bad); if ($b.Count) { $p += ((T "face {0} : {1}") -f "$h", (Get-CalibSurfaceReasons $b)) } }
        Append-Log ((T 'Contrôle de surface : défaut ponctuel de la disquette ({0}) ; la calibration rapide continue.') -f ($p -join ' ; '))
    }
    return $true
}
