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
$script:I18n['Calcul'] = 'Calc.'
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
$script:I18n["Le lecteur « {0} » de cette copie n'existe plus : cette calibration ne peut pas être rétablie."] = 'Drive "{0}" of this copy no longer exists: this calibration cannot be restored.'
$script:I18n["Le lecteur « {0} » de cette copie ne peut pas être relié avec certitude à un lecteur d'aujourd'hui."] = 'Drive "{0}" of this copy cannot be linked with certainty to a drive of today.'
$script:I18n["Cette calibration porte le nom « {0} », mais le lecteur qui porte aujourd'hui ce nom l'a reçu après elle : ne la rétablissez que si elle a été faite avec ce lecteur."] = 'This calibration bears the name "{0}", but the drive that bears this name today received it after it: restore it only if it was made with this drive.'
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
$script:I18n['Un lecteur porte déjà ce nom : {0}.'] = 'A drive already has this name: {0}.'
$script:I18n["Nom trop large pour s'afficher en entier dans les listes de lecteurs (environ 17 caractères) : raccourcissez-le."] = 'Name too wide to be shown in full in the drive lists (about 17 characters): shorten it.'
# Refus des actions du registre (Add-NamedDrive, Rename-NamedDrive, Move-NamedDrive, Remove-NamedDrive, Edit-DriveData,
# Protect-DriveData) ; {0} du premier : libelle de l operation en cours rendu par Get-AppBusy
$script:I18n['Lecteurs : opération en cours ({0}). Réessayez quand elle est terminée.'] = 'Drives: operation in progress ({0}). Try again when it has finished.'
$script:I18n["Calibration B en cours ou en attente de décision : terminez-la d'abord."] = 'Calibration B in progress or awaiting a decision: finish it first.'
$script:I18n['Choisissez la connexion du lecteur.'] = 'Select the connection of the drive.'
$script:I18n['Le lecteur {0} a déjà des données (courbes, lecteur cible, niveaux, mémoire par marque ou facteurs) : celles de la connexion {1} ne peuvent pas lui être attribuées.'] = 'Drive {0} already has data (curves, target drive, levels, per-brand memory or factors): those of connection {1} cannot be assigned to it.'
$script:I18n['La connexion {0} a déjà des données sans nom de lecteur (courbes, lecteur cible, niveaux, mémoire par marque ou facteurs) : le nom ne peut pas être retiré seul.'] = 'Connection {0} already has data without a drive name (curves, target drive, levels, per-brand memory or factors): the name cannot be removed on its own.'
$script:I18n["Configuration non sauvegardée : rien n'a été modifié (voir le journal)."] = 'Configuration not backed up: nothing was changed (see the log).'
# Journal : copie datee de la configuration avant une modification des lecteurs (Backup-ConfigForDrives,
# Protect-DriveData) ; les copies retirees par la rotation reprennent la ligne « Ancienne sauvegarde... » (010)
$script:I18n['Configuration sauvegardée avant la modification des lecteurs : {0}'] = 'Configuration backed up before changing the drives: {0}'
$script:I18n["Configuration non copiée avant la modification des lecteurs : {0}. Modification annulée : rien n'est changé."] = 'Configuration not copied before changing the drives: {0}. Change cancelled: nothing is modified.'
$script:I18n["Configuration non enregistrée avant la modification des lecteurs. Modification annulée : rien n'est changé."] = 'Configuration not saved before changing the drives. Change cancelled: nothing is modified.'
# Journal du chargement (Import-DriveRegistry, Repair-DriveRegistry, Restore-DriveRescueTargets) ; « {0} : {1} » : une
# fiche et ses calibrations, dans la ligne des lecteurs relus dans la copie de secours
$script:I18n['Lecteurs : {0} fiche(s) illisible(s), ignorée(s).'] = 'Drives: {0} unreadable record(s), ignored.'
$script:I18n['Lecteurs : connexion illisible pour {0} : redonnez-la dans « Lecteurs » (Accueil).'] = 'Drives: unreadable connection for {0}: set it again in "Drives" (Home).'
$script:I18n["Lecteurs relus dans la copie de secours ({0}) : le fichier de configuration ne les contenait pas (enregistré par une version antérieure, ou copie plus ancienne remise à sa place). Calibrations rangées sous leurs noms : {1}. Lecteurs cibles rétablis depuis cette copie : {2}. Vérifiez le lecteur choisi et son lecteur cible avant d'écrire."] = 'Drives read back from the rescue copy ({0}): the configuration file did not contain them (saved by an earlier version, or an older copy put back in its place). Calibrations filed under their names: {1}. Target drives restored from this copy: {2}. Check the selected drive and its target drive before writing.'
$script:I18n['{0} : {1}'] = '{0}: {1}'
$script:I18n["Lecteurs présents dans les calibrations, sans fiche : {0}. Redonnez leur connexion dans « Lecteurs » (Accueil) ; d'ici là, ils ne sont pas proposés dans le bandeau et leurs calibrations ne servent à aucun autre lecteur."] = 'Drives present in the calibrations, without a record: {0}. Set their connection again in "Drives" (Home); until then, they are not offered in the banner and their calibrations are not used for any other drive.'
$script:I18n['Calibrations rangées sous un nom de lecteur non admis ({0}) : elles ne servent à aucun lecteur.'] = 'Calibrations filed under a drive name that is not allowed ({0}): they are not used for any drive.'
# Copie de secours du registre (<configuration>.lecteurs : Save-DriveRescue, Import-DriveRegistry) : son commentaire, ses
# deux lignes de journal
$script:I18n['Copie de secours des lecteurs de Greaseweazle Studio (noms, connexions, lecteurs cibles) - régénérée automatiquement.'] = 'Rescue copy of the drives of Greaseweazle Studio (names, connections, target drives) - regenerated automatically.'
$script:I18n['Copie de secours des lecteurs non écrite ({0}) : {1}'] = 'Rescue copy of the drives not written ({0}): {1}'
$script:I18n['Copie de secours des lecteurs illisible ({0}) : {1}'] = 'Rescue copy of the drives unreadable ({0}): {1}'

# --- LN-b : lecteurs enregistres, interface (112, 110, 120, 140, 250, 270, 300, 540) ----------------------------------
# Bandeau : libelle d un lecteur enregistre et infobulle de la liste (Set-DriveBannerLayout) ; carte de l Accueil
# (Get-DrivesCardText) ; un lecteur non enregistre dans une liste de lecteurs (Format-ConnDrives, Get-DriveRows)
$script:I18n['Lecteur ({0}) :'] = 'Drive ({0}):'
$script:I18n["Lecteurs : {0}.`nLeurs calibrations sont rangées sous leur nom, quelle que soit leur connexion.`nL'application ne reconnaît pas le lecteur branché : choisissez-le ici chaque fois que vous en changez`n(pour les nommer : Accueil, « Lecteurs »)."] = "Drives: {0}.`nTheir calibrations are filed under their name, whatever their connection.`nThe application cannot recognise the drive that is plugged in: select it here each time you change it`n(to name them: Home, ""Drives"")."
$script:I18n['Lecteurs'] = 'Drives'
$script:I18n['Nommer vos lecteurs : plusieurs sur une même connexion, chacun avec ses calibrations.'] = 'Name your drives: several on one connection, each with its own calibrations.'
$script:I18n['{0} lecteur(s) sans connexion : redonnez-la ici pour retrouver leurs calibrations.'] = '{0} drive(s) without a connection: set it again here to get their calibrations back.'
$script:I18n['{0} (sans nom)'] = '{0} (no name)'
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
$script:I18n['La connexion {0} a déjà des calibrations sans nom de lecteur. Pour les garder avec ce lecteur, sélectionnez la ligne « {0} (sans nom) » et donnez-lui ce nom ; sinon ce lecteur sera calibré à part.'] = 'Connection {0} already has calibrations without a drive name. To keep them with this drive, select the row "{0} (no name)" and give it this name; otherwise this drive will be calibrated separately.'
$script:I18n["Rien à enregistrer : le nom et la connexion n'ont pas changé."] = 'Nothing to save: the name and the connection have not changed.'
$script:I18n['Lecteur « {0} » ajouté sur la connexion {1}, sans calibration. Choisissez-le dans la liste « Lecteur : » du bandeau quand il est branché.'] = 'Drive "{0}" added on connection {1}, without calibration. Select it in the "Drive:" list of the banner when it is plugged in.'
$script:I18n['Lecteur « {0} » ajouté sur la connexion {1} : les calibrations faites sans nom sur la connexion {2} ({3} courbe(s)) sont maintenant les siennes.'] = 'Drive "{0}" added on connection {1}: the calibrations made without a name on connection {2} ({3} curve(s)) are now its own.'
$script:I18n['Lecteur « {0} » ajouté sur la connexion {1} : le lecteur cible, les niveaux, la mémoire par marque et les facteurs mesurés de la connexion {2} sont maintenant les siens.'] = 'Drive "{0}" added on connection {1}: the target drive, the levels, the per-brand memory and the measured factors of connection {2} are now its own.'
$script:I18n["Lecteur « {0} » : il s'appelait « {1} ». Ses calibrations ({2} courbe(s)), ses niveaux, sa mémoire par marque, ses facteurs et ses lecteurs cibles portent son nouveau nom."] = 'Drive "{0}": it was called "{1}". Its calibrations ({2} curve(s)), its levels, its per-brand memory, its factors and its target drives carry its new name.'
$script:I18n['Lecteur « {0} » : connexion {1} (avant : {2}). Ses calibrations le suivent. Après un changement de nappe, contrôlez une écriture (onglet Qualité) ou refaites une calibration rapide.'] = 'Drive "{0}": connection {1} (before: {2}). Its calibrations follow it. After a cable change, check a write (Quality tab) or run a quick calibration again.'
$script:I18n['Lecteur « {0} » supprimé : {1} courbe(s) retirée(s).'] = 'Drive "{0}" deleted: {1} curve(s) removed.'
$script:I18n['Nom « {0} » retiré : ses calibrations sont rangées sous la connexion {1}, sans nom de lecteur.'] = 'Name "{0}" removed: its calibrations are filed under connection {1}, without a drive name.'
# Confirmations de la fenetre (Invoke-DriveEditPlan, Remove-DriveEntry : textes de Get-DriveEditPlan et Get-DriveDeletePlan)
$script:I18n['Attribuer à ce lecteur les calibrations de la connexion {0} ?'] = 'Assign the calibrations of connection {0} to this drive?'
$script:I18n["La connexion {0} a des calibrations faites sans nom de lecteur : {1}.`n`nEn nommant ce lecteur « {2} », vous déclarez qu'elles ont été faites avec lui : elles deviennent les siennes, avec ses niveaux, sa mémoire par marque, ses facteurs mesurés et son lecteur cible. Rien n'est recalculé ni effacé ; la configuration est d'abord copiée dans un fichier « {3}.lecteurs-….bak ». La connexion {0} garde un lecteur sans nom, sans calibration.`n`nSi elles viennent d'un autre lecteur, fermez cette fenêtre et choisissez « Nouveau lecteur » : il partira sans calibration."] = "Connection {0} has calibrations made without a drive name: {1}.`n`nBy naming this drive ""{2}"", you state that they were made with it: they become its own, with its levels, its per-brand memory, its measured factors and its target drive. Nothing is recomputed or erased; the configuration is first copied to a ""{3}.lecteurs-….bak"" file. Connection {0} keeps an unnamed drive, with no calibration.`n`nIf they come from another drive, close this window and choose ""New drive"": it will start without calibration."
$script:I18n['Les calibrations de la connexion {0} ont été faites avec le lecteur « {1} »'] = 'The calibrations of connection {0} were made with drive "{1}"'
$script:I18n['Attribuer ces calibrations'] = 'Assign these calibrations'
$script:I18n["Le lecteur sans nom de la connexion {0} n'a aucune calibration. Son lecteur cible, ses niveaux, sa mémoire par marque et ses facteurs mesurés passent sous le nom « {1} ». Continuer ?"] = 'The unnamed drive of connection {0} has no calibration. Its target drive, its levels, its per-brand memory and its measured factors move under the name "{1}". Continue?'
$script:I18n['Supprimer le lecteur « {0} » ?'] = 'Delete drive "{0}"?'
$script:I18n["Sont retirés : ses calibrations ({0}), ses niveaux, sa mémoire par marque, ses facteurs mesurés et son lecteur cible, ainsi que les courbes croisées dont il est le lecteur cible et le choix de ce lecteur comme cible d'un autre.`n`nL'application ne peut pas annuler cette suppression. Elle copie d'abord la configuration dans « {1}.lecteurs-….bak », dans le même dossier : pour revenir en arrière, fermez l'application, puis remettez cette copie à la place de « {1} »."] = "Removed: its calibrations ({0}), its levels, its per-brand memory, its measured factors and its target drive, as well as the cross curves of which it is the target drive and the choice of this drive as the target of another one.`n`nThe application cannot undo this deletion. It first copies the configuration to ""{1}.lecteurs-….bak"", in the same folder: to go back, close the application, then put this copy in place of ""{1}""."
$script:I18n['« Retirer seulement le nom » : ses calibrations restent, rangées sous la connexion {0}, sans nom de lecteur.'] = '"Remove the name only": its calibrations remain, filed under connection {0}, without a drive name.'
$script:I18n['Le lecteur « {0} » ne servira plus'] = 'Drive "{0}" will no longer be used'
$script:I18n['Supprimer avec ses calibrations'] = 'Delete with its calibrations'
$script:I18n['Retirer seulement le nom'] = 'Remove the name only'
$script:I18n["Supprimer le lecteur « {0} » ? Il n'a aucune calibration."] = 'Delete drive "{0}"? It has no calibration.'
# Confirmation du lecteur branche et du lecteur cible d une calibration croisee (Confirm-DriveIdentity), refus au journal
$script:I18n['Lecteur branché'] = 'Plugged-in drive'
$script:I18n['Quel lecteur est branché sur la connexion {0} ?'] = 'Which drive is plugged into connection {0}?'
$script:I18n["La connexion {0} porte plusieurs lecteurs : {1}. L'application ne reconnaît pas celui qui est branché."] = 'Connection {0} carries several drives: {1}. The application cannot recognise the one that is plugged in.'
$script:I18n["Vos lecteurs viennent d'être relus dans leur copie de secours : le fichier de configuration ne les contenait pas. L'application ne reconnaît pas le lecteur branché sur la connexion {0}."] = 'Your drives have just been read back from their rescue copy: the configuration file did not contain them. The application cannot recognise the drive plugged into connection {0}.'
$script:I18n["Lecteur choisi dans le bandeau : {0}`nSes calibrations : {1}`n`nL'écriture et la calibration emploient ses courbes et rangent leurs résultats sous son nom. Si un autre lecteur est branché, fermez cette fenêtre et choisissez-le dans la liste « Lecteur : » du bandeau : avec la courbe d'un autre lecteur, la disquette serait mal précompensée, sans aucun message d'erreur."] = "Drive selected in the banner: {0}`nIts calibrations: {1}`n`nWriting and calibration use its curves and file their results under its name. If another drive is plugged in, close this window and select it in the ""Drive:"" list of the banner: with the curve of another drive, the disk would be badly precompensated, without any error message."
$script:I18n['Le lecteur branché sur la connexion {0} est bien « {1} »'] = 'The drive plugged into connection {0} is indeed "{1}"'
$script:I18n["Le lecteur branché sur la connexion {0} n'est aucun des lecteurs"] = 'The drive plugged into connection {0} is none of the drives'
$script:I18n["Lecteur cible de cette calibration croisée : {0}`nLa courbe mesurée servira aux écritures du lecteur {1} destinées à ce lecteur. Si un autre lecteur est branché sur la connexion {2}, fermez cette fenêtre et relancez la calibration croisée avec le bon lecteur cible : mesurée avec un autre lecteur, la courbe serait fausse, sans aucun message d'erreur."] = "Target drive of this cross calibration: {0}`nThe measured curve will be used for the writes of drive {1} intended for this drive. If another drive is plugged into connection {2}, close this window and start the cross calibration again with the right target drive: measured with another drive, the curve would be wrong, without any error message."
$script:I18n['Opération annulée : lecteur branché non confirmé.'] = 'Operation cancelled: plugged-in drive not confirmed.'
# Journal : lecteur choisi (Update-DriveChoice), lecteur qui ecrit (Get-WriteSourceText)
$script:I18n['Lecteur choisi : {0} (avant : {1}).'] = 'Drive selected: {0} (before: {1}).'
$script:I18n['Lecteur qui écrit : {0}'] = 'Writing drive: {0}'
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
# Titres des deux premiers cadres de l onglet (520) ; « Options avancees » (010) reste le titre du troisieme
$script:I18n['1. Image à écrire'] = '1. Image to write'
$script:I18n['2. Disquette et lecteur'] = '2. Disk and drive'
# Lien des options avancees et son infobulle (520, Update-WAdvLink : 145) ; ligne a droite du bouton ECRIRE : options
# modifiees nommees (Get-WriteAdvChanges, 145 : une case decochee dont le defaut est cochee est suivie de « : decochee »)
$script:I18n['Options avancées…'] = 'Advanced options…'
$script:I18n['Options avancées : {0} modifiée(s)…'] = 'Advanced options: {0} changed…'
$script:I18n['Masquer les options avancées'] = 'Hide advanced options'
$script:I18n["Affiche ou masque les options avancées de l'écriture. Ce lien coche ou décoche la case « Mode expert » du bandeau, qui affiche aussi les onglets techniques.`nUne option avancée modifiée s'applique même masquée : le lien les compte et la ligne à droite du bouton « ÉCRIRE LA DISQUETTE » les nomme. « Réinitialiser » les remet à leur valeur par défaut."] = "Shows or hides the advanced write options. This link checks or unchecks the ""Expert mode"" box of the banner, which also shows the technical tabs.`nA changed advanced option applies even when hidden: the link counts them and the line to the right of the ""WRITE THE DISK"" button names them. ""Reset"" restores their default values."
$script:I18n['options avancées : {0}'] = 'advanced options: {0}'
$script:I18n['{0} : décochée'] = '{0}: unchecked'
# Infobulle de « Mode expert » (510) : ligne ajoutee au texte de 010
$script:I18n["Coché : affiche aussi les options avancées de l'onglet Écriture."] = 'Checked: also shows the advanced options of the Write tab.'
# Libelle « Lecteur qui ecrit » du cadre 2 (texte de Get-WriteSourceText, cle de la section LN-b) : infobulle
$script:I18n["Lecteur choisi dans la liste « Lecteur : » du bandeau : c'est lui qui écrit la disquette. Le lecteur cible est celui qui la relira."] = 'Drive selected in the "Drive:" list of the banner: it is the one that writes the disk. The target drive is the one that will read it back.'

# --- L10 : ligne « Ce qui va se passer » de l onglet Ecriture (140, 145, 260, 520) -------------------------------------
# Phrase (Format-WritePlan, 145) : segments separes par « ; » ; phrase coupee (Show-WritePlan : segments descriptifs
# retires, texte complet en infobulle)
$script:I18n['Ce qui va se passer : {0}.'] = 'What will happen: {0}.'
$script:I18n['Ce qui va se passer : {0} ; …'] = 'What will happen: {0}; …'
$script:I18n[' ; '] = '; '
# Effacement (Get-WriteErasePlan, 140)
$script:I18n['effacement haute fréquence des pistes'] = 'high-frequency erase of the tracks'
$script:I18n['pré-effacement de chaque piste'] = 'pre-erase of each track'
$script:I18n['sans effacement'] = 'no erase'
# Mesure de la disquette (Get-WriteLevelPlan, 140 ; Get-LevelBeforeWritePlan, 260) : texte de la liste « Mesure : » de la
# mesure faite, repli de la mesure sur l image, raisons d une ecriture sans mesure (« precompensation desactivee » : 013)
$script:I18n['mesure de la disquette : {0}'] = 'disk measurement: {0}'
$script:I18n["mesure de la disquette : {0}, au lieu de la mesure sur l'image ({1})"] = 'disk measurement: {0}, instead of the measurement on the image ({1})'
$script:I18n['sans mesure de la disquette ({0})'] = 'no disk measurement ({0})'
$script:I18n['lecteur cible {0}'] = 'target drive {0}'
$script:I18n['image flux'] = 'flux image'
$script:I18n['image en codage {0}'] = '{0}-encoded image'
$script:I18n['image non calibrable'] = 'image that cannot be calibrated'
$script:I18n['haute densité'] = 'high density'
$script:I18n['profil « {0} »'] = 'profile "{0}"'
$script:I18n['champ Pistes'] = 'Tracks field'
$script:I18n['image à une seule face'] = 'single-sided image'
# Tetes (Get-WriteHeads, 140)
$script:I18n['écriture des deux têtes ensemble'] = 'write of both heads together'
$script:I18n['écriture tête 0 puis tête 1'] = 'write of head 0 then head 1'
$script:I18n['écriture de la tête {0} seule'] = 'write of head {0} only'
# Controle (Get-WriteCheckPlan, 140) : demande, impose par la courbe adaptee d une calibration rapide, non applicable
$script:I18n['contrôle de toutes les pistes, {0} passe(s) de réécriture au plus'] = 'full track check, up to {0} rewrite pass(es)'
$script:I18n['contrôle de toutes les pistes, sans réécriture'] = 'full track check, no rewrite'
$script:I18n['contrôle de toutes les pistes non applicable ({0})'] = 'full track check not applicable ({0})'
$script:I18n['contrôle complet non demandé'] = 'full track check not requested'
$script:I18n['contrôle de toutes les pistes imposé par la courbe adaptée à cette disquette, {0} passe(s) de réécriture au plus'] = 'full track check required by the curve adapted to this disk, up to {0} rewrite pass(es)'
$script:I18n['contrôle de toutes les pistes imposé par la courbe adaptée à cette disquette, sans réécriture'] = 'full track check required by the curve adapted to this disk, no rewrite'
# Lecteur cible (Get-TargetWriteInfo, 140) : courbes croisees ecrites (Get-TargetCurvesText)
$script:I18n['pour le lecteur cible {0} : {1}'] = 'for target drive {0}: {1}'
# Formes courtes des segments critiques (le fait sans sa raison), quand la phrase coupee ne les tient pas entiers
$script:I18n['sans mesure de la disquette'] = 'no disk measurement'
$script:I18n["mesure de la disquette : {0}, au lieu de la mesure sur l'image"] = 'disk measurement: {0}, instead of the measurement on the image'
$script:I18n['contrôle de toutes les pistes non applicable'] = 'full track check not applicable'
$script:I18n['contrôle de toutes les pistes imposé'] = 'full track check required'
$script:I18n['lecteur cible {0} sans effet'] = 'target drive {0} has no effect'
# Refus du « Test rapide » sans reference utilisable (Get-LevelBeforeWritePlan, 260) : premiere phrase du message de
# Start-LevelBeforeWrite (010), seule dans la ligne
$script:I18n["Écriture refusée : le test rapide n'a pas de référence utilisable pour cette image ({0})."] = 'Write refused: the quick test has no usable reference for this image ({0}).'

# --- L11 : barre de l onglet Ecriture pendant l ecriture et son controle (140, 160, 170, 600) --------------------------
# Libelle pendant l ecriture (Get-WriteProgText, 160) : avancement de l ecriture seule, controle annonce ensuite ; fin sans
# verdict du controle (Get-WriteProgEnd, 160) : terminee, ou interrompue (erreur de gw, arret, gw introuvable)
$script:I18n['Écriture : {0} %'] = 'Writing: {0} %'
$script:I18n['Écriture : {0} %, contrôle de toutes les pistes ensuite'] = 'Writing: {0} %, then checking every track'
$script:I18n['Écriture terminée.'] = 'Write finished.'
$script:I18n['Écriture interrompue : voir le journal.'] = 'Write interrupted: see the log.'

# --- L12a : finition (140, 200, 260, 265, 510, 520) ---------------------------------------------------------------------
# Textes qui designent des controles ranges par le lot L9 dans les options avancees de l onglet Ecriture : ou les trouver.
# Remplacent trois cles de 010, retirees : infobulle de « Ecriture lente » (520) et du bouton de la Bibliotheque (510) ;
# infobulle du prechauffage de la calibration complete (520 et carte « Calibrer le lecteur », 200) ; refus des tetes d une
# ecriture lente (Get-WriteHeads, 140 ; repris par la ligne « Ce qui va se passer », ou l emplacement vient en tete de la
# consigne pour rester lisible dans ses trois lignes)
$script:I18n["Écriture lente : le lecteur est d'abord préchauffé par des lectures sans écriture (case « Préchauffer le lecteur avant l'écriture lente », dans les options avancées de l'onglet Écriture ; bouton « Passer le préchauffage » pendant l'attente)."] = 'Slow write: the drive is first warmed up by reads without writing ("Warm up the drive before the slow write" box, in the advanced options of the Write tab; "Skip warm-up" button while waiting).'
$script:I18n["Avant une calibration complète (bouton « Calibrer », carte « Calibrer le lecteur » de l'Accueil, calibration automatique avant une écriture) : lectures sans écriture des cylindres de test avant la première passe, pour stabiliser la température du lecteur ; réduites ou sautées si le lecteur vient de servir. Décochée : la calibration commence tout de suite.`nMême réglage dans les options avancées de l'onglet Écriture et dans la fenêtre de la carte « Calibrer le lecteur ». Durée : champ « Durée du préchauffage », dans les options avancées de l'onglet Écriture.`nLa calibration rapide (test rapide) n'a pas de préchauffage propre : avant une écriture lente, elle suit la case « Préchauffer le lecteur avant l'écriture lente »."] = "Before a full calibration (`"Calibrate`" button, `"Calibrate the drive`" card on the Home tab, automatic calibration before a write): reads without writing of the test cylinders before the first pass, to stabilise the drive temperature; shortened or skipped if the drive was just used. Unticked: the calibration starts right away.`nSame setting in the advanced options of the Write tab and in the window of the `"Calibrate the drive`" card. Duration: `"Warm-up duration`" field, in the advanced options of the Write tab.`nThe quick calibration (quick test) has no warm-up of its own: before a slow write, it follows the `"Warm up the drive before the slow write`" box."
$script:I18n["Écriture lente : nombre de faces de l'image inconnu ({0}).`nDans les options avancées, indiquer les têtes dans le champ Pistes (h=0-1 : double face, h=0 : simple face)`nou décocher « Effacer les pistes vides » : la tête 1 d'un format simple face serait effacée."] = "Slow write: number of sides of the image unknown ({0}).`nIn the advanced options, specify the heads in the Tracks field (h=0-1: double-sided, h=0: single-sided)`nor uncheck ""Erase empty tracks"": head 1 of a single-sided format would be erased."
# Journal du debut de la mesure complete de cette disquette (Get-DiskBoundText, 265) : cellules retenues = celles de la
# piste la plus longue d un IPF ou d un HFE aux pistes inegales (la ligne « Motif de test » donne la densite mediane)
$script:I18n["Borne de la courbe de cette disquette : {0} ns, le quart de la cellule de la piste la plus longue de l'image ({2} ns), {3} ns au plus ; au-delà de {1} ns, contrôle après écriture imposé."] = 'Curve bound for this disk: {0} ns, a quarter of the cell of the longest track of the image ({2} ns), {3} ns at most; above {1} ns, post-write check enforced.'
# Conseil de relever la borne precompMaxNs, journal et reserve de la fenetre de decision (260, 265) : {2}, borne la plus
# haute a conseiller (Get-BoundAdviceNs, 265 : 470 ns au plus, jamais au-dela du plafond de l image). Remplacent les deux
# cles de 010 a « 470 ns » ecrit en dur, retirees
$script:I18n["Plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés ; la borne se règle jusqu'à {2} ns (precompMaxNs)."] = '{0} ns ceiling reached at cylinders {1} with the adapted curve: these cylinders will stay under-compensated; the bound can be raised to {2} ns (precompMaxNs).'
$script:I18n["plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés ; la borne se règle jusqu'à {2} ns (precompMaxNs)"] = '{0} ns ceiling reached at cylinders {1} with the adapted curve: these cylinders will stay under-compensated; the bound can be raised to {2} ns (precompMaxNs)'

# --- rc2 : ecriture pour un lecteur cible avec le facteur par cylindre de la calibration croisee (140, 145) --------------
# Journal de l ecriture (Get-TargetTransferPlan, Get-TargetTransferSummary, 140) : courbe de cette disquette x facteur par
# cylindre ; {2} origine de la courbe de cette disquette, {3} courbes croisees (Get-TargetCurvesText), {4} resume par tete
$script:I18n["Écriture pour le lecteur cible {0} : courbe de cette disquette (lecteur {1}, {2}) × facteur par cylindre de la calibration croisée {1} → {0} ({3}) ; {4}"] = 'Write for target drive {0}: curve of this disk (drive {1}, {2}) × per-cylinder factor of the cross calibration {1} → {0} ({3}); {4}'
$script:I18n['courbe du lecteur'] = 'drive curve'
$script:I18n['calibration rapide de cette disquette'] = 'quick calibration of this disk'
$script:I18n['mesure complète de cette disquette'] = 'full measurement of this disk'
$script:I18n['× {0} ({1})'] = '× {0} ({1})'
$script:I18n['× {0}, moyenne des deux têtes'] = '× {0}, mean of both heads'
$script:I18n['facteur de {0} à {1}, médiane {2}'] = 'factor from {0} to {1}, median {2}'
$script:I18n['aucun cylindre où le besoin propre atteint {0} ns'] = 'no cylinder where the own need reaches {0} ns'
# Lecteur cible sans courbe propre du lecteur qui ecrit : courbe croisee telle quelle (Get-WriteFactorPlan,
# Start-WriteTabWrite, Start-PresetWrite, Update-WLevelUi, 140) ; Bibliotheque sans calibration automatique (Start-PresetWrite)
$script:I18n["Écriture pour le lecteur cible {0} : {1}, facteur 1,00 ; pas de courbe propre du lecteur {2} pour cette famille : courbe croisée telle quelle."] = 'Write for target drive {0}: {1}, factor 1.00; no own curve of drive {2} for this family: cross curve as is.'
$script:I18n["Mesure de la disquette avant l'écriture non faite : écriture pour le lecteur cible {0}, sans courbe propre du lecteur {1} pour cette famille. Écriture avec la courbe croisée telle quelle."] = 'Disk measurement before the write not done: write for target drive {0}, without an own curve of drive {1} for this family. Write with the cross curve as is.'
$script:I18n["Écriture pour le lecteur cible {0} : ni calibration automatique ni mesure de la disquette (pas de courbe propre du lecteur {1} pour cette famille) ; écriture avec la courbe croisée telle quelle."] = 'Write for target drive {0}: neither automatic calibration nor disk measurement (no own curve of drive {1} for this family); write with the cross curve as is.'
$script:I18n["Écriture pour le lecteur cible {0} : pas de calibration automatique du lecteur {1} (calibration {2} de la famille {3} absente ou à refaire) ; écriture sans mesure de la disquette, avec la courbe propre du lecteur {1} et le facteur par cylindre de la calibration croisée."] = 'Write for target drive {0}: no automatic calibration of drive {1} ({2} calibration of family {3} missing or to be redone); write without disk measurement, with the own curve of drive {1} and the per-cylinder factor of the cross calibration.'
# Case de la mesure (Update-WLevelUi, 140) : texte au « Test rapide » sans courbe propre, infobulles
$script:I18n["Mesurer la disquette avant l'écriture : toujours en « Test rapide », sauf pour le lecteur cible {0} (sans courbe du lecteur {1})"] = 'Measure the disk before the write: always with "Quick test", except for target drive {0} (no curve of drive {1})'
$script:I18n["Mesure de la disquette non disponible pour le lecteur cible {1} : pas de courbe propre du lecteur {0} pour cette famille, à laquelle la calibration croisée rapporte son facteur. L'image est écrite avec la courbe croisée telle quelle."] = 'Disk measurement not available for target drive {1}: no own curve of drive {0} for this family, to which the cross calibration relates its factor. The image is written with the cross curve as is.'
$script:I18n["Écriture pour le lecteur cible {1} : la disquette est mesurée par le lecteur {0}, celui qui écrit, comme pour une écriture ordinaire ; le facteur de la calibration croisée {0} → {1} est ensuite appliqué à la courbe de cette disquette, cylindre par cylindre."] = 'Write for target drive {1}: the disk is measured by drive {0}, the one that writes, as for an ordinary write; the factor of the cross calibration {0} → {1} is then applied to the curve of this disk, cylinder by cylinder.'
# Ligne « Ce qui va se passer » (Get-WritePlan, 145)
$script:I18n['pour le lecteur cible {0} : courbe de cette disquette × facteur par cylindre de la calibration croisée {1} → {0}'] = 'for target drive {0}: curve of this disk × per-cylinder factor of the cross calibration {1} → {0}'
$script:I18n['pour le lecteur cible {0} : facteur par cylindre de la calibration croisée'] = 'for target drive {0}: per-cylinder factor of the cross calibration'
# Infobulle de la liste « Lecteur cible » (Update-TargetDriveUi, 140) ; remplace celle de 018, retiree de l usage
$script:I18n["Lecteur qui relira la disquette écrite par le lecteur {0}, celui du bandeau.`n« (même lecteur) » : écriture ordinaire, avec la courbe du lecteur {0} et le facteur de marque.`nUn autre lecteur : la courbe de cette disquette (mesurée par le lecteur {0} si la mesure est demandée, sinon la courbe du lecteur {0} et son facteur de marque) est multipliée, cylindre par cylindre, par le facteur de « Calibrer pour un lecteur cible… » (courbe croisée « {0} → lecteur cible » rapportée à la courbe du lecteur {0}) ; sans courbe du lecteur {0} pour la famille, courbe croisée telle quelle, sans mesure ; sans courbe croisée pour la famille de l'image (ou du profil forcé), l'écriture est refusée. Jamais de calibration automatique ; le lecteur cible n'a pas à être branché ; le contrôle après écriture relit avec le lecteur {0}.`nSans effet sur l'écriture (le journal le dit) avec le profil Manuel, la case --precomp décochée, une image flux écrite telle quelle ou une image FM, GCR ou à codage propre ; écriture refusée en haute densité avec le profil Auto, et en écriture rapide quand les courbes croisées sont par tête seulement.`nLe choix est mémorisé pour le lecteur {0}."] = "Drive that will read the disk written by drive {0}, the one in the banner.`n""(same drive)"": ordinary write, with drive {0}'s curve and the brand factor.`nAnother drive: the curve of this disk (measured by drive {0} if the measurement is requested, otherwise drive {0}'s curve and its brand factor) is multiplied, cylinder by cylinder, by the factor of ""Calibrate for a target drive…"" (cross curve ""{0} → target drive"" relative to drive {0}'s curve); without a drive {0} curve for the family, cross curve as is, without measurement; without a cross curve for the image family (or that of the forced profile), the write is refused. Never an automatic calibration; the target drive does not need to be connected; the post-write check reads back with drive {0}.`nNo effect on the write (stated in the log) with the Manual profile, the --precomp box unchecked, a flux image written as is or an FM, GCR or system-specific-encoding image; write refused in high density with the Auto profile, and in a fast write when the cross curves are per head only.`nThe choice is remembered for drive {0}."
# Relecture de la rc2 : regles de la restauration pour un lecteur cible (Update-RsRules, ligne « Regles » du rapport, 300) ;
# remplacent celles de 018, retirees de l usage
$script:I18n["Règles appliquées à la copie : écriture tête par tête par le lecteur {0} avec la courbe croisée {0} → {1} et, si le lecteur {0} a sa courbe, son facteur de marque, sans calibration ni mesure de la destination, effacement avant l'écriture, vérification par gw, {2} essais par piste, contrôle de toutes les pistes ({3} passes de réécriture au plus), puis relecture par le lecteur {0} et comparaison avec l'original."] = 'Rules applied to the copy: head-by-head write by drive {0} with the cross curve {0} → {1} and, if drive {0} has its curve, its brand factor, without calibration or measurement of the destination, erase before writing, gw verification, {2} retries per track, check of all tracks (up to {3} rewrite passes), then read-back by drive {0} and comparison with the original.'
$script:I18n["Règles      : lecture {0} tours, {1} essais x {2} séries ; écriture tête par tête par le lecteur {5} avec la courbe croisée {5} → {6} et, si le lecteur {5} a sa courbe, son facteur de marque, sans calibration ni mesure de la destination, effacement avant l'écriture, vérification gw, {3} essais par piste ; contrôle de toutes les pistes, {4} passes de réécriture au plus ; relecture finale par le lecteur {5} sans nouvel essai."] = 'Rules       : read {0} revolutions, {1} retries x {2} series; head-by-head write by drive {5} with the cross curve {5} → {6} and, if drive {5} has its curve, its brand factor, without calibration or measurement of the destination, erase before writing, gw verification, {3} retries per track; check of all tracks, up to {4} rewrite passes; final read-back by drive {5} without retry.'
# Infobulle de la liste « Calibration precomp » (520) ; remplace celle de 018, retiree de l usage
$script:I18n["« Test rapide » avant une écriture lente, avec « complète, au motif » dans la liste « Mesure : » : mesure complète de cette disquette, sur tous ses cylindres (26 à 31 min), à la place de la calibration rapide. Lecteur cible choisi (liste « Lecteur cible »), avec effet sur l'écriture : la disquette est mesurée de même par le lecteur du bandeau juste avant l'écriture (« Calibrer » seul n'est pas proposé), puis le facteur par cylindre de la calibration croisée est appliqué ; sans courbe du lecteur du bandeau pour la famille de l'image, ni mesure ni calibration rapide (courbe croisée telle quelle)."] = '"Quick test" before a slow write, with "full, on the test pattern" in the "Measure:" list: full measurement of this disk, on all its cylinders (26 to 31 min), instead of the quick calibration. Target drive chosen ("Target drive" list), with an effect on the write: the disk is measured the same way by the banner drive just before the write ("Calibrate" alone is not offered), then the per-cylinder factor of the cross calibration is applied; without a curve of the banner drive for the image family, neither measurement nor quick calibration (cross curve as is).'
# Bouton « Calibrer » au « Test rapide » et carte de l Accueil, lecteur cible avec la courbe propre du lecteur (260)
$script:I18n["Calibration rapide seule non proposée pour le lecteur cible {0}. Pour mesurer cette disquette avec le lecteur {1} avant de l'écrire pour le lecteur cible, gardez « Test rapide » (ou cochez « Mesurer la disquette avant l'écriture lente ») et cliquez « ÉCRIRE LA DISQUETTE » : la mesure est faite juste avant l'écriture, puis le facteur par cylindre de la calibration croisée {1} → {0} est appliqué."] = 'Quick calibration alone not offered for target drive {0}. To measure this disk with drive {1} before writing it for the target drive, keep "Quick test" (or tick "Measure the disk before the slow write") and click "WRITE THE DISK": the measurement is made just before the write, then the per-cylinder factor of the cross calibration {1} → {0} is applied.'
$script:I18n["Calibration rapide depuis l'Accueil : lecteur cible {0} choisi pour le lecteur {1} : le profil de cette disquette n'est pas placé dans les champs --precomp ; l'écriture pour le lecteur cible ne reprend que la mesure faite par « ÉCRIRE LA DISQUETTE » juste avant l'écriture. Il reste affiché dans la fenêtre Courbe (dernière calibration rapide)."] = 'Quick calibration from the Home tab: target drive {0} chosen for drive {1}: the profile of this disk is not placed in the --precomp fields; the write for the target drive only uses the measurement made by "WRITE THE DISK" just before the write. It remains shown in the Curve window (last quick calibration).'
# Fenetre « Mesure de la disquette sur l image » (Start-ContentMeasure, 276), lecteur cible avec la courbe propre du lecteur
$script:I18n["Écriture pour le lecteur cible {1} : la courbe ainsi obtenue (niveau mesuré, ou facteur de la marque avec « Écrire sans mesure ») est ensuite multipliée, cylindre par cylindre, par le facteur de la calibration croisée {0} → {1} ; sans mesure ni facteur de la marque, la courbe croisée est écrite telle quelle."] = 'Write for target drive {1}: the curve so obtained (measured level, or brand factor with "Write without measuring") is then multiplied, cylinder by cylinder, by the factor of the cross calibration {0} → {1}; without measurement or brand factor, the cross curve is written as is.'
# Journal de l ecriture (Get-TargetTransferPlan, 140) : courbe propre du lecteur plus recente que la courbe croisee
$script:I18n['courbe du lecteur {0} postérieure à la calibration croisée {0} → {1}'] = 'curve of drive {0} newer than the cross calibration {0} → {1}'

# --- rc2.1 : garde de l ecriture pour un lecteur cible (140, 145) -------------------------------------------------------
# Raison (Get-TargetWriteInfo, ViewWhy) : les courbes chargees pour l ecriture « meme lecteur » ne sont pas les courbes
# propres du lecteur qui ecrit ; courbe croisee telle quelle (rc1), dit au journal, dans la case et dans la ligne
$script:I18n['les courbes chargées ne sont pas celles du lecteur {0} pour cette famille'] = 'the loaded curves are not those of drive {0} for this family'
$script:I18n["Écriture pour le lecteur cible {0} : {1}, facteur 1,00 ; {2} : courbe croisée telle quelle, sans le facteur par cylindre."] = 'Write for target drive {0}: {1}, factor 1.00; {2}: cross curve as is, without the per-cylinder factor.'
$script:I18n["Mesure de la disquette avant l'écriture non faite : écriture pour le lecteur cible {0} ({1}). Écriture avec la courbe croisée telle quelle."] = 'Disk measurement before the write not done: write for target drive {0} ({1}). Write with the cross curve as is.'
$script:I18n["Écriture pour le lecteur cible {0} : ni calibration automatique ni mesure de la disquette ({1}) ; écriture avec la courbe croisée telle quelle."] = 'Write for target drive {0}: neither automatic calibration nor disk measurement ({1}); write with the cross curve as is.'
$script:I18n["Mesure de la disquette non disponible pour le lecteur cible {0} : {1}. L'image est écrite avec la courbe croisée telle quelle, sans le facteur par cylindre."] = 'Disk measurement not available for target drive {0}: {1}. The image is written with the cross curve as is, without the per-cylinder factor.'
$script:I18n['pour le lecteur cible {0} : {1} telle quelle, sans le facteur par cylindre ({2})'] = 'for target drive {0}: {1} as is, without the per-cylinder factor ({2})'
# Relecture rc2.1 : courbes croisees par tete (Get-TargetCurvesText : « courbes croisees ... par tete »), accord au pluriel
$script:I18n['pour le lecteur cible {0} : {1} telles quelles, sans le facteur par cylindre ({2})'] = 'for target drive {0}: {1} as is, without the per-cylinder factor ({2})'
$script:I18n['pour le lecteur cible {0} : courbe croisée telle quelle'] = 'for target drive {0}: cross curve as is'

# --- rc3 : retours sur la rc2.2 (110, 530, 270, 230) ----------------------------------------------------------------------
# R3 : detection des lecteurs de la carte « Tester le Greaseweazle », diagnostic seulement (Complete-DriveDetect, 110)
$script:I18n['Connexions qui répondent : {0}.'] = 'Connections that respond: {0}.'
$script:I18n['La connexion {0} du lecteur du bandeau ne répond pas. Le lecteur du bandeau reste « {1} » : branchez-le, ou choisissez le lecteur branché dans la liste « Lecteur : ».'] = 'Connection {0} of the banner drive does not respond. The banner drive stays "{1}": plug it in, or choose the plugged-in drive in the "Drive:" list.'
# R5 (partie 1) : gw sans port du Greaseweazle, une nouvelle tentative (Test-GwPortRetry, 110)
$script:I18n["gw n'a pas pu ouvrir le port du Greaseweazle (carte déconnectée ou réinitialisée ?) : rien n'a été lu ni écrit. Nouvelle tentative de la même commande dans {0} s."] = 'gw could not open the Greaseweazle port (board disconnected or reset?): nothing was read or written. Retrying the same command in {0} s.'
$script:I18n["ERREUR : Greaseweazle déconnecté : gw n'a pas pu ouvrir son port, ni à la commande ni à la nouvelle tentative. Vérifiez le câble USB, le concentrateur USB et l'alimentation des lecteurs, puis relancez l'opération. Étape atteinte : {0}"] = 'ERROR: Greaseweazle disconnected: gw could not open its port, neither for the command nor for the retry. Check the USB cable, the USB hub and the drive power supply, then restart the operation. Step reached: {0}'

# --- rc4 : retours sur la rc3 (140, 145, 300, 520 ; R10 : 170, 190) -------------------------------------------------------
# Verification de gw (Get-WriteVerifyPlan, Get-WriteVerifyText, 140 ; R9 retire a la demande de l utilisateur, les deux gardees) :
# segment de la ligne « Ce qui va se passer », journal, infobulles
$script:I18n['sans vérification gw'] = 'no gw verification'
$script:I18n['vérification gw, {0} essai(s) au plus'] = 'gw verification, up to {0} retry(ies)'
$script:I18n['vérification gw, sans nouvel essai'] = 'gw verification, no retry'
$script:I18n['sans vérification gw (image flux écrite telle quelle)'] = 'no gw verification (flux image written as is)'
# R10 : controle apres une ecriture pour un lecteur cible avec le facteur par cylindre, relu par le lecteur qui a ecrit :
# asymetrie jugee sur son ecart a l asymetrie attendue (Get-AsymSummaryText, 190 ; Show-WriteCheckTable, 170) : journal,
# infobulle de la carte, en-tete de l export. Trois jugements, puis la part du score ; rien n est predit du lecteur cible
$script:I18n["Asymétrie conforme à l'attendu pour une écriture destinée au lecteur cible {0} (médiane attendue {1}, mesurée {2} ; relu par le lecteur {3})."] = 'Asymmetry as expected for a write intended for target drive {0} (median expected {1}, measured {2}; read back by drive {3}).'
$script:I18n["Asymétrie proche de l'attendu pour une écriture destinée au lecteur cible {0} (médiane attendue {1}, mesurée {2} ; relu par le lecteur {3})."] = 'Asymmetry close to the expected one for a write intended for target drive {0} (median expected {1}, measured {2}; read back by drive {3}).'
$script:I18n["Asymétrie éloignée de l'attendu pour une écriture destinée au lecteur cible {0} (médiane attendue {1}, mesurée {2} ; relu par le lecteur {3})."] = 'Asymmetry far from the expected one for a write intended for target drive {0} (median expected {1}, measured {2}; read back by drive {3}).'
$script:I18n["L'écart à l'attendu compte pour {0} point(s) du score moyen, au lieu de {1} pour l'asymétrie mesurée, et ne change pas l'état des pistes. La lecture par le lecteur {2} n'est pas prédite."] = 'The deviation from the expected value accounts for {0} point(s) of the mean score, instead of {1} for the measured asymmetry, and does not change the track status. Reading by drive {2} is not predicted.'
# R10 : infobulle du tableau (Update-QualityTip, 190), derniere ligne ; colonnes ajoutees a l export (Get-AlignTableExport)
$script:I18n["Contrôle d'une écriture pour un lecteur cible avec le facteur par cylindre : la case « Asym. » garde la valeur mesurée ; sa couleur et le score jugent l'écart à l'asymétrie attendue pour le lecteur qui relit."] = 'Check of a write for a target drive with the per-cylinder factor: the "Asym." cell keeps the measured value; its colour and the score judge the deviation from the asymmetry expected for the drive that reads back.'
$script:I18n['Asym. attendue'] = 'Expected asym.'
$script:I18n["Écart à l'attendu"] = 'Deviation from expected'
# R2 : borne de precompensation reglable dans les options avancees de l onglet Ecriture (520 ; Set-PrecompBound et
# Get-PrecompBoundText, 230 ; Update-WBoundUi, Get-PrecompBoundTip et Set-PrecompBoundFromUi, 145 ; Load-Config, 120) :
# libelle, element « automatique » de la liste, infobulle, journal
$script:I18n['Borne de précompensation :'] = 'Precompensation bound:'
$script:I18n['Automatique ({0} ns ; {1} ns en long track)'] = 'Automatic ({0} ns; {1} ns for long track)'
$script:I18n["Borne de précompensation : la plus forte valeur que la calibration du lecteur retient pour un cylindre."] = 'Precompensation bound: the highest value the drive calibration keeps for a cylinder.'
$script:I18n["Automatique : {0} ns pour une image standard (cellule de 2 us), {1} ns pour une image long track (le quart de sa cellule de 1,89 us). Valeur choisie, de {2} à {1} ns : la même pour les deux, {0} ns compris. La haute densité prend la moitié de la borne."] = 'Automatic: {0} ns for a standard image (2 us cell), {1} ns for a long track image (a quarter of its 1.89 us cell). Chosen value, from {2} to {1} ns: the same for both, {0} ns included. High density takes half the bound.'
$script:I18n["Au quart de la cellule, les intervalles écrits atteignent la limite au-delà de laquelle ils seraient lus pour d'autres : la borne ne dépasse pas {0} ns."] = 'At a quarter of the cell, written intervals reach the limit beyond which they would be read as others: the bound does not exceed {0} ns.'
$script:I18n["Borne d'au moins {0} ns : la courbe d'une seule disquette peut la dépasser quand son besoin est plus fort, jusqu'au quart de la cellule de la piste écrite ({1} ns au plus) ; borne choisie sous {0} ns : elle n'est jamais dépassée."] = 'Bound of at least {0} ns: the curve of a single disk may exceed it when its need is higher, up to a quarter of the cell of the written track ({1} ns at most); bound chosen below {0} ns: it is never exceeded.'
$script:I18n["Avec le réglage actuel, la courbe d'une mesure complète de la disquette impose le contrôle de toutes les pistes après l'écriture dès qu'elle dépasse {0} ns."] = 'With the current setting, the curve of a full measurement of the disk enforces the full track check after the write as soon as it exceeds {0} ns.'
$script:I18n["Une courbe déjà calculée garde la borne de son calcul : la nouvelle borne sert aux calibrations suivantes (le test rapide ramène à la borne en place les valeurs d'une référence calculée avec une borne plus haute). À l'écriture, la borne en place plafonne aussi la courbe multipliée par le facteur de précompensation et la mesure sur l'image : {0} ; une valeur déjà au-dessus n'est jamais augmentée."] = 'An already computed curve keeps the bound of its computation: the new bound applies to the following calibrations (the quick test brings the values of a reference computed with a higher bound back to the bound in place). At write time, the bound in place also caps the curve multiplied by the precompensation factor and the measurement on the image: {0}; a value already above it is never increased.'
$script:I18n["Enregistrée dans la configuration (precompMaxNs)."] = 'Saved in the configuration (precompMaxNs).'
$script:I18n['Borne de précompensation : {0} (avant : {1}).'] = 'Precompensation bound: {0} (before: {1}).'
$script:I18n["Borne de précompensation choisie : {0} ns en standard comme en long track (en automatique : {1} ns en long track) ; la haute densité en prend la moitié."] = 'Precompensation bound chosen: {0} ns for standard and long track alike (automatic setting: {1} ns for long track); high density takes half of it.'
$script:I18n['Borne de précompensation inchangée : une opération est en cours ou une calibration attend votre décision.'] = 'Precompensation bound unchanged: an operation is running or a calibration awaits your decision.'
# R5, partie 2 : reprise d une calibration interrompue (270). Etape et cause (Get-CalibStepInfo, Get-CalibStopCause),
# message d interruption (Set-CalibResume), ce qui differe au lancement suivant (Get-CalibResumeMismatch,
# Get-CalibResumeOffer), fenetre et journal de la reprise (Get-CalibResumeText), abandon (Clear-CalibResume)
$script:I18n['passe de mesure {0}/{1}'] = 'measurement pass {0}/{1}'
$script:I18n['vérification {0} du nouvel essai'] = 'verification {0} of the retry'
$script:I18n['conditionnement du lecteur'] = 'drive conditioning'
$script:I18n['{0}, pendant le {1}'] = '{0}, during the {1}'
$script:I18n['arrêt à votre demande'] = 'stopped at your request'
$script:I18n['relevé de la passe absent ou illisible'] = 'flux capture of the pass missing or unreadable'
$script:I18n["Greaseweazle déconnecté, gw n'a pas pu ouvrir son port, même à la nouvelle tentative"] = 'Greaseweazle disconnected, gw could not open its port, even on the retry'
$script:I18n['commande gw incomplète (disquette protégée en écriture ou absente, lecteur en défaut ?)'] = 'incomplete gw command (write-protected or missing disk, faulty drive?)'
$script:I18n['erreur de gw (code retour {0})'] = 'gw error (exit code {0})'
$script:I18n["Calibration interrompue à l'étape {0} ({1}) : {2}. Aucune passe n'était terminée : rien n'est gardé, la calibration est à recommencer."] = 'Calibration interrupted at step {0} ({1}): {2}. No pass was complete: nothing is kept, the calibration has to be started again.'
$script:I18n["Calibration interrompue à l'étape {0} ({1}) : {2}. Passes faites, gardées en mémoire : {3}."] = 'Calibration interrupted at step {0} ({1}): {2}. Passes done, kept in memory: {3}.'
$script:I18n["Reprise possible tant que l'application reste ouverte : relancez la même calibration (mêmes lecteurs, même famille, même test, même choix d'une courbe par tête, même image ou même type de disquette, mêmes options de lecteur et même borne de précompensation), avec la même disquette ; une fenêtre proposera de reprendre à l'étape {0}, rejouée en entier."] = 'It can be resumed as long as the application stays open: start the same calibration again (same drives, same family, same test, same choice of one curve per head, same image or same disk type, same drive options and same precompensation bound), with the same disk; a window will offer to resume at step {0}, replayed in full.'
$script:I18n['La disquette est dans le lecteur {0}, {1}.'] = 'The disk is in drive {0}, {1}.'
$script:I18n["Calibration interrompue : relancez-la pour reprendre à l'étape {0}."] = 'Calibration interrupted: start it again to resume at step {0}.'
$script:I18n['calibration croisée {0} → {1}, {2}, {3}'] = 'cross calibration {0} → {1}, {2}, {3}'
$script:I18n['calibration du lecteur {0}, {1}, {2}'] = 'calibration of drive {0}, {1}, {2}'
$script:I18n['lecteur cible'] = 'target drive'
$script:I18n["options de lecteur de l'onglet Écriture ou borne de précompensation"] = 'drive options of the Write tab or precompensation bound'
$script:I18n['ce qui diffère : {0}'] = 'what differs: {0}'
$script:I18n["ce lancement n'est pas une calibration du lecteur faite pour elle-même"] = 'this launch is not a drive calibration run for its own sake'
$script:I18n["Une calibration interrompue est gardée en mémoire ({0}, à reprendre à l'étape {1}) : ce lancement ne peut pas la reprendre ({2}). Si vous lancez cette calibration, ses passes faites seront abandonnées."] = 'An interrupted calibration is kept in memory ({0}, to be resumed at step {1}): this launch cannot resume it ({2}). If you start this calibration, its completed passes will be discarded.'
$script:I18n['Reprendre la calibration interrompue ?'] = 'Resume the interrupted calibration?'
$script:I18n["Reprendre à l'étape {0}"] = 'Resume at step {0}'
$script:I18n['Recommencer'] = 'Start again'
$script:I18n["La {0} a été interrompue à l'étape {1} ({2}) : {3}."] = 'The {0} was interrupted at step {1} ({2}): {3}.'
$script:I18n['Passes faites, gardées en mémoire : {0}.'] = 'Passes done, kept in memory: {0}.'
$script:I18n["Reprendre : l'étape {0} ({1}) est rejouée en entier, ses pistes de nouveau effacées, écrites puis relues (une écriture de plus que prévu sur ces pistes). La calibration continue ensuite avec les mesures gardées : son résultat est calculé comme sans interruption."] = 'Resume: step {0} ({1}) is replayed in full, its tracks erased, written and read back again (one more write than planned on these tracks). The calibration then goes on with the measurements kept: its result is computed as without the interruption.'
$script:I18n["Utilisez la même disquette. Elle doit se trouver dans le lecteur {0}, {1} : c'est là que le journal l'annonçait à l'interruption. Si vous l'avez déplacée, remettez-la dans ce lecteur avant de reprendre ; l'application demandera ensuite chaque échange, comme avant."] = 'Use the same disk. It must be in drive {0}, {1}: that is where the log said it was at the interruption. If you moved it, put it back in this drive before resuming; the application will then ask for each swap, as before.'
$script:I18n['Utilisez la même disquette, dans le lecteur {0}.'] = 'Use the same disk, in drive {0}.'
$script:I18n['Recommencer : les mesures gardées sont abandonnées, et la calibration repart de son avertissement.'] = 'Start again: the measurements kept are discarded, and the calibration starts over from its warning.'
$script:I18n["Fermer : rien n'est lancé ; la calibration reste à reprendre tant que l'application est ouverte et qu'aucune autre calibration du lecteur ni mesure complète d'une disquette ne commence ; une calibration rapide ou une mesure sur l'image ne l'abandonne pas."] = 'Close: nothing is started; the calibration can still be resumed as long as the application is open and no other drive calibration or full measurement of a disk starts; a quick calibration or a measurement on the image does not discard it.'
$script:I18n["=== Calibration reprise à l'étape {0} ({1}) : {2} passe(s) gardée(s) ({3}) ; l'étape interrompue est rejouée en entier ==="] = '=== Calibration resumed at step {0} ({1}): {2} pass(es) kept ({3}); the interrupted step is replayed in full ==='
$script:I18n["Calibration croisée reprise : disquette attendue dans le lecteur {0}, {1}, là où le journal l'annonçait à l'interruption."] = 'Cross calibration resumed: disk expected in drive {0}, {1}, where the log said it was at the interruption.'
$script:I18n['Calibration interrompue ({0}) : passes gardées abandonnées ({1}).'] = 'Interrupted calibration ({0}): passes kept discarded ({1}).'
$script:I18n['densité du motif différente'] = 'different pattern density'
$script:I18n['calibration recommencée à votre demande'] = 'calibration started again at your request'
$script:I18n['une autre calibration commence'] = 'another calibration starts'

# Decisions de l utilisateur (rc4) : borne de la courbe ecrite selon la famille (Get-PrecompBoundTip, 145) ; chute du
# besoin vers c43/c44, signature de la zone interieure (Test-InnerZoneBreak, 270)
$script:I18n['{0} ns au plus, {1} ns en long track'] = '{0} ns at most, {1} ns in long track'
$script:I18n['{0} ns au plus, long track compris'] = '{0} ns at most, long track included'
$script:I18n["Cette chute du besoin vers les cylindres 43 et 44 est une signature connue de nombreux lecteurs 3,5 pouces (zone intérieure du disque) : la courbe est correcte, rien à refaire."] = 'This drop of the need around cylinders 43 and 44 is a known signature of many 3.5-inch drives (inner zone of the disk): the curve is correct, nothing to redo.'
# rc4 (R1, R4) : fenetre « Lecteurs » a deux volets, gestes et leurs fenetres (112), bouton « Lecteurs... » du bandeau
# (510), calibration croisee depuis l Accueil (200, 270), textes d « Effacer les calibrations » (240) et de « Reinitialiser » (540)
$script:I18n['nappe PC avec twist'] = 'PC cable with twist'
$script:I18n['nappe droite'] = 'straight cable'
$script:I18n['aucune calibration'] = 'no calibration'
$script:I18n['{0} courbe(s), dont {1} croisée(s)'] = '{0} curve(s), {1} of them cross'
$script:I18n['{0} courbe(s)'] = '{0} curve(s)'
$script:I18n['Connexion à préciser'] = 'Connection to be set'
$script:I18n['aucun lecteur nommé'] = 'no named drive'
$script:I18n['1 lecteur nommé'] = '1 named drive'
$script:I18n['{0} lecteurs nommés'] = '{0} named drives'
$script:I18n['Connexion {0}'] = 'Connection {0}'
$script:I18n['Écrites par ce lecteur pour le lecteur cible {0} (courbes croisées)'] = 'Written by this drive for target drive {0} (cross curves)'
$script:I18n['Écrites par le lecteur {0} pour ce lecteur (courbes croisées)'] = 'Written by drive {0} for this drive (cross curves)'
$script:I18n['Écrites et relues par ce lecteur (courbes propres)'] = 'Written and read back by this drive (own curves)'
$script:I18n['Écrites et relues sur la connexion {0}, sans nom de lecteur'] = 'Written and read back on connection {0}, without a drive name'
$script:I18n['Connexion {0} ({1})'] = 'Connection {0} ({1})'
$script:I18n['lecteur choisi dans le bandeau'] = 'drive selected in the banner'
$script:I18n['lecteur sans nom'] = 'unnamed drive'
$script:I18n['lecteur nommé'] = 'named drive'
$script:I18n['Lecteur cible de ses écritures : {0} (réglé dans l''onglet Écriture).'] = 'Target drive of its writes: {0} (set in the Write tab).'
$script:I18n['Lecteur cible de ses écritures : aucun.'] = 'Target drive of its writes: none.'
$script:I18n["Renommer : tout ce qui est affiché ici suit le lecteur sous son nouveau nom.`nChanger de connexion : rien n'est modifié, le lecteur garde ses calibrations.`nSupprimer : le lecteur et tout ce qui est affiché ici sont retirés, après une copie de la configuration."] = "Rename: everything shown here follows the drive under its new name.`nChange connection: nothing is modified, the drive keeps its calibrations.`nDelete: the drive and everything shown here are removed, after a copy of the configuration."
$script:I18n['Ces calibrations ont été faites en choisissant « {0} » dans la liste « Lecteur : » du bandeau : l''application ne sait pas avec quel lecteur. Elles ne servent que lorsque « {0} » est choisi dans le bandeau. Si elles viennent d''un de vos lecteurs, « Donner un nom… » les range sous son nom.'] = 'These calibrations were made with "{0}" selected in the "Drive:" list of the banner: the application does not know with which drive. They are only used when "{0}" is selected in the banner. If they come from one of your drives, "Give a name…" files them under its name.'
$script:I18n['Aucune calibration faite sans nom de lecteur sur la connexion {0}.'] = 'No calibration made without a drive name on connection {0}.'
$script:I18n["Donner un nom : ces calibrations passent sous le nom choisi ; la connexion {0} garde un lecteur sans nom, sans calibration.`nSupprimer ses calibrations : elles sont retirées, après une copie de la configuration.`nUn lecteur sans nom ne change pas de connexion : donnez-lui d'abord un nom."] = "Give a name: these calibrations move under the chosen name; connection {0} keeps an unnamed drive, without calibration.`nDelete its calibrations: they are removed, after a copy of the configuration.`nAn unnamed drive does not change connection: give it a name first."
$script:I18n['Aussi rangés sous ce lecteur : niveaux de la calibration rapide ({0}), mémoire par marque ({1}), facteurs mesurés ({2}).'] = 'Also filed under this drive: quick calibration levels ({0}), per-brand memory ({1}), measured factors ({2}).'
$script:I18n['Supprimer les calibrations de « {0} » ?'] = 'Delete the calibrations of "{0}"?'
$script:I18n['Les calibrations de « {0} » ne serviront plus'] = 'The calibrations of "{0}" will no longer be used'
$script:I18n['Supprimer ses calibrations'] = 'Delete its calibrations'
$script:I18n['Calibrations de « {0} » supprimées : {1} courbe(s) retirée(s).'] = 'Calibrations of "{0}" deleted: {1} curve(s) removed.'
$script:I18n['Chaque lecteur a un nom et une connexion au Greaseweazle ; ses calibrations sont rangées sous son nom, et plusieurs lecteurs peuvent partager une connexion. L''application ne reconnaît pas le lecteur branché : le lecteur utilisé est celui choisi dans la liste « Lecteur : » du bandeau.'] = 'Each drive has a name and a connection to the Greaseweazle; its calibrations are filed under its name, and several drives can share a connection. The application cannot recognise the drive that is plugged in: the drive used is the one selected in the "Drive:" list of the banner.'
$script:I18n['Connexions et lecteurs'] = 'Connections and drives'
$script:I18n['En gras : le lecteur choisi dans le bandeau.'] = 'In bold: the drive selected in the banner.'
$script:I18n['Voir la courbe'] = 'View the curve'
$script:I18n['Ses calibrations'] = 'Its calibrations'
$script:I18n['Date'] = 'Date'
$script:I18n['Borne'] = 'Limit'
$script:I18n['Ajouter un lecteur…'] = 'Add a drive…'
$script:I18n['Renommer…'] = 'Rename…'
$script:I18n['Changer de connexion…'] = 'Change connection…'
$script:I18n['Donner un nom…'] = 'Give a name…'
$script:I18n['Supprimer ses calibrations…'] = 'Delete its calibrations…'
$script:I18n['Lecteur du bandeau : « {0} », choisi à son ajout.'] = 'Banner drive: "{0}", selected when added.'
$script:I18n['déjà : {0}'] = 'already: {0}'
$script:I18n['La connexion {0} a déjà des calibrations sans nom de lecteur : {1}. Ont-elles été faites avec ce lecteur ?'] = 'Connection {0} already has calibrations without a drive name: {1}. Were they made with this drive?'
$script:I18n['Ajouter un lecteur de disquette'] = 'Add a floppy drive'
$script:I18n['Donnez un nom au lecteur et indiquez sa connexion au Greaseweazle. Plusieurs lecteurs peuvent partager une connexion : vous choisirez dans le bandeau celui qui est branché.'] = 'Give the drive a name and state its connection to the Greaseweazle. Several drives can share a connection: you will select in the banner the one that is plugged in.'
$script:I18n['Ajouter le lecteur'] = 'Add the drive'
$script:I18n['Donner un nom à « {0} »'] = 'Give a name to "{0}"'
$script:I18n['Le lecteur garde sa connexion {0}. Plusieurs lecteurs peuvent partager une connexion : vous choisirez dans le bandeau celui qui est branché.'] = 'The drive keeps its connection {0}. Several drives can share a connection: you will select in the banner the one that is plugged in.'
$script:I18n['Donner ce nom'] = 'Give this name'
$script:I18n['Renommer le lecteur « {0} »'] = 'Rename drive "{0}"'
$script:I18n['Tout ce qui est rangé sous ce lecteur suit son nouveau nom : ses calibrations, son lecteur cible, ses niveaux, sa mémoire par marque et ses facteurs mesurés. Rien n''est recalculé ; la configuration est d''abord copiée.'] = 'Everything filed under this drive follows its new name: its calibrations, its target drive, its levels, its per-brand memory and its measured factors. Nothing is recalculated; the configuration is copied first.'
$script:I18n['Renommer'] = 'Rename'
$script:I18n['Changer la connexion du lecteur « {0} »'] = 'Change the connection of drive "{0}"'
$script:I18n['Rien n''est modifié : le lecteur garde ses calibrations, son lecteur cible et ses autres données. Choisissez la connexion où il est branché maintenant. Après un changement de nappe, contrôlez une écriture (onglet Qualité) ou refaites une calibration rapide.'] = 'Nothing is modified: the drive keeps its calibrations, its target drive and its other data. Select the connection where it is plugged in now. After a cable change, check a write (Quality tab) or redo a quick calibration.'
$script:I18n['Changer de connexion'] = 'Change connection'
$script:I18n['24 caractères au plus (environ 17, selon leur largeur)'] = '24 characters at most (about 17, depending on their width)'
$script:I18n['Non, c''est un autre lecteur : il part sans calibration. Ces calibrations restent sous « {0} ».'] = 'No, it is another drive: it starts without calibration. These calibrations stay under "{0}".'
$script:I18n['Oui : elles deviennent les siennes et sont rangées sous son nom. Rien n''est recalculé ; la configuration est d''abord copiée.'] = 'Yes: they become its own and are filed under its name. Nothing is recalculated; the configuration is copied first.'
$script:I18n['C''est le lecteur branché en ce moment sur la connexion {0} : le choisir dans le bandeau'] = 'It is the drive plugged into connection {0} right now: select it in the banner'
$script:I18n['Lecteurs…'] = 'Drives…'
$script:I18n['Lecteurs : noms, connexions et calibrations de chaque lecteur'] = 'Drives: names, connections and calibrations of each drive'
$script:I18n['Calibration croisée pour un lecteur cible…'] = 'Cross calibration for a target drive…'
$script:I18n['« Calibration croisée pour un lecteur cible… » : {0} écrit, un autre lecteur relit. Pour les disquettes écrites ici puis lues par cet autre lecteur.'] = '"Cross calibration for a target drive…": {0} writes, another drive reads back. For floppies written here and then read by that other drive.'
$script:I18n['famille sans calibration croisée'] = 'family without cross calibration'
$script:I18n['Calibration croisée impossible pour {0} : seules les familles {1} et {2} se calibrent pour un lecteur cible.'] = 'Cross calibration impossible for {0}: only the {1} and {2} families can be calibrated for a target drive.'
$script:I18n['Type de disquette choisi dans l''Accueil : {0} ({1}), {2} cylindres ; avec l''autre famille, 80 cylindres à sa densité.'] = 'Floppy type selected on Home: {0} ({1}), {2} cylinders; with the other family, 80 cylinders at its density.'
$script:I18n['80 cylindres, à la densité de la famille choisie'] = '80 cylinders, at the density of the chosen family'
$script:I18n['Vos lecteurs ne sont pas supprimés : {0} restent dans la liste du bandeau et dans la fenêtre « Lecteurs », sans calibration. Pour retirer aussi un lecteur : bouton « Lecteurs… » du bandeau, puis « Supprimer… ».'] = 'Your drives are not deleted: {0} stay in the banner list and in the "Drives" window, without calibration. To remove a drive as well: "Drives…" button of the banner, then "Delete…".'
$script:I18n["Remettre tous les réglages de l'interface à leurs valeurs par défaut ?`n`nVos lecteurs et leurs calibrations ne sont pas touchés : ils gardent leur nom, leur connexion, leurs courbes et leur lecteur cible ; la liste « Lecteur : » du bandeau revient à la connexion par défaut. La configuration est réenregistrée aussitôt.`n`nPour effacer les calibrations : onglet Écriture, options avancées, « Effacer les calibrations ». Pour retirer un lecteur : bouton « Lecteurs… » du bandeau, puis « Supprimer… ».`n`n(Aucun effet sur le Greaseweazle, ni sur vos fichiers image, ni sur l'index de la bibliothèque.)"] = "Reset all interface settings to their default values?`n`nYour drives and their calibrations are not touched: they keep their name, their connection, their curves and their target drive; the ""Drive:"" list of the banner goes back to the default connection. The configuration is saved again immediately.`n`nTo clear the calibrations: Write tab, advanced options, ""Clear calibrations"". To remove a drive: ""Drives…"" button of the banner, then ""Delete…"".`n`n(No effect on the Greaseweazle, on your image files or on the library index.)"
$script:I18n['Valeurs par défaut restaurées ; lecteurs et calibrations gardés, configuration réenregistrée.'] = 'Default values restored; drives and calibrations kept, configuration saved again.'
$script:I18n['Valeurs par défaut restaurées ; configuration non réenregistrée (voir le journal).'] = 'Default values restored; configuration not saved again (see the log).'

# --- rc5 : facteur de la disquette sous le seuil XferMinNs (140, R13) ------------------------------------------------------
$script:I18n['c{0} sous {1} ns : facteur du cylindre c{2} repris'] = 'c{0} below {1} ns: factor of cylinder c{2} reused'
$script:I18n['c{0} sous {1} ns : facteur moyen de la disquette repris ({2})'] = 'c{0} below {1} ns: mean factor of the disk reused ({2})'
$script:I18n['c{0} sous {1} ns : écart reporté en ns'] = 'c{0} below {1} ns: difference carried over in ns'

# --- rc6 : facteur de la disquette par l asymetrie (274, 276, R15) et report borne vers le lecteur cible (140) ---------------
$script:I18n["Facteur par l'asymétrie : k = {0} ± {1} (jackknife par zone {2} ; pente {3} × 2/cellule, t = {4} ; {5} cylindres à 2 niveaux au moins, {6} pistes ; écart-type résiduel {7})."] = 'Factor from asymmetry: k = {0} ± {1} (jackknife by zone {2}; slope {3} × 2/cell, t = {4}; {5} cylinders with 2 levels or more, {6} tracks; residual standard deviation {7}).'
$script:I18n["Facteur par l'asymétrie non déterminé ({0}) : la marge décide."] = 'Factor from asymmetry not determined ({0}): the margin decides.'
$script:I18n['{0} cylindres à 2 niveaux lisibles, il en faut {1}'] = '{0} cylinders with 2 readable levels, {1} needed'
$script:I18n["pente de l'asymétrie {0} × 2/cellule, hors de {1} à {2}"] = 'asymmetry slope {0} × 2/cell, outside {1} to {2}'
$script:I18n["pente de l'asymétrie peu marquée (t = {0}, il faut {1})"] = 'asymmetry slope too weak (t = {0}, {1} needed)'
$script:I18n['k = {0} ± {1}, incertitude au-delà de {2}'] = 'k = {0} ± {1}, uncertainty above {2}'
$script:I18n['k = {0} hors de {1} à {2}'] = 'k = {0} outside {1} to {2}'
$script:I18n['k = {0} au-delà de {1} fois le plus haut niveau écrit ({2})'] = 'k = {0} above {1} times the highest level written ({2})'
$script:I18n['{0}Marge plate (t = {1}, il faut au moins 2) : pas de facteur par la marge.'] = '{0}Flat margin (t = {1}, at least 2 needed): no factor from the margin.'
$script:I18n['{0}Facteur par la marge peu déterminé : k = {1} ± {2}.'] = '{0}Factor from the margin poorly determined: k = {1} ± {2}.'
$script:I18n['{0}Optimum de la marge au-delà de la borne {1} du facteur.'] = '{0}Margin optimum beyond the factor bound {1}.'
$script:I18n['{0}Facteur par la marge non mesuré ({1}).'] = '{0}Factor from the margin not measured ({1}).'
$script:I18n["{0}Facteur appliqué : k = {1}, par l'asymétrie."] = '{0}Factor applied: k = {1}, from asymmetry.'
$script:I18n["{0}Facteur appliqué : k = {1}, par l'asymétrie ; la marge donnait k = {2}, écart au-delà de {3}."] = '{0}Factor applied: k = {1}, from asymmetry; the margin gave k = {2}, a difference above {3}.'
$script:I18n["k {0} mesuré par l'asymétrie"] = 'k {0} measured from asymmetry'
$script:I18n["Mesure de la disquette sur l'image terminée en {0} : écriture de l'image (tête 0 : {1} ; tête 1 : {2})."] = 'Disk measurement on the image finished in {0}: writing the image (head 0: {1}; head 1: {2}).'
$script:I18n["Facteurs mesurés sur l'image avant la 12.11 : le facteur se règle désormais par l'asymétrie de lecture, ils ne sont plus appliqués. Refaites une mesure sur l'image pour chaque marque."] = 'Factors measured on the image before 12.11: the factor is now set from the read asymmetry; they are no longer applied. Measure again on the image for each brand.'
$script:I18n['c{0} : besoin de la disquette au-dessus de la courbe du lecteur, hausse reportée en ns'] = 'c{0}: disk need above the drive curve, increase carried over in ns'

# --- rc6 : asymetrie attendue d une ecriture pour un lecteur cible dans l onglet Qualite (190, 195, 170, R14) ----------------
$script:I18n["Lecteur cible {0} : asymétrie conforme à l'attendu (attendue {1}, mesurée {2})"] = 'Target drive {0}: asymmetry as expected (expected {1}, measured {2})'
$script:I18n["Lecteur cible {0} : asymétrie proche de l'attendu (attendue {1}, mesurée {2})"] = 'Target drive {0}: asymmetry close to the expected one (expected {1}, measured {2})'
$script:I18n["Lecteur cible {0} : asymétrie éloignée de l'attendu (attendue {1}, mesurée {2})"] = 'Target drive {0}: asymmetry far from the expected one (expected {1}, measured {2})'
$script:I18n["Asymétrie conforme à l'attendu (attendue {0}, mesurée {1})"] = 'Asymmetry as expected (expected {0}, measured {1})'
$script:I18n["Asymétrie proche de l'attendu (attendue {0}, mesurée {1})"] = 'Asymmetry close to the expected one (expected {0}, measured {1})'
$script:I18n["Asymétrie éloignée de l'attendu (attendue {0}, mesurée {1})"] = 'Asymmetry far from the expected one (expected {0}, measured {1})'
$script:I18n["disquette sous-compensée d'environ {0} ns"] = 'disk under-compensated by about {0} ns'
$script:I18n["disquette sur-compensée d'environ {0} ns"] = 'disk over-compensated by about {0} ns'
$script:I18n["disquette sous-compensée pour le lecteur cible d'environ {0} ns"] = 'disk under-compensated for the target drive by about {0} ns'
$script:I18n["disquette sur-compensée pour le lecteur cible d'environ {0} ns"] = 'disk over-compensated for the target drive by about {0} ns'
$script:I18n['{0} ; {1}'] = '{0}; {1}'
$script:I18n['Attendue'] = 'Expected'
$script:I18n['Écart'] = 'Gap'

# --- rc7 : correction par zones d une ecriture pour un lecteur cible, gain de l asymetrie attendue par la pente mesuree (140, 145, 170, 520, R16) --
# Gain de l asymetrie attendue (journal de l ecriture, 170)
$script:I18n["tête {0} : g = {1}, deux fois la pente mesurée sur l'image"] = 'head {0}: g = {1}, twice the slope measured on the image'
$script:I18n['tête {0} : g = {1} par défaut, pente non mesurée'] = 'head {0}: g = {1} by default, slope not measured'
$script:I18n['Contrôle après écriture : asymétrie attendue = g × excès de précompensation / cellule ; {0}.'] = 'Post-write check: expected asymmetry = g × precompensation excess / cell; {0}.'
# Zones du controle (170)
$script:I18n['tête {0} c{1}'] = 'head {0} c{1}'
$script:I18n['{0} : écart médian {1} ns, correction {2} ns'] = '{0}: median gap {1} ns, correction {2} ns'
$script:I18n["Contrôle après écriture : {0} zone(s) écartée(s) de l'attendu à la relecture par le lecteur {1} ({2}). Leurs {3} piste(s) sont réécrites à la passe {4}/{5} avec la précompensation décalée sur ces cylindres, puis relues ; une zone qui ne se rapproche pas de l'attendu reprend sa courbe d'origine."] = 'Post-write check: {0} zone(s) away from the expected value when read back by drive {1} ({2}). Their {3} track(s) are rewritten in pass {4}/{5} with the precompensation shifted on these cylinders, then read back; a zone that does not move closer to the expected value gets its original curve back.'
$script:I18n["Zone écartée de l'attendu, {0} : écart médian {1} ns avant la correction de {2} ns, {3} piste(s) saine(s) relue(s) après, il en faut {4} : correction reprise, courbe d'origine sur ces cylindres, pistes réécrites à la passe suivante."] = 'Zone away from the expected value, {0}: median gap {1} ns before the {2} ns correction, {3} healthy track(s) read back after it, {4} needed: correction withdrawn, original curve on these cylinders, tracks rewritten in the next pass.'
$script:I18n["Zone écartée de l'attendu, {0} : écart médian {1} ns avant, {2} ns après la correction de {3} ns (relecture par le lecteur {4}) : correction gardée."] = 'Zone away from the expected value, {0}: median gap {1} ns before, {2} ns after the {3} ns correction (read back by drive {4}): correction kept.'
$script:I18n["Zone écartée de l'attendu, {0} : écart médian {1} ns avant, {2} ns après la correction de {3} ns (relecture par le lecteur {4}) : correction reprise, courbe d'origine sur ces cylindres, pistes réécrites à la passe suivante."] = 'Zone away from the expected value, {0}: median gap {1} ns before, {2} ns after the {3} ns correction (read back by drive {4}): correction withdrawn, original curve on these cylinders, tracks rewritten in the next pass.'
$script:I18n["Contrôle après écriture : réécriture {0}/{1} de {2} piste(s) (pistes faibles et zones écartées de l'attendu)..."] = 'Post-write check: rewrite {0}/{1} of {2} track(s) (weak tracks and zones away from the expected value)...'
$script:I18n["Contrôle après écriture : effacement haute fréquence avant la réécriture {0}/{1} de {2} piste(s) (pistes faibles et zones écartées de l'attendu)..."] = 'Post-write check: high-frequency erase before rewrite {0}/{1} of {2} track(s) (weak tracks and zones away from the expected value)...'
$script:I18n["Effacement haute fréquence des pistes à réécrire (pistes faibles et zones écartées de l'attendu) avant leur réécriture (disquette double densité) : {0}."] = 'High-frequency erase of the tracks to rewrite (weak tracks and zones away from the expected value) before their rewrite (double-density disk): {0}.'
$script:I18n[" ; zones écartées de l'attendu : {0} corrigée(s) sur {1}, {2} non jugée(s), leurs pistes ont pu être réécrites avec la correction"] = '; zones away from the expected value: {0} corrected of {1}, {2} not judged, their tracks may have been rewritten with the correction'
$script:I18n[" ; zones écartées de l'attendu corrigées : {0} sur {1}"] = '; zones away from the expected value corrected: {0} of {1}'
$script:I18n[' ; zones corrigées : {0} sur {1}'] = '; zones corrected: {0} of {1}'
# Ligne « Ce qui va se passer » (145) et case des options avancees (520)
$script:I18n["correction des zones écartées de l'attendu, d'après la relecture par le lecteur qui écrit"] = 'correction of zones away from the expected value, based on the read-back by the writing drive'
$script:I18n["Corriger les zones écartées de l'attendu (lecteur cible)"] = 'Correct zones away from the expected value (target drive)'
$script:I18n["Écriture pour un lecteur cible avec le facteur par cylindre, contrôle de toutes les pistes et 2 passes de réécriture au moins : quand plusieurs cylindres voisins ({0} au moins) relus par le lecteur qui écrit s'écartent dans le même sens de l'asymétrie attendue, leurs pistes sont réécrites une fois avec la précompensation décalée de la moitié de l'écart ({1} ns au plus), puis relues. La correction est gardée si la zone se rapproche de l'attendu, sinon la zone reprend sa courbe d'origine. Une piste isolée n'est jamais corrigée.`nLa correction ne s'appuie que sur la relecture par le lecteur qui écrit : elle ne garantit pas la lecture par le lecteur cible."] = "Write for a target drive with the per-cylinder factor, check of all tracks and at least 2 rewrite passes: when several neighbouring cylinders (at least {0}) read back by the writing drive deviate in the same direction from the expected asymmetry, their tracks are rewritten once with the precompensation shifted by half the gap (at most {1} ns), then read back. The correction is kept if the zone moves closer to the expected value; otherwise the zone gets its original curve back. An isolated track is never corrected.`nThe correction relies only on the read-back by the writing drive: it does not guarantee reading by the target drive."

