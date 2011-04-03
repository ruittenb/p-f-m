#!/usr/bin/env sh
############################################################################
#
# Name:         installpfm.sh
# Version:      0.05
# Authors:      Rene Uittenbogaard
# Date:         2009-09-23
# Usage:        installpfm.sh
# Description:  This is not a script, this is a manual.
#		This is meant as an example how pfm dependencies can
#		be downloaded and installed. Your Mileage May Vary.
#		Comments and improvements are welcome!
#

VERSION=1.93.9

###############################################################################
# functions

install_prepare() {
	if echo -n "" | grep n >/dev/null; then
		# echo -n does not suppress newline
		n=
	else
		n='-n'
	fi
}

check_distro() {
	# if you know how to easily identify other distributions,
	# please let me know.
	if [ `uname` -eq 'Linux' ]; then
		ubuntu=`cat /etc/*-release 2>/dev/null | grep -i ubuntu`
	fi
}

check_libncurses_installation() {
	if [ "$ubuntu" ]; then
		apt-get install libncurses5
		apt-get install libncurses5-dev
	else
		question="Has libncurses successfully been installed on your system? (y/n) "
		answer=n
		echo $n "$question"
		read answer
		while [ "$answer" != y ]; do
			download_and_install_lib ncurses
			echo $n "$question"
			read answer
		done
	fi
}

check_libreadline_installation() {
	if [ "$ubuntu" ]; then
		apt-get install libreadline5
		apt-get install libreadline5-dev
		apt-get install libterm-readline-gnu-perl
	else
		question="Has libreadline successfully been installed on your system? (y/n) "
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

check_perl_module Term::Cap || download_and_install_perl_module \
	http://search.cpan.org/CPAN/authors/id/J/JS/JSTOWE/Term-Cap-1.12.tar.gz

check_perl_module Term::Screen || download_and_install_perl_module \
	http://search.cpan.org/CPAN/authors/id/J/JS/JSTOWE/Term-Screen-1.03.tar.gz

check_perl_module Term::ScreenColor || download_and_install_perl_module \
	http://search.cpan.org/CPAN/authors/id/R/RU/RUITTENB/Term-ScreenColor-1.10.tar.gz

check_perl_module Term::ReadLine::Gnu || download_and_install_perl_module \
	http://search.cpan.org/CPAN/authors/id/H/HA/HAYASHI/Term-ReadLine-Gnu-1.17a.tar.gz

install_pfm



