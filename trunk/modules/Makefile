TERM_CAP=Term-Cap-1.12
TERM_SCREEN=Term-Screen-1.03
TERM_SCREENCOLOR=Term-ScreenColor-1.13
TERM_READLINE_GNU=Term-ReadLine-Gnu-1.19
LWP_SIMPLE=libwww-perl-5.834

SUDO=sudo

all: Term-Cap Term-Screen Term-Screen-Uni Term-ScreenColor Term-ReadLine-Gnu LWP-Simple

Term-Cap:
	@echo 'Checking installation of Term::Cap...'
	@if perl -MTerm::Cap -e1 2>/dev/null; then :; \
	else \
		gunzip < $(TERM_CAP).tar.gz | tar xvf - ; \
		( cd $(TERM_CAP); perl Makefile.PL; make all; ${SUDO} make install ) \
	fi

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

LWP-Simple:
	@echo 'Checking installation of LWP::Simple...'
	@if perl -MLWP::Simple -e1 2>/dev/null; then :; \
	else \
		gunzip < $(LWP_SIMPLE).tar.gz | tar xvf - ; \
		( cd $(LWP_SIMPLE); perl Makefile.PL; make all test; ${SUDO} make install ) \
	fi

.PHONY: Term-Cap Term-Screen Term-ScreenColor Term-ReadLine-Gnu LWP-Simple