# --- rc8 : recalage de la courbe croisee par une relecture du lecteur cible (172, 112, 120, 140, 240, R17) ------------------
# Journal de l ecriture pour le lecteur cible (Get-TargetRecalPlan, 172 ; Get-TargetTransferPlan, 140)
$script:I18n['tête {0} : courbe croisée recalibrée ou calcul changé depuis le recalage'] = 'head {0}: cross curve recalibrated or calculation changed since the adjustment'
$script:I18n['tête {0} : facteur de la disquette non mesuré (k = 1 par défaut)'] = 'head {0}: disk factor not measured (k = 1 by default)'
$script:I18n['recalage du lecteur cible non appliqué : profil Manuel'] = 'target drive adjustment not applied: Manual profile'
$script:I18n['{0} ns'] = '{0} ns'
$script:I18n['tête 0 {0}, tête 1 {1}'] = 'head 0 {0}, head 1 {1}'
$script:I18n['{0} ns, moyenne des deux têtes'] = '{0} ns, mean of both heads'
$script:I18n['recalage du lecteur cible : {0} ({1} relecture(s), dernière le {2}), arrondi au ns et ajouté à la courbe écrite'] = 'target drive adjustment: {0} ({1} read-back(s), last on {2}), rounded to the ns and added to the written curve'
$script:I18n['non appliqué : {0}'] = 'not applied: {0}'
$script:I18n['recalage du lecteur cible non appliqué : {0}'] = 'target drive adjustment not applied: {0}'
# Memoire de l ecriture (172)
$script:I18n["Écriture pour le lecteur cible {0} interrompue : elle ne servira pas à recaler la courbe croisée {1} → {0}."] = 'Write for target drive {0} interrupted: it will not be used to adjust the cross curve {1} → {0}.'
$script:I18n["Écriture pour le lecteur cible {0} gardée en mémoire ({1}, {2} piste(s)) : une mesure de cette disquette par le lecteur {0} dans l'onglet « Qualité & alignement » pourra recaler la courbe croisée {3} → {0}."] = 'Write for target drive {0} kept in memory ({1}, {2} track(s)): a measurement of this disk by drive {0} in the "Quality & alignment" tab can adjust the cross curve {3} → {0}.'
# Relecture par le lecteur cible : raisons d un refus (172)
$script:I18n['aucune écriture pour le lecteur cible {0} en mémoire'] = 'no write for target drive {0} in memory'
$script:I18n["lecteur {0} : ce n'est pas le lecteur cible de l'écriture ({1})"] = 'drive {0}: not the target drive of the write ({1})'
$script:I18n["la relecture n'est pas « SUPPORT SAIN » (piste(s) illisible(s), marginale(s), en erreur ou instable(s) : {0})"] = 'the read-back is not "MEDIA HEALTHY" (unreadable, marginal, failing or unstable track(s): {0})'
$script:I18n["{0} piste(s) relue(s), l'écriture en a écrit {1} : mesurez les mêmes cylindres et les mêmes têtes"] = '{0} track(s) read back, the write wrote {1}: measure the same cylinders and the same heads'
$script:I18n['têtes relues {0}, têtes écrites {1}'] = 'heads read back {0}, heads written {1}'
$script:I18n["famille de la relecture : {0} (cellule médiane {1} ns), celle de l'écriture : {2}"] = 'read-back family: {0} (median cell {1} ns), write family: {2}'
$script:I18n["relecture antérieure à l'écriture du {0}"] = 'read-back earlier than the write of {0}'
$script:I18n["le contrôle de cette écriture a jugé l'asymétrie « éloignée de l'attendu »"] = 'the check of this write judged the asymmetry "far from the expected one"'
$script:I18n["tête {0} : facteur de la disquette non mesuré à l'écriture (k = 1 par défaut)"] = 'head {0}: disk factor not measured at the write (k = 1 by default)'
$script:I18n['tête {0} : {1} piste(s) retenue(s) (saines, sans erreur, hors zones corrigées), il en faut {2}'] = 'head {0}: {1} track(s) kept (healthy, error-free, outside corrected zones), {2} needed'
$script:I18n['tête {0} : {1} bloc(s) de 10 cylindres ayant au moins {2} pistes retenues, il en faut {3}'] = 'head {0}: {1} block(s) of 10 cylinders with at least {2} kept tracks, {3} needed'
$script:I18n['tête {0} : écart médian {1} ns, au-delà de ± {2} ns : trop grand pour venir de la courbe croisée, vérifiez le facteur de la disquette'] = 'head {0}: median gap {1} ns, beyond ± {2} ns: too large to come from the cross curve, check the disk factor'
$script:I18n['tête {0} : courbe croisée recalibrée ou calcul changé depuis cette écriture, le recalage ne vaudrait plus pour la courbe croisée actuelle'] = 'head {0}: cross curve recalibrated or calculation changed since this write, the adjustment would no longer apply to the current cross curve'
# Fenetre de confirmation et journal du recalage (172)
$script:I18n['trop de précompensation pour le lecteur cible'] = 'too much precompensation for the target drive'
$script:I18n['pas assez de précompensation pour le lecteur cible'] = 'not enough precompensation for the target drive'
$script:I18n['centrée pour le lecteur cible'] = 'centred for the target drive'
$script:I18n['aucun, le précédent est remis à zéro (courbe croisée recalibrée ou calcul changé)'] = 'none, the previous one is reset (cross curve recalibrated or calculation changed)'
$script:I18n['{0} ns sur {1} relecture(s)'] = '{0} ns over {1} read-back(s)'
$script:I18n['courbe écrite pour le lecteur {0} inchangée par rapport à cette écriture'] = 'curve written for drive {0} unchanged compared with this write'
$script:I18n['courbe écrite pour le lecteur {0} : {1} ns par rapport à cette écriture ({2} % à {3} % selon le cylindre)'] = 'curve written for drive {0}: {1} ns compared with this write ({2} % to {3} % depending on the cylinder)'
$script:I18n['courbe écrite pour le lecteur {0} : {1} ns par rapport à cette écriture'] = 'curve written for drive {0}: {1} ns compared with this write'
$script:I18n['Tête {0} : {1} pistes retenues, écart médian {2} ns ({3}) ; recalage {4} ns, au lieu de {5} ; {6}.'] = 'Head {0}: {1} tracks kept, median gap {2} ns ({3}); adjustment {4} ns, instead of {5}; {6}.'
$script:I18n["Recalage de la courbe croisée {0} → {1} : non proposé pendant une mesure continue. Faites une mesure simple de toute la disquette écrite le {2} (mêmes cylindres et mêmes têtes que l'écriture)."] = 'Cross curve adjustment {0} → {1}: not offered during a continuous measurement. Make a single measurement of the whole disk written on {2} (same cylinders and same heads as the write).'
$script:I18n['Recalage de la courbe croisée {0} → {1} sur cette relecture non proposé : {2}.'] = 'Cross curve adjustment {0} → {1} on this read-back not offered: {2}.'
$script:I18n['Recalage de la courbe croisée {0} → {1} : {2}.'] = 'Cross curve adjustment {0} → {1}: {2}.'
$script:I18n["Le lecteur {0} a relu la disquette écrite pour lui par le lecteur {1} le {2} (image « {3} », {4}, {5} pistes).`n`n{6}`n`nÉcart relu = (écart 3T + écart 4T) × cellule / g ({7}). Le recalage moyenne les {8} dernières écritures relues en se rapprochant de leur écart à mesure qu'elles s'ajoutent, au plus ± {9} ns ; arrondi au ns, il s'ajoute à la courbe écrite pour le lecteur {0} (au plus 25 % de sa valeur), sans modifier la courbe croisée. La fenêtre « Lecteurs » le montre et l'annule.`n`nUne autre disquette fausserait le recalage : confirmez que c'est bien celle-là."] = "Drive {0} read back the disk written for it by drive {1} on {2} (image `"{3}`", {4}, {5} tracks).`n`n{6}`n`nRead-back gap = (3T deviation + 4T deviation) × cell / g ({7}). The adjustment averages the last {8} writes read back, getting closer to their gap as they add up, at most ± {9} ns; rounded to the ns, it is added to the curve written for drive {0} (at most 25 % of its value), without changing the cross curve. The `"Drives`" window shows and cancels it.`n`nAnother disk would distort the adjustment: confirm that it is this one."
$script:I18n['Recalage de la courbe croisée'] = 'Cross curve adjustment'
$script:I18n['Recaler la courbe croisée {0} → {1} sur cette relecture ?'] = 'Adjust the cross curve {0} → {1} on this read-back?'
$script:I18n['Disquette écrite le {0} pour le lecteur {1}'] = 'Disk written on {0} for drive {1}'
$script:I18n['Recaler la courbe croisée'] = 'Adjust the cross curve'
$script:I18n['Recalage de la courbe croisée {0} → {1} non enregistré : non confirmé.'] = 'Cross curve adjustment {0} → {1} not saved: not confirmed.'
$script:I18n["Courbe croisée {0} → {1} recalée sur la relecture de l'écriture du {2} : {3} ; ajouté aux prochaines écritures pour le lecteur {1} (courbe croisée inchangée)."] = 'Cross curve {0} → {1} adjusted on the read-back of the write of {2}: {3}; added to the next writes for drive {1} (cross curve unchanged).'
# Fenetre « Lecteurs » (112, 172)
$script:I18n['Recalage de la courbe croisée {0} → {1} ({2}) : {3} ; {4} relecture(s), dernière le {5}.'] = 'Cross curve adjustment {0} → {1} ({2}): {3}; {4} read-back(s), last on {5}.'
$script:I18n['Sans effet : courbe croisée recalibrée ou calcul changé depuis.'] = 'No effect: cross curve recalibrated or calculation changed since.'
$script:I18n["{0}`n`nLes écritures suivantes pour le lecteur {1} reprennent la courbe écrite sans recalage ; la courbe croisée n'est pas modifiée, et les prochaines relectures par le lecteur {1} repartent de zéro.`n`nL'application copie d'abord la configuration dans « {2}.lecteurs-….bak », dans le même dossier."] = "{0}`n`nThe next writes for drive {1} go back to the written curve without adjustment; the cross curve is not changed, and the next read-backs by drive {1} start from zero.`n`nThe application first copies the configuration to `"{2}.lecteurs-….bak`", in the same folder."
$script:I18n['Annuler le recalage de la courbe croisée {0} → {1} ?'] = 'Cancel the adjustment of the cross curve {0} → {1}?'
$script:I18n['Annuler le recalage'] = 'Cancel the adjustment'
$script:I18n['Annuler le recalage…'] = 'Cancel the adjustment…'
$script:I18n['Recalage de la courbe croisée {0} → {1} ({2}) annulé : {3} tête(s).'] = 'Cross curve adjustment {0} → {1} ({2}) cancelled: {3} head(s).'
# Configuration et « Effacer les calibrations » (120, 240)
$script:I18n['Configuration : {0} recalage(s) de courbe croisée et {1} mémoire(s) d''écriture pour un lecteur cible illisibles, ignorés.'] = 'Configuration: {0} cross curve adjustment(s) and {1} target drive write memory(ies) unreadable, ignored.'
$script:I18n["Les recalages des courbes croisées ({0}) et la mémoire des dernières écritures pour un lecteur cible ({1}) sont effacés aussi."] = 'The cross curve adjustments ({0}) and the memory of the last writes for a target drive ({1}) are cleared too.'
$script:I18n["Recalages des courbes croisées ({0}) et mémoire des dernières écritures pour un lecteur cible ({1}) effacés avec les calibrations."] = 'Cross curve adjustments ({0}) and memory of the last writes for a target drive ({1}) cleared with the calibrations.'
# Memoire de l ecriture non posee (140)
$script:I18n['Écriture pour le lecteur cible {0} non gardée en mémoire : {1}'] = 'Write for target drive {0} not kept in memory: {1}'
