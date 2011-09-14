
LWP_VER            = 6.26
LWP                = libwww-perl-$(LWP_VER)
HTML_PARSER_VER    = 3.72
HTML_PARSER        = HTML-Parser-$(HTML_PARSER_VER)
FILE_TEMP_VER      = 0.2304
FILE_TEMP          = File-Temp-$(FILE_TEMP_VER)
FILE_STAT_BITS_VER = 0.19
FILE_STAT_BITS     = File-Stat-Bits-1.01
MODULE_LOAD_VER    = 0.32
MODULE_LOAD        = Module-Load-$(MODULE_LOAD_VER)
TERM_SCREEN_VER    = 1.06
TERM_SCREEN        = Term-Screen-$(TERM_SCREEN_VER)
TERM_SCRCOL_VER    = 1.20
TERM_SCRCOL        = Term-ScreenColor-$(TERM_SCRCOL_VER)
TERM_RL_GNU_VER    = 1.35
TERM_RL_GNU        = Term-ReadLine-Gnu-$(TERM_RL_GNU_VER)
ENCODE_VER         = 2.89
ENCODE             = Encode-$(ENCODE_VER)
ENCODE_LOCALE_VER  = 1.05
ENCODE_LOCALE      = Encode-Locale-$(ENCODE_LOCALE_VER)

DARWINOPTS = --includedir=/opt/local/include --libdir=/opt/local/lib

SUDO = $$SUDO

all: LWP HTML-Parser File-Temp File-Stat-Bits				\
	Module-Load Term-Screen Term-ScreenColor Term-ReadLine-Gnu	\
	Encode Encode-Locale

clean:
	rm -rf $(LWP) $(HTML_PARSER) $(FILE_TEMP) $(FILE_STAT_BITS)	\
	$(MODULE_LOAD) $(TERM_SCREEN) $(TERM_SCRCOL) $(TERM_RL_GNU)	\
	$(ENCODE) $(ENCODE_LOCALE)

LWP:
	@echo 'Checking installation of LWP...'
	@if 2>/dev/null perl -MLWP -e					\
	'exit !($$LWP::VERSION ge "$(LWP_VER)")';			\
	then :;								\
	else								\
		gunzip < $(LWP).tar.gz | tar xvf - ;			\
		(							\
			cd $(LWP)		&&			\
			perl Makefile.PL	&&			\
			make all test		&&			\
			${SUDO} make install				\
		)							\
	fi

HTML-Parser:
	@echo 'Checking installation of HTML::Parser...'
	@if 2>/dev/null perl -MHTML::Parser -e				\
	'exit !($$HTML::Parser::VERSION ge "$(HTML_PARSER_VER)")';	\
	then :;								\
	else								\
		gunzip < $(HTML_PARSER).tar.gz | tar xvf - ;		\
		(							\
			cd $(HTML_PARSER)	&&			\
			perl Makefile.PL	&&			\
			make all test		&&			\
			${SUDO} make install				\
		)							\
	fi

File-Temp:
	@echo 'Checking installation of File::Temp...'
	@if 2>/dev/null perl -MFile::Temp -e				\
	'exit !($$File::Temp::VERSION ge "$(FILE_TEMP_VER)")';		\
	then :;								\
	else								\
		gunzip < $(FILE_TEMP).tar.gz | tar xvf - ;		\
		(							\
			cd $(FILE_TEMP)		&&			\
			perl Makefile.PL	&&			\
			make all test		&&			\
			${SUDO} make install				\
		)							\
	fi

File-Stat-Bits:
	@echo 'Checking installation of File::Stat::Bits...'
	@if 2>/dev/null perl -MFile::Stat::Bits -e			\
	'exit!($$File::Stat::Bits::VERSION ge "$(FILE_STAT_BITS_VER)")';\
	then :;								\
	else								\
		gunzip < $(FILE_STAT_BITS).tar.gz | tar xvf - ;		\
		(							\
			cd $(FILE_STAT_BITS)	&&			\
			perl Makefile.PL	&&			\
			make all test		&&			\
			${SUDO} make install				\
		)							\
	fi

Module-Load:
	@echo 'Checking installation of Module::Load...'
	@if 2>/dev/null perl -MModule::Load -e				\
	'exit !($$Module::Load::VERSION ge "$(MODULE_LOAD_VER)")';	\
	then :;								\
	else								\
		gunzip < $(MODULE_LOAD).tar.gz | tar xvf - ;		\
		(							\
			cd $(MODULE_LOAD)	&&			\
			perl Makefile.PL	&&			\
			make all test		&&			\
			${SUDO} make install				\
		)							\
	fi

Term-Screen:
	@echo 'Checking installation of Term::Screen...'
	@if 2>/dev/null perl -MTerm::Screen -e				\
	'exit !($$Term::Screen::VERSION ge "$(TERM_SCREEN_VER)")';	\
	then :;								\
	else								\
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
	'exit !($$Term::ScreenColor::VERSION ge "$(TERM_SCRCOL_VER)")';	\
	then :;								\
	else								\
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
	-e 'exit !($$t->ReadLine eq "Term::ReadLine::Gnu" &&'		\
	-e '$$Term::ReadLine::Gnu::VERSION ge "$(TERM_RL_GNU_VER)")';	\
	then :;								\
	else								\
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

Encode:
	@echo 'Checking installation of Encode...'
	@if 2>/dev/null perl -MEncode -e				\
	'exit !($$Encode::VERSION ge "$(ENCODE_VER)")';			\
	then :;								\
	else								\
		gunzip < $(ENCODE).tar.gz | tar xvf - ;			\
		(							\
			cd $(ENCODE)		&&			\
			perl Makefile.PL	&&			\
			make all test		&&			\
			${SUDO} make install				\
		)							\
	fi

Encode-Locale:
	@echo 'Checking installation of Encode::Locale...'
	@if 2>/dev/null perl -MEncode::Locale -e			\
	'exit !($$Encode::Locale::VERSION ge "$(ENCODE_LOCALE_VER)")';	\
	then :;								\
	else								\
		gunzip < $(ENCODE_LOCALE).tar.gz | tar xvf - ;		\
		(							\
			cd $(ENCODE_LOCALE)	&&			\
			perl Makefile.PL	&&			\
			make all test		&&			\
			${SUDO} make install				\
		)							\
	fi

.PHONY: LWP HTML-Parser File-Temp File-Stat-Bits			\
	Module-Load Term-Screen Term-ScreenColor Term-ReadLine-Gnu	\
	Encode Encode-Locale

