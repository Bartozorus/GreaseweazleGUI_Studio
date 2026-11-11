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

# --- L6 : calibration croisee : journal exporte, echanges de disquette, lecteur cible preselectionne (110, 240, 250, 270, 540)

# --- L7 : revenir a une calibration precedente (120, 240, 250, 520) ----------------------------------------------------

# --- L8 : progression par piste, barre d etat en fin d operation (110, 170, 200, 270, 276, 300, 600) -------------------

# --- L9 : onglet Ecriture en trois etapes, options avancees, barre d onglets (145, 510, 520, 600) ----------------------

# --- L10 : ligne « Ce qui va se passer » de l onglet Ecriture (140, 145, 260, 520) -------------------------------------

# --- L11 : barre de l onglet Ecriture pendant l ecriture et son controle (140, 160, 170, 600) --------------------------
