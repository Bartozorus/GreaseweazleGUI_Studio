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
$script:GwIsErase   = $false    # 12.8.2 : le gw en cours est un 'erase' (pistes effacees, « Command Failed » avec le code 0)
$script:GwCmdFailed = $false    # 12.8.2 : « Command Failed » d un gw erase en cours (Get-GwEndRule)
$script:EraseLog    = $null     # 12.8.2 : pistes effacees et ecrites de l operation en cours (Start-ImageWrite, 170)
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
# 12.8.2 (decision du 27/10/2026) : erreurs par tour (hors classe) au plus pour l etat SAIN de Get-HealthLevel, partout ou
# il juge : onglet Qualite, controle apres ecriture et son garde-fou, source SCP de l ecriture, original en restauration,
# detection du format ; couleur de la colonne Erreurs (Get-AlLevel). 3 jusqu en 12.8.1 : le raccord d ecriture et le
# premier intervalle de la lecture, qui valaient environ 1 erreur par tour, ne comptent plus (S10, S11) ; 2 garde a peu
# pres la sensibilite de la 12.8.1 aux defauts des donnees. Une piste de la source au-dela n est pas reecrite par le
# controle de la copie (Test-SrcOverErr). Ni la calibration, ni le controle de surface, ni les courbes n utilisent
# Get-HealthLevel (CalSurfOocFloor, 560 : borne CRITIQUE de 20, inchangee).
$script:HealthErrOk = 2
$script:AlignRefLabel = ''
# 12.8.2 (S11) : zone de l index (Read-ScpFile, Set-ScpTrackPost). gw ecrit les images ADF et a secteurs d index a index
# (« Terminate at index ») : la jonction d ecriture tombe sur l index, dans l espace entre le dernier et le premier
# secteur (sources gw 1.23 : AmigaDOS DD, 2 048 cellules de vide apres l index, 4,0 ms, et 3 552 avant, 7,0 ms ; ibm.360
# et ibm.720, IAM a 2,94 ms et premier IDAM a 5,1 ms, dernier secteur fini 8,5 ms avant l index, 3,0 ms pour ibm.800 ;
# atarist.720 a 880, sans IAM, premier sync a 2,8 ms au moins, dernier secteur fini 3,1 ms au moins avant l index ; IPF
# Speedball 2 : premier sync a 4,7 ms). Relue par un autre lecteur, elle se decale de la position de son capteur d index
# (TEAC : 0,2 a 0,64 ms apres l index ; Sony qui a ecrit : jusqu a 28 us apres, 6 us avant ; essais du 27/10/2026). 1,0 ms
# de part et d autre couvre ce decalage et reste a 1,8 ms au moins des secteurs (1,1 ms avec le decalage du TEAC). Hors
# de cette hypothese (verification du 27/10/2026) : les formats gw a petit gap apres l index (coco.* et dragon.*, synchro
# a 1,4 ms ; ensoniq.mirage, IAM a 1,0 ms ; tsc.flex, synchro a 0,9 ms), dont le premier en-tete peut entrer dans la
# zone relue par un autre lecteur : garde par synchro ci-dessous.
# Les trous de signal restent comptes partout, premier intervalle compris (jamais vus au raccord).
# Garde-fous (revue du 27/10/2026), piste par piste : zone ecartee seulement si celle du tour 0 ne contient pas de donnees
# (Test-ScpZoneData : le raccord n est pas a l index pour une image IPF dont le raccord est ailleurs, un SCP avec bloc
# WRSP, un original non cale sur l index ou ecrit par un Amiga, un index simule) ; par tour et par bout, hors classe
# ecartes seulement s ils forment une seule grappe de ScpIdxClusterMax intervalles au plus, du debut du premier a la fin
# du dernier en ScpIdxClusterNs au plus (raccord mesure sur 30 lectures : 12 us et 4 intervalles au plus sur les copies
# gw, 38 us et 11 intervalles sur les originaux de duplicateur ; 60 us et 100 us y donnent les memes comptes) ; sinon tous
# sont comptes (defaut du support a l index). Verification du 27/10/2026 (Get-ScpZoneOoc) : une grappe prolongee au-dela
# de la zone (hors classe a ScpIdxClusterNs au plus de sa fin) fait compter le bout ; des grappes aux deux bouts d un
# meme tour (de part et d autre de l index) ne sont ecartees qu a ScpIdxClusterMax intervalles et ScpIdxClusterNs de
# distance cumulee a l index au plus (raccord du Sony a cheval : 4 intervalles et 34 us au plus) ; 0 changement sur les
# 30 lectures d essai.
$script:ScpIdxZoneNs = 1000000
$script:ScpIdxClusterNs = 60000
$script:ScpIdxClusterMax = 12
# Garde par synchro (verification du 27/10/2026, Test-ScpZoneSync) : zone aussi jugee « avec donnees » si le tour 0
# contient la double synchro MFM 0x4489 (classes ScpIdxSync : AmigaDOS, IBM et Atari MFM) qui commence a moins de
# ScpIdxZoneNs apres l index, ou a moins de ScpIdxSyncBeforeNs avant la fin du tour 0 (secteur a cheval sur l index) : un
# defaut dans le seul bloc riche de la zone, ou un secteur a donnees uniformes (zeros) a cheval sur l index, ne la font
# plus prendre pour du vide. Un secteur AmigaDOS dure 17,4 ms ; la derniere synchro d une copie gw est a 20,6 ms au moins
# de l index (30 lectures d essai), celle d ibm.800 et d atarist.880 a 19,5 ms environ : une erreur de ce cote compte la
# zone (fausse alerte possible), elle ne masque rien.
$script:ScpIdxSync = '3434324343'
$script:ScpIdxSyncBeforeNs = 18500000
# Tour de moins de 100 ms (plus de 600 tr/min) : plusieurs index par rotation (disque a secteurs durs lu sans
# --hard-sectors) : ni zone de l index, ni tours alignes
$script:ScpIdxMinRevNs = 100000000
# 12.8.2 (S12) : stabilite sur tours alignes, a partir de 3 tours (avec 2 tours, un seul compte de B a A : une variation
# a travers l index serait invisible ; ecart du nombre de flux, comme avant). Classes calculees sur ScpPostWin
# intervalles a chaque bout du tour 0 (ancres, zone de l index ; tout le tour au besoin) et sur ScpRevWin a chaque bout
# des autres tours (zone de l index et recherche des ancres, environ 9 ms en double densite ; segment classe a part
# au-dela) ; tout le tour si les ScpZoneWin intervalles d un bout durent moins de ScpIdxZoneNs (512 intervalles : plus de
# 2 ms en double densite). Ancre : Len intervalles consecutifs (comme les blocs de ScpStats.Instability), cherchee a
# +/- Win puis +/- Win2 de sa position attendue (le deplacement de l index est de quelques flux ; Win2 : celui du C#),
# Tries positions essayees et Cand candidats au plus par bout du tour 0. Donnees dans la zone de l index (meme critere de
# bloc, moities uniques aussi) : pas de ZoneStep intervalles apres un bloc trop uniforme, de Len / 2 apres un motif
# periodique, ZoneTries blocs au plus par bout.
$script:ScpPostWin = 4096
$script:ScpRevWin = 2048
$script:ScpZoneWin = 512
$script:ScpAnchor = @{ Len = 32; Win = 64; Win2 = 600; Tries = 128; Cand = 4; ZoneStep = 4; ZoneTries = 96 }
$script:ScpPostFail = $null                         # echecs du post-traitement d un fichier (Read-ScpFile, Set-ScpTrackPost)

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
    # Ecriture, dans l ordre de ses elements. 12.8.1 (spec-1281 § A.1) : mesure sur l image a ecrire ('content', nouveau
    # defaut) en tete de liste ; une configuration 12.8 a 'quick' passe a 'content' une fois (Update-LegacyLevelMode)
    levelBeforeWriteMode = @{ Sec = 'write'; Key = 'levelBeforeWriteMode'; Type = 'enum'; Def = 'content'; Codes = @('content', 'quick', 'complete') }
    # 12.8.1 (spec-1281 § A.4) : niveaux moyen et bas de la mesure sur l image (k x courbe du lecteur, le haut vaut 1),
    # dans la configuration seulement ; controles ensemble au chargement (Test-ContentLevelSettings : bas <= moyen - 0,2)
    contentKMid        = @{ Sec = 'write';   Key = 'contentKMid';        Type = 'double'; Def = 0.6;      Min = 0.3; Max = 0.8; Var = 'ContentKMid' }
    contentKLow        = @{ Sec = 'write';   Key = 'contentKLow';        Type = 'double'; Def = 0.25;     Min = 0.0; Max = 0.5; Var = 'ContentKLow' }
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
$script:ContentKMid = [double]$script:SettingDefs['contentKMid'].Def        # 12.8.1 : niveaux de la mesure sur l image (Get-Setting)
$script:ContentKLow = [double]$script:SettingDefs['contentKLow'].Def
# 12.8.1 : bornes uniques du facteur de precompensation d une ecriture, definies ici, avant l interface (520).
#  - TargetCorrMax : correction « lecteur cible » Dk, de -TargetCorrMax a +TargetCorrMax (Set-DriveDk,
#    ConvertFrom-TargetCorrConfig : 274 ; champs numWTgt0 et numWTgt1 : 520 ; infobulle : 140) ;
#  - ContentFMax : plafond du facteur ecrit k + Dk, ramene a 0..ContentFMax (Limit-WriteFactor : 274 ; Get-WriteFactorPlan :
#    140 ; 276). La courbe ecrite reste bornee a 0..CalHardNs (ConvertTo-ScaledSpec, 274).
# Portees le 26/10/2026 de 0,5 a 3,0 et de 1,5 a 4,0 : mesures reelles du couple Sony -> TEAC (courbe du Sony tres basse),
# Dk d environ +1,75 et facteur total k + Dk d environ 2,6 ; marge au-dessus. La protection en ns reste la borne absolue
# des valeurs ecrites, 0..CalHardNs
$script:TargetCorrMax = 3.0
$script:ContentFMax = 4.0
$script:WFactorNote = $null                                                 # 12.8.1 : complement « facteur » du libelle du profil (Update-WriteFactorNote)

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

