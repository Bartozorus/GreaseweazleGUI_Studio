# ============================== FONCTIONS : BIBLIOTHEQUE, ANALYSE (12.8, LOT 4A) ==
# Analyse sans interface des fichiers de la Bibliotheque (A3 § 3 et § 4.2, D18) : noms TOSEC et No-Intro avec replis,
# bloc INFO des IPF (108 premiers octets, CRC-32 IEEE par la bibliotheque ZIP de .NET, A5 § 3.3), blocs de demarrage
# et racine des ADF, disquettes manquantes d un jeu, regle des mots de la recherche. Aucune liste embarquee, aucun
# telechargement : « IPF de structure SPS » se lit dans le fichier, « officiel » est reserve a une correspondance avec une
# DAT locale (lot 4b).

function Initialize-LibRx {
    # Expressions du decoupage des noms, creees une fois (sensibles a la casse sauf (?i))
    $script:LibRx = @{
        Tok       = [regex]'\(([^()]*)\)|\[([^\[\]]*)\]'
        NonAlnum  = [regex]'[^\p{L}\p{N}]+'
        Ver       = [regex]'(?i)\s+(v\d[\w.\-]*(?:\s+rev\s+[\w.\-]+)?|rev\s+[\w.\-]+|r\d+[a-z]?)$'
        Disk      = [regex]'(?i)^(?:dis[kc]|disque|disquette|side|face)\s*([0-9]{1,3}|[a-z])(?:\s*(?:of|sur|/)\s*(?:([0-9]{1,3})|[a-z?]))?(?:\s+side\s+([ab]))?$'
        DiskFb    = [regex]'(?i)(?:^|[\s_\-.,]+)(?:amiga)?(?:diskette|dis[kc]o?|disque|disquette)\s*[-_#]?\s*([0-9]{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|viii|vii|vi|iv|ix|iii|ii|i|v|x|[a-h])(?:\s*(?:of|sur|de|von)\s*([0-9]{1,2}))?(?=$|[\s_\-.,])'
        DiskCamel = [regex]'(?<=[a-z0-9])(?:Amiga)?(?:Diskette|Dis[kc]o?)([0-9]{1,2}|One|Two|Three|Four|Five|Six|Seven|Eight|Nine|Ten|VIII|VII|VI|IV|IX|III|II|I|V|X|[A-H])(?:(?:of|von)([0-9]{1,2}))?$'
        DiskU     = [regex]'[_\-\s]+([0-9]{1,2})$'
        DiskWord  = @{ one = '1'; two = '2'; three = '3'; four = '4'; five = '5'; six = '6'; seven = '7'; eight = '8'; nine = '9'; ten = '10'
                      i = '1'; ii = '2'; iii = '3'; iv = '4'; v = '5'; vi = '6'; vii = '7'; viii = '8'; ix = '9'; x = '10' }
        DiskD     = [regex]'(?i)(?:^|[\s_\-.]+)d([0-9]{1,2})$'
        Date      = [regex]'^(1[89]|20)[0-9x]{2}(-[0-9x]{2}){0,2}$'
        LangT     = [regex]'^[a-z]{2}(-[a-z]{2})*$'
        LangM     = [regex]'^M\d{1,2}$'
        LangN     = [regex]'^[A-Z][a-z](,\s?[A-Z][a-z])*$'
        Country   = [regex]'^[A-Z]{2}(-[A-Z]{2})*$'
        Region    = [regex]'^(World|Europe|USA|Japan|Germany|France|Italy|Spain|UK|Australia|Asia|Korea|Brazil|Canada|Netherlands|Sweden|Scandinavia|Russia|China)(,\s*(World|Europe|USA|Japan|Germany|France|Italy|Spain|UK|Australia|Asia|Korea|Brazil|Canada|Netherlands|Sweden|Scandinavia|Russia|China))*$'
        VerTok    = [regex]'(?i)^(v\d[\w.\-]*|rev\s*[\w.\-]+)$'
        Copy      = [regex]'^(CW|CW-R|FW|GW|GW-R|LW|PD|SW|SW-R)$'
        Flag      = [regex]'^(cr|tr|f|h|m|p|t|o|u|v|b|a)(\d*)(?:\s+(.*))?$'
        SpsNo     = [regex]'^\d{4}$'
        Article   = [regex]'(?i)^(.*?),\s*(the|a|an|le|la|les|l''|der|die|das|el|il)$'
        Trim      = [regex]'[\s\-_,.]+$'
        # FIX4B (revue du lot 4, C2) : crochets d information gardes dans la cle de jeu (machine, densite, video : communs a
        # tout le jeu) ; les autres ([bootable], [WB], [docs], [KS2.0]...) sont propres a une disquette
        SetTag    = [regex]'(?i)^(AGA|ECS|OCS|HD|CD32|CDTV|NTSC|PAL)$'
    }
    # Langue par defaut d un pays (TOSEC : la langue n est indiquee que si elle differe de celle du pays) ou d une region
    $script:LibCountryLang = @{
        AU = 'en'; BR = 'pt'; CA = 'en'; CN = 'zh'; DE = 'de'; DK = 'da'; ES = 'es'; FI = 'fi'; FR = 'fr'; GB = 'en'; GR = 'el'
        IT = 'it'; JP = 'ja'; KR = 'ko'; NL = 'nl'; NO = 'no'; PL = 'pl'; PT = 'pt'; RU = 'ru'; SE = 'sv'; US = 'en'
        USA = 'en'; UK = 'en'; Australia = 'en'; Germany = 'de'; France = 'fr'; Italy = 'it'; Spain = 'es'; Japan = 'ja'
        Netherlands = 'nl'; Sweden = 'sv'; Brazil = 'pt'; Korea = 'ko'; China = 'zh'; Russia = 'ru'; Canada = 'en'
    }
    return $script:LibRx
}

