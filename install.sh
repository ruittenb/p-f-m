#!/bin/ksh
############################################################################
#
# Name:         installpfm.sh
# Version:      0.03
# Authors:      Rene Uittenbogaard
# Date:         2009-09-17
# Usage:        installpfm.sh
# Description:  This is not a script, this is a manual.
#		This is meant as an example how pfm dependencies can
#		be downloaded and installed. Your Mileage May Vary.
#		Comments and improvements are welcome!
#

VERSION=1.93.7

###############################################################################
# functions

check_libreadline_installation() {
	question="Has libreadline successfully been installed on your system? (y/n) "
	answer=n
	read answer?"$question"
	while [ "$answer" != y ]; do
		download_and_install_libreadline
		read answer?"$question"
	done
}

download_and_install_libreadline() {
	case `uname` in
		AIX)
			echo You will need to download libreadline from e.g. http://www.bullfreeware.com/
			echo and install it using installp, with something like:
			echo 'installp -d `pwd`/libreadline*bff all'
			break;;
		HPUX)
			echo You will need to download it from e.g. http://hpux.cs.utah.edu/
			echo and install it using swinstall, with something like:
			echo 'swinstall -s `pwd`/libreadline*depot libreadline'
			break;;
		Solaris)
			echo You will need to download it from e.g. http://www.sunfreeware.com/
			echo and install it using pkgadd, with something like:
			echo 'pkgadd -d libreadline*pkg all'
			break;;
		Linux)
			if cat /etc/*-release 2>/dev/null | grep -i ubuntu >/dev/null; then
				echo You will need to install libterm-readline-gnu-perl,
				echo e.g. with a command like: apt-get install libterm-readline-gnu-perl
			else
				echo You will need to download and install libreadline.
				echo Depending on your distribution:
				echo '\tdownload it from e.g. http://www.rpmfind.net/'
				echo '\tand install it using rpm, with something like:'
				echo '\trpm -ivh libreadline*rpm'
				echo or:
				echo '\tdownload it from e.g. http://packages.debian.org/'
				echo '\tand install it using apt-get, with something like:'
				echo '\tapt-get install libreadline'
				echo or use your distribution-specific commands.
			fi
			break;;
		*)
			echo You will need to download and install libreadline.
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



