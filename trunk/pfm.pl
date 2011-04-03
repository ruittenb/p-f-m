#!/usr/bin/env perl
#
##########################################################################
#
# Name:         pfm
# Version:      1.93.6
# Author:       Rene Uittenbogaard
# Created:      1999-03-14
# Date:         2009-02-20
# Usage:        pfm [ <directory> ] [ -s, --swap <directory> ]
#               pfm { -v, --version | -h, --help }
# Requires:     Term::ReadLine::Gnu (preferably)
#               Term::ScreenColor
#               Getopt::Long
#               POSIX
#               Config
#               Cwd
#               locale
#               strict
#               vars
# Description:  Personal File Manager for Unix/Linux
#
# TOTEST:
#       getdircontents: will stat(2) be able to detect w-files?
#       fix error handling in eval($do_this) and display_error()
#           partly implemented in handlecopyrename
#       fixed sysread() and buffering
#
#       change \ char for \1..\7 interpretation
#       correct optreden van "cannot do multifile oper when destination is single" (multi_to_single)
#       test substitution in (O), (Y) and Launch; du(Z); (P); df;  (N)ame
#       test major/minor numbers on DU 4.0E, Tru64, Sun (cannot test: no system available)
# TODO:
#       more consistent use of at(1,0) and at(0,0)
#       sub fileforall(sub) ?
#       cache color codes?
#       use SIGINT for interrupt single, SIGQUIT for interrupt multi?
#       bug: 'f' field in layout: characters in the 'gap' between filerecord & infocolumn
#           are not cleared when switching columnformats -> insert an artificial "gap" field?
#       handlemousedown() does ($mousecol >= $infocol) test: wrong if f col at left
#
#       does DFCMD handle columns correctly on AIX?  @tdisk{qw/device total used avail/}
#           prove1sup7:/home/ruittenb>df -k 
#           Filesystem    1024-blocks      Free %Used    Iused %Iused Mounted on
#           /dev/hd4            45056      3528   93%     1389     7% /
#           /dev/hd2           303104     31984   90%    10081    14% /usr
#
#       errortime and importanttime configureerbaar maken
#       fixing whiteout handling
#       find out why coloring goes wrong when e.g. LC_ALL=*.utf8
#       in chmod(directory): recursively descend? y/n
#       fix deleting lost file with one D if file is marked (file count ok, byte count wrong)
#       define printcommand at top of program? together with touch, du, lpr, unwo?
#       add html format doc for =1,=2,=7 definition examples
#       implement escape char fixes to Term::Screen in Term::ScreenColor
#
#       mend timetouchformat. see shar(1) archives
#           if touch -am -t 200112312359.59 $$.touch >/dev/null 2>&1 && test ! -f 200112312359.59 -a -f $$.touch; then
#           shar_touch='touch -am -t $1$2$3$4$5$6.$7 "$8"'
#           elif touch -am 123123592001.59 $$.touch >/dev/null 2>&1 && test ! -f 123123592001.59 -a ! -f 123123592001.5 -a -f $$.touch; then
#           shar_touch='touch -am $3$4$5$6$1$2.$7 "$8"'
#           elif touch -am 1231235901 $$.touch >/dev/null 2>&1 && test ! -f 1231235901 -a -f $$.touch; then
#           shar_touch='touch -am $3$4$5$6$2 "$8"'
#           else
#           shar_touch=:
#           echo
#           $echo 'WARNING: not restoring timestamps.  Consider getting and'
#           $echo "installing GNU \`touch', distributed in GNU File Utilities..."
#           echo
#           fi
#           rm -f 200112312359.59 123123592001.59 123123592001.5 1231235901 $$.touch
#
#       cp -pr copies symlinks to symlinks - ?
#           recursive directory copy? Ask for follow?
#       change (U)id command to request changing the symlink?
#       (B)abel option? tr/[:upper:]/[:lower:]/ etc
#       NIS line in passwd file will display '+' as username if ypbind is not running
#
#       (L)ink (R)el to current dir does not restat()
#       tar(G)et in multiple mode does not re-readlink()
#       (U) in multiple mode does not restat()
#       handletime does not restat() in multiple mode, nor resort
#
#       in handledelete: test whether deleted file is present as whiteout after deletion
#       after rename: position_at new name?
#       use the nameindexmap from handledelete() more globally?
#           in handlecopyrename()? in handlefind() in handlesymlink? in dirlookup? in handlemorefifo?
#           use in conjunction with 'keeplostfiles' option?
#
#       (M)ore - (P)hysical path?
#       'autochangedir' option?
#       set ROWS and COLUMNS in environment for child processes; but see if
#           this does not mess up with $scr->rows etc. which use these
#           variables internally; portability?
#       cache converted formatlines - store formatlines and maxfilesizelength
#           etc in hash; column_mode in swap_state
#       stat_entry() must *not* rebuild the selected_nr and total_nr lists:
#           this messes up with e.g. cOmmand -> cp \2 /somewhere/else
#           (which is, therefore, still buggy). this is closely related to:
#       sub countdircontents is not used
#       make commands in header and footer clickable buttons?
#       make F11 respect multiple mode? (marked+oldmarked, not removing marks)
#       hierarchical sort? e.g. 'sen' (size,ext,name)
#       window sizing problems on Sun 5.6 - test on sup6
#       include acl commands?
#       (F)ind command: stop at nearest match?
#       filename subs command? foreach(@file) { s/^pfm/pfm-/ }
#       incremental search (search entry while entering filename)?

##########################################################################
# main data structures:
#
# @dircontents   : array (current directory data) of references (to file data)
# $dircontents[$index]      : reference to hash (=file data)
# $dircontents[$index]{name}
#                     {selected}
#                     {size}
#                     {type}
#
# %currentfile = %{ $dircontents[$currentline+$baseindex] } (current file data)
# $currentfile{name}
#             {selected}
#             {size}
#             {type}

##########################################################################
# requirements

# 5.005 for negative lookbehind in re (in handlecopyrename())
# 5.6 for our()
require 5.006;

use Term::ScreenColor;
use Term::ReadLine;
use Getopt::Long;
use POSIX qw(strftime mktime);
use Config;
use Cwd;
use locale;
use strict;
#use warnings;
#use diagnostics;
#disable diagnostics; # so we can switch it on in '@'
#$^W = 0;

use vars qw(
    $FALSE
    $TRUE
    $READ_FIRST
    $READ_AGAIN
    $QUOTE_OFF
    $QUOTE_ON
    $MOUSE_OFF
    $MOUSE_ON
    $TERM_RAW
    $TERM_COOKED
    $FILENAME_SHORT
    $FILENAME_LONG
    $HIGHLIGHT_OFF
    $HIGHLIGHT_ON
    $TIME_FILE
    $TIME_CLOCK
    $HEADER_SINGLE
    $HEADER_MULTI
    $HEADER_MORE
    $HEADER_SORT
    $HEADER_INCLUDE
    $HEADER_LNKTYPE
    $TITLE_DISKINFO
    $TITLE_YCOMMAND
    $TITLE_SIGNAL
    $TITLE_SORT
    $TITLE_ESCAPE
    $R_NOP
    $R_STRIDE
    $R_HEADER
    $R_PATHINFO
    $R_TITLE
    $R_FOOTER
    $R_DIRFILTER
    $R_DIRLIST
    $R_DISKINFO
    $R_DIRSORT
    $R_CLEAR
    $R_DIRCONTENTS
    $R_NEWDIR
    $R_INIT_SWAP
    $R_QUIT
);

END {
    # in case something goes wrong
    system qw(stty -raw echo);
}

##########################################################################
# declarations and initialization

*FALSE          = \0;
*TRUE           = \1;
*READ_FIRST     = \0;
*READ_AGAIN     = \1;
*QUOTE_OFF      = \0;
*QUOTE_ON       = \1;
*MOUSE_OFF      = \0;
*MOUSE_ON       = \1;
*TERM_RAW       = \0;
*TERM_COOKED    = \1;
*FILENAME_SHORT = \0;
*FILENAME_LONG  = \1;
*HIGHLIGHT_OFF  = \0;
*HIGHLIGHT_ON   = \1;
*TIME_FILE      = \0;
*TIME_CLOCK     = \1;
*HEADER_SINGLE  = \0;
*HEADER_MULTI   = \1;
*HEADER_MORE    = \2;
*HEADER_SORT    = \4;
*HEADER_INCLUDE = \8;
*HEADER_LNKTYPE = \16;
*TITLE_DISKINFO = \0;
*TITLE_YCOMMAND = \1;
*TITLE_SIGNAL   = \2;
*TITLE_SORT     = \3;
*TITLE_ESCAPE   = \4;
*R_NOP          = \0;
*R_STRIDE       = \1;
*R_HEADER       = \2;
*R_PATHINFO     = \4;
*R_TITLE        = \8;
*R_FOOTER       = \16;
*R_DIRFILTER    = \32;
*R_DIRLIST      = \64;
*R_DISKINFO     = \128;
*R_DIRSORT      = \256;
*R_CLEAR        = \512;
*R_DIRCONTENTS  = \1024;
*R_NEWDIR       = \2048;
*R_INIT_SWAP    = \4096;
*R_QUIT         = \1048576;

my $R_FRAME     = $R_HEADER | $R_PATHINFO | $R_TITLE | $R_FOOTER;
my $R_SCREEN    = $R_DIRFILTER | $R_DIRLIST | $R_DISKINFO | $R_FRAME;
my $R_CLRSCR    = $R_CLEAR | $R_SCREEN;
my $R_CHDIR     = $R_NEWDIR | $R_DIRCONTENTS | $R_DIRSORT | $R_SCREEN
                | $R_STRIDE;

my ($VERSION,$LASTYEAR) = getversion();
my $CONFIGDIRNAME       = "$ENV{HOME}/.pfm";
my $CONFIGFILENAME      = '.pfmrc';
my $CONFIGDIRMODE       = 0700;
my $CWDFILENAME         = 'cwd';
my $SWDFILENAME         = 'swd';
my $LOSTMSG             = '';   # was ' (file lost)'; # now shown through coloring
my $MAJORMINORSEPARATOR = ',';
my $NAMETOOLONGCHAR     = '+';
my $MAXHISTSIZE         = 40;
my $ERRORDELAY          = 1;    # in seconds (fractions allowed)
my $IMPORTANTDELAY      = 2;    # extra time for important errors
my $SLOWENTRIES         = 300;
my $PATHLINE            = 1;
my $BASELINE            = 3;
my $DISKINFOLINE        = 4;
my $DIRINFOLINE         = 9;
my $MARKINFOLINE        = 15;
my $USERINFOLINE        = 21;
my $DATEINFOLINE        = 22;
my $DFCMD               = ($^O eq 'hpux') ? 'bdf' : ($^O eq 'sco') ? 'dfspace' : 'df -k';

my @SYMBOLIC_MODES      = qw(--- --x -w- -wx r-- r-x rw- rwx);
my %ONOFF               = ('' => 'off', 0 => 'off', 1 => 'on');
my %IDENTMODES          = ( user => 0, host => 1, 'user@host' => 2);
my %NUMFORMATS          = ( 'hex' => '%#04lx', 'oct' => '%03lo');

my %FILETYPEFLAGS       = (
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
    # => '+', # Hidden directory (AIX only) or context dependent (HP/UX only)

);

my @SORTMODES = (
    n =>'Name',        N =>' reverse',
   'm'=>' ignorecase', M =>' rev+igncase',
    e =>'Extension',   E =>' reverse',
    f =>' ignorecase', F =>' rev+igncase',
    d =>'Date/mtime',  D =>' reverse',
    a =>'date/Atime',  A =>' reverse',
   's'=>'Size',        S =>' reverse',
   'z'=>'siZe total',  Z =>' reverse',
    t =>'Type',        T =>' reverse',
    i =>'Inode',       I =>' reverse',
);

my %CMDESCAPES = (
    '1' => 'name',
    '2' => 'name.ext',
    '3' => 'curr path',
    '4' => 'mountpoint',
    '5' => 'swap path',
    '6' => 'base path',
    '7' => 'extension',
    'e' => 'editor',
    'p' => 'pager',
    'v' => 'viewer',
);

# AIX,BSD,Tru64: du gives blocks, du -k kbytes
# Solaris      : du gives kbytes
# HP           : du gives blocks,               du -b something unwanted
# Linux        : du gives blocks, du -k kbytes, du -b bytes
# Darwin       : du gives blocks, du -k kbytes
# the ${e} is replaced later
my %DUCMDS = (
    default => q(du -sk ${e}2 | awk '{ printf "%d", 1024 * $1 }'),
    solaris => q(du -s  ${e}2 | awk '{ printf "%d", 1024 * $1 }'),
    sunos   => q(du -s  ${e}2 | awk '{ printf "%d", 1024 * $1 }'),
    hpux    => q(du -s  ${e}2 | awk '{ printf "%d",  512 * $1 }'),
    linux   => q(du -sb ${e}2),
#    aix     => can use the default
#    freebsd => can use the default
#    netbsd  => can use the default unless proven otherwise
#    dec_osf => can use the default unless proven otherwise
#    beos    => can use the default unless proven otherwise
#    irix    => can use the default unless proven otherwise
#    sco     => can use the default unless proven otherwise
#    darwin  => can use the default
    # MSWin32, os390 etc. not supported
);

my %RDEVTOMAJOR = (
    default => 256,
    aix     => 2 ** 16,
    irix    => 2 ** 18,
    solaris => 2 ** 18,
    sunos   => 2 ** 18,
    dec_osf => 2 ** 20,
    tru64   => 2 ** 20, # correct value for $OSNAME on Tru64?
    hpux    => 2 ** 24,
);

my %LAYOUTFIELDS = (
    '*' => 'selected',
    'n' => 'display',
    'N' => 'name_too_long',
    's' => 'size_num',
    'S' => 'size_power',
    'z' => 'grand_num',
    'Z' => 'grand_power',
    'u' => 'uid',
    'g' => 'gid',
    'p' => 'mode',
    'a' => 'atimestring',
    'c' => 'ctimestring',
    'm' => 'mtimestring',
    'l' => 'nlink',
    'i' => 'inode',
    'd' => 'rdev',
    'f' => 'diskinfo',
);

my %FIELDHEADINGS = (
    selected      => ' ',
    name          => 'filename',
    display       => 'filename',
    name_too_long => ' ',
    size          => 'size',
    size_num      => 'size',
    size_power    => ' ',
    grand         => 'total',
    grand_num     => 'total',
    grand_power   => ' ',
    inode         => 'inode',
    mode          => 'perm',
    atime         => 'date/atime',
    mtime         => 'date/mtime',
    ctime         => 'date/ctime',
    atimestring   => 'date/atime',
    mtimestring   => 'date/mtime',
    ctimestring   => 'date/ctime',
    uid           => 'userid',
    gid           => 'groupid',
    nlink         => 'lnks',
    rdev          => 'dev',
    diskinfo      => 'disk info',
);

my $screenheight    = 20;    # inner height
my $screenwidth     = 80;    # terminal width
my $position_at     = '.';   # start with cursor here

my (@command_history, @mode_history, @path_history, @regex_history,
    @perlcmd_history, @time_history);

my %HISTORIES = (
    history_command => \@command_history,
    history_mode    => \@mode_history,
    history_path    => \@path_history,
    history_regex   => \@regex_history,
    history_time    => \@time_history,
    history_perlcmd => \@perlcmd_history
);

my (
    # lookup tables
    %usercache, %groupcache, %pfmrc, @signame, %dircolors, %framecolors,
    # screen- and keyboard objects, screen parameters
    $scr, $kbd, $wasresized, $currentpan,
    # modes
    $sort_mode, $multiple_mode, $swap_mode, $dot_mode, $dotdot_mode, $white_mode,
    $mouse_mode, $color_mode, $ident_mode, $radix_mode, $clobber_mode, $path_mode,
    # dir- and disk info
    $currentdir, $oldcurrentdir, @dircontents, @showncontents, %currentfile,
    %disk, $swap_state, %total_nr_of, %selected_nr_of, $ident,
    # cursor position
    $currentline, $baseindex, $cursorcol, $filenamecol, $infocol, $filerecordcol,
    # misc config options
    $editor, $pager, $viewer, $printcmd, $ducmd, $showlockchar, $e,
    $autoexitmultiple, $cursorveryvisible, $clsonexit, $rdevtomajor,
    $autowritehistory, $trspace, $swap_persistent, $mouseturnoff,
    @colorsetnames, %filetypeflags, $swapstartdir, $waitlaunchexec,
    # layouts and formatting
    $currentformatline, $currentformatlinewithinfo,
    @layoutfields, @layoutfieldswithinfo, @columnlayouts, $currentlayout, $formatname,
    $maxfilenamelength, $maxfilesizelength, $maxgrandtotallength, $infolength,
    # misc
    $white_cmd, @unwo_cmd,
);

##########################################################################
# read/write resource file and history file

sub whichconfigfile {
    return $ENV{PFMRC} ? $ENV{PFMRC} : "$CONFIGDIRNAME/$CONFIGFILENAME";
}

sub write_pfmrc {
    my @resourcefile;
    my $secs_per_32_days = 60 * 60 * 24 * 32;
    my $maxdatelen = 0;
    # the default layouts assume that the default timestamp format is 15 chars wide.
    # find out if this is enough, taking the current locale into account.
    foreach (0 .. 11) {
        $maxdatelen = max($maxdatelen, length strftime("%b", gmtime($secs_per_32_days * $_)));
    }
    $maxdatelen -= 3;
    if (open MKPFMRC, '>' . whichconfigfile()) {
        # both __DATA__ and __END__ markers are used at the same time
        while (($_ = <DATA>) !~ /^__END__$/) {
            s/^(##? Version )x$/$1$VERSION/m;
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

sub read_pfmrc {
    %pfmrc = ();
    unless (-r whichconfigfile()) {
        unless ($ENV{PFMRC} || -d $CONFIGDIRNAME) {
            # only make directory for default location ($ENV{PFMRC} unset)
            mkdir $CONFIGDIRNAME, $CONFIGDIRMODE;
        }
        write_pfmrc();
    }
    if (open PFMRC, whichconfigfile()) {
        while (<PFMRC>) {
            # the pragma 'locale' causes problems with reading in the configfile when using UTF-8
            no locale;
            if (/# Version ([\w\.]+)$/ and $1 lt $VERSION and !$_[0]) {
                # will not be in message color: usecolor not yet parsed
                neat_error(
                  "Warning: your $CONFIGFILENAME version $1 may be outdated.\r\n"
                . "Please see pfm(1), under DIAGNOSIS."
                );
                $scr->key_pressed($IMPORTANTDELAY);
            }
            s/#.*//;
            if (s/\\\n?$//) { $_ .= <PFMRC>; redo; }
#            if (/^\s*([^:[\s]+(?:\[[^]]+\])?)\s*:\s*(.*)$/o) {
             if (/^[ \t]*([^: \t[]+(?:\[[^]]+\])?)[ \t]*:[ \t]*(.*)$/o) {
#                print STDERR "-$1";
                $pfmrc{$1} = $2;
            }
        }
        close PFMRC;
    }
    goto &parse_pfmrc;
}

sub parse_pfmrc { # $readflag - show copyright only on startup (first read)
    local $_;
    my ($termkeys, $oldkey);
    %dircolors = %framecolors = %filetypeflags = ();
    # 'usecolor' - find out when color must be turned _off_
    # Term::ANSIScreen solution
#    unless (defined($ENV{ANSI_COLORS_DISABLED})) {
#        if (isno($pfmrc{usecolor}) or
#            ($ENV{TERM} !~ /(^linux$|color)/ && $pfmrc{usecolor} ne 'force')
#        ) {
#            $ENV{ANSI_COLORS_DISABLED} = 1;
#        }
#    }
    # Term::ScreenColor solution
    if (defined($ENV{ANSI_COLORS_DISABLED}) or isno($pfmrc{usecolor})) {
        $scr->colorizable(0);
    } elsif ($pfmrc{usecolor} eq 'force') {
        $scr->colorizable(1);
    }
    # 'copyrightdelay', 'cursorveryvisible', 'erase', 'keymap'
    copyright($pfmrc{copyrightdelay}) unless $_[0];
    $cursorveryvisible = isyes($pfmrc{cursorveryvisible});
    system ('tput', $cursorveryvisible ? 'cvvis' : 'cnorm');
    system ('stty', 'erase', $pfmrc{erase}) if defined($pfmrc{erase});
    $kbd->set_keymap($pfmrc{keymap})        if $pfmrc{keymap};
    # time/date format for clock and timestamps
    $pfmrc{clockdateformat} ||= '%Y %b %d';
    $pfmrc{clocktimeformat} ||= '%H:%M:%S';
    $pfmrc{timestampformat} ||= '%y %b %d %H:%M';
    # some configuration options are NOT fetched into common scalars
    # (e.g. confirmquit) - however, they remain accessable in %pfmrc
    # don't change initialized settings that are modifiable by key commands
    $clsonexit         = isyes($pfmrc{clsonexit});
    $waitlaunchexec    = isyes($pfmrc{waitlaunchexec});
    $autowritehistory  = isyes($pfmrc{autowritehistory});
    $autoexitmultiple  = isyes($pfmrc{autoexitmultiple});
    $mouseturnoff      = isyes($pfmrc{mouseturnoff});
    $swap_persistent   = isyes($pfmrc{persistentswap});
    $trspace           = isyes($pfmrc{translatespace}) ? ' ' : '';
    $dotdot_mode       = isyes($pfmrc{dotdotmode});
    $white_mode        = isyes($pfmrc{defaultwhitemode}) if !defined $white_mode;
    $dot_mode          = isyes($pfmrc{defaultdotmode})   if !defined $dot_mode;
    $clobber_mode      = isyes($pfmrc{defaultclobber})   if !defined $clobber_mode;
    $sort_mode         = $pfmrc{defaultsortmode} || 'n'   if !defined $sort_mode;
    $radix_mode        = $pfmrc{defaultradix}    || 'hex' if !defined $radix_mode;
    $path_mode         = $pfmrc{defaultpathmode} || 'log' if !defined $path_mode;
    $currentlayout     = $pfmrc{defaultlayout}   ||  0    if !defined $currentlayout;
    $e                 = $pfmrc{escapechar}      || '=';
    $rdevtomajor       = $RDEVTOMAJOR{$^O} || $RDEVTOMAJOR{default};
    $ducmd             = $pfmrc{ducmd} || $DUCMDS{$^O} || $DUCMDS{default};
    $ducmd             =~ s/\$\{e\}/$e/g;
    $mouse_mode        = $pfmrc{defaultmousemode}  || 'xterm' if !defined $mouse_mode;
    $mouse_mode        = ($mouse_mode eq 'xterm' && $ENV{TERM} =~ /xterm/) || isyes($mouse_mode);
    ($printcmd)        = ($pfmrc{printcmd}) ||
                         ($ENV{PRINTER} ? "lpr -P$ENV{PRINTER} ${e}2" : "lpr ${e}2");
    $showlockchar      = ( $pfmrc{showlock} eq 'sun' && $^O =~ /sun|solaris/i
                             or isyes($pfmrc{showlock}) ) ? 'l' : 'S';
    $ident_mode        = $IDENTMODES{$pfmrc{defaultident}} || 0 if !defined $ident_mode;
    $viewer            = $pfmrc{viewer} || 'xv';
    $editor            = $ENV{VISUAL} || $ENV{EDITOR}  || $pfmrc{editor} || 'vi';
    $pager             = $ENV{PAGER}  || $pfmrc{pager} || ($^O =~ /linux/i ? 'less' : 'more');
    # flags
    if ($pfmrc{filetypeflags} eq 'dirs') {
        %filetypeflags = ( d => $FILETYPEFLAGS{d} );
    } elsif (isyes($pfmrc{filetypeflags})) {
        %filetypeflags = %FILETYPEFLAGS;
    } else {
        %filetypeflags = ();
    }
    # split 'columnlayouts'
    @columnlayouts     = split(/:/, ( $pfmrc{columnlayouts}
        ? $pfmrc{columnlayouts}
        :   '* nnnnnnnnnnnnnnnnnnnnnnnnnnnssssssss mmmmmmmmmmmmmmmm pppppppppp ffffffffffffff:'
        .   '* nnnnnnnnnnnnnnnnnnnnnnnnnnnssssssss aaaaaaaaaaaaaaaa pppppppppp ffffffffffffff:'
        .   '* nnnnnnnnnnnnnnnnnnnnnssssssss uuuuuuuu gggggggglllll pppppppppp ffffffffffffff:'
    ));
    # repair pre-1.84 style (Y)our commands
    foreach (grep /^.$/, keys %pfmrc) {
        $oldkey = $_;
        s/^([[:upper:]])\b/your[\l$1]/;
        s/^([[:lower:]])\b/your[\u$1]/;
        $pfmrc{$_} = $pfmrc{$oldkey};
        delete $pfmrc{$oldkey};
    }
    # additional key definitions 'keydef'
    if ($termkeys = $pfmrc{'keydef[*]'} .':'. $pfmrc{"keydef[$ENV{TERM}]"}) {
        $termkeys =~ s/(\\e|\^\[)/\e/gi;
        # this does not allow : chars to appear in escape sequences!
        foreach (split /:/, $termkeys) {
            /^(\w+)=(.*)/ and $scr->def_key($1, $2);
        }
    }
    # init colorsets, ornaments, ident, formatlines, enable mouse
    parse_colorsets();
    setornaments();
    initident();
    makeformatlines();
    mouseenable($mouse_mode);
}

sub parse_colorsets {
    if (isyes($pfmrc{importlscolors}) and $ENV{LS_COLORS} || $ENV{LS_COLOURS}){
        $pfmrc{'dircolors[ls_colors]'} =   $ENV{LS_COLORS} || $ENV{LS_COLOURS};
    }
    $pfmrc{'dircolors[off]'}   = '';
    $pfmrc{'framecolors[off]'} =
        'title=reverse:swap=reverse:footer=reverse:highlight=bold:';
    # this %{{ }} construct keeps values unique
    @colorsetnames = keys %{{
        map { /\[(\w+)\]/; $1, '' }
        grep { /^(dir|frame)colors\[[^*]/ } keys(%pfmrc)
    }};
    # keep the default outside of @colorsetnames
    defined($pfmrc{'dircolors[*]'})   or $pfmrc{'dircolors[*]'}   = '';
    defined($pfmrc{'framecolors[*]'}) or $pfmrc{'framecolors[*]'} =
        'header=white on blue:multi=bold reverse cyan on white:'
    .   'title=bold reverse cyan on white:swap=reverse black on cyan:'
    .   'footer=bold reverse blue on white:message=bold cyan:highlight=bold:';
    foreach (@colorsetnames) {
        # should there be no dircolors[thisname], use the default
        defined($pfmrc{"dircolors[$_]"})
            or $pfmrc{"dircolors[$_]"} = $pfmrc{'dircolors[*]'};
        while ($pfmrc{"dircolors[$_]"} =~ /([^:=*]+)=([^:=]+)/g ) {
            $dircolors{$_}{$1} = $2;
        }
        # should there be no framecolors[thisname], use the default
        defined($pfmrc{"framecolors[$_]"})
            or $pfmrc{"framecolors[$_]"} = $pfmrc{'framecolors[*]'};
        while ($pfmrc{"framecolors[$_]"} =~ /([^:=*]+)=([^:=]+)/g ) {
            $framecolors{$_}{$1} = $2;
        }
    }
    # now set color_mode if unset
    $color_mode ||= defined($ENV{ANSI_COLORS_DISABLED})
        ? 'off'
        : $pfmrc{defaultcolorset} || (defined $dircolors{ls_colors} ? 'ls_colors' : $colorsetnames[0]);
}

sub write_history {
    my $failed;
    $scr->at(0,0)->clreol();
    foreach (keys(%HISTORIES)) {
        if (open (HISTFILE, ">$CONFIGDIRNAME/$_")) {
            print HISTFILE join "\n", @{$HISTORIES{$_}}, '';
            close HISTFILE;
        } elsif (!$failed) {
            putmessage("Unable to save (part of) history: $!");
            $failed++; # warn only once
        }
    }
    putmessage('History written successfully') unless $failed;
    $scr->key_pressed($ERRORDELAY);
    $scr->key_pressed($IMPORTANTDELAY) if $failed;
    return $R_HEADER;
}

sub read_history {
    my $hfile;
    # some defaults - set them here because $e is known only now
    @command_history = ('du -ks * | sort -n', "man ${e}1");
    @mode_history    = ('755', '644');
    @path_history    = ('/', $ENV{HOME});
    @regex_history   = ('\.jpg$');
#    @time_history;
#    @perlcmd_history;
    foreach (keys(%HISTORIES)) {
        $hfile = "$CONFIGDIRNAME/$_";
        if (-s $hfile and open (HISTFILE, $hfile)) {
            chomp( @{$HISTORIES{$_}} = <HISTFILE> );
            close HISTFILE;
        }
    }
}

sub write_cwd {
    if (open CWDFILE,">$CONFIGDIRNAME/$CWDFILENAME") {
        print CWDFILE $currentdir, "\n";
        close CWDFILE;
    } else {
        putmessage("Unable to create $CONFIGDIRNAME/$CWDFILENAME: $!\n");
    }
    if ($swap_state && $swap_persistent && open SWDFILE,">$CONFIGDIRNAME/$SWDFILENAME") {
        print SWDFILE $swap_state->{path}, "\n";
        close SWDFILE;
    } else {
        unlink "$CONFIGDIRNAME/$SWDFILENAME";
    }
}

##########################################################################
# some translations

sub getversion {
    my $ver  = 'unknown';
    my $year = 7*7*41; # don't edit this. If the year cannot be read, at least this is correct
    # the pragma 'locale' causes problems with reading in the configfile when using UTF-8
    no locale;
    if ( open (SELF, $0) || open (SELF, `which $0`) ) {
        while (<SELF>) {
            /^#+\s+Version:\s+([\w\.]+)/ and $ver  = "$1";
            /^#+\s+Date:\s+(\d+)/        and $year = "$1", last;
        }
        close SELF;
    }
    return ($ver, $year);
}

sub find_uid {
    my $uid = $_[0];
    return $usercache{$uid} || +($usercache{$uid} = scalar(defined($uid) ? getpwuid($uid) : '') || $uid);
}

sub find_gid {
    my $gid = $_[0];
    return $groupcache{$gid} || +($groupcache{$gid} = scalar(defined($gid) ? getgrgid($gid) : '') || $gid);
}

sub init_signames {
    my $i = 0;
    my @signame;
    foreach (split(/ /, $Config{sig_name})) {
#        $signo{$name} = $i;
        $signame[$i++] = $_;
    }
    return @signame;
}

#sub colornum2name {
#    my %attributes_r = map { s/^(.)$/0$1/; $_ }
#                     reverse %Term::ANSIScreen::attributes;
#    my $intermittent = shift;
#    $intermittent =~ s/\b([034]\d)\b/$attributes_r{$1}/g;
#    $intermittent =~ tr/;/ /;
#    return $intermittent;
#}

sub setornaments {
    my $messcolor = $framecolors{$color_mode}{message};
    my @cols;
    unless (exists $ENV{PERL_RL}) {
        # this would have been nice, however,
        # readline processes only the first (=most important) capability
        push @cols, 'mr' if ($messcolor =~ /reverse/);
        push @cols, 'md' if ($messcolor =~ /bold/);
        push @cols, 'us' if ($messcolor =~ /under(line|score)/);
#        $kbd->ornaments(join(';', @cols) . ',me,,');
        $kbd->ornaments($cols[0] . ',me,,');
    }
}

sub formatted {
    local $^A = '';
    formline(shift(), @_);
    return $^A;
}

sub time2str {
    my ($time, $flag) = @_;
    if ($flag == $TIME_FILE) {
        return strftime ($pfmrc{timestampformat}, localtime $time);
    } else {
        return strftime ($pfmrc{clockdateformat}, localtime $time),
               strftime ($pfmrc{clocktimeformat}, localtime $time);
    }
}

sub mode2str {
    my $strmode;
    my $nummode = shift; # || 0;
    my $octmode = sprintf("%lo", $nummode);
    $octmode    =~ /(\d\d?)(\d)(\d)(\d)(\d)$/;
    $strmode    = substr('-pc?d?b?-nl?sDw?', oct($1) & 017, 1)
             . $SYMBOLIC_MODES[$3] . $SYMBOLIC_MODES[$4] . $SYMBOLIC_MODES[$5];
    # 0000                000000  unused
    # 1000  S_IFIFO   p|  010000  fifo (named pipe)
    # 2000  S_IFCHR   c   020000  character special
    # 3000  S_IFMPC       030000  multiplexed character special (V7)
    # 4000  S_IFDIR   d/  040000  directory
    # 5000  S_IFNAM       050000  XENIX named special file with two subtypes, distinguished by st_rdev values 1,2
    # 0001  S_INSEM   s   000001  semaphore
    # 0002  S_INSHD   m   000002  shared data
    # 6000  S_IFBLK   b   060000  block special
    # 7000  S_IFMPB       070000  multiplexed block special (V7)
    # 8000  S_IFREG   -   100000  regular
    # 9000  S_IFNWK   n   110000  network special (HP-UX)
    # a000  S_IFLNK   l@  120000  symbolic link
    # b000  S_IFSHAD      130000  Solaris ACL shadow inode,not seen by userspace
    # c000  S_IFSOCK  s=  140000  socket
    # d000  S_IFDOOR  D>  150000  Solaris door
    # e000  S_IFWHT   w%  160000  BSD whiteout
    #
    if ($2 & 4) {       substr( $strmode,3,1) =~ tr/-x/Ss/ }
    if ($2 & 2) { eval "substr(\$strmode,6,1) =~ tr/-x/${showlockchar}s/" }
    if ($2 & 1) {       substr( $strmode,9,1) =~ tr/-x/Tt/ }
    return $strmode;
}

sub fit2limit {
    my $size_power = ' ';
    # size_num might be uninitialized or major/minor
    my ($size_num, $limit) = @_;
    while ($size_num > $limit) {
        $size_num = int($size_num/1024);
        $size_power =~ tr/KMGTPEZ/MGTPEZY/ || do { $size_power = 'K' };
    }
    return ($size_num, $size_power);
}

#sub unquotemeta {
#    local $1;
##    return map { s/\\(.)/$1/g; $_ } @_;
#    $_[0] =~ s/\\(.)/$1/g;
#    return $_[0];
#}

sub condquotemeta { # condition, string
#    return shift() ? map { quotemeta } @_ : @_;
    return $_[0] ? quotemeta($_[1]) : $_[1];
}

sub expand_replace { # esc-category, namenoext, name, ext
    my $qif = shift;
    for ($_[0]) {
        /1/ and return condquotemeta($qif, $_[1]);
        /2/ and return condquotemeta($qif, $_[2]);
        /3/ and return condquotemeta($qif, $currentdir);
        /4/ and return condquotemeta($qif, $disk{mountpoint});
        /5/ and return condquotemeta($qif, $swap_state->{path}) if $swap_state;
        /6/ and return condquotemeta($qif, basename($currentdir));
        /7/ and return condquotemeta($qif, $_[3]);
        /e/ and return condquotemeta($qif, $editor);
        /p/ and return condquotemeta($qif, $pager);
        /v/ and return condquotemeta($qif, $viewer);
        # this also handles the special $e$e case - don't quotemeta() this!
        return $_;
    }
}

sub expand_3456_escapes { # quoteif, command, whatever
    my $qif = $_[0];
    my $qe  = quotemeta $e;
    # readline understands ~ notation; now we understand it too
    $_[1] =~ s/^~(\/|$)/$ENV{HOME}\//;
    # ~user is not replaced if it is not in the passwd file
    # the format of passwd(5) dictates that a username cannot contain colons
    $_[1] =~ s/^~([^:\/]+)/(getpwnam $1)[7] || "~$1"/e;
    # the next generation in quoting
    $_[1] =~ s/$qe([^127])/expand_replace($qif, $1)/ge;
}

sub expand_escapes { # quoteif, command, \%currentfile
    my $qif       = $_[0];
    my $name      = $_[2]{name};
    my $qe        = quotemeta $e;
    my ($namenoext, $ext);
#    $namenoext = $name =~ /^(.*)\.([^\.]+)$/ ? $1 : $name;
    # included '.' in \7
    if ($name =~ /^(.*)(\.[^\.]+)$/) {
        $namenoext = $1;
        $ext = $2;
    } else {
        $namenoext = $name;
        $ext = '';
    }
    # readline understands ~ notation; now we understand it too
    $_[1] =~ s/^~(\/|$)/$ENV{HOME}\//;
    # ~user is not replaced if it is not in the passwd file
    # the format of passwd(5) dictates that a username cannot contain colons
    $_[1] =~ s/^~([^:\/]+)/(getpwnam $1)[7] || "~$1"/e;
    # the next generation in quoting
    $_[1] =~ s/$qe(.)/expand_replace($qif, $1, $namenoext, $name, $ext)/ge;
}

sub isyes {
    return $_[0] =~ /^(1|y|yes|true|on|always)$/i;
}

sub isno {
    return $_[0] =~ /^(0|n|no|false|off|never)$/;
}

sub min ($$) {
    return +($_[1] < $_[0]) ? $_[1] : $_[0];
}

sub max ($$) {
    return +($_[1] > $_[0]) ? $_[1] : $_[0];
}

sub inhibit ($$) {
    return !$_[0] && $_[1];
}

sub triggle ($) {
    ++$_[0] > 2 and $_[0] = 0;
    return $_[0];
}

sub toggle ($) {
    $_[0] = !$_[0];
}

##########################################################################
# more translations

sub readintohist { # \@history, $prompt, [$default_input]
    local $SIG{INT} = 'IGNORE'; # do not interrupt pfm
    my $history     = shift;
    my $prompt      = shift || '';
    my $input       = shift || '';
#    $kbd->SetHistory(@$history);
    set_term_history($kbd, @$history);
    $input = $kbd->readline($prompt, $input);
    if ($input =~ /\S/ and $input ne ${$history}[-1]) {
        push (@$history, $input);
        shift (@$history) if ($#$history > $MAXHISTSIZE);
    }
    return $input;
}

sub set_term_history {
    my $keyboard = shift;
#    my $h    = _history_file;
#    if ( $keyboard->Features->{readHistory} ) {
#        $keyboard->ReadHistory($h);
#    }
#    elsif ( $keyboard->Features->{setHistory} ) {
#        if ( -e $h ) {
#            my @h = File::Slurp::read_file($h);
#            chomp @h;
#            $keyboard->SetHistory(@h);
#        }
#    }
    if ($keyboard->Features->{setHistory}) {
        $keyboard->SetHistory(@_);
    }
    # else fail silently
    return $keyboard;
}

sub mychdir {
    my $goal = $_[0];
    my $result;
    if ($goal eq '') {
        $goal = $ENV{HOME};
    } elsif (-d $goal and $goal !~ m!^/!) {
        $goal = "$currentdir/$goal";
    } elsif ($goal !~ m!/!) {
        foreach (split /:/, $ENV{CDPATH}) {
            if (-d "$_/$goal") {
                $goal = "$_/$goal";
                $scr->at(0,0)->clreol();
                display_error("Using $goal");
                $scr->at(0,0);
                last;
            }
        }
    }
    $goal = canonicalize_path($goal);
    if ($result = chdir $goal and $goal ne $currentdir) {
        $oldcurrentdir = $currentdir;
        $currentdir = $goal;
#    } elsif (!$result) {
#        $currentdir = getcwd();
    }
    return $result;
}

sub dirname {
    $_[0] =~ m!^(.*)/.+?!;
    return length($1) ? $1
                      : $_[0] =~ m!^/! ? '/'
                                       : '.';
}

sub basename {
    $_[0] =~ /\/([^\/]*)\/?$/; # ok, it has LTS but this looks better in vim
    return length($1) ? $1 : $_[0];
}

sub reversepath {
    # reverses the path from target to symlink, returns the path from symlink to target
    my ($symlink_target_abs, $symlink_name_rel) = map { canonicalize_path($_) } @_;
    # $result ultimately is named as requested
    my $result = basename($symlink_target_abs);
    if ($symlink_name_rel !~ m!/!) {
        # in same dir: reversed path == rel_path
        return $result;
    }
    # lose the filename from the symlink_target_abs and symlink_name_rel, keep the directory
    $symlink_target_abs = dirname($symlink_target_abs);
    $symlink_name_rel   = dirname($symlink_name_rel);
    # reverse this path as follows:
    # foreach_left_to_right pathname element of symlink_name_rel {
    #   case '..' : prepend basename target to result
    #   case else : prepend '..' to result
    # }
    foreach (split (m!/!, $symlink_name_rel)) {
        if ($_ eq '..') {
            $result = basename($symlink_target_abs) .'/'. $result;
            $symlink_target_abs = dirname($symlink_target_abs);
        } else {
            $result = '../'. $result;
            $symlink_target_abs .= '/'.$_;
        }
    }
    return canonicalize_path($result);
}

sub canonicalize_path {
    # works like realpath() but does not resolve symlinks
    my $path = shift;
    1 while $path =~ s!/\./!/!g;
    1 while $path =~ s!^\./+!!g;
    1 while $path =~ s!/\.$!!g; # keep vim happy with this !
    1 while $path =~ s!
        (^|/)                # start of string or following /
        (?:\.?[^./][^/]*
        |\.\.[^/]+)          # any filename except ..
        /+                   # any number of slashes
        \.\.                 # the name '..'
        (?=/|$)              # followed by nothing or a slash
        !$1!gx;
    1 while $path =~ s!//!/!g;
    1 while $path =~ s!^/\.\.(/|$)!/!g;
    $path =~ s!(.)/$!$1!g; # keep vim happy with this !
    length($path) or $path = '/';
    return $path;
}

sub reducepaths {
    # remove identical prefix from path
    my ($symlink_target_abs, $symlink_name_abs) = @_;
    my $subpath;
    while (($subpath) = ($symlink_target_abs =~ m!^(/[^/]+)(?:/|$)!)
    and index($symlink_name_abs, $subpath) == 0)
    {
        $symlink_target_abs =~ s!^/[^/]+!!;
        $symlink_name_abs   =~ s!^/[^/]+!!;
    }
    # one of these could be empty now.
    # i'm beginning to feel that all this manipulation might be easier with VMS pathnames
    return $symlink_target_abs, $symlink_name_abs;
}

sub fileforall {
    my ($index, $loopfile);
    my ($do_this, $statflag) = @_;
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                exclude($loopfile, '.');
                $loopfile = $do_this->($loopfile);
                if ($statflag) {
                    $dircontents[$index] = stat_entry($loopfile->{name}, $loopfile->{selected});
                }
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        %currentfile = %{ $do_this->(\%currentfile) };
        if ($statflag) {
            $showncontents[$currentline+$baseindex] = stat_entry($currentfile{name}, $currentfile{selected});
        }
        copyback($currentfile{name});
    }
}

sub multi_to_single {
    my $qe = quotemeta $e;
    my $do_a_refresh = $R_PATHINFO;
    if ($multiple_mode and $_[0] !~ /(?<!$qe)(?:$qe$qe)*${e}[127]/ and !-d $_[0]) {
        $scr->at(0,0);
        putmessage('Cannot do multifile operation when destination is single file.');
        $scr->at(0,0);
        $do_a_refresh |= pressanykey(); # screen might have been resized
        path_info();
        return $do_a_refresh;
    } else {
        return 0;
    }
}

sub restat_copyback {
    $showncontents[$currentline+$baseindex] = stat_entry($currentfile{name}, $currentfile{selected});
    if ($showncontents[$currentline+$baseindex]{nlink} == 0) {
#        if ($pfmrc{keeplostfiles}) {
            $showncontents[$currentline+$baseindex]{display} .= $LOSTMSG;
#        } else {
#            splice @dircontents, $index, 1;
#            splice @showncontents, $nameindexmap{$loopfile->{name}}, 1;
#        }
    }
    copyback($currentfile{name});
}

sub maxpan {
    my ($temp, $width) = @_;
    my $panspace;
    # this is an assignment on purpose
    if ($panspace = 2 * (length($temp) > $width)) {
        eval "
            \$temp =~ s/^((?:\\S+ )+?).{1,".($width - $panspace)."}\$/\$1/;
        ";
        return $temp =~ tr/ //;
    } else {
        return 0;
    };
}

sub exclude { # $entry,$oldmark
    my ($entry, $oldmark) = @_;
    $oldmark ||= " ";
    $entry->{selected} = $oldmark;
    $selected_nr_of{$entry->{type}}--;
    $entry->{type} =~ /-/ and $selected_nr_of{bytes} -= $entry->{size};
}

sub include { # $entry
    my $entry = $_[0];
    $entry->{selected} = "*";
    $selected_nr_of{$entry->{type}}++;
    $entry->{type} =~ /-/ and $selected_nr_of{bytes} += $entry->{size};
}

sub reformat {
    foreach (@dircontents) {
        $_->{name_too_long} = length($_->{display}) > $maxfilenamelength-1
            ? $NAMETOOLONGCHAR : ' ';
        @{$_}{qw(size_num size_power)} =
            fit2limit($_->{size}, $maxfilesizelength);
        @{$_}{qw(grand_num grand_power)} =
            fit2limit($_->{grand}, $maxgrandtotallength);
        @{$_}{qw(atimestr ctimestr mtimestr)} =
            map { time2str($_, $TIME_FILE) } @{$_}{qw(atime ctime mtime)};
    }
}

sub dirlookup {
    # this assumes that the entry will be found
    my ($name, @array) = @_;
    my $found = $#array;
    while ($found >= 0 and $array[$found]{name} ne $name) {
        $found--;
    }
    return $found;
}

sub followmode {
    my %currentfile = %{$_[0]};
    return $currentfile{type} ne 'l'
           ? $currentfile{mode}
           : mode2str((stat $currentfile{name})[2]);
}

sub copyback {
    # copy a changed entry from @showncontents back to @dircontents
    $dircontents[dirlookup($_[0], @dircontents)] = $showncontents[$currentline+$baseindex];
}

sub isorphan {
    return ! -e $_[0];
}

sub resizecatcher {
    $wasresized = 1;
    $SIG{WINCH} = \&resizecatcher;
}

#sub reaper {
#    (wait() == -1) ? 0 : $?;
#    $SIG{CHLD} = \&reaper;
#}

sub mouseenable {
    if ($_[0]) {
        print "\e[?9h";
    } else {
        print "\e[?9l";
    }
}

sub stty_raw {
    if ($_[0]) {
        system qw(stty -raw echo);
        $scr->echo();
    } else {
        system qw(stty raw -echo);
        $scr->noecho();
    }
}

sub testdirempty {
    opendir TESTDIR, $_[0];
    readdir TESTDIR;                    # every directory has at least a '.' entry
    readdir TESTDIR;                    # and a '..' entry
    my $third_entry = readdir TESTDIR;  # but not necessarily a third entry
    closedir TESTDIR;
    # if the directory could not be read at all, this will return true.
    # instead of catching the exception here, we will simply wait for 'unlink' to return false
    return !$third_entry;
}

sub white_commands {
    $white_cmd = '';
    @unwo_cmd  = ();
    foreach (split /:/, $ENV{PATH}) {
        if (!@unwo_cmd) {
            if (-f "$_/unwhiteout") {
                @unwo_cmd = qw(unwhiteout);
            } elsif (-f "$_/unwo") {
                @unwo_cmd = qw(unwo);
            }
        }
        if (!$white_cmd) {
            if (-f "$_/listwhite") {
                $white_cmd = 'listwhite';
            } elsif (-f "$_/lsw") {
                $white_cmd = 'lsw';
            }
        }
    }
    unless (@unwo_cmd) {
        @unwo_cmd = qw(rm -W);
    }
}

sub globalinit {
    my ($startingdir, $opt_version, $opt_help);
    Getopt::Long::Configure(qw'bundling permute');
    GetOptions ('s|swap=s'  => \$swapstartdir,
                'h|help'    => \$opt_help,
                'v|version' => \$opt_version) or $opt_help = 2;
    usage()        if $opt_help;
    printversion() if $opt_version;
    exit 1          if $opt_help == 2;
    exit 0          if $opt_help or $opt_version;
    $startingdir = shift @ARGV;
    $SIG{WINCH}  = \&resizecatcher;
    # read_pfmrc() needs $kbd for setting keymap and ornaments
    $kbd = new Term::ReadLine 'pfm';
    $scr = new Term::ScreenColor;
    $scr->clrscr();
    if ($scr->rows()) { $screenheight = $scr->rows()-$BASELINE-2 }
    if ($scr->cols()) { $screenwidth  = $scr->cols() }
    @signame        = init_signames();
    %selected_nr_of = %total_nr_of   = ();
    $swap_mode      = $multiple_mode = 0;
    $swap_state     = 0;
    $currentpan     = 0;
    $baseindex      = 0;
    white_commands();
    read_pfmrc($READ_FIRST);
    read_history();
    init_frame();
    # now find starting directory
    $oldcurrentdir = $currentdir = getcwd();
    if ($startingdir ne '') {
        unless (mychdir($startingdir)) {
            $scr->at(0,0)->clreol();
            display_error("$startingdir: $! - using .");
            $scr->key_pressed($IMPORTANTDELAY);
        }
    }
}

##########################################################################
# debugging helper commands

sub dumprefreshflags {
    my $res;
    $res .= "R_QUIT\n"        if $_[0] & $R_QUIT;
    $res .= "R_INIT_SWAP\n"   if $_[0] & $R_INIT_SWAP;
    $res .= "R_NEWDIR\n"      if $_[0] & $R_NEWDIR;
    $res .= "R_DIRCONTENTS\n" if $_[0] & $R_DIRCONTENTS;
    $res .= "R_DIRSORT\n"     if $_[0] & $R_DIRSORT;
    $res .= "R_CLEAR\n"       if $_[0] & $R_CLEAR;
    $res .= "R_DIRFILTER\n"   if $_[0] & $R_DIRFILTER;
    $res .= "R_DIRLIST\n"     if $_[0] & $R_DIRLIST;
    $res .= "R_DISKINFO\n"    if $_[0] & $R_DISKINFO;
    $res .= "R_FOOTER\n"      if $_[0] & $R_FOOTER;
    $res .= "R_TITLE\n"       if $_[0] & $R_TITLE;
    $res .= "R_PATHINFO\n"    if $_[0] & $R_PATHINFO;
    $res .= "R_HEADER\n"      if $_[0] & $R_HEADER;
    $res .= "R_STRIDE\n"      if $_[0] & $R_STRIDE;
    $res .= "R_NOP\n"         if $_[0] & $R_NOP;
    return $res;
}

sub convwhite {
    $showncontents[$currentline+$baseindex]{type} = 'w';
    $dircontents  [$currentline+$baseindex]{type} = 'w';
    $showncontents[$currentline+$baseindex]{mode} =~ s/^./w/;
    $dircontents  [$currentline+$baseindex]{mode} =~ s/^./w/;
}

##########################################################################
# apply color

sub putmessage {
    $scr->putcolored($framecolors{$color_mode}{message}, @_);
}

sub decidecolor {
    my $f = shift;
    $f->{type}  eq 'w'        and return $dircolors{$color_mode}{wh};
    $f->{nlink} ==  0         and return $dircolors{$color_mode}{lo};
    $f->{type}  eq 'd'        and return $dircolors{$color_mode}{di};
    $f->{type}  eq 'l'        and return $dircolors{$color_mode}
                                        { isorphan($f->{name}) ? 'or' : 'ln' };
    $f->{type}  eq 'b'        and return $dircolors{$color_mode}{bd};
    $f->{type}  eq 'c'        and return $dircolors{$color_mode}{cd};
    $f->{type}  eq 'p'        and return $dircolors{$color_mode}{pi};
    $f->{type}  eq 's'        and return $dircolors{$color_mode}{so};
    $f->{type}  eq 'D'        and return $dircolors{$color_mode}{'do'};
    $f->{type}  eq 'n'        and return $dircolors{$color_mode}{nt};
    $f->{mode}  =~ /[xst]/    and return $dircolors{$color_mode}{ex};
    $f->{name}  =~ /(\.\w+)$/ and return $dircolors{$color_mode}{$1};
}

sub applycolor {
    my ($line, $length, %file) = @_;
    $length = $length ? 255 : $maxfilenamelength-1;
    $scr->at($line, $filenamecol)->putcolored(decidecolor(\%file), substr($file{name}, 0, $length));
}

##########################################################################
# small printing routines

sub validate_layoutnum {
    while ($currentlayout > $#columnlayouts) {
        $currentlayout -= @columnlayouts;
    }
    return $currentlayout;
}

sub makeformatlines {
    my ($squeezedlayoutline, $currentlayoutline, $firstwronglayout, $prev, $letter, $trans, $temp);
    LAYOUT: {
        $currentlayoutline = $columnlayouts[validate_layoutnum()];
        # we could also test /(^f|f$)/; but catch only fatal errors for now.
        unless ($currentlayoutline =~ /n/ and $currentlayoutline =~ /f/  and $currentlayoutline =~ /\*/) {
            $firstwronglayout ||= $currentlayout || '0 but true';
            $scr->at(0,0)->clreol();
            display_error("Bad layout #$currentlayout: a mandatory field is missing");
            $scr->key_pressed($IMPORTANTDELAY);
            $currentlayout++;
            if (validate_layoutnum() != $firstwronglayout) {
                redo LAYOUT;
            } else {
                $scr->at(0,0)->puts("Fatal error: No valid layout defined in " . whichconfigfile())->clreol()->at(1,0);
                stty_raw($TERM_COOKED);
                mouseenable($MOUSE_OFF);
                exit 2;
            }
        }
    }
    # layouts are all based on a screenwidth of 80: elongate filename field
    $currentlayoutline =~ s/n/'n' x ($screenwidth - 79)/e;
    # find out the length of the filename, filesize and info fields
    $infolength          =       ($currentlayoutline =~ tr/f//);
    $maxfilenamelength   =       ($currentlayoutline =~ tr/n//);
    $maxfilesizelength   = 10 ** ($currentlayoutline =~ tr/s// -1) -1;
    if ($maxfilesizelength < 2) { $maxfilesizelength = 2 }
    $maxgrandtotallength = 10 ** ($currentlayoutline =~ tr/z// -1) -1;
    if ($maxgrandtotallength < 2) { $maxgrandtotallength = 2 }
    # provide N, S and Z fields
    $currentlayoutline =~ s/n(?!n)/N/i;
    $currentlayoutline =~ s/s(?!s)/S/i;
    $currentlayoutline =~ s/z(?!z)/Z/i;
#    $currentlayoutline =~ s/(\s+)f/'F'x length($1) . 'f'/e;
#    $currentlayoutline =~ s/f(\s+)/'f' . 'F'x length($1)/e;
#    $gaplength = 
    ($temp = $currentlayoutline) =~ s/[^f].*//;
    $filerecordcol     = length $temp;
    $cursorcol         = index ($currentlayoutline, '*');
    $filenamecol       = index ($currentlayoutline, 'n');
    $infocol           = index ($currentlayoutline, 'f');
#    $gapcol            = index($currentlayoutline, 'F');
    foreach ($cursorcol, $filenamecol, $infocol, $filerecordcol) {
        if ($_ < 0) { $_ = 0 }
    }
    # determine the layout field set (no spaces)
    ($squeezedlayoutline = $currentlayoutline) =~ tr/*nNsSzZugpacmdilf /*nNsSzZugpacmdilf/ds;
    ($formatname = $squeezedlayoutline) =~ s/[*SNZ]//g;
    @layoutfields         = map { $LAYOUTFIELDS{$_} } grep { !/f/ } (split //, $squeezedlayoutline);
    @layoutfieldswithinfo = map { $LAYOUTFIELDS{$_} }               (split //, $squeezedlayoutline);
    # make the formatline
    $currentformatlinewithinfo = $currentformatline = $prev = '';
    foreach $letter (split //, $currentlayoutline) {
        if ($letter eq ' ') {
            $currentformatlinewithinfo .= ' ';
        } elsif ($prev ne $letter) {
            $currentformatlinewithinfo .= '@';
        } else {
            ($trans = $letter) =~ tr{*nNsSzZugpacmdilf}
                                    {<<<><><<<<<<<<>><};
            $currentformatlinewithinfo .= $trans;
        }
        $prev = $letter;
    }
    substr ($currentformatline = $currentformatlinewithinfo, $infocol, $infolength, '');
    return $currentformatline;
}

sub pathline {
    # pfff.. this has become very complicated since we wanted to handle
    # all those exceptions
    my ($path, $dev) = @_;
    my $overflow     = ' ';
    my $ELLIPSIS     = '..';
    my $normaldevlen = 12;
    my $actualdevlen = max($normaldevlen, length($dev));
    # the three in the next exp is the length of the overflow char plus the '[]'
    my $maxpathlen   = $screenwidth - $actualdevlen -3;
    my ($restpathlen, $disppath);
    $dev = $dev . ' 'x max($actualdevlen -length($dev), 0);
    FIT: {
        # the next line is supposed to contain an assignment
        unless (length($path) <= $maxpathlen and $disppath = $path) {
            # no fit: try to replace (part of) the name with ..
            # we will try to keep the first part e.g. /usr1/ because this often
            # shows the filesystem we're on; and as much as possible of the end
            unless ($path =~ /^(\/[^\/]+?\/)(.+)/) {
                # impossible to replace; just truncate
                # this is the case for e.g. /some_insanely_long_directory_name
                $disppath = substr($path, 0, $maxpathlen);
                $overflow = $NAMETOOLONGCHAR;
                last FIT;
            }
            ($disppath, $path) = ($1, $2);
            # the one being subtracted is for the '/' char in the next match
            $restpathlen = $maxpathlen -length($disppath) -length($ELLIPSIS) -1;
            unless ($path =~ /(\/.{1,$restpathlen})$/) {
                # impossible to replace; just truncate
                # this is the case for e.g. /usr/some_insanely_long_directory_name
                $disppath = substr($disppath.$path, 0, $maxpathlen);
                $overflow = $NAMETOOLONGCHAR;
                last FIT;
            }
            # pathname component candidate for replacement found; name will fit
            $disppath .= $ELLIPSIS . $1;
        }
    }
    return $disppath . ' 'x max($maxpathlen -length($disppath), 0)
         . $overflow . "[$dev]";
}

sub fileline { # $currentfile, @layoutfields
    my ($currentfile, @fields) = @_;
    $^A = '';
    formline($currentformatline, @{$currentfile}{@fields});
    return $^A;
}

sub highlightline { # true/false
    my $linecolor;
    $scr->at($currentline + $BASELINE, $filerecordcol);
    if ($_[0] == $HIGHLIGHT_ON) {
        $linecolor = $framecolors{$color_mode}{highlight};
        $scr->bold()        if ($linecolor =~ /bold/);
        $scr->reverse()     if ($linecolor =~ /reverse/);
#        $scr->underline()   if ($linecolor =~ /under(line|score)/);
        $scr->term()->Tputs('us', 1, *STDOUT)
                            if ($linecolor =~ /under(line|score)/);
    }
    $scr->putcolored($linecolor, fileline(\%currentfile, @layoutfields));
    applycolor($currentline + $BASELINE, $FILENAME_SHORT, %currentfile);
    $scr->reset()->normal()->at($currentline + $BASELINE, $cursorcol);
}

sub markcurrentline { # letter
    $scr->at($currentline + $BASELINE, $cursorcol)->puts($_[0]);
}

sub pressanykey {
    putmessage("\n*** Hit any key to continue ***"); # previously just cyan
    stty_raw($TERM_RAW);
    mouseenable($MOUSE_ON) if $mouse_mode && $mouseturnoff;
    if ($scr->getch() eq 'kmous') {
        $scr->getch(); # discard mouse info: co-ords and button
        $scr->getch();
        $scr->getch();
    };
    return handleresize() if $wasresized;
    return 0;
}

sub display_error {
    putmessage(@_);
    return $scr->key_pressed($ERRORDELAY); # return value often discarded by caller
}

sub neat_error {
    $scr->at(0,0)->clreol();
    display_error($_[0]);
    if ($multiple_mode) {
        return $R_PATHINFO;
    } else {
        return $R_FRAME;
    }
}

sub ok_to_remove_marks {
    my $sure;
    if (mark_info()) {
        $scr->at(0,0)->clreol();
        putmessage('OK to remove marks [Y/N]? ');
        $sure = $scr->getch();
        init_header();
        return ($sure =~ /y/i);
    }
    return 1;
}

sub promptforboundarytime {
    my $prompt = ($_[0] eq 'a' ? 'After' : 'Before')
               . " modification time CCYY-MM-DD hh:mm[.ss]: ";
    my $boundarytime;
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    $boundarytime = readintohist(\@time_history, $prompt);
    # init_header is done in handleinclude
    stty_raw($TERM_RAW);
    $boundarytime =~ tr/0-9.//dc;
    $boundarytime =~ /(....)(..)(..)(..)(..)(\...)?$/;
    $boundarytime = mktime($6, $5, $4, $3, $2-1, $1-1900, 0, 0, 0);
    return $boundarytime;
}

sub promptforwildfilename {
    my $prompt = 'Wild filename (regular expression): ';
    my $wildfilename;
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    $wildfilename = readintohist(\@regex_history, $prompt);
    # init_header is done in handleinclude
    stty_raw($TERM_RAW);
    eval "/$wildfilename/";
    if ($@) {
        display_error($@);
        $scr->key_pressed($IMPORTANTDELAY);
        $wildfilename = '^$';   # clear illegal regexp
    }
    return $wildfilename;
}

sub clearcolumn {
    my $spaces = ' ' x $infolength;
    foreach ($BASELINE .. $BASELINE+$screenheight) {
        $scr->at($_, $infocol)->puts($spaces);
    }
}

sub path_info {
    $scr->at($PATHLINE, 0)->puts(pathline($currentdir, $disk{'device'}));
}

##########################################################################
# headers, footers

sub fitbanner { # $header/footer, $screenwidth
    my ($banner, $virtwidth) = @_;
    my ($maxwidth, $spcount);
    if (length($banner) > $virtwidth) {
        $spcount  = maxpan($banner, $virtwidth);
        $maxwidth = $virtwidth -2*($currentpan > 0) -2*($currentpan < $spcount);
        $banner  .= ' ';
        eval "
            \$banner =~ s/^(?:\\S+ ){$currentpan,}?(.{1,$maxwidth}) .*/\$1/;
        ";
        if ($currentpan > 0       ) { $banner  = '< ' . $banner; }
        if ($currentpan < $spcount) { $banner .= ' >'; }
    }
    return $banner;
}

sub init_frame {
    init_header();
    init_title($swap_mode, $TITLE_DISKINFO, @layoutfieldswithinfo);
    init_footer();
}

sub init_title { # swap_mode, extra field, @layoutfieldswithinfo
    my ($smode, $info, @fields) = @_;
    my $linecolor;
    for ($info) {
        $_ == $TITLE_DISKINFO and $FIELDHEADINGS{diskinfo} = ' ' x ($infolength-14) . '     disk info';
        $_ == $TITLE_SORT     and $FIELDHEADINGS{diskinfo} = 'sort mode     ' . ' ' x ($infolength-14);
        $_ == $TITLE_SIGNAL   and $FIELDHEADINGS{diskinfo} = '  nr signal   ' . ' ' x ($infolength-14);
        $_ == $TITLE_YCOMMAND and $FIELDHEADINGS{diskinfo} = 'your commands ' . ' ' x ($infolength-14);
        $_ == $TITLE_ESCAPE   and $FIELDHEADINGS{diskinfo} = 'esc legend    ' . ' ' x ($infolength-14);
    }
#    $FIELDHEADINGS{display} = $FIELDHEADINGS{name} . ' (' . $sort_mode . ('%','')[$white_mode] . ('.','')[$dot_mode] . ')';
    $linecolor = $smode ? $framecolors{$color_mode}{swap}
                        : $framecolors{$color_mode}{title};
    $scr->bold()        if ($linecolor =~ /bold/);
    $scr->reverse()     if ($linecolor =~ /reverse/);
#    $scr->underline()   if ($linecolor =~ /under(line|score)/);
    $scr->term()->Tputs('us', 1, *STDOUT)
                        if ($linecolor =~ /under(line|score)/);
    $scr->at(2,0)
        ->putcolored($linecolor, formatted($currentformatlinewithinfo, @FIELDHEADINGS{@fields}))
        ->reset()->normal();
}

sub header {
    # do not take multiple mode into account at all
    my $mode = $_[0];
    if      ($mode & $HEADER_SORT) {
        return 'Sort by: Name, Extension, Size, Date, Type, Inode (ignorecase, reverse):';
    } elsif ($mode & $HEADER_MORE) {
        return 'Config-pfm Edit-new make-Fifo sHell Kill-chld Make-dir Show-dir Write-hist ESC';
    } elsif ($mode & $HEADER_INCLUDE) {
        return 'Include? Every, Oldmarks, After, Before, User or Files only:';
    } elsif ($mode & $HEADER_LNKTYPE) {
        return 'Absolute, Relative symlink or Hard link:';
    } else {
        return 'Attribute Copy Delete Edit Find tarGet Include Link More Name'
        .     ' cOmmands Print Quit Rename Show Time User unWhiteout'
        .     ' eXclude Your-commands siZe';
    }
}

sub init_header { # <special header mode>
    my $mode    = $_[0] || ($multiple_mode * $HEADER_MULTI);
    my $domulti = $mode & $HEADER_MULTI;
    my ($pos, $header, $headerlength, $vscreenwidth);
    $vscreenwidth = $screenwidth - 9 * $domulti;
    $header       = fitbanner(header($mode), $vscreenwidth);
    $headerlength = length($header);
    if ($headerlength < $vscreenwidth) {
        $header .= ' ' x ($vscreenwidth - $headerlength);
    }
    $scr->at(0,0);
    if ($domulti) {
        $scr->putcolored($framecolors{$color_mode}{multi}, 'Multiple');
    }
    $scr->color($framecolors{$color_mode}{header})->puts(' ' x $domulti)->puts($header)->bold();
    while ($header =~ /[[:upper:]<>](?!nclude\?)/g) {
        $pos = pos($header) -1;
        $scr->at(0, $pos + 9 * $domulti)->puts(substr($header, $pos, 1));
    }
    $scr->reset()->normal();
    return $headerlength;
}

sub footer {
    return "F1-Help F2-Back F3-Redraw F4-Color[$color_mode]"
    .     " F5-Reread F6-Sort[$sort_mode] F7-Swap[$ONOFF{$swap_mode}]"
    .     " F8-Include F9-Columns[$currentlayout]" # $formatname ?
    .     " F10-Multiple[$ONOFF{$multiple_mode}] F11-Restat F12-Mouse[$ONOFF{$mouse_mode}]"
    .     " !-Clobber[$ONOFF{$clobber_mode}]"
    .     " .-Dotfiles[$ONOFF{$dot_mode}]"
    .     ($white_cmd ? " %-Whiteouts[$ONOFF{$white_mode}]" : '')
    .     " \"-Pathnames[$path_mode]"
    .     " *-Radix[$radix_mode]"
#    .     " =-Ident"
    ;
}

sub init_footer {
    my $footer = fitbanner(footer(), $screenwidth);
    my $linecolor;
    $linecolor = $framecolors{$color_mode}{footer};
    $scr->bold()        if ($linecolor =~ /bold/);
    $scr->reverse()     if ($linecolor =~ /reverse/);
#    $scr->underline()   if ($linecolor =~ /under(line|score)/);
    $scr->term()->Tputs('us', 1, *STDOUT)
                        if ($linecolor =~ /under(line|score)/);
    $scr->at($BASELINE+$screenheight+1,0)
        ->putcolored($linecolor, $footer, ' ' x ($screenwidth - length $footer))
        ->reset()->normal();
}

sub usage {
    my $directory = Term::ScreenColor::colored('underline', 'directory');
    print "Usage: pfm [ $directory ] [ -s, --swap $directory ]\n",
          "       pfm { -h, --help | -v, --version }\n\n",
          "    $directory            : specify starting directory\n",
          "    -h, --help           : print this help and exit\n",
          "    -s, --swap $directory : specify swap directory\n",
          "    -v, --version        : print version information and exit\n",
          "\nConfiguration options will be read from \$PFMRC ", $ENV{PFMRC} ? "($ENV{PFMRC})" : "or $CONFIGDIRNAME/$CONFIGFILENAME", "\n";
}

sub printversion {
    print "pfm $VERSION\n";
}

sub copyright {
    # lookalike to DOS version :)
    return
    $scr->at(0,0)->clreol()->cyan() # %dircolors has not been set yet
                 ->puts("PFM $VERSION for Unix and Unix-like OS's.")
        ->at(1,0)->puts("Copyright (c) 1999-$LASTYEAR Rene Uittenbogaard")
        ->at(2,0)->puts("This software comes with no warranty: see the file COPYING for details.")
                 ->reset()->normal()->key_pressed($_[0]);
}

sub goodbye {
    my $bye = 'Goodbye from your Personal File Manager!';
    mouseenable($MOUSE_OFF);
    stty_raw($TERM_COOKED);
    if ($clsonexit) {
        $scr->clrscr();
    } else {
        $scr->at(0,0)->puts(' ' x (($screenwidth-length $bye)/2) . $bye)
            ->clreol()->at($PATHLINE,0);
    }
    write_cwd();
    write_history() if $autowritehistory;
    unless ($clsonexit) {
        $scr->at($screenheight+$BASELINE+1,0)->clreol();
    }
    system qw(tput cnorm) if $cursorveryvisible;
    # END {} block is also executed, although not necessary at normal exit.
}

sub credits {
    $scr->clrscr();
    stty_raw($TERM_COOKED);
    my $pfm = $scr->colored('bold', 'pfm');
    print <<"_eoCredits_";


             $pfm for Unix and Unix-like OS's.  Version $VERSION
             Original idea/design: Paul R. Culley and Henk de Heer
             Author and Copyright (c) 1999-$LASTYEAR Rene Uittenbogaard


       $pfm is distributed under the GNU General Public License version 2.
                    $pfm is distributed without any warranty,
             even without the implied warranties of merchantability
                      or fitness for a particular purpose.
                   Please read the file COPYING for details.

      You are encouraged to copy and share this program with other users.
   Any bug, comment or suggestion is welcome in order to update this product.

    New versions may be obtained from http://sourceforge.net/projects/p-f-m/

                For questions, remarks or suggestions about $pfm,
                 send email to: ruittenb\@users.sourceforge.net


                                                         any key to exit to $pfm
_eoCredits_
    stty_raw($TERM_RAW);
    $scr->getch();
}

##########################################################################
# system information

sub str_informatted {
    formatted('@' . '>' x ($infolength-1), @_);
}

sub data_informatted {
    formatted('@' . '>' x ($infolength-7) . ' @<<<<<', @_);
}

sub user_info {
    $scr->at($USERINFOLINE, $infocol)->putcolored(($> ? 'normal' : 'red'), str_informatted($ident));
}

sub disk_info { # %disk{ total, used, avail }
    my @desc      = ('K tot','K usd','K avl');
    my @values    = @disk{qw/total used avail/};
    my $startline = $DISKINFOLINE;
    # I played with vt100 boxes once,      lqqqqk
    # but I hated it.                      x    x
    # In case someone wants to try:        mqqqqj
#    $scr->at($startline-1,$infocol)->puts("\cNlqq\cO Disk space");
    $scr->at($startline-1, $infocol)->puts(str_informatted('Disk space'));
    foreach (0..2) {
        while ($values[$_] > 99_999) {
            $values[$_] /= 1024;
            $desc[$_] =~ tr/KMGTPEZ/MGTPEZY/;
        }
        $scr->at($startline+$_, $infocol)
            ->puts(data_informatted(int($values[$_]), $desc[$_]));
    }
}

sub dir_info {
    my @desc   = ('files','dirs ','symln','spec ');
    my @values = @total_nr_of{'-','d','l'};
    $values[3] = $total_nr_of{'c'} + $total_nr_of{'b'}
               + $total_nr_of{'p'} + $total_nr_of{'s'}
               + $total_nr_of{'D'} + $total_nr_of{'w'}
               + $total_nr_of{'n'};
    my $startline = $DIRINFOLINE;
    $scr->at($startline-1, $infocol)
        ->puts(str_informatted("Directory($sort_mode" . ($white_mode ? '' : '%') . ($dot_mode ? '' : '.') . ")"));
    foreach (0..3) {
        $scr->at($startline+$_, $infocol)
            ->puts(data_informatted($values[$_],$desc[$_]));
    }
}

sub mark_info {
    my @desc = ('bytes','files','dirs ','symln','spec ');
    my @values = @selected_nr_of{'bytes','-','d','l'};
    $values[4] = $selected_nr_of{'c'} + $selected_nr_of{'b'}
               + $selected_nr_of{'p'} + $selected_nr_of{'s'}
               + $selected_nr_of{'D'} + $selected_nr_of{'w'}
               + $selected_nr_of{'n'};
    my $startline = $MARKINFOLINE;
    my $total = 0;
    $values[0] = join ('', fit2limit($values[0], 9_999_999));
    $values[0] =~ s/ $//;
    $scr->at($startline-1, $infocol)->puts(str_informatted('Marked files'));
    foreach (0..4) {
        $scr->at($startline+$_, $infocol)
            ->puts(data_informatted($values[$_], $desc[$_]));
        $total += $values[$_] if $_;
    }
    return $total;
}

sub clock_info {
    my ($date, $time);
    my $line = $DATEINFOLINE;
    ($date, $time) = time2str(time, $TIME_CLOCK);
    if ($scr->rows() > 24) {
        $scr->at($line++, $infocol)->puts(str_informatted($date));
    }
    $scr->at($line++, $infocol)->puts(str_informatted($time));
}

##########################################################################
# sorting subs

sub as_requested {
    my ($exta, $extb);
    if ($dotdot_mode) {
        # Oleg Bartunov wanted to have . and .. unsorted (always at the top)
        if    ($a->{name} eq '.' ) { return -1 }
        elsif ($b->{name} eq '.' ) { return  1 }
        elsif ($a->{name} eq '..') { return -1 }
        elsif ($b->{name} eq '..') { return  1 }
    }
    SWITCH:
    for ($sort_mode) {
        /n/ and return    $a->{name}  cmp    $b->{name},    last SWITCH;
        /N/ and return    $b->{name}  cmp    $a->{name},    last SWITCH;
        /m/ and return lc($a->{name}) cmp lc($b->{name}),   last SWITCH;
        /M/ and return lc($b->{name}) cmp lc($a->{name}),   last SWITCH;
        /d/ and return    $a->{mtime} <=>    $b->{mtime},   last SWITCH;
        /D/ and return    $b->{mtime} <=>    $a->{mtime},   last SWITCH;
        /a/ and return    $a->{atime} <=>    $b->{atime},   last SWITCH;
        /A/ and return    $b->{atime} <=>    $a->{atime},   last SWITCH;
        /s/ and return    $a->{size}  <=>    $b->{size},    last SWITCH;
        /S/ and return    $b->{size}  <=>    $a->{size},    last SWITCH;
        /z/ and return    $a->{grand} <=>    $b->{grand},   last SWITCH;
        /Z/ and return    $b->{grand} <=>    $a->{grand},   last SWITCH;
        /i/ and return    $a->{inode} <=>    $b->{inode},   last SWITCH;
        /I/ and return    $b->{inode} <=>    $a->{inode},   last SWITCH;
        /t/ and return $a->{type}.$a->{name}
                                      cmp $b->{type}.$b->{name}, last SWITCH;
        /T/ and return $b->{type}.$b->{name}
                                      cmp $a->{type}.$a->{name}, last SWITCH;
        /[ef]/i and do {
             if ($a->{name} =~ /^(.*)(\.[^\.]+)$/) { $exta = $2."\0377".$1 }
                                             else { $exta = "\0377".$a->{name} }
             if ($b->{name} =~ /^(.*)(\.[^\.]+)$/) { $extb = $2."\0377".$1 }
                                             else { $extb = "\0377".$b->{name} }
             /e/ and return    $exta  cmp    $extb,        last SWITCH;
             /E/ and return    $extb  cmp    $exta,        last SWITCH;
             /f/ and return lc($exta) cmp lc($extb),       last SWITCH;
             /F/ and return lc($extb) cmp lc($exta),       last SWITCH;
        };
    }
}

sub by_name {
    return $a->{name} cmp $b->{name};
}

sub alphabetically {
    return uc($a) cmp uc($b) || $a cmp $b;
}

sub escape_middle {
    # the sorting of the backslash appears to be locale-dependant
    if ($a eq "$e$e" && $b =~ /\d/) {
        return 1;
    } elsif ($b eq "$e$e" && $a =~ /\d/) {
        return -1;
    } else {
        return $a cmp $b;
    }
}

##########################################################################
# user commands

sub handlequit { # key
    return $R_QUIT if isno($pfmrc{confirmquit});
    return $R_QUIT if $_[0] eq 'Q'; # quick quit
    return $R_QUIT if ($pfmrc{confirmquit} =~ /marked/i and !mark_info());
    $scr->at(0,0)->clreol();
    putmessage('Are you sure you want to quit [Y/N]? ');
    my $sure = $scr->getch();
    return +($sure =~ /y/i) ? $R_QUIT : $R_HEADER;
}

sub handlemultiple {
    toggle($multiple_mode);
    return $R_HEADER;
}

sub handlecolumns {
    $currentlayout++;
    makeformatlines();
    reformat();
    return $R_SCREEN;
}

sub handlerefresh {
    return ok_to_remove_marks() ? $R_DIRCONTENTS | $R_DIRSORT | $R_SCREEN
                                : $R_NOP;
}

sub handlecolor {
    my $index = $#colorsetnames;
    while ($color_mode ne $colorsetnames[$index] and $index > 0) {
        $index--;
    }
    if ($index-- <= 0) { $index = $#colorsetnames }
    $color_mode = $colorsetnames[$index];
    setornaments();
    return $R_SCREEN;
}

sub initident {
    chomp ($ident  = getpwuid($>)  ) unless $ident_mode == 1;
    chomp ($ident  = `hostname`    )     if $ident_mode == 1;
    chomp ($ident .= '@'.`hostname`)     if $ident_mode == 2;
    return $R_DISKINFO | $R_FOOTER;
}

sub handleident {
    triggle($ident_mode);
    goto &initident;
}

sub handleclobber {
    toggle($clobber_mode);
    return $R_FOOTER;
}

sub handlepathmode {
    $path_mode  = $path_mode eq 'phys' ? 'log' : 'phys';
    $currentdir = getcwd() if $path_mode eq 'phys';
    return $R_FOOTER | $R_PATHINFO;
}

sub handleradix {
    $radix_mode = $radix_mode eq 'hex' ? 'oct' : 'hex';
    return $R_FOOTER;
}

sub handlemouse {
    mouseenable(toggle $mouse_mode);
    return $R_FOOTER;
}

sub handleresize {
    $wasresized = 0;
    handlefit();
    validate_position();
    return $R_CLRSCR;
}

sub handlemousedown {
    my ($stashline, %stashfile, $mbutton, $mousecol, $mouserow, $on_name);
    my $do_a_refresh = $R_NOP;
    $scr->noecho();
    $mbutton  = ord($scr->getch()) - 040;
    $mousecol = ord($scr->getch()) - 041;
    $mouserow = ord($scr->getch()) - 041;
    $scr->echo();
    # button:  on pathline:  on title/footer:  on file:  on filename:
    # left     More - Show   ctrl-U/ctrl-D     F8        Show
    # middle   cOmmand       pgup/pgdn         Show      ENTER
    # right    cOmmand       pgup/pgdn         Show      ENTER
    if ($mouserow == $PATHLINE) {
        $do_a_refresh |= $mbutton ? handlecommand('o') : handlemoreshow();
    } elsif ($mouserow < $BASELINE) {
        $do_a_refresh |= $mbutton ? handlemove('pgup') : handlemove("\cU");
    } elsif ($mouserow > $screenheight + $BASELINE) {
        $do_a_refresh |= $mbutton ? handlemove('pgdn') : handlemove("\cD");
    } elsif ($mousecol >= $infocol or !defined $showncontents[$mouserow - $BASELINE + $baseindex]) {
    # return now if clicked on diskinfo or empty line
        return $do_a_refresh;
    } else {
    # clicked on an existing file
        $stashline   = $currentline;
        %stashfile   = %currentfile;
    # put cursor temporarily on another file
        $currentline = $mouserow - $BASELINE;
        %currentfile = %{$showncontents[$currentline+$baseindex]};
        $on_name = ($mousecol >= $filenamecol
                and $mousecol <= $filenamecol + $maxfilenamelength);
        if ($on_name and $mbutton) {
            $do_a_refresh |= handleenter();
        } elsif (!$on_name and !$mbutton) {
            $do_a_refresh |= handleselect();
        } else {
            $do_a_refresh |= handleshow();
        }
        # restore currentfile unless we did a chdir()
        unless ($do_a_refresh & $R_NEWDIR) {
            $currentline = $stashline;
            %currentfile = %stashfile;
        }
    }
    return $do_a_refresh;
}

sub handleadvance {
    my     $do_a_refresh = handleselect();
    return $do_a_refresh | handlemove(@_); # pass ' ' key on
}

sub handlesize {
    my ($recursivesize, $command, $tempfile, $do_this);
    my ($index, $loopfile);
    my $do_a_refresh = ($R_DIRFILTER | $R_DIRLIST | $R_HEADER | $R_PATHINFO | $R_DISKINFO) * $multiple_mode;
#    $do_a_refresh |= $R_DIRSORT * (lc $sort_mode eq 'z');
    markcurrentline('Z') unless $multiple_mode;
    $do_this = sub {
        $loopfile = shift;
        expand_escapes($QUOTE_ON, ($command = $ducmd), $loopfile);
        ($recursivesize = `$command 2>/dev/null`) =~ s/\D*(\d+).*/$1/;
        chomp $recursivesize;
        if ($?) {
            neat_error('Could not read all directories');
            $recursivesize ||= 0;
            $do_a_refresh |= $R_SCREEN;
        }
        @{$loopfile}{qw(grand grand_num grand_power)} =
            ($recursivesize, fit2limit($recursivesize, $maxgrandtotallength));
        if (join('', @layoutfields) =~ /grand/) {
            $do_a_refresh |= $multiple_mode * $R_DIRLIST;
        } elsif (!$multiple_mode) {
            # use filesize field
            $tempfile = { %$loopfile };
            @{$tempfile}{qw(size size_num size_power)} = ($recursivesize,
                fit2limit($recursivesize, $maxfilesizelength));
            $scr->at($currentline + $BASELINE, $filerecordcol)
                ->puts(fileline($tempfile, @layoutfields));
            markcurrentline('Z');
            applycolor($currentline + $BASELINE, $FILENAME_SHORT,
                       %currentfile);
            $scr->getch();
        }
        return $loopfile;
    };
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                exclude($loopfile, '.');
                $loopfile = $do_this->($loopfile);
                $dircontents[$index] = $loopfile;
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        %currentfile = %{ $do_this->(\%currentfile) };
        $showncontents[$currentline+$baseindex] = { %currentfile };
        copyback($currentfile{name});
    }
    return $do_a_refresh;
}

sub handlewhiteout {
    toggle($white_mode);
    $position_at = $currentfile{name};
    return $R_DIRLIST | $R_DIRFILTER | $R_DISKINFO | $R_FOOTER;
}

sub handledot {
    toggle($dot_mode);
    $position_at = $currentfile{name};
    return $R_DIRLIST | $R_DIRFILTER | $R_DISKINFO | $R_FOOTER;
}

sub handlecdold {
    if (ok_to_remove_marks()) {
        mychdir($oldcurrentdir);
        return $R_CHDIR;
    } else {
        return $R_HEADER;
    }
}

sub handlepan {
    my $width = $screenwidth - 9 * $multiple_mode;
    my $count   = max(maxpan(header(0), $width), maxpan(footer(), $width));
#    # add 2 for safety, because header and footer are of unequal length
#    my $count   = 2 + maxpan(header());
    $currentpan = $currentpan - ($_[0] =~ /</ and $currentpan > 0)
                              + ($_[0] =~ />/ and $currentpan < $count);
    return $R_HEADER | $R_FOOTER;
}

sub handlefind {
    my $findme;
    my $prompt = 'File to find: ';
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    ($findme = readintohist(\@path_history, $prompt)) =~ s/\/$//;
    if ($findme =~ /\//) { $findme = basename($findme) };
    stty_raw($TERM_RAW);
    return $R_HEADER if $findme eq '';
    FINDENTRY:
    foreach (sort by_name @showncontents) {
        last FINDENTRY if $findme le ($position_at = $_->{name});
#        if (index($_->{name}, $findme) == 0) {
#            $position_at = $_->{name};
#            last FINDENTRY;
#        }
    }
    return $R_DIRLIST | $R_HEADER;
}

sub handlefit {
    $scr->resize();
    my $newheight = $scr->rows();
    my $newwidth  = $scr->cols();
    if ($newheight || $newwidth) {
#        $ENV{ROWS}    = $newheight;
#        $ENV{COLUMNS} = $newwidth;
        $screenheight = $newheight - $BASELINE - 2;
        $screenwidth  = $newwidth;
    }
    makeformatlines();
    reformat();
    return $R_CLRSCR;
}

sub handleperlcommand {
    my $perlcmd;
    $scr->at(0,0)->clreol()->putcolored($framecolors{$color_mode}{message}, 'Enter Perl command:')
        ->at($PATHLINE,0)->clreol();
    stty_raw($TERM_COOKED);
    $perlcmd = readintohist(\@perlcmd_history);
    stty_raw($TERM_RAW);
    eval $perlcmd;
    display_error($@) if $@;
    return $R_SCREEN;
}

sub handlemoreshow {
    my ($newname, $do_a_refresh);
    my $prompt = 'Directory Pathname: ';
    return $R_HEADER unless ok_to_remove_marks();
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    $newname = readintohist(\@path_history, $prompt);
    stty_raw($TERM_RAW);
    return $R_HEADER if $newname eq '';
    $position_at = '.';
    expand_escapes($QUOTE_OFF, $newname, \%currentfile);
    if (mychdir($newname)) {
        $do_a_refresh |= $R_CHDIR;
    } else {
        display_error("$newname: $!");
        $do_a_refresh |= $R_SCREEN;
    }
    return $do_a_refresh;
}

sub handlemoremake {
    my ($newname, $do_a_refresh);
    my $prompt  = 'New Directory Pathname: ';
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    $newname = readintohist(\@path_history, $prompt);
    expand_escapes($QUOTE_OFF, $newname, \%currentfile);
    stty_raw($TERM_RAW);
    return $R_HEADER if $newname eq '';
#    if (!mkdir $newname, 0777) {
    if (system "mkdir -p \Q$newname\E") {
        display_error('Make dir failed');
        $do_a_refresh |= $R_SCREEN;
    } elsif (!ok_to_remove_marks()) {
        $do_a_refresh |= $R_HEADER; # $R_SCREEN ?
    } elsif (!mychdir($newname)) {
        display_error("$newname: $!"); # e.g. by restrictive umask
        $do_a_refresh |= $R_SCREEN;
    } else {
        $position_at = '.';
        $do_a_refresh |= $R_CHDIR;
    }
    return $do_a_refresh;
}

sub handlemoreconfig {
    my $do_a_refresh = $R_CLRSCR;
    my $olddotdot    = $dotdot_mode;
    $scr->at(0,0)->clreol();
    if (system $editor, whichconfigfile()) {
        $scr->at(1,0);
        display_error('Editor failed');
    } else {
        read_pfmrc($READ_AGAIN);
        if ($olddotdot != $dotdot_mode) {
            # allowed to switch dotdot mode (no key), but not sortmode (use F6)
            $position_at   = $currentfile{name};
            $do_a_refresh |= $R_DIRSORT;
        }
    }
    return $do_a_refresh;
}


sub handlemoreedit {
    my $newname;
    my $prompt  = 'New filename: ';
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    $newname = readintohist(\@path_history, $prompt);
    expand_escapes($QUOTE_OFF, $newname, \%currentfile);
    system "$editor \Q$newname\E" and display_error('Editor failed');
    stty_raw($TERM_RAW);
    return $R_CLRSCR;
}

sub handlemorefifo {
    my ($newname, $findindex);
    my $do_a_refresh = $R_SCREEN;
    my $prompt = 'New FIFO name: ';
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    $newname = readintohist(\@path_history, $prompt);
    expand_escapes($QUOTE_OFF, $newname, \%currentfile);
    system "mkfifo \Q$newname\E" and display_error('Make FIFO failed');
    # is newname present in @dircontents? push otherwise
    # (this part is nearly identical to the part in handlecopyrename())
    $findindex = 0;
    $findindex++ while ($findindex <= $#dircontents and
                    $newname ne $dircontents[$findindex]{name});
    if ($findindex > $#dircontents) {
        $do_a_refresh |= $R_DIRSORT;
    }
    $dircontents[$findindex] = stat_entry($newname, $dircontents[$findindex]{selected} || ' ');
    # upto here
    stty_raw($TERM_RAW);
    return $do_a_refresh;
}

sub handlemoreshell {
    $scr->clrscr();
    stty_raw($TERM_COOKED);
#    @ENV{qw(ROWS COLUMNS)} = ($screenheight + $BASELINE + 2, $screenwidth);
    system ($ENV{SHELL} ? $ENV{SHELL} : 'sh'); # most portable
    pressanykey(); # will also put the screen back in raw mode
    return $R_CLRSCR;
}

sub handlemorekill {
    my $printline = $BASELINE;
    my $prompt    = 'Signal to send to child processes: ';
    my $signal    = 'TERM';
    my $err;
    init_title($swap_mode, $TITLE_SIGNAL, @layoutfieldswithinfo);
    clearcolumn();
    foreach (1 .. min($#signame, $screenheight)+1) {
        $scr->at($printline++, $infocol)->puts(sprintf('  %2d %s', $_, $signame[$_]));
    }
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    $signal = $kbd->readline($prompt, $signal); # special case
    stty_raw($TERM_RAW);
    clearcolumn();
    return $R_HEADER | $R_TITLE | $R_DISKINFO if $signal eq '';
    if ($signal !~ /\D/) {
        $signal = $signame[$signal];
    }
    local $SIG{$signal} = 'IGNORE';
    # the "only portable" way from perlfunc(1) doesn't seem to work for me
#   kill -$signal, $$;
    eval { kill $signal, -$$ };
    if ($@) {
        $scr->at(0,0)->clreol();
        ($err = $@) =~ s/ at \S+ line \d+.\n//;
        display_error($err);
    }
    return $R_HEADER | $R_PATHINFO | $R_TITLE | $R_DISKINFO;
}

#sub handlemorephyspath {
#    init_header();
#    $scr->at(0,0)->clreol();
#    putmessage('Current physical path:');
#    $scr->at($PATHLINE, 0)->puts(pathline(getcwd(), $disk{'device'}));
#    $scr->getch();
#    return $R_PATHINFO | $R_HEADER;
#}

sub handlemore {
    local $_;
    my $do_a_refresh = $R_HEADER;
    my $headerlength = init_header($HEADER_MORE);
    $scr->noecho();
    my $key = $scr->at(0, $headerlength+1)->getch();
MOREKEY: for ($key) {
#        /^a$/i and $do_a_refresh |= handlemoreacl(),      last MOREKEY;
        /^s$/i and $do_a_refresh |= handlemoreshow(),     last MOREKEY;
        /^m$/i and $do_a_refresh |= handlemoremake(),     last MOREKEY;
        /^c$/i and $do_a_refresh |= handlemoreconfig(),   last MOREKEY;
        /^e$/i and $do_a_refresh |= handlemoreedit(),     last MOREKEY;
        /^h$/i and $do_a_refresh |= handlemoreshell(),    last MOREKEY;
        /^f$/i and $do_a_refresh |= handlemorefifo(),     last MOREKEY;
        /^w$/i and $do_a_refresh |= write_history(),      last MOREKEY;
#        /^p$/i and $do_a_refresh |= handlemorephyspath(), last MOREKEY;
# since when has pfm become a process manager?
        /^k$/i and $do_a_refresh |= handlemorekill(),     last MOREKEY;
    }
    return $do_a_refresh;
}

sub handleinclude { # include/exclude flag (from keypress)
    local $_;
    my $exin = shift;
    my $do_a_refresh = $R_HEADER | $R_PATHINFO;
    my ($criterion, $headerlength);
    our ($wildfilename, $boundarytime, $entry);
    # $wildfilename could have been declared using my(), but that will prevent
    # changes in its value to be noticed by the anonymous sub
    $headerlength = init_header($HEADER_INCLUDE);
    # modify header to say "exclude" when 'x' was pressed
    if ($exin =~ /x/i) {
        $scr->at(0,0)->putcolored($framecolors{$color_mode}{header}, 'Ex');
    }
    $exin =~ tr/ix/* /;
    my $key = lc($scr->at(0, $headerlength+1)->getch());
    if      ($key eq 'o') { # oldmarks
        $criterion = sub { $entry->{selected} eq '.' };
    } elsif ($key eq 'e') { # every
        $criterion = sub { $entry->{name} !~ /^\.\.?$/ };
    } elsif ($key eq 'u') { # user only
        $criterion = sub { $entry->{uid} =~ /$ENV{USER}/ };
    } elsif ($key =~ /^[ab]$/) { # after/before mtime
        if ($boundarytime = promptforboundarytime($key)) {
            # this was the behavior of PFM.COM, IIRC
            $wildfilename = promptforwildfilename();
            if ($key eq 'a') {
                $criterion = sub {
                                $entry->{name} =~ /$wildfilename/
                                and $entry->{mtime} > $boundarytime;
                            };
            } else {
                $criterion = sub {
                                $entry->{name} =~ /$wildfilename/
                                and $entry->{mtime} < $boundarytime;
                            };
            }
        } # if $boundarytime
    } elsif ($key eq 'f') { # regular files
        $wildfilename = promptforwildfilename();
        # it seems that ("a" =~ //) == false, that comes in handy
        $criterion    = sub {
                            $entry->{name} =~ /$wildfilename/
                            and $entry->{type} eq '-';
                        };
    }
    if ($criterion) {
        foreach $entry (@showncontents) {
            if ($criterion->()) {
                if ($entry->{selected} eq '*' && $exin eq ' ') {
                    exclude($entry);
                } elsif ($entry->{selected} eq '.' && $exin eq ' ') {
                    $entry->{selected} = $exin;
                } elsif ($entry->{selected} ne '*' && $exin eq '*') {
                    include($entry);
                }
                $do_a_refresh |= $R_SCREEN;
            }
        }
    }
    return $do_a_refresh;
}

sub handlename {
    markcurrentline(uc($_[0])); # disregard multiple_mode
    my $numformat = $NUMFORMATS{$radix_mode};
    my %otherfile = %currentfile;
    my $line;
    for ($otherfile{name}, $otherfile{target}) {
        s/\\/\\\\/;
        # don't ask how this works
        s{([${trspace}\177[:cntrl:]]|[^[:ascii:]])}
         {'\\' . sprintf($numformat, unpack('C', $1))}eg;
    }
    $line = $otherfile{name} . filetypeflag(\%otherfile) . (length($otherfile{target}) ? ' -> ' . $otherfile{target} : '');
    $scr->at($currentline+$BASELINE, $filenamecol)->putcolored($framecolors{$color_mode}{highlight}, $line, " \cH");
    applycolor($currentline+$BASELINE, $FILENAME_LONG, %otherfile); # resets colors to normal
    if ($scr->noecho()->getch() eq '*') {
        handleradix();
        init_footer();
        $scr->echo()->at($currentline+$BASELINE, $filenamecol)->puts(' ' x length $line);
        goto &handlename;
    }
    if ($filenamecol < $infocol && $filenamecol+length($line) >= $infocol or $filenamecol+length($line) >= $screenwidth) {
        return $R_CLRSCR;
    } else {
        return $R_STRIDE;
    }
}

sub handlesort {
    my $printline = $BASELINE;
    my %sortmodes = @SORTMODES;
    my ($i, $key, $headerlength);
    $headerlength = init_header($HEADER_SORT);
    init_title($swap_mode, $TITLE_SORT, @layoutfieldswithinfo);
    clearcolumn();
    # we can't use foreach (keys %SORTMODES) because we would lose ordering
    foreach (grep { ($i += 1) %= 2 } @SORTMODES) { # keep keys, skip values
        $scr->at($printline++, $infocol)->puts(sprintf('%1s %s', $_, $sortmodes{$_}));
    }
    $key = $scr->at(0, $headerlength+1)->getch();
    clearcolumn();
    if ($sortmodes{$key}) {
        $sort_mode   = $key;
        $position_at = $currentfile{name};
    }
    return $R_DIRSORT | $R_SCREEN;
}

sub handlekeyell {
    # small l only
    if ($currentfile{type} eq 'd') {
        # this automatically passes the 'l' key in $_[0] to handleentry()
        goto &handleentry;
    } else {
        goto &handlesymlink;
    }
}

sub handlesymlink {
    my ($newname, $loopfile, $do_this, $multi2single, $index, $newnameexpanded,
        $targetstring, $findindex, $testname, $headerlength, $absrel,
        $simpletarget, $simplename);
    my @lncmd = $clobber_mode ? qw(ln -f) : qw(ln);
    my $do_a_refresh = $multiple_mode ? $R_DIRLIST | $R_HEADER : $R_HEADER;
    markcurrentline('L') unless $multiple_mode;
    $headerlength = init_header($HEADER_LNKTYPE);
    $absrel = lc $scr->at(0, $headerlength+1)->getch();
    return $R_HEADER unless $absrel =~ /^[arh]$/;
    push @lncmd, '-s' if $absrel !~ /h/;
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    my $prompt = 'Name of new '.
        ( $absrel eq 'r' ? 'relative symbolic'
        : $absrel eq 'a' ? 'absolute symbolic' : 'hard') . ' link: ';
    push (@path_history, $currentfile{name}) unless $multiple_mode;
    $newname = readintohist(\@path_history, $prompt);
    if ($#path_history > 0 and $path_history[-1] eq $path_history[-2]) {
        pop @path_history;
    }
    stty_raw($TERM_RAW);
    return $R_HEADER if $newname eq '';
    $newname = canonicalize_path($newname);
    # expand \[3456] at this point as a test, but not \[127]
    expand_3456_escapes($QUOTE_OFF, ($testname = $newname), \%currentfile);
    # assignment on purpose, executed before evaluation of return value
    return $R_HEADER | $multi2single if $multi2single = multi_to_single($testname);
    $do_this = sub {
        if (-d $newnameexpanded) {
            # make sure $newname is a file (not a directory)
            $newnameexpanded .= '/'.$loopfile->{name};
        }
        if ($absrel eq 'r') {
            if ($newnameexpanded =~ m!^/!) {
                # absolute: first eliminate identical pathname prefix
                ($simpletarget, $simplename) = reducepaths($currentdir.'/'.$loopfile->{name}, $newnameexpanded);
                # now make absolute path relative
                $simpletarget =~ s!^/!!;
                $simpletarget =~ s![^/]+!..!g;
                $simpletarget = dirname($simpletarget);
                # and reverse it
                $targetstring = reversepath($currentdir.'/'.$loopfile->{name}, $simpletarget.'/'.$simplename);
            } else {
                # relative: reverse path
                $targetstring = reversepath($currentdir.'/'.$loopfile->{name}, $newnameexpanded);
            }
        } else { # $absrel eq 'a'
            # hand over an absolute path
            $targetstring = $currentdir.'/'.$loopfile->{name};
        }
        if (system @lncmd, $targetstring, $newnameexpanded) {
            $do_a_refresh |= neat_error('Linking failed');
        } elsif ($newnameexpanded !~ m!/!) {
            # is newname present in @dircontents? push otherwise
            $findindex = 0;
            $findindex++ while ($findindex <= $#dircontents and
                           $newnameexpanded ne $dircontents[$findindex]{name});
            if ($findindex > $#dircontents) {
                $do_a_refresh |= $R_DIRSORT | $R_DIRFILTER | $R_DIRLIST;
            }
            $dircontents[$findindex] = stat_entry($newnameexpanded,
                $dircontents[$findindex]{selected} || ' ');
        }
    };
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            expand_escapes($QUOTE_OFF,($newnameexpanded = $newname),$loopfile);
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                exclude($loopfile,'.');
                $do_this->();
                $dircontents[$index] =
                    stat_entry($loopfile->{name}, $loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        expand_escapes($QUOTE_OFF, ($newnameexpanded = $newname), $loopfile);
        $do_this->();
        restat_copyback();
    }
    return $do_a_refresh;
}

sub handleunwo {
    my ($index, $loopfile, $do_this);
    my $count = 0;
    my $do_a_refresh = $multiple_mode ? $R_DIRLIST | $R_HEADER : $R_HEADER;
    my $nowhiteouterror = 'Current file is not a whiteout';
    markcurrentline('W') unless $multiple_mode;
    if ($currentfile{type} ne 'w' and !$multiple_mode) {
        $scr->at(0,0)->clreol();
        display_error($nowhiteouterror);
        return $R_HEADER;
    }
    $scr->at($PATHLINE,0);
    $do_this = sub {
        if ($loopfile->{type} eq 'w') {
            if (!system(@unwo_cmd, $loopfile->{name})) {
                $total_nr_of{$loopfile->{type}}--;
                exclude($loopfile) if $loopfile->{selected} eq '*';
            } else {
                $do_a_refresh |= neat_error('Whiteout removal failed');
            }
        } else {
            $do_a_refresh |= neat_error($nowhiteouterror);
        }
    };
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                exclude($loopfile, '.');
                $do_this->();
                $dircontents[$index] = stat_entry($loopfile->{name}, $loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        $do_this->();
        restat_copyback();
    }
    return $do_a_refresh;
}

sub handletarget {
    my ($newtarget, $newtargetexpanded, $oldtargetok, $loopfile, $do_this, $index);
    my $do_a_refresh = $multiple_mode ? $R_DIRLIST | $R_HEADER : $R_HEADER;
    my $nosymlinkerror = 'Current file is not a symbolic link';
    markcurrentline('G') unless $multiple_mode;
    if ($currentfile{type} ne 'l' and !$multiple_mode) {
        $scr->at(0,0)->clreol();
        display_error($nosymlinkerror);
        return $R_HEADER;
    }
    my $prompt = 'New symlink target: ';
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    push (@path_history, $currentfile{target}) unless $multiple_mode;
    chomp($newtarget = readintohist(\@path_history, $prompt));
    if ($#path_history > 0 and $path_history[-1] eq $path_history[-2]) {
        pop @path_history;
    }
    stty_raw($TERM_RAW);
    return $R_HEADER if ($newtarget eq '');
    $do_this = sub {
        if ($loopfile->{type} ne "l") {
            $scr->at(0,0)->clreol();
            display_error($nosymlinkerror);
        } else {
            $oldtargetok = 1;
            if (-d $loopfile->{name}) {
                # if it points to a dir, the symlink must be removed first
                # next line is an intentional assignment
                unless ($oldtargetok = unlink $loopfile->{name}) {
                    $do_a_refresh |= neat_error($!);
                }
            }
            if ($oldtargetok and
                system qw(ln -sf), $newtargetexpanded, $loopfile->{name})
            {
                $do_a_refresh |= neat_error('Symlinking failed');
            }
        }
    };
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                expand_escapes($QUOTE_OFF, ($newtargetexpanded = $newtarget), $loopfile);
                exclude($loopfile,'.');
                $do_this->();
                $dircontents[$index] = stat_entry($loopfile->{name}, $loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        expand_escapes($QUOTE_OFF,($newtargetexpanded = $newtarget),$loopfile);
        $do_this->();
        restat_copyback();
    }
    return $do_a_refresh;
}

sub handlechown {
    my ($newuid, $loopfile, $do_this, $index);
    my $prompt = 'New [user][:group] ';
    my $do_a_refresh = $multiple_mode ? $R_DIRLIST | $R_HEADER : $R_HEADER;
    markcurrentline('U') unless $multiple_mode;
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    chomp($newuid = readintohist(\@mode_history, $prompt));
    stty_raw($TERM_RAW);
    return $R_HEADER if ($newuid eq '');
    $do_this = sub {
        if (system ('chown', $newuid, $loopfile->{name})) {
            $do_a_refresh |= neat_error('Change owner failed');
        }
    };
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                exclude($loopfile, '.');
                $do_this->();
                $dircontents[$index] = stat_entry($loopfile->{name}, $loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        $do_this->();
        restat_copyback();
    }
    return $do_a_refresh;
}

sub handlechmod {
    my ($newmode, $loopfile, $do_this, $index);
    my $prompt = 'Permissions [ugoa][-=+][rwxslt] or octal: ';
    my $do_a_refresh = $multiple_mode
                     ? $R_DIRFILTER | $R_DIRLIST | $R_HEADER | $R_PATHINFO
                     : $R_HEADER;
    markcurrentline('A') unless $multiple_mode;
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    chomp($newmode = readintohist(\@mode_history, $prompt));
    stty_raw($TERM_RAW);
    return $R_HEADER if ($newmode eq '');
    if ($newmode =~ s/^\s*(\d+)\s*$/oct($1)/e) {
        $do_this = sub {
            unless (chmod $newmode, $loopfile->{name}) {
                $do_a_refresh |= neat_error($!);
            }
        };
    } else {
        $do_this = sub {
            if (system 'chmod', $newmode, $loopfile->{name}) {
                $do_a_refresh |= neat_error('Change mode failed');
            }
        };
    }
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                exclude($loopfile,'.');
                $do_this->();
                $dircontents[$index] =
                    stat_entry($loopfile->{name},$loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        $do_this->();
        restat_copyback();
    }
    return $do_a_refresh;
}

sub handlecommand { # Y or O
    local $_;
    my ($key, $command, $do_this, $printstr, $prompt, $loopfile, $index);
    my $printline = $BASELINE;
    markcurrentline(uc($_[0])) unless $multiple_mode;
    clearcolumn();
    if ($_[0] =~ /y/i) { # Your
        init_title($swap_mode, $TITLE_YCOMMAND, @layoutfieldswithinfo);
        foreach (sort alphabetically keys %pfmrc) {
            if (/^your\[[[:alpha:]]\]$/ && $printline <= $BASELINE+$screenheight) {
                $printstr = $pfmrc{$_};
                $printstr =~ s/\e/^[/g;
                $scr->at($printline++, $infocol)
                    ->puts(sprintf('%1s %s', substr($_,5,1), substr($printstr,0,$infolength-2)));
            }
        }
        $prompt = 'Enter one of the highlighted chars below: ';
        $key = $scr->at(0,0)->clreol()->putcolored($framecolors{$color_mode}{message}, $prompt)->getch();
        clearcolumn();
        # this line is supposed to contain an assignment
        return $R_DISKINFO | $R_FRAME unless $command = $pfmrc{"your[$key]"};
        stty_raw($TERM_COOKED);
    } else { # cOmmand
        init_title($swap_mode, $TITLE_ESCAPE, @layoutfieldswithinfo);
        foreach (sort escape_middle keys %CMDESCAPES, $e) {
            if ($printline <= $BASELINE+$screenheight) {
                $scr->at($printline++, $infocol)->puts(sprintf(' %1s%1s %s', $e, $_, $CMDESCAPES{$_} || "literal $e"));
            }
        }
        $prompt = "Enter Unix command ($e" . "[1-7] or $e" . "[epv] escapes see below):";
        $scr->at(0,0)->clreol()->putcolored($framecolors{$color_mode}{message}, $prompt)
            ->at($PATHLINE,0)->clreol();
        stty_raw($TERM_COOKED);
        $command = readintohist(\@command_history);
        clearcolumn();
    }
#    $command =~ s/^\s*$/$ENV{'SHELL'}/; # PFM.COM behavior (undesirable)
    unless ($command =~ /^\s*\n?$/) {
#        $command .= "\n";
        if ($multiple_mode) {
            $scr->clrscr()->at(0,0);
            for $index (0..$#dircontents) {
                $loopfile = $dircontents[$index];
                if ($loopfile->{selected} eq '*') {
                    exclude($loopfile,'.');
                    $do_this = $command;
                    expand_escapes($QUOTE_ON, $do_this, $loopfile);
                    $scr->puts($do_this . "\n");
                    system $do_this and display_error('External command failed');
                    $dircontents[$index] =
                        stat_entry($loopfile->{name},$loopfile->{selected});
                    if ($dircontents[$index]{nlink} == 0) {
                        $dircontents[$index]{display} .= $LOSTMSG;
                    }
                }
            }
            $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
        } else { # single-file mode
            $loopfile = \%currentfile;
            expand_escapes($QUOTE_ON, $command, \%currentfile);
            $scr->clrscr()->at(0,0)->puts($command . "\n");
            system $command and display_error('External command failed');
            restat_copyback();
        }
        pressanykey();
    }
    stty_raw($TERM_RAW);
    return $R_CLRSCR;
}

sub handledelete {
    my ($loopfile, $do_this, $index, $success, $msg, $oldpos, $sure, %nameindexmap);
    my $count = 0;
    markcurrentline('D') unless $multiple_mode;
    if ($multiple_mode or $currentfile{nlink}) {
        $scr->at(0,0)->clreol();
        putmessage('Are you sure you want to delete [Y/N]? ');
        $sure = $scr->getch();
        return $R_HEADER if $sure !~ /y/i;
    }
    $scr->at($PATHLINE,0);
    $do_this = sub {
        if ($loopfile->{name} eq '.') {
            # don't allow people to delete '.'; normally, this would be allowed
            # if it is empty, but if that leaves the parent directory empty,
            # then it can also be removed, which causes a fatal pfm error.
            $msg = 'Deleting current directory not allowed';
            $success = 0;
#        } elsif ($loopfile->{type} eq 'w') {
#            $success = !system(@unwo_cmd, $loopfile->{name});
        } elsif ($loopfile->{nlink} == 0 and $loopfile->{type} ne 'w') {
            # remove 'lost files' immediately, no confirmation needed
            $success = 1;
        } elsif ($loopfile->{type} eq 'd') {
            if (testdirempty($loopfile->{name})) {
                $success = rmdir $loopfile->{name};
            } else {
                $scr->at(0,0)->clreol();
                putmessage('Recursively delete a non-empty directory [Affirmative/Negative]? ');
                $sure = lc $scr->getch();
                $scr->at(0,0);
                if ($sure eq 'a') {
                    $success = !system('rm', '-rf', $loopfile->{name});
                } else {
                    $msg = 'Deletion cancelled. Directory not empty';
                    $success = 0;
                }
                $scr->clreol();
            }
        } else {
            $success = unlink $loopfile->{name};
        }
        if ($success) {
            $total_nr_of{$loopfile->{type}}--;
            exclude($loopfile) if $loopfile->{selected} eq '*';
        } else { # not success
            display_error($msg || $!);
        }
    };
    if ($multiple_mode) {
        $oldpos = $currentfile{name};
        # build nameindexmap on showncontents, not dircontents.
        # this is faster than doing a dirlookup() every iteration
        %nameindexmap = map { $_->{name}, $count++ } @showncontents;
        # we must delete in reverse order because the number of directory
        # entries will decrease by deleting. This invalidates the %nameindexmap
        # for entries with index > current index.
        for $index (reverse(0..$#dircontents)) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                $do_this->();
                if ($success) {
                    splice @dircontents, $index, 1;
                    splice @showncontents, $nameindexmap{$loopfile->{name}}, 1;
                }
            }
        }
        # %nameindexmap may be completely invalid at this point. use dirlookup()
        if (dirlookup($oldpos, @showncontents) > 0) {
            $position_at = $oldpos;
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        $do_this->();
        if ($success) {
            splice @dircontents, dirlookup($loopfile->{name}, @dircontents), 1;
            splice @showncontents, $currentline+$baseindex, 1;
        }
    }
    # this prevents the cursor from running out of @showncontents;
    # otherwise, the validate_position() call is pointless
    while ($position_at eq '' and $currentline+$baseindex > $#showncontents) {
        $currentline--;
    }
    validate_position();
    return $R_SCREEN;
}

sub handleprint {
    my ($loopfile, $do_this, $command, $index);
    markcurrentline('P') unless $multiple_mode;
    $scr->at(0,0)->clreol()->putcolored($framecolors{$color_mode}{message}, 'Enter print command: ')
        ->at($PATHLINE,0)->clreol();
    stty_raw($TERM_COOKED);
    # don't use readintohist : special case with command_history
#    $kbd->SetHistory(@command_history);
    set_term_history($kbd, @command_history);
    $command = $kbd->readline('',$printcmd);
    if ($command =~ /\S/
        and $command ne $printcmd
        and $command ne $command_history[$#command_history]
    ) {
        push (@command_history, $command);
        shift (@command_history) if ($#command_history > $MAXHISTSIZE);
    }
    stty_raw($TERM_RAW);
    return $R_FRAME | $R_DISKINFO if $command eq '';
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            $do_this = $command;
            expand_escapes($QUOTE_ON, $do_this, $loopfile);
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                exclude($loopfile, '.');
                system $do_this and display_error('Print command failed');
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        expand_escapes($QUOTE_ON, $command, \%currentfile);
        system $command and display_error('Print command failed');
    }
    return $R_SCREEN;
}

sub handleshow {
    goto &handleentry if (followmode(\%currentfile) =~ /^d/);
    my ($loopfile,$index);
    $scr->clrscr()->at(0,0);
    stty_raw($TERM_COOKED);
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->puts($loopfile->{name});
                exclude($loopfile,'.');
                system "$pager \Q$loopfile->{name}" and display_error('Pager failed');
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        system "$pager \Q$currentfile{name}" and display_error('Pager failed');
    }
    stty_raw($TERM_RAW);
    return $R_CLRSCR;
}

sub handlehelp {
    $scr->clrscr()->cooked();
    print map { substr($_, 8)."\n" } split("\n", <<'    _eoHelp_');
        --------------------------------------------------------------------------------
        a     Attrib         F1  help             up, down arrow  move one line         
        c     Copy           F2  prev dir         k, j            move one line         
        d DEL Delete         F3  redraw screen    -, +            move ten lines        
        e     Edit           F4  cycle colors     CTRL-E, CTRL-Y  scroll dir one line   
        f /   find           F5  reread dir       CTRL-U, CTRL-D  move half a page      
        g     tarGet         F6  sort dir         CTRL-B, CTRL-F  move a full page      
        i     Include        F7  swap mode        PgUp, PgDn      move a full page      
        L     symLink        F8  mark file        HOME, END       move to top, bottom   
        n     Name           F9  cycle layouts    SPACE           mark file & advance   
        o     cOmmand        F10 multiple mode    right arrow, l  enter dir             
        p     Print          F11 restat file      left arrow, h   leave dir             
        q     Quit           F12 toggle mouse     ENTER           enter dir, launch     
        Q     Quick quit    --------------------- ESC, BS         leave dir             
        r     Rename         mc  Config pfm      ---------------------------------------
        s     Show           me  Edit new file    =  ident           <  cmnds left      
        t     Time           mf  make FIFO        *  radix           >  cmnds right     
        u     Uid            mh  spawn sHell      !  clobber         "  paths log/phys  
        w     unWhiteout     mk  Kill children    @  perlcmd         ?  help            
        x     eXclude        mm  Make new dir     .  dotfiles                           
        y     Your command   ms  Show directory   %  whiteout                           
        z     siZe           mw  Write history                                          
        --------------------------------------------------------------------------------
    _eoHelp_
#    $scr->at(12,0)->putcolored('bold yellow', 'q     Quit')->at(23,0);
    $scr->puts("F1 or ? for more elaborate help, any other key for next screen ")->raw();
    if ($scr->getch() =~ /(k1|\?)/) {
        system qw(man pfm); # how unsubtle :-)
    }
    credits();
    return $R_CLRSCR;
}

sub handletime {
    my ($newtime, $loopfile, $do_this, $index, $do_a_refresh, @cmdopts);
    my $prompt = "Put date/time [[CC]YY]-MM-DD hh:mm[.ss]: ";
    $do_a_refresh = $multiple_mode ? $R_DIRLIST | $R_HEADER : $R_HEADER;
    markcurrentline('T') unless $multiple_mode;
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    $newtime = readintohist(\@time_history, $prompt, strftime ("%Y-%m-%d %H:%M.%S", localtime time));
    if ($#time_history > 0 and $time_history[-1] eq $time_history[-2]) {
        pop @time_history;
    }
    stty_raw($TERM_RAW);
    $newtime =~ tr/0-9.//cd;
    return $R_HEADER if ($newtime eq '');
    @cmdopts = ($newtime eq '.') ? () : ('-t', $newtime);
    $do_this = sub {
        if (system ('touch', @cmdopts, $loopfile->{name})) {
            $do_a_refresh |= neat_error('Touch failed');
        }
    };
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                exclude($loopfile,'.');
                $do_this->();
                $dircontents[$index] = stat_entry($loopfile->{name},$loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        $do_this->();
        restat_copyback();
    }
    return $do_a_refresh;
}

sub handleedit {
    my ($loopfile, $index);
    $scr->clrscr()->at(0,0);
    stty_raw($TERM_COOKED);
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->puts($loopfile->{name});
                exclude($loopfile, '.');
                system "$editor \Q$loopfile->{name}" and display_error('Editor failed');
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        system "$editor \Q$currentfile{name}" and display_error('Editor failed');
    }
    stty_raw($TERM_RAW);
    return $R_CLRSCR;
}

sub handlecopyrename {
    my $state    = uc $_[0];
    my @statecmd = (($state eq 'C' ? qw(cp -r)       : 'mv'), ($clobber_mode ? '-f' : '-i'));
    my $prompt   =   $state eq 'C' ? 'Destination: ' : 'New name: ';
    my ($loopfile, $index, $testname, $newname, $multi2single, $newnameexpanded,
        $do_this, $findindex, $sure);
    my $do_a_refresh = $R_HEADER;
    markcurrentline($state) unless $multiple_mode;
    $scr->at(0,0)->clreol();
    stty_raw($TERM_COOKED);
    push (@path_history, $currentfile{name}) unless $multiple_mode;
    $newname = readintohist(\@path_history, $prompt);
    if ($#path_history > 0 and $path_history[-1] eq $path_history[-2]) {
        pop @path_history;
    }
    stty_raw($TERM_RAW);
    return $R_HEADER if ($newname eq '');
    # expand \[3456] at this point as a test, but not \[127]
    expand_3456_escapes($QUOTE_OFF, ($testname = $newname), \%currentfile);
    # assignment on purpose, executed before evaluation of return value
    return $R_HEADER | $multi2single if $multi2single = multi_to_single($testname);
    $do_this = sub {
#        if ($state eq 'C' and $loopfile->{type} =~ /[ld]/ ) { # move this outsde of do_this
#            # AIX: cp -r follows symlink
#            # Linux: cp -r copies symlink
#            $scr->at(0,0)->clreol();
#            putmessage('Copy symlinks to symlinks [Copy/Follow]? ');
#            $sure = lc $scr->getch();
#            $scr->at(0,0);
#            if ($sure eq 'a') {
#            } else {
#                $msg = 'Skipping directory';
#            }
#            $scr->clreol();
#        } elsif
        if (system @statecmd, $loopfile->{name}, $newnameexpanded) {
            $do_a_refresh |= neat_error($state eq 'C' ? 'Copy failed' : 'Move failed');
        } elsif ($newnameexpanded !~ m!/!) {
            # is newname present in @dircontents? push otherwise
            $findindex = 0;
            $findindex++ while ($findindex <= $#dircontents and
                            $newnameexpanded ne $dircontents[$findindex]{name});
            if ($findindex > $#dircontents) {
                $do_a_refresh |= $R_DIRSORT;
            }
            $dircontents[$findindex] = stat_entry($newnameexpanded, $dircontents[$findindex]{selected} || ' ');
        }
    };
    stty_raw($TERM_COOKED) unless $clobber_mode;
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                exclude($loopfile, '.');
                expand_escapes($QUOTE_OFF, ($newnameexpanded = $newname), $loopfile);
                $do_this->();
                $dircontents[$index] = stat_entry($loopfile->{name},$loopfile->{selected});
                if ($dircontents[$index]{nlink} == 0) {
                    $dircontents[$index]{display} .= $LOSTMSG;
                }
                $do_a_refresh |= $R_SCREEN;
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        expand_escapes($QUOTE_OFF, ($newnameexpanded = $newname), $loopfile);
        $do_this->();
        restat_copyback();
        # if ! $clobber_mode, we might have gotten an 'Overwrite?' question
        $do_a_refresh |= $R_SCREEN unless $clobber_mode;
    }
    stty_raw($TERM_RAW) unless $clobber_mode;
    return $do_a_refresh;
}

sub handlerestat {
    # i have seen these commands somewhere before..
    my $currentfile = $dircontents[$currentline+$baseindex];
    restat_copyback();
    return $R_STRIDE;
}

sub handleselect {
    # we cannot use %currentfile because we don't want to modify a copy
    my $file          = $showncontents[$currentline+$baseindex];
    my $was_selected  = $file->{selected} =~ /\*/;
    $file->{selected} = substr('* ', $was_selected, 1);
    if ($was_selected) {
        $selected_nr_of{$file->{type}}--;
        $file->{type} =~ /-/ and $selected_nr_of{bytes} -= $file->{size};
    } else {
        $selected_nr_of{$file->{type}}++;
        $file->{type} =~ /-/ and $selected_nr_of{bytes} += $file->{size};
    }
    # we need %currentfile set, so highlightline() can show the 'selected' status
    %currentfile = %$file;
    copyback($file->{name});
    highlightline($HIGHLIGHT_OFF);
    return $R_DISKINFO;
}

sub validate_position {
    # requirement: $showncontents[$currentline+$baseindex] is defined
    my $do_a_refresh;
    if ($currentline < 0) {
        $baseindex    += $currentline;
        $baseindex     < 0 and $baseindex = 0;
        $currentline   = 0;
        $do_a_refresh |= $R_DIRLIST;
    }
    if ($currentline > $screenheight) {
        $baseindex    += $currentline - $screenheight;
        $currentline   = $screenheight;
        $do_a_refresh |= $R_DIRLIST;
    }
    if ($currentline + $baseindex > $#showncontents) {
        $currentline   = $#showncontents - $baseindex;
        $do_a_refresh |= $R_DIRLIST;
    }
    return $do_a_refresh;
}

sub handlescroll {
    local $_ = $_[0];
    return 0 if (/\cE/ && $baseindex == $#showncontents && $currentline == 0)
             or (/\cY/ && $baseindex == 0);
    my $displacement = -(/^\cY$/)
                       +(/^\cE$/);
    $baseindex   += $displacement;
    $currentline -= $displacement if $currentline-$displacement >= 0
                                 and $currentline-$displacement <= $screenheight;
#    validate_position();
    return $R_DIRLIST;
}

sub handlemove {
    local $_ = $_[0];
    my $displacement = -10*(/^-$/)  -(/^(?:ku|k)$/   )
                       +10*(/^\+$/) +(/^(?:kd|j| )$/)
                       +$screenheight*(/\cF|pgdn/)
                       -$screenheight*(/\cB|pgup/)
                       +int($screenheight*(/\cD/)/2)
                       -int($screenheight*(/\cU/)/2)
                       -($currentline    +$baseindex)              *(/^home$/)
                       +($#showncontents -$currentline -$baseindex)*(/^end$/ );
    $currentline += $displacement;
    return validate_position();
}

sub launchtype {
    my $do_this;
    if (exists $pfmrc{"launch[$_[0]]"}) {
        $do_this = $pfmrc{"launch[$_[0]]"};
        expand_escapes($QUOTE_ON, $do_this, \%currentfile);
        $scr->clrscr()->at(0,0)->puts("Launch type $_[0]\n$do_this\n");
        system $do_this and display_error('Launch failed');
        return 'type_launched';
    } else {
        display_error("No launch command defined for type $_[0]\n");
        return 'type_tried';
    }
}

sub launchbyxbit {
    my $pid;
    if (followmode(\%currentfile) =~ /[xsS]/) {
        $scr->clrscr()->at(0,0)->puts("Launch executable $currentfile{name}\n");
#        if ($waitlaunchexec) {
            system "./\Q$currentfile{name}" and display_error('Launch failed');
#        } else {
#            $SIG{CHLD} = sub {
#                wait;
#                unless (--$childprocs) {
#                    $SIG{CHLD} = 'DEFAULT';
#                }
#            };
#            if (!defined($pid = fork)) {
#                display_error("Unable to fork: $!");
#            } elsif (!$pid) {
#                # child
#                exec "./\Q$currentfile{name}";
#            } else {
#                # parent
#                $childprocs++;
#            }
#        }
        return 'xbit_launched';
    } else {
        return 0; # must return false to prevent "File type unknown" error
    }
}

sub launchbymagic {
    my $magic = `file \Q$currentfile{name}`;
    my ($re, $launched);
    MAGIC: foreach (grep /^magic\[/, keys %pfmrc) {
        ($re) = (/magic\[([^]]+)\]/);
        # this will produce errors for invalid REs
        if (eval "\$magic =~ /$re/") {
            $launched = launchtype($pfmrc{$_});
            last MAGIC;
        }
    }
    if ($launched) {
        return 'magic_launched';
    } else {
        return 'magic_tried';
    }
}

sub launchbyextension {
    my ($ext) = ( $currentfile{name} =~ /(\.[^\.]+?)$/ );
    my $launched;
    if (exists $pfmrc{"extension[*$ext]"}) {
        $launched = launchtype($pfmrc{"extension[*$ext]"});
    }
    if ($launched) {
        return 'ext_launched';
    } else {
        return 'ext_tried';
    }
}

sub handleenter {
    goto &handleentry if followmode(\%currentfile) =~ /^d/;
    my $launched;
    $scr->at(0,0)->clreol()->at(0,0);
    stty_raw($TERM_COOKED);
    LAUNCH: foreach (split /,/, $pfmrc{launchby}) {
        /magic/     and $launched = launchbymagic();
        /extension/ and $launched = launchbyextension();
        /xbit/      and $launched = launchbyxbit();
        last LAUNCH if $launched =~ /launched/;
    }
    if ($launched =~ /launched/) {
        $launched = $R_CLRSCR;
        pressanykey();
        restat_copyback();
    } elsif (defined $launched) {
        # we did try, but the file type was unknown
#        display_error('File type unknown');
#        $launched = $R_HEADER;
        system "$pager \Q$currentfile{name}" and display_error($!);
        $launched = $R_CLRSCR;
    } else {
        # 'launchby' contains no valid entries
        display_error(q"No valid 'launchby' option in config file");
        $launched = $R_HEADER;
    }
    stty_raw($TERM_RAW);
    return $launched;
}

sub swap_stash {
    return {
        path              =>   $currentdir,
        contents          => [ @dircontents ],
        position          =>   $currentfile{name},
        disk              => { %disk },
        selected          => { %selected_nr_of },
        totals            => { %total_nr_of },
        multiple_mode     =>   $multiple_mode,
        sort_mode         =>   $sort_mode,
        dot_mode          =>   $dot_mode,
        white_mode        =>   $white_mode,
        argvnull          =>   $0
    };
}

sub swap_fetch {
    my $state = shift;
    @dircontents    = @{$state->{contents}};
    $position_at    =   $state->{position};
    %disk           = %{$state->{disk}};
    %selected_nr_of = %{$state->{selected}};
    %total_nr_of    = %{$state->{totals}};
    $multiple_mode  =   $state->{multiple_mode};
    $sort_mode      =   $state->{sort_mode};
    $dot_mode       =   $state->{dot_mode};
    $white_mode     =   $state->{white_mode};
    $0              =   $state->{argvnull};
    return $state->{path};
}

sub handleswap {
    my $do_a_refresh = $R_TITLE | $R_HEADER;
    my $prompt       = 'Directory Pathname: ';
    my ($temp_state, $nextdir);
    if ($swap_state and !$swap_persistent) { # swap back if ok_to_remove_marks
        if (ok_to_remove_marks()) {
            $nextdir   = swap_fetch($swap_state);
            $swap_mode = $swap_state = 0;
            $do_a_refresh |= $R_SCREEN;
        } else { # not ok to remove marks
            $do_a_refresh |= $R_HEADER;
        }
    } elsif ($swap_state and $swap_persistent) { # swap persistent
        $temp_state = $swap_state;
        $swap_state = swap_stash();
        $nextdir    = swap_fetch($temp_state);
        toggle($swap_mode);
        $do_a_refresh |= $R_SCREEN;
    } else { # $swap_state = 0; ask and swap forward
        if (defined $swapstartdir) {
            $nextdir = $swapstartdir;
            undef $swapstartdir;
            $do_a_refresh |= $swap_persistent * $R_INIT_SWAP;
        } else {
            $scr->at(0,0)->clreol();
            stty_raw($TERM_COOKED);
            $nextdir = readintohist(\@path_history, $prompt);
            stty_raw($TERM_RAW);
            return $do_a_refresh if $nextdir eq '';
        }
        $swap_state    = swap_stash();
        $swap_mode     = 1;
        $sort_mode     = $pfmrc{defaultsortmode} || 'n';
        $multiple_mode = 0;
        # this was the old location of the if-block above
        # which has been moved up to enable returning sooner
        expand_escapes($QUOTE_OFF, $nextdir, \%currentfile);
        $position_at   = '.';
        $do_a_refresh |= $R_CHDIR;
    }
    if (!mychdir($nextdir)) {
        $scr->at($PATHLINE,0)->clreol();
        display_error("$nextdir: $!");
        $do_a_refresh |= $R_CHDIR; # dan maar de lucht in
    }
    return $do_a_refresh;
}

sub handleentry {
    my $key = shift;
    my ($tempptr, $nextdir, $success, $direction);
    if ( $key =~ /^kl|[h\e\cH]$/i ) {
        $nextdir   = '..';
        $direction = 'up';
    } else {
        $nextdir   = $currentfile{name};
        $direction = $nextdir eq '..' ? 'up' : 'down';
    }
    return $R_NOP if ($nextdir    eq '.');
    return $R_NOP if ($currentdir eq '/' && $direction eq 'up');
    return $R_NOP if ! ok_to_remove_marks();
    $success = mychdir($nextdir);
    if ($success && $direction =~ /up/ ) {
        $position_at   = basename($oldcurrentdir);
    } elsif ($success && $direction =~ /down/) {
        $position_at   = '..';
    }
    unless ($success) {
        $scr->at(0,0)->clreol();
        display_error($!);
        init_header();
    }
    return $success ? $R_CHDIR : $R_STRIDE;
}

##########################################################################
# directory browsing helper routines

sub stat_entry { # path_of_entry, selected_flag
    # the second argument is used to have the caller specify whether the
    # 'selected' field of the file info should be cleared (when reading
    # a new directory) or kept intact (when re-statting)
    my ($entry, $selected_flag) = @_;
    my ($ptr, $name_too_long, $target);
    my ($device, $inode, $mode, $nlink, $uid, $gid, $rdev, $size,
        $atime, $mtime, $ctime, $blksize, $blocks) = lstat $entry;
    $ptr = {
        name        => $entry,           device      => $device,
        uid         => find_uid($uid),  inode       => $inode,
        gid         => find_gid($gid),  nlink       => $nlink,
        mode        => mode2str($mode), rdev        => $rdev,
        selected    => $selected_flag,   grand_power => ' ',
        atime       => $atime,           size        => $size,
        mtime       => $mtime,           blocks      => $blocks,
        ctime       => $ctime,           blksize     => $blksize,
        atimestring => time2str($atime, $TIME_FILE),
        mtimestring => time2str($mtime, $TIME_FILE),
        ctimestring => time2str($ctime, $TIME_FILE),
    };
    @{$ptr}{qw(size_num size_power)} = fit2limit($size, $maxfilesizelength);
    $ptr->{type} = substr($ptr->{mode}, 0, 1);
    if ($ptr->{type} eq 'l') {
        $ptr->{target}  = readlink($ptr->{name});
        $ptr->{display} = $entry . $filetypeflags{'l'}
                        . ' -> ' . $ptr->{target};
    } elsif ($ptr->{type} eq '-' and $ptr->{mode} =~ /.[xst]/) {
        $ptr->{display} = $entry . $filetypeflags{'x'};
    } elsif ($ptr->{type} =~ /[bc]/) {
        $ptr->{size_num} = sprintf("%d", $rdev / $rdevtomajor) . $MAJORMINORSEPARATOR . ($rdev % $rdevtomajor);
        $ptr->{display} = $entry . $filetypeflags{$ptr->{type}};
    } else {
        $ptr->{display} = $entry . $filetypeflags{$ptr->{type}};
    }
    $ptr->{name_too_long} = length($ptr->{display}) > $maxfilenamelength-1
                            ? $NAMETOOLONGCHAR : ' ';
    $total_nr_of{ $ptr->{type} }++; # this is wrong! e.g. after cOmmand
    return $ptr;
}

sub filetypeflag {
    my $file = shift;
    if ($file->{type} eq '-' and $file->{mode} =~ /.[xst]/) {
        return $filetypeflags{'x'};
    } else {
        return $filetypeflags{$file->{type}};
    }
}

sub getdircontents { # (current)directory
    my (@contents, $entry);
    my @allentries = ();
    %usercache = %groupcache = ();
#    init_title($swap_mode, $TITLE_DISKINFO, @layoutfieldswithinfo);
    if (opendir CURRENT, "$_[0]") {
        @allentries = readdir CURRENT;
        closedir CURRENT;
        if ($white_cmd) {
            push @allentries, `$white_cmd $_[0]`;
        }
    } else {
        $scr->at(0,0)->clreol();
        display_error("Cannot read . : $!");
    }
    # next lines also correct for directories with no entries at all
    # (this is sometimes the case on NTFS filesystems: why?)
    if ($#allentries < 0) {
        @allentries = ('.', '..');
    }
#    local $SIG{INT} = sub { return @contents };
    if ($#allentries > $SLOWENTRIES) {
        # don't use display_error here because that would just cost more time
        $scr->at(0,0)->clreol()->putcolored($framecolors{$color_mode}{message}, 'Please Wait');
    }
    foreach $entry (@allentries) {
        # have the mark cleared on first stat with ' '
        push @contents, stat_entry($entry, ' ');
    }
    init_header();
    return @contents;
}

sub printdircontents { # @contents
    foreach my $i ($baseindex .. $baseindex+$screenheight) {
        unless ($i > $#_) {
            $scr->at($i+$BASELINE-$baseindex,$filerecordcol)
                ->puts(fileline($_[$i], @layoutfields));
            applycolor($i+$BASELINE-$baseindex, $FILENAME_SHORT, %{$_[$i]});
        } else {
            $scr->at($i+$BASELINE-$baseindex,$filerecordcol)
                ->puts(' 'x($screenwidth - $infolength));
        }
    }
}

sub filterdir {
    return grep { $dot_mode   || $_->{name} =~ /^(\.\.?|[^\.].*)$/
           and    $white_mode || $_->{type} ne 'w'
    } @_;
}

sub init_dircount {
    %selected_nr_of =
    %total_nr_of    = ( d=>0, l=>0, '-'=>0, c=>0, b=>0,
                        D=>0, p=>0, 's'=>0, n=>0, w=>0, bytes => 0);
}

sub countdircontents {
    init_dircount();
    foreach my $i (0..$#_) {
        $total_nr_of   {$_[$i]{type}}++;
        $selected_nr_of{$_[$i]{type}}++ if ($_[$i]{selected} eq '*');
    }
}

sub get_filesystem_info {
    my (@dflist, %tdisk);
    chop (@dflist = (`$DFCMD .`, ''));
    shift @dflist;
    $dflist[0] .= $dflist[1]; # in case filesystem info wraps onto next line
    @tdisk{qw/device total used avail/} = split (/\s+/, $dflist[0]);
    $tdisk{avail} = $tdisk{total} - $tdisk{used} if $tdisk{avail} =~ /%/;
    @tdisk{qw/mountpoint/} = $dflist[0] =~ /(\S*)$/;
    return %tdisk;
}

sub position_cursor {
    $currentline = 0;
    $baseindex   = 0 if $position_at eq '..'; # descending into this dir
    ANYENTRY: {
        for (0..$#showncontents) {
            if ($position_at eq $showncontents[$_]{name}) {
                $currentline = $_ - $baseindex;
                last ANYENTRY;
            }
        }
        $baseindex = 0;
    }
    $position_at = '';
    return validate_position(); # refresh flag
}

sub set_argv0 {
    # this may be helpful for sysadmins trying to unmount a filesystem
    $0 = 'pfm [on ' . ( $disk{device} eq 'none' ? $disk{mountpoint}
                                                : $disk{device} ) . ']';
}

sub recalc_ptr {
    $position_at = '.';
    return position_cursor(); # refresh flag
}

sub showdiskinfo {
    my $spaces = ' ' x $infolength;
    # gap is not filled in yet
    my $gap = ' ' x (max($infocol-length($currentformatline)-$filerecordcol,
                         $filerecordcol-$infolength));
    disk_info(%disk);
    $scr->at($DIRINFOLINE-2, $infocol)->puts($spaces);
    dir_info(%total_nr_of);
    $scr->at($MARKINFOLINE-2, $infocol)->puts($spaces);
    mark_info(%selected_nr_of);
    $scr->at($USERINFOLINE-1, $infocol)->puts($spaces);
    user_info();
    clock_info();
    foreach ($DATEINFOLINE+2 .. $BASELINE+$screenheight) {
        $scr->at($_, $infocol)->puts($spaces);
    }
}

##########################################################################
# directory browsing main routine
#
# this sub is the heart of pfm. it has the following structure:
#
# until quit {
#     refresh everything flagged for refreshing;
#     wait for keypress-, mousedown- or resize-event;
#     handle the request;
# }
#
# when a key command handling sub exits, browse() uses its return value
# to decide which elements should be redrawn on-screen, and what else
# should be refreshed.
# the following are valid return values:
#
# $R_NOP    (=0) : no action was required, wait for new key
# $R_STRIDE      : refresh %currentfile, validate cursor position (always done)
# $R_HEADER      : reprint the header
# $R_PATHINFO    : reprint the pathinfo
# $R_TITLE       : reprint the title
# $R_FOOTER      : reprint the footer
# $R_FRAME       : combination of R_HEADER, R_PATHINFO, R_TITLE and R_FOOTER
# $R_DISKINFO    : reprint the disk- and directory info column
# $R_DIRLIST     : redisplay directory listing
# $R_DIRFILTER   : decide which entries to display (init @showncontents)
# $R_SCREEN      : combination of R_DIRFILTER, R_DIRLIST, R_DISKINFO and R_FRAME
# $R_CLEAR       : clear the screen
# $R_CLRSCR      : combination of R_CLEAR and R_SCREEN
# $R_DIRSORT     : resort @dircontents
# $R_DIRCONTENTS : reread directory contents
# $R_NEWDIR      : re-init directory-specific vars
# $R_CHDIR       : combination of R_NEWDIR, R_DIRCONTENTS, R_DIRSORT, R_SCREEN
# $R_INIT_SWAP   : after reading the directory, we should be swapped immediately
# $R_QUIT        : exit from program

sub browse {
    my $wantrefresh = shift;
    my $key;
    STRIDE: until ($wantrefresh & $R_QUIT) {
#        system "echo '" . dumprefreshflags($wantrefresh) . "' > /dev/pts/3";
#        $wantrefresh |= handleresize() if $wasresized;
        if ($wantrefresh &   $R_NEWDIR) {
            $wantrefresh &= ~$R_NEWDIR;
            # it's dangerous to leave multiple_mode on when changing directories
            # 'autoexitmultiple' is only for leaving it on between commands
            $multiple_mode = 0;
            $currentdir    = getcwd() if $path_mode eq 'phys';
            %disk          = get_filesystem_info();
            set_argv0();
            # this test is nested so that it does not get executed every time
            if ($wantrefresh &   $R_INIT_SWAP) {
                $wantrefresh &= ~$R_INIT_SWAP;
                # if $swapstartdir is set, we will make a first pass through
                # this then{} construct: it reads the main dircontents
                # and calls handleswap(), which detects $swapstartdir and
                # swaps forward, and subsequently erases $swapstartdir.
                # if 'persistentswap' is on, R_INIT_SWAP will be set again,
                # which will take us on a second pass through this
                # then{} construct, and we will be swapped back.
                # the swapback does not set R_INIT_SWAP again.
                init_dircount();
                # first pass, read main dir.
                # second pass, read swap dir.
                @dircontents  = sort as_requested getdircontents($currentdir);
                %currentfile  = %{$dircontents[$currentline+$baseindex]};
                $wantrefresh |= handleswap();
                unless ($swap_mode) {
                    # on second pass, flag that the main dir
                    # does not need reading any more
                    $wantrefresh &= ~($R_DIRCONTENTS | $R_DIRSORT);
                }
                redo STRIDE;
            }
        }
        # draw frame as soon as possible: this looks better on slower terminals
        if ($wantrefresh &   $R_CLEAR) {
            $wantrefresh &= ~$R_CLEAR;
            $scr->clrscr();
        }
        if ($wantrefresh & $R_FRAME) {
            $wantrefresh &= ~($R_TITLE | $R_HEADER | $R_FOOTER);
            init_frame();
        }
        # now in order of severity
        if ($wantrefresh &   $R_DIRCONTENTS) {
            $wantrefresh &= ~$R_DIRCONTENTS;
            init_dircount();
            $position_at  = $showncontents[$currentline+$baseindex]{name} unless length($position_at);
            @dircontents  = getdircontents($currentdir);
        }
        if ($wantrefresh &   $R_DIRSORT) {
            $wantrefresh &= ~$R_DIRSORT;
            $position_at  = $showncontents[$currentline+$baseindex]{name} unless length($position_at);
            @dircontents  = sort as_requested @dircontents;
        }
        if ($wantrefresh &   $R_DIRFILTER) {
            $wantrefresh &= ~$R_DIRFILTER;
            @showncontents = filterdir(@dircontents);
        }
        if ($wantrefresh &   $R_STRIDE) {
            $wantrefresh &= ~$R_STRIDE;
            position_cursor() if $position_at ne '';
            recalc_ptr() unless defined $showncontents[$currentline+$baseindex];
            %currentfile = %{$showncontents[$currentline+$baseindex]};
        }
        if ($wantrefresh &   $R_DIRLIST) {
            $wantrefresh &= ~$R_DIRLIST;
            printdircontents(@showncontents);
        }
        if ($wantrefresh &   $R_DISKINFO) {
            $wantrefresh &= ~$R_DISKINFO;
            showdiskinfo();
        }
        if ($wantrefresh &   $R_HEADER) {
            $wantrefresh &= ~$R_HEADER;
            init_header();
        }
        if ($wantrefresh &   $R_PATHINFO) {
            $wantrefresh &= ~$R_PATHINFO;
            path_info();
        }
        if ($wantrefresh &   $R_TITLE) {
            $wantrefresh &= ~$R_TITLE;
            init_title($swap_mode, $TITLE_DISKINFO, @layoutfieldswithinfo);
        }
        if ($wantrefresh &   $R_FOOTER) {
            $wantrefresh &= ~$R_FOOTER;
            init_footer();
        }
        # normally, the current cursor position must be validated every pass
        $wantrefresh |= $R_STRIDE;
        # don't send mouse escapes to the terminal if not necessary
        highlightline($HIGHLIGHT_ON);
        mouseenable($MOUSE_ON) if $mouse_mode && $mouseturnoff;
        MAIN_WAIT_LOOP: until (length($scr->{IN}) || $wasresized || $scr->key_pressed(1)) {
            clock_info();
            $scr->at($currentline+$BASELINE, $cursorcol);
        }
        if ($wasresized) {
            $wantrefresh |= handleresize();
        # the next line contains an assignment on purpose
        } elsif (length($scr->{IN}) || $scr->key_pressed() and $key = $scr->getch()) {
            highlightline($HIGHLIGHT_OFF);
            mouseenable($MOUSE_OFF) if $mouseturnoff;
            KEY: for ($key) {
                # order is determined by (supposed) frequency of use
                /^(?:ku|kd|pgup|pgdn|[-+jk\cF\cB\cD\cU]|home|end)$/i
                              and $wantrefresh |= handlemove($_),      last KEY;
                /^(?:kr|kl|[h\e\cH])$/i
                              and $wantrefresh |= handleentry($_),     last KEY;
                /^[\cE\cY]$/  and $wantrefresh |= handlescroll($_),    last KEY;
                /^l$/         and $wantrefresh |= handlekeyell($_),    last KEY;
                /^ $/         and $wantrefresh |= handleadvance($_),   last KEY;
                /^k5$/        and $wantrefresh |= handlerefresh(),     last KEY;
                /^[cr]$/i     and $wantrefresh |= handlecopyrename($_),last KEY;
                /^[yo]$/i     and $wantrefresh |= handlecommand($_),   last KEY;
                /^e$/i        and $wantrefresh |= handleedit(),        last KEY;
                /^d(el)?$/i   and $wantrefresh |= handledelete(),      last KEY;
                /^[ix]$/i     and $wantrefresh |= handleinclude($_),   last KEY;
                /^\r$/i       and $wantrefresh |= handleenter(),       last KEY;
                /^s$/i        and $wantrefresh |= handleshow(),        last KEY;
                /^kmous$/     and $wantrefresh |= handlemousedown(),   last KEY;
                /^k7$/        and $wantrefresh |= handleswap(),        last KEY;
                /^k10$/       and $wantrefresh |= handlemultiple(),    last KEY;
                /^m$/i        and $wantrefresh |= handlemore(),        last KEY;
                /^p$/i        and $wantrefresh |= handleprint(),       last KEY;
                /^L$/         and $wantrefresh |= handlesymlink(),     last KEY;
                /^[nv]$/i     and $wantrefresh |= handlename($_),      last KEY;
                /^k8$/        and $wantrefresh |= handleselect(),      last KEY;
                /^k11$/       and $wantrefresh |= handlerestat(),      last KEY;
                /^[\/f]$/i    and $wantrefresh |= handlefind(),        last KEY;
                /^[<>]$/i     and $wantrefresh |= handlepan($_),       last KEY;
                /^k3|\cL|\cR/ and $wantrefresh |= handlefit(),         last KEY;
                /^t$/i        and $wantrefresh |= handletime(),        last KEY;
                /^a$/i        and $wantrefresh |= handlechmod(),       last KEY;
                /^q$/i        and $wantrefresh |= handlequit($_),      last KEY;
                /^k6$/        and $wantrefresh |= handlesort(),        last KEY;
                /^(?:k1|\?)$/ and $wantrefresh |= handlehelp(),        last KEY;
                /^k2$/        and $wantrefresh |= handlecdold(),       last KEY;
                /^\.$/        and $wantrefresh |= handledot(),         last KEY;
                /^k9$/        and $wantrefresh |= handlecolumns(),     last KEY;
                /^k4$/        and $wantrefresh |= handlecolor(),       last KEY;
                /^\@$/        and $wantrefresh |= handleperlcommand(), last KEY;
                /^u$/i        and $wantrefresh |= handlechown(),       last KEY;
                /^z$/i        and $wantrefresh |= handlesize(),        last KEY;
                /^g$/i        and $wantrefresh |= handletarget(),      last KEY;
                /^k12$/       and $wantrefresh |= handlemouse(),       last KEY;
                /^=$/         and $wantrefresh |= handleident(),       last KEY;
                /^\*$/        and $wantrefresh |= handleradix(),       last KEY;
                /^!$/         and $wantrefresh |= handleclobber(),     last KEY;
                /^"$/         and $wantrefresh |= handlepathmode(),    last KEY;
                /^w$/i        and $wantrefresh |= handleunwo(),        last KEY;
                /^%$/i        and $wantrefresh |= handlewhiteout(),    last KEY;
                # invalid keypress: cursor position needs no checking
                $wantrefresh &= ~$R_STRIDE;
            } # switch KEY
        } # if key_pressed
    } # until QUIT
}

##########################################################################
# main() is not of type void

globalinit();
browse($R_CHDIR | ($R_INIT_SWAP * defined $swapstartdir));
goodbye();
exit 0;

__DATA__
##########################################################################
## Configuration file for Personal File Manager
## Version x

## every option line in this file should have the form:
## [whitespace] option [whitespace]:[whitespace] value
## (whitespace is optional)
## the option itself may not contain whitespace or colons,
## except in a classifier enclosed in [] that immediately follows it.
## in other words: /^\s*([^:[\s]+(?:\[[^]]+\])?)\s*:\s*(.*)$/
## everything following a # is regarded as a comment.
## escape may be entered as a real escape, as \e or as ^[ (caret, bracket)
## lines may be continued on the next line by ending them in \

## binary options may have yes/no, true/false, on/off, or 0/1 values.
## some options can be set using environment variables.
## your environment settings override the options in this file.

##########################################################################
## general

## should we exit from multiple file mode after executing a command?
autoexitmultiple:yes

## write history files automatically upon exit
autowritehistory:no

## clock date/time format; see strftime(3).
## %x and %X provide properly localized time and date.
## the defaults are "%Y %b %d" and "%H:%M:%S"
## the diskinfo field (f) in the layouts below must be wide enough for this.
clockdateformat:%Y %b %d
clocktimeformat:%H:%M:%S
#clockdateformat:%x
#clocktimeformat:%X

## whether you want to have the screen cleared when pfm exits
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

## initial colorset to pick from the various colorsets defined below (cycle with F4)
defaultcolorset:dark

## show dot files initially? (hide them otherwise, toggle with . key)
defaultdotmode:yes

## initial ident mode (user, host, or user@host, cycle with = key)
defaultident:user

## initial layout to pick from the array 'columnlayouts' (see below) (cycle with F9)
defaultlayout:0

## initially turn on mouse support? (yes,no,xterm) (default: only in xterm) (toggle with F12)
defaultmousemode:xterm

## initially display logical or physical paths? (log,phys) (default: log) (toggle with ")
defaultpathmode:log

## initial radix that Name will use to display non-ascii chars with (hex,oct) (toggle with *)
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

## the character that pfm recognizes as special abbreviation character (default =)
## previous versions used \ (note that this leads to confusing results)
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
keydef[*]:kmous=\e[M:home=\e[1~:end=\e[4~:end=\e[F:\
kl=\eOD:kd=\eOB:ku=\eOA:kr=\eOC:k1=\eOP:k2=\eOQ:k3=\eOR:k4=\eOS:

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

##########################################################################
## colors

## you may define as many different colorsets as you like.
## use the notation 'framecolors[colorsetname]' and 'dircolors[colorsetname]'.
## the F4 key will cycle through these colorsets.
## the special setname 'off' is used for no coloring.

## 'framecolors' defines the colors for header, header in multiple mode,
## title, title in swap mode, footer, messages, and the highlighted file.
## for the frame to become colored, 'usecolor' must be set to 'yes' or 'force'.

framecolors[light]:\
header=white on blue:multi=reverse cyan on black:\
title=reverse cyan on black:swap=reverse black on cyan:\
footer=reverse blue on white:message=blue:highlight=bold:

framecolors[dark]:\
header=white on blue:multi=bold reverse cyan on white:\
title=bold reverse cyan on white:swap=black on cyan:\
footer=bold reverse blue on white:message=bold cyan:highlight=bold:

## these are a suggestion
#framecolors[dark]:\
#header=white on blue:multi=reverse cyan on black:\
#title=reverse cyan on black:swap=reverse yellow on black:\
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
*.htm=bold yellow:*.html=bold yellow:*.tar=bold red:*.tgz=bold red:\
*.arj=bold red:*.taz=bold red:*.lzh=bold red:*.zip=bold red:\
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
*.htm=black on yellow:*.html=black on yellow:*.tar=bold red:*.tgz=bold red:\
*.arj=bold red:*.taz=bold red:*.lzh=bold red:*.zip=bold red:\
*.z=bold red:*.Z=bold red:*.gz=bold red:*.bz2=bold red:*.deb=red:*.rpm=red:\
*.pkg=red:*.jpg=bold magenta:*.gif=bold magenta:*.bmp=bold magenta:\
*.xbm=bold magenta:*.xpm=bold magenta:*.png=bold magenta:\
*.mpg=bold white on blue:*.avi=bold white on blue:\
*.gl=bold white on blue:*.dl=bold white on blue:

## The special set 'framecolors[*]' will be used for every 'dircolors[x]'
## for which there is no corresponding 'framecolors[x]' (like ls_colors)

framecolors[*]:\
title=reverse:swap=reverse:footer=reverse:highlight=bold:

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
* nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnzzzzzzzz mmmmmmmmmmmmmmm ffffffffffffff:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsssssssss ffffffffffffff:\
pppppppppp  uuuuuuuu gggggggg sssssss* nnnnnnnnnnnnnnnnnnnnnnnnnn ffffffffffffff:\
pppppppppp  mmmmmmmmmmmmmmm  ssssssss* nnnnnnnnnnnnnnnnnnnnnnnnnn ffffffffffffff:\
ppppppppppllll uuuuuuuu ggggggggssssssss mmmmmmmmmmmmmmm *nnnnnnn ffffffffffffff:

##########################################################################
## your commands

## in the defined commands, you may use the following escapes.
## these must NOT be quoted any more!
##  =1 : current filename without extension
##  =2 : current filename entirely
##  =3 : current directory path
##  =4 : current mountpoint
##  =5 : swap directory path (F7)
##  =6 : current directory basename
##  =7 : current filename extension
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
your[G]:gimp =2
your[g]:gvim =2
your[i]:rpm -qpi =2
your[j]:mpg123 =2 &
your[k]:esdplay =2
your[l]:mv -i =2 "$(echo =2 | tr '[:upper:]' '[:lower:]')"
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
extension[*.3i]  : application/x-intercal
extension[*.i]   : application/x-intercal
extension[*.bf]  : application/x-befunge
extension[*.Z]   : application/x-compress
extension[*.arj] : application/x-arj
extension[*.au]  : audio/basic
extension[*.avi] : video/x-msvideo
extension[*.bat] : application/x-msdos-batch
extension[*.bin] : application/octet-stream
extension[*.bmp] : image/x-ms-bitmap
extension[*.bz2] : application/x-bzip2
extension[*.c]   : application/x-c
extension[*.cmd] : application/x-msdos-batch
extension[*.com] : application/x-executable
extension[*.css] : text/css
extension[*.deb] : application/x-deb
extension[*.doc] : application/x-ms-office
extension[*.dll] : application/octet-stream
extension[*.dvi] : application/x-dvi
extension[*.eps] : application/postscript
extension[*.exe] : application/x-executable
extension[*.gif] : image/gif
extension[*.gz]  : application/x-gzip
extension[*.htm] : text/html
extension[*.html]: text/html
extension[*.jar] : application/zip
extension[*.jpeg]: image/jpeg
extension[*.jpg] : image/jpeg
extension[*.lzh] : application/x-lha
extension[*.mid] : audio/midi
extension[*.midi]: audio/midi
extension[*.mov] : video/quicktime
extension[*.man] : application/x-groff-man
extension[*.mm]  : application/x-groff-mm
extension[*.mp2] : audio/mpeg
extension[*.mp3] : audio/mpeg
extension[*.mpeg]: video/mpeg
extension[*.mpg] : video/mpeg
extension[*.p]   : application/x-chem
extension[*.pas] : application/x-pascal
extension[*.pdb] : chemical/x-pdb
extension[*.pdf] : application/pdf
extension[*.ppt] : application/x-ms-office
extension[*.pl]  : application/x-perl
extension[*.pm]  : application/x-perl-module
extension[*.png] : image/png
extension[*.ps]  : application/postscript
extension[*.qt]  : video/quicktime
extension[*.ra]  : audio/x-realaudio
extension[*.ram] : audio/x-pn-realaudio
extension[*.rar] : application/x-rar
extension[*.rpm] : application/x-rpm
extension[*.tar] : application/x-tar
extension[*.taz] : application/x-tar-compress
extension[*.tgz] : application/x-tar-gzip
extension[*.tif] : image/tiff
extension[*.tiff]: image/tiff
extension[*.txt] : text/plain
extension[*.uue] : application/x-uuencoded
extension[*.wav] : audio/x-wav
extension[*.xbm] : image/x-xbitmap
extension[*.xpm] : image/x-xpixmap
extension[*.xwd] : image/x-xwindowdump
extension[*.xls] : application/x-ms-office
extension[*.ync] : application/x-yencoded
extension[*.z]   : application/x-compress
extension[*.zip] : application/zip

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

launch[application/x-intercal]    : ick =2
launch[application/x-befunge]     : mtfi =2
launch[application/x-chem]        : chem =2 | groff -pteR -man > =1.ps; gv =1.ps &
launch[application/octet-stream]  : =p =2
launch[application/pdf]           : acroread =2 &
launch[application/postscript]    : gv =2 &
launch[application/x-arj]         : unarj x =2
launch[application/x-bzip2]       : bunzip2 =2
launch[application/x-c]           : gcc -o =1 =2
launch[application/x-compress]    : uncompress =2
#launch[application/x-deb]         :
launch[application/x-dvi]         : xdvi =2 &
launch[application/x-executable]  : wine =2 &
launch[application/x-groff-man]	  : groff -pteR -man =2 > =1.ps; gv =1.ps &
launch[application/x-groff-mm]	  : groff -pteR -mm  =2 > =1.ps; gv =1.ps &
launch[application/x-gzip]        : gunzip =2
#launch[application/x-lha]         :
launch[application/x-msdos-batch] : =e =2
launch[application/x-ms-office]   : =e =2
launch[application/x-pascal]      : =e =2
launch[application/x-perl-module] : =e =2
launch[application/x-perl]        : =2
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
launch[application/x-yencoded]    : ydecode =2
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
launch[image/x-ms-bitmap]         : =v =2 &
launch[image/x-xbitmap]           : =v =2 &
launch[image/x-xpixmap]           : =v =2 &
launch[image/x-xwindowdump]       : =v =2 &
launch[text/css]                  : =e =2
launch[text/html]                 : lynx =2
launch[text/plain]                : =e =2
#launch[video/mpeg]                :
#launch[video/quicktime]           :
launch[video/x-msvideo]           : divxPlayer =2 &

## vi: set filetype=xdefaults: # fairly close
__END__

##########################################################################
# pod documentation

=pod

=head1 NAME

C<pfm> - Personal File Manager for Linux/Unix

=head1 SYNOPSIS

C<pfm [ >I<directory>C< ] [ -s, --swap >I<directory>C< ]>

C<pfm { -v, --version | -h, --help }>

=head1 DESCRIPTION

C<pfm> is a terminal-based file manager, based on PFMS<.>COM for MS-DOS.

All C<pfm> commands are accessible through one or two keystrokes, and a few
are accessible with the mouse. Most command keys are case-insensitive. C<pfm>
can operate in single-file mode or multiple-file mode. In single-file mode,
the command corresponding to the keystroke will be performed on the current
(highlighted) file only. In multiple-file mode, the command will apply to
a selection of files.

Note that throughout this manual page, I<file> can mean any type of file,
not just plain regular files. These will be referred to as I<regular files>.

=head1 OPTIONS

Most of C<pfm>'s configuration is read from a config file. The default
location for this file is F<$HOME/.pfm/.pfmrc>, but an alternative location
may be specified using the environment variable C<PFMRC>. If there is no
config file present at startup, one will be created. The file contains
many comments on the available options, and is therefore supposed to be
self-explanatory. C<pfm> will issue a warning if the config file version
is older than the version of C<pfm> you are running. In this case, please
let C<pfm> create a new default config file and compare the changes with
your own settings, so that you do not miss any new config options or
format changes. See also the B<C>onfig command under MORE COMMANDS below,
and DIAGNOSIS.

There are two commandline options that specify starting directories.
The C<CDPATH> environment variable is taken into account when C<pfm>
tries to find these directories.

=over

=item I<directory>

The directory that C<pfm> should initially use as its main directory. If
unspecified, the current directory is used.

=item -h, --help

Print usage information, then exit.

=item -s, --swap I<directory>

The directory that C<pfm> should initially use as swap directory. (See
also the B<F7> command below).

There would be no point in setting the swap directory and subsequently
returning to the main directory if 'persistentswap' is turned off in your
config file. Therefore, C<pfm> will swap back to the main directory I<only>
if 'persistentswap' is turned on.

=item -v, --version

Print current version, then exit.

=back

=head1 NAVIGATION

Navigation through directories is essentially done using the arrow keys
and the vi(1) cursor keys (B<hjkl>). The following additional navigation
keys are available:

Movement inside a directory:

=begin html

<table border=0 cellspacing=4 align=center width="80%">
<tr><td colspan=2><hr></td></tr>
<tr>
    <td width="30%"><i>up arrow</i>, <i>down arrow</i></td>
    <td>move the cursor by one line</td>
</tr>
<tr>
    <td><b>k</b>, <b>j</b></td>
    <td>move the cursor by one line</td>
</tr>
<tr>
    <td><b>-</b>, <b>+</b></td>
    <td>move the cursor by ten lines</td>
</tr>
<tr>
    <td><b>CTRL-E</b>, <b>CTRL-Y</b></td>
    <td>scroll the screen by one line</td>
</tr>
<tr>
    <td><b>CTRL-U</b>, <b>CTRL-D</b></td>
    <td>move the cursor by half a page</td>
</tr>
<tr>
    <td><b>CTRL-B</b>, <b>CTRL-F</b></td>
    <td>move the cursor by a full page</td>
</tr>
<tr>
    <td><b>PgUp</b>, <b>PgDn</b></td>
    <td>move the cursor by a full page</td>
</tr>
<tr>
    <td><b>HOME</b>, <b>END</b></td>
    <td>move the cursor to the top or bottom line</td>
</tr>
<!-- tr><td colspan=2><hr></td></tr -->
<tr>
    <td><b>SPACE</b></td>
    <td>mark the current file, then move the cursor one line down</td>
</tr>
</tr>
<tr><td colspan=2><hr></td></tr>
</table>

=end html

=begin roff

.in +4n
.TS
lw(20n) | lw(41n).
_
\fIup arrow\fP, \fIdown arrow\fP	move the cursor by one line
\fBk\fP, \fBj\fP	move the cursor by one line
\fB-\fP, \fB+\fP	move the cursor by ten lines
\fBCTRL-E\fP, \fBCTRL-Y\fP	scroll the screen by one line
\fBCTRL-U\fP, \fBCTRL-D\fP	move the cursor by half a page
\fBCTRL-B\fP, \fBCTRL-F\fP	move the cursor by a full page
\fBPgUp\fP, \fBPgDn\fP	move the cursor by a full page
\fBHOME\fP, \fBEND\fP	move the cursor to the top or bottom line
.\"_	_
\fBSPACE\fP	T{
mark the current file,
then move the cursor one line down
T}
_
.TE
.in

=end roff

Movement between directories:

=begin html

<table border=0 cellspacing=4 align=center width="80%">
<tr><td colspan=2><hr></td></tr>
<tr>
    <td width="30%"><i>right arrow</i>, <b>l</b></td>
    <td><i>chdir()</i> to a subdirectory</td>
</tr>
<tr>
    <td><i>left arrow</i>, <b>h</b></td>
    <td><i>chdir()</i> to the parent directory</td>
</tr>
<tr>
    <td><b>ENTER</b></td>
    <td><i>chdir()</i> to a subdirectory</td>
</tr>
<tr>
    <td><b>ESC</b>, <b>BS</b></td>
    <td><i>chdir()</i> to the parent directory</td>
</tr>
<tr><td colspan=2><hr></td></tr>
</table>

=end html

=begin roff

.in +4n
.TS
lw(20n) | lw(41n).
_
\fIright arrow\fP, \fBl\fP	\fIchdir()\fP to a subdirectory
\fIleft arrow\fP, \fBh\fP	\fIchdir()\fP to the parent directory
\fBENTER\fP	\fIchdir()\fP to a subdirectory
\fBESC\fP, \fBBS\fP	\fIchdir()\fP to the parent directory
_
.TE
.in

=end roff

Note 1: the B<l> and B<ENTER> keys function differently when the cursor
is on a non-directory file (see below under B<L>ink and LAUNCHING FILES
respectively).

Note 2: see below under BUGS on the functioning of B<ESC>.

=head1 COMMANDS

=over

=item B<Attrib>

Changes the mode of the file if you are the owner. The mode may be specified
either symbolically or numerically, see chmod(1) for more details.

Note 1: the mode on a symbolic link cannot be set. See chmod(1) for more
details.

Note 2: the name B<Attrib> for this command is a reminiscence of the DOS
version.

=item B<Copy>

Copy current file. You will be prompted for the destination filename.
Directories will be copied recursively with all underlying files.

In multiple-file mode, it is not allowed to specify a single non-directory
filename as a destination. Instead, the destination name must be a
directory or a name containing a B<=1>, B<=2> or B<=7> escape (see below
under cB<O>mmand).

If clobber mode is off (see below under the B<!> command), existing files
will not be overwritten unless the action is confirmed by the user.

=item B<Delete>

Delete a file or directory. You must confirm this command with B<Y>
to actually delete the file. If the current file is a directory which
contains files, and you want to delete it recursively, you must respond with
B<A>ffirmative to the additional prompt. Lost files (files on the screen
but not actually present on disk) can be deleted from the screen listing
without confirmation. Whiteouts cannot be deleted; use unB<W>hiteout for
this purpose.

=item B<Edit>

Edit a file with your external editor. You can specify an editor with the
environment variable VISUAL or EDITOR or with the 'editor' option
in the F<.pfmrc> file. Otherwise vi(1) is used.

=item B<Find>

Prompts for a filename, then positions the cursor on that file.

=item B<tarGet>

Allows you to change the target that a symbolic link points to. You must
have permission to remove the current symbolic link.

=item B<Include>

Allows you to mark a group of files which meet a certain criterion:

=over

=item B<A>fter / B<B>efore

files newer/older than a specified date and time

=item B<E>very file

all files, including dotfiles, except for the B<.> and B<..> entries

=item B<F>iles only

regular files of which the filenames match a specified regular expression
(not a glob pattern!)

=item B<O>ldmarks

files which were previously marked and are now denoted with
an I<oldmark> (B<.>).

=item B<U>ser

files owned by the current user

=back

Oldmarks may be used to perform more than one command on a group of files.

=item B<Link>

Prompts to create either:

=over

=item an B<A>bsolute symlink

This will create a symlink containing an absolute path to the target,
irrespective of whether you enter a relative or an absolute symlink name.

Example: when the cursor is on the file F</home/rene/incoming/.plan>,
and you request an absolute symlink to be made with either the name
F<../.plan> or F</home/rene/.plan>, the actual symlink will become:

    /home/rene/.plan -> /home/rene/incoming/.plan

=item a B<H>ard link

This will create an additional hard link to the current file with the
specified name, which must be on the same filesystem.

=item a B<R>elative symlink

This will create a symlink containing a relative path to the target,
irrespective of whether you enter a relative or an absolute symlink name.

Example: when the cursor is on the file F</home/rene/incoming/.plan>,
and you request a relative symlink to be made with either the name
F<../.plan> or F</home/rene/.plan>, the actual symlink will become:

    /home/rene/.plan -> incoming/.plan

=back

If a directory is specified, C<pfm> will follow the behavior of ln(1),
which is to create the new link inside that directory.

In multiple-file mode, it is not allowed to specify a single non-directory
filename as a new name. Instead, the new name must be a directory or a
name containing a B<=1>, B<=2> or B<=7> escape (see below under cB<O>mmand).

If clobber mode is off (see below under the B<!> command), existing files
will not be overwritten.

Note that if the current file is a directory, the B<l> key, being one of
the vi(1) cursor keys, will chdir() you into the directory. The capital B<L>
command will I<always> try to make a link.

=item B<More>

Presents you with a choice of operations not related to the current
files. Use this to configure C<pfm>, edit a new file, make a new directory,
show a different directory, kill all child processes, or write the history
files to disk. See below under MORE COMMANDS. Pressing B<ESC> will take
you back to the main menu.

=item B<Name>

Shows the complete long filename. For a symbolic link, this command
will also show the target of the symbolic link. This is useful in case
the terminal is not wide enough to display the entire name, or if the
name contains non-printable characters. Non-ASCII characters and control
characters will be displayed as their octal or hexadecimal equivalents like
the examples in the following table. Spaces will be converted as well, if
the 'translatespace' option is turned on in the F<.pfmrc> file.  When the
name is shown in its converted form, pressing B<*> will change the radix.
The 'defaultradix' option specifies the initial radix that will be used.

Examples:

=begin html

<table border=0 cellspacing=4 align=center width="50%">
<tr><td colspan=3><hr></td></tr>
<tr>
    <td rowspan=3>character</td>
    <td colspan=2>representation in radix</td>
</tr>
<tr>
    <td colspan=2><hr></td>
</tr>
<tr>
    <td>octal</td>
    <td>hexadecimal</td>
</tr>
<tr><td colspan=3><hr></td></tr>
<tr>
    <td>CTRL-A</td>
    <td>\001</td>
    <td>\0x01</td>
</tr>
<tr>
    <td>space</td>
    <td>\040</td>
    <td>\0x20</td>
</tr>
<tr>
    <td>c cedilla (<b>&ccedil;</b>)</td>
    <td>\347</td>
    <td>\0xe7</td>
</tr>
<tr>
    <td>backslash (<b>\</b>)</td>
    <td>\\</td>
    <td>\\</td>
</tr>
<tr><td colspan=3><hr></td></tr>
</table>

=end html

=begin roff

.in +4n
.TS
l  | c  s
l6 | l8 l.
_
character	representation in radix
_
\^	octal	hexadecimal\0
_
CTRL-A	\\001	\\0x01
space	\\040	\\0x20
c cedilla (\fB\(,c\fP)	\\347	\\0xe7
backslash (\fB\\\fP)	\\\\	\\\\\0
_
.TE
.in

=end roff

=item B<cOmmand>

Allows execution of a shell command. After the command completes, C<pfm>
will resume.

On the commandline, you may use several special abbreviations, which will
be replaced by C<pfm> with the current filename, directoryname etc. (see
below). These abbreviations start with an escape character. This escape
character is defined with the option 'escapechar' in your F<.pfmrc> file. The
default is B<=>. Previous versions of C<pfm> used B<\>, but this was deemed
too confusing because backslashes are parsed by the shell as well. This
manual page (and the default config file) will assume you are using B<=> as
'escapechar'.

The following abbreviations are available:

=over

=item B<=1>

the current filename without extension (see below)

=item B<=2>

the current filename, complete

=item B<=3>

the full current directory path

=item B<=4>

the mountpoint of the current filesystem

=item B<=5>

the full swap directory path (see B<F7> command)

=item B<=6>

the basename of the current directory

=item B<=7>

the extension of the current filename (see below)

=item B<==>

a single literal B<=>

=item B<=e>

the editor specified with the 'editor' option in the config file

=item B<=p>

the pager specified with the 'pager' option in the config file

=item B<=v>

the image viewer specified with the 'viewer' option in the config file

=back

The I<extension> of the filename is defined as follows:

If the filename does not contain a period at all, then the file has no
extension (B<=7> is empty) and its whole name is regarded as B<=1>.

If the filename does contain a period, the extension B<=7> is defined
as the final part of the filename, starting at the last period in the
name. The filename B<=1> is the part before the period.

In all cases, the concatenation of B<=1> and B<=7> is equal to B<=2>.

Examples:

=begin html

<table border=0 cellspacing=4 align=center width="50%">
<tr><td colspan=3><hr></td></tr>
<tr>
    <td><b>=2</b></td>
    <td><b>=1</b></td>
    <td><b>=7</b></td>
</tr>
<tr><td colspan=3><hr></td></tr>
<tr>
    <td>track01.wav</td>
    <td>track01</td>
    <td>.wav</td>
</tr>
<tr>
    <td>garden.jpg</td>
    <td>garden</td>
    <td>.jpg</td>
</tr>
<tr>
    <td>end.</td>
    <td>end</td>
    <td>.</td>
</tr>
<tr>
    <td>somename</td>
    <td>somename</td>
    <td><i>empty</i></td>
</tr>
<tr>
    <td>.profile</td>
    <td><i>empty</i></td>
    <td>.profile</td>
</tr>
<tr>
    <td>.profile.old</td>
    <td>.profile</td>
    <td>.old</td>
</tr>
<tr><td colspan=3><hr></td></tr>
</table>

=end html

=begin roff

.in +4n
.TS
lb | lb lb
l  | l  l  .
_
=2	=1	=7
_
track01.wav	track01	.wav
garden.jpg	garden	.jpg
end.	end	.
somename	somename	\fIempty\fP
\.profile	\fIempty\fP	.profile
\.profile.old	.profile	.old
_
.TE
.in -4n

=end roff

See also below under QUOTING RULES.

=item B<Print>

Will prompt for a print command (default C<lpr -P$PRINTER =2>, or C<lpr =2>
if C<PRINTER> is unset) and will run it. No formatting is done. You may
specify a print command with the 'printcmd' option in the F<.pfmrc> file.

=item B<Quit>

Exit C<pfm>. The option 'confirmquit' in the F<.pfmrc> file specifies
whether C<pfm> should ask for confirmation. Note that by pressing a capital
B<Q> (quick quit), you will I<never> be asked for confirmation.

=item B<Rename>

Change the name of the file and/or move it into another directory. You will
be prompted for the new filename. Depending on your Unix implementation,
a pathname on another filesystem may or may not be allowed.

In multiple-file mode, it is not allowed to specify a single non-directory
filename as a new name. Instead, the new name must be a directory or a
name containing a B<=1> or B<=2> escape (see above under cB<O>mmand).

If clobber mode is off (see below under the B<!> command), existing files
will not be overwritten unless the action is confirmed by the user.

=item B<Show>

Displays the contents of the current file or directory on screen.
You can choose which pager to use for file viewing with the environment
variable C<PAGER>, or with the 'pager' option in the F<.pfmrc> file.

=item B<Time>

Change mtime (modification date/time) of the file. The time may be entered
either with or without clarifying interpunction (e.g. 2008-12-04 08:42.12)
as the interpunction will be removed to obtain a format which touch(1)
can use. Enter B<.> to set the mtime to the current date and time.

=item B<Uid>

Change ownership of a file. Note that many Unix variants do not allow normal
(non-C<root>) users to change ownership. Symbolic links will be followed.

=item B<View>

(Deprecated.) Identical to B<N>ame.

=item B<unWhiteout>

(Only on platforms that support whiteout files). Provides the option
to remove the whiteout entry in the top layer of a translucent (tfs),
inheriting (ifs) or union (unionfs) filesystem, thereby restoring access
to the corresponding file in the lower layer.

=item B<eXclude>

Allows you to erase marks on a group of files which meet a certain
criterion. See B<I>nclude for details.

=item B<Your command>

Like cB<O>mmand (see above), except that it uses one-letter commands
(case-sensitive) that have been preconfigured in the F<.pfmrc> file.
B<Y>our commands may use B<=1>S< .. >B<=7> and B<=e>, B<=p> and B<=v>
escapes just as in cB<O>mmand, e.g.

    your[c]:tar cvf - =2 | gzip > =2.tar.gz
    your[t]:tar tvf =2 | =p

=item B<siZe>

For directories, reports the grand total (in bytes) of the directory
and its contents.

For other file types, reports the total number of bytes in allocated
data blocks. For regular files, this is often more than the reported
file size. For special files and I<fast symbolic links>, the number is 0,
as no data blocks are allocated for these file types.

If the screen layout (selected with B<F9>) contains a 'grand total' column,
that column will be used. Otherwise, the 'filesize' column will temporarily
be (ab)used. A 'grand total' column in the layout will never be filled in
when entering the directory.

Note: since du(1) commands are not portable, C<pfm> guesses how it can
calculate the size according to the Unix variant that it runs on. If C<pfm>
guesses this incorrectly, you might have to specify the C<du> command (or
C<du | awk> combination) applicable for your Unix version in the F<.pfmrc>
file. Examples are provided. Please notify the author if you know any
corrections that should be made.

=back

=head1 MORE COMMANDS

These commands are accessible through the main screen B<M>ore command.

=over

=item B<Config pfm>

This command will open the F<.pfmrc> config file with your preferred
editor. The file will be re-read by C<pfm> after you exit your editor.
Options that are only modifiable through the config file (like
'columnlayouts') will be reinitialized immediately, options that affect
settings modifiable by key commands (like 'defaultsortmode') will not.

=item B<Edit new file>

You will be prompted for the new filename, then your editor will
be spawned.

=item B<make Fifo>

Prompts for a name, then creates a FIFO file (named pipe) with that
name. See also fifo(4) and mkfifo(1).

=item B<sHell>

Spawns your default login shell. When you exit from it, C<pfm> will resume.

=item B<Kill children>

Lists available signals. After selection of a signal, sends this signal
to all child processes of C<pfm> (more accurately: all processes in the
same process group).

=item B<Make new directory>

Specify a new directory name and C<pfm> will create it for you. Furthermore,
if you don't have any files marked, your current directory will be set to
the newly created directory.

=item B<Show directory>

You will be asked for the directory you want to view. Note that this
command is different from B<F7> because this will not change your current
swap directory status.

=item B<Write history>

C<pfm> uses the readline library for keeping track of the Unix commands,
pathnames, regular expressions, modification times, and file modes
entered. The history is read from individual files in F<$HOME/.pfm/>
every time C<pfm> starts. The history is written only when this command
is given, or when C<pfm> exits and the 'autowritehistory' option is set
in F<.pfmrc>.

=back

=head1 MISCELLANEOUS and FUNCTION KEYS

=over

=item B<ENTER>

If the current file is a directory, C<pfm> will chdir() to that directory.
Otherwise, C<pfm> will attempt to I<launch> the file. See LAUNCHING
FILES below.

=item B<DEL>

Identical to the B<D>elete command (see above).

=item B<!>

Toggle clobber mode. This controls whether a file should be overwritten when
its name is reused in B<C>opy, B<L>ink or B<R>ename.

=item B<">

Toggle pathname handling. In B<physical> mode, the current directory path
will always be transformed to its canonical form (the simplest form, with
symbolic names resolved). In B<logical> mode, all symbolic link components
in the current directory path will be preserved.

=item B<%>

Toggle show/hide whiteout files.

=item B<*>

Toggle the radix used by the B<N>ame command.

=item B<.>

Toggle show/hide dot files.

=item B</>

Identical to B<F>ind (see above).

=item B<E<lt>>

Scroll the header and footer, in order to view all available commands.

=item B<=>

Switch between displaying the username, the hostname, or username@hostname.

=item B<E<gt>>

Scroll the header and footer, in order to view all available commands.

=item B<?>

Display help. Identical to B<F1>.

=item B<@>

Allows the user to enter a perl command to be executed in the context
of C<pfm>. Primarily used for debugging.

=item B<F1>

Display help, version number and license information.

=item B<F2>

chdir() back to the previous directory.

=item B<F3>

Fit the file list into the current window and refresh the display.

=item B<F4>

Change the current colorset. Multiple colorsets may be defined,
see the F<.pfmrc> file itself for details.

=item B<F5>

Current directory will be reread. Use this when the contents of the
directory have changed. This command will erase all marks.

=item B<F6>

Allows you to re-sort the directory listing. You will be presented
a number of sort modes.

=item B<F7>

Alternates the display between two directories. When switching for the first
time, you are prompted for a directory path to show. When you switch back by
pressing B<F7> again, the contents of the alternate directory are displayed
unchanged. Header text changes color when in swap screen. In shell commands,
the directory path from the alternate screen may be referred to as B<=5>.
If the 'persistentswap' option has been set in the config file, then
leaving the swap mode will store the main directory path as swap path again.

=item B<F8>

Toggles the mark (include flag) on an individual file.

=item B<F9>

Toggle the column layout. Layouts are defined in your F<.pfmrc>,
in the 'defaultlayout' and 'columnlayouts' options. See the config
file itself for information on changing the column layout.

Note that a 'grand total' column in the layout will only be filled when
the siB<Z>e command is issued, not when reading the directory contents.

=item B<F10>

Switch between single-file and multiple-file mode.

=item B<F11>

Refresh (using lstat(2)) the displayed file data for the current file.

=item B<F12>

Toggle mouse use. See below under MOUSE COMMANDS.

=back

=head1 LAUNCHING FILES

The B<ENTER> key, when used on a non-directory file, will attempt to launch
the file.

The command used for launching a file is determined by the file type. File
types are identified by a unique name, preferably MIME type names. Launch
commands for every file type may be defined using the config file
'launch[I<filetype>]' options.

Example:

    launch[image/gif]      :=v =2 &
    launch[application/pdf]:acroread =2 &

There are three methods for determining the file type. You may opt to
use one, two, or all three of these methods, thereby using the second and
third method as fallback.

The following methods are available:

=over

=item B<extension>

The filename extension will be translated to a file type using the
'extension[*.I<extension>]' options in the config file.

Example:

    extension[*.gif]:image/gif
    extension[*.pdf]:application/pdf

=item B<magic>

The file(1) command will be run on the current file. Its output will
be translated to a file type using the 'magic[I<regular expression>]'
options in the config file.

Example:

    magic[GIF image data]:image/gif
    magic[PDF document]  :application/pdf

=item B<xbit>

The executable bits in the file permissions will be checked (after
symbolic links have been followed). If the current file is executable,
C<pfm> will attempt to start the file as an executable command.

=back

To select which method or methods (I<extension>, I<magic>, and/or I<xbit>)
should be used for determining the file type, you should specify these
using the 'launchby' option (separated by commas if more than one).

Example:

    launchby:xbit,extension

If the file type cannot be determined, the current file will be displayed
using your pager.

The B<ENTER> key will always behave as if C<pfm> runs in single-file mode.
It will I<not> launch multiple files. Use B<Y>our or cB<O>mmand to launch
multiple files.

=head1 QUOTING RULES

C<pfm> adds an extra layer of parsing to filenames and shell commands. It
is important to take notice of the rules that C<pfm> uses.

=for considering In versions prior to 1.93.1, the default escape character was B<\>.

The following six types of input can be distinguished:

=over

=item B<a regular expression> (only the B<I>nclude and eB<X>clude commands)

The input is parsed as a regular expression.

=item B<a time> (e.g. the B<T>ime or B<I>nclude - B<B>efore commands)

Characters not in the set C<[0-9.]> are removed from the input.

=item B<a literal pattern> (only the B<F>ind command)

The input is taken literally.

=item B<not a filename or shell command> (e.g. in B<A>ttribute or B<U>id)

The input is taken literally.

=item B<a filename> (e.g. in B<C>opy or tarB<G>et).

First of all, tilde expansion is performed.

Next, any C<=[1-7evp]> character sequence is expanded to the corresponding
value.

At the same time, any C<=[^1-7evp]> character sequence is just replaced
with the character itself.

Finally, if the filename is to be processed by C<pfm>, it is taken literally;
if it is to be handed over to a shell, all metacharacters are replaced I<escaped>.

=item B<a shell command> (e.g. in cB<O>mmand or B<P>rint)

First of all, tilde expansion is performed.

Next, any C<=[1-7evp]> character sequence is expanded to the corresponding
value, I<with shell metacharacters escaped>.

At the same time, any C<=[^1-7evp]> character sequence is just replaced
with the character itself.

=back

In short:

=over

=item

C<pfm> always escapes shell metacharacters in expanded B<=2>
I<etc.> constructs.

=item

In filenames entered, shell metacharacters are taken literally.

=item

In shell commands entered, metacharacters that you want to be taken
literally must be escaped one extra time.

=back

Examples:

=begin older versions

<table border=0 cellspacing=4 align=center>
<tr><td colspan=3><hr></td></tr>
<tr>
    <td>char(s) wanted in filename&nbsp;&nbsp;&nbsp;</td>
    <td>char(s) to type in filename&nbsp;&nbsp;&nbsp;</td>
    <td>char(s) to type in shell command&nbsp;&nbsp;&nbsp;</td>
</tr>
<tr><td colspan=3><hr><td></tr>
<tr>
    <td><i>any non-metachar</i></td>
    <td><i>that char</i></td>
    <td><i>that char</i></td>
</tr>
<tr>
    <td>\</td>
    <td>\\</td>
    <td>\\\\</td>
</tr>
<tr>
    <td>&quot;</td>
    <td>&quot; <b>or</b> \&quot;</td>
    <td>\\&quot; <b>or</b> '&quot;'</td>
</tr>
<tr>
    <td><i>space</i></td>
    <td><i>space</i> <b>or</b> \<i>space</i></td>
    <td>\\<i>space</i>  <b>or</b> '<i>space</i>'</td>
</tr>
<tr>
    <td><i>filename</i></td>
    <td>\2</td>
    <td>\2</td>
</tr>
<tr>
    <td>\2</td>
    <td>\\2</td>
    <td>\\\\2 <b>or</b> '\\2'</td>
</tr>
<tr><td colspan=3><hr><td></tr>
</table>

=end older versions

=begin html

<table border=0 cellspacing=4 align=center>
<tr><td colspan=3><hr></td></tr>
<tr>
    <td>char(s) wanted in filename&nbsp;&nbsp;&nbsp;</td>
    <td>char(s) to type in filename&nbsp;&nbsp;&nbsp;</td>
    <td>char(s) to type in shell command&nbsp;&nbsp;&nbsp;</td>
</tr>
<tr><td colspan=3><hr><td></tr>
<tr>
    <td><i>any non-metachar</i></td>
    <td><i>that char</i></td>
    <td><i>that char</i></td>
</tr>
<tr>
    <td>\</td>
    <td>\</td>
    <td>\\ or '\'</td>
</tr>
<tr>
    <td>&quot;</td>
    <td>&quot;</td>
    <td>\&quot; <b>or</b> '&quot;'</td>
</tr>
<tr>
    <td>=</td>
    <td>==</td>
    <td>==</td>
</tr>
<tr>
    <td><i>space</i></td>
    <td><i>space</i></td>
    <td>\\<i>space</i>  <b>or</b> '<i>space</i>'</td>
</tr>
<tr>
    <td><i>filename</i></td>
    <td>=2</td>
    <td>=2</td>
</tr>
<tr>
    <td>\2</td>
    <td>\2</td>
    <td>\\2 <b>or</b> '\2'</td>
</tr>
<tr>
    <td>=2</td>
    <td>==2</td>
    <td>==2</td>
</tr>
<tr><td colspan=3><hr><td></tr>
</table>

=end html

=begin older versions

.in
.TS
l | l l.
_
T{
char(s) wanted in filename
T}	T{
char(s) to type in filename
T}	T{
char(s) to type in shell command
T}
_
.\" great. *roff wants even more backslashes. so much for clarity.
\fIany non-metachar\fP	\fIthat char\fP	\fIthat char\fP
\\	\\\\	\\\\\\\\ \fBor\fR '\\\\'
"	" \fBor\fP \\"	\\\\" \fBor\fR '"'
\fIspace\fP	\fIspace\fP \fBor\fP \\\fIspace\fP	\\\\\fIspace\fP \fBor\fR '\fIspace\fP'
\fIfilename\fP	\\2	\\2
\\2	\\\\2	\\\\\\\\2 \fBor\fR '\\\\2'
_
.TE
.in

=end older versions

=begin roff

.in
.TS
l | l l.
_
T{
char(s) wanted in filename
T}	T{
char(s) to type in filename
T}	T{
char(s) to type in shell command
T}
_
.\" great. *roff wants even more backslashes. so much for clarity.
\fIany non-metachar\fP	\fIthat char\fP	\fIthat char\fP
\\	\\	\\\\ \fBor\fR '\\'
"	"	\\" \fBor\fR '"'
\&=	==	==
\fIspace\fP	\fIspace\fP	\\\fIspace\fP \fBor\fR '\fIspace\fP'
\fIfilename\fP	=2	=2
\\2	\\2	\\\\2 \fBor\fR '\\2'
=2	==2	==2
_
.TE
.in

=end roff

=head1 MOUSE COMMANDS

When C<pfm> is run in an xterm or other terminal that supports the
use of a mouse, turning on mouse mode (either initially with the
'defaultmousemode' option in the F<.pfmrc> file, or while running using
the B<F12> key) will give mouse access to the following commands:

=begin html

<table border=0 cellspacing=4 align=center width="50%">
<tr><td colspan=6><hr></td></tr>
<tr>
    <td rowspan=3>button</td>
    <td colspan=5>location clicked</td>
</tr>
<tr><td colspan=5><hr></td></tr>
<tr>
    <td>pathline</td>
    <td>title</td>
    <td>header/footer</td>
    <td>file</td>
    <td>filename</td>
</tr>
<tr><td colspan=6><hr></td></tr>
<tr>
    <td>1</td>
    <td><b>M</b>ore - <b>S</b>how</td>
    <td>CTRL-U</td>
    <td>CTRL-D</td>
    <td>F8</td>
    <td><b>S</b>how</td>
</tr>
<tr>
    <td>2</td>
    <td>c<b>O</b>mmand</td>
    <td>PgUp</td>
    <td>PgDn</td>
    <td><b>S</b>how</td>
    <td>ENTER</td>
</tr>
<tr>
    <td>3</td>
    <td>c<b>O</b>mmand</td>
    <td>PgUp</td>
    <td>PgDn</td>
    <td><b>S</b>how</td>
    <td>ENTER</td>
</tr>
<tr><td colspan=6><hr><td></tr>
</table>

=end html

=begin roff

.in +4n
.TS
c | c s s s s
^ | l l l l l
c | l l l l l.
_
\0button	location clicked
_
\^	pathline	title/header	footer	file	filename\0
_
1	\fBM\fPore \- \fBS\fPhow	CTRL-U	CTRL-D	F8	\fBS\fPhow
2	c\fBO\fPmmand	PgUp	PgDn	\fBS\fPhow	ENTER
3	c\fBO\fPmmand	PgUp	PgDn	\fBS\fPhow	ENTER
_
.TE
.in

=end roff

The cursor will I<only> be moved when the title, header or footer is clicked,
or when changing directory.

Mouse use will be turned off during the execution of commands, unless
'mouseturnoff' is set to 'no' in F<.pfmrc>. Note that setting this to
'no' means that your (external) commands (like your pager and editor)
will receive escape codes when the mouse is clicked.

=head1 WORKING DIRECTORY INHERITANCE

Upon exit, C<pfm> will save its current working directory in the file
F<$HOME/.pfm/cwd>, and its swap directory, if any, in F<$HOME/.pfm/swd>.
This enables the user to have the calling process (shell) "inherit"
C<pfm>'s current working directory, and to reinstate the swap directory
upon the next invocation.  To achieve this, you may call C<pfm> using a
function or alias like the following:

Example for ksh(1), bash(1) and zsh(1):

    pfm() {
        if [ -s ~/.pfm/swd ]; then
            swd=-s"`cat ~/.pfm/swd`"
        fi
        # providing $swd is optional
        /usr/local/bin/pfm $swd "$@"
        if [ -s ~/.pfm/cwd ]; then
            cd "`cat ~/.pfm/cwd`"
            rm -f ~/.pfm/cwd
        fi
    }

Example for csh(1) and tcsh(1):

    alias pfm ':                                \
    if (-s ~/.pfm/swd) then                     \
        set swd=-s"`cat ~/.pfm/swd`"            \
    endif                                       \
    : providing $swd is optional                \
    /usr/local/bin/pfm $swd \!*                 \
    if (-s ~/.pfm/cwd) then                     \
        cd "`cat ~/.pfm/cwd`"                   \
        rm -f ~/.pfm/cwd                        \
    endif'

=head1 ENVIRONMENT

=over

=item B<ANSI_COLORS_DISABLED>

Detected as an indication that ANSI coloring escape sequences should not
be used.

=item B<CDPATH>

A colon-separated list of directories specifying the search path when
changing directories. There is always an implicit B<.> entry at the start
of this search path.

=item B<EDITOR>

The editor to be used for the B<E>dit command. Overridden by VISUAL.

=item B<LC_ALL>

=item B<LC_COLLATE>

=item B<LC_CTYPE>

=item B<LC_MESSAGES>

=for comment =item B<LC_MONETARY>

=item B<LC_NUMERIC>

=item B<LC_TIME>

=item B<LANG>

Determine locale settings, most notably for collation sequence, messages
and date/time format. See locale(7).

=item B<PAGER>

Identifies the pager with which to view text files. Defaults to less(1)
for Linux systems or more(1) for Unix systems.

=item B<PERL_RL>

Indicate whether and how the readline prompts should be highlighted.
See Term::ReadLine(3pm). If unset, a good guess is made based on your
config file 'framecolors[]' setting.

=item B<PFMRC>

Specify a location of an alternate F<.pfmrc> file. If unset, the default
location F<$HOME/.pfm/.pfmrc> is used. The cwd- and history-files cannot
be displaced in this manner, and will always be located in the directory
F<$HOME/.pfm/>.

=item B<PRINTER>

May be used to specify a printer to print to using the B<P>rint command.

=item B<SHELL>

Your default login shell, spawned by B<M>ore - sB<H>ell.

=item B<VISUAL>

The editor to be used for the B<E>dit command. Overrides EDITOR.

=back

=head1 FILES

The directory F<$HOME/.pfm/> and files therein. A number of input histories
and the current working directory on exit are saved to this directory.

The default location for the config file is F<$HOME/.pfm/.pfmrc>.

=head1 DIAGNOSIS

If C<pfm> reports that your config file might be outdated, you might be
missing some of the newer configuration options (or default values for
these). Try the following command and compare the new config file with
your original one:

    env PFMRC=~/.pfm/.pfmrc-new pfm

To prevent the warning from occurring again, update the '## Version' line.

=head1 BUGS and WARNINGS

When typed by itself, the B<ESC> key needs to be pressed twice. This is
due to the lack of a proper timeout in C<Term::Screen>.

C<Term::ReadLine::Gnu> does not allow a half-finished line to be aborted by
pressing B<ESC>. For most commands, you will need to clear the half-finished
line. You may use the terminal kill character (usually B<CTRL-U>) for this
(see stty(1)).

The author once almost pressed B<ENTER> when logged in as root and with
the cursor next to F</sbin/reboot>. You have been warned.

The smallest terminal size supported is 80x24. The display will be messed
up if you resize your terminal window to a smaller size.

C<pfm> uses up too much memory. But then again, everybody has tons of
memory nowadays.

=head1 VERSION

This manual pertains to C<pfm> version 1.93.6.

=head1 AUTHOR and COPYRIGHT

=for roff
.PP \" display the authors
.\" the \(co character only exists in groff
.ie \n(.g .ds co \(co
.el       .ds co (c)
.ie \n(.g .ds e' \('e
.el       .ds e' e\*'
..
Copyright \*(co 1999-2009, Ren\*(e' Uittenbogaard (ruittenb@users.sourceforge.net).
.PP \

=for html
Copyright &copy; 1999-2009, Ren&eacute; Uittenbogaard (ruittenb@users.sourceforge.net).

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the terms described by the GNU General Public
License version 2.

This program was based on PFMS<.>COM version 2.32, originally written for
MS-DOS by Paul R. Culley and Henk de Heer. The name 'pfm' was adopted
with kind permission of the original authors.

=head1 SEE ALSO

The documentation on PFMS<.>COM. The manual pages for chmod(1), file(1),
less(1), locale(7), lpr(1), touch(1), vi(1), Term::ScreenColor(3pm),
Term::ReadLine(3pm), and Term::Screen(3pm).

=cut

: vim:     set tabstop=4 shiftwidth=4 expandtab list:
: vim>600: set foldmethod=indent nofoldenable:

