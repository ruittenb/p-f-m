#!/usr/bin/env perl
#
##########################################################################
# @(#) pfm.pl 19990314-20021227 v1.82
#
# Name:         pfm.pl
# Version:      1.82
# Author:       Rene Uittenbogaard
# Date:         2002-12-27
# Usage:        pfm.pl [directory]
# Requires:     Term::ScreenColor
#               Term::Screen
#               Term::Cap
#               Term::ReadLine::Gnu
#               Term::ReadLine
#               POSIX
#               Config
#               Cwd
#               strict
#               vars
# Description:  Personal File Manager for Unix/Linux
#
# TODO: use quotemeta() for quoting? (problem: \ in filenames)
#       double quote support by using system(@) for all commands
#       double quote and space support in (Y)our and c(O)mmands
#       get rid of `` around 'du' in si(Z)e and 'df' in get_filesystem_info?
#
#       fix error handling in eval($do_this) and &display_error
#          partly implemented in handlecopyrename
#       make a sub fileforall(sub) ?
#
#       (M)ore - (E)dit should expand ~ and \5 ? make this more consistent
#       sub readintohistwithdefault() ?
#
#       implement cached_header and cached_footer ?
#       implement pfmrc version check?
#       implement include Before/After
#       make siZe command work in multiple mode
#       make color of pfm sysmessages customizable?
#       split dircolors in dircolorsdark and dircolorslight (switch with F4)
#           this also needs $headercolor etc in 2 modes
#
#       use the nameindexmap from handledelete() more globally?
#         in handlecopyrename()? in handlefind() in handlesymlink? in dirlookup?
#       use perl symlink()
#       what to do if du(1) says "permission denied" ?
#       implement 'logical' paths in addition to 'physical' paths?
#           unless (chdir()) { getcwd() } otherwise no getcwd() ?
#       use mkdir -p if m!/! (all unix platforms?)
#       implement default action for filetype? ENTER -> .jpg:xv \2 ?
#       set ROWS en COLUMNS in environment for child processes; but see if
#           this does not mess up with $scr->rows etc. which use these
#           variables internally; portability?
#       stat_entry() must *not* rebuild the selected_nr and total_nr lists:
#           this messes up with e.g. cOmmand -> cp \2 /somewhere/else
#           (which is, therefore, still buggy). this is closely related to:
#       sub countdircontents is not used
#       make commands in header and footer clickable buttons?
#       hierarchical sort? e.g. 'sen' (size,ext,name)
#       incremental search (search entry while entering filename)?
#       major/minor numbers on DU 4.0E are wrong (have they got readline?)

##########################################################################
# Main data structures:
#
# @dircontents   : array (current directory data) of references (to file data)
# $dircontents[$index]      : reference to hash (=file data)
# %{ $dircontents[$index] } : hash (=file data)
# $dircontents[$index]{name}
#                     {selected}
#                     {size}
#                     {type}
#
# %currentfile = %{ $dircontents[$currentfile+$baseindex] } (current file data)
# $currentfile{name}
#             {selected}
#             {size}
#             {type}

##########################################################################
# requirements

require 5.005; # for negative lookbehind in re

use Term::ScreenColor;
use Term::ReadLine;
use POSIX 'strftime';
use Config;
use Cwd;
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
    $TITLE_DISKINFO
    $TITLE_COMMAND
    $TITLE_SIGNAL
    $TITLE_SORT
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
    $R_CLS
    $R_DIRCONTENTS
    $R_NEWDIR
    $R_QUIT
);

BEGIN {
    $ENV{PERL_RL} = 'Gnu ornaments=1';
}

##########################################################################
# declarations and initialization

*FALSE          = \0;
*TRUE           = \1;
*READ_FIRST     = \0;
*READ_AGAIN     = \1;
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
*TITLE_DISKINFO = \0;
*TITLE_COMMAND  = \1;
*TITLE_SIGNAL   = \2;
*TITLE_SORT     = \3;
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
*R_CLS          = \512;
*R_DIRCONTENTS  = \1024;
*R_NEWDIR       = \2048;
*R_QUIT         = \1048576;

my $R_FRAME     = $R_HEADER | $R_PATHINFO | $R_TITLE | $R_FOOTER;
my $R_SCREEN    = $R_DIRFILTER | $R_DIRLIST | $R_DISKINFO | $R_FRAME;
my $R_CLEAR     = $R_CLS | $R_SCREEN;
my $R_CHDIR     = $R_NEWDIR | $R_DIRCONTENTS | $R_DIRSORT | $R_SCREEN
                | $R_STRIDE;

my $VERSION             = &getversion;
my $CONFIGDIRNAME       = "$ENV{HOME}/.pfm";
my $CONFIGFILENAME      = '.pfmrc';
my $LOSTMSG             = ''; # was '(file lost)';
my $CWDFILENAME         = 'cwd';
my $MAJORMINORSEPARATOR = ',';
my $NAMETOOLONGCHAR     = '+';
my $MAXHISTSIZE         = 40;
my $ERRORDELAY          = 1;    # seconds
my $SLOWENTRIES         = 300;
my $PATHLINE            = 1;
my $BASELINE            = 3;
my $USERLINE            = 21;
my $DATELINE            = 22;
my $DATECOL             = 14;
my $CONFIGFILEMODE      = 0777;
my $DFCMD               = ($^O eq 'hpux') ? 'bdf' : 'df -k';

my @SYMBOLIC_MODES = qw(--- --x -w- -wx r-- r-x rw- rwx);

my %ONOFF = ('' => 'off', 0 => 'off', 1 => 'on');

my %TIMEHINTS = (
    pfm   => '[[CC]YY]MMDDhhmm[.ss]',
    touch => 'MMDDhhmm[[CC]YY][.ss]'
);

my @SORTMODES = (
    n =>'Name',        N =>' reverse',
   'm'=>' ignorecase', M =>' rev+igncase',
    e =>'Extension',   E =>' reverse',
    f =>' ignorecase', F =>' rev+igncase',
    d =>'Date/mtime',  D =>' reverse',
    a =>'date/Atime',  A =>' reverse',
   's'=>'Size',        S =>' reverse',
    t =>'Type',        T =>' reverse',
    i =>'Inode',       I =>' reverse'
);

# AIX,BSD,Tru64: du gives blocks, du -k kbytes
# Solaris      : du gives kbytes
# HP           : du gives blocks,               du -b something unwanted
# Linux        : du gives blocks, du -k kbytes, du -b bytes
my %DUCMDS = (
    default => q(du -sk "\2" | awk '{ printf "%d", 1024 * $1 }'),
    solaris => q(du -s  "\2" | awk '{ printf "%d", 1024 * $1 }'),
    sunos   => q(du -s  "\2" | awk '{ printf "%d", 1024 * $1 }'),
    hpux    => q(du -s  "\2" | awk '{ printf "%d",  512 * $1 }'),
    linux   => q(du -sb "\2"),
#    aix     => can use the default
#    freebsd => can use the default
#    netbsd  => can use the default unless proven otherwise
#    dec_osf => can use the default unless proven otherwise
#    beos    => can use the default unless proven otherwise
#    irix    => can use the default unless proven otherwise
#    sco     => can use the default unless proven otherwise
    # MSWin32, macos, os390 etc. not supported
);

my $TITLEVIRTFILE = {
    selected      => '',
    name          => 'filename',
    display       => 'filename',
    name_too_long => '',
    size          => 'size',
    size_num      => 'size',
    size_power    => ' ',
    grand         => 'total',
    grand_num     => 'total',
    grand_power   => ' ',
    inode         => 'inode',
    mode          => ' perm',
    atime         => 'date/atime',
    mtime         => 'date/mtime',
    ctime         => 'date/ctime',
    atimestring   => 'date/atime',
    mtimestring   => 'date/mtime',
    ctimestring   => 'date/ctime',
    uid           => 'userid',
    gid           => 'groupid',
    nlink         => 'lnks',
    rdev          => 'dev'
};

my $screenheight    = 20;    # inner height
my $screenwidth     = 80;    # terminal width
my $position_at     = '.';   # start with cursor here

# some examples as defaults
my @command_history = ('du -ks *', 'man "\1"');
my @mode_history    = qw(755 644);
my @path_history    = ('/', $ENV{HOME});
my @regex_history   = qw(.*\.jpg);
my @time_history;
my @perlcmd_history;

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
    %user, %group, %pfmrc, @signame, %dircolors,
    # screen- and keyboard objects, screen parameters
    $scr, $kbd, $wasresized, $mouse_mode,
    # modes
    $sort_mode, $multiple_mode, $swap_mode, $dot_mode, $dotdot_mode,
    $currentpan,
    # dir- and disk info
    $currentdir, $oldcurrentdir, @dircontents, @showncontents, %currentfile,
    %disk, $swap_state, %total_nr_of, %selected_nr_of,
    # cursor position
    $currentline, $baseindex, $cursorcol, $filenamecol,
    # misc config options
    $editor, $pager, $printcmd, $ducmd, $showlockchar, $autoexitmultiple,
    $clobber, $cursorveryvisible, $clsonexit, $autowritehistory, $viewbase,
    $trspace, $swap_persistent, $timeformat, $timestampformat, $mouseturnoff,
    # layouts and formatting
    @columnlayouts, $currentlayout, @layoutfields, $currentformatline,
    $maxfilenamelength, $maxfilesizelength, $maxgrandtotallength,
    # coloring of screen
    $titlecolor, $footercolor, $headercolor, $swapcolor, $multicolor
);

##########################################################################
# read/write resource file and history file

sub whichconfigfile {
    return $ENV{PFMRC} ? $ENV{PFMRC} : "$CONFIGDIRNAME/$CONFIGFILENAME";
}

