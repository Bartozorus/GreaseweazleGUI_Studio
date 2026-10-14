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
$script:Version = '11.8'

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
$script:I18n["{0} cylindre(s) corrigé(s) de plus de {1} ns de résidu, nouveau profil : {2}"] = "{0} cylinder(s) corrected for more than {1} ns of residual, new profile: {2}"
$script:I18n["Résidu après vérification (ns, tolérance {0}) : {1}"] = "Residual after verification (ns, tolerance {0}): {1}"
$script:I18n['Calibration precomp : aucune mesure exploitable, profil inchangé.'] = 'Precomp calibration: no usable measurement, profile unchanged.'
$script:I18n["Calibration terminée : profil {0} = {1}"] = "Calibration complete: {0} profile = {1}"
$script:I18n["Profil enregistré dans la configuration et appliqué par le mode Auto à toute image {0}."] = "Profile saved to the configuration and applied by Auto mode to any {0} image."
$script:I18n['Calibration precomp interrompue.'] = 'Precomp calibration aborted.'
$script:I18n['écriture'] = 'writing'
$script:I18n['relecture'] = 'reading back'
$script:I18n["Calibration : passe {0}/{1}, {2}, {3}  -  {4} %  -  reste environ {5}"] = "Calibration: pass {0}/{1}, {2}, {3}  -  {4} %  -  about {5} left"
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
$script:I18n["CONTRÔLE APRÈS ÉCRITURE : {0}/{0} pistes saines"] = "POST-WRITE CHECK: {0}/{0} healthy tracks"
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
$script:I18n["Mesures (cylindre : estimation ± incertitude, ns) :"] = "Measurements (cylinder: estimate ± uncertainty, ns):"
$script:I18n['cylindre'] = 'cylinder'
$script:I18n["{0} : lecteur {1}, {2}, courbe {3}, de {4} à {5} ns"] = "{0}: drive {1}, {2}, {3} curve, from {4} to {5} ns"
$script:I18n['mesure par cylindre testé (± incertitude)'] = 'measurement per tested cylinder (± uncertainty)'
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
$script:I18n["Calibration par tête impossible : l'image n'a qu'une face, gw n'écrirait pas la tête 1.`nDécocher « Écriture lente » pour une calibration commune."] = "Per-head calibration impossible: the image has a single side, gw would not write head 1.`nUncheck ""Slow write"" for a common calibration."
$script:I18n['Calibration : le décalage ne varie pas avec la précompensation écrite, cette face n''a pas été écrite (format simple face ?).'] = 'Calibration: the shift does not vary with the written precompensation, this side was not written (single-sided format?).'
$script:I18n[' ; écriture lente : courbes par tête antérieures au profil commun, profil commun pour les deux têtes'] = '; slow write: per-head curves older than the common profile, common profile for both heads'
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
$script:WriteTracks  = @{}      # pistes annoncees « Writing Track » par la derniere ecriture gw : 'cyl.tete' -> $true
$script:WriteQueue   = New-Object System.Collections.Queue   # ecriture lente : commandes gw write restantes (une par tete)
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

$btnWCurve = New-Object System.Windows.Forms.Button
$btnWCurve.Text = (T 'Courbe'); $btnWCurve.Location = '620,50'; $btnWCurve.Size = '130,26'; $btnWCurve.Enabled = $false
$tip.SetToolTip($btnWCurve, (T 'Affiche la courbe de précompensation calibrée pour la famille de l''image (standard ou long track) : mesures, courbe ajustée et valeur retenue pour chaque cylindre.') + "`n" + (T 'Écriture lente cochée : une courbe par tête, si la calibration a été faite en écriture lente.'))
$btnWCurve.Add_Click({ Show-PrecompCurve $script:CurveFamily $chkWSlow.Checked })

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
[void]$cmbWCalMode.Items.AddRange(@((T 'Test standard : 1 cylindre sur 10'), (T 'Test fin : tous les cylindres')))
$cmbWCalMode.SelectedIndex = 0
$btnWCalib = New-Object System.Windows.Forms.Button
$btnWCalib.Text = (T 'Calibrer'); $btnWCalib.Location = '425,104'; $btnWCalib.Size = '120,26'
$tip.SetToolTip($btnWCalib, (T "Calibre la précompensation pour ce lecteur d'écriture : chaque passe écrit les cylindres de test de l'image avec une valeur de precomp, les relit en flux et note le placement des transitions. La meilleure valeur par cylindre forme le profil, enregistré pour la famille de l'image (standard ou long track) et appliqué ensuite par le mode Auto. La disquette insérée est écrasée. Test standard : un cylindre sur 10, quelques minutes. Test fin : tous les cylindres, environ une heure."))
$tip.SetToolTip($btnWCalib, $tip.GetToolTip($btnWCalib) + "`n" + (T 'Écriture lente cochée : une courbe par tête, vérifiée en écrivant la tête 0 puis la tête 1, chacune avec son profil.'))
$btnWCalib.Add_Click({ Start-PrecompCalib })

# --- Ligne 4 : progression globale de la calibration (toutes passes), visible pendant et apres
$pbWCal = New-Object System.Windows.Forms.ProgressBar
$pbWCal.Location = '12,136'; $pbWCal.Size = '300,16'; $pbWCal.Minimum = 0; $pbWCal.Maximum = 100; $pbWCal.Visible = $false
$lblWCal = New-Object System.Windows.Forms.Label
$lblWCal.Location = '320,137'; $lblWCal.AutoSize = $true; $lblWCal.ForeColor = 'DimGray'; $lblWCal.Visible = $false

$grpWOpt.Controls.AddRange(@($chkWPreErase, $chkWEraseEmpty, $chkWNoVerify, (New-Label (T 'Retries :') '500,26'), $numWRetries, $chkWSlow, $chkWPrecomp, $txtWPrecomp, $chkWPostCheck,
    $lblWPrecomp1, $txtWPrecomp1, (New-Label (T 'Calibration précomp :') '12,109'), $cmbWCalMode, $btnWCalib, $pbWCal, $lblWCal, $lblWRepair, $numWRepair))

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
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
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
    $blocker = if ($chkWPostCheck.Checked) { Get-WriteCheckBlocker $txtWFile.Text $cmbWFmt.Text } else { $null }
    if ($blocker) {
        Append-Log ((T "Contrôle de toutes les pistes non applicable ({0}) : l'analyse de flux est calibrée pour le MFM double densité. Écriture sans contrôle.") -f "$blocker")
    }
    if ($chkWPostCheck.Checked -and -not $blocker) {
        # Options de lecteur reprises par les relectures de controle (gw read les accepte toutes)
        $readOpts = @()
        if ($chkWReverse.Checked)         { $readOpts += '--reverse' }
        if ($cmbWDensel.Text -ne '(non)') { $readOpts += "--densel=$($cmbWDensel.Text)" }
        if ($txtWFakeIdx.Text.Trim())     { $readOpts += "--fake-index=$($txtWFakeIdx.Text.Trim())" }
        New-WriteCheck $base $txtWFile.Text $userTs ([int]$numWRepair.Value) $readOpts $headPc
        $script:Chain.Clear()
        if ($slow) { for ($i = 0; $i -lt $script:WriteQueue.Count; $i++) { $script:Chain.Enqueue({ Invoke-WriteQueueNext }) } }
        else { $script:WriteArgs = $a; $script:Chain.Enqueue({ Start-Gw $script:WriteArgs }) }
        $script:Chain.Enqueue({ Start-WriteCheck })
        Invoke-NextChainStep
    } elseif ($slow) {
        $script:Chain.Clear()
        for ($i = 0; $i -lt $script:WriteQueue.Count; $i++) { $script:Chain.Enqueue({ Invoke-WriteQueueNext }) }
        Invoke-NextChainStep
    } else {
        Start-Gw $a
    }
})

