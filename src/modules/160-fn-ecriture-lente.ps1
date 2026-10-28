# ============================== FONCTIONS : ECRITURE LENTE : FILE ET PRECHAUFFAGE ===

function Get-WriteWarmupTSpec([string]$userTs, [int[]]$heads, [string]$image) {
    # Pistes du prechauffage d une ecriture lente : un cylindre sur 10 de la zone ecrite, son premier et son dernier
    # (comme le test standard de la calibration), tetes ecrites, elements step, hswap, h0.off et h1.off du champ Pistes
    # conserves (memes pistes physiques que l ecriture). Zone : c= du champ Pistes, sinon cylindres de l image
    # (Get-ImageCylinders), sinon 40 cylindres, valables sur tout lecteur (40 pistes et step=2 compris)
    $hs = if (@($heads).Count -ge 2) { '0-1' } else { "$(@($heads)[0])" }
    $extras = Get-TSpecExtras $userTs
    $cyls = @()
    $m = [regex]::Match(":$userTs", ':\s*c\s*=\s*([^:]*)')
    if ($m.Success -and $m.Groups[1].Value.Trim()) {
        foreach ($r in ($m.Groups[1].Value -split ',')) {
            if ($r -match '^\s*(\d+)\s*-\s*(\d+)\s*$') { $cyls += @([int]$Matches[1]..[int]$Matches[2]) }
            elseif ($r -match '^\s*(\d+)\s*$') { $cyls += [int]$Matches[1] }
            else { return "c=$($m.Groups[1].Value.Trim()):h=$hs$extras" }      # forme non lue : c= repris tel quel
        }
    } else {
        $n = Get-ImageCylinders $image
        if ($null -eq $n) { $n = 40 }
        $cyls = @(0..([math]::Max(1, [math]::Min(84, [int]$n)) - 1))
    }
    $s = @($cyls | Sort-Object -Unique)
    $pick = @(@($s | Where-Object { $_ % 10 -eq 0 }) + @($s[0], $s[-1]))
    return "c=$(Format-CylList ([int[]]$pick)):h=$hs$extras"
}

function Invoke-WriteQueueNext {
    # Ecriture lente : commande gw write suivante (une par tete) ; pistes et retries de la precedente cumules pour le controle.
    # 12.8.2 : la file commence par les commandes gw erase --hfreq de l effacement avant l ecriture (Start-ImageWrite,
    # ecriture rapide comprise)
    if ($script:WriteQueue.Count -eq 0) { return }
    Merge-RepRetries
    Start-Gw ([string[]]$script:WriteQueue.Dequeue())
}

function Start-WriteWarmup([string]$tspec, [bool]$noWarm) {
    # Prechauffage du lecteur avant une ecriture lente (fin de Start-ImageWrite, chaine d ecriture prete : onglet Ecriture,
    # Bibliotheque, restauration, reprise apres une calibration) : memes regles que celui de la calibration
    # (CalWarmupMinutes, Get-CalWarmupPlan : duree reduite ou prechauffage saute si le lecteur vient de servir, calibration
    # qui precede comprise ; lectures gw read sans ecriture, echecs toleres). Sans prechauffage (reglage a 0, case
    # « Prechauffer le lecteur » decochee, prechauffage passe pendant la calibration qui precede, lecteur deja actif) :
    # chaine lancee tout de suite. Sinon la chaine d ecriture est mise de cote (WriteWarm.Rest) pendant les lectures, puis
    # reprise telle quelle (Invoke-WriteWarmup) ; libelle et barre de l onglet Ecriture retablis a la fin.
    $script:WriteWarm = $null
    $drv = $cmbDrive.Text
    if ([double]$script:CalWarmupMinutes -le 0) { Invoke-NextChainStep; return }
    if (-not $chkWWarm.Checked) { Append-Log ((T "Préchauffage du lecteur {0} non demandé (case « Préchauffer le lecteur avant l'écriture lente » décochée) : écriture lente tout de suite.") -f "$drv"); Invoke-NextChainStep; return }
    if ($noWarm) { Append-Log ((T "Préchauffage du lecteur {0} passé à votre demande pendant la calibration : écriture lente tout de suite.") -f "$drv"); Invoke-NextChainStep; return }
    $plan = Get-CalWarmupPlan (Get-GwDriveKey (@('read') + (Get-CommonArgs))) ([double]$script:CalWarmupMinutes)
    $actTxt = Format-CalDuration ([math]::Round($plan.Active)); $idleTxt = Format-CalDuration ([math]::Round($plan.Idle))
    if ($plan.Skip) {
        Append-Log ((T "Préchauffage du lecteur {0} sauté : lecteur déjà en activité pendant {1} (dernière commande terminée il y a {2}).") -f "$drv", "$actTxt", "$idleTxt")
        Invoke-NextChainStep; return
    }
    $durTxt = Format-CalDuration ([math]::Round($plan.Sec))
    if ($plan.Reduced) { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant l'écriture lente, pour stabiliser sa température (durée réduite : lecteur déjà en activité pendant {2}, dernière commande terminée il y a {3}).") -f "$drv", "$durTxt", "$actTxt", "$idleTxt") }
    else { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant l'écriture lente, pour stabiliser sa température.") -f "$drv", "$durTxt") }
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $scp = Join-Path $script:TempDir 'write-warmup.scp'
    # Options d index et de densite de l ecriture (Get-WriteFormatArgs) : --fake-index et --densel par Get-DriveReadArgs,
    # --hard-sectors et --gen-tg43 ajoutees ici quand l ecriture les utilise (gw read 1.23 les declare, dans les memes
    # groupes exclusifs que gw write : --hard-sectors / --fake-index, --densel / --gen-tg43)
    $ro = @(Get-DriveReadArgs)
    if ($chkWHard.Checked) { $ro += '--hard-sectors' }
    if ($chkWTG43.Checked) { $ro += '--gen-tg43' }
    Hide-WCalVerdict                                      # 12.8 (FIX3) : verdict du controle precedent, non retabli a la fin
    $script:WriteWarm = @{
        Drive = $drv; Rest = @($script:Chain.ToArray()); WarmSec = [double]$plan.Sec; WarmStart = (Get-Date)
        WarmReads = 0; WarmFails = 0; WarmFailRun = 0; WarmDurs = @(); WarmReadStart = $null; WarmSkip = $false; WarmScp = $scp
        WarmArgs = @(@('read') + (Get-CommonArgs) + $ro + @('--revs=3', "--tracks=$tspec", "`"$scp`""))
        LblText = $lblWCal.Text; LblVisible = $lblWCal.Visible; PbVisible = $pbWCal.Visible
    }
    $script:Chain.Clear()
    $pbWCal.Value = 0; $pbWCal.Visible = $true; $lblWCal.Visible = $true
    Invoke-WriteWarmup
}

function Invoke-WriteWarmup {
    # Lecture de prechauffage suivante, ou fin : meme regle que Invoke-CalibWarmup (CalWarmupMinReads lectures au moins,
    # arret a la duree ou avant une lecture qui la depasserait de plus d une demi-lecture), sur demande (bouton « Passer le
    # prechauffage » : apres la lecture en cours) ou apres CalWarmupMaxFails lectures de suite sans aboutir (code non nul,
    # ou code 0 et lecture incomplete : l ecriture commence et signale le defaut s il persiste). Fin : chaine d ecriture
    # mise de cote reprise telle quelle
    $w = $script:WriteWarm
    if (-not $w) { return }
    $failed = $false
    if ($w.WarmReadStart -is [datetime]) {
        $w.WarmDurs += ((Get-Date) - $w.WarmReadStart).TotalSeconds; $w.WarmReadStart = $null
        $code = [int]$script:GwLastCode
        if ($code -ne 0 -or [bool]$script:GwLastIncomplete) {
            $w.WarmFails++; $w.WarmFailRun++
            if ($w.WarmFails -eq 1) { Append-Log ((T "Préchauffage du lecteur {0} : la lecture n'a pas abouti (code {1}) ; sans effet sur l'écriture, le préchauffage continue.") -f "$($w.Drive)", "$code") }
        } else { $w.WarmFailRun = 0 }
        $failed = ([int]$w.WarmFailRun -ge $script:CalWarmupMaxFails)
    }
    if (Test-Path -LiteralPath $w.WarmScp) { Remove-Item -LiteralPath $w.WarmScp -Force -ErrorAction SilentlyContinue }
    $left = $w.WarmSec - ((Get-Date) - $w.WarmStart).TotalSeconds
    $avg = if (@($w.WarmDurs).Count -gt 0) { (@($w.WarmDurs) | Measure-Object -Average).Average } else { 0.0 }
    if ($failed -or ($w.WarmSkip -and $w.WarmReads -ge 1) -or ($w.WarmReads -ge $script:CalWarmupMinReads -and ($left -le 0 -or $left -lt $avg / 2))) {
        $elTxt = Format-CalDuration ([math]::Round(((Get-Date) - $w.WarmStart).TotalSeconds))
        if ($failed) { Append-Log ((T "Préchauffage du lecteur {0} arrêté après {1} lectures de suite sans aboutir (Greaseweazle, lecteur ou disquette absent ?) : l'écriture commence, elle signalera le défaut s'il persiste.") -f "$($w.Drive)", "$($w.WarmFailRun)") }
        elseif ($w.WarmFails -gt 0) { Append-Log ((T "Préchauffage du lecteur {0} terminé : {1} lecture(s) en {2}, dont {3} sans aboutir (sans effet sur l'écriture).") -f "$($w.Drive)", "$($w.WarmReads)", "$elTxt", "$($w.WarmFails)") }
        else { Append-Log ((T "Préchauffage du lecteur {0} terminé : {1} lecture(s) en {2}.") -f "$($w.Drive)", "$($w.WarmReads)", "$elTxt") }
        $script:WriteWarm = $null
        # Libelle et barre de l onglet Ecriture comme avant le prechauffage (ecriture, controle apres ecriture)
        $lblWCal.Text = $w.LblText; $lblWCal.Visible = [bool]$w.LblVisible; $pbWCal.Visible = [bool]$w.PbVisible
        if ($script:Restore -and $script:Restore.Cur -eq 5) { Set-RsStep 5 'run' }      # detail « prechauffage » retire
        $script:Chain.Clear()
        foreach ($s in @($w.Rest)) { $script:Chain.Enqueue($s) }
        Invoke-NextChainStep; return
    }
    $w.WarmReads++; $w.WarmReadStart = Get-Date; $script:GwLastCode = 0; $script:GwLastIncomplete = $false
    Update-WriteWarmupProgress
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw ([string[]]$script:WriteWarm.WarmArgs) -Soft })
    $script:Chain.Enqueue({ Invoke-WriteWarmup })
    Invoke-NextChainStep
}

function Update-WriteWarmupProgress {
    # Barre et libelle de l onglet Ecriture pendant le prechauffage d une ecriture lente (minuteur) : duree ecoulee sur la
    # duree prevue, avancement et temps restant en tete (libelle coupe a la largeur de l onglet) ; passe a la demande : fin
    # de la lecture en cours
    $w = $script:WriteWarm
    if (-not $w) { return }
    $g = Get-WarmupLeft $w
    $pbWCal.Value = $g.Pct
    $lblWCal.Text = if ($w.WarmSkip) { (T 'Préchauffage du lecteur {0} passé : fin de la lecture en cours.') -f "$($w.Drive)" }
                    else { (T "Préchauffage avant l'écriture : {2} %, reste environ {3} (lecteur {0}, lecture {1}, sans écriture)") -f "$($w.Drive)", "$($w.WarmReads)", "$($g.Pct)", (Format-CalDuration ([math]::Round($g.Left))) }
}

function Stop-WriteWarmup {
    # Abandon pendant le prechauffage d une ecriture lente (Arreter, gw non lance, erreur d etape, restauration en echec) :
    # chaine d ecriture mise de cote abandonnee, rien n est ecrit ; sans effet hors prechauffage (idempotent)
    if (-not $script:WriteWarm) { return }
    $script:WriteWarm = $null
    $pbWCal.Visible = $false
    $lblWCal.Text = (T 'Préchauffage interrompu : écriture annulée.')
    Append-Log (T 'Écriture annulée : préchauffage du lecteur interrompu.')
}
