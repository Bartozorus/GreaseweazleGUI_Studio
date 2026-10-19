
# Sortie de gw capturee via redirection fichier puis relue par le timer.
# --- Detection des lecteurs -------------------------------------------------------------------------------------
# gw seek <lecteur> 0 : sans moteur ni ecriture, la tete revient au cylindre 0 ; un lecteur absent ou mal cable ne
# signale jamais la piste 0 (« Command Failed: Seek: Track 0 not found », code 0, ou « Track0 signal absent », code 1).
# Au demarrage : lecteur memorise d abord, puis A, B, 0 a 3, arret au premier qui repond. Carte « Tester » : tous.
$script:Detect = $null
$script:DetectAt = $null
$script:DriveIds = @('A', 'B', '0', '1', '2', '3')

$script:DetectNone = $false     # aucun lecteur au dernier demarrage : seul le lecteur memorise est teste (configuration)

