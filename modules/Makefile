
TERM_SCREEN_VER    = 1.03
TERM_SCREEN        = Term-Screen-$(TERM_SCREEN_VER)
TERM_SCRCOL_VER    = 1.13
TERM_SCRCOL        = Term-ScreenColor-1.13a
TERM_RL_GNU_VER    = 1.20
TERM_RL_GNU        = Term-ReadLine-Gnu-$(TERM_RL_GNU_VER)
FILE_STAT_BITS_VER = 0.19
FILE_STAT_BITS     = File-Stat-Bits-1.01
HTML_PARSER_VER    = 3.67
HTML_PARSER        = HTML-Parser-$(HTML_PARSER_VER)
LWP_VER            = 5.836
LWP                = libwww-perl-$(LWP_VER)

DARWINOPTS = --includedir=/opt/local/include --libdir=/opt/local/lib

SUDO = sudo

all: Term-Screen Term-ScreenColor Term-ReadLine-Gnu			\
	File-Stat-Bits HTML-Parser LWP

clean:
	rm -rf $(TERM_SCREEN) $(TERM_SCRCOL) $(TERM_RL_GNU)		\
		$(FILE_STAT_BITS) $(HTML_PARSER) $(LWP)

Term-Screen:
	@echo 'Checking installation of Term::Screen...'
	@if 2>/dev/null perl -MTerm::Screen -e				\
	'exit !($$Term::Screen::VERSION lt "$(TERM_SCREEN_VER)")';	\
	then								\
		gunzip < $(TERM_SCREEN).tar.gz | tar xvf - ;		\
		(							\
			cd $(TERM_SCREEN)	&&			\
			perl Makefile.PL	&&			\
			make all		&&			\
			${SUDO} make install				\
		)							\
	fi

Term-ScreenColor:
	@echo 'Checking installation of Term::ScreenColor...'
	@if 2>/dev/null perl -MTerm::ScreenColor -e			\
	'exit !($$Term::ScreenColor::VERSION lt "$(TERM_SCRCOL_VER)")';	\
	then								\
		gunzip < $(TERM_SCRCOL).tar.gz | tar xvf - ;		\
		(							\
			cd $(TERM_SCRCOL)	&&			\
			perl Makefile.PL	&&			\
			make all test		&&			\
			${SUDO} make install				\
		)							\
	fi

Term-ReadLine-Gnu:
	@echo 'Checking installation of Term::ReadLine::Gnu...'
	@if 2>/dev/null perl -MTerm::ReadLine				\
	-e '$$t = new Term::ReadLine "";'				\
	-e 'exit !($$t->ReadLine ne "Term::ReadLine::Gnu" ||'		\
	-e '$$Term::ReadLine::Gnu::VERSION lt "$(TERM_RL_GNU_VER)")';	\
	then								\
		gunzip < $(TERM_RL_GNU).tar.gz | tar xvf - ;		\
		(							\
			cd $(TERM_RL_GNU)		&&		\
			if perl Makefile.PL;				\
			then						\
				make all test		&&		\
				${SUDO} make install;			\
			elif [ "`uname`" = Darwin ];			\
			then						\
				perl Makefile.PL $(DARWINOPTS) &&	\
				make all test		&&		\
				${SUDO} make install;			\
			fi						\
		)							\
	fi

File-Stat-Bits:
	@echo 'Checking installation of File::Stat::Bits...'
	@if 2>/dev/null perl -MFile::Stat::Bits -e			\
	'exit!($$File::Stat::Bits::VERSION lt "$(FILE_STAT_BITS_VER)")';\
	then								\
		gunzip < $(FILE_STAT_BITS).tar.gz | tar xvf - ;		\
		(							\
			cd $(FILE_STAT_BITS)	&&			\
			perl Makefile.PL	&&			\
			make all test		&&			\
			${SUDO} make install				\
		)							\
	fi

HTML-Parser:
	@echo 'Checking installation of HTML::Parser...'
	@if 2>/dev/null perl -MHTML::Parser -e				\
	'exit !($$HTML::Parser::VERSION lt "$(HTML_PARSER_VER)")';	\
	then								\
		gunzip < $(HTML_PARSER).tar.gz | tar xvf - ;		\
		(							\
			cd $(HTML_PARSER)	&&			\
			perl Makefile.PL	&&			\
			make all test		&&			\
			${SUDO} make install				\
		)							\
	fi

LWP:
	@echo 'Checking installation of LWP...'
	@if 2>/dev/null perl -MLWP -e					\
	'exit !($$LWP::VERSION lt "$(LWP_VER)")';			\
	then								\
		gunzip < $(LWP).tar.gz | tar xvf - ;			\
		(							\
			cd $(LWP)		&&			\
			perl Makefile.PL	&&			\
			make all test		&&			\
			${SUDO} make install				\
		)							\
	fi

.PHONY: Term-Screen Term-ScreenColor Term-ReadLine-Gnu			\
	File-Stat-Bits HTML-Parser LWP

