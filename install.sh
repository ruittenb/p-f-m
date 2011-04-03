#!/usr/bin/env sh
############################################################################
#
# Name:         installpfm.sh
# Version:      0.08
# Authors:      Rene Uittenbogaard
# Date:         2009-09-30
# Usage:        installpfm.sh
# Description:  This is not a script, this is a manual.
#		This is meant as an example how pfm dependencies can
#		be downloaded and installed. Your Mileage May Vary.
#		Comments and improvements are welcome!
#

VERSION=1.94.0

###############################################################################
# helper functions

install_prepare() {
	if echo -n "" | grep n >/dev/null; then
		# echo -n does not suppress newline
		n=
	else
		n='-n'
	fi
}

init_package_commands() {
	case "$1" in
	hpux)
		packagelistcmd=swlist
		packageinstallcmd='swinstall -s `pwd`/${packagename}*depot ${packagename}'
		packageurls='http://hpux.connect.org.uk/'
		break
		;;
	sunos|solaris)
		packagelistcmd=pkginfo
		packageinstallcmd='pkgadd -d ${packagename}*pkg all'
		packageurls='ftp://ftp.sunfreeware.com/'
		break
		;;
	aix)
		packagelistcmd='lslpp -L'
		packageinstallcmd='installp -d `pwd`/${packagename}*bff all'
		packageurls='http://www.bullfreeware.com/'
		break
		;;
	darwin)
		packagelistcmd='port installed'
		packageinstallcmd='port install ${packagename}'
		packageurls="http://www.macports.org/"
		break
		;;
	*bsd)
		packagelistcmd=pkg_info
		packageinstallcmd='pkg_add ${packagename}'
		break
		;;
	rpm)
		packagelistcmd='rpm -qa'
		packageinstallcmd='rpm -ivh ${packagename}*.rpm'
		packageurls='http://www.rpmfind.net/'
		break
		;;
	deb)
		packagelistcmd='dpkg -l'
		packageinstallcmd='apt-get install ${packagename}'
		packageurls='http://packages.ubuntu.com/,http://packages.debian.org/'
		break
		;;
	slackware)
		packagelistcmd='ls -1 /var/log/packages'
		packageinstallcmd='installpkg ${packagename}'
		break
		;;
	*)
		packagelistcmd=
		packageinstallcmd=
		break
		;;
	esac
}

check_distro() {
	# http://linuxmafia.com/faq/Admin/release-files.html
	# http://goc.grid.sinica.edu.tw/gocwiki/How_to_publish_the_OS_name
	#
	uname=`uname | tr A-Z a-z`
	if [ "$uname" != 'linux' ]; then
		distro=
		init_package_commands $uname
	elif [ -e /etc/ubuntu-release ]; then
		distro=ubuntu
		init_package_commands deb
	elif [ -e /etc/redhat-release ]; then
		distro=redhat
		init_package_commands rpm
	elif [ -e /etc/fedora-release ]; then
		distro=fedoracore
		init_package_commands rpm
	elif [ -e /etc/mandrake-release ]; then
		distro=mandrake
		init_package_commands rpm
	elif [ -e /etc/debian_version ]; then
		distro=debian
		init_package_commands deb
	elif [	-e /etc/SuSE-release -o -e /etc/UnitedLinux-release ]; then
		distro=suse
		init_package_commands rpm
	elif [ -e /etc/slackware-version ]; then
		distro=slackware
		init_package_commands slackware
	elif [ -e /etc/knoppix_version ]; then
		distro=knoppix
		init_package_commands deb
	elif [ -x /usr/bin/lsb_release ]; then
		distro="`lsb_release -i | awk '{print $NF}' | tr A-Z a-z`"
		init_package_commands ''
	else
		distro=unknown
		init_package_commands ''
	fi
}

enkader() {
	# usage  : cmd | enkader [ indent [ footer_yesno ] ]
	# example: dpkg -l | grep libncurses | enkader
	indent="${1:-4}"
	footer="${2:-yes}"
	awk '
	BEGIN {
		indent="'"$indent"'"
		if ("'"$footer"'" == "no") footer=0; else footer=1
		maxlength=77-indent;
		indentstr=substr("                                    ", 1, indent);
		minusstr=substr( \
			"--------------------------------------------------------------------------------", \
			1, maxlength + 1);
		printf("%s+%-s+\n", indentstr, minusstr);
	}
	{
		printf("%s| %-" maxlength "s|\n", indentstr, substr($0, 1, maxlength));
	}
	END {
		if (footer) printf("%s+%-s+\n", indentstr, minusstr);
	}'
}

enkadercmd() {
	command="$@"
	test "$command" || return
	echo "Command: $command" | enkader 4 no
	eval "$command" | enkader 4
}

#----------------------------- main functions ---------------------------------

check_libncurses_installation() {
#	if [ "$ubuntu" ]; then
#		apt-get install libncurses5
#		apt-get install libncurses5-dev
#	else
	question="Has libncurses successfully been installed on your system? (Yes/No/Tell me) "
	answer=n
	echo $n "$question"
	read answer
	while [ "$answer" != y ]; do
		download_and_install_lib ncurses
		echo $n "$question"
		read answer
	done
}

check_libreadline_installation() {
	if [ "$ubuntu" ]; then
		apt-get install libreadline5
		apt-get install libreadline5-dev
		apt-get install libterm-readline-gnu-perl
	else
		question="Has libreadline successfully been installed on your system? (Yes/No/Tell me) "
		answer=n
		echo $n "$question"
		read answer
		while [ "$answer" != y ]; do
			download_and_install_lib readline
			echo $n "$question"
			read answer
		done
	fi
}

download_and_install_lib() {
	case `uname` in
		AIX)
			echo "You will need to download it from e.g. http://www.bullfreeware.com/"
			echo "(maybe: http://www.bullfreeware.com/download/aix43/gnu.readline-4.1.0.1.exe)"
			echo "and install it using installp, with something like:"
			echo 'installp -d `pwd`/lib'$1'*bff all'
			break;;
		HPUX)
			echo "You will need to download it from e.g. http://hpux.connect.org.uk/"
			echo "(maybe: http://hpux.connect.org.uk/hppd/hpux/Gnu/readline-6.0.004/ )"
			echo "and install it using swinstall, with something like:"
			echo 'swinstall -s `pwd`/lib'$1'*depot lib'$1
			break;;
		Solaris)
			echo "You will need to download it from e.g. http://www.sunfreeware.com/"
			echo "(maybe: ftp://ftp.sunfreeware.com/pub/freeware/sparc/10/readline-5.2-sol10-sparc-local.gz)"
			echo "and install it using pkgadd, with something like:"
			echo 'pkgadd -d lib'$1'*pkg all'
			break;;
		Linux)
			echo You will need to download and install lib$1.
			echo Depending on your distribution:
			echo '\tdownload it from e.g. http://www.rpmfind.net/'
			echo '\tand install it using rpm, with something like:'
			echo '\trpm -ivh lib'$1'*rpm'
			echo or:
			echo '\tdownload it from e.g. http://packages.debian.org/'
			echo '\tand install it using apt-get, with something like:'
			echo '\tapt-get install lib'$1
			echo or use your distribution-specific commands.
			break;;
		*)
			echo "You will need to download and install lib$1".
			break;;
	esac
	echo
}

check_perl_module() {
	perl -M"$1" -e1
}

download_and_install_perl_module() {
	olddir=$(pwd)
	url="$1"
	file="${1##/}"
	name="${file%.tar.gz}"
	cd /tmp
	wget -c "$url"
	gunzip < "$file" | tar xvf -
	cd "$name"
	perl Makefile.PL
	make
	make test
	make install
	cd $olddir
}

install_pfm() {
	olddir=$(pwd)
	if [ ! -f pfm ]; then
		file="pfm-$VERSION.tar.gz"
		name="${file%.tar.gz}"
		cd /tmp
		wget -c http://downloads.sourceforge.net/p-f-m/$file
		gunzip < "$file" | tar xvf -
		cd "$name"
	fi
	make
	make install
	cd $olddir
}

###############################################################################
# main

install_prepare
check_distro

check_libncurses_installation
check_libreadline_installation

# check, download and install the Perl modules

check_perl_module Term::Cap || download_and_install_perl_module \
	http://search.cpan.org/CPAN/authors/id/J/JS/JSTOWE/Term-Cap-1.12.tar.gz

check_perl_module Term::Screen || download_and_install_perl_module \
	http://search.cpan.org/CPAN/authors/id/J/JS/JSTOWE/Term-Screen-1.03.tar.gz

check_perl_module Term::ScreenColor || download_and_install_perl_module \
	http://search.cpan.org/CPAN/authors/id/R/RU/RUITTENB/Term-ScreenColor-1.10.tar.gz

check_perl_module Term::ReadLine::Gnu || download_and_install_perl_module \
	http://search.cpan.org/CPAN/authors/id/H/HA/HAYASHI/Term-ReadLine-Gnu-1.17a.tar.gz

# check, download and install the application

install_pfm


# vim: set tabstop=8 shiftwidth=8 noexpandtab:
