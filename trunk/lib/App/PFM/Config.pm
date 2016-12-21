#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Config 1.33
#
# Name:			App::PFM::Config
# Version:		1.33
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2016-12-21
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
use App::PFM::Util qw(isyes isno isxterm ifnotdefined max lstrftime maxdatetimelen);
use App::PFM::Event;

use POSIX qw(mktime);

use strict;
use locale;

use constant {
	READ_AGAIN		 => 0,
	READ_FIRST		 => 1,
	CONFIGDIRNAME	 => "$ENV{HOME}/.pfm",
	CONFIGFILENAME	 => '.pfmrc',
	CONFIGDIRMODE	 => oct(700),
	BOOKMARKFILENAME => 'bookmarks',
};

use constant DEFAULTFORMAT =>
	'* nnnnnnnnnnnnnnnnnnnnnnnnnnnssssssss mmmmmmmmmmmmmmmm pppppppppp ffffffffffffff';

use constant BOOKMARKKEYS => [qw(
	a b c d e f g h i j k l m n o p q r s t u v w x y z
	A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
	0 1 2 3 4 5 6 7 8 9
)];

use constant FILETYPEFLAGS => {
	 # ls(1)
	 x => '*',
	 d => '/',
	 l => '@',
	 p => '|',
	's'=> '=',
	 D => '>',
	 w => '%',
	 # tcsh(1)
	 b => '#',
	 c => '%',
	 n => ':',
	 # => '+', # Hidden directory (AIX only) or context dependent (HP-UX only)
	'-'=> '',
	' '=> '',  # was ' (lost)'
};

our ($_pfm);

##########################################################################
# private subs

=item I<_init(App:PFM::Application $pfm, App::PFM::Screen $screen,>
I<string $pfm_version)>

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $screen, $pfm_version) = @_;
	$_pfm = $pfm;
	$self->{_screen}         = $screen;
	$self->{_pfm_version}    = $pfm_version;
	$self->{_pfmrc}          = {};
	$self->{_text}           = [];
	$self->{_configfilename} = $self->location();
	return;
}

=item I<_parse_colorsets()>

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
		'menu=normal:menukeys=underscore:footer=reverse:footerkeys=:' .
		'headings=reverse:swap=reverse:highlight=bold:';
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
		'menu=white on blue:menukeys=bold cyan on blue:'
	.	'multi=bold reverse cyan on white:'
	.	'headings=bold reverse cyan on white:swap=reverse black on cyan:'
	.	'footer=bold reverse blue on white:footerkeys=bold cyan on blue:'
	.	'rootuser=reverse red:message=bold cyan:highlight=bold:';
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
	return;
}

=item I<_ask_to_backup(string $message)>

Prompts for confirmation to backup the current F<.pfmrc> and work on
a new one.

=cut

sub _ask_to_backup {
	my ($self, $message) = @_;
	my $screen = $self->{_screen};
	$screen->neat_error("$message (y/n)? ");
	return 0 if (lc $screen->getch() ne 'y');
	$screen->puts("\r\n");
	unless ($self->backup()) {
		$screen->puts("Could not backup your config file, aborting");
		$screen->important_delay();
		return 0;
	}
	return 1;
}

##########################################################################
# constructor, getters and setters

=item I<configfilename( [ string $filename ] )>

Getter/setter for the current filename of the F<.pfmrc> file.

=cut

sub configfilename {
	my ($self, $value) = @_;
	$self->{_configfilename} = $value if defined $value;
	return $self->{_configfilename};
}

=item I<pfmrc( [ hashref $pfmrc ] )>

Getter/setter for the _pfmrc member variable holding the config options.

=cut

sub pfmrc {
	my ($self, $value) = @_;
	$self->{_pfmrc} = $value if defined $value;
	return $self->{_pfmrc};
}

=item I<text( [ arrayref $lines ] )>

Getter/setter for the member variable holding the unparsed text
of the config file.

=cut

sub text {
	my ($self, $value) = @_;
	$self->{_text} = $value if defined $value;
	return $self->{_text};
}

=item I<your_commands()>

Getter for the keys of the Your commands in the config file.

=cut

sub your_commands {
	my ($self) = @_;
	my @your =  map { substr($_, 5, 1) }
				grep /^your\[[[:alnum:]]\]$/, keys %{$self->{_pfmrc}};
	return @your;
}

=item I<your(char $key)>

Getter for a specific Your command from the config file.

=cut

sub your {
	my ($self, $key) = @_;
	return $self->{_pfmrc}{"your[$key]"};
}

##########################################################################
# public subs

=item I<location()>

Returns a message string for the user indicating which F<.pfmrc>
is currently being used.

=cut

sub location {
#	my ($self) = @_;
	return ($ENV{PFMRC} ? $ENV{PFMRC} : CONFIGDIRNAME . "/" . CONFIGFILENAME);
}

=item I<read(bool $firstread)>

Reads in the F<.pfmrc> file. If none exists, a default F<.pfmrc> is written.
The I<firstread> variable ensures that the message "Your config file may
be outdated" is given only once.  If the config file is outdated, offer
to update it (see App::PFM::Config::Update).

=cut

sub read {
	my ($self, $read_first) = @_;
	my ($pfmrc_version, $updater, $wanna);
	my $screen = $self->{_screen};
	READ_ATTEMPT: {
		$self->{_pfmrc} = {};
		$self->{_text}  = [];
		# try to find a config file
		unless (-r $self->{_configfilename}) {
			# create a default config file
			$self->write_default();
		}
		# open and read in
		if (open my $PFMRC, '<', $self->{_configfilename}) {
			$self->{_text} = [ <$PFMRC> ];
			seek($PFMRC, 0, 0); # rewind
			while (<$PFMRC>) {
				if (/#\s*Version\D+([[:alnum:].]+)$/) {
					$pfmrc_version = $1;
					next;
				}
				s/#.*//;
				if (s/\\\n?$//) { $_ .= <$PFMRC>; redo; }
#				if (/^\s*([^:[\s]+(?:\[[^]]+\])?)\s*:\s*(.*)$/o) {
				if (/^[ \t]*([^: \t[]+(?:\[[^]]+\])?)[ \t]*:[ \t]*(.*)$/o) {
#					print STDERR "-$1";
					$self->{_pfmrc}{$1} = $2;
				}
			}
			close $PFMRC;
			return unless $read_first;
			# messages will not be in message color: usecolor not yet parsed
			if (!defined $pfmrc_version) {
				# undefined pfmrc version
				$screen->neat_error(
					"Warning: the version of your $self->{_configfilename}\r\n"
				.	"could not be determined. Please see pfm(1), under "
				.	"DIAGNOSIS."
				);
				$screen->important_delay();
			} elsif ($pfmrc_version lt $self->{_pfm_version}) {
				# pfmrc version outdated
				$updater = App::PFM::Config::Update->new();
				$wanna = "Warning: your $self->{_configfilename} version "
					.	"$pfmrc_version\r\nmay be too old for this version "
					.	"of pfm ($self->{_pfm_version}).\r\nDo you want me to "
					.	"backup this config file\r\nand";
				if ($pfmrc_version ge $updater->get_minimum_version()) {
					# outdated but can be updated
					return unless $self->_ask_to_backup(
						"$wanna update it now");
					$screen->cooked_echo();
					$updater->update(
						$pfmrc_version, $self->{_pfm_version}, $self->{_text});
					$self->write_text();
					$screen->raw_noecho();
					redo READ_ATTEMPT;
				} else {
					# outdated and too old to update
					return unless $self->_ask_to_backup(
						"$wanna create a new default one for this version");
					$self->write_default();
					redo READ_ATTEMPT;
				}
			} # if !defined($version) or $version lt $pfm_version
		} # if open()
	} # READ_ATTEMPT
	return;
}

=item I<parse()>

Processes the settings from the F<.pfmrc> file.
Most options are fetched into member variables. Those that aren't,
remain accessable in the hash member C<$config-E<gt>{_pfmrc}>.

=cut

sub parse {
	my ($self) = @_;
	my $pfmrc  = $self->{_pfmrc};
	my $e;
	local $_;
	$self->{dircolors}     = {};
	$self->{framecolors}   = {};
	$self->{filetypeflags} = {};
	# 'usecolor' - find out when color must be turned _off_
	# we want to do this _now_ so that the copyright message is colored.
	if (defined($ENV{ANSI_COLORS_DISABLED}) or isno($pfmrc->{usecolor})) {
		$self->{usecolor} = 0;
	} elsif ($pfmrc->{usecolor} eq 'force') {
		$self->{usecolor} = 1;
	} else {
		$self->{usecolor} = $self->{_screen}->colorizable;
	}
	# copyright message
	$self->fire(App::PFM::Event->new({
		name   => 'after_parse_usecolor',
		origin => $self,
		type   => 'soft',
		data   => $pfmrc,
	}));
	# parse and set defaults
	$self->{clockdateformat}	 = $pfmrc->{clockdateformat} || '%Y %b %d';
	$self->{clocktimeformat}	 = $pfmrc->{clocktimeformat} || '%H:%M:%S';
	$self->{timestampformat}	 = $pfmrc->{timestampformat} || '%y %b %d %H:%M';
	$self->{mousewheeljumpsize}	 = $pfmrc->{mousewheeljumpsize}  || 'variable';
	$self->{mousewheeljumpmin}	 = $pfmrc->{mousewheeljumpmin}   || 1;
	$self->{mousewheeljumpmax}	 = $pfmrc->{mousewheeljumpmax}   || 10;
	$self->{mousewheeljumpratio} = $pfmrc->{mousewheeljumpratio} || 4;
	$self->{cursorjumptime}		 = $pfmrc->{cursorjumptime}      || 0.5;
	$self->{esc_timeout}		 = $pfmrc->{esc_timeout}         || 0.4;
	$self->{launchby}			 = $pfmrc->{launchby};
	$self->{copyoptions}		 = $pfmrc->{copyoptions};
	$self->{checkforupdates}	 = !isno($pfmrc->{checkforupdates});
	$self->{cursorveryvisible}	 = isyes($pfmrc->{cursorveryvisible});
	$self->{clsonexit}			 = isyes($pfmrc->{clsonexit});
	$self->{confirmquit}		 = isyes($pfmrc->{confirmquit});
	$self->{autowritehistory}	 = isyes($pfmrc->{autowritehistory});
	$self->{autowritebookmarks}	 = isyes($pfmrc->{autowritebookmarks});
	$self->{autoexitmultiple}	 = isyes($pfmrc->{autoexitmultiple});
	$self->{refresh_always_smart}= isyes($pfmrc->{refresh_always_smart});
	$self->{highlightname}		 = isyes($pfmrc->{highlightname} || 'yes');
	$self->{swap_persistent}	 = isyes($pfmrc->{persistentswap} || 'yes');
	$self->{mouse_moves_cursor}	 = isyes($pfmrc->{mouse_moves_cursor});
	$self->{autosort}			 = isyes($pfmrc->{autosort} || 'yes');
	$self->{trspace}			 = isyes($pfmrc->{defaulttranslatespace}) ? ' ' : '';
	$self->{dotdot_mode}		 = isyes($pfmrc->{dotdotmode});
	$self->{autorcs}			 = isyes($pfmrc->{autorcs});
	$self->{remove_marks_ok}	 = isyes($pfmrc->{remove_marks_ok});
	$self->{clickiskeypresstoo}	 = isyes($pfmrc->{clickiskeypresstoo} || 'yes');
	$self->{clobber_mode}		 = isyes($pfmrc->{defaultclobber});
	$self->{clobber_compare}	 = isyes($pfmrc->{clobber_compare} || 'yes');
	$self->{timefieldstretch}	 = isyes($pfmrc->{timefieldstretch});
	$self->{currentlayout}		 = $pfmrc->{defaultlayout} || 0;
	$self->{white_mode}			 = isyes($pfmrc->{defaultwhitemode});
	$self->{dot_mode}			 = isyes($pfmrc->{defaultdotmode});
	$self->{path_mode}			 = $pfmrc->{defaultpathmode} eq 'phys' ? 'phys' : 'log';
	$self->{sort_mode}			 = $pfmrc->{defaultsortmode} || 'n';
	$self->{radix_mode}			 = $pfmrc->{defaultradix} || 'oct';
	$self->{ident_mode}			 = $pfmrc->{defaultident} || 'user,host';
	$self->{escapechar} =
	$self->{e}			= $e	 = $pfmrc->{escapechar} || '=';
	$self->{sortcycle}			 = $pfmrc->{sortcycle} || 'n,en,dn,Dn,sn,Sn,tn,un';
	$self->{keymap}				 = $pfmrc->{keymap} || 'emacs';
	$self->{paste_protection}	 = $pfmrc->{paste_protection} || 'xterm';
	$self->{paste_protection}	 = ($self->{paste_protection} eq 'xterm' && isxterm($ENV{TERM}))
								 || isyes($self->{paste_protection});
	$self->{force_minimum_size}	 = $pfmrc->{force_minimum_size} || 'xterm';
	$self->{force_minimum_size}	 = ($self->{force_minimum_size} eq 'xterm' && isxterm($ENV{TERM}))
								 || isyes($self->{force_minimum_size});
	$self->{mouse_mode}			 = $_pfm->browser->mouse_mode || $pfmrc->{defaultmousemode} || 'xterm';
	$self->{mouse_mode}			 = ($self->{mouse_mode} eq 'xterm' && isxterm($ENV{TERM}))
								 || isyes($self->{mouse_mode});
	$self->{altscreen_mode}		 = $ENV{PFMDEBUG} ? 'no' : $pfmrc->{altscreenmode} || 'xterm';
	$self->{altscreen_mode}		 = ($self->{altscreen_mode} eq 'xterm' && isxterm($ENV{TERM}))
								 || isyes($self->{altscreen_mode});
	$self->{chdirautocmd}		 = $pfmrc->{chdirautocmd};
	$self->{windowtype}			 = $pfmrc->{windowtype} eq 'standalone' ? 'standalone' : 'pfm';
	$self->{windowcmd}			 = $pfmrc->{windowcmd}
								 || ($pfmrc->{windowtype} eq 'standalone'
									? 'nautilus'
									: $^O eq 'linux' ? 'gnome-terminal -e' : 'xterm -e');
	$self->{printcmd}			 = $pfmrc->{printcmd}
								 || ($ENV{PRINTER} ? "lpr -P$ENV{PRINTER} ${e}2" : "lpr ${e}2");
	$self->{viewer}				 = $pfmrc->{viewer} || 'xv';
	$self->{editor}				 = $ENV{VISUAL} || $ENV{EDITOR} || $pfmrc->{editor} || 'vi';
	$self->{fg_editor}			 = $pfmrc->{fg_editor} || $self->{editor};
	$self->{pager}				 = $ENV{PAGER} || $pfmrc->{pager} || ($^O eq 'linux' ? 'less' : 'more');
	# flags
	if (isyes($pfmrc->{filetypeflags})) {
		$self->{filetypeflags} = FILETYPEFLAGS;
	} elsif ($pfmrc->{filetypeflags} eq 'dirs') {
		$self->{filetypeflags} = { d => FILETYPEFLAGS->{d} };
	} else {
		$self->{filetypeflags} = {};
	}
	# split 'columnlayouts', provide one default
	$self->{columnlayouts} = [
		$pfmrc->{columnlayouts}
			? split(/:/, $pfmrc->{columnlayouts})
			: DEFAULTFORMAT
	];
	# default sort modes
#	$self->{directory_specific_sortmodes} =
#		$pfmrc->{directory_specific_sortmodes} ? [
#			map { [ split /=/ ] } split(
#				/:/, $pfmrc->{directory_specific_sortmodes})
#	] : [];
	# file filter
	$self->{file_filter} = {};
	@{$self->{file_filter}}{
		$pfmrc->{file_filter}
			? grep length, split(/:/, $pfmrc->{file_filter})
			: undef
	} = ();
	# colorsets
	$self->_parse_colorsets();
	# signal observers.
	$self->fire(App::PFM::Event->new({
		name   => 'after_parse_config',
		origin => $self,
		type   => 'soft',
		data   => $pfmrc,
	}));
	return;
}

=item I<write_default()>

Writes a default config file. Creates the default containing directory
(F<~/.pfm>) if does not exist. An existing config file will be clobbered.

=cut

sub write_default {
	my ($self) = @_;
	my @resourcefile;
	my $version    = $self->{_pfm_version};
	local $_;
	# if necessary, create the directory, but only if $ENV{PFMRC} is not set
	unless ($ENV{PFMRC} || -d CONFIGDIRNAME) {
		mkdir CONFIGDIRNAME, CONFIGDIRMODE;
	}
	if (open my $MKPFMRC, '>', $self->{_configfilename}) { # ignore failure
		# both __DATA__ and __END__ markers are used at the same time
		while (($_ = <DATA>) !~ /^__END__/) {
			s/^(##? Version )x/$1$version/m;
			# we don't need to calculate the length of the date field any more,
			# since it can be adjusted according to the locale's needs.
			print $MKPFMRC $_;
		}
		close DATA;
		close $MKPFMRC;
	} # no success? well, that's just too bad
	return;
}

=item I<backup()>

Creates a backup of the current config file, I<e.g.>
F<.pfmrc.20100901T231201>.

=cut

sub backup {
	my ($self) = @_;
	my $now    = lstrftime('%Y%m%dT%H%M%S', localtime);
	# quotemeta($now) as well: it may be tainted (determined by locale).
	my $result = system(
		"cp \Q$self->{_configfilename}\E \Q$self->{_configfilename}.$now\E");
	return !$result;
}

=item I<write_text()>

Creates a new config file by writing the raw text to it.

=cut

sub write_text {
	my ($self) = @_;
	open my $MKPFMRC, '>', $self->{_configfilename} or return;
	print $MKPFMRC @{$self->{_text}};
	close $MKPFMRC or return;
	return 1;
}

=item I<read_bookmarks()>

Reads the bookmarks file.
Fails silently if the bookmarks file cannot be read.

=cut

sub read_bookmarks {
	my ($self) = @_;
	my %bookmarks = ();
	if (open my $BOOKMARKS, '<', CONFIGDIRNAME . "/" . BOOKMARKFILENAME) {
		while (<$BOOKMARKS>) {
			# wrapping lines (ending in '\') are not allowed
			s/#.*//;
			if (/^[ \t]*bookmark\[(.)\][ \t]*:[ \t]*(.*)$/o) {
				$bookmarks{$1} = $2;
			}
		}
		close $BOOKMARKS;
	} # fail silently
	return %bookmarks;
}

=item I<write_bookmarks( [ bool $finishing [, bool $silent ] ] )>

Writes the states to the bookmarks file.
Reports an error if the bookmarks file cannot be written.

The argument I<finishing> indicates that the final message
should be shown without delay.

The argument I<silent> suppresses output and may be used for testing.

=cut

sub write_bookmarks {
	my ($self, $finishing, $silent) = @_;
	my ($state, $path, $BOOKMARKS);
	my $screen = $self->{_screen};
	if (!$finishing && !$silent) {
		$screen->at(0,0)->clreol()
			->set_deferred_refresh($screen->R_MENU);
	}
	unless (open $BOOKMARKS, '>', CONFIGDIRNAME . "/" . BOOKMARKFILENAME) {
		$screen->display_error("Error writing bookmarks: $!") unless $silent;
		return;
	}
	print $BOOKMARKS '#' x 74, "\n## bookmarks for pfm\n\n";
	foreach (@{BOOKMARKKEYS()}) {
		next if /^S_/; # skip S_MAIN, S_PREV, S_SWAP
		$state = $_pfm->state($_);
		if (ref $state) {
			$path = $state->directory->path || '';
			if ($state->{_position}) {
				$path .= '/' . $state->{_position};
			}
		} else {
			$path = $state;
		}
		print $BOOKMARKS "bookmark[$_]:$path\n";
	}
	print $BOOKMARKS "\n## vim: set filetype=xdefaults:\n";
	unless (close $BOOKMARKS) {
		$screen->display_error("Error writing bookmarks: $!") unless $silent;
		return;
	}
	unless ($silent) {
		$screen->putmessage(
			'Bookmarks written successfully' . ($finishing ? "\n" : ''));
	}
	unless ($finishing) {
		$screen->error_delay();
	}
	return;
}

=item I<on_shutdown( [ bool $silent ] )>

Called when the application is shutting down. Writes the bookmarks
to file if so indicated by the config.

The I<silent> argument suppresses output and may be used for testing
if the application shuts down correctly.

=cut

sub on_shutdown {
	my ($self, $silent) = @_;
	$self->write_bookmarks(1, $silent) if $self->{autowritebookmarks};
	return;
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

## automatically check for updates on the web (default: yes)
#checkforupdates:no

## Must 'Hit any key to continue' also accept mouse clicks?
#clickiskeypresstoo:yes

## display file comparison information before asking to clobber (default: yes)
#clobber_compare:no

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

## time between cursor jumps in incremental find and the bookmark browser
## (in seconds, fractions allowed)
#cursorjumptime:0.5

## use very visible cursor (e.g. block cursor on Linux console)
cursorveryvisible:yes

## initial setting for automatically clobbering existing files (toggle with !)
defaultclobber:no

## initial colorset to pick from the various colorsets defined below
## (cycle with F4)
defaultcolorset:dark

## show dot files initially? (hide them otherwise, toggle with . key)
defaultdotmode:yes

## initial ident mode (two of: 'host', 'user' or 'tty', separated by commas)
## (cycle with = key)
defaultident:user,host

## initial layout to pick from the array 'columnlayouts' (see below)
## (cycle with F9)
defaultlayout:0

## initially turn on mouse support? (yes,no,xterm) (default: only in xterm)
## (toggle with F12)
defaultmousemode:xterm

## initially display logical or physical paths? (log,phys) (default: log)
## (toggle with ")
defaultpathmode:log

## initial radix that Name will use to display non-ascii chars with
## (hex,oct,dec) (toggle with *)
defaultradix:hex

## initial sort mode (nNmMeEfFdDaAsSzZtTuUgGvViI*) (default: n)
## (select with F6)
defaultsortmode:n

## default translate spaces when viewing Name
## (toggle with SPACE when viewing Name)
defaulttranslatespace:no

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

## timeout for escape sequences (in seconds). Smaller values can make
## handling the ESC key snappier, but over a slow connection, function
## keys and friends may not arrive correctly. Use with care.
## (default: 0.4)
#esc_timeout: 0.4

## In case the regular editor automatically forks in the background, you
## may want to specify a foreground editor here. If defined, this editor
## will be used for editing the config file, so that pfm will be able to
## wait for the editor to finish before rereading the config file.
## It will also be used for editing ACLs.
#fg_editor:vim

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
## if some (special) keys do not seem to work, add their escape sequences here.
## you may specify these by-terminal (make the option name 'keydef[$TERM]')
## or global ('keydef[*]')
## definitely look in the Term::Screen(3pm) manpage for details.
## also check 'kmous' from terminfo if your mouse is malfunctioning.
keydef[*]:kmous=\e[M:pgdn=\e[62~:pgup=\e[63~:\
ks1=\eO1;2P:ks1=\e[1;2P:\
ks2=\eO1;2Q:ks2=\e[1;2Q:\
ks4=\eO1;2S:ks4=\e[26~:ks4=\e[1;2S:\
ks8=\e[19;2~:ks8=\e[32~:\
ks9=\e[20;2~:ks9=\e[33~:
# :ks1=\eO1;2P:ks1=\e[1;2P:             # shift-F1
# :ks2=\eO1;2Q:ks2=\e[1;2Q:             # shift-F2
# :ks4=\eO1;2S:ks4=\e[26~:ks4=\e[1;2S:  # shift-F4
# :ks8=\e[19;2~:                        # shift-F8
# :ks9=\e[20;2~:ks9=\e[33~:             # shift-F9
## gnome-terminal handles F1  itself. enable shift-F1 by adding:
#k1=\eO1;2P:
## gnome-terminal handles F10 itself. enable shift-F10 by adding:
#k10=\e[21;2~:
## gnome-terminal handles F11 itself. enable shift-F11 by adding:
#k11=\e[23;2~:

## the keymap to use in readline. Allowed values are:
## emacs (=emacs-standard), emacs-standard, emacs-meta, emacs-ctlx,
## vi (=vi-command), vi-command, vi-move, and vi-insert.
## emacs is the default.
#keymap:vi-insert

## should a mouse click move the cursor to the clicked line? (default no)
#mouse_moves_cursor:yes

## characteristics of the mouse wheel: the number of lines that the
## mouse wheel will scroll. This can be an integer or 'variable'.
#mousewheeljumpsize:5
mousewheeljumpsize:variable

## if 'mousewheeljumpsize' is 'variable', the next three values are taken
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

## disable pasting when a menu is active. This requires a terminal
## that understands 'bracketed paste' mode. (yes,no,xterm)
paste_protection:xterm

## F7 key swap path method is persistent? (default yes)
#persistentswap:no

## your system's print command (needs =2 for current filename).
## if unspecified, the default is:
## if $PRINTER is set:   'lpr -P$PRINTER =2'
## if $PRINTER is unset: 'lpr =2'
#printcmd:lp -d$PRINTER =2

## should F5 always leave marks untouched like (M)ore-F5?
#refresh_always_smart:no

## is it always "OK to remove marks?" without confirmation?
#remove_marks_ok:no

## sort modes to cycle through when clicking 'Sort' in the footer.
## default: n,en,dn,Dn,sn,Sn,tn,un
sortcycle:n,dn,Dn,sn,Sn,tn,un

## format for displaying timestamps: see strftime(3).
## take care that the time fields (a, c and m) in the layouts defined below
## should be wide enough for this string.
timestampformat:%y %b %d %H:%M
#timestampformat:%Y-%m-%d %H:%M:%S
#timestampformat:%b %d %H:%M
#timestampformat:%c
#timestampformat:%Y %V %a

## should the time field be stretched to the timestamp length? (otherwise,
## the timestamp will be truncated). (default: yes)
#timefieldstretch:no

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
##               specify the terminal command with 'windowcmd'.
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
## headings, headings in swap mode, footer, messages, the username (for root),
## and the highlighted file.
## for the frame to become colored, 'usecolor' must be set to 'yes' or 'force'.

## pfm version 1 used 'header' instead of 'menu' and 'title' instead
## of 'headings'.

framecolors[light]:\
menu=white on blue:menukeys=bold cyan on blue:multi=reverse cyan on black:\
headings=reverse cyan on black:swap=reverse black on cyan:\
footer=reverse blue on white:footerkeys=bold cyan on blue:\
rootuser=reverse red:message=blue:highlight=bold:

framecolors[dark]:\
menu=white on blue:menukeys=bold cyan on blue:multi=bold reverse cyan on white:\
headings=bold reverse cyan on white:swap=black on cyan:\
footer=bold reverse blue on white:footerkeys=bold cyan on blue:\
rootuser=reverse red:message=bold cyan:highlight=bold:

## these are a suggestion
#framecolors[dark]:\
#menu=white on blue:menukeys=bold yellow on blue:multi=reverse cyan on black:\
#headings=reverse cyan on black:swap=reverse yellow on black:\
#footer=bold reverse blue on white:footerkeys=bold yellow on blue:\
#rootuser=reverse red:message=bold cyan:highlight=bold:

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
## *.ext      defines colors for files with a specific extension
## 'filename' defines colors for complete specific filenames

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
'Makefile'=underline:'Imakefile'=underline:'Makefile.PL'=underline:\
*.cmd=bold green:*.exe=bold green:*.com=bold green:\
*.btm=bold green:*.bat=bold green:\
*.pas=green:\
*.c=magenta:*.h=magenta:\
*.pm=cyan:*.pl=cyan:\
*.htm=bold yellow:*.phtml=bold yellow:*.html=bold yellow:\
*.php=yellow:\
*.doc=bold cyan:*.docx=bold cyan:*.odt=bold cyan:\
*.xls=cyan:*.xlsx=cyan:*.ods=cyan:\
*.tar=bold red:*.tgz=bold red:*.arj=bold red:*.taz=bold red:*.lzh=bold red:\
*.lzma=bold red:*.zip=bold red:*.rar=bold red:*.z=bold red:*.Z=bold red:\
*.xz=bold red:*.txz=bold red:\
*.gz=bold red:*.bz2=bold red:*.dz=bold red:*.bz=bold red:*.tbz2=bold red:\
*.tz=bold red:*.ace=bold red:*.zoo=bold red:*.7z=bold red:*.rz=bold red:\
*.deb=red:*.rpm=red:*.cpio=red:*.jar=red:*.pkg=red:\
*.jpg=bold magenta:*.jpeg=bold magenta:*.gif=bold magenta:\
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
'Makefile'=underline:'Imakefile'=underline:'Makefile.PL'=underline:\
*.cmd=bold green:*.exe=bold green:*.com=bold green:\
*.btm=bold green:*.bat=bold green:\
*.pas=green:\
*.c=magenta:*.h=magenta:\
*.pm=on cyan:*.pl=on cyan:\
*.htm=black on yellow:*.phtml=black on yellow:*.html=black on yellow:\
*.php=black on yellow:\
*.doc=bold black on cyan:*.docx=bold black on cyan:*.odt=bold black on cyan:\
*.xls=black on cyan:*.xlsx=black on cyan:*.ods=black on cyan:\
*.tar=bold red:*.tgz=bold red:*.arj=bold red:*.taz=bold red:*.lzh=bold red:\
*.zip=bold red:*.rar=bold red:\
*.xz=bold red:*.txz=bold red:\
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
headings=reverse:swap=reverse:footer=reverse:footerkeys=reverse:\
rootuser=reverse red:highlight=bold:

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
## w    uid                      >=5 (system-dependent)
## h    gid                      >=5 (system-dependent)
## p    mode (permissions)       10 (+1 for ACL flag '+')
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
* nnnnnnnnnnnnnnnnnnnnnnnnnnnsssssssss mmmmmmmmmmmmmmm pppppppppppffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnsssssssss aaaaaaaaaaaaaaa pppppppppppffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnssssssss uuuuuuuu gggggggglllll pppppppppppffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnsssssss uuuuuuuu gggggggg pppppppppppffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnuuuuuuuu gggggggg pppppppppppffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnnnssssssss vvvv mmmmmmmmmmmmmmm pppppppppppffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnzzzzzzzz mmmmmmmmmmmmmmm ffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsssssssss ffffffffffffff:\
ppppppppppp uuuuuuuu gggggggg mmmmmmmmmmmmmmm sssssss* nnnnnnnnnn ffffffffffffff:\
pppppppppppllll uuuuuuuu ggggggggssssssss mmmmmmmmmmmmmmm *nnnnnn ffffffffffffff:

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
##  =8 : list of marked filenames
##  =9 : previous directory path (F2)
##  == : a single literal '='
##  =e : 'editor'    (defined above)
##  =E : 'fg_editor' (defined above)
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
your[1]:vimdiff =2*
your[2]:meld =2* &

##########################################################################
## launch commands

## how should pfm try to determine the file type? by its magic (using file(1)),
## by its unique filename,
## by extension, should we try to run it as an executable if the 'x' bit is set,
## or should we prefer one method and fallback on another one?
## allowed values: combinations of 'xbit', 'name', 'extension' and 'magic'
launchby:name,extension,xbit
#launchby:name,extension,xbit,magic

## launchby extension
## the file type names do not have to be valid MIME types
extension[*.1m]   : application/x-nroff-man
extension[*.1]    : application/x-nroff-man
extension[*.3i]   : application/x-intercal
extension[*.3pm]  : application/x-nroff-man
extension[*.ai]   : application/postscript
extension[*.aif]  : audio/x-aiff
extension[*.aifc] : audio/x-aiff
extension[*.aiff] : audio/x-aiff
extension[*.arj]  : application/x-arj
extension[*.au]   : audio/basic
extension[*.avi]  : video/x-msvideo
extension[*.awk]  : application/x-awk
extension[*.bash] : application/x-bash
extension[*.bat]  : application/x-msdos-batch
extension[*.bin]  : application/octet-stream
extension[*.bf]   : application/x-befunge
extension[*.bmp]  : image/x-ms-bitmap
extension[*.bz2]  : application/x-bzip2
extension[*.c]    : text/x-c
extension[*.cc]   : text/x-c++
extension[*.class]: application/octet-stream
extension[*.cmd]  : application/x-msdos-batch
extension[*.com]  : application/x-executable
extension[*.cpio] : application/x-cpio
extension[*.cs]   : text/x-csharp
extension[*.csh]  : application/x-csh
extension[*.css]  : text/css
extension[*.deb]  : application/x-deb
extension[*.doc]  : application/msword
extension[*.docx] : application/msword
extension[*.dot]  : application/msword
extension[*.dll]  : application/octet-stream
extension[*.dvi]  : application/x-dvi
extension[*.eps]  : application/postscript
extension[*.exe]  : application/x-executable
extension[*.f]    : text/x-fortran
extension[*.for]  : text/x-fortran
extension[*.f90]  : text/x-fortran
extension[*.f95]  : text/x-fortran
extension[*.flv]  : video/x-flv
extension[*.gif]  : image/gif
extension[*.gz]   : application/x-gzip
extension[*.h]    : text/plain
extension[*.hh]   : text/plain
extension[*.hqx]  : application/mac-binhex40
extension[*.htm]  : text/html
extension[*.html] : text/html
extension[*.i]    : application/x-intercal
extension[*.jar]  : application/zip
extension[*.java] : text/x-java
extension[*.jpe]  : image/jpeg
extension[*.jpeg] : image/jpeg
extension[*.jpg]  : image/jpeg
extension[*.js]   : application/javascript
extension[*.json] : application/json
extension[*.latex]: application/x-latex
extension[*.lha]  : application/x-lha
extension[*.lzh]  : application/x-lha
extension[*.lsp]  : application/x-lisp
extension[*.m3u]  : text/x-m3u-playlist
extension[*.mid]  : audio/midi
extension[*.midi] : audio/midi
extension[*.mov]  : video/quicktime
extension[*.movie]: video/x-sgi-movie
extension[*.man]  : application/x-groff-man
extension[*.mm]   : application/x-groff-mm
extension[*.mp2]  : audio/mpeg
extension[*.mp3]  : audio/mpeg
extension[*.mp4]  : video/mpeg
extension[*.mpe]  : video/mpeg
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
extension[*.pot]  : application/mspowerpoint
extension[*.pps]  : application/mspowerpoint
extension[*.ppt]  : application/mspowerpoint
extension[*.pptx] : application/mspowerpoint
extension[*.ppz]  : application/mspowerpoint
extension[*.pl]   : application/x-perl
extension[*.pm]   : application/x-perl-module
extension[*.png]  : image/png
extension[*.pbm]  : image/x-portable-bitmap
extension[*.pgm]  : image/x-portable-graymap
extension[*.pnm]  : image/x-portable-anymap
extension[*.ppm]  : image/x-portable-pixmap
extension[*.ps]   : application/postscript
extension[*.py]   : application/x-python
extension[*.qt]   : video/quicktime
extension[*.ra]   : audio/x-realaudio
extension[*.ram]  : audio/x-pn-realaudio
extension[*.rm]   : audio/x-pn-realaudio
extension[*.rar]  : application/x-rar
#extension[*.rpm]  : audio/x-pn-realaudio-plugin
extension[*.rpm]  : application/x-rpm
extension[*.rtf]  : text/rtf
extension[*.rtx]  : text/richtext
extension[*.scm]  : application/x-scheme
extension[*.ss]   : application/x-scheme
extension[*.sh]   : application/x-sh
extension[*.shar] : application/x-shar
extension[*.sit]  : application/x-stuffit
extension[*.smi]  : application/smil
extension[*.smil] : application/smil
extension[*.spl]  : application/x-futuresplash
extension[*.sql]  : application/x-sql
extension[*.sty]  : text/x-tex-style
extension[*.svg]  : image/svg+xml
extension[*.swf]  : application/x-shockwave-flash
extension[*.tar]  : application/x-tar
extension[*.taz]  : application/x-tar-compress
extension[*.tcl]  : application/x-tcl
extension[*.tex]  : application/x-tex
extension[*.texi] : application/x-texinfo
extension[*.texinfo]: application/x-texinfo
extension[*.tgz]  : application/x-tar-gzip
extension[*.tif]  : image/tiff
extension[*.tiff] : image/tiff
extension[*.tcsh] : application/x-tcsh
extension[*.txt]  : text/plain
extension[*.txz]  : application/x-tar-xz
extension[*.uue]  : application/x-uuencoded
extension[*.viv]  : video/vnd.vivo
extension[*.vivo] : video/vnd.vivo
extension[*.vrml] : model/vrml
extension[*.wrl]  : model/vrml
extension[*.wav]  : audio/x-wav
extension[*.wmv]  : video/x-winmedia
extension[*.xcf]  : image/x-gimp
extension[*.xbm]  : image/x-xbitmap
extension[*.xlc]  : application/vnd.ms-excel
extension[*.xll]  : application/vnd.ms-excel
extension[*.xlm]  : application/vnd.ms-excel
extension[*.xls]  : application/vnd.ms-excel
extension[*.xlsx] : application/vnd.ms-excel
extension[*.xlt]  : application/vnd.ms-excel
extension[*.xlw]  : application/vnd.ms-excel
extension[*.xml]  : application/xml
extension[*.xpm]  : image/x-xpixmap
extension[*.xz]   : application/x-xz
extension[*.xwd]  : image/x-xwindowdump
extension[*.ync]  : application/x-yencoded
extension[*.yml]  : application/x-yaml
extension[*.z]    : application/x-compress
extension[*.Z]    : application/x-compress
extension[*.zip]  : application/zip
extension[*.zsh]  : application/x-zsh

## launchby magic
## these will search by regular expression in the file(1) output
magic[ASCII English text]   : text/plain
magic[C\+?\+? program text] : text/x-c
magic[GIF image data]       : image/gif
magic[HTML document text]   : text/html
magic[make commands text]   : text/x-makefile
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
magic[Python script]        : application/x-python
magic[tar archive]          : application/x-tar

## launchby extension or magic
launch[application/javascript]    : =e =2
launch[application/json]          : =e =2
launch[application/msword]        : ooffice =2 &
launch[application/mspowerpoint]  : ooffice =2 &
launch[application/vnd.ms-excel]  : ooffice =2 &
launch[application/octet-stream]  : =p =2
launch[application/pdf]           : acroread =2 &
#launch[application/pdf]           : evince =2 &
launch[application/postscript]    : gv =2 &
launch[application/x-arj]         : unarj x =2
launch[application/x-befunge]     : mtfi =2
launch[application/x-bzip2]       : bunzip2 =2
launch[application/x-chem]        : chem =2|groff -pteR -mm > =1.ps; gv =1.ps &
launch[application/x-compress]    : uncompress =2
launch[application/x-intercal]    : ick -b =2
launch[application/x-deb]         : dpkg -L =2
launch[application/x-dvi]         : xdvi =2 &
launch[application/x-executable]  : wine =2 &
launch[application/x-groff-man]	  : groff -pteR -man =2 > =1.ps; gv =1.ps &
launch[application/x-groff-mm]	  : groff -pteR -mm  =2 > =1.ps; gv =1.ps &
launch[application/x-gzip]        : gunzip =2
#launch[application/x-lha]         :
launch[application/x-msdos-batch] : =e =2
launch[application/x-ms-office]   : ooffice =1 &
launch[application/x-openoffice]  : ooffice =2 &
launch[application/x-nroff-man]	  : nroff -p -t -e -man =2 | =p
launch[application/x-pascal]      : =e =2
launch[application/x-perl-module] : =e =2
launch[application/x-perl]        : ./=2
launch[application/x-python]      : ./=2
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
launch[application/x-tar-xz]      : xz -dc =2 | tar xvf -
launch[application/x-xz]          : xz -d =2
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
launch[text/x-c]                  : gcc -o =1 =2
launch[text/x-c++]                : g++ -o =1 =2
launch[text/x-csharp]             : gmcs =2
launch[text/x-makefile]           : make
launch[text/x-m3u-playlist]       : vlc =2 >/dev/null 2>&1
launch[text/x-php]                : =e =2
launch[video/mpeg]                : xine =2 &
#launch[video/quicktime]           :
launch[video/x-msvideo]           : divxPlayer =2 &

## launchby name
## some filenames have their own special launch method
launchname[Makefile]              : make
launchname[Imakefile]             : xmkmf
launchname[Makefile.PL]           : perl =2

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

pfm(1), App::PFM::Config::Update(3pm).

=cut

# vim: set tabstop=4 shiftwidth=4:
