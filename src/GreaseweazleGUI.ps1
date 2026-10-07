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
#      automatiquement d apres l image (IPF : bits par piste, SCP : flux, HFE : debit).
#
# Compatible Windows PowerShell 5.1+ / PowerShell 7
# Lancement : powershell -ExecutionPolicy Bypass -File .\GreaseweazleGUI.ps1
# =============================================================================

param(
    [ValidateSet('auto','fr','en')][string]$Language = 'auto'   # auto = langue d affichage de Windows (fr -> francais, sinon anglais)
)

# Version de l application (lue par Build-Exe.ps1 et par le workflow de release)
$script:Version = '11.7'

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
$script:I18n["A/B = bus IBM-PC (nappe avec twist) - typiquement le lecteur PC`n0/1/2 = bus Shugart (nappe droite) - typiquement le lecteur Amiga"] = "A/B = IBM-PC bus (twisted cable) - typically the PC drive`n0/1/2 = Shugart bus (straight cable) - typically the Amiga drive"
$script:I18n['Port COM du Greaseweazle. Vide = détection automatique.'] = 'Greaseweazle COM port. Empty = auto-detect.'
$script:I18n['Affiche le temps écoulé après chaque commande gw.'] = 'Shows the elapsed time after each gw command.'
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
$script:I18n['Envoyer vers Écriture'] = 'Send to Write'
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
$script:I18n["Auto : la cellule de l'image est mesurée (IPF : bits par piste ; SCP : flux ; HFE : débit)`net le profil --precomp correspondant est appliqué.`nManuel : le champ --precomp n'est jamais modifié."] = "Auto: the image bit cell is measured (IPF: bits per track; SCP: flux; HFE: bitrate)`nand the matching --precomp profile is applied.`nManual: the --precomp field is never changed."
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
$script:I18n['Mesurer la disquette après l''écriture'] = 'Measure the disk after writing'
$script:I18n["Après une écriture réussie, relit la disquette et évalue l'état du support :`nles pistes qui ont nécessité des retries à l'écriture sont relues en priorité,`nplus un échantillon de contrôle (cylindres 0, 40, 79). Résultat dans l'onglet Qualité & alignement."] = "After a successful write, reads the disk back and assesses the media condition:`ntracks that needed retries while writing are read first,`nplus a control sample (cylinders 0, 40, 79). Result in the Quality & alignment tab."
$script:I18n['Retries :'] = 'Retries:'
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
$script:I18n['Choisis une image : le format et la précompensation seront déduits automatiquement.'] = 'Choose an image: the format and precompensation will be detected automatically.'
$script:I18n['Lecture / Dump'] = 'Read / Dump'
$script:I18n['Flux SCP (préservation)|*.scp|ADF (AmigaDOS)|*.adf|Kryoflux stream|*.raw|HFE|*.hfe|Tous|*.*'] = 'SCP flux (preservation)|*.scp|ADF (AmigaDOS)|*.adf|Kryoflux stream|*.raw|HFE|*.hfe|All files|*.*'
$script:I18n['Tours lus par piste. 5 recommandés pour l''archivage flux (SCP).'] = 'Revolutions read per track. 5 recommended for flux archiving (SCP).'
$script:I18n['--raw (cumuler le flux entre les retries)'] = '--raw (accumulate flux across retries)'
$script:I18n['LIRE LA DISQUETTE'] = 'READ THE DISK'
$script:I18n['Indique un fichier de sortie.'] = 'Specify an output file.'
$script:I18n['Sortie :'] = 'Output:'
$script:I18n['Révolutions :'] = 'Revolutions:'
$script:I18n['Tracks :'] = 'Tracks:'
$script:I18n['Images disquette|*.scp;*.raw;*.ipf;*.adf;*.hfe;*.img;*.st;*.dsk|Tous|*.*'] = 'Disk images|*.scp;*.raw;*.ipf;*.adf;*.hfe;*.img;*.st;*.dsk|All files|*.*'
$script:I18n['Format de décodage. Nécessaire pour passer d''un flux (SCP/RAW) à un format secteur (ADF).'] = 'Decoding format. Required to go from a flux file (SCP/RAW) to a sector format (ADF).'
$script:I18n['CONVERTIR'] = 'CONVERT'
$script:I18n['Fichier source introuvable.'] = 'Source file not found.'
$script:I18n['Indique un fichier de destination.'] = 'Specify a destination file.'
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
$script:I18n['Fais d''abord une mesure.'] = 'Run a measurement first.'
$script:I18n['Référence'] = 'Reference'
$script:I18n["lecteur {0}, tête {1}, {2}"] = "drive {0}, head {1}, {2}"
$script:I18n["Référence : {0} ({1} piste(s))"] = "Reference: {0} ({1} track(s))"
$script:I18n["Mesure : référence fixée ({0})."] = "Measurement: reference set ({0})."
$script:I18n['Réinitialiser'] = 'Reset'
$script:I18n['Efface le meilleur score, la tendance, la référence et le guide.'] = 'Clears the best score, the trend, the reference and the guide.'
$script:I18n['Aucune référence'] = 'No reference'
$script:I18n['Lance une mesure'] = 'Run a measurement'
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
$script:I18n["État par piste : SAIN / À SURVEILLER / CRITIQUE (erreurs, trous, stabilité, jitter).`nSeuils jitter : <60 / <120 / <200 ns. Asymétrie : <0,02 / <0,05 / <0,10."] = "Per-track status: HEALTHY / TO WATCH / CRITICAL (errors, dropouts, stability, jitter).`nJitter thresholds: <60 / <120 / <200 ns. Asymmetry: <0.02 / <0.05 / <0.10."
$script:I18n['Mesure :'] = 'Measure:'
$script:I18n['Cylindres :'] = 'Cylinders:'
$script:I18n['Têtes :'] = 'Heads:'
$script:I18n['Tours :'] = 'Revs:'
$script:I18n['Outils'] = 'Tools'
$script:I18n['Info périphérique'] = 'Device info'
$script:I18n['Mesurer la vitesse (rpm)'] = 'Measure speed (rpm)'
$script:I18n['Bande passante USB'] = 'USB bandwidth'
$script:I18n['Reset du périphérique'] = 'Reset device'
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
$script:I18n["Insère une DISQUETTE DE NETTOYAGE (jamais une disquette de données) puis valide."] = "Insert a CLEANING DISK (never a data disk), then confirm."
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
$script:I18n['Coche au moins un paramètre à modifier.'] = 'Check at least one parameter to change.'
$script:I18n['Rien à faire'] = 'Nothing to do'
$script:I18n["Valeurs pré-remplies = défauts usine, à titre indicatif.`n"] = "Pre-filled values = factory defaults, for reference.`n"
$script:I18n["Coche une case pour transmettre le paramètre à gw.`n`n"] = "Tick a box to pass the parameter to gw.`n`n"
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
$script:I18n['Paramètres'] = 'Settings'
$script:I18n["Paramètres enregistrés : {0}"] = "Settings saved: {0}"
$script:I18n["Remettre tous les paramètres de l'interface à leurs valeurs par défaut et supprimer le fichier de configuration ?`n`n(Aucun effet sur le Greaseweazle, ni sur tes fichiers image, ni sur l'index de la bibliothèque.)"] = "Reset all interface settings to their defaults and delete the configuration file?`n`n(No effect on the Greaseweazle, your image files or the library index.)"
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
$script:I18n["Pour commencer :`r`n1. Choisis le dossier racine de tes images (bouton ...).`r`n2. Déplie l'arborescence ou utilise la recherche.`r`n3. Sélectionne une image puis « Envoyer vers Écriture »."] = "To get started:`r`n1. Choose the root folder of your images (... button).`r`n2. Expand the tree or use the search.`r`n3. Select an image, then ""Send to Write""."
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
$script:I18n['Choisis un format de décodage.'] = 'Choose a decoding format.'
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
$script:I18n['Indique au moins un cylindre valide (0-83).'] = 'Specify at least one valid cylinder (0-83).'
$script:I18n['Barres de score par cylindre : apparaissent après la première mesure.'] = 'Score bars per cylinder: shown after the first measurement.'
$script:I18n["Position {0}  |  meilleure position : {1} (score {2})"] = "Position {0}  |  best position: {1} (score {2})"
$script:I18n["Position 0 mesurée (score {0}). Tourne le stepper d'UN PETIT cran dans un sens, puis clique le bouton correspondant."] = "Position 0 measured (score {0}). Turn the stepper ONE SMALL notch in one direction, then click the matching button."
$script:I18n["Position {0} re-mesurée. Meilleure position connue : {1}."] = "Position {0} measured again. Best known position: {1}."
$script:I18n[" Reviens de {0} cran(s) vers le sens {1} pour la retrouver."] = " Go back {0} notch(es) in direction {1} to return to it."
$script:I18n["Position {0} mesurée. Pas de mesure à la position précédente : impossible de conclure, continue."] = "Position {0} measured. No measurement at the previous position: cannot conclude, keep going."
$script:I18n["AMÉLIORATION ({0} -> {1}) : CONTINUE dans le sens {2}, encore un cran, puis mesure."] = "IMPROVEMENT ({0} -> {1}): KEEP GOING in direction {2}, one more notch, then measure."
$script:I18n["OPTIMUM TROUVÉ à la position {0} (score {1}) : RECULE d'un cran (sens {2}), resserre les vis, re-mesure pour contrôle."] = "OPTIMUM FOUND at position {0} (score {1}): GO BACK one notch (direction {2}), tighten the screws, measure again to check."
$script:I18n["DÉGRADATION ({0} -> {1}) : RECULE d'un cran (sens {2}) pour revenir à la position {3}, puis essaie l'autre sens."] = "DEGRADATION ({0} -> {1}): GO BACK one notch (direction {2}) to return to position {3}, then try the other direction."
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
$script:I18n["CONTRÔLE POST-ÉCRITURE : "] = "POST-WRITE CHECK: "
$script:I18n["  (aucun retry à l'écriture)"] = "  (no retry while writing)"
$script:I18n["CONTRÔLE POST-ÉCRITURE : pistes difficiles ({0}) relues SAINES  -  "] = "POST-WRITE CHECK: difficult tracks ({0}) read back HEALTHY  -  "
$script:I18n["CONTRÔLE POST-ÉCRITURE : pistes difficiles encore marginales : {0}  ->  réécrire sur un autre support"] = "POST-WRITE CHECK: difficult tracks still marginal: {0}  ->  rewrite on another disk"
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
$script:I18n["gw.exe introuvable : {0}`n`nPlace ce script dans le même répertoire que gw.exe."] = "gw.exe not found: {0}`n`nPut this script in the same folder as gw.exe."
$script:I18n['Lecture'] = 'Read'
$script:I18n['Effacement'] = 'Erase'
$script:I18n['Nettoyage'] = 'Clean'
$script:I18n['Mesure de vitesse'] = 'Speed measurement'
$script:I18n["ERREUR lancement : {0}"] = "Launch ERROR: {0}"
$script:I18n['Contrôle post-écriture : module d''analyse SCP indisponible.'] = 'Post-write check: SCP analysis module unavailable.'
$script:I18n["Contrôle post-écriture : pistes avec retries : {0}. Relecture des cylindres {1} (2 faces)."] = "Post-write check: tracks with retries: {0}. Reading back cylinders {1} (2 sides)."
$script:I18n["Pistes ayant nécessité des retries : "] = "Tracks that needed retries: "
$script:I18n['Écriture : aucune piste n''a nécessité de retry.'] = 'Write: no track needed a retry.'
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
$script:I18n['gw.exe      : ABSENT - place ce script dans le répertoire de gw.exe'] = 'gw.exe      : MISSING - put this script in the gw.exe folder'
$script:I18n['Config      : chargée depuis GreaseweazleGUI.json'] = 'Config      : loaded from GreaseweazleGUI.json'
$script:I18n['Config      : aucune, valeurs par défaut'] = 'Config      : none, using defaults'
$script:I18n['module indisponible, recherche directe'] = 'module unavailable, direct search'
$script:I18n['Effacer'] = 'Clear'
$script:I18n['Piste'] = 'Track'
$script:I18n['État'] = 'Status'
$script:I18n['Erreurs'] = 'Errors'
$script:I18n['Trous'] = 'Dropouts'
$script:I18n['Dossier'] = 'Folder'
$script:I18n['Alignement'] = 'Alignment'
$script:I18n['aucune'] = 'none'
$script:I18n['diskdefs|*.cfg|Tous|*.*'] = 'diskdefs|*.cfg|All files|*.*'
$script:I18n['ADF|*.adf|SCP|*.scp|HFE|*.hfe|IMG|*.img|Tous|*.*'] = 'ADF|*.adf|SCP|*.scp|HFE|*.hfe|IMG|*.img|All files|*.*'
$script:I18n['Calibration précomp :'] = 'Precomp calibration:'
$script:I18n['Test standard : 1 cylindre sur 10'] = 'Standard test: 1 cylinder in 10'
$script:I18n['Test fin : tous les cylindres'] = 'Fine test: every cylinder'
$script:I18n['Calibrer'] = 'Calibrate'
$script:I18n["Calibre la précompensation pour ce lecteur d'écriture : chaque passe écrit les cylindres de test de l'image avec une valeur de precomp, les relit en flux et note le placement des transitions. La meilleure valeur par cylindre forme le profil, enregistré pour la famille de l'image (standard ou long track) et appliqué ensuite par le mode Auto. La disquette insérée est écrasée. Test standard : un cylindre sur 10, quelques minutes. Test fin : tous les cylindres, environ une heure."] = "Calibrates precompensation for this write drive: each pass writes the image's test cylinders with one precomp value, reads them back as flux and scores transition placement. The best value per cylinder forms the profile, saved for the image family (standard or long track) and applied by Auto mode from then on. The inserted disk is overwritten. Standard test: one cylinder in 10, a few minutes. Fine test: every cylinder, about an hour."
$script:I18n['Calibration : module d''analyse SCP indisponible (Add-Type).'] = 'Calibration: SCP analysis module unavailable (Add-Type).'
$script:I18n['Choisis d''abord l''image à écrire : ses pistes servent de motif de test.'] = 'Choose the image to write first: its tracks are used as the test pattern.'
$script:I18n["Calibration impossible sur un flux ({0}) : gw n'applique la précompensation qu'aux images à bits ou secteurs (ADF, IPF, HFE, IMG...)."] = "Cannot calibrate with a flux image ({0}): gw only applies precompensation to bit-cell or sector images (ADF, IPF, HFE, IMG...)."
$script:I18n['Calibration precomp'] = 'Precomp calibration'
$script:I18n["{0} cylindres d'après l'image"] = "{0} cylinders from the image"
$script:I18n['80 cylindres par défaut (nombre non lisible dans l''image)'] = '80 cylinders by default (count not readable from the image)'
$script:I18n['test fin, tous les cylindres'] = 'fine test, every cylinder'
$script:I18n['test standard, un cylindre sur 10'] = 'standard test, one cylinder in 10'
$script:I18n["Calibration de la précompensation sur le lecteur {0} ({1}).`n`nImage : {2}, famille {3}, {4}.`nCylindres de test : {5} (2 faces), ÉCRASÉS à chaque passe. Durée estimée : {6} min pour {7} passes.`n`nInsère une disquette vierge ou sans valeur, puis confirme."] = "Precompensation calibration on drive {0} ({1}).`n`nImage: {2}, family {3}, {4}.`nTest cylinders: {5} (both sides), OVERWRITTEN on every pass. Estimated time: {6} min for {7} passes.`n`nInsert a blank or worthless disk, then confirm."
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
$script:I18n["Profil estimé : {0}"] = "Estimated profile: {0}"
$script:I18n["{0} cylindre(s) corrigé(s) de plus de {1} ns de résidu, nouveau profil : {2}"] = "{0} cylinder(s) corrected for more than {1} ns of residual, new profile: {2}"
$script:I18n["Résidu après vérification (ns, tolérance {0}) : {1}"] = "Residual after verification (ns, tolerance {0}): {1}"
$script:I18n['Calibration precomp : aucune mesure exploitable, profil inchangé.'] = 'Precomp calibration: no usable measurement, profile unchanged.'
$script:I18n["Profil {0} calibré le {1} sur le lecteur {2} : {3}"] = "{0} profile calibrated on {1} for drive {2}: {3}"
$script:I18n["Calibration terminée : profil {0} = {1}"] = "Calibration complete: {0} profile = {1}"
$script:I18n["Profil enregistré dans la configuration et appliqué par le mode Auto à toute image {0}."] = "Profile saved to the configuration and applied by Auto mode to any {0} image."
$script:I18n['Calibration precomp interrompue.'] = 'Precomp calibration aborted.'
$script:I18n['écriture'] = 'writing'
$script:I18n['relecture'] = 'reading back'
$script:I18n["Calibration : passe {0}/{1}, {2}, {3}  -  {4} %  -  reste environ {5}"] = "Calibration: pass {0}/{1}, {2}, {3}  -  {4} %  -  about {5} left"
$script:I18n["Calibration terminée en {0}"] = "Calibration completed in {0}"
function T([string]$s) {
    if ($script:Lang -eq 'fr') { return $s }
    $t = $script:I18n[$s]
    if ($null -ne $t) { return $t }
    return $s
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
}
public static class ScpStats {
    public static ScpRev Analyze(int[] flux, double indexNs) {
        var r = new ScpRev(); r.IndexMs = indexNs / 1e6; r.NFlux = flux.Length; r.Shift = double.NaN; r.ShiftN = 0;
        // 1) estimation de la cellule : mediane des intervalles de 2 cellules.
        //    Fenetre large (3,0 - 5,0 us) valable pour 2 us (AmigaDOS) comme pour 1,89 us (long tracks).
        var c2raw = new List<double>();
        foreach (int f in flux) if (f > 3000 && f < 5000) c2raw.Add(f);
        if (c2raw.Count < 50) { r.Cell = double.NaN; r.Jitter = double.NaN; r.R3 = double.NaN; r.R4 = double.NaN; r.OutOfClass = flux.Length; r.Dropouts = 0; return r; }
        c2raw.Sort(); double cell = c2raw[c2raw.Count / 2] / 2.0;
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
        double sSL = 0, sSS = 0, sLS = 0, sLL = 0; int nSL = 0, nSS = 0, nLS = 0, nLL = 0;
        for (int i = 1; i < n - 1; i++) {
            int k = cls[i]; if (k != 2 && k != 3) continue;
            int a = cls[i - 1], b = cls[i + 1];
            if (a < 2 || a > 4 || b < 2 || b > 4) continue;
            bool aL = a >= 3, bL = b >= 3;
            if (k == 2) { if (aL && bL) { sSL += flux[i]; nSL++; } else if (!aL && !bL) { sSS += flux[i]; nSS++; } }
            else        { if (!aL && !bL) { sLS += flux[i]; nLS++; } else if (aL && bL) { sLL += flux[i]; nLL++; } }
        }
        bool okS = nSL >= 30 && nSS >= 30, okL = nLS >= 30 && nLL >= 30;
        double shS = okS ? sSL / nSL - sSS / nSS : 0, shL = okL ? sLS / nLS - sLL / nLL : 0;
        if (okS && okL) { r.Shift = (shS - shL) / 2; r.ShiftN = Math.Min(Math.Min(nSL, nSS), Math.Min(nLS, nLL)); }
        else if (okS) { r.Shift = shS; r.ShiftN = Math.Min(nSL, nSS); }
        else if (okL) { r.Shift = -shL; r.ShiftN = Math.Min(nLS, nLL); }
        return r;
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
'@ -ErrorAction Stop
    $script:ScpStatsOk = $true
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
$script:WriteRetries = @{}      # pistes ayant necessite des retries a l ecriture : 'cyl.tete' -> nb max de retries
$script:PostWriteMode = $false  # la prochaine analyse est un controle post-ecriture
$script:AlPos       = $null     # guide : position courante du stepper en crans declares (0 = repere)
$script:AlLastMove  = 0         # guide : dernier deplacement declare (+1 / -1 / 0)
$script:AlPosScores = @{}       # guide : position -> meilleur score moyen mesure a cette position
$script:AlignRef    = $null     # reference memorisee (meme structure)

# Profils de precompensation (mesures le 06/10/2026, lecteur A600 en ecriture, relecture A600)
$script:PrecompStd  = '0=70:40=100:65=140'          # cellule 2 us : AmigaDOS, ADF, formats IBM/Atari
$script:PrecompLong = '0=85:20=110:40=120:65=140'   # cellule ~1,89 us : long tracks (formats proprietaires)
$script:PrecompThresholdNs = 1950                   # cellule < seuil -> profil long track
$script:AlignRefLabel = ''

$Formats = @('(auto)','amiga.amigados','amiga.amigados_hd','atarist.720','atarist.800','atarist.880',
             'ibm.360','ibm.720','ibm.1440','ibm.scan','commodore.1541','mac.800','raw.250','raw.500')

# --- Fenetre -------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Greaseweazle Studio v$($script:Version)"
$form.ClientSize = New-Object System.Drawing.Size(790, 680)
$form.MinimumSize = New-Object System.Drawing.Size(800, 620)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
$form.BackColor = [System.Drawing.Color]::FromArgb(236, 239, 244)
$mono     = New-Object System.Drawing.Font('Consolas', 9.5)
$monoBig  = New-Object System.Drawing.Font('Consolas', 10.5)
$tip  = New-Object System.Windows.Forms.ToolTip

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
    Play=0xE768; Pin=0xE718; Usb=0xE88E; Add=0xE710; Remove=0xE738
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
[void]$cmbDrive.Items.AddRange(@('A','B','0','1','2'))
$tip.SetToolTip($cmbDrive, (T "A/B = bus IBM-PC (nappe avec twist) - typiquement le lecteur PC`n0/1/2 = bus Shugart (nappe droite) - typiquement le lecteur Amiga"))

$txtDev = New-Object System.Windows.Forms.TextBox
$txtDev.Location = '652,34'; $txtDev.Width = 50; $txtDev.Anchor = 'Top,Right'
$tip.SetToolTip($txtDev, (T 'Port COM du Greaseweazle. Vide = détection automatique.'))

$chkTime = New-Object System.Windows.Forms.CheckBox
$chkTime.Text = '--time'; $chkTime.Location = '712,35'; $chkTime.Width = 70; $chkTime.Anchor = 'Top,Right'
$chkTime.BackColor = [System.Drawing.Color]::Transparent; $chkTime.ForeColor = [System.Drawing.Color]::White
$tip.SetToolTip($chkTime, (T 'Affiche le temps écoulé après chaque commande gw.'))

$pnlTop.Controls.AddRange(@($lblGwStatus, (New-BannerLabel (T 'Lecteur :') '500,37'), $cmbDrive,
    (New-BannerLabel (T 'COM :') '612,37'), $txtDev, $chkTime))

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

$btnLibToWrite = New-Object System.Windows.Forms.Button
$btnLibToWrite.Text = (T 'Envoyer vers Écriture'); $btnLibToWrite.Location = '465,213'; $btnLibToWrite.Size = '313,38'; $btnLibToWrite.Font = $bold
$btnLibToWrite.Anchor = 'Bottom,Right'; $btnLibToWrite.Enabled = $false
$btnLibToWrite.Add_Click({
    $sel = Resolve-LibSelection
    if (-not $sel) { return }
    if (-not $sel.IsImage) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Ce fichier n''est pas un format image reconnu par gw.'),(T 'Type non pris en charge'),'OK','Information'); return
    }
    $txtWFile.Text = $sel.Path
    if ($sel.Path -match '\.adf$') { $cmbWFmt.SelectedItem = 'amiga.amigados' } else { $cmbWFmt.SelectedIndex = 0 }
    Append-Log ((T "Image sélectionnée : {0}") -f "$($sel.Path)")
    Update-PrecompForImage $sel.Path
    $tabs.SelectedTab = $tabW
})

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
    $treeLib, $txtLibInfo, $btnLibToWrite, $btnLibOpen, $btnLibExplore))

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
$tip.SetToolTip($cmbWProfile, (T "Auto : la cellule de l'image est mesurée (IPF : bits par piste ; SCP : flux ; HFE : débit)`net le profil --precomp correspondant est appliqué.`nManuel : le champ --precomp n'est jamais modifié."))
$cmbWProfile.Add_SelectedIndexChanged({ Update-PrecompForImage $txtWFile.Text })

$btnWFile.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Filter = (T 'Images disquette|*.ipf;*.adf;*.scp;*.hfe;*.img;*.st;*.dsk;*.raw;*.d64;*.imd|Tous|*.*')
    if ($txtWFile.Text) { $p = Split-Path -Parent $txtWFile.Text; if ($p -and (Test-Path -LiteralPath $p)) { $d.InitialDirectory = $p } }
    if ($d.ShowDialog() -eq 'OK') {
        $txtWFile.Text = $d.FileName
        if ($d.FileName -match '\.adf$') { $cmbWFmt.SelectedItem = 'amiga.amigados' } else { $cmbWFmt.SelectedIndex = 0 }
        Update-PrecompForImage $d.FileName
    }
})
$txtWFile.Add_Leave({ Update-PrecompForImage $txtWFile.Text })

$grpWImage.Controls.AddRange(@((New-Label (T 'Image :') '12,23'), $txtWFile, $btnWFile,
    (New-Label (T 'Format :') '12,55'), $cmbWFmt, (New-Label (T 'Profil précomp. :') '320,55'), $cmbWProfile))

# --- Groupe 2 : options d'ecriture courantes
$grpWOpt = New-Group (T 'Options d''écriture') '10,98' '762,134'

$chkWPreErase = New-Object System.Windows.Forms.CheckBox
$chkWPreErase.Text = (T 'Pré-effacer chaque piste'); $chkWPreErase.Location = '12,24'; $chkWPreErase.Width = 170
$tip.SetToolTip($chkWPreErase, (T '--pre-erase : efface la piste juste avant de l''écrire. Recommandé sur une disquette déjà utilisée.'))
$chkWEraseEmpty = New-Object System.Windows.Forms.CheckBox
$chkWEraseEmpty.Text = (T 'Effacer les pistes vides'); $chkWEraseEmpty.Location = '190,24'; $chkWEraseEmpty.Width = 165
$tip.SetToolTip($chkWEraseEmpty, (T '--erase-empty : efface les pistes vides de l''image au lieu de les sauter. Supprime les résidus de l''ancien contenu.'))
$chkWNoVerify = New-Object System.Windows.Forms.CheckBox
$chkWNoVerify.Text = (T 'Sans vérification'); $chkWNoVerify.Location = '365,24'; $chkWNoVerify.Width = 130
$tip.SetToolTip($chkWNoVerify, (T '--no-verify : DÉCONSEILLÉ. Supprime la relecture de contrôle de chaque piste.'))

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