function Get-LibCompact([string]$s) {
    # Forme compacte d un texte, pour comparer titres et mots : minuscules, sans accents, sans ponctuation ni espaces
    if (-not $s) { return '' }
    $rx = $script:LibRx; if (-not $rx) { $rx = Initialize-LibRx }
    return $rx.NonAlnum.Replace($s.Normalize([System.Text.NormalizationForm]::FormD), '').ToLowerInvariant()
}

function Read-LibNameParts([string]$s, $rx) {
    # Decoupe TOSEC / No-Intro : titre (texte avant la premiere parenthese ou le premier crochet ; crochets de tete, comme
    # [BIOS] ou un numero de publication, ecartes), jetons dans l ordre (p : parentheses, b : crochets), texte restant
    $lead = $null; $rest = ''; $pos = 0
    $toks = [System.Collections.Generic.List[object]]::new()
    foreach ($m in $rx.Tok.Matches($s)) {
        $between = $s.Substring($pos, $m.Index - $pos)
        if ($null -eq $lead) {
            if ($between.Trim().Length -eq 0 -and $m.Groups[2].Success) {
                $toks.Add(@('b', $m.Groups[2].Value.Trim())); $pos = $m.Index + $m.Length; continue
            }
            $lead = $between
        } elseif ($between.Trim()) { $rest = ($rest + ' ' + $between.Trim()).Trim() }
        if ($m.Groups[1].Success) { $toks.Add(@('p', $m.Groups[1].Value.Trim())) } else { $toks.Add(@('b', $m.Groups[2].Value.Trim())) }
        $pos = $m.Index + $m.Length
    }
    $tail = $s.Substring($pos)
    if ($null -eq $lead) { $lead = $tail; $tail = '' }
    elseif ($tail.Trim()) { $rest = ($rest + ' ' + $tail.Trim()).Trim() }
    return @{ Lead = $lead.Trim(); Toks = $toks; Rest = $rest }
}

function Find-LibDiskInLead([string]$lead, $rx) {
    # Repli hors convention : numero de disquette en fin de nom (« Jeu - Disk1 », « jeu_d2 », « WizNLiz_Disk1 »,
    # « Jinks_Disk1of2 », « ChampionshipManager93_AmigaDisk1 »). Renvoie le titre sans la disquette, le numero et le total
    foreach ($r in @($rx.DiskFb, $rx.DiskCamel, $rx.DiskD)) {
        $m = $r.Match($lead)
        if (-not $m.Success) { continue }
        $tot = 0; if ($m.Groups.Count -gt 2 -and $m.Groups[2].Success) { $tot = [int]$m.Groups[2].Value }
        $dk = $m.Groups[1].Value; $w = $rx.DiskWord[$dk.ToLowerInvariant()]
        if ($w) { $dk = $w }
        return @{ Title = $lead.Substring(0, $m.Index); Disk = $dk; Tot = $tot }
    }
    return $null
}

