# ============================== FONCTIONS : BIBLIOTHEQUE =======================

function Start-LibWrite([string]$mode) {
    # Ecriture rapide ou lente de l image selectionnee : parametres de l onglet Ecriture appliques, calibration
    # automatique si elle manque pour la famille de l image, puis ecriture (onglet Ecriture affiche pour le suivi)
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    $sel = Resolve-LibSelection
    if (-not $sel) { return }
    if (-not $sel.IsImage) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Ce fichier n''est pas un format image reconnu par gw.'),(T 'Type non pris en charge'),'OK','Information'); return
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
    $out = @()
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            foreach ($e in $zip.Entries) {
                if ($e.FullName.EndsWith('/')) { continue }
                $out += [pscustomobject]@{ FullName = $e.FullName; Length = $e.Length; Kind = (Get-FileKind $e.Name) }
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
                    @{ Kind='zipentry'; ZipPath=$node.Tag.Path; Entry=$e.FullName; Size=$e.Length; FileKind=$e.Kind }))
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
    Stop-LibSearch
    if (-not $script:LibRunspace -or $script:LibRunspace.RunspaceStateInfo.State -ne 'Opened') {
        $script:LibRunspace = [runspacefactory]::CreateRunspace()
        $script:LibRunspace.Open()
    }
    $ps = [powershell]::Create()
    $ps.Runspace = $script:LibRunspace
    [void]$ps.AddScript({
        param($root, $filter, $imgExt, $docExt, $imgOnly)
        $pat = '*' + [System.Management.Automation.WildcardPattern]::Escape($filter) + '*'
        $out = New-Object System.Collections.Generic.List[object]
        Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like $pat } |
            ForEach-Object {
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

    $treeLib.BeginUpdate()
    try {
        $treeLib.Nodes.Clear()
        $list = New-Object System.Collections.Generic.List[System.Windows.Forms.TreeNode]
        foreach ($f in ($results | Sort-Object FullName)) {
            if (-not $f) { continue }
            $rel = $f.FullName
            if ($rel.Length -gt $root.Length) { $rel = $rel.Substring($root.Length).TrimStart('\') }
            $n = New-LibNode "$(Get-KindPrefix $f.Kind)$rel  ($(Format-Size $f.Length))" @{ Kind=$f.Kind; Path=$f.FullName; Size=$f.Length }
            if ($f.Kind -eq 'zip') { [void]$n.Nodes.Add((New-Placeholder)) }
            $list.Add($n)
        }
        if ($list.Count -gt 0) { $treeLib.Nodes.AddRange($list.ToArray()) }
        $lblLibCount.Text = ((T "{0} résultat(s)") -f "$($list.Count)")
    } finally { $treeLib.EndUpdate() }
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
    $max = 2000
    $res = [FastIndex]::Search($filter, [bool]$chkLibImgOnly.Checked, $max)
    $rootT = $root.TrimEnd('\')
    $treeLib.BeginUpdate()
    try {
        $treeLib.Nodes.Clear()
        $list = New-Object System.Collections.Generic.List[System.Windows.Forms.TreeNode]
        foreach ($e in $res) {
            $full = Join-Path $rootT $e.Rel
            $n = New-LibNode "$(Get-KindPrefix $e.Kind)$($e.Rel)  ($(Format-Size $e.Size))" @{ Kind=$e.Kind; Path=$full; Size=$e.Size }
            if ($e.Kind -eq 'zip') { [void]$n.Nodes.Add((New-Placeholder)) }
            $list.Add($n)
        }
        if ($list.Count -gt 0) { $treeLib.Nodes.AddRange($list.ToArray()) }
    } finally { $treeLib.EndUpdate() }
    $tot = [FastIndex]::LastTotal
    $lblLibCount.Text = if ($tot -gt $max) { ((T "{0} premiers sur {1}") -f "$max", "$('{0:N0}' -f $tot)") } else { ((T "{0} résultat(s)") -f "$('{0:N0}' -f $tot)") }
}

function Update-Library {
    Stop-LibSearch
    $btnLibFilter.Enabled = $true
    $btnLibRefresh.Enabled = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    $treeLib.Nodes.Clear()
    $txtLibInfo.Clear()
    Set-LibWriteEnabled $false
    $btnLibOpen.Enabled = $false
    $lblLibCount.Text = ''

    $root = $txtLibRoot.Text
    if (-not $root -or -not (Test-Path -LiteralPath $root)) {
        if ($root) { $lblLibCount.Text = (T 'racine introuvable') }
        $txtLibInfo.Text = (T "Pour commencer :`r`n1. Choisissez le dossier racine de vos images (bouton ...).`r`n2. Dépliez l'arborescence ou utilisez la recherche.`r`n3. Sélectionnez une image puis « Écriture rapide » ou « Écriture lente ».")
        return
    }

    $filter = $txtLibFilter.Text.Trim()
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
    Set-LibWriteEnabled $false
    $btnLibOpen.Enabled = $false
    if (-not $node -or -not $node.Tag) { $txtLibInfo.Clear(); return }
    $t = $node.Tag
    $lines = @()
    switch ($t.Kind) {
        'dir' {
            $lines += (T 'Dossier')
            $lines += $t.Path
        }
        'zip' {
            $lines += (T 'Archive ZIP')
            $lines += "$(Format-Size $t.Size)"
            $lines += $t.Path
            $lines += ''
            $lines += (T 'Déplier le nœud pour lister le contenu.')
        }
        'zipentry' {
            $lines += ((T "Dans l'archive : {0}") -f "$([System.IO.Path]::GetFileName($t.ZipPath))")
            $lines += ((T "Entrée  : {0}") -f "$($t.Entry)")
            $lines += ((T "Taille  : {0}") -f "$(Format-Size $t.Size)")
            $lines += ''
            $lines += (T 'Extrait dans un dossier temporaire avant usage.')
            Set-LibWriteEnabled ($t.FileKind -eq 'image')
            $btnLibOpen.Enabled    = ($t.FileKind -eq 'doc')
        }
        'image' {
            $lines += ((T "Image disquette ({0})") -f "$([System.IO.Path]::GetExtension($t.Path))")
            $lines += ((T "Taille : {0}") -f "$(Format-Size $t.Size)")
            $lines += $t.Path
            Set-LibWriteEnabled $true
        }
        'doc' {
            $lines += ((T "Document ({0})") -f "$([System.IO.Path]::GetExtension($t.Path))")
            $lines += ((T "Taille : {0}") -f "$(Format-Size $t.Size)")
            $lines += $t.Path
            $btnLibOpen.Enabled = $true
        }
        default {
            $lines += (T 'Fichier non pris en charge')
            if ($t.Path) { $lines += $t.Path }
        }
    }
    $txtLibInfo.Text = $lines -join [Environment]::NewLine
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

function Resolve-LibSelection {
    # Image ou document selectionne : chemin (entree d archive extraite dans TempDir) et source unique (fichier, ou
    # archive + entree : deux archives peuvent extraire le meme nom de fichier)
    $n = $treeLib.SelectedNode
    if (-not $n -or -not $n.Tag) { return $null }
    $t = $n.Tag
    if ($t.Kind -eq 'zipentry') {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        try {
            $p = Expand-ZipEntry $t.ZipPath $t.Entry
            Append-Log ((T "Extrait : {0} -> {1}") -f "$($t.Entry)", "$p")
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
