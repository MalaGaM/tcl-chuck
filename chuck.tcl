 ###############################################
#                                               #
#             C h u c k   F a c t s             #
# v1.1 (02/08/2013) ©2013 Galdinx et MenzAgitat #
#                                               #
#        IRC:  irc.epiknet.org  #boulets        #
#                                               #
#         Les scripts de MenzAgitat sont        #
#  téléchargeables sur http://www.eggdrop.fr    #
#                                               #
 ###############################################

#
# Description
# Script permettant d'afficher un fact au hasard pris sur le site 
# "http://chucknorrisfacts.fr/ grâce a une commande publique, "!chuck" par exemple.
# Le script stock par ailleurs chacune des citations dans un fichier externe
# Si le site est momentanément indisponible, le script pioche alors un fact aux hasard 
# dans ceux déja collectés.
#

#
# Changelog
#
# 1.0 - 1ère version
# 1.1 - Adaptation du script suite à modification du payload du site support + corrections/optimisations/ajustements de code
#

#
# LICENCE:
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#

if { [lindex [split $version] 1] < 1061800 } { putloglev o * "\00304\002\[Chuck Facts - ERREUR\]\002\003 La version de votre eggdrop est \00304\002[lindex [split $version] 0]\002\003; chuck.tcl ne fonctionnera correctement que sur les eggdrops version 1.6.18 ou supérieure." ; return }
if { $tcl_version < 8.4 } { putloglev o * "\00304\002\[Chuck Facts - ERREUR\]\002\003 chuck.tcl nécessite que Tcl 8.4 (ou plus) soit installé pour fonctionner. Votre version actuelle de Tcl est \00304\002$tcl_version\002\003." ; return }
package require Tcl 8.4
if {[info commands chuck::uninstall] eq "::chuck::uninstall"} { chuck::uninstall }
namespace eval chuck {



	######################
	#	    PARAMETRES     #
	######################

	# Chans sur lesquels le script sera actif (séparés par un espace)
	# Remarque : attention aux majuscules, le nom du chan est sensible à la casse
	variable allowed_chans "#chan1 #chan2"

	
	#### COMMANDES PUBLIQUES ET AUTORISATIONS
   
 	# Commande utilisée pour afficher une citation
 	# ex. : "!chuck"
 	variable chuckcmd "!chuck"
 	# autorisations pour la commande !chuck
 	variable chuckauth "-|-"
  	

 	#### CHEMINS D'ACCES
   
 	# Chemin relatif ou absolu vers le fichier hébergeant la base de données
 	# des citations receuillies ; ce fichier doit exister.
	variable chuckpath "scripts/BDDs/chuck.db"


 	#### HEURE DU TRI DE LA BASE DE DONNES
   
	# (format 24h, mettez un 0 devant les valeurs inférieures à 10)
	# exemples : "05h15" = 5h15    "00h00" = minuit     "17h05" = 17h05
	variable freqtribase "05h05"

	
	#### PARAMETRES DE L'ANTI-FLOOD
  	
 	# Anti-flood (0 = désactivé, 1 = activé)
 	variable antiflood 1
 	# Combien de commandes sont autorisées en combien de temps ?
 	# exemple : "4:45" = 4 commandes maximum en 45 secondes;
 	# les suivantes seront ignorées.
 	variable cmdflood_chuck "4:45"
 	# Intervalle de temps minimum entre l'affichage de 2 messages
 	# avertissant que l'anti-flood a été déclenché (ne réglez pas
 	# cette valeur trop bas afin de ne pas être floodé par les messages
 	# d'avertissement de l'anti-flood...)
 	variable antiflood_msg_interval 20






####################################################################
#                                                                  #
# NE MODIFIEZ RIEN APRES CE CADRE SI VOUS NE CONNAISSEZ PAS LE TCL #
#                                                                  #
#   DO NOT MODIFY ANYTHING BELOW THIS BOX IF YOU DON'T KNOW TCL    #
#                                                                  #
####################################################################

	variable scriptname "Chuck Facts"
	variable version "1.1.20130802"
	
	variable time [split $freqtribase "h"] 
	# inutilisé, conservé au cas où
	variable cmdflood_global "5:120"
		
	variable floodsettingsstring [split "global $cmdflood_global chuck $cmdflood_chuck"]
	variable floodsettings ; array set floodsettings $floodsettingsstring
	variable instance ; array set instance {}
	variable antiflood_msg ; array set antiflood_msg {}
	bind evnt - prerehash [namespace current]::uninstall
	bind pub $chuckauth $chuckcmd [namespace current]::pub_disp_chuck
	bind time - "[lindex $time 1] [lindex $time 0] * * *" [namespace current]::tribase
	proc uninstall {args} {
		putlog "Désallocation des ressources de \002$chuck::scriptname...\002"
 		unbind evnt - prerehash [namespace current]::uninstall
 		catch { unbind pub $chuck::chuckauth $chuck::chuckcmd [namespace current]::pub_disp_chuck }
		catch { unbind time - "[lindex $chuck::time 1] [lindex $chuck::time 0] * * *" [namespace current]::tribase }
    namespace delete ::chuck
	}

}


proc chuck::pub_disp_chuck {nick host handle chan args} {
	if {[lsearch -exact [split $chuck::allowed_chans] $chan] != -1} {
		if {($chuck::antiflood == 1) && ([chuck::antiflood $chan "chuck"] == "flood")} { return }
		
		set useragent "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.1) Gecko/20061204 Firefox/2.0.0.1"
		set url "http://chucknorrisfacts.fr/facts/alea"
		
		::http::config -useragent $useragent
		catch { set token [::http::geturl "$url" -timeout 6000] }
		
		if {([info exists token]) && ([::http::status $token] == "ok")} {
			set retok [::http::data $token]
			set res ""
			regexp {class="factbody"(.+?)<div class="vote">} $retok res
			regsub -all {class="factbody">} $res "" res
			regsub -all {<div class="vote">} $res "" res
			regsub -all {\n} $res "" res
			regsub -all {^ +} $res "" res
			set result [chuck::string_filter $res]
			if { $result == "" } {
				chuck::pub_disp_secours 2 $chan
			} else { 
				puthelp "privmsg $chan :$result"
				chuck::log_fact $result 
			}
		} else {
			chuck::pub_disp_secours 1 $chan
		}
		::http::cleanup $token
	}
}


##### Conversion des caractères html spéciaux et filtrage des balises HTML
proc chuck::string_filter { str } {
	set str [string map -nocase {
		"&agrave;"			"à"		"&agrave;"			"à"		"&aacute;"			"á"		"&acirc;"			"â"
		"&atilde;"			"ã"		"&auml;"			"ä"		"&aring;"			"å"		"&aelig;"			"æ"
		"&ccedil;"			"ç"		"&egrave;"			"è"		"&eacute;"			"é"		"&ecirc;"			"ê"
		"&euml;"			"ë"		"&igrave;"			"ì"		"&iacute;"			"í"		"&icirc;"			"î"
		"&iuml;"			"ï"		"&eth;"				"ð"		"&ntilde;"			"ñ"		"&ograve;"			"ò"
		"&oacute;"			"ó"		"&ocirc;"			"ô"		"&otilde;"			"õ"		"&ouml;"			"ö"
		"&divide;"			"÷"		"&oslash;"			"ø"		"&ugrave;"			"ù"		"&uacute;"			"ú"
		"&ucirc;"			"û"		"&uuml;"			"ü"		"&yacute;"			"ý"		"&thorn;"			"þ"
		"&yuml;"			"ÿ"		"&quot;"			"\""	"&amp;"				"&"		"&euro;"			"€"
		"&oelig;"			"œ"		"&Yuml;"			"Ÿ"		"&nbsp;"			" "		"&iexcl;"			"¡"
		"&cent;"			"¢"		"&pound;"			"£"		"&curren;"			"¤"		"&yen;"				"¥"
		"&brvbar;"			"¦"		"&brkbar;"			"¦"		"&sect;"			"§"		"&uml;"				"¨"
		"&die;"				"¨"		"&copy;"			"©"		"&ordf;"			"ª"		"&laquo;"			"«"
		"&not;"				"¬"		"&shy;"				"­-"	"&reg;"				"®"		"&macr;"			"¯"
		"&hibar;"			"¯"		"&deg;"				"°"		"&plusmn;"			"±"		"&sup2;"			"²"
		"&sup3;"			"³"		"&acute;"			"´"		"&micro;"			"µ"		"&para;"			"¶"
		"&middot;"			"·"		"&cedil;"			"¸"		"&sup1;"			"¹"		"&ordm;"			"º"
		"&raquo;"			"»"		"&frac14;"			"¼"		"&frac12;"			"½"		"&frac34;"			"¾"
		"&iquest;"			"¿"		"&Agrave;"			"À"		"&Aacute;"			"Á"		"&Acirc;"			"Â"
		"&Atilde;"			"Ã"		"&Auml;"			"Ä"		"&Aring;"			"Å"		"&AElig;"			"Æ"
		"&Ccedil;"			"Ç"		"&Egrave;"			"È"		"&Eacute;"			"É"		"&Ecirc;"			"Ê"
		"&Euml;"			"Ë"		"&Igrave;"			"Ì"		"&Iacute;"			"Í"		"&Icirc;"			"Î"
		"&Iuml;"			"Ï"		"&ETH;"				"Ð"		"&Dstrok;"			"Ð"		"&Ntilde;"			"Ñ"
		"&Ograve;"			"Ò"		"&Oacute;"			"Ó"		"&Ocirc;"			"Ô"		"&Otilde;"			"Õ"
		"&Ouml;"			"Ö"		"&times;"			"×"		"&Oslash;"			"Ø"		"&Ugrave;"			"Ù"
		"&Uacute;"			"Ú"		"&Ucirc;"			"Û"		"&Uuml;"			"Ü"		"&Yacute;"			"Ý"
		"&THORN;"			"Þ"		"&szlig;"			"ß"		"\r"				""		"\t"				""
		"&#039;"			"\'"	"&#39;"				"\'"	"&gt;"				">"		"&lt;"				"<"
		"&#34;"				"\'"	"&#38;"				"&"		"#91;"				"\("	"&#92;"				"\/"
		"&#93;"				")"		"&#123;"			"("		"&#125;"			")"		"&#163;"			"£"
		"&#168;"			"¨"		"&#169;"			"©"		"&#171;"			"«"		"&#173;"			"­"
		"&#174;"			"®"		"&#180;"			"´"		"&#183;"			"·"		"&#185;"			"¹"
		"&#187;"			"»"		"&#188;"			"¼"		"&#189;"			"½"		"&#190;"			"¾"
		"&#192;"			"À"		"&#193;"			"Á"		"&#194;"			"Â"		"&#195;"			"Ã"
		"&#196;"			"Ä"		"&#197;"			"Å"		"&#198;"			"Æ"		"&#199;"			"Ç"
		"&#200;"			"È"		"&#201;"			"É"		"&#202;"			"Ê"		"&#203;"			"Ë"
		"&#204;"			"Ì"		"&#205;"			"Í"		"&#206;"			"Î"		"&#207;"			"Ï"
		"&#208;"			"Ð"		"&#209;"			"Ñ"		"&#210;"			"Ò"		"&#211;"			"Ó"
		"&#212;"			"Ô"		"&#213;"			"Õ"		"&#214;"			"Ö"		"&#215;"			"×"
		"&#216;"			"Ø"		"&#217;"			"Ù"		"&#218;"			"Ú"		"&#219;"			"Û"
		"&#220;"			"Ü"		"&#221;"			"Ý"		"&#222;"			"Þ"		"&#223;"			"ß"
		"&#224;"			"à"		"&#225;"			"á"		"&#226;"			"â"		"&#227;"			"ã"
		"&#228;"			"ä"		"&#229;"			"å"		"&#230;"			"æ"		"&#231;"			"ç"
		"&#232;"			"è"		"&#233;"			"é"		"&#234;"			"ê"		"&#235;"			"ë"
		"&#236;"			"ì"		"&#237;"			"í"		"&#238;"			"î"		"&#239;"			"ï"
		"&#240;"			"ð"		"&#241;"			"ñ"		"&#242;"			"ò"		"&#243;"			"ó"
		"&#244;"			"ô"		"&#245;"			"õ"		"&#246;"			"ö"		"&#247;"			"÷"
		"&#248;"			"ø"		"&#249;"			"ù"		"&#250;"			"ú"		"&#251;"			"û"
		"&#252;"			"ü"		"&#253;"			"ý"		"&#254;"			"þ"		
		
	} $str]
	regsub -all "<br />" $str " " str
	return "${str}"
}

proc chuck::log_fact { str } {
	set db [open $chuck::chuckpath a]
	puts $db $str
	close $db
}

proc chuck::tribase {min hour day month year} {
	set filechuck [open $chuck::chuckpath r]
	set db [split [read -nonewline $filechuck] "\n"]
	close $filechuck
	
	set filechuck [open $chuck::chuckpath w]
	set db [join [lsort -unique $db] "\n"]
	puts $filechuck $db
	close $filechuck
	putlog "\[Chuck Facts - Info\] Base de données triée"	
}


proc chuck::pub_disp_secours { type chan } {
	if { $type == 1 } { 
		putlog "\00304\002\[Chuck Facts - ERREUR\]\002\003 Le site est injoignable..."
	} else {
		putlog "\00304\002\[Chuck Facts - ERREUR\]\002\003 Le site retourne une information non traitable."
	}
	
	if { [file exists $chuck::chuckpath] } {
		set filechuck [open $chuck::chuckpath r]
		set db [split [read -nonewline $filechuck] "\n"]
		close $filechuck
		if { [llength $db] == 0 } {
				putlog "\00304\002\[Chuck Facts - ERREUR\]\002\003 La base de données est vide..."
				puthelp "privmsg $chan :\00304\002\[Chuck Facts - Erreur\]\002\003 : Le script a rencontré un problème, veuillez en informer un administrateur.\00304\003"		
		
		} else { 
			set result [lindex $db [expr [clock clicks -milliseconds] % [llength $db]]]
			if { $result != "" } {
				putlog "\[Chuck Facts - Info\] Une citation a été aléatoirement choisie dans la base de données locale et va être affichée..."
				puthelp "privmsg $chan :$result"
			} else {
				putlog "\00304\002\[Chuck Facts - ERREUR\]\002\003 La base de données est corrompue..."
				puthelp "privmsg $chan :\00304\002\[Chuck Facts - Erreur\]\002\003 : Le script a rencontré un problème, veuillez en informer un administrateur.\00304\003"		
			}
		}
		
	} else {
		putlog "\00304\002\[Chuck Facts - ERREUR\]\002\003 La base de données est inexistante..."
		puthelp "privmsg $chan :\00304\002\[Chuck Facts - Erreur\]\002\003 : Le script a rencontré un problème, veuillez en informer un administrateur.\00304\003"
	}
}


proc chuck::antiflood {chan type} {
  variable antiflood_msg
  if {![info exists antiflood_msg($chan$type)]} { set antiflood_msg($chan$type) 0 }
  variable instance
  if {![info exists instance($chan$type)]} { set instance($chan$type) 0 }
  set max_instances [lindex [split $chuck::floodsettings($type) ":"] 0]
  set instance_length [lindex [split $chuck::floodsettings($type) ":"] 1]
  if { $instance($chan$type) >= $max_instances } {
    if { $antiflood_msg($chan$type) == 0 } {
      set antiflood_msg($chan$type) 1
      if {$type != "global"} {
        putquick "privmsg $chan :\0037:::\00314 Contrôle de flood activé pour la commande \002!$type\002 : pas plus de $max_instances requête(s) toutes les $instance_length secondes.\003"
      } else {
        putquick "privmsg $chan :\0037:::\00314 Contrôle de flood sur les commandes de \002Vie De Merde\002 : pas plus de $max_instances commandes toutes les $instance_length secondes.\003"
      }
      utimer $chuck::antiflood_msg_interval "chuck::antiflood_msg_reset $chan $type"
    }
    return "flood"
  } else {
    incr instance($chan$type)
    utimer $instance_length "chuck::antiflood_close_instance $chan $type"
    return "no flood"
  }
}

proc chuck::antiflood_close_instance {chan type} {
  variable instance
  if { $instance($chan$type) > 0 } { incr instance($chan$type) -1 }
}

proc chuck::antiflood_msg_reset {chan type} {
  variable antiflood_msg
  set antiflood_msg($chan$type) 0
}

putlog "\002*$chuck::scriptname v$chuck::version*\002 (©2013 Galdinx et MenzAgitat) a été chargé."
