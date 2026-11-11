param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : lancement de gw en trois temps (Start-Gw, 110). Jusqu a la 12.10, un seul try couvrait Process.Start et la suite
# du demarrage : une exception apres le demarrage passait pour un echec du lancement, et gw tournait sans suivi (sortie
# non lue, fin non traitee, « Arreter » sans effet, autre commande possible).
#  G1 (arbre syntaxique) un seul try contient l appel de demarrage ; c est une instruction du premier niveau de Start-Gw,
#     son corps ne contient que cet appel ; son catch garde la ligne « ERREUR lancement », la remise a zero du suivi et
#     l ordre Reset-GwSequence, Set-GwLaunchFailedStatus, Set-Busy $false, et finit par return ;
#  G2 le suivi du processus ($script:GwProc = $p, puis GwSoft et GwDriveKey) est pose hors de tout try, aussitot apres ce
#     try et avant le second, sans rien d autre entre les deux ; G2b Start-Gw ne touche plus au suivi ensuite ;
#  G3 second try : flux de gw, Set-Busy $true, Set-QualityStale, Hide-WCalVerdict ; son catch : une ligne de journal (texte
#     de la specification), Set-Busy $true dans un try au catch vide, rien d autre (ni suivi, ni sequence, ni barre
#     d etat) ; Set-GwLaunchFailedStatus appelee une seule fois dans les modules, dans le catch du premier try ;
#  G4 execution du texte reel du second try, extrait par l arbre syntaxique et place dans une fonction du dossier de
#     travail, avec un faux processus (deux lecteurs de texte, aucun processus lance) et des bouchons :
#     G4v le second try n emploie que des variables et des commandes que ce test fournit ;
#     G4a Set-Busy qui leve : une ligne de journal, suivi intact, sequence gardee, nouvel essai de Set-Busy absorbe ;
#     G4b Set-QualityStale qui leve : meme attendu, Set-Busy $true appelee ;
#     G4c sans exception : aucune ligne, taches de lecture posees, lues par la vraie Drain-GwReader ;
#     G4d flux qui levent (flux ferme) : une ligne, Set-Busy $true tentee, taches nulles acceptees par Drain-GwReader ;
#     G4e resultat de l onglet Qualite perime pour une ecriture ou un effacement hors controle seulement ;
#     G4f ligne en anglais ; couleur d erreur de la vraie Get-LogColor dans les deux langues (le journal masque s ouvre) ;
#  G5 cas R9 a R13 du test de la barre d etat de la restauration (logic-barre-etat-restauration), lance tel quel dans un
#     processus de la meme edition : conformes.
# Fonctions et instructions reelles extraites par l arbre syntaxique, ecrites dans un fichier de travail puis chargees par
# dot-source. Aucun gw, aucun processus gw, aucune fenetre, aucune compilation. Non couvert : Start-Gw executee en entier
# (elle lancerait gw) ; une exception du journal lui-meme dans le second catch.
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
function Get-Ast([string]$file) {
    $tk = $null; $er = $null
    $a = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $file : $(@($er)[0].Message)" }
    return $a
}
function Get-List($a, [int]$max = 6) {
    $x = @($a); if ($x.Count -eq 0) { return 'aucun' }
    $t = (@($x | Select-Object -First $max) -join ' | '); if ($x.Count -gt $max) { $t += " | ... ($($x.Count))" }
    return $t
}
$tTry = [System.Management.Automation.Language.TryStatementAst]
$tCmd = [System.Management.Automation.Language.CommandAst]
$tAsg = [System.Management.Automation.Language.AssignmentStatementAst]
$tVar = [System.Management.Automation.Language.VariableExpressionAst]
$tFn = [System.Management.Automation.Language.FunctionDefinitionAst]
$tStr = [System.Management.Automation.Language.StringConstantExpressionAst]
$tRet = [System.Management.Automation.Language.ReturnStatementAst]
$ord = [System.StringComparison]::Ordinal

