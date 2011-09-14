#!/usr/bin/env sh
############################################################################
#
# Name:         install.sh
# Version:      0.41
# Authors:      Rene Uittenbogaard
# Date:         2010-09-16
# Usage:        sh install.sh
# Description:  Un*x-like systems can be very diverse.
#		This script is meant as an example how pfm dependencies
#		can be downloaded and installed, but Your Mileage May Vary.
#		Suggestions for improvement are welcome!
#

############################################################################
# helper functions

install_prepare() {
	echo
	echo "This script will try to guide you through the process of"
	echo "installing pfm together with its dependencies."
	echo
	VERSION=$(cat pfm | perl -ne '
		/^[^@]*\@\(#\)\D+(?:\d{4}-\d{2}-\d{2}\s*)?v?([[:alnum:].]+).*$/
			and print $1;
	')
	if [ "$PFMRC" -a -e "$PFMRC" ]; then
		pfmrc="$PFMRC"
	else
		pfmrc=~/.pfm/.pfmrc
	fi
	if echo -n '' | grep n >/dev/null; then
		# echo -n does not suppress newline
		n=
	else
		n='-n'
	fi
	sudo=
	if [ `whoami` != root ]; then
		echo $n "Do you want to use sudo? (Yes/No) "
		read answer
		answer=$(echo $answer | cut -c1 | tr A-Z a-z)
		if [ "x$answer" = xy ]; then
			sudo=sudo
		fi
	fi
	echo
}

init_package_commands() {
	case "$1" in
	hpux)
		packagelistcmd=swlist
		packageinstallcmd='swinstall -s \`pwd\`/${packagename}\*depot ${packagename}'
		packageurls='http://hpux.connect.org.uk/'
		ncursessuggestion='http://hpux.connect.org.uk/ftp/hpux/Sysadmin/ncurses-5.7/ncurses-5.7-hppa-11.23.depot.gz'
		readlinesuggestion='http://hpux.connect.org.uk/hppd/hpux/Gnu/readline-6.0.004/'
		break
		;;
	sunos|solaris)
		packagelistcmd=pkginfo
		packageinstallcmd='pkgadd -d ${packagename}\*pkg all'
		packageurls='ftp://ftp.sunfreeware.com/'
		ncursessuggestion='ftp://ftp.sunfreeware.com/pub/freeware/sparc/10/ncurses-5.7-sol10-sparc-local.gz'
		readlinesuggestion='ftp://ftp.sunfreeware.com/pub/freeware/sparc/10/readline-5.2-sol10-sparc-local.gz'
		break
		;;
	aix)
		packagelistcmd='lslpp -L'
		packageinstallcmd='installp -d \`pwd\`/${packagename}\*bff all'
		packageurls='http://www.bullfreeware.com/'
		ncursessuggestion=
		readlinesuggestion='http://www.bullfreeware.com/download/aix43/gnu.readline-4.1.0.1.exe'
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

make_minusC() {
	# 'make -C' is not portable
	cd "$1"
	shift
	make "$@"
	cd ..
}

############################################################################
# main functions

check_package() {
	packagename="$1"
	question="Has lib$packagename successfully been installed on your system? (Yes/No/Tell me) "
	answer=n
	echo $n "$question"
	read answer
	answer=$(echo $answer | cut -c1 | tr A-Z a-z)
	while [ "x$answer" != xy ]; do
		if [ "x$answer" = xt ]; then
			if [ "x$packagelistcmd" = x ]; then
				echo "I don't know how to list installed packages for your system, sorry!"
			else
				enkadercmd "$packagelistcmd|grep -i '$packagename'||echo not found"
			fi
		elif [ "x$answer" != xy ]; then
			download_and_install "$packagename"
		fi
		echo $n "$question"
		read answer
		answer=$(echo $answer | cut -c1 | tr A-Z a-z)
	done
}

download_and_install() {
	packagename="$1"
	echo $n "You will need to download $packagename "
	if [ "$uname" = darwin -a $packagename = readline ]; then
		echo "(for Fink: readline5,"
		echo "for Macports: readline or readline-5),"
	else
		echo "(sometimes called lib$packagename),"
	fi
	if [ "x$packageurls" != x ]; then
		echo "perhaps from:"
		for url in $(echo $packageurls | tr , " "); do
			echo "- $url"
		done
		if [ "x$ncursessuggestion" != x -a $packagename = ncurses ]; then
			echo "(maybe: $ncursessuggestion)"
		fi
		if [ "x$readlinesuggestion" != x -a $packagename = readline ]; then
			echo "(maybe: $readlinesuggestion)"
		fi
	fi
	echo $n "and install it"
	if [ "x$packageinstallcmd" != x ]; then
		echo " using a command like:"
		eval "echo $packageinstallcmd"
	fi
	echo
}

check_readline_gnu_wanted() {
	if [ -z "$PERL_RL" ]; then
		return
	fi
	variant=`echo $PERL_RL | cut -f1 -d' '`
	if [ "$variant" = Gnu ]; then
		return
	fi
	echo "Your environment variable PERL_RL seems configured to run"
	echo "Term::ReadLine::$variant. Do you want to continue installing"
	echo $n "Term::ReadLine::Gnu (strongly advised)? (Yes/No) "
	read answer
	answer=$(echo $answer | cut -c1 | tr A-Z a-z)
	if [ "x$answer" = xn ]; then
		return 1
	fi
}

check_cpan() {
	echo
	if check_perl_module CPAN; then
		cpan_available=1
	else
		cpan_available=
	fi
}

check_perl_module() {
	mod="$1"
	wantver="$2"
	echo "Checking module $mod..."
	if perl -M"$mod" -e1; then
		gotver=`perl -M"$mod" -e'print $'"$mod"'::VERSION;'`
		if perl -e"exit (\"$gotver\" lt \"$wantver\");"; then
			echo "Module $mod found (version $gotver)."
		else
			echo "Module $mod found (version $gotver), but we need $wantver."
			return 1
		fi
	else
		echo "Module $mod not found"
		return 1
	fi
}

check_perl_module_term_readline_gnu() {
	check_readline_gnu_wanted || return
	mod=Term::ReadLine
	variant=Gnu
	wantver="$1"
	PERL_RL=$variant; export PERL_RL
	echo "Checking module $mod::$variant..."
	if perl -M$mod -e "
		\$t = new $mod '';
		exit (\$t->ReadLine ne '$mod::$variant')";
	then
		gotver=`perl -M$mod -e'print $'"$mod::$variant"'::VERSION;'`
		if perl -e"exit (\"$gotver\" lt \"$wantver\");"; then
			echo "Module $mod::$variant found (version $gotver)."
		else
			echo "Module $mod::$variant found (version $gotver), but we need $wantver."
			return 1
		fi
	else
		echo "Module $mod::$variant not found"
		return 1
	fi
}

download_and_install_perl_module() {
	packagename="$1"
	if [ "$cpan_available" ]; then
		install_opt=
		while [ "x$install_opt" != xb -a "x$install_opt" != xc ]; do
			echo "Do you want to install the bundled version (B), or "
			echo $n "download the latest version from CPAN (C)? "
			read install_opt
			install_opt=$(echo $install_opt | cut -c1 | tr A-Z a-z)
		done
	else
		install_opt=b
	fi

	if [ "x$install_opt" = xc ]; then
		$sudo perl -MCPAN -e"install $packagename"
	else
		target="$(echo $packagename | sed -es/::/-/g)"
		SUDO=$sudo make_minusC modules $target
	fi
}

download_and_install_perl_module_term_readline_gnu() {
	packagename=Term::ReadLine::Gnu
	if [ $uname != darwin ]; then
		download_and_install_perl_module $packagename
		return
	fi
#	# Term::RL::Gnu gives a lot of compilation trouble on MacOSX.
#	# Offer to install it from macports/fink.
#	perlver=`perl -e'print $]'`
#	finkpkg=
#	if [ $perlver = 5.010000 ]; then
#		finkpkg=term-readline-gnu-pm5100
#	elif [ $perlver = 5.008008 ]; then
#		finkpkg=term-readline-gnu-pm588
#	elif [ $perlver = 5.008006 ]; then
#		finkpkg=term-readline-gnu-pm586
#	fi
#	if [ "$finkpkg" ]; then
#		finkalternative=" or Finkproject (F)"
#	fi
	install_opt=
	while [ "x$install_opt" != xb -a "x$install_opt" != xc \
	-a	"x$install_opt" != xm -a "x$install_opt" != xf ]
	do
		echo $n "Do you want to install the bundled version (B)"
#		echo $n ", download the version from Macports (M)${finkalternative}"
		if [ "$cpan_available" ]; then
			echo ","
			echo $n "or download the latest version from CPAN (C)"
		fi
		echo "?"
		read install_opt
		install_opt=$(echo $install_opt | cut -c1 | tr A-Z a-z)
	done

	if [ "x$install_opt" = xc ]; then
		$sudo perl -MCPAN -e"install $packagename"
#	elif [ "x$install_opt" = xm ]; then
#		$sudo port install p5-term-readline-gnu
#	elif [ "x$install_opt" = xf ]; then
#		perlver=`perl -e'print $]'`
#		if [ $perlver = 5.010000 ]; then
#			$sudo apt-get install term-readline-gnu-pm5100
#		elif [ $perlver = 5.008008 ]; then
#			$sudo apt-get install term-readline-gnu-pm588
#		elif [ $perlver = 5.008006 ]; then
#			$sudo apt-get install term-readline-gnu-pm586
#		fi
	else # bundled
		target="$(echo $packagename | sed -es/::/-/g)"
		SUDO=$sudo make_minusC modules $target
	fi
}

check_download_and_install_perl_module() {
	# the module version may not be identical to the filename version.
	# e.g. File-Stat-Bits-1.01 provides File::Stat::Bits 0.19
	#
	check_perl_module "$@" || \
	download_and_install_perl_module "$1"
}

check_download_and_install_perl_module_term_readline_gnu() {
	check_perl_module_term_readline_gnu "$1" || \
	download_and_install_perl_module_term_readline_gnu
}

install_pfm() {
	echo
	env MAKEFILE_PL_CALLED_FROM_INSTALL_SH=1 \
	perl Makefile.PL   && \
	make		   && \
	make test	   && \
	$sudo make install && \
	for oldfile in \
		/usr/local/bin/pfmrcupdate \
		/usr/local/man/man1/pfmrcupdate.1;
	do
		$sudo mv $oldfile $oldfile.old
	done
}

check_listwhite() {
	echo
	echo "Do you use a filesystem which makes use of whiteout files,"
	echo "such as: unionfs, tfs (translucent filesystem),"
	echo "ovlfs (overlay filesystem) or ifs (inheriting filesystem)?"
	echo $n "If you don't know what this is about, say no. (Yes/No) "
	read answer
	answer=$(echo $answer | cut -c1 | tr A-Z a-z)
	if [ "x$answer" != xy ]; then
		return
	fi
	echo
	echo "Proceeding with installation of listwhite..."
	cd listwhite
	./configure
	make all test
	$sudo make install
}

############################################################################
# main

install_prepare
check_distro

check_package ncurses
check_package readline

# check, download and install the Perl modules.
# check with the minimum required version.
check_cpan
check_download_and_install_perl_module File::Temp        0.22
check_download_and_install_perl_module File::Stat::Bits  0.19
check_download_and_install_perl_module HTML::Parser      3.59
check_download_and_install_perl_module LWP               5.827
check_download_and_install_perl_module Term::Screen      1.03
check_download_and_install_perl_module Term::ScreenColor 1.13
check_download_and_install_perl_module_term_readline_gnu 1.09

# install the application
install_pfm

# check the need for tools
check_listwhite

echo
echo "Installation done."
echo

# vim: set tabstop=8 shiftwidth=8 noexpandtab:

