 ###############################################
#                                               #
#             C h u c k   F a c t s             #
# v1.1 (02/08/2013) �2013 Galdinx et MenzAgitat #
#                                               #
#        IRC:  irc.epiknet.org  #boulets        #
#                                               #
#         Les scripts de MenzAgitat sont        #
#  t�l�chargeables sur http://www.eggdrop.fr    #
#                                               #
 ###############################################

#
# Description
# Script permettant d'afficher un fact au hasard pris sur le site 
# "http://chucknorrisfacts.fr/ gr�ce a une commande publique, "!chuck" par exemple.
# Le script stock par ailleurs chacune des citations dans un fichier externe
# Si le site est momentan�ment indisponible, le script pioche alors un fact aux hasard 
# dans ceux d�ja collect�s.
#

#
# Changelog
#
# 1.0 - 1�re version
# 1.1 - Adaptation du script suite � modification du payload du site support + corrections/optimisations/ajustements de code
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

if { [lindex [split $version] 1] < 1061800 } { putloglev o * "\00304\002\[Chuck Facts - ERREUR\]\002\003 La version de votre eggdrop est \00304\002[lindex [split $version] 0]\002\003; chuck.tcl ne fonctionnera correctement que sur les eggdrops version 1.6.18 ou sup�rieure." ; return }
if { $tcl_version < 8.4 } { putloglev o * "\00304\002\[Chuck Facts - ERREUR\]\002\003 chuck.tcl n�cessite que Tcl 8.4 (ou plus) soit install� pour fonctionner. Votre version actuelle de Tcl est \00304\002$tcl_version\002\003." ; return }
package require Tcl 8.4
if {[info commands chuck::uninstall] eq "::chuck::uninstall"} { chuck::uninstall }
namespace eval chuck {



	######################
	#	    PARAMETRES     #
	######################

	# Chans sur lesquels le script sera actif (s�par�s par un espace)
	# Remarque : attention aux majuscules, le nom du chan est sensible � la casse
	variable allowed_chans "#chan1 #chan2"

	
	#### COMMANDES PUBLIQUES ET AUTORISATIONS
   
 	# Commande utilis�e pour afficher une citation
 	# ex. : "!chuck"
 	variable chuckcmd "!chuck"
 	# autorisations pour la commande !chuck
 	variable chuckauth "-|-"
  	

 	#### CHEMINS D'ACCES
   
 	# Chemin relatif ou absolu vers le fichier h�bergeant la base de donn�es
 	# des citations receuillies ; ce fichier doit exister.
	variable chuckpath "scripts/BDDs/chuck.db"


 	#### HEURE DU TRI DE LA BASE DE DONNES
   
	# (format 24h, mettez un 0 devant les valeurs inf�rieures � 10)
	# exemples : "05h15" = 5h15    "00h00" = minuit     "17h05" = 17h05
	variable freqtribase "05h05"

	
	#### PARAMETRES DE L'ANTI-FLOOD
  	
 	# Anti-flood (0 = d�sactiv�, 1 = activ�)
 	variable antiflood 1
 	# Combien de commandes sont autoris�es en combien de temps ?
 	# exemple : "4:45" = 4 commandes maximum en 45 secondes;
 	# les suivantes seront ignor�es.
 	variable cmdflood_chuck "4:45"
 	# Intervalle de temps minimum entre l'affichage de 2 messages
 	# avertissant que l'anti-flood a �t� d�clench� (ne r�glez pas
 	# cette valeur trop bas afin de ne pas �tre flood� par les messages
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
	# inutilis�, conserv� au cas o�
	variable cmdflood_global "5:120"
		
	variable floodsettingsstring [split "global $cmdflood_global chuck $cmdflood_chuck"]
	variable floodsettings ; array set floodsettings $floodsettingsstring
	variable instance ; array set instance {}
	variable antiflood_msg ; array set antiflood_msg {}
	bind evnt - prerehash [namespace current]::uninstall
	bind pub $chuckauth $chuckcmd [namespace current]::pub_disp_chuck
	bind time - "[lindex $time 1] [lindex $time 0] * * *" [namespace current]::tribase
	proc uninstall {args} {
		putlog "D�sallocation des ressources de \002$chuck::scriptname...\002"
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


##### Conversion des caract�res html sp�ciaux et filtrage des balises HTML
proc chuck::string_filter { str } {
	set str [string map -nocase {
		"&agrave;"			"�"		"&agrave;"			"�"		"&aacute;"			"�"		"&acirc;"			"�"
		"&atilde;"			"�"		"&auml;"			"�"		"&aring;"			"�"		"&aelig;"			"�"
		"&ccedil;"			"�"		"&egrave;"			"�"		"&eacute;"			"�"		"&ecirc;"			"�"
		"&euml;"			"�"		"&igrave;"			"�"		"&iacute;"			"�"		"&icirc;"			"�"
		"&iuml;"			"�"		"&eth;"				"�"		"&ntilde;"			"�"		"&ograve;"			"�"
		"&oacute;"			"�"		"&ocirc;"			"�"		"&otilde;"			"�"		"&ouml;"			"�"
		"&divide;"			"�"		"&oslash;"			"�"		"&ugrave;"			"�"		"&uacute;"			"�"
		"&ucirc;"			"�"		"&uuml;"			"�"		"&yacute;"			"�"		"&thorn;"			"�"
		"&yuml;"			"�"		"&quot;"			"\""	"&amp;"				"&"		"&euro;"			"�"
		"&oelig;"			"�"		"&Yuml;"			"�"		"&nbsp;"			" "		"&iexcl;"			"�"
		"&cent;"			"�"		"&pound;"			"�"		"&curren;"			"�"		"&yen;"				"�"
		"&brvbar;"			"�"		"&brkbar;"			"�"		"&sect;"			"�"		"&uml;"				"�"
		"&die;"				"�"		"&copy;"			"�"		"&ordf;"			"�"		"&laquo;"			"�"
		"&not;"				"�"		"&shy;"				"�-"	"&reg;"				"�"		"&macr;"			"�"
		"&hibar;"			"�"		"&deg;"				"�"		"&plusmn;"			"�"		"&sup2;"			"�"
		"&sup3;"			"�"		"&acute;"			"�"		"&micro;"			"�"		"&para;"			"�"
		"&middot;"			"�"		"&cedil;"			"�"		"&sup1;"			"�"		"&ordm;"			"�"
		"&raquo;"			"�"		"&frac14;"			"�"		"&frac12;"			"�"		"&frac34;"			"�"
		"&iquest;"			"�"		"&Agrave;"			"�"		"&Aacute;"			"�"		"&Acirc;"			"�"
		"&Atilde;"			"�"		"&Auml;"			"�"		"&Aring;"			"�"		"&AElig;"			"�"
		"&Ccedil;"			"�"		"&Egrave;"			"�"		"&Eacute;"			"�"		"&Ecirc;"			"�"
		"&Euml;"			"�"		"&Igrave;"			"�"		"&Iacute;"			"�"		"&Icirc;"			"�"
		"&Iuml;"			"�"		"&ETH;"				"�"		"&Dstrok;"			"�"		"&Ntilde;"			"�"
		"&Ograve;"			"�"		"&Oacute;"			"�"		"&Ocirc;"			"�"		"&Otilde;"			"�"
		"&Ouml;"			"�"		"&times;"			"�"		"&Oslash;"			"�"		"&Ugrave;"			"�"
		"&Uacute;"			"�"		"&Ucirc;"			"�"		"&Uuml;"			"�"		"&Yacute;"			"�"
		"&THORN;"			"�"		"&szlig;"			"�"		"\r"				""		"\t"				""
		"&#039;"			"\'"	"&#39;"				"\'"	"&gt;"				">"		"&lt;"				"<"
		"&#34;"				"\'"	"&#38;"				"&"		"#91;"				"\("	"&#92;"				"\/"
		"&#93;"				")"		"&#123;"			"("		"&#125;"			")"		"&#163;"			"�"
		"&#168;"			"�"		"&#169;"			"�"		"&#171;"			"�"		"&#173;"			"�"
		"&#174;"			"�"		"&#180;"			"�"		"&#183;"			"�"		"&#185;"			"�"
		"&#187;"			"�"		"&#188;"			"�"		"&#189;"			"�"		"&#190;"			"�"
		"&#192;"			"�"		"&#193;"			"�"		"&#194;"			"�"		"&#195;"			"�"
		"&#196;"			"�"		"&#197;"			"�"		"&#198;"			"�"		"&#199;"			"�"
		"&#200;"			"�"		"&#201;"			"�"		"&#202;"			"�"		"&#203;"			"�"
		"&#204;"			"�"		"&#205;"			"�"		"&#206;"			"�"		"&#207;"			"�"
		"&#208;"			"�"		"&#209;"			"�"		"&#210;"			"�"		"&#211;"			"�"
		"&#212;"			"�"		"&#213;"			"�"		"&#214;"			"�"		"&#215;"			"�"
		"&#216;"			"�"		"&#217;"			"�"		"&#218;"			"�"		"&#219;"			"�"
		"&#220;"			"�"		"&#221;"			"�"		"&#222;"			"�"		"&#223;"			"�"
		"&#224;"			"�"		"&#225;"			"�"		"&#226;"			"�"		"&#227;"			"�"
		"&#228;"			"�"		"&#229;"			"�"		"&#230;"			"�"		"&#231;"			"�"
		"&#232;"			"�"		"&#233;"			"�"		"&#234;"			"�"		"&#235;"			"�"
		"&#236;"			"�"		"&#237;"			"�"		"&#238;"			"�"		"&#239;"			"�"
		"&#240;"			"�"		"&#241;"			"�"		"&#242;"			"�"		"&#243;"			"�"
		"&#244;"			"�"		"&#245;"			"�"		"&#246;"			"�"		"&#247;"			"�"
		"&#248;"			"�"		"&#249;"			"�"		"&#250;"			"�"		"&#251;"			"�"
		"&#252;"			"�"		"&#253;"			"�"		"&#254;"			"�"		
		
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
	putlog "\[Chuck Facts - Info\] Base de donn�es tri�e"	
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
				putlog "\00304\002\[Chuck Facts - ERREUR\]\002\003 La base de donn�es est vide..."
				puthelp "privmsg $chan :\00304\002\[Chuck Facts - Erreur\]\002\003 : Le script a rencontr� un probl�me, veuillez en informer un administrateur.\00304\003"		
		
		} else { 
			set result [lindex $db [expr [clock clicks -milliseconds] % [llength $db]]]
			if { $result != "" } {
				putlog "\[Chuck Facts - Info\] Une citation a �t� al�atoirement choisie dans la base de donn�es locale et va �tre affich�e..."
				puthelp "privmsg $chan :$result"
			} else {
				putlog "\00304\002\[Chuck Facts - ERREUR\]\002\003 La base de donn�es est corrompue..."
				puthelp "privmsg $chan :\00304\002\[Chuck Facts - Erreur\]\002\003 : Le script a rencontr� un probl�me, veuillez en informer un administrateur.\00304\003"		
			}
		}
		
	} else {
		putlog "\00304\002\[Chuck Facts - ERREUR\]\002\003 La base de donn�es est inexistante..."
		puthelp "privmsg $chan :\00304\002\[Chuck Facts - Erreur\]\002\003 : Le script a rencontr� un probl�me, veuillez en informer un administrateur.\00304\003"
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
        putquick "privmsg $chan :\0037:::\00314 Contr�le de flood activ� pour la commande \002!$type\002 : pas plus de $max_instances requ�te(s) toutes les $instance_length secondes.\003"
      } else {
        putquick "privmsg $chan :\0037:::\00314 Contr�le de flood sur les commandes de \002Vie De Merde\002 : pas plus de $max_instances commandes toutes les $instance_length secondes.\003"
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

putlog "\002*$chuck::scriptname v$chuck::version*\002 (�2013 Galdinx et MenzAgitat) a �t� charg�."
