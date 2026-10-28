# =============================================================================
# GreaseweazleGUI.ps1 - Interface graphique complete pour Greaseweazle
#
# A PLACER DANS LE MEME REPERTOIRE QUE gw.exe (ex. C:\greaseweazle-1.23\)
#   - gw.exe                : resolu automatiquement depuis ce repertoire
#   - GreaseweazleGUI.json  : configuration, creee/mise a jour automatiquement
#
# Couvre les 13 actions de gw : info read write convert erase clean seek
#                               delays update pin reset bandwidth rpm
# + onglet Bibliotheque : arborescence d images, archives ZIP parsees,
#   documents (txt/pdf/jpeg/png/gif/nfo) ouverts dans l application par defaut.
#
# v6 : fenetre entierement redimensionnable (separateur onglets/journal),
#      recherche de la bibliotheque en arriere-plan (plus de gel de l interface).
# v7 : onglet Comparaison - convert (reference) + read (disquette) + diff secteur.
# v8 : onglet Alignement - mesure de qualite de lecture (jitter, asymetrie, dropouts)
#      sur une disquette pressee, en continu pendant le reglage du stepper.
# v9 : profils de precompensation (standard 2 us / long track 1,89 us) choisis
#      automatiquement d apres l image (IPF et HFE : bits par piste, SCP : flux).
#
# Compatible Windows PowerShell 5.1+ / PowerShell 7
# Lancement : powershell -ExecutionPolicy Bypass -File .\GreaseweazleGUI.ps1
# =============================================================================

param(
    [ValidateSet('auto','fr','en')][string]$Language = 'auto'   # auto = langue d affichage de Windows (fr -> francais, sinon anglais)
)

# Version de l application (lue par Build-Exe.ps1 et par le workflow de release)
$script:Version = '12.8.2'
# Version du calcul de calibration (motif de test, mesure du decalage, ajustement de la courbe, verification), enregistree
# avec chaque courbe : a changer seulement quand ce calcul change. Une courbe faite avec ce calcul est reprise par les
# versions suivantes de l application ; une courbe d un autre calcul n est reprise que si l utilisateur la conserve.
# 12.8.2 : en double densite, chaque passe efface ses pistes en haute frequence (gw erase --hfreq) puis ecrit le motif
# sans --pre-erase (New-CalibPass) : la mesure change, les courbes du calcul 12.6 sont mises de cote au chargement
$script:CalibCalc = '12.8.2'
# 12.7 : version du calcul de la famille haute densite (hd), distincte : son bareme provisoire changera apres les premieres
# mesures reelles sans rouvrir le choix des courbes double densite (Get-CurveCalcRef)
$script:CalibCalcHd = '12.7'
# 12.8.1 : version de la mesure de la disquette sur l image (marge comptee sur le contenu de l image, facteur k par tete),
# enregistree avec chaque mesure (write.driveFactors) : une mesure d une autre version n est plus le facteur du lecteur
# (Get-DriveK). Distincte de CalibCalc : la calibration du lecteur (courbe V) ne change pas
$script:ContentCalc = '12.8.1'
$script:CalibAlgo = 'seg1'       # famille de modele de la courbe (information enregistree avec chaque courbe)
$script:OldCalib = $null         # calibrations d un autre calcul, mises de cote au chargement en attendant le choix