# Textes de la specification (lot1-simple, C.2) : cle francaise du journal et texte anglais attendu dans 019
$msgKey = "gw est lancé, mais une erreur a suivi son démarrage : {0}. La commande reste suivie jusqu'à sa fin ; « Arrêter » l'interrompt."
$msgEn = 'gw has started, but an error followed its start: {0}. The command is still tracked until it ends; "Stop" interrupts it.'

$mods = Join-Path $Wt 'src\modules'
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' -File | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'

# --- Fonctions des modules et appels de Set-GwLaunchFailedStatus (tous les modules)
$fns = @{}; $lfCalls = @()
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Sort-Object Name)) {
    $a = Get-Ast $f.FullName
    foreach ($fd in @($a.FindAll({ param($n) $n -is $tFn }, $false))) { $fns[$fd.Name] = $fd }
    foreach ($c in @($a.FindAll({ param($n) $n -is $tCmd -and $n.GetCommandName() -eq 'Set-GwLaunchFailedStatus' }, $true))) { $lfCalls += @{ File = $f.Name; Ast = $c } }
}
foreach ($x in 'Start-Gw', 'Drain-GwReader', 'Get-LogColor') { if (-not $fns.ContainsKey($x)) { throw "fonction $x introuvable dans les modules" } }
$sg = $fns['Start-Gw']
$top = @($sg.Body.EndBlock.Statements)
function Get-TopIndex($node) {
    # Rang du noeud parmi les instructions du premier niveau de Start-Gw ; -1 s il n en est pas une
    for ($i = 0; $i -lt $top.Count; $i++) { if ([object]::ReferenceEquals($top[$i], $node)) { return $i } }
    return -1
}
function Test-InTry($node) {
    # Vrai si un try de Start-Gw contient le noeud
    $x = $node.Parent
    while ($null -ne $x -and -not [object]::ReferenceEquals($x, $sg)) {
        if ($x -is $tTry) { return $true }
        $x = $x.Parent
    }
    return $false
}
function Get-Cmds($ast) { return @($ast.FindAll({ param($n) $n -is $tCmd }, $true)) }
function Get-CmdNames($ast) { return @(Get-Cmds $ast | ForEach-Object { [string]$_.GetCommandName() }) }
function Get-Assign($ast, [string]$var) {
    # Affectations de la variable $var (« script:GwProc ») dans $ast
    return @($ast.FindAll({ param($n) $n -is $tAsg -and $n.Left -is $tVar -and $n.Left.VariablePath.UserPath -eq $var }, $true))
}
function Get-LogKeys($ast) {
    # Cles litterales des appels de T places dans un appel de Append-Log
    $k = @()
    foreach ($c in @(Get-Cmds $ast | Where-Object { $_.GetCommandName() -eq 'Append-Log' })) {
        foreach ($t in @(Get-Cmds $c | Where-Object { $_.GetCommandName() -eq 'T' })) {
            if ($t.CommandElements.Count -eq 2 -and $t.CommandElements[1] -is $tStr) { $k += [string]$t.CommandElements[1].Value }
        }
    }
    return $k
}
function Get-BusyArg($ast) {
    # Argument de l unique appel de Set-Busy de $ast (« $true », « $false ») ; '' s il n y en a pas un seul
    $b = @(Get-Cmds $ast | Where-Object { $_.GetCommandName() -eq 'Set-Busy' })
    if ($b.Count -ne 1 -or $b[0].CommandElements.Count -ne 2) { return '' }
    return [string]$b[0].CommandElements[1].Extent.Text
}

# --- Les deux try du premier niveau : celui du demarrage (meme critere que le cas R10 de la barre d etat), puis le suivant
$tries = @($sg.Body.FindAll({ param($n) $n -is $tTry }, $true))
$withStart = @($tries | Where-Object { $_.Body.Extent.Text.Contains('$p.Start()') })
$t1 = $null; $i1 = -1; $t2 = $null; $i2 = -1; $c1 = $null; $c2 = $null
if ($withStart.Count -eq 1) {
    $t1 = $withStart[0]; $i1 = Get-TopIndex $t1
    if ($i1 -ge 0) { for ($i = $i1 + 1; $i -lt $top.Count; $i++) { if ($top[$i] -is $tTry) { $t2 = $top[$i]; $i2 = $i; break } } }
}
"source : $Wt ; Start-Gw : $($top.Count) instructions de premier niveau, $($tries.Count) try, dont $($withStart.Count) avec l appel de demarrage (rang $i1) ; second try de premier niveau : rang $i2"

