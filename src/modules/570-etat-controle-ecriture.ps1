
# ============================== CONTROLE APRES ECRITURE ========================
# Apres une ecriture reussie : relecture en flux (3 tours) de toutes les pistes ecrites,
# classement de chaque piste avec Get-TrackMetrics (memes criteres que l onglet Qualite :
# erreurs hors classe, trous, stabilite entre tours, jitter). Une piste A SURVEILLER,
# CRITIQUE, illisible ou absente de la relecture est faible : elle est reecrite seule
# (12.8.2 : apres un effacement haute frequence de la piste en double densite, pre-effacement force en haute
# densite), puis seule remesuree. Au plus N passes (« Passes de reecriture »,
# 3 par defaut ; 0 = controle seul). Les pistes vides de l image (IPF : enregistrement
# sans bloc) ne sont pas controlees. Garde-fou : si plus de la moitie des pistes sont
# faibles au premier controle (format non MFM, disquette inadaptee, lecteur en defaut),
# aucune reecriture automatique n est lancee.
# Les commandes gw d une etape sont dans une file ($script:Rep.Pending) et la chaine
# n enfile que des appels generiques : pas de closure (cf. Start-Compare).
$script:Rep = $null