function Get-LibNameInfo([string]$name, [string]$dirName = '') {
    # Analyse d un nom de fichier de la Bibliotheque (TOSEC v4, No-Intro, replis hors convention) :
    #  Title (titre court), Key (cle du groupe : titre compact, article final remis en tete), Version, Date, Publisher,
    #  DiskNo / DiskTot / Disk (disquette n sur N, lettre A = 1), DiskLetter, Label (label de media TOSEC), Langs (« en-fr »,
    #  « M3 » ; langue du pays a defaut), LangList, Country, Flags (codes TOSEC : cr, t, !...), FlagText, State (bad : [b] [o]
    #  [u] [v] ; mod : [cr] [f] [h] [m] [p] [t] [tr] ; ok : [!]), Variant (date, editeur, pays, statut, autres mentions),
    #  Sps (numero de publication entre crochets d un dossier SPS), Source (file, ou dir : IPF SPS au nom sans parentheses,
    #  dont le dossier de publication porte le nom TOSEC), Prefix (debut du nom, pour retrouver les autres disquettes),
    #  SetKey (jeu de disquettes : meme nom sans la disquette, ni les mentions [cr] [a]..., ni les crochets d information
    #  propres a une disquette comme [bootable] ou [WB] ; SetVariant : la variante ainsi reduite), Base (nom sans extension),
    #  Modified (mention de copie modifiee), SortKey (titre compact, ordre des groupes)
    $rx = $script:LibRx; if (-not $rx) { $rx = Initialize-LibRx }
    $base = $name; $ext = ''
    $i = $name.LastIndexOf('.')
    if ($i -gt 0 -and $name.Length - $i -le 6) {
        $e = $name.Substring($i)
        if ($e -match '^\.[A-Za-z0-9]{1,5}$' -and $e -notmatch '^\.\d+$') { $ext = $e.ToLowerInvariant(); $base = $name.Substring(0, $i) }
    }
    $fp = Read-LibNameParts $base $rx
    $parts = $fp; $src = 'file'; $fbDisk = $null
    if ($fp.Toks.Count -eq 0) { $fbDisk = Find-LibDiskInLead $fp.Lead $rx }
    # IPF des publications SPS : « WizNLiz_Disk1.ipf » dans « Wiz 'n' Liz (1993)(Psygnosis)[0749] » ; le dossier n est pris
    # que si son titre est celui du fichier (formes compactes egales, ou l une debut de l autre sur 4 caracteres au moins,
    # ou titre du fichier de 8 caracteres au moins contenu dans celui du dossier ; & lu « and ») ; numero final « _1 » admis
    if ($dirName -and $fp.Toks.Count -eq 0 -and $dirName.IndexOf('(') -ge 0) {
        $dp = Read-LibNameParts $dirName $rx
        if ($dp.Toks.Count -gt 0 -and $dp.Lead) {
            $ft = if ($fbDisk) { $fbDisk.Title } else { $fp.Lead }
            $dt = $dp.Lead; $mv = $rx.Ver.Match($dt); if ($mv.Success) { $dt = $dt.Substring(0, $mv.Index) }
            $b = Get-LibCompact ($dt -replace '&', 'and')
            $cand = @(@{ T = $ft; D = $fbDisk })
            if (-not $fbDisk) { $mu = $rx.DiskU.Match($fp.Lead); if ($mu.Success) { $cand += @{ T = $fp.Lead.Substring(0, $mu.Index); D = @{ Title = $fp.Lead.Substring(0, $mu.Index); Disk = $mu.Groups[1].Value; Tot = 0 } } } }
            foreach ($c in $cand) {
                $a = Get-LibCompact ($c.T -replace '&', 'and')
                if ($a.Length -lt 2 -or $b.Length -lt 2) { continue }
                $short = [math]::Min($a.Length, $b.Length)
                if ($a -eq $b -or ($short -ge 4 -and ($a.StartsWith($b) -or $b.StartsWith($a))) -or ($a.Length -ge 8 -and $b.Contains($a))) {
                    $parts = $dp; $src = 'dir'; $fbDisk = $c.D; break
                }
            }
        }
    }
    $lead = $parts.Lead
    $ver = ''
    $mv = $rx.Ver.Match($lead); if ($mv.Success) { $ver = $mv.Groups[1].Value; $lead = $lead.Substring(0, $mv.Index) }
    $diskNo = 0; $diskTot = 0; $disk = ''; $letter = $false; $label = ''
    $date = ''; $pub = ''; $multi = ''; $country = ''; $sps = ''
    $langs = [System.Collections.Generic.List[string]]::new()
    $flags = [System.Collections.Generic.List[string]]::new()
    $flagText = [System.Collections.Generic.List[string]]::new()
    $var = [System.Collections.Generic.List[string]]::new()
    $afterDate = $false; $afterDisk = $false
    foreach ($t in $parts.Toks) {
        $k = $t[0]; $x = $t[1]
        if ($k -eq 'b') {
            $afterDate = $false; $afterDisk = $false
            if ($x -eq '!') { $flags.Add('!'); $flagText.Add('[!]'); continue }
            $mf = $rx.Flag.Match($x)
            if ($mf.Success) { $flags.Add($mf.Groups[1].Value); $flagText.Add("[$x]"); continue }
            if ($rx.SpsNo.IsMatch($x)) { $sps = $x; continue }
            $var.Add("[$x]"); continue
        }
        if ($afterDate) { $pub = $x; $afterDate = $false; $var.Add("($x)"); continue }
        if (-not $disk) {
            $md = $rx.Disk.Match($x)
            if ($md.Success) {
                $disk = $md.Groups[1].Value.ToUpperInvariant()
                if ($md.Groups[2].Success) { $diskTot = [int]$md.Groups[2].Value }
                if ($md.Groups[3].Success) { $disk = $disk + $md.Groups[3].Value.ToUpperInvariant() }
                $afterDisk = $true; continue
            }
        }
        $wasDisk = $afterDisk; $afterDisk = $false
        if (-not $date -and $rx.Date.IsMatch($x)) { $date = $x; $afterDate = $true; $var.Add("($x)"); continue }
        if ($rx.LangT.IsMatch($x)) { foreach ($l in $x.Split('-')) { $langs.Add($l) }; continue }
        if ($rx.LangM.IsMatch($x)) { $multi = $x; continue }
        if ($rx.LangN.IsMatch($x)) { foreach ($l in ($x -split ',\s?')) { $langs.Add($l.ToLowerInvariant()) }; continue }
        if ($rx.Copy.IsMatch($x)) { $var.Add("($x)"); continue }
        if ($rx.Country.IsMatch($x) -or $rx.Region.IsMatch($x)) { $country = $x; $var.Add("($x)"); continue }
        if ($rx.VerTok.IsMatch($x)) { if (-not $ver) { $ver = $x }; continue }
        # Label de media TOSEC : la parenthese qui suit la disquette (« (Disk 1 of 4)(Workbench) »), propre a chaque disquette
        if ($wasDisk) { $label = $x; continue }
        $var.Add("($x)")
    }
    # Disquette hors convention : dans le nom du fichier (meme quand le reste vient du dossier de publication)
    if (-not $disk -and $fbDisk) {
        $disk = $fbDisk.Disk.ToUpperInvariant(); $diskTot = $fbDisk.Tot
        if ($src -eq 'file') { $lead = $fbDisk.Title }
    }
    if ($disk) {
        if ($disk -match '^(\d+)') { $diskNo = [int]$Matches[1] }
        elseif ($disk -match '^[A-Z]') { $diskNo = [int][char]$disk[0] - 64; $letter = $true }
    }
    $title = $rx.Trim.Replace($lead, '').Trim()
    if (-not $title) { $title = $base }
    $kt = $title; $ma = $rx.Article.Match($kt)
    if ($ma.Success) { $kt = $ma.Groups[2].Value + ' ' + $ma.Groups[1].Value }
    $key = Get-LibCompact $kt
    if (-not $key) { $key = $base.ToLowerInvariant() }
    # Langues : indiquees, sinon celle du pays ou de la region (« (DE) » : de) ; « M3 » : trois langues, non detaillees
    $derived = $false
    if ($langs.Count -eq 0 -and -not $multi -and $country) {
        foreach ($c in ($country -split '[-,]\s*')) { $l = $script:LibCountryLang[$c]; if ($l -and -not $langs.Contains($l)) { $langs.Add($l); $derived = $true } }
    }
    $langText = if ($langs.Count -gt 0) { $langs -join '-' } else { $multi }
    $state = ''; $modified = $false
    foreach ($f in $flags) {
        if ($f -eq 'b' -or $f -eq 'o' -or $f -eq 'u' -or $f -eq 'v') { $state = 'bad' }
        elseif ($f -eq 'cr' -or $f -eq 'f' -or $f -eq 'h' -or $f -eq 'm' -or $f -eq 'p' -or $f -eq 't' -or $f -eq 'tr') { $modified = $true }
    }
    if (-not $state -and $modified) { $state = 'mod' }
    if (-not $state -and $flags.Contains('!')) { $state = 'ok' }
    $varText = $var -join ''
    # FIX4B (C2) : variante du jeu, sans les crochets d information propres a une disquette ([bootable], [WB]...) : cle de
    # jeu et ordre des lignes (sinon « (Disk 1 of 2)[WB] » et « (Disk 2 of 2) » formaient deux jeux incomplets)
    $setVar = $varText
    if ($varText.IndexOf('[') -ge 0) {
        $sv = [System.Collections.Generic.List[string]]::new()
        foreach ($v in $var) { if (-not $v.StartsWith('[') -or $rx.SetTag.IsMatch($v.Substring(1, $v.Length - 2))) { $sv.Add($v) } }
        $setVar = $sv -join ''
    }
    # Debut du nom de fichier, pour retrouver les autres disquettes du jeu dans le dossier (motif « prefixe* »)
    $prefix = if ($src -eq 'dir') { '' } elseif ($fp.Toks.Count -eq 0 -and $fbDisk) { $rx.Trim.Replace($fbDisk.Title, '') } else { $rx.Trim.Replace($fp.Lead, '') }
    $setKey = "$key|$($ver.ToLowerInvariant())|$($setVar.ToLowerInvariant())|$langText|$ext"
    return @{
        Title = $title; Key = $key; Version = $ver; Date = $date; Publisher = $pub; Disk = $disk; DiskNo = $diskNo; DiskTot = $diskTot
        DiskLetter = $letter; Label = $label; Langs = $langText; LangList = @($langs); LangDerived = $derived; Multi = $multi; Country = $country
        Flags = @($flags); FlagText = ($flagText -join ' '); State = $state; Modified = $modified; Variant = $varText; SetVariant = $setVar; Sps = $sps; Source = $src
        Prefix = $prefix; SetKey = $setKey; Base = $base; Ext = $ext; Rest = $parts.Rest; SortKey = (Get-LibCompact $title)
    }
}

