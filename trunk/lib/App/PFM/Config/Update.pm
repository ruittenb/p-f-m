#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Config::Update 2.08.4
#
# Name:			App::PFM::Config::Update
# Version:		2.08.4
# Author:		Rene Uittenbogaard
# Created:		2010-05-28
# Date:			2010-09-06
#

##########################################################################

=pod

=head1 NAME

App::PFM::Config::Update

=head1 DESCRIPTION

PFM class used for updating an existing F<.pfmrc> for a newer
version of C<pfm>. Your original F<.pfmrc> will be backed up as
F<.pfmrc.>datestamp.

This class should be regarded as a I<get-me-going-fast> solution.
You will probably be better off by having C<pfm> generate a new
F<.pfmrc> for you and comparing it to your own version.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Config::Update;

use base 'App::PFM::Abstract';

use App::PFM::Util qw(min max);

use POSIX qw(strftime);
use Carp qw(cluck);

use strict;
use locale;

use constant UPDATES => {
	# removals is an arrayref with regexps.
	# substitutions is a coderef.
	# insertions is an arrayref with hashrefs with members 'before'
	#   and 'batch', the latter being an arrayref.
	# additions is an arrayref.
	# ----- template -------------------------------------------------------
	'template' => {
		removals => [
			qr//,
		],
		substitutions => sub {},
		insertions => [{
			before => qr//,
			batch => [],
		}],
		additions => [],
	},
	# ----- 1.89 -----------------------------------------------------------
	'1.89' => {
		substitutions => sub {
			s/(['"])(\\[1-6])\1/$2/g;
			s/(printcmd:.*)/$1 \\2/g;
			/cp.*date.*touch.*date/ && s/"(
			[^"()]*
			\$\(
			[^")]*
			(?:"[^"]*")*
			\)
			)"/$1/gx;
		},
		additions => [
			"# convert \$LS_COLORS into an additional colorset?\n",
			"importlscolors:yes\n",
			"\n",
		],
	},
	# ----- 1.90.1 ---------------------------------------------------------
	'1.90.1' => {
		substitutions => sub {
			if (/^(your|launch)/) {
				s/(\$PAGER|\bmore|\bless)\b/\\p/g;
				s/\$VIEWER\b/\\v/g;
				s/\$EDITOR\b/\\e/g;
			}
		},
		additions => [
			"## preferred image editor/viewer (don't specify \\2 here)\n",
			"#viewer:eog\n",
			"viewer:xv\n",
			"\n",
			"## The special set 'framecolors[*]' will be used for every 'dircolors[x]'\n",
			"## for which there is no corresponding 'framecolors[x]' (like ls_colors)\n",
			"framecolors[*]:\\\n",
			"title=reverse:swap=reverse:footer=reverse:highlight=bold:\n",
			"\n",
			"## The special set 'dircolors[*]' will be used for every 'framecolors[x]'\n",
			"## for which there is no corresponding 'dircolors[x]'\n",
			"dircolors[*]:\\\n",
			"di=bold:ln=underscore:\n",
			"\n",
		],
	},
	# ----- 1.90.4 ---------------------------------------------------------
	'1.90.4' => {
		substitutions => sub {
			s/\bviewbase\b/defaultnumbase/g;
		},
	},
	# ----- 1.91.3 ---------------------------------------------------------
	'1.91.3' => {
		removals => [
			qr/^#*\s*(timeformat:|format for entering time:)/,
			qr/^#*\s*touch MMDDhhmm\S* or pfm .*MMDDhhmm/,
		],
	},
	# ----- 1.91.4 ---------------------------------------------------------
	'1.91.4' => {
		substitutions => sub {
			s/\bdefaultnumbase\b/defaultradix/g;
		},
	},
	# ----- 1.91.5 ---------------------------------------------------------
	'1.91.5' => {
		additions => [
			"## clock date/time format; see strftime(3).\n",
			"## %x and %X provide properly localized time and date.\n",
			"## the defaults are \"%Y %b %d\" and \"%H:%M:%S\"\n",
			"## the diskinfo field (f) in the layouts below must be wide enough for this.\n",
			"clockdateformat:%Y %b %d\n",
			"#clocktimeformat:%H:%M:%S\n",
			"#clockdateformat:%x\n",
			"clocktimeformat:%X\n",
			"\n",
		],
	},
	# ----- 1.91.7 ---------------------------------------------------------
	'1.91.7' => {
		substitutions => sub {
			s/^([^#].*nnnn.*)(:\\?)$/$1 ffffffffffffff$2/;
			s{ layouts must not be wider than this! }
			 {-------------- file info -------------};
		},
	},
	# ----- 1.92.0 ---------------------------------------------------------
	'1.92.0' => {
		substitutions => sub {
			s{magic\[Sun/NeXT audio data\](\s*:\s*)audio/basic}
			 {magic\[Sun.NeXT audio data\]$1audio/basic};
			s{(diskinfo field) is as yet only supported as the last column.}
			 {$1 *must* be the _first_ or _last_ field on the line.};
			s{## launch commands.*not implemented.*}
			 {## launch commands};
		},
		insertions => [{
			before => qr/^## [iI]n other words:/,
			batch => [
				'## The option itself may not contain whitespace or colons,'."\n",
				'## except in a classifier enclosed in [] that immediately follows it.'."\n",
				'## In other words: /^\s*([^[:\s]+(?:\[[^]]+\])?)\s*:\s*(.*)$/'."\n",
			],
		}],
	},
	# ----- 1.92.1 ---------------------------------------------------------
	'1.92.1' => {
		substitutions => sub {
			s/^(#*\s*)\bclobber\b/$1defaultclobber/g;
		},
	},
	# ----- 1.92.3 ---------------------------------------------------------
	'1.92.3' => {
		# added 'waitlaunchexec', but this was deprecated later.
		# no need to add it here because it was never implemented.
	},
	# ----- 1.92.6 ---------------------------------------------------------
	'1.92.6' => {
		substitutions => sub {
			s/\bdotmode:\s*yes\b/defaultdotmode: no/g;
			s/\bdotmode:\s*no\b/defaultdotmode: yes/g;
			s/\bwhitemode:\s*yes\b/defaultwhitemode: no/g;
			s/\bwhitemode:\s*no\b/defaultwhitemode: yes/g;
		},
	},
	# ----- 1.93.1 ---------------------------------------------------------
	'1.93.1' => {
		substitutions => sub {
			s/\\([1-7epv])/=$1/g;
			s/\\\\/==/g;
		},
		additions => [
			"extension[*.dvi] : application/x-dvi\n",
			"extension[*.jar] : application/zip\n",
			"extension[*.man] : application/x-groff-man\n",
			"extension[*.mm]  : application/x-groff-mm\n",
			"extension[*.pdb] : chemical/x-pdb\n",
			"magic[TeX DVI file] : application/x-dvi\n",
			"\n",
			"## the character that pfm recognizes as special abbreviation character\n",
			"## (default =)\n",
			"## previous versions used \\ (note that this leads to confusing results)\n",
			"#escapechar:=\n",
			"#escapechar:\\\n",
			"\n",
		],
	},
	# ----- 1.93.8 ---------------------------------------------------------
	'1.93.8' => {
		additions => [
			"## use xterm alternate screen buffer (yes,no,xterm) (default: only in xterm)\n",
			"altscreenmode:xterm\n",
			"\n",
			"## command used for starting a new pfm window for a directory. \n",
			"## Only applicable under X. The default is to take gnome-terminal under \n",
			"## Linux, xterm under other Unices. \n",
			"## Be sure to include the option to start a program in the window. \n",
			"#windowcmd:gnome-terminal -e \n",
			"#windowcmd:xterm -e \n",
			"\n",
		],
	},
	# ----- 1.94.0 ---------------------------------------------------------
	'1.94.0' => {
		additions => [
			"## command to perform automatically after every chdir()\n",
			"#chdirautocmd:printf \"\\033]0;pfm - \$(basename \$(pwd))\\007\"\n",
			"\n",
		],
	},
	# ----- 1.94.2 ---------------------------------------------------------
	'1.94.2' => {
		additions => [
			"## request rcs status automatically?\n",
			"autorcs:yes\n",
			"\n",
			"## command to use for requesting the file status in your rcs system.\n",
			"rcscmd:svn status\n",
			"\n",
		],
	},
	# ----- 1.94.8 ---------------------------------------------------------
	'1.94.8' => {
		additions => [
			"extension[*.odp]  : application/x-openoffice\n",
			"extension[*.ods]  : application/x-openoffice\n",
			"extension[*.odt]  : application/x-openoffice\n",
			"launch[application/x-openoffice]  : ooffice =2 &\n",
			"\n",
		],
	},
	# ----- 1.95.1 ---------------------------------------------------------
	'1.95.1' => {
		additions => [
			"## is it always \"OK to remove marks?\" without confirmation?\n",
			"remove_marks_ok:no\n",
			"\n",
		],
	},
	# ----- 1.95.2 ---------------------------------------------------------
	'1.95.2' => {
		# this option was deprecated later
		additions => [
			"## automatically check for updates on exit (default: no) \n",
			"checkforupdates:no \n",
			"\n",
		],
	},
	# ----- 2.00.0 ---------------------------------------------------------
	'2.00.0' => {
		substitutions => sub {
			s/(^|:)header=/${1}menu=/;
			s/(^|:)title=/${1}headings=/;
		},
	},
	# ----- 2.01.7 ---------------------------------------------------------
	'2.01.7' => {
		removals => [
			qr/^#*\s*checkforupdates:/,
			qr/^#+\s*automatically check for updates on exit/,
		],
	},
	# ----- 2.03.7 ---------------------------------------------------------
	'2.03.7' => {
		removals => [
			qr/^[ #]*waitlaunchexec:/,
			qr/^[ #]*wait for launched executables to finish/,
		],
	},
	# ----- 2.04.4 ---------------------------------------------------------
	'2.04.4' => {
		additions => [
			"## commandline options to add to the cp(1) command, in the first place for\n",
			"## changing the 'follow symlinks' behavior.\n",
			"#copyoptions:-P\n",
			"\n",
		],
	},
	# ----- 2.05.3 ---------------------------------------------------------
	'2.05.3' => {
		additions => [
			"extension[*.3pm]  : application/x-nroff-man\n",
			"extension[*.js]   : application/javascript\n",
			"extension[*.m3u]  : text/x-m3u-playlist\n",
			"extension[*.sql]  : application/x-sql\n",
			"\n",
			"launch[application/javascript]    : =e =2\n",
			"launch[application/x-sql]         : =e =2\n",
			"launch[audio/mpeg]                : vlc =2 >/dev/null 2>&1\n",
			"launch[text/x-m3u-playlist]       : vlc =2 >/dev/null 2>&1\n",
			"\n",
		],
	},
	# ----- 2.05.9 ---------------------------------------------------------
	'2.05.9' => {
		removals => [
			qr/^#*\s*windowcmd:/,
			qr/^#+\s*command used for starting a new pfm window for a directory/,
			qr/^#+\s*Only applicable.*The default is to take gnome-terminal/,
			qr/^#+\s*Linux, xterm under other Uni[xc]es/,
			qr/^#+\s*Be sure to include the option to start a program/,
		],
		additions => [
			"## Command used for starting a new directory window. Only useful under X.\n",
			"##\n",
			"## If 'windowtype' is 'standalone', then this command will be started\n",
			"## and the current directory will be passed on the commandline.\n",
			"## The command is responsible for opening its own window.\n",
			"##\n",
			"## If 'windowtype' is 'pfm', then 'windowcmd' should be a terminal\n",
			"## command, which will be used to start pfm (the default is to use\n",
			"## gnome-terminal for linux and xterm for other Unices).\n",
			"## Be sure to include the option to start a program in the window\n",
			"## (for xterm, this is -e).\n",
			"##\n",
			"#windowcmd:gnome-terminal -e\n",
			"#windowcmd:xterm -e\n",
			"#windowcmd:nautilus\n",
			"\n",
			"## What to open when a directory is middle-clicked with the mouse?\n",
			"## 'pfm'       : open directories with pfm in a terminal window.\n",
			"##               specify the terminal command with 'windowcmd'.\n",
			"## 'standalone': open directories in a new window with the 'windowcmd'.\n",
			"#windowtype:standalone\n",
			"windowtype:pfm\n",
			"\n",
		],
	},
	# ----- 2.06.0 ---------------------------------------------------------
	'2.06.0' => {
		additions => [
			"## write bookmarks to file automatically upon exit\n",
			"autowritebookmarks:yes\n",
			"\n",
		],
	},
	# ----- 2.06.1 ---------------------------------------------------------
	'2.06.1' => {
		additions => [
			"## sort modes to cycle through when clicking 'Sort' in the footer.\n",
			"## default: nNeEdDaAsStu\n",
			"#sortcycle:nNeEdDaAsStu\n",
			"\n",
		],
	},
	# ----- 2.06.2 ---------------------------------------------------------
	'2.06.2' => {
		additions => [
			"## pfm does not support a terminal size of less than 80 columns or 24 rows.\n",
			"## this option will make pfm try to resize the terminal to the minimum\n",
			"## dimensions if it is resized too small.\n",
			"## valid options: yes,no,xterm.\n",
			"force_minimum_size:xterm\n",
			"\n",
		],
	},
	# ----- 2.06.3 ---------------------------------------------------------
	'2.06.3' => {
		additions => [
			"## In case the regular editor automatically forks in the background, you\n",
			"## may want to specify a foreground editor here. If defined, this editor\n",
			"## will be used for editing the config file, so that pfm will be able to\n",
			"## wait for the editor to finish before rereading the config file.\n",
			"#fg_editor:vim\n",
			"\n",
		],
	},
	# ----- 2.06.4 ---------------------------------------------------------
	'2.06.4' => {
		additions => [
			"## automatically sort the directory's contents again after a\n",
			"## (T)ime or (U)ser command? (default: yes)\n",
			"#autosort:yes\n",
			"\n",
		],
	},
	# ----- 2.06.9 ---------------------------------------------------------
	'2.06.9' => {
		removals => [
			qr/^[# ]*ducmd:/,
			qr/^[# ]*your system's du.+command.+needs.+for the current filename/,
			qr/^[# ]*[sS]pecify so that the outcome is in bytes/,
			qr/^[# ]*this is commented out because pfm makes a clever guess for your OS/,
		],
	},
	# ----- 2.08.0 ---------------------------------------------------------
	'2.08.0' => {
		substitutions => sub {
			s{## do=door nt=network special .not implemented. wh=whiteout}
			 {## do=door nt=network special wh=whiteout ep=event pipe};
			s{(^|:)(pi=[^:]*:so=[^:]*:)}
			 {$1$2ep=black on yellow:};
			s{^(dircolors[^:]*:no=[^:]*:fi=)reset:}
			 {$1:};
		},
	},
	# ----- 2.08.1 ---------------------------------------------------------
	'2.08.1' => {
		removals => [],
		substitutions => sub {
			s{## no=normal fi=file ex=executable lo=lost file ln=symlink or=orphan link}
			 {## no=normal fi=file lo=lost file ln=symlink or=orphan link hl=hard link};
			s{ln=([^:]*):or=([^:]*):}
			 {ln=$1:or=$2:hl=white on blue:};
		},
		insertions => [{
			before => qr/^([^#]*:|)wh=([^:]*):/,
			batch => [
				"su=white on red:sg=black on yellow:\\\n",
				"ow=blue on green:st=white on blue:tw=black on green:\\\n",
			],
		}, {
			before => qr/## ..<ext> defines extension colors/,
			batch => [
				"## ex=executable su=setuid sg=setgid ca=capability (not implemented)\n",
				"## ow=other-writable dir (d???????w?) st=sticky dir (d????????t)\n",
				"## tw=sticky and other-writable dir (d???????wt)\n",
			],
		}],
		additions => [
			"## overlay the highlight color onto the current filename? (default yes)\n",
			"highlightname:yes\n",
			"\n",
			"## characteristics of the mouse wheel: the number of lines that the\n",
			"## mouse wheel will scroll. This can be an integer or 'variable'.\n",
			"#mousewheeljumpsize:5\n",
			"mousewheeljumpsize:variable\n",
			"\n",
			"## if 'mousewheeljumpsize' is 'variable', the next two values are taken\n",
			"## into account.\n",
			"## 'mousewheeljumpratio' is used to calculate the number of lines that\n",
			"## the cursor will jump, namely: the total number of enties in the\n",
			"## directory divided by 'mousewheeljumpratio'.\n",
			"## 'mousewheeljumpmax' sets an upper bound to the number of lines that\n",
			"## the cursor is allowed to jump when using the mousewheel.\n",
			"mousewheeljumpratio:4\n",
			"mousewheeljumpmax:11\n",
			"\n",
		],
	},
	# ----- 2.08.2 ---------------------------------------------------------
	'2.08.2' => {
		removals => [
			qr/^[# ]*rcscmd:/,
			qr/^[# ]*command to use for requesting the file status in your rcs system/,
		],
		substitutions => sub {
			s{'mousewheeljumpmax' sets an upper bound to the number of lines that}
			 {'mousewheeljumpmin' and 'mousewheeljumpmax' set bounds to the number};
			s{the cursor is allowed to jump when using the mousewheel.}
			 {of lines that the cursor is allowed to jump when using the mousewheel.};
			# these should have been done in an earlier version.
			s{initial sort mode .nNmMeEfFsSzZiItTdDaA. }
			 {initial sort mode (nNmMeEfFdDaAsSzZtTuUgGvViI*) };
			s{F7 key swap path method is persistent...default no.}
			 {F7 key swap path method is persistent? (default yes)};
			s{title, title in swap mode}
			 {headings, headings in swap mode};
			s{colors for header, header in multiple mode}
			 {colors for menu, menu in multiple mode};
		},
		insertions => [{
			before => qr/^[ #]*mousewheeljumpmax:/,
			batch => [
				"mousewheeljumpmin:1\n",
			],
		}, {
			# this should have been done in an earlier version.
			before => qr/^clsonexit:/,
			batch => [
				"## Has no effect if altscreenmode is set.\n",
			],
		}, {
			# this should have been done in an earlier version.
			before => qr/^[ #]*fg_editor:/,
			batch => [
				"## It will also be used for editing ACLs.\n",
			],
		}],
		additions => [
			"## Must 'Hit any key to continue' also accept mouse clicks?\n",
			"clickiskeypresstoo:yes\n",
			"\n",
		],
	},
	# ----- 2.08.4 ---------------------------------------------------------
	'2.08.4' => {
		removals => [
			qr/Term::Screen needs these additions/,
		],
		substitutions => sub {
			s/^## default:\s*nNeEdDaAsStu/## default: n,en,dn,Dn,sn,Sn,tn,un/;
			s{(sortcycle:\s*)(\w+)$}
			 {$1 . join ',', split(//, $2)}eo;
		},
	},
};

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self) = @_;
}

=item _by_pfmrc_rules()

Sorting subroutine. Sorts the vim(1) modeline last.

=cut

sub _by_pfmrc_rules {
	my $modeline = qr/\bvi\w*:[ \cI]+set[ \cI].*\bfiletype=xdefaults\b/o;
	if ($a =~ /$modeline/) { return  1 }
	if ($b =~ /$modeline/) { return -1 }
	return 0;
}

=item _sort_pfmrc(arrayref $text)

Sorts the lines in the F<pfmrc> text.

=cut

sub _sort_pfmrc {
	my ($self, $text) = @_;
	@$text = sort _by_pfmrc_rules @$text;
}

=item _cross(string $cross, string $from, string $to)

Determines if a certain version I<cross> is crossed when updating
from I<from> to I<to>.

=cut

sub _cross {
	my ($self, $cross, $from, $to) = @_;
	return ($from lt $cross and $cross le $to);
}

=item _remove(arrayref $text, array @regexps)

Removes matching lines from the config text.

=cut

sub _remove {
	my ($self, $lines, @regexps) = @_;
	LINE: foreach my $i (reverse 0 .. $#$lines) {
		REGEXP: foreach (@regexps) {
			if (${$lines}[$i] =~ /$_/) {
				splice(@$lines, $i, 1);
				next LINE;
			}
		}
	}
}

=item _append(arrayref $text, array @addition)

Adds the specified lines at the end of the config text.

=cut

sub _append {
	my ($self, $lines, @addition) = @_;
	if ($#addition == 0) {
		@addition = split (/(?<=\n)/, $addition[0]);
	}
	push @$lines, @addition;
}

=item _insertbefore(arrayref $text, regexp $where, array @addition)

Adds the specified lines at the specified place in the config text.

=cut

sub _insertbefore {
	my ($self, $lines, $where, @addition) = @_;
	if ($#addition == 0) {
		@addition = split (/(?<=\n)/, $addition[0]);
	}
	foreach my $i (reverse 0 .. $#$lines) {
		if (${$lines}[$i] =~ /$where/) {
			# this changes the total number of lines, but this does not
			# matter because we are processing the list in reverse order.
			splice(@$lines, $i, 0, @addition);
		}
	}
}

=item _substitute(arrayref $text, coderef $substitutor)

Executes the I<substitutor> code for all lines in the config text.

=cut

sub _substitute {
	my ($self, $lines, $substitutor) = @_;
	local $_;
	if (!ref($substitutor)) { # TODO
		cluck "substitutor is no ref"; # TODO
	} # TODO

	foreach (@$lines) {
		$substitutor->();
	}
}

=item _get_locale()

Finds the locale that is currently in use for LC_TIME.

=cut

sub _get_locale {
	my ($self) = @_;
	open PIPE, 'locale|';
	my @lines = grep /^LC_TIME/, <PIPE>;
	close PIPE;
	chomp @lines;
	return $lines[0];
}

=item _get_pfmrc_timefieldlen(arrayref $text)

Determines the minimum length of a Unix 'ctime', 'mtime' or 'atime'
column.

=cut

sub _get_pfmrc_timefieldlen {
	my ($self, $text) = @_;
	my @layouts = grep /^[^#].*ffffffffffffff/, @$text;
	my $minlength = 80;
	my ($mlength, $clength, $alength);
	foreach (@layouts) {
		$mlength = tr/m// || 80;
		$clength = tr/c// || 80;
		$alength = tr/a// || 80;
		$minlength = min($minlength, $mlength, $clength, $alength);
	}
	return $minlength;
}

=item _get_pfmrc_timefieldformat(arrayref $text)

Determines the minimum length of the format as determined by the
'timestampformat' column.

=cut

sub _get_pfmrc_timefieldformat {
	my ($self, $text) = @_;
	my $timefieldformat = (grep /^timestampformat:/, @$text)[0];
	$timefieldformat =~ s/^[^:]*?:(.*)$/$1/;
	chomp $timefieldformat;
	return $timefieldformat;
}

=item I<_update_to_>versionZ<>()

=cut

=item _update_version_identifier

Updates the 'Version:' line in I<text> to the new version.

=cut

sub _update_version_identifier {
	my ($self, $to, $lines) = @_;
	# this updates the version field for any version
	$self->_substitute($lines, sub {
		s/^(#.*?Version\D+)[[:alnum:].]+/$1$to/;
	});
}

=item _update_text(string $version_from, string $version_to, arrayref $text)

Updates the array indicated by I<text> to the new version by adding
any new config options, removing deprecated ones, and updating
definitions that have changed.

=cut

sub _update_text {
	my ($self, $from, $to, $lines) = (@_);
	my %updates = %{UPDATES()};
	my ($version, $change);
	foreach $version (sort keys %updates) {
		next unless $self->_cross($version, $from, $to);
		foreach $change ($updates{$version}{removals}) {
			$self->_remove($lines, @$change);
		}
		if (defined($change = $updates{$version}{substitutions})) {
			$self->_substitute($lines, $change);
		}
		foreach $change (@{$updates{$version}{insertions}}) {
			$self->_insertbefore($lines, $change->{before}, @{$change->{batch}});
		}
		foreach $change ($updates{$version}{additions}) {
			$self->_append($lines, @$change);
		}
	}
	$self->_update_version_identifier($to, $lines);
}

##########################################################################
# public subs

=item check_date_locale(arrayref $text)

Checks the 'columnlayouts' option to see if it can accommodate date/time
strings localized according to your current locale (as defined by LC_ALL
or LC_TIME).

=cut

sub check_date_locale {
	my ($self, $text) = @_;
	my $timefieldlen    = $self->_get_pfmrc_timefieldlen($text);
	my $timefieldformat = $self->_get_pfmrc_timefieldformat($text);
	my $locale          = $self->_get_locale();
	#
	my ($mon, $timestr, $maxtimelength);
	foreach $mon (0..11) {
		# (sec, min, hour, mday, mon, year, wday = 0, yday = 0, isdst = -1)
		$timestr = strftime($timefieldformat, (0, 30, 10, 12, $mon, 95));
		$maxtimelength = max(length($timestr), $maxtimelength);
	}
	if ($maxtimelength > $timefieldlen) {
		print <<_LOCALE_WARNING_

Warning: Your date/time locale is set to $locale. In this locale,
the configured timestampformat of '$timefieldformat' in your .pfmrc may
require up to $maxtimelength characters.

Some of the layouts in your .pfmrc only allow for $timefieldlen characters.

Please verify that your file timestamps don't look truncated, otherwise
please change the 'columnlayouts' or 'timestampformat' option manually.

_LOCALE_WARNING_
	}
}

=item update(string $version_pfmrc, string $version_pfm, arrayref $text)

Updates the lines in the array pointed to by I<$text>.

=cut

sub update {
	my ($self, $version_pfmrc, $version_pfm, $text) = @_;
	return if $version_pfmrc ge $version_pfm;

	$self->check_date_locale($text);
	$self->_update_text($version_pfmrc, $version_pfm, $text);
	$self->_sort_pfmrc($text);
}

##########################################################################

1;

__END__

=back

SEE ALSO

pfm(1), locale(7). App::PFM::Config(3pm).

=cut

# vim: set tabstop=4 shiftwidth=4:

