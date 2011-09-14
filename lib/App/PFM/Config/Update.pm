#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Config::Update 2.08.1
#
# Name:			App::PFM::Config::Update
# Version:		2.08.1
# Author:		Rene Uittenbogaard
# Created:		2010-05-28
# Date:			2010-09-02
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

use strict;
use locale;

our ($_pfm);

##########################################################################
# private subs

=item _init( [ bool $amphibian ] )

Initializes new instances. Called from the constructor.
The I<amphibian> parameter specifies if the F<.pfmrc> should be kept
in a format that is suitable for both C<pfm> versions 1 and 2.

=cut

sub _init {
	my ($self, $amphibian) = @_;
	$self->{_amphibian} = $amphibian;
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

############################################################################
# private update subs

=item I<_update_to_>versionZ<>()

Updates the I<text> to the new version by adding and removing
options, and updating definitions that have changed.

=cut

sub _update_to_184 {
	my ($self, $lines) = @_;
	# this updates (Y)our commands for version 1.84
	print "Updating to 1.84...\n";
	s/^(\s*)([[:upper:]])(\s*):(.*)$/$1your[\l$2]$3:$4/ foreach @$lines;
	s/^(\s*)([[:lower:]])(\s*):(.*)$/$1your[\u$2]$3:$4/ foreach @$lines;
}

sub _update_to_188 {
	my ($self, $lines) = @_;
	# this replaces the pre-1.88 colors by 1.88-style colors.
	print "Updating to 1.88...\n";
	my %attributes = reverse ( 'black'      => 30,  'on_black'   => 40,
		'reset'      => '00',  'red'        => 31,  'on_red'     => 41,
		'bold'       => '01',  'green'      => 32,  'on_green'   => 42,
		'underline'  => '04',  'yellow'     => 33,  'on_yellow'  => 43,
		                       'blue'       => 34,  'on_blue'    => 44,
		'blink'      => '05',  'magenta'    => 35,  'on_magenta' => 45,
		'inverse'    => '07',  'cyan'       => 36,  'on_cyan'    => 46,
		'concealed'  => '08',  'white'      => 37,  'on_white'   => 47,
	);
	foreach (@$lines) {
		!/^#/ && /[=;]/ && s/\b([034]\d)\b/$attributes{$1}/g && tr/;/ /;
	}
}

sub _update_to_189 {
	my ($self, $lines) = @_;
	# this updates quoting in commands for version 1.89
	print "Updating to 1.89...\n";
	my $warned = 0;
	foreach (@$lines) {
		s/(['"])(\\[1-6])\1/$2/g;
		s/(printcmd:.*)/$1 \\2/g;
		/cp.*date.*touch.*date/ && s/"(
		[^"()]*
		\$\(
		[^")]*
		(?:"[^"]*")*
		\)
		)"/$1/gx;
		if (/\$\(.*\)/ and !$warned) {
			print "\nWarning: Quoting \$(..) constructs can be tricky.\n";
			print "Please double-check your .pfmrc. I'm imperfect.\n";
			$warned++;
		}
	}
	push @$lines, <<'_end_update_to_189_';

# convert $LS_COLORS into an additional colorset?
importlscolors:yes
	
_end_update_to_189_
}

sub _update_to_1901 {
	my ($self, $lines) = @_;
	# added 'viewer' option
	# added dir/framecolors[*] option
	# added '\[epv]' escapes
	foreach (@$lines) {
		if (/^(your|launch)/) {
			s/(\$PAGER|\bmore|\bless)\b/\\p/g;
			s/\$VIEWER\b/\\v/g;
			s/\$EDITOR\b/\\e/g;
		}
	}
	push @$lines, <<'_end_update_to_1901_';

## preferred image editor/viewer (don't specify \2 here)
#viewer:eog
viewer:xv

## The special set 'framecolors[*]' will be used for every 'dircolors[x]'
## for which there is no corresponding 'framecolors[x]' (like ls_colors)
framecolors[*]:\
title=reverse:swap=reverse:footer=reverse:highlight=bold:

## The special set 'dircolors[*]' will be used for every 'framecolors[x]'
## for which there is no corresponding 'dircolors[x]'
dircolors[*]:\
di=bold:ln=underscore:

_end_update_to_1901_
}

sub _update_to_1904 {
	my ($self, $lines) = @_;
	# changed config option 'viewbase' to 'defaultnumbase'
	print "Updating to 1.90.4...\n";
	foreach (@$lines) {
		s/\bviewbase\b/defaultnumbase/g;
	}
}

sub _update_to_1913 {
	my ($self, $lines) = @_;
	# this removes 'timeformat' for version 1.91.3
	print "Updating to 1.91.3...\n";
	my $i;
	for ($i = $#$lines; $i > 0; $i--) {
		if (${$lines}[$i] =~ /^#*\s*(timeformat:|format for entering time:)/
		or ${$lines}[$i] =~ /^#*\s*touch MMDDhhmm\S* or pfm .*MMDDhhmm/)
		{
			splice(@{$lines}, $i, 1);
		}
	}
}

sub _update_to_1914 {
	my ($self, $lines) = @_;
	# changed config option 'defaultnumbase' to 'defaultradix'
	print "Updating to 1.91.4...\n";
	foreach (@$lines) {
		s/\bdefaultnumbase\b/defaultradix/g;
	}
}

sub _update_to_1915 {
	my ($self, $lines) = @_;
	# added 'clockdateformat' and 'clocktimeformat' options
	print "Updating to 1.91.5...\n";
	push @$lines, <<_end_update_to_1915_;

## clock date/time format; see strftime(3).
## %x and %X provide properly localized time and date.
## the defaults are "%Y %b %d" and "%H:%M:%S"
## the diskinfo field (f) in the layouts below must be wide enough for this.
clockdateformat:%Y %b %d
#clocktimeformat:%H:%M:%S
#clockdateformat:%x
clocktimeformat:%X

_end_update_to_1915_
}

sub _update_to_1917 {
	my ($self, $lines) = @_;
	# this adds a diskinfo column (f-column) to pre-1.91.7 config files
	print "Updating to 1.91.7...\n";
	foreach (@$lines) {
		s/^([^#].*nnnn.*)(:\\?)$/$1 ffffffffffffff$2/;
		s{ layouts must not be wider than this! }
		 {-------------- file info -------------};
	}
}

sub _update_to_1920 {
	my ($self, $lines) = @_;
	# changes important comments.
	print "Updating to 1.92.0...\n";
	my $i;
	foreach (@$lines) {
		s{magic\[Sun/NeXT audio data\](\s*:\s*)audio/basic}
		 {magic\[Sun.NeXT audio data\]$1audio/basic};
		s{(diskinfo field) is as yet only supported as the last column.}
		 {$1 *must* be the _first_ or _last_ field on the line.};
		s{## launch commands.*not implemented.*}
		 {## launch commands};
	}
	my @new = (
"## the option itself may not contain whitespace or colons,\n",
"## except in a classifier enclosed in [] that immediately follows it.\n",
'## in other words: /^\s*([^[:\s]+(?:\[[^]]+\])?)\s*:\s*(.*)$/'."\n",
);
	for ($i = $#$lines; $i > 0; $i--) {
		if (${$lines}[$i] =~ /## in other words:/) {
			splice @$lines, $i, 1, @new;
		}
	}
}

sub _update_to_1921 {
	my ($self, $lines) = @_;
	# changed option 'clobber' to 'defaultclobber'
	print "Updating to 1.92.1...\n";
	foreach (@$lines) {
		s/^(#*\s*)\bclobber\b/$1defaultclobber/g;
	}
}

sub _update_to_1923 {
	my ($self, $lines) = @_;
	# added 'waitlaunchexec', but this was deprecated later.
	# no need to add it here because it was never implemented.
}

sub _update_to_1926 {
	my ($self, $lines) = @_;
	# inverted meaning of 'defaultdotmode' and 'defaultwhitemode'
	print "Updating to 1.92.6...\n";
	foreach (@$lines) {
		s/\bdotmode:\s*yes\b/defaultdotmode: no/g;
		s/\bdotmode:\s*no\b/defaultdotmode: yes/g;
		s/\bwhitemode:\s*yes\b/defaultwhitemode: no/g;
		s/\bwhitemode:\s*no\b/defaultwhitemode: yes/g;
	}
}

sub _update_to_1931 {
	my ($self, $lines) = @_;
	# added 'escapechar'; changed default escape char.
	print "Updating to 1.93.1...\n";
	foreach (@$lines) {
		s/\\([1-7epv])/=$1/g;
		s/\\\\/==/g;
	}
	push @$lines, <<'_end_update_to_1931_';

extension[*.dvi] : application/x-dvi
extension[*.jar] : application/zip
extension[*.man] : application/x-groff-man
extension[*.mm]  : application/x-groff-mm
extension[*.pdb] : chemical/x-pdb
magic[TeX DVI file] : application/x-dvi

## the character that pfm recognizes as special abbreviation character
## (default =)
## previous versions used \ (note that this leads to confusing results)
#escapechar:=
#escapechar:\

_end_update_to_1931_
}

sub _update_to_1938 {
	my ($self, $lines) = @_;
	# added 'altscreenmode'
	print "Updating to 1.93.8...\n";
	push @$lines, <<'_end_update_to_1938_';

## use xterm alternate screen buffer (yes,no,xterm) (default: only in xterm)
altscreenmode:xterm

## command used for starting a new pfm window for a directory. 
## Only applicable under X. The default is to take gnome-terminal under 
## Linux, xterm under other Unixes. 
## Be sure to include the option to start a program in the window. 
#windowcmd:gnome-terminal -e 
#windowcmd:xterm -e 

_end_update_to_1938_
}

sub _update_to_1942 {
	my ($self, $lines) = @_;
	# subversion support; 'rcscmd', 'autorcs'
	print "Updating to 1.94.2...\n";
	push @$lines, <<_end_update_to_1942_;

## request rcs status automatically?
autorcs:yes

## command to use for requesting the file status in your rcs system.
rcscmd:svn status

_end_update_to_1942_
}

sub _update_to_1948 {
	my ($self, $lines) = @_;
	# added openoffice document extensions to default .pfmrc
	print "Updating to 1.94.8...\n";
	push @$lines, <<_end_update_to_1948_;

extension[*.odp]  : application/x-openoffice
extension[*.ods]  : application/x-openoffice
extension[*.odt]  : application/x-openoffice
launch[application/x-openoffice]  : ooffice =2 &

_end_update_to_1948_
}

sub _update_to_1951 {
	my ($self, $lines) = @_;
	# added 'remove_marks_ok' option
	print "Updating to 1.95.1...\n";
	push @$lines, <<_end_update_to_1951_;

## is it always "OK to remove marks?" without confirmation?
remove_marks_ok:no

_end_update_to_1951_
}

sub _update_to_1952 {
	my ($self, $lines) = @_;
	# added 'checkforupdates' option (was deprecated later).
	print "Updating to 1.95.2...\n";
	push @$lines, <<_end_update_to_1952_;

## automatically check for updates on exit (default: no) 
checkforupdates:no 

_end_update_to_1952_
}

sub _update_to_200 {
	my ($self, $lines) = @_;
	# this updates the framecolors for version 2.00
	print "Updating to 2.00...\n";
	if ($self->{_amphibian}) {
		foreach (@$lines) {
			s/(^|:)(header=)([^:]*)/$1$2$3:menu=$3/;
			s/(^|:)(title=)([^:]*)/$1$2$3:headings=$3/;
		}
	} else {
		foreach (@$lines) {
			s/(^|:)header=/${1}menu=/;
			s/(^|:)title=/${1}headings=/;
		}
	}
}

sub _update_to_2017 {
	my ($self, $lines) = @_;
	return if $self->{_amphibian};
	# this removes 'checkforupdates' for version 2.01.7
	print "Updating to 2.01.7...\n";
	my $i;
	for ($i = $#$lines; $i > 0; $i--) {
		if (${$lines}[$i] =~ /^#*\s*checkforupdates:/
		or  ${$lines}[$i] =~ /^#+\s*automatically check for updates on exit/)
		{
			splice(@$lines, $i, 1);
		}
	}
}

sub _update_to_2037 {
	my ($self, $lines) = @_;
	return if $self->{_amphibian};
	# this removes 'waitlaunchexec' for version 2.03.7
	print "Updating to 2.03.7...\n";
	my $i;
	for ($i = $#$lines; $i > 0; $i--) {
		if (${$lines}[$i] =~ /^#*\s*waitlaunchexec:/
		or  ${$lines}[$i] =~ /^#+\s*wait for launched executables to finish/)
		{
			splice(@$lines, $i, 1);
		}
	}
}

sub _update_to_2044 {
	my ($self, $lines) = @_;
	# added 'copyoptions'
	print "Updating to 2.04.4...\n";
	push @$lines, <<_end_update_to_2044_;

## commandline options to add to the cp(1) command, in the first place for
## changing the 'follow symlinks' behavior.
#copyoptions:-P

_end_update_to_2044_
}

sub _update_to_2053 {
	my ($self, $lines) = @_;
	# added extra MIME types
	print "Updating to 2.05.3...\n";
	push @$lines, <<_end_update_to_2053_;

extension[*.3pm]  : application/x-nroff-man
extension[*.js]   : application/javascript
extension[*.m3u]  : text/x-m3u-playlist
extension[*.sql]  : application/x-sql

launch[application/javascript]    : =e =2
launch[application/x-sql]         : =e =2
launch[audio/mpeg]                : vlc =2 >/dev/null 2>&1
launch[text/x-m3u-playlist]       : vlc =2 >/dev/null 2>&1

_end_update_to_2053_
}

sub _update_to_2059 {
	my ($self, $lines) = @_;
	# added 'windowtype'
	print "Updating to 2.05.9...\n";
	my $i;
	for ($i = $#$lines; $i > 0; $i--) {
		if (${$lines}[$i] =~ /^#*\s*windowcmd:/
		or  ${$lines}[$i] =~ /^#+\s*command used for starting a new pfm window for a directory/
		or  ${$lines}[$i] =~ /^#+\s*Only applicable.*The default is to take gnome-terminal/
		or  ${$lines}[$i] =~ /^#+\s*Linux, xterm under other Unixes/
		or  ${$lines}[$i] =~ /^#+\s*Be sure to include the option to start a program/)
		{
			splice(@$lines, $i, 1);
		}
	}
	push @$lines, <<_end_update_to_2059_;

## Command used for starting a new directory window. Only useful under X.
##
## If 'windowtype' is 'standalone', then this command will be started
## and the current directory will be passed on the commandline.
## The command is responsible for opening its own window.
##
## If 'windowtype' is 'pfm', then 'windowcmd' should be a terminal
## command, which will be used to start pfm (the default is
## gnome-terminal for linux and xterm for other Unixes.
## Be sure to include the option to start a program in the window
## (for xterm, this is -e).
##
#windowcmd:gnome-terminal -e
#windowcmd:xterm -e
#windowcmd:nautilus

## What to open when a directory is middle-clicked with the mouse?
## 'pfm'       : open directories with pfm in a terminal window.
##				 specify the terminal command with 'windowcmd'.
## 'standalone': open directories in a new window with the 'windowcmd'.
#windowtype:standalone
windowtype:pfm

_end_update_to_2059_
}

sub _update_to_2060 {
	my ($self, $lines) = @_;
	# added 'autowritebookmarks'
	print "Updating to 2.06.0...\n";
	push @$lines, <<_end_update_to_2060_;

## write bookmarks to file automatically upon exit
autowritebookmarks:yes

_end_update_to_2060_
}

sub _update_to_2061 {
	my ($self, $lines) = @_;
	# added 'sortcycle'
	print "Updating to 2.06.1...\n";
	push @$lines, <<_end_update_to_2061_;

## sort modes to cycle through when clicking 'Sort' in the footer.
## default: nNeEdDaAsStu
#sortcycle:nNeEdDaAsStu

_end_update_to_2061_
}

sub _update_to_2062 {
	my ($self, $lines) = @_;
	# added 'force_minimum_size'
	print "Updating to 2.06.2...\n";
	push @$lines, <<_end_update_to_2062_;

## pfm does not support a terminal size of less than 80 columns or 24 rows.
## this option will make pfm try to resize the terminal to the minimum
## dimensions if it is resized too small.
## valid options: yes,no,xterm.
force_minimum_size:xterm

_end_update_to_2062_
}

sub _update_to_2063 {
	my ($self, $lines) = @_;
	# added 'fg_editor'
	print "Updating to 2.06.3...\n";
	push @$lines, <<_end_update_to_2063_;

## In case the regular editor automatically forks in the background, you
## may want to specify a foreground editor here. If defined, this editor
## will be used for editing the config file, so that pfm will be able to
## wait for the editor to finish before rereading the config file.
#fg_editor:vim

_end_update_to_2063_
}

sub _update_to_2064 {
	my ($self, $lines) = @_;
	# added 'autosort'
	print "Updating to 2.06.4...\n";
	push @$lines, <<_end_update_to_2064_;

## automatically sort the directory's contents again after a
## (T)ime or (U)ser command? (default: yes)
#autosort:yes

_end_update_to_2064_
}

sub _update_to_2069 {
	my ($self, $lines) = @_;
	return if $self->{_amphibian};
	# deprecated 'ducmd'
	print "Updating to 2.06.9...\n";
	my $i;
	for ($i = $#$lines; $i > 0; $i--) {
		if (${$lines}[$i] =~ /^#*\s*ducmd:/
		or  ${$lines}[$i] =~ /^#+\s*your system's du.+command.+needs.+for the current filename/
		or  ${$lines}[$i] =~ /^#+\s*specify so that the outcome is in bytes/
		or  ${$lines}[$i] =~ /^#+\s*this is commented out because pfm makes a clever guess for your OS/)
		{
			splice(@$lines, $i, 1);
		}
	}
}

sub _update_to_2080 {
	my ($self, $lines) = @_;
	# added color option for event pipes
	print "Updating to 2.08.0...\n";
	foreach (@$lines) {
		s{## do=door nt=network special .not implemented. wh=whiteout}
		 {## do=door nt=network special wh=whiteout ep=event pipe};
		s{(^|:)(pi=[^:]*:so=[^:]*:)}
		 {$1$2ep=black on yellow:};
		s{^(dircolors[^:]*:no=[^:]*:fi=)reset:}
		 {$1:};
	}
}

sub _update_to_2081 {
	my ($self, $lines) = @_;
	# added 'mousewheeljump{size,max,ratio}' and 'highlightname'
	print "Updating to 2.08.1...\n";
	foreach my $i (reverse 0 .. $#$lines) {
		${$lines}[$i] =~
			s{## no=normal fi=file ex=executable lo=lost file ln=symlink or=orphan link}
			 {## no=normal fi=file lo=lost file ln=symlink or=orphan link hl=hard link};
		${$lines}[$i] =~
			s{ln=([^:]*):or=([^:]*):}
			 {ln=$1:or=$2:hl=white on blue:};
		if (${$lines}[$i] =~ /^([^#]*:|)wh=([^:]*):/) {
			# this changes the total number of lines, but this does not
			# matter because we are processing the list in reverse order.
			splice(@$lines, $i, 0, <<_end_update_1_to_2081_);
su=white on red:sg=black on yellow:\\
ow=blue on green:st=white on blue:tw=black on green:\\
_end_update_1_to_2081_
		}
		if (${$lines}[$i] =~ /## ..<ext> defines extension colors/) {
			# this changes the total number of lines, but this does not
			# matter because we are processing the list in reverse order.
			splice(@$lines, $i, 0, <<_end_update_2_to_2081_);
## ex=executable su=setuid sg=setgid ca=capability (not implemented)
## ow=other-writable dir (d???????w?) st=sticky dir (d????????t)
### tw=sticky and other-writable dir (d???????wt)
_end_update_2_to_2081_
		}
	}
	push @$lines, <<_end_update_3_to_2081_;

## overlay the highlight color onto the current filename? (default yes)
highlightname:yes

## characteristics of the mouse wheel: the number of lines that the
## mouse wheel will scroll. This can be an integer or 'variable'.
#mousewheeljumpsize:5
mousewheeljumpsize:variable

## if 'mousewheeljumpsize' is 'variable', the next two values are taken
## into account.
## 'mousewheeljumpratio' is used to calculate the number of lines that
## the cursor will jump, namely: the total number of enties in the
## directory divided by 'mousewheeljumpratio'.
## 'mousewheeljumpmax' sets an upper bound to the number of lines that
## the cursor is allowed to jump when using the mousewheel.
mousewheeljumpratio:4
mousewheeljumpmax:11

_end_update_3_to_2081_
}

=item _update_version

Updates the 'Version:' line in I<text> to the new version.

=cut

sub _update_version {
	my ($self, $to, $lines) = @_;
	# this updates the version field for any version
	print "Updating version field to $to...\n";
	foreach (@$lines) {
		s/^(#.*?Version\D+)[[:alnum:].]+/$1$to/;
	}
}

=item _update_text(string $version_from, string $version_to, arrayref $text)

Updates the array indicated by I<text>.

=cut

sub _update_text {
	my ($self, $from, $to, $lines) = (@_);
	$self->_update_to_184 ($lines) if $self->_cross('1.84'  , $from, $to);
	$self->_update_to_188 ($lines) if $self->_cross('1.88'  , $from, $to);
	$self->_update_to_189 ($lines) if $self->_cross('1.89'  , $from, $to);
	$self->_update_to_1901($lines) if $self->_cross('1.90.1', $from, $to);
	$self->_update_to_1904($lines) if $self->_cross('1.90.4', $from, $to);
	$self->_update_to_1913($lines) if $self->_cross('1.91.3', $from, $to);
	$self->_update_to_1914($lines) if $self->_cross('1.91.4', $from, $to);
	$self->_update_to_1915($lines) if $self->_cross('1.91.5', $from, $to);
	$self->_update_to_1917($lines) if $self->_cross('1.91.7', $from, $to);
	$self->_update_to_1920($lines) if $self->_cross('1.92.0', $from, $to);
	$self->_update_to_1921($lines) if $self->_cross('1.92.1', $from, $to);
	$self->_update_to_1923($lines) if $self->_cross('1.92.3', $from, $to);
	$self->_update_to_1926($lines) if $self->_cross('1.92.6', $from, $to);
	$self->_update_to_1931($lines) if $self->_cross('1.93.1', $from, $to);
	$self->_update_to_1938($lines) if $self->_cross('1.93.8', $from, $to);
	$self->_update_to_1942($lines) if $self->_cross('1.94.2', $from, $to);
	$self->_update_to_1948($lines) if $self->_cross('1.94.8', $from, $to);
	$self->_update_to_1951($lines) if $self->_cross('1.95.1', $from, $to);
	$self->_update_to_1952($lines) if $self->_cross('1.95.2', $from, $to);
	$self->_update_to_200 ($lines) if $self->_cross('2.00'  , $from, $to);
	$self->_update_to_2017($lines) if $self->_cross('2.01.7', $from, $to);
	$self->_update_to_2037($lines) if $self->_cross('2.03.7', $from, $to);
	$self->_update_to_2044($lines) if $self->_cross('2.04.4', $from, $to);
	$self->_update_to_2053($lines) if $self->_cross('2.05.3', $from, $to);
	$self->_update_to_2059($lines) if $self->_cross('2.05.9', $from, $to);
	$self->_update_to_2060($lines) if $self->_cross('2.06.0', $from, $to);
	$self->_update_to_2061($lines) if $self->_cross('2.06.1', $from, $to);
	$self->_update_to_2062($lines) if $self->_cross('2.06.2', $from, $to);
	$self->_update_to_2063($lines) if $self->_cross('2.06.3', $from, $to);
	$self->_update_to_2064($lines) if $self->_cross('2.06.4', $from, $to);
	$self->_update_to_2069($lines) if $self->_cross('2.06.9', $from, $to);
	$self->_update_to_2080($lines) if $self->_cross('2.08.0', $from, $to);
	$self->_update_to_2081($lines) if $self->_cross('2.08.1', $from, $to);
	$self->_update_version($to, $lines);
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
	} else {
		print "Checking timestampformat vs. locale (ok)\n";
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

