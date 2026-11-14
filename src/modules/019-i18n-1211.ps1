# --- Textes de la 12.11 ----------------------------------------------------------------------------------------------
# Suite de la table $script:I18n (010-i18n) : cle francaise -> texte anglais, memes regles (placeholders {n} identiques,
# `n pour les retours a la ligne). Une section par lot de la 12.11 : chaque lot y ajoute ses entrees dans le meme commit
# que son code. Depuis la 12.11, le controle de la source (tests\check-source.ps1, cas I1) n admet plus aucune cle de
# T() sans entree : un texte identique dans les deux langues recoit une entree explicite. Une cle deja definie par un
# module precedent n est jamais redefinie ici (sa traduction changerait partout ou elle sert).

# --- L1 : textes de la 12.10 sans entree anglaise, reperes raccourcis de deux champs vides -----------------------------
# Huit textes identiques dans les deux langues, entree explicite comme « Format    : {0} » (010)
# Resultat de la comparaison (180)
$script:I18n['SHA1 ref  : {0}'] = 'SHA1 ref  : {0}'
# Tendance de l alignement (190)
$script:I18n['   stable'] = '   stable'
# Profil de precompensation : liste de l onglet Ecriture (520), profil force (220), famille d une courbe (230)
$script:I18n['Standard 2 us'] = 'Standard 2 us'
# Texte du profil choisi d apres l image (220)
$script:I18n['LONG TRACK ({0})'] = 'LONG TRACK ({0})'
$script:I18n['standard 2 us ({0})'] = 'standard 2 us ({0})'
# Pistes reessayees par une ecriture (600)
$script:I18n['{0} (x{1})'] = '{0} (x{1})'
# Journal du demarrage (600)
$script:I18n['Extraction  : {0}'] = 'Extraction  : {0}'
$script:I18n['Index       : {0}'] = 'Index       : {0}'
# Reperes des champs vides (540), raccourcis pour tenir dans leur champ : racine de la Bibliotheque (240 px), dossier de
# la restauration (256 px ; fin du dossier par defaut de Get-RestoreDefaultDir, 300)
$script:I18n['Dossier de vos images disque'] = 'Folder of your disk images'
$script:I18n['…\Greaseweazle Studio\Restaurations'] = '…\Greaseweazle Studio\Restorations'

# --- L2 : lancement de gw (110) ----------------------------------------------------------------------------------------
# Journal : erreur de l application apres le demarrage de gw (second try de Start-Gw) ; gw reste suivi jusqu a sa fin
$script:I18n["gw est lancé, mais une erreur a suivi son démarrage : {0}. La commande reste suivie jusqu'à sa fin ; « Arrêter » l'interrompt."] = 'gw has started, but an error followed its start: {0}. The command is still tracked until it ends; "Stop" interrupts it.'

# --- L3 : asymetrie signee de l onglet « Qualite & alignement » et du controle apres ecriture (190, 170, 195) ----------
# Resume de l asymetrie d un resultat (Get-AsymSummaryText, 190) : journal de la mesure et du controle apres ecriture,
# infobulle de la carte, en-tete de l export. Phrases conditionnelles (« comme apres une ecriture... ») : la regle du
# signe est etablie sur les lectures d un seul lecteur
$script:I18n["Asymétrie positive sur {0} piste(s) sur {1} (médiane {2}) : les intervalles longs sont relus trop longs, comme après une écriture au-dessus du niveau de précompensation qui centre les intervalles pour ce lecteur. Elle compte pour {3} point(s) du score moyen et ne change pas l'état des pistes."] = 'Positive asymmetry on {0} of {1} track(s) (median {2}): long intervals are read back too long, as after a write above the precompensation level that centres the intervals for this drive. It accounts for {3} point(s) of the mean score and does not change the track status.'
$script:I18n["Asymétrie négative sur {0} piste(s) sur {1} (médiane {2}) : les intervalles longs sont relus trop courts, comme après une écriture au-dessous du niveau de précompensation qui centre les intervalles pour ce lecteur. Elle compte pour {3} point(s) du score moyen et ne change pas l'état des pistes."] = 'Negative asymmetry on {0} of {1} track(s) (median {2}): long intervals are read back too short, as after a write below the precompensation level that centres the intervals for this drive. It accounts for {3} point(s) of the mean score and does not change the track status.'
# Sans signe commun : forme courte, dans l en-tete de l export seulement
$script:I18n['médiane {0}, sans signe commun ; {1} point(s) du score moyen'] = 'median {0}, no common sign; {1} point(s) of the mean score'
# Infobulle du tableau (Update-QualityTip, 190) : ligne du signe de la colonne « Asym. »
$script:I18n["Signe de l'asymétrie : + intervalles longs relus trop longs (comme après une écriture au-dessus de la précompensation qui les centre pour ce lecteur) ; - trop courts (comme après une écriture au-dessous) ; sans signe : écarts de sens opposés."] = 'Asymmetry sign: + long intervals read back too long (as after a write above the precompensation that centres them for this drive); - too short (as after a write below it); no sign: deviations in opposite directions.'