$lblWProfileInfo = New-Object System.Windows.Forms.Label
$lblWProfileInfo.Location = '270,348'; $lblWProfileInfo.Size = '502,40'; $lblWProfileInfo.Anchor = 'Top,Left,Right'
$lblWProfileInfo.ForeColor = 'DimGray'; $lblWProfileInfo.Text = (T 'Choisis une image : le format et la précompensation seront déduits automatiquement.')

$tabW.Controls.AddRange(@($grpWImage, $grpWOpt, $grpWAdv, $btnWrite, $lblWProfileInfo))
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
    if ($script:GwProc -or $script:Chain.Count -gt 0 -or $script:Rep -or $script:Cal) {
        if ($script:GwProc -and -not $script:GwProc.HasExited) {
            try { $script:GwProc.Kill($true) } catch { try { $script:GwProc.Kill() } catch { } }
        }
        $script:Chain.Clear(); $script:WriteQueue.Clear()
        if ($script:Rep) { Stop-WriteCheck }
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
        $script:Chain.Clear(); $script:WriteQueue.Clear()
        if ($script:Rep) { Stop-WriteCheck }
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

# Metriques d une piste (liste de ScpRev, un par tour) : base commune de l onglet Qualite et du
# controle apres ecriture, pour que « piste faible » ait partout la meme definition.
function Get-TrackMetrics($st) {
    $m = @{ Bad = $false; Missing = $false; J = 0.0; R3 = 0.0; R4 = 0.0; Ooc = 0.0; Dr = 0.0; Cell = 0.0; Stab = 0.0; Asym = 0.0; Score = 9999; Level = 2 }
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
    foreach ($v in @(($healthNames[$hl] + $mark), ('{0:N1}' -f $m.Ooc), ('{0:N1}' -f $m.Dr), [string]$m.Stab, ('{0:N0}' -f $m.J), ('{0:N0}' -f $m.Score), $delta, ('{0:N3}' -f $m.Asym), ('{0:N0}' -f $m.Cell))) { [void]$it.SubItems.Add($v) }
    $it.SubItems[1].BackColor = $healthColor[$hl]; $it.SubItems[1].ForeColor = $script:AlFg[$(@{0=0;1=2;2=3}[$hl])]
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

function Invoke-AlignAnalysis {
    if (-not $script:AlignTmp -or -not (Test-Path -LiteralPath $script:AlignTmp)) {
        Append-Log (T 'Mesure : fichier SCP absent, analyse impossible.'); $script:AlignLoop = $false; return
    }
    try { $tracks = Read-ScpFile $script:AlignTmp } catch { Append-Log ((T "Mesure : {0}") -f "$($_.Exception.Message)"); $script:AlignLoop = $false; return }

    $last = @{}; $watch = @(); $crit = @()
    $lvAl.Columns[1].Width = 140
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
            $sc = $m.Score
            if (-not $script:AlignBest.ContainsKey($key) -or $sc -lt $script:AlignBest[$key]) { $script:AlignBest[$key] = $sc }
            $last[$key] = @{ Score = $sc; Jitter = $m.J; Asym = $m.Asym; Err = $m.Ooc; Stab = $m.Stab; Cell = $m.Cell }
            $hl = $m.Level
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
    $rate = [BitConverter]::ToUInt16($h, 12)          # en-tete HFE : bitRate (kbit/s) a l offset 12
    if ($rate -le 0) { throw (T 'Débit HFE nul') }
    if ($rate -lt 100 -or $rate -gt 1000) { throw ((T "Débit HFE invalide ({0} kbit/s)") -f "$rate") }
    return @{ CellNs = [double](500000.0 / $rate); Bits = [int64](200000000.0 / (500000.0 / $rate)); Tracks = -1; DosTracks = -1; Source = ((T "HFE (débit {0} kbit/s)") -f "$rate") }
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
    $mode = $cmbWProfile.Text
    if ($mode -eq (T 'Manuel')) { $lblWProfileInfo.Text = (T 'Profil manuel : --precomp non modifié.'); return }
    if ($mode -eq (T 'Standard 2 us'))      { $x = Set-PrecompFields $script:PrecompStd 'std';   $lblWProfileInfo.Text = ((T "Profil forcé : standard 2 us ({0})") -f "$($script:PrecompStd)") + $x; return }
    if ($mode -eq (T 'Long track 1,89 us')) { $x = Set-PrecompFields $script:PrecompLong 'long'; $lblWProfileInfo.Text = ((T "Profil forcé : long track ({0})") -f "$($script:PrecompLong)") + $x; return }
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
$script:CalMaxNs     = 300              # borne haute d une valeur de precomp
$script:CalResidual  = 4.0              # residu (ns) au-dela duquel un cylindre est corrige
$script:CalMaxVerify = 2                # passes de verification au plus
$script:PrecompCurves = @{ std = $null; long = $null; std_h0 = $null; std_h1 = $null; long_h0 = $null; long_h1 = $null }   # derniere courbe calibree par famille d image (et par tete : ecriture lente)
$script:CurveKeys = @('std', 'long', 'std_h0', 'std_h1', 'long_h0', 'long_h1')
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

function Fit-PrecompCurve($est, $sig, [int]$maxCyl) {
    # Courbe de precompensation par cylindre a partir des estimations des cylindres testes.
    # Moindres carres ponderes (poids = 1 / incertitude^2) de p = A + B.x, B >= 0, pour trois formes
    # physiquement plausibles (densite lineaire croissante vers l interieur) : x = cylindre, 1/rayon,
    # 1/rayon^2 ; la forme de plus faible ecart pondere est retenue. Si elle n explique pas les mesures
    # (chi2 reduit > 4 avec au moins 4 points), interpolation monotone des mesures lissees (PAVA).
    $cs = @($est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    if ($cs.Count -eq 0) { return $null }
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
        # Interpolation monotone : PAVA pondere sur les mesures, puis lineaire entre cylindres testes
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
            $vals[$c] = [int][math]::Max(0, [math]::Min($script:CalMaxNs, [math]::Round($v, 0)))
        }
        return @{ Model = 'iso'; A = $null; B = $null; Chi = $chi; Values = $vals }
    }
    for ($c = 0; $c -le $maxCyl; $c++) {
        $v = $best.A + $best.B * (Get-CurveX $best.Model $c $maxCyl)
        $vals[$c] = [int][math]::Max(0, [math]::Min($script:CalMaxNs, [math]::Round($v, 0)))
    }
    return @{ Model = $best.Model; A = $best.A; B = $best.B; Chi = $chi; Values = $vals }
}

function Add-CurveCorrection($values, $delta) {
    # Valeurs par cylindre + corrections locales (ns) mesurees aux cylindres verifies : interpolation lineaire
    # des corrections entre cylindres verifies (0 la ou le residu est dans la tolerance), constante au-dela des
    # extremites, puis lissage monotone croissant (PAVA) et arrondi a l entier.
    $v = @($values); $n = $v.Count
    $ks = @($delta.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -ge 0 -and $_ -lt $n } | Sort-Object)
    $raw = New-Object double[] $n
    for ($c = 0; $c -lt $n; $c++) {
        $d = 0.0
        if ($ks.Count -gt 0) {
            if ($c -le $ks[0]) { $d = [double]$delta[$ks[0]] }
            elseif ($c -ge $ks[-1]) { $d = [double]$delta[$ks[-1]] }
            else {
                $j = 0; while ($ks[$j + 1] -lt $c) { $j++ }
                $t = ($c - $ks[$j]) / [double]($ks[$j + 1] - $ks[$j])
                $d = [double]$delta[$ks[$j]] + $t * ([double]$delta[$ks[$j + 1]] - [double]$delta[$ks[$j]])
            }
        }
        $raw[$c] = [double]$v[$c] + $d
    }
    $blocks = New-Object System.Collections.Generic.List[object]
    for ($c = 0; $c -lt $n; $c++) {
        $blocks.Add(@{ S = $raw[$c]; N = 1 })
        while ($blocks.Count -ge 2) {
            $p = $blocks[$blocks.Count - 2]; $q = $blocks[$blocks.Count - 1]
            if ($p.S / $p.N -le $q.S / $q.N) { break }
            $blocks.RemoveAt($blocks.Count - 1); $blocks.RemoveAt($blocks.Count - 1)
            $blocks.Add(@{ S = $p.S + $q.S; N = $p.N + $q.N })
        }
    }
    $out = New-Object int[] $n; $c = 0
    foreach ($bk in $blocks) { $m = [int][math]::Max(0, [math]::Min($script:CalMaxNs, [math]::Round($bk.S / $bk.N, 0))); for ($k = 0; $k -lt $bk.N; $k++) { $out[$c++] = $m } }
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
        default { return $model }
    }
}

function Format-CurveTable($cvs) {
    # Tableau texte des valeurs par cylindre (10 par ligne) et profil --precomp correspondant, pour chaque courbe
    $lines = @()
    foreach ($cv in @($cvs)) {
        if ($lines.Count -gt 0) { $lines += ''; $lines += '' }
        if ($null -ne $cv.Head) { $lines += ((T "Tête {0} : courbe {1}") -f "$($cv.Head)", (Get-CurveModelName $cv.Model)) }
        $v = @($cv.Values)
        $lines += @(((T "Profil --precomp : {0}") -f "$($cv.Spec)"), '', ('cyl  ' + ((0..9 | ForEach-Object { '{0,5}' -f "+$_" }) -join '')))
        for ($c0 = 0; $c0 -lt $v.Count; $c0 += 10) {
            $row = @(); for ($c = $c0; $c -lt [math]::Min($v.Count, $c0 + 10); $c++) { $row += ('{0,5}' -f $v[$c]) }
            $lines += ('{0,3}  ' -f $c0) + ($row -join '')
        }
        $lines += ''
        $lines += (T "Mesures (cylindre : estimation ± incertitude, ns) :")
        $m = @(); for ($i = 0; $i -lt @($cv.Cyls).Count; $i++) { $m += ("c{0} : {1:0.0} ± {2:0.0}" -f $cv.Cyls[$i], $cv.Ys[$i], $cv.Sig[$i]) }
        $lines += ($m -join '   ')
    }
    return ($lines -join "`r`n")
}

function Draw-PrecompCurve($g, $size) {
    # Une courbe (profil commun) ou une par tete (ecriture lente), mesures avec leur incertitude
    $cvs = @(@($script:CurveData) | Where-Object { $_ })
    if ($cvs.Count -eq 0) { return }
    $multi = $cvs.Count -gt 1
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::White)
    $W = $size.Width; $H = $size.Height
    $L = 56; $R = 20; $Tp = $(if ($multi) { 72 } else { 52 }); $Bm = 40
    $pw = $W - $L - $R; $ph = $H - $Tp - $Bm
    if ($pw -lt 60 -or $ph -lt 40) { return }
    $nC = 2; foreach ($cv in $cvs) { $nC = [math]::Max($nC, @($cv.Values).Count) }
    $maxC = $nC - 1
    $top = 0.0
    foreach ($cv in $cvs) {
        foreach ($x in @($cv.Values)) { if ($x -gt $top) { $top = $x } }
        for ($i = 0; $i -lt @($cv.Cyls).Count; $i++) { $t = [double]$cv.Ys[$i] + [double]$cv.Sig[$i]; if ($t -gt $top) { $top = $t } }
    }
    $step = if ($top -le 120) { 20 } elseif ($top -le 300) { 50 } else { 100 }
    $ymax = [math]::Max(2 * $step, [math]::Ceiling($top / $step) * $step)
    $fx = { param($c) $L + $pw * $c / $maxC }
    $fy = { param($v) $Tp + $ph * (1.0 - $v / $ymax) }
    $font = New-Object System.Drawing.Font('Segoe UI', 8.25)
    $fontB = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75)
    $grid = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(228, 232, 238), 1)
    $axis = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150, 156, 166), 1)
    $err = New-Object System.Drawing.Pen($script:Theme.Muted, 1.2)
    $txt = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 76, 88))
    $gray = New-Object System.Drawing.SolidBrush($script:Theme.Muted)
    # Tete 0 (ou profil commun) en bleu, tete 1 en orange ; points de mesure orange (commun) ou de la couleur de la tete
    $colors = @($script:Theme.Accent, $script:Theme.Flux)
    $pens = @(); $dots = @()
    for ($i = 0; $i -lt $cvs.Count; $i++) {
        $col = $colors[[math]::Min($i, 1)]
        $pens += (New-Object System.Drawing.Pen($col, 2.2))
        $dots += (New-Object System.Drawing.SolidBrush($(if ($multi) { $col } else { $script:Theme.Flux })))
    }
    try {
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
        for ($k = 0; $k -lt $cvs.Count; $k++) {
            $cv = $cvs[$k]; $vals = @($cv.Values)
            # Courbe retenue : une valeur par cylindre
            $pts = New-Object 'System.Drawing.PointF[]' $vals.Count
            for ($c = 0; $c -lt $vals.Count; $c++) { $pts[$c] = New-Object System.Drawing.PointF([float](& $fx $c), [float](& $fy $vals[$c])) }
            if ($pts.Count -ge 2) { $g.DrawLines($pens[$k], $pts) }
            # Mesures : estimation par cylindre teste, barre = incertitude
            for ($i = 0; $i -lt @($cv.Cyls).Count; $i++) {
                $x = & $fx $cv.Cyls[$i]; $yv = [double]$cv.Ys[$i]; $sg = [double]$cv.Sig[$i]
                $y1 = & $fy ([math]::Min($ymax, $yv + $sg)); $y2 = & $fy ([math]::Max(0, $yv - $sg))
                $g.DrawLine($err, $x, $y1, $x, $y2); $g.DrawLine($err, $x - 3, $y1, $x + 3, $y1); $g.DrawLine($err, $x - 3, $y2, $x + 3, $y2)
                $y = & $fy $yv; $g.FillEllipse($dots[$k], $x - 3.5, $y - 3.5, 7, 7)
            }
        }
        # Titre et legende
        $cv0 = $cvs[0]; $v0 = @($cv0.Values)
        if ($multi) { $title = ((T "{0} : lecteur {1}, {2}, une courbe par tête") -f "$($cv0.Family)", "$($cv0.Drive)", "$($cv0.Date)") }
        else { $title = ((T "{0} : lecteur {1}, {2}, courbe {3}, de {4} à {5} ns") -f "$($cv0.Family)", "$($cv0.Drive)", "$($cv0.Date)", (Get-CurveModelName $cv0.Model), "$($v0[0])", "$($v0[-1])") }
        $g.DrawString($title, $fontB, $txt, $L, 8)
        $ly = 30
        $g.FillEllipse($(if ($multi) { $gray } else { $dots[0] }), $L, $ly + 3, 7, 7)
        $s1 = (T 'mesure par cylindre testé (± incertitude)'); $g.DrawString($s1, $font, $txt, $L + 12, $ly)
        if (-not $multi) {
            $x2 = $L + 24 + $g.MeasureString($s1, $font).Width
            $g.DrawLine($pens[0], $x2, $ly + 7, $x2 + 22, $ly + 7)
            $g.DrawString((T 'précompensation retenue par cylindre'), $font, $txt, $x2 + 28, $ly)
        } else {
            $ly = 50; $x2 = $L
            for ($k = 0; $k -lt $cvs.Count; $k++) {
                $cv = $cvs[$k]; $vals = @($cv.Values)
                $g.DrawLine($pens[$k], $x2, $ly + 7, $x2 + 22, $ly + 7)
                $s = ((T "tête {0} : courbe {1}, de {2} à {3} ns") -f "$($cv.Head)", (Get-CurveModelName $cv.Model), "$($vals[0])", "$($vals[-1])")
                $g.DrawString($s, $font, $txt, $x2 + 28, $ly)
                $x2 += 28 + $g.MeasureString($s, $font).Width + 24
            }
        }
    } finally {
        foreach ($o in @($font, $fontB, $grid, $axis, $err, $txt, $gray) + $pens + $dots) { $o.Dispose() }
    }
}

