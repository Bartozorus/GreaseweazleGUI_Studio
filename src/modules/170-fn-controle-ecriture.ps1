# ============================== FONCTIONS : CONTROLE APRES ECRITURE ============

function Get-WriteCheckBlocker([string]$path, [string]$fmt) {
    # Raison pour laquelle l analyse de flux (calibree MFM double densite, cellule 2 us) ne s applique pas ; $null sinon
    if ($chkWHard.Checked) { return (T 'secteurs durs') }
    if ($chkWTG43.Checked) { return (T 'lecteur 8 pouces (TG43)') }
    $hd = Get-HighDensityReason $path $fmt
    if ($hd) { return $hd }
    if ($fmt -match '^(commodore\.15[47]1|mac\.|apple2\.)') { return ((T "format GCR {0}") -f "$fmt") }
    # Format FM de la table (simple densite, groupe 'fm' de Get-FormatCalibInfo) : les criteres sont ceux du MFM
    if ($fmt -and $fmt -ne '(auto)' -and $script:GwFormats.Contains($fmt) -and (Get-FormatCalibInfo $fmt).Group -eq 'fm') { return ((T "format FM {0}") -f "$fmt") }
    # Piste 0 en FM, les autres en MFM (codage fm0 de la table : tsc.flex.*, olivetti.m20...) : la piste 0 serait jugee
    # avec les criteres du MFM et pourrait etre reecrite a tort ; controle bloque pour tout le format
    if ($fmt -and $fmt -ne '(auto)' -and $script:GwFormats.Contains($fmt) -and [string]$script:GwFormats[$fmt].Enc -eq 'fm0') { return ((T "piste 0 en FM, format {0}") -f "$fmt") }
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
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
    $lblWCal.Text = (T 'Écriture en cours, contrôle de toutes les pistes ensuite.')
    $pbWCal.Visible = $false; $lblWCal.Visible = $true
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
    # Elle signale alors un defaut de la copie (support fatigue, defaut localise) : la piste est faible et reecrite.
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
    elseif ($cmd[0] -eq 'write') { $lblWCal.Text = ((T "Contrôle après écriture : réécriture {0}/{1} de {2} piste(s) faible(s)...") -f "$($rep.Round)", "$($rep.Max)", "$($rep.Weak.Count)") }
    elseif ($cmd[0] -eq 'erase') { $lblWCal.Text = ((T "Contrôle après écriture : effacement haute fréquence avant la réécriture {0}/{1} de {2} piste(s) faible(s)...") -f "$($rep.Round)", "$($rep.Max)", "$($rep.Weak.Count)") }
    else { $lblWCal.Text = ((T "Contrôle après écriture : remesure {0}/{1} de {2} piste(s)...") -f "$($rep.Round)", "$($rep.Max)", "$($rep.Weak.Count)") }
    Set-QualityRunText $lblWCal.Text                      # 12.8 (lot 3a) : etape du controle sur la carte de l onglet Qualite
    Start-Gw $cmd
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
    $zo = 0; $zt = 0; $zf = 0; $fb = @()
    foreach ($k in $expected) {
        $ms = $rep.State[$k]; $z = [int]$ms.ZoneOoc
        if ($z -gt 0) { $zo += $z; $zt++; if ([int]$ms.ZoneFarNs -gt $zf) { $zf = [int]$ms.ZoneFarNs } }
        if ($ms.StabFallback) { $fb += $k }
    }
    if ($zo -gt 0) { Append-Log ((T "Contrôle après écriture : {0} intervalle(s) hors classe du raccord d'écriture de gw, dans la zone de ± 1 ms autour de l'index (jusqu'à {2} ms), non compté(s), sur {1} piste(s) relue(s) en 3 tours.") -f "$zo", "$zt", (Format-UiNum ($zf / 1e6) '0.00')) }
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
    if ($weak.Count -eq 0) { Complete-WriteCheck; return }
    # Garde-fou sur un controle large seulement : une selection de quelques pistes doit pouvoir etre reecrite
    # Garde-fou calcule aux seuils Standard : un reglage strict du jitter fait reecrire davantage, sans faux diagnostic
    $weakStd = @($weak | Where-Object { $s = $rep.State[$_]; $s.Bad -or (Get-HealthLevel $s.Ooc $s.Dr $s.Stab $s.J $script:JitterStdOk $script:JitterStdWatch) -ge 1 })
    if ($rep.Round -eq 0 -and $expected.Count -ge 20 -and $weakStd.Count * 2 -gt $expected.Count) {
        $rep.Safety = $true
        Append-Log ((T "Plus de la moitié des pistes sont faibles ({0}/{1}) : format non MFM, disquette inadaptée ou lecteur en défaut. Aucune réécriture automatique.") -f "$($weakStd.Count)", "$($expected.Count)")
        Complete-WriteCheck; return
    }
    if ($rep.Round -ge $rep.Max) { Complete-WriteCheck; return }
    # Passe de reecriture : pistes faibles seules, puis remesure de ces seules pistes. 12.8.2 : double densite
    # (Rep.EraseMode 'hfreq') : effacement haute frequence des pistes faibles (gw erase --hfreq, memes elements du champ
    # Pistes), toujours, quelle que soit la case « Effacer avant d ecrire » (comme le pre-effacement force d avant), puis
    # reecriture sans --pre-erase ; haute densite (et autres cas 'pre') : pre-effacement force. Revue 12.8.2 : chaque
    # reecriture est precedee de l effacement de ses seules pistes (meme --tracks), et non toutes les pistes de la passe
    # d abord : un arret de gw n expose que les pistes de la commande en cours ; pistes effacees de la passe (EraseLog,
    # Read-GwOutput) restees sans ecriture : marquees illisibles par Update-RepPartial
    $rep.Round++
    Append-Log ((T "Réécriture des pistes faibles, passe {0}/{1} : {2}") -f "$($rep.Round)", "$($rep.Max)", "$(Format-TrackList $weak)")
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
        Append-Log ((T "Effacement haute fréquence des pistes faibles avant leur réécriture (disquette double densité) : {0}.") -f (Format-EraseTracks $ers))
    }
    Add-RepReads $groups $extras
    Start-RepPending
}

function Show-WriteCheckTable($rep) {
    # Etat final de chaque piste controlee (derniere mesure) dans l onglet Qualite, avec reecritures et retries
    $keys = Sort-TrackKeys @($rep.State.Keys)
    $last = @{}; $total = 0.0; $count = 0; $nBad = 0
    # 12.8 (lot 3b) : icone d etat de 16 px devant le texte de la colonne Etat
    $lvAl.Columns[1].Width = $(if (@($rep.State.Values | Where-Object { $_.Weak }).Count -gt 0) { 302 } else { 222 })
    $lvAl.BeginUpdate()
    try {
        $lvAl.Items.Clear()
        foreach ($k in $keys) {
            $m = $rep.State[$k]
            $mark = ''
            if ($rep.Rewrites.ContainsKey($k)) { $mark = ((T " (réécrite x{0})") -f "$($rep.Rewrites[$k])") }
            elseif ($rep.Retries.ContainsKey($k)) { $mark = ((T " (essais x{0})") -f "$($rep.Retries[$k])") }
            [void]$lvAl.Items.Add((New-AlignRow $k $m $mark '-' -1))
            if ($m.Bad) { $last[$k] = @{ Score = 9999; Jitter = 0; Asym = 0; Err = 0; Stab = 0; Cell = 0 }; $nBad++; continue }
            $last[$k] = @{ Score = $m.Score; Jitter = $m.J; Asym = $m.Asym; Err = $m.Ooc; Stab = $m.Stab; Cell = $m.Cell }
            $total += $m.Score; $count++
        }
    } finally { $lvAl.EndUpdate() }
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
    Render-AlignBars
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
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE interrompu par une erreur gw à la passe {0}/{1} : {2} piste(s) faible(s) ou non remesurée(s) : {3}  ->  support fatigué ou lecteur en défaut") -f "$($rep.Round)", "$($rep.Max)", "$($weak.Count)", "$(Format-TrackList $weak)"); $lvl = 3
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
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE : {0} piste(s) encore faible(s) après {1} passe(s) de réécriture : {2}  ->  support fatigué, réécrire sur une autre disquette") -f "$($weak.Count)", "$($rep.Round)", "$(Format-TrackList $weak)"); $lvl = 3
    }
    Append-Log $txt
    # Bilan exploitable par la restauration (accroche : le controle vide la chaine d etapes, rien ne le suit)
    $short = if ($GwError) { (T 'contrôle interrompu par une erreur gw') } elseif ($lvl -eq 0) { (T "{0}/{1} pistes saines") -f "$nOk", "$n" }
             elseif ($n -eq 0) { (T 'aucune piste mesurée') } else { (T "{0} piste(s) faible(s) : {1}") -f "$($weak.Count)", "$(Format-TrackList $weak)" }
    # 12.8 (lot 3) : verdict sur la carte de l onglet Qualite (texte complet dans l infobulle) et dans l onglet Ecriture,
    # avec l icone d etat (niveau 0 : h0, 2 : h1, 3 : h2) et son encre
    Set-QualityCheckState $lvl $txt $short $weak.Count
    Set-WCalVerdict $txt $(if ($lvl -le 0) { 'h0' } elseif ($lvl -le 2) { 'h1' } else { 'h2' })
    $script:LastCheck = @{ Ok = ($lvl -eq 0); Level = $lvl; Text = $txt; Short = $short; Weak = $weak; Measured = $n; Rounds = $rep.Round; Rewrites = $nRew; GwError = [bool]$GwError }
    if ($script:Restore) {
        if ($GwError) { Stop-Restore (T 'erreur gw pendant le contrôle des pistes') } else { Invoke-RestoreNext }
        return
    }
    Show-Tab $tabAl
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
    $script:Rep = $null
    Set-WCalVerdict (T 'Contrôle après écriture interrompu.') 'h1'     # 12.8 (lot 3) : icone d etat dans l onglet Ecriture
    Append-Log (T 'Contrôle après écriture interrompu.')
    Set-QualityStale 'checkabort'                         # 12.8 (lot 3a) : resultat de l onglet Qualite perime
    if ($script:Restore) { Stop-Restore (T 'contrôle des pistes interrompu') }
}