# --- L4 : plafond de precompensation d une disquette lie a la cellule de son image (260, 265, 270) ---------------------
# Journal du debut de la mesure complete de cette disquette (Get-DiskBoundText, 265) : borne au-dela du seuil, au quart de
# la cellule de la piste ecrite ; cellule inconnue (470 ns) : ligne de la 12.10 « ... {0} ns ; au-dela de {1} ns... » (010)
$script:I18n["Borne de la courbe de cette disquette : {0} ns, le quart de la cellule de l'image ({2} ns), {3} ns au plus ; au-delà de {1} ns, contrôle après écriture imposé."] = 'Curve bound for this disk: {0} ns, a quarter of the image cell ({2} ns), {3} ns at most; above {1} ns, post-write check enforced.'
# Conseil « machine cible » (Get-DiskOverAdviceText, 265), au journal apres chaque ligne « ... au-dela de {0} ns ... »
$script:I18n["Au-delà de {0} ns, la calibration ne compense que la chaîne d'écriture et de relecture de ce lecteur : essayez la disquette écrite sur la machine à laquelle elle est destinée (un vrai Amiga, par exemple) avant de vous y fier."] = "Above {0} ns, calibration only compensates this drive's own write and read chain: try the written disk on the machine it is meant for (a real Amiga, for example) before relying on it."

# --- L6 : calibration croisee : journal exporte, echanges de disquette, lecteur cible preselectionne (110, 240, 250, 270, 540)
# En-tete du journal exporte (Get-LogExportHeader, 110), deux lignes en tete du fichier seulement ; {1} de la seconde : le
# lecteur cible, ou « (meme lecteur) » (018). Les echanges annonces (7 et non 9) et la preselection n ont pas de texte nouveau
$script:I18n["Journal exporté le {0} par Greaseweazle Studio v{1} ; calcul de calibration v{2}, mesure sur l'image v{3}."] = 'Log exported on {0} by Greaseweazle Studio v{1}; calibration calculation v{2}, on-image measurement v{3}.'
$script:I18n['Lecteur du bandeau : {0} ; lecteur cible de ses écritures : {1}.'] = 'Drive in the banner: {0}; target drive for its writes: {1}.'
# Marque de troncature, premiere ligne du journal borne (Limit-LogText, 110) ; 400 000 : $script:LogMaxChars (540)
$script:I18n['[Journal tronqué : les {0} premiers caractères ont été retirés (400 000 au plus sont gardés). Exportez le journal après chaque opération longue.]'] = '[Log truncated: the first {0} characters were removed (at most 400,000 are kept). Export the log after each long operation.]'

# --- L7 : revenir a une calibration precedente (120, 240, 250, 520) ----------------------------------------------------
# Bouton btnWCalBack de l onglet Ecriture (520) et son infobulle ({0} : nom du fichier de configuration)
$script:I18n['Revenir à une calibration précédente…'] = 'Return to a previous calibration…'
$script:I18n["Liste les calibrations complètes gardées dans les copies de la configuration (fichiers « {0}.….bak » du dossier de l'application, faites avant chaque remplacement ou effacement d'une calibration) et rétablit celle que vous choisissez. Seules ses courbes reviennent : les autres courbes, les réglages, la mémoire par marque et les facteurs mesurés ne changent pas. L'état actuel est d'abord sauvegardé."] = 'Lists the full calibrations kept in the configuration copies ("{0}.….bak" files in the application folder, made before each replacement or clearing of a calibration) and restores the one you choose. Only its curves come back: the other curves, the settings, the per-brand memory and the measured factors do not change. The current state is backed up first.'
# Fenetre frmCalibBack (250) : titre, bandeau, colonnes, cellules, bouton, pied ; « Lecteur », « commune », « tete {0} »,
# « par tete », « test fin », « test standard » et « Fermer » sont des cles existantes
$script:I18n['Revenir à une calibration précédente'] = 'Return to a previous calibration'
$script:I18n['Quelle calibration rétablir ?'] = 'Which calibration to restore?'
$script:I18n["Calibrations complètes trouvées dans {0} copie(s) de la configuration, différentes des courbes en place. Choisissez une ligne, puis « Rétablir cette calibration ». Seules les courbes de cette ligne changent ; l'état actuel est d'abord copié dans un fichier « {1}.ref-….bak », d'où ce retour s'annule de la même façon."] = 'Full calibrations found in {0} configuration copies, different from the curves in place. Select a row, then "Restore this calibration". Only the curves of that row change; the current state is first copied to a "{1}.ref-….bak" file, from which this return can be undone the same way.'
$script:I18n['Calibration du'] = 'Calibrated on'
$script:I18n['Famille'] = 'Family'
$script:I18n['Courbes'] = 'Curves'
$script:I18n['Test'] = 'Test'
$script:I18n['Calcul'] = 'Calculation'
$script:I18n['Copie'] = 'Copy'
$script:I18n['{0} (autre calcul)'] = '{0} (other calculation)'
$script:I18n['Rétablir cette calibration'] = 'Restore this calibration'
$script:I18n['Copies illisibles ou sans courbe, non listées : {0}.'] = 'Unreadable copies or copies without a curve, not listed: {0}.'
# Detail d une ligne, assemble par Get-CalibBackInfo (240), la fonction qui decide
$script:I18n['À rétablir : {0} ; calibration du {1}, {2}, calcul {3}.'] = 'To restore: {0}; calibrated on {1}, {2}, calculation {3}.'
$script:I18n['Courbes en place remplacées : {0}.'] = 'Curves in place replaced: {0}.'
$script:I18n["Aucune courbe en place n'est remplacée."] = 'No curve in place is replaced.'
# Relecture de L7 : courbes en attente du choix, courbes ajoutees, retour sans copie (Get-CalibBackInfo, champ Backup)
$script:I18n["Courbes en attente du choix « garder ou recalibrer » retirées de l'attente : {0}."] = 'Curves awaiting the "keep or recalibrate" choice taken out of the wait: {0}.'
$script:I18n['Courbes ajoutées, sans courbe en place : {0}. Elles restent en place si vous annulez ce retour.'] = 'Curves added, with no curve in place: {0}. They stay in place if you undo this return.'
$script:I18n["Aucune copie n'est faite avant ce retour : il ne s'annule pas par ce bouton, qui rétablit des courbes et n'en retire aucune."] = 'No copy is made before this return: it cannot be undone with this button, which restores curves and never removes any.'
$script:I18n['Calcul {0}, autre que le calcul actuel (v{1}) : ces courbes seront conservées telles quelles, comme avec « Conserver ces courbes » au démarrage ; une nouvelle calibration peut donner une courbe plus juste.'] = 'Calculation {0}, other than the current calculation (v{1}): these curves will be kept as they are, as with "Keep these curves" at startup; a new calibration may give a more accurate curve.'
$script:I18n["Ces courbes par tête sont plus anciennes que la courbe commune en place de ce lecteur ({0}) : l'écriture lente ne les appliquera pas tant que cette courbe commune est plus récente."] = 'These per-head curves are older than the common curve in place for this drive ({0}): slow writing will not apply them as long as that common curve is more recent.'
$script:I18n["Les niveaux de la calibration rapide mesurés avec les courbes remplacées ne s'appliqueront plus. Les autres courbes, les réglages, la mémoire par marque et les facteurs mesurés ne changent pas."] = 'Quick calibration levels measured with the replaced curves will no longer apply. The other curves, the settings, the per-brand memory and the measured factors do not change.'
$script:I18n['Copie lue : {0}, du {1}.'] = 'Copy read: {0}, dated {1}.'
# Lecteur d aujourd hui d une courbe d une copie datee (Resolve-DriveOfEra, 112) : colonne « Lecteur », phrases du detail,
# confirmation a case d une ligne au lien incertain (Start-CalibBack)
$script:I18n["{0} (à l'époque : {1})"] = '{0} (at the time: {1})'
$script:I18n['{0} (lecteur supprimé depuis)'] = '{0} (drive deleted since)'
$script:I18n['Cette calibration a été faite sur la connexion {0}, avant que son lecteur soit enregistré sous le nom « {1} » : ne la rétablissez que si elle a été faite avec ce lecteur.'] = 'This calibration was made on connection {0}, before its drive was registered under the name "{1}": restore it only if it was made with this drive.'
$script:I18n["Le lecteur « {0} » de cette copie n'est plus enregistré : cette calibration ne peut pas être rétablie."] = 'Drive "{0}" of this copy is no longer registered: this calibration cannot be restored.'
$script:I18n["Le lecteur « {0} » de cette copie ne peut pas être relié avec certitude à un lecteur d'aujourd'hui."] = 'Drive "{0}" of this copy cannot be linked with certainty to a drive of today.'
$script:I18n["Cette calibration porte le nom « {0} », mais le lecteur enregistré aujourd'hui sous ce nom l'a été après elle : ne la rétablissez que si elle a été faite avec ce lecteur."] = 'This calibration bears the name "{0}", but the drive registered under this name today was registered after it: restore it only if it was made with this drive.'
$script:I18n['Rétablir cette calibration pour le lecteur « {0} » ?'] = 'Restore this calibration for drive "{0}"?'
$script:I18n["Cette calibration a bien été faite avec le lecteur « {0} » (à l'époque : {1})"] = 'This calibration was indeed made with drive "{0}" (at the time: {1})'
# Messages, onglet et journal (Start-CalibBack, Restore-CalibBack, 240 ; Backup-ConfigBeforeRef, motif back, 120)
$script:I18n['Aucune calibration précédente à rétablir : le dossier « {0} » ne contient aucune copie de la configuration (« {1}.….bak »).'] = 'No previous calibration to restore: folder "{0}" holds no configuration copy ("{1}.….bak").'
$script:I18n['Aucune calibration précédente à rétablir : aucune des {0} copie(s) de la configuration lue(s) dans « {1} » ne contient de courbe différente des courbes en place.'] ='No previous calibration to restore: none of the {0} configuration copies read in "{1}" holds a curve different from the curves in place.'
$script:I18n["Retour annulé : l'état actuel n'a pas pu être sauvegardé (voir le journal). Rien n'est modifié."] = 'Return cancelled: the current state could not be backed up (see the log). Nothing is changed.'
$script:I18n['Calibration précédente rétablie : {0} (calibration du {1}, calcul {2}), lue dans {3}. Courbes remplacées : {4}.'] = 'Previous calibration restored: {0} (calibrated on {1}, calculation {2}), read from {3}. Curves replaced: {4}.'
$script:I18n['Calibration précédente rétablie.'] = 'Previous calibration restored.'
$script:I18n['Configuration sauvegardée avant le retour à une calibration précédente (référence {0} du {1}) : {2}'] = 'Configuration backed up before returning to a previous calibration ({0} reference of {1}): {2}'
$script:I18n["Configuration non sauvegardée avant le retour à une calibration précédente ({0}) : {1}. Retour annulé : rien n'est modifié."] = 'Configuration not backed up before returning to a previous calibration ({0}): {1}. Return cancelled: nothing is changed.'
$script:I18n['Copie de la configuration illisible, ignorée : {0} ({1}).'] = 'Unreadable configuration copy, ignored: {0} ({1}).'
# Confirmation de « Effacer les calibrations » (Reset-CalibProfiles, 240) : remplace la cle de 010 (texte de la 12.8)
$script:I18n["L'application copie d'abord la configuration dans « {0}.ref-….bak », dans le même dossier. Ensuite, « Revenir à une calibration précédente… » rétablit les courbes de cette copie, une calibration à la fois ; les niveaux, la mémoire par marque et les facteurs mesurés effacés ne reviennent qu'en remettant la copie à la place de « {0} », application fermée."] = 'The application first copies the configuration to "{0}.ref-….bak", in the same folder. Afterwards, "Return to a previous calibration…" restores the curves of that copy, one calibration at a time; the cleared levels, per-brand memory and measured factors only come back by putting the copy in place of "{0}", with the application closed.'

