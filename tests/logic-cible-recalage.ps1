param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 rc8 (R17) : recalage de la courbe croisee par une relecture du lecteur cible (172-fn-recalage-cible.ps1 et lignes
# ajoutees a 040, 110, 112, 120, 140, 170, 190, 240, 540, 560, 600). Fonctions reelles de tous les modules fn, extraites par
# l arbre syntaxique et chargees par dot-source ; constantes reelles de 040 ; bouchons pour le journal, l enregistrement, les
# fenetres (Show-AppConfirm repond par une valeur posee par le cas) et la copie de la configuration. Donnees synthetiques
# seulement : lecteurs « A » (qui ecrit) et « 0 » (lecteur cible), courbes et relectures fabriquees ici. Attentes ecrites ici
# d apres la regle, sans les fonctions testees.
#  U  Get-TargetTransferSpec : recalage 0 (defaut) identique a l appel sans parametre (chaine, valeurs, exces) ; recalage
#     arrondi au ns, limite a 25 % de la valeur du cylindre, valeur nulle inchangee, borne max(borne, X, D) ; exces apres ;
#     courbe egale a X (D = Sp) : profil recalcule.
#  N  cumul : somme des estimations / (n + p), p = (1 - F) / F, F = TargetRecalFirstShare = 0,75 (version finale : les trois
#     quarts des la premiere ecriture relue ; rc8 : p = 1), plafond 8 ns, une decimale (arrondi au pair de .NET :
#     -3,75 -> -3,8) ; N2 f(1) a f(5) exacts (0,75 ; 6/7 ; 0,9 ; 12/13 ; 15/16) et plafond ; N3 la constante commande le
#     resultat (0,5 : regle de la rc8 ; 1 : moyenne ; hors de ]0 ; 1] : 0).
#  R  relecture par le lecteur cible (Get-TargetRecalReadback) : estimation exacte (g mesure, borne, repli 1,7 ; pistes en
#     erreur et zones exclues) ; refus : pas « SUPPORT SAIN », famille, nombre de pistes, tetes, relecture anterieure, peu de
#     pistes, peu de blocs, facteur non mesure, controle eloigne, ecart median > 12 ns, autre lecteur.
#  C  cumul dans le magasin (Get-TargetRecalUpdate) : premiere relecture, meme ecriture relue deux fois, ecritures suivantes,
#     cinq au plus, remise a zero (autre courbe croisee, autre calcul).
#  A  application (Get-TargetRecalPlan, Get-TargetTransferPlan) : courbe ecrite = regle + arrondi(o) cylindre par cylindre ;
#     sans recalage, aucun changement ; facteur non mesure, courbe recalibree, profil Manuel : rien ; ecriture rapide : moyenne.
#  O  proposition apres une mesure (Invoke-TargetRecalOffer) : confirmee (magasin, journal, enregistrement), refusee, mesure
#     continue, refus de la regle au journal, autre lecteur sans rien.
#  M  memoire de l ecriture (New-TargetWriteMemory, Complete-TargetWriteMemory, Update-TargetWriteMemoryGw).
#  D  fenetre « Lecteurs » : texte du recalage, « Annuler le recalage » (copie de la configuration d abord).
#  E  « Effacer les calibrations » efface les recalages et la memoire ; X nouvelle calibration croisee ; J configuration ;
#  K  lecteur renomme ou retire (Edit-DriveData).
# Relecture de la rc8 : U4 atteint vraiment la borne ; R16, O9 courbe croisee recalibree (ou calcul change) depuis
# l ecriture : tete refusee, rien propose ; O8 effet annonce limite a 25 % ; M6 memoire precedente de la paire retiree au
# lancement d une nouvelle ecriture (Set-TargetWritePending) ; K1 lecteur qui ecrit renomme et entrees d une autre paire
# gardees.
# Version finale, mesure obligatoire pour apprendre :
#  L  L1 Test-TargetRecalKLearn ('mesure' seule, les deux tetes en ecriture rapide) face a Test-TargetRecalKMeasured ; L2
#     'lecteur' applique toujours le recalage (Get-TargetRecalPlan), 'defaut' non ; L3 a L6 memoire d ecritures faites avec
#     un facteur mesure, de la marque, mele (rapide) ou k = 1 : ligne de fin d ecriture, relecture refusee par tete avec sa
#     raison, proposition non affichee, memoire gardee ; L7 origine absente ; L8 memoires de la rc8 (sans KLearn) et
#     configuration ; L9 textes anglais.
#     Relecture de la version finale : L10 memoire de la rc8 d une ecriture lente faite avec le facteur de la marque
#     (directe et relue de la configuration) : refusee, rien propose ; L11 relecture partielle et mesure continue d une
#     ecriture qui ne peut rien apprendre : sa raison, jamais « mesurez les memes cylindres » ; L12 consigne de fin
#     d ecriture selon l onglet (mesure faite avant sans facteur determine, « Ecrire sans mesure », « Test rapide », case
#     cochee avec une autre mesure, image non mesurable, restauration, facteur non applique) ; L13 tete exclue nommee par
#     sa tete physique (hswap). Onglet Ecriture simule ($chkWLevel, $cmbWCalMode, $cmbWFmt, $txtWTracks), mesure sur
#     l image possible ou non par des remplacants de Get-LevelWriteSkip (140) et Test-ContentMeasurable (276).
# Non couvert ici : l interface affichee (fenetre de confirmation, fenetre « Lecteurs »), une ecriture et une mesure reelles ;
# les ecritures « meme lecteur » et sans recalage sont couvertes par les empreintes de logic-cible-facteur.
Import-TestWinForms
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
$utf8b = New-Object System.Text.UTF8Encoding($true)
$mods = Join-Path $Wt 'src\modules'
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'
# Fonctions de tous les modules fn ; versions de 000 ; constantes de 040
$fns = New-Object System.Collections.Generic.List[string]
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Where-Object { $_.Name -match '^[1-4]\d\d-fn-' } | Sort-Object Name)) {
    foreach ($fd in (Get-Ast $f.FullName).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) { $fns.Add($fd.Extent.Text) }
}
$st = New-Object System.Collections.Generic.List[string]
foreach ($s in (Get-Ast (Join-Path $mods '000-entete.ps1')).EndBlock.Statements) { $t = $s.Extent.Text; if ($t -match '^\$script:(Version|VersionLabel|CalibCalc|CalibCalcHd|ContentCalc)\s*=') { $st.Add($t) } }
$gen = Join-Path $here 'gen-fonctions.ps1'
[System.IO.File]::WriteAllText($gen, ((@($fns) -join "`r`n`r`n") + "`r`n`r`n" + (@($st) -join "`r`n") + "`r`n"), $utf8b)
. $gen
. (Join-Path $mods '040-etat-formats.ps1')

