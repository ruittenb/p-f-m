#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Config::Update 2.11.6
#
# Name:			App::PFM::Config::Update
# Version:		2.11.6
# Author:		Rene Uittenbogaard
# Created:		2010-05-28
# Date:			2011-03-28
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

use App::PFM::Util qw(min max maxdatetimelen);

use POSIX qw(strftime);
use Carp qw(cluck);

use strict;
use locale;

use constant UPDATES => {
	# ----- template -------------------------------------------------------
	'template' => {
		removals => [
			qr//,
		],
		substitutions => sub {},
		insertions => [{
			ifnotpresent => qr//,
			before => qr//,
			after  => qr//,
			batch  => [],
		}],
		additions => [{
			ifnotpresent => qr//,
			before => qr//,
			after  => qr//,
			batch => [],
		}],
	},
	# ----- 1.88 -----------------------------------------------------------
	'1.88' => {
		# minimum version required for update
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
			s{(if you have .LS_COLORS or .LS_COLOURS set,)$}
			 {$1, and 'importlscolors' above is set,};
		},
		additions => [{
			batch => [
				"# convert \$LS_COLORS into an additional colorset?\n",
				"importlscolors:yes\n",
				"\n",
			],
		}],
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
		additions => [{
			batch => [
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
		}, {
			after => qr/^##  \\6 = current directory basename/,
			batch => [
				"##  \\\\ = a literal backslash\n",
				"##  \\e = 'editor' (defined above)\n",
				"##  \\p = 'pager'  (defined above)\n",
				"##  \\v = 'viewer' (defined above)\n",
			],
		}],
	},
	# ----- 1.90.3 ---------------------------------------------------------
	'1.90.3' => {
		additions => [{
			batch => [
				"## initial ident mode (user, host, or user\@host, cycle with = key)\n",
				"#defaultident:user\n",
				"\n",
			],
		}],
	},
	# ----- 1.90.4 ---------------------------------------------------------
	'1.90.4' => {
		substitutions => sub {
			s/\bviewbase\b/defaultnumbase/g;
		},
	},
	# ----- 1.91 -----------------------------------------------------------
	'1.91' => {
		additions => [{
			batch => [
				"## how should pfm try to determine the file type? by its magic (using file(1)),\n",
				"## by extension, should we try to run it as an executable if the 'x' bit is set,\n",
				"## or should we prefer one method and fallback on another one?\n",
				"## allowed values: combinations of 'xbit', 'extension' and 'magic'\n",
				"launchby:extension,xbit\n",
				"#launchby:extension,xbit,magic\n",
				"\n",
			],
		}],
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
		additions => [{
			batch => [
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
		}],
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
				'## In other words: /^\s*([^:[\s]+(?:\[[^]]+\])?)\s*:\s*(.*)$/'."\n",
			],
		}],
	},
	# ----- 1.92.1 ---------------------------------------------------------
	'1.92.1' => {
		removals => [
			qr'^## [iI]n other words: /\^\\s\*\(\[\^:\\s\]\+\)\\s\*:\\s\*\(\.\*\)\$/',
		],
		substitutions => sub {
			s/^(#*\s*)\bclobber\b/$1defaultclobber/g;
		},
	},
	# ----- 1.92.3 ---------------------------------------------------------
	'1.92.3' => {
		substitutions => sub {
			s/^(#*\s*)\bmousemode\b/$1defaultmousemode/g;
		},
		insertions => [{
			after => qr/^##  .6 . current directory basename/,
			batch => [
			  "##  \\7 = current filename extension\n",
			],
		}],
		# added 'waitlaunchexec', but this was deprecated later.
		# no need to add it here because it was never implemented.
	},
	# ----- 1.92.6 ---------------------------------------------------------
	'1.92.6' => {
		substitutions => sub {
			s{hide dot files.*show them otherwise}
			 {show dot files initially? (hide them otherwise}g;
			s/\bdotmode:\s*yes\b/defaultdotmode: no/g;
			s/\bdotmode:\s*no\b/defaultdotmode: yes/g;
			s/\bwhitemode:\s*yes\b/defaultwhitemode: no/g;
			s/\bwhitemode:\s*no\b/defaultwhitemode: yes/g;
		},
	},
	# ----- 1.93.1 ---------------------------------------------------------
	'1.93.1' => {
		substitutions => sub {
			s/\\([1-7pv])/=$1/g;
			# watch out for keydefs with \e[M, \eOF etc.
			!/be entered as a real escape/ and s/\\e(?!\[|O[ABCDPQRSFH1])/=e/g;
			s/\\\\/==/g;
			s{^## these must NOT be quoted any more!}
			 {## these must NOT be quoted.};
			s{^(##  =[3467epv] )= (.*)}
			 {$1: $2};
			s{^##  =1 = filename without extension}
			 {##  =1 : current filename without extension};
			s{^##  =2 = filename entirely}
			 {##  =2 : current filename entirely};
			s{^##  .5 = swap path .F7.}
			 {##  =5 : swap directory path (F7)};
			s{^##  == = a literal.*}
			 {##  == : a single literal '='};
		},
		additions => [{
			batch => [
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
		}],
	},
	# ----- 1.93.8 ---------------------------------------------------------
	'1.93.8' => {
		additions => [{
			batch => [
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
		}],
	},
	# ----- 1.94.0 ---------------------------------------------------------
	'1.94.0' => {
		additions => [{
			batch => [
				"## command to perform automatically after every chdir()\n",
				"#chdirautocmd:printf \"\\033]0;pfm - \$(basename \$(pwd))\\007\"\n",
				"\n",
			],
		}],
	},
	# ----- 1.94.2 ---------------------------------------------------------
	'1.94.2' => {
		additions => [{
			batch => [
				"## request rcs status automatically?\n",
				"autorcs:yes\n",
				"\n",
				"## command to use for requesting the file status in your rcs system.\n",
				"rcscmd:svn status\n",
				"\n",
			],
		}],
	},
	# ----- 1.94.7 ---------------------------------------------------------
	'1.94.7' => {
		insertions => [{
			after => qr/##  .7 . current filename extension/,
			batch => [
				"##  =8 : list of selected filenames\n",
			],
		}],
	},
	# ----- 1.94.8 ---------------------------------------------------------
	'1.94.8' => {
		additions => [{
			batch => [
				"extension[*.odp]  : application/x-openoffice\n",
				"extension[*.ods]  : application/x-openoffice\n",
				"extension[*.odt]  : application/x-openoffice\n",
				"launch[application/x-openoffice]  : ooffice =2 &\n",
				"\n",
			],
		}],
	},
	# ----- 1.95.1 ---------------------------------------------------------
	'1.95.1' => {
		additions => [{
			batch => [
				"## is it always \"OK to remove marks?\" without confirmation?\n",
				"remove_marks_ok:no\n",
				"\n",
			],
		}],
	},
	# ----- 1.95.2 ---------------------------------------------------------
	'1.95.2' => {
		# this option was deprecated in 2.01.7
		# this option was reinstated in 2.11.1
		additions => [{
			batch => [
				"## automatically check for updates on exit (default: no) \n",
				"checkforupdates:no \n",
				"\n",
			],
		}],
	},
	# ----- 2.00.0 ---------------------------------------------------------
	'2.00.0' => {
		substitutions => sub {
			s/(^#*|:)header=/${1}menu=/;
			s/(^#*|:)title=/${1}headings=/;
		},
	},
	# ----- 2.01.7 ---------------------------------------------------------
	'2.01.7' => {
		# this option was reinstated in 2.11.1
		removals => [
			qr/^#*\s*checkforupdates:/,
			qr/^#+\s*automatically check for updates on exit/,
		],
	},
	# ----- 2.03.7 ---------------------------------------------------------
	'2.03.7' => {
		removals => [
			qr/^#*\s*waitlaunchexec:/,
			qr/^#+\s*wait for launched executables to finish/,
		],
	},
	# ----- 2.04.4 ---------------------------------------------------------
	'2.04.4' => {
		additions => [{
			batch => [
				"## commandline options to add to the cp(1) command, in the first place for\n",
				"## changing the 'follow symlinks' behavior.\n",
				"#copyoptions:-P\n",
				"\n",
			],
		}],
	},
	# ----- 2.05.3 ---------------------------------------------------------
	'2.05.3' => {
		additions => [{
			batch => [
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
		}],
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
		additions => [{
			batch => [
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
		}],
	},
	# ----- 2.06.0 ---------------------------------------------------------
	'2.06.0' => {
		additions => [{
			batch => [
				"## write bookmarks to file automatically upon exit\n",
				"autowritebookmarks:yes\n",
				"\n",
			],
		}],
	},
	# ----- 2.06.1 ---------------------------------------------------------
	'2.06.1' => {
		additions => [{
			batch => [
				"## sort modes to cycle through when clicking 'Sort' in the footer.\n",
				"## default: nNeEdDaAsStu\n",
				"#sortcycle:nNeEdDaAsStu\n",
				"\n",
			],
		}],
	},
	# ----- 2.06.2 ---------------------------------------------------------
	'2.06.2' => {
		additions => [{
			batch => [
				"## pfm does not support a terminal size of less than 80 columns or 24 rows.\n",
				"## this option will make pfm try to resize the terminal to the minimum\n",
				"## dimensions if it is resized too small.\n",
				"## valid options: yes,no,xterm.\n",
				"force_minimum_size:xterm\n",
				"\n",
			],
		}],
	},
	# ----- 2.06.3 ---------------------------------------------------------
	'2.06.3' => {
		additions => [{
			batch => [
				"## In case the regular editor automatically forks in the background, you\n",
				"## may want to specify a foreground editor here. If defined, this editor\n",
				"## will be used for editing the config file, so that pfm will be able to\n",
				"## wait for the editor to finish before rereading the config file.\n",
				"#fg_editor:vim\n",
				"\n",
			],
		}],
	},
	# ----- 2.06.4 ---------------------------------------------------------
	'2.06.4' => {
		additions => [{
			batch => [
				"## automatically sort the directory's contents again after a\n",
				"## (T)ime or (U)ser command? (default: yes)\n",
				"#autosort:yes\n",
				"\n",
			],
		}],
	},
	# ----- 2.06.9 ---------------------------------------------------------
	'2.06.9' => {
		removals => [
			qr/^#*\s*ducmd:/,
			qr/^#+\s*your system's du.1. command.+?(?:needs.+?for the current filename)?/,
			qr/need to specify '=2' for the name of the current file/,
			qr/^#+\s*[sS]pecify so that the outcome is in bytes/,
			qr/^#+\s*this is commented out because pfm makes a clever guess for your OS/,
		],
		additions => [{
			ifnotpresent => qr/^##  =f : 'fg_editor'/,
			after => qr/^##  =e . 'editor'.*defined above/,
			batch => [
				"##  =f : 'fg_editor' (defined above)\n",
			],
		}],
	},
	# ----- 2.08.0 ---------------------------------------------------------
	'2.08.0' => {
		substitutions => sub {
			s{## do=door nt=network special .not implemented. wh=whiteout.*}
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
		additions => [{
			batch => [
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
		}],
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
		},
		insertions => [{
			before => qr/^[ #]*mousewheeljumpmax:/,
			batch => [
				"mousewheeljumpmin:1\n",
			],
		}],
		additions => [{
			batch => [
				"## Must 'Hit any key to continue' also accept mouse clicks?\n",
				"clickiskeypresstoo:yes\n",
				"\n",
			],
		}],
	},
	# ----- 2.08.3-backlog -------------------------------------------------
	'2.08.3-backlog' => {
		# This was not a real pfm version. This entry fixes a backlog of
		# changes that should have been updated in earlier versions.
		removals => [
			qr'^## [iI]n other words: /\^\\s\*\(\[\^:\\s\]\+\)\\s\*:\\s\*\(\.\*\)\$/',
			qr/## the first three layouts were the old .pre-v1.72. defaults/,
		],
		substitutions => sub {
			s{(every option line in this file should have the)}
			 {ucfirst $1}e;
			s{^(## .whitespace is optional.)}
			 {$1.};
			s{(everything following a # is regarded)}
			 {ucfirst $1}e;
			s{(binary options may have yes/no, true/false,)}
			 {ucfirst $1}e;
			s{(some options can be set using environment variables)}
			 {ucfirst $1}e;
			s{(your environment settings override the options in this file)}
			 {ucfirst $1}e;
			s{escape.+(may be entered as a real escape, as ).e(.*)}
			 {Escapes $1\\e$2.};
			s{(lines may be continued on the next line by ending them in ).*}
			 {ucfirst($1) . "\\ (backslash)."}e;
			s{^(#*\s*)\bmousemode\b}
			 {$1defaultmousemode};
			s{initial sort mode .nNmMeEfFsS(?:zZ)?iItTdDaA. }
			 {initial sort mode (nNmMeEfFdDaAsSzZtTuUgGvViI*) };
			s{F7 key swap path method is persistent...default no.}
			 {F7 key swap path method is persistent? (default yes)};
			s{hide dot files.*show them otherwise}
			 {show dot files initially? (hide them otherwise}g;
			s{title, title in swap mode}
			 {headings, headings in swap mode};
			s{colors for header, header in multiple mode}
			 {colors for menu, menu in multiple mode};
			s{(if you have .LS_COLORS or .LS_COLOURS set,)$}
			 {$1, and 'importlscolors' above is set,};
			s{## char column name             needed}
			 {## char column name  mandatory? needed};
			s{## \*    (mark|selected flag)\s+1}
			 {## *    mark                yes 1};
			s{## n    filename                variable length;}
			 {## n    filename            yes variable length;};
			s{## p    permissions .(?:mode)?\s+10}
			 {## p    mode (permissions)      10};
			s{(## a    access time             15)}
			 {$1 (using "%y %b %d %H:%M" if len(%b) == 3)};
			s{(## c    change time             15)}
			 {$1 (using "%y %b %d %H:%M" if len(%b) == 3)};
			s{(## m    modification time       15)}
			 {$1 (using "%y %b %d %H:%M" if len(%b) == 3)};
			s{## i    inode                   7}
			 {## i    inode                   >=7 (system-dependent)};
			s{## a final : after the last layout is allowed.}
			 {## a final colon (:) after the last layout is allowed.};
			s{## these must NOT be quoted any more!}
			 {## these must NOT be quoted.};
			s{##  =1 = filename without extension}
			 {##  =1 : current filename without extension};
			s{##  =2 = filename entirely}
			 {##  =2 : current filename entirely};
			s{##  =3 = current directory path}
			 {##  =3 : current directory path};
			s{##  =4 = current mountpoint}
			 {##  =4 : current mountpoint};
			s{##  =5 = swap path .F7.}
			 {##  =5 : swap directory path (F7)};
			s{##  =6 = current directory basename}
			 {##  =6 : current directory basename};
		},
		insertions => [{
			ifnotpresent => qr/the diskinfo field .must. be the _first_ or _last_ field on the line/,
			before => qr/## a final.*after the last layout is allowed/,
			batch  => [
				"## the diskinfo field *must* be the _first_ or _last_ field on the line.\n",
			],
		}, {
			ifnotpresent => qr/^## v    versioning info/,
			after => qr/^## l    link count/,
			batch => [
				"## v    versioning info         >=4\n",
			],
		}, {
			ifnotpresent => qr/^## f    diskinfo/,
			after => qr/^## l    link count/,
			batch => [
				"## f    diskinfo            yes >=14 (using clockformat, if len(%x) <= 14)\n",
			],
		}, {
			ifnotpresent => qr/^## Has no effect if altscreenmode is set/,
			after => qr/whether you want to have the screen cleared when pfm exits/,
			batch => [
				"## Has no effect if altscreenmode is set.\n",
			],
		}, {
			ifnotpresent => qr/## It will also be used for editing ACLs/,
			before => qr/^#*\s*fg_editor:/,
			batch => [
				"## It will also be used for editing ACLs.\n",
			],
		}, {
			ifnotpresent => qr/7 . current filename extension/,
			after => qr/^##  .6 . current directory basename/,
			batch => [
			  "##  =7 : current filename extension\n",
			],
		}, {
			ifnotpresent => qr/8 . list of selected filenames/,
			after => qr/##  .7 . current filename extension/,
			batch => [
				"##  =8 : list of selected filenames\n",
			],
		}],
		additions => [{
			ifnotpresent => qr/defaultpathmode/,
			batch => [
				"## initially display logical or physical paths? (log,phys) (default: log)\n",
				"## (toggle with \")\n",
				"defaultpathmode:log\n",
				"\n",
			],
		}, {
			ifnotpresent => qr/defaultwhitemode/,
			batch => [
				"## show whiteout files initially? (hide them otherwise, toggle with % key)\n",
				"defaultwhitemode:no\n",
				"\n",
			],
		}, {
			ifnotpresent => qr/launchby/,
			batch => [
				"## how should pfm try to determine the file type? by its magic (using file(1)),\n",
				"## by extension, should we try to run it as an executable if the 'x' bit is set,\n",
				"## or should we prefer one method and fallback on another one?\n",
				"## allowed values: combinations of 'xbit', 'extension' and 'magic'\n",
				"launchby:extension,xbit\n",
				"#launchby:extension,xbit,magic\n",
				"\n",
			],
		}],
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
	# ----- 2.08.5 ---------------------------------------------------------
	'2.08.5' => {
		substitutions => sub {
			s{##.*<ext> defines extension colors}
			 {## *.ext      defines colors for files with a specific extension};
		},
		insertions => [{
			after => qr/defines colors for files with a specific extension/,
			batch => [
				"## 'filename' defines colors for complete specific filenames\n",
				"\n",
			],
		}, {
			before => qr/cmd=[^:]*:..exe=[^:]*:..com=[^:]*/,
			batch  => [
				"'Makefile'=underline:'Makefile.PL'=underline:\\\n",
			],
		}, {
			ifnotpresent => qr/gnome-terminal.+?handles F1\s+?itself.+?enable shift-F1/,
			after => qr/## also check 'kmous' from terminfo if your mouse is malfunctioning/,
			batch => [
				"## gnome-terminal handles F1  itself. enable shift-F1 by adding:\n",
				"#k1=\\eO1;2P:\n",
				"## gnome-terminal handles F10 itself. enable shift-F10 by adding:\n",
				"#k10=\\e[21;2~:\n",
				"## gnome-terminal handles F11 itself. enable shift-F11 by adding:\n",
				"#k11=\\e[23;2~:\n",
				"\n",
			],
		}],
	},
	# ----- 2.09.2 ---------------------------------------------------------
	'2.09.2' => {
		substitutions => sub {
			s{^## initial ident mode .user, host, or user.host, cycle with = key.*}
			 {## initial ident mode (two of: 'host', 'user' or 'tty', separated by commas)};
			s{^defaultident:.*}
			 {defaultident:user,host};
			s{^(##  =8 : list of) selected (filenames)}
			 {$1 marked $2};
			s{^## headings, headings in swap mode, footer, messages,.*}
			 {## headings, headings in swap mode, footer, messages, the username (for root),};
		},
		additions => [{
			after => qr/^## initial ident mode /,
			batch => [
				"## (cycle with = key)\n",
			],
		}, {
			after => qr/^## headings, headings in swap mode, footer/,
			batch => [
				"## and the highlighted file.\n",
			],
		}, {
			after => qr/^framecolors\[/,
			batch => [
				"rootuser=reverse red:\\\n",
			],
		}, {
			after => qr/^#framecolors\[/,
			batch => [
				"#rootuser=reverse red:\\\n",
			],
		}, {
			batch => [
				"## should F5 always leave marks untouched like (M)ore-F5?\n",
				"#refresh_always_smart:no\n",
				"\n",
			],
		}],
	},
	# ----- 2.09.3 ---------------------------------------------------------
	'2.09.3' => {
		substitutions => sub {
			s{^#+\s*translate spaces when viewing Name}
			 {## default translate spaces when viewing Name};
			s[^(#*\s*)translatespace:(.*)]
			 [${1}defaulttranslatespace:${2}];
			s{^(#+\s*initial radix that Name will use to display.*)\(hex,oct\)(.*)}
			 {$1(hex,oct,dec)$2};
		},
		additions => [{
			batch => [
				"## disable pasting when a menu is active. This requires a terminal\n",
				"## that understands 'bracketed paste' mode. (yes,no,xterm)\n",
				"paste_protection:xterm\n",
				"\n",
			]
		}, {
			after => qr/translate spaces when viewing Name/,
			batch => [
				"## (toggle with SPACE when viewing Name)\n",
			],
		}],
	},
	# ----- 2.09.5 ---------------------------------------------------------
	'2.09.5' => {
		removals => [
			qr/^(#+\s*)show whether mandatory locking is enabled.*-rw-r-lr--.*yes,no,sun/,
			qr/^(#+\s*)'sun' = show locking only on sunos.solaris/,
			qr/^(#*\s*)showlock:/,
		],
	},
	# ----- 2.09.6 ---------------------------------------------------------
	'2.09.6' => {
		additions => [{
			after => qr{^launch\[text/html\].*:},
			batch => [
				"launch[text/x-makefile]           : make\n",
			],
		}, {
			after => qr{^magic\[HTML document text\]},
			batch => [
				"magic[make commands text]   : text/x-makefile\n",
			],
		}],
		substitutions => sub {
			s{^##  =f : 'fg_editor' .defined above.}
			 {##  =E : 'fg_editor' (defined above)};
		},
	},
	# ----- 2.09.9 ---------------------------------------------------------
	'2.09.9' => {
		additions => [{
			after => qr{^## g    group\s+>=8.*system-dependent},
			batch => [
				"## w    uid                      >=5 (system-dependent)\n",
				"## h    gid                      >=5 (system-dependent)\n",
			],
		}],
	},
	# ----- 2.10.4 ---------------------------------------------------------
	'2.10.4' => {
		additions => [{
			after => qr{^## how should pfm try to determine the file type},
			batch => [
				"## by its unique filename,\n",
			],
		}, {
			before => qr{^## the file type names do not have to be valid MIME},
			batch => [
				"## launchby extension\n",
			],
		}, {
			before => qr{^## these will search by regular expression in the},
			batch => [
				"## launchby magic\n",
			],
		}, {
			batch => [
				"## launchby name\n",
				"## some filenames have their own special launch method\n",
				"launchname[Makefile]              : make\n",
				"launchname[Imakefile]             : xmkmf\n",
				"launchname[Makefile.PL]           : perl =2\n",
				"\n",
			],
		}],
		substitutions => sub {
			s[^(#*\s*launchby\s*:\s*)]
			 [${1}name,];
			s{('Makefile'=([\w\s]*):)}
			 {$1'Imakefile'=$2:};
			s{^(## allowed values: combinations of 'xbit', )('extension' and)}
			 {$1'name', $2};
		},
	},
	# ----- 2.10.6 ---------------------------------------------------------
	'2.10.6' => {
		additions => [{
			after => qr{^## the keymap to use in readline},
			batch => [
				"## emacs (=emacs-standard), emacs-standard, emacs-meta, emacs-ctlx,\n",
				"## vi (=vi-command), vi-command, vi-move, and vi-insert.\n",
				"## emacs is the default.\n",
			],
		}],
		substitutions => sub {
			s{^## the keymap to use in readline.*}
			 {## the keymap to use in readline. Allowed values are:};
		},
	},
	# ----- 2.10.9 ---------------------------------------------------------
	'2.10.9' => {
		additions => [{
			batch => [
				"## time between cursor jumps in incremental find and the bookmark browser\n",
				"## (in seconds, fractions allowed)\n",
				"#cursorjumptime:0.5\n",
				"\n",
			],
		}],
		substitutions => sub {
			s{(menu=)([\w_ ]*):}
			 {$1$2:menukeys=bold $2:};
		},
	},
	# ----- 2.11.0 ---------------------------------------------------------
	'2.11.0' => {
		substitutions => sub {
			s{(footer=)([\w_ ]*):}
			 {$1$2:footerkeys=bold $2:};
		},
		removals => [
			qr/^(#+\s*)turn off mouse support during execution of commands/,
			qr/^(#+\s*)caution: if you set this to 'no', your .external. commands/,
			qr/^(#+\s*).*? will receive escape codes on mousedown events/,
			qr/^(#*\s*)mouseturnoff:/,
		],
	},
	# ----- 2.11.1 ---------------------------------------------------------
	'2.11.1' => {
		additions => [{
			ifnotpresent => qr/checkforupdates:/,
			batch => [
				"## automatically check for updates on the web (default: yes) \n",
				"#checkforupdates:no \n",
				"\n",
			],
		}, {
			after => qr{^##  =8 : list of marked filenames},
			batch => [
				"##  =9 : previous directory path (F2)\n",
			],
		}],
	},
	# ----- 2.11.5 ---------------------------------------------------------
	'2.11.5' => {
		substitutions => sub {
			s{(extension\[\*\.do(?:c|t|cx)\]\s*:\s*application)/x-ms-office}
			 {$1/msword};
			s{(extension\[\*\.p(?:ot|pt|ptx|ps|pz)\]\s*:\s*application)/x-ms-office}
			 {$1/mspowerpoint};
			s{(extension\[\*\.xl(?:c|l|m|s|sx|t|w)\]\s*:\s*application)/x-ms-office}
			 {$1/vnd.ms-excel};
			s{(magic\[C.*program text\]\s*):\s*application/x-c\>}
			 {$1: text/x-c\>};
			s{launch\[application/x-c\]}
			 {launch[text/x-c]};
		},
		additions => [{
			ifnotpresent => qr{launch.application/msword},
			after => qr{launch\[application/x-ms-office\]},
			batch => [
				"launch[application/msword]      : ooffice =2 &\n",
				"launch[application/mspowerpoint]: ooffice =2 &\n",
				"launch[application/vnd.ms-excel]: ooffice =2 &\n",
			],
		}, {
			ifnotpresent => qr{extension\[.*portable},
			after => qr{extension\[\*\.png\]},
			batch => [
				"extension[*.pbm]  : image/x-portable-bitmap\n",
				"extension[*.pgm]  : image/x-portable-graymap\n",
				"extension[*.pnm]  : image/x-portable-anymap\n",
				"extension[*.ppm]  : image/x-portable-pixmap\n",
			],
		}, {
			ifnotpresent => qr{extension\[.*fortran},
			after => qr{extension\[\*\.exe\]},
			batch => [
				"extension[*.f]    : text/x-fortran\n",
				"extension[*.for]  : text/x-fortran\n",
				"extension[*.f90]  : text/x-fortran\n",
				"extension[*.f95]  : text/x-fortran\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.jpe\]\s*:},
			after => qr{extension\[\*\.jpg\]},
			batch => [
				"extension[*.jpe]  : image/jpeg\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.sit\]\s*:},
			after => qr{extension\[\*\.zip\]\s*:\s*application/zip},
			batch => [
				"extension[*.sit]  : application/x-stuffit\n",
				"extension[*.hqx]  : application/mac-binhex40\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.svg\]\s*:},
			after => qr{extension.*application/xml},
			batch => [
				"extension[*.svg]  : image/svg+xml\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.rtf\]\s*:},
			before => qr{extension\[\*\.txt},
			batch => [
				"extension[*.rtf]  : text/rtf\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.latex\]\s*:},
			after => qr{extension\[\.1\]},
			batch => [
				"extension[*.latex]  : application/x-latex\n",
				"extension[*.tex]    : application/x-tex\n",
				"extension[*.texi]   : application/x-texinfo\n",
				"extension[*.texinfo]: application/x-texinfo\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.rm\]\s*:},
			after => qr{extension\[\*\.ram\]\s*:\s*audio/x(?:-pn)?-realaudio},
			batch => [
				"extension[*.rm]   : audio/x-pn-realaudio\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.smi.?\]\s*:},
			after => qr{extension\[\*\.ram\]\s*:\s*audio/x(?:-pn)?-realaudio},
			batch => [
				"extension[*.smi]  : application/smil\n",
				"extension[*.smil] : application/smil\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.aif.?\]\s*:},
			before => qr{extension\[\*\.arj},
			batch => [
				"extension[*.aif]  : audio/x-aiff\n",
				"extension[*.aifc] : audio/x-aiff\n",
				"extension[*.aiff] : audio/x-aiff\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.cs\]\s*:},
			after => qr{extension\[\*\.c\]},
			batch => [
				"extension[*.cs]      : text/x-csharp\n",
				"launch[text/x-csharp]: gmcs =2\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.cc\]},
			after => qr{extension\[\*\.c\]},
			batch => [
				"extension[*.cc]   : text/x-c++\n",
				"launch[text/x-c++]: g++ -o =1 =2\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.java\]\s*:},
			after => qr{extension\[\*\.jar\]},
			batch => [
				"extension[*.class] : application/octet-stream\n",
				"extension[*.java]  : text/x-java\n",
				"launch[text/x-java]: javac =2\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.cpio\]},
			after => qr{extension\[\*\.tar\]},
			batch => [
				"extension[*.cpio] : application/x-cpio\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.lha\]},
			before => qr{extension\[\*\.lzh\]},
			batch => [
				"extension[*.lha]  : application/x-lha\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.mp4\]},
			after => qr{extension\[\*\.mp3\]},
			batch => [
				"extension[*.mp4]  : video/mpeg\n",
				"extension[*.mpe]  : video/mpeg\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.ai\]},
			after => qr{extension\[\*\.ps\]},
			batch => [
				"extension[*.ai]   : application/postscript\n",
			],
		}, {
			ifnotpresent => qr{extension\[\*\.swf\]},
			after => qr{extension\[\*\.svg\]},
			batch => [
				"extension[*.swf]   : application/x-shockwave-flash\n",
				"extension[*.flv]   : video/x-flv\n",
			],
		}],
	},
	# ----- 2.11.6 ---------------------------------------------------------
	'2.11.6' => {
		additions => [{
			ifnotpresent => qr/timestamptruncate:/,
			before => qr/## use color .yes,no,force. .may be overridden by/,
			batch => [
				"## should the timestamps be truncated to the field length? (otherwise,\n",
				"## the timestamp field is adjusted if necessary). (default: no)\n",
				"#timestamptruncate:yes\n",
				"\n",
			],
		}, {
			ifnotpresent => qr/mouse_moves_cursor:/,
			before => qr/## characteristics of the mouse wheel: the number of lines/,
			batch => [
				"## should a mouse click move the cursor to the clicked line? (default no)\n",
				"#mouse_moves_cursor:yes\n",
				"\n",
			],
		}, {
			ifnotpresent => qr/clobber_compare:/,
			before => qr{## clock date/time format; see strftime},
			batch => [
				"## display file comparison information before asking to clobber (default: yes)\n",
				"#clobber_compare:no\n",
				"\n",
			],
		}],
	},
};


##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self) = @_;
	return;
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
	return;
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
	return;
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
	return;
}

=item _insert(arrayref $text, regexp $before, regexp $after, array @addition)

Adds the specified lines at the specified place in the config text.
If I<before> is specified, the I<addition> is inserted before the matching line.
If I<after> is specified, the I<addition> is inserted after the matching line.

=cut

sub _insert {
	my ($self, $lines, $before, $after, @addition) = @_;
	my ($where, $delta);
	if ($#addition == 0) {
		@addition = split (/(?<=\n)/, $addition[0]);
	}
	$where = defined $after ? $after : $before;
	$delta = defined $after;
	foreach my $i (reverse 1 .. $#$lines) {
		if (${$lines}[$i] =~ /$where/) {
			# this changes the total number of lines, but this does not
			# matter because we are processing the list in reverse order.
			splice(@$lines, $i + $delta, 0, @addition);
		}
	}
	return;
}

=item _substitute(arrayref $text, coderef $substitutor)

Executes the I<substitutor> code for all lines in the config text.

=cut

sub _substitute {
	my ($self, $lines, $substitutor) = @_;
	local $_;
	foreach (@$lines) {
		$substitutor->();
	}
	return;
}

=item _get_locale()

Finds the locale that is currently in use for LC_TIME.

=cut

sub _get_locale {
	my ($self) = @_;
	open my $LOCALEPIPE, '-|', 'locale';
	my @lines = grep /^LC_TIME/, <$LOCALEPIPE>;
	close $LOCALEPIPE;
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
	return;
}

=item _update_text(string $version_from, string $version_to, arrayref $text)

Updates the array indicated by I<text> to the new version by adding
any new config options, removing deprecated ones, and updating
definitions that have changed.

=cut

sub _update_text {
	my ($self, $from, $to, $lines) = (@_);
	my %updates = %{UPDATES()};
	my $change;
	foreach my $version (sort keys %updates) {
		next unless $self->_cross($version, $from, $to);
		if (defined($change = $updates{$version}{removals})) {
			# $change is an arrayref with regexps
			$self->_remove($lines, @$change);
		}
		if (defined($change = $updates{$version}{substitutions})) {
			# $change is a coderef
			$self->_substitute($lines, $change);
		}
		foreach my $change (
			@{$updates{$version}{insertions}},
			@{$updates{$version}{additions}},
		) {
			# $change is a hashref
			if (!exists $change->{ifnotpresent} or
				(exists($change->{ifnotpresent}) &&
				!grep { $_ =~ $change->{ifnotpresent} } @$lines)
			) {
				if (exists $change->{before} or
					exists $change->{after}
				) {
					$self->_insert(
						$lines,
						$change->{before},
						$change->{after},
						@{$change->{batch}});
				} else {
					$self->_append($lines, @{$change->{batch}});
				}
			}
		}
	}
	$self->_update_version_identifier($to, $lines);
	return;
}

##########################################################################
# public subs

=item get_minimum_version()

Fetches the minimum version a F<.pfmrc> must have in order for this class
to be able to update it.

=cut

sub get_minimum_version {
	my ($self) = @_;
	return (sort { $a cmp $b } keys %{UPDATES()})[0];
}

=item check_date_locale(arrayref $text)

Checks the 'columnlayouts' option to see if it can accommodate date/time
strings localized according to your current locale (as defined by LC_ALL
or LC_TIME).

=cut

sub check_date_locale {
	my ($self, $text) = @_;
	my $locale          = $self->_get_locale();
	my $timefieldlen    = $self->_get_pfmrc_timefieldlen($text);
	my $timefieldformat = $self->_get_pfmrc_timefieldformat($text);
	my $maxdatetimelen  = maxdatetimelen($timefieldformat);
	#
	if ($maxdatetimelen > $timefieldlen) {
		print <<_LOCALE_WARNING_

Warning: Your date/time locale (LC_TIME) is set to $locale. In this
locale, the configured timestampformat of '$timefieldformat' in your
.pfmrc may require up to $maxdatetimelen characters.

Some of the layouts in your .pfmrc only allow for $timefieldlen characters.

Please verify that your file timestamps don't look truncated, otherwise
please change the 'columnlayouts' or 'timestampformat' option manually.

_LOCALE_WARNING_
	}
	return;
}

=item update(string $version_pfmrc, string $version_pfm, arrayref $text)

Updates the lines in the array pointed to by I<$text>.

=cut

sub update {
	my ($self, $version_pfmrc, $version_pfm, $text) = @_;
	return if $version_pfmrc ge $version_pfm;
	if ($version_pfmrc lt $self->get_minimum_version()) {
		return 0;
	}

	$self->check_date_locale($text);
	$self->_update_text($version_pfmrc, $version_pfm, $text);
	$self->_sort_pfmrc($text);
	return 1;
}

##########################################################################

1;

__END__

=back

SEE ALSO

pfm(1), locale(7). App::PFM::Config(3pm).

=cut

# vim: set tabstop=4 shiftwidth=4:

