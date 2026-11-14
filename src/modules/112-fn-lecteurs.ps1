# ============================== FONCTIONS : LECTEURS ENREGISTRES ===============
# 12.11 (lot LN-a, socle sans interface) : un lecteur de disquette peut recevoir un nom. Le nom est alors son identite : le
# texte de la liste du bandeau, la cle de rangement de ses courbes (« nom|cle », « source>cible|cle ») et le champ Drive de
# ses donnees. La connexion (A, B, 0 a 3 : la valeur de --drive) devient un attribut de sa fiche, donne par la seule
# fonction Get-DriveConn. Un lecteur non enregistre garde pour identite le code de sa connexion : tant qu aucun lecteur
# n a ete enregistre, cles, blocs de la configuration et arguments de gw sont ceux de la 12.10 (une fois une copie de
# secours lue ou ecrite, le bloc drives reste ecrit, liste vide comprise : Export-DriveRegistry).
# Etat (040) : $script:DriveReg, registre, table ordonnee nom -> fiche @{ Name ; Conn ; Id ; Created ; From ; At } ;
# $script:DriveLast, connexion -> dernier lecteur enregistre choisi. Le registre n est jamais lu par un index ni par une
# propriete (Get-DriveRecord enumere ses entrees) : un nom fait de chiffres ne peut pas etre pris pour un rang, et aucun
# nom ne peut masquer une propriete de la table. Les mots reserves ($script:DriveReserved, refuses par Test-DriveName)
# protegent en plus la garde « registre non vide » ($script:DriveReg.Count -gt 0) des lignes ajoutees aux fonctions
# existantes.
# Des donnees ne changent d identite que par Edit-DriveData, appelee par les quatre actions du registre (Add-NamedDrive,
# Rename-NamedDrive, Move-NamedDrive, Remove-NamedDrive), qui ne touchent ni liste ni fenetre et rendent une table
# @{ Ok ; Why ; ... } (Why : le texte du refus). L interface (bandeau, confirmation du lecteur branche, fenetre
# « Lecteurs enregistres ») est en fin de module (lot LN-b).

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
    # 12.11 (relecture de LN-a) : le refus part des que $to porte une donnee (Get-DriveData : Any), courbe ou non : le texte
    # nomme toutes les sortes de donnees, et non les seules calibrations (un lecteur cible choisi suffit)
    $refuse = if ($toConn) { ((T 'La connexion {0} a déjà des données sans nom de lecteur (courbes, lecteur cible, niveaux, mémoire par marque ou facteurs) : le nom ne peut pas être retiré seul.') -f $to) } else { ((T 'Le lecteur {0} a déjà des données (courbes, lecteur cible, niveaux, mémoire par marque ou facteurs) : celles de la connexion {1} ne peuvent pas lui être attribuées.') -f $to, $from) }
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
    if ($from) { $rec = Get-DriveRecord ([string](Test-DriveName $name).Name) }   # 12.11 : nom normalise (espaces repetes ramenes a un seul), comme Test-DriveName
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
        # 12.11 (relecture de LN-a) : espaces des bords retires ici seulement, comme Import-TargetDrives les retire
        if ($targets -is [System.Collections.IDictionary]) { foreach ($e in @($targets.GetEnumerator())) { $all += ([string]$e.Key).Trim(); $all += ([string]$e.Value).Trim() } }
        else { foreach ($p in @($targets.PSObject.Properties)) { $all += ([string]$p.Name).Trim(); $all += ([string]$p.Value).Trim() } }
    }
    foreach ($a in $all) {
        $s = [string]$a   # 12.11 : identite telle que la donnee la porte (Get-DriveData compare sans retirer d espace)
        if (-not $s.Trim() -or $seen.ContainsKey($s)) { continue }
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
    # un : @{ Src ; Tgt }. Le couple d une fiche relue sans aucune courbe est retabli aussi : ce lecteur cible est alors sa
    # seule donnee, et nommer de ce nom le lecteur d une connexion pour lui rendre ses courbes est refuse (Edit-DriveData,
    # texte qui cite le lecteur cible) tant que ce choix reste
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

# ============================== LN-b : INTERFACE DES LECTEURS ENREGISTRES =======
# 12.11 (lot LN-b) : liste « Lecteur : » du bandeau (les six connexions, puis les lecteurs enregistres qui ont une
# connexion) et ses deux dispositions, liaison au reglage drive (Sync-DriveCombo, 120), lecteur a confirmer, confirmation
# du lecteur branche dans les cinq fonctions qui engagent une operation sous l identite du lecteur (Start-ImageWrite,
# Start-LevelCalib, Start-PrecompCalib, Start-ContentMeasure, Start-Restore) et du lecteur cible d une calibration
# croisee (Start-CrossCalib), verrou de la liste pendant une operation, fenetre « Lecteurs enregistres » (frmDrives), qui
# affiche et transmet les gestes : Get-DriveEditPlan et Get-DriveDeletePlan decident et donnent les textes. Sans lecteur
# enregistre, le code de la 12.10 n appelle que Update-DriveChoice (gestionnaire du bandeau : lecteur courant retenu),
# Set-DriveHandChoice (choix a la main) et Update-DriveLock (verrou, voulu pour tous) : bandeau, textes, journal,
# configuration et arguments de gw restent ceux de la 12.10.

function Get-WriteSourceText {
    # 12.11 (lot LN-b) : seule source du texte « Lecteur qui ecrit : TEAC FD-235HF (A) » (lecteur non enregistre :
    # « Lecteur qui ecrit : A ») : journal de chaque ecriture (Confirm-DriveIdentity -Write) ; libelle de l onglet Ecriture
    # et tete de la ligne « Ce qui va se passer » (lots L9 et L10)
    return ((T 'Lecteur qui écrit : {0}') -f (Get-DriveLabel ([string]$cmbDrive.Text)))
}

function Format-ConnDrives($drives) {
    # 12.11 (lot LN-b) : lecteurs d une connexion en texte (Get-ConnDrives, cibles ecartees d une calibration croisee) :
    # le nom d un lecteur enregistre, « A (non enregistre) » pour un lecteur non enregistre
    $l = @()
    foreach ($d in @($drives)) { if ($d) { $l += $(if (Test-DriveConnCode ([string]$d)) { (T '{0} (non enregistré)') -f [string]$d } else { [string]$d }) } }
    return ($l -join ', ')
}

function Get-DriveListItems {
    # 12.11 (lot LN-b) : elements voulus de la liste du bandeau : les six connexions, puis les lecteurs enregistres qui ont
    # une connexion, dans l ordre du registre (une fiche sans connexion n y est pas : ses courbes ne servent a aucun
    # lecteur tant que sa connexion n est pas rendue). Tableau protege par la virgule (pas de @() autour de l appel)
    $l = @([string[]]$script:SettingDefs['drive'].Codes)
    if ($script:DriveReg) { foreach ($e in @($script:DriveReg.GetEnumerator())) { if ([string]$e.Value.Conn) { $l += [string]$e.Value.Name } } }
    return ,@($l)
}

function Get-DrivesCardText {
    # 12.11 (lot LN-b) : description de la carte « Lecteurs enregistres » de l Accueil (540) : fiches sans connexion
    # comptees (leurs courbes ne servent a aucun lecteur), sinon le texte d origine
    $n = 0
    if ($script:DriveReg) { $n = @($script:DriveReg.GetEnumerator() | Where-Object { -not [string]$_.Value.Conn }).Count }
    if ($n -gt 0) { return ((T '{0} lecteur(s) sans connexion : redonnez-la ici pour retrouver leurs calibrations.') -f "$n") }
    return (T 'Nommer vos lecteurs : plusieurs sur une même connexion, chacun avec ses calibrations.')
}

function Update-DrivesCard {
    # 12.11 (lot LN-b) : texte de la carte « Lecteurs enregistres » (Get-DrivesCardText)
    if (-not $cardDrives) { return }
    $t = Get-DrivesCardText
    if ([string]$cardDrives.Controls[3].Text -cne $t) { $cardDrives.Controls[3].Text = $t }
}

function Update-DriveList([string]$Select = '') {
    # 12.11 (lot LN-b) : elements de la liste du bandeau (Get-DriveListItems) et lecteur choisi : $Select (un element de
    # la liste) s il est donne, sinon le choix garde s il existe encore, sinon le lecteur retenu pour la connexion du
    # reglage (Get-DriveForConn). Ordre impose : element choisi ajoute s il manque, puis choisi (le gestionnaire du
    # bandeau, 520, s execute avec le lecteur final), puis seulement les autres elements retires et remis dans l ordre du
    # registre : le choix n est jamais retire, le texte de la liste n est jamais vide (le gestionnaire n a aucune garde sur
    # un texte vide). Une liste sans poignee (fenetre pas encore affichee, tests) ne deplace pas son choix quand un element
    # est insere avant lui : le choix est repris a la fin, sans changement de texte. Liaisons des reglages gardees pendant
    # la mise a jour, puis reglage drive ramene a la connexion du lecteur choisi ; disposition du bandeau et carte de
    # l Accueil
    $want = Get-DriveListItems
    $nc = @($script:SettingDefs['drive'].Codes).Count
    $cur = [string]$cmbDrive.Text
    $sel = ''
    if ($Select -and $want -ccontains $Select) { $sel = $Select }
    elseif ($cur -and $want -ccontains $cur) { $sel = $cur }
    else { $sel = Get-DriveForConn ([string](Get-Setting 'drive')); if ($want -cnotcontains $sel) { $sel = [string]$want[0] } }
    $have = @($cmbDrive.Items | ForEach-Object { [string]$_ })
    $sv = $script:SettingSync; $script:SettingSync = $true
    try {
        if (($have -join "`n") -cne ($want -join "`n")) {
            if ($have -cnotcontains $sel) { [void]$cmbDrive.Items.Add($sel) }
            if ([string]$cmbDrive.SelectedItem -cne $sel) { $cmbDrive.SelectedItem = $sel }
            for ($i = $cmbDrive.Items.Count - 1; $i -ge $nc; $i--) { if ([string]$cmbDrive.Items[$i] -cne $sel) { $cmbDrive.Items.RemoveAt($i) } }
            $at = $nc; $after = ([array]::IndexOf($want, $sel) -lt $nc)
            for ($i = $nc; $i -lt $want.Count; $i++) {
                $w = [string]$want[$i]
                if ($w -ceq $sel) { $after = $true; continue }
                if ($after) { [void]$cmbDrive.Items.Add($w) } else { $cmbDrive.Items.Insert($at, $w); $at++ }
            }
            if ([string]$cmbDrive.SelectedItem -cne $sel) { $cmbDrive.SelectedIndex = $cmbDrive.Items.IndexOf($sel) }
        } elseif ([string]$cmbDrive.SelectedItem -cne $sel) { $cmbDrive.SelectedItem = $sel }
    } finally { $script:SettingSync = $sv }
    $c = Get-DriveConn ([string]$cmbDrive.Text)
    if ($c -and [string](Get-Setting 'drive') -cne $c) { Set-Setting 'drive' $c $cmbDrive }
    Set-DriveBannerLayout
    Update-DrivesCard
}

function Set-DriveBannerLayout {
    # 12.11 (lot LN-b) : disposition du bandeau. Liste de six elements (aucun lecteur enregistre ayant une connexion) :
    # positions de la 12.10, au pixel pres, libelle « Lecteur : ». Sinon disposition elargie (maquette approuvee le
    # 13/11/2026) : liste de $script:DriveListWidth px (un nom admis s y affiche en entier : Test-DriveName), libelle
    # « Lecteur (A) : » pour un lecteur enregistre, « Lecteur : » pour un lecteur non enregistre, contre la liste ;
    # « COM : » et son champ decales vers le bord droit, « Chrono » remonte sur la rangee de l etat de gw ; « Aide » et
    # « Mode expert » 12 px a gauche du libelle le plus large (« Lecteur (X) : »), place fixe quel que soit le lecteur
    # choisi. Positions de la 12.10 relevees au premier appel (distance au bord droit du bandeau : controles ancres en
    # haut a droite), reprises pour revenir a la disposition de la 12.10 ; les positions elargies en derivent (ecarts de
    # la 12.10 gardes). Infobulle de la liste : celle de la 12.10, suivie des lecteurs enregistres et de leur connexion
    if (-not $cmbDrive -or -not $lblDrive -or -not $pnlTop) { return }
    $W = [int]$pnlTop.Width
    if (-not $script:DriveBanner) {
        $p0 = [ordered]@{}
        $all = [ordered]@{ lblGwStatus = $lblGwStatus; chkTime = $chkTime; txtDev = $txtDev; lblCom = $lblCom; cmbDrive = $cmbDrive; lblDrive = $lblDrive; btnHelpTop = $btnHelpTop; chkExpert = $chkExpert }
        foreach ($n in @($all.Keys)) {
            $c = $all[$n]
            if ($c) { $p0[$n] = @{ C = $c; R = ($W - [int]$c.Left); Top = [int]$c.Top; W = [int]$c.Width } }
        }
        $script:DriveBanner = @{ P = $p0; Tip = $(if ($tip) { [string]$tip.GetToolTip($cmbDrive) } else { '' }) }
    }
    $p = $script:DriveBanner.P
    $wide = ($cmbDrive.Items.Count -gt @($script:SettingDefs['drive'].Codes).Count)
    $d = [string]$cmbDrive.Text
    $lt = if ($wide -and (Test-DriveRegistered $d)) { (T 'Lecteur ({0}) :') -f (Get-DriveConn $d) } else { (T 'Lecteur :') }
    if ([string]$lblDrive.Text -cne $lt) { $lblDrive.Text = $lt }
    if (-not $wide) {
        foreach ($k in @($p.Keys)) {
            $x = $p[$k]
            $x.C.Location = New-Object System.Drawing.Point(($W - [int]$x.R), [int]$x.Top)
            if ($k -eq 'cmbDrive') { $x.C.Width = [int]$x.W }
        }
    } elseif ($p.Contains('chkTime') -and $p.Contains('txtDev') -and $p.Contains('lblCom') -and $p.Contains('cmbDrive')) {
        # Champ COM contre le bord droit de « Chrono » ; « COM : » et la liste a leurs ecarts de la 12.10
        $xR = $W - [int]$p['chkTime'].R + [int]$p['chkTime'].W
        $xDev = $xR - $txtDev.Width
        $xCom = $xDev - ([int]$p['lblCom'].R - [int]$p['txtDev'].R)
        $xCmb = $xCom - ([int]$p['cmbDrive'].R - [int]$p['lblCom'].R - [int]$p['cmbDrive'].W) - [int]$script:DriveListWidth
        $chkTime.Location = New-Object System.Drawing.Point(($W - [int]$p['chkTime'].R), 8)
        $txtDev.Location = New-Object System.Drawing.Point($xDev, [int]$p['txtDev'].Top)
        $lblCom.Location = New-Object System.Drawing.Point($xCom, [int]$p['lblCom'].Top)
        $cmbDrive.Width = [int]$script:DriveListWidth
        $cmbDrive.Location = New-Object System.Drawing.Point($xCmb, [int]$p['cmbDrive'].Top)
        $lblDrive.Location = New-Object System.Drawing.Point(($xCmb - $lblDrive.PreferredWidth), [int]$p['lblDrive'].Top)
        $wMax = 0
        foreach ($k in @($script:SettingDefs['drive'].Codes)) { $wk = [System.Windows.Forms.TextRenderer]::MeasureText(((T 'Lecteur ({0}) :') -f [string]$k), $lblDrive.Font).Width; if ($wk -gt $wMax) { $wMax = $wk } }
        if ($btnHelpTop) {
            $xh = $xCmb - $wMax - 12 - $btnHelpTop.Width
            $btnHelpTop.Location = New-Object System.Drawing.Point($xh, [int]$p['btnHelpTop'].Top)
            if ($chkExpert) { $chkExpert.Location = New-Object System.Drawing.Point($xh, [int]$p['chkExpert'].Top) }
        }
    }
    if ($tip) {
        $t = [string]$script:DriveBanner.Tip
        if ($script:DriveReg.Count -gt 0) {
            $names = @($script:DriveReg.GetEnumerator() | ForEach-Object { Get-DriveLabel ([string]$_.Value.Name) })
            $t += "`n`n" + ((T "Lecteurs enregistrés : {0}.`nLeurs calibrations sont rangées sous leur nom, quelle que soit leur connexion. L'application ne reconnaît pas le lecteur branché : choisissez-le ici chaque fois que vous en changez (pour les nommer : Accueil, « Lecteurs enregistrés »).") -f ($names -join ', '))
        }
        if ([string]$tip.GetToolTip($cmbDrive) -cne $t) { $tip.SetToolTip($cmbDrive, $t) }
    }
}

function Sync-DriveCombo {
    # 12.11 (lot LN-b) : reglage drive (une connexion) vers la liste du bandeau quand des lecteurs sont enregistres
    # (Set-SettingCtlValue, 120 : fenetre de nettoyage, Set-Defaults, chargement de la configuration) : rien si le lecteur
    # choisi est deja sur cette connexion, sinon le lecteur retenu pour elle (Get-DriveForConn)
    $c = [string](Get-Setting 'drive')
    if ((Get-DriveConn ([string]$cmbDrive.Text)) -ceq $c) { return }
    Set-Combo $cmbDrive (Get-DriveForConn $c)
}

function Clear-DriveActivity([string]$conn) {
    # 12.11 (lot LN-b) : activite du prechauffage oubliee pour une connexion ($script:DriveActivity, cles
    # « peripherique|connexion », Get-GwDriveKey) : un autre lecteur vient d y etre branche, il est froid
    if (-not $conn -or -not $script:DriveActivity) { return }
    foreach ($k in @($script:DriveActivity.Keys | Where-Object { ([string]$_).EndsWith('|' + $conn) })) { $script:DriveActivity.Remove($k) }
}

function Update-DriveChoice {
    # 12.11 (lot LN-b) : gestionnaire du bandeau (520), apres Sync-PrecompCurves : le texte de la liste vient de changer.
    # Lecteur a confirmer : $script:DriveChecked est vide des qu il differe du lecteur choisi, quel que soit l ordre des
    # evenements de la liste (seuls Set-DriveHandChoice, pour un choix fait dans la liste deroulee, et la case de la
    # confirmation le posent). Avec des lecteurs enregistres : dernier lecteur choisi sur la connexion
    # ($script:DriveLast), activite du prechauffage de la connexion oubliee quand un autre lecteur y est choisi, libelle
    # et disposition du bandeau, libelle du lecteur de la restauration, ligne « Lecteur choisi » quand l un des deux
    # lecteurs est enregistre. Texte vide (liste en reconstruction) ou inchange : rien
    $new = [string]$cmbDrive.Text; $old = [string]$script:DriveCur
    if (-not $new -or $new -ceq $old) { return }
    $script:DriveCur = $new
    if ([string]$script:DriveChecked -cne $new) { $script:DriveChecked = '' }
    if ($script:DriveReg.Count -eq 0) { return }
    $c = Get-DriveConn $new
    if ($c) {
        $nl = @{}
        if ($script:DriveLast) { foreach ($e in @($script:DriveLast.GetEnumerator())) { if ([string]$e.Key -cne $c) { $nl[[string]$e.Key] = [string]$e.Value } } }
        $r = Get-DriveRecord $new
        if ($r) { $nl[$c] = [string]$r.Name }
        $script:DriveLast = $nl
        if ($old -and (Get-DriveConn $old) -ceq $c) { Clear-DriveActivity $c }
    }
    Set-DriveBannerLayout
    Update-RsDrive
    if ($old -and ((Test-DriveRegistered $new) -or (Test-DriveRegistered $old))) { Append-Log ((T 'Lecteur choisi : {0} (avant : {1}).') -f (Get-DriveLabel $new), (Get-DriveLabel $old)) }
}

function Set-DriveHandChoice([bool]$listOpen) {
    # 12.11 (lot LN-b) : SelectionChangeCommitted de la liste du bandeau (510) : seul un choix fait dans la liste deroulee
    # ($listOpen : DroppedDown) vaut confirmation du lecteur branche. Molette (sans effet, 510), fleches ou lettre sur la
    # liste fermee : rien n est pose, la confirmation reste due. Evenement leve avant le changement du texte : le lecteur
    # pose est l ancien, et Update-DriveChoice le vide ensuite. Une hypothese fausse sur ces evenements fait demander la
    # confirmation plus souvent, jamais moins
    if ($listOpen) { $script:DriveChecked = [string]$cmbDrive.SelectedItem }
}

function Test-DriveCheckDue {
    # 12.11 (lot LN-b) : vrai quand le lecteur du bandeau doit etre confirme avant une ecriture, une calibration, une
    # mesure ou une restauration : des lecteurs sont enregistres, le lecteur choisi n a ete ni choisi a la main dans la
    # liste deroulee ni confirme depuis son dernier changement, et sa connexion porte au moins deux lecteurs
    # (Get-ConnDrives), ou le registre vient d etre relu dans sa copie de secours et la connexion porte un lecteur
    # enregistre
    if ($script:DriveReg.Count -eq 0) { return $false }
    $d = [string]$cmbDrive.Text
    if ([string]$script:DriveChecked -and [string]$script:DriveChecked -ceq $d) { return $false }
    $all = @(Get-ConnDrives (Get-DriveConn $d))
    if ($script:DriveRescued -and @($all | Where-Object { Test-DriveRegistered $_ }).Count -ge 1) { return $true }
    return ($all.Count -ge 2)
}

function Confirm-DriveIdentity([switch]$Write, [string]$Target = '') {
    # 12.11 (lot LN-b) : confirmation du lecteur branche, appelee seulement avec des lecteurs enregistres par les cinq
    # fonctions qui engagent une operation sous l identite du lecteur du bandeau (Start-ImageWrite avec -Write,
    # Start-LevelCalib, Start-PrecompCalib, Start-ContentMeasure, Start-Restore) ; due ou non : Test-DriveCheckDue.
    # Fenetre frmConfirm (Show-AppConfirm, niveau warn) : lecteurs de la connexion, lecteur choisi et ses calibrations ;
    # case obligatoire qui nomme le lecteur, ou dit qu il n est aucun des lecteurs enregistres (lecteur non enregistre).
    # Acceptee : lecteur confirme ($script:DriveChecked), les etapes suivantes de la meme operation ne redemandent pas ;
    # refusee (Fermer, Echap, croix) : faux, une ligne de journal, l operation ne part pas (refus note dans la surcharge
    # d une ecriture de la Bibliotheque, comme Test-TargetWriteAllowed). -Write : ligne « Lecteur qui ecrit » au journal
    # (Get-WriteSourceText). -Target (Start-CrossCalib) : lecteur cible d une calibration croisee, confirme a chaque fois
    # que sa connexion porte au moins deux lecteurs : la courbe est rangee « source>cible » et la case de l avertissement
    # de la calibration ne nomme que le lecteur qui ecrit
    $refuse = (T 'Opération annulée : lecteur branché non confirmé.')
    if ($Target) {
        $tc = Get-DriveConn $Target
        $all = @(Get-ConnDrives $tc)
        if ($all.Count -lt 2) { return $true }
        $txt = ((T "La connexion {0} porte plusieurs lecteurs : {1}. L'application ne reconnaît pas celui qui est branché.") -f $tc, (Format-ConnDrives $all)) + "`n`n" + ((T "Lecteur cible de cette calibration croisée : {0}`nLa courbe mesurée servira aux écritures du lecteur {1} destinées à ce lecteur. Si un autre lecteur est branché sur la connexion {2}, fermez cette fenêtre et relancez la calibration croisée avec le bon lecteur cible : mesurée avec un autre lecteur, la courbe serait fausse, sans aucun message d'erreur.") -f (Get-DriveLabel $Target), (Get-DriveLabel ([string]$cmbDrive.Text)), $tc)
        $rt = Get-DriveRecord $Target
        $chk = if ($rt) { (T 'Le lecteur branché sur la connexion {0} est bien « {1} »') -f $tc, [string]$rt.Name } else { (T "Le lecteur branché sur la connexion {0} n'est aucun des lecteurs enregistrés") -f $tc }
        if (Show-AppConfirm -Title (T 'Lecteur branché') -Heading ((T 'Quel lecteur est branché sur la connexion {0} ?') -f $tc) -Text $txt -Check $chk -Level 'warn') { return $true }
        Append-Log $refuse
        if ($script:OpOverride) { $script:OpOverride.Refused = $true }
        return $false
    }
    if (Test-DriveCheckDue) {
        $d = [string]$cmbDrive.Text; $c = Get-DriveConn $d
        $intro = if ($script:DriveRescued) { (T "Vos lecteurs enregistrés viennent d'être relus dans leur copie de secours : le fichier de configuration ne les contenait pas. L'application ne reconnaît pas le lecteur branché sur la connexion {0}.") -f $c }
                 else { (T "La connexion {0} porte plusieurs lecteurs : {1}. L'application ne reconnaît pas celui qui est branché.") -f $c, (Format-ConnDrives @(Get-ConnDrives $c)) }
        $txt = $intro + "`n`n" + ((T "Lecteur choisi dans le bandeau : {0}`nSes calibrations : {1}`n`nL'écriture et la calibration emploient ses courbes et rangent leurs résultats sous son nom. Si un autre lecteur est branché, fermez cette fenêtre et choisissez-le dans la liste « Lecteur : » du bandeau : avec la courbe d'un autre lecteur, la disquette serait mal précompensée, sans aucun message d'erreur.") -f (Get-DriveLabel $d), (Get-DriveDataText (Get-DriveData $d)))
        $rd = Get-DriveRecord $d
        $chk = if ($rd) { (T 'Le lecteur branché sur la connexion {0} est bien « {1} »') -f $c, [string]$rd.Name } else { (T "Le lecteur branché sur la connexion {0} n'est aucun des lecteurs enregistrés") -f $c }
        if (-not (Show-AppConfirm -Title (T 'Lecteur branché') -Heading ((T 'Quel lecteur est branché sur la connexion {0} ?') -f $c) -Text $txt -Check $chk -Level 'warn')) {
            Append-Log $refuse
            if ($script:OpOverride) { $script:OpOverride.Refused = $true }
            return $false
        }
        $script:DriveChecked = $d
    }
    if ($Write) { Append-Log (Get-WriteSourceText) }
    return $true
}

function Update-DriveLock {
    # 12.11 (lot LN-b) : minuteur principal (600) : liste « Lecteur : » du bandeau inactive pendant toute operation
    # (Get-AppBusy), sauf la pause d une mesure continue de l onglet Qualite, avec ou sans lecteur enregistre : une
    # operation commencee avec un lecteur se termine avec lui (une calibration relit la connexion du bandeau a chaque
    # passe, sa cle de rangement est figee au lancement). Un changement fait par le code reste possible
    $b = Get-AppBusy
    $lock = ([bool]$b -and $b -ne 'quality')
    if ($cmbDrive.Enabled -eq $lock) { $cmbDrive.Enabled = -not $lock }
}

function Get-DriveRows {
    # 12.11 (lot LN-b) : lignes de la fenetre « Lecteurs enregistres » : chaque fiche, dans l ordre du registre, puis
    # chaque lecteur non enregistre qui a des donnees (« A (non enregistre) »). Une ligne : @{ Kind ('rec' ou 'conn') ;
    # Drive (identite) ; Conn ; Text, ConnText, Cal (textes des trois colonnes) ; Data (Get-DriveData) }. Tableau protege
    # par la virgule
    $rows = @()
    if ($script:DriveReg) {
        foreach ($e in @($script:DriveReg.GetEnumerator())) {
            $r = $e.Value; $nm = [string]$r.Name; $dt = Get-DriveData $nm
            $rows += ,@{ Kind = 'rec'; Drive = $nm; Conn = [string]$r.Conn; Text = $nm; ConnText = $(if ([string]$r.Conn) { [string]$r.Conn } else { (T 'à préciser') }); Cal = (Get-DriveDataText $dt); Data = $dt }
        }
    }
    foreach ($c in @($script:SettingDefs['drive'].Codes)) {
        $dt = Get-DriveData ([string]$c)
        if ($dt['Any']) { $rows += ,@{ Kind = 'conn'; Drive = [string]$c; Conn = [string]$c; Text = ((T '{0} (non enregistré)') -f [string]$c); ConnText = [string]$c; Cal = (Get-DriveDataText $dt); Data = $dt } }
    }
    return ,@($rows)
}

function Get-DriveEditPlan($row, [string]$name, [string]$conn) {
    # 12.11 (lot LN-b) : seule decision du bouton « Enregistrer » de la fenetre « Lecteurs enregistres », et ses textes,
    # sans rien changer : @{ Kind ; Error ; Note ; Ask ; Text ; Log ; Name ; Conn ; From ; Old ; N ; AskHeading ;
    # AskText ; AskCheck ; AskGo }. $row : ligne choisie (Get-DriveRows), $null pour « Nouveau lecteur ». Kind : new
    # (fiche sans courbe ; Note : la connexion a des calibrations sans nom), adopt (le lecteur non enregistre de la ligne
    # recoit le nom, ou une fiche existante sans aucune donnee), rename (nom change, ne serait-ce que de casse : -cne),
    # move (connexion changee, ou rendue a une fiche sans connexion), rename+move, none (rien a enregistrer). Ask : check
    # (confirmation a case : le lecteur non enregistre a des courbes), yesno (question : des donnees sans courbe) ou vide.
    # Error : refus, texte affiche dans la fenetre. Text : resultat affiche ; Log : lignes du journal (renommer et deplacer
    # a la fois : les deux, le resultat affiche est celui du changement de connexion). N : courbes deplacees
    $p = @{ Kind = ''; Error = ''; Note = ''; Ask = ''; Text = ''; Log = @(); Name = ''; Conn = $conn; From = ''; Old = ''; N = 0; AskHeading = ''; AskText = ''; AskCheck = ''; AskGo = '' }
    $why = Get-DriveEditRefusal
    if ($why) { $p.Error = $why; return $p }
    $nm = [string](Test-DriveName $name).Name
    if (-not $row) {
        $p.Kind = 'new'
        if (-not (Test-DriveConnCode $conn)) { $p.Error = (T 'Choisissez la connexion du lecteur.'); return $p }
        $dc = Get-DriveData $conn
        if ((@($dc['Keys']).Count + @($dc['Cross']).Count) -gt 0) { $p.Note = (T 'La connexion {0} a déjà des calibrations sans nom de lecteur. Pour les garder avec ce lecteur, sélectionnez la ligne « {0} (non enregistré) » et donnez-lui ce nom ; sinon ce lecteur sera calibré à part.') -f $conn }
        $tn = Test-DriveName $name
        if (-not $tn.Ok) { $p.Error = [string]$tn.Why; return $p }
        $p.Name = [string]$tn.Name
        $p.Text = (T 'Lecteur « {0} » enregistré sur la connexion {1}, sans calibration. Choisissez-le dans la liste « Lecteur : » du bandeau quand il est branché.') -f $p.Name, $conn
        $p.Log = @($p.Text)
        return $p
    }
    if ([string]$row.Kind -eq 'conn') {
        $p.Kind = 'adopt'; $p.From = [string]$row.Drive
        if (-not (Test-DriveConnCode $conn)) { $p.Error = (T 'Choisissez la connexion du lecteur.'); return $p }
        $rec = Get-DriveRecord $nm
        if ($rec) { $p.Name = [string]$rec.Name }
        else {
            $tn = Test-DriveName $name
            if (-not $tn.Ok) { $p.Error = [string]$tn.Why; return $p }
            $p.Name = [string]$tn.Name
        }
        $chk = Edit-DriveData $p.From $p.Name -Check
        if (-not $chk.Ok) { $p.Error = [string]$chk.Why; return $p }
        $dt = Get-DriveData $p.From
        $p.N = @($dt['Keys']).Count + @($dt['Cross']).Count
        if ($p.N -gt 0) {
            $p.Ask = 'check'
            $p.AskHeading = (T 'Attribuer à ce lecteur les calibrations de la connexion {0} ?') -f $p.From
            $p.AskText = (T "La connexion {0} a des calibrations faites sans nom de lecteur : {1}.`n`nEn nommant ce lecteur « {2} », vous déclarez qu'elles ont été faites avec lui : elles deviennent les siennes, avec ses niveaux, sa mémoire par marque, ses facteurs mesurés et son lecteur cible. Rien n'est recalculé ni effacé ; la configuration est d'abord copiée dans un fichier « {3}.lecteurs-….bak ». La connexion {0} garde un lecteur non enregistré, sans calibration.`n`nSi elles viennent d'un autre lecteur, fermez cette fenêtre et choisissez « Nouveau lecteur » : il partira sans calibration.") -f $p.From, (Get-DriveDataText $dt), $p.Name, [System.IO.Path]::GetFileName([string]$script:ConfigFile)
            $p.AskCheck = (T 'Les calibrations de la connexion {0} ont été faites avec le lecteur « {1} »') -f $p.From, $p.Name
            $p.AskGo = (T 'Attribuer ces calibrations')
        } elseif ($dt['Any']) {
            $p.Ask = 'yesno'
            $p.AskText = (T 'Le lecteur non enregistré de la connexion {0} n''a aucune calibration. Son lecteur cible, ses niveaux, sa mémoire par marque et ses facteurs mesurés passent sous le nom « {1} ». Continuer ?') -f $p.From, $p.Name
        }
        $p.Text = (T 'Lecteur « {0} » enregistré sur la connexion {1} : les calibrations faites sans nom sur la connexion {2} ({3} courbe(s)) sont maintenant les siennes.') -f $p.Name, $conn, $p.From, "$($p.N)"
        $p.Log = @($p.Text)
        return $p
    }
    $rec = Get-DriveRecord ([string]$row.Drive)
    if (-not $rec) { $p.Kind = 'none'; $p.Error = (T 'Rien à enregistrer : le nom et la connexion n''ont pas changé.'); return $p }
    $old = [string]$rec.Name; $oc = [string]$rec.Conn
    $p.Old = $old
    if (-not (Test-DriveConnCode $conn)) { $p.Error = (T 'Choisissez la connexion du lecteur.'); return $p }
    $ren = ($nm -cne $old); $mov = ($conn -cne $oc)
    if (-not $ren -and -not $mov) { $p.Kind = 'none'; $p.Error = (T 'Rien à enregistrer : le nom et la connexion n''ont pas changé.'); return $p }
    $p.Name = $old
    if ($ren) {
        $tn = Test-DriveName $name $old
        if (-not $tn.Ok) { $p.Error = [string]$tn.Why; return $p }
        $p.Name = [string]$tn.Name
        $chk = Edit-DriveData $old $p.Name -Check
        if (-not $chk.Ok) { $p.Error = [string]$chk.Why; return $p }
    }
    $dt = Get-DriveData $old
    $p.N = @($dt['Keys']).Count + @($dt['Cross']).Count
    $p.Kind = if ($ren -and $mov) { 'rename+move' } elseif ($ren) { 'rename' } else { 'move' }
    $l = @()
    if ($ren) { $l += (T "Lecteur « {0} » : il s'appelait « {1} ». Ses calibrations ({2} courbe(s)), ses niveaux, sa mémoire par marque, ses facteurs et ses lecteurs cibles portent son nouveau nom.") -f $p.Name, $old, "$($p.N)" }
    if ($mov) { $l += (T 'Lecteur « {0} » : connexion {1} (avant : {2}). Ses calibrations le suivent. Après un changement de nappe, contrôlez une écriture (onglet Qualité) ou refaites une calibration rapide.') -f $p.Name, $conn, $(if ($oc) { $oc } else { (T 'à préciser') }) }
    $p.Log = $l; $p.Text = [string]$l[-1]
    return $p
}

function Update-DriveUiAfterEdit([string]$Select = '') {
    # 12.11 (lot LN-b) : interface apres une action de la fenetre « Lecteurs enregistres » : fenetre Courbe fermee (elle
    # garderait l ancien nom : seul le gestionnaire du bandeau la ferme), liste et disposition du bandeau
    # (Update-DriveList), liste « Lecteur cible » et case de la mesure, libelle du lecteur de la restauration, profil de
    # l image une fois la fenetre affichee
    if ($script:CurveForm -and -not $script:CurveForm.IsDisposed) { $script:CurveForm.Close() }
    Update-DriveList $Select
    Update-TargetDriveUi; Update-SlowUi
    Update-RsDrive
    if ($form -and $form.Visible) { Update-PrecompForImage $txtWFile.Text }
}

function Invoke-DriveEditPlan($plan) {
    # 12.11 (lot LN-b) : execute la decision de Get-DriveEditPlan : confirmation s il y a lieu (case T37 a T40, ou question
    # T70), action du registre (Add-NamedDrive, Rename-NamedDrive, Move-NamedDrive : elles font la copie datee), interface
    # (Update-DriveUiAfterEdit), journal, enregistrement. Lecteur du bandeau nomme, renomme ou deplace : c est le meme
    # lecteur physique, sans ligne « Lecteur choisi » ; il devient le dernier lecteur de sa connexion, le reglage drive suit
    # sa connexion (Update-DriveList) ; connexion changee : confirmation de nouveau due, activite du prechauffage de la
    # nouvelle connexion oubliee. Rend @{ Ok ; Text (resultat affiche) ; Error (refus affiche) } ; confirmation refusee :
    # Ok faux, rien n est change
    $res = @{ Ok = $false; Text = ''; Error = '' }
    if (-not $plan) { return $res }
    if ($plan.Error) { $res.Error = [string]$plan.Error; return $res }
    if ($plan.Ask -eq 'check') {
        if (-not (Show-AppConfirm -Title (T 'Lecteurs enregistrés') -Heading $plan.AskHeading -Text $plan.AskText -Check $plan.AskCheck -GoText $plan.AskGo -GoGlyph 'Save' -Level 'warn')) { return $res }
    } elseif ($plan.Ask -eq 'yesno') {
        if ([string](Show-AppMessage $plan.AskText (T 'Lecteurs enregistrés') 'YesNo' 'Question') -ne 'Yes') { return $res }
    }
    $banner = [string]$cmbDrive.Text; $bConn = Get-DriveConn $banner
    $r = $null
    switch ([string]$plan.Kind) {
        'new'         { $r = Add-NamedDrive $plan.Name $plan.Conn }
        'adopt'       { $r = Add-NamedDrive $plan.Name $plan.Conn $plan.From }
        'rename'      { $r = Rename-NamedDrive $plan.Old $plan.Name }
        'move'        { $r = Move-NamedDrive $plan.Old $plan.Conn }
        'rename+move' { $r = Rename-NamedDrive $plan.Old $plan.Name; if ($r.Ok) { $r = Move-NamedDrive $plan.Name $plan.Conn } }
    }
    if (-not $r -or -not $r.Ok) { $res.Error = $(if ($r -and $r.Why) { [string]$r.Why } else { (T "Configuration non sauvegardée : rien n'a été modifié (voir le journal).") }); return $res }
    $now = ''
    if ($plan.Kind -eq 'adopt' -and $banner -ceq [string]$plan.From) { $now = [string]$plan.Name }
    elseif ($plan.Old -and $banner -ceq [string]$plan.Old) { $now = [string]$plan.Name }
    if ($now) {
        $nc = Get-DriveConn $now
        $script:DriveCur = $now
        $nl = @{}
        foreach ($e in @($script:DriveLast.GetEnumerator())) { if ([string]$e.Key -cne $nc) { $nl[[string]$e.Key] = [string]$e.Value } }
        if ($nc) { $nl[$nc] = $now }
        $script:DriveLast = $nl
        if ($nc -cne $bConn) { $script:DriveChecked = ''; Clear-DriveActivity $nc }
    }
    Update-DriveUiAfterEdit $now
    foreach ($l in @($plan.Log)) { Append-Log ([string]$l) }
    [void](Save-Config)
    $res.Ok = $true; $res.Text = [string]$plan.Text
    return $res
}

function Get-DriveDeletePlan($row) {
    # 12.11 (lot LN-b) : seule decision du bouton « Supprimer... » (fiche seulement), et ses textes, sans rien changer :
    # @{ Error ; Name ; Conn ; Any ; Keep ; N ; Heading ; Text ; Check ; Go ; Alt ; Question ; TextDel ; TextKeep }. Avec
    # des donnees (Any) : confirmation a case au niveau danger, qui ne nomme aucune des deux issues (la case commande les
    # deux boutons) ; chaque bouton nomme la sienne ; « Retirer seulement le nom » (Keep) propose quand la fiche a une
    # connexion dont le lecteur non enregistre n a aucune donnee (sinon Remove-NamedDrive -KeepData le refuserait). Sans
    # donnee : question simple. La copie annoncee (texte de la confirmation) est faite par Remove-NamedDrive des que le
    # lecteur a une donnee, le meme champ Any decidant des deux
    $p = @{ Error = ''; Name = ''; Conn = ''; Any = $false; Keep = $false; N = 0; Heading = ''; Text = ''; Check = ''; Go = ''; Alt = ''; Question = ''; TextDel = ''; TextKeep = '' }
    $why = Get-DriveEditRefusal
    if ($why) { $p.Error = $why; return $p }
    $rec = if ($row -and [string]$row.Kind -eq 'rec') { Get-DriveRecord ([string]$row.Drive) } else { $null }
    if (-not $rec) { return $p }
    $nm = [string]$rec.Name; $c = [string]$rec.Conn
    $dt = Get-DriveData $nm
    $p.Name = $nm; $p.Conn = $c; $p.Any = [bool]$dt['Any']
    $p.N = @($dt['Keys']).Count + @($dt['Cross']).Count
    $p.Keep = [bool]($c -and (Test-DriveConnCode $c) -and -not (Get-DriveData $c)['Any'])
    if ($p.Any) {
        $p.Heading = (T 'Supprimer le lecteur « {0} » ?') -f $nm
        $p.Text = (T "Sont retirés : ses calibrations ({0}), ses niveaux, sa mémoire par marque, ses facteurs mesurés et son lecteur cible, ainsi que les courbes croisées dont il est le lecteur cible et le choix de ce lecteur comme cible d'un autre.`n`nL'application ne peut pas annuler cette suppression. Elle copie d'abord la configuration dans « {1}.lecteurs-….bak », dans le même dossier : pour revenir en arrière, fermez l'application, puis remettez cette copie à la place de « {1} ».") -f (Get-DriveDataText $dt), [System.IO.Path]::GetFileName([string]$script:ConfigFile)
        if ($p.Keep) { $p.Text += "`n`n" + ((T '« Retirer seulement le nom » : ses calibrations restent, rangées sous la connexion {0}, sans nom de lecteur.') -f $c); $p.Alt = (T 'Retirer seulement le nom') }
        $p.Check = (T 'Le lecteur « {0} » ne doit plus être enregistré') -f $nm
        $p.Go = (T 'Supprimer avec ses calibrations')
    } else { $p.Question = (T 'Supprimer le lecteur « {0} » ? Il n''a aucune calibration.') -f $nm }
    $p.TextDel = (T 'Lecteur « {0} » supprimé : {1} courbe(s) retirée(s).') -f $nm, "$($p.N)"
    $p.TextKeep = (T 'Nom « {0} » retiré : ses calibrations sont rangées sous la connexion {1}, sans nom de lecteur.') -f $nm, $c
    return $p
}

function Remove-DriveEntry($row) {
    # 12.11 (lot LN-b) : « Supprimer... » de la fenetre « Lecteurs enregistres » : decision et textes de
    # Get-DriveDeletePlan, confirmation, Remove-NamedDrive (avec -KeepData pour « Retirer seulement le nom » ; copie
    # datee faite par elle), interface (Update-DriveUiAfterEdit : lecteur supprime du bandeau remplace par le lecteur non
    # enregistre de sa connexion), journal, enregistrement. Rend @{ Ok ; Text ; Error } ; confirmation refusee : Ok faux
    $res = @{ Ok = $false; Text = ''; Error = '' }
    $p = Get-DriveDeletePlan $row
    if ($p.Error) { $res.Error = [string]$p.Error; return $res }
    if (-not $p.Name) { return $res }
    $keep = $false
    if ($p.Any) {
        $go = [bool](Show-AppConfirm -Title (T 'Lecteurs enregistrés') -Heading $p.Heading -Text $p.Text -Check $p.Check -GoText $p.Go -GoGlyph 'Delete' -Level 'danger' -AltText $p.Alt)
        if (-not $go) {
            if ($p.Alt -and [string]$script:ConfirmChoice -eq 'alt') { $keep = $true } else { return $res }
        }
    } elseif ([string](Show-AppMessage $p.Question (T 'Lecteurs enregistrés') 'YesNo' 'Question') -ne 'Yes') { return $res }
    $r = if ($keep) { Remove-NamedDrive $p.Name -KeepData } else { Remove-NamedDrive $p.Name }
    if (-not $r.Ok) { $res.Error = $(if ($r.Why) { [string]$r.Why } else { (T "Configuration non sauvegardée : rien n'a été modifié (voir le journal).") }); return $res }
    Update-DriveUiAfterEdit
    $res.Text = $(if ($keep) { [string]$p.TextKeep } else { [string]$p.TextDel })
    Append-Log $res.Text
    [void](Save-Config)
    $res.Ok = $true
    return $res
}

function Get-DriveWidestName($font) {
    # 12.11 (lot LN-b) : nom le plus large admis par Test-DriveName dans la police $font (lettres W, les plus larges) :
    # sert a mesurer les textes qui citent un nom (hauteur du texte d etat de la fenetre « Lecteurs enregistres »)
    $n = 'W'
    while ($n.Length -lt [int]$script:DriveNameMax -and [System.Windows.Forms.TextRenderer]::MeasureText(($n + 'W'), $font).Width -le ([int]$script:DriveListWidth - 24)) { $n += 'W' }
    return $n
}

function Get-DrivesStateSamples($font) {
    # 12.11 (lot LN-b) : textes les plus longs du texte d etat de la fenetre « Lecteurs enregistres », avec le nom le plus
    # large admis : sa hauteur est celle du plus haut d entre eux (aucun texte coupe)
    $w = Get-DriveWidestName $font
    return @(
        ((T 'La connexion {0} a déjà des calibrations sans nom de lecteur. Pour les garder avec ce lecteur, sélectionnez la ligne « {0} (non enregistré) » et donnez-lui ce nom ; sinon ce lecteur sera calibré à part.') -f 'A'),
        ((T "Lecteur « {0} » : il s'appelait « {1} ». Ses calibrations ({2} courbe(s)), ses niveaux, sa mémoire par marque, ses facteurs et ses lecteurs cibles portent son nouveau nom.") -f $w, $w, '99'),
        ((T 'Lecteur « {0} » : connexion {1} (avant : {2}). Ses calibrations le suivent. Après un changement de nappe, contrôlez une écriture (onglet Qualité) ou refaites une calibration rapide.') -f $w, 'A', (T 'à préciser')),
        ((T 'Lecteur « {0} » enregistré sur la connexion {1} : les calibrations faites sans nom sur la connexion {2} ({3} courbe(s)) sont maintenant les siennes.') -f $w, 'A', '0', '99'),
        ((T 'Lecteur « {0} » enregistré sur la connexion {1}, sans calibration. Choisissez-le dans la liste « Lecteur : » du bandeau quand il est branché.') -f $w, 'A'),
        ((T 'Le lecteur {0} a déjà des données (courbes, lecteur cible, niveaux, mémoire par marque ou facteurs) : celles de la connexion {1} ne peuvent pas lui être attribuées.') -f $w, 'A'),
        ((T 'La connexion {0} a déjà des données sans nom de lecteur (courbes, lecteur cible, niveaux, mémoire par marque ou facteurs) : le nom ne peut pas être retiré seul.') -f 'A'),
        ((T 'Lecteurs enregistrés : opération en cours ({0}). Réessayez quand elle est terminée.') -f (T 'mesure continue de la qualité')),
        ((T "Nom trop large pour s'afficher en entier dans les listes de lecteurs (environ 17 caractères) : raccourcissez-le."))
    )
}

function New-DrivesDialog {
    # 12.11 (lot LN-b) : fenetre « Lecteurs enregistres » (frmDrives), construite sans etre affichee (Show-DrivesDialog
    # l affiche), au modele de frmJitter : bandeau d information (New-DlgBanner, lblDrvText) ; liste lvDrives (Get-DriveRows),
    # colonnes « Lecteur », « Connexion », « Calibrations » (150 + 90 + 379 = 619 px : largeur utile quand la barre
    # verticale parait, aucune barre horizontale) ; « Nom : » (txtDrvName, 24 caracteres au plus), « Connexion : »
    # (cmbDrvConn) ; texte d etat lblDrvState (refus dans l encre du danger, note ou resultat dans l encre neutre ; hauteur
    # du plus haut de ses textes les plus longs, Get-DrivesStateSamples, mesure par le Label lui-meme) ; « Nouveau
    # lecteur », « Supprimer... », « Enregistrer » (principal), « Fermer » (CancelButton, aucun AcceptButton : Entree
    # n enregistre rien). La fenetre ne decide rien (Get-DriveEditPlan, Invoke-DriveEditPlan, Get-DriveDeletePlan,
    # Remove-DriveEntry) et n ouvre aucune boite de message directe (Show-AppConfirm, Show-AppMessage). Rend l etat
    # partage avec ses gestionnaires ($script:DrvDlg) : @{ Dlg ; Lv ; Name ; Conn ; State ; New ; Del ; Save ; Close ;
    # Gdi ; Rows ; Mode ('new' ou 'row') ; Busy }
    $W = 640
    $gdi = New-Object System.Collections.Generic.List[object]
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmDrives'; $dlg.Text = (T 'Lecteurs enregistrés')
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    $text = (T "Un lecteur enregistré a un nom et une connexion au Greaseweazle (A ou B : nappe PC avec twist ; 0 à 3 : nappe droite). Ses calibrations, son lecteur cible et ses facteurs mesurés sont rangés sous son nom : plusieurs lecteurs peuvent partager une connexion, et un lecteur garde ses calibrations quand il change de connexion.`n`nL'application ne reconnaît pas le lecteur branché : celui qui compte est le lecteur choisi dans la liste « Lecteur : » du bandeau. Un lecteur nouveau part sans calibration, avec le profil d'origine.")
    $ban = New-DlgBanner $dlg 16 $W (T 'Vos lecteurs de disquette') $text 'info' (New-DlgPicto 'drive') $gdi 'lblDrvText'
    $y = $ban.Bottom + 14
    $lv = New-Object System.Windows.Forms.ListView
    $lv.Name = 'lvDrives'; $lv.View = 'Details'; $lv.FullRowSelect = $true; $lv.MultiSelect = $false; $lv.HideSelection = $false
    $lv.HeaderStyle = 'Nonclickable'; $lv.Font = $dlg.Font
    $lv.Location = New-Object System.Drawing.Point(16, $y); $lv.Size = New-Object System.Drawing.Size($W, 190)
    [void]$lv.Columns.Add((T 'Lecteur'), 150); [void]$lv.Columns.Add((T 'Connexion'), 90); [void]$lv.Columns.Add((T 'Calibrations'), 379)
    $y = $lv.Bottom + 12
    $lblN = New-Object System.Windows.Forms.Label
    $lblN.Name = 'lblDrvName'; $lblN.Text = (T 'Nom :'); $lblN.AutoSize = $true; $lblN.Location = New-Object System.Drawing.Point(16, ($y + 3))
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Name = 'txtDrvName'; $txt.Width = 220; $txt.MaxLength = [int]$script:DriveNameMax
    $txt.Location = New-Object System.Drawing.Point((16 + [System.Windows.Forms.TextRenderer]::MeasureText($lblN.Text, $dlg.Font).Width + 6), $y)
    $lblC = New-Object System.Windows.Forms.Label
    $lblC.Name = 'lblDrvConn'; $lblC.Text = (T 'Connexion :'); $lblC.AutoSize = $true; $lblC.Location = New-Object System.Drawing.Point(($txt.Right + 24), ($y + 3))
    $cmb = New-Object System.Windows.Forms.ComboBox
    $cmb.Name = 'cmbDrvConn'; $cmb.DropDownStyle = 'DropDownList'; $cmb.Width = 56
    [void]$cmb.Items.AddRange([object[]]@($script:SettingDefs['drive'].Codes))
    $cmb.Location = New-Object System.Drawing.Point(($lblC.Left + [System.Windows.Forms.TextRenderer]::MeasureText($lblC.Text, $dlg.Font).Width + 6), $y)
    $y += 34
    $fS = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75); $gdi.Add($fS)
    $st = New-Object System.Windows.Forms.Label
    $st.Name = 'lblDrvState'; $st.AutoSize = $false; $st.UseMnemonic = $false; $st.Font = $fS; $st.ForeColor = $script:Theme.Muted
    $st.Location = New-Object System.Drawing.Point(16, $y); $st.Size = New-Object System.Drawing.Size($W, 20)
    # 12.11 (lot LN-b) : hauteur mesuree par le Label lui-meme (son decoupage des lignes) : la maquette donnait 36 px a deux
    # lignes, qui en demandent 40
    $hs = 0
    foreach ($s0 in @(Get-DrivesStateSamples $fS)) { $st.Text = [string]$s0; $h0 = $st.GetPreferredSize((New-Object System.Drawing.Size($W, 0))).Height; if ($h0 -gt $hs) { $hs = $h0 } }
    $st.Text = ''; $st.Height = $hs
    $y = $st.Bottom + 8
    $bNew = New-Object System.Windows.Forms.Button; $bNew.Name = 'btnDrvNew'; $bNew.Text = (T 'Nouveau lecteur'); $bNew.Size = New-Object System.Drawing.Size((Get-DlgButtonWidth $bNew.Text 'Add' 150), 34)
    $bDel = New-Object System.Windows.Forms.Button; $bDel.Name = 'btnDrvDel'; $bDel.Text = (T 'Supprimer…'); $bDel.Size = New-Object System.Drawing.Size((Get-DlgButtonWidth $bDel.Text 'Delete' 130), 34)
    $bSave = New-Object System.Windows.Forms.Button; $bSave.Name = 'btnDrvSave'; $bSave.Text = (T 'Enregistrer'); $bSave.Size = New-Object System.Drawing.Size((Get-DlgButtonWidth $bSave.Text 'Save' 140), 34)
    $bClose = New-Object System.Windows.Forms.Button; $bClose.Name = 'btnDrvClose'; $bClose.Text = (T 'Fermer'); $bClose.Size = New-Object System.Drawing.Size(110, 34)
    $bClose.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-Btn $bNew 'Add' 'normal'; Set-Btn $bDel 'Delete' 'normal'; Set-Btn $bSave 'Save' 'primary'; Set-Btn $bClose '' 'normal'
    $bNew.Location = New-Object System.Drawing.Point(16, $y); $bDel.Location = New-Object System.Drawing.Point(($bNew.Right + 8), $y)
    $bClose.Location = New-Object System.Drawing.Point((16 + $W - $bClose.Width), $y); $bSave.Location = New-Object System.Drawing.Point(($bClose.Left - 8 - $bSave.Width), $y)
    $dlg.ClientSize = New-Object System.Drawing.Size(($W + 32), ($y + 34 + 16))
    $dlg.CancelButton = $bClose
    $dlg.Controls.AddRange(@($lv, $lblN, $txt, $lblC, $cmb, $st, $bNew, $bDel, $bSave, $bClose))
    $s = @{ Dlg = $dlg; Lv = $lv; Name = $txt; Conn = $cmb; State = $st; New = $bNew; Del = $bDel; Save = $bSave; Close = $bClose; Gdi = $gdi; Rows = @(); Mode = 'new'; Busy = $false }
    $script:DrvDlg = $s
    $lv.Add_SelectedIndexChanged({ $s = $script:DrvDlg; if ($s -and -not $s.Busy) { Set-DrivesDialogInputs $s } })
    $cmb.Add_SelectedIndexChanged({ $s = $script:DrvDlg; if ($s -and -not $s.Busy -and $s.Mode -eq 'new') { Show-DrivesDialogNote $s } })
    $bNew.Add_Click({ if ($script:DrvDlg) { Start-DrivesDialogNew $script:DrvDlg } })
    $bSave.Add_Click({ if ($script:DrvDlg) { [void](Invoke-DrivesDialogSave $script:DrvDlg) } })
    $bDel.Add_Click({ if ($script:DrvDlg) { [void](Invoke-DrivesDialogDelete $script:DrvDlg) } })
    Update-DrivesDialog $s
    Start-DrivesDialogNew $s
    return $s
}

