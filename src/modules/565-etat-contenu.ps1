
# ============================== MESURE DE LA DISQUETTE SUR L IMAGE =============
# 12.8.1 : mesure de la disquette sur l image (276) ; principe : spec-1281.md, § A
# Principe. Avant une ecriture lente, 40 cylindres de l image (8 blocs de 5 repartis sur le disque) sont ecrits avec
# l image elle-meme, en 3 passes, a k x V : V est la courbe du lecteur (inchangee), k parcourt 3 niveaux selon un carre
# latin (chaque bloc recoit chaque niveau une fois). Apres chaque passe, ces pistes sont relues sur 3 tours et leur marge
# fixe (Mfix : quantile 1e-3 de l ecart de chaque intervalle a ses limites de decodage, horloge fixe) est comptee
# (192). Par tete, la marge est ajustee par effets fixes passe + cylindre et une quadratique en k ; son sommet, borne a
# [k_min ; 1], est le facteur k* de la tete (274). La courbe ecrite vaut (k* + Dk) x V, bornee a 0..CalHardNs (Dk :
# correction « lecteur cible » du lecteur). Sans mesure, le facteur du lecteur (mediane des 3 derniers k* du lecteur, de
# la famille et de la tete, 1 sans mesure) s applique. Pistes exclues : absentes, longues ou protegees de l image (IPF),
# avant l ecriture ; vides, de longueur hors norme ou non MFM a tous les niveaux, apres la relecture. Arret de gw sur une
# piste refusee a la verification : piste gardee, reprise de la tete une fois par passe.
$script:ContentLevelsDefault = @(1.0, 0.6, 0.25)   # niveaux k x V par defaut (contentKMid, contentKLow : 040)
$script:ContentBlocks = 8; $script:ContentBlockLen = 5; $script:ContentMinBlocks = 4; $script:ContentMaxCyl = 80
$script:ContentQ = 1e-3; $script:ContentTolM = 1e-6; $script:ContentMaxIt = 50; $script:ContentT0Tol = 0.05
$script:ContentZMax = 5e-4; $script:ContentCellsTol = 0.02; $script:ContentFluxMin = 0.5
$script:ContentMinCyl = 20; $script:ContentMinLevelCyl = 6; $script:ContentResumeMax = 1
$script:ContentEstWrite = 1.25; $script:ContentEstRead = 0.85     # s par piste (balayages du 25/10/2026)
$script:EraseEstTrack = 0.37         # 12.8.2 : s par piste effacee en haute frequence (essai E5 du 27/10/2026 : 52 pistes en 19 s)
$script:ContentScpName = 'contenu-mesure.scp'   # relecture unique quand contentKeepMeasures vaut 0 (plafond du facteur ContentFMax : 040)
# 12.9 (critique de la phase A, § 3.1) : modele « K-ns » (y = a_passe + g_cylindre - Q (W - k V)^2, 274), facteur k de 0 a
# ContentKMax ; marge plate si t de la courbure < ContentFlatT, facteur peu determine si son erreur-type > ContentSeKMax ;
# poids de Huber (constante, iterations), pistes de poids < ContentLowWeight nommees au journal ; 4e passe aux niveaux
# ContentFourthLevels (alternes par bloc) si une tete a k >= ContentFourthTrigger ou pas de sommet ; enregistrements :
# ContentRecPerKey par lecteur, famille, tete, marque et calcul, ContentRecMax en tout, ContentRecOldMax d un ancien
# calcul ; relectures gardees dans TempDir\ContentScpDir (D6, reglage contentKeepMeasures : 040)
$script:ContentKMax = 2.0; $script:ContentFlatT = 2.0; $script:ContentSeKMax = 0.25
$script:ContentHuberC = 1.345; $script:ContentHuberIt = 10; $script:ContentLowWeight = 0.5
$script:ContentFourthLevels = @(1.6, 1.0); $script:ContentFourthTrigger = 0.9
$script:ContentRecPerKey = 5; $script:ContentRecMax = 80; $script:ContentRecOldMax = 20   # 20 -> 80
$script:ContentScpDir = 'mesures-image'
$script:ContentMeasures = @()        # enregistrements de mesure (C.2), relus par Load-Config
$script:TargetCorr = @{}             # Dk par lecteur (C.4), relu par Load-Config
$script:TgtCorrEdit = @{}            # saisie en cours d un champ Dk (tete -> lecteur et valeur d avant), 140
$script:WriteFactorNext = $null      # facteur mesure pour l ecriture qui suit (A.10), lu une fois par Start-ImageWrite
$script:GwVerifyFail = $null         # arret « Failed to verify Track C.H » de la derniere commande gw write (110)
