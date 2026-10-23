$script:IndexDir       = Join-Path $env:LOCALAPPDATA 'GreaseweazleGUI'
$script:LibIndexing    = $false
$script:LibSearchAt    = $null
$script:LibPendingSearch = $false
# 12.8 (lot 4a) : liste groupee des resultats, panneau de details, travail differe (bloc INFO des IPF, jeux incomplets)
$script:LibListMode    = $false            # recherche saisie : liste des resultats ; sinon arborescence
$script:LibAll         = $null             # chemins relatifs retenus par la regle des mots, avant filtres et plafond
$script:LibCand        = $null             # candidats de l index ou de la recherche de repli (Rel, Size, Kind)
$script:LibRoot        = ''; $script:LibRootLeaf = ''
$script:LibCounts      = $null             # Total, Capped, Shown, Hidden de la derniere liste
$script:LibRecCache    = @{}               # fiches analysees, par chemin relatif
$script:LibIpfCache    = @{}               # bloc INFO lu, par chemin et taille
$script:LibSetCache    = @{}               # disquettes manquantes, par jeu (SetId)
$script:LibGroups      = @{}               # groupes de la liste, par cle de titre
$script:LibSort        = @{ Col = -1; Desc = $false }
$script:LibColTitles   = @()
$script:LibColW        = @(); $script:LibColAuto = @{}   # FIX4B : largeurs de depart des colonnes, largeurs elargies par le tri
$script:LibWork        = New-Object System.Collections.Queue
$script:LibWorkDone    = 0; $script:LibWorkTotal = 0
$script:LibCur         = $null; $script:LibSub = $null; $script:LibSubRecs = @(); $script:LibInfoBase = ''
$script:LibRendering   = $false; $script:LibOrigPending = $false; $script:LibThumbPath = ''
$script:LibSearchFilter = ''; $script:LibSearchInDirs = $false
$script:LibIndexHits   = 0; $script:LibFilterMs = 0; $script:LibParseMs = 0; $script:LibRenderMs = 0; $script:LibTimes = $null
$script:LibRx          = $null; $script:LibCountryLang = @{}
# 12.8 (lot 4b, D19) : liste de reference (DAT) choisie par l utilisateur, identification des fichiers
$script:LibDat         = $null             # liste lue (Read-LibDat) : chemin, en-tete, index par taille et par nom ; Ok ou Error
$script:LibDatState    = @{}               # etat d identification (ok, mod, unk), par chemin et taille (Get-LibIpfKey), avec la date lue
$script:LibDatZip      = @{}               # archives ZIP identifiees (repertoire central), par chemin, taille et date
$script:LibDatLine     = ''                # lignes « Liste de reference » du panneau de details (remplacees a la fin du calcul)
$script:LibHashCache   = $null; $script:LibHashFileCur = ''   # empreintes calculees (hash-<md5>.tsv de la racine)
$script:LibZipEnc      = $null
$script:LibDatRecheck  = $false            # FIX4B : etats identifies par lecture a revalider apres une nouvelle recherche
$script:LibDatRx       = $null             # FIX4B : expressions du format clrmamepro (Get-LibDatRx)
$script:ProgTotal      = 0
$script:ProgSeen       = $null
$script:ProgOp         = ''
$script:ConfirmDlg     = $null   # 12.8 (D3) : bouton principal de la fenetre frmConfirm ouverte (Set-ConfirmGo)
# 12.8 (S3) : reponse de la derniere fenetre frmConfirm ('go', 'alt' : second bouton, 'close'), texte de sa liste de marque
$script:ConfirmChoice  = ''
$script:ConfirmComboText = $null

# Chaine d etapes (convert -> read -> compare, ou read -> analyse d alignement) executee par le timer
$script:Chain = New-Object System.Collections.Generic.Queue[scriptblock]
$script:AlignLoop   = $false
$script:AlignNextAt = $null
$script:QualPauseBar = $false    # 12.8 (lot 5, D20) : barre de boutons dans l etat « pause d une mesure continue » (Set-Busy)
$script:AlignBest   = @{}
$script:AlignPrev   = $null
$script:AlignTmp    = $null
$script:AlignLast   = $null     # derniere mesure : cle 'cyl.tete' -> @{Score;Jitter;Asym;Err;Stab;Cell}
$script:GwIsWrite   = $false    # le gw en cours est un 'write' : on capture les retries de verification
$script:GwSoft      = $false    # le gw en cours est une lecture de prechauffage : code retour et piste manquante sans effet
$script:GwLastCode  = 0         # code retour du dernier gw termine (prechauffage)
$script:GwLastIncomplete = $false   # dernier gw termine avec le code 0 mais incomplet (prechauffage)
$script:GwDriveKey  = $null     # lecteur du gw en cours s il peut faire tourner le moteur (DriveActivity, mise a jour par le
                                # minuteur a la fin de la commande, seulement si le moteur a tourne)
$script:WriteRetries = @{}      # pistes ayant necessite des retries a l ecriture : 'cyl.tete' -> nb max de retries
$script:WriteTracks  = @{}      # pistes annoncees « Writing Track » par la derniere ecriture gw : 'cyl.tete' -> $true
$script:WriteQueue   = New-Object System.Collections.Queue   # ecriture lente : commandes gw write restantes (une par tete)
$script:AlPos       = $null     # guide : position courante du stepper en crans declares (0 = repere)
$script:AlLastMove  = 0         # guide : dernier deplacement declare (+1 / -1 / 0)
$script:AlPosScores = @{}       # guide : position -> meilleur score moyen mesure a cette position
$script:AlignRef    = $null     # reference memorisee (meme structure)
# 12.8 (lot 3) : etat unique de l affichage de l onglet Qualite (Set-QualityPending, Set-QualityResult, Set-QualityStale,
# Reset-QualityView ; module 195) : empty | run | result | stale ; contenu de la carte calcule (QualCard) ; ressources GDI+
# en cache (pinceaux, stylos, polices, formats, pictogrammes), liberees a la fermeture ; icones d etat de l onglet Ecriture
# (verdict du controle apres ecriture) et du verdict de la restauration
$script:QualView = @{ State = 'empty'; Kind = ''; Reason = ''; At = $null; Has = $false; Pass = 0; Drive = ''; Heads = ''; Revs = 0; NCyl = 0; RunText = ''; Res = $null }
$script:QualCard = $null
$script:QualGdi = @{}
$script:WCalIcon = $null
$script:WTabNotice = $null      # 12.8 (FIX-PISTES) : avis de fin d une operation de la Bibliotheque (Set-WTabNotice)
$script:RsResultIcon = $null

# Profils de precompensation (mesures le 06/10/2026, lecteur A600 en ecriture, relecture A600)
$script:PrecompStd  = '0=70:40=100:65=140'          # cellule 2 us : AmigaDOS, ADF, formats IBM/Atari
$script:PrecompLong = '0=85:20=110:40=120:65=140'   # cellule ~1,89 us : long tracks (formats proprietaires)
$script:PrecompStdDefault  = $script:PrecompStd     # profils d origine, retablis par « Effacer les calibrations »
$script:PrecompLongDefault = $script:PrecompLong
$script:PrecompHdDefault = '0=70:40=100:65=140'   # 12.7 : profil d origine haute densite (hd), celui de la 12.6 pour un ADF ou un IMG HD (H)
$script:PrecompThresholdNs = 1950                   # cellule < seuil -> profil long track
# 12.8 (point 7) : seuils du prereglage Standard, constante unique : reglage par defaut, jugement d un original et
# garde-fou du controle apres ecriture (toujours Standard, quel que soit le reglage)
$script:JitterStdOk = 120
$script:JitterStdWatch = 250
$script:JitterOk = $script:JitterStdOk              # jitter (ns) sous lequel une piste peut etre SAINE (reglage de l Accueil)
$script:JitterWatch = $script:JitterStdWatch        # jitter (ns) sous lequel une piste est au plus A SURVEILLER, CRITIQUE au-dela
$script:AlignRefLabel = ''

# --- Reglages a source unique (12.8, point 7) ----------------------------------
# Un reglage modifiable depuis plusieurs interfaces, ou enregistre dans la configuration, est defini ici une seule fois :
# section et cle JSON, type, defaut, bornes ; enum : codes independants de la langue, dans l ordre des elements des
# listes liees (Json 'index' : enregistre par son rang, l entier de la 12.7). LegacyKey et Legacy : cle et anciens textes
# traduits relus (configuration 12.7 enregistree en francais ou en anglais) ; Text : le texte de la langue de
# l interface est encore ecrit sous LegacyKey, pour qu une 12.7 relise la configuration. Var : valeur gardee dans la
# variable du script que lit le code (Get-Setting, Set-SettingStore). Lecture, enregistrement, defauts, liaisons et
# propagation : 120-fn-configuration (Import-Settings, Export-Settings, Reset-Settings, Register-SettingCtl, Set-Setting).
$script:SettingDefs = [ordered]@{
    drive              = @{ Sec = 'global';  Key = 'drive';              Type = 'enum';   Def = 'A';      Codes = @('A', 'B', '0', '1', '2', '3') }
    calMode            = @{ Sec = 'write';   Key = 'calMode';            Type = 'enum';   Def = 'std';    Codes = @('std', 'fine', 'level'); Json = 'index' }
    slowWrite          = @{ Sec = 'write';   Key = 'slowWrite';          Type = 'bool';   Def = $false }
    warmSlowWrite      = @{ Sec = 'write';   Key = 'slowWarmup';         Type = 'bool';   Def = $true }
    warmFullCalib      = @{ Sec = 'write';   Key = 'calibWarmup';        Type = 'bool';   Def = $true }
    warmMinutes        = @{ Sec = 'write';   Key = 'calWarmupMinutes';   Type = 'double'; Def = 5.0;      Min = 0.0; Max = 30.0; Var = 'CalWarmupMinutes' }
    levelBeforeWrite   = @{ Sec = 'write';   Key = 'levelBeforeWrite';   Type = 'bool';   Def = $true }
    # 12.8 (S3, decision du 21/10/2026) : mesure de la disquette avant une ecriture lente : calibration rapide ('quick') ou
    # mesure complete de cette disquette ('complete', reference du lecteur inchangee) ; liste cmbWLevelMode de l onglet
    # Ecriture, dans l ordre de ses elements
    levelBeforeWriteMode = @{ Sec = 'write'; Key = 'levelBeforeWriteMode'; Type = 'enum'; Def = 'quick'; Codes = @('quick', 'complete') }
    precompProfile     = @{ Sec = 'write';   Key = 'precompProfileCode'; Type = 'enum';   Def = 'auto';   Codes = @('auto', 'std', 'long', 'manual'); LegacyKey = 'precompProfile'; Text = $true
                            Legacy = @{ 'Auto (selon image)' = 'auto'; 'Auto (from image)' = 'auto'; 'Standard 2 us' = 'std'; 'Long track 1,89 us' = 'long'; 'Long track 1.89 us' = 'long'; 'Manuel' = 'manual'; 'Manual' = 'manual' } }
    precompThresholdNs = @{ Sec = 'write';   Key = 'precompThresholdNs'; Type = 'int';    Def = $script:PrecompThresholdNs; Min = 0; Max = 100000; Var = 'PrecompThresholdNs' }
    homeCalHeads       = @{ Sec = 'ui';      Key = 'homeCalHeads';       Type = 'bool';   Def = $true }
    homeCalCyls        = @{ Sec = 'ui';      Key = 'homeCalCyls';        Type = 'int';    Def = 0;        Min = 0; Max = 84 }
    alignPreset        = @{ Sec = 'align';   Key = 'presetCode';         Type = 'enum';   Def = 'std';    Codes = @('quick', 'std', 'full', 'custom'); LegacyKey = 'preset'; Text = $true
                            Legacy = @{ 'Rapide (5 cylindres)' = 'quick'; 'Quick (5 cylinders)' = 'quick'; 'Standard (0-70 pas 10)' = 'std'; 'Standard (0-70 by 10)' = 'std'; 'Complet (0-79)' = 'full'; 'Full (0-79)' = 'full'; 'Personnalisé' = 'custom'; 'Custom' = 'custom' } }
    jitterOk           = @{ Sec = 'quality'; Key = 'jitterOk';           Type = 'int';    Def = $script:JitterStdOk;    Min = 30; Max = 300; Var = 'JitterOk' }
    jitterWatch        = @{ Sec = 'quality'; Key = 'jitterWatch';        Type = 'int';    Def = $script:JitterStdWatch; Min = 40; Max = 600; Var = 'JitterWatch' }
    cleanPasses        = @{ Sec = 'tools';   Key = 'passes';             Type = 'int';    Def = 3;        Min = 1; Max = 20 }
    cleanLinger        = @{ Sec = 'tools';   Key = 'linger';             Type = 'int';    Def = 500;      Min = 0; Max = 5000 }
    # 12.8 (lot 2, D13) : format de la restauration, dans l ordre de la liste cmbRsFmt : detection automatique, copie
    # exacte du flux, puis les formats. Cle neuve : restore.format (12.7) n est pas relu, son defaut amiga.amigados n etant
    # pas un choix de l utilisateur
    restoreFormat      = @{ Sec = 'restore'; Key = 'formatChoice';       Type = 'enum';   Def = 'auto'
                            Codes = @('auto', 'flux', 'amiga.amigados', 'amiga.amigados_hd', 'atarist.720', 'atarist.800', 'atarist.880', 'ibm.360', 'ibm.720', 'ibm.1440') }
}
$script:Settings    = @{}                                                   # cle -> valeur (reglages sans variable propre)
$script:SettingCtl  = @{}                                                   # cle -> controles d onglet lies (Register-SettingCtl)
$script:SettingOf   = New-Object 'System.Collections.Generic.Dictionary[object,string]'   # controle lie -> cle
$script:SettingSync = $false                                                # garde de reentrance des liaisons
$script:OpOverride  = $null                                                 # 12.8 (D4) : surcharge d une operation (Enter-OpOverride)

$Formats = @('(auto)','amiga.amigados','amiga.amigados_hd','atarist.720','atarist.800','atarist.880',
             'ibm.360','ibm.720','ibm.1440','ibm.scan','commodore.1541','mac.800','raw.250','raw.500')

# Formats de gw 1.23 (src\greaseweazle\data\diskdefs*.cfg du tag v1.23, 141 definitions) pour la carte « Calibrer le
# lecteur » de l Accueil et les regles d ecriture (Get-FormatCalibInfo) : nom, cylindres, faces, codage, debit en kbit/s
# (0 : debit par defaut de gw, 250 kbit/s pour ces geometries ; raw.* : 500 / cellule en us), tr/min (300 si absent).
# Codages : mfm ; fm ; fm0 (piste 0 en FM, les autres en MFM) ; amiga ; c64, a2, mac (GCR) ; m2fm (dec.rx02, hp.mmfm) ;
# dg (datageneral) ; hard (secteurs durs : micropolis, northstar) ; scan (ibm.scan) ; bit (raw.*).
$script:GwFormatTable = @'
acorn.adfs.160 40 1 mfm 250 300; acorn.adfs.320 80 1 mfm 250 300; acorn.adfs.640 80 2 mfm 250 300; acorn.adfs.800 80 2 mfm 250 300; acorn.adfs.1600 80 2 mfm 500 300; acorn.dfs.ss 40 1 fm 125 300; acorn.dfs.ss80 80 1 fm 125 300; acorn.dfs.ds 40 2 fm 125 300; acorn.dfs.ds80 80 2 fm 125 300
akai.800 80 2 mfm 250 300; akai.1600 80 2 mfm 500 300
amiga.amigados 80 2 amiga 0 300; amiga.amigados_hd 80 2 amiga 0 300
apple2.nofs.140 35 1 a2 0 300; apple2.appledos.140 35 1 a2 0 300; apple2.prodos.140 35 1 a2 0 300
atari.90 40 1 fm 130 300; atari.130 40 1 mfm 260 300
atarist.360 80 1 mfm 250 300; atarist.400 80 1 mfm 250 300; atarist.440 80 1 mfm 261 300; atarist.720 80 2 mfm 250 300; atarist.800 80 2 mfm 250 300; atarist.880 80 2 mfm 261 300
coco.decb 35 1 mfm 250 300; coco.decb.40t 40 1 mfm 250 300; coco.os9.40ss 40 1 mfm 250 300; coco.os9.40ds 40 2 mfm 250 300; coco.os9.80ss 80 1 mfm 250 300; coco.os9.80ds 80 2 mfm 250 300
commodore.1541 40 1 c64 0 300; commodore.1571 35 2 c64 0 300; commodore.1581 80 2 mfm 250 300; commodore.cmd.fd2000.dd 81 2 mfm 250 300; commodore.cmd.fd2000.hd 81 2 mfm 500 300; commodore.cmd.fd4000.ed 81 2 mfm 1000 300
datageneral.2f 77 1 dg 0 300
dec.rx01 77 1 fm 250 360; dec.rx02 77 1 m2fm 250 360
dragon.40ss 40 1 mfm 0 300; dragon.40ds 40 2 mfm 0 300; dragon.80ss 80 1 mfm 0 300; dragon.80ds 80 2 mfm 0 300
eagle.ssqd.400 80 1 mfm 250 300; eagle.dsqd.800 80 2 mfm 250 300
ensoniq.800 80 2 mfm 250 300; ensoniq.1600 80 2 mfm 500 300; ensoniq.mirage 80 1 mfm 250 300
epson.qx10.logo 40 2 mfm 250 300; epson.qx10.booter 15 1 mfm 250 300; epson.qx10.400 40 2 mfm 250 300; epson.qx10.399 40 2 mfm 250 300; epson.qx10.396 40 2 mfm 250 300; epson.qx10.320 40 2 mfm 250 300
gem.1600 80 2 mfm 500 300
hp.mmfm.9885 67 1 m2fm 0 300; hp.mmfm.9895 77 2 m2fm 0 300
ibm.160 40 1 mfm 250 300; ibm.180 40 1 mfm 250 300; ibm.320 40 2 mfm 250 300; ibm.360 40 2 mfm 250 300; ibm.720 80 2 mfm 250 300; ibm.800 80 2 mfm 250 300; ibm.1200 80 2 mfm 500 360; ibm.1440 80 2 mfm 500 300; ibm.1680 80 2 mfm 500 300; ibm.dmf 80 2 mfm 500 300; ibm.2880 80 2 mfm 1000 300; ibm.scan 80 2 scan 0 300
kaypro.ssdd.40 40 1 mfm 250 300; kaypro.dsdd.40 40 2 mfm 250 300; kaypro.dsdd.80 80 2 mfm 250 300
luxor.80 40 1 fm 250 300; luxor.160 40 1 mfm 250 300; luxor.320 40 2 mfm 250 300; luxor.640 80 2 mfm 250 300; luxor.1000.data 77 2 mfm 500 360; luxor.1000.program 77 2 fm0 500 360; luxor.1000.abcnet 77 1 fm0 500 360
mac.400 80 1 mac 0 300; mac.800 80 2 mac 0 300
micropolis.48tpi.ss 35 1 hard 0 300; micropolis.48tpi.ds 35 2 hard 0 300; micropolis.48tpi.ss.275 35 1 hard 0 300; micropolis.48tpi.ds.275 35 2 hard 0 300; micropolis.100tpi.ss 77 1 hard 0 300; micropolis.100tpi.ds 77 2 hard 0 300; micropolis.100tpi.ss.275 77 1 hard 0 300; micropolis.100tpi.ds.275 77 2 hard 0 300
mm1.os9.80dshd_32 80 2 mfm 500 300; mm1.os9.80dshd_33 80 2 mfm 500 300; mm1.os9.80dshd_36 80 2 mfm 500 300; mm1.os9.80dshd_37 80 2 mfm 500 300
msx.1d 40 1 mfm 250 300; msx.1dd 80 1 mfm 250 300; msx.2d 40 2 mfm 250 300; msx.2dd 80 2 mfm 250 300
northstar.fm.ss 35 1 hard 0 300; northstar.fm.ds 35 2 hard 0 300; northstar.mfm.ss 35 1 hard 0 300; northstar.mfm.ds 35 2 hard 0 300
occ1.sd 40 1 fm 125 300; occ1.dd 40 1 mfm 250 300
olivetti.m20 35 2 fm0 250 300
pc98.2d 40 2 mfm 250 300; pc98.2dd 77 2 mfm 250 360; pc98.2hd 77 2 mfm 500 360; pc98.n88basic.hd 77 2 fm0 500 360; pc98.2hs 81 2 mfm 500 300
raw.125 81 2 bit 125 300; raw.250 81 2 bit 250 300; raw.500 81 2 bit 500 300
sci.prophet 80 2 mfm 250 300
sega.sf7000 40 1 mfm 250 300
thomson.1s80 40 1 fm 250 300; thomson.1s160 40 1 fm 250 300; thomson.2s160 40 2 fm 250 300; thomson.1s320 80 1 mfm 250 300; thomson.2s320 80 2 mfm 250 300
tsc.flex.dsdd 80 2 fm0 0 300; tsc.flex.ssdd 80 1 fm0 0 300
xerox.860.ss 77 1 fm 250 360; xerox.860.dssd 77 2 fm 250 360
zx.trdos.ds80 80 2 mfm 0 300; zx.quorum.ds80 80 2 mfm 0 300; zx.d80.ds80 80 2 mfm 0 300; zx.fdd3000.ss40 40 1 mfm 250 300; zx.fdd3000.ds80 80 2 mfm 250 300; zx.kempston.ss40 40 1 mfm 250 300; zx.kempston.ds80 80 2 mfm 250 300; zx.plusd.ds80 80 2 mfm 0 300; zx.opus.ss40 40 1 mfm 250 300; zx.opus.ds80 80 2 mfm 250 300; zx.3dos.ss40 40 1 mfm 250 300; zx.3dos.ds80 80 2 mfm 250 300; zx.rocky.ss40 40 1 mfm 250 300; zx.rocky.ds80 80 2 mfm 250 300; zx.turbodrive.ds40 40 2 mfm 250 300; zx.turbodrive.ds80 80 2 mfm 250 300; zx.watford.ss40 40 1 mfm 250 300; zx.watford.ds80 80 2 mfm 250 300
'@
$script:GwFormats = [ordered]@{}
foreach ($fe in ($script:GwFormatTable -split '[;\r\n]+')) {
    $fp = @($fe.Trim() -split '\s+')
    if ($fp.Count -eq 6) { $script:GwFormats[$fp[0]] = @{ Cyls = [int]$fp[1]; Heads = [int]$fp[2]; Enc = $fp[3]; Rate = [int]$fp[4]; Rpm = [int]$fp[5] } }
}
# 12.8 (lot 2, D13) : format de la comparaison, liste cmbCmpFmt : detection automatique, puis les formats de la liste
# ($Formats), dans son ordre ; codes suivants : les autres formats de gw, saisis dans la liste modifiable (Update-CmpFmtFound
# les affiche). Cle neuve : compare.format (12.7) n est pas relu, son defaut amiga.amigados n etant pas un choix
$script:SettingDefs['compareFormat'] = @{ Sec = 'compare'; Key = 'formatChoice'; Type = 'enum'; Def = 'auto'
    Codes = @(@('auto') + @($Formats | Where-Object { $_ -ne '(auto)' }) + @($script:GwFormats.Keys | Where-Object { $Formats -notcontains $_ })) }
# 12.8 (lot 4b, D19) : liste de reference (DAT) de la Bibliotheque, fichier choisi par l utilisateur ; vide : aucune
$script:SettingDefs['libDat'] = @{ Sec = 'library'; Key = 'dat'; Type = 'string'; Def = '' }
$script:FmtDetect     = $null    # 12.8 (lot 2) : detection du format en cours (Invoke-DiskFormatDetect) : proprietaire, flux, lignes de gw
$script:FmtDetectArgs = @()      # arguments de la commande gw de l etape de detection en cours
$script:CmpAuto       = $null    # 12.8 (lot 2) : comparaison en detection automatique : reference, candidats, sonde de la disquette
$script:CmpRefCyls    = 0        # cylindres de la reference au-dela du format (ADF de 81 a 83 cylindres), non compares (FIX2), 0 sinon
$script:HomeCalApp  = @('app.long', 'app.flux', 'app.free')   # types d image de la carte sans format gw (Get-HomeCalibInfo)
$script:HomeCalFmt  = 'amiga.amigados'   # dernier type choisi dans la carte (configuration ui.homeCalFormat)
$script:HomeCalBusy = $false             # calibration lancee depuis l Accueil : progression affichee sur la carte
$script:HomeCalDesc = ''                 # texte d origine de la carte
$script:HcDlg       = $null              # etat de la fenetre de la carte (gestionnaires d evenements)
# 12.7 : zone de progression de l Accueil (Update-HomeProgress). HomeProgDone : bilan d une calibration lancee depuis
# l Accueil (Set-HomeProgDone) ; HomeProgHold : fenetre de decision ouverte (derniere progression gardee) ; HomeProgUi :
# etat affiche, compare avant toute modification d un controle
$script:HomeProgDone = $null
$script:HomeProgHold = $false
$script:HomeProgUi   = @{ Mode = 'none'; Shown = $false; Links = ''; RawTitle = $null; Src = $null; Bar = $null; TitleW = 756 }