$chkWPostCheck = New-Object System.Windows.Forms.CheckBox
$chkWPostCheck.Text = (T 'Mesurer la disquette après l''écriture'); $chkWPostCheck.Location = '500,50'; $chkWPostCheck.Width = 255
$tip.SetToolTip($chkWPostCheck, (T "Après une écriture réussie, relit la disquette et évalue l'état du support :`nles pistes qui ont nécessité des retries à l'écriture sont relues en priorité,`nplus un échantillon de contrôle (cylindres 0, 40, 79). Résultat dans l'onglet Qualité & alignement."))

# --- Ligne 3 : calibration automatique de la precompensation pour le lecteur d ecriture
$cmbWCalMode = New-Object System.Windows.Forms.ComboBox
$cmbWCalMode.Location = '165,77'; $cmbWCalMode.Width = 250; $cmbWCalMode.DropDownStyle = 'DropDownList'
[void]$cmbWCalMode.Items.AddRange(@((T 'Test standard : 1 cylindre sur 10'), (T 'Test fin : tous les cylindres')))
$cmbWCalMode.SelectedIndex = 0
$btnWCalib = New-Object System.Windows.Forms.Button
$btnWCalib.Text = (T 'Calibrer'); $btnWCalib.Location = '425,76'; $btnWCalib.Size = '120,26'
$tip.SetToolTip($btnWCalib, (T "Calibre la précompensation pour ce lecteur d'écriture : chaque passe écrit les cylindres de test de l'image avec une valeur de precomp, les relit en flux et note le placement des transitions. La meilleure valeur par cylindre forme le profil, enregistré pour la famille de l'image (standard ou long track) et appliqué ensuite par le mode Auto. La disquette insérée est écrasée. Test standard : un cylindre sur 10, quelques minutes. Test fin : tous les cylindres, environ une heure."))
$btnWCalib.Add_Click({ Start-PrecompCalib })

# --- Ligne 4 : progression globale de la calibration (toutes passes), visible pendant et apres
$pbWCal = New-Object System.Windows.Forms.ProgressBar
$pbWCal.Location = '12,108'; $pbWCal.Size = '300,16'; $pbWCal.Minimum = 0; $pbWCal.Maximum = 100; $pbWCal.Visible = $false
$lblWCal = New-Object System.Windows.Forms.Label
$lblWCal.Location = '320,109'; $lblWCal.AutoSize = $true; $lblWCal.ForeColor = 'DimGray'; $lblWCal.Visible = $false

$grpWOpt.Controls.AddRange(@($chkWPreErase, $chkWEraseEmpty, $chkWNoVerify, (New-Label (T 'Retries :') '500,26'), $numWRetries, $chkWPrecomp, $txtWPrecomp, $chkWPostCheck,
    (New-Label (T 'Calibration précomp :') '12,81'), $cmbWCalMode, $btnWCalib, $pbWCal, $lblWCal))

# --- Groupe 3 : options avancees (rarement utiles)
$grpWAdv = New-Group (T 'Options avancées') '10,238' '762,74'

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
$btnWrite.Text = (T 'ÉCRIRE LA DISQUETTE'); $btnWrite.Location = '10,320'; $btnWrite.Size = '250,40'; $btnWrite.Font = $bold
# Options "comment ecrire" communes a l ecriture et a la calibration precomp
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

$btnWrite.Add_Click({
    if (-not (Test-Path -LiteralPath $txtWFile.Text)) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Fichier image introuvable.'),(T 'Erreur'),'OK','Warning'); return
    }
    $a = @('write') + (Get-CommonArgs)
    if ($chkWPreErase.Checked)   { $a += '--pre-erase' }
    if ($chkWEraseEmpty.Checked) { $a += '--erase-empty' }
    if ($chkWNoVerify.Checked)   { $a += '--no-verify' }
    $a += "--retries=$($numWRetries.Value)"
    if ($chkWPrecomp.Checked -and $txtWPrecomp.Text.Trim()) { $a += '--precomp'; $a += $txtWPrecomp.Text.Trim() }
    $a += Get-WriteFormatArgs
    if ($txtWTracks.Text.Trim())      { $a += "--tracks=$($txtWTracks.Text.Trim())" }
    $a += "`"$($txtWFile.Text)`""
    if ($chkWPostCheck.Checked) {
        $script:WriteArgs = $a
        $script:Chain.Clear()
        $script:Chain.Enqueue({ Start-Gw $script:WriteArgs })
        $script:Chain.Enqueue({ Start-PostWriteCheck })
        Invoke-NextChainStep
    } else {
        Start-Gw $a
    }
})

$lblWProfileInfo = New-Object System.Windows.Forms.Label
$lblWProfileInfo.Location = '270,320'; $lblWProfileInfo.Size = '502,40'; $lblWProfileInfo.Anchor = 'Top,Left,Right'
$lblWProfileInfo.ForeColor = 'DimGray'; $lblWProfileInfo.Text = (T 'Choisis une image : le format et la précompensation seront déduits automatiquement.')

$tabW.Controls.AddRange(@($grpWImage, $grpWOpt, $grpWAdv, $btnWrite, $lblWProfileInfo))

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
$chkRRaw.Text = (T '--raw (cumuler le flux entre les retries)'); $chkRRaw.Location = '90,105'; $chkRRaw.Width = 290
$chkRRev = New-Object System.Windows.Forms.CheckBox
$chkRRev.Text = '--reverse'; $chkRRev.Location = '390,105'; $chkRRev.Width = 100

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
        [void][System.Windows.Forms.MessageBox]::Show((T 'Indique un fichier de sortie.'),(T 'Erreur'),'OK','Warning'); return
    }
    $a = @('read') + (Get-CommonArgs)
    $a += "--revs=$($numRevs.Value)"
    $a += "--retries=$($numRRetries.Value)"
    if ($chkRRaw.Checked) { $a += '--raw' }
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
    (New-Label (T 'Révolutions :') '10,77'), $numRevs,
    (New-Label (T 'Retries :') '190,77'), $numRRetries,
    (New-Label (T 'Tracks :') '355,77'), $txtRTracks,
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
        [void][System.Windows.Forms.MessageBox]::Show((T 'Indique un fichier de destination.'),(T 'Erreur'),'OK','Warning'); return
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
    (New-Label (T 'Tracks :') '355,78'), $txtCvTracks, $btnConvert))

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
    (New-Label (T 'Format :') '10,47'), $cmbCmpFmt, (New-Label (T 'Retries :') '305,47'), $numCmpRetries, $btnCmpFromWrite,
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
    if (-not $script:AlignLast) { [void][System.Windows.Forms.MessageBox]::Show((T 'Fais d''abord une mesure.'),(T 'Référence'),'OK','Information'); return }
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
    $lblAlRef.Text = (T 'Aucune référence'); $lblAlHealth.Text = (T 'Lance une mesure'); $lblAlHealth.BackColor = [System.Drawing.SystemColors]::Control
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
$lblAlHealth.Text = (T 'Lance une mesure')
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
$tip.SetToolTip($lvAl, (T "État par piste : SAIN / À SURVEILLER / CRITIQUE (erreurs, trous, stabilité, jitter).`nSeuils jitter : <60 / <120 / <200 ns. Asymétrie : <0,02 / <0,05 / <0,10."))

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

$btnInfo  = New-ToolButton (T 'Info périphérique')        '15,15'  { Start-Gw @('info') }
$btnRpm   = New-ToolButton (T 'Mesurer la vitesse (rpm)') '15,52'  { Start-Gw (@('rpm') + (Get-CommonArgs)) }
$btnBw    = New-ToolButton (T 'Bande passante USB')       '15,89'  { Start-Gw @('bandwidth') }
$btnReset = New-ToolButton (T 'Reset du périphérique')    '15,126' { Start-Gw @('reset') }

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
$btnClean.Add_Click({
    $r = [System.Windows.Forms.MessageBox]::Show(
        (T "Insère une DISQUETTE DE NETTOYAGE (jamais une disquette de données) puis valide."),
        (T 'Nettoyage des têtes'), 'OKCancel', 'Information')
    if ($r -eq 'OK') {
        Start-Gw (@('clean') + (Get-CommonArgs) + @("--passes=$($numPasses.Value)", "--linger=$($numLinger.Value)"))
    }
})

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
        [void][System.Windows.Forms.MessageBox]::Show((T 'Coche au moins un paramètre à modifier.'),(T 'Rien à faire'),'OK','Information'); return
    }
    Start-Gw $a
})

