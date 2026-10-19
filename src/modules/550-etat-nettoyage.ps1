
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
