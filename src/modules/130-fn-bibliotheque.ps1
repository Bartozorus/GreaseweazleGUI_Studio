# ============================== FONCTIONS : BIBLIOTHEQUE =======================

function Start-LibWrite([string]$mode) {
    # Ecriture rapide ou lente de l image selectionnee : parametres de l onglet Ecriture appliques, calibration
    # automatique si elle manque pour la famille de l image, puis ecriture (onglet Ecriture affiche pour le suivi)
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    $sel = Resolve-LibSelection
    if (-not $sel) { return }
    if (-not $sel.IsImage) {
        # 12.8 (lot 4a) : message dans le journal et le panneau de details, plus de boite de message
        Show-LibNotice (T 'Ce fichier n''est pas un format image reconnu par gw.'); return
    }
    Append-Log ((T "Image sélectionnée : {0}") -f "$($sel.Path)")
    # 12.8 (D4) : prereglage en surcharge temporaire de l onglet Ecriture, retabli a la fin de l operation
    Enter-OpOverride 'library'
    Set-WritePreset $mode $sel.Path $sel.Source
    Update-PrecompForImage $sel.Path
    Show-Tab $tabW
    Start-PresetWrite $mode
    # Rien de lance (refus, calibration annulee, fichier introuvable) : fin tout de suite. Image secteur sans format :
    # Start-PresetWrite demande de le choisir dans l onglet Ecriture, le prereglage y reste (comme en 12.7)
    if (Test-OpIdle) {
        $needFmt = (Test-NeedsFormat $txtWFile.Text) -and -not ($cmbWFmt.Text -and $cmbWFmt.Text -ne '(auto)')
        Exit-OpOverride -Keep:$needFmt
    } elseif ($script:OpOverride) { $script:OpOverride.Started = $true }
}

function Set-LibWriteEnabled([bool]$on) { $btnLibFast.Enabled = $on; $btnLibSlow.Enabled = $on }

function Show-LibNotice([string]$text) {
    # 12.8 (lot 4a) : message de la Bibliotheque dans le journal et en tete du panneau de details (aucune boite de message)
    Append-Log ((T 'Bibliothèque : {0}') -f $text)
    $txtLibInfo.Text = $text + "`r`n`r`n" + $script:LibInfoBase
}

# ============================== BIBLIOTHEQUE : LOGIQUE =========================
function Format-Size([long]$bytes) {
    if ($bytes -ge 1048576) { return ((T '{0:N1} Mo') -f ($bytes / 1MB)) }
    if ($bytes -ge 1024)    { return ((T '{0:N0} Ko') -f ($bytes / 1KB)) }
    return ((T "{0} o") -f "$bytes")
}

function Get-FileKind([string]$name) {
    $e = [System.IO.Path]::GetExtension($name).ToLower()
    if ($e -eq '.zip')               { return 'zip' }
    if ($script:ImgExt -contains $e) { return 'image' }
    if ($script:DocExt -contains $e) { return 'doc' }
    return 'other'
}

function Get-KindPrefix([string]$kind) { return '' }   # remplace par les icones de l'arborescence

function Get-ZipEntries([string]$zipPath) {
    # Entrees d une archive (dossiers exclus) ; Index : rang dans l archive, celui du repertoire central (12.8, lot 4b)
    $out = @()
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            $ix = 0
            foreach ($e in $zip.Entries) {
                $ei = $ix; $ix++
                if ($e.FullName.EndsWith('/')) { continue }
                $out += [pscustomobject]@{ FullName = $e.FullName; Length = $e.Length; Kind = (Get-FileKind $e.Name); Index = $ei }
            }
        } finally { $zip.Dispose() }
    } catch {
        Append-Log ((T "ZIP illisible ({0}) : {1}") -f "$([System.IO.Path]::GetFileName($zipPath))", "$($_.Exception.Message)")
    }
    return $out
}

function New-LibNode([string]$text, $tagHash) {
    $n = New-Object System.Windows.Forms.TreeNode
    $n.Text = $text
    $n.Tag  = $tagHash
    $k = $tagHash.Kind
    if ($k -eq 'zipentry') { $k = $tagHash.FileKind }
    if (@('dir','zip','image','doc','other') -notcontains $k) { $k = 'blank' }
    $n.ImageKey = $k; $n.SelectedImageKey = $k
    return $n
}

function New-Placeholder { return (New-LibNode (T '(chargement...)') @{ Kind='placeholder' }) }