# --- Bouchons et etat ---------------------------------------------------------------------------------------------------
$script:Log = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text) { $script:Log.Add($text) }
$script:Saves = 0
function Save-Config { $script:Saves++; return $true }
$script:ConfirmAns = $true; $script:ConfirmArgs = $null; $script:ConfirmN = 0
function Show-AppConfirm([string]$Title, [string]$Heading, [string]$Text, [string]$Check = '', [string]$GoText = '', [string]$GoGlyph = '', [string]$Level = 'warn', [string]$Picto = 'warn', [string]$AltText = '', $Combo = $null) {
    $script:ConfirmN++; $script:ConfirmArgs = @{ Title = $Title; Heading = $Heading; Text = $Text; Check = $Check; GoText = $GoText; Level = $Level }
    return [bool]$script:ConfirmAns
}
$script:MsgText = ''
function Show-AppMessage([string]$text, [string]$title, [string]$buttons = 'OK', [string]$icon = 'Information') { $script:MsgText = $text; return 'Yes' }
function Get-AppBusy([switch]$Text) { return '' }
$script:ProtectOk = $true; $script:ProtectN = 0
function Protect-DriveData([string[]]$drives) { $script:ProtectN++; return @{ Ok = [bool]$script:ProtectOk; Bak = ''; Copy = $true; Why = 'copie factice en echec' } }
function Update-PrecompForImage($p) { }
function Backup-ConfigBeforeRef([string[]]$keys, [string]$why = 'replace', [string]$Protect = '') { return $null }
$script:Manual = $false
function Test-ManualPrecomp { return [bool]$script:Manual }
$cmbDrive = New-Object System.Windows.Forms.ComboBox; $cmbDrive.Text = 'A'
$txtWFile = New-Object System.Windows.Forms.TextBox
$pbWCal = New-Object System.Windows.Forms.ProgressBar; $lblWCal = New-Object System.Windows.Forms.Label
# Version finale (relecture) : onglet Ecriture lu par la consigne de fin d ecriture (Get-TargetWriteLearnHow, 172) : case
# « Mesurer la disquette » (vrai Test-WriteLevelWanted, 140), « Calibration precomp » (2 : Test rapide), liste « Mesure »
# (vrai Get-LevelBeforeWriteKind, 260) ; mesure sur l image possible ou non ($script:FkMeasurable, $script:FkSkip)
$chkWLevel = [pscustomobject]@{ Checked = $false }
$cmbWCalMode = [pscustomobject]@{ SelectedIndex = 1 }
$cmbWFmt = [pscustomobject]@{ Text = '(auto)' }
$txtWTracks = [pscustomobject]@{ Text = '' }
$script:Settings['levelBeforeWriteMode'] = 'content'
$script:FkMeasurable = $true; $script:FkSkip = $null
function Get-LevelWriteSkip([string]$img, [string]$fmt, [string]$ts) { return $script:FkSkip }
function Test-ContentMeasurable([string]$img, [string]$fmt) { return @{ Ok = [bool]$script:FkMeasurable; Why = 'image factice' } }
$script:Theme = @{ Danger = [System.Drawing.Color]::Red; Muted = [System.Drawing.Color]::Gray }
$script:CurveKeys = @('std', 'long', 'std_h0', 'std_h1', 'long_h0', 'long_h1', 'hd', 'hd_h0', 'hd_h1')
$script:PrecompCurves = @{}; $script:DriveReg = @{}; $script:TargetDrives = @{}; $script:LevelShifts = @{}; $script:LevelBrands = @(); $script:OldCalib = $null
$script:ConfigFile = Join-Path $here 'GreaseweazleGUI.json'
$script:WriteQueue = New-Object System.Collections.Queue
$script:WriteTracks = @{}; $script:GwLastArgs = @(); $script:Cal = $null; $script:Restore = $null; $script:AlignLoop = $false
$script:QualView = @{ Pass = 0 }
$XD = '12/11/2026 15:20'
function New-FkCurve([string]$drive, [string]$tgt, $head, [string]$spec, [string]$date = $XD) {
    return @{ Drive = $drive; Target = $tgt; Head = $head; Date = $date; Spec = $spec; Values = @(); Method = 'motif'; Calc = $script:CalibCalc; Test = 'fine'; Family = 'Standard 2 us' }
}
function Reset-Fk {
    $script:Log.Clear(); $script:Saves = 0; $script:ConfirmN = 0; $script:ConfirmArgs = $null; $script:ConfirmAns = $true; $script:ProtectN = 0; $script:ProtectOk = $true; $script:Manual = $false
    $script:TargetRecal = @{}; $script:LastTargetWrites = @{}; $script:TargetWritePending = $null; $script:AlignLoop = $false; $script:QualView = @{ Pass = 0 }
    $script:DriveCurves = @{
        'A|std_h0' = (New-FkCurve 'A' '' 0 '0=40:40=30:70=26' '15/11/2026 10:00'); 'A|std_h1' = (New-FkCurve 'A' '' 1 '0=38:40=28:70=24' '15/11/2026 10:00')
        'A>0|std_h0' = (New-FkCurve 'A' '0' 0 '0=60:40=44:70=36'); 'A>0|std_h1' = (New-FkCurve 'A' '0' 1 '0=58:40=42:70=34')
        'A>0|std' = (New-FkCurve 'A' '0' $null '0=59:40=43:70=35' '16/11/2026 17:30') }
    $script:ContentMeasures = @(
        @{ Drive = '0'; Family = 'std'; Head = 0; Date = '20/11/2026 09:00'; ContentCalc = $script:ContentCalc; Calc = $script:CalibCalc; SRelAsym = 0.50; Method = 'asym' },
        @{ Drive = '0'; Family = 'std'; Head = 0; Date = '21/11/2026 10:00'; ContentCalc = $script:ContentCalc; Calc = $script:CalibCalc; SRelAsym = 0.70; Method = 'asym' },
        @{ Drive = '0'; Family = 'std'; Head = 0; Date = '22/11/2026 08:00'; ContentCalc = '12.9'; Calc = $script:CalibCalc; SRelAsym = 0.90; Method = 'asym' },
        @{ Drive = 'A'; Family = 'std'; Head = 1; Date = '22/11/2026 08:00'; ContentCalc = $script:ContentCalc; Calc = $script:CalibCalc; SRelAsym = 0.95; Method = 'asym' })
}
function New-FkMem([string]$id = 'W20261122100000', [string]$at = '2026-11-22 10:00:00', [int]$o0 = 0, [int]$o1 = 0, [string]$verdict = 'ok', [bool]$k0 = $true, [bool]$k1 = $true) {
    return @{ Id = $id; Date = '22/11/2026 10:00'; At = $at; Image = 'essai.adf'; Fam = 'std'; Slow = $true; Tracks = 160; Heads = [int[]]@(0, 1); Verdict = $verdict; Calc = $script:CalibCalc
              H = @{ '0' = @{ Phys = 0; W = '0=40:40=32:70=24'; O = $o0; ORecal = [double]$o0; XDate = $XD; XKey = 'std_h0'; K = 0.74; KSrc = $(if ($k0) { 'mesure' } else { 'defaut' }); KMeasured = $k0; Zones = [int[]]@() }
                     '1' = @{ Phys = 1; W = '0=38:40=30:70=22'; O = $o1; ORecal = [double]$o1; XDate = $XD; XKey = 'std_h1'; K = 0.74; KSrc = $(if ($k1) { 'mesure' } else { 'defaut' }); KMeasured = $k1; Zones = [int[]]@() } } }
}
# Relecture synthetique : e(c) = e0 + ((c mod 5) - 2) x 0,5 ns (mediane e0 sur 80 cylindres), d3 = d4 = e x g / cellule / 2
function New-FkRead([hashtable]$e0, [hashtable]$g, [int]$nCyl = 80, [int[]]$heads = @(0, 1), [double]$cell = 2000) {
    $t = @{}
    foreach ($h in $heads) {
        for ($c = 0; $c -lt $nCyl; $c++) {
            $e = [double]$e0[$h] + (($c % 5) - 2) * 0.5
            $d = $e * [double]$g[$h] / $cell / 2
            $t["$c.$h"] = @{ Bad = $false; Weak = $false; Level = 0; Ooc = 0.0; R3 = 1.5 + $d; R4 = 2.0 + $d; Cell = $cell }
        }
    }
    return $t
}
$AT = [datetime]::ParseExact('2026-11-22 11:00:00', 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
$G = @{ 0 = 1.4; 1 = 1.7 }     # tete 0 : 2 x 0,70 (derniere mesure du calcul courant) ; tete 1 : repli
function Near([double]$a, [double]$b, [double]$tol = 1e-6) { return ([math]::Abs($a - $b) -le $tol) }

# =====================================================================================================================
# U : Get-TargetTransferSpec
Reset-Fk
$sets = @(@('0=40:40=30:70=26', '0=40:40=30:70=26', '0=60:40=44:70=36'), @('0=29:40=22:70=19', '0=40:40=30:70=26', '0=60:40=44:70=36'),
          @('0=80:40=60:70=50', '0=40:40=30:70=26', '0=60:40=44:70=36'), @('0=8:20=4:60=0', '0=12:20=6:60=0', '0=10:20=6:60=0'))
$same = $true
foreach ($s3 in $sets) {
    $a = Get-TargetTransferSpec $s3[0] $s3[1] $s3[2] 84 400
    $b = Get-TargetTransferSpec $s3[0] $s3[1] $s3[2] 84 400 0
    if ([string]$a.Spec -cne [string]$b.Spec -or (@($a.Values) -join ',') -ne (@($b.Values) -join ',') -or (@($a.Excess) -join ',') -ne (@($b.Excess) -join ',') -or [int]$a.Recal -ne 0 -or @($a.RecalLimited).Count -ne 0) { $same = $false }
}
$a0 = Get-TargetTransferSpec '0=40:40=30:70=26' '0=40:40=30:70=26' '0=60:40=44:70=36' 84 400
Chk 'U1' ($same -and [string]$a0.Spec -ceq '0=60:40=44:70=36') 'recalage 0 (defaut et explicite) : courbe, valeurs et exces identiques ; D = Sp : chaine de X telle quelle'
# Recalage -3,4 : arrondi -3, valeurs >= 12 decalees de -3 ; 4 a 11 : limite a floor(25 %) ; 0 : inchangee
$b = Get-TargetTransferSpec '0=8:20=4:60=0' '0=12:20=6:60=0' '0=10:20=6:60=0' 84 400
$r = Get-TargetTransferSpec '0=8:20=4:60=0' '0=12:20=6:60=0' '0=10:20=6:60=0' 84 400 -3.4
function Get-FkV([string]$spec, [int]$c) { $v = 0; foreach ($e in ($spec -split ':')) { if ($e -match '^(\d+)=(\d+)$' -and [int]$Matches[1] -le $c) { $v = [int]$Matches[2] } }; return $v }
$ok = $true; $lim = @()
for ($c = 0; $c -lt 84; $c++) {
    $v = [int]$b.Values[$c]; $l = [int][math]::Floor(0.25 * $v); $oc = [math]::Max(-$l, [math]::Min($l, -3)); if ($v -gt 0 -and $oc -ne -3) { $lim += $c }
    if ([int]$r.Values[$c] -ne $(if ($v -gt 0) { $v + $oc } else { 0 })) { $ok = $false }
}
Chk 'U2' ($ok -and [int]$r.Recal -eq -3 -and (@($r.RecalLimited) -join ',') -eq ($lim -join ',') -and $lim.Count -gt 0 -and [int]$r.Values[70] -eq 0) "recalage -3,4 : -3 ns, limite a 25 % de la valeur (cylindres $(@($r.RecalLimited).Count)), valeur nulle inchangee"
$ok = $true
for ($c = 0; $c -lt 84; $c++) { if ([int]$r.Excess[$c] -ne [int]$r.Values[$c] - (Get-FkV '0=8:20=4:60=0' $c)) { $ok = $false } }
Chk 'U3' $ok 'exces (courbe ecrite - D) calcule apres le recalage'
# Borne (relecture rc8 : cas qui l atteint vraiment) : X 420, D 410, Sp 400 : 420 x 410 / 400 = 430,5, ramene a X + (D - Sp)
# = 430, puis a max(borne 400, X 420, D 410) = 420 ; recalage +5 sans effet au-dessus. Sous la borne (X 390 : 400) : +5 entier
$hb = Get-TargetTransferSpec '0=410' '0=400' '0=420' 84 400 5
$hn = Get-TargetTransferSpec '0=410' '0=400' '0=420' 84 400
$lb = Get-TargetTransferSpec '0=410' '0=400' '0=390' 84 400 5
$ln = Get-TargetTransferSpec '0=410' '0=400' '0=390' 84 400
Chk 'U4' ([int]$hn.Values[0] -eq 420 -and [int]$hb.Values[0] -eq 420 -and [int]$ln.Values[0] -eq 400 -and [int]$lb.Values[0] -eq 405) "recalage +5 borne a max(borne, X, D) : a la borne $($hn.Values[0]) -> $($hb.Values[0]) ; dessous $($ln.Values[0]) -> $($lb.Values[0])"
$sx = Get-TargetTransferSpec '0=40:40=30:70=26' '0=40:40=30:70=26' '0=60:40=44:70=36' 84 400 -2
Chk 'U5' ([string]$sx.Spec -ceq (Build-CurveProfile $sx.Values) -and [string]$sx.Spec -ceq '0=58:40=42:70=34') "D = Sp avec recalage -2 : profil recalcule ($($sx.Spec))"

# =====================================================================================================================
# N : cumul
$n1 = Get-TargetRecalNs @(@{ Est = -6.0 })
$n2 = Get-TargetRecalNs @(@{ Est = -6.0 }, @{ Est = -3.0 })
$n3 = Get-TargetRecalNs @(@{ Est = -20.0 })
$n4 = Get-TargetRecalNs @(@{ Est = 30.0 }, @{ Est = 30.0 })
$n5 = Get-TargetRecalNs @(@{ Est = -4.0 }, @{ Est = -4.0 }, @{ Est = -4.0 }, @{ Est = -4.0 }, @{ Est = -4.0 })
$n6 = Get-TargetRecalNs @(@{ Est = -5.55 })
# Attentes calculees a la main, somme / (n + 1/3) : -6 / (4/3) = -4,5 ; -9 / (7/3) = -3,857 -> -3,9 ; -20 / (4/3) = -15 et
# 60 / (7/3) = 25,7 : plafond -8 et 8 ; -20 / (16/3) = -3,75 -> -3,8 (au pair) ; -5,55 / (4/3) = -4,1625 -> -4,2. La regle
# de la rc8 (n + 1) donnait -3,0 ; -3,0 ; -8 ; 8 ; -3,3 ; -2,8
Chk 'N1' ($script:TargetRecalFirstShare -eq 0.75 -and (Near $n1 -4.5) -and (Near $n2 -3.9) -and (Near $n3 -8.0) -and (Near $n4 8.0) -and (Near $n5 -3.8) -and (Near (Get-TargetRecalNs @()) 0) -and (Near $n6 -4.2)) "somme/(n+1/3) : $n1, $n2 ; plafond : $n3, $n4 ; cinq ecritures : $n5 ; une decimale : $n6"
# Part f(n) de l ecart moyen m retenue, avec des moyennes dont le produit est exact : f(1) = 3/4 (m -4 : -3) ; f(2) = 6/7
# (m -7 : -6) ; f(3) = 9/10 (m -5 : -4,5) ; f(4) = 12/13 (m -6,5 : -6) ; f(5) = 15/16 (m -3,2 : -3) ; plafond des deux
# cotes : m +12 et -12 donneraient +9 et -9
$f1 = Get-TargetRecalNs @(@{ Est = -4.0 })
$f2 = Get-TargetRecalNs @(@{ Est = -7.0 }, @{ Est = -7.0 })
$f3 = Get-TargetRecalNs @(1..3 | ForEach-Object { @{ Est = -5.0 } })
$f4 = Get-TargetRecalNs @(1..4 | ForEach-Object { @{ Est = -6.5 } })
$f5 = Get-TargetRecalNs @(1..5 | ForEach-Object { @{ Est = -3.2 } })
$cp = Get-TargetRecalNs @(@{ Est = 12.0 }); $cm = Get-TargetRecalNs @(@{ Est = -12.0 })
Chk 'N2' ((Near $f1 -3.0) -and (Near ($f1 / -4.0) 0.75) -and (Near $f2 -6.0) -and (Near ($f2 / -7.0) (6.0 / 7)) -and (Near $f3 -4.5) -and (Near $f4 -6.0) -and (Near $f5 -3.0) -and (Near $cp 8.0) -and (Near $cm -8.0)) "f(1) = $($f1 / -4.0), f(2) = $($f2 / -7.0) ; f(3) a f(5) : $f3, $f4, $f5 ; plafond : $cp, $cm"
# La constante de 040 commande le resultat : 0,5 redonne la regle de la rc8 (-6 : -3) ; 1, la moyenne (-6 et -3 : -4,5) ;
# 0 ou 1,5 : aucun recalage
$fs = $script:TargetRecalFirstShare
$script:TargetRecalFirstShare = 0.5; $g5 = Get-TargetRecalNs @(@{ Est = -6.0 })
$script:TargetRecalFirstShare = 1.0; $g10 = Get-TargetRecalNs @(@{ Est = -6.0 }, @{ Est = -3.0 })
$script:TargetRecalFirstShare = 0.0; $g0 = Get-TargetRecalNs @(@{ Est = -6.0 })
$script:TargetRecalFirstShare = 1.5; $g15 = Get-TargetRecalNs @(@{ Est = -6.0 })
$script:TargetRecalFirstShare = $fs
Chk 'N3' ((Near $g5 -3.0) -and (Near $g10 -4.5) -and (Near $g0 0) -and (Near $g15 0) -and (Near (Get-TargetRecalNs @(@{ Est = -6.0 })) -4.5)) "TargetRecalFirstShare 0,5 : $g5 ; 1 : $g10 ; 0 : $g0 ; 1,5 : $g15 ; 0,75 retablie"

# =====================================================================================================================
# R : relecture par le lecteur cible
Reset-Fk
$mem = New-FkMem
$rb = New-FkRead @{ 0 = 6.0; 1 = 4.0 } $G
$rb['12.0'].Ooc = 0.7; $rb['12.0'].R3 = 1.6                  # piste SAINE avec erreurs : exclue, relecture admise
$ev = Get-TargetRecalReadback $mem $rb 0 $AT '0' '0'
Chk 'R1' ($ev.Ok -and $ev.Heads['0'].Ok -and $ev.Heads['1'].Ok -and [int]$ev.Heads['0'].N -eq 79 -and [int]$ev.Heads['1'].N -eq 80 -and (Near ([double]$ev.Heads['0'].Med) 6.0) -and (Near ([double]$ev.Heads['1'].Med) 4.0) -and (Near ([double]$ev.Heads['0'].Est) -6.0) -and (Near ([double]$ev.Heads['1'].Est) -4.0)) "estimation : mediane e = 6 / 4 ns, est = -6 / -4 ; piste avec erreurs exclue (79 pistes)"
Chk 'R2' ((Near ([double]$ev.Heads['0'].G) 1.4) -and $ev.Heads['0'].GMeasured -and (Near ([double]$ev.Heads['1'].G) 1.7) -and -not $ev.Heads['1'].GMeasured -and [string]$ev.Fam -eq 'std') 'g : 2 x pente de la derniere mesure du calcul courant (1,4) ; sans mesure : repli 1,7 ; famille standard'
$script:ContentMeasures += @{ Drive = '0'; Family = 'std'; Head = 1; Date = '21/11/2026 11:00'; ContentCalc = $script:ContentCalc; Calc = $script:CalibCalc; SRelAsym = 2.0; Method = 'asym' }
Chk 'R3' (Near ([double](Get-TargetReadGain '0' 'std' 1).G) 3.0) 'pente bornee a ContentAsymSRelMax : g = 2 x 1,5'
Reset-Fk
# Zones de l ecriture exclues ; ecriture deja recalee de -3 : estimation absolue
$mem = New-FkMem -o0 -3
$mem.H['0'].Zones = [int[]]@(30..39)
$rb = New-FkRead @{ 0 = 2.0; 1 = 4.0 } $G
for ($c = 30; $c -le 39; $c++) { $rb["$c.0"].R3 = 1.6; $rb["$c.0"].R4 = 2.1 }
$ev = Get-TargetRecalReadback $mem $rb 0 $AT '0' '0'
Chk 'R4' ($ev.Ok -and [int]$ev.Heads['0'].N -eq 70 -and (Near ([double]$ev.Heads['0'].Est) -5.0) -and [int]$ev.Heads['0'].O -eq -3) "zones exclues (70 pistes) ; recalage applique -3 et mediane +2 : estimation -5"
function Test-FkWhy($ev, [string]$code) { return (@($ev.Why | Where-Object { [string]$_.Code -eq $code }).Count -gt 0) }
$mem = New-FkMem
$rb = New-FkRead @{ 0 = 3.0; 1 = 3.0 } $G; $rb['79.1'].Level = 1; $rb['79.1'].Ooc = 13.3
$ev = Get-TargetRecalReadback $mem $rb 1 $AT '0' '0'
Chk 'R5' (-not $ev.Ok -and (Test-FkWhy $ev 'health') -and ([string]@($ev.Why)[0].Text).Contains('79.1')) "piste A SURVEILLER : relecture refusee ($(@($ev.Why)[0].Text))"
$rb = New-FkRead @{ 0 = 3.0; 1 = 3.0 } $G 80 @(0, 1) 1890
$ev = Get-TargetRecalReadback $mem $rb 0 $AT '0' '0'
Chk 'R6' (-not $ev.Ok -and (Test-FkWhy $ev 'family') -and [string]$ev.Fam -eq 'long') 'cellule de 1 890 ns : famille long track, refusee'
$rb = New-FkRead @{ 0 = 3.0; 1 = 3.0 } $G 79
$ev = Get-TargetRecalReadback $mem $rb 0 $AT '0' '0'
Chk 'R7' (-not $ev.Ok -and (Test-FkWhy $ev 'tracks') -and -not (Test-FkWhy $ev 'heads')) '158 pistes relues pour 160 ecrites : refusee'
$rb = New-FkRead @{ 0 = 3.0; 1 = 3.0 } $G 80 @(0)
$ev = Get-TargetRecalReadback $mem $rb 0 $AT '0' '0'
Chk 'R8' (-not $ev.Ok -and (Test-FkWhy $ev 'heads') -and (Test-FkWhy $ev 'tracks')) 'tete 0 seule relue : refusee (tetes, nombre de pistes)'
$rb = New-FkRead @{ 0 = 3.0; 1 = 3.0 } $G
$ev = Get-TargetRecalReadback $mem $rb 0 ($AT.AddHours(-2)) '0' '0'
Chk 'R9' (-not $ev.Ok -and (Test-FkWhy $ev 'before')) 'relecture anterieure a l ecriture : refusee'
$rb = New-FkRead @{ 0 = 3.0; 1 = 3.0 } $G
for ($c = 0; $c -lt 25; $c++) { $rb["$c.1"].Ooc = 1.0 }
$ev = Get-TargetRecalReadback $mem $rb 0 $AT '0' '0'
Chk 'R10' ($ev.Ok -and $ev.Heads['0'].Ok -and -not $ev.Heads['1'].Ok -and [int]$ev.Heads['1'].N -eq 55 -and (@($ev.Heads['1'].Why) -join ' ').Contains('il en faut 60')) 'tete 1 : 55 pistes sans erreur, refusee seule ; tete 0 retenue'
$rb = New-FkRead @{ 0 = 3.0; 1 = 3.0 } $G
foreach ($c in @(0..79)) { if (($c -ge 50 -and $c % 10 -ge 4) -or ($c -lt 50 -and $c % 10 -eq 9 -and $c -gt 40)) { $rb["$c.1"].Ooc = 1.0 } }
$ev = Get-TargetRecalReadback $mem $rb 0 $AT '0' '0'
Chk 'R11' (-not $ev.Heads['1'].Ok -and [int]$ev.Heads['1'].N -ge 60 -and [int]$ev.Heads['1'].Blocks -eq 5 -and (@($ev.Heads['1'].Why) -join ' ').Contains('bloc')) "tete 1 : $($ev.Heads['1'].N) pistes sur $($ev.Heads['1'].Blocks) blocs de 10 cylindres a 5 pistes : refusee"
$memk = New-FkMem -k0 $false
$rb = New-FkRead @{ 0 = 3.0; 1 = 3.0 } $G
$ev = Get-TargetRecalReadback $memk $rb 0 $AT '0' '0'
$memk2 = New-FkMem -k0 $false -k1 $false
$ev2 = Get-TargetRecalReadback $memk2 $rb 0 $AT '0' '0'
Chk 'R12' ($ev.Ok -and -not $ev.Heads['0'].Ok -and $ev.Heads['1'].Ok -and -not $ev2.Ok) 'facteur k non mesure : tete refusee ; les deux : relecture refusee'
$memo = New-FkMem -verdict 'off'
$ev = Get-TargetRecalReadback $memo $rb 0 $AT '0' '0'
Chk 'R13' (-not $ev.Ok -and (Test-FkWhy $ev 'verdict')) 'controle « eloigne de l attendu » : refusee'
$rb = New-FkRead @{ 0 = 12.5; 1 = 3.0 } $G
$ev = Get-TargetRecalReadback $mem $rb 0 $AT '0' '0'
$rb2 = New-FkRead @{ 0 = 11.5; 1 = 3.0 } $G
$ev2 = Get-TargetRecalReadback $mem $rb2 0 $AT '0' '0'
Chk 'R14' (-not $ev.Heads['0'].Ok -and $ev.Heads['1'].Ok -and $ev2.Heads['0'].Ok -and (@($ev.Heads['0'].Why) -join ' ').Contains('12')) 'ecart median 12,5 ns : tete refusee ; 11,5 ns : retenue'
$ev = Get-TargetRecalReadback $mem $rb2 0 $AT 'B' '0'
Chk 'R15' (-not $ev.Ok -and (Test-FkWhy $ev 'notarget')) 'relu par un autre lecteur que le lecteur cible : refusee'
# Relecture rc8 : lecteur qui a ecrit connu ($src) : courbe croisee de la tete recalibree depuis l ecriture, ou calcul de
# calibration change : tete refusee ; courbe inchangee : retenue
$rb = New-FkRead @{ 0 = 3.0; 1 = 3.0 } $G
$evA = Get-TargetRecalReadback $mem $rb 0 $AT '0' '0' 'A'
$script:DriveCurves['A>0|std_h1'] = (New-FkCurve 'A' '0' 1 '0=58:40=42:70=34' '23/11/2026 09:00')
$evB = Get-TargetRecalReadback $mem $rb 0 $AT '0' '0' 'A'
$memc = New-FkMem; $memc.Calc = 'autre'
$evC = Get-TargetRecalReadback $memc $rb 0 $AT '0' '0' 'A'
$memn = New-FkMem; $memn.H['0'].XKey = ''
$evN = Get-TargetRecalReadback $memn $rb 0 $AT '0' '0' 'A'
Reset-Fk
Chk 'R16' ($evA.Ok -and $evA.Heads['0'].Ok -and $evA.Heads['1'].Ok -and $evB.Ok -and $evB.Heads['0'].Ok -and -not $evB.Heads['1'].Ok -and (@($evB.Heads['1'].Why) -join ' ').Contains('recalibrée') -and -not $evC.Ok -and -not $evC.Heads['0'].Ok -and -not $evC.Heads['1'].Ok -and $evN.Heads['0'].Ok) 'courbe croisee de la tete 1 recalibree depuis l ecriture : tete 1 refusee ; calcul change : les deux ; cle absente : courbe de la tete reprise'

# =====================================================================================================================
# C : cumul dans le magasin
Reset-Fk
$mem = New-FkMem
$rb = New-FkRead @{ 0 = 6.0; 1 = 4.0 } $G
$ev = Get-TargetRecalReadback $mem $rb 0 $AT '0' '0'
$up = Get-TargetRecalUpdate 'A' '0' $mem $ev $AT
$u0 = @($up | Where-Object { $_.Head -eq 0 })[0]; $u1 = @($up | Where-Object { $_.Head -eq 1 })[0]
Chk 'C1' (@($up).Count -eq 2 -and [string]$u0.Key -eq 'A>0|std_h0' -and (Near ([double]$u0.New.Ns) -4.5) -and (Near ([double]$u1.New.Ns) -3.0) -and [int]$u0.New.N -eq 1 -and [string]$u0.New.XDate -eq $XD -and [string]$u0.New.XKey -eq 'std_h0' -and -not $u0.Reset -and $null -eq $u0.Old) 'premiere relecture : o = 3/4 x est (-4,5 et -3), n = 1, date de X gardee'
foreach ($u in $up) { $script:TargetRecal[$u.Key] = $u.New }
$rb = New-FkRead @{ 0 = 4.0; 1 = 4.0 } $G
$ev = Get-TargetRecalReadback $mem $rb 0 $AT '0' '0'
$up = Get-TargetRecalUpdate 'A' '0' $mem $ev $AT
$u0 = @($up | Where-Object { $_.Head -eq 0 })[0]
Chk 'C2' ([int]$u0.New.N -eq 1 -and [int]@($u0.New.Items)[0].NR -eq 2 -and (Near ([double]@($u0.New.Items)[0].Est) -5.0) -and (Near ([double]$u0.New.Ns) -3.8)) 'meme ecriture relue deux fois : estimation = moyenne des relectures (-5), n = 1 ; o = 3/4 x -5 = -3,75, arrondi au pair -3,8'
foreach ($u in $up) { $script:TargetRecal[$u.Key] = $u.New }
$m2 = New-FkMem -id 'W20261122120000' -at '2026-11-22 12:00:00' -o0 -3 -o1 -2
$rb = New-FkRead @{ 0 = 1.0; 1 = 1.0 } $G
$ev = Get-TargetRecalReadback $m2 $rb 0 ($AT.AddHours(2)) '0' '0'
$up = Get-TargetRecalUpdate 'A' '0' $m2 $ev ($AT.AddHours(2))
$u0 = @($up | Where-Object { $_.Head -eq 0 })[0]
Chk 'C3' ([int]$u0.New.N -eq 2 -and (Near ([double]@($u0.New.Items)[1].Est) -4.0) -and (Near ([double]$u0.New.Ns) -3.9)) 'deuxieme ecriture (recalee -3, ecart +1) : est -4, o = (-5 - 4) / (2 + 1/3) = -3,857, soit -3,9'
$items = @(1..6 | ForEach-Object { @{ WriteId = "W$_"; Date = ''; Est = -1.0 * $_; Tracks = 80; NR = 1; Read = '' } })
$script:TargetRecal['A>0|std_h0'] = @{ Ns = 0; N = 6; Items = $items[0..4]; XDate = $XD; XKey = 'std_h0'; Calc = $script:CalibCalc; At = '' }
$m6 = New-FkMem -id 'W6'
$ev = Get-TargetRecalReadback $m6 (New-FkRead @{ 0 = 6.0; 1 = 6.0 } $G) 0 $AT '0' '0'
$up = Get-TargetRecalUpdate 'A' '0' $m6 $ev $AT
$u0 = @($up | Where-Object { $_.Head -eq 0 })[0]
Chk 'C4' ([int]$u0.New.N -eq 5 -and [string]@($u0.New.Items)[0].WriteId -eq 'W2' -and [string]@($u0.New.Items)[4].WriteId -eq 'W6' -and (Near ([double]$u0.New.Ns) -3.8)) "sixieme ecriture : les cinq dernieres gardees (W2 a W6), o = -20 / (5 + 1/3) = -3,75, arrondi au pair : $($u0.New.Ns)"
$script:TargetRecal['A>0|std_h0'] = @{ Ns = -3; N = 1; Items = @(@{ WriteId = 'W1'; Date = ''; Est = -6.0; Tracks = 80; NR = 1; Read = '' }); XDate = '01/11/2026 10:00'; XKey = 'std_h0'; Calc = $script:CalibCalc; At = '' }
$script:TargetRecal['A>0|std_h1'] = @{ Ns = -3; N = 1; Items = @(@{ WriteId = 'W1'; Date = ''; Est = -6.0; Tracks = 80; NR = 1; Read = '' }); XDate = $XD; XKey = 'std_h1'; Calc = 'autre'; At = '' }
$up = Get-TargetRecalUpdate 'A' '0' $m6 $ev $AT
Chk 'C5' (@($up | Where-Object { $_.Reset -and [int]$_.New.N -eq 1 }).Count -eq 2) 'autre courbe croisee (date) ou autre calcul : remise a zero, n = 1'

# =====================================================================================================================
# A : application
Reset-Fk
$own = @($script:DriveCurves['A|std_h0'], $script:DriveCurves['A|std_h1']); $xc = @($script:DriveCurves['A>0|std_h0'], $script:DriveCurves['A>0|std_h1'])
$tw = @{ Src = 'A'; Tgt = '0'; Fam = 'std'; Own = $own; Curves = $xc; Xfer = $true }
$wf = @{ Apply = $true; F0 = 0.74; F1 = 0.80; FMean = 0.77; Hard = 400; K = @{ 0 = 0.74; 1 = 0.80 }; Src = @{ 0 = 'mesure'; 1 = 'lecteur' }; SrcText = @{ 0 = 'k 0,74'; 1 = 'k 0,80' } }
$td = @{ P0 = $own[0].Spec; P1 = $own[1].Spec; Kind = @{ 0 = 'own'; 1 = 'own' } }
$p0 = Get-TargetTransferPlan $tw $wf $td $true
$d0 = ConvertTo-ScaledSpec $own[0].Spec 0.74 400; $d1 = ConvertTo-ScaledSpec $own[1].Spec 0.80 400
$e0 = Get-TargetTransferSpec $d0 $own[0].Spec $xc[0].Spec 0 400; $e1 = Get-TargetTransferSpec $d1 $own[1].Spec $xc[1].Spec 0 400
Chk 'A1' ([string]$p0.P0 -ceq [string]$e0.Spec -and [string]$p0.P1 -ceq [string]$e1.Spec -and -not ([string]$p0.Line).Contains('recalage') -and -not $p0.Recal.Used) 'sans recalage en memoire : profils de la regle rc7 et journal sans recalage'
$script:TargetRecal['A>0|std_h0'] = @{ Ns = -3.4; N = 1; Items = @(@{ WriteId = 'W1'; Date = '22/11/2026 10:00'; Est = -6.8; Tracks = 80; NR = 1; Read = '2026-11-22 11:00:00' }); XDate = $XD; XKey = 'std_h0'; Calc = $script:CalibCalc; At = '2026-11-22 11:00:00' }
$script:TargetRecal['A>0|std_h1'] = @{ Ns = 2.6; N = 1; Items = @(@{ WriteId = 'W1'; Date = '22/11/2026 10:00'; Est = 5.2; Tracks = 80; NR = 1; Read = '2026-11-22 11:00:00' }); XDate = $XD; XKey = 'std_h1'; Calc = $script:CalibCalc; At = '2026-11-22 11:00:00' }
$p1 = Get-TargetTransferPlan $tw $wf $td $true
$ok = $true
foreach ($pr in @(@($p1.T[0], $e0, $d0, $xc[0].Spec, -3), @($p1.T[1], $e1, $d1, $xc[1].Spec, 3))) {
    for ($c = 0; $c -lt @($pr[1].Values).Count; $c++) {
        $v = [int]$pr[1].Values[$c]; $l = [int][math]::Floor(0.25 * $v); $oc = [math]::Max(-$l, [math]::Min($l, [int]$pr[4]))
        $bd = [math]::Max(400, [math]::Max((Get-FkV ([string]$pr[3]) $c), (Get-FkV ([string]$pr[2]) $c)))
        $want = if ($v -gt 0) { [math]::Max(0, [math]::Min($v + $oc, $bd)) } else { $v }
        if ([int]$pr[0].Values[$c] -ne $want) { $ok = $false }
    }
}
Chk 'A2' ($ok -and $p1.Recal.Used -and ([string]$p1.Line).Contains('recalage du lecteur cible : tête 0 -3,4 ns, tête 1 +2,6 ns (1 relecture(s), dernière le 22/11/2026)') -and [int]$p1.T[0].Recal -eq -3 -and [int]$p1.T[1].Recal -eq 3) "courbe ecrite = regle + arrondi(o) par cylindre (25 %, borne) ; journal : $([string]$p1.Recal.Text)"
$wfd = @{ Apply = $true; F0 = 1.0; F1 = 0.80; FMean = 0.9; Hard = 400; K = @{ 0 = 1.0; 1 = 0.80 }; Src = @{ 0 = 'defaut'; 1 = 'mesure' }; SrcText = @{ 0 = 'k 1'; 1 = 'k 0,80' } }
$pk = Get-TargetTransferPlan $tw $wfd $td $true
Chk 'A3' ((Near ([double]$pk.Recal.O[0]) 0) -and (Near ([double]$pk.Recal.O[1]) 2.6) -and ([string]$pk.Line).Contains('non appliqué : tête 0 : facteur de la disquette non mesuré')) 'facteur de la tete 0 non mesure : recalage de cette tete non applique, dit au journal'
$twF = @{ Src = 'A'; Tgt = '0'; Fam = 'std'; Own = @($script:DriveCurves['A|std_h0']); Curves = @($script:DriveCurves['A>0|std']); Xfer = $true }
$pf = Get-TargetTransferPlan $twF $wf $td $false
$pfd = Get-TargetTransferPlan $twF $wfd $td $false
Chk 'A4' ((Near ([double]$pf.Recal.O[0]) 0) -and ([string]$pf.Line).Contains('recalibrée') -and (Near ([double]$pfd.Recal.O[0]) 0)) 'ecriture rapide (courbe commune d une autre date) : recalage sans effet, dit au journal'
$script:DriveCurves['A>0|std'] = (New-FkCurve 'A' '0' $null '0=59:40=43:70=35' $XD)
$twF.Curves = @($script:DriveCurves['A>0|std'])
$pf = Get-TargetTransferPlan $twF $wf $td $false
$pfd = Get-TargetTransferPlan $twF $wfd $td $false
Chk 'A5' ((Near ([double]$pf.Recal.O[0]) -0.4) -and (Near ([double]$pf.Recal.O[1]) -0.4) -and ([string]$pf.Line).Contains('moyenne des deux têtes') -and (Near ([double]$pfd.Recal.O[0]) 0) -and -not $pfd.Recal.Used) 'ecriture rapide : moyenne des deux tetes (-0,4) ; un facteur non mesure : rien'
$script:Manual = $true
$pm = Get-TargetTransferPlan $tw $wf $td $true
$script:Manual = $false
Chk 'A6' ((Near ([double]$pm.Recal.O[0]) 0) -and (Near ([double]$pm.Recal.O[1]) 0) -and ([string]$pm.Line).Contains('profil Manuel')) 'profil Manuel : aucun recalage'
$script:DriveCurves['A>0|std_h0'] = (New-FkCurve 'A' '0' 0 '0=61:40=45:70=37' '23/11/2026 09:00')
$xc2 = @($script:DriveCurves['A>0|std_h0'], $script:DriveCurves['A>0|std_h1'])
$tw2 = @{ Src = 'A'; Tgt = '0'; Fam = 'std'; Own = $own; Curves = $xc2; Xfer = $true }
$px = Get-TargetTransferPlan $tw2 $wf $td $true
$sx = Get-TargetRecalSummaryText 'A' '0' 'std'
Chk 'X1' ((Near ([double]$px.Recal.O[0]) 0) -and (Near ([double]$px.Recal.O[1]) 2.6) -and ([string]$px.Line).Contains('tête 0 : courbe croisée recalibrée') -and $sx.Contains('Sans effet')) 'nouvelle calibration croisee de la tete 0 : recalage de cette tete sans effet (ecriture, fenetre « Lecteurs »)'
$memx = New-FkMem; $memx.H['0'].XDate = '23/11/2026 09:00'
$ev = Get-TargetRecalReadback $memx (New-FkRead @{ 0 = 2.0; 1 = 2.0 } $G) 0 $AT '0' '0'
$up = Get-TargetRecalUpdate 'A' '0' $memx $ev $AT
$u0 = @($up | Where-Object { $_.Head -eq 0 })[0]
Chk 'X2' ($u0.Reset -and [int]$u0.New.N -eq 1 -and (Near ([double]$u0.New.Ns) -1.5) -and [string]$u0.New.XDate -eq '23/11/2026 09:00') 'relecture d une ecriture faite avec la nouvelle courbe : recalage repart de zero'

# =====================================================================================================================
# O : proposition apres une mesure
Reset-Fk
$script:LastTargetWrites['A>0'] = New-FkMem
$res = @{ Kind = 'measure'; Health = 0; At = $AT; Ctx = @{ Drive = '0'; Heads = '0+1'; Revs = 3 } }
$rb = New-FkRead @{ 0 = 6.0; 1 = 4.0 } $G
$script:ConfirmAns = $true
$o1 = Invoke-TargetRecalOffer $res $rb
$ct = [string]$script:ConfirmArgs.Text
# 12.11 (version finale, rendu de la fenetre) : effet sur la courbe ecrite insecable : espace insecable avant « ns » et « % »,
# signe moins U+2212 des valeurs (O2, O8 adaptes)
$nbO = [string][char]0x00A0; $mnO = [string][char]0x2212
Chk 'O1' ($o1 -eq 'stored' -and $script:ConfirmN -eq 1 -and (Near ([double]$script:TargetRecal['A>0|std_h0'].Ns) -4.5) -and (Near ([double]$script:TargetRecal['A>0|std_h1'].Ns) -3.0) -and $script:Saves -eq 1 -and (@($script:Log) -join ' ').Contains('Courbe croisée A → 0 recalée')) 'confirmee : magasin, journal, configuration enregistree'
Chk 'O2' ([string]$script:ConfirmArgs.Check -eq 'Disquette écrite le 22/11/2026 10:00 pour le lecteur 0' -and $ct.Contains('« essai.adf »') -and $ct.Contains("Tête 0 : 80 pistes retenues, écart médian +6,0 ns (trop de précompensation pour le lecteur cible) ; recalage -4,5 ns, au lieu de aucun ; courbe écrite pour le lecteur 0 : ${mnO}4${nbO}ns par rapport à cette écriture") -and $ct.Contains('g = 1,40')) "fenetre : ecriture (date, image), case de la disquette, recalage par tete (-4,5 ns) et effet sur la courbe ecrite (arrondi au pair : -4 ns)"
Reset-Fk
$script:LastTargetWrites['A>0'] = New-FkMem
$script:ConfirmAns = $false
# Rendu de la rc8 : fenetre en anglais, g des deux tetes separes par « ; » (T(' ; ')), jamais par le « ; » francais
$script:Lang = 'en'
$o2 = Invoke-TargetRecalOffer $res $rb
$script:Lang = 'fr'
$ctEn = [string]$script:ConfirmArgs.Text
Chk 'O3' ($o2 -eq 'declined' -and $script:TargetRecal.Count -eq 0 -and $script:Saves -eq 0 -and $ctEn.Contains('; head 1: g = ') -and -not $ctEn.Contains(' ; ')) "non confirmee : rien n est garde ; fenetre en anglais sans « ; » francais"
$script:ConfirmAns = $true; $script:AlignLoop = $true; $script:QualView = @{ Pass = 1 }
$o3 = Invoke-TargetRecalOffer $res $rb
$script:AlignLoop = $false
Chk 'O4' ($o3 -eq 'loop' -and $script:TargetRecal.Count -eq 0 -and (@($script:Log) -join ' ').Contains('mesure continue')) 'mesure continue : rien d evalue, une ligne'
$script:Log.Clear(); $script:ConfirmN = 0
$rbb = New-FkRead @{ 0 = 6.0; 1 = 4.0 } $G; $rbb['79.1'].Level = 1
$o4 = Invoke-TargetRecalOffer @{ Kind = 'measure'; Health = 1; At = $AT; Ctx = @{ Drive = '0' } } $rbb
Chk 'O5' ($o4 -eq 'refused' -and $script:ConfirmN -eq 0 -and (@($script:Log) -join ' ').Contains('non proposé') -and (@($script:Log) -join ' ').Contains('SUPPORT SAIN')) 'relecture refusee : raison au journal, aucune fenetre'
$script:Log.Clear()
$o5 = Invoke-TargetRecalOffer @{ Kind = 'measure'; Health = 0; At = $AT; Ctx = @{ Drive = 'A' } } $rb
Chk 'O6' ($o5 -eq 'none' -and $script:Log.Count -eq 0 -and $script:ConfirmN -eq 0) 'mesure par un lecteur sans ecriture en memoire pour lui : rien'
$script:Log.Clear()
$o6 = Invoke-TargetRecalOffer $res (New-FkRead @{ 0 = 6.0; 1 = 4.0 } $G 3)
$lt = (@($script:Log) -join ' ')
Chk 'O7' ($o6 -eq 'refused' -and $script:ConfirmN -eq 0 -and $lt.Contains('6 piste(s) relue(s), l''écriture en a écrit 160') -and -not $lt.Contains('il en faut')) 'mesure de quelques cylindres : refus en une raison (pistes), sans le detail par tete'
# Relecture rc8 : effet annonce par la fenetre limite comme l application (25 % de chaque valeur) : courbe 8 et 4 ns,
# recalage -3 : -2 et -1 ns, soit -25 % partout (et non -38 % et -75 %)
$memw = New-FkMem; $memw.H['0'].W = '0=8:20=4:60=0'
$ht = Get-TargetRecalHeadText $memw @{ Med = 6.0; N = 80; O = 0 } @{ Head = 0; Reset = $false; Old = $null; New = @{ Ns = -3.0 } } '0'
$script:Lang = 'en'; $htEn = Get-TargetRecalHeadText $memw @{ Med = 6.0; N = 80; O = 0 } @{ Head = 0; Reset = $false; Old = $null; New = @{ Ns = -3.0 } } '0'; $script:Lang = 'fr'
Chk 'O8' ($ht.Contains("${mnO}3${nbO}ns par rapport à cette écriture (${mnO}25$nbO% à ${mnO}25$nbO% selon le cylindre)") -and $htEn.Contains("${mnO}3${nbO}ns compared with this write (${mnO}25$nbO% to ${mnO}25$nbO% depending on the cylinder)")) "fenetre : effet limite a 25 % de la courbe, valeurs et unites insecables, signe moins U+2212 ($ht | $htEn)"
# Relecture rc8 : la proposition passe le lecteur qui a ecrit : courbe croisee recalibree depuis l ecriture, rien n est propose
$script:LastTargetWrites['A>0'] = New-FkMem; $script:Log.Clear(); $script:ConfirmN = 0
$script:DriveCurves['A>0|std_h0'] = (New-FkCurve 'A' '0' 0 '0=61:40=45:70=37' '23/11/2026 09:00'); $script:DriveCurves['A>0|std_h1'] = (New-FkCurve 'A' '0' 1 '0=59:40=43:70=35' '23/11/2026 09:00')
$o9 = Invoke-TargetRecalOffer $res $rb
Chk 'O9' ($o9 -eq 'refused' -and $script:ConfirmN -eq 0 -and $script:TargetRecal.Count -eq 0 -and (@($script:Log) -join ' ').Contains('recalibrée ou calcul changé depuis cette écriture')) 'courbe croisee recalibree depuis l ecriture : aucune fenetre, raison au journal'
# O10 (12.11, version finale) : lignes de journal de la proposition, listes separees par T(' ; ') comme les voisines : en
# anglais « ; » sans espace avant, jamais le « ; » francais ; en francais, « ; » inchange. Recalage enregistre (deux
# tetes) ; relecture refusee pour les deux tetes (ecart median de 12,5 ns, au-dela de 12)
$rbF = New-FkRead @{ 0 = 12.5; 1 = 12.5 } $G
$o10 = @{}
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    Reset-Fk; $script:LastTargetWrites['A>0'] = New-FkMem; $script:ConfirmAns = $true
    [void](Invoke-TargetRecalOffer $res $rb); $o10["$lg-ok"] = [string]@($script:Log)[-1]
    Reset-Fk; $script:LastTargetWrites['A>0'] = New-FkMem
    [void](Invoke-TargetRecalOffer $res $rbF); $o10["$lg-ref"] = [string]@($script:Log)[-1]
}
$script:Lang = 'fr'; Reset-Fk
$o10ok = ($o10['en-ok'].Contains(': head 0 -4.5 ns; head 1 -3.0 ns; added to the next writes') -and $o10['en-ref'].Contains('12.5 ns, beyond ± 12 ns') -and $o10['en-ref'].Contains('disk factor; head 1: median gap +12.5 ns') -and
          -not ($o10['en-ok'] + $o10['en-ref']).Contains(' ; ') -and $o10['fr-ok'].Contains(' : tête 0 -4,5 ns ; tête 1 -3,0 ns ; ajouté aux prochaines écritures') -and $o10['fr-ref'].Contains('facteur de la disquette ; tête 1 : écart médian +12,5 ns'))
Chk 'O10' $o10ok "anglais : « $($o10['en-ok']) » ; « $($o10['en-ref']) » ; francais : « $($o10['fr-ok']) »"
# O11 (12.11, relecture de la version finale) : controle statique (arbre syntaxique des modules fn) des listes passees a
# T(' ; ') en 12.11, que O10 et R4d (logic-calib-retour) ne prouvent que pour trois des dix-sept : dans chaque fonction de
# la table, autant de T(' ; ') qu attendu (les dix-sept et quatre voisines : 172 deux de la rc8, Get-WriteFactorHint,
# Format-WritePlan) et aucun litteral ' ; ' ecrit en dur ; dans tout module fn, aucune fonction qui melange les deux. Les
# jointures d avant la 12.11 (litteral en dur dans d autres fonctions) ne sont pas concernees
$o11Want = [ordered]@{ 'Test-GwPortRetry' = 1; 'Restore-DriveRescueTargets' = 1; 'Get-TargetTransferPlan' = 3; 'Get-WriteFactorHint' = 1; 'Format-WritePlan' = 1
                       'Get-AsymGainText' = 1; 'Start-WriteZonePass' = 1; 'Invoke-TargetRecalOffer' = 5; 'Get-QualityCardModel' = 1; 'Get-CalibBackInfo' = 4; 'Restore-CalibBack' = 2 }
$o11T = @{}; $o11D = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Where-Object { $_.Name -match '^[1-4]\d\d-fn-' })) {
    foreach ($c in (Get-Ast $f.FullName).FindAll({ param($x) $x -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $x.Value -ceq ' ; ' }, $true)) {
        $q = $c.Parent; $fn = ''
        while ($q) { if ($q -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $fn = $q.Name; break }; $q = $q.Parent }
        $inT = ($c.Parent -is [System.Management.Automation.Language.CommandAst] -and $c.Parent.GetCommandName() -ceq 'T')
        if ($inT) { $o11T[$fn] = 1 + [int]$o11T[$fn] } else { $o11D[$fn] = 1 + [int]$o11D[$fn] }
    }
}
$o11Bad = @(foreach ($k in $o11Want.Keys) { if ([int]$o11T[$k] -ne [int]$o11Want[$k] -or [int]$o11D[$k] -ne 0) { "$k (T $([int]$o11T[$k]) sur $($o11Want[$k]), en dur $([int]$o11D[$k]))" } })
$o11Bad += @(foreach ($k in @($o11T.Keys)) { if ([int]$o11D[$k] -gt 0 -and -not $o11Want.Contains($k)) { "$k (melange : T $($o11T[$k]), en dur $($o11D[$k]))" } })
Chk 'O11' ($o11Bad.Count -eq 0 -and @($o11Want.Values | Measure-Object -Sum).Sum -eq 21) "vingt et une listes (dix-sept de la 12.11, quatre voisines) passees a T(' ; ') dans $($o11Want.Count) fonctions, aucun « ; » en dur a cote ; ecarts : $(if ($o11Bad.Count) { $o11Bad -join ' | ' } else { 'aucun' })"

# =====================================================================================================================
# M : memoire de l ecriture
Reset-Fk
$xp = @{ T = @{ 0 = @{ Spec = '0=50:40=40'; Recal = -3 }; 1 = @{ Spec = '0=48:40=38'; Recal = 2 } } }
$rc = @{ O = @{ 0 = -3.4; 1 = 2.0 }; XDate = @{ 0 = $XD; 1 = $XD }; XKey = @{ 0 = 'std_h0'; 1 = 'std_h1' } }
$wfm = @{ Apply = $true; K = @{ 0 = 0.74; 1 = 1.0 }; Src = @{ 0 = 'mesure'; 1 = 'defaut' }; FMean = 0.87 }
$pm = New-TargetWriteMemory $tw $wfm $xp $rc $true '' 'C:\factice\essai.adf' @(0, 1) $true 0
$ps = New-TargetWriteMemory $tw $wfm $xp $rc $true 'hswap' 'C:\factice\essai.adf' @(0, 1) $true 0
Chk 'M1' ([int]$pm.H['0'].Phys -eq 0 -and [int]$pm.H['0'].O -eq -3 -and [string]$pm.H['0'].W -eq '0=50:40=40' -and $pm.H['0'].KMeasured -and -not $pm.H['1'].KMeasured -and [string]$pm.H['1'].KSrc -eq 'defaut' -and $pm.H['0'].KLearn -eq $true -and $pm.H['1'].KLearn -eq $false -and [int]$ps.H['0'].Phys -eq 1 -and [string]$ps.H['0'].W -eq '0=48:40=38' -and [string]$pm.Image -eq 'essai.adf') 'memoire : tete physique (hswap), courbe ecrite, recalage applique, k, son origine et s il apprend'
$script:TargetWritePending = $pm
$st0 = @{}
for ($c = 0; $c -lt 80; $c++) { foreach ($h in 0, 1) { $m = @{ Bad = $false; Weak = $false; Level = 0; Ooc = 0.0; R3 = 1.502; R4 = 2.002; Cell = 2000; Asym = 0.004; Score = 40; J = 40 }; $m.AsymExp = 0.004; $m.AsymGap = 0.0; $m.AsymDev = 0.0; $m.AsymHead = "$h"; $st0["$c.$h"] = $m } }
$wr = @{}; foreach ($k in $st0.Keys) { $wr[$k] = $true }
$rep = @{ State = $st0; Written = $wr; HeadPrecomp = @{ 0 = '0=50:20=45:30=40'; 1 = '0=48:40=38' }; Zones = @(@{ H = 0; C0 = 20; C1 = 29; State = 'ok' }, @{ H = 1; C0 = 50; C1 = 54; State = 'back' }) }
Complete-TargetWriteMemory $true $rep
$lm = $script:LastTargetWrites['A>0']
Chk 'M2' ($null -eq $script:TargetWritePending -and $lm -and [string]$lm.Verdict -eq 'ok' -and [int]$lm.Tracks -eq 160 -and [string]$lm.H['0'].W -eq '0=50:20=45:30=40' -and (@($lm.H['0'].Zones) -join ',') -eq ((20..29) -join ',') -and (@($lm.H['1'].Zones) -join ',') -eq ((50..54) -join ',') -and $lm.Date -and $lm.At -and -not $lm.ContainsKey('Written') -and $script:Saves -eq 1 -and (@($script:Log) -join ' ').Contains('gardée en mémoire')) 'fin du controle : verdict R10, courbe finale avec zones, cylindres des zones, pistes, date ; enregistree'
$script:TargetWritePending = (New-TargetWriteMemory $tw $wfm $xp $rc $true '' 'C:\factice\essai.adf' @(0, 1) $true 0)
Complete-TargetWriteMemory $false
Chk 'M3' (-not $script:LastTargetWrites.ContainsKey('A>0') -and (@($script:Log) -join ' ').Contains('interrompue')) 'ecriture interrompue : memoire de la paire retiree'
# Sans controle : fin de la derniere commande gw write de l image
$script:TargetWritePending = (New-TargetWriteMemory $tw $wfm $xp $rc $true '' 'C:\factice\essai.adf' @(0, 1) $false 160)
$script:GwLastArgs = @('write', '--precomp', '0=50', '--tracks=h=0', '"C:\factice\essai.adf"')
$script:WriteTracks = @{}; for ($c = 0; $c -lt 80; $c++) { $script:WriteTracks["$c.0"] = $true }
$script:WriteQueue.Enqueue(@('write'))
Update-TargetWriteMemoryGw 0 $false
$mid = ($null -ne $script:TargetWritePending -and -not $script:LastTargetWrites.ContainsKey('A>0'))
[void]$script:WriteQueue.Dequeue()
$script:WriteTracks = @{}; for ($c = 0; $c -lt 80; $c++) { $script:WriteTracks["$c.1"] = $true }
$script:Cal = @{ Mode = 'content' }; Update-TargetWriteMemoryGw 0 $false; $calSkip = ($null -ne $script:TargetWritePending); $script:Cal = $null
$script:GwLastArgs = @('write', '"C:\factice\autre.adf"'); Update-TargetWriteMemoryGw 0 $false; $imgSkip = ($null -ne $script:TargetWritePending)
$script:GwLastArgs = @('write', '--tracks=h=1', '"C:\factice\essai.adf"')
Update-TargetWriteMemoryGw 0 $false
$lm = $script:LastTargetWrites['A>0']
Chk 'M4' ($mid -and $calSkip -and $imgSkip -and $lm -and [int]$lm.Tracks -eq 160 -and [string]$lm.Verdict -eq '') 'sans controle : gardee a la fin de la derniere commande de l image (160 pistes ecrites), pas sur une autre operation'
$script:TargetWritePending = (New-TargetWriteMemory $tw $wfm $xp $rc $true '' 'C:\factice\essai.adf' @(0, 1) $false 160)
$script:GwLastArgs = @('write', '"C:\factice\essai.adf"')
Update-TargetWriteMemoryGw 1 $false
Chk 'M5' ($null -eq $script:TargetWritePending -and -not $script:LastTargetWrites.ContainsKey('A>0')) 'sans controle, erreur de gw : memoire retiree'
# Relecture rc8 : au lancement d une nouvelle ecriture pour la paire A>0, la memoire precedente de cette paire est retiree
# tout de suite (fenetre fermee ou arret brutal pendant l ecriture : elle ne reste pas) ; celle d une autre paire reste
$script:LastTargetWrites['A>0'] = New-FkMem; $script:LastTargetWrites['B>0'] = New-FkMem -id 'W20261121100000'
Set-TargetWritePending (New-TargetWriteMemory $tw $wfm $xp $rc $true '' 'C:\factice\essai.adf' @(0, 1) $true 0)
Chk 'M6' ($null -ne $script:TargetWritePending -and [string]$script:TargetWritePending.Tgt -eq '0' -and -not $script:LastTargetWrites.ContainsKey('A>0') -and $script:LastTargetWrites.ContainsKey('B>0') -and $null -eq (Get-TargetWriteMemoryFor '0').Mem.Src -and [string](Get-TargetWriteMemoryFor '0').Src -eq 'B') 'nouvelle ecriture A>0 lancee : memoire precedente de A>0 retiree, celle de B>0 gardee'
$script:TargetWritePending = $null

# =====================================================================================================================
# D : fenetre « Lecteurs »
Reset-Fk
$script:TargetRecal['A>0|std_h0'] = @{ Ns = -3.7; N = 1; Items = @(@{ WriteId = 'W1'; Date = ''; Est = -7.4; Tracks = 80; NR = 2; Read = '2026-11-22 11:00:00' }); XDate = $XD; XKey = 'std_h0'; Calc = $script:CalibCalc; At = '2026-11-22 11:00:00' }
$script:TargetRecal['A>0|std_h1'] = @{ Ns = -2.3; N = 1; Items = @(@{ WriteId = 'W1'; Date = ''; Est = -4.6; Tracks = 80; NR = 2; Read = '2026-11-22 11:00:00' }); XDate = $XD; XKey = 'std_h1'; Calc = $script:CalibCalc; At = '2026-11-22 11:00:00' }
$sm = Get-TargetRecalSummaryText 'A' '0' 'std'
# Rendu de la rc8 : valeur de chaque tete insecable (espaces insecables entre la tete, la valeur et l unite, signe moins
# U+2212 au lieu du trait d union, apres lequel le texte se coupait), en anglais aussi
$nbD = [string][char]0x00A0; $mnD = [string][char]0x2212
$script:Lang = 'en'; $smEn = Get-TargetRecalSummaryText 'A' '0' 'std'; $script:Lang = 'fr'
Chk 'D1' ($sm -ceq ('Recalage de la courbe croisée A → 0 (Standard 2 us) : ' + 'tête 0 -3,7 ns'.Replace(' ', $nbD).Replace('-', $mnD) + ', ' + 'tête 1 -2,3 ns'.Replace(' ', $nbD).Replace('-', $mnD) + ' ; 2 relecture(s), dernière le 22/11/2026.') -and
          $smEn.Contains('head 0 -3.7 ns'.Replace(' ', $nbD).Replace('-', $mnD) + ', ' + 'head 1 -2.3 ns'.Replace(' ', $nbD).Replace('-', $mnD) + '; 2 read-back(s)')) "texte : $sm ; anglais : $smEn"
