# ============================== RESTAURATION : LOGIQUE =========================
# Copie d une disquette d origine sur une disquette vierge, regles d ecriture les plus strictes :
#  1. lecture de l original : avec un format, image secteur lue par gw avec relectures physiques (--retries,
#     --seek-retries ; un secteur manquant est rempli par gw du motif « -=[BAD SECTOR]=- ») ; sans format, flux exact ;
#  2. verification : avec un format, tous les secteurs doivent etre lus, sinon arret avant toute ecriture (une copie
#     fidele est impossible) ; flux : qualite piste par piste, a juger par l utilisateur au changement de disquette ;
#  3. changement de disquette (pause, bouton Continuer) ; 4. sonde du cylindre 0 de la destination : identique a
#     l original -> c est probablement l original, l ecriture est refusee sauf confirmation ;
#  5-7. ecriture lente tete par tete deleguee a Start-PresetWrite : une calibration existante (par tete, sinon commune)
#     n est jamais refaite, ses reserves sont signalees ; calibration par tete en test fin seulement si la famille n en a
#     aucune, eventuellement sur une disquette sacrifiee (la destination est alors redemandee et de nouveau sondee) ;
#     pre-effacement, verification gw, essais et passes de reecriture de $script:RestoreRules, controle de toutes les pistes ;
#  8. relecture de la copie sans nouvel essai et comparaison secteur par secteur avec l original.
# Machine d etats $script:Restore, un seul repartiteur Invoke-RestoreNext. Calibration, ecriture et controle vident
# la chaine d etapes : ils rappellent la restauration par des points d accroche (Complete-WriteCheck, fin de
# Start-ImageWrite). Tout abandon passe par Stop-Restore (idempotent) ; un chien de garde dans le timer arrete une
# sequence restee sans suite (aucun gw, aucune etape, aucun controle ni calibration en cours).
$script:Restore = $null
$script:GwCapture = $null
$script:LastCheck = $null
$script:RestoreArgs = @()
$script:RestoreRules = @{ ReadRevs = 5; ReadRetries = 10; SeekRetries = 2; WriteRetries = 20; RepairPasses = 5; FinalRetries = 0 }