# --- G1 : premier try
$g1Body = $false; $g1Seq = ''; $g1Ret = $false; $g1Keep = $false; $n1 = 0
if ($t1) {
    $st = @($t1.Body.Statements); $n1 = $st.Count
    $g1Body = ($st.Count -eq 1 -and $st[0].Extent.Text.Trim() -ceq '[void]$p.Start()')
    if ($t1.CatchClauses.Count -eq 1 -and $t1.CatchClauses[0].IsCatchAll -and $null -eq $t1.Finally) {
        $c1 = $t1.CatchClauses[0].Body
        $g1Seq = (@(Get-CmdNames $c1 | Where-Object { $_ -in 'Reset-GwSequence', 'Set-GwLaunchFailedStatus', 'Set-Busy' }) -join ',')
        $cst = @($c1.Statements)
        $g1Ret = ($cst.Count -gt 0 -and $cst[$cst.Count - 1] -is $tRet -and $null -eq $cst[$cst.Count - 1].Pipeline)
        $g1Keep = ((@(Get-LogKeys $c1) -join '|') -ceq 'ERREUR lancement : {0}' -and @(Get-Assign $c1 'script:GwProc' | Where-Object { $_.Right.Extent.Text.Trim() -ceq '$null' }).Count -eq 1 -and $c1.Extent.Text.Contains('$script:OpOverride.Written = $false') -and (Get-BusyArg $c1) -ceq '$false')
    }
}
Chk 'G1' ($withStart.Count -eq 1 -and $i1 -ge 0 -and $g1Body -and $g1Seq -ceq 'Reset-GwSequence,Set-GwLaunchFailedStatus,Set-Busy' -and $g1Ret -and $g1Keep) "un seul try contient l appel de demarrage ($($withStart.Count)), au premier niveau de Start-Gw (rang $i1) ; son corps ne contient que cet appel ($n1 instruction(s) : $g1Body) ; catch : ligne « ERREUR lancement », suivi remis a zero, Set-Busy `$false ($g1Keep), ordre « $g1Seq », return final ($g1Ret)"

# --- G2 : suivi pose hors de tout try, entre les deux try
$asgP = @(Get-Assign $sg.Body 'script:GwProc')
$setP = @($asgP | Where-Object { $_.Right.Extent.Text.Trim() -ceq '$p' })
$ip = -1; $g2Out = $false; $between = @()
if ($setP.Count -eq 1) { $ip = Get-TopIndex $setP[0]; $g2Out = -not (Test-InTry $setP[0]) }
if ($i1 -ge 0 -and $i2 -gt $i1 + 1) { $between = @($top[($i1 + 1)..($i2 - 1)]) }
$btw = @($between | ForEach-Object { if ($_ -is $tAsg -and $_.Left -is $tVar) { "$($_.Left.VariablePath.UserPath)=$($_.Right.Extent.Text.Trim())" } else { 'autre instruction' } })
Chk 'G2' ($setP.Count -eq 1 -and $g2Out -and $i1 -ge 0 -and $ip -eq $i1 + 1 -and $i2 -gt $ip -and ($btw -join ' ; ') -ceq 'script:GwProc=$p ; script:GwSoft=$warmRead ; script:GwDriveKey=$driveKey') "`$script:GwProc = `$p : $($setP.Count) fois, hors de tout try ($g2Out), rang $ip, aussitot apres le try du demarrage (rang $i1) et avant le second (rang $i2) ; entre les deux : $(Get-List $btw)"
$after = @(); if ($setP.Count -eq 1) { $after = @($asgP | Where-Object { $_.Extent.StartOffset -gt $setP[0].Extent.StartOffset }) }
Chk 'G2b' ($setP.Count -eq 1 -and $after.Count -eq 0 -and $asgP.Count -eq 2) "Start-Gw ne touche plus a `$script:GwProc apres l avoir pose : $($after.Count) affectation(s) ensuite, $($asgP.Count) en tout (2 attendues : remise a zero du catch du demarrage, puis pose)"

# --- G3 : second try et son catch
$g3Body = $false; $g3Catch = $false; $extra = @(); $nAsg = -1; $okIn = $false; $key2 = ''
if ($t2) {
    $b2 = @(Get-CmdNames $t2.Body)
    $streams = @('script:OutStdoutReader', 'script:OutStderrReader', 'script:OutStdoutTask', 'script:OutStderrTask' | Where-Object { @(Get-Assign $t2.Body $_).Count -eq 1 })
    $g3Body = ((Get-BusyArg $t2.Body) -ceq '$true' -and ($b2 -contains 'Set-QualityStale') -and ($b2 -contains 'Hide-WCalVerdict') -and $streams.Count -eq 4)
    if ($t2.CatchClauses.Count -eq 1 -and $t2.CatchClauses[0].IsCatchAll -and $null -eq $t2.Finally) {
        $c2 = $t2.CatchClauses[0].Body
        $c2Names = @(Get-CmdNames $c2)
        $extra = @($c2Names | Where-Object { $_ -notin 'Append-Log', 'T', 'Set-Busy' } | Sort-Object -Unique)
        $in2 = @($c2.FindAll({ param($n) $n -is $tTry }, $true))
        if ($in2.Count -eq 1) {
            $s2 = @($in2[0].Body.Statements)
            $okIn = ($s2.Count -eq 1 -and ($s2[0].Extent.Text.Trim() -replace '\s+', ' ') -ceq 'Set-Busy $true' -and $null -eq $in2[0].Finally -and $in2[0].CatchClauses.Count -eq 1 -and $in2[0].CatchClauses[0].IsCatchAll -and @($in2[0].CatchClauses[0].Body.Statements).Count -eq 0)
        }
        $nAsg = @($c2.FindAll({ param($n) $n -is $tAsg }, $true)).Count
        $key2 = (@(Get-LogKeys $c2) -join '|')
        $g3Catch = ($key2 -ceq $msgKey -and $extra.Count -eq 0 -and @($c2Names | Where-Object { $_ -eq 'Append-Log' }).Count -eq 1 -and (Get-BusyArg $c2) -ceq '$true' -and $okIn -and $nAsg -eq 0)
    }
}
$g3One = ($lfCalls.Count -eq 1 -and $null -ne $c1 -and $lfCalls[0].File -like '110-*' -and $lfCalls[0].Ast.Extent.StartOffset -ge $c1.Extent.StartOffset -and $lfCalls[0].Ast.Extent.EndOffset -le $c1.Extent.EndOffset)
Chk 'G3' ($null -ne $t2 -and $g3Body -and $g3Catch -and $g3One) "second try (rang $i2) : flux de gw, Set-Busy `$true, Set-QualityStale, Hide-WCalVerdict ($g3Body) ; son catch : ligne de journal de la specification ($($key2 -ceq $msgKey)), Set-Busy `$true dans un try au catch vide ($okIn), autres commandes : $(Get-List $extra), affectations : $nAsg ; Set-GwLaunchFailedStatus : $($lfCalls.Count) appel(s) dans les modules, dans le catch du demarrage ($g3One)"

# --- G4 : execution du texte reel du second try
$nl = "`r`n"
$code = $fns['Drain-GwReader'].Extent.Text + $nl + $nl + $fns['Get-LogColor'].Extent.Text + $nl
# Aucune preference d erreur dans les modules : le bloc s execute avec celle de l application ('Continue')
if ($t2) { $code += $nl + 'function Invoke-GwAfterStart($p, [string]$first) {' + $nl + "    `$ErrorActionPreference = 'Continue'" + $nl + '    ' + $t2.Extent.Text + $nl + '}' + $nl }
$gen = Join-Path $here 'gen-gw-lancement.ps1'
[System.IO.File]::WriteAllText($gen, $code, (New-Object System.Text.UTF8Encoding($true)))

$script:Calls = New-Object System.Collections.Generic.List[string]
$script:ThrowAt = ''
function Append-Log($t) { $script:Calls.Add("Append-Log $t") }
function Set-Busy([bool]$busy) { $script:Calls.Add("Set-Busy $busy"); if ($script:ThrowAt -eq 'busy') { throw 'panne simulee de Set-Busy' } }
function Set-QualityStale([string]$reason) { $script:Calls.Add("Set-QualityStale $reason"); if ($script:ThrowAt -eq 'stale') { throw 'panne simulee de Set-QualityStale' } }
function Hide-WCalVerdict { $script:Calls.Add('Hide-WCalVerdict') }
function Reset-GwSequence { $script:Calls.Add('Reset-GwSequence') }
function Set-GwLaunchFailedStatus { $script:Calls.Add('Set-GwLaunchFailedStatus') }
. $gen
function Get-CallsPre([string]$pre) { return @($script:Calls | Where-Object { ([string]$_).StartsWith($pre, $ord) }) }
function New-FakeProc([string]$out, [string]$err, [switch]$Closed) {
    # Faux processus : deux vrais lecteurs de texte a la place des flux de gw. -Closed : flux de sortie ferme, sa lecture leve
    $ro = [System.IO.StringReader]::new($out); $re = [System.IO.StringReader]::new($err)
    if ($Closed) { $ro.Dispose() }
    return @{ StandardOutput = $ro; StandardError = $re }
}
function Invoke-Case([string]$first, [string]$throwAt, $proc, $rep = $null) {
    # Etat de Start-Gw a l entree du second try : suivi pose (temps 2), flux de la commande precedente remis a zero par
    # le minuteur (600). Rend ce que le bloc a fait
    $script:Calls.Clear(); $script:ThrowAt = $throwAt; $script:Rep = $rep
    $script:OutStdoutReader = $null; $script:OutStderrReader = $null; $script:OutStdoutTask = $null; $script:OutStderrTask = $null
    $script:OutQueue = New-Object System.Collections.Queue
    $script:GwProc = $proc
    $esc = $false; $o = @()
    try { $o = @(Invoke-GwAfterStart $proc $first) } catch { $esc = $true }
    $script:ThrowAt = ''
    return @{ Esc = $esc; Out = $o.Count; Log = @(Get-CallsPre 'Append-Log '); All = ($script:Calls -join ' | '); Kept = [object]::ReferenceEquals($script:GwProc, $proc)
              Seq = (@(Get-CallsPre 'Reset-GwSequence').Count + @(Get-CallsPre 'Set-GwLaunchFailedStatus').Count) }
}
function Read-Fake {
    # Lit les flux poses par le second try avec la vraie Drain-GwReader, comme Read-GwOutput ; rend les lignes recues
    Drain-GwReader $script:OutStdoutReader ([ref]$script:OutStdoutTask)
    Drain-GwReader $script:OutStderrReader ([ref]$script:OutStderrTask)
    $got = @(); while ($script:OutQueue.Count -gt 0) { $got += [string]$script:OutQueue.Dequeue() }
    return ($got -join '|')
}

if (-not $t2) {
    foreach ($id in 'G4v', 'G4a', 'G4b', 'G4c', 'G4d', 'G4e', 'G4f') { Chk $id $false 'second try de Start-Gw introuvable : cas non joue' }
} else {
    $known = @('p', 'first', 'script:Rep', 'script:OutStdoutReader', 'script:OutStderrReader', 'script:OutStdoutTask', 'script:OutStderrTask', '_', 'true', 'false', 'null')
    $knownCmd = @('Set-Busy', 'Set-QualityStale', 'Hide-WCalVerdict', 'Append-Log', 'T')
    $unkV = @($t2.FindAll({ param($n) $n -is $tVar }, $true) | ForEach-Object { [string]$_.VariablePath.UserPath } | Sort-Object -Unique | Where-Object { $known -notcontains $_ })
    $unkC = @(Get-CmdNames $t2 | Sort-Object -Unique | Where-Object { $knownCmd -notcontains $_ })
    Chk 'G4v' ($unkV.Count -eq 0 -and $unkC.Count -eq 0) "le second try n emploie que des variables et des commandes fournies par ce test ; variables inconnues : $(Get-List $unkV) ; commandes inconnues : $(Get-List $unkC)"

    $pa = New-FakeProc "ligne 1`nligne 2" 'erreur 1'
    $r = Invoke-Case 'write' 'busy' $pa
    $want = 'Append-Log ' + ($msgKey -f 'panne simulee de Set-Busy')
    Chk 'G4a' (-not $r.Esc -and $r.Out -eq 0 -and $r.Log.Count -eq 1 -and $r.Kept -and $r.Seq -eq 0 -and $r.All -ceq ('Set-Busy True | ' + $want + ' | Set-Busy True') -and $null -ne $script:OutStdoutTask -and $null -ne $script:OutStderrTask) "Set-Busy qui leve : $($r.Log.Count) ligne de journal ; `$script:GwProc intact ($($r.Kept)) ; Reset-GwSequence et Set-GwLaunchFailedStatus : $($r.Seq) appel ; nouvel essai de Set-Busy `$true absorbe (exception sortie du bloc : $($r.Esc)) ; flux deja poses ; appels : $($r.All)"

    $r = Invoke-Case 'write' 'stale' (New-FakeProc 'ligne 1' '')
    $want = 'Append-Log ' + ($msgKey -f 'panne simulee de Set-QualityStale')
    Chk 'G4b' (-not $r.Esc -and $r.Out -eq 0 -and $r.Log.Count -eq 1 -and $r.Kept -and $r.Seq -eq 0 -and $r.All -ceq ('Set-Busy True | Set-QualityStale written | ' + $want + ' | Set-Busy True')) "Set-QualityStale qui leve : $($r.Log.Count) ligne de journal ; `$script:GwProc intact ($($r.Kept)) ; sequence gardee ($($r.Seq) appel) ; Set-Busy `$true appelee, Hide-WCalVerdict non ; appels : $($r.All)"

    $pc = New-FakeProc "ligne 1`nligne 2" 'erreur 1'
    $r = Invoke-Case 'write' '' $pc
    $wired = ([object]::ReferenceEquals($script:OutStdoutReader, $pc.StandardOutput) -and [object]::ReferenceEquals($script:OutStderrReader, $pc.StandardError) -and $script:OutStdoutTask -is [System.Threading.Tasks.Task] -and $script:OutStderrTask -is [System.Threading.Tasks.Task])
    $read = Read-Fake
    Chk 'G4c' (-not $r.Esc -and $r.Out -eq 0 -and $r.Log.Count -eq 0 -and $r.Kept -and $r.Seq -eq 0 -and $r.All -ceq 'Set-Busy True | Set-QualityStale written | Hide-WCalVerdict' -and $wired -and $read -ceq 'ligne 1|ligne 2|erreur 1') "sans exception : $($r.Log.Count) ligne de journal, aucune sortie ($($r.Out)) ; lecteurs et taches de lecture poses ($wired) ; lignes lues par la vraie Drain-GwReader : « $read » ; appels : $($r.All)"

    $r = Invoke-Case 'write' '' (New-FakeProc 'ligne 1' '' -Closed)
    $cut = $msgKey.IndexOf('{0}'); $pre = 'Append-Log ' + $msgKey.Substring(0, $cut); $suf = $msgKey.Substring($cut + 3)
    $line = ''; if ($r.Log.Count -eq 1) { $line = [string]$r.Log[0] }
    # Le texte de l exception du systeme n est pas compare : seulement le debut et la fin de la ligne
    $okLine = ($line.StartsWith($pre, $ord) -and $line.EndsWith($suf, $ord) -and $line.Length -gt ($pre.Length + $suf.Length))
    $tasksNull = ($null -eq $script:OutStdoutTask -and $null -eq $script:OutStderrTask)
    $drained = $true; $read = ''
    try { $read = Read-Fake } catch { $drained = $false }
    Chk 'G4d' (-not $r.Esc -and $r.Out -eq 0 -and $okLine -and $r.Kept -and $r.Seq -eq 0 -and $r.All -ceq ($line + ' | Set-Busy True') -and $tasksNull -and $drained -and $read -eq '') "flux qui levent (flux de sortie ferme) : $($r.Log.Count) ligne de journal au texte attendu ($okLine) ; `$script:GwProc intact ($($r.Kept)) ; sequence gardee ($($r.Seq) appel) ; Set-Busy `$true tentee ; taches de lecture nulles ($tasksNull), acceptees par la vraie Drain-GwReader ($drained, aucune ligne lue)"

    $r1 = Invoke-Case 'read' '' (New-FakeProc 'x' '')
    $r2 = Invoke-Case 'erase' '' (New-FakeProc 'x' '')
    $r3 = Invoke-Case 'write' '' (New-FakeProc 'x' '') @{ Round = 0 }
    $script:Rep = $null
    Chk 'G4e' ($r1.All -ceq 'Set-Busy True' -and $r2.All -ceq 'Set-Busy True | Set-QualityStale written | Hide-WCalVerdict' -and $r3.All -ceq 'Set-Busy True') "resultat de l onglet Qualite perime pour une ecriture ou un effacement hors controle seulement ; lecture : $($r1.All) ; effacement : $($r2.All) ; ecriture d un controle apres ecriture : $($r3.All)"

    $script:Lang = 'en'
    $r = Invoke-Case 'write' 'stale' (New-FakeProc 'x' '')
    $script:Lang = 'fr'
    $lineFr = $msgKey -f 'panne simulee de Set-QualityStale'; $lineEn = $msgEn -f 'panne simulee de Set-QualityStale'
    $gotEn = ''; if ($r.Log.Count -eq 1) { $gotEn = [string]$r.Log[0] }
    $script:LogColors = @{ cmd = 'cmd'; dim = 'dim'; std = 'std'; ok = 'ok'; warn = 'warn'; err = 'err' }
    $colFr = [string](Get-LogColor $lineFr); $colEn = [string](Get-LogColor $lineEn)
    Chk 'G4f' ($gotEn -ceq ('Append-Log ' + $lineEn) -and $colFr -eq 'err' -and $colEn -eq 'err') "interface anglaise : « $gotEn » ; couleur de la ligne dans le journal (vraie Get-LogColor) : $colFr en francais, $colEn en anglais (err attendu : le journal masque s ouvre)"
}

# --- G5 : cas R9 a R13 du test de la barre d etat de la restauration, lance tel quel
$exeName = 'powershell.exe'; if ($PSVersionTable.PSEdition -eq 'Core') { $exeName = 'pwsh.exe' }
$exe = Join-Path $PSHOME $exeName
$other = Join-Path $PSScriptRoot 'logic-barre-etat-restauration.ps1'
$a = @('-Wt', $Wt, '-Work', (Join-Path $here 'barre-etat'))
# 'Continue' : sous Windows PowerShell 5.1, une ligne de la sortie d erreur reprise par 2>&1 arrete le script sous 'Stop'
$ErrorActionPreference = 'Continue'
$lines = @(& $exe -NoProfile -File $other @a 2>&1 | ForEach-Object { "$_" })
$rc = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
# Sortie gardee dans le dossier de travail, non recopiee ici (sa ligne de bilan fausserait le decompte de ce test)
[System.IO.File]::WriteAllLines((Join-Path $here 'G5-barre-etat.txt'), [string[]]$lines, (New-Object System.Text.UTF8Encoding($false)))
$ids = @('R9', 'R10', 'R11', 'R12', 'R13')
$okIds = @($ids | Where-Object { $id = $_; @($lines | Where-Object { $_ -cmatch ('^' + $id + '\s+conforme\b') }).Count -eq 1 })
Chk 'G5' ($okIds.Count -eq $ids.Count) "logic-barre-etat-restauration lance tel quel (code $rc) : cas conformes parmi R9 a R13 : $(Get-List $okIds) ($($okIds.Count) sur $($ids.Count))"

$nk = ''; if ($script:Fail) { $nk = ' ; non conformes : ' + (@($script:FailIds) -join ', ') }
"=== bilan logic-gw-lancement : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