function Get-LibDiskText($info) {
    # Disquette pour la colonne « Disq. » : « 2/4 », « 2 », « B »
    if (-not $info.Disk) { return '' }
    if ($info.DiskTot -gt 0) { return "$($info.Disk)/$($info.DiskTot)" }
    return $info.Disk
}

function Get-LibMissingDisks($sets) {
    # Disquettes absentes de jeux a plusieurs disquettes. $sets : SetKey -> liste de @{ DiskNo ; DiskTot ; Letter }.
    # Total annonce (« Disk x of y ») : numeros absents de 1 a y ; sans total : trous entre 1 et le plus grand numero present.
    # Renvoie SetKey -> @{ Missing (numeros) ; Total ; Known (total annonce) ; Letter }
    $out = @{}
    foreach ($k in @($sets.Keys)) {
        $have = @{}; $tot = 0; $max = 0; $letter = $false
        foreach ($d in $sets[$k]) {
            $n = [int]$d.DiskNo; if ($n -le 0) { continue }
            $have[$n] = $true; if ($n -gt $max) { $max = $n }
            if ([int]$d.DiskTot -gt $tot) { $tot = [int]$d.DiskTot }
            if ($d.Letter) { $letter = $true }
        }
        if ($max -eq 0) { continue }
        $known = ($tot -gt 0); $n2 = if ($known) { $tot } else { $max }
        if ($n2 -lt 2 -or $n2 -gt 99) { continue }
        $miss = @(for ($j = 1; $j -le $n2; $j++) { if (-not $have.ContainsKey($j)) { $j } })
        if ($miss.Count -gt 0) { $out[$k] = @{ Missing = $miss; Total = $n2; Known = $known; Letter = $letter } }
    }
    return $out
}

function Format-LibDiskList($m) {
    # « 3, 7 » ; disquettes en lettres : « C, G »
    return (@($m.Missing | ForEach-Object { if ($m.Letter) { [string][char](64 + $_) } else { "$_" } }) -join ', ')
}

function Get-LibWordRx([string]$word, [bool]$inDirs) {
    # Expression d un mot de la recherche : ses lettres et chiffres dans l ordre, sans casse, separes au plus par des
    # caracteres qui ne sont ni lettres ni chiffres ; sans $inDirs, dans le nom du fichier seulement (aucune barre oblique
    # inverse apres le mot). Mot sans lettre ni chiffre : $null.
    # FIX4C (relecture finale du lot 4) : elle filtre le sur-ensemble de l index (FastIndex.Search, et Start-LibSearch en
    # repli : mot tel qu il est saisi, sous-chaine du chemin, casse ignoree). La ponctuation omise n est donc pas toleree
    # dans les faits : « kings » ne trouve pas « King's », « king's » ne trouve pas « KingsQuest » ; « king quest » trouve
    # les deux. Recherche sans ponctuation : FastIndex a modifier (12.9, avec une validation de securite, D19)
    # FIX4B (revue du lot 4, C5) : la forme compacte n a plus d accents ; le mot tel qu il est saisi est donc aussi accepte
    # (« Opération » trouve « Opération Stealth », comme en 12.7 : l index cherche le mot brut)
    $c = Get-LibCompact $word
    if (-not $c) { return $null }
    $sep = if ($inDirs) { '[^\p{L}\p{N}]*' } else { '[^\p{L}\p{N}\\]*' }
    $p = (@($c.ToCharArray() | ForEach-Object { [regex]::Escape([string]$_) }) -join $sep)
    $raw = $word.Trim()
    if ($raw -and $raw.ToLowerInvariant() -cne $c) { $p = '(?:' + $p + '|' + [regex]::Escape($raw) + ')' }
    if (-not $inDirs) { $p += '[^\\]*$' }
    return ('(?i)' + $p)
}

