# ============================== FONCTIONS : LECTEURS ENREGISTRES ===============
# 12.11 (lot LN-a, socle sans interface) : un lecteur de disquette peut recevoir un nom. Le nom est alors son identite : le
# texte de la liste du bandeau, la cle de rangement de ses courbes (« nom|cle », « source>cible|cle ») et le champ Drive de
# ses donnees. La connexion (A, B, 0 a 3 : la valeur de --drive) devient un attribut de sa fiche, donne par la seule
# fonction Get-DriveConn. Un lecteur non enregistre garde pour identite le code de sa connexion : sans lecteur
# enregistre, cles, blocs de la configuration et arguments de gw sont ceux de la 12.10.
# Etat (040) : $script:DriveReg, registre, table ordonnee nom -> fiche @{ Name ; Conn ; Id ; Created ; From ; At } ;
# $script:DriveLast, connexion -> dernier lecteur enregistre choisi. Le registre n est jamais lu par un index ni par une
# propriete (Get-DriveRecord enumere ses entrees) : un nom fait de chiffres ne peut pas etre pris pour un rang, et aucun
# nom ne peut masquer une propriete de la table. Les mots reserves ($script:DriveReserved, refuses par Test-DriveName)
# protegent en plus la garde « registre non vide » ($script:DriveReg.Count -gt 0) des lignes ajoutees aux fonctions
# existantes.
# Des donnees ne changent d identite que par Edit-DriveData, appelee par les quatre actions du registre (Add-NamedDrive,
# Rename-NamedDrive, Move-NamedDrive, Remove-NamedDrive), qui ne touchent ni liste ni fenetre et rendent une table
# @{ Ok ; Why ; ... } (Why : le texte du refus). L interface (bandeau, fenetre « Lecteurs enregistres ») est le lot LN-b :
# d ici la, rien n enregistre un lecteur et le registre reste vide.

function Test-DriveConnCode([string]$s) {
    # 12.11 : vrai pour une des six connexions (codes du reglage drive, 040) ; comparaison exacte, comme
    # ConvertTo-SettingValue : « a » n est pas une connexion
    foreach ($c in $script:SettingDefs['drive'].Codes) { if ($c -ceq $s) { return $true } }
    return $false
}

function Get-DriveRecord([string]$drive) {
    # 12.11 : fiche d un lecteur enregistre, casse ignoree ; $null pour un lecteur non enregistre ou inconnu. Par
    # enumeration : ni index, ni propriete de la table
    if (-not $drive -or -not $script:DriveReg) { return $null }
    foreach ($e in @($script:DriveReg.GetEnumerator())) { if ([string]$e.Key -eq $drive) { return $e.Value } }
    return $null
}

function Get-DriveConn([string]$drive) {
    # 12.11 : seule fonction qui donne la connexion (valeur de --drive) d un lecteur : un lecteur non enregistre (A, B,
    # 0 a 3) est sa propre connexion ; un lecteur enregistre : celle de sa fiche ; inconnu, ou fiche sans connexion : ''
    # (gw refuse alors la commande : un nom n atteint jamais --drive). Sans autre fonction du module : les tests qui
    # chargent Get-CalibDriveArgsFor ne chargent qu elle
    foreach ($c in $script:SettingDefs['drive'].Codes) { if ($c -ceq $drive) { return [string]$c } }
    if ($drive -and $script:DriveReg) { foreach ($e in @($script:DriveReg.GetEnumerator())) { if ([string]$e.Key -eq $drive) { return [string]$e.Value.Conn } } }
    return ''
}

function Test-DriveRegistered([string]$drive) {
    # 12.11 : vrai pour un nom du registre
    return ($null -ne (Get-DriveRecord $drive))
}

function Get-DriveLabel([string]$drive) {
    # 12.11 : texte d un lecteur la ou sa connexion doit se lire : « TEAC FD-235HF (A) » ; lecteur non enregistre : son
    # code ; fiche sans connexion : « nom (connexion a preciser) » ; nom sans fiche : l identite nue
    $r = Get-DriveRecord $drive
    if (-not $r) { return $drive }
    if ([string]$r.Conn) { return ('{0} ({1})' -f [string]$r.Name, [string]$r.Conn) }
    return ((T '{0} (connexion à préciser)') -f [string]$r.Name)
}

function Get-DriveForConn([string]$conn) {
    # 12.11 : lecteur retenu pour une connexion : le dernier lecteur enregistre choisi sur elle s il y est toujours
    # enregistre, rendu par le nom de sa fiche, a sa casse (Set-Combo choisit par Items.Contains) ; sinon la connexion
    $l = ''
    if ($script:DriveLast) { foreach ($e in @($script:DriveLast.GetEnumerator())) { if ([string]$e.Key -ceq $conn) { $l = [string]$e.Value } } }
    $r = Get-DriveRecord $l
    if ($r -and [string]$r.Conn -ceq $conn) { return [string]$r.Name }
    return $conn
}

function Get-ConnDrives([string]$conn) {
    # 12.11 : lecteurs qu une connexion peut porter : ceux qui y sont enregistres, dans l ordre du registre, puis son
    # lecteur non enregistre s il a des donnees ou s il est le lecteur du bandeau. Elements rendus un a un, sans virgule
    # de protection : l appelant les recueille par @()
    if (-not (Test-DriveConnCode $conn)) { return }
    if ($script:DriveReg) { foreach ($e in @($script:DriveReg.GetEnumerator())) { if ([string]$e.Value.Conn -ceq $conn) { [string]$e.Value.Name } } }
    if ([string]$cmbDrive.Text -ceq $conn -or (Get-DriveData $conn)['Any']) { $conn }
}

function Test-DriveName([string]$name, [string]$self = '', [switch]$Load) {
    # 12.11 : seule decision sur le nom d un lecteur : @{ Ok ; Why (texte du refus) ; Name (nom normalise : espaces des
    # bords retires, espaces repetes ramenes a un seul) }. $self : nom actuel de la fiche modifiee, qui n est pas un
    # doublon d elle-meme, meme a la casse pres. -Load (chargement d une configuration, noms trouves dans les donnees) :
    # regles de structure seules, mots reserves compris ; le nom doit etre deja normalise ; la largeur, qui depend de la
    # police, n est controlee qu a la saisie
    $res = @{ Ok = $false; Why = ''; Name = '' }
    $n = (([string]$name).Trim()) -replace ' {2,}', ' '
    $res.Name = $n
    if (-not $n) { $res.Why = (T 'Donnez un nom au lecteur.'); return $res }
    if ($n.Length -gt [int]$script:DriveNameMax) { $res.Why = ((T 'Nom trop long : {0} caractères au plus.') -f "$([int]$script:DriveNameMax)"); return $res }
    # Lettres, chiffres, espace et - . _ + # ° (U+00B0) : « | » et « > » separent les cles du magasin, « & » marque un
    # raccourci dans un libelle, les parentheses sont reservees a la connexion (« nom (A) »)
    $bad = ''
    foreach ($ch in $n.ToCharArray()) { if ([string]$ch -cnotmatch '^[\p{L}\p{Nd} \-._+#°]$') { $bad = [string]$ch; break } }
    if (-not $bad -and $Load -and $n -cne [string]$name) { $bad = ' ' }
    if ($bad) {
        if ([char]::IsControl($bad[0]) -or ([char]::IsWhiteSpace($bad[0]) -and $bad -ne ' ')) { $bad = ('U+{0:X4}' -f [int]$bad[0]) }
        $res.Why = ((T "Caractère non admis : « {0} ». Un nom se compose de lettres, de chiffres, d'espaces et des signes - . _ + # °") -f $bad)
        return $res
    }
    if ($n -cnotmatch '[A-Za-z0-9]') { $res.Why = (T 'Un nom contient au moins une lettre sans accent ou un chiffre.'); return $res }
    foreach ($c in $script:SettingDefs['drive'].Codes) { if ([string]$c -eq $n) { $res.Why = ((T '« {0} » désigne une connexion : choisissez un autre nom.') -f $n); return $res } }
    # Mots reserves : une table PowerShell rend la valeur d une cle avant sa propre propriete ; une fiche « Count » ferait
    # lever une erreur a la garde « registre non vide » au lieu de la rendre vraie
    foreach ($w in @($script:DriveReserved)) { if ([string]$w -eq $n) { $res.Why = ((T '« {0} » est un mot réservé : choisissez un autre nom.') -f $n); return $res } }
    $dup = Get-DriveRecord $n
    $dupName = if ($dup) { [string]$dup.Name } elseif ($script:DriveReg -and $script:DriveReg.Contains($n)) { $n } else { '' }
    if ($dupName -and -not ($self -and $dupName -eq $self)) { $res.Why = ((T 'Un lecteur enregistré porte déjà ce nom : {0}.') -f $dupName); return $res }
    if (-not $Load -and $form -and $form.Font) {
        # Liste du bandeau elargie et liste « Lecteur cible » : 24 px de moins que leur largeur pour le texte d un element
        $w = [System.Windows.Forms.TextRenderer]::MeasureText($n, $form.Font).Width
        if ($w -gt ([int]$script:DriveListWidth - 24)) { $res.Why = (T "Nom trop large pour s'afficher en entier dans les listes de lecteurs (environ 17 caractères) : raccourcissez-le."); return $res }
    }
    $res.Ok = $true
    return $res
}

function Get-DriveData([string]$drive, $old = $null) {
    # 12.11 : ce qui est range sous un lecteur (code d une connexion ou nom), dans tous les porteurs de l identite :
    # @{ Keys (cles de magasin de ses courbes, courbes d un autre calcul en attente du choix comprises) ; Cross (cles
    # croisees dont il est la source ou la cible) ; Levels, Brands, Factors (niveaux de la calibration rapide, entrees de
    # la memoire par marque, facteurs mesures sur l image) ; Target (son lecteur cible) ; TargetOf (lecteurs dont il est
    # le lecteur cible) ; Last (connexions dont il est le dernier lecteur choisi) ; Latest (date de sa courbe la plus
    # recente) ; Any }. Any : vrai des que Keys, Cross, Levels, Brands, Factors, Target ou TargetOf est non vide (un
    # lecteur qui n apparait que comme cible porte une donnee). $old : courbes en attente du choix pendant Load-Config,
    # avant que $script:OldCalib soit pose. Les champs se lisent par l index (['Keys']) : sur une table, .Keys rendrait
    # ce champ, pas les cles
    $keys = @(); $cross = @(); $levels = @(); $brands = @(); $factors = @(); $tgtOf = @(); $last = @(); $tgt = ''; $latest = ''; $bd = [datetime]::MinValue
    if (-not $drive) { return @{ Keys = @(); Cross = @(); Levels = @(); Brands = @(); Factors = @(); Target = ''; TargetOf = @(); Last = @(); Latest = ''; Any = $false } }
    $oc = $script:OldCalib
    $tabs = @()
    if ($null -ne $script:DriveCurves) { $tabs += ,$script:DriveCurves }
    if ($null -ne $old) { $tabs += ,$old } elseif ($oc -and $null -ne $oc.Curves) { $tabs += ,$oc.Curves }
    foreach ($tb in $tabs) {
        foreach ($e in @($tb.GetEnumerator())) {
            $sk = [string]$e.Key; $cv = $e.Value
            if (-not $cv) { continue }
            $d = [string](Split-DriveCurveKey $sk).Drive
            $x = Split-CrossDrive $d
            $mine = $false
            if ($x) { if ([string]$x.Src -eq $drive -or [string]$x.Tgt -eq $drive) { $cross += $sk; $mine = $true } }
            elseif ($d -eq $drive) { $keys += $sk; $mine = $true }
            if ($mine) { $dt = Get-CurveDate $cv; if (-not $latest -or $dt -gt $bd) { $bd = $dt; $latest = [string]$cv.Date } }
        }
    }
    $lvs = @()
    if ($null -ne $script:LevelShifts) { $lvs += @($script:LevelShifts.GetEnumerator() | ForEach-Object { $_.Value }) }
    if ($null -eq $old -and $oc -and $null -ne $oc.Levels) { $lvs += @($oc.Levels.GetEnumerator() | ForEach-Object { $_.Value }) }
    $levels = @($lvs | Where-Object { $_ -and [string]$_.Drive -eq $drive })
    $brands = @(@($script:LevelBrands) | Where-Object { $_ -and [string]$_.Drive -eq $drive })
    $factors = @(@($script:ContentMeasures) | Where-Object { $_ -and [string]$_.Drive -eq $drive })
    if ($null -ne $script:TargetDrives) {
        foreach ($e in @($script:TargetDrives.GetEnumerator())) {
            if ([string]$e.Key -eq $drive -and [string]$e.Value) { $tgt = [string]$e.Value }
            if ([string]$e.Value -eq $drive) { $tgtOf += [string]$e.Key }
        }
    }
    if ($script:DriveLast) { foreach ($e in @($script:DriveLast.GetEnumerator())) { if ([string]$e.Value -eq $drive) { $last += [string]$e.Key } } }
    $any = ($keys.Count -gt 0 -or $cross.Count -gt 0 -or $levels.Count -gt 0 -or $brands.Count -gt 0 -or $factors.Count -gt 0 -or [bool]$tgt -or $tgtOf.Count -gt 0)
    return @{ Keys = @($keys | Sort-Object); Cross = @($cross | Sort-Object); Levels = $levels; Brands = $brands; Factors = $factors; Target = $tgt; TargetOf = @($tgtOf | Sort-Object); Last = @($last | Sort-Object); Latest = $latest; Any = $any }
}

function Get-DriveDataText($data) {
    # 12.11 : texte des calibrations d un lecteur (Get-DriveData) : « 5 courbe(s) dont 2 croisee(s), derniere : ... »,
    # « 2 courbe(s), derniere : ... » ou « aucune »
    if ($null -eq $data) { return (T 'aucune') }
    $nk = @($data['Keys']).Count; $nx = @($data['Cross']).Count
    if ($nk + $nx -eq 0) { return (T 'aucune') }
    $dt = [string]$data['Latest']; if (-not $dt) { $dt = '?' }
    if ($nx -gt 0) { return ((T '{0} courbe(s) dont {1} croisée(s), dernière : {2}') -f "$($nk + $nx)", "$nx", $dt) }
    return ((T '{0} courbe(s), dernière : {1}') -f "$nk", $dt)
}

function Get-DriveMovedKey([string]$storeKey, [string]$from, [string]$to) {
    # 12.11 : cle de magasin (« lecteur|cle », « source>cible|cle ») quand les donnees de $from passent sous $to ($to
    # vide : retrait). Rend @{ Key (nouvelle cle ; '' : courbe retiree) ; Moved (la cle cite $from) }
    $p = Split-DriveCurveKey $storeKey
    $d = [string]$p.Drive; $k = [string]$p.Key
    $x = Split-CrossDrive $d
    if ($x) {
        $s = [string]$x.Src; $t = [string]$x.Tgt
        if ($s -ne $from -and $t -ne $from) { return @{ Key = $storeKey; Moved = $false } }
        if (-not $to) { return @{ Key = ''; Moved = $true } }
        if ($s -eq $from) { $s = $to }
        if ($t -eq $from) { $t = $to }
        return @{ Key = (Get-DriveCurveKey "$s>$t" $k); Moved = $true }
    }
    if ($d -ne $from) { return @{ Key = $storeKey; Moved = $false } }
    if (-not $to) { return @{ Key = ''; Moved = $true } }
    return @{ Key = (Get-DriveCurveKey $to $k); Moved = $true }
}

function Edit-DriveData([string]$from, [string]$to, [switch]$Check) {
    # 12.11 : seule fonction qui change l identite de donnees : tout ce qui est range sous $from passe sous $to, ou est
    # retire si $to est vide. Porteurs, tous ici : (1) cles de $script:DriveCurves, simples et croisees, la source comme
    # la cible ; (2) champs Drive et Target des courbes deplacees ; (3) $script:OldCalib.Curves et .Levels ;
    # (4) $script:LevelShifts ; (5) $script:LevelBrands ; (6) $script:ContentMeasures ; (7) $script:TargetDrives, comme
    # source et comme cible ; (8) $script:DriveLast. La vue ($script:PrecompCurves) n est jamais ecrite ici :
    # l appelant la refait par Sync-PrecompCurves.
    # Jamais de fusion : refus sans effet si $to porte deja une donnee (Get-DriveData : Any) ou si une cle d arrivee
    # existe deja. $to egal a $from a la casse pres (correction de casse d un nom) : admis, ce refus ne s applique pas.
    # Deux temps : calcul des nouvelles tables et de la liste des champs a reecrire, sans aucun effet, puis affectations
    # simples : tout ou rien. Chaque table est reconstruite a partir d une table vide, cle par cle ; jamais d ajout puis
    # de retrait dans la table en place, qui detruit l entree quand les deux cles ne different que par la casse.
    # -Check : premier temps seul (decision et texte du refus, sans rien changer). Rend @{ Ok ; Why ; N (courbes
    # deplacees ou retirees) }
    $res = @{ Ok = $false; Why = ''; N = 0 }
    if (-not $from) { return $res }
    $same = ($from -eq $to)
    $toConn = Test-DriveConnCode $to
    $refuse = if ($toConn) { ((T 'La connexion {0} a déjà des calibrations sans nom de lecteur : le nom ne peut pas être retiré seul.') -f $to) } else { ((T 'Le lecteur {0} a déjà des calibrations : celles de la connexion {1} ne peuvent pas lui être attribuées.') -f $to, $from) }
    # --- Premier temps : calcul, sans effet -------------------------------------------------------------------------
    $fix = @(); $n = 0; $clash = $false
    $nCurves = @{}; $nOld = [ordered]@{}; $nOldLv = @{}; $nLv = @{}; $nBr = @(); $nCm = @(); $nTd = @{}; $nLast = @{}
    $oc = $script:OldCalib
    $hasOld = [bool]($oc -and $null -ne $oc.Curves); $hasOldLv = [bool]($oc -and $null -ne $oc.Levels)
    try {
        if ($to -and -not $same -and (Get-DriveData $to)['Any']) { $res.Why = $refuse; return $res }
        # (1) (2) (3) courbes du magasin et courbes d un autre calcul en attente du choix
        $src = @()
        if ($null -ne $script:DriveCurves) { $src += ,@($script:DriveCurves, $nCurves) }
        if ($hasOld) { $src += ,@($oc.Curves, $nOld) }
        foreach ($pair in $src) {
            $new = $pair[1]
            foreach ($e in @($pair[0].GetEnumerator())) {
                $sk = [string]$e.Key; $cv = $e.Value
                $m = Get-DriveMovedKey $sk $from $to
                $nk = [string]$m.Key
                if ($m.Moved) {
                    if ($cv) { $n++ }
                    if (-not $nk) { continue }
                    if ($cv) {
                        if ([string]$cv.Drive -eq $from) { $fix += ,@{ O = $cv; F = 'Drive'; V = $to } }
                        if ([string]$cv.Target -eq $from) { $fix += ,@{ O = $cv; F = 'Target'; V = $to } }
                    }
                }
                if ($new.Contains($nk)) { $clash = $true }
                $new.Add($nk, $cv)
            }
        }
        # (3) (4) niveaux de la calibration rapide : meme cle (« cle de courbe|tete », sans lecteur), champ Drive
        $src = @()
        if ($null -ne $script:LevelShifts) { $src += ,@($script:LevelShifts, $nLv) }
        if ($hasOldLv) { $src += ,@($oc.Levels, $nOldLv) }
        foreach ($pair in $src) {
            $new = $pair[1]
            foreach ($e in @($pair[0].GetEnumerator())) {
                $lr = $e.Value
                if ($lr -and [string]$lr.Drive -eq $from) { if (-not $to) { continue }; $fix += ,@{ O = $lr; F = 'Drive'; V = $to } }
                $new.Add([string]$e.Key, $lr)
            }
        }
        # (5) memoire par marque, (6) facteurs mesures sur l image : champ Drive
        foreach ($en in @($script:LevelBrands)) {
            if ($null -eq $en) { continue }
            if ([string]$en.Drive -eq $from) { if (-not $to) { continue }; $fix += ,@{ O = $en; F = 'Drive'; V = $to } }
            $nBr += ,$en
        }
        foreach ($rec in @($script:ContentMeasures)) {
            if ($null -eq $rec) { continue }
            if ([string]$rec.Drive -eq $from) { if (-not $to) { continue }; $fix += ,@{ O = $rec; F = 'Drive'; V = $to } }
            $nCm += ,$rec
        }
        # (7) lecteurs cibles : la source comme la cible
        if ($null -ne $script:TargetDrives) {
            foreach ($e in @($script:TargetDrives.GetEnumerator())) {
                $s = [string]$e.Key; $t = [string]$e.Value
                if ($s -eq $from -or $t -eq $from) {
                    if (-not $to) { continue }
                    if ($s -eq $from) { $s = $to }
                    if ($t -eq $from) { $t = $to }
                }
                if ($nTd.Contains($s)) { $clash = $true }
                $nTd.Add($s, $t)
            }
        }
        # (8) dernier lecteur choisi par connexion : des noms seulement (un nom retire ou rendu a sa connexion en sort)
        if ($script:DriveLast) {
            foreach ($e in @($script:DriveLast.GetEnumerator())) {
                $v = [string]$e.Value
                if ($v -eq $from) { if (-not $to -or $toConn) { continue }; $v = $to }
                $nLast.Add([string]$e.Key, $v)
            }
        }
    } catch {
        if (-not $clash) { $res.Why = ([string]$_.Exception.Message).Trim(); return $res }
    }
    if ($clash) { $res.Why = $refuse; return $res }
    $res.N = $n
    if ($Check) { $res.Ok = $true; return $res }
    # --- Second temps : affectations simples -------------------------------------------------------------------------
    $script:DriveCurves = $nCurves
    if ($hasOld) { $script:OldCalib.Curves = $nOld }
    if ($hasOldLv) { $script:OldCalib.Levels = $nOldLv }
    $script:LevelShifts = $nLv
    $script:LevelBrands = $nBr
    $script:ContentMeasures = $nCm
    $script:TargetDrives = $nTd
    $script:DriveLast = $nLast
    foreach ($f in $fix) { $f.O[[string]$f.F] = [string]$f.V }
    $res.Ok = $true
    return $res
}

