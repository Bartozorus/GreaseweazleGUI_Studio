param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.12 : verification du contenu par l application, etape 1 (observation ; 170, 040).
#  K1 a K9  Compare-TrackContent sur des tours synthetiques (int[] en ns) : meme contenu a une autre vitesse et avec de la
#           gigue ; un intervalle change ; une transition perdue ; autre contenu ; erreur de lecture d un seul tour ;
#           ajout dans une zone de remplissage (vu dans un seul sens) ; ecarts de la zone de l index ignores ; cas non
#           comparables ; limite connue (transition perdue dans un remplissage uniforme, en debut de bloc).
#  A1       Get-ContentRefArgs : arguments de gw convert, --format et --diskdefs repris ; cas ou la comparaison ne
#           s applique pas.
#  S1       Start-ContentRef : gw introuvable, aucune exception, raison gardee ; rien quand la comparaison ne s applique pas.
#  C1 a C3  Add-ContentCheck et Get-ContentCheckText sur de vrais fichiers SCP ecrits par le test : piste identique,
#           piste differente, piste absente de la reference, piste reecrite relue a la passe suivante, reference
#           indisponible (code retour, attente depassee, fichier absent), second tour de la reference.
#  W1       cablage (statique) : la reference est lancee avant les relectures, hors de Start-Gw et de la chaine ; les
#           fonctions ajoutees n ecrivent ni l etat des pistes, ni les pistes faibles, ni la file des commandes.
# Fonctions reelles extraites par l arbre syntaxique, bloc C# ScpStats de 030 copie tel quel ; aucun gw, aucune fenetre.
# Non couvert ici : gw convert lui-meme et la relecture d une vraie disquette (essais sur materiel).
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Set-TestCulture
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mods = Join-Path $Wt 'src\modules'
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
$tFn = [System.Management.Automation.Language.FunctionDefinitionAst]
$tCmd = [System.Management.Automation.Language.CommandAst]
function Get-CcAst([string]$path) {
    $tk = $null; $er = $null
    $a = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message)" }
    return $a
}
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'
$all = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Where-Object { $_.Name -match '^[1-4]\d\d-fn-' } | Sort-Object Name)) {
    foreach ($fd in (Get-CcAst $f.FullName).FindAll({ param($x) $x -is $tFn }, $false)) { $all[$fd.Name] = $fd }
}
$new = @('Get-ContentRefArgs', 'Start-ContentRef', 'Get-ContentRef', 'Get-FluxTrimmed', 'Compare-TrackContent', 'Add-ContentCheck', 'Get-ContentCheckText')
$load = @($new + @('Read-ScpTrackRevs', 'Get-ScpRevTable', 'Get-TSpecExtras', 'Get-TrackKeyOrder', 'Sort-TrackKeys', 'Format-TrackList', 'Format-CylList', 'Add-UiTiming'))
$miss = @($load | Where-Object { -not $all.ContainsKey($_) })
if ($miss.Count) { throw "fonctions introuvables : $($miss -join ', ')" }
$cs = @((Get-CcAst (Join-Path $mods '030-csharp.ps1')).FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'Add-Type' -and $x.Extent.Text -like '*class ScpStats*' }, $true))
if ($cs.Count -ne 1) { throw "statement Add-Type ScpStats : $($cs.Count)" }
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine($cs[0].Extent.Text)
foreach ($n in $load) { [void]$sb.AppendLine($all[$n].Extent.Text); [void]$sb.AppendLine('') }
foreach ($st in (Get-CcAst (Join-Path $mods '040-etat-formats.ps1')).EndBlock.Statements) {
    if ($st -is [System.Management.Automation.Language.AssignmentStatementAst] -and $st.Left.Extent.Text -like '$script:ContentCheck*') { [void]$sb.AppendLine($st.Extent.Text) }
}
$gen = Join-Path $here 'gen-controle-contenu.ps1'
[System.IO.File]::WriteAllText($gen, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
$script:RLog = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text, $raw = $false) { $script:RLog.Add($text) }
$chkTime = $null
. $gen
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$cell = 2000.0
$rnd = New-Object System.Random(20261127)

# --- tours synthetiques ---------------------------------------------------------------------------------------------------
function New-CcClasses([int]$n) {
    # classes 2 / 3 / 4 (50 / 35 / 15 %) ; une zone de remplissage (classe 2) de 3 000 intervalles a partir de 16 000
    $c = New-Object 'int[]' $n
    for ($i = 0; $i -lt $n; $i++) { $u = $rnd.NextDouble(); $c[$i] = if ($u -lt 0.50) { 2 } elseif ($u -lt 0.85) { 3 } else { 4 } }
    for ($i = 16000; $i -lt 19000; $i++) { $c[$i] = 2 }
    return , $c
}
function ConvertTo-CcRev([int[]]$cls, [double]$speed = 1.0, [int]$jit = 0) {
    # @{ Flux ; DurNs } : intervalles de $cls a la cellule de 2 000 ns x $speed, gigue uniforme de +/- $jit ns
    $f = New-Object 'int[]' $cls.Length; [double]$t = 0
    for ($i = 0; $i -lt $cls.Length; $i++) { $f[$i] = [int]($cls[$i] * $cell * $speed) + $rnd.Next(-$jit, $jit + 1); $t += $f[$i] }
    return @{ Flux = $f; DurNs = $t }
}
function New-CcRevs($a, $b = $null, $c = $null) {
    $l = New-Object 'System.Collections.Generic.List[object]'
    foreach ($x in @($a, $b, $c)) { if ($null -ne $x) { $l.Add($x) } }
    return , $l
}
function Get-CcText($r) { if ($null -eq $r) { return 'rien' }; return "$($r.AB)/$($r.BA)/$($r.Miss)" }
$zone = [double]$script:ContentCheckZoneNs
$n = 46000
$cls = New-CcClasses $n
$ref = ConvertTo-CcRev $cls

'--- K. comparaison d une piste a son tour de reference'
$r1 = Compare-TrackContent $ref (New-CcRevs (ConvertTo-CcRev $cls 1.012 200) (ConvertTo-CcRev $cls 1.012 200) (ConvertTo-CcRev $cls 1.011 200)) ($cell * 1.012) $zone
Chk 'K1' ($r1 -and $r1.Miss -eq 0 -and $r1.Blocks -gt 1300) "meme contenu, vitesse +1,2 %, gigue de +/- 200 ns, trois tours : $(Get-CcText $r1) bloc(s) absent(s) (reference vers relu / relu vers reference / piste), $($r1.Blocks) blocs"

$c2 = [int[]]$cls.Clone(); $c2[30010] = if ($c2[30010] -eq 4) { 2 } else { 4 }
$r2 = Compare-TrackContent $ref (New-CcRevs (ConvertTo-CcRev $c2 1.012 200) (ConvertTo-CcRev $c2 1.012 200) (ConvertTo-CcRev $c2 1.012 200)) ($cell * 1.012) $zone
Chk 'K2' ($r2 -and $r2.AB -ge 1 -and $r2.BA -ge 1 -and $r2.Miss -le 2) "un intervalle change au milieu des donnees, sur les trois tours : $(Get-CcText $r2)"

$l3 = New-Object 'System.Collections.Generic.List[int]'
for ($i = 0; $i -lt $n; $i++) { if ($i -eq 30010) { $l3.Add([math]::Min(5, $cls[$i] + $cls[$i + 1])); $i++ } else { $l3.Add($cls[$i]) } }
$c3 = [int[]]$l3.ToArray()
$r3 = Compare-TrackContent $ref (New-CcRevs (ConvertTo-CcRev $c3 1.012 200) (ConvertTo-CcRev $c3 1.012 200) (ConvertTo-CcRev $c3 1.012 200)) ($cell * 1.012) $zone
Chk 'K3' ($r3 -and $r3.Miss -ge 1 -and $r3.Miss -le 3) "une transition perdue (la suite du tour est decalee d un intervalle, le suivi du decalage reprend) : $(Get-CcText $r3)"

$other = New-CcClasses $n
$r4 = Compare-TrackContent $ref (New-CcRevs (ConvertTo-CcRev $other 1.0 100) (ConvertTo-CcRev $other 1.0 100)) $cell $zone
Chk 'K4' ($r4 -and $r4.Miss -gt 0.8 * $r4.Blocks) "autre contenu : $(Get-CcText $r4) sur $($r4.Blocks) blocs"