function Get-DrivesDialogRow($s) {
    # 12.11 (lot LN-b) : ligne choisie de frmDrives (Get-DriveRows), lue sur les elements eux-memes (SelectedIndices reste
    # vide tant que la liste n a pas de poignee) ; $null sans choix ou en mode « Nouveau lecteur »
    if (-not $s -or $s.Mode -ne 'row') { return $null }
    for ($i = 0; $i -lt $s.Lv.Items.Count; $i++) { if ($s.Lv.Items[$i].Selected -and $i -lt @($s.Rows).Count) { return $s.Rows[$i] } }
    return $null
}

function Set-DrivesDialogState($s, [string]$text, [bool]$err) {
    # 12.11 (lot LN-b) : texte d etat de frmDrives : refus dans l encre du danger, note ou resultat dans l encre neutre
    $s.State.ForeColor = $(if ($err) { $script:Theme.Danger } else { $script:Theme.Muted })
    $s.State.Text = $text
}

function Update-DrivesDialog($s, [string]$keep = '') {
    # 12.11 (lot LN-b) : lignes de frmDrives (Get-DriveRows) ; $keep : identite de la ligne a choisir ensuite (mode ligne)
    $s.Busy = $true
    try {
        $rows = Get-DriveRows
        $s.Rows = $rows
        $s.Lv.BeginUpdate()
        $s.Lv.Items.Clear()
        foreach ($r in $rows) {
            $it = New-Object System.Windows.Forms.ListViewItem([string]$r.Text)
            [void]$it.SubItems.Add([string]$r.ConnText); [void]$it.SubItems.Add([string]$r.Cal)
            [void]$s.Lv.Items.Add($it)
        }
        $s.Lv.EndUpdate()
        $s.Mode = 'new'
        if ($keep) { for ($i = 0; $i -lt @($rows).Count; $i++) { if ([string]$rows[$i].Drive -ceq $keep) { Select-DrivesDialogRow $s $i; $s.Mode = 'row' } } }
    } finally { $s.Busy = $false }
    if ($s.Mode -eq 'row') { Set-DrivesDialogInputs $s }
}

function Select-DrivesDialogRow($s, [int]$i) {
    # 12.11 (lot LN-b) : une seule ligne choisie dans frmDrives : les autres d abord desselectionnees (une liste sans
    # poignee n applique pas MultiSelect)
    for ($k = 0; $k -lt $s.Lv.Items.Count; $k++) { if ($k -ne $i -and $s.Lv.Items[$k].Selected) { $s.Lv.Items[$k].Selected = $false } }
    if ($i -ge 0 -and $i -lt $s.Lv.Items.Count) { $s.Lv.Items[$i].Selected = $true }
}

function Set-DrivesDialogInputs($s) {
    # 12.11 (lot LN-b) : ligne choisie de frmDrives : nom de la fiche (vide pour un lecteur non enregistre), sa connexion
    # (aucune pour une fiche « a preciser »), « Supprimer... » actif pour une fiche seulement
    $s.Mode = 'row'
    $r = Get-DrivesDialogRow $s
    $s.Busy = $true
    try {
        if (-not $r) { $s.Mode = 'new'; $s.Del.Enabled = $false; return }
        $s.Name.Text = $(if ([string]$r.Kind -eq 'rec') { [string]$r.Drive } else { '' })
        $s.Conn.SelectedIndex = [array]::IndexOf([string[]]@($script:SettingDefs['drive'].Codes), [string]$r.Conn)
        $s.Del.Enabled = ([string]$r.Kind -eq 'rec')
    } finally { $s.Busy = $false }
    Set-DrivesDialogState $s '' $false
}

function Start-DrivesDialogNew($s) {
    # 12.11 (lot LN-b) : « Nouveau lecteur » : aucune ligne choisie, nom vide, connexion proposee : celle du lecteur du
    # bandeau ; note de la connexion (Show-DrivesDialogNote)
    $s.Busy = $true
    try {
        foreach ($it in @($s.Lv.Items)) { $it.Selected = $false }
        $s.Mode = 'new'; $s.Name.Text = ''; $s.Del.Enabled = $false
        $c = Get-DriveConn ([string]$cmbDrive.Text); if (-not $c) { $c = [string](Get-Setting 'drive') }
        $s.Conn.SelectedIndex = [array]::IndexOf([string[]]@($script:SettingDefs['drive'].Codes), $c)
    } finally { $s.Busy = $false }
    Show-DrivesDialogNote $s
}

function Show-DrivesDialogNote($s) {
    # 12.11 (lot LN-b) : « Nouveau lecteur » : note de la connexion choisie avant l enregistrement (Get-DriveEditPlan :
    # elle a des calibrations sans nom de lecteur), dans l encre neutre
    $p = Get-DriveEditPlan $null ([string]$s.Name.Text) ([string]$s.Conn.Text)
    Set-DrivesDialogState $s ([string]$p.Note) $false
}

function Invoke-DrivesDialogSave($s) {
    # 12.11 (lot LN-b) : bouton « Enregistrer » de frmDrives : decision (Get-DriveEditPlan), execution
    # (Invoke-DriveEditPlan) ; refus dans le texte d etat, la fenetre reste ouverte ; resultat dans le texte d etat, liste
    # a jour, ligne du lecteur modifie choisie. Rend le resultat d Invoke-DriveEditPlan
    $row = Get-DrivesDialogRow $s
    $plan = Get-DriveEditPlan $row ([string]$s.Name.Text) ([string]$s.Conn.Text)
    $r = Invoke-DriveEditPlan $plan
    if ($r.Error) { Set-DrivesDialogState $s ([string]$r.Error) $true; return $r }
    if (-not $r.Ok) { return $r }
    Update-DrivesDialog $s ([string]$plan.Name)
    Set-DrivesDialogState $s ([string]$r.Text) $false
    return $r
}

function Invoke-DrivesDialogDelete($s) {
    # 12.11 (lot LN-b) : bouton « Supprimer... » de frmDrives (Remove-DriveEntry) ; ensuite, mode « Nouveau lecteur »
    $r = Remove-DriveEntry (Get-DrivesDialogRow $s)
    if ($r.Error) { Set-DrivesDialogState $s ([string]$r.Error) $true; return $r }
    if (-not $r.Ok) { return $r }
    Update-DrivesDialog $s
    Start-DrivesDialogNew $s
    Set-DrivesDialogState $s ([string]$r.Text) $false
    return $r
}

function Show-DrivesDialog {
    # 12.11 (lot LN-b) : carte « Lecteurs enregistres » de l Accueil (540) : refusee pendant une operation (texte qui porte
    # le libelle rendu par Get-AppBusy, la fonction qui decide : la pause d une mesure continue et une detection des
    # lecteurs en sont), sinon frmDrives (New-DrivesDialog), modale ; images et polices liberees a la fermeture
    $busy = Get-AppBusy -Text
    if ($busy) { [void](Show-AppMessage ((T 'Lecteurs enregistrés : opération en cours ({0}). Réessayez quand elle est terminée.') -f "$busy") (T 'Lecteurs enregistrés') 'OK' 'Information'); return }
    $s = New-DrivesDialog
    [void](Set-DlgFit $s.Dlg ([System.Windows.Forms.Screen]::FromControl($form).WorkingArea))
    try { [void]$s.Dlg.ShowDialog($form) } finally { $script:DrvDlg = $null; Clear-DlgGdi $s.Dlg $s.Gdi }
}
