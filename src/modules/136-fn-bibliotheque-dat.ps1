# ============================== FONCTIONS : BIBLIOTHEQUE, LISTE DE REFERENCE ====
# 12.8 (lot 4b, D19 ; A3 § 3.4 B) : liste de reference (DAT) choisie par l utilisateur sur son ordinateur. Aucune liste
# n est fournie, embarquee ni telechargee par l application. Formats : Logiqx XML (TOSEC, No-Intro), lu par XmlReader
# sans DTD ni resolution externe, et clrmamepro (texte). Identification d un fichier : index par taille et empreinte
# (SHA-1 ou MD5 par la cryptographie .NET, sinon CRC-32 par la bibliotheque ZIP de .NET, Get-Crc32) ; etats sur le
# modele de RomVault : officiel (identique a une entree de la liste), modifie (meme nom qu une entree, contenu different),
# inconnu. Archive ZIP : CRC-32 et taille de chaque entree lus dans le repertoire central, sans decompression ni calcul ;
# image extraite pour l ecriture controlee contre ce CRC-32 (Test-LibZipEntryData, FIX4B).
# Empreintes calculees gardees dans hash-<md5 de la racine>.tsv, a cote de l index. Fonctions sans interface, testables
# au niveau 2. Aucun calcul de CRC en PowerShell (alertes EDR du 20/10/2026).

function New-LibDatIndex([string]$format) {
    # Liste vide : en-tete, compteurs, index par taille et par nom de fichier (sans le dossier, casse ignoree).
    # FIX4C (relecture finale du lot 4) : index ByHash par « taille|type|empreinte » (type C, M ou S : CRC-32, MD5, SHA-1),
    # et « taille|type| » pour les entrees de cette taille qui n ont pas cette empreinte (Get-LibDatMatch)
    return @{ Ok = $false; Error = ''; Format = $format; Name = ''; Description = ''; Version = ''; Path = ''
              Games = 0; Roms = 0; Skipped = 0; Ms = 0
              BySize = [System.Collections.Generic.Dictionary[long, System.Collections.Generic.List[object]]]::new()
              ByName = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new([System.StringComparer]::OrdinalIgnoreCase)
              ByHash = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new([System.StringComparer]::OrdinalIgnoreCase) }
}

function Add-LibDatRom($dat, [string]$game, [string]$name, [string]$size, [string]$crc, [string]$md5, [string]$sha1) {
    # Entree d une liste : taille obligatoire et au moins une empreinte valide (CRC-32 sur 8 chiffres hexadecimaux, MD5,
    # SHA-1) ; sinon ignoree (comptee dans Skipped). Nom garde sans son dossier
    [long]$sz = -1
    if (-not [long]::TryParse(([string]$size).Trim(), [System.Globalization.NumberStyles]::Integer, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$sz) -or $sz -lt 0) { $dat.Skipped++; return }
    $c = ([string]$crc).Trim().ToUpperInvariant()
    if ($c -match '^[0-9A-F]{1,8}$') { $c = $c.PadLeft(8, '0') } else { $c = '' }
    $m = ([string]$md5).Trim().ToLowerInvariant(); if ($m -notmatch '^[0-9a-f]{32}$') { $m = '' }
    $s = ([string]$sha1).Trim().ToLowerInvariant(); if ($s -notmatch '^[0-9a-f]{40}$') { $s = '' }
    if (-not $c -and -not $m -and -not $s) { $dat.Skipped++; return }
    $leaf = ([string]$name) -replace '^.*[\\/]', ''
    $e = @{ Game = [string]$game; Name = $leaf; Size = $sz; Crc = $c; Md5 = $m; Sha1 = $s; Ord = 0 }
    $l = $null
    if (-not $dat.BySize.TryGetValue($sz, [ref]$l)) { $l = [System.Collections.Generic.List[object]]::new(); $dat.BySize[$sz] = $l }
    $e.Ord = $l.Count
    $l.Add($e)
    # FIX4C : rang Ord dans la liste de sa taille ; index par taille et empreinte, empreinte vide = entree sans cette empreinte
    foreach ($k in "$sz|C|$c", "$sz|M|$m", "$sz|S|$s") {
        $l = $null
        if (-not $dat.ByHash.TryGetValue($k, [ref]$l)) { $l = [System.Collections.Generic.List[object]]::new(); $dat.ByHash[$k] = $l }
        $l.Add($e)
    }
    if ($leaf) {
        $l = $null
        if (-not $dat.ByName.TryGetValue($leaf, [ref]$l)) { $l = [System.Collections.Generic.List[object]]::new(); $dat.ByName[$leaf] = $l }
        $l.Add($e)
    }
    $dat.Roms++
}

function Get-LibDatRx {
    # Expressions du format clrmamepro, creees une fois. FIX4B (revue du lot 4, C6) : aucune n a deux quantificateurs
    # voisins qui se disputent les memes caracteres (« rom ( » suivi de milliers d espaces bloquait l interface 50 s) :
    # duree proportionnelle a la longueur de la ligne ; delai maximal de 1 s par recherche en plus (liste refusee)
    if ($script:LibDatRx) { return $script:LibDatRx }
    $o = [System.Text.RegularExpressions.RegexOptions]::None; $to = [TimeSpan]::FromSeconds(1)
    $script:LibDatRx = @{
        Open    = [regex]::new('^(\w+)\s*\($', $o, $to)
        Kv      = [regex]::new('^(\w+)\s+(?:"([^"]*)"|(.*))$', $o, $to)
        # Forme ecrite par clrmamepro (espaces simples) : nom entre guillemets ou sans espace, size, crc, puis md5 et sha1
        RomFast = [regex]::new('^rom \( name (?:"([^"]*)"|([^\s"]+)) size (\d+) crc "?([0-9A-Fa-f]{1,8})"?(?: md5 "?([0-9A-Fa-f]{32})"?)?(?: sha1 "?([0-9A-Fa-f]{40})"?)? \)$', $o, $to)
        # Jetons : texte entre guillemets (jusqu a la fin si le guillemet n est pas ferme), ou suite de caracteres sans espace
        Tok     = [regex]::new('"[^"]*(?:"|$)|[^\s"]+', $o, $to)
        Hex     = [regex]::new('^"?([0-9A-Fa-f]+)"?$', $o, $to)
        Keys    = [System.Collections.Generic.HashSet[string]]::new([string[]]@('size', 'crc', 'md5', 'sha1', 'sha256', 'merge', 'status', 'flags', 'date', 'region', 'serial', 'offs', 'bios'), [System.StringComparer]::Ordinal)
    }
    return $script:LibDatRx
}

function ConvertFrom-LibDatRomLine([string]$ln) {
    # Ligne « rom ( ... ) » de clrmamepro (rognee) : champs name, size, crc, md5, sha1 ; $null si ce n est pas un fichier
    # decrit sur une ligne (« rom ( » seul ouvre un bloc). FIX4B (C6) : forme courante lue par une expression sans retour
    # arriere, sinon contenu entre la premiere « ( » et la derniere « ) », decoupe en jetons
    $rx = Get-LibDatRx
    $m = $rx.RomFast.Match($ln)
    if ($m.Success) {
        return @{ name = $(if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }); size = $m.Groups[3].Value; crc = $m.Groups[4].Value; md5 = $m.Groups[5].Value; sha1 = $m.Groups[6].Value }
    }
    $i = $ln.IndexOf('(')
    if ($i -lt 3 -or -not $ln.StartsWith('rom') -or $ln.Substring(3, $i - 3).Trim().Length -gt 0 -or -not $ln.EndsWith(')') -or $ln.Length - $i -lt 2) { return $null }
    return (ConvertFrom-LibDatRomText $ln.Substring($i + 1, $ln.Length - $i - 2).Trim())
}

function ConvertFrom-LibDatRomText([string]$s) {
    # Champs d une ligne « rom ( ... ) » de clrmamepro : name entre guillemets, ou jusqu au mot-cle suivant (noms avec
    # espaces ou parentheses, ecrits sans guillemets par certains outils, comme la DAT SPS) ; puis size, crc, md5, sha1.
    # FIX4B (C6) : jetons d une expression lineaire, lus dans l ordre ; nom sans guillemets repris tel quel de la ligne
    $rx = Get-LibDatRx
    $f = @{}
    $toks = $rx.Tok.Matches($s)
    $n = $toks.Count; $i = 0
    if ($n -ge 2 -and $toks[0].Value -ceq 'name') {
        $a = $toks[1]
        if ($a.Value.StartsWith('"')) {
            $v = $a.Value.Substring(1); if ($v.EndsWith('"')) { $v = $v.Substring(0, $v.Length - 1) }
            $f['name'] = $v; $i = 2
        } else {
            # Nom jusqu au mot-cle suivant, s il est suivi d un autre jeton (comme « size 1234 »)
            $j = 2
            while ($j -lt $n -and -not ($rx.Keys.Contains($toks[$j].Value) -and $j + 1 -lt $n)) { $j++ }
            $z = $toks[$j - 1]
            $f['name'] = $s.Substring($a.Index, $z.Index + $z.Length - $a.Index); $i = $j
        }
    }
    foreach ($k in 'size', 'crc', 'md5', 'sha1') {
        for ($t = $i; $t + 1 -lt $n; $t++) {
            if ($toks[$t].Value -cne $k) { continue }
            $h = $rx.Hex.Match($toks[$t + 1].Value)
            if ($h.Success) { $f[$k] = $h.Groups[1].Value; break }
        }
    }
    return $f
}

function Read-LibDatClrMamePro([string]$text) {
    # Format texte clrmamepro, ligne par ligne (forme ecrite par clrmamepro et par les outils qui le suivent) : bloc ouvert
    # par « mot ( » en fin de ligne et ferme par « ) » seul ; lignes « cle valeur » (valeur entre guillemets ou non) ;
    # fichier sur une ligne, « rom ( name ... size ... crc ... md5 ... sha1 ... ) ». En-tete : clrmamepro ou emulator ;
    # jeux : game, machine, resource, set ; autres blocs et lignes (disk, sample...) ignores ; « ) » en trop ignoree
    $dat = New-LibDatIndex 'clrmamepro'
    # FIX4B (C6) : expressions sans retour arriere catastrophique (Get-LibDatRx), ligne « rom ( ... ) » lue par
    # ConvertFrom-LibDatRomLine (forme courante d un coup, sinon jetons)
    $rx = Get-LibDatRx
    $rxOpen = $rx.Open; $rxKv = $rx.Kv
    $stack = [System.Collections.Generic.List[object]]::new()
    $cur = $null
    foreach ($raw in $text.Split([char]10)) {
        $ln = $raw.Trim()
        if ($ln.Length -eq 0) { continue }
        if ($cur -and $ln.StartsWith('rom')) {
            $rf = ConvertFrom-LibDatRomLine $ln
            if ($null -ne $rf) { $cur.Roms.Add($rf); continue }
        }
        if ($ln -eq ')') {
            if ($stack.Count -eq 0) { continue }
            $blk = $cur
            $stack.RemoveAt($stack.Count - 1)
            $cur = if ($stack.Count -gt 0) { $stack[$stack.Count - 1] } else { $null }
            $t = $blk.T
            if ($t -eq 'rom') { if ($cur) { $cur.Roms.Add($blk.F) } }
            elseif ($t -eq 'game' -or $t -eq 'machine' -or $t -eq 'resource' -or $t -eq 'set') {
                $dat.Games++
                foreach ($f in $blk.Roms) { Add-LibDatRom $dat ([string]$blk.F['name']) ([string]$f['name']) ([string]$f['size']) ([string]$f['crc']) ([string]$f['md5']) ([string]$f['sha1']) }
            } elseif ($t -eq 'clrmamepro' -or $t -eq 'emulator') {
                $dat.Name = [string]$blk.F['name']; $dat.Description = [string]$blk.F['description']; $dat.Version = [string]$blk.F['version']
            }
            continue
        }
        if ($ln.EndsWith('(')) {
            $m = $rxOpen.Match($ln)
            if ($m.Success) {
                $blk = @{ T = $m.Groups[1].Value.ToLowerInvariant(); F = @{}; Roms = [System.Collections.Generic.List[object]]::new() }
                $stack.Add($blk); $cur = $blk
                continue
            }
        }
        if (-not $cur) { continue }
        $m = $rxKv.Match($ln)
        if ($m.Success) { $cur.F[$m.Groups[1].Value.ToLowerInvariant()] = $(if ($m.Groups[2].Success) { $m.Groups[2].Value } else { $m.Groups[3].Value }) }
    }
    return $dat
}

function Read-LibDatLogiqx([System.IO.Stream]$stream) {
    # Format Logiqx XML : <header> (name, description, version), <game> ou <machine> ou <software>, <rom name size crc
    # md5 sha1/>. DtdProcessing.Ignore : le DOCTYPE est saute sans lire la DTD (ni fichier ni reseau) ; XmlResolver nul :
    # aucune resolution externe. Une entite declaree dans la DTD (interne ou externe) reste donc inconnue : sa reference
    # leve une XmlException, la liste est refusee
    $dat = New-LibDatIndex 'Logiqx XML'
    $set = New-Object System.Xml.XmlReaderSettings
    $set.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
    $set.XmlResolver = $null
    $set.IgnoreComments = $true; $set.IgnoreWhitespace = $true; $set.IgnoreProcessingInstructions = $true
    $set.CloseInput = $false
    $xr = [System.Xml.XmlReader]::Create($stream, $set)
    try {
        $game = ''; $inHeader = $false
        $go = $xr.Read()
        while ($go) {
            $adv = $false
            $nt = $xr.NodeType
            if ($nt -eq [System.Xml.XmlNodeType]::Element) {
                $ln = $xr.LocalName
                if ($ln -eq 'rom') {
                    Add-LibDatRom $dat $game $xr.GetAttribute('name') $xr.GetAttribute('size') $xr.GetAttribute('crc') $xr.GetAttribute('md5') $xr.GetAttribute('sha1')
                } elseif ($ln -eq 'game' -or $ln -eq 'machine' -or $ln -eq 'software') {
                    $game = [string]$xr.GetAttribute('name'); $dat.Games++
                } elseif ($ln -eq 'header') {
                    if (-not $xr.IsEmptyElement) { $inHeader = $true }
                } elseif ($inHeader -and ($ln -eq 'name' -or $ln -eq 'description' -or $ln -eq 'version')) {
                    $v = $xr.ReadElementContentAsString(); $adv = $true
                    if ($ln -eq 'name') { $dat.Name = $v } elseif ($ln -eq 'description') { $dat.Description = $v } else { $dat.Version = $v }
                }
            } elseif ($nt -eq [System.Xml.XmlNodeType]::EndElement -and $xr.LocalName -eq 'header') { $inHeader = $false }
            if ($adv) { $go = -not $xr.EOF } else { $go = $xr.Read() }
        }
    } finally { $xr.Close() }
    return $dat
}

function Read-LibDat([string]$path) {
    # Liste de reference d un fichier : format d apres le premier caractere significatif (« < » : Logiqx XML ; lettre :
    # clrmamepro), 256 Mo au plus. Renvoie l index (Ok, ou Error avec le message)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $dat = New-LibDatIndex ''
    try {
        $fi = New-Object System.IO.FileInfo($path)
        if (-not $fi.Exists) { $dat.Error = (T 'fichier introuvable') }
        elseif ($fi.Length -gt 256MB) { $dat.Error = ((T 'fichier trop gros ({0})') -f (Format-Size $fi.Length)) }
        else {
            $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try {
                $head = New-Object byte[] 4096
                $n = $fs.Read($head, 0, 4096)
                $enc = [System.Text.Encoding]::UTF8; $off = 0
                if ($n -ge 2 -and $head[0] -eq 0xFF -and $head[1] -eq 0xFE) { $enc = [System.Text.Encoding]::Unicode; $off = 2 }
                elseif ($n -ge 2 -and $head[0] -eq 0xFE -and $head[1] -eq 0xFF) { $enc = [System.Text.Encoding]::BigEndianUnicode; $off = 2 }
                elseif ($n -ge 3 -and $head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF) { $off = 3 }
                $first = $enc.GetString($head, $off, [math]::Max(0, $n - $off)).TrimStart()
                [void]$fs.Seek(0, [System.IO.SeekOrigin]::Begin)
                $d = $null
                if ($first.StartsWith('<')) { $d = Read-LibDatLogiqx $fs }
                elseif ($first -match '^[A-Za-z]') {
                    $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8, $true)
                    $d = Read-LibDatClrMamePro $sr.ReadToEnd()
                } else { $dat.Error = (T 'format non reconnu (ni Logiqx XML ni clrmamepro)') }
                if ($d) {
                    $dat = $d
                    if ($dat.Roms -eq 0) { $dat.Error = (T 'aucune entrée avec une taille et une empreinte') }
                }
            } finally { $fs.Dispose() }
        }
    } catch {
        $e = $_.Exception
        while ($e.InnerException -and $e -is [System.Management.Automation.MethodInvocationException]) { $e = $e.InnerException }
        $dat.Error = if ($e -is [System.Text.RegularExpressions.RegexMatchTimeoutException]) { T 'liste mal formée (ligne trop longue à analyser)' } else { $e.Message }
    }
    $dat.Path = $path
    $dat.Ok = (-not $dat.Error)
    $dat.Ms = $sw.ElapsedMilliseconds
    if (-not $dat.Name) { $dat.Name = [System.IO.Path]::GetFileNameWithoutExtension($path) }
    return $dat
}

function Get-LibDatCompare($e, $h, [bool]$common = $false) {
    # Entree $e de la liste et empreintes connues $h du fichier : $false des qu une empreinte connue des deux cotes
    # differe ; sinon egalite exigee sur l empreinte la plus forte que porte l entree (SHA-1, puis MD5, puis CRC-32) ;
    # $null si le fichier ne l a pas encore (a calculer). FIX4B (revue du lot 4, C7) : un CRC-32 garde en cache ne decide
    # plus seul quand la liste fournit un SHA-1 ou un MD5 (le verdict ne depend plus du cache des empreintes).
    # $common (entree d archive ZIP : seul le CRC-32 du repertoire central est connu sans decompression) : la plus forte
    # des empreintes communes suffit, comme au lot 4b ; les donnees sont controlees avant l ecriture (Test-LibZipEntryData)
    if (($e.Sha1 -and $h.Sha1 -and $e.Sha1 -ne $h.Sha1) -or ($e.Md5 -and $h.Md5 -and $e.Md5 -ne $h.Md5) -or ($e.Crc -and $h.Crc -and $e.Crc -ne $h.Crc)) { return $false }
    if ($common) {
        if (($e.Sha1 -and $h.Sha1) -or ($e.Md5 -and $h.Md5) -or ($e.Crc -and $h.Crc)) { return $true }
        return $null
    }
    $k = if ($e.Sha1) { 'Sha1' } elseif ($e.Md5) { 'Md5' } else { 'Crc' }
    if ($e[$k] -and $h[$k]) { return $true }
    return $null
}

function Get-LibDatMatch($dat, [long]$size, [string]$name, $h, [switch]$Common) {
    # Etat d un fichier de taille $size et de nom $name, d empreintes connues $h (Crc, Md5, Sha1 ; vides si inconnues) :
    #  ok   officiel : meme taille et meme empreinte qu une entree (Entry : celle du meme nom s il y en a une) ;
    #  mod  modifie : aucune entree identique, mais une entree porte le meme nom de fichier (Entry) ;
    #  unk  inconnu : ni empreinte ni nom dans la liste ;
    #  wait empreinte a calculer (Need : Sha1, Md5 ou Crc, la plus forte que porte l entree de meme taille).
    # -Common : comparaison sur la plus forte des empreintes communes (entrees d archive ZIP, Get-LibDatCompare)
    # FIX4C (relecture finale du lot 4 : 2 738 entrees SPS de 1 049 612 octets, 27 ms par appel) : sans empreinte connue,
    # toutes les entrees de cette taille sont a calculer, la premiere donne Need. Sinon, seules sont comparees les entrees
    # qui ont la meme valeur pour une empreinte connue du fichier (index ByHash), ou aucune de ses empreintes connues : les
    # autres different sur une empreinte connue des deux cotes (Get-LibDatCompare : $false). Rang Ord de la liste garde :
    # meme resultat (Entry, Need) que la comparaison de toutes les entrees de cette taille
    $leaf = ([string]$name) -replace '^.*[\\/]', ''
    if ($null -eq $h) { $h = @{} }
    $cands = $null
    if ($dat.BySize.TryGetValue($size, [ref]$cands) -and $cands.Count -gt 0) {
        $hc = [string]$h.Crc; $hm = [string]$h.Md5; $hs = [string]$h.Sha1
        if (-not $hc -and -not $hm -and -not $hs) {
            $e = $cands[0]
            return @{ State = 'wait'; Need = $(if ($e.Sha1) { 'Sha1' } elseif ($e.Md5) { 'Md5' } else { 'Crc' }) }
        }
        if ($null -ne $dat.ByHash) {
            $parts = [System.Collections.Generic.List[object]]::new()
            $miss = $null; $noMiss = $false; $l = $null
            foreach ($p in @(@('C', $hc), @('M', $hm), @('S', $hs))) {
                if (-not $p[1]) { continue }
                if ($dat.ByHash.TryGetValue("$size|$($p[0])|$($p[1])", [ref]$l)) { $parts.Add($l) }
                # Entrees sans aucune des empreintes connues : la plus courte des listes « sans cette empreinte », filtree
                if ($dat.ByHash.TryGetValue("$size|$($p[0])|", [ref]$l)) { if (-not $noMiss -and ($null -eq $miss -or $l.Count -lt $miss.Count)) { $miss = $l } }
                else { $noMiss = $true; $miss = $null }
            }
            if ($null -ne $miss) {
                $none = [System.Collections.Generic.List[object]]::new()
                foreach ($e in $miss) { if ((-not $hc -or -not $e.Crc) -and (-not $hm -or -not $e.Md5) -and (-not $hs -or -not $e.Sha1)) { $none.Add($e) } }
                if ($none.Count -gt 0) { $parts.Add($none) }
            }
            if ($parts.Count -eq 1) { $cands = $parts[0] }
            else {
                $sd = [System.Collections.Generic.SortedDictionary[int, object]]::new()
                foreach ($pl in $parts) { foreach ($e in $pl) { $sd[[int]$e.Ord] = $e } }
                $cands = $sd.Values
            }
        }
        $hit = $null; $need = ''
        foreach ($e in $cands) {
            $m = Get-LibDatCompare $e $h ([bool]$Common)
            if ($null -eq $m) {
                if (-not $need) { $need = if ($e.Sha1) { 'Sha1' } elseif ($e.Md5) { 'Md5' } else { 'Crc' } }
                continue
            }
            if ($m -and (-not $hit -or ($e.Name -ieq $leaf -and $hit.Name -ine $leaf))) { $hit = $e }
        }
        if ($hit) { return @{ State = 'ok'; Entry = $hit } }
        if ($need) { return @{ State = 'wait'; Need = $need } }
    }
    $named = $null
    if ($leaf -and $dat.ByName.TryGetValue($leaf, [ref]$named)) { return @{ State = 'mod'; Entry = $named[0] } }
    return @{ State = 'unk' }
}

function Get-LibFileCrc32([string]$path) {
    # CRC-32 d un fichier entier, lu en flux et calcule par la bibliotheque ZIP native de .NET (Get-Crc32), sans calcul
    # en PowerShell : 8 chiffres hexadecimaux en majuscules
    $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try { return ('{0:X8}' -f (Get-Crc32 -Stream $fs)) } finally { $fs.Dispose() }
}

function Get-LibHashText([string]$algo, [System.IO.Stream]$stream) {
    # SHA-1 ou MD5 d un flux, par la cryptographie .NET (deja utilisee par l index), en hexadecimal minuscule
    $ha = if ($algo -eq 'Sha1') { [System.Security.Cryptography.SHA1]::Create() } else { [System.Security.Cryptography.MD5]::Create() }
    try { return ([BitConverter]::ToString($ha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant()) } finally { $ha.Dispose() }
}

function ConvertFrom-LibZipDir([byte[]]$cd, [int]$count) {
    # Entrees du repertoire central d une archive ZIP (signature 0x02014B50), dans l ordre de ZipArchive.Entries : nom
    # (UTF-8 si le bit 11 est mis, sinon page de codes 437), CRC-32, tailles, dossier ; $null si le repertoire est tronque
    if (-not $script:LibZipEnc) {
        try { $script:LibZipEnc = [System.Text.Encoding]::GetEncoding(437) } catch { $script:LibZipEnc = [System.Text.Encoding]::GetEncoding(28591) }
    }
    $out = [System.Collections.Generic.List[object]]::new()
    $p = 0
    for ($k = 0; $k -lt $count; $k++) {
        if ($p + 46 -gt $cd.Length -or [BitConverter]::ToUInt32($cd, $p) -ne 0x02014B50) { return $null }
        $flags = [BitConverter]::ToUInt16($cd, $p + 8)
        $nl = [BitConverter]::ToUInt16($cd, $p + 28); $xl = [BitConverter]::ToUInt16($cd, $p + 30); $cl = [BitConverter]::ToUInt16($cd, $p + 32)
        if ($p + 46 + $nl -gt $cd.Length) { return $null }
        $enc = if ($flags -band 0x800) { [System.Text.Encoding]::UTF8 } else { $script:LibZipEnc }
        $nm = $enc.GetString($cd, $p + 46, $nl)
        $out.Add(@{ Name = $nm; Crc = ('{0:X8}' -f [BitConverter]::ToUInt32($cd, $p + 16)); CSize = [long][BitConverter]::ToUInt32($cd, $p + 20)
                    Size = [long][BitConverter]::ToUInt32($cd, $p + 24); Dir = $nm.EndsWith('/'); Index = $k })
        $p += 46 + $nl + $xl + $cl
    }
    return ,$out
}

function Read-LibZipDir([string]$path) {
    # Repertoire central d une archive ZIP, sans decompression : fin d archive (0x06054B50, commentaire compris) cherchee
    # dans les 65 557 derniers octets, puis repertoire lu d un bloc. $null si illisible ou ZIP64 (non pris en charge)
    $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $len = $fs.Length
        if ($len -lt 22) { return $null }
        $tl = [int][math]::Min($len, 65557)
        $tail = New-Object byte[] $tl
        [void]$fs.Seek($len - $tl, [System.IO.SeekOrigin]::Begin)
        $got = 0
        while ($got -lt $tl) { $k = $fs.Read($tail, $got, $tl - $got); if ($k -le 0) { break }; $got += $k }
        if ($got -lt $tl) { return $null }
        $at = -1
        for ($i = $tl - 22; $i -ge 0; $i--) {
            if ($tail[$i] -eq 0x50 -and $tail[$i + 1] -eq 0x4B -and $tail[$i + 2] -eq 5 -and $tail[$i + 3] -eq 6 -and [BitConverter]::ToUInt16($tail, $i + 20) -eq $tl - $i - 22) { $at = $i; break }
        }
        if ($at -lt 0) { return $null }
        $n = [int][BitConverter]::ToUInt16($tail, $at + 10)
        $cdSize = [long][BitConverter]::ToUInt32($tail, $at + 12); $cdOff = [long][BitConverter]::ToUInt32($tail, $at + 16)
        if ($n -eq 0xFFFF -or $cdOff -eq 0xFFFFFFFFL -or $cdSize -gt 64MB -or $cdOff + $cdSize -gt $len) { return $null }
        $cd = New-Object byte[] $cdSize
        [void]$fs.Seek($cdOff, [System.IO.SeekOrigin]::Begin)
        $got = 0
        while ($got -lt $cdSize) { $k = $fs.Read($cd, $got, [int]($cdSize - $got)); if ($k -le 0) { break }; $got += $k }
        if ($got -lt $cdSize) { return $null }
        # FIX4B (revue du lot 4, C1) : liste rendue telle quelle (virgule). « return (liste) » la deroulait : avec une seule
        # entree, l appelant recevait la table de l entree au lieu d une liste (entree d un ZIP TOSEC dite « inconnu »)
        $ents = ConvertFrom-LibZipDir $cd $n
        if ($null -eq $ents) { return $null }
        return ,$ents
    } finally { $fs.Dispose() }
}

function Test-LibZipEntryData([string]$zipPath, $idx, [string]$entry, [string]$file) {
    # FIX4B (revue du lot 4, C3) : entree $entry (rang $idx) extraite dans $file, comparee au repertoire central de
    # l archive (taille et CRC-32) : ZipArchive ne controle pas les donnees decompressees. CRC-32 du fichier extrait par la
    # bibliotheque ZIP native de .NET (Get-LibFileCrc32). @{ Ok ; Want ; Got } ; $null si le controle est impossible
    # (archive illisible ou ZIP64, entree introuvable, fichier absent ou de plus de 256 Mo)
    $dir = Read-LibZipDir $zipPath
    if ($null -eq $dir) { return $null }
    $e = $null
    # Rang dans ZipArchive.Entries = rang dans le repertoire central (lot 4b) ; sinon le nom
    if ($null -ne $idx -and [int]$idx -ge 0 -and [int]$idx -lt $dir.Count -and -not $dir[[int]$idx].Dir) { $e = $dir[[int]$idx] }
    else { foreach ($d in $dir) { if (-not $d.Dir -and $d.Name -ceq $entry) { $e = $d; break } } }
    if (-not $e) { return $null }
    $fi = New-Object System.IO.FileInfo($file)
    if (-not $fi.Exists -or $fi.Length -gt 256MB) { return $null }
    $got = Get-LibFileCrc32 $file
    return @{ Ok = ($fi.Length -eq [long]$e.Size -and $got -eq $e.Crc); Want = $e.Crc; Got = $got; Size = $fi.Length; WantSize = [long]$e.Size }
}