$lblDelayNote = New-Object System.Windows.Forms.Label
$lblDelayNote.Text = (T "Valeurs pré-remplies = défauts usine, à titre indicatif.`n") +
                     (T "Coche une case pour transmettre le paramètre à gw.`n`n") +
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

$tabs.TabPages.AddRange(@($tabL,$tabW,$tabR,$tabCv,$tabCmp,$tabAl,$tabT,$tabD,$tabC))
$split.Panel1.Controls.Add($tabs)

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
    if ($script:GwProc -and -not $script:GwProc.HasExited) {
        try { $script:GwProc.Kill($true) } catch { try { $script:GwProc.Kill() } catch { } }
        $script:Chain.Clear()
        $script:PostWriteMode = $false
        if ($script:Cal) { Stop-PrecompCalib }
        Append-Log (T '*** Interrompu par l''utilisateur ***')
    }
    if ($script:AlignLoop) { $script:AlignLoop = $false; $script:AlignNextAt = $null; Append-Log (T 'Mesure continue arrêtée.') }
})

$btnLogToggle = New-BarButton (T 'Masquer journal') 140
$btnLogToggle.Add_Click({ Set-LogVisible ($split.Panel2Collapsed) })

$btnClear = New-BarButton (T 'Effacer') 95
$btnClear.Add_Click({ $txtLog.Clear() })

$btnSaveLog = New-BarButton (T 'Exporter') 100
$btnSaveLog.Add_Click({
    $d = New-Object System.Windows.Forms.SaveFileDialog
    $d.Filter = (T 'Texte|*.txt'); $d.InitialDirectory = $script:AppDir
    $d.FileName = "gw-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    if ($d.ShowDialog() -eq 'OK') { $txtLog.Text | Set-Content -LiteralPath $d.FileName -Encoding UTF8 }
})

$btnCfgSave = New-BarButton (T 'Paramètres') 115
$btnCfgSave.Add_Click({ if (Save-Config) { Append-Log ((T "Paramètres enregistrés : {0}") -f "$($script:ConfigFile)") } })

$btnCfgReset = New-BarButton (T 'Réinitialiser') 120
$btnCfgReset.Add_Click({
    $r = [System.Windows.Forms.MessageBox]::Show(
        (T "Remettre tous les paramètres de l'interface à leurs valeurs par défaut et supprimer le fichier de configuration ?`n`n(Aucun effet sur le Greaseweazle, ni sur tes fichiers image, ni sur l'index de la bibliothèque.)"),
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

$flowButtons.Controls.AddRange(@($btnStop, $btnLogToggle, $btnClear, $btnSaveLog, $btnCfgSave, $btnCfgReset))

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
foreach ($n in @('Library','Save','Download','Switch','Copy','Diagnostic','Repair','Stopwatch','Cmd')) {
    $imgTabs.Images.Add($n, (New-GlyphBitmap $n 16 $script:Theme.Accent))
}
$tabs.ImageList = $imgTabs
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
Set-Btn $btnLibToWrite 'Save' 'primary'
Set-Btn $btnLibOpen    'OpenFile'
Set-Btn $btnLibExplore 'FolderOpen'
Set-Btn $btnWFile      'FolderOpen' -IconOnly
Set-Btn $btnWDiskdefs  'FolderOpen' -IconOnly
Set-Btn $btnWrite      'Save' 'primary'
Set-Btn $btnWCalib     'Diagnostic'
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
Set-Btn $btnLogToggle  'Page'
Set-Btn $btnClear      'Delete'
Set-Btn $btnSaveLog    'Save'
Set-Btn $btnCfgSave    'Setting'
Set-Btn $btnCfgReset   'Refresh'
$tip.SetToolTip($btnClear,   (T 'Effacer le contenu du journal.'))
$tip.SetToolTip($btnSaveLog, (T 'Exporter le journal dans un fichier texte.'))
$tip.SetToolTip($btnCfgSave, (T 'Enregistrer maintenant tous les paramètres de l''interface.'))
$tip.SetToolTip($btnCfgReset,(T 'Remettre les paramètres de l''interface à leurs valeurs par défaut.'))

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
    $btnLibToWrite.Enabled = $false
    $btnLibOpen.Enabled = $false
    $lblLibCount.Text = ''

    $root = $txtLibRoot.Text
    if (-not $root -or -not (Test-Path -LiteralPath $root)) {
        if ($root) { $lblLibCount.Text = (T 'racine introuvable') }
        $txtLibInfo.Text = (T "Pour commencer :`r`n1. Choisis le dossier racine de tes images (bouton ...).`r`n2. Déplie l'arborescence ou utilise la recherche.`r`n3. Sélectionne une image puis « Envoyer vers Écriture ».")
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
    $btnLibToWrite.Enabled = $false
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
            $btnLibToWrite.Enabled = ($t.FileKind -eq 'image')
            $btnLibOpen.Enabled    = ($t.FileKind -eq 'doc')
        }
        'image' {
            $lines += ((T "Image disquette ({0})") -f "$([System.IO.Path]::GetExtension($t.Path))")
            $lines += ((T "Taille : {0}") -f "$(Format-Size $t.Size)")
            $lines += $t.Path
            $btnLibToWrite.Enabled = $true
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
    $n = $treeLib.SelectedNode
    if (-not $n -or -not $n.Tag) { return $null }
    $t = $n.Tag
    if ($t.Kind -eq 'zipentry') {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        try {
            $p = Expand-ZipEntry $t.ZipPath $t.Entry
            Append-Log ((T "Extrait : {0} -> {1}") -f "$($t.Entry)", "$p")
            return @{ Path = $p; IsImage = ($t.FileKind -eq 'image') }
        } catch {
            Append-Log ((T "Extraction impossible : {0}") -f "$($_.Exception.Message)")
            return $null
        } finally { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
    }
    if ($t.Kind -eq 'image' -or $t.Kind -eq 'doc' -or $t.Kind -eq 'other') {
        return @{ Path = $t.Path; IsImage = ($t.Kind -eq 'image') }
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
        $script:Chain.Clear()
        Append-Log ((T "ERREUR étape : {0}") -f "$($_.Exception.Message)")
        if ($txtCmpResult.Text -like ((T 'Comparaison en cours') + '*')) { $txtCmpResult.Text = ((T "ÉCHEC : {0}") -f "$($_.Exception.Message)") }
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
        [void][System.Windows.Forms.MessageBox]::Show((T 'Choisis un format de décodage.'),(T 'Erreur'),'OK','Warning'); return
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
        $tabs.SelectedTab = $tabCmp
    } catch {
        $txtCmpResult.Text = ((T "ERREUR pendant la comparaison : {0}") -f "$($_.Exception.Message)")
        Append-Log ((T "Comparaison : erreur {0}") -f "$($_.Exception.Message)")
    } finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

# ============================== ALIGNEMENT : LOGIQUE ===========================
function Read-ScpFile([string]$path) {
    $d = [System.IO.File]::ReadAllBytes($path)
    if ([System.Text.Encoding]::ASCII.GetString($d, 0, 3) -ne 'SCP') { throw (T 'Fichier SCP invalide') }
    $revs = $d[5]; $res = ($d[11] + 1) * 25
    $tracks = @{}
    for ($t = 0; $t -lt 168; $t++) {
        $o = [BitConverter]::ToUInt32($d, 16 + 4 * $t)
        if ($o -eq 0) { continue }
        $tn = $d[$o + 3]; $list = @()
        for ($r = 0; $r -lt $revs; $r++) {
            $idx  = [BitConverter]::ToUInt32($d, $o + 4 + 12 * $r)
            $ln   = [BitConverter]::ToUInt32($d, $o + 8 + 12 * $r)
            $doff = [BitConverter]::ToUInt32($d, $o + 12 + 12 * $r)
            $flux = [ScpStats]::Decode($d, [int]($o + $doff), [int]$ln, $res)
            $list += [ScpStats]::Analyze($flux, [double]$idx * $res)
        }
        $tracks[[int]$tn] = $list
    }
    return $tracks
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
        [void][System.Windows.Forms.MessageBox]::Show((T 'Indique au moins un cylindre valide (0-83).'),(T 'Alignement'),'OK','Warning')
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
        'jitter' { if ($v -lt 60)  { 0 } elseif ($v -lt 120) { 1 } elseif ($v -lt 200) { 2 } else { 3 } }
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
            $txt = ((T "Position 0 mesurée (score {0}). Tourne le stepper d'UN PETIT cran dans un sens, puis clique le bouton correspondant.") -f "$([math]::Round($avg,0))")
            $color = 'RoyalBlue'
        } else {
            $txt = ((T "Position {0} re-mesurée. Meilleure position connue : {1}.") -f "$pos", "$bestPos")
            if ($pos -ne $bestPos) { $txt += ((T " Reviens de {0} cran(s) vers le sens {1} pour la retrouver.") -f "$([math]::Abs($pos-$bestPos))", "$($sens[[math]::Sign($bestPos-$pos)])") }
        }
    } else {
        $prev = $pos - $script:AlLastMove
        $prevScore = if ($script:AlPosScores.ContainsKey($prev)) { $script:AlPosScores[$prev] } else { $null }
        if ($null -eq $prevScore) {
            $txt = ((T "Position {0} mesurée. Pas de mesure à la position précédente : impossible de conclure, continue.") -f "$pos")
        } elseif ($avg -lt $prevScore * 0.97) {
            $txt = ((T "AMÉLIORATION ({0} -> {1}) : CONTINUE dans le sens {2}, encore un cran, puis mesure.") -f "$([math]::Round($prevScore,0))", "$([math]::Round($avg,0))", "$($sens[$script:AlLastMove])")
            $color = 'Green'
        } elseif ($avg -gt $prevScore * 1.03) {
            # le pas precedent etait-il un optimum (moins bon des deux cotes) ?
            $other = $prev - $script:AlLastMove
            $otherWorse = $script:AlPosScores.ContainsKey($other) -and ($script:AlPosScores[$other] -gt $prevScore * 1.03)
            if ($otherWorse -and $prev -eq $bestPos) {
                $txt = ((T "OPTIMUM TROUVÉ à la position {0} (score {1}) : RECULE d'un cran (sens {2}), resserre les vis, re-mesure pour contrôle.") -f "$prev", "$([math]::Round($prevScore,0))", "$($sens[-$script:AlLastMove])")
                $color = 'DarkGreen'
            } else {
                $txt = ((T "DÉGRADATION ({0} -> {1}) : RECULE d'un cran (sens {2}) pour revenir à la position {3}, puis essaie l'autre sens.") -f "$([math]::Round($prevScore,0))", "$([math]::Round($avg,0))", "$($sens[-$script:AlLastMove])", "$prev")
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

function Get-HealthLevel([double]$err, [double]$drop, [double]$stab, [double]$jit) {
    if ($err -le 3 -and $drop -le 0 -and $stab -le 2 -and $jit -lt 120) { return 0 }
    if ($err -le 20 -and $drop -le 1 -and $stab -le 10 -and $jit -lt 250) { return 1 }
    return 2
}

function Invoke-AlignAnalysis {
    if (-not $script:AlignTmp -or -not (Test-Path -LiteralPath $script:AlignTmp)) {
        Append-Log (T 'Mesure : fichier SCP absent, analyse impossible.'); $script:AlignLoop = $false; return
    }
    try { $tracks = Read-ScpFile $script:AlignTmp } catch { Append-Log ((T "Mesure : {0}") -f "$($_.Exception.Message)"); $script:AlignLoop = $false; return }

    $healthNames = @{ 0=(T 'SAIN'); 1=(T 'À SURVEILLER'); 2=(T 'CRITIQUE') }
    $healthColor = @{ 0=$script:AlColors[0]; 1=$script:AlColors[2]; 2=$script:AlColors[3] }
    $last = @{}; $watch = @(); $crit = @(); $hardTracks = @()
    $lvAl.BeginUpdate()
    try {
        $lvAl.Items.Clear()
        $total = 0.0; $count = 0
        foreach ($tn in ($tracks.Keys | Sort-Object)) {
            $st = $tracks[$tn]; $cyl = [math]::Floor($tn / 2); $hd = $tn % 2; $key = "$cyl.$hd"
            $lab = "$cyl.$hd"
            $bad = $false
            foreach ($x in $st) { if ([double]::IsNaN($x.Jitter)) { $bad = $true } }
            $it = New-Object System.Windows.Forms.ListViewItem($lab)
            $it.UseItemStyleForSubItems = $false
            if ($bad) {
                foreach ($v in @((T 'ILLISIBLE'),'-','-','-','-','-','-','-','-')) { [void]$it.SubItems.Add([string]$v) }
                $it.SubItems[1].BackColor = $script:AlColors[3]; $it.SubItems[1].ForeColor = [System.Drawing.Color]::White; $it.SubItems[1].Font = $bold
                [void]$lvAl.Items.Add($it)
                $last[$key] = @{ Score = 9999; Jitter = 0; Asym = 0; Err = 0; Stab = 0; Cell = 0 }
                $crit += ((T "{0} (illisible)") -f "$lab"); continue
            }
            $j   = ($st | Measure-Object -Property Jitter -Average).Average
            $r3  = ($st | Measure-Object -Property R3 -Average).Average
            $r4  = ($st | Measure-Object -Property R4 -Average).Average
            $ooc = ($st | Measure-Object -Property OutOfClass -Average).Average
            $dr  = ($st | Measure-Object -Property Dropouts -Average).Average
            $cell= ($st | Measure-Object -Property Cell -Average).Average
            $nf  = $st | ForEach-Object { $_.NFlux }
            $stab= ($nf | Measure-Object -Maximum).Maximum - ($nf | Measure-Object -Minimum).Minimum
            $asym= [math]::Abs($r3 - 1.5) + [math]::Abs($r4 - 2.0)
            $sc  = [math]::Round($j + 2000 * $asym + 5 * $ooc + 50 * $dr + $stab, 0)
            if (-not $script:AlignBest.ContainsKey($key) -or $sc -lt $script:AlignBest[$key]) { $script:AlignBest[$key] = $sc }
            $last[$key] = @{ Score = $sc; Jitter = $j; Asym = $asym; Err = $ooc; Stab = $stab; Cell = $cell }
            $hl = Get-HealthLevel $ooc $dr $stab $j
            if ($hl -eq 1) { $watch += $lab } elseif ($hl -eq 2) { $crit += ((T "{0} ({1} err/tour)") -f "$lab", "$([math]::Round($ooc,0))") }
            $retryMark = ''
            if ($script:PostWriteMode -and $script:WriteRetries.ContainsKey($key)) { $retryMark = ((T " (retries x{0})") -f "$($script:WriteRetries[$key])"); $hardTracks += @{ Key = $key; Level = $hl } }

            $delta = '-'; $deltaLvl = -1
            if ($script:AlignRef -and $script:AlignRef.ContainsKey($key) -and $script:AlignRef[$key].Score -gt 0) {
                $pct = ($sc - $script:AlignRef[$key].Score) / $script:AlignRef[$key].Score * 100
                $delta = ('{0:+0;-0;0} %' -f $pct); $deltaLvl = Get-AlLevel 'delta' $pct
            }
            foreach ($v in @(($healthNames[$hl] + $retryMark), ('{0:N1}' -f $ooc), ('{0:N1}' -f $dr), [string]$stab, ('{0:N0}' -f $j), ('{0:N0}' -f $sc), $delta, ('{0:N3}' -f $asym), ('{0:N0}' -f $cell))) { [void]$it.SubItems.Add($v) }
            $it.SubItems[1].BackColor = $healthColor[$hl]; $it.SubItems[1].ForeColor = $script:AlFg[$(@{0=0;1=2;2=3}[$hl])]
            $it.SubItems[1].Font = $bold
            $lvErr = Get-AlLevel 'err' $ooc;    $it.SubItems[2].BackColor = $script:AlColors[$lvErr];  $it.SubItems[2].ForeColor = $script:AlFg[$lvErr]
            $lvDr  = $(if ($dr -le 0) { 0 } elseif ($dr -le 1) { 2 } else { 3 }); $it.SubItems[3].BackColor = $script:AlColors[$lvDr]; $it.SubItems[3].ForeColor = $script:AlFg[$lvDr]
            $lvStb = Get-AlLevel 'stab' $stab;  $it.SubItems[4].BackColor = $script:AlColors[$lvStb];  $it.SubItems[4].ForeColor = $script:AlFg[$lvStb]
            $lvJit = Get-AlLevel 'jitter' $j;   $it.SubItems[5].BackColor = $script:AlColors[$lvJit];  $it.SubItems[5].ForeColor = $script:AlFg[$lvJit]
            $lvSc  = Get-AlLevel 'score' $sc;   $it.SubItems[6].BackColor = $script:AlColors[$lvSc];   $it.SubItems[6].ForeColor = $script:AlFg[$lvSc]
            if ($deltaLvl -ge 0) { $it.SubItems[7].BackColor = $script:AlColors[$deltaLvl]; $it.SubItems[7].ForeColor = $script:AlFg[$deltaLvl] }
            $lvAs  = Get-AlLevel 'asym' $asym;  $it.SubItems[8].BackColor = $script:AlColors[$lvAs];   $it.SubItems[8].ForeColor = $script:AlFg[$lvAs]
            [void]$lvAl.Items.Add($it)
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
        if ($script:PostWriteMode) {
            if ($script:WriteRetries.Count -eq 0) {
                $lblAlHealth.Text = (T "CONTRÔLE POST-ÉCRITURE : ") + $lblAlHealth.Text + (T "  (aucun retry à l'écriture)")
            } else {
                $badHard = @($hardTracks | Where-Object { $_.Level -ge 1 } | ForEach-Object { $_.Key })
                if ($badHard.Count -eq 0) {
                    $lblAlHealth.Text = ((T "CONTRÔLE POST-ÉCRITURE : pistes difficiles ({0}) relues SAINES  -  ") -f "$(($hardTracks | ForEach-Object { $_.Key }) -join ', ')") + $lblAlHealth.Text
                } else {
                    $lblAlHealth.Text = ((T "CONTRÔLE POST-ÉCRITURE : pistes difficiles encore marginales : {0}  ->  réécrire sur un autre support") -f "$($badHard -join ', ')")
                    $lblAlHealth.BackColor = $script:AlColors[3]; $lblAlHealth.ForeColor = $script:AlFg[3]
                }
            }
            $script:PostWriteMode = $false
        }
        Append-Log ((T "Mesure : {0}") -f "$($lblAlHealth.Text)")

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
    $fs = [System.IO.File]::OpenRead($path)
    try { $h = New-Object byte[] 32; [void]$fs.Read($h, 0, 32) } finally { $fs.Dispose() }
    if ([System.Text.Encoding]::ASCII.GetString($h, 0, 8) -notmatch '^HXCPICFE|^HXCHFEV3') { throw (T 'Signature HFE absente') }
    $rate = [BitConverter]::ToUInt16($h, 24)
    if ($rate -le 0) { throw (T 'Débit HFE nul') }
    return @{ CellNs = [double](500000.0 / $rate); Bits = [int64](200000000.0 / (500000.0 / $rate)); Tracks = -1; DosTracks = -1; Source = ((T "HFE (débit {0} kbit/s)") -f "$rate") }
}

function Update-PrecompForImage([string]$path) {
    $mode = $cmbWProfile.Text
    if ($mode -eq (T 'Manuel')) { $lblWProfileInfo.Text = (T 'Profil manuel : --precomp non modifié.'); return }
    if ($mode -eq (T 'Standard 2 us'))      { $txtWPrecomp.Text = $script:PrecompStd;  $chkWPrecomp.Checked = $true; $lblWProfileInfo.Text = ((T "Profil forcé : standard 2 us ({0})") -f "$($script:PrecompStd)"); return }
    if ($mode -eq (T 'Long track 1,89 us')) { $txtWPrecomp.Text = $script:PrecompLong; $chkWPrecomp.Checked = $true; $lblWProfileInfo.Text = ((T "Profil forcé : long track ({0})") -f "$($script:PrecompLong)"); return }
    # Auto
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { $lblWProfileInfo.Text = ''; return }
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
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
        $txtWPrecomp.Text = $script:PrecompStd; $chkWPrecomp.Checked = $true
        $lblWProfileInfo.Text = ((T "Auto : image secteur ({0}) -> standard 2 us ({1})") -f "$ext", "$($script:PrecompStd)")
        return
    }
    $long = $info.CellNs -lt $script:PrecompThresholdNs
    $txtWPrecomp.Text = if ($long) { $script:PrecompLong } else { $script:PrecompStd }
    $chkWPrecomp.Checked = $true
    $detail = ((T "cellule {0} ns, {1} bits/piste") -f "$([math]::Round($info.CellNs,0))", "$($info.Bits)")
    if ($info.DosTracks -ge 0 -and $info.Tracks -gt 0) { $detail += ((T ", {0}/{1} pistes DOS") -f "$($info.DosTracks)", "$($info.Tracks)") }
    $lblWProfileInfo.Text = ((T "Auto : {0} : {1} -> ") -f "$($info.Source)", "$detail") + $(if ($long) { ((T "LONG TRACK ({0})") -f "$($script:PrecompLong)") } else { ((T "standard 2 us ({0})") -f "$($script:PrecompStd)") })
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
# Profil : valeurs lissees croissantes vers l interieur, arrondies a 5 ns, seuils c=ns.
# Le profil remplace celui de la famille de l image (standard 2 us / long track) et est
# enregistre dans la configuration : le mode Auto l applique ensuite.
# Test standard : un cylindre sur 10 plus le dernier ; test fin : tous les cylindres.
# Cylindres deduits de l image (ADF, IPF, HFE), 80 par defaut. gw n applique la precomp
# qu aux pistes a bits (images secteur ou bitcell), jamais aux flux SCP/RAW.
$script:Cal = $null
$script:CalCoarse    = @(0, 100, 200)   # passes de mesure : trois points pour la droite
$script:CalMaxNs     = 300              # borne haute d une valeur de precomp
$script:CalResidual  = 4.0              # residu (ns) au-dela duquel un cylindre est corrige
$script:CalMaxVerify = 2                # passes de verification au plus

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

function Get-CalibTrackShift($st) {
    # Decalage de pic residuel moyen (ns) sur les tours ou il est mesurable ; NaN sinon
    $vals = @()
    foreach ($x in $st) { if (-not [double]::IsNaN($x.Shift)) { $vals += [double]$x.Shift } }
    if ($vals.Count -eq 0) { return [double]::NaN }
    return ($vals | Measure-Object -Average).Average
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

function Build-CalibProfile([hashtable]$est) {
    # Estimation par cylindre (ns, reels) -> profil c=ns : lissage croissant (pool adjacent violators,
    # la precomp necessaire ne diminue pas vers l interieur), arrondi a 5 ns, une entree par changement.
    $xs = @($est.Keys | Sort-Object); $ys = @($xs | ForEach-Object { [double]$est[$_] })
    if ($xs.Count -eq 0) { return '' }
    $blocks = New-Object System.Collections.Generic.List[object]
    foreach ($y in $ys) {
        $blocks.Add(@{ Sum = [double]$y; Count = 1 })
        while ($blocks.Count -ge 2) {
            $a = $blocks[$blocks.Count - 2]; $b = $blocks[$blocks.Count - 1]
            if ($a.Sum / $a.Count -le $b.Sum / $b.Count) { break }
            $blocks.RemoveAt($blocks.Count - 1); $blocks.RemoveAt($blocks.Count - 1)
            $blocks.Add(@{ Sum = $a.Sum + $b.Sum; Count = $a.Count + $b.Count })
        }
    }
    $smooth = @()
    foreach ($b in $blocks) {
        $m = [int]([math]::Round($b.Sum / $b.Count / 5.0, 0) * 5)
        $m = [math]::Max(0, [math]::Min($script:CalMaxNs, $m))
        for ($k = 0; $k -lt $b.Count; $k++) { $smooth += $m }
    }
    $parts = @(); $prev = $null
    for ($i = 0; $i -lt $xs.Count; $i++) {
        if ($null -eq $prev -or $smooth[$i] -ne $prev) { $parts += "$($xs[$i])=$($smooth[$i])"; $prev = $smooth[$i] }
    }
    if ([int]$xs[0] -ne 0) { $parts[0] = "0=$($smooth[0])" }
    return ($parts -join ':')
}

function Start-PrecompCalib {
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    $script:Cal = $null
    if (-not $script:ScpStatsOk) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Calibration : module d''analyse SCP indisponible (Add-Type).'),(T 'Calibration precomp'),'OK','Warning'); return
    }
    if (-not (Test-Path -LiteralPath $script:GwExe)) {
        [void][System.Windows.Forms.MessageBox]::Show(((T "gw.exe introuvable : {0}`n`nPlace ce script dans le même répertoire que gw.exe.") -f "$($script:GwExe)"),(T 'Erreur'),'OK','Error'); return
    }
    $img = $txtWFile.Text
    if (-not $img -or -not (Test-Path -LiteralPath $img)) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Choisis d''abord l''image à écrire : ses pistes servent de motif de test.'),(T 'Calibration precomp'),'OK','Warning'); return
    }
    $ext = [System.IO.Path]::GetExtension($img).ToLower()
    if (@('.scp', '.raw', '.kf', '.a2r', '.ctr') -contains $ext) {
        [void][System.Windows.Forms.MessageBox]::Show(((T "Calibration impossible sur un flux ({0}) : gw n'applique la précompensation qu'aux images à bits ou secteurs (ADF, IPF, HFE, IMG...).") -f "$ext"),(T 'Calibration precomp'),'OK','Warning'); return
    }
    $family = Get-ImageFamily $img
    $nCyl = Get-ImageCylinders $img
    $cylSrc = if ($null -ne $nCyl) { ((T "{0} cylindres d'après l'image") -f "$nCyl") } else { (T '80 cylindres par défaut (nombre non lisible dans l''image)') }
    if ($null -eq $nCyl) { $nCyl = 80 }
    $nCyl = [math]::Max(2, [math]::Min(84, [int]$nCyl))
    $maxCyl = $nCyl - 1
    $fine = ($cmbWCalMode.SelectedIndex -eq 1)
    if ($fine) { $cyls = @(0..$maxCyl) }
    else { $cyls = @(0..$maxCyl | Where-Object { $_ % 10 -eq 0 }); if ($cyls -notcontains $maxCyl) { $cyls += $maxCyl } }
    $cyls = @($cyls | Sort-Object -Unique)
    $nPassEst = $script:CalCoarse.Count + $script:CalMaxVerify
    $minutes = [math]::Max(1, [math]::Round($cyls.Count * 2 * 1.4 * $nPassEst / 60, 0))
    $modeTxt = if ($fine) { (T 'test fin, tous les cylindres') } else { (T 'test standard, un cylindre sur 10') }
    $famTxt = Get-CalibFamilyName $family
    $cylList = Format-CylList $cyls
    $r = [System.Windows.Forms.MessageBox]::Show(
        ((T "Calibration de la précompensation sur le lecteur {0} ({1}).`n`nImage : {2}, famille {3}, {4}.`nCylindres de test : {5} (2 faces), ÉCRASÉS à chaque passe. Durée estimée : {6} min pour {7} passes.`n`nInsère une disquette vierge ou sans valeur, puis confirme.") -f "$($cmbDrive.Text)", "$modeTxt", "$([System.IO.Path]::GetFileName($img))", "$famTxt", "$cylSrc", "$cylList", "$minutes", "$nPassEst"),
        (T 'Calibration precomp'), 'OKCancel', 'Warning')
    if ($r -ne 'OK') { return }
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $script:Cal = @{
        Mode = $(if ($fine) { 'fine' } else { 'std' }); Cyls = $cyls; MaxCyl = $maxCyl; Family = $family
        Image = $img; Drive = $cmbDrive.Text; TSpec = "c=${cylList}:h=0-1"
        Stage = 'coarse'; Values = @($script:CalCoarse); Index = 0; Value = 0; ValueTxt = ''; Spec = ''
        Results = @{}; Est = @{}; Slope = $null; Profile = ''; Verify = @{}; VerifyCount = 0
        Scp = (Join-Path $script:TempDir 'precomp-calib.scp'); WriteArgs = @(); ReadArgs = @()
        # Progression globale : passes faites / prevues, durees mesurees par phase, estimation initiale 0,7 s par piste et par phase
        StartTime = (Get-Date); PassStart = (Get-Date); PhaseStart = (Get-Date); Phase = 'write'
        PassesDone = 0; TotalPasses = $nPassEst; WriteDurs = @(); ReadDurs = @(); EstTrack = 0.7
    }
    foreach ($c in $cyls) { $script:Cal.Results[[int]$c] = @{} }
    Append-Log ((T "=== Calibration precomp : lecteur {0}, image {1} ({2}, {3}) ===") -f "$($cmbDrive.Text)", "$([System.IO.Path]::GetFileName($img))", "$famTxt", "$modeTxt")
    Append-Log ((T "Cylindres de test : {0} ({1})") -f "$cylList", "$cylSrc")
    $pbWCal.Value = 0; $pbWCal.Visible = $true; $lblWCal.Visible = $true
    Update-CalibProgress
    New-CalibPass
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
    $lblWCal.Text = ((T "Calibration : passe {0}/{1}, {2}, {3}  -  {4} %  -  reste environ {5}") -f "$([math]::Min($total, $cal.PassesDone + 1))", "$total", "$($cal.ValueTxt)", "$phaseTxt", "$pct", (Format-CalDuration $remaining))
}

function Stop-PrecompCalib {
    # Abandon (bouton Arreter, erreur gw, fichier manquant) : etat remis a zero, barre masquee
    $script:Cal = $null
    $pbWCal.Visible = $false
    $lblWCal.Text = (T 'Calibration precomp interrompue.')
    Append-Log (T 'Calibration precomp interrompue.')
}

function New-CalibPass {
    $cal = $script:Cal
    if ($cal.Stage -eq 'coarse') {
        $cal.Value = [int]$cal.Values[$cal.Index]; $cal.Spec = "0=$($cal.Value)"; $cal.ValueTxt = "$($cal.Value) ns"
        Append-Log ((T "Calibration : passe de mesure {0}/{1}, precomp {2} ns") -f "$($cal.Index + 1)", "$($cal.Values.Count)", "$($cal.Value)")
    } else {
        $cal.Spec = $cal.Profile; $cal.ValueTxt = (T 'profil')
        Append-Log ((T "Calibration : passe de vérification {0}/{1}, profil {2}") -f "$($cal.VerifyCount)", "$($script:CalMaxVerify)", "$($cal.Profile)")
    }
    if (Test-Path -LiteralPath $cal.Scp) { Remove-Item -LiteralPath $cal.Scp -Force }
    $cal.WriteArgs = @('write') + (Get-CommonArgs) + @('--pre-erase', '--no-verify') + (Get-WriteFormatArgs) + @("--tracks=$($cal.TSpec)", '--precomp', $cal.Spec, "`"$($cal.Image)`"")
    $cal.ReadArgs  = @('read') + (Get-CommonArgs) + @('--revs=3', "--tracks=$($cal.TSpec)", "`"$($cal.Scp)`"")
    $cal.PassStart = Get-Date; $cal.PhaseStart = $cal.PassStart; $cal.Phase = 'write'
    Update-CalibProgress
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw $script:Cal.WriteArgs })
    $script:Chain.Enqueue({
        $script:Cal.WriteDurs += ((Get-Date) - $script:Cal.PhaseStart).TotalSeconds
        $script:Cal.Phase = 'read'; $script:Cal.PhaseStart = Get-Date
        Start-Gw $script:Cal.ReadArgs
    })
    $script:Chain.Enqueue({ Invoke-CalibAnalysis })
    Invoke-NextChainStep
}

function Set-CalibEstimates {
    # Droite decalage = b + a * precomp par cylindre (moindres carres sur les passes de mesure) ;
    # pente mise en commun (mediane) pour les cylindres dont la pente propre n est pas fiable.
    $cal = $script:Cal
    $fits = @{}; $slopes = @()
    foreach ($c in $cal.Cyls) {
        $r = $cal.Results[[int]$c]
        if ($r.Count -lt 2) { continue }
        $xs = @($r.Keys | Sort-Object); $ys = @($xs | ForEach-Object { [double]$r[$_].Shift })
        $mx = ($xs | Measure-Object -Average).Average; $my = ($ys | Measure-Object -Average).Average
        $sxx = 0.0; $sxy = 0.0
        for ($i = 0; $i -lt $xs.Count; $i++) { $sxx += ($xs[$i] - $mx) * ($xs[$i] - $mx); $sxy += ($xs[$i] - $mx) * ($ys[$i] - $my) }
        if ($sxx -le 0) { continue }
        $a = $sxy / $sxx
        $fits[[int]$c] = @{ A = $a; Mx = $mx; My = $my }
        if ($a -lt -0.2) { $slopes += $a }
    }
    if ($fits.Count -eq 0) { Append-Log (T 'Calibration : aucune mesure exploitable pour estimer la précompensation.'); return $false }
    $pooled = $null
    if ($slopes.Count -gt 0) { $s = @($slopes | Sort-Object); $pooled = $s[[int][math]::Floor($s.Count / 2)] }
    $cal.Slope = if ($null -ne $pooled) { $pooled } else { -2.0 }   # -2 : valeur theorique (deux transitions par intervalle)
    $cal.Est = @{}
    foreach ($c in @($fits.Keys)) {
        $f = $fits[$c]
        $a = if ($f.A -lt -0.2) { $f.A } else { $cal.Slope }
        $b = $f.My - $a * $f.Mx
        $v0 = -$b / $a
        $cal.Est[[int]$c] = [math]::Max(0, [math]::Min($script:CalMaxNs, $v0))
    }
    $estTxt = (@($cal.Est.Keys | Sort-Object | ForEach-Object { "c$_=$([math]::Round($cal.Est[$_], 0))" })) -join ' '
    Append-Log ((T "Pente moyenne : {0} ns de décalage par ns de precomp ; estimation par cylindre : {1}") -f "$([math]::Round($cal.Slope, 2))", "$estTxt")
    return $true
}

function Invoke-CalibAnalysis {
    $cal = $script:Cal
    if (-not $cal) { return }
    if (-not (Test-Path -LiteralPath $cal.Scp)) { Append-Log (T 'Calibration : fichier SCP absent, analyse impossible.'); Stop-PrecompCalib; return }
    try { $tracks = Read-ScpFile $cal.Scp } catch { Append-Log ((T "Calibration : {0}") -f "$($_.Exception.Message)"); Stop-PrecompCalib; return }
    $cal.ReadDurs += ((Get-Date) - $cal.PhaseStart).TotalSeconds
    $cal.PassesDone++
    $shifts = @(); $scores = @(); $bad = @()
    foreach ($c in $cal.Cyls) {
        $sv = @(); $jv = @()
        foreach ($h in 0, 1) {
            $tn = [int]$c * 2 + $h
            if (-not $tracks.ContainsKey($tn)) { continue }
            $s = Get-CalibTrackShift $tracks[$tn]; if (-not [double]::IsNaN($s)) { $sv += $s }
            $j = Get-CalibTrackScore $tracks[$tn]; if ($j -lt 9999) { $jv += $j }
        }
        if ($sv.Count -eq 0) { $bad += $c; continue }
        $sh = ($sv | Measure-Object -Average).Average
        $jt = if ($jv.Count -gt 0) { ($jv | Measure-Object -Average).Average } else { [double]::NaN }
        if ($cal.Stage -eq 'coarse') { $cal.Results[[int]$c][[int]$cal.Value] = @{ Shift = $sh; Score = $jt } }
        else { $cal.Verify[[int]$c] = @{ Shift = $sh; Score = $jt } }
        $shifts += $sh; if (-not [double]::IsNaN($jt)) { $scores += $jt }
    }
    $badTxt = if ($bad.Count -gt 0) { ((T ", illisibles : {0}") -f "$($bad -join ',')") } else { '' }
    if ($shifts.Count -gt 0) {
        $st = $shifts | Measure-Object -Average -Minimum -Maximum
        $scTxt = if ($scores.Count -gt 0) { "$([math]::Round(($scores | Measure-Object -Average).Average, 0))" } else { '-' }
        Append-Log ((T "  {0} : décalage résiduel moyen {1} ns (de {2} à {3}), score jitter moyen {4}, {5} cylindre(s){6}") -f "$($cal.ValueTxt)", "$([math]::Round($st.Average, 1))", "$([math]::Round($st.Minimum, 1))", "$([math]::Round($st.Maximum, 1))", "$scTxt", "$($shifts.Count)", "$badTxt")
    } else {
        Append-Log ((T "  {0} : aucun cylindre mesurable{1}") -f "$($cal.ValueTxt)", "$badTxt")
    }
    if ($cal.Stage -eq 'coarse') {
        $cal.Index++
        if ($cal.Index -lt $cal.Values.Count) { New-CalibPass; return }
        if (-not (Set-CalibEstimates)) { $cal.TotalPasses = $cal.PassesDone; Complete-PrecompCalib; return }
        $cal.Profile = Build-CalibProfile $cal.Est
        Append-Log ((T "Profil estimé : {0}") -f "$($cal.Profile)")
        $cal.Stage = 'verify'; $cal.VerifyCount = 1; $cal.Verify = @{}
        New-CalibPass; return
    }
    # Verification : les cylindres dont le residu depasse la tolerance sont corriges d apres la pente
    $corr = 0
    foreach ($c in @($cal.Verify.Keys)) {
        $res = [double]$cal.Verify[$c].Shift
        if ([math]::Abs($res) -le $script:CalResidual) { continue }
        $applied = Get-SpecValue $cal.Profile ([int]$c)
        $cal.Est[[int]$c] = [math]::Max(0, [math]::Min($script:CalMaxNs, $applied + $res / [math]::Abs($cal.Slope)))
        $corr++
    }
    if ($corr -gt 0 -and $cal.VerifyCount -lt $script:CalMaxVerify) {
        $newProfile = Build-CalibProfile $cal.Est
        if ($newProfile -ne $cal.Profile) {
            $cal.Profile = $newProfile
            Append-Log ((T "{0} cylindre(s) corrigé(s) de plus de {1} ns de résidu, nouveau profil : {2}") -f "$corr", "$($script:CalResidual)", "$($cal.Profile)")
            $cal.VerifyCount++; $cal.Verify = @{}
            New-CalibPass; return
        }
    }
    $cal.TotalPasses = $cal.PassesDone
    Complete-PrecompCalib
}

function Complete-PrecompCalib {
    $cal = $script:Cal; $script:Cal = $null
    if (-not $cal) { return }
    $pbWCal.Value = 100
    $elapsedTotal = if ($cal.StartTime -is [datetime]) { ((Get-Date) - $cal.StartTime).TotalSeconds } else { 0 }
    $lblWCal.Text = ((T "Calibration terminée en {0}") -f (Format-CalDuration $elapsedTotal))
    if (-not $cal.Profile) { Append-Log (T 'Calibration precomp : aucune mesure exploitable, profil inchangé.'); return }
    if ($cal.Verify.Count -gt 0) {
        $resTxt = (@($cal.Verify.Keys | Sort-Object | ForEach-Object { "c$_=$('{0:+0.0;-0.0;0.0}' -f [double]$cal.Verify[$_].Shift)" })) -join ' '
        Append-Log ((T "Résidu après vérification (ns, tolérance {0}) : {1}") -f "$($script:CalResidual)", "$resTxt")
    }
    $spec = $cal.Profile
    $famTxt = Get-CalibFamilyName $cal.Family
    if ($cal.Family -eq 'long') { $script:PrecompLong = $spec } else { $script:PrecompStd = $spec }
    $cmbWProfile.SelectedIndex = 0                 # Auto : applique le profil de la famille de l image
    Update-PrecompForImage $txtWFile.Text
    $lblWProfileInfo.Text = ((T "Profil {0} calibré le {1} sur le lecteur {2} : {3}") -f "$famTxt", "$(Get-Date -Format 'dd/MM/yyyy HH:mm')", "$($cal.Drive)", "$spec")
    Append-Log ((T "Calibration terminée : profil {0} = {1}") -f "$famTxt", "$spec")
    Append-Log ((T "Profil enregistré dans la configuration et appliqué par le mode Auto à toute image {0}.") -f "$famTxt")
    [void](Save-Config)
}

# --- Configuration -------------------------------------------------------------
function Set-Defaults {
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
    $chkWPostCheck.Checked = $true
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
    $numPin.Value = 2
    $cmbPinLvl.SelectedIndex = 0

    foreach ($k in $script:DelayCtrls.Keys) {
        $c = $script:DelayCtrls[$k]
        $c.Chk.Checked = $false
        $c.Num.Value = $c.Def
    }

    $cmbHelpAct.SelectedItem = 'write'
    $txtC.Text = 'write --pre-erase --erase-empty --retries=10 --precomp 40=140 "jeu.ipf"'
}

function Save-Config {
    $delays = @{}
    foreach ($k in $script:DelayCtrls.Keys) {
        $c = $script:DelayCtrls[$k]
        $delays[$k] = @{ on = [bool]$c.Chk.Checked; val = [int]$c.Num.Value }
    }
    $cfg = [ordered]@{
        _comment = (T 'Configuration GreaseweazleGUI - régénérée automatiquement. Supprimable sans risque.')
        _saved   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        window   = @{
            width  = $(if ($form.WindowState -eq 'Normal') { $form.Width }  else { $form.RestoreBounds.Width })
            height = $(if ($form.WindowState -eq 'Normal') { $form.Height } else { $form.RestoreBounds.Height })
            split = $split.SplitterDistance; maximized = ($form.WindowState -eq 'Maximized')
            logVisible = -not $split.Panel2Collapsed
        }
        global   = @{ drive = $cmbDrive.Text; device = $txtDev.Text; time = [bool]$chkTime.Checked }
        library  = @{ root = $txtLibRoot.Text; imagesOnly = [bool]$chkLibImgOnly.Checked }
        write    = @{
            file = $txtWFile.Text; format = $cmbWFmt.Text
            preErase = [bool]$chkWPreErase.Checked; eraseEmpty = [bool]$chkWEraseEmpty.Checked
            noVerify = [bool]$chkWNoVerify.Checked; reverse = [bool]$chkWReverse.Checked
            hardSectors = [bool]$chkWHard.Checked; genTg43 = [bool]$chkWTG43.Checked
            retries = [int]$numWRetries.Value
            precompOn = [bool]$chkWPrecomp.Checked; precomp = $txtWPrecomp.Text
            precompProfile = $cmbWProfile.Text; postCheck = [bool]$chkWPostCheck.Checked; calMode = [int]$cmbWCalMode.SelectedIndex
            precompStd = $script:PrecompStd; precompLong = $script:PrecompLong; precompThresholdNs = [int]$script:PrecompThresholdNs
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
            pin = [int]$numPin.Value; pinLevel = $cmbPinLvl.Text
        }
        delays   = $delays
        free     = @{ command = $txtC.Text; helpAction = $cmbHelpAct.Text }
    }
    try {
        $cfg | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:ConfigFile -Encoding UTF8
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
        if ($w -ge $form.MinimumSize.Width -and $h -ge $form.MinimumSize.Height) { $form.Size = New-Object System.Drawing.Size($w, $h) }
        $script:PendingSplit = [int](Get-Cfg $win 'split' 0)
        if ([bool](Get-Cfg $win 'maximized' $false)) { $form.WindowState = 'Maximized' }
        $script:PendingLogVisible = [bool](Get-Cfg $win 'logVisible' $true)
    }

    $g = Get-Cfg $cfg 'global' $null
    Set-Combo $cmbDrive (Get-Cfg $g 'drive' 'A')
    $txtDev.Text = [string](Get-Cfg $g 'device' '')
    $chkTime.Checked = [bool](Get-Cfg $g 'time' $false)

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
    $script:PrecompStd  = [string](Get-Cfg $w 'precompStd' $script:PrecompStd)
    $script:PrecompLong = [string](Get-Cfg $w 'precompLong' $script:PrecompLong)
    $script:PrecompThresholdNs = [int](Get-Cfg $w 'precompThresholdNs' $script:PrecompThresholdNs)
    Set-Combo $cmbWProfile (Get-Cfg $w 'precompProfile' (T 'Auto (selon image)'))
    $chkWPostCheck.Checked = [bool](Get-Cfg $w 'postCheck' $true)
    $cm = [int](Get-Cfg $w 'calMode' 0); if ($cm -ge 0 -and $cm -lt $cmbWCalMode.Items.Count) { $cmbWCalMode.SelectedIndex = $cm }
    $txtWPrecomp.Text  = [string](Get-Cfg $w 'precomp' $script:PrecompStd)
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
    $btnCfgSave.Enabled = -not $busy
    $btnCfgReset.Enabled = -not $busy
}

function Get-LogColor([string]$line) {
    if ($line -match '^>>>') { return $script:LogColors.cmd }
    if ($line -match 'FATAL|ERREUR|ERROR|ECHEC|ÉCHEC|FAILED|Failed|Command Failed|Write ?Protect|CRITIQUE|CRITICAL|ILLISIBLE|UNREADABLE|introuvable|not found|code retour : [1-9]|exit code: [1-9]') { return $script:LogColors.err }
    if ($line -match 'Verify Failure|Retry #|retries|À SURVEILLER|TO WATCH|marginal|DIFF[EÉ]RENT|Interrompu|Interrupted|aborted') { return $script:LogColors.warn }
    if ($line -match 'All tracks verified|code retour : 0|exit code: 0|SAIN|HEALTHY|IDENTIQUE|IDENTICAL|EXCELLENT|aucune piste n|no track needed') { return $script:LogColors.ok }
    if ($line -match '^T\d+\.\d+:') { return $script:LogColors.dim }
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
    if ($line -match '^(Reading|Writing|Erasing)\s+c=([\d,\-]+):h=([\d,\-]+)') {
        $script:ProgTotal = (Get-SpecCount $Matches[2]) * (Get-SpecCount $Matches[3])
        if ($script:ProgTotal -gt 0) { $stBar.Style = 'Continuous'; $stBar.Minimum = 0; $stBar.Maximum = $script:ProgTotal; $stBar.Value = 0 }
        return
    }
    if ($line -match '^T(\d+)\.(\d+):') {
        $key = "$($Matches[1]).$($Matches[2])"
        [void]$script:ProgSeen.Add($key)
        if ($script:ProgTotal -gt 0) {
            $v = [math]::Min($script:ProgSeen.Count, $script:ProgTotal)
            $stBar.Value = $v
            $pct = [math]::Round(100 * $v / $script:ProgTotal, 0)
            $stTrack.Text = ((T "piste {0}  ({1}/{2}, {3} %)") -f "$key", "$v", "$($script:ProgTotal)", "$pct")
        } else { $stTrack.Text = ((T "piste {0}") -f "$key") }
        if ($line -match 'Retry #(\d+)') { $stTrack.Text += ((T "  -  retry {0}") -f "$($Matches[1])") }
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

# Sortie de gw capturee via redirection fichier puis relue par le timer.
function Start-Gw([string[]]$gwArgs) {
    $exe = $script:GwExe
    if (-not (Test-Path -LiteralPath $exe)) {
        [void][System.Windows.Forms.MessageBox]::Show(((T "gw.exe introuvable : {0}`n`nPlace ce script dans le même répertoire que gw.exe.") -f "$exe"),(T 'Erreur'),'OK','Error'); return
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }

    [void](Save-Config)

    $script:GwIsWrite = ($gwArgs.Count -gt 0 -and $gwArgs[0] -eq 'write')
    $verbs = @{ write=(T 'Écriture'); read=(T 'Lecture'); erase=(T 'Effacement'); convert='Conversion'; clean=(T 'Nettoyage'); rpm=(T 'Mesure de vitesse'); update=(T 'Mise à jour firmware') }
    $first = if ($gwArgs.Count -gt 0) { ($gwArgs[0] -split ' ')[0] } else { '' }
    Start-Progress $(if ($verbs.ContainsKey($first)) { $verbs[$first] } else { "gw $first" })
    if ($script:GwIsWrite) { $script:WriteRetries = @{} }
    if ($chkTime.Checked) { $gwArgs = @('--time') + $gwArgs }
    $argLine = $gwArgs -join ' '
    Append-Log ">>> gw $argLine"
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
        # Lecture asynchrone des deux flux : chaque ReadLineAsync rend une Task que le timer
        # inspecte sans bloquer l'interface. Pas de bloc -Action (inactif sous ShowDialog).
        $script:OutStdoutReader = $p.StandardOutput
        $script:OutStderrReader = $p.StandardError
        $script:OutStdoutTask = $script:OutStdoutReader.ReadLineAsync()
        $script:OutStderrTask = $script:OutStderrReader.ReadLineAsync()
        Set-Busy $true
    } catch {
        Append-Log ((T "ERREUR lancement : {0}") -f "$($_.Exception.Message)")
        $script:GwProc = $null
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
    if ($script:GwIsWrite) {
        foreach ($l in $lines) {
            if ($l -match '^T(\d+)\.(\d+):.*Retry #(\d+)') {
                $k = "$($Matches[1]).$($Matches[2])"; $n = [int]$Matches[3]
                if (-not $script:WriteRetries.ContainsKey($k) -or $n -gt $script:WriteRetries[$k]) { $script:WriteRetries[$k] = $n }
            }
        }
    }
    if ($lines.Count -gt 0) { Append-Log ($lines -join [Environment]::NewLine) }
}

# Controle post-ecriture : relit les pistes difficiles + un echantillon, puis analyse dans l onglet Qualite
function Start-PostWriteCheck {
    if (-not $script:ScpStatsOk) { Append-Log (T 'Contrôle post-écriture : module d''analyse SCP indisponible.'); return }
    $cyls = @(0, 40, 79)
    foreach ($k in $script:WriteRetries.Keys) { $cyls += [int]($k -split '\.')[0] }
    $cyls = @($cyls | Where-Object { $_ -ge 0 -and $_ -le 83 } | Sort-Object -Unique)
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $script:AlignTmp = Join-Path $script:TempDir 'align.scp'
    if (Test-Path -LiteralPath $script:AlignTmp) { Remove-Item -LiteralPath $script:AlignTmp -Force }
    $script:AlignArgs = @('read') + (Get-CommonArgs) + @('--revs=3', "--tracks=c=$($cyls -join ','):h=0-1", "`"$($script:AlignTmp)`"")
    $script:PostWriteMode = $true
    $script:AlignLoop = $false; $script:AlLastMove = 0
    $retryTxt = if ($script:WriteRetries.Count -gt 0) { ($script:WriteRetries.Keys | Sort-Object | ForEach-Object { ((T "{0} (x{1})") -f "$_", "$($script:WriteRetries[$_])") }) -join ', ' } else { (T 'aucune') }
    Append-Log ((T "Contrôle post-écriture : pistes avec retries : {0}. Relecture des cylindres {1} (2 faces).") -f "$retryTxt", "$($cyls -join ',')")
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw $script:AlignArgs })
    $script:Chain.Enqueue({ Invoke-AlignAnalysis; $tabs.SelectedTab = $tabAl })
    Invoke-NextChainStep
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({
    # Sortie de gw
    if ($script:GwProc) {
        if ($script:GwProc.HasExited) {
            Read-GwOutput $true
            $code = $script:GwProc.ExitCode
            $script:OutStdoutReader = $null; $script:OutStderrReader = $null
            $script:OutStdoutTask = $null; $script:OutStderrTask = $null
            Stop-Progress $code
            if ($script:GwIsWrite) {
                if ($script:WriteRetries.Count -gt 0) {
                    Append-Log ((T "Pistes ayant nécessité des retries : ") + (($script:WriteRetries.Keys | Sort-Object | ForEach-Object { ((T "{0} (x{1})") -f "$_", "$($script:WriteRetries[$_])") }) -join ', '))
                } elseif ($code -eq 0 -and -not ($script:ProgTotal -gt 0 -and $script:ProgSeen.Count * 2 -lt $script:ProgTotal)) { Append-Log (T 'Écriture : aucune piste n''a nécessité de retry.') }
                $script:GwIsWrite = $false
            }
            $elapsed = if ($script:GwStart -is [datetime]) { [math]::Round(((Get-Date) - $script:GwStart).TotalSeconds, 1) } else { 0 }
            Append-Log ((T "<<< Terminé (code retour : {0}, {1} s, {2} ligne(s) reçues)") -f "$code", "$elapsed", "$($script:GwLines)")
            # Arret silencieux : code 0 mais moins de la moitie des pistes annoncees traitees
            # (une image incomplete n explique pas un tel ecart). Pas de controle post-ecriture
            # ni d etape suivante : ils masqueraient le probleme.
            if ($code -eq 0 -and $script:ProgTotal -gt 0 -and $script:ProgSeen.Count * 2 -lt $script:ProgTotal) {
                Append-Log ((T "ERREUR : opération incomplète, gw s'est arrêté après {0} piste(s) sur {1} annoncées avec le code 0. Vérifier le lecteur, le câble USB et l'alimentation, puis relancer.") -f "$($script:ProgSeen.Count)", "$($script:ProgTotal)")
                $script:Chain.Clear(); $script:PostWriteMode = $false
                if ($script:Cal) { Stop-PrecompCalib }
            }
            Append-Log ''
            $script:GwProc = $null
            Set-Busy $false
            if ($script:Chain.Count -gt 0) {
                if ($code -eq 0) {
                    Invoke-NextChainStep
                } else {
                    $script:Chain.Clear()
                    Append-Log (T 'Séquence interrompue : gw a retourné une erreur.')
                    if ($txtCmpResult.Text -like ((T 'Comparaison en cours') + '*')) { $txtCmpResult.Text = ((T "ÉCHEC : gw a retourné le code {0}. Voir le journal.") -f "$code") }
                    if ($script:AlignLoop) { $script:AlignLoop = $false; $script:AlignNextAt = $null; $lblAlVerdict.Text = (T 'Mesure interrompue (erreur gw)') }
                    $script:PostWriteMode = $false
                    if ($script:Cal) { Stop-PrecompCalib }
                }
            }
        } else {
            Read-GwOutput $false
        }
    }
    # Calibration precomp : barre globale et temps restant
    if ($script:Cal) { Update-CalibProgress }
    # Alignement : passe suivante en mode continu
    if ($script:AlignLoop -and $script:AlignNextAt -and -not $script:GwProc -and (Get-Date) -ge $script:AlignNextAt) {
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

$form.Add_FormClosing({
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
    Render-Banner
    Set-LogVisible $script:PendingLogVisible
    if ($script:PendingSplit -gt 0) {
        $max = $split.Height - $split.Panel2MinSize - $split.SplitterWidth
        if ($script:PendingSplit -ge $split.Panel1MinSize -and $script:PendingSplit -le $max) {
            $split.SplitterDistance = $script:PendingSplit
        }
    }
    # Bibliotheque chargee une fois la fenetre visible (racine reseau possible)
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try { Update-Library; if ($txtWFile.Text) { Update-PrecompForImage $txtWFile.Text } } finally { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
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

Append-Log "Greaseweazle Studio v$($script:Version)"
Append-Log ((T "Répertoire  : {0}") -f "$($script:AppDir)")
if (Test-Path -LiteralPath $script:GwExe) { Append-Log (T 'gw.exe      : trouvé') }
else { Append-Log (T 'gw.exe      : ABSENT - place ce script dans le répertoire de gw.exe') }
if ($loaded) { Append-Log (T 'Config      : chargée depuis GreaseweazleGUI.json') }
else         { Append-Log (T 'Config      : aucune, valeurs par défaut') }
Append-Log ((T "Extraction  : {0}") -f "$($script:TempDir)")
Append-Log ((T "Index       : {0}") -f "$(if ($script:FastIndexOk) { $script:IndexDir } else { (T 'module indisponible, recherche directe') })")
Append-Log ''

[void]$form.ShowDialog()