# --- L8 : progression par piste, barre d etat en fin d operation (110, 170, 200, 270, 276, 300, 600) -------------------
# Phase du libelle de la barre de calibration (Update-CalibProgress, 270) pendant un gw erase : « (passe 3/5, 0/30/100 ns,
# effacement) », a cote de « ecriture » et « relecture » (010)
$script:I18n['effacement'] = 'erasing'
# Barre d etat a la fin d une restauration (Close-Restore, 300, par Set-SeqEnd, 110) ; l heure suit le texte. Les autres
# fins (calibration, controle apres ecriture, recherche des lecteurs) reprennent des textes existants
$script:I18n['Restauration réussie'] = 'Restore succeeded'
$script:I18n['Restauration réussie avec réserve'] = 'Restore succeeded with a reservation'
$script:I18n['Restauration échouée'] = 'Restore failed'

# --- LN-a : lecteurs enregistres, socle sans interface (112, 120) ------------------------------------------------------
# Textes que rendent ou ecrivent les fonctions du socle ; ceux du bandeau et de la fenetre « Lecteurs enregistres »
# viendront en section LN-b. Un nom de lecteur ne passe jamais par T() ; « {0} ({1}) » (Get-DriveLabel) est sans mot
# Libelle d une fiche sans connexion (Get-DriveLabel)
$script:I18n['{0} (connexion à préciser)'] = '{0} (connection to be set)'
# Calibrations d un lecteur (Get-DriveDataText) ; sans courbe : « aucune » (010)
$script:I18n['{0} courbe(s), dernière : {1}'] = '{0} curve(s), latest: {1}'
$script:I18n['{0} courbe(s) dont {1} croisée(s), dernière : {2}'] = '{0} curve(s), {1} of them cross, latest: {2}'
# Refus d un nom (Test-DriveName, qui decide et dit pourquoi)
$script:I18n['Donnez un nom au lecteur.'] = 'Give the drive a name.'
$script:I18n['Nom trop long : {0} caractères au plus.'] = 'Name too long: {0} characters at most.'
$script:I18n["Caractère non admis : « {0} ». Un nom se compose de lettres, de chiffres, d'espaces et des signes - . _ + # °"] = 'Character not allowed: "{0}". A name is made of letters, digits, spaces and the signs - . _ + # °'
$script:I18n['Un nom contient au moins une lettre sans accent ou un chiffre.'] = 'A name contains at least one unaccented letter or one digit.'
$script:I18n['« {0} » désigne une connexion : choisissez un autre nom.'] = '"{0}" designates a connection: choose another name.'
$script:I18n['« {0} » est un mot réservé : choisissez un autre nom.'] = '"{0}" is a reserved word: choose another name.'
$script:I18n['Un lecteur enregistré porte déjà ce nom : {0}.'] = 'A registered drive already has this name: {0}.'
$script:I18n["Nom trop large pour s'afficher en entier dans les listes de lecteurs (environ 17 caractères) : raccourcissez-le."] = 'Name too wide to be shown in full in the drive lists (about 17 characters): shorten it.'
# Refus des actions du registre (Add-NamedDrive, Rename-NamedDrive, Move-NamedDrive, Remove-NamedDrive, Edit-DriveData,
# Protect-DriveData) ; {0} du premier : libelle de l operation en cours rendu par Get-AppBusy
$script:I18n['Lecteurs enregistrés : opération en cours ({0}). Réessayez quand elle est terminée.'] = 'Registered drives: operation in progress ({0}). Try again when it has finished.'
$script:I18n["Calibration B en cours ou en attente de décision : terminez-la d'abord."] = 'Calibration B in progress or awaiting a decision: finish it first.'
$script:I18n['Choisissez la connexion du lecteur.'] = 'Select the connection of the drive.'
$script:I18n['Le lecteur {0} a déjà des données (courbes, lecteur cible, niveaux, mémoire par marque ou facteurs) : celles de la connexion {1} ne peuvent pas lui être attribuées.'] = 'Drive {0} already has data (curves, target drive, levels, per-brand memory or factors): those of connection {1} cannot be assigned to it.'
$script:I18n['La connexion {0} a déjà des données sans nom de lecteur (courbes, lecteur cible, niveaux, mémoire par marque ou facteurs) : le nom ne peut pas être retiré seul.'] = 'Connection {0} already has data without a drive name (curves, target drive, levels, per-brand memory or factors): the name cannot be removed on its own.'
$script:I18n["Configuration non sauvegardée : rien n'a été modifié (voir le journal)."] = 'Configuration not backed up: nothing was changed (see the log).'
# Journal : copie datee de la configuration avant une modification des lecteurs (Backup-ConfigForDrives,
# Protect-DriveData) ; les copies retirees par la rotation reprennent la ligne « Ancienne sauvegarde... » (010)
$script:I18n['Configuration sauvegardée avant la modification des lecteurs enregistrés : {0}'] = 'Configuration backed up before changing the registered drives: {0}'
$script:I18n["Configuration non copiée avant la modification des lecteurs enregistrés : {0}. Modification annulée : rien n'est changé."] = 'Configuration not copied before changing the registered drives: {0}. Change cancelled: nothing is modified.'
$script:I18n["Configuration non enregistrée avant la modification des lecteurs enregistrés. Modification annulée : rien n'est changé."] = 'Configuration not saved before changing the registered drives. Change cancelled: nothing is modified.'
# Journal du chargement (Import-DriveRegistry, Repair-DriveRegistry, Restore-DriveRescueTargets) ; « {0} : {1} » : une
# fiche et ses calibrations, dans la ligne des lecteurs relus dans la copie de secours
$script:I18n['Lecteurs enregistrés : {0} fiche(s) illisible(s), ignorée(s).'] = 'Registered drives: {0} unreadable record(s), ignored.'
$script:I18n['Lecteurs enregistrés : connexion illisible pour {0} : redonnez-la dans « Lecteurs enregistrés » (Accueil).'] = 'Registered drives: unreadable connection for {0}: set it again in "Registered drives" (Home).'
$script:I18n["Lecteurs enregistrés relus dans la copie de secours ({0}) : le fichier de configuration ne les contenait pas (enregistré par une version antérieure, ou copie plus ancienne remise à sa place). Calibrations rangées sous leurs noms : {1}. Lecteurs cibles rétablis depuis cette copie : {2}. Vérifiez le lecteur choisi et son lecteur cible avant d'écrire."] = 'Registered drives read back from the rescue copy ({0}): the configuration file did not contain them (saved by an earlier version, or an older copy put back in its place). Calibrations filed under their names: {1}. Target drives restored from this copy: {2}. Check the selected drive and its target drive before writing.'
$script:I18n['{0} : {1}'] = '{0}: {1}'
$script:I18n["Lecteurs présents dans les calibrations, sans fiche : {0}. Redonnez leur connexion dans « Lecteurs enregistrés » (Accueil) ; d'ici là, ils ne sont pas proposés dans le bandeau et leurs calibrations ne servent à aucun autre lecteur."] = 'Drives present in the calibrations, without a record: {0}. Set their connection again in "Registered drives" (Home); until then, they are not offered in the banner and their calibrations are not used for any other drive.'
$script:I18n['Calibrations rangées sous un nom de lecteur non admis ({0}) : elles ne servent à aucun lecteur.'] = 'Calibrations filed under a drive name that is not allowed ({0}): they are not used for any drive.'
# Copie de secours du registre (<configuration>.lecteurs : Save-DriveRescue, Import-DriveRegistry) : son commentaire, ses
# deux lignes de journal
$script:I18n['Copie de secours des lecteurs enregistrés de Greaseweazle Studio (noms, connexions, lecteurs cibles) - régénérée automatiquement.'] = 'Rescue copy of the registered drives of Greaseweazle Studio (names, connections, target drives) - regenerated automatically.'
$script:I18n['Copie de secours des lecteurs enregistrés non écrite ({0}) : {1}'] = 'Rescue copy of the registered drives not written ({0}): {1}'
$script:I18n['Copie de secours des lecteurs enregistrés illisible ({0}) : {1}'] = 'Rescue copy of the registered drives unreadable ({0}): {1}'

# --- LN-b : lecteurs enregistres, interface (112, 110, 120, 140, 250, 270, 300, 540) ----------------------------------
# Bandeau : libelle d un lecteur enregistre et infobulle de la liste (Set-DriveBannerLayout) ; carte de l Accueil
# (Get-DrivesCardText) ; un lecteur non enregistre dans une liste de lecteurs (Format-ConnDrives, Get-DriveRows)
$script:I18n['Lecteur ({0}) :'] = 'Drive ({0}):'
$script:I18n["Lecteurs enregistrés : {0}.`nLeurs calibrations sont rangées sous leur nom, quelle que soit leur connexion.`nL'application ne reconnaît pas le lecteur branché : choisissez-le ici chaque fois que vous en changez`n(pour les nommer : Accueil, « Lecteurs enregistrés »)."] = "Registered drives: {0}.`nTheir calibrations are filed under their name, whatever their connection.`nThe application cannot recognise the drive that is plugged in: select it here each time you change it`n(to name them: Home, ""Registered drives"")."
$script:I18n['Lecteurs enregistrés'] = 'Registered drives'
$script:I18n['Nommer vos lecteurs : plusieurs sur une même connexion, chacun avec ses calibrations.'] = 'Name your drives: several on one connection, each with its own calibrations.'
$script:I18n['{0} lecteur(s) sans connexion : redonnez-la ici pour retrouver leurs calibrations.'] = '{0} drive(s) without a connection: set it again here to get their calibrations back.'
$script:I18n['{0} (non enregistré)'] = '{0} (not registered)'
# Fenetre « Lecteurs enregistres » (New-DrivesDialog, Get-DriveRows)
$script:I18n['Vos lecteurs de disquette'] = 'Your floppy drives'
$script:I18n["Un lecteur enregistré a un nom et une connexion au Greaseweazle (A ou B : nappe PC avec twist ; 0 à 3 : nappe droite). Ses calibrations, son lecteur cible et ses facteurs mesurés sont rangés sous son nom : plusieurs lecteurs peuvent partager une connexion, et un lecteur garde ses calibrations quand il change de connexion.`n`nL'application ne reconnaît pas le lecteur branché : celui qui compte est le lecteur choisi dans la liste « Lecteur : » du bandeau. Un lecteur nouveau part sans calibration, avec le profil d'origine."] = "A registered drive has a name and a connection to the Greaseweazle (A or B: PC cable with twist; 0 to 3: straight cable). Its calibrations, its target drive and its measured factors are filed under its name: several drives can share a connection, and a drive keeps its calibrations when its connection changes.`n`nThe application cannot recognise the drive that is plugged in: the one that counts is the drive selected in the ""Drive:"" list of the banner. A new drive starts without calibration, with the original profile."
$script:I18n['Connexion'] = 'Connection'
$script:I18n['Calibrations'] = 'Calibrations'
$script:I18n['à préciser'] = 'to be set'
$script:I18n['Connexion :'] = 'Connection:'
$script:I18n['Nouveau lecteur'] = 'New drive'
$script:I18n['Supprimer…'] = 'Delete…'
# Decision et resultats du bouton « Enregistrer » (Get-DriveEditPlan) : note, refus, resultats (texte d etat et journal)
$script:I18n['La connexion {0} a déjà des calibrations sans nom de lecteur. Pour les garder avec ce lecteur, sélectionnez la ligne « {0} (non enregistré) » et donnez-lui ce nom ; sinon ce lecteur sera calibré à part.'] = 'Connection {0} already has calibrations without a drive name. To keep them with this drive, select the row "{0} (not registered)" and give it this name; otherwise this drive will be calibrated separately.'
$script:I18n["Rien à enregistrer : le nom et la connexion n'ont pas changé."] = 'Nothing to save: the name and the connection have not changed.'
$script:I18n['Lecteur « {0} » enregistré sur la connexion {1}, sans calibration. Choisissez-le dans la liste « Lecteur : » du bandeau quand il est branché.'] = 'Drive "{0}" registered on connection {1}, without calibration. Select it in the "Drive:" list of the banner when it is plugged in.'
$script:I18n['Lecteur « {0} » enregistré sur la connexion {1} : les calibrations faites sans nom sur la connexion {2} ({3} courbe(s)) sont maintenant les siennes.'] = 'Drive "{0}" registered on connection {1}: the calibrations made without a name on connection {2} ({3} curve(s)) are now its own.'
$script:I18n['Lecteur « {0} » enregistré sur la connexion {1} : le lecteur cible, les niveaux, la mémoire par marque et les facteurs mesurés de la connexion {2} sont maintenant les siens.'] = 'Drive "{0}" registered on connection {1}: the target drive, the levels, the per-brand memory and the measured factors of connection {2} are now its own.'
$script:I18n["Lecteur « {0} » : il s'appelait « {1} ». Ses calibrations ({2} courbe(s)), ses niveaux, sa mémoire par marque, ses facteurs et ses lecteurs cibles portent son nouveau nom."] = 'Drive "{0}": it was called "{1}". Its calibrations ({2} curve(s)), its levels, its per-brand memory, its factors and its target drives carry its new name.'
$script:I18n['Lecteur « {0} » : connexion {1} (avant : {2}). Ses calibrations le suivent. Après un changement de nappe, contrôlez une écriture (onglet Qualité) ou refaites une calibration rapide.'] = 'Drive "{0}": connection {1} (before: {2}). Its calibrations follow it. After a cable change, check a write (Quality tab) or run a quick calibration again.'
$script:I18n['Lecteur « {0} » supprimé : {1} courbe(s) retirée(s).'] = 'Drive "{0}" deleted: {1} curve(s) removed.'
$script:I18n['Nom « {0} » retiré : ses calibrations sont rangées sous la connexion {1}, sans nom de lecteur.'] = 'Name "{0}" removed: its calibrations are filed under connection {1}, without a drive name.'
# Confirmations de la fenetre (Invoke-DriveEditPlan, Remove-DriveEntry : textes de Get-DriveEditPlan et Get-DriveDeletePlan)
$script:I18n['Attribuer à ce lecteur les calibrations de la connexion {0} ?'] = 'Assign the calibrations of connection {0} to this drive?'
$script:I18n["La connexion {0} a des calibrations faites sans nom de lecteur : {1}.`n`nEn nommant ce lecteur « {2} », vous déclarez qu'elles ont été faites avec lui : elles deviennent les siennes, avec ses niveaux, sa mémoire par marque, ses facteurs mesurés et son lecteur cible. Rien n'est recalculé ni effacé ; la configuration est d'abord copiée dans un fichier « {3}.lecteurs-….bak ». La connexion {0} garde un lecteur non enregistré, sans calibration.`n`nSi elles viennent d'un autre lecteur, fermez cette fenêtre et choisissez « Nouveau lecteur » : il partira sans calibration."] = "Connection {0} has calibrations made without a drive name: {1}.`n`nBy naming this drive ""{2}"", you state that they were made with it: they become its own, with its levels, its per-brand memory, its measured factors and its target drive. Nothing is recomputed or erased; the configuration is first copied to a ""{3}.lecteurs-….bak"" file. Connection {0} keeps an unregistered drive, with no calibration.`n`nIf they come from another drive, close this window and choose ""New drive"": it will start without calibration."
$script:I18n['Les calibrations de la connexion {0} ont été faites avec le lecteur « {1} »'] = 'The calibrations of connection {0} were made with drive "{1}"'
$script:I18n['Attribuer ces calibrations'] = 'Assign these calibrations'
$script:I18n["Le lecteur non enregistré de la connexion {0} n'a aucune calibration. Son lecteur cible, ses niveaux, sa mémoire par marque et ses facteurs mesurés passent sous le nom « {1} ». Continuer ?"] = 'The unregistered drive of connection {0} has no calibration. Its target drive, its levels, its per-brand memory and its measured factors move under the name "{1}". Continue?'
$script:I18n['Supprimer le lecteur « {0} » ?'] = 'Delete drive "{0}"?'
$script:I18n["Sont retirés : ses calibrations ({0}), ses niveaux, sa mémoire par marque, ses facteurs mesurés et son lecteur cible, ainsi que les courbes croisées dont il est le lecteur cible et le choix de ce lecteur comme cible d'un autre.`n`nL'application ne peut pas annuler cette suppression. Elle copie d'abord la configuration dans « {1}.lecteurs-….bak », dans le même dossier : pour revenir en arrière, fermez l'application, puis remettez cette copie à la place de « {1} »."] = "Removed: its calibrations ({0}), its levels, its per-brand memory, its measured factors and its target drive, as well as the cross curves of which it is the target drive and the choice of this drive as the target of another one.`n`nThe application cannot undo this deletion. It first copies the configuration to ""{1}.lecteurs-….bak"", in the same folder: to go back, close the application, then put this copy in place of ""{1}""."
$script:I18n['« Retirer seulement le nom » : ses calibrations restent, rangées sous la connexion {0}, sans nom de lecteur.'] = '"Remove the name only": its calibrations remain, filed under connection {0}, without a drive name.'
$script:I18n['Le lecteur « {0} » ne doit plus être enregistré'] = 'Drive "{0}" must no longer be registered'
$script:I18n['Supprimer avec ses calibrations'] = 'Delete with its calibrations'
$script:I18n['Retirer seulement le nom'] = 'Remove the name only'
$script:I18n["Supprimer le lecteur « {0} » ? Il n'a aucune calibration."] = 'Delete drive "{0}"? It has no calibration.'
# Confirmation du lecteur branche et du lecteur cible d une calibration croisee (Confirm-DriveIdentity), refus au journal
$script:I18n['Lecteur branché'] = 'Plugged-in drive'
$script:I18n['Quel lecteur est branché sur la connexion {0} ?'] = 'Which drive is plugged into connection {0}?'
$script:I18n["La connexion {0} porte plusieurs lecteurs : {1}. L'application ne reconnaît pas celui qui est branché."] = 'Connection {0} carries several drives: {1}. The application cannot recognise the one that is plugged in.'
$script:I18n["Vos lecteurs enregistrés viennent d'être relus dans leur copie de secours : le fichier de configuration ne les contenait pas. L'application ne reconnaît pas le lecteur branché sur la connexion {0}."] = 'Your registered drives have just been read back from their rescue copy: the configuration file did not contain them. The application cannot recognise the drive plugged into connection {0}.'
$script:I18n["Lecteur choisi dans le bandeau : {0}`nSes calibrations : {1}`n`nL'écriture et la calibration emploient ses courbes et rangent leurs résultats sous son nom. Si un autre lecteur est branché, fermez cette fenêtre et choisissez-le dans la liste « Lecteur : » du bandeau : avec la courbe d'un autre lecteur, la disquette serait mal précompensée, sans aucun message d'erreur."] = "Drive selected in the banner: {0}`nIts calibrations: {1}`n`nWriting and calibration use its curves and file their results under its name. If another drive is plugged in, close this window and select it in the ""Drive:"" list of the banner: with the curve of another drive, the disk would be badly precompensated, without any error message."
$script:I18n['Le lecteur branché sur la connexion {0} est bien « {1} »'] = 'The drive plugged into connection {0} is indeed "{1}"'
$script:I18n["Le lecteur branché sur la connexion {0} n'est aucun des lecteurs enregistrés"] = 'The drive plugged into connection {0} is none of the registered drives'
$script:I18n["Lecteur cible de cette calibration croisée : {0}`nLa courbe mesurée servira aux écritures du lecteur {1} destinées à ce lecteur. Si un autre lecteur est branché sur la connexion {2}, fermez cette fenêtre et relancez la calibration croisée avec le bon lecteur cible : mesurée avec un autre lecteur, la courbe serait fausse, sans aucun message d'erreur."] = "Target drive of this cross calibration: {0}`nThe measured curve will be used for the writes of drive {1} intended for this drive. If another drive is plugged into connection {2}, close this window and start the cross calibration again with the right target drive: measured with another drive, the curve would be wrong, without any error message."
$script:I18n['Opération annulée : lecteur branché non confirmé.'] = 'Operation cancelled: plugged-in drive not confirmed.'
# Journal : lecteur choisi (Update-DriveChoice), lecteur qui ecrit (Get-WriteSourceText), lecteur retenu par la detection
# (Complete-DriveDetect, 110)
$script:I18n['Lecteur choisi : {0} (avant : {1}).'] = 'Drive selected: {0} (before: {1}).'
$script:I18n['Lecteur qui écrit : {0}'] = 'Writing drive: {0}'
$script:I18n['Connexion {0} : lecteur retenu « {1} », le dernier choisi sur cette connexion. La détection ne reconnaît pas le lecteur branché : vérifiez la liste « Lecteur : » du bandeau.'] = 'Connection {0}: drive "{1}" kept, the last one selected on this connection. Detection cannot recognise the drive that is plugged in: check the "Drive:" list of the banner.'
# Textes existants completes, pour un lecteur enregistre en jeu seulement : case de la mesure (140), fenetre de decision
# (250), cibles ecartees d une calibration croisee (270), ligne d etat de l echange et du controle de surface (270),
# libelle du lecteur de la restauration (300)
$script:I18n["Mesurer la disquette avant l'écriture : toujours en « Test rapide », sauf pour un lecteur cible"] = 'Measure the disk before the write: always with "Quick test", except for a target drive'
$script:I18n["Conserver la courbe : elle est enregistrée pour le lecteur {0} et appliquée à ses prochaines écritures.`nAbandonner la courbe : la calibration précédente est rétablie."] = "Keep the curve: it is saved for drive {0} and applied to its next writes.`nDiscard the curve: the previous calibration is restored."
$script:I18n["Non proposés, parce qu'ils sont sur la connexion {0} du lecteur qui écrit : {1}. Les deux lecteurs d'une calibration croisée sont branchés en même temps, chacun sur sa connexion."] = 'Not offered, because they are on connection {0} of the writing drive: {1}. The two drives of a cross calibration are plugged in at the same time, each on its own connection.'
$script:I18n['{0} → {1} : déplacez la disquette'] = '{0} → {1}: move the disk'
$script:I18n['{0} : contrôle de surface, décision demandée'] = '{0}: surface check, decision requested'
$script:I18n['{0}  (bandeau)'] = '{0}  (banner)'

# --- L9 : onglet Ecriture en trois etapes, options avancees, barre d onglets (145, 510, 520, 600) ----------------------

# --- L10 : ligne « Ce qui va se passer » de l onglet Ecriture (140, 145, 260, 520) -------------------------------------

# --- L11 : barre de l onglet Ecriture pendant l ecriture et son controle (140, 160, 170, 600) --------------------------