function Expand-LibNode($node) {
    if (-not $node -or -not $node.Tag) { return }
    if ($node.Nodes.Count -ne 1 -or $node.Nodes[0].Tag.Kind -ne 'placeholder') { return }

    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $treeLib.BeginUpdate()
    try {
        $node.Nodes.Clear()
        if ($node.Tag.Kind -eq 'dir') {
            Populate-LibDir $node
        } elseif ($node.Tag.Kind -eq 'zip') {
            $list = New-Object System.Collections.Generic.List[System.Windows.Forms.TreeNode]
            foreach ($e in (Get-ZipEntries $node.Tag.Path)) {
                if ($chkLibImgOnly.Checked -and $e.Kind -ne 'image') { continue }
                $list.Add((New-LibNode "$(Get-KindPrefix $e.Kind)$($e.FullName)  ($(Format-Size $e.Length))" `
                    @{ Kind='zipentry'; ZipPath=$node.Tag.Path; Entry=$e.FullName; Size=$e.Length; FileKind=$e.Kind; Idx=$e.Index }))
            }
            if ($list.Count -eq 0) { $list.Add((New-LibNode (T '(aucune image)') @{ Kind='none' })) }
            $node.Nodes.AddRange($list.ToArray())
        }
    } finally {
        $treeLib.EndUpdate()
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

function Populate-LibDir($node) {
    $path = $node.Tag.Path
    $list = New-Object System.Collections.Generic.List[System.Windows.Forms.TreeNode]
    try {
        foreach ($d in (Get-ChildItem -LiteralPath $path -Directory -ErrorAction Stop | Sort-Object Name)) {
            $sub = New-LibNode $d.Name @{ Kind='dir'; Path=$d.FullName }
            [void]$sub.Nodes.Add((New-Placeholder))
            $list.Add($sub)
        }
        foreach ($f in (Get-ChildItem -LiteralPath $path -File -ErrorAction Stop | Sort-Object Name)) {
            $kind = Get-FileKind $f.Name
            if ($chkLibImgOnly.Checked -and $kind -ne 'image' -and $kind -ne 'zip') { continue }
            $n = New-LibNode "$(Get-KindPrefix $kind)$($f.Name)  ($(Format-Size $f.Length))" @{ Kind=$kind; Path=$f.FullName; Size=$f.Length }
            if ($kind -eq 'zip') { [void]$n.Nodes.Add((New-Placeholder)) }
            $list.Add($n)
        }
    } catch {
        Append-Log ((T "Lecture impossible de {0} : {1}") -f "$path", "$($_.Exception.Message)")
    }
    if ($list.Count -gt 0) { $node.Nodes.AddRange($list.ToArray()) }
}

# --- Recherche asynchrone : s execute dans un runspace separe, l UI ne gele pas
function Stop-LibSearch {
    if ($script:LibPS) {
        try { $script:LibPS.Stop() } catch { }
        try { $script:LibPS.Dispose() } catch { }
    }
    $script:LibPS = $null
    $script:LibAsync = $null
}

function Start-LibSearch([string]$root, [string]$filter, [bool]$imgOnly) {
    # Recherche de repli (index rapide indisponible) : sur-ensemble, chaque mot dans le chemin relatif ; la regle des mots
    # (nom du fichier, ou chemin avec « Aussi dans les dossiers ») s applique a la fin (Complete-LibSearch), comme pour l index
    Stop-LibSearch
    if (-not $script:LibRunspace -or $script:LibRunspace.RunspaceStateInfo.State -ne 'Opened') {
        $script:LibRunspace = [runspacefactory]::CreateRunspace()
        $script:LibRunspace.Open()
    }
    $script:LibSearchFilter = $filter; $script:LibSearchInDirs = [bool]$chkLibInDirs.Checked
    $ps = [powershell]::Create()
    $ps.Runspace = $script:LibRunspace
    [void]$ps.AddScript({
        param($root, $filter, $imgExt, $docExt, $imgOnly)
        $words = @($filter.Split([char[]]@(' '), [System.StringSplitOptions]::RemoveEmptyEntries))
        $rl = $root.TrimEnd('\').Length + 1
        $out = New-Object System.Collections.Generic.List[object]
        Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue |
            ForEach-Object {
                $rel = if ($_.FullName.Length -gt $rl) { $_.FullName.Substring($rl) } else { $_.Name }
                foreach ($w in $words) { if ($rel.IndexOf($w, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return } }
                $e = [System.IO.Path]::GetExtension($_.Name).ToLower()
                $kind = if ($e -eq '.zip') { 'zip' } elseif ($imgExt -contains $e) { 'image' } elseif ($docExt -contains $e) { 'doc' } else { 'other' }
                if ($imgOnly -and $kind -ne 'image' -and $kind -ne 'zip') { return }
                $out.Add([pscustomobject]@{ Name = $_.Name; FullName = $_.FullName; Length = $_.Length; Kind = $kind })
            }
        $out.ToArray()
    }).AddArgument($root).AddArgument($filter).AddArgument($script:ImgExt).AddArgument($script:DocExt).AddArgument($imgOnly)
    $script:LibPS = $ps
    $script:LibAsync = $ps.BeginInvoke()

    $lblLibCount.Text = (T 'recherche en cours...')
    $btnLibFilter.Enabled = $false
    $btnLibRefresh.Enabled = $false
    $form.Cursor = [System.Windows.Forms.Cursors]::AppStarting
}

function Complete-LibSearch {
    $root = $txtLibRoot.Text
    $results = @()
    try { $results = @($script:LibPS.EndInvoke($script:LibAsync)) } catch { Append-Log ((T "Recherche : {0}") -f "$($_.Exception.Message)") }
    Stop-LibSearch
    $btnLibFilter.Enabled = $true
    $btnLibRefresh.Enabled = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    $rootT = $root.TrimEnd('\')
    $ents = [System.Collections.Generic.List[object]]::new()
    foreach ($f in $results) {
        if (-not $f) { continue }
        $rel = $f.FullName
        if ($rel.Length -gt $rootT.Length) { $rel = $rel.Substring($rootT.Length).TrimStart('\') }
        $ents.Add([pscustomobject]@{ Rel = $rel; Size = [long]$f.Length; Kind = $f.Kind })
    }
    $sorted = @($ents | Sort-Object Rel)
    # Tableau garde tel quel (un seul element : pas de deroulement en chaine)
    [string[]]$rels = @(); if ($sorted.Count -gt 0) { $rels = [string[]]@($sorted.Rel) }
    Set-LibResults $root $sorted (Select-LibMatches $rels $script:LibSearchFilter $script:LibSearchInDirs)
}

function Get-LibIndexFile([string]$root) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $h = [BitConverter]::ToString($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($root.TrimEnd('\').ToLowerInvariant()))).Replace('-','').Substring(0,16)
    return (Join-Path $script:IndexDir "index-$h.tsv")
}

function Test-LibIndexReady([string]$root) {
    if (-not $script:FastIndexOk) { return $false }
    return ([FastIndex]::Root -eq $root.TrimEnd('\') -and [FastIndex]::Count -gt 0)
}

function Start-LibIndex([bool]$force) {
    if (-not $script:FastIndexOk) { return }
    $root = $txtLibRoot.Text
    if (-not $root -or -not (Test-Path -LiteralPath $root)) { return }
    if ([FastIndex]::Busy) { return }
    $file = Get-LibIndexFile $root
    if (-not $force -and (Test-LibIndexReady $root)) { return }
    if (-not $force -and (Test-Path -LiteralPath $file)) {
        try { if ([FastIndex]::Load($file, $root)) { Show-LibIndexStatus; return } } catch { Append-Log ((T "Index illisible, reconstruction : {0}") -f "$($_.Exception.Message)") }
    }
    # 12.8 (lot 4a) : reindexation demandee : blocs INFO et jeux relus (fichiers ajoutes, remplaces ou deplaces)
    if ($force) { $script:LibIpfCache = @{}; $script:LibSetCache = @{}; $script:LibRecCache = @{}; $script:LibDatState = @{}; $script:LibDatZip = @{} }
    [FastIndex]::StartBuild($root, $file)
    $script:LibIndexing = $true
    $btnLibReindex.Enabled = $false
    Append-Log ((T "Bibliothèque : indexation de {0} en arrière-plan...") -f "$root")
}

function Show-LibIndexStatus {
    if (-not $script:FastIndexOk -or [FastIndex]::Count -eq 0) { return }
    $tip.SetToolTip($lblLibCount, ((T "Index : {0} fichiers, construit le {1}.") -f "$([FastIndex]::Count)", "$([FastIndex]::Built.ToString('dd/MM/yyyy HH:mm'))"))
    if (-not $txtLibFilter.Text.Trim()) { $lblLibCount.Text = ((T "Index : {0} fichiers") -f "$('{0:N0}' -f [FastIndex]::Count)") }
}

function Show-LibIndexResults([string]$root, [string]$filter) {
    # 12.8 (lot 4a, A3 § 4.2 n° 8) : l index cherche chaque mot dans le chemin relatif complet, sans limite (FastIndex
    # inchange : sur-ensemble) ; la regle des mots s applique ensuite au nom du fichier, ou au chemin avec « Aussi dans les
    # dossiers » (Select-LibMatches) ; la liste n analyse et n affiche que les 2 000 premiers (Show-LibResults)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $res = [FastIndex]::Search($filter, [bool]$chkLibImgOnly.Checked, [int]::MaxValue)
    [string[]]$rels = @(); if ($res.Count -gt 0) { $rels = [string[]]@($res.Rel) }
    $all = Select-LibMatches $rels $filter ([bool]$chkLibInDirs.Checked)
    $script:LibIndexHits = $res.Count; $script:LibFilterMs = $sw.ElapsedMilliseconds
    Set-LibResults $root $res $all
}

function Update-Library {
    Stop-LibSearch
    Stop-LibWork
    $btnLibFilter.Enabled = $true
    $btnLibRefresh.Enabled = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    $treeLib.Nodes.Clear()
    $script:LibRendering = $true
    try { $lvLib.Items.Clear(); $lvLib.Groups.Clear() } finally { $script:LibRendering = $false }
    $script:LibAll = $null; $script:LibCand = $null; $script:LibCounts = $null; $script:LibGroups = @{}; $script:LibSetCache = @{}
    Clear-LibDetails
    $lblLibCount.Text = ''

    $root = $txtLibRoot.Text
    $filter = $txtLibFilter.Text.Trim()
    # 12.8 (lot 4a) : recherche saisie -> liste groupee des resultats ; recherche vide -> arborescence (A3 § 4.1)
    Set-LibViewMode ([bool]$filter)
    if (-not $root -or -not (Test-Path -LiteralPath $root)) {
        if ($root) { $lblLibCount.Text = (T 'racine introuvable') }
        $txtLibInfo.Text = (T "Pour commencer :`r`n1. Choisissez le dossier racine de vos images (bouton ...).`r`n2. Dépliez l'arborescence ou utilisez la recherche.`r`n3. Sélectionnez une image puis « Écriture rapide » ou « Écriture lente ».")
        return
    }

    if ($filter) {
        if ($script:FastIndexOk) {
            if (Test-LibIndexReady $root) { Show-LibIndexResults $root $filter; return }
            Start-LibIndex $false
            if (Test-LibIndexReady $root) { Show-LibIndexResults $root $filter; return }
            $script:LibPendingSearch = $true
            $lblLibCount.Text = (T 'indexation en cours...')
            return
        }
        Start-LibSearch $root $filter ([bool]$chkLibImgOnly.Checked)
        return
    }
    # Navigation : l'index est charge (ou construit) en arriere-plan pour que la premiere recherche soit instantanee
    if ($script:FastIndexOk -and -not (Test-LibIndexReady $root)) { Start-LibIndex $false }

    $treeLib.BeginUpdate()
    try {
        $rootNode = New-LibNode (Split-Path -Leaf $root) @{ Kind='dir'; Path=$root }
        [void]$treeLib.Nodes.Add($rootNode)
        Populate-LibDir $rootNode
        $rootNode.Expand()
        $lblLibCount.Text = ((T "{0} élément(s)") -f "$($rootNode.Nodes.Count)")
    } finally { $treeLib.EndUpdate() }
    Show-LibIndexStatus
}

function Show-LibSelection($node) {
    # Arborescence : panneau de details de l element choisi (12.8 : meme panneau que la liste des resultats)
    if (-not $node -or -not $node.Tag -or @('placeholder', 'none') -contains $node.Tag.Kind) { Clear-LibDetails; return }
    Show-LibDetails (Get-LibNodeRecord $node.Tag)
}

function Expand-ZipEntry([string]$zipPath, [string]$entry) {
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $dest = Join-Path $script:TempDir ([System.IO.Path]::GetFileName($entry))
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $e = $zip.Entries | Where-Object { $_.FullName -eq $entry } | Select-Object -First 1
        if (-not $e) { throw ((T "Entrée introuvable dans l'archive : {0}") -f "$entry") }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true)
    } finally { $zip.Dispose() }
    return $dest
}

function Get-LibWriteTarget {
    # 12.8 (lot 4a) : element vise par l ecriture : ligne de la liste (recherche saisie) ou noeud de l arborescence ;
    # archive ZIP : entree image choisie dans la liste des documents et entrees du panneau
    $t = $null
    if ($script:LibListMode) { if ($lvLib.SelectedItems.Count -gt 0) { $t = $lvLib.SelectedItems[0].Tag } }
    else { $n = $treeLib.SelectedNode; if ($n -and $n.Tag) { $t = $n.Tag } }
    if ($t -and $t.Kind -eq 'zip') {
        $s = $script:LibSub
        if ($s -and $s.Kind -eq 'zipentry' -and $s.FileKind -eq 'image' -and $s.ZipPath -eq $t.Path) { return $s }
        return $null
    }
    return $t
}

function Resolve-LibSelection {
    # Image ou document selectionne : chemin (entree d archive extraite dans TempDir) et source unique (fichier, ou
    # archive + entree : deux archives peuvent extraire le meme nom de fichier)
    $t = Get-LibWriteTarget
    if (-not $t) { return $null }
    if ($t.Kind -eq 'zipentry') {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        try {
            $p = Expand-ZipEntry $t.ZipPath $t.Entry
            Append-Log ((T "Extrait : {0} -> {1}") -f "$($t.Entry)", "$p")
            # FIX4B (revue du lot 4, C3) : image extraite controlee contre la taille et le CRC-32 annonces par l archive
            # (ZipArchive ne verifie pas les donnees) : une image alteree n est jamais ecrite, meme si la liste de reference
            # dit l archive « officiel »
            if ($t.FileKind -eq 'image') {
                $chk = Test-LibZipEntryData $t.ZipPath $t.Idx $t.Entry $p
                if ($chk -and -not $chk.Ok) {
                    try { [System.IO.File]::Delete($p) } catch { }
                    Show-LibNotice ((T "Image altérée dans l'archive : CRC-32 {0} au lieu de {1}. Écriture annulée.") -f $chk.Got, $chk.Want)
                    return $null
                }
            }
            return @{ Path = $p; IsImage = ($t.FileKind -eq 'image'); Source = "$($t.ZipPath)|$($t.Entry)" }
        } catch {
            Append-Log ((T "Extraction impossible : {0}") -f "$($_.Exception.Message)")
            return $null
        } finally { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
    }
    if ($t.Kind -eq 'image' -or $t.Kind -eq 'doc' -or $t.Kind -eq 'other') {
        return @{ Path = $t.Path; IsImage = ($t.Kind -eq 'image'); Source = $t.Path }
    }
    return $null
}

# ============================== BIBLIOTHEQUE : LISTE DES RESULTATS (12.8, LOT 4A) =
# Recherche saisie : ListView Details groupee par titre court (groupes non repliables : ListViewGroup.CollapsedState
# n existe pas en .NET Framework), colonnes Variante, Disq., Version, Langue, Etat, Format, Taille, Dossier ; tri par
# colonne ; badges (pastille du format et pictogramme d etat du lot 3) ; filtres Format, Langue, copies modifiees,
# originaux. Travail differe (bloc INFO des IPF, disquettes manquantes) par tranches au minuteur principal : ni runspace
# ni bloc C# nouveau, l interface reste disponible pendant la lecture d un partage.

function Set-LibViewMode([bool]$list) {
    $script:LibListMode = $list
    $lvLib.Visible = $list; $treeLib.Visible = -not $list
    foreach ($c in @($cmbLibFmt, $cmbLibLang, $chkLibHideMod, $chkLibOrig)) { $c.Enabled = $list }
}

function Get-LibFormatCode([string]$ext, [string]$kind) {
    # Format affiche : extension en majuscules (4 lettres au plus), ZIP pour une archive
    if ($kind -eq 'zip') { return 'ZIP' }
    if (-not $ext) { return '' }
    $c = $ext.TrimStart('.').ToUpperInvariant()
    if ($c.Length -gt 4) { $c = $c.Substring(0, 4) }
    return $c
}

function Get-LibFormatColor([string]$fmt) {
    # Couleur de la pastille du format : IPF Accent, ADF Floppy, ZIP Zip, flux (SCP, HFE...) WarnInk, documents Muted,
    # autres images secteur Ok ; texte blanc (contraste >= 3:1, element graphique)
    if ($fmt -eq 'IPF') { return $script:Theme.Accent }
    if ($fmt -eq 'ADF') { return $script:Theme.Floppy }
    if ($fmt -eq 'ZIP') { return $script:Theme.Zip }
    if (@('SCP', 'HFE', 'A2R', 'RAW', 'CTR', 'DMK') -contains $fmt) { return $script:Theme.WarnInk }
    if (@('PDF', 'TXT', 'JPG', 'JPEG', 'PNG', 'GIF', 'NFO', 'MD') -contains $fmt) { return $script:Theme.Muted }
    return $script:Theme.Ok
}

function Get-LibRecord([string]$rel, [long]$size, [string]$kind) {
    # Fiche d un fichier de la liste ; nom analyse une fois (cache par chemin relatif et taille)
    $r = $script:LibRecCache[$rel]
    if ($r -and $r.Size -eq $size -and $r.Kind -eq $kind) { return $r }
    $i = $rel.LastIndexOf('\')
    $name = $rel.Substring($i + 1)
    $relDir = if ($i -gt 0) { $rel.Substring(0, $i) } else { '' }
    $dirName = if ($relDir) { $relDir.Substring($relDir.LastIndexOf('\') + 1) } else { $script:LibRootLeaf }
    $info = Get-LibNameInfo $name $dirName
    $path = $script:LibRoot + '\' + $rel
    $dirFull = if ($relDir) { $script:LibRoot + '\' + $relDir } else { $script:LibRoot }
    $r = @{ Rel = $rel; Path = $path; Name = $name; RelDir = $relDir; Size = $size; Kind = $kind; Ext = $info.Ext
            Fmt = (Get-LibFormatCode $info.Ext $kind); Info = $info; SetId = "$dirFull|$($info.SetKey)"; Item = $null; StateText = '' }
    $script:LibRecCache[$rel] = $r
    return $r
}

function Get-LibNodeRecord($tag) {
    # Fiche d un element de l arborescence (dossier, fichier, archive, entree d archive)
    if (-not $tag) { return $null }
    if ($tag.Kind -eq 'dir') { return @{ Kind = 'dir'; Path = $tag.Path } }
    if ($tag.Kind -eq 'zipentry') { return (Get-LibEntryRecord $tag) }
    if (-not $tag.Path) { return $null }
    $name = [System.IO.Path]::GetFileName($tag.Path); $dir = [System.IO.Path]::GetDirectoryName($tag.Path)
    $info = Get-LibNameInfo $name ([System.IO.Path]::GetFileName($dir))
    return @{ Kind = $tag.Kind; Path = $tag.Path; Name = $name; Size = [long]$tag.Size; Ext = $info.Ext; Fmt = (Get-LibFormatCode $info.Ext $tag.Kind)
              Info = $info; SetId = "$dir|$($info.SetKey)"; RelDir = $dir; Rel = $tag.Path; Item = $null; StateText = '' }
}

function Get-LibEntryRecord($e) {
    # Fiche d une entree d archive ZIP (arborescence, ou entree choisie dans le panneau)
    $name = $e.Entry.Substring($e.Entry.LastIndexOf('/') + 1)
    $info = Get-LibNameInfo $name ''
    return @{ Kind = 'zipentry'; ZipPath = $e.ZipPath; Entry = $e.Entry; Size = [long]$e.Size; FileKind = $e.FileKind; Name = $name; Idx = $e.Idx
              Ext = $info.Ext; Fmt = (Get-LibFormatCode $info.Ext $e.FileKind); Info = $info; Path = $e.ZipPath; SetId = ''; Item = $null; StateText = '' }
}

function Get-LibIpfKey($r) {
    if ($r.Kind -eq 'zipentry') { return "$($r.ZipPath)|$($r.Entry)|$($r.Size)" }
    return "$($r.Path)|$($r.Size)"
}

function Read-LibBytes($r, [long[]]$at, [int[]]$len) {
    # Octets aux positions croissantes $at d un fichier, ou d une entree de ZIP (flux decompresse en memoire, sans
    # extraction). Fichier partage en lecture (FileShare.ReadWrite) ; element $null si la lecture est incomplete
    $res = New-Object 'object[]' $at.Count
    $zip = $null; $s = $null
    try {
        if ($r.Kind -eq 'zipentry') {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($r.ZipPath)
            $e = $zip.GetEntry($r.Entry)
            if (-not $e) { return ,$res }
            $s = $e.Open()
        } else {
            $s = [System.IO.File]::Open($r.Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        }
        $pos = [long]0
        for ($i = 0; $i -lt $at.Count; $i++) {
            if ($s.CanSeek) { [void]$s.Seek($at[$i], [System.IO.SeekOrigin]::Begin); $pos = $at[$i] }
            else {
                $skip = New-Object byte[] 65536
                while ($pos -lt $at[$i]) { $k = $s.Read($skip, 0, [int][math]::Min(65536, $at[$i] - $pos)); if ($k -le 0) { break }; $pos += $k }
                if ($pos -lt $at[$i]) { break }
            }
            $buf = New-Object byte[] $len[$i]; $got = 0
            while ($got -lt $len[$i]) { $k = $s.Read($buf, $got, $len[$i] - $got); if ($k -le 0) { break }; $got += $k }
            $pos += $got
            if ($got -eq $len[$i]) { $res[$i] = $buf }
        }
    } catch { } finally {
        if ($s) { $s.Dispose() }
        if ($zip) { $zip.Dispose() }
    }
    return ,$res
}

function Get-LibIpf($r) {
    # Bloc INFO d un IPF (108 premiers octets), en cache par chemin et taille
    $k = Get-LibIpfKey $r
    $o = $script:LibIpfCache[$k]
    if ($o) { return $o }
    $b = Read-LibBytes $r @(0) @(108)
    $o = Get-IpfInfoBlock $b[0]
    $script:LibIpfCache[$k] = $o
    return $o
}

function Get-LibAdf($r) {
    # Bloc de demarrage (1 024 octets) et bloc racine (880, ou 1760 en haute densite) d un ADF
    $size = [long]$r.Size
    $hd = ($size -gt 0 -and $size % 22528 -eq 0 -and $size / 11264 -gt 84)
    $rootAt = if ($hd) { [long]1760 * 512 } else { [long]880 * 512 }
    $b = Read-LibBytes $r @(0, $rootAt) @(1024, 512)
    return (Get-AdfInfo $b[0] $b[1] $size)
}

function Get-LibRowState($r) {
    # Colonne « Etat » et badge : identification par la liste de reference (12.8, lot 4b : officiel, modifie, inconnu ;
    # « … » en attente), puis, pour un IPF, bloc INFO (lu en differe), puis mentions TOSEC du nom. Pictogramme (lot 3) :
    # h2 image defectueuse ([b] [o] [u] [v]) ou CRC faux ; h1 copie modifiee (mention du nom, ou modifie d apres la liste) ;
    # h0 officiel d apres la liste ; sps structure SPS (disquette du logo) ; h0 image verifiee [!] ; user IPF utilisateur
    # (disquette grise) ; hq bloc INFO illisible ; aucun sinon
    $i = $r.Info; $parts = @(); $icon = ''
    $ds = Get-LibDatQuick $r
    $dk = if ($ds) { [string]$ds.State } else { '' }
    if ($dk -and $dk -ne 'wait') { $parts += (Get-LibDatWord $dk) }
    $ipfKind = ''
    if ($r.Ext -eq '.ipf' -and $r.Kind -ne 'zip') {
        $ipf = $script:LibIpfCache[(Get-LibIpfKey $r)]
        $ipfKind = if ($ipf) { $ipf.Kind } else { 'wait' }
    }
    switch ($ipfKind) {
        'sps'   { $parts += 'SPS' }
        'user'  { $parts += (T 'utilisateur') }
        'crc'   { $parts += (T 'CRC faux') }
        'none'  { $parts += '?' }
        'other' { $parts += '?' }
        'wait'  { $parts += '…' }
    }
    if ($dk -eq 'wait' -and $ipfKind -ne 'wait') { $parts = @('…') + $parts }
    if ($i.FlagText) { $parts += $i.FlagText }
    if ($i.State -eq 'bad' -or $ipfKind -eq 'crc') { $icon = 'h2' }
    elseif ($i.State -eq 'mod' -or $dk -eq 'mod') { $icon = 'h1' }
    elseif ($dk -eq 'ok') { $icon = 'h0' }
    elseif ($ipfKind -eq 'sps') { $icon = 'sps' }
    elseif ($i.State -eq 'ok') { $icon = 'h0' }
    elseif ($ipfKind -eq 'user') { $icon = 'user' }
    elseif ($ipfKind -eq 'none' -or $ipfKind -eq 'other') { $icon = 'hq' }
    $col = $script:Theme.Muted
    switch ($icon) { 'h2' { $col = Get-QualInk 3 } 'h1' { $col = $script:Theme.WarnInk } 'sps' { $col = $script:Theme.Accent } 'h0' { $col = Get-QualInk 0 } }
    if (-not $icon -and $i.FlagText) { $col = [System.Drawing.SystemColors]::WindowText }
    return @{ Text = ($parts -join ' '); Icon = $icon; Color = $col; Ipf = $ipfKind; Dat = $dk }
}

function Get-LibStateIcon([string]$icon) {
    # Pictogramme d etat de 16 px : ceux du lot 3 (h0, h1, h2, hq), disquette du logo pour la structure SPS, grisee pour un
    # IPF utilisateur ; en cache avec les ressources de la qualite (liberees a la fermeture)
    if ($icon -ne 'sps' -and $icon -ne 'user') { return (Get-QualityIcon $icon 16) }
    $k = "ilib$icon"
    $o = $script:QualGdi[$k]
    if ($o) { return $o }
    if ($icon -eq 'user') { $o = New-QualityGreyBitmap (Get-LibStateIcon 'sps') }
    else {
        $o = New-Object System.Drawing.Bitmap(16, 16, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($o)
        try { $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias; Draw-PictoFloppy $g 0 0 16 $false } finally { $g.Dispose() }
    }
    $script:QualGdi[$k] = $o
    return $o
}

function New-LibBadge([string]$fmt, [string]$icon) {
    # Badge de 42 x 16 px de la colonne « Variante » : pastille du format, puis pictogramme d etat
    $bmp = New-Object System.Drawing.Bitmap(42, 16, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        if ($fmt) {
            $rr = New-RoundRect 0.5 2 24 12 3
            $g.FillPath((Get-QualBrush (Get-LibFormatColor $fmt)), $rr); $rr.Dispose()
            $f = Get-QualFont 'Segoe UI' $(if ($fmt.Length -gt 3) { 5 } else { 6 }) 'Bold'
            $g.DrawString($fmt, $f, (Get-QualBrush ([System.Drawing.Color]::White)), (New-Object System.Drawing.RectangleF(0, 2, 25, 12)), (Get-QualSf 'center'))
        }
        if ($icon) { $g.DrawImage((Get-LibStateIcon $icon), 26, 0, 16, 16) }
    } finally { $g.Dispose() }
    return $bmp
}

function Get-LibBadgeKey($r, $st) {
    $k = "$($r.Fmt)|$($st.Icon)"
    if (-not $imgLibBadge.Images.ContainsKey($k)) { $imgLibBadge.Images.Add($k, (New-LibBadge $r.Fmt $st.Icon)) }
    return $k
}

function Set-LibResults([string]$root, $cand, [string[]]$all) {
    # Nouvelle recherche : $cand, candidats de l index ou de la recherche de repli (Rel, Size, Kind ; ordre des chemins) ;
    # $all, chemins relatifs retenus par la regle des mots ; puis liste
    Stop-LibWork
    $rootT = $root.TrimEnd('\')
    if ($script:LibRoot -ne $rootT) { $script:LibRecCache = @{}; $script:LibSetCache = @{} }
    $script:LibRoot = $rootT
    $script:LibRootLeaf = [System.IO.Path]::GetFileName($rootT)
    $script:LibCand = $cand
    $script:LibAll = [string[]]@(); if ($null -ne $all) { $script:LibAll = [string[]]$all }
    # FIX4B (revue du lot 4, C4) : nouvelle recherche ou « Actualiser » : etats d identification lus dans les fichiers
    # revalides en differe (un fichier modifie a taille egale, un ADF ou un emulateur enregistre une partie, n est plus
    # dit « officiel ») ; pas a chaque tri ou filtre
    $script:LibDatRecheck = $true
    Update-LibFormatChoices
    Show-LibResults
}

function Update-LibFormatChoices {
    # Formats presents dans les correspondances (extensions, operateurs vectorises) ; choix courant garde, meme absent
    $cur = if ($cmbLibFmt.SelectedIndex -gt 0) { [string]$cmbLibFmt.SelectedItem } else { '' }
    $set = @{}
    if ($script:LibAll.Count -gt 0) {
        $ext = [string[]](($script:LibAll -replace '^.*\\', '') -replace '^[^.]*$', '' -replace '^.*\.', '')
        foreach ($x in [System.Collections.Generic.HashSet[string]]::new($ext, [System.StringComparer]::OrdinalIgnoreCase)) {
            if (-not $x) { continue }
            $c = $x.ToUpperInvariant(); if ($c.Length -gt 4) { $c = $c.Substring(0, 4) }
            $set[$c] = $true
        }
    }
    if ($cur) { $set[$cur] = $true }
    $script:LibRendering = $true
    try {
        $cmbLibFmt.BeginUpdate()
        $cmbLibFmt.Items.Clear(); [void]$cmbLibFmt.Items.Add((T 'Tous'))
        foreach ($f in @($set.Keys | Sort-Object)) { [void]$cmbLibFmt.Items.Add($f) }
        $cmbLibFmt.SelectedIndex = $(if ($cur) { $cmbLibFmt.Items.IndexOf($cur) } else { 0 })
        $cmbLibFmt.EndUpdate()
    } finally { $script:LibRendering = $false }
}

function Update-LibLangChoices($recs) {
    # Langues presentes dans les fiches analysees (indiquees, ou langue du pays) ; choix courant garde, meme absent
    $cur = if ($cmbLibLang.SelectedIndex -gt 0) { [string]$cmbLibLang.SelectedItem } else { '' }
    $set = @{}
    foreach ($r in $recs) { foreach ($l in $r.Info.LangList) { $set[$l] = $true } }
    if ($cur) { $set[$cur] = $true }
    $script:LibRendering = $true
    try {
        $cmbLibLang.BeginUpdate()
        $cmbLibLang.Items.Clear(); [void]$cmbLibLang.Items.Add((T 'Toutes'))
        foreach ($l in @($set.Keys | Sort-Object)) { [void]$cmbLibLang.Items.Add($l) }
        $cmbLibLang.SelectedIndex = $(if ($cur) { $cmbLibLang.Items.IndexOf($cur) } else { 0 })
        $cmbLibLang.EndUpdate()
    } finally { $script:LibRendering = $false }
}

function Update-LibFilters {
    # Filtre ou tri change : liste refaite depuis les fiches en cache (aucune nouvelle recherche)
    if ($script:LibRendering -or -not $script:LibListMode -or $null -eq $script:LibAll) { return }
    Show-LibResults -Keep
}

function Get-LibSortValue($r, [int]$col) {
    # Partie de cle de tri croissant d une colonne (comparaison ordinale) : nombres sur des chiffres fixes, textes en
    # minuscules. Ordre decroissant : Get-LibDescKeys
    $num = $null
    switch ($col) {
        0 { $s = $(if ($r.Info.Variant) { $r.Info.Variant } else { $r.Info.Base }) }
        1 { $num = [long]$r.Info.DiskNo }
        2 { $s = [string]$r.Info.Version }
        3 { $s = [string]$r.Info.Langs }
        4 { $s = [string](Get-LibRowState $r).Text }
        5 { $s = [string]$r.Fmt }
        6 { $num = [long]$r.Size }
        default { $s = [string]$r.RelDir }
    }
    if ($null -ne $num) { return $num.ToString('D15') }
    return $s.ToLowerInvariant() + [char]0
}

function Get-LibDescKeys([string[]]$vals) {
    # Cles de tri decroissant : rang de chaque valeur dans l ordre ordinal croissant, inverse et ecrit sur 7 chiffres
    # (valeurs egales : meme rang, departagees ensuite par le nom du fichier). Aucune transformation caractere par caractere
    $s = [string[]]$vals.Clone()
    [Array]::Sort([Array]$s, [System.Collections.IComparer][System.StringComparer]::Ordinal)
    $rank = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::Ordinal)
    foreach ($v in $s) { if (-not $rank.ContainsKey($v)) { $rank[$v] = $rank.Count } }
    $top = $rank.Count
    $out = New-Object 'string[]' $vals.Length
    for ($i = 0; $i -lt $vals.Length; $i++) { $out[$i] = ($top - $rank[$vals[$i]]).ToString('D7') }
    return ,$out
}

function Get-LibSetSortValue($r, [string]$sep) {
    # FIX4B (revue du lot 4, constat 1) : ordre dans un groupe : images et archives avant les documents, puis jeu de
    # disquettes (variante du jeu, version, langue, mentions, extension), puis disquette. Les disquettes d un meme jeu restent
    # contigues : la copie [cr] allemande en deux disquettes ne s intercale plus entre celles de l original en trois
    $i = $r.Info
    $rank = if ($r.Kind -eq 'doc' -or $r.Kind -eq 'other') { '1' } else { '0' }
    return ($rank + $sep + ([string]$i.SetVariant).ToLowerInvariant() + $sep + ([string]$i.Version).ToLowerInvariant() + $sep + [string]$i.Langs + $sep +
            ([string]$i.FlagText).ToLowerInvariant() + $sep + [string]$r.Ext + $sep + ([long]$i.DiskNo).ToString('D4'))
}

function Sort-LibRecords($recs) {
    # Groupes dans l ordre des titres ; dans un groupe : colonne choisie (croissant ou decroissant), puis jeu de disquettes
    # et disquette (Get-LibSetSortValue) ; nom du fichier en dernier. Cle composee triee par [Array]::Sort (ordinal,
    # natif) : Sort-Object avec des blocs de script prenait plusieurs secondes pour 2 000 lignes sous Windows PowerShell 5.1
    $col = [int]$script:LibSort.Col; $desc = [bool]$script:LibSort.Desc
    $n = $recs.Count
    $keys = New-Object 'string[]' $n; $arr = New-Object 'object[]' $n
    $sep = [string][char]1
    $vals = $null
    if ($col -ge 0) {
        $vals = New-Object 'string[]' $n
        for ($i = 0; $i -lt $n; $i++) { $vals[$i] = Get-LibSortValue $recs[$i] $col }
        if ($desc) { $vals = Get-LibDescKeys $vals }
    }
    for ($i = 0; $i -lt $n; $i++) {
        $r = $recs[$i]; $arr[$i] = $r
        $v = Get-LibSetSortValue $r $sep
        if ($null -ne $vals) { $v = $vals[$i] + $sep + $v }
        $keys[$i] = $r.Info.SortKey + $sep + $r.Info.Key + $sep + $v + $sep + $r.Name.ToLowerInvariant()
    }
    # Surcharge non generique imposee : sinon PowerShell lie Sort<TKey,TValue> sur une copie des lignes (cles seules triees)
    [Array]::Sort([Array]$keys, [Array]$arr, [System.Collections.IComparer][System.StringComparer]::Ordinal)
    return ,$arr
}

function Set-LibSort([int]$col) {
    # Clic sur un en-tete : tri par cette colonne, puis ordre inverse au clic suivant (fleche dans l en-tete)
    if ($script:LibSort.Col -eq $col) { $script:LibSort.Desc = -not $script:LibSort.Desc } else { $script:LibSort.Col = $col; $script:LibSort.Desc = $false }
    for ($j = 0; $j -lt $lvLib.Columns.Count; $j++) {
        $t = $script:LibColTitles[$j]
        $c = $lvLib.Columns[$j]
        if ($j -eq $col) {
            $t += $(if ($script:LibSort.Desc) { ' ▼' } else { ' ▲' })
            # FIX4B (revue du lot 4) : colonne elargie si son titre et la fleche n y tiennent pas (« Langue ▲ »)
            $need = Get-LibColumnWidth $t
            if ($c.Width -lt $need) { $c.Width = $need; $script:LibColAuto[$j] = $need }
        } elseif ($script:LibColAuto[$j] -and $c.Width -eq $script:LibColAuto[$j] -and $j -lt $script:LibColW.Count) {
            # Colonne qui n est plus triee : largeur de depart rendue (sauf si l utilisateur l a changee entre-temps)
            $c.Width = $script:LibColW[$j]; $script:LibColAuto[$j] = 0
        }
        $c.Text = $t
    }
    Update-LibFilters
}

function Get-LibColumnWidth([string]$title, [int]$min = 0) {
    # Largeur d une colonne de la liste : titre mesure dans la police de la liste (celle de la fenetre tant que la liste
    # n est pas placee dans l onglet), plus les marges de l en-tete
    $f = if ($lvLib -and $lvLib.Parent) { $lvLib.Font } else { $form.Font }
    $w = [System.Windows.Forms.TextRenderer]::MeasureText($title, $f).Width + 14
    return [int][math]::Max($min, $w)
}

function New-LibListItem($r) {
    $i = $r.Info
    $st = Get-LibRowState $r
    $it = [System.Windows.Forms.ListViewItem]::new($(if ($i.Variant) { $i.Variant } else { $i.Base }))
    $it.UseItemStyleForSubItems = $false
    [void]$it.SubItems.Add((Get-LibDiskText $i))
    [void]$it.SubItems.Add([string]$i.Version)
    $sl = $it.SubItems.Add([string]$i.Langs); if ($i.LangDerived) { $sl.ForeColor = $script:Theme.Muted }
    $ss = $it.SubItems.Add($st.Text); $ss.ForeColor = $st.Color
    [void]$it.SubItems.Add([string]$r.Fmt)
    [void]$it.SubItems.Add((Format-Size $r.Size))
    [void]$it.SubItems.Add($(if ($r.RelDir) { $r.RelDir } else { '.' }))
    $it.ImageKey = Get-LibBadgeKey $r $st
    $it.ToolTipText = $r.Rel
    $it.Tag = $r
    $r.Item = $it; $r.StateText = $st.Text
    return $it
}

function Update-LibRowState($r, [switch]$Detached) {
    # Bloc INFO lu (en differe ou a la selection) : colonne « Etat » et badge de la ligne mis a jour sur place ; -Detached :
    # ligne gardee d un affichage precedent, remise a jour avant d etre reutilisee
    $it = $r.Item
    if (-not $it) { return }
    if (-not $Detached -and -not $it.ListView) { return }
    $st = Get-LibRowState $r
    if ($it.SubItems[4].Text -eq $st.Text) { return }
    $it.SubItems[4].Text = $st.Text; $it.SubItems[4].ForeColor = $st.Color
    $it.ImageKey = Get-LibBadgeKey $r $st
    $r.StateText = $st.Text
}

function Get-LibMissingText($m, [switch]$Short) {
    # Disquettes manquantes : « manque 3 (jeu de 3) » ; -Short, colonne « Etat » de la liste (100 px) : « manque 3 », le
    # nombre de disquettes du jeu reste dans l infobulle de la ligne et dans le panneau
    if ($m.Known -and -not $Short) { return ((T 'manque {0} (jeu de {1})') -f (Format-LibDiskList $m), $m.Total) }
    return ((T 'manque {0}') -f (Format-LibDiskList $m))
}

function New-LibMissingItem($r, $m) {
    # Ligne « disquettes manquantes » d un jeu, a la fin de son groupe (A3 § 4.2 n° 5) : variante du jeu, texte dans la
    # colonne « Etat » en WarnInk, pictogramme « ! » du lot 3. L en-tete d un groupe n est jamais modifie apres son ajout :
    # sous .NET Framework, ListViewGroup.Header recree la poignee de la liste (toutes les lignes reinserees).
    # FIX4B (revue du lot 4) : texte court dans la colonne (forme longue dans l infobulle et le panneau) ; variante du jeu,
    # sans les crochets propres a une disquette
    $t = Get-LibMissingText $m -Short
    $it = [System.Windows.Forms.ListViewItem]::new($(if ($r.Info.SetVariant) { $r.Info.SetVariant } else { $r.Info.Title }))
    $it.UseItemStyleForSubItems = $false
    [void]$it.SubItems.Add('')
    [void]$it.SubItems.Add([string]$r.Info.Version)
    [void]$it.SubItems.Add([string]$r.Info.Langs)
    $ss = $it.SubItems.Add($t); $ss.ForeColor = $script:Theme.WarnInk
    [void]$it.SubItems.Add([string]$r.Fmt)
    [void]$it.SubItems.Add('')
    [void]$it.SubItems.Add($(if ($r.RelDir) { $r.RelDir } else { '.' }))
    $it.ImageKey = Get-LibBadgeKey @{ Fmt = '' } @{ Icon = 'h1' }
    $it.ToolTipText = (T 'Jeu incomplet : {0}') -f (Get-LibMissingText $m)
    $it.Tag = @{ Kind = 'missing'; Rel = "missing|$($r.SetId)"; Name = ''; Info = $r.Info; Missing = $m; SetId = $r.SetId; Fmt = $r.Fmt; RelDir = $r.RelDir; Path = $r.Path }
    return $it
}

function Add-LibMissingRow($r) {
    # Travail differe : jeu incomplet trouve apres l affichage -> ligne ajoutee a la fin de son groupe (sans recreer la liste)
    $m = $script:LibSetCache[$r.SetId]
    if (-not $m -or -not $m.Missing -or $m.Missing.Count -eq 0) { return }
    $g = $script:LibGroups[$r.Info.Key]
    if (-not $g -or -not $r.Item -or -not $r.Item.ListView) { return }
    $it = New-LibMissingItem $r $m
    $it.Group = $g.Group
    [void]$lvLib.Items.Add($it)
}

function Show-LibResults([switch]$Keep) {
    # Liste des resultats : filtre Format sur toutes les correspondances, 2 000 premieres analysees, puis filtres Langue,
    # copies modifiees et originaux ; groupes dans l ordre des titres, lignes triees ; travail differe relance
    Stop-LibWork
    [void](Get-LibDat)      # 12.8 (lot 4b) : liste de reference enregistree, lue a la premiere demande
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $max = 2000
    $fmtSel = if ($cmbLibFmt.SelectedIndex -gt 0) { [string]$cmbLibFmt.SelectedItem } else { '' }
    $langSel = if ($cmbLibLang.SelectedIndex -gt 0) { [string]$cmbLibLang.SelectedItem } else { '' }
    $hideMod = [bool]$chkLibHideMod.Checked; $orig = [bool]$chkLibOrig.Checked
    $keepRel = $null
    if ($Keep -and $lvLib.SelectedItems.Count -gt 0) { $keepRel = $lvLib.SelectedItems[0].Tag.Rel }
    # Filtre Format sur toutes les correspondances (chemins), puis fiches des 2 000 premieres dans l ordre des candidats.
    # FIX4B (revue du lot 4) : le total reste celui des correspondances ; les fichiers d un autre format comptent parmi les
    # masques (compteur et infobulle), comme ceux des autres filtres
    $fm = $script:LibAll
    if ($fmtSel -and $fm.Count -gt 0) { $fm = [string[]]@($fm -match ('(?i)\.' + [regex]::Escape($fmtSel) + '[^.\\]*$')) }
    $total = $fm.Count
    $fmtHidden = $script:LibAll.Count - $fm.Count
    $recs = [System.Collections.Generic.List[object]]::new()
    if ($total -gt 0) {
        $set = [System.Collections.Generic.HashSet[string]]::new([string[]]$fm, [System.StringComparer]::Ordinal)
        foreach ($e in $script:LibCand) {
            if ($recs.Count -ge $max) { break }
            if ($set.Contains([string]$e.Rel)) { $recs.Add((Get-LibRecord ([string]$e.Rel) ([long]$e.Size) ([string]$e.Kind))) }
        }
    }
    $script:LibParseMs = $sw.ElapsedMilliseconds
    $tm = [ordered]@{ fiches = $sw.ElapsedMilliseconds }
    Update-LibLangChoices $recs
    $shown = [System.Collections.Generic.List[object]]::new(); $hidden = 0; $script:LibOrigPending = $false
    foreach ($r in $recs) {
        $i = $r.Info
        if ($langSel -and $i.LangList -notcontains $langSel) { $hidden++; continue }
        if ($hideMod -and $i.Modified) { $hidden++; continue }
        if ($orig -and (Test-LibDatOn)) {
            # 12.8 (lot 4b) : liste de reference chargee : fichiers officiels seulement (images et archives)
            $dq = Get-LibDatQuick $r
            if (-not $dq) { $hidden++; continue }
            if ($dq.State -eq 'wait') { $script:LibOrigPending = $true; $hidden++; continue }
            if ($dq.State -ne 'ok') { $hidden++; continue }
        } elseif ($orig) {
            if ($r.Ext -ne '.ipf' -or $r.Kind -eq 'zip') { $hidden++; continue }
            $ipf = $script:LibIpfCache[(Get-LibIpfKey $r)]
            if (-not $ipf) { $script:LibOrigPending = $true; $hidden++; continue }
            if ($ipf.Kind -ne 'sps') { $hidden++; continue }
        }
        $shown.Add($r)
    }
    $tm.filtres = $sw.ElapsedMilliseconds
    $sorted = Sort-LibRecords $shown
    $tm.tri = $sw.ElapsedMilliseconds
    $script:LibRendering = $true
    $lvLib.BeginUpdate()
    try {
        $lvLib.Items.Clear(); $lvLib.Groups.Clear()
        $tm.vidage = $sw.ElapsedMilliseconds
        # Groupes formes d abord (ordre des titres), en-tete complet des la creation : ListViewGroup.Header ne se change
        # plus une fois le groupe dans la liste (sous .NET Framework, chaque changement recree la poignee de la liste)
        $script:LibGroups = @{}; $order = [System.Collections.Generic.List[string]]::new()
        foreach ($r in $sorted) {
            $k = $r.Info.Key
            $g = $script:LibGroups[$k]
            if (-not $g) { $g = @{ Title = $r.Info.Title; Recs = [System.Collections.Generic.List[object]]::new() }; $script:LibGroups[$k] = $g; $order.Add($k) }
            $g.Recs.Add($r)
        }
        $groups = [System.Collections.Generic.List[System.Windows.Forms.ListViewGroup]]::new()
        $items = [System.Collections.Generic.List[System.Windows.Forms.ListViewItem]]::new()
        foreach ($k in $order) {
            $g = $script:LibGroups[$k]
            $g.Group = [System.Windows.Forms.ListViewGroup]::new($k, ((T '{0}  ·  {1} fichier(s)') -f $g.Title, $g.Recs.Count))
            $groups.Add($g.Group)
            $seen = @{}
            # Ligne d un affichage precedent (tri, filtre) reutilisee : seule sa colonne « Etat » est remise a jour
            foreach ($r in $g.Recs) {
                $it = $r.Item
                if ($it -and -not $it.ListView) { $it.Selected = $false; Update-LibRowState $r -Detached } else { $it = New-LibListItem $r }
                $it.Group = $g.Group; $items.Add($it)
            }
            # Jeux incomplets deja connus (cache) : ligne a la fin du groupe
            foreach ($r in $g.Recs) {
                if ($seen.ContainsKey($r.SetId)) { continue }
                $seen[$r.SetId] = $true
                $m = $script:LibSetCache[$r.SetId]
                if ($m -and $m.Missing -and $m.Missing.Count -gt 0) { $it = New-LibMissingItem $r $m; $it.Group = $g.Group; $items.Add($it) }
            }
        }
        $tm.lignes = $sw.ElapsedMilliseconds
        $lvLib.Groups.AddRange($groups.ToArray())
        $tm.groupes = $sw.ElapsedMilliseconds
        $lvLib.Items.AddRange($items.ToArray())
        $tm.ajout = $sw.ElapsedMilliseconds
    } finally { $lvLib.EndUpdate(); $script:LibRendering = $false }
    $script:LibCounts = @{ Total = $script:LibAll.Count; Capped = $recs.Count; Shown = $shown.Count; Hidden = $hidden + $fmtHidden; Max = $max }
    $script:LibRenderMs = $sw.ElapsedMilliseconds
    $tm.total = $sw.ElapsedMilliseconds; $script:LibTimes = $tm
    $kept = $false
    if ($keepRel) {
        foreach ($it in $lvLib.Items) { if ($it.Tag.Rel -eq $keepRel) { $it.Selected = $true; $it.EnsureVisible(); $kept = $true; break } }
    }
    if (-not $kept) { Clear-LibDetails }
    Start-LibWork $recs $shown
    Update-LibCountText
}

function Update-LibCountText {
    # Compteur : resultats, plafond de 2 000, lignes masquees par les filtres, avancement du travail differe
    $c = $script:LibCounts
    if (-not $c) { return }
    $t = if ($c.Hidden -gt 0) { (T '{0} affiché(s), {1} masqué(s)') -f "$('{0:N0}' -f $c.Shown)", "$('{0:N0}' -f $c.Hidden)" }
         elseif ($c.Total -gt $c.Capped) { (T "{0} premiers sur {1}") -f "$('{0:N0}' -f $c.Capped)", "$('{0:N0}' -f $c.Total)" }
         else { (T "{0} résultat(s)") -f "$('{0:N0}' -f $c.Total)" }
    if ($script:LibWork.Count -gt 0) { $t += '  ·  ' + ((T 'analyse {0}/{1}') -f $script:LibWorkDone, $script:LibWorkTotal) }
    $lblLibCount.Text = $t
    $tip.SetToolTip($lblLibCount, ((T "{0} fichier(s) dont le nom correspond ; {1} analysé(s) (2 000 au plus) ; {2} masqué(s) par les filtres ; {3} affiché(s).") -f "$('{0:N0}' -f $c.Total)", "$('{0:N0}' -f $c.Capped)", "$('{0:N0}' -f $c.Hidden)", "$('{0:N0}' -f $c.Shown)"))
}

function Start-LibWork($recs, $shown) {
    # Travail differe : bloc INFO des IPF analyses (etat SPS, filtre « Originaux seulement »), puis jeux a plusieurs
    # disquettes affiches (disquettes manquantes d apres les fichiers du dossier, pas d apres les seuls resultats)
    $script:LibWork.Clear(); $script:LibWorkDone = 0
    foreach ($r in $recs) {
        if ($r.Ext -eq '.ipf' -and $r.Kind -ne 'zip' -and -not $script:LibIpfCache.ContainsKey((Get-LibIpfKey $r))) { $script:LibWork.Enqueue(@{ T = 'ipf'; Rec = $r }) }
    }
    $seen = @{}
    foreach ($r in $shown) {
        if ($r.Info.DiskNo -gt 0 -and -not $seen.ContainsKey($r.SetId) -and -not $script:LibSetCache.ContainsKey($r.SetId)) { $seen[$r.SetId] = $true; $script:LibWork.Enqueue(@{ T = 'set'; Rec = $r }) }
    }
    # 12.8 (lot 4b) : identification par la liste de reference des images et archives dont la taille figure dans la liste
    # (lignes affichees d abord, puis lignes masquees par les filtres, pour « Originaux seulement ») ; FIX4B (C4) : apres
    # une nouvelle recherche, etats deja identifies par lecture revalides aussi (taille et date du fichier, Test-LibDatFresh)
    $recheck = [bool]$script:LibDatRecheck; $script:LibDatRecheck = $false
    if (Test-LibDatOn) {
        $seen = @{}
        foreach ($grp in @($shown, $recs)) {
            foreach ($r in $grp) {
                $q = Get-LibDatQuick $r
                if (-not $q -or ($q.State -ne 'wait' -and -not ($recheck -and $null -ne $q.Ticks))) { continue }
                $k = Get-LibIpfKey $r
                if ($seen.ContainsKey($k)) { continue }
                $seen[$k] = $true; $script:LibWork.Enqueue(@{ T = 'dat'; Rec = $r })
            }
        }
    }
    $script:LibWorkTotal = $script:LibWork.Count
}

function Stop-LibWork { $script:LibWork.Clear(); $script:LibWorkDone = 0; $script:LibWorkTotal = 0 }

function Step-LibWork([int]$budgetMs = 60) {
    # Une tranche du travail differe (minuteur principal, 200 ms) : $budgetMs au plus, puis la main revient a l interface
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($script:LibWork.Count -gt 0 -and $sw.ElapsedMilliseconds -lt $budgetMs) {
        $w = $script:LibWork.Peek()
        if ($w.T -eq 'dat') {
            # 12.8 (lot 4b) : identification ; CRC-32 d un fichier d un seul tenant (bibliotheque ZIP de .NET)
            [void](Step-LibDatWork $w)
            [void]$script:LibWork.Dequeue(); $script:LibWorkDone++
            continue
        }
        [void]$script:LibWork.Dequeue(); $script:LibWorkDone++
        if ($w.T -eq 'ipf') { [void](Get-LibIpf $w.Rec); Update-LibRowState $w.Rec }
        else {
            $cached = $script:LibSetCache.ContainsKey($w.Rec.SetId)
            [void](Get-LibSetMissing $w.Rec)
            if (-not $cached) { Add-LibMissingRow $w.Rec }
        }
    }
    if ($script:LibWork.Count -eq 0) {
        $script:LibWorkTotal = 0
        if ($script:LibOrigPending -and $chkLibOrig.Checked) { $script:LibOrigPending = $false; Show-LibResults -Keep; return }
    }
    Update-LibCountText
}

function Get-LibSetMissing($r) {
    # Disquettes manquantes du jeu de $r, d apres les fichiers de son dossier (meme nom sans la disquette, meme extension) ;
    # cache par jeu. Dossier de publication SPS : tous ses fichiers ; sinon motif « debut du nom* » (filtre par le systeme
    # de fichiers, 500 fichiers au plus)
    if (-not $r -or -not $r.Info -or $r.Info.DiskNo -le 0 -or -not $r.SetId -or $r.Kind -eq 'zipentry') { return $null }
    $id = $r.SetId
    if ($script:LibSetCache.ContainsKey($id)) { return $script:LibSetCache[$id] }
    $res = $null
    try {
        $dir = [System.IO.Path]::GetDirectoryName($r.Path)
        $pat = if ($r.Info.Source -eq 'dir') { '*' } elseif ($r.Info.Prefix) { $r.Info.Prefix + '*' } else { '' }
        if ($pat) {
            $dirName = [System.IO.Path]::GetFileName($dir)
            $list = [System.Collections.Generic.List[object]]::new(); $n = 0; $unknown = 0
            foreach ($f in [System.IO.Directory]::EnumerateFiles($dir, $pat)) {
                $n++; if ($n -gt 500) { break }
                $i2 = Get-LibNameInfo ([System.IO.Path]::GetFileName($f)) $dirName
                if ($i2.SetKey -ne $r.Info.SetKey) { continue }
                if ($i2.DiskNo -gt 0) { $list.Add(@{ DiskNo = $i2.DiskNo; DiskTot = $i2.DiskTot; Letter = $i2.DiskLetter }); continue }
                # FIX4B (revue du lot 4, C2) : fichier du meme jeu sans numero de disquette dans le nom (publication SPS :
                # « SuperCars.ipf », « BodyBlows_BootDisk.ipf ») : numero lu dans le bloc INFO d un IPF ; sinon, ou bloc
                # illisible, aucun manque signale (la disquette « manquante » est peut-etre celle-la)
                $dn = 0
                if ($i2.Ext -eq '.ipf') {
                    try {
                        $ipf = Get-LibIpf @{ Kind = 'image'; Path = $f; Size = (New-Object System.IO.FileInfo($f)).Length }
                        if (($ipf.Kind -eq 'sps' -or $ipf.Kind -eq 'user') -and $ipf.DiskNumber -gt 0 -and $ipf.DiskNumber -le 99) { $dn = [int]$ipf.DiskNumber }
                    } catch { }
                }
                if ($dn -gt 0) { $list.Add(@{ DiskNo = $dn; DiskTot = 0; Letter = $false }) } else { $unknown++ }
            }
            $m = Get-LibMissingDisks @{ s = $list }
            $res = if ($m.ContainsKey('s') -and $unknown -eq 0) { $m['s'] } else { @{ Missing = @(); Total = 0; Known = $false; Letter = $false } }
        }
    } catch { $res = $null }
    $script:LibSetCache[$id] = $res
    return $res
}

# --- Panneau de details ---------------------------------------------------------------------------------------------
function Format-LibIpfDate([long]$d) {
    # Date du bloc INFO (entier AAAAMMJJ) au format JJ/MM/AAAA
    if ($d -lt 19000101 -or $d -gt 29991231) { return '' }
    $s = "$d"
    return "$($s.Substring(6, 2))/$($s.Substring(4, 2))/$($s.Substring(0, 4))"
}

function Get-LibPlatformName([long]$p) {
    switch ($p) {
        1 { return 'Amiga' } 2 { return 'Atari ST' } 3 { return 'PC' } 4 { return 'Amstrad CPC' } 5 { return 'Spectrum' }
        6 { return 'Sam Coupé' } 7 { return 'Archimedes' } 8 { return 'C64' } 9 { return (T 'Atari 8 bits') }
    }
    return "$p"
}

function Get-LibIpfLines($ipf) {
    # Bloc INFO (D18) : « IPF de structure SPS » sans liste, jamais « officiel » (reserve a une correspondance avec une DAT)
    $L = @()
    switch ($ipf.Kind) {
        'sps' {
            $t = (T 'IPF de structure SPS : publication n° {0}, révision {1}') -f $ipf.FileKey, $ipf.FileRev
            if ($ipf.DiskNumber -gt 0) { $t += ((T ', disquette {0}') -f $ipf.DiskNumber) }
            $L += $t
        }
        'user'  { $L += (T 'IPF utilisateur (disk-analyse) : copie personnelle, pas une publication SPS') }
        'crc'   { $L += (T 'IPF : bloc INFO au CRC faux (fichier altéré ou incomplet)') }
        'other' { $L += ((T 'IPF : encodeur inconnu ({0})') -f $ipf.Encoder) }
        default { $L += (T 'IPF : bloc INFO absent ou illisible') }
    }
    if ($ipf.Kind -eq 'sps' -or $ipf.Kind -eq 'user') {
        $p = @()
        $pl = @($ipf.Platforms | ForEach-Object { Get-LibPlatformName $_ }) -join ', '
        if ($pl) { $p += ((T 'Plate-forme : {0}') -f $pl) }
        $d = Format-LibIpfDate $ipf.Date
        if ($d) { $p += ((T 'créé le {0}') -f $d) }
        if ($p.Count -gt 0) { $L += ($p -join ' · ') }
    }
    return $L
}

function Get-LibAdfLines($a) {
    $L = @()
    if ($a.Dos) {
        $fs = $a.Fs; if ($a.Intl) { $fs += ' INTL' }; if ($a.DirCache) { $fs += ' DIRCACHE' }
        $t = (T 'ADF : AmigaDOS {0} (DOS{1})') -f $fs, $a.Flags
        if ($a.RootOk -and $a.Volume) { $t += ((T ', volume « {0} »') -f $a.Volume) }
        elseif (-not $a.RootOk) { $t += (T ', sans bloc racine lisible (chargeur propre)') }
        if ($a.Bootable) { $t += (T ', amorçable') }
        $L += $t
    } elseif ($a.BootRead) {
        $t = T 'ADF : bloc de démarrage non-DOS (chargeur propre, souvent protégé)'
        if ($a.RootOk -and $a.Volume) { $t += ((T ', volume « {0} »') -f $a.Volume) }
        $L += $t
    } else { $L += (T 'ADF : lecture impossible') }
    if ($a.Hd) { $L += (T 'ADF haute densité (bloc racine 1760)') }
    return $L
}

function Get-LibFlagLine($i) {
    # Mentions TOSEC du nom, expliquees
    if (-not $i.FlagText) { return '' }
    $d = @()
    foreach ($f in @($i.Flags | Select-Object -Unique)) {
        $x = switch ($f) {
            'cr' { T 'déplombée' } 'f' { T 'corrigée' } 'h' { T 'modifiée (hack)' } 'm' { T 'modifiée' } 'p' { T 'pirate' }
            't' { T 'entraîneur (trainer)' } 'tr' { T 'traduite' } 'o' { T 'image trop longue (overdump)' }
            'u' { T 'image incomplète (underdump)' } 'v' { T 'virus' } 'b' { T 'image défectueuse (bad dump)' }
            'a' { T 'variante (alternate)' } '!' { T 'image vérifiée' } default { $f }
        }
        $d += $x
    }
    return ((T 'Mentions : {0} ({1})') -f $i.FlagText, ($d -join ', '))
}

function Get-LibNameLines($r) {
    # Ce que dit le nom : variante, disquette, version, langue, mentions
    $i = $r.Info; $L = @()
    if (-not $i) { return $L }
    if ($i.Variant) { $L += ((T 'Variante : {0}') -f $i.Variant) }
    $p = @()
    if ($i.Disk) {
        $d = if ($i.DiskTot -gt 0) { (T 'Disquette {0} sur {1}') -f $i.Disk, $i.DiskTot } else { (T 'Disquette {0}') -f $i.Disk }
        if ($i.Label) { $d += " ($($i.Label))" }
        $p += $d
    }
    if ($i.Version) { $p += ((T 'Version {0}') -f $i.Version) }
    if ($i.Langs) { $p += ((T 'Langue : {0}') -f $i.Langs) }
    if ($p.Count -gt 0) { $L += ($p -join ' · ') }
    $f = Get-LibFlagLine $i
    if ($f) { $L += $f }
    return $L
}

function Get-LibContentLines($r) {
    # Ce que dit le fichier : IPF (bloc INFO) ou ADF (type DOS, volume) ; la ligne de la liste suit
    $L = @()
    try {
        if ($r.Ext -eq '.ipf') { $L += Get-LibIpfLines (Get-LibIpf $r); Update-LibRowState $r }
        elseif ($r.Ext -eq '.adf') { $L += Get-LibAdfLines (Get-LibAdf $r) }
    } catch { $L += ((T 'Lecture impossible : {0}') -f "$($_.Exception.Message)") }
    # 12.8 (lot 4b) : identification par la liste de reference ; CRC-32 d un fichier : calcul en tete du travail differe,
    # ligne remplacee a la fin (Update-LibDatDetails)
    if ((Test-LibDatOn) -and (Test-LibDatEligible $r)) {
        try {
            $s = Resolve-LibDatState $r
            if ($s -and $s.State -eq 'wait') { Request-LibDatWork $r }
            Update-LibRowState $r
        } catch { }
        $d = @(Get-LibDatLines $r)
        if ($d.Count -gt 0) { $L += $d; if ($r.Kind -eq 'image') { $script:LibDatLine = $d -join "`r`n" } }
    }
    return $L
}

function Test-LibPicture([string]$path) { return (@('.jpg', '.jpeg', '.png', '.gif') -contains [System.IO.Path]::GetExtension($path).ToLowerInvariant()) }

function Get-LibRelatedDocs($r) {
    # Documents associes (A3 § 4.2 n° 6) : documents (DocExt) du dossier au titre court du jeu, ou tous ceux du dossier
    # quand c est celui du jeu (dossier de publication SPS, ou dossier au titre du jeu) ; medias selon la convention Pegasus
    # (media\<titre ou nom>\*.png|jpg, a cote de l image ou a la racine). 60 au plus
    $out = [System.Collections.Generic.List[object]]::new()
    if (-not $r -or -not $r.Info) { return ,$out }
    $path = if ($r.Kind -eq 'zipentry') { $r.ZipPath } else { $r.Path }
    if (-not $path) { return ,$out }
    $key = $r.Info.Key
    $seen = @{}
    try {
        $dir = [System.IO.Path]::GetDirectoryName($path)
        $dirName = [System.IO.Path]::GetFileName($dir)
        $gameDir = ($r.Info.Source -eq 'dir') -or ((Get-LibNameInfo $dirName '').Key -eq $key)
        $pat = if ($gameDir) { '*' } elseif ($r.Info.Prefix) { $r.Info.Prefix + '*' } else { '' }
        if ($pat) {
            foreach ($f in [System.IO.Directory]::EnumerateFiles($dir, $pat)) {
                if ($out.Count -ge 60) { break }
                if ($script:DocExt -notcontains [System.IO.Path]::GetExtension($f).ToLowerInvariant()) { continue }
                $nm = [System.IO.Path]::GetFileName($f)
                if (-not $gameDir -and (Get-LibNameInfo $nm $dirName).Key -ne $key) { continue }
                $seen[$f.ToLowerInvariant()] = $true
                $out.Add(@{ Kind = 'doc'; Path = $f; Name = $nm })
            }
        }
        $roots = @($dir)
        if ($script:LibRoot -and $script:LibRoot -ne $dir) { $roots += $script:LibRoot }
        foreach ($mr in $roots) {
            foreach ($nm in @($r.Info.Title, $r.Info.Base | Select-Object -Unique)) {
                if (-not $nm) { continue }
                $md = [System.IO.Path]::Combine($mr, 'media', $nm)
                if (-not [System.IO.Directory]::Exists($md)) { continue }
                foreach ($f in [System.IO.Directory]::EnumerateFiles($md)) {
                    if ($out.Count -ge 60) { break }
                    if (-not (Test-LibPicture $f) -or $seen.ContainsKey($f.ToLowerInvariant())) { continue }
                    $seen[$f.ToLowerInvariant()] = $true
                    $out.Add(@{ Kind = 'doc'; Path = $f; Name = ('media\' + $nm + '\' + [System.IO.Path]::GetFileName($f)); Media = $true })
                }
            }
        }
    } catch { }
    return ,$out
}

function Select-LibThumb($docs) {
    # Vignette : boxFront des medias, sinon une image dont le nom evoque la boite, sinon la premiere image
    $pics = @($docs | Where-Object { Test-LibPicture $_.Path })
    foreach ($d in $pics) { if ([System.IO.Path]::GetFileNameWithoutExtension($d.Path) -ieq 'boxFront') { return $d.Path } }
    foreach ($d in $pics) { if ([System.IO.Path]::GetFileName($d.Path) -match '(?i)box|cover|front|jaquette') { return $d.Path } }
    if ($pics.Count -gt 0) { return $pics[0].Path }
    return ''
}

function Set-LibThumb([string]$path) {
    # Vignette chargee par un flux en memoire (le fichier n est jamais verrouille), reduite au cadre ; ancienne liberee
    $old = $picLibThumb.Image; $picLibThumb.Image = $null
    if ($old) { $old.Dispose() }
    $ok = $false
    if ($path) {
        try {
            $fi = New-Object System.IO.FileInfo($path)
            if ($fi.Exists -and $fi.Length -le 16MB) {
                $bytes = [System.IO.File]::ReadAllBytes($path)
                $ms = New-Object System.IO.MemoryStream(,$bytes)
                try {
                    $img = [System.Drawing.Image]::FromStream($ms)
                    try {
                        # Image de 72 x 72 px, affichee reduite si la page est basse (SizeMode Zoom, Update-LibPanelLayout)
                        $w = 72; $h = 72
                        $sc = [math]::Min([math]::Min($w / $img.Width, $h / $img.Height), 1.0)
                        $tw = [math]::Max(1, [int]($img.Width * $sc)); $th = [math]::Max(1, [int]($img.Height * $sc))
                        $bmp = New-Object System.Drawing.Bitmap($w, $h)
                        $g = [System.Drawing.Graphics]::FromImage($bmp)
                        try {
                            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                            $g.DrawImage($img, [int](($w - $tw) / 2), [int](($h - $th) / 2), $tw, $th)
                        } finally { $g.Dispose() }
                        $picLibThumb.Image = $bmp; $ok = $true
                    } finally { $img.Dispose() }
                } finally { $ms.Dispose() }
            }
        } catch { }
    }
    $script:LibThumbPath = if ($ok) { $path } else { '' }
    # Texte d information a cote de la vignette, ou sur toute la largeur sans vignette
    Update-LibPanelLayout
}

function Update-LibPanelLayout {
    # FIX4B (revue du lot 4, constat 2) : colonne de droite ajustee a la hauteur de la page (environ 300 px a la taille par
    # defaut avec le journal, et non 340). Entre le titre et les boutons : liste du bas (documents, entrees d archive) en
    # bas, 2 lignes (3 si la place le permet), masquee quand elle est vide ; texte au-dessus ; vignette a gauche du texte,
    # carree, de la hauteur du texte (72 px au plus), masquee sous 40 px : jamais sur la liste du bas. Appelee a chaque
    # affichage du panneau (Set-LibThumb) et au redimensionnement de la page (apres l ancrage des boutons)
    $x = $lblLibTitle.Left; $w = $lblLibTitle.Width
    $top = $lblLibTitle.Bottom + 1
    $bot = $btnLibFast.Top - 3
    $docs = ($lstLibDocs.Items.Count -gt 0)
    if ($docs) {
        $dh = $(if ($bot - $top -ge 170) { 3 } else { 2 }) * $lstLibDocs.ItemHeight + 4
        $lstLibDocs.SetBounds($x, $bot - $dh, $w, $dh)
        $bot -= $dh + 2
    }
    # Visible affecte sans le relire : la lecture rend faux tant que l onglet est cache (etat propre du controle ignore)
    $lstLibDocs.Visible = $docs
    $ih = [int][math]::Max(20, $bot - $top)
    $th = 0
    if ($picLibThumb.Image) { $th = [int][math]::Min(72, $ih); if ($th -lt 40) { $th = 0 } }
    $tx = $x
    if ($th -gt 0) { $picLibThumb.SetBounds($x, $top, $th, $th); $tx = $x + $th + 6 }
    $picLibThumb.Visible = ($th -gt 0)
    $txtLibInfo.SetBounds($tx, $top, $x + $w - $tx, $ih)
}

function Clear-LibDetails {
    $script:LibCur = $null; $script:LibSub = $null; $script:LibSubRecs = @(); $script:LibInfoBase = ''; $script:LibDatLine = ''
    $was = $script:LibRendering; $script:LibRendering = $true
    try { $lstLibDocs.Items.Clear() } finally { $script:LibRendering = $was }
    $lblLibTitle.Text = ''; $txtLibInfo.Clear()
    Set-LibThumb ''
    Set-LibWriteEnabled $false
    $btnLibOpen.Enabled = $false
}

function Show-LibDetails($r) {
    # Panneau de details (A3 § 4.1, § 4.2 n° 4 a 6) : titre ; ce que disent le nom et le fichier (IPF : bloc INFO ; ADF :
    # type DOS et volume) ; disquettes manquantes du jeu ; taille et chemin ; documents associes et vignette. Archive ZIP :
    # ses entrees dans la liste du bas, la premiere image choisie pour l ecriture
    Clear-LibDetails
    if (-not $r) { return }
    if (Test-LibDatEligible $r) { [void](Get-LibDat) }      # 12.8 (lot 4b) : liste lue a la premiere demande
    $script:LibCur = $r
    $L = [System.Collections.Generic.List[string]]::new()
    $title = ''; $docs = $null; $thumb = ''; $subs = @(); $selSub = -1
    switch ($r.Kind) {
        'dir' { $title = [System.IO.Path]::GetFileName($r.Path.TrimEnd('\')); $L.Add((T 'Dossier')); $L.Add($r.Path) }
        'zip' {
            $title = $r.Info.Title
            foreach ($x in (Get-LibNameLines $r)) { $L.Add($x) }
            $ents = @(Get-ZipEntries $r.Path)
            $nImg = @($ents | Where-Object { $_.Kind -eq 'image' }).Count
            $L.Add(((T 'Archive ZIP, {0} : {1} entrée(s), dont {2} image(s)') -f (Format-Size $r.Size), $ents.Count, $nImg))
            # 12.8 (lot 4b) : identification par la liste de reference (repertoire central de l archive)
            $zs = $null
            if (Test-LibDatOn) {
                try { $zs = Resolve-LibDatState $r; Update-LibRowState $r } catch { }
                foreach ($x in (Get-LibDatLines $r)) { $L.Add($x) }
            }
            $m = Get-LibSetMissing $r
            if ($m -and $m.Missing.Count -gt 0) { $L.Add(((T 'Jeu incomplet : {0}') -f (Get-LibMissingText $m))) }
            foreach ($e in $ents) {
                $ew = ''
                if ($zs -and $zs.Zip -and $null -ne $e.Index -and $e.Index -lt $zs.Zip.Entries.Count -and $zs.Zip.Entries[$e.Index] -and $zs.Zip.Dir[$e.Index].Size -eq [long]$e.Length) {
                    $ew = Get-LibDatWord $zs.Zip.Entries[$e.Index].State
                }
                $et = if ($ew) { (T '{0}  (dans l''archive, {1}) : {2}') -f $e.FullName, (Format-Size $e.Length), $ew } else { (T '{0}  (dans l''archive, {1})') -f $e.FullName, (Format-Size $e.Length) }
                $subs += ,@{ Kind = 'zipentry'; ZipPath = $r.Path; Entry = $e.FullName; Size = [long]$e.Length; FileKind = $e.Kind; Idx = $e.Index; Text = $et }
                if ($selSub -lt 0 -and $e.Kind -eq 'image') { $selSub = $subs.Count - 1 }
            }
            $L.Add($r.Path)
            $docs = Get-LibRelatedDocs $r
        }
        'zipentry' {
            $title = $r.Info.Title
            foreach ($x in (Get-LibNameLines $r)) { $L.Add($x) }
            foreach ($x in (Get-LibContentLines $r)) { $L.Add($x) }
            $L.Add(((T "Dans l'archive : {0}") -f [System.IO.Path]::GetFileName($r.ZipPath)))
            $L.Add("$($r.Fmt), $(Format-Size $r.Size)")
            $docs = Get-LibRelatedDocs $r
        }
        'image' {
            $title = $r.Info.Title
            foreach ($x in (Get-LibNameLines $r)) { $L.Add($x) }
            foreach ($x in (Get-LibContentLines $r)) { $L.Add($x) }
            $m = Get-LibSetMissing $r
            if ($m -and $m.Missing.Count -gt 0) { $L.Add(((T 'Jeu incomplet : {0}') -f (Get-LibMissingText $m))) }
            $L.Add("$($r.Fmt), $(Format-Size $r.Size)")
            $L.Add($r.Path)
            $docs = Get-LibRelatedDocs $r
        }
        'doc' {
            $title = $r.Info.Title
            $L.Add(((T "Document ({0}), {1}") -f [System.IO.Path]::GetExtension($r.Path), (Format-Size $r.Size)))
            $L.Add($r.Path)
            if (Test-LibPicture $r.Path) { $thumb = $r.Path }
        }
        'missing' {
            $title = $r.Info.Title
            if ($r.Info.SetVariant) { $L.Add(((T 'Variante : {0}') -f $r.Info.SetVariant)) }
            $L.Add(((T 'Jeu incomplet : {0}') -f (Get-LibMissingText $r.Missing)))
            $L.Add([System.IO.Path]::GetDirectoryName($r.Path))
        }
        default {
            $title = $r.Name
            $L.Add((T 'Fichier non pris en charge'))
            if ($r.Path) { $L.Add($r.Path) }
        }
    }
    if ($docs) {
        foreach ($d in $docs) { $subs += ,@{ Kind = 'doc'; Path = $d.Path; Name = $d.Name; Text = $d.Name } }
        if (-not $thumb) { $thumb = Select-LibThumb $docs }
    }
    $script:LibSubRecs = $subs
    $script:LibRendering = $true
    try { foreach ($s in $subs) { [void]$lstLibDocs.Items.Add($s.Text) } } finally { $script:LibRendering = $false }
    $lblLibTitle.Text = $title
    $script:LibInfoBase = $L -join "`r`n"
    $txtLibInfo.Text = $script:LibInfoBase
    Set-LibThumb $thumb
    Set-LibWriteEnabled ($r.Kind -eq 'image' -or ($r.Kind -eq 'zipentry' -and $r.FileKind -eq 'image'))
    $btnLibOpen.Enabled = ($r.Kind -eq 'doc' -or ($r.Kind -eq 'zipentry' -and $r.FileKind -eq 'doc'))
    if ($selSub -ge 0) { $lstLibDocs.SelectedIndex = $selSub }
}

function Show-LibSubSelection {
    # Element choisi dans la liste du bas : entree d archive (son analyse s ajoute au panneau ; image : cible de l ecriture)
    # ou document (Ouvrir ; image affichee dans la vignette)
    if ($script:LibRendering) { return }
    $i = $lstLibDocs.SelectedIndex
    $s = if ($i -ge 0 -and $i -lt $script:LibSubRecs.Count) { $script:LibSubRecs[$i] } else { $null }
    $script:LibSub = $s
    $cur = $script:LibCur
    $txt = $script:LibInfoBase
    if ($s -and $s.Kind -eq 'zipentry' -and $s.FileKind -eq 'image') {
        $er = Get-LibEntryRecord $s
        $lines = @(Get-LibNameLines $er) + @(Get-LibContentLines $er)
        $txt += "`r`n`r`n" + ((T 'Entrée choisie : {0}') -f $s.Entry)
        if ($lines.Count -gt 0) { $txt += "`r`n" + ($lines -join "`r`n") }
    }
    $txtLibInfo.Text = $txt
    if ($cur -and $cur.Kind -eq 'zip') { Set-LibWriteEnabled ([bool]($s -and $s.Kind -eq 'zipentry' -and $s.FileKind -eq 'image')) }
    $btnLibOpen.Enabled = [bool](Get-LibOpenTarget)
    if ($s -and $s.Kind -eq 'doc' -and (Test-LibPicture $s.Path)) { Set-LibThumb $s.Path }
}

function Get-LibOpenTarget {
    # Document a ouvrir : celui choisi dans la liste du bas, sinon l element selectionne s il est un document
    $s = $script:LibSub
    if ($s -and ($s.Kind -eq 'doc' -or ($s.Kind -eq 'zipentry' -and $s.FileKind -eq 'doc'))) { return $s }
    $c = $script:LibCur
    if ($c -and ($c.Kind -eq 'doc' -or ($c.Kind -eq 'zipentry' -and $c.FileKind -eq 'doc'))) { return $c }
    return $null
}

function Open-LibDoc {
    # Ouvre le document avec l application par defaut (entree d archive extraite dans TempDir)
    $t = Get-LibOpenTarget
    if (-not $t) { return }
    $p = $t.Path
    if ($t.Kind -eq 'zipentry') {
        try { $p = Expand-ZipEntry $t.ZipPath $t.Entry; Append-Log ((T "Extrait : {0} -> {1}") -f "$($t.Entry)", "$p") }
        catch { Append-Log ((T "Extraction impossible : {0}") -f "$($_.Exception.Message)"); return }
    }
    try { Start-Process -FilePath $p } catch { Append-Log ((T "Ouverture impossible : {0}") -f "$($_.Exception.Message)") }
}

function Clear-LibGdi {
    # Fermeture de la fenetre : vignette et badges de la liste
    if ($picLibThumb -and $picLibThumb.Image) { $b = $picLibThumb.Image; $picLibThumb.Image = $null; $b.Dispose() }
    if ($imgLibBadge) { try { $imgLibBadge.Dispose() } catch { } }
}

# ============================== BIBLIOTHEQUE : LISTE DE REFERENCE (12.8, LOT 4B) ==
# D19 (A3 § 3.4 B) : liste (DAT) choisie par l utilisateur (bouton « Liste de reference... »), chemin enregistre (reglage
# libDat), lue a la premiere ouverture de l onglet ou a la premiere recherche ; jamais fournie ni telechargee. Images et
# archives ZIP identifiees : liste des resultats par le travail differe du minuteur (CRC-32 d un fichier par la
# bibliotheque ZIP de .NET ; CRC d une entree d archive lu dans son repertoire central), panneau de details a la selection (element mis en tete du travail differe). « Officiel » n apparait qu avec une liste.

function Test-LibDatOn { return [bool]($script:LibDat -and $script:LibDat.Ok) }

function Test-LibDatEligible($r) {
    # Elements identifies : images, archives ZIP et entrees image d une archive (ni documents ni dossiers)
    return [bool]($r -and ($r.Kind -eq 'image' -or $r.Kind -eq 'zip' -or ($r.Kind -eq 'zipentry' -and $r.FileKind -eq 'image')))
}

function Get-LibDatWord([string]$state) {
    switch ($state) { 'ok' { return (T 'officiel') } 'mod' { return (T 'modifié') } 'unk' { return (T 'inconnu') } }
    return '…'
}

function Format-LibDatEntry($e) {
    if (-not $e) { return '' }
    if ($e.Game) { return ((T '« {0} » du jeu « {1} »') -f $e.Name, $e.Game) }
    return ((T '« {0} »') -f $e.Name)
}

function Get-LibDat {
    # Liste chargee (Ok), lue a la premiere demande si un chemin est enregistre ; une seule lecture par chemin (une liste
    # illisible n est relue qu apres un nouveau choix) ; $null sans liste utilisable
    $p = [string](Get-Setting 'libDat')
    if (-not $p) { return $null }
    if (-not $script:LibDat -or $script:LibDat.Path -ne $p) { Import-LibDatNow }
    if (Test-LibDatOn) { return $script:LibDat }
    return $null
}

function Import-LibDatNow {
    # Lecture de la liste enregistree (curseur d attente), ligne de journal, etat a cote du bouton ; etats remis a zero
    $p = [string](Get-Setting 'libDat')
    $script:LibDatState = @{}; $script:LibDatZip = @{}
    if (-not $p) { $script:LibDat = $null; Update-LibDatLabel; return }
    $was = $form.Cursor; $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try { $d = Read-LibDat $p } finally { $form.Cursor = $was }
    $script:LibDat = $d
    if ($d.Ok) {
        Append-Log ((T 'Liste de référence : {0} ({1}), {2} entrée(s), {3} fichier(s), lue en {4} s.') -f $d.Name, (Get-LibDatFormatText $d), "$('{0:N0}' -f $d.Games)", "$('{0:N0}' -f $d.Roms)", (Format-UiNum ($d.Ms / 1000.0) '0.0'))
    } else {
        Append-Log ((T 'Liste de référence illisible ({0}) : {1}') -f [System.IO.Path]::GetFileName($p), $d.Error)
    }
    Update-LibDatLabel
}

function Get-LibDatFormatText($d) {
    if ($d.Version) { return ((T '{0}, version {1}') -f $d.Format, $d.Version) }
    return [string]$d.Format
}

function Update-LibDatLabel {
    # Etat de la liste a cote du bouton : aucune ; nom du fichier (lue a l ouverture de l onglet) ; « nom, N entree(s) » ;
    # illisible (message dans l infobulle). Bouton de retrait visible avec une liste
    $p = [string](Get-Setting 'libDat')
    $d = $script:LibDat
    $btnLibDatClear.Visible = [bool]$p
    if (-not $p) {
        $lblLibDat.Text = (T 'aucune'); $lblLibDat.ForeColor = $script:Theme.Muted
        $tip.SetToolTip($lblLibDat, (T 'Aucune liste de référence : les fichiers ne sont pas identifiés.'))
        return
    }
    if (-not $d -or $d.Path -ne $p) {
        $lblLibDat.Text = [System.IO.Path]::GetFileName($p); $lblLibDat.ForeColor = $script:Theme.Muted
        $tip.SetToolTip($lblLibDat, ((T "{0}`nLue à l'ouverture de l'onglet Bibliothèque.") -f $p))
        return
    }
    if (-not $d.Ok) {
        $lblLibDat.Text = (T 'liste illisible'); $lblLibDat.ForeColor = (Get-QualInk 3)
        $tip.SetToolTip($lblLibDat, "$p`n$($d.Error)")
        return
    }
    $lblLibDat.Text = (T '{0}, {1} entrée(s)') -f $d.Name, "$('{0:N0}' -f $d.Games)"
    $lblLibDat.ForeColor = [System.Drawing.SystemColors]::ControlText
    $t = (T 'Liste de référence : {0}') -f $d.Name
    if ($d.Description -and $d.Description -ne $d.Name) { $t += "`n" + $d.Description }
    $t += "`n" + ((T '{0} entrée(s), {1} fichier(s) identifiable(s) ({2})') -f "$('{0:N0}' -f $d.Games)", "$('{0:N0}' -f $d.Roms)", (Get-LibDatFormatText $d))
    $t += "`n" + $p
    $tip.SetToolTip($lblLibDat, $t)
}

function Reset-LibDat {
    # Reglage libDat change (choix, retrait, configuration lue, valeurs par defaut) : liste dechargee, relue a la prochaine
    # demande ; etats d identification et travail differe d identification abandonnes
    $script:LibDat = $null; $script:LibDatState = @{}; $script:LibDatZip = @{}
    Update-LibDatLabel
}

function Select-LibDatFile {
    # Bouton « Liste de reference... » : fichier .dat ou .xml choisi par l utilisateur sur son ordinateur
    $d = New-Object System.Windows.Forms.OpenFileDialog
    try {
        $d.Title = (T 'Liste de référence (DAT)')
        $d.Filter = (T 'Listes de référence (*.dat;*.xml)|*.dat;*.xml|Tous les fichiers (*.*)|*.*')
        $cur = [string](Get-Setting 'libDat')
        if ($cur) { try { $d.InitialDirectory = [System.IO.Path]::GetDirectoryName($cur); $d.FileName = [System.IO.Path]::GetFileName($cur) } catch { } }
        if ($d.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
        Set-LibDatPath $d.FileName
    } finally { $d.Dispose() }
}

function Set-LibDatPath([string]$path) {
    # Liste choisie (lue tout de suite) ou retiree (chemin vide) ; liste des resultats et panneau refaits
    Stop-LibWork
    Set-Setting 'libDat' $path
    if ($path) { Import-LibDatNow } else { Append-Log (T 'Liste de référence retirée.') }
    if ($script:LibListMode -and $null -ne $script:LibAll) { Show-LibResults -Keep }
    elseif ($script:LibCur) { Show-LibDetails $script:LibCur }
}

function Get-LibDatQuick($r) {
    # Etat d identification sans lecture de fichier : en cache, ou decide par la taille et le nom (aucune entree de cette
    # taille) ; @{ State = 'wait' } s il faut lire le fichier ; $null sans liste ou pour un element non identifie
    if (-not (Test-LibDatOn) -or -not (Test-LibDatEligible $r)) { return $null }
    $k = Get-LibIpfKey $r
    $s = $script:LibDatState[$k]
    if ($s) { return $s }
    if ($r.Kind -ne 'zip' -and -not $script:LibDat.BySize.ContainsKey([long]$r.Size)) {
        $s = Get-LibDatMatch $script:LibDat ([long]$r.Size) $r.Name @{}
        $script:LibDatState[$k] = $s
        return $s
    }
    return @{ State = 'wait' }
}

function Get-LibHashStore {
    # Empreintes gardees pour la racine de la Bibliotheque (hash-<md5>.tsv), lues une fois par racine
    $f = Get-LibHashFile ([string]$txtLibRoot.Text)
    if ($script:LibHashFileCur -ne $f -or $null -eq $script:LibHashCache) { $script:LibHashCache = Import-LibHashCache $f; $script:LibHashFileCur = $f }
    return $script:LibHashCache
}

function Get-LibHashCached([string]$path, [long]$size, [long]$ticks) {
    $o = $null
    if ((Get-LibHashStore).TryGetValue((Get-LibHashKey $path $size $ticks), [ref]$o)) { return @{ Crc = $o.Crc; Md5 = $o.Md5; Sha1 = $o.Sha1 } }
    return @{ Crc = ''; Md5 = ''; Sha1 = '' }
}

function Save-LibHash([string]$path, [long]$size, [long]$ticks, $h) {
    $c = Get-LibHashStore
    $c[(Get-LibHashKey $path $size $ticks)] = @{ Crc = $h.Crc; Md5 = $h.Md5; Sha1 = $h.Sha1 }
    Add-LibHashLine $script:LibHashFileCur $path $size $ticks $h
}

function Get-LibZipDat([string]$zipPath) {
    # Archive ZIP identifiee, en cache par chemin, taille et date : repertoire central, etat de chaque entree image et de
    # l archive. Entree dont la liste n a pas de CRC-32 : SHA-1 ou MD5 calcules sur le flux decompresse. $null si illisible
    $fi = New-Object System.IO.FileInfo($zipPath)
    if (-not $fi.Exists) { return $null }
    $ck = "$zipPath|$($fi.Length)|$($fi.LastWriteTimeUtc.Ticks)"
    if ($script:LibDatZip.ContainsKey($ck)) { return $script:LibDatZip[$ck] }
    $z = $null
    $ents = Read-LibZipDir $zipPath
    # FIX4B (C1) : liste, meme d une seule entree ; archive sans entree : inconnu, et non illisible
    if ($null -ne $ents) {
        $z = Get-LibZipDatState $script:LibDat $ents
        if ($z.State -eq 'wait') {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
            try {
                for ($i = 0; $i -lt $ents.Count; $i++) {
                    $s = $z.Entries[$i]
                    if (-not $s -or $s.State -ne 'wait') { continue }
                    $h = @{ Crc = $ents[$i].Crc; Md5 = ''; Sha1 = '' }; $n = 0
                    while ($s.State -eq 'wait' -and $s.Need -ne 'Crc' -and $n -lt 3 -and $i -lt $zip.Entries.Count) {
                        $st = $zip.Entries[$i].Open()
                        try { $h[$s.Need] = Get-LibHashText $s.Need $st } finally { $st.Dispose() }
                        $s = Get-LibDatMatch $script:LibDat ([long]$ents[$i].Size) $ents[$i].Name $h -Common; $n++
                    }
                    if ($s.State -eq 'wait') { $s = @{ State = 'unk' } }
                    $z.Entries[$i] = $s
                }
            } finally { $zip.Dispose() }
            $z = Measure-LibZipDatState $z.Entries
        }
        $z.Dir = $ents
        $z.Ticks = $fi.LastWriteTimeUtc.Ticks; $z.Len = $fi.Length     # FIX4B (C4) : etat revalide si l archive change
    }
    $script:LibDatZip[$ck] = $z
    return $z
}

function Get-LibZipEntryState($z, $r) {
    # Etat d une entree d archive : rang dans l archive (controle par la taille), sinon nom et taille
    if (-not $z) { return @{ State = 'unk'; Err = (T 'archive illisible') } }
    $i = -1
    if ($null -ne $r.Idx -and $r.Idx -ge 0 -and $r.Idx -lt $z.Dir.Count -and $z.Dir[$r.Idx].Size -eq [long]$r.Size) { $i = [int]$r.Idx }
    else { for ($j = 0; $j -lt $z.Dir.Count; $j++) { if ($z.Dir[$j].Name -ceq [string]$r.Entry -and $z.Dir[$j].Size -eq [long]$r.Size) { $i = $j; break } } }
    if ($i -lt 0 -or -not $z.Entries[$i]) {
        $s = Get-LibDatMatch $script:LibDat ([long]$r.Size) $r.Name @{}
        if ($s.State -eq 'wait') { $s = @{ State = 'unk' } }
        $s.Ticks = $z.Ticks; $s.Len = $z.Len
        return $s
    }
    $e = $z.Entries[$i]
    return @{ State = $e.State; Entry = $e.Entry; Hash = @{ Crc = $z.Dir[$i].Crc; Md5 = ''; Sha1 = '' }; Ticks = $z.Ticks; Len = $z.Len }
}

function Test-LibDatFresh($r, $s) {
    # FIX4B (revue du lot 4, C4) : etat identifie par lecture du fichier (ou de son archive) encore valable si la taille et
    # la date de modification n ont pas change. Etat sans date (decide par la taille seule, ou en erreur) : valable
    if (-not $s -or $null -eq $s.Ticks) { return $true }
    try {
        $p = if ($r.Kind -eq 'zipentry') { [string]$r.ZipPath } else { [string]$r.Path }
        $fi = New-Object System.IO.FileInfo($p)
        return [bool]($fi.Exists -and $fi.Length -eq [long]$s.Len -and $fi.LastWriteTimeUtc.Ticks -eq [long]$s.Ticks)
    } catch { return $false }
}

function Resolve-LibDatState($r) {
    # Identification avec lecture : archive ZIP (repertoire central), entree d archive, fichier (empreinte gardee, sinon
    # SHA-1 ou MD5 calcules ici). Etat garde par chemin et taille, avec la date lue (Ticks, Test-LibDatFresh) ;
    # @{ State = 'wait'; Need = 'Crc' }, non garde : CRC-32 du fichier a calculer dans le travail differe (Step-LibDatWork)
    $q = Get-LibDatQuick $r
    $k = Get-LibIpfKey $r
    # FIX4B (C4) : etat garde d un fichier modifie depuis (meme taille, autre date) : identification refaite ; « Originaux
    # seulement » : liste refaite a la fin du travail differe (Step-LibWork)
    if ($q -and $q.State -ne 'wait' -and -not (Test-LibDatFresh $r $q)) {
        [void]$script:LibDatState.Remove($k); $q = Get-LibDatQuick $r; $script:LibOrigPending = $true
    }
    if (-not $q -or $q.State -ne 'wait') { return $q }
    $dat = $script:LibDat
    $s = $null
    try {
        if ($r.Kind -eq 'zip') {
            $z = Get-LibZipDat $r.Path
            $s = if ($z) { @{ State = $z.State; Zip = $z; Ticks = $z.Ticks; Len = $z.Len } } else { @{ State = 'unk'; Err = (T 'archive illisible') } }
        } elseif ($r.Kind -eq 'zipentry') {
            $s = Get-LibZipEntryState (Get-LibZipDat $r.ZipPath) $r
        } else {
            $fi = New-Object System.IO.FileInfo($r.Path)
            if (-not $fi.Exists) { $s = @{ State = 'unk'; Err = (T 'fichier introuvable') } }
            else {
                $tk = $fi.LastWriteTimeUtc.Ticks
                $h = Get-LibHashCached $r.Path $fi.Length $tk
                $s = Get-LibDatMatch $dat $fi.Length $r.Name $h; $n = 0
                while ($s.State -eq 'wait' -and $s.Need -ne 'Crc' -and $n -lt 3) {
                    $fs = [System.IO.File]::Open($r.Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                    try { $h[$s.Need] = Get-LibHashText $s.Need $fs } finally { $fs.Dispose() }
                    Save-LibHash $r.Path $fi.Length $tk $h
                    $s = Get-LibDatMatch $dat $fi.Length $r.Name $h; $n++
                }
                if ($s.State -eq 'wait') { return $s }
                $s.Hash = $h; $s.Ticks = $tk; $s.Len = $fi.Length
            }
        }
    } catch { $s = @{ State = 'unk'; Err = "$($_.Exception.Message)" } }
    $script:LibDatState[$k] = $s
    return $s
}

function Request-LibDatWork($r) {
    # Element du panneau dont le CRC-32 reste a calculer : en tete du travail differe
    $k = Get-LibIpfKey $r
    $items = $script:LibWork.ToArray()
    $script:LibWork.Clear()
    $script:LibWork.Enqueue(@{ T = 'dat'; Rec = $r })
    foreach ($w in $items) {
        if ($w.T -eq 'dat' -and (Get-LibIpfKey $w.Rec) -eq $k) { continue }
        $script:LibWork.Enqueue($w)
    }
    $script:LibWorkTotal = $script:LibWorkDone + $script:LibWork.Count
}

function Step-LibDatWork($w) {
    # Identification de $w.Rec : etat deja connu, archive, empreinte gardee, ou SHA-1/MD5 ; sinon CRC-32 du fichier
    # (32 Mo au plus), d un seul tenant, par la bibliotheque ZIP native de .NET (Get-LibFileCrc32, aucun calcul en
    # PowerShell). L etat est toujours connu au retour : l appelant retire l element de la file
    $r = $w.Rec
    if (-not (Test-LibDatOn)) { return }
    $k = Get-LibIpfKey $r
    $s = Resolve-LibDatState $r
    if (-not $s -or $s.State -ne 'wait') { Complete-LibDatItem $r; return }
    try {
        $fi = New-Object System.IO.FileInfo($r.Path)
        if ($fi.Length -gt 32MB) { throw (T 'fichier trop gros pour le calcul du CRC-32') }
        $tk = $fi.LastWriteTimeUtc.Ticks
        $h = Get-LibHashCached $r.Path $fi.Length $tk
        $h.Crc = Get-LibFileCrc32 $r.Path
        Save-LibHash $r.Path $fi.Length $tk $h
        $s = Get-LibDatMatch $script:LibDat $fi.Length $r.Name $h
        # FIX4B (C7) : CRC-32 egal a celui d une entree qui fournit aussi un SHA-1 ou un MD5 : cette empreinte est calculee
        # tout de suite (Resolve-LibDatState repart du CRC-32 garde) ; le CRC-32 seul ne suffit pas
        if ($s.State -eq 'wait' -and $s.Need -ne 'Crc') {
            $s2 = Resolve-LibDatState $r
            if ($s2 -and $s2.State -ne 'wait') { Complete-LibDatItem $r; return }
        }
        if ($s.State -eq 'wait') { $s = @{ State = 'unk' } }
        $s.Hash = $h; $s.Ticks = $tk; $s.Len = $fi.Length
    } catch { $s = @{ State = 'unk'; Err = "$($_.Exception.Message)" } }
    $script:LibDatState[$k] = $s
    Complete-LibDatItem $r
}

function Complete-LibDatItem($r) {
    # Etat connu : ligne de la liste et panneau de details mis a jour sur place
    Update-LibRowState $r
    Update-LibDatDetails $r
}

function Update-LibDatDetails($r) {
    # Fichier affiche dans le panneau identifie apres l affichage : ses lignes « Liste de reference » remplacees sur place
    $c = $script:LibCur
    if (-not $c -or $c.Kind -ne 'image' -or -not $script:LibDatLine -or (Get-LibIpfKey $c) -ne (Get-LibIpfKey $r)) { return }
    $new = @(Get-LibDatLines $c) -join "`r`n"
    $old = $script:LibDatLine
    if (-not $new -or $new -eq $old) { return }
    $script:LibInfoBase = $script:LibInfoBase.Replace($old, $new)
    $txtLibInfo.Text = $txtLibInfo.Text.Replace($old, $new)
    $script:LibDatLine = $new
}

function Get-LibDatLines($r) {
    # Lignes « Liste de reference » du panneau : etat et entree correspondante de la liste ; archive ZIP : nombre d images
    # officielles ; empreinte calculee ou lue dans l archive
    if (-not (Test-LibDatOn) -or -not (Test-LibDatEligible $r)) { return @() }
    $n = $script:LibDat.Name
    $s = Get-LibDatQuick $r
    $L = @()
    if ($s.Err) { $L += ((T 'Liste de référence ({0}) : non identifié ({1})') -f $n, $s.Err) }
    elseif ($s.Zip) { $L += ((T 'Liste de référence ({0}) : {1}, {2} image(s) officielle(s) sur {3}') -f $n, (Get-LibDatWord $s.State), $s.Zip.OkCount, $s.Zip.Total) }
    else {
        switch ($s.State) {
            'ok'    { $L += ((T 'Liste de référence ({0}) : officiel, {1}') -f $n, (Format-LibDatEntry $s.Entry)) }
            'mod'   { $L += ((T 'Liste de référence ({0}) : modifié, même nom que {1}, contenu différent') -f $n, (Format-LibDatEntry $s.Entry)) }
            'unk'   { $L += ((T 'Liste de référence ({0}) : inconnu, absent de la liste') -f $n) }
            default { $L += ((T 'Liste de référence ({0}) : identification en cours…') -f $n) }
        }
    }
    if ($s.Hash) {
        if ($s.Hash.Sha1) { $L += ((T 'Empreinte {0} : {1}') -f 'SHA-1', $s.Hash.Sha1) }
        elseif ($s.Hash.Md5) { $L += ((T 'Empreinte {0} : {1}') -f 'MD5', $s.Hash.Md5) }
        elseif ($s.Hash.Crc) { $L += ((T 'Empreinte {0} : {1}') -f 'CRC-32', $s.Hash.Crc) }
    }
    return $L
}
