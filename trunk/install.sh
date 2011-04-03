#!/usr/bin/env sh
############################################################################
#
# Name:         install.sh
# Version:      0.23
# Authors:      Rene Uittenbogaard
# Date:         2010-11-28
# Usage:        sh install.sh
# Description:  Un*x-like systems can be very diverse.
#		This script is meant as an example how pfm dependencies
#		can be downloaded and installed, but Your Mileage May Vary.
#		Suggestions for improvement are welcome!
#

VERSION=1.95.0

###############################################################################
# helper functions

install_prepare() {
	if echo -n '' | grep n >/dev/null; then
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
		packageinstallcmd='swinstall -s \`pwd\`/${packagename}\*depot ${packagename}'
		packageurls='http://hpux.connect.org.uk/'
		packagesuggestion='http://hpux.connect.org.uk/hppd/hpux/Gnu/readline-6.0.004/'
		break
		;;
	sunos|solaris)
		packagelistcmd=pkginfo
		packageinstallcmd='pkgadd -d ${packagename}\*pkg all'
		packageurls='ftp://ftp.sunfreeware.com/'
		packagesuggestion='ftp://ftp.sunfreeware.com/pub/freeware/sparc/10/readline-5.2-sol10-sparc-local.gz'
		break
		;;
	aix)
		packagelistcmd='lslpp -L'
		packageinstallcmd='installp -d \`pwd\`/${packagename}\*bff all'
		packageurls='http://www.bullfreeware.com/'
		packagesuggestion='http://www.bullfreeware.com/download/aix43/gnu.readline-4.1.0.1.exe'
		break
		;;
	darwin)
		if port version >/dev/null 2>&1; then
			packagelistcmd='port installed'
			packageinstallcmd='port install ${packagename}'
			packageurls='http://www.macports.org/'
		else
			packagelistcmd='dpkg -l'
			packageinstallcmd='apt-get install ${packagename}'
			packageurls='http://www.finkproject.org/'
		fi
		break
		;;
	*bsd)
		packagelistcmd=pkg_info
		packageinstallcmd='pkg_add ${packagename}'
		packageurls='http://www.freebsd.org/ports/,ftp://ftp.openbsd.org/pub/OpenBSD/'
		break
		;;
	rpm)
		packagelistcmd='rpm -qa'
		packageinstallcmd='rpm -ivh ${packagename}\*.rpm'
		packageurls='http://www.rpmfind.net/,http://www.rpm.org/'
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
		packageurls='http://packages.slackware.it/'
		break
		;;
	gentoo)
		packagelistcmd='emerge -s'
		packageinstallcmd='emerge ${packagename}'
		packageurls='http://www.gentoo.org/main/en/mirrors2.xml'
		break
		;;
	*)
		packagelistcmd=
		packageinstallcmd=
		packageurls=
		break
		;;
	esac
}

check_distro() {
	# http://linuxmafia.com/faq/Admin/release-files.html
	# http://goc.grid.sinica.edu.tw/gocwiki/How_to_publish_the_OS_name
	#
	uname=`uname | tr A-Z a-z`
	lsb="`lsb_release -i 2>/dev/null | awk '{print $NF}' | tr A-Z a-z`"
	if [ "$uname" != 'linux' ]; then
		distro=
		init_package_commands $uname
	elif [ -e /etc/ubuntu-release -o "$lsb" = ubuntu ]; then
		distro=ubuntu
		init_package_commands deb
	elif [ -e /etc/redhat-release -o "$lsb" = redhat ]; then
		distro=redhat
		init_package_commands rpm
	elif [ -e /etc/fedora-release -o "$lsb" = fedora ]; then
		distro=fedoracore
		init_package_commands rpm
	elif [ -e /etc/mandrake-release -o "$lsb" = mandrake ]; then
		distro=mandrake
		init_package_commands rpm
	elif [ -e /etc/debian_version -o "$lsb" = debian ]; then
		distro=debian
		init_package_commands deb
	elif [	-e /etc/SuSE-release        -o "$lsb" = suse \
	-o	-e /etc/UnitedLinux-release -o "$lsb" = unitedlinux ]; then
		distro=suse
		init_package_commands rpm
	elif [ -e /etc/slackware-version -o "$lsb" = slackware ]; then
		distro=slackware
		init_package_commands slackware
	elif [ -e /etc/knoppix_version -o "$lsb" = knoppix ]; then
		distro=knoppix
		init_package_commands deb
	elif [ -e /etc/gentoo-release -o "$lsb" = gentoo ]; then
		distro=gentoo
		init_package_commands gentoo
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

###############################################################################
# main functions

check_package() {
	packagename="$1"
	question="Has lib$packagename successfully been installed on your system? (Yes/No/Tell me) "
	answer=n
	echo $n "$question"
	read answer
	while [ "$answer" != y ]; do
		if [ "$answer" = t ]; then
			if [ "x$packagelistcmd" = x ]; then
				echo "I don't know how to list installed packages for your system, sorry"
			else
				enkadercmd "$packagelistcmd|grep -i '$packagename'||echo not found"
			fi
		elif [ "$answer" != y ]; then
			download_and_install "$packagename"
		fi
		echo $n "$question"
		read answer
	done
}

download_and_install() {
	packagename="$1"
	echo "You will need to download $packagename (sometimes called lib$packagename),"
	if [ "x$packageurls" != x ]; then
		echo "perhaps from:"
		for url in $(echo $packageurls | tr , " "); do
			echo "- $url"
		done
		if [ "x$packagesuggestion" != x ]; then
			echo "(maybe: $packagesuggestion)"
		fi
	fi
	echo $n "and install it"
	if [ "x$packageinstallcmd" != x ]; then
		echo " using a command like:"
		eval "echo '$packageinstallcmd'"
	fi
	echo
}

check_cpan() {
	if check_perl_module CPAN; then
		cpan_available=1
	else
		cpan_available=
	fi
}

check_perl_module() {
	echo "Checking module $1..."
	if perl -M"$1" -e1; then
		echo "Module $1 found."
	else
		echo "Module $1 not found"
		return 1
	fi
}

check_perl_module_term_readline_gnu() {
	trg=Term::ReadLine::Gnu
	echo "Checking module $trg..."
	if perl -MTerm::ReadLine -e '$t = new Term::ReadLine ""; exit !($t->ReadLine eq "Term::ReadLine::Gnu")'; then
		echo "Module $trg found."
	else
		echo "Module $trg not found"
		return 1
	fi
}

download_and_install_perl_module() {
	packagename="$1"
	if [ "$cpan_available" ]; then
		install_opt=
		while [ "x$install_opt" != xb -a "x$install_opt" != xc ]; do
			echo "Do you want to install the bundled version, or "
			echo $n "download the latest version from CPAN? (Bundled/Cpan) "
			read install_opt
			install_opt=$(echo $install_opt | cut -c1 | tr A-Z a-z)
		done
	else
		install_opt=b
	fi

	if [ "x$install_opt" = xc ]; then
		perl -MCPAN -e"install $packagename"
	else
		target="$(echo $packagename | sed -es/::/-/g)"
		make -C modules $target
	fi
}

install_pfm() {
	make
	make install
}

###############################################################################
# main

install_prepare
check_distro

check_package ncurses
check_package readline

# check, download and install the Perl modules

check_cpan
check_perl_module Term::Cap         || download_and_install_perl_module Term::Cap
check_perl_module Term::Screen      || download_and_install_perl_module Term::Screen
check_perl_module Term::ScreenColor || download_and_install_perl_module Term::ScreenColor
check_perl_module_term_readline_gnu || download_and_install_perl_module Term::ReadLine::Gnu

# check, download and install the application

install_pfm

# vim: set tabstop=8 shiftwidth=8 noexpandtab:

