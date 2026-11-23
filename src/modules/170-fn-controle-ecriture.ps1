# ============================== FONCTIONS : CONTROLE APRES ECRITURE ============

function Get-WriteCheckBlocker([string]$path, [string]$fmt) {
    # Raison pour laquelle l analyse de flux (calibree MFM double densite, cellule 2 us) ne s applique pas ; $null sinon
    if ($chkWHard.Checked) { return (T 'secteurs durs') }
    if ($chkWTG43.Checked) { return (T 'lecteur 8 pouces (TG43)') }
    $hd = Get-HighDensityReason $path $fmt
    if ($hd) { return $hd }
    # 12.10 (lot 1, B1) : codage de l image par Get-ImageEncoding (format explicite de la table, sinon format implicite de
    # l extension, sinon en-tete HFE, IMD ou D88) ; textes inchanges, l image FM (SSD, DSD, HFE, IMD, D88) s y ajoute.
    # GCR et FM : les criteres sont ceux du MFM. Piste 0 en FM, les autres en MFM (codage fm0 de la table : tsc.flex.*,
    # olivetti.m20...) : la piste 0 serait jugee avec les criteres du MFM et pourrait etre reecrite a tort ; controle bloque
    # pour tout le format
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    $ie = Get-ImageEncoding $path $fmt
    $fx = ($fmt -and $fmt -ne '(auto)')
    if ($ie.Enc -eq 'gcr') { if ($fx) { return ((T "format GCR {0}") -f "$fmt") }; return ((T "image GCR {0}") -f "$ext") }
    if ($ie.Enc -eq 'fm') { if ($fx) { return ((T "format FM {0}") -f "$fmt") }; return ((T "image FM {0}") -f "$ext") }
    if ($ie.Enc -eq 'fm0' -and $fx) { return ((T "piste 0 en FM, format {0}") -f "$fmt") }
    # Images GCR sans format implicite de gw (G64, NIB, WOZ), et extension GCR avec un format MFM explicite, comme en 12.8
    if (@('.d64', '.d71', '.g64', '.nib', '.woz', '.do', '.po') -contains $ext) { return ((T "image GCR {0}") -f "$ext") }
    try {
        if ($ext -eq '.scp' -and $script:ScpStatsOk -and (Test-ScpHighDensity $path)) { return (T 'flux SCP haute densité') }
    } catch { }
    return $null
}

function New-WriteCheck([string[]]$base, [string]$image, [string]$userTSpec, [int]$max, [string[]]$readOpts, $headPrecomp, [string]$eraseMode = '') {
    # $headPrecomp : ecriture lente, --precomp par tete logique (0, 1 -> profil ou $null) ; $base est alors sans --precomp
    # 12.8.2 : $eraseMode, effacement des reecritures (Invoke-WriteCheckAnalysis) : 'hfreq' (double densite) ou 'pre'
    # (haute densite, flux SCP de densite inconnue, secteurs durs, TG43, --densel : Get-EraseMode) ; vide : d apres l image
    # et le format de l onglet (150). Revue 12.8.2 : jamais le repli « pistes de l image inconnues » de l ecriture
    # (Start-ImageWrite, $emCheck) : les pistes faibles sont toujours connues
    $script:WriteTracks = @{}; $script:WriteRetries = @{}   # rien d une ecriture precedente dans le perimetre
    if (-not $eraseMode) { $eraseMode = Get-EraseMode (Test-ImageHighDensity $image $cmbWFmt.Text) }
    $script:Rep = @{
        Base = @($base); Image = $image; UserTSpec = $userTSpec; Max = [math]::Max(0, $max); EraseMode = $eraseMode
        Common = @(Get-CommonArgs); ReadOpts = @($readOpts)   # lecteur et port memorises au clic : les relectures visent le meme disque
        HeadPrecomp = $headPrecomp; Written = @{}              # Written : pistes ecrites, cumulees sur les commandes (ecriture lente)
        Round = 0; Scope = $null; Weak = @(); State = @{}; Retries = @{}; Rewrites = @{}
        Pending = (New-Object System.Collections.Queue); Scps = @(); Safety = $false; Measured = 0
        # Zone instable relue sur la copie = defaut de la copie, sauf source capable d en porter (voir Set-CopyUnstable)
        UnstDefect = (-not (Test-SourceMayHaveWeak $image)); NoJudge = $null; SrcWeak = $null
        SrcOver = $null                                        # 12.8.2 : pistes deja hors norme dans la source (Test-SrcOverErr)
    }
    # Une mesure continue de l onglet Qualite ecraserait le resultat du controle : elle est arretee
    $script:AlignLoop = $false; $script:AlignNextAt = $null; $script:AlLastMove = 0
    # 12.11 (L11) : ecriture suivie par la barre de l onglet (Start-WriteProgress, 160, appelee juste avant) : libelle et
    # barre sont les siens ; restauration (barre de l onglet non posee) : libelle de la 12.10, barre masquee
    if (-not $script:WriteProg) {
        $lblWCal.Text = (T 'Écriture en cours, contrôle de toutes les pistes ensuite.')
        $pbWCal.Visible = $false; $lblWCal.Visible = $true
    }
    # 12.8 (lot 3a) : resultat de l onglet Qualite grise et marque « controle en cours » pendant l ecriture et le controle
    Set-QualityPending 'check'
}

function Test-SourceMayHaveWeak([string]$path) {
    # Sources dont gw ecrit les zones faibles comme une zone sans flux (une transition toutes les 32 cellules, track.py
    # MasterTrack.force_random_weak), relue volontairement instable : IPF (CAPS), HFE v3 (opcode Rand), EDSK (secteur
    # stocke en plusieurs copies). Flux .raw, .kf, .a2r, .ctr : non analyses. Fichier illisible : prudence.
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    if (@('.ipf', '.raw', '.kf', '.a2r', '.ctr') -contains $ext) { return $true }
    if (@('.hfe', '.dsk', '.edsk') -notcontains $ext) { return $false }
    try {
        $fs = [System.IO.File]::OpenRead($path)
        try { $b = New-Object byte[] 16; $n = $fs.Read($b, 0, 16) } finally { $fs.Dispose() }
        $s = [System.Text.Encoding]::ASCII.GetString($b, 0, $n)
        return ($s.StartsWith('HXCHFEV3') -or $s.StartsWith('EXTENDED CPC DSK'))
    } catch { return $true }
}

function Test-RepFakeIndex($rep) {
    # 12.8.2 (S11) : relectures du controle avec un index simule (--fake-index des options de relecture, Rep.ReadOpts, ou
    # de l ecriture, Rep.Base) : la jonction d ecriture n est pas a l index relu, la zone de l index est comptee
    return (@(@($rep.ReadOpts) + @($rep.Base) | Where-Object { "$_" -match '^--fake-index=' }).Count -gt 0)
}

function Test-SrcOverErr($m) {
    # 12.8.2 (decision du 27/10/2026) : piste de la source (original en restauration, image SCP de l onglet Ecriture) deja
    # hors norme par ses erreurs, au-dela du seuil SAIN (HealthErrOk, Get-HealthLevel) : protection (Copylock) ou defaut
    # d origine, qu une reecriture ne peut pas corriger. Le controle de la copie l ignore comme une piste critique : ni
    # reecrite, ni comptee faible. Piste illisible : non (deja critique).
    return ($null -ne $m -and -not $m.Bad -and [double]$m.Ooc -gt $script:HealthErrOk)
}

function Set-CopyUnstable($rep, [string]$k, $m) {
    # gw ecrit un tour fige de la source : une zone instable d un tour a l autre relue sur la copie ne vient pas de la
    # source quand celle-ci n en contient pas a cette piste (image secteur, HFE v1/v2, piste stable d un SCP analyse).
    # Elle signale alors un defaut de la copie (usure ou defaut localise) : la piste est faible et reecrite.
    # Pistes instables, critiques ou (12.8.2) deja hors norme de la source (Rep.Ignore) : traitees a part. Non jugees
    # (Unjudged : ni reecrites ni comptees saines) : source qui peut porter des zones faibles (Test-SourceMayHaveWeak), SCP
    # non analysable, piste que la source porte avec une courte zone instable ou que l analyse n a pas pu mesurer
    # (Rep.NoJudge).
    if (-not $m -or $m.Bad -or -not $m.Weak) { return }
    if ($rep.Ignore -and $rep.Ignore.ContainsKey($k)) { return }
    if (-not $rep.UnstDefect -or ($rep.NoJudge -and $rep.NoJudge.ContainsKey($k))) { $m.Unjudged = $true; return }
    $m.CopyDefect = $true
    if ($m.Level -lt 1) { $m.Level = 1 }
}

function Merge-RepRetries {
    # Retries et pistes ecrites de la derniere ecriture gw (remis a zero a chaque nouvelle ecriture) -> cumul du controle
    $rep = $script:Rep
    if (-not $rep) { return }
    foreach ($k in @($script:WriteTracks.Keys)) { $rep.Written[$k] = $true }
    foreach ($k in @($script:WriteRetries.Keys)) {
        $n = [int]$script:WriteRetries[$k]
        if (-not $rep.Retries.ContainsKey($k) -or $n -gt $rep.Retries[$k]) { $rep.Retries[$k] = $n }
    }
}

function Add-RepReads($groups, [string]$extras) {
    # Relectures en flux d un groupe de TSPEC, un fichier SCP par commande
    $rep = $script:Rep
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $rep.Scps = @(); $i = 0
    foreach ($g in @($groups)) {
        $scp = Join-Path $script:TempDir ("check-r{0}-{1}.scp" -f $rep.Round, $i)
        if (Test-Path -LiteralPath $scp) { Remove-Item -LiteralPath $scp -Force }
        $rep.Pending.Enqueue([string[]](@('read') + $rep.Common + $rep.ReadOpts + @('--revs=3', "--tracks=$g$extras", "`"$scp`"")))
        $rep.Scps += $scp; $i++
    }
}

function Start-RepPending {
    # Une etape de chaine par commande en file, puis l analyse
    $rep = $script:Rep
    # 12.11 (L11) : passe du controle dans la barre de l onglet (Step-WriteProgress, 160) : plan de ses commandes, file de
    # la passe inchangee ; affichage seulement
    Step-WriteProgress @($rep.Pending.ToArray())
    $script:Chain.Clear()
    for ($i = 0; $i -lt $rep.Pending.Count; $i++) { $script:Chain.Enqueue({ Invoke-RepNextCmd }) }
    $script:Chain.Enqueue({ Invoke-WriteCheckAnalysis })
    Invoke-NextChainStep
}

function Invoke-RepNextCmd {
    $rep = $script:Rep
    if (-not $rep -or $rep.Pending.Count -eq 0) { return }
    Merge-RepRetries
    $cmd = [string[]]$rep.Pending.Dequeue()
    if ($rep.Round -eq 0) { $lblWCal.Text = (T 'Contrôle après écriture : relecture de toutes les pistes...') }
    # 12.11 rc7 (R16) : passe 1 avec des zones ecartees de l attendu (Start-WriteZonePass) : pistes faibles et pistes des zones
    elseif ($rep.ZonePass -and $cmd[0] -eq 'write') { $lblWCal.Text = ((T "Contrôle après écriture : réécriture {0}/{1} de {2} piste(s) (pistes faibles et zones écartées de l'attendu)...") -f "$($rep.Round)", "$($rep.Max)", "$($rep.Weak.Count)") }
    elseif ($rep.ZonePass -and $cmd[0] -eq 'erase') { $lblWCal.Text = ((T "Contrôle après écriture : effacement haute fréquence avant la réécriture {0}/{1} de {2} piste(s) (pistes faibles et zones écartées de l'attendu)...") -f "$($rep.Round)", "$($rep.Max)", "$($rep.Weak.Count)") }
    elseif ($cmd[0] -eq 'write') { $lblWCal.Text = ((T "Contrôle après écriture : réécriture {0}/{1} de {2} piste(s) faible(s)...") -f "$($rep.Round)", "$($rep.Max)", "$($rep.Weak.Count)") }
    elseif ($cmd[0] -eq 'erase') { $lblWCal.Text = ((T "Contrôle après écriture : effacement haute fréquence avant la réécriture {0}/{1} de {2} piste(s) faible(s)...") -f "$($rep.Round)", "$($rep.Max)", "$($rep.Weak.Count)") }
    else { $lblWCal.Text = ((T "Contrôle après écriture : remesure {0}/{1} de {2} piste(s)...") -f "$($rep.Round)", "$($rep.Max)", "$($rep.Weak.Count)") }
    Set-QualityRunText $lblWCal.Text                      # 12.8 (lot 3a) : etape du controle sur la carte de l onglet Qualite
    Start-Gw $cmd
}

function Enter-CheckTab {
    # 12.10 (lot 1, E11) : onglet Qualite & alignement affiche pendant la relecture du controle apres ecriture, pour tout
    # controle hors restauration (ECRIRE, Bibliotheque, controle impose : E11-2) ; onglet d avant memorise pour le retour
    # (Exit-CheckTab). Restauration exclue (E11-3) : pages verrouillees par Set-RsLock, etape « Controler toutes les
    # pistes » de l onglet Restauration
    if ($script:Restore -or $script:CheckTabReturn) { return }
    $script:CheckTabReturn = $tabs.SelectedTab
    if ($tabs.SelectedTab -ne $tabAl) { Show-Tab $tabAl }
}

function Exit-CheckTab {
    # 12.10 (lot 1, E11) : fin, arret ou erreur du controle : retour a l onglet d avant (E11-1), sauf si l utilisateur en a
    # choisi un autre entre-temps (onglets actifs entre deux commandes gw ; Set-Busy inchange)
    $t = $script:CheckTabReturn; $script:CheckTabReturn = $null
    if ($t -and $t -ne $tabAl -and $tabs.SelectedTab -eq $tabAl -and $tabs.TabPages.Contains($t)) { $tabs.SelectedTab = $t }
}

function Start-WriteCheck {
    # Etape de chaine apres l ecriture initiale (code retour 0) : relecture de toutes les pistes ecrites
    $rep = $script:Rep
    if (-not $rep) { return }
    Merge-RepRetries
    if (-not $script:ScpStatsOk) {
        Append-Log (T 'Contrôle après écriture : module d''analyse SCP indisponible, contrôle ignoré.'); $script:Rep = $null; Set-QualityStale 'checkabort'
        if ($script:Restore) { Stop-Restore (T 'contrôle des pistes indisponible') }
        return
    }
    # Perimetre = pistes que gw a reellement ecrites (lignes « Writing Track » ; une piste vide effacee n en a pas),
    # limitees a l image quand ses pistes sont connues. A defaut : pistes de l image, puis 80 x 2.
    # 12.8 (FIX-PISTES, essai du 21/10/2026) : toujours limite aux pistes retenues par c= et h= du champ Pistes (ecriture de
    # c=0:h=0 dont la piste est vide dans l image : 158 pistes de l image relues auparavant) ; c= illisible : non limite
    $img = Get-ImageTrackSet $rep.Image
    $sel = Get-TSpecSelection $rep.UserTSpec
    if (@($sel.Heads).Count -eq 0) { $sel.Heads = @(0, 1) }
    $set = @{}; $cut = 0
    foreach ($k in @($rep.Written.Keys)) {
        if ($null -ne $img -and -not $img.ContainsKey($k)) { continue }
        if (Test-TSpecKey $sel $k) { $set[$k] = $true } else { $cut++ }
    }
    if ($set.Count -eq 0) {
        $all = $img
        if ($null -eq $all) {
            $all = @{}
            $n = Get-ImageCylinders $rep.Image; if ($null -eq $n) { $n = 80 }
            for ($c = 0; $c -lt [int]$n; $c++) { $all["$c.0"] = $true; $all["$c.1"] = $true }
        }
        $cut = 0
        foreach ($k in @($all.Keys)) { if (Test-TSpecKey $sel $k) { $set[$k] = $true } else { $cut++ } }
        if ($set.Count -eq 0 -and $cut -gt 0 -and -not $script:Restore) {
            # Aucune piste de l image dans le champ Pistes (piste vide de l image, effacee ou sautee par gw) : rien a relire,
            # aucun verdict ; resultat de l onglet Qualite marque perime avec la raison
            Append-Log ((T "Contrôle après écriture : aucune piste de l'image dans le champ Pistes (« {0} ») : rien à relire (piste vide de l'image, effacée ou sautée par gw).") -f "$($rep.UserTSpec.Trim())")
            $script:Rep = $null
            $pbWCal.Visible = $false; $lblWCal.Text = (T 'Contrôle après écriture : aucune piste à relire.'); $lblWCal.Visible = $true
            Set-QualityStale 'checknone'
            return
        }
    }
    $rep.Scope = $set
    $rep.Round = 0
    $groups = Get-TrackGroups @($set.Keys)                # pistes exactes ecrites, memes elements step/offsets que l ecriture
    if ($cut -gt 0) { Append-Log ((T "Contrôle après écriture : relecture en flux de {0} piste(s) de l'image, celles du champ Pistes (« {1} ») (3 tours).") -f "$($set.Count)", "$($rep.UserTSpec.Trim())") }
    else { Append-Log ((T "Contrôle après écriture : relecture en flux de {0} piste(s) de l'image (3 tours).") -f "$($set.Count)") }
    $rep.Pending.Clear()
    Enter-CheckTab                                        # 12.10 (lot 1, E11) : seulement si une relecture commence
    Add-RepReads $groups (Get-TSpecExtras $rep.UserTSpec)
    Start-RepPending
}

function Invoke-WriteCheckAnalysis {
    $rep = $script:Rep
    if (-not $rep) { return }
    Merge-RepRetries
    if ($rep.Round -gt 0) {
        # Passe terminee : toutes ses ecritures et relectures ont rendu le code 0
        foreach ($k in @($rep.Weak)) { $rep.Rewrites[$k] = 1 + $(if ($rep.Rewrites.ContainsKey($k)) { [int]$rep.Rewrites[$k] } else { 0 }) }
    }
    $tracks = @{}
    $fake = Test-RepFakeIndex $rep
    foreach ($scp in $rep.Scps) {
        if (-not (Test-Path -LiteralPath $scp)) { Append-Log (T 'Contrôle après écriture : fichier SCP absent, analyse impossible.'); Stop-WriteCheck; return }
        try { $t = Read-ScpFile $scp -NoIndexZone:$fake } catch { Append-Log ((T "Contrôle après écriture : {0}") -f "$($_.Exception.Message)"); Stop-WriteCheck; return }
        foreach ($tn in $t.Keys) { $tracks[[int]$tn] = $t[$tn] }
    }
    # Pistes attendues : premier controle = image (ou TSPEC utilisateur relu, limite a l image) ; ensuite = pistes reecrites
    if ($rep.Round -eq 0) { $expected = @($rep.Scope.Keys) } else { $expected = @($rep.Weak) }
    $expected = Sort-TrackKeys $expected
    $watch = @(); $crit = @(); $healthy = 0
    foreach ($k in $expected) {
        $tn = Get-TrackKeyOrder $k
        if ($tracks.ContainsKey($tn)) { $m = Get-TrackMetrics $tracks[$tn] }
        else { $m = Get-TrackMetrics @(); $m.Missing = $true }
        Set-CopyUnstable $rep $k $m
        $rep.State[$k] = $m
        if ($m.Bad -or $m.Level -ge 2) { $crit += $k } elseif ($m.Level -eq 1) { $watch += $k }
        elseif (-not $m.Unjudged -and -not ($m.Weak -and $rep.Ignore -and $rep.Ignore.ContainsKey($k))) { $healthy++ }
    }
    $unjK = @($expected | Where-Object { $rep.State[$_].Unjudged -and -not $rep.State[$_].Bad -and $rep.State[$_].Level -lt 1 })
    if ($unjK.Count -gt 0 -and $rep.Round -eq 0) { Append-Log ((T "Contrôle : zone instable sur {0} piste(s) non jugée(s) ({1}) : la source peut en contenir (protection) sans que l'application puisse le vérifier. Ni réécrites ni comptées comme saines.") -f "$($unjK.Count)", "$(Format-TrackList $unjK)") }
    $defK = @($expected | Where-Object { $rep.State[$_].CopyDefect })
    if ($defK.Count -gt 0) { Append-Log ((T "Contrôle : zone instable d'un tour à l'autre sur la copie, piste(s) {0} : la source n'en contient pas, défaut probable du support. Ces pistes sont traitées comme faibles.") -f "$(Format-TrackList $defK)") }
    # 12.8.2 (S11, S12) : hors classe de la zone de l index (jonction d ecriture de gw) ecartes du comptage, avec la
    # distance a l index la plus grande, et pistes dont la stabilite n a pas pu etre mesuree sur tours alignes : une
    # ligne par analyse ; index simule : une ligne au premier controle
    # 12.10 (S13) : so / sot, hors classe reproductibles retires ; sov, pistes au-dela du plafond ScpStructMax par tour (tout
    # compte), sauf celles que le controle ne compte pas (Rep.Ignore : deja critiques, non reproductibles ou hors norme dans
    # la source, ligne a part)
    $zo = 0; $zt = 0; $zf = 0; $fb = @(); $so = 0; $sot = 0; $sov = @()
    foreach ($k in $expected) {
        $ms = $rep.State[$k]; $z = [int]$ms.ZoneOoc
        if ([int]$ms.StructOoc -gt 0) { $so += [int]$ms.StructOoc; $sot++ }
        if ([int]$ms.StructOver -gt 0 -and -not ($rep.Ignore -and $rep.Ignore.ContainsKey($k))) { $sov += $k }
        if ($z -gt 0) { $zo += $z; $zt++; if ([int]$ms.ZoneFarNs -gt $zf) { $zf = [int]$ms.ZoneFarNs } }
        if ($ms.StabFallback) { $fb += $k }
    }
    if ($zo -gt 0) { Append-Log ((T "Contrôle après écriture : {0} intervalle(s) hors classe du raccord d'écriture de gw, dans la zone de ± 1 ms autour de l'index (jusqu'à {2} ms), non compté(s), sur {1} piste(s) relue(s) en 3 tours.") -f "$zo", "$zt", (Format-UiNum ($zf / 1e6) '0.00')) }
    if ($so -gt 0) { Append-Log ((T "Contrôle après écriture : {0} intervalle(s) hors classe reproductibles d'un tour à l'autre à la même position, sur {1} piste(s), non compté(s) : raccord d'écriture d'une longue piste ou protection.") -f "$so", "$sot") }   # 12.10 (S13)
    if ($sov.Count -gt 0) { Append-Log ((T "Contrôle après écriture : {0} piste(s) avec plus de {1} intervalles hors classe reproductibles par tour, tous comptés comme erreurs (au-delà d'un raccord d'écriture ou d'une protection : défaut du support ou écriture à revoir) : {2}.") -f "$($sov.Count)", "$($script:ScpStructMax)", "$(Format-TrackList $sov)") }
    if ($fb.Count -gt 0) { Append-Log ((T "Contrôle après écriture : stabilité de {0} piste(s) jugée sur l'écart du nombre de flux entre les tours, faute de repère commun pour les aligner : {1}.") -f "$($fb.Count)", "$(Format-TrackList $fb)") }
    if ($fake -and $rep.Round -eq 0) { Append-Log (T "Contrôle après écriture : index simulé (--fake-index), la zone de l'index est comptée comme le reste de la piste.") }
    if ($rep.Ignore) {
        # Restauration d un flux ou image SCP : pistes deja critiques ou non reproductibles (zone instable), non comptees.
        # 12.8.2 (decision du 27/10/2026) : pistes deja hors norme par leurs erreurs dans la source (Rep.SrcOver, aussi dans
        # Rep.Ignore : Copylock, defaut d origine), non reecrites, signalees par une ligne a part
        $ign = @(@($watch) + @($crit) | Where-Object { $rep.Ignore.ContainsKey($_) })
        $ovr = @($ign | Where-Object { $rep.SrcOver -and $rep.SrcOver.ContainsKey($_) })
        $ign = @($ign | Where-Object { -not ($rep.SrcOver -and $rep.SrcOver.ContainsKey($_)) })
        if ($ign.Count -gt 0 -and $rep.Round -eq 0) { Append-Log ((T "Contrôle : {0} piste(s) non reproductible(s) ou déjà critique(s) dans la source, non comptée(s) : {1}") -f "$($ign.Count)", "$(Format-TrackList $ign)") }
        if ($ovr.Count -gt 0 -and $rep.Round -eq 0) { Append-Log ((T "Contrôle : {0} piste(s) déjà hors norme dans l'original, non réécrite(s) : {1}") -f "$($ovr.Count)", "$(Format-TrackList (Sort-TrackKeys $ovr))") }
        $watch = @($watch | Where-Object { -not $rep.Ignore.ContainsKey($_) }); $crit = @($crit | Where-Object { -not $rep.Ignore.ContainsKey($_) })
    }
    $weak = Sort-TrackKeys (@($watch) + @($crit))
    $lw = if ($watch.Count -gt 0) { " : $(Format-TrackList $watch)" } else { '' }
    $lc = if ($crit.Count -gt 0) { " : $(Format-TrackList $crit)" } else { '' }
    if ($rep.Round -eq 0) {
        $rep.Measured = $expected.Count
        Append-Log ((T "Contrôle complet : {0} piste(s) mesurée(s), {1} saine(s), {2} à surveiller{3}, {4} critique(s) ou illisible(s){5}.") -f "$($expected.Count)", "$healthy", "$($watch.Count)", "$lw", "$($crit.Count)", "$lc")
    } else {
        Append-Log ((T "Remesure après réécriture {0}/{1} : {2} piste(s), {3} saine(s), {4} à surveiller{5}, {6} critique(s) ou illisible(s){7}.") -f "$($rep.Round)", "$($rep.Max)", "$($expected.Count)", "$healthy", "$($watch.Count)", "$lw", "$($crit.Count)", "$lc")
    }
    $rep.Weak = $weak
    if ($expected.Count -eq 0) { Append-Log (T 'Contrôle après écriture : aucune piste mesurée.'); Complete-WriteCheck; return }
    # 12.11 rc7 (R16) : relecture de la passe 1 d une correction par zones : jugement de chaque zone (Complete-WriteZonePass),
    # les pistes d une zone reprise rejoignent les pistes faibles de la passe suivante
    if ($rep.Round -eq 1 -and $rep.ZonePass) { $weak = Complete-WriteZonePass $rep $weak; $rep.Weak = $weak }
    if ($weak.Count -gt 0) {
        # Garde-fou sur un controle large seulement : une selection de quelques pistes doit pouvoir etre reecrite
        # Garde-fou calcule aux seuils Standard : un reglage strict du jitter fait reecrire davantage, sans faux diagnostic
        $weakStd = @($weak | Where-Object { $s = $rep.State[$_]; $s.Bad -or (Get-HealthLevel $s.Ooc $s.Dr $s.Stab $s.J $script:JitterStdOk $script:JitterStdWatch) -ge 1 })
        if ($rep.Round -eq 0 -and $expected.Count -ge 20 -and $weakStd.Count * 2 -gt $expected.Count) {
            $rep.Safety = $true
            Append-Log ((T "Plus de la moitié des pistes sont faibles ({0}/{1}) : format non MFM, disquette inadaptée ou lecteur en défaut. Aucune réécriture automatique.") -f "$($weakStd.Count)", "$($expected.Count)")
            Complete-WriteCheck; return
        }
    }
    # 12.11 rc7 (R16) : zones a corriger, au controle complet d une ecriture pour un lecteur cible seulement (Find-WriteZones) :
    # leurs pistes sont reecrites a la passe 1 avec les pistes faibles, meme sans piste faible
    $zs = @(); if ($rep.Round -eq 0) { $zs = @(Find-WriteZones $rep) }
    if ($weak.Count -eq 0 -and $zs.Count -eq 0) { Complete-WriteCheck; return }
    if ($rep.Round -ge $rep.Max) { Complete-WriteCheck; return }
    # Passe de reecriture : pistes faibles seules, puis remesure de ces seules pistes. 12.8.2 : double densite
    # (Rep.EraseMode 'hfreq') : effacement haute frequence des pistes faibles (gw erase --hfreq, memes elements du champ
    # Pistes), toujours, quelle que soit la case « Effacer avant d ecrire » (comme le pre-effacement force d avant), puis
    # reecriture sans --pre-erase ; haute densite (et autres cas 'pre') : pre-effacement force. Revue 12.8.2 : chaque
    # reecriture est precedee de l effacement de ses seules pistes (meme --tracks), et non toutes les pistes de la passe
    # d abord : un arret de gw n expose que les pistes de la commande en cours ; pistes effacees de la passe (EraseLog,
    # Read-GwOutput) restees sans ecriture : marquees illisibles par Update-RepPartial
    $rep.Round++
    if ($weak.Count -gt 0) { Append-Log ((T "Réécriture des pistes faibles, passe {0}/{1} : {2}") -f "$($rep.Round)", "$($rep.Max)", "$(Format-TrackList $weak)") }
    # 12.11 rc7 (R16) : pistes des zones (Start-WriteZonePass : profils decales, journal) ajoutees a celles de la passe
    if ($zs.Count -gt 0) { $zk = @(Start-WriteZonePass $rep $zs); $weak = Sort-TrackKeys @(@($weak) + $zk | Select-Object -Unique); $rep.Weak = $weak }
    $groups = Get-TrackGroups $weak
    $extras = Get-TSpecExtras $rep.UserTSpec
    $hf = ([string]$rep.EraseMode -eq 'hfreq')
    $wbase = @($rep.Base)
    if ($hf) { $wbase = @($wbase | Where-Object { $_ -ne '--pre-erase' }) } elseif ($wbase -notcontains '--pre-erase') { $wbase += '--pre-erase' }
    $rep.Pending.Clear()
    # Lecteur et port memorises au clic (Rep.Common, comme les relectures) et --fake-index de l ecriture (Rep.Base)
    $eda = @(@($rep.Common) + @(@($rep.Base) | Where-Object { $_ -match '^--fake-index=' }))
    $wts = @()
    if ($null -ne $rep.HeadPrecomp) {
        # Ecriture lente : une reecriture par tete, chacune avec sa precompensation
        foreach ($h in 0, 1) {
            $cs = @($weak | Where-Object { ($_ -split '\.')[1] -eq "$h" } | ForEach-Object { [int](($_ -split '\.')[0]) })
            if ($cs.Count -eq 0) { continue }
            $cmd = @($wbase); if ($rep.HeadPrecomp[$h]) { $cmd += @('--precomp', $rep.HeadPrecomp[$h]) }
            $wts += @{ Ts = "c=$(Format-CylList $cs):h=$h$extras"; Cmd = $cmd }
        }
    } else {
        foreach ($g in $groups) { $wts += @{ Ts = "$g$extras"; Cmd = $wbase } }
    }
    $ers = @()
    foreach ($wt in $wts) {
        if ($hf) { $ec = [string[]](@('erase') + $eda + @('--hfreq', "--tracks=$($wt.Ts)")); $rep.Pending.Enqueue($ec); $ers += ,$ec }
        $rep.Pending.Enqueue([string[]](@($wt.Cmd) + @("--tracks=$($wt.Ts)", "`"$($rep.Image)`"")))
    }
    $script:EraseLog = $null
    if ($hf -and $ers.Count -gt 0) {
        $script:EraseLog = @{ Owner = 'check'; Round = [int]$rep.Round; Erased = @{}; Written = @{} }
        if ($rep.ZonePass) { Append-Log ((T "Effacement haute fréquence des pistes à réécrire (pistes faibles et zones écartées de l'attendu) avant leur réécriture (disquette double densité) : {0}.") -f (Format-EraseTracks $ers)) }
        else { Append-Log ((T "Effacement haute fréquence des pistes faibles avant leur réécriture (disquette double densité) : {0}.") -f (Format-EraseTracks $ers)) }
    }
    Add-RepReads $groups $extras
    Start-RepPending
}

function Get-RepAsymExcess($rep, [string]$k) {
    # 12.11 rc4 (R10) : exces de precompensation (ns) de la piste $k ('cylindre.tete') d une ecriture pour un lecteur cible
    # avec le facteur par cylindre : Rep.AsymExcess, memorise a l ecriture (Start-ImageWrite, 140 : par tete, tableau par
    # cylindre de courbe ecrite - courbe que le lecteur qui ecrit aurait ecrite pour lui-meme sur cette disquette). Cylindre
    # au-dela du tableau : derniere valeur (les profils y sont constants) ; $null sans cette memoire pour la piste
    if (-not $rep -or -not $rep.AsymExcess) { return $null }
    $p = @($k -split '\.')
    if ($p.Count -ne 2) { return $null }
    $ex = $rep.AsymExcess[[int]$p[1]]
    if ($null -eq $ex) { return $null }
    $ex = @($ex)
    if ($ex.Count -eq 0) { return $null }
    return [double]$ex[[math]::Min([int]$p[0], $ex.Count - 1)]
}

function Get-RepAsymGain($rep, [string]$k) {
    # 12.11 rc7 (R16) : gain de l asymetrie attendue de la piste $k ('cylindre.tete') : Rep.AsymGain de sa tete (2 x pente de
    # l asymetrie relue mesuree sur l image, par tete relue : Start-ImageWrite, 140) ; NaN sans elle (Get-AsymExpGain, 190,
    # prend alors le repli AsymExpGainFallback de 040)
    if (-not $rep -or -not $rep.AsymGain) { return [double]::NaN }
    $p = @($k -split '\.')
    if ($p.Count -ne 2) { return [double]::NaN }
    $g = $rep.AsymGain[[int]$p[1]]
    if ($null -eq $g) { return [double]::NaN }
    return [double]$g
}

function Get-AsymGainText($gains, $measured) {
    # 12.11 rc7 (R16) : ligne de journal du gain de l asymetrie attendue d une ecriture pour un lecteur cible (Start-ImageWrite,
    # 140), par tete relue : $gains (Rep.AsymGain), $measured (tete -> pente mesuree sur l image ou non)
    $it = @(foreach ($h in 0, 1) {
        $g = Format-UiNum ([double]$gains[$h]) '0.00'
        if ($measured -and $measured[$h]) { (T "tête {0} : g = {1}, deux fois la pente mesurée sur l'image") -f "$h", $g }
        else { (T 'tête {0} : g = {1} par défaut, pente non mesurée') -f "$h", $g }
    })
    return ((T 'Contrôle après écriture : asymétrie attendue = g × excès de précompensation / cellule ; {0}.') -f ($it -join (T ' ; ')))
}

function Get-WriteZoneGap($rep, [string]$k) {
    # 12.11 rc7 (R16) : ecart de la piste $k a son asymetrie attendue, en ns : e = (mesuree signee - attendue) x cellule / g,
    # g le gain de sa tete (Get-RepAsymGain, Get-AsymExpGain), attendue du plan (Get-RepAsymExcess, Get-AsymExpected) ;
    # $null pour une piste non retenue : absente, illisible, pas SAINE (niveau 0), zone instable non jugee ou defaut de la
    # copie, piste ignoree par le controle (Rep.Ignore), sans exces memorise, cellule ou rapport non mesure
    $m = $rep.State[$k]
    if ($null -eq $m -or $m.Bad -or $m.Missing -or [int]$m.Level -ne 0 -or $m.Unjudged -or $m.CopyDefect) { return $null }
    if ($rep.Ignore -and $rep.Ignore.ContainsKey($k)) { return $null }
    $e = Get-RepAsymExcess $rep $k
    if ($null -eq $e) { return $null }
    $g = [double](Get-AsymExpGain (Get-RepAsymGain $rep $k))
    $x = Get-AsymExpected ([double]$e) ([double]$m.Cell) $g
    $d3 = [double]$m.R3 - 1.5; $d4 = [double]$m.R4 - 2.0
    if ($null -eq $x -or [double]::IsNaN($d3) -or [double]::IsNaN($d4)) { return $null }
    return (($d3 + $d4) - [double]$x) * [double]$m.Cell / $g
}

function Get-WriteZoneScan($rep) {
    # 12.11 rc7 (R16) : zones d une ecriture pour un lecteur cible, tete par tete, sur la relecture par le lecteur qui ecrit
    # (Rep.State). Pistes retenues : celles de Get-WriteZoneGap, triees par cylindre. y(c) : mediane de e sur les pistes
    # retenues des cylindres c - WriteZoneHalfWin a c + WriteZoneHalfWin (fenetre tronquee aux bords) ; piste marquee du
    # signe de y(c) si |y(c)| >= WriteZoneMinNs. Suites de pistes consecutives de meme signe, fusionnees quand au plus
    # WriteZoneGap cylindres les separent (jamais par-dessus une suite de signe oppose). Zone : suite de WriteZoneMinCyl
    # cylindres au moins (du premier au dernier), WriteZoneMinTracks pistes retenues au moins, mediane brute de e (E0) du
    # signe de la suite et de WriteZoneMinNs ns au moins ; une piste isolee, ou deux voisines, ne font ni ne defont une zone.
    # Correction Dz : arrondi (au pair) de -WriteZoneF x E0, bornee a +/- WriteZoneCapNs. Rend les zones une a une :
    # @{ H ; C0 ; C1 ; E0 ; Dz ; N (pistes retenues) ; State 'pending' ; E1 ; Tracks : pistes de la zone, Start-WriteZonePass }
    # Relecture rc7 : un cylindre sans piste retenue (piste faible, ignoree, non jugee, hors du controle) n est pas marque :
    # une suite s arrete apres plus de WriteZoneGap cylindres sans piste retenue, comme apres des cylindres non marques
    # 12.11 (version finale, relecture du banc) : E0Map, cle -> e de chacune des N pistes retenues de la zone (celles de
    # E0), pour juger la zone sur les memes pistes a sa relecture (Complete-WriteZonePass)
    $sMin = [double]$script:WriteZoneMinNs; $hw = [int]$script:WriteZoneHalfWin; $cap = [double]$script:WriteZoneCapNs
    foreach ($h in 0, 1) {
        $pl = New-Object System.Collections.Generic.List[object]
        foreach ($k in @($rep.State.Keys)) {
            $p = @(([string]$k) -split '\.')
            if ($p.Count -ne 2 -or [int]$p[1] -ne $h) { continue }
            $e = Get-WriteZoneGap $rep ([string]$k)
            if ($null -ne $e) { $pl.Add(@{ C = [int]$p[0]; E = [double]$e; K = [string]$k }) }
        }
        $pts = @($pl | Sort-Object -Property @{ Expression = { [int]$_.C } })
        $n = $pts.Count
        if ($n -eq 0) { continue }
        $sg = New-Object int[] $n
        for ($i = 0; $i -lt $n; $i++) {
            $c = [int]$pts[$i].C
            $y = [double](Get-Median @($pts | Where-Object { [int]$_.C -ge $c - $hw -and [int]$_.C -le $c + $hw } | ForEach-Object { [double]$_.E }))
            $sg[$i] = $(if ($y -ge $sMin) { 1 } elseif ($y -le -$sMin) { -1 } else { 0 })
        }
        $runs = New-Object System.Collections.Generic.List[object]
        $i = 0
        while ($i -lt $n) {
            $j = $i
            while ($j + 1 -lt $n -and $sg[$j + 1] -eq $sg[$i] -and ([int]$pts[$j + 1].C - [int]$pts[$j].C - 1) -le [int]$script:WriteZoneGap) { $j++ }
            if ($sg[$i] -ne 0) {
                $lr = if ($runs.Count -gt 0) { $runs[$runs.Count - 1] } else { $null }
                if ($lr -and [int]$lr.S -eq $sg[$i] -and ([int]$pts[$i].C - [int]$pts[[int]$lr.I1].C - 1) -le [int]$script:WriteZoneGap) { $lr.I1 = $j }
                else { $runs.Add(@{ I0 = $i; I1 = $j; S = $sg[$i] }) }
            }
            $i = $j + 1
        }
        foreach ($r in $runs) {
            $c0 = [int]$pts[[int]$r.I0].C; $c1 = [int]$pts[[int]$r.I1].C
            $vals = @(for ($q = [int]$r.I0; $q -le [int]$r.I1; $q++) { [double]$pts[$q].E })
            if ($c1 - $c0 + 1 -lt [int]$script:WriteZoneMinCyl -or $vals.Count -lt [int]$script:WriteZoneMinTracks) { continue }
            $md = [double](Get-Median $vals)
            if ([math]::Sign($md) -ne [int]$r.S -or [math]::Abs($md) -lt $sMin) { continue }
            $dz = [int][math]::Round([math]::Max(-$cap, [math]::Min($cap, -[double]$script:WriteZoneF * $md)))
            $mp = @{}; for ($q = [int]$r.I0; $q -le [int]$r.I1; $q++) { $mp[[string]$pts[$q].K] = [double]$pts[$q].E }
            @{ H = $h; C0 = $c0; C1 = $c1; E0 = $md; Dz = $dz; N = $vals.Count; E0Map = $mp; State = 'pending'; E1 = $null; Tracks = @() }
        }
    }
}

function Get-WriteZoneSpec([string]$spec, $zones, [int]$hard = 0) {
    # 12.11 rc7 (R16) : profil --precomp $spec d une tete, decale de Dz ns sur les cylindres C0 a C1 de chaque zone de
    # $zones (celles de cette tete) : W'(c) = W(c) + Dz, au moins 0, au plus $hard ou W(c) s il est deja au-dessus (une
    # valeur n est jamais augmentee au-dela) ; une valeur nulle reste nulle ; ailleurs, valeurs inchangees. Elements autres
    # que c=ns gardes en tete. Sans zone : $spec rendu tel quel (meme chaine, commandes de la rc6). Relecture rc7 : $hard,
    # borne de la courbe ecrite (Rep.ZoneHard : celle de Get-WriteFactorPlan, borne de precompensation en place, comme la
    # courbe ecrite pour le lecteur cible) ; 0 ou absente : CalHardMaxNs (470 ns, 560)
    $zs = @($zones | Where-Object { $_ })
    if (-not $spec -or $zs.Count -eq 0) { return $spec }
    $pre = @(); $last = 0
    foreach ($x in ($spec -split ':')) {
        if ($x -match '^\s*(\d+)\s*=\s*(\d+)\s*$') { if ([int]$Matches[1] -gt $last) { $last = [int]$Matches[1] } }
        elseif ($x.Trim()) { $pre += $x }
    }
    $n = $last + 1
    foreach ($z in $zs) { if ([int]$z.C1 + 2 -gt $n) { $n = [int]$z.C1 + 2 } }
    $v = New-Object int[] $n
    for ($c = 0; $c -lt $n; $c++) { $v[$c] = [int](Get-SpecValue $spec $c) }
    if ($hard -le 0) { $hard = [int]$script:CalHardMaxNs }
    foreach ($z in $zs) {
        for ($c = [math]::Max(0, [int]$z.C0); $c -le [int]$z.C1; $c++) {
            $w = $v[$c]
            if ($w -le 0) { continue }
            $v[$c] = [int][math]::Max(0, [math]::Min($w + [int]$z.Dz, [math]::Max($hard, $w)))
        }
    }
    return ((@($pre) + @(Build-CurveProfile $v)) -join ':')
}

function Get-RepHeadSpec($rep, [int]$h) {
    # 12.11 rc7 (R16) : profil --precomp que les reecritures du controle donnent a la tete logique $h : Rep.HeadPrecomp
    # (ecriture lente), sinon celui de Rep.Base (ecriture rapide, meme profil pour les deux tetes) ; '' sans --precomp
    if ($null -ne $rep.HeadPrecomp) { return [string]$rep.HeadPrecomp[$h] }
    $b = [string[]]@($rep.Base); $i = [array]::IndexOf($b, '--precomp')
    if ($i -ge 0 -and $i + 1 -lt $b.Count) { return [string]$b[$i + 1] }
    return ''
}

function Find-WriteZones($rep) {
    # 12.11 rc7 (R16) : zones a corriger, au controle complet seulement (Invoke-WriteCheckAnalysis, Round 0) : ecriture pour
    # un lecteur cible avec asymetrie attendue (Rep.AsymExcess), correction demandee a l ecriture (Rep.ZoneFix, case des
    # options avancees, Get-WriteZonePlan, 140), au moins 2 passes de reecriture (un repli reste possible), garde-fou
    # « plus de la moitie des pistes faibles » non declenche (Rep.Safety). Zones de Get-WriteZoneScan dont la correction
    # change le profil de leur tete (Get-RepHeadSpec, Get-WriteZoneSpec). Rend les zones une a une, rien sinon
    if (-not $rep -or -not $rep.ZoneFix -or -not $rep.AsymExcess -or [int]$rep.Max -lt 2 -or $rep.Safety) { return }
    foreach ($z in @(Get-WriteZoneScan $rep)) {
        $sp = Get-RepHeadSpec $rep ([int]$z.H)
        if (-not $sp -or (Get-WriteZoneSpec $sp @($z) ([int]$rep.ZoneHard)) -ceq $sp) { continue }
        $z
    }
}

function Format-WriteZone($z) {
    # 12.11 rc7 (R16) : « tete 0 c28-43 » d une zone (journal)
    return ((T 'tête {0} c{1}') -f "$($z.H)", "$([int]$z.C0)-$([int]$z.C1)")
}

function Start-WriteZonePass($rep, $zs) {
    # 12.11 rc7 (R16) : passe 1 du controle avec des zones ($zs, Find-WriteZones), avant ses commandes : profil de chaque
    # tete decale sur ses zones (Rep.HeadPrecomp ; profils d origine gardes dans Rep.HeadPrecompOrig ; ecriture rapide : le
    # profil commun de Rep.Base en est retire et donne aux deux tetes, une reecriture par tete ensuite), pistes de chaque
    # zone (perimetre du controle, tete et cylindres de la zone, hors pistes ignorees et zones instables non jugees : ce que
    # le controle ne reecrit jamais), une ligne de journal. Rend les cles des pistes des zones (Invoke-WriteCheckAnalysis
    # les ajoute aux pistes faibles de la passe : meme effacement, meme reecriture, meme relecture). Version finale : les
    # pistes faibles de la zone a la detection sont reecrites aussi, mais seules celles de E0Map jugent la zone
    # (Complete-WriteZonePass)
    if ($null -eq $rep.HeadPrecomp) {
        $pc = Get-RepHeadSpec $rep 0
        $b = [string[]]@($rep.Base); $i = [array]::IndexOf($b, '--precomp')
        if ($i -ge 0) { $rep.Base = @(for ($q = 0; $q -lt $b.Count; $q++) { if ($q -ne $i -and $q -ne $i + 1) { $b[$q] } }) }
        $rep.HeadPrecomp = @{ 0 = $pc; 1 = $pc }
    }
    $rep.HeadPrecompOrig = @{ 0 = $rep.HeadPrecomp[0]; 1 = $rep.HeadPrecomp[1] }
    foreach ($h in 0, 1) {
        $hz = @($zs | Where-Object { [int]$_.H -eq $h })
        if ($hz.Count -gt 0) { $rep.HeadPrecomp[$h] = Get-WriteZoneSpec ([string]$rep.HeadPrecompOrig[$h]) $hz ([int]$rep.ZoneHard) }
    }
    $all = New-Object System.Collections.Generic.List[string]
    foreach ($z in $zs) {
        $zk = @(@($rep.Scope.Keys) | Where-Object {
            $p = @(([string]$_) -split '\.')
            $p.Count -eq 2 -and [int]$p[1] -eq [int]$z.H -and [int]$p[0] -ge [int]$z.C0 -and [int]$p[0] -le [int]$z.C1 -and
            -not ($rep.Ignore -and $rep.Ignore.ContainsKey([string]$_)) -and -not ($rep.State[[string]$_] -and $rep.State[[string]$_].Unjudged) })
        $z.Tracks = Sort-TrackKeys $zk
        foreach ($k in $z.Tracks) { if (-not $all.Contains([string]$k)) { $all.Add([string]$k) } }
    }
    $rep.Zones = @($zs); $rep.ZonePass = $true
    $it = @(foreach ($z in $zs) { (T '{0} : écart médian {1} ns, correction {2} ns') -f (Format-WriteZone $z), (Format-UiNum ([double]$z.E0) '+0.0;-0.0;0.0'), ('{0:+0;-0;0}' -f [int]$z.Dz) })
    Append-Log ((T "Contrôle après écriture : {0} zone(s) écartée(s) de l'attendu à la relecture par le lecteur {1} ({2}). Leurs {3} piste(s) sont réécrites à la passe {4}/{5} avec la précompensation décalée sur ces cylindres, puis relues ; une zone qui ne se rapproche pas de l'attendu reprend sa courbe d'origine.") -f "$(@($zs).Count)", "$($rep.TargetSrc)", ($it -join (T ' ; ')), "$($all.Count)", "$($rep.Round)", "$($rep.Max)")
    # 12.11 (version finale) : conseil par tete dont les zones couvrent presque tous les cylindres ecrits, a la suite de la
    # ligne des zones (Get-WriteZoneHeadAdvice) ; texte seulement
    foreach ($l in @(Get-WriteZoneHeadAdvice $rep $zs)) { Append-Log $l }
    return @($all)
}

function Get-WriteZoneHeadAdvice($rep, $zs) {
    # 12.11 (version finale) : conseil d une correction par zones ($zs, Find-WriteZones), une ligne de journal par tete dont
    # les zones de meme sens couvrent au moins WriteZoneHeadPct % (040) des cylindres ecrits de cette tete : cylindres du
    # perimetre du controle (Rep.Scope) de la tete, couverts par les cylindres C0 a C1 de ses zones, reunis. Deux morceaux
    # de meme sens (separes par plus de WriteZoneGap cylindres sans piste retenue) comptent ensemble ; des zones de sens
    # contraires, non : une erreur du facteur de la disquette multiplie toute la courbe de la tete et la decale dans un seul
    # sens. Pourcentage tronque a l unite, seuil compare sans arrondi. Consigne selon l origine du facteur de la disquette
    # (Rep.ZoneAdvice, Get-TargetZoneAdvice, 172, decidee au lancement) : mesure sur cette disquette, ou mesure sur l image
    # faite avant l ecriture sans determiner ce facteur : la refaire ; facteur de la marque ou k = 1 : le geste de mesure de
    # Get-TargetWriteHowPhrase ; aucune consigne possible (restauration, image non mesurable, origine inconnue) : le fait
    # seul. Texte seulement : zones, profils et reecritures inchanges. Rend les lignes, tete 0 puis tete 1
    # Relecture de la version finale : en pratique How seul decide du texte. Une origine 'mesure' (KSrc) ne nait que du
    # facteur mesure sur l image juste avant l ecriture (Get-WriteFactorPlan, $next.K), qui donne aussi How 'mesure'
    # (Get-TargetWriteLearnHow, 172) ; le test de KSrc reste par precaution (memoire d une autre origine), sans effet
    # observable aujourd hui
    $out = @()
    if (-not $rep -or -not $rep.Scope) { return $out }
    $min = [double]$script:WriteZoneHeadPct
    $ad = $rep.ZoneAdvice
    foreach ($h in 0, 1) {
        $cyl = @{}
        foreach ($k in @($rep.Scope.Keys)) { $p = @(([string]$k) -split '\.'); if ($p.Count -eq 2 -and [int]$p[1] -eq $h) { $cyl[[int]$p[0]] = $true } }
        $tot = $cyl.Count
        if ($tot -eq 0) { continue }
        $best = 0
        foreach ($sg in 1, -1) {
            $cov = @{}
            foreach ($z in @(@($zs) | Where-Object { $_ -and [int]$_.H -eq $h -and [math]::Sign([double]$_.E0) -eq $sg })) {
                for ($c = [int]$z.C0; $c -le [int]$z.C1; $c++) { if ($cyl.ContainsKey($c)) { $cov[$c] = $true } }
            }
            if ($cov.Count -gt $best) { $best = $cov.Count }
        }
        if ($best * 100 -lt $min * $tot) { continue }
        $pct = "$([int][math]::Floor(100.0 * $best / $tot))"
        $ks = ''; $how = ''
        if ($ad) { if ($ad.KSrc) { $ks = [string]$ad.KSrc[$h] }; $how = [string]$ad.How }
        $ph = Get-TargetWriteHowPhrase $how
        if ($ks -ceq 'mesure' -or $how -ceq 'mesure') { $out += (T "Contrôle après écriture : zone(s) écartée(s) de l'attendu sur {0} % des cylindres écrits de la tête {1} ({2} sur {3}) : facteur de la disquette à revoir, refaites la mesure sur l'image.") -f $pct, "$h", "$best", "$tot" }
        elseif ($ph) { $out += (T "Contrôle après écriture : zone(s) écartée(s) de l'attendu sur {0} % des cylindres écrits de la tête {1} ({2} sur {3}) : facteur de la disquette à revoir ; pour le mesurer sur l'image avant l'écriture, {4}.") -f $pct, "$h", "$best", "$tot", $ph }
        else { $out += (T "Contrôle après écriture : zone(s) écartée(s) de l'attendu sur {0} % des cylindres écrits de la tête {1} ({2} sur {3}) : facteur de la disquette à revoir.") -f $pct, "$h", "$best", "$tot" }
    }
    return $out
}

function Complete-WriteZonePass($rep, $weak) {
    # 12.11 rc7 (R16) : analyse de la passe 1 d une correction par zones (Invoke-WriteCheckAnalysis, Round 1), sur la
    # relecture par le lecteur qui ecrit : par zone, E1, mediane de e (Get-WriteZoneGap : pistes SAINES, attendue du plan)
    # sur ses pistes appariees (ci-dessous). Acceptee (State 'ok') si (E0P - E1) x signe(E0) >= WriteZoneAccept x |Dz|
    # (rapprochee de l attendue
    # d au moins la moitie du decalage) et E1 x signe(E0) >= -WriteZoneMinNs (pas plus de 8 ns de l autre cote) ; sinon, ou
    # sans piste saine relue, reprise (State 'back') : profil d origine sur ses cylindres et ses pistes ajoutees aux pistes
    # faibles de la passe suivante. Une seule tentative par zone. Profils des passes suivantes : origine + zones acceptees.
    # Une ligne de journal par zone. Rend les pistes faibles de la passe suivante. Relecture rc7 : jugee sur
    # WriteZoneMinTracks pistes saines relues au moins, comme sa detection ; moins (pistes devenues faibles) : reprise
    # 12.11 (version finale, relecture du banc) : jugement sur des pistes appariees, celles retenues a la detection (E0Map,
    # Get-WriteZoneScan) et saines a la relecture (Get-WriteZoneGap non nul ; toutes relues : elles sont dans Tracks).
    # E0P, mediane de leur e a la detection, remplace E0 dans le critere ; E1, mediane de leur e a la relecture ; NP, leur
    # nombre (WriteZoneMinTracks au moins, sinon reprise). Une piste faible a la detection (reecrite, dans Tracks) ne compte
    # pas, meme guerie : sur une zone dont l ecart change par paliers, elle deplacait la mediane de la relecture sans aucun
    # effet de la correction (banc : relecture identique sur les pistes de E0, zone pourtant gardee) ; une piste devenue
    # faible sort des deux medianes. E0 (detection) reste celui de la ligne des zones, du sens du critere et du conseil
    # (Get-WriteZoneHeadAdvice) ; journal : E0P et, s il differe de E0, le nombre de pistes appariees
    $back = New-Object System.Collections.Generic.List[string]
    $nMin = [int]$script:WriteZoneMinTracks
    foreach ($z in @($rep.Zones)) {
        if ([string]$z.State -ne 'pending') { continue }
        $v0 = New-Object System.Collections.Generic.List[double]; $v1 = New-Object System.Collections.Generic.List[double]
        if ($z.E0Map) { foreach ($k in @($z.E0Map.Keys)) { $e = Get-WriteZoneGap $rep ([string]$k); if ($null -ne $e) { $v0.Add([double]$z.E0Map[$k]); $v1.Add([double]$e) } } }
        $np = $v1.Count; $z.NP = $np
        $ok = $false; $sg = [math]::Sign([double]$z.E0)
        if ($np -gt 0) { $z.E0P = [double](Get-Median $v0); $z.E1 = [double](Get-Median $v1) }
        if ($np -ge $nMin) {
            $ok = (([double]$z.E0P - [double]$z.E1) * $sg -ge [double]$script:WriteZoneAccept * [math]::Abs([int]$z.Dz) -and [double]$z.E1 * $sg -ge -[double]$script:WriteZoneMinNs)
        }
        $z.State = $(if ($ok) { 'ok' } else { 'back' })
        $e0 = Format-UiNum ([double]$z.E0) '+0.0;-0.0;0.0'; $dz = '{0:+0;-0;0}' -f [int]$z.Dz
        if ($np -lt $nMin) { Append-Log ((T "Zone écartée de l'attendu, {0} : écart médian {1} ns avant la correction de {2} ns, {3} piste(s) saine(s) aux deux relectures, il en faut {4} : correction reprise, courbe d'origine sur ces cylindres, pistes réécrites à la passe suivante.") -f (Format-WriteZone $z), $e0, $dz, "$np", "$nMin") }
        else {
            $e0p = Format-UiNum ([double]$z.E0P) '+0.0;-0.0;0.0'; $e1 = Format-UiNum ([double]$z.E1) '+0.0;-0.0;0.0'
            $same = ([double]$z.E0P -eq [double]$z.E0)
            if ($ok -and $same) { Append-Log ((T "Zone écartée de l'attendu, {0} : écart médian {1} ns avant, {2} ns après la correction de {3} ns (relecture par le lecteur {4}) : correction gardée.") -f (Format-WriteZone $z), $e0p, $e1, $dz, "$($rep.TargetSrc)") }
            elseif ($ok) { Append-Log ((T "Zone écartée de l'attendu, {0} : écart médian {1} ns avant, {2} ns après la correction de {3} ns (relecture par le lecteur {4}, sur les {5} pistes saines aux deux relectures) : correction gardée.") -f (Format-WriteZone $z), $e0p, $e1, $dz, "$($rep.TargetSrc)", "$np") }
            elseif ($same) { Append-Log ((T "Zone écartée de l'attendu, {0} : écart médian {1} ns avant, {2} ns après la correction de {3} ns (relecture par le lecteur {4}) : correction reprise, courbe d'origine sur ces cylindres, pistes réécrites à la passe suivante.") -f (Format-WriteZone $z), $e0p, $e1, $dz, "$($rep.TargetSrc)") }
            else { Append-Log ((T "Zone écartée de l'attendu, {0} : écart médian {1} ns avant, {2} ns après la correction de {3} ns (relecture par le lecteur {4}, sur les {5} pistes saines aux deux relectures) : correction reprise, courbe d'origine sur ces cylindres, pistes réécrites à la passe suivante.") -f (Format-WriteZone $z), $e0p, $e1, $dz, "$($rep.TargetSrc)", "$np") }
        }
        if (-not $ok) { foreach ($k in @($z.Tracks)) { if (-not $back.Contains([string]$k)) { $back.Add([string]$k) } } }
    }
    $rep.ZonePass = $false
    if ($rep.HeadPrecompOrig) {
        foreach ($h in 0, 1) {
            $hz = @(@($rep.Zones) | Where-Object { [int]$_.H -eq $h -and [string]$_.State -eq 'ok' })
            $rep.HeadPrecomp[$h] = $(if ($hz.Count -gt 0) { Get-WriteZoneSpec ([string]$rep.HeadPrecompOrig[$h]) $hz ([int]$rep.ZoneHard) } else { $rep.HeadPrecompOrig[$h] })
        }
    }
    # Tableau rendu entier (virgule), meme vide ou d une seule piste, comme Sort-TrackKeys
    $next = Sort-TrackKeys @(@($weak) + @($back) | Select-Object -Unique)
    return ,$next
}

function Get-WriteZoneCount($rep) {
    # 12.11 rc7 (R16) : zones du controle (Rep.Zones) : N, Ok (correction gardee), Pend (non jugees : passe 1 interrompue
    # par une erreur de gw, avant ou apres la reecriture de leurs pistes avec la correction)
    $zs = @(@($rep.Zones) | Where-Object { $_ })
    return @{ N = $zs.Count; Ok = @($zs | Where-Object { [string]$_.State -eq 'ok' }).Count; Pend = @($zs | Where-Object { [string]$_.State -eq 'pending' }).Count }
}

function Show-WriteCheckTable($rep) {
    # Etat final de chaque piste controlee (derniere mesure) dans l onglet Qualite, avec reecritures et retries
    $keys = Sort-TrackKeys @($rep.State.Keys)
    # 12.11 rc4 (R10) : ecriture pour un lecteur cible avec le facteur par cylindre (Rep.AsymExcess) : le lecteur qui a
    # ecrit relit une disquette ecrite expres au-dessus de son propre besoin. Chaque piste lisible recoit son asymetrie
    # attendue et l ecart mesuree - attendue, que le score et la couleur de la case « Asym. » jugent a la place de la
    # valeur mesuree (Set-TrackAsymExpected, 190). Pose ici, a l affichage du resultat : l etat des pistes, les pistes
    # faibles et les reecritures (Invoke-WriteCheckAnalysis) sont decides avant et n en dependent pas. AsymFor : lecteur
    # cible et lecteur qui a relu, gardes avec le resultat pour sa phrase (journal, infobulle de la carte, export).
    # AsymHead : tete de la piste qui porte une asymetrie attendue ('0' ou '1', tiree de sa cle), pour le jugement tete
    # par tete du resume (Get-AsymSummary, 190 : courbe ecrite et facteur de la disquette sont par tete)
    $asymFor = $null
    # 12.11 rc7 (R16) : gain de la tete de chaque piste (Get-RepAsymGain : 2 x pente mesuree sur l image, sinon le repli)
    if ($rep.AsymExcess) {
        foreach ($k in $keys) { $e = Get-RepAsymExcess $rep $k; if ($null -ne $e) { Set-TrackAsymExpected $rep.State[$k] $e (Get-RepAsymGain $rep $k); if ($rep.State[$k] -and $null -ne $rep.State[$k].AsymExp) { $rep.State[$k].AsymHead = [string](@($k -split '\.')[1]) } } }
        $asymFor = @{ Target = [string]$rep.Target; Src = [string]$rep.TargetSrc }
    }
    $last = @{}; $total = 0.0; $count = 0; $nBad = 0
    # 12.8 (lot 3b) : icone d etat de 16 px devant le texte de la colonne Etat
    $lvAl.Columns[1].Width = $(if (@($rep.State.Values | Where-Object { $_.Weak }).Count -gt 0) { 302 } else { 222 })
    # 12.11 rc6 (R14) : colonnes « Attendue » et « Ecart » quand une piste porte une asymetrie attendue (Set-AlExpColumns,
    # 190) ; sans elle, tableau de toujours
    $expCols = [bool]($asymFor -and @($keys | Where-Object { $rep.State[$_] -and $null -ne $rep.State[$_].AsymExp }).Count -gt 0)
    Set-AlExpColumns $expCols
    $lvAl.BeginUpdate()
    try {
        $lvAl.Items.Clear()
        foreach ($k in $keys) {
            $m = $rep.State[$k]
            $mark = ''
            if ($rep.Rewrites.ContainsKey($k)) { $mark = ((T " (réécrite x{0})") -f "$($rep.Rewrites[$k])") }
            elseif ($rep.Retries.ContainsKey($k)) { $mark = ((T " (essais x{0})") -f "$($rep.Retries[$k])") }
            $row = New-AlignRow $k $m $mark '-' -1
            if ($expCols) { $row = Add-AlExpCells $row $m }
            [void]$lvAl.Items.Add($row)
            if ($m.Bad) { $last[$k] = @{ Score = 9999; Jitter = 0; Asym = 0; Err = 0; Stab = 0; Cell = 0 }; $nBad++; continue }
            $last[$k] = @{ Score = $m.Score; Jitter = $m.J; Asym = $m.Asym; Err = $m.Ooc; Stab = $m.Stab; Cell = $m.Cell }
            $total += $m.Score; $count++
        }
    } finally { $lvAl.EndUpdate() }
    Set-AlNumColumnWidths                                 # 12.11 (version finale) : colonnes des nombres a leur plus longue case (195)
    # Bandeau des zones instables d apres la derniere mesure du controle (efface celui d une mesure precedente)
    $inIgn = { param($k) $rep.Ignore -and $rep.Ignore.ContainsKey($k) }
    $defK = @($keys | Where-Object { $rep.State[$_].CopyDefect })
    $srcK = @($keys | Where-Object { $rep.State[$_].Weak -and (& $inIgn $_) -and $rep.SrcWeak -and $rep.SrcWeak.ContainsKey($_) })
    $crtK = @($keys | Where-Object { $rep.State[$_].Weak -and (& $inIgn $_) -and -not ($rep.SrcWeak -and $rep.SrcWeak.ContainsKey($_)) })
    $unkK = @($keys | Where-Object { $rep.State[$_].Unjudged -and -not (& $inIgn $_) })
    Set-UnstableBanner @(
        $(if ($defK.Count -gt 0) { (T "Zone instable sur la copie, défaut probable du support (la source n'en contient pas) : {0}") -f "$(Format-TrackList $defK)" }),
        $(if ($srcK.Count -gt 0) { (T "Zone instable de la source (protection probable, non reproductible) : {0}") -f "$(Format-TrackList $srcK)" }),
        $(if ($crtK.Count -gt 0) { (T "Zone instable sur une piste déjà critique dans la source : {0}") -f "$(Format-TrackList $crtK)" }),
        $(if ($unkK.Count -gt 0) { (T "Zone instable non jugée (la source peut contenir une protection) : {0}") -f "$(Format-TrackList $unkK)" }))
    $script:AlignLast = $last
    $script:AlignLastInfo = New-AlignLastInfo $last ([string]$cmbDrive.Text)   # 12.11 rc3 (R7) : lecteur qui a relu (liste du bandeau inactive pendant le controle)
    # 12.8 (lot 3) : resultat du controle sur la carte de l onglet Qualite ; son etat (COPIE SAINE, pistes faibles) suit
    # dans Complete-WriteCheck (Set-QualityCheckState)
    $res = @{ Kind = 'check'; Score = $null; Lvl = 3; Count = $count; Bad = $nBad; Health = -1; CheckLvl = -1; Weak = 0; HealthText = ''; HealthSub = '' }
    if ($count -gt 0) {
        $avg = [math]::Round($total / $count, 0); $lvl = Get-AlLevel 'score' $avg
        $res.Score = $avg; $res.Lvl = $lvl
        $res.ScoreText = ((T "Contrôle après écriture : score moyen {0} ({1}) sur {2} piste(s) lisible(s)") -f "$avg", "$($script:AlNames[$lvl])", "$count")
    } else {
        $res.ScoreText = (T 'Aucune piste analysable')
    }
    # 12.11 : resume de l asymetrie des pistes lisibles (Get-AsymSummary : signe commun, part du score moyen) : infobulle
    # de la carte et journal ; l en-tete de l export le recalcule sur les lignes du tableau, meme fonction
    # 12.11 rc4 (R10) : ecriture pour un lecteur cible avec asymetrie attendue : phrase du jugement de l ecart (-For)
    if ($asymFor) { $res.AsymFor = $asymFor }
    $asum = Get-AsymSummary @($keys | ForEach-Object { $rep.State[$_] })
    $res.AsymText = Get-AsymSummaryText $asum -For $asymFor
    # 12.11 rc6 (R14) : ligne de l asymetrie attendue sur la carte (Get-AsymExpLine, 190), forme longue et sans le nom du
    # lecteur cible, et son jugement (couleur) ; '' sans asymetrie attendue : carte de toujours
    $res.AsymLine = Get-AsymExpLine $asum $asymFor; $res.AsymLineShort = Get-AsymExpLine $asum $asymFor -Short
    $res.AsymJudge = $(if ($res.AsymLine) { [string]$asum.Judge } else { '' })
    # 12.11 rc7 (R16) : zones ecartees de l attendu corrigees (Get-WriteZoneCount) a la suite de la ligne de la carte.
    # Relecture rc7 : AsymLineBare, forme courte sans elles, derniere forme de la carte (Render-QualityCard, 195) : une
    # ligne trop longue perd le nombre de zones (repris par le verdict, infobulle) plutot que d etre coupee
    # Rendu de la rc8 : AsymLineCompact (ni le nom du lecteur cible ni « pour le lecteur cible ») suivie des zones, avant
    # AsymLineBare : le nombre de zones tient a la taille par defaut
    $zc = Get-WriteZoneCount $rep
    if ($res.AsymLine -and $zc.N -gt 0) { $zt = (T ' ; zones corrigées : {0} sur {1}') -f "$($zc.Ok)", "$($zc.N)"; $res.AsymLineBare = $res.AsymLineShort; $res.AsymLineCompact = (Get-AsymExpLine $asum $asymFor -Compact) + $zt; $res.AsymLine += $zt; $res.AsymLineShort += $zt }
    if ($res.AsymText) { Append-Log ((T "Contrôle après écriture : {0}") -f $res.AsymText) }
    Set-QualityResult $res
}

function Complete-WriteCheck([switch]$GwError) {
    $rep = $script:Rep; $script:Rep = $null
    if (-not $rep) { return }
    Show-WriteCheckTable $rep
    $n = $rep.State.Count
    $weak = @(@($rep.Weak) | Where-Object { $_ })
    $nRew = $rep.Rewrites.Count
    # Pistes ignorees (non reproductibles ou deja critiques) : ni saines ni faibles, signalees a part ; de meme les pistes
    # a zone instable non jugee
    $ignK = @(@($rep.State.Keys) | Where-Object { $rep.Ignore -and $rep.Ignore.ContainsKey($_) -and ($rep.State[$_].Bad -or $rep.State[$_].Level -ge 1 -or $rep.State[$_].Weak) })
    $unjK = @(@($rep.State.Keys) | Where-Object { $rep.State[$_].Unjudged -and -not $rep.State[$_].Bad -and $rep.State[$_].Level -lt 1 -and -not ($rep.Ignore -and $rep.Ignore.ContainsKey($_)) })
    $nOk = $n - $ignK.Count - $unjK.Count
    # 12.8.2 : pistes deja hors norme dans la source (Rep.SrcOver) citees a part des pistes non reproductibles ou critiques
    $ovrK = @($ignK | Where-Object { $rep.SrcOver -and $rep.SrcOver.ContainsKey($_) })
    $ignC = @($ignK | Where-Object { -not ($rep.SrcOver -and $rep.SrcOver.ContainsKey($_)) })
    if ($GwError) {
        # gw a echoue pendant une passe de reecriture : les pistes de la passe restent faibles
        # 12.10 (lot 1, I-5) : verdict neutre, l usure du support n est pas presumee
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE interrompu par une erreur gw à la passe {0}/{1} : {2} piste(s) faible(s) ou non remesurée(s) : {3}  ->  disquette ou lecteur en défaut, non distingués") -f "$($rep.Round)", "$($rep.Max)", "$($weak.Count)", "$(Format-TrackList $weak)"); $lvl = 3
    } elseif ($n -eq 0) {
        $txt = (T 'CONTRÔLE APRÈS ÉCRITURE : aucune piste mesurée.'); $lvl = 3
    } elseif ($weak.Count -eq 0) {
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE : {0}/{1} pistes saines") -f "$nOk", "$n")
        if ($ignC.Count -gt 0) { $txt += ((T ", {0} piste(s) non reproductible(s) ou déjà critique(s) non comptée(s) : {1}") -f "$($ignC.Count)", "$(Format-TrackList (Sort-TrackKeys $ignC))") }
        if ($ovrK.Count -gt 0) { $txt += ((T ", {0} piste(s) déjà hors norme dans l'original non comptée(s) : {1}") -f "$($ovrK.Count)", "$(Format-TrackList (Sort-TrackKeys $ovrK))") }
        if ($unjK.Count -gt 0) { $txt += ((T ", {0} piste(s) à zone instable non jugée(s) : {1}") -f "$($unjK.Count)", "$(Format-TrackList (Sort-TrackKeys $unjK))") }
        if ($nRew -gt 0) { $txt += ((T ", après réécriture de {0} piste(s) en {1} passe(s)") -f "$nRew", "$($rep.Round)") }
        $lvl = 0
    } elseif ($rep.Safety) {
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE : {0}/{1} pistes faibles, réécriture automatique non lancée (plus de la moitié des pistes)  ->  vérifier le format, la disquette et le lecteur") -f "$($weak.Count)", "$n"); $lvl = 3
    } elseif ($rep.Max -eq 0) {
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE : {0}/{1} piste(s) faible(s) : {2}  (réécriture automatique désactivée)") -f "$($weak.Count)", "$n", "$(Format-TrackList $weak)"); $lvl = 2
    } else {
        # 12.10 (lot 1, I-5) : verdict neutre (esprit du libelle 12.8 de la calibration) : l usure n est pas presumee, une
        # autre disquette reste conseillee
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE : {0} piste(s) encore faible(s) après {1} passe(s) de réécriture : {2}  ->  autre type de disquette ou usure, non distingués ; essayez une autre disquette") -f "$($weak.Count)", "$($rep.Round)", "$(Format-TrackList $weak)"); $lvl = 3
    }
    # 12.10 : ecriture pour un lecteur cible (Rep.Target, Rep.TargetSrc : Start-ImageWrite) : le verdict rappelle que la
    # relecture est celle du lecteur qui a ecrit, pas celle du lecteur cible
    # 12.11 rc7 (R16) : zones ecartees de l attendu (Get-WriteZoneCount) : corrigees sur combien, et celles non jugees
    # (passe 1 interrompue par une erreur de gw : leurs pistes ont pu etre reecrites avec la correction, ou pas encore)
    $zc = Get-WriteZoneCount $rep
    if ($zc.Pend -gt 0) { $txt += ((T " ; zones écartées de l'attendu : {0} corrigée(s) sur {1}, {2} non jugée(s), leurs pistes ont pu être réécrites avec la correction") -f "$($zc.Ok)", "$($zc.N)", "$($zc.Pend)") }
    elseif ($zc.N -gt 0) { $txt += ((T " ; zones écartées de l'attendu corrigées : {0} sur {1}") -f "$($zc.Ok)", "$($zc.N)") }
    if ($rep.Target) { $txt += ((T " (relu par le lecteur {0}, pas par le lecteur cible {1})") -f "$($rep.TargetSrc)", "$($rep.Target)") }
    Append-Log $txt
    # 12.11 rc8 (R17) : ecriture pour un lecteur cible : memoire de l ecriture gardee (verdict R10, courbe finale et zones),
    # ou retiree apres une erreur de gw (Complete-TargetWriteMemory, 172) ; rien pour une autre ecriture
    Complete-TargetWriteMemory (-not $GwError) $rep
    # Bilan exploitable par la restauration (accroche : le controle vide la chaine d etapes, rien ne le suit)
    $short = if ($GwError) { (T 'contrôle interrompu par une erreur gw') } elseif ($lvl -eq 0) { (T "{0}/{1} pistes saines") -f "$nOk", "$n" }
             elseif ($n -eq 0) { (T 'aucune piste mesurée') } else { (T "{0} piste(s) faible(s) : {1}") -f "$($weak.Count)", "$(Format-TrackList $weak)" }
    # 12.11 : barre d etat en fin de sequence (Set-SeqEnd, 110) : le bilan court du controle, a la place de « Lecture
    # termine(e) » et du compteur de la derniere relecture ; icone du niveau (0 : ok, 3 : err, sinon neutre). En
    # restauration, la relecture de comparaison puis le verdict de la restauration le remplacent
    Set-SeqEnd ((T "Contrôle après écriture : {0}") -f "$short") $(if ($lvl -le 0) { 'ok' } elseif ($lvl -ge 3) { 'err' } else { 'idle' })
    # 12.8 (lot 3) : verdict sur la carte de l onglet Qualite (texte complet dans l infobulle) et dans l onglet Ecriture,
    # avec l icone d etat (niveau 0 : h0, 2 : h1, 3 : h2) et son encre
    Set-QualityCheckState $lvl $txt $short $weak.Count
    Set-WCalVerdict $txt $(if ($lvl -le 0) { 'h0' } elseif ($lvl -le 2) { 'h1' } else { 'h2' })
    $script:LastCheck = @{ Ok = ($lvl -eq 0); Level = $lvl; Text = $txt; Short = $short; Weak = $weak; Measured = $n; Rounds = $rep.Round; Rewrites = $nRew; GwError = [bool]$GwError }
    if ($script:Restore) {
        if ($GwError) { Stop-Restore (T 'erreur gw pendant le contrôle des pistes') } else { Invoke-RestoreNext }
        return
    }
    # 12.10 (lot 1, E11) : retour a l onglet d avant le controle (verdict dans l onglet Ecriture, detail dans l onglet
    # Qualite) ; en 12.8, l onglet Qualite restait affiche a la fin
    Exit-CheckTab
}

function Update-RepPartial {
    # Passe interrompue par gw : une relecture terminee implique que les ecritures de la passe l ont precedee.
    # Les pistes remesurees prennent leur nouvelle mesure ; les autres restent « faibles ou non remesurees ».
    $rep = $script:Rep
    $remeasured = @{}
    $fake = Test-RepFakeIndex $rep
    foreach ($scp in @($rep.Scps)) {
        if (-not (Test-Path -LiteralPath $scp)) { continue }
        try { $t = Read-ScpFile $scp -NoIndexZone:$fake } catch { continue }
        foreach ($tn in @($t.Keys)) {
            $k = "$([math]::Floor([int]$tn / 2)).$([int]$tn % 2)"
            if (@($rep.Weak) -notcontains $k) { continue }
            $mm = Get-TrackMetrics $t[$tn]; Set-CopyUnstable $rep $k $mm
            $rep.State[$k] = $mm
            $rep.Rewrites[$k] = 1 + $(if ($rep.Rewrites.ContainsKey($k)) { [int]$rep.Rewrites[$k] } else { 0 })
            $remeasured[$k] = $true
        }
    }
    # Revue 12.8.2 : pistes faibles de la passe effacees en haute frequence (lignes « Erasing Track », EraseLog de la passe)
    # sans ligne « Writing Track » ensuite, ni remesure : vierges, et non plus a leur mesure d avant la passe ; marquees
    # illisibles (absentes de la relecture), une ligne de journal
    $el = $script:EraseLog
    if ($el -and [string]$el.Owner -eq 'check' -and [int]$el.Round -eq [int]$rep.Round) {
        $blank = Sort-TrackKeys @(@($rep.Weak) | Where-Object { $el.Erased.ContainsKey([string]$_) -and -not $el.Written.ContainsKey([string]$_) -and -not $remeasured.ContainsKey($_) })
        foreach ($k in $blank) { $mm = Get-TrackMetrics @(); $mm.Missing = $true; $rep.State[$k] = $mm }
        if (@($blank).Count -gt 0) { Append-Log ((T "Contrôle après écriture : piste(s) effacée(s) en haute fréquence et non réécrite(s) après l'arrêt de gw : {0}. Elles sont vierges sur la disquette : réécrivez l'image.") -f "$(Format-TrackList $blank)") }
    }
    $rep.Weak = Sort-TrackKeys @(@($rep.Weak) | Where-Object { -not $remeasured.ContainsKey($_) -or $rep.State[$_].Bad -or $rep.State[$_].Level -ge 1 })
}

function Stop-WriteCheck([switch]$GwError) {
    # Abandon (bouton Arreter, erreur gw, operation incomplete, fichier manquant) : rien n est reecrit ensuite.
    # Erreur gw pendant une passe de reecriture : verdict et tableau avec les mesures deja acquises.
    if (-not $script:Rep) { return }
    if ($GwError -and $script:Rep.Round -gt 0 -and $script:Rep.State.Count -gt 0) { Update-RepPartial; Complete-WriteCheck -GwError; return }
    # Relecture rc7 (R16) : arret pendant une passe de reecriture (Arreter) : pistes de la passe effacees en haute frequence
    # et pas encore reecrites (EraseLog de la passe, Read-GwOutput), vierges sur la disquette ; meme ligne que
    # Update-RepPartial. Depuis la correction par zones, une passe peut effacer des pistes saines, jusqu a une tete entiere
    $rep = $script:Rep; $el = $script:EraseLog; $blank = @()
    if ([int]$rep.Round -gt 0 -and $el -and [string]$el.Owner -eq 'check' -and [int]$el.Round -eq [int]$rep.Round) {
        $blank = Sort-TrackKeys @(@($rep.Weak) | Where-Object { $el.Erased.ContainsKey([string]$_) -and -not $el.Written.ContainsKey([string]$_) })
    }
    $script:Rep = $null
    Exit-CheckTab                                         # 12.10 (lot 1, E11) : sans effet si la relecture n a pas commence
    Set-WCalVerdict (T 'Contrôle après écriture interrompu.') 'h1'     # 12.8 (lot 3) : icone d etat dans l onglet Ecriture
    Append-Log (T 'Contrôle après écriture interrompu.')
    Complete-TargetWriteMemory $false                     # 12.11 rc8 (R17) : ecriture pour un lecteur cible non gardee (172)
    if (@($blank).Count -gt 0) { Append-Log ((T "Contrôle après écriture : piste(s) effacée(s) en haute fréquence et non réécrite(s) après l'arrêt de gw : {0}. Elles sont vierges sur la disquette : réécrivez l'image.") -f "$(Format-TrackList $blank)") }
    Set-QualityStale 'checkabort'                         # 12.8 (lot 3a) : resultat de l onglet Qualite perime
    if ($script:Restore) { Stop-Restore (T 'contrôle des pistes interrompu') }
}