function Get-LibZipDatState($dat, $entries) {
    # Archive ZIP : etat de chaque entree image (taille et CRC-32 du repertoire central), puis de l archive : officiel si
    # toutes ses images le sont ; modifie si une partie seulement l est, ou si une image est modifiee ; inconnu sinon.
    # Entree dont l empreinte manque (liste sans CRC-32) : State wait (a calculer sur le flux decompresse)
    $res = [System.Collections.Generic.List[object]]::new()
    foreach ($e in $entries) {
        if ($e.Dir -or (Get-FileKind ($e.Name -replace '^.*/', '')) -ne 'image') { $res.Add($null); continue }
        $res.Add((Get-LibDatMatch $dat ([long]$e.Size) $e.Name @{ Crc = $e.Crc } -Common))
    }
    return (Measure-LibZipDatState $res)
}

function Measure-LibZipDatState($res) {
    # Etat d une archive d apres l etat de ses entrees image ($null : entree hors images)
    $ok = 0; $mod = 0; $tot = 0; $wait = 0
    foreach ($s in $res) {
        if (-not $s) { continue }
        $tot++
        switch ($s.State) { 'ok' { $ok++ } 'mod' { $mod++ } 'wait' { $wait++ } }
    }
    $st = if ($wait -gt 0) { 'wait' } elseif ($tot -gt 0 -and $ok -eq $tot) { 'ok' } elseif ($ok -gt 0 -or $mod -gt 0) { 'mod' } else { 'unk' }
    return @{ State = $st; OkCount = $ok; Total = $tot; Entries = $res }
}

function Get-LibHashFile([string]$root) {
    # Cache des empreintes d une racine : hash-<16 premiers chiffres du MD5 du chemin>.tsv, a cote de l index
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try { $h = [BitConverter]::ToString($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($root.TrimEnd('\').ToLowerInvariant()))).Replace('-', '').Substring(0, 16) }
    finally { $md5.Dispose() }
    return (Join-Path $script:IndexDir "hash-$h.tsv")
}

function Get-LibHashKey([string]$path, [long]$size, [long]$ticks) { return ($path.ToLowerInvariant() + '|' + $size + '|' + $ticks) }

function Import-LibHashCache([string]$file) {
    # Empreintes gardees : lignes « chemin, taille, date de modification (ticks UTC), CRC-32, MD5, SHA-1 » separees par
    # des tabulations ; une ligne plus recente complete la precedente. Fichier absent ou illisible : cache vide
    $c = [System.Collections.Generic.Dictionary[string, object]]::new()
    try {
        if (-not [System.IO.File]::Exists($file)) { return ,$c }
        foreach ($ln in [System.IO.File]::ReadAllLines($file, [System.Text.Encoding]::UTF8)) {
            if (-not $ln -or $ln.StartsWith('#')) { continue }
            $f = $ln.Split("`t")
            if ($f.Count -lt 6) { continue }
            [long]$sz = 0; [long]$tk = 0
            if (-not [long]::TryParse($f[1], [ref]$sz) -or -not [long]::TryParse($f[2], [ref]$tk)) { continue }
            $k = Get-LibHashKey $f[0] $sz $tk
            $o = $null
            if (-not $c.TryGetValue($k, [ref]$o)) { $o = @{ Crc = ''; Md5 = ''; Sha1 = '' }; $c[$k] = $o }
            if ($f[3] -match '^[0-9A-F]{8}$') { $o.Crc = $f[3] }
            if ($f[4] -match '^[0-9a-f]{32}$') { $o.Md5 = $f[4] }
            if ($f[5] -match '^[0-9a-f]{40}$') { $o.Sha1 = $f[5] }
        }
    } catch { }
    return ,$c
}

function Add-LibHashLine([string]$file, [string]$path, [long]$size, [long]$ticks, $h) {
    # Ajout d une ligne au cache des empreintes (cree avec son en-tete) ; erreur d ecriture ignoree (cache facultatif)
    try {
        $dir = [System.IO.Path]::GetDirectoryName($file)
        if (-not [System.IO.Directory]::Exists($dir)) { [void][System.IO.Directory]::CreateDirectory($dir) }
        $new = -not [System.IO.File]::Exists($file)
        $line = "$path`t$size`t$ticks`t$($h.Crc)`t$($h.Md5)`t$($h.Sha1)"
        if ($new) { $line = "#GWHASH1`tchemin`ttaille`tticks`tcrc32`tmd5`tsha1`r`n" + $line }
        [System.IO.File]::AppendAllText($file, $line + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}
