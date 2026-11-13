
# ============================== CALIBRATION PRECOMP ============================
# Principe. La precompensation corrige le decalage de pic (peak shift) : a la lecture,
# une transition est repoussee par sa voisine la plus proche, donc un intervalle court
# (2T) encadre par deux longs est lu trop long et un 3T encadre par deux courts trop
# court. ScpStats.Analyze mesure ce decalage residuel signe (Shift, ns) : > 0 = sous-
# compense, < 0 = sur-compense, 0 = reglage ideal. Il est lineaire en la precomp
# ecrite : trois passes de mesure (0, 30 et 100 ns en double densite, niveaux repartis par cylindre) suffisent
# pour ajuster une droite par
# cylindre et en deduire la valeur qui annule le decalage. Une passe de verification
# ecrit ensuite le profil obtenu et mesure le residu ; les cylindres hors tolerance
# sont corriges et une derniere passe verifie. Chaque passe = une commande gw write
# (tous les cylindres de test, --precomp unique ou profil) puis gw read en flux, 3 tours.
# Courbe : les estimations des cylindres testes (avec leur incertitude) sont ajustees par une courbe
# croissante vers l interieur (Fit-PrecompCurve), evaluee pour CHAQUE cylindre de l image : une valeur
# entiere en ns par cylindre, profil c=ns avec une entree a chaque changement. Courbe affichable (bouton
# « Courbe ») et enregistree avec ses mesures.
# Le profil remplace celui de la famille de l image (standard 2 us / long track) et est
# enregistre dans la configuration : le mode Auto l applique ensuite.
# Test standard : un cylindre sur 10 plus le dernier ; test fin : tous les cylindres.
# Cylindres deduits de l image (ADF, IPF, HFE), 80 par defaut. gw n applique la precomp
# qu aux pistes a bits (images secteur ou bitcell), jamais aux flux SCP/RAW.
$script:Cal = $null
$script:CalRedo = $null   # calibration B (« Refaire sur une autre disquette ») : courbe A en memoire ; Stage 'confirm', 'running' ou 'interrupted'
$script:CalCoarse    = @(0, 30, 100)   # passes de mesure : trois niveaux, repartis par cylindre (12.9, correction 2)
# 12.10 : niveaux proportionnes a la famille (Get-CalLevels) : en long track (cellule 1,89 us) le besoin vaut 1,4 a 1,7 fois
# celui du standard (TEAC du 02/11/2026 : 105 a 439 ns) et tous les cylindres depassaient 100 ns : plus aucun zero interpole,
# decalage commun de l ecriture non evaluable, toute la courbe extrapolee ou encadree. Facteur sur CalCoarse : 0/60/200 ns
$script:CalLevelKLong = 2.0
# 12.11 : correction de l asymetrie de l onglet Qualite par la reference du motif retiree (fonctions et drapeau de la
# 12.10, livres desactives). Lectures gardees du 02/11/2026 (un lecteur, long track) : l asymetrie n est pas un biais de
# lecture du lecteur, elle suit la precompensation ecrite ; retrancher le releve du motif, ecrit a la courbe entiere,
# n etait juste qu a ce niveau et penalisait une ecriture au facteur mesure. Le releve (AsymCyl, AsymD3, AsymD4 : ecarts
# 3T/2T - 1,5 et 4T/2T - 2 du motif relu a la premiere verification, Get-TracksAsym, Get-UnitAsymRef) reste enregistre
# avec chaque courbe, pour l etude ; plus aucun code ne le relit
# 12.9 (correction 3) : 0, 30 et 100 ns au lieu de 0, 100 et 200 : la corde qui donne le zero des besoins courants (5 a
# 85 ns au lecteur A) est courte et proche du zero (biais de courbure +0,91 -> +0,19 ns, v129\cal2\donnees) ; un besoin
# au-dela de 100 ns est encadre (CalBracketMargin, CalBracketStep et CalMaxNs inchanges).
# Plafond des passes de MESURE (encadrement, mesures complementaires, cibles interpolees) : un cylindre encore
# sous-compense a ce plafond a un zero extrapole de ses mesures, que la verification ecrit et mesure.
$script:CalMaxNs     = 300
# Borne absolue d une valeur de precomp (zero estime, courbe, verification, plafond Sat/plancher des residus) : gw 1.23
# n impose aucune borne (PrecompSpec int(v), Precomp.apply sans clamp) ; en MFM 2 us, un intervalle court ecrit vaut
# 4 us - 2t, 400 ns = 0,2 cellule ; simulation du PLL de gw : premier echec vers 540 ns (2 us), 507 ns (long track
# 1,89 us). Reglage write.precompMaxNs : de 300 ns (plafond des mesures) a CalHardMaxNs, 470 ns (un quart de cellule long
# track : chaque intervalle ecrit y atteint sa frontiere de decision) ; chaque courbe enregistre la borne de son calcul (maxNs).
$script:CalHardNsDefault = 400
$script:CalHardMinNs = 300
$script:CalHardMaxNs = 470   # 12.11 : borne haute du reglage precompMaxNs, et repli sans densite du plafond par disquette ci-dessous
$script:CalDiskCapCell = 0.25; $script:CalDiskCapMaxNs = 500   # 12.11 : plafond par disquette (Get-DiskCapNs, 265) : part de la cellule de l image, et ns au plus
$script:CalHardNs    = $script:CalHardNsDefault
# Zero extrapole au-dela de CalMaxNs incertain (plus de CalTrendSig ns, 25 % de 50 ns) ou sans pente propre : combine avec
# la tendance de la courbe, droite sur les CalTrendN derniers cylindres fiables, a CalTrendSpan cylindres au plus en test
# fin (3 fois plus en test standard)
$script:CalTrendSig  = 12.5
$script:CalTrendN    = 6
$script:CalTrendSpan = 12
$script:CalResidual  = 4.0              # residu (ns) au-dela duquel un cylindre est corrige
$script:CalNoiseMinDiffs = 10           # differences de residus (cylindres verifies distants de 2 au plus) necessaires pour estimer le bruit, sinon regle d origine
$script:CalDriftWitness  = 10           # verification ciblee : cylindres temoins non modifies, reecrits et relus pour mesurer la derive du lecteur (H)
$script:CalDriftMinWit   = 6            # temoins necessaires pour retirer cette derive du jugement (H)
$script:CalContraMaxNs   = 12           # verifications contradictoires : ecart entre elles (ns de precomp) au-dela duquel la fenetre de decision s ouvre (H)
$script:CalContraMinNs   = 2            # verifications contradictoires : ecart minimal (ns de precomp) quand la tolerance de la verification 1 n est pas convertible
$script:CalMaxVerify = 2                # passes de verification au plus
# 12.8 (lot 1b) : nouvel essai automatique, apres la derniere verification, des cylindres non converges dont la cause
# n est pas exclue (Get-CalibRetestPlan) : passes de verification ciblees de plus, au plus
$script:CalMaxRetest = 1
# 12.8 (S3-HIGH, essai E1 du 23/10/2026) : mesure complete de cette disquette ($script:CalDiskOnly) seulement : nouveaux
# essais automatiques au plus (la calibration complete de reference garde CalMaxRetest). Ecritures du motif par piste au
# plus, annoncees dans l avertissement M1 et au journal : passes de mesure, encadrement, mesure directe, verifications et
# ces nouveaux essais, soit 10 ; la disquette mesuree est celle a ecrire, reecrite ensuite par l image (pas de disquette
# sacrifiee a epargner)
$script:CalDiskMaxRetest = 3
$script:CalBracketMargin = 80          # passe d encadrement : estimation + marge (ns) pour un cylindre encore sous-compense au plus fort niveau des passes de mesure (100 ns en double densite)
# --- Controle de surface de la passe 1 (seuils provisoires (H)) ------------------------------------------------------
$script:CalSurfDropRevs  = 2      # trous de signal (>= 20 us) dans au moins ce nombre de tours : defaut reproductible (H)
$script:CalSurfOocFloor  = 20     # hors classe par tour (mediane des tours) : plancher, borne CRITIQUE de Get-HealthLevel (H)
$script:CalSurfStabFloor = 10     # ecart du nombre de flux entre tours : plancher, borne CRITIQUE de Get-HealthLevel (H)
$script:CalSurfMadK      = 10     # ecart a la mediane de la face, en MAD normalises (MAD au moins 1) (H)
$script:CalSurfShiftMax  = 300    # decalage residuel (ns) au-dela duquel les hors classe ne sont pas juges (H)
$script:CalSurfMinBad    = 2      # pistes defectueuses par face pour une disquette douteuse, au moins (H)
$script:CalSurfFrac      = 0.10   # ... ou cette part des cylindres testes de la face (H)
$script:CalSurfRun       = 3      # ... ou ce nombre de cylindres testes consecutifs (H)
# --- Comparaison de deux calibrations (A et B, autre disquette) (H) --------------------------------------------------
$script:CalCmpPointNs  = 4.0      # zone de desaccord : chaque cylindre au-dela de cet ecart de forme (ns de precomp) (H)
$script:CalCmpZoneNs   = 8.0      # ... et moyenne au-dela de max(CalCmpZoneNs ; 3 sigma / racine(n)) (H, 3 calibrations reelles)
$script:CalCmpMinN     = 3        # ... sur au moins ce nombre de cylindres encadres consecutifs (H)
$script:CalCmpSpotNs   = 15.0     # ecart ponctuel : au-dela de max(CalCmpSpotNs ; 4 sigma) (H)
$script:CalCmpPrefNs   = 1.0      # courbe conseillee : forme plus proche de la calibration precedente d au moins
$script:CalCmpPrefFrac = 0.25     #   max(CalCmpPrefNs ; CalCmpPrefFrac x l autre) (H)
$script:CalCmpLocalNs  = 4.0      # zone de desaccord : courbe conseillee si son ecart local a la calibration precedente est plus faible d au moins (H)
# --- Vitesse du lecteur et densite relue a la passe 1, toutes familles (arbitrage 10 de la 12.7) ----------------------
$script:CalSurfRotTol    = 0.10   # duree du tour : ecart relatif admis a 60 000 / tr/min ms (arbitrage 1 : cellule a +/- 10 %) (H)
$script:CalSurfFluxTol   = 0.10   # nombre de flux par tour : ecart relatif admis a CalFluxPerCell x cellules du motif (H)
$script:CalSurfGrossFrac = 0.5    # defaut grossier d une face : au moins cette part de ses pistes mesurees hors tolerance (arbitrage 1)
$script:CalFluxPerCell   = 0.375  # flux par cellule du motif (CalibPattern.Track : 0,75 transition par bit de donnee, 2 cellules par bit)
$script:CalHdShiftCells  = 0.2    # haute densite : decalage a la passe 1 au-dela duquel la mesure sort de sa plage (simulation 18/10/2026)
$script:AfterCalib = ''                                  # 'write' : ecriture rapide ou lente a lancer apres une calibration reussie
$script:CalibConfirmSeconds = 120                        # avertissement avant calibration : validation automatique au bout de ce delai (s)
# 12.9 (S1) : ce delai ne vaut plus que pour la calibration de la disquette a ecrire d une ecriture sans surveillance (case
# « Sans surveillance pour la prochaine ecriture » de l onglet Ecriture, chkWUnattended, Get-CalibConfirmSeconds) ; une
# calibration seule n a jamais de delai. CalibUnattended : etat de la case, pour la session, jamais enregistre ;
# UnattendedRun : sequence d ecriture lancee avec la case cochee (Start-UnattendedWrite), case decochee a sa fin
# (Update-CalibUnattended, minuteur principal)
$script:CalibUnattended = $false
$script:UnattendedRun = $false
# 12.9 (L2-a) : marche du besoin entre deux cylindres voisins, non suivie par la courbe (Get-CalibNeedSteps) : baisse d au
# moins max(CalDevNs / CalStepDevDiv ; CalResidual), soit 5 ns en double densite et 4 ns en haute densite, sous le seuil
# de rupture de la courbe, autour de cylindres non converges contigus (CalStepMaxCyl au plus). Conseil seulement.
# 12.9 (correction 4) : une baisse mesuree par les passes de mesure et confirmee par la verification devient une dent
# suivie par la courbe (CalDentOn) ; les autres restent un conseil
$script:CalStepDevDiv = 3.0
$script:CalStepMaxCyl = 4
# 12.9 (corrections 1, 2 et 4 du calcul de calibration, CalibCalc 12.9 ; double densite seulement, bareme CalScaleDd) :
#  - CalCondPass : conditionnement du lecteur avant la premiere passe de mesure (effacement haute frequence et ecriture
#    du motif sur tous les cylindres, sans relecture, Start-CalibCondition) ;
#  - CalLatin : niveaux des passes de mesure repartis par cylindre (carre latin, Get-CalibLatinW) et decalage propre a
#    chaque passe retire des mesures (Get-CalibPassOffsets, modele M2) ; CalLatinMinCyl cylindres de test au moins
#    (sinon passes uniformes : image de 40 cylindres en test standard) et autant de cylindres mesures aux n niveaux par face ;
#  - CalDentOn : dent locale du besoin admise dans la courbe (Get-CalibDents, Split-CurveDents), CalDentMax par unite au
#    plus (les plus fortes), entre cylindres distants de CalDentGap au plus ; confirmee par la verification si la baisse
#    de ses zeros atteint CalDentConfNs (moitie du seuil de marche de 5 ns) ;
#  - CalCondWarnNs : ecart de la premiere passe de mesure aux suivantes (ns de decalage) au-dela duquel le journal le
#    signale (information seulement ; 4 ns : au-dessus de l ecart que donne le plus souvent le seul decalage propre a
#    chaque ecriture, 1 a 2 ns d ecart-type aux essais du 31/10/2026)
$script:CalCondPass    = $true
$script:CalLatin       = $true
$script:CalLatinMinCyl = 6
$script:CalDentOn      = $true
$script:CalDentMax     = 2
$script:CalDentGap     = 2
$script:CalDentConfNs  = 2.5
$script:CalCondWarnNs  = 4.0
# 12.9 (decalage propre a l ecriture de verification, journal du 01/11/2026) : a une verification qui ecrit tous les
# cylindres estimes d une unite par une commande gw (verification complete, VerifyList nul), le decalage commun de cette
# ecriture, mediane des residus bruts (hors points isoles, hors plafond et plancher), est retire des residus avant le
# jugement et toute correction (Get-VerifyOffset, Invoke-CalibAnalysis) ; la courbe n est pas deplacee, les residus bruts
# restent au journal et dans la courbe enregistree (Raw). CalVOffOn : par bareme (double densite seulement, CalScaleDd) ;
# CalVOffMinCyl : cylindres verifies au moins (test standard de 80 cylindres : 9) ; CalVOffSigK : retire seulement au-dela
# de ce nombre d erreurs-types (1,2533 x max(1 ; 1,4826 MAD) / racine de n) ; CalVOffMaxNs : borne (ns de decalage,
# 2 x CalResidual, seuil de la derive forte) au-dela de laquelle il est signale au journal mais non retire (lecteur ou
# support instable depuis les passes de mesure : chemins d aujourd hui)
$script:CalVOffOn     = $true
$script:CalVOffMinCyl = 9
$script:CalVOffSigK   = 2.0
$script:CalVOffMaxNs  = 8.0
# CalVOffHomNs (banc 129-voff2) : ecart maximal, en ns de decalage, entre la mediane des cylindres retenus (besoin interpole)
# et celle des autres cylindres verifies, et entre les deux moities de la piste parmi les retenus : au-dela, le decalage
# n est pas commun a toute l ecriture (erreur regionale de la courbe) et n est pas retire (Get-VerifyOffset, 'regional')
$script:CalVOffHomNs  = 2.5
# 12.10 : erreur de modele aux forts besoins (Get-VerifySlope, Invoke-CalibAnalysis ; calibration TEAC du 01/11/2026 et
# essai 5 du 02/11/2026 : -0,045 ns/ns de 100 a 215 ns ecrits, 3 ns de surcompensation aux cylindres interieurs, dans
# la tolerance cylindre par cylindre). CalSlopeOn : par bareme (double densite seulement, CalScaleDd) ; CalSlopeMinCyl :
# cylindres verifies ecrits au-dela du niveau mesure, au moins ; CalSlopeMinNsNs : pente minimale (ns de residu par ns
# ecrit) ; CalSlopeSigK : erreurs-types de la pente exigees ; CalSlopeMinNs : residu de la droite au-dela duquel un
# cylindre est corrige a son zero mesure meme dans la tolerance (moitie de CalResidual)
$script:CalSlopeOn      = $true
$script:CalSlopeMinCyl  = 10
$script:CalSlopeMinNsNs = 0.02
$script:CalSlopeSigK    = 2.5   # banc 1210-a (N1) : a 2, une reponse lineaire bruitee passait ~5 % du temps (2,0 a 2,4) ; banc 1210-b : a 3, le
                                 # scenario C5 (besoin 245 + 2,5 c, extrapole au-dela de 300 ns) perdait sa correction (2,7) ; cas reels TEAC 3,8 a 7
$script:CalSlopeMinNs   = 2.0
# Prechauffage du lecteur avant une calibration complete (Start-CalibWarmup ; 12.8, D6 : case « Prechauffer le lecteur
# avant la calibration complete », write.calibWarmup, onglet Ecriture et carte « Calibrer le lecteur »), avant une
# ecriture lente (Start-WriteWarmup, case « Prechauffer le lecteur avant l ecriture lente », write.slowWarmup) et avant la
# calibration rapide qui precede une ecriture lente (meme case) : lectures sans ecriture pendant CalWarmupMinutes (champ
# « Duree du prechauffage » de l onglet Ecriture, write.calWarmupMinutes, decimales admises, 0 : aucun, 0 a 30 min), une
# lecture au moins. Lecteur deja actif (derniere commande gw qui fait tourner le moteur terminee
# il y a moins de CalWarmupGapMin) : duree reduite de celle de sa derniere serie d activite continue (une serie est rompue
# par CalWarmupGapMin sans commande) ; prechauffage saute s il en reste moins de CalWarmupSkipMin. Calibration rapide
# seule ou avant une ecriture rapide, ecriture rapide, reecritures du controle apres ecriture : aucun. Bouton « Passer le
# prechauffage » : fin apres la lecture en cours (WarmSkip).
$script:CalWarmupDefault  = $script:SettingDefs['warmMinutes'].Def   # 12.8 : defaut et borne de la table des reglages (5 et 30 min)
$script:CalWarmupMaxMin   = $script:SettingDefs['warmMinutes'].Max
$script:CalWarmupMinutes  = [double]$script:CalWarmupDefault
$script:CalWarmupMinReads = 1
$script:CalWarmupGapMin   = 5
$script:CalWarmupSkipMin  = 1
$script:CalWarmupMaxFails = 2   # lectures de prechauffage de suite sans aboutir avant d abreger le prechauffage
$script:WriteWarm = $null        # prechauffage d une ecriture lente en cours (Start-WriteWarmup) : chaine d ecriture mise de cote
$script:WarmSkipShown = $false   # bouton « Passer le prechauffage » affiche (synchronise par le minuteur)
$script:DriveActivity = @{}      # 'peripherique|lecteur' -> @{ Start; End } : derniere serie d activite continue du lecteur
                                 # (commandes qui ont fait tourner le moteur : code 0, ou au moins une piste lue ou ecrite)
$script:CalConfirm = $null
# 12.10 : courbes par lecteur. Magasin DriveCurves : « lecteur|cle » -> courbe (cle : std, long, hd, std_h0... ; champs Drive =
# lecteur qui ecrit, Target = lecteur qui relit, vide pour une courbe ordinaire), ecrit par Set-DriveCurve seulement, lu par
# Get-DriveCurve (240), enregistre en bloc write.driveCurves (120). PrecompCurves reste la vue du lecteur courant (bandeau),
# reconstruite par Sync-PrecompCurves au chargement, au changement de lecteur et apres chaque ecriture dans le magasin :
# tout le code qui lit PrecompCurves lit les courbes du lecteur courant, sans changement
$script:DriveCurves = @{}
$script:PrecompCurves = @{ std = $null; long = $null; std_h0 = $null; std_h1 = $null; long_h0 = $null; long_h1 = $null; hd = $null; hd_h0 = $null; hd_h1 = $null }   # vue du lecteur courant : derniere courbe calibree par famille d image (et par tete : ecriture lente)
# 12.7 : cles de la haute densite (hd) apres les six cles double densite, dans le meme ordre qu avant
$script:CurveKeys = @('std', 'long', 'std_h0', 'std_h1', 'long_h0', 'long_h1', 'hd', 'hd_h0', 'hd_h1')
# Calibration rapide (niveau par disquette) : la forme vient d une calibration complete (reference), seul le niveau est
# mesure sur la disquette a ecrire. (H) : seuils a recaler sur materiel reel.
# 12.8 (lot 1c) : calibration rapide adaptative 'lvl2' (journal, enregistrements adaptes) ; write.levelAlgo garde le
# format 'lvl1' (G2) : une 12.7 relit les niveaux ordinaires et ignore seuls les enregistrements adaptes ('lvl2')
$script:LevelAlgo       = 'lvl2'
$script:LevelFormat     = 'lvl1'
$script:LevelCyls       = 6      # cylindres de niveau par unite
$script:LevelMinCyls    = 4
$script:LevelMaxPasses  = 3
$script:LevelLo         = 20     # valeur de reference admise pour un cylindre de niveau (ns)
$script:LevelHi         = 260    # 40 ns de marge sous le plafond des passes de mesure (CalMaxNs, 300 ns) ; repli : 290
$script:LevelSteep      = 15     # ecart maximal avec chaque cylindre voisin de la reference (ns)
$script:LevelMinMove    = 4      # ecart minimal entre les niveaux des passes 1 et 2 (ns)
$script:LevelShapeFloor = 3.0    # plancher d incertitude du controle de forme, tau0 (H)
$script:LevelTauOk      = 4.0    # (H)
$script:LevelTauMax     = 8.0    # (H)
$script:LevelBitsNote   = 0.02
$script:LevelBitsMax    = 0.05   # (H)
$script:LevelHistMax    = 10
$script:LevelFatigueNs  = 25.0   # (H)
$script:LevelKMin       = 0.3    # pente minimale admise (ns de decalage par ns de precomp) pour estimer le niveau
$script:LevelShifts     = @{}    # 'cle de courbe|c|0|1' -> resultat de la derniere calibration rapide
# 12.8 (lot 1c, c1-design.md § 4) : calibration rapide adaptative (module 265), variante prudente V3, reglages (H) faits sur
# la grille du simulateur (v128\c1), plats sauf mention ; c1-linearite.md : aucun ne change
$script:LevelAdaptDeltaMin  = 16     # base minimale des deux precompensations d un cylindre (ns) : pente propre a 10 % pres
$script:LevelAdaptOvershoot = 1.3    # passe de mesure : correction de la passe 1 x 1,3, pour encadrer le zero
$script:LevelAdaptKRatioLo  = 0.5    # pente propre plausible, en fraction de la pente de reference
$script:LevelAdaptKRatioHi  = 1.7
$script:LevelAdaptMinFit    = 6      # cylindres d ajustement au moins pour 3 parametres (5 pour 2, 3 pour le niveau seul)
$script:LevelAdaptParsimony = 0.15   # penalite de la validation croisee par terme de forme
$script:LevelAdaptCoefZ     = 2.0    # terme de forme retenu au-dela de 2 erreurs-types
$script:LevelAdaptEffMin    = 8.0    # effet minimal d une forme sur la face (ns), sinon niveau seul
$script:LevelAdaptSMax      = 0.60   # echelle plausible (refus au-dela)
$script:LevelAdaptBMax      = 60.0   # pente plausible, ns du premier au dernier cylindre (refus au-dela)
$script:LevelAdaptLooFloor  = 15.0   # ecart isole en validation croisee : min(max(15 ; 4 et.) ; 20) ns
$script:LevelAdaptLooK      = 4.0
$script:LevelAdaptLooCap    = 20.0
$script:LevelAdaptResOk     = 8.0    # zone de reserve : residu d ajustement au-dela (ns)
$script:LevelAdaptCtlCyls   = 2      # cylindres de controle hors ajustement (zone c60 et au-dela, et bout de face)
$script:LevelAdaptCtlLo     = 60
$script:LevelAdaptCtlK      = 3.0    # tolerance d un controle : 3 et., bornee a 10..15 ns
$script:LevelAdaptCtlFloor  = 10.0
$script:LevelAdaptCtlCap    = 15.0
$script:LevelAdaptBigEffect = 15.0   # effet qui ouvre la fenetre « a surveiller » (= seuil f = 1 de Test-LevelShape)
$script:LevelAdaptPersist   = 2      # declencheur B a la passe 2 confirme par les zeros a la pente de reference
$script:LevelNwcDelta       = 24     # base de confirmation d une pente nulle (ns)
$script:LevelAdaptTrigF1    = $false # declenchement des la passe 1 sur une forme non conforme a f = 1 (non retenu, § 2.3)
# 12.8 (F3R, decisions du 21/10/2026, v128\c3\final\v3f.py) : terme de centre hc ((c - C0)+ / (n - 1 - C0))^2 de la forme
# adaptee, ajuste sur les controles (passe 3) ou repris d un refus de la passe de mesure (e3) ; reglages (H) de
# c3-variantes.md § 2.1. Plafond par disquette (12.11 : Get-DiskCapNs, quart de la cellule de l image, et non plus
# CalHardMaxNs) pour la seule courbe adaptee dont le besoin depasse CalHardNs (reference et calibration complete : CalHardNs)
$script:LevelCenterC0       = 60     # debut du terme de centre (= LevelAdaptCtlLo)
$script:LevelCenterMinOther = 3.0    # appui : un autre cylindre du centre, meme sens, au moins max(3 ns ; 1 et.)
$script:LevelCenterOpp      = 8.0    # aucun cylindre du centre en sens contraire au-dela de max(8 ns ; 2 et.)
$script:LevelCenterLooCap   = 20.0   # regularite : controle et reintegres predits sans eux a min(max(15 ; 4 et.) ; 20) ns
$script:LevelCenterResOk    = 10.0   # lissage : |residu| <= max(10 ns ; 3 et.)
$script:LevelCenterFresh    = $true  # controle neuf (jamais ecrit) apres une reprise e3
# 12.8 (lot 1c, § 10) : memoire de la correction par marque de disquette (write.levelBrand, write.levelBrands)
$script:LevelBrandMax        = 30    # entrees gardees (les plus anciennes supprimees)
$script:LevelBrandKeepLevels = 10    # niveaux gardes par entree
$script:LevelBrandKeepShapes = 5     # formes gardees par entree ; point de depart = medianes
$script:LevelBrand  = ''             # derniere marque choisie (vide : non precisee)
$script:LevelBrands = @()            # entrees : marque x lecteur x reference x tete
$script:LevelPostForce = $false      # G1 : controle apres ecriture impose par une courbe adaptee (Start-ImageWrite)
$script:CalReviewBrand = $null       # marque nommee dans la fenetre de decision (Show-CalibReview)
# 12.8 (lot 1c, point 4) : copies GreaseweazleGUI.json.ref-*.bak gardees (Backup-ConfigBeforeRef, les plus recentes)
$script:ConfigRefBackupKeep = 10
# 12.8 (lot 1c, point 3) : repli « Calibration complete » demande par Start-LevelFallback (@{ Swap }) : confirmation sans
# compte a rebours, case « disquette sacrifiee » obligatoire ; lu et remis a $null au debut de Start-PrecompCalib
$script:CalFallbackAsk = $null
# 12.10 : calibration croisee demandee par Start-CrossCalib (@{ Src ; Tgt } : le lecteur qui ecrit, celui qui relit) : lue
# et remise a $null au debut de Start-PrecompCalib (signature inchangee : enveloppes de make-test), comme CalFallbackAsk
$script:CalCrossAsk = $null
# 12.10 : lecteur cible des ecritures, par lecteur source (liste « Lecteur cible » de l onglet Ecriture, 520 ; Get-TargetDrive,
# Set-TargetDrive, 140) : « source » -> « cible » ; relu par Load-Config (write.targetDrive, Import-TargetDrives), garde par
# Set-Defaults et « Effacer les calibrations » (les courbes croisees, elles, sont effacees)
$script:TargetDrives = @{}
# 12.8 (S3, decision du 21/10/2026) : mesure complete de cette disquette demandee par Start-DiskMeasure (@{ Brand ; HardNs ;
# Ref } ; 12.11 : HardNs et CapBits poses par Start-PrecompCalib, la densite du motif connue) : lue et remise a $null au debut de
# Start-PrecompCalib (signature inchangee : make-test) ; relance sans marque (W-M2) : lu et remis a $false par Start-LevelCalib
$script:CalDiskOnly = $null
$script:LevelNoBrand = $false
# 12.7 : bareme de la calibration par famille. Les amplitudes ci-dessus (ns de precompensation, ou de decalage rapporte a
# la cellule) sont celles de la double densite (2 us). Haute densite (1 us, famille hd) : amplitudes x CalHdK, d apres la
# plage de mesure de ScpStats.Analyze (sans biais jusqu a 0,2 cellule : 400 ns a 2 us, 200 ns a 1 us, simulation du
# 18/10/2026) (H). Seuils de bruit (CalResidual, CalContraMinNs, derive, temoins, pentes, comptes du controle de surface)
# communs. Set-CalibScale pose le bareme de la famille au debut de chaque calibration ; double densite : objets d origine
# (CalScaleDd), calcul inchange.
$script:CalBracketStep   = 40      # encadrement : au moins la plus forte valeur mesuree + ce pas (ns)
$script:CalTrendRefSig   = 6.0     # tendance : incertitude maximale d un cylindre de reference (ns)
$script:CalDevNs         = 15.0    # ecart notable : point isole, chute ou ecart du test standard, courbe moins mesure (ns)
$script:CalDenseStep     = 15      # mesure complementaire B : ecart minimal a la valeur A (ns)
$script:CalExtrapSigMin  = 5.0     # incertitude minimale d un zero extrapole (ns)
$script:CalSigMax        = 50.0    # incertitude maximale d un zero (ns)
$script:CalInterpDefault = 100     # cible d une passe de mesure sans aucune estimation (ns)
$script:CalHdK           = 0.5     # rapport des cellules haute et double densite (1 us / 2 us) (H)
$script:CalHardNsUser    = $script:CalHardNs   # borne configuree (precompMaxNs), celle de la double densite
$script:CalScaleDd = @{ CalCoarse = $script:CalCoarse; CalMaxNs = $script:CalMaxNs; CalBracketMargin = $script:CalBracketMargin
    CalBracketStep = $script:CalBracketStep; CalTrendSig = $script:CalTrendSig; CalTrendRefSig = $script:CalTrendRefSig
    CalContraMaxNs = $script:CalContraMaxNs; CalDevNs = $script:CalDevNs; CalDenseStep = $script:CalDenseStep
    CalExtrapSigMin = $script:CalExtrapSigMin; CalSigMax = $script:CalSigMax; CalInterpDefault = $script:CalInterpDefault
    CalSurfShiftMax = $script:CalSurfShiftMax; CalCmpPointNs = $script:CalCmpPointNs; CalCmpZoneNs = $script:CalCmpZoneNs
    CalCmpSpotNs = $script:CalCmpSpotNs; CalCmpPrefNs = $script:CalCmpPrefNs; CalCmpLocalNs = $script:CalCmpLocalNs
    LevelTauOk = $script:LevelTauOk; LevelTauMax = $script:LevelTauMax; CalCondPass = $script:CalCondPass; CalLatin = $script:CalLatin; CalDentOn = $script:CalDentOn; CalVOffOn = $script:CalVOffOn }
$script:CalScaleHd = @{ CalCoarse = @(0, 50, 100); CalMaxNs = 150; CalBracketMargin = 40; CalBracketStep = 20; CalTrendSig = 6.25
    CalTrendRefSig = 3.0; CalContraMaxNs = 6; CalDevNs = 7.5; CalDenseStep = 8; CalExtrapSigMin = 2.5; CalSigMax = 25.0
    CalInterpDefault = 50; CalSurfShiftMax = 150; CalCmpPointNs = 2.0; CalCmpZoneNs = 4.0; CalCmpSpotNs = 7.5; CalCmpPrefNs = 0.5
    CalCmpLocalNs = 2.0; LevelTauOk = 2.0; LevelTauMax = 4.0; CalCondPass = $false; CalLatin = $false; CalDentOn = $false; CalVOffOn = $false }
$script:CalScaleFam = 'dd'
$script:WProfileHd = $false           # champs --precomp remplis par la branche haute densite d Update-PrecompForImage (mode Auto)
$script:LevelFieldsPending = $false   # ecriture apres une calibration rapide (Bibliotheque) : champs remis a la reference a sa fin
$script:CurveData = $null; $script:CurveForm = $null; $script:CurveFamily = 'std'
$script:CurveZones = @()   # 12.7 : zones de desaccord entre les calibrations A et B (fenetre de comparaison, Draw-PrecompCurve)
# 12.10 (lot 1, A1-tendance) : tendance lissee de la fenetre Courbe (affichage seul, hors du calcul de calibration) : marche
# franche d au moins 6 ns (haute densite : x CalHdK), courbe dessinee a partir de 20 cylindres mesures
$script:CurveTrendStepNs = 6.0
$script:CurveTrendMinCyls = 20
$script:UiReady = $false                                 # vrai une fois la fenetre principale affichee
