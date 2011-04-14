TERM_SCREEN=Term-Screen-1.03
TERM_SCREENCOLOR=Term-ScreenColor-1.13a
TERM_READLINE_GNU=Term-ReadLine-Gnu-1.20
LWP=libwww-perl-5.835

SUDO=sudo

all: Term-Screen Term-ScreenColor Term-ReadLine-Gnu LWP

Term-Screen:
	@echo 'Checking installation of Term::Screen...'
	@if perl -MTerm::Screen -e1 2>/dev/null; then :; \
	else \
		gunzip < $(TERM_SCREEN).tar.gz | tar xvf - ; \
		( cd $(TERM_SCREEN); perl Makefile.PL; make all; ${SUDO} make install ) \
	fi

Term-ScreenColor:
	@echo 'Checking installation of Term::ScreenColor...'
	@if perl -MTerm::ScreenColor -e1 2>/dev/null; then :; \
	else \
		gunzip < $(TERM_SCREENCOLOR).tar.gz | tar xvf - ; \
		( cd $(TERM_SCREENCOLOR); perl Makefile.PL; make all test; ${SUDO} make install ) \
	fi

Term-ReadLine-Gnu:
	@echo 'Checking installation of Term::ReadLine::Gnu...'
	@if perl -MTerm::ReadLine -e '$$t = new Term::ReadLine ""; exit !($$t->ReadLine eq "Term::ReadLine::Gnu")'; then :; \
	else \
		gunzip < $(TERM_READLINE_GNU).tar.gz | tar xvf - ; \
		( cd $(TERM_READLINE_GNU); \
		perl Makefile.PL || { \
			test "`uname`" = Darwin && perl Makefile.PL --prefix=/opt/local; \
		}; \
		make all test; ${SUDO} make install ) \
	fi

LWP:
	@echo 'Checking installation of LWP...'
	@if perl -MLWP -e1 2>/dev/null; then :; \
	else \
		gunzip < $(LWP).tar.gz | tar xvf - ; \
		( cd $(LWP); perl Makefile.PL; make all test; ${SUDO} make install ) \
	fi

.PHONY: Term-Screen Term-ScreenColor Term-ReadLine-Gnu LWP

