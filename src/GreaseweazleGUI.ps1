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
$script:Version = '12.6'
# Version du calcul de calibration (motif de test, mesure du decalage, ajustement de la courbe, verification), enregistree
# avec chaque courbe : a changer seulement quand ce calcul change. Une courbe faite avec ce calcul est reprise par les
# versions suivantes de l application ; une courbe d un autre calcul n est reprise que si l utilisateur la conserve.
$script:CalibCalc = '12.6'
$script:CalibAlgo = 'seg1'       # famille de modele de la courbe (information enregistree avec chaque courbe)
$script:OldCalib = $null         # calibrations d un autre calcul, mises de cote au chargement en attendant le choix

# --- Langue de l interface -------------------------------------------------------
# Deux langues : francais et anglais. Choix automatique d apres la langue
# d affichage de Windows (CurrentUICulture) : fr -> francais, toute autre -> anglais.
# -Language fr|en force le choix. Le francais est la cle de la table, l anglais la
# valeur ; une cle absente est affichee telle quelle (francais).
$script:Lang = $Language
if ($script:Lang -eq 'auto') {
    $script:Lang = if ([System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'fr') { 'fr' } else { 'en' }
}
$script:I18n = [System.Collections.Hashtable]::new([System.StringComparer]::Ordinal)
$script:I18n['Préservation, écriture et contrôle de disquettes'] = 'Floppy disk preservation, writing and checking'
$script:I18n['●  gw.exe prêt'] = '●  gw.exe ready'
$script:I18n['●  gw.exe introuvable'] = '●  gw.exe not found'
$script:I18n["A/B = bus IBM-PC (nappe avec twist) - typiquement le lecteur PC`n0 à 3 = bus Shugart (nappe droite) - typiquement le lecteur Amiga`nAu démarrage, l'application sélectionne le premier lecteur qui répond."] = "A/B = IBM-PC bus (twisted cable) - typically the PC drive`n0 to 3 = Shugart bus (straight cable) - typically the Amiga drive`nAt startup, the application selects the first drive that responds."
$script:I18n['Port COM du Greaseweazle. Vide = détection automatique.'] = 'Greaseweazle COM port. Empty = auto-detect.'
$script:I18n['Lecteur :'] = 'Drive:'
$script:I18n['COM :'] = 'COM:'
$script:I18n['Bibliothèque'] = 'Library'
$script:I18n['Choisir le dossier racine'] = 'Choose the root folder'
$script:I18n['Répertoire racine de la bibliothèque d''images'] = 'Root folder of the image library'
$script:I18n['Actualiser l''arborescence'] = 'Refresh the tree'
$script:I18n["Recherche dans l'index : plusieurs mots = tous requis (ex. : monkey 2 fr).`nRésultats au fil de la frappe une fois l'index construit. Vide = arborescence."] = "Search the index: several words = all required (e.g. monkey 2 fr).`nResults as you type once the index is built. Empty = tree view."
$script:I18n['Chercher'] = 'Search'
$script:I18n['Images seulement'] = 'Images only'
$script:I18n['Réindexer'] = 'Reindex'
$script:I18n["Reconstruit l'index de la racine (en arrière-plan). À faire après l'ajout ou le déplacement de fichiers."] = "Rebuilds the root index (in the background). Do this after adding or moving files."
$script:I18n['Écriture rapide'] = 'Fast write'
$script:I18n["Écrit l'image sélectionnée en une passe, les deux têtes ensemble : image entière, profil de précompensation Auto,`npré-effacement, effacement des pistes vides, vérification gw, 10 essais, sans contrôle complet des pistes.`nSans calibration commune pour la famille de l'image, le lecteur est d'abord calibré : la disquette reçoit le motif de test, puis l'image."] = "Writes the selected image in one pass, both heads together: whole image, Auto precompensation profile,`npre-erase, erase empty tracks, gw verification, 10 retries, no full track check.`nWithout a common calibration for the image family, the drive is calibrated first: the disk receives the test pattern, then the image."
$script:I18n["Écrit la tête 0 puis la tête 1, chacune avec sa précompensation, puis contrôle toutes les pistes`net réécrit les pistes faibles, 3 passes au plus. Mêmes paramètres que l'écriture rapide.`nSans calibration par tête pour la famille de l'image, chaque tête est d'abord calibrée : la disquette reçoit le motif de test, puis l'image."] = "Writes head 0 then head 1, each with its own precompensation, then checks every track`nand rewrites weak tracks, 3 passes at most. Same settings as the fast write.`nWithout a per-head calibration for the image family, each head is calibrated first: the disk receives the test pattern, then the image."
$script:I18n['Écriture lente : image entière, profil Auto, pré-effacement, effacement des pistes vides, vérification gw, 10 essais, tête 0 puis tête 1, contrôle de toutes les pistes, 3 passes de réécriture.'] = 'Slow write: whole image, Auto profile, pre-erase, erase empty tracks, gw verification, 10 retries, head 0 then head 1, full track check, 3 rewrite passes.'
$script:I18n['Écriture rapide : image entière, profil Auto, pré-effacement, effacement des pistes vides, vérification gw, 10 essais, les deux têtes ensemble, sans contrôle complet des pistes.'] = 'Fast write: whole image, Auto profile, pre-erase, erase empty tracks, gw verification, 10 retries, both heads together, no full track check.'
$script:I18n['par tête'] = 'per-head'
$script:I18n['commune'] = 'common'
$script:I18n["La calibration {0} de la famille {1} a été mesurée sur le contenu d'une image, avant le motif de test : elle est refaite."] = "The {0} calibration of the {1} family was measured on an image's content, before the test pattern: it is redone."
$script:I18n["Aucune calibration {0} pour la famille {1} : calibration automatique, puis écriture."] = "No {0} calibration for the {1} family: automatic calibration, then write."
$script:I18n['Écriture annulée : la calibration n''a pas été lancée.'] = 'Write cancelled: the calibration was not started.'
$script:I18n["Calibration automatique avant l'écriture : la disquette insérée reçoit d'abord le motif de test, puis l'image."] = "Automatic calibration before writing: the inserted disk first receives the test pattern, then the image."
$script:I18n['Écriture annulée : calibration interrompue.'] = 'Write cancelled: calibration aborted.'
$script:I18n['Écriture annulée : calibration sans mesure exploitable.'] = 'Write cancelled: calibration without usable measurement.'
$script:I18n['Calibration terminée : écriture de l''image avec le profil obtenu.'] = 'Calibration complete: writing the image with the resulting profile.'
$script:I18n['Ce fichier n''est pas un format image reconnu par gw.'] = 'This file is not an image format recognised by gw.'
$script:I18n['Type non pris en charge'] = 'Unsupported type'
$script:I18n["Image sélectionnée : {0}"] = "Selected image: {0}"
$script:I18n['Ouvrir (application par défaut)'] = 'Open (default application)'
$script:I18n["Ouverture impossible : {0}"] = "Cannot open: {0}"
$script:I18n['Ouvrir le dossier'] = 'Open folder'
$script:I18n['Racine :'] = 'Root:'
$script:I18n['Recherche :'] = 'Search:'
$script:I18n['Écriture'] = 'Write'
$script:I18n['Image à écrire'] = 'Image to write'
$script:I18n['Choisir une image (IPF, ADF, SCP, HFE...). Le format et le profil de précompensation sont déduits automatiquement.'] = 'Choose an image (IPF, ADF, SCP, HFE...). The format and the precompensation profile are detected automatically.'
$script:I18n["(auto) = aucun --format transmis : obligatoire pour IPF, SCP, HFE.`nUn ADF a besoin de amiga.amigados (rempli automatiquement). Saisie libre possible."] = "(auto) = no --format passed: required for IPF, SCP, HFE.`nAn ADF needs amiga.amigados (filled in automatically). Free input allowed."
$script:I18n['Auto (selon image)'] = 'Auto (from image)'
$script:I18n['Long track 1,89 us'] = 'Long track 1.89 us'
$script:I18n['Manuel'] = 'Manual'
$script:I18n["Auto : la cellule de l'image est mesurée (IPF et HFE : bits par piste ; SCP : flux)`net le profil --precomp correspondant est appliqué.`nManuel : le champ --precomp n'est jamais modifié."] = "Auto: the image bit cell is measured (IPF and HFE: bits per track; SCP: flux)`nand the matching --precomp profile is applied.`nManual: the --precomp field is never changed."
$script:I18n['Images disquette|*.ipf;*.adf;*.scp;*.hfe;*.img;*.st;*.dsk;*.raw;*.d64;*.imd|Tous|*.*'] = 'Disk images|*.ipf;*.adf;*.scp;*.hfe;*.img;*.st;*.dsk;*.raw;*.d64;*.imd|All files|*.*'
$script:I18n['Image :'] = 'Image:'
$script:I18n['Format :'] = 'Format:'
$script:I18n['Profil précomp. :'] = 'Precomp profile:'
$script:I18n['Options d''écriture'] = 'Write options'
$script:I18n['Pré-effacer chaque piste'] = 'Pre-erase each track'
$script:I18n['--pre-erase : efface la piste juste avant de l''écrire. Recommandé sur une disquette déjà utilisée.'] = '--pre-erase: erases the track just before writing it. Recommended on a previously used disk.'
$script:I18n['Effacer les pistes vides'] = 'Erase empty tracks'
$script:I18n['--erase-empty : efface les pistes vides de l''image au lieu de les sauter. Supprime les résidus de l''ancien contenu.'] = '--erase-empty: erases tracks that are empty in the image instead of skipping them. Removes remnants of old content.'
$script:I18n['Sans vérification'] = 'No verification'
$script:I18n['--no-verify : DÉCONSEILLÉ. Supprime la relecture de contrôle de chaque piste.'] = '--no-verify: NOT RECOMMENDED. Skips the verification read of each track.'
$script:I18n['--retries : nombre de réécritures d''une piste dont la vérification échoue.'] = '--retries: number of rewrites of a track whose verification fails.'
$script:I18n['Précompensation (--precomp) :'] = 'Precompensation (--precomp):'
$script:I18n["--precomp : cylindre=nanosecondes, paliers séparés par ':'.`nRempli automatiquement selon le profil ; modifiable en mode Manuel."] = "--precomp: cylinder=nanoseconds, steps separated by ':'.`nFilled in automatically from the profile; editable in Manual mode."
$script:I18n['Transmet --precomp à gw. Coché automatiquement quand un profil est appliqué.'] = 'Passes --precomp to gw. Checked automatically when a profile is applied.'
$script:I18n['Options avancées'] = 'Advanced options'
$script:I18n["--tracks : sous-ensemble de pistes, ex : c=0-79:h=0-1`nc=0:h=0 pour réécrire uniquement la piste 0 face 0."] = "--tracks: subset of tracks, e.g. c=0-79:h=0-1`nc=0:h=0 to rewrite only track 0 side 0."
$script:I18n['--densel : force le signal density select (pin 2) sur les lecteurs qui l''exploitent.'] = '--densel: forces the density select signal (pin 2) on drives that use it.'
$script:I18n['--fake-index : simule des impulsions d''index, ex : 300rpm ou 200ms (lecteurs sans capteur d''index).'] = '--fake-index: simulates index pulses, e.g. 300rpm or 200ms (drives without an index sensor).'
$script:I18n['Secteurs durs (--hard-sectors)'] = 'Hard sectors (--hard-sectors)'
$script:I18n['TG43 lecteur 8 pouces (--gen-tg43)'] = 'TG43 for 8-inch drives (--gen-tg43)'
$script:I18n['Pistes :'] = 'Tracks:'
$script:I18n['Densel :'] = 'Densel:'
$script:I18n['Fake index :'] = 'Fake index:'
$script:I18n['Diskdefs :'] = 'Diskdefs:'
$script:I18n['ÉCRIRE LA DISQUETTE'] = 'WRITE THE DISK'
$script:I18n['Fichier image introuvable.'] = 'Image file not found.'
$script:I18n['Erreur'] = 'Error'
$script:I18n['Choisissez une image : le format et la précompensation seront déduits automatiquement.'] = 'Choose an image: the format and precompensation will be detected automatically.'
$script:I18n['Lecture / Dump'] = 'Read / Dump'
$script:I18n['Flux SCP (préservation)|*.scp|ADF (AmigaDOS)|*.adf|Kryoflux stream|*.raw|HFE|*.hfe|Tous|*.*'] = 'SCP flux (preservation)|*.scp|ADF (AmigaDOS)|*.adf|Kryoflux stream|*.raw|HFE|*.hfe|All files|*.*'
$script:I18n['Tours lus par piste. 5 recommandés pour l''archivage flux (SCP).'] = 'Revolutions read per track. 5 recommended for flux archiving (SCP).'
$script:I18n['LIRE LA DISQUETTE'] = 'READ THE DISK'
$script:I18n['Indiquez un fichier de sortie.'] = 'Specify an output file.'
$script:I18n['Sortie :'] = 'Output:'
$script:I18n['Images disquette|*.scp;*.raw;*.ipf;*.adf;*.hfe;*.img;*.st;*.dsk|Tous|*.*'] = 'Disk images|*.scp;*.raw;*.ipf;*.adf;*.hfe;*.img;*.st;*.dsk|All files|*.*'
$script:I18n['Format de décodage. Nécessaire pour passer d''un flux (SCP/RAW) à un format secteur (ADF).'] = 'Decoding format. Required to go from a flux file (SCP/RAW) to a sector format (ADF).'
$script:I18n['CONVERTIR'] = 'CONVERT'
$script:I18n['Fichier source introuvable.'] = 'Source file not found.'
$script:I18n['Indiquez un fichier de destination.'] = 'Specify a destination file.'
$script:I18n['Source :'] = 'Source:'
$script:I18n['Destination :'] = 'Destination:'
$script:I18n['Comparaison'] = 'Compare'
$script:I18n["Format de décodage commun : la référence est convertie dans ce format,`nla disquette est lue dans ce format, puis les deux sont comparées octet par octet."] = "Common decoding format: the reference is converted to this format,`nthe disk is read in this format, then both are compared byte by byte."
$script:I18n['Reprendre l''image de l''onglet Écriture'] = 'Use the image from the Write tab'
$script:I18n['COMPARER LA DISQUETTE'] = 'COMPARE THE DISK'
$script:I18n["ERREUR comparaison : {0}"] = "Compare ERROR: {0}"
$script:I18n['Référence :'] = 'Reference:'
$script:I18n['Qualité & alignement'] = 'Quality & alignment'
$script:I18n['BON'] = 'GOOD'
$script:I18n['MOYEN'] = 'AVERAGE'
$script:I18n['MAUVAIS'] = 'POOR'
$script:I18n['Rapide (5 cylindres)'] = 'Quick (5 cylinders)'
$script:I18n['Standard (0-70 pas 10)'] = 'Standard (0-70 by 10)'
$script:I18n['Complet (0-79)'] = 'Full (0-79)'
$script:I18n['Personnalisé'] = 'Custom'
$script:I18n["Rapide : contrôle en 30 s. Standard : tri de collection. Complet : état exhaustif d'une disquette (2-3 min)."] = "Quick: 30 s check. Standard: collection sorting. Full: exhaustive condition of one disk (2-3 min)."
$script:I18n['Cylindres mesurés (0-83), séparés par des virgules.'] = 'Measured cylinders (0-83), comma-separated.'
$script:I18n['Tours lus par piste. 3 suffit ; 5 pour une disquette douteuse.'] = 'Revolutions read per track. 3 is enough; 5 for a doubtful disk.'
$script:I18n['Continu'] = 'Loop'
$script:I18n['Répète la mesure en boucle (réglage mécanique). STOP pour arrêter.'] = 'Repeats the measurement in a loop (mechanical adjustment). STOP to end.'
$script:I18n['MESURER LA DISQUETTE'] = 'MEASURE THE DISK'
$script:I18n['Lit les cylindres choisis avec le lecteur sélectionné en haut et évalue l''état du support et la qualité de lecture.'] = 'Reads the chosen cylinders with the drive selected above and assesses media condition and read quality.'
$script:I18n['Le module d''analyse SCP n''a pas pu être compilé (Add-Type).'] = 'The SCP analysis module could not be compiled (Add-Type).'
$script:I18n['Mesure'] = 'Measurement'
$script:I18n['Fixer comme référence'] = 'Set as reference'
$script:I18n["Mémorise la dernière mesure comme référence (ex. : lecteur Amiga sur la même disquette).`nLes mesures suivantes affichent l'écart en %."] = "Stores the last measurement as the reference (e.g. Amiga drive on the same disk).`nLater measurements show the difference in %."
$script:I18n['Faites d''abord une mesure.'] = 'Run a measurement first.'
$script:I18n['Référence'] = 'Reference'
$script:I18n["lecteur {0}, tête {1}, {2}"] = "drive {0}, head {1}, {2}"
$script:I18n["Référence : {0} ({1} piste(s))"] = "Reference: {0} ({1} track(s))"
$script:I18n["Mesure : référence fixée ({0})."] = "Measurement: reference set ({0})."
$script:I18n['Réinitialiser'] = 'Reset'
$script:I18n['Efface le meilleur score, la tendance, la référence et le guide.'] = 'Clears the best score, the trend, the reference and the guide.'
$script:I18n['Aucune référence'] = 'No reference'
$script:I18n['Lancez une mesure'] = 'Run a measurement'
$script:I18n['Mode réglage du lecteur (guide)'] = 'Drive adjustment mode (guide)'
$script:I18n['Affiche les boutons du guide d''alignement (positions du stepper, recommandations avancer/reculer).'] = 'Shows the alignment guide buttons (stepper positions, forward/back recommendations).'
$script:I18n['Repère (position 0)'] = 'Mark (position 0)'
$script:I18n["Point de départ : stepper à sa position d'origine (trait de repère). Mesure la position 0 et démarre le guide."] = "Starting point: stepper at its original position (reference mark). Measures position 0 and starts the guide."
$script:I18n["J'ai tourné +1 cran"] = "I turned +1 notch"
$script:I18n["À cliquer APRÈS avoir tourné le stepper d'un petit cran dans le sens '+'. Lance la mesure."] = "Click AFTER turning the stepper one small notch in the '+' direction. Runs the measurement."
$script:I18n["J'ai tourné -1 cran"] = "I turned -1 notch"
$script:I18n["À cliquer APRÈS avoir tourné le stepper d'un petit cran dans le sens '-'. Lance la mesure."] = "Click AFTER turning the stepper one small notch in the '-' direction. Runs the measurement."
$script:I18n["État du support : basé uniquement sur les erreurs, les trous de signal, la stabilité entre tours et le jitter.`nIndépendant du contenu : comparable d'une disquette à l'autre."] = "Media condition: based only on errors, signal dropouts, revolution-to-revolution stability and jitter.`nContent-independent: comparable from one disk to another."
$script:I18n["Score de qualité de lecture (plus bas = mieux). Dépend du contenu : à comparer uniquement sur une même image`n(deux lecteurs, deux précompensations, deux réglages)."] = "Read quality score (lower = better). Content-dependent: only compare on the same image`n(two drives, two precompensations, two adjustments)."
$script:I18n['Score par cylindre : barre courte = bon. Trait noir = référence, trait bleu = meilleur vu.'] = 'Score per cylinder: short bar = good. Black line = reference, blue line = best seen.'
$script:I18n['vs réf'] = 'vs ref'
$script:I18n['Mesure :'] = 'Measure:'
$script:I18n['Cylindres :'] = 'Cylinders:'
$script:I18n['Têtes :'] = 'Heads:'
$script:I18n['Tours :'] = 'Revs:'
$script:I18n['Outils'] = 'Tools'
$script:I18n['Mesurer la vitesse (rpm)'] = 'Measure speed (rpm)'
$script:I18n['Mise à jour firmware'] = 'Firmware update'
$script:I18n["Mettre à jour le firmware du Greaseweazle ?`nNe pas débrancher pendant l'opération."] = "Update the Greaseweazle firmware?`nDo not unplug during the operation."
$script:I18n['Cylindre cible. Valeurs négatives possibles sur lecteur flippy.'] = 'Target cylinder. Negative values possible on a flippy drive.'
$script:I18n['TSPEC optionnel. Vide = toute la disquette.'] = 'Optional TSPEC. Empty = whole disk.'
$script:I18n['EFFACER'] = 'ERASE'
$script:I18n["les pistes {0}"] = "tracks {0}"
$script:I18n["TOUTE la disquette"] = "the WHOLE disk"
$script:I18n["Opération IRRÉVERSIBLE : {0} dans le lecteur {1} sera effacée.`n`nContinuer ?"] = "IRREVERSIBLE operation: {0} in drive {1} will be erased.`n`nContinue?"
$script:I18n['Confirmation effacement'] = 'Confirm erase'
$script:I18n['Temps de contact par pas, en millisecondes.'] = 'Contact time per step, in milliseconds.'
$script:I18n['NETTOYER'] = 'CLEAN'
$script:I18n['Nettoyage des têtes'] = 'Head cleaning'
$script:I18n['Appliquer'] = 'Apply'
$script:I18n['Seek cylindre :'] = 'Seek cylinder:'
$script:I18n['Erase tracks :'] = 'Erase tracks:'
$script:I18n['Clean passes :'] = 'Clean passes:'
$script:I18n['linger :'] = 'linger:'
$script:I18n['Pin :'] = 'Pin:'
$script:I18n['Délais'] = 'Delays'
$script:I18n['Select Delay (us) :'] = 'Select Delay (us):'
$script:I18n['Step Delay (us) :'] = 'Step Delay (us):'
$script:I18n['Settle Time (ms) :'] = 'Settle Time (ms):'
$script:I18n['Motor Delay (ms) :'] = 'Motor Delay (ms):'
$script:I18n['Watchdog (ms) :'] = 'Watchdog (ms):'
$script:I18n['Pre-Write (us) :'] = 'Pre-Write (us):'
$script:I18n['Post-Write (us) :'] = 'Post-Write (us):'
$script:I18n['Index Mask (us) :'] = 'Index Mask (us):'
$script:I18n['Afficher les délais actuels'] = 'Show current delays'
$script:I18n['Appliquer les valeurs cochées'] = 'Apply checked values'
$script:I18n['Cochez au moins un paramètre à modifier.'] = 'Check at least one parameter to change.'
$script:I18n['Rien à faire'] = 'Nothing to do'
$script:I18n["Valeurs pré-remplies = défauts usine, à titre indicatif.`n"] = "Pre-filled values = factory defaults, for reference.`n"
$script:I18n["Cochez une case pour transmettre le paramètre à gw.`n`n"] = "Tick a box to pass the parameter to gw.`n`n"
$script:I18n["Seek en échec / Track 0 not found : augmenter Step`n"] = "Seek failing / Track 0 not found: increase Step`n"
$script:I18n["(20000 à 40000 us) puis Settle (40 ms).`n`n"] = "(20000 to 40000 us) then Settle (40 ms).`n`n"
$script:I18n["Les modifications ne survivent pas à un reset ni à un`n"] = "Changes do not survive a reset or`n"
$script:I18n["débranchement du Greaseweazle."] = "unplugging the Greaseweazle."
$script:I18n['Commande libre'] = 'Free command'
$script:I18n['EXÉCUTER'] = 'RUN'
$script:I18n['Arguments passés à gw (sans "gw") :'] = 'Arguments passed to gw (without "gw"):'
$script:I18n['Arrêter'] = 'Stop'
$script:I18n['*** Interrompu par l''utilisateur ***'] = '*** Interrupted by user ***'
$script:I18n['Mesure continue arrêtée.'] = 'Continuous measurement stopped.'
$script:I18n['Masquer journal'] = 'Hide log'
$script:I18n['Exporter'] = 'Export'
$script:I18n['Texte|*.txt'] = 'Text|*.txt'
$script:I18n["Paramètres enregistrés : {0}"] = "Settings saved: {0}"
$script:I18n["Remettre tous les paramètres de l'interface à leurs valeurs par défaut et supprimer le fichier de configuration ?`n`n(Aucun effet sur le Greaseweazle, ni sur vos fichiers image, ni sur l'index de la bibliothèque.)"] = "Reset all interface settings to their defaults and delete the configuration file?`n`n(No effect on the Greaseweazle, your image files or the library index.)"
$script:I18n['Réinitialiser les paramètres'] = 'Reset settings'
$script:I18n['Configuration supprimée, valeurs par défaut restaurées.'] = 'Configuration deleted, defaults restored.'
$script:I18n["Impossible de supprimer la configuration : {0}"] = "Cannot delete the configuration: {0}"
$script:I18n['Valeurs par défaut restaurées.'] = 'Defaults restored.'
$script:I18n['Prêt.'] = 'Ready.'
$script:I18n['Effacer le contenu du journal.'] = 'Clear the log.'
$script:I18n['Exporter le journal dans un fichier texte.'] = 'Export the log to a text file.'
$script:I18n['Enregistrer maintenant tous les paramètres de l''interface.'] = 'Save all interface settings now.'
$script:I18n['Remettre les paramètres de l''interface à leurs valeurs par défaut.'] = 'Reset interface settings to their defaults.'
$script:I18n['Afficher journal'] = 'Show log'
$script:I18n['{0:N1} Mo'] = '{0:N1} MB'
$script:I18n['{0:N0} Ko'] = '{0:N0} KB'
$script:I18n["{0} o"] = "{0} B"
$script:I18n["ZIP illisible ({0}) : {1}"] = "Unreadable ZIP ({0}): {1}"
$script:I18n['(chargement...)'] = '(loading...)'
$script:I18n['(aucune image)'] = '(no image)'
$script:I18n["Lecture impossible de {0} : {1}"] = "Cannot read {0}: {1}"
$script:I18n['recherche en cours...'] = 'searching...'
$script:I18n["Recherche : {0}"] = "Search: {0}"
$script:I18n["{0} résultat(s)"] = "{0} result(s)"
$script:I18n["Index illisible, reconstruction : {0}"] = "Unreadable index, rebuilding: {0}"
$script:I18n["Bibliothèque : indexation de {0} en arrière-plan..."] = "Library: indexing {0} in the background..."
$script:I18n["Index : {0} fichiers, construit le {1}."] = "Index: {0} files, built on {1}."
$script:I18n["Index : {0} fichiers"] = "Index: {0} files"
$script:I18n["{0} premiers sur {1}"] = "first {0} of {1}"
$script:I18n['racine introuvable'] = 'root not found'
$script:I18n["Pour commencer :`r`n1. Choisissez le dossier racine de vos images (bouton ...).`r`n2. Dépliez l'arborescence ou utilisez la recherche.`r`n3. Sélectionnez une image puis « Écriture rapide » ou « Écriture lente »."] = "To get started:`r`n1. Choose the root folder of your images (... button).`r`n2. Expand the tree or use the search.`r`n3. Select an image, then ""Fast write"" or ""Slow write""."
$script:I18n['indexation en cours...'] = 'indexing...'
$script:I18n["{0} élément(s)"] = "{0} item(s)"
$script:I18n['Archive ZIP'] = 'ZIP archive'
$script:I18n['Déplier le nœud pour lister le contenu.'] = 'Expand the node to list its contents.'
$script:I18n["Dans l'archive : {0}"] = "In archive: {0}"
$script:I18n["Entrée  : {0}"] = "Entry  : {0}"
$script:I18n["Taille  : {0}"] = "Size   : {0}"
$script:I18n['Extrait dans un dossier temporaire avant usage.'] = 'Extracted to a temporary folder before use.'
$script:I18n["Image disquette ({0})"] = "Disk image ({0})"
$script:I18n["Taille : {0}"] = "Size: {0}"
$script:I18n['Fichier non pris en charge'] = 'Unsupported file'
$script:I18n["Entrée introuvable dans l'archive : {0}"] = "Entry not found in archive: {0}"
$script:I18n["Extrait : {0} -> {1}"] = "Extracted: {0} -> {1}"
$script:I18n["Extraction impossible : {0}"] = "Extraction failed: {0}"
$script:I18n["ERREUR étape : {0}"] = "Step ERROR: {0}"
$script:I18n["ÉCHEC : {0}"] = "FAILED: {0}"
$script:I18n['Image de référence introuvable.'] = 'Reference image not found.'
$script:I18n['Choisissez un format de décodage.'] = 'Choose a decoding format.'
$script:I18n['Comparaison en cours'] = 'Comparison in progress'
$script:I18n["Comparaison en cours...`r`nReference : {0}`r`nFormat    : {1}"] = "Comparison in progress...`r`nReference : {0}`r`nFormat    : {1}"
$script:I18n["=== Comparaison : {0} ({1}) ==="] = "=== Compare: {0} ({1}) ==="
$script:I18n['Référence déjà au format décodé : copiée sans conversion.'] = 'Reference already in the decoded format: copied without conversion.'
$script:I18n["ÉCHEC : un des deux fichiers décodés est absent.`r`n{0}`r`n{1}"] = "FAILED: one of the two decoded files is missing.`r`n{0}`r`n{1}"
$script:I18n['Comparaison impossible : fichier décodé manquant.'] = 'Cannot compare: decoded file missing.'
$script:I18n["Référence : {0}"] = "Reference : {0}"
$script:I18n["Taille    : référence {0} o / disquette {1} o"] = "Size      : reference {0} B / disk {1} B"
$script:I18n["SHA1 disq : {0}"] = "SHA1 disk : {0}"
$script:I18n['RÉSULTAT : IDENTIQUE - la disquette correspond octet pour octet à la référence'] = 'RESULT: IDENTICAL - the disk matches the reference byte for byte'
$script:I18n["           sur l'ensemble des pistes décodables au format {0}."] = "           across all tracks decodable in the {0} format."
$script:I18n["Comparaison : IDENTIQUE ({0} octets)"] = "Compare: IDENTICAL ({0} bytes)"
$script:I18n["RÉSULTAT : DIFFÉRENT - {0} octet(s) sur {1} secteur(s) / {2}"] = "RESULT: DIFFERENT - {0} byte(s) in {1} sector(s) / {2}"
$script:I18n['           (tailles différentes : vérifier le format de décodage)'] = '           (different sizes: check the decoding format)'
$script:I18n["Cyl {0} Head {1} (piste {2})"] = "Cyl {0} Head {1} (track {2})"
$script:I18n["secteur logique {0} (offset 0x{1:X})"] = "logical sector {0} (offset 0x{1:X})"
$script:I18n["Pistes en écart ({0}) :"] = "Differing tracks ({0}):"
$script:I18n["  {0,-28} secteurs : {1}"] = "  {0,-28} sectors: {1}"
$script:I18n['Une piste dont TOUS les secteurs diffèrent est probablement illisible'] = 'A track where ALL sectors differ is probably unreadable'
$script:I18n['ou non-AmigaDOS (protection) ; quelques secteurs isolés = support marginal.'] = 'or non-AmigaDOS (protection); a few isolated sectors = marginal media.'
$script:I18n["  ... {0} autre(s)"] = "  ... {0} more"
$script:I18n["Comparaison : DIFFÉRENT - {0} octet(s), {1} secteur(s)"] = "Compare: DIFFERENT - {0} byte(s), {1} sector(s)"
$script:I18n["Fichiers décodés conservés :"] = "Decoded files kept:"
$script:I18n["ERREUR pendant la comparaison : {0}"] = "ERROR during comparison: {0}"
$script:I18n["Comparaison : erreur {0}"] = "Compare: error {0}"
$script:I18n['Fichier SCP invalide'] = 'Invalid SCP file'
$script:I18n['Indiquez au moins un cylindre valide (0-83).'] = 'Specify at least one valid cylinder (0-83).'
$script:I18n['Barres de score par cylindre : apparaissent après la première mesure.'] = 'Score bars per cylinder: shown after the first measurement.'
$script:I18n["Position {0}  |  meilleure position : {1} (score {2})"] = "Position {0}  |  best position: {1} (score {2})"
$script:I18n["Position 0 mesurée (score {0}). Tournez le stepper d'UN PETIT cran dans un sens, puis cliquez sur le bouton correspondant."] = "Position 0 measured (score {0}). Turn the stepper ONE SMALL notch in one direction, then click the matching button."
$script:I18n["Position {0} re-mesurée. Meilleure position connue : {1}."] = "Position {0} measured again. Best known position: {1}."
$script:I18n[" Revenez de {0} cran(s) vers le sens {1} pour la retrouver."] = " Go back {0} notch(es) in direction {1} to return to it."
$script:I18n["Position {0} mesurée. Pas de mesure à la position précédente : impossible de conclure, continuez."] = "Position {0} measured. No measurement at the previous position: cannot conclude, keep going."
$script:I18n["AMÉLIORATION ({0} -> {1}) : CONTINUEZ dans le sens {2}, encore un cran, puis mesurez."] = "IMPROVEMENT ({0} -> {1}): KEEP GOING in direction {2}, one more notch, then measure."
$script:I18n["OPTIMUM TROUVÉ à la position {0} (score {1}) : RECULEZ d'un cran (sens {2}), resserrez les vis, re-mesurez pour contrôle."] = "OPTIMUM FOUND at position {0} (score {1}): GO BACK one notch (direction {2}), tighten the screws, measure again to check."
$script:I18n["DÉGRADATION ({0} -> {1}) : RECULEZ d'un cran (sens {2}) pour revenir à la position {3}, puis essayez l'autre sens."] = "DEGRADATION ({0} -> {1}): GO BACK one notch (direction {2}) to return to position {3}, then try the other direction."
$script:I18n["Pas de changement net ({0} -> {1}) : cran trop petit ou plateau. Encore un cran dans le sens {2}."] = "No clear change ({0} -> {1}): notch too small or plateau. One more notch in direction {2}."
$script:I18n["  (Meilleur connu : position {0}.)"] = "  (Best known: position {0}.)"
$script:I18n["Guide alignement : {0}"] = "Alignment guide: {0}"
$script:I18n['Mesure : fichier SCP absent, analyse impossible.'] = 'Measurement: SCP file missing, cannot analyse.'
$script:I18n["Mesure : {0}"] = "Measurement: {0}"
$script:I18n['SAIN'] = 'HEALTHY'
$script:I18n['À SURVEILLER'] = 'TO WATCH'
$script:I18n['CRITIQUE'] = 'CRITICAL'
$script:I18n['ILLISIBLE'] = 'UNREADABLE'
$script:I18n["{0} (illisible)"] = "{0} (unreadable)"
$script:I18n["{0} ({1} err/tour)"] = "{0} ({1} err/rev)"
$script:I18n["SUPPORT CRITIQUE  -  {0} piste(s) en erreur : {1}   ->  dump flux immédiat conseillé"] = "MEDIA CRITICAL  -  {0} track(s) in error: {1}   ->  immediate flux dump advised"
$script:I18n["SUPPORT À SURVEILLER  -  {0}/{1} piste(s) marginale(s) : {2}   ->  dump flux recommandé"] = "MEDIA TO WATCH  -  {0}/{1} marginal track(s): {2}   ->  flux dump recommended"
$script:I18n["SUPPORT SAIN  -  {0}/{1} pistes propres (erreurs, trous, stabilité, jitter dans les normes)"] = "MEDIA HEALTHY  -  {0}/{1} clean tracks (errors, dropouts, stability, jitter within limits)"
$script:I18n['   MIEUX (v)'] = '   BETTER (v)'
$script:I18n['   MOINS BIEN (^)'] = '   WORSE (^)'
$script:I18n["   |   référence {0}"] = "   |   reference {0}"
$script:I18n["Qualité de lecture : score {0} - {1}{2}{3}   |   meilleur {4}"] = "Read quality: score {0} - {1}{2}{3}   |   best {4}"
$script:I18n["Mesure : score moyen {0} ({1}){2}"] = "Measurement: average score {0} ({1}){2}"
$script:I18n['Aucune piste analysable'] = 'No analysable track'
$script:I18n['Signature IPF absente'] = 'IPF signature missing'
$script:I18n['Aucune piste formatée dans l''IPF'] = 'No formatted track in the IPF'
$script:I18n['IPF (bits par piste)'] = 'IPF (bits per track)'
$script:I18n['Signature SCP absente'] = 'SCP signature missing'
$script:I18n['Aucune piste analysable dans le SCP'] = 'No analysable track in the SCP'
$script:I18n['SCP (flux mesuré)'] = 'SCP (measured flux)'
$script:I18n['Signature HFE absente'] = 'HFE signature missing'
$script:I18n['Débit HFE nul'] = 'HFE bitrate is zero'
$script:I18n["HFE (débit {0} kbit/s)"] = "HFE (bitrate {0} kbit/s)"
$script:I18n['Profil manuel : --precomp non modifié.'] = 'Manual profile: --precomp unchanged.'
$script:I18n["Profil forcé : standard 2 us ({0})"] = "Forced profile: standard 2 us ({0})"
$script:I18n["Profil forcé : long track ({0})"] = "Forced profile: long track ({0})"
$script:I18n["Détection du profil impossible ({0}) : {1}"] = "Profile detection failed ({0}): {1}"
$script:I18n["Auto : image secteur ({0}) -> standard 2 us ({1})"] = "Auto: sector image ({0}) -> standard 2 us ({1})"
$script:I18n["cellule {0} ns, {1} bits/piste"] = "cell {0} ns, {1} bits/track"
$script:I18n[", {0}/{1} pistes DOS"] = ", {0}/{1} DOS tracks"
$script:I18n["Auto : {0} : {1} -> "] = "Auto: {0}: {1} -> "
$script:I18n["Profil precomp : {0}"] = "Precomp profile: {0}"
$script:I18n["Compare le contenu physique d'une disquette à une image de référence (IPF, ADF, SCP, HFE...).`r`n`r`n"] = "Compares the physical contents of a disk with a reference image (IPF, ADF, SCP, HFE...).`r`n`r`n"
$script:I18n["Principe : la référence est convertie par gw dans le format de décodage choisi, la disquette est`r`n"] = "Principle: gw converts the reference to the chosen decoding format, the disk is`r`n"
$script:I18n["lue dans ce même format, puis les deux fichiers sont comparés octet par octet, secteur par secteur.`r`n`r`n"] = "read in that same format, then both files are compared byte by byte, sector by sector.`r`n`r`n"
$script:I18n["Limite : seules les pistes décodables dans ce format sont comparées. Les pistes de protection`r`n"] = "Limit: only tracks decodable in that format are compared. Protection tracks`r`n"
$script:I18n["(non-AmigaDOS) d'un IPF n'apparaissent pas dans la comparaison. Le flux brut (SCP) n'est jamais`r`n"] = "(non-AmigaDOS) of an IPF do not appear in the comparison. Raw flux (SCP) is never`r`n"
$script:I18n["identique d'une lecture à l'autre : il n'existe pas de comparaison bit à bit au niveau flux."] = "identical from one read to the next: there is no bit-for-bit comparison at flux level."
$script:I18n['Configuration GreaseweazleGUI - régénérée automatiquement. Supprimable sans risque.'] = 'GreaseweazleGUI configuration - regenerated automatically. Safe to delete.'
$script:I18n["ERREUR sauvegarde configuration : {0}"] = "ERROR saving configuration: {0}"
$script:I18n["Configuration illisible, valeurs par défaut conservées : {0}"] = "Unreadable configuration, defaults kept: {0}"
$script:I18n["{0} en cours..."] = "{0} in progress..."
$script:I18n["piste {0}  ({1}/{2}, {3} %)"] = "track {0}  ({1}/{2}, {3} %)"
$script:I18n["piste {0}"] = "track {0}"
$script:I18n["{0} terminé(e)  -  {1}"] = "{0} done  -  {1}"
$script:I18n["{0} en échec (code {1})  -  {2}"] = "{0} failed (code {1})  -  {2}"
$script:I18n["gw.exe introuvable : {0}`n`nPlacez ce script dans le même répertoire que gw.exe."] = "gw.exe not found: {0}`n`nPut this script in the same folder as gw.exe."
$script:I18n['Lecture'] = 'Read'
$script:I18n['Effacement'] = 'Erase'
$script:I18n['Nettoyage'] = 'Clean'
$script:I18n['Mesure de vitesse'] = 'Speed measurement'
$script:I18n["ERREUR lancement : {0}"] = "Launch ERROR: {0}"
$script:I18n["Pistes ayant nécessité de nouveaux essais : "] = "Tracks that needed retries: "
$script:I18n['Écriture : aucune piste n''a nécessité de nouvel essai.'] = 'Write: no track needed a retry.'
$script:I18n[" (essais x{0})"] = " (retries x{0})"
$script:I18n["  -  essai {0}"] = "  -  retry {0}"
$script:I18n["<<< Terminé (code retour : {0}, {1} s, {2} ligne(s) reçues)"] = "<<< Done (exit code: {0}, {1} s, {2} line(s) received)"
$script:I18n["ERREUR : opération incomplète, gw s'est arrêté après {0} piste(s) sur {1} annoncées avec le code 0. Vérifier le lecteur, le câble USB et l'alimentation, puis relancer."] = "ERROR: incomplete operation, gw stopped after {0} track(s) of {1} announced with exit code 0. Check the drive, the USB cable and the power supply, then retry."
$script:I18n['Séquence interrompue : gw a retourné une erreur.'] = 'Sequence aborted: gw returned an error.'
$script:I18n["ÉCHEC : gw a retourné le code {0}. Voir le journal."] = "FAILED: gw returned code {0}. See the log."
$script:I18n['Mesure interrompue (erreur gw)'] = 'Measurement aborted (gw error)'
$script:I18n["indexation : {0} fichiers..."] = "indexing: {0} files..."
$script:I18n["Indexation : ERREUR {0}"] = "Indexing: ERROR {0}"
$script:I18n["Bibliothèque : index construit, {0} fichiers en {1} s."] = "Library: index built, {0} files in {1} s."
$script:I18n["Répertoire  : {0}"] = "Folder      : {0}"
$script:I18n['gw.exe      : trouvé'] = 'gw.exe      : found'
$script:I18n['gw.exe      : ABSENT - placez ce script dans le répertoire de gw.exe'] = 'gw.exe      : MISSING - put this script in the gw.exe folder'
$script:I18n['Config      : chargée depuis GreaseweazleGUI.json'] = 'Config      : loaded from GreaseweazleGUI.json'
$script:I18n['Config      : aucune, valeurs par défaut'] = 'Config      : none, using defaults'
$script:I18n['module indisponible, recherche directe'] = 'module unavailable, direct search'
$script:I18n['Piste'] = 'Track'
$script:I18n['État'] = 'Status'
$script:I18n['Erreurs'] = 'Errors'
$script:I18n['Trous'] = 'Dropouts'
$script:I18n['Dossier'] = 'Folder'
$script:I18n['Alignement'] = 'Alignment'
$script:I18n['diskdefs|*.cfg|Tous|*.*'] = 'diskdefs|*.cfg|All files|*.*'
$script:I18n['ADF|*.adf|SCP|*.scp|HFE|*.hfe|IMG|*.img|Tous|*.*'] = 'ADF|*.adf|SCP|*.scp|HFE|*.hfe|IMG|*.img|All files|*.*'
$script:I18n['Calibration précomp :'] = 'Precomp calibration:'
$script:I18n['Test standard : 1 cylindre sur 10'] = 'Standard test: 1 cylinder in 10'
$script:I18n['Test fin : tous les cylindres'] = 'Fine test: every cylinder'
$script:I18n['Calibrer'] = 'Calibrate'
$script:I18n["Calibre la précompensation pour ce lecteur d'écriture : chaque passe écrit sur les cylindres de test un motif de test pseudo-aléatoire, à la densité de l'image, avec une valeur de precomp puis, en vérification, le profil obtenu ; elle le relit en flux et mesure le décalage de pic. Une courbe donne ensuite une valeur par cylindre ; le profil est enregistré pour la famille de l'image (standard ou long track) et appliqué ensuite par le mode Auto. Le contenu de l'image n'est pas écrit. La disquette insérée est écrasée. Test standard : un cylindre sur 10, quelques minutes. Test fin : tous les cylindres, un quart d'heure environ."] = "Calibrates precompensation for this write drive: each pass writes a pseudo-random test pattern on the test cylinders, at the image's density, with one precomp value then, for verification, the resulting profile; it reads it back as flux and measures the peak shift. A curve then gives one value per cylinder; the profile is saved for the image family (standard or long track) and applied by Auto mode from then on. The image content is not written. The inserted disk is overwritten. Standard test: one cylinder in 10, a few minutes. Fine test: every cylinder, about a quarter of an hour."
$script:I18n['Calibration : module d''analyse SCP indisponible (Add-Type).'] = 'Calibration: SCP analysis module unavailable (Add-Type).'
$script:I18n['Choisissez d''abord l''image à écrire : elle fixe la famille (cellule) et le nombre de cylindres de la calibration.'] = 'Choose the image to write first: it sets the family (cell) and the number of cylinders of the calibration.'
$script:I18n["Calibration impossible sur un flux ({0}) : la calibration ne détermine la densité que d'une image à bits ou secteurs (ADF, IPF, HFE, IMG...)."] = "Cannot calibrate with a flux image ({0}): the calibration only determines the density of a bit-cell or sector image (ADF, IPF, HFE, IMG...)."
$script:I18n['Calibration precomp'] = 'Precomp calibration'
$script:I18n["{0} cylindres d'après l'image"] = "{0} cylinders from the image"
$script:I18n['80 cylindres par défaut (nombre non lisible dans l''image)'] = '80 cylinders by default (count not readable from the image)'
$script:I18n['test fin, tous les cylindres'] = 'fine test, every cylinder'
$script:I18n['test standard, un cylindre sur 10'] = 'standard test, one cylinder in 10'
$script:I18n["Calibration de la précompensation sur le lecteur {0} ({1}).`n`nImage : {2}, famille {3}, {4}.`nMotif de test : données pseudo-aléatoires générées à la densité de l'image, son contenu n'est pas écrit.`nCylindres de test : {5} (2 faces), ÉCRASÉS à chaque passe. Durée estimée : {6} min pour {7} passes."] = "Precompensation calibration on drive {0} ({1}).`n`nImage: {2}, family {3}, {4}.`nTest pattern: pseudo-random data generated at the image's density, its content is not written.`nTest cylinders: {5} (both sides), OVERWRITTEN on every pass. Estimated time: {6} min for {7} passes."
$script:I18n["ATTENTION : la calibration écrit le motif de test sur les mêmes pistes à chaque passe ({0} passes prévues, jusqu'à {1} {2}). Ces écritures répétées sollicitent le support magnétique et peuvent le fatiguer."] = 'WARNING: calibration writes the test pattern to the same tracks on every pass ({0} passes planned, up to {1} {2}). These repeated writes stress the magnetic media and can wear it out.'
$script:I18n['si la courbe demande un encadrement'] = 'if the curve needs a bracketing pass'
$script:I18n['si la courbe demande un encadrement ou des mesures complémentaires (30 cylindres au plus)'] = 'if the curve needs a bracketing pass or additional measurements (30 cylinders at most)'
$script:I18n["Pour épargner {0}, cochez la case ci-dessous (le compte à rebours s'arrête), remplacez-la par une disquette sacrifiée (sans valeur, jamais l'original), puis cliquez sur « Lancer la calibration » : après la calibration, l'application vous demandera de remettre {0}. Sinon, la calibration utilise la disquette insérée."] = 'To spare {0}, tick the box below (the countdown stops), replace it with a sacrificial disk (worthless, never the original), then click "Start the calibration": after the calibration, the application will ask you to put {0} back. Otherwise, the calibration uses the inserted disk.'
$script:I18n["Compte à rebours arrêté : insérez la disquette sacrifiée, puis cliquez sur « Lancer la calibration »."] = 'Countdown stopped: insert the sacrificial disk, then click "Start the calibration".'
$script:I18n["Compte à rebours arrêté : cliquez sur « Lancer la calibration » pour calibrer avec la disquette insérée."] = 'Countdown stopped: click "Start the calibration" to calibrate with the inserted disk.'
$script:I18n['Insérez de préférence une disquette sacrifiée (vierge ou sans valeur), puis validez.'] = 'Preferably insert a sacrificial disk (blank or worthless), then confirm.'
$script:I18n["J'ai inséré une disquette sacrifiée : me redemander {0} après la calibration"] = 'I inserted a sacrificial disk: ask me again for {0} after the calibration'
$script:I18n['la disquette de destination'] = 'the destination disk'
$script:I18n['la disquette à écrire'] = 'the disk to write'
$script:I18n['Lancer la calibration'] = 'Start the calibration'
$script:I18n["Sans réponse, la calibration démarre automatiquement dans {0} s."] = 'Without an answer, the calibration starts automatically in {0} s.'
$script:I18n["Calibration : avertissement validé automatiquement après {0} s sans réponse."] = 'Calibration: warning confirmed automatically after {0} s without an answer.'
$script:I18n["Calibration sur une disquette sacrifiée : {0} sera redemandée avant l'écriture."] = 'Calibration on a sacrificial disk: {0} will be requested again before writing.'
$script:I18n['Écriture annulée : la disquette à écrire n''a pas été remise après la calibration.'] = 'Write cancelled: the disk to write was not put back after the calibration.'
$script:I18n["=== Calibration precomp : lecteur {0}, image {1} ({2}, {3}) ==="] = "=== Precomp calibration: drive {0}, image {1} ({2}, {3}) ==="
$script:I18n["Cylindres de test : {0} ({1})"] = "Test cylinders: {0} ({1})"
$script:I18n["Calibration : passe de mesure {0}/{1}, precomp {2} ns"] = "Calibration: measurement pass {0}/{1}, precomp {2} ns"
$script:I18n["Calibration : passe de vérification {0}/{1}, profil {2}"] = "Calibration: verification pass {0}/{1}, profile {2}"
$script:I18n['profil'] = 'profile'
$script:I18n['Calibration : fichier SCP absent, analyse impossible.'] = 'Calibration: SCP file missing, cannot analyse.'
$script:I18n["Calibration : {0}"] = "Calibration: {0}"
$script:I18n[", illisibles : {0}"] = ", unreadable: {0}"
$script:I18n["  {0} : décalage résiduel moyen {1} ns (de {2} à {3}), score jitter moyen {4}, {5} cylindre(s){6}"] = "  {0}: average residual shift {1} ns (from {2} to {3}), average jitter score {4}, {5} cylinder(s){6}"
$script:I18n["  {0} : aucun cylindre mesurable{1}"] = "  {0}: no measurable cylinder{1}"
$script:I18n['Calibration : aucune mesure exploitable pour estimer la précompensation.'] = 'Calibration: no usable measurement to estimate precompensation.'
$script:I18n["Pente moyenne : {0} ns de décalage par ns de precomp ; estimation par cylindre : {1}"] = "Average slope: {0} ns of shift per ns of precomp; estimate per cylinder: {1}"
$script:I18n["Écrire l'image : la courbe est conservée et l'image est écrite avec elle.`nArrêter : l'image n'est pas écrite et cette calibration n'est pas conservée (la calibration précédente est rétablie)."] = "Write the image: the curve is kept and the image is written with it.`nStop: the image is not written and this calibration is not kept (the previous calibration is restored)."
$script:I18n["Conserver la courbe : elle est enregistrée et appliquée aux prochaines écritures.`nAbandonner la courbe : la calibration précédente est rétablie."] = "Keep the curve: it is saved and applied to the next writes.`nDiscard the curve: the previous calibration is restored."
$script:I18n["La calibration ne donne pas un bon résultat :"] = 'The calibration does not give a good result:'
$script:I18n['Conserver la courbe'] = 'Keep the curve'
$script:I18n['Abandonner la courbe'] = 'Discard the curve'
$script:I18n['Calibration complète'] = 'Full calibration'
$script:I18n["non convergée aux cylindres {0}"] = 'not converged at cylinders {0}'
$script:I18n["plafond de {0} ns atteint aux cylindres {1} (support fatigué ?)"] = '{0} ns ceiling reached at cylinders {1} (worn media?)'
$script:I18n["précompensation nulle encore excessive aux cylindres {0}"] = 'zero precompensation still excessive at cylinders {0}'
$script:I18n["courbe éloignée des mesures (courbe moins mesure) : {0}"] = 'curve far from the measurements (curve minus measurement): {0}'
$script:I18n["Calibration : résultat douteux ({0}) : courbe affichée, décision demandée."] = 'Calibration: doubtful result ({0}): curve shown, decision requested.'
$script:I18n['Calibration abandonnée : la calibration précédente est rétablie.'] = 'Calibration discarded: the previous calibration is restored.'
$script:I18n['Calibration abandonnée à votre demande : courbe non conservée, calibration précédente rétablie.'] = 'Calibration discarded at your request: curve not kept, previous calibration restored.'
$script:I18n['Écriture annulée : résultat de calibration refusé.'] = 'Write cancelled: calibration result refused.'
$script:I18n['résultat de calibration refusé'] = 'calibration result refused'
$script:I18n['Calibration : résultat accepté malgré les réserves.'] = 'Calibration: result accepted despite the reservations.'
$script:I18n["Vérification : {0} cylindre(s) hors tolérance, courbe réajustée sur les zéros mesurés par la vérification ({1}) : {2}"] = 'Verification: {0} cylinder(s) out of tolerance, curve refitted on the zeros measured by the verification ({1}): {2}'
$script:I18n["changement de sens déplacé de {0} à {1}"] = 'change of direction moved from {0} to {1}'
$script:I18n["changements de sens {0}"] = 'changes of direction {0}'
$script:I18n["{0} cylindre(s) corrigé(s), résidu hors tolérance, nouveau profil : {1}"] = "{0} cylinder(s) corrected, residual out of tolerance, new profile: {1}"
$script:I18n["Plafond de {0} ns atteint aux cylindres {1} : le besoin dépasse la précompensation maximale, la courbe reste au plafond et une nouvelle calibration n'y changera rien. Si une disquette en bon état sature aussi, c'est le lecteur ; sinon, c'est le support, probablement fatigué."] = "{0} ns ceiling reached at cylinders {1}: the need exceeds the maximum precompensation, the curve stays at the ceiling and a new calibration will not change it. If a disk in good condition saturates too, it is the drive; otherwise it is the media, probably worn."
$script:I18n[' Limite de précompensation atteinte (0 ou {0} ns) : voir le journal.'] = ' Precompensation limit reached (0 or {0} ns): see the log.'
$script:I18n["Précompensation nulle encore excessive aux cylindres {0} : la courbe reste à 0 ns et une nouvelle calibration n'y changera rien. La même mesure sur une autre disquette désigne le lecteur, sinon le support."] = 'Zero precompensation still excessive at cylinders {0}: the curve stays at 0 ns and a new calibration will not change it. The same measurement on another disk points to the drive, otherwise to the media.'
$script:I18n["Résidu après vérification (ns, tolérance {0}, élargie à 3 erreurs-types si la mesure est plus bruitée) : {1}"] = "Residual after verification (ns, tolerance {0}, widened to 3 standard errors when the measurement is noisier): {1}"
$script:I18n['Calibration precomp : aucune mesure exploitable, profil inchangé.'] = 'Precomp calibration: no usable measurement, profile unchanged.'
$script:I18n["Calibration terminée : profil {0} = {1}"] = "Calibration complete: {0} profile = {1}"
$script:I18n["Profil enregistré dans la configuration et appliqué par le mode Auto à toute image {0}."] = "Profile saved to the configuration and applied by Auto mode to any {0} image."
$script:I18n['Calibration precomp interrompue.'] = 'Precomp calibration aborted.'
$script:I18n['écriture'] = 'writing'
$script:I18n['relecture'] = 'reading back'
$script:I18n["Calibration : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})"] = "Calibration: {4} %, about {5} left (pass {0}/{1}, {2}, {3})"
$script:I18n["Calibration terminée en {0}"] = "Calibration completed in {0}"
$script:I18n['Contrôler toutes les pistes'] = 'Check all tracks'
$script:I18n["Après une écriture réussie, relit en flux toutes les pistes écrites et classe chacune avec les critères de l'onglet Qualité & alignement.`nUne piste À SURVEILLER, CRITIQUE ou illisible est réécrite seule (avec pré-effacement), puis seule remesurée,`njusqu'au nombre de passes de réécriture choisi. Résultat dans l'onglet Qualité & alignement."] = "After a successful write, reads back every written track as flux and grades each one with the Quality & alignment criteria.`nA TO WATCH, CRITICAL or unreadable track is rewritten on its own (with pre-erase), then re-measured on its own,`nup to the chosen number of rewrite passes. Result in the Quality & alignment tab."
$script:I18n['Passes de réécriture :'] = 'Rewrite passes:'
$script:I18n['Nombre maximal de passes de réécriture des pistes faibles détectées par le contrôle. 0 = contrôle seul, sans réécriture.'] = 'Maximum number of rewrite passes for weak tracks found by the check. 0 = check only, no rewrite.'
$script:I18n['ABSENTE'] = 'MISSING'
$script:I18n['Écriture en cours, contrôle de toutes les pistes ensuite.'] = 'Writing, then checking every track.'
$script:I18n['Contrôle après écriture : relecture de toutes les pistes...'] = 'Post-write check: reading back every track...'
$script:I18n["Contrôle après écriture : réécriture {0}/{1} de {2} piste(s) faible(s)..."] = "Post-write check: rewrite {0}/{1} of {2} weak track(s)..."
$script:I18n["Contrôle après écriture : remesure {0}/{1} de {2} piste(s)..."] = "Post-write check: re-measuring {0}/{1}, {2} track(s)..."
$script:I18n['Contrôle après écriture : module d''analyse SCP indisponible, contrôle ignoré.'] = 'Post-write check: SCP analysis module unavailable, check skipped.'
$script:I18n["Contrôle après écriture : relecture en flux de {0} piste(s) de l'image (3 tours)."] = "Post-write check: reading back {0} image track(s) as flux (3 revolutions)."
$script:I18n['Contrôle après écriture : fichier SCP absent, analyse impossible.'] = 'Post-write check: SCP file missing, cannot analyse.'
$script:I18n["Contrôle après écriture : {0}"] = "Post-write check: {0}"
$script:I18n["Contrôle complet : {0} piste(s) mesurée(s), {1} saine(s), {2} à surveiller{3}, {4} critique(s) ou illisible(s){5}."] = "Full check: {0} track(s) measured, {1} healthy, {2} to watch{3}, {4} critical or unreadable{5}."
$script:I18n["Remesure après réécriture {0}/{1} : {2} piste(s), {3} saine(s), {4} à surveiller{5}, {6} critique(s) ou illisible(s){7}."] = "Re-measure after rewrite {0}/{1}: {2} track(s), {3} healthy, {4} to watch{5}, {6} critical or unreadable{7}."
$script:I18n['Contrôle après écriture : aucune piste mesurée.'] = 'Post-write check: no track measured.'
$script:I18n["Plus de la moitié des pistes sont faibles ({0}/{1}) : format non MFM, disquette inadaptée ou lecteur en défaut. Aucune réécriture automatique."] = "More than half of the tracks are weak ({0}/{1}): non-MFM format, unsuitable disk or faulty drive. No automatic rewrite."
$script:I18n["Réécriture des pistes faibles, passe {0}/{1} : {2}"] = "Rewriting weak tracks, pass {0}/{1}: {2}"
$script:I18n[" (réécrite x{0})"] = " (rewritten x{0})"
$script:I18n["Contrôle après écriture : score moyen {0} ({1}) sur {2} piste(s) lisible(s)"] = "Post-write check: average score {0} ({1}) over {2} readable track(s)"
$script:I18n['CONTRÔLE APRÈS ÉCRITURE : aucune piste mesurée.'] = 'POST-WRITE CHECK: no track measured.'
$script:I18n[", après réécriture de {0} piste(s) en {1} passe(s)"] = ", after rewriting {0} track(s) in {1} pass(es)"
$script:I18n["CONTRÔLE APRÈS ÉCRITURE : {0}/{1} pistes faibles, réécriture automatique non lancée (plus de la moitié des pistes)  ->  vérifier le format, la disquette et le lecteur"] = "POST-WRITE CHECK: {0}/{1} weak tracks, automatic rewrite not started (more than half of the tracks)  ->  check the format, the disk and the drive"
$script:I18n["CONTRÔLE APRÈS ÉCRITURE : {0}/{1} piste(s) faible(s) : {2}  (réécriture automatique désactivée)"] = "POST-WRITE CHECK: {0}/{1} weak track(s): {2}  (automatic rewrite disabled)"
$script:I18n["CONTRÔLE APRÈS ÉCRITURE : {0} piste(s) encore faible(s) après {1} passe(s) de réécriture : {2}  ->  support fatigué, réécrire sur une autre disquette"] = "POST-WRITE CHECK: {0} track(s) still weak after {1} rewrite pass(es): {2}  ->  worn media, rewrite on another disk"
$script:I18n['Contrôle après écriture interrompu.'] = 'Post-write check aborted.'
$script:I18n[" ... (+{0})"] = " ... (+{0})"
$script:I18n['gw n''a pas pu être lancé.'] = 'gw could not be started.'
$script:I18n["Contrôle de toutes les pistes non applicable ({0}) : l'analyse de flux est calibrée pour le MFM double densité. Écriture sans contrôle."] = "Track check not applicable ({0}): the flux analysis is calibrated for double-density MFM. Writing without check."
$script:I18n['secteurs durs'] = 'hard sectors'
$script:I18n["format haute densité {0}"] = "high-density format {0}"
$script:I18n["format GCR {0}"] = "GCR format {0}"
$script:I18n["image GCR {0}"] = "GCR image {0}"
$script:I18n['ADF haute densité'] = 'high-density ADF'
$script:I18n["image haute densité, cellule {0} ns"] = "high-density image, cell {0} ns"
$script:I18n["CONTRÔLE APRÈS ÉCRITURE interrompu par une erreur gw à la passe {0}/{1} : {2} piste(s) faible(s) ou non remesurée(s) : {3}  ->  support fatigué ou lecteur en défaut"] = "POST-WRITE CHECK aborted by a gw error in pass {0}/{1}: {2} weak or unmeasured track(s): {3}  ->  worn media or faulty drive"
$script:I18n["Débit HFE invalide ({0} kbit/s)"] = "Invalid HFE bitrate ({0} kbit/s)"
$script:I18n["gw déjà en cours : commande ignorée ({0})."] = "gw already running: command ignored ({0})."
$script:I18n['lecteur 8 pouces (TG43)'] = '8-inch drive (TG43)'
$script:I18n['flux SCP haute densité'] = 'high-density SCP flux'
$script:I18n['Courbe'] = 'Curve'
$script:I18n['Affiche la courbe de précompensation calibrée pour la famille de l''image (standard ou long track) : mesures, courbe ajustée et valeur retenue pour chaque cylindre.'] = 'Shows the calibrated precompensation curve for the image family (standard or long track): measurements, fitted curve and the value used for every cylinder.'
$script:I18n['linéaire'] = 'linear'
$script:I18n['1/rayon'] = '1/radius'
$script:I18n['1/rayon²'] = '1/radius²'
$script:I18n['monotone interpolée'] = 'monotone interpolated'
$script:I18n[' + corrections locales'] = ' + local corrections'
$script:I18n["Profil --precomp : {0}"] = "--precomp profile: {0}"
$script:I18n["Mesures (cylindre : estimation ± incertitude en ns, origine, courbe retenue et écart, résidu de vérification) :"] = "Measurements (cylinder: estimate ± uncertainty in ns, origin, curve value and deviation, verification residual):"
$script:I18n['  * extrapolée au-delà des mesures, ^ plafonnée à 0 ou {0} ns : valeur peu fiable.'] = '  * extrapolated beyond the measurements, ^ capped at 0 or {0} ns: unreliable value.'
$script:I18n['encadrement'] = 'bracketing'
$script:I18n["Calibration : passe d'encadrement des cylindres {0}, encore sous-compensés à {1} ns : precomp {2}"] = "Calibration: bracketing pass for cylinders {0}, still under-compensated at {1} ns: precomp {2}"
$script:I18n['Après encadrement : '] = 'After bracketing: '
$script:I18n["Vérification {0} : "] = "Verification {0}: "
$script:I18n["Valeurs peu fiables : {0} extrapolée(s) au-delà des mesures ({1}), {2} plafonnée(s) à 0 ou {3} ns ({4})."] = "Unreliable values: {0} extrapolated beyond the measurements ({1}), {2} capped at 0 or {3} ns ({4})."
$script:I18n[' NON CONVERGÉE : voir le journal et la fenêtre Courbe.'] = ' NOT CONVERGED: see the log and the Curve window.'
$script:I18n['encadrée'] = 'bracketed'
$script:I18n['extrapolée'] = 'extrapolated'
$script:I18n['plafonnée'] = 'capped'
$script:I18n['NON CONVERGÉE : résidu hors tolérance après la dernière vérification (voir « résidu »).'] = 'NOT CONVERGED: residual out of tolerance after the last verification (see "residual").'
$script:I18n["résidu {0}"] = "residual {0}"
$script:I18n['courbe'] = 'curve'
$script:I18n['NON CONVERGÉE'] = 'NOT CONVERGED'
$script:I18n['mesure encadrée'] = 'bracketed measurement'
$script:I18n['écart > 15 ns et > 3 incertitudes'] = 'deviation > 15 ns and > 3 uncertainties'
$script:I18n['au-delà des mesures'] = 'beyond the measurements'
$script:I18n['cylindre'] = 'cylinder'
$script:I18n["{0} : lecteur {1}, {2}, courbe {3}, de {4} à {5} ns"] = "{0}: drive {1}, {2}, {3} curve, from {4} to {5} ns"

$script:I18n['précompensation retenue par cylindre'] = 'precompensation used per cylinder'
$script:I18n["Courbe de précompensation - {0}"] = "Precompensation curve - {0}"
$script:I18n["Courbe ajustée : {0} (écart réduit {1}), de {2} ns au cylindre 0 à {3} ns au cylindre {4} ; profil : {5}"] = "Fitted curve: {0} (reduced deviation {1}), from {2} ns at cylinder 0 to {3} ns at cylinder {4}; profile: {5}"
$script:I18n["Profil {0} calibré le {1} sur le lecteur {2} : courbe {3}, de {4} à {5} ns, une valeur par cylindre (bouton Courbe)."] = "{0} profile calibrated on {1} for drive {2}: {3} curve, from {4} to {5} ns, one value per cylinder (Curve button)."
$script:I18n["  Précomp cylindres {0}-{1} : {2} ns"] = "  Precomp cylinders {0}-{1}: {2} ns"
$script:I18n['Écriture lente'] = 'Slow write'
$script:I18n["Écriture lente : toutes les pistes de la tête 0, puis toutes celles de la tête 1 (une commande gw write par tête),`nchacune avec sa propre précompensation. Deux balayages complets du disque : plus long.`nCochée, la calibration mesure et vérifie une courbe de précompensation par tête."] = "Slow write: every track of head 0, then every track of head 1 (one gw write command per head),`neach with its own precompensation. Two full sweeps of the disk: takes longer.`nWhen checked, the calibration measures and verifies one precompensation curve per head."
$script:I18n['Précomp. tête 1 (--precomp) :'] = 'Head 1 precomp (--precomp):'
$script:I18n['Précomp. tête 0 (--precomp) :'] = 'Head 0 precomp (--precomp):'
$script:I18n["Écriture lente : --precomp de la tête 1 (la tête 0 utilise le champ du dessus).`nRempli par le profil calibré pour la tête 1 ; modifiable en mode Manuel. Vide : tête 1 écrite sans --precomp."] = "Slow write: --precomp for head 1 (head 0 uses the field above).`nFilled with the profile calibrated for head 1; editable in Manual mode. Empty: head 1 written without --precomp."
$script:I18n['Écriture lente cochée : une courbe par tête, vérifiée en écrivant la tête 0 puis la tête 1, chacune avec son profil.'] = 'Slow write checked: one curve per head, verified by writing head 0 then head 1, each with its own profile.'
$script:I18n['Écriture lente cochée : une courbe par tête, si la calibration a été faite en écriture lente.'] = 'Slow write checked: one curve per head, if the calibration was run in slow write mode.'
$script:I18n['Écriture lente : le champ Pistes ne sélectionne ni la tête 0 ni la tête 1.'] = 'Slow write: the Tracks field selects neither head 0 nor head 1.'
$script:I18n['aucune'] = 'none'
$script:I18n["Écriture lente : {0} commande(s) gw write, tête 0 puis tête 1 ; precomp tête 0 : {1} ; tête 1 : {2}"] = "Slow write: {0} gw write command(s), head 0 then head 1; head 0 precomp: {1}; head 1: {2}"
$script:I18n['[tête {0}] '] = '[head {0}] '
$script:I18n[', une courbe par tête (écriture lente)'] = ', one curve per head (slow write)'
$script:I18n["Calibration : passe de vérification {0}/{1}, tête 0 puis tête 1, profils {2} et {3}"] = "Calibration: verification pass {0}/{1}, head 0 then head 1, profiles {2} and {3}"
$script:I18n["Profils {0} par tête calibrés le {1} sur le lecteur {2} : tête 0 de {3} à {4} ns, tête 1 de {5} à {6} ns, une valeur par cylindre (bouton Courbe)."] = "{0} per-head profiles calibrated on {1} for drive {2}: head 0 from {3} to {4} ns, head 1 from {5} to {6} ns, one value per cylinder (Curve button)."
$script:I18n["Profils par tête enregistrés dans la configuration et appliqués par le mode Auto en écriture lente à toute image {0}."] = "Per-head profiles saved in the configuration and applied by Auto mode in slow write to any {0} image."
$script:I18n["Tête {0} : courbe {1}"] = "Head {0}: {1} curve"
$script:I18n["{0} : lecteur {1}, {2}, une courbe par tête"] = "{0}: drive {1}, {2}, one curve per head"
$script:I18n["tête {0} : courbe {1}, de {2} à {3} ns"] = "head {0}: {1} curve, from {2} to {3} ns"
$script:I18n["Courbe de précompensation - {0}, une courbe par tête"] = "Precompensation curve - {0}, one curve per head"
$script:I18n[' ; écriture lente : profils calibrés tête 0 et tête 1 appliqués'] = '; slow write: head 0 and head 1 calibrated profiles applied'
$script:I18n[' ; écriture lente : même profil pour les deux têtes (aucune calibration par tête pour cette famille)'] = '; slow write: same profile for both heads (no per-head calibration for this family)'
$script:I18n["Écriture lente : image à une seule face, seule la tête {0} est écrite."] = "Slow write: single-sided image, only head {0} is written."
$script:I18n["Écriture lente : nombre de faces de l'image inconnu ({0}).`nIndiquer les têtes dans le champ Pistes (h=0-1 pour une image double face, h=0 pour une simple face)`nou décocher « Effacer les pistes vides » : la tête 1 d'un format simple face serait effacée."] = "Slow write: number of sides of the image unknown ({0}).`nSpecify the heads in the Tracks field (h=0-1 for a double-sided image, h=0 for a single-sided one)`nor uncheck ""Erase empty tracks"": head 1 of a single-sided format would be erased."
$script:I18n["Calibration : motif de test impossible à créer : {0}"] = "Calibration: unable to create the test pattern: {0}"
$script:I18n['format à secteurs, 2 µs par cellule'] = 'sector format, 2 µs per cell'
$script:I18n['Effacer les calibrations'] = 'Clear calibrations'
$script:I18n["Efface toutes les calibrations de précompensation : courbes communes et par tête des familles standard et long track.`nLes profils de famille reprennent leurs valeurs d'origine. Une écriture rapide ou lente recalibre ensuite automatiquement."] = "Clears every precompensation calibration: common and per-head curves of the standard and long-track families.`nThe family profiles return to their original values. A fast or slow write then recalibrates automatically."
$script:I18n["tête {0}"] = "head {0}"
$script:I18n['Opération en cours : attendre la fin de la calibration ou de l''écriture.'] = 'Operation in progress: wait for the calibration or the write to finish.'
$script:I18n['Aucune calibration enregistrée : les profils sont déjà ceux d''origine.'] = 'No calibration saved: the profiles are already the original ones.'
$script:I18n["Effacer toutes les calibrations de précompensation ?`n`nCourbes : {0}.`nProfils de famille remis aux valeurs d'origine : standard {1}, long track {2}.`n`nOpération irréversible. Le mode Auto applique ensuite ces profils ; une écriture rapide ou lente recalibre automatiquement."] = "Clear every precompensation calibration?`n`nCurves: {0}.`nFamily profiles reset to their original values: standard {1}, long track {2}.`n`nThis cannot be undone. Auto mode then applies these profiles; a fast or slow write recalibrates automatically."
$script:I18n['Calibrations effacées.'] = 'Calibrations cleared.'
$script:I18n["Calibrations effacées : {0} courbe(s) ({1}) ; profils standard et long track remis aux valeurs d'origine ({2} ; {3})."] = "Calibrations cleared: {0} curve(s) ({1}); standard and long-track profiles reset to their original values ({2}; {3})."
$script:I18n["Calibration non prise en charge pour une image haute densité ({0}) : les profils calibrés sont ceux des familles double densité (standard 2 µs, long track 1,89 µs)."] = "Calibration not supported for a high-density image ({0}): calibrated profiles belong to the double-density families (standard 2 µs, long track 1.89 µs)."
$script:I18n["Image haute densité ({0}) : pas de calibration automatique, écriture avec le profil courant."] = "High-density image ({0}): no automatic calibration, writing with the current profile."
$script:I18n['ADF haute densité, horloge AmigaDOS de gw'] = 'high-density ADF, gw AmigaDOS clock'
$script:I18n['ADF, horloge AmigaDOS de gw'] = 'ADF, gw AmigaDOS clock'
$script:I18n['IPF, bits par piste de l''image'] = 'IPF, bits per track of the image'
$script:I18n['HFE, bits par piste de l''image'] = 'HFE, bits per track of the image'
$script:I18n["HFE ({0} bits par piste, débit {1} kbit/s)"] = "HFE ({0} bits per track, bitrate {1} kbit/s)"
$script:I18n["image secteur de {0} octets"] = "sector image of {0} bytes"
$script:I18n['image IMD à 500 kbit/s'] = 'IMD image at 500 kbit/s'
$script:I18n["Image secteur sans géométrie ({0}) : gw exige le format.`nChoisir le format dans l'onglet Écriture, puis relancer l'écriture."] = "Sector image without geometry ({0}): gw requires the format.`nChoose the format in the Write tab, then start the write again."
$script:I18n['Format requis'] = 'Format required'
$script:I18n["Densité de l'image non établie ({0}, format déduit par gw) : pas de calibration automatique, écriture avec le profil courant."] = "Image density not established ({0}, format deduced by gw): no automatic calibration, writing with the current profile."
$script:I18n["Module d'analyse SCP indisponible : pas de calibration automatique, écriture avec le profil courant."] = "SCP analysis module unavailable: no automatic calibration, writing with the current profile."
$script:I18n["Courbes par tête de la famille {0} antérieures à la calibration commune : elles sont refaites."] = "Per-head curves of the {0} family are older than the common calibration: they are redone."
$script:I18n["Nombre de faces de l'image inconnu : effacement des pistes vides désactivé (seules les pistes présentes dans l'image sont écrites)."] = "The image's number of sides is unknown: erasing empty tracks disabled (only the tracks present in the image are written)."
$script:I18n["Image à une seule face : seule la tête {0} est écrite (h={0} dans Pistes)."] = "Single-sided image: only head {0} is written (h={0} in Tracks)."
$script:I18n["Champ Pistes : éléments de lecteur conservés ({0})."] = "Tracks field: drive elements kept ({0})."
$script:I18n['Secteurs durs ou lecteur 8 pouces (TG43) : pas de calibration automatique, écriture avec le profil courant.'] = 'Hard sectors or 8-inch drive (TG43): no automatic calibration, writing with the current profile.'
$script:I18n["Cellule de l'image hors de la plage mesurable ({0} ns, de 1 700 à 2 300 ns en MFM double densité) : pas de calibration automatique, écriture avec le profil courant."] = "Image bit cell outside the measurable range ({0} ns, 1,700 to 2,300 ns in double-density MFM): no automatic calibration, writing with the current profile."
$script:I18n['Calibration non prise en charge avec secteurs durs ou lecteur 8 pouces (TG43) : l''analyse de flux est calibrée pour le MFM double densité.'] = 'Calibration not supported with hard sectors or an 8-inch drive (TG43): the flux analysis is calibrated for double-density MFM.'
$script:I18n["Calibration non prise en charge : cellule de l'image de {0} ns, hors de la plage mesurable (1 700 à 2 300 ns, MFM double densité)."] = "Calibration not supported: image bit cell of {0} ns, outside the measurable range (1,700 to 2,300 ns, double-density MFM)."
$script:I18n['non relu'] = 'not read back'
$script:I18n['long track, 1,89 µs par cellule'] = 'long track, 1.89 µs per cell'
$script:I18n["Motif de test : HFE de données pseudo-aléatoires généré, {0} cylindres, {1} cellules par piste ({2}), soit {3} ns par cellule à 300 tr/min. L'image ne fixe que la densité et le nombre de cylindres, son contenu n'est pas écrit."] = "Test pattern: pseudo-random HFE generated, {0} cylinders, {1} cells per track ({2}), i.e. {3} ns per cell at 300 rpm. The image only sets the density and the number of cylinders, its content is not written."
$script:I18n['Calibration : le décalage ne varie pas avec la précompensation écrite, cette face n''a pas été écrite (tête ou circuit d''écriture défaillant ?).'] = 'Calibration: the shift does not vary with the written precompensation, this side was not written (faulty head or write circuit?).'
$script:I18n[' ; écriture lente : courbes par tête antérieures au profil commun, profil commun pour les deux têtes'] = '; slow write: per-head curves older than the common profile, common profile for both heads'
$script:I18n["Aide en ligne : impossible d'ouvrir {0} ({1})"] = 'Online help: cannot open {0} ({1})'
$script:I18n['Chrono'] = 'Timer'
$script:I18n['Affiche le temps écoulé après chaque commande gw (option --time).'] = 'Shows the elapsed time after each gw command (--time option).'
$script:I18n['Mode expert'] = 'Expert mode'
$script:I18n["Décoché : seuls les onglets utiles au quotidien sont affichés (Accueil, Restauration, Bibliothèque, Écriture, Lecture, Qualité).`nCoché : tous les onglets, y compris Conversion, Comparaison, Outils, Délais et Commande libre."] = "Unchecked: only the everyday tabs are shown (Home, Restore, Library, Write, Read, Quality).`nChecked: all tabs, including Conversion, Comparison, Tools, Delays and Free command."
$script:I18n['Aide'] = 'Help'
$script:I18n['Ouvre le guide en ligne de l''onglet affiché (touche F1).'] = 'Opens the online guide for the current tab (F1 key).'
$script:I18n['Essais :'] = 'Retries:'
$script:I18n['Flux brut (--raw)'] = 'Raw flux (--raw)'
$script:I18n['Face B flippy (--reverse)'] = 'Flippy side B (--reverse)'
$script:I18n['Lecture : image secteur, --raw ignoré (gw le refuse pour ce type de fichier).'] = 'Read: sector image, --raw ignored (gw refuses it for this file type).'
$script:I18n['Tester la carte (info)'] = 'Test the board (info)'
$script:I18n['Débit USB (bandwidth)'] = 'USB throughput (bandwidth)'
$script:I18n['Réinitialiser la carte (reset)'] = 'Reset the board (reset)'
$script:I18n['Accueil'] = 'Home'
$script:I18n['Que voulez-vous faire ?'] = 'What do you want to do?'
$script:I18n["Choisissez une tâche : l'application règle les options pour vous. F1 ouvre l'aide de l'onglet affiché."] = 'Pick a task: the application sets the options for you. F1 opens the help for the current tab.'
$script:I18n['Restaurer une disquette'] = 'Restore a floppy disk'
$script:I18n["Copier une disquette d'origine sur une disquette vierge, avec les contrôles les plus stricts."] = 'Copy an original floppy disk onto a blank one, with the strictest checks.'
$script:I18n['Écrire une image sur une disquette'] = 'Write an image to a floppy disk'
$script:I18n["Choisir un fichier (ADF, IPF, SCP...) dans votre bibliothèque et l'écrire sur une disquette."] = 'Pick a file (ADF, IPF, SCP...) in your library and write it to a floppy disk.'
$script:I18n['Sauvegarder une disquette'] = 'Back up a floppy disk'
$script:I18n["Lire une disquette et l'enregistrer dans un fichier : SCP pour archiver, ADF pour un émulateur."] = 'Read a floppy disk and save it to a file: SCP to archive, ADF for an emulator.'
$script:I18n['Vérifier une disquette ou un lecteur'] = 'Check a floppy disk or a drive'
$script:I18n['Mesurer la qualité de lecture piste par piste, ou guider le réglage de l''alignement.'] = 'Measure the read quality track by track, or get guidance to adjust the alignment.'
$script:I18n['Tester le Greaseweazle'] = 'Test the Greaseweazle'
$script:I18n['Guide pas à pas'] = 'Step-by-step guide'
$script:I18n['Ouvrir l''aide en ligne : premiers pas, glossaire des termes, dépannage.'] = 'Open the online help: getting started, glossary, troubleshooting.'
$script:I18n['Restauration'] = 'Restore'
$script:I18n['Copie exacte du flux (disquette protégée ou format inconnu)'] = 'Exact flux copy (copy-protected disk or unknown format)'
$script:I18n['1. Disquette d''origine'] = '1. Original disk'
$script:I18n["Lecteur qui lit la disquette d'origine (même convention que le choix Lecteur du bandeau).`nA/B = nappe PC avec twist, 0 à 3 = nappe droite (lecteur Amiga, par exemple)."] = "Drive that reads the original disk (same convention as the Drive choice in the banner).`nA/B = PC cable with twist, 0 to 3 = straight cable (Amiga drive, for example)."
$script:I18n["Format de la disquette d'origine.`nAvec un format (amiga.amigados pour une disquette Amiga, par exemple) : chaque secteur est lu et vérifié, la copie est écrite avec la précompensation calibrée puis comparée secteur par secteur à l'original.`nCopie exacte du flux : pour une disquette protégée contre la copie ou d'un format absent de la liste ; le signal est recopié tel quel, sans précompensation ni comparaison par secteur."] = "Format of the original disk.`nWith a format (amiga.amigados for an Amiga disk, for example): every sector is read and checked, the copy is written with the calibrated precompensation, then compared sector by sector with the original.`nExact flux copy: for a copy-protected disk or a format not in the list; the signal is copied as is, without precompensation or sector comparison."
$script:I18n['2. Disquette de destination'] = '2. Destination disk'
$script:I18n["Lecteur qui écrit la copie. Même lecteur que l'origine : l'application vous demandera de changer de disquette entre la lecture et l'écriture."] = 'Drive that writes the copy. Same drive as the original: the application will ask you to swap disks between reading and writing.'
$script:I18n['3. Sauvegarde de l''original'] = '3. Backup of the original'
$script:I18n['Dossier où enregistrer la lecture de l''original, la relecture de la copie et le rapport'] = 'Folder where the read of the original, the read-back of the copy and the report are saved'
$script:I18n["Dossier où sont enregistrés la lecture de l'original, la relecture de la copie et le rapport de restauration."] = 'Folder where the read of the original, the read-back of the copy and the restore report are saved.'
$script:I18n['Nom des fichiers enregistrés, par exemple « Workbench 1.3 ». Vide : date et heure.'] = 'Name of the saved files, for example "Workbench 1.3". Empty: date and time.'
$script:I18n['Dossier :'] = 'Folder:'
$script:I18n['Nom :'] = 'Name:'
$script:I18n['Documents\Greaseweazle Studio\Restaurations'] = 'Documents\Greaseweazle Studio\Restorations'
$script:I18n['vide = date et heure'] = 'empty = date and time'
$script:I18n['RESTAURER LA DISQUETTE'] = 'RESTORE THE DISK'
$script:I18n["ERREUR restauration : {0}"] = 'Restore ERROR: {0}'
$script:I18n["Lit l'original, vous demande de changer de disquette, puis écrit et contrôle la copie avec les règles les plus strictes.`nDurée : de quelques minutes à plus d'une demi-heure selon la calibration et l'état des disquettes."] = "Reads the original, asks you to swap disks, then writes and checks the copy with the strictest rules.`nDuration: from a few minutes to more than half an hour depending on the calibration and the condition of the disks."
$script:I18n['Étapes'] = 'Steps'
$script:I18n['Lire la disquette d''origine'] = 'Read the original disk'
$script:I18n['Vérifier la lecture'] = 'Check the read'
$script:I18n['Changer de disquette'] = 'Swap disks'
$script:I18n['Vérifier la disquette de destination'] = 'Check the destination disk'
$script:I18n['Calibrer le lecteur si nécessaire'] = 'Calibrate the drive if needed'
$script:I18n['Écrire la tête 0 puis la tête 1'] = 'Write head 0, then head 1'
$script:I18n['Comparer la copie à l''original'] = 'Compare the copy with the original'
$script:I18n['Continuer'] = 'Continue'
$script:I18n['Écraser quand même'] = 'Overwrite anyway'
$script:I18n['Annuler'] = 'Cancel'
$script:I18n['monotone par segments'] = 'piecewise monotone'
$script:I18n['isolée'] = 'isolated'
$script:I18n['changement de sens'] = 'change of direction'
$script:I18n["Changement de sens du besoin entre c{0} et c{1} : courbe monotone par segments. La même signature sur une autre disquette désigne le lecteur, sinon le support."] = 'Change of direction of the need between c{0} and c{1}: piecewise monotone curve. The same signature on another disk points to the drive, otherwise to the media.'
$script:I18n["Le besoin redescend à partir de c{0} : courbe monotone par segments. La même signature sur une autre disquette désigne le lecteur, sinon le support."] = 'The need decreases from c{0} onwards: piecewise monotone curve. The same signature on another disk points to the drive, otherwise to the media.'
$script:I18n["Point(s) isolé(s) écarté(s) de la courbe : {0} : écart avec les cylindres voisins, défaut ponctuel probable de la disquette de calibration, non suivi."] = 'Isolated point(s) excluded from the curve: {0}: deviation from the neighbouring cylinders, probable local defect of the calibration disk, not followed.'
$script:I18n["Calibration : anomalie de la courbe ({0}) : mesures complémentaires des cylindres {1}, en deux passes, pour distinguer une marche, une rampe ou un point isolé."] = 'Calibration: curve anomaly ({0}): additional measurements of cylinders {1}, in two passes, to tell a step, a ramp or an isolated point apart.'
$script:I18n["Calibration : zone {0} non complétée (2 zones et 30 cylindres au plus) : test fin conseillé."] = 'Calibration: zone {0} not completed (2 zones and 30 cylinders at most): fine test recommended.'
$script:I18n["chute entre c{0} et c{1}"] = 'drop between c{0} and c{1}'
$script:I18n["écart à c{0}"] = 'deviation at c{0}'
$script:I18n["mesure complémentaire {0}"] = 'additional measurement {0}'
$script:I18n["Calibration : mesure complémentaire {0} des cylindres {1} : precomp {2}"] = 'Calibration: additional measurement {0} of cylinders {1}: precomp {2}'
$script:I18n['Après mesures complémentaires : '] = 'After additional measurements: '
$script:I18n["Calibration : passe de vérification {0}/{1} ciblée sur les cylindres modifiés : {2}"] = 'Calibration: verification pass {0}/{1} limited to the changed cylinders: {2}'
$script:I18n["Écart à la courbe de plus de 15 ns et de trois incertitudes (courbe moins mesure) : {0}."] = 'Deviation from the curve of more than 15 ns and three uncertainties (curve minus measurement): {0}.'
$script:I18n["Calibration non convergée aux cylindres {0} : résidu hors tolérance après la dernière vérification, la courbe ne suit pas la mesure à ces cylindres. Refaire la calibration en test fin, ou sur une autre disquette sacrifiée."] = 'Calibration not converged at cylinders {0}: residual out of tolerance after the last verification, the curve does not follow the measurement at these cylinders. Redo the calibration with the fine test, or on another sacrificial disk.'
$script:I18n["Restauration : {0} piste(s) avec une courte zone instable ({1}) : raccord d'écriture ou protection possible. Elles ne seront jamais réécrites sur une disquette identique à l'original."] = 'Restore: {0} track(s) with a short unstable zone ({1}): write splice or possible protection. They will never be rewritten on a disk identical to the original.'
$script:I18n["La disquette insérée a le même contenu que l'original. Chaque cylindre ({0}) porte une piste non reproductible ou critique : aucun cylindre ne peut être réécrit sans détruire la protection. Écriture refusée : insérez une autre disquette."] = 'The inserted disk has the same content as the original. Every cylinder ({0}) carries a non-reproducible or critical track: no cylinder can be rewritten without destroying the protection. Write refused: insert another disk.'
$script:I18n["aucun cylindre réécrivable sans toucher aux pistes non reproductibles : rien n'a été écrit"] = 'no cylinder can be rewritten without touching the non-reproducible tracks: nothing was written'
$script:I18n["ATTENTION : la disquette insérée porte les mêmes données que l'original, c'est probablement l'ORIGINAL. Changez de disquette. S'il s'agit d'une ancienne copie à remplacer entièrement, cliquez sur « Annuler », effacez-la (case « Mode expert », onglet Outils, bouton « EFFACER »), puis relancez la restauration. « Écraser quand même » sert à rafraîchir l'original : les cylindres non reproductibles ou critiques ne sont ni réécrits ni contrôlés."] = 'WARNING: the inserted disk holds the same data as the original, it is probably the ORIGINAL. Change disks. If it is an old copy to replace entirely, click "Cancel", erase it ("Expert mode" box, Tools tab, "ERASE" button), then start the restore again. "Overwrite anyway" is for refreshing the original: the non-reproducible or critical cylinders are neither rewritten nor checked.'
$script:I18n[" {0} piste(s) non reproductible(s) de l'original préservée(s), non réécrite(s) : protection d'origine intacte."] = ' {0} non-reproducible track(s) of the original preserved, not rewritten: original protection intact.'
$script:I18n[" Cylindres {0} ni réécrits ni contrôlés (disquette reconnue comme l'original) : s'il s'agissait d'une copie, elle est incomplète ; effacez-la puis relancez la restauration."] = ' Cylinders {0} neither rewritten nor checked (disk recognised as the original): if it was a copy, it is incomplete; erase it then restart the restore.'
$script:I18n["Image flux : {0} piste(s) déjà critique(s) ou illisible(s) dans l'image ({1}) : piste non formatée, protection ou défaut de l'original. gw en écrit le premier tour tel quel : ces pistes ne sont ni réécrites ni comptées par le contrôle."] = 'Flux image: {0} track(s) already critical or unreadable in the image ({1}): unformatted track, protection or defect of the original. gw writes their first revolution as it is: these tracks are neither rewritten nor counted by the check.'
$script:I18n["Analyse de l'image flux..."] = 'Analysing the flux image...'
$script:I18n["CONTRÔLE APRÈS ÉCRITURE : {0}/{1} pistes saines"] = 'POST-WRITE CHECK: {0}/{1} healthy tracks'
$script:I18n[", {0} piste(s) non reproductible(s) ou déjà critique(s) non comptée(s) : {1}"] = ', {0} non-reproducible or already critical track(s) not counted: {1}'
$script:I18n["{0}/{1} pistes saines"] = '{0}/{1} healthy tracks'
$script:I18n["Zone instable d'un tour à l'autre (protection contre la copie ou défaut du support) : {0}"] = 'Zone changing from one revolution to the next (copy protection or media defect): {0}'
$script:I18n[" ; cylindres voisins {0} : défaut du support probable"] = '; neighbouring cylinders {0}: probable media defect'
$script:I18n["c{0}-c{1} tête {2}"] = 'c{0}-c{1} head {2}'
$script:I18n["Mesure : pistes instables sur des cylindres voisins d'une même face ({0}) : défaut du support probable (rayure, usure) plutôt qu'une protection."] = 'Measurement: unstable tracks on neighbouring cylinders of the same side ({0}): probable media defect (scratch, wear) rather than a protection.'
$script:I18n["Zone instable sur la copie, défaut probable du support (la source n'en contient pas) : {0}"] = 'Unstable zone on the copy, probable media defect (the source has none): {0}'
$script:I18n["Zone instable de la source (protection probable, non reproductible) : {0}"] = 'Unstable zone from the source (probable protection, not reproducible): {0}'
$script:I18n["Zone instable sur une piste déjà critique dans la source : {0}"] = 'Unstable zone on a track already critical in the source: {0}'
$script:I18n["Zone instable non jugée (la source peut contenir une protection) : {0}"] = 'Unstable zone not judged (the source may hold a protection): {0}'
$script:I18n["Contrôle : zone instable sur {0} piste(s) non jugée(s) ({1}) : la source peut en contenir (protection) sans que l'application puisse le vérifier. Ni réécrites ni comptées comme saines."] = 'Check: unstable zone on {0} track(s) not judged ({1}): the source may hold some (protection) and the application cannot verify it. Neither rewritten nor counted as healthy.'
$script:I18n[", {0} piste(s) à zone instable non jugée(s) : {1}"] = ', {0} track(s) with an unstable zone not judged: {1}'
$script:I18n['NON JUGÉE'] = 'NOT JUDGED'
$script:I18n["Contrôle : zone instable d'un tour à l'autre sur la copie, piste(s) {0} : la source n'en contient pas, défaut probable du support. Ces pistes sont traitées comme faibles."] = 'Check: zone changing from one revolution to the next on the copy, track(s) {0}: the source has none, probable media defect. These tracks are treated as weak.'
$script:I18n["Écart avec la calibration précédente du lecteur {0} ({1}) : {2} ns en moyenne (de {3} à {4} ns)."] = 'Difference from the previous calibration of drive {0} ({1}): {2} ns on average (from {3} to {4} ns).'
$script:I18n["Plafond atteint alors que la calibration précédente du même lecteur ne l'atteignait pas : support de calibration probablement fatigué (sinon têtes à nettoyer, ou autre lecteur sous la même lettre)."] = 'Ceiling reached whereas the previous calibration of the same drive did not reach it: the calibration disk is probably worn (otherwise dirty heads, or another drive under the same letter).'
$script:I18n["Calibration faite sur une disquette sacrifiée dont le besoin dépasse {0} ns : si elle est fatiguée, la courbe surestime le besoin de la disquette à écrire. Préférez une disquette sacrifiée en bon état."] = 'Calibration made on a sacrificial disk whose need exceeds {0} ns: if that disk is worn, the curve overestimates the need of the disk to write. Prefer a sacrificial disk in good condition.'
$script:I18n["Lecteur {0} : non pris en charge par cette carte (ligne de sélection absente)."] = 'Drive {0}: not supported by this board (select line missing).'
$script:I18n["{0} et {1} utilisent la même ligne de sélection : la détection ne peut pas les distinguer (A ou B : nappe PC avec twist ; 0 à 3 : nappe droite)."] = '{0} and {1} use the same select line: the detection cannot tell them apart (A or B: PC cable with twist; 0 to 3: straight cable).'
$script:I18n["Restauration : lecteur {0} remplacé par {1} (origine et destination)."] = 'Restore: drive {0} replaced by {1} (source and destination).'
$script:I18n["Détection des lecteurs : aucun lecteur au dernier démarrage, seul le lecteur {0} est testé (carte « Tester le Greaseweazle » de l'Accueil : tous les lecteurs)."] = 'Drive detection: no drive at the last startup, only drive {0} is tested ("Test the Greaseweazle" card on the Home tab: all drives).'
$script:I18n["Détection des lecteurs interrompue : {0}"] = 'Drive detection aborted: {0}'
$script:I18n[' (zone instable)'] = ' (unstable zone)'
$script:I18n["Mesure : zone instable d'un tour à l'autre sur {0} piste(s) : {1}. Bits faibles d'une protection contre la copie probable, ou défaut localisé du support : une copie faite depuis un flux n'en écrit qu'un tour et ne les reproduit pas fidèlement."] = 'Measurement: zone changing from one revolution to the next on {0} track(s): {1}. Weak bits of a probable copy protection, or a localised media defect: a copy made from a flux image writes only one revolution of them and cannot reproduce them faithfully.'
$script:I18n["{0} pistes : {1} saines, {2} à surveiller, {3} critiques, {4} à zone instable"] = '{0} tracks: {1} healthy, {2} to watch, {3} critical, {4} with an unstable zone'
$script:I18n["Restauration : {0} piste(s) non reproductible(s) sur l'original, zone instable d'un tour à l'autre ({1}) : bits faibles d'une protection contre la copie probable, ou défaut localisé. La copie n'en recevra qu'un tour figé : la protection risque de ne pas fonctionner. Ces pistes ne sont jamais réécrites sur une disquette identique à l'original."] = 'Restore: {0} non-reproducible track(s) on the original, zone changing from one revolution to the next ({1}): weak bits of a probable copy protection, or a localised defect. The copy will receive a single frozen revolution of them: the protection may not work. These tracks are never rewritten on a disk identical to the original.'
$script:I18n["PROTECTION PROBABLE : {0} piste(s) de l'original changent d'un tour à l'autre (bits faibles) : une copie ne peut pas les reproduire et risque de ne pas fonctionner."] = 'PROBABLE PROTECTION: {0} track(s) of the original change from one revolution to the next (weak bits): a copy cannot reproduce them and may not work.'
$script:I18n["Restauration : empreinte de l'original prise sur la piste {0}.{1} ({2} blocs de référence) : la disquette de destination y sera comparée."] = 'Restore: fingerprint of the original taken on track {0}.{1} ({2} reference blocks): the destination disk will be compared with it.'
$script:I18n["Restauration : aucune piste de l'original ne permet une empreinte fiable : la disquette de destination ne pourra pas être comparée à l'original."] = 'Restore: no track of the original allows a reliable fingerprint: the destination disk cannot be compared with the original.'
$script:I18n["Restauration : empreinte de la piste {0}.{1} retrouvée {2} fois sur {3} sur la disquette insérée."] = 'Restore: fingerprint of track {0}.{1} found {2} times out of {3} on the inserted disk.'
$script:I18n["Restauration : la disquette de destination porte les mêmes données que l'original (empreinte de la piste {0}.{1}). Écriture refusée."] = 'Restore: the destination disk holds the same data as the original (fingerprint of track {0}.{1}). Write refused.'
$script:I18n["La disquette insérée a le même contenu que l'original : c'est peut-être l'ORIGINAL lui-même.`n`nEn mode secteur, chaque piste est réécrite au format standard : si la disquette porte une protection contre la copie (piste non standard, bits faibles), elle sera définitivement détruite. Pour une disquette protégée, utilisez « Copie exacte du flux ».`n`nÉcraser quand même cette disquette ?"] = "The inserted disk has the same content as the original: it may be the ORIGINAL itself.`n`nIn sector mode, every track is rewritten in the standard format: if the disk carries a copy protection (non-standard track, weak bits), it will be destroyed for good. For a protected disk, use `"Exact flux copy`".`n`nOverwrite this disk anyway?"
$script:I18n["La disquette insérée a le même contenu que l'original : c'est peut-être l'ORIGINAL lui-même.`n`nLes cylindres qui portent des pistes non reproductibles ou déjà critiques sur l'original ({0}) ne seront pas réécrits : leur protection éventuelle est préservée. Les autres pistes seront effacées puis réécrites à partir de la lecture.`n`nÉcraser quand même cette disquette ?"] = "The inserted disk has the same content as the original: it may be the ORIGINAL itself.`n`nThe cylinders carrying non-reproducible or already critical tracks on the original ({0}) will not be rewritten: their possible protection is preserved. The other tracks will be erased then rewritten from the read.`n`nOverwrite this disk anyway?"
$script:I18n["La disquette insérée a le même contenu que l'original : c'est peut-être l'ORIGINAL lui-même.`n`nAucune piste non reproductible n'a été détectée : toutes les pistes seront effacées puis réécrites à partir de la lecture.`n`nÉcraser quand même cette disquette ?"] = "The inserted disk has the same content as the original: it may be the ORIGINAL itself.`n`nNo non-reproducible track was detected: all tracks will be erased then rewritten from the read.`n`nOverwrite this disk anyway?"
$script:I18n["non vérifiable : aucune empreinte exploitable sur l'original"] = 'not checkable: no usable fingerprint on the original'
$script:I18n["Restauration : écriture sur une disquette identique à l'original : cylindres {0} non réécrits (pistes non reproductibles, protection préservée)."] = 'Restore: writing to a disk identical to the original: cylinders {0} not rewritten (non-reproducible tracks, protection preserved).'
$script:I18n["Instables   : {0} (zone instable d'un tour à l'autre : protection contre la copie probable, non reproductible)"] = 'Unstable    : {0} (zone changing from one revolution to the next: probable copy protection, not reproducible)'
$script:I18n["Préservés   : cylindres {0}, non réécrits sur la disquette identique à l'original"] = 'Preserved   : cylinders {0}, not rewritten on the disk identical to the original'
$script:I18n[' (avec réserve : protection non reproductible)'] = ' (with reservation: non-reproducible protection)'
$script:I18n[" Attention : {0} piste(s) de l'original non reproductible(s) (zone instable, protection contre la copie probable) : la copie n'en a reçu qu'un tour figé et risque de ne pas fonctionner."] = ' Warning: {0} non-reproducible track(s) on the original (unstable zone, probable copy protection): the copy received a single frozen revolution of them and may not work.'
$script:I18n["{0} secteur(s) illisible(s), regroupés sur la ou les pistes {1} : c'est souvent une protection contre la copie (secteurs volontairement illisibles), qu'une copie secteur par secteur ne peut pas reproduire. Relancez avec « Copie exacte du flux »."] = '{0} unreadable sector(s), grouped on track(s) {1}: this is often a copy protection (deliberately unreadable sectors), which a sector-by-sector copy cannot reproduce. Restart with "Exact flux copy".'
$script:I18n["Image flux : {0} piste(s) changent d'un tour à l'autre ({1}) : bits faibles d'une protection contre la copie probable. gw n'en écrit que le premier tour : la protection risque de ne pas fonctionner sur la disquette écrite. Ces pistes ne sont pas réécrites par le contrôle."] = 'Flux image: {0} track(s) change from one revolution to the next ({1}): weak bits of a probable copy protection. gw writes only their first revolution: the protection may not work on the written disk. These tracks are not rewritten by the check.'
$script:I18n["L'image {0} contient {1} piste(s) dont le contenu change d'un tour à l'autre ({2}) : bits faibles d'une protection contre la copie probable.`n`ngw n'écrit que le premier tour de chaque piste : ces bits seront figés et la protection risque de ne pas fonctionner sur la disquette écrite.`n`nN'écrivez jamais cette image sur une disquette d'origine. Écrire quand même ?"] = "The image {0} contains {1} track(s) whose content changes from one revolution to the next ({2}): weak bits of a probable copy protection.`n`ngw writes only the first revolution of each track: these bits will be frozen and the protection may not work on the written disk.`n`nNever write this image on an original disk. Write anyway?"
$script:I18n['Protection contre la copie'] = 'Copy protection'
$script:I18n['Écriture annulée : image protégée non écrite.'] = 'Write cancelled: protected image not written.'
$script:I18n["Contrôle : {0} piste(s) non reproductible(s) ou déjà critique(s) dans la source, non comptée(s) : {1}"] = 'Check: {0} non-reproducible or already critical track(s) in the source, not counted: {1}'
$script:I18n["Calibration {0} de la famille {1} non convergée ({2}) : écriture avec cette courbe. Pour la refaire, bouton « Calibrer » de l'onglet Écriture, de préférence en test fin."] = 'Calibration {0} of the {1} family not converged ({2}): writing with this curve. To redo it, use the Write tab Calibrate button, preferably with the fine test.'
$script:I18n["Détection des lecteurs : recherche de la piste 0 sur {0} (gw seek : la tête se déplace, sans rotation ni écriture)."] = 'Drive detection: looking for track 0 on {0} (gw seek: the head moves, no spinning and no writing).'
$script:I18n["Aucun lecteur détecté : vérifiez l'alimentation du lecteur, la nappe et son sens, puis le type de nappe (A ou B : nappe PC avec twist ; 0 à 3 : nappe droite)."] = 'No drive detected: check the drive power supply, the cable and its orientation, then the cable type (A or B: PC cable with twist; 0 to 3: straight cable).'
$script:I18n["Lecteur(s) détecté(s) : {0}."] = 'Drive(s) detected: {0}.'
$script:I18n["Lecteur {0} sélectionné : le lecteur {1} ne répond pas."] = 'Drive {0} selected: drive {1} does not respond.'
$script:I18n["Lecteur {0} détecté."] = 'Drive {0} detected.'
$script:I18n['Vérifier que la carte répond (gw info), puis détecter les lecteurs branchés (A, B, 0 à 3).'] = 'Check that the board responds (gw info), then detect the connected drives (A, B, 0 to 3).'
$script:I18n["Écrire l'image"] = 'Write the image'
$script:I18n["Calibration terminée.`n`nRetirez la disquette sacrifiée du lecteur {0} et insérez la disquette à écrire, puis cliquez sur « Écrire l'image ».`nAnnuler : l'image n'est pas écrite."] = "Calibration complete.`n`nRemove the sacrificial disk from drive {0} and insert the disk to write, then click `"Write the image`".`nCancel: the image is not written."
$script:I18n["Sans réponse, l'écriture de l'image démarre automatiquement dans {0} s."] = 'Without an answer, the image write starts automatically in {0} s.'
$script:I18n["Calibration : remise de la disquette validée automatiquement après {0} s sans réponse."] = 'Calibration: disk swap confirmed automatically after {0} s without an answer.'
$script:I18n["Sans réponse, reprise automatique dans {0} s."] = 'Without an answer, automatic resume in {0} s.'
$script:I18n["reprise automatique après {0} s sans réponse : changement de disquette non confirmé"] = 'resumed automatically after {0} s without an answer: disk change not confirmed'
$script:I18n["Restauration : reprise automatique après {0} s sans réponse."] = 'Restore: resumed automatically after {0} s without an answer.'
$script:I18n['Régler le jitter'] = 'Adjust the jitter'
$script:I18n["Choisir le jitter maximal d'une piste saine : plus il est strict, plus l'écriture lente réécrit de pistes."] = 'Maximum jitter of a healthy track: the stricter it is, the more tracks the slow write rewrites.'
$script:I18n['Courbe de calibration'] = 'Calibration curve'
$script:I18n["Aucune calibration enregistrée.`n`nLa courbe apparaît après une première calibration : bouton « Calibrer » de l'onglet Écriture, ou première écriture depuis la Bibliothèque."] = "No calibration saved.`n`nThe curve appears after a first calibration: `"Calibrate`" button of the Write tab, or a first write from the Library."
$script:I18n['Réglage du jitter'] = 'Jitter setting'
$script:I18n["Le jitter mesure la dispersion des intervalles entre les transitions magnétiques d'une piste, en nanosecondes : plus il est faible, plus la piste est nette.`n`nCes seuils fixent l'état de chaque piste dans l'onglet « Qualité & alignement », dans le contrôle après écriture et dans la restauration. Une piste n'est SAINE que si son jitter est sous le premier seuil, et si ses erreurs, ses trous et sa stabilité sont bons. Au-delà du second seuil, elle est CRITIQUE.`n`nAprès une écriture avec contrôle de toutes les pistes (écriture lente, restauration), une piste qui n'est pas SAINE est réécrite, dans la limite des passes de réécriture : un réglage plus strict fait réécrire davantage de pistes, donc davantage d'écritures sur la disquette. Le jugement de la disquette d'origine en restauration et le garde-fou (plus de la moitié des pistes faibles : aucune réécriture) gardent les seuils Standard."] = "The jitter measures the spread of the intervals between the magnetic transitions of a track, in nanoseconds: the lower it is, the cleaner the track.`n`nThese thresholds set the state of each track in the `"Quality & alignment`" tab, in the check after writing and in the restore. A track is HEALTHY only if its jitter is below the first threshold, and if its errors, dropouts and stability are good. Above the second threshold, it is CRITICAL.`n`nAfter a write with all tracks checked (slow write, restore), a track that is not HEALTHY is rewritten, within the rewrite passes: a stricter setting rewrites more tracks, hence more writes on the disk. Judging the original disk during a restore and the safeguard (more than half of the tracks weak: no rewrite) keep the Standard thresholds."
$script:I18n['Préréglage :'] = 'Preset:'
$script:I18n['Standard (120 / 250 ns)'] = 'Standard (120 / 250 ns)'
$script:I18n['Strict (90 / 180 ns)'] = 'Strict (90 / 180 ns)'
$script:I18n['Très strict (70 / 140 ns)'] = 'Very strict (70 / 140 ns)'
$script:I18n['Personnalisé'] = 'Custom'
$script:I18n['SAIN si le jitter est inférieur à :'] = 'HEALTHY if the jitter is below:'
$script:I18n["À SURVEILLER s'il est inférieur à :"] = 'TO WATCH if it is below:'
$script:I18n['Au-delà : CRITIQUE. Les nouvelles valeurs valent pour les prochaines mesures.'] = 'Above: CRITICAL. The new values apply to the next measurements.'
$script:I18n['Valeurs par défaut'] = 'Default values'
$script:I18n["Le seuil À SURVEILLER doit dépasser le seuil SAIN d'au moins 10 ns."] = 'The TO WATCH threshold must exceed the HEALTHY threshold by at least 10 ns.'
$script:I18n["Opération en cours : modifiez le réglage du jitter une fois l'opération terminée."] = 'Operation in progress: change the jitter setting once the operation is finished.'
$script:I18n["Réglage du jitter : SAIN sous {0} ns, À SURVEILLER sous {1} ns, CRITIQUE au-delà (prochaines mesures)."] = 'Jitter setting: HEALTHY below {0} ns, TO WATCH below {1} ns, CRITICAL above (next measurements).'
$script:I18n["État par piste : SAIN / À SURVEILLER / CRITIQUE, d'après les erreurs, les trous, la stabilité et le jitter.`nJitter : SAIN sous {0} ns, À SURVEILLER sous {1} ns (onglet Accueil, « Régler le jitter »).`nCouleurs de la colonne Jitter : <{2} / <{0} / <{3} ns. Asymétrie : <0,02 / <0,05 / <0,10 (couleur et score seulement, sans effet sur l'état)."] = "Per-track status: HEALTHY / TO WATCH / CRITICAL, from errors, dropouts, stability and jitter.`nJitter: HEALTHY below {0} ns, TO WATCH below {1} ns (Home tab, `"Adjust the jitter`").`nJitter column colours: <{2} / <{0} / <{3} ns. Asymmetry: <0.02 / <0.05 / <0.10 (colour and score only, no effect on the status)."
$script:I18n['annulée par l''utilisateur'] = 'cancelled by the user'
$script:I18n['Dossier qui contient vos images disque (bouton à droite pour le choisir)'] = 'Folder that holds your disk images (button on the right to choose it)'
$script:I18n['Nom d''image à rechercher'] = 'Image name to search for'
$script:I18n['Image à écrire : ADF, IPF, SCP, HFE, IMG... (bouton à droite)'] = 'Image to write: ADF, IPF, SCP, HFE, IMG... (button on the right)'
$script:I18n['vide = toutes les pistes'] = 'empty = all tracks'
$script:I18n['vide = lecteur normal'] = 'empty = normal drive'
$script:I18n['vide = formats intégrés à gw'] = 'empty = formats built into gw'
$script:I18n['auto'] = 'auto'
$script:I18n['Fichier à créer : .scp pour archiver, .adf pour un émulateur'] = 'File to create: .scp to archive, .adf for an emulator'
$script:I18n['vide = toutes'] = 'empty = all'
$script:I18n['Fichier à convertir'] = 'File to convert'
$script:I18n['Fichier à créer (son extension fixe le type)'] = 'File to create (its extension sets the type)'
$script:I18n['Image de référence : ADF, IPF, SCP...'] = 'Reference image: ADF, IPF, SCP...'
$script:I18n["Fichier où enregistrer la disquette lue.`n.scp : flux exact, pour archiver (protections comprises).`n.adf, .img, .st : secteurs décodés, pour un émulateur (un format est alors nécessaire)."] = "File where the read disk is saved.`n.scp: exact flux, to archive (copy protections included).`n.adf, .img, .st: decoded sectors, for an emulator (a format is then required)."
$script:I18n["Format de la disquette. (auto) : flux sans décodage.`nAvec un format, gw vérifie chaque secteur et relit les pistes incomplètes (Essais)."] = "Disk format. (auto): flux without decoding.`nWith a format, gw checks every sector and re-reads incomplete tracks (Retries)."
$script:I18n['Nombre de relectures d''une piste dont des secteurs manquent (avec un format seulement).'] = 'Number of re-reads of a track with missing sectors (with a format only).'
$script:I18n['Pistes à lire, par exemple c=0-79:h=0-1. Vide : toutes les pistes du format.'] = 'Tracks to read, for example c=0-79:h=0-1. Empty: all tracks of the format.'
$script:I18n['Face B d''une disquette flippy (5,25" retournée) : le flux est lu à l''envers.'] = 'Side B of a flippy disk (flipped 5.25"): the flux is read in reverse.'
$script:I18n['Force le signal de densité du lecteur (H = haute, L = basse). (non) : laissé au lecteur.'] = 'Forces the drive density signal (H = high, L = low). (non): left to the drive.'
$script:I18n['Fichier de définitions de formats personnalisés. Vide : formats intégrés à gw.'] = 'File of custom format definitions. Empty: formats built into gw.'
$script:I18n['Lit la disquette insérée et enregistre le fichier.'] = 'Reads the inserted disk and saves the file.'
$script:I18n['Écrit l''image sur la disquette insérée avec les options de cet onglet. Tout le contenu de la disquette est remplacé.'] = 'Writes the image to the inserted disk with the options of this tab. All the content of the disk is replaced.'
$script:I18n['interrompue par l''utilisateur'] = 'interrupted by the user'
$script:I18n['Vider'] = 'Clear'
$script:I18n['Enregistrer'] = 'Save'
$script:I18n['Arrête la commande ou la séquence en cours.'] = 'Stops the current command or sequence.'
$script:I18n['Affiche ou masque le journal des commandes gw.'] = 'Shows or hides the log of gw commands.'
$script:I18n["erreur interne : {0}"] = 'internal error: {0}'
$script:I18n['calibration interrompue'] = 'calibration interrupted'
$script:I18n['calibration sans mesure exploitable'] = 'calibration without a usable measurement'
$script:I18n['l''écriture n''a pas démarré après la calibration, voir le journal'] = 'the write did not start after the calibration, see the log'
$script:I18n['contrôle des pistes indisponible'] = 'track check unavailable'
$script:I18n['contrôle interrompu par une erreur gw'] = 'check interrupted by a gw error'
$script:I18n['aucune piste mesurée'] = 'no track measured'
$script:I18n["{0} piste(s) faible(s) : {1}"] = '{0} weak track(s): {1}'
$script:I18n['erreur gw pendant le contrôle des pistes'] = 'gw error during the track check'
$script:I18n['contrôle des pistes interrompu'] = 'track check interrupted'
$script:I18n['Restaurations'] = 'Restorations'
$script:I18n['Une opération est déjà en cours : attendez sa fin ou cliquez sur « Arrêter ».'] = 'An operation is already running: wait for it to finish or click "Stop".'
$script:I18n["Restauration impossible : le module d'analyse de flux n'a pas pu être compilé, le contrôle strict des pistes n'est donc pas disponible."] = 'Restore impossible: the flux analysis module could not be compiled, so the strict track check is not available.'
$script:I18n['Restauration non prise en charge avec « Secteurs durs » ou « TG43 » cochés dans les options avancées de l''onglet Écriture : le contrôle des pistes est calibré pour le MFM double densité.'] = 'Restore not supported with "Hard sectors" or "TG43" checked in the advanced options of the Write tab: the track check is calibrated for double-density MFM.'
$script:I18n["Dossier de sauvegarde inaccessible : {0}"] = 'Backup folder not accessible: {0}'
$script:I18n['disquette'] = 'disk'
$script:I18n['original'] = 'original'
$script:I18n["secteur par secteur, format {0}"] = 'sector by sector, format {0}'
$script:I18n['copie exacte du flux, sans précompensation ni comparaison par secteur'] = 'exact flux copy, without precompensation or sector comparison'
$script:I18n["Le lecteur {0} lit l'original, puis vous changez de disquette quand l'application vous le demande."] = 'Drive {0} reads the original, then you swap disks when the application asks.'
$script:I18n["Le lecteur {0} lit l'original et le lecteur {1} écrit la copie."] = 'Drive {0} reads the original and drive {1} writes the copy.'
$script:I18n["Restauration ({0}).`n`n{1}`n`n1. Insérez maintenant la disquette d'ORIGINE dans le lecteur {2}, de préférence protégée en écriture.`n2. Sa lecture est enregistrée dans :`n   {3}`n3. La disquette de destination sera entièrement effacée puis écrite.`n`nCommencer la lecture ?"] = "Restore ({0}).`n`n{1}`n`n1. Insert the ORIGINAL disk in drive {2} now, preferably write-protected.`n2. Its read is saved in:`n   {3}`n3. The destination disk will be fully erased, then written.`n`nStart reading?"
$script:I18n['copie relue'] = 'copy read back'
$script:I18n['rapport'] = 'report'
$script:I18n["=== RESTAURATION : {0} ({1}) ==="] = '=== RESTORE: {0} ({1}) ==='
$script:I18n["Original : lecteur {0} -> {1}"] = 'Original: drive {0} -> {1}'
$script:I18n["Copie    : lecteur {0}"] = 'Copy    : drive {0}'
$script:I18n['la lecture n''a produit aucun fichier (disquette absente ou lecteur incorrect ?)'] = 'the read produced no file (no disk, or wrong drive?)'
$script:I18n['gw n''a imprimé aucun bilan de secteurs : format incorrect, ou disquette illisible ?'] = 'gw printed no sector summary: wrong format, or unreadable disk?'
$script:I18n["{0} secteur(s) illisible(s) sur l'original (pistes {1}) : une copie fidèle est impossible. Nettoyez les têtes du lecteur et relancez, ou choisissez « Copie exacte du flux » si la disquette est protégée contre la copie."] = '{0} unreadable sector(s) on the original (tracks {1}): a faithful copy is impossible. Clean the drive heads and try again, or choose "Exact flux copy" if the disk is copy-protected.'
$script:I18n["{0}/{1} secteurs lus"] = '{0}/{1} sectors read'
$script:I18n["Restauration : original lu en entier, {0}/{1} secteurs."] = 'Restore: original fully read, {0}/{1} sectors.'
$script:I18n["flux illisible : {0}"] = 'unreadable flux: {0}'
$script:I18n['aucune piste dans le flux lu.'] = 'no track in the flux read.'
$script:I18n["{0} pistes : {1} saines, {2} à surveiller, {3} critiques"] = '{0} tracks: {1} healthy, {2} to watch, {3} critical'
$script:I18n["Restauration : flux de l'original, {0}."] = 'Restore: flux of the original, {0}.'
$script:I18n["Retirez l'ORIGINAL du lecteur {0} et rangez-le. Insérez la disquette de DESTINATION : tout son contenu sera remplacé."] = 'Remove the ORIGINAL from drive {0} and put it away. Insert the DESTINATION disk: all its content will be replaced.'
$script:I18n["Vérifiez que la disquette de DESTINATION est dans le lecteur {0} : tout son contenu sera remplacé."] = 'Check that the DESTINATION disk is in drive {0}: all its content will be replaced.'
$script:I18n["{0} piste(s) critique(s) dans la lecture : normal pour une protection, sinon nettoyez le lecteur et relancez."] = '{0} critical track(s) in the read: normal for a copy protection, otherwise clean the drive and try again.'
$script:I18n['Puis cliquez sur « Continuer ».'] = 'Then click "Continue".'
$script:I18n["Restauration : en attente de la disquette de destination dans le lecteur {0}."] = 'Restore: waiting for the destination disk in drive {0}.'
$script:I18n['Une commande gw est encore en cours : attendez sa fin.'] = 'A gw command is still running: wait for it to finish.'
$script:I18n['contrôle ignoré à votre demande'] = 'check skipped at your request'
$script:I18n['non applicable à une copie de flux'] = 'not applicable to a flux copy'
$script:I18n['Aucune disquette lisible n''a été détectée dans le lecteur de destination.'] = 'No readable disk was detected in the destination drive.'
$script:I18n['la disquette insérée semble être l''original'] = 'the inserted disk seems to be the original'
$script:I18n['Restauration : la disquette de destination contient les mêmes données que l''original sur le cylindre 0. Écriture refusée.'] = 'Restore: the destination disk holds the same data as the original on cylinder 0. Write refused.'
$script:I18n["ATTENTION : la disquette insérée a le même contenu que l'original sur le cylindre 0, c'est probablement l'ORIGINAL. Changez de disquette. S'il s'agit bien d'une copie à remplacer, cliquez sur « Écraser quand même »."] = 'WARNING: the inserted disk has the same content as the original on cylinder 0, it is probably the ORIGINAL. Swap disks. If it really is a copy to replace, click "Overwrite anyway".'
$script:I18n['ce n''est pas l''original'] = 'not the original'
$script:I18n['aucune calibration existante'] = 'no existing calibration'
$script:I18n['commune aux deux têtes'] = 'common to both heads'
$script:I18n['mesurée sur le contenu d''une image, avant le motif de test'] = 'measured on an image''s content, before the test pattern'
$script:I18n["mesurée sur le lecteur {0}"] = 'measured on drive {0}'
$script:I18n['non convergée'] = 'not converged'
$script:I18n["Restauration : calibration existante utilisée ({0}), le lecteur n'est pas recalibré."] = 'Restore: existing calibration used ({0}), the drive is not recalibrated.'
$script:I18n["Remarque sur cette calibration : {0}. Pour la refaire, lancez « Calibrer » dans l'onglet Écriture, « Écriture lente » cochée, avant la restauration."] = 'Note about this calibration: {0}. To redo it, run "Calibrate" in the Write tab, with "Slow write" ticked, before the restore.'
$script:I18n["calibration existante ({0}), pas de recalibration"] = 'existing calibration ({0}), no recalibration'
$script:I18n['Restauration : calibration terminée sur la disquette sacrifiée.'] = 'Restore: calibration complete on the sacrificial disk.'
$script:I18n["Calibration terminée. Retirez la disquette sacrifiée du lecteur {0} et insérez la disquette de DESTINATION : tout son contenu sera remplacé. Elle sera de nouveau vérifiée avant l'écriture."] = 'Calibration complete. Remove the sacrificial disk from drive {0} and insert the DESTINATION disk: all its content will be replaced. It will be checked again before writing.'
$script:I18n["faite ({0})"] = 'done ({0})'
$script:I18n["faite sur une disquette sacrifiée ({0})"] = 'done on a sacrificial disk ({0})'
$script:I18n["Restauration : calibration par tête en test fin ({0})."] = 'Restore: per-head calibration with the fine test ({0}).'
$script:I18n["Restauration : écriture tête par tête, {0} essais par piste, contrôle de toutes les pistes ({1} passes au plus)."] = 'Restore: head-by-head write, {0} retries per track, check of all tracks (up to {1} passes).'
$script:I18n["non applicable : {0}"] = 'not applicable: {0}'
$script:I18n['l''écriture n''a pas démarré (calibration refusée ou annulée ? voir le journal)'] = 'the write did not start (calibration refused or cancelled? see the log)'
$script:I18n['faite, non convergée sur une tête : voir le journal'] = 'done, not converged on one head: see the log'
$script:I18n['séquence arrêtée sans suite, voir le journal'] = 'sequence stopped without continuation, see the log'
$script:I18n['non applicable à ce format'] = 'not applicable to this format'
$script:I18n['relecture de la copie impossible'] = 'cannot read the copy back'
$script:I18n["identique, {0} secteurs"] = 'identical, {0} sectors'
$script:I18n["Restauration : copie IDENTIQUE à l'original, {0} secteurs relus du premier coup."] = 'Restore: copy IDENTICAL to the original, {0} sectors read back at the first attempt.'
$script:I18n["{0} secteur(s) différent(s) sur {1}, dont {2} non relu(s) du premier coup ; pistes {3}"] = '{0} sector(s) differ out of {1}, of which {2} not read back at the first attempt; tracks {3}'
$script:I18n["{0} secteur(s) différent(s)"] = '{0} sector(s) differ'
$script:I18n["Restauration : copie DIFFÉRENTE de l'original : {0}."] = 'Restore: copy DIFFERENT from the original: {0}.'
$script:I18n["Greaseweazle Studio v{0} - rapport de restauration"] = 'Greaseweazle Studio v{0} - restore report'
$script:I18n["Date        : {0}, durée {1} min"] = 'Date        : {0}, duration {1} min'
$script:I18n["Disquette   : {0}"] = 'Disk        : {0}'
$script:I18n["Mode        : {0}"] = 'Mode        : {0}'
$script:I18n['copie exacte du flux'] = 'exact flux copy'
$script:I18n["Lecteurs    : origine {0}, destination {1}"] = 'Drives      : original {0}, destination {1}'
$script:I18n["Original lu : {0}"] = 'Original    : {0}'
$script:I18n["Copie relue : {0}"] = 'Read-back   : {0}'
$script:I18n["Règles      : lecture {0} tours, {1} essais x {2} séries ; écriture tête par tête, calibration existante conservée (calibration par tête en test fin si aucune n'existe), pré-effacement, vérification gw, {3} essais par piste ; contrôle de toutes les pistes, {4} passes de réécriture au plus ; relecture finale sans nouvel essai."] = 'Rules       : read {0} revolutions, {1} retries x {2} series; head-by-head write, existing calibration kept (per-head calibration with the fine test if none exists), pre-erase, gw verification, {3} retries per track; check of all tracks, up to {4} rewrite passes; final read-back without retry.'
$script:I18n['Étapes :'] = 'Steps:'
$script:I18n["Verdict     : {0}"] = 'Verdict     : {0}'
$script:I18n["Rapport     : {0}"] = 'Report      : {0}'
$script:I18n["Rapport non enregistré : {0}"] = 'Report not saved: {0}'
$script:I18n['comparaison non faite'] = 'comparison not done'
$script:I18n['RESTAURATION RÉUSSIE'] = 'RESTORE SUCCEEDED'
$script:I18n['La copie a été écrite tête par tête, toutes ses pistes sont saines et elle est identique à l''original, secteur par secteur.'] = 'The copy was written head by head, all its tracks are healthy and it is identical to the original, sector by sector.'
$script:I18n['Le flux a été recopié et toutes les pistes de la copie sont saines. Sans format, la copie n''est pas comparée secteur par secteur : essayez-la sur la machine d''origine.'] = 'The flux was copied and all tracks of the copy are healthy. Without a format, the copy is not compared sector by sector: try it on the original machine.'
$script:I18n['RESTAURATION ÉCHOUÉE'] = 'RESTORE FAILED'
$script:I18n['Essayez une autre disquette de destination ; si le problème persiste, nettoyez les têtes du lecteur. Le détail est dans le rapport.'] = 'Try another destination disk; if the problem persists, clean the drive heads. The details are in the report.'
$script:I18n['Rien n''a été écrit : la disquette de destination n''a pas été touchée.'] = 'Nothing was written: the destination disk was not touched.'
$script:I18n['Le détail est dans le journal et dans le rapport.'] = 'The details are in the log and in the report.'
$script:I18n['gw n''a pas pu être lancé'] = 'gw could not be started'
$script:I18n['opération gw incomplète : disquette protégée en écriture, absente, ou lecteur en défaut ? Voir le journal'] = 'incomplete gw operation: write-protected or missing disk, or faulty drive? See the log'
$script:I18n["gw a retourné le code {0}, voir le journal"] = 'gw returned code {0}, see the log'
$script:I18n["Une restauration est en cours. Quitter quand même ? La disquette de destination restera incomplète."] = 'A restore is running. Quit anyway? The destination disk will remain incomplete.'
$script:I18n['Conseil : protégez-la en écriture avant de commencer.'] = 'Tip: write-protect it before you start.'
$script:I18n['Disquette 3,5" : fenêtre de protection ouverte. 5,25" : encoche couverte. Ainsi, même une erreur de manipulation ne peut pas l''effacer.'] = '3.5" disk: protection window open. 5.25" disk: notch covered. This way, even a handling mistake cannot erase it.'
$script:I18n['Vierge ou à sacrifier : tout son contenu sera remplacé.'] = 'Blank or expendable: all its content will be replaced.'
$script:I18n["Règles appliquées à la copie : écriture tête par tête avec la calibration existante du lecteur (calibration par tête si aucune n'existe), pré-effacement, vérification par gw, {0} essais par piste, contrôle de toutes les pistes ({1} passes de réécriture au plus), puis relecture et comparaison avec l'original."] = 'Rules applied to the copy: head-by-head write with the existing drive calibration (per-head calibration if none exists), pre-erase, gw verification, {0} retries per track, check of all tracks (up to {1} rewrite passes), then read-back and comparison with the original.'
$script:I18n['commande gw'] = 'gw command'
$script:I18n['calibration'] = 'calibration'
$script:I18n['contrôle après écriture'] = 'post-write check'
$script:I18n['séquence d''étapes'] = 'step sequence'
$script:I18n["Restauration refusée : opération en cours ({0})."] = 'Restore refused: operation in progress ({0}).'
$script:I18n['Restauration : changez de disquette, puis cliquez sur « Continuer » dans l''onglet Restauration.'] = 'Restore: swap disks, then click "Continue" in the Restore tab.'
$script:I18n['Lecture : flux avec un format, sans « Flux brut » : gw enregistre un flux reconstitué à partir des secteurs décodés ; les pistes protégées ou illisibles ne sont pas conservées telles quelles. Cochez « Flux brut (--raw) » pour garder le flux réel.'] = 'Read: flux with a format, without "Raw flux": gw saves a flux rebuilt from the decoded sectors; protected or unreadable tracks are not kept as they are. Check "Raw flux (--raw)" to keep the real flux.'
$script:I18n["Enregistre le flux réel du disque ; avec un format, celui-ci sert alors au contrôle des secteurs et aux relectures.`nSans cette case, un .scp lu avec un format contient un flux reconstitué à partir des secteurs décodés.`nAvec des essais, les tours relus sont ajoutés après les premiers, mais la plupart des logiciels ne lisent que les premiers tours."] = "Saves the real flux of the disk; with a format, the format is then used to check the sectors and for re-reads.`nWithout this box, a .scp read with a format holds a flux rebuilt from the decoded sectors.`nWith retries, the re-read revolutions are appended after the first ones, but most software only reads the first revolutions."
$script:I18n['flux haute densité : une copie de flux ne pourrait pas être contrôlée. Choisissez un format haute densité (amiga.amigados_hd, ibm.1440) pour une copie vérifiée secteur par secteur.'] = 'high-density flux: a flux copy could not be checked. Choose a high-density format (amiga.amigados_hd, ibm.1440) for a copy verified sector by sector.'
$script:I18n["lecture sans données exploitables : {0} piste(s) critique(s) sur {1}. Disquette vierge, lecteurs inversés ou têtes sales ?"] = 'read without usable data: {0} critical track(s) out of {1}. Blank disk, swapped drives or dirty heads?'
$script:I18n["Copie de flux : l'application ne peut pas vérifier que la disquette insérée n'est pas l'original.`n`nAvez-vous bien retiré l'ORIGINAL et inséré la disquette de DESTINATION ?"] = "Flux copy: the application cannot check that the inserted disk is not the original.`n`nDid you remove the ORIGINAL and insert the DESTINATION disk?"
$script:I18n['La copie a été écrite tête par tête et elle est identique à l''original, secteur par secteur. Le contrôle des pistes ne s''applique pas à ce format (haute densité).'] = 'The copy was written head by head and it is identical to the original, sector by sector. The track check does not apply to this format (high density).'
$script:I18n['fenêtre fermée pendant la restauration'] = 'window closed during the restore'
$script:I18n['Test rapide : niveau par disquette'] = 'Quick test: level per disk'
$script:I18n["Test standard (un cylindre sur 10) ou test fin (tous les cylindres) : calibration complète, qui mesure la courbe de précompensation du lecteur ; elle est faite une fois, puis réutilisée.`nTest rapide : la forme de la courbe vient de la dernière calibration complète du lecteur (la référence). Avant chaque écriture depuis la Bibliothèque ou une restauration, et avec « Calibrer », seul son niveau est mesuré sur la disquette insérée : 4 à 9 cylindres par tête, 1 à 3 écritures du motif par piste. Sans référence utilisable, une calibration complète en test fin est faite d'abord ; elle devient la référence."] = "Standard test (one cylinder in 10) or fine test (every cylinder): full calibration, which measures the precompensation curve of the drive; it is done once, then reused.`nQuick test: the shape of the curve comes from the last full calibration of the drive (the reference). Before each write from the Library or a restore, and with `"Calibrate`", only its level is measured on the inserted disk: 4 to 9 cylinders per head, 1 to 3 writes of the pattern per track. Without a usable reference, a full fine-test calibration is done first; it becomes the reference."
$script:I18n['Test rapide : mesure seulement le niveau de la disquette insérée, sur la forme de la dernière calibration complète du lecteur ; le profil obtenu est placé dans les champs --precomp, pour cette disquette.'] = 'Quick test: only measures the level of the inserted disk, on the shape of the last full calibration of the drive; the resulting profile is placed in the --precomp fields, for this disk.'
$script:I18n['témoin de marche'] = 'step witness'
$script:I18n['témoin du plafond'] = 'ceiling witness'
$script:I18n['conforme'] = 'consistent'
$script:I18n['approximative'] = 'approximate'
$script:I18n['NON CONFORME'] = 'INCONSISTENT'
$script:I18n["Dernière calibration rapide ({0}, lecteur {1}) : niveau {2} ns ± {3} ; écart de forme {4} ns ; forme {5} ; {6} passe(s) ; profil appliqué : {7}"] = 'Last quick calibration ({0}, drive {1}): level {2} ns ± {3}; shape deviation {4} ns; shape {5}; {6} pass(es); applied profile: {7}'
$script:I18n["  c{0,-3} zéro {1,6:0.0} ± {2,4:0.0}  écart à la forme {3,6:+0.0;-0.0;0.0}  {4}"] = '  c{0,-3} zero {1,6:0.0} ± {2,4:0.0}  deviation from shape {3,6:+0.0;-0.0;0.0}  {4}'
$script:I18n["Niveaux mesurés avec cette référence : médiane {0} ns, de {1} à {2} ns, {3} disquette(s)."] = 'Levels measured with this reference: median {0} ns, from {1} to {2} ns, {3} disk(s).'
$script:I18n['FORME NON CONFORME'] = 'SHAPE INCONSISTENT'
$script:I18n['courbe décalée (dernière disquette)'] = 'shifted curve (last disk)'
$script:I18n['mesure du niveau'] = 'level measurement'
$script:I18n["niveau de la dernière disquette : {0} ns ± {1}, forme {2} ({3})"] = 'level of the last disk: {0} ns ± {1}, shape {2} ({3})'
$script:I18n["tête {0} : niveau {1} ns ± {2}, forme {3} ({4})"] = 'head {0}: level {1} ns ± {2}, shape {3} ({4})'
$script:I18n["aucune calibration commune pour la famille {0}"] = 'no common calibration for the {0} family'
$script:I18n["aucune calibration par tête à jour pour la famille {0}"] = 'no up-to-date per-head calibration for the {0} family'
$script:I18n['référence mesurée sur le contenu d''une image, avant le motif de test'] = 'reference measured on the content of an image, before the test pattern'
$script:I18n["référence mesurée sur le lecteur {0}, et non {1}"] = 'reference measured on drive {0}, not {1}'
$script:I18n['référence antérieure à la calibration rapide (pente ou densité non enregistrée)'] = 'reference older than the quick calibration (slope or density not recorded)'
$script:I18n["image de {0} cylindres, référence de {1}"] = 'image of {0} cylinders, reference of {1}'
$script:I18n["densité de l'image différente de celle de la référence de {0} % (5 % au plus)"] = 'image density differs from the reference density by {0} % (5 % at most)'
$script:I18n["Densité de l'image différente de celle de la référence de {0} %."] = 'Image density differs from the reference density by {0} %.'
$script:I18n["trop peu de cylindres de mesure fiables dans la référence ({0}, {1} au moins)"] = 'too few reliable measurement cylinders in the reference ({0}, at least {1})'
$script:I18n['Référence non convergée : ses cylindres hors tolérance sont exclus de la mesure ; une calibration complète en test fin est conseillée.'] = 'Reference not converged: its out-of-tolerance cylinders are excluded from the measurement; a full fine-test calibration is recommended.'
$script:I18n['Référence en test standard : entre les cylindres mesurés, la forme est interpolée ; une référence en test fin est conseillée.'] = 'Standard-test reference: between the measured cylinders, the shape is interpolated; a fine-test reference is recommended.'
$script:I18n["écarts dispersés ({0} cylindres hors de la forme)"] = 'scattered deviations ({0} cylinders off the shape)'
$script:I18n["écart de forme {0} ns"] = 'shape deviation {0} ns'
$script:I18n["le niveau varie avec le cylindre ({0} ns de c{1} à c{2})"] = 'the level varies with the cylinder ({0} ns from c{1} to c{2})'
$script:I18n["la marche de c{0} n'a pas la même hauteur ({1} ns d'écart de part et d'autre)"] = 'the step at c{0} does not have the same height ({1} ns difference on either side)'
$script:I18n["marche déplacée ou absente entre c{0} et c{1} (autre lecteur sous la même lettre ?)"] = 'step moved or missing between c{0} and c{1} (another drive under the same letter?)'
$script:I18n["tête {0} : {1}"] = 'head {0}: {1}'
$script:I18n['test fin'] = 'fine test'
$script:I18n['test standard'] = 'standard test'
$script:I18n["Calibration rapide avant l'écriture : {0} reçoit le motif de test sur ces seuls cylindres, au plus 3 fois, puis l'image."] = 'Quick calibration before writing: {0} receives the test pattern on these cylinders only, at most 3 times, then the image.'
$script:I18n["Calibration rapide de la précompensation sur le lecteur {0} : seul le niveau de la courbe est mesuré, sur la disquette insérée.`n`nRéférence : calibration complète du {1} ({2}), dont la forme est reprise telle quelle.`nImage : {3}, famille {4}.`nCylindres mesurés : {5} (2 faces), ÉCRASÉS à chaque passe ; 1 à 3 passes, 2 en général. Durée estimée : {6} min."] = "Quick precompensation calibration on drive {0}: only the level of the curve is measured, on the inserted disk.`n`nReference: full calibration of {1} ({2}), whose shape is reused as is.`nImage: {3}, {4} family.`nMeasured cylinders: {5} (2 sides), OVERWRITTEN on every pass; 1 to 3 passes, usually 2. Estimated duration: {6} min."
$script:I18n["Le niveau dépend du support : il doit être mesuré sur la disquette qui recevra l'image. N'insérez pas de disquette sacrifiée. Une calibration complète écrit le motif 4 à 8 fois sur ses cylindres de test ; la calibration rapide, 3 fois au plus."] = 'The level depends on the media: it must be measured on the disk that will receive the image. Do not insert a sacrificial disk. A full calibration writes the pattern 4 to 8 times on its test cylinders; the quick calibration, 3 times at most.'
$script:I18n["Aucune image n'est écrite. Insérez la disquette que vous allez écrire : le profil obtenu est placé dans les champs --precomp et ne vaut que pour elle."] = 'No image is written. Insert the disk you are going to write: the resulting profile is placed in the --precomp fields and only applies to it.'
$script:I18n['forme commune, niveau mesuré par tête'] = 'common shape, level measured per head'
$script:I18n['une courbe par tête'] = 'one curve per head'
$script:I18n['courbe commune'] = 'common curve'
$script:I18n["=== Calibration rapide : lecteur {0}, image {1} ({2}, {3}) ==="] = '=== Quick calibration: drive {0}, image {1} ({2}, {3}) ==='
$script:I18n["{0}Référence de forme : calibration complète ({1}) du {2}, lecteur {3} ; cylindres de niveau : {4}."] = '{0}Shape reference: full calibration ({1}) of {2}, drive {3}; level cylinders: {4}.'
$script:I18n["{0}Témoins de marche : c{1} et c{2} (contrôle de la forme, hors calcul du niveau)."] = '{0}Step witnesses: c{1} and c{2} (shape check, not used for the level).'
$script:I18n["{0}Témoin du plafond : c{1} (référence au plafond de {3} ns de son calcul, de c{2} à c{1})."] = '{0}Ceiling witness: c{1} (reference at the {3} ns ceiling of its calculation, from c{2} to c{1}).'
$script:I18n["{0}Niveau de départ : {1} ns (médiane de la référence et des {2} derniers niveaux mesurés avec elle)."] = '{0}Starting level: {1} ns (median of the reference and of the last {2} levels measured with it).'
$script:I18n['Cylindres de niveau choisis parmi les cylindres mesurés et vérifiés de la référence ; exclus : cylindres 0 et 1, changements de sens et leurs voisins, pentes raides, valeurs hors de 20 à 260 ns, points isolés ou hors tolérance.'] = 'Level cylinders chosen among the measured and verified cylinders of the reference; excluded: cylinders 0 and 1, direction changes and their neighbours, steep slopes, values outside 20 to 260 ns, isolated or out-of-tolerance points.'
$script:I18n["Niveau estimé : {0} ns ± {1} ({2} cylindres ; écarts à la forme de {3} à {4} ns ; écart de forme {5} ns)."] = 'Estimated level: {0} ns ± {1} ({2} cylinders; deviations from the shape from {3} to {4} ns; shape deviation {5} ns).'
$script:I18n["Niveau vérifié à la passe {0} : décalage résiduel moyen {1} ns (tolérance {2}) : niveau retenu {3} ns."] = 'Level verified at pass {0}: mean residual shift {1} ns (tolerance {2}): level kept {3} ns.'
$script:I18n["Niveau non vérifié après {0} passes (décalage résiduel moyen {1} ns, tolérance {2}) : niveau estimé {3} ns retenu."] = 'Level not verified after {0} passes (mean residual shift {1} ns, tolerance {2}): estimated level {3} ns kept.'
$script:I18n["Niveau hors tolérance (décalage résiduel moyen {0} ns, tolérance {1}) : passe suivante à {2} ns."] = 'Level out of tolerance (mean residual shift {0} ns, tolerance {1}): next pass at {2} ns.'
$script:I18n["tête {0} {1}"] = 'head {0} {1}'
$script:I18n["{0}Calibration rapide : moins de 3 cylindres mesurables, niveau impossible à estimer."] = '{0}Quick calibration: fewer than 3 measurable cylinders, the level cannot be estimated.'
$script:I18n['Calibration rapide sans mesure exploitable.'] = 'Quick calibration without a usable measurement.'
$script:I18n['Écriture annulée : calibration rapide sans mesure exploitable.'] = 'Write cancelled: quick calibration without a usable measurement.'
$script:I18n['calibration rapide sans mesure exploitable'] = 'quick calibration without a usable measurement'
$script:I18n["Écart isolé à c{0} ({1} ns par rapport à la forme) : défaut ponctuel probable de cette disquette, écarté du niveau."] = 'Isolated deviation at c{0} ({1} ns from the shape): probably a local defect of this disk, left out of the level.'
$script:I18n["Forme conforme à la référence (écart de forme {0} ns)."] = 'Shape consistent with the reference (shape deviation {0} ns).'
$script:I18n["Forme approximative (écart de forme {0} ns) : courbe décalée appliquée ; une calibration complète de cette disquette serait plus précise."] = 'Approximate shape (shape deviation {0} ns): shifted curve applied; a full calibration of this disk would be more accurate.'
$script:I18n["Forme non conforme à la référence : {0}."] = 'Shape inconsistent with the reference: {0}.'
$script:I18n["forme non conforme à la référence : {0}"] = 'shape inconsistent with the reference: {0}'
$script:I18n['besoin au-delà de {0} ns sur la plupart des cylindres mesurés (support fatigué ?)'] = 'need above {0} ns on most measured cylinders (worn media?)'
$script:I18n["Plafond de {0} ns atteint aux cylindres {1} avec le niveau de cette disquette ({2} ns par rapport à la référence) : support probablement fatigué, ces cylindres resteront sous-compensés."] = '{0} ns ceiling reached at cylinders {1} with the level of this disk ({2} ns from the reference): media probably worn, these cylinders will remain under-compensated.'
$script:I18n["Précompensation nulle encore excessive aux cylindres {0} avec le niveau de cette disquette : ces cylindres resteront sur-compensés."] = 'Zero precompensation still excessive at cylinders {0} with the level of this disk: these cylinders will remain over-compensated.'
$script:I18n["Zone plafonnée de la référence (c{0} à c{1}) : besoin mesuré au témoin c{1} : {2} ns ; zone interpolée jusqu'à cette valeur."] = 'Capped zone of the reference (c{0} to c{1}): need measured at witness c{1}: {2} ns; zone interpolated up to this value.'
$script:I18n["Zone plafonnée de la référence (c{0} à c{1}) : le besoin dépasse encore {2} ns au témoin c{1} ; zone portée jusqu'à {2} ns."] = 'Capped zone of the reference (c{0} to c{1}): the need still exceeds {2} ns at witness c{1}; zone raised up to {2} ns.'
$script:I18n["Cette disquette demande {0} ns de plus que la médiane des {1} dernières disquettes mesurées avec cette référence : support probablement fatigué, l'écriture y sera moins sûre."] = 'This disk needs {0} ns more than the median of the last {1} disks measured with this reference: media probably worn, writing to it will be less reliable.'
$script:I18n["Les {0} dernières disquettes s'écartent toutes de la référence dans le même sens (de {1} à {2} ns) : la référence a peut-être été mesurée sur une disquette atypique. Une nouvelle calibration complète en test fin, sur une disquette sacrifiée en bon état, est conseillée."] = 'The last {0} disks all deviate from the reference in the same direction (from {1} to {2} ns): the reference may have been measured on an atypical disk. A new full fine-test calibration, on a sacrificial disk in good condition, is recommended.'
$script:I18n["Calibration rapide terminée en {0} : niveau {1}, forme {2}."] = 'Quick calibration finished in {0}: level {1}, shape {2}.'
$script:I18n["Profil {0} de cette disquette (calibration rapide du {1}, lecteur {2}) : référence du {3} décalée de {4}. À n'utiliser que pour cette disquette (bouton Courbe)."] = '{0} profile of this disk (quick calibration of {1}, drive {2}): reference of {3} shifted by {4}. Only use it for this disk (Curve button).'
$script:I18n["Calibration rapide terminée en {0} : {1} passe(s), {2} écritures de piste sur {3} cylindres (2 faces), aucune ailleurs."] = 'Quick calibration finished in {0}: {1} pass(es), {2} track writes on {3} cylinders (2 sides), none elsewhere.'
$script:I18n["Niveau retenu : {0}."] = 'Level kept: {0}.'
$script:I18n["{0}Profil {1} de cette disquette : {2}"] = '{0}{1} profile of this disk: {2}'
$script:I18n["niveau mesuré sur la destination : {0} ({1} passe(s))"] = 'level measured on the destination: {0} ({1} pass(es))'
$script:I18n["forme {0}"] = 'shape {0}'
$script:I18n['Calibration rapide terminée : écriture de l''image avec le niveau mesuré.'] = 'Quick calibration finished: writing the image with the measured level.'
$script:I18n["Calibration complète demandée après la calibration rapide ({0})."] = 'Full calibration requested after the quick calibration ({0}).'
$script:I18n["La calibration rapide ne convient pas à cette disquette ({0}).`nCalibration complète en test fin ci-dessous : elle devient la nouvelle référence de forme du lecteur {1}. Annuler : rien de plus n'est écrit ; le profil décalé reste dans les champs --precomp."] = "The quick calibration does not suit this disk ({0}).`nFull fine-test calibration below: it becomes the new shape reference of drive {1}. Cancel: nothing more is written; the shifted profile stays in the --precomp fields."
$script:I18n['Écriture annulée : la calibration rapide n''a pas été lancée.'] = 'Write cancelled: the quick calibration was not started.'
$script:I18n["Restauration : niveau non mesuré ({0}) : écriture avec la calibration existante."] = 'Restore: level not measured ({0}): writing with the existing calibration.'
$script:I18n["Calibration rapide non applicable à cette image : {0}. Écriture avec la courbe du lecteur, sans mesure du niveau."] = 'Quick calibration not applicable to this image: {0}. Writing with the drive curve, without measuring the level.'
$script:I18n["Calibration rapide impossible : {0}. Calibration complète en test fin d'abord : elle devient la référence de forme du lecteur."] = 'Quick calibration impossible: {0}. Full fine-test calibration first: it becomes the shape reference of the drive.'
$script:I18n["Calibration rapide impossible : {0}.`nCalibration complète en test fin ci-dessous : elle devient la référence de forme du lecteur {1}, reprise ensuite par la calibration rapide de chaque disquette. Une disquette sacrifiée en bon état, du même type que la disquette à écrire, donne la meilleure référence."] = "Quick calibration impossible: {0}.`nFull fine-test calibration below: it becomes the shape reference of drive {1}, then reused by the quick calibration of each disk. A sacrificial disk in good condition, of the same type as the disk to be written, gives the best reference."
$script:I18n["Calibration rapide non applicable à cette image : {0}."] = 'Quick calibration not applicable to this image: {0}.'
$script:I18n["Calibration rapide impossible : {0}.`n`nLa calibration rapide reprend la forme d'une calibration complète de ce lecteur. Lancer maintenant une calibration complète en test fin ? Elle devient la référence de forme du lecteur."] = "Quick calibration impossible: {0}.`n`nThe quick calibration reuses the shape of a full calibration of this drive. Start a full fine-test calibration now? It becomes the shape reference of the drive."
$script:I18n["Calibration rapide : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})"] = 'Quick calibration: {4} %, about {5} left (pass {0}/{1}, {2}, {3})'
$script:I18n["niveau {0} ns"] = 'level {0} ns'
$script:I18n["tête {0} {1} ns"] = 'head {0} {1} ns'
$script:I18n["Calibration rapide : passe {0}/{1}, {2}"] = 'Quick calibration: pass {0}/{1}, {2}'
$script:I18n["Forme comparée à la calibration précédente du lecteur {0} ({1}), sur {2} cylindres mesurés par les deux : niveau {3} ns, écart de forme {4} ns (au plus {5} ns, à c{6})."] = 'Shape compared with the previous calibration of drive {0} ({1}), on {2} cylinders measured by both: level {3} ns, shape deviation {4} ns (at most {5} ns, at c{6}).'
$script:I18n["Nouvelle référence de forme ({0}) : les niveaux mesurés avec la précédente sont abandonnés."] = 'New shape reference ({0}): the levels measured with the previous one are dropped.'
$script:I18n["Calibration terminée : elle devient la référence de forme du lecteur {0}.`n`nRetirez la disquette sacrifiée et insérez la disquette à écrire, puis cliquez sur « Mesurer le niveau et écrire » : son niveau de précompensation est mesuré sur les cylindres {1} (2 faces, 1 à 3 écritures du motif par piste), puis l'image est écrite.`nAnnuler : l'image n'est pas écrite."] = "Calibration finished: it becomes the shape reference of drive {0}.`n`nRemove the sacrificial disk and insert the disk to be written, then click `"Measure the level and write`": its precompensation level is measured on cylinders {1} (2 sides, 1 to 3 writes of the pattern per track), then the image is written.`nCancel: the image is not written."
$script:I18n['Mesurer le niveau et écrire'] = 'Measure the level and write'
$script:I18n["Sans réponse, la mesure du niveau puis l'écriture démarrent automatiquement dans {0} s."] = 'Without an answer, the level measurement then the write start automatically in {0} s.'
$script:I18n["Calibration rapide impossible : {0}. Écriture avec la nouvelle calibration complète."] = 'Quick calibration impossible: {0}. Writing with the new full calibration.'
$script:I18n['Restauration : niveau mesuré sur la disquette de destination (test rapide), la calibration du lecteur n''est pas refaite.'] = 'Restore: level measured on the destination disk (quick test), the drive calibration is not redone.'
$script:I18n["niveau non mesuré : {0}"] = 'level not measured: {0}'
$script:I18n["Niveau      : {0}"] = 'Level       : {0}'
$script:I18n["Écrire l'image : l'image est écrite avec le niveau mesuré.`nArrêter : l'image n'est pas écrite ; le niveau n'est pas conservé et les profils de la référence sont rétablis."] = "Write the image: the image is written with the measured level.`nStop: the image is not written; the level is not kept and the reference profiles are restored."
$script:I18n["Conserver le niveau : le profil décalé reste dans les champs --precomp, pour cette disquette seulement.`nAbandonner le niveau : les champs --precomp reprennent leurs valeurs d'avant la calibration rapide."] = "Keep the level: the shifted profile stays in the --precomp fields, for this disk only.`nDiscard the level: the --precomp fields return to their values from before the quick calibration."
$script:I18n["Calibration complète : la courbe du lecteur est mesurée de nouveau en test fin, après un avertissement ; elle devient la nouvelle référence de forme."] = 'Full calibration: the drive curve is measured again with the fine test, after a warning; it becomes the new shape reference.'
$script:I18n['Conserver le niveau'] = 'Keep the level'
$script:I18n['Abandonner le niveau'] = 'Discard the level'
$script:I18n['précompensation nulle encore excessive sur la plupart des cylindres mesurés'] = 'zero precompensation still excessive on most measured cylinders'
$script:I18n['Calibration rapide abandonnée : champs --precomp rétablis.'] = 'Quick calibration abandoned: --precomp fields restored.'
$script:I18n['Calibration rapide abandonnée à votre demande : niveau non conservé, champs --precomp rétablis.'] = 'Quick calibration abandoned at your request: level not kept, --precomp fields restored.'
$script:I18n['Test rapide choisi dans l''onglet Écriture : avant l''écriture, le niveau de la courbe est mesuré sur la disquette à écrire (4 à 9 cylindres par tête, 1 à 3 écritures du motif par piste).'] = 'Quick test chosen in the Write tab: before writing, the level of the curve is measured on the disk to be written (4 to 9 cylinders per head, 1 to 3 writes of the pattern per track).'
$script:I18n['non vérifiée, plafond atteint'] = 'not verified, ceiling reached'
$script:I18n['non vérifiée, plancher atteint'] = 'not verified, floor reached'
$script:I18n["Trop peu de cylindres de mesure selon les règles habituelles : règles élargies (cylindres 0 et 1 admis, valeurs de 5 à 290 ns, résidu de référence jusqu'à 12 ns)."] = 'Too few measurement cylinders under the usual rules: widened rules (cylinders 0 and 1 allowed, values from 5 to 290 ns, reference residual up to 12 ns).'
$script:I18n["Niveau stable mais non vérifié à la passe {0} (décalage résiduel moyen {1} ns, tolérance {2}) : niveau {3} ns retenu."] = 'Level stable but not verified at pass {0} (mean residual shift {1} ns, tolerance {2}): level {3} ns kept.'
$script:I18n['Calibration rapide : une face ne réagit pas à la précompensation (voir le journal).'] = 'Quick calibration: one side does not respond to precompensation (see the log).'
$script:I18n['Écriture annulée : une face ne réagit pas à la précompensation.'] = 'Write cancelled: one side does not respond to precompensation.'
$script:I18n['une face ne réagit pas à la précompensation'] = 'one side does not respond to precompensation'
$script:I18n["niveau non vérifié par une écriture du motif ({0} passe(s))"] = 'level not verified by a write of the pattern ({0} pass(es))'
$script:I18n["niveau estimé sur {0} cylindre(s) de niveau seulement ({1} au plafond ou au plancher)"] = 'level estimated on only {0} level cylinder(s) ({1} at the ceiling or floor)'
$script:I18n["besoin hors de 0 à {1} ns aux cylindres de niveau {0}, loin du niveau de cette disquette : écartés du niveau"] = 'need outside 0 to {1} ns at level cylinders {0}, far from the level of this disk: left out of the level'
$script:I18n["témoin du plafond c{0} non résolu : zone de c{1} à c{0} laissée à la référence ({2} ns, plafond de son calcul), relevée du niveau s'il est positif, sans mesure sur cette disquette"] = 'ceiling witness c{0} not resolved: zone c{1} to c{0} left at the reference ({2} ns, ceiling of its calculation), raised by the level if it is positive, not measured on this disk'
$script:I18n['non vérifiée (limite de 0 ou {0} ns atteinte)'] = 'not verified (0 or {0} ns limit reached)'
$script:I18n['non vérifiée, trop peu de cylindres mesurés'] = 'not verified, too few measured cylinders'
$script:I18n['non vérifiée (trop peu de cylindres mesurés)'] = 'not verified (too few measured cylinders)'
$script:I18n["Profils par tête appliqués par le mode Auto en écriture lente à toute image {0} ; ils seront enregistrés dans la configuration à la fin de la restauration."] = 'Per-head profiles applied by Auto mode in slow write to any {0} image; they will be saved in the configuration at the end of the restore.'
$script:I18n["Profil appliqué par le mode Auto à toute image {0} ; il sera enregistré dans la configuration à la fin de la restauration."] = 'Profile applied by Auto mode to any {0} image; it will be saved in the configuration at the end of the restore.'
$script:I18n['Calibration rapide : écriture terminée, champs --precomp remis au profil de la référence (le profil décalé ne valait que pour la disquette écrite).'] = 'Quick calibration: write finished, --precomp fields reset to the reference profile (the shifted profile only applied to the written disk).'
$script:I18n['antérieur à 12.1'] = 'older than 12.1'
$script:I18n['{0}, conservé (calcul actuel v{1})'] = '{0}, kept (current calculation v{1})'
$script:I18n['Courbe obtenue avec le calcul de calibration v{0}.'] = 'Curve obtained with calibration calculation v{0}.'
$script:I18n['Configuration sauvegardée avant le choix sur les anciennes calibrations : {0}'] = 'Configuration saved before the choice on the old calibrations: {0}'
$script:I18n['Profil de famille calibré sans courbe (version antérieure à 12.1) : profil d''origine rétabli.'] = 'Calibrated family profile without curve (version older than 12.1): original profile restored.'
$script:I18n['{0} : calcul {1}, lecteur {2}, {3}'] = '{0}: calculation {1}, drive {2}, {3}'
$script:I18n['Calibrations d''un autre calcul'] = 'Calibrations from another calculation'
$script:I18n['Recalibrer (conseillé)'] = 'Recalibrate (recommended)'
$script:I18n['Conserver ces courbes'] = 'Keep these curves'
$script:I18n['Calibrations d''un autre calcul conservées à votre demande : {0}. Elles sont utilisées telles quelles (calcul actuel v{1}).'] = 'Calibrations from another calculation kept at your request: {0}. They are used as they are (current calculation v{1}).'
$script:I18n["Calibrations d'un autre calcul abandonnées : {0}. Courbes et profils calibrés remis aux valeurs d'origine ; le lecteur sera recalibré à la prochaine écriture qui en a besoin."] = 'Calibrations from another calculation discarded: {0}. Curves and calibrated profiles reset to the original values; the drive will be recalibrated at the next write that needs it.'
$script:I18n['Calibrations d''un autre calcul : décision remise au prochain démarrage ; elles ne sont pas utilisées d''ici là.'] = 'Calibrations from another calculation: decision postponed to the next start; they are not used until then.'
$script:I18n['calcul {0}'] = 'calculation {0}'
$script:I18n['Calcul de calibration : {0}'] = 'Calibration calculation: {0}'
$script:I18n['calcul de calibration {0}'] = 'calibration calculation {0}'
$script:I18n["Calibration {0} de la famille {1} faite avec le calcul {2} : écriture avec cette courbe, conservée à votre demande. Pour la refaire avec le calcul actuel, bouton « Calibrer » de l'onglet Écriture."] = '{0} calibration of the {1} family made with calculation {2}: writing with this curve, kept at your request. To redo it with the current calculation, Calibrate button of the Write tab.'
$script:I18n['Référence faite avec le calcul de calibration {0}.'] = 'Reference made with calibration calculation {0}.'
$script:I18n['{0}, calcul {1}'] = '{0}, calculation {1}'
$script:I18n['Ces calibrations ont été faites avec un autre calcul de calibration que le calcul actuel (v{0}) :'] = 'These calibrations were made with a calibration calculation other than the current one (v{0}):'
$script:I18n["Calibrations faites avec un autre calcul de calibration que le calcul actuel (v{0}) : {1}. Elles sont mises de côté jusqu'à votre choix."] = 'Calibrations made with a calibration calculation other than the current one (v{0}): {1}. They are set aside until you choose.'
$script:I18n["Recalibrer (conseillé) : ces calibrations sont abandonnées ; la prochaine écriture qui en a besoin recalibre le lecteur.`nConserver ces courbes : elles restent utilisées telles quelles ; la fenêtre Courbe et le journal rappellent leur calcul. Le calcul ayant changé, une nouvelle calibration peut donner une courbe plus juste. Une courbe antérieure à la 12.3 ne peut pas servir de référence au test rapide (pente et densité non enregistrées).`nFermer la fenêtre (ou Échap) : décision au prochain démarrage ; d'ici là, ces calibrations ne sont pas utilisées."] = "Recalibrate (recommended): these calibrations are discarded; the next write that needs one recalibrates the drive.`nKeep these curves: they remain in use as they are; the Curve window and the log recall their calculation. As the calculation has changed, a new calibration may give a more accurate curve. A curve older than 12.3 cannot be the reference of the quick test (slope and density not recorded).`nClose the window (or Esc): decision at the next start; until then, these calibrations are not used."
$script:I18n["Copie de la configuration d'avant ce choix : {0}"] = 'Copy of the configuration from before this choice: {0}'
$script:I18n['Courbes de la version 12.2 relues dans la copie faite par la première version 12.3 : {0}'] = 'Curves of version 12.2 read back from the copy made by the first 12.3 version: {0}'
$script:I18n["Bruit de mesure estimé : {0} ns, sur {1} écarts entre cylindres vérifiés distants de 2 au plus. Un écart est retenu si la moyenne des résidus voisins (2 cylindres au plus) dépasse {2} ns, si un résidu dépasse {3} ns, s'il s'étend sur 3 cylindres ou plus, ou 2 en bord de piste ou de segment, au-delà de {2} ns, ou s'il couvre 2 cylindres au-delà de {4} ns. Seuils relevés quand le bruit est fort. Un écart dont un cylindre a moins de 2 autres cylindres vérifiés à 2 cylindres au plus est retenu sur sa seule tolérance ; les points isolés et les cylindres au plafond ou au plancher ne comptent ni dans le bruit ni dans le voisinage, les cylindres non reproductibles ni dans le bruit ni dans les moyennes."] = 'Estimated measurement noise: {0} ns, from {1} differences between verified cylinders at most 2 apart. A deviation is kept if the mean of the neighbouring residuals (within 2 cylinders) exceeds {2} ns, if a residual exceeds {3} ns, if it spans 3 or more cylinders, or 2 at the edge of the track or of a segment, beyond {2} ns, or if it covers 2 cylinders beyond {4} ns. Thresholds are raised when the noise is high. A deviation one of whose cylinders has fewer than 2 other verified cylinders within 2 cylinders is kept on its tolerance alone; isolated points and cylinders at the ceiling or floor count neither in the noise nor in the neighbourhood, non-reproducible cylinders neither in the noise nor in the means.'
$script:I18n['Écarts locaux non retenus : {0}. Hors tolérance, mais sous les seuils ci-dessus : ces écarts ne sont pas corrigés.'] = 'Local deviations not kept: {0}. Out of tolerance, but below the thresholds above: these deviations are not corrected.'
$script:I18n["c{0} : extrapolation {1} ± {2} ns, tendance {3} ± {4} ns, retenu {5} ns"] = 'c{0}: extrapolation {1} ± {2} ns, trend {3} ± {4} ns, kept {5} ns'
$script:I18n["Besoin au-delà de {0} ns, zéro extrapolé incertain (loin des mesures ou sans pente propre) : combiné avec la tendance de la courbe ({1}). La vérification écrit la courbe à ces cylindres et la mesure."] = 'Need above {0} ns, uncertain extrapolated zero (far from the measurements or without its own slope): combined with the trend of the curve ({1}). The verification writes the curve at these cylinders and measures it.'
$script:I18n[' et par la tendance de la courbe'] = ' and by the trend of the curve'
$script:I18n["Besoin au-delà de {0} ns, plafond des passes de mesure, aux cylindres {1} : courbe jusqu'à {2} ns, déduite par extrapolation des mesures{3}, puis contrôlée par la vérification. Un besoin aussi fort est inhabituel : si une disquette en bon état ne l'atteint pas, le support de calibration est probablement fatigué."] = 'Need above {0} ns, the ceiling of the measurement passes, at cylinders {1}: curve up to {2} ns, deduced by extrapolation of the measurements{3}, then checked by the verification. Such a high need is unusual: if a disk in good condition does not reach it, the calibration disk is probably worn.'
$script:I18n["Besoin au-delà de {0} ns alors que la calibration précédente du même lecteur ne dépassait pas cette valeur : support de calibration probablement fatigué (sinon têtes à nettoyer, ou autre lecteur sous la même lettre)."] = 'Need above {0} ns whereas the previous calibration of the same drive did not exceed this value: the calibration disk is probably worn (otherwise dirty heads, or another drive under the same letter).'
$script:I18n["Courbes au plafond de {0} ns de leur calcul : {1}. Conservées, elles y restent ; le calcul actuel va jusqu'à {2} ns."] = 'Curves at the {0} ns ceiling of their calculation: {1}. If kept, they stay there; the current calculation goes up to {2} ns.'
$script:I18n["Courbe au plafond de {0} ns de son calcul : {1}. Conservée, elle y reste ; le calcul actuel va jusqu'à {2} ns."] = 'Curve at the {0} ns ceiling of its calculation: {1}. If kept, it stays there; the current calculation goes up to {2} ns.'
$script:I18n['courbe au plafond de {0} ns de son calcul'] = 'curve at the {0} ns ceiling of its calculation'
$script:I18n["Auto : image haute densité ({0}) -> profil d'origine {1} ({2}) : un profil calibré (double densité) ne s'applique pas à une image haute densité"] = "Auto: high-density image ({0}) -> original {1} profile ({2}): a calibrated (double-density) profile does not apply to a high-density image"
$script:I18n["c{0} ({1} puis {2} ns)"] = 'c{0} ({1} then {2} ns)'
$script:I18n["Calibration : témoins de dérive, réécrits à leur valeur inchangée et relus pour mesurer l'écart du lecteur entre deux vérifications : {0}"] = 'Calibration: drift witnesses, rewritten at their unchanged value and read again to measure the drive offset between two verifications: {0}'
$script:I18n['moins de 1 ns'] = 'less than 1 ns'
$script:I18n["Dérive du lecteur entre les deux vérifications : {0} ± {1} ns de décalage commun sur {2} cylindres témoins (dispersion {3})."] = 'Drive drift between the two verifications: {0} ± {1} ns of common offset on {2} witness cylinders (spread {3}).'
$script:I18n[" Le besoin de précompensation était plus élevé de {0} ns à la dernière vérification."] = ' The precompensation need was {0} ns higher at the last verification.'
$script:I18n[" Le besoin de précompensation était plus faible de {0} ns à la dernière vérification."] = ' The precompensation need was {0} ns lower at the last verification.'
$script:I18n[" Écart des cylindres corrigés à leur prédiction, dérive comprise : {0} ns en médiane sur {1}."] = ' Deviation of the corrected cylinders from their prediction, drift included: median {0} ns over {1}.'
$script:I18n["Zone non reproductible d'une vérification à l'autre aux cylindres {0} : les deux vérifications placent le besoin de part et d'autre de la valeur écrite. La courbe y prend la médiane des passes de mesure et des deux vérifications, dans l'intervalle des deux valeurs écrites et sans dépasser les cylindres vérifiés voisins (écart entre les vérifications jusqu'à {1} ns de précompensation)."] = 'Zone not reproducible from one verification to the next at cylinders {0}: the two verifications place the need on either side of the written value. The curve takes there the median of the measurement passes and of the two verifications, within the interval of the two written values and without passing the neighbouring verified cylinders (difference between the verifications up to {1} ns of precompensation).'
$script:I18n["vérifications contradictoires aux cylindres {0} (écart jusqu'à {1} ns : lecteur ou support instable ?)"] = 'contradictory verifications at cylinders {0} (difference up to {1} ns: unstable drive or media?)'
$script:I18n["vérifications contradictoires aux cylindres {0} sans mesure de la dérive du lecteur (écart jusqu'à {1} ns : dérive du lecteur ou zone non reproductible ?)"] = 'contradictory verifications at cylinders {0} without a measurement of the drive drift (difference up to {1} ns: drive drift or non-reproducible zone?)'
$script:I18n["Cylindres vérifiés {0} déplacés par le lissage croissant de la courbe autour de la zone non reproductible, sans nouvelle mesure : leur résidu n'est pas enregistré avec la courbe."] = 'Verified cylinders {0} moved by the increasing smoothing of the curve around the non-reproducible zone, without a new measurement: their residual is not saved with the curve.'
$script:I18n['zone non reproductible'] = 'non-reproducible zone'
$script:I18n["Cylindres non reproductibles d'une vérification à l'autre (zéro estimé à la pente commune par la vérification précédente, puis par la dernière, dérive retirée) : {0}. Ils ne comptent pas pour la convergence ; une nouvelle calibration peut leur donner une autre valeur."] = 'Cylinders not reproducible from one verification to the next (zero estimated with the common slope by the previous verification, then by the last one, drift removed): {0}. They do not count for convergence; a new calibration may give them another value.'
$script:I18n["Borne de précompensation réglée dans la configuration (precompMaxNs) : {0} ns, au lieu de {1} ns par défaut."] = 'Precompensation bound set in the configuration (precompMaxNs): {0} ns, instead of {1} ns by default.'
$script:I18n["dérive du lecteur de {0} ns entre deux vérifications (lecteur ou support instable ?)"] = 'drive drift of {0} ns between two verifications (unstable drive or media?)'
$script:I18n[" Les résidus des cylindres relus à la dernière vérification sont jugés sans ce décalage ; les témoins, inchangés, sur leur mesure précédente, sauf ceux d'un écart systématique, jugés sur leur relecture."] = ' The residuals of the cylinders read again at the last verification are judged without this offset; the witnesses, unchanged, on their previous measurement, except those of a systematic deviation, judged on their new reading.'
$script:I18n["Dérive du lecteur non mesurée : {0} témoin(s) exploitable(s) sur {1}, {2} au moins nécessaires ; résidus jugés sans correction de dérive, témoins sur leur mesure précédente."] = 'Drive drift not measured: {0} usable witness(es) out of {1}, at least {2} needed; residuals judged without drift correction, witnesses on their previous measurement.'
$script:I18n["Dérive du lecteur non mesurée : {0} cylindre(s) non modifié(s) disponible(s) comme témoins, {1} au moins nécessaires ; résidus jugés sans correction de dérive."] = 'Drive drift not measured: {0} unchanged cylinder(s) available as witnesses, at least {1} needed; residuals judged without drift correction.'
$script:I18n["Référence calculée avec une borne de {0} ns, au-delà de la borne actuelle (precompMaxNs = {1} ns) aux cylindres {2} : valeurs ramenées à {1} ns."] = 'Reference computed with a {0} ns bound, beyond the current bound (precompMaxNs = {1} ns) at cylinders {2}: values brought back to {1} ns.'
$script:I18n["Borne de précompensation (precompMaxNs) de {0} ns ramenée à {1} ns : elle va de {2} à {3} ns. Au-delà de 470 ns, la précompensation déplacerait une transition d'un quart de cellule en long track (1,89 µs)."] = 'Precompensation bound (precompMaxNs) of {0} ns brought back to {1} ns: it ranges from {2} to {3} ns. Beyond 470 ns, precompensation would move a transition by a quarter of a cell on long tracks (1.89 µs).'
$script:I18n["Borne de précompensation (precompMaxNs) illisible ({0}) : {1} ns par défaut."] = 'Precompensation bound (precompMaxNs) unreadable ({0}): {1} ns by default.'
$script:I18n["Préchauffage avant la calibration : {2} %, reste environ {3} (lecteur {0}, lecture {1}, sans écriture)"] = 'Warm-up before the calibration: {2} %, about {3} left (drive {0}, read {1}, no writing)'
$script:I18n["Préchauffage du lecteur {0} sauté : lecteur déjà en activité pendant {1} (dernière commande terminée il y a {2})."] = 'Drive {0} warm-up skipped: drive already active for {1} (last command finished {2} ago).'
$script:I18n["Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la calibration, pour stabiliser sa température (durée réduite : lecteur déjà en activité pendant {2}, dernière commande terminée il y a {3})."] = 'Drive {0} warm-up: {1} of reading without writing before the calibration, to stabilise its temperature (shortened: drive already active for {2}, last command finished {3} ago).'
$script:I18n["Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la calibration, pour stabiliser sa température."] = 'Drive {0} warm-up: {1} of reading without writing before the calibration, to stabilise its temperature.'
$script:I18n["Préchauffage du lecteur {0} : la lecture n'a pas abouti (code {1}) ; sans effet sur la calibration, le préchauffage continue."] = 'Drive {0} warm-up: the read did not complete (code {1}); no effect on the calibration, the warm-up continues.'
$script:I18n["Préchauffage du lecteur {0} terminé : {1} lecture(s) en {2}, dont {3} sans aboutir (sans effet sur la calibration)."] = 'Drive {0} warm-up finished: {1} read(s) in {2}, {3} of which did not complete (no effect on the calibration).'
$script:I18n["Préchauffage du lecteur {0} terminé : {1} lecture(s) en {2}."] = 'Drive {0} warm-up finished: {1} read(s) in {2}.'
$script:I18n["Préchauffage du lecteur {0} arrêté après {1} lectures de suite sans aboutir (Greaseweazle, lecteur ou disquette absent ?) : la calibration commence, sa première écriture signalera le défaut s'il persiste."] = 'Drive {0} warm-up stopped after {1} consecutive reads that did not complete (Greaseweazle, drive or disk missing?): the calibration starts, its first write will report the fault if it persists.'
$script:I18n["Préchauffage du lecteur avant la première passe : jusqu'à {0} de lecture sans écriture (moins si le lecteur vient de servir), compris dans la durée estimée."] = 'Drive warm-up before the first pass: up to {0} of reading without writing (less if the drive was just used), included in the estimated time.'
$script:I18n["Préchauffage du lecteur (calWarmupMinutes) illisible ({0}) : {1} min par défaut."] = 'Drive warm-up (calWarmupMinutes) unreadable ({0}): {1} min by default.'
$script:I18n["Préchauffage du lecteur (calWarmupMinutes) de {0} min ramené à {1} min : il va de 0 à {2} min."] = 'Drive warm-up (calWarmupMinutes) of {0} min brought back to {1} min: it ranges from 0 to {2} min.'
$script:I18n["Préchauffage du lecteur {0} : {1} de lecture sans écriture avant l'écriture lente, pour stabiliser sa température."] = 'Drive {0} warm-up: {1} of reading without writing before the slow write, to stabilise its temperature.'
$script:I18n["Préchauffage du lecteur {0} : {1} de lecture sans écriture avant l'écriture lente, pour stabiliser sa température (durée réduite : lecteur déjà en activité pendant {2}, dernière commande terminée il y a {3})."] = 'Drive {0} warm-up: {1} of reading without writing before the slow write, to stabilise its temperature (shortened: drive already active for {2}, last command finished {3} ago).'
$script:I18n["Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la calibration rapide et l'écriture lente, pour que le niveau soit mesuré dans l'état du lecteur au moment de l'écriture."] = 'Drive {0} warm-up: {1} of reading without writing before the quick calibration and the slow write, so that the level is measured in the drive state at write time.'
$script:I18n["Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la calibration rapide et l'écriture lente, pour que le niveau soit mesuré dans l'état du lecteur au moment de l'écriture (durée réduite : lecteur déjà en activité pendant {2}, dernière commande terminée il y a {3})."] = 'Drive {0} warm-up: {1} of reading without writing before the quick calibration and the slow write, so that the level is measured in the drive state at write time (shortened: drive already active for {2}, last command finished {3} ago).'
$script:I18n["Préchauffage du lecteur {0} non demandé (case « Préchauffer le lecteur avant l'écriture lente » décochée) : écriture lente tout de suite."] = 'Drive {0} warm-up not requested ("Warm up the drive before the slow write" box unticked): slow write right away.'
$script:I18n["Préchauffage du lecteur {0} passé à votre demande pendant la calibration : écriture lente tout de suite."] = 'Drive {0} warm-up skipped at your request during the calibration: slow write right away.'
$script:I18n["Préchauffage du lecteur {0} passé à votre demande après {1} : la lecture en cours se termine, puis l'opération continue."] = 'Drive {0} warm-up skipped at your request after {1}: the current read finishes, then the operation continues.'
$script:I18n['Préchauffage du lecteur {0} passé : fin de la lecture en cours.'] = 'Drive {0} warm-up skipped: finishing the current read.'
$script:I18n["Préchauffage avant l'écriture : {2} %, reste environ {3} (lecteur {0}, lecture {1}, sans écriture)"] = 'Warm-up before the write: {2} %, about {3} left (drive {0}, read {1}, no writing)'
$script:I18n["Préchauffage du lecteur {0} : la lecture n'a pas abouti (code {1}) ; sans effet sur l'écriture, le préchauffage continue."] = 'Drive {0} warm-up: the read did not complete (code {1}); no effect on the write, the warm-up continues.'
$script:I18n["Préchauffage du lecteur {0} terminé : {1} lecture(s) en {2}, dont {3} sans aboutir (sans effet sur l'écriture)."] = 'Drive {0} warm-up finished: {1} read(s) in {2}, {3} of which did not complete (no effect on the write).'
$script:I18n["Préchauffage du lecteur {0} arrêté après {1} lectures de suite sans aboutir (Greaseweazle, lecteur ou disquette absent ?) : l'écriture commence, elle signalera le défaut s'il persiste."] = 'Drive {0} warm-up stopped after {1} consecutive reads that did not complete (Greaseweazle, drive or disk missing?): the write starts and will report the fault if it persists.'
$script:I18n["Préchauffage du lecteur avant la mesure du niveau : jusqu'à {0} de lecture sans écriture (moins si le lecteur vient de servir), compris dans la durée estimée."] = 'Drive warm-up before the level measurement: up to {0} of reading without writing (less if the drive was just used), included in the estimated time.'
$script:I18n['Écriture annulée : préchauffage du lecteur interrompu.'] = 'Write cancelled: drive warm-up interrupted.'
$script:I18n['Préchauffage interrompu : écriture annulée.'] = 'Warm-up interrupted: write cancelled.'
$script:I18n['Préchauffage'] = 'Warm-up'
$script:I18n['préchauffage du lecteur'] = 'drive warm-up'
$script:I18n['Passer le préchauffage'] = 'Skip warm-up'
$script:I18n["Préchauffer le lecteur avant l'écriture lente ({0} au plus de lecture sans écriture)"] = 'Warm up the drive before the slow write (up to {0} of reading without writing)'
$script:I18n["Préchauffer le lecteur avant l'écriture lente (désactivé : calWarmupMinutes = 0 dans la configuration)"] = 'Warm up the drive before the slow write (disabled: calWarmupMinutes = 0 in the configuration)'
$script:I18n["Écriture lente (onglet Écriture, Bibliothèque, restauration) : avant d'écrire, le lecteur est préchauffé par des lectures sans écriture (un cylindre sur 10 des pistes écrites, têtes écrites), comme avant une calibration complète, pour écrire dans l'état du lecteur où la précompensation a été calibrée.`nDurée : réglage calWarmupMinutes de la configuration (5 min par défaut, 0 : aucun) ; réduite ou sautée si le lecteur vient de servir, calibration qui précède comprise. Une calibration rapide avant l'écriture lente est précédée du préchauffage : le niveau est mesuré dans le même état du lecteur.`nUne disquette protégée en écriture n'est signalée qu'à la première écriture, après le préchauffage.`nDécochée : écriture tout de suite. Pendant le préchauffage, le bouton « Passer le préchauffage » lance l'écriture après la lecture en cours."] = "Slow write (Write tab, Library, restore): before writing, the drive is warmed up by reads without writing (one cylinder in 10 of the written tracks, written heads), as before a full calibration, to write in the drive state in which the precompensation was calibrated.`nDuration: calWarmupMinutes setting of the configuration (5 min by default, 0: none); shortened or skipped if the drive was just used, preceding calibration included. A quick calibration before the slow write is preceded by the warm-up: the level is measured in the same drive state.`nA write-protected disk is only reported at the first write, after the warm-up.`nUnticked: write right away. During the warm-up, the ""Skip warm-up"" button starts the write after the current read."
$script:I18n["Termine le préchauffage du lecteur après la lecture en cours : l'écriture lente (ou la calibration) commence aussitôt."] = 'Ends the drive warm-up after the current read: the slow write (or the calibration) starts right away.'
$script:I18n["Écriture lente : le lecteur est d'abord préchauffé par des lectures sans écriture (case « Préchauffer le lecteur avant l'écriture lente » de l'onglet Écriture ; bouton « Passer le préchauffage » pendant l'attente)."] = 'Slow write: the drive is first warmed up by reads without writing ("Warm up the drive before the slow write" box of the Write tab; "Skip warm-up" button while waiting).'
$script:I18n["format absent de la table de l'application (gw plus récent ou fichier diskdefs) : calibrez depuis l'onglet Écriture, avec l'image et ce format"] = 'format missing from the application table (newer gw or diskdefs file): calibrate from the Write tab, with the image and this format'
$script:I18n["format de balayage : gw n'écrit pas une image secteur avec ibm.scan, densité inconnue à l'avance"] = 'scan format: gw does not write a sector image with ibm.scan, density unknown in advance'
$script:I18n["haute densité : les courbes calibrées sont double densité ; l'écriture applique le profil d'origine de la famille, non calibré"] = "high density: calibrated curves are double density; writing applies the family's original, uncalibrated profile"
$script:I18n['codage GCR : la calibration ne mesure que le MFM double densité'] = 'GCR encoding: calibration only measures double-density MFM'
$script:I18n['codage FM (simple densité) : la calibration ne mesure que le MFM double densité'] = 'FM encoding (single density): calibration only measures double-density MFM'
$script:I18n['codage propre au système (M2FM, Data General) : la calibration ne mesure que le MFM double densité'] = 'system-specific encoding (M2FM, Data General): calibration only measures double-density MFM'
$script:I18n['disquette à secteurs durs : calibration non prise en charge'] = 'hard-sectored disk: calibration not supported'
$script:I18n["format à {0} tr/min : le motif de test suppose un lecteur à 300 tr/min"] = '{0} rpm format: the test pattern assumes a 300 rpm drive'
$script:I18n["cellule de {0} ns, hors de la plage mesurable (1 700 à 2 300 ns)"] = '{0} ns cell, outside the measurable range (1,700 to 2,300 ns)'
$script:I18n["Débit de {0} kbit/s (cellule de {1} ns) : l'écriture de ce format applique la courbe {2}, mesurée à 2 µs par cellule (densité plus forte de {3} %)."] = '{0} kbit/s data rate ({1} ns cell): writing this format applies the {2} curve, measured at 2 µs per cell ({3} % higher density).'
$script:I18n['Piste 0 en FM : non mesurée, la courbe s''y applique telle quelle.'] = 'Track 0 in FM: not measured, the curve is applied to it as is.'
$script:I18n['Format simple face : la calibration écrit aussi la face 1 (lecteur double face nécessaire).'] = 'Single-sided format: calibration also writes side 1 (double-sided drive required).'
$script:I18n["{0} cylindres dans la définition de gw."] = '{0} cylinders in the gw definition.'
$script:I18n['Amiga longues pistes (IPF, HFE)'] = 'Amiga long tracks (IPF, HFE)'
$script:I18n["Pistes longues d'une protection contre la copie : la cellule réelle et le nombre de cylindres (jusqu'à 84) se lisent dans l'image ; « Calibrer » dans l'onglet Écriture, avec l'image, les reprend exactement."] = 'Long tracks of a copy protection: the actual cell and the number of cylinders (up to 84) are read from the image; "Calibrate" in the Write tab, with the image, uses them exactly.'
$script:I18n['Flux : SCP, RAW, KF, A2R, CTR'] = 'Flux: SCP, RAW, KF, A2R, CTR'
$script:I18n["flux écrit tel quel, sans précompensation (gw ne l'applique qu'aux images à secteurs ou à bits) : pas de calibration"] = 'flux written as is, without precompensation (gw only applies it to sector or bitcell images): no calibration'
$script:I18n['Géométrie libre : IMD, TD0, D88, MSA, DSK CPC'] = 'Free geometry: IMD, TD0, D88, MSA, CPC DSK'
$script:I18n["densité non établie par l'application : l'écriture ne calibre pas, elle applique la courbe {0} ; pour la calibrer, choisissez le format gw de la disquette (atarist.720 pour un MSA de 720 Ko, par exemple)"] = "density not established by the application: writing does not calibrate, it applies the {0} curve; to calibrate it, choose the disk's gw format (atarist.720 for a 720 KB MSA, for example)"
$script:I18n["{0} : aucune courbe"] = '{0}: no curve'
$script:I18n['test non enregistré'] = 'test not recorded'
$script:I18n["{0} : {1}, lecteur {2}, {3}, {4} cylindres, calcul {5}"] = '{0}: {1}, drive {2}, {3}, {4} cylinders, calculation {5}'
$script:I18n[', NON CONVERGÉE'] = ', NOT CONVERGED'
$script:I18n['Courbes par tête antérieures à la courbe commune : non appliquées.'] = 'Per-head curves older than the common curve: not applied.'
$script:I18n['opération en cours'] = 'operation in progress'
$script:I18n["module d'analyse SCP indisponible (Add-Type)"] = 'SCP analysis module unavailable (Add-Type)'
$script:I18n["image de géométrie impossible à créer : {0}"] = 'geometry image cannot be created: {0}'
$script:I18n["seuil de famille precompThresholdNs de {0} ns : ce type serait calibré dans la famille {1}"] = 'precompThresholdNs family threshold of {0} ns: this type would be calibrated in the {1} family'
$script:I18n["{0} cylindres choisis dans l'Accueil"] = '{0} cylinders chosen on the Home tab'
$script:I18n['calibration rapide'] = 'quick calibration'
$script:I18n["Calibration depuis l'Accueil : type {0}, famille {1}, {2} cylindres, {3}, {4}."] = 'Calibration from the Home tab: type {0}, family {1}, {2} cylinders, {3}, {4}.'
$script:I18n["calibration rapide impossible : {0}"] = 'quick calibration impossible: {0}'
$script:I18n['Choisissez un type de disquette dans la liste.'] = 'Choose a disk type in the list.'
$script:I18n["{0}`r`n`r`nNon calibrable : {1}."] = "{0}`r`n`r`nNot calibratable: {1}."
$script:I18n["{0}`r`nFamille de calibration : {1} ({2} cellules par piste, {3} ns par cellule)."] = "{0}`r`nCalibration family: {1} ({2} cells per track, {3} ns per cell)."
$script:I18n["Complète, test standard (1 cylindre sur 10) : environ {0} min"] = 'Full, standard test (1 cylinder in 10): about {0} min'
$script:I18n["Complète, test fin (tous les cylindres) : environ {0} min ; référence du test rapide"] = 'Full, fine test (all cylinders): about {0} min; reference of the quick test'
$script:I18n["Rapide (niveau de la disquette insérée) : environ {0} min"] = 'Quick (level of the inserted disk): about {0} min'
$script:I18n["Forme reprise de la calibration complète du {0}. Insérez la disquette que vous allez écrire : le profil obtenu ne vaut que pour elle."] = 'Shape taken from the full calibration of {0}. Insert the disk you are going to write: the resulting profile is only valid for it.'
$script:I18n['Rapide (niveau de la disquette insérée)'] = 'Quick (level of the inserted disk)'
$script:I18n["Indisponible : {0}."] = 'Unavailable: {0}.'
$script:I18n["La courbe actuelle vient du lecteur {0} : elle sera remplacée, et la nouvelle s'appliquera à tous les lecteurs (une courbe par famille)."] = 'The current curve comes from drive {0}: it will be replaced, and the new one will apply to all drives (one curve per family).'
$script:I18n["La courbe actuelle couvre {0} cylindres : elle sera remplacée par une courbe de {1} cylindres, appliquée à toutes les images de la famille {2}."] = 'The current curve covers {0} cylinders: it will be replaced by a {1}-cylinder curve, applied to all images of the {2} family.'
$script:I18n["Opération en cours : ouvrez la calibration une fois l'opération terminée."] = 'Operation in progress: open the calibration once the operation is finished.'
$script:I18n['Calibrer le lecteur'] = 'Calibrate the drive'
$script:I18n["Choisissez le type de disquette. La calibration mesure la précompensation du lecteur {0} sur une disquette sacrifiée, à la densité de ce type ; la courbe obtenue s'applique ensuite à toutes les images de sa famille. Aucune image n'est nécessaire."] = 'Choose the disk type. Calibration measures the precompensation of drive {0} on a sacrificial disk, at the density of this type; the resulting curve then applies to all images of its family. No image is needed.'
$script:I18n['Type'] = 'Type'
$script:I18n['Géométrie'] = 'Geometry'
$script:I18n['Calibration (famille)'] = 'Calibration (family)'
$script:I18n['Amiga double densité'] = 'Amiga double density'
$script:I18n['Amiga haute densité'] = 'Amiga high density'
$script:I18n['PC et Atari ST double densité'] = 'PC and Atari ST double density'
$script:I18n['Haute densité : PC et autres'] = 'High density: PC and others'
$script:I18n['Images longues pistes et protégées'] = 'Long-track and protected images'
$script:I18n['GCR : Commodore 64, Apple II, Macintosh'] = 'GCR: Commodore 64, Apple II, Macintosh'
$script:I18n['FM (simple densité)'] = 'FM (single density)'
$script:I18n['Autres formats MFM double densité'] = 'Other double-density MFM formats'
$script:I18n['Autres formats'] = 'Other formats'
$script:I18n['non calibrable'] = 'not calibratable'
$script:I18n["Famille {0}"] = '{0} family'
$script:I18n["Cylindres de test : ceux du format par défaut. Un lecteur 5,25 pouces 40 pistes : 40 ; un long track : jusqu'à 84 si le lecteur y accède."] = 'Test cylinders: those of the format by default. A 40-track 5.25-inch drive: 40; a long track: up to 84 if the drive reaches them.'
$script:I18n['Une courbe par tête (écriture lente et restauration)'] = 'One curve per head (slow write and restore)'
$script:I18n["Coché : une courbe par tête, celle de l'écriture lente et de la restauration.`nDécoché : une courbe commune aux deux têtes, celle de l'écriture rapide."] = "Checked: one curve per head, used by slow write and restore.`nUnchecked: one curve common to both heads, used by fast write."
$script:I18n["Préchauffer le lecteur avant la calibration complète ({0} au plus de lecture sans écriture)"] = 'Warm up the drive before the full calibration (up to {0} of reading without writing)'
$script:I18n["Préchauffer le lecteur avant la calibration complète (désactivé : calWarmupMinutes = 0 dans la configuration)"] = 'Warm up the drive before the full calibration (disabled: calWarmupMinutes = 0 in the configuration)'
$script:I18n["Lectures sans écriture des cylindres de test avant la première passe, pour stabiliser la température du lecteur ; réduites ou sautées si le lecteur vient de servir. Décochée : la calibration commence tout de suite. La calibration rapide n'est jamais précédée d'un préchauffage."] = 'Reads without writing of the test cylinders before the first pass, to stabilise the drive temperature; shortened or skipped if the drive was just used. Unticked: the calibration starts right away. The quick calibration is never preceded by a warm-up.'
$script:I18n['Afficher la courbe'] = 'Show the curve'
$script:I18n['Fermer'] = 'Close'
$script:I18n["Calibration depuis l'Accueil non lancée : {0}."] = 'Calibration from the Home tab not started: {0}.'
$script:I18n["Calibration non lancée : {0}."] = 'Calibration not started: {0}.'
$script:I18n['Choisir un type de disquette, voir sa courbe et calibrer le lecteur : complète ou rapide.'] = 'Choose a disk type, view its curve and calibrate the drive: full or quick.'
$script:I18n["Calibration de la précompensation sur le lecteur {0} ({1}).`n`nType de disquette : {2}, famille {3}, {4}.`nMotif de test : données pseudo-aléatoires générées à la densité de ce type.`nCylindres de test : {5} (2 faces), ÉCRASÉS à chaque passe. Durée estimée : {6} min pour {7} passes."] = "Precompensation calibration on drive {0} ({1}).`n`nDisk type: {2}, family {3}, {4}.`nTest pattern: pseudo-random data generated at the density of this type.`nTest cylinders: {5} (2 sides), OVERWRITTEN at each pass. Estimated duration: {6} min for {7} passes."
$script:I18n["=== Calibration precomp : lecteur {0}, type {1} ({2}, {3}) ==="] = '=== Precomp calibration: drive {0}, type {1} ({2}, {3}) ==='
$script:I18n["Motif de test : HFE de données pseudo-aléatoires généré, {0} cylindres, {1} cellules par piste ({2}), soit {3} ns par cellule à 300 tr/min, d'après le type de disquette choisi."] = 'Test pattern: generated HFE of pseudo-random data, {0} cylinders, {1} cells per track ({2}), i.e. {3} ns per cell at 300 rpm, from the chosen disk type.'
$script:I18n["Préchauffage du lecteur {0} désactivé pour cette calibration."] = 'Drive {0} warm-up disabled for this calibration.'
$script:I18n["Calibration rapide de la précompensation sur le lecteur {0} : seul le niveau de la courbe est mesuré, sur la disquette insérée.`n`nRéférence : calibration complète du {1} ({2}), dont la forme est reprise telle quelle.`nType de disquette : {3}, famille {4}.`nCylindres mesurés : {5} (2 faces), ÉCRASÉS à chaque passe ; 1 à 3 passes, 2 en général. Durée estimée : {6} min."] = "Quick precompensation calibration on drive {0}: only the level of the curve is measured, on the inserted disk.`n`nReference: full calibration of {1} ({2}), whose shape is reused as is.`nDisk type: {3}, family {4}.`nMeasured cylinders: {5} (2 sides), OVERWRITTEN at each pass; 1 to 3 passes, usually 2. Estimated duration: {6} min."
$script:I18n["Aucune image n'est écrite. Insérez la disquette que vous allez écrire : le profil obtenu ne vaut que pour elle ; il est placé dans les champs --precomp de l'onglet Écriture si son image est de la même famille."] = 'No image is written. Insert the disk you are going to write: the resulting profile is only valid for it; it is placed in the --precomp fields of the Write tab if its image is of the same family.'
$script:I18n["=== Calibration rapide : lecteur {0}, type {1} ({2}, {3}) ==="] = '=== Quick calibration: drive {0}, type {1} ({2}, {3}) ==='
$script:I18n["Calibration rapide depuis l'Accueil : l'image de l'onglet Écriture n'est pas de la famille {0}, le profil de cette disquette n'est pas placé dans ses champs --precomp ; il reste affiché dans la fenêtre Courbe (dernière calibration rapide)."] = 'Quick calibration from the Home tab: the Write tab image is not of the {0} family, the profile of this disk is not placed in its --precomp fields; it remains shown in the Curve window (last quick calibration).'
$script:I18n["Format {0} non calibrable ({1}) : pas de calibration automatique, écriture avec le profil courant."] = 'Format {0} not calibratable ({1}): no automatic calibration, writing with the current profile.'
$script:I18n["Calibration non prise en charge pour le format {0} : {1}."] = 'Calibration not supported for format {0}: {1}.'
$script:I18n["{0} cylindres d'après le format {1}"] = '{0} cylinders from format {1}'
$script:I18n["format FM {0}"] = 'FM format {0}'
$script:I18n["piste 0 en FM, format {0}"] = 'track 0 in FM, format {0}'
$script:I18n['Nettoyer les têtes du lecteur'] = 'Clean the drive heads'
$script:I18n['Procédure en images. Disquette de nettoyage uniquement, jamais une vraie disquette.'] = 'Illustrated procedure. Cleaning disk only, never a real disk.'
$script:I18n['Standard : 3 passes, 500 ms par position'] = 'Standard: 3 passes, 500 ms per position'
$script:I18n['Courte : 3 passes, 100 ms par position (réglage de gw)'] = 'Short: 3 passes, 100 ms per position (gw default)'
$script:I18n['Longue : 8 passes, 500 ms par position'] = 'Long: 8 passes, 500 ms per position'
$script:I18n['Une disquette à tissu, vendue pour cet usage. Jamais une disquette de données.'] = 'A fabric disk sold for this purpose. Never a data disk.'
$script:I18n["Quelques gouttes d'alcool isopropylique (90 % ou plus) sur le tissu, par la fenêtre du volet : humide, pas détrempé."] = 'A few drops of isopropyl alcohol (90% or more) on the fabric, through the shutter window: damp, not soaked.'
$script:I18n['Disquette sèche : rien à faire à cette étape.'] = 'Dry disk: nothing to do at this step.'
$script:I18n['Insérez-la dans le lecteur {0}, volet en avant, comme une disquette ordinaire.'] = 'Insert it into drive {0}, shutter first, like an ordinary disk.'
$script:I18n['Cochez la case, puis « Lancer le nettoyage ». La tête va et vient pendant {0} environ ; le bruit est normal.'] = 'Tick the box, then "Start cleaning". The head moves back and forth for about {0}; the noise is normal.'
$script:I18n["Retirez-la, puis laissez sécher les têtes le temps indiqué par la notice du kit (à défaut, {0} min par prudence) avant d'insérer une disquette de données."] = 'Remove it, then let the heads dry for the time given in the kit instructions (failing that, {0} min to be safe) before inserting a data disk.'
$script:I18n['Retirez-la : le lecteur est prêt.'] = 'Remove it: the drive is ready.'
$script:I18n['humide'] = 'wet'
$script:I18n['sèche'] = 'dry'
$script:I18n['Nettoyage des têtes du lecteur {0} : {1} passe(s) en zigzag sur {2} cylindres, {3} ms à chaque position, durée estimée {4} ; disquette de nettoyage {5}.'] = 'Head cleaning of drive {0}: {1} zig-zag pass(es) over {2} cylinders, {3} ms at each position, estimated duration {4}; {5} cleaning disk.'
$script:I18n['Nettoyage terminé : retirez la disquette de nettoyage.'] = 'Cleaning finished: remove the cleaning disk.'
$script:I18n["Nettoyage interrompu. Le moteur du lecteur peut tourner encore jusqu'à la fin du délai de sécurité du Greaseweazle (watchdog, 10 s par défaut) : attendez qu'il s'arrête, puis retirez la disquette de nettoyage."] = 'Cleaning interrupted. The drive motor may keep running until the Greaseweazle safety timeout expires (watchdog, 10 s by default): wait for it to stop, then remove the cleaning disk.'
$script:I18n["gw s'est arrêté après {0} passe(s) sur {1}"] = 'gw stopped after {0} of {1} pass(es)'
$script:I18n['ÉCHEC du nettoyage des têtes : {0}'] = 'Head cleaning FAILED: {0}'
$script:I18n["Le nettoyage n'a pas abouti : retirez la disquette de nettoyage, vérifiez le lecteur choisi et son câblage (carte « Tester le Greaseweazle » de l'Accueil), puis relancez."] = 'The cleaning did not complete: remove the cleaning disk, check the selected drive and its cabling ("Test the Greaseweazle" card on the Home tab), then try again.'
$script:I18n["Disquette humide : laissez sécher les têtes le temps indiqué par la notice du kit avant d'insérer une disquette de données ; à défaut, attendez par prudence jusqu'à {0}."] = 'Wet disk: let the heads dry for the time given in the kit instructions before inserting a data disk; failing that, wait until {0} to be safe.'
$script:I18n['Le lecteur est prêt.'] = 'The drive is ready.'
$script:I18n["Comptez cette utilisation sur l'étiquette de la disquette de nettoyage : elle s'use."] = 'Record this use on the cleaning disk label: it wears out.'
$script:I18n['durée estimée : {0}'] = 'estimated duration: {0}'
$script:I18n['NE LANCEZ JAMAIS LE NETTOYAGE AVEC UNE VRAIE DISQUETTE'] = 'NEVER USE A REAL DISK FOR CLEANING'
$script:I18n["Pendant le nettoyage, la tête balaie toute la surface en va-et-vient, moteur en marche, pour frotter sa saleté contre le tissu. Une vraie disquette (données, original ou disquette vierge à garder) risquerait d'être rayée par cette saleté et de perdre ses données, sans retour possible. N'insérez qu'une disquette de nettoyage, et suivez d'abord la notice de son kit."] = 'During cleaning, the head sweeps the whole surface back and forth with the motor running, to rub its dirt off against the fabric. A real disk (data, original or blank disk you want to keep) could be scratched by this dirt and lose its data, with no way back. Insert only a cleaning disk, and follow the instructions of its kit first.'
$script:I18n['1. Disquette de nettoyage'] = '1. Cleaning disk'
$script:I18n['2. Humidifier le tissu'] = '2. Moisten the fabric'
$script:I18n['3. Insérer'] = '3. Insert'
$script:I18n['4. Lancer le nettoyage'] = '4. Start cleaning'
$script:I18n['5. Retirer, laisser sécher'] = '5. Remove, let dry'
$script:I18n['Type :'] = 'Type:'
$script:I18n['Lecteur 80 pistes : 3,5 pouces, ou 5,25 pouces haute densité'] = '80-track drive: 3.5-inch, or 5.25-inch high density'
$script:I18n['Lecteur 40 pistes : 5,25 pouces double densité (360 Ko)'] = '40-track drive: 5.25-inch double density (360 KB)'
$script:I18n['Course de la tête pendant le nettoyage (--cyls). Un lecteur 40 pistes ne doit pas être envoyé au-delà de sa butée.'] = 'Head travel during cleaning (--cyls). A 40-track drive must not be driven beyond its end stop.'
$script:I18n['Disquette :'] = 'Disk:'
$script:I18n['humide (alcool isopropylique)'] = 'wet (isopropyl alcohol)'
$script:I18n['Durée :'] = 'Duration:'
$script:I18n["Réglage de l'onglet Outils : {0} passe(s), {1} ms par position"] = 'Tools tab setting: {0} pass(es), {1} ms per position'
$script:I18n["J'ai inséré une disquette de nettoyage dans le lecteur {0}"] = 'I have inserted a cleaning disk in drive {0}'
$script:I18n['Lancer le nettoyage'] = 'Start cleaning'
$script:I18n["Une commande gw est en cours : attendez qu'elle se termine, puis relancez."] = 'A gw command is running: wait for it to finish, then try again.'
$script:I18n["gw n'a pas pu être lancé : voir le journal."] = 'gw could not be started: see the log.'
$script:I18n['Nettoyage en cours sur le lecteur {0}...'] = 'Cleaning drive {0}...'
$script:I18n['Nettoyage en cours sur le lecteur {0} : passe {1} sur {2}, reste environ {3}.'] = 'Cleaning drive {0}: pass {1} of {2}, about {3} left.'
$script:I18n["Opération en cours : lancez le nettoyage une fois l'opération terminée ou arrêtée."] = 'Operation in progress: start the cleaning once the operation has finished or been stopped.'
# 12.6 corrections apres test et revue : courbe plus courte que l image, carte Calibration de l Accueil
$script:I18n["{0} cylindres pour le format {1} ({2} dans la définition de gw, {0} au moins pour la calibration)"] = '{0} cylinders for format {1} ({2} in the gw definition, at least {0} for the calibration)'
$script:I18n["Calibration {0} de la famille {1} mesurée sur {2} cylindres seulement, image de {3} cylindres : elle est refaite."] = 'The {0} calibration of the {1} family was measured on {2} cylinders only, the image has {3} cylinders: it is redone.'
$script:I18n["courbe de {0} cylindres pour une image de {1}"] = '{0}-cylinder curve for a {1}-cylinder image'
$script:I18n["type de {0} cylindres, référence de {1}"] = 'type of {0} cylinders, reference of {1}'
$script:I18n["densité de ce type différente de celle de la référence de {0} % (5 % au plus)"] = 'density of this type differs from the reference density by {0} % (5 % at most)'
$script:I18n["Densité de ce type différente de celle de la référence de {0} %."] = 'Density of this type differs from the reference density by {0} %.'
$script:I18n["Conserver le niveau : il est enregistré pour cette disquette et reste affiché dans la fenêtre Courbe ; les champs --precomp ne sont pas modifiés.`nAbandonner le niveau : il n'est pas enregistré."] = "Keep the level: it is saved for this disk and stays shown in the Curve window; the --precomp fields are not changed.`nDiscard the level: it is not saved."
$script:I18n['Calibration rapide abandonnée.'] = 'Quick calibration abandoned.'
$script:I18n['Calibration rapide abandonnée à votre demande : niveau non conservé.'] = 'Quick calibration abandoned at your request: level not kept.'
$script:I18n["La calibration rapide ne convient pas à cette disquette ({0}).`nCalibration complète en test fin ci-dessous : elle devient la nouvelle référence de forme du lecteur {1}. Annuler : rien de plus n'est écrit."] = "The quick calibration does not suit this disk ({0}).`nFull fine-test calibration below: it becomes the new shape reference of drive {1}. Cancel: nothing more is written."
function T([string]$s) {
    if ($script:Lang -eq 'fr') { return $s }
    $t = $script:I18n[$s]
    if ($null -ne $t) { return $t }
    return $s
}

function Format-UiNum([double]$v, [string]$fmt = '0.#') {
    # Nombre decimal d un texte d interface : separateur de la culture Windows en francais, point en anglais (interface
    # anglaise sur un poste en francais : « 1890.2 ns », et non « 1890,2 »)
    $ci = if ($script:Lang -eq 'fr') { [System.Globalization.CultureInfo]::CurrentCulture } else { [System.Globalization.CultureInfo]::InvariantCulture }
    return $v.ToString($fmt, $ci)
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
try { Add-Type -AssemblyName System.IO.Compression.FileSystem } catch { }
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Chemins -------------------------------------------------------------------
if ($PSScriptRoot) {
    $script:AppDir = $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    $script:AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    # Exe PS2EXE : repertoire de l executable (gw.exe est a cote), jamais le repertoire courant,
    # qui depend du raccourci et qui, sur un partage UNC, est rendu sous forme qualifiee par le
    # fournisseur (Microsoft.PowerShell.Core\FileSystem::\\serveur\...), inconnue de Process.Start.
    $exePath = $null
    try { $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName } catch { }
    if ($exePath -and $exePath -notmatch '(^|\\)(powershell|powershell_ise|pwsh)\.exe$') {
        $script:AppDir = Split-Path -Parent $exePath
    } else {
        $script:AppDir = (Get-Location).ProviderPath
    }
}
$script:AppDir = $script:AppDir -replace '^[^:]+::', ''   # retire un eventuel prefixe de fournisseur PowerShell
$script:GwExe      = Join-Path $script:AppDir 'gw.exe'
$script:ConfigFile = Join-Path $script:AppDir 'GreaseweazleGUI.json'
$script:TempDir    = Join-Path $env:TEMP 'GreaseweazleGUI'

$script:GwProc     = $null
$script:OutQueue   = $null      # file des lignes de sortie de gw.exe (remplie par Drain-GwReader)
$script:OutStdoutReader = $null
$script:OutStderrReader = $null
$script:OutStdoutTask   = $null
$script:OutStderrTask   = $null

# Recherche asynchrone de la bibliotheque
$script:LibRunspace = $null
$script:LibPS       = $null
$script:LibAsync    = $null

# Extensions image reconnues par gw 1.23 (suffixes listes par "gw write --help")
$script:ImgExt = @('.a2r','.adf','.ads','.adm','.adl','.ctr','.d1m','.d2m','.d4m','.d64','.d71',
                   '.d81','.d88','.dcp','.dim','.dmk','.do','.dsd','.dsk','.edsk','.fd','.fdi',
                   '.hdm','.hfe','.ima','.img','.imd','.ipf','.mgt','.msa','.nfd','.nsi','.po',
                   '.raw','.sf7','.scp','.ssd','.st','.td0','.xdf')
$script:DocExt = @('.txt','.pdf','.jpg','.jpeg','.png','.gif','.nfo','.md')

# Comparateur de secteurs compile a la volee (boucle PowerShell trop lente sur 900 Ko)
$script:FastCompare = $false
try {
    Add-Type -TypeDefinition @'
public static class GwCompare {
    public static int[] DiffSectors(byte[] a, byte[] b, int sectorSize) {
        var list = new System.Collections.Generic.List<int>();
        int n = System.Math.Max(a.Length, b.Length);
        int sectors = (n + sectorSize - 1) / sectorSize;
        for (int sIdx = 0; sIdx < sectors; sIdx++) {
            int start = sIdx * sectorSize;
            int end = System.Math.Min(start + sectorSize, n);
            for (int i = start; i < end; i++) {
                if (i >= a.Length || i >= b.Length || a[i] != b[i]) { list.Add(sIdx); break; }
            }
        }
        return list.ToArray();
    }
    public static long DiffBytes(byte[] a, byte[] b) {
        long d = 0; int n = System.Math.Max(a.Length, b.Length);
        for (int i = 0; i < n; i++) { if (i >= a.Length || i >= b.Length || a[i] != b[i]) d++; }
        return d;
    }
}
'@ -ErrorAction Stop
    $script:FastCompare = $true
} catch { }

# Analyse de flux SCP compilee (onglet Alignement)
$script:ScpStatsOk = $false
try {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
public class ScpRev {
    public double IndexMs; public int NFlux; public double Cell;
    public double Jitter; public double R3; public double R4;
    public int OutOfClass; public int Dropouts;
    public double Shift; public int ShiftN;   // decalage de pic residuel (ns, > 0 = sous-compense) et effectif minimal
    public double ShiftSE;                    // erreur-type du decalage (ns), d apres la dispersion dans les quatre contextes
    public int NSL, NSS, NLS, NLL;            // effectifs : 2T entre deux longs / deux courts, 3T entre deux courts / deux longs
    public int Blocks, Unstable, MaxRun;      // stabilite d un tour a l autre (premier tour) : blocs, blocs instables, plus longue suite
    public int RunPos = -1;                   // debut de cette suite, en pour mille du tour
    public string[] Finger; public int Rich;  // empreinte de la piste (reconnaissance de l original) et nombre de blocs riches
}
public static class ScpStats {
    public static ScpRev Analyze(int[] flux, double indexNs) { return Analyze(flux, indexNs, 0); }
    // cellsPerRev > 0 : motif connu (calibration) -> cellule = duree du tour / nombre de cellules. La mediane des
    // intervalles de deux cellules derive sinon quand le decalage residuel est grand, et fait sortir des intervalles
    // de leur classe (simulation : jusqu a +37 ns sur le decalage mesure a 200 ns de precomp).
    public static ScpRev Analyze(int[] flux, double indexNs, int cellsPerRev) {
        var r = new ScpRev(); r.IndexMs = indexNs / 1e6; r.NFlux = flux.Length; r.Shift = double.NaN; r.ShiftN = 0; r.ShiftSE = double.NaN;
        // 1) estimation de la cellule : mediane des intervalles de 2 cellules.
        //    Fenetre large (3,0 - 5,0 us) valable pour 2 us (AmigaDOS) comme pour 1,89 us (long tracks).
        var c2raw = new List<double>();
        foreach (int f in flux) if (f > 3000 && f < 5000) c2raw.Add(f);
        if (c2raw.Count < 50) { r.Cell = double.NaN; r.Jitter = double.NaN; r.R3 = double.NaN; r.R4 = double.NaN; r.OutOfClass = flux.Length; r.Dropouts = 0; return r; }
        c2raw.Sort(); double cell = (cellsPerRev > 0 && indexNs > 0) ? indexNs / cellsPerRev : c2raw[c2raw.Count / 2] / 2.0;
        // 2) classement de chaque intervalle par son nombre de cellules (arrondi), relatif a la cellule mesuree.
        //    2, 3, 4 cellules = MFM standard ; 5 cellules = marqueur de format (long tracks, syncs speciaux) : pas une erreur.
        //    cls[i] : 2, 3, 4 (MFM), 5 (marqueur tolere), 0 (hors classe ou trou).
        var c2 = new List<double>(); var c3 = new List<double>(); var c4 = new List<double>();
        int n = flux.Length; int[] cls = new int[n];
        int ooc = 0, drop = 0;
        for (int i = 0; i < n; i++) {
            int f = flux[i]; cls[i] = 0;
            if (f >= 20000) { drop++; continue; }
            double q = f / cell; int k = (int)Math.Round(q);
            if (Math.Abs(q - k) > 0.35) { ooc++; continue; }        // trop loin d un multiple entier : erreur
            if (k == 2) { c2.Add(f); cls[i] = 2; } else if (k == 3) { c3.Add(f); cls[i] = 3; } else if (k == 4) { c4.Add(f); cls[i] = 4; }
            else if (k == 5) { cls[i] = 5; /* marqueur, tolere */ } else ooc++;
        }
        r.OutOfClass = ooc; r.Dropouts = drop;
        if (c2.Count < 50) { r.Cell = cell; r.Jitter = double.NaN; r.R3 = double.NaN; r.R4 = double.NaN; return r; }
        r.Cell = cell;
        double m2 = 0; foreach (double v in c2) m2 += v; m2 /= c2.Count;
        double sq = 0; foreach (double v in c2) sq += (v - m2) * (v - m2); r.Jitter = Math.Sqrt(sq / c2.Count);
        double m3 = 0; foreach (double v in c3) m3 += v; m3 = c3.Count > 0 ? m3 / c3.Count : double.NaN;
        double m4 = 0; foreach (double v in c4) m4 += v; m4 = c4.Count > 0 ? m4 / c4.Count : double.NaN;
        r.R3 = m3 / m2; r.R4 = m4 / m2;
        // 3) decalage de pic residuel (ce que corrige la precompensation) : a la lecture, une transition
        //    est repoussee par sa voisine la plus proche. Un 2T encadre par deux intervalles longs (3T/4T)
        //    est donc lu plus long qu un 2T encadre par deux 2T ; un 3T encadre par deux 2T est lu plus
        //    court qu un 3T encadre par deux longs. Shift = demi-somme des deux ecarts (ns) : > 0 sous-
        //    compense, < 0 sur-compense, 0 = reglage ideal. Lineaire en la precomp ecrite.
        //    Les quatre contextes doivent compter au moins 30 occurrences : un estimateur a un seul contexte est
        //    biaise (simulations : de -55 a +27 ns). Erreur-type = demi-racine de la somme des variances des moyennes.
        double sSL = 0, sSS = 0, sLS = 0, sLL = 0, qSL = 0, qSS = 0, qLS = 0, qLL = 0; int nSL = 0, nSS = 0, nLS = 0, nLL = 0;
        for (int i = 1; i < n - 1; i++) {
            int k = cls[i]; if (k != 2 && k != 3) continue;
            int a = cls[i - 1], b = cls[i + 1];
            if (a < 2 || a > 4 || b < 2 || b > 4) continue;
            bool aL = a >= 3, bL = b >= 3; double f = flux[i];
            if (k == 2) { if (aL && bL) { sSL += f; qSL += f * f; nSL++; } else if (!aL && !bL) { sSS += f; qSS += f * f; nSS++; } }
            else        { if (!aL && !bL) { sLS += f; qLS += f * f; nLS++; } else if (aL && bL) { sLL += f; qLL += f * f; nLL++; } }
        }
        r.NSL = nSL; r.NSS = nSS; r.NLS = nLS; r.NLL = nLL;
        r.ShiftN = Math.Min(Math.Min(nSL, nSS), Math.Min(nLS, nLL));
        if (r.ShiftN >= 30) {
            double mSL = sSL / nSL, mSS = sSS / nSS, mLS = sLS / nLS, mLL = sLL / nLL;
            r.Shift = ((mSL - mSS) - (mLS - mLL)) / 2;
            double v = Math.Max(0, qSL / nSL - mSL * mSL) / nSL + Math.Max(0, qSS / nSS - mSS * mSS) / nSS
                     + Math.Max(0, qLS / nLS - mLS * mLS) / nLS + Math.Max(0, qLL / nLL - mLL * mLL) / nLL;
            r.ShiftSE = Math.Sqrt(v) / 2;
        }
        return r;
    }
    // --- Pistes non reproductibles et empreinte -------------------------------------------------------------------
    // Classes des intervalles d un tour : '2' a '5' (nombre de cellules), 'x' hors classe ou trou.
    public static string Classes(int[] flux, double cell) {
        var sb = new System.Text.StringBuilder(flux.Length);
        foreach (int f in flux) {
            if (f >= 20000 || cell <= 0) { sb.Append('x'); continue; }
            double q = f / cell; int k = (int)Math.Round(q);
            sb.Append((Math.Abs(q - k) > 0.35 || k < 2 || k > 5) ? 'x' : (char)('0' + k));
        }
        return sb.ToString();
    }
    // Bloc « riche » : aucune classe au-dessus de maxShare du bloc, aucun intervalle hors classe (pas un gap ni un sync)
    static bool Rich(string s, int start, int len, double maxShare) {
        int[] c = new int[128]; int mx = 0;
        for (int i = start; i < start + len; i++) { int k = s[i] & 127; c[k]++; if (c[k] > mx) mx = c[k]; }
        return c['x'] == 0 && mx <= maxShare * len;
    }
    // Stabilite d une piste d un tour a l autre : le premier tour est decoupe en blocs de 64 intervalles, chacun cherche
    // dans les autres tours pres de sa position attendue (decalage suivi, fenetre de +/- 600 intervalles). Un bloc
    // introuvable dans un autre tour est instable. Premier et dernier blocs ignores (bord du tour, index). Une suite de
    // plusieurs blocs instables = bits faibles (protection) ou defaut localise ; un bloc isole = raccord d ecriture.
    // Renvoie { blocs, blocs instables, plus longue suite instable, debut de cette suite en pour mille }.
    public static int[] Instability(List<int[]> revs, double cell) {
        // Deux tours de reference (0 puis 1) : une erreur de lecture du tour de reference rendrait le bloc introuvable
        // partout ailleurs ; on garde le resultat le moins instable. Avec deux tours, une erreur isolee n est pas
        // distinguable d un bit faible.
        var res = new int[] { 0, 0, 0, -1 };
        if (revs == null || revs.Count < 2 || double.IsNaN(cell) || cell <= 0) return res;
        var cls = new List<string>(); foreach (var r in revs) cls.Add(Classes(r, cell));
        int[] a0 = InstabilityRef(cls, 0);
        if (cls.Count < 3) return a0;
        int[] a1 = InstabilityRef(cls, 1);
        return (a1[2] < a0[2] || (a1[2] == a0[2] && a1[1] < a0[1])) ? a1 : a0;
    }
    // Tour de reference decoupe en blocs de 32 intervalles, chacun cherche dans les autres tours pres de sa position
    // attendue (decalage suivi, fenetre de +/- 600 intervalles). Un bloc est instable s il manque dans au moins deux
    // autres tours (une erreur aleatoire ne touche qu un tour ; des bits faibles changent a chaque tour). Premier et
    // dernier blocs ignores (bord du tour, index). Une suite de blocs instables = bits faibles ou defaut localise ; un
    // raccord d ecriture est un defaut physique fixe, relu pareil a chaque tour.
    static int[] InstabilityRef(List<string> cls, int refIdx) {
        const int L = 32, W = 600;
        var res = new int[] { 0, 0, 0, -1 };
        string a = cls[refIdx];
        int nb = a.Length / L; if (nb < 8) return res;
        int[] miss = new int[nb];
        for (int r = 0; r < cls.Count; r++) {
            if (r == refIdx) continue;
            string b = cls[r]; int off = 0;
            for (int i = 1; i < nb - 1; i++) {
                int exp = i * L + off;
                // bloc a sa place attendue : cas le plus frequent, sans recherche
                if (exp >= 0 && exp + L <= b.Length && string.CompareOrdinal(a, i * L, b, exp, L) == 0) continue;
                string blk = a.Substring(i * L, L);
                int s = Math.Max(0, exp - W), e = Math.Min(b.Length, exp + L + W);
                if (e - s < L) { miss[i]++; continue; }
                if (!Rich(a, i * L, L, 0.8)) {
                    if (b.IndexOf(blk, s, e - s, StringComparison.Ordinal) < 0) miss[i]++;
                    continue;
                }
                int best = -1, bestD = int.MaxValue, p = s;
                while (p <= e - L) {
                    int q = b.IndexOf(blk, p, e - p, StringComparison.Ordinal);
                    if (q < 0) break;
                    int d = Math.Abs(q - exp); if (d < bestD) { bestD = d; best = q; }
                    p = q + 1;
                }
                if (best >= 0) off = best - i * L; else miss[i]++;
            }
        }
        int need = Math.Min(2, cls.Count - 1);
        int nbad = 0, run = 0, top = 0, topStart = -1, start = 0;
        for (int i = 0; i < nb; i++) {
            if (miss[i] >= need) { nbad++; if (run == 0) start = i; run++; if (run > top) { top = run; topStart = start; } }
            else run = 0;
        }
        res[0] = nb; res[1] = nbad; res[2] = top; res[3] = topStart < 0 ? -1 : (int)(1000L * topStart / nb);
        return res;
    }
    // Blocs riches presents une seule fois dans le tour : exclut les remplissages periodiques (E5E5 Atari, 4E...) et
    // les en-tetes communs a toute disquette du meme format
    static List<int> Qualified(string a) {
        const int L = 64; var q = new List<int>(); int nb = a.Length / L;
        for (int i = 1; i < nb - 1; i++) {
            if (!Rich(a, i * L, L, 0.6)) continue;
            string blk = a.Substring(i * L, L);
            if (a.IndexOf(blk, StringComparison.Ordinal) != a.LastIndexOf(blk, StringComparison.Ordinal)) continue;
            q.Add(i);
        }
        return q;
    }
    // Empreinte d une piste : jusqu a n blocs qualifies de 64 intervalles du premier tour, repartis sur la piste ;
    // aucune si la piste a moins de 24 blocs qualifies (piste vide ou formatee sans donnees propres : E5E5, 4E...)
    public static string[] Fingerprint(int[] flux, double cell, int n) {
        var outp = new List<string>();
        if (flux == null || double.IsNaN(cell) || cell <= 0) return outp.ToArray();
        string a = Classes(flux, cell); var q = Qualified(a);
        if (q.Count < 24) return outp.ToArray();
        int k = Math.Min(n, q.Count);
        for (int j = 0; j < k; j++) { int i = q[(int)((long)j * q.Count / k)]; outp.Add(a.Substring(i * 64, 64)); }
        return outp.ToArray();
    }
    public static int RichCount(int[] flux, double cell) {
        if (flux == null || double.IsNaN(cell) || cell <= 0) return 0;
        return Qualified(Classes(flux, cell)).Count;
    }
    // Nombre de blocs de l empreinte retrouves dans les tours d une autre lecture. Chaque tour est classe avec la cellule
    // de l original ET avec sa propre cellule : un lecteur de destination d une autre vitesse decale toutes les classes.
    public static int Match(List<int[]> revs, double cell, string[] fp) {
        if (revs == null || fp == null || fp.Length == 0) return 0;
        var sb = new System.Text.StringBuilder();
        foreach (var r in revs) {
            if (r == null) continue;
            if (!double.IsNaN(cell) && cell > 0) { sb.Append(Classes(r, cell)); sb.Append('|'); }
            double c = Analyze(r, 0).Cell;
            if (!double.IsNaN(c) && c > 0) { sb.Append(Classes(r, c)); sb.Append('|'); }
        }
        string s = sb.ToString(); int n = 0;
        foreach (var f in fp) if (s.IndexOf(f, StringComparison.Ordinal) >= 0) n++;
        return n;
    }
    public static int[] Decode(byte[] data, int offset, int count, int resNs) {
        var outp = new List<int>(count); long carry = 0;
        for (int i = 0; i < count; i++) {
            int v = (data[offset + 2 * i] << 8) | data[offset + 2 * i + 1];
            if (v == 0) { carry += 65536; continue; }
            outp.Add((int)((v + carry) * resNs)); carry = 0;
        }
        return outp.ToArray();
    }
}
public static class CalibPattern {
    // Motif de test de la calibration precomp : image HFE v1 telle que gw la lit (image/hfe.py). En-tete de 512 octets
    // (debit en kbit/s a l offset 12), table des pistes au bloc 1 (decalage en blocs de 512 octets, longueur des deux
    // faces en octets), donnees des le bloc 2 en blocs de 256 octets alternes face 0 / face 1, premiere cellule dans le
    // bit de poids faible. Chaque piste : un tour a 300 tr/min (2000 x debit cellules par seconde) de donnees
    // pseudo-aleatoires codees MFM, sans structure de secteur : meme statistique de motifs sur toutes les pistes.
    public static void WriteHfe(string path, int nCyl, int nBits, int rate, int seed) {
        // nBits : cellules par piste (multiple de 16). gw cale chaque piste ecrite sur un tour du lecteur : c est ce nombre,
        // et non le debit de l en-tete, qui fixe la densite ecrite. Longueur des deux faces sur 16 bits dans la table.
        if (nCyl < 1 || nCyl > 255 || nBits < 16 || nBits % 16 != 0 || nBits / 4 > 0xFFFF || rate < 1 || rate > 0xFFFF)
            throw new ArgumentOutOfRangeException("nBits", "HFE : " + nCyl + " cylindres, " + nBits + " cellules par piste hors limites");
        int nBytes = nBits / 8, nBlocks = (nBytes + 255) / 256;
        byte[] head = new byte[512]; for (int i = 0; i < 512; i++) head[i] = 0xFF;
        Array.Copy(System.Text.Encoding.ASCII.GetBytes("HXCPICFE"), head, 8);
        head[8] = 0; head[9] = (byte)nCyl; head[10] = 2; head[11] = 0xFF;   // revision, cylindres, faces, codage inconnu
        head[12] = (byte)(rate & 0xFF); head[13] = (byte)(rate >> 8);       // debit (kbit/s)
        head[14] = 0; head[15] = 0; head[16] = 0xFF; head[17] = 1;          // tr/min inutilise, interface inconnue, reserve
        head[18] = 1; head[19] = 0; head[20] = 0xFF; head[21] = 0xFF;       // table au bloc 1, ecriture permise, pas simple
        byte[] tlut = new byte[512]; for (int i = 0; i < 512; i++) tlut[i] = 0xFF;
        for (int c = 0; c < nCyl; c++) {
            int off = 2 + c * nBlocks, len = 2 * nBytes;
            tlut[c * 4] = (byte)(off & 0xFF); tlut[c * 4 + 1] = (byte)(off >> 8);
            tlut[c * 4 + 2] = (byte)(len & 0xFF); tlut[c * 4 + 3] = (byte)(len >> 8);
        }
        var rnd = new Random(seed);
        using (var fs = new System.IO.FileStream(path, System.IO.FileMode.Create, System.IO.FileAccess.Write)) {
            fs.Write(head, 0, 512); fs.Write(tlut, 0, 512);
            byte[] blk = new byte[256];
            for (int c = 0; c < nCyl; c++) {
                byte[][] side = new byte[][] { Track(rnd, nBits), Track(rnd, nBits) };
                for (int b = 0; b < nBlocks; b++)
                    for (int s = 0; s < 2; s++) {
                        for (int i = 0; i < 256; i++) { int k = b * 256 + i; blk[i] = k < nBytes ? side[s][k] : (byte)0x88; }
                        fs.Write(blk, 0, 256);
                    }
            }
        }
    }
    static byte[] Track(Random rnd, int nBits) {
        // MFM : une cellule d horloge puis une de donnee par bit ; horloge a 1 seulement entre deux bits de donnee a 0
        byte[] t = new byte[nBits / 8]; int prev = 0;
        for (int i = 0; i < nBits; i += 2) {
            int d = rnd.Next(2), clk = (prev == 0 && d == 0) ? 1 : 0;
            if (clk == 1) t[i >> 3] |= (byte)(1 << (i & 7));
            if (d == 1) t[(i + 1) >> 3] |= (byte)(1 << ((i + 1) & 7));
            prev = d;
        }
        return t;
    }
}
'@ -ErrorAction Stop
    $script:ScpStatsOk = $true
} catch { }

# Ajustement de la courbe de calibration monotone par segments : bloc separe (un echec de compilation garde
# l ajustement croissant d origine sans toucher a l analyse de flux)
$script:CurveFitOk = $false
try {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
public static class CurveFit {
    // PAVA pondere sur y[from..to), croissant (inc) ou decroissant
    static double[] Pava(double[] y, double[] w, int from, int to, bool inc) {
        var v = new List<double>(); var wt = new List<double>(); var cnt = new List<int>();
        for (int i = from; i < to; i++) {
            v.Add(inc ? y[i] : -y[i]); wt.Add(w[i]); cnt.Add(1);
            while (v.Count >= 2 && v[v.Count - 2] > v[v.Count - 1]) {
                int a = v.Count - 2, b = v.Count - 1;
                double ww = wt[a] + wt[b];
                v[a] = ww > 0 ? (v[a] * wt[a] + v[b] * wt[b]) / ww : (v[a] + v[b]) / 2; wt[a] = ww; cnt[a] += cnt[b];
                v.RemoveAt(b); wt.RemoveAt(b); cnt.RemoveAt(b);
            }
        }
        var o = new double[to - from]; int k = 0;
        for (int j = 0; j < v.Count; j++) for (int c = 0; c < cnt[j]; c++) o[k++] = inc ? v[j] : -v[j];
        return o;
    }
    static double Cost(double[] y, double[] w, double[] f, int from) {
        double s = 0; for (int i = 0; i < f.Length; i++) { double e = y[from + i] - f[i]; s += w[from + i] * e * e; } return s;
    }
    static double[] Join(double[] a, double[] b, double[] d) {
        int n = a.Length + b.Length + (d == null ? 0 : d.Length); var o = new double[n]; int k = 0;
        foreach (double x in a) o[k++] = x; foreach (double x in b) o[k++] = x;
        if (d != null) foreach (double x in d) o[k++] = x;
        return o;
    }
    // Monotone par segments : K = 0 (croissant), 1 (croissant puis decroissant) ou 2 (croissant, decroissant, croissant).
    // Cout = somme ponderee des ecarts au carre + K x pen ; un changement de sens n est admis que sur une chute nette
    // (sommet - creux > minDrop) entre deux points fiables (encadres). Renvoie { K, t1, t2, cout, f0 ... fn-1 } :
    // segments [0, t1), [t1, t2), [t2, n).
    public static double[] SegFit(double[] y, double[] w, bool[] reliable, double pen, double minDrop) {
        int n = y.Length;
        double[] best = Pava(y, w, 0, n, true);
        double bestCost = Cost(y, w, best, 0); int bk = 0, bt1 = n, bt2 = n;
        for (int t1 = 1; t1 < n; t1++) {
            double[] a = Pava(y, w, 0, t1, true), b = Pava(y, w, t1, n, false);
            // la montee finit sur le sommet (a[t1-1] >= b[0]) : segments sans montee cachee dans la descente
            if (b[0] > a[t1 - 1] || a[t1 - 1] - b[b.Length - 1] <= minDrop || !reliable[t1 - 1] || !reliable[n - 1]) continue;
            double c = Cost(y, w, a, 0) + Cost(y, w, b, t1) + pen;
            if (c < bestCost) { bestCost = c; bk = 1; bt1 = t1; bt2 = n; best = Join(a, b, null); }
        }
        for (int t1 = 1; t1 < n - 1; t1++) {
            double[] a = Pava(y, w, 0, t1, true);
            if (!reliable[t1 - 1]) continue;
            double ca = Cost(y, w, a, 0);
            for (int t2 = t1 + 1; t2 < n; t2++) {
                double[] b = Pava(y, w, t1, t2, false);
                if (b[0] > a[t1 - 1] || a[t1 - 1] - b[b.Length - 1] <= minDrop || !reliable[t2 - 1]) continue;
                double[] d = Pava(y, w, t2, n, true);
                if (d[0] < b[b.Length - 1]) continue;            // la descente finit sur le creux
                double c = ca + Cost(y, w, b, t1) + Cost(y, w, d, t2) + 2 * pen;
                if (c < bestCost) { bestCost = c; bk = 2; bt1 = t1; bt2 = t2; best = Join(a, b, d); }
            }
        }
        var res = new double[4 + n]; res[0] = bk; res[1] = bt1; res[2] = bt2; res[3] = bestCost;
        for (int i = 0; i < n; i++) res[4 + i] = best[i];
        return res;
    }
}
'@ -ErrorAction Stop
    $script:CurveFitOk = $true
} catch { }

# Index de bibliotheque : parcours rapide dans un thread .NET (pas de PowerShell en arriere-plan),
# recherche en memoire instantanee, persistance dans un fichier TSV local.
$script:FastIndexOk = $false
try {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Collections.Generic;
public class IdxEntry { public string Rel; public long Size; public string Kind; }
public static class FastIndex {
    static readonly object sync = new object();
    static List<IdxEntry> entries = new List<IdxEntry>();
    static HashSet<string> imgExt = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    static HashSet<string> docExt = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    public static volatile bool Busy;
    public static volatile int Scanned;
    public static string Error;
    public static string Root = "";
    public static DateTime Built = DateTime.MinValue;
    public static double LastBuildSeconds;
    public static int LastTotal;
    public static void SetExt(string[] img, string[] doc) {
        imgExt = new HashSet<string>(img, StringComparer.OrdinalIgnoreCase);
        docExt = new HashSet<string>(doc, StringComparer.OrdinalIgnoreCase);
    }
    public static string KindOf(string name) {
        string e = Path.GetExtension(name);
        if (string.Equals(e, ".zip", StringComparison.OrdinalIgnoreCase)) return "zip";
        if (imgExt.Contains(e)) return "image";
        if (docExt.Contains(e)) return "doc";
        return "other";
    }
    public static int Count { get { lock (sync) { return entries.Count; } } }
    public static void StartBuild(string root, string outFile) {
        if (Busy) return;
        Busy = true; Scanned = 0; Error = null;
        Thread t = new Thread(delegate() {
            DateTime t0 = DateTime.Now;
            List<IdxEntry> list = new List<IdxEntry>();
            try {
                string r = root.TrimEnd('\\');
                int rootLen = r.Length + 1;
                Stack<DirectoryInfo> stack = new Stack<DirectoryInfo>();
                stack.Push(new DirectoryInfo(r));
                while (stack.Count > 0) {
                    DirectoryInfo d = stack.Pop();
                    try {
                        foreach (FileSystemInfo fsi in d.EnumerateFileSystemInfos()) {
                            if ((fsi.Attributes & FileAttributes.Directory) != 0) {
                                if ((fsi.Attributes & FileAttributes.ReparsePoint) == 0) stack.Push((DirectoryInfo)fsi);
                            } else {
                                FileInfo fi = (FileInfo)fsi;
                                string full = fi.FullName;
                                IdxEntry en = new IdxEntry();
                                en.Rel = full.Length > rootLen ? full.Substring(rootLen) : fi.Name;
                                en.Size = fi.Length; en.Kind = KindOf(fi.Name);
                                list.Add(en);
                                Scanned = list.Count;
                            }
                        }
                    } catch (Exception) { }
                }
                list.Sort(delegate(IdxEntry a, IdxEntry b) { return string.Compare(a.Rel, b.Rel, StringComparison.OrdinalIgnoreCase); });
                lock (sync) { entries = list; Root = r; Built = DateTime.Now; }
                LastBuildSeconds = (DateTime.Now - t0).TotalSeconds;
                Save(outFile);
            } catch (Exception ex) { Error = ex.Message; }
            finally { Busy = false; }
        });
        t.IsBackground = true;
        t.Start();
    }
    public static void Save(string file) {
        string dir = Path.GetDirectoryName(file);
        if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
        using (StreamWriter w = new StreamWriter(file, false, new UTF8Encoding(false))) {
            lock (sync) {
                w.WriteLine("#GWIDX1\t" + Root + "\t" + Built.Ticks.ToString());
                foreach (IdxEntry e in entries) w.WriteLine(e.Rel + "\t" + e.Size.ToString() + "\t" + e.Kind);
            }
        }
    }
    public static bool Load(string file, string root) {
        if (!File.Exists(file)) return false;
        List<IdxEntry> list = new List<IdxEntry>();
        string r = root.TrimEnd('\\'); DateTime built = File.GetLastWriteTime(file);
        using (StreamReader rd = new StreamReader(file, Encoding.UTF8)) {
            string line = rd.ReadLine();
            if (line == null || !line.StartsWith("#GWIDX1")) return false;
            string[] h = line.Split('\t');
            if (h.Length >= 3) { long ticks; if (long.TryParse(h[2], out ticks)) built = new DateTime(ticks); }
            while ((line = rd.ReadLine()) != null) {
                string[] p = line.Split('\t');
                if (p.Length < 3) continue;
                IdxEntry e = new IdxEntry(); e.Rel = p[0]; long sz; long.TryParse(p[1], out sz); e.Size = sz; e.Kind = p[2];
                list.Add(e);
            }
        }
        lock (sync) { entries = list; Root = r; Built = built; }
        return true;
    }
    public static IdxEntry[] Search(string query, bool imgOnly, int max) {
        string[] words = query.Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
        List<IdxEntry> res = new List<IdxEntry>(); int total = 0;
        lock (sync) {
            foreach (IdxEntry e in entries) {
                if (imgOnly && e.Kind != "image" && e.Kind != "zip") continue;
                bool ok = true;
                foreach (string w in words) { if (e.Rel.IndexOf(w, StringComparison.OrdinalIgnoreCase) < 0) { ok = false; break; } }
                if (!ok) continue;
                total++;
                if (res.Count < max) res.Add(e);
            }
        }
        LastTotal = total;
        return res.ToArray();
    }
}
'@ -ErrorAction Stop
    [FastIndex]::SetExt([string[]]$script:ImgExt, [string[]]$script:DocExt)
    $script:FastIndexOk = $true
} catch { }
$script:IndexDir       = Join-Path $env:LOCALAPPDATA 'GreaseweazleGUI'
$script:LibIndexing    = $false
$script:LibSearchAt    = $null
$script:LibPendingSearch = $false
$script:ProgTotal      = 0
$script:ProgSeen       = $null
$script:ProgOp         = ''

# Chaine d etapes (convert -> read -> compare, ou read -> analyse d alignement) executee par le timer
$script:Chain = New-Object System.Collections.Generic.Queue[scriptblock]
$script:AlignLoop   = $false
$script:AlignNextAt = $null
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

# Profils de precompensation (mesures le 06/10/2026, lecteur A600 en ecriture, relecture A600)
$script:PrecompStd  = '0=70:40=100:65=140'          # cellule 2 us : AmigaDOS, ADF, formats IBM/Atari
$script:PrecompLong = '0=85:20=110:40=120:65=140'   # cellule ~1,89 us : long tracks (formats proprietaires)
$script:PrecompStdDefault  = $script:PrecompStd     # profils d origine, retablis par « Effacer les calibrations »
$script:PrecompLongDefault = $script:PrecompLong
$script:PrecompThresholdNs = 1950                   # cellule < seuil -> profil long track
$script:JitterOk = 120                              # jitter (ns) sous lequel une piste peut etre SAINE (reglage de l Accueil)
$script:JitterWatch = 250                           # jitter (ns) sous lequel une piste est au plus A SURVEILLER, CRITIQUE au-dela
$script:AlignRefLabel = ''

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
$script:HomeCalApp  = @('app.long', 'app.flux', 'app.free')   # types d image de la carte sans format gw (Get-HomeCalibInfo)
$script:HomeCalFmt  = 'amiga.amigados'   # dernier type choisi dans la carte (configuration ui.homeCalFormat)
$script:HomeCalBusy = $false             # calibration lancee depuis l Accueil : progression affichee sur la carte
$script:HomeCalDesc = ''                 # texte d origine de la carte
$script:HcDlg       = $null              # etat de la fenetre de la carte (gestionnaires d evenements)

# --- Fenetre -------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Greaseweazle Studio v$($script:Version)"
# Largeur : cartes de l Accueil (colonne de droite jusqu a 770 px) sans defilement horizontal avec la barre verticale,
# a la taille par defaut comme a la taille minimale (12.6 : 790 et 800 px auparavant, 5 et 11 px de defilement)
$form.ClientSize = New-Object System.Drawing.Size(800, 682)
$form.MinimumSize = New-Object System.Drawing.Size(816, 620)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
$form.BackColor = [System.Drawing.Color]::FromArgb(236, 239, 244)
$mono     = New-Object System.Drawing.Font('Consolas', 9.5)
$monoBig  = New-Object System.Drawing.Font('Consolas', 10.5)
$tip  = New-Object System.Windows.Forms.ToolTip
$bold = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold)   # utilise des la bibliotheque
# Infobulles : delai de lecture suffisant pour les textes longs (5 s par defaut sous WinForms)
$tip.AutoPopDelay = 30000; $tip.InitialDelay = 400; $tip.ReshowDelay = 100

# Textes indicatifs gris dans les champs vides (EM_SETCUEBANNER) : appliques a l affichage de la fenetre, une fois
# les poignees Windows creees. Sans effet sur une zone multiligne.
$script:CueOk = $false
try {
    Add-Type -Namespace GwUi -Name Native -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);' -ErrorAction Stop
    $script:CueOk = $true
} catch { }
$script:CueText = @{}
function Set-Cue($tb, [string]$text) {
    $script:CueText[$tb] = $text
    if ($script:CueOk -and $tb.IsHandleCreated) { [void][GwUi.Native]::SendMessage($tb.Handle, 0x1501, [IntPtr]1, $text) }
    $tb.Add_HandleCreated({ if ($script:CueOk -and $script:CueText.ContainsKey($this)) { [void][GwUi.Native]::SendMessage($this.Handle, 0x1501, [IntPtr]1, [string]$script:CueText[$this]) } })
}
function Apply-Cues {
    if (-not $script:CueOk) { return }
    foreach ($tb in @($script:CueText.Keys)) { if ($tb.IsHandleCreated) { [void][GwUi.Native]::SendMessage($tb.Handle, 0x1501, [IntPtr]1, [string]$script:CueText[$tb]) } }
}

# Aide en ligne : page du wiki associee a l onglet courant (TabPage.Tag), touche F1 ou bouton Aide du bandeau
$script:WikiBase = 'https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/'
function Open-Help([string]$page) {
    $url = $script:WikiBase + $(if ($page) { [System.Uri]::EscapeDataString($page) } else { '' })
    try { Start-Process $url } catch { Append-Log ((T "Aide en ligne : impossible d'ouvrir {0} ({1})") -f "$url", "$($_.Exception.Message)") }
}
function Open-HelpForTab {
    $p = if ($tabs.SelectedTab -and $tabs.SelectedTab.Tag) { [string]$tabs.SelectedTab.Tag } else { 'Home' }
    Open-Help $p
}


# ============================== THEME, ICONES & LOGO ===========================
# Aucun fichier image externe : les icones sont rendues a l'execution a partir de la police
# d'icones de Windows (Segoe Fluent Icons sur Windows 11, Segoe MDL2 Assets sur Windows 10),
# le logo est dessine en GDI+.
$script:Theme = @{
    Accent  = [System.Drawing.Color]::FromArgb(37, 99, 168)
    Accent2 = [System.Drawing.Color]::FromArgb(22, 54, 98)
    Danger  = [System.Drawing.Color]::FromArgb(196, 60, 52)
    Ok      = [System.Drawing.Color]::FromArgb(46, 139, 87)
    Warn    = [System.Drawing.Color]::FromArgb(214, 140, 30)
    Muted   = [System.Drawing.Color]::FromArgb(110, 116, 128)
    Page    = [System.Drawing.Color]::FromArgb(250, 251, 253)
    Window  = [System.Drawing.Color]::FromArgb(236, 239, 244)
    Floppy  = [System.Drawing.Color]::FromArgb(44, 58, 85)
    Flux    = [System.Drawing.Color]::FromArgb(255, 150, 50)
    Folder  = [System.Drawing.Color]::FromArgb(222, 170, 60)
    Zip     = [System.Drawing.Color]::FromArgb(130, 90, 170)
}
$script:IconFont = $null
try {
    $fams = @((New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object { $_.Name })
    foreach ($f in @('Segoe Fluent Icons','Segoe MDL2 Assets')) { if ($fams -contains $f) { $script:IconFont = $f; break } }
} catch { }
$script:Glyph = @{
    Library=0xE8F1; Save=0xE74E; Download=0xE896; Switch=0xE8AB; Copy=0xE8C8; Diagnostic=0xE9D9
    Repair=0xE90F; Stopwatch=0xE916; Cmd=0xE756; Folder=0xE8B7; FolderOpen=0xE838; Search=0xE721
    Refresh=0xE72C; Sync=0xE895; OpenFile=0xE8E5; Document=0xE8A5; Package=0xE7B8; Page=0xE7C3
    Stop=0xE71A; Delete=0xE74D; Setting=0xE713; Info=0xE946; Error=0xE783; Check=0xE73E
    Play=0xE768; Pin=0xE718; Usb=0xE88E; Add=0xE710; Remove=0xE738; Home=0xE80F; Help=0xE897; History=0xE81C
}

function New-GlyphBitmap([string]$name, [int]$size, [System.Drawing.Color]$color) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $brush = New-Object System.Drawing.SolidBrush($color)
    $drawn = $false
    if ($script:IconFont -and $script:Glyph.ContainsKey($name)) {
        try {
            $fam  = New-Object System.Drawing.FontFamily($script:IconFont)
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $path.AddString([string][char]$script:Glyph[$name], $fam, 0, [single]100, (New-Object System.Drawing.PointF(0, 0)), [System.Drawing.StringFormat]::GenericTypographic)
            $b = $path.GetBounds()
            if ($b.Width -gt 0 -and $b.Height -gt 0) {
                # Mise a l'echelle sur la boite reelle du trace, puis centrage sur CETTE boite
                # (et non sur la bounding box typographique) : sinon l'espace reserve aux jambages
                # pousse le glyphe visible vers le haut et il parait decale vers le bas dans le bouton.
                $box = [single]($size - 2)
                $sc = [math]::Min($box / $b.Width, $box / $b.Height)
                $offX = [single](($size - $b.Width * $sc) / 2)
                $offY = [single](($size - $b.Height * $sc) / 2)
                $m = New-Object System.Drawing.Drawing2D.Matrix
                $m.Translate($offX, $offY)
                $m.Scale([single]$sc, [single]$sc)
                $m.Translate([single](-$b.X), [single](-$b.Y))
                $path.Transform($m)
                $g.FillPath($brush, $path); $drawn = $true
            }
            $path.Dispose()
        } catch { }
    }
    if (-not $drawn) { $g.FillEllipse($brush, [int]($size * 0.3), [int]($size * 0.3), [int]($size * 0.4), [int]($size * 0.4)) }
    $brush.Dispose(); $g.Dispose()
    return $bmp
}

# Bitmap d'icone decale d'un pixel vers le haut pour compenser le centrage vertical des boutons WinForms.
function New-ButtonIcon([string]$glyph, [int]$size, [System.Drawing.Color]$color) {
    $src = New-GlyphBitmap $glyph $size $color
    $dst = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.DrawImage($src, 0, -1, $size, $size)
    $g.Dispose(); $src.Dispose()
    return $dst
}

function New-RoundRect([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 2 * $r
    $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure(); return $p
}

# Logo original : disquette 3,5" stylisee portant un signal de flux magnetique
function New-LogoBitmap([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $k = $size / 64.0
    function P([double]$x, [double]$y) { New-Object System.Drawing.PointF([single]($x * $k), [single]($y * $k)) }
    # corps avec coin coupe
    $body = New-Object System.Drawing.Drawing2D.GraphicsPath
    $body.AddPolygon([System.Drawing.PointF[]]@((P 5 4), (P 53 4), (P 60 11), (P 60 58), (P 57 61), (P 8 61), (P 5 58)))
    $g.FillPath((New-Object System.Drawing.SolidBrush($script:Theme.Floppy)), $body)
    # volet metallique et sa fenetre
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(205, 212, 222))), (New-RoundRect (17*$k) (4*$k) (30*$k) (20*$k) (2*$k)))
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($script:Theme.Floppy)), [single](36*$k), [single](8*$k), [single](7*$k), [single](12*$k))
    # etiquette
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(248, 249, 252))), (New-RoundRect (11*$k) (31*$k) (42*$k) (26*$k) (2.5*$k)))
    # signal de flux : train d'impulsions MFM
    $pen = New-Object System.Drawing.Pen($script:Theme.Flux, [single]([math]::Max(1.2, 2.6 * $k)))
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $xs = @(14, 18, 18, 22, 22, 28, 28, 31, 31, 37, 37, 41, 41, 45, 45, 50)
    $ys = @(48, 48, 39, 39, 48, 48, 39, 39, 48, 48, 39, 39, 48, 48, 39, 39)
    $pts = for ($i = 0; $i -lt $xs.Count; $i++) { P $xs[$i] $ys[$i] }
    $g.DrawLines($pen, [System.Drawing.PointF[]]$pts)
    # trou de protection en ecriture
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(20, 28, 44))), [single](8*$k), [single](52*$k), [single](4*$k), [single](4*$k))
    $g.Dispose()
    return $bmp
}

$script:BtnHoverNormal = [System.Drawing.Color]::FromArgb(232, 238, 247)
function Set-Btn($btn, [string]$glyph, [string]$style = 'normal', [switch]$IconOnly, $IconColor = $null) {
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 1
    $btn.UseVisualStyleBackColor = $false
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Font = $script:BtnFont
    $icColor = $null
    if ($IconOnly) { $style = 'icon' }
    switch ($style) {
        'primary' {
            $btn.BackColor = $script:Theme.Accent; $btn.ForeColor = [System.Drawing.Color]::White
            $btn.FlatAppearance.BorderSize = 0
            $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(52, 118, 196)
            $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(28, 82, 150)
            $btn.Font = $script:BtnFontBold; $icColor = [System.Drawing.Color]::White
        }
        'danger' {
            $btn.BackColor = $script:Theme.Danger; $btn.ForeColor = [System.Drawing.Color]::White
            $btn.FlatAppearance.BorderSize = 0
            $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(216, 80, 72)
            $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(170, 44, 38)
            $btn.Font = $script:BtnFontBold; $icColor = [System.Drawing.Color]::White
        }
        'icon' {
            $btn.BackColor = [System.Drawing.Color]::White
            $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(196, 204, 216)
            $btn.FlatAppearance.MouseOverBackColor = $script:BtnHoverNormal
            $icColor = $script:Theme.Accent
        }
        default {
            $btn.BackColor = [System.Drawing.Color]::White; $btn.ForeColor = [System.Drawing.Color]::FromArgb(40, 46, 58)
            $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(196, 204, 216)
            $btn.FlatAppearance.MouseOverBackColor = $script:BtnHoverNormal
            $icColor = $script:Theme.Accent
        }
    }
    if ($IconColor) { $icColor = $IconColor }
    if ($glyph) { $btn.Image = New-ButtonIcon $glyph 16 $icColor } else { $btn.Image = $null }
    if ($style -eq 'icon') {
        $tipText = $btn.Text; $btn.Text = ''; $btn.ImageAlign = 'MiddleCenter'
        if ($tipText -and $tipText -ne '...') { $tip.SetToolTip($btn, $tipText) }
    } else {
        $btn.ImageAlign = 'MiddleLeft'; $btn.TextAlign = 'MiddleCenter'; $btn.TextImageRelation = 'ImageBeforeText'
        $btn.Padding = New-Object System.Windows.Forms.Padding(6, 0, 10, 0)
    }
}

$script:LogoBig   = New-LogoBitmap 48
$script:LogoIcon  = New-LogoBitmap 32

# Les TabPage recoivent une taille explicite AVANT l ajout des controles :
# WinForms calcule les decalages d ancrage a ce moment-la. Sans cela, un
# controle ancre a droite est positionne par rapport a une page de 200 px
# et se retrouve hors ecran une fois la page etiree.
$script:PageW = 782
$script:PageH = 340
function New-TabPage($text) {
    $tp = New-Object System.Windows.Forms.TabPage
    $tp.Text = $text
    $tp.Size = New-Object System.Drawing.Size($script:PageW, $script:PageH)
    $tp.UseVisualStyleBackColor = $false
    $tp.BackColor = $script:Theme.Page
    return $tp
}

function New-Label($text, $loc, $anchor) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = $loc; $l.AutoSize = $true
    if ($anchor) { $l.Anchor = $anchor }
    return $l
}

# --- Bandeau (logo, titre, lecteur) --------------------------------------------
$pnlTop = New-Object System.Windows.Forms.Panel
$pnlTop.Size = New-Object System.Drawing.Size(790, 64)
$pnlTop.Dock = 'Top'
$pnlTop.BackgroundImageLayout = 'None'

function Render-Banner {
    $w = [math]::Max(1, $pnlTop.ClientSize.Width); $h = [math]::Max(1, $pnlTop.ClientSize.Height)
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $script:Theme.Accent2, $script:Theme.Accent, [single]0)
    $g.FillRectangle($lg, $rect)
    # motif discret : pistes concentriques
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(22, 255, 255, 255), 1)
    for ($r = 30; $r -lt 260; $r += 14) { $g.DrawEllipse($pen, [single]($w - 160 - $r), [single]($h / 2 - $r), [single](2 * $r), [single](2 * $r)) }
    $g.DrawImage($script:LogoBig, 12, [int](($h - 48) / 2))
    $fTitle = New-Object System.Drawing.Font('Segoe UI Semibold', 15)
    $fSub   = New-Object System.Drawing.Font('Segoe UI', 9)
    $g.DrawString('Greaseweazle Studio', $fTitle, [System.Drawing.Brushes]::White, 68, 7)
    $g.DrawString((T 'Préservation, écriture et contrôle de disquettes'), $fSub, (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(205, 220, 240))), 70, 37)
    $g.Dispose()
    $old = $pnlTop.BackgroundImage
    $pnlTop.BackgroundImage = $bmp
    if ($old) { $old.Dispose() }
}
$pnlTop.Add_Resize({ Render-Banner })

function New-BannerLabel($text, $loc) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = $loc; $l.AutoSize = $true; $l.Anchor = 'Top,Right'
    $l.BackColor = [System.Drawing.Color]::Transparent; $l.ForeColor = [System.Drawing.Color]::White
    return $l
}

$lblGwStatus = New-BannerLabel '' '556,10'
$lblGwStatus.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
if (Test-Path -LiteralPath $script:GwExe) {
    $lblGwStatus.Text = (T '●  gw.exe prêt'); $lblGwStatus.ForeColor = [System.Drawing.Color]::FromArgb(150, 235, 160)
} else {
    $lblGwStatus.Text = (T '●  gw.exe introuvable'); $lblGwStatus.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 150)
}
$tip.SetToolTip($lblGwStatus, $script:GwExe)

$cmbDrive = New-Object System.Windows.Forms.ComboBox
$cmbDrive.Location = '556,34'; $cmbDrive.Width = 45; $cmbDrive.DropDownStyle = 'DropDownList'
$cmbDrive.Anchor = 'Top,Right'
[void]$cmbDrive.Items.AddRange(@('A','B','0','1','2','3'))
$tip.SetToolTip($cmbDrive, (T "A/B = bus IBM-PC (nappe avec twist) - typiquement le lecteur PC`n0 à 3 = bus Shugart (nappe droite) - typiquement le lecteur Amiga`nAu démarrage, l'application sélectionne le premier lecteur qui répond."))

$txtDev = New-Object System.Windows.Forms.TextBox
$txtDev.Location = '652,34'; $txtDev.Width = 50; $txtDev.Anchor = 'Top,Right'
$tip.SetToolTip($txtDev, (T 'Port COM du Greaseweazle. Vide = détection automatique.'))

$chkTime = New-Object System.Windows.Forms.CheckBox
$chkTime.Text = (T 'Chrono'); $chkTime.Location = '712,35'; $chkTime.Width = 70; $chkTime.Anchor = 'Top,Right'
$chkTime.BackColor = [System.Drawing.Color]::Transparent; $chkTime.ForeColor = [System.Drawing.Color]::White
$tip.SetToolTip($chkTime, (T 'Affiche le temps écoulé après chaque commande gw (option --time).'))

# Mode expert : affiche aussi les onglets techniques (Conversion, Comparaison, Outils, Délais, Commande libre)
$chkExpert = New-Object System.Windows.Forms.CheckBox
$chkExpert.Text = (T 'Mode expert'); $chkExpert.Location = '404,9'; $chkExpert.AutoSize = $true; $chkExpert.Anchor = 'Top,Right'
$chkExpert.BackColor = [System.Drawing.Color]::Transparent; $chkExpert.ForeColor = [System.Drawing.Color]::White
$tip.SetToolTip($chkExpert, (T "Décoché : seuls les onglets utiles au quotidien sont affichés (Accueil, Restauration, Bibliothèque, Écriture, Lecture, Qualité).`nCoché : tous les onglets, y compris Conversion, Comparaison, Outils, Délais et Commande libre."))

# Aide en ligne (wiki) pour l onglet affiche ; touche F1
$btnHelpTop = New-Object System.Windows.Forms.Button
$btnHelpTop.Text = (T 'Aide'); $btnHelpTop.Location = '404,33'; $btnHelpTop.Size = '84,26'; $btnHelpTop.Anchor = 'Top,Right'
$btnHelpTop.Add_Click({ Open-HelpForTab })
$tip.SetToolTip($btnHelpTop, (T 'Ouvre le guide en ligne de l''onglet affiché (touche F1).'))

$pnlTop.Controls.AddRange(@($lblGwStatus, (New-BannerLabel (T 'Lecteur :') '500,37'), $cmbDrive,
    (New-BannerLabel (T 'COM :') '612,37'), $txtDev, $chkTime, $chkExpert, $btnHelpTop))

# --- Separateur onglets / journal ----------------------------------------------
$split = New-Object System.Windows.Forms.SplitContainer
$split.Orientation = 'Horizontal'
$split.Size = New-Object System.Drawing.Size(790, 644)
$split.Panel1MinSize = 300
$split.Panel2MinSize = 80
$split.SplitterWidth = 6
$split.SplitterDistance = 372
$split.Dock = 'Fill'

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$tabs.Padding = New-Object System.Drawing.Point(12, 5)

# ============================== BIBLIOTHEQUE ===================================
$tabL = New-TabPage (T 'Bibliothèque')

$txtLibRoot = New-Object System.Windows.Forms.TextBox
$txtLibRoot.Location = '85,11'; $txtLibRoot.Width = 610; $txtLibRoot.Anchor = 'Top,Left,Right'

$btnLibRoot = New-Object System.Windows.Forms.Button
$btnLibRoot.Text = (T 'Choisir le dossier racine'); $btnLibRoot.Location = '700,10'; $btnLibRoot.Width = 36; $btnLibRoot.Anchor = 'Top,Right'
$btnLibRoot.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = (T 'Répertoire racine de la bibliothèque d''images')
    if ($txtLibRoot.Text -and (Test-Path -LiteralPath $txtLibRoot.Text)) { $d.SelectedPath = $txtLibRoot.Text }
    if ($d.ShowDialog() -eq 'OK') { $txtLibRoot.Text = $d.SelectedPath; Update-Library }
})

$btnLibRefresh = New-Object System.Windows.Forms.Button
$btnLibRefresh.Text = (T 'Actualiser l''arborescence'); $btnLibRefresh.Location = '742,10'; $btnLibRefresh.Width = 36; $btnLibRefresh.Anchor = 'Top,Right'
$btnLibRefresh.Add_Click({ Update-Library })

$txtLibFilter = New-Object System.Windows.Forms.TextBox
$txtLibFilter.Location = '85,41'; $txtLibFilter.Width = 230
$tip.SetToolTip($txtLibFilter, (T "Recherche dans l'index : plusieurs mots = tous requis (ex. : monkey 2 fr).`nRésultats au fil de la frappe une fois l'index construit. Vide = arborescence."))
$txtLibFilter.Add_KeyDown({ if ($_.KeyCode -eq 'Enter') { $script:LibSearchAt = $null; Update-Library } })
$txtLibFilter.Add_TextChanged({ $script:LibSearchAt = (Get-Date).AddMilliseconds(350) })

$btnLibFilter = New-Object System.Windows.Forms.Button
$btnLibFilter.Text = (T 'Chercher'); $btnLibFilter.Location = '320,40'; $btnLibFilter.Width = 36
$btnLibFilter.Add_Click({ $script:LibSearchAt = $null; Update-Library })

$chkLibImgOnly = New-Object System.Windows.Forms.CheckBox
$chkLibImgOnly.Text = (T 'Images seulement'); $chkLibImgOnly.Location = '398,42'; $chkLibImgOnly.Width = 130
$chkLibImgOnly.Add_CheckedChanged({ Update-Library })

$lblLibCount = New-Object System.Windows.Forms.Label
$lblLibCount.Location = '530,44'; $lblLibCount.Size = '148,18'; $lblLibCount.Anchor = 'Top,Left,Right'; $lblLibCount.Text = ''; $lblLibCount.ForeColor = 'DimGray'

$btnLibReindex = New-Object System.Windows.Forms.Button
$btnLibReindex.Text = (T 'Réindexer'); $btnLibReindex.Location = '683,40'; $btnLibReindex.Width = 95; $btnLibReindex.Anchor = 'Top,Right'
$tip.SetToolTip($btnLibReindex, (T "Reconstruit l'index de la racine (en arrière-plan). À faire après l'ajout ou le déplacement de fichiers."))
$btnLibReindex.Add_Click({ Start-LibIndex $true })

$treeLib = New-Object System.Windows.Forms.TreeView
$treeLib.Location = '10,70'; $treeLib.Size = '445,250'
$treeLib.Anchor = 'Top,Bottom,Left,Right'
$treeLib.HideSelection = $false
$treeLib.Add_BeforeExpand({ Expand-LibNode $_.Node })
$treeLib.Add_AfterSelect({ Show-LibSelection $_.Node })

$txtLibInfo = New-Object System.Windows.Forms.TextBox
$txtLibInfo.Location = '465,70'; $txtLibInfo.Size = '313,135'
$txtLibInfo.Anchor = 'Top,Bottom,Right'
$txtLibInfo.Multiline = $true; $txtLibInfo.ReadOnly = $true; $txtLibInfo.Font = $mono; $txtLibInfo.ForeColor = [System.Drawing.Color]::FromArgb(40,44,52)
$txtLibInfo.ScrollBars = 'Vertical'
$txtLibInfo.BackColor = [System.Drawing.SystemColors]::Control

function Start-LibWrite([string]$mode) {
    # Ecriture rapide ou lente de l image selectionnee : parametres de l onglet Ecriture appliques, calibration
    # automatique si elle manque pour la famille de l image, puis ecriture (onglet Ecriture affiche pour le suivi)
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    $sel = Resolve-LibSelection
    if (-not $sel) { return }
    if (-not $sel.IsImage) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Ce fichier n''est pas un format image reconnu par gw.'),(T 'Type non pris en charge'),'OK','Information'); return
    }
    Append-Log ((T "Image sélectionnée : {0}") -f "$($sel.Path)")
    Set-WritePreset $mode $sel.Path $sel.Source
    Update-PrecompForImage $sel.Path
    Show-Tab $tabW
    Start-PresetWrite $mode
}

function Set-LibWriteEnabled([bool]$on) { $btnLibFast.Enabled = $on; $btnLibSlow.Enabled = $on }

$btnLibFast = New-Object System.Windows.Forms.Button
$btnLibFast.Text = (T 'Écriture rapide'); $btnLibFast.Location = '465,213'; $btnLibFast.Size = '154,38'; $btnLibFast.Font = $bold
$btnLibFast.Anchor = 'Bottom,Right'; $btnLibFast.Enabled = $false
$tip.SetToolTip($btnLibFast, (T "Écrit l'image sélectionnée en une passe, les deux têtes ensemble : image entière, profil de précompensation Auto,`npré-effacement, effacement des pistes vides, vérification gw, 10 essais, sans contrôle complet des pistes.`nSans calibration commune pour la famille de l'image, le lecteur est d'abord calibré : la disquette reçoit le motif de test, puis l'image."))
$tip.SetToolTip($btnLibFast, $tip.GetToolTip($btnLibFast) + "`n" + (T 'Test rapide choisi dans l''onglet Écriture : avant l''écriture, le niveau de la courbe est mesuré sur la disquette à écrire (4 à 9 cylindres par tête, 1 à 3 écritures du motif par piste).'))
$btnLibFast.Add_Click({ Start-LibWrite 'fast' })
$btnLibSlow = New-Object System.Windows.Forms.Button
$btnLibSlow.Text = (T 'Écriture lente'); $btnLibSlow.Location = '624,213'; $btnLibSlow.Size = '154,38'; $btnLibSlow.Font = $bold
$btnLibSlow.Anchor = 'Bottom,Right'; $btnLibSlow.Enabled = $false
$tip.SetToolTip($btnLibSlow, (T "Écrit la tête 0 puis la tête 1, chacune avec sa précompensation, puis contrôle toutes les pistes`net réécrit les pistes faibles, 3 passes au plus. Mêmes paramètres que l'écriture rapide.`nSans calibration par tête pour la famille de l'image, chaque tête est d'abord calibrée : la disquette reçoit le motif de test, puis l'image."))
$tip.SetToolTip($btnLibSlow, $tip.GetToolTip($btnLibSlow) + "`n" + (T 'Test rapide choisi dans l''onglet Écriture : avant l''écriture, le niveau de la courbe est mesuré sur la disquette à écrire (4 à 9 cylindres par tête, 1 à 3 écritures du motif par piste).'))
$tip.SetToolTip($btnLibSlow, $tip.GetToolTip($btnLibSlow) + "`n" + (T "Écriture lente : le lecteur est d'abord préchauffé par des lectures sans écriture (case « Préchauffer le lecteur avant l'écriture lente » de l'onglet Écriture ; bouton « Passer le préchauffage » pendant l'attente)."))
$btnLibSlow.Add_Click({ Start-LibWrite 'slow' })

$btnLibOpen = New-Object System.Windows.Forms.Button
$btnLibOpen.Text = (T 'Ouvrir (application par défaut)'); $btnLibOpen.Location = '465,250'; $btnLibOpen.Size = '313,32'
$btnLibOpen.Anchor = 'Bottom,Right'; $btnLibOpen.Enabled = $false
$btnLibOpen.Add_Click({
    $sel = Resolve-LibSelection
    if (-not $sel) { return }
    try { Start-Process -FilePath $sel.Path } catch { Append-Log ((T "Ouverture impossible : {0}") -f "$($_.Exception.Message)") }
})

$btnLibExplore = New-Object System.Windows.Forms.Button
$btnLibExplore.Text = (T 'Ouvrir le dossier'); $btnLibExplore.Location = '465,287'; $btnLibExplore.Size = '313,32'
$btnLibExplore.Anchor = 'Bottom,Right'
$btnLibExplore.Add_Click({
    $n = $treeLib.SelectedNode
    if (-not $n -or -not $n.Tag) { return }
    $p = $n.Tag.Path
    if ($n.Tag.Kind -eq 'zipentry') { $p = $n.Tag.ZipPath }
    if ($p -and (Test-Path -LiteralPath $p)) {
        if ((Get-Item -LiteralPath $p).PSIsContainer) { Start-Process explorer.exe "`"$p`"" }
        else { Start-Process explorer.exe "/select,`"$p`"" }
    }
})

$tabL.Controls.AddRange(@((New-Label (T 'Racine :') '10,14'), $txtLibRoot, $btnLibRoot, $btnLibRefresh,
    (New-Label (T 'Recherche :') '10,44'), $txtLibFilter, $btnLibFilter, $chkLibImgOnly, $lblLibCount, $btnLibReindex,
    $treeLib, $txtLibInfo, $btnLibFast, $btnLibSlow, $btnLibOpen, $btnLibExplore))

# ============================== ECRITURE =======================================
$tabW = New-TabPage (T 'Écriture')

function New-Group($text, $loc, $size) {
    $g = New-Object System.Windows.Forms.GroupBox
    $g.Text = $text; $g.Location = $loc; $g.Size = $size; $g.Anchor = 'Top,Left,Right'
    return $g
}
$bold = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold)
$script:BtnFont     = New-Object System.Drawing.Font('Segoe UI', 9.75)
$script:BtnFontBold = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold)

# --- Groupe 1 : image et profil
$grpWImage = New-Group (T 'Image à écrire') '10,6' '762,86'

$txtWFile = New-Object System.Windows.Forms.TextBox
$txtWFile.Location = '80,20'; $txtWFile.Width = 630; $txtWFile.Anchor = 'Top,Left,Right'
$btnWFile = New-Object System.Windows.Forms.Button
$btnWFile.Text = '...'; $btnWFile.Location = '715,19'; $btnWFile.Width = 36; $btnWFile.Anchor = 'Top,Right'
$tip.SetToolTip($btnWFile, (T 'Choisir une image (IPF, ADF, SCP, HFE...). Le format et le profil de précompensation sont déduits automatiquement.'))

$cmbWFmt = New-Object System.Windows.Forms.ComboBox
$cmbWFmt.Location = '80,52'; $cmbWFmt.Width = 200
[void]$cmbWFmt.Items.AddRange($Formats)
$tip.SetToolTip($cmbWFmt, (T "(auto) = aucun --format transmis : obligatoire pour IPF, SCP, HFE.`nUn ADF a besoin de amiga.amigados (rempli automatiquement). Saisie libre possible."))

$cmbWProfile = New-Object System.Windows.Forms.ComboBox
$cmbWProfile.Location = '440,52'; $cmbWProfile.Width = 170; $cmbWProfile.DropDownStyle = 'DropDownList'
[void]$cmbWProfile.Items.AddRange(@((T 'Auto (selon image)'),(T 'Standard 2 us'),(T 'Long track 1,89 us'),(T 'Manuel')))
$tip.SetToolTip($cmbWProfile, (T "Auto : la cellule de l'image est mesurée (IPF et HFE : bits par piste ; SCP : flux)`net le profil --precomp correspondant est appliqué.`nManuel : le champ --precomp n'est jamais modifié."))
$cmbWProfile.Add_SelectedIndexChanged({ Update-PrecompForImage $txtWFile.Text })

$btnWCurve = New-Object System.Windows.Forms.Button
$btnWCurve.Text = (T 'Courbe'); $btnWCurve.Location = '620,50'; $btnWCurve.Size = '130,26'; $btnWCurve.Enabled = $false
$tip.SetToolTip($btnWCurve, (T 'Affiche la courbe de précompensation calibrée pour la famille de l''image (standard ou long track) : mesures, courbe ajustée et valeur retenue pour chaque cylindre.') + "`n" + (T 'Écriture lente cochée : une courbe par tête, si la calibration a été faite en écriture lente.'))
$btnWCurve.Add_Click({ Show-PrecompCurve $script:CurveFamily $chkWSlow.Checked })

$btnWFile.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Filter = (T 'Images disquette|*.ipf;*.adf;*.scp;*.hfe;*.img;*.st;*.dsk;*.raw;*.d64;*.imd|Tous|*.*')
    if ($txtWFile.Text) { $p = Split-Path -Parent $txtWFile.Text; if ($p -and (Test-Path -LiteralPath $p)) { $d.InitialDirectory = $p } }
    if ($d.ShowDialog() -eq 'OK') {
        $txtWFile.Text = $d.FileName; $script:PresetSource = $d.FileName
        if ($d.FileName -match '\.adf$') { $cmbWFmt.SelectedItem = $(if (Test-AdfHd $d.FileName) { 'amiga.amigados_hd' } else { 'amiga.amigados' }) } else { $cmbWFmt.SelectedIndex = 0 }
        Update-PrecompForImage $d.FileName
    }
})
$txtWFile.Add_Enter({ $script:WFileOnEnter = $txtWFile.Text })
$txtWFile.Add_Leave({ if ($txtWFile.Text -ne $script:WFileOnEnter) { Update-PrecompForImage $txtWFile.Text } })   # profil d une calibration rapide garde sans changement d image

$grpWImage.Controls.AddRange(@((New-Label (T 'Image :') '12,23'), $txtWFile, $btnWFile,
    (New-Label (T 'Format :') '12,55'), $cmbWFmt, (New-Label (T 'Profil précomp. :') '320,55'), $cmbWProfile, $btnWCurve))

# --- Groupe 2 : options d'ecriture courantes
$grpWOpt = New-Group (T 'Options d''écriture') '10,98' '762,162'

$chkWPreErase = New-Object System.Windows.Forms.CheckBox
$chkWPreErase.Text = (T 'Pré-effacer chaque piste'); $chkWPreErase.Location = '12,24'; $chkWPreErase.Width = 170
$tip.SetToolTip($chkWPreErase, (T '--pre-erase : efface la piste juste avant de l''écrire. Recommandé sur une disquette déjà utilisée.'))
$chkWEraseEmpty = New-Object System.Windows.Forms.CheckBox
$chkWEraseEmpty.Text = (T 'Effacer les pistes vides'); $chkWEraseEmpty.Location = '190,24'; $chkWEraseEmpty.Width = 165
$tip.SetToolTip($chkWEraseEmpty, (T '--erase-empty : efface les pistes vides de l''image au lieu de les sauter. Supprime les résidus de l''ancien contenu.'))
$chkWNoVerify = New-Object System.Windows.Forms.CheckBox
$chkWNoVerify.Text = (T 'Sans vérification'); $chkWNoVerify.Location = '365,24'; $chkWNoVerify.Width = 130
$tip.SetToolTip($chkWNoVerify, (T '--no-verify : DÉCONSEILLÉ. Supprime la relecture de contrôle de chaque piste.'))
$chkWSlow = New-Object System.Windows.Forms.CheckBox
$chkWSlow.Text = (T 'Écriture lente'); $chkWSlow.Location = '625,24'; $chkWSlow.Width = 125
$tip.SetToolTip($chkWSlow, (T "Écriture lente : toutes les pistes de la tête 0, puis toutes celles de la tête 1 (une commande gw write par tête),`nchacune avec sa propre précompensation. Deux balayages complets du disque : plus long.`nCochée, la calibration mesure et vérifie une courbe de précompensation par tête."))
$tip.SetToolTip($chkWSlow, $tip.GetToolTip($chkWSlow) + "`n" + (T "Écriture lente : le lecteur est d'abord préchauffé par des lectures sans écriture (case « Préchauffer le lecteur avant l'écriture lente » de l'onglet Écriture ; bouton « Passer le préchauffage » pendant l'attente)."))
# Prechauffage du lecteur avant une ecriture lente (Start-WriteWarmup) : preference enregistree (write.slowWarmup), case
# placee sous le bouton ECRIRE ; inactive sans ecriture lente ou quand calWarmupMinutes vaut 0 (Update-SlowUi)
$chkWWarm = New-Object System.Windows.Forms.CheckBox
$chkWWarm.Location = '12,394'; $chkWWarm.AutoSize = $true; $chkWWarm.Checked = $true; $chkWWarm.Enabled = $false
$chkWWarm.Text = (T "Préchauffer le lecteur avant l'écriture lente ({0} au plus de lecture sans écriture)") -f '5 min'
$tip.SetToolTip($chkWWarm, (T "Écriture lente (onglet Écriture, Bibliothèque, restauration) : avant d'écrire, le lecteur est préchauffé par des lectures sans écriture (un cylindre sur 10 des pistes écrites, têtes écrites), comme avant une calibration complète, pour écrire dans l'état du lecteur où la précompensation a été calibrée.`nDurée : réglage calWarmupMinutes de la configuration (5 min par défaut, 0 : aucun) ; réduite ou sautée si le lecteur vient de servir, calibration qui précède comprise. Une calibration rapide avant l'écriture lente est précédée du préchauffage : le niveau est mesuré dans le même état du lecteur.`nUne disquette protégée en écriture n'est signalée qu'à la première écriture, après le préchauffage.`nDécochée : écriture tout de suite. Pendant le préchauffage, le bouton « Passer le préchauffage » lance l'écriture après la lecture en cours."))

$numWRetries = New-Object System.Windows.Forms.NumericUpDown
$numWRetries.Location = '560,22'; $numWRetries.Width = 50
$numWRetries.Minimum = 0; $numWRetries.Maximum = 50
$tip.SetToolTip($numWRetries, (T '--retries : nombre de réécritures d''une piste dont la vérification échoue.'))

$chkWPrecomp = New-Object System.Windows.Forms.CheckBox
$chkWPrecomp.Text = (T 'Précompensation (--precomp) :'); $chkWPrecomp.Location = '12,50'; $chkWPrecomp.Width = 210
$txtWPrecomp = New-Object System.Windows.Forms.TextBox
$txtWPrecomp.Location = '225,48'; $txtWPrecomp.Width = 260
$tip.SetToolTip($txtWPrecomp, (T "--precomp : cylindre=nanosecondes, paliers séparés par ':'.`nRempli automatiquement selon le profil ; modifiable en mode Manuel."))
$tip.SetToolTip($chkWPrecomp, (T 'Transmet --precomp à gw. Coché automatiquement quand un profil est appliqué.'))
$lblWPrecomp1 = New-Label (T 'Précomp. tête 1 (--precomp) :') '29,81'
$txtWPrecomp1 = New-Object System.Windows.Forms.TextBox
$txtWPrecomp1.Location = '225,78'; $txtWPrecomp1.Width = 260
$tip.SetToolTip($txtWPrecomp1, (T "Écriture lente : --precomp de la tête 1 (la tête 0 utilise le champ du dessus).`nRempli par le profil calibré pour la tête 1 ; modifiable en mode Manuel. Vide : tête 1 écrite sans --precomp."))
function Update-SlowUi {
    # Ecriture lente : champ --precomp de la tete 1 actif, le premier champ devient celui de la tete 0
    $on = $chkWSlow.Checked
    $txtWPrecomp1.Enabled = $on; $lblWPrecomp1.Enabled = $on
    $chkWPrecomp.Text = if ($on) { (T 'Précomp. tête 0 (--precomp) :') } else { (T 'Précompensation (--precomp) :') }
    # Prechauffage avant l ecriture lente : duree du reglage calWarmupMinutes ; case inactive sans ecriture lente ou a 0 min
    $wm = [double]$script:CalWarmupMinutes
    $mt = if ($wm -eq [math]::Floor($wm)) { "$([int]$wm) min" } else { Format-CalDuration (60 * $wm) }
    $chkWWarm.Text = if ($wm -gt 0) { (T "Préchauffer le lecteur avant l'écriture lente ({0} au plus de lecture sans écriture)") -f "$mt" } else { (T "Préchauffer le lecteur avant l'écriture lente (désactivé : calWarmupMinutes = 0 dans la configuration)") }
    $chkWWarm.Enabled = ($on -and $wm -gt 0)
}
$chkWSlow.Add_CheckedChanged({ Update-SlowUi; if ($script:UiReady) { Update-PrecompForImage $txtWFile.Text } })

$chkWPostCheck = New-Object System.Windows.Forms.CheckBox
$chkWPostCheck.Text = (T 'Contrôler toutes les pistes'); $chkWPostCheck.Location = '500,50'; $chkWPostCheck.Width = 255
$tip.SetToolTip($chkWPostCheck, (T "Après une écriture réussie, relit en flux toutes les pistes écrites et classe chacune avec les critères de l'onglet Qualité & alignement.`nUne piste À SURVEILLER, CRITIQUE ou illisible est réécrite seule (avec pré-effacement), puis seule remesurée,`njusqu'au nombre de passes de réécriture choisi. Résultat dans l'onglet Qualité & alignement."))

$lblWRepair = New-Label (T 'Passes de réécriture :') '560,81'
$numWRepair = New-Object System.Windows.Forms.NumericUpDown
$numWRepair.Location = '695,78'; $numWRepair.Width = 50
$numWRepair.Minimum = 0; $numWRepair.Maximum = 10; $numWRepair.Value = 3
$tip.SetToolTip($numWRepair, (T 'Nombre maximal de passes de réécriture des pistes faibles détectées par le contrôle. 0 = contrôle seul, sans réécriture.'))
$chkWPostCheck.Add_CheckedChanged({ $numWRepair.Enabled = $chkWPostCheck.Checked; $lblWRepair.Enabled = $chkWPostCheck.Checked })

# --- Ligne 3 : calibration automatique de la precompensation pour le lecteur d ecriture
$cmbWCalMode = New-Object System.Windows.Forms.ComboBox
$cmbWCalMode.Location = '165,105'; $cmbWCalMode.Width = 250; $cmbWCalMode.DropDownStyle = 'DropDownList'
[void]$cmbWCalMode.Items.AddRange(@((T 'Test standard : 1 cylindre sur 10'), (T 'Test fin : tous les cylindres'), (T 'Test rapide : niveau par disquette')))
$cmbWCalMode.SelectedIndex = 0
$tip.SetToolTip($cmbWCalMode, (T "Test standard (un cylindre sur 10) ou test fin (tous les cylindres) : calibration complète, qui mesure la courbe de précompensation du lecteur ; elle est faite une fois, puis réutilisée.`nTest rapide : la forme de la courbe vient de la dernière calibration complète du lecteur (la référence). Avant chaque écriture depuis la Bibliothèque ou une restauration, et avec « Calibrer », seul son niveau est mesuré sur la disquette insérée : 4 à 9 cylindres par tête, 1 à 3 écritures du motif par piste. Sans référence utilisable, une calibration complète en test fin est faite d'abord ; elle devient la référence."))
$btnWCalib = New-Object System.Windows.Forms.Button
$btnWCalib.Text = (T 'Calibrer'); $btnWCalib.Location = '425,104'; $btnWCalib.Size = '120,26'
$tip.SetToolTip($btnWCalib, (T "Calibre la précompensation pour ce lecteur d'écriture : chaque passe écrit sur les cylindres de test un motif de test pseudo-aléatoire, à la densité de l'image, avec une valeur de precomp puis, en vérification, le profil obtenu ; elle le relit en flux et mesure le décalage de pic. Une courbe donne ensuite une valeur par cylindre ; le profil est enregistré pour la famille de l'image (standard ou long track) et appliqué ensuite par le mode Auto. Le contenu de l'image n'est pas écrit. La disquette insérée est écrasée. Test standard : un cylindre sur 10, quelques minutes. Test fin : tous les cylindres, un quart d'heure environ."))
$tip.SetToolTip($btnWCalib, $tip.GetToolTip($btnWCalib) + "`n" + (T 'Écriture lente cochée : une courbe par tête, vérifiée en écrivant la tête 0 puis la tête 1, chacune avec son profil.'))
$btnWCalib.Add_Click({ $script:AfterCalib = ''; if ($cmbWCalMode.SelectedIndex -eq 2) { Start-LevelCalibButton } else { Start-PrecompCalib } })
$tip.SetToolTip($btnWCalib, $tip.GetToolTip($btnWCalib) + "`n" + (T 'Test rapide : mesure seulement le niveau de la disquette insérée, sur la forme de la dernière calibration complète du lecteur ; le profil obtenu est placé dans les champs --precomp, pour cette disquette.'))
$btnWCalReset = New-Object System.Windows.Forms.Button
$btnWCalReset.Text = (T 'Effacer les calibrations'); $btnWCalReset.Location = '555,104'; $btnWCalReset.Size = '195,26'
$tip.SetToolTip($btnWCalReset, (T "Efface toutes les calibrations de précompensation : courbes communes et par tête des familles standard et long track.`nLes profils de famille reprennent leurs valeurs d'origine. Une écriture rapide ou lente recalibre ensuite automatiquement."))
$btnWCalReset.Add_Click({ Reset-CalibProfiles })

# --- Ligne 4 : progression globale de la calibration (toutes passes), visible pendant et apres
$pbWCal = New-Object System.Windows.Forms.ProgressBar
$pbWCal.Location = '12,136'; $pbWCal.Size = '300,16'; $pbWCal.Minimum = 0; $pbWCal.Maximum = 100; $pbWCal.Visible = $false
$lblWCal = New-Object System.Windows.Forms.Label
$lblWCal.Location = '320,137'; $lblWCal.AutoSize = $true; $lblWCal.ForeColor = 'DimGray'; $lblWCal.Visible = $false

$grpWOpt.Controls.AddRange(@($chkWPreErase, $chkWEraseEmpty, $chkWNoVerify, (New-Label (T 'Essais :') '500,26'), $numWRetries, $chkWSlow, $chkWPrecomp, $txtWPrecomp, $chkWPostCheck,
    $lblWPrecomp1, $txtWPrecomp1, (New-Label (T 'Calibration précomp :') '12,109'), $cmbWCalMode, $btnWCalib, $btnWCalReset, $pbWCal, $lblWCal, $lblWRepair, $numWRepair))

# --- Groupe 3 : options avancees (rarement utiles)
$grpWAdv = New-Group (T 'Options avancées') '10,266' '762,74'

$txtWTracks = New-Object System.Windows.Forms.TextBox
$txtWTracks.Location = '70,20'; $txtWTracks.Width = 150
$tip.SetToolTip($txtWTracks, (T "--tracks : sous-ensemble de pistes, ex : c=0-79:h=0-1`nc=0:h=0 pour réécrire uniquement la piste 0 face 0."))
$cmbWDensel = New-Object System.Windows.Forms.ComboBox
$cmbWDensel.Location = '290,20'; $cmbWDensel.Width = 60; $cmbWDensel.DropDownStyle = 'DropDownList'
[void]$cmbWDensel.Items.AddRange(@('(non)','H','L'))
$tip.SetToolTip($cmbWDensel, (T '--densel : force le signal density select (pin 2) sur les lecteurs qui l''exploitent.'))
$txtWFakeIdx = New-Object System.Windows.Forms.TextBox
$txtWFakeIdx.Location = '445,20'; $txtWFakeIdx.Width = 80
$tip.SetToolTip($txtWFakeIdx, (T '--fake-index : simule des impulsions d''index, ex : 300rpm ou 200ms (lecteurs sans capteur d''index).'))
$txtWDiskdefs = New-Object System.Windows.Forms.TextBox
$txtWDiskdefs.Location = '605,20'; $txtWDiskdefs.Width = 110
$btnWDiskdefs = New-Object System.Windows.Forms.Button
$btnWDiskdefs.Text = '...'; $btnWDiskdefs.Location = '718,19'; $btnWDiskdefs.Width = 32
$btnWDiskdefs.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Filter = (T 'diskdefs|*.cfg|Tous|*.*'); $d.InitialDirectory = $script:AppDir
    if ($d.ShowDialog() -eq 'OK') { $txtWDiskdefs.Text = $d.FileName }
})
$chkWReverse = New-Object System.Windows.Forms.CheckBox
$chkWReverse.Text = (T 'Flippy (--reverse)'); $chkWReverse.Location = '12,46'; $chkWReverse.Width = 150
$chkWHard = New-Object System.Windows.Forms.CheckBox
$chkWHard.Text = (T 'Secteurs durs (--hard-sectors)'); $chkWHard.Location = '170,46'; $chkWHard.Width = 210
$chkWTG43 = New-Object System.Windows.Forms.CheckBox
$chkWTG43.Text = (T 'TG43 lecteur 8 pouces (--gen-tg43)'); $chkWTG43.Location = '390,46'; $chkWTG43.Width = 250

$grpWAdv.Controls.AddRange(@((New-Label (T 'Pistes :') '12,23'), $txtWTracks, (New-Label (T 'Densel :') '232,23'), $cmbWDensel,
    (New-Label (T 'Fake index :') '365,23'), $txtWFakeIdx, (New-Label (T 'Diskdefs :') '540,23'), $txtWDiskdefs, $btnWDiskdefs,
    $chkWReverse, $chkWHard, $chkWTG43))

# --- Action
$btnWrite = New-Object System.Windows.Forms.Button
$btnWrite.Text = (T 'ÉCRIRE LA DISQUETTE'); $btnWrite.Location = '10,348'; $btnWrite.Size = '250,40'; $btnWrite.Font = $bold
# Options "comment ecrire" de l ecriture ; la calibration les reprend sans --format ni --diskdefs (Get-CalibDriveArgs, motif HFE)
function Get-WriteFormatArgs {
    $a = @()
    if ($chkWReverse.Checked)    { $a += '--reverse' }
    if ($chkWHard.Checked)       { $a += '--hard-sectors' }
    if ($chkWTG43.Checked)       { $a += '--gen-tg43' }
    if ($cmbWFmt.Text -and $cmbWFmt.Text -ne '(auto)')      { $a += "--format=$($cmbWFmt.Text)" }
    if ($cmbWDensel.Text -ne '(non)') { $a += "--densel=$($cmbWDensel.Text)" }
    if ($txtWFakeIdx.Text.Trim())     { $a += "--fake-index=$($txtWFakeIdx.Text.Trim())" }
    if ($txtWDiskdefs.Text.Trim())    { $a += "--diskdefs=`"$($txtWDiskdefs.Text.Trim())`"" }
    return $a
}

function Start-ImageWrite([switch]$NoWarmup) {
    # Ecriture de l image avec les parametres de l onglet (bouton ECRIRE, ecriture rapide ou lente, fin de calibration automatique)
    # Ecriture lente : prechauffage du lecteur avant la premiere ecriture (Start-WriteWarmup, chaine d ecriture prete) ;
    # NoWarmup : prechauffage passe a la demande de l utilisateur pendant la calibration qui precede
    if (-not (Test-Path -LiteralPath $txtWFile.Text)) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Fichier image introuvable.'),(T 'Erreur'),'OK','Warning'); return
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    # Image flux a plusieurs tours : pistes dont le contenu change d un tour a l autre (bits faibles d une protection),
    # que gw ne reproduit pas (il n ecrit que le premier tour) : avertissement, confirmation, pas de reecriture au controle
    $script:ImageUnstable = $null; $script:ImageSrcWeak = $null; $script:ImageNoJudge = $null; $script:ImageScpFailed = $false
    if (-not $script:Restore -and $script:ScpStatsOk -and [System.IO.Path]::GetExtension($txtWFile.Text).ToLower() -eq '.scp') {
        # Analyse (quelques secondes pour un flux complet) mise en cache par fichier, taille et date
        $uk = @{}; $ck = @{}; $nj = @{}; $failed = $false
        $fi = Get-Item -LiteralPath $txtWFile.Text
        $ckey = "$($fi.FullName)|$($fi.Length)|$($fi.LastWriteTimeUtc.Ticks)"
        if ($script:ScpWeakCache -and $script:ScpWeakCache.Key -eq $ckey) { $uk = $script:ScpWeakCache.Weak.Clone(); $ck = $script:ScpWeakCache.Crit.Clone(); $nj = $script:ScpWeakCache.NoJudge.Clone(); $failed = [bool]$script:ScpWeakCache.Failed }
        else {
            $oldTxt = $stOp.Text; $stOp.Text = (T "Analyse de l'image flux..."); $status.Refresh()
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            try {
                $ts = Read-ScpFile $txtWFile.Text
                foreach ($tn in @($ts.Keys)) {
                    $m = Get-TrackMetrics $ts[$tn]
                    $key = "$([math]::Floor([int]$tn / 2)).$([int]$tn % 2)"
                    # Image jugee aux seuils Standard, comme un original en restauration
                    $lv = if ($m.Bad) { 2 } else { Get-HealthLevel $m.Ooc $m.Dr $m.Stab $m.J 120 250 }
                    if ($m.Weak) { $uk[$key] = $true } elseif ($lv -ge 2) { $ck[$key] = $true }
                    # Courte zone instable (raccord ou protection) ou stabilite non mesurable (un seul tour, densite) : une
                    # zone instable relue sur la copie n y sera pas jugee
                    elseif ($m.ShortUnstable -or $m.Blocks -eq 0) { $nj[$key] = $true }
                }
                $script:ScpWeakCache = @{ Key = $ckey; Weak = $uk.Clone(); Crit = $ck.Clone(); NoJudge = $nj.Clone(); Failed = $false }
            } catch { $failed = $true } finally { $form.Cursor = [System.Windows.Forms.Cursors]::Default; $stOp.Text = $oldTxt }
        }
        if ($uk.Count -gt 0) {
            $lst = Format-TrackList (Sort-TrackKeys @($uk.Keys))
            Append-Log ((T "Image flux : {0} piste(s) changent d'un tour à l'autre ({1}) : bits faibles d'une protection contre la copie probable. gw n'en écrit que le premier tour : la protection risque de ne pas fonctionner sur la disquette écrite. Ces pistes ne sont pas réécrites par le contrôle.") -f "$($uk.Count)", "$lst")
            $q = [System.Windows.Forms.MessageBox]::Show(((T "L'image {0} contient {1} piste(s) dont le contenu change d'un tour à l'autre ({2}) : bits faibles d'une protection contre la copie probable.`n`ngw n'écrit que le premier tour de chaque piste : ces bits seront figés et la protection risque de ne pas fonctionner sur la disquette écrite.`n`nN'écrivez jamais cette image sur une disquette d'origine. Écrire quand même ?") -f "$([System.IO.Path]::GetFileName($txtWFile.Text))", "$($uk.Count)", "$lst"), (T 'Protection contre la copie'), 'YesNo', 'Warning', 'Button2')
            if ($q -ne 'Yes') { Append-Log (T 'Écriture annulée : image protégée non écrite.'); return }
        }
        if ($ck.Count -gt 0) {
            Append-Log ((T "Image flux : {0} piste(s) déjà critique(s) ou illisible(s) dans l'image ({1}) : piste non formatée, protection ou défaut de l'original. gw en écrit le premier tour tel quel : ces pistes ne sont ni réécrites ni comptées par le contrôle.") -f "$($ck.Count)", "$(Format-TrackList (Sort-TrackKeys @($ck.Keys)))")
        }
        $ign = @{}
        foreach ($k in @(@($uk.Keys) + @($ck.Keys))) { $ign[[string]$k] = $true }
        if ($ign.Count -gt 0) { $script:ImageUnstable = $ign }
        $script:ImageSrcWeak = $uk; $script:ImageNoJudge = $nj; $script:ImageScpFailed = $failed
    }
    $slow = $chkWSlow.Checked
    $userTs = $txtWTracks.Text.Trim()
    $heads = @(0, 1)
    if ($slow) {
        $heads = Get-TSpecHeads $userTs
        if ($heads.Count -eq 0) {
            [void][System.Windows.Forms.MessageBox]::Show((T 'Écriture lente : le champ Pistes ne sélectionne ni la tête 0 ni la tête 1.'),(T 'Erreur'),'OK','Warning'); return
        }
        if (-not [regex]::IsMatch(":$userTs", ':\s*h\s*=')) {
            # Sans h= explicite : faces de l image. gw part des pistes du format et h=1 ajouterait la tete 1 d un format
            # simple face (D64, IMG simple face, IPF une face) : avec --erase-empty, toute la face 1 serait effacee.
            $imgSet = Get-ImageTrackSet $txtWFile.Text
            if ($null -ne $imgSet) {
                $present = @{}
                foreach ($k in @($imgSet.Keys)) { $present[[int](($k -split '\.')[1])] = $true }
                $heads = @(@(0, 1) | Where-Object { $present.ContainsKey($_) })
                if ($heads.Count -eq 1) { Append-Log ((T "Écriture lente : image à une seule face, seule la tête {0} est écrite.") -f "$($heads[0])") }
            } elseif ($chkWEraseEmpty.Checked) {
                [void][System.Windows.Forms.MessageBox]::Show(((T "Écriture lente : nombre de faces de l'image inconnu ({0}).`nIndiquer les têtes dans le champ Pistes (h=0-1 pour une image double face, h=0 pour une simple face)`nou décocher « Effacer les pistes vides » : la tête 1 d'un format simple face serait effacée.") -f "$([System.IO.Path]::GetFileName($txtWFile.Text))"),(T 'Erreur'),'OK','Warning'); return
            }
        }
    }
    # $base : toutes les options sauf --tracks et l image (reprises telles quelles par les reecritures ciblees) ;
    # en ecriture lente, sans --precomp : chaque tete a sa commande et sa valeur
    $base = @('write') + (Get-CommonArgs)
    if ($chkWPreErase.Checked)   { $base += '--pre-erase' }
    if ($chkWEraseEmpty.Checked) { $base += '--erase-empty' }
    if ($chkWNoVerify.Checked)   { $base += '--no-verify' }
    $base += "--retries=$($numWRetries.Value)"
    # Mode Auto, image haute densite (format choisi apres l image, par exemple) : profil d origine, jamais un profil
    # calibre (Update-PrecompForImage) ; format revenu en double densite apres coup : profil calibre de nouveau
    if ($cmbWProfile.SelectedIndex -eq 0 -and $chkWPrecomp.Checked) {
        if (Get-HighDensityReason $txtWFile.Text $cmbWFmt.Text) {
            $hdd = if ((Get-ImageFamily $txtWFile.Text) -eq 'long') { $script:PrecompLongDefault } else { $script:PrecompStdDefault }
            if ($txtWPrecomp.Text.Trim() -ne $hdd -or $txtWPrecomp1.Text.Trim() -ne $hdd) { Update-PrecompForImage $txtWFile.Text }
        } elseif ($script:WProfileHd) { Update-PrecompForImage $txtWFile.Text }
    }
    $pc0 = if ($chkWPrecomp.Checked -and $txtWPrecomp.Text.Trim()) { $txtWPrecomp.Text.Trim() } else { $null }
    $pc1 = if ($chkWPrecomp.Checked -and $txtWPrecomp1.Text.Trim()) { $txtWPrecomp1.Text.Trim() } else { $null }
    if (-not $slow -and $pc0) { $base += '--precomp'; $base += $pc0 }
    $base += Get-WriteFormatArgs
    $a = $base
    if ($userTs)      { $a += "--tracks=$userTs" }
    $a += "`"$($txtWFile.Text)`""
    $headPc = $null
    $script:WriteQueue.Clear()
    if ($slow) {
        # Ecriture lente : tete 0 sur tout le disque, puis tete 1 (gw applique --precomp par cylindre seulement).
        # Les champs correspondent aux tetes physiques (calibration) ; hswap : la tete logique h est ecrite par la tete 1 - h.
        $swap = (Get-TSpecExtras $userTs) -match '(^|:)\s*hswap\s*(:|$)'
        $headPc = @{}
        foreach ($h in 0, 1) { $phys = if ($swap) { 1 - $h } else { $h }; $headPc[$h] = if ($phys -eq 0) { $pc0 } else { $pc1 } }
        foreach ($h in $heads) {
            $cmd = @($base); if ($headPc[$h]) { $cmd += '--precomp'; $cmd += $headPc[$h] }
            $script:WriteQueue.Enqueue([string[]]($cmd + @("--tracks=$(Set-TSpecHead $userTs $h)", "`"$($txtWFile.Text)`"")))
        }
        $none = (T 'aucune')
        Append-Log ((T "Écriture lente : {0} commande(s) gw write, tête 0 puis tête 1 ; precomp tête 0 : {1} ; tête 1 : {2}") -f "$($heads.Count)", "$(if ($headPc[0]) { $headPc[0] } else { $none })", "$(if ($headPc[1]) { $headPc[1] } else { $none })")
    }
    # Prechauffage de l ecriture lente (Start-WriteWarmup) : un cylindre sur 10 des pistes ecrites, tetes ecrites
    $warmTs = if ($slow) { Get-WriteWarmupTSpec $userTs ([int[]]$heads) $txtWFile.Text } else { $null }
    $blocker = if ($chkWPostCheck.Checked) { Get-WriteCheckBlocker $txtWFile.Text $cmbWFmt.Text } else { $null }
    if ($blocker) {
        Append-Log ((T "Contrôle de toutes les pistes non applicable ({0}) : l'analyse de flux est calibrée pour le MFM double densité. Écriture sans contrôle.") -f "$blocker")
    }
    if ($chkWPostCheck.Checked -and -not $blocker) {
        # Options de lecteur reprises par les relectures de controle (gw read les accepte toutes)
        $readOpts = @(Get-DriveReadArgs)
        New-WriteCheck $base $txtWFile.Text $userTs ([int]$numWRepair.Value) $readOpts $headPc
        if ($script:ImageUnstable) { $script:Rep.Ignore = $script:ImageUnstable }
        $script:Rep.SrcWeak = $script:ImageSrcWeak; $script:Rep.NoJudge = $script:ImageNoJudge
        # SCP non analyse (module absent, restauration : voir Start-RestoreWrite) ou analyse en echec : rien n est juge
        if ([System.IO.Path]::GetExtension($txtWFile.Text).ToLower() -eq '.scp' -and ($script:ImageScpFailed -or ((-not $script:Restore) -and $null -eq $script:ImageNoJudge))) { $script:Rep.UnstDefect = $false }
        $script:Chain.Clear()
        if ($slow) { for ($i = 0; $i -lt $script:WriteQueue.Count; $i++) { $script:Chain.Enqueue({ Invoke-WriteQueueNext }) } }
        else { $script:WriteArgs = $a; $script:Chain.Enqueue({ Start-Gw $script:WriteArgs }) }
        $script:Chain.Enqueue({ Start-WriteCheck })
        if ($slow) { Start-WriteWarmup $warmTs ([bool]$NoWarmup) } else { Invoke-NextChainStep }
    } elseif ($slow) {
        $script:Chain.Clear()
        for ($i = 0; $i -lt $script:WriteQueue.Count; $i++) { $script:Chain.Enqueue({ Invoke-WriteQueueNext }) }
        if ($script:Restore) { $script:Chain.Enqueue({ Invoke-RestoreNext }) }   # restauration sans controle complet
        Start-WriteWarmup $warmTs ([bool]$NoWarmup)
    } else {
        if ($script:Restore) { $script:Chain.Clear(); $script:Chain.Enqueue({ Invoke-RestoreNext }) }
        Start-Gw $a
    }
}

function Get-CalibState([string]$fam, [bool]$heads, [int]$nCyl = 0) {
    # Etat de la calibration utilisee par l ecriture rapide (courbe commune) ou lente (courbes par tete) :
    #  'ok'      : mesuree sur le motif de test (Method = 'motif') et, par tete, au moins aussi recente que la courbe
    #              commune : sinon Get-FamilyCurves applique la courbe commune aux deux tetes ;
    #  'content' : courbe anterieure au motif, mesuree sur le contenu d une image (biaisee) : refaite ;
    #  'stale'   : courbes par tete anterieures a la calibration commune ;
    #  'short'   : courbe plus courte que l image de nCyl cylindres (> 0) de plus de 4 cylindres (seuil de Get-LevelRef) :
    #              gw appliquerait la valeur de son dernier cylindre a tous les suivants ; refaite. Une courbe plus longue
    #              couvre l image (memes cylindres physiques) : conservee ;
    #  'none'    : absente ou incomplete.
    $keys = @(if ($heads) { "${fam}_h0", "${fam}_h1" } else { $fam })
    $missing = $false
    foreach ($k in $keys) {
        $cv = $script:PrecompCurves[$k]
        if (-not $cv) { $missing = $true } elseif ($cv.Method -ne 'motif') { return 'content' }
    }
    if ($missing) { return 'none' }
    if ($heads -and -not (Test-HeadCurvesCurrent $fam)) { return 'stale' }
    if ($nCyl -gt 0) { foreach ($k in $keys) { if (@($script:PrecompCurves[$k].Values).Count -lt $nCyl - 4) { return 'short' } } }
    return 'ok'
}

function Test-CalibCurrent([string]$fam, [bool]$heads) {
    # Calibration utilisable telle quelle par l ecriture rapide ou lente (voir Get-CalibState)
    return ((Get-CalibState $fam $heads) -eq 'ok')
}

function Set-WritePreset([string]$mode, [string]$path, [string]$source = '') {
    # Parametres d une ecriture rapide ou lente : image entiere, profil Auto, pre-effacement, effacement des pistes vides,
    # verification gw, 10 essais, precomp transmise. Rapide : une commande pour les deux tetes, sans controle complet.
    # Lente : tete 0 puis tete 1 (profils par tete), controle de toutes les pistes, 3 passes de reecriture. Les options
    # de lecteur (flippy, densel, fake index, diskdefs, secteurs durs, TG43) decrivent le materiel : conservees, comme
    # les elements step, h0.off, h1.off et hswap du champ Pistes (seuls c= et h= sont retires : image entiere).
    # Format : ADF -> amiga.amigados, ou amiga.amigados_hd d apres la taille ; image secteur brute (IMG, IMA, ST, DSK
    # sans signature CPC) : format conserve si la meme source (fichier, ou entree d archive : deux ZIP peuvent extraire
    # le meme nom) est deja celle de l onglet Ecriture, sinon (auto) et Start-PresetWrite demande de le choisir ;
    # autres images : (auto), gw deduit le format.
    if (-not $source) { $source = $path }
    $same = ($txtWFile.Text -eq $path -and $script:PresetSource -eq $source)
    $txtWFile.Text = $path; $script:PresetSource = $source
    if ($path -match '\.adf$') { $cmbWFmt.SelectedItem = $(if (Test-AdfHd $path) { 'amiga.amigados_hd' } else { 'amiga.amigados' }) }
    elseif (-not ($same -and (Test-NeedsFormat $path))) { $cmbWFmt.SelectedIndex = 0 }
    $cmbWProfile.SelectedIndex = 0
    # Faces de l image (Get-ImageTrackSet) : inconnues -> pas d effacement des pistes vides, qui effacerait la face 1
    # d une image simple face (gw n ecrit alors que les pistes presentes) ; une seule face en ecriture rapide -> h= de
    # cette face dans Pistes (en lente, Start-ImageWrite n ecrit deja que les faces de l image).
    $extras = Get-TSpecExtras $txtWTracks.Text
    $set = Get-ImageTrackSet $path
    $facesUnknown = ($null -eq $set)
    $oneHead = $null
    if (-not $facesUnknown) {
        $hs = @(@($set.Keys) | ForEach-Object { [int](([string]$_ -split '\.')[1]) } | Sort-Object -Unique)
        if ($hs.Count -eq 1) { $oneHead = $hs[0] }
    }
    $chkWPreErase.Checked = $true; $chkWEraseEmpty.Checked = (-not $facesUnknown); $chkWNoVerify.Checked = $false
    $numWRetries.Value = 10; $chkWPrecomp.Checked = $true
    $txtWTracks.Text = $(if ($mode -ne 'slow' -and $null -ne $oneHead) { "h=$oneHead" + $extras } else { $extras.TrimStart(':') })
    $chkWSlow.Checked = ($mode -eq 'slow')
    if ($mode -eq 'slow') {
        $chkWPostCheck.Checked = $true; $numWRepair.Value = 3
        Append-Log (T 'Écriture lente : image entière, profil Auto, pré-effacement, effacement des pistes vides, vérification gw, 10 essais, tête 0 puis tête 1, contrôle de toutes les pistes, 3 passes de réécriture.')
    } else {
        $chkWPostCheck.Checked = $false
        Append-Log (T 'Écriture rapide : image entière, profil Auto, pré-effacement, effacement des pistes vides, vérification gw, 10 essais, les deux têtes ensemble, sans contrôle complet des pistes.')
        if ($null -ne $oneHead) { Append-Log ((T "Image à une seule face : seule la tête {0} est écrite (h={0} dans Pistes).") -f "$oneHead") }
    }
    if ($facesUnknown) { Append-Log (T "Nombre de faces de l'image inconnu : effacement des pistes vides désactivé (seules les pistes présentes dans l'image sont écrites).") }
    if ($extras) { Append-Log ((T "Champ Pistes : éléments de lecteur conservés ({0}).") -f $extras.TrimStart(':')) }
}

function Start-PresetWrite([string]$mode, [switch]$NoCalib, [switch]$LevelOnly) {
    # Calibration automatique si elle manque pour la famille de l image (commune en rapide, par tete en lente), puis
    # ecriture. Ecriture directe, sans calibration automatique : flux ecrit tel quel (sans --format, gw ne lui applique
    # pas la precompensation), image haute densite, secteurs durs ou lecteur 8 pouces, densite non etablie (conteneur
    # a geometrie libre : IMD, TD0, D88, D64... ; IPF ou HFE dont la cellule sort de la plage mesurable), module
    # d analyse SCP indisponible. NoCalib (restauration) : la calibration existante est conservee, jamais refaite.
    $img = $txtWFile.Text
    if (-not $img -or -not (Test-Path -LiteralPath $img)) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Fichier image introuvable.'),(T 'Erreur'),'OK','Warning'); return
    }
    $ext = [System.IO.Path]::GetExtension($img).ToLower()
    $fmt = $cmbWFmt.Text
    $explicit = ($fmt -and $fmt -ne '(auto)')
    if ((Test-NeedsFormat $img) -and -not $explicit) {
        # Avant toute calibration : gw refuserait l ecriture apres coup (« Sector image requires a disk format »)
        [void][System.Windows.Forms.MessageBox]::Show(((T "Image secteur sans géométrie ({0}) : gw exige le format.`nChoisir le format dans l'onglet Écriture, puis relancer l'écriture.") -f "$ext"),(T 'Format requis'),'OK','Warning'); return
    }
    if (@('.scp', '.raw', '.kf', '.a2r', '.ctr') -contains $ext) { Start-ImageWrite; return }
    $hd = Get-HighDensityReason $img $fmt
    if ($hd) { Append-Log ((T "Image haute densité ({0}) : pas de calibration automatique, écriture avec le profil courant.") -f "$hd"); Start-ImageWrite; return }
    if ($chkWHard.Checked -or $chkWTG43.Checked) { Append-Log (T 'Secteurs durs ou lecteur 8 pouces (TG43) : pas de calibration automatique, écriture avec le profil courant.'); Start-ImageWrite; return }
    # Format gw explicite de la table non calibrable (FM, codage propre, secteurs durs, 360 tr/min, cellule hors plage :
    # Get-FormatCalibInfo, memes regles que la carte Calibration de l Accueil) : pas de calibration automatique ; GCR :
    # ligne « densite non etablie » ci-dessous, inchangee
    $fci = if ($explicit -and $script:GwFormats.Contains($fmt)) { Get-FormatCalibInfo $fmt } else { $null }
    if ($fci -and -not $fci.Cal -and $fmt -notmatch '^(commodore\.15[47]1|mac\.|apple2\.)') { Append-Log ((T "Format {0} non calibrable ({1}) : pas de calibration automatique, écriture avec le profil courant.") -f "$fmt", "$($fci.Why)"); Start-ImageWrite; return }
    $ddKnown =(@('.adf', '.ipf', '.hfe') -contains $ext) -or ($explicit -and $fmt -notmatch '^(commodore\.15[47]1|mac\.|apple2\.)')
    if (-not $ddKnown) { Append-Log ((T "Densité de l'image non établie ({0}, format déduit par gw) : pas de calibration automatique, écriture avec le profil courant.") -f "$ext"); Start-ImageWrite; return }
    $oor = Get-CellOutOfRange $img
    if ($null -ne $oor) { Append-Log ((T "Cellule de l'image hors de la plage mesurable ({0} ns, de 1 700 à 2 300 ns en MFM double densité) : pas de calibration automatique, écriture avec le profil courant.") -f "$oor"); Start-ImageWrite; return }
    if (-not $script:ScpStatsOk) { Append-Log (T "Module d'analyse SCP indisponible : pas de calibration automatique, écriture avec le profil courant."); Start-ImageWrite; return }
    if ($NoCalib) { if ($LevelOnly) { Start-LevelBeforeWrite $mode -Restore; return }; Start-ImageWrite; return }
    # Test rapide : niveau mesure sur la disquette a ecrire, sur la forme de la calibration complete du lecteur
    if ($cmbWCalMode.SelectedIndex -eq 2) { Start-LevelBeforeWrite $mode; return }
    $fam = Get-ImageFamily $img
    $heads = ($mode -eq 'slow')
    # Cylindres de l image, comme la calibration les prendrait (Test-CalibImage) : courbe plus courte refaite ('short')
    $imgCyl = (Get-CalibCylinders $img $fmt).NCyl
    $imgCyl = if ($null -eq $imgCyl) { 80 } else { [math]::Max(2, [math]::Min(84, [int]$imgCyl)) }
    $state = Get-CalibState $fam $heads $imgCyl
    $kind = if ($heads) { (T 'par tête') } else { (T 'commune') }
    if ($state -eq 'ok') {
        # Courbe non convergee gardee apres un « Annuler » : reutilisee, mais signalee
        $nc = @(@($(if ($heads) { @("${fam}_h0", "${fam}_h1") } else { @($fam) })) | Where-Object { $script:PrecompCurves[$_] -and $script:PrecompCurves[$_].Converged -eq $false })
        $kc = @(@($(if ($heads) { @("${fam}_h0", "${fam}_h1") } else { @($fam) })) | Where-Object { $script:PrecompCurves[$_] -and (Get-CurveCalc $script:PrecompCurves[$_]) -ne $script:CalibCalc })
        if ($kc.Count -gt 0) { Append-Log ((T "Calibration {0} de la famille {1} faite avec le calcul {2} : écriture avec cette courbe, conservée à votre demande. Pour la refaire avec le calcul actuel, bouton « Calibrer » de l'onglet Écriture.") -f "$kind", (Get-CalibFamilyName $fam), (Get-CurveCalcText $script:PrecompCurves[$kc[0]] -Plain)) }
        if ($nc.Count -gt 0) { Append-Log ((T "Calibration {0} de la famille {1} non convergée ({2}) : écriture avec cette courbe. Pour la refaire, bouton « Calibrer » de l'onglet Écriture, de préférence en test fin.") -f "$kind", (Get-CalibFamilyName $fam), "$($script:PrecompCurves[$nc[0]].Date)") }
        Start-ImageWrite; return
    }
    switch ($state) {
        'content' { Append-Log ((T "La calibration {0} de la famille {1} a été mesurée sur le contenu d'une image, avant le motif de test : elle est refaite.") -f "$kind", (Get-CalibFamilyName $fam)) }
        'stale'   { Append-Log ((T "Courbes par tête de la famille {0} antérieures à la calibration commune : elles sont refaites.") -f (Get-CalibFamilyName $fam)) }
        'short'   {
            $sk = @(if ($heads) { "${fam}_h0", "${fam}_h1" } else { $fam }) | ForEach-Object { @($script:PrecompCurves[$_].Values).Count } | Measure-Object -Minimum
            Append-Log ((T "Calibration {0} de la famille {1} mesurée sur {2} cylindres seulement, image de {3} cylindres : elle est refaite.") -f "$kind", (Get-CalibFamilyName $fam), "$($sk.Minimum)", "$imgCyl")
        }
        default   { Append-Log ((T "Aucune calibration {0} pour la famille {1} : calibration automatique, puis écriture.") -f "$kind", (Get-CalibFamilyName $fam)) }
    }
    $script:AfterCalib = 'write'
    Start-PrecompCalib
    if (-not $script:Cal) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : la calibration n''a pas été lancée.') }
}

$btnWrite.Add_Click({ Start-ImageWrite })

$lblWProfileInfo = New-Object System.Windows.Forms.Label
$lblWProfileInfo.Location = '270,348'; $lblWProfileInfo.Size = '502,40'; $lblWProfileInfo.Anchor = 'Top,Left,Right'
$lblWProfileInfo.ForeColor = 'DimGray'; $lblWProfileInfo.Text = (T 'Choisissez une image : le format et la précompensation seront déduits automatiquement.')

$tabW.Controls.AddRange(@($grpWImage, $grpWOpt, $grpWAdv, $btnWrite, $lblWProfileInfo, $chkWWarm))
$tabW.AutoScroll = $true                                  # fenetre basse ou journal agrandi : defilement plutot que bouton masque

# ============================== LECTURE ========================================
$tabR = New-TabPage (T 'Lecture / Dump')

$txtRFile = New-Object System.Windows.Forms.TextBox
$txtRFile.Location = '90,13'; $txtRFile.Width = 650; $txtRFile.Anchor = 'Top,Left,Right'
$btnRFile = New-Object System.Windows.Forms.Button
$btnRFile.Text = '...'; $btnRFile.Location = '745,12'; $btnRFile.Width = 30; $btnRFile.Anchor = 'Top,Right'

$cmbRFmt = New-Object System.Windows.Forms.ComboBox
$cmbRFmt.Location = '90,43'; $cmbRFmt.Width = 200
[void]$cmbRFmt.Items.AddRange($Formats)

$btnRFile.Add_Click({
    $d = New-Object System.Windows.Forms.SaveFileDialog
    $d.Filter = (T 'Flux SCP (préservation)|*.scp|ADF (AmigaDOS)|*.adf|Kryoflux stream|*.raw|HFE|*.hfe|Tous|*.*')
    if ($txtRFile.Text) { $p = Split-Path -Parent $txtRFile.Text; if ($p -and (Test-Path -LiteralPath $p)) { $d.InitialDirectory = $p } }
    elseif ($txtLibRoot.Text -and (Test-Path -LiteralPath $txtLibRoot.Text)) { $d.InitialDirectory = $txtLibRoot.Text }
    if ($d.ShowDialog() -eq 'OK') {
        $txtRFile.Text = $d.FileName
        if ($d.FileName -match '\.adf$') { $cmbRFmt.SelectedItem = 'amiga.amigados' } else { $cmbRFmt.SelectedIndex = 0 }
    }
})

$numRevs = New-Object System.Windows.Forms.NumericUpDown
$numRevs.Location = '110,74'; $numRevs.Width = 55
$numRevs.Minimum = 1; $numRevs.Maximum = 30
$tip.SetToolTip($numRevs, (T 'Tours lus par piste. 5 recommandés pour l''archivage flux (SCP).'))

$numRRetries = New-Object System.Windows.Forms.NumericUpDown
$numRRetries.Location = '255,74'; $numRRetries.Width = 55
$numRRetries.Minimum = 0; $numRRetries.Maximum = 50

$txtRTracks = New-Object System.Windows.Forms.TextBox
$txtRTracks.Location = '415,74'; $txtRTracks.Width = 160

$chkRRaw = New-Object System.Windows.Forms.CheckBox
$chkRRaw.Text = (T 'Flux brut (--raw)'); $chkRRaw.Location = '90,105'; $chkRRaw.Width = 290
$chkRRev = New-Object System.Windows.Forms.CheckBox
$chkRRev.Text = (T 'Face B flippy (--reverse)'); $chkRRev.Location = '390,105'; $chkRRev.Width = 100

$cmbRDensel = New-Object System.Windows.Forms.ComboBox
$cmbRDensel.Location = '90,135'; $cmbRDensel.Width = 60; $cmbRDensel.DropDownStyle = 'DropDownList'
[void]$cmbRDensel.Items.AddRange(@('(non)','H','L'))

$txtRDiskdefs = New-Object System.Windows.Forms.TextBox
$txtRDiskdefs.Location = '250,135'; $txtRDiskdefs.Width = 325
$btnRDiskdefs = New-Object System.Windows.Forms.Button
$btnRDiskdefs.Text = '...'; $btnRDiskdefs.Location = '580,134'; $btnRDiskdefs.Width = 30
$btnRDiskdefs.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Filter = (T 'diskdefs|*.cfg|Tous|*.*'); $d.InitialDirectory = $script:AppDir
    if ($d.ShowDialog() -eq 'OK') { $txtRDiskdefs.Text = $d.FileName }
})

$btnRead = New-Object System.Windows.Forms.Button
$btnRead.Text = (T 'LIRE LA DISQUETTE'); $btnRead.Location = '90,175'; $btnRead.Size = '250,40'; $btnRead.Font = $bold
$btnRead.Add_Click({
    if (-not $txtRFile.Text.Trim()) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Indiquez un fichier de sortie.'),(T 'Erreur'),'OK','Warning'); return
    }
    $a = @('read') + (Get-CommonArgs)
    $a += "--revs=$($numRevs.Value)"
    $a += "--retries=$($numRRetries.Value)"
    $outExt = [System.IO.Path]::GetExtension($txtRFile.Text.Trim().Trim('"')).ToLower()
    $fmtSet = ($cmbRFmt.Text -and $cmbRFmt.Text -ne '(auto)')
    $raw = $chkRRaw.Checked
    if (@('.scp', '.raw') -contains $outExt -and $fmtSet -and -not $raw) {
        # Sans --raw, gw enregistre un flux reconstitue a partir des secteurs decodes (read.py) : choix laisse a l utilisateur
        Append-Log (T 'Lecture : flux avec un format, sans « Flux brut » : gw enregistre un flux reconstitué à partir des secteurs décodés ; les pistes protégées ou illisibles ne sont pas conservées telles quelles. Cochez « Flux brut (--raw) » pour garder le flux réel.')
    }
    if (@('.adf', '.img', '.ima', '.st', '.dsk') -contains $outExt -and $raw) { $raw = $false; Append-Log (T 'Lecture : image secteur, --raw ignoré (gw le refuse pour ce type de fichier).') }
    if ($raw) { $a += '--raw' }
    if ($chkRRev.Checked) { $a += '--reverse' }
    if ($cmbRFmt.Text -and $cmbRFmt.Text -ne '(auto)') { $a += "--format=$($cmbRFmt.Text)" }
    if ($txtRTracks.Text.Trim())      { $a += "--tracks=$($txtRTracks.Text.Trim())" }
    if ($cmbRDensel.Text -ne '(non)') { $a += "--densel=$($cmbRDensel.Text)" }
    if ($txtRDiskdefs.Text.Trim())    { $a += "--diskdefs=`"$($txtRDiskdefs.Text.Trim())`"" }
    $a += "`"$($txtRFile.Text)`""
    Start-Gw $a
})

$tabR.Controls.AddRange(@((New-Label (T 'Sortie :') '10,17'), $txtRFile, $btnRFile,
    (New-Label (T 'Format :') '10,47'), $cmbRFmt,
    (New-Label (T 'Tours :') '10,77'), $numRevs,
    (New-Label (T 'Essais :') '190,77'), $numRRetries,
    (New-Label (T 'Pistes :') '355,77'), $txtRTracks,
    $chkRRaw, $chkRRev,
    (New-Label (T 'Densel :') '10,138'), $cmbRDensel,
    (New-Label (T 'Diskdefs :') '165,138'), $txtRDiskdefs, $btnRDiskdefs,
    $btnRead))

# ============================== CONVERSION =====================================
$tabCv = New-TabPage 'Conversion'

$txtCvIn = New-Object System.Windows.Forms.TextBox
$txtCvIn.Location = '90,13'; $txtCvIn.Width = 650; $txtCvIn.Anchor = 'Top,Left,Right'
$btnCvIn = New-Object System.Windows.Forms.Button
$btnCvIn.Text = '...'; $btnCvIn.Location = '745,12'; $btnCvIn.Width = 30; $btnCvIn.Anchor = 'Top,Right'
$btnCvIn.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Filter = (T 'Images disquette|*.scp;*.raw;*.ipf;*.adf;*.hfe;*.img;*.st;*.dsk|Tous|*.*')
    if ($txtCvIn.Text) { $p = Split-Path -Parent $txtCvIn.Text; if ($p -and (Test-Path -LiteralPath $p)) { $d.InitialDirectory = $p } }
    if ($d.ShowDialog() -eq 'OK') { $txtCvIn.Text = $d.FileName }
})

$cmbCvFmt = New-Object System.Windows.Forms.ComboBox
$cmbCvFmt.Location = '90,75'; $cmbCvFmt.Width = 200
[void]$cmbCvFmt.Items.AddRange($Formats)
$tip.SetToolTip($cmbCvFmt, (T 'Format de décodage. Nécessaire pour passer d''un flux (SCP/RAW) à un format secteur (ADF).'))

$txtCvOut = New-Object System.Windows.Forms.TextBox
$txtCvOut.Location = '90,43'; $txtCvOut.Width = 650; $txtCvOut.Anchor = 'Top,Left,Right'
$btnCvOut = New-Object System.Windows.Forms.Button
$btnCvOut.Text = '...'; $btnCvOut.Location = '745,42'; $btnCvOut.Width = 30; $btnCvOut.Anchor = 'Top,Right'
$btnCvOut.Add_Click({
    $d = New-Object System.Windows.Forms.SaveFileDialog
    $d.Filter = (T 'ADF|*.adf|SCP|*.scp|HFE|*.hfe|IMG|*.img|Tous|*.*')
    if ($d.ShowDialog() -eq 'OK') {
        $txtCvOut.Text = $d.FileName
        if ($d.FileName -match '\.adf$') { $cmbCvFmt.SelectedItem = 'amiga.amigados' }
    }
})

$txtCvTracks = New-Object System.Windows.Forms.TextBox
$txtCvTracks.Location = '415,75'; $txtCvTracks.Width = 160

$btnConvert = New-Object System.Windows.Forms.Button
$btnConvert.Text = (T 'CONVERTIR'); $btnConvert.Location = '90,120'; $btnConvert.Size = '250,40'; $btnConvert.Font = $bold
$btnConvert.Add_Click({
    if (-not (Test-Path -LiteralPath $txtCvIn.Text)) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Fichier source introuvable.'),(T 'Erreur'),'OK','Warning'); return
    }
    if (-not $txtCvOut.Text.Trim()) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Indiquez un fichier de destination.'),(T 'Erreur'),'OK','Warning'); return
    }
    # convert ne pilote pas le lecteur : pas de --drive ni --device
    $a = @('convert')
    if ($cmbCvFmt.Text -and $cmbCvFmt.Text -ne '(auto)') { $a += "--format=$($cmbCvFmt.Text)" }
    if ($txtCvTracks.Text.Trim()) { $a += "--tracks=$($txtCvTracks.Text.Trim())" }
    $a += "`"$($txtCvIn.Text)`""
    $a += "`"$($txtCvOut.Text)`""
    Start-Gw $a
})

$tabCv.Controls.AddRange(@((New-Label (T 'Source :') '10,17'), $txtCvIn, $btnCvIn,
    (New-Label (T 'Destination :') '10,47'), $txtCvOut, $btnCvOut,
    (New-Label (T 'Format :') '10,78'), $cmbCvFmt,
    (New-Label (T 'Pistes :') '355,78'), $txtCvTracks, $btnConvert))

# ============================== COMPARAISON ====================================
$tabCmp = New-TabPage (T 'Comparaison')

$txtCmpRef = New-Object System.Windows.Forms.TextBox
$txtCmpRef.Location = '90,13'; $txtCmpRef.Width = 650; $txtCmpRef.Anchor = 'Top,Left,Right'
$btnCmpRef = New-Object System.Windows.Forms.Button
$btnCmpRef.Text = '...'; $btnCmpRef.Location = '745,12'; $btnCmpRef.Width = 30; $btnCmpRef.Anchor = 'Top,Right'
$btnCmpRef.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Filter = (T 'Images disquette|*.ipf;*.adf;*.scp;*.hfe;*.img;*.st;*.dsk;*.raw;*.d64;*.imd|Tous|*.*')
    if ($txtCmpRef.Text) { $p = Split-Path -Parent $txtCmpRef.Text; if ($p -and (Test-Path -LiteralPath $p)) { $d.InitialDirectory = $p } }
    if ($d.ShowDialog() -eq 'OK') { $txtCmpRef.Text = $d.FileName }
})

$cmbCmpFmt = New-Object System.Windows.Forms.ComboBox
$cmbCmpFmt.Location = '90,43'; $cmbCmpFmt.Width = 200
[void]$cmbCmpFmt.Items.AddRange(($Formats | Where-Object { $_ -ne '(auto)' }))
$tip.SetToolTip($cmbCmpFmt, (T "Format de décodage commun : la référence est convertie dans ce format,`nla disquette est lue dans ce format, puis les deux sont comparées octet par octet."))

$numCmpRetries = New-Object System.Windows.Forms.NumericUpDown
$numCmpRetries.Location = '365,43'; $numCmpRetries.Width = 55
$numCmpRetries.Minimum = 0; $numCmpRetries.Maximum = 50

$btnCmpFromWrite = New-Object System.Windows.Forms.Button
$btnCmpFromWrite.Text = (T 'Reprendre l''image de l''onglet Écriture'); $btnCmpFromWrite.Location = '440,41'; $btnCmpFromWrite.Size = '280,26'
$btnCmpFromWrite.Add_Click({
    if ($txtWFile.Text) {
        $txtCmpRef.Text = $txtWFile.Text
        if ($cmbWFmt.Text -and $cmbWFmt.Text -ne '(auto)') { Set-Combo $cmbCmpFmt $cmbWFmt.Text }
    }
})

$btnCompare = New-Object System.Windows.Forms.Button
$btnCompare.Text = (T 'COMPARER LA DISQUETTE'); $btnCompare.Location = '90,80'; $btnCompare.Size = '250,40'; $btnCompare.Font = $bold
$btnCompare.Add_Click({ try { Start-Compare } catch { Append-Log ((T "ERREUR comparaison : {0}") -f "$($_.Exception.Message)") } })

$txtCmpResult = New-Object System.Windows.Forms.TextBox
$txtCmpResult.Location = '10,130'; $txtCmpResult.Size = '768,190'
$txtCmpResult.Anchor = 'Top,Bottom,Left,Right'
$txtCmpResult.Multiline = $true; $txtCmpResult.ReadOnly = $true; $txtCmpResult.Font = $monoBig; $txtCmpResult.ForeColor = [System.Drawing.Color]::FromArgb(40,44,52)
$txtCmpResult.ScrollBars = 'Vertical'; $txtCmpResult.WordWrap = $false
$txtCmpResult.BackColor = [System.Drawing.SystemColors]::Control

$tabCmp.Controls.AddRange(@((New-Label (T 'Référence :') '10,17'), $txtCmpRef, $btnCmpRef,
    (New-Label (T 'Format :') '10,47'), $cmbCmpFmt, (New-Label (T 'Essais :') '305,47'), $numCmpRetries, $btnCmpFromWrite,
    $btnCompare, $txtCmpResult))

# ============================== QUALITE & ALIGNEMENT ===========================
$tabAl = New-TabPage (T 'Qualité & alignement')

$script:AlColors = @{
    0 = [System.Drawing.Color]::FromArgb(86, 196, 108)    # excellent (vert franc)
    1 = [System.Drawing.Color]::FromArgb(188, 214, 94)    # bon (vert-jaune)
    2 = [System.Drawing.Color]::FromArgb(245, 176, 66)    # moyen (orange)
    3 = [System.Drawing.Color]::FromArgb(233, 86, 80)     # mauvais (rouge)
}
# texte lisible (noir ou blanc) sur chaque couleur d'etat
$script:AlFg = @{
    0 = [System.Drawing.Color]::FromArgb(14, 46, 20)
    1 = [System.Drawing.Color]::FromArgb(40, 44, 10)
    2 = [System.Drawing.Color]::FromArgb(54, 32, 0)
    3 = [System.Drawing.Color]::White
}
$script:AlNames = @{ 0='EXCELLENT'; 1=(T 'BON'); 2=(T 'MOYEN'); 3=(T 'MAUVAIS') }

$cmbAlPreset = New-Object System.Windows.Forms.ComboBox
$cmbAlPreset.Location = '70,11'; $cmbAlPreset.Width = 160; $cmbAlPreset.DropDownStyle = 'DropDownList'
[void]$cmbAlPreset.Items.AddRange(@((T 'Rapide (5 cylindres)'),(T 'Standard (0-70 pas 10)'),(T 'Complet (0-79)'),(T 'Personnalisé')))
$tip.SetToolTip($cmbAlPreset, (T "Rapide : contrôle en 30 s. Standard : tri de collection. Complet : état exhaustif d'une disquette (2-3 min)."))
$cmbAlPreset.Add_SelectedIndexChanged({
    switch ($cmbAlPreset.SelectedIndex) {
        0 { $txtAlCyls.Text = '0,20,40,60,79' }
        1 { $txtAlCyls.Text = '0,10,20,30,40,50,60,70' }
        2 { $txtAlCyls.Text = (0..79) -join ',' }
    }
})

$txtAlCyls = New-Object System.Windows.Forms.TextBox
$txtAlCyls.Location = '305,11'; $txtAlCyls.Width = 170
$tip.SetToolTip($txtAlCyls, (T 'Cylindres mesurés (0-83), séparés par des virgules.'))
$txtAlCyls.Add_TextChanged({ if ($cmbAlPreset.SelectedIndex -ne 3 -and $txtAlCyls.Focused) { $cmbAlPreset.SelectedIndex = 3 } })

$cmbAlHead = New-Object System.Windows.Forms.ComboBox
$cmbAlHead.Location = '530,11'; $cmbAlHead.Width = 55; $cmbAlHead.DropDownStyle = 'DropDownList'
[void]$cmbAlHead.Items.AddRange(@('0','1','0+1'))

$numAlRevs = New-Object System.Windows.Forms.NumericUpDown
$numAlRevs.Location = '645,11'; $numAlRevs.Width = 45
$numAlRevs.Minimum = 1; $numAlRevs.Maximum = 10
$tip.SetToolTip($numAlRevs, (T 'Tours lus par piste. 3 suffit ; 5 pour une disquette douteuse.'))

$chkAlLoop = New-Object System.Windows.Forms.CheckBox
$chkAlLoop.Text = (T 'Continu'); $chkAlLoop.Location = '700,12'; $chkAlLoop.Width = 75
$tip.SetToolTip($chkAlLoop, (T 'Répète la mesure en boucle (réglage mécanique). STOP pour arrêter.'))
$numAlPause = New-Object System.Windows.Forms.NumericUpDown
$numAlPause.Location = '700,36'; $numAlPause.Width = 45; $numAlPause.Visible = $false
$numAlPause.Minimum = 0; $numAlPause.Maximum = 60

$btnAlStart = New-Object System.Windows.Forms.Button
$btnAlStart.Text = (T 'MESURER LA DISQUETTE'); $btnAlStart.Location = '10,40'; $btnAlStart.Size = '220,40'; $btnAlStart.Font = $bold
$tip.SetToolTip($btnAlStart, (T 'Lit les cylindres choisis avec le lecteur sélectionné en haut et évalue l''état du support et la qualité de lecture.'))
$btnAlStart.Add_Click({
    if (-not $script:ScpStatsOk) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Le module d''analyse SCP n''a pas pu être compilé (Add-Type).'),(T 'Mesure'),'OK','Warning'); return
    }
    $script:AlignLoop = [bool]$chkAlLoop.Checked
    $script:AlLastMove = 0
    Start-AlignCycle
})

$btnAlRef = New-Object System.Windows.Forms.Button
$btnAlRef.Text = (T 'Fixer comme référence'); $btnAlRef.Location = '240,40'; $btnAlRef.Size = '175,40'
$tip.SetToolTip($btnAlRef, (T "Mémorise la dernière mesure comme référence (ex. : lecteur Amiga sur la même disquette).`nLes mesures suivantes affichent l'écart en %."))
$btnAlRef.Add_Click({
    if (-not $script:AlignLast) { [void][System.Windows.Forms.MessageBox]::Show((T 'Faites d''abord une mesure.'),(T 'Référence'),'OK','Information'); return }
    $script:AlignRef = $script:AlignLast.Clone()
    $script:AlignRefLabel = ((T "lecteur {0}, tête {1}, {2}") -f "$($cmbDrive.Text)", "$($cmbAlHead.Text)", "$(Get-Date -Format 'dd/MM HH:mm')")
    $lblAlRef.Text = ((T "Référence : {0} ({1} piste(s))") -f "$($script:AlignRefLabel)", "$($script:AlignRef.Count)")
    Append-Log ((T "Mesure : référence fixée ({0}).") -f "$($script:AlignRefLabel)")
    [void](Save-Config)
    Render-AlignBars
})

$btnAlReset = New-Object System.Windows.Forms.Button
$btnAlReset.Text = (T 'Réinitialiser'); $btnAlReset.Location = '424,40'; $btnAlReset.Size = '120,40'
$tip.SetToolTip($btnAlReset, (T 'Efface le meilleur score, la tendance, la référence et le guide.'))
$btnAlReset.Add_Click({
    $script:AlignBest = @{}; $script:AlignPrev = $null; $script:AlignRef = $null; $script:AlignLast = $null
    $script:AlPos = $null; $script:AlLastMove = 0; $script:AlPosScores = @{}; $script:AlignRefLabel = ''
    $lblAlRef.Text = (T 'Aucune référence'); $lblAlHealth.Text = (T 'Lancez une mesure'); $lblAlHealth.BackColor = [System.Drawing.SystemColors]::Control
    $lblAlVerdict.Text = ''; $lblAlVerdict.BackColor = [System.Drawing.SystemColors]::Control
    $lblAlPos.Text = ''; $lblAlReco.Text = ''
    $lvAl.Items.Clear(); $pnlAlBars.Invalidate()
})

$chkAlGuide = New-Object System.Windows.Forms.CheckBox
$chkAlGuide.Text = (T 'Mode réglage du lecteur (guide)'); $chkAlGuide.Location = '556,48'; $chkAlGuide.Width = 220
$tip.SetToolTip($chkAlGuide, (T 'Affiche les boutons du guide d''alignement (positions du stepper, recommandations avancer/reculer).'))
$chkAlGuide.Add_CheckedChanged({
    $v = $chkAlGuide.Checked
    $btnAlPos0.Visible = $v; $btnAlPlus.Visible = $v; $btnAlMinus.Visible = $v; $lblAlPos.Visible = $v; $lblAlReco.Visible = $v
    $numAlPause.Visible = $v
})

$lblAlRef = New-Object System.Windows.Forms.Label
$lblAlRef.Location = '10,78'; $lblAlRef.AutoSize = $true; $lblAlRef.Text = (T 'Aucune référence'); $lblAlRef.ForeColor = 'Gray'

# --- Guide (visible en mode reglage)
$btnAlPos0 = New-Object System.Windows.Forms.Button
$btnAlPos0.Text = (T 'Repère (position 0)'); $btnAlPos0.Location = '10,96'; $btnAlPos0.Size = '155,26'; $btnAlPos0.Visible = $false
$tip.SetToolTip($btnAlPos0, (T "Point de départ : stepper à sa position d'origine (trait de repère). Mesure la position 0 et démarre le guide."))
$btnAlPos0.Add_Click({ $script:AlPos = 0; $script:AlLastMove = 0; $script:AlPosScores = @{}; $script:AlignLoop = $false; Start-AlignCycle })
$btnAlPlus = New-Object System.Windows.Forms.Button
$btnAlPlus.Text = (T "J'ai tourné +1 cran"); $btnAlPlus.Location = '172,96'; $btnAlPlus.Size = '160,26'; $btnAlPlus.Visible = $false
$tip.SetToolTip($btnAlPlus, (T "À cliquer APRÈS avoir tourné le stepper d'un petit cran dans le sens '+'. Lance la mesure."))
$btnAlPlus.Add_Click({ if ($null -eq $script:AlPos) { $script:AlPos = 0 }; $script:AlPos += 1; $script:AlLastMove = 1; $script:AlignLoop = $false; Start-AlignCycle })
$btnAlMinus = New-Object System.Windows.Forms.Button
$btnAlMinus.Text = (T "J'ai tourné -1 cran"); $btnAlMinus.Location = '339,96'; $btnAlMinus.Size = '160,26'; $btnAlMinus.Visible = $false
$tip.SetToolTip($btnAlMinus, (T "À cliquer APRÈS avoir tourné le stepper d'un petit cran dans le sens '-'. Lance la mesure."))
$btnAlMinus.Add_Click({ if ($null -eq $script:AlPos) { $script:AlPos = 0 }; $script:AlPos -= 1; $script:AlLastMove = -1; $script:AlignLoop = $false; Start-AlignCycle })
$lblAlPos = New-Object System.Windows.Forms.Label
$lblAlPos.Location = '508,101'; $lblAlPos.AutoSize = $true; $lblAlPos.Text = ''; $lblAlPos.ForeColor = 'Gray'; $lblAlPos.Visible = $false

# --- Verdict 1 : etat du support (la question d'un collectionneur)
$lblAlHealth = New-Object System.Windows.Forms.Label
$lblAlHealth.Location = '10,126'; $lblAlHealth.Size = '768,34'; $lblAlHealth.Anchor = 'Top,Left,Right'
$lblAlHealth.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
$lblAlHealth.TextAlign = 'MiddleCenter'; $lblAlHealth.BorderStyle = 'FixedSingle'
$lblAlHealth.Text = (T 'Lancez une mesure')
$tip.SetToolTip($lblAlHealth, (T "État du support : basé uniquement sur les erreurs, les trous de signal, la stabilité entre tours et le jitter.`nIndépendant du contenu : comparable d'une disquette à l'autre."))

# --- Verdict 2 : qualite de lecture (score, pour comparer lecteurs et reglages)
$lblAlVerdict = New-Object System.Windows.Forms.Label
$lblAlVerdict.Location = '10,163'; $lblAlVerdict.Size = '768,24'; $lblAlVerdict.Anchor = 'Top,Left,Right'
$lblAlVerdict.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$lblAlVerdict.TextAlign = 'MiddleCenter'
$lblAlVerdict.Text = ''
$tip.SetToolTip($lblAlVerdict, (T "Score de qualité de lecture (plus bas = mieux). Dépend du contenu : à comparer uniquement sur une même image`n(deux lecteurs, deux précompensations, deux réglages)."))

$lblAlReco = New-Object System.Windows.Forms.Label
$lblAlReco.Location = '10,188'; $lblAlReco.Size = '768,20'; $lblAlReco.Anchor = 'Top,Left,Right'
$lblAlReco.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$lblAlReco.TextAlign = 'MiddleCenter'; $lblAlReco.Text = ''; $lblAlReco.ForeColor = 'DimGray'; $lblAlReco.Visible = $false

$pnlAlBars = New-Object System.Windows.Forms.Panel
$pnlAlBars.Location = '10,210'; $pnlAlBars.Size = '768,50'; $pnlAlBars.Anchor = 'Top,Left,Right'
$pnlAlBars.BackColor = 'White'; $pnlAlBars.BorderStyle = 'FixedSingle'
$pnlAlBars.Add_Paint({ Draw-AlignBars $_.Graphics $pnlAlBars.ClientSize })
$pnlAlBars.Add_Resize({ $pnlAlBars.Invalidate() })
$tip.SetToolTip($pnlAlBars, (T 'Score par cylindre : barre courte = bon. Trait noir = référence, trait bleu = meilleur vu.'))

$lvAl = New-Object System.Windows.Forms.ListView
$lvAl.Location = '10,266'; $lvAl.Size = '768,60'; $lvAl.Anchor = 'Top,Bottom,Left,Right'
$lvAl.View = 'Details'; $lvAl.FullRowSelect = $true; $lvAl.GridLines = $false; $lvAl.Font = $monoBig
$lvAl.OwnerDraw = $true; $lvAl.HeaderStyle = 'Nonclickable'
$lvAl.BackColor = [System.Drawing.Color]::White
$lvAl.Add_DrawColumnHeader({
    param($s0, $e)
    $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($script:Theme.Accent2)), $e.Bounds)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.LineAlignment = 'Center'; $fmt.Alignment = $(if ($e.ColumnIndex -eq 0) { 'Near' } else { 'Center' })
    $r = [System.Drawing.RectangleF]::new($e.Bounds.X + 4, $e.Bounds.Y, $e.Bounds.Width - 8, $e.Bounds.Height)
    $e.Graphics.DrawString($e.Header.Text, $bold, [System.Drawing.Brushes]::White, $r, $fmt)
})
$lvAl.Add_DrawSubItem({
    param($s0, $e)
    $row = $e.Item.Index
    $baseBg = if ($row % 2) { [System.Drawing.Color]::FromArgb(243, 246, 250) } else { [System.Drawing.Color]::White }
    $bg = if ($e.SubItem.BackColor -ne [System.Drawing.Color]::Empty -and $e.SubItem.BackColor.ToArgb() -ne [System.Drawing.SystemColors]::Window.ToArgb() -and $e.SubItem.BackColor.ToArgb() -ne 0) { $e.SubItem.BackColor } else { $baseBg }
    $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($bg)), $e.Bounds)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(225, 229, 235))
    $e.Graphics.DrawLine($pen, $e.Bounds.Right - 1, $e.Bounds.Top, $e.Bounds.Right - 1, $e.Bounds.Bottom)
    $fg = if ($e.SubItem.ForeColor -ne [System.Drawing.Color]::Empty) { $e.SubItem.ForeColor } else { [System.Drawing.Color]::FromArgb(32, 36, 44) }
    $fnt = if ($e.SubItem.Font) { $e.SubItem.Font } else { $lvAl.Font }
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.LineAlignment = 'Center'; $fmt.Alignment = $(if ($e.ColumnIndex -eq 0) { 'Near' } else { 'Center' })
    $fmt.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap; $fmt.Trimming = 'EllipsisCharacter'
    $r = [System.Drawing.RectangleF]::new($e.Bounds.X + 4, $e.Bounds.Y, $e.Bounds.Width - 8, $e.Bounds.Height)
    $e.Graphics.DrawString($e.SubItem.Text, $fnt, (New-Object System.Drawing.SolidBrush($fg)), $r, $fmt)
})
$imgRow = New-Object System.Windows.Forms.ImageList
$imgRow.ImageSize = New-Object System.Drawing.Size(1, 24)
$lvAl.SmallImageList = $imgRow
foreach ($c in @(@((T 'Piste'),60),@((T 'État'),140),@((T 'Erreurs'),70),@((T 'Trous'),78),@('Stab',55),@((T 'Jitter ns'),80),@('Score',65),@((T 'vs réf'),70),@('Asym.',70),@((T 'Cell ns'),75))) {
    [void]$lvAl.Columns.Add($c[0], $c[1])
}

$tabAl.Controls.AddRange(@((New-Label (T 'Mesure :') '10,14'), $cmbAlPreset, (New-Label (T 'Cylindres :') '238,14'), $txtAlCyls,
    (New-Label (T 'Têtes :') '488,14'), $cmbAlHead, (New-Label (T 'Tours :') '598,14'), $numAlRevs, $chkAlLoop, $numAlPause,
    $btnAlStart, $btnAlRef, $btnAlReset, $chkAlGuide, $lblAlRef,
    $btnAlPos0, $btnAlPlus, $btnAlMinus, $lblAlPos, $lblAlHealth, $lblAlVerdict, $lblAlReco, $pnlAlBars, $lvAl))

# ============================== OUTILS =========================================
$tabT = New-TabPage (T 'Outils')

function New-ToolButton($text, $loc, $onClick) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Location = $loc; $b.Size = '220,34'; $b.TextAlign = 'MiddleLeft'
    $b.Add_Click($onClick)
    return $b
}

$btnInfo  = New-ToolButton (T 'Tester la carte (info)')   '15,15'  { $a = @('info'); if ($txtDev.Text.Trim()) { $a += "--device=$($txtDev.Text.Trim())" }; Start-Gw $a }
$btnRpm   = New-ToolButton (T 'Mesurer la vitesse (rpm)') '15,52'  { Start-Gw (@('rpm') + (Get-CommonArgs)) }
$btnBw    = New-ToolButton (T 'Débit USB (bandwidth)')    '15,89'  { Start-Gw @('bandwidth') }
$btnReset = New-ToolButton (T 'Réinitialiser la carte (reset)') '15,126' { Start-Gw @('reset') }

$btnUpdate = New-ToolButton (T 'Mise à jour firmware') '15,163' {
    $r = [System.Windows.Forms.MessageBox]::Show(
        (T "Mettre à jour le firmware du Greaseweazle ?`nNe pas débrancher pendant l'opération."),
        'gw update', 'YesNo', 'Warning')
    if ($r -eq 'Yes') { Start-Gw @('update') }
}

$numSeek = New-Object System.Windows.Forms.NumericUpDown
$numSeek.Location = '355,18'; $numSeek.Width = 60
$numSeek.Minimum = -8; $numSeek.Maximum = 85
$tip.SetToolTip($numSeek, (T 'Cylindre cible. Valeurs négatives possibles sur lecteur flippy.'))

$btnSeek = New-Object System.Windows.Forms.Button
$btnSeek.Text = 'Seek'; $btnSeek.Location = '425,17'; $btnSeek.Size = '80,26'
$btnSeek.Add_Click({ Start-Gw (@('seek') + (Get-CommonArgs) + @("$($numSeek.Value)")) })

$txtEraseTracks = New-Object System.Windows.Forms.TextBox
$txtEraseTracks.Location = '355,55'; $txtEraseTracks.Width = 150
$tip.SetToolTip($txtEraseTracks, (T 'TSPEC optionnel. Vide = toute la disquette.'))

$btnErase = New-Object System.Windows.Forms.Button
$btnErase.Text = (T 'EFFACER'); $btnErase.Location = '515,54'; $btnErase.Size = '100,26'
$btnErase.Add_Click({
    $scope = if ($txtEraseTracks.Text.Trim()) { ((T "les pistes {0}") -f "$($txtEraseTracks.Text.Trim())") } else { (T "TOUTE la disquette") }
    $r = [System.Windows.Forms.MessageBox]::Show(
        ((T "Opération IRRÉVERSIBLE : {0} dans le lecteur {1} sera effacée.`n`nContinuer ?") -f "$scope", "$($cmbDrive.Text)"),
        (T 'Confirmation effacement'), 'YesNo', 'Warning')
    if ($r -eq 'Yes') {
        $a = @('erase') + (Get-CommonArgs)
        if ($txtEraseTracks.Text.Trim()) { $a += "--tracks=$($txtEraseTracks.Text.Trim())" }
        Start-Gw $a
    }
})

$numPasses = New-Object System.Windows.Forms.NumericUpDown
$numPasses.Location = '355,92'; $numPasses.Width = 50
$numPasses.Minimum = 1; $numPasses.Maximum = 20

$numLinger = New-Object System.Windows.Forms.NumericUpDown
$numLinger.Location = '470,92'; $numLinger.Width = 60
$numLinger.Minimum = 0; $numLinger.Maximum = 5000
$tip.SetToolTip($numLinger, (T 'Temps de contact par pas, en millisecondes.'))

$btnClean = New-Object System.Windows.Forms.Button
$btnClean.Text = (T 'NETTOYER'); $btnClean.Location = '540,91'; $btnClean.Size = '100,26'
# Fenetre de nettoyage de l Accueil (avertissement, procedure, case obligatoire, suivi), avec les passes et le linger
# de cet onglet en 4e duree
$btnClean.Add_Click({ Show-CleanDialog -Passes ([int]$numPasses.Value) -Linger ([int]$numLinger.Value) })

$numPin = New-Object System.Windows.Forms.NumericUpDown
$numPin.Location = '355,129'; $numPin.Width = 50
$numPin.Minimum = 1; $numPin.Maximum = 34

$cmbPinLvl = New-Object System.Windows.Forms.ComboBox
$cmbPinLvl.Location = '420,129'; $cmbPinLvl.Width = 55; $cmbPinLvl.DropDownStyle = 'DropDownList'
[void]$cmbPinLvl.Items.AddRange(@('H','L'))

$btnPin = New-Object System.Windows.Forms.Button
$btnPin.Text = (T 'Appliquer'); $btnPin.Location = '485,128'; $btnPin.Size = '100,26'
$btnPin.Add_Click({ Start-Gw (@('pin') + (Get-CommonArgs) + @("$($numPin.Value)", $cmbPinLvl.Text)) })

$tabT.Controls.AddRange(@($btnInfo,$btnRpm,$btnBw,$btnReset,$btnUpdate,
    (New-Label (T 'Seek cylindre :') '250,21'), $numSeek, $btnSeek,
    (New-Label (T 'Erase tracks :') '250,58'), $txtEraseTracks, $btnErase,
    (New-Label (T 'Clean passes :') '250,95'), $numPasses, (New-Label (T 'linger :') '415,95'), $numLinger, $btnClean,
    (New-Label (T 'Pin :') '250,132'), $numPin, $cmbPinLvl, $btnPin))

# ============================== DELAIS =========================================
$tabD = New-TabPage (T 'Délais')

$delayDefs = @(
    @{Key='select';     Label=(T 'Select Delay (us) :'); Def=10},
    @{Key='step';       Label=(T 'Step Delay (us) :');   Def=10000},
    @{Key='settle';     Label=(T 'Settle Time (ms) :');  Def=15},
    @{Key='motor';      Label=(T 'Motor Delay (ms) :');  Def=750},
    @{Key='watchdog';   Label=(T 'Watchdog (ms) :');     Def=10000},
    @{Key='pre-write';  Label=(T 'Pre-Write (us) :');    Def=100},
    @{Key='post-write'; Label=(T 'Post-Write (us) :');   Def=1000},
    @{Key='index-mask'; Label=(T 'Index Mask (us) :');   Def=200}
)
$script:DelayCtrls = [ordered]@{}
$y = 15
foreach ($d in $delayDefs) {
    $tabD.Controls.Add((New-Label $d.Label "15,$($y+3)"))
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Location = "175,$($y+2)"; $chk.Width = 18
    $num = New-Object System.Windows.Forms.NumericUpDown
    $num.Location = "200,$y"; $num.Width = 85
    $num.Minimum = 0; $num.Maximum = 1000000
    $num.Enabled = $false
    $chk.Tag = $num
    $chk.Add_CheckedChanged({ $this.Tag.Enabled = $this.Checked })
    $tabD.Controls.AddRange(@($chk,$num))
    $script:DelayCtrls[$d.Key] = @{Chk=$chk; Num=$num; Def=$d.Def}
    $y += 32
}

$btnDelaysShow = New-Object System.Windows.Forms.Button
$btnDelaysShow.Text = (T 'Afficher les délais actuels'); $btnDelaysShow.Location = '330,15'; $btnDelaysShow.Size = '230,32'
$btnDelaysShow.Add_Click({ Start-Gw @('delays') })

$btnDelaysSet = New-Object System.Windows.Forms.Button
$btnDelaysSet.Text = (T 'Appliquer les valeurs cochées'); $btnDelaysSet.Location = '330,55'; $btnDelaysSet.Size = '230,32'
$btnDelaysSet.Add_Click({
    $a = @('delays')
    foreach ($k in $script:DelayCtrls.Keys) {
        $c = $script:DelayCtrls[$k]
        if ($c.Chk.Checked) { $a += "--$k=$($c.Num.Value)" }
    }
    if ($a.Count -eq 1) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Cochez au moins un paramètre à modifier.'),(T 'Rien à faire'),'OK','Information'); return
    }
    Start-Gw $a
})

$lblDelayNote = New-Object System.Windows.Forms.Label
$lblDelayNote.Text = (T "Valeurs pré-remplies = défauts usine, à titre indicatif.`n") +
                     (T "Cochez une case pour transmettre le paramètre à gw.`n`n") +
                     (T "Seek en échec / Track 0 not found : augmenter Step`n") +
                     (T "(20000 à 40000 us) puis Settle (40 ms).`n`n") +
                     (T "Les modifications ne survivent pas à un reset ni à un`n") +
                     (T "débranchement du Greaseweazle.")
$lblDelayNote.Location = '330,100'; $lblDelayNote.Size = '400,150'

$tabD.Controls.AddRange(@($btnDelaysShow,$btnDelaysSet,$lblDelayNote))

# ============================== COMMANDE LIBRE =================================
$tabC = New-TabPage (T 'Commande libre')

$txtC = New-Object System.Windows.Forms.TextBox
$txtC.Location = '10,40'; $txtC.Width = 768; $txtC.Font = $mono; $txtC.Anchor = 'Top,Left,Right'

$btnC = New-Object System.Windows.Forms.Button
$btnC.Text = (T 'EXÉCUTER'); $btnC.Location = '10,75'; $btnC.Size = '150,40'; $btnC.Font = $bold
$btnC.Add_Click({ if ($txtC.Text.Trim()) { Start-Gw @($txtC.Text.Trim()) } })

$btnHelp = New-Object System.Windows.Forms.Button
$btnHelp.Text = 'gw help'; $btnHelp.Location = '175,75'; $btnHelp.Size = '110,34'
$btnHelp.Add_Click({ Start-Gw @('help') })

$cmbHelpAct = New-Object System.Windows.Forms.ComboBox
$cmbHelpAct.Location = '300,79'; $cmbHelpAct.Width = 130; $cmbHelpAct.DropDownStyle = 'DropDownList'
[void]$cmbHelpAct.Items.AddRange(@('info','read','write','convert','erase','clean','seek','delays','update','pin','reset','bandwidth','rpm'))

$btnHelpAct = New-Object System.Windows.Forms.Button
$btnHelpAct.Text = '--help'; $btnHelpAct.Location = '440,75'; $btnHelpAct.Size = '90,34'
$btnHelpAct.Add_Click({ Start-Gw @($cmbHelpAct.Text, '--help') })

$tabC.Controls.AddRange(@((New-Label (T 'Arguments passés à gw (sans "gw") :') '10,17'), $txtC, $btnC,
    $btnHelp, $cmbHelpAct, $btnHelpAct))

# ============================== ACCUEIL ========================================
# Point d entree pour un debutant : une carte par tache courante, qui ouvre l onglet adapte ou lance l action.
$tabH = New-TabPage (T 'Accueil')
$tabH.AutoScroll = $true

$lblHTitle = New-Object System.Windows.Forms.Label
$lblHTitle.Text = (T 'Que voulez-vous faire ?'); $lblHTitle.Location = '14,8'; $lblHTitle.AutoSize = $true
$lblHTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 13); $lblHTitle.ForeColor = $script:Theme.Accent2
$lblHSub = New-Object System.Windows.Forms.Label
$lblHSub.Text = (T "Choisissez une tâche : l'application règle les options pour vous. F1 ouvre l'aide de l'onglet affiché.")
$lblHSub.Location = '16,38'; $lblHSub.AutoSize = $true; $lblHSub.ForeColor = $script:Theme.Muted

function Get-HomeCard($ctrl) {
    # Carte (Panel) d un controle de la carte
    $c = $ctrl
    while ($c -and -not ($c -is [System.Windows.Forms.Panel] -and $c.Name -eq 'HomeCard')) { $c = $c.Parent }
    return $c
}

function New-HomeCard([string]$glyph, [string]$title, [string]$desc, [string]$loc, [scriptblock]$action) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Name = 'HomeCard'; $p.Location = $loc; $p.Size = '373,84'; $p.BackColor = [System.Drawing.Color]::White
    $p.Tag = $action
    $bar = New-Object System.Windows.Forms.Panel
    $bar.Location = '0,0'; $bar.Size = '5,84'; $bar.BackColor = $script:Theme.Accent
    $pic = New-Object System.Windows.Forms.PictureBox
    $pic.Image = New-GlyphBitmap $glyph 28 $script:Theme.Accent; $pic.Location = '16,26'; $pic.Size = '32,32'; $pic.SizeMode = 'CenterImage'
    $t = New-Object System.Windows.Forms.Label
    $t.Text = $title; $t.Location = '58,10'; $t.Size = '306,22'
    $t.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5); $t.ForeColor = $script:Theme.Accent2
    $d = New-Object System.Windows.Forms.Label
    $d.Text = $desc; $d.Location = '58,34'; $d.Size = '306,44'; $d.ForeColor = $script:Theme.Muted
    $p.Controls.AddRange(@($bar, $pic, $t, $d))
    foreach ($c in @($p, $bar, $pic, $t, $d)) {
        $c.Cursor = [System.Windows.Forms.Cursors]::Hand
        $c.Add_Click({ $card = Get-HomeCard $this; if ($card -and $card.Tag) { & $card.Tag } })
        $c.Add_MouseEnter({ $card = Get-HomeCard $this; if ($card) { $card.BackColor = [System.Drawing.Color]::FromArgb(234, 241, 251) } })
        $c.Add_MouseLeave({
            $card = Get-HomeCard $this
            if ($card -and -not $card.ClientRectangle.Contains($card.PointToClient([System.Windows.Forms.Cursor]::Position))) { $card.BackColor = [System.Drawing.Color]::White }
        })
    }
    $p.Add_Paint({
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(205, 212, 224))
        $_.Graphics.DrawRectangle($pen, 0, 0, $this.Width - 1, $this.Height - 1); $pen.Dispose()
    })
    return $p
}

$cardRestore = New-HomeCard 'History' (T 'Restaurer une disquette') (T "Copier une disquette d'origine sur une disquette vierge, avec les contrôles les plus stricts.") '14,64' { Show-Tab $tabRs }
$cardWrite   = New-HomeCard 'Save' (T 'Écrire une image sur une disquette') (T "Choisir un fichier (ADF, IPF, SCP...) dans votre bibliothèque et l'écrire sur une disquette.") '397,64' { Show-Tab $tabL }
$cardRead    = New-HomeCard 'Download' (T 'Sauvegarder une disquette') (T "Lire une disquette et l'enregistrer dans un fichier : SCP pour archiver, ADF pour un émulateur.") '14,156' { Show-Tab $tabR }
$cardCheck   = New-HomeCard 'Diagnostic' (T 'Vérifier une disquette ou un lecteur') (T 'Mesurer la qualité de lecture piste par piste, ou guider le réglage de l''alignement.') '397,156' { Show-Tab $tabAl }
# Carte Calibration a la place de l ancienne carte Courbe (courbe affichee depuis sa fenetre) ; 397,248 : carte Nettoyage
$cardCalib   = New-HomeCard 'Stopwatch' (T 'Calibrer le lecteur') (T 'Choisir un type de disquette, voir sa courbe et calibrer le lecteur : complète ou rapide.') '14,248' { Show-HomeCalib }
$cardTest    = New-HomeCard 'Usb' (T 'Tester le Greaseweazle') (T 'Vérifier que la carte répond (gw info), puis détecter les lecteurs branchés (A, B, 0 à 3).') '14,340' {
    if (($script:GwProc -and -not $script:GwProc.HasExited) -or $script:Chain.Count -gt 0 -or $script:Rep -or $script:Cal -or $script:Restore -or $script:Detect) { return }
    $script:DetectAt = $null                              # la detection complete remplace la detection automatique en attente
    $script:InfoArgs = @('info'); if ($txtDev.Text.Trim()) { $script:InfoArgs += "--device=$($txtDev.Text.Trim())" }
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw $script:InfoArgs })
    $script:Chain.Enqueue({ Start-DriveDetect 'full' })
    Invoke-NextChainStep
}
$cardHelp    = New-HomeCard 'Help' (T 'Guide pas à pas') (T 'Ouvrir l''aide en ligne : premiers pas, glossaire des termes, dépannage.') '397,340' { Open-Help 'Premiers-pas' }
$cardClean   = New-HomeCard 'Repair' (T 'Nettoyer les têtes du lecteur') (T 'Procédure en images. Disquette de nettoyage uniquement, jamais une vraie disquette.') '397,248' { Show-CleanDialog }
$cardJitter  = New-HomeCard 'Setting' (T 'Régler le jitter') (T "Choisir le jitter maximal d'une piste saine : plus il est strict, plus l'écriture lente réécrit de pistes.") '14,432' { Show-JitterSettings }
$script:HomeCalDesc = $cardCalib.Controls[3].Text      # description d origine, remplacee par la progression (Update-HomeCalibCard)
$tabH.Controls.AddRange(@($lblHTitle, $lblHSub, $cardRestore, $cardWrite, $cardRead, $cardCheck, $cardCalib, $cardClean, $cardTest, $cardHelp, $cardJitter))

# ============================== RESTAURATION : INTERFACE =======================
# Assistant : lecture de l original, changement de disquette, ecriture stricte, controle et comparaison. La logique
# (machine d etats $script:Restore) est dans la section RESTAURATION : LOGIQUE.
$tabRs = New-TabPage (T 'Restauration')
$tabRs.AutoScroll = $true
$script:RsFluxItem = (T 'Copie exacte du flux (disquette protégée ou format inconnu)')

$grpRsSrc = New-Group (T '1. Disquette d''origine') '10,4' '380,80'; $grpRsSrc.Anchor = 'Top,Left'
$cmbRsSrc = New-Object System.Windows.Forms.ComboBox
$cmbRsSrc.Location = '78,21'; $cmbRsSrc.Width = 50; $cmbRsSrc.DropDownStyle = 'DropDownList'
[void]$cmbRsSrc.Items.AddRange(@('A','B','0','1','2','3'))
$tip.SetToolTip($cmbRsSrc, (T "Lecteur qui lit la disquette d'origine (même convention que le choix Lecteur du bandeau).`nA/B = nappe PC avec twist, 0 à 3 = nappe droite (lecteur Amiga, par exemple)."))
$cmbRsFmt = New-Object System.Windows.Forms.ComboBox
$cmbRsFmt.Location = '196,21'; $cmbRsFmt.Width = 172; $cmbRsFmt.DropDownWidth = 360; $cmbRsFmt.DropDownStyle = 'DropDownList'
[void]$cmbRsFmt.Items.AddRange(@($script:RsFluxItem, 'amiga.amigados', 'amiga.amigados_hd', 'atarist.720', 'atarist.800', 'atarist.880', 'ibm.360', 'ibm.720', 'ibm.1440'))
$tip.SetToolTip($cmbRsFmt, (T "Format de la disquette d'origine.`nAvec un format (amiga.amigados pour une disquette Amiga, par exemple) : chaque secteur est lu et vérifié, la copie est écrite avec la précompensation calibrée puis comparée secteur par secteur à l'original.`nCopie exacte du flux : pour une disquette protégée contre la copie ou d'un format absent de la liste ; le signal est recopié tel quel, sans précompensation ni comparaison par secteur."))
$lblRsSrcHint = New-Object System.Windows.Forms.Label
$lblRsSrcHint.Text = (T 'Conseil : protégez-la en écriture avant de commencer.')
$lblRsSrcHint.Location = '12,52'; $lblRsSrcHint.Size = '360,20'; $lblRsSrcHint.ForeColor = $script:Theme.Muted
$tip.SetToolTip($lblRsSrcHint, (T 'Disquette 3,5" : fenêtre de protection ouverte. 5,25" : encoche couverte. Ainsi, même une erreur de manipulation ne peut pas l''effacer.'))
$grpRsSrc.Controls.AddRange(@((New-Label (T 'Lecteur :') '12,24'), $cmbRsSrc, (New-Label (T 'Format :') '138,24'), $cmbRsFmt, $lblRsSrcHint))

$grpRsDst = New-Group (T '2. Disquette de destination') '10,88' '380,78'; $grpRsDst.Anchor = 'Top,Left'
$cmbRsDst = New-Object System.Windows.Forms.ComboBox
$cmbRsDst.Location = '78,21'; $cmbRsDst.Width = 50; $cmbRsDst.DropDownStyle = 'DropDownList'
[void]$cmbRsDst.Items.AddRange(@('A','B','0','1','2','3'))
$tip.SetToolTip($cmbRsDst, (T "Lecteur qui écrit la copie. Même lecteur que l'origine : l'application vous demandera de changer de disquette entre la lecture et l'écriture."))
$lblRsDstHint = New-Object System.Windows.Forms.Label
$lblRsDstHint.Text = (T 'Vierge ou à sacrifier : tout son contenu sera remplacé.')
$lblRsDstHint.Location = '12,52'; $lblRsDstHint.Size = '360,20'; $lblRsDstHint.ForeColor = $script:Theme.Muted
$grpRsDst.Controls.AddRange(@((New-Label (T 'Lecteur :') '12,24'), $cmbRsDst, $lblRsDstHint))

$grpRsDir = New-Group (T '3. Sauvegarde de l''original') '10,170' '380,82'; $grpRsDir.Anchor = 'Top,Left'
$txtRsDir = New-Object System.Windows.Forms.TextBox
$txtRsDir.Location = '78,21'; $txtRsDir.Width = 256
$btnRsDir = New-Object System.Windows.Forms.Button
$btnRsDir.Text = '...'; $btnRsDir.Location = '340,20'; $btnRsDir.Width = 30
$btnRsDir.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = (T 'Dossier où enregistrer la lecture de l''original, la relecture de la copie et le rapport')
    if ($txtRsDir.Text -and (Test-Path -LiteralPath $txtRsDir.Text)) { $d.SelectedPath = $txtRsDir.Text }
    if ($d.ShowDialog() -eq 'OK') { $txtRsDir.Text = $d.SelectedPath }
})
$txtRsName = New-Object System.Windows.Forms.TextBox
$txtRsName.Location = '78,51'; $txtRsName.Width = 292
$tip.SetToolTip($txtRsDir, (T "Dossier où sont enregistrés la lecture de l'original, la relecture de la copie et le rapport de restauration."))
$tip.SetToolTip($txtRsName, (T 'Nom des fichiers enregistrés, par exemple « Workbench 1.3 ». Vide : date et heure.'))
$grpRsDir.Controls.AddRange(@((New-Label (T 'Dossier :') '12,24'), $txtRsDir, $btnRsDir, (New-Label (T 'Nom :') '12,54'), $txtRsName))
Set-Cue $txtRsDir (T 'Documents\Greaseweazle Studio\Restaurations')
Set-Cue $txtRsName (T 'vide = date et heure')

$btnRsStart = New-Object System.Windows.Forms.Button
$btnRsStart.Text = (T 'RESTAURER LA DISQUETTE'); $btnRsStart.Location = '10,260'; $btnRsStart.Size = '250,40'; $btnRsStart.Font = $bold
$btnRsStart.Add_Click({ try { Start-Restore } catch { Append-Log ((T "ERREUR restauration : {0}") -f "$($_.Exception.Message)") } })
$lblRsRules = New-Object System.Windows.Forms.Label
$lblRsRules.Location = '404,232'; $lblRsRules.Size = '372,100'; $lblRsRules.ForeColor = $script:Theme.Muted
$tip.SetToolTip($btnRsStart, (T "Lit l'original, vous demande de changer de disquette, puis écrit et contrôle la copie avec les règles les plus strictes.`nDurée : de quelques minutes à plus d'une demi-heure selon la calibration et l'état des disquettes."))

$lblRsStepsTitle = New-Object System.Windows.Forms.Label
$lblRsStepsTitle.Text = (T 'Étapes'); $lblRsStepsTitle.Location = '402,8'; $lblRsStepsTitle.AutoSize = $true
$lblRsStepsTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5); $lblRsStepsTitle.ForeColor = $script:Theme.Accent2
$script:RsStepNames = @((T 'Lire la disquette d''origine'), (T 'Vérifier la lecture'), (T 'Changer de disquette'),
    (T 'Vérifier la disquette de destination'), (T 'Calibrer le lecteur si nécessaire'), (T 'Écrire la tête 0 puis la tête 1'),
    (T 'Contrôler toutes les pistes'), (T 'Comparer la copie à l''original'))
$script:RsStepLabels = @()
for ($i = 0; $i -lt $script:RsStepNames.Count; $i++) {
    $l = New-Object System.Windows.Forms.Label
    $l.Location = New-Object System.Drawing.Point(404, (32 + 21 * $i)); $l.Size = '372,20'; $l.AutoEllipsis = $true
    $l.ForeColor = $script:Theme.Muted; $l.Text = "○  " + $script:RsStepNames[$i]
    $script:RsStepLabels += $l
}
$lblRsNow = New-Object System.Windows.Forms.Label
$lblRsNow.Location = '404,204'; $lblRsNow.Size = '372,22'; $lblRsNow.AutoEllipsis = $true; $lblRsNow.ForeColor = $script:Theme.Accent

# Attente du changement de disquette : la sequence est en pause, sans commande gw en cours
$pnlRsWait = New-Object System.Windows.Forms.Panel
$pnlRsWait.Location = '402,230'; $pnlRsWait.Size = '374,104'; $pnlRsWait.BackColor = [System.Drawing.Color]::FromArgb(255, 246, 220); $pnlRsWait.Visible = $false
$lblRsWait = New-Object System.Windows.Forms.Label
$lblRsWait.Location = '8,6'; $lblRsWait.AutoSize = $true; $lblRsWait.MaximumSize = New-Object System.Drawing.Size(358, 0); $lblRsWait.ForeColor = [System.Drawing.Color]::FromArgb(90, 60, 0)
$btnRsGo = New-Object System.Windows.Forms.Button
$btnRsGo.Text = (T 'Continuer'); $btnRsGo.Location = '8,68'; $btnRsGo.Size = '120,30'
$btnRsGo.Add_Click({ try { Resume-Restore $false } catch { Append-Log ((T "ERREUR restauration : {0}") -f "$($_.Exception.Message)") } })
$btnRsForce = New-Object System.Windows.Forms.Button
$btnRsForce.Text = (T 'Écraser quand même'); $btnRsForce.Location = '134,68'; $btnRsForce.Size = '140,30'; $btnRsForce.Visible = $false
$btnRsForce.Add_Click({ try { Resume-Restore $true } catch { Append-Log ((T "ERREUR restauration : {0}") -f "$($_.Exception.Message)") } })
$btnRsCancel = New-Object System.Windows.Forms.Button
$btnRsCancel.Text = (T 'Annuler'); $btnRsCancel.Location = '280,68'; $btnRsCancel.Size = '86,30'
$btnRsCancel.Add_Click({ Stop-Restore (T 'annulée par l''utilisateur') })
$pnlRsWait.Controls.AddRange(@($lblRsWait, $btnRsGo, $btnRsForce, $btnRsCancel))

# Verdict final
$lblRsResult = New-Object System.Windows.Forms.Label
$lblRsResult.Location = '402,230'; $lblRsResult.AutoSize = $true; $lblRsResult.MaximumSize = New-Object System.Drawing.Size(374, 0); $lblRsResult.MinimumSize = New-Object System.Drawing.Size(374, 60)
$lblRsResult.Visible = $false; $lblRsResult.Padding = New-Object System.Windows.Forms.Padding(8)
$lblRsResult.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75)

$tabRs.Controls.AddRange(@($grpRsSrc, $grpRsDst, $grpRsDir, $btnRsStart, $lblRsRules, $lblRsStepsTitle) + $script:RsStepLabels + @($lblRsNow, $pnlRsWait, $lblRsResult))
Set-Btn $btnRsStart 'History' 'primary'
Set-Btn $btnRsDir 'FolderOpen' -IconOnly
Set-Btn $btnRsGo 'Play' 'primary'
Set-Btn $btnRsForce 'Delete' 'danger'
Set-Btn $btnHelpTop 'Help'

# Aide en ligne : page du wiki de chaque onglet (F1, bouton Aide)
$tabH.Tag = 'Premiers-pas'; $tabRs.Tag = 'Restaurer-une-disquette'; $tabL.Tag = 'Autres-onglets'; $tabW.Tag = 'Écriture'
$tabR.Tag = 'Autres-onglets'; $tabCv.Tag = 'Autres-onglets'; $tabCmp.Tag = 'Autres-onglets'; $tabAl.Tag = 'Qualité-et-alignement'
$tabT.Tag = 'Autres-onglets'; $tabD.Tag = 'Autres-onglets'; $tabC.Tag = 'Autres-onglets'

# Onglets affiches : usage courant, ou tous en mode expert
$script:AllTabs = @($tabH, $tabRs, $tabL, $tabW, $tabR, $tabCv, $tabCmp, $tabAl, $tabT, $tabD, $tabC)
$script:NoviceTabs = @($tabH, $tabRs, $tabL, $tabW, $tabR, $tabAl)
function Update-TabSet {
    $want = if ($chkExpert.Checked) { $script:AllTabs } else { $script:NoviceTabs }
    $sel = $tabs.SelectedTab
    $tabs.SuspendLayout()
    $tabs.TabPages.Clear()
    $tabs.TabPages.AddRange([System.Windows.Forms.TabPage[]]$want)
    if ($sel -and $want -contains $sel) { $tabs.SelectedTab = $sel }
    $tabs.ResumeLayout()
}
function Show-Tab($page) {
    # Onglet technique masque (mode expert decoche) : le mode expert est active pour l afficher
    if (-not $tabs.TabPages.Contains($page)) { $chkExpert.Checked = $true }
    if ($tabs.TabPages.Contains($page)) { $tabs.SelectedTab = $page }
}
$chkExpert.Add_CheckedChanged({ Update-TabSet })

# Textes indicatifs des champs vides et infobulles des champs qui n en avaient pas
Set-Cue $txtLibRoot   (T 'Dossier qui contient vos images disque (bouton à droite pour le choisir)')
Set-Cue $txtLibFilter (T 'Nom d''image à rechercher')
Set-Cue $txtWFile     (T 'Image à écrire : ADF, IPF, SCP, HFE, IMG... (bouton à droite)')
Set-Cue $txtWTracks   (T 'vide = toutes les pistes')
Set-Cue $txtWFakeIdx  (T 'vide = lecteur normal')
Set-Cue $txtWDiskdefs (T 'vide = formats intégrés à gw')
Set-Cue $txtDev       (T 'auto')
Set-Cue $txtRFile     (T 'Fichier à créer : .scp pour archiver, .adf pour un émulateur')
Set-Cue $txtRTracks   (T 'vide = toutes')
Set-Cue $txtRDiskdefs (T 'vide = formats intégrés à gw')
Set-Cue $txtCvIn      (T 'Fichier à convertir')
Set-Cue $txtCvOut     (T 'Fichier à créer (son extension fixe le type)')
Set-Cue $txtCvTracks  (T 'vide = toutes')
Set-Cue $txtCmpRef    (T 'Image de référence : ADF, IPF, SCP...')
Set-Cue $txtEraseTracks (T 'vide = toutes les pistes')
$tip.SetToolTip($txtRFile, (T "Fichier où enregistrer la disquette lue.`n.scp : flux exact, pour archiver (protections comprises).`n.adf, .img, .st : secteurs décodés, pour un émulateur (un format est alors nécessaire)."))
$tip.SetToolTip($cmbRFmt, (T "Format de la disquette. (auto) : flux sans décodage.`nAvec un format, gw vérifie chaque secteur et relit les pistes incomplètes (Essais)."))
$tip.SetToolTip($numRRetries, (T 'Nombre de relectures d''une piste dont des secteurs manquent (avec un format seulement).'))
$tip.SetToolTip($txtRTracks, (T 'Pistes à lire, par exemple c=0-79:h=0-1. Vide : toutes les pistes du format.'))
$tip.SetToolTip($chkRRaw, (T "Enregistre le flux réel du disque ; avec un format, celui-ci sert alors au contrôle des secteurs et aux relectures.`nSans cette case, un .scp lu avec un format contient un flux reconstitué à partir des secteurs décodés.`nAvec des essais, les tours relus sont ajoutés après les premiers, mais la plupart des logiciels ne lisent que les premiers tours."))
$tip.SetToolTip($chkRRev, (T 'Face B d''une disquette flippy (5,25" retournée) : le flux est lu à l''envers.'))
$tip.SetToolTip($cmbRDensel, (T 'Force le signal de densité du lecteur (H = haute, L = basse). (non) : laissé au lecteur.'))
$tip.SetToolTip($txtRDiskdefs, (T 'Fichier de définitions de formats personnalisés. Vide : formats intégrés à gw.'))
$tip.SetToolTip($btnRead, (T 'Lit la disquette insérée et enregistre le fichier.'))
$tip.SetToolTip($btnWrite, (T 'Écrit l''image sur la disquette insérée avec les options de cet onglet. Tout le contenu de la disquette est remplacé.'))
$tabs.TabPages.AddRange([System.Windows.Forms.TabPage[]]$script:AllTabs)   # tous attaches : Fit-ControlText les ajuste ; Update-TabSet apres la configuration
$split.Panel1.Controls.Add($tabs)
# Onglet Ecriture defilant (fenetre basse) : il s ouvre en haut, sur l image. Selectionne par le code (bibliotheque),
# WinForms y place le focus sur un controle du bas et fait defiler jusqu a lui. Reprise une fois ce focus pose.
$tabs.Add_SelectedIndexChanged({
    if ($tabs.SelectedTab -ne $tabW -or -not $form.IsHandleCreated) { return }
    [void]$form.BeginInvoke([System.Action]{
        if ($tabs.SelectedTab -ne $tabW -or -not $tabW.VerticalScroll.Visible) { return }
        if ($tabW.ContainsFocus) { [void]$txtWFile.Focus() }
        $tabW.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)
    })
})

# --- Barre de boutons + barre d'etat (hors du separateur : toujours visibles) ---
$flowButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$flowButtons.Size = New-Object System.Drawing.Size(790, 44)
$flowButtons.BackColor = $script:Theme.Window; $flowButtons.Dock = 'Bottom'; $flowButtons.Padding = New-Object System.Windows.Forms.Padding(6,4,6,2); $flowButtons.WrapContents = $false

function New-BarButton($text, $width) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Size = New-Object System.Drawing.Size($width, 32); $b.Margin = New-Object System.Windows.Forms.Padding(0,0,8,0)
    return $b
}

$btnStop = New-BarButton (T 'Arrêter') 105
$btnStop.Enabled = $false; $btnStop.Font = $bold
$btnStop.Add_Click({
    $script:Detect = $null; $script:DetectAt = $null
    if ($script:GwProc -or $script:Chain.Count -gt 0 -or $script:Rep -or $script:Cal -or $script:Restore -or $script:WriteWarm) {
        if ($script:GwProc -and -not $script:GwProc.HasExited) {
            try { $script:GwProc.Kill($true) } catch { try { $script:GwProc.Kill() } catch { } }
        }
        $script:Chain.Clear(); $script:WriteQueue.Clear()
        Stop-WriteWarmup       # prechauffage d une ecriture lente : chaine d ecriture mise de cote abandonnee, rien n est ecrit
        if ($script:Restore) { Stop-Restore (T 'interrompue par l''utilisateur') }
        if ($script:Rep) { Stop-WriteCheck }
        if ($script:Cal) { Stop-PrecompCalib }
        Append-Log (T '*** Interrompu par l''utilisateur ***')
    }
    if ($script:AlignLoop) { $script:AlignLoop = $false; $script:AlignNextAt = $null; Append-Log (T 'Mesure continue arrêtée.') }
})

$btnLogToggle = New-BarButton (T 'Masquer journal') 140
$btnLogToggle.Add_Click({ Set-LogVisible ($split.Panel2Collapsed) })

$btnClear = New-BarButton (T 'Vider') 95
$btnClear.Add_Click({ $txtLog.Clear() })

$btnSaveLog = New-BarButton (T 'Exporter') 100
$btnSaveLog.Add_Click({
    $d = New-Object System.Windows.Forms.SaveFileDialog
    $d.Filter = (T 'Texte|*.txt'); $d.InitialDirectory = $script:AppDir
    $d.FileName = "gw-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    if ($d.ShowDialog() -eq 'OK') { $txtLog.Text | Set-Content -LiteralPath $d.FileName -Encoding UTF8 }
})

$btnCfgSave = New-BarButton (T 'Enregistrer') 115
$btnCfgSave.Add_Click({ if (Save-Config) { Append-Log ((T "Paramètres enregistrés : {0}") -f "$($script:ConfigFile)") } })

$btnCfgReset = New-BarButton (T 'Réinitialiser') 120
$btnCfgReset.Add_Click({
    $r = [System.Windows.Forms.MessageBox]::Show(
        (T "Remettre tous les paramètres de l'interface à leurs valeurs par défaut et supprimer le fichier de configuration ?`n`n(Aucun effet sur le Greaseweazle, ni sur vos fichiers image, ni sur l'index de la bibliothèque.)"),
        (T 'Réinitialiser les paramètres'), 'YesNo', 'Question')
    if ($r -eq 'Yes') {
        Set-Defaults
        Update-Library
        if (Test-Path -LiteralPath $script:ConfigFile) {
            try { Remove-Item -LiteralPath $script:ConfigFile -Force; Append-Log (T 'Configuration supprimée, valeurs par défaut restaurées.') }
            catch { Append-Log ((T "Impossible de supprimer la configuration : {0}") -f "$($_.Exception.Message)") }
        } else { Append-Log (T 'Valeurs par défaut restaurées.') }
    }
})

# Prechauffage en cours (ecriture lente ou calibration) : fin apres la lecture en cours, sans tuer gw. Visible pendant
# tout prechauffage (minuteur) ; Enregistrer et Reinitialiser, inactifs pendant une operation, lui cedent leur place
# (la barre ne passe pas a la ligne)
$btnWarmSkip = New-BarButton (T 'Passer le préchauffage') 175
$btnWarmSkip.Visible = $false
$btnWarmSkip.Add_Click({
    $w = if ($script:WriteWarm) { $script:WriteWarm } elseif ($script:Cal -and $script:Cal.Stage -eq 'warmup') { $script:Cal } else { $null }
    if (-not $w -or $w.WarmSkip) { return }
    $w.WarmSkip = $true; $btnWarmSkip.Enabled = $false
    Append-Log ((T "Préchauffage du lecteur {0} passé à votre demande après {1} : la lecture en cours se termine, puis l'opération continue.") -f "$($w.Drive)", (Format-CalDuration ([math]::Round(((Get-Date) - $w.WarmStart).TotalSeconds))))
    if ($script:WriteWarm) { Update-WriteWarmupProgress } else { Update-CalibProgress }
})

$flowButtons.Controls.AddRange(@($btnStop, $btnWarmSkip, $btnLogToggle, $btnClear, $btnSaveLog, $btnCfgSave, $btnCfgReset))

$status = New-Object System.Windows.Forms.StatusStrip
$status.SizingGrip = $false
$status.BackColor = [System.Drawing.Color]::FromArgb(222, 227, 235)
$status.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
$status.ImageScalingSize = New-Object System.Drawing.Size(18, 18)
$status.Padding = New-Object System.Windows.Forms.Padding(6, 0, 6, 0)
$stOp = New-Object System.Windows.Forms.ToolStripStatusLabel
$stOp.Spring = $true; $stOp.TextAlign = 'MiddleLeft'; $stOp.Text = (T 'Prêt.')
$stOp.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75)
$stTrack = New-Object System.Windows.Forms.ToolStripStatusLabel
$stTrack.Text = ''; $stTrack.AutoSize = $true; $stTrack.ForeColor = $script:Theme.Accent2
$stTrack.Font = New-Object System.Drawing.Font('Consolas', 9.75, [System.Drawing.FontStyle]::Bold)
$stBar = New-Object System.Windows.Forms.ToolStripProgressBar
$stBar.Size = New-Object System.Drawing.Size(280, 18); $stBar.Visible = $false; $stBar.MarqueeAnimationSpeed = 30
[void]$status.Items.AddRange(@($stOp, $stTrack, $stBar))

# --- Journal (panneau bas du separateur, repliable) ---
$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.Dock = 'Fill'; $txtLog.ReadOnly = $true; $txtLog.DetectUrls = $false; $txtLog.WordWrap = $false
$txtLog.Font = $monoBig; $txtLog.BorderStyle = 'None'
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(24, 26, 31)
$txtLog.ForeColor = [System.Drawing.Color]::FromArgb(232, 234, 238)
$script:LogColors = @{
    cmd  = [System.Drawing.Color]::FromArgb(130, 190, 255)
    err  = [System.Drawing.Color]::FromArgb(255, 110, 95)
    warn = [System.Drawing.Color]::FromArgb(255, 200, 100)
    ok   = [System.Drawing.Color]::FromArgb(120, 230, 130)
    dim  = [System.Drawing.Color]::FromArgb(165, 170, 178)
    std  = [System.Drawing.Color]::FromArgb(232, 234, 238)
}
$split.Panel2.Controls.Add($txtLog)

# ============================== HABILLAGE (icones) =============================
$form.Icon = [System.Drawing.Icon]::FromHandle($script:LogoIcon.GetHicon())

# Onglets
$imgTabs = New-Object System.Windows.Forms.ImageList
$imgTabs.ColorDepth = [System.Windows.Forms.ColorDepth]::Depth32Bit
$imgTabs.ImageSize = New-Object System.Drawing.Size(16, 16)
foreach ($n in @('Home','History','Library','Save','Download','Switch','Copy','Diagnostic','Repair','Stopwatch','Cmd')) {
    $imgTabs.Images.Add($n, (New-GlyphBitmap $n 16 $script:Theme.Accent))
}
$tabs.ImageList = $imgTabs
$tabH.ImageKey = 'Home'; $tabRs.ImageKey = 'History'
$tabL.ImageKey = 'Library'; $tabW.ImageKey = 'Save'; $tabR.ImageKey = 'Download'; $tabCv.ImageKey = 'Switch'
$tabCmp.ImageKey = 'Copy'; $tabAl.ImageKey = 'Diagnostic'; $tabT.ImageKey = 'Repair'; $tabD.ImageKey = 'Stopwatch'; $tabC.ImageKey = 'Cmd'

# Arborescence de la bibliotheque
$imgTree = New-Object System.Windows.Forms.ImageList
$imgTree.ColorDepth = [System.Windows.Forms.ColorDepth]::Depth32Bit
$imgTree.ImageSize = New-Object System.Drawing.Size(16, 16)
$imgTree.Images.Add('blank', (New-Object System.Drawing.Bitmap(16, 16)))
$imgTree.Images.Add('dir',   (New-GlyphBitmap 'Folder'   16 $script:Theme.Folder))
$imgTree.Images.Add('zip',   (New-GlyphBitmap 'Package'  16 $script:Theme.Zip))
$imgTree.Images.Add('image', (New-GlyphBitmap 'Save'     16 $script:Theme.Accent))
$imgTree.Images.Add('doc',   (New-GlyphBitmap 'Document' 16 $script:Theme.Muted))
$imgTree.Images.Add('other', (New-GlyphBitmap 'Page'     16 ([System.Drawing.Color]::FromArgb(170, 175, 185))))
$treeLib.ImageList = $imgTree
$treeLib.ItemHeight = 20

# Boutons : actions principales en bleu, action destructive en rouge, parcours en icone seule
Set-Btn $btnLibRoot    'FolderOpen' -IconOnly
Set-Btn $btnLibRefresh 'Refresh'    -IconOnly
Set-Btn $btnLibFilter  'Search'     -IconOnly
Set-Btn $btnLibReindex 'Sync'
Set-Btn $btnLibFast    'Save' 'primary'
Set-Btn $btnLibSlow    'Save' 'primary'
Set-Btn $btnLibOpen    'OpenFile'
Set-Btn $btnLibExplore 'FolderOpen'
Set-Btn $btnWFile      'FolderOpen' -IconOnly
Set-Btn $btnWDiskdefs  'FolderOpen' -IconOnly
Set-Btn $btnWrite      'Save' 'primary'
Set-Btn $btnWCalib     'Diagnostic'
Set-Btn $btnWCalReset  'Delete' 'danger'
Set-Btn $btnWCurve     'Diagnostic'
Set-Btn $btnRFile      'FolderOpen' -IconOnly
Set-Btn $btnRDiskdefs  'FolderOpen' -IconOnly
Set-Btn $btnRead       'Download' 'primary'
Set-Btn $btnCvIn       'FolderOpen' -IconOnly
Set-Btn $btnCvOut      'FolderOpen' -IconOnly
Set-Btn $btnConvert    'Switch' 'primary'
Set-Btn $btnCmpRef     'FolderOpen' -IconOnly
Set-Btn $btnCmpFromWrite 'Save'
Set-Btn $btnCompare    'Copy' 'primary'
Set-Btn $btnAlStart    'Diagnostic' 'primary'
Set-Btn $btnAlRef      'Pin'
Set-Btn $btnAlReset    'Refresh'
Set-Btn $btnAlPos0     'Pin'
Set-Btn $btnAlPlus     'Add'
Set-Btn $btnAlMinus    'Remove'
Set-Btn $btnInfo       'Info'
Set-Btn $btnRpm        'Stopwatch'
Set-Btn $btnBw         'Usb'
Set-Btn $btnReset      'Refresh'
Set-Btn $btnUpdate     'Download'
Set-Btn $btnSeek       'Play'
Set-Btn $btnErase      'Delete' 'danger'
Set-Btn $btnClean      'Repair'
Set-Btn $btnPin        'Pin'
Set-Btn $btnDelaysShow 'Stopwatch'
Set-Btn $btnDelaysSet  'Check'
Set-Btn $btnC          'Play' 'primary'
Set-Btn $btnHelp       'Info'
Set-Btn $btnHelpAct    'Info'
Set-Btn $btnStop       'Stop' -IconColor $script:Theme.Danger
Set-Btn $btnWarmSkip   'Play'
Set-Btn $btnLogToggle  'Page'
Set-Btn $btnClear      'Delete'
Set-Btn $btnSaveLog    'Save'
Set-Btn $btnCfgSave    'Setting'
Set-Btn $btnCfgReset   'Refresh'
$tip.SetToolTip($btnClear,   (T 'Effacer le contenu du journal.'))
$tip.SetToolTip($btnSaveLog, (T 'Exporter le journal dans un fichier texte.'))
$tip.SetToolTip($btnCfgSave, (T 'Enregistrer maintenant tous les paramètres de l''interface.'))
$tip.SetToolTip($btnCfgReset,(T 'Remettre les paramètres de l''interface à leurs valeurs par défaut.'))
$tip.SetToolTip($btnStop, (T 'Arrête la commande ou la séquence en cours.'))
$tip.SetToolTip($btnWarmSkip, (T "Termine le préchauffage du lecteur après la lecture en cours : l'écriture lente (ou la calibration) commence aussitôt."))
$tip.SetToolTip($btnLogToggle, (T 'Affiche ou masque le journal des commandes gw.'))

# Barre d'etat : pictogramme d'etat
$script:StIcons = @{
    idle = New-GlyphBitmap 'Info'  16 $script:Theme.Muted
    run  = New-GlyphBitmap 'Play'  16 $script:Theme.Accent
    ok   = New-GlyphBitmap 'Check' 16 $script:Theme.Ok
    err  = New-GlyphBitmap 'Error' 16 $script:Theme.Danger
}
$stOp.Image = $script:StIcons.idle

$form.Controls.Add($flowButtons)
$form.Controls.Add($status)
$form.Controls.Add($pnlTop)
$form.Controls.Add($split)
$split.BringToFront()

function Set-LogVisible([bool]$visible) {
    $split.Panel2Collapsed = -not $visible
    $btnLogToggle.Text = if ($visible) { (T 'Masquer journal') } else { (T 'Afficher journal') }
}

# ============================== BIBLIOTHEQUE : LOGIQUE =========================
function Format-Size([long]$bytes) {
    if ($bytes -ge 1048576) { return ((T '{0:N1} Mo') -f ($bytes / 1MB)) }
    if ($bytes -ge 1024)    { return ((T '{0:N0} Ko') -f ($bytes / 1KB)) }
    return ((T "{0} o") -f "$bytes")
}

function Get-FileKind([string]$name) {
    $e = [System.IO.Path]::GetExtension($name).ToLower()
    if ($e -eq '.zip')               { return 'zip' }
    if ($script:ImgExt -contains $e) { return 'image' }
    if ($script:DocExt -contains $e) { return 'doc' }
    return 'other'
}

function Get-KindPrefix([string]$kind) { return '' }   # remplace par les icones de l'arborescence

function Get-ZipEntries([string]$zipPath) {
    $out = @()
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            foreach ($e in $zip.Entries) {
                if ($e.FullName.EndsWith('/')) { continue }
                $out += [pscustomobject]@{ FullName = $e.FullName; Length = $e.Length; Kind = (Get-FileKind $e.Name) }
            }
        } finally { $zip.Dispose() }
    } catch {
        Append-Log ((T "ZIP illisible ({0}) : {1}") -f "$([System.IO.Path]::GetFileName($zipPath))", "$($_.Exception.Message)")
    }
    return $out
}

function New-LibNode([string]$text, $tagHash) {
    $n = New-Object System.Windows.Forms.TreeNode
    $n.Text = $text
    $n.Tag  = $tagHash
    $k = $tagHash.Kind
    if ($k -eq 'zipentry') { $k = $tagHash.FileKind }
    if (@('dir','zip','image','doc','other') -notcontains $k) { $k = 'blank' }
    $n.ImageKey = $k; $n.SelectedImageKey = $k
    return $n
}

function New-Placeholder { return (New-LibNode (T '(chargement...)') @{ Kind='placeholder' }) }

function Expand-LibNode($node) {
    if (-not $node -or -not $node.Tag) { return }
    if ($node.Nodes.Count -ne 1 -or $node.Nodes[0].Tag.Kind -ne 'placeholder') { return }

    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $treeLib.BeginUpdate()
    try {
        $node.Nodes.Clear()
        if ($node.Tag.Kind -eq 'dir') {
            Populate-LibDir $node
        } elseif ($node.Tag.Kind -eq 'zip') {
            $list = New-Object System.Collections.Generic.List[System.Windows.Forms.TreeNode]
            foreach ($e in (Get-ZipEntries $node.Tag.Path)) {
                if ($chkLibImgOnly.Checked -and $e.Kind -ne 'image') { continue }
                $list.Add((New-LibNode "$(Get-KindPrefix $e.Kind)$($e.FullName)  ($(Format-Size $e.Length))" `
                    @{ Kind='zipentry'; ZipPath=$node.Tag.Path; Entry=$e.FullName; Size=$e.Length; FileKind=$e.Kind }))
            }
            if ($list.Count -eq 0) { $list.Add((New-LibNode (T '(aucune image)') @{ Kind='none' })) }
            $node.Nodes.AddRange($list.ToArray())
        }
    } finally {
        $treeLib.EndUpdate()
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

function Populate-LibDir($node) {
    $path = $node.Tag.Path
    $list = New-Object System.Collections.Generic.List[System.Windows.Forms.TreeNode]
    try {
        foreach ($d in (Get-ChildItem -LiteralPath $path -Directory -ErrorAction Stop | Sort-Object Name)) {
            $sub = New-LibNode $d.Name @{ Kind='dir'; Path=$d.FullName }
            [void]$sub.Nodes.Add((New-Placeholder))
            $list.Add($sub)
        }
        foreach ($f in (Get-ChildItem -LiteralPath $path -File -ErrorAction Stop | Sort-Object Name)) {
            $kind = Get-FileKind $f.Name
            if ($chkLibImgOnly.Checked -and $kind -ne 'image' -and $kind -ne 'zip') { continue }
            $n = New-LibNode "$(Get-KindPrefix $kind)$($f.Name)  ($(Format-Size $f.Length))" @{ Kind=$kind; Path=$f.FullName; Size=$f.Length }
            if ($kind -eq 'zip') { [void]$n.Nodes.Add((New-Placeholder)) }
            $list.Add($n)
        }
    } catch {
        Append-Log ((T "Lecture impossible de {0} : {1}") -f "$path", "$($_.Exception.Message)")
    }
    if ($list.Count -gt 0) { $node.Nodes.AddRange($list.ToArray()) }
}

# --- Recherche asynchrone : s execute dans un runspace separe, l UI ne gele pas
function Stop-LibSearch {
    if ($script:LibPS) {
        try { $script:LibPS.Stop() } catch { }
        try { $script:LibPS.Dispose() } catch { }
    }
    $script:LibPS = $null
    $script:LibAsync = $null
}

function Start-LibSearch([string]$root, [string]$filter, [bool]$imgOnly) {
    Stop-LibSearch
    if (-not $script:LibRunspace -or $script:LibRunspace.RunspaceStateInfo.State -ne 'Opened') {
        $script:LibRunspace = [runspacefactory]::CreateRunspace()
        $script:LibRunspace.Open()
    }
    $ps = [powershell]::Create()
    $ps.Runspace = $script:LibRunspace
    [void]$ps.AddScript({
        param($root, $filter, $imgExt, $docExt, $imgOnly)
        $pat = '*' + [System.Management.Automation.WildcardPattern]::Escape($filter) + '*'
        $out = New-Object System.Collections.Generic.List[object]
        Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like $pat } |
            ForEach-Object {
                $e = [System.IO.Path]::GetExtension($_.Name).ToLower()
                $kind = if ($e -eq '.zip') { 'zip' } elseif ($imgExt -contains $e) { 'image' } elseif ($docExt -contains $e) { 'doc' } else { 'other' }
                if ($imgOnly -and $kind -ne 'image' -and $kind -ne 'zip') { return }
                $out.Add([pscustomobject]@{ Name = $_.Name; FullName = $_.FullName; Length = $_.Length; Kind = $kind })
            }
        $out.ToArray()
    }).AddArgument($root).AddArgument($filter).AddArgument($script:ImgExt).AddArgument($script:DocExt).AddArgument($imgOnly)
    $script:LibPS = $ps
    $script:LibAsync = $ps.BeginInvoke()

    $lblLibCount.Text = (T 'recherche en cours...')
    $btnLibFilter.Enabled = $false
    $btnLibRefresh.Enabled = $false
    $form.Cursor = [System.Windows.Forms.Cursors]::AppStarting
}

function Complete-LibSearch {
    $root = $txtLibRoot.Text
    $results = @()
    try { $results = @($script:LibPS.EndInvoke($script:LibAsync)) } catch { Append-Log ((T "Recherche : {0}") -f "$($_.Exception.Message)") }
    Stop-LibSearch
    $btnLibFilter.Enabled = $true
    $btnLibRefresh.Enabled = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::Default

    $treeLib.BeginUpdate()
    try {
        $treeLib.Nodes.Clear()
        $list = New-Object System.Collections.Generic.List[System.Windows.Forms.TreeNode]
        foreach ($f in ($results | Sort-Object FullName)) {
            if (-not $f) { continue }
            $rel = $f.FullName
            if ($rel.Length -gt $root.Length) { $rel = $rel.Substring($root.Length).TrimStart('\') }
            $n = New-LibNode "$(Get-KindPrefix $f.Kind)$rel  ($(Format-Size $f.Length))" @{ Kind=$f.Kind; Path=$f.FullName; Size=$f.Length }
            if ($f.Kind -eq 'zip') { [void]$n.Nodes.Add((New-Placeholder)) }
            $list.Add($n)
        }
        if ($list.Count -gt 0) { $treeLib.Nodes.AddRange($list.ToArray()) }
        $lblLibCount.Text = ((T "{0} résultat(s)") -f "$($list.Count)")
    } finally { $treeLib.EndUpdate() }
}

function Get-LibIndexFile([string]$root) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $h = [BitConverter]::ToString($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($root.TrimEnd('\').ToLowerInvariant()))).Replace('-','').Substring(0,16)
    return (Join-Path $script:IndexDir "index-$h.tsv")
}

function Test-LibIndexReady([string]$root) {
    if (-not $script:FastIndexOk) { return $false }
    return ([FastIndex]::Root -eq $root.TrimEnd('\') -and [FastIndex]::Count -gt 0)
}

function Start-LibIndex([bool]$force) {
    if (-not $script:FastIndexOk) { return }
    $root = $txtLibRoot.Text
    if (-not $root -or -not (Test-Path -LiteralPath $root)) { return }
    if ([FastIndex]::Busy) { return }
    $file = Get-LibIndexFile $root
    if (-not $force -and (Test-LibIndexReady $root)) { return }
    if (-not $force -and (Test-Path -LiteralPath $file)) {
        try { if ([FastIndex]::Load($file, $root)) { Show-LibIndexStatus; return } } catch { Append-Log ((T "Index illisible, reconstruction : {0}") -f "$($_.Exception.Message)") }
    }
    [FastIndex]::StartBuild($root, $file)
    $script:LibIndexing = $true
    $btnLibReindex.Enabled = $false
    Append-Log ((T "Bibliothèque : indexation de {0} en arrière-plan...") -f "$root")
}

function Show-LibIndexStatus {
    if (-not $script:FastIndexOk -or [FastIndex]::Count -eq 0) { return }
    $tip.SetToolTip($lblLibCount, ((T "Index : {0} fichiers, construit le {1}.") -f "$([FastIndex]::Count)", "$([FastIndex]::Built.ToString('dd/MM/yyyy HH:mm'))"))
    if (-not $txtLibFilter.Text.Trim()) { $lblLibCount.Text = ((T "Index : {0} fichiers") -f "$('{0:N0}' -f [FastIndex]::Count)") }
}

function Show-LibIndexResults([string]$root, [string]$filter) {
    $max = 2000
    $res = [FastIndex]::Search($filter, [bool]$chkLibImgOnly.Checked, $max)
    $rootT = $root.TrimEnd('\')
    $treeLib.BeginUpdate()
    try {
        $treeLib.Nodes.Clear()
        $list = New-Object System.Collections.Generic.List[System.Windows.Forms.TreeNode]
        foreach ($e in $res) {
            $full = Join-Path $rootT $e.Rel
            $n = New-LibNode "$(Get-KindPrefix $e.Kind)$($e.Rel)  ($(Format-Size $e.Size))" @{ Kind=$e.Kind; Path=$full; Size=$e.Size }
            if ($e.Kind -eq 'zip') { [void]$n.Nodes.Add((New-Placeholder)) }
            $list.Add($n)
        }
        if ($list.Count -gt 0) { $treeLib.Nodes.AddRange($list.ToArray()) }
    } finally { $treeLib.EndUpdate() }
    $tot = [FastIndex]::LastTotal
    $lblLibCount.Text = if ($tot -gt $max) { ((T "{0} premiers sur {1}") -f "$max", "$('{0:N0}' -f $tot)") } else { ((T "{0} résultat(s)") -f "$('{0:N0}' -f $tot)") }
}

function Update-Library {
    Stop-LibSearch
    $btnLibFilter.Enabled = $true
    $btnLibRefresh.Enabled = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    $treeLib.Nodes.Clear()
    $txtLibInfo.Clear()
    Set-LibWriteEnabled $false
    $btnLibOpen.Enabled = $false
    $lblLibCount.Text = ''

    $root = $txtLibRoot.Text
    if (-not $root -or -not (Test-Path -LiteralPath $root)) {
        if ($root) { $lblLibCount.Text = (T 'racine introuvable') }
        $txtLibInfo.Text = (T "Pour commencer :`r`n1. Choisissez le dossier racine de vos images (bouton ...).`r`n2. Dépliez l'arborescence ou utilisez la recherche.`r`n3. Sélectionnez une image puis « Écriture rapide » ou « Écriture lente ».")
        return
    }

    $filter = $txtLibFilter.Text.Trim()
    if ($filter) {
        if ($script:FastIndexOk) {
            if (Test-LibIndexReady $root) { Show-LibIndexResults $root $filter; return }
            Start-LibIndex $false
            if (Test-LibIndexReady $root) { Show-LibIndexResults $root $filter; return }
            $script:LibPendingSearch = $true
            $lblLibCount.Text = (T 'indexation en cours...')
            return
        }
        Start-LibSearch $root $filter ([bool]$chkLibImgOnly.Checked)
        return
    }
    # Navigation : l'index est charge (ou construit) en arriere-plan pour que la premiere recherche soit instantanee
    if ($script:FastIndexOk -and -not (Test-LibIndexReady $root)) { Start-LibIndex $false }

    $treeLib.BeginUpdate()
    try {
        $rootNode = New-LibNode (Split-Path -Leaf $root) @{ Kind='dir'; Path=$root }
        [void]$treeLib.Nodes.Add($rootNode)
        Populate-LibDir $rootNode
        $rootNode.Expand()
        $lblLibCount.Text = ((T "{0} élément(s)") -f "$($rootNode.Nodes.Count)")
    } finally { $treeLib.EndUpdate() }
    Show-LibIndexStatus
}

function Show-LibSelection($node) {
    Set-LibWriteEnabled $false
    $btnLibOpen.Enabled = $false
    if (-not $node -or -not $node.Tag) { $txtLibInfo.Clear(); return }
    $t = $node.Tag
    $lines = @()
    switch ($t.Kind) {
        'dir' {
            $lines += (T 'Dossier')
            $lines += $t.Path
        }
        'zip' {
            $lines += (T 'Archive ZIP')
            $lines += "$(Format-Size $t.Size)"
            $lines += $t.Path
            $lines += ''
            $lines += (T 'Déplier le nœud pour lister le contenu.')
        }
        'zipentry' {
            $lines += ((T "Dans l'archive : {0}") -f "$([System.IO.Path]::GetFileName($t.ZipPath))")
            $lines += ((T "Entrée  : {0}") -f "$($t.Entry)")
            $lines += ((T "Taille  : {0}") -f "$(Format-Size $t.Size)")
            $lines += ''
            $lines += (T 'Extrait dans un dossier temporaire avant usage.')
            Set-LibWriteEnabled ($t.FileKind -eq 'image')
            $btnLibOpen.Enabled    = ($t.FileKind -eq 'doc')
        }
        'image' {
            $lines += ((T "Image disquette ({0})") -f "$([System.IO.Path]::GetExtension($t.Path))")
            $lines += ((T "Taille : {0}") -f "$(Format-Size $t.Size)")
            $lines += $t.Path
            Set-LibWriteEnabled $true
        }
        'doc' {
            $lines += ((T "Document ({0})") -f "$([System.IO.Path]::GetExtension($t.Path))")
            $lines += ((T "Taille : {0}") -f "$(Format-Size $t.Size)")
            $lines += $t.Path
            $btnLibOpen.Enabled = $true
        }
        default {
            $lines += (T 'Fichier non pris en charge')
            if ($t.Path) { $lines += $t.Path }
        }
    }
    $txtLibInfo.Text = $lines -join [Environment]::NewLine
}

function Expand-ZipEntry([string]$zipPath, [string]$entry) {
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $dest = Join-Path $script:TempDir ([System.IO.Path]::GetFileName($entry))
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $e = $zip.Entries | Where-Object { $_.FullName -eq $entry } | Select-Object -First 1
        if (-not $e) { throw ((T "Entrée introuvable dans l'archive : {0}") -f "$entry") }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true)
    } finally { $zip.Dispose() }
    return $dest
}

function Resolve-LibSelection {
    # Image ou document selectionne : chemin (entree d archive extraite dans TempDir) et source unique (fichier, ou
    # archive + entree : deux archives peuvent extraire le meme nom de fichier)
    $n = $treeLib.SelectedNode
    if (-not $n -or -not $n.Tag) { return $null }
    $t = $n.Tag
    if ($t.Kind -eq 'zipentry') {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        try {
            $p = Expand-ZipEntry $t.ZipPath $t.Entry
            Append-Log ((T "Extrait : {0} -> {1}") -f "$($t.Entry)", "$p")
            return @{ Path = $p; IsImage = ($t.FileKind -eq 'image'); Source = "$($t.ZipPath)|$($t.Entry)" }
        } catch {
            Append-Log ((T "Extraction impossible : {0}") -f "$($_.Exception.Message)")
            return $null
        } finally { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
    }
    if ($t.Kind -eq 'image' -or $t.Kind -eq 'doc' -or $t.Kind -eq 'other') {
        return @{ Path = $t.Path; IsImage = ($t.Kind -eq 'image'); Source = $t.Path }
    }
    return $null
}

# ============================== COMPARAISON : LOGIQUE ==========================
function Invoke-NextChainStep {
    if ($script:Chain.Count -eq 0) { return }
    $step = $script:Chain.Dequeue()
    try {
        & $step
    } catch {
        $script:Chain.Clear(); $script:WriteQueue.Clear()
        Stop-WriteWarmup
        if ($script:Rep) { Stop-WriteCheck }
        Append-Log ((T "ERREUR étape : {0}") -f "$($_.Exception.Message)")
        # Etape de calibration en echec : calibration abandonnee, avec l ecriture qu elle devait preceder
        if ($script:Cal) { Stop-PrecompCalib }
        $script:AfterCalib = ''
        if ($txtCmpResult.Text -like ((T 'Comparaison en cours') + '*')) { $txtCmpResult.Text = ((T "ÉCHEC : {0}") -f "$($_.Exception.Message)") }
        if ($script:Restore) { Stop-Restore ((T "erreur interne : {0}") -f "$($_.Exception.Message)") }
    }
}

function Get-DecodedExt([string]$fmt) {
    if ($fmt -like 'amiga.*') { return '.adf' }
    if ($fmt -like 'atarist.*') { return '.st' }
    return '.img'
}

function Get-SectorsPerTrack([string]$fmt) {
    switch ($fmt) {
        'amiga.amigados'    { return 11 }
        'amiga.amigados_hd' { return 22 }
        'ibm.720'           { return 9 }
        'ibm.1440'          { return 18 }
        'ibm.360'           { return 9 }
        'atarist.720'       { return 9 }
        'atarist.800'       { return 10 }
        'atarist.880'       { return 11 }
        default             { return 0 }
    }
}

function Start-Compare {
    $ref = $txtCmpRef.Text
    if (-not $ref -or -not (Test-Path -LiteralPath $ref)) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Image de référence introuvable.'),(T 'Erreur'),'OK','Warning'); return
    }
    $fmt = $cmbCmpFmt.Text
    if (-not $fmt) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Choisissez un format de décodage.'),(T 'Erreur'),'OK','Warning'); return
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }

    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $ext   = Get-DecodedExt $fmt
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:CmpRefDecoded = Join-Path $script:TempDir "cmp-$stamp-reference$ext"
    $script:CmpDiskRead   = Join-Path $script:TempDir "cmp-$stamp-disquette$ext"
    $script:CmpFmt        = $fmt
    $script:CmpRefName    = [System.IO.Path]::GetFileName($ref)
    $retries = [int]$numCmpRetries.Value

    $txtCmpResult.Text = ((T "Comparaison en cours...`r`nReference : {0}`r`nFormat    : {1}") -f "$ref", "$fmt")
    Append-Log ((T "=== Comparaison : {0} ({1}) ===") -f "$script:CmpRefName", "$fmt")

    $script:CmpRefPath = $ref
    $script:CmpRetries = $retries

    # Etapes = scriptblocks simples (pas de GetNewClosure : un closure tourne dans un
    # module dynamique qui ne voit ni les fonctions du script ni la portee $script:)
    $script:Chain.Clear()
    if ([System.IO.Path]::GetExtension($ref).ToLower() -eq $ext) {
        $script:Chain.Enqueue({
            Copy-Item -LiteralPath $script:CmpRefPath -Destination $script:CmpRefDecoded -Force
            Append-Log (T 'Référence déjà au format décodé : copiée sans conversion.')
            Invoke-NextChainStep
        })
    } else {
        $script:Chain.Enqueue({
            Start-Gw @('convert', "--format=$($script:CmpFmt)", "`"$($script:CmpRefPath)`"", "`"$($script:CmpRefDecoded)`"")
        })
    }
    $script:Chain.Enqueue({
        Start-Gw (@('read') + (Get-CommonArgs) + @("--retries=$($script:CmpRetries)", "--format=$($script:CmpFmt)", "`"$($script:CmpDiskRead)`""))
    })
    $script:Chain.Enqueue({ Compare-Images })
    Invoke-NextChainStep
}

function Compare-Images {
    $refPath = $script:CmpRefDecoded
    $dskPath = $script:CmpDiskRead
    $fmt     = $script:CmpFmt
    if (-not (Test-Path -LiteralPath $refPath) -or -not (Test-Path -LiteralPath $dskPath)) {
        $txtCmpResult.Text = ((T "ÉCHEC : un des deux fichiers décodés est absent.`r`n{0}`r`n{1}") -f "$refPath", "$dskPath")
        Append-Log (T 'Comparaison impossible : fichier décodé manquant.')
        return
    }
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try {
        $a = [System.IO.File]::ReadAllBytes($refPath)
        $b = [System.IO.File]::ReadAllBytes($dskPath)
        $sha = [System.Security.Cryptography.SHA1]::Create()
        $ha = [System.BitConverter]::ToString($sha.ComputeHash($a)).Replace('-','')
        $hb = [System.BitConverter]::ToString($sha.ComputeHash($b)).Replace('-','')

        $sectorSize = 512
        if ($script:FastCompare) {
            $diffSectors = [GwCompare]::DiffSectors($a, $b, $sectorSize)
            $diffBytes   = [GwCompare]::DiffBytes($a, $b)
        } else {
            $n = [Math]::Max($a.Length, $b.Length); $diffBytes = 0
            $set = New-Object System.Collections.Generic.HashSet[int]
            for ($i = 0; $i -lt $n; $i++) {
                if ($i -ge $a.Length -or $i -ge $b.Length -or $a[$i] -ne $b[$i]) { $diffBytes++; [void]$set.Add([int][Math]::Floor($i / $sectorSize)) }
            }
            $diffSectors = @($set | Sort-Object)
        }

        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add(((T "Référence : {0}") -f "$($script:CmpRefName)"))
        $lines.Add(((T "Format    : {0}") -f "$fmt"))
        $lines.Add(((T "Taille    : référence {0} o / disquette {1} o") -f "$($a.Length)", "$($b.Length)"))
        $lines.Add(((T "SHA1 ref  : {0}") -f "$ha"))
        $lines.Add(((T "SHA1 disq : {0}") -f "$hb"))
        $lines.Add('')
        if ($ha -eq $hb) {
            $lines.Add((T 'RÉSULTAT : IDENTIQUE - la disquette correspond octet pour octet à la référence'))
            $lines.Add(((T "           sur l'ensemble des pistes décodables au format {0}.") -f "$fmt"))
            Append-Log ((T "Comparaison : IDENTIQUE ({0} octets)") -f "$($a.Length)")
        } else {
            $totalSectors = [Math]::Ceiling([Math]::Max($a.Length, $b.Length) / $sectorSize)
            $lines.Add(((T "RÉSULTAT : DIFFÉRENT - {0} octet(s) sur {1} secteur(s) / {2}") -f "$diffBytes", "$($diffSectors.Count)", "$totalSectors"))
            if ($a.Length -ne $b.Length) { $lines.Add((T '           (tailles différentes : vérifier le format de décodage)')) }
            $lines.Add('')
            $spt = Get-SectorsPerTrack $fmt
            $shown = 0
            $byTrack = [ordered]@{}
            foreach ($sIdx in $diffSectors) {
                if ($spt -gt 0) {
                    $trk = [int][Math]::Floor($sIdx / $spt); $sec = $sIdx % $spt
                    $key = ((T "Cyl {0} Head {1} (piste {2})") -f "$([int][Math]::Floor($trk / 2))", "$($trk % 2)", "$trk")
                    if (-not $byTrack.Contains($key)) { $byTrack[$key] = New-Object System.Collections.Generic.List[int] }
                    $byTrack[$key].Add($sec)
                } else {
                    if ($shown -lt 40) { $lines.Add(((T "secteur logique {0} (offset 0x{1:X})") -f $sIdx, ($sIdx * $sectorSize))) }
                    $shown++
                }
            }
            if ($spt -gt 0) {
                $lines.Add(((T "Pistes en écart ({0}) :") -f "$($byTrack.Count)"))
                foreach ($k in $byTrack.Keys) {
                    if ($shown -ge 60) { $lines.Add('  ...'); break }
                    $secs = $byTrack[$k]
                    $lines.Add(((T "  {0,-28} secteurs : {1}") -f $k, (($secs | Sort-Object) -join ',')))
                    $shown++
                }
                if ($byTrack.Count -gt 0) {
                    $lines.Add('')
                    $lines.Add((T 'Une piste dont TOUS les secteurs diffèrent est probablement illisible'))
                    $lines.Add((T 'ou non-AmigaDOS (protection) ; quelques secteurs isolés = support marginal.'))
                }
            } elseif ($shown -gt 40) { $lines.Add(((T "  ... {0} autre(s)") -f "$($shown - 40)")) }
            Append-Log ((T "Comparaison : DIFFÉRENT - {0} octet(s), {1} secteur(s)") -f "$diffBytes", "$($diffSectors.Count)")
        }
        $lines.Add('')
        $lines.Add((T "Fichiers décodés conservés :"))
        $lines.Add("  $refPath")
        $lines.Add("  $dskPath")
        $txtCmpResult.Text = ($lines -join "`r`n")
        Show-Tab $tabCmp
    } catch {
        $txtCmpResult.Text = ((T "ERREUR pendant la comparaison : {0}") -f "$($_.Exception.Message)")
        Append-Log ((T "Comparaison : erreur {0}") -f "$($_.Exception.Message)")
    } finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

# ============================== ALIGNEMENT : LOGIQUE ===========================
function Read-ScpFile([string]$path, [int]$cellsPerRev = 0, [switch]$Finger) {
    # cellsPerRev > 0 : motif de test connu (calibration) ; la cellule vaut alors duree du tour / nombre de cellules,
    # au lieu de la mediane des intervalles de deux cellules, qui derive quand le decalage residuel est grand.
    $d = [System.IO.File]::ReadAllBytes($path)
    if ([System.Text.Encoding]::ASCII.GetString($d, 0, 3) -ne 'SCP') { throw (T 'Fichier SCP invalide') }
    $revs = $d[5]; $res = ($d[11] + 1) * 25
    $tracks = @{}
    for ($t = 0; $t -lt 168; $t++) {
        $o = [BitConverter]::ToUInt32($d, 16 + 4 * $t)
        if ($o -eq 0) { continue }
        $tn = $d[$o + 3]; $list = @()
        $fl = New-Object 'System.Collections.Generic.List[int[]]'
        for ($r = 0; $r -lt $revs; $r++) {
            $idx  = [BitConverter]::ToUInt32($d, $o + 4 + 12 * $r)
            $ln   = [BitConverter]::ToUInt32($d, $o + 8 + 12 * $r)
            $doff = [BitConverter]::ToUInt32($d, $o + 12 + 12 * $r)
            $flux = [ScpStats]::Decode($d, [int]($o + $doff), [int]$ln, $res)
            $fl.Add($flux)
            $list += [ScpStats]::Analyze($flux, [double]$idx * $res, $cellsPerRev)
        }
        # Stabilite d un tour a l autre (zones instables : bits faibles d une protection, defaut localise) et, sur
        # demande, empreinte de la piste ; pas pour la calibration (motif connu, une passe par valeur de precomp)
        # Double densite seulement (cellule de 1,7 a 2,3 us, long tracks compris) : en haute densite, la cellule estimee
        # sur les intervalles de 3 a 5 us est fausse et les classes aussi
        if ($cellsPerRev -le 0 -and $list.Count -gt 0 -and -not [double]::IsNaN($list[0].Cell) -and $list[0].Cell -ge 1700 -and $list[0].Cell -le 2300) {
            $ins = [ScpStats]::Instability($fl, [double]$list[0].Cell)
            $list[0].Blocks = $ins[0]; $list[0].Unstable = $ins[1]; $list[0].MaxRun = $ins[2]; $list[0].RunPos = $ins[3]
            if ($Finger) { $list[0].Finger = [ScpStats]::Fingerprint($fl[0], [double]$list[0].Cell, 8); $list[0].Rich = [ScpStats]::RichCount($fl[0], [double]$list[0].Cell) }
        }
        $tracks[[int]$tn] = $list
    }
    return $tracks
}

function Read-ScpTrackFlux([string]$path, [int]$tn) {
    # Flux brut de chaque tour d une piste d un SCP (sonde de la restauration en flux)
    $d = [System.IO.File]::ReadAllBytes($path)
    if ([System.Text.Encoding]::ASCII.GetString($d, 0, 3) -ne 'SCP') { throw (T 'Fichier SCP invalide') }
    $revs = $d[5]; $res = ($d[11] + 1) * 25
    $fl = New-Object 'System.Collections.Generic.List[int[]]'
    if ($tn -lt 0 -or $tn -ge 168) { return ,$fl }
    $o = [BitConverter]::ToUInt32($d, 16 + 4 * $tn)
    if ($o -eq 0) { return ,$fl }
    for ($r = 0; $r -lt $revs; $r++) {
        $ln   = [BitConverter]::ToUInt32($d, $o + 8 + 12 * $r)
        $doff = [BitConverter]::ToUInt32($d, $o + 12 + 12 * $r)
        $fl.Add([ScpStats]::Decode($d, [int]($o + $doff), [int]$ln, $res))
    }
    return ,$fl
}

function Get-AlignCyls {
    $vals = @()
    foreach ($tok in ($txtAlCyls.Text -split '[,; ]+')) {
        if ($tok -match '^\d+$') { $v = [int]$tok; if ($v -ge 0 -and $v -le 83) { $vals += $v } }
    }
    return ($vals | Sort-Object -Unique)
}

function Start-AlignCycle {
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    $cyls = Get-AlignCyls
    if (-not $cyls -or $cyls.Count -eq 0) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Indiquez au moins un cylindre valide (0-83).'),(T 'Alignement'),'OK','Warning')
        $script:AlignLoop = $false; return
    }
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $script:AlignTmp = Join-Path $script:TempDir 'align.scp'
    if (Test-Path -LiteralPath $script:AlignTmp) { Remove-Item -LiteralPath $script:AlignTmp -Force }
    $cspec = ($cyls -join ',')
    $hspec = if ($cmbAlHead.Text -eq '0+1') { '0-1' } else { $cmbAlHead.Text }
    $script:AlignArgs = @('read') + (Get-CommonArgs) + @("--revs=$($numAlRevs.Value)", "--tracks=c=${cspec}:h=$hspec", "`"$($script:AlignTmp)`"")
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw $script:AlignArgs })
    $script:Chain.Enqueue({ Invoke-AlignAnalysis })
    Invoke-NextChainStep
}

function Get-AlLevel([string]$kind, [double]$v) {
    switch ($kind) {
        'score'  { if ($v -lt 100) { 0 } elseif ($v -lt 200) { 1 } elseif ($v -lt 400) { 2 } else { 3 } }
        'jitter' { if ($v -lt $script:JitterOk * 0.5) { 0 } elseif ($v -lt $script:JitterOk) { 1 } elseif ($v -lt (Get-JitterRedBound)) { 2 } else { 3 } }
        'asym'   { if ($v -lt 0.02){ 0 } elseif ($v -lt 0.05){ 1 } elseif ($v -lt 0.10){ 2 } else { 3 } }
        'err'    { if ($v -le 0)   { 0 } elseif ($v -le 3)   { 1 } elseif ($v -le 20)  { 2 } else { 3 } }
        'stab'   { if ($v -le 2)   { 0 } elseif ($v -le 5)   { 1 } elseif ($v -le 10)  { 2 } else { 3 } }
        'delta'  { if ($v -le 10)  { 0 } elseif ($v -le 30)  { 1 } elseif ($v -le 100) { 2 } else { 3 } }   # ecart % vs reference
        default  { 3 }
    }
}

function Draw-AlignBars($g, $size) {
    $g.Clear([System.Drawing.Color]::White)
    $font = New-Object System.Drawing.Font('Segoe UI', 8)
    if (-not $script:AlignLast -or $script:AlignLast.Count -eq 0) {
        $g.DrawString((T 'Barres de score par cylindre : apparaissent après la première mesure.'), $font, [System.Drawing.Brushes]::Gray, 8, 26); return
    }
    $keys = @($script:AlignLast.Keys | Sort-Object { [double]$_ })
    $n = $keys.Count; $left = 44; $w = [math]::Max(10, ($size.Width - $left - 10) / $n); $h = $size.Height
    # echelle auto : la plus grande valeur affichee (mesure, reference, meilleur) + 15 %, arrondie a 50, minimum 100
    $peak = 0.0
    foreach ($v in $script:AlignLast.Values) { if ($v.Score -lt 2000 -and $v.Score -gt $peak) { $peak = $v.Score } }
    if ($script:AlignRef) { foreach ($v in $script:AlignRef.Values) { if ($v.Score -lt 2000 -and $v.Score -gt $peak) { $peak = $v.Score } } }
    foreach ($k in $script:AlignBest.Keys) { if ($k -ne '_global' -and $script:AlignBest[$k] -lt 2000 -and $script:AlignBest[$k] -gt $peak) { $peak = $script:AlignBest[$k] } }
    $maxScore = [math]::Max(100.0, [math]::Ceiling($peak * 1.15 / 50) * 50)
    # axe
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Gainsboro)
    foreach ($frac in 0.25,0.5,0.75) { $y = [int]($h - 14 - ($h - 24) * $frac); $g.DrawLine($pen, $left, $y, $size.Width - 6, $y) }
    $g.DrawString('0', $font, [System.Drawing.Brushes]::Gray, 2, $h - 22)
    $g.DrawString([string][int]$maxScore, $font, [System.Drawing.Brushes]::Gray, 2, 2)
    $i = 0
    foreach ($k in $keys) {
        $st = $script:AlignLast[$k]
        $x = [int]($left + $i * $w + 4); $bw = [int]($w - 8)
        $sc = [math]::Min($st.Score, $maxScore)
        $bh = [int](($h - 24) * ($sc / $maxScore)); if ($bh -lt 2) { $bh = 2 }
        $lvl = Get-AlLevel 'score' $st.Score
        $brush = New-Object System.Drawing.SolidBrush($script:AlColors[$lvl])
        $g.FillRectangle($brush, $x, $h - 14 - $bh, $bw, $bh)
        $g.DrawRectangle([System.Drawing.Pens]::DimGray, $x, $h - 14 - $bh, $bw, $bh)
        # repere reference (trait noir) et meilleur (trait bleu)
        if ($script:AlignRef -and $script:AlignRef.ContainsKey($k)) {
            $ry = [int]($h - 14 - ($h - 24) * ([math]::Min($script:AlignRef[$k].Score, $maxScore) / $maxScore))
            $g.DrawLine([System.Drawing.Pens]::Black, $x - 2, $ry, $x + $bw + 2, $ry)
            $g.DrawLine([System.Drawing.Pens]::Black, $x - 2, $ry + 1, $x + $bw + 2, $ry + 1)
        }
        if ($script:AlignBest.ContainsKey($k)) {
            $by = [int]($h - 14 - ($h - 24) * ([math]::Min($script:AlignBest[$k], $maxScore) / $maxScore))
            $g.DrawLine([System.Drawing.Pens]::RoyalBlue, $x - 2, $by, $x + $bw + 2, $by)
        }
        $label = if ($cmbAlHead.Text -eq '0+1') { "c$k" } else { "c$($k -replace '\.\d+$','')" }
        $g.DrawString($label, $font, [System.Drawing.Brushes]::Black, $x, $h - 14)
        $g.DrawString(('{0:N0}' -f $st.Score), $font, [System.Drawing.Brushes]::Black, $x, [math]::Max(0, $h - 14 - $bh - 14))
        $i++
    }
}

function Update-AlignGuide([double]$avg) {
    if ($null -eq $script:AlPos) { $lblAlPos.Text = ''; return }
    $pos = [int]$script:AlPos
    if (-not $script:AlPosScores.ContainsKey($pos) -or $avg -lt $script:AlPosScores[$pos]) { $script:AlPosScores[$pos] = $avg }
    $bestPos = $pos; $bestScore = [double]::PositiveInfinity
    foreach ($k in $script:AlPosScores.Keys) { if ($script:AlPosScores[$k] -lt $bestScore) { $bestScore = $script:AlPosScores[$k]; $bestPos = [int]$k } }
    $lblAlPos.Text = ((T "Position {0}  |  meilleure position : {1} (score {2})") -f "$pos", "$bestPos", "$([math]::Round($bestScore,0))")

    $sens = @{ 1 = "'+'"; -1 = "'-'" }
    $color = 'DimGray'; $txt = ''
    if ($script:AlLastMove -eq 0) {
        if ($script:AlPosScores.Count -le 1) {
            $txt = ((T "Position 0 mesurée (score {0}). Tournez le stepper d'UN PETIT cran dans un sens, puis cliquez sur le bouton correspondant.") -f "$([math]::Round($avg,0))")
            $color = 'RoyalBlue'
        } else {
            $txt = ((T "Position {0} re-mesurée. Meilleure position connue : {1}.") -f "$pos", "$bestPos")
            if ($pos -ne $bestPos) { $txt += ((T " Revenez de {0} cran(s) vers le sens {1} pour la retrouver.") -f "$([math]::Abs($pos-$bestPos))", "$($sens[[math]::Sign($bestPos-$pos)])") }
        }
    } else {
        $prev = $pos - $script:AlLastMove
        $prevScore = if ($script:AlPosScores.ContainsKey($prev)) { $script:AlPosScores[$prev] } else { $null }
        if ($null -eq $prevScore) {
            $txt = ((T "Position {0} mesurée. Pas de mesure à la position précédente : impossible de conclure, continuez.") -f "$pos")
        } elseif ($avg -lt $prevScore * 0.97) {
            $txt = ((T "AMÉLIORATION ({0} -> {1}) : CONTINUEZ dans le sens {2}, encore un cran, puis mesurez.") -f "$([math]::Round($prevScore,0))", "$([math]::Round($avg,0))", "$($sens[$script:AlLastMove])")
            $color = 'Green'
        } elseif ($avg -gt $prevScore * 1.03) {
            # le pas precedent etait-il un optimum (moins bon des deux cotes) ?
            $other = $prev - $script:AlLastMove
            $otherWorse = $script:AlPosScores.ContainsKey($other) -and ($script:AlPosScores[$other] -gt $prevScore * 1.03)
            if ($otherWorse -and $prev -eq $bestPos) {
                $txt = ((T "OPTIMUM TROUVÉ à la position {0} (score {1}) : RECULEZ d'un cran (sens {2}), resserrez les vis, re-mesurez pour contrôle.") -f "$prev", "$([math]::Round($prevScore,0))", "$($sens[-$script:AlLastMove])")
                $color = 'DarkGreen'
            } else {
                $txt = ((T "DÉGRADATION ({0} -> {1}) : RECULEZ d'un cran (sens {2}) pour revenir à la position {3}, puis essayez l'autre sens.") -f "$([math]::Round($prevScore,0))", "$([math]::Round($avg,0))", "$($sens[-$script:AlLastMove])", "$prev")
                $color = 'DarkOrange'
            }
        } else {
            $txt = ((T "Pas de changement net ({0} -> {1}) : cran trop petit ou plateau. Encore un cran dans le sens {2}.") -f "$([math]::Round($prevScore,0))", "$([math]::Round($avg,0))", "$($sens[$script:AlLastMove])")
            $color = 'DimGray'
        }
        if ($pos -ne $bestPos -and $color -ne 'DarkGreen' -and $avg -gt $bestScore * 1.10) {
            $txt += ((T "  (Meilleur connu : position {0}.)") -f "$bestPos")
        }
    }
    $lblAlReco.Text = $txt; $lblAlReco.ForeColor = $color
    Append-Log ((T "Guide alignement : {0}") -f "$txt")
}

function Render-AlignBars { $pnlAlBars.Invalidate() }

function Get-HealthLevel([double]$err, [double]$drop, [double]$stab, [double]$jit, [double]$okT = $script:JitterOk, [double]$watchT = $script:JitterWatch) {
    # Seuils de jitter reglables (Accueil, « Regler le jitter ») ; l asymetrie n entre pas dans l etat. Seuils explicites
    # (Standard 120 / 250 ns) pour juger un ORIGINAL et pour le garde-fou du controle : un reglage strict ne doit faire
    # que reecrire davantage de pistes de la copie, pas rejeter une source lisible ni bloquer les reecritures.
    if ($err -le 3 -and $drop -le 0 -and $stab -le 2 -and $jit -lt $okT) { return 0 }
    if ($err -le 20 -and $drop -le 1 -and $stab -le 10 -and $jit -lt $watchT) { return 1 }
    return 2
}

function Get-JitterRedBound {
    # Borne orange / rouge de la colonne Jitter : toujours au-dessus du seuil SAIN (bande orange non vide)
    return [math]::Max($script:JitterWatch * 0.8, ($script:JitterOk + $script:JitterWatch) / 2)
}

function Update-QualityTip {
    $tip.SetToolTip($lvAl, ((T "État par piste : SAIN / À SURVEILLER / CRITIQUE, d'après les erreurs, les trous, la stabilité et le jitter.`nJitter : SAIN sous {0} ns, À SURVEILLER sous {1} ns (onglet Accueil, « Régler le jitter »).`nCouleurs de la colonne Jitter : <{2} / <{0} / <{3} ns. Asymétrie : <0,02 / <0,05 / <0,10 (couleur et score seulement, sans effet sur l'état).") -f "$($script:JitterOk)", "$($script:JitterWatch)", "$([math]::Round($script:JitterOk * 0.5))", "$([math]::Round((Get-JitterRedBound)))"))
}

function Set-JitterThresholds([int]$ok, [int]$watch) {
    # Bornes : SAIN de 30 a 300 ns, A SURVEILLER au moins 10 ns au-dessus, 600 ns au plus
    $ok = [math]::Max(30, [math]::Min(300, $ok))
    $watch = [math]::Max($ok + 10, [math]::Min(600, $watch))
    $script:JitterOk = $ok; $script:JitterWatch = $watch
    Update-QualityTip
}

function Get-JitterPresets {
    return @(
        @{ Name = (T 'Standard (120 / 250 ns)'); Ok = 120; Watch = 250 },
        @{ Name = (T 'Strict (90 / 180 ns)'); Ok = 90; Watch = 180 },
        @{ Name = (T 'Très strict (70 / 140 ns)'); Ok = 70; Watch = 140 }
    )
}

function Show-JitterSettings {
    # Reglage des seuils de jitter (etat SAIN / A SURVEILLER / CRITIQUE) : onglet Qualite, controle apres ecriture,
    # restauration. Refuse pendant une operation (un controle en cours changerait de criteres en route).
    if (($script:GwProc -and -not $script:GwProc.HasExited) -or $script:Chain.Count -gt 0 -or $script:Rep -or $script:Cal -or $script:Restore) {
        [void][System.Windows.Forms.MessageBox]::Show((T "Opération en cours : modifiez le réglage du jitter une fois l'opération terminée."), (T 'Réglage du jitter'), 'OK', 'Information'); return
    }
    $w = 540
    $presets = Get-JitterPresets
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmJitter'; $dlg.Text = (T 'Réglage du jitter')
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    $text = (T "Le jitter mesure la dispersion des intervalles entre les transitions magnétiques d'une piste, en nanosecondes : plus il est faible, plus la piste est nette.`n`nCes seuils fixent l'état de chaque piste dans l'onglet « Qualité & alignement », dans le contrôle après écriture et dans la restauration. Une piste n'est SAINE que si son jitter est sous le premier seuil, et si ses erreurs, ses trous et sa stabilité sont bons. Au-delà du second seuil, elle est CRITIQUE.`n`nAprès une écriture avec contrôle de toutes les pistes (écriture lente, restauration), une piste qui n'est pas SAINE est réécrite, dans la limite des passes de réécriture : un réglage plus strict fait réécrire davantage de pistes, donc davantage d'écritures sur la disquette. Le jugement de la disquette d'origine en restauration et le garde-fou (plus de la moitié des pistes faibles : aucune réécriture) gardent les seuils Standard.")
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.AutoSize = $false; $lbl.UseMnemonic = $false; $lbl.Text = $text; $lbl.Location = New-Object System.Drawing.Point(16, 16)
    $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $h = [System.Windows.Forms.TextRenderer]::MeasureText($text, $dlg.Font, (New-Object System.Drawing.Size($w, 10000)), $tf).Height
    $lbl.Size = New-Object System.Drawing.Size($w, ($h + 4))
    $y = $lbl.Bottom + 14
    $l1 = New-Object System.Windows.Forms.Label; $l1.Text = (T 'Préréglage :'); $l1.AutoSize = $true; $l1.Location = New-Object System.Drawing.Point(16, ($y + 3))
    $cmb = New-Object System.Windows.Forms.ComboBox
    $cmb.Name = 'cmbJitPreset'; $cmb.DropDownStyle = 'DropDownList'; $cmb.Location = New-Object System.Drawing.Point(290, $y); $cmb.Width = 240
    foreach ($pr in $presets) { [void]$cmb.Items.Add($pr.Name) }
    [void]$cmb.Items.Add((T 'Personnalisé'))
    $y += 36
    $l2 = New-Object System.Windows.Forms.Label; $l2.Text = (T 'SAIN si le jitter est inférieur à :'); $l2.AutoSize = $true; $l2.Location = New-Object System.Drawing.Point(16, ($y + 3))
    $numOk = New-Object System.Windows.Forms.NumericUpDown
    $numOk.Name = 'numJitOk'; $numOk.Minimum = 30; $numOk.Maximum = 300; $numOk.Increment = 5; $numOk.Width = 80; $numOk.Location = New-Object System.Drawing.Point(290, $y)
    $u1 = New-Object System.Windows.Forms.Label; $u1.Text = 'ns'; $u1.AutoSize = $true; $u1.Location = New-Object System.Drawing.Point(376, ($y + 3))
    $y += 34
    $l3 = New-Object System.Windows.Forms.Label; $l3.Text = (T "À SURVEILLER s'il est inférieur à :"); $l3.AutoSize = $true; $l3.Location = New-Object System.Drawing.Point(16, ($y + 3))
    $numWatch = New-Object System.Windows.Forms.NumericUpDown
    $numWatch.Name = 'numJitWatch'; $numWatch.Minimum = 40; $numWatch.Maximum = 600; $numWatch.Increment = 10; $numWatch.Width = 80; $numWatch.Location = New-Object System.Drawing.Point(290, $y)
    $u2 = New-Object System.Windows.Forms.Label; $u2.Text = 'ns'; $u2.AutoSize = $true; $u2.Location = New-Object System.Drawing.Point(376, ($y + 3))
    $y += 34
    $l4 = New-Object System.Windows.Forms.Label; $l4.Text = (T 'Au-delà : CRITIQUE. Les nouvelles valeurs valent pour les prochaines mesures.'); $l4.AutoSize = $true; $l4.ForeColor = $script:Theme.Muted; $l4.Location = New-Object System.Drawing.Point(16, $y)
    $y += 34
    $btnDef = New-Object System.Windows.Forms.Button; $btnDef.Name = 'btnJitDefault'; $btnDef.Text = (T 'Valeurs par défaut'); $btnDef.Size = New-Object System.Drawing.Size(170, 34)
    $btnOk = New-Object System.Windows.Forms.Button; $btnOk.Name = 'btnJitOk'; $btnOk.Text = (T 'Enregistrer'); $btnOk.Size = New-Object System.Drawing.Size(140, 34)
    $btnNo = New-Object System.Windows.Forms.Button; $btnNo.Name = 'btnJitCancel'; $btnNo.Text = (T 'Annuler'); $btnNo.Size = New-Object System.Drawing.Size(110, 34)
    $btnNo.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-Btn $btnDef 'Refresh' 'normal'; Set-Btn $btnOk 'Save' 'primary'; Set-Btn $btnNo '' 'normal'
    $btnDef.Location = New-Object System.Drawing.Point(16, $y)
    $btnNo.Location = New-Object System.Drawing.Point((16 + $w - $btnNo.Width), $y)
    $btnOk.Location = New-Object System.Drawing.Point(($btnNo.Left - 8 - $btnOk.Width), $y)
    $dlg.ClientSize = New-Object System.Drawing.Size(($w + 32), ($y + $btnOk.Height + 16))
    $dlg.AcceptButton = $btnOk; $dlg.CancelButton = $btnNo
    $dlg.Controls.AddRange(@($lbl, $l1, $cmb, $l2, $numOk, $u1, $l3, $numWatch, $u2, $l4, $btnDef, $btnOk, $btnNo))
    # Etat partage avec les gestionnaires (portee script) : prereglage <-> valeurs, sans boucle
    $script:JitDlg = @{ Presets = $presets; Cmb = $cmb; Ok = $numOk; Watch = $numWatch; Busy = $false; Dlg = $dlg }
    $numOk.Value = $script:JitterOk; $numWatch.Value = $script:JitterWatch
    $sync = {
        $s = $script:JitDlg
        if (-not $s -or $s.Busy) { return }
        $s.Busy = $true
        $i = -1
        for ($k = 0; $k -lt $s.Presets.Count; $k++) { if ($s.Presets[$k].Ok -eq [int]$s.Ok.Value -and $s.Presets[$k].Watch -eq [int]$s.Watch.Value) { $i = $k } }
        $s.Cmb.SelectedIndex = $(if ($i -ge 0) { $i } else { $s.Presets.Count })
        $s.Busy = $false
    }
    & $sync
    $numOk.Add_ValueChanged($sync); $numWatch.Add_ValueChanged($sync)
    $cmb.Add_SelectedIndexChanged({
        $s = $script:JitDlg
        if (-not $s -or $s.Busy -or $s.Cmb.SelectedIndex -lt 0 -or $s.Cmb.SelectedIndex -ge $s.Presets.Count) { return }
        $s.Busy = $true
        $pr = $s.Presets[$s.Cmb.SelectedIndex]
        $s.Ok.Value = $pr.Ok; $s.Watch.Value = $pr.Watch
        $s.Busy = $false
    })
    $btnDef.Add_Click({ $script:JitDlg.Cmb.SelectedIndex = 0 })
    $btnOk.Add_Click({
        $s = $script:JitDlg
        if ([int]$s.Watch.Value -lt [int]$s.Ok.Value + 10) {
            [void][System.Windows.Forms.MessageBox]::Show((T "Le seuil À SURVEILLER doit dépasser le seuil SAIN d'au moins 10 ns."), (T 'Réglage du jitter'), 'OK', 'Warning'); return
        }
        $s.Dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
    })
    $dr = $dlg.ShowDialog($form)
    if ($dr -eq [System.Windows.Forms.DialogResult]::OK) {
        Set-JitterThresholds ([int]$numOk.Value) ([int]$numWatch.Value)
        [void](Save-Config)
        Append-Log ((T "Réglage du jitter : SAIN sous {0} ns, À SURVEILLER sous {1} ns, CRITIQUE au-delà (prochaines mesures).") -f "$($script:JitterOk)", "$($script:JitterWatch)")
    }
    $script:JitDlg = $null
    $dlg.Dispose()
}

function Show-HomeCurve {
    # Courbe de la derniere calibration, toutes familles confondues : pour chaque famille, courbes par tete si elles sont
    # a jour, sinon la courbe commune (Get-FamilyCurves) ; on garde la famille dont cette courbe est la plus recente
    $best = $null; $bestDate = [datetime]::MinValue
    foreach ($f in @('std', 'long')) {
        $cvs = Get-FamilyCurves $f $true
        if ($cvs.Count -eq 0) { continue }
        $d = Get-CurveDate $cvs[0]
        if ($null -eq $best -or $d -gt $bestDate) { $best = $f; $bestDate = $d }
    }
    if ($best) { Show-PrecompCurve $best $true; return }
    [void][System.Windows.Forms.MessageBox]::Show((T "Aucune calibration enregistrée.`n`nLa courbe apparaît après une première calibration : bouton « Calibrer » de l'onglet Écriture, ou première écriture depuis la Bibliothèque."), (T 'Courbe de calibration'), 'OK', 'Information')
}

# ============================== ACCUEIL : CALIBRATION ==========================
# Carte « Calibrer le lecteur » : type de disquette choisi dans la liste de tous les formats de gw 1.23 ($script:GwFormats)
# et des types d image sans format gw ; famille de calibration ou raison de l absence de calibration ; etat des courbes ;
# courbe ; calibration complete (test standard ou fin, prechauffage compris sauf case decochee) ou rapide, sans image :
# une image de geometrie (HFE du generateur du motif, New-CalibGeometry) tient lieu d image pour Test-CalibImage,
# Get-LevelRef et New-CalibPattern, qui en tirent famille, cylindres et densite comme d une image de l onglet Ecriture.

function Get-FormatCalibInfo([string]$name) {
    # Calibration d un format gw (table GwFormats). Cal = 'std' avec Bits (cellules par piste du motif, celles que
    # Get-PatternBits retient pour une image de ce format : ADF 101 344, autres 100 000), NCyl (35 au moins) et Notes ;
    # sinon Why, raison affichee. Group : groupe de la liste de la carte. Memes regles que l ecriture : haute densite
    # (Test-HdFormat, ou debit de 450 kbit/s et plus), GCR, FM, codages propres, secteurs durs, 360 tr/min, cellule hors
    # plage. Debit de 260 ou 261 kbit/s (Atari) : famille standard, comme l ecriture d une image secteur, avec une note.
    $r = @{ Name = $name; Label = $name; Group = 'other'; Cal = $null; Why = ''; Notes = @(); NCyl = 0; Heads = 0; Bits = 0; BitsSrc = ''; Rate = 0 }
    $e = $script:GwFormats[$name]
    if (-not $e) { $r.Why = (T "format absent de la table de l'application (gw plus récent ou fichier diskdefs) : calibrez depuis l'onglet Écriture, avec l'image et ce format"); return $r }
    $r.NCyl = [math]::Max(35, [int]$e.Cyls); $r.Heads = [int]$e.Heads
    $rate = [int]$e.Rate; $r.Rate = $rate
    $hd = (Test-HdFormat $name) -or $rate -ge 450
    $gcr = (@('c64', 'a2', 'mac') -contains $e.Enc)
    $grp = ''
    if ($e.Enc -eq 'amiga') { $grp = $(if ($hd) { 'amiga_hd' } else { 'amiga_dd' }) }
    elseif ($gcr) { $grp = 'gcr' }
    elseif ($e.Enc -eq 'fm') { $grp = 'fm' }
    elseif ($hd) { $grp = 'hd' }
    elseif ($e.Enc -eq 'mfm' -and $name -match '^(ibm|atarist)\.') { $grp = 'pc_dd' }
    if ($e.Enc -eq 'scan') { $r.Why = (T "format de balayage : gw n'écrit pas une image secteur avec ibm.scan, densité inconnue à l'avance") }
    elseif ($hd) { $r.Why = (T "haute densité : les courbes calibrées sont double densité ; l'écriture applique le profil d'origine de la famille, non calibré") }
    elseif ($gcr) { $r.Why = (T 'codage GCR : la calibration ne mesure que le MFM double densité') }
    elseif ($e.Enc -eq 'fm') { $r.Why = (T 'codage FM (simple densité) : la calibration ne mesure que le MFM double densité') }
    elseif (@('m2fm', 'dg') -contains $e.Enc) { $r.Why = (T 'codage propre au système (M2FM, Data General) : la calibration ne mesure que le MFM double densité') }
    elseif ($e.Enc -eq 'hard') { $r.Why = (T 'disquette à secteurs durs : calibration non prise en charge') }
    elseif ([int]$e.Rpm -ne 300) { $r.Why = ((T "format à {0} tr/min : le motif de test suppose un lecteur à 300 tr/min") -f "$($e.Rpm)") }
    elseif ($e.Enc -eq 'bit' -and $rate -ne 250) { $r.Why = ((T "cellule de {0} ns, hors de la plage mesurable (1 700 à 2 300 ns)") -f "$([math]::Round(500000 / $rate))") }
    else {
        $r.Cal = 'std'
        if ($e.Enc -eq 'amiga') { $r.Bits = 101344; $r.BitsSrc = (T 'ADF, horloge AmigaDOS de gw') }
        else { $r.Bits = 100000; $r.BitsSrc = (T 'format à secteurs, 2 µs par cellule') }
        if ($rate -gt 250) { $r.Notes += ((T "Débit de {0} kbit/s (cellule de {1} ns) : l'écriture de ce format applique la courbe {2}, mesurée à 2 µs par cellule (densité plus forte de {3} %).") -f "$rate", "$([math]::Round(500000 / $rate))", (Get-CalibFamilyName 'std'), (Format-UiNum ([math]::Round(100.0 * ($rate - 250) / 250, 1)))) }
        if ($e.Enc -eq 'fm0') { $r.Notes += (T 'Piste 0 en FM : non mesurée, la courbe s''y applique telle quelle.') }
        if ($r.Heads -eq 1) { $r.Notes += (T 'Format simple face : la calibration écrit aussi la face 1 (lecteur double face nécessaire).') }
        if ([int]$e.Cyls -ne 80) { $r.Notes += ((T "{0} cylindres dans la définition de gw.") -f "$($e.Cyls)") }
    }
    if (-not $grp) { $grp = $(if ($r.Cal) { 'other_dd' } else { 'other' }) }
    $r.Group = $grp
    return $r
}

function Get-HomeCalibInfo([string]$name) {
    # Type de disquette de la carte : format gw (Get-FormatCalibInfo) ou type d image de l application sans format gw
    $r = @{ Name = $name; Label = ''; Group = 'long'; Cal = $null; Why = ''; Notes = @(); NCyl = 0; Heads = 0; Bits = 0; BitsSrc = ''; Rate = 0 }
    switch ($name) {
        'app.long' {
            # 105 808 cellules : Get-PatternBits d une image long track illisible (105 820 ramene a un multiple de 16)
            $r.Label = (T 'Amiga longues pistes (IPF, HFE)'); $r.Cal = 'long'; $r.Bits = 105808; $r.NCyl = 80; $r.Heads = 2
            $r.BitsSrc = (T 'long track, 1,89 µs par cellule')
            $r.Notes = @((T "Pistes longues d'une protection contre la copie : la cellule réelle et le nombre de cylindres (jusqu'à 84) se lisent dans l'image ; « Calibrer » dans l'onglet Écriture, avec l'image, les reprend exactement."))
            return $r
        }
        'app.flux' { $r.Label = (T 'Flux : SCP, RAW, KF, A2R, CTR'); $r.Why = (T "flux écrit tel quel, sans précompensation (gw ne l'applique qu'aux images à secteurs ou à bits) : pas de calibration"); return $r }
        'app.free' {
            $r.Label = (T 'Géométrie libre : IMD, TD0, D88, MSA, DSK CPC'); $r.Group = 'other'
            $r.Why = ((T "densité non établie par l'application : l'écriture ne calibre pas, elle applique la courbe {0} ; pour la calibrer, choisissez le format gw de la disquette (atarist.720 pour un MSA de 720 Ko, par exemple)") -f (Get-CalibFamilyName 'std'))
            return $r
        }
    }
    return (Get-FormatCalibInfo $name)
}

function Get-HomeCalibList {
    # Liste de la carte : types d image de l application, puis les formats de gw 1.23 dans l ordre de la table
    return @(@(@($script:HomeCalApp) + @($script:GwFormats.Keys)) | ForEach-Object { Get-HomeCalibInfo $_ })
}

function Get-HomeCurveState([string]$fam) {
    # Etat des courbes d une famille : commune et par tete (date, lecteur, test, cylindres, calcul, convergence)
    $lines = @()
    foreach ($k in @($fam, "${fam}_h0", "${fam}_h1")) {
        $cv = $script:PrecompCurves[$k]
        if (-not $cv) { $lines += ((T "{0} : aucune courbe") -f (Get-CurveKeyLabel $k)); continue }
        $tt = if ([string]$cv.Test -eq 'fine') { (T 'test fin') } elseif ([string]$cv.Test -eq 'std') { (T 'test standard') } else { (T 'test non enregistré') }
        $st = (T "{0} : {1}, lecteur {2}, {3}, {4} cylindres, calcul {5}") -f (Get-CurveKeyLabel $k), "$($cv.Date)", "$($cv.Drive)", "$tt", "$(@($cv.Values).Count)", (Get-CurveCalcText $cv)
        if ($cv.Converged -eq $false) { $st += (T ', NON CONVERGÉE') }
        $lines += $st
    }
    if ($script:PrecompCurves["${fam}_h0"] -and $script:PrecompCurves["${fam}_h1"] -and -not (Test-HeadCurvesCurrent $fam)) { $lines += (T 'Courbes par tête antérieures à la courbe commune : non appliquées.') }
    return ($lines -join "`r`n")
}

function New-CalibGeometry($info, [int]$nCyl) {
    # Image de geometrie de la carte : HFE du generateur du motif de test aux cylindres et aux cellules par piste du type
    # choisi. Get-ImageCylinders (en-tete), Get-ImageFamily, Get-PatternBits, Get-CellOutOfRange et Get-HighDensityReason
    # (table des pistes, 8 x (longueur // 2) = cellules) la lisent comme toute image HFE : la calibration complete ou
    # rapide en deduit famille, cylindres et densite. Cellules : 100 000 (2 000 ns), 101 344 (1 973,5 ns), 105 808
    # (1 890,2 ns, sous le seuil PrecompThresholdNs de 1 950 ns par defaut).
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $path = Join-Path $script:TempDir 'precomp-geometry.hfe'
    [CalibPattern]::WriteHfe($path, $nCyl, [int]$info.Bits, [int][math]::Round($info.Bits / 400.0), 20261014)
    return $path
}

function Get-WriteTabFamily {
    # Famille de l image de l onglet Ecriture ; $null sans image, pour un flux ou une image haute densite
    $p = $txtWFile.Text
    if (-not $p -or -not (Test-Path -LiteralPath $p)) { return $null }
    if (@('.scp', '.raw', '.kf', '.a2r', '.ctr') -contains [System.IO.Path]::GetExtension($p).ToLower()) { return $null }
    if (Get-HighDensityReason $p $cmbWFmt.Text) { return $null }
    return (Get-ImageFamily $p)
}

function Test-HomeCalibBusy {
    # Operation en cours : gw, chaine d etapes, controle, calibration, restauration, detection, prechauffage d ecriture
    return [bool](($script:GwProc -and -not $script:GwProc.HasExited) -or $script:Chain.Count -gt 0 -or $script:Rep -or $script:Cal -or $script:Restore -or $script:Detect -or $script:WriteWarm)
}

function Start-HomeCalib([string]$name, [string]$test, [bool]$heads, [int]$nCyl, [bool]$warm = $true) {
    # Calibration de la carte, sans image : image de geometrie du type choisi, puis calibration complete (test 'std' ou
    # 'fine' ; warm : prechauffage du lecteur s il est regle) ou rapide ('level'). Pas de fenetre ici hors de celles de la
    # calibration (testable) : renvoie @{ Started ; Why } (Why vide : avertissement refuse par l utilisateur).
    $res = @{ Started = $false; Why = '' }
    if (Test-HomeCalibBusy) { $res.Why = (T 'opération en cours'); return $res }
    if (-not $script:ScpStatsOk) { $res.Why = (T "module d'analyse SCP indisponible (Add-Type)"); return $res }
    $info = Get-HomeCalibInfo $name
    if (-not $info.Cal) { $res.Why = $info.Why; return $res }
    $nCyl = [math]::Max(2, [math]::Min(84, $nCyl))
    try { $img = New-CalibGeometry $info $nCyl }
    catch { $res.Why = ((T "image de géométrie impossible à créer : {0}") -f "$($_.Exception.Message)"); return $res }
    # Seuil de famille de la configuration (precompThresholdNs) : la famille deduite de la geometrie doit etre celle du type
    $fam = Get-ImageFamily $img
    if ($fam -ne $info.Cal) { $res.Why = ((T "seuil de famille precompThresholdNs de {0} ns : ce type serait calibré dans la famille {1}") -f "$($script:PrecompThresholdNs)", (Get-CalibFamilyName $fam)); return $res }
    $script:HomeCalFmt = $name
    $geom = @{ Img = $img; Label = [string]$info.Label; Fmt = $name; BitsSrc = [string]$info.BitsSrc; CylSrc = ((T "{0} cylindres choisis dans l'Accueil") -f "$nCyl") }
    $script:AfterCalib = ''
    $tt = switch ($test) { 'level' { (T 'calibration rapide') } 'fine' { (T 'test fin') } default { (T 'test standard') } }
    $kt = if ($heads) { (T 'une courbe par tête') } else { (T 'courbe commune') }
    Append-Log ((T "Calibration depuis l'Accueil : type {0}, famille {1}, {2} cylindres, {3}, {4}.") -f "$($info.Label)", (Get-CalibFamilyName $fam), "$nCyl", "$kt", "$tt")
    if ($test -eq 'level') {
        $lr = Get-LevelRef $fam $heads $cmbDrive.Text $img $false -ForHome
        if (-not $lr.Ok) { $res.Why = ((T "calibration rapide impossible : {0}") -f "$($lr.Why)"); return $res }
        Start-LevelCalib $lr -Geom $geom
    } else {
        Start-PrecompCalib -Geom $geom -Heads $heads -Test $(if ($test -eq 'fine') { 'fine' } else { 'std' }) -NoWarmup:(-not $warm)
    }
    if (-not $script:Cal) { return $res }
    $script:HomeCalBusy = $true
    Update-HomeCalibCard
    $res.Started = $true
    return $res
}

function Update-HomeCalibCard {
    # Carte « Calibrer le lecteur » : progression d une calibration lancee depuis l Accueil (texte de la barre de l onglet
    # Ecriture), puis son bilan jusqu a la prochaine ouverture de la carte. Minuterie principale et Start-HomeCalib.
    # Progression trop longue pour le libelle de la carte (306 x 44, deux lignes) : details de la fin entre parentheses
    # retires (format court : avancement et temps restant en tete), plutot qu une troisieme ligne coupee
    $d = $cardCalib.Controls[3]
    if ($script:Cal -and $script:Cal.Home) {
        $t = $lblWCal.Text
        $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
        if ([System.Windows.Forms.TextRenderer]::MeasureText($t, $d.Font, (New-Object System.Drawing.Size($d.Width, 10000)), $tf).Height -gt $d.Height) { $t = $t -replace '\s*\([^()]*\)\s*$', '' }
        if ($d.Text -ne $t) { $d.Text = $t }
        $d.ForeColor = $script:Theme.Accent; return
    }
    $script:HomeCalBusy = $false
    $d.Text = $lblWCal.Text; $d.ForeColor = $script:Theme.Muted
}

function Update-HomeCalibDialog {
    # Fenetre de la carte : detail du type choisi, etat des courbes, durees, disponibilite du test rapide, prechauffage,
    # remplacement d une courbe d un autre lecteur ou d une autre geometrie (une courbe par famille, pour tous les lecteurs)
    $s = $script:HcDlg
    if (-not $s -or $s.Busy) { return }
    $s.Busy = $true
    try {
        $info = if ($s.Lv.SelectedItems.Count -gt 0) { $s.Lv.SelectedItems[0].Tag } else { $null }
        if ($info -and $s.Last -ne $info.Name) { $s.Last = $info.Name; if ($info.Cal) { Set-Num $s.Cyl $info.NCyl } }
        $ok = [bool]($info -and $info.Cal)
        foreach ($c in @($s.Cyl, $s.Heads, $s.Std, $s.Fine, $s.Go)) { $c.Enabled = $ok }
        # « Calibrer » bleu seulement quand il est actif, sinon style normal grise (comme Set-CleanGo) ; style refait
        # seulement quand il change
        $gs = if ($ok) { 'primary' } else { 'normal' }
        if ($s.GoStyle -ne $gs) { $s.GoStyle = $gs; Set-Btn $s.Go 'Play' $gs }
        $s.Warn.Text = ''; $s.QuickTxt.Text = ''
        $wm = [double]$script:CalWarmupMinutes
        if (-not $info) { $s.Info.Text = (T 'Choisissez un type de disquette dans la liste.'); $s.Quick.Enabled = $false; $s.Curve.Enabled = $false; $s.Warm.Enabled = $false; return }
        if (-not $ok) {
            $s.Info.Text = ((T "{0}`r`n`r`nNon calibrable : {1}.") -f "$($info.Label)", "$($info.Why)")
            $s.Quick.Enabled = $false; $s.Curve.Enabled = $false; $s.Warm.Enabled = $false
            return
        }
        $fam = [string]$info.Cal; $heads = [bool]$s.Heads.Checked; $n = [int]$s.Cyl.Value
        $txt = (T "{0}`r`nFamille de calibration : {1} ({2} cellules par piste, {3} ns par cellule).") -f "$($info.Label)", (Get-CalibFamilyName $fam), "$($info.Bits)", (Format-UiNum ([math]::Round(200000000.0 / [double]$info.Bits, 1)))
        foreach ($nt in @($info.Notes)) { $txt += "`r`n" + $nt }
        $txt += "`r`n`r`n" + (Get-HomeCurveState $fam)
        $s.Info.Text = $txt
        $s.Curve.Enabled = ((Get-FamilyCurves $fam $heads).Count -gt 0)
        # Durees : memes estimations que Start-PrecompCalib (passes prevues, 1,4 s par piste et par phase, sans le
        # prechauffage, annonce par sa case) et Start-LevelCalib (2 passes)
        $np = $script:CalCoarse.Count + $script:CalMaxVerify
        $nStd = @(0..($n - 1) | Where-Object { $_ % 10 -eq 0 }).Count + $(if (($n - 1) % 10 -ne 0) { 1 } else { 0 })
        $s.Std.Text = ((T "Complète, test standard (1 cylindre sur 10) : environ {0} min") -f "$([math]::Max(1, [math]::Round($nStd * 2 * 1.4 * $np / 60, 0)))")
        $s.Fine.Text = ((T "Complète, test fin (tous les cylindres) : environ {0} min ; référence du test rapide") -f "$([math]::Max(1, [math]::Round($n * 2 * 1.4 * $np / 60, 0)))")
        $lr = Get-LevelRef $fam $heads $cmbDrive.Text '' $false -NCyl $n -Bits ([int]$info.Bits) -ForHome
        if ($lr.Ok) {
            $lc = @{}
            foreach ($u in @($lr.Units)) { foreach ($c in @(@($u.LCyls) + @($u.Wit) + @($(if ($null -ne $u.Probe) { $u.Probe })))) { $lc[[int]$c] = $true } }
            $s.Quick.Enabled = $true
            $s.Quick.Text = ((T "Rapide (niveau de la disquette insérée) : environ {0} min") -f "$([math]::Max(1, [math]::Round($lc.Count * 2 * 1.4 * 2 / 60, 0)))")
            $s.QuickTxt.Text = ((T "Forme reprise de la calibration complète du {0}. Insérez la disquette que vous allez écrire : le profil obtenu ne vaut que pour elle.") -f "$($lr.Units[0].Cv.Date)")
        } else {
            if ($s.Quick.Checked) { $s.Fine.Checked = $true }
            $s.Quick.Enabled = $false
            $s.Quick.Text = (T 'Rapide (niveau de la disquette insérée)')
            $s.QuickTxt.Text = ((T "Indisponible : {0}.") -f "$($lr.Why)")
        }
        # Prechauffage : calibration complete seulement (la calibration rapide mesure le lecteur dans son etat du moment)
        $s.Warm.Enabled = ($wm -gt 0 -and -not $s.Quick.Checked)
        if (-not $s.Quick.Checked) {
            # Courbe remplacee : tete 0 par tete, sinon la courbe commune (cle calculee directement : affecter le resultat
            # d un if deroulerait un tableau d un seul element en chaine, et $keys[0] serait son premier caractere)
            $cv = $script:PrecompCurves[$(if ($heads) { "${fam}_h0" } else { $fam })]
            $w = @()
            if ($cv -and [string]$cv.Drive -ne $cmbDrive.Text) { $w += ((T "La courbe actuelle vient du lecteur {0} : elle sera remplacée, et la nouvelle s'appliquera à tous les lecteurs (une courbe par famille).") -f "$($cv.Drive)") }
            if ($cv -and [math]::Abs(@($cv.Values).Count - $n) -gt 4) { $w += ((T "La courbe actuelle couvre {0} cylindres : elle sera remplacée par une courbe de {1} cylindres, appliquée à toutes les images de la famille {2}.") -f "$(@($cv.Values).Count)", "$n", (Get-CalibFamilyName $fam)) }
            $s.Warn.Text = ($w -join "`r`n")
        }
    } finally { $s.Busy = $false }
}

function Show-HomeCalib {
    # Fenetre de la carte « Calibrer le lecteur ». Refusee pendant une operation. « Calibrer » ferme la fenetre, puis
    # Start-HomeCalib affiche l avertissement habituel de la calibration (Show-CalibConfirm) : pas de fenetres modales
    # imbriquees. Le type choisi est enregistre (ui.homeCalFormat) a la fermeture, lance ou non.
    if (Test-HomeCalibBusy) {
        [void][System.Windows.Forms.MessageBox]::Show((T "Opération en cours : ouvrez la calibration une fois l'opération terminée."), (T 'Calibration precomp'), 'OK', 'Information'); return
    }
    if ($script:HomeCalDesc) { $cardCalib.Controls[3].Text = $script:HomeCalDesc; $cardCalib.Controls[3].ForeColor = $script:Theme.Muted }
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmHomeCalib'; $dlg.Text = (T 'Calibrer le lecteur')
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    # Hauteur : zone d avertissement de 106 px (deux avertissements de remplacement de courbe, en francais et en anglais)
    $dlg.ClientSize = New-Object System.Drawing.Size(960, 676)
    $htip = New-Object System.Windows.Forms.ToolTip
    $htip.AutoPopDelay = 30000; $htip.InitialDelay = 400; $htip.ReshowDelay = 100
    $intro = New-Object System.Windows.Forms.Label
    $intro.AutoSize = $false; $intro.UseMnemonic = $false; $intro.Location = '16,12'; $intro.Size = '928,40'
    $intro.Text = ((T "Choisissez le type de disquette. La calibration mesure la précompensation du lecteur {0} sur une disquette sacrifiée, à la densité de ce type ; la courbe obtenue s'applique ensuite à toutes les images de sa famille. Aucune image n'est nécessaire.") -f "$($cmbDrive.Text)")
    $lv = New-Object System.Windows.Forms.ListView
    $lv.Name = 'lvHcFmt'; $lv.Location = '16,58'; $lv.Size = '540,556'; $lv.View = 'Details'; $lv.FullRowSelect = $true
    $lv.HideSelection = $false; $lv.MultiSelect = $false; $lv.HeaderStyle = 'Nonclickable'; $lv.ShowItemToolTips = $true
    [void]$lv.Columns.Add((T 'Type'), 300); [void]$lv.Columns.Add((T 'Géométrie'), 80); [void]$lv.Columns.Add((T 'Calibration (famille)'), 136)
    $gn = [ordered]@{ amiga_dd = (T 'Amiga double densité'); amiga_hd = (T 'Amiga haute densité'); pc_dd = (T 'PC et Atari ST double densité')
                      hd = (T 'Haute densité : PC et autres'); long = (T 'Images longues pistes et protégées'); gcr = (T 'GCR : Commodore 64, Apple II, Macintosh')
                      fm = (T 'FM (simple densité)'); other_dd = (T 'Autres formats MFM double densité'); other = (T 'Autres formats') }
    $groups = @{}
    foreach ($k in @($gn.Keys)) { $g = New-Object System.Windows.Forms.ListViewGroup([string]$k, [string]$gn[$k]); [void]$lv.Groups.Add($g); $groups[$k] = $g }
    $sel = $null
    foreach ($info in @(Get-HomeCalibList)) {
        $it = New-Object System.Windows.Forms.ListViewItem([string]$info.Label)
        [void]$it.SubItems.Add($(if ($info.NCyl -gt 0) { "$($info.NCyl) × $($info.Heads)" } else { '-' }))
        [void]$it.SubItems.Add($(if ($info.Cal) { Get-CalibFamilyName $info.Cal } else { (T 'non calibrable') }))
        $it.ToolTipText = $(if ($info.Cal) { ((T "Famille {0}") -f (Get-CalibFamilyName $info.Cal)) } else { [string]$info.Why })
        if (-not $info.Cal) { $it.ForeColor = $script:Theme.Muted }
        $it.Tag = $info; $it.Group = $groups[[string]$info.Group]
        [void]$lv.Items.Add($it)
        if ($info.Name -eq $script:HomeCalFmt) { $sel = $it }
    }
    $tbInfo = New-Object System.Windows.Forms.TextBox
    $tbInfo.Name = 'tbHcInfo'; $tbInfo.Multiline = $true; $tbInfo.ReadOnly = $true; $tbInfo.ScrollBars = 'Vertical'; $tbInfo.TabStop = $false
    $tbInfo.Location = '572,58'; $tbInfo.Size = '372,196'; $tbInfo.BackColor = $script:Theme.Page
    $lblCyl = New-Object System.Windows.Forms.Label; $lblCyl.Text = (T 'Cylindres :'); $lblCyl.AutoSize = $true; $lblCyl.Location = '572,267'
    $numCyl = New-Object System.Windows.Forms.NumericUpDown
    $numCyl.Name = 'numHcCyl'; $numCyl.Minimum = 35; $numCyl.Maximum = 84; $numCyl.Value = 80; $numCyl.Width = 60; $numCyl.Location = '680,264'
    $htip.SetToolTip($numCyl, (T "Cylindres de test : ceux du format par défaut. Un lecteur 5,25 pouces 40 pistes : 40 ; un long track : jusqu'à 84 si le lecteur y accède."))
    $chkHeads = New-Object System.Windows.Forms.CheckBox
    $chkHeads.Name = 'chkHcHeads'; $chkHeads.Text = (T 'Une courbe par tête (écriture lente et restauration)'); $chkHeads.Location = '572,292'; $chkHeads.Size = '372,24'; $chkHeads.Checked = $true
    $htip.SetToolTip($chkHeads, (T "Coché : une courbe par tête, celle de l'écriture lente et de la restauration.`nDécoché : une courbe commune aux deux têtes, celle de l'écriture rapide."))
    # Prechauffage de la calibration complete (calWarmupMinutes) : case cochee si le reglage est > 0, non enregistree
    $wm = [double]$script:CalWarmupMinutes
    $wmt = if ($wm -eq [math]::Floor($wm)) { "$([int]$wm) min" } else { Format-CalDuration (60 * $wm) }
    $chkWarm = New-Object System.Windows.Forms.CheckBox
    $chkWarm.Name = 'chkHcWarm'; $chkWarm.Location = '572,318'; $chkWarm.Size = '372,36'; $chkWarm.Checked = ($wm -gt 0); $chkWarm.Enabled = ($wm -gt 0)
    $chkWarm.Text = if ($wm -gt 0) { (T "Préchauffer le lecteur avant la calibration complète ({0} au plus de lecture sans écriture)") -f "$wmt" } else { (T "Préchauffer le lecteur avant la calibration complète (désactivé : calWarmupMinutes = 0 dans la configuration)") }
    $htip.SetToolTip($chkWarm, (T "Lectures sans écriture des cylindres de test avant la première passe, pour stabiliser la température du lecteur ; réduites ou sautées si le lecteur vient de servir. Décochée : la calibration commence tout de suite. La calibration rapide n'est jamais précédée d'un préchauffage."))
    $rbStd = New-Object System.Windows.Forms.RadioButton;   $rbStd.Name = 'rbHcStd';     $rbStd.Location = '572,356';   $rbStd.Size = '372,36'
    $rbFine = New-Object System.Windows.Forms.RadioButton;  $rbFine.Name = 'rbHcFine';   $rbFine.Location = '572,394';  $rbFine.Size = '372,36'
    $rbQuick = New-Object System.Windows.Forms.RadioButton; $rbQuick.Name = 'rbHcQuick'; $rbQuick.Location = '572,432'; $rbQuick.Size = '372,36'
    $lblQuick = New-Object System.Windows.Forms.Label
    $lblQuick.Name = 'lblHcQuick'; $lblQuick.AutoSize = $false; $lblQuick.UseMnemonic = $false; $lblQuick.Location = '590,468'; $lblQuick.Size = '354,52'; $lblQuick.ForeColor = $script:Theme.Muted
    # Hauteurs mesurees (Segoe UI 9,75) : texte du test rapide 51 px (3 lignes), deux avertissements 102 px en francais
    $lblWarn = New-Object System.Windows.Forms.Label
    $lblWarn.Name = 'lblHcWarn'; $lblWarn.AutoSize = $false; $lblWarn.UseMnemonic = $false; $lblWarn.Location = '572,522'; $lblWarn.Size = '372,104'; $lblWarn.ForeColor = $script:Theme.Warn
    $btnCurve = New-Object System.Windows.Forms.Button; $btnCurve.Name = 'btnHcCurve'; $btnCurve.Text = (T 'Afficher la courbe'); $btnCurve.Size = New-Object System.Drawing.Size(190, 34); $btnCurve.Location = '16,628'
    $btnClose = New-Object System.Windows.Forms.Button; $btnClose.Name = 'btnHcClose'; $btnClose.Text = (T 'Fermer'); $btnClose.Size = New-Object System.Drawing.Size(110, 34); $btnClose.Location = '834,628'
    $btnGo = New-Object System.Windows.Forms.Button; $btnGo.Name = 'btnHcGo'; $btnGo.Text = (T 'Calibrer'); $btnGo.Size = New-Object System.Drawing.Size(160, 34); $btnGo.Location = '666,628'
    $btnClose.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-Btn $btnCurve 'Diagnostic' 'normal'; Set-Btn $btnGo 'Play' 'primary'; Set-Btn $btnClose '' 'normal'
    $dlg.CancelButton = $btnClose                     # pas d AcceptButton : Entree dans la liste ne lance rien
    $dlg.Controls.AddRange(@($intro, $lv, $tbInfo, $lblCyl, $numCyl, $chkHeads, $chkWarm, $rbStd, $rbFine, $rbQuick, $lblQuick, $lblWarn, $btnCurve, $btnGo, $btnClose))
    # Mode par defaut : celui de l onglet Ecriture (test standard, fin ou rapide) ; rapide indisponible : test fin
    switch ([int]$cmbWCalMode.SelectedIndex) { 2 { $rbQuick.Checked = $true } 1 { $rbFine.Checked = $true } default { $rbStd.Checked = $true } }
    $script:HcDlg = @{ Dlg = $dlg; Lv = $lv; Info = $tbInfo; Cyl = $numCyl; Heads = $chkHeads; Warm = $chkWarm; Std = $rbStd; Fine = $rbFine; Quick = $rbQuick
                       QuickTxt = $lblQuick; Warn = $lblWarn; Curve = $btnCurve; Go = $btnGo; GoStyle = 'primary'; Busy = $false; Last = ''; Choice = $null }
    $lv.Add_SelectedIndexChanged({ Update-HomeCalibDialog })
    $numCyl.Add_ValueChanged({ Update-HomeCalibDialog })
    $chkHeads.Add_CheckedChanged({ Update-HomeCalibDialog })
    foreach ($rb in @($rbStd, $rbFine, $rbQuick)) { $rb.Add_CheckedChanged({ if ($this.Checked) { Update-HomeCalibDialog } }) }
    $btnCurve.Add_Click({
        $s = $script:HcDlg
        if ($s.Lv.SelectedItems.Count -gt 0 -and $s.Lv.SelectedItems[0].Tag.Cal) { Show-PrecompCurve ([string]$s.Lv.SelectedItems[0].Tag.Cal) ([bool]$s.Heads.Checked) -Owner $s.Dlg }
    })
    $btnGo.Add_Click({
        $s = $script:HcDlg
        if ($s.Lv.SelectedItems.Count -eq 0 -or -not $s.Lv.SelectedItems[0].Tag.Cal) { return }
        $t = if ($s.Quick.Checked) { 'level' } elseif ($s.Fine.Checked) { 'fine' } else { 'std' }
        $s.Choice = @{ Name = [string]$s.Lv.SelectedItems[0].Tag.Name; Test = $t; Heads = [bool]$s.Heads.Checked; NCyl = [int]$s.Cyl.Value; Warm = [bool]($s.Warm.Enabled -and $s.Warm.Checked) }
        $s.Dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
    })
    $dlg.Add_Shown({ $s = $script:HcDlg; if ($s) { if ($s.Lv.SelectedItems.Count -gt 0) { $s.Lv.SelectedItems[0].EnsureVisible() }; [void]$s.Lv.Focus() } })
    if ($sel) { $sel.Selected = $true; $sel.Focused = $true }
    Update-HomeCalibDialog
    $dr = [System.Windows.Forms.DialogResult]::Cancel; $ch = $null; $last = ''
    try { $dr = $dlg.ShowDialog($form) }
    finally {
        if ($script:HcDlg) { $ch = $script:HcDlg.Choice; $last = [string]$script:HcDlg.Last }
        $script:HcDlg = $null; $htip.Dispose(); $dlg.Dispose()
    }
    if ($last) { $script:HomeCalFmt = $last }
    if ($dr -ne [System.Windows.Forms.DialogResult]::OK -or -not $ch) { [void](Save-Config); return }
    $r = Start-HomeCalib $ch.Name $ch.Test $ch.Heads $ch.NCyl $ch.Warm
    [void](Save-Config)
    if (-not $r.Started -and $r.Why) {
        Append-Log ((T "Calibration depuis l'Accueil non lancée : {0}.") -f "$($r.Why)")
        [void][System.Windows.Forms.MessageBox]::Show(((T "Calibration non lancée : {0}.") -f "$($r.Why)"), (T 'Calibration precomp'), 'OK', 'Information')
    }
}

# ============================== NETTOYAGE DES TETES : PICTOGRAMMES =============
# Vignettes 120 x 84 des etapes du nettoyage, dessinees en GDI+ comme le logo (aucun fichier image) : disquette 3,5
# pouces du logo, facade de lecteur, fleches, gouttes, horloge. Couleurs du theme.

function Draw-PictoFloppy($g, [single]$x, [single]$y, [single]$s, [bool]$cleaning, [bool]$flip = $false) {
    # Disquette 3,5 pouces du logo (repere 0..64) en ($x, $y), cote $s, volet en haut ; $flip : volet en bas (vers la
    # fente du lecteur). Nettoyage : corps bleu, tissu dans la fenetre du volet, etiquette CLEAN ; donnees : flux du logo
    $st = $g.Save()
    if ($flip) { $g.TranslateTransform([single]($x + $s), [single]($y + $s)); $g.RotateTransform([single]180) }
    else { $g.TranslateTransform($x, $y) }
    $g.ScaleTransform([single]($s / 64.0), [single]($s / 64.0))
    $body = New-Object System.Drawing.Drawing2D.GraphicsPath
    $body.AddPolygon([System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(5, 4)), (New-Object System.Drawing.PointF(53, 4)),
        (New-Object System.Drawing.PointF(60, 11)), (New-Object System.Drawing.PointF(60, 58)), (New-Object System.Drawing.PointF(57, 61)),
        (New-Object System.Drawing.PointF(8, 61)), (New-Object System.Drawing.PointF(5, 58))))
    $cBody = if ($cleaning) { [System.Drawing.Color]::FromArgb(58, 104, 160) } else { $script:Theme.Floppy }
    $bBody = New-Object System.Drawing.SolidBrush($cBody)
    $bMetal = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(205, 212, 222))
    $bLabel = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(248, 249, 252))
    $g.FillPath($bBody, $body)
    $g.FillPath($bMetal, (New-RoundRect 17 4 30 20 2))
    if ($cleaning) {
        $hb = New-Object System.Drawing.Drawing2D.HatchBrush([System.Drawing.Drawing2D.HatchStyle]::Weave, [System.Drawing.Color]::FromArgb(170, 188, 214), [System.Drawing.Color]::White)
        $g.FillRectangle($hb, [single]34, [single]7, [single]11, [single]14); $hb.Dispose()
    } else { $g.FillRectangle($bBody, [single]36, [single]8, [single]7, [single]12) }
    $g.FillPath($bLabel, (New-RoundRect 11 31 42 26 2.5))
    if ($cleaning) {
        $f = New-Object System.Drawing.Font('Segoe UI', [single]11, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
        # disquette retournee : etiquette lisible quand meme (dernier trace avant Restore)
        $rc = New-Object System.Drawing.RectangleF(11, 31, 42, 26)
        if ($flip) { $g.TranslateTransform([single]32, [single]44); $g.RotateTransform([single]180); $rc = New-Object System.Drawing.RectangleF(-21, -13, 42, 26) }
        $g.DrawString('CLEAN', $f, $bBody, $rc, $sf)
        $f.Dispose(); $sf.Dispose()
    } else {
        $pen = New-Object System.Drawing.Pen($script:Theme.Flux, [single]2.6); $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $xs = @(14, 18, 18, 22, 22, 28, 28, 31, 31, 37, 37, 41, 41, 45, 45, 50); $ys = @(48, 48, 39, 39, 48, 48, 39, 39, 48, 48, 39, 39, 48, 48, 39, 39)
        $g.DrawLines($pen, [System.Drawing.PointF[]]@(for ($i = 0; $i -lt $xs.Count; $i++) { New-Object System.Drawing.PointF($xs[$i], $ys[$i]) }))
        $pen.Dispose()
    }
    $bBody.Dispose(); $bMetal.Dispose(); $bLabel.Dispose(); $body.Dispose()
    $g.Restore($st)
}

function Draw-PictoDrive($g, [bool]$on) {
    # Facade de lecteur 3,5 pouces en bas de la vignette : fente, voyant (vert : moteur en marche), bouton d ejection
    $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(64, 70, 84)); $g.FillPath($b, (New-RoundRect 6 56 108 26 4)); $b.Dispose()
    $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(18, 22, 30)); $g.FillRectangle($b, [single]20, [single]62, [single]80, [single]5); $b.Dispose()
    $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 156, 168)); $g.FillPath($b, (New-RoundRect 80 72 16 5 2)); $b.Dispose()
    $cl = if ($on) { [System.Drawing.Color]::FromArgb(90, 220, 110) } else { [System.Drawing.Color]::FromArgb(48, 78, 58) }
    $b = New-Object System.Drawing.SolidBrush($cl); $g.FillRectangle($b, [single]24, [single]73, [single]10, [single]3); $b.Dispose()
}

function Draw-PictoArrow($g, [System.Drawing.Color]$c, [single]$x1, [single]$y1, [single]$x2, [single]$y2) {
    $pen = New-Object System.Drawing.Pen($c, [single]3)
    $pen.CustomEndCap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap(3, 3)
    $g.DrawLine($pen, $x1, $y1, $x2, $y2); $pen.Dispose()
}

function Fill-PictoDrop($g, $brush, [single]$cx, [single]$cy, [single]$r) {
    # Goutte : cercle de rayon $r centre en ($cx, $cy), pointe 2,2 $r au-dessus du centre
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc([single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r), [single]-27, [single]234)
    $p.AddLine($p.GetLastPoint(), (New-Object System.Drawing.PointF($cx, [single]($cy - 2.2 * $r))))
    $p.CloseFigure(); $g.FillPath($brush, $p); $p.Dispose()
}

function Draw-PictoClock($g, [single]$cx, [single]$cy, [single]$r) {
    $pen = New-Object System.Drawing.Pen($script:Theme.Accent, [single]2.5)
    $g.FillEllipse([System.Drawing.Brushes]::White, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r))
    $g.DrawEllipse($pen, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r))
    $g.DrawLine($pen, $cx, $cy, $cx, [single]($cy - 0.65 * $r)); $g.DrawLine($pen, $cx, $cy, [single]($cx + 0.5 * $r), $cy)
    $pen.Dispose()
}

function New-CleanPicto([string]$kind) {
    # Vignette d une etape : disk (disquette de nettoyage), drops (alcool sur le tissu), insert, run (zigzag de la tete),
    # dry (retirer, laisser secher), forbid (disquette de donnees barree : avertissement)
    $bmp = New-Object System.Drawing.Bitmap(120, 84, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    switch ($kind) {
        'disk' { Draw-PictoFloppy $g 26 2 80 $true }
        'drops' {
            Draw-PictoFloppy $g 2 18 66 $true
            # flacon incline vers la fenetre du volet, trois gouttes
            $st = $g.Save(); $g.TranslateTransform([single]96, [single]30); $g.RotateTransform([single]-100)
            $bw = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White); $pen = New-Object System.Drawing.Pen($script:Theme.Accent, [single]2)
            $bp = New-RoundRect -13 -10 26 30 4; $g.FillPath($bw, $bp); $g.DrawPath($pen, $bp)
            $g.FillRectangle($bw, [single]-5, [single]-19, [single]10, [single]9); $g.DrawRectangle($pen, [single]-5, [single]-19, [single]10, [single]9)
            $g.Restore($st)
            $f = New-Object System.Drawing.Font('Segoe UI', [single]10, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
            $bt = New-Object System.Drawing.SolidBrush($script:Theme.Accent)
            $g.DrawString('IPA', $f, $bt, (New-Object System.Drawing.RectangleF(84, 50, 30, 14)), $sf)
            $bd = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 150, 230))
            Fill-PictoDrop $g $bd 70 32 3.2; Fill-PictoDrop $g $bd 60 26 3.2; Fill-PictoDrop $g $bd 50 34 3.2
            $bw.Dispose(); $pen.Dispose(); $f.Dispose(); $sf.Dispose(); $bt.Dispose(); $bd.Dispose(); $bp.Dispose()
        }
        'insert' {
            Draw-PictoFloppy $g 38 0 44 $true $true
            Draw-PictoDrive $g $false
            Draw-PictoArrow $g $script:Theme.Accent 98 10 98 50
        }
        'run' {
            Draw-PictoDrive $g $true
            # va-et-vient de la tete sur toute la surface : zigzag termine par une fleche
            $pen = New-Object System.Drawing.Pen($script:Theme.Flux, [single]3); $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
            $pen.CustomEndCap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap(3, 3)
            $xs = @(12, 26, 40, 54, 68, 82, 96, 110); $pts = for ($i = 0; $i -lt $xs.Count; $i++) { New-Object System.Drawing.PointF($xs[$i], $(if ($i % 2) { 12 } else { 40 })) }
            $g.DrawLines($pen, [System.Drawing.PointF[]]$pts); $pen.Dispose()
        }
        'dry' {
            Draw-PictoFloppy $g 10 0 44 $true $true
            Draw-PictoDrive $g $false
            Draw-PictoArrow $g $script:Theme.Accent 62 46 62 8
            Draw-PictoClock $g 92 26 18
        }
        'forbid' {
            Draw-PictoFloppy $g 24 2 72 $false
            $pen = New-Object System.Drawing.Pen($script:Theme.Danger, [single]7)
            $g.DrawEllipse($pen, [single]22, [single]4, [single]76, [single]76); $g.DrawLine($pen, [single]35, [single]17, [single]85, [single]67)
            $pen.Dispose()
        }
    }
    $g.Dispose()
    return $bmp
}

# ============================== NETTOYAGE DES TETES ============================
# gw clean (outils 1.23, tools/clean.py) : moteur en marche, aucune lecture ni ecriture ; la tete va et vient en zigzag
# sur toute la course (pas de max(cyls/8, 2) cylindres, --linger ms a chaque position), --passes fois (defauts gw :
# --cyls=80, --passes=3, --linger=100). Une ligne « Pass N: 9 0 19 10 ... » a la fin de chaque passe (N a partir de 0) ;
# un lecteur qui ne repond pas donne « Command Failed: ... » avec le code 0, sur la ligne de la passe en cours. --linger
# reste sous le delai watchdog du firmware (10 s par defaut) : au-dela, le firmware couperait le moteur entre deux
# positions. Fenetre frmClean (carte de l Accueil, bouton NETTOYER de l onglet Outils) : avertissement, procedure
# illustree, options, case « J ai insere une disquette de nettoyage » obligatoire, puis gw clean suivi dans la fenetre
# (barre, Arreter) ; le minuteur principal lit la sortie de gw pendant ShowDialog.
$script:CleanRun = $null          # gw clean en cours : @{ Drive; Passes; Done; Lines; Stopped; Wet; Est; Start }
$script:CleanDlg = $null          # controles de la fenetre de nettoyage (gestionnaires d evenements)
$script:CleanDryMinutes = 5       # attente apres une disquette humide, a defaut de la notice du kit (marge prudente)
$script:CleanPrefs = @{ Wet = $true; Cyls = 80; Preset = 0 }   # derniers choix de la fenetre (configuration tools.clean*)

function Get-CleanSeconds([int]$passes, [int]$linger, [int]$cyls) {
    # Duree estimee de gw clean avec les delais d usine du firmware (pas 10 ms, stabilisation 15 ms, moteur 750 ms) :
    # meme parcours que clean.py, tete partant du cylindre 0. Estimation : les reglages de l onglet Delais l allongent
    $step = [math]::Max([math]::Floor($cyls / 8), 2)
    $pos = 0; $steps = 0; $stops = 0
    for ($p = 0; $p -lt $passes; $p++) {
        for ($c = 0; $c -lt $cyls; $c += $step) {
            foreach ($t in @([math]::Min($c + $step - 1, $cyls - 1), $c)) { $steps += [math]::Abs($t - $pos); $pos = $t; $stops++ }
        }
    }
    return 0.75 + 0.010 * $steps + $stops * (0.015 + $linger / 1000.0)
}

function Get-CleanPresets {
    # Standard : 3 passes de 500 ms, environ 30 s (un cycle de la notice 3M) ; Courte : reglage de gw ; Longue : 8 passes
    return @(
        @{ Name = (T 'Standard : 3 passes, 500 ms par position'); Passes = 3; Linger = 500 },
        @{ Name = (T 'Courte : 3 passes, 100 ms par position (réglage de gw)'); Passes = 3; Linger = 100 },
        @{ Name = (T 'Longue : 8 passes, 500 ms par position'); Passes = 8; Linger = 500 }
    )
}

function Test-GwIdle {
    # Aucune operation en cours (Test-HomeCalibBusy : gw, chaine d etapes, controle, calibration, restauration,
    # detection, prechauffage d ecriture), mesure continue de l onglet Qualite comprise
    return -not ((Test-HomeCalibBusy) -or $script:AlignLoop)
}

function Get-CleanStepTexts([bool]$wet, [string]$drive, [string]$dur) {
    # Textes des cinq vignettes de la procedure ; sechage : notice du kit d abord, CleanDryMinutes a defaut. Espaces
    # insecables dans la duree, apres « et devant : ; % » : aucun signe isole en debut de ligne dans les vignettes etroites
    $nb = [string][char]0x00A0
    $t = @(
        (T 'Une disquette à tissu, vendue pour cet usage. Jamais une disquette de données.'),
        $(if ($wet) { (T "Quelques gouttes d'alcool isopropylique (90 % ou plus) sur le tissu, par la fenêtre du volet : humide, pas détrempé.") } else { (T 'Disquette sèche : rien à faire à cette étape.') }),
        ((T 'Insérez-la dans le lecteur {0}, volet en avant, comme une disquette ordinaire.') -f "$drive"),
        ((T 'Cochez la case, puis « Lancer le nettoyage ». La tête va et vient pendant {0} environ ; le bruit est normal.') -f "$($dur.Replace(' ', $nb))"),
        $(if ($wet) { ((T "Retirez-la, puis laissez sécher les têtes le temps indiqué par la notice du kit (à défaut, {0} min par prudence) avant d'insérer une disquette de données.") -f "$($script:CleanDryMinutes)") } else { (T 'Retirez-la : le lecteur est prêt.') })
    )
    return @($t | ForEach-Object { (($_ -replace ' ([:;%»])', "$nb`$1") -replace '« ', "«$nb") })
}

function Start-HeadClean([string]$drive, [int]$cyls, [int]$passes, [int]$linger, [bool]$wet) {
    # gw clean sur le lecteur $drive ; $script:CleanRun suit la commande (Update-Progress : passes vues, autres lignes).
    # --cyls seulement s il differe du defaut de gw (80). $false si gw n a pas demarre
    $est = Get-CleanSeconds $passes $linger $cyls
    $kind = if ($wet) { (T 'humide') } else { (T 'sèche') }
    Append-Log ((T 'Nettoyage des têtes du lecteur {0} : {1} passe(s) en zigzag sur {2} cylindres, {3} ms à chaque position, durée estimée {4} ; disquette de nettoyage {5}.') -f "$drive", "$passes", "$cyls", "$linger", (Format-CalDuration ([math]::Round($est))), "$kind")
    $a = @('clean', "--drive=$drive")
    if ($txtDev.Text.Trim()) { $a += "--device=$($txtDev.Text.Trim())" }
    if ($cyls -ne 80) { $a += "--cyls=$cyls" }
    $a += @("--passes=$passes", "--linger=$linger")
    Start-Gw $a
    if (-not ($script:GwProc -and $script:GwProc.StartInfo.Arguments -match '(^|\s)clean\s')) { return $false }
    $script:CleanRun = @{ Drive = $drive; Passes = $passes; Done = 0; Lines = (New-Object System.Collections.Generic.List[string])
                          Stopped = $false; Wet = $wet; Est = $est; Start = Get-Date }
    return $true
}

function Stop-HeadClean {
    # Arreter (fenetre de nettoyage) ou fermeture de la fenetre pendant le nettoyage. gw tue ne coupe pas le moteur :
    # le firmware le coupe a la fin du delai watchdog (10 s par defaut, onglet Delais). gw deja termine : bilan normal
    $r = $script:CleanRun
    if (-not $r -or $r.Stopped) { return }
    if (-not ($script:GwProc -and -not $script:GwProc.HasExited)) { return }
    $r.Stopped = $true
    try { $script:GwProc.Kill($true) } catch { try { $script:GwProc.Kill() } catch { } }
    Append-Log (T '*** Interrompu par l''utilisateur ***')
}

function Complete-HeadClean {
    # Fin de gw clean : bilan dans le journal et texte de fin de la fenetre. Renvoie @{ Ok ; Text ; Color }
    $r = $script:CleanRun; $script:CleanRun = $null
    if (-not $r) { return @{ Ok = $false; Text = ''; Color = $null } }
    $code = [int]$script:GwLastCode
    $lines = @($r.Lines | Where-Object { $_.Trim() })
    $failed = (-not $r.Stopped) -and ($code -ne 0 -or @($lines | Where-Object { $_ -match 'Command Failed|FATAL' }).Count -gt 0 -or $r.Done -lt $r.Passes)
    $ok = (-not $r.Stopped) -and (-not $failed)
    $dryAt = (Get-Date).AddMinutes($script:CleanDryMinutes).ToString('HH:mm')
    $parts = @()
    if ($ok) { $parts += (T 'Nettoyage terminé : retirez la disquette de nettoyage.') }
    elseif ($r.Stopped) { $parts += (T "Nettoyage interrompu. Le moteur du lecteur peut tourner encore jusqu'à la fin du délai de sécurité du Greaseweazle (watchdog, 10 s par défaut) : attendez qu'il s'arrête, puis retirez la disquette de nettoyage.") }
    else {
        # Raison : deux dernieres lignes utiles, sans le debut de la ligne de passe ni les prefixes d erreur de gw ; code 0
        # sans erreur signalee mais passes manquantes : nombre de passes vues, puis la derniere ligne de gw
        $useful = @($lines | ForEach-Object { ((($_ -replace '^Pass \d+:[\d ]*', '') -replace 'FATAL ERROR:?|Command Failed:?', '') -replace '\*', '').Trim() } | Where-Object { $_ })
        if ($code -eq 0 -and @($lines | Where-Object { $_ -match 'Command Failed|FATAL' }).Count -eq 0) {
            $why = ((T "gw s'est arrêté après {0} passe(s) sur {1}") -f "$($r.Done)", "$($r.Passes)")
            if ($useful.Count -gt 0) { $why += ' / ' + $useful[-1] }
        } else {
            $why = (@($useful) | Select-Object -Last 2) -join ' / '
            if (-not $why) { $why = ((T "gw a retourné le code {0}, voir le journal") -f "$code") }
        }
        Append-Log ((T 'ÉCHEC du nettoyage des têtes : {0}') -f "$why")
        $parts += (T "Le nettoyage n'a pas abouti : retirez la disquette de nettoyage, vérifiez le lecteur choisi et son câblage (carte « Tester le Greaseweazle » de l'Accueil), puis relancez.")
    }
    if ($r.Wet -and ($ok -or $r.Done -gt 0 -or $r.Stopped)) { $parts += ((T "Disquette humide : laissez sécher les têtes le temps indiqué par la notice du kit avant d'insérer une disquette de données ; à défaut, attendez par prudence jusqu'à {0}.") -f "$dryAt") }
    elseif ($ok) { $parts += (T 'Le lecteur est prêt.') }
    if ($ok) { $parts += (T "Comptez cette utilisation sur l'étiquette de la disquette de nettoyage : elle s'use.") }
    $text = $parts -join ' '
    Append-Log $text
    $color = if ($ok) { $script:Theme.Ok } elseif ($r.Stopped) { $script:Theme.Warn } else { $script:Theme.Danger }
    return @{ Ok = $ok; Text = $text; Color = $color; Outcome = $(if ($ok) { 'ok' } elseif ($r.Stopped) { 'stop' } else { 'fail' }) }
}

function Get-CleanDlgOptions {
    # Options choisies dans la fenetre de nettoyage, avec la duree estimee
    $s = $script:CleanDlg
    $pr = $s.Presets[[math]::Max(0, $s.Dur.SelectedIndex)]
    $cyls = if ($s.Cyls.SelectedIndex -eq 1) { 40 } else { 80 }
    return @{ Drive = [string]$s.Drive.SelectedItem; Cyls = $cyls; Passes = [int]$pr.Passes; Linger = [int]$pr.Linger; Wet = [bool]$s.Wet.Checked
              Est = (Get-CleanSeconds ([int]$pr.Passes) ([int]$pr.Linger) $cyls) }
}

function Set-CleanTiles([int]$cur, [string]$endTag = '') {
    # Vignettes : avant $cur faites (vert), $cur en cours (bleu), apres a faire ; etape 2 grisee avec une disquette seche.
    # endTag 'stop' ou 'fail' (fin du nettoyage interrompu ou en echec) : la vignette juste avant $cur (4, « Lancer le
    # nettoyage ») est marquee interrompue (orange) ou en echec (rouge), et non faite
    $s = $script:CleanDlg
    for ($i = 0; $i -lt $s.Tiles.Count; $i++) {
        $t = $s.Tiles[$i]
        $tag = if ($cur -lt 0 -or $i -gt $cur) { 'todo' } elseif ($i -lt $cur) { 'done' } else { 'cur' }
        if ($i -eq $cur - 1 -and @('stop', 'fail') -contains $endTag) { $tag = $endTag }
        if ($i -eq 1 -and -not $s.Wet.Checked) { $tag = 'skip' }
        $t.Panel.Tag = $tag
        $t.Panel.BackColor = switch ($tag) {
            'done' { [System.Drawing.Color]::FromArgb(236, 247, 240) }
            'cur'  { [System.Drawing.Color]::FromArgb(234, 241, 251) }
            'skip' { [System.Drawing.Color]::FromArgb(244, 245, 247) }
            'stop' { [System.Drawing.Color]::FromArgb(253, 243, 228) }
            'fail' { [System.Drawing.Color]::FromArgb(253, 236, 234) }
            default { [System.Drawing.Color]::White }
        }
        $t.Title.ForeColor = if ($tag -eq 'skip') { $script:Theme.Muted } else { $script:Theme.Accent2 }
        $t.Panel.Invalidate()
    }
}

function Update-CleanDlg {
    # Textes des etapes et duree estimee d apres les options ; vignettes selon la case de confirmation
    $s = $script:CleanDlg
    if (-not $s -or $s.Phase -eq 'run') { return }
    $o = Get-CleanDlgOptions
    $dur = Format-CalDuration ([math]::Round($o.Est))
    $txt = Get-CleanStepTexts $o.Wet $o.Drive $dur
    for ($i = 0; $i -lt 5; $i++) { $s.Tiles[$i].Desc.Text = $txt[$i] }
    $s.Est.Text = ((T 'durée estimée : {0}') -f "$dur")
    # Case de confirmation : elle nomme le lecteur choisi (decochee a chaque changement de lecteur ou de type)
    $s.Chk.Text = ((T "J'ai inséré une disquette de nettoyage dans le lecteur {0}") -f "$($o.Drive)")
    if ($s.Phase -eq 'ready') { Set-CleanTiles $(if ($s.Chk.Checked) { 3 } else { -1 }) }
}

function Set-CleanGo([bool]$on) {
    # Bouton « Lancer le nettoyage » : bleu seulement quand il est actif (case cochee), sinon style normal grise ; style
    # (et icone) refait seulement quand il change
    $s = $script:CleanDlg; $b = $s.Go
    $b.Enabled = $on
    $st = if ($on) { 'primary' } else { 'normal' }
    if ($s.GoStyle -ne $st) { $s.GoStyle = $st; Set-Btn $b 'Repair' $st }
}

function Set-CleanDlgPhase([string]$phase, [string]$text = '', $color = $null, [string]$outcome = '') {
    # Etat de la fenetre : ready (options modifiables), run (gw clean en cours), end (termine, arrete ou en echec ;
    # outcome 'ok', 'stop' ou 'fail' de Complete-HeadClean : vignette 4 faite, interrompue ou en echec)
    $s = $script:CleanDlg
    if (-not $s) { return }
    if ($phase -eq 'end' -and $s.Chk.Checked) { $s.Busy = $true; $s.Chk.Checked = $false; $s.Busy = $false }   # nouvelle confirmation pour relancer
    $s.Phase = $phase
    $run = ($phase -eq 'run')
    foreach ($c in @($s.Drive, $s.Cyls, $s.Wet, $s.Dry, $s.Dur, $s.Chk)) { $c.Enabled = -not $run }
    $s.Go.Visible = -not $run; $s.Stop.Visible = $run; $s.Bar.Visible = $run
    Set-CleanGo ((-not $run) -and $s.Chk.Checked)
    if ($run) { $s.Bar.Value = 0 }
    $s.State.ForeColor = if ($color) { $color } else { $script:Theme.Accent2 }
    $s.State.Text = $text
    if ($phase -eq 'end') { Set-CleanTiles 4 $outcome } else { Set-CleanTiles $(if ($run -or $s.Chk.Checked) { 3 } else { -1 }) }
}

function Set-CleanDlgFit($dlg, [System.Drawing.Rectangle]$wa) {
    # Ecran trop petit pour la fenetre de nettoyage (zone de travail $wa) : hauteur ramenee a celle de l ecran avec un
    # defilement vertical, largeur augmentee de la barre de defilement (pas de defilement horizontal). $true si ajustee
    if ($dlg.Height -le $wa.Height) { return $false }
    $dlg.AutoScroll = $true
    $dlg.Size = New-Object System.Drawing.Size(($dlg.Width + [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth), $wa.Height)
    return $true
}

function New-CleanDialog([int]$Passes = 0, [int]$Linger = 0) {
    # Construit la fenetre de nettoyage (sans l afficher) et $script:CleanDlg. $Passes > 0 : reglage de l onglet Outils.
    # Hauteurs des textes (vignettes, avertissement, etat) mesurees dans la langue de l interface
    $W = 880; $tw = 168; $gap = [int](($W - 5 * $tw) / 4)    # largeur : hauteur de la fenetre sous 720 px (ecran 1366 x 768)
    $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $gdi = New-Object System.Collections.Generic.List[object]       # images et polices liberees avec la fenetre
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmClean'; $dlg.Text = (T 'Nettoyage des têtes')
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    $ctip = New-Object System.Windows.Forms.ToolTip
    $ctip.AutoPopDelay = 30000; $ctip.InitialDelay = 400; $ctip.ReshowDelay = 100

    # Avertissement, en tete et en rouge
    $pnlW = New-Object System.Windows.Forms.Panel
    $pnlW.Name = 'pnlCleanWarn'; $pnlW.Location = New-Object System.Drawing.Point(16, 16); $pnlW.BackColor = [System.Drawing.Color]::FromArgb(253, 236, 234)
    $picW = New-Object System.Windows.Forms.PictureBox
    $picW.Image = New-CleanPicto 'forbid'; $gdi.Add($picW.Image); $picW.SizeMode = 'Zoom'; $picW.Location = New-Object System.Drawing.Point(8, 10); $picW.Size = New-Object System.Drawing.Size(100, 70)
    $fWT = New-Object System.Drawing.Font('Segoe UI Semibold', 11); $gdi.Add($fWT)
    $lblWT = New-Object System.Windows.Forms.Label
    $lblWT.Name = 'lblCleanWarnTitle'; $lblWT.Text = (T 'NE LANCEZ JAMAIS LE NETTOYAGE AVEC UNE VRAIE DISQUETTE'); $lblWT.UseMnemonic = $false; $lblWT.AutoEllipsis = $true
    $lblWT.Font = $fWT; $lblWT.ForeColor = [System.Drawing.Color]::FromArgb(160, 32, 26)
    $lblWT.Location = New-Object System.Drawing.Point(118, 10); $lblWT.Size = New-Object System.Drawing.Size(($W - 128), 24)
    $wTxt = (T "Pendant le nettoyage, la tête balaie toute la surface en va-et-vient, moteur en marche, pour frotter sa saleté contre le tissu. Une vraie disquette (données, original ou disquette vierge à garder) risquerait d'être rayée par cette saleté et de perdre ses données, sans retour possible. N'insérez qu'une disquette de nettoyage, et suivez d'abord la notice de son kit.")
    $lblW = New-Object System.Windows.Forms.Label
    $lblW.Name = 'lblCleanWarn'; $lblW.Text = $wTxt; $lblW.UseMnemonic = $false; $lblW.ForeColor = [System.Drawing.Color]::FromArgb(110, 24, 20)
    $hw = [System.Windows.Forms.TextRenderer]::MeasureText($wTxt, $dlg.Font, (New-Object System.Drawing.Size(($W - 128), 10000)), $tf).Height
    $lblW.Location = New-Object System.Drawing.Point(118, 38); $lblW.Size = New-Object System.Drawing.Size(($W - 128), ($hw + 4))
    $pnlW.Size = New-Object System.Drawing.Size($W, [math]::Max(90, $lblW.Bottom + 10))
    $pnlW.Controls.AddRange(@($picW, $lblWT, $lblW))
    $pnlW.Add_Paint({ $pen = New-Object System.Drawing.Pen($script:Theme.Danger, [single]2); $_.Graphics.DrawRectangle($pen, 1, 1, $this.Width - 2, $this.Height - 2); $pen.Dispose() })

    # Procedure en cinq vignettes ; hauteur des textes : la plus grande de toutes les variantes (humide / seche)
    $titles = @((T '1. Disquette de nettoyage'), (T '2. Humidifier le tissu'), (T '3. Insérer'), (T '4. Lancer le nettoyage'), (T '5. Retirer, laisser sécher'))
    $kinds = @('disk', 'drops', 'insert', 'run', 'dry')
    $fT = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75); $gdi.Add($fT)
    $tsz = New-Object System.Drawing.Size(($tw - 8), 10000)
    $hT = 0; foreach ($s in $titles) { $hT = [math]::Max($hT, [System.Windows.Forms.TextRenderer]::MeasureText($s, $fT, $tsz, $tf).Height) }
    $hD = 0
    foreach ($v in @((Get-CleanStepTexts $true 'A' '88 min 88 s'), (Get-CleanStepTexts $false 'A' '88 min 88 s'))) {   # duree la plus large
        foreach ($s in $v) { $hD = [math]::Max($hD, [System.Windows.Forms.TextRenderer]::MeasureText($s, $dlg.Font, $tsz, $tf).Height) }
    }
    $yT = $pnlW.Bottom + 14
    $tiles = @()
    for ($i = 0; $i -lt 5; $i++) {
        $p = New-Object System.Windows.Forms.Panel
        $p.Name = "pnlCleanStep$($i + 1)"; $p.Tag = 'todo'; $p.BackColor = [System.Drawing.Color]::White
        $p.Location = New-Object System.Drawing.Point((16 + $i * ($tw + $gap)), $yT); $p.Size = New-Object System.Drawing.Size($tw, (92 + $hT + 4 + $hD + 8))
        $pic = New-Object System.Windows.Forms.PictureBox
        $pic.Image = New-CleanPicto $kinds[$i]; $gdi.Add($pic.Image); $pic.Location = New-Object System.Drawing.Point([int](($tw - 120) / 2), 4); $pic.Size = New-Object System.Drawing.Size(120, 84)
        $lt = New-Object System.Windows.Forms.Label
        $lt.Name = "lblCleanTitle$($i + 1)"; $lt.Text = $titles[$i]; $lt.UseMnemonic = $false; $lt.Font = $fT; $lt.ForeColor = $script:Theme.Accent2
        $lt.Location = New-Object System.Drawing.Point(4, 92); $lt.Size = New-Object System.Drawing.Size(($tw - 8), $hT)
        $ld = New-Object System.Windows.Forms.Label
        $ld.Name = "lblCleanStep$($i + 1)"; $ld.UseMnemonic = $false; $ld.ForeColor = [System.Drawing.Color]::FromArgb(70, 76, 88)
        $ld.Location = New-Object System.Drawing.Point(4, (96 + $hT)); $ld.Size = New-Object System.Drawing.Size(($tw - 8), $hD)
        $p.Controls.AddRange(@($pic, $lt, $ld))
        $p.Add_Paint({
            $c = switch ([string]$this.Tag) { 'cur' { $script:Theme.Accent } 'done' { $script:Theme.Ok } 'stop' { $script:Theme.Warn } 'fail' { $script:Theme.Danger } default { [System.Drawing.Color]::FromArgb(205, 212, 224) } }
            $pen = New-Object System.Drawing.Pen($c, [single]$(if (@('cur', 'stop', 'fail') -contains [string]$this.Tag) { 2 } else { 1 }))
            $_.Graphics.DrawRectangle($pen, 0, 0, $this.Width - 1, $this.Height - 1); $pen.Dispose()
        })
        $tiles += @(@{ Panel = $p; Title = $lt; Desc = $ld })
    }

    # Options
    $y = $yT + $tiles[0].Panel.Height + 14
    $l1 = New-Label (T 'Lecteur :') (New-Object System.Drawing.Point(16, ($y + 3)))
    $cmbD = New-Object System.Windows.Forms.ComboBox
    $cmbD.Name = 'cmbCleanDrive'; $cmbD.DropDownStyle = 'DropDownList'; $cmbD.Width = 56; $cmbD.Location = New-Object System.Drawing.Point(110, $y)
    [void]$cmbD.Items.AddRange(@('A', 'B', '0', '1', '2', '3'))
    $cmbD.SelectedItem = [string]$cmbDrive.Text; if ($cmbD.SelectedIndex -lt 0) { $cmbD.SelectedIndex = 0 }
    $l2 = New-Label (T 'Type :') (New-Object System.Drawing.Point(190, ($y + 3)))
    $cmbC = New-Object System.Windows.Forms.ComboBox
    $cmbC.Name = 'cmbCleanCyls'; $cmbC.DropDownStyle = 'DropDownList'; $cmbC.Location = New-Object System.Drawing.Point(250, $y); $cmbC.Width = ($W + 16 - 250)
    [void]$cmbC.Items.AddRange(@((T 'Lecteur 80 pistes : 3,5 pouces, ou 5,25 pouces haute densité'), (T 'Lecteur 40 pistes : 5,25 pouces double densité (360 Ko)')))
    $cmbC.SelectedIndex = $(if ([int]$script:CleanPrefs.Cyls -eq 40) { 1 } else { 0 })
    $ctip.SetToolTip($cmbC, (T "Course de la tête pendant le nettoyage (--cyls). Un lecteur 40 pistes ne doit pas être envoyé au-delà de sa butée."))
    $y += 34
    $l3 = New-Label (T 'Disquette :') (New-Object System.Drawing.Point(16, ($y + 3)))
    $rbWet = New-Object System.Windows.Forms.RadioButton
    $rbWet.Name = 'rbCleanWet'; $rbWet.Text = (T 'humide (alcool isopropylique)'); $rbWet.AutoSize = $true; $rbWet.Checked = [bool]$script:CleanPrefs.Wet
    $rbWet.Location = New-Object System.Drawing.Point(110, ($y + 1))
    $rbDry = New-Object System.Windows.Forms.RadioButton
    $rbDry.Name = 'rbCleanDry'; $rbDry.Text = (T 'sèche'); $rbDry.AutoSize = $true; $rbDry.Checked = -not $rbWet.Checked
    $rbDry.Location = New-Object System.Drawing.Point((110 + [System.Windows.Forms.TextRenderer]::MeasureText($rbWet.Text, $dlg.Font).Width + 40), ($y + 1))
    $y += 34
    $l4 = New-Label (T 'Durée :') (New-Object System.Drawing.Point(16, ($y + 3)))
    $presets = @(Get-CleanPresets)
    if ($Passes -gt 0) { $presets += @(@{ Name = ((T 'Réglage de l''onglet Outils : {0} passe(s), {1} ms par position') -f "$Passes", "$Linger"); Passes = $Passes; Linger = $Linger }) }
    $cmbT = New-Object System.Windows.Forms.ComboBox
    $cmbT.Name = 'cmbCleanDur'; $cmbT.DropDownStyle = 'DropDownList'; $cmbT.Location = New-Object System.Drawing.Point(110, $y); $cmbT.Width = 420
    foreach ($pr in $presets) { [void]$cmbT.Items.Add($pr.Name) }
    $cmbT.SelectedIndex = $(if ($Passes -gt 0) { $presets.Count - 1 } else { [math]::Max(0, [math]::Min(2, [int]$script:CleanPrefs.Preset)) })
    $lEst = New-Label '' (New-Object System.Drawing.Point(542, ($y + 3))); $lEst.Name = 'lblCleanEst'; $lEst.ForeColor = $script:Theme.Muted
    $y += 36
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Name = 'chkCleanOk'; $chk.Text = ((T "J'ai inséré une disquette de nettoyage dans le lecteur {0}") -f "$($cmbD.Text)"); $chk.AutoSize = $true; $chk.Font = $bold; $chk.UseMnemonic = $false
    $chk.Location = New-Object System.Drawing.Point(16, $y)
    $y += 28
    $bar = New-Object System.Windows.Forms.ProgressBar
    $bar.Name = 'pbClean'; $bar.Location = New-Object System.Drawing.Point(16, $y); $bar.Size = New-Object System.Drawing.Size($W, 16); $bar.Maximum = 1000; $bar.Visible = $false
    # Etat : hauteur du plus long texte de fin (echec ou arret suivi du sechage, succes humide), 3 lignes au moins
    $fS = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75); $gdi.Add($fS)
    $wetEnd = ((T "Disquette humide : laissez sécher les têtes le temps indiqué par la notice du kit avant d'insérer une disquette de données ; à défaut, attendez par prudence jusqu'à {0}.") -f '00:00')
    $hS = 0
    foreach ($e in @(((T 'Nettoyage terminé : retirez la disquette de nettoyage.') + ' ' + $wetEnd + ' ' + (T "Comptez cette utilisation sur l'étiquette de la disquette de nettoyage : elle s'use.")),
                     ((T "Nettoyage interrompu. Le moteur du lecteur peut tourner encore jusqu'à la fin du délai de sécurité du Greaseweazle (watchdog, 10 s par défaut) : attendez qu'il s'arrête, puis retirez la disquette de nettoyage.") + ' ' + $wetEnd),
                     ((T "Le nettoyage n'a pas abouti : retirez la disquette de nettoyage, vérifiez le lecteur choisi et son câblage (carte « Tester le Greaseweazle » de l'Accueil), puis relancez.") + ' ' + $wetEnd))) {
        $hS = [math]::Max($hS, [System.Windows.Forms.TextRenderer]::MeasureText($e, $fS, (New-Object System.Drawing.Size($W, 10000)), $tf).Height)
    }
    $hS = [math]::Max($hS, 3 * $fS.Height)
    $lblS = New-Object System.Windows.Forms.Label
    $lblS.Name = 'lblCleanState'; $lblS.UseMnemonic = $false; $lblS.Font = $fS
    $lblS.Location = New-Object System.Drawing.Point(16, ($y + 20)); $lblS.Size = New-Object System.Drawing.Size($W, ($hS + 4))
    $y = $lblS.Bottom + 8
    $btnGo = New-Object System.Windows.Forms.Button
    $btnGo.Name = 'btnCleanStart'; $btnGo.Text = (T 'Lancer le nettoyage'); $btnGo.Size = New-Object System.Drawing.Size(230, 34); $btnGo.Enabled = $false
    $btnStp = New-Object System.Windows.Forms.Button
    $btnStp.Name = 'btnCleanStop'; $btnStp.Text = (T 'Arrêter'); $btnStp.Size = New-Object System.Drawing.Size(130, 34); $btnStp.Visible = $false
    $btnCl = New-Object System.Windows.Forms.Button
    $btnCl.Name = 'btnCleanClose'; $btnCl.Text = (T 'Fermer'); $btnCl.Size = New-Object System.Drawing.Size(110, 34)
    $btnCl.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-Btn $btnGo 'Repair' 'primary'; Set-Btn $btnStp 'Stop' 'danger'; Set-Btn $btnCl '' 'normal'
    $btnCl.Location = New-Object System.Drawing.Point((16 + $W - $btnCl.Width), $y)
    $btnGo.Location = New-Object System.Drawing.Point(($btnCl.Left - 8 - $btnGo.Width), $y)
    $btnStp.Location = New-Object System.Drawing.Point(($btnCl.Left - 8 - $btnStp.Width), $y)
    $dlg.ClientSize = New-Object System.Drawing.Size(($W + 32), ($y + $btnCl.Height + 16))
    $dlg.CancelButton = $btnCl                        # pas d AcceptButton : Entree ne lance pas le nettoyage
    $dlg.Controls.AddRange(@($pnlW) + @($tiles | ForEach-Object { $_.Panel }) + @($l1, $cmbD, $l2, $cmbC, $l3, $rbWet, $rbDry, $l4, $cmbT, $lEst, $chk, $bar, $lblS, $btnGo, $btnStp, $btnCl))
    [void](Set-CleanDlgFit $dlg ([System.Windows.Forms.Screen]::FromControl($form).WorkingArea))

    $script:CleanDlg = @{ Dlg = $dlg; Tiles = $tiles; Drive = $cmbD; Cyls = $cmbC; Wet = $rbWet; Dry = $rbDry; Dur = $cmbT; Est = $lEst
                          Chk = $chk; Bar = $bar; State = $lblS; Go = $btnGo; Stop = $btnStp; Close = $btnCl; Presets = $presets
                          Phase = 'ready'; Busy = $false; Tmr = $null; Tip = $ctip; Gdi = $gdi; GoStyle = 'primary' }
    $upd = { Update-CleanDlg }
    # Lecteur ou type change apres la confirmation : case decochee (son gestionnaire desactive « Lancer le nettoyage »),
    # la disquette de nettoyage doit etre confirmee pour le nouveau lecteur. Avant Update-CleanDlg (vignettes a jour)
    $reset = { $s = $script:CleanDlg; if ($s -and $s.Phase -ne 'run' -and $s.Chk.Checked) { $s.Chk.Checked = $false } }
    $cmbD.Add_SelectedIndexChanged($reset); $cmbC.Add_SelectedIndexChanged($reset)
    $cmbD.Add_SelectedIndexChanged($upd); $cmbC.Add_SelectedIndexChanged($upd); $cmbT.Add_SelectedIndexChanged($upd); $rbWet.Add_CheckedChanged($upd)
    $chk.Add_CheckedChanged({
        $s = $script:CleanDlg
        if (-not $s -or $s.Busy -or $s.Phase -eq 'run') { return }
        $s.Phase = 'ready'; $s.State.Text = ''
        Set-CleanGo $this.Checked
        Set-CleanTiles $(if ($this.Checked) { 3 } else { -1 })
    })
    $btnGo.Add_Click({
        $s = $script:CleanDlg
        if (-not $s -or -not $s.Chk.Checked -or $script:CleanRun) { return }
        if (-not (Test-GwIdle)) { $s.State.ForeColor = $script:Theme.Warn; $s.State.Text = (T "Une commande gw est en cours : attendez qu'elle se termine, puis relancez."); return }
        $o = Get-CleanDlgOptions
        # choix memorises (enregistres par Start-Gw) ; le reglage de l onglet Outils n est pas un prereglage
        $script:CleanPrefs = @{ Wet = $o.Wet; Cyls = $o.Cyls; Preset = $(if ($s.Dur.SelectedIndex -le 2) { $s.Dur.SelectedIndex } else { $script:CleanPrefs.Preset }) }
        if (-not (Start-HeadClean $o.Drive $o.Cyls $o.Passes $o.Linger $o.Wet)) { $s.State.ForeColor = $script:Theme.Danger; $s.State.Text = (T "gw n'a pas pu être lancé : voir le journal."); return }
        Set-CleanDlgPhase 'run' ((T 'Nettoyage en cours sur le lecteur {0}...') -f "$($o.Drive)")
    })
    $btnStp.Add_Click({ Stop-HeadClean })
    # Fermer, Echap ou la croix pendant le nettoyage : arret, et la fenetre reste ouverte sur le texte de fin (retirer,
    # laisser secher). Fermer et Echap passent par DialogResult (CloseReason None), la croix par UserClosing
    $dlg.Add_FormClosing({
        if (-not $script:CleanRun) { return }
        Stop-HeadClean
        if ($_.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing -or $_.CloseReason -eq [System.Windows.Forms.CloseReason]::None) { $_.Cancel = $true }
    })
    # Suivi : barre (passes terminees ou temps ecoule sur la duree estimee, 99 % au plus tant que gw tourne), puis bilan
    # quand le minuteur principal a traite la fin de gw ($script:GwProc remis a $null)
    $tmr = New-Object System.Windows.Forms.Timer
    $tmr.Interval = 250
    $tmr.Add_Tick({
        $s = $script:CleanDlg; $r = $script:CleanRun
        if (-not $s -or -not $r -or $s.Phase -ne 'run') { return }
        if ($script:GwProc) {
            $el = ((Get-Date) - $r.Start).TotalSeconds
            $v = [math]::Max(1000.0 * $r.Done / [math]::Max(1, $r.Passes), 1000.0 * $el / [math]::Max(1.0, $r.Est))
            $s.Bar.Value = [int][math]::Min(990.0, $v)
            $s.State.Text = ((T 'Nettoyage en cours sur le lecteur {0} : passe {1} sur {2}, reste environ {3}.') -f "$($r.Drive)", "$([math]::Min($r.Passes, $r.Done + 1))", "$($r.Passes)", (Format-CalDuration ([math]::Round([math]::Max(0.0, $r.Est - $el)))))
            return
        }
        $res = Complete-HeadClean
        Set-CleanDlgPhase 'end' $res.Text $res.Color $res.Outcome
    })
    $script:CleanDlg.Tmr = $tmr
    Set-CleanGo $false
    Update-CleanDlg
    return $dlg
}

function Show-CleanDialog([int]$Passes = 0, [int]$Linger = 0) {
    # Nettoyage des tetes : carte de l Accueil ; bouton NETTOYER de l onglet Outils ($Passes / $Linger de cet onglet)
    if (-not (Test-GwIdle)) {
        [void][System.Windows.Forms.MessageBox]::Show((T "Opération en cours : lancez le nettoyage une fois l'opération terminée ou arrêtée."), (T 'Nettoyage des têtes'), 'OK', 'Information'); return
    }
    $dlg = New-CleanDialog $Passes $Linger
    $s = $script:CleanDlg
    $s.Tmr.Start()
    try { [void]$dlg.ShowDialog($form) }
    finally {
        $s.Tmr.Stop(); $s.Tmr.Dispose()
        if ($script:CleanRun) { Stop-HeadClean; [void](Complete-HeadClean) }   # fenetre fermee par le systeme pendant le nettoyage
        $script:CleanDlg = $null
        $s.Tip.Dispose(); $dlg.Dispose()
        foreach ($o in $s.Gdi) { try { $o.Dispose() } catch { } }
    }
}

# Metriques d une piste (liste de ScpRev, un par tour) : base commune de l onglet Qualite et du
# controle apres ecriture, pour que « piste faible » ait partout la meme definition.
function Get-TrackMetrics($st) {
    $m = @{ Bad = $false; Missing = $false; J = 0.0; R3 = 0.0; R4 = 0.0; Ooc = 0.0; Dr = 0.0; Cell = 0.0; Stab = 0.0; Asym = 0.0; Score = 9999; Level = 2
            Weak = $false; ShortUnstable = $false; Blocks = 0; Unstable = 0; MaxRun = 0; RunPos = -1 }
    $list = @($st)
    if ($list.Count -eq 0) { $m.Bad = $true; return $m }
    foreach ($x in $list) { if ([double]::IsNaN($x.Jitter)) { $m.Bad = $true } }
    if ($m.Bad) { return $m }
    $m.J    = ($list | Measure-Object -Property Jitter -Average).Average
    $m.R3   = ($list | Measure-Object -Property R3 -Average).Average
    $m.R4   = ($list | Measure-Object -Property R4 -Average).Average
    $m.Ooc  = ($list | Measure-Object -Property OutOfClass -Average).Average
    $m.Dr   = ($list | Measure-Object -Property Dropouts -Average).Average
    $m.Cell = ($list | Measure-Object -Property Cell -Average).Average
    $nf     = $list | ForEach-Object { $_.NFlux }
    $m.Stab = ($nf | Measure-Object -Maximum).Maximum - ($nf | Measure-Object -Minimum).Minimum
    $m.Asym = [math]::Abs($m.R3 - 1.5) + [math]::Abs($m.R4 - 2.0)
    $m.Score = [math]::Round($m.J + 2000 * $m.Asym + 5 * $m.Ooc + 50 * $m.Dr + $m.Stab, 0)
    $m.Level = Get-HealthLevel $m.Ooc $m.Dr $m.Stab $m.J
    # Stabilite d un tour a l autre (Read-ScpFile, premier tour) : blocs de 32 intervalles absents d au moins deux autres
    # tours. Weak : au moins 3 blocs consecutifs (une dizaine d octets), au plus le quart de la piste = bits faibles d une
    # protection probable, ou defaut localise ; non reproductible par une copie, qui n ecrit qu un tour. ShortUnstable :
    # 2 blocs, raccord d ecriture a cheval sur deux blocs ou courte zone de protection : pas d alerte, mais jamais reecrite
    # sur une disquette identique a l original.
    $r0 = $list[0]
    if ($r0.Blocks -gt 0) {
        $m.Blocks = $r0.Blocks; $m.Unstable = $r0.Unstable; $m.MaxRun = $r0.MaxRun; $m.RunPos = $r0.RunPos
        $m.Weak = ($r0.MaxRun -ge 3 -and $r0.Unstable * 4 -le $r0.Blocks)
        $m.ShortUnstable = ($r0.MaxRun -ge 2 -and -not $m.Weak)
    }
    return $m
}

# Ligne du tableau de l onglet Qualite pour une piste ; $mark complete l etat (ex. « (reecrite x2) »)
function New-AlignRow([string]$lab, $m, [string]$mark, [string]$delta, [int]$deltaLvl) {
    $healthNames = @{ 0=(T 'SAIN'); 1=(T 'À SURVEILLER'); 2=(T 'CRITIQUE') }
    $healthColor = @{ 0=$script:AlColors[0]; 1=$script:AlColors[2]; 2=$script:AlColors[3] }
    $it = New-Object System.Windows.Forms.ListViewItem($lab)
    $it.UseItemStyleForSubItems = $false
    if ($m.Bad) {
        $state = if ($m.Missing) { (T 'ABSENTE') } else { (T 'ILLISIBLE') }
        foreach ($v in @(($state + $mark),'-','-','-','-','-','-','-','-')) { [void]$it.SubItems.Add([string]$v) }
        $it.SubItems[1].BackColor = $script:AlColors[3]; $it.SubItems[1].ForeColor = [System.Drawing.Color]::White; $it.SubItems[1].Font = $bold
        return $it
    }
    $hl = [int]$m.Level
    $wk = if ($m.Weak) { (T ' (zone instable)') } else { '' }
    # Zone instable non jugee (controle d une copie dont la source peut porter des zones faibles) : ni SAINE ni faible
    $stTxt = if ($m.Unjudged -and $hl -eq 0) { (T 'NON JUGÉE') } else { $healthNames[$hl] }
    foreach ($v in @(($stTxt + $wk + $mark), ('{0:N1}' -f $m.Ooc), ('{0:N1}' -f $m.Dr), [string]$m.Stab, ('{0:N0}' -f $m.J), ('{0:N0}' -f $m.Score), $delta, ('{0:N3}' -f $m.Asym), ('{0:N0}' -f $m.Cell))) { [void]$it.SubItems.Add($v) }
    $it.SubItems[1].BackColor = $healthColor[$hl]; $it.SubItems[1].ForeColor = $script:AlFg[$(@{0=0;1=2;2=3}[$hl])]
    if ($m.Unjudged -and $hl -eq 0) { $it.SubItems[1].BackColor = $script:AlColors[1]; $it.SubItems[1].ForeColor = $script:AlFg[1] }
    $it.SubItems[1].Font = $bold
    $lvErr = Get-AlLevel 'err' $m.Ooc;    $it.SubItems[2].BackColor = $script:AlColors[$lvErr];  $it.SubItems[2].ForeColor = $script:AlFg[$lvErr]
    $lvDr  = $(if ($m.Dr -le 0) { 0 } elseif ($m.Dr -le 1) { 2 } else { 3 }); $it.SubItems[3].BackColor = $script:AlColors[$lvDr]; $it.SubItems[3].ForeColor = $script:AlFg[$lvDr]
    $lvStb = Get-AlLevel 'stab' $m.Stab;  $it.SubItems[4].BackColor = $script:AlColors[$lvStb];  $it.SubItems[4].ForeColor = $script:AlFg[$lvStb]
    $lvJit = Get-AlLevel 'jitter' $m.J;   $it.SubItems[5].BackColor = $script:AlColors[$lvJit];  $it.SubItems[5].ForeColor = $script:AlFg[$lvJit]
    $lvSc  = Get-AlLevel 'score' $m.Score; $it.SubItems[6].BackColor = $script:AlColors[$lvSc];  $it.SubItems[6].ForeColor = $script:AlFg[$lvSc]
    if ($deltaLvl -ge 0) { $it.SubItems[7].BackColor = $script:AlColors[$deltaLvl]; $it.SubItems[7].ForeColor = $script:AlFg[$deltaLvl] }
    $lvAs  = Get-AlLevel 'asym' $m.Asym;  $it.SubItems[8].BackColor = $script:AlColors[$lvAs];   $it.SubItems[8].ForeColor = $script:AlFg[$lvAs]
    return $it
}

function Set-UnstableBanner([string[]]$parts) {
    # Bandeau orange des zones instables (onglet Qualite) ; vide : efface un bandeau orange reste d une mesure precedente,
    # sauf pendant le guide d alignement qui utilise la meme ligne
    $parts = @($parts | Where-Object { $_ })
    if ($parts.Count -gt 0) {
        $lblAlReco.Text = ($parts -join '   |   '); $lblAlReco.ForeColor = 'DarkOrange'; $lblAlReco.Visible = $true
        $script:UnstableBannerText = $lblAlReco.Text
    } elseif ($script:UnstableBannerText -and $lblAlReco.Text -eq $script:UnstableBannerText) { $lblAlReco.Text = ''; $script:UnstableBannerText = $null }
    elseif (-not $chkAlGuide.Checked -and $lblAlReco.ForeColor -eq [System.Drawing.Color]::DarkOrange) { $lblAlReco.Text = '' }
}

function Get-UnstableClusters([string[]]$keys, [int]$minRun = 3) {
    # Suites d au moins $minRun cylindres consecutifs instables sur une meme face (« c58-c61 tete 1 ») : une rayure ou une
    # usure touche des pistes voisines, une protection a bits faibles tient en general sur une piste isolee
    $out = @()
    foreach ($h in 0, 1) {
        $cs = @($keys | Where-Object { $_ -match "^\d+\.$h$" } | ForEach-Object { [int](($_ -split '\.')[0]) } | Sort-Object -Unique)
        $i = 0
        while ($i -lt $cs.Count) {
            $j = $i
            while ($j + 1 -lt $cs.Count -and $cs[$j + 1] -eq $cs[$j] + 1) { $j++ }
            if ($j - $i + 1 -ge $minRun) { $out += ((T "c{0}-c{1} tête {2}") -f "$($cs[$i])", "$($cs[$j])", "$h") }
            $i = $j + 1
        }
    }
    return $out
}

function Invoke-AlignAnalysis {
    if (-not $script:AlignTmp -or -not (Test-Path -LiteralPath $script:AlignTmp)) {
        Append-Log (T 'Mesure : fichier SCP absent, analyse impossible.'); $script:AlignLoop = $false; return
    }
    try { $tracks = Read-ScpFile $script:AlignTmp } catch { Append-Log ((T "Mesure : {0}") -f "$($_.Exception.Message)"); $script:AlignLoop = $false; return }

    $last = @{}; $watch = @(); $crit = @(); $weakL = @()
    $lvAl.Columns[1].Width = 200
    $lvAl.BeginUpdate()
    try {
        $lvAl.Items.Clear()
        $total = 0.0; $count = 0
        foreach ($tn in ($tracks.Keys | Sort-Object)) {
            $st = $tracks[$tn]; $cyl = [math]::Floor($tn / 2); $hd = $tn % 2; $key = "$cyl.$hd"
            $lab = "$cyl.$hd"
            $m = Get-TrackMetrics $st
            if ($m.Bad) {
                [void]$lvAl.Items.Add((New-AlignRow $lab $m '' '-' -1))
                $last[$key] = @{ Score = 9999; Jitter = 0; Asym = 0; Err = 0; Stab = 0; Cell = 0 }
                $crit += ((T "{0} (illisible)") -f "$lab"); continue
            }
            # Zone instable : la piste ne se relit pas pareil d un tour a l autre, elle n est pas propre (protection ou
            # defaut du support, l application ne peut pas trancher sur une disquette inconnue) : au moins A SURVEILLER
            if ($m.Weak -and $m.Level -lt 1) { $m.Level = 1 }
            $sc = $m.Score
            if (-not $script:AlignBest.ContainsKey($key) -or $sc -lt $script:AlignBest[$key]) { $script:AlignBest[$key] = $sc }
            $last[$key] = @{ Score = $sc; Jitter = $m.J; Asym = $m.Asym; Err = $m.Ooc; Stab = $m.Stab; Cell = $m.Cell }
            $hl = $m.Level
            if ($m.Weak) { $weakL += $lab }
            if ($hl -eq 1) { $watch += $lab } elseif ($hl -eq 2) { $crit += ((T "{0} ({1} err/tour)") -f "$lab", "$([math]::Round($m.Ooc,0))") }

            $delta = '-'; $deltaLvl = -1
            if ($script:AlignRef -and $script:AlignRef.ContainsKey($key) -and $script:AlignRef[$key].Score -gt 0) {
                $pct = ($sc - $script:AlignRef[$key].Score) / $script:AlignRef[$key].Score * 100
                $delta = ('{0:+0;-0;0} %' -f $pct); $deltaLvl = Get-AlLevel 'delta' $pct
            }
            [void]$lvAl.Items.Add((New-AlignRow $lab $m '' $delta $deltaLvl))
            $total += $sc; $count++
        }
        $script:AlignLast = $last
        $nTracks = $tracks.Count

        # --- Verdict 1 : etat du support
        if ($crit.Count -gt 0) {
            $lblAlHealth.Text = ((T "SUPPORT CRITIQUE  -  {0} piste(s) en erreur : {1}   ->  dump flux immédiat conseillé") -f "$($crit.Count)", "$($crit -join ', ')")
            $lblAlHealth.BackColor = $script:AlColors[3]; $lblAlHealth.ForeColor = $script:AlFg[3]
        } elseif ($watch.Count -gt 0) {
            $lblAlHealth.Text = ((T "SUPPORT À SURVEILLER  -  {0}/{1} piste(s) marginale(s) : {2}   ->  dump flux recommandé") -f "$($watch.Count)", "$nTracks", "$($watch -join ', ')")
            $lblAlHealth.BackColor = $script:AlColors[2]; $lblAlHealth.ForeColor = $script:AlFg[2]
        } else {
            $lblAlHealth.Text = ((T "SUPPORT SAIN  -  {0}/{1} pistes propres (erreurs, trous, stabilité, jitter dans les normes)") -f "$nTracks", "$nTracks")
            $lblAlHealth.BackColor = $script:AlColors[0]; $lblAlHealth.ForeColor = $script:AlFg[0]
        }
        Append-Log ((T "Mesure : {0}") -f "$($lblAlHealth.Text)")
        if ($weakL.Count -gt 0) { Append-Log ((T "Mesure : zone instable d'un tour à l'autre sur {0} piste(s) : {1}. Bits faibles d'une protection contre la copie probable, ou défaut localisé du support : une copie faite depuis un flux n'en écrit qu'un tour et ne les reproduit pas fidèlement.") -f "$($weakL.Count)", "$($weakL -join ', ')") }
        $clu = @(Get-UnstableClusters $weakL)
        if ($clu.Count -gt 0) { Append-Log ((T "Mesure : pistes instables sur des cylindres voisins d'une même face ({0}) : défaut du support probable (rayure, usure) plutôt qu'une protection.") -f "$($clu -join ', ')") }

        # --- Verdict 2 : score de lecture
        if ($count -gt 0) {
            $avg = [math]::Round($total / $count, 0)
            if (-not $script:AlignBest.ContainsKey('_global') -or $avg -lt $script:AlignBest['_global']) { $script:AlignBest['_global'] = $avg }
            $trend = ''
            if ($null -ne $script:AlignPrev) {
                if ($avg -lt $script:AlignPrev - 2) { $trend = (T '   MIEUX (v)') } elseif ($avg -gt $script:AlignPrev + 2) { $trend = (T '   MOINS BIEN (^)') } else { $trend = (T '   stable') }
            }
            $script:AlignPrev = $avg
            $lvlAvg = Get-AlLevel 'score' $avg
            $refTxt = ''
            if ($script:AlignRef) {
                $refScores = @($script:AlignRef.Values | ForEach-Object { $_.Score } | Where-Object { $_ -lt 9999 })
                if ($refScores.Count -gt 0) { $refAvg = [math]::Round(($refScores | Measure-Object -Average).Average, 0); $refTxt = ((T "   |   référence {0}") -f "$refAvg") }
            }
            $lblAlVerdict.Text = ((T "Qualité de lecture : score {0} - {1}{2}{3}   |   meilleur {4}") -f "$avg", "$($script:AlNames[$lvlAvg])", "$trend", "$refTxt", "$($script:AlignBest['_global'])")
            $lblAlVerdict.BackColor = $script:AlColors[$lvlAvg]; $lblAlVerdict.ForeColor = $script:AlFg[$lvlAvg]
            Append-Log ((T "Mesure : score moyen {0} ({1}){2}") -f "$avg", "$($script:AlNames[$lvlAvg])", "$trend")
            Update-AlignGuide $avg
            $bn = if ($weakL.Count -gt 0) { ((T "Zone instable d'un tour à l'autre (protection contre la copie ou défaut du support) : {0}") -f "$($weakL -join ', ')") + $(if ($clu.Count -gt 0) { (T " ; cylindres voisins {0} : défaut du support probable") -f "$($clu -join ', ')" } else { '' }) } else { '' }
            Set-UnstableBanner @($bn)
        } else {
            $lblAlVerdict.Text = (T 'Aucune piste analysable'); $lblAlVerdict.BackColor = $script:AlColors[3]; $lblAlVerdict.ForeColor = $script:AlFg[3]
        }
    } finally { $lvAl.EndUpdate() }
    Render-AlignBars

    if ($script:AlignLoop) { $script:AlignNextAt = (Get-Date).AddSeconds([int]$numAlPause.Value) }
}

# ============================== PROFIL PRECOMP : DETECTION =====================
function Get-BE32([byte[]]$b, [int]$o) {
    return ([int64]$b[$o] * 16777216) + ([int64]$b[$o+1] * 65536) + ([int64]$b[$o+2] * 256) + [int64]$b[$o+3]
}

# IPF : mediane des bits par piste (enregistrements IMGE) -> cellule nominale a 300 tr/min
function Get-IpfCellInfo([string]$path) {
    $d = [System.IO.File]::ReadAllBytes($path)
    if ([System.Text.Encoding]::ASCII.GetString($d, 0, 4) -ne 'CAPS') { throw (T 'Signature IPF absente') }
    $bits = New-Object System.Collections.Generic.List[int64]; $dos = 0; $n = 0
    $pos = 0
    while ($pos + 12 -le $d.Length) {
        $id = [System.Text.Encoding]::ASCII.GetString($d, $pos, 4)
        $ln = Get-BE32 $d ($pos + 4)
        if ($ln -lt 12) { break }
        if ($id -eq 'IMGE' -and $pos + 12 + 44 -le $d.Length) {
            $trkbits = Get-BE32 $d ($pos + 12 + 36)
            $blkcnt  = Get-BE32 $d ($pos + 12 + 40)
            if ($blkcnt -gt 0 -and $trkbits -gt 0) { $bits.Add($trkbits); $n++; if ($blkcnt -eq 11) { $dos++ } }
        } elseif ($id -eq 'DATA' -and $pos + 16 -le $d.Length) {
            $ln += Get-BE32 $d ($pos + 12)
        }
        $pos += $ln
    }
    if ($bits.Count -eq 0) { throw (T 'Aucune piste formatée dans l''IPF') }
    $sorted = $bits | Sort-Object
    $med = [int64]$sorted[[int]($sorted.Count / 2)]
    return @{ CellNs = [double](200000000.0 / $med); Bits = $med; Tracks = $n; DosTracks = $dos; Source = (T 'IPF (bits par piste)') }
}

# SCP : cellule mesuree sur les premieres pistes presentes (revolution 0)
function Get-ScpCellInfo([string]$path) {
    $d = [System.IO.File]::ReadAllBytes($path)
    if ([System.Text.Encoding]::ASCII.GetString($d, 0, 3) -ne 'SCP') { throw (T 'Signature SCP absente') }
    $res = ($d[11] + 1) * 25; $cells = @(); $t = 0
    while ($t -lt 168 -and $cells.Count -lt 4) {
        $o = [BitConverter]::ToUInt32($d, 16 + 4 * $t); $t++
        if ($o -eq 0) { continue }
        $ln = [BitConverter]::ToUInt32($d, $o + 8); $doff = [BitConverter]::ToUInt32($d, $o + 12)
        $flux = [ScpStats]::Decode($d, [int]($o + $doff), [int]$ln, $res)
        $st = [ScpStats]::Analyze($flux, 0)
        if (-not [double]::IsNaN($st.Cell)) { $cells += $st.Cell }
    }
    if ($cells.Count -eq 0) { throw (T 'Aucune piste analysable dans le SCP') }
    $avg = ($cells | Measure-Object -Average).Average
    return @{ CellNs = $avg; Bits = [int64](200000000.0 / $avg); Tracks = $cells.Count; DosTracks = -1; Source = (T 'SCP (flux mesuré)') }
}

# HFE : debit binaire declare dans l en-tete (kbit/s) -> cellule = 500 000 / debit
function Get-HfeCellInfo([string]$path) {
    # Densite d un HFE telle que gw l ecrit (hfe.py) : par face, 8 x (longueur // 2) bits, la longueur (octets, deux
    # faces) etant lue dans la table des pistes (bloc ToUInt16(18), une entree de 4 octets par cylindre : bloc des
    # donnees, longueur) ; gw cale chaque piste sur un tour du lecteur, d ou une cellule de 200 ms / bits a 300 tr/min
    # (mediane des pistes). Table retenue si elle suit l en-tete, est complete et designe pour au moins la moitie des
    # cylindres des donnees presentes dans le fichier. HFE v3 (opcodes dans le flux de bits) ou table inexploitable :
    # 400 x debit de l en-tete.
    $fs = [System.IO.File]::OpenRead($path)
    try {
        $h = New-Object byte[] 32; [void]$fs.Read($h, 0, 32)
        $sig = [System.Text.Encoding]::ASCII.GetString($h, 0, 8)
        if ($sig -notmatch '^HXCPICFE|^HXCHFEV3') { throw (T 'Signature HFE absente') }
        $rate = [BitConverter]::ToUInt16($h, 12)          # en-tete HFE : bitRate (kbit/s) a l offset 12
        if ($rate -le 0) { throw (T 'Débit HFE nul') }
        if ($rate -lt 100 -or $rate -gt 1000) { throw ((T "Débit HFE invalide ({0} kbit/s)") -f "$rate") }
        $bits = [int64](400 * [int]$rate); $src = ((T "HFE (débit {0} kbit/s)") -f "$rate")
        $nCyl = [int]$h[9]; $tlBase = [int][BitConverter]::ToUInt16($h, 18)
        if ($sig -eq 'HXCPICFE' -and $nCyl -gt 0 -and $tlBase -ge 1) {
            $tl = New-Object byte[] (4 * $nCyl)
            [void]$fs.Seek([int64]$tlBase * 512, [System.IO.SeekOrigin]::Begin)
            $got = $fs.Read($tl, 0, $tl.Length)
            if ($got -eq $tl.Length) {
                $flen = $fs.Length
                $lens = @(@(for ($i = 0; $i + 4 -le $got; $i += 4) {
                    $off = [int64][BitConverter]::ToUInt16($tl, $i); $l = [int][BitConverter]::ToUInt16($tl, $i + 2)
                    if ($l -ge 2 -and $off -gt $tlBase -and $off * 512 + $l -le $flen + 512) { 8 * [int64][math]::Floor($l / 2) }
                }) | Sort-Object)
                if ($lens.Count -gt 0 -and $lens.Count -ge [math]::Ceiling($nCyl / 2)) {
                    $med = [int64]$lens[[int][math]::Floor($lens.Count / 2)]
                    if ($med -ge 20000 -and $med -le 600000) { $bits = $med; $src = ((T "HFE ({0} bits par piste, débit {1} kbit/s)") -f "$med", "$rate") }
                }
            }
        }
    } finally { $fs.Dispose() }
    return @{ CellNs = [double](200000000.0 / $bits); Bits = $bits; Tracks = -1; DosTracks = -1; Source = $src }
}

function Get-CurveDate($cv) {
    # Date d une courbe (dd/MM/yyyy HH:mm, separateur de la culture courante a l enregistrement) ; MinValue si illisible
    $d = [datetime]::MinValue
    if (-not $cv -or -not $cv.Date) { return $d }
    foreach ($ci in @([System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.CultureInfo]::CurrentCulture)) {
        if ([datetime]::TryParseExact([string]$cv.Date, 'dd/MM/yyyy HH:mm', $ci, [System.Globalization.DateTimeStyles]::None, [ref]$d)) { return $d }
    }
    return [datetime]::MinValue
}

function Test-HeadCurvesCurrent([string]$fam) {
    # Courbes par tete applicables : les deux presentes et au moins aussi recentes que la courbe commune de la famille
    # (une calibration commune posterieure, apres un changement de lecteur par exemple, les rend perimees).
    $h0 = $script:PrecompCurves["${fam}_h0"]; $h1 = $script:PrecompCurves["${fam}_h1"]
    if (-not $h0 -or -not $h1 -or -not $h0.Spec -or -not $h1.Spec) { return $false }
    $one = $script:PrecompCurves[$fam]
    if (-not $one) { return $true }
    return ((Get-CurveDate $h0) -ge (Get-CurveDate $one))
}

function Get-FamilyCurves([string]$family, [bool]$preferHeads) {
    # Courbes appliquees a la famille : par tete en ecriture lente si elles sont a jour, sinon la courbe commune
    if ($preferHeads -and (Test-HeadCurvesCurrent $family)) { return ,@($script:PrecompCurves["${family}_h0"], $script:PrecompCurves["${family}_h1"]) }
    $one = $script:PrecompCurves[$family]
    if ($one) { return ,@($one) }
    return ,@()
}

function Get-HeadSpec([string]$fam, [int]$h) {
    # Profil calibre d une tete (ecriture lente), $null si la famille n a pas de calibration par tete
    $cv = $script:PrecompCurves["${fam}_h$h"]
    if ($cv -and $cv.Spec) { return [string]$cv.Spec }
    return $null
}

function Set-PrecompFields([string]$spec, [string]$fam) {
    # Champs --precomp : commun (tete 0 en ecriture lente) et tete 1. Ecriture lente : profils calibres par tete
    # de la famille s ils sont a jour, sinon le profil commun pour les deux tetes. Renvoie le complement du libelle.
    $chkWPrecomp.Checked = $true
    if ($chkWSlow.Checked -and (Test-HeadCurvesCurrent $fam)) {
        $txtWPrecomp.Text = Get-HeadSpec $fam 0; $txtWPrecomp1.Text = Get-HeadSpec $fam 1
        return (T ' ; écriture lente : profils calibrés tête 0 et tête 1 appliqués')
    }
    $txtWPrecomp.Text = $spec; $txtWPrecomp1.Text = $spec
    if (-not $chkWSlow.Checked) { return '' }
    if ((Get-HeadSpec $fam 0) -and (Get-HeadSpec $fam 1)) { return (T ' ; écriture lente : courbes par tête antérieures au profil commun, profil commun pour les deux têtes') }
    return (T ' ; écriture lente : même profil pour les deux têtes (aucune calibration par tête pour cette famille)')
}

function Update-PrecompForImage([string]$path) {
    Update-CurveButton $path
    $script:WProfileHd = $false
    $mode = $cmbWProfile.Text
    if ($mode -eq (T 'Manuel')) { $lblWProfileInfo.Text = (T 'Profil manuel : --precomp non modifié.'); return }
    if ($mode -eq (T 'Standard 2 us'))      { $x = Set-PrecompFields $script:PrecompStd 'std';   $lblWProfileInfo.Text = ((T "Profil forcé : standard 2 us ({0})") -f "$($script:PrecompStd)") + $x; return }
    if ($mode -eq (T 'Long track 1,89 us')) { $x = Set-PrecompFields $script:PrecompLong 'long'; $lblWProfileInfo.Text = ((T "Profil forcé : long track ({0})") -f "$($script:PrecompLong)") + $x; return }
    # Auto
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { $lblWProfileInfo.Text = ''; return }
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    # Image haute densite : jamais de profil calibre (courbes double densite, jusqu a CalHardNs ns, trop fortes pour une
    # cellule de 1 us), profil d origine de sa famille pour les deux tetes, ecriture lente comprise
    $hd = Get-HighDensityReason $path $cmbWFmt.Text
    if ($hd) {
        $hf = Get-ImageFamily $path
        $def = if ($hf -eq 'long') { $script:PrecompLongDefault } else { $script:PrecompStdDefault }
        $chkWPrecomp.Checked = $true; $txtWPrecomp.Text = $def; $txtWPrecomp1.Text = $def
        $lblWProfileInfo.Text = ((T "Auto : image haute densité ({0}) -> profil d'origine {1} ({2}) : un profil calibré (double densité) ne s'applique pas à une image haute densité") -f "$hd", (Get-CalibFamilyName $hf), "$def")
        Append-Log ((T "Profil precomp : {0}") -f "$($lblWProfileInfo.Text)")
        $script:WProfileHd = $true
        return
    }
    $info = $null
    try {
        switch ($ext) {
            '.ipf' { $info = Get-IpfCellInfo $path }
            '.scp' { if ($script:ScpStatsOk) { $info = Get-ScpCellInfo $path } }
            '.hfe' { $info = Get-HfeCellInfo $path }
        }
    } catch { Append-Log ((T "Détection du profil impossible ({0}) : {1}") -f "$ext", "$($_.Exception.Message)"); $info = $null }
    if ($null -eq $info) {
        # formats secteur (ADF, IMG, ST...) : cellule standard par definition
        $x = Set-PrecompFields $script:PrecompStd 'std'
        $lblWProfileInfo.Text = ((T "Auto : image secteur ({0}) -> standard 2 us ({1})") -f "$ext", "$($script:PrecompStd)") + $x
        return
    }
    $long = $info.CellNs -lt $script:PrecompThresholdNs
    $x = if ($long) { Set-PrecompFields $script:PrecompLong 'long' } else { Set-PrecompFields $script:PrecompStd 'std' }
    $detail = ((T "cellule {0} ns, {1} bits/piste") -f "$([math]::Round($info.CellNs,0))", "$($info.Bits)")
    if ($info.DosTracks -ge 0 -and $info.Tracks -gt 0) { $detail += ((T ", {0}/{1} pistes DOS") -f "$($info.DosTracks)", "$($info.Tracks)") }
    $lblWProfileInfo.Text = ((T "Auto : {0} : {1} -> ") -f "$($info.Source)", "$detail") + $(if ($long) { ((T "LONG TRACK ({0})") -f "$($script:PrecompLong)") } else { ((T "standard 2 us ({0})") -f "$($script:PrecompStd)") }) + $x
    Append-Log ((T "Profil precomp : {0}") -f "$($lblWProfileInfo.Text)")
}

# ============================== CALIBRATION PRECOMP ============================
# Principe. La precompensation corrige le decalage de pic (peak shift) : a la lecture,
# une transition est repoussee par sa voisine la plus proche, donc un intervalle court
# (2T) encadre par deux longs est lu trop long et un 3T encadre par deux courts trop
# court. ScpStats.Analyze mesure ce decalage residuel signe (Shift, ns) : > 0 = sous-
# compense, < 0 = sur-compense, 0 = reglage ideal. Il est lineaire en la precomp
# ecrite : trois passes de mesure (0, 100, 200 ns) suffisent pour ajuster une droite par
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
$script:CalCoarse    = @(0, 100, 200)   # passes de mesure : trois points pour la droite
# Plafond des passes de MESURE (encadrement, mesures complementaires, cibles interpolees) : un cylindre encore
# sous-compense a ce plafond a un zero extrapole de ses mesures, que la verification ecrit et mesure.
$script:CalMaxNs     = 300
# Borne absolue d une valeur de precomp (zero estime, courbe, verification, plafond Sat/plancher des residus) : gw 1.23
# n impose aucune borne (PrecompSpec int(v), Precomp.apply sans clamp) ; en MFM 2 us, un intervalle court ecrit vaut
# 4 us - 2t, 400 ns = 0,2 cellule ; simulation du PLL de gw : premier echec vers 540 ns (2 us), 507 ns (long track
# 1,89 us). Reglable dans la configuration (write.precompMaxNs), de 300 ns (plafond des mesures) a 470 ns (un quart de
# cellule long track : chaque intervalle ecrit atteint alors sa frontiere de decision) ; chaque courbe enregistre la borne
# de son calcul (maxNs).
$script:CalHardNsDefault = 400
$script:CalHardMinNs = 300
$script:CalHardMaxNs = 470
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
$script:CalBracketMargin = 80           # passe d encadrement : estimation + marge (ns) pour un cylindre encore sous-compense a 200 ns
$script:AfterCalib = ''                                  # 'write' : ecriture rapide ou lente a lancer apres une calibration reussie
$script:CalibConfirmSeconds = 120                        # avertissement avant calibration : validation automatique au bout de ce delai (s)
# Prechauffage du lecteur avant une calibration complete (Start-CalibWarmup), avant une ecriture lente (Start-WriteWarmup,
# case « Prechauffer le lecteur », write.slowWarmup) et avant la calibration rapide qui precede une ecriture lente (meme
# case) : lectures sans ecriture pendant CalWarmupMinutes (configuration write.calWarmupMinutes, decimales admises, 0 :
# aucun, 0 a 30 min), une lecture au moins. Lecteur deja actif (derniere commande gw qui fait tourner le moteur terminee
# il y a moins de CalWarmupGapMin) : duree reduite de celle de sa derniere serie d activite continue (une serie est rompue
# par CalWarmupGapMin sans commande) ; prechauffage saute s il en reste moins de CalWarmupSkipMin. Calibration rapide
# seule ou avant une ecriture rapide, ecriture rapide, reecritures du controle apres ecriture : aucun. Bouton « Passer le
# prechauffage » : fin apres la lecture en cours (WarmSkip).
$script:CalWarmupDefault  = 5
$script:CalWarmupMaxMin   = 30
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
$script:PrecompCurves = @{ std = $null; long = $null; std_h0 = $null; std_h1 = $null; long_h0 = $null; long_h1 = $null }   # derniere courbe calibree par famille d image (et par tete : ecriture lente)
$script:CurveKeys = @('std', 'long', 'std_h0', 'std_h1', 'long_h0', 'long_h1')
# Calibration rapide (niveau par disquette) : la forme vient d une calibration complete (reference), seul le niveau est
# mesure sur la disquette a ecrire. (H) : seuils a recaler sur materiel reel.
$script:LevelAlgo       = 'lvl1'
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
$script:WProfileHd = $false           # champs --precomp remplis par la branche haute densite d Update-PrecompForImage (mode Auto)
$script:LevelFieldsPending = $false   # ecriture apres une calibration rapide (Bibliotheque) : champs remis a la reference a sa fin
$script:CurveData = $null; $script:CurveForm = $null; $script:CurveFamily = 'std'
$script:UiReady = $false                                 # vrai une fois la fenetre principale affichee

function Get-ImageCylinders([string]$path) {
    # Nombre de cylindres de l image, $null si non determinable
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    try {
        switch ($ext) {
            '.adf' {
                $len = (Get-Item -LiteralPath $path).Length
                if ($len % 11264 -eq 0) {                                   # 11264 = 2 faces x 11 secteurs x 512 (DD)
                    $c = $len / 11264
                    if ($c -gt 84 -and $len % 22528 -eq 0) { $c = $len / 22528 }   # HD : 22 secteurs
                    return [int]$c
                }
            }
            '.ipf' {
                $d = [System.IO.File]::ReadAllBytes($path); $max = -1; $pos = 0
                while ($pos + 12 -le $d.Length) {
                    $id = [System.Text.Encoding]::ASCII.GetString($d, $pos, 4); $ln = Get-BE32 $d ($pos + 4)
                    if ($ln -lt 12) { break }
                    if ($id -eq 'IMGE' -and $pos + 16 -le $d.Length) {
                        $t = Get-BE32 $d ($pos + 12)                       # champ track = cylindre
                        if ($t -gt $max -and $t -lt 200) { $max = $t }
                    } elseif ($id -eq 'DATA' -and $pos + 16 -le $d.Length) { $ln += Get-BE32 $d ($pos + 12) }
                    $pos += $ln
                }
                if ($max -ge 0) { return [int]($max + 1) }
            }
            '.hfe' {
                $fs = [System.IO.File]::OpenRead($path)
                try { $h = New-Object byte[] 16; [void]$fs.Read($h, 0, 16) } finally { $fs.Dispose() }
                if ($h[9] -gt 0) { return [int]$h[9] }                     # number_of_track
            }
        }
    } catch { }
    return $null
}

function Get-ImageFamily([string]$path) {
    # 'long' si la cellule de l image est sous le seuil (long tracks), 'std' sinon : meme logique que le mode Auto
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    $info = $null
    try {
        switch ($ext) {
            '.ipf' { $info = Get-IpfCellInfo $path }
            '.hfe' { $info = Get-HfeCellInfo $path }
        }
    } catch { $info = $null }
    if ($null -ne $info -and $info.CellNs -lt $script:PrecompThresholdNs) { return 'long' }
    return 'std'
}

function Format-CylList([int[]]$cyls) {
    $s = @($cyls | Sort-Object -Unique)
    $contig = $true
    for ($i = 1; $i -lt $s.Count; $i++) { if ($s[$i] -ne $s[$i - 1] + 1) { $contig = $false; break } }
    if ($contig -and $s.Count -gt 1) { return "$($s[0])-$($s[-1])" }
    return ($s -join ',')
}

function Get-CalibTrackScore($st) {
    # Score de qualite (jitter 2T + asymetrie 3T/4T + hors classe) sur les tours lisibles ; 9999 = illisible
    foreach ($x in $st) { if ([double]::IsNaN($x.Jitter) -or [double]::IsNaN($x.R3) -or [double]::IsNaN($x.R4)) { return 9999 } }
    $j   = ($st | Measure-Object -Property Jitter -Average).Average
    $r3  = ($st | Measure-Object -Property R3 -Average).Average
    $r4  = ($st | Measure-Object -Property R4 -Average).Average
    $ooc = ($st | Measure-Object -Property OutOfClass -Average).Average
    return ($j + 2000 * ([math]::Abs($r3 - 1.5) + [math]::Abs($r4 - 2.0)) + 5 * $ooc)
}


function Get-CalibFamilyName([string]$family) {
    if ($family -eq 'long') { return (T 'Long track 1,89 us') }
    return (T 'Standard 2 us')
}

function Get-SpecValue([string]$spec, [int]$cyl) {
    # Valeur de precomp appliquee par gw au cylindre : derniere entree c=ns dont c <= cylindre (entrees croissantes)
    $v = 0
    foreach ($m in [regex]::Matches($spec, '(\d+)\s*=\s*(\d+)')) { if ([int]$m.Groups[1].Value -le $cyl) { $v = [int]$m.Groups[2].Value } }
    return $v
}

function Get-CurveX([string]$model, [double]$c, [int]$maxCyl) {
    # Abscisse du modele pour le cylindre c. u = 0 (exterieur) a 1 (dernier cylindre de l image).
    # Rayon relatif : 3,5" de 39,5 a 24,7 mm (rapport 0,625) ; 5,25" 40 ou 80 pistes : rapport voisin (0,63).
    $u = $c / [math]::Max(1, $maxCyl)
    $r = 1.0 - 0.375 * $u
    switch ($model) {
        'inv'  { return 1.0 / $r }
        'inv2' { return 1.0 / ($r * $r) }
        default { return $u }
    }
}

function Get-Median($a) {
    $s = @($a | ForEach-Object { [double]$_ } | Sort-Object)
    if ($s.Count -eq 0) { return 0.0 }
    if ($s.Count % 2 -eq 1) { return [double]$s[[int][math]::Floor($s.Count / 2)] }
    return ([double]$s[$s.Count / 2 - 1] + [double]$s[$s.Count / 2]) / 2
}

function Get-IsolatedPoints($cs, $est, $sig) {
    # Donnees denses (test fin, mesures complementaires) : point isole = au moins un voisin mesure a 3 cylindres au plus
    # de chaque cote (2 au plus par cote), ecart a la mediane des voisins > max(15 ns ; 4 incertitudes) alors que les
    # deux cotes s accordent (ecart < meme seuil) : defaut ponctuel de la disquette de calibration, non suivi par la
    # courbe. 10 % des points et 4 au plus, jamais le premier ni le dernier.
    $cand = @()
    for ($i = 1; $i -lt $cs.Count - 1; $i++) {
        $c = [int]$cs[$i]
        $left = @(); for ($j = $i - 1; $j -ge 0 -and $left.Count -lt 2; $j--) { if ($c - [int]$cs[$j] -le 3) { $left += [double]$est[[int]$cs[$j]] } else { break } }
        $right = @(); for ($j = $i + 1; $j -lt $cs.Count -and $right.Count -lt 2; $j++) { if ([int]$cs[$j] - $c -le 3) { $right += [double]$est[[int]$cs[$j]] } else { break } }
        if ($left.Count -eq 0 -or $right.Count -eq 0) { continue }
        $s = if ($sig -and $sig.ContainsKey($c)) { [double]$sig[$c] } else { 5.0 }
        $thr = [math]::Max(15.0, 4.0 * $s)
        $r = [double]$est[$c] - (Get-Median (@($left) + @($right)))
        if ([math]::Abs($r) -gt $thr -and [math]::Abs((Get-Median $left) - (Get-Median $right)) -lt $thr) { $cand += ,@($c, $r) }
    }
    $max = [int][math]::Min(4, [math]::Floor($cs.Count * 0.1))
    $out = @{}
    if ($max -le 0) { return $out }
    foreach ($x in @($cand | Sort-Object { -[math]::Abs([double]$_[1]) } | Select-Object -First $max)) { $out[[int]$x[0]] = [double]$x[1] }
    return $out
}

function Fit-PrecompCurve($est, $sig, [int]$maxCyl, $kinds = $null, [bool]$dense = $false) {
    # Courbe de precompensation par cylindre a partir des estimations des cylindres testes.
    # Moindres carres ponderes (poids = 1 / incertitude^2) de p = A + B.x, B >= 0, pour trois formes
    # physiquement plausibles (densite lineaire croissante vers l interieur) : x = cylindre, 1/rayon,
    # 1/rayon^2 ; la forme de plus faible ecart pondere est retenue. Si elle n explique pas les mesures
    # (chi2 reduit > 4 avec au moins 4 points), interpolation monotone des mesures lissees (PAVA).
    # Donnees denses : points isoles ecartes (poids nul : la courbe passe par l interpolation de leurs voisins)
    $csAll = @($est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    if ($csAll.Count -eq 0) { return $null }
    $outl = @{}
    if ($dense -and $csAll.Count -ge 8) { $outl = Get-IsolatedPoints $csAll $est $sig }
    $cs = @($csAll | Where-Object { -not $outl.ContainsKey($_) })
    $ys = @($cs | ForEach-Object { [double]$est[$_] })
    $ws = @($cs | ForEach-Object { $s = if ($sig -and $sig.ContainsKey($_)) { [math]::Max(1.0, [double]$sig[$_]) } else { 5.0 }; 1.0 / ($s * $s) })
    $best = $null
    foreach ($model in 'lin', 'inv', 'inv2') {
        $xs = @($cs | ForEach-Object { Get-CurveX $model $_ $maxCyl })
        $sw = 0.0; $sx = 0.0; $sy = 0.0
        for ($i = 0; $i -lt $cs.Count; $i++) { $sw += $ws[$i]; $sx += $ws[$i] * $xs[$i]; $sy += $ws[$i] * $ys[$i] }
        $mx = $sx / $sw; $my = $sy / $sw
        $sxx = 0.0; $sxy = 0.0
        for ($i = 0; $i -lt $cs.Count; $i++) { $sxx += $ws[$i] * ($xs[$i] - $mx) * ($xs[$i] - $mx); $sxy += $ws[$i] * ($xs[$i] - $mx) * ($ys[$i] - $my) }
        $b = if ($cs.Count -ge 2 -and $sxx -gt 0) { [math]::Max(0.0, $sxy / $sxx) } else { 0.0 }
        $a = $my - $b * $mx
        $ssr = 0.0
        for ($i = 0; $i -lt $cs.Count; $i++) { $e = $ys[$i] - ($a + $b * $xs[$i]); $ssr += $ws[$i] * $e * $e }
        if ($null -eq $best -or $ssr -lt $best.Ssr) { $best = @{ Model = $model; A = $a; B = $b; Ssr = $ssr } }
    }
    $chi = $best.Ssr / [math]::Max(1, $cs.Count - 2)
    $vals = New-Object int[] ($maxCyl + 1)
    if ($cs.Count -ge 4 -and $chi -gt 4.0) {
        # Monotone par segments (CurveFit) : le besoin peut redescendre une ou deux fois, seulement sur une chute nette
        # (plus de 15 ns et de 3 incertitudes) entre deux mesures encadrees ; sinon croissant (PAVA). Puis lineaire
        # entre cylindres testes.
        $fyS = $null; $model = 'iso'; $breaks = @(); $segs = $null
        if ($script:CurveFitOk) {
            $rel = [bool[]]@($cs | ForEach-Object { -not $kinds -or -not $kinds.ContainsKey($_) -or $kinds[$_] -eq 'interp' })
            $sg = @($cs | ForEach-Object { if ($sig -and $sig.ContainsKey($_)) { [math]::Max(1.0, [double]$sig[$_]) } else { 5.0 } })
            $minDrop = [math]::Max(15.0, 3.0 * [math]::Sqrt(2.0) * (Get-Median $sg))
            $r = [CurveFit]::SegFit([double[]]$ys, [double[]]$ws, $rel, 4.0 * [math]::Log($cs.Count), $minDrop)
            $K = [int]$r[0]
            $fyS = @($r[4..($r.Count - 1)])
            if ($K -ge 1) {
                $pk = [int]$cs[[int]$r[1] - 1]
                $tr = if ($K -eq 2) { [int]$cs[[int]$r[2] - 1] } else { $maxCyl }
                $model = 'seg'
                $breaks = if ($K -eq 2) { @($pk, $tr) } else { @($pk) }
                $segs = @(@{ Lo = 0; Hi = $pk; Dir = 1 }, @{ Lo = $pk + 1; Hi = $tr; Dir = -1 })
                if ($K -eq 2 -and $tr -lt $maxCyl) { $segs += @{ Lo = $tr + 1; Hi = $maxCyl; Dir = 1 } }
            }
        }
        if ($null -ne $fyS) {
            $fy = $fyS
            for ($c = 0; $c -le $maxCyl; $c++) {
                if ($c -le $cs[0]) { $v = $fy[0] }
                elseif ($c -ge $cs[-1]) { $v = $fy[-1] }
                else {
                    $j = 0; while ($cs[$j + 1] -lt $c) { $j++ }
                    $tt = ($c - $cs[$j]) / [double]($cs[$j + 1] - $cs[$j])
                    $v = $fy[$j] + $tt * ($fy[$j + 1] - $fy[$j])
                }
                $vals[$c] = [int][math]::Max(0, [math]::Min($script:CalHardNs, [math]::Round($v, 0)))
            }
            return @{ Model = $model; A = $null; B = $null; Chi = $chi; Values = $vals; Breaks = $breaks; Segs = $segs; Outliers = @($outl.Keys) }
        }
        # Repli sans CurveFit : interpolation monotone croissante (PAVA pondere sur les mesures)
        $blocks = New-Object System.Collections.Generic.List[object]
        for ($i = 0; $i -lt $cs.Count; $i++) {
            $blocks.Add(@{ SW = $ws[$i]; SWY = $ws[$i] * $ys[$i]; N = 1 })
            while ($blocks.Count -ge 2) {
                $p = $blocks[$blocks.Count - 2]; $q = $blocks[$blocks.Count - 1]
                if ($p.SWY / $p.SW -le $q.SWY / $q.SW) { break }
                $blocks.RemoveAt($blocks.Count - 1); $blocks.RemoveAt($blocks.Count - 1)
                $blocks.Add(@{ SW = $p.SW + $q.SW; SWY = $p.SWY + $q.SWY; N = $p.N + $q.N })
            }
        }
        $fy = @(); foreach ($bk in $blocks) { for ($k = 0; $k -lt $bk.N; $k++) { $fy += $bk.SWY / $bk.SW } }
        for ($c = 0; $c -le $maxCyl; $c++) {
            if ($c -le $cs[0]) { $v = $fy[0] }
            elseif ($c -ge $cs[-1]) { $v = $fy[-1] }
            else {
                $j = 0; while ($cs[$j + 1] -lt $c) { $j++ }
                $t = ($c - $cs[$j]) / [double]($cs[$j + 1] - $cs[$j])
                $v = $fy[$j] + $t * ($fy[$j + 1] - $fy[$j])
            }
            $vals[$c] = [int][math]::Max(0, [math]::Min($script:CalHardNs, [math]::Round($v, 0)))
        }
        return @{ Model = 'iso'; A = $null; B = $null; Chi = $chi; Values = $vals; Breaks = @(); Segs = $null; Outliers = @($outl.Keys) }
    }
    for ($c = 0; $c -le $maxCyl; $c++) {
        $v = $best.A + $best.B * (Get-CurveX $best.Model $c $maxCyl)
        $vals[$c] = [int][math]::Max(0, [math]::Min($script:CalHardNs, [math]::Round($v, 0)))
    }
    return @{ Model = $best.Model; A = $best.A; B = $best.B; Chi = $chi; Values = $vals; Breaks = @(); Segs = $null; Outliers = @($outl.Keys) }
}

function Add-CurveCorrection($values, $delta, $segs = $null) {
    # Valeurs par cylindre + corrections locales (ns) mesurees aux cylindres verifies, segment par segment (courbe
    # monotone par segments : jamais d interpolation ni de lissage a travers un changement de sens) : interpolation
    # lineaire des corrections des cylindres verifies du segment (0 la ou le residu est dans la tolerance), constante
    # jusqu aux bords du segment, puis lissage monotone dans le sens du segment (PAVA) et arrondi a l entier.
    $v = @($values); $n = $v.Count
    if (-not $segs) { $segs = @(@{ Lo = 0; Hi = $n - 1; Dir = 1 }) }
    $out = New-Object int[] $n
    for ($c = 0; $c -lt $n; $c++) { $out[$c] = [int]$v[$c] }
    foreach ($sg in @($segs)) {
        $lo = [math]::Max(0, [int]$sg.Lo); $hi = [math]::Min($n - 1, [int]$sg.Hi)
        if ($hi -lt $lo) { continue }
        $ks = @($delta.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -ge $lo -and $_ -le $hi } | Sort-Object)
        if ($ks.Count -gt 0 -and @($segs).Count -gt 1) {
            # Ancrage aux bords : cylindre verifie le plus proche dans le segment voisin (sommet ou creux), pour que la
            # correction parte de la sienne au lieu de s appliquer telle quelle jusqu au changement de sens
            $kl = @($delta.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -lt $lo } | Sort-Object)
            $kr = @($delta.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -gt $hi } | Sort-Object)
            if ($kl.Count -gt 0) { $ks = @(@($kl[-1]) + $ks) }
            if ($kr.Count -gt 0) { $ks = @($ks + @($kr[0])) }
        }
        $raw = New-Object double[] ($hi - $lo + 1)
        for ($c = $lo; $c -le $hi; $c++) {
            $d = 0.0
            if ($ks.Count -gt 0) {
                if ($c -le $ks[0]) { $d = [double]$delta[$ks[0]] }
                elseif ($c -ge $ks[-1]) { $d = [double]$delta[$ks[-1]] }
                else {
                    $j = 0; while ($ks[$j + 1] -lt $c) { $j++ }
                    $tt = ($c - $ks[$j]) / [double]($ks[$j + 1] - $ks[$j])
                    $d = [double]$delta[$ks[$j]] + $tt * ([double]$delta[$ks[$j + 1]] - [double]$delta[$ks[$j]])
                }
            }
            $raw[$c - $lo] = ([double]$v[$c] + $d) * [int]$sg.Dir
        }
        $blocks = New-Object System.Collections.Generic.List[object]
        foreach ($x in $raw) {
            $blocks.Add(@{ S = $x; N = 1 })
            while ($blocks.Count -ge 2) {
                $p = $blocks[$blocks.Count - 2]; $q = $blocks[$blocks.Count - 1]
                if ($p.S / $p.N -le $q.S / $q.N) { break }
                $blocks.RemoveAt($blocks.Count - 1); $blocks.RemoveAt($blocks.Count - 1)
                $blocks.Add(@{ S = $p.S + $q.S; N = $p.N + $q.N })
            }
        }
        $c = $lo
        foreach ($bk in $blocks) { $m = [int][math]::Max(0, [math]::Min($script:CalHardNs, [math]::Round($bk.S / $bk.N * [int]$sg.Dir, 0))); for ($k = 0; $k -lt $bk.N; $k++) { $out[$c++] = $m } }
    }
    return ,$out
}

function Build-CurveProfile($values) {
    # Valeurs par cylindre -> profil --precomp : une entree c=ns a chaque changement (gw : valeur pour c et au-dela)
    $v = @($values)
    if ($v.Count -eq 0) { return '' }
    $parts = @("0=$($v[0])")
    for ($c = 1; $c -lt $v.Count; $c++) { if ($v[$c] -ne $v[$c - 1]) { $parts += "$c=$($v[$c])" } }
    return ($parts -join ':')
}

function Get-CurveModelName([string]$model) {
    if ($model -match '^(.+)\+c$') { return (Get-CurveModelName $Matches[1]) + (T ' + corrections locales') }
    switch ($model) {
        'lin'  { return (T 'linéaire') }
        'inv'  { return (T '1/rayon') }
        'inv2' { return (T '1/rayon²') }
        'iso'  { return (T 'monotone interpolée') }
        'seg'  { return (T 'monotone par segments') }
        default { return $model }
    }
}

function Format-CurveTable($cvs) {
    # Tableau texte des valeurs par cylindre (10 par ligne), profil --precomp, puis mesures avec leur origine, l ecart
    # de la courbe et le residu de la derniere verification, pour chaque courbe
    $lines = @()
    $kn = @{ witness = (T 'témoin de marche'); probe = (T 'témoin du plafond') }
    foreach ($cv in @($cvs)) {
        if ($lines.Count -gt 0) { $lines += ''; $lines += '' }
        $lrs = Get-CurveLevelRecs $cv
        foreach ($rec in @($lrs)) {
            $vk = if ([string]$rec.Shape -eq 'mismatch') { 'mismatch' } else { [string]$rec.Verdict }
            $vt = @{ ok = (T 'conforme'); approx = (T 'approximative'); mismatch = (T 'NON CONFORME'); sat = (T 'non vérifiée, plafond atteint'); low = (T 'non vérifiée, plancher atteint'); few = (T 'non vérifiée, trop peu de cylindres mesurés') }[$vk]
            $hp = if ($null -eq $rec.Head) { '' } else { (T '[tête {0}] ') -f "$($rec.Head)" }
            $lines += ($hp + ((T "Dernière calibration rapide ({0}, lecteur {1}) : niveau {2} ns ± {3} ; écart de forme {4} ns ; forme {5} ; {6} passe(s) ; profil appliqué : {7}") -f "$($rec.Date)", "$($rec.Drive)", ('{0:+0;-0;0}' -f [int]$rec.Delta), (Format-LevelNum $rec.SE), (Format-LevelNum $rec.Tau), "$vt", "$($rec.Passes)", "$($rec.Spec)"))
            for ($i = 0; $i -lt @($rec.Cyls).Count; $i++) {
                $kd = [string]$rec.Kinds[$i]; $kt = if ($kn.ContainsKey($kd)) { $kn[$kd] } else { Get-KindName $kd }
                $lines += ((T "  c{0,-3} zéro {1,6:0.0} ± {2,4:0.0}  écart à la forme {3,6:+0.0;-0.0;0.0}  {4}") -f [int]$rec.Cyls[$i], [double]$rec.Zs[$i], [double]$rec.Sigs[$i], $(if ([double]::IsNaN([double]$rec.Est)) { '-' } else { [double]$rec.Ds[$i] - [double]$rec.Est }), "$kt")
            }
            $hv = @(@($rec.Hist) | ForEach-Object { [double]$_.Delta })
            if ($hv.Count -gt 0) { $lines += ((T "Niveaux mesurés avec cette référence : médiane {0} ns, de {1} à {2} ns, {3} disquette(s).") -f ('{0:+0;-0;0}' -f [math]::Round((Get-Median $hv), 0)), ('{0:+0;-0;0}' -f ($hv | Measure-Object -Minimum).Minimum), ('{0:+0;-0;0}' -f ($hv | Measure-Object -Maximum).Maximum), "$($hv.Count)") }
            $lines += ''
        }
        if ($null -ne $cv.Head) { $lines += ((T "Tête {0} : courbe {1}") -f "$($cv.Head)", (Get-CurveModelName $cv.Model)) }
        $lines += ((T "Calcul de calibration : {0}") -f (Get-CurveCalcText $cv))
        if ($cv.Converged -eq $false) { $lines += (T 'NON CONVERGÉE : résidu hors tolérance après la dernière vérification (voir « résidu »).') }
        $v = @($cv.Values)
        $lines += @(((T "Profil --precomp : {0}") -f "$($cv.Spec)"), '', ('cyl  ' + ((0..9 | ForEach-Object { '{0,5}' -f "+$_" }) -join '')))
        for ($c0 = 0; $c0 -lt $v.Count; $c0 += 10) {
            $row = @(); for ($c = $c0; $c -lt [math]::Min($v.Count, $c0 + 10); $c++) { $row += ('{0,5}' -f $v[$c]) }
            $lines += ('{0,3}  ' -f $c0) + ($row -join '')
        }
        $lines += ''
        $lines += (T "Mesures (cylindre : estimation ± incertitude en ns, origine, courbe retenue et écart, résidu de vérification) :")
        for ($i = 0; $i -lt @($cv.Cyls).Count; $i++) {
            $c = [int]$cv.Cyls[$i]
            $kind = if ($cv.Kinds -and $i -lt @($cv.Kinds).Count) { Get-KindName $cv.Kinds[$i] } else { '' }
            $cur = if ($c -lt $v.Count) { $v[$c] } else { $null }
            $dev = if ($null -ne $cur) { '{0:+0;-0;0}' -f ($cur - [double]$cv.Ys[$i]) } else { '' }
            # Zone non reproductible (verifications contradictoires) : valeur retenue sans mesure a cette valeur
            $res = if (@($cv.Contra) -contains $c) { (T 'zone non reproductible') }
                   elseif ($cv.Res -and $i -lt @($cv.Res).Count -and -not [double]::IsNaN([double]$cv.Res[$i])) { (T 'résidu {0}') -f ('{0:+0.0;-0.0;0.0}' -f [double]$cv.Res[$i]) } else { '' }
            $lines += ("  c{0,-3} {1,6:0.0} ± {2,4:0.0}  {3,-11} {4} {5,4} ({6,4})  {7}" -f $c, [double]$cv.Ys[$i], [double]$cv.Sig[$i], $kind, (T 'courbe'), $cur, $dev, $res).TrimEnd()
        }
    }
    return ($lines -join "`r`n")
}

function Draw-PrecompCurve($g, $size) {
    # Une courbe (profil commun) ou une par tete (ecriture lente). Mesures selon leur origine : point plein = encadree
    # par deux mesures, cercle creux = extrapolee, carre creux = plafonnee ; anneau rouge = ecart a la courbe > max(15 ns ; 3 incertitudes).
    # Zone hachuree : au-dessus de la plus forte precomp mesuree (extrapolation).
    $cvs = @(@($script:CurveData) | Where-Object { $_ })
    if ($cvs.Count -eq 0) { return }
    $multi = $cvs.Count -gt 1
    # Niveaux de la derniere calibration rapide, superposes a chaque courbe (Set-CurveLevelData)
    $lvls = @{}; $hasLevel = $false
    for ($k = 0; $k -lt $cvs.Count; $k++) {
        # Affectation directe : un if renverrait un enregistrement seul deroule (table de hachage, pas tableau)
        $lvls[$k] = @()
        if ($script:CurveLevel -and $script:CurveLevel.ContainsKey($k)) { $lvls[$k] = @($script:CurveLevel[$k]) }
        if ($lvls[$k].Count -gt 0) { $hasLevel = $true }
    }
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::White)
    $W = $size.Width; $H = $size.Height
    $nRec = @(@($lvls.Values) | ForEach-Object { $_ }).Count       # un enregistrement de niveau par ligne de legende
    $L = 56; $R = 20; $Tp = $(if ($hasLevel) { 92 + 20 * [math]::Max(0, $nRec - 1) } else { 72 }); $Bm = 40
    $pw = $W - $L - $R; $ph = $H - $Tp - $Bm
    if ($pw -lt 60 -or $ph -lt 40) { return }
    $nC = 2; foreach ($cv in $cvs) { $nC = [math]::Max($nC, @($cv.Values).Count) }
    $maxC = $nC - 1
    $top = 0.0; $maxX = 0
    foreach ($cv in $cvs) {
        foreach ($x in @($cv.Values)) { if ($x -gt $top) { $top = $x } }
        for ($i = 0; $i -lt @($cv.Cyls).Count; $i++) { $t = [double]$cv.Ys[$i] + [double]$cv.Sig[$i]; if ($t -gt $top) { $top = $t } }
        if ($cv.MaxX -and [int]$cv.MaxX -gt $maxX) { $maxX = [int]$cv.MaxX }
    }
    foreach ($k in @($lvls.Keys)) { foreach ($rec in $lvls[$k]) {
        foreach ($x in @($rec.Values)) { if ($x -gt $top) { $top = $x } }
        for ($i = 0; $i -lt @($rec.Zs).Count; $i++) { $tz = [double]$rec.Zs[$i] + [double]$rec.Sigs[$i]; if ($tz -gt $top) { $top = $tz } }
    } }
    $step = if ($top -le 120) { 20 } elseif ($top -le 400) { 50 } else { 100 }      # pas de 50 jusqu a la borne CalHardNs
    $ymax = [math]::Max(2 * $step, [math]::Ceiling($top / $step) * $step)
    $fx = { param($c) $L + $pw * $c / $maxC }
    $fy = { param($v) $Tp + $ph * (1.0 - $v / $ymax) }
    $font = New-Object System.Drawing.Font('Segoe UI', 8.25)
    $fontB = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75)
    $grid = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(228, 232, 238), 1)
    $axis = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150, 156, 166), 1)
    $err = New-Object System.Drawing.Pen($script:Theme.Muted, 1.2)
    $flag = New-Object System.Drawing.Pen($script:Theme.Danger, 1.8)
    $txt = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 76, 88))
    $red = New-Object System.Drawing.SolidBrush($script:Theme.Danger)
    $gray = New-Object System.Drawing.SolidBrush($script:Theme.Muted)
    $grayPen = New-Object System.Drawing.Pen($script:Theme.Muted, 1.6)
    $hatch = New-Object System.Drawing.Drawing2D.HatchBrush([System.Drawing.Drawing2D.HatchStyle]::BackwardDiagonal, [System.Drawing.Color]::FromArgb(222, 226, 232), [System.Drawing.Color]::White)
    $colors = @($script:Theme.Accent, $script:Theme.Flux)
    $pens = @(); $dots = @(); $hollow = @()
    for ($i = 0; $i -lt $cvs.Count; $i++) {
        $col = $colors[[math]::Min($i, 1)]
        $dc = if ($multi) { $col } else { $script:Theme.Flux }
        $pens += (New-Object System.Drawing.Pen($col, 2.2))
        $dots += (New-Object System.Drawing.SolidBrush($dc))
        $hollow += (New-Object System.Drawing.Pen($dc, 1.6))
    }
    try {
        if ($maxX -gt 0 -and $maxX -lt $ymax) {
            $yh = & $fy $maxX
            $g.FillRectangle($hatch, [float]$L, [float]$Tp, [float]$pw, [float]($yh - $Tp))
        }
        for ($v = 0; $v -le $ymax; $v += $step) {
            $y = & $fy $v
            $g.DrawLine($grid, $L, $y, $L + $pw, $y)
            $s = "$v"; $sz = $g.MeasureString($s, $font)
            $g.DrawString($s, $font, $txt, $L - 6 - $sz.Width, $y - $sz.Height / 2)
        }
        $ticks = @(0..$maxC | Where-Object { $_ % 10 -eq 0 }); if ($ticks -notcontains $maxC) { $ticks += $maxC }
        foreach ($c in $ticks) {
            $x = & $fx $c
            $g.DrawLine($grid, $x, $Tp, $x, $Tp + $ph)
            $s = "$c"; $sz = $g.MeasureString($s, $font)
            $g.DrawString($s, $font, $txt, $x - $sz.Width / 2, $Tp + $ph + 4)
        }
        $g.DrawLine($axis, $L, $Tp + $ph, $L + $pw, $Tp + $ph); $g.DrawLine($axis, $L, $Tp, $L, $Tp + $ph)
        $g.DrawString('ns', $font, $txt, 8, $Tp - 16)
        $s = (T 'cylindre'); $sz = $g.MeasureString($s, $font); $g.DrawString($s, $font, $txt, $L + $pw - $sz.Width, $Tp + $ph + 20)
        # Changements de sens du besoin (courbe monotone par segments) : trait vertical pointille
        $dash = New-Object System.Drawing.Pen($script:Theme.Muted, 1)
        $dash.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
        try { foreach ($cv in $cvs) { foreach ($bc in @($cv.Breaks)) { if ($null -ne $bc -and [int]$bc -le $maxC) { $xb = & $fx ([int]$bc); $g.DrawLine($dash, $xb, $Tp, $xb, $Tp + $ph) } } } } finally { $dash.Dispose() }
        for ($k = 0; $k -lt $cvs.Count; $k++) {
            $cv = $cvs[$k]; $vals = @($cv.Values)
            $pts = New-Object 'System.Drawing.PointF[]' $vals.Count
            for ($c = 0; $c -lt $vals.Count; $c++) { $pts[$c] = New-Object System.Drawing.PointF([float](& $fx $c), [float](& $fy $vals[$c])) }
            if ($pts.Count -ge 2) { $g.DrawLines($pens[$k], $pts) }
            for ($i = 0; $i -lt @($cv.Cyls).Count; $i++) {
                $x = & $fx $cv.Cyls[$i]; $yv = [double]$cv.Ys[$i]; $sg = [double]$cv.Sig[$i]
                $y1 = & $fy ([math]::Min($ymax, $yv + $sg)); $y2 = & $fy ([math]::Max(0, $yv - $sg))
                $g.DrawLine($err, $x, $y1, $x, $y2); $g.DrawLine($err, $x - 3, $y1, $x + 3, $y1); $g.DrawLine($err, $x - 3, $y2, $x + 3, $y2)
                $y = & $fy $yv
                $kind = if ($cv.Kinds -and $i -lt @($cv.Kinds).Count) { [string]$cv.Kinds[$i] } else { 'interp' }
                switch ($kind) {
                    'outlier' { $g.DrawLine($hollow[$k], $x - 4, $y - 4, $x + 4, $y + 4); $g.DrawLine($hollow[$k], $x - 4, $y + 4, $x + 4, $y - 4) }
                    'extrap' { $g.FillEllipse([System.Drawing.Brushes]::White, $x - 3.5, $y - 3.5, 7, 7); $g.DrawEllipse($hollow[$k], $x - 3.5, $y - 3.5, 7, 7) }
                    'cap'    { $g.FillRectangle([System.Drawing.Brushes]::White, $x - 3.5, $y - 3.5, 7, 7); $g.DrawRectangle($hollow[$k], $x - 3.5, $y - 3.5, 7, 7) }
                    default  { $g.FillEllipse($dots[$k], $x - 3.5, $y - 3.5, 7, 7) }
                }
                if (Test-CurvePointFlag $cv $i) { $g.DrawEllipse($flag, $x - 7, $y - 7, 14, 14) }
            }
            # Courbe decalee de la derniere disquette (tirets) et mesures du niveau (losanges)
            foreach ($rec in $lvls[$k]) {
                $col = if ($null -ne $rec.Head -and -not $multi) { $colors[[math]::Min([int]$rec.Head, 1)] } else { $colors[[math]::Min($k, 1)] }
                $dp = New-Object System.Drawing.Pen($col, 1.6); $dp.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
                $mp = New-Object System.Drawing.Pen($col, 1.4)
                try {
                    $rv = @($rec.Values)
                    $lp = New-Object 'System.Drawing.PointF[]' $rv.Count
                    for ($c = 0; $c -lt $rv.Count; $c++) { $lp[$c] = New-Object System.Drawing.PointF([float](& $fx $c), [float](& $fy $rv[$c])) }
                    if ($lp.Count -ge 2) { $g.DrawLines($dp, $lp) }
                    for ($i = 0; $i -lt @($rec.Cyls).Count; $i++) {
                        $x = & $fx ([int]$rec.Cyls[$i]); $zv = [double]$rec.Zs[$i]; $sz2 = [double]$rec.Sigs[$i]; $y = & $fy $zv
                        if ($sz2 -gt 0) { $y1 = & $fy ([math]::Min($ymax, $zv + $sz2)); $y2 = & $fy ([math]::Max(0, $zv - $sz2)); $g.DrawLine($err, $x, $y1, $x, $y2) }
                        $kd = [string]$rec.Kinds[$i]
                        if ($kd -eq 'outlier') { $g.DrawLine($mp, $x - 4, $y - 4, $x + 4, $y + 4); $g.DrawLine($mp, $x - 4, $y + 4, $x + 4, $y - 4) }
                        elseif ($kd -eq 'cap') { $g.DrawRectangle($mp, $x - 3.5, $y - 3.5, 7, 7) }
                        else {
                            $dm = @((New-Object System.Drawing.PointF([float]$x, [float]($y - 5))), (New-Object System.Drawing.PointF([float]($x + 5), [float]$y)), (New-Object System.Drawing.PointF([float]$x, [float]($y + 5))), (New-Object System.Drawing.PointF([float]($x - 5), [float]$y)))
                            $g.FillPolygon([System.Drawing.Brushes]::White, [System.Drawing.PointF[]]$dm); $g.DrawPolygon($mp, [System.Drawing.PointF[]]$dm)
                        }
                    }
                } finally { $dp.Dispose(); $mp.Dispose() }
            }
        }
        # Titre (non convergence en rouge) et legende sur deux lignes
        $cv0 = $cvs[0]; $v0 = @($cv0.Values)
        if ($multi) { $title = ((T "{0} : lecteur {1}, {2}, une courbe par tête") -f "$($cv0.Family)", "$($cv0.Drive)", "$($cv0.Date)") }
        else { $title = ((T "{0} : lecteur {1}, {2}, courbe {3}, de {4} à {5} ns") -f "$($cv0.Family)", "$($cv0.Drive)", "$($cv0.Date)", (Get-CurveModelName $cv0.Model), "$($v0[0])", "$($v0[-1])") }
        $title += ', ' + ((T "calcul {0}") -f (Get-CurveCalcText $cv0))     # version du calcul de calibration de la courbe
        $g.DrawString($title, $fontB, $txt, $L, 8)
        $tx = $L + 12 + $g.MeasureString($title, $fontB).Width
        if (@($cvs | Where-Object { $_.Converged -eq $false }).Count -gt 0) {
            $g.DrawString((T 'NON CONVERGÉE'), $fontB, $red, $tx, 8); $tx += 12 + $g.MeasureString((T 'NON CONVERGÉE'), $fontB).Width
        }
        if (@(@($lvls.Values) | ForEach-Object { $_ } | Where-Object { $_.Verdict -eq 'mismatch' -or $_.Shape -eq 'mismatch' }).Count -gt 0) { $g.DrawString((T 'FORME NON CONFORME'), $fontB, $red, $tx, 8) }
        $ly = 30; $x2 = $L
        $g.FillEllipse($gray, $x2, $ly + 3, 7, 7); $s = (T 'mesure encadrée'); $g.DrawString($s, $font, $txt, $x2 + 11, $ly); $x2 += 24 + $g.MeasureString($s, $font).Width
        $g.DrawEllipse($grayPen, $x2, $ly + 3, 7, 7); $s = (T 'extrapolée'); $g.DrawString($s, $font, $txt, $x2 + 11, $ly); $x2 += 24 + $g.MeasureString($s, $font).Width
        $g.DrawRectangle($grayPen, $x2, $ly + 3, 7, 7); $s = (T 'plafonnée'); $g.DrawString($s, $font, $txt, $x2 + 11, $ly); $x2 += 24 + $g.MeasureString($s, $font).Width
        if (@($cvs | Where-Object { @($_.Kinds) -contains 'outlier' }).Count -gt 0) { $g.DrawLine($grayPen, $x2, $ly + 3, $x2 + 7, $ly + 10); $g.DrawLine($grayPen, $x2, $ly + 10, $x2 + 7, $ly + 3); $s = (T 'isolée'); $g.DrawString($s, $font, $txt, $x2 + 11, $ly); $x2 += 24 + $g.MeasureString($s, $font).Width }
        if (@($cvs | Where-Object { @($_.Breaks).Count -gt 0 }).Count -gt 0) { $dl = New-Object System.Drawing.Pen($script:Theme.Muted, 1); $dl.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash; $g.DrawLine($dl, $x2 + 3, $ly + 1, $x2 + 3, $ly + 12); $dl.Dispose(); $s = (T 'changement de sens'); $g.DrawString($s, $font, $txt, $x2 + 11, $ly); $x2 += 24 + $g.MeasureString($s, $font).Width }
        $g.DrawEllipse($flag, $x2 - 1, $ly + 1, 11, 11); $s = (T 'écart > 15 ns et > 3 incertitudes'); $g.DrawString($s, $font, $txt, $x2 + 13, $ly); $x2 += 26 + $g.MeasureString($s, $font).Width
        $g.FillRectangle($hatch, $x2, $ly + 2, 16, 10); $g.DrawRectangle($grid, $x2, $ly + 2, 16, 10); $g.DrawString((T 'au-delà des mesures'), $font, $txt, $x2 + 20, $ly)
        $ly = 50; $x2 = $L
        for ($k = 0; $k -lt $cvs.Count; $k++) {
            $cv = $cvs[$k]; $vals = @($cv.Values)
            $g.DrawLine($pens[$k], $x2, $ly + 7, $x2 + 22, $ly + 7)
            $s = if ($multi) { ((T "tête {0} : courbe {1}, de {2} à {3} ns") -f "$($cv.Head)", (Get-CurveModelName $cv.Model), "$($vals[0])", "$($vals[-1])") } else { (T 'précompensation retenue par cylindre') }
            $g.DrawString($s, $font, $txt, $x2 + 28, $ly)
            $x2 += 28 + $g.MeasureString($s, $font).Width + 24
        }
        if ($hasLevel) {
            # Troisieme ligne : courbe decalee, mesure du niveau, niveau par enregistrement
            $ly = 70; $x2 = $L
            $dl = New-Object System.Drawing.Pen($script:Theme.Muted, 1.6); $dl.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
            $g.DrawLine($dl, $x2, $ly + 7, $x2 + 22, $ly + 7); $dl.Dispose()
            $s = (T 'courbe décalée (dernière disquette)'); $g.DrawString($s, $font, $txt, $x2 + 28, $ly); $x2 += 28 + $g.MeasureString($s, $font).Width + 16
            $dm = @((New-Object System.Drawing.PointF([float]($x2 + 4), [float]($ly + 2))), (New-Object System.Drawing.PointF([float]($x2 + 9), [float]($ly + 7))), (New-Object System.Drawing.PointF([float]($x2 + 4), [float]($ly + 12))), (New-Object System.Drawing.PointF([float]($x2 - 1), [float]($ly + 7))))
            $g.DrawPolygon($grayPen, [System.Drawing.PointF[]]$dm)
            $s = (T 'mesure du niveau'); $g.DrawString($s, $font, $txt, $x2 + 13, $ly); $x2 += 13 + $g.MeasureString($s, $font).Width + 24
            $vn = @{ ok = (T 'conforme'); approx = (T 'approximative'); mismatch = (T 'NON CONFORME'); sat = (T 'non vérifiée, plafond atteint'); low = (T 'non vérifiée, plancher atteint'); few = (T 'non vérifiée, trop peu de cylindres mesurés') }
            $ri = 0
            foreach ($rec in @(@($lvls.Values) | ForEach-Object { $_ })) {
                if ($ri -gt 0) { $ly += 20; $x2 = $L }; $ri++
                $vk = if ([string]$rec.Shape -eq 'mismatch') { 'mismatch' } else { [string]$rec.Verdict }
                $vt = if ($vn.ContainsKey($vk)) { $vn[$vk] } else { $vk }
                $s = if ($null -eq $rec.Head) { (T "niveau de la dernière disquette : {0} ns ± {1}, forme {2} ({3})") -f ('{0:+0;-0;0}' -f [int]$rec.Delta), (Format-LevelNum $rec.SE), "$vt", "$($rec.Date)" }
                     else { (T "tête {0} : niveau {1} ns ± {2}, forme {3} ({4})") -f "$($rec.Head)", ('{0:+0;-0;0}' -f [int]$rec.Delta), (Format-LevelNum $rec.SE), "$vt", "$($rec.Date)" }
                $g.DrawString($s, $font, $txt, $x2, $ly); $x2 += $g.MeasureString($s, $font).Width + 20
            }
        }
    } finally {
        foreach ($o in @($font, $fontB, $grid, $axis, $err, $flag, $txt, $red, $gray, $grayPen, $hatch) + $pens + $dots + $hollow) { $o.Dispose() }
    }
}

function Show-PrecompCurve([string]$family, [bool]$preferHeads, $Owner = $null) {
    # Owner : fenetre proprietaire (carte Calibration de l Accueil : sa fenetre modale ; sinon la fenetre principale)
    $cvs = Get-FamilyCurves $family $preferHeads
    if ($cvs.Count -eq 0) { return }
    if ($script:CurveForm -and -not $script:CurveForm.IsDisposed) { $script:CurveForm.Close() }
    $script:CurveData = $cvs
    Set-CurveLevelData $cvs
    $f = New-Object System.Windows.Forms.Form
    $f.Text = if ($cvs.Count -gt 1) { ((T "Courbe de précompensation - {0}, une courbe par tête") -f "$($cvs[0].Family)") } else { ((T "Courbe de précompensation - {0}") -f "$($cvs[0].Family)") }
    $f.Size = New-Object System.Drawing.Size(920, 560); $f.MinimumSize = New-Object System.Drawing.Size(520, 360)
    $f.StartPosition = 'CenterParent'; $f.Icon = $form.Icon; $f.BackColor = [System.Drawing.Color]::White
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true; $tb.ReadOnly = $true; $tb.ScrollBars = 'Vertical'; $tb.Dock = 'Bottom'; $tb.Height = 170
    $tb.TabStop = $false; $tb.HideSelection = $true          # pas de texte tout selectionne a l ouverture
    $tb.Font = New-Object System.Drawing.Font('Consolas', 9.75); $tb.BackColor = $script:Theme.Page
    $tb.Text = Format-CurveTable $cvs
    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Dock = 'Fill'; $pb.BackColor = [System.Drawing.Color]::White
    $pb.Add_Paint({ Draw-PrecompCurve $_.Graphics $this.ClientSize })
    $pb.Add_Resize({ $this.Invalidate() })
    $f.Controls.Add($tb); $f.Controls.Add($pb); $pb.BringToFront()
    $script:CurveForm = $f
    if ($null -eq $Owner) { $Owner = $form }
    $f.Show($Owner)
    $tb.Select(0, 0); $pb.Focus() | Out-Null
}

function Update-CurveButton([string]$path) {
    # Bouton « Courbe » : actif si une courbe calibree (commune ou par tete) existe pour la famille de l image courante
    # Avant l affichage de la fenetre : aucun acces au fichier (racine reseau possible) ; le gestionnaire Shown recalcule.
    if (-not $script:UiReady) { $path = '' }
    $fam = 'std'
    $ext = if ($path) { [System.IO.Path]::GetExtension($path).ToLower() } else { '' }
    if (@('.scp', '.raw', '.kf', '.a2r', '.ctr') -contains $ext) { $script:CurveFamily = 'std'; $btnWCurve.Enabled = $false; return }
    if ($path -and (Test-Path -LiteralPath $path)) { try { $fam = Get-ImageFamily $path } catch { $fam = 'std' } }
    $script:CurveFamily = $fam
    $btnWCurve.Enabled = (Get-FamilyCurves $fam ([bool]$chkWSlow.Checked)).Count -gt 0
}

function Get-CurveCalc($cv) {
    # Version du calcul de calibration d une courbe ; courbe anterieure a ce champ : version de l application qui l a
    # faite (le calcul changeait alors avec chaque version) ; '' si aucune (anterieure a 12.1)
    if (-not $cv) { return '' }
    if ($cv.Calc) { return [string]$cv.Calc }
    return [string]$cv.Version
}

function Test-CurveCalcOk($cv) {
    # Courbe utilisable : faite avec le calcul actuel, ou conservee par l utilisateur pour ce calcul
    if (-not $cv) { return $false }
    return ((Get-CurveCalc $cv) -eq $script:CalibCalc -or [string]$cv.KeptFor -eq $script:CalibCalc)
}

function Get-CurveCalcText($cv, [switch]$Plain) {
    # « v12.3 » ; courbe d un autre calcul conservee : « v12.2, conservé (calcul actuel v12.3) »
    $c = Get-CurveCalc $cv
    $ct = if ($c) { "v$c" } else { (T 'antérieur à 12.1') }
    if ($Plain -or $c -eq $script:CalibCalc) { return $ct }
    return ((T "{0}, conservé (calcul actuel v{1})") -f "$ct", "$($script:CalibCalc)")
}

function Get-CurveMaxNs($cv) {
    # Borne des valeurs d une courbe : enregistree depuis le calcul 12.4 (CalHardNs au moment du calcul, champ MaxNs) ;
    # 300 ns pour une courbe qui ne l a pas (toutes les courbes jusqu au calcul 12.3, valeurs bornees a 300)
    if ($cv -and $null -ne $cv.MaxNs -and [int]$cv.MaxNs -gt 0) { return [int]$cv.MaxNs }
    return 300
}

function Test-CurveAtMax($cv) {
    # Courbe qui atteint la borne de son calcul : valeur a la borne avec un residu de verification positif (encore
    # sous-compensee), ou mesure plafonnee au-dessus (type 'cap' haut)
    if (-not $cv -or $null -eq $cv.Cyls) { return $false }
    $mx = Get-CurveMaxNs $cv; $v = @($cv.Values); $cs = @($cv.Cyls)
    $ks = @(); if ($null -ne $cv.Kinds) { $ks = @($cv.Kinds) }
    $ys = @(); if ($null -ne $cv.Ys) { $ys = @($cv.Ys) }
    $rs = @(); if ($null -ne $cv.Res) { $rs = @($cv.Res) }
    for ($i = 0; $i -lt $cs.Count; $i++) {
        $c = [int]$cs[$i]
        if ($i -lt $ks.Count -and $i -lt $ys.Count -and [string]$ks[$i] -eq 'cap' -and [double]$ys[$i] -ge $mx - 0.5) { return $true }
        if ($c -lt $v.Count -and [int]$v[$c] -ge $mx -and $i -lt $rs.Count -and $null -ne $rs[$i]) {
            $r = [double]$rs[$i]
            if (-not [double]::IsNaN($r) -and $r -gt 0) { return $true }
        }
    }
    return $false
}

function ConvertTo-CurveConfig($cv) {
    if (-not $cv) { return $null }
    $o = [ordered]@{ family = $cv.Family; head = $cv.Head; drive = $cv.Drive; date = $cv.Date; model = $cv.Model; spec = $cv.Spec; method = $cv.Method
                       values = @($cv.Values); cyls = @($cv.Cyls); ys = @($cv.Ys); sig = @($cv.Sig)
                       kinds = @($cv.Kinds); res = @(@($cv.Res) | ForEach-Object { if ($null -eq $_ -or [double]::IsNaN([double]$_)) { $null } else { [double]$_ } })
                       converged = $(if ($null -eq $cv.Converged) { $null } else { [bool]$cv.Converged }); maxx = $cv.MaxX; version = $cv.Version
                       algo = $cv.Algo; calc = $cv.Calc; keptFor = $cv.KeptFor; breaks = @($cv.Breaks); slope = $cv.Slope; bits = $cv.Bits; test = $cv.Test
                       maxNs = $(if ($null -ne $cv.MaxNs) { [int]$cv.MaxNs } else { $null }) }
    # Zone non reproductible (calcul 12.6) : enregistree seulement si elle existe
    $ct = @(@($cv.Contra) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
    if ($ct.Count -gt 0) { $o.contra = $ct }
    return $o
}

function ConvertTo-LevelConfig($r) {
    # Resultat d une calibration rapide (tableau plat dans la configuration, profondeur JSON limitee)
    if (-not $r) { return $null }
    return [ordered]@{ refKey = $r.RefKey; tag = $r.Tag; head = $r.Head; drive = $r.Drive; date = $r.Date; refDate = $r.RefDate; refTest = $r.RefTest
                       delta = $r.Delta; est = $r.Est; se = $r.SE; tau = $r.Tau; verdict = $r.Verdict; shape = $r.Shape; reasons = @($r.Reasons); conv = [bool]$r.Conv; passes = $r.Passes
                       cyls = @($r.Cyls); zs = @($r.Zs); ds = @($r.Ds); sigs = @($r.Sigs); kinds = @($r.Kinds); values = @($r.Values); spec = $r.Spec
                       sat = @($r.Sat); floor = @($r.Floor); hist = @(@($r.Hist) | ForEach-Object { [ordered]@{ date = $_.Date; delta = $_.Delta } })
                       version = $r.Version; algo = $r.Algo; levelAlgo = $r.LevelAlgo }
}

function ConvertFrom-LevelConfig($o) {
    if (-not $o) { return $null }
    try {
        $r = @{ RefKey = [string]$o.refKey; Tag = [string]$o.tag; Head = $(if ($null -ne $o.head) { [int]$o.head } else { $null }); Drive = [string]$o.drive
                Date = [string]$o.date; RefDate = [string]$o.refDate; RefTest = [string]$o.refTest; Delta = [int]$o.delta; Est = [double]$o.est; SE = [double]$o.se
                Tau = [double]$o.tau; Verdict = [string]$o.verdict; Shape = [string]$o.shape; Reasons = [string[]]@($o.reasons); Conv = [bool]$o.conv; Passes = [int]$o.passes
                Cyls = [int[]]@($o.cyls); Zs = [double[]]@($o.zs); Ds = [double[]]@($o.ds); Sigs = [double[]]@($o.sigs); Kinds = [string[]]@($o.kinds)
                Values = [int[]]@($o.values); Spec = [string]$o.spec; Sat = [int[]]@(@($o.sat) | Where-Object { $null -ne $_ }); Floor = [int[]]@(@($o.floor) | Where-Object { $null -ne $_ })
                Hist = @(@($o.hist) | Where-Object { $_ } | ForEach-Object { @{ Date = [string]$_.date; Delta = [int]$_.delta } })
                Version = [string]$o.version; Algo = [string]$o.algo; LevelAlgo = [string]$o.levelAlgo }
        if (-not $r.RefKey -or $r.Values.Count -lt 2 -or $r.Cyls.Count -ne $r.Zs.Count) { return $null }
        return $r
    } catch { return $null }
}

function ConvertFrom-CurveConfig($o) {
    if (-not $o) { return $null }
    try {
        $cv = @{ Family = [string]$o.family; Head = $(if ($null -ne $o.head) { [int]$o.head } else { $null }); Drive = [string]$o.drive; Date = [string]$o.date
                 Model = [string]$o.model; Spec = [string]$o.spec; Method = $(if ($o.method) { [string]$o.method } else { 'image' })
                 Values = [int[]]@($o.values); Cyls = [int[]]@($o.cyls); Ys = [double[]]@($o.ys); Sig = [double[]]@($o.sig)
                 Kinds = $null; Res = $null; Converged = $null; MaxX = 0; Version = [string]$o.version; Algo = [string]$o.algo
                 Calc = [string]$o.calc; KeptFor = [string]$o.keptFor
                 Breaks = [int[]]@(@($o.breaks) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ }) }
        if ($cv.Values.Count -lt 2 -or $cv.Cyls.Count -ne $cv.Ys.Count -or $cv.Cyls.Count -ne $cv.Sig.Count) { return $null }
        # Champs ajoutes en v11.9 : absents d une courbe plus ancienne
        if ($o.kinds -and @($o.kinds).Count -eq $cv.Cyls.Count) { $cv.Kinds = [string[]]@($o.kinds) }
        if ($o.res -and @($o.res).Count -eq $cv.Cyls.Count) { $cv.Res = [double[]]@(@($o.res) | ForEach-Object { if ($null -eq $_) { [double]::NaN } else { [double]$_ } }) }
        if ($null -ne $o.converged) { $cv.Converged = [bool]$o.converged }
        if ($o.maxx) { $cv.MaxX = [int]$o.maxx }
        # Champs de la calibration rapide (12.3) : absents d une courbe plus ancienne
        $cv.Slope = $(if ($null -ne $o.slope) { [double]$o.slope } else { $null })
        $cv.Bits = $(if ($o.bits) { [int]$o.bits } else { 0 })
        $cv.Test = [string]$o.test
        # Borne des valeurs (calcul 12.4) : absente d une courbe plus ancienne, qui vaut alors 300 (Get-CurveMaxNs)
        $cv.MaxNs = $(if ($null -ne $o.maxNs) { [int]$o.maxNs } else { $null })
        # Zone non reproductible, verifications contradictoires (calcul 12.6) : absente d une courbe plus ancienne
        $cv.Contra = [int[]]@(@($o.contra) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
        return $cv
    } catch { return $null }
}

function New-CalibUnit($head) {
    # Unite de calibration : les deux tetes ensemble (Head = $null, profil commun) ou une seule tete (ecriture lente)
    $prefix = if ($null -eq $head) { '' } else { ((T '[tête {0}] ') -f "$head") }
    return @{ Head = $head; Prefix = $prefix; Results = @{}; Est = @{}; Sig = @{}; Kind = @{}; Bracket = @{}; Warn = $null; Fit = $null; Slope = $null; Profile = ''; Verify = @{}
              Dense = @{}; VerifyList = $null; VerifyP = @{}; Outliers = @(); Own = @{}; Trend = @{}; VerifyPrev = @{}; Witness = @(); ReadLast = @{}; Writes = @{}; WitCand = 0; WitMin = 0
              EstPass = @{} }
}

function Get-PatternBits([string]$family, [string]$img) {
    # Cellules par piste du motif de test (voir New-CalibPattern) : densite de l image ; la calibration rapide compare
    # celle de l image a celle de sa reference
    $bits = 100000; $src = (T 'format à secteurs, 2 µs par cellule')
    $ext = [System.IO.Path]::GetExtension($img).ToLower()
    try {
        switch ($ext) {
            '.adf' {
                $len = (Get-Item -LiteralPath $img).Length
                if ($len % 22528 -eq 0 -and $len / 11264 -gt 84) { $bits = 202688; $src = (T 'ADF haute densité, horloge AmigaDOS de gw') }
                else { $bits = 101344; $src = (T 'ADF, horloge AmigaDOS de gw') }
            }
            '.ipf' { $info = Get-IpfCellInfo $img; if ($info.Bits -ge 50000 -and $info.Bits -le 260000) { $bits = [int]$info.Bits; $src = (T 'IPF, bits par piste de l''image') } }
            '.hfe' { $info = Get-HfeCellInfo $img; if ($info.Bits -ge 50000 -and $info.Bits -le 260000) { $bits = [int]$info.Bits; $src = (T 'HFE, bits par piste de l''image') } }
        }
    } catch { }
    if ($family -eq 'long' -and $bits -eq 100000) { $bits = 105820; $src = (T 'long track, 1,89 µs par cellule') }
    $bits -= $bits % 16
    return @{ Bits = $bits; Source = $src }
}

function New-CalibPattern([string]$family, [string]$img, [int]$nCyl) {
    # Motif de test independant du contenu de l image : HFE de donnees pseudo-aleatoires codees MFM (graine fixe, contenu
    # reproductible) a la DENSITE de l image. gw cale chaque piste ecrite sur un tour du lecteur (write.py, facteur
    # drive_ticks_per_rev / ticks_to_index) : la densite ne depend que du nombre de cellules par piste.
    #  ADF : celui du codec AmigaDOS de gw, horloge 14/7 093 790 s, (int(0,2 / horloge) + 31) & ~31 = 101 344 cellules
    #        (1 973,5 ns) en DD, 202 688 en HD ;
    #  IPF et HFE : bits par piste de l image (mediane ; HFE v3 : 400 x debit) ;
    #  autres formats a secteurs (IMG, ST...) : 100 000 cellules de 2 us ; long track illisible : 1,89 us.
    # Une piste pauvre en motifs (secteurs vides) reduit la mesure du decalage de pic a quelques dizaines d occurrences
    # (en-tetes, syncs) : resultat plus bruite et biaise de quelques ns (jusqu a ~15 ns en simulation). Ici toutes les
    # pistes ont la meme richesse de motifs : calibration reproductible, independante de l image.
    $pb = Get-PatternBits $family $img
    $bits = $pb.Bits; $src = $pb.Source
    $rate = [int][math]::Round($bits / 400.0)            # debit de l en-tete HFE (kbit/s) : un tour a 300 tr/min, indicatif
    $path = Join-Path $script:TempDir 'precomp-pattern.hfe'
    [CalibPattern]::WriteHfe($path, $nCyl, $bits, $rate, 20261014)
    return @{ Path = $path; Bits = $bits; Rate = $rate; CellNs = 200000000.0 / $bits; Source = $src }
}

function Get-CalibDriveArgs {
    # Options de lecteur de l ecriture reprises par la calibration, sans --format ni --diskdefs : le motif est un HFE
    return @(Get-WriteFormatArgs | Where-Object { $_ -notmatch '^--(format|diskdefs)=' })
}

function Get-CurveKeyLabel([string]$key) {
    # 'std' -> « Standard 2 us (commune) », 'long_h1' -> « Long track 1,89 us (tête 1) »
    $fam = if ($key -like 'long*') { 'long' } else { 'std' }
    $kind = if ($key -match '_h(\d)$') { (T "tête {0}") -f "$($Matches[1])" } else { (T 'commune') }
    return ("{0} ({1})" -f (Get-CalibFamilyName $fam), $kind)
}

function Resolve-OldCalibrations {
    # Calibrations d un autre calcul (Load-Config) : conserver ou recalibrer. Fermeture de la fenetre : decision remise au
    # prochain demarrage, calibrations gardees dans la configuration mais non utilisees d ici la.
    $o = $script:OldCalib
    if (-not $o) { return }
    $items = @(@($o.Curves.Keys) | ForEach-Object { $cv = $o.Curves[$_]; (T "{0} : calcul {1}, lecteur {2}, {3}") -f (Get-CurveKeyLabel $_), (Get-CurveCalcText $cv -Plain), "$($cv.Drive)", "$($cv.Date)" })
    $txt = ((T "Ces calibrations ont été faites avec un autre calcul de calibration que le calcul actuel (v{0}) :") -f "$($script:CalibCalc)") + "`n" + ((@($items) | ForEach-Object { "  - $_" }) -join "`n") + "`n`n" +
           (T "Recalibrer (conseillé) : ces calibrations sont abandonnées ; la prochaine écriture qui en a besoin recalibre le lecteur.`nConserver ces courbes : elles restent utilisées telles quelles ; la fenêtre Courbe et le journal rappellent leur calcul. Le calcul ayant changé, une nouvelle calibration peut donner une courbe plus juste. Une courbe antérieure à la 12.3 ne peut pas servir de référence au test rapide (pente et densité non enregistrées).`nFermer la fenêtre (ou Échap) : décision au prochain démarrage ; d'ici là, ces calibrations ne sont pas utilisées.")
    # Courbe a la borne de son calcul : conservee, elle y reste (le calcul actuel admet des valeurs plus hautes)
    $atMax = @(@($o.Curves.Keys) | Where-Object { Test-CurveAtMax $o.Curves[$_] })
    foreach ($mx in @($atMax | ForEach-Object { Get-CurveMaxNs $o.Curves[$_] } | Where-Object { $_ -lt $script:CalHardNs } | Sort-Object -Unique)) {
        $kl = @($atMax | Where-Object { (Get-CurveMaxNs $o.Curves[$_]) -eq $mx } | ForEach-Object { Get-CurveKeyLabel $_ })
        $ct = if ($kl.Count -gt 1) { (T "Courbes au plafond de {0} ns de leur calcul : {1}. Conservées, elles y restent ; le calcul actuel va jusqu'à {2} ns.") } else { (T "Courbe au plafond de {0} ns de son calcul : {1}. Conservée, elle y reste ; le calcul actuel va jusqu'à {2} ns.") }
        $txt += "`n`n" + ($ct -f "$mx", ($kl -join ', '), "$($script:CalHardNs)")
    }
    if ($o.Bak -and (Test-Path -LiteralPath $o.Bak)) { $txt += "`n`n" + ((T "Copie de la configuration d'avant ce choix : {0}") -f "$([System.IO.Path]::GetFileName([string]$o.Bak))") }
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmOldCalib'; $dlg.Text = (T 'Calibrations d''un autre calcul'); $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false; $dlg.BackColor = [System.Drawing.Color]::White
    $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $h = [System.Windows.Forms.TextRenderer]::MeasureText($txt, $dlg.Font, (New-Object System.Drawing.Size(620, 10000)), $tf).Height
    $dlg.ClientSize = New-Object System.Drawing.Size(660, ($h + 90))
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Name = 'lblOldText'; $lbl.AutoSize = $false; $lbl.UseMnemonic = $false; $lbl.Text = $txt
    $lbl.Location = New-Object System.Drawing.Point(20, 16); $lbl.Size = New-Object System.Drawing.Size(620, ($h + 8))
    $btnRedo = New-Object System.Windows.Forms.Button
    $btnRedo.Name = 'btnOldRedo'; $btnRedo.Text = (T 'Recalibrer (conseillé)'); $btnRedo.Size = New-Object System.Drawing.Size(200, 34)
    $btnRedo.Location = New-Object System.Drawing.Point(($dlg.ClientSize.Width - 20 - 200), ($h + 40)); $btnRedo.DialogResult = [System.Windows.Forms.DialogResult]::Abort
    $btnKeep = New-Object System.Windows.Forms.Button
    $btnKeep.Name = 'btnOldKeep'; $btnKeep.Text = (T 'Conserver ces courbes'); $btnKeep.Size = New-Object System.Drawing.Size(200, 34)
    $btnKeep.Location = New-Object System.Drawing.Point(($btnRedo.Left - 8 - 200), ($h + 40)); $btnKeep.DialogResult = [System.Windows.Forms.DialogResult]::OK
    Set-Btn $btnRedo '' 'primary'; Set-Btn $btnKeep '' 'normal'
    $dlg.Controls.AddRange(@($lbl, $btnRedo, $btnKeep)); $dlg.AcceptButton = $btnRedo; $dlg.ActiveControl = $btnRedo   # Entree : bouton conseille
    $dlg.KeyPreview = $true
    $dlg.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $_.Handled = $true; $this.Close() } })   # Echap : decision remise
    $dlg.Add_Shown({ $this.Activate(); try { [System.Media.SystemSounds]::Exclamation.Play() } catch { } })
    try { $dr = $dlg.ShowDialog($form) } finally { $dlg.Dispose() }
    $list = (@($o.Curves.Keys | ForEach-Object { (T "{0}, calcul {1}") -f (Get-CurveKeyLabel $_), (Get-CurveCalcText $o.Curves[$_] -Plain) })) -join ' ; '
    if ($dr -eq [System.Windows.Forms.DialogResult]::OK) {
        # Conservees pour le calcul actuel : reprises sans question aux demarrages suivants, calcul rappele a l usage
        foreach ($k in @($o.Curves.Keys)) { $cv = $o.Curves[$k]; $cv.KeptFor = $script:CalibCalc; $script:PrecompCurves[$k] = $cv }
        if ($o.Std) { $script:PrecompStd = $o.Std }
        if ($o.Long) { $script:PrecompLong = $o.Long }
        foreach ($k in @($o.Levels.Keys)) { $script:LevelShifts[$k] = $o.Levels[$k] }
        $script:OldCalib = $null
        if ($cmbWProfile.Text -ne (T 'Manuel')) {
            # Champs enregistres (faits avec ces courbes), puis recalcules pour l image choisie le cas echeant
            if ($null -ne $o.P0) { $txtWPrecomp.Text = $o.P0; $txtWPrecomp1.Text = $o.P1 }
            if ($txtWFile.Text) { Update-PrecompForImage $txtWFile.Text }
        }
        Append-Log ((T "Calibrations d'un autre calcul conservées à votre demande : {0}. Elles sont utilisées telles quelles (calcul actuel v{1}).") -f "$list", "$($script:CalibCalc)")
    } elseif ($dr -eq [System.Windows.Forms.DialogResult]::Abort) {
        $script:OldCalib = $null
        Append-Log ((T "Calibrations d'un autre calcul abandonnées : {0}. Courbes et profils calibrés remis aux valeurs d'origine ; le lecteur sera recalibré à la prochaine écriture qui en a besoin.") -f "$list")
    } else {
        Append-Log (T 'Calibrations d''un autre calcul : décision remise au prochain démarrage ; elles ne sont pas utilisées d''ici là.')
        return
    }
    Update-CurveButton $txtWFile.Text
    [void](Save-Config)
}

function Reset-CalibProfiles {
    # Efface toutes les calibrations : courbes communes et par tete des deux familles ; profils de famille remis aux
    # valeurs d origine. Refuse pendant une operation (calibration, ecriture, controle, sequence en cours).
    if (($script:GwProc -and -not $script:GwProc.HasExited) -or $script:Cal -or $script:Rep -or $script:Restore -or $script:Chain.Count -gt 0) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Opération en cours : attendre la fin de la calibration ou de l''écriture.'),(T 'Effacer les calibrations'),'OK','Warning'); return
    }
    $curves = @($script:CurveKeys | Where-Object { $script:PrecompCurves[$_] })
    # Calibrations d un autre calcul en attente du choix : effacees aussi
    $pend = @(if ($script:OldCalib) { @($script:OldCalib.Curves.Keys | Where-Object { -not $script:PrecompCurves[$_] }) })
    $curves = @(@($curves) + $pend | Sort-Object -Unique)
    $changed = ($script:PrecompStd -ne $script:PrecompStdDefault) -or ($script:PrecompLong -ne $script:PrecompLongDefault)
    if ($curves.Count -eq 0 -and -not $changed) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Aucune calibration enregistrée : les profils sont déjà ceux d''origine.'),(T 'Effacer les calibrations'),'OK','Information'); return
    }
    $list = if ($curves.Count -gt 0) { (@($curves | ForEach-Object { Get-CurveKeyLabel $_ }) -join ', ') } else { (T 'aucune') }
    $r = [System.Windows.Forms.MessageBox]::Show(
        ((T "Effacer toutes les calibrations de précompensation ?`n`nCourbes : {0}.`nProfils de famille remis aux valeurs d'origine : standard {1}, long track {2}.`n`nOpération irréversible. Le mode Auto applique ensuite ces profils ; une écriture rapide ou lente recalibre automatiquement.") -f "$list", "$($script:PrecompStdDefault)", "$($script:PrecompLongDefault)"),
        (T 'Effacer les calibrations'), 'YesNo', 'Warning')
    if ($r -ne 'Yes') { return }
    foreach ($k in $script:CurveKeys) { $script:PrecompCurves[$k] = $null }
    $script:LevelShifts = @{}; $script:OldCalib = $null
    $script:PrecompStd = $script:PrecompStdDefault; $script:PrecompLong = $script:PrecompLongDefault
    if ($script:CurveForm -and -not $script:CurveForm.IsDisposed) { $script:CurveForm.Close() }
    Update-PrecompForImage $txtWFile.Text
    $pbWCal.Visible = $false; $lblWCal.Visible = $true; $lblWCal.Text = (T 'Calibrations effacées.')
    Append-Log ((T "Calibrations effacées : {0} courbe(s) ({1}) ; profils standard et long track remis aux valeurs d'origine ({2} ; {3}).") -f "$($curves.Count)", "$list", "$($script:PrecompStdDefault)", "$($script:PrecompLongDefault)")
    [void](Save-Config)
}

function Get-CalibTrackMeasure($st) {
    # Decalage de pic d une piste (moyenne des tours mesurables) et son erreur-type (ns) ; $null si aucun tour mesurable.
    # Erreur-type : celle d Analyze (dispersion dans les quatre contextes) combinee sur les tours, a defaut la
    # dispersion entre tours.
    $vals = @(); $ses = @()
    foreach ($x in @($st)) {
        if ($null -eq $x -or $null -eq $x.Shift -or [double]::IsNaN([double]$x.Shift)) { continue }
        $vals += [double]$x.Shift
        $se = $x.ShiftSE
        if ($null -ne $se -and -not [double]::IsNaN([double]$se) -and [double]$se -gt 0) { $ses += [double]$se }
    }
    if ($vals.Count -eq 0) { return $null }
    $m = ($vals | Measure-Object -Average).Average
    $se = [double]::NaN
    if ($ses.Count -eq $vals.Count) { $q = 0.0; foreach ($s in $ses) { $q += $s * $s }; $se = [math]::Sqrt($q) / $vals.Count }
    elseif ($vals.Count -ge 2) { $q = 0.0; foreach ($v in $vals) { $q += ($v - $m) * ($v - $m) }; $se = [math]::Sqrt($q / ($vals.Count - 1)) / [math]::Sqrt($vals.Count) }
    return @{ Shift = $m; SE = $se }
}

function Add-CalibPoint($points, [int]$x, $m) {
    # Mesure (Shift, SE, Score) a la precomp x pour un cylindre ; deux mesures a la meme valeur sont moyennees
    if ($points.ContainsKey($x)) {
        $o = $points[$x]
        $se = if (-not [double]::IsNaN([double]$o.SE) -and -not [double]::IsNaN([double]$m.SE)) { [math]::Sqrt($o.SE * $o.SE + $m.SE * $m.SE) / 2 } else { [double]::NaN }
        $points[$x] = @{ Shift = ($o.Shift + $m.Shift) / 2; SE = $se; Score = $m.Score }
    } else { $points[$x] = $m }
}

function Limit-CalibZero([double]$x0, [double]$sig, [string]$kind, [double]$a, [bool]$own) {
    # Zero borne a 0..CalHardNs (« plafonnee » au-dela). Au-dela du plafond des passes de mesure (CalMaxNs), il garde son
    # type (encadre ou extrapole) : la verification ecrit la courbe a cette valeur et la mesure.
    $k = $kind; $v = $x0
    if ($v -lt 0) { $v = 0.0; $k = 'cap' }
    if ($v -gt $script:CalHardNs) { $v = [double]$script:CalHardNs; $k = 'cap' }
    return @{ Est = $v; Sig = [math]::Min(50.0, [math]::Max(1.0, $sig)); Kind = $k; Slope = $a; Own = $own }
}

function Get-CalibZero($points, [double]$pooledSlope) {
    # Precomp qui annule le decalage d un cylindre, d apres ses mesures (precomp -> Shift, SE) :
    #  - encadree : deux mesures de signes opposes -> interpolation lineaire entre elles (pente locale) ;
    #  - sinon extrapolee depuis les deux mesures les plus proches du zero (pente locale, ou pente commune si elle
    #    n est pas nettement negative) : la pente s aplatit au-dela de la plage mesuree, d ou une incertitude
    #    elargie de 25 % de la distance extrapolee ; si la mesure la plus proche est deja sur le zero (decalage dans
    #    2 erreurs-types), le zero est mesure et non extrapole : « encadree », sans l incertitude minimale de 5 ns ;
    #  - bornee a 0..CalHardNs : « plafonnee » (Limit-CalibZero).
    # Renvoie @{ Est; Sig; Kind = interp|extrap|cap; Slope; Own } ou $null (moins de deux mesures).
    $xs = @($points.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    if ($xs.Count -lt 2) { return $null }
    $s = @($xs | ForEach-Object { [double]$points[$_].Shift })
    $e = @($xs | ForEach-Object { $v = $points[$_].SE; if ($null -eq $v -or [double]::IsNaN([double]$v) -or [double]$v -le 0) { 2.0 } else { [double]$v } })
    for ($i = 0; $i -lt $xs.Count - 1; $i++) {
        if ($s[$i] -gt 0 -and $s[$i + 1] -le 0) {
            $a = ($s[$i + 1] - $s[$i]) / ($xs[$i + 1] - $xs[$i])
            $x0 = $xs[$i] + $s[$i] / (-$a)
            $sig = [math]::Sqrt($e[$i] * $e[$i] + $e[$i + 1] * $e[$i + 1]) / [math]::Abs($a)
            return (Limit-CalibZero $x0 $sig 'interp' $a ($a -lt -0.2))
        }
    }
    $under = $s[-1] -gt 0
    $j = if ($under) { $xs.Count - 2 } else { 0 }
    $a = ($s[$j + 1] - $s[$j]) / ($xs[$j + 1] - $xs[$j])
    $own = $a -lt -0.2
    if (-not $own) { $a = $pooledSlope }
    $xr = if ($under) { $xs[-1] } else { $xs[0] }
    $sr = if ($under) { $s[-1] } else { $s[0] }
    $er = if ($under) { $e[-1] } else { $e[0] }
    $x0 = $xr + $sr / (-$a)
    $sig = [math]::Sqrt([math]::Pow($er / [math]::Abs($a), 2) + [math]::Pow(0.25 * [math]::Abs($x0 - $xr), 2))
    if ([math]::Abs($sr) -le 2.0 * $er) { return (Limit-CalibZero $x0 $sig 'interp' $a $own) }
    return (Limit-CalibZero $x0 ([math]::Max(5.0, $sig)) 'extrap' $a $own)
}

function Get-BracketSpec($bracket) {
    # Profil --precomp d une passe d encadrement : une entree c=ns par cylindre a encadrer (seuls ceux-la sont ecrits)
    return ((@($bracket.Keys | ForEach-Object { [int]$_ } | Sort-Object) | ForEach-Object { "$_=$($bracket[$_])" }) -join ':')
}

function Get-InterpEst($u, [int]$c) {
    # Estimation interpolee lineairement entre les cylindres estimes qui encadrent c, cible d une passe de mesure : bornee
    # a 0..CalMaxNs (plafond des passes de mesure)
    $cs = @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    if ($cs.Count -eq 0) { return 100 }
    $v = if ($c -le $cs[0]) { [double]$u.Est[$cs[0]] } elseif ($c -ge $cs[-1]) { [double]$u.Est[$cs[-1]] } else {
        $j = 0; while ($cs[$j + 1] -lt $c) { $j++ }
        [double]$u.Est[$cs[$j]] + ($c - $cs[$j]) / [double]($cs[$j + 1] - $cs[$j]) * ([double]$u.Est[$cs[$j + 1]] - [double]$u.Est[$cs[$j]])
    }
    return [int][math]::Max(0, [math]::Min($script:CalMaxNs, [math]::Round($v, 0)))
}

function Start-CalibDensify($cal) {
    # Test standard : une chute du besoin entre deux cylindres testes voisins (plus de 15 ns et de 3 incertitudes), ou
    # une estimation loin de la courbe provisoire, declenche des mesures complementaires sur les cylindres intermediaires
    # (chute : tous ceux entre les deux, plus 2 de part et d autre ; ecart : c-4, c-2, c-1, c+1, c+2, c+4), en deux
    # passes : A a la valeur interpolee, B de l autre cote du zero (pente commune). Les cylindres qui bordent la zone
    # sont remesures a leur estimation. 2 zones et 30 cylindres au plus. Renvoie $true si une passe est lancee.
    if ($cal.Mode -eq 'fine' -or $cal.Densified) { return $false }
    $zones = New-Object System.Collections.Generic.List[object]
    foreach ($u in $cal.Units) {
        $cs = @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
        if ($cs.Count -lt 3) { continue }
        for ($i = 0; $i -lt $cs.Count - 1; $i++) {
            $ci = $cs[$i]; $cj = $cs[$i + 1]
            $thr = [math]::Max(15.0, 3.0 * [math]::Sqrt([double]$u.Sig[$ci] * [double]$u.Sig[$ci] + [double]$u.Sig[$cj] * [double]$u.Sig[$cj]))
            $drop = [double]$u.Est[$ci] - [double]$u.Est[$cj]
            if ($drop -gt $thr -and $cj - $ci -gt 1) { $zones.Add(@{ Lo = $ci; Hi = $cj; Kind = 'drop'; Sev = $drop }) }
        }
        $fit = Fit-PrecompCurve $u.Est $u.Sig $cal.MaxCyl $u.Kind $false
        if ($fit) {
            foreach ($c in $cs) {
                $dv = $fit.Values[$c] - [double]$u.Est[$c]
                if ([math]::Abs($dv) -gt [math]::Max(15.0, 3.0 * [double]$u.Sig[$c])) { $zones.Add(@{ Lo = $c; Hi = $c; Kind = 'dev'; Sev = [math]::Abs($dv) }) }
            }
        }
    }
    if ($zones.Count -eq 0) { return $false }
    $tested = @{}; foreach ($c in $cal.Cyls) { $tested[[int]$c] = $true }
    $new = @{}; $bounds = @{}; $kept = 0; $skipped = @(); $names = @(); $drops = @()
    # Chutes d abord (par severite), puis ecarts ; un ecart deja couvert par une chute retenue (a 2 cylindres pres)
    # ne compte pas : il ne doit pas prendre la place d une autre chute
    foreach ($z in @($zones | Sort-Object @{ Expression = { [int]($_.Kind -ne 'drop') } }, @{ Expression = { -[double]$_.Sev } })) {
        if ($z.Kind -ne 'drop' -and @($drops | Where-Object { [int]$z.Lo -ge [int]$_.Lo - 2 -and [int]$z.Lo -le [int]$_.Hi + 2 }).Count -gt 0) { continue }
        # (parentheses : la virgule est prioritaire sur l addition en PowerShell)
        $cand = if ($z.Kind -eq 'drop') { @(@(([int]$z.Lo + 1)..([int]$z.Hi - 1)) + @(([int]$z.Lo - 2), ([int]$z.Hi + 2))) } else { @(([int]$z.Lo - 4), ([int]$z.Lo - 2), ([int]$z.Lo - 1), ([int]$z.Lo + 1), ([int]$z.Lo + 2), ([int]$z.Lo + 4)) }
        $add = @($cand | Where-Object { $_ -ge 0 -and $_ -le $cal.MaxCyl -and -not $tested.ContainsKey([int]$_) -and -not $new.ContainsKey([int]$_) })
        $nm = if ($z.Kind -eq 'drop') { (T "chute entre c{0} et c{1}") -f "$($z.Lo)", "$($z.Hi)" } else { (T "écart à c{0}") -f "$($z.Lo)" }
        if ($add.Count -eq 0) { continue }                                   # zone deja couverte (autre tete)
        if ($kept -ge 2 -or $new.Count + $add.Count -gt 30) { $skipped += $nm; continue }
        foreach ($c in $add) { $new[[int]$c] = $true }
        $bounds[[int]$z.Lo] = $true; $bounds[[int]$z.Hi] = $true
        $kept++; $names += $nm
        if ($z.Kind -eq 'drop') { $drops += $z }
    }
    foreach ($s in $skipped) { Append-Log ((T "Calibration : zone {0} non complétée (2 zones et 30 cylindres au plus) : test fin conseillé.") -f "$s") }
    if ($new.Count -eq 0) { return $false }
    $newL = [int[]]@($new.Keys | Sort-Object)
    $bndL = [int[]]@($bounds.Keys | Where-Object { $tested.ContainsKey([int]$_) } | Sort-Object)
    $cal.Densified = $true; $cal.DenseNew = $newL; $cal.DensePass = 'A'
    $cal.Cyls = [int[]]@(@($cal.Cyls) + @($newL) | Sort-Object -Unique)
    $cal.CylList = Format-CylList $cal.Cyls; $cal.TSpec = "c=$($cal.CylList):h=0-1"
    foreach ($u in $cal.Units) {
        foreach ($c in $newL) { $u.Results[$c] = @{} }
        $u.Dense = @{}
        foreach ($c in $newL) { $u.Dense[$c] = Get-InterpEst $u $c }
        foreach ($c in $bndL) { if ($u.Est.ContainsKey($c)) { $u.Dense[$c] = [int][math]::Max(0, [math]::Min($script:CalMaxNs, [math]::Round([double]$u.Est[$c], 0))) } }
    }
    Append-Log ((T "Calibration : anomalie de la courbe ({0}) : mesures complémentaires des cylindres {1}, en deux passes, pour distinguer une marche, une rampe ou un point isolé.") -f "$($names -join ' ; ')", "$(Format-CylList $newL)")
    $cal.Stage = 'densify'; $cal.TotalPasses += 2
    New-CalibPass
    return $true
}

function Set-CalibDenseB($cal) {
    # Passe B : chaque cylindre ajoute est ecrit de l autre cote du zero predit par sa mesure A (pente commune),
    # a 15 ns au moins de la valeur A ; les cylindres qui bordent la zone sont remesures a la meme valeur (repetition)
    foreach ($u in $cal.Units) {
        $slope = if ($null -ne $u.Slope -and [double]$u.Slope -lt -0.2) { [double]$u.Slope } else { -2.0 }
        $nd = @{}
        foreach ($c in @($u.Dense.Keys | ForEach-Object { [int]$_ })) {
            if ($cal.DenseNew -notcontains $c) { $nd[$c] = [int]$u.Dense[$c]; continue }
            $x1 = [int]$u.Dense[$c]; $pts = $u.Results[$c]
            if (-not $pts -or -not $pts.ContainsKey($x1)) { continue }
            $z = $x1 + [double]$pts[$x1].Shift / (-$slope)
            $dir = if ($z -ge $x1) { 1 } else { -1 }
            $x2 = [int][math]::Round($z + 15 * $dir)
            if ([math]::Abs($x2 - $x1) -lt 15) { $x2 = $x1 + 15 * $dir }
            $x2 = [int][math]::Max(0, [math]::Min($script:CalMaxNs, $x2))
            if ($x2 -eq $x1) { $x2 = if ($x1 -ge 15) { $x1 - 15 } else { $x1 + 15 } }
            $nd[$c] = $x2
        }
        $u.Dense = $nd
    }
}

function Get-TrendEstimates($u, [int]$maxCyl, [bool]$dense) {
    # Zero d un cylindre encore sous-compense au plafond des passes de mesure (CalMaxNs), extrapole de ses mesures : garde
    # tel quel s il est proche (incertitude <= CalTrendSig) avec une pente propre. Sinon combine (moyenne ponderee par
    # l inverse des variances) avec la tendance de la courbe : droite ponderee de pente >= 0 sur les CalTrendN derniers
    # cylindres fiables (incertitude <= 6 ns, ni plafonnes, ni isoles, ni eux-memes combines) qui le precedent dans le meme
    # segment croissant, a CalTrendSpan cylindres au plus (3 fois plus en test standard). Incertitude de la tendance :
    # erreur-type de la prediction (elargie si les points s ecartent de la droite) et 25 % de la hausse extrapolee depuis
    # le dernier cylindre fiable (meme regle qu une extrapolation propre).
    # Copies : u.Est, u.Sig et u.Kind restent la mesure propre (controle Dev, journal, courbe enregistree) ; type
    # transitoire 'trend' (non fiable pour SegFit), jamais enregistre. Renvoie @{ Est; Sig; Kind; Info (c -> detail) }.
    $est = @{}; $sig = @{}; $kind = @{}; $info = @{}
    foreach ($k in @($u.Est.Keys)) { $est[[int]$k] = [double]$u.Est[$k]; $sig[[int]$k] = [double]$u.Sig[$k]; $kind[[int]$k] = [string]$u.Kind[$k] }
    $res = @{ Est = $est; Sig = $sig; Kind = $kind; Info = $info }
    $cand = @($est.Keys | ForEach-Object { [int]$_ } | Where-Object { $kind[$_] -eq 'extrap' -and $est[$_] -gt $script:CalMaxNs -and ($sig[$_] -gt $script:CalTrendSig -or ($u.Own -and $u.Own.ContainsKey($_) -and -not $u.Own[$_])) } | Sort-Object)
    if ($cand.Count -eq 0) { return $res }                      # cas courant : aucune combinaison
    $f0 = Fit-PrecompCurve $u.Est $u.Sig $maxCyl $u.Kind $dense
    $segs = @(if ($f0 -and $f0.Segs) { @($f0.Segs) } else { @{ Lo = 0; Hi = $maxCyl; Dir = 1 } })
    $outl = @{}; if ($f0) { foreach ($c in @($f0.Outliers)) { if ($null -ne $c) { $outl[[int]$c] = $true } } }
    $cs = @($est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    $span = if ($dense) { [int]$script:CalTrendSpan } else { 3 * [int]$script:CalTrendSpan }
    $minRef = if ($dense) { 3 } else { 2 }
    foreach ($c in $cand) {
        $sg = @($segs | Where-Object { $c -ge [int]$_.Lo -and $c -le [int]$_.Hi })
        if ($sg.Count -eq 0 -or [int]$sg[0].Dir -ne 1) { continue }        # segment decroissant : pas de tendance montante
        $lo = [math]::Max([int]$sg[0].Lo, $c - $span)
        $ref = @($cs | Where-Object { $_ -lt $c -and $_ -ge $lo -and -not $outl.ContainsKey($_) -and $kind[$_] -ne 'cap' -and $kind[$_] -ne 'trend' -and [double]$u.Sig[$_] -le 6.0 } | Select-Object -Last ([int]$script:CalTrendN))
        if ($ref.Count -lt $minRef) { continue }
        $sw = 0.0; $sx = 0.0; $sy = 0.0
        foreach ($r in $ref) { $w = 1.0 / [math]::Pow([math]::Max(1.0, [double]$u.Sig[$r]), 2); $sw += $w; $sx += $w * $r; $sy += $w * [double]$u.Est[$r] }
        $mx = $sx / $sw; $my = $sy / $sw; $sxx = 0.0; $sxy = 0.0
        foreach ($r in $ref) { $w = 1.0 / [math]::Pow([math]::Max(1.0, [double]$u.Sig[$r]), 2); $sxx += $w * ($r - $mx) * ($r - $mx); $sxy += $w * ($r - $mx) * ([double]$u.Est[$r] - $my) }
        if ($sxx -le 0) { continue }
        $b = [math]::Max(0.0, $sxy / $sxx); $a = $my - $b * $mx
        $chi = 0.0; foreach ($r in $ref) { $w = 1.0 / [math]::Pow([math]::Max(1.0, [double]$u.Sig[$r]), 2); $chi += $w * [math]::Pow([double]$u.Est[$r] - ($a + $b * $r), 2) }
        $chi = $chi / [math]::Max(1, $ref.Count - 2)
        $pred = $a + $b * $c
        $rise = [math]::Max(0.0, $pred - [double]$u.Est[$ref[-1]])
        $sT = [math]::Max(1.0, [math]::Sqrt((1.0 / $sw + [math]::Pow($c - $mx, 2) / $sxx) * [math]::Max(1.0, $chi) + [math]::Pow(0.25 * $rise, 2)))
        $wo = 1.0 / [math]::Pow([math]::Max(1.0, $sig[$c]), 2); $wt = 1.0 / ($sT * $sT)
        # Plancher : la plus forte precomp ecrite au cylindre, encore sous-compensee (zero extrapole au-dela)
        $xr = 0.0
        if ($u.Results -and $u.Results.ContainsKey($c) -and $u.Results[$c].Count -gt 0) { $xr = [double](@($u.Results[$c].Keys | ForEach-Object { [int]$_ }) | Measure-Object -Maximum).Maximum }
        $v = [math]::Max($xr, [math]::Min([double]$script:CalHardNs, ($wo * $est[$c] + $wt * $pred) / ($wo + $wt))); $sv = 1.0 / [math]::Sqrt($wo + $wt)
        $info[$c] = @{ Own = $est[$c]; OwnSig = $sig[$c]; Trend = $pred; TrendSig = $sT; Est = $v; Sig = $sv }
        $est[$c] = $v; $sig[$c] = $sv; $kind[$c] = 'trend'
    }
    return $res
}

function Start-CalibFit($cal) {
    # Courbe par unite d apres les estimations (points isoles ecartes sur des donnees denses ; zero extrapole incertain
    # au-dela du plafond des passes de mesure combine avec la tendance de la courbe, Get-TrendEstimates), puis premiere
    # passe de verification de tous les cylindres estimes
    $dense = ($cal.Mode -eq 'fine' -or [bool]$cal.Densified)
    foreach ($u in $cal.Units) {
        # Estimation des seules passes de mesure (apres encadrement et mesures complementaires, avant toute verification et
        # sans la tendance) : troisieme mesure des verifications contradictoires (Get-VerifyDrift)
        $u.EstPass = @{}; foreach ($k in @($u.Est.Keys)) { $u.EstPass[[int]$k] = [double]$u.Est[$k] }
        $tr = Get-TrendEstimates $u $cal.MaxCyl $dense
        $u.Trend = $tr.Info
        if ($tr.Info.Count -gt 0) {
            $tt = (@($tr.Info.Keys | Sort-Object | ForEach-Object { $ti = $tr.Info[$_]; (T "c{0} : extrapolation {1} ± {2} ns, tendance {3} ± {4} ns, retenu {5} ns") -f "$_", (Format-LevelNum $ti.Own), (Format-LevelNum $ti.OwnSig), (Format-LevelNum $ti.Trend), (Format-LevelNum $ti.TrendSig), (Format-LevelNum $ti.Est) })) -join ' ; '
            Append-Log ($u.Prefix + ((T "Besoin au-delà de {0} ns, zéro extrapolé incertain (loin des mesures ou sans pente propre) : combiné avec la tendance de la courbe ({1}). La vérification écrit la courbe à ces cylindres et la mesure.") -f "$($script:CalMaxNs)", "$tt"))
            $u.Fit = Fit-PrecompCurve $tr.Est $tr.Sig $cal.MaxCyl $tr.Kind $dense
        } else { $u.Fit = Fit-PrecompCurve $u.Est $u.Sig $cal.MaxCyl $u.Kind $dense }
        $u.Outliers = @($u.Fit.Outliers | ForEach-Object { [int]$_ } | Sort-Object)
        foreach ($c in $u.Outliers) { if ($u.Kind.ContainsKey($c)) { $u.Kind[$c] = 'outlier' } }
        $u.Profile = Build-CurveProfile $u.Fit.Values
        Append-Log ($u.Prefix + ((T "Courbe ajustée : {0} (écart réduit {1}), de {2} ns au cylindre 0 à {3} ns au cylindre {4} ; profil : {5}") -f (Get-CurveModelName $u.Fit.Model), "$([math]::Round($u.Fit.Chi, 2))", "$($u.Fit.Values[0])", "$($u.Fit.Values[-1])", "$($cal.MaxCyl)", "$($u.Profile)"))
        if ($u.Outliers.Count -gt 0) { Append-Log ($u.Prefix + ((T "Point(s) isolé(s) écarté(s) de la courbe : {0} : écart avec les cylindres voisins, défaut ponctuel probable de la disquette de calibration, non suivi.") -f (($u.Outliers | ForEach-Object { "c$_" }) -join ', '))) }
        $u.Verify = @{}; $u.VerifyP = @{}; $u.VerifyList = $null; $u.VerifyPrev = @{}; $u.Witness = @(); $u.ReadLast = @{}; $u.WitCand = 0; $u.WitMin = 0
    }
    $cal.Stage = 'verify'; $cal.VerifyCount = 1
    New-CalibPass
}

function Get-ResidualTol($meas) {
    # Tolerance du residu d une verification : CalResidual, elargie a 3 erreurs-types quand la mesure est plus bruitee
    # (un residu dans le bruit ne justifie ni une correction ni une alerte de non-convergence)
    $se = [double]::NaN
    if ($null -ne $meas -and $null -ne $meas.SE) { $se = [double]$meas.SE }
    if ([double]::IsNaN($se)) { return [double]$script:CalResidual }
    return [math]::Max([double]$script:CalResidual, 3.0 * $se)
}

function Add-DriftWitnesses($u) {
    # Verification ciblee : des cylindres non modifies sont reecrits a leur valeur inchangee et relus avec les cylindres
    # modifies. Leur valeur ecrite ne change pas : l ecart de leur residu d une verification a l autre mesure directement la
    # derive du lecteur entre les deux passes (temperature, contact de la tete), sans dependre de la pente. Repartis sur la
    # piste, sans condition sur leur residu (pas de biais de selection), et seulement s ils ne depassent pas le nombre
    # maximal d ecritures par piste que la calibration atteint de toute facon.
    $u.Witness = @(); $u.WitCand = 0
    # Minimum de temoins : 4 en test standard (peu de cylindres non modifies), sinon CalDriftMinWit ; garde avec l unite
    $u.WitMin = if ($script:Cal -and $script:Cal.Mode -ne 'fine' -and -not [bool]$script:Cal.Densified) { 4 } else { [int]$script:CalDriftMinWit }
    if (@($u.VerifyList).Count -eq 0) { return }
    $vals = @($u.Fit.Values)
    $cand = @($u.Verify.Keys | ForEach-Object { [int]$_ } | Where-Object {
        @($u.VerifyList) -notcontains $_ -and @($u.Outliers) -notcontains $_ -and $u.VerifyP.ContainsKey($_) -and $_ -lt $vals.Count -and
        [int]$vals[$_] -eq [int]$u.VerifyP[$_] -and [int]$vals[$_] -gt 0 -and [int]$vals[$_] -lt $script:CalHardNs } | Sort-Object)
    if ($null -ne $u.Writes -and $u.Writes.Count -gt 0) {
        $wmax = [int](@($u.Writes.Values) | Measure-Object -Maximum).Maximum
        $vmax = [int](@(@($u.VerifyList) | ForEach-Object { 1 + [int]$u.Writes[[int]$_] }) | Measure-Object -Maximum).Maximum
        $lim = [math]::Max($wmax, $vmax)
        $low = @($cand | Where-Object { 1 + [int]$u.Writes[[int]$_] -le $lim })
        # Repli : une ecriture de plus sur quelques pistes plutot qu aucune mesure de derive
        if ($low.Count -ge [int]$u.WitMin) { $cand = $low }
    }
    $u.WitCand = $cand.Count
    $k = [math]::Min([int]$script:CalDriftWitness, $cand.Count)
    if ($k -lt [int]$u.WitMin) { return }
    $w = @(for ($i = 0; $i -lt $k; $i++) { [int]$cand[[int][math]::Floor(($i + 0.5) * $cand.Count / $k)] })
    $u.Witness = $w
    $u.VerifyList = @(@($u.VerifyList) + $w | Sort-Object -Unique)
}

function Get-VerifyDrift($u) {
    # Derive du lecteur entre les deux dernieres verifications, mesuree sur les temoins (meme valeur ecrite les deux fois) :
    # D = mediane de (residu nouveau - residu precedent), incertitude E = 1,2533 S / racine du nombre de temoins. Les residus
    # des cylindres relus a la derniere verification sont juges sans ce decalage (ramenes au repere de la verification
    # precedente, sur laquelle la courbe a ete corrigee).
    # Verifications contradictoires (Contra) : cylindre corrige (p1 -> p2) dont le residu de la derniere verification r2'
    # (derive D retiree, 0 si non mesuree) est hors de sa tolerance du cote de p1, et dont le residu de la verification
    # precedente r1 est du cote de p2 (hors de sa tolerance), ou dans sa tolerance (cylindre deplace avec ses voisins par le
    # lissage, sans que la verification 1 l ait demande) : les deux verifications placent le besoin entre p1 et p2 mais leurs
    # estimations se contredisent. Valeur retenue Z : mediane de l estimation des passes de mesure (EstPass) et des
    # zeros des deux verifications (pente commune), moyenne des deux zeros sans EstPass, bornee a [min(p1,p2) ; max(p1,p2)] ;
    # E = ecart entre les deux zeros. Toujours traite ainsi, quelle que soit la longueur de la suite (Set-VerifyContra).
    # Ecart minimal : un candidat dont E ne depasse pas la tolerance de la verification 1 convertie en ns de precomp par la
    # meme pente (CalContraMinNs si elle n est pas convertible) est en accord. Zone : suite de candidats voisins (comme les
    # suites ci-dessous) dont un au moins depasse ce seuil, candidats en accord compris ; une suite dont tous les candidats
    # sont en accord (cylindre isole, typiquement) n est pas une contradiction : jugee par les regles qui suivent (non
    # reproductible, ecart local ou non converge), residu enregistre.
    # Non reproductible : temoin dont l ecart s eloigne de D de plus de max(3 tolerances ; 4 S) ; cylindre corrige dont le
    # residu, derive retiree, va a l inverse du changement prevu par la pente commune de plus de cette limite, ou au-dela du
    # changement prevu entier de plus de cette limite alors que r2' reste hors de sa tolerance (hors contradiction : r1 a
    # l oppose de la correction, comme le c81 de U5). Une reponse
    # plus faible que prevu, ou nulle, n est pas une non-reproductibilite : le cylindre est juge normalement. Une suite d au
    # moins 3 candidats voisins (2 cylindres au plus, ou consecutifs parmi les cylindres relus) de meme sens est un ecart
    # systematique, jugee normalement elle aussi. DC / NC : ecart median des cylindres corriges a leur prediction (derive
    # comprise), a comparer a D (les temoins isoles derivent-ils comme les blocs corriges ?). Sys : candidats d une suite
    # systematique ; un temoin qui en fait partie est juge sur sa relecture, derive retiree, et non sur sa mesure precedente.
    $res = @{ Use = $false; D = 0.0; S = [double]::NaN; SRaw = [double]::NaN; E = [double]::NaN; NW = 0; NC = 0; DC = [double]::NaN; NonRepro = @{}; Sys = @{}; Contra = @{} }
    if (-not $u.VerifyPrev -or $u.VerifyPrev.Count -eq 0) { return $res }
    $sl = if ($null -ne $u.Slope -and [double]$u.Slope -lt -0.2) { [double]$u.Slope } else { -2.0 }
    $wit = @(); $cor = @()
    foreach ($k in @($u.VerifyPrev.Keys)) {
        $c = [int]$k
        if (-not $u.Verify.ContainsKey($c) -or -not $u.VerifyP.ContainsKey($c) -or @($u.Outliers) -contains $c) { continue }
        $p1 = [double]$u.VerifyPrev[$c].P; $r1 = [double]$u.VerifyPrev[$c].Shift
        $p2 = [double]$u.VerifyP[$c]; $r2 = [double]$u.Verify[$c].Shift
        if ([double]::IsNaN($r1) -or [double]::IsNaN($r2)) { continue }
        $o = @{ C = $c; Obs = $r2 - $r1; Exp = $sl * ($p2 - $p1); P1 = $p1; R1 = $r1; P2 = $p2; R2 = $r2 }
        if ($p2 -eq $p1) { $wit += ,$o } else { $cor += ,$o }
    }
    $res.NW = $wit.Count
    $wm = if ($u.WitMin) { [int]$u.WitMin } else { [int]$script:CalDriftMinWit }
    $d = 0.0; $s = 1.0
    if ($wit.Count -ge $wm) {
        $dw = @($wit | ForEach-Object { [double]$_.Obs })
        $d = [double](Get-Median $dw)
        $sr = 1.4826 * [double](Get-Median @($dw | ForEach-Object { [math]::Abs($_ - $d) }))
        $s = [math]::Max(1.0, $sr)
        $res.Use = $true; $res.D = $d; $res.S = $s; $res.SRaw = $sr; $res.E = 1.2533 * $s / [math]::Sqrt([double]$wit.Count)
    }
    # Verifications contradictoires (derive retiree si elle est mesuree) : candidats, puis zones
    $cnd = @{}
    foreach ($o in $cor) {
        $c = [int]$o.C; $p1 = [double]$o.P1; $p2 = [double]$o.P2; $r1 = [double]$o.R1; $r2 = [double]$o.R2 - $d
        $dir = [math]::Sign($p2 - $p1)
        # r2' hors tolerance du cote de p1 ; r1 hors tolerance : du cote de p2 (dans sa tolerance : tout signe)
        if ([math]::Sign($r2) -ne -$dir -or [math]::Abs($r2) -le (Get-ResidualTol $u.Verify[$c])) { continue }
        if ([math]::Abs($r1) -gt (Get-ResidualTol $u.VerifyPrev[$c].Meas) -and [math]::Sign($r1) -ne $dir) { continue }
        $z1 = $p1 - $r1 / $sl; $z2 = $p2 - $r2 / $sl
        # Ecart minimal : zeros a moins de la tolerance de la verification 1 (ns de precomp, pente sl comme E) : accord
        $tp = [double](Get-ResidualTol $u.VerifyPrev[$c].Meas) / [math]::Abs($sl)
        if ([double]::IsNaN($tp) -or [double]::IsInfinity($tp) -or $tp -le 0) { $tp = [double]$script:CalContraMinNs }
        $zp = $null
        if ($u.EstPass -and $u.EstPass.ContainsKey($c) -and -not [double]::IsNaN([double]$u.EstPass[$c])) { $zp = [double]$u.EstPass[$c] }
        $zm = if ($null -ne $zp) { [double](Get-Median @($zp, $z1, $z2)) } else { ($z1 + $z2) / 2.0 }
        $zm = [math]::Max([math]::Min($p1, $p2), [math]::Min([math]::Max($p1, $p2), $zm))
        $zc = [int][math]::Max(0, [math]::Min($script:CalHardNs, [math]::Round($zm, 0)))
        $cnd[$c] = @{ Z = $zc; Z1 = $z1; Z2 = $z2; ZP = $zp; E = [math]::Abs($z2 - $z1); P1 = $p1; P2 = $p2; Low = ([math]::Abs($z2 - $z1) -le $tp) }
    }
    # Zone : suite de candidats voisins (2 cylindres au plus, ou consecutifs parmi les cylindres relus) dont un au moins
    # depasse l ecart minimal ; une suite dont tous les candidats sont en accord n est pas une contradiction
    $rl = @(@($wit + $cor) | ForEach-Object { [int]$_.C } | Sort-Object)
    $kc = @($cnd.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    $ia = 0
    while ($ia -lt $kc.Count) {
        $ja = $ia
        while ($ja -lt $kc.Count - 1 -and (($kc[$ja + 1] - $kc[$ja] -le 2) -or ([array]::IndexOf($rl, $kc[$ja + 1]) - [array]::IndexOf($rl, $kc[$ja]) -eq 1))) { $ja++ }
        $hi = $false; for ($q = $ia; $q -le $ja; $q++) { if (-not $cnd[$kc[$q]].Low) { $hi = $true } }
        if ($hi) { for ($q = $ia; $q -le $ja; $q++) { $ce = $cnd[$kc[$q]]; $res.Contra[$kc[$q]] = @{ Z = $ce.Z; Z1 = $ce.Z1; Z2 = $ce.Z2; ZP = $ce.ZP; E = $ce.E; P1 = $ce.P1; P2 = $ce.P2 } } }
        $ia = $ja + 1
    }
    if (-not $res.Use) { return $res }
    $lim = [math]::Max(3.0 * [double]$script:CalResidual, 4.0 * $s)
    $cand = @{}
    foreach ($o in @($wit + $cor)) {
        if ($res.Contra.ContainsKey([int]$o.C)) { continue }                 # verifications contradictoires : mediane
        $ob = [double]$o.Obs - $d; $ex = [double]$o.Exp
        # A l inverse du changement prevu ; ou au-dela du changement prevu entier, r2' encore hors tolerance
        $nr = if ($ex -eq 0) { [math]::Abs($ob) -gt $lim } else {
            $sgx = [math]::Sign($ex)
            (($ob * $sgx) -lt (-$lim)) -or ((($ob * $sgx) -gt ([math]::Abs($ex) + $lim)) -and ([math]::Abs([double]$o.R2 - $d) -gt (Get-ResidualTol $u.Verify[[int]$o.C])))
        }
        if ($nr) { $cand[[int]$o.C] = $o }
    }
    # Suites de candidats voisins de meme sens : ecart systematique, pas une mesure non reproductible
    $cs = @($cand.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    # Voisins : 2 cylindres au plus, ou consecutifs parmi les cylindres relus (test standard, un cylindre sur 10)
    $all = @(@($wit + $cor) | ForEach-Object { [int]$_.C } | Sort-Object)
    $i = 0
    while ($i -lt $cs.Count) {
        $j = $i
        while ($j -lt $cs.Count - 1 -and (($cs[$j + 1] - $cs[$j] -le 2) -or ([array]::IndexOf($all, $cs[$j + 1]) - [array]::IndexOf($all, $cs[$j]) -eq 1)) -and [math]::Sign([double]$cand[$cs[$j + 1]].Obs - $d - [double]$cand[$cs[$j + 1]].Exp) -eq [math]::Sign([double]$cand[$cs[$i]].Obs - $d - [double]$cand[$cs[$i]].Exp)) { $j++ }
        if ($j - $i + 1 -lt 3) {
            for ($q = $i; $q -le $j; $q++) { $o = $cand[$cs[$q]]; $res.NonRepro[[int]$cs[$q]] = @{ Z1 = [double]$o.P1 - [double]$o.R1 / $sl; Z2 = [double]$o.P2 - ([double]$o.R2 - $d) / $sl } }
        }
        else { for ($q = $i; $q -le $j; $q++) { $res.Sys[[int]$cs[$q]] = $true } }   # ecart systematique : juge sur la relecture
        $i = $j + 1
    }
    $kc = @($cor | Where-Object { -not $res.NonRepro.ContainsKey([int]$_.C) } | ForEach-Object { [double]$_.Obs - [double]$_.Exp })
    if ($kc.Count -gt 0) { $res.NC = $kc.Count; $res.DC = [double](Get-Median $kc) }
    return $res
}

function Set-VerifyContra($u) {
    # Apres la derniere verification, avant le bilan : cylindres aux verifications contradictoires (Get-VerifyDrift) ramenes
    # a leur valeur retenue (mediane bornee a l intervalle des deux valeurs ecrites). Correction par segments de la courbe
    # (Add-CurveCorrection : 0 aux autres cylindres verifies, monotonie par segments conservee), nouveau profil ; pas de
    # nouvelle passe d ecriture. Les cylindres verifies hors zone sont des points fixes (residu mesure a leur valeur) : la
    # cible d un cylindre de la zone est bornee par ses voisins fixes du meme segment, dans le sens du segment, pour que le
    # lissage croissant ne deplace aucun d eux sans mesure. Filet : un cylindre fixe deplace malgre tout (test standard :
    # cylindre interpole entre la zone et lui) est releve dans ContraMoved (residu non enregistre, ligne de journal).
    # Renvoie le nombre de cylindres de la zone dont la valeur change.
    $u.ContraMoved = @()
    if (-not $u.Fit -or -not $u.Profile) { return 0 }
    $dft = Get-VerifyDrift $u
    if ($dft.Contra.Count -eq 0) { return 0 }
    $vals = @($u.Fit.Values); $delta = @{}; $n = 0
    foreach ($k in @($u.Verify.Keys)) {
        $c = [int]$k
        if (@($u.Outliers) -contains $c -or $c -ge $vals.Count) { continue }
        $delta[$c] = 0.0
    }
    $segs = if ($u.Fit.Segs) { @($u.Fit.Segs) } else { @(@{ Lo = 0; Hi = $vals.Count - 1; Dir = 1 }) }
    $fix = @($delta.Keys | ForEach-Object { [int]$_ } | Where-Object { -not $dft.Contra.ContainsKey($_) } | Sort-Object)
    foreach ($k in @($dft.Contra.Keys)) {
        $c = [int]$k
        if (-not $delta.ContainsKey($c)) { continue }
        $sg = $null; foreach ($g in $segs) { if ($c -ge [int]$g.Lo -and $c -le [int]$g.Hi) { $sg = $g; break } }
        $t = [double]$dft.Contra[$c].Z
        if ($sg) {
            # Voisins fixes du segment, a gauche et a droite ; segment decroissant : bornes inversees
            $fl = @($fix | Where-Object { $_ -ge [int]$sg.Lo -and $_ -lt $c }); $fr = @($fix | Where-Object { $_ -gt $c -and $_ -le [int]$sg.Hi })
            $a = if ($fl.Count) { [double]$vals[$fl[-1]] } else { $null }; $b = if ($fr.Count) { [double]$vals[$fr[0]] } else { $null }
            if ([int]$sg.Dir -lt 0) { $x = $a; $a = $b; $b = $x }
            if ($null -ne $a) { $t = [math]::Max($t, $a) }
            if ($null -ne $b) { $t = [math]::Min($t, $b) }
        }
        $delta[$c] = $t - [double]$vals[$c]; if ($delta[$c] -ne 0) { $n++ }
    }
    if ($n -eq 0) { return 0 }
    $newVals = Add-CurveCorrection $u.Fit.Values $delta $u.Fit.Segs
    $newProfile = Build-CurveProfile $newVals
    if ($newProfile -eq $u.Profile) { return 0 }
    $base = ([string]$u.Fit.Model) -replace '\+c$', ''
    $u.Fit = @{ Model = "$base+c"; A = $u.Fit.A; B = $u.Fit.B; Chi = $u.Fit.Chi; Values = $newVals; Breaks = $u.Fit.Breaks; Segs = $u.Fit.Segs; Outliers = $u.Fit.Outliers }
    $u.Profile = $newProfile
    $u.ContraMoved = [int[]]@($fix | Where-Object { [int]$newVals[$_] -ne [int]$vals[$_] })
    return $n
}

function Get-ResidualFlags($u) {
    # Residus de la derniere verification. Bad : residu retenu (correction a la verification, non-convergence au bilan) ;
    # Spot : residu hors tolerance non retenu (ecart local, signale sans correction).
    # Voisinage d un cylindre : cylindres juges a 2 cylindres au plus (distance en cylindres, pas en rang) ; fenetre
    # tronquee, jamais decalee, la ou il en manque (debut ou fin de piste, cylindre non verifie, point isole, cylindre au
    # plafond ou au plancher). Points isoles et limites physiques (plafond, plancher) hors du jugement ; cylindres non
    # reproductibles et verifications contradictoires (Get-VerifyDrift) aussi, mais comptes comme voisins verifies.
    #  - Bruit : ecart-type robuste (MAD) des differences de residu entre cylindres juges consecutifs distants de 2 au
    #    plus, dans le meme segment de la courbe. Moins de CalNoiseMinDiffs differences (test standard, un cylindre sur
    #    10) : regle d origine, tout residu hors de sa tolerance est retenu.
    #  - Seuil d une moyenne de n residus : T(n) = max(CalResidual ; 3 bruits / racine de n). Residu tres grand :
    #    Hard = max(3 CalResidual ; 6 bruits).
    #  - Ecart : suite de cylindres juges consecutifs, distants de 2 au plus, hors tolerance, du meme
    #    signe ; un seul verdict par ecart. Retenu si l un de ses cylindres a moins de 2 voisins (cylindre epars : regle
    #    d origine, la courbe suit sa correction par interpolation entre cylindres verifies), une moyenne de voisinage
    #    au-dela de T, ou un residu au-dela de Hard ; ou si l ecart compte au moins 3 cylindres, ou 2 au bord (aucun
    #    cylindre juge du meme segment au-dela, a 2 cylindres au plus, d un cote : bout de piste, changement de sens,
    #    plafond : marche que la courbe peut suivre et que la fenetre ne peut pas confirmer), avec une moyenne au-dela de
    #    T(longueur) ; ou s il compte 2 cylindres de moyenne au-dela de Hard / racine de 2 (exigence d un residu seul
    #    au-dela de Hard, ramenee a la moyenne de 2).
    $vals = @($u.Fit.Values)
    $segs = @($u.Fit.Segs | Where-Object { $null -ne $_ })
    $pts = New-Object System.Collections.Generic.List[object]
    $dft = Get-VerifyDrift $u
    foreach ($c in @($u.Verify.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
        # Non reproductible, ou verifications contradictoires (zone non reproductible) : hors du jugement
        if (@($u.Outliers) -contains $c -or $dft.NonRepro.ContainsKey($c) -or $dft.Contra.ContainsKey($c)) { continue }
        $r = [double]$u.Verify[$c].Shift; $mz = $u.Verify[$c]
        # Temoin : valeur inchangee, juge sur sa mesure precedente (repere de la verification precedente, comme les cylindres
        # corriges une fois la derive retiree) ; sa relecture ne sert qu a mesurer la derive. Autre cylindre relu a la
        # derniere verification : juge sans la derive du lecteur mesuree sur les temoins
        if (@($u.Witness) -contains $c -and $u.VerifyPrev -and $u.VerifyPrev.ContainsKey($c) -and -not $dft.Sys.ContainsKey($c)) { $mz = $u.VerifyPrev[$c].Meas; $r = [double]$u.VerifyPrev[$c].Shift }
        elseif ($dft.Use -and $u.ReadLast -and $u.ReadLast.ContainsKey($c)) { $r -= [double]$dft.D }
        # Limites physiques (courbe au plafond encore sous-compensee, au plancher encore sur-compensee) : hors du jugement
        if ($c -lt $vals.Count -and (($r -gt 0 -and [int]$vals[$c] -ge $script:CalHardNs) -or ($r -lt 0 -and [int]$vals[$c] -le 0))) { continue }
        $sg = if ($segs.Count -gt 0) { -1 } else { 0 }
        for ($g = 0; $g -lt $segs.Count; $g++) { if ($c -ge [int]$segs[$g].Lo -and $c -le [int]$segs[$g].Hi) { $sg = $g; break } }
        $pts.Add(@{ C = $c; R = $r; S = $sg; Out = ([math]::Abs($r) -gt (Get-ResidualTol $mz)) })
    }
    $n = $pts.Count
    $bad = @{}; $spot = @()
    $res = @{ Bad = $bad; Spot = $spot; Sigma = [double]::NaN; NDiff = 0; Hard = [double]::NaN; HardPair = [double]::NaN }
    $d = @(for ($i = 1; $i -lt $n; $i++) { if ($pts[$i].S -eq $pts[$i - 1].S -and $pts[$i].C - $pts[$i - 1].C -le 2) { [double]$pts[$i].R - [double]$pts[$i - 1].R } })
    $res.NDiff = $d.Count
    if ($d.Count -lt $script:CalNoiseMinDiffs) {
        foreach ($p in $pts) { if ($p.Out) { $bad[$p.C] = $true } }
        return $res
    }
    $md = [double](Get-Median $d)
    $sig = 1.4826 * [double](Get-Median @($d | ForEach-Object { [math]::Abs($_ - $md) })) / [math]::Sqrt(2.0)
    $t0 = [double]$script:CalResidual
    $hard = [math]::Max(3.0 * $t0, 6.0 * $sig)
    # Voisinage : premier et dernier indice des cylindres juges a 2 cylindres au plus (fenetre tronquee, jamais decalee)
    $lo = New-Object int[] $n; $hi = New-Object int[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $a = $i; while ($a -gt 0 -and $pts[$i].C - $pts[$a - 1].C -le 2) { $a-- }
        $b = $i; while ($b -lt $n - 1 -and $pts[$b + 1].C - $pts[$i].C -le 2) { $b++ }
        $lo[$i] = $a; $hi[$i] = $b
    }
    # Jugement de chaque cylindre hors tolerance d apres son voisinage
    $flag = New-Object bool[] $n
    for ($i = 0; $i -lt $n; $i++) {
        if (-not $pts[$i].Out) { continue }
        $k = $hi[$i] - $lo[$i] + 1
        # Un cylindre non reproductible (ou d une zone non reproductible), hors des moyennes, reste un voisin verifie (pas de
        # bascule dans la regle d origine)
        $kx = @(@($dft.NonRepro.Keys) + @($dft.Contra.Keys) | Where-Object { [math]::Abs([int]$_ - [int]$pts[$i].C) -le 2 }).Count
        if ($k + $kx -lt 3) { $flag[$i] = $true; continue }
        $s = 0.0; for ($j = $lo[$i]; $j -le $hi[$i]; $j++) { $s += [double]$pts[$j].R }
        $tl = [math]::Max($t0, 3.0 * $sig / [math]::Sqrt([double]$k))
        if ([math]::Abs($s / $k) -gt $tl -or [math]::Abs([double]$pts[$i].R) -gt $hard) { $flag[$i] = $true }
    }
    # Ecarts : suites de cylindres consecutifs, hors tolerance, du meme signe, qui peuvent franchir un bord de segment
    # (segment d un seul cylindre au pied d une chute franche) ; un seul verdict par ecart
    $i = 0
    while ($i -lt $n) {
        if (-not $pts[$i].Out) { $i++; continue }
        $j = $i
        while ($j -lt $n - 1 -and $pts[$j + 1].Out -and $pts[$j + 1].C - $pts[$j].C -le 2 -and [math]::Sign([double]$pts[$j + 1].R) -eq [math]::Sign([double]$pts[$i].R)) { $j++ }
        $k = $j - $i + 1
        $keep = $false; $s = 0.0
        for ($q = $i; $q -le $j; $q++) { if ($flag[$q]) { $keep = $true }; $s += [double]$pts[$q].R }
        if (-not $keep -and $k -ge 2) {
            # Au bord : aucun cylindre juge du meme segment au-dela de l ecart, a 2 cylindres au plus, d un cote
            $edge = ($i -eq 0 -or $pts[$i - 1].S -ne $pts[$i].S -or $pts[$i].C - $pts[$i - 1].C -gt 2 -or
                     $j -eq $n - 1 -or $pts[$j + 1].S -ne $pts[$j].S -or $pts[$j + 1].C - $pts[$j].C -gt 2)
            $thr = if ($edge -or $k -ge 3) { [math]::Max($t0, 3.0 * $sig / [math]::Sqrt([double]$k)) } else { $hard / [math]::Sqrt(2.0) }
            if ([math]::Abs($s / $k) -gt $thr) { $keep = $true }
        }
        for ($q = $i; $q -le $j; $q++) { if ($keep) { $bad[$pts[$q].C] = $true } else { $spot += $pts[$q].C } }
        $i = $j + 1
    }
    $res.Spot = $spot; $res.Sigma = $sig; $res.Hard = $hard; $res.HardPair = $hard / [math]::Sqrt(2.0)
    return $res
}

function Get-CalibWarnings($u, [int]$maxCyl) {
    # Bilan de fiabilite d une unite apres la derniere verification :
    #  NonConv : cylindres dont le residu de la derniere verification est retenu par Get-ResidualFlags (ecart regional,
    #            marche au bord, residu tres grand, cylindre epars) ; ou cylindres mesures que la derniere verification
    #            n a pas pu relire (correction eventuelle jamais verifiee) ;
    #  Spot    : ecarts locaux, hors tolerance mais non retenus par Get-ResidualFlags (signales, non corriges) ;
    #  Dev     : cylindres ou la courbe retenue s ecarte de l estimation de plus de max(15 ns ; 3 incertitudes),
    #            typiquement un besoin non croissant lisse par la contrainte croissante ;
    #  Sat     : cylindres encore sous-compenses alors que la valeur ecrite a la derniere verification est a la borne
    #            absolue CalHardNs : le besoin depasse la precomp maximale, une nouvelle calibration n y changera rien
    #            (exclus de NonConv) ;
    #  Floor   : cylindres encore sur-compenses avec une valeur ecrite a la derniere verification a 0 ns (plancher) : meme
    #            principe ;
    #  Beyond  : cylindres dont la courbe depasse le plafond des passes de mesure CalMaxNs (valeurs deduites des mesures,
    #            puis verifiees), information seulement ;
    #  Extrap / Cap : estimations extrapolees au-dela des mesures, ou plafonnees.
    #  Drift / NonRepro : derive du lecteur entre les deux verifications (temoins) et cylindres non reproductibles d une
    #            passe a l autre (Get-VerifyDrift) ; les residus relus a la derniere verification sont juges sans la derive.
    #  Contra  : zone non reproductible, verifications contradictoires (Get-VerifyDrift) : courbe a la mediane des passes de
    #            mesure et des deux verifications (Set-VerifyContra), hors du jugement de convergence (jamais Sat ni Floor :
    #            besoin entre les deux valeurs ecrites). Liste lue par Complete-PrecompCalib (journal, Res, champ contra).
    $nonConv = @(); $sat = @(); $floor = @(); $dev = @(); $extrap = @(); $cap = @(); $spot = @(); $beyond = @(); $nonRepro = @(); $contra = @()
    $outl = @{}; foreach ($c in @($u.Outliers)) { $outl[[int]$c] = $true }
    $vals = @($u.Fit.Values)
    $fl = Get-ResidualFlags $u
    $dft = Get-VerifyDrift $u
    foreach ($c in @($u.Verify.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
        if ($outl.ContainsKey($c)) { continue }
        $r = [double]$u.Verify[$c].Shift; $mz = $u.Verify[$c]
        if (@($u.Witness) -contains $c -and $u.VerifyPrev -and $u.VerifyPrev.ContainsKey($c) -and -not $dft.Sys.ContainsKey($c)) { $mz = $u.VerifyPrev[$c].Meas; $r = [double]$u.VerifyPrev[$c].Shift }
        elseif ($dft.Use -and $u.ReadLast -and $u.ReadLast.ContainsKey($c)) { $r -= [double]$dft.D }
        $out = [math]::Abs($r) -gt (Get-ResidualTol $mz)
        # Limites physiques jugees a la valeur ecrite quand le residu a ete mesure (avant Set-VerifyContra) : une zone
        # non reproductible (besoin entre p1 et p2) n est jamais au plafond ni au plancher. VerifyP est rempli avec Verify ;
        # sans lui (unite sans valeurs ecrites), valeur de la courbe ; jamais de comparaison avec $null ($null -le 0 est vrai)
        $pw = $null
        if ($u.VerifyP -and $u.VerifyP.ContainsKey($c)) { $pw = [int]$u.VerifyP[$c] } elseif ($c -lt $vals.Count) { $pw = [int]$vals[$c] }
        if ($out -and $null -ne $pw -and $r -gt 0 -and $pw -ge $script:CalHardNs) { $sat += ("c{0} ({1:+0.0;-0.0})" -f $c, $r); continue }
        if ($out -and $null -ne $pw -and $r -lt 0 -and $pw -le 0) { $floor += ("c{0} ({1:+0.0;-0.0})" -f $c, $r); continue }
        if ($dft.Contra.ContainsKey($c)) { $contra += $c; continue }
        if ($dft.NonRepro.ContainsKey($c)) { $z = $dft.NonRepro[$c]; $nonRepro += ((T "c{0} ({1} puis {2} ns)") -f "$c", (Format-LevelNum $z.Z1), (Format-LevelNum $z.Z2)); continue }
        if ($out) {
            $txt = "c{0} ({1:+0.0;-0.0})" -f $c, $r
            if ($fl.Bad.ContainsKey($c)) { $nonConv += $txt }
            else { $spot += $txt }            # ecart local non retenu par Get-ResidualFlags
        }
    }
    foreach ($c in @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
        if (-not $u.Verify.ContainsKey($c) -and -not $outl.ContainsKey($c)) { $nonConv += ("c{0} ({1})" -f $c, (T 'non relu')) }
    }
    foreach ($c in @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
        if ($c -lt $vals.Count -and -not $outl.ContainsKey($c)) {
            $dv = $vals[$c] - [double]$u.Est[$c]
            if ([math]::Abs($dv) -gt [math]::Max(15.0, 3.0 * [double]$u.Sig[$c])) { $dev += ("c{0} ({1:+0;-0})" -f $c, $dv) }
        }
        if ($u.Kind[$c] -eq 'extrap') { $extrap += "c$c" } elseif ($u.Kind[$c] -eq 'cap') { $cap += "c$c" }
    }
    # Cylindres a la borne absolue avec Sat : couverts par le message du plafond, ce ne sont pas des valeurs deduites
    for ($c = 0; $c -lt $vals.Count; $c++) { $x = [int]$vals[$c]; if ($x -gt $script:CalMaxNs -and ($x -lt $script:CalHardNs -or $sat.Count -eq 0)) { $beyond += $c } }
    return @{ NonConv = $nonConv; Sat = $sat; Floor = $floor; Dev = $dev; Extrap = $extrap; Cap = $cap; Isolated = @($u.Outliers | ForEach-Object { "c$_" }); Breaks = @($u.Fit.Breaks)
              Spot = $spot; Sigma = $fl.Sigma; NDiff = $fl.NDiff; Hard = $fl.Hard; HardPair = $fl.HardPair; Beyond = [int[]]$beyond
              Drift = $dft; NonRepro = $nonRepro; Contra = [int[]]$contra }
}

function Get-KindName([string]$k) {
    switch ($k) { 'interp' { return (T 'encadrée') } 'extrap' { return (T 'extrapolée') } 'cap' { return (T 'plafonnée') } 'outlier' { return (T 'isolée') } default { return '' } }
}

function Test-CurvePointFlag($cv, [int]$i) {
    # Point dont la courbe s ecarte de plus de max(15 ns ; 3 incertitudes)
    $c = [int]$cv.Cyls[$i]; $v = @($cv.Values)
    if ($c -ge $v.Count) { return $false }
    if ($cv.Kinds -and $i -lt @($cv.Kinds).Count -and [string]$cv.Kinds[$i] -eq 'outlier') { return $false }
    return ([math]::Abs($v[$c] - [double]$cv.Ys[$i]) -gt [math]::Max(15.0, 3.0 * [double]$cv.Sig[$i]))
}

function Show-CalibReview($cal, [string[]]$issues, [bool]$toWrite, [bool]$offerFull = $false, [bool]$noFields = $false) {
    # Calibration au resultat douteux (non convergee, limite de 0 ou CalHardNs, ecart aux mesures, forme qui ne colle pas en
    # mode rapide) : la courbe obtenue est montree et l utilisateur decide. Pas de validation automatique : la decision
    # demande de regarder la courbe. Renvoie 'keep' (conserver / ecrire), 'stop' (abandonner) ou 'full' (calibration
    # complete, mode rapide seulement). Fermeture de la fenetre : arreter avant une ecriture, conserver sinon. noFields :
    # calibration rapide de la carte Calibration de l Accueil dont le profil n est pas place dans les champs --precomp.
    # Get-FamilyCurves renvoie deja un tableau protege (operateur virgule) : pas de @() autour, sinon tableau imbrique
    if ($script:CurveForm -and -not $script:CurveForm.IsDisposed) { $script:CurveForm.Close() }   # elle dessine ces memes donnees
    $script:CurveData = Get-FamilyCurves $cal.Family $cal.Slow
    Set-CurveLevelData $script:CurveData
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmCalibReview'; $dlg.Text = (T 'Calibration precomp')
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    $dlg.ShowInTaskbar = $false; $dlg.MinimizeBox = $false
    $dlg.Size = New-Object System.Drawing.Size(980, 760); $dlg.MinimumSize = New-Object System.Drawing.Size(700, 520)
    $dlg.KeyPreview = $true                        # Echap : comme la croix de la fenetre
    $dlg.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $_.Handled = $true; $this.Close() } })
    $lvl = ($cal.Mode -eq 'level')
    $head = if ($toWrite -and $lvl) { (T "Écrire l'image : l'image est écrite avec le niveau mesuré.`nArrêter : l'image n'est pas écrite ; le niveau n'est pas conservé et les profils de la référence sont rétablis.") }
            elseif ($toWrite) { (T "Écrire l'image : la courbe est conservée et l'image est écrite avec elle.`nArrêter : l'image n'est pas écrite et cette calibration n'est pas conservée (la calibration précédente est rétablie).") }
            elseif ($lvl -and $noFields) { (T "Conserver le niveau : il est enregistré pour cette disquette et reste affiché dans la fenêtre Courbe ; les champs --precomp ne sont pas modifiés.`nAbandonner le niveau : il n'est pas enregistré.") }
            elseif ($lvl) { (T "Conserver le niveau : le profil décalé reste dans les champs --precomp, pour cette disquette seulement.`nAbandonner le niveau : les champs --precomp reprennent leurs valeurs d'avant la calibration rapide.") }
            else { (T "Conserver la courbe : elle est enregistrée et appliquée aux prochaines écritures.`nAbandonner la courbe : la calibration précédente est rétablie.") }
    if ($offerFull) { $head += "`n" + (T "Calibration complète : la courbe du lecteur est mesurée de nouveau en test fin, après un avertissement ; elle devient la nouvelle référence de forme.") }
    $txt = (T "La calibration ne donne pas un bon résultat :") + "`n" + ((@($issues) | ForEach-Object { "  - $_" }) -join "`n") + "`n`n" + $head
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Name = 'lblRevText'; $lbl.AutoSize = $false; $lbl.UseMnemonic = $false; $lbl.Text = $txt; $lbl.Dock = 'Top'
    $lbl.Padding = New-Object System.Windows.Forms.Padding(12, 10, 12, 6); $lbl.ForeColor = $script:Theme.Warn
    $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $lbl.Height = [System.Windows.Forms.TextRenderer]::MeasureText($txt, $dlg.Font, (New-Object System.Drawing.Size(930, 10000)), $tf).Height + 20
    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Dock = 'Fill'; $pb.BackColor = [System.Drawing.Color]::White
    $pb.Add_Paint({ Draw-PrecompCurve $_.Graphics $this.ClientSize })
    $pb.Add_Resize({ $this.Invalidate() })
    $bar = New-Object System.Windows.Forms.Panel
    $bar.Dock = 'Bottom'; $bar.Height = 56; $bar.BackColor = $script:Theme.Page
    $bar.Width = $dlg.ClientSize.Width             # avant les boutons : leur ancrage a droite se mesure sur cette largeur
    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Name = 'btnRevKeep'; $btnOk.Size = New-Object System.Drawing.Size(200, 34); $btnOk.Anchor = 'Top,Right'
    $btnOk.Text = if ($toWrite) { (T "Écrire l'image") } elseif ($lvl) { (T 'Conserver le niveau') } else { (T 'Conserver la courbe') }
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btnNo = New-Object System.Windows.Forms.Button
    $btnNo.Name = 'btnRevStop'; $btnNo.Size = New-Object System.Drawing.Size(180, 34); $btnNo.Anchor = 'Top,Right'
    $btnNo.Text = if ($toWrite) { (T 'Arrêter') } elseif ($lvl) { (T 'Abandonner le niveau') } else { (T 'Abandonner la courbe') }
    $btnNo.DialogResult = [System.Windows.Forms.DialogResult]::Abort
    Set-Btn $btnOk $(if ($toWrite) { 'Save' } else { '' }) 'primary'; Set-Btn $btnNo '' 'normal'
    $btnNo.Location = New-Object System.Drawing.Point(($dlg.ClientSize.Width - 16 - $btnNo.Width), 11)
    $btnOk.Location = New-Object System.Drawing.Point(($btnNo.Left - 8 - $btnOk.Width), 11)
    $bar.Controls.AddRange(@($btnOk, $btnNo))
    if ($offerFull) {
        $btnFull = New-Object System.Windows.Forms.Button
        $btnFull.Name = 'btnRevFull'; $btnFull.Size = New-Object System.Drawing.Size(200, 34); $btnFull.Anchor = 'Top,Right'
        $btnFull.Text = (T 'Calibration complète'); $btnFull.DialogResult = [System.Windows.Forms.DialogResult]::Retry
        Set-Btn $btnFull '' 'normal'
        $btnFull.Location = New-Object System.Drawing.Point(($btnOk.Left - 8 - $btnFull.Width), 11)
        $bar.Controls.Add($btnFull)
    }
    $dlg.Controls.Add($pb); $dlg.Controls.Add($lbl); $dlg.Controls.Add($bar); $pb.BringToFront()
    $dlg.Add_Shown({ $this.Activate(); try { [System.Media.SystemSounds]::Exclamation.Play() } catch { } })
    try { $dr = $dlg.ShowDialog($form) } finally { $dlg.Dispose() }
    if ($dr -eq [System.Windows.Forms.DialogResult]::OK) { return 'keep' }
    if ($dr -eq [System.Windows.Forms.DialogResult]::Retry) { return 'full' }
    if ($dr -eq [System.Windows.Forms.DialogResult]::Abort) { return 'stop' }
    return $(if ($toWrite) { 'stop' } else { 'keep' })
}

function Restore-CalibState($prev) {
    # Retablit les courbes et profils d avant une calibration refusee par l utilisateur
    $script:PrecompStd = $prev.Std; $script:PrecompLong = $prev.Long
    foreach ($k in @($prev.Curves.Keys)) { $script:PrecompCurves[$k] = $prev.Curves[$k] }
    if ($prev.Levels) { $script:LevelShifts = $prev.Levels }      # niveaux mesures avec la reference retablie
    if ($script:CurveForm -and -not $script:CurveForm.IsDisposed) { $script:CurveForm.Close() }
    # Choix du profil et champs --precomp d avant la calibration (profil Manuel compris)
    if ($null -ne $prev.Prof -and $cmbWProfile.SelectedIndex -ne $prev.Prof) { $cmbWProfile.SelectedIndex = $prev.Prof }
    Update-PrecompForImage $txtWFile.Text
    if ($null -ne $prev.P0) { $chkWPrecomp.Checked = $prev.On; $txtWPrecomp.Text = $prev.P0; $txtWPrecomp1.Text = $prev.P1; $lblWProfileInfo.Text = $prev.Lbl }
    if (-not $script:Restore) { [void](Save-Config) }
}

function Show-TimedConfirm([string]$name, [string]$title, [string]$text, [string]$okText, [string]$okGlyph, [string]$countFmt, [string]$checkLabel, [string]$stopOn, [string]$stopOff) {
    # Fenetre d avertissement a compte a rebours : $okText / Annuler ; sans reponse, validation automatique au bout de
    # $script:CalibConfirmSeconds (0 = pas de delai), pour qu une sequence sans surveillance ne reste pas bloquee.
    # $countFmt : ligne du decompte ({0} = secondes). $checkLabel : case facultative ; la cocher ou la decocher arrete le
    # decompte (l utilisateur est present), la ligne affiche alors $stopOn ou $stopOff. Renvoie @{ Ok ; Checked ; Auto }.
    $w = 560
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = $name; $dlg.Text = $title
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    $pic = New-Object System.Windows.Forms.PictureBox
    $pic.Image = [System.Drawing.SystemIcons]::Warning.ToBitmap(); $pic.SizeMode = 'AutoSize'; $pic.Location = New-Object System.Drawing.Point(16, 16)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.AutoSize = $false; $lbl.UseMnemonic = $false; $lbl.Text = $text; $lbl.Location = New-Object System.Drawing.Point(64, 16)
    $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $h = [System.Windows.Forms.TextRenderer]::MeasureText($text, $dlg.Font, (New-Object System.Drawing.Size($w, 10000)), $tf).Height
    $lbl.Size = New-Object System.Drawing.Size($w, ($h + 4))
    $y = $lbl.Bottom + 12
    $chk = $null
    if ($checkLabel) {
        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Name = 'chkCalSwap'; $chk.Text = $checkLabel; $chk.AutoSize = $false; $chk.UseMnemonic = $false
        $chk.CheckAlign = 'TopLeft'; $chk.TextAlign = 'TopLeft'
        $hc = [System.Windows.Forms.TextRenderer]::MeasureText($checkLabel, $dlg.Font, (New-Object System.Drawing.Size(($w - 24), 10000)), $tf).Height
        $chk.Size = New-Object System.Drawing.Size($w, [math]::Max(24, ($hc + 6))); $chk.Location = New-Object System.Drawing.Point(64, $y)
        $y = $chk.Bottom + 8
    }
    $lblCount = New-Object System.Windows.Forms.Label
    $lblCount.Name = 'lblCalCount'; $lblCount.AutoSize = $false; $lblCount.Font = $bold
    $lblCount.Location = New-Object System.Drawing.Point(64, $y); $lblCount.ForeColor = $script:Theme.Warn
    $hCount = 22
    foreach ($s in @(($countFmt -f '999'), $stopOn, $stopOff)) {
        if (-not $s) { continue }
        $lblCount.Text = $s
        $hCount = [math]::Max($hCount, $lblCount.GetPreferredSize((New-Object System.Drawing.Size($w, 0))).Height)
    }
    $lblCount.Text = ''
    $lblCount.Size = New-Object System.Drawing.Size($w, $hCount)
    $y = $lblCount.Bottom + 10
    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Name = 'btnCalOk'; $btnOk.Text = $okText; $btnOk.Size = New-Object System.Drawing.Size(200, 34)
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btnNo = New-Object System.Windows.Forms.Button
    $btnNo.Name = 'btnCalCancel'; $btnNo.Text = (T 'Annuler'); $btnNo.Size = New-Object System.Drawing.Size(110, 34)
    $btnNo.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-Btn $btnOk $okGlyph 'primary'; Set-Btn $btnNo '' 'normal'
    $btnNo.Location = New-Object System.Drawing.Point((64 + $w - $btnNo.Width), $y)
    $btnOk.Location = New-Object System.Drawing.Point(($btnNo.Left - 8 - $btnOk.Width), $y)
    $dlg.ClientSize = New-Object System.Drawing.Size((64 + $w + 16), ($y + $btnOk.Height + 16))
    $dlg.AcceptButton = $btnOk; $dlg.CancelButton = $btnNo
    $dlg.Controls.AddRange(@($pic, $lbl, $lblCount, $btnOk, $btnNo))
    if ($chk) { $dlg.Controls.Add($chk) }
    $sec = [int]$script:CalibConfirmSeconds
    $script:CalConfirm = @{ Left = $sec; Auto = $false; Dlg = $dlg; Count = $lblCount; Tmr = $null; Fmt = $countFmt; StopOn = $stopOn; StopOff = $stopOff }
    $tmr = $null
    if ($sec -gt 0) {
        $lblCount.Text = ($countFmt -f "$sec")
        $tmr = New-Object System.Windows.Forms.Timer
        $tmr.Interval = 1000
        $script:CalConfirm.Tmr = $tmr
        $tmr.Add_Tick({
            $c = $script:CalConfirm
            if (-not $c) { return }
            $c.Left--
            if ($c.Left -le 0) { $c.Auto = $true; $c.Dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK; return }
            $c.Count.Text = ($c.Fmt -f "$($c.Left)")
        })
    }
    if ($chk -and $tmr) {
        $chk.Add_CheckedChanged({
            $c = $script:CalConfirm
            if (-not $c) { return }
            if ($c.Tmr) { $c.Tmr.Stop() }
            $c.Count.Text = if ($this.Checked) { $c.StopOn } else { $c.StopOff }
        })
    }
    $dlg.Add_Shown({ $this.Activate(); try { [System.Media.SystemSounds]::Exclamation.Play() } catch { } })
    if ($tmr) { $tmr.Start() }
    try { $dr = $dlg.ShowDialog($form) }
    finally { if ($tmr) { $tmr.Stop(); $tmr.Dispose() } }
    $res = @{ Ok = ($dr -eq [System.Windows.Forms.DialogResult]::OK); Checked = [bool]($chk -and $chk.Checked); Auto = [bool]$script:CalConfirm.Auto }
    $script:CalConfirm = $null
    $dlg.Dispose()
    return $res
}

function Show-CalibConfirm([string]$text, [string]$swapLabel) {
    # Avertissement avant une calibration : la disquette inseree recoit le motif de test a chaque passe, ce qui use le
    # support. $swapLabel : case « disquette sacrifiee » (la disquette a ecrire est redemandee apres la calibration),
    # absente pour une calibration seule. Renvoie @{ Ok ; Swap ; Auto }.
    $r = Show-TimedConfirm 'frmCalibConfirm' (T 'Calibration precomp') $text (T 'Lancer la calibration') 'Diagnostic' (T "Sans réponse, la calibration démarre automatiquement dans {0} s.") $swapLabel (T "Compte à rebours arrêté : insérez la disquette sacrifiée, puis cliquez sur « Lancer la calibration ».") (T "Compte à rebours arrêté : cliquez sur « Lancer la calibration » pour calibrer avec la disquette insérée.")
    return @{ Ok = $r.Ok; Swap = $r.Checked; Auto = $r.Auto }
}

# ============================== CALIBRATION RAPIDE (NIVEAU PAR DISQUETTE) ======
# Observation sur materiel reel : la forme de la courbe tient au lecteur, son niveau au support. La courbe d une
# calibration complete (reference, jamais modifiee) est decalee d un niveau uniforme mesure sur la disquette qui va
# recevoir l image : 6 cylindres de niveau pris parmi les mesures verifiees de la reference, 2 temoins de marche et
# 1 temoin du plafond au plus, 1 a 3 passes qui ecrivent la reference decalee (le niveau retenu est celui d une passe
# ecrite et verifiee). Le resultat ne va que dans les champs --precomp de l ecriture qui suit et dans
# $script:LevelShifts (affichage, historique, niveau de depart).

function Format-LevelNum($x) {
    # Nombre d un texte de la calibration rapide : une decimale au plus, au format de la culture ; '-' si non defini
    if ($null -eq $x -or [double]::IsNaN([double]$x)) { return '-' }
    return ('{0:0.#}' -f [math]::Round([double]$x, 1))
}

function Get-WeightedMedian($v, $w) {
    $n = @($v).Count
    if ($n -eq 0) { return [double]::NaN }
    $idx = @(0..($n - 1) | Sort-Object { [double]$v[$_] })
    $tot = 0.0; foreach ($x in @($w)) { $tot += [double]$x }
    $acc = 0.0
    foreach ($i in $idx) { $acc += [double]$w[$i]; if ($acc -ge $tot / 2) { return [double]$v[$i] } }
    return [double]$v[$idx[-1]]
}

function Get-LevelZero($points, [double]$k) {
    # Zero d un cylindre en precomp absolue (k = pente en valeur absolue) : Get-CalibZero avec deux mesures ou plus ;
    # avec une seule, extrapolation par la pente, encadree si le decalage est dans deux erreurs-types
    if (-not $points) { return $null }
    $xs = @($points.Keys | ForEach-Object { [int]$_ })
    if ($xs.Count -ge 2) { return (Get-CalibZero $points (-$k)) }
    if ($xs.Count -eq 0) { return $null }
    $x = $xs[0]; $m = $points[$x]
    $e = if ($null -eq $m.SE -or [double]::IsNaN([double]$m.SE) -or [double]$m.SE -le 0) { 2.0 } else { [double]$m.SE }
    $x0 = $x + [double]$m.Shift / $k
    $sig = [math]::Sqrt([math]::Pow($e / $k, 2) + [math]::Pow(0.25 * [math]::Abs($x0 - $x), 2))
    if ([math]::Abs([double]$m.Shift) -le 2.0 * $e) { return (Limit-CalibZero $x0 $sig 'interp' (-$k) $false) }
    return (Limit-CalibZero $x0 ([math]::Max(5.0, $sig)) 'extrap' (-$k) $false)
}

function Get-LevelCands($cv, [int]$last) {
    # Cylindres candidats d une reference : mesures encadrees et verifiees, loin des changements de sens, voisinage plat ;
    # zone plafonnee terminale et son temoin ; temoins de marche (sommet et cylindre mesure suivant)
    $V = @($cv.Values); $cyls = @(@($cv.Cyls) | ForEach-Object { [int]$_ })
    $brk = @(@($cv.Breaks) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
    # Zone plafonnee : fin de la reference a la borne de SON calcul (300 ns avant le calcul 12.4, Get-CurveMaxNs)
    $max = Get-CurveMaxNs $cv
    $capLo = $V.Count
    for ($c = $V.Count - 1; $c -ge 0; $c--) { if ([int]$V[$c] -ge $max) { $capLo = $c } else { break } }
    $probe = $null; if ($capLo -le $last) { $probe = $last }
    $pick = {
        param([int]$lo, [double]$vLo, [double]$vHi, [double]$resMax)
        $out = @()
        for ($i = 0; $i -lt $cyls.Count; $i++) {
            $c = $cyls[$i]
            if ($c -lt $lo -or $c -gt $last -or $c -ge $capLo) { continue }
            $kind = if ($cv.Kinds -and $i -lt @($cv.Kinds).Count) { [string]$cv.Kinds[$i] } else { 'interp' }
            if ($kind -ne 'interp' -or (Test-CurvePointFlag $cv $i)) { continue }
            $res = if ($cv.Res -and $i -lt @($cv.Res).Count) { [double]$cv.Res[$i] } else { [double]::NaN }
            if ([double]::IsNaN($res) -or [math]::Abs($res) -gt $resMax) { continue }
            $vc = [double]$V[$c]
            if ($vc -lt $vLo -or $vc -gt $vHi) { continue }
            $near = $false; foreach ($b in $brk) { if ([math]::Abs($c - $b) -le 1 -or [math]::Abs($c - ($b + 1)) -le 1) { $near = $true } }
            if ($near) { continue }
            if ($c -gt 0 -and [math]::Abs($vc - [double]$V[$c - 1]) -gt $script:LevelSteep) { continue }
            if ($c + 1 -lt $V.Count -and [math]::Abs([double]$V[$c + 1] - $vc) -gt $script:LevelSteep) { continue }
            $out += $c
        }
        return $out
    }
    $cand = @(& $pick 2 $script:LevelLo $script:LevelHi $script:CalResidual)
    $fb = $false
    if ($cand.Count -lt $script:LevelMinCyls) { $cand = @(& $pick 0 5 290 12); $fb = $true }     # repli : 10 ns sous le plafond des passes de mesure (300 ns)
    $wit = @()
    if ($brk.Count -ge 1) {
        $pk = $brk[0]; $ip = [array]::IndexOf([int[]]$cyls, [int]$pk)
        if ($ip -ge 0 -and $ip + 1 -lt $cyls.Count) {
            $nx = $cyls[$ip + 1]
            $good = { param($i) ((-not $cv.Kinds) -or [string]$cv.Kinds[$i] -eq 'interp') -and -not (Test-CurvePointFlag $cv $i) }
            if (($nx - $pk) -le 3 -and $nx -le $last -and (& $good $ip) -and (& $good ($ip + 1)) -and ([double]$V[$pk] - [double]$V[$nx]) -ge 30) { $wit = @($pk, $nx) }
        }
    }
    return @{ Cands = $cand; CapLo = $capLo; Wit = $wit; Probe = $probe; Fallback = $fb }
}

function Select-LevelCyls([int[]]$cand, [int[]]$brk, [int]$n) {
    # Selection deterministe : extremites (bras de levier), voisins de chaque changement de sens, puis le plus eloigne
    $c = @($cand | Sort-Object -Unique)
    if ($c.Count -le $n) { return ,[int[]]$c }
    $sel = New-Object System.Collections.Generic.List[int]
    $sel.Add($c[0]); if (-not $sel.Contains($c[-1])) { $sel.Add($c[-1]) }
    foreach ($b in @($brk)) {
        $l = @($c | Where-Object { $_ -le $b }); $r = @($c | Where-Object { $_ -gt $b + 1 })
        if ($l.Count -gt 0 -and -not $sel.Contains($l[-1]) -and $sel.Count -lt $n) { $sel.Add($l[-1]) }
        if ($r.Count -gt 0 -and -not $sel.Contains($r[0]) -and $sel.Count -lt $n) { $sel.Add($r[0]) }
    }
    while ($sel.Count -lt $n) {
        $best = -1; $bd = -1
        foreach ($x in $c) {
            if ($sel.Contains($x)) { continue }
            $d = (@($sel) | ForEach-Object { [math]::Abs($x - $_) } | Measure-Object -Minimum).Minimum
            if ($d -gt $bd) { $bd = $d; $best = $x }
        }
        if ($best -lt 0) { break }
        $sel.Add($best)
    }
    return ,[int[]]@($sel | Sort-Object)
}

function Get-LevelRef([string]$fam, [bool]$heads, [string]$drive, [string]$img, [bool]$restore, [int]$NCyl = 0, [int]$Bits = 0, [switch]$ForHome) {
    # Reference de forme pour la calibration rapide. Class 'redo' : calibration complete necessaire ; 'domain' : image
    # hors du domaine de la reference (geometrie, densite), Short si la reference a moins de cylindres que l image. NCyl,
    # Bits (> 0) : cylindres et cellules par piste donnes a la place de ceux de l image (format d une image secteur,
    # fenetre de la carte Calibration sans image). ForHome : carte Calibration de l Accueil (type de disquette, sans image :
    # raisons et notes parlent du type). Variables locales $nc et $pbits : $nCyl et $bits designeraient les parametres
    # types [int] (noms insensibles a la casse)
    $res = @{ Ok = $false; Class = 'redo'; Why = ''; Units = @(); Notes = @(); NCyl = 80; MaxCyl = 79; Family = $fam; Short = $false }
    $nc = if ($NCyl -gt 0) { $NCyl } else { Get-ImageCylinders $img }; if ($null -eq $nc) { $nc = 80 }
    $nc = [math]::Max(2, [math]::Min(84, [int]$nc)); $res.NCyl = $nc; $res.MaxCyl = $nc - 1
    $specs = @()
    if (-not $heads) {
        $cv = $script:PrecompCurves[$fam]
        if (-not $cv) { $res.Why = (T "aucune calibration commune pour la famille {0}") -f (Get-CalibFamilyName $fam); return $res }
        $specs = @(@{ Key = $fam; Tag = 'c'; Head = $null; Cv = $cv })
    } elseif (Test-HeadCurvesCurrent $fam) {
        $specs = @(@{ Key = "${fam}_h0"; Tag = '0'; Head = 0; Cv = $script:PrecompCurves["${fam}_h0"] }, @{ Key = "${fam}_h1"; Tag = '1'; Head = 1; Cv = $script:PrecompCurves["${fam}_h1"] })
    } elseif ($restore -and $script:PrecompCurves[$fam]) {
        $cv = $script:PrecompCurves[$fam]
        $specs = @(@{ Key = $fam; Tag = '0'; Head = 0; Cv = $cv }, @{ Key = $fam; Tag = '1'; Head = 1; Cv = $cv })
    } else { $res.Why = (T "aucune calibration par tête à jour pour la famille {0}") -f (Get-CalibFamilyName $fam); return $res }
    foreach ($s in $specs) {
        $cv = $s.Cv
        if ($cv.Method -ne 'motif') { $res.Why = (T 'référence mesurée sur le contenu d''une image, avant le motif de test'); return $res }
        if ([string]$cv.Drive -ne $drive) { $res.Why = (T "référence mesurée sur le lecteur {0}, et non {1}") -f "$($cv.Drive)", "$drive"; return $res }
        if ($null -eq $cv.Slope -or -not $cv.Bits) { $res.Why = (T 'référence antérieure à la calibration rapide (pente ou densité non enregistrée)'); return $res }
    }
    $vc = @($specs[0].Cv.Values).Count
    if ([math]::Abs($nc - $vc) -gt 4) {
        $res.Class = 'domain'; $res.Short = ($vc -lt $nc)
        $res.Why = $(if ($ForHome) { (T "type de {0} cylindres, référence de {1}") } else { (T "image de {0} cylindres, référence de {1}") }) -f "$nc", "$vc"; return $res
    }
    $pbits = [double]$(if ($Bits -gt 0) { $Bits } else { (Get-PatternBits $fam $img).Bits }); $rb = [double]$specs[0].Cv.Bits
    $dev = [math]::Abs($pbits - $rb) / $rb
    $devTxt = Format-UiNum ([math]::Round(100 * $dev, 1)) '0.#'
    if ($dev -gt $script:LevelBitsMax) { $res.Class = 'domain'; $res.Why = $(if ($ForHome) { (T "densité de ce type différente de celle de la référence de {0} % (5 % au plus)") } else { (T "densité de l'image différente de celle de la référence de {0} % (5 % au plus)") }) -f "$devTxt"; return $res }
    if ($dev -gt $script:LevelBitsNote) { $res.Notes += ($(if ($ForHome) { (T "Densité de ce type différente de celle de la référence de {0} %.") } else { (T "Densité de l'image différente de celle de la référence de {0} %.") }) -f "$devTxt") }
    $last = [math]::Min($nc - 1, $vc - 1)
    $cands = @(); foreach ($s in $specs) { $cands += ,(Get-LevelCands $s.Cv $last) }
    $common = $null
    if ($specs.Count -eq 2) {
        $inter = @(@($cands[0].Cands) | Where-Object { @($cands[1].Cands) -contains $_ })
        if ($inter.Count -ge $script:LevelMinCyls) {
            $brkU = @(@(@($specs[0].Cv.Breaks) + @($specs[1].Cv.Breaks)) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique)
            $common = Select-LevelCyls ([int[]]$inter) ([int[]]$brkU) $script:LevelCyls
        }
    }
    $units = @()
    for ($i = 0; $i -lt $specs.Count; $i++) {
        $s = $specs[$i]; $cd = $cands[$i]; $cv = $s.Cv
        $sel = if ($null -ne $common) { $common } else { Select-LevelCyls ([int[]]@($cd.Cands)) ([int[]]@(@($cv.Breaks) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })) $script:LevelCyls }
        if (@($sel).Count -lt $script:LevelMinCyls) { $res.Why = (T "trop peu de cylindres de mesure fiables dans la référence ({0}, {1} au moins)") -f "$(@($sel).Count)", "$($script:LevelMinCyls)"; return $res }
        $kref = [math]::Max($script:LevelKMin, [math]::Min(3.0, -[double]$cv.Slope))
        $hk = "$($s.Key)|$($s.Tag)"; $old = $script:LevelShifts[$hk]
        $d0 = 0; $nh = 0
        if ($old -and [string]$old.RefDate -eq [string]$cv.Date -and @($old.Hist).Count -gt 0) {
            $hv = @(@($old.Hist) | Select-Object -Last 4 | ForEach-Object { [double]$_.Delta }); $nh = $hv.Count
            $d0 = [int][math]::Round((Get-Median (@(0.0) + $hv)))
        }
        $units += ,@{ RefKey = $s.Key; Tag = $s.Tag; Head = $s.Head; Cv = $cv; V = [int[]]@($cv.Values); KRef = $kref; LCyls = [int[]]@($sel)
                      Wit = [int[]]@($cd.Wit); Probe = $cd.Probe; CapLo = [int]$cd.CapLo; D0 = $d0; NHist = $nh }
    }
    if (@($specs | Where-Object { $_.Cv.Converged -eq $false }).Count -gt 0) { $res.Notes += (T 'Référence non convergée : ses cylindres hors tolérance sont exclus de la mesure ; une calibration complète en test fin est conseillée.') }
    $kcv = @($specs | Where-Object { (Get-CurveCalc $_.Cv) -ne $script:CalibCalc })
    if ($kcv.Count -gt 0) { $res.Notes += ((T "Référence faite avec le calcul de calibration {0}.") -f (Get-CurveCalcText $kcv[0].Cv)) }
    if (@($specs | Where-Object { [string]$_.Cv.Test -eq 'std' }).Count -gt 0) { $res.Notes += (T 'Référence en test standard : entre les cylindres mesurés, la forme est interpolée ; une référence en test fin est conseillée.') }
    if (@($cands | Where-Object { $_.Fallback }).Count -gt 0) { $res.Notes += (T "Trop peu de cylindres de mesure selon les règles habituelles : règles élargies (cylindres 0 et 1 admis, valeurs de 5 à 290 ns, résidu de référence jusqu'à 12 ns).") }
    $res.Ok = $true; $res.Units = $units; $res.Why = ''
    return $res
}

function Set-LevelTargets($u) {
    # Cibles de la passe : reference decalee du niveau courant (cylindres de niveau et temoins de marche) ; temoin du
    # plafond : reference decalee a la premiere passe, puis son zero estime tant qu il n est pas resolu. Valeurs ecrites
    # bornees a la borne absolue CalHardNs (le temoin d une reference plafonnee a 300 ns peut etre ecrit au-dela)
    $max = [int]$script:CalHardNs
    $t = @{}
    foreach ($c in @(@($u.LCyls) + @($u.Wit))) { $t[[int]$c] = [int][math]::Max(0, [math]::Min($max, [math]::Round([double]$u.V[[int]$c] + $u.D))) }
    if ($null -ne $u.Probe -and -not $u.ProbeDone) {
        $p = [int]$u.Probe
        $t[$p] = if ($null -ne $u.ProbeZ) { [int][math]::Max(0, [math]::Min($max, [math]::Round([double]$u.ProbeZ))) } else { [int][math]::Max(0, [math]::Min($max, [math]::Round([double]$u.V[$p] + $u.D))) }
    }
    $u.LTarget = $t
}

function Get-LevelEstimate($u, [int]$pass) {
    # Niveau estime (ecart entre zero mesure et reference, moyenne ponderee avec plancher tau0), ecart de forme, residu
    # moyen de la passe ecrite, temoins ; cibles a 0 ou a la borne CalHardNs (ecretees) hors pente et residu
    $max = [double]$script:CalHardNs
    $k = [double]$u.KRef; $kRaw = $null
    $kSpan = 0.0
    if ($pass -ge 2) {
        $sl = @(); $spans = @()
        foreach ($c in @($u.LCyls)) {
            $pts = $u.Results[[int]$c]; if (-not $pts) { continue }
            $xs = @($pts.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -gt 0 -and $_ -lt $max } | Sort-Object)
            if ($xs.Count -lt 2 -or ($xs[-1] - $xs[0]) -lt 4) { continue }
            $sl += ([double]$pts[$xs[-1]].Shift - [double]$pts[$xs[0]].Shift) / ($xs[-1] - $xs[0]); $spans += ($xs[-1] - $xs[0])
        }
        if ($sl.Count -gt 0) { $kSpan = [double](Get-Median $spans); $kRaw = [double](Get-Median $sl); if ($kRaw -lt -0.2) { $k = [math]::Max($script:LevelKMin, [math]::Min(3.0, -$kRaw)) } }
    }
    $ds = @{}; $sg = @{}; $kinds = @{}; $capped = @(); $floored = @()
    foreach ($c in @($u.LCyls)) {
        $z = Get-LevelZero $u.Results[[int]$c] $k
        if (-not $z) { continue }
        # Zero borne : a la borne CalHardNs (besoin au-dela) ou au plancher de 0 ns (precompensation nulle encore excessive)
        if ($z.Kind -eq 'cap') { if ([double]$z.Est -le 0) { $floored += [int]$c } else { $capped += [int]$c }; $kinds[[int]$c] = 'cap'; continue }
        $ds[[int]$c] = [double]$z.Est - [double]$u.V[[int]$c]; $sg[[int]$c] = [double]$z.Sig; $kinds[[int]$c] = [string]$z.Kind
    }
    $cs = @($ds.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    $t0 = [math]::Pow([double]$script:LevelShapeFloor, 2)
    $w = @{}; foreach ($c in $cs) { $w[$c] = 1.0 / ([math]::Pow($sg[$c], 2) + $t0) }
    $outl = @(); $scatter = 0
    if ($cs.Count -ge 1) {
        $m = Get-WeightedMedian ([double[]]@($cs | ForEach-Object { $ds[$_] })) ([double[]]@($cs | ForEach-Object { $w[$_] }))
        $iso = @($cs | Where-Object { [math]::Abs($ds[$_] - $m) -gt [math]::Max(15.0, 4.0 * $sg[$_]) })
        if ($iso.Count -eq 1 -and $cs.Count -ge 5) { $outl = $iso } elseif ($iso.Count -ge 2) { $scatter = $iso.Count }
    }
    $keep = @($cs | Where-Object { $outl -notcontains $_ })
    $n = $keep.Count
    $e = @{ N = $n; K = $k; KRaw = $kRaw; KSpan = $kSpan; Ds = $ds; Sigs = $sg; Kinds = $kinds; Capped = $capped; Floored = $floored; Outliers = $outl; Scatter = $scatter; Keep = $keep; W = $w
            Delta = [double]::NaN; SE = [double]::NaN; Tau = 0.0; Rbar = [double]::NaN; RTol = [double]$script:CalResidual * [math]::Min(1.0, $k / 2.0); Wit = @{}; ProbeZ = $null; ProbeKind = '' }
    if ($n -ge 1) {
        $sw = 0.0; $swd = 0.0; foreach ($c in $keep) { $sw += $w[$c]; $swd += $w[$c] * $ds[$c] }
        $dh = $swd / $sw; $e.Delta = $dh
        if ($n -ge 2) {
            $chi = 0.0; $ss = 0.0; $ms = 0.0
            foreach ($c in $keep) { $chi += $w[$c] * [math]::Pow($ds[$c] - $dh, 2); $ss += [math]::Pow($ds[$c] - $dh, 2); $ms += [math]::Pow($sg[$c], 2) }
            $e.SE = [math]::Sqrt(1.0 / $sw) * [math]::Sqrt([math]::Max(1.0, $chi / ($n - 1)))
            $e.Tau = [math]::Sqrt([math]::Max(0.0, $ss / ($n - 1) - $ms / $n))
        } else { $e.SE = [math]::Sqrt(1.0 / $sw) }
        $rs = @()
        foreach ($c in $keep) {
            $tg = [int]$u.LTarget[[int]$c]
            if ($tg -le 0 -or $tg -ge [int]$max) { continue }
            $pt = $u.Results[[int]$c][$tg]; if ($pt) { $rs += [double]$pt.Shift }
        }
        if ($rs.Count -gt 0) {
            $mr = ($rs | Measure-Object -Average).Average; $e.Rbar = [double]$mr
            if ($rs.Count -ge 2) {
                $sd = [math]::Sqrt((@($rs | ForEach-Object { [math]::Pow($_ - $mr, 2) }) | Measure-Object -Sum).Sum / ($rs.Count - 1))
                $e.RTol = [math]::Max([double]$script:CalResidual * [math]::Min(1.0, $k / 2.0), 2.0 * $sd / [math]::Sqrt($rs.Count))
            }
        }
    }
    foreach ($c in @($u.Wit)) {
        $z = Get-LevelZero $u.Results[[int]$c] $k
        if ($z -and $z.Kind -ne 'cap') { $e.Wit[[int]$c] = @{ D = [double]$z.Est - [double]$u.V[[int]$c]; Sig = [double]$z.Sig; Z = [double]$z.Est } }
    }
    if ($null -ne $u.Probe) {
        $z = Get-LevelZero $u.Results[[int]$u.Probe] $k
        if ($z) { $e.ProbeZ = [double]$z.Est; $e.ProbeKind = [string]$z.Kind }
    }
    return $e
}

function Test-LevelShape($e, $u, [double]$f = 1.0) {
    # Forme de la disquette comparee a la reference : dispersion, ecart de forme, inclinaison radiale, hauteur de marche,
    # temoins de marche. f = 2 : seuils doubles (bascule anticipee apres la premiere passe).
    $reasons = @(); $tilt = $null; $step = $null
    if ($e.Scatter -ge 2) { $reasons += ((T "écarts dispersés ({0} cylindres hors de la forme)") -f "$($e.Scatter)") }
    if ($e.Tau -gt $script:LevelTauMax * $f) { $reasons += ((T "écart de forme {0} ns") -f ('{0:0.#}' -f [math]::Round($e.Tau, 1))) }
    $keep = @($e.Keep); $w = $e.W; $ds = $e.Ds
    $maxC = [math]::Max(1, @($u.V).Count - 1)
    if ($keep.Count -ge 4) {
        $us = @{}; foreach ($c in $keep) { $us[$c] = [double]$c / $maxC }
        $uv = @($keep | ForEach-Object { $us[$_] })
        $range = ($uv | Measure-Object -Maximum).Maximum - ($uv | Measure-Object -Minimum).Minimum
        if ($range -ge 0.5) {
            $sw = 0.0; $su = 0.0; $sd = 0.0; foreach ($c in $keep) { $sw += $w[$c]; $su += $w[$c] * $us[$c]; $sd += $w[$c] * $ds[$c] }
            $ub = $su / $sw; $db = $sd / $sw
            $suu = 0.0; $sud = 0.0; foreach ($c in $keep) { $suu += $w[$c] * [math]::Pow($us[$c] - $ub, 2); $sud += $w[$c] * ($us[$c] - $ub) * ($ds[$c] - $db) }
            if ($suu -gt 0) {
                $b = $sud / $suu
                $chi = 0.0; foreach ($c in $keep) { $chi += $w[$c] * [math]::Pow($ds[$c] - ($db + $b * ($us[$c] - $ub)), 2) }
                $tilt = $b * $range
                $seT = [math]::Sqrt([math]::Max(1.0, $chi / [math]::Max(1, $keep.Count - 2)) / $suu) * $range
                if ([math]::Abs($tilt) -gt [math]::Max(15.0 * $f, 3.0 * $seT)) {
                    $c1 = ($keep | Measure-Object -Minimum).Minimum; $c2 = ($keep | Measure-Object -Maximum).Maximum
                    $reasons += ((T "le niveau varie avec le cylindre ({0} ns de c{1} à c{2})") -f ('{0:+0;-0;0}' -f [math]::Round($tilt, 0)), "$c1", "$c2")
                }
            }
        }
    }
    $brk = @(@($u.Cv.Breaks) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
    if ($brk.Count -ge 1) {
        $pk = $brk[0]
        $l = @($keep | Where-Object { $_ -le $pk }); $r = @($keep | Where-Object { $_ -gt $pk })
        if ($l.Count -ge 2 -and $r.Count -ge 2) {
            $wl = 0.0; $dl = 0.0; foreach ($c in $l) { $wl += $w[$c]; $dl += $w[$c] * $ds[$c] }
            $wr = 0.0; $dr = 0.0; foreach ($c in $r) { $wr += $w[$c]; $dr += $w[$c] * $ds[$c] }
            $step = $dr / $wr - $dl / $wl
            $seS = [math]::Sqrt(1.0 / $wl + 1.0 / $wr)
            if ([math]::Abs($step) -gt [math]::Max(15.0 * $f, 3.0 * $seS)) { $reasons += ((T "la marche de c{0} n'a pas la même hauteur ({1} ns d'écart de part et d'autre)") -f "$pk", ('{0:+0;-0;0}' -f [math]::Round($step, 0))) }
        }
    }
    if (@($u.Wit).Count -eq 2 -and -not [double]::IsNaN([double]$e.Delta)) {
        foreach ($c in @($u.Wit)) {
            $wz = $e.Wit[[int]$c]; if (-not $wz) { continue }
            if ([math]::Abs($wz.D - $e.Delta) -gt [math]::Max(15.0 * $f, 4.0 * $wz.Sig)) { $reasons += ((T "marche déplacée ou absente entre c{0} et c{1} (autre lecteur sous la même lettre ?)") -f "$($u.Wit[0])", "$($u.Wit[1])"); break }
        }
    }
    $verdict = if ($reasons.Count -gt 0) { 'mismatch' } elseif ($e.Tau -gt $script:LevelTauOk) { 'approx' } else { 'ok' }
    return @{ Verdict = $verdict; Reasons = $reasons; Tilt = $tilt; Step = $step }
}

function Build-LevelValues($u, [int]$d, $e) {
    # Courbe appliquee : reference + niveau, bornee a 0..CalHardNs. Valeur de reference a la borne de SON calcul
    # (Get-CurveMaxNs : 300 ns avant le calcul 12.4) : borne basse du besoin, relevee d un niveau positif, jamais abaissee.
    # Zone plafonnee terminale de la reference (CapLo au temoin du plafond) :
    #  - temoin resolu (zero encadre ou extrapole, au plus CalHardNs) : zone interpolee lineairement jusqu a ce zero ;
    #  - temoin plafonne (besoin au-dela de CalHardNs) : zone portee jusqu a CalHardNs, jamais sous la reference relevee
    #    du niveau ; temoin compte dans Sat (reserve, fenetre de decision) ;
    #  - temoin non resolu, ou zero au plancher (invraisemblable a la borne) : regle generale ci-dessus.
    # Noms distincts de la reference ($ref) et de sa valeur ($rv) : PowerShell ignore la casse ($V et $v seraient une
    # seule variable)
    $max = [int]$script:CalHardNs; $rmax = Get-CurveMaxNs $u.Cv; $ref = @($u.V); $n = $ref.Count
    $out = New-Object int[] $n; $sat = @(); $floor = @(); $clip = @()
    for ($c = 0; $c -lt $n; $c++) {
        $rv = [int]$ref[$c]
        # Reference au-dela de la borne actuelle (courbe calculee avec une borne plus haute) : ecretee a la borne, niveau
        # applique, sans Sat (la borne est un reglage, pas un besoin de cette disquette)
        if ($rv -gt $max) {
            $raw = if ($rv -ge $rmax) { $rv + [math]::Max(0, $d) } else { $rv + $d }
            if ($raw -gt $max) { $clip += $c }
            $out[$c] = [int][math]::Max(0, [math]::Min($max, $raw)); continue
        }
        if ($rv -ge $rmax) {
            $raw = $rv + [math]::Max(0, $d)
            if ($raw -gt $max) { $sat += $c }
            $out[$c] = [int][math]::Min($max, $raw); continue
        }
        if ($rv -le 0) { $out[$c] = 0; continue }
        $raw = $rv + $d
        if ($raw -gt $max) { $sat += $c } elseif ($raw -lt 0) { $floor += $c }
        $out[$c] = [int][math]::Max(0, [math]::Min($max, $raw))
    }
    $note = $null
    if ($null -ne $u.Probe -and [int]$u.CapLo -ge 1 -and [int]$u.CapLo -lt $n -and [int]$u.Probe -ge [int]$u.CapLo -and $e) {
        $p = [int]$u.Probe; $lo = [int]$u.CapLo; $y1 = $null
        if ($null -eq $e.ProbeZ -or ($e.ProbeKind -ne 'cap' -and -not $u.ProbeDone)) { $note = 'unresolved' }
        elseif ($e.ProbeKind -eq 'cap' -and [double]$e.ProbeZ -le 0) { $note = 'unresolved' }
        elseif ($e.ProbeKind -eq 'cap') { $note = 'cap'; $y1 = [double]$max }
        else { $note = 'interp'; $y1 = [double]$e.ProbeZ }
        if ($null -ne $y1) {
            # Zone recalculee : interpolation depuis le dernier cylindre hors zone ; au-dela du temoin (reference plus longue
            # que l image), valeur du temoin
            $y0 = [double]$out[$lo - 1]
            $sat = @($sat | Where-Object { $_ -lt $lo }); $clip = @($clip | Where-Object { $_ -lt $lo })
            for ($c = $lo; $c -lt $n; $c++) {
                $tt = [math]::Min(1.0, ($c - ($lo - 1)) / [double]($p - ($lo - 1)))
                $raw = [math]::Round($y0 + $tt * ($y1 - $y0))
                if ($note -eq 'cap') {
                    $lb = [double]$ref[$c] + [math]::Max(0, $d)
                    if ([double]$ref[$c] -gt $max) { $clip += $c } elseif ($c -eq $p -or $lb -gt $max) { $sat += $c }
                    $raw = [math]::Max($raw, [math]::Min([double]$max, $lb))
                }
                $out[$c] = [int][math]::Max(0, [math]::Min($max, $raw))
            }
        }
    }
    return @{ Values = $out; Sat = $sat; Floor = $floor; ProbeNote = $note; Clip = $clip }
}

function Start-LevelCalib($lr, [switch]$NoConfirm, [switch]$NoFallback, $Geom = $null) {
    # Calibration rapide : avertissement (sauf NoConfirm), motif, unites, premiere passe. Geom : type de disquette de la
    # carte Calibration de l Accueil (image de geometrie, Start-HomeCalib) a la place de l image de l onglet Ecriture
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    $script:Cal = $null
    $chk = Test-CalibImage $Geom
    if (-not $chk) { return }
    $img = $chk.Img; $fam = $lr.Family
    $toWrite = ($script:AfterCalib -eq 'write')
    $target = if ($script:Restore) { (T 'la disquette de destination') } else { (T 'la disquette à écrire') }
    $units0 = @($lr.Units)
    $slow = ($null -ne $units0[0].Head)
    $all = @{}
    $sets = @()
    foreach ($lu in $units0) {
        $one = @(@(@($lu.LCyls) + @($lu.Wit) + @($(if ($null -ne $lu.Probe) { $lu.Probe }))) | ForEach-Object { [int]$_ } | Sort-Object -Unique)
        foreach ($c in $one) { $all[[int]$c] = $true }
        $sets += (Format-CylList ([int[]]$one))
    }
    $cyls = [int[]]@($all.Keys | Sort-Object)
    $cylTxt = if (@($sets | Sort-Object -Unique).Count -le 1) { $sets[0] } else { ((@(0..($units0.Count - 1) | ForEach-Object { (T "tête {0} : {1}") -f "$($units0[$_].Head)", "$($sets[$_])" })) -join ' ; ') }
    $ref0 = $units0[0].Cv
    $testTxt = if ([string]$ref0.Test -eq 'fine') { (T 'test fin') } else { (T 'test standard') }
    # Calibration rapide avant une ecriture lente : prechauffage du lecteur avant la mesure du niveau (case « Prechauffer le
    # lecteur ») ; duree comprise dans l estimation (borne haute : reduit ou saute si le lecteur vient de servir)
    $warm = ($toWrite -and $chkWSlow.Checked -and $chkWWarm.Checked)
    $wu = if ($warm) { [math]::Max(0.0, [double]$script:CalWarmupMinutes) } else { 0.0 }
    $minutes = [math]::Max(1, [math]::Round($cyls.Count * 2 * 1.4 * 2 / 60 + $wu, 0))
    $script:AlignLoop = $false; $script:AlignNextAt = $null
    if (-not $NoConfirm) {
        $intro = if ($toWrite) { ((T "Calibration rapide avant l'écriture : {0} reçoit le motif de test sur ces seuls cylindres, au plus 3 fois, puis l'image.") -f "$target") + "`n`n" } else { '' }
        $bodyFmt = if ($Geom) { (T "Calibration rapide de la précompensation sur le lecteur {0} : seul le niveau de la courbe est mesuré, sur la disquette insérée.`n`nRéférence : calibration complète du {1} ({2}), dont la forme est reprise telle quelle.`nType de disquette : {3}, famille {4}.`nCylindres mesurés : {5} (2 faces), ÉCRASÉS à chaque passe ; 1 à 3 passes, 2 en général. Durée estimée : {6} min.") }
                   else { (T "Calibration rapide de la précompensation sur le lecteur {0} : seul le niveau de la courbe est mesuré, sur la disquette insérée.`n`nRéférence : calibration complète du {1} ({2}), dont la forme est reprise telle quelle.`nImage : {3}, famille {4}.`nCylindres mesurés : {5} (2 faces), ÉCRASÉS à chaque passe ; 1 à 3 passes, 2 en général. Durée estimée : {6} min.") }
        $body = $bodyFmt -f "$($cmbDrive.Text)", "$($ref0.Date)", "$testTxt", "$($chk.Label)", (Get-CalibFamilyName $fam), "$cylTxt", "$minutes"
        if ($wu -gt 0) { $body += "`n" + ((T "Préchauffage du lecteur avant la mesure du niveau : jusqu'à {0} de lecture sans écriture (moins si le lecteur vient de servir), compris dans la durée estimée.") -f (Format-CalDuration (60 * $wu))) }
        $tail = if ($toWrite) { (T "Le niveau dépend du support : il doit être mesuré sur la disquette qui recevra l'image. N'insérez pas de disquette sacrifiée. Une calibration complète écrit le motif 4 à 8 fois sur ses cylindres de test ; la calibration rapide, 3 fois au plus.") }
                elseif ($Geom) { (T "Aucune image n'est écrite. Insérez la disquette que vous allez écrire : le profil obtenu ne vaut que pour elle ; il est placé dans les champs --precomp de l'onglet Écriture si son image est de la même famille.") }
                else { (T "Aucune image n'est écrite. Insérez la disquette que vous allez écrire : le profil obtenu est placé dans les champs --precomp et ne vaut que pour elle.") }
        $ans = Show-CalibConfirm ($intro + $body + "`n`n" + $tail) ''
        if (-not $ans.Ok) { return }
        if ($ans.Auto) { Append-Log ((T "Calibration : avertissement validé automatiquement après {0} s sans réponse.") -f "$($script:CalibConfirmSeconds)") }
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    try { $pat = New-CalibPattern $fam $img $lr.NCyl }
    catch { [void][System.Windows.Forms.MessageBox]::Show(((T "Calibration : motif de test impossible à créer : {0}") -f "$($_.Exception.Message)"),(T 'Calibration precomp'),'OK','Error'); return }
    $units = @()
    foreach ($lu in $units0) {
        $u = New-CalibUnit $lu.Head
        foreach ($key in 'RefKey', 'Tag', 'Cv', 'V', 'KRef', 'LCyls', 'Wit', 'Probe', 'CapLo', 'D0', 'NHist') { $u[$key] = $lu[$key] }
        $u.D = [int]$lu.D0; $u.LTarget = @{}; $u.Done = $false; $u.Conv = $false; $u.Fail = ''; $u.Early = $false; $u.Sat = $false; $u.Low = $false; $u.Few = $false; $u.ProbeOnly = $false
        $u.Level = $null; $u.Passes = 0; $u.ProbeDone = $false; $u.ProbeZ = $null; $u.Est = $null; $u.Shape = $null
        foreach ($c in @(@($u.LCyls) + @($u.Wit) + @($(if ($null -ne $u.Probe) { $u.Probe })))) { $u.Results[[int]$c] = @{} }
        Set-LevelTargets $u
        $units += ,$u
    }
    $cylList = Format-CylList $cyls
    $script:Cal = @{
        Mode = 'level'; Stage = 'level'; LPass = 1; Cyls = $cyls; MaxCyl = $lr.MaxCyl; Family = $fam; Slow = $slow
        Image = $img; Pattern = $pat.Path; PatternBits = $pat.Bits; MaxCoarse = 0; Drive = $cmbDrive.Text; TSpec = "c=${cylList}:h=0-1"; CylList = $cylList
        Values = @(); Index = 0; Value = 0; ValueTxt = ''; Spec = ''; Units = $units; VerifyCount = 0; Swap = $false; LevelAfter = $false
        CanFallback = ($toWrite -and -not $NoFallback -and -not $script:Restore); Notes = @($lr.Notes)
        Scp = (Join-Path $script:TempDir 'precomp-calib.scp'); Writes = (New-Object System.Collections.Queue); ReadArgs = @()
        StartTime = (Get-Date); PassStart = (Get-Date); PhaseStart = (Get-Date); Phase = 'write'
        PassesDone = 0; TotalPasses = 2; WriteDurs = @(); ReadDurs = @(); EstTrack = 0.7; TrackWrites = 0
        Home = [bool]$Geom; Geom = $Geom                      # carte Calibration de l Accueil (progression sur la carte)
    }
    $kind = if ($slow -and $units[0].RefKey -eq $units[1].RefKey) { (T 'forme commune, niveau mesuré par tête') } elseif ($slow) { (T 'une courbe par tête') } else { (T 'courbe commune') }
    $lf = if ($Geom) { (T "=== Calibration rapide : lecteur {0}, type {1} ({2}, {3}) ===") } else { (T "=== Calibration rapide : lecteur {0}, image {1} ({2}, {3}) ===") }
    Append-Log ($lf -f "$($cmbDrive.Text)", "$($chk.Label)", (Get-CalibFamilyName $fam), "$kind")
    foreach ($u in $units) {
        $tt = if ([string]$u.Cv.Test -eq 'fine') { (T 'test fin') } else { (T 'test standard') }
        Append-Log ((T "{0}Référence de forme : calibration complète ({1}) du {2}, lecteur {3} ; cylindres de niveau : {4}.") -f "$($u.Prefix)", "$tt", "$($u.Cv.Date)", "$($u.Cv.Drive)", (Format-CylList ([int[]]@($u.LCyls))))
        if (@($u.Wit).Count -eq 2) { Append-Log ((T "{0}Témoins de marche : c{1} et c{2} (contrôle de la forme, hors calcul du niveau).") -f "$($u.Prefix)", "$($u.Wit[0])", "$($u.Wit[1])") }
        if ($null -ne $u.Probe) { Append-Log ((T "{0}Témoin du plafond : c{1} (référence au plafond de {3} ns de son calcul, de c{2} à c{1}).") -f "$($u.Prefix)", "$($u.Probe)", "$($u.CapLo)", "$(Get-CurveMaxNs $u.Cv)") }
        if ($u.D0 -ne 0) { Append-Log ((T "{0}Niveau de départ : {1} ns (médiane de la référence et des {2} derniers niveaux mesurés avec elle).") -f "$($u.Prefix)", ('{0:+0;-0;0}' -f $u.D0), "$($u.NHist)") }
    }
    Append-Log (T 'Cylindres de niveau choisis parmi les cylindres mesurés et vérifiés de la référence ; exclus : cylindres 0 et 1, changements de sens et leurs voisins, pentes raides, valeurs hors de 20 à 260 ns, points isolés ou hors tolérance.')
    foreach ($nt in @($lr.Notes)) { Append-Log $nt }
    $pbWCal.Value = 0; $pbWCal.Visible = $true; $lblWCal.Visible = $true
    Update-CalibProgress
    # Avant une ecriture lente : prechauffage de l ecriture fait ici, avant la mesure du niveau, pour que le niveau soit
    # mesure dans l etat du lecteur ou l image sera ecrite (Start-CalibWarmup, retour a l etape 'level') ; seule ou avant
    # une ecriture rapide : aucun prechauffage
    if ($warm) { Start-CalibWarmup } else { New-CalibPass }
}

function Invoke-LevelStep($cal) {
    # Apres chaque passe : estimation par unite, arret (niveau verifie, echec, bascule anticipee, dernier essai) ou passe suivante
    $p = [int]$cal.LPass
    foreach ($u in $cal.Units) {
        if ($u.Done) { continue }
        $u.Passes = $p
        if ($u.ProbeOnly) {
            # Passe du seul temoin du plafond, ecrit a son zero estime : le niveau est deja verifie
            $z = Get-LevelZero $u.Results[[int]$u.Probe] ([double]$u.Est.K)
            $pp = $u.Results[[int]$u.Probe]; $tg = [int]$u.LTarget[[int]$u.Probe]
            if ($z) {
                $u.Est.ProbeZ = [double]$z.Est; $u.Est.ProbeKind = [string]$z.Kind; $u.ProbeZ = [double]$z.Est
                $atTol = ($pp -and $pp.ContainsKey($tg) -and [math]::Abs([double]$pp[$tg].Shift) -le (Get-ResidualTol $pp[$tg]))
                if ($z.Kind -eq 'cap' -or ($z.Kind -eq 'interp' -and @($pp.Keys).Count -ge 2) -or $atTol) { $u.ProbeDone = $true }
            }
            $u.ProbeOnly = $false; $u.Done = $true; continue
        }
        $e = Get-LevelEstimate $u $p
        $u.Est = $e
        if ($null -ne $u.Probe -and -not $u.ProbeDone -and $null -ne $e.ProbeZ) {
            $pp = $u.Results[[int]$u.Probe]; $tg = [int]$u.LTarget[[int]$u.Probe]
            $atTol = ($pp -and $pp.ContainsKey($tg) -and [math]::Abs([double]$pp[$tg].Shift) -le (Get-ResidualTol $pp[$tg]))
            if ($e.ProbeKind -eq 'cap' -or ($e.ProbeKind -eq 'interp' -and @($pp.Keys).Count -ge 2) -or $atTol) { $u.ProbeDone = $true }
            $u.ProbeZ = $e.ProbeZ
        }
        if ($e.N + @($e.Capped).Count + @($e.Floored).Count -lt 3) { $u.Fail = 'nomeas'; $u.Done = $true; continue }
        if ($null -ne $u.Head -and $p -ge 2 -and $null -ne $e.KRaw -and $e.KRaw -ge [math]::Max(-0.2, -0.5 * [double]$u.KRef) -and [double]$u.KRef * [double]$e.KSpan -ge 4.0) { $u.Fail = 'nowrite'; $u.Done = $true; continue }
        if ($e.N -lt 3) {
            $nm = $e.N + @($e.Capped).Count + @($e.Floored).Count
            if (2 * @($e.Floored).Count -gt $nm) { $u.Low = $true } elseif (2 * @($e.Capped).Count -gt $nm) { $u.Sat = $true } else { $u.Few = $true }
            $u.Level = if ($e.N -ge 1 -and -not [double]::IsNaN([double]$e.Delta)) { [int][math]::Round([double]$e.Delta) } else { [int]$u.D }
            $u.Conv = $false; $u.Done = $true; continue
        }
        $dh = [double]$e.Delta
        $dv = @($e.Keep | ForEach-Object { $e.Ds[$_] })
        Append-Log ($u.Prefix + ((T "Niveau estimé : {0} ns ± {1} ({2} cylindres ; écarts à la forme de {3} à {4} ns ; écart de forme {5} ns).") -f ('{0:+0.0;-0.0;0.0}' -f $dh), ('{0:0.#}' -f [math]::Round($e.SE, 1)), "$($e.N)", ('{0:+0.0;-0.0;0.0}' -f (($dv | Measure-Object -Minimum).Minimum - $dh)), ('{0:+0.0;-0.0;0.0}' -f (($dv | Measure-Object -Maximum).Maximum - $dh)), ('{0:0.#}' -f [math]::Round($e.Tau, 1))))
        if (-not [double]::IsNaN([double]$e.Rbar) -and [math]::Abs($e.Rbar) -le $e.RTol) {
            $u.Level = [int]$u.D; $u.Conv = $true
            Append-Log ($u.Prefix + ((T "Niveau vérifié à la passe {0} : décalage résiduel moyen {1} ns (tolérance {2}) : niveau retenu {3} ns.") -f "$p", ('{0:0.#}' -f [math]::Round($e.Rbar, 1)), ('{0:0.#}' -f [math]::Round($e.RTol, 1)), ('{0:+0;-0;0}' -f $u.Level)))
            if ($null -ne $u.Probe -and -not $u.ProbeDone -and $null -ne $u.ProbeZ -and $p -lt $script:LevelMaxPasses) {
                # Temoin du plafond non resolu : une passe de plus sur ce seul cylindre, ecrit a son zero estime
                $u.ProbeOnly = $true
                $u.LTarget = @{ ([int]$u.Probe) = [int][math]::Max(0, [math]::Min([int]$script:CalHardNs, [math]::Round([double]$u.ProbeZ))) }
                continue
            }
            $u.Done = $true
            continue
        }
        if ($p -eq 1 -and $cal.CanFallback -and (Test-LevelShape $e $u 2.0).Verdict -eq 'mismatch') { $u.Level = [int][math]::Round($dh); $u.Conv = $false; $u.Early = $true; $u.Done = $true; continue }
        if ($p -ge $script:LevelMaxPasses) {
            $u.Level = [int][math]::Round($dh); $u.Conv = $false; $u.Done = $true
            Append-Log ($u.Prefix + ((T "Niveau non vérifié après {0} passes (décalage résiduel moyen {1} ns, tolérance {2}) : niveau estimé {3} ns retenu.") -f "$p", ('{0:0.#}' -f [math]::Round($e.Rbar, 1)), ('{0:0.#}' -f [math]::Round($e.RTol, 1)), ('{0:+0;-0;0}' -f $u.Level)))
            continue
        }
        $dn = [int][math]::Round($dh)
        $mv = [math]::Max([int]$script:LevelMinMove, [int][math]::Ceiling(4.0 / [double]$u.KRef))
        if ($p -eq 1 -and [math]::Abs($dn - $u.D) -lt $mv) {
            $sg = [math]::Sign($dh - $u.D); if ($sg -eq 0) { $sg = $(if ($e.Rbar -gt 0) { 1 } else { -1 }) }
            $dn = [int]$u.D + $mv * $sg
        }
        if ($dn -eq $u.D) {
            # [1] Estimation stable mais residu hors tolerance (ou non mesure) : niveau garde, non verifie
            $u.Level = [int]$u.D; $u.Conv = $false; $u.Done = $true
            Append-Log ($u.Prefix + ((T "Niveau stable mais non vérifié à la passe {0} (décalage résiduel moyen {1} ns, tolérance {2}) : niveau {3} ns retenu.") -f "$p", (Format-LevelNum $e.Rbar), (Format-LevelNum $e.RTol), ('{0:+0;-0;0}' -f $u.Level)))
            continue
        }
        Append-Log ($u.Prefix + ((T "Niveau hors tolérance (décalage résiduel moyen {0} ns, tolérance {1}) : passe suivante à {2} ns.") -f ('{0:0.#}' -f [math]::Round($e.Rbar, 1)), ('{0:0.#}' -f [math]::Round($e.RTol, 1)), ('{0:+0;-0;0}' -f $dn)))
        $u.D = $dn
        Set-LevelTargets $u
    }
    if (@($cal.Units | Where-Object { $_.Fail -or $_.Early }).Count -gt 0) {
        # Bascule anticipee ou echec d une tete : l autre tete, non terminee, garde son niveau estime (non verifie)
        foreach ($u in @($cal.Units | Where-Object { -not $_.Done })) { $u.Level = [int][math]::Round([double]$u.Est.Delta); $u.Conv = $false; $u.Done = $true }
        Complete-LevelCalib; return
    }
    if (@($cal.Units | Where-Object { -not $_.Done }).Count -gt 0) {
        $cal.LPass++; $cal.TotalPasses = [math]::Max([int]$cal.TotalPasses, [int]$cal.LPass)
        New-CalibPass; return
    }
    Complete-LevelCalib
}

function Get-LevelLabel($rec) {
    # « +12 ns » (profil commun) ou « tête 0 +12 ns »
    $v = '{0:+0;-0;0} ns' -f [int]$rec.Delta
    if ($null -eq $rec.Head) { return $v }
    return ((T "tête {0} {1}") -f "$($rec.Head)", "$v")
}

function Set-LevelFields($recs, [bool]$slow) {
    # Profils decales dans les champs --precomp (tetes physiques en ecriture lente) : pour cette disquette seulement
    $chkWPrecomp.Checked = $true
    $rs = @($recs)
    if ($slow) {
        $r0 = @($rs | Where-Object { $_.Head -eq 0 }); $r1 = @($rs | Where-Object { $_.Head -eq 1 })
        if ($r0.Count -gt 0) { $txtWPrecomp.Text = $r0[0].Spec }
        if ($r1.Count -gt 0) { $txtWPrecomp1.Text = $r1[0].Spec }
    } elseif ($rs.Count -gt 0) { $txtWPrecomp.Text = $rs[0].Spec; $txtWPrecomp1.Text = $rs[0].Spec }
}

function Complete-LevelCalib {
    $cal = $script:Cal; $script:Cal = $null
    if (-not $cal) { return }
    $pbWCal.Value = 100
    $elapsed = if ($cal.StartTime -is [datetime]) { ((Get-Date) - $cal.StartTime).TotalSeconds } else { 0 }
    $toWrite = ($script:AfterCalib -eq 'write')
    $famTxt = Get-CalibFamilyName $cal.Family
    $fails = @($cal.Units | Where-Object { $_.Fail })
    if ($fails.Count -gt 0) {
        foreach ($u in $fails) {
            if ($u.Fail -eq 'nowrite') { Append-Log ($u.Prefix + (T 'Calibration : le décalage ne varie pas avec la précompensation écrite, cette face n''a pas été écrite (tête ou circuit d''écriture défaillant ?).')) }
            else { Append-Log ((T "{0}Calibration rapide : moins de 3 cylindres mesurables, niveau impossible à estimer.") -f "$($u.Prefix)") }
        }
        $pbWCal.Visible = $false
        $nw = (@($fails | Where-Object { $_.Fail -eq 'nowrite' }).Count -gt 0)
        $lblWCal.Text = $(if ($nw) { (T 'Calibration rapide : une face ne réagit pas à la précompensation (voir le journal).') } else { (T 'Calibration rapide sans mesure exploitable.') })
        if ($toWrite) { $script:AfterCalib = ''; Append-Log $(if ($nw) { (T 'Écriture annulée : une face ne réagit pas à la précompensation.') } else { (T 'Écriture annulée : calibration rapide sans mesure exploitable.') }) }
        if ($script:Restore) { Stop-Restore $(if ($nw) { (T 'une face ne réagit pas à la précompensation') } else { (T 'calibration rapide sans mesure exploitable') }) }
        return
    }
    $date = Get-Date -Format 'dd/MM/yyyy HH:mm'
    $issues = New-Object System.Collections.Generic.List[string]
    $recs = @(); $prevRecs = @{}; $verdicts = @()
    foreach ($u in $cal.Units) {
        $e = $u.Est; $pfx = $u.Prefix
        $shape = Test-LevelShape $e $u 1.0; $u.Shape = $shape
        $bv = Build-LevelValues $u ([int]$u.Level) $e
        foreach ($c in @($e.Outliers)) { Append-Log ($pfx + ((T "Écart isolé à c{0} ({1} ns par rapport à la forme) : défaut ponctuel probable de cette disquette, écarté du niveau.") -f "$c", ('{0:+0;-0;0}' -f [math]::Round($e.Ds[[int]$c] - $e.Delta, 0)))) }
        $verdict = if ($u.Sat) { 'sat' } elseif ($u.Low) { 'low' } elseif ($u.Few) { 'few' } else { $shape.Verdict }
        switch ($shape.Verdict) {
            'ok'       { Append-Log ($pfx + ((T "Forme conforme à la référence (écart de forme {0} ns).") -f ('{0:0.#}' -f [math]::Round($e.Tau, 1)))) }
            'approx'   { Append-Log ($pfx + ((T "Forme approximative (écart de forme {0} ns) : courbe décalée appliquée ; une calibration complète de cette disquette serait plus précise.") -f ('{0:0.#}' -f [math]::Round($e.Tau, 1)))) }
            'mismatch' { Append-Log ($pfx + ((T "Forme non conforme à la référence : {0}.") -f ($shape.Reasons -join ' ; '))); $issues.Add($pfx + ((T "forme non conforme à la référence : {0}") -f ($shape.Reasons -join ' ; '))) }
        }
        if (-not $u.Conv) { $issues.Add($pfx + ((T "niveau non vérifié par une écriture du motif ({0} passe(s))") -f "$($u.Passes)")) }
        if ($u.Sat) { $issues.Add($pfx + ((T 'besoin au-delà de {0} ns sur la plupart des cylindres mesurés (support fatigué ?)') -f "$($script:CalHardNs)")) }
        if ($u.Low) { $issues.Add($pfx + (T 'précompensation nulle encore excessive sur la plupart des cylindres mesurés')) }
        if ($u.Few) { $issues.Add($pfx + ((T "niveau estimé sur {0} cylindre(s) de niveau seulement ({1} au plafond ou au plancher)") -f "$($e.N)", "$(@($e.Capped).Count + @($e.Floored).Count)")) }
        # [3] Cylindres de niveau bornes (zero au-dela de CalHardNs ou sous 0 ns) loin du niveau retenu : ecartes, signales
        $bnd = @(@(@($e.Capped) | Where-Object { [int]$u.V[[int]$_] + [int]$u.Level -lt [int]$script:CalHardNs - 15 }) + @(@($e.Floored) | Where-Object { [int]$u.V[[int]$_] + [int]$u.Level -gt 15 }))
        if (-not $u.Sat -and -not $u.Low -and $bnd.Count -gt 0) {
            $bt = (T "besoin hors de 0 à {1} ns aux cylindres de niveau {0}, loin du niveau de cette disquette : écartés du niveau") -f (Format-CylList ([int[]]@($bnd | Sort-Object))), "$($script:CalHardNs)"
            Append-Log ($pfx + $bt + '.'); $issues.Add($pfx + $bt)
        }
        if ($bv.Sat.Count -gt 0) {
            Append-Log ($pfx + ((T "Plafond de {0} ns atteint aux cylindres {1} avec le niveau de cette disquette ({2} ns par rapport à la référence) : support probablement fatigué, ces cylindres resteront sous-compensés.") -f "$($script:CalHardNs)", (Format-CylList ([int[]]$bv.Sat)), ('{0:+0;-0;0}' -f [int]$u.Level)))
            $issues.Add($pfx + ((T "plafond de {0} ns atteint aux cylindres {1} (support fatigué ?)") -f "$($script:CalHardNs)", (Format-CylList ([int[]]$bv.Sat))))
        }
        if (@($bv.Clip).Count -gt 0) {
            Append-Log ($pfx + ((T "Référence calculée avec une borne de {0} ns, au-delà de la borne actuelle (precompMaxNs = {1} ns) aux cylindres {2} : valeurs ramenées à {1} ns.") -f "$(Get-CurveMaxNs $u.Cv)", "$($script:CalHardNs)", (Format-CylList ([int[]]$bv.Clip))))
        }
        if ($bv.Floor.Count -gt 0) {
            Append-Log ($pfx + ((T "Précompensation nulle encore excessive aux cylindres {0} avec le niveau de cette disquette : ces cylindres resteront sur-compensés.") -f (Format-CylList ([int[]]$bv.Floor))))
            $issues.Add($pfx + ((T "précompensation nulle encore excessive aux cylindres {0}") -f (Format-CylList ([int[]]$bv.Floor))))
        }
        if ($bv.ProbeNote -eq 'interp') { Append-Log ($pfx + ((T "Zone plafonnée de la référence (c{0} à c{1}) : besoin mesuré au témoin c{1} : {2} ns ; zone interpolée jusqu'à cette valeur.") -f "$($u.CapLo)", "$($u.Probe)", ('{0:0.#}' -f [math]::Round($e.ProbeZ, 0)))) }
        elseif ($bv.ProbeNote -eq 'unresolved') {
            $ut = (T "témoin du plafond c{0} non résolu : zone de c{1} à c{0} laissée à la référence ({2} ns, plafond de son calcul), relevée du niveau s'il est positif, sans mesure sur cette disquette") -f "$($u.Probe)", "$($u.CapLo)", "$(Get-CurveMaxNs $u.Cv)"
            Append-Log ($pfx + $ut + '.'); $issues.Add($pfx + $ut)
        }
        elseif ($bv.ProbeNote -eq 'cap') { Append-Log ($pfx + ((T "Zone plafonnée de la référence (c{0} à c{1}) : le besoin dépasse encore {2} ns au témoin c{1} ; zone portée jusqu'à {2} ns.") -f "$($u.CapLo)", "$($u.Probe)", "$($script:CalHardNs)")) }
        # Historique avec la meme reference : support fatigue, derive de la reference
        $hk = "$($u.RefKey)|$($u.Tag)"; $old = $script:LevelShifts[$hk]; $prevRecs[$hk] = $old
        $hist = @(); if ($old -and [string]$old.RefDate -eq [string]$u.Cv.Date) { $hist = @($old.Hist) }
        if ($hist.Count -ge 3) {
            $hv = @($hist | Select-Object -Last 5 | ForEach-Object { [double]$_.Delta }); $med = [double](Get-Median $hv)
            if ([int]$u.Level - $med -gt $script:LevelFatigueNs) { Append-Log ($pfx + ((T "Cette disquette demande {0} ns de plus que la médiane des {1} dernières disquettes mesurées avec cette référence : support probablement fatigué, l'écriture y sera moins sûre.") -f ('{0:0.#}' -f [math]::Round([int]$u.Level - $med, 0)), "$($hv.Count)")) }
            $l5 = @(@($hist | Select-Object -Last 4 | ForEach-Object { [double]$_.Delta }) + @([double]$u.Level))
            if ($l5.Count -ge 5 -and (@($l5 | Where-Object { $_ -gt $script:LevelFatigueNs }).Count -eq 5 -or @($l5 | Where-Object { $_ -lt -$script:LevelFatigueNs }).Count -eq 5)) {
                Append-Log ($pfx + ((T "Les {0} dernières disquettes s'écartent toutes de la référence dans le même sens (de {1} à {2} ns) : la référence a peut-être été mesurée sur une disquette atypique. Une nouvelle calibration complète en test fin, sur une disquette sacrifiée en bon état, est conseillée.") -f "$($l5.Count)", ('{0:+0;-0;0}' -f ($l5 | Measure-Object -Minimum).Minimum), ('{0:+0;-0;0}' -f ($l5 | Measure-Object -Maximum).Maximum)))
            }
        }
        if (($verdict -eq 'ok' -or $verdict -eq 'approx') -and $u.Conv -and -not $u.Early) { $hist = @(@($hist) + @(@{ Date = $date; Delta = [int]$u.Level })) }
        if ($hist.Count -gt $script:LevelHistMax) { $hist = @($hist | Select-Object -Last $script:LevelHistMax) }
        # Mesures : cylindres de niveau, temoins de marche et du plafond
        $mc = @(); $mz = @(); $md = @(); $ms = @(); $mk = @()
        foreach ($c in @($u.LCyls)) {
            $ci = [int]$c
            if ($e.Ds.ContainsKey($ci)) { $mc += $ci; $mz += [math]::Round([double]$u.V[$ci] + $e.Ds[$ci], 1); $md += [math]::Round($e.Ds[$ci], 1); $ms += [math]::Round($e.Sigs[$ci], 1); $mk += $(if (@($e.Outliers) -contains $ci) { 'outlier' } else { [string]$e.Kinds[$ci] }) }
            elseif (@($e.Capped) -contains $ci) { $mc += $ci; $mz += [double]$script:CalHardNs; $md += [math]::Round([double]$script:CalHardNs - [double]$u.V[$ci], 1); $ms += 0.0; $mk += 'cap' }
            elseif (@($e.Floored) -contains $ci) { $mc += $ci; $mz += 0.0; $md += [math]::Round(-[double]$u.V[$ci], 1); $ms += 0.0; $mk += 'cap' }
        }
        foreach ($c in @($u.Wit)) { $wz = $e.Wit[[int]$c]; if ($wz) { $mc += [int]$c; $mz += [math]::Round($wz.Z, 1); $md += [math]::Round($wz.D, 1); $ms += [math]::Round($wz.Sig, 1); $mk += 'witness' } }
        if ($null -ne $u.Probe -and $null -ne $e.ProbeZ) { $mc += [int]$u.Probe; $mz += [math]::Round([double]$e.ProbeZ, 1); $md += [math]::Round([double]$e.ProbeZ - [double]$u.V[[int]$u.Probe], 1); $ms += 0.0; $mk += 'probe' }
        $rec = @{ RefKey = $u.RefKey; Tag = $u.Tag; Head = $u.Head; Drive = $cal.Drive; Date = $date; RefDate = [string]$u.Cv.Date; RefTest = [string]$u.Cv.Test
                  Delta = [int]$u.Level; Est = [math]::Round([double]$e.Delta, 1); SE = [math]::Round([double]$e.SE, 1); Tau = [math]::Round([double]$e.Tau, 1)
                  Verdict = $verdict; Shape = [string]$shape.Verdict; Reasons = [string[]]@($shape.Reasons); Conv = [bool]$u.Conv; Passes = [int]$u.Passes
                  Cyls = [int[]]$mc; Zs = [double[]]$mz; Ds = [double[]]$md; Sigs = [double[]]$ms; Kinds = [string[]]$mk
                  Values = [int[]]$bv.Values; Spec = (Build-CurveProfile $bv.Values); Sat = [int[]]@($bv.Sat); Floor = [int[]]@($bv.Floor)
                  Hist = @($hist); Version = $script:Version; Algo = $script:CalibAlgo; LevelAlgo = $script:LevelAlgo }
        $script:LevelShifts[$hk] = $rec
        $recs += ,$rec; $verdicts += $verdict
    }
    if (-not $script:Restore) { [void](Save-Config) }
    $fieldsPrev = @{ Prof = $cmbWProfile.SelectedIndex; On = $chkWPrecomp.Checked; P0 = $txtWPrecomp.Text; P1 = $txtWPrecomp1.Text; Lbl = $lblWProfileInfo.Text }
    # Carte Calibration de l Accueil : profil place dans les champs --precomp seulement si l image de l onglet Ecriture est
    # de la famille calibree (sinon il reste affiche dans la fenetre Courbe, derniere calibration rapide)
    $toFields = (-not $cal.Home) -or ((Get-WriteTabFamily) -eq $cal.Family)
    if ($toFields) {
        if ($cmbWProfile.SelectedIndex -ne 0) { $cmbWProfile.SelectedIndex = 0 }   # Auto : profil decale remplace au prochain changement d image
        Set-LevelFields $recs $cal.Slow
    }
    $lvlTxt = (@($recs | ForEach-Object { Get-LevelLabel $_ })) -join ', '
    $sv = @($cal.Units | ForEach-Object { [string]$_.Shape.Verdict })
    $shapeTxt = if ($sv -contains 'mismatch') { (T 'NON CONFORME') } elseif ($verdicts -contains 'sat' -or $verdicts -contains 'low') { ((T 'non vérifiée (limite de 0 ou {0} ns atteinte)') -f "$($script:CalHardNs)") } elseif ($verdicts -contains 'few') { (T 'non vérifiée (trop peu de cylindres mesurés)') } elseif ($sv -contains 'approx') { (T 'approximative') } else { (T 'conforme') }
    $lblWCal.Text = ((T "Calibration rapide terminée en {0} : niveau {1}, forme {2}.") -f (Format-CalDuration $elapsed), "$lvlTxt", "$shapeTxt")
    if ($toFields) { $lblWProfileInfo.Text = ((T "Profil {0} de cette disquette (calibration rapide du {1}, lecteur {2}) : référence du {3} décalée de {4}. À n'utiliser que pour cette disquette (bouton Courbe).") -f "$famTxt", "$date", "$($cal.Drive)", "$($recs[0].RefDate)", "$lvlTxt") }
    else { Append-Log ((T "Calibration rapide depuis l'Accueil : l'image de l'onglet Écriture n'est pas de la famille {0}, le profil de cette disquette n'est pas placé dans ses champs --precomp ; il reste affiché dans la fenêtre Courbe (dernière calibration rapide).") -f "$famTxt") }
    Append-Log ((T "Calibration rapide terminée en {0} : {1} passe(s), {2} écritures de piste sur {3} cylindres (2 faces), aucune ailleurs.") -f (Format-CalDuration $elapsed), "$($cal.PassesDone)", "$($cal.TrackWrites)", "$(@($cal.Cyls).Count)")
    Append-Log ((T "Niveau retenu : {0}.") -f "$lvlTxt")
    foreach ($rec in $recs) { $pp = if ($null -eq $rec.Head) { '' } else { (T '[tête {0}] ') -f "$($rec.Head)" }; Append-Log ((T "{0}Profil {1} de cette disquette : {2}") -f "$pp", "$famTxt", "$($rec.Spec)") }
    if ($script:Restore) {
        $r = $script:Restore
        $cn = $false
        $base = if ($r.CalibUsed) { ((T "calibration existante ({0}), pas de recalibration") -f "$($r.CalibUsed.Text)") + $(if ($r.CalibUsed.Notes.Count -gt 0) { ' ; ' + ($r.CalibUsed.Notes -join ' ; ') } else { '' }) }
                elseif ($r.CalSwap) {
                    # Calibration faite pendant cette restauration, sur une disquette sacrifiee : sa non-convergence reste signalee
                    $fo = Get-ImageFamily $r.Orig
                    $cn = (@(@(0, 1) | Where-Object { $cvn = $script:PrecompCurves["${fo}_h$_"]; $cvn -and $cvn.Converged -eq $false }).Count -gt 0)
                    $am = @(@(0, 1) | ForEach-Object { $script:PrecompCurves["${fo}_h$_"] } | Where-Object { Test-CurveAtMax $_ })
                    $bt = if ($cn) { (T 'faite, non convergée sur une tête : voir le journal') } else { (T "faite sur une disquette sacrifiée ({0})") -f "$($r.Calib)" }
                    if ($am.Count -gt 0) { $bt += ' ; ' + ((T "courbe au plafond de {0} ns de son calcul") -f "$(Get-CurveMaxNs $am[0])"); $cn = $true }
                    $bt
                } else { '' }
        $lt = (T "niveau mesuré sur la destination : {0} ({1} passe(s))") -f "$lvlTxt", "$($cal.PassesDone)"
        if ($shapeTxt -eq (T 'approximative')) { $lt += ' ; ' + ((T "forme {0}") -f "$shapeTxt") }
        if ($issues.Count -gt 0) { $lt += ' ; ' + ($issues -join ' ; ') }
        $r.Level = @{ State = $(if ($issues.Count -gt 0 -or $cn -or ($r.CalibUsed -and $r.CalibUsed.Notes.Count -gt 0)) { 'warn' } else { 'ok' }); Text = $(if ($base) { "$base ; $lt" } else { $lt }); Report = $lt }
    }
    if ($issues.Count -gt 0) {
        Append-Log ((T "Calibration : résultat douteux ({0}) : courbe affichée, décision demandée.") -f ($issues -join ' ; '))
        if ($script:Restore) { $script:Restore.InCall = $true }
        # Carte Calibration de l Accueil sans profil dans les champs --precomp : textes de la decision sans ces champs
        $noFields = ([bool]$cal.Home -and -not $toFields)
        try { $choice = Show-CalibReview $cal @($issues) $toWrite ([bool]($cal.CanFallback -or -not $toWrite)) $noFields }
        finally { if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
        if ($choice -eq 'stop') {
            # Resultat refuse : niveaux precedents retablis, champs ramenes a la reference
            foreach ($k in @($prevRecs.Keys)) { if ($prevRecs[$k]) { $script:LevelShifts[$k] = $prevRecs[$k] } else { $script:LevelShifts.Remove($k) } }
            if (-not $script:Restore) { [void](Save-Config) }
            if ($cmbWProfile.SelectedIndex -ne $fieldsPrev.Prof) { $cmbWProfile.SelectedIndex = $fieldsPrev.Prof }
            Update-PrecompForImage $txtWFile.Text
            $chkWPrecomp.Checked = $fieldsPrev.On; $txtWPrecomp.Text = $fieldsPrev.P0; $txtWPrecomp1.Text = $fieldsPrev.P1; $lblWProfileInfo.Text = $fieldsPrev.Lbl
            if ($script:Restore) { $script:Restore.Level = $null }     # niveau refuse : absent de l etape 4 et du rapport
            $pbWCal.Visible = $false
            if ($noFields) { $lblWCal.Text = (T 'Calibration rapide abandonnée.'); Append-Log (T 'Calibration rapide abandonnée à votre demande : niveau non conservé.') }
            else {
                $lblWCal.Text = (T 'Calibration rapide abandonnée : champs --precomp rétablis.')
                Append-Log (T 'Calibration rapide abandonnée à votre demande : niveau non conservé, champs --precomp rétablis.')
            }
            if ($toWrite) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : résultat de calibration refusé.'); if ($script:Restore) { Stop-Restore (T 'résultat de calibration refusé') } }
            return
        }
        if ($choice -eq 'full') { Start-LevelFallback $cal ($issues -join ' ; ') $toWrite $noFields; return }
        Append-Log (T 'Calibration : résultat accepté malgré les réserves.')
    }
    if ($toWrite) {
        $script:AfterCalib = ''
        Append-Log (T 'Calibration rapide terminée : écriture de l''image avec le niveau mesuré.')
        if ($script:Restore) { $script:Restore.InCall = $true }
        # Prechauffage passe pendant la calibration (bouton « Passer le prechauffage ») : pas de second prechauffage
        try { Start-ImageWrite -NoWarmup:([bool]$cal.WarmSkip) } finally { if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
        if ($script:Restore -and -not ($script:GwProc -and -not $script:GwProc.HasExited) -and $script:Chain.Count -eq 0) { Stop-Restore (T 'l''écriture n''a pas démarré après la calibration, voir le journal') }
        # Le profil decale ne vaut que pour cette disquette : remplace par celui de la reference quand l ecriture (controle
        # apres ecriture compris) est terminee (minuterie principale) ; positionne apres Start-ImageWrite, qui peut ouvrir
        # une fenetre avant de lancer gw
        if (-not $script:Restore) { $script:LevelFieldsPending = $true }
        return
    }
    $pbWCal.Visible = $false
    Show-PrecompCurve $cal.Family $cal.Slow
}

function Start-LevelFallback($cal, [string]$why, [bool]$toWrite, [bool]$noFields = $false) {
    # Calibration complete en test fin a la demande de l utilisateur, apres une calibration rapide douteuse : elle
    # devient la nouvelle reference ; sur disquette sacrifiee, le niveau de la disquette a ecrire est mesure ensuite.
    # noFields : calibration rapide de l Accueil dont le profil n est pas dans les champs --precomp (Complete-LevelCalib)
    Append-Log ((T "Calibration complète demandée après la calibration rapide ({0}).") -f "$why")
    $introFmt = if ($noFields) { (T "La calibration rapide ne convient pas à cette disquette ({0}).`nCalibration complète en test fin ci-dessous : elle devient la nouvelle référence de forme du lecteur {1}. Annuler : rien de plus n'est écrit.") }
                else { (T "La calibration rapide ne convient pas à cette disquette ({0}).`nCalibration complète en test fin ci-dessous : elle devient la nouvelle référence de forme du lecteur {1}. Annuler : rien de plus n'est écrit ; le profil décalé reste dans les champs --precomp.") }
    $intro = ($introFmt -f "$why", "$($cal.Drive)") + "`n`n"
    # Carte Calibration de l Accueil : meme type de disquette (image de geometrie), et non l image de l onglet Ecriture
    if ($cal.Home) {
        Start-PrecompCalib -ForceFine -Intro $intro -Geom $cal.Geom -Heads ([bool]$cal.Slow)
        if ($script:Cal) { $script:HomeCalBusy = $true }
        return
    }
    if ($toWrite) { $script:AfterCalib = 'write' }
    Start-PrecompCalib -ForceFine -Intro $intro -LevelAfter:$toWrite
    if (-not $script:Cal -and $toWrite) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : la calibration n''a pas été lancée.') }
}

function Start-LevelBeforeWrite([string]$mode, [switch]$Restore) {
    # Ecriture depuis la Bibliotheque ou restauration avec « Test rapide » : niveau mesure sur la disquette a ecrire ;
    # sans reference utilisable, calibration complete en test fin d abord (sauf en restauration : jamais refaite)
    $img = $txtWFile.Text
    $fam = Get-ImageFamily $img
    $nfc = Get-CalibCylinders $img $cmbWFmt.Text      # image secteur sans geometrie : cylindres du format choisi
    $lr = Get-LevelRef $fam ($mode -eq 'slow') $cmbDrive.Text $img ([bool]$Restore) -NCyl $(if ($null -ne $nfc.NCyl) { [int]$nfc.NCyl } else { 0 })
    if ($lr.Ok) {
        $script:AfterCalib = 'write'
        if ($Restore) { Append-Log (T 'Restauration : niveau mesuré sur la disquette de destination (test rapide), la calibration du lecteur n''est pas refaite.') }
        Start-LevelCalib $lr -NoFallback:([bool]$Restore)
        if (-not $script:Cal) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : la calibration rapide n''a pas été lancée.') }
        return
    }
    if ($Restore) {
        Append-Log ((T "Restauration : niveau non mesuré ({0}) : écriture avec la calibration existante.") -f "$($lr.Why)")
        if ($script:Restore) { $script:Restore.LevelNote = $lr.Why }
        Start-ImageWrite; return
    }
    # Hors domaine : ecriture avec la courbe du lecteur, sauf si elle est plus courte que l image (gw appliquerait la valeur
    # de son dernier cylindre a tous les suivants) : calibration complete, comme sans reference
    if ($lr.Class -eq 'domain' -and -not $lr.Short) {
        Append-Log ((T "Calibration rapide non applicable à cette image : {0}. Écriture avec la courbe du lecteur, sans mesure du niveau.") -f "$($lr.Why)")
        Start-ImageWrite; return
    }
    Append-Log ((T "Calibration rapide impossible : {0}. Calibration complète en test fin d'abord : elle devient la référence de forme du lecteur.") -f "$($lr.Why)")
    $intro = ((T "Calibration rapide impossible : {0}.`nCalibration complète en test fin ci-dessous : elle devient la référence de forme du lecteur {1}, reprise ensuite par la calibration rapide de chaque disquette. Une disquette sacrifiée en bon état, du même type que la disquette à écrire, donne la meilleure référence.") -f "$($lr.Why)", "$($cmbDrive.Text)") + "`n`n"
    $script:AfterCalib = 'write'
    Start-PrecompCalib -ForceFine -Intro $intro -LevelAfter
    if (-not $script:Cal) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : la calibration n''a pas été lancée.') }
}

function Start-LevelCalibButton {
    # Bouton « Calibrer » avec « Test rapide » : niveau de la disquette inseree, sans ecriture d image
    $chk = Test-CalibImage
    if (-not $chk) { return }
    $lr = Get-LevelRef $chk.Family ([bool]$chkWSlow.Checked) $cmbDrive.Text $chk.Img $false -NCyl ([int]$chk.NCyl)
    if ($lr.Ok) { $script:AfterCalib = ''; Start-LevelCalib $lr; return }
    if ($lr.Class -eq 'domain' -and -not $lr.Short) {
        [void][System.Windows.Forms.MessageBox]::Show(((T "Calibration rapide non applicable à cette image : {0}.") -f "$($lr.Why)"),(T 'Calibration precomp'),'OK','Information'); return
    }
    $q = [System.Windows.Forms.MessageBox]::Show(((T "Calibration rapide impossible : {0}.`n`nLa calibration rapide reprend la forme d'une calibration complète de ce lecteur. Lancer maintenant une calibration complète en test fin ? Elle devient la référence de forme du lecteur.") -f "$($lr.Why)"),(T 'Calibration precomp'),'OKCancel','Question')
    if ($q -eq 'OK') { $script:AfterCalib = ''; Start-PrecompCalib -ForceFine }
}

function Get-CurveLevelRecs($cv) {
    # Niveaux de la derniere calibration rapide faits sur cette courbe (meme date de reference, meme lecteur)
    if (-not $cv) { return ,@() }
    $key = @($script:CurveKeys | Where-Object { [object]::ReferenceEquals($script:PrecompCurves[$_], $cv) })
    if ($key.Count -eq 0) { return ,@() }
    $rs = @(@($script:LevelShifts.Values) | Where-Object { $_ -and $_.RefKey -eq $key[0] -and [string]$_.RefDate -eq [string]$cv.Date -and [string]$_.Drive -eq [string]$cv.Drive })
    if ($rs.Count -eq 0) { return ,@() }
    $latest = @($rs | Sort-Object { Get-CurveDate $_ } -Descending)[0].Date
    return ,@($rs | Where-Object { $_.Date -eq $latest } | Sort-Object { if ($null -eq $_.Head) { -1 } else { [int]$_.Head } })
}

function Set-CurveLevelData($cvs) {
    # Niveaux a superposer aux courbes affichees (index de la courbe -> enregistrements)
    $script:CurveLevel = @{}
    $i = 0
    foreach ($cv in @($cvs)) { $script:CurveLevel[$i] = Get-CurveLevelRecs $cv; $i++ }
}

function Get-CalibCylinders([string]$img, [string]$fmt) {
    # Cylindres d une image pour la calibration : lus dans l image (ADF, IPF, HFE) ; image secteur sans geometrie (IMG, ST,
    # DSK...) avec un format gw explicite de la table : cylindres de sa definition, 35 au moins comme la carte Calibration
    # de l Accueil (Get-FormatCalibInfo : une courbe de famille de 15 cylindres serait appliquee a toutes les images de 80) ;
    # sinon NCyl = $null (80 par defaut)
    $n = Get-ImageCylinders $img
    if ($null -ne $n) { return @{ NCyl = [int]$n; Src = ((T "{0} cylindres d'après l'image") -f "$n") } }
    if ($fmt -and $fmt -ne '(auto)' -and $script:GwFormats.Contains($fmt)) {
        $d = [int]$script:GwFormats[$fmt].Cyls; $c = [math]::Max(35, $d)
        if ($c -ne $d) { return @{ NCyl = $c; Src = ((T "{0} cylindres pour le format {1} ({2} dans la définition de gw, {0} au moins pour la calibration)") -f "$c", "$fmt", "$d") } }
        return @{ NCyl = $c; Src = ((T "{0} cylindres d'après le format {1}") -f "$c", "$fmt") }
    }
    return @{ NCyl = $null; Src = (T '80 cylindres par défaut (nombre non lisible dans l''image)') }
}

function Test-CalibImage($Geom = $null) {
    # Controles communs a la calibration complete et a la calibration rapide (memes messages) ; $null si refus. Geom :
    # type de disquette de la carte Calibration de l Accueil (image de geometrie de New-CalibGeometry, sans format gw) a la
    # place de l image et du format de l onglet Ecriture. Format gw explicite de la table non calibrable (FM, GCR, codage
    # propre, secteurs durs, 360 tr/min, cellule hors plage : Get-FormatCalibInfo) : refus.
    if (-not $script:ScpStatsOk) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Calibration : module d''analyse SCP indisponible (Add-Type).'),(T 'Calibration precomp'),'OK','Warning'); return $null
    }
    if (-not (Test-Path -LiteralPath $script:GwExe)) {
        [void][System.Windows.Forms.MessageBox]::Show(((T "gw.exe introuvable : {0}`n`nPlacez ce script dans le même répertoire que gw.exe.") -f "$($script:GwExe)"),(T 'Erreur'),'OK','Error'); return $null
    }
    $img = if ($Geom) { [string]$Geom.Img } else { $txtWFile.Text }
    $fmt = if ($Geom) { '' } else { $cmbWFmt.Text }
    if (-not $img -or -not (Test-Path -LiteralPath $img)) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Choisissez d''abord l''image à écrire : elle fixe la famille (cellule) et le nombre de cylindres de la calibration.'),(T 'Calibration precomp'),'OK','Warning'); return $null
    }
    $ext = [System.IO.Path]::GetExtension($img).ToLower()
    if (@('.scp', '.raw', '.kf', '.a2r', '.ctr') -contains $ext) {
        [void][System.Windows.Forms.MessageBox]::Show(((T "Calibration impossible sur un flux ({0}) : la calibration ne détermine la densité que d'une image à bits ou secteurs (ADF, IPF, HFE, IMG...).") -f "$ext"),(T 'Calibration precomp'),'OK','Warning'); return $null
    }
    $hd = Get-HighDensityReason $img $fmt
    if ($hd) {
        [void][System.Windows.Forms.MessageBox]::Show(((T "Calibration non prise en charge pour une image haute densité ({0}) : les profils calibrés sont ceux des familles double densité (standard 2 µs, long track 1,89 µs).") -f "$hd"),(T 'Calibration precomp'),'OK','Warning'); return $null
    }
    if ($chkWHard.Checked -or $chkWTG43.Checked) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Calibration non prise en charge avec secteurs durs ou lecteur 8 pouces (TG43) : l''analyse de flux est calibrée pour le MFM double densité.'),(T 'Calibration precomp'),'OK','Warning'); return $null
    }
    $oor = Get-CellOutOfRange $img
    if ($null -ne $oor) {
        [void][System.Windows.Forms.MessageBox]::Show(((T "Calibration non prise en charge : cellule de l'image de {0} ns, hors de la plage mesurable (1 700 à 2 300 ns, MFM double densité).") -f "$oor"),(T 'Calibration precomp'),'OK','Warning'); return $null
    }
    $fci = if ($fmt -and $fmt -ne '(auto)' -and $script:GwFormats.Contains($fmt)) { Get-FormatCalibInfo $fmt } else { $null }
    if ($fci -and -not $fci.Cal) {
        [void][System.Windows.Forms.MessageBox]::Show(((T "Calibration non prise en charge pour le format {0} : {1}.") -f "$fmt", "$($fci.Why)"),(T 'Calibration precomp'),'OK','Warning'); return $null
    }
    $family = Get-ImageFamily $img
    $cc = Get-CalibCylinders $img $fmt
    $nCyl = $cc.NCyl
    $cylSrc = if ($Geom) { [string]$Geom.CylSrc } else { [string]$cc.Src }
    if ($null -eq $nCyl) { $nCyl = 80 }
    $nCyl = [math]::Max(2, [math]::Min(84, [int]$nCyl))
    $maxCyl = $nCyl - 1
    $label = if ($Geom) { [string]$Geom.Label } else { [System.IO.Path]::GetFileName($img) }
    return @{ Img = $img; Family = $family; NCyl = $nCyl; MaxCyl = $maxCyl; CylSrc = $cylSrc; Label = $label }
}

function Start-PrecompCalib([switch]$ForceFine, [string]$Intro = '', [switch]$LevelAfter, $Geom = $null, $Heads = $null, [string]$Test = '', [switch]$NoWarmup) {
    # ForceFine : test fin impose (reference de la calibration rapide) ; Intro : texte place en tete de l avertissement ;
    # LevelAfter : apres une calibration sur disquette sacrifiee, le niveau de la disquette a ecrire est mesure.
    # Carte Calibration de l Accueil : Geom (type de disquette, image de geometrie), Heads (une courbe par tete) et Test
    # ('std' ou 'fine') a la place de l image, de la case Ecriture lente et du mode de l onglet Ecriture ; NoWarmup :
    # prechauffage du lecteur desactive pour cette calibration (case de la fenetre de la carte)
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    $script:Cal = $null
    $chk = Test-CalibImage $Geom
    if (-not $chk) { return }
    $img = $chk.Img; $family = $chk.Family; $nCyl = $chk.NCyl; $maxCyl = $chk.MaxCyl; $cylSrc = $chk.CylSrc
    $fine = ([bool]$ForceFine -or $(if ($Test) { $Test -eq 'fine' } else { $cmbWCalMode.SelectedIndex -eq 1 }))
    $slow = if ($null -ne $Heads) { [bool]$Heads } else { [bool]$chkWSlow.Checked }
    if ($fine) { $cyls = @(0..$maxCyl) }
    else { $cyls = @(0..$maxCyl | Where-Object { $_ % 10 -eq 0 }); if ($cyls -notcontains $maxCyl) { $cyls += $maxCyl } }
    $cyls = @($cyls | Sort-Object -Unique)
    $nPassEst = $script:CalCoarse.Count + $script:CalMaxVerify
    # Duree estimee : passes d ecriture et de relecture, plus le prechauffage du lecteur (borne haute : il est reduit ou
    # saute si le lecteur vient de servir, plan recalcule apres l avertissement par Start-CalibWarmup)
    $wu = if ($NoWarmup) { 0.0 } else { [math]::Max(0.0, [double]$script:CalWarmupMinutes) }
    $minutes = [math]::Max(1, [math]::Round($cyls.Count * 2 * 1.4 * $nPassEst / 60 + $wu, 0))
    $modeTxt = if ($fine) { (T 'test fin, tous les cylindres') } else { (T 'test standard, un cylindre sur 10') }
    if ($slow) { $modeTxt += (T ', une courbe par tête (écriture lente)') }
    $famTxt = Get-CalibFamilyName $family
    $cylList = Format-CylList $cyls
    $script:AlignLoop = $false; $script:AlignNextAt = $null
    # Avertissement (usure du support) : validation automatique au bout du delai ; avant une ecriture, case « disquette
    # sacrifiee » : la disquette a ecrire est redemandee apres la calibration (Complete-PrecompCalib)
    $toWrite = ($script:AfterCalib -eq 'write')
    $target = if ($script:Restore) { (T 'la disquette de destination') } else { (T 'la disquette à écrire') }
    $auto = if ($toWrite) { (T "Calibration automatique avant l'écriture : la disquette insérée reçoit d'abord le motif de test, puis l'image.") + "`n`n" } else { '' }
    $bodyFmt = if ($Geom) { (T "Calibration de la précompensation sur le lecteur {0} ({1}).`n`nType de disquette : {2}, famille {3}, {4}.`nMotif de test : données pseudo-aléatoires générées à la densité de ce type.`nCylindres de test : {5} (2 faces), ÉCRASÉS à chaque passe. Durée estimée : {6} min pour {7} passes.") }
               else { (T "Calibration de la précompensation sur le lecteur {0} ({1}).`n`nImage : {2}, famille {3}, {4}.`nMotif de test : données pseudo-aléatoires générées à la densité de l'image, son contenu n'est pas écrit.`nCylindres de test : {5} (2 faces), ÉCRASÉS à chaque passe. Durée estimée : {6} min pour {7} passes.") }
    $body = $bodyFmt -f "$($cmbDrive.Text)", "$modeTxt", "$($chk.Label)", "$famTxt", "$cylSrc", "$cylList", "$minutes", "$nPassEst"
    if ($wu -gt 0) { $body += "`n" + ((T "Préchauffage du lecteur avant la première passe : jusqu'à {0} de lecture sans écriture (moins si le lecteur vient de servir), compris dans la durée estimée.") -f (Format-CalDuration (60 * $wu))) }
    # Courbe remplacee d un autre nombre de cylindres (plus de 4 d ecart, seuil de Get-LevelRef) : la nouvelle s applique
    # ensuite a toutes les images de la famille (meme phrase que la fenetre de la carte Calibration de l Accueil)
    $cvr = $script:PrecompCurves[$(if ($slow) { "${family}_h0" } else { $family })]
    if ($cvr -and [math]::Abs(@($cvr.Values).Count - $nCyl) -gt 4) { $body += "`n" + ((T "La courbe actuelle couvre {0} cylindres : elle sera remplacée par une courbe de {1} cylindres, appliquée à toutes les images de la famille {2}.") -f "$(@($cvr.Values).Count)", "$nCyl", "$famTxt") }
    # Passes supplementaires possibles : encadrement (1), mesures complementaires du test standard (2, 30 cylindres au plus)
    $nPassMax = $nPassEst + 1 + $(if ($fine) { 0 } else { 2 })
    $extra = if ($fine) { (T 'si la courbe demande un encadrement') } else { (T 'si la courbe demande un encadrement ou des mesures complémentaires (30 cylindres au plus)') }
    $wear = (T "ATTENTION : la calibration écrit le motif de test sur les mêmes pistes à chaque passe ({0} passes prévues, jusqu'à {1} {2}). Ces écritures répétées sollicitent le support magnétique et peuvent le fatiguer.") -f "$nPassEst", "$nPassMax", "$extra"
    $choice = if ($toWrite) { (T "Pour épargner {0}, cochez la case ci-dessous (le compte à rebours s'arrête), remplacez-la par une disquette sacrifiée (sans valeur, jamais l'original), puis cliquez sur « Lancer la calibration » : après la calibration, l'application vous demandera de remettre {0}. Sinon, la calibration utilise la disquette insérée.") -f "$target" }
              else { (T 'Insérez de préférence une disquette sacrifiée (vierge ou sans valeur), puis validez.') }
    $swapLabel = if ($toWrite) { (T "J'ai inséré une disquette sacrifiée : me redemander {0} après la calibration") -f "$target" } else { '' }
    $ans = Show-CalibConfirm ($Intro + $auto + $body + "`n`n" + $wear + "`n`n" + $choice) $swapLabel
    if (-not $ans.Ok) { return }
    if ($ans.Auto) { Append-Log ((T "Calibration : avertissement validé automatiquement après {0} s sans réponse.") -f "$($script:CalibConfirmSeconds)") }
    if ($ans.Swap) { Append-Log ((T "Calibration sur une disquette sacrifiée : {0} sera redemandée avant l'écriture.") -f "$target") }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    try { $pat = New-CalibPattern $family $img $nCyl }
    catch { [void][System.Windows.Forms.MessageBox]::Show(((T "Calibration : motif de test impossible à créer : {0}") -f "$($_.Exception.Message)"),(T 'Calibration precomp'),'OK','Error'); return }
    # Ecriture lente : une unite par tete (mesures, courbe et verification separees) ; sinon une unite pour les deux tetes
    # @() autour du if : une seule unite resterait sinon une hashtable nue ($cal.Units[0] = $null)
    $units = @(if ($slow) { (New-CalibUnit 0), (New-CalibUnit 1) } else { New-CalibUnit $null })
    foreach ($u in $units) { foreach ($c in $cyls) { $u.Results[[int]$c] = @{} } }
    $script:Cal = @{
        Mode = $(if ($fine) { 'fine' } else { 'std' }); Cyls = $cyls; MaxCyl = $maxCyl; Family = $family; Slow = $slow
        Image = $img; Pattern = $pat.Path; PatternBits = $pat.Bits; MaxCoarse = 200; Drive = $cmbDrive.Text; TSpec = "c=${cylList}:h=0-1"; CylList = $cylList
        Stage = 'coarse'; Values = @($script:CalCoarse); Index = 0; Value = 0; ValueTxt = ''; Spec = ''
        Units = $units; VerifyCount = 0; Swap = [bool]$ans.Swap; LevelAfter = [bool]$LevelAfter
        Scp = (Join-Path $script:TempDir 'precomp-calib.scp'); Writes = (New-Object System.Collections.Queue); ReadArgs = @()
        # Progression globale : passes faites / prevues, durees mesurees par phase, estimation initiale 0,7 s par piste et par phase
        StartTime = (Get-Date); PassStart = (Get-Date); PhaseStart = (Get-Date); Phase = 'write'
        PassesDone = 0; TotalPasses = $nPassEst; WriteDurs = @(); ReadDurs = @(); EstTrack = 0.7
        Home = [bool]$Geom; Geom = $Geom; NoWarmup = [bool]$NoWarmup   # carte Calibration de l Accueil
    }
    if ($Geom) {
        # Densite du type choisi (source de Get-FormatCalibInfo), et non « HFE, bits par piste de l image » de la geometrie
        if ($Geom.BitsSrc) { $pat.Source = [string]$Geom.BitsSrc }
        Append-Log ((T "=== Calibration precomp : lecteur {0}, type {1} ({2}, {3}) ===") -f "$($cmbDrive.Text)", "$($chk.Label)", "$famTxt", "$modeTxt")
        Append-Log ((T "Cylindres de test : {0} ({1})") -f "$cylList", "$cylSrc")
        Append-Log ((T "Motif de test : HFE de données pseudo-aléatoires généré, {0} cylindres, {1} cellules par piste ({2}), soit {3} ns par cellule à 300 tr/min, d'après le type de disquette choisi.") -f "$nCyl", "$($pat.Bits)", "$($pat.Source)", "$([math]::Round($pat.CellNs, 1))")
    } else {
        Append-Log ((T "=== Calibration precomp : lecteur {0}, image {1} ({2}, {3}) ===") -f "$($cmbDrive.Text)", "$([System.IO.Path]::GetFileName($img))", "$famTxt", "$modeTxt")
        Append-Log ((T "Cylindres de test : {0} ({1})") -f "$cylList", "$cylSrc")
        Append-Log ((T "Motif de test : HFE de données pseudo-aléatoires généré, {0} cylindres, {1} cellules par piste ({2}), soit {3} ns par cellule à 300 tr/min. L'image ne fixe que la densité et le nombre de cylindres, son contenu n'est pas écrit.") -f "$nCyl", "$($pat.Bits)", "$($pat.Source)", "$([math]::Round($pat.CellNs, 1))")
    }
    $pbWCal.Value = 0; $pbWCal.Visible = $true; $lblWCal.Visible = $true
    Update-CalibProgress
    Start-CalibWarmup      # prechauffage du lecteur s il y a lieu, puis premiere passe de mesure
}

function Format-CalDuration([double]$sec) {
    if ($sec -lt 0) { $sec = 0 }
    $m = [math]::Floor($sec / 60); $s = [math]::Round($sec - 60 * $m, 0)
    if ($m -gt 0) { return "$m min $('{0:00}' -f $s) s" }
    return "$s s"
}

function Update-CalibProgress {
    # Barre globale : passes terminees + fraction de la passe en cours, d apres les durees moyennes
    # mesurees (ecriture et relecture separees) ; avant toute mesure, 0,7 s par piste et par phase.
    $cal = $script:Cal
    if (-not $cal) { return }
    # Libelles au format court du prechauffage de l ecriture : avancement et temps restant en tete, details ensuite entre
    # parentheses (libelle coupe a la largeur de l onglet a la taille minimale de la fenetre)
    if ($cal.Stage -eq 'warmup') {
        # Prechauffage : duree ecoulee sur la duree prevue (Get-WarmupLeft) ; passe a la demande : fin de la lecture en cours
        $g = Get-WarmupLeft $cal
        $pbWCal.Value = $g.Pct
        $lblWCal.Text = if ($cal.WarmSkip) { (T 'Préchauffage du lecteur {0} passé : fin de la lecture en cours.') -f "$($cal.Drive)" }
                        else { (T "Préchauffage avant la calibration : {2} %, reste environ {3} (lecteur {0}, lecture {1}, sans écriture)") -f "$($cal.Drive)", "$($cal.WarmReads)", "$($g.Pct)", (Format-CalDuration ([math]::Round($g.Left))) }
        return
    }
    $nTracks = $cal.Cyls.Count * 2
    $avgW = if ($cal.WriteDurs.Count -gt 0) { ($cal.WriteDurs | Measure-Object -Average).Average } else { $nTracks * $cal.EstTrack }
    $avgR = if ($cal.ReadDurs.Count -gt 0)  { ($cal.ReadDurs  | Measure-Object -Average).Average } else { $nTracks * $cal.EstTrack }
    if ($avgW -lt 1) { $avgW = 1 }; if ($avgR -lt 1) { $avgR = 1 }
    $pass = $avgW + $avgR
    $elapsed = ((Get-Date) - $cal.PhaseStart).TotalSeconds
    $frac = if ($cal.Phase -eq 'write') { [math]::Min(0.98, $elapsed / $avgW) * ($avgW / $pass) }
            else { ($avgW / $pass) + [math]::Min(0.98, $elapsed / $avgR) * ($avgR / $pass) }
    $total = [math]::Max(1, [int]$cal.TotalPasses)
    $done = [math]::Min($total, $cal.PassesDone + $frac)
    $pct = [int][math]::Floor(100 * $done / $total)
    $remaining = $pass * ($total - $done)
    $phaseTxt = if ($cal.Phase -eq 'write') { (T 'écriture') } else { (T 'relecture') }
    $pbWCal.Value = [math]::Max(0, [math]::Min(100, $pct))
    $fmt = if ($cal.Mode -eq 'level') { (T "Calibration rapide : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") } else { (T "Calibration : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
    $lblWCal.Text = ($fmt -f "$([math]::Min($total, $cal.PassesDone + 1))", "$total", "$($cal.ValueTxt)", "$phaseTxt", "$pct", (Format-CalDuration $remaining))
}

function Stop-PrecompCalib {
    # Abandon (bouton Arreter, erreur gw, fichier manquant) : etat remis a zero, barre masquee
    $script:Cal = $null
    $pbWCal.Visible = $false
    $lblWCal.Text = (T 'Calibration precomp interrompue.')
    Append-Log (T 'Calibration precomp interrompue.')
    if ($script:AfterCalib) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : calibration interrompue.') }
    if ($script:Restore) { Stop-Restore (T 'calibration interrompue') }
}

function Get-CalWarmupPlan([string]$key, [double]$minutes) {
    # Duree du prechauffage (s) pour le lecteur 'peripherique|lecteur' : reglage en minutes, reduit de la duree de la
    # derniere serie d activite continue du lecteur si sa derniere commande gw qui a fait tourner le moteur (code 0, ou au
    # moins une piste lue ou ecrite : une commande en echec immediat ne compte pas) s est terminee il y a moins de
    # CalWarmupGapMin (Active, Idle : depuis cette fin) ; Skip : il en reste moins de CalWarmupSkipMin. Reduced : duree
    # annoncee comme reduite (activite d au moins 1 s une fois arrondie : une commande tres courte, gw rpm ou nettoyage
    # arrete tout de suite, ne raccourcit le prechauffage que d une fraction de seconde)
    $p = @{ Sec = [math]::Max(0.0, 60.0 * $minutes); Recent = $false; Active = 0.0; Idle = 0.0; Skip = $false; Reduced = $false }
    if ($p.Sec -le 0) { return $p }
    $a = if ($key) { $script:DriveActivity[$key] } else { $null }
    if (-not $a -or $a.Start -isnot [datetime] -or $a.End -isnot [datetime]) { return $p }
    $idle = ((Get-Date) - $a.End).TotalSeconds
    if ($idle -ge 60.0 * $script:CalWarmupGapMin) { return $p }
    $p.Recent = $true; $p.Idle = [math]::Max(0.0, $idle); $p.Active = [math]::Max(0.0, ($a.End - $a.Start).TotalSeconds)
    $p.Sec = [math]::Max(0.0, $p.Sec - $p.Active)
    $p.Reduced = ([math]::Round($p.Active) -ge 1)
    if ($p.Sec -lt 60.0 * $script:CalWarmupSkipMin) { $p.Skip = $true }
    return $p
}

function Get-WarmupLeft($w) {
    # Prechauffage (calibration ou ecriture lente) : avancement (%) et temps restant (s) ; la lecture en cours peut depasser
    # la duree prevue (duree moyenne des lectures)
    $now = Get-Date
    $el = ($now - $w.WarmStart).TotalSeconds
    $left = [math]::Max(0.0, $w.WarmSec - $el)
    if (@($w.WarmDurs).Count -gt 0 -and $w.WarmReadStart -is [datetime]) {
        $avg = (@($w.WarmDurs) | Measure-Object -Average).Average
        $left = [math]::Max($left, $avg - ($now - $w.WarmReadStart).TotalSeconds)
    }
    $pct = [int][math]::Floor(100 * $el / [math]::Max(1.0, $el + $left))
    return @{ Pct = [math]::Max(0, [math]::Min(100, $pct)); Left = $left }
}

function Start-CalibWarmup {
    # Prechauffage du lecteur avant la premiere passe de mesure d une calibration complete (Start-PrecompCalib, apres
    # l avertissement et la remise eventuelle de la disquette sacrifiee) : lectures sans ecriture des cylindres de test,
    # deux tetes, vers un fichier temporaire, en boucle jusqu a la duree (Get-CalWarmupPlan). Etape 'warmup' de la
    # calibration : « Arreter » l interrompt comme une passe ; une lecture en echec (disquette vierge ou illisible) est
    # sans effet (GwSoft) ; seul l echec du lancement de gw arrete la calibration (Start-Gw, Reset-GwSequence). Apres
    # CalWarmupMaxFails lectures de suite sans aboutir (code non nul, ou code 0 et lecture incomplete : Greaseweazle,
    # lecteur ou disquette absent), le prechauffage est abrege et la calibration commence (Invoke-CalibWarmup).
    # Aussi appele par Start-LevelCalib avant une ecriture lente (mode 'level') : retour a l etape d appel (WarmNext).
    # Bouton « Passer le prechauffage » : fin apres la lecture en cours (WarmSkip).
    $cal = $script:Cal
    if (-not $cal) { return }
    if ([double]$script:CalWarmupMinutes -le 0) { New-CalibPass; return }
    # Case « Prechauffer » decochee dans la fenetre de la carte Calibration (Start-PrecompCalib -NoWarmup)
    if ($cal.NoWarmup) { Append-Log ((T "Préchauffage du lecteur {0} désactivé pour cette calibration.") -f "$($cal.Drive)"); New-CalibPass; return }
    $plan = Get-CalWarmupPlan (Get-GwDriveKey (@('read') + (Get-CommonArgs))) ([double]$script:CalWarmupMinutes)
    $actTxt = Format-CalDuration ([math]::Round($plan.Active)); $idleTxt = Format-CalDuration ([math]::Round($plan.Idle))
    if ($plan.Skip) {
        Append-Log ((T "Préchauffage du lecteur {0} sauté : lecteur déjà en activité pendant {1} (dernière commande terminée il y a {2}).") -f "$($cal.Drive)", "$actTxt", "$idleTxt")
        New-CalibPass; return
    }
    $durTxt = Format-CalDuration ([math]::Round($plan.Sec))
    if ($cal.Mode -eq 'level') {
        if ($plan.Reduced) { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la calibration rapide et l'écriture lente, pour que le niveau soit mesuré dans l'état du lecteur au moment de l'écriture (durée réduite : lecteur déjà en activité pendant {2}, dernière commande terminée il y a {3}).") -f "$($cal.Drive)", "$durTxt", "$actTxt", "$idleTxt") }
        else { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la calibration rapide et l'écriture lente, pour que le niveau soit mesuré dans l'état du lecteur au moment de l'écriture.") -f "$($cal.Drive)", "$durTxt") }
    }
    elseif ($plan.Reduced) { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la calibration, pour stabiliser sa température (durée réduite : lecteur déjà en activité pendant {2}, dernière commande terminée il y a {3}).") -f "$($cal.Drive)", "$durTxt", "$actTxt", "$idleTxt") }
    else { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la calibration, pour stabiliser sa température.") -f "$($cal.Drive)", "$durTxt") }
    $cal.WarmNext = [string]$cal.Stage
    $cal.Stage = 'warmup'; $cal.WarmSec = [double]$plan.Sec; $cal.WarmStart = Get-Date; $cal.WarmReads = 0; $cal.WarmFails = 0
    $cal.WarmFailRun = 0; $cal.WarmSkip = $false
    $cal.WarmDurs = @(); $cal.WarmReadStart = $null
    $cal.WarmScp = Join-Path $script:TempDir 'precomp-warmup.scp'
    $cal.WarmArgs = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @('--revs=3', "--tracks=$($cal.TSpec)", "`"$($cal.WarmScp)`"")
    Invoke-CalibWarmup
}

function Invoke-CalibWarmup {
    # Lecture de prechauffage suivante, ou premiere passe de mesure : CalWarmupMinReads lectures au moins, puis arret a la
    # duree, ou avant une lecture qui la depasserait de plus de la moitie de la duree moyenne d une lecture. Lecture sans
    # aboutir : code non nul, ou code 0 et lecture incomplete (GwLastIncomplete) ; CalWarmupMaxFails de suite : defaut
    # materiel probable (Greaseweazle, lecteur ou disquette absent), prechauffage abrege, la calibration commence et sa
    # premiere ecriture signale le defaut s il persiste
    $cal = $script:Cal
    if (-not $cal -or $cal.Stage -ne 'warmup') { return }
    if ($cal.WarmReadStart -is [datetime]) {
        $cal.WarmDurs += ((Get-Date) - $cal.WarmReadStart).TotalSeconds; $cal.WarmReadStart = $null
        $code = [int]$script:GwLastCode
        if ($code -ne 0 -or [bool]$script:GwLastIncomplete) {
            $cal.WarmFails++; $cal.WarmFailRun++
            if ($cal.WarmFails -eq 1) { Append-Log ((T "Préchauffage du lecteur {0} : la lecture n'a pas abouti (code {1}) ; sans effet sur la calibration, le préchauffage continue.") -f "$($cal.Drive)", "$code") }
        } else { $cal.WarmFailRun = 0 }
        if ($cal.WarmFailRun -ge $script:CalWarmupMaxFails) {
            if (Test-Path -LiteralPath $cal.WarmScp) { Remove-Item -LiteralPath $cal.WarmScp -Force -ErrorAction SilentlyContinue }
            Append-Log ((T "Préchauffage du lecteur {0} arrêté après {1} lectures de suite sans aboutir (Greaseweazle, lecteur ou disquette absent ?) : la calibration commence, sa première écriture signalera le défaut s'il persiste.") -f "$($cal.Drive)", "$($cal.WarmFailRun)")
            $cal.Stage = if ($cal.WarmNext) { [string]$cal.WarmNext } else { 'coarse' }
            New-CalibPass; return
        }
    }
    $left = $cal.WarmSec - ((Get-Date) - $cal.WarmStart).TotalSeconds
    $avg = if (@($cal.WarmDurs).Count -gt 0) { (@($cal.WarmDurs) | Measure-Object -Average).Average } else { 0.0 }
    if (Test-Path -LiteralPath $cal.WarmScp) { Remove-Item -LiteralPath $cal.WarmScp -Force -ErrorAction SilentlyContinue }
    # Fin : duree atteinte, ou prechauffage passe a la demande (bouton « Passer le prechauffage », apres la lecture en cours)
    if (($cal.WarmSkip -and $cal.WarmReads -ge 1) -or ($cal.WarmReads -ge $script:CalWarmupMinReads -and ($left -le 0 -or $left -lt $avg / 2))) {
        $elTxt = Format-CalDuration ([math]::Round(((Get-Date) - $cal.WarmStart).TotalSeconds))
        if ($cal.WarmFails -gt 0) { Append-Log ((T "Préchauffage du lecteur {0} terminé : {1} lecture(s) en {2}, dont {3} sans aboutir (sans effet sur la calibration).") -f "$($cal.Drive)", "$($cal.WarmReads)", "$elTxt", "$($cal.WarmFails)") }
        else { Append-Log ((T "Préchauffage du lecteur {0} terminé : {1} lecture(s) en {2}.") -f "$($cal.Drive)", "$($cal.WarmReads)", "$elTxt") }
        $cal.Stage = if ($cal.WarmNext) { [string]$cal.WarmNext } else { 'coarse' }
        New-CalibPass; return
    }
    $cal.WarmReads++; $cal.WarmReadStart = Get-Date; $script:GwLastCode = 0; $script:GwLastIncomplete = $false
    Update-CalibProgress
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw ([string[]]$script:Cal.WarmArgs) })
    $script:Chain.Enqueue({ Invoke-CalibWarmup })
    Invoke-NextChainStep
}

function New-CalibPass {
    # Une passe = une ou deux commandes gw write puis une relecture en flux.
    #  - mesure : meme valeur pour tous les cylindres de test et les deux tetes, une commande ;
    #  - encadrement : cylindres encore sous-compenses a la plus forte valeur mesuree, ecrits a leur estimation +
    #    CalBracketMargin (une valeur par cylindre ; par tete en ecriture lente), relus seuls ;
    #  - verification : le profil obtenu ; en ecriture lente tete 0 puis tete 1, chacune avec son profil.
    $cal = $script:Cal
    $writes = @(); $readTs = $cal.TSpec
    if ($cal.Stage -eq 'coarse') {
        $cal.Value = [int]$cal.Values[$cal.Index]; $cal.Spec = "0=$($cal.Value)"; $cal.ValueTxt = "$($cal.Value) ns"
        Append-Log ((T "Calibration : passe de mesure {0}/{1}, precomp {2} ns") -f "$($cal.Index + 1)", "$($cal.Values.Count)", "$($cal.Value)")
        $writes += ,@($cal.TSpec, $cal.Spec)
    } elseif ($cal.Stage -eq 'bracket') {
        $cal.ValueTxt = (T 'encadrement')
        $all = @{}
        foreach ($u in $cal.Units) { foreach ($c in @($u.Bracket.Keys)) { $all[[int]$c] = $true } }
        $cyls = [int[]]@($all.Keys | Sort-Object)
        if ($cal.Slow) {
            foreach ($u in $cal.Units) { if ($u.Bracket.Count -gt 0) { $writes += ,@("c=$(Format-CylList ([int[]]@($u.Bracket.Keys))):h=$($u.Head)", (Get-BracketSpec $u.Bracket)) } }
        } else {
            $writes += ,@("c=$(Format-CylList $cyls):h=0-1", (Get-BracketSpec $cal.Units[0].Bracket))
        }
        $readTs = "c=$(Format-CylList $cyls):h=0-1"
        $specTxt = (@($cal.Units | ForEach-Object { "$($_.Prefix)$(Get-BracketSpec $_.Bracket)" } | Where-Object { $_ -match '=' })) -join ' ; '
        Append-Log ((T "Calibration : passe d'encadrement des cylindres {0}, encore sous-compensés à {1} ns : precomp {2}") -f (Format-CylList $cyls), "$($cal.MaxCoarse)", "$specTxt")
    } elseif ($cal.Stage -eq 'densify') {
        $cal.ValueTxt = (T "mesure complémentaire {0}") -f "$($cal.DensePass)"
        $all = @{}
        foreach ($u in $cal.Units) { foreach ($c in @($u.Dense.Keys)) { $all[[int]$c] = $true } }
        $cyls = [int[]]@($all.Keys | Sort-Object)
        if ($cal.Slow) {
            foreach ($u in $cal.Units) { if ($u.Dense.Count -gt 0) { $writes += ,@("c=$(Format-CylList ([int[]]@($u.Dense.Keys))):h=$($u.Head)", (Get-BracketSpec $u.Dense)) } }
        } else {
            $writes += ,@("c=$(Format-CylList $cyls):h=0-1", (Get-BracketSpec $cal.Units[0].Dense))
        }
        $readTs = "c=$(Format-CylList $cyls):h=0-1"
        $specTxt = (@($cal.Units | ForEach-Object { "$($_.Prefix)$(Get-BracketSpec $_.Dense)" } | Where-Object { $_ -match '=' })) -join ' ; '
        Append-Log ((T "Calibration : mesure complémentaire {0} des cylindres {1} : precomp {2}") -f "$($cal.DensePass)", (Format-CylList $cyls), "$specTxt")
    } elseif ($cal.Stage -eq 'level') {
        # Calibration rapide : reference decalee du niveau courant sur les seuls cylindres de mesure ; ecriture rapide une
        # commande (h=0-1), ecriture lente une commande par tete non terminee
        $all = @{}; $parts = @()
        foreach ($u in $cal.Units) {
            if ($u.Done) { continue }
            $lc = [int[]]@($u.LTarget.Keys | ForEach-Object { [int]$_ } | Sort-Object)
            foreach ($c in $lc) { $all[$c] = $true }
            $lv = '{0:+0;-0;0}' -f [int]$u.D
            if ($null -eq $u.Head) { $parts += ((T "niveau {0} ns") -f "$lv") } else { $parts += ((T "tête {0} {1} ns") -f "$($u.Head)", "$lv") }
            if ($cal.Slow) { $writes += ,@("c=$(Format-CylList $lc):h=$($u.Head)", (Get-BracketSpec $u.LTarget)); $cal.TrackWrites += $lc.Count }
            else { $writes += ,@("c=$(Format-CylList $lc):h=0-1", (Get-BracketSpec $u.LTarget)); $cal.TrackWrites += 2 * $lc.Count }
        }
        $cal.ValueTxt = $parts -join ', '
        $readTs = "c=$(Format-CylList ([int[]]@($all.Keys | Sort-Object))):h=0-1"
        Append-Log ((T "Calibration rapide : passe {0}/{1}, {2}") -f "$($cal.LPass)", "$($script:LevelMaxPasses)", "$($cal.ValueTxt)")
    } elseif ($cal.Slow) {
        # Verification : tous les cylindres estimes (V1), puis seulement ceux dont la valeur a change (V2, VerifyList)
        $cal.ValueTxt = (T 'profil')
        $all = @{}
        foreach ($u in $cal.Units) {
            $lst = if ($null -ne $u.VerifyList) { @($u.VerifyList) } else { @($cal.Cyls) }
            if ($lst.Count -eq 0) { continue }
            foreach ($c in $lst) { $all[[int]$c] = $true }
            $writes += ,@("c=$(Format-CylList ([int[]]$lst)):h=$($u.Head)", $u.Profile)
        }
        if ($null -ne $cal.Units[0].VerifyList) {
            Append-Log ((T "Calibration : passe de vérification {0}/{1} ciblée sur les cylindres modifiés : {2}") -f "$($cal.VerifyCount)", "$($script:CalMaxVerify)", ((@($cal.Units | Where-Object { @($_.VerifyList).Count -gt 0 } | ForEach-Object { $uu = $_; "$($uu.Prefix)$(Format-CylList ([int[]]@(@($uu.VerifyList) | Where-Object { @($uu.Witness) -notcontains $_ })))" })) -join ' ; '))
            $wt = @($cal.Units | Where-Object { @($_.Witness).Count -gt 0 } | ForEach-Object { "$($_.Prefix)$(Format-CylList ([int[]]@($_.Witness)))" })
            if ($wt.Count -gt 0) { Append-Log ((T "Calibration : témoins de dérive, réécrits à leur valeur inchangée et relus pour mesurer l'écart du lecteur entre deux vérifications : {0}") -f ($wt -join ' ; ')) }
        } else {
            Append-Log ((T "Calibration : passe de vérification {0}/{1}, tête 0 puis tête 1, profils {2} et {3}") -f "$($cal.VerifyCount)", "$($script:CalMaxVerify)", "$($cal.Units[0].Profile)", "$($cal.Units[1].Profile)")
        }
        $readTs = "c=$(Format-CylList ([int[]]@($all.Keys | Sort-Object))):h=0-1"
    } else {
        $cal.Spec = $cal.Units[0].Profile; $cal.ValueTxt = (T 'profil')
        $u0 = $cal.Units[0]
        if ($null -ne $u0.VerifyList) {
            $lst = [int[]]@($u0.VerifyList)
            Append-Log ((T "Calibration : passe de vérification {0}/{1} ciblée sur les cylindres modifiés : {2}") -f "$($cal.VerifyCount)", "$($script:CalMaxVerify)", (Format-CylList ([int[]]@($lst | Where-Object { @($u0.Witness) -notcontains $_ }))))
            if (@($u0.Witness).Count -gt 0) { Append-Log ((T "Calibration : témoins de dérive, réécrits à leur valeur inchangée et relus pour mesurer l'écart du lecteur entre deux vérifications : {0}") -f (Format-CylList ([int[]]@($u0.Witness)))) }
            $writes += ,@("c=$(Format-CylList $lst):h=0-1", $cal.Spec)
            $readTs = "c=$(Format-CylList $lst):h=0-1"
        } else {
            Append-Log ((T "Calibration : passe de vérification {0}/{1}, profil {2}") -f "$($cal.VerifyCount)", "$($script:CalMaxVerify)", "$($cal.Spec)")
            $writes += ,@($cal.TSpec, $cal.Spec)
        }
    }
    if (Test-Path -LiteralPath $cal.Scp) { Remove-Item -LiteralPath $cal.Scp -Force }
    $cal.Writes.Clear()
    foreach ($w in $writes) {
        $cal.Writes.Enqueue([string[]](@('write') + (Get-CommonArgs) + @('--pre-erase', '--no-verify') + (Get-CalibDriveArgs) + @("--tracks=$($w[0])", '--precomp', $w[1], "`"$($cal.Pattern)`"")))
    }
    $cal.ReadArgs  = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @('--revs=3', "--tracks=$readTs", "`"$($cal.Scp)`"")
    $cal.PassStart = Get-Date; $cal.PhaseStart = $cal.PassStart; $cal.Phase = 'write'
    Update-CalibProgress
    $script:Chain.Clear()
    for ($i = 0; $i -lt $writes.Count; $i++) { $script:Chain.Enqueue({ Start-Gw ([string[]]$script:Cal.Writes.Dequeue()) }) }
    $script:Chain.Enqueue({
        $script:Cal.WriteDurs += ((Get-Date) - $script:Cal.PhaseStart).TotalSeconds
        $script:Cal.Phase = 'read'; $script:Cal.PhaseStart = Get-Date
        Start-Gw $script:Cal.ReadArgs
    })
    $script:Chain.Enqueue({ Invoke-CalibAnalysis })
    Invoke-NextChainStep
}

function Set-CalibEstimates($u, [string]$when = '') {
    # Valeur de precomp par cylindre teste (Get-CalibZero) d apres toutes ses mesures : passes 0/100/200, passe
    # d encadrement et passes de verification. Pente commune = mediane des pentes nettement negatives (-2 a defaut,
    # valeur theorique), utilisee seulement pour extrapoler un cylindre dont la pente locale n est pas fiable.
    $cal = $script:Cal
    $slopes = @(); $measured = 0
    foreach ($c in $cal.Cyls) {
        $pts = $u.Results[[int]$c]
        if ($pts.Count -lt 2) { continue }
        $measured++
        $xs = @($pts.Keys | ForEach-Object { [int]$_ } | Sort-Object); $ys = @($xs | ForEach-Object { [double]$pts[$_].Shift })
        $mx = ($xs | Measure-Object -Average).Average; $my = ($ys | Measure-Object -Average).Average
        $sxx = 0.0; $sxy = 0.0
        for ($i = 0; $i -lt $xs.Count; $i++) { $sxx += ($xs[$i] - $mx) * ($xs[$i] - $mx); $sxy += ($xs[$i] - $mx) * ($ys[$i] - $my) }
        if ($sxx -gt 0 -and $sxy / $sxx -lt -0.2) { $slopes += $sxy / $sxx }
    }
    if ($measured -eq 0) { Append-Log ($u.Prefix + (T 'Calibration : aucune mesure exploitable pour estimer la précompensation.')); return $false }
    # Tete seule sans aucune pente propre : le decalage ne suit pas la precomp ecrite, la face lue n a pas ete ecrite
    # (tete ou circuit d ecriture defaillant : le motif HFE a toujours deux faces) ; une pente de repli serait sans signification.
    if ($null -ne $u.Head -and $slopes.Count -eq 0) { Append-Log ($u.Prefix + (T 'Calibration : le décalage ne varie pas avec la précompensation écrite, cette face n''a pas été écrite (tête ou circuit d''écriture défaillant ?).')); return $false }
    $pooled = -2.0
    if ($slopes.Count -gt 0) { $sl = @($slopes | Sort-Object); $pooled = $sl[[int][math]::Floor($sl.Count / 2)] }
    $u.Slope = $pooled; $u.Est = @{}; $u.Sig = @{}; $u.Kind = @{}; $u.Own = @{}
    foreach ($c in $cal.Cyls) {
        $z = Get-CalibZero $u.Results[[int]$c] $pooled
        if (-not $z) { continue }
        $u.Est[[int]$c] = $z.Est; $u.Sig[[int]$c] = $z.Sig; $u.Kind[[int]$c] = $z.Kind
        $u.Own[[int]$c] = [bool]$z.Own             # pente propre fiable (sinon pente commune) : Get-TrendEstimates
    }
    foreach ($c in @($u.Outliers)) { if ($u.Kind.ContainsKey([int]$c)) { $u.Kind[[int]$c] = 'outlier' } }
    $mark = @{ interp = ''; extrap = '*'; cap = '^'; outlier = '!' }
    $estTxt = (@($u.Est.Keys | Sort-Object | ForEach-Object { "c$_=$([math]::Round($u.Est[$_], 0))$($mark[$u.Kind[$_]])" })) -join ' '
    Append-Log ($u.Prefix + $when + ((T "Pente moyenne : {0} ns de décalage par ns de precomp ; estimation par cylindre : {1}") -f "$([math]::Round($u.Slope, 2))", "$estTxt"))
    if (@($u.Kind.Values | Where-Object { $_ -ne 'interp' }).Count -gt 0) { Append-Log ($u.Prefix + ((T '  * extrapolée au-delà des mesures, ^ plafonnée à 0 ou {0} ns : valeur peu fiable.') -f "$($script:CalHardNs)")) }
    return $true
}

function Invoke-CalibAnalysis {
    $cal = $script:Cal
    if (-not $cal) { return }
    if (-not (Test-Path -LiteralPath $cal.Scp)) { Append-Log (T 'Calibration : fichier SCP absent, analyse impossible.'); Stop-PrecompCalib; return }
    try { $tracks = Read-ScpFile $cal.Scp ([int]$cal.PatternBits) } catch { Append-Log ((T "Calibration : {0}") -f "$($_.Exception.Message)"); Stop-PrecompCalib; return }
    $cal.ReadDurs += ((Get-Date) - $cal.PhaseStart).TotalSeconds
    $cal.PassesDone++
    foreach ($u in $cal.Units) {
        if ($cal.Stage -eq 'level' -and $u.Done) { continue }
        # Moyenne des deux faces (profil commun) ou face de l unite seule (ecriture lente) ; erreur-type combinee
        $heads = if ($null -eq $u.Head) { @(0, 1) } else { @([int]$u.Head) }
        $shifts = @(); $scores = @(); $bad = @()
        if ($cal.Stage -eq 'verify' -and $null -ne $u.VerifyList) {
            # Verification ciblee : la mesure de la passe precedente, prise a l ancienne valeur, ne vaut plus pour ces
            # cylindres ; non relus a cette passe, ils restent « non relus » (jamais juges sur un residu perime)
            # Mesure precedente gardee a part : la derive entre deux verifications (Get-VerifyDrift) la compare a la nouvelle
            $u.VerifyPrev = @{}; $u.ReadLast = @{}
            foreach ($c in @($u.VerifyList)) {
                $u.ReadLast[[int]$c] = $true
                if ($u.Verify.ContainsKey([int]$c) -and $u.VerifyP.ContainsKey([int]$c)) { $u.VerifyPrev[[int]$c] = @{ Shift = [double]$u.Verify[[int]$c].Shift; P = [double]$u.VerifyP[[int]$c]; Meas = $u.Verify[[int]$c] } }
                [void]$u.Verify.Remove([int]$c); [void]$u.VerifyP.Remove([int]$c)
            }
        }
        foreach ($c in $cal.Cyls) {
            if ($cal.Stage -eq 'bracket' -and -not $u.Bracket.ContainsKey([int]$c)) { continue }
            if ($cal.Stage -eq 'densify' -and -not $u.Dense.ContainsKey([int]$c)) { continue }
            if ($cal.Stage -eq 'verify' -and $null -ne $u.VerifyList -and @($u.VerifyList) -notcontains [int]$c) { continue }
            if ($cal.Stage -eq 'level' -and -not $u.LTarget.ContainsKey([int]$c)) { continue }
            if ($null -ne $u.Writes) { $u.Writes[[int]$c] = 1 + [int]$u.Writes[[int]$c] }   # piste ecrite a cette passe
            $sv = @(); $ev = @(); $jv = @()
            foreach ($h in $heads) {
                $tn = [int]$c * 2 + $h
                if (-not $tracks.ContainsKey($tn)) { continue }
                $m = Get-CalibTrackMeasure $tracks[$tn]; if ($m) { $sv += $m.Shift; $ev += $m.SE }
                $j = Get-CalibTrackScore $tracks[$tn]; if ($j -lt 9999) { $jv += $j }
            }
            if ($sv.Count -eq 0) { $bad += $c; continue }
            $sh = ($sv | Measure-Object -Average).Average
            $se = [double]::NaN
            if (@($ev | Where-Object { [double]::IsNaN([double]$_) }).Count -eq 0) { $q = 0.0; foreach ($x in $ev) { $q += $x * $x }; $se = [math]::Sqrt($q) / $ev.Count }
            $jt = if ($jv.Count -gt 0) { ($jv | Measure-Object -Average).Average } else { [double]::NaN }
            $meas = @{ Shift = $sh; SE = $se; Score = $jt }
            switch ($cal.Stage) {
                'coarse'  { Add-CalibPoint $u.Results[[int]$c] ([int]$cal.Value) $meas }
                'bracket' { Add-CalibPoint $u.Results[[int]$c] ([int]$u.Bracket[[int]$c]) $meas }
                'densify' { Add-CalibPoint $u.Results[[int]$c] ([int]$u.Dense[[int]$c]) $meas }
                'level'   { Add-CalibPoint $u.Results[[int]$c] ([int]$u.LTarget[[int]$c]) $meas }
                default   { $u.Verify[[int]$c] = $meas; $u.VerifyP[[int]$c] = Get-SpecValue $u.Profile ([int]$c) }
            }
            $shifts += $sh; if (-not [double]::IsNaN($jt)) { $scores += $jt }
        }
        if ($cal.Stage -eq 'verify' -and $null -ne $u.VerifyList -and @($u.Witness).Count -gt 0) {
            foreach ($c in @($u.Witness)) {
                $ci = [int]$c
                if ($u.Verify.ContainsKey($ci) -or -not $u.VerifyPrev.ContainsKey($ci)) { continue }
                $u.Verify[$ci] = $u.VerifyPrev[$ci].Meas; $u.VerifyP[$ci] = [int]$u.VerifyPrev[$ci].P
                [void]$u.VerifyPrev.Remove($ci); [void]$u.ReadLast.Remove($ci)
                $u.VerifyList = @(@($u.VerifyList) | Where-Object { [int]$_ -ne $ci })
            }
        }
        $badTxt = if ($bad.Count -gt 0) { ((T ", illisibles : {0}") -f "$($bad -join ',')") } else { '' }
        if ($shifts.Count -gt 0) {
            $st = $shifts | Measure-Object -Average -Minimum -Maximum
            $scTxt = if ($scores.Count -gt 0) { "$([math]::Round(($scores | Measure-Object -Average).Average, 0))" } else { '-' }
            Append-Log ((T "  {0} : décalage résiduel moyen {1} ns (de {2} à {3}), score jitter moyen {4}, {5} cylindre(s){6}") -f "$($u.Prefix)$($cal.ValueTxt)", (Format-LevelNum $st.Average), (Format-LevelNum $st.Minimum), (Format-LevelNum $st.Maximum), "$scTxt", "$($shifts.Count)", "$badTxt")
        } elseif (($cal.Stage -ne 'bracket' -or $u.Bracket.Count -gt 0) -and ($cal.Stage -ne 'densify' -or $u.Dense.Count -gt 0) -and ($cal.Stage -ne 'verify' -or $null -eq $u.VerifyList -or @($u.VerifyList).Count -gt 0)) {
            Append-Log ((T "  {0} : aucun cylindre mesurable{1}") -f "$($u.Prefix)$($cal.ValueTxt)", "$badTxt")
        }
    }
    if ($cal.Stage -eq 'level') { Invoke-LevelStep $cal; return }
    if ($cal.Stage -eq 'coarse') {
        $cal.Index++
        if ($cal.Index -lt $cal.Values.Count) { New-CalibPass; return }
        foreach ($u in $cal.Units) {
            if (-not (Set-CalibEstimates $u)) { $cal.TotalPasses = $cal.PassesDone; Complete-PrecompCalib; return }
        }
        # Encadrement : un cylindre encore sous-compense a la plus forte valeur mesuree a un zero extrapole, peu sur (la
        # pente varie hors de la plage mesuree) : une passe le mesure a son estimation + marge pour l encadrer, au plus au
        # plafond des passes de mesure (CalMaxNs) ; au-dela, zero extrapole de ces mesures, ecrit puis mesure par la verification.
        $cal.MaxCoarse = [int](@($script:CalCoarse) | Measure-Object -Maximum).Maximum
        $need = $false
        foreach ($u in $cal.Units) {
            $u.Bracket = @{}
            foreach ($c in @($u.Est.Keys)) {
                $pts = $u.Results[[int]$c]
                $top = [int](@($pts.Keys | ForEach-Object { [int]$_ }) | Measure-Object -Maximum).Maximum
                if ($u.Kind[[int]$c] -ne 'interp' -and [double]$pts[$top].Shift -gt 0 -and $top -lt $script:CalMaxNs) {
                    $u.Bracket[[int]$c] = [int][math]::Min($script:CalMaxNs, [math]::Max($top + 40, [math]::Round([double]$u.Est[[int]$c] + $script:CalBracketMargin)))
                    $need = $true
                }
            }
        }
        if ($need) { $cal.Stage = 'bracket'; $cal.TotalPasses++; New-CalibPass; return }
        if (Start-CalibDensify $cal) { return }
        Start-CalibFit $cal; return
    }
    if ($cal.Stage -eq 'bracket') {
        foreach ($u in $cal.Units) { if ($u.Bracket.Count -gt 0) { [void](Set-CalibEstimates $u (T 'Après encadrement : ')) } }
        if (Start-CalibDensify $cal) { return }
        Start-CalibFit $cal; return
    }
    if ($cal.Stage -eq 'densify') {
        if ($cal.DensePass -eq 'A') { Set-CalibDenseB $cal; $cal.DensePass = 'B'; New-CalibPass; return }
        foreach ($u in $cal.Units) { [void](Set-CalibEstimates $u (T 'Après mesures complémentaires : ')) }
        Start-CalibFit $cal; return
    }
    # Verification : la mesure au profil applique devient un point de plus pour chaque cylindre verifie ; l estimation
    # est recalculee (en general encadree, donc interpolee avec la pente locale). Correction locale de la courbe aux
    # cylindres hors tolerance (estimation - valeur appliquee), interpolee entre cylindres verifies, lissage croissant.
    # Ecriture lente : chaque tete est corrigee d apres sa propre mesure ; une nouvelle passe reverifie les deux.
    $again = $false
    foreach ($u in $cal.Units) {
        # Points de la passe : seulement les cylindres relus a cette passe (verification ciblee : VerifyList)
        $readNow = if ($null -ne $u.VerifyList) { @(@($u.VerifyList) | Where-Object { @($u.Witness) -notcontains [int]$_ }) } else { @($u.Verify.Keys | ForEach-Object { [int]$_ }) }
        foreach ($c in @($u.Verify.Keys)) { if ($readNow -contains [int]$c) { Add-CalibPoint $u.Results[[int]$c] ([int]$u.VerifyP[[int]$c]) $u.Verify[$c] } }
        [void](Set-CalibEstimates $u ((T "Vérification {0} : ") -f "$($cal.VerifyCount)"))
        $u.VerifyList = @()
        $corr = 0; $delta = @{}
        $fl = Get-ResidualFlags $u           # residus retenus : ecart regional, marche au bord, residu tres grand ou cylindre epars (pas un ecart local)
        foreach ($c in @($u.Verify.Keys)) {
            if (@($u.Outliers) -contains [int]$c) { continue }              # point isole : la courbe ne le suit pas
            $d = 0.0
            if ($fl.Bad.ContainsKey([int]$c) -and $u.Est.ContainsKey([int]$c)) {
                $d = [double]$u.Est[[int]$c] - (Get-SpecValue $u.Profile ([int]$c))
                if ([math]::Abs($d) -ge 0.5) { $corr++ } else { $d = 0.0 }
            }
            $delta[[int]$c] = $d
        }
        if ($corr -eq 0 -or $cal.VerifyCount -ge $script:CalMaxVerify) { continue }
        # Courbe monotone par segments : pres d un changement de sens, les mesures des premieres passes (cylindres ecrits
        # seuls, loin du zero) et celles de la verification (profil complet ecrit dans l ordre, comme l image) peuvent
        # differer bien au-dela de leur incertitude. Une correction par l estimation combinee, dans des segments figes,
        # fondrait alors le sommet et ses voisins en palier (PAVA). La courbe est reajustee sur les zeros locaux de la
        # verification : precomp appliquee - residu / pente, mesures prises au plus pres du zero et dans les conditions
        # de l ecriture ; les changements de sens peuvent se deplacer.
        if (@($u.Fit.Breaks).Count -gt 0) {
            $sl = if ($null -ne $u.Slope -and [double]$u.Slope -lt -0.2) { [double]$u.Slope } else { -2.0 }
            $zv = @{}; $zs = @{}
            foreach ($c in @($u.Verify.Keys)) {
                $ci = [int]$c
                if (@($u.Outliers) -contains $ci -or -not $u.VerifyP.ContainsKey($ci)) { continue }
                $zv[$ci] = [math]::Max(0.0, [math]::Min([double]$script:CalHardNs, [double]$u.VerifyP[$ci] - [double]$u.Verify[$c].Shift / $sl))
                $se = $u.Verify[$c].SE
                $zs[$ci] = if ($null -ne $se -and -not [double]::IsNaN([double]$se)) { [math]::Max(1.0, [double]$se / [math]::Abs($sl)) } else { 2.0 }
            }
            $re = $null
            if ($zv.Count -ge 4) { $re = Fit-PrecompCurve $zv $zs $cal.MaxCyl $null ($cal.Mode -eq 'fine' -or [bool]$cal.Densified) }
            if ($re -and @($re.Breaks).Count -gt 0) {
                # Forme reajustee, puis ancrage dans les nouveaux segments : un cylindre dans la tolerance garde sa valeur
                # appliquee (pas de reecriture inutile), un cylindre hors tolerance va a son zero mesure
                $dz = @{}
                foreach ($ci in @($zv.Keys)) {
                    $inTol = -not $fl.Bad.ContainsKey($ci)
                    $target = if ($inTol) { [double]$u.VerifyP[$ci] } else { [double]$zv[$ci] }
                    $dz[$ci] = $target - [double]$re.Values[$ci]
                }
                $re.Values = Add-CurveCorrection $re.Values $dz $re.Segs
                $newProfile = Build-CurveProfile $re.Values
                if ($newProfile -eq $u.Profile) { continue }
                $oldB = (@($u.Fit.Breaks) | ForEach-Object { "c$_" }) -join '/'
                $newB = (@($re.Breaks) | ForEach-Object { "c$_" }) -join '/'
                $u.Fit = @{ Model = 'seg+c'; A = $null; B = $null; Chi = $re.Chi; Values = $re.Values; Breaks = $re.Breaks; Segs = $re.Segs; Outliers = $u.Fit.Outliers }
                $u.Profile = $newProfile
                $bTxt = if ($oldB -ne $newB) { (T "changement de sens déplacé de {0} à {1}") -f "$oldB", "$newB" } else { (T "changements de sens {0}") -f "$newB" }
                Append-Log ($u.Prefix + ((T "Vérification : {0} cylindre(s) hors tolérance, courbe réajustée sur les zéros mesurés par la vérification ({1}) : {2}") -f "$corr", "$bTxt", "$($u.Profile)"))
                $u.VerifyList = @($u.Est.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -lt @($re.Values).Count -and (-not $u.VerifyP.ContainsKey($_) -or [int]$re.Values[$_] -ne [int]$u.VerifyP[$_]) } | Sort-Object)
                Add-DriftWitnesses $u
                if ($u.VerifyList.Count -gt 0) { $again = $true }
                continue
            }
        }
        $newVals = Add-CurveCorrection $u.Fit.Values $delta $u.Fit.Segs
        $newProfile = Build-CurveProfile $newVals
        if ($newProfile -eq $u.Profile) { continue }
        $base = ([string]$u.Fit.Model) -replace '\+c$', ''
        $u.Fit = @{ Model = "$base+c"; A = $u.Fit.A; B = $u.Fit.B; Chi = $u.Fit.Chi; Values = $newVals; Breaks = $u.Fit.Breaks; Segs = $u.Fit.Segs; Outliers = $u.Fit.Outliers }
        $u.Profile = $newProfile
        Append-Log ($u.Prefix + ((T "{0} cylindre(s) corrigé(s), résidu hors tolérance, nouveau profil : {1}") -f "$corr", "$($u.Profile)"))
        # Verification suivante ciblee : cylindres estimes dont la valeur appliquee change (au moins 1 ns)
        $u.VerifyList = @($u.Est.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -lt $newVals.Count -and (-not $u.VerifyP.ContainsKey($_) -or [int]$newVals[$_] -ne [int]$u.VerifyP[$_]) } | Sort-Object)
        Add-DriftWitnesses $u
        if ($u.VerifyList.Count -gt 0) { $again = $true }
    }
    if ($again) {
        $cal.VerifyCount++
        New-CalibPass; return
    }
    # Derniere verification : zones aux verifications contradictoires ramenees a la mediane (sans nouvelle passe)
    foreach ($u in $cal.Units) { [void](Set-VerifyContra $u) }
    $cal.TotalPasses = $cal.PassesDone
    Complete-PrecompCalib
}

function Complete-PrecompCalib {
    $cal = $script:Cal; $script:Cal = $null
    if (-not $cal) { return }
    $pbWCal.Value = 100
    $elapsedTotal = if ($cal.StartTime -is [datetime]) { ((Get-Date) - $cal.StartTime).TotalSeconds } else { 0 }
    $lblWCal.Text = ((T "Calibration terminée en {0}") -f (Format-CalDuration $elapsedTotal))
    if (@($cal.Units | Where-Object { -not $_.Profile -or -not $_.Fit }).Count -gt 0) {
        Append-Log (T 'Calibration precomp : aucune mesure exploitable, profil inchangé.')
        if ($script:AfterCalib) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : calibration sans mesure exploitable.') }
        if ($script:Restore) { Stop-Restore (T 'calibration sans mesure exploitable') }
        return
    }
    $famTxt = Get-CalibFamilyName $cal.Family
    $allConv = $true; $anySat = $false; $anyCeil = $false
    $issues = New-Object System.Collections.Generic.List[string]
    foreach ($u in $cal.Units) {
        if ($u.Verify.Count -gt 0) {
            $resTxt = (@($u.Verify.Keys | Sort-Object | ForEach-Object { "c$_=$('{0:+0.0;-0.0;0.0}' -f [double]$u.Verify[$_].Shift)" + $(if (@($u.Outliers) -contains [int]$_) { " ($(Get-KindName 'outlier'))" } else { '' }) })) -join ' '
            Append-Log ($u.Prefix + ((T "Résidu après vérification (ns, tolérance {0}, élargie à 3 erreurs-types si la mesure est plus bruitée) : {1}") -f "$($script:CalResidual)", "$resTxt"))
        }
        $u.Warn = Get-CalibWarnings $u $cal.MaxCyl
        $dft = $u.Warn.Drift
        if ($dft.Use) {
            $sla = if ($null -ne $u.Slope -and [double]$u.Slope -lt -0.2) { [math]::Abs([double]$u.Slope) } else { 2.0 }
            $dsp = if ([double]$dft.SRaw -ge 1.0) { "$(Format-LevelNum $dft.SRaw) ns" } else { (T 'moins de 1 ns') }
            $lt = (T "Dérive du lecteur entre les deux vérifications : {0} ± {1} ns de décalage commun sur {2} cylindres témoins (dispersion {3}).") -f ('{0:+0.0;-0.0;0.0}' -f [double]$dft.D), (Format-LevelNum $dft.E), "$($dft.NW)", "$dsp"
            $pdv = [math]::Round([math]::Abs([double]$dft.D) / $sla, 1); $pd = Format-LevelNum $pdv
            if ($pdv -le 0) { }
            elseif ([double]$dft.D -gt 0) { $lt += (T " Le besoin de précompensation était plus élevé de {0} ns à la dernière vérification.") -f "$pd" }
            elseif ([double]$dft.D -lt 0) { $lt += (T " Le besoin de précompensation était plus faible de {0} ns à la dernière vérification.") -f "$pd" }
            if ([int]$dft.NC -gt 0) { $lt += (T " Écart des cylindres corrigés à leur prédiction, dérive comprise : {0} ns en médiane sur {1}.") -f ('{0:+0.0;-0.0;0.0}' -f [double]$dft.DC), "$($dft.NC)" }
            $lt += (T " Les résidus des cylindres relus à la dernière vérification sont jugés sans ce décalage ; les témoins, inchangés, sur leur mesure précédente, sauf ceux d'un écart systématique, jugés sur leur relecture.")
            Append-Log ($u.Prefix + $lt)
            # Derive forte : retiree du jugement, mais signalee (lecteur ou support instable d une passe a l autre)
            if ([math]::Abs([double]$dft.D) -gt 2.0 * [double]$script:CalResidual) { $issues.Add($u.Prefix + ((T "dérive du lecteur de {0} ns entre deux vérifications (lecteur ou support instable ?)") -f ('{0:+0.0;-0.0;0.0}' -f [double]$dft.D))) }
        }
        elseif (@($u.Witness).Count -gt 0 -and $u.VerifyPrev.Count -gt 0) {
            Append-Log ($u.Prefix + ((T "Dérive du lecteur non mesurée : {0} témoin(s) exploitable(s) sur {1}, {2} au moins nécessaires ; résidus jugés sans correction de dérive, témoins sur leur mesure précédente.") -f "$($dft.NW)", "$(@($u.Witness).Count)", "$([int]$u.WitMin)"))
        }
        elseif (@($u.Witness).Count -eq 0 -and $u.VerifyPrev -and $u.VerifyPrev.Count -gt 0) {
            Append-Log ($u.Prefix + ((T "Dérive du lecteur non mesurée : {0} cylindre(s) non modifié(s) disponible(s) comme témoins, {1} au moins nécessaires ; résidus jugés sans correction de dérive.") -f "$([int]$u.WitCand)", "$([int]$u.WitMin)"))
        }
        # Zone non reproductible : verifications contradictoires, courbe a la mediane (Set-VerifyContra) ; liste de
        # Get-CalibWarnings (jamais un cylindre deja signale au plafond ou au plancher). Fenetre de decision si les deux
        # verifications s ecartent de plus de CalContraMaxNs, ou si la derive du lecteur n a pas ete mesuree (sans temoins,
        # une derive entre les deux verifications ne se distingue pas d une contradiction : l utilisateur tranche)
        $cn = [int[]]@(@($u.Warn.Contra) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object)
        if ($cn.Count -gt 0) {
            $em = [double](@($cn | ForEach-Object { [double]$dft.Contra[$_].E }) | Measure-Object -Maximum).Maximum
            $cl = Format-CylList $cn
            Append-Log ($u.Prefix + ((T "Zone non reproductible d'une vérification à l'autre aux cylindres {0} : les deux vérifications placent le besoin de part et d'autre de la valeur écrite. La courbe y prend la médiane des passes de mesure et des deux vérifications, dans l'intervalle des deux valeurs écrites et sans dépasser les cylindres vérifiés voisins (écart entre les vérifications jusqu'à {1} ns de précompensation).") -f "$cl", (Format-LevelNum $em)))
            if ($em -gt [double]$script:CalContraMaxNs) { $issues.Add($u.Prefix + ((T "vérifications contradictoires aux cylindres {0} (écart jusqu'à {1} ns : lecteur ou support instable ?)") -f "$cl", (Format-LevelNum $em))) }
            elseif (-not $dft.Use) { $issues.Add($u.Prefix + ((T "vérifications contradictoires aux cylindres {0} sans mesure de la dérive du lecteur (écart jusqu'à {1} ns : dérive du lecteur ou zone non reproductible ?)") -f "$cl", (Format-LevelNum $em))) }
        }
        # Filet du lissage de la zone : cylindre verifie hors zone deplace malgre tout (test standard : cylindre interpole
        # entre la zone et lui), sans nouvelle mesure ; son residu n est pas enregistre
        $mv = [int[]]@(@($u.ContraMoved) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object)
        if ($mv.Count -gt 0) {
            Append-Log ($u.Prefix + ((T "Cylindres vérifiés {0} déplacés par le lissage croissant de la courbe autour de la zone non reproductible, sans nouvelle mesure : leur résidu n'est pas enregistré avec la courbe.") -f (Format-CylList $mv)))
        }
        if (@($u.Warn.NonRepro).Count -gt 0) {
            Append-Log ($u.Prefix + ((T "Cylindres non reproductibles d'une vérification à l'autre (zéro estimé à la pente commune par la vérification précédente, puis par la dernière, dérive retirée) : {0}. Ils ne comptent pas pour la convergence ; une nouvelle calibration peut leur donner une autre valeur.") -f (@($u.Warn.NonRepro) -join ', ')))
        }
        if (-not [double]::IsNaN([double]$u.Warn.Sigma)) {
            Append-Log ($u.Prefix + ((T "Bruit de mesure estimé : {0} ns, sur {1} écarts entre cylindres vérifiés distants de 2 au plus. Un écart est retenu si la moyenne des résidus voisins (2 cylindres au plus) dépasse {2} ns, si un résidu dépasse {3} ns, s'il s'étend sur 3 cylindres ou plus, ou 2 en bord de piste ou de segment, au-delà de {2} ns, ou s'il couvre 2 cylindres au-delà de {4} ns. Seuils relevés quand le bruit est fort. Un écart dont un cylindre a moins de 2 autres cylindres vérifiés à 2 cylindres au plus est retenu sur sa seule tolérance ; les points isolés et les cylindres au plafond ou au plancher ne comptent ni dans le bruit ni dans le voisinage, les cylindres non reproductibles ni dans le bruit ni dans les moyennes.") -f (Format-LevelNum $u.Warn.Sigma), "$($u.Warn.NDiff)", (Format-LevelNum $script:CalResidual), (Format-LevelNum $u.Warn.Hard), (Format-LevelNum $u.Warn.HardPair)))
        }
        if (@($u.Warn.Spot).Count -gt 0) {
            Append-Log ($u.Prefix + ((T "Écarts locaux non retenus : {0}. Hors tolérance, mais sous les seuils ci-dessus : ces écarts ne sont pas corrigés.") -f (@($u.Warn.Spot) -join ', ')))
        }
        if ($u.Warn.NonConv.Count -gt 0) { $issues.Add($u.Prefix + ((T "non convergée aux cylindres {0}") -f ($u.Warn.NonConv -join ', '))) }
        if ($u.Warn.Sat.Count -gt 0) { $issues.Add($u.Prefix + ((T "plafond de {0} ns atteint aux cylindres {1} (support fatigué ?)") -f "$($script:CalHardNs)", ($u.Warn.Sat -join ', '))) }
        if ($u.Warn.Floor.Count -gt 0) { $issues.Add($u.Prefix + ((T "précompensation nulle encore excessive aux cylindres {0}") -f ($u.Warn.Floor -join ', '))) }
        if ($u.Warn.Dev.Count -gt 0) { $issues.Add($u.Prefix + ((T "courbe éloignée des mesures (courbe moins mesure) : {0}") -f ($u.Warn.Dev -join ', '))) }
        if ($u.Warn.NonConv.Count -gt 0) {
            $allConv = $false
            Append-Log ($u.Prefix + ((T "Calibration non convergée aux cylindres {0} : résidu hors tolérance après la dernière vérification, la courbe ne suit pas la mesure à ces cylindres. Refaire la calibration en test fin, ou sur une autre disquette sacrifiée.") -f ($u.Warn.NonConv -join ', ')))
        }
        if ($u.Warn.Sat.Count -gt 0) {
            $anySat = $true; $anyCeil = $true
            Append-Log ($u.Prefix + ((T "Plafond de {0} ns atteint aux cylindres {1} : le besoin dépasse la précompensation maximale, la courbe reste au plafond et une nouvelle calibration n'y changera rien. Si une disquette en bon état sature aussi, c'est le lecteur ; sinon, c'est le support, probablement fatigué.") -f "$($script:CalHardNs)", ($u.Warn.Sat -join ', ')))
        }
        if ($u.Warn.Floor.Count -gt 0) {
            $anySat = $true
            Append-Log ($u.Prefix + ((T "Précompensation nulle encore excessive aux cylindres {0} : la courbe reste à 0 ns et une nouvelle calibration n'y changera rien. La même mesure sur une autre disquette désigne le lecteur, sinon le support.") -f ($u.Warn.Floor -join ', ')))
        }
        if (@($u.Warn.Beyond).Count -gt 0) {
            # Courbe au-dela du plafond des passes de mesure : information (valeurs verifiees), sans fenetre de decision
            $anyCeil = $true
            $bmax = [int](@($u.Warn.Beyond | ForEach-Object { [int]$u.Fit.Values[$_] }) | Measure-Object -Maximum).Maximum
            $how = if ($u.Trend -and @($u.Trend.Keys).Count -gt 0) { (T ' et par la tendance de la courbe') } else { '' }
            Append-Log ($u.Prefix + ((T "Besoin au-delà de {0} ns, plafond des passes de mesure, aux cylindres {1} : courbe jusqu'à {2} ns, déduite par extrapolation des mesures{3}, puis contrôlée par la vérification. Un besoin aussi fort est inhabituel : si une disquette en bon état ne l'atteint pas, le support de calibration est probablement fatigué.") -f "$($script:CalMaxNs)", (Format-CylList ([int[]]$u.Warn.Beyond)), "$bmax", "$how"))
        }
        $bk = @($u.Warn.Breaks)
        if ($bk.Count -ge 2) { Append-Log ($u.Prefix + ((T "Changement de sens du besoin entre c{0} et c{1} : courbe monotone par segments. La même signature sur une autre disquette désigne le lecteur, sinon le support.") -f "$($bk[0])", "$($bk[1])")) }
        elseif ($bk.Count -eq 1) { Append-Log ($u.Prefix + ((T "Le besoin redescend à partir de c{0} : courbe monotone par segments. La même signature sur une autre disquette désigne le lecteur, sinon le support.") -f "$($bk[0])")) }
        if ($u.Warn.Dev.Count -gt 0) { Append-Log ($u.Prefix + ((T "Écart à la courbe de plus de 15 ns et de trois incertitudes (courbe moins mesure) : {0}.") -f ($u.Warn.Dev -join ', '))) }
        # Calibration precedente du meme lecteur (encore en memoire, remplacee plus bas) : la forme de la courbe tient au
        # lecteur, son niveau au support ; un ecart net, ou un plafond nouveau, designe le support de calibration
        $pkey = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }
        $prev = $script:PrecompCurves[$pkey]
        if ($prev -and [string]$prev.Drive -eq [string]$cal.Drive -and @($prev.Values).Count -gt 0 -and $u.Fit) {
            $pv = @($prev.Values); $nv = @($u.Fit.Values); $nn = [math]::Min($pv.Count, $nv.Count)
            if ($nn -gt 0) {
                $dd = @(for ($c = 0; $c -lt $nn; $c++) { [int]$nv[$c] - [int]$pv[$c] })
                $ds = $dd | Measure-Object -Average -Minimum -Maximum
                Append-Log ($u.Prefix + ((T "Écart avec la calibration précédente du lecteur {0} ({1}) : {2} ns en moyenne (de {3} à {4} ns).") -f "$($cal.Drive)", "$($prev.Date)", ('{0:+0;-0;0}' -f [math]::Round($ds.Average, 0)), ('{0:+0;-0;0}' -f $ds.Minimum), ('{0:+0;-0;0}' -f $ds.Maximum)))
                # Plafond de la courbe precedente : borne de SON calcul (300 ns avant le calcul 12.4)
                $pmax = [math]::Min((Get-CurveMaxNs $prev), [int]$script:CalHardNs)   # ramenee a la borne actuelle
                $ptop = [int](@($pv[0..($nn - 1)]) | Measure-Object -Maximum).Maximum
                if ($u.Warn.Sat.Count -gt 0 -and $ptop -lt $pmax) {
                    Append-Log ($u.Prefix + (T "Plafond atteint alors que la calibration précédente du même lecteur ne l'atteignait pas : support de calibration probablement fatigué (sinon têtes à nettoyer, ou autre lecteur sous la même lettre)."))
                }
                # Besoin au-dela du plafond des mesures : signale seulement une hausse nette (plus de 15 ns sur le maximum
                # des cylindres communs), pas une courbe qui passe de 298 a 305 ns
                elseif (@($u.Warn.Beyond).Count -gt 0 -and $ptop -le $script:CalMaxNs -and $ptop -lt $pmax -and [int](@($nv[0..($nn - 1)]) | Measure-Object -Maximum).Maximum - $ptop -gt 15) {
                    Append-Log ($u.Prefix + ((T "Besoin au-delà de {0} ns alors que la calibration précédente du même lecteur ne dépassait pas cette valeur : support de calibration probablement fatigué (sinon têtes à nettoyer, ou autre lecteur sous la même lettre).") -f "$($script:CalMaxNs)"))
                }
            }
        }
        # Diagnostic de forme (calibration rapide) : sur les cylindres mesures par les deux calibrations, ecart de niveau
        # et ecart de forme (dispersion apres retrait du niveau) ; donnees pour recaler les seuils sur materiel reel
        if ($prev -and [string]$prev.Drive -eq [string]$cal.Drive -and $prev.Cyls -and $prev.Ys) {
            $dd2 = @{}
            for ($i = 0; $i -lt @($prev.Cyls).Count; $i++) {
                $c = [int]$prev.Cyls[$i]
                $pk2 = if ($prev.Kinds -and $i -lt @($prev.Kinds).Count) { [string]$prev.Kinds[$i] } else { 'interp' }
                if ($pk2 -ne 'interp' -or -not $u.Est.ContainsKey($c) -or [string]$u.Kind[$c] -ne 'interp') { continue }
                $dd2[$c] = [double]$u.Est[$c] - [double]$prev.Ys[$i]
            }
            if ($dd2.Count -ge 4) {
                $mv = (@($dd2.Values) | Measure-Object -Average).Average
                $sdv = [math]::Sqrt((@($dd2.Values | ForEach-Object { [math]::Pow($_ - $mv, 2) }) | Measure-Object -Sum).Sum / ($dd2.Count - 1))
                $wc = @($dd2.Keys | Sort-Object { -[math]::Abs($dd2[$_] - $mv) })[0]
                Append-Log ($u.Prefix + ((T "Forme comparée à la calibration précédente du lecteur {0} ({1}), sur {2} cylindres mesurés par les deux : niveau {3} ns, écart de forme {4} ns (au plus {5} ns, à c{6}).") -f "$($cal.Drive)", "$($prev.Date)", "$($dd2.Count)", ('{0:+0;-0;0}' -f [math]::Round($mv, 0)), ('{0:0.#}' -f [math]::Round($sdv, 1)), ('{0:+0;-0;0}' -f [math]::Round($dd2[$wc] - $mv, 0)), "$wc"))
            }
        }
        if ($u.Warn.Extrap.Count + $u.Warn.Cap.Count -gt 0) {
            Append-Log ($u.Prefix + ((T "Valeurs peu fiables : {0} extrapolée(s) au-delà des mesures ({1}), {2} plafonnée(s) à 0 ou {3} ns ({4}).") -f "$($u.Warn.Extrap.Count)", ($(if ($u.Warn.Extrap.Count) { $u.Warn.Extrap -join ',' } else { '-' })), "$($u.Warn.Cap.Count)", "$($script:CalHardNs)", ($(if ($u.Warn.Cap.Count) { $u.Warn.Cap -join ',' } else { '-' }))))
        }
    }
    if ($anyCeil -and $cal.Swap) { Append-Log ((T "Calibration faite sur une disquette sacrifiée dont le besoin dépasse {0} ns : si elle est fatiguée, la courbe surestime le besoin de la disquette à écrire. Préférez une disquette sacrifiée en bon état.") -f "$($script:CalMaxNs)") }
    # Etat precedent (courbes et profils remplaces ci-dessous) : retabli si l utilisateur refuse un resultat douteux
    $prevCal = @{ Std = $script:PrecompStd; Long = $script:PrecompLong; Curves = @{}; Levels = $script:LevelShifts.Clone()
                  Prof = $cmbWProfile.SelectedIndex; On = $chkWPrecomp.Checked; P0 = $txtWPrecomp.Text; P1 = $txtWPrecomp1.Text; Lbl = $lblWProfileInfo.Text }
    foreach ($u in $cal.Units) { $pk = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }; $prevCal.Curves[$pk] = $script:PrecompCurves[$pk] }
    # Profil commun : remplace celui de la famille. Ecriture lente : courbes par tete, le profil commun est conserve.
    if (-not $cal.Slow) {
        $spec = $cal.Units[0].Profile
        if ($cal.Family -eq 'long') { $script:PrecompLong = $spec } else { $script:PrecompStd = $spec }
    }
    $date = Get-Date -Format 'dd/MM/yyyy HH:mm'
    foreach ($u in $cal.Units) {
        $key = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }
        $cs = @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
        $maxX = 0
        foreach ($c in $cs) { foreach ($x in @($u.Results[$c].Keys)) { if ([int]$x -gt $maxX) { $maxX = [int]$x } } }
        $script:PrecompCurves[$key] = @{
            Family = $famTxt; Head = $u.Head; Drive = $cal.Drive; Date = $date; Model = $u.Fit.Model; Spec = $u.Profile; Method = 'motif'
            Version = $script:Version; Algo = $script:CalibAlgo; Calc = $script:CalibCalc; Breaks = [int[]]@($u.Fit.Breaks)
            Values = [int[]]@($u.Fit.Values); Cyls = [int[]]$cs
            Ys = [double[]]@($cs | ForEach-Object { [math]::Round([double]$u.Est[$_], 1) })
            Sig = [double[]]@($cs | ForEach-Object { [math]::Round($(if ($u.Sig.ContainsKey($_)) { [double]$u.Sig[$_] } else { 5.0 }), 1) })
            Kinds = [string[]]@($cs | ForEach-Object { [string]$u.Kind[$_] })
            Res = [double[]]@($cs | ForEach-Object { if (@($u.Warn.Contra) -contains $_ -or @($u.ContraMoved) -contains $_) { [double]::NaN } elseif (@($u.Witness) -contains $_ -and $u.VerifyPrev.ContainsKey($_) -and -not $u.Warn.Drift.Sys.ContainsKey($_)) { [math]::Round([double]$u.VerifyPrev[$_].Shift, 1) } elseif ($u.Verify.ContainsKey($_)) { [math]::Round([double]$u.Verify[$_].Shift, 1) } else { [double]::NaN } })
            Converged = ($u.Warn.NonConv.Count -eq 0); MaxX = $maxX; MaxNs = [int]$script:CalHardNs
            Contra = [int[]]@(@($u.Warn.Contra) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object)
            Slope =$(if ($null -ne $u.Slope) { [math]::Round([double]$u.Slope, 3) } else { $null }); Bits = [int]$cal.PatternBits; Test = [string]$cal.Mode
        }
    }
    # Nouvelle reference de forme : les niveaux mesures avec la precedente sont abandonnes
    $dropped = @()
    foreach ($u in $cal.Units) {
        $key = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }
        foreach ($k in @($script:LevelShifts.Keys)) { if ($script:LevelShifts[$k] -and $script:LevelShifts[$k].RefKey -eq $key) { $script:LevelShifts.Remove($k); $dropped += $key } }
    }
    if ($dropped.Count -gt 0) { Append-Log ((T "Nouvelle référence de forme ({0}) : les niveaux mesurés avec la précédente sont abandonnés.") -f ((@($dropped | Sort-Object -Unique | ForEach-Object { Get-CurveKeyLabel $_ })) -join ', ')) }
    # Auto : applique le profil de la famille de l image ; carte Calibration de l Accueil : profil choisi dans l onglet
    # Ecriture respecte (Manuel compris), libelle du profil seulement pour une image de l onglet de la famille calibree
    if (-not $cal.Home) { $cmbWProfile.SelectedIndex = 0 }
    Update-PrecompForImage $txtWFile.Text
    $convTxt = if (-not $allConv) { (T ' NON CONVERGÉE : voir le journal et la fenêtre Courbe.') } elseif ($anySat) { ((T ' Limite de précompensation atteinte (0 ou {0} ns) : voir le journal.') -f "$($script:CalHardNs)") } else { '' }
    $showLbl = (-not $cal.Home) -or ($cmbWProfile.SelectedIndex -eq 0 -and (Get-WriteTabFamily) -eq $cal.Family)
    if ($showLbl -and $cal.Slow) {
        $v0 = @($cal.Units[0].Fit.Values); $v1 = @($cal.Units[1].Fit.Values)
        $lblWProfileInfo.Text = ((T "Profils {0} par tête calibrés le {1} sur le lecteur {2} : tête 0 de {3} à {4} ns, tête 1 de {5} à {6} ns, une valeur par cylindre (bouton Courbe).") -f "$famTxt", "$date", "$($cal.Drive)", "$($v0[0])", "$($v0[-1])", "$($v1[0])", "$($v1[-1])") + $convTxt
    } elseif ($showLbl) {
        $v = @($cal.Units[0].Fit.Values)
        $lblWProfileInfo.Text = ((T "Profil {0} calibré le {1} sur le lecteur {2} : courbe {3}, de {4} à {5} ns, une valeur par cylindre (bouton Courbe).") -f "$famTxt", "$date", "$($cal.Drive)", (Get-CurveModelName $cal.Units[0].Fit.Model), "$($v[0])", "$($v[-1])") + $convTxt
    }
    if ($convTxt) { $lblWCal.Text += $convTxt }
    foreach ($u in $cal.Units) {
        Append-Log ($u.Prefix + ((T "Calibration terminée : profil {0} = {1}") -f "$famTxt", "$($u.Profile)"))
        $v = @($u.Fit.Values)
        for ($c0 = 0; $c0 -lt $v.Count; $c0 += 10) {
            $hi = [math]::Min($v.Count - 1, $c0 + 9)
            $line = ((T "  Précomp cylindres {0}-{1} : {2} ns") -f "$c0", "$hi", "$((@($v[$c0..$hi])) -join ' ')")
            if ($u.Prefix) { $line = '  ' + $u.Prefix + $line.TrimStart() }
            Append-Log $line
        }
    }
    Append-Log ((T "Courbe obtenue avec le calcul de calibration v{0}.") -f "$($script:CalibCalc)")
    if ($script:Restore) {
        if ($cal.Slow) { Append-Log ((T "Profils par tête appliqués par le mode Auto en écriture lente à toute image {0} ; ils seront enregistrés dans la configuration à la fin de la restauration.") -f "$famTxt") }
        else { Append-Log ((T "Profil appliqué par le mode Auto à toute image {0} ; il sera enregistré dans la configuration à la fin de la restauration.") -f "$famTxt") }
    }
    elseif ($cal.Slow) { Append-Log ((T "Profils par tête enregistrés dans la configuration et appliqués par le mode Auto en écriture lente à toute image {0}.") -f "$famTxt") }
    else { Append-Log ((T "Profil enregistré dans la configuration et appliqué par le mode Auto à toute image {0}.") -f "$famTxt") }
    if (-not $script:Restore) { [void](Save-Config) }      # restauration : enregistree par Close-Restore, onglet Ecriture retabli
    if ($issues.Count -gt 0) {
        # Resultat douteux : courbe montree, l utilisateur choisit de continuer (ecrire, ou conserver la courbe) ou
        # d arreter (calibration precedente retablie). Restauration : sequence occupee pendant la fenetre (chien de garde).
        $toWrite = ($script:AfterCalib -eq 'write')
        Append-Log ((T "Calibration : résultat douteux ({0}) : courbe affichée, décision demandée.") -f ($issues -join ' ; '))
        if ($script:Restore) { $script:Restore.InCall = $true }
        try { $choice = Show-CalibReview $cal @($issues) $toWrite }
        finally { if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
        if ($choice -eq 'stop') {
            Restore-CalibState $prevCal
            $lblWCal.Text = (T 'Calibration abandonnée : la calibration précédente est rétablie.')
            Append-Log (T 'Calibration abandonnée à votre demande : courbe non conservée, calibration précédente rétablie.')
            if ($toWrite) {
                $script:AfterCalib = ''
                Append-Log (T 'Écriture annulée : résultat de calibration refusé.')
                if ($script:Restore) { Stop-Restore (T 'résultat de calibration refusé') }
            }
            return
        }
        Append-Log (T 'Calibration : résultat accepté malgré les réserves.')
    }
    if ($script:AfterCalib -eq 'write') {
        # Ecriture rapide ou lente : l image est ecrite tout de suite avec le profil obtenu (courbe visible par le bouton Courbe)
        $script:AfterCalib = ''
        if ($cal.Swap) {
            # Calibration faite sur une disquette sacrifiee : la disquette a ecrire est redemandee, avec le meme delai que
            # l avertissement (sans reponse, l image est ecrite sur la disquette inseree) ; restauration : attente a delai,
            # puis nouvelle sonde de la destination avant l ecriture
            if ($script:Restore) { Enter-RestoreSwapBack; return }
            $lrA = if ($cal.LevelAfter) { Get-LevelRef $cal.Family $cal.Slow $cal.Drive $cal.Image $false -NCyl ([int]$cal.MaxCyl + 1) } else { $null }
            if ($lrA -and -not $lrA.Ok) { Append-Log ((T "Calibration rapide impossible : {0}. Écriture avec la nouvelle calibration complète.") -f "$($lrA.Why)") }
            if ($lrA -and $lrA.Ok) {
                # Reference faite sur la disquette sacrifiee : le niveau de la disquette a ecrire est mesure apres sa remise
                $lr = $lrA
                $lc = if ($lr.Ok) { (@($lr.Units | ForEach-Object { Format-CylList ([int[]]@(@(@($_.LCyls) + @($_.Wit) + @($(if ($null -ne $_.Probe) { $_.Probe }))) | Sort-Object -Unique)) } | Sort-Object -Unique)) -join ' ; ' } else { '-' }
                $q = Show-TimedConfirm 'frmReinsert' (T 'Calibration precomp') ((T "Calibration terminée : elle devient la référence de forme du lecteur {0}.`n`nRetirez la disquette sacrifiée et insérez la disquette à écrire, puis cliquez sur « Mesurer le niveau et écrire » : son niveau de précompensation est mesuré sur les cylindres {1} (2 faces, 1 à 3 écritures du motif par piste), puis l'image est écrite.`nAnnuler : l'image n'est pas écrite.") -f "$($cal.Drive)", "$lc") (T 'Mesurer le niveau et écrire') 'Diagnostic' (T "Sans réponse, la mesure du niveau puis l'écriture démarrent automatiquement dans {0} s.") '' '' ''
                if (-not $q.Ok) { Append-Log (T 'Écriture annulée : la disquette à écrire n''a pas été remise après la calibration.'); return }
                if ($q.Auto) { Append-Log ((T "Calibration : remise de la disquette validée automatiquement après {0} s sans réponse.") -f "$($script:CalibConfirmSeconds)") }
                if ($lr.Ok) {
                    $script:AfterCalib = 'write'
                    Start-LevelCalib $lr -NoConfirm -NoFallback
                    if (-not $script:Cal) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : la calibration rapide n''a pas été lancée.') }
                    return
                }
            } else {
            $q = Show-TimedConfirm 'frmReinsert' (T 'Calibration precomp') ((T "Calibration terminée.`n`nRetirez la disquette sacrifiée du lecteur {0} et insérez la disquette à écrire, puis cliquez sur « Écrire l'image ».`nAnnuler : l'image n'est pas écrite.") -f "$($cal.Drive)") (T "Écrire l'image") 'Save' (T "Sans réponse, l'écriture de l'image démarre automatiquement dans {0} s.") '' '' ''
            if (-not $q.Ok) { Append-Log (T 'Écriture annulée : la disquette à écrire n''a pas été remise après la calibration.'); return }
            if ($q.Auto) { Append-Log ((T "Calibration : remise de la disquette validée automatiquement après {0} s sans réponse.") -f "$($script:CalibConfirmSeconds)") }
            }
        }
        Append-Log (T 'Calibration terminée : écriture de l''image avec le profil obtenu.')
        if ($script:Restore) { $script:Restore.InCall = $true }
        # Prechauffage passe pendant la calibration (bouton « Passer le prechauffage ») : pas de second prechauffage
        try { Start-ImageWrite -NoWarmup:([bool]$cal.WarmSkip) } finally { if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
        if ($script:Restore -and -not ($script:GwProc -and -not $script:GwProc.HasExited) -and $script:Chain.Count -eq 0) { Stop-Restore (T 'l''écriture n''a pas démarré après la calibration, voir le journal') }
        return
    }
    Show-PrecompCurve $cal.Family $cal.Slow
}

# ============================== CONTROLE APRES ECRITURE ========================
# Apres une ecriture reussie : relecture en flux (3 tours) de toutes les pistes ecrites,
# classement de chaque piste avec Get-TrackMetrics (memes criteres que l onglet Qualite :
# erreurs hors classe, trous, stabilite entre tours, jitter). Une piste A SURVEILLER,
# CRITIQUE, illisible ou absente de la relecture est faible : elle est reecrite seule
# (pre-effacement force), puis seule remesuree. Au plus N passes (« Passes de reecriture »,
# 3 par defaut ; 0 = controle seul). Les pistes vides de l image (IPF : enregistrement
# sans bloc) ne sont pas controlees. Garde-fou : si plus de la moitie des pistes sont
# faibles au premier controle (format non MFM, disquette inadaptee, lecteur en defaut),
# aucune reecriture automatique n est lancee.
# Les commandes gw d une etape sont dans une file ($script:Rep.Pending) et la chaine
# n enfile que des appels generiques : pas de closure (cf. Start-Compare).
$script:Rep = $null

function Get-TrackKeyOrder([string]$k) {
    $p = $k -split '\.'
    return ([int]$p[0] * 2 + [int]$p[1])
}

function Sort-TrackKeys($keys) {
    # La virgule empeche PowerShell de transformer un tableau vide en $null au retour de la fonction
    return ,@(@($keys) | Where-Object { $_ } | Sort-Object { Get-TrackKeyOrder $_ })
}

function Format-TrackList($keys, [int]$max = 24) {
    # Liste de pistes pour le journal, tronquee au-dela de $max entrees
    $k = @($keys)
    if ($k.Count -le $max) { return ($k -join ', ') }
    return ((@($k[0..($max - 1)]) -join ', ') + ((T " ... (+{0})") -f "$($k.Count - $max)"))
}

function Get-ImageTrackSet([string]$path) {
    # Pistes presentes dans l image ('cyl.tete' -> $true), $null si non determinable
    $set = @{}
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    try {
        switch ($ext) {
            '.ipf' {
                $d = [System.IO.File]::ReadAllBytes($path); $pos = 0
                while ($pos + 12 -le $d.Length) {
                    $id = [System.Text.Encoding]::ASCII.GetString($d, $pos, 4); $ln = Get-BE32 $d ($pos + 4)
                    if ($ln -lt 12) { break }
                    if ($id -eq 'IMGE' -and $pos + 12 + 44 -le $d.Length) {
                        $cyl  = Get-BE32 $d ($pos + 12)          # piste (cylindre)
                        $side = Get-BE32 $d ($pos + 16)          # face
                        $bits = Get-BE32 $d ($pos + 12 + 36)     # bits de la piste
                        $blk  = Get-BE32 $d ($pos + 12 + 40)     # nombre de blocs : 0 = piste vide
                        if ($blk -gt 0 -and $bits -gt 0 -and $cyl -lt 200 -and $side -le 1) { $set["$cyl.$side"] = $true }
                    } elseif ($id -eq 'DATA' -and $pos + 16 -le $d.Length) { $ln += Get-BE32 $d ($pos + 12) }
                    $pos += $ln
                }
            }
            '.hfe' {
                $fs = [System.IO.File]::OpenRead($path)
                try { $h = New-Object byte[] 16; [void]$fs.Read($h, 0, 16) } finally { $fs.Dispose() }
                $nt = [int]$h[9]; $ns = [math]::Max(1, [math]::Min(2, [int]$h[10]))
                for ($c = 0; $c -lt $nt; $c++) { for ($hd = 0; $hd -lt $ns; $hd++) { $set["$c.$hd"] = $true } }
            }
            '.adf' {
                $n = Get-ImageCylinders $path
                if ($null -ne $n) { for ($c = 0; $c -lt $n; $c++) { $set["$c.0"] = $true; $set["$c.1"] = $true } }
            }
        }
    } catch { $set = @{} }
    if ($set.Count -gt 0) { return $set }
    return $null
}

function Get-TSpecExtras([string]$tspec) {
    # Elements du TSPEC utilisateur autres que c= et h= (step, h0.off, h1.off, hswap...) : conserves
    # tels quels dans les reecritures et relectures ciblees, pour viser les memes pistes physiques.
    if (-not $tspec) { return '' }
    $x = @($tspec -split ':' | Where-Object { $_.Trim() -and $_ -notmatch '^\s*[ch]\s*=' })
    if ($x.Count -eq 0) { return '' }
    return ':' + ($x -join ':')
}

function Get-TSpecHeads([string]$tspec) {
    # Tetes 0 et 1 retenues par le TSPEC utilisateur (h=0, h=1, h=0-1, h=0,1) ; les deux si h= est absent
    $m = [regex]::Match(":$tspec", ':\s*h\s*=\s*([^:]*)')
    if (-not $m.Success) { return ,@(0, 1) }
    $hs = @()
    foreach ($r in ($m.Groups[1].Value -split ',')) {
        if ($r -match '^\s*(\d+)\s*-\s*(\d+)\s*$') { for ($i = [int]$Matches[1]; $i -le [int]$Matches[2]; $i++) { $hs += $i } }
        elseif ($r -match '^\s*(\d+)\s*$') { $hs += [int]$Matches[1] }
    }
    return ,@(@(0, 1) | Where-Object { $hs -contains $_ })
}

function Set-TSpecHead([string]$tspec, [int]$h) {
    # TSPEC utilisateur restreint a la tete h : c=, step, h0.off, h1.off et hswap conserves. Sans c=, gw garde
    # les cylindres par defaut du format (ou c=0-81), comme l ecriture normale.
    $parts = @($tspec -split ':' | Where-Object { $_.Trim() -and $_ -notmatch '^\s*h\s*=' })
    return ((@($parts) + "h=$h") -join ':')
}

function Get-WriteWarmupTSpec([string]$userTs, [int[]]$heads, [string]$image) {
    # Pistes du prechauffage d une ecriture lente : un cylindre sur 10 de la zone ecrite, son premier et son dernier
    # (comme le test standard de la calibration), tetes ecrites, elements step, hswap, h0.off et h1.off du champ Pistes
    # conserves (memes pistes physiques que l ecriture). Zone : c= du champ Pistes, sinon cylindres de l image
    # (Get-ImageCylinders), sinon 40 cylindres, valables sur tout lecteur (40 pistes et step=2 compris)
    $hs = if (@($heads).Count -ge 2) { '0-1' } else { "$(@($heads)[0])" }
    $extras = Get-TSpecExtras $userTs
    $cyls = @()
    $m = [regex]::Match(":$userTs", ':\s*c\s*=\s*([^:]*)')
    if ($m.Success -and $m.Groups[1].Value.Trim()) {
        foreach ($r in ($m.Groups[1].Value -split ',')) {
            if ($r -match '^\s*(\d+)\s*-\s*(\d+)\s*$') { $cyls += @([int]$Matches[1]..[int]$Matches[2]) }
            elseif ($r -match '^\s*(\d+)\s*$') { $cyls += [int]$Matches[1] }
            else { return "c=$($m.Groups[1].Value.Trim()):h=$hs$extras" }      # forme non lue : c= repris tel quel
        }
    } else {
        $n = Get-ImageCylinders $image
        if ($null -eq $n) { $n = 40 }
        $cyls = @(0..([math]::Max(1, [math]::Min(84, [int]$n)) - 1))
    }
    $s = @($cyls | Sort-Object -Unique)
    $pick = @(@($s | Where-Object { $_ % 10 -eq 0 }) + @($s[0], $s[-1]))
    return "c=$(Format-CylList ([int[]]$pick)):h=$hs$extras"
}

function Invoke-WriteQueueNext {
    # Ecriture lente : commande gw write suivante (une par tete) ; pistes et retries de la precedente cumules pour le controle
    if ($script:WriteQueue.Count -eq 0) { return }
    Merge-RepRetries
    Start-Gw ([string[]]$script:WriteQueue.Dequeue())
}

function Start-WriteWarmup([string]$tspec, [bool]$noWarm) {
    # Prechauffage du lecteur avant une ecriture lente (fin de Start-ImageWrite, chaine d ecriture prete : onglet Ecriture,
    # Bibliotheque, restauration, reprise apres une calibration) : memes regles que celui de la calibration
    # (CalWarmupMinutes, Get-CalWarmupPlan : duree reduite ou prechauffage saute si le lecteur vient de servir, calibration
    # qui precede comprise ; lectures gw read sans ecriture, echecs toleres). Sans prechauffage (reglage a 0, case
    # « Prechauffer le lecteur » decochee, prechauffage passe pendant la calibration qui precede, lecteur deja actif) :
    # chaine lancee tout de suite. Sinon la chaine d ecriture est mise de cote (WriteWarm.Rest) pendant les lectures, puis
    # reprise telle quelle (Invoke-WriteWarmup) ; libelle et barre de l onglet Ecriture retablis a la fin.
    $script:WriteWarm = $null
    $drv = $cmbDrive.Text
    if ([double]$script:CalWarmupMinutes -le 0) { Invoke-NextChainStep; return }
    if (-not $chkWWarm.Checked) { Append-Log ((T "Préchauffage du lecteur {0} non demandé (case « Préchauffer le lecteur avant l'écriture lente » décochée) : écriture lente tout de suite.") -f "$drv"); Invoke-NextChainStep; return }
    if ($noWarm) { Append-Log ((T "Préchauffage du lecteur {0} passé à votre demande pendant la calibration : écriture lente tout de suite.") -f "$drv"); Invoke-NextChainStep; return }
    $plan = Get-CalWarmupPlan (Get-GwDriveKey (@('read') + (Get-CommonArgs))) ([double]$script:CalWarmupMinutes)
    $actTxt = Format-CalDuration ([math]::Round($plan.Active)); $idleTxt = Format-CalDuration ([math]::Round($plan.Idle))
    if ($plan.Skip) {
        Append-Log ((T "Préchauffage du lecteur {0} sauté : lecteur déjà en activité pendant {1} (dernière commande terminée il y a {2}).") -f "$drv", "$actTxt", "$idleTxt")
        Invoke-NextChainStep; return
    }
    $durTxt = Format-CalDuration ([math]::Round($plan.Sec))
    if ($plan.Reduced) { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant l'écriture lente, pour stabiliser sa température (durée réduite : lecteur déjà en activité pendant {2}, dernière commande terminée il y a {3}).") -f "$drv", "$durTxt", "$actTxt", "$idleTxt") }
    else { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant l'écriture lente, pour stabiliser sa température.") -f "$drv", "$durTxt") }
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $scp = Join-Path $script:TempDir 'write-warmup.scp'
    # Options d index et de densite de l ecriture (Get-WriteFormatArgs) : --fake-index et --densel par Get-DriveReadArgs,
    # --hard-sectors et --gen-tg43 ajoutees ici quand l ecriture les utilise (gw read 1.23 les declare, dans les memes
    # groupes exclusifs que gw write : --hard-sectors / --fake-index, --densel / --gen-tg43)
    $ro = @(Get-DriveReadArgs)
    if ($chkWHard.Checked) { $ro += '--hard-sectors' }
    if ($chkWTG43.Checked) { $ro += '--gen-tg43' }
    $script:WriteWarm = @{
        Drive = $drv; Rest = @($script:Chain.ToArray()); WarmSec = [double]$plan.Sec; WarmStart = (Get-Date)
        WarmReads = 0; WarmFails = 0; WarmFailRun = 0; WarmDurs = @(); WarmReadStart = $null; WarmSkip = $false; WarmScp = $scp
        WarmArgs = @(@('read') + (Get-CommonArgs) + $ro + @('--revs=3', "--tracks=$tspec", "`"$scp`""))
        LblText = $lblWCal.Text; LblVisible = $lblWCal.Visible; PbVisible = $pbWCal.Visible
    }
    $script:Chain.Clear()
    $pbWCal.Value = 0; $pbWCal.Visible = $true; $lblWCal.Visible = $true
    Invoke-WriteWarmup
}

function Invoke-WriteWarmup {
    # Lecture de prechauffage suivante, ou fin : meme regle que Invoke-CalibWarmup (CalWarmupMinReads lectures au moins,
    # arret a la duree ou avant une lecture qui la depasserait de plus d une demi-lecture), sur demande (bouton « Passer le
    # prechauffage » : apres la lecture en cours) ou apres CalWarmupMaxFails lectures de suite sans aboutir (code non nul,
    # ou code 0 et lecture incomplete : l ecriture commence et signale le defaut s il persiste). Fin : chaine d ecriture
    # mise de cote reprise telle quelle
    $w = $script:WriteWarm
    if (-not $w) { return }
    $failed = $false
    if ($w.WarmReadStart -is [datetime]) {
        $w.WarmDurs += ((Get-Date) - $w.WarmReadStart).TotalSeconds; $w.WarmReadStart = $null
        $code = [int]$script:GwLastCode
        if ($code -ne 0 -or [bool]$script:GwLastIncomplete) {
            $w.WarmFails++; $w.WarmFailRun++
            if ($w.WarmFails -eq 1) { Append-Log ((T "Préchauffage du lecteur {0} : la lecture n'a pas abouti (code {1}) ; sans effet sur l'écriture, le préchauffage continue.") -f "$($w.Drive)", "$code") }
        } else { $w.WarmFailRun = 0 }
        $failed = ([int]$w.WarmFailRun -ge $script:CalWarmupMaxFails)
    }
    if (Test-Path -LiteralPath $w.WarmScp) { Remove-Item -LiteralPath $w.WarmScp -Force -ErrorAction SilentlyContinue }
    $left = $w.WarmSec - ((Get-Date) - $w.WarmStart).TotalSeconds
    $avg = if (@($w.WarmDurs).Count -gt 0) { (@($w.WarmDurs) | Measure-Object -Average).Average } else { 0.0 }
    if ($failed -or ($w.WarmSkip -and $w.WarmReads -ge 1) -or ($w.WarmReads -ge $script:CalWarmupMinReads -and ($left -le 0 -or $left -lt $avg / 2))) {
        $elTxt = Format-CalDuration ([math]::Round(((Get-Date) - $w.WarmStart).TotalSeconds))
        if ($failed) { Append-Log ((T "Préchauffage du lecteur {0} arrêté après {1} lectures de suite sans aboutir (Greaseweazle, lecteur ou disquette absent ?) : l'écriture commence, elle signalera le défaut s'il persiste.") -f "$($w.Drive)", "$($w.WarmFailRun)") }
        elseif ($w.WarmFails -gt 0) { Append-Log ((T "Préchauffage du lecteur {0} terminé : {1} lecture(s) en {2}, dont {3} sans aboutir (sans effet sur l'écriture).") -f "$($w.Drive)", "$($w.WarmReads)", "$elTxt", "$($w.WarmFails)") }
        else { Append-Log ((T "Préchauffage du lecteur {0} terminé : {1} lecture(s) en {2}.") -f "$($w.Drive)", "$($w.WarmReads)", "$elTxt") }
        $script:WriteWarm = $null
        # Libelle et barre de l onglet Ecriture comme avant le prechauffage (ecriture, controle apres ecriture)
        $lblWCal.Text = $w.LblText; $lblWCal.Visible = [bool]$w.LblVisible; $pbWCal.Visible = [bool]$w.PbVisible
        if ($script:Restore -and $script:Restore.Cur -eq 5) { Set-RsStep 5 'run' }      # detail « prechauffage » retire
        $script:Chain.Clear()
        foreach ($s in @($w.Rest)) { $script:Chain.Enqueue($s) }
        Invoke-NextChainStep; return
    }
    $w.WarmReads++; $w.WarmReadStart = Get-Date; $script:GwLastCode = 0; $script:GwLastIncomplete = $false
    Update-WriteWarmupProgress
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw ([string[]]$script:WriteWarm.WarmArgs) -Soft })
    $script:Chain.Enqueue({ Invoke-WriteWarmup })
    Invoke-NextChainStep
}

function Update-WriteWarmupProgress {
    # Barre et libelle de l onglet Ecriture pendant le prechauffage d une ecriture lente (minuteur) : duree ecoulee sur la
    # duree prevue, avancement et temps restant en tete (libelle coupe a la largeur de l onglet) ; passe a la demande : fin
    # de la lecture en cours
    $w = $script:WriteWarm
    if (-not $w) { return }
    $g = Get-WarmupLeft $w
    $pbWCal.Value = $g.Pct
    $lblWCal.Text = if ($w.WarmSkip) { (T 'Préchauffage du lecteur {0} passé : fin de la lecture en cours.') -f "$($w.Drive)" }
                    else { (T "Préchauffage avant l'écriture : {2} %, reste environ {3} (lecteur {0}, lecture {1}, sans écriture)") -f "$($w.Drive)", "$($w.WarmReads)", "$($g.Pct)", (Format-CalDuration ([math]::Round($g.Left))) }
}

function Stop-WriteWarmup {
    # Abandon pendant le prechauffage d une ecriture lente (Arreter, gw non lance, erreur d etape, restauration en echec) :
    # chaine d ecriture mise de cote abandonnee, rien n est ecrit ; sans effet hors prechauffage (idempotent)
    if (-not $script:WriteWarm) { return }
    $script:WriteWarm = $null
    $pbWCal.Visible = $false
    $lblWCal.Text = (T 'Préchauffage interrompu : écriture annulée.')
    Append-Log (T 'Écriture annulée : préchauffage du lecteur interrompu.')
}

function Get-TrackGroups($keys) {
    # Pistes -> TSPEC exacts (aucune piste en trop) : cylindres a deux faces en h=0-1, puis face 0 seule, puis face 1 seule
    $heads = @{}
    foreach ($k in @($keys)) {
        $p = $k -split '\.'; $c = [int]$p[0]; $hd = [int]$p[1]
        if (-not $heads.ContainsKey($c)) { $heads[$c] = @{} }
        $heads[$c][$hd] = $true
    }
    $both = @(); $h0 = @(); $h1 = @()
    foreach ($c in ($heads.Keys | Sort-Object)) {
        if ($heads[$c].ContainsKey(0) -and $heads[$c].ContainsKey(1)) { $both += [int]$c }
        elseif ($heads[$c].ContainsKey(0)) { $h0 += [int]$c } else { $h1 += [int]$c }
    }
    $g = @()
    if ($both.Count -gt 0) { $g += "c=$(Format-CylList $both):h=0-1" }
    if ($h0.Count -gt 0)   { $g += "c=$(Format-CylList $h0):h=0" }
    if ($h1.Count -gt 0)   { $g += "c=$(Format-CylList $h1):h=1" }
    return ,$g
}

function Test-AdfHd([string]$path) {
    # ADF haute densite : multiple de 22 528 octets (2 faces x 22 secteurs x 512) au-dela de 84 cylindres double
    # densite, meme regle que Get-ImageCylinders et New-CalibPattern
    try { $len = (Get-Item -LiteralPath $path).Length } catch { return $false }
    return ($len -gt 0 -and $len % 22528 -eq 0 -and $len / 11264 -gt 84)
}

function Test-NeedsFormat([string]$path) {
    # Image secteur brute, sans geometrie : gw exige --format (classe IMG pour .img, .ima et .st ; .dsk sans signature
    # CPC, dsk.py : un DSK Apricot est lu par Apridisk, derive d IMG, qui exige aussi le format)
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    if (@('.img', '.ima', '.st') -contains $ext) { return $true }
    if ($ext -ne '.dsk') { return $false }
    try {
        $fs = [System.IO.File]::OpenRead($path)
        try { $b = New-Object byte[] 24; $n = $fs.Read($b, 0, 24) } finally { $fs.Dispose() }
        $s = [System.Text.Encoding]::ASCII.GetString($b, 0, $n)
        if ($s.StartsWith('MV - CPC') -or $s.StartsWith('EXTENDED CPC DSK')) { return $false }
    } catch { }
    return $true
}

function Test-HdFormat([string]$fmt) {
    # Formats gw a 500 ou 1000 kbit/s (diskdefs) : *_hd, *.1200, *.1440, *.1600, *.1680, *.dmf, *.2880, pc98.2hd/2hs,
    # *.hd, *.ed, os9.80dshd_*, luxor.1000.*, hp.mmfm.* (cellule de 1 us), raw.500, raw.1000
    if (-not $fmt) { return $false }
    return ($fmt -match '(_hd|dshd_\d+|\.(1200|1440|1600|1680|dmf|2880|2hd|2hs|hd|ed))$' -or $fmt -match '^(raw\.(500|1000)$|luxor\.1000\.|hp\.mmfm\.)')
}

function Get-CellOutOfRange([string]$path) {
    # Cellule d une image IPF ou HFE hors de la plage que la calibration sait mesurer : ScpStats exige des 2T entre
    # 3 et 5 us, soit une cellule de 1,5 a 2,5 us ; marge retenue 1 700 a 2 300 ns (MFM double densite, long track
    # compris). Renvoie la cellule arrondie (ns), $null si elle est dans la plage ou non lue (autres formats).
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    $info = $null
    try { switch ($ext) { '.ipf' { $info = Get-IpfCellInfo $path } '.hfe' { $info = Get-HfeCellInfo $path } } } catch { return $null }
    if ($null -eq $info -or [double]::IsNaN([double]$info.CellNs)) { return $null }
    if ($info.CellNs -lt 1700 -or $info.CellNs -gt 2300) { return [int][math]::Round($info.CellNs, 0) }
    return $null
}

function Get-DriveReadArgs {
    # Options de lecteur de l onglet Ecriture utilisables en relecture (controle apres ecriture, calibration) : sans
    # --fake-index, un lecteur sans capteur d index ne relit rien
    $o = @()
    if ($chkWReverse.Checked)         { $o += '--reverse' }
    if ($cmbWDensel.Text -ne '(non)') { $o += "--densel=$($cmbWDensel.Text)" }
    if ($txtWFakeIdx.Text.Trim())     { $o += "--fake-index=$($txtWFakeIdx.Text.Trim())" }
    return $o
}

function Get-HighDensityReason([string]$path, [string]$fmt) {
    # Image ou format haute densite ; $null sinon. Les familles de calibration (standard 2 us, long track 1,89 us) sont
    # double densite : une calibration HD ecraserait la courbe standard, appliquee ensuite aux disquettes DD.
    # Sans format explicite : format implicite de gw pour l extension (HDM, XDF, FDI, DIM, DCP : pc98.2hd ou 2hs ;
    # D2M, D4M : CMD FD2000 HD, FD4000 ED), image secteur brute de 1 200 000 octets ou plus, mode de la premiere
    # piste d un IMD.
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    if (-not $fmt -or $fmt -eq '(auto)') {
        $def = @{ '.hdm' = 'pc98.2hd'; '.xdf' = 'pc98.2hd'; '.fdi' = 'pc98.2hd'; '.dim' = 'pc98.2hd'; '.dcp' = 'pc98.2hd'
                  '.d2m' = 'commodore.cmd.fd2000.hd'; '.d4m' = 'commodore.cmd.fd4000.ed' }
        if ($def.ContainsKey($ext)) { $fmt = $def[$ext] }
    }
    if (Test-HdFormat $fmt) { return ((T "format haute densité {0}") -f "$fmt") }
    try {
        if ($ext -eq '.adf' -and (Test-AdfHd $path)) { return (T 'ADF haute densité') }
        if (@('.img', '.ima', '.st', '.dsk', '.msa') -contains $ext) {
            $len = (Get-Item -LiteralPath $path).Length
            if ($len -ge 1200000) { return ((T "image secteur de {0} octets") -f "$len") }
        }
        if ($ext -eq '.imd') {
            # IMD : en-tete texte termine par 0x1A, puis mode de la premiere piste (0 = FM, 3 = MFM a 500 kbit/s)
            $fs = [System.IO.File]::OpenRead($path)
            try { $b = New-Object byte[] 65536; $n = $fs.Read($b, 0, $b.Length) } finally { $fs.Dispose() }
            $i = [Array]::IndexOf($b, [byte]0x1A, 0, $n)
            if ($i -ge 0 -and $i + 1 -lt $n -and ($b[$i + 1] -eq 0 -or $b[$i + 1] -eq 3)) { return (T 'image IMD à 500 kbit/s') }
        }
        $info = $null
        switch ($ext) { '.ipf' { $info = Get-IpfCellInfo $path } '.hfe' { $info = Get-HfeCellInfo $path } }
        if ($null -ne $info -and $info.CellNs -lt 1500) { return ((T "image haute densité, cellule {0} ns") -f "$([math]::Round($info.CellNs, 0))") }
    } catch { }
    return $null
}

function Get-WriteCheckBlocker([string]$path, [string]$fmt) {
    # Raison pour laquelle l analyse de flux (calibree MFM double densite, cellule 2 us) ne s applique pas ; $null sinon
    if ($chkWHard.Checked) { return (T 'secteurs durs') }
    if ($chkWTG43.Checked) { return (T 'lecteur 8 pouces (TG43)') }
    $hd = Get-HighDensityReason $path $fmt
    if ($hd) { return $hd }
    if ($fmt -match '^(commodore\.15[47]1|mac\.|apple2\.)') { return ((T "format GCR {0}") -f "$fmt") }
    # Format FM de la table (simple densite, groupe 'fm' de Get-FormatCalibInfo) : les criteres sont ceux du MFM
    if ($fmt -and $fmt -ne '(auto)' -and $script:GwFormats.Contains($fmt) -and (Get-FormatCalibInfo $fmt).Group -eq 'fm') { return ((T "format FM {0}") -f "$fmt") }
    # Piste 0 en FM, les autres en MFM (codage fm0 de la table : tsc.flex.*, olivetti.m20...) : la piste 0 serait jugee
    # avec les criteres du MFM et pourrait etre reecrite a tort ; controle bloque pour tout le format
    if ($fmt -and $fmt -ne '(auto)' -and $script:GwFormats.Contains($fmt) -and [string]$script:GwFormats[$fmt].Enc -eq 'fm0') { return ((T "piste 0 en FM, format {0}") -f "$fmt") }
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    if (@('.d64', '.d71', '.g64', '.nib', '.woz', '.do', '.po') -contains $ext) { return ((T "image GCR {0}") -f "$ext") }
    try {
        if ($ext -eq '.scp' -and $script:ScpStatsOk -and (Test-ScpHighDensity $path)) { return (T 'flux SCP haute densité') }
    } catch { }
    return $null
}

function Test-ScpHighDensity([string]$path) {
    # Flux MFM double densite : aucun intervalle sous 3 us (2T = 4 us). Haute densite : 2T = 2 us, donc
    # une large part d intervalles sous 2,6 us. Premier tour de la premiere piste presente.
    $d = [System.IO.File]::ReadAllBytes($path)
    if ($d.Length -lt 700 -or [System.Text.Encoding]::ASCII.GetString($d, 0, 3) -ne 'SCP') { return $false }
    $res = ($d[11] + 1) * 25
    for ($t = 0; $t -lt 168; $t++) {
        $o = [BitConverter]::ToUInt32($d, 16 + 4 * $t)
        if ($o -eq 0) { continue }
        $ln = [BitConverter]::ToUInt32($d, $o + 8); $doff = [BitConverter]::ToUInt32($d, $o + 12)
        $flux = [ScpStats]::Decode($d, [int]($o + $doff), [int]$ln, $res)
        if ($flux.Count -lt 1000) { continue }
        $short = @($flux | Where-Object { $_ -gt 500 -and $_ -lt 2600 }).Count
        return ($short -gt 0.2 * $flux.Count)
    }
    return $false
}

function New-WriteCheck([string[]]$base, [string]$image, [string]$userTSpec, [int]$max, [string[]]$readOpts, $headPrecomp) {
    # $headPrecomp : ecriture lente, --precomp par tete logique (0, 1 -> profil ou $null) ; $base est alors sans --precomp
    $script:WriteTracks = @{}; $script:WriteRetries = @{}   # rien d une ecriture precedente dans le perimetre
    $script:Rep = @{
        Base = @($base); Image = $image; UserTSpec = $userTSpec; Max = [math]::Max(0, $max)
        Common = @(Get-CommonArgs); ReadOpts = @($readOpts)   # lecteur et port memorises au clic : les relectures visent le meme disque
        HeadPrecomp = $headPrecomp; Written = @{}              # Written : pistes ecrites, cumulees sur les commandes (ecriture lente)
        Round = 0; Scope = $null; Weak = @(); State = @{}; Retries = @{}; Rewrites = @{}
        Pending = (New-Object System.Collections.Queue); Scps = @(); Safety = $false; Measured = 0
        # Zone instable relue sur la copie = defaut de la copie, sauf source capable d en porter (voir Set-CopyUnstable)
        UnstDefect = (-not (Test-SourceMayHaveWeak $image)); NoJudge = $null; SrcWeak = $null
    }
    # Une mesure continue de l onglet Qualite ecraserait le resultat du controle : elle est arretee
    $script:AlignLoop = $false; $script:AlignNextAt = $null; $script:AlLastMove = 0
    $lblWCal.Text = (T 'Écriture en cours, contrôle de toutes les pistes ensuite.')
    $pbWCal.Visible = $false; $lblWCal.Visible = $true
}

function Test-SourceMayHaveWeak([string]$path) {
    # Sources dont gw ecrit les zones faibles comme une zone sans flux (une transition toutes les 32 cellules, track.py
    # MasterTrack.force_random_weak), relue volontairement instable : IPF (CAPS), HFE v3 (opcode Rand), EDSK (secteur
    # stocke en plusieurs copies). Flux .raw, .kf, .a2r, .ctr : non analyses. Fichier illisible : prudence.
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    if (@('.ipf', '.raw', '.kf', '.a2r', '.ctr') -contains $ext) { return $true }
    if (@('.hfe', '.dsk', '.edsk') -notcontains $ext) { return $false }
    try {
        $fs = [System.IO.File]::OpenRead($path)
        try { $b = New-Object byte[] 16; $n = $fs.Read($b, 0, 16) } finally { $fs.Dispose() }
        $s = [System.Text.Encoding]::ASCII.GetString($b, 0, $n)
        return ($s.StartsWith('HXCHFEV3') -or $s.StartsWith('EXTENDED CPC DSK'))
    } catch { return $true }
}

function Set-CopyUnstable($rep, [string]$k, $m) {
    # gw ecrit un tour fige de la source : une zone instable d un tour a l autre relue sur la copie ne vient pas de la
    # source quand celle-ci n en contient pas a cette piste (image secteur, HFE v1/v2, piste stable d un SCP analyse).
    # Elle signale alors un defaut de la copie (support fatigue, defaut localise) : la piste est faible et reecrite.
    # Pistes instables ou critiques de la source (Rep.Ignore) : traitees a part. Non jugees (Unjudged : ni reecrites ni
    # comptees saines) : source qui peut porter des zones faibles (Test-SourceMayHaveWeak), SCP non analysable, piste
    # que la source porte avec une courte zone instable ou que l analyse n a pas pu mesurer (Rep.NoJudge).
    if (-not $m -or $m.Bad -or -not $m.Weak) { return }
    if ($rep.Ignore -and $rep.Ignore.ContainsKey($k)) { return }
    if (-not $rep.UnstDefect -or ($rep.NoJudge -and $rep.NoJudge.ContainsKey($k))) { $m.Unjudged = $true; return }
    $m.CopyDefect = $true
    if ($m.Level -lt 1) { $m.Level = 1 }
}

function Merge-RepRetries {
    # Retries et pistes ecrites de la derniere ecriture gw (remis a zero a chaque nouvelle ecriture) -> cumul du controle
    $rep = $script:Rep
    if (-not $rep) { return }
    foreach ($k in @($script:WriteTracks.Keys)) { $rep.Written[$k] = $true }
    foreach ($k in @($script:WriteRetries.Keys)) {
        $n = [int]$script:WriteRetries[$k]
        if (-not $rep.Retries.ContainsKey($k) -or $n -gt $rep.Retries[$k]) { $rep.Retries[$k] = $n }
    }
}

function Add-RepReads($groups, [string]$extras) {
    # Relectures en flux d un groupe de TSPEC, un fichier SCP par commande
    $rep = $script:Rep
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $rep.Scps = @(); $i = 0
    foreach ($g in @($groups)) {
        $scp = Join-Path $script:TempDir ("check-r{0}-{1}.scp" -f $rep.Round, $i)
        if (Test-Path -LiteralPath $scp) { Remove-Item -LiteralPath $scp -Force }
        $rep.Pending.Enqueue([string[]](@('read') + $rep.Common + $rep.ReadOpts + @('--revs=3', "--tracks=$g$extras", "`"$scp`"")))
        $rep.Scps += $scp; $i++
    }
}

function Start-RepPending {
    # Une etape de chaine par commande en file, puis l analyse
    $rep = $script:Rep
    $script:Chain.Clear()
    for ($i = 0; $i -lt $rep.Pending.Count; $i++) { $script:Chain.Enqueue({ Invoke-RepNextCmd }) }
    $script:Chain.Enqueue({ Invoke-WriteCheckAnalysis })
    Invoke-NextChainStep
}

function Invoke-RepNextCmd {
    $rep = $script:Rep
    if (-not $rep -or $rep.Pending.Count -eq 0) { return }
    Merge-RepRetries
    $cmd = [string[]]$rep.Pending.Dequeue()
    if ($rep.Round -eq 0) { $lblWCal.Text = (T 'Contrôle après écriture : relecture de toutes les pistes...') }
    elseif ($cmd[0] -eq 'write') { $lblWCal.Text = ((T "Contrôle après écriture : réécriture {0}/{1} de {2} piste(s) faible(s)...") -f "$($rep.Round)", "$($rep.Max)", "$($rep.Weak.Count)") }
    else { $lblWCal.Text = ((T "Contrôle après écriture : remesure {0}/{1} de {2} piste(s)...") -f "$($rep.Round)", "$($rep.Max)", "$($rep.Weak.Count)") }
    Start-Gw $cmd
}

function Start-WriteCheck {
    # Etape de chaine apres l ecriture initiale (code retour 0) : relecture de toutes les pistes ecrites
    $rep = $script:Rep
    if (-not $rep) { return }
    Merge-RepRetries
    if (-not $script:ScpStatsOk) {
        Append-Log (T 'Contrôle après écriture : module d''analyse SCP indisponible, contrôle ignoré.'); $script:Rep = $null
        if ($script:Restore) { Stop-Restore (T 'contrôle des pistes indisponible') }
        return
    }
    # Perimetre = pistes que gw a reellement ecrites (lignes « Writing Track » ; une piste vide effacee n en a pas),
    # limitees a l image quand ses pistes sont connues. A defaut : pistes de l image, puis 80 x 2.
    $img = Get-ImageTrackSet $rep.Image
    $set = @{}
    foreach ($k in @($rep.Written.Keys)) { if ($null -eq $img -or $img.ContainsKey($k)) { $set[$k] = $true } }
    if ($set.Count -eq 0) {
        if ($null -ne $img) { $set = $img }
        else {
            $n = Get-ImageCylinders $rep.Image; if ($null -eq $n) { $n = 80 }
            for ($c = 0; $c -lt [int]$n; $c++) { $set["$c.0"] = $true; $set["$c.1"] = $true }
        }
    }
    $rep.Scope = $set
    $rep.Round = 0
    $groups = Get-TrackGroups @($set.Keys)                # pistes exactes ecrites, memes elements step/offsets que l ecriture
    Append-Log ((T "Contrôle après écriture : relecture en flux de {0} piste(s) de l'image (3 tours).") -f "$($set.Count)")
    $rep.Pending.Clear()
    Add-RepReads $groups (Get-TSpecExtras $rep.UserTSpec)
    Start-RepPending
}

function Invoke-WriteCheckAnalysis {
    $rep = $script:Rep
    if (-not $rep) { return }
    Merge-RepRetries
    if ($rep.Round -gt 0) {
        # Passe terminee : toutes ses ecritures et relectures ont rendu le code 0
        foreach ($k in @($rep.Weak)) { $rep.Rewrites[$k] = 1 + $(if ($rep.Rewrites.ContainsKey($k)) { [int]$rep.Rewrites[$k] } else { 0 }) }
    }
    $tracks = @{}
    foreach ($scp in $rep.Scps) {
        if (-not (Test-Path -LiteralPath $scp)) { Append-Log (T 'Contrôle après écriture : fichier SCP absent, analyse impossible.'); Stop-WriteCheck; return }
        try { $t = Read-ScpFile $scp } catch { Append-Log ((T "Contrôle après écriture : {0}") -f "$($_.Exception.Message)"); Stop-WriteCheck; return }
        foreach ($tn in $t.Keys) { $tracks[[int]$tn] = $t[$tn] }
    }
    # Pistes attendues : premier controle = image (ou TSPEC utilisateur relu, limite a l image) ; ensuite = pistes reecrites
    if ($rep.Round -eq 0) { $expected = @($rep.Scope.Keys) } else { $expected = @($rep.Weak) }
    $expected = Sort-TrackKeys $expected
    $watch = @(); $crit = @(); $healthy = 0
    foreach ($k in $expected) {
        $tn = Get-TrackKeyOrder $k
        if ($tracks.ContainsKey($tn)) { $m = Get-TrackMetrics $tracks[$tn] }
        else { $m = Get-TrackMetrics @(); $m.Missing = $true }
        Set-CopyUnstable $rep $k $m
        $rep.State[$k] = $m
        if ($m.Bad -or $m.Level -ge 2) { $crit += $k } elseif ($m.Level -eq 1) { $watch += $k }
        elseif (-not $m.Unjudged -and -not ($m.Weak -and $rep.Ignore -and $rep.Ignore.ContainsKey($k))) { $healthy++ }
    }
    $unjK = @($expected | Where-Object { $rep.State[$_].Unjudged -and -not $rep.State[$_].Bad -and $rep.State[$_].Level -lt 1 })
    if ($unjK.Count -gt 0 -and $rep.Round -eq 0) { Append-Log ((T "Contrôle : zone instable sur {0} piste(s) non jugée(s) ({1}) : la source peut en contenir (protection) sans que l'application puisse le vérifier. Ni réécrites ni comptées comme saines.") -f "$($unjK.Count)", "$(Format-TrackList $unjK)") }
    $defK = @($expected | Where-Object { $rep.State[$_].CopyDefect })
    if ($defK.Count -gt 0) { Append-Log ((T "Contrôle : zone instable d'un tour à l'autre sur la copie, piste(s) {0} : la source n'en contient pas, défaut probable du support. Ces pistes sont traitées comme faibles.") -f "$(Format-TrackList $defK)") }
    if ($rep.Ignore) {
        # Restauration d un flux ou image SCP : pistes deja critiques ou non reproductibles (zone instable), non comptees
        $ign = @(@($watch) + @($crit) | Where-Object { $rep.Ignore.ContainsKey($_) })
        if ($ign.Count -gt 0 -and $rep.Round -eq 0) { Append-Log ((T "Contrôle : {0} piste(s) non reproductible(s) ou déjà critique(s) dans la source, non comptée(s) : {1}") -f "$($ign.Count)", "$(Format-TrackList $ign)") }
        $watch = @($watch | Where-Object { -not $rep.Ignore.ContainsKey($_) }); $crit = @($crit | Where-Object { -not $rep.Ignore.ContainsKey($_) })
    }
    $weak = Sort-TrackKeys (@($watch) + @($crit))
    $lw = if ($watch.Count -gt 0) { " : $(Format-TrackList $watch)" } else { '' }
    $lc = if ($crit.Count -gt 0) { " : $(Format-TrackList $crit)" } else { '' }
    if ($rep.Round -eq 0) {
        $rep.Measured = $expected.Count
        Append-Log ((T "Contrôle complet : {0} piste(s) mesurée(s), {1} saine(s), {2} à surveiller{3}, {4} critique(s) ou illisible(s){5}.") -f "$($expected.Count)", "$healthy", "$($watch.Count)", "$lw", "$($crit.Count)", "$lc")
    } else {
        Append-Log ((T "Remesure après réécriture {0}/{1} : {2} piste(s), {3} saine(s), {4} à surveiller{5}, {6} critique(s) ou illisible(s){7}.") -f "$($rep.Round)", "$($rep.Max)", "$($expected.Count)", "$healthy", "$($watch.Count)", "$lw", "$($crit.Count)", "$lc")
    }
    $rep.Weak = $weak
    if ($expected.Count -eq 0) { Append-Log (T 'Contrôle après écriture : aucune piste mesurée.'); Complete-WriteCheck; return }
    if ($weak.Count -eq 0) { Complete-WriteCheck; return }
    # Garde-fou sur un controle large seulement : une selection de quelques pistes doit pouvoir etre reecrite
    # Garde-fou calcule aux seuils Standard : un reglage strict du jitter fait reecrire davantage, sans faux diagnostic
    $weakStd = @($weak | Where-Object { $s = $rep.State[$_]; $s.Bad -or (Get-HealthLevel $s.Ooc $s.Dr $s.Stab $s.J 120 250) -ge 1 })
    if ($rep.Round -eq 0 -and $expected.Count -ge 20 -and $weakStd.Count * 2 -gt $expected.Count) {
        $rep.Safety = $true
        Append-Log ((T "Plus de la moitié des pistes sont faibles ({0}/{1}) : format non MFM, disquette inadaptée ou lecteur en défaut. Aucune réécriture automatique.") -f "$($weakStd.Count)", "$($expected.Count)")
        Complete-WriteCheck; return
    }
    if ($rep.Round -ge $rep.Max) { Complete-WriteCheck; return }
    # Passe de reecriture : pistes faibles seules, pre-effacement force, puis remesure de ces seules pistes
    $rep.Round++
    Append-Log ((T "Réécriture des pistes faibles, passe {0}/{1} : {2}") -f "$($rep.Round)", "$($rep.Max)", "$(Format-TrackList $weak)")
    $groups = Get-TrackGroups $weak
    $extras = Get-TSpecExtras $rep.UserTSpec
    $wbase = @($rep.Base); if ($wbase -notcontains '--pre-erase') { $wbase += '--pre-erase' }
    $rep.Pending.Clear()
    if ($null -ne $rep.HeadPrecomp) {
        # Ecriture lente : une reecriture par tete, chacune avec sa precompensation
        foreach ($h in 0, 1) {
            $cs = @($weak | Where-Object { ($_ -split '\.')[1] -eq "$h" } | ForEach-Object { [int](($_ -split '\.')[0]) })
            if ($cs.Count -eq 0) { continue }
            $cmd = @($wbase); if ($rep.HeadPrecomp[$h]) { $cmd += @('--precomp', $rep.HeadPrecomp[$h]) }
            $rep.Pending.Enqueue([string[]]($cmd + @("--tracks=c=$(Format-CylList $cs):h=$h$extras", "`"$($rep.Image)`"")))
        }
    } else {
        foreach ($g in $groups) { $rep.Pending.Enqueue([string[]]($wbase + @("--tracks=$g$extras", "`"$($rep.Image)`""))) }
    }
    Add-RepReads $groups $extras
    Start-RepPending
}

function Show-WriteCheckTable($rep) {
    # Etat final de chaque piste controlee (derniere mesure) dans l onglet Qualite, avec reecritures et retries
    $keys = Sort-TrackKeys @($rep.State.Keys)
    $last = @{}; $total = 0.0; $count = 0
    $lvAl.Columns[1].Width = $(if (@($rep.State.Values | Where-Object { $_.Weak }).Count -gt 0) { 280 } else { 200 })
    $lvAl.BeginUpdate()
    try {
        $lvAl.Items.Clear()
        foreach ($k in $keys) {
            $m = $rep.State[$k]
            $mark = ''
            if ($rep.Rewrites.ContainsKey($k)) { $mark = ((T " (réécrite x{0})") -f "$($rep.Rewrites[$k])") }
            elseif ($rep.Retries.ContainsKey($k)) { $mark = ((T " (essais x{0})") -f "$($rep.Retries[$k])") }
            [void]$lvAl.Items.Add((New-AlignRow $k $m $mark '-' -1))
            if ($m.Bad) { $last[$k] = @{ Score = 9999; Jitter = 0; Asym = 0; Err = 0; Stab = 0; Cell = 0 }; continue }
            $last[$k] = @{ Score = $m.Score; Jitter = $m.J; Asym = $m.Asym; Err = $m.Ooc; Stab = $m.Stab; Cell = $m.Cell }
            $total += $m.Score; $count++
        }
    } finally { $lvAl.EndUpdate() }
    # Bandeau des zones instables d apres la derniere mesure du controle (efface celui d une mesure precedente)
    $inIgn = { param($k) $rep.Ignore -and $rep.Ignore.ContainsKey($k) }
    $defK = @($keys | Where-Object { $rep.State[$_].CopyDefect })
    $srcK = @($keys | Where-Object { $rep.State[$_].Weak -and (& $inIgn $_) -and $rep.SrcWeak -and $rep.SrcWeak.ContainsKey($_) })
    $crtK = @($keys | Where-Object { $rep.State[$_].Weak -and (& $inIgn $_) -and -not ($rep.SrcWeak -and $rep.SrcWeak.ContainsKey($_)) })
    $unkK = @($keys | Where-Object { $rep.State[$_].Unjudged -and -not (& $inIgn $_) })
    Set-UnstableBanner @(
        $(if ($defK.Count -gt 0) { (T "Zone instable sur la copie, défaut probable du support (la source n'en contient pas) : {0}") -f "$(Format-TrackList $defK)" }),
        $(if ($srcK.Count -gt 0) { (T "Zone instable de la source (protection probable, non reproductible) : {0}") -f "$(Format-TrackList $srcK)" }),
        $(if ($crtK.Count -gt 0) { (T "Zone instable sur une piste déjà critique dans la source : {0}") -f "$(Format-TrackList $crtK)" }),
        $(if ($unkK.Count -gt 0) { (T "Zone instable non jugée (la source peut contenir une protection) : {0}") -f "$(Format-TrackList $unkK)" }))
    $script:AlignLast = $last
    if ($count -gt 0) {
        $avg = [math]::Round($total / $count, 0); $lvl = Get-AlLevel 'score' $avg
        $lblAlVerdict.Text = ((T "Contrôle après écriture : score moyen {0} ({1}) sur {2} piste(s) lisible(s)") -f "$avg", "$($script:AlNames[$lvl])", "$count")
        $lblAlVerdict.BackColor = $script:AlColors[$lvl]; $lblAlVerdict.ForeColor = $script:AlFg[$lvl]
    } else {
        $lblAlVerdict.Text = (T 'Aucune piste analysable'); $lblAlVerdict.BackColor = $script:AlColors[3]; $lblAlVerdict.ForeColor = $script:AlFg[3]
    }
    Render-AlignBars
}

function Complete-WriteCheck([switch]$GwError) {
    $rep = $script:Rep; $script:Rep = $null
    if (-not $rep) { return }
    Show-WriteCheckTable $rep
    $n = $rep.State.Count
    $weak = @(@($rep.Weak) | Where-Object { $_ })
    $nRew = $rep.Rewrites.Count
    # Pistes ignorees (non reproductibles ou deja critiques) : ni saines ni faibles, signalees a part ; de meme les pistes
    # a zone instable non jugee
    $ignK = @(@($rep.State.Keys) | Where-Object { $rep.Ignore -and $rep.Ignore.ContainsKey($_) -and ($rep.State[$_].Bad -or $rep.State[$_].Level -ge 1 -or $rep.State[$_].Weak) })
    $unjK = @(@($rep.State.Keys) | Where-Object { $rep.State[$_].Unjudged -and -not $rep.State[$_].Bad -and $rep.State[$_].Level -lt 1 -and -not ($rep.Ignore -and $rep.Ignore.ContainsKey($_)) })
    $nOk = $n - $ignK.Count - $unjK.Count
    if ($GwError) {
        # gw a echoue pendant une passe de reecriture : les pistes de la passe restent faibles
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE interrompu par une erreur gw à la passe {0}/{1} : {2} piste(s) faible(s) ou non remesurée(s) : {3}  ->  support fatigué ou lecteur en défaut") -f "$($rep.Round)", "$($rep.Max)", "$($weak.Count)", "$(Format-TrackList $weak)"); $lvl = 3
    } elseif ($n -eq 0) {
        $txt = (T 'CONTRÔLE APRÈS ÉCRITURE : aucune piste mesurée.'); $lvl = 3
    } elseif ($weak.Count -eq 0) {
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE : {0}/{1} pistes saines") -f "$nOk", "$n")
        if ($ignK.Count -gt 0) { $txt += ((T ", {0} piste(s) non reproductible(s) ou déjà critique(s) non comptée(s) : {1}") -f "$($ignK.Count)", "$(Format-TrackList (Sort-TrackKeys $ignK))") }
        if ($unjK.Count -gt 0) { $txt += ((T ", {0} piste(s) à zone instable non jugée(s) : {1}") -f "$($unjK.Count)", "$(Format-TrackList (Sort-TrackKeys $unjK))") }
        if ($nRew -gt 0) { $txt += ((T ", après réécriture de {0} piste(s) en {1} passe(s)") -f "$nRew", "$($rep.Round)") }
        $lvl = 0
    } elseif ($rep.Safety) {
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE : {0}/{1} pistes faibles, réécriture automatique non lancée (plus de la moitié des pistes)  ->  vérifier le format, la disquette et le lecteur") -f "$($weak.Count)", "$n"); $lvl = 3
    } elseif ($rep.Max -eq 0) {
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE : {0}/{1} piste(s) faible(s) : {2}  (réécriture automatique désactivée)") -f "$($weak.Count)", "$n", "$(Format-TrackList $weak)"); $lvl = 2
    } else {
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE : {0} piste(s) encore faible(s) après {1} passe(s) de réécriture : {2}  ->  support fatigué, réécrire sur une autre disquette") -f "$($weak.Count)", "$($rep.Round)", "$(Format-TrackList $weak)"); $lvl = 3
    }
    $lblAlHealth.Text = $txt; $lblAlHealth.BackColor = $script:AlColors[$lvl]; $lblAlHealth.ForeColor = $script:AlFg[$lvl]
    $lblWCal.Text = $txt; $lblWCal.Visible = $true
    Append-Log $txt
    # Bilan exploitable par la restauration (accroche : le controle vide la chaine d etapes, rien ne le suit)
    $short = if ($GwError) { (T 'contrôle interrompu par une erreur gw') } elseif ($lvl -eq 0) { (T "{0}/{1} pistes saines") -f "$nOk", "$n" }
             elseif ($n -eq 0) { (T 'aucune piste mesurée') } else { (T "{0} piste(s) faible(s) : {1}") -f "$($weak.Count)", "$(Format-TrackList $weak)" }
    $script:LastCheck = @{ Ok = ($lvl -eq 0); Level = $lvl; Text = $txt; Short = $short; Weak = $weak; Measured = $n; Rounds = $rep.Round; Rewrites = $nRew; GwError = [bool]$GwError }
    if ($script:Restore) {
        if ($GwError) { Stop-Restore (T 'erreur gw pendant le contrôle des pistes') } else { Invoke-RestoreNext }
        return
    }
    Show-Tab $tabAl
}

function Update-RepPartial {
    # Passe interrompue par gw : une relecture terminee implique que les ecritures de la passe l ont precedee.
    # Les pistes remesurees prennent leur nouvelle mesure ; les autres restent « faibles ou non remesurees ».
    $rep = $script:Rep
    $remeasured = @{}
    foreach ($scp in @($rep.Scps)) {
        if (-not (Test-Path -LiteralPath $scp)) { continue }
        try { $t = Read-ScpFile $scp } catch { continue }
        foreach ($tn in @($t.Keys)) {
            $k = "$([math]::Floor([int]$tn / 2)).$([int]$tn % 2)"
            if (@($rep.Weak) -notcontains $k) { continue }
            $mm = Get-TrackMetrics $t[$tn]; Set-CopyUnstable $rep $k $mm
            $rep.State[$k] = $mm
            $rep.Rewrites[$k] = 1 + $(if ($rep.Rewrites.ContainsKey($k)) { [int]$rep.Rewrites[$k] } else { 0 })
            $remeasured[$k] = $true
        }
    }
    $rep.Weak = Sort-TrackKeys @(@($rep.Weak) | Where-Object { -not $remeasured.ContainsKey($_) -or $rep.State[$_].Bad -or $rep.State[$_].Level -ge 1 })
}

function Stop-WriteCheck([switch]$GwError) {
    # Abandon (bouton Arreter, erreur gw, operation incomplete, fichier manquant) : rien n est reecrit ensuite.
    # Erreur gw pendant une passe de reecriture : verdict et tableau avec les mesures deja acquises.
    if (-not $script:Rep) { return }
    if ($GwError -and $script:Rep.Round -gt 0 -and $script:Rep.State.Count -gt 0) { Update-RepPartial; Complete-WriteCheck -GwError; return }
    $script:Rep = $null
    $lblWCal.Text = (T 'Contrôle après écriture interrompu.')
    Append-Log (T 'Contrôle après écriture interrompu.')
    if ($script:Restore) { Stop-Restore (T 'contrôle des pistes interrompu') }
}

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

function Get-RestoreDefaultDir {
    return (Join-Path ([Environment]::GetFolderPath('MyDocuments')) ('Greaseweazle Studio\' + (T 'Restaurations')))
}

function Get-RestoreFormat {
    # '' = copie exacte du flux
    if ($cmbRsFmt.SelectedIndex -le 0) { return '' }
    return [string]$cmbRsFmt.SelectedItem
}

function Get-SafeFileName([string]$s) {
    $bad = [System.IO.Path]::GetInvalidFileNameChars()
    $o = -join @($s.ToCharArray() | ForEach-Object { if ($bad -contains $_) { '_' } else { $_ } })
    return $o.Trim().TrimEnd('.')
}

function Update-RsRules {
    $r = $script:RestoreRules
    $lblRsRules.Text = ((T "Règles appliquées à la copie : écriture tête par tête avec la calibration existante du lecteur (calibration par tête si aucune n'existe), pré-effacement, vérification par gw, {0} essais par piste, contrôle de toutes les pistes ({1} passes de réécriture au plus), puis relecture et comparaison avec l'original.") -f "$($r.WriteRetries)", "$($r.RepairPasses)")
}

function Set-RsStep([int]$i, [string]$state, [string]$detail = '') {
    $g = @{ pending = '○'; run = '▶'; ok = '✓'; fail = '✗'; skip = '–'; warn = '!' }[$state]
    $c = @{ pending = $script:Theme.Muted; run = $script:Theme.Accent; ok = $script:Theme.Ok; fail = $script:Theme.Danger; skip = $script:Theme.Muted; warn = $script:Theme.Warn }[$state]
    $l = $script:RsStepLabels[$i]
    $l.Text = "$g  " + $script:RsStepNames[$i] + $(if ($detail) { "  -  $detail" } else { '' })
    $l.ForeColor = $c
    $l.Font = if ($state -eq 'run') { $bold } else { $form.Font }
    $tip.SetToolTip($l, $l.Text)
    if ($script:Restore) {
        $script:Restore.Steps[$i] = @{ State = $state; Detail = $detail }
        if ($state -eq 'run') { $script:Restore.Cur = $i }
    }
}

function Reset-RsSteps {
    for ($i = 0; $i -lt $script:RsStepNames.Count; $i++) { Set-RsStep $i 'pending' }
    $pnlRsWait.Visible = $false; $lblRsResult.Visible = $false; $lblRsNow.Text = ''; $lblRsRules.Visible = $true
}

function Set-RsLock([bool]$lock) {
    # Pendant une restauration : seuls l onglet Restauration et le bouton Arreter restent utilisables
    foreach ($p in $script:AllTabs) { if ($p -ne $tabRs) { $p.Enabled = -not $lock } }
    foreach ($c in @($grpRsSrc, $grpRsDst, $grpRsDir, $btnRsStart, $cmbDrive, $chkExpert)) { $c.Enabled = -not $lock }
    $btnCfgReset.Enabled = -not $lock -and -not ($script:GwProc -and -not $script:GwProc.HasExited)
    $btnCfgSave.Enabled = $btnCfgReset.Enabled
}

function Save-WriteTabState {
    return @{ File = $txtWFile.Text; Fmt = $cmbWFmt.Text; Slow = $chkWSlow.Checked; Pre = $chkWPreErase.Checked; Empty = $chkWEraseEmpty.Checked
              NoVer = $chkWNoVerify.Checked; Retries = $numWRetries.Value; Precomp = $chkWPrecomp.Checked; Post = $chkWPostCheck.Checked
              Repair = $numWRepair.Value; Tracks = $txtWTracks.Text; CalMode = $cmbWCalMode.SelectedIndex; Profile = $cmbWProfile.SelectedIndex
              P0 = $txtWPrecomp.Text; P1 = $txtWPrecomp1.Text; Drive = $cmbDrive.Text; Source = $script:PresetSource }
}

function Restore-WriteTabState($s) {
    # Onglet Ecriture et lecteur remis tels qu avant la restauration (les calibrations obtenues restent enregistrees)
    if (-not $s) { return }
    $txtWFile.Text = $s.File; Set-Combo $cmbWFmt $s.Fmt; if ($cmbWFmt.Text -ne $s.Fmt) { $cmbWFmt.Text = $s.Fmt }
    $chkWSlow.Checked = $s.Slow; $chkWPreErase.Checked = $s.Pre; $chkWEraseEmpty.Checked = $s.Empty; $chkWNoVerify.Checked = $s.NoVer
    Set-Num $numWRetries $s.Retries; $chkWPrecomp.Checked = $s.Precomp; $chkWPostCheck.Checked = $s.Post; Set-Num $numWRepair $s.Repair
    $txtWTracks.Text = $s.Tracks; $cmbWCalMode.SelectedIndex = $s.CalMode; $cmbWProfile.SelectedIndex = $s.Profile
    $script:PresetSource = $s.Source
    $cmbDrive.SelectedItem = $s.Drive
    Update-PrecompForImage $txtWFile.Text
    if ($cmbWProfile.Text -eq (T 'Manuel')) { $txtWPrecomp.Text = $s.P0; $txtWPrecomp1.Text = $s.P1 }
    $chkWPrecomp.Checked = $s.Precomp                      # Set-PrecompFields la recoche
}

function Start-Restore {
    if ($script:Restore) { return }
    $busy = @()
    if ($script:GwProc -and -not $script:GwProc.HasExited) { $busy += (T 'commande gw') }
    if ($script:Cal) { $busy += (T 'calibration') }
    if ($script:Rep) { $busy += (T 'contrôle après écriture') }
    if ($script:Chain.Count -gt 0) { $busy += (T 'séquence d''étapes') }
    if ($busy.Count -gt 0) {
        Append-Log ((T "Restauration refusée : opération en cours ({0}).") -f ($busy -join ', '))
        [void][System.Windows.Forms.MessageBox]::Show((T 'Une opération est déjà en cours : attendez sa fin ou cliquez sur « Arrêter ».'),(T 'Restauration'),'OK','Information'); return
    }
    if (-not (Test-Path -LiteralPath $script:GwExe)) {
        [void][System.Windows.Forms.MessageBox]::Show(((T "gw.exe introuvable : {0}`n`nPlacez ce script dans le même répertoire que gw.exe.") -f "$($script:GwExe)"),(T 'Erreur'),'OK','Error'); return
    }
    if (-not $script:ScpStatsOk) {
        [void][System.Windows.Forms.MessageBox]::Show((T "Restauration impossible : le module d'analyse de flux n'a pas pu être compilé, le contrôle strict des pistes n'est donc pas disponible."),(T 'Restauration'),'OK','Warning'); return
    }
    if ($chkWHard.Checked -or $chkWTG43.Checked) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Restauration non prise en charge avec « Secteurs durs » ou « TG43 » cochés dans les options avancées de l''onglet Écriture : le contrôle des pistes est calibré pour le MFM double densité.'),(T 'Restauration'),'OK','Warning'); return
    }
    $fmt = Get-RestoreFormat
    $dir = $txtRsDir.Text.Trim()
    if (-not $dir) { $dir = Get-RestoreDefaultDir }
    if (-not [System.IO.Path]::IsPathRooted($dir)) { $dir = Join-Path $script:AppDir $dir }
    try { $dir = [System.IO.Path]::GetFullPath($dir) } catch { }
    try { New-Item -ItemType Directory -Force -Path $dir -ErrorAction Stop | Out-Null }
    catch { [void][System.Windows.Forms.MessageBox]::Show(((T "Dossier de sauvegarde inaccessible : {0}") -f "$($_.Exception.Message)"),(T 'Restauration'),'OK','Warning'); return }
    $name = Get-SafeFileName $txtRsName.Text
    if (-not $name) { $name = (T 'disquette') + ' ' + (Get-Date -Format "yyyy-MM-dd HH'h'mm") }
    $ext = if ($fmt) { Get-DecodedExt $fmt } else { '.scp' }
    # Jamais d ecrasement : suffixe (2), (3)... si une restauration du meme nom existe deja
    $stem = Join-Path $dir $name; $k = 1
    while (Test-Path -LiteralPath ($stem + ' - ' + (T 'original') + $ext)) { $k++; $stem = (Join-Path $dir $name) + " ($k)" }
    $src = [string]$cmbRsSrc.SelectedItem; $dst = [string]$cmbRsDst.SelectedItem
    $same = ($src -eq $dst)
    $modeTxt = if ($fmt) { (T "secteur par secteur, format {0}") -f "$fmt" } else { (T 'copie exacte du flux, sans précompensation ni comparaison par secteur') }
    $swap = if ($same) { (T "Le lecteur {0} lit l'original, puis vous changez de disquette quand l'application vous le demande.") -f "$src" }
            else { (T "Le lecteur {0} lit l'original et le lecteur {1} écrit la copie.") -f "$src", "$dst" }
    $msg = ((T "Restauration ({0}).`n`n{1}`n`n1. Insérez maintenant la disquette d'ORIGINE dans le lecteur {2}, de préférence protégée en écriture.`n2. Sa lecture est enregistrée dans :`n   {3}`n3. La disquette de destination sera entièrement effacée puis écrite.`n`nCommencer la lecture ?") -f "$modeTxt", "$swap", "$src", "$dir")
    if ([System.Windows.Forms.MessageBox]::Show($msg, (T 'Restauration'), 'OKCancel', 'Information') -ne 'OK') { return }
    $txtRsDir.Text = $dir
    $script:Restore = @{
        Mode = $(if ($fmt) { 'sector' } else { 'flux' }); Fmt = $fmt; Ext = $ext; Src = $src; Dst = $dst; Same = $same; Name = $name
        Orig = ($stem + ' - ' + (T 'original') + $ext); Back = ($stem + ' - ' + (T 'copie relue') + $ext); Report = ($stem + ' - ' + (T 'rapport') + '.txt')
        Probe = (Join-Path $script:TempDir ("restore-probe-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + $ext))
        Stage = 'read'; Waiting = $false; Override = $false; InCall = $false; Idle = (Get-Date); Start = (Get-Date); Cur = 0
        Steps = @{}; Saved = (Save-WriteTabState); Read = $null; Cmp = $null; Calib = ''; HD = ''
        CalibUsed = $null; CalibDone = $false; CalSwap = $false; SwapBack = $false; SwapDeadline = $null
        Finger = $null; OnOriginal = $false; Preserved = @()   # flux : empreinte de l original, ecriture sur l original, cylindres preserves
        Extras = (Get-TSpecExtras $txtWTracks.Text)       # step, hswap, h0.off, h1.off : geometrie du lecteur
    }
    $script:LastCheck = $null
    Reset-RsSteps; Set-RsLock $true
    if (-not (Test-Path -LiteralPath $script:TempDir)) { New-Item -ItemType Directory -Force -Path $script:TempDir | Out-Null }
    Append-Log ''
    Append-Log ((T "=== RESTAURATION : {0} ({1}) ===") -f "$name", "$modeTxt")
    Append-Log ((T "Original : lecteur {0} -> {1}") -f "$src", "$($script:Restore.Orig)")
    Append-Log ((T "Copie    : lecteur {0}") -f "$dst")
    $cmbDrive.SelectedItem = $src
    Invoke-RestoreRead
}

function Invoke-RestoreRead {
    $r = $script:Restore
    Set-RsStep 0 'run'
    $a = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs)
    if ($r.Mode -eq 'sector') {
        $a += @("--format=$($r.Fmt)", "--revs=$($script:RestoreRules.ReadRevs)", "--retries=$($script:RestoreRules.ReadRetries)", "--seek-retries=$($script:RestoreRules.SeekRetries)")
    } else {
        $a += "--revs=$($script:RestoreRules.ReadRevs)"
    }
    if ($r.Extras) { $a += "--tracks=$($r.Extras.TrimStart(':'))" }
    $a += "`"$($r.Orig)`""
    $script:RestoreArgs = $a
    $script:GwCapture = New-Object System.Collections.Generic.List[string]
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw $script:RestoreArgs })
    $script:Chain.Enqueue({ Invoke-RestoreNext })
    Invoke-NextChainStep
}

function Invoke-RestoreNext {
    $r = $script:Restore
    if (-not $r) { return }
    $r.Idle = Get-Date
    switch ($r.Stage) {
        'read'    { Complete-RestoreRead }
        'probe'   { Complete-RestoreProbe }
        'write'   { Start-RestoreCompare }
        'compare' { Complete-RestoreCompare }
    }
}

function Get-GwSectorSummary($lines) {
    # Bilan d une lecture gw avec format : « T0.0: AmigaDOS (11/11 sectors) from ... » (derniere ligne de la piste),
    # « T0.0: Giving up: 2 sectors missing », « Found 1758 sectors of 1760 (99%) »
    $tracks = @{}; $gaveUp = @{}; $found = -1; $total = -1
    foreach ($l in @($lines)) {
        if ($l -match '^T(\d+)\.(\d+)\b[^:]*: Giving up: (\d+) sectors? missing') { $gaveUp["$($Matches[1]).$($Matches[2])"] = [int]$Matches[3] }
        elseif ($l -match '^T(\d+)\.(\d+)\b[^:]*: .*\((\d+)/(\d+) sectors\)') { $tracks["$($Matches[1]).$($Matches[2])"] = @([int]$Matches[3], [int]$Matches[4]) }
        elseif ($l -match '^Found (\d+) sectors of (\d+)') { $found = [int]$Matches[1]; $total = [int]$Matches[2] }
    }
    return @{ Tracks = $tracks; GaveUp = $gaveUp; Found = $found; Total = $total }
}

function Get-BadSectorBlocks([string]$path) {
    # Blocs de 512 octets remplis par gw du motif « -=[BAD SECTOR]=- » (secteur manquant a la lecture)
    $b = [System.IO.File]::ReadAllBytes($path)
    $pat = [System.Text.Encoding]::ASCII.GetBytes('-=[BAD SECTOR]=-')
    $list = New-Object System.Collections.Generic.List[int]
    for ($s = 0; $s + 512 -le $b.Length; $s += 512) {
        $same = $true
        for ($i = 0; $i -lt 512; $i++) { if ($b[$s + $i] -ne $pat[$i % 16]) { $same = $false; break } }
        if ($same) { $list.Add([int]($s / 512)) }
    }
    return ,$list.ToArray()
}

function Get-BlockTracks([int[]]$blocks, [string]$fmt) {
    # Pistes « cyl.tete » des blocs (image double face entrelacee, secteurs par piste du format)
    $spt = Get-SectorsPerTrack $fmt
    $set = @{}
    if ($spt -le 0) { return @() }
    foreach ($b in $blocks) { $t = [math]::Floor($b / $spt); $set["$([math]::Floor($t / 2)).$($t % 2)"] = $true }
    return (Sort-TrackKeys @($set.Keys))         # elements emis un par un : @() chez l appelant reste plat
}

function Complete-RestoreRead {
    $r = $script:Restore
    $lines = @(); if ($script:GwCapture) { $lines = @($script:GwCapture) }
    $script:GwCapture = $null
    if (-not (Test-Path -LiteralPath $r.Orig) -or (Get-Item -LiteralPath $r.Orig).Length -eq 0) {
        Fail-Restore 0 (T 'la lecture n''a produit aucun fichier (disquette absente ou lecteur incorrect ?)'); return
    }
    Set-RsStep 0 'ok' (Split-Path -Leaf $r.Orig)
    Set-RsStep 1 'run'
    if ($r.Mode -eq 'sector') {
        $sum = Get-GwSectorSummary $lines
        $bad = Get-BadSectorBlocks $r.Orig
        $miss = @($sum.GaveUp.Keys) + @(Get-BlockTracks $bad $r.Fmt)
        $miss = Sort-TrackKeys @($miss | Select-Object -Unique)
        $r.Read = @{ Found = $sum.Found; Total = $sum.Total; Bad = $bad.Count; Tracks = $miss }
        if ($sum.Total -le 0) { Fail-Restore 1 (T 'gw n''a imprimé aucun bilan de secteurs : format incorrect, ou disquette illisible ?'); return }
        $nMiss = [math]::Max($bad.Count, $sum.Total - $sum.Found)
        if ($nMiss -gt 0) {
            # Secteurs illisibles regroupes sur une ou deux pistes : protection contre la copie probable
            $nTk = @($miss).Count
            $fmtMiss = if ($nTk -ge 1 -and $nTk -le 2) { (T "{0} secteur(s) illisible(s), regroupés sur la ou les pistes {1} : c'est souvent une protection contre la copie (secteurs volontairement illisibles), qu'une copie secteur par secteur ne peut pas reproduire. Relancez avec « Copie exacte du flux ».") }
                       else { (T "{0} secteur(s) illisible(s) sur l'original (pistes {1}) : une copie fidèle est impossible. Nettoyez les têtes du lecteur et relancez, ou choisissez « Copie exacte du flux » si la disquette est protégée contre la copie.") }
            Fail-Restore 1 ($fmtMiss -f "$nMiss", "$(Format-TrackList $miss)")
            return
        }
        Set-RsStep 1 'ok' ((T "{0}/{1} secteurs lus") -f "$($sum.Found)", "$($sum.Total)")
        Append-Log ((T "Restauration : original lu en entier, {0}/{1} secteurs.") -f "$($sum.Found)", "$($sum.Total)")
    } else {
        # Flux : qualite piste par piste (MFM double densite) ; la decision revient a l utilisateur au changement de disquette
        if (Test-ScpHighDensity $r.Orig) {
            # Copie de flux HD : ni precompensation, ni verification gw, ni controle des pistes -> rien ne serait verifie
            Fail-Restore 1 (T 'flux haute densité : une copie de flux ne pourrait pas être contrôlée. Choisissez un format haute densité (amiga.amigados_hd, ibm.1440) pour une copie vérifiée secteur par secteur.'); return
        } else {
            try { $t = Read-ScpFile $r.Orig -Finger } catch { Fail-Restore 1 ((T "flux illisible : {0}") -f "$($_.Exception.Message)"); return }
            $n = 0; $sane = 0; $watch = 0; $crit = 0; $critKeys = @{}; $weakKeys = @{}; $unstKeys = @{}; $noMeas = @{}; $fp = $null; $maxTn = 0
            foreach ($tn in @($t.Keys | Sort-Object)) {
                # Original juge aux seuils Standard (120 / 250 ns), independants du reglage du jitter
                $m = Get-TrackMetrics $t[$tn]; $n++
                $lv = if ($m.Bad) { 2 } else { Get-HealthLevel $m.Ooc $m.Dr $m.Stab $m.J 120 250 }
                $key = "$([math]::Floor([int]$tn / 2)).$([int]$tn % 2)"
                if ([int]$tn -gt $maxTn) { $maxTn = [int]$tn }
                if ($lv -ge 2) { $crit++; $critKeys[$key] = $true } elseif ($lv -ge 1) { $watch++ } else { $sane++ }
                # Zone instable d un tour a l autre : bits faibles d une protection probable, non reproductibles
                if ($m.Weak) { $weakKeys[$key] = $true } elseif ($m.ShortUnstable -and $lv -lt 2) { $unstKeys[$key] = $true }
                elseif ($lv -lt 2 -and $m.Blocks -eq 0) { $noMeas[$key] = $true }
                # Empreinte : piste stable la plus riche en motifs, pour reconnaitre l original dans le lecteur de destination
                $r0 = $t[$tn][0]
                if ($lv -lt 2 -and -not $m.Weak -and $r0.Finger -and $r0.Finger.Count -ge 6 -and (-not $fp -or $r0.Rich -gt $fp.Rich)) {
                    $fp = @{ Tn = [int]$tn; Cyl = [int][math]::Floor([int]$tn / 2); Head = [int]$tn % 2; Fp = [string[]]$r0.Finger; Cell = [double]$r0.Cell; Rich = [int]$r0.Rich }
                }
            }
            if ($n -eq 0) { Fail-Restore 1 (T 'aucune piste dans le flux lu.'); return }
            if ($sane -eq 0 -or $crit * 2 -gt $n) {
                Fail-Restore 1 ((T "lecture sans données exploitables : {0} piste(s) critique(s) sur {1}. Disquette vierge, lecteurs inversés ou têtes sales ?") -f "$crit", "$n"); return
            }
            # Pistes deja critiques (cylindres non formates, protection) ou a zone instable (bits faibles) sur l original :
            # ni reecrites ni comptees au controle de la copie, jamais reecrites sur une disquette identique a l original
            $r.Read = @{ Tracks = $n; Sane = $sane; Watch = $watch; Crit = $crit; CritKeys = $critKeys; WeakKeys = $weakKeys; UnstKeys = $unstKeys; NoMeas = $noMeas; MaxCyl = [int][math]::Floor($maxTn / 2) }
            $r.Finger = $fp
            $txt = if ($weakKeys.Count -gt 0) { (T "{0} pistes : {1} saines, {2} à surveiller, {3} critiques, {4} à zone instable") -f "$n", "$sane", "$watch", "$crit", "$($weakKeys.Count)" }
                   else { (T "{0} pistes : {1} saines, {2} à surveiller, {3} critiques") -f "$n", "$sane", "$watch", "$crit" }
            Set-RsStep 1 $(if ($crit -gt 0 -or $weakKeys.Count -gt 0) { 'warn' } else { 'ok' }) $txt
            Append-Log ((T "Restauration : flux de l'original, {0}.") -f "$txt")
            if ($weakKeys.Count -gt 0) {
                Append-Log ((T "Restauration : {0} piste(s) non reproductible(s) sur l'original, zone instable d'un tour à l'autre ({1}) : bits faibles d'une protection contre la copie probable, ou défaut localisé. La copie n'en recevra qu'un tour figé : la protection risque de ne pas fonctionner. Ces pistes ne sont jamais réécrites sur une disquette identique à l'original.") -f "$($weakKeys.Count)", "$(Format-TrackList (Sort-TrackKeys @($weakKeys.Keys)))")
            }
            if ($unstKeys.Count -gt 0) {
                Append-Log ((T "Restauration : {0} piste(s) avec une courte zone instable ({1}) : raccord d'écriture ou protection possible. Elles ne seront jamais réécrites sur une disquette identique à l'original.") -f "$($unstKeys.Count)", "$(Format-TrackList (Sort-TrackKeys @($unstKeys.Keys)))")
            }
            if ($fp) { Append-Log ((T "Restauration : empreinte de l'original prise sur la piste {0}.{1} ({2} blocs de référence) : la disquette de destination y sera comparée.") -f "$($fp.Cyl)", "$($fp.Head)", "$($fp.Fp.Count)") }
            else { Append-Log (T "Restauration : aucune piste de l'original ne permet une empreinte fiable : la disquette de destination ne pourra pas être comparée à l'original.") }
        }
    }
    Enter-RestoreWait ''
}

function Enter-RestoreWait([string]$extra) {
    $r = $script:Restore
    $r.Stage = 'wait'; $r.Waiting = $true
    $cmbDrive.SelectedItem = $r.Dst
    Set-RsStep 2 'run'
    $msg = if ($r.SwapBack) { (T "Calibration terminée. Retirez la disquette sacrifiée du lecteur {0} et insérez la disquette de DESTINATION : tout son contenu sera remplacé. Elle sera de nouveau vérifiée avant l'écriture.") -f "$($r.Dst)" }
           elseif ($r.Same) { (T "Retirez l'ORIGINAL du lecteur {0} et rangez-le. Insérez la disquette de DESTINATION : tout son contenu sera remplacé.") -f "$($r.Dst)" }
           else { (T "Vérifiez que la disquette de DESTINATION est dans le lecteur {0} : tout son contenu sera remplacé.") -f "$($r.Dst)" }
    if ($extra) { $msg = $extra + "`n" + $msg }
    if ($r.Mode -eq 'flux' -and $r.Read -and $r.Read.WeakKeys -and $r.Read.WeakKeys.Count -gt 0) { $msg = ((T "PROTECTION PROBABLE : {0} piste(s) de l'original changent d'un tour à l'autre (bits faibles) : une copie ne peut pas les reproduire et risque de ne pas fonctionner.") -f "$($r.Read.WeakKeys.Count)") + "`n" + $msg }
    if ($r.Mode -eq 'flux' -and $r.Read -and $r.Read.Crit -gt 0) { $msg = ((T "{0} piste(s) critique(s) dans la lecture : normal pour une protection, sinon nettoyez le lecteur et relancez.") -f "$($r.Read.Crit)") + "`n" + $msg }
    $lblRsWait.Text = $msg + ' ' + (T 'Puis cliquez sur « Continuer ».')
    $btnRsForce.Visible = [bool]$r.Override
    # Boutons sous le texte (hauteur variable) ; « Ecraser quand meme » seul sur une seconde ligne
    $y = $lblRsWait.Bottom + 8
    $btnRsGo.Location = New-Object System.Drawing.Point(8, $y)
    $btnRsCancel.Location = New-Object System.Drawing.Point(($btnRsGo.Right + 8), $y)
    $bottom = $btnRsGo.Bottom
    if ($r.Override) { $btnRsForce.Location = New-Object System.Drawing.Point(8, ($btnRsGo.Bottom + 8)); $bottom = $btnRsForce.Bottom }
    $pnlRsWait.Height = $bottom + 8
    $pnlRsWait.Visible = $true; $pnlRsWait.BringToFront(); $lblRsRules.Visible = $false
    $lblRsNow.Text = ''
    Show-Tab $tabRs
    $tabRs.ScrollControlIntoView($pnlRsWait)                 # fenetre basse : l encadre et son bouton Continuer restent visibles
    $stOp.Text = (T 'Restauration : changez de disquette, puis cliquez sur « Continuer » dans l''onglet Restauration.')
    Append-Log ((T "Restauration : en attente de la disquette de destination dans le lecteur {0}.") -f "$($r.Dst)")
    try { [System.Media.SystemSounds]::Exclamation.Play() } catch { }
}

function Get-RestoreKeepCyls {
    # Flux : cylindres portant une piste non reproductible (zone instable, meme courte) ou deja critique sur l original,
    # jamais reecrits sur une disquette identique a l original
    $r = $script:Restore; $set = @{}
    if (-not $r -or $r.Mode -ne 'flux' -or -not $r.Read) { return @() }
    $src = @(@($r.Read.CritKeys.Keys) + @($r.Read.WeakKeys.Keys))
    if ($r.Read.UnstKeys) { $src += @($r.Read.UnstKeys.Keys) }
    foreach ($k in $src) { $set[[int](([string]$k -split '\.')[0])] = $true }
    return @($set.Keys | Sort-Object)
}

function Resume-Restore([bool]$force, [bool]$auto = $false) {
    $r = $script:Restore
    if (-not $r -or -not $r.Waiting) { return }
    if ($script:GwProc -and -not $script:GwProc.HasExited) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Une commande gw est encore en cours : attendez sa fin.'),(T 'Restauration'),'OK','Information'); return
    }
    if ($force) {
        # « Ecraser quand meme » : la disquette inseree a le contenu de l original, c est peut-etre l original lui-meme.
        # Flux : les cylindres non reproductibles ne seront pas reecrits ; secteur : toute protection hors secteurs serait detruite.
        if ($r.Mode -eq 'sector') { $msg = (T "La disquette insérée a le même contenu que l'original : c'est peut-être l'ORIGINAL lui-même.`n`nEn mode secteur, chaque piste est réécrite au format standard : si la disquette porte une protection contre la copie (piste non standard, bits faibles), elle sera définitivement détruite. Pour une disquette protégée, utilisez « Copie exacte du flux ».`n`nÉcraser quand même cette disquette ?") }
        else {
            $keep = @(Get-RestoreKeepCyls)
            # Chaque cylindre a preserver : aucune ecriture possible sans detruire la protection -> refus
            $incF = @(); if ($r.Read) { $incF = @(0..([int]$r.Read.MaxCyl) | Where-Object { $keep -notcontains $_ }) }
            if ($keep.Count -gt 0 -and $incF.Count -eq 0) {
                [void][System.Windows.Forms.MessageBox]::Show(((T "La disquette insérée a le même contenu que l'original. Chaque cylindre ({0}) porte une piste non reproductible ou critique : aucun cylindre ne peut être réécrit sans détruire la protection. Écriture refusée : insérez une autre disquette.") -f "$(Format-CylList $keep)"), (T 'Restauration'), 'OK', 'Warning')
                return
            }
            $msg = if ($keep.Count -gt 0) { (T "La disquette insérée a le même contenu que l'original : c'est peut-être l'ORIGINAL lui-même.`n`nLes cylindres qui portent des pistes non reproductibles ou déjà critiques sur l'original ({0}) ne seront pas réécrits : leur protection éventuelle est préservée. Les autres pistes seront effacées puis réécrites à partir de la lecture.`n`nÉcraser quand même cette disquette ?") -f "$(Format-CylList $keep)" }
                   else { (T "La disquette insérée a le même contenu que l'original : c'est peut-être l'ORIGINAL lui-même.`n`nAucune piste non reproductible n'a été détectée : toutes les pistes seront effacées puis réécrites à partir de la lecture.`n`nÉcraser quand même cette disquette ?") }
        }
        $q = [System.Windows.Forms.MessageBox]::Show($msg, (T 'Restauration'), 'YesNo', 'Warning', 'Button2')
        if ($q -ne 'Yes') { return }
    } elseif ($r.Mode -eq 'flux' -and $r.Same -and -not $r.Finger) {
        # Copie de flux sans empreinte exploitable : aucune sonde possible, confirmation explicite que l original a ete retire
        $q = [System.Windows.Forms.MessageBox]::Show((T "Copie de flux : l'application ne peut pas vérifier que la disquette insérée n'est pas l'original.`n`nAvez-vous bien retiré l'ORIGINAL et inséré la disquette de DESTINATION ?"), (T 'Restauration'), 'YesNo', 'Warning', 'Button2')
        if ($q -ne 'Yes') { return }
    }
    $r.Waiting = $false; $r.SwapBack = $false; $r.SwapDeadline = $null; $pnlRsWait.Visible = $false; $r.Idle = Get-Date; $r.Override = $false
    if ($auto) { Set-RsStep 2 'warn' ((T "reprise automatique après {0} s sans réponse : changement de disquette non confirmé") -f "$($script:CalibConfirmSeconds)") }
    else { Set-RsStep 2 'ok' }
    if (-not $force -and ($r.Mode -eq 'sector' -or $r.Finger)) { Start-RestoreProbe; return }
    if ($force) { $r.OnOriginal = $true; Set-RsStep 3 'warn' (T 'contrôle ignoré à votre demande') }
    else { Set-RsStep 3 'skip' (T "non vérifiable : aucune empreinte exploitable sur l'original") }
    Start-RestoreWrite
}

function Start-RestoreProbe {
    # Lecture du seul cylindre 0 de la disquette inseree (3 tours, 2 essais) : identique a l original -> c est l original
    $r = $script:Restore
    $r.Stage = 'probe'
    Set-RsStep 3 'run'
    Remove-Item -LiteralPath $r.Probe -ErrorAction SilentlyContinue
    if ($r.Mode -eq 'flux') {
        # Flux : lecture de la piste de l empreinte (2 tours), comparee aux blocs de reference de l original
        $f = $r.Finger
        $script:RestoreArgs = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @("--tracks=c=$($f.Cyl):h=$($f.Head)$($r.Extras)", '--revs=2', "`"$($r.Probe)`"")
    } else {
        $script:RestoreArgs = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @("--format=$($r.Fmt)", "--tracks=c=0:h=0-1$($r.Extras)", '--revs=3', '--retries=2', "`"$($r.Probe)`"")
    }
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw $script:RestoreArgs })
    $script:Chain.Enqueue({ Invoke-RestoreNext })
    Invoke-NextChainStep
}

function Restore-ProbeFailed {
    # Sonde sans resultat (pas de disquette, pas d index) : retour a l attente plutot qu un abandon
    $r = $script:Restore
    $script:Chain.Clear()
    $r.Override = $false
    Set-RsStep 3 'pending'
    Enter-RestoreWait (T 'Aucune disquette lisible n''a été détectée dans le lecteur de destination.')
}

function Complete-RestoreProbe {
    $r = $script:Restore
    if (-not (Test-Path -LiteralPath $r.Probe)) { Restore-ProbeFailed; return }
    if ($r.Mode -eq 'flux') {
        # Empreinte : au moins les trois quarts des blocs de reference retrouves -> memes donnees que l original
        $f = $r.Finger; $fl = $null
        try { $fl = Read-ScpTrackFlux $r.Probe $f.Tn } catch { $fl = $null }
        if (-not $fl -or $fl.Count -eq 0) { Restore-ProbeFailed; return }
        $hit = [ScpStats]::Match($fl, [double]$f.Cell, [string[]]$f.Fp)
        Append-Log ((T "Restauration : empreinte de la piste {0}.{1} retrouvée {2} fois sur {3} sur la disquette insérée.") -f "$($f.Cyl)", "$($f.Head)", "$hit", "$($f.Fp.Count)")
        if ($hit * 4 -ge $f.Fp.Count * 3) {
            Set-RsStep 3 'fail' (T 'la disquette insérée semble être l''original')
            Append-Log ((T "Restauration : la disquette de destination porte les mêmes données que l'original (empreinte de la piste {0}.{1}). Écriture refusée.") -f "$($f.Cyl)", "$($f.Head)")
            $r.Override = $true
            Enter-RestoreWait (T "ATTENTION : la disquette insérée porte les mêmes données que l'original, c'est probablement l'ORIGINAL. Changez de disquette. S'il s'agit d'une ancienne copie à remplacer entièrement, cliquez sur « Annuler », effacez-la (case « Mode expert », onglet Outils, bouton « EFFACER »), puis relancez la restauration. « Écraser quand même » sert à rafraîchir l'original : les cylindres non reproductibles ou critiques ne sont ni réécrits ni contrôlés.")
            return
        }
        Set-RsStep 3 'ok' (T 'ce n''est pas l''original')
        Start-RestoreWrite
        return
    }
    # Cylindre 0, secteur par secteur : un secteur non relu par la sonde (motif BAD SECTOR de gw) ne compte pas ;
    # au moins un secteur lu et tous les secteurs lus identiques a l original -> c est l original (meme abime)
    $a = [System.IO.File]::ReadAllBytes($r.Orig); $p = [System.IO.File]::ReadAllBytes($r.Probe)
    $spt = Get-SectorsPerTrack $r.Fmt
    $n = if ($spt -gt 0) { 2 * $spt * 512 } else { 1024 }
    $n = [math]::Min($n, [math]::Min($a.Length, $p.Length))
    $pat = [System.Text.Encoding]::ASCII.GetBytes('-=[BAD SECTOR]=-')
    $readable = 0; $differ = 0
    for ($s = 0; $s + 512 -le $n; $s += 512) {
        $isBad = $true
        for ($i = 0; $i -lt 512; $i++) { if ($p[$s + $i] -ne $pat[$i % 16]) { $isBad = $false; break } }
        if ($isBad) { continue }
        $readable++
        for ($i = 0; $i -lt 512; $i++) { if ($a[$s + $i] -ne $p[$s + $i]) { $differ++; break } }
    }
    $same = ($readable -gt 0 -and $differ -eq 0)
    if ($same) {
        Set-RsStep 3 'fail' (T 'la disquette insérée semble être l''original')
        Append-Log (T 'Restauration : la disquette de destination contient les mêmes données que l''original sur le cylindre 0. Écriture refusée.')
        $r.Override = $true
        Enter-RestoreWait (T "ATTENTION : la disquette insérée a le même contenu que l'original sur le cylindre 0, c'est probablement l'ORIGINAL. Changez de disquette. S'il s'agit bien d'une copie à remplacer, cliquez sur « Écraser quand même ».")
        return
    }
    Set-RsStep 3 'ok' (T 'ce n''est pas l''original')
    Start-RestoreWrite
}

function Get-RestoreCalibInfo([string]$fam, [int]$nCyl = 0) {
    # Calibration de l ecriture stricte : une calibration existante (par tete si a jour, sinon commune, comme l applique
    # l ecriture lente) n est jamais refaite ; Need seulement si la famille n en a aucune. Notes : reserves a signaler,
    # dont une courbe plus courte que l image de nCyl cylindres (> 0) de plus de 4 cylindres (Get-CalibState 'short')
    $cvs = Get-FamilyCurves $fam $true
    if ($cvs.Count -eq 0) { return @{ Need = $true; Text = (T 'aucune calibration existante'); Notes = @() } }
    $text = if ($cvs.Count -gt 1) { (T 'par tête') } else { (T 'commune aux deux têtes') }
    $notes = New-Object System.Collections.Generic.List[string]
    foreach ($cv in $cvs) {
        $n = @()
        if ($cv.Method -ne 'motif') { $n += (T 'mesurée sur le contenu d''une image, avant le motif de test') }
        if ($cv.Drive -and [string]$cv.Drive -ne $script:Restore.Dst) { $n += ((T "mesurée sur le lecteur {0}") -f "$($cv.Drive)") }
        if ($cv.Converged -eq $false) { $n += (T 'non convergée') }
        if ((Get-CurveCalc $cv) -ne $script:CalibCalc) { $n += ((T "calcul de calibration {0}") -f (Get-CurveCalcText $cv)) }
        if (Test-CurveAtMax $cv) { $n += ((T "courbe au plafond de {0} ns de son calcul") -f "$(Get-CurveMaxNs $cv)") }
        $vc = @($cv.Values).Count
        if ($nCyl -gt 0 -and $vc -lt $nCyl - 4) { $n += ((T "courbe de {0} cylindres pour une image de {1}") -f "$vc", "$nCyl") }
        foreach ($x in $n) { if (-not $notes.Contains($x)) { $notes.Add($x) } }
    }
    return @{ Need = $false; Text = $text; Notes = $notes.ToArray() }
}

function Start-RestoreWrite {
    $r = $script:Restore
    $r.Stage = 'write'; $r.Idle = Get-Date
    $script:LastCheck = $null
    $r.InCall = $true
    try {
        # Regles strictes dans l onglet Ecriture (etat d origine remis en fin de restauration)
        Set-WritePreset 'slow' $r.Orig ("restore|" + $r.Orig)
        if ($r.Mode -eq 'sector') { Set-Combo $cmbWFmt $r.Fmt }
        if ($r.Mode -eq 'flux' -and $r.OnOriginal -and $r.Read) {
            # Ecriture sur une disquette identique a l original (« Ecraser quand meme ») : cylindres non reproductibles exclus
            $keep = @(Get-RestoreKeepCyls)
            if ($keep.Count -gt 0) {
                $inc = @(0..([int]$r.Read.MaxCyl) | Where-Object { $keep -notcontains $_ })
                if ($inc.Count -eq 0) {
                    # Garde : jamais d ecriture complete sur l original quand tout est a preserver
                    $r.InCall = $false
                    Fail-Restore 3 (T "aucun cylindre réécrivable sans toucher aux pistes non reproductibles : rien n'a été écrit")
                    return
                }
                if ($inc.Count -gt 0) {
                    $txtWTracks.Text = "c=$(Format-CylList $inc)$($r.Extras)"
                    $r.Preserved = $keep
                    Append-Log ((T "Restauration : écriture sur une disquette identique à l'original : cylindres {0} non réécrits (pistes non reproductibles, protection préservée).") -f "$(Format-CylList $keep)")
                }
            }
        }
        Set-Num $numWRetries $script:RestoreRules.WriteRetries
        Set-Num $numWRepair $script:RestoreRules.RepairPasses
        $chkWNoVerify.Checked = $false; $chkWPostCheck.Checked = $true; $chkWPrecomp.Checked = $true
        # Test rapide choisi dans l onglet Ecriture avant la restauration : niveau mesure sur la destination quand une
        # calibration existe (ou apres une calibration sur disquette sacrifiee) ; une calibration n est jamais refaite
        $lvl = ($r.Saved -and [int]$r.Saved.CalMode -eq 2)
        $cmbWCalMode.SelectedIndex = 1
        Update-PrecompForImage $r.Orig
        $r.SwapBack = $false
        $noCalib = $false
        if ($r.Mode -eq 'sector') {
            $r.HD = [string](Get-HighDensityReason $r.Orig $r.Fmt)
            if (-not $r.HD) {
                if ($r.CalibDone) { $noCalib = $true }          # calibration faite sur une disquette sacrifiee, destination remise
                else {
                    $rc = (Get-CalibCylinders $r.Orig $r.Fmt).NCyl
                    $ci = Get-RestoreCalibInfo (Get-ImageFamily $r.Orig) $(if ($null -eq $rc) { 80 } else { [math]::Max(2, [math]::Min(84, [int]$rc)) })
                    if ($ci.Need) { $r.Calib = $ci.Text; Append-Log ((T "Restauration : calibration par tête en test fin ({0}).") -f "$($ci.Text)") }
                    else {
                        $noCalib = $true; $r.CalibUsed = $ci
                        Append-Log ((T "Restauration : calibration existante utilisée ({0}), le lecteur n'est pas recalibré.") -f "$($ci.Text)")
                        if ($ci.Notes.Count -gt 0) { Append-Log ((T "Remarque sur cette calibration : {0}. Pour la refaire, lancez « Calibrer » dans l'onglet Écriture, « Écriture lente » cochée, avant la restauration.") -f "$($ci.Notes -join ' ; ')") }
                    }
                }
            }
        }
        Append-Log ((T "Restauration : écriture tête par tête, {0} essais par piste, contrôle de toutes les pistes ({1} passes au plus).") -f "$($script:RestoreRules.WriteRetries)", "$($script:RestoreRules.RepairPasses)")
        Start-PresetWrite 'slow' -NoCalib:$noCalib -LevelOnly:($lvl -and $noCalib -and $r.Mode -eq 'sector' -and -not $r.HD)
        if ($r.Mode -eq 'flux' -and $script:Rep -and $r.Read) {
            # Pistes deja critiques ou non reproductibles sur l original : ni reecrites ni comptees au controle
            $ign = @{}
            foreach ($k in @(@($r.Read.CritKeys.Keys) + @($r.Read.WeakKeys.Keys))) { $ign[[string]$k] = $true }
            if ($ign.Count -gt 0) { $script:Rep.Ignore = $ign }
            # Zones instables relues sur la copie : courtes zones ou pistes non mesurables de l original non jugees
            $script:Rep.SrcWeak = $r.Read.WeakKeys
            $nj = @{}; foreach ($k in @(@($r.Read.UnstKeys.Keys) + @($(if ($r.Read.NoMeas) { $r.Read.NoMeas.Keys } else { @() })))) { $nj[[string]$k] = $true }
            $script:Rep.NoJudge = $nj
        }
    } finally { $r.InCall = $false; $r.Idle = Get-Date }
    if (-not $script:Restore) { return }
    if ($script:Cal) { Set-RsStep 4 'run' }
    elseif ($script:GwProc -and -not $script:GwProc.HasExited) {
        if ($r.Mode -ne 'sector') { Set-RsStep 4 'skip' (T 'non applicable à une copie de flux') }
        elseif ($r.HD) { Set-RsStep 4 'skip' ((T "non applicable : {0}") -f "$($r.HD)") }
        elseif ($r.CalibUsed) {
            $d = (T "calibration existante ({0}), pas de recalibration") -f "$($r.CalibUsed.Text)"
            if ($r.CalibUsed.Notes.Count -gt 0) { $d += ' ; ' + ($r.CalibUsed.Notes -join ' ; ') }
            if ($r.LevelNote) { $d += ' ; ' + ((T "niveau non mesuré : {0}") -f "$($r.LevelNote)") }
            Set-RsStep 4 $(if ($r.CalibUsed.Notes.Count -gt 0 -or $r.LevelNote) { 'warn' } else { 'ok' }) $d
        }
        elseif ($r.CalibDone -and $r.LevelNote) {
            $s4 = $r.Steps[4]
            $d = if ($s4 -and $s4.Detail) { $s4.Detail } else { (T "faite sur une disquette sacrifiée ({0})") -f "$($r.Calib)" }
            Set-RsStep 4 'warn' ($d + ' ; ' + ((T "niveau non mesuré : {0}") -f "$($r.LevelNote)"))
        }
        Set-RsStep 5 'run' $(if ($script:WriteWarm) { (T 'préchauffage du lecteur') } else { '' })
    } else {
        Fail-Restore 4 (T 'l''écriture n''a pas démarré (calibration refusée ou annulée ? voir le journal)')
    }
}

function Set-RsCalibDone {
    # Calibration terminee pendant la restauration : convergence des deux courbes par tete, courbe a la borne de son
    # calcul (meme reserve que Get-RestoreCalibInfo a la restauration suivante)
    $r = $script:Restore
    if ($r.Level) { Set-RsStep 4 $r.Level.State $r.Level.Text; return }
    $fam = Get-ImageFamily $r.Orig
    $nc = @(@(0, 1) | Where-Object { $cv = $script:PrecompCurves["${fam}_h$_"]; $cv -and $cv.Converged -eq $false })
    $am = @(@(0, 1) | ForEach-Object { $script:PrecompCurves["${fam}_h$_"] } | Where-Object { Test-CurveAtMax $_ })
    $d = if ($nc.Count -gt 0) { (T 'faite, non convergée sur une tête : voir le journal') }
         elseif ($r.CalSwap) { (T "faite sur une disquette sacrifiée ({0})") -f "$($r.Calib)" }
         elseif ($r.Calib) { (T "faite ({0})") -f "$($r.Calib)" } else { '' }
    if ($am.Count -gt 0) {
        $ct = (T "courbe au plafond de {0} ns de son calcul") -f "$(Get-CurveMaxNs $am[0])"
        $d = if ($d) { "$d ; $ct" } else { $ct }
    }
    Set-RsStep 4 $(if ($nc.Count -gt 0 -or $am.Count -gt 0) { 'warn' } else { 'ok' }) $d
}

function Enter-RestoreSwapBack {
    # Calibration faite sur une disquette sacrifiee : etape terminee, la destination est redemandee puis de nouveau
    # sondee (Resume-Restore -> Start-RestoreProbe) ; l ecriture reprend ensuite sans recalibrer (CalibDone).
    $r = $script:Restore
    $r.CalSwap = $true
    Set-RsCalibDone
    $r.CalibDone = $true; $r.SwapBack = $true
    # Sans reponse, reprise automatique au bout du delai de l avertissement (Update-RestoreProgress) : sonde, puis ecriture
    $r.SwapDeadline = $(if ($script:CalibConfirmSeconds -gt 0) { (Get-Date).AddSeconds($script:CalibConfirmSeconds) } else { $null })
    Set-RsStep 3 'pending'
    Append-Log (T 'Restauration : calibration terminée sur la disquette sacrifiée.')
    Enter-RestoreWait ''
}

function Update-RestoreProgress {
    # Appele par le timer : etape en cours pendant l ecriture deleguee, ligne d avancement, chien de garde
    $r = $script:Restore
    if (-not $r) { return }
    $busy = (($script:GwProc -and -not $script:GwProc.HasExited) -or $script:Chain.Count -gt 0 -or $script:Rep -or $script:Cal -or $script:WriteWarm -or $r.Waiting -or $r.InCall)
    if ($busy) { $r.Idle = Get-Date }
    elseif (((Get-Date) - $r.Idle).TotalSeconds -gt 5) { Stop-Restore (T 'séquence arrêtée sans suite, voir le journal'); return }
    if ($r.Waiting -and $r.SwapDeadline) {
        # Remise de la destination apres une calibration sur disquette sacrifiee : reprise automatique au bout du delai
        $left = [math]::Ceiling(($r.SwapDeadline - (Get-Date)).TotalSeconds)
        if ($left -le 0) {
            $r.SwapDeadline = $null
            Append-Log ((T "Restauration : reprise automatique après {0} s sans réponse.") -f "$($script:CalibConfirmSeconds)")
            Resume-Restore $false $true
            return
        }
        $txt = (T "Sans réponse, reprise automatique dans {0} s.") -f "$left"
        if ($lblRsNow.Text -ne $txt) { $lblRsNow.Text = $txt }
        return
    }
    if ($r.Stage -eq 'write') {
        if ($script:Cal) {
            if ($r.Cur -ne 4) { Set-RsStep 4 'run' }
        } elseif ($script:Rep -and $null -ne $script:Rep.Scope) {
            if ($r.Cur -lt 6) {
                if ($r.Steps.ContainsKey(4) -and $r.Steps[4].State -eq 'run') { Set-RsCalibDone }
                Set-RsStep 5 'ok'; Set-RsStep 6 'run'
            }
        } elseif ($script:GwProc -and $r.Cur -lt 5) {
            if ($r.Steps.ContainsKey(4) -and $r.Steps[4].State -eq 'run') { Set-RsCalibDone }
            Set-RsStep 5 'run' $(if ($script:WriteWarm) { (T 'préchauffage du lecteur') } else { '' })
        }
    }
    $now = if ($script:Cal -or $script:WriteWarm) { $lblWCal.Text } elseif ($script:GwProc) { ($stOp.Text + '   ' + $stTrack.Text).Trim() } else { '' }
    if ($lblRsNow.Text -ne $now) { $lblRsNow.Text = $now }
}

function Start-RestoreCompare {
    # Ecriture et controle termines (accroches) : bilan, puis relecture de la copie sans nouvel essai
    $r = $script:Restore
    $chk = $script:LastCheck
    if ($r.Steps.ContainsKey(4) -and $r.Steps[4].State -eq 'run') { Set-RsCalibDone }
    Set-RsStep 5 'ok'
    if ($chk) { Set-RsStep 6 $(if ($chk.Ok) { 'ok' } else { 'fail' }) $chk.Short }
    else { Set-RsStep 6 'skip' (T 'non applicable à ce format') }
    if ($r.Mode -ne 'sector') { Set-RsStep 7 'skip' (T 'non applicable à une copie de flux'); Finish-Restore; return }
    $r.Stage = 'compare'
    Set-RsStep 7 'run'
    Remove-Item -LiteralPath $r.Back -ErrorAction SilentlyContinue
    $script:RestoreArgs = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @("--format=$($r.Fmt)", "--retries=$($script:RestoreRules.FinalRetries)")
    if ($r.Extras) { $script:RestoreArgs += "--tracks=$($r.Extras.TrimStart(':'))" }
    $script:RestoreArgs += "`"$($r.Back)`""
    $script:GwCapture = New-Object System.Collections.Generic.List[string]
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw $script:RestoreArgs })
    $script:Chain.Enqueue({ Invoke-RestoreNext })
    Invoke-NextChainStep
}

function Complete-RestoreCompare {
    $r = $script:Restore
    $script:GwCapture = $null
    if (-not (Test-Path -LiteralPath $r.Back)) {
        $r.Cmp = @{ Ok = $false; Text = (T 'relecture de la copie impossible') }
        Set-RsStep 7 'fail' $r.Cmp.Text; Finish-Restore; return
    }
    $a = [System.IO.File]::ReadAllBytes($r.Orig); $b = [System.IO.File]::ReadAllBytes($r.Back)
    if ($script:FastCompare) { $diff = @([GwCompare]::DiffSectors($a, $b, 512)) }
    else {
        $set = New-Object System.Collections.Generic.HashSet[int]
        $n = [Math]::Max($a.Length, $b.Length)
        for ($i = 0; $i -lt $n; $i++) { if ($i -ge $a.Length -or $i -ge $b.Length -or $a[$i] -ne $b[$i]) { [void]$set.Add([int][Math]::Floor($i / 512)) } }
        $diff = @($set | Sort-Object)
    }
    $unread = Get-BadSectorBlocks $r.Back
    $total = [int][math]::Ceiling([math]::Max($a.Length, $b.Length) / 512)
    if ($diff.Count -eq 0) {
        $r.Cmp = @{ Ok = $true; Text = ((T "identique, {0} secteurs") -f "$total") }
        Set-RsStep 7 'ok' $r.Cmp.Text
        Append-Log ((T "Restauration : copie IDENTIQUE à l'original, {0} secteurs relus du premier coup.") -f "$total")
    } else {
        $trk = Get-BlockTracks ([int[]]$diff) $r.Fmt
        $r.Cmp = @{ Ok = $false; Text = ((T "{0} secteur(s) différent(s) sur {1}, dont {2} non relu(s) du premier coup ; pistes {3}") -f "$($diff.Count)", "$total", "$($unread.Count)", "$(Format-TrackList $trk)") }
        Set-RsStep 7 'fail' ((T "{0} secteur(s) différent(s)") -f "$($diff.Count)")
        Append-Log ((T "Restauration : copie DIFFÉRENTE de l'original : {0}.") -f "$($r.Cmp.Text)")
    }
    Finish-Restore
}

function Write-RestoreReport([bool]$ok, [string]$verdict) {
    $r = $script:Restore
    $L = New-Object System.Collections.Generic.List[string]
    $L.Add(((T "Greaseweazle Studio v{0} - rapport de restauration") -f "$($script:Version)"))
    $L.Add(((T "Date        : {0}, durée {1} min") -f (Get-Date -Format 'dd/MM/yyyy HH:mm'), "$([math]::Round(((Get-Date) - $r.Start).TotalMinutes, 1))"))
    $L.Add(((T "Disquette   : {0}") -f "$($r.Name)"))
    $L.Add(((T "Mode        : {0}") -f $(if ($r.Mode -eq 'sector') { (T "secteur par secteur, format {0}") -f "$($r.Fmt)" } else { (T 'copie exacte du flux') })))
    $L.Add(((T "Lecteurs    : origine {0}, destination {1}") -f "$($r.Src)", "$($r.Dst)"))
    $L.Add(((T "Original lu : {0}") -f "$($r.Orig)"))
    if ($r.Mode -eq 'sector') { $L.Add(((T "Copie relue : {0}") -f "$($r.Back)")) }
    if ($r.Read -and $r.Read.WeakKeys -and $r.Read.WeakKeys.Count -gt 0) { $L.Add(((T "Instables   : {0} (zone instable d'un tour à l'autre : protection contre la copie probable, non reproductible)") -f "$(Format-TrackList (Sort-TrackKeys @($r.Read.WeakKeys.Keys)))")) }
    if ($r.Level) { $L.Add(((T "Niveau      : {0}") -f "$($r.Level.Report)")) }
    if ($r.Preserved -and @($r.Preserved).Count -gt 0) { $L.Add(((T "Préservés   : cylindres {0}, non réécrits sur la disquette identique à l'original") -f "$(Format-CylList @($r.Preserved))")) }
    $rr = $script:RestoreRules
    $L.Add(((T "Règles      : lecture {0} tours, {1} essais x {2} séries ; écriture tête par tête, calibration existante conservée (calibration par tête en test fin si aucune n'existe), pré-effacement, vérification gw, {3} essais par piste ; contrôle de toutes les pistes, {4} passes de réécriture au plus ; relecture finale sans nouvel essai.") -f "$($rr.ReadRevs)", "$($rr.ReadRetries)", "$($rr.SeekRetries + 1)", "$($rr.WriteRetries)", "$($rr.RepairPasses)"))
    $L.Add('')
    $L.Add((T 'Étapes :'))
    $marks = @{ pending = '[ ]'; run = '[>]'; ok = '[OK]'; fail = '[ECHEC]'; skip = '[-]'; warn = '[!]' }
    for ($i = 0; $i -lt $script:RsStepNames.Count; $i++) {
        $s = if ($r.Steps.ContainsKey($i)) { $r.Steps[$i] } else { @{ State = 'pending'; Detail = '' } }
        $L.Add(("  {0,-7} {1}{2}" -f $marks[$s.State], $script:RsStepNames[$i], $(if ($s.Detail) { ' : ' + $s.Detail } else { '' })))
    }
    if ($script:LastCheck) { $L.Add(''); $L.Add($script:LastCheck.Text) }
    $L.Add('')
    $L.Add(((T "Verdict     : {0}") -f "$verdict"))
    try { [System.IO.File]::WriteAllLines($r.Report, $L, (New-Object System.Text.UTF8Encoding($true))); Append-Log ((T "Rapport     : {0}") -f "$($r.Report)") }
    catch { Append-Log ((T "Rapport non enregistré : {0}") -f "$($_.Exception.Message)") }
}

function Show-RestoreResult([bool]$ok, [string]$text) {
    $lblRsResult.Text = $text
    $lblRsResult.BackColor = if ($ok) { [System.Drawing.Color]::FromArgb(222, 244, 228) } else { [System.Drawing.Color]::FromArgb(252, 226, 224) }
    $lblRsResult.ForeColor = if ($ok) { [System.Drawing.Color]::FromArgb(20, 90, 45) } else { [System.Drawing.Color]::FromArgb(140, 30, 25) }
    $pnlRsWait.Visible = $false; $lblRsNow.Text = ''
    $lblRsResult.Visible = $true; $lblRsResult.BringToFront(); $lblRsRules.Visible = $false
    $tabRs.ScrollControlIntoView($lblRsResult)
}

function Finish-Restore {
    $r = $script:Restore
    if (-not $r) { return }
    $chk = $script:LastCheck
    $reasons = @()
    if ($chk -and -not $chk.Ok) { $reasons += $chk.Short }
    if ($r.Mode -eq 'sector' -and -not ($r.Cmp -and $r.Cmp.Ok)) { $reasons += $(if ($r.Cmp) { $r.Cmp.Text } else { (T 'comparaison non faite') }) }
    $ok = ($reasons.Count -eq 0)
    if ($ok) {
        $verdict = (T 'RESTAURATION RÉUSSIE')
        # Pistes instables reellement reecrites (un tour fige) et pistes instables preservees (cylindres non reecrits)
        $pres = @{}; foreach ($c in @($r.Preserved)) { if ($null -ne $c) { $pres[[int]$c] = $true } }
        $weakAll = if ($r.Read -and $r.Read.WeakKeys) { @($r.Read.WeakKeys.Keys) } else { @() }
        $nWeak = @($weakAll | Where-Object { -not $pres.ContainsKey([int](([string]$_ -split '\.')[0])) }).Count
        $nKept = $weakAll.Count - $nWeak
        $nPres = $pres.Count
        if ($nWeak -gt 0 -or $nPres -gt 0) { $verdict += (T ' (avec réserve : protection non reproductible)') }
        $detail = if ($r.Mode -eq 'sector' -and -not $chk) { (T 'La copie a été écrite tête par tête et elle est identique à l''original, secteur par secteur. Le contrôle des pistes ne s''applique pas à ce format (haute densité).') }
                  elseif ($r.Mode -eq 'sector') { (T 'La copie a été écrite tête par tête, toutes ses pistes sont saines et elle est identique à l''original, secteur par secteur.') }
                  else { (T 'Le flux a été recopié et toutes les pistes de la copie sont saines. Sans format, la copie n''est pas comparée secteur par secteur : essayez-la sur la machine d''origine.') }
        if ($nWeak -gt 0) { $detail += ((T " Attention : {0} piste(s) de l'original non reproductible(s) (zone instable, protection contre la copie probable) : la copie n'en a reçu qu'un tour figé et risque de ne pas fonctionner.") -f "$nWeak") }
        if ($nKept -gt 0) { $detail += ((T " {0} piste(s) non reproductible(s) de l'original préservée(s), non réécrite(s) : protection d'origine intacte.") -f "$nKept") }
        if ($nPres -gt 0) { $detail += ((T " Cylindres {0} ni réécrits ni contrôlés (disquette reconnue comme l'original) : s'il s'agissait d'une copie, elle est incomplète ; effacez-la puis relancez la restauration.") -f "$(Format-CylList @($pres.Keys | Sort-Object))") }
    } else {
        $verdict = (T 'RESTAURATION ÉCHOUÉE') + ' : ' + ($reasons -join ' ; ')
        $detail = (T 'Essayez une autre disquette de destination ; si le problème persiste, nettoyez les têtes du lecteur. Le détail est dans le rapport.')
    }
    Append-Log $verdict
    Write-RestoreReport $ok $verdict
    Show-RestoreResult $ok ($verdict + "`n`n" + $detail)
    Close-Restore
}

function Fail-Restore([int]$step, [string]$why) {
    $r = $script:Restore
    if (-not $r) { return }
    $r.Stage = 'failed'
    $script:Chain.Clear(); $script:WriteQueue.Clear(); $script:GwCapture = $null; $script:AfterCalib = ''
    Stop-WriteWarmup
    if ($step -ge 0) { Set-RsStep $step 'fail' $why }
    $verdict = (T 'RESTAURATION ÉCHOUÉE') + ' : ' + $why
    Append-Log $verdict
    Write-RestoreReport $false $verdict
    $note = if ($step -le 1) { (T 'Rien n''a été écrit : la disquette de destination n''a pas été touchée.') } else { (T 'Le détail est dans le journal et dans le rapport.') }
    Show-RestoreResult $false ($verdict + "`n`n" + $note)
    Close-Restore
}

function Stop-Restore([string]$why) {
    # Abandon (bouton Arreter ou Annuler, erreur gw, operation incomplete, sequence bloquee) ; sans effet hors restauration
    $r = $script:Restore
    if (-not $r) { return }
    Fail-Restore ([int]$r.Cur) $why
}

function Close-Restore {
    $r = $script:Restore
    $script:Restore = $null
    if ($r) { Restore-WriteTabState $r.Saved; [void](Save-Config) }      # reglages de l onglet Ecriture retablis, puis enregistres
    Set-RsLock $false
    $pnlRsWait.Visible = $false
}

# --- Configuration -------------------------------------------------------------
function Set-Defaults {
    $script:CalHardNs = $script:CalHardNsDefault
    $script:CalWarmupMinutes = [double]$script:CalWarmupDefault
    $script:HomeCalFmt = 'amiga.amigados'
    $cmbDrive.SelectedIndex = 0
    $txtDev.Text = ''
    $chkTime.Checked = $false

    $txtLibRoot.Text = ''
    $txtLibFilter.Text = ''
    $chkLibImgOnly.Checked = $false

    $txtWFile.Text = ''
    $cmbWFmt.SelectedIndex = 0
    $chkWPreErase.Checked = $true
    $chkWEraseEmpty.Checked = $true
    $chkWNoVerify.Checked = $false
    $chkWReverse.Checked = $false
    $chkWHard.Checked = $false
    $chkWTG43.Checked = $false
    $numWRetries.Value = 10
    $chkWPrecomp.Checked = $true
    $txtWPrecomp.Text = $script:PrecompStd
    $txtWPrecomp1.Text = $script:PrecompStd
    $chkWSlow.Checked = $false
    $chkWWarm.Checked = $true
    Update-SlowUi
    $chkWPostCheck.Checked = $true
    $numWRepair.Value = 3
    $cmbWProfile.SelectedIndex = 0
    $cmbWCalMode.SelectedIndex = 0
    $lblWProfileInfo.Text = ''
    $txtWTracks.Text = ''
    $cmbWDensel.SelectedIndex = 0
    $txtWFakeIdx.Text = ''
    $txtWDiskdefs.Text = ''

    $txtRFile.Text = ''
    $cmbRFmt.SelectedIndex = 0
    $numRevs.Value = 5
    $numRRetries.Value = 10
    $txtRTracks.Text = ''
    $chkRRaw.Checked = $false
    $chkRRev.Checked = $false
    $cmbRDensel.SelectedIndex = 0
    $txtRDiskdefs.Text = ''

    $txtCvIn.Text = ''
    $txtCvOut.Text = ''
    $cmbCvFmt.SelectedIndex = 0
    $txtCvTracks.Text = ''

    $cmbAlPreset.SelectedIndex = 1
    $cmbAlHead.SelectedIndex = 2
    $txtAlCyls.Text = '0,10,20,30,40,50,60,70'
    $numAlRevs.Value = 3
    $chkAlLoop.Checked = $false
    $numAlPause.Value = 2
    $chkAlGuide.Checked = $false

    $txtCmpRef.Text = ''
    Set-Combo $cmbCmpFmt 'amiga.amigados'
    $numCmpRetries.Value = 10
    $txtCmpResult.Text = (T "Compare le contenu physique d'une disquette à une image de référence (IPF, ADF, SCP, HFE...).`r`n`r`n") +
                         (T "Principe : la référence est convertie par gw dans le format de décodage choisi, la disquette est`r`n") +
                         (T "lue dans ce même format, puis les deux fichiers sont comparés octet par octet, secteur par secteur.`r`n`r`n") +
                         (T "Limite : seules les pistes décodables dans ce format sont comparées. Les pistes de protection`r`n") +
                         (T "(non-AmigaDOS) d'un IPF n'apparaissent pas dans la comparaison. Le flux brut (SCP) n'est jamais`r`n") +
                         (T "identique d'une lecture à l'autre : il n'existe pas de comparaison bit à bit au niveau flux.")

    $numSeek.Value = 0
    $txtEraseTracks.Text = ''
    $numPasses.Value = 3
    $numLinger.Value = 100
    $script:CleanPrefs = @{ Wet = $true; Cyls = 80; Preset = 0 }      # fenetre de nettoyage : humide, 80 pistes, Standard
    $numPin.Value = 2
    $cmbPinLvl.SelectedIndex = 0

    foreach ($k in $script:DelayCtrls.Keys) {
        $c = $script:DelayCtrls[$k]
        $c.Chk.Checked = $false
        $c.Num.Value = $c.Def
    }

    $cmbRsSrc.SelectedItem = 'A'; $cmbRsDst.SelectedItem = 'A'; $cmbRsFmt.SelectedIndex = 1; $txtRsDir.Text = ''; $txtRsName.Text = ''
    Update-RsRules; Reset-RsSteps
    $cmbHelpAct.SelectedItem = 'write'
    $txtC.Text = 'write --pre-erase --erase-empty --retries=10 --precomp 40=140 "jeu.ipf"'
    Set-JitterThresholds 120 250
    Update-CurveButton $txtWFile.Text
}

function Save-Config {
    $delays = @{}
    foreach ($k in $script:DelayCtrls.Keys) {
        $c = $script:DelayCtrls[$k]
        $delays[$k] = @{ on = [bool]$c.Chk.Checked; val = [int]$c.Num.Value }
    }
    $curvesCfg = [ordered]@{}
    $oc = $script:OldCalib          # calibrations d un autre calcul en attente du choix : gardees telles quelles
    foreach ($k in $script:CurveKeys) {
        $cv = $script:PrecompCurves[$k]
        if (-not $cv -and $oc -and $oc.Curves.Contains($k)) { $cv = $oc.Curves[$k] }
        $curvesCfg[$k] = ConvertTo-CurveConfig $cv
    }
    $lvCfg = @(@($script:LevelShifts.Values) | Where-Object { $_ } | ForEach-Object { ConvertTo-LevelConfig $_ })
    if ($oc) { $lvCfg += @(@($oc.Levels.Values) | Where-Object { $_ -and -not $script:PrecompCurves[$_.RefKey] } | ForEach-Object { ConvertTo-LevelConfig $_ }) }
    $cfg = [ordered]@{
        _comment = (T 'Configuration GreaseweazleGUI - régénérée automatiquement. Supprimable sans risque.')
        _saved   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        window   = @{
            width  = $(if ($form.WindowState -eq 'Normal') { $form.Width }  else { $form.RestoreBounds.Width })
            height = $(if ($form.WindowState -eq 'Normal') { $form.Height } else { $form.RestoreBounds.Height })
            split = $split.SplitterDistance; maximized = ($form.WindowState -eq 'Maximized')
            logVisible = -not $split.Panel2Collapsed
        }
        global   = @{ drive = $cmbDrive.Text; device = $txtDev.Text; time = [bool]$chkTime.Checked; detectNone = [bool]$script:DetectNone }
        library  = @{ root = $txtLibRoot.Text; imagesOnly = [bool]$chkLibImgOnly.Checked }
        write    = @{
            file = $txtWFile.Text; format = $cmbWFmt.Text
            preErase = [bool]$chkWPreErase.Checked; eraseEmpty = [bool]$chkWEraseEmpty.Checked
            noVerify = [bool]$chkWNoVerify.Checked; reverse = [bool]$chkWReverse.Checked
            hardSectors = [bool]$chkWHard.Checked; genTg43 = [bool]$chkWTG43.Checked
            retries = [int]$numWRetries.Value
            precompOn = [bool]$chkWPrecomp.Checked; precomp = $txtWPrecomp.Text; precomp1 = $txtWPrecomp1.Text; slowWrite = [bool]$chkWSlow.Checked
            precompProfile = $cmbWProfile.Text; postCheck = [bool]$chkWPostCheck.Checked; repairMax = [int]$numWRepair.Value; calMode = [int]$cmbWCalMode.SelectedIndex
            precompStd = $(if ($oc -and $oc.Std -and -not $script:PrecompCurves['std']) { $oc.Std } else { $script:PrecompStd })
            precompLong = $(if ($oc -and $oc.Long -and -not $script:PrecompCurves['long']) { $oc.Long } else { $script:PrecompLong })
            precompThresholdNs = [int]$script:PrecompThresholdNs
            precompMaxNs = [int]$script:CalHardNs   # borne des valeurs calibrees (300 a 470 ns, 400 par defaut)
            calWarmupMinutes = [double]$script:CalWarmupMinutes   # prechauffage du lecteur avant une calibration complete ou une ecriture lente (0 a 30 min, 5 par defaut, 0 : aucun)
            slowWarmup = [bool]$chkWWarm.Checked                  # case « Prechauffer le lecteur avant l ecriture lente »
            calibVersion = $script:Version     # version de l application qui a enregistre (information)
            calibCalc = $script:CalibCalc      # calcul de calibration courant ; chaque courbe porte le sien (calc)
            calibAlgo = $script:CalibAlgo
            precompCurves = $curvesCfg
            levelAlgo = $script:LevelAlgo; levelShifts = $lvCfg
            tracks = $txtWTracks.Text; densel = $cmbWDensel.Text
            fakeIndex = $txtWFakeIdx.Text; diskdefs = $txtWDiskdefs.Text
        }
        read     = @{
            file = $txtRFile.Text; format = $cmbRFmt.Text
            revs = [int]$numRevs.Value; retries = [int]$numRRetries.Value
            tracks = $txtRTracks.Text; raw = [bool]$chkRRaw.Checked; reverse = [bool]$chkRRev.Checked
            densel = $cmbRDensel.Text; diskdefs = $txtRDiskdefs.Text
        }
        convert  = @{ input = $txtCvIn.Text; output = $txtCvOut.Text; format = $cmbCvFmt.Text; tracks = $txtCvTracks.Text }
        compare  = @{ reference = $txtCmpRef.Text; format = $cmbCmpFmt.Text; retries = [int]$numCmpRetries.Value }
        align    = @{ head = $cmbAlHead.Text; cyls = $txtAlCyls.Text; revs = [int]$numAlRevs.Value; loop = [bool]$chkAlLoop.Checked; pause = [int]$numAlPause.Value
                      preset = $cmbAlPreset.Text; guide = [bool]$chkAlGuide.Checked
                      reference = $(if ($script:AlignRef) { $r = @{}; foreach ($k in $script:AlignRef.Keys) { $r[$k] = [double]$script:AlignRef[$k].Score }; $r } else { $null })
                      referenceLabel = $script:AlignRefLabel }
        tools    = @{
            seek = [int]$numSeek.Value; eraseTracks = $txtEraseTracks.Text
            passes = [int]$numPasses.Value; linger = [int]$numLinger.Value
            cleanWet = [bool]$script:CleanPrefs.Wet; cleanCyls = [int]$script:CleanPrefs.Cyls; cleanPreset = [int]$script:CleanPrefs.Preset
            pin = [int]$numPin.Value; pinLevel = $cmbPinLvl.Text
        }
        delays   = $delays
        free     = @{ command = $txtC.Text; helpAction = $cmbHelpAct.Text }
        ui       = @{ expert = [bool]$chkExpert.Checked; homeCalFormat = [string]$script:HomeCalFmt }   # type de la carte Calibration
        quality  = @{ jitterOk = [int]$script:JitterOk; jitterWatch = [int]$script:JitterWatch }
        restore  = @{ source = $cmbRsSrc.Text; target = $cmbRsDst.Text; folder = $txtRsDir.Text
                      format = $(if ($cmbRsFmt.SelectedIndex -le 0) { 'flux' } else { $cmbRsFmt.Text }) }
    }
    try {
        $cfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:ConfigFile -Encoding UTF8
        return $true
    } catch {
        Append-Log ((T "ERREUR sauvegarde configuration : {0}") -f "$($_.Exception.Message)")
        return $false
    }
}

function Get-Cfg($obj, [string]$name, $default) {
    if ($null -ne $obj -and ($obj.PSObject.Properties.Name -contains $name) -and $null -ne $obj.$name) { return $obj.$name }
    return $default
}

function Set-Num($ctrl, $value) {
    try {
        $v = [decimal]$value
        if ($v -lt $ctrl.Minimum) { $v = $ctrl.Minimum }
        if ($v -gt $ctrl.Maximum) { $v = $ctrl.Maximum }
        $ctrl.Value = $v
    } catch { }
}

function Set-Combo($ctrl, $value) {
    if ([string]::IsNullOrEmpty($value)) { return }
    if ($ctrl.Items.Contains($value)) { $ctrl.SelectedItem = $value }
    elseif ($ctrl.DropDownStyle -ne 'DropDownList') { $ctrl.Text = $value }
}

function Load-Config {
    if (-not (Test-Path -LiteralPath $script:ConfigFile)) { return $false }
    try {
        $cfg = Get-Content -LiteralPath $script:ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Append-Log ((T "Configuration illisible, valeurs par défaut conservées : {0}") -f "$($_.Exception.Message)")
        return $false
    }

    $win = Get-Cfg $cfg 'window' $null
    if ($win) {
        $w = [int](Get-Cfg $win 'width' $form.Width); $h = [int](Get-Cfg $win 'height' $form.Height)
        # Largeur enregistree avec le minimum de 800 px des versions anterieures a la 12.6 : portee au minimum actuel, la
        # hauteur enregistree est conservee
        if ($w -ge 800 -and $w -lt $form.MinimumSize.Width) { $w = $form.MinimumSize.Width }
        if ($w -ge $form.MinimumSize.Width -and $h -ge $form.MinimumSize.Height) { $form.Size = New-Object System.Drawing.Size($w, $h) }
        $script:PendingSplit = [int](Get-Cfg $win 'split' 0)
        if ([bool](Get-Cfg $win 'maximized' $false)) { $form.WindowState = 'Maximized' }
        $script:PendingLogVisible = [bool](Get-Cfg $win 'logVisible' $true)
    }

    $g = Get-Cfg $cfg 'global' $null
    Set-Combo $cmbDrive (Get-Cfg $g 'drive' 'A')
    $txtDev.Text = [string](Get-Cfg $g 'device' '')
    $chkTime.Checked = [bool](Get-Cfg $g 'time' $false)
    $script:DetectNone = [bool](Get-Cfg $g 'detectNone' $false)

    $l = Get-Cfg $cfg 'library' $null
    $txtLibRoot.Text = [string](Get-Cfg $l 'root' '')
    $chkLibImgOnly.Checked = [bool](Get-Cfg $l 'imagesOnly' $false)

    $w = Get-Cfg $cfg 'write' $null
    $txtWFile.Text = [string](Get-Cfg $w 'file' '')
    Set-Combo $cmbWFmt (Get-Cfg $w 'format' '(auto)')
    $chkWPreErase.Checked   = [bool](Get-Cfg $w 'preErase' $true)
    $chkWEraseEmpty.Checked = [bool](Get-Cfg $w 'eraseEmpty' $true)
    $chkWNoVerify.Checked   = [bool](Get-Cfg $w 'noVerify' $false)
    $chkWReverse.Checked    = [bool](Get-Cfg $w 'reverse' $false)
    $chkWHard.Checked       = [bool](Get-Cfg $w 'hardSectors' $false)
    $chkWTG43.Checked       = [bool](Get-Cfg $w 'genTg43' $false)
    Set-Num $numWRetries (Get-Cfg $w 'retries' 10)
    $chkWPrecomp.Checked    = [bool](Get-Cfg $w 'precompOn' $true)
    # Calibrations : courbe reprise si elle a ete faite avec le calcul de calibration actuel ($script:CalibCalc), quelle que
    # soit la version de l application qui l a faite, ou si l utilisateur l a conservee pour ce calcul (KeptFor). Courbe
    # d un autre calcul : mise de cote ($script:OldCalib) avec son profil de famille et ses niveaux ; au demarrage,
    # l utilisateur choisit de la conserver ou de recalibrer (Resolve-OldCalibrations) ; d ici la, elle n est pas utilisee.
    $calVer = [string](Get-Cfg $w 'calibVersion' '')
    $pcv = Get-Cfg $w 'precompCurves' $null
    $cfgStd = [string](Get-Cfg $w 'precompStd' $script:PrecompStdDefault)
    $cfgLong = [string](Get-Cfg $w 'precompLong' $script:PrecompLongDefault)
    # Premiere 12.3 publiee : elle a abandonne les courbes 12.2 et reecrit la configuration sans elles (sans calibCalc),
    # apres en avoir fait la copie .calib-v12.2.bak : ces courbes y sont relues pour etre proposees au choix
    $fromBak = $null
    $hasCurve = ($pcv -and @($script:CurveKeys | Where-Object { Get-Cfg $pcv $_ $null }).Count -gt 0)
    $bak122 = $script:ConfigFile + '.calib-v12.2.bak'
    if (-not $hasCurve -and $calVer -eq '12.3' -and $null -eq (Get-Cfg $w 'calibCalc' $null) -and (Test-Path -LiteralPath $bak122)) {
        try {
            $bw = Get-Cfg (Get-Content -LiteralPath $bak122 -Raw -Encoding UTF8 | ConvertFrom-Json) 'write' $null
            $bpcv = Get-Cfg $bw 'precompCurves' $null
            if ($bpcv -and @($script:CurveKeys | Where-Object { Get-Cfg $bpcv $_ $null }).Count -gt 0) {
                $pcv = $bpcv; $fromBak = $bak122
                $cfgStd = [string](Get-Cfg $bw 'precompStd' $script:PrecompStdDefault); $cfgLong = [string](Get-Cfg $bw 'precompLong' $script:PrecompLongDefault)
            }
        } catch { }
    }
    $old = [ordered]@{}
    foreach ($fam in $script:CurveKeys) {
        $cv = if ($pcv) { ConvertFrom-CurveConfig (Get-Cfg $pcv $fam $null) } else { $null }
        if ($cv -and -not (Test-CurveCalcOk $cv)) { $old[$fam] = $cv; $cv = $null }
        $script:PrecompCurves[$fam] = $cv
    }
    # Profil de famille : celui de la configuration s il accompagne une courbe reprise ; mis de cote avec sa courbe ;
    # profil calibre sans courbe (anterieur a 12.1) : abandonne
    $oldStd = $null; $oldLong = $null; $lostProf = $false
    if ($script:PrecompCurves['std']) { $script:PrecompStd = $cfgStd }
    else { $script:PrecompStd = $script:PrecompStdDefault; if ($old.Contains('std')) { $oldStd = $cfgStd } elseif ($cfgStd -ne $script:PrecompStdDefault) { $lostProf = $true } }
    if ($script:PrecompCurves['long']) { $script:PrecompLong = $cfgLong }
    else { $script:PrecompLong = $script:PrecompLongDefault; if ($old.Contains('long')) { $oldLong = $cfgLong } elseif ($cfgLong -ne $script:PrecompLongDefault) { $lostProf = $true } }
    # Niveaux de la calibration rapide : gardes avec leur reference (meme courbe, meme lecteur, meme algorithme de niveau) ;
    # ceux d une reference mise de cote le sont avec elle
    $script:LevelShifts = @{}; $oldLv = @{}
    if ([string](Get-Cfg $w 'levelAlgo' '') -eq $script:LevelAlgo) {
        foreach ($o in @(Get-Cfg $w 'levelShifts' @())) {
            $lr = ConvertFrom-LevelConfig $o
            if (-not $lr -or $lr.LevelAlgo -ne $script:LevelAlgo) { continue }
            $rc = $script:PrecompCurves[$lr.RefKey]; $tgt = $script:LevelShifts
            if (-not $rc -and $old.Contains($lr.RefKey)) { $rc = $old[$lr.RefKey]; $tgt = $oldLv }
            if (-not $rc -or [string]$rc.Date -ne [string]$lr.RefDate -or [string]$rc.Drive -ne [string]$lr.Drive) { continue }
            $tgt["$($lr.RefKey)|$($lr.Tag)"] = $lr
        }
    }
    $script:OldCalib = $null
    $calPurged = $lostProf
    if ($old.Count -gt 0) {
        $calPurged = $true
        $tags = @(@($old.Values) | ForEach-Object { Get-CurveCalc $_ } | Sort-Object -Unique)
        $tag = if ($tags.Count -eq 1 -and $tags[0]) { "v$($tags[0])" } elseif ($calVer) { "v$calVer" } else { 'ancienne' }
        # Copie de la configuration avant tout enregistrement, quel que soit le choix : une fois par passage d un calcul au
        # calcul actuel ; courbes relues dans la copie de la 12.3 publiee : cette copie
        if ($fromBak) { $bak = $fromBak; Append-Log ((T "Courbes de la version 12.2 relues dans la copie faite par la première version 12.3 : {0}") -f "$fromBak") }
        else {
            $bak = $script:ConfigFile + '.calib-' + $tag + '-avant-v' + $script:CalibCalc + '.bak'
            if (-not (Test-Path -LiteralPath $bak)) { try { Copy-Item -LiteralPath $script:ConfigFile -Destination $bak -ErrorAction Stop; Append-Log ((T "Configuration sauvegardée avant le choix sur les anciennes calibrations : {0}") -f "$bak") } catch { $bak = $null } }
        }
        $script:OldCalib = @{ Curves = $old; Std = $oldStd; Long = $oldLong; Levels = $oldLv; Bak = $bak; P0 = $null; P1 = $null }
        Append-Log ((T "Calibrations faites avec un autre calcul de calibration que le calcul actuel (v{0}) : {1}. Elles sont mises de côté jusqu'à votre choix.") -f "$($script:CalibCalc)", ((@($old.Keys | ForEach-Object { (T "{0}, calcul {1}") -f (Get-CurveKeyLabel $_), (Get-CurveCalcText $old[$_] -Plain) })) -join ' ; '))
    }
    if ($lostProf) { Append-Log (T 'Profil de famille calibré sans courbe (version antérieure à 12.1) : profil d''origine rétabli.') }
    $script:PrecompThresholdNs = [int](Get-Cfg $w 'precompThresholdNs' $script:PrecompThresholdNs)
    # Borne des valeurs calibrees : reglage de la configuration, ramene a 300..470 ns ; valeur illisible : defaut, signale
    $hraw = Get-Cfg $w 'precompMaxNs' $null
    $hn = $script:CalHardNsDefault; $hd = 0.0
    if ($null -ne $hraw) {
        if ($hraw -isnot [bool] -and $hraw -isnot [array] -and [double]::TryParse(([string]$hraw).Trim(), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$hd) -and -not [double]::IsNaN($hd) -and -not [double]::IsInfinity($hd)) {
            $hn = [int][math]::Round([math]::Max(-1e9, [math]::Min(1e9, $hd)))
        } else { Append-Log ((T "Borne de précompensation (precompMaxNs) illisible ({0}) : {1} ns par défaut.") -f "$hraw", "$($script:CalHardNsDefault)") }
    }
    $script:CalHardNs = [int][math]::Max($script:CalHardMinNs, [math]::Min($script:CalHardMaxNs, $hn))
    if ($script:CalHardNs -ne $hn) { Append-Log ((T "Borne de précompensation (precompMaxNs) de {0} ns ramenée à {1} ns : elle va de {2} à {3} ns. Au-delà de 470 ns, la précompensation déplacerait une transition d'un quart de cellule en long track (1,89 µs).") -f "$hraw", "$($script:CalHardNs)", "$($script:CalHardMinNs)", "$($script:CalHardMaxNs)") }
    elseif ($script:CalHardNs -ne $script:CalHardNsDefault) { Append-Log ((T "Borne de précompensation réglée dans la configuration (precompMaxNs) : {0} ns, au lieu de {1} ns par défaut.") -f "$($script:CalHardNs)", "$($script:CalHardNsDefault)") }
    # Prechauffage du lecteur avant une calibration complete (minutes, decimales admises) : ramene a 0..30 min ; valeur
    # illisible : defaut, signale
    $wraw = Get-Cfg $w 'calWarmupMinutes' $null
    $wm = [double]$script:CalWarmupDefault; $wd = 0.0
    if ($null -ne $wraw) {
        if ($wraw -isnot [bool] -and $wraw -isnot [array] -and [double]::TryParse(([string]$wraw).Trim(), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$wd) -and -not [double]::IsNaN($wd) -and -not [double]::IsInfinity($wd)) {
            $wm = $wd
        } else { Append-Log ((T "Préchauffage du lecteur (calWarmupMinutes) illisible ({0}) : {1} min par défaut.") -f "$wraw", "$($script:CalWarmupDefault)") }
    }
    $script:CalWarmupMinutes = [math]::Max(0.0, [math]::Min([double]$script:CalWarmupMaxMin, $wm))
    if ($script:CalWarmupMinutes -ne $wm) { Append-Log ((T "Préchauffage du lecteur (calWarmupMinutes) de {0} min ramené à {1} min : il va de 0 à {2} min.") -f "$wraw", "$($script:CalWarmupMinutes)", "$($script:CalWarmupMaxMin)") }
    Set-Combo $cmbWProfile (Get-Cfg $w 'precompProfile' (T 'Auto (selon image)'))
    $chkWPostCheck.Checked = [bool](Get-Cfg $w 'postCheck' $true)
    $rm = [int](Get-Cfg $w 'repairMax' 3); $numWRepair.Value = [math]::Max(0, [math]::Min(10, $rm))
    $numWRepair.Enabled = $chkWPostCheck.Checked; $lblWRepair.Enabled = $chkWPostCheck.Checked
    $cm = [int](Get-Cfg $w 'calMode' 0); if ($cm -ge 0 -and $cm -lt $cmbWCalMode.Items.Count) { $cmbWCalMode.SelectedIndex = $cm }
    $txtWPrecomp.Text  = [string](Get-Cfg $w 'precomp' $script:PrecompStd)
    $txtWPrecomp1.Text = [string](Get-Cfg $w 'precomp1' $txtWPrecomp.Text)
    if ($script:OldCalib) { $script:OldCalib.P0 = $txtWPrecomp.Text; $script:OldCalib.P1 = $txtWPrecomp1.Text }   # retablis si conservees
    # Champs --precomp remplis par une ancienne calibration : profil d origine (sauf profil manuel, choisi par l utilisateur)
    if ($calPurged -and $cmbWProfile.Text -ne (T 'Manuel')) { $txtWPrecomp.Text = $script:PrecompStd; $txtWPrecomp1.Text = $script:PrecompStd }
    $chkWSlow.Checked  = [bool](Get-Cfg $w 'slowWrite' $false)
    $chkWWarm.Checked  = [bool](Get-Cfg $w 'slowWarmup' $true)
    Update-SlowUi
    $txtWTracks.Text   = [string](Get-Cfg $w 'tracks' '')
    Set-Combo $cmbWDensel (Get-Cfg $w 'densel' '(non)')
    $txtWFakeIdx.Text  = [string](Get-Cfg $w 'fakeIndex' '')
    $txtWDiskdefs.Text = [string](Get-Cfg $w 'diskdefs' '')

    $r = Get-Cfg $cfg 'read' $null
    $txtRFile.Text = [string](Get-Cfg $r 'file' '')
    Set-Combo $cmbRFmt (Get-Cfg $r 'format' '(auto)')
    Set-Num $numRevs     (Get-Cfg $r 'revs' 5)
    Set-Num $numRRetries (Get-Cfg $r 'retries' 10)
    $txtRTracks.Text = [string](Get-Cfg $r 'tracks' '')
    $chkRRaw.Checked = [bool](Get-Cfg $r 'raw' $false)
    $chkRRev.Checked = [bool](Get-Cfg $r 'reverse' $false)
    Set-Combo $cmbRDensel (Get-Cfg $r 'densel' '(non)')
    $txtRDiskdefs.Text = [string](Get-Cfg $r 'diskdefs' '')

    $c = Get-Cfg $cfg 'convert' $null
    $txtCvIn.Text  = [string](Get-Cfg $c 'input' '')
    $txtCvOut.Text = [string](Get-Cfg $c 'output' '')
    Set-Combo $cmbCvFmt (Get-Cfg $c 'format' '(auto)')
    $txtCvTracks.Text = [string](Get-Cfg $c 'tracks' '')

    $al = Get-Cfg $cfg 'align' $null
    $ref = Get-Cfg $al 'reference' $null
    if ($ref) {
        $script:AlignRef = @{}
        foreach ($prop in $ref.PSObject.Properties) { $script:AlignRef[[string]$prop.Name] = @{ Score = [double]$prop.Value } }
        $script:AlignRefLabel = [string](Get-Cfg $al 'referenceLabel' '')
        $lblAlRef.Text = ((T "Référence : {0} ({1} piste(s))") -f "$($script:AlignRefLabel)", "$($script:AlignRef.Count)")
    }
    Set-Combo $cmbAlPreset (Get-Cfg $al 'preset' (T 'Standard (0-70 pas 10)'))
    Set-Combo $cmbAlHead (Get-Cfg $al 'head' '0+1')
    $txtAlCyls.Text = [string](Get-Cfg $al 'cyls' '0,10,20,30,40,50,60,70')
    $chkAlGuide.Checked = [bool](Get-Cfg $al 'guide' $false)
    Set-Num $numAlRevs (Get-Cfg $al 'revs' 3)
    $chkAlLoop.Checked = [bool](Get-Cfg $al 'loop' $false)
    Set-Num $numAlPause (Get-Cfg $al 'pause' 2)

    $cm = Get-Cfg $cfg 'compare' $null
    $txtCmpRef.Text = [string](Get-Cfg $cm 'reference' '')
    Set-Combo $cmbCmpFmt (Get-Cfg $cm 'format' 'amiga.amigados')
    Set-Num $numCmpRetries (Get-Cfg $cm 'retries' 10)

    $t = Get-Cfg $cfg 'tools' $null
    Set-Num $numSeek   (Get-Cfg $t 'seek' 0)
    $txtEraseTracks.Text = [string](Get-Cfg $t 'eraseTracks' '')
    Set-Num $numPasses (Get-Cfg $t 'passes' 3)
    Set-Num $numLinger (Get-Cfg $t 'linger' 100)
    # Fenetre de nettoyage : humide sauf false explicite, 40 pistes ou 80, prereglage de duree 0..2
    $cc = 0; [void][int]::TryParse([string](Get-Cfg $t 'cleanCyls' 80), [ref]$cc)
    $cp = 0; [void][int]::TryParse([string](Get-Cfg $t 'cleanPreset' 0), [ref]$cp)
    $script:CleanPrefs = @{ Wet = ([string](Get-Cfg $t 'cleanWet' $true) -ne 'False'); Cyls = $(if ($cc -eq 40) { 40 } else { 80 }); Preset = [math]::Max(0, [math]::Min(2, $cp)) }
    Set-Num $numPin    (Get-Cfg $t 'pin' 2)
    Set-Combo $cmbPinLvl (Get-Cfg $t 'pinLevel' 'H')

    $dl = Get-Cfg $cfg 'delays' $null
    foreach ($k in $script:DelayCtrls.Keys) {
        $ctl = $script:DelayCtrls[$k]
        $e = Get-Cfg $dl $k $null
        if ($null -ne $e) {
            Set-Num $ctl.Num (Get-Cfg $e 'val' $ctl.Def)
            $ctl.Chk.Checked = [bool](Get-Cfg $e 'on' $false)
        }
    }

    $f = Get-Cfg $cfg 'free' $null
    $txtC.Text = [string](Get-Cfg $f 'command' $txtC.Text)
    Set-Combo $cmbHelpAct (Get-Cfg $f 'helpAction' 'write')

    # Configuration d une version precedente (sans section ui) : tous les onglets, comme avant
    $ui = Get-Cfg $cfg 'ui' $null
    $chkExpert.Checked = [bool](Get-Cfg $ui 'expert' ($null -eq $ui))
    # Type de disquette de la carte Calibration de l Accueil : nom de la table (format gw 1.23 ou type d image app.*)
    $hcf = [string](Get-Cfg $ui 'homeCalFormat' '')
    if ($hcf -and ($script:HomeCalApp -contains $hcf -or $script:GwFormats.Contains($hcf))) { $script:HomeCalFmt = $hcf }
    $rs = Get-Cfg $cfg 'restore' $null
    Set-Combo $cmbRsSrc ([string](Get-Cfg $rs 'source' 'A')); Set-Combo $cmbRsDst ([string](Get-Cfg $rs 'target' 'A'))
    $rf = [string](Get-Cfg $rs 'format' 'amiga.amigados')
    if ($rf -eq 'flux') { $cmbRsFmt.SelectedIndex = 0 } else { Set-Combo $cmbRsFmt $rf }
    $txtRsDir.Text = [string](Get-Cfg $rs 'folder' '')
    $q = Get-Cfg $cfg 'quality' $null
    Set-JitterThresholds ([int](Get-Cfg $q 'jitterOk' 120)) ([int](Get-Cfg $q 'jitterWatch' 250))

    return $true
}

# --- Coeur ---------------------------------------------------------------------
function Get-CommonArgs {
    $a = @("--drive=$($cmbDrive.Text)")
    if ($txtDev.Text.Trim()) { $a += "--device=$($txtDev.Text.Trim())" }
    return $a
}

function Set-Busy([bool]$busy) {
    $tabs.Enabled = -not $busy
    $btnStop.Enabled = $busy
    $btnCfgSave.Enabled = -not $busy -and -not $script:Restore
    $btnCfgReset.Enabled = -not $busy -and -not $script:Restore
}

function Get-LogColor([string]$line) {
    if ($line -match '^>>>') { return $script:LogColors.cmd }
    # Lignes de synthese du controle apres ecriture : simples comptes par etat (« 0 critique(s) » n est pas une erreur)
    if ($line -match '^(Contrôle complet|Full check|Remesure après réécriture|Re-measure after rewrite)\b') { return $script:LogColors.std }
    if ($line -match 'FATAL|ERREUR|ERROR|ECHEC|ÉCHEC|FAILED|Command Failed|Write ?Protect|CRITIQUE|CRITICAL|ILLISIBLE|UNREADABLE|introuvable|not found|code retour : [1-9]|exit code: [1-9]|support fatigué|worn media|réécriture automatique non lancée|automatic rewrite not started|RESTAURATION ÉCHOUÉE|RESTORE FAILED') { return $script:LogColors.err }
    if ($line -match 'Verify Failure|Retry #|nécessité de nouveaux essais|needed retries|À SURVEILLER|TO WATCH|marginal|DIFF[EÉ]RENT|Interrompu|Interrupted|aborted|non applicable|not applicable|réécriture automatique désactivée|automatic rewrite disabled|Aucune réécriture automatique|No automatic rewrite|non convergée|not converged|NON CONVERGÉE|NOT CONVERGED|Valeurs peu fiables|Unreliable values|Écart à la courbe|Deviation from the curve|Giving up|zone instable|unstable zone|non jugée|not judged|probablement fatigué|probably worn') { return $script:LogColors.warn }
    if ($line -match 'All tracks verified|code retour : 0|exit code: 0|SAIN|HEALTHY|IDENTIQUE|IDENTICAL|EXCELLENT|aucune piste n|no track needed|RESTAURATION RÉUSSIE|RESTORE SUCCEEDED') { return $script:LogColors.ok }
    if ($line -match '^T\d+\.\d+\b[^:]*:') { return $script:LogColors.dim }
    return $script:LogColors.std
}

function Append-Log([string]$text) {
    foreach ($line in ($text -split "`r?`n")) {
        $c = Get-LogColor $line
        $txtLog.SelectionStart = $txtLog.TextLength; $txtLog.SelectionLength = 0
        $txtLog.SelectionColor = $c
        $txtLog.AppendText($line + "`n")
        if ($c -eq $script:LogColors.err -and $split.Panel2Collapsed) { Set-LogVisible $true }
    }
    if ($txtLog.TextLength -gt 400000) {
        $txtLog.ReadOnly = $false; $txtLog.Select(0, 150000); $txtLog.SelectedText = ''; $txtLog.ReadOnly = $true
    }
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.ScrollToCaret()
}

function Get-SpecCount([string]$spec) {
    $n = 0
    foreach ($part in ($spec -split ',')) {
        if ($part -match '^(\d+)-(\d+)$') { $n += [int]$Matches[2] - [int]$Matches[1] + 1 }
        elseif ($part -match '^\d+$') { $n++ }
    }
    return $n
}

function Start-Progress([string]$verb) {
    $script:ProgOp = $verb; $script:ProgTotal = 0
    $script:ProgSeen = New-Object 'System.Collections.Generic.HashSet[string]'
    $stOp.Text = ((T "{0} en cours...") -f "$verb"); $stTrack.Text = ''; $stOp.Image = $script:StIcons.run
    $stBar.Style = 'Marquee'; $stBar.Visible = $true
}

function Update-Progress([string]$line) {
    # Nettoyage des tetes (Start-HeadClean) : « Pass N: ... » a la fin de chaque passe (passes faites) ; une ligne de passe
    # interrompue par « Command Failed » et les autres lignes sont gardees pour le bilan (Complete-HeadClean)
    if ($script:CleanRun) {
        if ($line -match '^Pass (\d+):') {
            $pn = [int]$Matches[1]
            if ($line -notmatch 'Command Failed|FATAL') { $script:CleanRun.Done = [math]::Max([int]$script:CleanRun.Done, $pn + 1); return }
        }
        $script:CleanRun.Lines.Add($line)
        return
    }
    if ($line -match '^(Reading|Writing|Erasing)\s+c=([\d,\-]+):h=([\d,\-]+)') {
        $script:ProgTotal = (Get-SpecCount $Matches[2]) * (Get-SpecCount $Matches[3])
        if ($script:ProgTotal -gt 0) { $stBar.Style = 'Continuous'; $stBar.Minimum = 0; $stBar.Maximum = $script:ProgTotal; $stBar.Value = 0 }
        return
    }
    if ($line -match '^T(\d+)\.(\d+)\b[^:]*:') {
        $key = "$($Matches[1]).$($Matches[2])"
        [void]$script:ProgSeen.Add($key)
        if ($script:ProgTotal -gt 0) {
            $v = [math]::Min($script:ProgSeen.Count, $script:ProgTotal)
            $stBar.Value = $v
            $pct = [math]::Round(100 * $v / $script:ProgTotal, 0)
            $stTrack.Text = ((T "piste {0}  ({1}/{2}, {3} %)") -f "$key", "$v", "$($script:ProgTotal)", "$pct")
        } else { $stTrack.Text = ((T "piste {0}") -f "$key") }
        if ($line -match 'Retry #(\d+)(?:\.(\d+))?') { $stTrack.Text += ((T "  -  essai {0}") -f "$(if ($Matches[2]) { $Matches[2] } else { $Matches[1] })") }
    }
}

function Stop-Progress([int]$code) {
    $stBar.Style = 'Continuous'
    if ($code -eq 0) {
        if ($script:ProgTotal -gt 0) { $stBar.Value = $stBar.Maximum }
        $stOp.Text = ((T "{0} terminé(e)  -  {1}") -f "$($script:ProgOp)", "$(Get-Date -Format 'HH:mm:ss')"); $stOp.Image = $script:StIcons.ok
    } else {
        $stOp.Text = ((T "{0} en échec (code {1})  -  {2}") -f "$($script:ProgOp)", "$code", "$(Get-Date -Format 'HH:mm:ss')"); $stOp.Image = $script:StIcons.err
    }
    $stBar.Visible = ($code -eq 0 -and $script:ProgTotal -gt 0)
}

function Reset-GwSequence {
    # gw n a pas pu etre lance : la sequence en cours (ecriture controlee, calibration, comparaison)
    # est abandonnee, sinon le prochain gw termine avec le code 0 reprendrait ses etapes, ecritures comprises.
    $script:Chain.Clear(); $script:WriteQueue.Clear(); $script:Detect = $null
    Stop-WriteWarmup
    if ($script:Rep) { Stop-WriteCheck }
    if ($script:Cal) { Stop-PrecompCalib }
    if ($txtCmpResult.Text -like ((T 'Comparaison en cours') + '*')) { $txtCmpResult.Text = ((T "ÉCHEC : {0}") -f (T 'gw n''a pas pu être lancé.')) }
    if ($script:Restore) { Stop-Restore (T 'gw n''a pas pu être lancé') }
}

# Sortie de gw capturee via redirection fichier puis relue par le timer.
# --- Detection des lecteurs -------------------------------------------------------------------------------------
# gw seek <lecteur> 0 : sans moteur ni ecriture, la tete revient au cylindre 0 ; un lecteur absent ou mal cable ne
# signale jamais la piste 0 (« Command Failed: Seek: Track 0 not found », code 0, ou « Track0 signal absent », code 1).
# Au demarrage : lecteur memorise d abord, puis A, B, 0 a 3, arret au premier qui repond. Carte « Tester » : tous.
$script:Detect = $null
$script:DetectAt = $null
$script:DriveIds = @('A', 'B', '0', '1', '2', '3')

$script:DetectNone = $false     # aucun lecteur au dernier demarrage : seul le lecteur memorise est teste (configuration)

function Start-DriveDetect([string]$mode) {
    if (-not (Test-Path -LiteralPath $script:GwExe)) { return }
    if (($script:GwProc -and -not $script:GwProc.HasExited) -or $script:Chain.Count -gt 0 -or $script:Rep -or $script:Cal -or $script:Restore -or $script:Detect) { return }
    $script:DetectAt = $null
    $cur = [string]$cmbDrive.Text
    $order = @(@($cur) + @($script:DriveIds | Where-Object { $_ -ne $cur }) | Where-Object { $_ })
    if ($mode -eq 'auto' -and $script:DetectNone) {
        $order = @($cur)
        Append-Log ((T "Détection des lecteurs : aucun lecteur au dernier démarrage, seul le lecteur {0} est testé (carte « Tester le Greaseweazle » de l'Accueil : tous les lecteurs).") -f "$cur")
    }
    $script:Detect = @{ Mode = $mode; Queue = (New-Object System.Collections.Queue); Found = @(); Tried = @(); Cur = $cur; Drive = '' }
    foreach ($d in $order) { $script:Detect.Queue.Enqueue($d) }
    Append-Log ((T "Détection des lecteurs : recherche de la piste 0 sur {0} (gw seek : la tête se déplace, sans rotation ni écriture).") -f "$($order -join ', ')")
    Invoke-DriveProbe
}

function Invoke-DriveProbe {
    $dt = $script:Detect
    if (-not $dt) { return }
    if ($dt.Queue.Count -eq 0) { Complete-DriveDetect; return }
    $d = [string]$dt.Queue.Dequeue(); $dt.Drive = $d; $dt.Tried += $d
    $script:GwCapture = New-Object System.Collections.Generic.List[string]
    $a = @('seek', "--drive=$d")
    if ($txtDev.Text.Trim()) { $a += "--device=$($txtDev.Text.Trim())" }
    $a += '0'
    Start-Gw $a
}

function Complete-DriveProbe([int]$code) {
    # Fin d un gw seek de la detection (appele par le timer, quel que soit le code retour)
    $dt = $script:Detect
    if (-not $dt) { return }
    $lines = @(); if ($script:GwCapture) { $lines = @($script:GwCapture) }
    $script:GwCapture = $null
    $txt = $lines -join "`n"
    if ($code -eq 0 -and $txt -notmatch 'Command Failed|FATAL|Track ?0') {
        $dt.Found += $dt.Drive
        if ($dt.Mode -eq 'auto') { Complete-DriveDetect; return }
    } elseif ($txt -match 'Invalid unit number') {
        # Firmware ACK_BAD_UNIT : ligne de selection non cablee sur cette carte (V4 Slim, F7 Slim, F1 de base, F7 v1)
        Append-Log ((T "Lecteur {0} : non pris en charge par cette carte (ligne de sélection absente).") -f "$($dt.Drive)")
    } elseif ($txt -notmatch 'Track 0 not found|Track0 signal') {
        # Erreur sans rapport avec le lecteur (carte absente, port occupe...) : detection abandonnee, cause en clair
        $why = (@($lines | Where-Object { $_.Trim() } | Select-Object -Last 2) -join ' / ') -replace 'FATAL ERROR:?|Command Failed:?', '' -replace '\*', ''
        Append-Log ((T "Détection des lecteurs interrompue : {0}") -f "$($why.Trim())")
        if ($dt.Found.Count -gt 0) { Complete-DriveDetect } else { $script:Detect = $null }
        return
    }
    Invoke-DriveProbe
}

function Complete-DriveDetect {
    $dt = $script:Detect; $script:Detect = $null
    if (-not $dt) { return }
    $script:DetectNone = ($dt.Found.Count -eq 0)
    # A et 2 (broche 14), B et 1 (broche 12) partagent une ligne de selection : gw seek, sans moteur, ne les distingue
    # pas. Une seule entree par paire : A ou B, sauf si 2 ou 1 etait deja le reglage ; l identifiant prefere qui a ete
    # sonde sans repondre cede la place a celui de la paire qui a repondu
    $found = @($dt.Found)
    foreach ($pp in @(@('A', '2'), @('B', '1'))) {
        if (-not (($found -contains $pp[0]) -or ($found -contains $pp[1]))) { continue }
        $keepId = if ($dt.Cur -eq $pp[1]) { $pp[1] } else { $pp[0] }
        $other = if ($keepId -eq $pp[0]) { $pp[1] } else { $pp[0] }
        if ($found -notcontains $keepId -and @($dt.Tried) -contains $keepId) { $sw = $keepId; $keepId = $other; $other = $sw }
        $found = @($found | Where-Object { $_ -ne $other })
        if ($found -notcontains $keepId) { $found += $keepId }
        if ($dt.Mode -ne 'auto') { Append-Log ((T "{0} et {1} utilisent la même ligne de sélection : la détection ne peut pas les distinguer (A ou B : nappe PC avec twist ; 0 à 3 : nappe droite).") -f $pp[0], $pp[1]) }
    }
    $dt.Found = $found
    if ($dt.Found.Count -eq 0) {
        Append-Log (T "Aucun lecteur détecté : vérifiez l'alimentation du lecteur, la nappe et son sens, puis le type de nappe (A ou B : nappe PC avec twist ; 0 à 3 : nappe droite).")
        return
    }
    $pick = if ($dt.Found -contains $dt.Cur) { $dt.Cur } else { [string]$dt.Found[0] }
    if ($dt.Mode -ne 'auto') { Append-Log ((T "Lecteur(s) détecté(s) : {0}.") -f "$($dt.Found -join ', ')") }
    if ($pick -ne $dt.Cur) {
        Set-Combo $cmbDrive $pick
        # Restauration a un seul lecteur (origine = destination = lecteur absent) seulement : jamais confondre deux lecteurs
        if ($cmbRsSrc.Text -eq $dt.Cur -and $cmbRsDst.Text -eq $dt.Cur) {
            Set-Combo $cmbRsSrc $pick; Set-Combo $cmbRsDst $pick
            Append-Log ((T "Restauration : lecteur {0} remplacé par {1} (origine et destination).") -f "$($dt.Cur)", "$pick")
        }
        Append-Log ((T "Lecteur {0} sélectionné : le lecteur {1} ne répond pas.") -f "$pick", "$($dt.Cur)")
    } else { Append-Log ((T "Lecteur {0} détecté.") -f "$pick") }
}

function Get-GwDriveKey([string[]]$gwArgs) {
    # Lecteur d une commande gw qui fait tourner le moteur (read, write, erase, clean, rpm) : 'peripherique|lecteur' ;
    # $null pour les autres commandes (seek, info...) ou sans --drive
    $line = ' ' + (($gwArgs | Where-Object { $null -ne $_ }) -join ' ')
    $verb = @($line.Trim() -split '\s+')[0]
    if (@('read', 'write', 'erase', 'clean', 'rpm') -notcontains $verb) { return $null }
    if ($line -notmatch '\s--drive=(\S+)') { return $null }
    $drv = $Matches[1]
    $dev = if ($line -match '\s--device=(\S+)') { $Matches[1] } else { '' }
    return "$dev|$drv"
}

function Start-Gw([string[]]$gwArgs, [switch]$Soft) {
    # Soft : lecture de prechauffage d une ecriture lente (Invoke-WriteWarmup), marquee par appel
    $exe = $script:GwExe
    if (-not (Test-Path -LiteralPath $exe)) {
        Reset-GwSequence
        [void][System.Windows.Forms.MessageBox]::Show(((T "gw.exe introuvable : {0}`n`nPlacez ce script dans le même répertoire que gw.exe.") -f "$exe"),(T 'Erreur'),'OK','Error'); return
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) {
        Append-Log ((T "gw déjà en cours : commande ignorée ({0}).") -f "$($gwArgs -join ' ')")
        if ($script:Chain.Count -gt 0 -or $script:Rep -or $script:Cal -or $script:WriteWarm) { Reset-GwSequence }
        return
    }

    if (-not $script:Restore -and -not $script:Detect) { [void](Save-Config) }      # restauration : reglages temporaires ; detection : pas d ecriture a chaque sonde

    $script:GwIsWrite = ($gwArgs.Count -gt 0 -and $gwArgs[0] -eq 'write')
    $verbs = @{ write=(T 'Écriture'); read=(T 'Lecture'); erase=(T 'Effacement'); convert='Conversion'; clean=(T 'Nettoyage'); rpm=(T 'Mesure de vitesse'); update=(T 'Mise à jour firmware') }
    $first = if ($gwArgs.Count -gt 0) { ($gwArgs[0] -split ' ')[0] } else { '' }
    # Lecture de prechauffage (calibration : etape 'warmup' ; ecriture lente : -Soft) : son code retour n arrete pas la
    # sequence ; lecteur de la commande pour DriveActivity (serie d activite mise a jour par le minuteur a la fin de la
    # commande, seulement si le moteur a tourne). Nom distinct du parametre Soft (PowerShell ignore la casse).
    $warmRead = [bool]([bool]$Soft -or ($script:Cal -and $script:Cal.Stage -eq 'warmup' -and $first -eq 'read'))
    Start-Progress $(if ($warmRead) { (T 'Préchauffage') } elseif ($verbs.ContainsKey($first)) { $verbs[$first] } else { "gw $first" })
    if ($script:GwIsWrite) { $script:WriteRetries = @{}; $script:WriteTracks = @{} }
    $script:GwWriteSummary = $false
    $driveKey = if ($script:Detect) { $null } else { Get-GwDriveKey $gwArgs }
    if ($chkTime.Checked) { $gwArgs = @('--time') + $gwArgs }
    $argLine = $gwArgs -join ' '
    if (-not $script:Detect) { Append-Log ">>> gw $argLine" }
    $script:GwStart = Get-Date; $script:GwLines = 0

    # gw.exe est appele directement (aucun cmd.exe intermediaire) ; sa sortie est redirigee
    # dans le processus et lue par des gestionnaires d'evenements qui remplissent une file
    # thread-safe, videe par le timer de l'interface. Pas de fichier temporaire.
    $script:OutPending = ''
    $script:OutQueue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = $exe
    $psi.Arguments = $argLine
    $psi.WorkingDirectory       = $script:AppDir
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
    $psi.EnvironmentVariables['PYTHONUNBUFFERED'] = '1'
    $psi.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi

    try {
        [void]$p.Start()
        $script:GwProc = $p
        $script:GwSoft = $warmRead; $script:GwDriveKey = $driveKey
        # Lecture asynchrone des deux flux : chaque ReadLineAsync rend une Task que le timer
        # inspecte sans bloquer l'interface. Pas de bloc -Action (inactif sous ShowDialog).
        $script:OutStdoutReader = $p.StandardOutput
        $script:OutStderrReader = $p.StandardError
        $script:OutStdoutTask = $script:OutStdoutReader.ReadLineAsync()
        $script:OutStderrTask = $script:OutStderrReader.ReadLineAsync()
        Set-Busy $true
    } catch {
        Append-Log ((T "ERREUR lancement : {0}") -f "$($_.Exception.Message)")
        $script:GwProc = $null; $script:GwSoft = $false; $script:GwDriveKey = $null
        Reset-GwSequence
        Set-Busy $false
    }
}

function Drain-GwReader($reader, [ref]$task) {
    # Vide les lignes disponibles d'un flux ; relance une tache tant qu'elle se complete tout de suite.
    if (-not $reader -or $null -eq $task.Value) { return }
    while ($task.Value.IsCompleted) {
        $line = $null
        try { $line = $task.Value.Result } catch { $task.Value = $null; return }
        if ($null -eq $line) { $task.Value = $null; return }   # fin de flux
        if ($line -ne '') { $script:OutQueue.Enqueue($line) }
        $task.Value = $reader.ReadLineAsync()
    }
}

function Read-GwOutput([bool]$flush) {
    if (-not $script:OutQueue) { return }
    if ($flush) {
        # Processus termine : attendre la fin de flux (EOF) de stdout puis stderr, sinon les dernieres
        # lignes (dont un eventuel message d erreur de gw) restent dans le tube et sont perdues.
        $deadline = (Get-Date).AddSeconds(5)
        foreach ($which in 'out', 'err') {
            while ((Get-Date) -lt $deadline) {
                $t = if ($which -eq 'out') { $script:OutStdoutTask } else { $script:OutStderrTask }
                if ($null -eq $t) { break }
                try { [void]$t.Wait(500) } catch { break }
                if (-not $t.IsCompleted) { continue }
                if ($which -eq 'out') { Drain-GwReader $script:OutStdoutReader ([ref]$script:OutStdoutTask) }
                else                  { Drain-GwReader $script:OutStderrReader ([ref]$script:OutStderrTask) }
            }
        }
    }
    Drain-GwReader $script:OutStdoutReader ([ref]$script:OutStdoutTask)
    Drain-GwReader $script:OutStderrReader ([ref]$script:OutStderrTask)
    $lines = @()
    while ($script:OutQueue.Count -gt 0) {
        $l = [string]$script:OutQueue.Dequeue()
        if ($l -ne '') { $lines += $l }
    }
    if ($lines.Count -eq 0) { return }
    $script:GwLines += $lines.Count
    foreach ($l in $lines) { Update-Progress $l }
    if ($null -ne $script:GwCapture) { foreach ($l in $lines) { $script:GwCapture.Add($l) } }
    if ($script:Detect) { return }                      # detection des lecteurs : sortie analysee, pas affichee
    if ($script:GwIsWrite) {
        foreach ($l in $lines) {
            if ($l -match '^T(\d+)\.(\d+)\b[^:]*:.*Retry #(\d+)') {
                $k = "$($Matches[1]).$($Matches[2])"; $n = [int]$Matches[3]
                if (-not $script:WriteRetries.ContainsKey($k) -or $n -gt $script:WriteRetries[$k]) { $script:WriteRetries[$k] = $n }
            }
            if ($l -match '^T(\d+)\.(\d+)\b[^:]*: Writing Track') { $script:WriteTracks["$($Matches[1]).$($Matches[2])"] = $true }
            if ($l -match '^(All tracks verified|No tracks verified|\d+ tracks verified)') { $script:GwWriteSummary = $true }
        }
    }
    if ($lines.Count -gt 0) { Append-Log ($lines -join [Environment]::NewLine) }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({
    # Sortie de gw
    if ($script:GwProc) {
        if ($script:GwProc.HasExited) {
            Read-GwOutput $true
            $code = $script:GwProc.ExitCode
            # Lecture de prechauffage : code retour et pistes manquantes sans effet, l etape suivante a toujours lieu
            $soft = [bool]$script:GwSoft; $script:GwSoft = $false; $script:GwLastCode = $code
            # Activite du lecteur : seulement si le moteur a tourne (code 0, ou au moins une piste lue ou ecrite) ;
            # nouvelle serie si la commande a commence CalWarmupGapMin apres la fin de la precedente
            if ($script:GwDriveKey -and ($code -eq 0 -or ($script:ProgSeen -and $script:ProgSeen.Count -gt 0))) {
                $actNow = Get-Date; $actCur = $script:DriveActivity[$script:GwDriveKey]
                if (-not $actCur -or ($script:GwStart - $actCur.End).TotalMinutes -ge $script:CalWarmupGapMin) { $script:DriveActivity[$script:GwDriveKey] = @{ Start = $script:GwStart; End = $actNow } }
                else { $actCur.End = $actNow }
            }
            $script:GwDriveKey = $null
            $script:OutStdoutReader = $null; $script:OutStderrReader = $null
            $script:OutStdoutTask = $null; $script:OutStderrTask = $null
            Stop-Progress $code
            $wasWrite = [bool]$script:GwIsWrite
            if ($script:GwIsWrite) {
                if ($script:WriteRetries.Count -gt 0) {
                    Append-Log ((T "Pistes ayant nécessité de nouveaux essais : ") + (($script:WriteRetries.Keys | Sort-Object | ForEach-Object { ((T "{0} (x{1})") -f "$_", "$($script:WriteRetries[$_])") }) -join ', '))
                } elseif ($code -eq 0 -and $script:GwWriteSummary) { Append-Log (T 'Écriture : aucune piste n''a nécessité de nouvel essai.') }
                $script:GwIsWrite = $false
            }
            $elapsed = if ($script:GwStart -is [datetime]) { [math]::Round(((Get-Date) - $script:GwStart).TotalSeconds, 1) } else { 0 }
            if ($script:Detect) { Stop-Progress 0 }
            else { Append-Log ((T "<<< Terminé (code retour : {0}, {1} s, {2} ligne(s) reçues)") -f "$code", "$elapsed", "$($script:GwLines)") }
            # Arret silencieux avec le code 0 (ex. « Command Failed: WriteProtected ») : pas de controle ni d etape suivante,
            # ils masqueraient le probleme. Ecriture : gw imprime toujours une ligne de bilan quand il va au bout (verification
            # comprise), quel que soit le nombre de pistes de l image. Autres commandes : moins de la moitie des pistes annoncees.
            $incomplete = if ($wasWrite) { $code -eq 0 -and -not $script:GwWriteSummary }
                          else { $code -eq 0 -and $script:ProgTotal -gt 0 -and $script:ProgSeen.Count * 2 -lt $script:ProgTotal }
            $script:GwLastIncomplete = [bool]$incomplete
            if ($incomplete -and -not $soft) {
                Append-Log ((T "ERREUR : opération incomplète, gw s'est arrêté après {0} piste(s) sur {1} annoncées avec le code 0. Vérifier le lecteur, le câble USB et l'alimentation, puis relancer.") -f "$($script:ProgSeen.Count)", "$($script:ProgTotal)")
                $script:Chain.Clear(); $script:WriteQueue.Clear()
                Stop-WriteWarmup        # defensif : une lecture de prechauffage est « soft »
                $why = (T 'opération gw incomplète : disquette protégée en écriture, absente, ou lecteur en défaut ? Voir le journal')
                if ($script:Restore -and $script:Restore.Stage -eq 'probe') { Restore-ProbeFailed }
                else {
                    # Restauration : raison exacte d abord, sauf si le controle a deja un bilan (il l ecrira dans le rapport)
                    if ($script:Restore -and -not ($script:Rep -and $script:Rep.Round -gt 0)) { Stop-Restore $why }
                    if ($script:Rep) { Stop-WriteCheck -GwError }
                    if ($script:Cal) { Stop-PrecompCalib }
                    if ($script:Restore) { Stop-Restore $why }
                }
            }
            if (-not $script:Detect) { Append-Log '' }
            $script:GwProc = $null
            Set-Busy $false
            if ($script:Detect) { Complete-DriveProbe $code }
            if ($script:Chain.Count -gt 0) {
                if ($code -eq 0 -or $soft) {
                    Invoke-NextChainStep
                } else {
                    $why = ((T "gw a retourné le code {0}, voir le journal") -f "$code")
                    if ($script:Restore -and $script:Restore.Stage -eq 'probe') { Restore-ProbeFailed }
                    elseif ($script:Restore -and -not ($script:Rep -and $script:Rep.Round -gt 0)) { Stop-Restore $why }
                    $script:Chain.Clear(); $script:WriteQueue.Clear()
                    Stop-WriteWarmup    # defensif : une lecture de prechauffage est « soft »
                    Append-Log (T 'Séquence interrompue : gw a retourné une erreur.')
                    if ($txtCmpResult.Text -like ((T 'Comparaison en cours') + '*')) { $txtCmpResult.Text = ((T "ÉCHEC : gw a retourné le code {0}. Voir le journal.") -f "$code") }
                    if ($script:AlignLoop) { $script:AlignLoop = $false; $script:AlignNextAt = $null; $lblAlVerdict.Text = (T 'Mesure interrompue (erreur gw)') }
                    if ($script:Rep) { Stop-WriteCheck -GwError }
                    if ($script:Cal) { Stop-PrecompCalib }
                }
            }
            if ($code -ne 0 -and -not $soft -and $script:Restore -and -not $script:Restore.Waiting) { Stop-Restore ((T "gw a retourné le code {0}, voir le journal") -f "$code") }
        } else {
            Read-GwOutput $false
        }
    }
    # Ecriture apres une calibration rapide de la Bibliotheque, terminee (gw, etapes, controle et calibration finis) :
    # champs --precomp remis au profil de la reference, le profil decale ne valait que pour la disquette ecrite
    if ($script:LevelFieldsPending -and -not $script:GwProc -and $script:Chain.Count -eq 0 -and -not $script:Rep -and -not $script:Cal -and -not $script:WriteWarm) {
        $script:LevelFieldsPending = $false
        if ($cmbWProfile.SelectedIndex -eq 0 -and -not $script:Restore) {
            Update-PrecompForImage $txtWFile.Text
            Append-Log (T 'Calibration rapide : écriture terminée, champs --precomp remis au profil de la référence (le profil décalé ne valait que pour la disquette écrite).')
        }
    }
    # Calibration precomp : barre globale et temps restant ; prechauffage d une ecriture lente
    if ($script:Cal) { Update-CalibProgress } elseif ($script:WriteWarm) { Update-WriteWarmupProgress }
    if ($script:HomeCalBusy) { Update-HomeCalibCard }     # carte Calibration de l Accueil : progression, puis bilan
    # Bouton « Passer le prechauffage » : visible pendant tout prechauffage (ecriture lente, calibration), inactif une fois
    # clique ; Enregistrer et Reinitialiser (inactifs pendant une operation) lui cedent leur place dans la barre
    $wcur = if ($script:WriteWarm) { $script:WriteWarm } elseif ($script:Cal -and $script:Cal.Stage -eq 'warmup') { $script:Cal } else { $null }
    $wshow = [bool]$wcur
    if ($script:WarmSkipShown -ne $wshow) { $script:WarmSkipShown = $wshow; $btnWarmSkip.Visible = $wshow; $btnCfgSave.Visible = -not $wshow; $btnCfgReset.Visible = -not $wshow }
    if ($wshow -and $btnWarmSkip.Enabled -eq [bool]$wcur.WarmSkip) { $btnWarmSkip.Enabled = -not [bool]$wcur.WarmSkip }
    # Restauration : etape en cours et chien de garde
    if ($script:Restore) { Update-RestoreProgress }
    # Detection des lecteurs au demarrage, fenetre affichee et aucune operation en cours
    if ($script:DetectAt -and (Get-Date) -ge $script:DetectAt -and -not $script:GwProc -and $script:Chain.Count -eq 0 -and -not $script:Rep -and -not $script:Cal -and -not $script:Restore) {
        $script:DetectAt = $null
        Start-DriveDetect 'auto'
    }
    # Alignement : passe suivante en mode continu
    if ($script:AlignLoop -and $script:AlignNextAt -and -not $script:GwProc -and -not $script:Cal -and -not $script:Rep -and -not $script:Restore -and $script:Chain.Count -eq 0 -and (Get-Date) -ge $script:AlignNextAt) {
        $script:AlignNextAt = $null
        Start-AlignCycle
    }
    # Recherche bibliotheque terminee ?
    if ($script:LibAsync -and $script:LibAsync.IsCompleted) { Complete-LibSearch }
    # Indexation en cours / terminee
    if ($script:LibIndexing) {
        if ([FastIndex]::Busy) {
            $lblLibCount.Text = ((T "indexation : {0} fichiers...") -f "$('{0:N0}' -f [FastIndex]::Scanned)")
        } else {
            $script:LibIndexing = $false; $btnLibReindex.Enabled = $true
            if ([FastIndex]::Error) { Append-Log ((T "Indexation : ERREUR {0}") -f "$([FastIndex]::Error)") }
            else { Append-Log ((T "Bibliothèque : index construit, {0} fichiers en {1} s.") -f "$('{0:N0}' -f [FastIndex]::Count)", "$([math]::Round([FastIndex]::LastBuildSeconds,0))") }
            Show-LibIndexStatus
            if ($script:LibPendingSearch) { $script:LibPendingSearch = $false; Update-Library }
        }
    }
    # Recherche au fil de la frappe (seulement si l'index est pret : sinon on attend Entree)
    if ($script:LibSearchAt -and (Get-Date) -ge $script:LibSearchAt) {
        $script:LibSearchAt = $null
        if (Test-LibIndexReady $txtLibRoot.Text) { Update-Library }
    }
})
$timer.Start()

$form.KeyPreview = $true
$form.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::F1) { Open-HelpForTab; $_.Handled = $true } })
$form.Add_FormClosing({
    if ($script:Restore) {
        $q = [System.Windows.Forms.MessageBox]::Show((T "Une restauration est en cours. Quitter quand même ? La disquette de destination restera incomplète."), (T 'Restauration'), 'YesNo', 'Warning')
        if ($q -ne 'Yes') { $_.Cancel = $true; return }
        if ($script:GwProc -and -not $script:GwProc.HasExited) { try { $script:GwProc.Kill() } catch { } }
        Stop-Restore (T 'fenêtre fermée pendant la restauration')   # rapport ecrit, onglet Ecriture et lecteur remis avant Save-Config
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) {
        try { $script:GwProc.Kill($true) } catch { try { $script:GwProc.Kill() } catch { } }
    }
    [void](Save-Config)
    Stop-LibSearch
    if ($script:LibRunspace) { try { $script:LibRunspace.Close(); $script:LibRunspace.Dispose() } catch { } }
    $timer.Stop()
})

# Position du separateur : appliquee une fois la fenetre affichee (taille connue)
$script:PendingSplit = 0
$script:PendingLogVisible = $true
$form.Add_Shown({
    $script:UiReady = $true
    Render-Banner
    Apply-Cues
    Set-LogVisible $script:PendingLogVisible
    if ($script:PendingSplit -gt 0) {
        $max = $split.Height - $split.Panel2MinSize - $split.SplitterWidth
        if ($script:PendingSplit -ge $split.Panel1MinSize -and $script:PendingSplit -le $max) {
            $split.SplitterDistance = $script:PendingSplit
        }
    }
    # Bibliotheque chargee une fois la fenetre visible (racine reseau possible)
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try { Update-Library; if ($txtWFile.Text) { Update-PrecompForImage $txtWFile.Text } else { Update-CurveButton '' } } finally { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
    # Calibrations d un autre calcul : choix de l utilisateur, puis detection des lecteurs (qui lance gw)
    Resolve-OldCalibrations
    if (Test-Path -LiteralPath $script:GwExe) { $script:DetectAt = (Get-Date).AddSeconds(1) }   # detection des lecteurs
})

# --- Largeurs ajustees au texte (police, langue) : plus de libelles tronques --------
function Fit-ControlText($parent) {
    foreach ($c in @($parent.Controls)) {
        if ($c -is [System.Windows.Forms.CheckBox] -or $c -is [System.Windows.Forms.RadioButton]) {
            if ($c.Text) { $c.AutoSize = $true }
        } elseif ($c -is [System.Windows.Forms.Button] -and $c.Text -and $c.Text -ne '...') {
            $extra = if ($c.Image) { 46 } else { 24 }
            $need = [System.Windows.Forms.TextRenderer]::MeasureText($c.Text, $c.Font).Width + $extra
            if ($c.Width -lt $need) {
                $delta = $need - $c.Width
                $right = [bool]($c.Anchor -band [System.Windows.Forms.AnchorStyles]::Right)
                $left  = [bool]($c.Anchor -band [System.Windows.Forms.AnchorStyles]::Left)
                if ($right -and -not $left) { $c.Left -= $delta }
                $c.Width = $need
            }
        }
        if ($c.Controls.Count -gt 0) { Fit-ControlText $c }
    }
}
Fit-ControlText $form

# --- Demarrage -----------------------------------------------------------------
Set-Defaults
$loaded = Load-Config
Update-TabSet
Update-CurveButton ''

Append-Log "Greaseweazle Studio v$($script:Version)"
Append-Log ((T "Répertoire  : {0}") -f "$($script:AppDir)")
if (Test-Path -LiteralPath $script:GwExe) { Append-Log (T 'gw.exe      : trouvé') }
else { Append-Log (T 'gw.exe      : ABSENT - placez ce script dans le répertoire de gw.exe') }
if ($loaded) { Append-Log (T 'Config      : chargée depuis GreaseweazleGUI.json') }
else         { Append-Log (T 'Config      : aucune, valeurs par défaut') }
Append-Log ((T "Extraction  : {0}") -f "$($script:TempDir)")
Append-Log ((T "Index       : {0}") -f "$(if ($script:FastIndexOk) { $script:IndexDir } else { (T 'module indisponible, recherche directe') })")
Append-Log ''

[void]$form.ShowDialog()