$r5a = Compare-TrackContent $ref (New-CcRevs (ConvertTo-CcRev $c2 1.0 100) (ConvertTo-CcRev $cls 1.0 100) (ConvertTo-CcRev $cls 1.0 100)) $cell $zone
$r5b = Compare-TrackContent $ref (New-CcRevs (ConvertTo-CcRev $c2 1.0 100)) $cell $zone
Chk 'K5' ($r5a -and $r5a.Miss -eq 0 -and $r5b -and $r5b.Miss -ge 1) "erreur de lecture sur un seul des trois tours : $(Get-CcText $r5a) (le plus petit compte des tours) ; meme erreur sur l unique tour relu : $(Get-CcText $r5b)"

$c6 = [int[]]$cls.Clone(); foreach ($i in 17000..17063) { $c6[$i] = if ($i % 2) { 3 } else { 4 } }
$r6 = Compare-TrackContent $ref (New-CcRevs (ConvertTo-CcRev $c6 1.0 100) (ConvertTo-CcRev $c6 1.0 100)) $cell $zone
Chk 'K6' ($r6 -and $r6.BA -ge 1 -and $r6.Miss -ge 1) "64 intervalles ecrits dans la zone de remplissage de la reference : $(Get-CcText $r6) (le sens relu vers reference le voit)"

# zone de l index : 1 ms a chaque bout = 500 cellules, soit environ 190 intervalles de ce tour ; ecarts dans les 100 premiers
# et les 100 derniers intervalles
$c7 = [int[]]$cls.Clone(); foreach ($i in @(0..99) + @(($n - 100)..($n - 1))) { $c7[$i] = 5 }
$r7 = Compare-TrackContent $ref (New-CcRevs (ConvertTo-CcRev $c7 1.0 100) (ConvertTo-CcRev $c7 1.0 100)) $cell $zone
$t7 = Get-FluxTrimmed ([int[]]$ref.Flux) ([double]$ref.DurNs) $zone
$cut7 = [int][math]::Ceiling($n * $zone / [double]$ref.DurNs)
$t7e = Get-FluxTrimmed ([int[]]@(4000, 4000)) 8000.0 $zone
Chk 'K7' ($r7 -and $r7.Miss -eq 0 -and $t7.Length -eq $n - 2 * $cut7 -and $cut7 -gt 150 -and $cut7 -lt 260 -and $t7[0] -eq $ref.Flux[$cut7] -and $t7e.Length -eq 0) "ecarts a moins de 1 ms de l index (100 intervalles a chaque bout) : $(Get-CcText $r7) ; tour rogne de $cut7 intervalles a chaque bout ($($t7.Length) sur $n) ; tour plus court que la zone : $($t7e.Length) intervalle"

$r8 = @((Compare-TrackContent $ref (New-CcRevs (ConvertTo-CcRev $cls)) 1000.0 $zone), (Compare-TrackContent $ref (New-CcRevs (ConvertTo-CcRev $cls)) ([double]::NaN) $zone),
        (Compare-TrackContent $null (New-CcRevs (ConvertTo-CcRev $cls)) $cell $zone), (Compare-TrackContent $ref $null $cell $zone),
        (Compare-TrackContent (ConvertTo-CcRev ([int[]]$cls[0..600])) (New-CcRevs (ConvertTo-CcRev $cls)) $cell $zone), (Compare-TrackContent $ref (New-CcRevs) $cell $zone))
Chk 'K8' (@($r8 | Where-Object { $null -ne $_ }).Count -eq 0) "non comparable : cellule de 1 000 ns (haute densite), cellule non mesuree, pas de reference, pas de tour relu, reference trop courte, liste de tours vide -> rien ($(@($r8 | ForEach-Object { Get-CcText $_ }) -join ', '))"

# Limite connue : dans une zone de remplissage uniforme, une transition perdue au debut d un bloc donne un bloc qui existe
# ailleurs dans la reference (fin de donnees suivie du remplissage) : non vue. Le cas est fige pour signaler tout changement
$p9 = 16000 + 32 * 20; while (($p9 - [int][math]::Ceiling($n * $zone / [double]$ref.DurNs)) % 32 -ne 0) { $p9++ }
$l9 = New-Object 'System.Collections.Generic.List[int]'
for ($i = 0; $i -lt $n; $i++) { if ($i -eq $p9) { $l9.Add(4); $i++ } else { $l9.Add($cls[$i]) } }
$c9 = [int[]]$l9.ToArray()
$r9 = Compare-TrackContent $ref (New-CcRevs (ConvertTo-CcRev $c9) (ConvertTo-CcRev $c9)) $cell $zone
Chk 'K9' ($r9 -and $r9.AB -eq 0 -and $r9.Miss -le 1) "limite connue, transition perdue dans le remplissage uniforme : $(Get-CcText $r9) (zero ou un bloc : une erreur de ce genre peut ne pas se voir)"