function Select-LibMatches([string[]]$rels, [string]$filter, [bool]$inDirs) {
    # 12.8 (A3 § 4.2 n° 8) : chemins relatifs dont le NOM de fichier contient chaque mot (le chemin complet avec $inDirs,
    # comme la 12.7), en ignorant la casse (ponctuation : voir Get-LibWordRx, FIX4C). Filtrage vectorise (operateur
    # -match sur le tableau : 50 000 chemins en moins de 0,1 s sous pwsh 7), ordre garde. $rels : sur-ensemble de l index
    # Affectation directe : un tableau d un seul element ne doit pas devenir une chaine (-match rendrait un booleen)
    [string[]]$cur = @(); if ($null -ne $rels) { $cur = [string[]]$rels }
    foreach ($w in @($filter.Split([char[]]@(' '), [System.StringSplitOptions]::RemoveEmptyEntries))) {
        $rx = Get-LibWordRx $w $inDirs
        if ($rx -and $cur.Count -gt 0) { $cur = [string[]]@($cur -match $rx) }
    }
    return ,$cur
}

function Get-Crc32([byte[]]$Data, [int]$Offset = 0, [int]$Count = -1, [System.IO.Stream]$Stream = $null) {
    # CRC-32 IEEE (celui de zlib, des archives ZIP et des enregistrements IPF, A5 § 3.3) calcule par la bibliotheque ZIP
    # native de .NET, sans aucun calcul en PowerShell (alertes EDR du 20/10/2026, decisions128) : les $Count octets de
    # $Data a partir de $Offset (ou le flux $Stream, lu jusqu a sa fin) vont dans l entree unique d une archive ZIP en
    # memoire, sans compression ; l archive fermee, le CRC est lu dans l en-tete du repertoire central (fin d archive
    # 0x06054B50 dans les 22 derniers octets, l archive n a pas de commentaire ; en-tete central 0x02014B50, CRC au
    # decalage 16, petit-boutiste). Tableau vide : 0. Nom de type qualifie par l assembly : System.IO.Compression n est
    # pas charge par l amorce (seulement System.IO.Compression.FileSystem) ; ce nom le charge depuis le GAC, sans Add-Type
    if ($Count -lt 0) { $Count = $(if ($null -ne $Data) { $Data.Length - $Offset } else { 0 }) }
    $cap = $(if ($Stream -and $Stream.CanSeek) { [int][math]::Min([long]$Stream.Length + 4096, [int]::MaxValue) } else { $Count + 4096 })
    $ms = New-Object System.IO.MemoryStream($cap)
    try {
        $za = [System.IO.Compression.ZipArchive, System.IO.Compression, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]::new($ms, 'Create', $true)
        try {
            $es = $za.CreateEntry('crc32', 'NoCompression').Open()
            try {
                if ($Stream) { $Stream.CopyTo($es, 65536) } elseif ($Count -gt 0) { $es.Write($Data, $Offset, $Count) }
            } finally { $es.Dispose() }
        } finally { $za.Dispose() }
        $b = $ms.GetBuffer(); $e = [int]$ms.Length - 22
        if ($e -lt 0 -or [BitConverter]::ToUInt32($b, $e) -ne 0x06054B50) { throw (T 'calcul du CRC-32 impossible') }
        $cd = [long][BitConverter]::ToUInt32($b, $e + 16)
        if ($cd + 46 -gt $e -or [BitConverter]::ToUInt32($b, [int]$cd) -ne 0x02014B50) { throw (T 'calcul du CRC-32 impossible') }
        return [long][BitConverter]::ToUInt32($b, [int]$cd + 16)
    } finally { $ms.Dispose() }
}

function Get-IpfInfoBlock([byte[]]$h) {
    # Enregistrements CAPS (12 octets) et INFO (96 octets) en tete d un IPF (A3 § 3.1, A5 § 3.2), valeurs big-endian.
    # Kind : sps (structure de publication SPS : CAPS puis INFO, CRC valides, encodeur 1 CAPS ou 2 SPS, fileKey different de
    # la marque de disk-analyse ; creatorId non teste, il vaut 0 dans les publications SPS, decisions128) ; user (IPF
    # utilisateur de disk-analyse, fileKey 0x843265BB) ; crc (CRC de CAPS ou d INFO faux) ; other (encodeur inconnu) ;
    # none (bloc INFO absent ou illisible). Le bloc INFO n est qu un indice d origine : « officiel » demande une DAT (D18)
    $r = @{ Kind = 'none'; CrcOk = $false; MediaType = 0; Encoder = 0; EncRev = 0; FileKey = 0; FileRev = 0; Origin = 0; MinTrack = 0; MaxTrack = 0
            MinSide = 0; MaxSide = 0; Date = 0; Time = 0; Platforms = @(); DiskNumber = 0; CreatorId = 0 }
    if (-not $h -or $h.Length -lt 108) { return $r }
    $asc = [System.Text.Encoding]::ASCII
    if ($asc.GetString($h, 0, 4) -ne 'CAPS' -or (Get-BE32 $h 4) -ne 12 -or $asc.GetString($h, 12, 4) -ne 'INFO' -or (Get-BE32 $h 16) -ne 96) { return $r }
    $r.MediaType = Get-BE32 $h 24; $r.Encoder = Get-BE32 $h 28; $r.EncRev = Get-BE32 $h 32; $r.FileKey = Get-BE32 $h 36
    $r.FileRev = Get-BE32 $h 40; $r.Origin = Get-BE32 $h 44; $r.MinTrack = Get-BE32 $h 48; $r.MaxTrack = Get-BE32 $h 52
    $r.MinSide = Get-BE32 $h 56; $r.MaxSide = Get-BE32 $h 60; $r.Date = Get-BE32 $h 64; $r.Time = Get-BE32 $h 68
    $r.Platforms = @(foreach ($o in 72, 76, 80, 84) { $p = Get-BE32 $h $o; if ($p -ne 0) { $p } })
    $r.DiskNumber = Get-BE32 $h 88; $r.CreatorId = Get-BE32 $h 92
    # CRC de chaque enregistrement complet, champ CRC (octets 8 a 11 de l enregistrement) mis a zero
    $ok = $true
    foreach ($rec in @(@(0, 12), @(12, 96))) {
        $b = [byte[]]::new($rec[1])
        [Array]::Copy($h, $rec[0], $b, 0, $rec[1])
        $stored = Get-BE32 $b 8
        $b[8] = 0; $b[9] = 0; $b[10] = 0; $b[11] = 0
        if ((Get-Crc32 $b 0 $rec[1]) -ne $stored) { $ok = $false }
    }
    $r.CrcOk = $ok
    if (-not $ok) { $r.Kind = 'crc' }
    elseif ($r.FileKey -eq 0x843265BBL) { $r.Kind = 'user' }
    elseif ($r.Encoder -eq 1 -or $r.Encoder -eq 2) { $r.Kind = 'sps' }
    else { $r.Kind = 'other' }
    return $r
}

