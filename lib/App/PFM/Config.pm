#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Config 0.94
#
# Name:			App::PFM::Config
# Version:		0.94
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-09-03
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

use App::PFM::Config::Update;
use App::PFM::Util qw(isyes isno isxterm ifnotdefined);
use App::PFM::Event;

use POSIX qw(strftime mktime);

use strict;

use constant {
	READ_AGAIN		 => 0,
	READ_FIRST		 => 1,
	NO_COPYRIGHT	 => 0,
	SHOW_COPYRIGHT	 => 1,
	CONFIGDIRNAME	 => "$ENV{HOME}/.pfm",
	CONFIGFILENAME	 => '.pfmrc',
	CONFIGDIRMODE	 => 0700,
	BOOKMARKFILENAME => 'bookmarks',
};

our ($_pfm);

##########################################################################
# private subs

=item _init(App:PFM::Application $pfm)

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm = $pfm;
	$self->{_pfmrc} = {};
	$self->{_text}  = [];
	$self->{_configfilename} = $self->location();
}

=item _parse_colorsets()

Parses the colorsets defined in the F<.pfmrc>.

=cut

sub _parse_colorsets {
	my ($self) = @_;
	my $pfmrc = $self->{_pfmrc};
	if (isyes($pfmrc->{importlscolors}) and $ENV{LS_COLORS} || $ENV{LS_COLOURS}){
		$pfmrc->{'dircolors[ls_colors]'} =  $ENV{LS_COLORS} || $ENV{LS_COLOURS};
	}
	$pfmrc->{'dircolors[off]'}   = '';
	$pfmrc->{'framecolors[off]'} =
		'headings=reverse:swap=reverse:footer=reverse:highlight=bold:';
	# this %{{ }} construct keeps values unique
	$self->{colorsetnames} = [
		keys %{{
			map { /\[(\w+)\]/; $1, '' }
			grep { /^(dir|frame)colors\[[^*]/ } keys(%$pfmrc)
		}}
	];
	# keep the default outside of @colorsetnames
	defined($pfmrc->{'dircolors[*]'})   or $pfmrc->{'dircolors[*]'}   = '';
	defined($pfmrc->{'framecolors[*]'}) or $pfmrc->{'framecolors[*]'} =
		'menu=white on blue:multi=bold reverse cyan on white:'
	.	'headings=bold reverse cyan on white:swap=reverse black on cyan:'
	.	'footer=bold reverse blue on white:message=bold cyan:highlight=bold:';
	foreach (@{$self->{colorsetnames}}) {
		# should there be no dircolors[thisname], use the default
		defined($pfmrc->{"dircolors[$_]"})
			or $pfmrc->{"dircolors[$_]"} = $pfmrc->{'dircolors[*]'};
		$self->{dircolors}{$_} = {};
		while ($pfmrc->{"dircolors[$_]"} =~ /([^:=*]+)=([^:=]+)/g ) {
			$self->{dircolors}{$_}{$1} = $2;
		}
		$self->{framecolors}{$_} = {};
		# should there be no framecolors[thisname], use the default
		defined($pfmrc->{"framecolors[$_]"})
			or $pfmrc->{"framecolors[$_]"} = $pfmrc->{'framecolors[*]'};
		while ($pfmrc->{"framecolors[$_]"} =~ /([^:=*]+)=([^:=]+)/g ) {
			$self->{framecolors}{$_}{$1} = $2;
		}
	}
}

##########################################################################
# constructor, getters and setters

=item configfilename( [ string $filename ] )

Getter/setter for the current filename of the F<.pfmrc> file.

=cut

sub configfilename {
	my ($self, $value) = @_;
	$self->{_configfilename} = $value if defined $value;
	return $self->{_configfilename};
}

=item pfmrc( [ hashref $pfmrc ] )

Getter/setter for the _pfmrc member variable holding the config options.

=cut

sub pfmrc {
	my ($self, $value) = @_;
	$self->{_pfmrc} = $value if defined $value;
	return $self->{_pfmrc};
}

=item text( [ arrayref $lines ] )

Getter/setter for the member variable holding the unparsed text
of the config file.

=cut

sub text {
	my ($self, $value) = @_;
	$self->{_text} = $value if defined $value;
	return $self->{_text};
}

=item your_commands()

Getter for the keys of the Your commands in the config file.

=cut

sub your_commands {
	my ($self) = @_;
	my @your = # map { $_, $self->{_pfmrc}{$_} }
				grep /^your\[[[:alpha:]]\]$/, keys %{$self->{_pfmrc}};
	return @your;
}

##########################################################################
# public subs

=item location()

Returns a message string for the user indicating which F<.pfmrc>
is currently being used.

=cut

sub location {
#	my ($self) = @_;
	return ($ENV{PFMRC} ? $ENV{PFMRC} : CONFIGDIRNAME . "/" . CONFIGFILENAME);
}

=item read(bool $firstread)

Reads in the F<.pfmrc> file. If none exists, a default F<.pfmrc> is written.
The I<firstread> variable ensures that the message "Your config file may
be outdated" is given only once.

=cut

sub read {
	my ($self, $read_first) = @_;
	my ($pfmrc_version, $updater);
	my $screen = $_pfm->screen;
	READ_ATTEMPT: {
		$self->{_pfmrc} = {};
		$self->{_text}  = [];
		unless (-r $self->{_configfilename}) {
			unless ($ENV{PFMRC} || -d CONFIGDIRNAME) {
				# create the directory only if $ENV{PFMRC} is not set
				mkdir CONFIGDIRNAME, CONFIGDIRMODE;
			}
			$self->write_default();
		}
		if (open PFMRC, $self->{_configfilename}) {
			$self->{_text} = [ <PFMRC> ];
			seek(PFMRC, 0, 0); # rewind
			while (<PFMRC>) {
				if (/#\s*Version\D+([[:alnum:].]+)$/) {
					$pfmrc_version = $1;
					next;
				}
				s/#.*//;
				if (s/\\\n?$//) { $_ .= <PFMRC>; redo; }
#				if (/^\s*([^:[\s]+(?:\[[^]]+\])?)\s*:\s*(.*)$/o) {
				if (/^[ \t]*([^: \t[]+(?:\[[^]]+\])?)[ \t]*:[ \t]*(.*)$/o) {
#					print STDERR "-$1";
					$self->{_pfmrc}{$1} = $2;
				}
			}
			close PFMRC;
			if (!defined $pfmrc_version) {
				# will not be in message color: usecolor not yet parsed
				$screen->neat_error(
					"Warning: the version of your $self->{_configfilename}\r\n"
				.	"could not be determined. Please see pfm(1), under DIAGNOSIS."
				);
				$screen->important_delay();
			} elsif ($pfmrc_version lt $_pfm->{VERSION} and $read_first) {
				# will not be in message color: usecolor not yet parsed
				$screen->neat_error(
					"Warning: your $self->{_configfilename} version $pfmrc_version"
				.	"\r\nmay be too old for this version of pfm ($_pfm->{VERSION})."
				.	"\r\nDo you want me to backup this config file and update it "
				.	"now (y/n)? ");
				return if (lc $screen->getch() ne 'y');
				$screen->puts("\r\n");
				if (!$self->backup()) {
					$screen->puts(
						"Could not backup your config file, aborting update");
					$screen->important_delay();
					return;
				}
				$screen->cooked_echo();
				$updater = new App::PFM::Config::Update();
				$updater->update(
					$pfmrc_version, $_pfm->{VERSION}, $self->{_text});
				$self->write_text();
				$screen->raw_noecho();
				redo READ_ATTEMPT;
			} # if !defined($version) or $version lt $pfm_version
		} # if open()
	} # READ_ATTEMPT
}

=item parse()

Processes the settings from the F<.pfmrc> file.
Most options are fetched into member variables. Those that aren't,
remain accessable in the hash member C<$config-E<gt>{_pfmrc}>.

=cut

sub parse {
	my ($self) = @_;
	my $state          = $_pfm->state;
	my $screen         = $_pfm->screen;
	my $diskinfo       = $screen->diskinfo;
	my $commandhandler = $_pfm->commandhandler;
	my $pfmrc          = $self->{_pfmrc};
	my $e;
	local $_;
	$self->{dircolors}     = {};
	$self->{framecolors}   = {};
	$self->{filetypeflags} = {};
	# 'usecolor' - find out when color must be turned _off_
	# we want to do this _now_ so that the copyright message is colored.
	if (defined($ENV{ANSI_COLORS_DISABLED}) or isno($pfmrc->{usecolor})) {
		$screen->colorizable(0);
	} elsif ($pfmrc->{usecolor} eq 'force') {
		$screen->colorizable(1);
	}
	# copyright message
	$self->fire(new App::PFM::Event({
		name   => 'after_parse_usecolor',
		origin => $self, # not used ATM
		type   => 'soft',
	}));
	# time/date format for clock and timestamps
	$self->{clockdateformat}	= $pfmrc->{clockdateformat} || '%Y %b %d';
	$self->{clocktimeformat}	= $pfmrc->{clocktimeformat} || '%H:%M:%S';
	$self->{timestampformat}	= $pfmrc->{timestampformat} || '%y %b %d %H:%M';
	$self->{mousewheeljumpsize}	= $pfmrc->{mousewheeljumpsize}  || 'variable';
	$self->{mousewheeljumpmin}	= $pfmrc->{mousewheeljumpmin}   || 1;
	$self->{mousewheeljumpmax}	= $pfmrc->{mousewheeljumpmax}   || 10;
	$self->{mousewheeljumpratio}= $pfmrc->{mousewheeljumpratio} || 4;
	$self->{launchby}			= $pfmrc->{launchby};
	$self->{copyoptions}		= $pfmrc->{copyoptions};
	# Don't change settings back to the defaults if they may have
	# been modified by key commands.
	$self->{cursorveryvisible}	= isyes($pfmrc->{cursorveryvisible});
	$self->{clsonexit}			= isyes($pfmrc->{clsonexit});
	$self->{confirmquit}		= isyes($pfmrc->{confirmquit});
	$self->{autowritehistory}	= isyes($pfmrc->{autowritehistory});
	$self->{autowritebookmarks}	= isyes($pfmrc->{autowritebookmarks});
	$self->{autoexitmultiple}	= isyes($pfmrc->{autoexitmultiple});
	$self->{mouseturnoff}		= isyes($pfmrc->{mouseturnoff});
	$self->{highlightname}		= isyes($pfmrc->{highlightname} || 'yes');
	$self->{swap_persistent}	= isyes($pfmrc->{persistentswap} || 'yes');
	$self->{autosort}			= isyes($pfmrc->{autosort} || 'yes');
	$self->{trspace}			= isyes($pfmrc->{translatespace}) ? ' ' : '';
	$self->{dotdot_mode}		= isyes($pfmrc->{dotdotmode});
	$self->{autorcs}			= isyes($pfmrc->{autorcs});
	$self->{remove_marks_ok}	= isyes($pfmrc->{remove_marks_ok});
	$self->{clickiskeypresstoo}	= isyes($pfmrc->{clickiskeypresstoo} || 'yes');
	$self->{clobber_mode}		= ifnotdefined($commandhandler->clobber_mode,isyes($pfmrc->{defaultclobber}));
	$self->{path_mode}			= ifnotdefined($state->directory->path_mode, $pfmrc->{defaultpathmode} || 'log');
	$self->{currentlayout}		= ifnotdefined($screen->listing->layout,     $pfmrc->{defaultlayout}   ||  0);
	$self->{white_mode}			= ifnotdefined($state->{white_mode},         isyes($pfmrc->{defaultwhitemode}));
	$self->{dot_mode}			= ifnotdefined($state->{dot_mode},           isyes($pfmrc->{defaultdotmode}));
	$self->{sort_mode}			= ifnotdefined($state->sort_mode,            $pfmrc->{defaultsortmode} || 'n');
	$self->{radix_mode}			= ifnotdefined($state->{radix_mode},         $pfmrc->{defaultradix}    || 'hex');
	$self->{ident_mode}			= ifnotdefined($diskinfo->ident_mode,
								  $diskinfo->IDENTMODES->{$pfmrc->{defaultident}} || 0);
	$self->{escapechar} =
	$self->{e}			= $e	= $pfmrc->{escapechar} || '=';
	$self->{sortcycle}			= $pfmrc->{sortcycle} || 'nNeEdDaAsStu';
	$self->{force_minimum_size}	= $pfmrc->{force_minimum_size} || 'xterm';
	$self->{force_minimum_size}	= ($self->{force_minimum_size} eq 'xterm' && isxterm($ENV{TERM}))
								|| isyes($self->{force_minimum_size});
	$self->{mouse_mode}			= $_pfm->browser->mouse_mode || $pfmrc->{defaultmousemode} || 'xterm';
	$self->{mouse_mode}			= ($self->{mouse_mode} eq 'xterm' && isxterm($ENV{TERM}))
								|| isyes($self->{mouse_mode});
	$self->{altscreen_mode}		= $pfmrc->{altscreenmode} || 'xterm';
	$self->{altscreen_mode}		= ($self->{altscreen_mode}  eq 'xterm' && isxterm($ENV{TERM}))
								|| isyes($self->{altscreen_mode});
	$self->{chdirautocmd}		= $pfmrc->{chdirautocmd};
	$self->{windowtype}			= $pfmrc->{windowtype} eq 'standalone' ? 'standalone' : 'pfm';
	$self->{windowcmd}			= $pfmrc->{windowcmd}
								|| ($pfmrc->{windowtype} eq 'standalone'
									? 'nautilus'
									: $^O eq 'linux' ? 'gnome-terminal -e' : 'xterm -e');
	$self->{printcmd}			= $pfmrc->{printcmd}
								|| ($ENV{PRINTER} ? "lpr -P$ENV{PRINTER} ${e}2" : "lpr ${e}2");
	$self->{showlockchar}		= ( $pfmrc->{showlock} eq 'sun' && $^O =~ /sun|solaris/i
								or isyes($pfmrc->{showlock}) ) ? 'l' : 'S';
	$self->{viewer}				= $pfmrc->{viewer} || 'xv';
	$self->{editor}				= $ENV{VISUAL} || $ENV{EDITOR}   || $pfmrc->{editor} || 'vi';
	$self->{fg_editor}			= $pfmrc->{fg_editor} || $self->{editor};
	$self->{pager}				= $ENV{PAGER}  || $pfmrc->{pager} || ($^O =~ /linux/i ? 'less' : 'more');
	# flags
	if (isyes($pfmrc->{filetypeflags})) {
		$self->{filetypeflags} = $screen->listing->FILETYPEFLAGS;
	} elsif ($pfmrc->{filetypeflags} eq 'dirs') {
		$self->{filetypeflags} = { d => $screen->listing->FILETYPEFLAGS->{d} };
	} else {
		$self->{filetypeflags} = {};
	}
	# split 'columnlayouts'
	$self->{columnlayouts} = [
		$pfmrc->{columnlayouts}
			? split(/:/, $pfmrc->{columnlayouts})
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
	my ($self) = @_;
	my ($termkeys, $newcolormode);
	my $screen = $_pfm->screen;
	my $state  = $_pfm->state;
	my $pfmrc  = $self->{_pfmrc};
	# make cursor very visible
	system ('tput', $pfmrc->{cursorveryvisible} ? 'cvvis' : 'cnorm');
	# keymap, erase
	system ('stty', 'erase', $pfmrc->{erase}) if defined($pfmrc->{erase});
	$_pfm->history->keyboard->set_keymap($pfmrc->{keymap}) if $pfmrc->{keymap};
	# additional key definitions 'keydef'
	if ($termkeys = $pfmrc->{'keydef[*]'} .':'. $pfmrc->{"keydef[$ENV{TERM}]"}) {
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
				: length($pfmrc->{defaultcolorset})
					? $pfmrc->{defaultcolorset}
					: (defined $self->{dircolors}{ls_colors}
						? 'ls_colors'
						: $self->{colorsetnames}[0])));
	# init colorsets, ornaments, ident, formatlines, enable mouse
	$screen->color_mode($newcolormode);
	$_pfm->history->setornaments($self->{framecolors}{$newcolormode}{message});
	$_pfm->commandhandler->clobber_mode($self->{clobber_mode});
	$_pfm->browser->mouse_mode($self->{mouse_mode});
	$screen->diskinfo->ident_mode($self->{ident_mode});
	$screen->listing->layout($self->{currentlayout});
	$screen->set_deferred_refresh($screen->R_ALTERNATE);
	$state->sort_mode($self->{sort_mode});
	# hand variables over to the state
	$state->{dot_mode}         = $self->{dot_mode};
	$state->{radix_mode}       = $self->{radix_mode};
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
	my $version    = $_pfm->{VERSION};
	local $_;
	# The default layouts assume that the default timestamp format
	# is 15 chars wide.
	# Find out if this is enough, taking the current locale into account.
	foreach (0 .. 11) {
		$maxdatelen = max($maxdatelen,
			length strftime("%b", gmtime($secs_per_32_days * $_)));
	}
	$maxdatelen -= 3;
	if (open MKPFMRC, ">$self->{_configfilename}") {
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

=item backup()

Creates a backup of the current config file, I<e.g.>
F<.pfmrc.20100901T231201>.

=cut

sub backup {
	my ($self) = @_;
	my $now    = strftime('%Y%m%dT%H%M%S', localtime);
	# quotemeta($now) as well: it may be tainted (determined by locale).
	my $result = system("cp \Q$self->{_configfilename}\E \Q$self->{_configfilename}.$now\E");
	return !$result;
}

=item write_text()

Creates a new config file by writing the raw text to it.

=cut

sub write_text {
	my ($self) = @_;
	open MKPFMRC, ">$self->{_configfilename}" or return 0;
	print MKPFMRC @{$self->{_text}};
	close MKPFMRC or return 0;
	return 1;
}

=item read_bookmarks()

Reads the bookmarks file.
Fails silently if the bookmarks file cannot be read.

=cut

sub read_bookmarks {
	my ($self) = @_;
	my %bookmarks = ();
	if (open BOOKMARKS, CONFIGDIRNAME . "/" . BOOKMARKFILENAME) {
		while (<BOOKMARKS>) {
			# wrapping lines (ending in '\') are not allowed
			s/#.*//;
			if (/^[ \t]*bookmark\[(.)\][ \t]*:[ \t]*(.*)$/o) {
				$bookmarks{$1} = $2;
			}
		}
		close BOOKMARKS;
	} # fail silently
	return %bookmarks;
}

=item write_bookmarks( [ bool $finishing ] )

Writes the states to the bookmarks file.
Reports an error if the bookmarks file cannot be written.

The argument I<finishing> indicates that the final message
should be shown without delay.

=cut

sub write_bookmarks {
	my ($self, $finishing) = @_;
	my ($state, $path);
	my $screen = $_pfm->screen;
	unless ($finishing) {
		$screen->at(0,0)->clreol()
			->set_deferred_refresh($screen->R_MENU);
	}
	unless (open BOOKMARKS, ">" . CONFIGDIRNAME . "/" . BOOKMARKFILENAME) {
		$screen->display_error("Error writing bookmarks: $!");
		return;
	}
	print BOOKMARKS '#' x 74, "\n## bookmarks for pfm\n\n";
	foreach (@{$_pfm->BOOKMARKKEYS}) {
		next if /../;
		$state = $_pfm->state($_);
		if (ref $state) {
			$path = $state->directory->path;
			if ($state->{_position}) {
				$path .= '/' . $state->{_position};
			}
		} else {
			$path = $state;
		}
		print BOOKMARKS "bookmark[$_]:$path\n";
	}
	print BOOKMARKS "\n## vim: set filetype=xdefaults:\n";
	unless (close BOOKMARKS) {
		$screen->display_error("Error writing bookmarks: $!");
		return;
	}
	$screen->putmessage(
		'Bookmarks written successfully' . ($finishing ? "\n" : ''));
	unless ($finishing) {
		$screen->error_delay();
	}
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

## automatically sort the directory's contents again after a
## (T)ime or (U)ser command? (default: yes)
#autosort:yes

## write bookmarks to file automatically upon exit
autowritebookmarks:yes

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
## Has no effect if altscreenmode is set.
clsonexit:no

## In case the regular editor automatically forks in the background, you
## may want to specify a foreground editor here. If defined, this editor
## will be used for editing the config file, so that pfm will be able to
## wait for the editor to finish before rereading the config file.
## It will also be used for editing ACLs.
#fg_editor:vim

## have pfm ask for confirmation when you press 'q'uit? (yes,no,marked)
## 'marked' = ask only if there are any marked files in the current directory
confirmquit:yes

## commandline options to add to the cp(1) command, in the first place for
## changing the 'follow symlinks' behavior.
#copyoptions:-L
#copyoptions:-P

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

## initial sort mode (nNmMeEfFdDaAsSzZtTuUgGvViI*) (default: n)
## (select with F6)
defaultsortmode:n

## show whiteout files initially? (hide them otherwise, toggle with % key)
defaultwhitemode:no

## '.' and '..' entries always at the top of the dirlisting?
dotdotmode:no

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

## pfm does not support a terminal size of less than 80 columns or 24 rows.
## this option will make pfm try to resize the terminal to the minimum
## dimensions if it is resized too small.
## valid options: yes,no,xterm.
force_minimum_size:xterm

## overlay the highlight color onto the current filename? (default yes)
highlightname:yes

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

## characteristics of the mouse wheel: the number of lines that the
## mouse wheel will scroll. This can be an integer or 'variable'.
#mousewheeljumpsize:5
mousewheeljumpsize:variable

## if 'mousewheeljumpsize' is 'variable', the next two values are taken
## into account.
## 'mousewheeljumpratio' is used to calculate the number of lines that
## the cursor will jump, namely: the total number of enties in the
## directory divided by 'mousewheeljumpratio'.
## 'mousewheeljumpmin' and 'mousewheeljumpmax' set bounds to the number
## of lines that the cursor is allowed to jump when using the mousewheel.
mousewheeljumpratio:4
mousewheeljumpmin:1
mousewheeljumpmax:11

## your pager (don't specify =2 here). you can also use $PAGER
#pager:less

## F7 key swap path method is persistent? (default yes)
#persistentswap:no

## your system's print command (needs =2 for current filename).
## if unspecified, the default is:
## if $PRINTER is set:   'lpr -P$PRINTER =2'
## if $PRINTER is unset: 'lpr =2'
#printcmd:lp -d$PRINTER =2

## is it always "OK to remove marks?" without confirmation?
#remove_marks_ok:no

## show whether mandatory locking is enabled (e.g. -rw-r-lr-- ) (yes,no,sun)
## 'sun' = show locking only on sunos/solaris
showlock:sun

## sort modes to cycle through when clicking 'Sort' in the footer.
## default: nNeEdDaAsStu
#sortcycle:nNeEdDaAsStu

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
#viewer:xv
viewer:eog

## Command used for starting a new directory window. Only useful under X.
##
## If 'windowtype' is 'standalone', then this command will be started
## and the current directory will be passed on the commandline.
## The command is responsible for opening its own window.
##
## If 'windowtype' is 'pfm', then 'windowcmd' should be a terminal
## command, which will be used to start pfm (the default is to use
## gnome-terminal for linux and xterm for other Unices).
## Be sure to include the option to start a program in the window
## (for xterm, this is -e).
##
#windowcmd:gnome-terminal -e
#windowcmd:xterm -e
#windowcmd:nautilus

## What to open when a directory is middle-clicked with the mouse?
## 'pfm'       : open directories with pfm in a terminal window.
##				 specify the terminal command with 'windowcmd'.
## 'standalone': open directories in a new window with the 'windowcmd'
##               (e.g. nautilus).
#windowtype:standalone
windowtype:pfm

##########################################################################
## colors

## you may define as many different colorsets as you like.
## use the notation 'framecolors[colorsetname]' and 'dircolors[colorsetname]'.
## the F4 key will cycle through these colorsets.
## the special setname 'off' is used for no coloring.

## 'framecolors' defines the colors for menu, menu in multiple mode,
## headings, headings in swap mode, footer, messages, and the highlighted file.
## for the frame to become colored, 'usecolor' must be set to 'yes' or 'force'.

## pfm version 1 used 'header' instead of 'menu' and 'title' instead
## of 'headings'.

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
## no=normal fi=file lo=lost file ln=symlink or=orphan link hl=hard link
## di=directory bd=block special cd=character special pi=fifo so=socket
## do=door nt=network special wh=whiteout ep=event pipe
## ex=executable su=setuid sg=setgid ca=capability (not implemented)
## ow=other-writable dir (d???????w?) st=sticky dir (d????????t)
## tw=sticky and other-writable dir (d???????wt)
## *.<ext> defines extension colors

dircolors[dark]:\
no=reset:fi=:\
lo=bold black:di=bold blue:\
ln=bold cyan:or=white on red:hl=white on blue:\
bd=bold yellow on black:cd=bold yellow on black:\
pi=yellow on black:so=bold magenta:ep=black on yellow:\
do=bold magenta:nt=bold magenta:wh=bold black on white:\
su=white on red:sg=black on yellow:\
ow=blue on green:st=white on blue:tw=black on green:\
ex=green:\
ca=black on red:\
*.cmd=bold green:*.exe=bold green:*.com=bold green:\
*.btm=bold green:*.bat=bold green:\
*.pas=green:\
*.c=magenta:*.h=magenta:\
*.pm=cyan:*.pl=cyan:\
*.htm=bold yellow:*.phtml=bold yellow:*.html=bold yellow:\
*.php=yellow:\
*.tar=bold red:*.tgz=bold red:*.arj=bold red:*.taz=bold red:*.lzh=bold red:\
*.lzma=bold red:*.zip=bold red:*.rar=bold red:*.z=bold red:*.Z=bold red:\
*.gz=bold red:*.bz2=bold red:*.dz=bold red:*.bz=bold red:*.tbz2=bold red:\
*.tz=bold red:*.ace=bold red:*.zoo=bold red:*.7z=bold red:*.rz=bold red:\
*.deb=red:*.rpm=red:*.cpio=red:*.jar=red:*.pkg=red:\
*.jpg=bold magenta:*.jpeg=bold magenta::*.gif=bold magenta:\
*.bmp=bold magenta:*.xbm=bold magenta:*.xpm=bold magenta:\
*.png=bold magenta:*.xcf=bold magenta:*.pbm=bold magenta:\
*.pgm=bold magenta:*.ppm=bold magenta:*.tga=bold magenta:\
*.tif=bold magenta:*.tiff=bold magenta:*.pcx=bold magenta:\
*.svg=bold magenta:*.svgz=bold magenta:*.mng=bold magenta:\
*.mpg=bold white:*.mpeg=bold white:*.m2v=bold white:*.mkv=bold white:\
*.ogm=bold white:*.mp4=bold white:*.m4v=bold white:*.mp4v=bold white:\
*.vob=bold white:*.qt=bold white:*.nuv=bold white:*.wmv=bold white:\
*.asf=bold white:*.rm=bold white:*.rmvb=bold white:*.flc=bold white:\
*.avi=bold white:*.fli=bold white:*.flv=bold white:*.gl=bold white:\
*.dl=bold white:*.xwd=bold white:*.yuv=bold white:*.axv=bold white:\
*.anx=bold white:*.ogv=bold white:*.ogx=bold white:*.mov=bold white:\
*.aac=cyan:*.au=cyan:*.flac=cyan:*.mid=cyan:*.midi=cyan:*.mka=cyan:\
*.aiff=cyan:*.aifc=cyan:*.mp3=cyan:*.mpc=cyan:*.ogg=cyan:*.ra=cyan:\
*.wav=cyan:*.axa=cyan:*.oga=cyan:*.spx=cyan:*.xspf=cyan:

dircolors[light]:\
no=reset:fi=:\
lo=bold black:di=bold blue:\
ln=underscore blue:or=white on red:hl=white on blue:\
bd=bold yellow on black:cd=bold yellow on black:\
pi=yellow on black:so=bold magenta:ep=black on yellow:\
do=bold magenta:nt=bold magenta:wh=bold white on black:\
su=white on red:sg=black on yellow:\
ow=blue on green:st=white on blue:tw=black on green:\
ex=green:\
ca=black on red:\
*.cmd=bold green:*.exe=bold green:*.com=bold green:*.btm=bold green:\
*.bat=bold green:*.pas=green:*.c=magenta:*.h=magenta:*.pm=on cyan:*.pl=on cyan:\
*.htm=black on yellow:*.phtml=black on yellow:*.html=black on yellow:\
*.php=black on yellow:
*.tar=bold red:*.tgz=bold red:*.arj=bold red:*.taz=bold red:*.lzh=bold red:\
*.zip=bold red:*.rar=bold red:\
*.z=bold red:*.Z=bold red:*.gz=bold red:*.bz2=bold red:*.deb=red:*.rpm=red:\
*.pkg=red:*.jpg=bold magenta:*.gif=bold magenta:*.bmp=bold magenta:\
*.xbm=bold magenta:*.xpm=bold magenta:*.png=bold magenta:\
*.mpg=bold white on blue:*.mpeg=bold white on blue:\
*.m2v=bold white on blue:*.mkv=bold white on blue:\
*.ogm=bold white on blue:*.mp4=bold white on blue:\
*.m4v=bold white on blue:*.mp4v=bold white on blue:\
*.vob=bold white on blue:*.qt=bold white on blue:\
*.nuv=bold white on blue:*.wmv=bold white on blue:\
*.asf=bold white on blue:*.rm=bold white on blue:\
*.rmvb=bold white on blue:*.flc=bold white on blue:\
*.avi=bold white on blue:*.fli=bold white on blue:\
*.flv=bold white on blue:*.gl=bold white on blue:\
*.dl=bold white on blue:*.xwd=bold white on blue:\
*.yuv=bold white on blue:*.axv=bold white on blue:\
*.anx=bold white on blue:*.ogv=bold white on blue:\
*.ogx=bold white on blue:*.mov=bold white on blue:
*.aac=cyan:*.au=cyan:*.flac=cyan:*.mid=cyan:*.midi=cyan:*.mka=cyan:\
*.aiff=cyan:*.aifc=cyan:*.mp3=cyan:*.mpc=cyan:*.ogg=cyan:*.ra=cyan:\
*.wav=cyan:*.axa=cyan:*.oga=cyan:*.spx=cyan:*.xspf=cyan:

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
## p    mode (permissions)       10
## m    modification time        15 (using "%y %b %d %H:%M" if len(%b) == 3)
## a    access time              15 (using "%y %b %d %H:%M" if len(%b) == 3)
## c    change time              15 (using "%y %b %d %H:%M" if len(%b) == 3)
## v    versioning info          >=4
## d    device                   5?
## i    inode                    >=7 (system-dependent)
## l    link count               >=5 (system-dependent)
## f    diskinfo            yes  >=14 (using clockformat, if len(%x) <= 14)

## take care not to make the fields too small or values will be cropped!
## if the terminal is resized, the filename field will be elongated.
## the diskinfo field *must* be the _first_ or _last_ field on the line.
## a final colon (:) after the last layout is allowed.

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
##  =e : 'editor'    (defined above)
##  =f : 'fg_editor' (defined above)
##  =p : 'pager'     (defined above)
##  =v : 'viewer'    (defined above)

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
extension[*.3pm]  : application/x-nroff-man
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
extension[*.js]   : application/javascript
extension[*.json] : application/json
extension[*.lzh]  : application/x-lha
extension[*.m3u]  : text/x-m3u-playlist
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
extension[*.sql]  : application/x-sql
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

launch[application/javascript]    : =e =2
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
launch[application/x-sql]         : =e =2
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
#launch[audio/mpeg]                : mpg123 =2 &
launch[audio/mpeg]                : vlc =2 >/dev/null 2>&1
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
launch[text/x-m3u-playlist]       : vlc =2 >/dev/null 2>&1
launch[text/x-php]                : =e =2
launch[video/mpeg]                : xine =2 &
#launch[video/quicktime]           :
launch[video/x-msvideo]           : divxPlayer =2 &

## vim: set filetype=xdefaults: # fairly close
__END__

=back

=head1 EVENTS

This package implements the following events:

=over 2

=item after_parse_usecolor

Called when the 'usecolor' setting of the config file has been
parsed.  This allows the caller to show a colored message on
screen while the rest of the config file is being parsed.

=back

=head1 SEE ALSO

pfm(1).

=cut

# vim: set tabstop=4 shiftwidth=4:
