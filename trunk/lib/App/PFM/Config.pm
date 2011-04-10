#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Config 0.10
#
# Name:			App::PFM::Config.pm
# Version:		0.10
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-01
#

##########################################################################

=pod

=head1 NAME

App::PFM::Config

=head1 DESCRIPTION

PFM Config class, used for reading and parsing the F<.pfmrc> config file,
creating a default one, and storing the configuration in memory.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Config;

use base 'App::PFM::Abstract';

use App::PFM::Util;

use POSIX qw(strftime mktime);

use strict;

use constant {
	READ_AGAIN		=> 0,
	READ_FIRST		=> 1,
	NO_COPYRIGHT	=> 0,
	SHOW_COPYRIGHT	=> 1,
	CONFIGDIRNAME	=> "$ENV{HOME}/.pfm",
	CONFIGFILENAME	=> '.pfmrc',
	CONFIGDIRMODE	=> 0700,
};

# AIX,BSD,Tru64	: du gives blocks, du -k kbytes
# Solaris		: du gives kbytes
# HP			: du gives blocks,               du -b blocks in swap(?)
# Linux			: du gives blocks, du -k kbytes, du -b bytes
# Darwin		: du gives blocks, du -k kbytes
# the ${e} is replaced later
my %DUCMDS = (
	default	=> q(du -sk ${e}2 | awk '{ printf "%d", 1024 * $1 }'),
	solaris	=> q(du -s  ${e}2 | awk '{ printf "%d", 1024 * $1 }'),
	sunos	=> q(du -s  ${e}2 | awk '{ printf "%d", 1024 * $1 }'),
	hpux	=> q(du -s  ${e}2 | awk '{ printf "%d",  512 * $1 }'),
	linux	=> q(du -sb ${e}2),
#	aix		=> can use the default
#	freebsd	=> can use the default
#	netbsd	=> can use the default
#	dec_osf	=> can use the default unless proven otherwise
#	beos	=> can use the default unless proven otherwise
#	irix	=> can use the default unless proven otherwise
#	sco		=> can use the default unless proven otherwise
#	darwin	=> can use the default
	# MSWin32, os390 etc. not supported
);

my ($_pfm, $_configfilename, %_pfmrc);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm = $pfm;
	$_configfilename =
		$ENV{PFMRC} ? $ENV{PFMRC} : CONFIGDIRNAME . "/" . CONFIGFILENAME;
}

=item _copyright()

Prints a short copyright message. Called at startup.

=cut

sub _copyright {
	my ($self, $delay) = @_;
	# lookalike to DOS version :)
	# note that configured colors are not yet known
	my $lastyear = $_pfm->{LASTYEAR};
	my $version  = $_pfm->{VERSION};
	$_pfm->screen
		->at(0,0)->clreol()->cyan()
				 ->puts("PFM $version for Unix and Unix-like operating systems.")
		->at(1,0)->puts("Copyright (c) 1999-$lastyear Rene Uittenbogaard")
		->at(2,0)->puts("This software comes with no warranty: " .
						"see the file COPYING for details.")
		->reset()->normal();
	return $_pfm->screen->key_pressed($delay);
}

=item _parse_colorsets()

Parses the colorsets defined in the F<.pfmrc>.

=cut

sub _parse_colorsets {
	my $self = shift;
	if (isyes($_pfmrc{importlscolors}) and $ENV{LS_COLORS} || $ENV{LS_COLOURS}){
		$_pfmrc{'dircolors[ls_colors]'} =  $ENV{LS_COLORS} || $ENV{LS_COLOURS};
	}
	$_pfmrc{'dircolors[off]'}   = '';
	$_pfmrc{'framecolors[off]'} =
		'headings=reverse:swap=reverse:footer=reverse:highlight=bold:';
	# this %{{ }} construct keeps values unique
	$self->{colorsetnames} = [
		keys %{{
			map { /\[(\w+)\]/; $1, '' }
			grep { /^(dir|frame)colors\[[^*]/ } keys(%_pfmrc)
		}}
	];
	# keep the default outside of @colorsetnames
	defined($_pfmrc{'dircolors[*]'})   or $_pfmrc{'dircolors[*]'}   = '';
	defined($_pfmrc{'framecolors[*]'}) or $_pfmrc{'framecolors[*]'} =
		'menu=white on blue:multi=bold reverse cyan on white:'
	.	'headings=bold reverse cyan on white:swap=reverse black on cyan:'
	.	'footer=bold reverse blue on white:message=bold cyan:highlight=bold:';
	foreach (@{$self->{colorsetnames}}) {
		# should there be no dircolors[thisname], use the default
		defined($_pfmrc{"dircolors[$_]"})
			or $_pfmrc{"dircolors[$_]"} = $_pfmrc{'dircolors[*]'};
		$self->{dircolors}{$_} = {};
		while ($_pfmrc{"dircolors[$_]"} =~ /([^:=*]+)=([^:=]+)/g ) {
			$self->{dircolors}{$_}{$1} = $2;
		}
		$self->{framecolors}{$_} = {};
		# should there be no framecolors[thisname], use the default
		defined($_pfmrc{"framecolors[$_]"})
			or $_pfmrc{"framecolors[$_]"} = $_pfmrc{'framecolors[*]'};
		while ($_pfmrc{"framecolors[$_]"} =~ /([^:=*]+)=([^:=]+)/g ) {
			$self->{framecolors}{$_}{$1} = $2;
		}
	}
}

##########################################################################
# constructor, getters and setters

=item configfilename()

Getter/setter for the current filename of the F<.pfmrc> file.

=cut

sub configfilename {
	my ($self, $value) = @_;
	$_configfilename = $value if defined $value;
	return $_configfilename;
}

##########################################################################
# public subs

=item give_location()

Returns a message string for the user indicating which F<.pfmrc>
is currently being used.

=cut

sub give_location {
	my $self = shift;
	return "Configuration options will be read from \$PFMRC " .
		($ENV{PFMRC}
			? "($ENV{PFMRC})"
			: "or " . CONFIGDIRNAME . "/" . CONFIGFILENAME);
}

=item read()

Reads in the F<.pfmrc> file. If none exists, a default F<.pfmrc> is written.

=cut

sub read {
	my ($self, $read_first) = @_;
	%_pfmrc = ();
	unless (-r $_configfilename) {
		unless ($ENV{PFMRC} || -d CONFIGDIRNAME) {
			# create the directory only if $ENV{PFMRC} is not set
			mkdir CONFIGDIRNAME, CONFIGDIRMODE;
		}
		$self->write_default();
	}
	if (open PFMRC, $_configfilename) {
		while (<PFMRC>) {
			# the pragma 'locale' causes problems when the config
			# is read in using UTF-8
			no locale;
			if (/# Version ([\w.]+)$/ and
				$1 lt $_pfm->{VERSION} and $read_first)
			{
				# will not be in message color: usecolor not yet parsed
				$_pfm->screen->neat_error(
					"Warning: your $_configfilename version $1 may be "
				.	"outdated.\r\nPlease see pfm(1), under DIAGNOSIS."
				);
				$_pfm->screen->important_delay();
			}
			s/#.*//;
			if (s/\\\n?$//) { $_ .= <PFMRC>; redo; }
#			if (/^\s*([^:[\s]+(?:\[[^]]+\])?)\s*:\s*(.*)$/o) {
			if (/^[ \t]*([^: \t[]+(?:\[[^]]+\])?)[ \t]*:[ \t]*(.*)$/o) {
#				print STDERR "-$1";
				$_pfmrc{$1} = $2;
			}
		}
		close PFMRC;
	}
}

=item parse()

Processes the settings from the F<.pfmrc> file.

=cut

sub parse {
	my ($self, $show_copyright) = @_;
	my $state          = $_pfm->state;
	my $screen         = $_pfm->screen;
	my $diskinfo       = $screen->diskinfo;
	my $commandhandler = $_pfm->commandhandler;
	my $e;
	local $_;
	$self->{dircolors}     = {};
	$self->{framecolors}   = {};
	$self->{filetypeflags} = {};
	# 'usecolor' - find out when color must be turned _off_
	# we want to do this _now_ so that the copyright message is colored.
	if (defined($ENV{ANSI_COLORS_DISABLED}) or isno($_pfmrc{usecolor})) {
		$screen->colorizable(0);
	} elsif ($_pfmrc{usecolor} eq 'force') {
		$screen->colorizable(1);
	}
	# do 'cvvis' _now_ so that the copyright message shows the new cursor.
	system ('tput', $_pfmrc{cursorveryvisible} ? 'cvvis' : 'cnorm');
	# copyright message
	$self->_copyright($_pfmrc{copyrightdelay}) if $show_copyright;
	# time/date format for clock and timestamps
	$self->{clockdateformat}	= $_pfmrc{clockdateformat} || '%Y %b %d';
	$self->{clocktimeformat}	= $_pfmrc{clocktimeformat} || '%H:%M:%S';
	$self->{timestampformat}	= $_pfmrc{timestampformat} || '%y %b %d %H:%M';
	# Some configuration options are NOT fetched into class members
	# - however, they remain accessable in %_pfmrc.
	# Don't change settings back to the defaults if they may have
	# been modified by key commands.
	$self->{cursorveryvisible}	= isyes($_pfmrc{cursorveryvisible});
	$self->{clsonexit}			= isyes($_pfmrc{clsonexit});
	$self->{confirmquit}		= isyes($_pfmrc{confirmquit});
	$self->{waitlaunchexec}		= isyes($_pfmrc{waitlaunchexec});
	$self->{autowritehistory}	= isyes($_pfmrc{autowritehistory});
	$self->{autoexitmultiple}	= isyes($_pfmrc{autoexitmultiple});
	$self->{mouseturnoff}		= isyes($_pfmrc{mouseturnoff});
	$self->{swap_persistent}	= isyes($_pfmrc{persistentswap});
	$self->{trspace}			= isyes($_pfmrc{translatespace}) ? ' ' : '';
	$self->{dotdot_mode}		= isyes($_pfmrc{dotdotmode});
	$self->{autorcs}			= isyes($_pfmrc{autorcs});
	$self->{remove_marks_ok}	= isyes($_pfmrc{remove_marks_ok});
	$self->{clickiskeypresstoo}	= isyes($_pfmrc{clickiskeypresstoo} || 'yes');
	$self->{clobber_mode}		= ifnotdefined($commandhandler->clobber_mode,isyes($_pfmrc{defaultclobber}));
	$self->{path_mode}			= ifnotdefined($state->directory->path_mode, $_pfmrc{defaultpathmode} || 'log');
	$self->{currentlayout}		= ifnotdefined($screen->listing->layout,     $_pfmrc{defaultlayout}   ||  0);
	$self->{white_mode}			= ifnotdefined($state->{white_mode},         isyes($_pfmrc{defaultwhitemode}));
	$self->{dot_mode}			= ifnotdefined($state->{dot_mode},           isyes($_pfmrc{defaultdotmode}));
	$self->{sort_mode}			= ifnotdefined($state->{sort_mode},          $_pfmrc{defaultsortmode} || 'n');
	$self->{radix_mode}			= ifnotdefined($state->{radix_mode},         $_pfmrc{defaultradix}    || 'hex');
	$self->{ident_mode}			= ifnotdefined($diskinfo->ident_mode,
								  $diskinfo->IDENTMODES->{$_pfmrc{defaultident}} || 0);
	$self->{escapechar} = $e	= $_pfmrc{escapechar} || '=';
	$self->{ducmd}				= $_pfmrc{ducmd} || $DUCMDS{$^O} || $DUCMDS{default};
	$self->{ducmd}				=~ s/\$\{e\}/${e}/g;
	$self->{mouse_mode}			= $_pfm->browser->mouse_mode || $_pfmrc{defaultmousemode} || 'xterm';
	$self->{mouse_mode}			= ($self->{mouse_mode} eq 'xterm' && isxterm($ENV{TERM}))
								|| isyes($self->{mouse_mode});
	$self->{altscreen_mode}		= $_pfmrc{altscreenmode}    || 'xterm';
	$self->{altscreen_mode}		= ($self->{altscreen_mode}  eq 'xterm' && isxterm($ENV{TERM}))
								|| isyes($self->{altscreen_mode});
	$self->{chdirautocmd}		= $_pfmrc{chdirautocmd};
	$self->{windowcmd}			= $_pfmrc{windowcmd}
								|| ($^O eq 'linux' ? 'gnome-terminal -e' : 'xterm -e');
	$self->{printcmd}			= $_pfmrc{printcmd}
								|| ($ENV{PRINTER} ? "lpr -P$ENV{PRINTER} ${e}2" : "lpr ${e}2");
	$self->{showlockchar}		= ( $_pfmrc{showlock} eq 'sun' && $^O =~ /sun|solaris/i
								or isyes($_pfmrc{showlock}) ) ? 'l' : 'S';
	$self->{viewer}				= $_pfmrc{viewer} || 'xv';
	$self->{editor}				= $ENV{VISUAL} || $ENV{EDITOR}   || $_pfmrc{editor} || 'vi';
	$self->{pager}				= $ENV{PAGER}  || $_pfmrc{pager} || ($^O =~ /linux/i ? 'less' : 'more');
	# flags
	if (isyes($_pfmrc{filetypeflags})) {
		$self->{filetypeflags} = $screen->listing->FILETYPEFLAGS;
	} elsif ($_pfmrc{filetypeflags} eq 'dirs') {
		$self->{filetypeflags} = { d => $screen->listing->FILETYPEFLAGS->{d} };
	} else {
		$self->{filetypeflags} = {};
	}
	# split 'columnlayouts'
	$self->{columnlayouts} = [
		$_pfmrc{columnlayouts}
			? split(/:/, $_pfmrc{columnlayouts})
			:('* nnnnnnnnnnnnnnnnnnnnnnnnnnnssssssss mmmmmmmmmmmmmmmm pppppppppp ffffffffffffff'
			, '* nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnssssssss mmmmmmmmmmmmmmmm ffffffffffffff'
			, '* nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnssssssss uuuuuuuu pppppppppp ffffffffffffff')
	];
	$self->_parse_colorsets();
}

=item apply()

Propagates the settings from the F<.pfmrc> file to the application
and other classes.

=cut

sub apply {
	my $self = shift;
	my ($termkeys, $newcolormode);
	my $screen = $_pfm->screen;
	my $state  = $_pfm->state;
	# keymap, erase
	system ('stty', 'erase', $_pfmrc{erase}) if defined($_pfmrc{erase});
	$_pfm->history->keyboard->set_keymap($_pfmrc{keymap}) if $_pfmrc{keymap};
	# additional key definitions 'keydef'
	if ($termkeys = $_pfmrc{'keydef[*]'} .':'. $_pfmrc{"keydef[$ENV{TERM}]"}) {
		$termkeys =~ s/(\\e|\^\[)/\e/gi;
		# this does not allow colons (:) to appear in escape sequences!
		foreach (split /:/, $termkeys) {
			/^(\w+)=(.*)/ and $screen->def_key($1, $2);
		}
	}
	# determine color_mode if unset
	$newcolormode =
		(length($screen->color_mode)
			? $screen->color_mode
			: (defined($ENV{ANSI_COLORS_DISABLED})
				? 'off'
				: length($_pfmrc{defaultcolorset})
					? $_pfmrc{defaultcolorset}
					: (defined $self->{dircolors}{ls_colors}
						? 'ls_colors'
						: $self->{colorsetnames}[0])));
	# init colorsets, ornaments, ident, formatlines, enable mouse
	$screen->color_mode($newcolormode);
	$_pfm->history->setornaments($self->{framecolors}{$newcolormode}{message});
	$_pfm->commandhandler->clobber_mode($self->{clobber_mode});
	$screen->diskinfo->ident_mode($self->{ident_mode});
	$screen->listing->layout($self->{currentlayout});
	$screen->mouse_enable()	if $self->{mouse_mode};
	$screen->alternate_on()	if $self->{altscreen_mode};
	# hand variables over to the state
	$state->{dot_mode}         = $self->{dot_mode};
	$state->{radix_mode}       = $self->{radix_mode};
	$state->{sort_mode}        = $self->{sort_mode};
	$state->{white_mode}       = $self->{white_mode};
	$state->directory->path_mode($self->{path_mode});
}

=item write_default()

Writes a default config file in case none exists.

=cut

sub write_default {
	my ($self) = @_;
	my @resourcefile;
	my $secs_per_32_days = 60 * 60 * 24 * 32;
	my $maxdatelen = 0;
	my $version = $_pfm->{VERSION};
	local $_;
	# The default layouts assume that the default timestamp format
	# is 15 chars wide.
	# Find out if this is enough, taking the current locale into account.
	foreach (0 .. 11) {
		$maxdatelen = max($maxdatelen,
			length strftime("%b", gmtime($secs_per_32_days * $_)));
	}
	$maxdatelen -= 3;
	if (open MKPFMRC, ">$_configfilename") {
		# both __DATA__ and __END__ markers are used at the same time
		while (($_ = <DATA>) !~ /^__END__/) {
			s/^(##? Version )x/$1$version/m;
			if ($^O =~ /linux/i) {
				s{^(\s*(?:your\[[[:alpha:]]\]|launch\[[^]]+\])\s*:\s*\w+.*?\s+)more(\s*)$}
				 {$1less$2}mg;
			}
			if (/nnnnn/ and $maxdatelen) {
				s/([cma])/$1 x ($maxdatelen+1)/e &&
				s/nnnnn{$maxdatelen}/nnnn/;
			}
			print MKPFMRC;
		}
		close DATA;
		close MKPFMRC;
	} # no success? well, that's just too bad
}

##########################################################################

1;

__DATA__
##########################################################################
## Configuration file for Personal File Manager
## Version x
##
## Every option line in this file should have the form:
## [whitespace] option [whitespace]:[whitespace] value
## (whitespace is optional).
## The option itself may not contain whitespace or colons,
## except in a classifier enclosed in [] that immediately follows it.
## In other words: /^\s*([^:[\s]+(?:\[[^]]+\])?)\s*:\s*(.*)$/
## Everything following a # is regarded as a comment.
## Escapes may be entered as a real escape, as \e or as ^[ (caret, bracket).
## Lines may be continued on the next line by ending them in \ (backslash).
##
## Binary options may have yes/no, true/false, on/off, or 0/1 values.
## Some options can be set using environment variables.
## Your environment settings override the options in this file.

##########################################################################
## general

## use xterm alternate screen buffer (yes,no,xterm) (default: only in xterm)
altscreenmode:xterm

## should we exit from multiple file mode after executing a command?
autoexitmultiple:yes

## request rcs status automatically?
autorcs:yes

## write history files automatically upon exit
autowritehistory:no

## command to perform automatically after every chdir()
#chdirautocmd:printf "\033]0;pfm - $(basename $(pwd))\007"
#chdirautocmd:xtitle "pfm - $(hostname):$(pwd)"

## Must 'Hit any key to continue' also accept mouse clicks?
#clickiskeypresstoo:yes

## clock date/time format; see strftime(3).
## %x and %X provide properly localized time and date.
## the defaults are "%Y %b %d" and "%H:%M:%S"
## the diskinfo field (f) in the layouts below must be wide enough for this.
clockdateformat:%Y %b %d
clocktimeformat:%H:%M:%S
#clockdateformat:%x
#clocktimeformat:%X

## whether you want to have the screen cleared when pfm exits.
## No effect if altscreenmode is set.
clsonexit:no

## have pfm ask for confirmation when you press 'q'uit? (yes,no,marked)
## 'marked' = ask only if there are any marked files in the current directory
confirmquit:yes

## time to display copyright message at start (in seconds, fractions allowed)
## make pfm a lookalike to the DOS version :)
copyrightdelay:0.2

## use very visible cursor (e.g. block cursor on Linux console)
cursorveryvisible:yes

## initial setting for automatically clobbering existing files (toggle with !)
defaultclobber:no

## initial colorset to pick from the various colorsets defined below
## (cycle with F4)
defaultcolorset:dark

## show dot files initially? (hide them otherwise, toggle with . key)
defaultdotmode:yes

## initial ident mode (user, host, or user@host, cycle with = key)
defaultident:user

## initial layout to pick from the array 'columnlayouts' (see below)
## (cycle with F9)
defaultlayout:0

## initially turn on mouse support? (yes,no,xterm) (default: only in xterm)
## (toggle with F12)
defaultmousemode:xterm

## initially display logical or physical paths? (log,phys) (default: log)
## (toggle with ")
defaultpathmode:log

## initial radix that Name will use to display non-ascii chars with (hex,oct)
## (toggle with *)
defaultradix:hex

## initial sort mode (nNmMeEfFsSzZiItTdDaA) (default: n) (select with F6)
defaultsortmode:n

## show whiteout files initially? (hide them otherwise, toggle with % key)
defaultwhitemode:no

## '.' and '..' entries always at the top of the dirlisting?
dotdotmode:no

## your system's du(1) command (needs =2 for the current filename).
## specify so that the outcome is in bytes.
## this is commented out because pfm makes a clever guess for your OS.
#ducmd:du -sk =2 | awk '{ printf "%d", 1024 * $1 }'

## specify your favorite editor (don't specify =2 here).
## you can also use $EDITOR for this
editor:vi

## the erase character for your terminal (default: don't set)
#erase:^H

## the character that pfm recognizes as special abbreviation character
## (default =). Previous versions used \ but this leads to confusing results.
#escapechar:=
#escapechar:\

## display file type flags (yes, no, dirs)
## yes: 'ls -F' type, dirs: 'ls -p' type
filetypeflags:yes

## convert $LS_COLORS into an additional colorset?
importlscolors:yes

## additional key definitions for Term::Screen.
## it seems that Term::Screen needs these additions *badly*.
## if some (function) keys do not seem to work, add their escape sequences here.
## you may specify these by-terminal (make the option name 'keydef[$TERM]')
## or global ('keydef[*]')
## definitely look in the Term::Screen(3pm) manpage for details.
## also check 'kmous' from terminfo if your mouse is malfunctioning.
#keydef[vt100]:home=\e[1~:end=\e[4~:
keydef[*]:kmous=\e[M:home=\e[1~:end=\e[4~:end=\e[F:home=\eOH:end=\eOF:\
kl=\eOD:kd=\eOB:ku=\eOA:kr=\eOC:k1=\eOP:k2=\eOQ:k3=\eOR:k4=\eOS:\
pgdn=\e[62~:pgup=\e[63~:
# for gnome-terminal that handles F1 itself, you can enable shift-F1 with:
#k1=\eO1;2P:
# for gnome-terminal that handles F10 itself, you can enable shift-F10 with:
#k10=\e[21;2~:
# for gnome-terminal that handles F11 itself, you can enable shift-F11 with:
#k11=\e[23;2~:

## the keymap to use in readline (vi,emacs). (default emacs)
#keymap:vi

## turn off mouse support during execution of commands?
## caution: if you set this to 'no', your (external) commands (like $pager
## and $editor) will receive escape codes on mousedown events
mouseturnoff:yes

## your pager (don't specify =2 here). you can also use $PAGER
#pager:less

## F7 key swap path method is persistent? (default no)
persistentswap:yes

## your system's print command (needs =2 for current filename).
## if unspecified, the default is:
## if $PRINTER is set:   'lpr -P$PRINTER =2'
## if $PRINTER is unset: 'lpr =2'
#printcmd:lp -d$PRINTER =2

## suppress the prompt "OK to remove marks?"
#remove_marks_ok:no

## show whether mandatory locking is enabled (e.g. -rw-r-lr-- ) (yes,no,sun)
## 'sun' = show locking only on sunos/solaris
showlock:sun

## format for displaying timestamps: see strftime(3).
## take care that the time fields (a, c and m) in the layouts defined below
## should be wide enough for this string.
timestampformat:%y %b %d %H:%M
#timestampformat:%Y-%m-%d %H:%M:%S
#timestampformat:%b %d %H:%M
#timestampformat:%c
#timestampformat:%Y %V %a

## translate spaces when viewing Name
translatespace:no

## use color (yes,no,force) (may be overridden by ANSI_COLORS_DISABLED)
## 'no'    = use no color at all
## 'yes'   = use color if your terminal is thought to support it
## 'force' = use color on any terminal
## define your colorsets below ('framecolors' and 'dircolors')
usecolor:force

## preferred image editor/viewer (don't specify =2 here)
viewer:xv

## wait for launched executables to finish? (not implemented: will always wait)
waitlaunchexec:yes

## command used for starting a new pfm window for a directory.
## Only applicable under X. The default is to take gnome-terminal under
## Linux, xterm under other Unixes.
## Be sure to include the option to start a program in the window.
#windowcmd:gnome-terminal -e
#windowcmd:xterm -e

##########################################################################
## colors

## you may define as many different colorsets as you like.
## use the notation 'framecolors[colorsetname]' and 'dircolors[colorsetname]'.
## the F4 key will cycle through these colorsets.
## the special setname 'off' is used for no coloring.

## 'framecolors' defines the colors for menu, menu in multiple mode,
## headings, headings in swap mode, footer, messages, and the highlighted file.
## for the frame to become colored, 'usecolor' must be set to 'yes' or 'force'.

framecolors[light]:\
menu=white on blue:multi=reverse cyan on black:\
headings=reverse cyan on black:swap=reverse black on cyan:\
footer=reverse blue on white:message=blue:highlight=bold:

framecolors[dark]:\
menu=white on blue:multi=bold reverse cyan on white:\
headings=bold reverse cyan on white:swap=black on cyan:\
footer=bold reverse blue on white:message=bold cyan:highlight=bold:

## these are a suggestion
#framecolors[dark]:\
#menu=white on blue:multi=reverse cyan on black:\
#headings=reverse cyan on black:swap=reverse yellow on black:\
#footer=bold reverse blue on white:message=bold cyan:highlight=bold:

## 'dircolors' defines the colors that will be used for your files.
## for the files to become colored, 'usecolor' must be set to 'yes' or 'force'.
## see also the manpages for ls(1) and dircolors(1) (on Linux systems).
## if you have $LS_COLORS or $LS_COLOURS set, and 'importlscolors' above is set,
## an additional colorset called 'framecolors[ls_colors]' will be added.
## the special name 'framecolors[off]' is used for no coloring

##-file types:
## no=normal fi=file ex=executable lo=lost file ln=symlink or=orphan link
## di=directory bd=block special cd=character special pi=fifo so=socket
## do=door nt=network special (not implemented) wh=whiteout
## *.<ext> defines extension colors

dircolors[dark]:no=reset:fi=reset:ex=green:lo=bold black:di=bold blue:\
ln=bold cyan:or=white on red:\
bd=bold yellow on black:cd=bold yellow on black:\
pi=yellow on black:so=bold magenta:\
do=bold magenta:nt=bold magenta:wh=bold black on white:\
*.cmd=bold green:*.exe=bold green:*.com=bold green:*.btm=bold green:\
*.bat=bold green:*.pas=green:*.c=magenta:*.h=magenta:*.pm=cyan:*.pl=cyan:\
*.htm=bold yellow:*.phtml=bold yellow:*.html=bold yellow:*.php=yellow:\
*.tar=bold red:*.tgz=bold red:*.arj=bold red:*.taz=bold red:*.lzh=bold red:\
*.zip=bold red:*.rar=bold red:\
*.z=bold red:*.Z=bold red:*.gz=bold red:*.bz2=bold red:*.deb=red:*.rpm=red:\
*.pkg=red:*.jpg=bold magenta:*.gif=bold magenta:*.bmp=bold magenta:\
*.xbm=bold magenta:*.xpm=bold magenta:*.png=bold magenta:\
*.mpg=bold white:*.avi=bold white:*.gl=bold white:*.dl=bold white:

dircolors[light]:no=reset:fi=reset:ex=reset green:lo=bold black:di=bold blue:\
ln=underscore blue:or=white on red:\
bd=bold yellow on black:cd=bold yellow on black:\
pi=reset yellow on black:so=bold magenta:\
do=bold magenta:nt=bold magenta:wh=bold white on black:\
*.cmd=bold green:*.exe=bold green:*.com=bold green:*.btm=bold green:\
*.bat=bold green:*.pas=green:*.c=magenta:*.h=magenta:*.pm=on cyan:*.pl=on cyan:\
*.htm=black on yellow:*.phtml=black on yellow:*.html=black on yellow:\
*.php=black on yellow:
*.tar=bold red:*.tgz=bold red:*.arj=bold red:*.taz=bold red:*.lzh=bold red:\
*.zip=bold red:*.rar=bold red:\
*.z=bold red:*.Z=bold red:*.gz=bold red:*.bz2=bold red:*.deb=red:*.rpm=red:\
*.pkg=red:*.jpg=bold magenta:*.gif=bold magenta:*.bmp=bold magenta:\
*.xbm=bold magenta:*.xpm=bold magenta:*.png=bold magenta:\
*.mpg=bold white on blue:*.avi=bold white on blue:\
*.gl=bold white on blue:*.dl=bold white on blue:

## The special set 'framecolors[*]' will be used for every 'dircolors[x]'
## for which there is no corresponding 'framecolors[x]' (like ls_colors)

framecolors[*]:\
headings=reverse:swap=reverse:footer=reverse:highlight=bold:

## The special set 'dircolors[*]' will be used for every 'framecolors[x]'
## for which there is no corresponding 'dircolors[x]'

dircolors[*]:\
di=bold:ln=underscore:

##########################################################################
## column layouts

## char column name  mandatory?  needed character width if column present
## ---- -----------------------  ----------------------------------------------
## *    mark                yes  1
## n    filename            yes  variable length; last char == overflow flag
## s    filesize                 >=4; last char == power of 1024 (K, M, G..)
## z    grand total              >=4; last char == power of 1024 (K, M, G..)
## u    user                     >=8 (system-dependent)
## g    group                    >=8 (system-dependent)
## p    permissions              10
## a    access time              15 (using "%y %b %d %H:%M" if len(%b) == 3)
## c    change time              15 (using "%y %b %d %H:%M" if len(%b) == 3)
## m    modification time        15 (using "%y %b %d %H:%M" if len(%b) == 3)
## v    rcs(svn) info            >=4
## d    device                   5?
## i    inode                    >=7 (system-dependent)
## l    link count               >=5 (system-dependent)
## f    diskinfo            yes  >=14 (using clockformat, if len(%x) <= 14)

## take care not to make the fields too small or values will be cropped!
## if the terminal is resized, the filename field will be elongated.
## the diskinfo field *must* be the _first_ or _last_ field on the line.
## a final colon (:) after the last layout is allowed.
## the first three layouts were the old (pre-v1.72) defaults.

#<------------------------- file info -------------------------># #<-diskinfo->#
columnlayouts:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnsssssssss mmmmmmmmmmmmmmm pppppppppp ffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnsssssssss aaaaaaaaaaaaaaa pppppppppp ffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnssssssss uuuuuuuu gggggggglllll pppppppppp ffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnsssssss uuuuuuuu gggggggg pppppppppp ffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnuuuuuuuu gggggggg pppppppppp ffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnnnssssssss vvvv mmmmmmmmmmmmmmm pppppppppp ffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnzzzzzzzz mmmmmmmmmmmmmmm ffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsssssssss ffffffffffffff:\
pppppppppp uuuuuuuu gggggggg mmmmmmmmmmmmmmm sssssss* nnnnnnnnnnn ffffffffffffff:\
ppppppppppllll uuuuuuuu ggggggggssssssss mmmmmmmmmmmmmmm *nnnnnnn ffffffffffffff:

##########################################################################
## your commands

## in the defined commands, you may use the following escapes.
## these must NOT be quoted.
##  =1 : current filename without extension
##  =2 : current filename entirely
##  =3 : current directory path
##  =4 : current mountpoint
##  =5 : swap directory path (F7)
##  =6 : current directory basename
##  =7 : current filename extension
##  =8 : list of selected filenames
##  == : a single literal '='
##  =e : 'editor' (defined above)
##  =p : 'pager'  (defined above)
##  =v : 'viewer' (defined above)

your[a]:acroread =2 &
your[B]:bunzip2 =2
your[b]:xv -root +noresetroot +smooth -maxpect -quit =2
your[c]:tar cvf - =2 | gzip > =2.tar.gz
your[d]:uudecode =2
your[e]:unarj l =2 | =p
your[F]:fuser =2
your[f]:file =2
your[G]:gimp =2 &
your[g]:gvim =2
your[I]:svn ci =8
your[i]:rpm -qpi =2
your[j]:mpg123 =2 &
your[k]:esdplay =2
your[l]:mv -i =2 "$(echo =2 | tr '[:upper:]' '[:lower:]')"
your[M]:meld . =5 &
your[n]:nroff -man =2 | =p
your[o]:cp =2 =2.$(date +"%Y%m%d"); touch -r =2 =2.$(date +"%Y%m%d")
your[p]:perl -cw =2
your[q]:unzip -l =2 | =p
your[r]:rpm -qpl =2 | =p
your[S]:shar =2 > =2.shar
your[s]:strings =2 | =p
your[t]:gunzip < =2 | tar tvf - | =p
your[U]:unzip =2
your[u]:gunzip =2
your[V]:gv =2 &
your[v]:xv =2 &
your[w]:what =2
your[x]:gunzip < =2 | tar xvf -
your[y]:lynx =2
your[Z]:bzip2 =2
your[z]:gzip =2

##########################################################################
## launch commands

## how should pfm try to determine the file type? by its magic (using file(1)),
## by extension, should we try to run it as an executable if the 'x' bit is set,
## or should we prefer one method and fallback on another one?
## allowed values: combinations of 'xbit', 'extension' and 'magic'
launchby:extension,xbit
#launchby:extension,xbit,magic

## the file type names do not have to be valid MIME types
extension[*.1m]   : application/x-nroff-man
extension[*.1]    : application/x-nroff-man
extension[*.3i]   : application/x-intercal
extension[*.i]    : application/x-intercal
extension[*.bf]   : application/x-befunge
extension[*.Z]    : application/x-compress
extension[*.arj]  : application/x-arj
extension[*.au]   : audio/basic
extension[*.avi]  : video/x-msvideo
extension[*.bat]  : application/x-msdos-batch
extension[*.bin]  : application/octet-stream
extension[*.bmp]  : image/x-ms-bitmap
extension[*.bz2]  : application/x-bzip2
extension[*.c]    : application/x-c
extension[*.cmd]  : application/x-msdos-batch
extension[*.com]  : application/x-executable
extension[*.css]  : text/css
extension[*.deb]  : application/x-deb
extension[*.doc]  : application/x-ms-office
extension[*.docx] : application/x-ms-office
extension[*.dll]  : application/octet-stream
extension[*.dvi]  : application/x-dvi
extension[*.eps]  : application/postscript
extension[*.exe]  : application/x-executable
extension[*.gif]  : image/gif
extension[*.gz]   : application/x-gzip
extension[*.htm]  : text/html
extension[*.html] : text/html
extension[*.jar]  : application/zip
extension[*.jpeg] : image/jpeg
extension[*.jpg]  : image/jpeg
extension[*.json] : application/json
extension[*.lzh]  : application/x-lha
extension[*.mid]  : audio/midi
extension[*.midi] : audio/midi
extension[*.mov]  : video/quicktime
extension[*.man]  : application/x-groff-man
extension[*.mm]   : application/x-groff-mm
extension[*.mp2]  : audio/mpeg
extension[*.mp3]  : audio/mpeg
extension[*.mpeg] : video/mpeg
extension[*.mpg]  : video/mpeg
extension[*.odp]  : application/x-openoffice
extension[*.ods]  : application/x-openoffice
extension[*.odt]  : application/x-openoffice
extension[*.p]    : application/x-chem
extension[*.pas]  : application/x-pascal
extension[*.pdb]  : chemical/x-pdb
extension[*.pdf]  : application/pdf
extension[*.php]  : text/x-php
extension[*.phtml]: text/x-php
extension[*.pps]  : application/x-ms-office
extension[*.ppt]  : application/x-ms-office
extension[*.pptx] : application/x-ms-office
extension[*.pl]   : application/x-perl
extension[*.pm]   : application/x-perl-module
extension[*.png]  : image/png
extension[*.ps]   : application/postscript
extension[*.qt]   : video/quicktime
extension[*.ra]   : audio/x-realaudio
extension[*.ram]  : audio/x-pn-realaudio
extension[*.rar]  : application/x-rar
extension[*.rpm]  : application/x-rpm
extension[*.tar]  : application/x-tar
extension[*.taz]  : application/x-tar-compress
extension[*.tgz]  : application/x-tar-gzip
extension[*.tif]  : image/tiff
extension[*.tiff] : image/tiff
extension[*.txt]  : text/plain
extension[*.uue]  : application/x-uuencoded
extension[*.wav]  : audio/x-wav
extension[*.wmv]  : video/x-winmedia
extension[*.xcf]  : image/x-gimp
extension[*.xbm]  : image/x-xbitmap
extension[*.xls]  : application/x-ms-office
extension[*.xlsx] : application/x-ms-office
extension[*.xml]  : application/xml
extension[*.xpm]  : image/x-xpixmap
extension[*.xwd]  : image/x-xwindowdump
extension[*.ync]  : application/x-yencoded
extension[*.yml]  : application/x-yaml
extension[*.z]    : application/x-compress
extension[*.zip]  : application/zip

## these will search by regular expression in the file(1) output
magic[ASCII English text]   : text/plain
magic[C\+?\+? program text] : application/x-c
magic[GIF image data]       : image/gif
magic[HTML document text]   : text/html
magic[JPEG image data]      : image/jpeg
magic[MP3]                  : audio/mpeg
magic[MS Windows.*executab] : application/x-executable
magic[MS-DOS.*executable]   : application/x-executable
magic[Microsoft ASF]        : application/x-ms-office
magic[Microsoft Office.*]   : application/x-ms-office
magic[PC bitmap.*Windows]   : image/x-ms-bitmap
magic[PDF document]         : application/pdf
magic[PNG image data]       : image/png
magic[PostScript document]  : application/postscript
magic[RAR archive]          : application/x-rar
magic[RIFF.*data, AVI]      : video/x-msvideo
magic[RPM]                  : application/x-rpm
magic[Sun.NeXT audio data]  : audio/basic
magic[TeX DVI file]         : application/x-dvi
magic[TIFF image data]      : image/tiff
magic[WAVE audio]           : audio/x-wav
magic[X pixmap image]       : image/x-xpixmap
magic[XWD X-Windows Dump]   : image/x-xwindowdump
magic[Zip archive data]     : application/zip
magic[bzip2 compressed data]: application/x-bzip2
magic[compress.d data]      : application/x-compress
magic[gzip compressed data] : application/x-gzip
magic[perl script]          : application/x-perl
magic[tar archive]          : application/x-tar

launch[application/json]          : =e =2
launch[application/octet-stream]  : =p =2
launch[application/pdf]           : acroread =2 &
#launch[application/pdf]           : evince =2 &
launch[application/postscript]    : gv =2 &
launch[application/x-arj]         : unarj x =2
launch[application/x-befunge]     : mtfi =2
launch[application/x-bzip2]       : bunzip2 =2
launch[application/x-c]           : gcc -o =1 =2
launch[application/x-chem]        : chem =2|groff -pteR -mm > =1.ps; gv =1.ps &
launch[application/x-compress]    : uncompress =2
launch[application/x-intercal]    : ick =2
launch[application/x-deb]         : dpkg -L =2
launch[application/x-dvi]         : xdvi =2 &
launch[application/x-executable]  : wine =2 &
launch[application/x-groff-man]	  : groff -pteR -man =2 > =1.ps; gv =1.ps &
launch[application/x-groff-mm]	  : groff -pteR -mm  =2 > =1.ps; gv =1.ps &
launch[application/x-gzip]        : gunzip =2
#launch[application/x-lha]         :
launch[application/x-msdos-batch] : =e =2
launch[application/x-ms-office]   : ooffice =2 &
launch[application/x-openoffice]  : ooffice =2 &
launch[application/x-nroff-man]	  : nroff -p -t -e -man =2 | =p
launch[application/x-pascal]      : =e =2
launch[application/x-perl-module] : =e =2
launch[application/x-perl]        : ./=2
launch[application/x-rar]         : unrar x =2
#launch[application/x-rpm]         : rpm -Uvh =2
launch[application/x-rpm]         : rpm -qpl =2
#launch[application/x-tar-compress]: uncompress < =2 | tar xvf -
launch[application/x-tar-compress]: uncompress < =2 | tar tvf -
#launch[application/x-tar-gzip]    : gunzip < =2 | tar xvf -
launch[application/x-tar-gzip]    : gunzip < =2 | tar tvf -
#launch[application/x-tar]         : tar xvf =2
launch[application/x-tar]         : tar tvf =2
launch[application/x-uuencoded]   : uudecode =2
launch[application/x-yaml]        : =e =2
launch[application/x-yencoded]    : ydecode =2
launch[application/xml]           : firefox =2 &
launch[application/zip]           : unzip =2
launch[audio/basic]               : esdplay =2 &
launch[audio/midi]                : timidity =2 &
launch[audio/mpeg]                : mpg123 =2 &
launch[audio/x-pn-realaudio]      : realplay =2 &
launch[audio/x-realaudio]         : realplay =2 &
launch[audio/x-wav]               : esdplay =2 &
launch[chemical/x-pdb]            : molecule -molecule =2 &
launch[image/gif]                 : =v =2 &
launch[image/jpeg]                : =v =2 &
launch[image/png]                 : =v =2 &
launch[image/tiff]                : =v =2 &
launch[image/x-gimp]              : gimp =2 &
launch[image/x-ms-bitmap]         : =v =2 &
launch[image/x-xbitmap]           : =v =2 &
launch[image/x-xpixmap]           : =v =2 &
launch[image/x-xwindowdump]       : =v =2 &
launch[text/css]                  : =e =2
launch[text/html]                 : lynx =2
launch[text/plain]                : =e =2
launch[text/x-php]                : =e =2
launch[video/mpeg]                : xine =2 &
#launch[video/quicktime]           :
launch[video/x-msvideo]           : divxPlayer =2 &

## vim: set filetype=xdefaults: # fairly close
__END__

=back

=head1 SEE ALSO

pfm(1).

=cut

# vim: set tabstop=4 shiftwidth=4:
