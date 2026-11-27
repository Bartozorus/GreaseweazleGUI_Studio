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
