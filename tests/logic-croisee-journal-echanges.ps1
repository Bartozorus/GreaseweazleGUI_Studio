param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 (lot L6) : calibration croisee : echanges de disquette annonces (7 au moins, et non 9), lecteur cible de l onglet
# Ecriture preselectionne dans la fenetre de choix, en-tete du journal exporte, marque de troncature du journal.
#  A  echanges : Get-CrossSwapEstimate reelle (240), cas de la specification ; constantes reelles de 560 et affectation reelle
#     de $nPassEst (Start-PrecompCalib, 270) ; ses trois appels (270) transmettent $script:CalMaxVerify ; avertissement de la
#     calibration (bloc « if ($cx) » reel de Start-PrecompCalib, Show-TimedConfirm remplace) et texte de la fenetre de choix
#     (affectation reelle de Show-CrossCalibDialog, 250, avec les nombres que lui passe la vraie Start-CrossCalib) :
#     « 7 échanges au moins », en francais et en anglais. Le deroule reel des invites d echange d une calibration croisee
#     qui converge a la premiere verification (7 invites) est le cas E9 de logic-calib-croisee, qui possede ce harnais.
#  P  preselection : Get-CrossTargetIndex reelle (240) ; instructions reelles de Show-CrossCalibDialog qui creent les trois
#     listes, executees avec de vrais ComboBox jamais affiches ; vraie Start-CrossCalib avec les vraies Get-TargetDrive,
#     Get-DriveIds et Get-CrossCalibTargets (codes des lecteurs lus dans 040, jamais recopies) : le lecteur cible de l onglet
#     est transmis ; fenetre fermee ou validee sur un autre lecteur : lecteur cible memorise et courbes inchanges.
#  J  journal exporte : Get-LogExportHeader et Export-LogFile reelles (110) : deux lignes mot pour mot, en francais et en
#     anglais, date JJ/MM/AAAA HH:mm:ss quelle que soit la culture du poste (J5b), ni chemin ni nom de compte ; le fichier commence par ces deux lignes, le journal
#     affiche ne les recoit pas ; le bouton « Exporter » (540) appelle Export-LogFile.
#  L  troncature : Limit-LogText et Append-Log reelles (110) sur un RichTextBox jamais affiche, constantes reelles de 540 :
#     399 999 et 400 000 caracteres inchanges ; 400 001 : marque en premiere ligne, coupe en debut de ligne, 400 000
#     caracteres au plus ; second depassement : une seule marque, compte cumule ; partie retiree sans fin de ligne : coupe
#     au caractere ; apres « Vider », le compte repart de zero.
#  I  textes : cles de 019-i18n-1211.ps1, texte anglais, memes parametres {n}. D  documents : README, CHANGELOG.
# Fonctions et instructions reelles extraites par l arbre syntaxique, ecrites dans un fichier de travail puis chargees par
# dot-source. Aucun gw, aucune fenetre affichee, aucune compilation. Non couvert : la fenetre de choix affichee, la boite
# d enregistrement du bouton « Exporter », le codage du fichier sous Windows PowerShell 5.1 (BOM de Set-Content).
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
Import-TestWinForms
$tFn = [System.Management.Automation.Language.FunctionDefinitionAst]
$tCmd = [System.Management.Automation.Language.CommandAst]
$tAsg = [System.Management.Automation.Language.AssignmentStatementAst]
$tVar = [System.Management.Automation.Language.VariableExpressionAst]
$tStr = [System.Management.Automation.Language.StringConstantExpressionAst]
$tNum = [System.Management.Automation.Language.ConstantExpressionAst]
$tHash = [System.Management.Automation.Language.HashtableAst]
$tIf = [System.Management.Automation.Language.IfStatementAst]
$tFor = [System.Management.Automation.Language.ForEachStatementAst]
$ord = [System.StringComparison]::Ordinal
$utf8 = New-Object System.Text.UTF8Encoding($false)
$inv = [System.Globalization.CultureInfo]::InvariantCulture

# Textes de la specification (essai-croisee, § 2.4) : cles francaises et textes anglais attendus dans 019. Ecart voulu a la
# specification : « banner » et non « top bar », le mot des autres textes anglais de l application pour le bandeau
$kH1 = "Journal exporté le {0} par Greaseweazle Studio v{1} ; calcul de calibration v{2}, mesure sur l'image v{3}."
$eH1 = 'Log exported on {0} by Greaseweazle Studio v{1}; calibration calculation v{2}, on-image measurement v{3}.'
$kH2 = 'Lecteur du bandeau : {0} ; lecteur cible de ses écritures : {1}.'
$eH2 = 'Drive in the banner: {0}; target drive for its writes: {1}.'
$kMk = '[Journal tronqué : les {0} premiers caractères ont été retirés (400 000 au plus sont gardés). Exportez le journal après chaque opération longue.]'
$eMk = '[Log truncated: the first {0} characters were removed (at most 400,000 are kept). Export the log after each long operation.]'

# ---------------------------------------------------------------- modules : arbres, fonctions, commandes
function Get-Ast([string]$file) {
    $tk = $null; $er = $null
    $a = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $file : $(@($er)[0].Message)" }
    return $a
}
function Get-Owner($node) {
    # Fonction des modules qui contient le noeud ; '' au niveau du script
    $p = $node.Parent
    while ($null -ne $p -and $p -isnot $tFn) { $p = $p.Parent }
    if ($p) { return [string]$p.Name }
    return ''
}
$mods = Join-Path $Wt 'src\modules'
$f110 = '110-fn-coeur-gw.ps1'; $f240 = '240-fn-calib-mesure.ps1'; $f250 = '250-fn-calib-fenetres.ps1'; $f270 = '270-fn-calib-complete.ps1'
$f540 = '540-ui-accueil-restauration-barre.ps1'; $f019 = '019-i18n-1211.ps1'
$asts = @{}; $fns = @{}; $fnFile = @{}
# Commandes relevees en un seul parcours des modules : appels des fonctions du lot, et appels de T avec une de ses cles
$want = @('Get-CrossSwapEstimate', 'Get-CrossTargetIndex', 'Get-LogExportHeader', 'Export-LogFile', 'Limit-LogText', 'Show-CrossCalibDialog')
$calls = New-Object System.Collections.Generic.List[object]
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Sort-Object Name)) {
    $a = Get-Ast $f.FullName; $asts[$f.Name] = $a
    foreach ($fd in @($a.FindAll({ param($n) $n -is $tFn }, $false))) { $fns[$fd.Name] = $fd; $fnFile[$fd.Name] = $f.Name }
    foreach ($c in @($a.FindAll({ param($n) $n -is $tCmd }, $true))) {
        $nm = [string]$c.GetCommandName()
        if ($want -contains $nm) { $calls.Add(@{ Name = $nm; File = $f.Name; Owner = (Get-Owner $c); Ast = $c }) }
        elseif ($nm -ceq 'T' -and $c.CommandElements.Count -eq 2 -and $c.CommandElements[1] -is $tStr) {
            $kv = [string]$c.CommandElements[1].Value
            if ($kv -ceq $kH1 -or $kv -ceq $kH2 -or $kv -ceq $kMk) { $calls.Add(@{ Name = 'T'; Key = $kv; File = $f.Name; Owner = (Get-Owner $c); Ast = $c }) }
        }
    }
}
$need = @('Get-CrossSwapEstimate', 'Get-CrossTargetIndex', 'Get-CrossCalibTargets', 'Get-DriveIds', 'Get-TargetDrive', 'Start-CrossCalib', 'Start-PrecompCalib',
          'Show-CrossCalibDialog', 'Get-CalibFamilyName', 'Limit-LogText', 'Get-LogExportHeader', 'Export-LogFile', 'Append-Log', 'Get-LogColor')
$miss = @($need | Where-Object { -not $fns.ContainsKey($_) })
if ($miss.Count) { throw "fonctions introuvables dans les modules (lot L6 pas encore implemente ?) : $($miss -join ', ')" }
function Get-CallsOf([string]$name) { return ,@($calls | Where-Object { $_.Name -ceq $name }) }
function Get-KeyOwners([string]$key) { return ,@($calls | Where-Object { $_.Name -ceq 'T' -and $_.Key -ceq $key } | ForEach-Object { "$($_.Owner)" }) }
function Get-CmdNames($ast) { return ,@($ast.FindAll({ param($n) $n -is $tCmd }, $true) | ForEach-Object { [string]$_.GetCommandName() }) }
function Get-TopAssign([string]$file, [string]$left) {
    # Affectation du niveau du script d un module, texte tel quel
    $s = @($asts[$file].EndBlock.Statements | Where-Object { $_ -is $tAsg -and $_.Left.Extent.Text -ceq $left })
    if ($s.Count -ne 1) { throw "affectation $left de $file : $($s.Count) trouvee(s)" }
    return [string]$s[0].Extent.Text
}
function Get-DriveCodesText {
    # Codes du reglage drive de $script:SettingDefs (040), lus par l arbre syntaxique : la liste des lecteurs n est pas recopiee
    foreach ($h in @($asts['040-etat-formats.ps1'].FindAll({ param($n) $n -is $tHash }, $true))) {
        foreach ($kv in @($h.KeyValuePairs)) {
            if ([string]$kv.Item1.Extent.Text -cne 'drive') { continue }
            $in = $kv.Item2.Find({ param($n) $n -is $tHash }, $true)
            if (-not $in) { continue }
            $cd = @($in.KeyValuePairs | Where-Object { [string]$_.Item1.Extent.Text -ceq 'Codes' })
            if ($cd.Count -eq 1) { return [string]$cd[0].Item2.Extent.Text }
        }
    }
    throw 'codes du reglage drive introuvables dans 040'
}

# ---------------------------------------------------------------- fichier de travail : fonctions et instructions reelles
$parts = New-Object System.Collections.Generic.List[string]
foreach ($n in 'Get-CrossSwapEstimate', 'Get-CrossTargetIndex', 'Get-CrossCalibTargets', 'Get-DriveIds', 'Get-TargetDrive', 'Start-CrossCalib', 'Get-CalibFamilyName',
               'Limit-LogText', 'Get-LogExportHeader', 'Export-LogFile', 'Append-Log', 'Get-LogColor') { $parts.Add([string]$fns[$n].Extent.Text) }
# Constantes : versions (000), passes de la calibration (560), journal borne et couleurs du journal (540), lecteurs (040)
foreach ($l in '$script:Version', '$script:CalibCalc', '$script:ContentCalc') { $parts.Add((Get-TopAssign '000-entete.ps1' $l)) }
foreach ($l in '$script:CalCoarse', '$script:CalMaxVerify', '$script:CalMaxRetest') { $parts.Add((Get-TopAssign '560-etat-calibration.ps1' $l)) }
foreach ($l in '$script:LogColors', '$script:LogMaxChars', '$script:LogKeepChars', '$script:LogCut') { $parts.Add((Get-TopAssign $f540 $l)) }
$parts.Add('$script:SettingDefs = @{ drive = @{ Codes = ' + (Get-DriveCodesText) + ' } }')
# Start-PrecompCalib (270) : affectation de $nPassEst et bloc « if ($cx) » de l avertissement, recopies tels quels
$sp = $fns['Start-PrecompCalib']
$np = @($sp.Body.FindAll({ param($n) $n -is $tAsg -and $n.Left.Extent.Text -ceq '$nPassEst' }, $true))
if ($np.Count -ne 1) { throw "affectation de `$nPassEst dans Start-PrecompCalib : $($np.Count) trouvee(s)" }
$parts.Add('function Get-RealNPassEst {' + "`r`n" + $np[0].Extent.Text + "`r`n" + 'return $nPassEst' + "`r`n}")
$cf = @($sp.Body.EndBlock.Statements | Where-Object { $_ -is $tIf -and $_.Clauses[0].Item1.Extent.Text -ceq '$cx' -and $_.Extent.Text.Contains("'frmCalibConfirm'") })
if ($cf.Count -ne 1) { throw "bloc if (`$cx) de l avertissement dans Start-PrecompCalib : $($cf.Count) trouve(s)" }
$parts.Add('function Get-RealCrossConfirm($cx, $nPassEst, $fine, $Intro, $body, $wear) {' + "`r`n" + $cf[0].Extent.Text + "`r`n" + 'return $ans' + "`r`n}")
# Show-CrossCalibDialog (250) : texte du bandeau (premiere affectation de $txt) et creation des trois listes (de
# l affectation de $rows a la boucle qui cree les ComboBox), recopies tels quels
$sd = $fns['Show-CrossCalibDialog']
$tx = @($sd.Body.FindAll({ param($n) $n -is $tAsg -and $n.Left.Extent.Text -ceq '$txt' -and $n.Operator -eq [System.Management.Automation.Language.TokenKind]::Equals }, $true))
if ($tx.Count -ne 1) { throw "affectation de `$txt dans Show-CrossCalibDialog : $($tx.Count) trouvee(s)" }
$parts.Add('function Get-RealCrossDlgText([string]$src, [int]$minSwaps, [int]$maxSwaps) {' + "`r`n" + $tx[0].Extent.Text + "`r`n" + 'return $txt' + "`r`n}")
$sdSt = @($sd.Body.EndBlock.Statements); $i0 = -1; $i1 = -1
for ($i = 0; $i -lt $sdSt.Count; $i++) {
    if ($i0 -lt 0 -and $sdSt[$i] -is $tAsg -and $sdSt[$i].Left.Extent.Text -ceq '$rows') { $i0 = $i }
    elseif ($i0 -ge 0 -and $i1 -lt 0 -and $sdSt[$i] -is $tFor -and $sdSt[$i].Extent.Text.Contains('System.Windows.Forms.ComboBox')) { $i1 = $i }
}
if ($i0 -lt 0 -or $i1 -lt 0) { throw 'creation des listes de Show-CrossCalibDialog introuvable' }
$rowsTxt = (@($sdSt[$i0..$i1] | ForEach-Object { $_.Extent.Text }) -join "`r`n")
$parts.Add('function New-RealCrossRows($dlg, [string[]]$targets, [string]$family, [bool]$fine, [string]$preselect, [int]$y) {' + "`r`n" + $rowsTxt + "`r`n" + 'return $cmbs' + "`r`n}")
$gen = Join-Path $here 'gen-croisee-journal.ps1'
[System.IO.File]::WriteAllText($gen, ((@($parts) -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' -File | Sort-Object Name)) { . $f.FullName }
. $gen
$script:Lang = 'fr'
$real = @{ Version = [string]$script:Version; CalibCalc = [string]$script:CalibCalc; ContentCalc = [string]$script:ContentCalc }
$logCut0 = "$([int]$script:LogCut.N)|$([string]$script:LogCut.Mark)"      # etat initial du journal borne, tel que 540 le pose
$ids = Get-DriveIds
"logic-croisee-journal-echanges : $($parts.Count) fonctions et instructions reelles ; lecteurs de 040 : $($ids -join ',') ; $($calls.Count) appels releves ; PowerShell $($PSVersionTable.PSVersion)"

# ================================================================ A. echanges annonces (M3)
"--- A. Get-CrossSwapEstimate (240) : 7 echanges au moins"
$e1 = Get-CrossSwapEstimate 5 $true 1 2; $e2 = Get-CrossSwapEstimate 5 $false 1 2; $e3 = Get-CrossSwapEstimate 5 $true 1
Chk 'A1' ([int]$e1.Min -eq 7 -and [int]$e1.Max -eq 13 -and [int]$e2.Min -eq 7 -and [int]$e2.Max -eq 17 -and [int]$e3.Min -eq 7 -and [int]$e3.Max -eq 13) "5 passes prevues dont 2 verifications : test fin $($e1.Min)/$($e1.Max), test standard $($e2.Min)/$($e2.Max) ; sans le quatrieme argument : $($e3.Min)/$($e3.Max) (attendu 7/13, 7/17, 7/13)"
$e4 = Get-CrossSwapEstimate 4 $true 0 1; $e5 = Get-CrossSwapEstimate 1 $true 0 2; $e6 = Get-CrossSwapEstimate 0 $true 0
Chk 'A2' ([int]$e4.Min -eq 7 -and [int]$e4.Max -eq 9 -and [int]$e5.Min -eq 1 -and [int]$e6.Min -eq 1 -and [int]$e6.Max -eq 3) "4 passes dont 1 verification, sans nouvel essai : $($e4.Min)/$($e4.Max) (attendu 7/9) ; 1 passe dont 2 verifications : $($e5.Min) au moins, jamais sous 1 ; 0 passe : $($e6.Min)/$($e6.Max)"
$e7 = Get-CrossSwapEstimate 5 $true 1 1; $e8 = Get-CrossSwapEstimate 5 $true 1 0; $e9 = Get-CrossSwapEstimate 6 $true 1 3
Chk 'A2b' ([int]$e7.Min -eq 9 -and [int]$e8.Min -eq 9 -and [int]$e7.Max -eq 13 -and [int]$e9.Min -eq 7 -and [int]$e9.Max -eq 15) "une seule verification prevue : aucune a retrancher ($($e7.Min)) ; zero verification : rien de negatif ($($e8.Min)) ; 6 passes dont 3 verifications : $($e9.Min)/$($e9.Max) (attendu 7/15) ; le maximum ne depend pas des verifications"
$nPass = [int](Get-RealNPassEst); $nCoarse = @($script:CalCoarse).Count; $mv = [int]$script:CalMaxVerify; $mr = [int]$script:CalMaxRetest
$rf = Get-CrossSwapEstimate $nPass $true $mr $mv; $rs = Get-CrossSwapEstimate $nPass $false $mr $mv
Chk 'A3' ($nPass -eq ($nCoarse + $mv) -and [int]$rf.Min -eq (2 * ($nCoarse + 1) - 1) -and [int]$rf.Min -eq 7 -and [int]$rf.Max -eq 13 -and [int]$rs.Min -eq 7 -and [int]$rs.Max -eq 17) "constantes reelles de 560 ($nCoarse passes de mesure, $mv verifications, $mr nouvel essai) et affectation reelle de `$nPassEst ($nPass) : test fin $($rf.Min)/$($rf.Max), test standard $($rs.Min)/$($rs.Max) ; minimum = 2 x (passes de mesure + 1 verification) - 1"
$sc = Get-CallsOf 'Get-CrossSwapEstimate'
$scBad = @($sc | Where-Object { $_.File -cne $f270 -or $_.Ast.CommandElements.Count -ne 5 -or $_.Ast.CommandElements[3].Extent.Text -cne '([int]$script:CalMaxRetest)' -or $_.Ast.CommandElements[4].Extent.Text -cne '([int]$script:CalMaxVerify)' })
$scOwn = (@($sc | ForEach-Object { $_.Owner } | Sort-Object) -join ',')
Chk 'A4' ($sc.Count -eq 3 -and $scBad.Count -eq 0 -and $scOwn -ceq 'Start-CrossCalib,Start-CrossCalib,Start-PrecompCalib') "appels de Get-CrossSwapEstimate dans les modules : $($sc.Count) ($scOwn), tous dans 270, avec `$script:CalMaxRetest puis `$script:CalMaxVerify ; non conformes : $($scBad.Count)"

function Invoke-ConfirmText([bool]$fine, [string]$lang) {
    # Avertissement de la calibration croisee : bloc reel de Start-PrecompCalib, fenetre remplacee (texte releve, Annuler)
    function Append-Log([string]$text) { $script:XLog.Add($text) }
    function Show-TimedConfirm([string]$name, [string]$title, [string]$text, [string]$okText, [string]$okGlyph, [string]$countFmt, [string]$checkLabel, [string]$stopOn, [string]$stopOff, [int]$Seconds = 0, [switch]$NeedCheck, $Combo = $null, [string]$Heading = '', [string]$Level = 'warn', [string]$Picto = 'warn') {
        $script:XConf.Add(@{ Name = $name; Text = $text })
        return @{ Ok = $false; Checked = $false; Auto = $false }
    }
    $script:XLog = New-Object System.Collections.Generic.List[string]; $script:XConf = New-Object System.Collections.Generic.List[object]
    $script:Lang = $lang
    try { [void](Get-RealCrossConfirm @{ Src = 'A'; Tgt = '0' } (Get-RealNPassEst) $fine '' 'CORPS' 'USURE') } finally { $script:Lang = 'fr' }
    if ($script:XConf.Count -ne 1 -or $script:XConf[0].Name -cne 'frmCalibConfirm') { return '' }
    return [string]$script:XConf[0].Text
}
$wF = Invoke-ConfirmText $true 'fr'; $wS = Invoke-ConfirmText $false 'fr'; $wFe = Invoke-ConfirmText $true 'en'; $wSe = Invoke-ConfirmText $false 'en'
Chk 'A5' ($wF.Contains("d'un lecteur à l'autre : 7 échanges au moins, 13 au plus. La durée estimée ne compte pas ces échanges.") -and $wS.Contains(' : 7 échanges au moins, 17 au plus. ') -and $wF -notmatch '\b9 échanges' -and $wS -notmatch '\b9 échanges' -and $wF.EndsWith("CORPS`n`nUSURE", $ord)) "avertissement de la calibration croisee, bloc reel : « 7 échanges au moins, 13 au plus » en test fin, « 7 échanges au moins, 17 au plus » en test standard, plus aucun « 9 échanges »"
Chk 'A5e' ($wFe.Contains('from one drive to the other: 7 swaps at least, 13 at most. The estimated duration does not count these swaps.') -and $wSe.Contains(': 7 swaps at least, 17 at most. ') -and $wFe -notmatch '\b9 swaps' -and $wSe -notmatch '\b9 swaps') "en anglais : « 7 swaps at least, 13 at most » et « 7 swaps at least, 17 at most »"

function Get-MapText($h) { return (@(@($h.Keys) | Sort-Object | ForEach-Object { "$_=$($h[$_])" }) -join ';') }
function Get-CurveText($h) { return (@(@($h.Keys) | Sort-Object | ForEach-Object { "$_ : $($h[$_].Spec) $($h[$_].Date)" }) -join ' ; ') }
function Invoke-CrossStart($o) {
    # Start-CrossCalib reelle (270) avec les vraies Get-TargetDrive, Get-DriveIds et Get-CrossCalibTargets ; fenetres, image
    # de l onglet et lancement remplaces. $o : @{ Tab (lecteurs cibles memorises) ; DlgOk ; DlgTarget }
    function Append-Log([string]$text) { $script:XLog.Add($text) }
    function Get-AppBusy([switch]$Text) { return '' }
    function Show-AppMessage([string]$text, [string]$title, [string]$buttons = 'OK', [string]$icon = 'Information') { $script:XMsg.Add($text); return 'OK' }
    function Show-CrossCalibDialog([string]$src, [string[]]$targets, [string]$family, [bool]$fine, [string]$imgInfo, [bool]$slow, [int]$minSwaps, [int]$maxSwaps, [string]$preselect = '') {
        $script:XDlg.Add(@{ Src = $src; Targets = @($targets); Family = $family; Fine = $fine; Min = $minSwaps; Max = $maxSwaps; Pre = $preselect; NArg = $PSBoundParameters.Count })
        return @{ Ok = [bool]$o.DlgOk; Target = [string]$o.DlgTarget; Family = 'std'; Fine = $true }
    }
    function Start-PrecompCalib([switch]$ForceFine, [string]$Intro = '', [switch]$LevelAfter, $Geom = $null, $Heads = $null, [string]$Test = '', [switch]$NoWarmup) {
        $script:XStart.Add(@{ Src = [string]$script:CalCrossAsk.Src; Tgt = [string]$script:CalCrossAsk.Tgt; Test = $Test }); $script:CalCrossAsk = $null
    }
    function Save-Config { $script:XWrite++; return $true }
    function Set-TargetDrive([string]$src, [string]$tgt) { $script:XWrite++ }
    function Set-DriveCurve { $script:XWrite++ }
    function Get-CalibEnvBlock { return $null }
    function Get-CalibSettingBlock { return '' }
    function Get-CalibImageCheck($Geom = $null) { return @{ Ok = $true; Why = ''; Scope = ''; Family = 'std' } }
    $script:XLog = New-Object System.Collections.Generic.List[string]; $script:XMsg = New-Object System.Collections.Generic.List[string]
    $script:XDlg = New-Object System.Collections.Generic.List[object]; $script:XStart = New-Object System.Collections.Generic.List[object]; $script:XWrite = 0
    $script:CalRedo = $null; $script:Cal = $null; $script:CalCrossAsk = $null; $script:AfterCalib = 'write'
    $script:TargetDrives = @{}; foreach ($k in @($o.Tab.Keys)) { $script:TargetDrives[[string]$k] = [string]$o.Tab[$k] }
    $store = @{ 'A|std' = @{ Spec = '0=50'; Date = '01/11/2026 10:00' }; 'A>0|std' = @{ Spec = '0=80'; Date = '02/11/2026 10:00' } }
    $script:DriveCurves = $store
    $cmbDrive = [pscustomobject]@{ Text = 'A'; Items = $ids }; $cmbWCalMode = [pscustomobject]@{ SelectedIndex = 1 }; $chkWSlow = [pscustomobject]@{ Checked = $true }; $txtWFile = [pscustomobject]@{ Text = 'C:\x\image.adf' }
    $tab0 = Get-MapText $script:TargetDrives; $cv0 = Get-CurveText $script:DriveCurves
    $res = Start-CrossCalib
    $r = @{ Res = $res; Dlg = $script:XDlg.ToArray(); Start = $script:XStart.ToArray(); Log = $script:XLog.ToArray(); Msg = $script:XMsg.ToArray(); Write = [int]$script:XWrite
            Tab0 = $tab0; Tab1 = (Get-MapText $script:TargetDrives); Cv0 = $cv0; Cv1 = (Get-CurveText $script:DriveCurves); SameStore = [object]::ReferenceEquals($script:DriveCurves, $store); Ask = $script:CalCrossAsk }
    $script:TargetDrives = $null; $script:DriveCurves = $null
    return $r
}
$x0 = Invoke-CrossStart @{ Tab = @{}; DlgOk = $false; DlgTarget = '' }
$d0 = $null; if ($x0.Dlg.Count -eq 1) { $d0 = $x0.Dlg[0] }
$dlgFr = ''; $dlgEn = ''
if ($d0) {
    $dlgFr = [string](Get-RealCrossDlgText 'A' ([int]$d0.Min) ([int]$d0.Max))
    $script:Lang = 'en'; try { $dlgEn = [string](Get-RealCrossDlgText 'A' ([int]$d0.Min) ([int]$d0.Max)) } finally { $script:Lang = 'fr' }
}
Chk 'A6' ($null -ne $d0 -and [int]$d0.Min -eq 7 -and [int]$d0.Max -eq 17 -and $dlgFr.Contains("d'un lecteur à l'autre : 7 échanges au moins, 17 au plus si la courbe demande des passes supplémentaires.") -and $dlgFr.StartsWith('Le lecteur A, choisi dans le bandeau,', $ord) -and $dlgFr -notmatch '\b9 échanges') "fenetre de choix : la vraie Start-CrossCalib lui passe $(if ($d0) { "$($d0.Min) et $($d0.Max)" }) ; texte reel du bandeau : « 7 échanges au moins, 17 au plus si la courbe demande des passes supplémentaires »"
Chk 'A6e' ($dlgEn.Contains('from one drive to the other: 7 swaps at least, 17 at most if the curve needs extra passes.') -and $dlgEn -notmatch '\b9 swaps') "en anglais : « 7 swaps at least, 17 at most if the curve needs extra passes »"

# ================================================================ P. lecteur cible preselectionne (M4)
"--- P. Get-CrossTargetIndex (240), listes reelles de Show-CrossCalibDialog (250), Start-CrossCalib reelle (270)"
$lst = @('B', '0', '1', '2', '3')
$p1 = @((Get-CrossTargetIndex $lst '0'), (Get-CrossTargetIndex $lst 'Z'), (Get-CrossTargetIndex $lst ''), (Get-CrossTargetIndex @() '0'), (Get-CrossTargetIndex $null '0'), (Get-CrossTargetIndex $lst '3'), (Get-CrossTargetIndex $lst 'B'))
Chk 'P1' (($p1 -join ',') -ceq '1,0,0,0,0,4,0') "Get-CrossTargetIndex sur B,0,1,2,3 : lecteur 0 -> 1 ; lecteur absent -> 0 ; chaine vide -> 0 ; liste vide -> 0 ; liste nulle -> 0 ; dernier -> 4 ; premier -> 0 : $($p1 -join ',')"
$p2Bad = @(); $p2N = 0
foreach ($s in $ids) {
    $tg = Get-CrossCalibTargets $ids $s
    foreach ($t in $tg) { $p2N++; $ix = Get-CrossTargetIndex $tg $t; if ([string]$tg[$ix] -cne [string]$t) { $p2Bad += "$s>$t" } }
    if ((Get-CrossTargetIndex $tg $s) -ne 0) { $p2Bad += "$s>$s" }
}
Chk 'P2' ($p2N -eq ($ids.Count * ($ids.Count - 1)) -and $p2N -gt 0 -and $p2Bad.Count -eq 0) "listes reelles (Get-DriveIds, Get-CrossCalibTargets) : pour chacun des $p2N couples source et cible, le rang rendu designe la cible ; la source elle-meme, absente de sa liste, donne 0 ; en defaut : $($p2Bad.Count)"
function Get-RowsPick([string[]]$targets, [string]$preselect, [string]$family, [bool]$fine) {
    # Instructions reelles de Show-CrossCalibDialog qui creent les trois listes, sur une fenetre jamais affichee
    $dlg = New-Object System.Windows.Forms.Form
    try {
        $out = @(New-RealCrossRows $dlg $targets $family $fine $preselect 40)
        $cmbs = $out[$out.Count - 1]
        $t = $cmbs['cmbCrossTarget']
        return @{ Target = [string]$t.Text; Index = [int]$t.SelectedIndex; Items = (@($t.Items | ForEach-Object { [string]$_ }) -join ','); Family = [int]$cmbs['cmbCrossFamily'].SelectedIndex; Test = [int]$cmbs['cmbCrossTest'].SelectedIndex; N = [int]$cmbs.Count }
    } finally { $dlg.Dispose() }
}
$tgA = Get-CrossCalibTargets $ids 'A'
$last = [string]$tgA[$tgA.Count - 1]
$r0 = Get-RowsPick $tgA '0' 'std' $true; $r1 = Get-RowsPick $tgA '' 'long' $false; $r2 = Get-RowsPick $tgA 'Z' 'std' $true; $r3 = Get-RowsPick $tgA $last 'std' $true
Chk 'P3' ($r0.N -eq 3 -and $r0.Items -ceq ($tgA -join ',') -and $r0.Target -ceq '0' -and $r1.Target -ceq [string]$tgA[0] -and $r1.Index -eq 0 -and $r2.Target -ceq [string]$tgA[0] -and $r3.Target -ceq $last -and $r3.Index -eq ($tgA.Count - 1)) "liste « Lecteur cible : » reelle ($($r0.Items)) : lecteur cible 0 de l onglet -> « $($r0.Target) » ; aucun -> « $($r1.Target) », le premier, comme en 12.10 ; inconnu -> « $($r2.Target) » ; dernier de la liste -> « $($r3.Target) »"
Chk 'P3b' ($r0.Family -eq 0 -and $r0.Test -eq 1 -and $r1.Family -eq 1 -and $r1.Test -eq 0) "listes « Famille : » et « Test : » inchangees : preselection d apres la famille et le test recus ($($r0.Family)/$($r0.Test), $($r1.Family)/$($r1.Test))"
$sx = @(@{ Tab = @{ A = '0' }; Pre = '0' }, @{ Tab = @{}; Pre = '' }, @{ Tab = @{ A = 'A' }; Pre = '' }, @{ Tab = @{ A = 'Z' }; Pre = '' }, @{ Tab = @{ B = '1' }; Pre = '' }, @{ Tab = @{ A = [string]$tgA[0] }; Pre = [string]$tgA[0] })
$p4Bad = @(); $p4Txt = @()
foreach ($c in $sx) {
    $x = Invoke-CrossStart @{ Tab = $c.Tab; DlgOk = $false; DlgTarget = '' }
    $got = '?'; if ($x.Dlg.Count -eq 1) { $got = [string]$x.Dlg[0].Pre }
    $p4Txt += "$(Get-MapText $c.Tab) -> « $got »"
    if ($x.Dlg.Count -ne 1 -or $got -cne [string]$c.Pre -or [int]$x.Dlg[0].NArg -ne 9 -or ($x.Dlg[0].Targets -join ',') -cne ($tgA -join ',')) { $p4Bad += (Get-MapText $c.Tab) }
}
Chk 'P4' ($p4Bad.Count -eq 0) "Start-CrossCalib reelle, lecteur A dans le bandeau : lecteur cible memorise transmis a la fenetre de choix (neuvieme argument) ; aucun, la source elle-meme, un lecteur inconnu ou le choix d un autre lecteur source : chaine vide : $($p4Txt -join ' ; ')"
$xc = Invoke-CrossStart @{ Tab = @{ A = '0' }; DlgOk = $false; DlgTarget = '' }
Chk 'P5' ($xc.Dlg.Count -eq 1 -and $xc.Dlg[0].Pre -ceq '0' -and $xc.Tab0 -ceq 'A=0' -and $xc.Tab1 -ceq $xc.Tab0 -and $xc.Cv1 -ceq $xc.Cv0 -and $xc.SameStore -and $xc.Start.Count -eq 0 -and $xc.Write -eq 0 -and $null -eq $xc.Ask -and $xc.Msg.Count -eq 0 -and $xc.Log.Count -eq 1 -and $xc.Log[0] -ceq "Calibration croisée : fenêtre de choix fermée, rien n'est lancé.") "fenetre de choix fermee apres la preselection de 0 : lecteur cible memorise inchange ($($xc.Tab1)), courbes inchangees, aucune demande posee, rien de lance ni d enregistre"
$xo = Invoke-CrossStart @{ Tab = @{ A = '0' }; DlgOk = $true; DlgTarget = '1' }
$xs = Invoke-CrossStart @{ Tab = @{ A = '0' }; DlgOk = $true; DlgTarget = '0' }
Chk 'P6' ($xo.Start.Count -eq 1 -and $xo.Start[0].Src -ceq 'A' -and $xo.Start[0].Tgt -ceq '1' -and $xo.Tab1 -ceq 'A=0' -and $xo.Cv1 -ceq $xo.Cv0 -and $xo.SameStore -and $xo.Write -eq 0 -and $xs.Start.Count -eq 1 -and $xs.Start[0].Tgt -ceq '0' -and $xs.Tab1 -ceq 'A=0' -and (@($xo.Log | Where-Object { $_ -ceq 'Calibration croisée demandée : écriture par le lecteur A, relecture par le lecteur 1, famille Standard 2 us, test fin.' }).Count -eq 1)) "fenetre validee sur un autre lecteur que le preselectionne : la calibration est demandee pour le lecteur choisi ($($xo.Start[0].Src) -> $($xo.Start[0].Tgt)), le lecteur cible de l onglet reste $($xo.Tab1), aucune courbe ne change avant la calibration ; validee telle quelle : lecteur $($xs.Start[0].Tgt)"
$noWrite = @('Set-TargetDrive', 'Set-TargetDriveFromUi', 'Update-TargetDriveUi', 'Import-TargetDrives', 'Set-DriveCurve', 'Sync-PrecompCurves', 'Save-Config')
$wr = @()
foreach ($n in 'Show-CrossCalibDialog', 'Get-CrossTargetIndex', 'Start-CrossCalib') { foreach ($c in (Get-CmdNames $fns[$n].Body)) { if ($noWrite -contains $c) { $wr += "$n : $c" } } }
$preUse = @($sd.Body.FindAll({ param($n) $n -is $tVar -and $n.VariablePath.UserPath -eq 'preselect' }, $true))
$preIn = @($preUse | Where-Object { $p = $_.Parent; while ($null -ne $p -and $p -isnot $tCmd) { $p = $p.Parent }; $null -ne $p -and [string]$p.GetCommandName() -ceq 'Get-CrossTargetIndex' })
$tiAsg = @($fns['Get-CrossTargetIndex'].Body.FindAll({ param($n) $n -is $tAsg }, $true))
$tiCalls = Get-CallsOf 'Get-CrossTargetIndex'; $dlgCalls = Get-CallsOf 'Show-CrossCalibDialog'
Chk 'P7' ($wr.Count -eq 0 -and $preUse.Count -eq 1 -and $preIn.Count -eq 1 -and $tiAsg.Count -eq 0 -and $tiCalls.Count -eq 1 -and $tiCalls[0].Owner -ceq 'Show-CrossCalibDialog' -and $dlgCalls.Count -eq 1 -and $dlgCalls[0].Owner -ceq 'Start-CrossCalib' -and $dlgCalls[0].Ast.CommandElements.Count -eq 10 -and $dlgCalls[0].Ast.CommandElements[9].Extent.Text -ceq '(Get-TargetDrive $src)') "statique : la fenetre de choix, Get-CrossTargetIndex et Start-CrossCalib n appellent aucune fonction qui memorise un lecteur cible, une courbe ou la configuration ($($wr.Count)) ; `$preselect n est lu que par l appel de Get-CrossTargetIndex ; Start-CrossCalib passe (Get-TargetDrive `$src) en neuvieme argument"

# ================================================================ J. journal exporte (M1)
"--- J. Get-LogExportHeader, Export-LogFile (110), bouton « Exporter » (540)"
$cmbDrive = [pscustomobject]@{ Text = 'A'; Items = $ids }
$split = [pscustomobject]@{ Panel2Collapsed = $false }
function Set-LogVisible([bool]$on) { }
$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.ReadOnly = $true; $txtLog.DetectUrls = $false; $txtLog.WordWrap = $false
$when = New-Object System.DateTime(2026, 11, 13, 14, 5, 9)
$script:Version = '12.11'; $script:CalibCalc = '12.10'; $script:ContentCalc = '12.9'
$script:TargetDrives = @{ A = '0' }
$hT = Get-LogExportHeader $when
$script:TargetDrives = @{}
$hN = Get-LogExportHeader $when
$fr1 = "Journal exporté le 13/11/2026 14:05:09 par Greaseweazle Studio v12.11 ; calcul de calibration v12.10, mesure sur l'image v12.9."
Chk 'J1' (@($hT).Count -eq 2 -and [string]$hT[0] -ceq $fr1 -and [string]$hT[1] -ceq 'Lecteur du bandeau : A ; lecteur cible de ses écritures : 0.') "en-tete, lecteur A, lecteur cible 0 : deux lignes mot pour mot : « $($hT[0]) » / « $($hT[1]) »"
Chk 'J2' (@($hN).Count -eq 2 -and [string]$hN[0] -ceq $fr1 -and [string]$hN[1] -ceq 'Lecteur du bandeau : A ; lecteur cible de ses écritures : (même lecteur).') "sans lecteur cible : « $($hN[1]) »"
$script:Lang = 'en'; Set-TestCulture 'en-US'
try {
    $script:TargetDrives = @{ A = '0' }; $hTe = Get-LogExportHeader $when
    $script:TargetDrives = @{}; $hNe = Get-LogExportHeader $when
} finally { $script:Lang = 'fr'; Set-TestCulture 'fr-FR' }
$en1 = 'Log exported on 13/11/2026 14:05:09 by Greaseweazle Studio v12.11; calibration calculation v12.10, on-image measurement v12.9.'
Chk 'J3' ([string]$hTe[0] -ceq $en1 -and [string]$hTe[1] -ceq 'Drive in the banner: A; target drive for its writes: 0.' -and [string]$hNe[0] -ceq $en1 -and [string]$hNe[1] -ceq 'Drive in the banner: A; target drive for its writes: (same drive).') "en anglais, culture en-US : « $($hTe[0]) » / « $($hTe[1]) » / « $($hNe[1]) » ; date au meme format"
$script:Version = 'VV'; $script:CalibCalc = 'CC'; $script:ContentCalc = 'MM'; $cmbDrive.Text = [string]$tgA[0]
$hS = Get-LogExportHeader $when
$script:Version = $real.Version; $script:CalibCalc = $real.CalibCalc; $script:ContentCalc = $real.ContentCalc; $cmbDrive.Text = 'A'
$hR = Get-LogExportHeader $when
Chk 'J4' ([string]$hS[0] -ceq 'Journal exporté le 13/11/2026 14:05:09 par Greaseweazle Studio vVV ; calcul de calibration vCC, mesure sur l''image vMM.' -and [string]$hS[1] -ceq "Lecteur du bandeau : $($tgA[0]) ; lecteur cible de ses écritures : (même lecteur)." -and [string]$hR[0] -ceq ($kH1 -f '13/11/2026 14:05:09', $real.Version, $real.CalibCalc, $real.ContentCalc) -and $real.Version -match '^\d+\.\d+') "l en-tete lit les variables de l application : valeurs factices rendues telles quelles ; avec les versions reelles de 000 : « $($hR[0]) »"
$t0 = Get-Date; $hD = Get-LogExportHeader; $dOk = $false; $dTxt = ''
$mD = [regex]::Match([string]$hD[0], '^Journal exporté le (\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}) par Greaseweazle Studio v')
if ($mD.Success) { $dTxt = $mD.Groups[1].Value; $dd = [datetime]::ParseExact($dTxt, 'dd/MM/yyyy HH:mm:ss', $inv); $dOk = ([math]::Abs(($dd - $t0).TotalSeconds) -le 120) }
Chk 'J5' ($dOk) "sans argument : date et heure de l export, au format JJ/MM/AAAA HH:mm:ss ($dTxt)"
# J5b (corrections de relecture) : la date de l en-tete ne suit pas la culture du poste. « / » et « : » d un format .NET
# sont les separateurs de la culture courante (13.11.2026 en de-DE et en fr-CH, 13-11-2026 en nl-NL, 14.05.09 en fi-FI) :
# sous chacune, la premiere ligne reste celle du cas J1, au caractere pres ; le meme format sans culture invariante
# differe sous au moins une de ces cultures (sinon le cas ne prouverait rien)
$script:TargetDrives = @{ A = '0' }; $cmbDrive.Text = 'A'
$script:Version = '12.11'; $script:CalibCalc = '12.10'; $script:ContentCalc = '12.9'
$badCu = @(); $difCu = @(); $cuList = @('de-DE', 'fr-CH', 'fr-CA', 'nl-NL', 'fi-FI')
try {
    foreach ($cu in $cuList) {
        Set-TestCulture $cu
        $hC = Get-LogExportHeader $when
        if (@($hC).Count -ne 2 -or [string]$hC[0] -cne $fr1 -or [string]$hC[1] -cne 'Lecteur du bandeau : A ; lecteur cible de ses écritures : 0.') { $badCu += "$cu : « $($hC[0]) »" }
        if ($when.ToString('dd/MM/yyyy HH:mm:ss') -cne '13/11/2026 14:05:09') { $difCu += $cu }
    }
} finally { Set-TestCulture 'fr-FR' }
$script:TargetDrives = @{}; $script:Version = $real.Version; $script:CalibCalc = $real.CalibCalc; $script:ContentCalc = $real.ContentCalc
Chk 'J5b' ($badCu.Count -eq 0 -and $difCu.Count -ge 1) "date de l en-tete independante de la culture du poste : meme premiere ligne sous $($cuList -join ', ') (ecarts : $(if ($badCu.Count) { $badCu -join ' | ' } else { 'aucun' })) ; sans culture invariante, le meme format differe sous : $($difCu -join ', ')"
$allH = (@($hT) + @($hN) + @($hTe) + @($hNe) + @($hR) + @($hD)) -join "`n"
$priv = @()
if ($allH.Contains('\')) { $priv += 'barre inverse' }
if ($allH -match '[A-Za-z]:[\\/]') { $priv += 'lettre de volume' }
foreach ($ev in 'USERNAME', 'USERPROFILE', 'COMPUTERNAME', 'USERDOMAIN', 'APPDATA', 'LOCALAPPDATA', 'TEMP') {
    $evv = [string][System.Environment]::GetEnvironmentVariable($ev)
    if ($evv.Length -ge 3 -and $allH.IndexOf($evv, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $priv += "valeur de $ev" }
}
$gh = $fns['Get-LogExportHeader']
$ghVars = @($gh.FindAll({ param($n) $n -is $tVar }, $true) | ForEach-Object { [string]$_.VariablePath.UserPath } | Sort-Object -Unique)
$ghVarBad = @($ghVars | Where-Object { @('when', 'tgt', 'l1', 'l2', 'script:Version', 'script:CalibCalc', 'script:ContentCalc', 'cmbDrive') -cnotcontains $_ })
$ghCmdBad = @((Get-CmdNames $gh) | Where-Object { @('T', 'Get-TargetDrive', 'Get-Date') -cnotcontains $_ })
Chk 'J6' ($priv.Count -eq 0 -and $ghVarBad.Count -eq 0 -and $ghCmdBad.Count -eq 0) "ni chemin, ni nom de compte, ni nom de poste dans les lignes de l en-tete ($($priv.Count) trouve) ; Get-LogExportHeader ne lit que la date, les trois versions, le lecteur du bandeau et son lecteur cible (autres variables : $($ghVarBad -join ',') ; autres commandes : $($ghCmdBad -join ','))"
# Export reel : le fichier commence par les deux lignes de Get-LogExportHeader, le journal affiche ne les recoit pas
$txtLog.Clear(); $script:LogCut = @{ N = 0; Mark = '' }; $script:TargetDrives = @{ A = '0' }
Append-Log "Greaseweazle Studio : première ligne du journal`n>>> gw info"
$logTxt = [string]$txtLog.Text
$exp = Join-Path $here 'export-journal.txt'
if (Test-Path -LiteralPath $exp) { Remove-Item -LiteralPath $exp -Force }
Export-LogFile $exp
$raw = [System.IO.File]::ReadAllText($exp, [System.Text.Encoding]::UTF8)
$hX = Get-LogExportHeader
$rxD = '\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}'
$rl = @($raw -split "`n")
$body = ''; if ($rl.Count -ge 3) { $body = $raw.Substring($rl[0].Length + 1 + $rl[1].Length + 1) }
Chk 'J7' ($logTxt -ceq "Greaseweazle Studio : première ligne du journal`n>>> gw info`n" -and $rl.Count -ge 4 -and ([regex]::Replace($rl[0], $rxD, 'DATE')) -ceq ([regex]::Replace([string]$hX[0], $rxD, 'DATE')) -and $rl[0] -match $rxD -and $rl[1] -ceq [string]$hX[1] -and $rl[1] -ceq 'Lecteur du bandeau : A ; lecteur cible de ses écritures : 0.' -and $body -ceq ($logTxt + [System.Environment]::NewLine) -and [string]$txtLog.Text -ceq $logTxt) "Export-LogFile reelle : le fichier commence par les deux lignes de Get-LogExportHeader, puis porte le journal tel quel ($($logTxt.Length) caracteres) ; le journal affiche est inchange"
$hSave = @($asts[$f540].EndBlock.Statements | Where-Object { $_.Extent.Text.StartsWith('$btnSaveLog.Add_Click(', $ord) })
$hsCmd = @(); $hsArg = ''; $hsLog = 0
if ($hSave.Count -eq 1) {
    $hsCmd = Get-CmdNames $hSave[0]
    $ec = @($hSave[0].FindAll({ param($n) $n -is $tCmd -and $n.GetCommandName() -eq 'Export-LogFile' }, $true))
    if ($ec.Count -eq 1 -and $ec[0].CommandElements.Count -eq 2) { $hsArg = [string]$ec[0].CommandElements[1].Extent.Text }
    $hsLog = @($hSave[0].FindAll({ param($n) $n -is $tVar -and $n.VariablePath.UserPath -eq 'txtLog' }, $true)).Count
}
$elCmd = Get-CmdNames $fns['Export-LogFile']
$ghCalls = Get-CallsOf 'Get-LogExportHeader'; $elCalls = Get-CallsOf 'Export-LogFile'
$k1o = Get-KeyOwners $kH1; $k2o = Get-KeyOwners $kH2
Chk 'J8' ($hSave.Count -eq 1 -and $hsArg -ceq '$d.FileName' -and $hsCmd -cnotcontains 'Set-Content' -and $hsLog -eq 0 -and @($elCmd | Where-Object { $_ -ceq 'Get-LogExportHeader' }).Count -eq 1 -and @($elCmd | Where-Object { $_ -ceq 'Set-Content' }).Count -eq 1 -and $ghCalls.Count -eq 1 -and $ghCalls[0].Owner -ceq 'Export-LogFile' -and $elCalls.Count -eq 1 -and $elCalls[0].File -ceq $f540 -and $elCalls[0].Owner -ceq '' -and ($k1o -join ',') -ceq 'Get-LogExportHeader' -and ($k2o -join ',') -ceq 'Get-LogExportHeader') "statique : le bouton « Exporter » (540) appelle Export-LogFile `$d.FileName et n ecrit plus le fichier lui-meme ; Export-LogFile est la seule a appeler Get-LogExportHeader, seule fonction qui porte les deux textes de l en-tete"

# ================================================================ L. journal borne, marque de troncature (M2)
"--- L. Limit-LogText, Append-Log (110) sur un RichTextBox jamais affiche ; constantes de 540"
$max = [int]$script:LogMaxChars; $keep = [int]$script:LogKeepChars
function New-LogLines([int]$total, [int]$first = 0) {
    # Texte de $total caracteres exactement : lignes numerotees de 80 caracteres, fin de ligne comprise ; la derniere,
    # plus courte, tombe juste et finit elle aussi par une fin de ligne
    $sb = New-Object System.Text.StringBuilder
    $i = $first
    while ($sb.Length + 80 -le $total) { [void]$sb.Append(('ligne {0:000000} ' -f $i).PadRight(79, '.')).Append("`n"); $i++ }
    $rest = $total - $sb.Length
    if ($rest -gt 0) { [void]$sb.Append(('fin {0:000000} ' -f $i).PadRight(79, '.').Substring(0, $rest - 1)).Append("`n") }
    return $sb.ToString()
}
function Set-LogText([string]$t) { $txtLog.Clear(); $txtLog.Text = $t; $script:LogCut = @{ N = 0; Mark = '' } }
function Get-MarkCount([string]$t) { return ([regex]::Matches($t, [regex]::Escape('[Journal tronqué'))).Count }
function Get-MarkText([int]$n) { return ($kMk -f "$n") }
$lit = [regex]::Match($kMk, '\((\d[\d ]*) au plus sont gardés\)'); $litEn = [regex]::Match($eMk, 'at most ([\d,]+) are kept')
$litFr = -1; if ($lit.Success) { $litFr = [int]($lit.Groups[1].Value -replace ' ', '') }
$litE = -1; if ($litEn.Success) { $litE = [int]($litEn.Groups[1].Value -replace ',', '') }
Chk 'L0' ($max -eq 400000 -and $keep -eq 250000 -and $keep -lt $max -and $litFr -eq $max -and $litE -eq $max -and $logCut0 -ceq '0|') "constantes reelles de 540 : $max caracteres au plus, $keep gardes apres une troncature, aucun caractere retire ni marque au depart ; le nombre ecrit dans la marque, en francais ($litFr) et en anglais ($litE), est cette borne"
$tA = New-LogLines 399999
Set-LogText $tA; $lenA = [int]$txtLog.TextLength; Limit-LogText; $aA = [string]$txtLog.Text
$tB = New-LogLines 400000
Set-LogText $tB; Limit-LogText; $aB = [string]$txtLog.Text
Chk 'L1' ($tA.Length -eq 399999 -and $lenA -eq 399999 -and $aA -ceq $tA -and $tB.Length -eq 400000 -and $aB -ceq $tB -and [string]$script:LogCut.Mark -ceq '' -and [int]$script:LogCut.N -eq 0) "399 999 puis 400 000 caracteres : journal inchange, aucune marque (longueur vue par le controle : $lenA)"
$t1 = New-LogLines 400001
Set-LogText $t1; Limit-LogText
$a1 = [string]$txtLog.Text; $m1 = [string]$script:LogCut.Mark; $n1 = [int]$script:LogCut.N
$k1 = ''; $c1 = -1; $lineStart = $false
if ($m1 -and $a1.StartsWith($m1 + "`n", $ord)) { $k1 = $a1.Substring($m1.Length + 1); $c1 = $t1.Length - $k1.Length; if ($c1 -gt 0 -and $c1 -le $t1.Length) { $lineStart = ($t1[$c1 - 1] -eq [char]10) } }
Chk 'L2' ($m1 -ceq (Get-MarkText $c1) -and $n1 -eq $c1 -and $k1.Length -gt 0 -and $t1.EndsWith($k1, $ord) -and $lineStart -and $k1.StartsWith('ligne ', $ord) -and $a1.Length -le $max -and [int]$txtLog.TextLength -eq $a1.Length -and (Get-MarkCount $a1) -eq 1) "400 001 caracteres : marque en premiere ligne (« $(if ($m1.Length -gt 70) { $m1.Substring(0, 70) + '...' } else { $m1 }) »), suivie de la fin du journal a partir d un debut de ligne ; $n1 caracteres retires, $($a1.Length) gardes, marque comprise ($max au plus)"
Chk 'L2b' ($k1.Length -ge $keep -and $k1.Length -lt ($keep + 80) -and $c1 -gt ($t1.Length - $keep - 80) -and $c1 -le ($t1.Length - $keep) -and $txtLog.ReadOnly) "la coupe recule jusqu au debut de la ligne en cours : $($k1.Length) caracteres du journal gardes ($keep et moins d une ligne de plus), environ 150 000 retires comme avant ; le journal reste en lecture seule"
$txtLog.Select(1, 5); $colM = $txtLog.SelectionColor.ToArgb(); $txtLog.Select($m1.Length + 3, 5); $colK = $txtLog.SelectionColor.ToArgb()
Chk 'L2c' ($colM -eq $script:LogColors.warn.ToArgb() -and $colK -ne $colM) "la marque est ecrite dans la couleur d avertissement du journal, pas le texte qui la suit"
# Second depassement, la marque etant en place : une seule marque, compte cumule
$more = New-LogLines 150000 900000
$txtLog.AppendText($more); Limit-LogText
$a2 = [string]$txtLog.Text; $m2 = [string]$script:LogCut.Mark; $n2 = [int]$script:LogCut.N
$all2 = $t1 + $more; $k2 = ''; $c2 = -1; $ls2 = $false
if ($m2 -and $a2.StartsWith($m2 + "`n", $ord)) { $k2 = $a2.Substring($m2.Length + 1); $c2 = $all2.Length - $k2.Length; if ($c2 -gt 0 -and $c2 -le $all2.Length) { $ls2 = ($all2[$c2 - 1] -eq [char]10) } }
Chk 'L3' ((Get-MarkCount $a2) -eq 1 -and $m2 -ceq (Get-MarkText $c2) -and $n2 -eq $c2 -and $n2 -gt $n1 -and $k2.Length -gt 0 -and $all2.EndsWith($k2, $ord) -and $ls2 -and $a2.Length -le $max -and $k2.Length -ge $keep -and $k2.Length -lt ($keep + 80)) "second depassement : une seule marque, qui remplace la precedente ; compte cumule : $n1 puis $n2 caracteres retires du journal, marque non comptee ; coupe en debut de ligne ; $($a2.Length) caracteres gardes"
# Partie retiree sans fin de ligne : coupe au caractere
$t4 = ('x' * 300000) + "`n" + (New-LogLines 100001)
$err4 = ''
Set-LogText $t4
try { Limit-LogText } catch { $err4 = "$($_.Exception.Message)" }
$a4 = [string]$txtLog.Text; $m4 = [string]$script:LogCut.Mark; $k4 = ''
if ($m4 -and $a4.StartsWith($m4 + "`n", $ord)) { $k4 = $a4.Substring($m4.Length + 1) }
Chk 'L4' ($err4 -ceq '' -and $k4.Length -eq $keep -and $t4.EndsWith($k4, $ord) -and $k4.StartsWith('xxxx', $ord) -and [int]$script:LogCut.N -eq ($t4.Length - $keep) -and $m4 -ceq (Get-MarkText ($t4.Length - $keep)) -and $a4.Length -le $max) "ligne de 300 000 caracteres en tete, aucune fin de ligne dans la partie retiree : coupe au caractere, sans erreur ; $($script:LogCut.N) caracteres retires, exactement $($k4.Length) gardes"
# Seule fin de ligne de la partie retiree : celle de la marque en place
$big5 = ('y' * 400000) + "`n"
$txtLog.Clear(); $txtLog.Text = $m4 + "`n" + $big5; $n4 = [int]$script:LogCut.N
$err5 = ''
try { Limit-LogText } catch { $err5 = "$($_.Exception.Message)" }
$a5 = [string]$txtLog.Text; $m5 = [string]$script:LogCut.Mark; $k5 = ''
if ($m5 -and $a5.StartsWith($m5 + "`n", $ord)) { $k5 = $a5.Substring($m5.Length + 1) }
Chk 'L5' ($err5 -ceq '' -and (Get-MarkCount $a5) -eq 1 -and $k5.Length -eq $keep -and $big5.EndsWith($k5, $ord) -and [int]$script:LogCut.N -eq ($n4 + $big5.Length - $keep) -and $m5 -ceq (Get-MarkText ($n4 + $big5.Length - $keep))) "marque en place suivie d une ligne de 400 000 caracteres : la fin de ligne de la marque ne sert pas de coupe, coupe au caractere ; compte cumule $n4 + $($big5.Length - $keep) = $($script:LogCut.N)"
# « Vider » (540 : $txtLog.Clear()) : la marque n est plus en tete, le compte repart de zero
$hClear = @($asts[$f540].EndBlock.Statements | Where-Object { $_.Extent.Text.StartsWith('$btnClear.Add_Click(', $ord) })
$nBefore = [int]$script:LogCut.N
$txtLog.Clear(); $txtLog.Text = $t1
Limit-LogText
$a6 = [string]$txtLog.Text
Chk 'L6' ($hClear.Count -eq 1 -and $hClear[0].Extent.Text -ceq '$btnClear.Add_Click({ $txtLog.Clear() })' -and $nBefore -gt $n1 -and [int]$script:LogCut.N -eq $n1 -and $a6 -ceq $a1 -and (Get-MarkCount $a6) -eq 1) "apres « Vider » (le bouton vide le journal sans autre effet), un nouveau depassement recompte depuis zero : $($script:LogCut.N) caracteres retires, et non $nBefore de plus"
# Append-Log reelle : la troncature vient par elle
Set-LogText (New-LogLines 399990)
Append-Log 'Calibration : derniere ligne ajoutee par Append-Log'
$a7 = [string]$txtLog.Text; $m7 = [string]$script:LogCut.Mark
Set-LogText "premiere`n"
Append-Log 'seconde'
$a7s = [string]$txtLog.Text
$alCmd = Get-CmdNames $fns['Append-Log']; $llCalls = Get-CallsOf 'Limit-LogText'
$alNum = @($fns['Append-Log'].FindAll({ param($n) $n -is $tNum -and $n.Value -is [int] -and [int]$n.Value -ge 1000 }, $true))
$llNum = @($fns['Limit-LogText'].FindAll({ param($n) $n -is $tNum -and $n.Value -is [int] -and [int]$n.Value -gt 1000 }, $true))
$kmo = Get-KeyOwners $kMk
Chk 'L7' ($m7 -and $a7.StartsWith($m7 + "`n", $ord) -and $a7.EndsWith("`nCalibration : derniere ligne ajoutee par Append-Log`n", $ord) -and $a7.Length -le $max -and (Get-MarkCount $a7) -eq 1 -and $a7s -ceq "premiere`nseconde`n" -and @($alCmd | Where-Object { $_ -ceq 'Limit-LogText' }).Count -eq 1 -and $llCalls.Count -eq 1 -and $llCalls[0].Owner -ceq 'Append-Log' -and $alNum.Count -eq 0 -and $llNum.Count -eq 0 -and ($kmo -join ',') -ceq 'Limit-LogText') "Append-Log reelle : une ligne ajoutee a un journal de 399 990 caracteres le tronque, marque en tete, la ligne ajoutee en fin ; petit journal : aucune marque ; statique : Append-Log appelle Limit-LogText une fois et ne porte plus de borne chiffree, Limit-LogText lit ses bornes dans les constantes et porte seule le texte de la marque"
# Marque en anglais, et dans le fichier exporte
$script:Lang = 'en'
try { Set-LogText $t1; Limit-LogText; $m8 = [string]$script:LogCut.Mark; $a8 = [string]$txtLog.Text } finally { $script:Lang = 'fr' }
$exp2 = Join-Path $here 'export-journal-tronque.txt'
if (Test-Path -LiteralPath $exp2) { Remove-Item -LiteralPath $exp2 -Force }
Export-LogFile $exp2
$rl2 = @([System.IO.File]::ReadAllText($exp2, [System.Text.Encoding]::UTF8) -split "`n")
Chk 'L8' ($m8 -ceq ($eMk -f "$n1") -and $a8.StartsWith($m8 + "`n", $ord) -and $rl2.Count -gt 4 -and $rl2[0].StartsWith('Journal exporté le ', $ord) -and $rl2[2] -ceq $m8 -and $rl2[3].StartsWith('ligne ', $ord)) "interface en anglais : « $(if ($m8.Length -gt 60) { $m8.Substring(0, 60) + '...' } else { $m8 }) » ; journal tronque exporte : en-tete, puis la marque en troisieme ligne du fichier, puis le journal"
$txtLog.Dispose()

# ================================================================ I. textes (019)
"--- I. cles de 019-i18n-1211.ps1"
$t019 = [System.IO.File]::ReadAllText((Join-Path $mods $f019), [System.Text.Encoding]::UTF8)
function Get-Ph([string]$s) { return (@([regex]::Matches($s, '\{\d+\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ',') }
$iBad = @(); $iTxt = @()
foreach ($p in @(@($kH1, $eH1, '{0},{1},{2},{3}'), @($kH2, $eH2, '{0},{1}'), @($kMk, $eMk, '{0}'))) {
    $k = [string]$p[0]; $en = [string]$script:I18n[$k]
    $iTxt += "$(Get-Ph $k)"
    if (-not $script:I18n.ContainsKey($k) -or $en -cne [string]$p[1] -or (Get-Ph $k) -cne (Get-Ph $en) -or (Get-Ph $k) -cne [string]$p[2] -or ([regex]::Matches($t019, [regex]::Escape($k))).Count -ne 1) { $iBad += $k.Substring(0, 30) }
}
Chk 'I1' ($iBad.Count -eq 0 -and [string]$script:I18n['(même lecteur)'] -ceq '(same drive)') "les trois textes francais de l en-tete et de la marque ont leur cle dans 019, une fois, avec le texte anglais attendu et les memes parametres des deux cotes ($($iTxt -join ' ; ')) ; « (même lecteur) » garde sa cle de 018 ; en defaut : $($iBad.Count)"

# ================================================================ D. documents
"--- D. README, CHANGELOG"
$readme = [System.IO.File]::ReadAllText((Join-Path $Wt 'README.md'), [System.Text.Encoding]::UTF8)
$chg = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
$s11 = ''; $b11 = $chg.IndexOf('## [12.11]', $ord); $b10 = $chg.IndexOf('## [12.10]', $ord)
if ($b11 -ge 0 -and $b10 -gt $b11) { $s11 = $chg.Substring($b11, $b10 - $b11) }
Chk 'D1' ($readme.Contains("7 échanges au moins, jusqu'à 13 en test fin et 17 en test standard") -and -not $readme.Contains('9 échanges au moins')) "README : « 7 échanges au moins, jusqu'à 13 en test fin et 17 en test standard », plus de « 9 échanges au moins »"
Chk 'D2' ($s11.Contains('le nombre d''échanges annoncé va de 7, et non 9, à 13 ou 17') -and $s11.Contains('Journal exporté') -and $s11.Contains('la fenêtre de choix propose d''abord le lecteur cible de l''onglet') -and $s11.Contains('[Journal tronqué : les ')) "CHANGELOG, section 12.11 : echanges annonces de 7 et non 9, journal exporte et marque de troncature, lecteur cible propose d abord"

$nk = ''; if ($script:Fail) { $nk = ' ; non conformes : ' + (@($script:FailIds) -join ', ') }
"=== bilan logic-croisee-journal-echanges : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
