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

# --- L8 : progression par piste, barre d etat en fin d operation (110, 170, 200, 270, 276, 300, 600) -------------------
# Phase du libelle de la barre de calibration (Update-CalibProgress, 270) pendant un gw erase : « (passe 3/5, 0/30/100 ns,
# effacement) », a cote de « ecriture » et « relecture » (010)
$script:I18n['effacement'] = 'erasing'
# Barre d etat a la fin d une restauration (Close-Restore, 300, par Set-SeqEnd, 110) ; l heure suit le texte. Les autres
# fins (calibration, controle apres ecriture, recherche des lecteurs) reprennent des textes existants
$script:I18n['Restauration réussie'] = 'Restore succeeded'
$script:I18n['Restauration réussie avec réserve'] = 'Restore succeeded with a reservation'
$script:I18n['Restauration échouée'] = 'Restore failed'

# --- L9 : onglet Ecriture en trois etapes, options avancees, barre d onglets (145, 510, 520, 600) ----------------------

# --- L10 : ligne « Ce qui va se passer » de l onglet Ecriture (140, 145, 260, 520) -------------------------------------

# --- L11 : barre de l onglet Ecriture pendant l ecriture et son controle (140, 160, 170, 600) --------------------------