function Get-DriveNow {
    # 12.11 : date et heure d une fiche (Created, At), a la seconde, meme forme que _saved
    return (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-DriveDate([string]$s) {
    # 12.11 : date d une fiche (yyyy-MM-dd HH:mm:ss) ; MinValue si elle est vide ou illisible
    $d = [datetime]::MinValue
    if ($s -and [datetime]::TryParseExact($s, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$d)) { return $d }
    return [datetime]::MinValue
}

function Backup-ConfigForDrives {
    # 12.11 : copie datee, octet pour octet, du fichier de configuration sur disque avant une modification des lecteurs
    # enregistres : <fichier>.lecteurs-<AAAAMMJJ-HHmmss>.bak, date et heure de la copie ; nom deja pris : suffixe -2,
    # -3... avant .bak (une copie n en ecrase jamais une autre). Rotation propre : les $script:DriveBackupKeep copies
    # .lecteurs-*.bak les plus recentes sont gardees ; les copies .ref-*.bak de Backup-ConfigBeforeRef ne sont ni comptees
    # ni touchees. Rend @{ Ok ; Bak ; Why } : un echec ne se confond jamais avec « rien a copier »
    $res = @{ Ok = $false; Bak = ''; Why = '' }
    $cfg = [string]$script:ConfigFile
    $bak = ''; $dir = ''; $leaf = ''
    try {
        $leaf = [System.IO.Path]::GetFileName($cfg); $dir = Split-Path -Parent $cfg
        $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss', [System.Globalization.CultureInfo]::InvariantCulture)
        $base = Join-Path $dir ($leaf + '.lecteurs-' + $stamp)
        $bak = $base + '.bak'; $i = 1
        while (Test-Path -LiteralPath $bak) { $i++; $bak = $base + '-' + $i + '.bak' }
        [System.IO.File]::Copy($cfg, $bak, $false)
        [System.IO.File]::SetLastWriteTime($bak, (Get-Date))
    } catch {
        $msg = ([string]$(if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message })).Trim().TrimEnd('.')
        Append-Log ((T "Configuration non copiée avant la modification des lecteurs enregistrés : {0}. Modification annulée : rien n'est changé.") -f "$msg")
        $res.Why = $msg
        return $res
    }
    Append-Log ((T 'Configuration sauvegardée avant la modification des lecteurs enregistrés : {0}') -f "$bak")
    $keep = [math]::Max(1, [int]$script:DriveBackupKeep)
    try {
        $bakName = [System.IO.Path]::GetFileName($bak)
        $all = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction Stop | Where-Object { $_.Name -like ($leaf + '.lecteurs-*.bak') -and $_.Name -ne $bakName } | Sort-Object -Property @{ Expression = { $_.LastWriteTime }; Descending = $true }, @{ Expression = { $_.Name }; Descending = $true })
        foreach ($f in @($all | Select-Object -Skip ($keep - 1))) {
            try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; Append-Log ((T "Ancienne sauvegarde de configuration supprimée ({1} gardées) : {0}") -f "$($f.FullName)", "$keep") } catch { }
        }
    } catch { }
    $res.Ok = $true; $res.Bak = $bak
    return $res
}

function Protect-DriveData([string[]]$drives) {
    # 12.11 : avant une modification des donnees de ces lecteurs. Sans aucune donnee sous eux (Get-DriveData : Any faux
    # pour tous) : Ok, sans copie. Sinon : enregistrement (le fichier sur disque devient l etat d avant ; son bloc
    # drives est ecrit meme avec une liste vide, $script:DriveBlockKeep, si bien que la copie d avant la premiere
    # attribution dit « aucun lecteur enregistre »), puis copie datee (Backup-ConfigForDrives). Enregistrement ou copie
    # en echec : Ok faux, l appelant annule la modification. Rend @{ Ok ; Bak ; Copy (une copie a ete faite) ; Why }
    $res = @{ Ok = $true; Bak = ''; Copy = $false; Why = '' }
    $any = $false
    foreach ($d in @($drives)) { if ($d -and (Get-DriveData $d)['Any']) { $any = $true } }
    if (-not $any) { return $res }
    $res.Ok = $false
    $saved = $false
    $script:DriveBlockKeep = $true
    # Le temps de cet enregistrement, une erreur d ecriture du fichier arrete Save-Config (qui la note et rend faux) au
    # lieu d etre seulement affichee : sans cela, la copie qui suit serait celle d un fichier perime
    $eap = $ErrorActionPreference
    try { $ErrorActionPreference = 'Stop'; $saved = [bool](Save-Config) } catch { $saved = $false } finally { $ErrorActionPreference = $eap; $script:DriveBlockKeep = $false }
    if (-not $saved) {
        Append-Log (T "Configuration non enregistrée avant la modification des lecteurs enregistrés. Modification annulée : rien n'est changé.")
        $res.Why = (T "Configuration non sauvegardée : rien n'a été modifié (voir le journal).")
        return $res
    }
    $bk = Backup-ConfigForDrives
    if (-not $bk.Ok) { $res.Why = (T "Configuration non sauvegardée : rien n'a été modifié (voir le journal)."); return $res }
    $res.Ok = $true; $res.Bak = [string]$bk.Bak; $res.Copy = $true
    return $res
}

function New-DriveId([string]$kind = 'L') {
    # 12.11 : identifiant d une fiche neuve, jamais deduit d un compteur : la lettre L (R : fiche refaite d apres les
    # donnees par Repair-DriveRegistry ou a la lecture), la date et l heure a la seconde, un tiret et un rang a deux
    # chiffres parmi les fiches de la meme seconde : « L20261120180211-01 ». Unique dans le registre, inchange par un
    # renommage ou un changement de connexion : il ne range rien, il relie un nom lu dans une copie datee au lecteur
    # d aujourd hui (Resolve-DriveOfEra)
    if ($kind -cne 'R') { $kind = 'L' }
    $used = @{}
    if ($script:DriveReg) { foreach ($e in @($script:DriveReg.GetEnumerator())) { $u = [string]$e.Value.Id; if ($u.Length -gt 1) { $used[$u.Substring(1)] = $true } } }
    while ($true) {
        $stamp = (Get-Date).ToString('yyyyMMddHHmmss', [System.Globalization.CultureInfo]::InvariantCulture)
        for ($r = 1; $r -le 99; $r++) { $tail = ('{0}-{1:00}' -f $stamp, $r); if (-not $used.ContainsKey($tail)) { return ($kind + $tail) } }
        Start-Sleep -Milliseconds 250
    }
}

function New-DriveRegTable($records) {
    # 12.11 : registre construit a partir d une table vide, dans l ordre donne ; rien n est affecte ici
    $t = [ordered]@{}
    foreach ($r in @($records)) { if ($r) { $t.Add([string]$r.Name, $r) } }
    return $t
}

function Get-DriveEditRefusal {
    # 12.11 : refus commun des quatre actions du registre : operation en cours (le texte porte le libelle rendu par
    # Get-AppBusy, la fonction qui decide), ou calibration B en cours ou en attente de sa decision ; '' sinon
    $busy = Get-AppBusy -Text
    if ($busy) { return ((T 'Lecteurs enregistrés : opération en cours ({0}). Réessayez quand elle est terminée.') -f "$busy") }
    if ($script:CalRedo) { return (T "Calibration B en cours ou en attente de décision : terminez-la d'abord.") }
    return ''
}

function Add-NamedDrive([string]$name, [string]$conn, [string]$from = '') {
    # 12.11 : enregistre un lecteur (fiche neuve : Id, Created). Avec $from (une connexion) : nomme le lecteur non
    # enregistre de cette connexion, dont les donnees passent sous le nom (copie datee d abord, des qu il en a une), et
    # pose From et At ; avec le nom d une fiche existante sans aucune donnee : attribution a cette fiche, qui garde son
    # identifiant. Jamais de fusion (refus d Edit-DriveData). Rend @{ Ok ; Why ; Name ; N ; Bak ; Copy }
    $res = @{ Ok = $false; Why = ''; Name = ''; N = 0; Bak = ''; Copy = $false }
    $why = Get-DriveEditRefusal
    if ($why) { $res.Why = $why; return $res }
    if (-not (Test-DriveConnCode $conn) -or ($from -and -not (Test-DriveConnCode $from))) { $res.Why = (T 'Choisissez la connexion du lecteur.'); return $res }
    $rec = $null
    if ($from) { $rec = Get-DriveRecord (([string]$name).Trim()) }
    $nm = ''
    if ($rec) { $nm = [string]$rec.Name }
    else {
        $tn = Test-DriveName $name
        if (-not $tn.Ok) { $res.Why = [string]$tn.Why; return $res }
        $nm = [string]$tn.Name
    }
    $now = Get-DriveNow
    $newReg = $null
    if (-not $rec) {
        $nrec = @{ Name = $nm; Conn = $conn; Id = (New-DriveId 'L'); Created = $now; From = ''; At = '' }
        if ($from) { $nrec.From = $from; $nrec.At = $now }
        $list = @(); if ($script:DriveReg) { $list = @($script:DriveReg.GetEnumerator() | ForEach-Object { $_.Value }) }
        try { $newReg = New-DriveRegTable (@($list) + @($nrec)) } catch { $res.Why = ((T 'Un lecteur enregistré porte déjà ce nom : {0}.') -f $nm); return $res }
    }
    if ($from) {
        $chk = Edit-DriveData $from $nm -Check
        if (-not $chk.Ok) { $res.Why = [string]$chk.Why; return $res }
        $pr = Protect-DriveData @($from)
        if (-not $pr.Ok) { $res.Why = [string]$pr.Why; return $res }
        $ed = Edit-DriveData $from $nm
        if (-not $ed.Ok) { $res.Why = [string]$ed.Why; return $res }
        $res.N = [int]$ed.N; $res.Bak = [string]$pr.Bak; $res.Copy = [bool]$pr.Copy
    }
    if ($rec) { $rec.Conn = $conn; $rec.From = $from; $rec.At = $now }
    else { $script:DriveReg = $newReg }
    if ($script:DriveChecked -and ([string]$script:DriveChecked -eq $nm -or [string]$script:DriveChecked -eq $from)) { $script:DriveChecked = '' }
    Sync-PrecompCurves
    $res.Ok = $true; $res.Name = $nm
    return $res
}