sub write_pfmrc {
    local $_;
    my @resourcefile;
    if (open MKPFMRC, '>' . &whichconfigfile) {
        # both __DATA__ and __END__ markers are used at the same time
        push (@resourcefile, $_) while (($_ = <DATA>) !~ /^__END__$/);
        close DATA;
        print MKPFMRC map {
            s/^(##? Version )x$/$1$VERSION/m;
            s/^([A-Z]:\w+.*?\s+)more(\s*)$/$1less$2/mg if $^O =~ /linux/i;
            $_;
        } @resourcefile;
        close MKPFMRC;
    } # no success? well, that's just too bad
}

sub read_pfmrc { # $readflag - show copyright only on startup (first read)
    %dircolors = %pfmrc = ();
    local $_;
    my $termkeys;
    unless (-r &whichconfigfile) {
        unless ($ENV{PFMRC} || -d $CONFIGDIRNAME) {
            # only make directory for default location ($ENV{PFMRC} unset)
            mkdir $CONFIGDIRNAME, $CONFIGFILEMODE;
        }
        &write_pfmrc;
    }
    if (open PFMRC, &whichconfigfile) {
        while (<PFMRC>) {
            s/#.*//;
            if (s/\\\n?$//) { $_ .= <PFMRC>; redo; }
            if (/^\s*       # whitespace at beginning
                 ([^:\s]+)  # keyword
                 \s*:\s*    # separator (:), may have whitespace around it
                 (.*)$/x    # value - allow spaces
            ) {
                $pfmrc{$1} = $2;
            }
        }
        close PFMRC;
    }
    # 'usecolor'
    if (defined($pfmrc{usecolor}) && ($pfmrc{usecolor} eq 'force')) {
        $scr->colorizable($TRUE);
    } elsif (defined($pfmrc{usecolor}) && ! &yesno($pfmrc{usecolor})) {
        $scr->colorizable($FALSE);
    }
    # 'copyrightdelay', 'cursorveryvisible'
    &copyright($pfmrc{copyrightdelay}) unless $_[0];
    $cursorveryvisible = &yesno($pfmrc{cursorveryvisible});
    system ('tput', $cursorveryvisible ? 'cvvis' : 'cnorm');
    # 'erase', 'keymap'
    system ('stty', 'erase', $pfmrc{erase}) if defined($pfmrc{erase});
    $kbd->set_keymap($pfmrc{keymap})        if $pfmrc{keymap};
    # some configuration options are NOT fetched into common scalars
    # (e.g. confirmquit) - however, they remain accessable in %pfmrc
    $clsonexit         = &yesno($pfmrc{clsonexit});
    $clobber           = &yesno($pfmrc{clobber});
    $dot_mode          = &yesno($pfmrc{dotmode});
    $dotdot_mode       = &yesno($pfmrc{dotdotmode});
    $autowritehistory  = &yesno($pfmrc{autowritehistory});
    $autoexitmultiple  = &yesno($pfmrc{autoexitmultiple});
    $mouseturnoff      = &yesno($pfmrc{mouseturnoff});
    $swap_persistent   = &yesno($pfmrc{persistentswap});
    $trspace           = &yesno($pfmrc{translatespace}) ? ' ' : '';
    # don't change sort_mode and currentlayout through the config file:
    # the config file just specifies the _defaults_ for globalinit();
    # at runtime use (F6) and (F9)
#    $sort_mode         = $pfmrc{sortmode}   || 'n';
#    $currentlayout     = $pfmrc{currentlayout} || 0;
    $ducmd             = $pfmrc{ducmd} || $DUCMDS{$^O} || $DUCMDS{default};
    $viewbase          = $pfmrc{viewbase} eq 'hex' ? "%#04lx" : "%03lo";
    $timestampformat   = $pfmrc{timestampformat}  || '%y %b %d %H:%M';
    $timeformat        = $pfmrc{timeformat}       || 'pfm';
    $headercolor       = $pfmrc{headercolor}      || '37;44';
    $multicolor        = $pfmrc{multicolor}       || '36;47';
    $titlecolor        = $pfmrc{titlecolor}       || '01;07;36;47';
    $swapcolor         = $pfmrc{swapcolor}        || '07;36;40';
    $footercolor       = $pfmrc{footercolor}      || '07;34;47';
    $mouse_mode        = $pfmrc{mousemode}        || 'xterm';
    $mouse_mode        = ($mouse_mode eq 'xterm' && $ENV{TERM} eq 'xterm')
                             || &yesno($mouse_mode);
    ($printcmd)        = ($pfmrc{printcmd}) ||
                             ($ENV{PRINTER} ? "lpr -P$ENV{PRINTER}" : 'lpr');
    $showlockchar      = ( $pfmrc{showlock} eq 'sun' && $^O =~ /sun|solaris/i
                             or &yesno($pfmrc{showlock}) ) ? 'l' : 'S';
    $editor            = $ENV{EDITOR} || $pfmrc{editor} || 'vi';
    $pager             = $ENV{PAGER}  || $pfmrc{pager}  ||
                             ($^O =~ /linux/i ? 'less' : 'more');
    # split 'columnlayouts'
    @columnlayouts     = split(/:/, ( $pfmrc{columnlayouts}
        ? $pfmrc{columnlayouts}
        :   '* nnnnnnnnnnnnnnnnnnnnNsssssssS mmmmmmmmmmmmmmmiiiiiii pppppppppp:'
        .   '* nnnnnnnnnnnnnnnnnnnnNsssssssS aaaaaaaaaaaaaaaiiiiiii pppppppppp:'
        .   '* nnnnnnnnnnnnnnnnnnnnNsssssssS uuuuuuuu gggggggglllll pppppppppp'
    ));
    # parse 'dircolors'
    $pfmrc{dircolors} ||= $ENV{LS_COLORS} || $ENV{LS_COLOURS};
    if ($pfmrc{dircolors}) {
        while ($pfmrc{dircolors} =~ /([^:=*]+)=([^:=]+)/g ) {
            $dircolors{$1} = $2;
        }
    }
    # additional key definitions 'keydef'
    if ($termkeys = $pfmrc{"keydef_$ENV{TERM}"}) {
        $termkeys =~ s/(\\e|\^\[)/\e/gi;
        # this does not allow : chars to appear in escape sequences!
        foreach (split /:/, $termkeys) {
            /^(\w+)=(.*)/;
            $scr->def_key($1, $2);
        }
    }
}

sub write_history {
    my $failed;
    foreach (keys(%HISTORIES)) {
        if (open (HISTFILE, ">$CONFIGDIRNAME/$_")) {
            print HISTFILE join "\n",@{$HISTORIES{$_}},'';
            close HISTFILE;
        } elsif (!$failed) {
            $scr->bold()->cyan()->puts("Unable to save (part of) history: $!\n")
                ->normal();
            # wait? refresh?
            $failed++; # warn only once
        }
    }
}

sub read_history {
    my $hfile;
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
        print CWDFILE getcwd();
        close CWDFILE;
    } else {
        $scr->bold()->cyan()
            ->puts("Unable to create $CONFIGDIRNAME/$CWDFILENAME: $!\n")
            ->normal();
    }
}

##########################################################################
# some translations

sub getversion {
    my $ver = '?';
    if ( open (SELF, $0) || open (SELF, `which $0`) ) {
        foreach (grep /^#+ Version:/, <SELF>) {
            /([\d\.]+\w)/ and $ver = "$1";
        }
        close SELF;
    }
    return $ver;
}

sub init_uids {
    my (%user, $name, $uid);
    while (($name, undef, $uid) = getpwent) {
        $user{$uid} = $name
    }
    endpwent;
    return %user;
}

sub init_gids {
    my (%group, $name, $gid);
    while (($name, undef, $gid) = getgrent) {
        $group{$gid} = $name
    }
    endgrent;
    return %group;
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

sub time2str {
    my ($time, $flag) = @_;
    if ($flag == $TIME_FILE) {
        return strftime ($timestampformat, localtime $time);
    } else {
        return strftime ("%Y %a %d %H:%M:%S", localtime $time);
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
    # 5000  S_IFNAM       050000  XENIX named special file with two subtypes,
    #                             distinguished by st_rdev values 1, 2:
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
    # whiteout support is broken: readdir does not return the names of w-entries
    # furthermore, the link count (0) on w-entries will pose problems too
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
        $size_power =~ tr/KMGTP/MGTPE/ || do { $size_power = 'K' };
    }
    return ($size_num, $size_power);
}

sub expand_12_escapes {
    my %thisfile = %{$_[1]};
    my $namenoext =
        $thisfile{name} =~ /^(.*)\.([^\.]+)$/ ? $1 : $thisfile{name};
    # there must be an odd nr. of backslashes before the digit
    # because \\ must be interpreted as an escaped backslash
    $_[0] =~ s/((?<!\\)(?:\\\\)*)\\1/$1$namenoext/g;
    $_[0] =~ s/((?<!\\)(?:\\\\)*)\\2/$1$thisfile{name}/g;
}

sub expand_345_escapes {
    # there must be an odd nr. of backslashes before the digit
    # because \\ must be interpreted as an escaped backslash
    $_[0] =~ s/((?<!\\)(?:\\\\)*)\\3/$1$currentdir/g;
    $_[0] =~ s/((?<!\\)(?:\\\\)*)\\4/$1$disk{mountpoint}/g;
    $_[0] =~ s/((?<!\\)(?:\\\\)*)\\5/$1$swap_state->{path}/g if $swap_state;
    # readline understands ~ notation; now we understand it too
    # ~user is not replaced if it is not in the passwd file
    $_[0] =~ s/^~(\/|$)/$ENV{HOME}\//;
    $_[0] =~ s/^~([^:\/]+)/(getpwnam $1)[7] || "~$1"/e;
}

sub expand_escapes {
    &expand_12_escapes(@_);
    &expand_345_escapes(@_);
    $_[0] =~ s/\\\\/\\/g;
}

sub readintohist { # \@history, $prompt, [$default_input]
    local $SIG{INT} = 'IGNORE'; # do not interrupt pfm
#    local $^W       = 0;        # Term::Readline::Gnu is not -w proof
    my $history     = shift;
    my $prompt      = shift || '';
    my $input       = shift || '';
    $kbd->SetHistory(@$history);
    $input = $kbd->readline($prompt,$input);
    if ($input =~ /\S/ and $input ne ${$history}[$#$history]) {
        push (@$history, $input);
        shift (@$history) if ($#$history > $MAXHISTSIZE);
    }
    return $input;
}

sub yesno {
    return $_[0] =~ /^(always|yes|1|true|on)$/i;
}

sub min ($$) {
    return +($_[1] < $_[0]) ? $_[1] : $_[0];
}

sub max ($$) {
    return +($_[1] > $_[0]) ? $_[1] : $_[0];
}

sub findchangedir {
    my $goal = $_[0];
    if (!-d $goal and $goal !~ /\// and $goal ne '') {
        foreach (split /:/, $ENV{CDPATH}) {
            if (-d "$_/$goal") {
                $goal = "$_/$goal";
                $scr->at(0,0)->clreol();
                &display_error("Using $goal");
                $scr->at(0,0);
                last;
            }
        }
    }
    return chdir $goal;
}

sub mychdir ($) {
    my $goal = $_[0];
    my $result;
    if ($result = &findchangedir($goal) and $goal ne $currentdir) {
        $oldcurrentdir = $currentdir;
    }
    $currentdir = getcwd() || $ENV{HOME};
    return $result;
}

sub inhibit ($$) {
    return !$_[0] && $_[1];
}

sub toggle ($) {
    $_[0] = !$_[0];
}

sub basename {
    $_[0] =~ /\/([^\/]*)$/; # ok, it has LTS but this looks better in vim
    return $1;
}

sub maxpan {
    my $temp = shift;
    my $panspace;
    # this is an assignment on purpose
    if ($panspace = 2 * (length($temp) > $screenwidth)) {
        eval "
            \$temp =~ s/^((?:\\S+ )+?).{1,".($screenwidth-$panspace)."}\$/\$1/;
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

sub filterdir {
    return grep { !$dot_mode || $_->{name} =~ /^(\.\.?|[^\.].*)$/ } @_;
}

sub figuretoolong {
    foreach (@dircontents) {
        $_->{name_too_long} = length($_->{display}) > $maxfilenamelength-1
            ? $NAMETOOLONGCHAR : ' ';
        @{$_}{qw(size_num size_power)} =
            &fit2limit($_->{size}, $maxfilesizelength);
        @{$_}{qw(grand_num grand_power)} =                  ####### ? #######
            &fit2limit($_->{grand}, $maxgrandtotallength);  ####### ? #######
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
           : &mode2str((stat $currentfile{name})[2]);
}

sub copyback {
    # copy a changed entry from @showncontents back to @dircontents
    $dircontents[&dirlookup($_[0], @dircontents)] =
        $showncontents[$currentline+$baseindex];
}

sub isorphan {
    return ! -e $_[0];
}

sub resizecatcher {
    $wasresized = 1;
    $SIG{WINCH} = \&resizecatcher;
}

sub mouseenable {
    if ($_[0]) {
        $scr->puts("\e[?9h");
    } else {
        $scr->puts("\e[?9l");
    }
}

sub stty_raw {
    if ($_[0]) {
        system qw(stty -raw echo);
    } else {
        system qw(stty raw -echo);
    }
}

##########################################################################
# debugging helper commands

sub dumprefreshflags {
    my $res;
    $res .= "R_QUIT\n"        if $_[0] & $R_QUIT;
    $res .= "R_NEWDIR\n"      if $_[0] & $R_NEWDIR;
    $res .= "R_DIRCONTENTS\n" if $_[0] & $R_DIRCONTENTS;
    $res .= "R_DIRSORT\n"     if $_[0] & $R_DIRSORT;
    $res .= "R_CLS\n"         if $_[0] & $R_CLS;
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

##########################################################################
# apply color

sub digestcolor {
    return unless defined $_[0];
    foreach (split /;/, $_[0]) { $scr->color($_) }
}

sub decidecolor {
    my %file = @_;
    $file{nlink} ==  0        and &digestcolor($dircolors{lo}), return;
    $file{type}  eq 'd'       and &digestcolor($dircolors{di}), return;
    $file{type}  eq 'l'       and &digestcolor(
                                  $dircolors{&isorphan($file{name}) ?'or':'ln'}
                              ), return;
    $file{type}  eq 'b'       and &digestcolor($dircolors{bd}), return;
    $file{type}  eq 'c'       and &digestcolor($dircolors{cd}), return;
    $file{type}  eq 'p'       and &digestcolor($dircolors{pi}), return;
    $file{type}  eq 's'       and &digestcolor($dircolors{so}), return;
    $file{type}  eq 'D'       and &digestcolor($dircolors{'do'}), return;
    $file{type}  eq 'n'       and &digestcolor($dircolors{nt}), return;
    $file{type}  eq 'w'       and &digestcolor($dircolors{wh}), return;
    $file{mode}  =~ /[xst]/   and &digestcolor($dircolors{ex}), return;
    $file{name}  =~/(\.\w+)$/ and &digestcolor($dircolors{$1}), return;
}

sub applycolor {
    if ($scr->colorizable()) {
        my ($line, $length, %file) = (shift, shift, @_);
        $length = $length ? 255 : $maxfilenamelength-1;
        &decidecolor(%file);
        $scr->at($line, $filenamecol)
            ->puts(substr($file{name}, 0, $length))->normal();
    }
}

##########################################################################
# small printing routines

sub makeformatlines {
    my ($squeezedlayoutline, $prev, $letter, $trans);
    if ($currentlayout > $#columnlayouts) {
        $currentlayout = 0;
    }
    my $currentlayoutline = $columnlayouts[$currentlayout];
    # find out the length of the filename and filesize fields
    $maxfilenamelength   =       ($currentlayoutline =~ tr/n//) +$screenwidth -80;
    $maxfilesizelength   = 10 ** ($currentlayoutline =~ tr/s// -1) -1;
    if ($maxfilesizelength < 2) { $maxfilesizelength = 2 }
    $maxgrandtotallength = 10 ** ($currentlayoutline =~ tr/z// -1) -1;
    if ($maxgrandtotallength < 2) { $maxgrandtotallength = 2 }
    # layouts are all based on a screenwidth of 80
    # elongate filename field
    $currentlayoutline =~ s/n/'n' x ($screenwidth - 79)/e;
    # provide N, S and Z fields
    $currentlayoutline =~ s/n(?!n)/N/i;
    $currentlayoutline =~ s/s(?!s)/S/i;
    $currentlayoutline =~ s/z(?!z)/Z/i;
    $cursorcol         = index ($currentlayoutline, '*');
    $filenamecol       = index ($currentlayoutline, 'n');
    foreach ($cursorcol, $filenamecol) {
        if ($_ < 0) { $_ = 0 }
    }
    ($squeezedlayoutline = $currentlayoutline) =~
        tr/*nNsSzZugpacmdil /*nNsSzZugpacmdil/ds;
    @layoutfields = map {
        if    ($_ eq '*') { 'selected'      }
        elsif ($_ eq 'n') { 'display'       }
        elsif ($_ eq 'N') { 'name_too_long' }
        elsif ($_ eq 's') { 'size_num'      }
        elsif ($_ eq 'S') { 'size_power'    }
        elsif ($_ eq 'z') { 'grand_num'     }
        elsif ($_ eq 'Z') { 'grand_power'   }
        elsif ($_ eq 'u') { 'uid'           }
        elsif ($_ eq 'g') { 'gid'           }
        elsif ($_ eq 'p') { 'mode'          }
        elsif ($_ eq 'a') { 'atimestring'   }
        elsif ($_ eq 'c') { 'ctimestring'   }
        elsif ($_ eq 'm') { 'mtimestring'   }
        elsif ($_ eq 'l') { 'nlink'         }
        elsif ($_ eq 'i') { 'inode'         }
        elsif ($_ eq 'd') { 'rdev'          }
    } (split //, $squeezedlayoutline);
    $currentformatline = $prev = '';
    foreach $letter (split //, $currentlayoutline) {
        if ($letter eq ' ') {
            $currentformatline .= ' ';
        } elsif ($prev ne $letter) {
            $currentformatline .= '@';
        } else {
            ($trans = $letter) =~ tr/*nNsSzZugpacmdilf/<<<><><<<<<<<<>></;
            $currentformatline .= $trans;
        }
        $prev = $letter;
    }
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
                # this is the case for e.g. /some_insanely_long_directoryname
                $disppath = substr($path, 0, $maxpathlen);
                $overflow = $NAMETOOLONGCHAR;
                last FIT;
            }
            ($disppath, $path) = ($1, $2);
            # the one being subtracted is for the '/' char in the next match
            $restpathlen = $maxpathlen -length($disppath) -length($ELLIPSIS) -1;
            unless ($path =~ /(\/.{1,$restpathlen})$/) {
                # impossible to replace; just truncate
                # this is the case for e.g. /usr/someinsanelylongdirectoryname
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
    $scr->at($currentline + $BASELINE, 0);
    $scr->bold() if ($_[0] == $HIGHLIGHT_ON);
    $scr->puts(&fileline(\%currentfile, @layoutfields));
    &applycolor($currentline + $BASELINE, $FILENAME_SHORT, %currentfile);
    $scr->normal()->at($currentline + $BASELINE, $cursorcol);
}

sub markcurrentline { # letter
    $scr->at($currentline + $BASELINE, $cursorcol)->puts($_[0]);
}

sub pressanykey {
    $scr->cyan();
    print "\n*** Hit any key to continue ***";
    &stty_raw($TERM_RAW);
    $scr->normal()->getch();
}

sub display_error {
    $scr->cyan()->bold()->puts($_[0])->normal();
    return $scr->key_pressed($ERRORDELAY); # return value not actually used
}

sub neat_error {
    $scr->at(0,0)->clreol();
    &display_error($!);
    if ($multiple_mode) {
        return $R_PATHINFO;
    } else {
        return $R_FRAME;
    }
}

sub ok_to_remove_marks {
    my $sure;
    if (&mark_info) {
        $sure = $scr->at(0,0)->clreol()->bold()->cyan()
                    ->puts("OK to remove marks [Y/N]? ")->normal()->getch();
        &init_header;
        return ($sure =~ /y/i);
    }
    1;
}

sub promptforwildfilename {
    my $prompt = 'Wild filename (regular expression): ';
    my $wildfilename;
    $scr->at(0,0)->clreol();
    &stty_raw($TERM_COOKED);
    $wildfilename = &readintohist(\@regex_history, $prompt);
    # init_header is done in handleinclude
    &stty_raw($TERM_RAW);
    eval "/$wildfilename/";
    if ($@) {
        &display_error($@);
        $scr->key_pressed(1.5); # add 1.5 seconds
        $wildfilename = '^$';   # clear illegal regexp
    }
    return $wildfilename;
}

sub clearcolumn {
    my $spaces = ' ' x $DATECOL;
    foreach ($BASELINE .. $BASELINE+$screenheight) {
        $scr->at($_, $screenwidth-$DATECOL)->puts($spaces);
    }
}

sub path_info {
    $scr->at($PATHLINE, 0)->puts(&pathline($currentdir, $disk{'device'}));
}

##########################################################################
# headers, footers

sub fitbanner { # $header/footer, $screenwidth
    my ($banner, $virtwidth) = @_;
    my ($maxwidth, $spcount);
    if (length($banner) > $virtwidth) {
        $spcount  = &maxpan($banner);
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
   &init_header;
   &init_title($swap_mode, $TITLE_DISKINFO, @layoutfields);
   &init_footer;
}

sub init_title { # swap_mode, extra field, @layoutfields
    my ($smode, $info, @fields) = @_;
    my $linecolor;
    for ($info) {
        $_ == $TITLE_DISKINFO and $info = '     disk info';
        $_ == $TITLE_SORT     and $info = 'sort mode     ';
        $_ == $TITLE_SIGNAL   and $info = '  nr signal   ';
        $_ == $TITLE_COMMAND  and $info = 'your commands ';
    }
    &digestcolor($linecolor = $smode ? $swapcolor : $titlecolor);
    $scr->reverse() if ($linecolor =~ /\b0?7\b/);
    $scr->bold()    if ($linecolor =~ /\b0?1\b/);
    $^A = '';
    formline($currentformatline . ' @>>>>>>>>>>>>>',
        @{$TITLEVIRTFILE}{@fields}, $info);
    $scr->at(2,0)->puts($^A)->normal();
}

sub header {
    # do not take multiple mode into account at all
    my $mode = $_[0] & ~$HEADER_MULTI;
    if      ($mode & $HEADER_SORT) {
        return 'Sort by: Name, Extension, Size, Date, Type, Inode'
        .     ' (ignorecase, reverse):';
    } elsif ($mode & $HEADER_MORE) {
        return 'Config pfm Edit new file Make new dir Show dir sHell Kill'
        .     ' Write history ESC';
    } elsif ($mode & $HEADER_INCLUDE) {
        return 'Include? Every, Oldmarks, User or Files only:';
    } else {
        return 'Attribute Copy Delete Edit Find Include tarGet Link More'
        .     ' cOmmands Print Quit Rename Show Time User View eXclude'
        .     ' Your-commands siZe';
    }
}

sub init_header { # <special header mode>
    my $mode = $_[0] || ($multiple_mode * $HEADER_MULTI);
    my ($pos, $header, $headerlength, $vscreenwidth);
    $vscreenwidth = $screenwidth - 9*$multiple_mode;
    $header       = &fitbanner(&header($mode), $vscreenwidth);
    $headerlength = length($header);
    if ($headerlength < $vscreenwidth) {
        $header .= ' ' x ($vscreenwidth - $headerlength);
    }
    $scr->at(0,0);
    if ($mode & $HEADER_MULTI) {
        &digestcolor($multicolor);
        $scr->reverse()->bold()->puts('Multiple')->normal();
    }
    &digestcolor($headercolor);
    $scr->puts(' ' x $multiple_mode)->puts($header)->bold();
    # in earlier days, regex was [A-Z](?!FM |M E| Ed)
    while ($header =~ /[A-Z<>]/g) {
        $pos = pos($header) -1;
        $scr->at(0, $pos + 9*$multiple_mode)->puts(substr($header, $pos, 1));
    }
    $scr->normal();
    return $headerlength;
}

sub footer {
    return "F1-Help F2-Back F3-Redraw F4-Color[$ONOFF{$scr->colorizable()}]"
    .     " F5-Reread F6-Sort[$sort_mode] F7-Swap[$ONOFF{$swap_mode}]"
    .     " F8-Include F9-Columns[$currentlayout]"
    .     " F10-Multiple[$ONOFF{$multiple_mode}] F11-Restat"
    .     " F12-Mouse[$ONOFF{$mouse_mode}]";
}

sub init_footer {
    my $footer = &fitbanner(&footer, $screenwidth);
    &digestcolor($footercolor);
    $scr->reverse() if ($footercolor =~ /\b0?7\b/);
    $scr->bold()->at($BASELINE+$screenheight+1,0) ->puts($footer)
        ->puts(' ' x ($screenwidth - length $footer))->normal();
}

sub copyright {
    return unless $_[0];
    # lookalike to DOS version :)
    $scr->cyan() ->puts("PFM $VERSION for Unix computers and compatibles.")
        ->at(1,0)->puts("Copyright (c) 1999-2002 Rene Uittenbogaard")
        ->at(2,0)->puts("This software comes with no warranty: see the file "
                       ."COPYING for details.")->normal();
    return $scr->key_pressed($_[0]);
}

sub globalinit {
    my $startingdir = shift;
    $SIG{WINCH} = \&resizecatcher;
    $kbd = Term::ReadLine->new('Pfm', \*STDIN, \*STDOUT);
    $scr = Term::ScreenColor->new();
    $scr->clrscr();
    &read_pfmrc($READ_FIRST);
    &read_history;
    %user           = &init_uids;
    %group          = &init_gids;
    @signame        = &init_signames;
    %selected_nr_of = %total_nr_of = ();
    $swap_mode      = $multiple_mode = 0;
    $swap_state     = $currentpan = 0;
    $baseindex      = 0;
    $sort_mode      = $pfmrc{defaultsortmode} || 'n';
    $currentlayout  = $pfmrc{defaultlayout}   || 0;
    if ($scr->rows()) { $screenheight = $scr->rows()-$BASELINE-2 }
    if ($scr->cols()) { $screenwidth  = $scr->cols() }
    &makeformatlines;
    &init_frame;
    &mouseenable($mouse_mode);
    # now find starting directory
    $oldcurrentdir = $currentdir = getcwd();
    $startingdir and &mychdir($startingdir) || do {
        $scr->at(0,0)->clreol();
        &display_error("$startingdir: $! - using .");
        $scr->key_pressed(1); # add another second error delay
        &init_header;
    };
}

sub goodbye {
    my $bye = 'Goodbye from your Personal File Manager!';
    &mouseenable($MOUSE_OFF);
    &stty_raw($TERM_COOKED);
    if ($clsonexit) {
        $scr->clrscr();
    } else {
        $scr->at(0,0)->puts(' ' x (($screenwidth-length $bye)/2) . $bye)
            ->clreol()->normal()->at($PATHLINE,0);
    }
    &write_cwd;
    &write_history if $autowritehistory;
    unless ($clsonexit) {
        $scr->at($screenheight+$BASELINE+1,0)->clreol();
    }
    system qw(tput cnorm) if $cursorveryvisible;
}

sub credits {
    $scr->clrscr();
    &stty_raw($TERM_COOKED);
    print <<"_eoCredits_";


             PFM for Unix computers and compatibles.  Version $VERSION
             Original idea/design: Paul R. Culley and Henk de Heer
             Author and Copyright (c) 1999-2002 Rene Uittenbogaard


       PFM is distributed under the GNU General Public License version 2.
                    PFM is distributed without any warranty,
             even without the implied warranties of merchantability
                      or fitness for a particular purpose.
                   Please read the file COPYING for details.


      You are encouraged to copy and share this program with other users.
   Any bug, comment or suggestion is welcome in order to update this product.


                For questions, remarks or suggestions about PFM,
                 send email to: ruittenb\@users.sourceforge.net


                                                          any key to exit to PFM
_eoCredits_
    &stty_raw($TERM_RAW);
    $scr->getch();
}

##########################################################################
# system information

sub user_info {
    $^A = "";
    formline('@>>>>>>>', $user{$>});
    $scr->red() unless ($>);
    $scr->at($USERLINE, $screenwidth-$DATECOL+6)->puts($^A)->normal();
}

sub infoline { # number, description
    $^A = "";
    formline('@>>>>>> @<<<<<', @_);
    return $^A;
}

sub disk_info { # %disk{ total, used, avail }
    local $_;
    my @desc      = ('K tot','K usd','K avl');
    my @values    = @disk{qw/total used avail/};
    my $startline = 4;
    # I played with vt100 boxes once,      lqqqqk
    # but I hated it.                      x    x
    # In case someone wants to try:        mqqqqj
#    $scr->at($startline-1,$screenwidth-$DATECOL)
#        ->puts("\cNlqq\cO Disk space");
    $scr->at($startline-1, $screenwidth-$DATECOL+4)->puts('Disk space');
    foreach (0..2) {
        while ($values[$_] > 99_999) {
                $values[$_] /= 1024;
                $desc[$_] =~ tr/KMGTP/MGTPE/;
        }
        $scr->at($startline+$_, $screenwidth-$DATECOL+1)
            ->puts(&infoline(int($values[$_]), $desc[$_]));
    }
}

sub dir_info {
    local $_;
    my @desc   = qw/files dirs symln spec/;
    my @values = @total_nr_of{'-','d','l'};
    $values[3] = $total_nr_of{'c'} + $total_nr_of{'b'}
               + $total_nr_of{'p'} + $total_nr_of{'s'}
               + $total_nr_of{'D'} + $total_nr_of{'w'}
               + $total_nr_of{'n'};
    my $startline = 9;
    $scr->at($startline-1, $screenwidth - $DATECOL + !$dot_mode)
        ->puts(" Directory($sort_mode" . ($dot_mode ? '.' : '') . ")");
    foreach (0..3) {
        $scr->at($startline+$_,$screenwidth-$DATECOL+1)
            ->puts(&infoline($values[$_],$desc[$_]));
    }
}

sub mark_info {
    my @desc = qw/bytes files dirs symln spec/;
    my @values = @selected_nr_of{'bytes','-','d','l'};
    $values[4] = $selected_nr_of{'c'} + $selected_nr_of{'b'}
               + $selected_nr_of{'p'} + $selected_nr_of{'s'}
               + $selected_nr_of{'D'} + $selected_nr_of{'w'}
               + $selected_nr_of{'n'};
    my $startline = 15;
    my $total = 0;
    $values[0] = join ('', &fit2limit($values[0], 9_999_999));
    $values[0] =~ s/ $//;
    $scr->at($startline-1, $screenwidth-$DATECOL+2)->puts('Marked files');
    foreach (0..4) {
        $scr->at($startline+$_, $screenwidth-$DATECOL+1)
            ->puts(&infoline($values[$_], $desc[$_]));
        $total += $values[$_] if $_;
    }
    return $total;
}

sub date_info {
    my ($line, $col) = @_;
    my ($datetime, $date, $time);
    $datetime = &time2str(time, $TIME_CLOCK);
    ($date, $time) = ($datetime =~ /(.*)\s+(.*)/);
    # it might be better to do this with formline and $^A
    $scr->at($line++, $col+3)->puts($date) if ($scr->rows() > 24);
    $scr->at($line++, $col+6)->puts($time);
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

##########################################################################
# user commands

sub handlequit { # key
    return $R_QUIT if $pfmrc{confirmquit} =~ /^(never|no|0|false|off)$/i;
    return $R_QUIT if $_[0] eq 'Q'; # quick quit
    return $R_QUIT if ($pfmrc{confirmquit} =~ /marked/i and !&mark_info);
    $scr->at(0,0)->clreol()->bold()->cyan();
    $scr->puts("Are you sure you want to quit [Y/N]? ")->normal();
    my $sure = $scr->getch();
    return +($sure =~ /y/i) ? $R_QUIT : $R_HEADER;
}

sub handlemultiple {
    toggle($multiple_mode);
    return $R_HEADER;
}

sub handlecolumns {
    ++$currentlayout;
    &makeformatlines;
    &figuretoolong;
    return $R_DIRLIST | $R_TITLE;
}

sub handlerefresh {
    return &ok_to_remove_marks ? $R_DIRCONTENTS | $R_DIRSORT | $R_SCREEN
                               : $R_NOP;
}

sub handlecolor {
    $scr->colorizable(!$scr->colorizable());
    return $R_SCREEN;
}

sub handlemousetoggle {
    &mouseenable(toggle $mouse_mode);
    return $R_FOOTER;
}

sub handleresize {
    $wasresized = 0;
    &handlefit;         # returns R_SCREEN, which is correct...
    &validate_position; # ... but we must validate the cursor position too
    return $R_CLEAR;
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
        $do_a_refresh |= $mbutton ? &handlecommand('o') : &handlemoreshow;
    } elsif ($mouserow < $BASELINE) {
        $do_a_refresh |= $mbutton ? &handlemove('pgup') : &handlemove("\cU");
    } elsif ($mouserow > $screenheight + $BASELINE) {
        $do_a_refresh |= $mbutton ? &handlemove('pgdn') : &handlemove("\cD");
    } elsif ($mousecol >= $screenwidth - $DATECOL
            or !defined $showncontents[$mouserow - $BASELINE + $baseindex]) {
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
            $do_a_refresh |= &handleshowenter("\r");
        } elsif (!$on_name and !$mbutton) {
            $do_a_refresh |= &handleselect;
        } else {
            $do_a_refresh |= &handleshowenter('s');
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
    &handleselect;
    # this automatically passes the " " key in $_[0] to &handlemove
    # ..and loses the return value from &handleselect. solve this in handlemove
    goto &handlemove;
}

sub handlesize {
    my ($recursivesize, $command, $tempfile);
    &markcurrentline('Z'); # disregard multiple_mode
    &expand_escapes($command = $ducmd, \%currentfile);
    ($recursivesize = `$command`) =~ s/\D*(\d+).*/$1/;
#    unless ($?) { # think about what to do when $? != 0 ?
        $scr->at($currentline + $BASELINE, 0);
        @{$showncontents[$currentline+$baseindex]}
            {qw(grand grand_num grand_power)} = ($recursivesize,
            &fit2limit($recursivesize, $maxgrandtotallength));
        if (join('', @layoutfields) =~ /grand/) {
            $scr->puts(&fileline($showncontents[$currentline+$baseindex],
                @layoutfields));
        } else {
            # use size field
            $tempfile = { %currentfile };
            @{$tempfile}{qw(size size_num size_power)} = ($recursivesize,
                &fit2limit($recursivesize, $maxfilesizelength));
            $scr->puts(&fileline($tempfile, @layoutfields));
        }
        &markcurrentline('Z');
        &applycolor($currentline + $BASELINE, $FILENAME_SHORT, %currentfile);
        $scr->getch();
#    }
    return $R_NOP;
}

sub handledot {
    &toggle($dot_mode);
    $position_at = $currentfile{name};
#    @showncontents = &filterdir(@dircontents);
#    &validate_position;
    return $R_DIRLIST | $R_DIRFILTER | $R_DISKINFO;
}

sub handleshowenter {
    my $followmode  = &followmode(\%currentfile);
    if ($followmode =~ /^d/) {
        goto &handleentry;
    } elsif ($_[0] =~ /\r/ and $followmode =~ /x/) {
        goto &handleenter;
    } else {
        goto &handleshow;
    }
}

sub handlecdold {
    if (&ok_to_remove_marks) {
        &mychdir($oldcurrentdir);
        return $R_CHDIR;
    } else {
        return $R_HEADER;
    }
}

sub handlepan {
    my $count   = max(&maxpan(&header), &maxpan(&footer));
#    # add 2 for safety, because header and footer are of unequal length
#    my $count   = 2 + &maxpan(&header);
    $currentpan = $currentpan - ($_[0] =~ /</ and $currentpan > 0)
                              + ($_[0] =~ />/ and $currentpan < $count);
    return $R_HEADER | $R_FOOTER;
}

sub handlefind {
    my $findme;
    my $prompt = 'File to find: ';
    $scr->at(0,0)->clreol();
    &stty_raw($TERM_COOKED);
    ($findme = &readintohist(\@path_history, $prompt)) =~ s/\/$//;
    if ($findme =~ /\//) { $findme = basename($findme) };
    &stty_raw($TERM_RAW);
    return $R_HEADER if $findme eq '';
    FINDENTRY:
    foreach (sort by_name @showncontents) {
        if ($_->{name} =~ /^$findme/) {
            $position_at = $_->{name};
            last FINDENTRY;
        }
    }
    return $R_DIRLIST | $R_HEADER;
}

sub handlefit {
    local $_;
    $scr->resize();
    my $newheight = $scr->rows();
    my $newwidth  = $scr->cols();
    if ($newheight || $newwidth) {
#        $ENV{ROWS}    = $newheight;
#        $ENV{COLUMNS} = $newwidth;
        $screenheight = $newheight - $BASELINE - 2;
        $screenwidth  = $newwidth;
    }
    &makeformatlines;
    &figuretoolong;
    return $R_CLEAR;
}

sub handleperlcommand {
    my $perlcmd;
    my $prompt = 'Enter Perl command:';
    $scr->at(0,0)->clreol()->cyan()->bold()->puts($prompt)->normal()
        ->at($PATHLINE,0)->clreol();
    &stty_raw($TERM_COOKED);
    $perlcmd = &readintohist(\@perlcmd_history);
    &stty_raw($TERM_RAW);
    eval $perlcmd;
    &display_error($@) if $@;
    return $R_SCREEN;
}

sub handlemoreshow {
    my ($newname, $do_a_refresh);
    my $prompt = 'Directory Pathname: ';
    return $R_HEADER unless &ok_to_remove_marks;
    $scr->at(0,0)->clreol();
    &stty_raw($TERM_COOKED);
    $newname = &readintohist(\@path_history, $prompt);
    &stty_raw($TERM_RAW);
    return $R_HEADER if $newname eq '';
    $position_at = '.';
    &expand_escapes($newname, \%currentfile);
    if (&mychdir($newname)) {
        $do_a_refresh |= $R_CHDIR;
    } else {
        &display_error("$newname: $!");
        $do_a_refresh |= $R_SCREEN;
    }
    return $do_a_refresh;
}

sub handlemoremake {
    my ($newname, $do_a_refresh);
    my $prompt  = 'New Directory Pathname: ';
    $scr->at(0,0)->clreol();
    &stty_raw($TERM_COOKED);
    $newname = &readintohist(\@path_history, $prompt);
    &stty_raw($TERM_RAW);
    return $R_HEADER if $newname eq '';
    if (!mkdir $newname, 0777) {
        &display_error("$newname: $!");
        $do_a_refresh |= $R_SCREEN;
    } elsif (!&ok_to_remove_marks) {
        $do_a_refresh |= $R_HEADER; # $R_SCREEN ?
    } elsif (!&mychdir($newname)) {
        &display_error("$newname: $!"); # e.g. by restrictive umask
        $do_a_refresh |= $R_SCREEN;
    } else {
        $position_at = '.';
        $do_a_refresh |= $R_CHDIR;
    }
    return $do_a_refresh;
}

sub handlemoreconfig {
    my $do_a_refresh = $R_CLEAR;
    my $olddotdot    = $dotdot_mode;
#    my $oldsort      = $sort_mode;
    if (system $editor, "$CONFIGDIRNAME/$CONFIGFILENAME") {
        &display_error($!);
    } else {
        &read_pfmrc($READ_AGAIN);
        if ($olddotdot != $dotdot_mode) {
            # allowed to switch dotdot mode (no key), but not sortmode (use F6)
#            $sort_mode     = $oldsort;
            $position_at   = $currentfile{name};
            $do_a_refresh |= $R_DIRSORT;
        }
        &makeformatlines;
    }
    return $do_a_refresh;
}


sub handlemoreedit {
    my $newname;
    my $stateprompt  = 'New name: ';
    $scr->at(0,0)->clreol();
    &stty_raw($TERM_COOKED);
    $newname = &readintohist(\@path_history, $stateprompt);
#    &expand_escapes($newname, $currentfile);
    system ($editor, $newname) and &display_error($!);
    &stty_raw($TERM_RAW);
    return $R_CLEAR;
}

sub handlemorekill {
    my $printline   = $BASELINE;
    my $stateprompt = 'Signal to send to child processes: ';
    my $signal      = 'TERM';
    &init_title($swap_mode, $TITLE_SIGNAL, @layoutfields);
    &clearcolumn;
    foreach (1 .. min($#signame, $screenheight)+1) {
        $^A = "";
        formline('@# @<<<<<<<<', $_, $signame[$_]);
        $scr->at($printline++, $screenwidth-$DATECOL+2)->puts($^A);
    }
    $scr->at(0,0)->clreol();
    &stty_raw($TERM_COOKED);
    $signal = $kbd->readline($stateprompt, $signal); # special case
    &stty_raw($TERM_RAW);
    &clearcolumn;
    return $R_HEADER | $R_TITLE | $R_DISKINFO if $signal eq '';
    if ($signal !~ /\D/) {
        $signal = $signame[$signal];
    }
    local $SIG{$signal} = 'IGNORE';
    # the "only portable" way from perlfunc(1) doesn't seem to work for me
#   kill -$signal, $$;
    kill $signal, -$$;
    return $R_HEADER | $R_PATHINFO | $R_TITLE | $R_DISKINFO;
}

sub handlemoreshell {
    $scr->clrscr();
    &stty_raw($TERM_COOKED);
#    @ENV{qw(ROWS COLUMNS)} = ($screenheight + $BASELINE + 2, $screenwidth);
    system ($ENV{SHELL} ? $ENV{SHELL} : 'sh'); # most portable
    &pressanykey; # will also put the screen back in raw mode
    return $R_CLEAR;
}

sub handlemore {
    local $_;
    my $do_a_refresh = $R_HEADER;
    my $headerlength = &init_header($HEADER_MORE);
    $scr->noecho();
    my $key = $scr->at(0, $headerlength+1)->getch();
    MOREKEY: for ($key) {
        /^s$/i and $do_a_refresh |= &handlemoreshow,      last MOREKEY;
        /^m$/i and $do_a_refresh |= &handlemoremake,      last MOREKEY;
        /^c$/i and $do_a_refresh |= &handlemoreconfig,    last MOREKEY;
        /^e$/i and $do_a_refresh |= &handlemoreedit,      last MOREKEY;
        /^h$/i and $do_a_refresh |= &handlemoreshell,     last MOREKEY;
        /^w$/i and $do_a_refresh |= &write_history,       last MOREKEY;
        # since when has pfm become a process manager?
        /^k$/i and $do_a_refresh |= &handlemorekill,      last MOREKEY;
#        /^p$/i and $do_a_refresh |= &handlemoreprocgroup, last MOREKEY;
    }
    return $do_a_refresh;
}

sub handleinclude { # include/exclude flag (from keypress)
    local $_;
    my $exin = shift;
    my $do_a_refresh = $R_HEADER;
    my ($criterion, $headerlength);
    our ($wildfilename, $entry);
    # $wildfilename could have been declared using my(), but that will prevent
    # changes in its value to be noticed by the anonymous sub
    $headerlength = &init_header($HEADER_INCLUDE);
    # modify header to say "exclude" when 'x' was pressed
    if ($exin =~ /x/i) { $scr->at(0,0)->on_blue()->puts('Ex')->normal(); }
    $exin =~ tr/ix/* /;
    my $key = $scr->at(0, $headerlength+1)->getch();
    if ($key =~ /^o$/i) {   # include oldmarks
        foreach $entry (@showncontents) {
            if ($entry->{selected} eq '.' && $exin eq ' ') {
                $entry->{selected} = $exin;
            } elsif ($entry->{selected} eq '.' && $exin eq '*') {
                &include($entry);
            }
            $do_a_refresh |= $R_SCREEN;
        }
    } elsif ($key =~ /^[efu]$/i) {
        if ($key =~ /^e$/i) { # include every
            $criterion = sub { $entry->{name} !~ /^\.\.?$/ };
        };
        if ($key =~ /^u$/i) { # user only
            $criterion = sub { $entry->{uid} =~ /$ENV{USER}/ };
        };
        if ($key =~ /^f$/i) { # include files
            $wildfilename = &promptforwildfilename;
            $criterion    = sub {
                                $entry->{name} =~ /$wildfilename/
                                and $entry->{type} eq '-';
                            };
        };
        foreach $entry (@showncontents) {
            if (&$criterion) {
                if ($entry->{selected} eq '*' && $exin eq ' ') {
                    &exclude($entry);
                } elsif ($entry->{selected} eq '.' && $exin eq ' ') {
                    $entry->{selected} = $exin;
                } elsif ($entry->{selected} ne '*' && $exin eq '*') {
                    &include($entry);
                }
                $do_a_refresh |= $R_SCREEN;
            }
        }
    } # if $key =~ /[efu]/
    return $do_a_refresh;
}

sub handleview {
    &markcurrentline('V'); # disregard multiple_mode
    # we are allowed to alter %currentfile because
    # when we exit with at least $R_STRIDE, %currentfile will be reassigned
    for ($currentfile{name}, $currentfile{target}) {
        s/\\/\\\\/;
        # don't ask how this works
        s{([${trspace}\177[:cntrl:]]|[^[:ascii:]])}
         {'\\' . sprintf($viewbase, unpack('C', $1))}eg;
    }
    $scr->at($currentline+$BASELINE, $filenamecol)->bold()
        # erase char after name, under cursor
        ->puts($currentfile{name} . (length($currentfile{target}) ? ' -> ' : '')
                                  . $currentfile{target} . " \cH");
    &applycolor($currentline+$BASELINE, $FILENAME_LONG, %currentfile);
    $scr->getch();
    if (length($currentfile{name}) + length($currentfile{target}) + $filenamecol
        > $screenwidth - $DATECOL
    ) {
        return $R_CLEAR;
    } else {
        return $R_STRIDE;
    }
}

sub handlesort {
    my $printline = $BASELINE;
    my %sortmodes = @SORTMODES;
    my ($i, $key, $headerlength);
    $headerlength = &init_header($HEADER_SORT);
    &init_title($swap_mode, $TITLE_SORT, @layoutfields);
    &clearcolumn;
    # we can't use foreach (keys %SORTMODES) because we would lose ordering
    foreach (grep { ($i += 1) %= 2 } @SORTMODES) { # keep keys, skip values
        $^A = "";
        formline('@ @<<<<<<<<<<<', $_, $sortmodes{$_});
        $scr->at($printline++, $screenwidth - $DATECOL)->puts($^A);
    }
    $key = $scr->at(0, $headerlength+1)->getch();
    &clearcolumn;
    if ($sortmodes{$key}) {
        $sort_mode   = $key;
        $position_at = $currentfile{name};
    }
    return $R_DIRSORT | $R_SCREEN;
}

sub handlekeyell {
    # small l only
    if ($currentfile{type} eq 'd') {
        # this automatically passes the 'l' key in $_[0] to &handleentry
        goto &handleentry;
    } else {
        goto &handlesymlink;
    }
}

sub handlesymlink {
    my ($newname, $loopfile, $do_this, $index, $newnameexpanded, $targetstring,
        $findindex);
    my $prompt = 'New symbolic link: ';
    my $do_a_refresh = $multiple_mode ? $R_DIRLIST | $R_HEADER : $R_HEADER;
    &markcurrentline('L') unless $multiple_mode;
    $scr->at(0,0)->clreol();
    &stty_raw($TERM_COOKED);
    push (@path_history, $currentfile{name}) unless $multiple_mode;
    $newname = &readintohist(\@path_history, $prompt);
    if ($#path_history > 0 and $path_history[-1] eq $path_history[-2]) {
        pop @path_history;
    }
    &stty_raw($TERM_RAW);
    return $R_HEADER if ($newname eq '');
    $do_this = sub {
        if (-d $newnameexpanded or $newnameexpanded =~ m!^[^/]/!) {
            $targetstring = $currentdir . "/" . $loopfile->{name};
        } else {
            $targetstring = $loopfile->{name};
        }
        if (system 'ln', ($clobber ? '-sf' : '-s'),
            $targetstring, $newnameexpanded
        ) {
            $do_a_refresh |= &neat_error;
#            $scr->at(0,0)->clreol();
#            &display_error($!);
#            if ($multiple_mode) {
#                &path_info;
#            } else {
#                $do_a_refresh |= $R_FRAME;
#            }
        } elsif ($newnameexpanded !~ m!/!) {
            # is newname present in @dircontents? push otherwise
            $findindex = 0;
            $findindex++ while ($findindex <= $#dircontents and
                          $newnameexpanded ne $dircontents[$findindex]{name});
            if ($findindex > $#dircontents) {
                $do_a_refresh |= $R_DIRSORT | $R_DIRFILTER;
            }
            $dircontents[$findindex] = &stat_entry($newnameexpanded,
                $dircontents[$findindex]{selected} || " ");
        }
    };
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            &expand_escapes(($newnameexpanded = $newname), $loopfile);
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                &exclude($loopfile,'.');
                &$do_this;
                $dircontents[$index] =
                    &stat_entry($loopfile->{name}, $loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        &expand_escapes(($newnameexpanded = $newname), $loopfile);
        &$do_this;
        $showncontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name}, $currentfile{selected});
        &copyback($currentfile{name});
    }
    return $do_a_refresh;
}

sub handletarget {
    my ($newtarget, $loopfile, $do_this, $index, $oldtargetok);
    my $nosymlinkerror = "Current file is not a symbolic link";
    if ($currentfile{type} ne 'l' and !$multiple_mode) {
        $scr->at(0,0)->clreol();
        &display_error($nosymlinkerror);
        return $R_HEADER;
    }
    my $prompt = 'New symlink target: ';
    my $do_a_refresh = $multiple_mode ? $R_DIRLIST | $R_HEADER : $R_HEADER;
    &markcurrentline('G') unless $multiple_mode;
    $scr->at(0,0)->clreol();
    &stty_raw($TERM_COOKED);
    push (@path_history, $currentfile{target}) unless $multiple_mode;
    chomp($newtarget = &readintohist(\@path_history, $prompt));
    if ($#path_history > 0 and $path_history[-1] eq $path_history[-2]) {
        pop @path_history;
    }
    &stty_raw($TERM_RAW);
    return $R_HEADER if ($newtarget eq '');
    $do_this = sub {
        if ($loopfile->{type} ne "l") {
            $scr->at(0,0)->clreol();
            &display_error($nosymlinkerror);
#            $do_a_refresh |= $R_HEADER;
        } else {
            $oldtargetok = 1;
            if (-d $loopfile->{name}) {
                # if it points to a dir, the symlink must be removed first
                # next line is an intentional assignment
                unless ($oldtargetok = unlink $loopfile->{name}) {
                    $do_a_refresh |= &neat_error;
#                    $scr->at(0,0)->clreol();
#                    &display_error($!);
#                    if ($multiple_mode) {
#                        &path_info;
#                    } else {
#                        $do_a_refresh |= $R_FRAME;
#                    }
                }
            }
            if ($oldtargetok and
                system qw(ln -sf), $newtarget, $loopfile->{name})
            {
                $do_a_refresh |= &neat_error;
#                $scr->at(0,0)->clreol();
#                &display_error($!);
#                if ($multiple_mode) {
#                    &path_info;
#                } else {
#                    $do_a_refresh |= $R_FRAME;
#                }
            }
        }
    };
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                &exclude($loopfile,'.');
                &$do_this;
                $dircontents[$index] =
                    &stat_entry($loopfile->{name}, $loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        &$do_this;
        $showncontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name}, $currentfile{selected});
        &copyback($currentfile{name});
    }
    return $do_a_refresh;
}

sub handlechown {
    my ($newuid, $loopfile, $do_this, $index);
    my $prompt = 'New [user][:group] ';
    my $do_a_refresh = $multiple_mode ? $R_DIRLIST | $R_HEADER : $R_HEADER;
    &markcurrentline('U') unless $multiple_mode;
    $scr->at(0,0)->clreol();
    &stty_raw($TERM_COOKED);
    chomp($newuid = &readintohist(\@mode_history, $prompt));
    &stty_raw($TERM_RAW);
    return $R_HEADER if ($newuid eq '');
    $do_this = sub {
        if (system ('chown', $newuid, $loopfile->{name})) {
            $do_a_refresh |= &neat_error;
#            $scr->at(0,0)->clreol();
#            &display_error($!);
#            if ($multiple_mode) {
#                &path_info;
#            } else {
#                $do_a_refresh |= $R_FRAME;
#            }
        }
    };
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                &exclude($loopfile, '.');
                &$do_this;
                $dircontents[$index] =
                    &stat_entry($loopfile->{name}, $loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        &$do_this;
        $showncontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name}, $currentfile{selected});
        &copyback($currentfile{name});
    }
    return $do_a_refresh;
}

sub handlechmod {
    my ($newmode, $loopfile, $do_this, $index);
    my $prompt = 'Permissions [ugoa][-=+][rwxslt] or octal: ';
    my $do_a_refresh = $multiple_mode ? $R_DIRLIST | $R_HEADER : $R_HEADER;
    &markcurrentline('A') unless $multiple_mode;
    $scr->at(0,0)->clreol();
    &stty_raw($TERM_COOKED);
    chomp($newmode = &readintohist(\@mode_history, $prompt));
    &stty_raw($TERM_RAW);
    return $R_HEADER if ($newmode eq '');
    if ($newmode =~ s/^\s*(\d+)\s*$/oct($1)/e) {
        $do_this = sub {
            unless (chmod $newmode, $loopfile->{name}) {
                $do_a_refresh |= &neat_error;
#                &display_error($!);
#                if ($multiple_mode) {
#                    &path_info;
#                } else {
#                    $do_a_refresh |= $R_FRAME;
#                }
            }
        };
    } else {
        $do_this = sub {
            if (system 'chmod', $newmode, $loopfile->{name}) {
                $do_a_refresh |= &neat_error;
#                $scr->at(0,0)->clreol();
#                &display_error($!);
#                if ($multiple_mode) {
#                    &path_info;
#                } else {
#                    $do_a_refresh |= $R_FRAME;
#                }
            }
        };
    }
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                &exclude($loopfile,'.');
                &$do_this;
                $dircontents[$index] =
                    &stat_entry($loopfile->{name},$loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        &$do_this;
        $showncontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name}, $currentfile{selected});
        &copyback($currentfile{name});
    }
    return $do_a_refresh;
}

sub handlecommand { # Y or O
    local $_;
    my ($key, $command, $do_this, $printstr, $printline, $loopfile, $index);
    &markcurrentline(uc($_[0])) unless $multiple_mode;
    if ($_[0] =~ /y/i) { # Your
        &clearcolumn;
        &init_title($swap_mode, $TITLE_COMMAND, @layoutfields);
        $printline = $BASELINE;
        foreach (sort keys %pfmrc) {
            if (/^[A-Z]$/ && $printline <= $BASELINE+$screenheight) {
                $printstr = $pfmrc{$_};
                $printstr =~ s/\e/^[/g;
                $^A = "";
                formline('@ @<<<<<<<<<<<',$_,$printstr);
                $scr->at($printline++,$screenwidth-$DATECOL)->puts($^A);
            }
        }
        $key = $scr->at(0,0)->clreol()->cyan()->bold()
                   ->puts('Enter one of the highlighted chars at right:')
                   ->at(0,45)->normal()->getch();
        &clearcolumn;
        # this line is supposed to be an assignment
        return $R_DISKINFO | $R_FRAME unless ($command = $pfmrc{uc($key)});
        &stty_raw($TERM_COOKED);
    } else { # cOmmand
        $printstr = <<'_eoPrompt_';
Enter Unix command (\1=name, \2=name.ext, \3=path, \4=mountpoint, \5=swap path):
_eoPrompt_
        $scr->at(0,0)->clreol()->bold()->cyan()->puts($printstr)->normal()
            ->at($PATHLINE,0)->clreol();
        &stty_raw($TERM_COOKED);
        $command = &readintohist(\@command_history);
    }
#    $command =~ s/^\s*\n?$/$ENV{'SHELL'}/; # PFM.COM behavior
    unless ($command =~ /^\s*\n?$/) {
        $command .= "\n";
        if ($multiple_mode) {
            $scr->clrscr()->at(0,0);
            for $index (0..$#dircontents) {
                $loopfile = $dircontents[$index];
                if ($loopfile->{selected} eq '*') {
                    &exclude($loopfile,'.');
                    $do_this = $command;
                    &expand_escapes($do_this,$loopfile);
                    $scr->puts($do_this);
                    system $do_this and &display_error($!);
                    $dircontents[$index] =
                        &stat_entry($loopfile->{name},$loopfile->{selected});
                    if ($dircontents[$index]{nlink} == 0) {
                        $dircontents[$index]{display} .= " $LOSTMSG";
                    }
                }
            }
            $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
        } else { # single-file mode
            $loopfile = \%currentfile;
            &expand_escapes($command, \%currentfile);
            $scr->clrscr()->at(0,0)->puts($command);
            system $command and &display_error($!);
            $showncontents[$currentline+$baseindex] =
                &stat_entry($currentfile{name}, $currentfile{selected});
            if ($showncontents[$currentline+$baseindex]{nlink} == 0) {
                $showncontents[$currentline+$baseindex]{display} .= " $LOSTMSG";
            }
            &copyback($currentfile{name});
        }
        &pressanykey;
    }
    &stty_raw($TERM_RAW);
    return $R_CLEAR;
}

sub handledelete {
    my ($loopfile, $do_this, $index, $success, $msg, $oldpos, %nameindexmap);
    my $count = 0;
    &markcurrentline('D') unless $multiple_mode;
    $scr->at(0,0)->clreol()->cyan()->bold()
        ->puts("Are you sure you want to delete [Y/N]? ")->normal();
    my $sure = $scr->getch();
    return $R_HEADER if $sure !~ /y/i;
    $scr->at($PATHLINE,0);
    $do_this = sub {
        if ($loopfile->{name} eq '.') {
            # don't allow people to delete '.': normally, this would be allowed
            # if it is empty, but if that leaves the parent directory empty,
            # then it can also be removed, which causes a fatal pfm error.
            $success = 0;
            $msg = 'Deleting current directory not allowed';
        } elsif ($loopfile->{nlink} == 0) {
            $success = 1;
        } elsif ($loopfile->{type} eq 'd') {
            $success = rmdir $loopfile->{name};
        } else {
            $success = unlink $loopfile->{name};
        }
        if ($success) {
            $total_nr_of{$loopfile->{type}}--;
            &exclude($loopfile) if $loopfile->{selected} eq '*';
        } else { # not success
            &display_error($msg || $!);
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
                &$do_this;
                if ($success) {
                    splice @dircontents, $index, 1;
                    splice @showncontents, $nameindexmap{$loopfile->{name}}, 1;
                }
            }
        }
        # %nameindexmap may be completely invalid at this point. use dirlookup()
        if (&dirlookup($oldpos, @showncontents) > 0) {
            $position_at = $oldpos;
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        &$do_this;
        if ($success) {
            splice @dircontents, &dirlookup($loopfile->{name}, @dircontents), 1;
            splice @showncontents, $currentline+$baseindex, 1;
        }
    }
    # this prevents the cursor from running out of @showncontents;
    # otherwise, the validate_position() call is pointless
    while ($position_at eq '' and $currentline+$baseindex > $#showncontents) {
        $currentline--;
    }
    &validate_position;
    return $R_SCREEN;
}

sub handleprint {
    my ($loopfile, $do_this, $index);
    &markcurrentline('P') unless $multiple_mode;
    $scr->at(0,0)->clreol()
        ->bold()->cyan()->puts('Enter print command: ')->normal()
        ->at($PATHLINE,0)->clreol();
    &stty_raw($TERM_COOKED);
    # don't use readintohist : special case with command_history
    $kbd->SetHistory(@command_history);
    $do_this = $kbd->readline('',$printcmd);
    if ($do_this =~ /\S/
        and $do_this ne $printcmd
        and $do_this ne $command_history[$#command_history]
    ) {
        push (@command_history, $do_this);
        shift (@command_history) if ($#command_history > $MAXHISTSIZE);
    }
    &stty_raw($TERM_RAW);
    return $R_FRAME | $R_DISKINFO if $do_this eq '';
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                &exclude($loopfile, '.');
                system "$do_this \Q$loopfile->{name}" and &display_error($!);
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        system "$do_this \Q$currentfile{name}" and &display_error($!);
    }
    return $R_SCREEN;
}

sub handleshow {
    my ($loopfile,$index);
    $scr->clrscr()->at(0,0);
    &stty_raw($TERM_COOKED);
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->puts($loopfile->{name});
                &exclude($loopfile,'.');
                system "$pager \Q$loopfile->{name}" and &display_error($!);
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        system "$pager \Q$currentfile{name}" and &display_error($!);
    }
    &stty_raw($TERM_RAW);
    return $R_CLEAR;
}

sub handlehelp {
    $scr->clrscr();
    system qw(man pfm); # how unsubtle :-)
    &credits;
    return $R_CLEAR;
}

sub handletime {
    my ($newtime, $loopfile, $do_this, $index, $do_a_refresh, @cmdopts);
    my $prompt = "Put date/time $TIMEHINTS{$timeformat}: ";
    $do_a_refresh = $multiple_mode ? $R_DIRLIST | $R_HEADER : $R_HEADER;
    &markcurrentline('T') unless $multiple_mode;
    $scr->at(0,0)->clreol();
    &stty_raw($TERM_COOKED);
    $newtime = &readintohist(\@time_history, $prompt);
    &stty_raw($TERM_RAW);
    return $R_HEADER if ($newtime eq '');
    # convert date/time to touch format if necessary
    if ($timeformat eq 'pfm') {
        $newtime =~ s/^(\d{0,4})(\d{8})(\..*)?/$2$1$3/;
    }
    if ($newtime eq '.') {
        @cmdopts = ();
    } else {
        @cmdopts = ('-t', $newtime);
    }
    $do_this = sub {
        if (system ('touch', @cmdopts, $loopfile->{name})) {
            $do_a_refresh |= &neat_error;
#            $scr->at(0,0)->clreol();
#            &display_error($!);
#            if ($multiple_mode) {
#                &path_info;
#            } else {
#                $do_a_refresh |= $R_FRAME;
#            }
        }
    };
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
                &exclude($loopfile,'.');
                &$do_this;
                $dircontents[$index] =
                    &stat_entry($loopfile->{name},$loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        &$do_this;
        $showncontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name}, $currentfile{selected});
        &copyback($currentfile{name});
    }
    return $do_a_refresh;
}

sub handleedit {
    my ($loopfile, $index);
    $scr->clrscr()->at(0,0);
    &stty_raw($TERM_COOKED);
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->puts($loopfile->{name});
                &exclude($loopfile, '.');
                system "$editor \Q$loopfile->{name}" and &display_error($!);
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        system "$editor \Q$currentfile{name}" and &display_error($!);
    }
    &stty_raw($TERM_RAW);
    return $R_CLEAR;
}

sub handlecopyrename {
    my $state = "\u$_[0]";
    my $statecmd = ($state eq 'C' ? 'cp' : 'mv');
    my $stateprompt = $state eq 'C' ? 'Destination: ' : 'New name: ';
    my ($loopfile, $index, $newname, $newnameexpanded, $do_this, $findindex,
        @cmdopts);
    my $do_a_refresh = $R_HEADER;
    &markcurrentline($state) unless $multiple_mode;
    $scr->at(0,0)->clreol();
    &stty_raw($TERM_COOKED);
    push (@path_history, $currentfile{name}) unless $multiple_mode;
    $newname = &readintohist(\@path_history, $stateprompt);
    if ($#path_history > 0 and $path_history[-1] eq $path_history[-2]) {
        pop @path_history;
    }
    &stty_raw($TERM_RAW);
    return $R_HEADER if ($newname eq '');
    # expand \[345] at this point, but not yet \[12]
    &expand_345_escapes($newname, \%currentfile);
    if ($multiple_mode and $newname !~ /(?<!\\)(?:\\\\)*\\[12]/
                       and !-d($newname) )
    {
        $scr->at(0,0)->cyan()->bold()
        ->puts("Cannot do multifile operation when destination is single file.")
        ->normal()->at(0,0);
        &pressanykey;
        &path_info;
        return $R_HEADER;
    }
    @cmdopts = $clobber ? () : qw(-i);
    $do_this = sub {
        if (system $statecmd, @cmdopts, $loopfile->{name}, $newnameexpanded) {
            $do_a_refresh |= &neat_error;
#            $scr->at(0,0)->clreol();
#            &display_error($!);
#            if ($multiple_mode) {
#                $do_a_refresh |= $R_PATHINFO;
#            } else {
#                $do_a_refresh |= $R_FRAME;
#            }
        } elsif ($newnameexpanded !~ m!/!) {
            # is newname present in @dircontents? push otherwise
            $findindex = 0;
            $findindex++ while ($findindex <= $#dircontents and
                            $newnameexpanded ne $dircontents[$findindex]{name});
            if ($findindex > $#dircontents) {
                $do_a_refresh |= $R_DIRSORT;
            }
            $dircontents[$findindex] = &stat_entry($newnameexpanded,
                $dircontents[$findindex]{selected} || " ");
        }
    };
    &stty_raw($TERM_COOKED) unless $clobber;
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                &exclude($loopfile, '.');
                &expand_escapes(($newnameexpanded = $newname), $loopfile);
                $scr->at($PATHLINE,0)->clreol()->puts($loopfile->{name});
#                &stty_raw($TERM_COOKED) unless $clobber;
                &$do_this;
                $dircontents[$index] =
                    &stat_entry($loopfile->{name},$loopfile->{selected});
                if ($dircontents[$index]{nlink} == 0) {
                    $dircontents[$index]{display} .= " $LOSTMSG";
                }
#                &stty_raw($TERM_RAW) unless $clobber;
                $do_a_refresh |= $R_SCREEN;
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
#        &expand_escapes($command, $loopfile);
        &expand_escapes(($newnameexpanded = $newname), $loopfile);
        &$do_this;
        $showncontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name}, $currentfile{selected});
        if ($showncontents[$currentline+$baseindex]{nlink} == 0) {
            $showncontents[$currentline+$baseindex]{display} .= " $LOSTMSG";
        }
        &copyback($currentfile{name});
        # if ! $clobber, we might have gotten an 'Overwrite?' question
        $do_a_refresh |= $R_SCREEN unless $clobber;
    }
    &stty_raw($TERM_RAW) unless $clobber;
    return $do_a_refresh;
}

sub handlerestat {
    # i have seen these commands somewhere before..
    my $currentfile = $dircontents[$currentline+$baseindex];
    $showncontents[$currentline+$baseindex] =
        &stat_entry($currentfile{name}, $currentfile{selected});
    if ($showncontents[$currentline+$baseindex]{nlink} == 0) {
        $showncontents[$currentline+$baseindex]{display} .= " $LOSTMSG";
    }
    &copyback($currentfile{name});
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
    # we need %currentfile set, so &highlightline can show the 'selected' status
    %currentfile = %$file;
    &copyback($file->{name});
    &highlightline($HIGHLIGHT_OFF);
#    &mark_info(%selected_nr_of);
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
#    &validate_position;
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
    return &validate_position | ($_ eq ' ' ? $R_DISKINFO : $R_NOP);
}

sub handleenter {
    $scr->clrscr();
    &stty_raw($TERM_COOKED);
    system "./\Q$currentfile{name}" and &display_error($!);
    &pressanykey; # will also reset raw mode
    return $R_CLEAR;
}

sub handleswap {
    my $do_a_refresh = $R_TITLE | $R_HEADER;
    my $temp_state   = $swap_state;
    my $stateprompt  = 'Directory Pathname: ';
    my $nextdir;
    if ($swap_state and !$swap_persistent) { # swap back if ok_to_remove_marks
        if (&ok_to_remove_marks) {
            $nextdir           =   $swap_state->{path};
            @dircontents       = @{$swap_state->{contents}};
            $position_at       =   $swap_state->{position};
            %disk              = %{$swap_state->{disk}};
            %selected_nr_of    = %{$swap_state->{selected}};
            %total_nr_of       = %{$swap_state->{totals}};
            $multiple_mode     =   $swap_state->{multiple_mode};
            $sort_mode         =   $swap_state->{sort_mode};
            $dot_mode          =   $swap_state->{dot_mode};
            $0                 =   $swap_state->{argvnull};
            $swap_mode = $swap_state = 0;
            $do_a_refresh |= $R_SCREEN;
        } else { # not ok to remove marks
            $do_a_refresh |= $R_HEADER;
        }
    } elsif ($swap_state and $swap_persistent) { # swap persistent
        $swap_state = {
            path              =>   $currentdir,
            contents          => [ @dircontents ],
            position          =>   $currentfile{name},
            disk              => { %disk },
            selected          => { %selected_nr_of },
            totals            => { %total_nr_of },
            multiple_mode     =>   $multiple_mode,
            sort_mode         =>   $sort_mode,
            dot_mode          =>   $dot_mode,
            argvnull          =>   $0
        };
        $nextdir           =   $temp_state->{path};
        @dircontents       = @{$temp_state->{contents}};
        $position_at       =   $temp_state->{position};
        %disk              = %{$temp_state->{disk}};
        %selected_nr_of    = %{$temp_state->{selected}};
        %total_nr_of       = %{$temp_state->{totals}};
        $multiple_mode     =   $temp_state->{multiple_mode};
        $sort_mode         =   $temp_state->{sort_mode};
        $dot_mode          =   $temp_state->{dot_mode};
        $0                 =   $temp_state->{argvnull};
        toggle($swap_mode);
        $do_a_refresh |= $R_SCREEN;
    } else { # $swap_state = 0; ask and swap forward
        $swap_state = {
            path              =>   $currentdir,
            contents          => [ @dircontents ],
            position          =>   $currentfile{name},
            disk              => { %disk },
            selected          => { %selected_nr_of },
            totals            => { %total_nr_of },
            multiple_mode     =>   $multiple_mode,
            sort_mode         =>   $sort_mode,
            dot_mode          =>   $dot_mode,
            argvnull          =>   $0
        };
        $swap_mode     = 1;
        $sort_mode     = $pfmrc{sortmode} || 'n';
        $multiple_mode = 0;
        $scr->at(0,0)->clreol();
        &stty_raw($TERM_COOKED);
        $nextdir = &readintohist(\@path_history, $stateprompt);
        &expand_escapes($nextdir, \%currentfile);
        &stty_raw($TERM_RAW);
        $position_at   = '.';
        $do_a_refresh |= $R_CHDIR;
    }
    if (!&mychdir($nextdir)) {
        $scr->at($PATHLINE,0);
        &display_error("$nextdir: $!");
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
    return $R_NOP if ! &ok_to_remove_marks;
    $success = &mychdir($nextdir);
    if ($success && $direction =~ /up/ ) {
        $position_at   = &basename($oldcurrentdir);
    } elsif ($success && $direction =~ /down/) {
        $position_at   = '..';
    }
    unless ($success) {
        $scr->at(0,0)->clreol();
        &display_error($!);
        &init_header;
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
    if (!defined $user{$uid} ) {  $user{$uid} = $uid }
    if (!defined $group{$gid}) { $group{$gid} = $gid }
    $ptr = {
        name        => $entry,           device      => $device,
        uid         => $user{$uid},      inode       => $inode,
        gid         => $group{$gid},     nlink       => $nlink,
        mode        => &mode2str($mode), rdev        => $rdev,
        selected    => $selected_flag,   grand_power => ' ',
        atime       => $atime,           size        => $size,
        mtime       => $mtime,           blocks      => $blocks,
        ctime       => $ctime,           blksize     => $blksize,
        atimestring => &time2str($atime, $TIME_FILE),
        mtimestring => &time2str($mtime, $TIME_FILE),
        ctimestring => &time2str($ctime, $TIME_FILE),
    };
    @{$ptr}{qw(size_num size_power)} = &fit2limit($size, $maxfilesizelength);
    $ptr->{type} = substr($ptr->{mode}, 0, 1);
    if ($ptr->{type} eq 'l') {
        $ptr->{target}  = readlink($ptr->{name});
        $ptr->{display} = $entry . ' -> ' . $ptr->{target};
    } elsif ($ptr->{type} =~ /[bc]/) {
        $ptr->{size} = sprintf("%d",$rdev/256).$MAJORMINORSEPARATOR.($rdev%256);
        $ptr->{display} = $entry;
    } else {
        $ptr->{display} = $entry;
    }
    $ptr->{name_too_long} = length($ptr->{display}) > $maxfilenamelength-1
                            ? $NAMETOOLONGCHAR : ' ';
    $total_nr_of{ $ptr->{type} }++; # this is wrong! e.g. after cOmmand
    return $ptr;
}

sub getdircontents { # (current)directory
    my (@contents, $entry);
    my @allentries = ();
#    &init_title($swap_mode, $TITLE_DISKINFO, @layoutfields);
    if (opendir CURRENT, "$_[0]") {
        @allentries = readdir CURRENT;
        closedir CURRENT;
    } else {
        $scr->at(0,0)->clreol();
        &display_error("Cannot read . : $!");
    }
    # next lines also correct for directories with no entries at all
    # (this is sometimes the case on NTFS filesystems: why?)
    if ($#allentries < 0) {
        @allentries = ('.', '..');
    }
    local $SIG{INT} = sub { return @contents };
    if ($#allentries > $SLOWENTRIES) {
        # don't use display_error here because that would just cost more time
        $scr->at(0,0)->clreol()->cyan()->bold()->puts('Please Wait')->normal();
    }
    foreach $entry (@allentries) {
        # have the mark cleared on first stat with ' '
        push @contents, &stat_entry($entry, ' ');
    }
    &init_header();
    return @contents;
}

sub printdircontents { # @contents
    foreach my $i ($baseindex .. $baseindex+$screenheight) {
        unless ($i > $#_) {
            $scr->at($i+$BASELINE-$baseindex,0)
                ->puts(&fileline($_[$i], @layoutfields));
            &applycolor($i+$BASELINE-$baseindex, $FILENAME_SHORT, %{$_[$i]});
        } else {
            $scr->at($i+$BASELINE-$baseindex,0)
                ->puts(' 'x($screenwidth-$DATECOL-1));
        }
    }
}

sub countdircontents {
    %selected_nr_of =
    %total_nr_of    = ( d=>0, l=>0, '-'=>0, c=>0, b=>0,
                        D=>0, p=>0, 's'=>0, n=>0, w=>0, bytes => 0);
    foreach my $i (0..$#_) {
        $total_nr_of   {$_[$i]{type}}++;
        $selected_nr_of{$_[$i]{type}}++ if ($_[$i]{selected} eq '*');
    }
}

sub get_filesystem_info {
    my (@dflist, %tdisk);
    chop( (undef, @dflist) = (`$DFCMD .`, '') ); # undef to swallow header
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
    return &validate_position; # refresh flag
}

sub set_argv0 {
    # this may be helpful for sysadmins trying to unmount a filesystem
    $0 = 'pfm [on ' . ( $disk{device} eq 'none' ? $disk{mountpoint}
                                                : $disk{device} ) . ']';
}

sub recalc_ptr {
    $position_at = '.';
    return &position_cursor; # refresh flag
}

sub showdiskinfo {
    &disk_info(%disk);
    &dir_info(%total_nr_of);
    &mark_info(%selected_nr_of);
    &user_info;
    &date_info($DATELINE, $screenwidth-$DATECOL);
}

##########################################################################
# directory browsing main routine
#
# this sub is the heart of pfm. it has the following structure:
#
# repeat {
#       refresh everything flagged for refreshing;
#       wait for keypress-, mousedown- or resize-event;
#       handle the request;
# } until quit;
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
# $R_CLS         : clear the screen
# $R_CLEAR       : combination of R_CLS and R_SCREEN
# $R_DIRSORT     : resort @dircontents
# $R_DIRCONTENTS : reread directory contents
# $R_NEWDIR      : re-init directory-specific vars
# $R_CHDIR       : combination of R_NEWDIR, R_DIRCONTENTS, R_DIRSORT, R_SCREEN
# $R_QUIT        : exit from program

sub browse {
    my $wantrefresh = shift;
    my $key;
    STRIDE: do {
#        system "xmessage '" . &dumprefreshflags($wantrefresh) . "'";
        if ($wantrefresh & $R_NEWDIR) {
            $wantrefresh &= ~$R_NEWDIR;
            # it's dangerous to leave multiple_mode on when changing directories
            # 'autoexitmultiple' is only for leaving it on between commands
            $multiple_mode = 0;
            $currentdir    = getcwd();
            %disk          = &get_filesystem_info;
            &set_argv0;
        }
        # draw frame as soon as possible: this looks better on slower terminals
        if ($wantrefresh & $R_CLS) {
            $wantrefresh &= ~$R_CLS;
            $scr->clrscr();
        }
        if ($wantrefresh & $R_FRAME) {
            $wantrefresh &= ~($R_TITLE | $R_HEADER | $R_FOOTER);
            &init_frame;
        }
        # now in order of severity
        if ($wantrefresh   & $R_DIRCONTENTS) {
            $wantrefresh   &= ~$R_DIRCONTENTS;
            %selected_nr_of =
            %total_nr_of    = ( d=>0, l=>0, '-'=>0, c=>0, b=>0,
                                D=>0, p=>0, 's'=>0, n=>0, w=>0, bytes => 0);
            $position_at  ||= $showncontents[$currentline+$baseindex]{name};
            @dircontents    = &getdircontents($currentdir);
        }
        if ($wantrefresh & $R_DIRSORT) {
            $wantrefresh &= ~$R_DIRSORT;
            $position_at ||= $showncontents[$currentline+$baseindex]{name};
            @dircontents = sort as_requested @dircontents;
        }
        if ($wantrefresh & $R_DIRFILTER) {
            $wantrefresh &= ~$R_DIRFILTER;
            @showncontents = &filterdir(@dircontents);
        }
        if ($wantrefresh & $R_STRIDE) {
            $wantrefresh &= ~$R_STRIDE;
            &position_cursor if $position_at ne '';
            &recalc_ptr unless defined $showncontents[$currentline+$baseindex];
            %currentfile = %{$showncontents[$currentline+$baseindex]};
        }
        if ($wantrefresh & $R_DIRLIST) {
            $wantrefresh &= ~$R_DIRLIST;
            &printdircontents(@showncontents);
        }
        if ($wantrefresh & $R_DISKINFO) {
            $wantrefresh &= ~$R_DISKINFO;
            &showdiskinfo;
        }
        if ($wantrefresh & $R_HEADER) {
            $wantrefresh &= ~$R_HEADER;
            &init_header;
        }
        if ($wantrefresh & $R_PATHINFO) {
            $wantrefresh &= ~$R_PATHINFO;
            &path_info;
        }
        if ($wantrefresh & $R_TITLE) {
            $wantrefresh &= ~$R_TITLE;
            &init_title($swap_mode, $TITLE_DISKINFO, @layoutfields);
        }
        if ($wantrefresh & $R_FOOTER) {
            $wantrefresh &= ~$R_FOOTER;
            &init_footer;
        }
        # normally, the current cursor position must be validated every pass
        $wantrefresh |= $R_STRIDE;
        # don't send mouse escapes to the terminal if not necessary
        &highlightline($HIGHLIGHT_ON);
        &mouseenable($MOUSE_ON) if $mouse_mode && $mouseturnoff;
        WAIT: until ($scr->key_pressed(1) || $wasresized) {
            &date_info($DATELINE, $screenwidth-$DATECOL);
            $scr->at($currentline+$BASELINE, $cursorcol);
        }
        if ($wasresized) {
            $wantrefresh |= &handleresize;
        # the next line contains an assignment on purpose
        } elsif ($scr->key_pressed() and $key = $scr->getch()) {
            &highlightline($HIGHLIGHT_OFF);
            &mouseenable($MOUSE_OFF) if $mouseturnoff;
            KEY: for ($key) {
                # order is determined by (supposed) frequency of use
                /^(?:kr|kl|[h\e\cH])$/i
                             and $wantrefresh |= &handleentry($_),     last KEY;
                /^l$/        and $wantrefresh |= &handlekeyell($_),    last KEY;
                /^[cr]$/i    and $wantrefresh |= &handlecopyrename($_),last KEY;
                /^[yo]$/i    and $wantrefresh |= &handlecommand($_),   last KEY;
                /^e$/i       and $wantrefresh |= &handleedit,          last KEY;
                /^(?:ku|kd|pgup|pgdn|[-+jk\cF\cB\cD\cU]|home|end)$/i
                             and $wantrefresh |= &handlemove($_),      last KEY;
                /^[\cE\cY]$/ and $wantrefresh |= &handlescroll($_),    last KEY;
                /^ $/        and $wantrefresh |= &handleadvance($_),   last KEY;
                /^d$/i       and $wantrefresh |= &handledelete,        last KEY;
                /^[ix]$/i    and $wantrefresh |= &handleinclude($_),   last KEY;
                /^[s\r]$/i   and $wantrefresh |= &handleshowenter($_), last KEY;
                /^kmous$/    and $wantrefresh |= &handlemousedown,     last KEY;
                /^k7$/       and $wantrefresh |= &handleswap,          last KEY;
                /^k5$/       and $wantrefresh |= &handlerefresh,       last KEY;
                /^k10$/      and $wantrefresh |= &handlemultiple,      last KEY;
                /^m$/i       and $wantrefresh |= &handlemore,          last KEY;
                /^p$/i       and $wantrefresh |= &handleprint,         last KEY;
                /^L$/        and $wantrefresh |= &handlesymlink,       last KEY;
                /^v$/i       and $wantrefresh |= &handleview,          last KEY;
                /^k8$/       and $wantrefresh |= &handleselect,        last KEY;
                /^k11$/      and $wantrefresh |= &handlerestat,        last KEY;
                /^[\/f]$/i   and $wantrefresh |= &handlefind,          last KEY;
                /^[<>]$/i    and $wantrefresh |= &handlepan($_),       last KEY;
                /^k3$/       and $wantrefresh |= &handlefit,           last KEY;
                /^t$/i       and $wantrefresh |= &handletime,          last KEY;
                /^a$/i       and $wantrefresh |= &handlechmod,         last KEY;
                /^q$/i       and $wantrefresh |= &handlequit($_),      last KEY;
                /^k6$/       and $wantrefresh |= &handlesort,          last KEY;
                /^(?:k1|\?)$/
                             and $wantrefresh |= &handlehelp,          last KEY;
                /^k2$/       and $wantrefresh |= &handlecdold,         last KEY;
                /^\.$/       and $wantrefresh |= &handledot,           last KEY;
                /^k9$/       and $wantrefresh |= &handlecolumns,       last KEY;
                /^k4$/       and $wantrefresh |= &handlecolor,         last KEY;
                /^\@$/       and $wantrefresh |= &handleperlcommand,   last KEY;
                /^u$/i       and $wantrefresh |= &handlechown,         last KEY;
                /^z$/i       and $wantrefresh |= &handlesize,          last KEY;
                /^g$/i       and $wantrefresh |= &handletarget,        last KEY;
                /^k12$/      and $wantrefresh |= &handlemousetoggle,   last KEY;
                # invalid keypress: cursor position needs no checking
                $wantrefresh &= ~$R_STRIDE;
            } # end switch KEY
        } # end if key_pressed
    } until $wantrefresh & $R_QUIT;
}

##########################################################################
# void main(char *path)

&globalinit(@ARGV);
&browse($R_CHDIR);
&goodbye;
exit 0;

__DATA__
##########################################################################
## Configuration file for Personal File Manager
## Version x

## every option line in this file should have the form:
## [whitespace] option [whitespace]:[whitespace] value
## (whitespace is optional)
## in other words: /^\s*([^:\s]+)\s*:\s*(.*)$/
## everything following a # is regarded as a comment.
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

## automatically clobber existing files
clobber:no

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

## initial layout to pick from the array 'columnlayouts' (see below) (F9)
defaultlayout:0

## initial sort mode (see F6 command) (nNmMeEfFsSiItTdDaA) (default n)
defaultsortmode:n

## hide dot files? (show them otherwise, toggle with . key)
dotmode:no

## '.' and '..' entries always at the top of the dirlisting?
dotdotmode:no

## your system's du(1) command. Specify so that the outcome is in bytes.
## you need to specify "\2" for the name of the current file.
## this is commented out because pfm makes a clever guess for your OS.
#ducmd:du -sk "\2" | awk '{ printf "%d", 1024 * $1 }'

## specify your favorite editor. you can also use $EDITOR for this
editor:vi

## the erase character for your terminal (default: don't set)
#erase:^H

## additional key definitions for Term::Screen.
## definitely look in the Term::Screen(3pm) manpage for details.
## specify these by-terminal (make the option name 'keydef_$TERM')
## if some (function) keys do not seem to work, add their escape sequences here.
## also check 'kmous' from terminfo if your mouse is malfunctioning.
keydef_linux:home=\e[1~:end=\e[4~
keydef_xterm:home=\e[H:end=\e[F:kmous=\e[M

## the keymap to use in readline (vi,emacs). (default emacs)
#keymap:vi

## turn on mouse support? (yes,no,xterm) (default: only in xterm)
mousemode:xterm

## turn off mouse support during execution of commands?
## caution: if you set this to 'no', your (external) commands (like $pager
## and $editor) will receive escape codes on mousedown events
mouseturnoff:yes

## your pager. you can also use $PAGER
#pager:less

## F7 key swap path method is persistent? (default no)
persistentswap:yes

## your system's print command. Specify if the default 'lpr' does not work.
#printcmd:lp -d$ENV{PRINTER}

## show whether mandatory locking is enabled (e.g. -rw-r-lr-- ) (yes,no,sun)
## 'sun' = show locking only on sunos/solaris
showlock:sun

## format for entering time:
## touch MMDDhhmm[[CC]YY][.ss] or pfm [[CC]YY]MMDDhhmm[.ss]
timeformat:pfm

## format for displaying timestamps: see strftime(3).
## Take care that the time fields in the layouts defined below
## should be wide enough for this string.
timestampformat:%y %b %d %H:%M
#timestampformat:%Y-%m-%d %H:%M:%S
#timestampformat:%b %d %H:%M
#timestampformat:%Y %V %a

## translate spaces when Viewing
translatespace:no

## base number system to View non-ascii characters with (hex,oct)
viewbase:hex

##########################################################################
## colors

## use color (yes,no,force)
## 'no'    = use no color at all
## 'yes'   = use color for title bars, if pfm thinks your terminal supports it
## 'force' = use color for title bars on any terminal
## your *files* will only be colored if you also define 'dircolors' below
usecolor:force

## 'dircolors' defines the colors that will be used for your files.
## for your files to become colored, 'usecolor' must be set to 'yes' or 'force'.
## see also the manpages for ls(1) and dircolors(1) (on Linux systems).
## you can also use $LS_COLORS or $LS_COLOURS to set this.

##-attribute codes:
## 00=none 01=bold 04=underscore 05=blink 07=reverse 08=concealed(?)
##-text color codes:
## 30=black 31=red 32=green 33=yellow 34=blue 35=magenta 36=cyan 37=white
##-background color codes:
## 40=black 41=red 42=green 43=yellow 44=blue 45=magenta 46=cyan 47=white
##-file types:
## no=normal fi=file ex=executable lo=lost file ln=symlink or=orphan link
## di=directory bd=block special cd=character special pi=fifo so=socket
## do=door nt=network special (not implemented) wh=whiteout (not implemented)
## *.<ext> defines extension colors

## you may specify an escape as a real escape, as \e or as ^[ (caret, bracket)

dircolors:no=00:fi=00:ex=00;32:lo=01;30:di=01;34:ln=01;36:or=37;41:\
bd=01;33;40:cd=01;33;40:pi=00;33;40:so=01;35:\
do=01;35:nt=01;35:wh=01;30;47:lc=\e[:rc=m:\
*.cmd=01;32:*.exe=01;32:*.com=01;32:*.btm=01;32:*.bat=01;32:\
*.pas=32:*.c=35:*.h=35:*.pm=36:*.pl=36:\
*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:\
*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=31:*.rpm=31:\
*.jpg=01;35:*.gif=01;35:*.bmp=01;35:*.xbm=01;35:*.xpm=01;35:\
*.mpg=01;37:*.avi=01;37:*.gl=01;37:*.dl=01;37:*.htm=01;33:*.html=01;33:

## use this if you don't want colors for your files, but only for the title bars
#dircolors:-

## colors for header, title, footer
## regardless of these settings, the footer will always be bold
## these are commented out because they are the defaults
#headercolor:37;44
#multicolor:36;47
#titlecolor:01;07;36;47
#swapcolor:07;36;40
#footercolor:07;34;47

## these are some suggestions
#titlecolor:07;36;40
#swapcolor:07;33;40

##########################################################################
## column layouts

## char name                    needed width if present
## *    selected flag           1
## n    filename                variable length; last char == overflow flag
## s    filesize                >=4; last char == power of 1024 (K, M, G..)
## z    grand total             >=4; last char == power of 1024 (K, M, G..)
## u    user                    >=8 (system-dependent)
## g    group                   >=8 (system-dependent)
## p    permissions (mode)      10
## a    access time             15
## c    change time             15
## m    modification time       15
## d    device                  5?
## i    inode                   7
## l    link count              >=5 (system-dependent)

## take care not to make the fields too small or values will be cropped!
## if the terminal is resized, the filename field will be elongated.
## a final : after the last layout is allowed.
## the first three layouts were the old (pre-v1.72) defaults.
## the last one is the ls(1) layout.

#<----------- layouts must not be wider than this! ------------># #<-diskinfo->#
columnlayouts:\
* nnnnnnnnnnnnnnnnnnnnnssssssss mmmmmmmmmmmmmmmiiiiiii pppppppppp:\
* nnnnnnnnnnnnnnnnnnnnnssssssss aaaaaaaaaaaaaaaiiiiiii pppppppppp:\
* nnnnnnnnnnnnnnnnnnnnnssssssss uuuuuuuu gggggggglllll pppppppppp:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnsssssss uuuuuuuu gggggggg pppppppppp:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnuuuuuuuu gggggggg pppppppppp:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnzzzzzzzz mmmmmmmmmmmmmmm:\
* nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnssssssss:\
pppppppppp  uuuuuuuu gggggggg sssssss* nnnnnnnnnnnnnnnnnnnnnnnnnn:\
pppppppppp  mmmmmmmmmmmmmmm  ssssssss* nnnnnnnnnnnnnnnnnnnnnnnnnn:\
ppppppppppllll uuuuuuuu ggggggggssssssss mmmmmmmmmmmmmmm *nnnnnnn:

##########################################################################
## your commands

## these assume you do not have filenames with double quotes in them.
## in these commands, \1=filename without extension, \2=filename complete,
## \3=current directory path, \4=current mountpoint, \5=swap path (F7)

A:acroread "\2" &
B:xv -root +noresetroot +smooth -maxpect -quit "\2"
C:tar cvf - "\2" | gzip > "\2".tar.gz
D:uudecode "\2"
E:unarj l "\2" | more
F:file "\2"
G:gvim "\2"
I:rpm -qpi "\2"
J:mpg123 "\2" &
K:esdplay "\2"
L:mv -i "\2" "$(echo "\2" | tr A-Z a-z)"
N:nroff -man "\2" | more
O:cp "\2" "\2.$(date +"%Y%m%d")"; touch -r "\2" "\2.$(date +"%Y%m%d")"
P:perl -cw "\2"
Q:unzip -l "\2" | more
R:rpm -qpl "\2" | more
S:strings "\2" | more
T:gunzip < "\2" | tar tvf - | more
U:gunzip "\2"
V:xv "\2" &
W:what "\2"
X:gunzip < "\2" | tar xvf -
Y:lynx "\2"
Z:gzip "\2"

## vi: set filetype=xdefaults: # close enough, just not for multiline strings
__END__

##########################################################################
# pod documentation

=pod

=head1 NAME

C<pfm> - Personal File Manager for Linux/Unix

=head1 SYNOPSIS

C<pfm [>I<directory>C<]>

=head1 DESCRIPTION

C<pfm> is a terminal-based file manager, based on PFMS<.>COM for MS-DOS.

All C<pfm> commands are accessible through one or two keystrokes, and a few
are accessible with the mouse. Most command keys are case-insensitive. C<pfm>
can operate in single-file mode or multiple-file mode. In single-file mode,
the command corresponding to the keypress will be performed on the current
(highlighted) file only. In multiple-file mode, the command will apply to
a selection of files.

Note that throughout this manual page, I<file> can mean any type
of file, not just plain regular files. These will be referred to as
I<regular files>.

=head1 OPTIONS

=over

You may specify a starting directory on the command line when
invoking C<pfm>. The C<CDPATH> environment variable is taken into
account when C<pfm> tries to find this directory. There are no command line
options. Configuration is read from a file, F<$HOME/.pfm/.pfmrc> , which
is created automatically the first time you start C<pfm>. The file is
supposed to be self-explanatory.  See also MORE COMMANDS below.

=back

=head1 NAVIGATION

=over

Navigation through directories is done using the arrow keys, the vi(1)
cursor keys (B<hjkl>), B<->, B<+>, B<PgUp>, B<PgDn>, B<home>, B<end>, and the
vi(1) control keys B<CTRL-F>, B<CTRL-B>, B<CTRL-U>, B<CTRL-D>, B<CTRL-Y>
and B<CTRL-E>. Note that the B<l> key is also used for creating symbolic
links (see the B<L>ink command below). Pressing B<ESC> or B<BS> will take
you one directory level up (note: see BUGS below). Pressing B<ENTER> when
the cursor is on a directory will take you into the directory. Pressing
B<SPACE> will both mark the current file and advance the cursor.

=back

=head1 COMMANDS

=over

=item B<.>

Toggle show/hide dot files.

=item B</>

Identical to B<F>ind (see below).

=item B<E<lt>>

Scroll the header and footer, displaying the left part of the set
of available commands.

=item B<E<gt>>

Scroll the header and footer, displaying the right part of the set of
available commands.

=item B<?>

Display help. Identical to B<F1>.

=item B<@>

Allows the user to enter a perl command to be executed in the context
of C<pfm>. Primarily used for debugging.

=item B<Attrib>

Changes the mode of the file if you are the owner. Use a '+' to add a
permission, a '-' to remove it, and a '=' specify the mode exactly, or
specify the mode numerically.

Note 1: the mode on a symbolic link cannot be set. Read the chmod(1)
page for more details.

Note 2: the name B<Attrib> for this command is a reminiscence of the DOS
version.

=item B<Copy>

Copy current file. You will be prompted for the destination filename.
In multiple-file mode, it is not allowed to specify a regular file
for a destination. Specify the destination name with B<\1> or B<\2>
(see cB<O>mmand below), or use a directory as destination.

=item B<Delete>

Delete a file or directory.

=item B<Edit>

Edit a file with your external editor. You can specify an editor with
the environment variable C<EDITOR> or in the F<$HOME/.pfm/.pfmrc> file,
else vi(1) is used.

=item B<Find>

Prompts for a filename, then positions the cursor on that file.

=item B<tarGet>

Allows to change the target that a symbolic link points to. You must have
permission to remove the current symbolic link.

=item B<Include>

Allows you to mark a group of files which meet a certain criterion:
B<E>very file, B<O>ldmarks (reselects any files which were previously
marked and are now denoted with an I<oldmark> B<.> ), B<U>ser (only
files owned by you) or B<F>iles only (prompts for a regular expression
(not a glob pattern) which the filename must match). Oldmarks may be
used to do multifile operations on a group of files more than once. If
you B<I>nclude B<E>very, dotfiles will be included as well, except for
the B<.> and B<..> directory entries.

=item B<Link>

Create a symbolic link to the current file or directory. The symlink will
become relative if you are creating it in the current directory, otherwise
it will contain an absolute path.

Note that if the current file is a directory, the B<l> key, being one of
the vi(1) cursor keys, will chdir() you into the directory. The capital
B<L> command will I<always> make a symlink.

=item B<More>

Presents you with a choice of operations not related to the current
files. Use this to configure C<pfm>, edit a new file, make a new
directory, show a different directory, kill all child processes, or
write the history files to disk. See MORE COMMANDS below. Pressing B<ESC>
will take you back to the main menu.

=item B<cOmmand>

Allows execution of a shell command on the current files.  After the
command completes, C<pfm> will resume.  You may abbreviate the current
filename as B<\2>, the current filename without extension as B<\1>,
the current directory path as B<\3>, the mount point of the current
filesystem as B<\4> and the swap directory path (see B<F7> command)
as B<\5>. To enter a backslash, use B<\\>.

=item B<Print>

Will prompt for a print command (default C<lpr -P$PRINTER>, or C<lpr>
if C<PRINTER> is unset) and will pipe the current file through
it. No formatting is done. You may specify a print command in your
F<$HOME/.pfm/.pfmrc> (see below).

=item B<Quit>

Exit C<pfm>. You may specify in your F<$HOME/.pfm/.pfmrc> whether
C<pfm> should ask for confirmation (option 'confirmquit'). Note that
by pressing a capital B<Q> (quick quit), you will I<never> be asked for
confirmation.

=item B<Rename>

Change the name of the file to the path- and filename specified. Depending
on your Unix implementation, a different path- and filename on another
filesystem may or may not be allowed. In multiple-file mode, the new
name I<must> be a directoryname or a name containing a B<\1> or B<\2>
escape (see cB<O>mmand above). If the option 'clobber' is set to I<no>
in F<$HOME/.pfm/.pfmrc>, existing files will not be overwritten unless
the action is confirmed by the user.

=item B<Show>

Displays the contents of the current file or directory on the screen.
You can choose which pager to use for file viewing with the environment
variable C<PAGER>, or in the F<$HOME/.pfm/.pfmrc> file.

=item B<Time>

Change mtime (modification date/time) of the file. The format used is
converted to a format which touch(1) can use. Enter B<.> to set the
mtime to the current date and time.

=item B<Uid>

Change ownership of a file. Note that many Unix variants do not allow
normal (non-C<root>) users to change ownership.

=item B<View>

View the complete long filename. For a symbolic link, also displays the
target of the symbolic link. Non-ASCII characters, control characters
and (optionally) spaces will be displayed in octal or hexadecimal
(configurable through the 'viewbase' and 'translatespace' options in
F<$HOME/.pfm/.pfmrc>), formatted like the following examples:

    octal:                     hexadecimal:

    control-A : \001           control-A : \0x01
    space     : \040           space     : \0x20
    c-cedilla : \347           c-cedilla : \0xe7
    backslash : \\             backslash : \\

=item B<eXclude>

Allows you to erase marks on a group of files which meet a certain
criterion. See B<I>nclude for details.

=item B<Your command>

Like cB<O>mmand (see above), except that it uses commands that have
been preconfigured in F<$HOME/.pfm/.pfmrc> by a I<letter>B<:>I<command>
line. Commands may use B<\1>-B<\5> escapes just as in cB<O>mmand, e.g.

    C:tar cvf - \2 | gzip > \2.tar.gz
    W:what \2

=item B<siZe>

For directories, reports the grand total (in bytes) of the directory
and its contents.

For other file types, reports the total number of bytes in allocated
data blocks. For regular files, this is often more than the reported
file size. For special files and I<fast symbolic links>, the number is 0,
as no data blocks are allocated for these file types.

If the screen layout (selected with B<F9>) contains a 'grand total' column,
that column will be used. Otherwise, the 'filesize' column will temporarily
be (ab)used. A 'grand total' column in the layout will never be filled by
default.

Note: since du(1) is not portable, you will have to specify the C<du>
command (or C<du | awk> combination) applicable for your Unix version in
the F<.pfmrc> file. Examples are provided.

=back

=head1 MORE COMMANDS

=over

=item B<Config PFM>

This command will open the F<$HOME/.pfm/.pfmrc> configuration file with
your preferred editor. The file will be re-read by C<pfm> after you exit
your editor.

=item B<Edit new file>

You will be prompted for the new filename, then your editor will
be spawned.

=item B<sHell>

Spawns your default login shell until you exit from it, then resumes.

=item B<Kill children>

Lists available signals. After selection of a signal, sends this signal
to all child processes of C<pfm> (more accurately: all processes in the
same process group).

=item B<Make new directory>

Specify a new directory name and C<pfm> will create it for you.
Furthermore, if you don't have any files marked, your current
directory will be set to the newly created directory.

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
in F<$HOME/.pfm/.pfmrc> .

=back

=head1 MISCELLANEOUS and FUNCTION KEYS

=over

=item B<F1>

Display help, version number and license information.

=item B<F2>

Jump back to the previous directory.

=item B<F3>

Fit the file list into the current window and refresh the display.

=item B<F4>

Toggle the use of color.

=item B<F5>

Current directory will be reread. Use this when the contents of the
directory have changed. This command will erase all marks.

=item B<F6>

Allows you to re-sort the directory listing. You will be presented by
a number of sort modes.

=item B<F7>

Swaps the display between primary and secondary screen. When switching
from primary to secondary, you are prompted for a path to show.
When switching back by pressing B<F7> again, the original contents are
displayed unchanged. Header text changes color when in secondary screen.
While in the secondary screen, the swap directory from the first screen
may be referred to in commands as B<\5>.

=item B<F8>

Toggles the include flag (mark) on an individual file.

=item B<F9>

Toggle the column layout. Layouts are defined in your F<.pfmrc>, through
the 'defaultlayout' and 'columnlayouts' options. See the configuration
file for information on changing the column layout.

Note that a 'grand total' column in the layout will only be filled when
the siB<Z>e command is issued.

=item B<F10>

Switch between single-file and multiple-file mode.

=item B<F11>

Refresh (using lstat(2)) the displayed file data for the current file.

=item B<F12>

Toggle mouse use. See MOUSE COMMANDS below.

=item B<ENTER>

Displays the contents of the current file or directory on the screen (like
B<S>how). If the current file is executable, the executable will be invoked.

=back

=head1 MOUSE COMMANDS

When C<pfm> is run in an xterm, mouse use may be turned on (either through
the B<F12> key, or with the 'mousemode' option in the config file), which
will give mouse access to the following commands:

    button:   pathline:     title:   footer:   file:   filename:

    left      More - Show   ctrl-U   ctrl-D    F8      Show
    middle    cOmmand       PgUp     PgDn      Show    ENTER
    right     cOmmand       PgUp     PgDn      Show    ENTER

The cursor will I<only> be moved when the title or footer is clicked, or
when changing directory.

Mouse use will be turned off during the execution of commands, unless
'mouseturnoff' is set to 'no' in F<.pfmrc> . Note that setting this to
'no' means that your (external) commands (like your pager and editor)
will receive escape codes when the mouse is clicked.

=head1 WORKING DIRECTORY INHERITANCE

=over

Upon exit, C<pfm> will save its current working directory in a file
F<$HOME/.pfm/cwd> . In order to have this directory "inherited" by the
calling process (shell), you may call C<pfm> using a function like the
following (example for ksh(1) and bash(1), add it to your F<.profile>
or F<.bash_profile>):

 pfm () {
     /usr/local/bin/pfm "$@"
     if [ -s ~/.pfm/cwd ]; then
         cd "`cat ~/.pfm/cwd`" # double quotes for names with spaces
         rm -f ~/.pfm/cwd
     fi
 }

=back

=head1 ENVIRONMENT

=over

=item B<CDPATH>

A colon-separated list of directories specifying the search path when
changing directories. There is an implicit 'B<.>' entry at the start of
this search path. Make sure the variable is exported into the environment
if you want to use this feature.

=item B<EDITOR>

The editor to be used for the B<E>dit command.

=item B<HOME>

The directory where the B<F7> commans will take you if you don't specify
a new directory. Also the directory that initial B<~/> characters in a
filename will expand to.

=item B<PAGER>

Identifies the pager with which to view text files. Defaults to less(1)
for Linux systems or more(1) for Unix systems.

=item B<PFMRC>

Specify a location of an alternate F<.pfmrc> file. The cwd- and history-
files cannot be displaced in this manner.

=item B<PRINTER>

May be used to specify a printer to print to using the B<P>rint command.

=item B<SHELL>

Your default login shell, spawned by B<M>ore - sB<H>ell.

=back

=head1 FILES

The directory F<$HOME/.pfm/> and files therein. Several input histories
are saved to this directory.

=head1 BUGS and WARNINGS

When typed by itself, the B<ESC> key needs to be pressed twice. This is
due to the lack of a proper timeout in C<Term::Screen>.

The F<readline> library does not allow a half-finished line to be aborted by
pressing B<ESC>. For most commands, you will need to clear the half-finished
line. You may use the terminal kill character (usually B<CTRL-U>) for this
(see stty(1)).

When key repeat sets in, some of the registered keypresses may not be
processed before another key is pressed. This can be dangerous when
deleting files. The author once almost pressed B<ENTER> when logged in
as root and with the cursor next to F</sbin/reboot> . You have been warned.

Commands that are started from a shell (e.g. with B<Y>our or cB<O>mmand)
enclose the filename in double quotes to allow names with spaces.
This prevents the correct processing of filenames containing double quotes.

The smallest terminal size supported is 80x24. The display will be messed
up if you resize your terminal window to a smaller size.

Whiteout support, broken in previous versions, has been removed.

C<pfm> uses up too much memory. But then again, everybody has tons of
memory nowadays.

=head1 VERSION

This manual pertains to C<pfm> version 1.82 .

=head1 SEE ALSO

The documentation on PFMS<.>COM . The mentioned manual pages for
chmod(1), less(1), lpr(1), touch(1), vi(1). The manual pages for
Term::ScreenColor(3) and Term::ReadLine::Gnu(3).

=head1 AUTHOR

Written by RenE<eacute> Uittenbogaard (ruittenb@users.sourceforge.net).
This program was based on PFMS<.>COM version 2.32, originally written
for MS-DOS by Paul R. Culley and Henk de Heer. Permission to use the
name 'pfm' was kindly granted by Henk de Heer.

=head1 COPYRIGHT

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the terms described by the GNU General Public
License version 2.

=cut

# vim:     set tabstop=4 shiftwidth=4 expandtab list:
# vim>600: set foldmethod=indent nofoldenable:

