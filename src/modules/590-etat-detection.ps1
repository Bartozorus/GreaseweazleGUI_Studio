
# Sortie de gw capturee via redirection fichier puis relue par le timer.
# --- Detection des lecteurs -------------------------------------------------------------------------------------
# gw seek <lecteur> 0 : sans moteur ni ecriture, la tete revient au cylindre 0 ; un lecteur absent ou mal cable ne
# signale jamais la piste 0 (« Command Failed: Seek: Track 0 not found », code 0, ou « Track0 signal absent », code 1).
# Carte « Tester le Greaseweazle » : connexion du lecteur du bandeau d abord, puis les autres de A, B, 0 a 3. 12.11 rc3
# (R3) : plus de detection au demarrage, et la detection ne change plus le lecteur du bandeau
$script:Detect = $null
$script:DriveIds = @('A', 'B', '0', '1', '2', '3')