function Rename-NamedDrive([string]$old, [string]$new) {
    # 12.11 : renomme un lecteur enregistre : ses donnees passent sous le nouveau nom (copie datee d abord, des qu il en
    # a une), la fiche garde son identifiant et son rang ; une correction de casse est un renommage comme un autre. Le
    # registre est reconstruit (la fiche sous l autre casse, affectee puis retiree en place, serait videe). Rend
    # @{ Ok ; Why ; Name ; N ; Bak ; Copy }
    $res = @{ Ok = $false; Why = ''; Name = ''; N = 0; Bak = ''; Copy = $false }
    $why = Get-DriveEditRefusal
    if ($why) { $res.Why = $why; return $res }
    $rec = Get-DriveRecord $old
    if (-not $rec) { return $res }
    $cur = [string]$rec.Name
    $tn = Test-DriveName $new $cur
    if (-not $tn.Ok) { $res.Why = [string]$tn.Why; return $res }
    $nm = [string]$tn.Name
    $res.Name = $nm
    if ($nm -ceq $cur) { $res.Ok = $true; return $res }
    $nrec = @{}
    foreach ($e in @($rec.GetEnumerator())) { $nrec[[string]$e.Key] = $e.Value }
    $nrec.Name = $nm
    $newReg = $null
    try { $newReg = New-DriveRegTable @($script:DriveReg.GetEnumerator() | ForEach-Object { if ([object]::ReferenceEquals($_.Value, $rec)) { $nrec } else { $_.Value } }) }
    catch { $res.Why = ((T 'Un lecteur enregistré porte déjà ce nom : {0}.') -f $nm); return $res }
    $chk = Edit-DriveData $cur $nm -Check
    if (-not $chk.Ok) { $res.Why = [string]$chk.Why; return $res }
    $pr = Protect-DriveData @($cur)
    if (-not $pr.Ok) { $res.Why = [string]$pr.Why; return $res }
    $ed = Edit-DriveData $cur $nm
    if (-not $ed.Ok) { $res.Why = [string]$ed.Why; return $res }
    $script:DriveReg = $newReg
    if ($script:DriveChecked -and ([string]$script:DriveChecked -eq $cur -or [string]$script:DriveChecked -eq $nm)) { $script:DriveChecked = '' }
    Sync-PrecompCurves
    $res.Ok = $true; $res.N = [int]$ed.N; $res.Bak = [string]$pr.Bak; $res.Copy = [bool]$pr.Copy
    return $res
}

function Move-NamedDrive([string]$name, [string]$conn) {
    # 12.11 : change la connexion de la fiche et retire de $script:DriveLast toute entree qui cite ce lecteur ; aucune
    # cle, aucun champ de donnee : les calibrations suivent le nom. Rend @{ Ok ; Why ; Name ; Old (connexion d avant) }
    $res = @{ Ok = $false; Why = ''; Name = ''; Old = '' }
    $why = Get-DriveEditRefusal
    if ($why) { $res.Why = $why; return $res }
    $rec = Get-DriveRecord $name
    if (-not $rec) { return $res }
    if (-not (Test-DriveConnCode $conn)) { $res.Why = (T 'Choisissez la connexion du lecteur.'); return $res }
    $nm = [string]$rec.Name
    $nLast = @{}
    if ($script:DriveLast) { foreach ($e in @($script:DriveLast.GetEnumerator())) { if ([string]$e.Value -ne $nm) { $nLast.Add([string]$e.Key, [string]$e.Value) } } }
    $res.Old = [string]$rec.Conn
    $rec.Conn = $conn
    $script:DriveLast = $nLast
    if ($script:DriveChecked -and [string]$script:DriveChecked -eq $nm) { $script:DriveChecked = '' }
    Sync-PrecompCurves
    $res.Ok = $true; $res.Name = $nm
    return $res
}

function Remove-NamedDrive([string]$name, [switch]$KeepData) {
    # 12.11 : supprime la fiche et ce qui est range sous le nom : ses courbes, les courbes croisees dont il est la
    # source ou la cible, ses niveaux, sa memoire par marque, ses facteurs, son lecteur cible et le choix de ce lecteur
    # comme cible d un autre (copie datee obligatoire d abord, des qu il a une donnee : sans elle, rien n est supprime).
    # -KeepData : retire seulement le nom ; ses donnees vont sous le code de la connexion de sa fiche, la forme qu une
    # 12.10 retrouve ; refus si ce code porte deja une donnee ou si la fiche n a pas de connexion. Rend
    # @{ Ok ; Why ; Name ; Conn ; N ; Bak ; Copy }
    $res = @{ Ok = $false; Why = ''; Name = ''; Conn = ''; N = 0; Bak = ''; Copy = $false }
    $why = Get-DriveEditRefusal
    if ($why) { $res.Why = $why; return $res }
    $rec = Get-DriveRecord $name
    if (-not $rec) { return $res }
    $nm = [string]$rec.Name; $conn = [string]$rec.Conn
    $to = ''
    if ($KeepData) {
        if (-not (Test-DriveConnCode $conn)) { $res.Why = (T 'Choisissez la connexion du lecteur.'); return $res }
        $to = $conn
    }
    $newReg = New-DriveRegTable @($script:DriveReg.GetEnumerator() | ForEach-Object { if (-not [object]::ReferenceEquals($_.Value, $rec)) { $_.Value } })
    $chk = Edit-DriveData $nm $to -Check
    if (-not $chk.Ok) { $res.Why = [string]$chk.Why; return $res }
    $pr = Protect-DriveData @($nm)
    if (-not $pr.Ok) { $res.Why = [string]$pr.Why; return $res }
    $ed = Edit-DriveData $nm $to
    if (-not $ed.Ok) { $res.Why = [string]$ed.Why; return $res }
    $script:DriveReg = $newReg
    if ($script:DriveChecked -and [string]$script:DriveChecked -eq $nm) { $script:DriveChecked = '' }
    Sync-PrecompCurves
    $res.Ok = $true; $res.Name = $nm; $res.Conn = $conn; $res.N = [int]$ed.N; $res.Bak = [string]$pr.Bak; $res.Copy = [bool]$pr.Copy
    return $res
}

function Get-DriveField($o, [string]$name) {
    # 12.11 : champ d un bloc de la configuration, lu dans un objet de ConvertFrom-Json ou dans une table (bloc rendu par
    # Export-DriveRegistry) ; $null s il est absent. Table : par enumeration, sans index (une connexion « 0 » ne doit pas
    # etre prise pour un rang)
    if ($null -eq $o -or $o -is [string] -or $o -is [ValueType] -or $o -is [array]) { return $null }
    if ($o -is [System.Collections.IDictionary]) {
        foreach ($e in @($o.GetEnumerator())) { if ([string]$e.Key -eq $name) { return $e.Value } }
        return $null
    }
    $p = $o.PSObject.Properties[$name]
    if ($null -ne $p) { return $p.Value }
    return $null
}

function Get-DriveBlockItems($block) {
    # 12.11 : entrees de la liste d un bloc drives, une a une : @{ Id ; Name ; Conn ; Created ; From ; At }, textes
    # bruts ; une entree qui n est pas un objet est rendue sans nom (elle sera comptee illisible)
    foreach ($it in @(Get-DriveField $block 'list')) {
        if ($null -eq $it) { continue }
        @{ Id = [string](Get-DriveField $it 'id'); Name = [string](Get-DriveField $it 'name'); Conn = [string](Get-DriveField $it 'conn')
           Created = [string](Get-DriveField $it 'created'); From = [string](Get-DriveField $it 'from'); At = [string](Get-DriveField $it 'at') }
    }
}

function Get-DriveRescuePath {
    # 12.11 : copie de secours du registre, a cote du fichier de configuration : <fichier>.lecteurs (son nom ne finit pas
    # par .bak : ni la rotation des copies, ni leur lecture ne la voient)
    $c = [string]$script:ConfigFile
    if (-not $c) { return '' }
    return ($c + '.lecteurs')
}

function Get-DriveTargetPairs {
    # 12.11 : couples « source, cible » des lecteurs cibles dont l un au moins est un lecteur enregistre, sources
    # triees, un a un : @{ Src ; Tgt }. Une version anterieure, qui ne connait pas les noms, les retire a son premier
    # enregistrement : la copie de secours les garde
    if ($null -eq $script:TargetDrives) { return }
    foreach ($s in @($script:TargetDrives.GetEnumerator() | ForEach-Object { [string]$_.Key } | Sort-Object)) {
        $t = Get-TargetDrive $s
        if ($t -and ((Test-DriveRegistered $s) -or (Test-DriveRegistered $t))) { @{ Src = $s; Tgt = [string]$t } }
    }
}

function Get-DriveRescueText($items, $last, $pairs) {
    # 12.11 : contenu utile de la copie de secours (fiches, dernier lecteur par connexion, couples de lecteurs cibles),
    # en un texte de forme fixe, sans _saved : la copie n est reecrite que s il change
    $l = @()
    foreach ($it in @($items)) { if ($it) { $l += ,([ordered]@{ id = [string]$it.Id; name = [string]$it.Name; conn = [string]$it.Conn; created = [string]$it.Created; from = [string]$it.From; at = [string]$it.At }) } }
    $la = [ordered]@{}
    foreach ($c in $script:SettingDefs['drive'].Codes) { $v = [string](Get-DriveField $last ([string]$c)); if ($v) { $la.Add([string]$c, $v) } }
    $tg = @()
    foreach ($p in @($pairs)) { if ($p) { $tg += ,([ordered]@{ source = [string]$p.Src; target = [string]$p.Tgt }) } }
    return (([ordered]@{ drives = [ordered]@{ list = $l; last = $la }; targets = $tg }) | ConvertTo-Json -Depth 6 -Compress)
}

function Read-DriveRescue {
    # 12.11 : copie de secours du registre : @{ Found ; Ok ; Path ; Items (fiches brutes) ; Last ; Pairs (@{ Src ; Tgt }) ;
    # Text (contenu utile, Get-DriveRescueText) ; Why (fichier illisible) }. Elle ne porte aucune courbe
    $p = Get-DriveRescuePath
    $res = @{ Found = $false; Ok = $false; Path = $p; Items = @(); Last = $null; Pairs = @(); Text = $null; Why = '' }
    if (-not $p -or -not (Test-Path -LiteralPath $p -PathType Leaf)) { return $res }
    $res.Found = $true
    try {
        $o = Get-Content -LiteralPath $p -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $blk = Get-DriveField $o 'drives'
        $items = @(Get-DriveBlockItems $blk)
        $last = Get-DriveField $blk 'last'
        $pairs = @()
        foreach ($t in @(Get-DriveField $o 'targets')) {
            $s = [string](Get-DriveField $t 'source'); $g = [string](Get-DriveField $t 'target')
            if ($s -and $g) { $pairs += ,@{ Src = $s; Tgt = $g } }
        }
        $res.Items = $items; $res.Last = $last; $res.Pairs = $pairs
        $res.Text = Get-DriveRescueText $items $last $pairs
        $res.Ok = $true
    } catch { $res.Why = ([string]$_.Exception.Message).Trim() }
    return $res
}

function Save-DriveRescue($block) {
    # 12.11 : copie de secours du registre, ecrite par Save-Config apres l ecriture reussie du fichier principal :
    # { _comment, _saved, version, drives, targets }. Ecrite seulement quand son contenu utile differe du dernier lu ou
    # ecrit ($script:DriveRescueText) : Save-Config precede chaque commande gw. Registre devenu vide : reecrite avec une
    # liste vide, jamais supprimee ; registre vide et copie ni lue ni ecrite dans la session : aucun fichier n est cree
    # ni touche. Echec : une ligne de journal, l enregistrement de la configuration reste reussi. Rend vrai si la copie a
    # ete ecrite
    if ($null -eq $block) { return $false }
    $p = Get-DriveRescuePath
    if (-not $p) { return $false }
    $items = @(Get-DriveBlockItems $block)
    if ($items.Count -eq 0 -and $null -eq $script:DriveRescueText) { return $false }
    $pairs = @(Get-DriveTargetPairs)
    $txt = Get-DriveRescueText $items (Get-DriveField $block 'last') $pairs
    if ($null -ne $script:DriveRescueText -and $txt -ceq [string]$script:DriveRescueText) { return $false }
    try {
        $o = [ordered]@{
            _comment = (T 'Copie de secours des lecteurs enregistrés de Greaseweazle Studio (noms, connexions, lecteurs cibles) - régénérée automatiquement.')
            _saved   = (Get-DriveNow)
            version  = [string]$script:Version
            drives   = $block
            targets  = @($pairs | ForEach-Object { [ordered]@{ source = [string]$_.Src; target = [string]$_.Tgt } })
        }
        $o | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $p -Encoding UTF8 -ErrorAction Stop
        $script:DriveRescueText = $txt
        return $true
    } catch {
        Append-Log ((T 'Copie de secours des lecteurs enregistrés non écrite ({0}) : {1}') -f "$p", "$(([string]$_.Exception.Message).Trim())")
        return $false
    }
}

function Export-DriveRegistry {
    # 12.11 : bloc drives de la configuration : { list : fiches dans l ordre du registre ; last : dernier lecteur
    # enregistre choisi par connexion }. $null avec un registre vide : qui n a jamais enregistre de lecteur garde un
    # fichier aux cles exactes de la 12.10. Bloc a liste vide dans deux cas : l enregistrement que Protect-DriveData fait
    # avant sa copie ($script:DriveBlockKeep), et tant qu une copie de secours a ete lue ou ecrite dans la session
    # ($script:DriveRescueText) : un bloc present fait foi, liste vide comprise
    $recs = @()
    if ($script:DriveReg) { $recs = @($script:DriveReg.GetEnumerator() | ForEach-Object { $_.Value }) }
    if ($recs.Count -eq 0 -and -not $script:DriveBlockKeep -and $null -eq $script:DriveRescueText) { return $null }
    $list = @()
    foreach ($r in $recs) { $list += ,([ordered]@{ id = [string]$r.Id; name = [string]$r.Name; conn = [string]$r.Conn; created = [string]$r.Created; from = [string]$r.From; at = [string]$r.At }) }
    $last = [ordered]@{}
    foreach ($c in $script:SettingDefs['drive'].Codes) { $l = Get-DriveForConn ([string]$c); if ($l -cne [string]$c) { $last.Add([string]$c, $l) } }
    return [ordered]@{ list = $list; last = $last }
}

function Import-DriveRegistry($cfg, $old = $null) {
    # 12.11 : bloc drives de la configuration -> registre ($script:DriveReg, $script:DriveLast, vides d abord). Un bloc
    # present fait foi, liste vide comprise. Bloc absent (fichier enregistre par une version anterieure, ou copie datee
    # plus ancienne remise a sa place : rien ne les distingue) : registre relu dans la copie de secours si elle a des
    # fiches ; $script:DriveRescued, et ses couples de lecteurs cibles en attente ($script:DriveRescuePairs,
    # Restore-DriveRescueTargets). La copie de secours est toujours lue, pour la comparaison de Save-DriveRescue.
    # Jamais d erreur : entree au nom refuse (regles de structure, mots reserves compris), doublon a la casse pres ou
    # identifiant en double : ignoree et comptee (la premiere est gardee) ; identifiant absent ou d une autre forme :
    # fiche gardee avec un identifiant « R... » neuf ; connexion qui n est ni vide ni exactement un des six codes : fiche
    # gardee sans connexion, avec son identifiant. last : ramene au nom de la fiche, a sa casse ; registre relu dans la
    # copie de secours : retenu pour une connexion seulement si le lecteur nomme a une courbe ($old : courbes en attente
    # du choix), ou si le lecteur non enregistre de cette connexion n en a aucune (le bandeau reste sinon sur le lecteur
    # qui porte les courbes)
    $script:DriveReg = [ordered]@{}; $script:DriveLast = @{}; $script:DriveRescuePairs = $null
    $rs = Read-DriveRescue
    $script:DriveRescueText = $(if ($rs.Ok) { [string]$rs.Text } else { $null })
    $blk = Get-DriveField $cfg 'drives'
    $fromRescue = $false
    if ($null -eq $blk) {
        if ($rs.Found -and -not $rs.Ok) { Append-Log ((T 'Copie de secours des lecteurs enregistrés illisible ({0}) : {1}') -f "$($rs.Path)", "$($rs.Why)"); return }
        if (-not $rs.Ok -or @($rs.Items).Count -eq 0) { return }
        $fromRescue = $true
    }
    $items = @(); $lastRaw = $null
    if ($fromRescue) { $items = @($rs.Items); $lastRaw = $rs.Last } else { $items = @(Get-DriveBlockItems $blk); $lastRaw = Get-DriveField $blk 'last' }
    $now = Get-DriveNow
    $bad = 0; $noConn = @(); $ids = @{}; $recs = @()
    foreach ($it in $items) {
        $tn = Test-DriveName ([string]$it.Name) '' -Load
        if (-not $tn.Ok) { $bad++; continue }
        $id = [string]$it.Id
        if ($id -cnotmatch '^[LR]\d{14}-\d{2}$') { $id = '' }
        elseif ($ids.ContainsKey($id)) { $bad++; continue }
        $conn = [string]$it.Conn
        if ($conn -and -not (Test-DriveConnCode $conn)) { $conn = ''; $noConn += [string]$tn.Name }
        $created = [string]$it.Created
        if ((ConvertTo-DriveDate $created) -eq [datetime]::MinValue) { $created = $now }
        $from = [string]$it.From; $at = [string]$it.At
        if (-not (Test-DriveConnCode $from) -or (ConvertTo-DriveDate $at) -eq [datetime]::MinValue) { $from = ''; $at = '' }
        $rec = @{ Name = [string]$tn.Name; Conn = $conn; Id = $id; Created = $created; From = $from; At = $at }
        $tbl = $null
        try { $tbl = New-DriveRegTable (@($recs) + @($rec)) } catch { $bad++; continue }
        $recs += ,$rec
        $script:DriveReg = $tbl
        if ($id) { $ids[$id] = $true }
    }
    foreach ($rec in $recs) { if (-not [string]$rec.Id) { $rec.Id = New-DriveId 'R' } }
    if ($bad -gt 0) { Append-Log ((T 'Lecteurs enregistrés : {0} fiche(s) illisible(s), ignorée(s).') -f "$bad") }
    if ($noConn.Count -gt 0) { Append-Log ((T 'Lecteurs enregistrés : connexion illisible pour {0} : redonnez-la dans « Lecteurs enregistrés » (Accueil).') -f ($noConn -join ', ')) }
    $nLast = @{}
    foreach ($c in $script:SettingDefs['drive'].Codes) {
        $r = Get-DriveRecord ([string](Get-DriveField $lastRaw ([string]$c)))
        if (-not $r -or [string]$r.Conn -cne [string]$c) { continue }
        if ($fromRescue) {
            $dn = Get-DriveData ([string]$r.Name) $old; $dc = Get-DriveData ([string]$c) $old
            if ((@($dn['Keys']).Count + @($dn['Cross']).Count) -eq 0 -and (@($dc['Keys']).Count + @($dc['Cross']).Count) -gt 0) { continue }
        }
        $nLast.Add([string]$c, [string]$r.Name)
    }
    $script:DriveLast = $nLast
    if ($fromRescue) { $script:DriveRescued = $true; $script:DriveRescuePairs = @($rs.Pairs) }
}

function Get-DriveIdentities($old = $null, $targets = $null) {
    # 12.11 : identites citees par les porteurs que lit Get-DriveData, une a une, sans doublon : cles du magasin et
    # courbes en attente du choix ($old pendant Load-Config), la source et la cible d une cle croisee, champ Drive des
    # niveaux, de la memoire par marque et des facteurs mesures, sources et cibles des lecteurs cibles ($targets : bloc
    # targetDrive brut de la configuration, lu avant qu Import-TargetDrives ecarte les lecteurs inconnus)
    $seen = @{}
    $all = @()
    $oc = $script:OldCalib
    $tabs = @()
    if ($null -ne $script:DriveCurves) { $tabs += ,$script:DriveCurves }
    if ($null -ne $old) { $tabs += ,$old } elseif ($oc -and $null -ne $oc.Curves) { $tabs += ,$oc.Curves }
    foreach ($tb in $tabs) {
        foreach ($e in @($tb.GetEnumerator())) {
            $d = [string](Split-DriveCurveKey ([string]$e.Key)).Drive
            $x = Split-CrossDrive $d
            if ($x) { $all += [string]$x.Src; $all += [string]$x.Tgt } else { $all += $d }
        }
    }
    if ($null -ne $script:LevelShifts) { foreach ($e in @($script:LevelShifts.GetEnumerator())) { if ($e.Value) { $all += [string]$e.Value.Drive } } }
    if ($null -eq $old -and $oc -and $null -ne $oc.Levels) { foreach ($e in @($oc.Levels.GetEnumerator())) { if ($e.Value) { $all += [string]$e.Value.Drive } } }
    foreach ($en in @($script:LevelBrands)) { if ($en) { $all += [string]$en.Drive } }
    foreach ($rec in @($script:ContentMeasures)) { if ($rec) { $all += [string]$rec.Drive } }
    if ($null -ne $script:TargetDrives) { foreach ($e in @($script:TargetDrives.GetEnumerator())) { $all += [string]$e.Key; $all += [string]$e.Value } }
    if ($null -ne $targets -and $targets -isnot [string] -and $targets -isnot [ValueType] -and $targets -isnot [array]) {
        if ($targets -is [System.Collections.IDictionary]) { foreach ($e in @($targets.GetEnumerator())) { $all += [string]$e.Key; $all += [string]$e.Value } }
        else { foreach ($p in @($targets.PSObject.Properties)) { $all += [string]$p.Name; $all += [string]$p.Value } }
    }
    foreach ($a in $all) {
        $s = ([string]$a).Trim()
        if (-not $s -or $seen.ContainsKey($s)) { continue }
        $seen[$s] = $true
        $s
    }
}

function Repair-DriveRegistry($old = $null, $targets = $null) {
    # 12.11 : une identite sans fiche n est jamais devinee : tout nom admis trouve dans un porteur (Get-DriveIdentities)
    # sans etre ni une connexion ni une fiche recoit une fiche sans connexion, d identifiant « R... » ; elle n est pas
    # proposee dans le bandeau et ses calibrations ne servent a aucun autre lecteur tant que sa connexion n est pas
    # rendue. Un nom que refusent les regles de structure (mot reserve compris) ne recoit pas de fiche : ses donnees
    # restent en memoire, hors de toute vue. Une configuration dont tous les porteurs citent une connexion (12.10) ne
    # donne aucune fiche et aucune ligne. Rend les noms qui ont recu une fiche, un a un
    $names = @(); $refused = @()
    $recs = @(); if ($script:DriveReg) { $recs = @($script:DriveReg.GetEnumerator() | ForEach-Object { $_.Value }) }
    $now = Get-DriveNow
    foreach ($d in @(Get-DriveIdentities $old $targets)) {
        if ((Test-DriveConnCode $d) -or (Test-DriveRegistered $d)) { continue }
        $tn = Test-DriveName $d '' -Load
        if (-not $tn.Ok) { $refused += $d; continue }
        $rec = @{ Name = [string]$tn.Name; Conn = ''; Id = (New-DriveId 'R'); Created = $now; From = ''; At = '' }
        $tbl = $null
        try { $tbl = New-DriveRegTable (@($recs) + @($rec)) } catch { $refused += $d; continue }
        $recs += ,$rec
        $script:DriveReg = $tbl
        $names += [string]$tn.Name
    }
    if ($names.Count -gt 0) { Append-Log ((T "Lecteurs présents dans les calibrations, sans fiche : {0}. Redonnez leur connexion dans « Lecteurs enregistrés » (Accueil) ; d'ici là, ils ne sont pas proposés dans le bandeau et leurs calibrations ne servent à aucun autre lecteur.") -f ($names -join ', ')) }
    if ($refused.Count -gt 0) { Append-Log ((T 'Calibrations rangées sous un nom de lecteur non admis ({0}) : elles ne servent à aucun lecteur.') -f ($refused -join ', ')) }
    foreach ($nm in $names) { $nm }
}

function Restore-DriveRescueTargets($old = $null) {
    # 12.11 : apres Import-TargetDrives, quand le registre vient d etre relu dans la copie de secours : retablit par
    # Set-TargetDrive chaque couple de la copie dont la source n a pas de lecteur cible aujourd hui et dont les deux
    # lecteurs sont connus (Get-DriveIds) ; un couple dont la source a un autre lecteur cible n est pas touche. Puis une
    # ligne de journal qui dit ce qui a ete trouve, fiche par fiche (Get-DriveDataText, « aucune » comprise), sans
    # affirmer ni la cause de l absence du bloc, ni que les calibrations sont intactes. Rend les couples retablis, un a
    # un : @{ Src ; Tgt }
    $pairs = $script:DriveRescuePairs
    if ($null -eq $pairs) { return }
    $script:DriveRescuePairs = $null
    $done = @()
    $ids = Get-DriveIds                    # tableau protege par la virgule : pas de @() autour de l appel
    foreach ($p in @($pairs)) {
        if (-not $p) { continue }
        $s = [string]$p.Src; $t = [string]$p.Tgt
        if (-not $s -or -not $t -or $s -eq $t -or $ids -notcontains $s -or $ids -notcontains $t) { continue }
        if (Get-TargetDrive $s) { continue }
        [void](Set-TargetDrive $s $t)
        $done += ,@{ Src = $s; Tgt = $t }
    }
    $cal = @()
    if ($script:DriveReg) { foreach ($e in @($script:DriveReg.GetEnumerator())) { $cal += ((T '{0} : {1}') -f [string]$e.Value.Name, (Get-DriveDataText (Get-DriveData ([string]$e.Value.Name) $old))) } }
    $tg = if ($done.Count -gt 0) { (@($done | ForEach-Object { "$($_.Src) → $($_.Tgt)" }) -join ', ') } else { (T 'aucun') }
    Append-Log ((T "Lecteurs enregistrés relus dans la copie de secours ({0}) : le fichier de configuration ne les contenait pas (enregistré par une version antérieure, ou copie plus ancienne remise à sa place). Calibrations rangées sous leurs noms : {1}. Lecteurs cibles rétablis depuis cette copie : {2}. Vérifiez le lecteur choisi et son lecteur cible avant d'écrire.") -f "$(Get-DriveRescuePath)", ($cal -join ' ; '), $tg)
    foreach ($d in $done) { $d }
}

function Resolve-DriveOfEra([string]$drive, $eraBlock, [datetime]$when) {
    # 12.11 (pour le retour a une calibration precedente, lot L7) : lecteur d aujourd hui d une courbe lue dans une copie
    # datee de la configuration. $drive : identite lue dans la copie (les deux cotes d une cle croisee se resolvent l un
    # apres l autre) ; $eraBlock : bloc drives de la copie, $null si elle n en a pas ; $when : date de la courbe. Jamais
    # un rang ni un compteur : un identifiant de fiche est date et n est jamais reattribue. Rend @{ Drive (identite
    # d aujourd hui ; '' : aucun lecteur, la courbe ne peut pas etre retablie) ; Era ($drive) ; Sure ; Why } :
    #   id         nom dont la copie a la fiche, et une fiche d aujourd hui porte le meme identifiant (renommee ou non)
    #   ambiguous  meme cas, mais le nom de l epoque est aujourd hui celui d une autre fiche : aucun lecteur
    #   deleted    aucune fiche d aujourd hui pour ce nom ou cet identifiant (lecteur supprime depuis, meme recree sous
    #              le meme nom : sa fiche « L... » est une autre) : aucun lecteur
    #   name       nom sans fiche dans la copie (ou fiche d aujourd hui « R... », refaite d apres les donnees) : la fiche
    #              de ce nom, creee avant la courbe
    #   name-after meme cas, fiche creee apres la courbe : Sure faux
    #   conn-named connexion dont une fiche d aujourd hui a recu les calibrations (From) apres la date de la courbe (la
    #              premiere attribution posterieure, s il y en a plusieurs) : cette fiche, Sure faux
    #   conn       connexion sans attribution posterieure : le lecteur non enregistre de cette connexion
    $res = @{ Drive = ''; Era = $drive; Sure = $false; Why = 'deleted' }
    if (-not $drive) { return $res }
    $recs = @(); if ($script:DriveReg) { $recs = @($script:DriveReg.GetEnumerator() | ForEach-Object { $_.Value }) }
    if (Test-DriveConnCode $drive) {
        $best = $null; $bestAt = [datetime]::MaxValue
        foreach ($r in $recs) {
            if ([string]$r.From -cne $drive) { continue }
            $at = ConvertTo-DriveDate ([string]$r.At)
            if ($at -ne [datetime]::MinValue -and $at -gt $when -and $at -lt $bestAt) { $best = $r; $bestAt = $at }
        }
        if ($best) { $res.Drive = [string]$best.Name; $res.Why = 'conn-named'; return $res }
        $res.Drive = $drive; $res.Sure = $true; $res.Why = 'conn'
        return $res
    }
    $eraId = ''
    foreach ($it in @(Get-DriveBlockItems $eraBlock)) { if ([string]$it.Name -eq $drive) { $eraId = [string]$it.Id; break } }
    $today = Get-DriveRecord $drive
    if ($eraId -cmatch '^[LR]\d{14}-\d{2}$') {
        $byId = $null
        foreach ($r in $recs) { if ([string]$r.Id -ceq $eraId) { $byId = $r; break } }
        if ($byId) {
            if ($today -and [string]$today.Id -cne $eraId) { $res.Why = 'ambiguous'; return $res }
            $res.Drive = [string]$byId.Name; $res.Sure = $true; $res.Why = 'id'
            return $res
        }
        if (-not $today -or [string]$today.Id -cnotlike 'R*') { return $res }
    }
    if (-not $today) { return $res }
    $res.Drive = [string]$today.Name
    $cr = ConvertTo-DriveDate ([string]$today.Created)
    if ($cr -ne [datetime]::MinValue -and $cr -le $when) { $res.Sure = $true; $res.Why = 'name' } else { $res.Why = 'name-after' }
    return $res
}