$lvC = New-Object System.Windows.Forms.ListView; [void]$lvC.Items.Add('Standard 2 us'); [void]$lvC.Items.Add('Standard 2 us'); $lvC.Items[1].Selected = $true
$s = @{ Curves = $lvC; CRows = @(@{ Group = 'own'; StoreDrive = 'A'; Family = 'std' }, @{ Group = 'out'; Other = '0'; StoreDrive = 'A>0'; Family = 'std' }); Info = (New-Object System.Windows.Forms.Label); Recal = (New-Object System.Windows.Forms.Button); State = (New-Object System.Windows.Forms.Label); InfoBase = 'Lecteur cible de ses écritures : 0.' }
Update-DrivesDialogRecal $s
$d2 = ($s.Recal.Enabled -and ([string]$s.Info.Text).EndsWith($sm) -and ([string]$s.Info.Text).StartsWith('Lecteur cible'))
$lvC.Items[1].Selected = $false; $lvC.Items[0].Selected = $true; Update-DrivesDialogRecal $s
Chk 'D2' ($d2 -and -not $s.Recal.Enabled -and [string]$s.Info.Text -eq 'Lecteur cible de ses écritures : 0.') 'courbe croisee choisie : texte du recalage et bouton actif ; courbe propre : bouton inactif'
$lvC.Items[0].Selected = $false; $lvC.Items[1].Selected = $true
$script:ProtectOk = $false
$g1 = Undo-TargetRecalGesture $s
$keep = ($script:TargetRecal.Count -eq 2 -and -not $g1.Ok -and $g1.Error)
$script:ProtectOk = $true
$g2 = Undo-TargetRecalGesture $s
Chk 'D3' ($keep -and $g2.Ok -and $script:TargetRecal.Count -eq 0 -and $script:ProtectN -eq 2 -and $script:Saves -eq 1 -and -not $s.Recal.Enabled -and ([string]$s.State.Text).Contains('annulé : 2 tête(s)') -and ([string]$script:ConfirmArgs.Heading).Contains('Annuler le recalage')) 'Annuler le recalage : confirmation, copie de la configuration d abord (echec : rien), recalages retires, enregistre'

# =====================================================================================================================
# E : « Effacer les calibrations »
Reset-Fk
$script:TargetRecal['A>0|std_h0'] = @{ Ns = -3.7; N = 1; Items = @(@{ WriteId = 'W1'; Est = -7.4; NR = 1 }); XDate = $XD; Calc = $script:CalibCalc; At = '' }
$script:LastTargetWrites['A>0'] = New-FkMem
$script:PrecompStd = '0=140'; $script:PrecompStdDefault = '0=140'; $script:PrecompLong = '0=140'; $script:PrecompLongDefault = '0=140'
function Get-CalibResetAfterText { return 'ensuite' }
Reset-CalibProfiles
Chk 'E1' ($script:TargetRecal.Count -eq 0 -and $script:LastTargetWrites.Count -eq 0 -and $script:MsgText.Contains('Les recalages des courbes croisées (1) et la mémoire des dernières écritures pour un lecteur cible (1) sont effacés aussi.') -and (@($script:Log) -join ' ').Contains('Recalages des courbes croisées (1)')) 'Effacer les calibrations : recalages et memoire des ecritures effaces, message et journal'

# =====================================================================================================================
# J : configuration
Reset-Fk
$script:TargetRecal['A>0|std_h0'] = @{ Ns = -3.0; N = 2; Items = @(@{ WriteId = 'W1'; Date = '21/11/2026 10:00'; Est = -5.0; Tracks = 79; NR = 2; Read = '2026-11-21 11:00:00' }, @{ WriteId = 'W2'; Date = '22/11/2026 10:00'; Est = -4.0; Tracks = 80; NR = 1; Read = '2026-11-22 11:00:00' }); XDate = $XD; XKey = 'std_h0'; Calc = $script:CalibCalc; At = '2026-11-22 11:00:00' }
$script:TargetRecal['A>0|std_h1'] = @{ Ns = -1.0; N = 1; Items = @(@{ WriteId = 'W2'; Date = '22/11/2026 10:00'; Est = -2.0; Tracks = 80; NR = 1; Read = '2026-11-22 11:00:00' }); XDate = $XD; XKey = 'std_h1'; Calc = $script:CalibCalc; At = '2026-11-22 11:00:00' }
$mj = New-FkMem -o0 -3; $mj.H['0'].Zones = [int[]]@(20..29)
$script:LastTargetWrites['A>0'] = $mj
$cfg = @{ write = @{ targetRecal = (Export-TargetRecal); lastTargetWrite = (Export-LastTargetWrites) } }
$js = $cfg | ConvertTo-Json -Depth 8
$o = $js | ConvertFrom-Json
$i1 = Import-TargetRecal $o.write.targetRecal
$i2 = Import-LastTargetWrites $o.write.lastTargetWrite
$e0 = $script:TargetRecal['A>0|std_h0']; $e1 = $script:TargetRecal['A>0|std_h1']; $lj = $script:LastTargetWrites['A>0']
# ns enregistre (-3,0 et -1,0, regle de la rc8) jamais repris : recalcule au chargement par la regle courante (-9 / (2 + 1/3)
# = -3,857 -> -3,9 ; -2 x 3/4 = -1,5) ; une entree enregistree par la rc8 la suit donc des le demarrage suivant
Chk 'J1' ([int]$i1.N -eq 2 -and [int]$i1.Bad -eq 0 -and (Near ([double]$e0.Ns) -3.9) -and [int]$e0.N -eq 2 -and [int]@($e0.Items)[0].NR -eq 2 -and [string]@($e0.Items)[1].WriteId -eq 'W2' -and [string]$e0.XDate -eq $XD -and [string]$e0.XKey -eq 'std_h0' -and (Near ([double]$e1.Ns) -1.5) -and @($e1.Items).Count -eq 1) 'recalages relus (une ou deux ecritures), ns recalcule par la regle courante'
Chk 'J2' ([int]$i2.N -eq 1 -and $lj -and [string]$lj.Id -eq $mj.Id -and [int]$lj.H['0'].O -eq -3 -and (@($lj.H['0'].Zones) -join ',') -eq ((20..29) -join ',') -and $lj.H['0'].KMeasured -and [string]$lj.H['1'].W -eq $mj.H['1'].W -and (@($lj.Heads) -join ',') -eq '0,1' -and [int]$lj.Tracks -eq 160 -and [string]$lj.Verdict -eq 'ok') 'memoire de l ecriture relue a l identique'
$bad = ('{ "a": { "x": 1 }, "A>0|std_h0": { "xDate": "12/11/2026 15:20", "items": [] }, "A>0|std_h1": { "xDate": "12/11/2026 15:20", "items": [ { "writeId": "W1", "est": -4 } ] } }' | ConvertFrom-Json)
$i3 = Import-TargetRecal $bad
Chk 'J3' ([int]$i3.N -eq 1 -and [int]$i3.Bad -eq 2 -and (Near ([double]$script:TargetRecal['A>0|std_h1'].Ns) -3.0)) 'entrees illisibles ignorees et comptees ; o recalcule sur les estimations (-4 x 3/4)'

# =====================================================================================================================
# K : lecteur renomme ou retire
Reset-Fk
$script:TargetRecal['A>0|std_h0'] = @{ Ns = -3.0; N = 1; Items = @(@{ WriteId = 'W1'; Est = -6.0; NR = 1 }); XDate = $XD; Calc = $script:CalibCalc; At = '' }
$script:LastTargetWrites['A>0'] = New-FkMem
# Relecture rc8 : entrees d une autre paire (B>C), qui doivent rester telles quelles a chaque geste
$bc = @{ Ns = -1.0; N = 1; Items = @(@{ WriteId = 'W9'; Est = -2.0; NR = 1 }); XDate = $XD; Calc = $script:CalibCalc; At = '' }; $bm = New-FkMem -id 'W20261120100000'
$script:TargetRecal['B>C|std_h1'] = $bc; $script:LastTargetWrites['B>C'] = $bm
$k1 = Edit-DriveData '0' 'Cible'
$kOk = ($k1.Ok -and $script:TargetRecal.ContainsKey('A>Cible|std_h0') -and -not $script:TargetRecal.ContainsKey('A>0|std_h0') -and $script:LastTargetWrites.ContainsKey('A>Cible') -and $null -ne (Get-TargetWriteMemoryFor 'Cible'))
$k3 = Edit-DriveData 'A' 'Ecrit'
$kSrc = ($k3.Ok -and $script:TargetRecal.ContainsKey('Ecrit>Cible|std_h0') -and $script:LastTargetWrites.ContainsKey('Ecrit>Cible') -and [string](Get-TargetWriteMemoryFor 'Cible').Src -eq 'Ecrit')
$k2 = Edit-DriveData 'Cible' ''
$kBc = ([object]::ReferenceEquals($script:TargetRecal['B>C|std_h1'], $bc) -and [object]::ReferenceEquals($script:LastTargetWrites['B>C'], $bm))
Chk 'K1' ($kOk -and $kSrc -and $k2.Ok -and $kBc -and $script:TargetRecal.Count -eq 1 -and $script:LastTargetWrites.Count -eq 1) 'lecteur cible puis lecteur qui ecrit renommes : recalage et memoire les suivent ; cible retiree : ils sont retires ; ceux d une autre paire restent'

# =====================================================================================================================
# L : version finale, seul un facteur mesure sur la disquette elle-meme apprend le recalage
Reset-Fk
$wM = @{ Apply = $true; K = @{ 0 = 0.74; 1 = 0.80 }; Src = @{ 0 = 'mesure'; 1 = 'mesure' }; FMean = 0.77 }
$wL = @{ Apply = $true; K = @{ 0 = 0.74; 1 = 0.80 }; Src = @{ 0 = 'lecteur'; 1 = 'lecteur' }; FMean = 0.77 }
$wD = @{ Apply = $true; K = @{ 0 = 1.0; 1 = 1.0 }; Src = @{ 0 = 'defaut'; 1 = 'defaut' }; FMean = 1.0 }
$wX = @{ Apply = $true; K = @{ 0 = 0.74; 1 = 0.80 }; Src = @{ 0 = 'mesure'; 1 = 'lecteur' }; FMean = 0.77 }
$wS = @{ Apply = $true; K = @{ '0' = 0.74; '1' = 0.80 }; Src = @{ '0' = 'mesure'; '1' = 'mesure' }; FMean = 0.77 }
$wN = @{ Apply = $false; K = @{ 0 = 0.74; 1 = 0.80 }; Src = @{ 0 = 'mesure'; 1 = 'mesure' }; FMean = 0.77 }
$lrn = @(foreach ($c in @(@($wM, 0, $true), @($wM, 1, $true), @($wS, 1, $true), @($wX, 0, $true), @($wM, 0, $false))) { Test-TargetRecalKLearn $c[0] $c[1] $c[2] })
$nol = @(foreach ($c in @(@($wL, 0, $true), @($wX, 1, $true), @($wD, 0, $true), @($wN, 0, $true), @($wX, 0, $false), @($wL, 1, $false), @($null, 0, $true))) { Test-TargetRecalKLearn $c[0] $c[1] $c[2] })
$app = @(foreach ($c in @(@($wL, 0, $true), @($wX, 1, $true), @($wX, 0, $false), @($wL, 1, $false))) { Test-TargetRecalKMeasured $c[0] $c[1] $c[2] })
Chk 'L1' ((@($lrn | Where-Object { $_ -ne $true }).Count -eq 0) -and (@($nol | Where-Object { $_ -ne $false }).Count -eq 0) -and (@($app | Where-Object { $_ -ne $true }).Count -eq 0) -and -not (Test-TargetRecalKMeasured $wD 0 $true)) "apprend : 'mesure' (cles nombre ou texte ; rapide : les deux tetes) ; n apprend pas : 'lecteur', 'defaut', facteur non applique, rapide mele ; 'lecteur' et rapide mele s appliquent toujours ($(($lrn + $nol + $app) -join ','))"
# Application inchangee : une ecriture avec le facteur de la marque recoit le recalage, une ecriture a k = 1 non
$twL = @{ Src = 'A'; Tgt = '0'; Fam = 'std' }
$xcL = @($script:DriveCurves['A>0|std_h0'], $script:DriveCurves['A>0|std_h1'])
$script:TargetRecal['A>0|std_h0'] = @{ Ns = -3.4; N = 1; Items = @(@{ WriteId = 'W1'; Date = '22/11/2026 10:00'; Est = -4.5; Tracks = 80; NR = 1; Read = '2026-11-22 11:00:00' }); XDate = $XD; XKey = 'std_h0'; Calc = $script:CalibCalc; At = '2026-11-22 11:00:00' }
$script:TargetRecal['A>0|std_h1'] = @{ Ns = 2.6; N = 1; Items = @(@{ WriteId = 'W1'; Date = '22/11/2026 10:00'; Est = 3.5; Tracks = 80; NR = 1; Read = '2026-11-22 11:00:00' }); XDate = $XD; XKey = 'std_h1'; Calc = $script:CalibCalc; At = '2026-11-22 11:00:00' }
$pLr = Get-TargetRecalPlan $twL $wL $xcL $true
$pDf = Get-TargetRecalPlan $twL $wD $xcL $true
$pLf = Get-TargetRecalPlan @{ Src = 'A'; Tgt = '0'; Fam = 'std' } $wX $xcL $false
Chk 'L2' ($pLr.Used -and (Near ([double]$pLr.O[0]) -3.4) -and (Near ([double]$pLr.O[1]) 2.6) -and -not ([string]$pLr.Text).Contains('non appliqué') -and -not $pDf.Used -and (Near ([double]$pDf.O[0]) 0) -and ([string]$pDf.Text).Contains('k = 1 par défaut') -and $pLf.Used -and (Near ([double]$pLf.O[0]) -0.4)) "facteur de la marque : recalage applique ($([string]$pLr.Text)) ; k = 1 : non ; rapide mele : applique (moyenne -0,4)"
$script:TargetRecal = @{}
# Memoires faites par le code reel (New-TargetWriteMemory, Complete-TargetWriteMemory sans controle, 160 pistes du plan),
# date posee ensuite sur une valeur fictive anterieure a la relecture
$xpL = @{ T = @{ 0 = @{ Spec = '0=50:40=40'; Recal = 0 }; 1 = @{ Spec = '0=48:40=38'; Recal = 0 } } }
$rcL = @{ O = @{ 0 = 0.0; 1 = 0.0 }; XDate = @{ 0 = $XD; 1 = $XD }; XKey = @{ 0 = 'std_h0'; 1 = 'std_h1' } }
function New-FkDone($wf, [bool]$slow) {
    $script:LastTargetWrites = @{}; $script:Log.Clear(); $script:Saves = 0
    $script:TargetWritePending = (New-TargetWriteMemory $twL $wf $xpL $rcL $slow '' 'C:\factice\essai.adf' @(0, 1) $false 160)
    Complete-TargetWriteMemory $true
    $m = $script:LastTargetWrites['A>0']
    if ($m) { $m.At = '2026-11-22 10:00:00'; $m.Date = '22/11/2026 10:00' }
    return $m
}
$resL = @{ Kind = 'measure'; Health = 0; At = $AT; Ctx = @{ Drive = '0'; Heads = '0+1'; Revs = 3 } }
$rbL = New-FkRead @{ 0 = 6.0; 1 = 4.0 } $G
$howS = "cochez « Mesurer la disquette avant l'écriture lente », avec la mesure « sur l'image à écrire »"
$howF = "écrivez l'image en écriture lente, avec « Mesurer la disquette avant l'écriture lente » cochée et la mesure « sur l'image à écrire »"
# L3 : ecriture lente, tete 0 mesuree sur la disquette, tete 1 de la marque : la tete 0 seule apprend
$mX = New-FkDone $wX $true
$lX = (@($script:Log) -join ' ')
$evX = Get-TargetRecalReadback $mX $rbL 0 $AT '0' '0' 'A'
$script:Log.Clear(); $script:ConfirmN = 0; $script:ConfirmAns = $true
$oX = Invoke-TargetRecalOffer $resL $rbL
$lXo = (@($script:Log) -join ' ')
Chk 'L3' ($mX -and $mX.H['0'].KLearn -eq $true -and $mX.H['1'].KLearn -eq $false -and $mX.H['1'].KMeasured -eq $true -and [string]$mX.H['1'].KSrc -ceq 'lecteur' -and $lX.Contains('gardée en mémoire') -and $lX.Contains("La tête 1 ne servira pas à ce recalage : son facteur n'a pas été mesuré sur la disquette elle-même.") -and $evX.Ok -and $evX.Heads['0'].Ok -and -not $evX.Heads['1'].Ok -and (@($evX.Heads['1'].Why) -join ' ') -ceq 'tête 1 : facteur de la disquette repris des mesures du lecteur pour la marque, pas mesuré sur cette disquette' -and $oX -eq 'stored' -and $script:TargetRecal.ContainsKey('A>0|std_h0') -and -not $script:TargetRecal.ContainsKey('A>0|std_h1') -and $lXo.Contains('repris des mesures du lecteur') -and -not $lXo.Contains('ne peut pas recaler') -and -not ([string]$script:ConfirmArgs.Text).Contains('ne peut pas recaler') -and ([string]$script:ConfirmArgs.Text).Contains('pas mesuré sur cette disquette')) "tete 0 mesuree, tete 1 de la marque : seule la tete 0 apprend ; la ligne de fin d ecriture et le journal de la relecture le disent ; raison de la tete exclue sans conclusion contraire a la fenetre qui recale l autre"
# L4 : ecriture lente avec le facteur de la marque sur les deux tetes : rien a apprendre ; ligne de fin d ecriture sans
# promesse, avec la consigne ; memoire gardee : la relecture est refusee avec sa raison, sans fenetre
$script:TargetRecal = @{}
$mL = New-FkDone $wL $true
$lL = (@($script:Log) -join ' ')
$script:Log.Clear(); $script:ConfirmN = 0
$oL = Invoke-TargetRecalOffer $resL $rbL
$lLo = (@($script:Log) -join ' ')
Chk 'L4' ($mL -and $script:Saves -eq 1 -and $lL.StartsWith('Écriture pour le lecteur cible 0 terminée (') -and $lL.Contains("elle ne pourra pas recaler la courbe croisée A → 0, car son facteur n'a pas été mesuré sur la disquette elle-même. Pour qu'une écriture recale cette courbe, $howS.") -and -not $lL.Contains('pourra recaler la courbe croisée A → 0.') -and -not $lL.Contains('gardée en mémoire') -and $oL -eq 'refused' -and $script:ConfirmN -eq 0 -and $script:TargetRecal.Count -eq 0 -and $lLo.Contains("Recalage de la courbe croisée A → 0 sur cette relecture non proposé : l'écriture du $($mL.Date) ne peut pas recaler la courbe croisée (tête 0 : facteur de la disquette repris des mesures du lecteur pour la marque, pas mesuré sur cette disquette ; tête 1 : facteur de la disquette repris") -and -not $lLo.Contains('aucune écriture') -and -not $mL.ContainsKey('How')) "facteur de la marque : « $lL » ; relecture : « $lLo »"
# L5 : ecriture rapide aux origines melees : facteur moyen, aucune tete n apprend ; rapide aux deux tetes mesurees : apprend
$mF = New-FkDone $wX $false
$lF = (@($script:Log) -join ' ')
$evF = Get-TargetRecalReadback $mF $rbL 0 $AT '0' '0' 'A'
$mFm = New-FkDone $wM $false
$evFm = Get-TargetRecalReadback $mFm $rbL 0 $AT '0' '0' 'A'
Chk 'L5' ($mF.H['0'].KLearn -eq $false -and $mF.H['1'].KLearn -eq $false -and $mF.H['0'].KMeasured -eq $true -and $lF.Contains("Pour qu'une écriture recale cette courbe, $howF.") -and -not $evF.Ok -and (@($evF.Heads['0'].Why) -join ' ').Contains("tête 0 : écriture rapide avec le facteur moyen des deux têtes, dont une n'a pas été mesurée sur cette disquette") -and (@($evF.Heads['1'].Why) -join ' ').Contains('repris des mesures du lecteur') -and $mFm.H['0'].KLearn -eq $true -and $evFm.Ok -and $evFm.Heads['0'].Ok -and $evFm.Heads['1'].Ok) 'ecriture rapide melee : aucune tete n apprend (raison par tete) ; rapide aux deux tetes mesurees : les deux apprennent'
# L6 : k = 1 par defaut : ni applique ni appris
$mD = New-FkDone $wD $true
$lD = (@($script:Log) -join ' ')
$evD = Get-TargetRecalReadback $mD $rbL 0 $AT '0' '0' 'A'
Chk 'L6' ($mD.H['0'].KLearn -eq $false -and $mD.H['0'].KMeasured -eq $false -and $lD.Contains('elle ne pourra pas recaler') -and -not $evD.Ok -and (@($evD.Heads['0'].Why) -join ' ').Contains("tête 0 : facteur de la disquette non mesuré à l'écriture (k = 1 par défaut)")) 'k = 1 : ligne de fin d ecriture sans promesse, relecture refusee (k = 1 par defaut)'
# L7 : origine du facteur absente (memoire sans kSrc, relue de la configuration) : tete qui n apprend pas, raison claire
$js7 = '{ "A>0": { "id": "W20261122100000", "date": "22/11/2026 10:00", "at": "2026-11-22 10:00:00", "image": "essai.adf", "fam": "std", "slow": true, "tracks": 160, "heads": [0, 1], "verdict": "ok", "calc": "' + $script:CalibCalc + '",' +
       ' "h": { "0": { "phys": 0, "w": "0=40:40=32:70=24", "o": 0, "xDate": "' + $XD + '", "xKey": "std_h0", "k": 0.74, "kMeasured": true }, "1": { "phys": 1, "w": "0=38:40=30:70=22", "o": 0, "xDate": "' + $XD + '", "xKey": "std_h1", "k": 0.74, "kSrc": "autre", "kMeasured": true } } } }'
$i7 = Import-LastTargetWrites ($js7 | ConvertFrom-Json)
$m7 = $script:LastTargetWrites['A>0']
$ev7 = Get-TargetRecalReadback $m7 $rbL 0 $AT '0' '0' 'A'
$memE = New-FkMem; $memE.H['0'].KSrc = ''
Chk 'L7' ([int]$i7.N -eq 1 -and $null -eq $m7.H['0'].KLearn -and -not $ev7.Ok -and (@($ev7.Heads['0'].Why) -join ' ').Contains('tête 0 : origine du facteur de la disquette inconnue') -and (@($ev7.Heads['1'].Why) -join ' ').Contains('tête 1 : origine du facteur de la disquette inconnue') -and (Get-TargetWriteKLearnWhy $memE '0').Contains('inconnue') -and (Get-TargetWriteKLearnWhy $null '0').Contains('inconnue')) 'kSrc absent ou inconnu : la tete n apprend pas, « origine inconnue »'
# L8 : memoires de la rc8 (KSrc, KMeasured, sans KLearn) : lente 'mesure' apprend ; rapide aux deux tetes 'mesure' apprend ;
# rapide a une seule tete ecrite (origine de l autre inconnue) ou a l autre tete 'lecteur' : non. Configuration : KLearn
# null garde tel quel (un faux ecrit a sa place priverait la memoire de la rc8 de l apprentissage), vrai et faux relus
$r8s = New-FkMem
$r8f = New-FkMem; $r8f.Slow = $false
$r8o = New-FkMem; $r8o.Slow = $false; $r8o.H.Remove('1'); $r8o.Heads = [int[]]@(0)
$r8m = New-FkMem; $r8m.Slow = $false; $r8m.H['1'].KSrc = 'lecteur'
$okR8 = ((Get-TargetWriteKLearnWhy $r8s '0') -eq '' -and (Get-TargetWriteKLearnWhy $r8f '1') -eq '' -and (Get-TargetWriteKLearnWhy $r8o '0').Contains('inconnue') -and (Get-TargetWriteKLearnWhy $r8m '0').Contains('écriture rapide'))
$script:LastTargetWrites = @{ 'A>0' = (New-FkMem); 'B>0' = $mX }
$o8 = (@{ write = @{ lastTargetWrite = (Export-LastTargetWrites) } } | ConvertTo-Json -Depth 8) | ConvertFrom-Json
$i8 = Import-LastTargetWrites $o8.write.lastTargetWrite
$a8 = $script:LastTargetWrites['A>0']; $b8 = $script:LastTargetWrites['B>0']
Chk 'L8' ($okR8 -and [int]$i8.N -eq 2 -and $null -eq $a8.H['0'].KLearn -and (Get-TargetWriteKLearnWhy $a8 '0') -eq '' -and $b8.H['0'].KLearn -eq $true -and $b8.H['1'].KLearn -eq $false -and (Get-TargetWriteKLearnWhy $b8 '0') -eq '' -and (Get-TargetWriteKLearnWhy $b8 '1').Contains('repris des mesures')) 'memoires de la rc8 : lente et rapide mesurees apprennent, rapide a une tete ou melee non ; configuration : KLearn null, vrai et faux relus'
# L9 : textes anglais (cles T() identiques a la table, controle I1 de check-source pour toutes les cles)
$keys9 = @('tête {0} : facteur de la disquette repris des mesures du lecteur pour la marque, pas mesuré sur cette disquette',
           'tête {0} : origine du facteur de la disquette inconnue',
           "tête {0} : écriture rapide avec le facteur moyen des deux têtes, dont une n'a pas été mesurée sur cette disquette",
           "Écriture pour le lecteur cible {0} terminée ({1}, {2} piste(s)) : elle ne pourra pas recaler la courbe croisée {3} → {0}, car son facteur n'a pas été mesuré sur la disquette elle-même.",
           "Pour qu'une écriture recale cette courbe, {0}.",
           "La mesure sur l'image faite avant cette écriture n'a pas déterminé ce facteur (voir ses lignes dans le journal) : une écriture recalera cette courbe quand cette mesure le déterminera.",
           "mesurez la disquette au lieu de choisir « Écrire sans mesure »", "choisissez la mesure « sur l'image à écrire »",
           "choisissez le test standard ou fin dans « Calibration précomp », avec « Mesurer la disquette avant l'écriture lente » cochée et la mesure « sur l'image à écrire »",
           "écrivez l'image en écriture lente, avec le test standard ou fin dans « Calibration précomp », « Mesurer la disquette avant l'écriture lente » cochée et la mesure « sur l'image à écrire »",
           "La tête {0} ne servira pas à ce recalage : son facteur n'a pas été mesuré sur la disquette elle-même.",
           "Recalage de la courbe croisée {0} → {1} sur cette relecture non proposé : l'écriture du {2} ne peut pas recaler la courbe croisée ({3}).")
$script:Lang = 'en'
$mLe = New-FkDone $wL $true
$lLe = (@($script:Log) -join ' ')
$wLe = Get-TargetWriteKLearnWhy $mLe '0'
$script:Log.Clear(); $script:ConfirmN = 0
$oLe = Invoke-TargetRecalOffer $resL $rbL
$lLeo = (@($script:Log) -join ' ')
$wLme = $wL.Clone(); $wLme.Next = 'mesure'
[void](New-FkDone $wLme $true)
$lMe = (@($script:Log) -join ' ')
$script:Lang = 'fr'
Chk 'L9' (@($keys9 | Where-Object { -not $script:I18n.ContainsKey($_) }).Count -eq 0 -and $lLe.Contains('cannot be used to adjust the cross curve A → 0, because its factor was not measured on the disk itself. For a write to adjust this curve, check "Measure the disk before the slow write"') -and $wLe -ceq "head 0: disk factor taken from the drive's measurements for the brand, not measured on this disk" -and $oLe -eq 'refused' -and $lLeo.Contains('Cross curve adjustment A → 0 on this read-back not offered: the write of ') -and $lLeo.Contains("cannot adjust the cross curve (head 0: disk factor taken from the drive's measurements for the brand, not measured on this disk; head 1: ") -and -not $lLeo.Contains(' ; ') -and $lMe.Contains('The measurement on the image made before this write did not determine this factor (see its lines in the log)')) "anglais : « $lLe » ; « $wLe » ; « $lLeo »"
# L10 : memoire de la rc8 (sans KLearn) d une ecriture lente faite avec le facteur de la marque (kSrc 'lecteur', kMeasured
# vrai : ce que la rc8 ecrivait) : aucune tete n apprend, directement et apres un aller-retour par la configuration ;
# relecture complete : refusee, aucune fenetre, rien d enregistre. Echoue si 'lecteur' redevient appris pour une memoire
# sans KLearn
Reset-Fk
$r8l = New-FkMem; $r8l.H['0'].KSrc = 'lecteur'; $r8l.H['1'].KSrc = 'lecteur'
$w10 = @((Get-TargetWriteKLearnWhy $r8l '0'), (Get-TargetWriteKLearnWhy $r8l '1'))
$script:LastTargetWrites = @{ 'A>0' = $r8l }
$o10c = (@{ write = @{ lastTargetWrite = (Export-LastTargetWrites) } } | ConvertTo-Json -Depth 8) | ConvertFrom-Json
$i10 = Import-LastTargetWrites $o10c.write.lastTargetWrite
$r8c = $script:LastTargetWrites['A>0']
$w10c = @((Get-TargetWriteKLearnWhy $r8c '0'), (Get-TargetWriteKLearnWhy $r8c '1'))
$ev10 = Get-TargetRecalReadback $r8c $rbL 0 $AT '0' '0' 'A'
$script:Log.Clear(); $script:ConfirmN = 0; $script:ConfirmAns = $true
$o10 = Invoke-TargetRecalOffer $resL $rbL
Chk 'L10' (@($w10 + $w10c | Where-Object { -not ([string]$_).Contains('repris des mesures du lecteur pour la marque') }).Count -eq 0 -and [int]$i10.N -eq 1 -and $null -eq $r8c.H['0'].KLearn -and $r8c.H['0'].KMeasured -eq $true -and -not $ev10.Ok -and -not $ev10.Heads['0'].Ok -and -not $ev10.Heads['1'].Ok -and $o10 -eq 'refused' -and $script:ConfirmN -eq 0 -and $script:TargetRecal.Count -eq 0 -and $script:Saves -eq 0) "memoire de la rc8, ecriture lente avec le facteur de la marque : refusee directement et apres la configuration ($($w10c -join ' | '))"
# L11 : ecriture qui ne peut rien apprendre (facteur de la marque) : une relecture partielle (10 cylindres) donne cette
# raison, jamais « mesurez les memes cylindres » ; mesure continue : cette raison a la premiere passe, rien ensuite.
# Ecriture dont une tete apprend : relecture partielle refusee par sa couverture, comme avant (O7)
Reset-Fk
[void](New-FkDone $wL $true)
$rb10 = New-FkRead @{ 0 = 6.0; 1 = 4.0 } $G 10
$script:Log.Clear(); $script:ConfirmN = 0
$oP = Invoke-TargetRecalOffer $resL $rb10
$lP = (@($script:Log) -join ' ')
$script:Log.Clear(); $script:AlignLoop = $true; $script:QualView = @{ Pass = 1 }
$oQ1 = Invoke-TargetRecalOffer $resL $rb10
$lQ1 = (@($script:Log) -join ' ')
$script:Log.Clear(); $script:QualView = @{ Pass = 2 }
$oQ2 = Invoke-TargetRecalOffer $resL $rb10
$nQ2 = $script:Log.Count
$script:AlignLoop = $false; $script:QualView = @{ Pass = 0 }
[void](New-FkDone $wX $true)
$script:Log.Clear()
$oPx = Invoke-TargetRecalOffer $resL $rb10
$lPx = (@($script:Log) -join ' ')
Chk 'L11' ($oP -eq 'refused' -and $script:ConfirmN -eq 0 -and $lP.Contains('ne peut pas recaler la courbe croisée (tête 0 : facteur de la disquette repris des mesures du lecteur pour la marque, pas mesuré sur cette disquette ; tête 1 : ') -and -not $lP.Contains('mesurez les mêmes cylindres') -and -not $lP.Contains('piste(s) relue(s)') -and $oQ1 -eq 'loop' -and $lQ1.Contains('ne peut pas recaler la courbe croisée (tête 0 : ') -and -not $lQ1.Contains('Faites une mesure simple') -and $oQ2 -eq 'loop' -and $nQ2 -eq 0 -and $oPx -eq 'refused' -and $lPx.Contains('mesurez les mêmes cylindres')) "relecture partielle : « $lP » ; mesure continue : « $lQ1 » ; une tete apprend : « $lPx »"
# L12 : consigne de la ligne de fin d une ecriture qui ne peut rien apprendre (facteur de la marque sur les deux tetes),
# decidee au lancement d apres l onglet. Mesure sur l image faite avant l ecriture sans determiner le facteur (Next
# 'mesure', origines 'lecteur') : elle le dit, sans demander de cocher la case ; « Ecrire sans mesure » ; « Test rapide »
# (case cochee et verrouillee ; lente, rapide) ; case cochee avec la mesure complete ; case cochee, mesure sur l image, sans
# mesure faite : aucune consigne ; image non mesurable sur son contenu (lente, rapide), image qui ne recouvre pas le motif,
# restauration, facteur non applique : aucune consigne. Lente case decochee et rapide : L4 et L5
Reset-Fk
$howM = "La mesure sur l'image faite avant cette écriture n'a pas déterminé ce facteur (voir ses lignes dans le journal) : une écriture recalera cette courbe quand cette mesure le déterminera."
$pfx = "Pour qu'une écriture recale cette courbe, "
$base = "elle ne pourra pas recaler la courbe croisée A → 0, car son facteur n'a pas été mesuré sur la disquette elle-même."
function Get-FkEndLine($wf, [bool]$slow) { [void](New-FkDone $wf $slow); return (@($script:Log) -join ' ') }
$wLs = $wL.Clone(); $wLs.Next = 'sans'
$e1 = Get-FkEndLine $wLme $true
$e2 = Get-FkEndLine $wLs $true
$cmbWCalMode.SelectedIndex = 2; $chkWLevel.Checked = $true
$e3 = Get-FkEndLine $wL $true; $e4 = Get-FkEndLine $wL $false
$cmbWCalMode.SelectedIndex = 1
$script:Settings['levelBeforeWriteMode'] = 'complete'; $e5 = Get-FkEndLine $wL $true
$script:Settings['levelBeforeWriteMode'] = 'content'; $e6 = Get-FkEndLine $wL $true
$chkWLevel.Checked = $false
$script:FkMeasurable = $false; $e7 = Get-FkEndLine $wL $true; $e7f = Get-FkEndLine $wL $false; $script:FkMeasurable = $true
$script:FkSkip = @{ Why = 'une face' }; $e8 = Get-FkEndLine $wL $true; $script:FkSkip = $null
$script:Restore = @{ Step = 4 }; $e9 = Get-FkEndLine $wL $true; $script:Restore = $null
$wLn = $wL.Clone(); $wLn.Apply = $false
$hN = Get-TargetWriteLearnHow $wLn $true 'C:\factice\essai.adf'
$none = @($e6, $e7, $e7f, $e8, $e9)
$okN = (@($none | Where-Object { -not $_.Contains($base) -or $_.Contains($pfx) -or $_.Contains($howM) }).Count -eq 0)
Chk 'L12' (@($e1, $e2, $e3, $e4, $e5 | Where-Object { -not $_.Contains($base) -or $_.Contains('cochez') }).Count -eq 0 -and $e1.Contains($howM) -and -not $e1.Contains($pfx) -and $e2.Contains($pfx + 'mesurez la disquette au lieu de choisir « Écrire sans mesure ».') -and $e3.Contains($pfx + "choisissez le test standard ou fin dans « Calibration précomp », avec « Mesurer la disquette avant l'écriture lente » cochée et la mesure « sur l'image à écrire ».") -and $e4.Contains($pfx + "écrivez l'image en écriture lente, avec le test standard ou fin dans « Calibration précomp », « Mesurer la disquette avant l'écriture lente » cochée et la mesure « sur l'image à écrire ».") -and $e5.Contains($pfx + "choisissez la mesure « sur l'image à écrire ».") -and $okN -and $hN -eq '') "mesure faite avant : « $e1 » ; Test rapide : « $e3 » ; mesure complete : « $e5 »"
# L13 : hswap, tete physique 0 mesuree sur la disquette, tete physique 1 de la marque : la tete logique 0, ecrite par la tete
# physique 1, n apprend pas ; la ligne de fin d ecriture nomme la tete physique 1, comme les lignes du facteur de l ecriture
$script:LastTargetWrites = @{}; $script:Log.Clear()
$script:TargetWritePending = (New-TargetWriteMemory $twL $wX $xpL $rcL $true 'hswap' 'C:\factice\essai.adf' @(0, 1) $false 160)
Complete-TargetWriteMemory $true
$mH = $script:LastTargetWrites['A>0']; $lH = (@($script:Log) -join ' ')
Chk 'L13' ($mH -and [int]$mH.H['0'].Phys -eq 1 -and $mH.H['0'].KLearn -eq $false -and $mH.H['1'].KLearn -eq $true -and $lH.Contains('gardée en mémoire') -and $lH.Contains('La tête 1 ne servira pas à ce recalage') -and -not $lH.Contains('La tête 0 ne servira pas')) "hswap : « $lH »"
# L14 (12.11, version finale) : ce que peut demander le conseil des zones qui couvrent presque toute une tete
# (Get-TargetZoneAdvice) : origine du facteur par tete logique relue (hswap ; ecriture rapide : 'mesure' seulement si les
# deux tetes le sont), consigne de Get-TargetWriteLearnHow ; gestes de Get-TargetWriteHowPhrase (memes textes que la ligne
# de fin d ecriture)
$img14 = 'C:\factice\essai.adf'
$wF0 = $wL.Clone(); $wF0.Src = @{ 0 = 'defaut'; 1 = 'defaut' }
$a1 = Get-TargetZoneAdvice $wX $true '' $img14; $a2 = Get-TargetZoneAdvice $wX $true 'hswap' $img14
$a3 = Get-TargetZoneAdvice $wX $false '' $img14; $a4 = Get-TargetZoneAdvice $wM $false '' $img14; $a5 = Get-TargetZoneAdvice $wF0 $false '' $img14
$a6 = Get-TargetZoneAdvice $wLme $true '' $img14
$script:Restore = @{ Step = 4 }; $a7 = Get-TargetZoneAdvice $wL $true '' $img14; $script:Restore = $null
$ks14 = @($a1, $a2, $a3, $a4, $a5 | ForEach-Object { "$($_.KSrc[0])/$($_.KSrc[1])" }) -join ' '
$hw14 = @($a1, $a3, $a6, $a7 | ForEach-Object { [string]$_.How }) -join ' '
$ph14 = @('sans', 'slow', 'fast', 'mode', 'quickslow', 'quickfast' | ForEach-Object { $x = Get-TargetWriteHowPhrase $_; [bool]$x -and (Get-TargetWriteLearnHowText $_) -ceq ($pfx + $x + '.') })
$ph14 += @((Get-TargetWriteHowPhrase 'mesure') -ceq '', (Get-TargetWriteHowPhrase '') -ceq '', (Get-TargetWriteHowPhrase 'autre') -ceq '')
Chk 'L14' ($ks14 -ceq 'mesure/lecteur lecteur/mesure lecteur/lecteur mesure/mesure defaut/defaut' -and $hw14 -ceq 'slow fast mesure ' -and @($ph14 | Where-Object { -not $_ }).Count -eq 0) "origines par tete logique : $ks14 (lente, hswap, rapide mixte, rapide mesuree, rapide k = 1) ; consignes : « $hw14 » (lente case decochee, rapide, mesure faite avant, restauration) ; gestes communs a la ligne de fin d ecriture"

# =====================================================================================================================
"=== bilan logic-cible-recalage : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$(if ($script:Fail) { " ; NON CONFORMES : $($script:FailIds -join ', ')" }) ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail -gt 0) { exit 1 }
exit 0