'--- A. arguments de gw convert'
$script:TempDir = Join-Path $here 'tmp'; $script:AppDir = $here; $script:Restore = $null
function New-CcRep([hashtable]$set = @{}) {
    $r = @{ Image = 'D:\jeux\image factice.ipf'; Base = @('write', '--drive=0', '--retries=10', '--erase-empty'); UserTSpec = ''; EraseMode = 'hfreq'
            Scps = @(); State = @{}; Weak = @(); Pending = (New-Object System.Collections.Queue); Round = 0; Max = 3 }
    foreach ($k in @($set.Keys)) { $r[$k] = $set[$k] }
    return $r
}
$refPath = Join-Path $script:TempDir 'contenu-ref.scp'
$a1 = Get-ContentRefArgs (New-CcRep)
$a2 = Get-ContentRefArgs (New-CcRep @{ Image = 'x.adf'; Base = @('write', '--drive=0', '--format=amiga.amigados', '--diskdefs="d:\mes defs.cfg"', '--retries=10') })
$a1ok = (($a1 -join '|') -ceq ('convert|"D:\jeux\image factice.ipf"|"' + $refPath + '"') -and ($a2 -join '|') -ceq ('convert|--format=amiga.amigados|--diskdefs="d:\mes defs.cfg"|"x.adf"|"' + $refPath + '"'))
$no = [ordered]@{
    'haute densite' = (New-CcRep @{ EraseMode = 'pre' }); 'face retournee' = (New-CcRep @{ Base = @('write', '--reverse') }); 'secteurs durs' = (New-CcRep @{ Base = @('write', '--hard-sectors') })
    'TG43' = (New-CcRep @{ Base = @('write', '--gen-tg43') }); 'index simule' = (New-CcRep @{ Base = @('write', '--fake-index=300rpm') }); 'densite forcee' = (New-CcRep @{ Base = @('write', '--densel=H') })
    'hswap' = (New-CcRep @{ UserTSpec = 'c=0-79:hswap' }); 'pas double' = (New-CcRep @{ UserTSpec = 'c=0-39:step=2' }); 'sans image' = (New-CcRep @{ Image = '' })
}
$a1no = @(foreach ($k in @($no.Keys)) { if ($null -ne (Get-ContentRefArgs $no[$k])) { $k } })
$script:Restore = @{ Step = 1 }; $a1r = ($null -eq (Get-ContentRefArgs (New-CcRep))); $script:Restore = $null
$script:ContentCheckOn = $false; $a1off = ($null -eq (Get-ContentRefArgs (New-CcRep))); $script:ContentCheckOn = $true
$a1c = ($null -ne (Get-ContentRefArgs (New-CcRep @{ UserTSpec = 'c=0-39:h=0' })))
Chk 'A1' ($a1ok -and $a1no.Count -eq 0 -and $a1r -and $a1off -and $a1c) "gw convert <image> <reference> ; --format et --diskdefs de l ecriture repris, ses autres options non ($a1ok) ; champ Pistes limite a c= et h= : compare ($a1c) ; non applicable : $(@($no.Keys) -join ', ') (en defaut : $(if ($a1no.Count) { $a1no -join ', ' } else { 'aucun' })), restauration ($a1r), constante ContentCheckOn fausse ($a1off)"

'--- S. lancement de la reference'
$script:GwExe = Join-Path $here 'absent\gw.exe'
$rs = New-CcRep; $sErr = ''
try { Start-ContentRef $rs } catch { $sErr = "$($_.Exception.Message)" }
$rsNo = New-CcRep @{ EraseMode = 'pre'; Content = 'ancien' }; Start-ContentRef $rsNo
$s1t = Get-ContentCheckText $rs
Add-ContentCheck $rs @('0.0')
Chk 'S1' (-not $sErr -and $rs.Content -and [string]$rs.Content.Why -clike 'gw convert non lancé (*' -and $null -eq $rs.Content.Proc -and $rs.Content.Done.Count -eq 0 -and $null -eq $rsNo.Content -and $s1t -clike "Vérification du contenu (à l'essai) : non faite, gw convert non lancé (*). La vérification de gw et le contrôle n'en dépendent pas." -and (Get-ContentCheckText $rsNo) -ceq '') "gw introuvable : aucune exception ($(-not $sErr)), raison gardee et dite a la fin du controle, aucune piste comparee ; comparaison non applicable : rien de lance, Rep.Content vide, aucune ligne"

'--- C. comparaison au controle, sur des fichiers SCP ecrits par le test'
function Write-CcScp([string]$path, $tracks, [int]$revs) {
    # SCP minimal : en-tete de 16 octets, table de 168 decalages, par piste « TRK », numero, puis par tour duree (tics de
    # 25 ns), nombre d intervalles et decalage des donnees ; intervalles en mots de 16 bits, poids fort d abord
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $hd = New-Object 'byte[]' (16 + 4 * 168); $hd[0] = 0x53; $hd[1] = 0x43; $hd[2] = 0x50; $hd[5] = [byte]$revs; $hd[8] = 0x03
    $bw.Write($hd)
    $offs = @{}
    foreach ($tn in @($tracks.Keys | Sort-Object)) {
        $offs[[int]$tn] = [int]$ms.Position
        $list = $tracks[$tn]
        $bw.Write([byte[]]@(0x54, 0x52, 0x4B, [byte]$tn))
        [int]$doff = 4 + 12 * $revs
        for ($r = 0; $r -lt $revs; $r++) {
            $f = [int[]]$list[$r].Flux
            $bw.Write([uint32][math]::Round([double]$list[$r].DurNs / 25)); $bw.Write([uint32]$f.Length); $bw.Write([uint32]$doff)
            $doff += 2 * $f.Length
        }
        for ($r = 0; $r -lt $revs; $r++) {
            $f = [int[]]$list[$r].Flux; $b = New-Object 'byte[]' (2 * $f.Length)
            for ($i = 0; $i -lt $f.Length; $i++) { $v = [int]($f[$i] / 25); $b[2 * $i] = [byte]($v -shr 8); $b[2 * $i + 1] = [byte]($v -band 255) }
            $bw.Write($b)
        }
    }
    $bw.Flush(); $d = $ms.ToArray(); $bw.Dispose()
    foreach ($tn in @($offs.Keys)) { [array]::Copy([BitConverter]::GetBytes([uint32]$offs[$tn]), 0, $d, 16 + 4 * $tn, 4) }
    [System.IO.File]::WriteAllBytes($path, $d)
}
function ConvertTo-CcRev25([int[]]$cls, [double]$speed = 1.0, [int]$jit = 0) {
    # comme ConvertTo-CcRev, intervalles multiples de 25 ns (resolution du fichier)
    $r = ConvertTo-CcRev $cls $speed $jit; [double]$t = 0
    for ($i = 0; $i -lt $r.Flux.Length; $i++) { $r.Flux[$i] = 25 * [int][math]::Round($r.Flux[$i] / 25); $t += $r.Flux[$i] }
    $r.DurNs = $t
    return $r
}
function New-CcProc([int]$code = 0, [bool]$done = $true) {
    $p = New-Object psobject -Property @{ ExitCode = $code; Done = $done }
    $p | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param($ms) return [bool]$this.Done }
    return $p
}
if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
$m = 20000
$tA = New-CcClasses $m; $tB = New-CcClasses $m; $tC = New-CcClasses $m; $tD = New-CcClasses $m
$tBx = [int[]]$tB.Clone(); $tBx[9000] = if ($tBx[9000] -eq 4) { 2 } else { 4 }
$refFile = Join-Path $script:TempDir 'contenu-ref.scp'
# reference : pistes 0.0 (0), 0.1 (1) et 2.0 (4) ; son premier tour de la piste 2.0 porte une erreur, le second non
$tDx = [int[]]$tD.Clone(); $tDx[5000] = if ($tDx[5000] -eq 4) { 2 } else { 4 }
Write-CcScp $refFile @{ 0 = @((ConvertTo-CcRev25 $tA), (ConvertTo-CcRev25 $tA)); 1 = @((ConvertTo-CcRev25 $tB), (ConvertTo-CcRev25 $tB)); 4 = @((ConvertTo-CcRev25 $tDx), (ConvertTo-CcRev25 $tD)) } 2
$rd0 = Join-Path $script:TempDir 'check-r0-0.scp'
# relecture : 0.0 identique, 0.1 avec un intervalle change, 1.0 (2) absente de la reference, 2.0 identique a l image
Write-CcScp $rd0 @{ 0 = @((ConvertTo-CcRev25 $tA 1.01 150), (ConvertTo-CcRev25 $tA 1.01 150), (ConvertTo-CcRev25 $tA 1.01 150))
                    1 = @((ConvertTo-CcRev25 $tBx 1.01 150), (ConvertTo-CcRev25 $tBx 1.01 150), (ConvertTo-CcRev25 $tBx 1.01 150))
                    2 = @((ConvertTo-CcRev25 $tC 1.01 150), (ConvertTo-CcRev25 $tC 1.01 150), (ConvertTo-CcRev25 $tC 1.01 150))
                    4 = @((ConvertTo-CcRev25 $tD 1.01 150), (ConvertTo-CcRev25 $tD 1.01 150), (ConvertTo-CcRev25 $tD 1.01 150)) } 3
$keys = @('0.0', '0.1', '1.0', '2.0', '3.0')
function New-CcCheckRep($proc) {
    $r = New-CcRep @{ Scps = @($rd0) }
    foreach ($k in $keys) { $r.State[$k] = @{ Cell = 2020.0; Missing = ($k -ceq '3.0'); Bad = $false; Level = 0 } }
    $r.Content = @{ Path = $refFile; Proc = $proc; Why = ''; Ref = $null; Done = @{}; Skip = @{} }
    return $r
}
$rc = New-CcCheckRep (New-CcProc)
$before = "$($rc.Weak.Count)/$($rc.Pending.Count)/$($rc.Round)/$(@($rc.State.Keys | Sort-Object) -join ',')"
Add-ContentCheck $rc $keys
$after = "$($rc.Weak.Count)/$($rc.Pending.Count)/$($rc.Round)/$(@($rc.State.Keys | Sort-Object) -join ',')"
$d1 = "0.0=$($rc.Content.Done['0.0']) 0.1=$(if ([int]$rc.Content.Done['0.1'] -ge 1) { 'diff' } else { $rc.Content.Done['0.1'] }) 2.0=$($rc.Content.Done['2.0']) ; non comparees : $(@($rc.Content.Skip.Keys | Sort-Object) -join ',')"
$txt1 = Get-ContentCheckText $rc
$want1 = "Vérification du contenu (à l'essai) : 3 piste(s) comparée(s) au flux que gw tire de l'image, 1 différente(s) : 0.1 ; 1 piste(s) non comparée(s). Ce constat ne change ni l'état des pistes ni les réécritures."
Chk 'C1' ($d1 -ceq '0.0=0 0.1=diff 2.0=0 ; non comparees : 1.0' -and -not $rc.Content.Why -and $before -ceq $after -and $txt1 -ceq $want1) "controle complet : $d1 (piste 1.0 absente de la reference ; piste 3.0 attendue mais absente de la relecture : hors de la comparaison, le controle la dit illisible ; piste 2.0 : le premier tour de la reference porte une erreur, le second concorde) ; etat du controle inchange ($($before -ceq $after)) ; ligne : $txt1"

# passe de reecriture : la piste 0.1 est relue, cette fois identique
$rd1 = Join-Path $script:TempDir 'check-r1-0.scp'
Write-CcScp $rd1 @{ 1 = @((ConvertTo-CcRev25 $tB 1.01 150), (ConvertTo-CcRev25 $tB 1.01 150), (ConvertTo-CcRev25 $tB 1.01 150)) } 3
$rc.Scps = @($rd1); $rc.Round = 1
Add-ContentCheck $rc @('0.1')
$txt2 = Get-ContentCheckText $rc
$want2 = "Vérification du contenu (à l'essai) : 3 piste(s) comparée(s) au flux que gw tire de l'image, aucune différence ; 1 piste(s) non comparée(s)."
Chk 'C2' ([int]$rc.Content.Done['0.1'] -eq 0 -and $rc.Content.Done.Count -eq 3 -and $txt2 -ceq $want2) "piste 0.1 reecrite puis relue identique : son resultat est remplace ($($rc.Content.Done['0.1'])), les autres gardes ; ligne : $txt2"

$why = @()
foreach ($pc in @((New-CcProc 1), (New-CcProc 0 $false), $null)) {
    $rx = New-CcCheckRep $pc
    Add-ContentCheck $rx $keys; Add-ContentCheck $rx $keys
    $why += "$($rx.Content.Why)|$($rx.Content.Done.Count)"
}
$rx = New-CcCheckRep (New-CcProc); $rx.Content.Path = Join-Path $script:TempDir 'absent.scp'; Add-ContentCheck $rx $keys; $why += "$($rx.Content.Why)|$($rx.Content.Done.Count)"
$bad = Join-Path $script:TempDir 'illisible.scp'; [System.IO.File]::WriteAllBytes($bad, [byte[]]@(1, 2, 3))
$rx = New-CcCheckRep (New-CcProc); $rx.Content.Path = $bad; Add-ContentCheck $rx $keys; $why += "$($rx.Content.Why)|$($rx.Content.Done.Count)"
$rn = New-CcRep @{ Scps = @($rd0) }; $nErr = ''; try { Add-ContentCheck $rn $keys } catch { $nErr = "$($_.Exception.Message)" }
$wantWhy = 'gw convert a rendu le code 1|0 ; gw convert non terminé après 15 s|0 ; gw convert non lancé|0 ; fichier de référence absent|0 ; fichier de référence illisible|0'
Chk 'C3' (($why -join ' ; ') -ceq $wantWhy -and -not $nErr -and (Get-ContentCheckText $rn) -ceq '') "reference indisponible, raison et pistes comparees : $($why -join ' ; ') ; controle sans comparaison lancee (Rep.Content absent) : rien, aucune erreur ($(-not $nErr))"

'--- W. cablage'
$swc = $all['Start-WriteCheck'].Extent.Text; $iwa = $all['Invoke-WriteCheckAnalysis'].Extent.Text; $cwc = $all['Complete-WriteCheck'].Extent.Text
$w1a = ($swc.IndexOf('Start-ContentRef $rep') -gt 0 -and $swc.IndexOf('Start-ContentRef $rep') -lt $swc.IndexOf('Add-RepReads $groups') -and $iwa.Contains('Add-ContentCheck $rep $expected') -and $cwc.Contains('$ctl = Get-ContentCheckText $rep; if ($ctl) { Append-Log $ctl }'))
# commandes appelees (arbre syntaxique) et ecritures de l etat du controle (texte sans les lignes de commentaire)
$w1b = @($new | Where-Object {
    $fd = $all[$_]
    $calls = @($fd.Body.FindAll({ param($x) $x -is $tCmd }, $true) | ForEach-Object { [string]$_.GetCommandName() })
    $code = (@($fd.Extent.Text -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
    @($calls | Where-Object { @('Start-Gw', 'Invoke-NextChainStep', 'Stop-WriteCheck', 'Complete-WriteCheck', 'Reset-GwSequence', 'Start-RepPending', 'Add-RepReads') -contains $_ }).Count -gt 0 -or
    $code -match '\$script:Chain|\.Pending|\.Weak\b|\.Rewrites|\.State\[[^\]]+\]\s*=|\.Round\s*(=|\+\+)'
})
$w1c = @($all.Keys | Where-Object { $new -notcontains $_ -and $all[$_].Extent.Text -match '\.Content\.(Done|Skip|Why|Ref|Proc)|Get-ContentRef\b|Compare-TrackContent' })
Chk 'W1' ($w1a -and $w1b.Count -eq 0 -and $w1c.Count -eq 0) "Start-WriteCheck lance la reference avant les relectures, Invoke-WriteCheckAnalysis compare, Complete-WriteCheck ecrit la ligne ($w1a) ; les $($new.Count) fonctions ajoutees n appellent ni Start-Gw ni la chaine et n ecrivent ni l etat des pistes, ni les pistes faibles, ni la file (en defaut : $(if ($w1b.Count) { $w1b -join ', ' } else { 'aucune' })) ; aucune autre fonction ne lit le resultat de la comparaison (en defaut : $(if ($w1c.Count) { $w1c -join ', ' } else { 'aucune' }))"

foreach ($p in @($gen, $refFile, $rd0, $rd1, $bad)) { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force } }
$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-controle-contenu : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