function Show-PrecompCurve([string]$family, [bool]$preferHeads) {
    $cvs = Get-FamilyCurves $family $preferHeads
    if ($cvs.Count -eq 0) { return }
    if ($script:CurveForm -and -not $script:CurveForm.IsDisposed) { $script:CurveForm.Close() }
    $script:CurveData = $cvs
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
    $f.Show($form)
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

function ConvertTo-CurveConfig($cv) {
    if (-not $cv) { return $null }
    return [ordered]@{ family = $cv.Family; head = $cv.Head; drive = $cv.Drive; date = $cv.Date; model = $cv.Model; spec = $cv.Spec
                       values = @($cv.Values); cyls = @($cv.Cyls); ys = @($cv.Ys); sig = @($cv.Sig) }
}

function ConvertFrom-CurveConfig($o) {
    if (-not $o) { return $null }
    try {
        $cv = @{ Family = [string]$o.family; Head = $(if ($null -ne $o.head) { [int]$o.head } else { $null }); Drive = [string]$o.drive; Date = [string]$o.date
                 Model = [string]$o.model; Spec = [string]$o.spec
                 Values = [int[]]@($o.values); Cyls = [int[]]@($o.cyls); Ys = [double[]]@($o.ys); Sig = [double[]]@($o.sig) }
        if ($cv.Values.Count -lt 2 -or $cv.Cyls.Count -ne $cv.Ys.Count -or $cv.Cyls.Count -ne $cv.Sig.Count) { return $null }
        return $cv
    } catch { return $null }
}

function New-CalibUnit($head) {
    # Unite de calibration : les deux tetes ensemble (Head = $null, profil commun) ou une seule tete (ecriture lente)
    $prefix = if ($null -eq $head) { '' } else { ((T '[tête {0}] ') -f "$head") }
    return @{ Head = $head; Prefix = $prefix; Results = @{}; Est = @{}; Sig = @{}; Fit = $null; Slope = $null; Profile = ''; Verify = @{} }
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
    $slow = [bool]$chkWSlow.Checked
    if ($slow) {
        $imgSet = Get-ImageTrackSet $img
        if ($null -ne $imgSet -and @($imgSet.Keys | Where-Object { $_ -like '*.1' }).Count -eq 0) {
            [void][System.Windows.Forms.MessageBox]::Show((T "Calibration par tête impossible : l'image n'a qu'une face, gw n'écrirait pas la tête 1.`nDécocher « Écriture lente » pour une calibration commune."),(T 'Calibration precomp'),'OK','Warning'); return
        }
    }
    if ($fine) { $cyls = @(0..$maxCyl) }
    else { $cyls = @(0..$maxCyl | Where-Object { $_ % 10 -eq 0 }); if ($cyls -notcontains $maxCyl) { $cyls += $maxCyl } }
    $cyls = @($cyls | Sort-Object -Unique)
    $nPassEst = $script:CalCoarse.Count + $script:CalMaxVerify
    $minutes = [math]::Max(1, [math]::Round($cyls.Count * 2 * 1.4 * $nPassEst / 60, 0))
    $modeTxt = if ($fine) { (T 'test fin, tous les cylindres') } else { (T 'test standard, un cylindre sur 10') }
    if ($slow) { $modeTxt += (T ', une courbe par tête (écriture lente)') }
    $famTxt = Get-CalibFamilyName $family
    $cylList = Format-CylList $cyls
    $script:AlignLoop = $false; $script:AlignNextAt = $null
    $r = [System.Windows.Forms.MessageBox]::Show(
        ((T "Calibration de la précompensation sur le lecteur {0} ({1}).`n`nImage : {2}, famille {3}, {4}.`nCylindres de test : {5} (2 faces), ÉCRASÉS à chaque passe. Durée estimée : {6} min pour {7} passes.`n`nInsère une disquette vierge ou sans valeur, puis confirme.") -f "$($cmbDrive.Text)", "$modeTxt", "$([System.IO.Path]::GetFileName($img))", "$famTxt", "$cylSrc", "$cylList", "$minutes", "$nPassEst"),
        (T 'Calibration precomp'), 'OKCancel', 'Warning')
    if ($r -ne 'OK') { return }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    # Ecriture lente : une unite par tete (mesures, courbe et verification separees) ; sinon une unite pour les deux tetes
    # @() autour du if : une seule unite resterait sinon une hashtable nue ($cal.Units[0] = $null)
    $units = @(if ($slow) { (New-CalibUnit 0), (New-CalibUnit 1) } else { New-CalibUnit $null })
    foreach ($u in $units) { foreach ($c in $cyls) { $u.Results[[int]$c] = @{} } }
    $script:Cal = @{
        Mode = $(if ($fine) { 'fine' } else { 'std' }); Cyls = $cyls; MaxCyl = $maxCyl; Family = $family; Slow = $slow
        Image = $img; Drive = $cmbDrive.Text; TSpec = "c=${cylList}:h=0-1"; CylList = $cylList
        Stage = 'coarse'; Values = @($script:CalCoarse); Index = 0; Value = 0; ValueTxt = ''; Spec = ''
        Units = $units; VerifyCount = 0
        Scp = (Join-Path $script:TempDir 'precomp-calib.scp'); Writes = (New-Object System.Collections.Queue); ReadArgs = @()
        # Progression globale : passes faites / prevues, durees mesurees par phase, estimation initiale 0,7 s par piste et par phase
        StartTime = (Get-Date); PassStart = (Get-Date); PhaseStart = (Get-Date); Phase = 'write'
        PassesDone = 0; TotalPasses = $nPassEst; WriteDurs = @(); ReadDurs = @(); EstTrack = 0.7
    }
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
    # Une passe = une ou deux commandes gw write puis une relecture en flux de tous les cylindres de test.
    # Passes de mesure : meme valeur pour les deux tetes, une commande. Verification en ecriture lente : tete 0
    # puis tete 1, chacune avec son profil (gw applique --precomp par cylindre seulement).
    $cal = $script:Cal
    $writes = @()
    if ($cal.Stage -eq 'coarse') {
        $cal.Value = [int]$cal.Values[$cal.Index]; $cal.Spec = "0=$($cal.Value)"; $cal.ValueTxt = "$($cal.Value) ns"
        Append-Log ((T "Calibration : passe de mesure {0}/{1}, precomp {2} ns") -f "$($cal.Index + 1)", "$($cal.Values.Count)", "$($cal.Value)")
        $writes += ,@($cal.TSpec, $cal.Spec)
    } elseif ($cal.Slow) {
        $cal.ValueTxt = (T 'profil')
        Append-Log ((T "Calibration : passe de vérification {0}/{1}, tête 0 puis tête 1, profils {2} et {3}") -f "$($cal.VerifyCount)", "$($script:CalMaxVerify)", "$($cal.Units[0].Profile)", "$($cal.Units[1].Profile)")
        foreach ($u in $cal.Units) { $writes += ,@("c=$($cal.CylList):h=$($u.Head)", $u.Profile) }
    } else {
        $cal.Spec = $cal.Units[0].Profile; $cal.ValueTxt = (T 'profil')
        Append-Log ((T "Calibration : passe de vérification {0}/{1}, profil {2}") -f "$($cal.VerifyCount)", "$($script:CalMaxVerify)", "$($cal.Spec)")
        $writes += ,@($cal.TSpec, $cal.Spec)
    }
    if (Test-Path -LiteralPath $cal.Scp) { Remove-Item -LiteralPath $cal.Scp -Force }
    $cal.Writes.Clear()
    foreach ($w in $writes) {
        $cal.Writes.Enqueue([string[]](@('write') + (Get-CommonArgs) + @('--pre-erase', '--no-verify') + (Get-WriteFormatArgs) + @("--tracks=$($w[0])", '--precomp', $w[1], "`"$($cal.Image)`"")))
    }
    $cal.ReadArgs  = @('read') + (Get-CommonArgs) + @('--revs=3', "--tracks=$($cal.TSpec)", "`"$($cal.Scp)`"")
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

function Set-CalibEstimates($u) {
    # Droite decalage = b + a * precomp par cylindre (moindres carres sur les passes de mesure) ;
    # pente mise en commun (mediane) pour les cylindres dont la pente propre n est pas fiable.
    $cal = $script:Cal
    $fits = @{}; $slopes = @()
    foreach ($c in $cal.Cyls) {
        $r = $u.Results[[int]$c]
        if ($r.Count -lt 2) { continue }
        $xs = @($r.Keys | Sort-Object); $ys = @($xs | ForEach-Object { [double]$r[$_].Shift })
        $mx = ($xs | Measure-Object -Average).Average; $my = ($ys | Measure-Object -Average).Average
        $sxx = 0.0; $sxy = 0.0
        for ($i = 0; $i -lt $xs.Count; $i++) { $sxx += ($xs[$i] - $mx) * ($xs[$i] - $mx); $sxy += ($xs[$i] - $mx) * ($ys[$i] - $my) }
        if ($sxx -le 0) { continue }
        $a = $sxy / $sxx
        $sse = 0.0
        for ($i = 0; $i -lt $xs.Count; $i++) { $e = $ys[$i] - ($my + $a * ($xs[$i] - $mx)); $sse += $e * $e }
        $fits[[int]$c] = @{ A = $a; Mx = $mx; My = $my; S = [math]::Sqrt($sse / [math]::Max(1, $xs.Count - 2)) }
        if ($a -lt -0.2) { $slopes += $a }
    }
    if ($fits.Count -eq 0) { Append-Log ($u.Prefix + (T 'Calibration : aucune mesure exploitable pour estimer la précompensation.')); return $false }
    # Tete seule sans aucune pente propre : le decalage ne suit pas la precomp ecrite, la face lue n a pas ete ecrite
    # (format simple face : gw saute la tete 1) ; la pente de repli donnerait une courbe sans signification.
    if ($null -ne $u.Head -and $slopes.Count -eq 0) { Append-Log ($u.Prefix + (T 'Calibration : le décalage ne varie pas avec la précompensation écrite, cette face n''a pas été écrite (format simple face ?).')); return $false }
    $pooled = $null
    if ($slopes.Count -gt 0) { $s = @($slopes | Sort-Object); $pooled = $s[[int][math]::Floor($s.Count / 2)] }
    $u.Slope = if ($null -ne $pooled) { $pooled } else { -2.0 }   # -2 : valeur theorique (deux transitions par intervalle)
    $u.Est = @{}; $u.Sig = @{}
    foreach ($c in @($fits.Keys)) {
        $f = $fits[$c]
        $own = $f.A -lt -0.2
        $a = if ($own) { $f.A } else { $u.Slope }
        $b = $f.My - $a * $f.Mx
        $v0 = -$b / $a
        $u.Est[[int]$c] = [math]::Max(0, [math]::Min($script:CalMaxNs, $v0))
        # Incertitude (ns) : ecart-type des mesures autour de la droite rapporte a la pente ; 10 ns si pente commune
        $u.Sig[[int]$c] = if ($own) { [math]::Max(1.0, [math]::Min(50.0, $f.S / [math]::Abs($a))) } else { 10.0 }
    }
    $estTxt = (@($u.Est.Keys | Sort-Object | ForEach-Object { "c$_=$([math]::Round($u.Est[$_], 0))" })) -join ' '
    Append-Log ($u.Prefix + ((T "Pente moyenne : {0} ns de décalage par ns de precomp ; estimation par cylindre : {1}") -f "$([math]::Round($u.Slope, 2))", "$estTxt"))
    return $true
}

function Invoke-CalibAnalysis {
    $cal = $script:Cal
    if (-not $cal) { return }
    if (-not (Test-Path -LiteralPath $cal.Scp)) { Append-Log (T 'Calibration : fichier SCP absent, analyse impossible.'); Stop-PrecompCalib; return }
    try { $tracks = Read-ScpFile $cal.Scp } catch { Append-Log ((T "Calibration : {0}") -f "$($_.Exception.Message)"); Stop-PrecompCalib; return }
    $cal.ReadDurs += ((Get-Date) - $cal.PhaseStart).TotalSeconds
    $cal.PassesDone++
    foreach ($u in $cal.Units) {
        # Moyenne des deux faces (profil commun) ou face de l unite seule (ecriture lente)
        $heads = if ($null -eq $u.Head) { @(0, 1) } else { @([int]$u.Head) }
        $shifts = @(); $scores = @(); $bad = @()
        foreach ($c in $cal.Cyls) {
            $sv = @(); $jv = @()
            foreach ($h in $heads) {
                $tn = [int]$c * 2 + $h
                if (-not $tracks.ContainsKey($tn)) { continue }
                $s = Get-CalibTrackShift $tracks[$tn]; if (-not [double]::IsNaN($s)) { $sv += $s }
                $j = Get-CalibTrackScore $tracks[$tn]; if ($j -lt 9999) { $jv += $j }
            }
            if ($sv.Count -eq 0) { $bad += $c; continue }
            $sh = ($sv | Measure-Object -Average).Average
            $jt = if ($jv.Count -gt 0) { ($jv | Measure-Object -Average).Average } else { [double]::NaN }
            if ($cal.Stage -eq 'coarse') { $u.Results[[int]$c][[int]$cal.Value] = @{ Shift = $sh; Score = $jt } }
            else { $u.Verify[[int]$c] = @{ Shift = $sh; Score = $jt } }
            $shifts += $sh; if (-not [double]::IsNaN($jt)) { $scores += $jt }
        }
        $badTxt = if ($bad.Count -gt 0) { ((T ", illisibles : {0}") -f "$($bad -join ',')") } else { '' }
        if ($shifts.Count -gt 0) {
            $st = $shifts | Measure-Object -Average -Minimum -Maximum
            $scTxt = if ($scores.Count -gt 0) { "$([math]::Round(($scores | Measure-Object -Average).Average, 0))" } else { '-' }
            Append-Log ((T "  {0} : décalage résiduel moyen {1} ns (de {2} à {3}), score jitter moyen {4}, {5} cylindre(s){6}") -f "$($u.Prefix)$($cal.ValueTxt)", "$([math]::Round($st.Average, 1))", "$([math]::Round($st.Minimum, 1))", "$([math]::Round($st.Maximum, 1))", "$scTxt", "$($shifts.Count)", "$badTxt")
        } else {
            Append-Log ((T "  {0} : aucun cylindre mesurable{1}") -f "$($u.Prefix)$($cal.ValueTxt)", "$badTxt")
        }
    }
    if ($cal.Stage -eq 'coarse') {
        $cal.Index++
        if ($cal.Index -lt $cal.Values.Count) { New-CalibPass; return }
        foreach ($u in $cal.Units) {
            if (-not (Set-CalibEstimates $u)) { $cal.TotalPasses = $cal.PassesDone; Complete-PrecompCalib; return }
        }
        foreach ($u in $cal.Units) {
            $u.Fit = Fit-PrecompCurve $u.Est $u.Sig $cal.MaxCyl
            $u.Profile = Build-CurveProfile $u.Fit.Values
            Append-Log ($u.Prefix + ((T "Courbe ajustée : {0} (écart réduit {1}), de {2} ns au cylindre 0 à {3} ns au cylindre {4} ; profil : {5}") -f (Get-CurveModelName $u.Fit.Model), "$([math]::Round($u.Fit.Chi, 2))", "$($u.Fit.Values[0])", "$($u.Fit.Values[-1])", "$($cal.MaxCyl)", "$($u.Profile)"))
            $u.Verify = @{}
        }
        $cal.Stage = 'verify'; $cal.VerifyCount = 1
        New-CalibPass; return
    }
    # Verification : correction locale de la courbe aux cylindres dont le residu depasse la tolerance
    # (residu / pente), interpolee entre cylindres verifies ; les cylindres dans la tolerance ancrent la courbe.
    # Ecriture lente : chaque tete est corrigee d apres sa propre mesure ; une nouvelle passe reverifie les deux.
    $again = $false
    foreach ($u in $cal.Units) {
        $corr = 0; $delta = @{}
        foreach ($c in @($u.Verify.Keys)) {
            $res = [double]$u.Verify[$c].Shift
            $d = 0.0
            if ([math]::Abs($res) -gt $script:CalResidual) {
                $d = $res / [math]::Abs($u.Slope)
                $applied = Get-SpecValue $u.Profile ([int]$c)
                $u.Est[[int]$c] = [math]::Max(0, [math]::Min($script:CalMaxNs, $applied + $d))
                $u.Sig[[int]$c] = [math]::Max(1.0, $script:CalResidual / [math]::Abs($u.Slope))   # mesure directe a la valeur appliquee
                $corr++
            }
            $delta[[int]$c] = $d
        }
        if ($corr -eq 0 -or $cal.VerifyCount -ge $script:CalMaxVerify) { continue }
        $newVals = Add-CurveCorrection $u.Fit.Values $delta
        $newProfile = Build-CurveProfile $newVals
        if ($newProfile -eq $u.Profile) { continue }
        $base = ([string]$u.Fit.Model) -replace '\+c$', ''
        $u.Fit = @{ Model = "$base+c"; A = $u.Fit.A; B = $u.Fit.B; Chi = $u.Fit.Chi; Values = $newVals }
        $u.Profile = $newProfile
        Append-Log ($u.Prefix + ((T "{0} cylindre(s) corrigé(s) de plus de {1} ns de résidu, nouveau profil : {2}") -f "$corr", "$($script:CalResidual)", "$($u.Profile)"))
        $again = $true
    }
    if ($again) {
        $cal.VerifyCount++
        foreach ($u in $cal.Units) { $u.Verify = @{} }
        New-CalibPass; return
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
    if (@($cal.Units | Where-Object { -not $_.Profile -or -not $_.Fit }).Count -gt 0) { Append-Log (T 'Calibration precomp : aucune mesure exploitable, profil inchangé.'); return }
    foreach ($u in $cal.Units) {
        if ($u.Verify.Count -eq 0) { continue }
        $resTxt = (@($u.Verify.Keys | Sort-Object | ForEach-Object { "c$_=$('{0:+0.0;-0.0;0.0}' -f [double]$u.Verify[$_].Shift)" })) -join ' '
        Append-Log ($u.Prefix + ((T "Résidu après vérification (ns, tolérance {0}) : {1}") -f "$($script:CalResidual)", "$resTxt"))
    }
    $famTxt = Get-CalibFamilyName $cal.Family
    # Profil commun : remplace celui de la famille. Ecriture lente : courbes par tete, le profil commun est conserve.
    if (-not $cal.Slow) {
        $spec = $cal.Units[0].Profile
        if ($cal.Family -eq 'long') { $script:PrecompLong = $spec } else { $script:PrecompStd = $spec }
    }
    $date = Get-Date -Format 'dd/MM/yyyy HH:mm'
    foreach ($u in $cal.Units) {
        $key = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }
        $cs = @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
        $script:PrecompCurves[$key] = @{
            Family = $famTxt; Head = $u.Head; Drive = $cal.Drive; Date = $date; Model = $u.Fit.Model; Spec = $u.Profile
            Values = [int[]]@($u.Fit.Values); Cyls = [int[]]$cs
            Ys = [double[]]@($cs | ForEach-Object { [math]::Round([double]$u.Est[$_], 1) })
            Sig = [double[]]@($cs | ForEach-Object { [math]::Round($(if ($u.Sig.ContainsKey($_)) { [double]$u.Sig[$_] } else { 5.0 }), 1) })
        }
    }
    $cmbWProfile.SelectedIndex = 0                 # Auto : applique le profil de la famille de l image
    Update-PrecompForImage $txtWFile.Text
    if ($cal.Slow) {
        $v0 = @($cal.Units[0].Fit.Values); $v1 = @($cal.Units[1].Fit.Values)
        $lblWProfileInfo.Text = ((T "Profils {0} par tête calibrés le {1} sur le lecteur {2} : tête 0 de {3} à {4} ns, tête 1 de {5} à {6} ns, une valeur par cylindre (bouton Courbe).") -f "$famTxt", "$date", "$($cal.Drive)", "$($v0[0])", "$($v0[-1])", "$($v1[0])", "$($v1[-1])")
    } else {
        $v = @($cal.Units[0].Fit.Values)
        $lblWProfileInfo.Text = ((T "Profil {0} calibré le {1} sur le lecteur {2} : courbe {3}, de {4} à {5} ns, une valeur par cylindre (bouton Courbe).") -f "$famTxt", "$date", "$($cal.Drive)", (Get-CurveModelName $cal.Units[0].Fit.Model), "$($v[0])", "$($v[-1])")
    }
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
    if ($cal.Slow) { Append-Log ((T "Profils par tête enregistrés dans la configuration et appliqués par le mode Auto en écriture lente à toute image {0}.") -f "$famTxt") }
    else { Append-Log ((T "Profil enregistré dans la configuration et appliqué par le mode Auto à toute image {0}.") -f "$famTxt") }
    [void](Save-Config)
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

function Invoke-WriteQueueNext {
    # Ecriture lente : commande gw write suivante (une par tete) ; pistes et retries de la precedente cumules pour le controle
    if ($script:WriteQueue.Count -eq 0) { return }
    Merge-RepRetries
    Start-Gw ([string[]]$script:WriteQueue.Dequeue())
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

function Get-WriteCheckBlocker([string]$path, [string]$fmt) {
    # Raison pour laquelle l analyse de flux (calibree MFM double densite, cellule 2 us) ne s applique pas ; $null sinon
    if ($chkWHard.Checked) { return (T 'secteurs durs') }
    if ($chkWTG43.Checked) { return (T 'lecteur 8 pouces (TG43)') }
    if ($fmt -match '(_hd|\.(1200|1440|1680|dmf|2880))$' -or $fmt -match '^raw\.(500|1000)$') { return ((T "format haute densité {0}") -f "$fmt") }
    if ($fmt -match '^(commodore\.15[47]1|mac\.|apple2\.)') { return ((T "format GCR {0}") -f "$fmt") }
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    if (@('.d64', '.d71', '.g64', '.nib', '.woz', '.do', '.po') -contains $ext) { return ((T "image GCR {0}") -f "$ext") }
    try {
        if ($ext -eq '.adf' -and (Get-Item -LiteralPath $path).Length -eq 1802240) { return (T 'ADF haute densité') }
        $info = $null
        switch ($ext) { '.ipf' { $info = Get-IpfCellInfo $path } '.hfe' { $info = Get-HfeCellInfo $path } }
        if ($null -ne $info -and $info.CellNs -lt 1500) { return ((T "image haute densité, cellule {0} ns") -f "$([math]::Round($info.CellNs, 0))") }
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
    }
    # Une mesure continue de l onglet Qualite ecraserait le resultat du controle : elle est arretee
    $script:AlignLoop = $false; $script:AlignNextAt = $null; $script:AlLastMove = 0
    $lblWCal.Text = (T 'Écriture en cours, contrôle de toutes les pistes ensuite.')
    $pbWCal.Visible = $false; $lblWCal.Visible = $true
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
    if (-not $script:ScpStatsOk) { Append-Log (T 'Contrôle après écriture : module d''analyse SCP indisponible, contrôle ignoré.'); $script:Rep = $null; return }
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
        $rep.State[$k] = $m
        if ($m.Bad -or $m.Level -ge 2) { $crit += $k } elseif ($m.Level -eq 1) { $watch += $k } else { $healthy++ }
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
    if ($rep.Round -eq 0 -and $expected.Count -ge 20 -and $weak.Count * 2 -gt $expected.Count) {
        $rep.Safety = $true
        Append-Log ((T "Plus de la moitié des pistes sont faibles ({0}/{1}) : format non MFM, disquette inadaptée ou lecteur en défaut. Aucune réécriture automatique.") -f "$($weak.Count)", "$($expected.Count)")
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
    $lvAl.Columns[1].Width = 200
    $lvAl.BeginUpdate()
    try {
        $lvAl.Items.Clear()
        foreach ($k in $keys) {
            $m = $rep.State[$k]
            $mark = ''
            if ($rep.Rewrites.ContainsKey($k)) { $mark = ((T " (réécrite x{0})") -f "$($rep.Rewrites[$k])") }
            elseif ($rep.Retries.ContainsKey($k)) { $mark = ((T " (retries x{0})") -f "$($rep.Retries[$k])") }
            [void]$lvAl.Items.Add((New-AlignRow $k $m $mark '-' -1))
            if ($m.Bad) { $last[$k] = @{ Score = 9999; Jitter = 0; Asym = 0; Err = 0; Stab = 0; Cell = 0 }; continue }
            $last[$k] = @{ Score = $m.Score; Jitter = $m.J; Asym = $m.Asym; Err = $m.Ooc; Stab = $m.Stab; Cell = $m.Cell }
            $total += $m.Score; $count++
        }
    } finally { $lvAl.EndUpdate() }
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
    if ($GwError) {
        # gw a echoue pendant une passe de reecriture : les pistes de la passe restent faibles
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE interrompu par une erreur gw à la passe {0}/{1} : {2} piste(s) faible(s) ou non remesurée(s) : {3}  ->  support fatigué ou lecteur en défaut") -f "$($rep.Round)", "$($rep.Max)", "$($weak.Count)", "$(Format-TrackList $weak)"); $lvl = 3
    } elseif ($n -eq 0) {
        $txt = (T 'CONTRÔLE APRÈS ÉCRITURE : aucune piste mesurée.'); $lvl = 3
    } elseif ($weak.Count -eq 0) {
        $txt = ((T "CONTRÔLE APRÈS ÉCRITURE : {0}/{0} pistes saines") -f "$n")
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
    $tabs.SelectedTab = $tabAl
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
            $rep.State[$k] = Get-TrackMetrics $t[$tn]
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
    $txtWPrecomp1.Text = $script:PrecompStd
    $chkWSlow.Checked = $false
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
    $numPin.Value = 2
    $cmbPinLvl.SelectedIndex = 0

    foreach ($k in $script:DelayCtrls.Keys) {
        $c = $script:DelayCtrls[$k]
        $c.Chk.Checked = $false
        $c.Num.Value = $c.Def
    }

    $cmbHelpAct.SelectedItem = 'write'
    $txtC.Text = 'write --pre-erase --erase-empty --retries=10 --precomp 40=140 "jeu.ipf"'
    Update-CurveButton $txtWFile.Text
}

function Save-Config {
    $delays = @{}
    foreach ($k in $script:DelayCtrls.Keys) {
        $c = $script:DelayCtrls[$k]
        $delays[$k] = @{ on = [bool]$c.Chk.Checked; val = [int]$c.Num.Value }
    }
    $curvesCfg = [ordered]@{}
    foreach ($k in $script:CurveKeys) { $curvesCfg[$k] = ConvertTo-CurveConfig $script:PrecompCurves[$k] }
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
            precompOn = [bool]$chkWPrecomp.Checked; precomp = $txtWPrecomp.Text; precomp1 = $txtWPrecomp1.Text; slowWrite = [bool]$chkWSlow.Checked
            precompProfile = $cmbWProfile.Text; postCheck = [bool]$chkWPostCheck.Checked; repairMax = [int]$numWRepair.Value; calMode = [int]$cmbWCalMode.SelectedIndex
            precompStd = $script:PrecompStd; precompLong = $script:PrecompLong; precompThresholdNs = [int]$script:PrecompThresholdNs
            precompCurves = $curvesCfg
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
    $pcv = Get-Cfg $w 'precompCurves' $null
    if ($pcv) { foreach ($fam in $script:CurveKeys) { $script:PrecompCurves[$fam] = ConvertFrom-CurveConfig (Get-Cfg $pcv $fam $null) } }
    $script:PrecompThresholdNs = [int](Get-Cfg $w 'precompThresholdNs' $script:PrecompThresholdNs)
    Set-Combo $cmbWProfile (Get-Cfg $w 'precompProfile' (T 'Auto (selon image)'))
    $chkWPostCheck.Checked = [bool](Get-Cfg $w 'postCheck' $true)
    $rm = [int](Get-Cfg $w 'repairMax' 3); $numWRepair.Value = [math]::Max(0, [math]::Min(10, $rm))
    $numWRepair.Enabled = $chkWPostCheck.Checked; $lblWRepair.Enabled = $chkWPostCheck.Checked
    $cm = [int](Get-Cfg $w 'calMode' 0); if ($cm -ge 0 -and $cm -lt $cmbWCalMode.Items.Count) { $cmbWCalMode.SelectedIndex = $cm }
    $txtWPrecomp.Text  = [string](Get-Cfg $w 'precomp' $script:PrecompStd)
    $txtWPrecomp1.Text = [string](Get-Cfg $w 'precomp1' $txtWPrecomp.Text)
    $chkWSlow.Checked  = [bool](Get-Cfg $w 'slowWrite' $false)
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
    # Lignes de synthese du controle apres ecriture : simples comptes par etat (« 0 critique(s) » n est pas une erreur)
    if ($line -match '^(Contrôle complet|Full check|Remesure après réécriture|Re-measure after rewrite)\b') { return $script:LogColors.std }
    if ($line -match 'FATAL|ERREUR|ERROR|ECHEC|ÉCHEC|FAILED|Command Failed|Write ?Protect|CRITIQUE|CRITICAL|ILLISIBLE|UNREADABLE|introuvable|not found|code retour : [1-9]|exit code: [1-9]|support fatigué|worn media|réécriture automatique non lancée|automatic rewrite not started') { return $script:LogColors.err }
    if ($line -match 'Verify Failure|Retry #|retries|À SURVEILLER|TO WATCH|marginal|DIFF[EÉ]RENT|Interrompu|Interrupted|aborted|non applicable|not applicable|réécriture automatique désactivée|automatic rewrite disabled|Aucune réécriture automatique|No automatic rewrite') { return $script:LogColors.warn }
    if ($line -match 'All tracks verified|code retour : 0|exit code: 0|SAIN|HEALTHY|IDENTIQUE|IDENTICAL|EXCELLENT|aucune piste n|no track needed') { return $script:LogColors.ok }
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

function Reset-GwSequence {
    # gw n a pas pu etre lance : la sequence en cours (ecriture controlee, calibration, comparaison)
    # est abandonnee, sinon le prochain gw termine avec le code 0 reprendrait ses etapes, ecritures comprises.
    $script:Chain.Clear(); $script:WriteQueue.Clear()
    if ($script:Rep) { Stop-WriteCheck }
    if ($script:Cal) { Stop-PrecompCalib }
    if ($txtCmpResult.Text -like ((T 'Comparaison en cours') + '*')) { $txtCmpResult.Text = ((T "ÉCHEC : {0}") -f (T 'gw n''a pas pu être lancé.')) }
}

# Sortie de gw capturee via redirection fichier puis relue par le timer.
function Start-Gw([string[]]$gwArgs) {
    $exe = $script:GwExe
    if (-not (Test-Path -LiteralPath $exe)) {
        Reset-GwSequence
        [void][System.Windows.Forms.MessageBox]::Show(((T "gw.exe introuvable : {0}`n`nPlace ce script dans le même répertoire que gw.exe.") -f "$exe"),(T 'Erreur'),'OK','Error'); return
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) {
        Append-Log ((T "gw déjà en cours : commande ignorée ({0}).") -f "$($gwArgs -join ' ')")
        if ($script:Chain.Count -gt 0 -or $script:Rep -or $script:Cal) { Reset-GwSequence }
        return
    }

    [void](Save-Config)

    $script:GwIsWrite = ($gwArgs.Count -gt 0 -and $gwArgs[0] -eq 'write')
    $verbs = @{ write=(T 'Écriture'); read=(T 'Lecture'); erase=(T 'Effacement'); convert='Conversion'; clean=(T 'Nettoyage'); rpm=(T 'Mesure de vitesse'); update=(T 'Mise à jour firmware') }
    $first = if ($gwArgs.Count -gt 0) { ($gwArgs[0] -split ' ')[0] } else { '' }
    Start-Progress $(if ($verbs.ContainsKey($first)) { $verbs[$first] } else { "gw $first" })
    if ($script:GwIsWrite) { $script:WriteRetries = @{}; $script:WriteTracks = @{} }
    $script:GwWriteSummary = $false
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
            $script:OutStdoutReader = $null; $script:OutStderrReader = $null
            $script:OutStdoutTask = $null; $script:OutStderrTask = $null
            Stop-Progress $code
            $wasWrite = [bool]$script:GwIsWrite
            if ($script:GwIsWrite) {
                if ($script:WriteRetries.Count -gt 0) {
                    Append-Log ((T "Pistes ayant nécessité des retries : ") + (($script:WriteRetries.Keys | Sort-Object | ForEach-Object { ((T "{0} (x{1})") -f "$_", "$($script:WriteRetries[$_])") }) -join ', '))
                } elseif ($code -eq 0 -and $script:GwWriteSummary) { Append-Log (T 'Écriture : aucune piste n''a nécessité de retry.') }
                $script:GwIsWrite = $false
            }
            $elapsed = if ($script:GwStart -is [datetime]) { [math]::Round(((Get-Date) - $script:GwStart).TotalSeconds, 1) } else { 0 }
            Append-Log ((T "<<< Terminé (code retour : {0}, {1} s, {2} ligne(s) reçues)") -f "$code", "$elapsed", "$($script:GwLines)")
            # Arret silencieux avec le code 0 (ex. « Command Failed: WriteProtected ») : pas de controle ni d etape suivante,
            # ils masqueraient le probleme. Ecriture : gw imprime toujours une ligne de bilan quand il va au bout (verification
            # comprise), quel que soit le nombre de pistes de l image. Autres commandes : moins de la moitie des pistes annoncees.
            $incomplete = if ($wasWrite) { $code -eq 0 -and -not $script:GwWriteSummary }
                          else { $code -eq 0 -and $script:ProgTotal -gt 0 -and $script:ProgSeen.Count * 2 -lt $script:ProgTotal }
            if ($incomplete) {
                Append-Log ((T "ERREUR : opération incomplète, gw s'est arrêté après {0} piste(s) sur {1} annoncées avec le code 0. Vérifier le lecteur, le câble USB et l'alimentation, puis relancer.") -f "$($script:ProgSeen.Count)", "$($script:ProgTotal)")
                $script:Chain.Clear(); $script:WriteQueue.Clear()
                if ($script:Rep) { Stop-WriteCheck -GwError }
                if ($script:Cal) { Stop-PrecompCalib }
            }
            Append-Log ''
            $script:GwProc = $null
            Set-Busy $false
            if ($script:Chain.Count -gt 0) {
                if ($code -eq 0) {
                    Invoke-NextChainStep
                } else {
                    $script:Chain.Clear(); $script:WriteQueue.Clear()
                    Append-Log (T 'Séquence interrompue : gw a retourné une erreur.')
                    if ($txtCmpResult.Text -like ((T 'Comparaison en cours') + '*')) { $txtCmpResult.Text = ((T "ÉCHEC : gw a retourné le code {0}. Voir le journal.") -f "$code") }
                    if ($script:AlignLoop) { $script:AlignLoop = $false; $script:AlignNextAt = $null; $lblAlVerdict.Text = (T 'Mesure interrompue (erreur gw)') }
                    if ($script:Rep) { Stop-WriteCheck -GwError }
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
    if ($script:AlignLoop -and $script:AlignNextAt -and -not $script:GwProc -and -not $script:Cal -and -not $script:Rep -and $script:Chain.Count -eq 0 -and (Get-Date) -ge $script:AlignNextAt) {
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
    $script:UiReady = $true
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
    try { Update-Library; if ($txtWFile.Text) { Update-PrecompForImage $txtWFile.Text } else { Update-CurveButton '' } } finally { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
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
Update-CurveButton ''

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
