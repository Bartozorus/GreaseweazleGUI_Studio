# --- Textes de la 12.12 ----------------------------------------------------------------------------------------------
# Suite de la table $script:I18n (010-i18n) : cle francaise -> texte anglais, memes regles que 019-i18n-1211 (placeholders
# {n} identiques, aucune cle de T() sans entree, aucune cle d un autre module redefinie). Une section par lot de la 12.12.

# Recalage de la courbe croisee par regime d ecriture (172 : Get-TargetRecalPlan, Invoke-TargetRecalOffer,
# Get-TargetRecalSummaryText ; 120 : Load-Config)
$script:I18n['tête {0} : recalage appris pour un facteur de la disquette de 1 ou moins, celui de cette écriture est au-dessus de 1'] = 'head {0}: adjustment learned for a disk factor of 1 or less, the factor of this write is above 1'
$script:I18n['tête {0} : recalage appris pour un facteur de la disquette au-dessus de 1, celui de cette écriture est de 1 ou moins'] = 'head {0}: adjustment learned for a disk factor above 1, the factor of this write is 1 or less'
$script:I18n['{0} ns (facteur au-dessus de 1)'] = '{0} ns (factor above 1)'
$script:I18n['tête {0} {1} ns (facteur au-dessus de 1)'] = 'head {0} {1} ns (factor above 1)'
$script:I18n['(facteur au-dessus de 1)'] = '(factor above 1)'
$script:I18n['Tête {0} : facteur de la disquette au-dessus de 1 ; ce recalage ne vaut que pour les écritures dont le facteur dépasse 1, tenu à part de celui des autres.'] = 'Head {0}: disk factor above 1; this adjustment only applies to writes whose factor is above 1, and is kept apart from the adjustment of the others.'
$script:I18n['Recalage des courbes croisées : {0} écriture(s) relue(s) dont le facteur de la disquette dépassait 1 reclassée(s) ; leur recalage est désormais tenu à part.'] = 'Cross curve adjustments: {0} read-back write(s) whose disk factor was above 1 reclassified; their adjustment is now kept apart.'

# Journal exporte apres une troncature : lignes de l application retirees de l affichage (110 : Export-LogFile)
$script:I18n["[Lignes de l'application retirées du journal affiché, sans les commandes ni la sortie de gw : {0} ligne(s).]"] = '[Application lines removed from the displayed log, without gw commands and output: {0} line(s).]'
$script:I18n['[Fin des lignes retirées. Suite : journal affiché.]'] = '[End of the removed lines. Next: displayed log.]'

# Vitesse : durees au journal quand « Chrono » est cochee (110 : Add-UiTiming ; 120, 220, 600)
$script:I18n['Durée : {0}, {1} s{2}'] = 'Duration: {0}, {1} s{2}'
$script:I18n['enregistrement de la configuration'] = 'saving the configuration'
$script:I18n["profil de l'image et ligne « Ce qui va se passer »"] = 'image profile and "What will happen" line'
$script:I18n['fenêtre sans réponse'] = 'window not responding'
# Correction par zones (lecteur cible) decochee par defaut : infobulle (520), migration (120), zones citees (170)
$script:I18n["Décochée par défaut depuis la 12.12 : les relectures par un lecteur cible n'ont pas confirmé ces écarts. Décochée, le contrôle cite les zones au journal sans les corriger."] = 'Unchecked by default since 12.12: read-backs by a target drive did not confirm these gaps. When unchecked, the check lists the zones in the log without correcting them.'
$script:I18n["Case « Corriger les zones écartées de l'attendu (lecteur cible) » décochée, une seule fois : elle n'est plus cochée par défaut dans cette version. Les relectures par un lecteur cible n'ont pas confirmé les écarts vus par le lecteur qui écrit, et la correction éloignait la disquette de ce que lit le lecteur cible. La case reste dans les options avancées de l'onglet « Écriture »."] = '"Correct zones away from the expected value (target drive)" box unchecked, once only: it is no longer checked by default in this version. Read-backs by a target drive did not confirm the gaps seen by the writing drive, and the correction moved the disk away from what the target drive reads. The box remains in the advanced options of the "Write" tab.'
$script:I18n['{0} : écart médian {1} ns'] = '{0}: median gap {1} ns'
$script:I18n["Contrôle après écriture : {0} zone(s) écartée(s) de l'attendu à la relecture par le lecteur {1} ({2}), non corrigée(s) : seule une relecture par le lecteur {3} dit ce qu'il lira."] = 'Post-write check: {0} zone(s) away from the expected value when read back by drive {1} ({2}), not corrected: only a read-back by drive {3} tells what it will read.'
# Verification du contenu par l application, etape 1 (170)
$script:I18n['gw convert non lancé ({0})'] = 'gw convert not started ({0})'
$script:I18n['gw convert non lancé'] = 'gw convert not started'
$script:I18n['gw convert non terminé après {0} s'] = 'gw convert not finished after {0} s'
$script:I18n['gw convert a rendu le code {0}'] = 'gw convert returned code {0}'
$script:I18n['fichier de référence absent'] = 'reference file missing'
$script:I18n['fichier de référence illisible'] = 'reference file unreadable'
$script:I18n['vérification du contenu'] = 'content verification'
$script:I18n[' ; {0} piste(s) non comparée(s)'] = '; {0} track(s) not compared'
$script:I18n["Vérification du contenu (à l'essai) : non faite, {0}. La vérification de gw et le contrôle n'en dépendent pas."] = 'Content verification (on trial): not done, {0}. The gw verification and the check do not depend on it.'
$script:I18n["Vérification du contenu (à l'essai) : {0} piste(s) comparée(s) au flux que gw tire de l'image, aucune différence{1}."] = 'Content verification (on trial): {0} track(s) compared with the flux gw derives from the image, no difference{1}.'
$script:I18n["Vérification du contenu (à l'essai) : {0} piste(s) comparée(s) au flux que gw tire de l'image, {1} différente(s) : {2}{3}. Ce constat ne change ni l'état des pistes ni les réécritures."] = 'Content verification (on trial): {0} track(s) compared with the flux gw derives from the image, {1} different: {2}{3}. This finding changes neither the state of the tracks nor the rewrites.'