function Get-AdfInfo([byte[]]$boot, [byte[]]$root, [long]$size) {
    # ADF (A3 § 4.2 n° 4, A5 § 2) : bloc de demarrage (« DOS » et octet de type : bit 0 FFS, bit 1 INTL, bit 2 DIRCACHE ;
    # somme avec report sur 256 mots longs = 0xFFFFFFFF : amorcable) ; bloc racine 880 (DD, 81 a 83 cylindres compris) ou
    # 1760 (HD) : type 2 en 0, sous-type 1 en 508, somme nulle sur 128 mots longs ; nom du volume : longueur en 432, 30
    # caracteres au plus a partir de 433 (ISO-8859-1)
    $r = @{ Dos = $false; Fs = ''; Flags = -1; Intl = $false; DirCache = $false; Bootable = $false; BootRead = $false; RootOk = $false; Volume = ''; Hd = $false; RootBlock = 880 }
    $r.Hd = ($size -gt 0 -and $size % 22528 -eq 0 -and $size / 11264 -gt 84)
    if ($r.Hd) { $r.RootBlock = 1760 }
    if ($boot -and $boot.Length -ge 1024) {
        $r.BootRead = $true
        if ($boot[0] -eq 0x44 -and $boot[1] -eq 0x4F -and $boot[2] -eq 0x53 -and $boot[3] -le 7) {
            $r.Dos = $true; $f = [int]$boot[3]; $r.Flags = $f
            $r.Fs = if ($f -band 1) { 'FFS' } else { 'OFS' }
            $r.Intl = [bool]($f -band 2); $r.DirCache = [bool]($f -band 4)
            [long]$s = 0
            for ($o = 0; $o -lt 1024; $o += 4) {
                $s += Get-BE32 $boot $o
                if ($s -gt 0xFFFFFFFFL) { $s = ($s -band 0xFFFFFFFFL) + 1 }
            }
            $r.Bootable = ($s -eq 0xFFFFFFFFL)
        }
    }
    if ($root -and $root.Length -ge 512) {
        [long]$s = 0
        for ($o = 0; $o -lt 512; $o += 4) { $s = ($s + (Get-BE32 $root $o)) -band 0xFFFFFFFFL }
        if ((Get-BE32 $root 0) -eq 2 -and (Get-BE32 $root 508) -eq 1 -and $s -eq 0) {
            $r.RootOk = $true
            $n = [int]$root[432]; if ($n -gt 30) { $n = 30 }
            if ($n -gt 0) { $r.Volume = [System.Text.Encoding]::GetEncoding(28591).GetString($root, 433, $n) }
        }
    }
    return $r
}
